--- Defines the `ConstDef` class, which represents a global constant used by the game.
---
--- The `ConstDef` class has the following properties:
--- - `type`: The type of the constant, which can be "bool", "number", "text", "color", "string_list", "preset_id", or "preset_id_list".
--- - `value`: The value of the constant, which can be of the type specified by the `type` property.
--- - `scale`: The scale factor for the value, which is only applicable for "number" type constants.
--- - `translate`: A boolean indicating whether the value should be translated.
--- - `preset_class`: The preset class associated with the constant, which is only applicable for "preset_id_list" and "preset_id" type constants.
---
--- The `ConstDef` class also has the following methods:
--- - `GetLuaCode()`: Returns the Lua code to access the constant.
--- - `GetDefaultPropertyValue(prop, prop_meta)`: Returns the default value for a given property of the constant.
--- - `GetDefaultValueOf(type)`: Returns the default value for a given type of constant.
--- - `GetValueText()`: Returns the text representation of the constant's value.
DefineClass.ConstDef = {__parents={"Preset"}, properties={{id="_", editor="help",
    help="<style GedHighlight>Defined in the Lua code; only the value is editable here.", no_edit=function(obj)
        return not obj.from_lua
    end, buttons={{name="Edit Code", func=function(obj)
        OpenFileLineInHaerald(obj.from_file, obj.from_line)
    end}}}, {id="type", editor="choice", default="number",
    items={"bool", "number", "text", "color", "string_list", "preset_id", "preset_id_list"}},
    {id="value", editor=function(obj)
        return obj.type
    end, default=0, item_default="", scale=function(obj)
        return obj.scale
    end, translate=function(obj)
        return obj.translate
    end, preset_class=function(obj)
        return obj.preset_class
    end}, {id="scale", editor="choice", default=1, no_edit=function(obj)
        return obj.type ~= "number"
    end, items=function()
        return table.keys2(const.Scale, true, 1, 10, 100, 1000)
    end}, {id="translate", editor="bool", default=false, no_edit=function(obj)
        return obj.type ~= "text"
    end}, {id="preset_class", editor="choice", default=false, items=function()
        return table.keys(Presets, true)
    end, no_edit=function(obj)
        return obj.type ~= "preset_id_list" and obj.type ~= "preset_id"
    end}, -- help
    {id="__", editor="help", help="This constant is accessible from Lua as:"},
    {id="LuaCode", name="Lua code", editor="text", read_only=true, dont_save=true, default="",
        buttons={{name="Copy", func=function(obj)
            CopyToClipboard(obj:GetLuaCode())
            GedDisplayTempStatus("clipboard", "Copied to clipboard")
        end}}}}, EditorView=Untranslated(
    "<id> <color GedName><ValueText><color 128 128 128><opt(u(save_in), ' - ', '')><color 0 128 0><opt(u(Comment),' ','')>"),
    EditorMenubarName="Consts", EditorMenubar="Editors.Lists", EditorIcon="CommonAssets/UI/Icons/pi.png",
    Documentation="Allows modifying the global constants used by the game.", -- for constants defined from the Lua code
    from_lua=false, from_file=false, from_line=false, default_value=false, default_scale=false}

---
--- This function is called after all classes have been processed. It sets the `read_only` property of certain properties in the `ConstDef` class to `true` if the constant is defined in Lua code.
---
--- The properties affected are:
--- - `value`
--- - `scale`
--- - `LuaCode`
---
--- This ensures that these properties cannot be edited in the editor if the constant is defined in Lua code.
---
function OnMsg.ClassesPostprocess()
	for _, prop in ipairs(ConstDef.properties) do
		if prop.id ~= "value" and prop.id ~= "scale" and prop.id ~= "LuaCode" then
			prop.read_only = function(obj) return obj.from_lua end
		end
	end
end

---
--- Returns the Lua code representation of the constant.
---
--- If the constant is in the "Default" group, the code will be `const.{id}`.
--- Otherwise, the code will be `const{accessor}.{id}`, where `accessor` is either a dot or a bracketed string, depending on whether the group contains spaces.
---
--- @param self ConstDef
--- @return string The Lua code representation of the constant
---
function ConstDef:GetLuaCode()
    local group = self.group
    local accessor = group:find("%s") and string.format('["%s"]', group) or string.format(".%s", group)
    return self.group == "Default" and string.format("const.%s", self.id)
               or string.format("const%s.%s", accessor, self.id)
