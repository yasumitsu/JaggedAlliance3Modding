local function IsGedAppOpened(template_id)
	if not rawget(_G, "GedConnections") then return false end
	for key, conn in pairs(GedConnections) do
		if conn.app_template == template_id then
			return true
		end
	end
	return false
end

--- Checks if the Mod Editor Ged application is currently opened.
---
--- @return boolean true if the Mod Editor Ged application is opened, false otherwise
function IsModEditorOpened()
	return IsGedAppOpened("ModEditor")
end

--- Checks if the Mod Manager Ged application is currently opened.
---
--- @return boolean true if the Mod Manager Ged application is opened, false otherwise
function IsModManagerOpened()
	return IsGedAppOpened("ModManager")
end

ModEditorMapName = "ModEditor"
---
--- Checks if the given map name matches the ModEditor map name or if the map data indicates that the map is a ModEditor map.
---
--- @param map_name string|nil The name of the map to check. If not provided, the current map name will be used.
--- @return boolean true if the map is a ModEditor map, false otherwise
function IsModEditorMap(map_name)
	map_name = map_name or GetMapName()
	return map_name == ModEditorMapName or (table.get(MapData, map_name, "ModEditor") or false)
end

function OnMsg.UnableToUnlockAchievementReasons(reasons, achievement)
	if AreModdingToolsActive() then
		reasons["modding tools active"] = true
	end
end

if not config.Mods then	return end

if FirstLoad then
	ModUploadThread = false
	LastEditedMod = false -- the last mod that was opened or edited in a Mod Editor Ged application
end

---
--- Opens the Mod Editor Ged application for the specified mod.
---
--- @param mod table The mod to open in the Mod Editor.
--- @return table|nil The Ged application instance, or nil if it could not be opened.
function OpenModEditor(mod)
	local editor = GedConnections[mod.mod_ged_id]
	if editor then
		local activated = editor:Call("rfnApp", "Activate")
		if activated ~= "disconnected" then
			return editor
		end
	end
	
	LoadLuaParticleSystemPresets()
	for _, presets in pairs(Presets) do
		if class ~= "ListItem" then
			PopulateParentTableCache(presets)
		end
	end
	
	local mod_path = ModConvertSlashes(mod:GetModRootPath())
	local context = {
		mod_items = GedItemsMenu("ModItem"),
		dlcs = g_AvailableDlc or { },
		mod_path = mod_path,
		mod_os_path = ConvertToOSPath(mod_path),
		mod_content_path = mod:GetModContentPath(),
		WarningsUpdateRoot = "root",
		suppress_property_buttons = {
			"GedOpPresetIdNewInstance",
			"GedRpcEditPreset",
			"OpenTagsEditor",
		},
	}
	Msg("GatherModEditorLogins", context)
	local container = Container:new{ mod }
	UpdateParentTable(mod, container)
	editor = OpenGedApp("ModEditor", container, context)
	if editor then 
		editor:Send("rfnApp", "SetSelection", "root", { 1 }) 
		editor:Send("rfnApp", "SetTitle", string.format("Mod Editor - %s", mod.title))
		mod.mod_ged_id = editor.ged_id
	end
	return editor
end

function OnMsg.GedOpened(ged_id)
	local conn = GedConnections[ged_id]
	if conn and conn.app_template == "ModEditor" then
		SetUnmuteSoundReason("ModEditor") -- disable mute when unfocused in order to be able to test sound mod items
	end
	
	if conn and (conn.app_template == "ModEditor" or conn.app_template == "ModManager") then
		ReloadShortcuts()
	end
end

function OnMsg.GedClosing(ged_id)
	local conn = GedConnections[ged_id]
	if conn and conn.app_template == "ModEditor" then
		ClearUnmuteSoundReason("ModEditor") -- disable mute when unfocused in order to be able to test sound mod items
	end
end

function OnMsg.GedClosed(ged)
	if ged and (ged.app_template == "ModEditor" or ged.app_template == "ModManager") then
		DelayedCall(0, ReloadShortcuts)
	end
end

---
--- Opens the mod editor or the mod manager, depending on the provided mod parameter.
---
--- If a mod is provided, the mod editor is opened for that mod. If no mod is provided, the mod manager is opened.
---
--- If the current map is not the mod editor map, the map is changed to the mod editor map and any open menu dialogs are closed.
---
--- @param mod table|nil The mod to open the editor for, or nil to open the mod manager.
---
function WaitModEditorOpen(mod)
	if not IsModEditorMap(CurrentMap) then
		ChangeMap(ModEditorMapName)
		CloseMenuDialogs()
	end
	if mod then
		OpenModEditor(mod)
	else
		if IsModManagerOpened() then return end
		local context = {
			dlcs = g_AvailableDlc or { },
		}
		SortModsList()
		local ged = OpenGedApp("ModManager", ModsList, context)
		if ged then ged:BindObj("log", ModMessageLog) end
		if LocalStorage.OpenModdingDocs == nil or LocalStorage.OpenModdingDocs then
			if not Platform.developer then
				GedOpHelpMod()
			end
		end
	end
end

---
--- Opens the mod editor or the mod manager, depending on the provided mod parameter.
---
--- If a mod is provided, the mod editor is opened for that mod. If no mod is provided, the mod manager is opened.
---
--- If the current map is not the mod editor map, the map is changed to the mod editor map and any open menu dialogs are closed.
---
--- @param mod table|nil The mod to open the editor for, or nil to open the mod manager.
---
function ModEditorOpen(mod)
	CreateRealTimeThread(WaitModEditorOpen)
end

---
--- Formats a table of strings into a single string, with each element separated by a newline.
---
--- @param obj table A table of strings to be formatted.
--- @return string The formatted string.
---
function GedModMessageLog(obj)
	return table.concat(obj, "\n")
end

function OnMsg.NewMapLoaded()
	if config.Mods then
		ReloadShortcuts()
	end
end

function OnMsg.ModsReloaded()
	if IsModManagerOpened() then
		SortModsList()
	end
