if not config.Mods then return end

--Tags
function ModDef:GetTags()
	local tags_used = { }
	for i,tag in ipairs(PredefinedModTags) do
		if self[tag.id] then
			table.insert(tags_used, tag.display_name)
		end
	end
	
	return tags_used
end

PredefinedModTags = {
    { id = "TagIMPCharacter", display_name = "IMP Character" },
    { id = "TagMercs", display_name = "Mercs" },
    { id = "TagWeapons&Items", display_name = "Weapons & Items" },
    { id = "TagPerks&Talents&Skills", display_name = "Perks, Talents & Skills" },
    { id = "TagMines&Economy", display_name = "Mines & Economy" },
    { id = "TagSatview&Operations", display_name = "Sat view & Operations" },
    { id = "TagBalancing&Difficulty", display_name = "Balancing & Difficulty" },
    { id = "TagCombat&AI", display_name = "Combat & AI" },
    { id = "TagEnemies", display_name = "Enemies" },    
    { id = "TagGameSettings", display_name = "Game Settings" },
    { id = "TagUI", display_name = "UI" },
    { id = "TagVisuals&Graphics", display_name = "Visuals & Graphics" },
    { id = "TagLocalization", display_name = "Localization" },
    { id = "TagMusic&Sound&Voices", display_name = "Music, Sound & Voices" },
    { id = "TagQuest&Campaigns", display_name = "Quest & Campaigns" },
    { id = "TagLibs&ModdingTools", display_name = "Libs & Modding Tools" },
    { id = "TagOther", display_name = "Other" }
}

table.sortby_field(PredefinedModTags, "display_name")

PredefinedModTagsByName = { }
for i,tag in ipairs(PredefinedModTags) do
	PredefinedModTagsByName[tag.display_name] = tag
end

function OnMsg.ClassesGenerate(classdefs)
	local mod = classdefs["ModDef"]
	local properties = mod.properties
	
	for i,tag in ipairs(PredefinedModTags) do
		local prop_meta = { category = "Tags", id = tag.id, name = Untranslated(tag.display_name), editor = "bool", default = false }
		table.insert(properties, prop_meta)
	end
end

--Cheats
---
--- Starts a real-time thread that calls `DbgStartExploration()` to start an exploration debug session.
---
--- This function is likely used for testing or debugging purposes, as it directly calls an internal function
--- (`DbgStartExploration()`) that is not part of the public API.
---
--- @function CheatTestExploration
--- @return nil
function CheatTestExploration()
	CreateRealTimeThread(function() DbgStartExploration() end)
end

---
--- Enables a cheat with the given ID for the specified side.
---
--- @param id string The ID of the cheat to enable.
--- @param side string The side for which to enable the cheat.
--- @return nil
function CheatEnable(id, side)
	NetSyncEvent("CheatEnable", id, nil, side)
end

---
--- Activates a cheat with the given ID.
---
--- This function is likely used to enable cheats or other debug functionality in the game.
---
--- @param id string The ID of the cheat to activate.
--- @return nil
function CheatActivate(id)
	NetSyncEvent(id)
end

---
--- Toggles the fly camera mode.
---
--- This function calls the `ActionById("G_CameraChange")` action, which is likely responsible for toggling the fly camera mode in the game.
---
--- @function CheatToggleFlyCamera
--- @return nil
function CheatToggleFlyCamera()
	XShortcutsTarget:ActionById("G_CameraChange"):OnAction()
end

---
--- Resets the game session and changes the map to the ModEditorMapName.
---
--- This function is likely used for testing or debugging purposes, as it directly resets the game session and changes the map.
---
--- @function CheatResetMap
--- @return nil
function CheatResetMap()
	CreateRealTimeThread(function()
		ResetGameSession()
		ChangeMap(ModEditorMapName)
	end)
end

---
--- Adds a merc unit to the player's squad.
---
--- If the merc unit is already in the player's squad, this function does nothing.
--- If the player has no merc squads, this function will start an exploration to find a free position for the merc.
--- If the merc unit is not a merc (i.e. does not have unit data), this function will create unit data for it.
---
--- @param id string The ID of the merc unit to add to the player's squad.
--- @return nil
function CheatAddMerc(id)
	if table.find(g_Units, "session_id", id) then return end
	if not next(GetPlayerMercSquads()) then
		DbgStartExploration(nil, {id})
	else
		local ud = gv_UnitData[id]
		if not ud then -- Non-merc units will not have unit data.
			ud = CreateUnitData(id, id, InteractionRand(nil, "CheatAddMerc"))
		end
		UIAddMercToSquad(id)
		HiredMercArrived(gv_UnitData[id])
	end
end

