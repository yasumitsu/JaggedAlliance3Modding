--[==[

DLC OS-specific files have the following structure:
 
DLC content is:
 |- autorun.lua
 |- revisions.lua
 |- Lua.hpk (if containing newer version of Lua, causes reload) 
 |- Data.hkp (if containing newer version of Data)
 |- Data/... (additional data)
 |- Maps/...
 |- Sounds.hpk
 |- EntityTextures.hpk (additional entity textures)
 |- ...

The Autorun returns a table with a description of the dlc:
return {
	name = "Colossus",
	display_name = T{"Colossus"}, -- optional, must be a T with an id if present
	pre_load = function() end,
	post_load = function() end,
	required_lua_revision = 12345, -- skip loading this DLC below this revision
}


DLC mount steps:

1. Enumerate and mount OS-specific DLC packs (validating them on steam/pc)
	-- result is a list of folders containing autorun.lua files
	
2. Execute autorun.lua and revisions.lua; autorun.lua should set g_AvailableDlc[dlc.name] = true
	
3. Check required_lua_revision and call dlc:pre_load() for each dlc that passes the check

4. If necessary reload localization, lua and data from the lasest packs (it can update the follow up Dlc load steps)

5. If necessary reload the latest Dlc assets
	-- reload entities
	-- reload BinAssets
	-- reload sounds
	-- reload music

6. Call the dlc:post_load() for each dlc
]==]

if FirstLoad then
	-- "" and false are "no dlc" values for the missions and achievements systems respectively
	g_AvailableDlc = {[""] = true, [false] = true} -- [achievement name] = true ; DLC code is expected to properly init this!
	g_DlcDisplayNames = {} -- [achievement name] = "translated string"
	DlcFolders = false
	DlcDefinitions = false
	DataLoaded = false
end

if FirstLoad and Platform.playstation then
	local err, list = AsyncPlayStationAddcontList(0)
	g_AddcontStatus = {}
	if not err then
		for _, addcont in ipairs(list) do
			g_AddcontStatus[addcont.label] = addcont.status
		end
	end
end
	
dlc_print = CreatePrint{
	--"dlc" 
}

--[[@@@
Returns if the player has a specific DLC installed.
@function bool IsDlcAvailable(string dlc)
@param dlc - The ID of a DLC.
@result bool - If the DLC is available and loaded.
]]
---
--- Returns if the player has a specific DLC installed.
---
--- @param dlc string The ID of a DLC.
--- @return boolean If the DLC is available and loaded.
function IsDlcAvailable(dlc)
	dlc = dlc or false
	return g_AvailableDlc[dlc]
end

---
--- Returns if the player has a specific DLC installed.
---
--- @param dlc string The ID of a DLC.
--- @return boolean If the DLC is available and loaded.
function IsDlcOwned(dlc)
end
---
--- Returns the path to a DLC directory.
---
--- @param dlc string The ID of a DLC.
--- @return string The path to the DLC directory.

function DLCPath(dlc)
	if not dlc or dlc == "" then return "" end
	return "DLC/" .. dlc
end