end

---
--- Updates the property panels of all open mod editors.
---
--- This function iterates through all open Ged connections and checks if the application template is "ModEditor". If so, it resolves the "SelectedObject" and marks it as modified, which will trigger a refresh of the property panels.
---
--- This function is typically called when the selected object in a mod editor has changed, to ensure the property panels display the correct information for the new selection.
---
--- @return nil
---
function UpdateModEditorsPropPanels()
	for id, ged in pairs(GedConnections) do
		if ged.app_template == "ModEditor" then
			local selected_obj = ged:ResolveObj("SelectedObject")
			if selected_obj then
				ObjModified(selected_obj)
			end
		end
	end
end


----- Ged Ops (Mods)

---
--- Creates a new mod with the given title.
---
--- This function prompts the user to enter a mod title, and then creates a new mod with that title. If the title is empty or invalid, an error message is shown to the user.
---
--- @param socket table The Ged socket object.
--- @param obj table The Ged object.
--- @return number|nil The index of the newly created mod in the ModsList table, or nil if the operation failed.
---
function GedOpNewMod(socket, obj)
	local title = socket:WaitUserInput(T(200174645592, "Enter Mod Title"), "")
	if not title then return end
	title = title:trim_spaces()
	if #title == 0 then
		socket:ShowMessage(T(634182240966, "Error"), T(112659155240, "No name provided"))
		return
	end
	local err, mod = CreateMod(title)
	if err then
		socket:ShowMessage(GetErrorTitle(err, "mods", mod), GetErrorText(err, "mods"))
		return
	end
	return table.find(ModsList, mod)
end

---
--- Loads a mod from the ModsList.
---
--- This function adds the mod's ID to the AccountStorage.LoadMods table, which indicates that the mod should be loaded. It then triggers the "OnGedLoadMod" message, which can be used by other systems to react to the mod being loaded. Finally, it reloads the mod items and marks the ModsList as modified, which will trigger a refresh of the UI.
---
--- @param socket table The Ged socket object.
--- @param obj table The Ged object.
--- @param item_idx number The index of the mod in the ModsList table.
--- @return nil
---
function GedOpLoadMod(socket, obj, item_idx)
	local mod = ModsList[item_idx]
	if mod.items then return end
	table.insert_unique(AccountStorage.LoadMods, mod.id)
	Msg("OnGedLoadMod", mod.id)
	ModsReloadItems()
	ObjModified(ModsList)
end

---
--- Unloads a mod from the ModsList.
---
--- This function removes the mod's ID from the AccountStorage.LoadMods table, which indicates that the mod should no longer be loaded. It then triggers the "OnGedUnloadMod" message, which can be used by other systems to react to the mod being unloaded. Finally, it closes any open mod editors for that mod, reloads the mod items, and marks the ModsList as modified, which will trigger a refresh of the UI.
---
--- @param socket table The Ged socket object.
--- @param obj table The Ged object.
--- @param item_idx number The index of the mod in the ModsList table.
--- @return nil
---
function GedOpUnloadMod(socket, obj, item_idx)
	local mod = ModsList[item_idx]
	if not mod.items then return end
	table.remove_value(AccountStorage.LoadMods, mod.id)
	Msg("OnGedUnloadMod", mod.id)
	-- close Mod editor for that mod (mod-editing assumes that the mod is loaded)
	for id, ged in pairs(GedConnections) do
		if ged.app_template == "ModEditor" then
			local root = ged:ResolveObj("root")
			if root and root[1] == mod then
				ged:Close()
			end 
		end
	end
	ModsReloadItems()
	ObjModified(ModsList)
end

---
--- Opens a mod for editing in the Ged mod editor.
---
--- This function first checks if the current thread is a real-time thread. If not, it creates a new real-time thread and calls itself. This ensures that the mod editing operation is performed in a real-time thread.
---
--- If the mod is already being opened for editing, the function returns without doing anything.
---
--- If the mod is not in the "appdata" or "additional" source, or if it is packed, the function copies the mod files to a temporary location in the "AppData/Mods" directory. It then updates the mod's paths and mounts the content.
---
--- Finally, the function ensures that the mod is loaded by adding its ID to the `AccountStorage.LoadMods` table, triggering the "OnGedLoadMod" message, and reloading the mod items. It then waits for the mod editor to open.
---
--- @param socket table The Ged socket object.
--- @param obj table The Ged object.
--- @param item_idx number The index of the mod in the ModsList table.
--- @return nil
---
function GedOpEditMod(socket, obj, item_idx)
	if not IsRealTimeThread() then
		return CreateRealTimeThread(GedOpEditMod, socket, obj, item_idx)
	end
	local mod = ModsList[item_idx]
	if not mod or IsValidThread(mod.mod_opening) then return end
	if not CanLoadUnpackedMods() then
		ModLog(true, T{970080750583, "Error opening <ModLabel> for editing: cannot open unpacked mods", mod})
		return
	end
	mod.mod_opening = CurrentThread()
	local force_reload
	-- copy if not in AppData or svnAssets
	if (mod.source ~= "appdata" and mod.source ~= "additional") or mod.packed then
		local mod_folder = mod.title:gsub('[/?<>\\:*|"]', "_")
		local unpack_path = string.format("AppData/Mods/%s/", mod_folder)
		unpack_path = string.gsub(ConvertToOSPath(unpack_path), "\\", "/")
		
		local base_unpack_path, i = string.sub(unpack_path, 1, -2), 0
		while io.exists(unpack_path) do
			 i = i + 1
			 unpack_path = base_unpack_path .. " " .. tostring(i) .. "/"
		end
		
		local res = socket:WaitQuestion(T(521819598348, "Confirm Copy"), T{814173350691, "Mod '<u(title)>' files will be copied to <u(path)>", mod, path = unpack_path})
		if res ~= "ok" then
			return
		end
		GedSetUiStatus("mod_unpack", "Copying...")
		ModLog(T{348544010518, "Copying <ModLabel> to <u(path)>", mod, path = unpack_path})
		AsyncCreatePath(unpack_path)
		local err
		if mod.packed then
			local pack_path = mod.path .. ModsPackFileName
			err = AsyncUnpack(pack_path, unpack_path)
		else
			local folders
			err, folders = AsyncListFiles(mod.content_path, "*", "recursive,relative,folders")
			if not err then
				--create folder structure
				for _, folder in ipairs(folders) do
					local err = AsyncCreatePath(unpack_path .. folder)
					if err then
						ModLog(true, T{311163830130, "Error creating folder <u(folder)>: <u(err)>", folder = folder, err = err})
						break
					end
				end
				--copy all files
				local files
				err, files = AsyncListFiles(mod.content_path, "*", "recursive,relative")
				if not err then
					for _,file in ipairs(files) do
						local err = AsyncCopyFile(mod.content_path .. file, unpack_path .. file, "raw")
						if err then
							ModLog(true, T{403285832388, "Error copying <u(file)>: <u(err)>", file = file, err = err})
						end
					end
				else
					ModLog(true, T{600384081290, "Error looking up files of <ModLabel>: <u(err)>", mod, err = err})
				end
			else
				ModLog(true, T{836115199867, "Error looking up folders of <ModLabel>: <u(err)>", mod, err = err})
			end
		end
		GedSetUiStatus("mod_unpack")
		
		if not err then
			mod:UnmountContent()
			mod:ChangePaths(unpack_path)
			mod.packed = false
			mod.source = "appdata"
			mod:MountContent()
			force_reload = true
			mod:SaveDef("serialize_only")
		else
			ModLog(true, T{578088043400, "Error copying <ModLabel>: <u(err)>", mod, err = err})
		end
	end
	if force_reload or not mod:ItemsLoaded() then
		table.insert_unique(AccountStorage.LoadMods, mod.id)
		Msg("OnGedLoadMod", mod.id)
		mod.force_reload = true
		ModsReloadItems(nil, "force_reload")
		ObjModified(ModsList)
	end
	if mod:ItemsLoaded() then
		WaitModEditorOpen(mod)
	end
	mod.mod_opening = false