end

---
--- Returns the default property value for the specified property.
---
--- If the constant is defined in Lua code (`from_lua` is true) and the property is `"value"` or `"scale"`, the default value or scale is returned, respectively.
--- Otherwise, the default property value is retrieved from the `Preset` class.
---
--- @param self ConstDef The ConstDef instance.
--- @param prop string The property name.
--- @param prop_meta table The property metadata.
--- @return any The default property value.
---
function ConstDef:GetDefaultPropertyValue(prop, prop_meta)
    if self.from_lua and prop == "value" then
        return self.default_value
    end
    if self.from_lua and prop == "scale" then
        return self.default_scale
    end
    return Preset.GetDefaultPropertyValue(self, prop, prop_meta)
end

---
--- Returns the default value for the specified type.
---
--- @param type string The type of the constant.
--- @return any The default value for the specified type.
---
function ConstDef:GetDefaultValueOf(type)
    type = type or "number"
    if type == "number" then
        return 0
    elseif type == "text" then
        return ""
    elseif type == "color" then
        return white
    elseif type == "bool" then
        return true
    end
    return false
end

---
--- Returns the text representation of the constant's value based on its type.
---
--- For boolean constants, returns "true" or "false".
--- For number constants, formats the value using `FormatNumberProp`.
--- For color constants, returns the RGBA values as a string.
--- For list constants, returns a comma-separated string of the values.
--- For preset ID constants, returns the value as a string.
---
--- @param self ConstDef The ConstDef instance.
--- @return string The text representation of the constant's value.
---
function ConstDef:GetValueText()
    local t = self.type
    if t == "bool" then
        return self.value and "true" or "false"
    elseif t == "number" then
        return FormatNumberProp(tonumber(self.value) or 0, self.scale)
    elseif t == "color" then
        return string.format("%d %d %d %d", GetRGBA(self.value))
    elseif t == "preset_id_list" or t == "string_list" then
        return table.concat(self.value, ", ")
    elseif t == "preset_id" then
        return self.value or ""
    end
    return "???"
end

---
--- Handles updates to the `translate` and `type` properties of a `ConstDef` instance.
---
--- When the `translate` property is updated, the `value` property is updated with the localized value.
--- When the `type` property is updated, the `value` property is set to the default value for the new type.
---
--- @param self ConstDef The `ConstDef` instance.
--- @param prop_id string The ID of the property that was updated.
--- @param old_value any The previous value of the property.
--- @param ged table The Game Editor data.
---
function ConstDef:OnEditorSetProperty(prop_id, old_value, ged)
    if prop_id == "translate" then
        self:UpdateLocalizedProperty("value", self.translate)
    end
    if prop_id == "type" then
        self.value = self:GetDefaultValueOf(self.type)
    end
end

---
--- Returns the save path for a ConstDef instance based on the `save_in` property.
---
--- If `save_in` is empty, the path is "Lua/__const.lua".
--- If `save_in` is "Common", the path is "CommonLua/Data/__const.lua".
--- If `save_in` starts with "Libs/", the path is "CommonLua/{save_in}/Data/__const.lua".
--- Otherwise, the path is "svnProject/Dlc/{save_in}/Code/__const.lua".
---
--- @param self ConstDef The ConstDef instance.
--- @param save_in string The save location for the ConstDef.
--- @return string The save path for the ConstDef.
---
function ConstDef:GetSavePath(save_in)
    save_in = save_in or self.save_in
    if save_in == "" then
        return "Lua/__const.lua"
    end
    if save_in == "Common" then
        return "CommonLua/Data/__const.lua"
    end
    if save_in:starts_with("Libs/") then
        return string.format("CommonLua/%s/Data/__const.lua", save_in)
    end
    return string.format("svnProject/Dlc/%s/Code/__const.lua", save_in)
end

