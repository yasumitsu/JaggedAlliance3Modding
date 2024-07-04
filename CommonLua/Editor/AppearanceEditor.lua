DefineClass.CharacterEntity =
{
	__parents = {"CObject"},
	flags = {gofRealTimeAnim = true},
}

DefineClass.CharacterBody = { __parents = {"CharacterEntity"} }
	DefineClass.CharacterBodyMale = { __parents = {"CharacterBody"} }
	DefineClass.CharacterBodyFemale = { __parents = {"CharacterBody"} }
DefineClass.CharacterHead = { __parents = {"CharacterEntity"} }
	DefineClass.CharacterHeadMale = { __parents = {"CharacterHead"} }
	DefineClass.CharacterHeadFemale = { __parents = {"CharacterHead"} }
DefineClass.CharacterPants = { __parents = {"CharacterEntity"} }
	DefineClass.CharacterPantsMale = { __parents = {"CharacterPants"} }
	DefineClass.CharacterPantsFemale = { __parents = {"CharacterPants"} }
DefineClass.CharacterShirts = { __parents = {"CharacterEntity"} }
	DefineClass.CharacterShirtsMale = { __parents = {"CharacterShirts"} }
	DefineClass.CharacterShirtsFemale = { __parents = {"CharacterShirts"} }
DefineClass.CharacterArmor = { __parents = {"CharacterEntity"} }
	DefineClass.CharacterArmorMale = { __parents = {"CharacterArmor"} }
	DefineClass.CharacterArmorFemale = { __parents = {"CharacterArmor"} }
DefineClass.CharacterHair = { __parents = {"CharacterEntity"} }
	DefineClass.CharacterHairMale = { __parents = {"CharacterHair"} }
	DefineClass.CharacterHairFemale = { __parents = {"CharacterHair"} }
DefineClass.CharacterHat = { __parents = {"CharacterEntity"} }
DefineClass.CharacterChest = { __parents = {"CharacterEntity"} }
	DefineClass.CharacterChestMale = { __parents = {"CharacterChest"} }
	DefineClass.CharacterChestFemale = { __parents = {"CharacterChest"} }
DefineClass.CharacterHip = { __parents = {"CharacterEntity"} }
	DefineClass.CharacterHipMale = { __parents = {"CharacterHip"} }
	DefineClass.CharacterHipFemale = { __parents = {"CharacterHip"} }

local function GetGender(appearance)
	return IsKindOf(g_Classes[appearance.Body], "CharacterBodyMale") and "Male" or "Female"
end

local function GetEntityClassInherits(entity_class, skip_none, filter)
	local inherits = ClassLeafDescendantsList(entity_class, function(class)
		return not table.find(filter, class)
	end)
	
	if not skip_none then
		table.insert(inherits, 1, "")
	end
	
	return inherits
end

--- Returns a list of character body class names that can be used in the appearance editor.
---
--- The list includes all character body classes that inherit from `CharacterBody`, excluding the specific
--- `CharacterBodyMale` and `CharacterBodyFemale` classes. An empty string is also included as the first
--- item in the list.
---
--- @return table<string> A list of character body class names.
function GetCharacterBodyComboItems()
	return GetEntityClassInherits("CharacterBody", "skip none", {"CharacterBodyMale", "CharacterBodyFemale"})
end

--- Returns a list of character head class names that can be used in the appearance editor.
---
--- The list includes all character head classes that inherit from `CharacterHead`, with the gender
--- appended to the class name. An empty string is also included as the first item in the list.
---
--- @param appearance AppearancePreset The appearance preset to get the head class names for.
--- @return table<string> A list of character head class names.
function GetCharacterHeadComboItems(appearance)
	return IsKindOf(appearance, "AppearancePreset") and GetEntityClassInherits("CharacterHead" .. GetGender(appearance)) or {}
end