end

---
--- Removes a mod from the ModsList and deletes all its files.
---
--- @param socket table The socket object that triggered the operation.
--- @param obj table The object that triggered the operation.
--- @param item_idx number The index of the mod to be removed in the ModsList.
---
--- @return number The new index of the item after the removal, clamped to the range of the ModsList.
---
function GedOpRemoveMod(socket, obj, item_idx)
	local mod = ModsList[item_idx]
	local reasons = { }
	Msg("GatherModDeleteFailReasons", mod, reasons)
	if next(reasons) then
		socket:ShowMessage(T(634182240966, "Error"), table.concat(reasons, "\n"))
	else
		local res = socket:WaitQuestion(T(118482924523, "Are you sure?"), T{820846615088, "Do you want to delete all <ModLabel> files?", mod})
		if res == "cancel" then return end
		table.remove(ModsList, item_idx)
		local err = DeleteMod(mod)
		if err then
			socket:ShowMessage(GetErrorTitle(err, "mods"), GetErrorText(err, "mods", mod))
		end
		return Clamp(item_idx, 1, #ModsList)
	end
end

---
--- Opens the help documentation for the specified mod document.
---
--- @param socket table The socket object that triggered the operation.
--- @param obj table The object that triggered the operation.
--- @param document string The name of the mod document to open, or nil to open the index.
---
function GedOpHelpMod(socket, obj, document)
	local help_file = string.format("%s", ConvertToOSPath(DocsRoot .. (document or "index.md.html")))
	help_file = string.gsub(help_file, "[\n\r]", "")
	if io.exists(help_file) then
		help_file = string.gsub(help_file, " ", "%%20")
		OpenUrl("file:///" .. help_file, "force external browser")
	end
end

---
--- Changes the dark mode setting for the editor and notifies all connected sockets.
---
--- @param socket table The socket object that triggered the operation.
--- @param obj table The object that triggered the operation.
--- @param choice boolean The new dark mode setting.
---
function GedOpDarkModeChange(socket, obj, choice)
	SetProperty(XEditorSettings, "DarkMode", choice)
	
	for id, dlg in pairs(Dialogs) do 
		if IsKindOf(dlg, "XDarkModeAwareDialog") then 
			dlg:SetDarkMode(GetDarkModeSetting())
		end
	end
	for id, socket in pairs(GedConnections) do
		socket:Send("rfnApp", "SetDarkMode", GetDarkModeSetting())
	end
	ReloadShortcuts()
end

---
--- Toggles the visibility of the modding documentation in the editor.
---
--- @param socket table The socket object that triggered the operation.
--- @param obj table The object that triggered the operation.
--- @param choice boolean The new visibility setting for the modding documentation.
---
function GedOpOpenDocsToggle(socket, obj, choice)
	if LocalStorage.OpenModdingDocs ~= nil then
		LocalStorage.OpenModdingDocs = not LocalStorage.OpenModdingDocs 
	else
		LocalStorage.OpenModdingDocs = false
	end
	SaveLocalStorage()
	socket:Send("rfnApp", "SetActionToggled", "OpenModdingDocs", LocalStorage.OpenModdingDocs)
end

function OnMsg.GedActivated(ged, initial)
	if initial and ged.app_template == "ModManager" then
		ged:Send("rfnApp", "SetActionToggled", "OpenModdingDocs", LocalStorage.OpenModdingDocs == nil or LocalStorage.OpenModdingDocs)
	end
end

---
--- Triggers a cheat function in the global namespace.
---
--- @param socket table The socket object that triggered the operation.
--- @param obj table The object that triggered the operation.
--- @param cheat string The name of the cheat function to trigger.
--- @param ... any Additional arguments to pass to the cheat function.
---
function GedOpTriggerCheat(socket, obj, cheat, ...)
	if string.starts_with(cheat, "Cheat") then 
		local func = rawget(_G, cheat)
		if func then
			func(...)
		end
	end
end

---
--- Creates a new mod with the given title.
---
--- @param title string The title of the new mod.
--- @return string|ModDef, ModDef The error message if an error occurred, or the new ModDef instance.
---
function CreateMod(title)
	for _, mod in ipairs(ModsList) do
		if mod.title == title then return "exists" end
	end
	local path = string.format("AppData/Mods/%s/", title:gsub('[/?<>\\:*|"]', "_"))
	if io.exists(path .. "metadata.lua") then
		return "exists"
	end
	AsyncCreatePath(path)
	
	local authors = {}
	Msg("GatherModAuthorNames", authors)
	local author
	--choose from modding platform (except steam)
	for platform, name in pairs(authors) do
		if platform ~= "steam" then
			author = name
			break
		end
	end
	--fallback to steam name or default
	author = author or authors.steam or "unknown"
	
	local env = LuaModEnv()
	local id = ModDef:GenerateId()
	local mod = ModDef:new{
		title = title,
		author = author,
		id = id,
		path = path,
		content_path = ModContentPath .. id .. "/",
		env = env,
	}
	Msg("ModDefCreated", mod)
	mod:SetupEnv()
	mod:MountContent()
	
	assert(Mods[mod.id] == nil)
	Mods[mod.id] = mod
	ModsList[#ModsList+1] = mod
	SortModsList()
	CacheModDependencyGraph()
	
	local items_err = AsyncStringToFile(path .. "items.lua", "return {}")
	local def_err = mod:SaveDef()
	return (def_err or items_err), mod
end

--- Deletes a mod from the game.
---
--- @param mod ModDef The mod to delete.
--- @return string|nil The error message if an error occurred, or nil if the deletion was successful.
function DeleteMod(mod)
	local err = AsyncDeletePath(mod.path)
	if err then return err end
	Mods[mod.id] = nil
	table.remove_entry(ModsList, mod)
	table.remove_entry(ModsLoaded, mod)
	table.remove_entry(AccountStorage.LoadMods, mod.id)
	Msg("OnGedUnloadMod", mod.id)
	ObjModified(ModsList)
	mod:delete()
end


----- Ged Ops (Mod Items)

---
--- Creates a new mod item in the mod editor.
---
--- @param socket GedSocket The socket to use for the operation.
--- @param root table The root table of the mod definition.
--- @param path table The path to the new item.
--- @param class_or_instance table The class or instance to use for the new item.
--- @return string|nil The error message if an error occurred, or nil if the operation was successful.
function GedOpNewModItem(socket, root, path, class_or_instance)
	if #path == 0 then path = { 1 } end
	if #path == 1 then table.insert(path, #root[1].items) end
	return GedOpTreeNewItem(socket, root, path, class_or_instance)
end

local function GetSelectionBaseClass(root, selection)
	return ParentNodeByPath(root, selection[1]).ContainerClass
end

---
--- Duplicates a mod item in the mod editor.
---
--- @param socket GedSocket The socket to use for the operation.
--- @param root table The root table of the mod definition.
--- @param selection table The selection to duplicate.
--- @return string|nil The error message if an error occurred, or nil if the operation was successful.
function GedOpDuplicateModItem(socket, root, selection)
	local path = selection[1]
	if not path or #path < 2 then return "error" end
	assert(path[1] == 1)
	return GedOpTreeDuplicate(socket, root, selection, GetSelectionBaseClass(root, selection))
end

---
--- Cuts a mod item in the mod editor.
---
--- @param socket GedSocket The socket to use for the operation.
--- @param root table The root table of the mod definition.
--- @param selection table The selection to cut.
--- @return string|nil The error message if an error occurred, or nil if the operation was successful.
function GedOpCutModItem(socket, root, selection)
	local path = selection[1]
	if not path or #path < 2 then return "error" end
	assert(path[1] == 1)
	return GedOpTreeCut(socket, root, selection, GetSelectionBaseClass(root, selection))
end

---
--- Copies a mod item in the mod editor.
---
--- @param socket GedSocket The socket to use for the operation.
--- @param root table The root table of the mod definition.
--- @param selection table The selection to copy.
--- @return string|nil The error message if an error occurred, or nil if the operation was successful.
function GedOpCopyModItem(socket, root, selection)
	local path = selection[1]
	if not path or #path < 2 then return "error" end
	assert(path[1] == 1)
	return GedOpTreeCopy(socket, root, selection, GetSelectionBaseClass(root, selection))
end

---
--- Pastes a mod item in the mod editor.
---
--- @param socket GedSocket The socket to use for the operation.
--- @param root table The root table of the mod definition.
--- @param selection table The selection to paste.
--- @return string|nil The error message if an error occurred, or nil if the operation was successful.
function GedOpPasteModItem(socket, root, selection)
	-- simulate select ModDef/root
	if not selection[1] then 
		selection[1] = { 1 }
		selection[2] = { 1 }
		selection.n = 2 
	end
	-- simulate select last element of ModDef/root
	if #selection[1] == 1 then 
		table.insert(selection[1], #root[1].items)
		selection[2][1] = #root[1].items
	end
	
	return GedOpTreePaste(socket, root, selection)
end

---
--- Deletes a mod item in the mod editor.
---
--- @param socket GedSocket The socket to use for the operation.
--- @param root table The root table of the mod definition.
--- @param selection table The selection to delete.
--- @return string|nil The error message if an error occurred, or nil if the operation was successful.
function GedOpDeleteModItem(socket, root, selection)
	local path = selection[1]
	if not path or #path < 2 then return "error" end
	assert(path[1] == 1)
	
	local items_name_string = ""
	for idx = 1, #selection[2] do
		local leaf = selection[2][idx]
		local item = TreeNodeChildren(ParentNodeByPath(root, path))[leaf]
		local item_name = item.id or item.name or item.__class or item.EditorName or item.class
		items_name_string = idx == 1 and item_name or items_name_string .. "\n" .. item_name
	end
	
	local confirm_text = T{435161105463, "Please confirm the deletion of item '<u(name)>'!", name = items_name_string}
	if #selection[2] ~= 1 then 
		confirm_text = T{621296865915, "Are you sure you want to delete the following <u(number_of_items)> selected items?\n<u(items)>", number_of_items = #selection[2], items = items_name_string}
	end
	if "ok" ~= socket:WaitQuestion(T(986829419084, "Confirmation"), confirm_text) then
		return
	end
	
	return GedOpTreeDeleteItem(socket, root, selection)
end

---
--- Saves the current mod.
---
--- @param ged GedSocket The GedSocket instance.
---
function GedSaveMod(ged)
	local old_root = ged:ResolveObj("root")
	local mod = old_root[1]
	if mod:CanSaveMod(ged) then
		mod:SaveWholeMod()
	end
end

-- reloads the mod to update function debug info, allowing the modder to debug their code after saving
-- (TODO: unused for now, consider adding a button for that when the debugging support is ready)
---
--- Reloads the mod items in the GED mod editor.
---
--- This function is responsible for unloading and reloading the mod items in the GED mod editor. It first retrieves the root object of the mod, then unloads and reloads the mod items. Finally, it updates the parent table and rebinds the root object.
---
--- @param ged GedSocket The GedSocket instance.
---
function GedReloadModItems(ged)
	local old_root = ged:ResolveObj("root")
	local mod = old_root[1]
	GedSetUiStatus("mod_reload_items", "Reloading items...")
	mod:UnloadItems()
	mod:LoadItems()
	local container = Container:new{ mod }
	UpdateParentTable(mod, container)
	GedRebindRoot(old_root, container)
	GedSetUiStatus("mod_reload_items")
end

---
--- Opens the dedicated editor for the specified ModdedPresetClass.
---
--- @param socket GedSocket The GedSocket instance.
--- @param obj Preset The Preset object.
--- @param selection table The selection table.
--- @param a any Unused parameter.
--- @param b any Unused parameter.
--- @param c any Unused parameter.
---
function GedOpOpenModItemPresetEditor(socket, obj, selection, a, b, c)
	if obj and obj.ModdedPresetClass then
		OpenPresetEditor(obj.ModdedPresetClass)
	end
end

---
--- Retrieves the docked actions for a mod item.
---
--- This function is responsible for gathering the docked actions for a mod item. It uses the `OnMsg.GatherModItemDockedActions` message to allow other modules to add their own actions to the list.
---
--- @param obj table The mod item object.
--- @return table The table of docked actions.
---
function GedGetModItemDockedActions(obj)
	local actions = {}
	Msg("GatherModItemDockedActions", obj, actions) -- use this msg to add more actions for mod item that are docked on the bottom right
	return actions
end

function OnMsg.GatherModItemDockedActions(obj, actions)
	if IsKindOf(obj, "Preset") then
		local preset_class = g_Classes[obj.ModdedPresetClass]
		local class = preset_class.PresetClass or preset_class.class
		actions["PresetEditor"] = {
			name = "Open in " .. (preset_class.EditorMenubarName ~= "" and preset_class.EditorMenubarName or (class .. " editor")),
			rolloverText = "Open the dedicated editor for this item,\nalongside the rest of the game content.",
			op = "GedOpOpenModItemPresetEditor"
		}
	end
end

function OnMsg.GatherModItemDockedActions(obj, actions)
	if IsKindOf(obj, "ModItem") and obj.TestModItem ~= ModItem.TestModItem then
		actions["TestModItem"] = {
			name = "Test mod item",
			rolloverText = obj.TestDescription,
			op = "GedOpTestModItem"
		}
	end
end

---
--- Retrieves a list of editable mods for the mod editor combo box.
---
--- This function is responsible for gathering the list of mods that are currently loaded and not packed. The resulting list is used to populate the editable mods combo box in the mod editor.
---
--- @return table The table of mod items to display in the combo box.
---
function GedGetEditableModsComboItems()
	if not ModsLoaded then return empty_table end
	
	local ret = {}
	for idx, mod in ipairs(ModsLoaded) do
		if mod and mod:ItemsLoaded() and not mod:IsPacked() then
			table.insert(ret, { text = mod.title or mod.id, value = mod.id })
		end
	end
	return ret
end

-- Clones the selected Preset to the selected mod as a ModItemPreset so it can be modded
---
--- Clones the selected Preset to the selected mod as a ModItemPreset so it can be modded.
---
--- @param socket The socket object that the operation is being performed on.
--- @param root The root object of the tree where the new ModItemPreset will be added.
--- @param selection_path The path to the selected item in the tree.
--- @param item_class The class of the selected item.
--- @param mod_id The ID of the mod that the new ModItemPreset will be added to.
--- @return table The path to the newly created ModItemPreset, and a function to undo the operation.
---
function GedOpClonePresetInMod(socket, root, selection_path, item_class, mod_id)
	local mod = Mods and Mods[mod_id]
	if not mod or not mod.items then return "Invalid mod selected" end
	
	local selected_preset = socket:ResolveObj("SelectedPreset")
	local path = selection_path and selection_path[1]
	
	-- Check if the preset class has a corersponding mod item class
	local class_or_instance = "ModItem" .. item_class
	local mod_item_class = g_Classes[class_or_instance]
	if not g_Classes[item_class] or not mod_item_class then return "No ModItemPreset class exists for this Preset type" end
	
	-- Create the new ModItemPreset and add it to the tree of the calling Preset Editor
	local item_path, item_undo_fn = GedOpTreeNewItem(socket, root, path, class_or_instance, nil, mod_id)
	if type(item_path) ~= "table" or type(item_undo_fn) ~= "function" then 
		return "Error creating the new mod item"
	end

	-- Copy all properties from the chosen preset using the __copy mod item property (see ModItemPreset:OnEditorSetProperty)
	local item = GetNodeByPath(root, item_path)
	item["__copy_group"] = selected_preset.group
	local prop_id = "__copy"
	local id_value = selected_preset.id
	GedSetProperty(socket, item, prop_id, id_value)
	
	-- Set the same group and id (unique one) like the selected preset and get the new path in the tree
	item:SetGroup(selected_preset.group)
	item:SetId(item:GenerateUniquePresetId(selected_preset.id))
	item_path = RecursiveFindTreeItemPath(root, item)

	return item_path, item_undo_fn
end

---
--- Binds the editable mods combo in Preset Editors, it should contain only loaded mods.
--- Note: Since all bindings require an "obj" whose reference can later be used to update the binding (with GedRebindRoot) 
--- and there's no suitable "obj" to pass here we use empty_table as a kind of dummy constant reference that we can use for updates later.
---
--- @param socket The socket object that the operation is being performed on.
---
function GedOpSetModdingBindings(socket)
	-- Bind the editable mods combo in Preset Editors, it should contain only loaded mods
	-- Note: Since all bindings require an "obj" whose reference can later be used to update the binding (with GedRebindRoot) 
	-- and there's no suitable "obj" to pass here we use empty_table as a kind of dummy constant reference that we can use for updates later
	socket:BindObj("EditableModsCombo", empty_table, GedGetEditableModsComboItems)
	
	-- Don't bind LastEditedMod if that mod is currently not loaded or packed
	if LastEditedMod and Mods then
		local mod = Mods[LastEditedMod.id]
		if mod and mod:ItemsLoaded() and not mod:IsPacked() then
			socket:BindObj("LastEditedMod", mod.id, return_first)
		end
	end
end

function OnMsg.OnGedLoadMod(mod_id)
	GedRebindRoot(empty_table, empty_table, "EditableModsCombo", GedGetEditableModsComboItems, "dont_restore_app_state")
end

function OnMsg.OnGedUnloadMod(mod_id)
	GedRebindRoot(empty_table, empty_table, "EditableModsCombo", GedGetEditableModsComboItems, "dont_restore_app_state")
end

-- Utility function for updating the Mod Editor tree panel for a given mod that changed
---
--- Handles the case where a mod has been modified, by notifying the parent container that the mod has been modified.
---
--- @param mod The mod instance that has been modified.
---
function ObjModifiedMod(mod)
	if not mod then return end
	local mod_container = ParentTableCache[mod]
	-- Check if the given ModDef instance is not the original one
	if not mod_container and mod.id and Mods and Mods[mod.id] then
		mod_container = ParentTableCache[Mods[mod.id]]
	end
	if mod_container then
		ObjModified(mod_container)
	end
end

local function CreatePackageForUpload(mod_def, params)
	local content_path = mod_def.content_path
	local temp_path = "TmpData/ModUpload/"
	local pack_path = temp_path .. "Pack/"
	local shots_path = temp_path .. "Screenshots/"
	
	--clean old files in ModUpload & recreate folder structure
	AsyncDeletePath(temp_path)
	AsyncCreatePath(pack_path)
	AsyncCreatePath(shots_path)
	
	--copy & rename mod screenshots
	params.screenshots = { }
	for i=1,5 do
		--copy & rename mod_def.screenshot1, mod_def.screenshot2, mod_def.screenshot3, mod_def.screenshot4, mod_def.screenshot5
		local screenshot = mod_def["screenshot"..i]
		if io.exists(screenshot) then
			local path, name, ext = SplitPath(screenshot)
			local new_name = ModsScreenshotPrefix .. name .. ext
			local new_path = shots_path .. new_name
			local err = AsyncCopyFile(screenshot, new_path)
			if not err then
				local os_path = ConvertToOSPath(new_path)
				table.insert(params.screenshots, os_path)
			end
		end
	end
	
	local mod_entities = {}
	for _, entity in ipairs(mod_def.entities) do
		DelayedLoadEntity(mod_def, entity)
		mod_entities[entity] = true
	end
	WaitDelayedLoadEntities()

	ReloadLua()

	EngineBinAssetsPrints = {}

	local materials_seen, used_tex, textures_data = CollapseEntitiesTextures(mod_entities)

	if next(EngineBinAssetsPrints) then
		for _, log in ipairs(EngineBinAssetsPrints) do
			ModLogF(log)
		end
	end

	local dest_path = ConvertToOSPath(mod_def.content_path .. "BinAssets/")
	local res = SaveModMaterials(materials_seen, dest_path)

	--determine which files should to be packed and which ignored
	local files_to_pack = { }
	local substring_begin = #mod_def.content_path + 1
	local err, all_files = AsyncListFiles(content_path, nil, "recursive")
	for i,file in ipairs(all_files) do
		local ignore

		for j,filter in ipairs(mod_def.ignore_files) do
			if MatchWildcard(file, filter) then
				ignore = true
				break
			end
		end

		local dir, filename, ext = SplitPath(file)
		if ext == ".dds" and not used_tex[filename .. ext] then
			ignore = true
		end

		ignore = ignore or ext == ".mtl"

		if not ignore then
			table.insert(files_to_pack, { src = file, dst = string.sub(file, substring_begin) })
		end
	end
	
	--pack the mod content
	local err = AsyncPack(pack_path .. ModsPackFileName, content_path, files_to_pack)
	if err then
		return false, T{243097197797, --[[Mod upload error]] "Failed creating content package file (<err>)", err = err}
	end
	
	params.os_pack_path = ConvertToOSPath(pack_path .. ModsPackFileName)
	return true, nil
end

---
--- Packs a mod for upload.
---
--- @param mod_def ModDef The mod definition to pack.
--- @param show_file boolean If true, opens the packed mod file in the system file explorer.
--- @return string The directory path of the packed mod file.
---
function DbgPackMod(mod_def, show_file)
	local params = {}
	if mod_def:IsDirty() then
		mod_def:SaveWholeMod()
	end
	CreatePackageForUpload(mod_def, params)
	local dir = SplitPath(params.os_pack_path):gsub("/", "\\")
	if show_file then
		AsyncExec(string.format('explorer "%s"', dir))
	end
	return dir
end

---
--- Packs a mod for the bug reporter.
---
--- @param mod ModDef|string The mod definition or mod ID to pack.
--- @return string The directory path of the packed mod file.
---
function PackModForBugReporter(mod)
	mod = IsKindOf(mod, "ModDef") and mod or (Mods and Mods[mod.id])
	if not mod then return end
	local params = {}
	if mod:IsDirty() then
		mod:SaveWholeMod()
	end
	CreatePackageForUpload(mod, params)
	return params.os_pack_path
end

if FirstLoad then
	ModUploadDeveloperWarningShown = false
end

---
--- Uploads a mod to the platform.
---
--- @param ged_socket GedSocket The GedSocket instance to use for UI interactions.
--- @param mod ModDef The mod definition to upload.
--- @param params table A table of parameters for the upload process.
--- @param prepare_fn function A function to prepare the mod for upload.
--- @param upload_fn function A function to perform the actual upload.
---
function UploadMod(ged_socket, mod, params, prepare_fn, upload_fn)
	ModUploadThread = CreateRealTimeThread(function(ged_socket, mod, params, prepare_fn, upload_fn)
		local function DoUpload()
			--uploading is done in three steps
			-- 1) the platform prepares the mod for uploading (generate IDs and others...)
			-- 2) the mod is packaged into a .hpk file
			-- 3) the mod is uploaded
			-- every function returns at least two parameters: `success` and `message`
			
			local function ReportError(ged_socket, message)
				ModLog(true, Untranslated{"Mod <ModLabel> was not uploaded! Error: <u(err)>", mod, err = message})
				ged_socket:ShowMessage("Error", message)
			end
			
			local success, message
			success, message = prepare_fn(ged_socket, mod, params)
			if not success then
				ReportError(ged_socket, message)
				return
			end
			
			success, message = CreatePackageForUpload(mod, params)
			if not success then
				ReportError(ged_socket, message)
				return
			end
			
			success, message = upload_fn(ged_socket, mod, params)
			if not success then
				ReportError(ged_socket, message)
			else
				local msg = T{561889745203, "Mod <ModLabel> was successfully uploaded!", mod}
				ModLog(msg)
				ged_socket:ShowMessage(T(898871916829, "Success"), msg)
				
				if insideHG() then
					if Platform.goldmaster then
						ged_socket:ShowMessage("Reminder", "After publishing a mod, make sure to copy it to svnAssets/Source/Mods/ and commit.")
					elseif Platform.developer and not ModUploadDeveloperWarningShown then
						ged_socket:ShowMessage("Reminder", "Publishing sample mods should be done using the target GoldMaster version of the game.")
						ModUploadDeveloperWarningShown = true
					end
				end
			end
		end
		
		PauseInfiniteLoopDetection("UploadMod")
		GedSetUiStatus("mod_upload", "Uploading...")
		DoUpload()
		GedSetUiStatus("mod_upload")
		ResumeInfiniteLoopDetection("UploadMod")
		ModUploadThread = false
	end, ged_socket, mod, params, prepare_fn, upload_fn)
end

---
--- Validates a mod before uploading it.
---
--- @param ged_socket table The GED socket object.
--- @param mod table The mod object to validate.
--- @return string|nil The error message if validation fails, or nil if validation passes.
---
function ValidateModBeforeUpload(ged_socket, mod)
	if IsValidThread(ModUploadThread) then
		ged_socket:ShowMessage("Error", "Another mod is currently uploading.\n\nPlease wait for the upload to finish.")
		return "upload in progress"
	end
	
	if mod.last_changes == "" then
		ged_socket:ShowMessage("Error", "Please fill in the 'Last Changes' field of your mod before uploading.")
		return "no 'last changes'"
	end
	
	if mod:IsDirty() then
		if "ok" ~= ged_socket:WaitQuestion("Mod Upload", "The mod needs to be saved before uploading.\n\nContinue?", "Yes", "No") or
			not mod:CanSaveMod(ged_socket)
		then
			return "mod saving failed"
		end
		mod:SaveWholeMod()
	end
end

---
--- Tests a mod item.
---
--- @param socket table The GED socket object.
--- @param root table The root object of the mod.
--- @param path string The path to the mod item to test.
---
function GedOpTestModItem(socket, root, path)
	local item = IsKindOf(root, "ModItem") and root or GetNodeByPath(root, path)
	if IsKindOf(item, "ModItem") then
		item:TestModItem(socket)
	end
end

---
--- Opens the mod folder in the system file explorer.
---
--- @param socket table The GED socket object.
--- @param root table The root object of the mod.
---
function GedOpOpenModFolder(socket, root)
	local mod = root[1]
	local path = ConvertToOSPath(SlashTerminate(mod.path))
	CreateRealTimeThread(function()
		AsyncExec(string.format('cmd /c start /D "%s" .', path))
	end)
end

---
--- Packs the specified mod.
---
--- @param socket table The GED socket object.
--- @param root table The root object of the mod.
---
function GedOpPackMod(socket, root)
	local mod = root[1]
	if not mod then return end
	CreateRealTimeThread(function()
		if socket:WaitQuestion("Pack mod", "Packing the mod will take more time the bigger it is.\nAre you sure you want to continue?", "Yes", "No") == "ok" then
			GedSetUiStatus("mod_packing", "Packing mod...")
			DbgPackMod(mod, true)
			GedSetUiStatus("mod_packing")
		end
	end)
end

---
--- Opens the documentation for the specified mod item.
---
--- @param socket table The GED socket object.
--- @param root table The root object of the mod.
--- @param path string The path to the mod item to open documentation for.
---
function GedOpModItemHelp(socket, root, path)
	local item = GetNodeByPath(root, path)
	if IsKindOf(item, "ModItem") then
		local filename = DocsRoot .. item.class .. ".md.html"
		if io.exists(filename) then
			local os_path = ConvertToOSPath(filename)
			OpenAddress(os_path)
			return
		end
	end
	local path_to_index = ConvertToOSPath(DocsRoot .. "index.md.html")
	if io.exists(path_to_index) then
		OpenAddress(path_to_index)
	end
end

---
--- Generates a CSV file containing localization data for a mod.
---
--- @param socket table The GED socket object.
--- @param root table The root object of the mod.
---
function GedOpGenTTableMod(socket, root)
	local csv = {}
	local modDef = root[1]
	modDef:ForEachModItem(function(item)
		item:ForEachSubObject("PropertyObject", function(obj, parents)
			obj:GenerateLocalizationContext(obj)
			for _, propMeta in ipairs(obj.GetProperties and obj:GetProperties()) do
				local propVal = obj:GetProperty(propMeta.id)
				if propVal ~= "" and IsT(propVal) then
					local context, voice = match_and_remove(ContextCache[propVal], "voice:")
					if getmetatable(propVal) == TConcatMeta then
						for _, t in ipairs(propVal) do
							csv[#csv+1] = { id = TGetID(t), text = TDevModeGetEnglishText(t), context = context, voice = voice }
						end
					else
						csv[#csv+1] = { id = TGetID(propVal), text = TDevModeGetEnglishText(propVal), context = context, voice = voice }
					end
				end
			end
		end)
	end)
	
	local csv_filename = modDef.path .. "/ModTexts.csv"
	local fields = { "id", "text", "translation", "voice", "context" } -- translation is intentionally non-existent above, to create an empty column
	local field_captions = { "ID", "Text", "Translation", "VoiceActor", "Context" }
	local err = SaveCSV(csv_filename, csv, fields, field_captions, ",")
	if err then
		socket:ShowMessage("Error", "Failed to export a translation table to\n" .. ConvertToOSPath(csv_filename) .. "\nError: " .. err)
	else
		socket:ShowMessage("Success", "Successfully exported a translation table to\n" .. ConvertToOSPath(csv_filename))
	end
end

local function GetDirSize(path)
	local err, files = AsyncListFiles(path)
	local size
	if not err then
		size = 0
		for _, filename in ipairs(files) do
			size = size + io.getsize(filename)
		end
	end
	return size
end

local function GetModDetailsForBugReporter(modDef)
	local mod_content_path = modDef:GetModContentPath()
	local mod_root_path = modDef:GetModRootPath()
	local is_packed = modDef:IsPacked()
	local modSize = not is_packed and GetDirSize(ConvertToOSPath(mod_content_path)) or io.getsize(mod_root_path .. ModsPackFileName)
	local estPackSizeReduction = is_packed and 1 or 2
	local maxSize = 100*1024*1024 --100mb
	
	local res = {
		id = modDef.id,
		title = modDef.title,
		mod_path = mod_content_path,
		mod_items_path = mod_root_path .. "items.lua",
		mod_metadata_path = mod_root_path .. "metadata.lua",
		mod_is_packed = is_packed and mod_root_path .. ModsPackFileName,
		mod_size_check = modSize and (modSize / estPackSizeReduction <= maxSize),
		mod_os_path = mod_root_path,
	}
	return res
end

---
--- Gets the currently edited mod from the given socket.
---
--- @param socket table The socket object associated with the mod editor.
--- @return table|boolean The details of the currently edited mod, or `false` if no mod is currently being edited.
function GedGetMod(socket)
	local mod = socket and socket.app_template == "ModEditor" and socket:ResolveObj("root")
	mod = mod and IsKindOf(mod[1], "ModDef") and mod[1]
	if not mod then return false end
	
	return GetModDetailsForBugReporter(mod)
end

---
--- Gets the last edited mod from the given socket, or the last edited mod globally if no socket is provided.
---
--- @param socket table The socket object associated with the mod editor. Can be `nil`.
--- @return table|boolean The details of the last edited mod, or `false` if no mod has been edited.
function GedGetLastEditedMod(socket)
	return socket and GedGetMod(socket) or LastEditedMod
end

---
--- Checks if the modding tools are active.
---
--- @param socket table The socket object associated with the mod editor.
--- @return boolean True if the modding tools are active, false otherwise.
function GedAreModdingToolsActive(socket)
	return AreModdingToolsActive()
end

---
--- Packs the specified mod for a bug report.
---
--- @param socket table The socket object associated with the mod editor.
--- @param mod table The mod to pack for the bug report.
--- @return string|nil The path to the packed mod file, or `nil` if the mod could not be packed.
function GedPackModForBugReport(socket, mod)
	DebugPrint("Packing mod...")
	local modDef = Mods and Mods[mod.id]
	local packed_path
	if modDef then
		packed_path = PackModForBugReporter(modDef)
	end
	return packed_path
end

local function UpdateLastEditedMod(mod)
	local oldMod = LastEditedMod
	LastEditedMod = GetModDetailsForBugReporter(mod)
	if not oldMod or not LastEditedMod or oldMod.id ~= LastEditedMod.id then
		Msg("LastEditedModChanged", LastEditedMod)
	end
end

function OnMsg.ObjModified(obj)
	local mod = TryGetModDefFromObj(obj)
	if mod then
		UpdateLastEditedMod(mod)
	end
end

function OnMsg.GedOpened(app_id)
	local conn = GedConnections[app_id]
	if conn and conn.app_template == "ModEditor" then
		local root = conn and conn:ResolveObj("root")
		local mod = root and root[1]
		if mod then
			UpdateLastEditedMod(mod)
		end
	end
end

---
--- Gets the current Steam beta name and branch.
---
--- @return string|nil The current Steam beta name, or `nil` if not on Steam or no beta is active.
--- @return string|nil The current Steam beta branch, or `nil` if not on Steam or no beta is active.
function GedGetSteamBetaName()
	local steam_beta, steam_branch
	if Platform.steam then
		steam_beta, steam_branch = SteamGetCurrentBetaName()
	end
	return steam_beta, steam_branch
end