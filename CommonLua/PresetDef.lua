---
--- Returns a function that generates a list of class names that are descendants of the specified base class.
---
--- @param base_class string|nil The base class to filter by. If nil, defaults to "Preset".
--- @param filter function|nil An optional filter function to apply to the list of class names.
--- @param param1 any Optional parameter to pass to the filter function.
--- @param param2 any Optional second parameter to pass to the filter function.
--- @return function A function that returns a list of class names.
---
function PresetClassesCombo(base_class, filter, param1, param2)
	return function (obj)
		return ClassDescendantsList(base_class or "Preset", filter, obj, param1, param2)
	end
end

---
--- Defines a class for preset definitions, which are used to configure and customize the behavior of presets in the game.
---
--- The `PresetDef` class inherits from the `ClassDef` class and provides a set of properties that can be used to configure various aspects of a preset, such as whether it has groups, parameters, a companion file, or is stored in a single file. It also provides options for customizing the editor behavior, such as the editor menu name, shortcut, icon, and custom actions.
---
--- The `PresetDef` class is used to define the properties and behavior of presets in the game, and is typically used in conjunction with other classes and systems that work with presets.
---
DefineClass.PresetDef = {
	__parents = { "ClassDef" },
	properties = {
		{ category = "Misc", id = "DefGlobalMap", name = "GlobalMap", editor = "text", default = "", },
		{ category = "Misc", id = "DefHasGroups", name = "Organize in groups", editor = "bool", default = Preset.HasGroups, },
		{ category = "Misc", id = "DefPresetGroupPreset", name = "Groups preset class", editor = "choice", default = false, items = PresetClassesCombo(), },
		{ category = "Misc", id = "DefHasSortKey", name = "Has SortKey", editor = "bool", default = Preset.HasSortKey, },
		{ category = "Misc", id = "DefHasParameters", name = "Has parameters", editor = "bool", default = Preset.HasParameters, },
		{ category = "Misc", id = "DefHasCompanionFile", name = "Has companion file", editor = "bool", default = Preset.HasCompanionFile, },
		{ category = "Misc", id = "DefHasObsolete", name = "Has Obsolete", editor = "bool", default = Preset.HasObsolete, },
		{ category = "Misc", id = "DefSingleFile", name = "Store in single file", editor = "bool", default = Preset.SingleFile, },
		{ category = "Misc", id = "DefPropertyTranslation", name = "Translate property names", editor = "bool", default = Preset.PropertyTranslation, },
		{ category = "Misc", id = "DefPresetClass", name = "Preset base class", editor = "choice", default = false, items = PresetClassesCombo(), },
		{ category = "Misc", id = "DefContainerClass", name = "Container sub-items class", editor = "text", default = "", },
		{ category = "Misc", id = "DefPersistAsReference", name = "Persist as reference", editor = "bool", default = true, help = "When true preset instances will only be referenced by savegames, if false used preset instance data will be saved."},
		{ category = "Misc", id = "DefModItem", name = "Define ModItem", editor = "bool", default = false, },
		{ category = "Misc", id = "DefModItemName", name = "ModItem name", editor = "text", default = "", no_edit = function(self) return not self.DefModItem end, },
		{ category = "Misc", id = "DefModItemSubmenu", name = "ModItem submenu", editor = "text", default = "Other", no_edit = function(self) return not self.DefModItem end, },
		{ category = "Editor", id = "DefGedEditor", name = "Editor class", editor = "text", default = Preset.GedEditor, },
		{ category = "Editor", id = "DefEditorName", name = "Editor menu name", editor = "text", default = "", },
		{ category = "Editor", id = "DefEditorShortcut", name = "Editor shortcut", editor = "shortcut", default = Preset.EditorShortcut, },
		{ category = "Editor", id = "DefEditorIcon", name = "Editor icon", editor = "text", default = Preset.EditorIcon, },
		{ category = "Editor", id = "DefEditorMenubar", name = "Editor menu", editor = "combo", default = "Editors", items = ClassValuesCombo("Preset", "EditorMenubar"), },
		{ category = "Editor", id = "DefEditorMenubarSortKey", name = "Editor SortKey", editor = "text", default = "" },
		{ category = "Editor", id = "DefFilterClass", name = "Filter class", editor = "combo", items = ClassDescendantsCombo("GedFilter"), default = "", },
		{ category = "Editor", id = "DefSubItemFilterClass", name = "Subitems filter class", editor = "combo", items = ClassDescendantsCombo("GedFilter"), default = "", },
		{ category = "Editor", id = "DefAltFormat", name = "Alternative format string", editor = "text", default = "", },
		{ category = "Editor", id = "DefEditorCustomActions", name = "Custom editor actions", editor = "nested_list", default = false, base_class = "EditorCustomActionDef", inclusive = true },
		{ category = "Editor", id = "DefTODOItems", name = "TODO items", editor = "string_list", default = false, },
	},
	group = "PresetDefs",
	DefParentClassList = { "Preset" },
	GlobalMap = "PresetDefs",
	EditorViewPresetPrefix = "<color 75 105 198>[Preset]</color> ",
}