--- Returns a list of character pants class names that can be used in the appearance editor.
---
--- The list includes all character pants classes that inherit from `CharacterPants`, with the gender
--- appended to the class name. An empty string is also included as the first item in the list.
---
--- @param appearance AppearancePreset The appearance preset to get the pants class names for.
--- @return table<string> A list of character pants class names.
function GetCharacterPantsComboItems(appearance)
	return IsKindOf(appearance, "AppearancePreset") and GetEntityClassInherits("CharacterPants" .. GetGender(appearance)) or {}
end

--- Returns a list of character shirt class names that can be used in the appearance editor.
---
--- The list includes all character shirt classes that inherit from `CharacterShirts`, with the gender
--- appended to the class name. An empty string is also included as the first item in the list.
---
--- @param appearance AppearancePreset The appearance preset to get the shirt class names for.
--- @return table<string> A list of character shirt class names.
function GetCharacterShirtComboItems(appearance)
	return IsKindOf(appearance, "AppearancePreset") and GetEntityClassInherits("CharacterShirts" .. GetGender(appearance)) or {}
end

--- Returns a list of character armor class names that can be used in the appearance editor.
---
--- The list includes all character armor classes that inherit from `CharacterArmor`, with the gender
--- appended to the class name. An empty string is also included as the first item in the list.
---
--- @param appearance AppearancePreset The appearance preset to get the armor class names for.
--- @return table<string> A list of character armor class names.
function GetCharacterArmorComboItems(appearance)
	return IsKindOf(appearance, "AppearancePreset") and GetEntityClassInherits("CharacterArmor" .. GetGender(appearance)) or {}
end

--- Returns a list of character hair class names that can be used in the appearance editor.
---
--- The list includes all character hair classes that inherit from `CharacterHair`, with the gender
--- appended to the class name. An empty string is also included as the first item in the list.
---
--- @param appearance AppearancePreset The appearance preset to get the hair class names for.
--- @return table<string> A list of character hair class names.
function GetCharacterHairComboItems(appearance)
	return IsKindOf(appearance, "AppearancePreset") and GetEntityClassInherits("CharacterHair" .. GetGender(appearance)) or {}
end

--- Returns a list of character hat class names that can be used in the appearance editor.
---
--- The list includes all character hat classes that inherit from `CharacterHat`.
---
--- @return table<string> A list of character hat class names.
function GetCharacterHatComboItems()
	return GetEntityClassInherits("CharacterHat")
end

--- Returns a list of character chest class names that can be used in the appearance editor.
---
--- The list includes all character chest classes that inherit from `CharacterChest`, with the gender
--- appended to the class name. An empty string is also included as the first item in the list.
---
--- @param appearance AppearancePreset The appearance preset to get the chest class names for.
--- @return table<string> A list of character chest class names.
function GetCharacterChestComboItems(appearance)
	return IsKindOf(appearance, "AppearancePreset") and GetEntityClassInherits("CharacterChest" .. GetGender(appearance)) or {}
end

--- Returns a list of character hip class names that can be used in the appearance editor.
---
--- The list includes all character hip classes that inherit from `CharacterHip`, with the gender
--- appended to the class name. An empty string is also included as the first item in the list.
---
--- @param appearance AppearancePreset The appearance preset to get the hip class names for.
--- @return table<string> A list of character hip class names.
function GetCharacterHipComboItems(appearance)
	return IsKindOf(appearance, "AppearancePreset") and GetEntityClassInherits("CharacterHip" .. GetGender(appearance)) or {}
end

if FirstLoad then
	AppearanceEditor = false
end

--- Opens the appearance editor for the given appearance preset.
---
--- This function creates a new real-time thread to open the appearance editor. If the appearance editor is not already open, it will create a new instance of the appearance editor. If the appearance editor is already open, this function will do nothing.
---
--- @param appearance AppearancePreset The appearance preset to open the editor for.
function OpenAppearanceEditor(appearance)
	CreateRealTimeThread(function(appearance)
		if not AppearanceEditor or not IsValid(AppearanceEditor) then
			AppearanceEditor = OpenPresetEditor("AppearancePreset") or false
		end
	end, appearance)
end

