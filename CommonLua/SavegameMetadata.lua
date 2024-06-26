GameVar("SavegameMeta", false)
MapVar("LoadedRealTime", false)
PersistableGlobals.SavegameMeta = false
PersistableGlobals.LoadedRealTime = false

local modid_props = {}
function OnMsg.ClassesBuilt()
	if not config.Mods then return end
	for i, prop_meta in ipairs(ModDef.properties) do
		if prop_meta.modid then
			table.insert(modid_props, prop_meta.id)
		end
	end
end
---
--- Returns a table containing information about the currently loaded mods.
--- The table contains an entry for each loaded mod, with the following fields:
---   - id: the unique identifier of the mod
---   - title: the title of the mod
---   - version: the version of the mod
---   - lua_revision: the Lua revision the mod was saved with
---   - saved_with_revision: the Lua revision the mod was saved with
---   - source: the source of the mod (e.g. "Steam", "GOG", etc.)
---   - [modid_props]: any additional properties defined in the mod's metadata
---
--- @return table The table of loaded mod information
function GetLoadedModsSavegameData()
	if not config.Mods then return end
	local active_mods = SavegameMeta and SavegameMeta.active_mods or {}
	for _, mod in ipairs(ModsLoaded or empty_table) do
		local idx = table.find(active_mods, "id", mod.id) or (#active_mods + 1)
		local mod_info = {
			id = mod.id,
			title = mod.title,
			version = mod.version,
			lua_revision = mod.lua_revision,
			saved_with_revision = mod.saved_with_revision,
			source = mod.source,
		}
		for i, prop_id in ipairs(modid_props) do
			mod_info[prop_id] = rawget(mod, prop_id)
		end
		active_mods[idx] = mod_info
	end
	return active_mods
end

---
--- Returns a list of all resources affected by the currently loaded mods.
---
--- This function first checks if the `ModsAffectedResourcesCache` is valid. If not, it calls `FillModsAffectedResourcesCache()` to populate the cache.
---
--- The function then iterates through the `ModsAffectedResourcesCache` table, excluding the `"valid"` key, and collects the `ResourceTextDescription` of each affected object. The resulting list of affected resources is returned.
---
--- @return table A list of resource text descriptions affected by the currently loaded mods
function GetAllLoadedModsAffectedResources()
	if not config.Mods then return end
	if not ModsAffectedResourcesCache or not ModsAffectedResourcesCache.valid then
		FillModsAffectedResourcesCache()
	end
	
	local affected_resources = {}
	for _, class in pairs(ModsAffectedResourcesCache) do
		if class ~= "valid" then
			for _, affectedObj in ipairs(class) do
				table.insert(affected_resources, affectedObj:GetResourceTextDescription())
			end
		end
	end
	return affected_resources
end

---
--- Gathers game metadata for a savegame, including the active mods, affected resources, and other relevant information.
---
--- @param params table Optional table of parameters, including whether to include the full terrain data.
--- @return table The gathered game metadata, including the map name, active mods, affected resources, and other relevant information.
function GatherGameMetadata(params)
	assert(LuaRevision and LuaRevision ~= 0, "LuaRevision should never be 0 at this point")
	params = params or empty_table
	local save_terrain_grid_delta = config.SaveTerrainGridDelta and not params.include_full_terrain
	local map = RemapMapName(GetMapName())
	local mapdata = MapData[map] or mapdata
	local metadata = {
		map = map,
		active_mods = GetLoadedModsSavegameData(),
		mod_affected_resources = GetAllLoadedModsAffectedResources(),
		BaseMapNetHash = save_terrain_grid_delta and mapdata.NetHash or nil,
		TerrainHash = save_terrain_grid_delta and mapdata.TerrainHash or nil,
		GameTime = GameTime(),
		broken = SavegameMeta and SavegameMeta.broken or nil,
		ignored_mods = SavegameMeta and SavegameMeta.ignored_mods or nil,
	}
	Msg("GatherGameMetadata", metadata)
	config.BaseMapFolder = save_terrain_grid_delta and GetMapFolder(map) or ""
	
	return metadata
end

---
--- Checks if any mods are missing or outdated in the list of active mods.
---
--- @param active_mods table A list of active mods, where each mod is a table containing the mod's id, title, version, and lua_revision, or just the mod's id in older saves.
--- @param missing_mods_list table A table to store the missing or outdated mods.
---
function GetMissingMods(active_mods, missing_mods_list)
	--check if any mods are missing or outdated
	for _, mod in ipairs(active_mods or empty_table) do
		--mod is a table, containing id, title, version and lua_revision or is just the id in older saves
		local blacklistedReason = GetModBlacklistedReason(mod.id)
		local local_mod = table.find_value(ModsLoaded, "id", mod.id or mod) or Mods[mod.id or mod]
		--possible problems
		local deprecated = not Platform.developer and blacklistedReason and blacklistedReason == "deprecate" --in dev we want to count deprecated as missing
		local missing = not local_mod
		local too_old = (mod.lua_revision or 9999999) < ModMinLuaRevision
		local disabled = local_mod and not table.find(AccountStorage.LoadMods, mod.id or mod)
		local old_local = local_mod and local_mod.version < (mod.version or 0)
		
		if not deprecated and (missing or too_old or disabled or old_local) then
			missing_mods_list[#missing_mods_list + 1] = table.copy(mod)
		end
	end
end

---
--- Displays a dialog to the user asking if they want to load the game anyway, despite some issues with the savegame.
---
--- @param err string The error message to display to the user.
--- @param alt_option string An optional alternative choice to display in the dialog.
--- @return boolean Whether the user chose to load the game anyway.
--- @return boolean Whether the user chose the alternative option.
function LoadAnyway(err, alt_option)
	DebugPrint("\nLoad anyway", ":", _InternalTranslate(err), "\n\n")
	local default_load_anyway = config.DefaultLoadAnywayAnswer
	if default_load_anyway ~= nil then
		return default_load_anyway
	end
	local parent = GetLoadingScreenDialog() or terminal.desktop
	local choice = WaitMultiChoiceQuestion(parent, T(1000599, "Warning"), err, nil, T(3686, "Load anyway"), T(1000246, "Cancel"), alt_option)
	return choice ~= 2, choice == 3
end

---
--- Validates the metadata of a saved game, checking for missing DLCs, outdated Lua revision, and other issues.
---
--- @param metadata table The metadata of the saved game.
--- @param broken table A table to store any issues found with the saved game.
--- @param missing_mods_list table A table to store any missing or outdated mods.
--- @return string|nil An error message if the saved game cannot be loaded, or nil if it can be loaded.
---
function ValidateSaveMetadata(metadata, broken, missing_mods_list)
	if metadata.dlcs then
		local missing_dlc = false
		local load_anyway_enabled = true
		for _, dlc in ipairs(metadata.dlcs) do
			if not IsDlcAvailable(dlc.id) then
				missing_dlc = true
				if Platform.developer then
					local dlc_preset = FindPreset("DLCConfig", dlc.id)
					load_anyway_enabled = load_anyway_enabled and not dlc_preset or dlc_preset.load_anyway
				end
			end
		end
		
		if Platform.developer and missing_dlc and load_anyway_enabled then
			if not LoadAnyway(T(1000849, "The game cannot be loaded because some required downloadable content is not installed.")) then
				return "missing dlc"
			else
				broken = table.create_set(broken, "MissingDLC", true)
			end
		elseif missing_dlc then
			WaitMessage(GetLoadingScreenDialog() or terminal.desktop,
				T(1000599, "Warning"),
				T(1000849, "The game cannot be loaded because some required downloadable content is not installed."),
				T(1000136, "OK"))
			return "missing dlc"
		end
	end
	
	if (metadata.lua_revision or 0) < config.SupportedSavegameLuaRevision then
		if not LoadAnyway(T(3685, "This savegame is from an old version and may not function properly.")) then
			return "old version"
		end
		broken = table.create_set(broken, "WrongLuaRevision", true)
	end
	
	if not broken and metadata.broken then
		if not LoadAnyway(T(1000851, "This savegame was loaded in the past with ignored errors. It may not function properly.")) then
			return "saved broken"
		end
	end
	
	return GameSpecificValidateSaveMetadata(metadata, broken, missing_mods_list)
end

--stub
function GameSpecificValidateSaveMetadata()
end

---
--- Loads the metadata for a savegame and performs various validation checks on it.
---
--- @param folder string The folder containing the savegame files.
--- @param params table Additional parameters to pass to the callback functions.
--- @return string|nil An error message if there was a problem loading the metadata, or nil if successful.
function LoadMetadataCallback(folder, params)
	local st = GetPreciseTicks()
	local err, metadata = LoadMetadata(folder)
	if err then return err end
	
	DebugPrint("Load Game:",
		"\n\tlua_revision:", metadata.lua_revision,
		"\n\tassets_revision:", metadata.assets_revision,
	"\n")
	if metadata.dlcs and #metadata.dlcs > 0 then
		DebugPrint("\n\tdlcs:", table.concat(table.map(metadata.dlcs, "id"), ", "), "\n")
	end
	if metadata.active_mods and #metadata.active_mods > 0 then
		DebugPrint("\n\tmods:", table.concat(table.map(metadata.active_mods, "id"), ", "), "\n")
	end
	
	local broken, change_current_map
	local map_name = RemapMapName(metadata.map)
	config.BaseMapFolder = ""
	if map_name and metadata.BaseMapNetHash then
		local map_meta = MapData[map_name]
		assert(map_meta)
		local terrain_hash = metadata.TerrainHash
		local requested_map_hash = terrain_hash or metadata.BaseMapNetHash
		local map_hash = map_meta and (terrain_hash and map_meta.TerrainHash or map_meta.NetHash)
		local different_map = requested_map_hash ~= map_hash
		if different_map and config.TryRestoreMapVersionOnLoad then
			for map_id, map_data in pairs(MapData) do
				local map_data_hash = terrain_hash and map_data.TerrainHash or map_data.NetHash
				if map_data_hash == requested_map_hash and (not config.CompatibilityMapTest or map_data.ForcePackOld) then
					map_name = map_id
					different_map = false
					change_current_map = true
					break
				end
			end
		end
		if different_map then
			if not LoadAnyway(T(840159075107, "The game cannot be loaded because it requires a map that is not present or has a different version.")) then
				return "different map"
			end
			broken = table.create_set(broken, "DifferentMap", true)
			if not map_meta then
				map_name = GetOrigMapName(map_name)
			end
		end
		config.BaseMapFolder = GetMapFolder(map_name)
		if CurrentMapFolder ~= "" then
			UnmountByPath(CurrentMapFolder)
		end
		CurrentMapFolder = config.BaseMapFolder
		local err = PreloadMap(map_name)
		CurrentMapFolder = "" -- so that ChangeMap("") will not unmount the map we just mounted
		if err then
			return err
		end
	end
	
	local missing_mods_list = {}
	local validate_error = ValidateSaveMetadata(metadata, broken, missing_mods_list)
	if validate_error then
		return validate_error
	end
	
	err = GameSpecificLoadCallback(folder, metadata, params)
	if err then return err end
	
	if change_current_map then
		CurrentMap = map_name
		CurrentMapFolder = GetMapFolder(map_name)
		_G.mapdata = MapData[map_name]
	end

	metadata.broken = metadata.broken or broken or false
	if next(missing_mods_list) then
		metadata.ignored_mods = metadata.ignored_mods or {}
		missing_mods_list = table.filter(missing_mods_list, function(idx, mod) return not table.find(metadata.ignored_mods, "id", mod.id) end)
		table.iappend(metadata.ignored_mods, missing_mods_list)
	end
	metadata.active_mods = GetLoadedModsSavegameData()
	SavegameMeta = metadata
	LoadedRealTime = RealTime()
	DebugPrint("Game Loaded in", GetPreciseTicks() - st, "ms\n")
	Msg("GameMetadataLoaded", metadata)
end

---
--- Returns the original real time value from the loaded savegame, or the current real time if no savegame is loaded.
---
--- The original real time value is stored in the `SavegameMeta.real_time` field when a savegame is loaded. This function calculates the current real time offset from the loaded real time to provide the original real time value.
---
--- @return number The original real time value from the loaded savegame, or the current real time if no savegame is loaded.
function GetOrigRealTime()
	local orig_real_time = LoadedRealTime and SavegameMeta and SavegameMeta.real_time
	if not orig_real_time then
		return RealTime()
	end
	return (RealTime() - LoadedRealTime) + orig_real_time
end

MapVar("OrigLuaRev", function()
	return LuaRevision
end)
MapVar("OrigAssetsRev", function()
	return AssetsRevision
end)

---
--- Handles the start of a bug report by printing information about the savegame and game start revisions.
---
--- If a savegame is loaded, this function will print the savegame's Lua revision and whether it is supported, as well as the savegame's assets revision.
---
--- If the game start Lua revision is different from the original Lua revision, this function will print the original Lua and assets revisions.
---
--- If the savegame has any errors, this function will print a list of the savegame error keys.
---
--- @param print_func function The function to use for printing the bug report information.
---
function OnMsg.BugReportStart(print_func)
	local lua_revision = SavegameMeta and SavegameMeta.lua_revision
	if lua_revision then
		local supported_str = lua_revision >= config.SupportedSavegameLuaRevision and "/" or " (unsupported!) /"
		print_func("Savegame Rev:", lua_revision, supported_str, SavegameMeta.assets_revision)
	end
	if OrigLuaRev and OrigLuaRev ~= LuaRevision then
		print_func("Game Start Rev:", OrigLuaRev, OrigAssetsRev)
	end
	if SavegameMeta and type(SavegameMeta.broken) == "table" then
		print_func("Savegame Errors:", table.concat(table.keys(SavegameMeta.broken, true), ','))
	end
end