--- Generates constant definitions for the PresetDef class.
---
--- This function is responsible for appending constant definitions to the provided code object.
--- It defines constants for various properties of the PresetDef class, such as HasGroups, PresetGroupPreset, HasSortKey, etc.
--- If the PresetDef has any custom editor actions defined, it also appends those to the code object.
---
--- @param code CodeGenerator The code generator object to append the constant definitions to.
function PresetDef:GenerateConsts(code)
	self:AppendConst(code, "HasGroups")
	self:AppendConst(code, "PresetGroupPreset", "")
	self:AppendConst(code, "HasSortKey")
	self:AppendConst(code, "HasParameters")
	self:AppendConst(code, "HasCompanionFile")
	self:AppendConst(code, "HasObsolete")
	self:AppendConst(code, "SingleFile")
	self:AppendConst(code, "PropertyTranslation")
	self:AppendConst(code, "GlobalMap", "")
	self:AppendConst(code, "PresetClass", "")
	self:AppendConst(code, "ContainerClass")
	self:AppendConst(code, "PersistAsReference")
	self:AppendConst(code, "GedEditor")
	self:AppendConst(code, "EditorMenubarName", false, "DefEditorName")
	self:AppendConst(code, "EditorShortcut")
	self:AppendConst(code, "EditorIcon")
	self:AppendConst(code, "EditorMenubar")
	self:AppendConst(code, "EditorMenubarSortKey")
	self:AppendConst(code, "FilterClass", "")
	self:AppendConst(code, "SubItemFilterClass", "")
	self:AppendConst(code, "AltFormat", "")
	self:AppendConst(code, "TODOItems")
	
	if self.DefEditorCustomActions and #self.DefEditorCustomActions > 0 then
		local result = {}
		for idx, action in ipairs(self.DefEditorCustomActions) do
			if action.Name ~= "" then
				local action_copy = table.raw_copy(action)
				table.insert(result, action_copy)
			end
		end
		code:append("\tEditorCustomActions = ")
		code:appendv(result)
		code:append(",\n")
	end
	ClassDef.GenerateConsts(self, code)
end

--- Generates methods for the PresetDef class.
---
--- This function is responsible for generating methods for the PresetDef class. If the PresetDef has a ModItem defined, it generates a method to define the ModItem preset. It then calls the GenerateMethods function of the parent ClassDef class to generate any additional methods.
---
--- @param code CodeGenerator The code generator object to append the method definitions to.
function PresetDef:GenerateMethods(code)
	if self.DefModItem then
		code:appendf('DefineModItemPreset("%s", { EditorName = "%s", EditorSubmenu = "%s" })\n\n', self.id, self.DefModItemName, self.DefModItemSubmenu)
	end
	ClassDef.GenerateMethods(self, code)
end

--- Returns an error message if the PresetDef has an invalid ModItem configuration.
---
--- This function checks if the PresetDef has a ModItem defined, and if so, whether the ModItem name has been specified. If the ModItem name is empty, it returns an error message. Otherwise, it calls the `GetError` function of the parent `ClassDef` class to get any additional error messages.
---
--- @return string The error message, or `nil` if there are no errors.
function PresetDef:GetError()
	if self.DefModItem and (self.DefModItemName or "") == "" then
		return "ModItem name must be specified."
	end
	return ClassDef.GetError(self)
end


----- ClassAsGroupPresetDef