---
--- Generates the save data for a list of ConstDef presets.
---
--- This function iterates through the provided presets and generates Lua code to define each preset that has been modified from its default value. The generated code is appended to the provided code string.
---
--- @param file_path string The file path where the constants will be saved.
--- @param presets table A list of ConstDef presets to save.
--- @param code_pstr string An optional code string to append the generated code to.
--- @return string The code string containing the generated save data.
---
function ConstDef:GetSaveData(file_path, presets, code_pstr)
    local code = code_pstr or pstr(exported_files_header_warning, 16384)
    for idx, preset in ipairs(presets) do
        if not preset.from_lua or ValueToLuaCode(preset.value) ~= ValueToLuaCode(preset.default_value) then
            if preset.from_lua then
                -- only save the editable values for consts defined with DefineConstFromCode
                preset = setmetatable({id=preset.id, group=preset.group, value=preset.value, scale=preset.scale},
                    g_Classes.ConstDef)
            end
            -- clear defaults
            if not preset.translate then
                preset.translate = nil
            end
            if not preset.preset_class then
                preset.preset_class = nil
            end
            if preset.scale == 1 then
                preset.scale = nil
            end
            if preset.group == ConstDef.group then
                preset.group = nil
            end
            if preset.id == "" then
                preset.id = nil
            end
            if preset.type == "number" then
                preset.type = nil
            end
            if preset.save_in == "" then
                preset.save_in = nil
            end

            code:append("DefineConst")
            preset:GenerateLocalizationContext(preset)
            TableToLuaCode(preset, nil, code)
            code:append("\n")
        end
    end
    return code
end

--- Initializes the Presets and g_PresetLastSavePaths tables if they don't already exist.
---
--- This code is executed when the file is first loaded. It checks if the Presets and g_PresetLastSavePaths tables exist in the global scope, and initializes them if they don't.
---
--- @global Presets table The table of preset configurations.
--- @global g_PresetLastSavePaths table The table of last save paths for presets.
--- @return nil
if FirstLoad then
	Presets = rawget(_G, "Presets") or {}
	PresetsLoadingFileName = false
	g_PresetLastSavePaths = rawget(_G, "g_PresetLastSavePaths") or {}
end

-- as Lua is reloaded, invalididate the constants, ensuring a Lua crash if a constant is used before it is defined via DefineConstXXX
---
--- Resets the global constants defined in the `Presets.ConstDef` table.
---
--- This function iterates through all the preset groups in `Presets.ConstDef`, and removes the corresponding constants from the `const` table. It then resets the `Presets.ConstDef` table to an empty table, and returns the old presets.
---
--- @return table The old presets that were removed.
---
function ResetConstants()
    for _, group in ipairs(Presets.ConstDef) do
        for _, preset in ipairs(group) do
            local group_id = preset.group
            if group_id == "Default" then
                const[preset.id] = nil
            else
                local const_group = const[group_id]
                if const_group and rawget(const_group, preset.id) ~= nil then -- might be a LuaVar table (set up with SetupVarTable)
                    const_group[preset.id] = nil
                end
            end
        end
    end
    local old_presets = Presets.ConstDef
    Presets.ConstDef = {}
    return old_presets
end