---
--- Returns a table of all inventory item IDs.
---
--- This function iterates over all `InventoryItemCompositeDef` presets and collects their IDs into a table.
---
--- @return table A table containing all inventory item IDs.
function GetItemsIds()
	local items = {}
	ForEachPreset("InventoryItemCompositeDef", function(o)
		table.insert(items, o.id)
	end)
	return items
end

---
--- Adds an inventory item to the player's inventory.
---
--- @param id string The ID of the inventory item to add.
--- @return nil
function CheatAddItem(id)
	UIPlaceInInventory(nil, InventoryItemDefs[id])
end

---
--- Takes a screenshot of the currently isolated object.
---
--- This function is used to capture a screenshot of the currently isolated object in the game. It is typically used for debugging or testing purposes.
---
--- @return nil
function CheatIsolatedScreenshot()
	IsolatedObjectScreenshot()
end

---
--- Starts a new mod game with the selected campaign.
---
--- This function allows the user to select a campaign from the available campaign presets, and then start a new mod game with that campaign. The user can choose to start a "quickstart" game, which skips the merc hire and arrival phase, or a "normal" game.
---
--- @param start_type string The type of game to start, either "quickstart" or "normal".
--- @return nil
function CheatNewModGame(start_type)
	CreateRealTimeThread(function()
		local campaignPresets = {}
		for _, preset in pairs(CampaignPresets) do
			table.insert(campaignPresets, preset.id)
		end
		local pickedCampaign = WaitListChoice(nil, campaignPresets, "Select campaign", 1)
		if not pickedCampaign then return end
	
		if start_type == "quickstart" then
			if WaitQuestion(terminal.desktop, Untranslated("Quick Start"), Untranslated("A new quick test mod game will be started. It will skip the merc hire & arrival phase.\n\nUnsaved mod changes will not be applied. Continue?"), Untranslated("Yes"), Untranslated("No")) ~= "ok" then
				return
			end
			ProtectedModsReloadItems(nil, "force_reload")
			QuickStartCampaign(pickedCampaign, {difficulty = "Normal"})
		elseif start_type == "normal" then
			if WaitQuestion(terminal.desktop, Untranslated("New Game"), Untranslated("A new test mod game will be started.\n\nUnsaved mod changes will not be applied. Continue?"), Untranslated("Yes"), Untranslated("No")) ~= "ok" then
				return
			end
			ProtectedModsReloadItems(nil, "force_reload")
			StartCampaign(pickedCampaign, {difficulty = "Normal"})
		end
	end)
end

---
--- Spawns an enemy unit at the current terrain cursor position.
---
--- @param id string The ID of the enemy unit to spawn. If not provided, "LegionRaider" will be used.
--- @return nil
function CheatSpawnEnemy(id)
	local p = GetTerrainCursorXY(UIL.GetScreenSize()/2)
	local freePoint = DbgFindFreePassPositions(p, 1, 20, xxhash(p))
	if not next(freePoint) then return end
	local unit = SpawnUnit(id or "LegionRaider", tostring(RealTime()), freePoint[1])
	unit:SetSide("enemy1")
end

--override open editor func to pass zulu related cheats info into the context
---
--- Opens the mod editor for the specified mod.
---
--- If the current map is not the mod editor map, this function will change the map to the mod editor map and close any open menu dialogs.
---
--- If a mod is provided, the function will open the mod editor for that mod. If no mod is provided, the function will open the mod manager, which allows the user to select a mod to edit.
---
--- @param mod table The mod to open the editor for, or nil to open the mod manager.
--- @return nil
function ModEditorOpen(mod)
	CreateRealTimeThread(function()
		if not IsModEditorMap(CurrentMap) then
			ChangeMap(ModEditorMapName)
			CloseMenuDialogs()
		end
		if mod then
			OpenModEditor(mod)
		else
			local context = {
				dlcs = g_AvailableDlc or { },
				mercs = GetGroupedMercsForCheats(nil, nil, true),
				items = GetItemsIds(),
			}
			local ged = OpenGedApp("ModManager", ModsList, context)
			if ged then ged:BindObj("log", ModMessageLog) end
			if LocalStorage.OpenModdingDocs == nil or LocalStorage.OpenModdingDocs then
				if Platform.goldmaster then
					GedOpHelpMod()
				end
			end
		end
	end)
end

if not Platform.developer and not Platform.asserts then
	function OnMsg.ChangeMapDone(map)
		ConsoleSetEnabled(AreModdingToolsActive())
	end
end