--- Defines a class for a preset that is part of a group of presets.
---
--- The `ClassAsGroupPresetDef` class inherits from the `PresetDef` class and adds additional properties and methods to handle presets that are part of a group.
---
--- The class has the following properties:
--- - `GroupPresetClass`: The class name of the group preset that this preset belongs to.
--- - `DefHasGroups`: Indicates whether the preset has groups.
--- - `DefGedEditor`: The GED editor for the preset.
--- - `DefEditorName`: The name of the preset in the editor.
--- - `DefEditorShortcut`: The shortcut for the preset in the editor.
--- - `DefEditorIcon`: The icon for the preset in the editor.
--- - `DefEditorMenubar`: The menubar for the preset in the editor.
--- - `DefEditorMenubarSortKey`: The sort key for the preset in the editor menubar.
--- - `DefFilterClass`: The filter class for the preset.
--- - `DefSubItemFilterClass`: The sub-item filter class for the preset.
--- - `DefEditorCustomActions`: The custom actions for the preset in the editor.
--- - `DefTODOItems`: The TODO items for the preset.
--- - `DefPresetClass`: The preset class for the preset.
---
--- The class also has an `EditorViewPresetPrefix` property that is used to display the preset in the editor.
DefineClass.ClassAsGroupPresetDef = {
	__parents = { "PresetDef", },
	properties = {
		{ category = "Preset", id = "GroupPresetClass", name = "Preset group class", editor = "choice", default = false, 
			items = PresetClassesCombo("Preset", function(class_name, class) return class.PresetClass == class_name end), 
			help = "Only Presets with .PresetClass == <class_name> are listed here"},
		{ id = "DefHasGroups", editor = false },
		{ id = "DefGedEditor", editor = false },
		{ id = "DefEditorName", editor = false },
		{ id = "DefEditorShortcut", editor = false },
		{ id = "DefEditorIcon", editor = false },
		{ id = "DefEditorMenubar", editor = false },
		{ id = "DefEditorMenubarSortKey", editor = false },
		{ id = "DefFilterClass", editor = false },
		{ id = "DefSubItemFilterClass", editor = false },
		{ id = "DefEditorCustomActions", editor = false },
		{ id = "DefTODOItems", editor = false },
		{ id = "DefPresetClass", editor = false },
	},
	EditorViewPresetPrefix = Untranslated("<color 75 105 198>[<def(GroupPresetClass,'GroupPreset')>]</color> "),
}

--- Initializes the `DefParentClassList` property for a `ClassAsGroupPresetDef` object.
---
--- The `DefParentClassList` property is set to either:
--- - The existing `DefParentClassList` value, if it exists.
--- - A table containing the `GroupPresetClass` value, if it exists.
--- - `nil`, if neither `DefParentClassList` nor `GroupPresetClass` exist.
---
--- This method is called during the initialization of a `ClassAsGroupPresetDef` object.
--- Initializes the `DefParentClassList` property for a `ClassAsGroupPresetDef` object.
---
--- The `DefParentClassList` property is set to either:
--- - The existing `DefParentClassList` value, if it exists.
--- - A table containing the `GroupPresetClass` value, if it exists.
--- - `nil`, if neither `DefParentClassList` nor `GroupPresetClass` exist.
---
--- This method is called during the initialization of a `ClassAsGroupPresetDef` object.
function ClassAsGroupPresetDef:Init()
self.DefParentClassList = rawget(self, "DefParentClassList") or self.GroupPresetClass and { self.GroupPresetClass } or nil
end

--- Gets the default value for the `DefParentClassList` property of a `ClassAsGroupPresetDef` object.
---
--- If the `id` parameter is `"DefParentClassList"`, this function returns a table containing the `GroupPresetClass` value. Otherwise, it calls the `GetDefaultPropertyValue` function of the parent `PresetDef` class.
---
--- @param id string The ID of the property to get the default value for.
--- @param prop_meta table The metadata for the property.
--- @return any The default value for the property.
function ClassAsGroupPresetDef:GetDefaultPropertyValue(id, prop_meta)
	if id == "DefParentClassList" then
		return { self.GroupPresetClass }
	end
	return PresetDef.GetDefaultPropertyValue(self, id, prop_meta)
end