---
--- Resets the global constants defined in the `Presets.ConstDef` table.
---
--- This function iterates through all the preset groups in `Presets.ConstDef`, and removes the corresponding constants from the `const` table. It then resets the `Presets.ConstDef` table to an empty table, and returns the old presets.
---
--- @return table The old presets that were removed.
---
local old_root = ResetConstants()
local groups = Presets.ConstDef
local const = const
---
--- Defines a new constant in the Presets.ConstDef table.
---
--- This function takes a table `obj` with the following fields:
--- - `group`: the group the constant belongs to (default is "Default")
--- - `id`: the unique identifier for the constant (optional)
--- - `type`: the type of the constant (e.g. "number", "string", "boolean")
--- - `value`: the value of the constant (optional, will use the default value for the type if not provided)
---
--- The function will add the constant to the appropriate group in the `Presets.ConstDef` table, and also add it to the `const` table, which is used to access the constants globally.
---
--- @param obj table The table containing the constant definition.
--- @return any The old value of the constant, if it was previously defined.
function DefineConst(obj)
    local obj_group = obj.group or "Default"
    assert(obj.group ~= "")
    local group = groups[obj_group]
    if group then
        group[#group + 1] = obj
    else
        group = {obj}
        groups[obj_group] = group
        groups[#groups + 1] = group
    end
    local const_group = obj_group == "Default" and const or const[obj_group]
    if not const_group then
        const_group = {}
        const[obj_group] = const_group
    end
    local value = obj.value
    if value == nil then
        value = ConstDef:GetDefaultValueOf(obj.type)
    end
    local id = obj.id or ""
    local old_value
    if id == "" then
        const_group[#const_group + 1] = value
    else
        old_value = const_group[id]
        const_group[id] = value
        group[id] = obj
    end
    g_PresetLastSavePaths[obj] = PresetsLoadingFileName
    return old_value
end

-- compatibility
LoadCommonConsts = empty_func
LoadDlcConsts = empty_func

---
--- Loads constants from the specified Lua file.
---
--- @param filename string The path to the Lua file containing the constants.
---
local function loadconsts(filename)
    PresetsLoadingFileName = filename
    pdofile(filename)
    PresetsLoadingFileName = false
end

---
--- Loads all the constants defined in the game, including common, project, DLC, and mod constants.
---
--- This function is called early in the game initialization process to ensure that constant values are available for use throughout the codebase.
---
--- The function loads constants from the following files:
--- - CommonLua/Data/__const.lua: Common constants
--- - [LibPath]/Data/__const.lua: Constants for each library
--- - Lua/__GameConst.lua: Project-specific constants
--- - Lua/__const.lua: Additional project constants
--- - [DlcFolder]/Code/__const.lua: Constants for each DLC
--- - Mod constants: Constants defined by loaded mods
---
--- After loading all constants, the function sends the "LoadConsts" message.
---
--- @function LoadConsts
--- @return nil
function LoadConsts()
	-- common consts
	loadconsts("CommonLua/Data/__const.lua")
	ForEachLib("", function (lib, path)
		loadconsts(path .. "__GameConst.lua")
		loadconsts(path .. "Data/__const.lua")
	end)
	
	-- project consts
	loadconsts("Lua/__GameConst.lua")
	loadconsts("Lua/__const.lua")
	
	-- DLC consts
	for _, dlc_folder in ipairs(rawget(_G, "DlcFolders")) do
		loadconsts(dlc_folder .. "/Code/__const.lua")
	end
	
	-- Mod consts
	for _, mod in ipairs(config.Mods and rawget(_G, "ModsLoaded")) do
		if mod:ItemsLoaded() then
			mod:ForEachModItem("ModItemConstDef", function(item)
				item:AssignToConsts()
			end)
		end
	end
	Msg("LoadConsts")
end

---
--- Loads all the constants defined in the game, including common, project, DLC, and mod constants.
---
--- This function is called early in the game initialization process to ensure that constant values are available for use throughout the codebase.
---
--- @function LoadConsts
--- @return nil
if not Platform.ged then
	LoadConsts() -- load constants as early as possible, so their values (possibly project-redefined) can be used on the global Lua scope
end

---
--- Handles the case where a ConstDef preset for a const, defined from the Lua code, was deleted.
---
--- This function is called when a preset is saved, and if the preset is a ConstDef, it triggers a real-time thread to reload the Lua code.
---
--- @param class string The class of the preset that was saved.
--- @return nil
function OnMsg.PresetSave(class)
    local classdef = g_Classes[class]
    if IsKindOf(classdef, "ConstDef") then
        CreateRealTimeThread(ReloadLua) -- handles the case where a ConstDef preset for a const, defined from the Lua code, was deleted
    end
end

---
--- Fixes the metatables of all ConstDef presets.
---
--- This function is called when the ClassesBuilt message is received, and when a ConstDef preset is reloaded.
---
--- It iterates through all ConstDef presets, sets their metatable to the ConstDef class, and then sorts the presets.
---
--- Finally, it rebinds the root of the ConstDef presets in the GED.
---
--- @function FixConstMetatables
--- @return nil
local function FixConstMetatables()
    ForEachPresetExtended("ConstDef", function(preset, group, ConstDef)
        setmetatable(preset, ConstDef)
    end, ConstDef)

    ConstDef:SortPresets()
    GedRebindRoot(old_root, Presets.ConstDef)
end

---
--- Fixes the metatables of all ConstDef presets when the ClassesBuilt message is received, or when a ConstDef preset is reloaded.
---
--- This function iterates through all ConstDef presets, sets their metatable to the ConstDef class, and then sorts the presets. Finally, it rebinds the root of the ConstDef presets in the GED.
---
--- @function FixConstMetatables
--- @return nil
OnMsg.ClassesBuilt = FixConstMetatables
ConstDef.OnDataReloaded = FixConstMetatables

---
--- Retrieves the value of a constant defined in the `const` table.
---
--- If the constant does not exist, a warning message is printed and the default value is returned.
---
--- @param group string The group the constant belongs to.
--- @param name string The name of the constant.
--- @param default any The default value to return if the constant does not exist.
--- @return any The value of the constant, or the default value if the constant does not exist.
function GetConst(group, name, default)
    local tbl = const[group]
    local value = tbl and tbl[name]
    if value == nil then
        printf("once", "No such const: %s.%s", group, name)
        return default
    end
    return value
end


-- Use to define a constant and its default value from Lua code.
-- It appears in the ConstDef editor, and its value can be tweaked from there.
---
--- Defines a constant from Lua code and adds it to the ConstDef editor.
---
--- This function is used to define a constant with a specific type, group, ID, value, scale, and comment. It checks if the constant has already been defined in the ConstDef editor, and if so, it uses the values from the editor. Otherwise, it creates a new constant definition.
---
--- The function also records the source location of the constant definition (file and line number) for debugging purposes.
---
--- @param obj table A table containing the properties of the constant to be defined, including type, group, ID, value, scale, and comment.
--- @return nil
function DefineConstFromCode(obj)
    assert(Loading)

    local def_scale, def_value = obj.scale, obj.value
    local group = groups[obj.group]
    local preset = group and group[obj.id]
    if preset then -- const was redefined from the Const editor, and has been loaded from file
        preset.Comment = obj.Comment
        obj = preset -- use the value/scale from the redefined Const preset; fill in rest of the data in it
    end

    local info = debug.getinfo(3)
    obj.from_lua = true
    obj.from_file = info.short_src
    obj.from_line = info.currentline
    obj.default_value = def_value
    obj.default_scale = def_scale
    if not preset then
        local old_value = DefineConst(obj)
        assert(old_value == nil or old_value == obj.value,
            string.format("const.%s%s redefined with a different value, likely as LuaVar in C++ and then in Lua.",
                obj.group == "Default" and "" or (obj.group .. "."), obj.id))
    end
end

--- Defines a constant integer value with an optional scale factor.
---
--- This function is used to define a constant integer value with an optional scale factor. The scale factor is used to adjust the value of the constant, for example to convert between different units of measurement.
---
--- If no scale factor is provided, a default scale of 1 is used.
---
--- @param group string The group that the constant belongs to.
--- @param id string The unique identifier for the constant.
--- @param value number The value of the constant.
--- @param scale string|number The scale factor to apply to the value. Can be a string representing a predefined scale, or a number.
--- @param comment string A brief description of the constant.
--- @return nil
function DefineConstInt(group, id, value, scale, comment)
	if not scale or scale == "" then scale = 1 end
	assert(type(scale) ~= "string" or const.Scale[scale]) -- maybe const.Scale is not yet defined for the scale you are trying to use
	
	value = value * (const.Scale[scale] or tonumber(scale) or 1)
	DefineConstFromCode{ type = "number", group = group, id = id, value = value, scale = scale, Comment = comment }
end

---
--- Defines a constant string value.
---
--- This function is used to define a constant string value. The value is stored in the global `const` table with the specified group and ID.
---
--- @param group string The group that the constant belongs to.
--- @param id string The unique identifier for the constant.
--- @param value string The value of the constant.
--- @param comment string A brief description of the constant.
--- @return nil
function DefineConstString(group, id, value, comment)
    DefineConstFromCode {type="text", group=group, id=id, value=value, Comment=comment}
end

--- Defines a constant boolean value.
---
--- This function is used to define a constant boolean value. The value is stored in the global `const` table with the specified group and ID.
---
--- @param group string The group that the constant belongs to.
--- @param id string The unique identifier for the constant.
--- @param value boolean The value of the constant.
--- @param comment string A brief description of the constant.
--- @return nil
function DefineConstBool(group, id, value, comment)
    DefineConstFromCode {type="bool", group=group, id=id, value=value, Comment=comment}
end