---
--- Opens the mod editor for the specified mod.
---
--- If the current map is not the mod editor map, this function will change the map to the mod editor map and close any open menu dialogs.
---
--- If a mod is provided, the function will open the mod editor for that mod. If no mod is provided, the function will open the mod manager, which allows the user to select a mod to edit.
---
--- @param mod table The mod to open the editor for, or nil to open the mod manager.
--- @return nil
function OpenModEditor(mod)
	local editor = GedConnections[mod.mod_ged_id]
	if editor then
		local activated = editor:Call("rfnApp", "Activate")
		if activated ~= "disconnected" then
			return editor
		end
	end
	
	for _, presets in pairs(Presets) do
		PopulateParentTableCache(presets)
	end
	
	local mod_path = ModConvertSlashes(mod:GetModRootPath())
	local mod_folder_supported = g_Classes.ModItemFolder and true or false
	local mod_items = GedItemsMenu("ModItem")
	
	--exception for ModItemMapPatch, as it is not a leaf node because of ModItemSetpiecePrg
	local modItemMapPatchClass = g_Classes.ModItemMapPatch
	if modItemMapPatchClass then
		table.insert_unique(mod_items, {
			Class = "ModItemMapPatch",
			EditorName = modItemMapPatchClass:HasMember("EditorName") and GedTranslate(modItemMapPatchClass.EditorName, modItemMapPatchClass, false) or "ModItemMapPatch",
			EditorIcon = rawget(modItemMapPatchClass, "EditorIcon"),
			EditorShortcut = rawget(modItemMapPatchClass, "EditorShortcut"),
			EditorSubmenu = rawget(modItemMapPatchClass, "EditorSubmenu"),
			ScriptDomain = rawget(modItemMapPatchClass, "ScriptDomain"), 
		})
	end
	
	local context = {
		mod_items = mod_items,
		mod_folder_supported = mod_folder_supported,
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
		mercs = GetGroupedMercsForCheats(nil, nil, true),
		items = GetItemsIds(),
	}
	Msg("GatherModEditorLogins", context)
	local container = Container:new{ mod }
	UpdateParentTable(mod, container)
	local editor = OpenGedApp("ModEditor", container, context)
	if editor then 
		editor:Send("rfnApp", "SetSelection", "root", { 1 })
		editor:Send("rfnApp", "SetTitle", string.format("Mod Editor - %s", mod.title))
	end
	return editor
end

--MODS UI
---
--- Closes a popup window and optionally opens the pre-game main menu.
---
--- @param win table The window object that triggered the popup close.
---
function ModsUIClosePopup(win)
	local dlg = GetDialog(win)
	local obj = dlg.context
	obj.popup_shown = false
	local wnd = dlg:ResolveId("idPopUp")
	if wnd and wnd.window_state ~= "destroying" then
		wnd:Close()
	end
	dlg:UpdateActionViews(dlg)
	if GetDialog("PreGameMenu") then
		CreateRealTimeThread(function()
			LoadingScreenOpen("idLoadingScreen", "main menu")
			OpenPreGameMainMenu("")
			LoadingScreenClose("idLoadingScreen", "main menu")
		end)
	end
end

--Undefine moditem classes not used in Zulu
function OnMsg.ClassesPreprocess(classdefs)
	UndefineClass('ModItemShelterSlabMaterials')
	UndefineClass('ModItemStoryBit')
	UndefineClass('ModItemStoryBitCategory')
	UndefineClass('ModItemActionFXColorization')
	UndefineClass("ModItemGameValue")
	UndefineClass("ModItemCompositeBodyPreset")
end

DefineModItemPreset("AppearancePreset", { 
	EditorName = "Appearance preset", 
	EditorSubmenu = "Unit", 
	TestDescription = "Updates the appearance of the object if already spawned.", 
	Documentation = "This mod item allows to change the appearance of existing units in the game and create new appearances for custom units.",
	DocumentationLink = "Docs/ModItemAppearancePreset.md.html"
})

local function UpdateAppearanceOnSpawnedObj(id)
	for _, unit in ipairs(g_Units) do
		if unit.Appearance and unit.Appearance == id then
			unit:ApplyAppearance(id, "force")
		end
	end
end

---
--- Updates the appearance of all spawned objects that use the specified appearance preset.
---
--- @param id string The ID of the appearance preset.
---
function ModItemAppearancePreset:TestModItem(ged)
	UpdateAppearanceOnSpawnedObj(self.id)
end

---
--- Updates the appearance of all spawned objects that use the specified appearance preset.
---
--- @param prop_id string The ID of the property that was set.
--- @param old_value any The old value of the property.
--- @param ged table The GED (Game Editor) object associated with this mod item.
---
function ModItemAppearancePreset:OnEditorSetProperty(prop_id, old_value, ged)
	ModItemPreset.OnEditorSetProperty(self, prop_id, old_value, ged)
	UpdateAppearanceOnSpawnedObj(self.id)
end