---
--- Handles the `OnEditorSetProperty` event for the `ClassAsGroupPresetDef` class.
---
--- When the `GroupPresetClass` property is set, this function updates the `DefParentClassList` property:
--- - Removes the old `GroupPresetClass` value from the `DefParentClassList`.
--- - Ensures the `DefParentClassList` is a table, even if it was previously `nil`.
--- - Checks if any of the existing `DefParentClassList` classes are ancestors of the new `GroupPresetClass`.
--- - If not, adds the new `GroupPresetClass` to the beginning of the `DefParentClassList`.
---
--- Finally, it calls the `OnEditorSetProperty` function of the parent `PresetDef` class.
---
--- @param prop_id string The ID of the property that was set.
--- @param old_value any The previous value of the property.
--- @param ged table The GED editor object.
--- @return any The result of calling the parent `PresetDef.OnEditorSetProperty` function.
function ClassAsGroupPresetDef:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "GroupPresetClass" then
		table.remove_entry(self.DefParentClassList, old_value)
		self.DefParentClassList = rawget(self, "DefParentClassList") or {}
		for _, class_name in ipairs(self.DefParentClassList) do
			local class = g_Classes[class_name]
			if class and class.__ancestors[self.GroupPresetClass] then
				return
			end
		end
		table.insert(self.DefParentClassList, 1, self.GroupPresetClass)
	end
	return PresetDef.OnEditorSetProperty(self, prop_id, old_value, ged)
end

---
--- Generates constants for the `ClassAsGroupPresetDef` class.
---
--- This function calls the `GenerateConsts` function of the parent `PresetDef` class, and then appends a constant for the `id` property of the `ClassAsGroupPresetDef` object.
---
--- @param code table The code table to append the constants to.
function ClassAsGroupPresetDef:GenerateConsts(code)
	PresetDef.GenerateConsts(self, code)
	code:appendf("\tgroup = \"%s\",\n", self.id)
end


----- EditorCustomActionDef

---
--- Defines a custom action for the editor.
---
--- The `EditorCustomActionDef` class is used to define custom actions that can be added to the editor's toolbar or menu bar. These actions can perform various functions, such as toggling a property or executing a custom function.
---
--- The properties of this class define the various aspects of the custom action, such as its name, rollover text, function name, and icon.
---
--- @class EditorCustomActionDef
--- @field Name string The name of the custom action.
--- @field Rollover string The rollover text for the custom action.
--- @field FuncName string The name of the function to be executed when the custom action is triggered.
--- @field IsToggledFuncName string The name of the function that determines whether the custom action is toggled.
--- @field Toolbar string The name of the toolbar where the custom action should be displayed.
--- @field Menubar string The name of the menu bar where the custom action should be displayed.
--- @field SortKey string The sort key used to determine the order of the custom action in the toolbar or menu bar.
--- @field Shortcut string The keyboard shortcut for the custom action.
--- @field Icon string The path to the icon image for the custom action.
DefineClass.EditorCustomActionDef = {
	__parents = { "PropertyObject" },
	properties = {
		{ id = "Name", editor = "text", default = "", },
		{ id = "Rollover", editor = "text", default = "", },
		{ id = "FuncName", editor = "text", default = "", },
		{ id = "IsToggledFuncName", editor = "text", default = "" },
		{ id = "Toolbar", editor = "text", default = "", },
		{ id = "Menubar", editor = "text", default = "", },
		{ id = "SortKey", editor = "text", default = "", },
		{ id = "Shortcut", editor = "shortcut", default = "", },
		{ id = "Icon", editor = "ui_image", default = "CommonAssets/UI/Ged/cog.tga" },
	},
	EditorView = Untranslated("<Name><opt(u(Shortcut),' - ','')>"),
}


----- DCLPropertiesDef

local blacklist = {
	ClassDef = true, FXPreset = true, XTemplate = true, AnimMetadata = true,
	SoundPreset = true, SoundTypePreset = true, ReverbDef = true, NoisePreset = true,
}