-- Use, for example, for marking savegames. In all other cases use IsDlcAvailable
---
--- Returns a list of all available DLCs.
---
--- @return table A table of DLC IDs.
function GetAvailableDlcList()
	local dlcs = {}
	for dlc, v in pairs(g_AvailableDlc) do
		if v and dlc ~= "" and dlc ~= false then
			dlcs[ 1 + #dlcs ] = dlc
		end
	end
	table.sort(dlcs)
	return dlcs
end

---
--- Returns a list of all available DLC folders in the "svnProject/Dlc/" directory.
---
--- @return table A table of DLC folder names.
function GetDeveloperDlcs()
	local dlcs = Platform.developer and IsFSUnpacked() and io.listfiles("svnProject/Dlc/", "*", "folders") or empty_table
	for i, folder in ipairs(dlcs) do
		dlcs[i] = string.gsub(folder, "svnProject/Dlc/", "")
	end
	table.sort(dlcs)
	return dlcs
end

DbgAllDlcs = false
DbgAreDlcsMissing = return_true
DbgIgnoreMissingDlcs = rawget(_G, "DbgIgnoreMissingDlcs") or {}

if Platform.developer and IsFSUnpacked() then
	DbgAllDlcs = GetDeveloperDlcs()
	function DbgAreDlcsMissing()
		for _, dlc in ipairs(DbgAllDlcs or empty_table) do
			if not DbgIgnoreMissingDlcs[dlc] and not g_AvailableDlc[dlc] then
				return dlc
			end
		end
	end
end

-- Helper function for tying a savegame to a set of required DLCs
--	metadata = FillDlcMetadata(metadata, dlcs)
---
--- Fills the DLC metadata in the provided table.
---
--- @param metadata table The metadata table to fill.
--- @param dlcs table A list of DLC IDs.
--- @return table The updated metadata table.
function FillDlcMetadata(metadata, dlcs)
	metadata = metadata or {}
	dlcs = dlcs or GetAvailableDlcList()
	local t = {}
	for _, dlc in ipairs(dlcs) do
		t[#t+1] = {id = dlc, name = g_DlcDisplayNames[dlc] or dlc}
	end
	metadata.dlcs = t
	return metadata
end

-- Step 1. Enumerate and mount OS-specific DLC packs (validating them on steam/pc)
---
--- Mounts OS-specific DLC packs and returns a list of the mounted folders.
---
--- This function is responsible for mounting DLC packs that are specific to the
--- current operating system. It checks the current platform and mounts the
--- appropriate DLC packs, such as PlayStation Addcont, AppStore, Xbox, and
--- Windows Store DLCs. It also mounts any embedded DLCs that are available.
---
--- @return table A list of the mounted DLC folders.
--- @return boolean Whether an error occurred during the mounting process.
function DlcMountOsPacks()
	dlc_print("Mount Os Packs")
	local folders = {}
	local error = false
	
	if Platform.demo then
		dlc_print("Mount Os Packs early out: no DLCs in demo")
		return folders, error
	end
	
	if Platform.playstation then
		for label, status in pairs(g_AddcontStatus) do
			if status == const.PlaystationAddcontStatusInstalled then
				local addcont_error, mount_point = AsyncPlayStationAddcontMount(0, label)
				local pack_error = MountPack(label, mount_point .. "/content.hpk")
				error = error or addcont_error or pack_error
				table.insert(folders, label)
			end
		end
		dlc_print(string.format("PS4 Addcont: %d listed (%d mounted)", #g_AddcontStatus, #folders))
	end
	if Platform.appstore then
		local content = AppStore.ListDownloadedContent()
		for i=1, #content do
			local folder = "Dlc" .. i
			local err = MountPack(folder, content[i].path)
			if not err then
				folders[#folders+1] = folder
			end
		end
	end
	if Platform.xbox then
		local list
		error, list = Xbox.EnumerateLocalDlcs()
		if not error then
			for idx = 1, #list do
				local folders_index = #folders+1
				
				local err, mountDir = AsyncXboxMountDLC(list[idx][1])
				if not err then
					err = MountPack("Dlc" .. folders_index, mountDir .. "/content.hpk")
					error = error or err
					if not err then
						folders[folders_index] = "Dlc" .. folders_index
					end
				end
			end
		end
	end
	if Platform.windows_store then
		local err, list = WindowsStore.MountDlcs()
		if not err then
			for i=1, #list do
				local folder = list[i]
				local folders_index = #folders+1
				err = MountPack("Dlc" .. folders_index, folder .. "/content.hpk")
				if not err then
					folders[folders_index] = "Dlc" .. folders_index
				end
			end
		end
	end
	
	if not DlcFolders then -- Load the embedded DLCs only once
		if Platform.developer and IsFSUnpacked() then
			local dev_list = Platform.developer and IsFSUnpacked() and io.listfiles("svnProject/Dlc/", "*", "folders") or empty_table
			for _, folder in ipairs(dev_list) do
				local dlc = string.gsub(folder, "svnProject/Dlc/", "")
				if not (LocalStorage.DisableDLC and LocalStorage.DisableDLC[dlc]) then
					folders[#folders + 1] = folder
				end
			end
		else
			local files = io.listfiles("AppData/DLC/", "*.hpk", "non recursive") or {}
			table.iappend(files, io.listfiles("DLC/", "*.hpk", "non recursive"))
			if Platform.linux then
				table.iappend(files, io.listfiles("dlc/", "*.hpk", "non recursive"))
			end
			if Platform.pgo_train then
				table.iappend(files, io.listfiles("../win32-dlc", "*.hpk", "non recursive"))
			end
			dlc_print("Dlc os packs: ", files)
			for i=1,#files do
				local folder = "Dlc" .. tostring(#folders+1)
				local err = MountPack(folder, files[i])
				if not err then
					table.insert(folders, folder)
				end
			end	
		end
	end
		
	dlc_print("Dlc folders: ", folders)
	return folders, error
end

-- 2. Execute autorun.lua and revisions.lua
---
--- Executes the autorun.lua file for each DLC folder and returns a table of DLC objects.
---
--- @param folders table A table of DLC folder names.
--- @return table A table of DLC objects.
function DlcAutoruns(folders)
	dlc_print("Dlc Autoruns")
	local dlcs = {}
	
	-- dlc.folder points to the autorun mount
	for i = 1, #folders do
		local folder = folders[i]
		local dlc = dofile(folder .. "/autorun.lua")
		if type(dlc) == "function" then
			dlc = dlc(folder)
		end
		if type(dlc) == "table" then
			dlc_print("Autorun executed for", dlc.name)
			dlc.folder = folder
			if Platform.developer and folder:starts_with("svnProject/Dlc") then
				dlc.lua_revision, dlc.assets_revision = LuaRevision, AssetsRevision
			else
				dlc.lua_revision, dlc.assets_revision = dofile(folder .. "/revisions.lua")
			end
			table.insert(dlcs, dlc)
			DebugPrint(string.format("DLC %s loaded, lua revision %d, assets revision %d\n", tostring(dlc.name), dlc.lua_revision or 0, dlc.assets_revision or 0))
		else
			print("Autorun failed:", folder)
		end
	end
	return dlcs
end

-- 3. Call the dlc:pre_load() to all dlcs. Let a DLC decide that it doesn't want to be installed
---
--- Executes the pre-load logic for each DLC and removes any DLCs that don't meet the required Lua revision.
---
--- @param dlcs table A table of DLC objects.
--- @return number The highest required Lua revision across all DLCs.
---
function DlcPreLoad(dlcs)
	local revision
	for i = #dlcs, 1, -1 do
		local required_lua_revision = dlcs[i].required_lua_revision
		if required_lua_revision and required_lua_revision <= LuaRevision then
			required_lua_revision = nil -- the required revision is lower, ignore condition
		end
		revision = Max(revision, required_lua_revision)
		local pre_load = dlcs[i].pre_load or empty_func
		if required_lua_revision or pre_load(dlcs[i]) == "remove" then
			dlc_print("Dlc removed:", dlcs[i].name, required_lua_revision or "")
			table.remove_value(DlcFolders, dlcs[i].folder)
			table.remove(dlcs, i)
		end
	end
	return revision
end

---
--- Returns a message string indicating that some downloadable content requires a title update to function.
---
--- This function first attempts to retrieve the message text from the translation table. If the message text is not found in the translation table, it falls back to providing a default message in the user's current language.
---
--- @return string The message string indicating that some downloadable content requires a title update.
---
function GetDlcRequiresTitleUpdateMessage()
	local id = TGetID(MessageText.DlcRequiresUpdate)
	if id and TranslationTable[id] then
		return TranslationTable[id]
	end
	
	-- fallback
	local language, strMessage = GetLanguage(), nil
	if     language == "French" then
		strMessage = "Certains contenus téléchargeables nécessitent l'installation d'une mise à jour du jeu pour fonctionner."
	elseif language == "Italian" then
		strMessage = "Alcuni contenuti scaricabili richiedono un aggiornamento del titolo per essere utilizzati."
	elseif language == "German" then
		strMessage = "Bei einigen Inhalten zum Herunterladen ist ein Update notwendig, damit sie funktionieren."
	elseif language == "Spanish" or language == "Latam" then
		strMessage = "Ciertos contenidos descargables requieren una actualización para funcionar."
	elseif language == "Polish" then
		strMessage = "Część zawartości do pobrania wymaga aktualizacji gry."
	elseif language == "Russian" then
		strMessage = "Загружаемый контент требует обновления игры."
	else
		strMessage = "Some downloadable content requires a title update in order to work."
	end
	return strMessage
end


local function find(dlcs, path, rev, rev_name)
	local found
	for i = #dlcs, 1, -1 do
		local dlc = dlcs[i]
		if dlc[rev_name] > rev and io.exists(dlc.folder .. path) then
			rev = dlc[rev_name]
			found = dlc
		end
	end
	if found then
		return found.folder .. path, found
	end
end

-- 4. If necessary reload localization, lua and data from the lasest packs (it can update the follow up Dlc load steps)
---
--- Reloads Lua code and other assets from the latest DLC packs.
---
--- This function first mounts the latest localization pack for the current language, and optionally the English language pack.
--- It then mounts the latest BinAssets pack, reloads entities, and reloads texture headers.
--- Next, it mounts the latest Lua and Data packs, and reloads Lua if necessary.
--- Finally, it loads the translation tables if the localization was reloaded but Lua was not.
---
--- @param dlcs table A table of DLC information.
--- @param late_dlc_reload boolean Whether this is a late DLC reload.
---
function DlcReloadLua(dlcs, late_dlc_reload)
	local lang_reload
	local reload = late_dlc_reload
	
	-- mount latest localization
	local lang_pack = find(dlcs, "/Local/" .. GetLanguage() .. ".hpk", LuaRevision, "lua_revision")
	if lang_pack then
		dlc_print(" - localization:", lang_pack)
		MountPack("", lang_pack, "", "CurrentLanguage")
		lang_reload = true
	end
	
	-- English language for e.g. the Mod Editor on PC
	if config.GedLanguageEnglish then
		local engl_pack = find(dlcs, "/Local/English.hpk", LuaRevision, "lua_revision")
		if engl_pack then
			MountPack("", engl_pack, "", "EnglishLanguage")
		end
	end
	
	-- reload entities
	local binassets_path = "/BinAssets.hpk"
	local binassets_pack = find(dlcs, binassets_path, AssetsRevision, "assets_revision")
	if binassets_pack then
		dlc_print(" - BinAssets:", binassets_pack)
		UnmountByPath("BinAssets")
		local err = MountPack("BinAssets", binassets_pack)
		dlc_print(" - BinAssets:", binassets_pack, "ERROR", err)
		ReloadEntities("BinAssets/entities.dat")
		ReloadTextureHeaders()
		reload = true
	end
	
	-- reload Lua
	if late_dlc_reload then -- clean the global tables to prevent duplication
		Presets = {}
		ClassDescendants("Preset", function(name, class)
			if class.GlobalMap then
				_G[class.GlobalMap] = {}
			end
		end)
	end
	
	local lua_pack, dlc = find(dlcs, "/Lua.hpk", LuaRevision, "lua_revision")
	if lua_pack then
		dlc_print(" - lua:", dlc.folder .. "/Lua.hpk")
		assert(not config.RunUnpacked)
		UnmountByLabel("Lua")
		LuaPackfile = lua_pack
		reload = true
	end
	local data_pack, dlc = find(dlcs, "/Data.hpk", LuaRevision, "lua_revision")
	if data_pack then
		assert(io.exists(dlc.folder .. "/Data.hpk"))
		UnmountByLabel("Data")
		DataPackfile = data_pack
	end
	for i = 1, #dlcs do
		if io.exists(dlcs[i].folder .. "/Code/") then
			reload = true
			break
		end
	end

	reload = reload or config.Mods and next(ModsLoaded)
	if reload then
		ReloadLua(true)
	end
	
	if lang_reload and not reload then
		LoadTranslationTables()
	end
end

---
--- Mounts all available voice packs for the current language from the specified DLCs.
---
--- @param dlcs table A table of DLC information.
--- @param skip_sort boolean (optional) If true, the DLCs will not be sorted by assets revision.
---
function DlcMountVoices(dlcs, skip_sort)
	UnmountByLabel("DlcVoices")
	if not dlcs then return end
	-- Mount all available voices packs in the multi (order by assets revision in case we want to fix a voice from one DLC from a later one)
	local sorted_dlcs
	if not skip_sort then
		sorted_dlcs = table.copy(dlcs)
		table.stable_sort(sorted_dlcs, function (a, b) return a.assets_revision < b.assets_revision end)
	end
	for i, dlc in ipairs(sorted_dlcs or dlcs) do
		local voice_pack = string.format("%s/Local/Voices/%s.hpk", dlc.folder, GetVoiceLanguage())
		if MountPack("CurrentLanguage/Voices", voice_pack, "seethrough,label:DlcVoices") then
			dlc_print(" - localization voice: ", voice_pack)
		end
	end
end

---
--- Mounts all available map packs from the specified DLCs.
---
--- @param dlcs table A table of DLC information.
---
function DlcMountMapPacks(dlcs)
	for _, dlc in ipairs(dlcs) do
		for _, map_pack in ipairs(io.listfiles(dlc.folder .. "/Maps", "*.hpk")) do
			local map_name = string.match(map_pack, ".*/Maps/([^/]*).hpk")
			if map_name then
				MapPackfile[map_name] = map_pack
			end
		end
	end
end

---
--- Mounts all available UI assets from the specified DLCs.
---
--- @param dlcs table A table of DLC information.
---
function DlcMountUI(dlcs)
	local asset_path = dlcs.folder .. "/UI/"
	if io.exists(asset_path) then
		local err = MountFolder("UI", asset_path, "seethrough")
		dlc_print(" - UI:", asset_path, "ERROR", err)
	end
end

---
--- Mounts additional non-entity textures from the specified DLCs.
---
--- @param dlcs table A table of DLC information.
---
function DlcMountNonEntityTextures(dlcs)
	local asset_path = find(dlcs, "/AdditionalNETextures.hpk", AssetsRevision, "assets_revision")
	if asset_path then
		UnmountByLabel("AdditionalNETextures")
		local err = MountPack("", asset_path, "priority:high,seethrough,label:AdditionalNETextures")
		dlc_print(" - non-entity textures:", asset_path, "ERROR", err)
	end
end

---
--- Mounts additional entity textures from the specified DLCs.
---
--- @param dlcs table A table of DLC information.
---
function DlcMountAdditionalEntityTextures(dlcs)
	local asset_path = find(dlcs, "/AdditionalTextures.hpk", AssetsRevision, "assets_revision")
	if asset_path then
		UnmountByLabel("AdditionalTextures")
		local err = MountPack("", asset_path, "priority:high,seethrough,label:AdditionalTextures")
		dlc_print(" - entity textures:", asset_path, "ERROR", err)
	end
end

---
--- Mounts all available sound assets from the specified DLCs.
---
--- @param dlcs table A table of DLC information.
---
function DlcMountSounds(dlcs)
	local asset_path = dlcs.folder .. "/Sounds/"
	if io.exists(asset_path) then
		local err = MountFolder("Sounds", asset_path, "seethrough")
		dlc_print(" - Sounds:", asset_path, "ERROR", err)
	end
end

---
--- Mounts meshes and animations from the specified DLCs.
---
--- This function is responsible for mounting the mesh and animation assets from the
--- specified DLCs. It first checks if the base meshes and animations are mounted,
--- and if not, it mounts the default Meshes.hpk and Animations.hpk packs. Then, it
--- mounts any additional mesh, animation, and skeleton assets from each DLC.
---
--- @param dlcs table A table of DLC information.
---
function DlcMountMeshesAndAnimations(dlcs)
	local meshes_pack = find(dlcs, "/Meshes.hpk", AssetsRevision, "assets_revision")
	if meshes_pack then
		dlc_print(" - Meshes:", meshes_pack)
		UnmountByPath("Meshes")
		MountPack("Meshes", meshes_pack)
	else
		-- If we reload DLCs in packed mode, make sure to have the original meshes first
		if MountsByPath("Meshes") == 0 and not IsFSUnpacked() then
			MountPack("Meshes", "Packs/Meshes.hpk")
		end
	end
	local animations_pack = find(dlcs, "/Animations.hpk", AssetsRevision, "assets_revision")
	if animations_pack then
		dlc_print(" - Animations:", animations_pack)
		UnmountByPath("Animations")
		MountPack("Animations", animations_pack)
	else
		if MountsByPath("Animations") == 0 and not IsFSUnpacked() then 
			MountPack("Animations", "Packs/Animations.hpk")
		end
	end

	-- mount additional meshes and animations for each DLC
	for i, dlc in ipairs(dlcs) do
		MountPack("", dlc.folder .. "/DlcMeshes.hpk", "seethrough,label:DlcMeshes")
		MountPack("", dlc.folder .. "/DlcAnimations.hpk", "seethrough,label:DlcAnimations")
		MountPack("", dlc.folder .. "/DlcSkeletons.hpk", "seethrough,label:DlcSkeletons")
		MountPack("BinAssets", dlc.folder .. "/DlcBinAssets.hpk", "seethrough,label:DlcBinAssets")
	end

	--common assets should be processed before the rest
	UnmountByLabel("CommonAssets")
	MountPack("", "Packs/CommonAssets.hpk", "seethrough,label:CommonAssets")
end

---
--- Reloads the shader cache for the specified DLCs.
---
--- This function is responsible for mounting the shader cache pack for the current
--- graphics API (DX9 or DX11). It first checks if the shader cache pack is available
--- for the specified DLCs, and if so, it mounts the pack. If the pack is not available,
--- it does not mount anything. The function also sets a flag to force a reload of the
--- shader cache on the next map or savegame load.
---
--- @param dlcs table A table of DLC information.
---
function DlcReloadShaders(dlcs)
end
function DlcReloadShaders(dlcs)	
	-- box DX9 and DX11 shader packs should be provided or missing
	local asset_path, dlc = find(dlcs, "/ShaderCache" .. config.GraphicsApi .. ".hpk", AssetsRevision, "assets_revision")
	if asset_path then
		dlc_print(" - ShaderCache:", asset_path)
		UnmountByPath("ShaderCache")
		MountPack("ShaderCache", asset_path, "seethrough,in_mem,priority:high")
		-- NOTE: new shader cache will be reloaded not on start up(main menu) but on next map/savegame load
		hr.ForceShaderCacheReload = true
	end
end

---
--- Mounts the music assets for the specified DLCs.
---
--- This function is responsible for mounting the music assets for the specified DLCs.
--- It checks if the music folder exists for each DLC, and if so, it mounts the folder
--- and creates a new playlist for the DLC's music.
---
--- @param dlcs table A table of DLC information.
---
function DlcAddMusic(dlcs)
	local asset_path = dlcs.folder .. "/Music/"
	if io.exists(asset_path) then
		local err = MountFolder("Music/" .. dlc.name, asset_path)
		dlc_print(" - Music:", asset_path, "ERROR", err)
		Playlists[dlc.name] = PlaylistCreate("Music/" .. dlc.name)
	end
end

---
--- Mounts the cubemap assets for the specified DLCs.
---
--- This function is responsible for mounting the cubemap assets for the specified DLCs.
--- It checks if the cubemap folder exists for each DLC, and if so, it mounts the folder.
---
--- @param dlcs table A table of DLC information.
---
function DlcAddCubemaps(dlcs)
	local asset_path = dlcs.folder .. "/Cubemaps/"
	if io.exists(asset_path) then
		local err = MountFolder("Cubemaps", asset_path, "seethrough")
		dlc_print(" - Cubemaps:", asset_path, "ERROR", err)
	end
end

---
--- Mounts the billboard assets for the specified DLCs.
---
--- This function is responsible for mounting the billboard assets for the specified DLCs.
--- It checks if the billboard folder exists for each DLC, and if so, it mounts the folder.
---
--- @param dlcs table A table of DLC information.
---
function DlcAddBillboards(dlcs)
	local asset_path = dlcs.folder .. "/Textures/Billboards/"
	if io.exists(asset_path) then
		local err = MountFolder("Textures/Billboards", asset_path, "seethrough")
		dlc_print(" - Billboards:", asset_path, "ERROR", err)
	end
end

---
--- Mounts the movie assets for the specified DLCs.
---
--- This function is responsible for mounting the movie assets for the specified DLCs.
--- It checks if the movie folder exists for each DLC, and if so, it mounts the folder.
---
--- @param dlcs table A table of DLC information.
---
function DlcMountMovies(dlcs)
	if IsFSUnpacked() then return end
	for _, dlc in ipairs(dlcs) do
		local path = dlc.folder .. "/Movies/"
		if io.exists(path) then
			local err = MountFolder("Movies/", path, "seethrough")
			dlc_print(" - DlcMovies:", path, err and "ERROR", err)
		end
	end
end

---
--- Mounts the binary asset folders for the specified DLCs.
---
--- This function is responsible for mounting the binary asset folders for the specified DLCs.
--- It checks if the BinAssets folder exists for each DLC, and if so, it mounts the folder.
---
--- @param dlcs table A table of DLC information.
---
function DlcMountBinAssets(dlcs)
	if IsFSUnpacked() then return end
	for _, dlc in ipairs(dlcs) do
		local path = dlc.folder .. "/BinAssets/"
		if io.exists(path) then
			local err = MountFolder("BinAssets/", path, "seethrough")
			dlc_print(" - DlcBinAssets:", path, err and "ERROR", err)
		end
	end
end

---
--- Mounts the miscellaneous assets for the specified DLCs.
---
--- This function is responsible for mounting the miscellaneous assets for the specified DLCs.
--- It checks if the Misc folder exists for each DLC, and if so, it mounts the folder.
---
--- @param dlcs table A table of DLC information.
---
function DlcMountMisc(dlcs)
	UnmountByLabel("DlcMisc")
	for _, dlc in ipairs(dlcs) do
		local path = dlc.folder .. "/Misc/"
		if io.exists(path) then
			local err = MountFolder("Misc/", path, "seethrough,label:DlcMisc")
			dlc_print(" - DlcMisc:", path, err and "ERROR", err)
		end
	end
end

---
--- Reloads the assets for the specified DLCs.
---
--- This function is responsible for reloading the assets for the specified DLCs. It performs the following steps:
---
--- 1. Mounts the map packs found in the Maps/ folder.
--- 2. Mounts the UI, sounds, music, cubemaps, and billboards for each DLC.
--- 3. Mounts the most recent additional non-entity textures.
--- 4. Mounts the most recent additional entity textures.
--- 5. Mounts the latest meshes, animations, and additional ones in the DLCs.
--- 6. Reloads the shaders (excluding OpenGL shaders).
--- 7. Mounts the movies for each DLC.
--- 8. Mounts the binary assets for each DLC.
--- 9. Mounts the miscellaneous assets for each DLC.
--- 10. Mounts the voices for each DLC.
---
--- @param dlcs table A table of DLC information.
---
function DlcReloadAssets(dlcs)
end
-- 5. If necessary reload the latest Dlc assets
function DlcReloadAssets(dlcs)
	dlcs = table.copy(dlcs)
	table.stable_sort(dlcs, function (a, b) return a.assets_revision < b.assets_revision end)
	
	-- mount map packs found in Maps/
	DlcMountMapPacks(dlcs)
	for _, dlc in pairs(dlcs) do
		-- mount the dlc UI
		DlcMountUI(dlc)
		-- mount the dlc sounds
		DlcMountSounds(dlc)
		-- mount the dlc music to the default playlist
		DlcAddMusic(dlc)
		-- mount the dlc cubemaps
		DlcAddCubemaps(dlc)
		-- mount the dlc billboards
		DlcAddBillboards(dlc)
	end
	-- mount the most recent additional non-entity textures
	DlcMountNonEntityTextures(dlcs)
	-- mount the most recent additional entity textures
	DlcMountAdditionalEntityTextures(dlcs)
	-- mount latest meshes and animations plus additional ones in Dlcs
	DlcMountMeshesAndAnimations(dlcs)
	-- find latest shaders; OpenGL shaders are not reloaded
	DlcReloadShaders(dlcs)
	-- mount movies
	DlcMountMovies(dlcs)
	-- 
	DlcMountBinAssets(dlcs)
	-- mount Misc
	DlcMountMisc(dlcs)
	-- mount voices
	DlcMountVoices(dlcs, true)
end

-- 6. Call the dlc.post_load() for each dlc
---
--- Calls the `post_load()` function for each DLC in the provided table.
---
--- @param dlcs table A table of DLC information.
---
function DlcPostLoad(dlcs)
	for _, dlc in ipairs(dlcs) do
		if dlc.post_load then dlc:post_load() end
	end
end

---
--- Handles errors that occur during DLC loading.
---
--- @param err string The error message.
---
function DlcErrorHandler(err)
	print("DlcErrorHandler", err, GetStack())
end

---
--- Waits for the initial DLC load to complete.
---
--- This function does nothing on reloads (like what happens on Xbox).
---
function WaitInitialDlcLoad()
	if not DlcFolders then
		WaitMsg("DlcsLoaded")
	end
end
function WaitInitialDlcLoad() -- does nothing on reloads (like what happens on Xbox)
	if not DlcFolders then
		WaitMsg("DlcsLoaded")
	end
end

---
--- Loads and initializes downloadable content (DLC) for the game.
---
--- This function is responsible for mounting DLC folders, loading DLC assets and Lua code,
--- and handling any errors that occur during the DLC loading process.
---
--- @param force_reload boolean (optional) If true, forces a full reload of the DLC, ignoring any previous state.
---
function LoadDlcs(force_reload)
	if Platform.developer and (LuaRevision == 0 or AssetsRevision == 0) then
		for i=1, 50 do
			Sleep(50)
			if LuaRevision ~= 0 and AssetsRevision ~= 0 then break end
		end
		if LuaRevision == 0 or AssetsRevision == 0 then
			print("Couldn't get LuaRevision or AssetsRevision, DLC loading may be off")
		end
	end

	if DlcFolders and not force_reload then
		return
	end
	
	if force_reload then
		ForceReloadBinAssets()
		DlcFolders = false
	end
	
	if Platform.appstore then
		local err = CopyDownloadedDLCs()
		if err then
			print("Failed to copy downloaded DLCs", err)
		end
	end
	
	LoadingScreenOpen("idDlcLoading", "dlc loading", T(808151841545, "Checking for downloadable content... Please wait."))
	
	-- 1. Mount OS packs
	local bCorrupt = false
	local folders, err = DlcMountOsPacks()
	if err == "File is corrupt" then
		bCorrupt = true
		err = false
	end
	
	if err then 
		DlcErrorHandler(err)
	end
	
	local dlcs = DlcAutoruns(folders)
	table.stable_sort(dlcs, function (a, b) return a.lua_revision < b.lua_revision end)

	UnmountByLabel("Dlc")
	local seen_dlcs = {}
	for i, dlc in ripairs(dlcs) do
		if seen_dlcs[dlc.name] then
			table.remove(dlcs, i)
		else
			seen_dlcs[dlc.name] = true
			dlc.title = dlc.title or dlc.display_name and _InternalTranslate(dlc.display_name) or dlc.name
			if not dlc.folder:starts_with("svnProject/Dlc/") then
				local org_folder = dlc.folder
				dlc.folder = "Dlc/" .. dlc.name
				MountFolder(dlc.folder, org_folder, "priority:high,label:Dlc")
			end
		end
	end
	DlcFolders = table.map(dlcs, "folder")
	DlcDefinitions = table.copy(dlcs)

	local bRevision = DlcPreLoad(dlcs)
	dlc_print("Dlc tables after preload:\n", table.map(dlcs, "name"))
	
	if config.Mods then
		-- load mod items in the same loading screen
		ModsReloadDefs()
		ModsReloadItems(nil, nil, true)
	end

	DlcReloadLua(dlcs, force_reload)
	DlcReloadAssets(dlcs)


	local metaCheck = const.PrecacheDontCheck
	if Platform.test then
		metaCheck = Platform.pc and const.PrecacheCheckUpToDate or const.PrecacheCheckExists
	end
	for _, dlc in ipairs(dlcs) do
		ResourceManager.LoadPrecacheMetadata("BinAssets/resources-" .. dlc.name .. ".meta", metaCheck)
	end
	
	DlcPostLoad(dlcs)
	
	-- Collect and translate the DLC display names. 
	--	We are just after the step that would reload the localization, so this would handle the case
	--		where a DLC display name is translated in the new DLC-provided localization
	local dlc_names = GetAvailableDlcList()
	for i=1, #dlc_names do
		local dlc_metadata = table.find_value(dlcs, "name", dlc_names[i])
		assert(dlc_metadata)
		local display_name = dlc_metadata.display_name
		if display_name then
			if not IsT(display_name) or not TGetID(display_name) then
				print("DLC", dlc_names[i], "display_name must be a localized T!")
			end
			display_name = _InternalTranslate(display_name)
			assert(type(display_name)=="string")
			g_DlcDisplayNames[ dlc_names[i] ] = display_name
		end
	end
	
	local dlc_names = GetAvailableDlcList()
	if next(dlc_names) then
		local infos = {}
		for i=1, #dlc_names do
			local dlcname = dlc_names[i]
			infos[i] = string.format("%s(%s)", dlcname, g_DlcDisplayNames[dlcname] or "")
		end
		print("Available DLCs:", table.concat(infos, ","))
	end
	Msg("DlcsLoaded")

	LoadData(dlcs)

	if config.Mods and next(ModsLoaded) then
		ContinueModsReloadItems()
	end

	if not Platform.developer then
		if not config.Mods or not Platform.pc then -- the mod creation (available on PC only) needs the data and lua sources to be able to copy functions
			UnmountByLabel("Lua")
			UnmountByLabel("Data")
		end
	end

	-- Messages should be shown after LoadData(), as there are UI presets that need to be present
	local interactive = not (Platform.developer and GetIgnoreDebugErrors())
	if interactive then
		if bCorrupt then
			WaitMessage(GetLoadingScreenDialog() or terminal.desktop, "", T(619878690503, --[[error_message]] "A downloadable content file appears to be damaged and cannot be loaded. Please delete it from the Memory section of the Dashboard and download it again."), nil, terminal.desktop)
		end
		if bRevision then
			local message = Untranslated(GetDlcRequiresTitleUpdateMessage())
			WaitMessage(GetLoadingScreenDialog() or terminal.desktop, "", message)
		end
	end
	
	LoadingScreenClose("idDlcLoading", "dlc loading")
	UIL.Invalidate()
end

---
--- Loads data for the game, including preset files, folders, and DLC data.
---
--- This function is responsible for loading all the necessary data for the game, including preset files and folders from the "CommonLua/Data" directory, as well as any additional data from DLC folders.
---
--- It first pauses the infinite loop detection, collects garbage, and then loads the preset files and folders. It then iterates through any DLC folders and loads the preset folders from those as well.
---
--- After loading the data, it performs some preprocessing and postprocessing steps, and then sets the `DataLoaded` flag to `true`. Finally, it collects garbage again and resumes the infinite loop detection.
---
--- @param dlcs table|nil A table of DLC definitions, each with a `folder` field.
function LoadData(dlcs)
	PauseInfiniteLoopDetection("LoadData")
	collectgarbage("collect")
	collectgarbage("stop")

	Msg("DataLoading")
	MsgClear("DataLoading")

	LoadPresetFiles("CommonLua/Data")
	LoadPresetFolders("CommonLua/Data")
	ForEachLib("Data", function (lib, path)
		LoadPresetFiles(path)
		LoadPresetFolders(path)
	end)
	LoadPresetFolder("Data")
	
	for _, dlc in ipairs(dlcs or empty_table) do
		LoadPresetFolder(dlc.folder .. "/Presets")
	end
	Msg("DataPreprocess")
	MsgClear("DataPreprocess")
	Msg("DataPostprocess")
	MsgClear("DataPostprocess")
	Msg("DataLoaded")
	MsgClear("DataLoaded")
	DataLoaded = true
	
	local mem = collectgarbage("count")
	collectgarbage("collect")
	collectgarbage("restart")
	-- printf("Load Data mem %dk, peak %dk", collectgarbage("count"), mem)
	ResumeInfiniteLoopDetection("LoadData")
end

---
--- Waits for the game data to be fully loaded.
---
--- This function blocks until the `DataLoaded` flag is set to `true`, indicating that all necessary game data has been loaded.
---
--- @function WaitDataLoaded
--- @return nil
function WaitDataLoaded()
	if not DataLoaded then
		WaitMsg("DataLoaded")
	end
end

if Platform.xbox then
	local oldLoadDlcs = LoadDlcs
	function LoadDlcs(...)
		SuspendSigninChecks("load dlcs")
		SuspendInviteChecks("load dlcs")
		sprocall(oldLoadDlcs, ...)
		ResumeSigninChecks("load dlcs")
		ResumeInviteChecks("load dlcs")
	end
end


function OnMsg.BugReportStart(print_func)
	local list = GetAvailableDlcList()
	table.sort(list)
	print_func("Dlcs: " .. table.concat(list, ", "))
end

---
--- Returns a list of DLC combo items, including the additional item if provided.
---
--- The list includes all non-deprecated DLC definitions, with the name and title of each DLC.
--- If the name and title differ, the title is displayed in parentheses after the name.
--- If an additional item is provided, it is inserted at index 2 in the list.
---
--- @param additional_item table|nil The additional item to insert in the list
--- @return table The list of DLC combo items
---
function DlcComboItems(additional_item)
	local items = {{ text = "", value = ""}}
	for _, def in ipairs(DlcDefinitions) do
		if not def.deprecated then
			local name, title = def.name, def.title
			if name ~= title then
				title = name .. " (" .. title .. ")"
			end
			items[#items + 1] = {text = title, value = name}
		end
	end
	if additional_item then
		table.insert(items, 2, additional_item)
	end
	return items
end

---
--- Returns a function that provides a list of DLC combo items, including the additional item if provided.
---
--- The list includes all non-deprecated DLC definitions, with the name and title of each DLC.
--- If the name and title differ, the title is displayed in parentheses after the name.
--- If an additional item is provided, it is inserted at index 2 in the list.
---
--- @param additional_item table|nil The additional item to insert in the list
--- @return function A function that returns the list of DLC combo items
---
function DlcCombo(additional_item)
	return function()
		return DlcComboItems(additional_item)
	end
end

---
--- Downloads the specified DLC content files.
---
--- This function downloads the specified DLC content files from the network and saves them to the local file system.
--- It creates the necessary directories, downloads the files, and renames the downloaded files to the correct names.
---
--- @param list table A list of DLC names to download
--- @param progress function A callback function to report the download progress
--- @return string An error message if the download fails, or "disconnected" if the network is not connected
---
function RedownloadContent(list, progress)
	if not NetIsConnected() then return "disconnected" end
	progress(0)
	AsyncCreatePath("AppData/DLC")
	AsyncCreatePath("AppData/DownloadedDLC")
	for i = 1, #list do
		local dlc_name = list[i]
		local name = dlc_name .. ".hpk"
		local download_file = string.format("AppData/DownloadedDLC/%s.download", dlc_name)
		local dlc_file = string.format("AppData/DLC/%s.hpk", dlc_name)
		local err, def = NetCall("rfnGetContentDef", name)
		if not err and def then
			local err, local_def = CreateContentDef(download_file, def.chunk_size)
			if err == "Path Not Found" or err == "File Not Found" then
				err, local_def = CreateContentDef(dlc_file, def.chunk_size)
			end
			if local_def then local_def.name = name end
			local start_progress = 100 * (i - 1) / #list
			local file_progress = 100 * i / #list - start_progress
			start_progress = start_progress + file_progress / 10
			progress(start_progress)
			err = NetDownloadContent(download_file, def, 
				function (x, y) 
					progress(start_progress + MulDivRound(file_progress * 9 / 10, x, y))
				end, 
				local_def)
			if not err then
				local downloaded_dlc_file = string.format("AppData/DownloadedDLC/%s.hpk", dlc_name)
				os.remove(downloaded_dlc_file)
				os.rename(download_file, downloaded_dlc_file)
			end
		end
		progress(100 * i / #list)
	end
end

---
--- Copies downloaded DLC files from the "AppData/DownloadedDLC" directory to the "AppData/DLC" directory.
---
--- This function first creates the necessary directories if they don't already exist. It then lists all the .hpk files in the "AppData/DownloadedDLC" directory and copies them to the "AppData/DLC" directory. If the copy operation fails, the function deletes the file from the "AppData/DownloadedDLC" directory.
---
--- @return string An error message if the operation fails, or nil if successful.
---
function CopyDownloadedDLCs()
	AsyncCreatePath("AppData/DLC")
	AsyncCreatePath("AppData/DownloadedDLC")
	local err, new_dlcs = AsyncListFiles("AppData/DownloadedDLC", "*.hpk", "relative")
	if err then return err end
	for i = 1, #new_dlcs do
		local src = "AppData/DownloadedDLC/" .. new_dlcs[i]
		if not AsyncCopyFile(src, "AppData/DLC/" .. new_dlcs[i], "raw") then
			AsyncFileDelete(src)
		end
	end
end

---
--- Loads the code for all DLC folders.
---
--- This function iterates through the `DlcFolders` table and calls the `dofolder` function for each DLC folder's "Code/" subdirectory. This allows the code in the DLC folders to be loaded and executed.
---
--- @return nil
---
function DlcsLoadCode()
	for i = 1, #(DlcFolders or "") do
		dofolder(DlcFolders[i] .. "/Code/")
	end
end

---
--- Reloads the available DLC folders and updates the global state accordingly.
---
--- This function is responsible for reloading the DLC folders and updating the global state to reflect the current DLC configuration. It performs the following steps:
---
--- 1. Opens the pre-game main menu.
--- 2. Resets the `DlcFolders` table to `false`.
--- 3. Removes any disabled DLCs from the `g_AvailableDlc` table.
--- 4. Saves the updated local storage.
--- 5. Purges any presets that are saved in the "Data" folder, as they need to be reloaded.
--- 6. Calls the `LoadDlcs` function with the "force reload" argument.
---
--- This function is typically called when the DLC configuration has changed, such as when a DLC is enabled or disabled.
---
function ReloadDevDlcs()
	CreateRealTimeThread(function()
		OpenPreGameMainMenu()
		DlcFolders = false
		for dlc in pairs(LocalStorage.DisableDLC or empty_table) do
			g_AvailableDlc[dlc] = nil
		end
		SaveLocalStorage()
		ClassDescendants("Preset", function(name, preset, Presets)
			--purge presets, which are saved in Data, we are reloading it
			if preset:GetSaveFolder() == "Data" then
				if preset.GlobalMap then
					_G[preset.GlobalMap] = {}
				end
				Presets[preset.PresetClass or name] = {}
			end
		end, Presets)
		LoadDlcs("force reload")
	end)
end

---
--- Sets the enabled/disabled state of all DLC folders.
---
--- This function iterates through all the DLC folders in the "svnProject/Dlc/" directory and sets their enabled/disabled state in the `LocalStorage.DisableDLC` table. If the state of a DLC folder has changed, it calls the `ReloadDevDlcs` function to update the global state.
---
--- @param enable boolean Whether to enable or disable all DLC folders
---
function SetAllDevDlcs(enable)
	local disabled  = not enable
	LocalStorage.DisableDLC = LocalStorage.DisableDLC or {}
	for _, file in ipairs(io.listfiles("svnProject/Dlc/", "*", "folders")) do
		local dlc = string.gsub(file, "svnProject/Dlc/", "")
		if (LocalStorage.DisableDLC[dlc] or false) ~= disabled then
			LocalStorage.DisableDLC[dlc] = disabled
			DelayedCall(0, ReloadDevDlcs)
		end
	end
end

---
--- Saves the given DLC ownership data to disk, encrypting it with the provided encryption key.
---
--- The function first checks if the current machine has a valid machine ID. If so, it adds the machine ID to the data and then saves the encrypted data to the specified file path.
---
--- @param data table The DLC ownership data to save to disk.
--- @param file_path string The file path to save the data to.
---
function SaveDLCOwnershipDataToDisk(data, file_path)
	local machine_id = GetMachineID()
	if (machine_id or "") ~= "" then -- don't save to disk without machine id
		data.machine_id = machine_id
		--encrypt data and machine id and save to disk
		SaveLuaTableToDisk(data, file_path, g_encryption_key)
	end
end

---
--- Loads DLC ownership data from the specified file path.
---
--- This function first checks if the specified file path exists. If it does, it attempts to decrypt the file and load the DLC ownership data. If the decryption is successful and the data contains a valid machine ID that matches the current machine, the function removes the machine ID from the data and returns it. If the file does not exist or the decryption fails, the function returns an empty table.
---
--- @param file_path string The file path to load the DLC ownership data from.
--- @return table The DLC ownership data, or an empty table if the data could not be loaded.
---
function LoadDLCOwnershipDataFromDisk(file_path)
	if io.exists(file_path) then
		--decrypt the file
		local data, err = LoadLuaTableFromDisk(file_path, nil, g_encryption_key)
		if not err then
			if data and (data.machine_id or "") == GetMachineID() then -- check against current machine id
				data.machine_id = nil -- remove the machine_id from the data, no need for it
				return data
			end
		end
	end
	return {}
end