---
--- Applies the specified mod options to the current game session.
---
--- This function is responsible for loading the mod options from the account storage and applying them to the current game session.
---
--- @param modsOptions table An array of mod options to apply.
---
function ApplyModOptions(modsOptions)
	CreateRealTimeThread(function(modsOptions)
		for _, modOptions in ipairs(modsOptions) do
			local mod = modOptions.__mod
			AccountStorage.ModOptions = AccountStorage.ModOptions or { }
			local storage_table = AccountStorage.ModOptions[mod.id] or { }
			for _, prop in ipairs(modOptions:GetProperties()) do
				local value = modOptions:GetProperty(prop.id)
				value = type(value) == "table" and table.copy(value) or value
				storage_table[prop.id] = value
			end
			AccountStorage.ModOptions[mod.id] = storage_table
			rawset(mod.env, "CurrentModOptions", modOptions)
			Msg("ApplyModOptions", mod.id)
		end
		SaveAccountStorage(1000)
	end, modsOptions)
end

---
--- Returns the option metadata for the current mod item option.
---
--- @return table The option metadata, including the option's ID, name, editor, default value, help text, and the ID of the mod it belongs to.
---
function ModItemOption:GetOptionMeta()
	local display_name = self.DisplayName
	if not display_name or display_name == "" then
		display_name = self.name
	end
	
	return {
		id = self.name,
		name = T(display_name),
		editor = self.ValueEditor,
		default = self.DefaultValue,
		help = Untranslated(self.Help),
		modId = self.mod.id,
	}
end

DefineClass.ModItemTranslatedVoices =  {
	__parents = { "ModItem" },
	
	EditorName = "Translated voices",
	EditorSubmenu = "Unit",
	
	properties = {
		{ id = "_", default = false, editor = "help", 
			help = [[The <style GedHighlight>Translated Voices</style> mod item allows to supply to the game voices which will be used when the game is running in a specific language. You can use this to add new language voices of the existing voice lines, to override the existing voice lines, or to add entirely new voice content to the game.

1. Voice filenames need to match the localization IDs of the texts they correspond to; you can look up the localization IDs of existing lines in the game localization table (Game.csv) supplied with the mod tools.
2. Voice files should be in Opus format; it is recommended to combine this mod item with an <style GedHighlight>Convert & Import Assets</style> mod item targeting a folder inside your mod folder structure.
3. To supply voices in multiple languages, use one <style GedHighlight>Translated Voices</style> mod item per language.]], },
		{ id = "language", name = "Language", editor = "dropdownlist", default = "", help = "Based on this value, the mod will decide if it should load the voices located in the translation folder.",
			items = GetAllLanguages(), 
		},
		{ id = "translatedVoicesFolder", name = "Translated Voices Folder", editor = "browse", filter = "folder", default = "", help = "The folder inside the mod in which the translated voices should be placed. If you use the Convert & Import mod item for creating the files, pick the same path as the one defined there." },
		{ id = "btn", editor = "buttons", default = false, buttons = {{name = "Force mount folder", func = "TryMountFolder"}}, untranslated = true},

	}, 
}

---
--- Initializes a new instance of the `ModItemTranslatedVoices` class.
---
--- This method is called when a new instance of the `ModItemTranslatedVoices` class is created in the editor.
---
--- @param parent table The parent object of the new instance.
--- @param ged table The Ged (Graphical Editor) object associated with the new instance.
--- @param is_paste boolean Indicates whether the new instance is being pasted from the clipboard.
---
function ModItemTranslatedVoices:OnEditorNew(parent, ged, is_paste)
	self.name = "TranslatedVoices"
end

---
--- Returns a unique label for mounting the translated voices folder.
---
--- The label is constructed from the mod ID and the language.
---
--- @return string The mount label for the translated voices folder.
---
function ModItemTranslatedVoices:GetMountLabel()
	return self.mod.id .. "/" .. self.language
end

---
--- Attempts to mount the translated voices folder.
---
--- If the `translatedVoicesFolder` property is not empty and the current language matches the `language` property (or the `language` property is "Any"), this function will attempt to mount the translated voices folder.
---
--- If the folder is successfully mounted, a label is used to identify the mount point. The label is constructed from the mod ID and the language.
---
--- If there is an error mounting the folder, a log message is written to the ModLog.
---
--- @return nil
---
function ModItemTranslatedVoices:TryMountFolder()
	if self.translatedVoicesFolder ~= "" and (GetLanguage() == self.language or self.language == "Any") then
		local err = MountFolder("CurrentLanguage/Voices", self.translatedVoicesFolder, "seethrough,label:" .. self:GetMountLabel())
		if err then
			ModLogF(true, "Failed to mount translated voice folder '%s': %s", self.translatedVoicesFolder, err)
		end
	end
end