---
--- Defines a DLC properties class that can be used to add properties to existing preset classes.
---
--- The `DLCPropertiesDef` class is used to define additional properties that can be added to existing preset classes when a DLC is installed. This allows for extending the functionality of existing game objects without modifying the core game code.
---
--- The properties of this class define the DLC to which the properties should be added, the preset class to which the properties should be added, and various metadata about the properties themselves.
---
--- @class DLCPropertiesDef
--- @field SaveIn string The DLC to which the properties should be added.
--- @field add_to_preset string The preset class to which the properties should be added.
--- @field DefParentClassList table A list of parent classes for the DLC properties.
--- @field DefPropertyTranslation table A table of property translations for the DLC properties.
--- @field DefStoreAsTable boolean Whether the DLC properties should be stored as a table.
--- @field DefPropertyTabs table A table of property tabs for the DLC properties.
--- @field DefUndefineClass boolean Whether the DLC properties class should be undefined.
DefineClass.DLCPropertiesDef = {
	__parents = { "ClassDef" },
	properties = {
		{ id = "SaveIn", name = "Add properties in DLC", editor = "choice", default = "", 
			items = function(obj) return obj:GetPresetSaveLocations() end, },
		{ id = "add_to_preset", name = "In preset class", editor = "choice", default = "",
			-- try to list only game-specific presets
			items = ClassDescendantsCombo("Preset", false, function(name, preset)
				local class = preset.PresetClass or preset.class
				return preset.class == class and next(Presets[class]) and Presets[class][1][1].save_in == "" and not blacklist[class]
			end)
		},
		{ id = "DefParentClassList", editor = false, },
		{ id = "DefPropertyTranslation", editor = false, },
		{ id = "DefStoreAsTable", editor = false, },
		{ id = "DefPropertyTabs", editor = false, },
		{ id = "DefUndefineClass", editor = false, },
	},
}

---
--- Gets the object class and whether it is a composite object for the DLC properties.
---
--- @return string object_class The class to add the DLC properties to.
--- @return boolean is_composite Whether the object class is a composite object.
function DLCPropertiesDef:GetObjectClass()
	local preset_class = g_Classes[self.add_to_preset]
	local is_composite = preset_class:IsKindOf("CompositeDef")
	return is_composite and preset_class.ObjectBaseClass or self.add_to_preset, is_composite
end

---
--- Generates the extra code for a DLC property definition.
---
--- This function is responsible for generating the extra code that should be added to a property definition when the property is part of a DLC. It determines the appropriate class and template string to use based on whether the property is being added to a composite object.
---
--- @param prop_def table The property definition for which to generate the extra code.
--- @return string The extra code to add to the property definition.
function DLCPropertiesDef:GeneratePropExtraCode(prop_def)
	local object_class, is_composite = self:GetObjectClass()
	local override_prop = object_class and g_Classes[object_class]:GetPropertyMetadata(prop_def.id)
	assert(not override_prop or override_prop.dlc_override or override_prop.dlc == self.save_in)
	local template_str = is_composite and "template = true, " or ""
	return override_prop and not override_prop.dlc and
		string.format('%sdlc = "%s", maingame_prop_id = "%s", id = "%s%sDLC"', template_str, self.save_in, prop_def.id, prop_def.id, self.save_in) or
		string.format('%sdlc = "%s"', template_str, self.save_in)
end

---
--- Generates the global code for the DLC properties definition.
---
--- This function is responsible for generating the global code that should be added when the DLC properties are defined. It calls the base class's `GenerateGlobalCode` function and then appends a call to `DefineDLCProperties` with the appropriate parameters.
---
--- @param code CodeWriter The code writer to append the global code to.
function DLCPropertiesDef:GenerateGlobalCode(code)
	ClassDef.GenerateGlobalCode(self, code)
	code:appendf('DefineDLCProperties("%s", "%s", "%s", "%s")\n\n',
		self:GetObjectClass(), self.add_to_preset, self.save_in, self.id)
end

local hintColor = RGB(210, 255, 210)
---
--- Gets the error message for the DLCPropertiesDef if the required parameters are not set.
---
--- @return table The error message and hint color.
function DLCPropertiesDef:GetError()
	if self.save_in == "" then
		return { "Specify the DLC to add the properties of this class to.", hintColor }
	elseif self.add_to_preset == "" then
		return { "Add the properties to which preset?\n\nIn case of composite objects, specify the CompositDef preset; properties will be added to its ObjectBaseClass.", hintColor }
	end
end