function OnMsg.GedOpened(ged_id)
	local gedApp = GedConnections[ged_id]
	if gedApp and gedApp.app_template == "PresetEditor" and gedApp.context and gedApp.context.PresetClass == "AppearancePreset" then
		AppearanceEditor = gedApp
	end
end

function OnMsg.GedClosing(ged_id)
	if AppearanceEditor and AppearanceEditor.ged_id == ged_id then
		if cameraMax.IsActive() then
			cameraTac.Activate(1)
		end
		AppearanceEditor = false
	end	
end

--- Closes the appearance editor if it is currently open.
---
--- This function checks if the `AppearanceEditor` variable is set, and if so, sends the "rfnApp" and "Exit" messages to it to close the editor.
function CloseAppearanceEditor()
	if AppearanceEditor then
		AppearanceEditor:Send("rfnApp", "Exit")
	end
end

local function UpdateAnimationMomentsEditor(appearance)
	local character = GetAnimationMomentsEditorObject()
	if character then
		local speed = character.anim_speed
		local frame = character.Frame
		character:ApplyAppearance(appearance)
		if speed == 0 then
			character:SetFrame(frame)
		end
	end
end

function OnMsg.GedPropertyEdited(ged_id, object, prop_id, old_value)
	if AppearanceEditor and AppearanceEditor.ged_id == ged_id then
		UpdateAnimationMomentsEditor(AppearanceEditor.selected_object.id)
	elseif AreModdingToolsActive() and g_Classes.ModItemAppearancePreset and IsKindOf(object, "ModItemAppearancePreset") then
		UpdateAnimationMomentsEditor(object.id)
	end
end

function OnMsg.GedOnEditorSelect(appearance, selected, ged)
	if selected and AppearanceEditor and AppearanceEditor.ged_id == ged.ged_id then
		UpdateAnimationMomentsEditor(appearance.id)
	end
end

OnMsg.ChangeMapDone = CloseAppearanceEditor

--- Refreshes the appearance of all units on the map that have the specified appearance.
---
--- @param root table The root object.
--- @param obj table The object whose appearance is being refreshed.
--- @param context table The context object.
function RefreshApperanceToAllUnits(root, obj, context)
	local appearance = obj.id
	MapForEach("map", "AppearanceObject", function(obj)
		if obj.Appearance == appearance then
			obj:ApplyAppearance(appearance, "force")
		end
	end)
end

DefineClass.AppearanceWeight =
{
	__parents = {"PropertyObject"},
	
	properties =
	{
		{id = "Preset", name = "Preset", editor = "combo", items = PresetsCombo("AppearancePreset"), default = "" },
		{id = "Weight", name = "Weight", editor = "number", default = 1 },
		{id = "ViewInAppearanceEditorBtn", editor = "buttons", buttons = {{name = "View in Appearance Editor", func = "ViewInAppearanceEditor"}}, dont_save = true},
		{id = "ViewInAnimMetadataEditorBtn", editor = "buttons", buttons = {{name = "View in Anim Metadata Editor", func = "ViewInAnimMetadataEditor"}}, dont_save = true},		
		{id = "GameStates", name = "Game States Required",
			editor = "set", three_state = true, default = set(),
			items = function() return GetGameStateFilter() end,
			help = "Map states requirements for the Preset to be choosen.",
		},
	},
	EditorView = Untranslated("AppearanceWeight <u(Preset)> : <Weight>")
}

---
--- Opens the Appearance Editor for the specified Appearance Preset.
---
--- @param prop_id string The property ID.
--- @param ged table The GED object.
---
function AppearanceWeight:ViewInAppearanceEditor(prop_id, ged)
	local appearance = self.Preset
	local preset = AppearancePresets[appearance] or EntitySpecPresets[appearance]
	if preset then
		preset:OpenEditor()
	end
end

---
--- Opens the Animation Metadata Editor for the specified Appearance Preset.
---
--- @param prop_id string The property ID.
--- @param ged table The GED object.
---
function AppearanceWeight:ViewInAnimMetadataEditor(prop_id, ged)
	OpenAnimationMomentsEditor(self.Preset)
end