---
--- Unmounts the translated voices folder.
---
--- This function unmounts the folder that was previously mounted using the `TryMountFolder()` function. The mount label used to identify the mount point is constructed from the mod ID and the language.
---
--- @return nil
---
function ModItemTranslatedVoices:UnmountFolders()
	UnmountByLabel(self:GetMountLabel())
end

---
--- Called when the mod is loaded.
---
--- This function is called when the mod is loaded. It attempts to mount the translated voices folder if the necessary conditions are met.
---
--- @return nil
---
function ModItemTranslatedVoices:OnModLoad()
	ModItem.OnModLoad(self)
	self:TryMountFolder()
end

---
--- Unmounts the translated voices folder when the mod is unloaded.
---
--- This function is called when the mod is unloaded. It unmounts the folder that was previously mounted using the `TryMountFolder()` function. The mount label used to identify the mount point is constructed from the mod ID and the language.
---
--- @return nil
---
function ModItemTranslatedVoices:OnModUnload()
	self:UnmountFolders()
	
	ModItem.OnModUnload(self)
end

function OnMsg.TranslationChanged()
	for _, loadedMod in ipairs(ModsLoaded) do
		if loadedMod:ItemsLoaded() then
			loadedMod:ForEachModItem("ModItemTranslatedVoices", function(loadedItem)
				if loadedItem.mod then
					loadedItem:UnmountFolders()
					loadedItem:TryMountFolder()
				end
			end)
		end
	end
end

---
--- Returns an error message if the language for the translated voices is not set.
---
--- @return string|nil The error message if the language is not set, otherwise nil.
---
function ModItemTranslatedVoices:GetError()
	if self.language == "" then
		return "Choose a language for the translated voices."
	end
end

function OnMsg.UnableToUnlockAchievementReasons(reasons, achievement)
	if AreModdingToolsActive() then
		reasons["modding tools active"] = true
	end
end

-- Mods Presets (UI)
-- A preset contains a list of mod id's with the idea to easily 
-- enable a specific set of mods.

---
--- Initializes the mod presets system.
---
--- This function sets up the mod presets system by checking if it's the first time the presets are being loaded. If so, it loads the default preset. Otherwise, it loads the existing presets from the local storage.
---
--- The mod presets system allows the user to save a set of enabled mods as a preset, which can be easily selected later. This function is responsible for the initial setup and loading of these presets.
---
--- @return nil
---
function InitModPresets()
	local firstTimeDefaultPreset = not LocalStorage.ModPresets
	LocalStorage.ModPresets = LocalStorage.ModPresets or { 
		{id = "default", mod_ids = {}}, 
		{id = "create new preset", mod_ids = {}, input_field = true}, 
	}
	if firstTimeDefaultPreset then
		FirstLoadOfDefaultPreset()
	end
	SaveLocalStorageDelayed()
end

---
--- Initializes the default mod preset by adding all currently loaded mods to the "Default" preset.
---
--- This function is called the first time the mod presets system is loaded. It iterates through all the currently loaded mods and adds their IDs to the "Default" preset. This ensures that the default preset contains all the mods that are currently enabled.
---
--- After adding the mods, the function sorts the mod presets and selects the "default" preset.
---
--- @return nil
---
function FirstLoadOfDefaultPreset()
	for _, modDef in ipairs(ModsLoaded) do
		AddModToModPreset("Default", modDef.id)
	end
	
	SortModPresets()
	SelectModPreset("default", "firstime")
end

---
--- Creates a new mod preset with the given preset ID.
---
--- If a preset with the given ID already exists, the function will return `false` along with an error message.
---
--- Otherwise, the function will create a new preset with the given ID, add it to the `LocalStorage.ModPresets` table, sort the presets, and save the local storage. The function will return `true` on success.
---
--- @param preset_id string The ID of the new preset to create.
--- @return boolean, string|nil True on success, or false and an error message if a preset with the given ID already exists.
---
function CreateModPreset(preset_id)
	preset_id = string.lower(preset_id)
	if table.find(LocalStorage.ModPresets, "id", preset_id) then
		return false, T{846096667197, "A mod preset with the name <em><u(name)></em> already exists.", name = preset_id}
	end
	
	table.insert(LocalStorage.ModPresets, { id = preset_id, mod_ids = {}, timestamp = os.time() })
	SortModPresets()
	SaveLocalStorageDelayed()
	return true
end

---
--- Deletes a mod preset with the given preset ID.
---
--- If a preset with the given ID does not exist, the function will return without doing anything.
---
--- Otherwise, the function will remove the preset from the `LocalStorage.ModPresets` table, and save the local storage.
---
--- @param preset_id string The ID of the preset to delete.
--- @return nil
---
function DeleteModPreset(preset_id)
	preset_id = string.lower(preset_id)
	local presetDataIdx = table.find(LocalStorage.ModPresets, "id", preset_id)
	if not presetDataIdx then return end
	
	table.remove(LocalStorage.ModPresets, presetDataIdx)
	SaveLocalStorageDelayed()
end

---
--- Adds a mod to the specified mod preset.
---
--- If the specified preset does not exist, the function will return without doing anything.
---
--- Otherwise, the function will add the specified mod ID to the mod_ids list of the preset, and save the local storage.
---
--- @param preset_id string The ID of the preset to add the mod to.
--- @param mod_id string The ID of the mod to add to the preset.
--- @return nil
---
function AddModToModPreset(preset_id, mod_id)
	preset_id = string.lower(preset_id)
	local presetData = table.find_value(LocalStorage.ModPresets, "id", preset_id)
	if not presetData then return end
	
	table.insert(presetData.mod_ids, mod_id)
	SaveLocalStorageDelayed()
end

---
--- Removes a mod from the specified mod preset.
---
--- If the specified preset does not exist, the function will return without doing anything.
---
--- Otherwise, the function will remove the specified mod ID from the mod_ids list of the preset, and save the local storage.
---
--- @param preset_id string The ID of the preset to remove the mod from.
--- @param mod_id string The ID of the mod to remove from the preset.
--- @return nil
---
function RemoveModFromModPreset(preset_id, mod_id)
	preset_id = string.lower(preset_id)
	local presetData = table.find_value(LocalStorage.ModPresets, "id", preset_id)
	if not presetData then return end
	
	local modIdx = table.find(presetData.mod_ids, mod_id)
	if not modIdx then return end
	
	table.remove(presetData.mod_ids,modIdx)
	SaveLocalStorageDelayed()
end

---
--- Selects a mod preset and turns on the mods associated with that preset.
---
--- If the specified preset does not exist, the function will return without doing anything.
---
--- Otherwise, the function will turn off all mods, clear the installed tags filter, update the installed mods, and then turn on the mods associated with the specified preset. It will also save the last selected preset to the local storage.
---
--- @param preset_id string The ID of the preset to select.
--- @param firstTime boolean Whether this is the first time the preset is being selected.
--- @return nil
---
function SelectModPreset(preset_id, firstTime)
	preset_id = string.lower(preset_id) 
	AllModsOff()
	
	--clear tags when selecting preset
	ModsUIClearFilter("temp_installed_tags")
	ModsUISetInstalledTags()
	if g_ModsUIContextObj then
		g_ModsUIContextObj:GetInstalledMods()
	end
	ObjModified(PredefinedModTags)
	
	local presetData = table.find_value(LocalStorage.ModPresets, "id", preset_id)
	if not presetData then return end
	
	for _, mod_id in ipairs(presetData.mod_ids) do
		if Mods[mod_id] and not ModIdBlacklist[mod_id] then
			TurnModOn(mod_id)
		end
	end
	LocalStorage.LastSelectedModPreset = preset_id
	SaveLocalStorageDelayed()
	if not firstTime then g_CantLoadMods = {} end
	CreateRealTimeThread(WaitErrorLoadingMods, T(907697247489, "The following mods from the preset couldn't be loaded and have been disabled:\n"))
end

---
--- Sorts the mod presets stored in the local storage.
---
--- The mod presets are sorted in the following order:
--- - Presets with an `input_field` or no `timestamp` are sorted alphabetically by their ID.
--- - Presets without an `input_field` and with a `timestamp` are sorted in descending order by their timestamp.
---
--- After sorting the mod presets, the local storage is saved.
---
function SortModPresets()
	if next(LocalStorage.ModPresets) then
		table.sort(LocalStorage.ModPresets, function(a, b) 
			local specialFieldA = a.input_field or not a.timestamp
			local specialFieldB = b.input_field or not b.timestamp
			if specialFieldA and specialFieldB then
				return string.lower(a.id) < string.lower(b.id)
			elseif not specialFieldA and not specialFieldB then
				return a.timestamp > b.timestamp
			end
			if specialFieldA then return true end
			if specialFieldB then return false end
		end)
	end
	SaveLocalStorageDelayed()
end

---
--- Gets the name of a mod preset.
---
--- @param preset_id string The ID of the mod preset.
--- @return string The name of the mod preset.
---
function GetModPresetName(preset_id)
	preset_id = string.lower(preset_id)
	local presetData = table.find_value(LocalStorage.ModPresets, "id", preset_id)
	if presetData then
		if presetData.id == "default" then
			return T(366064427094, "Default")
		elseif presetData.id == "create new preset" then
			return T(804320297184, "Create New Preset")
		else
			return Untranslated(presetData.id)
		end
	end
end

---
--- Turns a mod on and adds it to the last selected mod preset if requested.
---
--- @param id string The ID of the mod to turn on.
--- @param updatePreset boolean If true, the mod will be added to the last selected mod preset.
---
function TurnModOn(id, updatePreset)
	table.insert_unique(AccountStorage.LoadMods, id)
	if updatePreset then
		AddModToModPreset(LocalStorage.LastSelectedModPreset, id)
	end
end

---
--- Turns a mod off and removes it from the last selected mod preset if requested.
---
--- @param id string The ID of the mod to turn off.
--- @param updatePreset boolean If true, the mod will be removed from the last selected mod preset.
---
function TurnModOff(id, updatePreset)
	table.remove_entry(AccountStorage.LoadMods, id)
	if updatePreset then
		RemoveModFromModPreset(LocalStorage.LastSelectedModPreset, id)
	end
end

OnMsg.ModsUIDialogStarted = InitModPresets

---
--- Checks if all predefined mod tags are enabled.
---
--- @return boolean True if all predefined mod tags are enabled, false otherwise.
---
function AreAllTagsEnabled()
	if not g_ModsUIContextObj then return false end
	local predifinedCount = PredefinedModTags and #PredefinedModTags or 0
	local enabledCount = 0
	if g_ModsUIContextObj and next(g_ModsUIContextObj.temp_installed_tags) then
		enabledCount = #table.keys(g_ModsUIContextObj.temp_installed_tags)
	end
	return predifinedCount == enabledCount
end

DefineModItemPreset("CampaignPreset", { EditorName = "Campaign", EditorSubmenu = "Campaign & Maps", TestDescription = "Starts the created campaign." })
DefineModItemPreset("QuestsDef", { EditorName = "Quest", EditorSubmenu = "Campaign & Maps" })
DefineModItemPreset("Conversation", { EditorName = "Conversation", EditorSubmenu = "Campaign & Maps" })
DefineModItemPreset("Email", { EditorName = "Email", EditorSubmenu = "Campaign & Maps" })
DefineModItemPreset("HistoryOccurence", { EditorName = "History occurrence", EditorSubmenu = "Campaign & Maps" })
DefineModItemPreset("TutorialHint", { EditorName = "Tutorial hint", EditorSubmenu = "Campaign & Maps" })
DefineModItemPreset("EnvironmentColorPalette", { EditorSubmenu = "Campaign & Maps", EditorName = "Environment Palette" })

---
--- Starts a real-time thread that reloads mod items and quickly starts a campaign with the specified ID and difficulty.
---
--- @param self ModItemCampaignPreset The ModItemCampaignPreset instance.
---
function ModItemCampaignPreset:TestModItem()
	CreateRealTimeThread(function(self)
		ProtectedModsReloadItems(nil, "force_reload")
		QuickStartCampaign(self.id, {difficulty = "Normal"})
	end, self)
end

---
--- Returns the editor view for a ModItemQuestsDef.
---
--- @return table The editor view for the ModItemQuestsDef.
---
function ModItemQuestsDef:GetEditorView()
	return T{506003151811, "<mod_text> <original_text>", mod_text = Untranslated("<color 128 128 128>" .. self.EditorName .. "</color>"), original_text = QuestsDef.GetEditorView(self)}
end

---
--- Called when a new mod item is created in the editor.
---
--- @param parent ModDef|table The parent object of the mod item, either a ModDef or a table with a `mod` field.
--- @param ged table The GED (Game Editor) object associated with the mod item.
--- @param is_paste boolean Whether the mod item is being pasted from another location.
--- @param duplicate_id string The ID of the mod item being duplicated, if any.
--- @param mod_id string The ID of the mod the mod item belongs to.
---
function ModItem:OnEditorNew(parent, ged, is_paste, duplicate_id, mod_id)
	-- Mod item presets can also be added through Preset Editors (see GedOpClonePresetInMod)
	-- In those cases the reference to the mod will be set from the mod_id parameter

	self.mod = (IsKindOf(parent, "ModDef") and parent or parent.mod) or (mod_id and Mods and Mods[mod_id])
	assert(self.mod, "Mod item has no reference to a mod")

	if not is_paste and self.campaign then
		local lastCampaign
		self.mod:ForEachModItem("ModItemCampaignPreset", function(modItem)
			lastCampaign = modItem.id
		end)
		if lastCampaign then
			self.campaign = lastCampaign
		end
	end
end

OnMsg.ModsReloaded = RebuildGroupToConversation
OnMsg.NewGame = RebuildGroupToConversation

function OnMsg.ModsReloaded()
	for _, mod_def in ipairs(ModsLoaded) do
		if mod_def.saved_with_revision < 348693 then -- A random revision from the day this fixup was written.
			local property_to_scale = {
				vignette_circularity = 100.0,
				vignette_darken_feather = 1000.0,
				vignette_darken_start = 1000.0,
				vignette_tint_feather = 1000.0,
				vignette_tint_start = 1000.0,
				chromatic_aberration_circularity = 100.0,
				chromatic_aberration_feather = 1000.0,
				chromatic_aberration_start = 1000.0,
				chromatic_aberration_intensity = 1000.0,
				translucency_scale = 1000.0,
				translucency_distort_sun_dir = 1000.0,
				translucency_sun_falloff = 1000.0,
				translucency_sun_scale = 1000.0,
				translucency_ambient_scale = 1000.0,
				translucency_base_luminance = 1000.0,
				translucency_base_k = 1.0,
				translucency_reduce_k = 1.0,
				translucency_desaturation = 1000.0,
			}
			mod_def:ForEachModItem("ModItemLightmodelPreset", function(item)
				for prop_id, scale in pairs(property_to_scale) do
					if rawget(item, prop_id) then
						item[prop_id] = item[prop_id] / scale
					end
				end
				if rawget(item, "vignette_darken_opacity") then
					item.vignette_darken_opacity = MulDivRound(item.vignette_darken_opacity, 1000, 255) / 1000.0
				end
			end)
		end
	end
end


---- Map Editor

-- add custom button to open map editor documentation (uses Zulu-specific parameter of CreateMessageBox)
--- Shows a help popup with tips for using the map editor.
---
--- This function creates a message box with a welcome message and some tips for using the map editor controls, such as camera movement and object placement. It also includes an action button that opens the detailed game-specific help documentation.
---
--- @param self XEditor The XEditor instance.
function XEditor:ShowHelpText()
	self.help_popup = CreateMessageBox(XShortcutsTarget,
		Untranslated("Welcome to the Map Editor!"),
		Untranslated([[Here are some short tips to get you started.

Camera controls:
  • <mouse_wheel_up> - zoom in/out
  • hold <middle_click> - pan the camera
  • hold Ctrl - faster movement
  • hold Alt - look around
  • hold Ctrl+Alt - rotate camera

Look through the editor tools on the left - for example, press N to place objects.

Use <right_click> to access object properties and actions.

Read More opens detailed game-specific help.]]),
		Untranslated("OK"),
		nil, -- context obj
		XAction:new({
			ActionId = "idReadMore",
			ActionTranslate = false,
			ActionName = "Read More",
			ActionToolbar = "ActionBar",
			OnAction = function(self, host)
				GedOpHelpMod(nil, nil, "MapEditor.md.html")
				host:Close()
			end,
		})
	)
end

-- override editor.StartModdingEditor to close some game-specific UIs
old_StartModdingEditor = editor.StartModdingEditor

---
--- Overrides the `editor.StartModdingEditor` function to close some game-specific UIs before calling the original function.
---
--- This function is used to handle the initialization of the modding editor. It first closes some game-specific UIs, such as the satellite sector editor, satellite view, and the modify weapon dialog. It then calls the original `editor.StartModdingEditor` function with the provided `mod_item` and `map` parameters.
---
--- @param mod_item table The mod item to be edited in the modding editor.
--- @param map string The map to be edited in the modding editor.
function editor.StartModdingEditor(mod_item, map)
	CloseGedSatelliteSectorEditor()
	CloseSatelliteView(true)
	CloseDialog("ModifyWeaponDlg", true)
	Sleep(1000)
	old_StartModdingEditor(mod_item, map)
end

-- override to check for mod maps
---
--- Mounts a map by either unpacking the map data from a pack file or verifying the map folder exists.
---
--- @param map string The name of the map to mount.
--- @param folder string The folder where the map data is located.
--- @return string|nil An error message if the map data is missing or the map folder is missing, otherwise `nil`.
function MountMap(map, folder)
	folder = folder or GetMapFolder(map)
	if not IsFSUnpacked() and not MapData[map].ModMapPath then
		local map_pack = MapPackfile[map] or string.format("Packs/Maps/%s.hpk", map)
		local err = AsyncMountPack(folder, map_pack, "seethrough")
		assert(not err, "Map data is missing!")
		if err then return err end
	elseif not io.exists(folder) then
		assert(false, "Map folder is missing!")
		return "Path Not Found"
	end
end

AppendClass.Lightmodel = {
	properties = {
		{ id = "ice_color", editor = false, default = RGB(255, 255, 255) },
		{ id = "ice_strength", default = 0, editor = false },
		{ id = "snow_color", editor = false, default = RGB(167, 167, 167) },
		{ id = "snow_dir_x", 	editor = false, default = 0 },
		{ id = "snow_dir_y", 	editor = false, default = 0 },
		{ id = "snow_dir_z", 	editor = false, default = 1000 },
		{ id = "snow_str",	editor = false, default = 0 },
		{ id = "snow_enable", editor = false, default = false, },
	},
}