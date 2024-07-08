DefineClass.ClassDefSubItem = {
	__parents = { "PropertyObject" },
}

---
--- Converts a value to a string with color formatting.
---
--- @param value any The value to convert to a string.
--- @param t string The type of the value.
--- @return string The formatted string with color tags.
---
function ClassDefSubItem:ToStringWithColor(value, t)
	local text = t and value or ValueToLuaCode(value)
	t = t or type(value)
	local color
	if t == "string" or IsT(value) then
		color = RGB(60, 140, 40)
	elseif t == "boolean" or t == "nil" then
		color = RGB(75, 105, 198)
	elseif t == "number" then
		color = RGB(150, 50, 20)
	elseif t == "function" then
		text = string.gsub(text, "^function ", "<color 75 105 198>function</color><color 92 92 92>")
		text = string.gsub(text, "end$", "<color 75 105 198>end</color>")
	end
	if not color then
		return text
	end
	local r, g, b = GetRGB(color)
	return string.format("<color %s %s %s><tags off>%s<tags on></color>", r, g, b, text)
end


----- PropertyDef

local function GetCategoryItems(self)
	local categories = PresetGroupCombo("PropertyCategory", "Default")()
	local parent
	ForEachPreset("ClassDef", function(preset)
		parent = parent or table.find(preset, self) and preset
	end)
	if parent then
		local tmp = table.invert(categories)
		for _, prop in ipairs(parent) do
			if IsKindOf(prop, "PropertyDef") then
				tmp[prop.category or ""] = true
			end
		end
		categories = table.keys(tmp)
	end
	table.sort(categories, function(a, b)
		if a and b then
			return a < b
		else
			return b
		end
	end)
	return categories
end

local reusable_expressions = {
	dont_save = "Don't save",
	read_only = "Read only",
	no_edit = "Hidden",
	no_validate = "No validation",
}

local function reusable_expressions_combo(self)
	local ret = {
		{ text = "true", value = true },
		{ text = "false", value = false },
		{ text = "expression", value = "expression"},
	}
	local preset = GetParentTableOfKind(self, "ClassDef")
	for _, property_def in ipairs(preset) do
		if IsKindOf(property_def, "PropertyDef") then
			for id, name in pairs(reusable_expressions) do
				if property_def[id] == "expression" then
					table.insert(ret, {
						text = "Reuse " .. name .. " from " .. property_def.id,
						value = property_def.id .. "." .. id
					})
				end
			end
		end
	end
	return ret
end

---
--- Validates that the given `value` is a valid identifier string.
---
--- An identifier must start with a letter or underscore, and can contain only
--- letters, digits, and underscores.
---
--- @param self table The `PropertyDef` instance.
--- @param value string The value to validate.
--- @return string|nil An error message if the value is invalid, or `nil` if valid.
function ValidateIdentifier(self, value)
	return (type(value) ~= "string" or not value:match("^[%a_][%w_]*$")) and "Please enter a valid identifier"
end

DefineClass.PropertyDef = {
	__parents = { "ClassDefSubItem" },
	properties = {
		{ category = "Property", id = "category", name = "Category", editor = "combo", items = GetCategoryItems, default = false, },
		{ category = "Property", id = "id", name = "Id", editor = "text", default = "", validate = ValidateIdentifier },
		{ category = "Property", id = "name", name = "Name", editor = "text", translate = function(self) return self.translate_in_ged end, default = false },
		{ category = "Property", id = "help", name = "Help", editor = "text", translate = function(self) return self.translate_in_ged end, lines = 1, max_lines = 3, default = false },
		
		{ category = "Property", id = "dont_save", name = "Don't save", editor = "choice", default = false, items = reusable_expressions_combo },
		{ category = "Property", id = "dont_save_expression", name = "Don't save", editor = "expression", default = return_true, params = "self, prop_meta",
			no_edit = function(self) return type(self.dont_save) == "boolean" end,
			read_only = function(self) return self.dont_save ~= "expression" end,
			dont_save = function(self) return self.dont_save ~= "expression" end, },
		{ category = "Property", id = "read_only", name = "Read only", editor = "choice", default = false, items = reusable_expressions_combo },
		{ category = "Property", id = "read_only_expression", name = "Read only", editor = "expression", default = return_true, params = "self, prop_meta",
			no_edit = function(self) return type(self.read_only) == "boolean" end,
			read_only = function(self) return self.read_only ~= "expression" end,
			dont_save = function(self) return self.read_only ~= "expression" end, },
		{ category = "Property", id = "no_edit", name = "Hidden", editor = "choice", default = false, items = reusable_expressions_combo },
		{ category = "Property", id = "no_edit_expression", name = "Hidden", editor = "expression", default = return_true, params = "self, prop_meta",
			no_edit = function(self) return type(self.no_edit) == "boolean" end,
			read_only = function(self) return self.no_edit ~= "expression" end,
			dont_save = function(self) return self.no_edit ~= "expression" end, },
		{ category = "Property", id = "no_validate", name = "No validation", editor = "choice", default = false, items = reusable_expressions_combo },
		{ category = "Property", id = "no_validate_expression", name = "No validation", editor = "expression", default = return_true,  params = "self, prop_meta",
			no_edit = function(self) return type(self.no_validate) == "boolean" end,
			read_only = function(self) return self.no_validate ~= "expression" end,
			dont_save = function(self) return self.no_validate ~= "expression" end, },
		
		{ category = "Property", id = "buttons", name = "Buttons", editor = "nested_list", base_class = "PropertyDefPropButton", default = false, inclusive = true, 
		  help = "Button function is searched by name in the object, the root parent (Preset?), and then globally.\n\nParameters are (self, root, prop_id, ged) for the object method, (root, obj, prop_id, ged) otherwise." },
		{ category = "Property", id = "template", name = "Template", editor = "bool", default = false, help = "Marks template properties for classes which inherit 'ClassTemplate'"},
		{ category = "Property", id = "validate", name = "Validate", editor = "expression", params = "self, value", help = "A function called by Ged when changing the value. Returns error, updated_value."},
		{ category = "Property", id = "extra_code", name = "Extra Code", editor = "text", lines = 1, max_lines = 5, default = false, help = "Additional code to insert in the property metadata" },
	},
	editor = false,
	validate = false,
	context = false,
	gender = false,
	os_path = false,
	translate_in_ged = false,
}

---
--- Generates a string representation of the editor view for a property definition.
---
--- @param self PropertyDef The property definition object.
--- @return string The editor view string.
---
function PropertyDef:GetEditorView()
	local category = ""
	if self.category then
		category = string.format("<color 45 138 138>[%s]</color> ", self.category)
	end
	return string.format("%s<color 75 105 198>%s</color> %s <color 158 158 158>=</color> <color 150 90 40>%s",
		category, self.editor, self.id, self:ToStringWithColor(self.default))
end

local function getTranslatableValue(text, translate)
	if not text or text == "" then return end
	if text then
		assert(IsT(text) == translate)
	end
	return text
end

local reuse_error_fn = function() return "Unable to locate expression to reuse." end
local reuse_prop_ids = { dont_save_expression = "dont_save", read_only_expression = "read_only", no_edit_expression = "no_edit", no_validate_expression = "no_validate" }

---
--- Gets the property value from the current object or reuses an expression from another property.
---
--- @param self PropertyDef The property definition object.
--- @param prop string The name of the property to get.
--- @return function|nil The property value or a reused expression function, or nil if not found.
---
function PropertyDef:GetProperty(prop)
	local main_prop_id = reuse_prop_ids[prop]
	if main_prop_id then
		local value = self:GetProperty(main_prop_id)
		if type(value) == "string" and value ~= "expression" then
			local reuse_prop_id, reuse = value:match("([%w_]+)%.([%w_]+)")
			if reuse then
				local preset = GetParentTableOfKind(self, "ClassDef")
				local property_def = table.find_value(preset, "id", reuse_prop_id)
				return property_def and property_def[reuse .. "_expression"] or reuse_error_fn
			end
		end
	end
	return ClassDefSubItem.GetProperty(self, prop)
end

---
--- Generates the expression setting code for a property definition.
---
--- @param self PropertyDef The property definition object.
--- @param id string The name of the expression setting property.
---
function PropertyDef:GenerateExpressionSettingCode(code, id)
	local value = self[id]
	if type(value) ~= "boolean" then
		local expr = self:GetProperty(id .. "_expression")
		if expr ~= reuse_error_fn then
			code:appendf("%s = function(self) %s end, ", id, GetFuncBody(expr))
		end
	elseif value then
		code:appendf("%s = true, ", id)
	end
end

---
--- Generates the code for a property definition.
---
--- @param self PropertyDef The property definition object.
--- @param code CodeWriter The code writer to append the generated code to.
--- @param translate function A function to translate text.
--- @param extra_code_fn function An optional function to generate additional code.
---
function PropertyDef:GenerateCode(code, translate, extra_code_fn)
	if self.id == "" then return end
	code:append("\t\t{ ")
	if self.category and self.category ~= "" then
		code:appendf("category = \"%s\", ", self.category)
	end
	code:append("id = \"", self.id, "\", ")
	local name, help = getTranslatableValue(self.name, translate), getTranslatableValue(self.help, translate)
	if name then
		code:append("name = ", ValueToLuaCode(name), ", ")
	end
	if help then
		code:append("help = ", ValueToLuaCode(help), ", ")
	end
	code:append("\n\t\t\t")
	code:appendf("editor = \"%s\", default = %s, ", self.editor, self:GenerateDefaultValueCode())
	
	self:GenerateExpressionSettingCode(code, "dont_save")
	self:GenerateExpressionSettingCode(code, "read_only")
	self:GenerateExpressionSettingCode(code, "no_edit")
	self:GenerateExpressionSettingCode(code, "no_validate")
	if self.validate then
		code:appendf("validate = function(self, value) %s end, ", GetFuncBody(self.validate))
	end
	
	if self.buttons and #self.buttons > 0 then
		code:append("buttons = {")
		for _, data in ipairs(self.buttons) do
			if data.Name ~= "" then
				if data.IsHidden ~= empty_func then
					code:appendf([[ {name = "%s", func = "%s", is_hidden = function(self) %s end }, ]], data.Name, data.FuncName, GetFuncBody(data.IsHidden))
				else
					code:appendf([[ {name = "%s", func = "%s"}, ]], data.Name, data.FuncName)
				end
			end
		end
		code:append("}, ")
	end
	if self.template then code:append("template = true, ") end
	if self.extra_code and self.extra_code ~= "" or extra_code_fn then
		local ext_code = self.extra_code and self.extra_code:gsub(",$", "")
		if extra_code_fn then
			ext_code = ext_code and (ext_code .. ", " .. extra_code_fn(self)) or extra_code_fn(self)
			ext_code = ext_code:gsub(",$", "")
		end
		if ext_code and ext_code ~= "" then
			code:append("\n\t\t\t", ext_code)
			code:append(", ")
		end
	end
	self:GenerateAdditionalPropCode(code, translate)
	code:append("},\n")
end

---
--- Generates the default value code for a property definition.
---
--- @param self PropertyDef The property definition object.
--- @return string The Lua code representing the default value.
function PropertyDef:GenerateDefaultValueCode()
	return ValueToLuaCode(self.default, ' ', nil, {} --[[ enable property injection ]])
end

---
--- Validates the property defined by the `PropertyDef` object.
---
--- If the `no_validate` flag is not set, this function delegates the validation to the `ValidateProperty` method of the `PropertyObject` class.
---
--- @param prop_meta table The property metadata to validate.
--- @return boolean True if the property is valid, false otherwise.
function PropertyDef:ValidateProperty(prop_meta)
	if not self.no_validate then
		return PropertyObject.ValidateProperty(self, prop_meta)
	end
end

---
--- Generates additional property code for the `PropertyDef` object.
---
--- This function is called to generate any additional code that needs to be appended to the property definition.
---
--- @param code CodeBuilder The code builder object to append the additional code to.
--- @param translate function The translation function to use for localizing any strings.
---
function PropertyDef:GenerateAdditionalPropCode(code, translate)
end

---
--- Appends the function code for the specified property to the provided code builder.
---
--- @param code CodeBuilder The code builder to append the function code to.
--- @param prop_name string The name of the property to append the function code for.
---
function PropertyDef:AppendFunctionCode(code, prop_name)
	if not self[prop_name] then return end
	local name, params, body = GetFuncSource(self[prop_name])
	code:appendf("%s = function (%s)\n", prop_name, params)
	if type(body) == "string" then
		body = string.split(body, "\n")
	end
	code:append("\t", body and table.concat(body, "\n\t") or "", "\n")
	code:append("end, \n")
end

---
--- Checks if the `PropertyDef` object has any extra code that defines the `items` property, and returns an error message if it does.
---
--- This is to ensure that the `items` property is defined using the dedicated `Items` property instead of in the extra code, to make the items appear in the default value property.
---
--- @return string|nil The error message if the `items` property is defined in the extra code, or `nil` if there is no error.
function PropertyDef:GetError()
	if not self.no_validate and self.extra_code and (self.extra_code:find("[^%w_]items%s*=") or self.extra_code:find("^items%s*=")) then
		return "Please don't define 'items' as extra code. Use the dedicated Items property instead.\nThis is to make items appear in the default value property."
	end
end

---
--- Cleans up the `PropertyDef` object before saving.
---
--- This function is called to perform any necessary cleanup or preparation of the `PropertyDef` object before it is saved.
---
--- @param self PropertyDef The `PropertyDef` object to clean up.
---
function PropertyDef:CleanupForSave()
end

---
--- Emulates the property evaluation process for the given property metadata.
---
--- This function is used to evaluate a property's value based on the provided metadata, default value, and optional validation function.
---
--- @param metadata_id string The identifier of the property metadata to evaluate.
--- @param default any The default value to use if the property metadata is not found or cannot be evaluated.
--- @param prop_meta table The property metadata object.
--- @param validate_fn function An optional validation function to apply to the evaluated value.
--- @return any The evaluated property value.
function PropertyDef:EmulatePropEval(metadata_id, default, prop_meta, validate_fn)
	local prop_meta = self
	local classdef_preset = GetParentTableOfKind(self, "ClassDef")
	if not classdef_preset then return default end
	local obj_class = g_Classes[classdef_preset.id]
	local instance = obj_class and not obj_class:IsKindOf("CObject") and obj_class:new() or {}
	if validate_fn then
		return eval_items(prop_meta[metadata_id], instance, prop_meta)
	end
	return prop_eval(prop_meta[metadata_id], instance, prop_meta, default)
end

local function EmulatePropEval(metadata_id, default)
	return function(self, prop_meta, validate_fn)
		return self:EmulatePropEval(metadata_id, default, prop_meta, validate_fn)
	end
end

DefineClass.PropertyDefPropButton = {
	__parents = { "PropertyObject" },
	properties = {
		{ id = "Name", editor = "text", default = ""},
		{ id = "FuncName", editor = "text", default = ""},
		{ id = "IsHidden", editor = "expression", default = empty_func},
	},
	EditorView = Untranslated("[<Name>] = <FuncName>"),
}

DefineClass.PropertyDefButtons = {
	__parents = { "PropertyDef" },
	properties = {
		{ id = "default", name = "Default value", editor = false, default = false, },
	},	
	editor = "buttons",
	EditorName = "Buttons property",
	EditorSubmenu = "Extras",
}

DefineClass.PropertyDefBool = {
	__parents = { "PropertyDef" },
	properties = {
		{ category = "Bool", id = "default", name = "Default value", editor = "bool", default = false, },
	},
	editor = "bool",
	EditorName = "Bool property",
	EditorSubmenu = "Basic property",
}

DefineClass.PropertyDefTable = {
	__parents = { "PropertyDef" },
	properties = {
		{ category = "Table", id = "default", name = "Default value", editor = "prop_table", default = false, },
		{ category = "Table", id = "lines",   name = "Lines",         editor = "number", default = 1, },
	},
	editor = "prop_table",
	EditorName = "Table property",
	EditorSubmenu = "Objects",
}

---
--- Generates additional property code for a `PropertyDefTable` object.
---
--- @param code table The code table to append the additional code to.
--- @param translate function The translation function to use.
---
--- If the `lines` property of the `PropertyDefTable` is greater than 1, this function will append additional code to the `code` table to handle multiple lines of the table property.
---
function PropertyDefTable:GenerateAdditionalPropCode(code, translate)
	if self.lines > 1 then
		code:append("indent = \"\", lines = 1, max_lines = ", self.lines, ", ")
	end
end

DefineClass.PropertyDefPoint = {
	__parents = { "PropertyDef" },
	properties = {
		{ category = "Point", id = "default", name = "Default value", editor = "point", default = false, },
	},
	editor = "point",
	EditorName = "Point property",
	EditorSubmenu = "Basic property",
}

DefineClass.PropertyDefPoint2D = {
	__parents = { "PropertyDef" },
	properties = {
		{ category = "Point2D", id = "default", name = "Default value", editor = "point2d", default = false, },
	},
	editor = "point2d",
	EditorName = "Point2D property",
	EditorSubmenu = "Basic property",
}

DefineClass.PropertyDefRect = {
	__parents = { "PropertyDef" },
	properties = {
		{ category = "Rect", id = "default", name = "Default value", editor = "rect", default = false, },
	},
	editor = "rect",
	EditorName = "Rect property",
	EditorSubmenu = "Basic property",
}

DefineClass.PropertyDefMargins = {
	__parents = { "PropertyDef" },
	properties = {
		{ category = "Margins", id = "default", name = "Default value", editor = "margins", default = false, },
	},
	editor = "margins",
	EditorName = "Margins property",
	EditorSubmenu = "Extras",
}

DefineClass.PropertyDefPadding = {
	__parents = { "PropertyDef" },
	properties = {
		{ category = "Padding", id = "default", name = "Default value", editor = "padding", default = false, },
	},
	editor = "padding",
	EditorName = "Padding property",
	EditorSubmenu = "Extras",
}

DefineClass.PropertyDefBox = {
	__parents = { "PropertyDef" },
	properties = {
		{ category = "Box", id = "default", name = "Default value", editor = "box", default = false, },
	},
	editor = "box",
	EditorName = "Box property",
	EditorSubmenu = "Basic property",
}

DefineClass.PropertyDefNumber = {
	__parents = { "PropertyDef" },
	properties = {
		{ category = "Number", id = "default", name = "Default value", editor = "number", default = false, scale = function(obj) return obj.scale end, min = function(obj) return obj.min end, max = function(obj) return obj.max end, },
		{ category = "Number", id = "scale", name = "Scale", editor = "choice", default = 1, items = function() return table.keys2(const.Scale, true, 1, 10, 100, 1000, 1000000) end, },
		{ category = "Number", id = "step", name = "Step", editor = "number", default = 1, scale = function(obj) return obj.scale end, },
		{ category = "Number", id = "float", name = "Float", editor = "bool", default = false, },
		{ category = "Number", id = "slider", name = "Slider", editor = "bool", default = false, },
		{ category = "Number", id = "min", name = "Min", editor = "number", default = min_int64, scale = function(obj) return obj.scale end, no_edit = PropChecker("custom_lims", true)},
		{ category = "Number", id = "max", name = "Max", editor = "number", default = max_int64, scale = function(obj) return obj.scale end, no_edit = PropChecker("custom_lims", true) },
		{ category = "Number", id = "custom_min", name = "Min", editor = "expression", default = false, no_edit = PropChecker("custom_lims", false) },
		{ category = "Number", id = "custom_max", name = "Max", editor = "expression", default = false, no_edit = PropChecker("custom_lims", false) },
		{ category = "Number", id = "custom_lims", name = "Custom Lims", editor = "bool", default = false, help = "Use custom limits"},
		{ category = "Number", id = "modifiable", name = "Modifiable", editor = "bool", default = false, help = "Marks modifiable properties for classes which inherit 'Modifiable' class"},
	},
	editor = "number",
	EditorName = "Number property",
	EditorSubmenu = "Basic property",
}

---
--- Generates additional property code for a `PropertyDefNumber` object.
---
--- @param code table The code table to append the additional property code to.
--- @param translate boolean Whether to translate the property values.
---
function PropertyDefNumber:GenerateAdditionalPropCode(code, translate)
	local scale = self.scale
	if scale ~= 1 then
		code:appendf(type(scale) == "number" and "scale = %d, " or "scale = \"%s\", ", scale)
	end
	if self.step ~= 1 then code:appendf("step = %d, ", self.step) end
	if self.slider then code:append("slider = true, ") end
	if self.custom_lims then
		if self.custom_min ~= PropertyDefNumber.custom_min then
			local name, params, body = GetFuncSource(self.custom_min)
			body = type(body) == "table" and table.concat(body, "\n") or body
			code:appendf("min = function(self) %s end, ", body)
		end
		if self.custom_max ~= PropertyDefNumber.custom_max then
			local name, params, body = GetFuncSource(self.custom_max)
			body = type(body) == "table" and table.concat(body, "\n") or body
			code:appendf("max = function(self) %s end, ", body)
		end
	else
		if self.min ~= PropertyDefNumber.min then code:appendf("min = %d, ", self.min) end
		if self.max ~= PropertyDefNumber.max then code:appendf("max = %d, ", self.max) end
	end
	if self.modifiable then code:append("modifiable = true, ") end
end

---
--- Callback function that is called when a property of the `PropertyDefNumber` class is set in the editor.
---
--- If the "Slider" property is set to true, this function will automatically set the "Min" property to 0 and the "Max" property to 100 times the current scale value, if the "Min" and "Max" properties are set to their default values.
---
--- @param prop_id string The ID of the property that was set
--- @param old_value any The previous value of the property
--- @param ged table The GED (Game Editor) object associated with the property
---
function PropertyDefNumber:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "slider" and self.slider then
		if self.min == PropertyDefNumber.min then self.min = 0 end
		if self.max == PropertyDefNumber.max then self.max = 100 * (const.Scale[self.scale] or self.scale) end
	end
end

DefineClass.PropertyDefRange = {
	__parents = { "PropertyDef" },
	properties = {
		{ category = "Range", id = "default", name = "Default value", editor = "range", scale = function(obj) return obj.scale end, min = function(obj) return obj.min end, max = function(obj) return obj.max end, default = false, },
		{ category = "Range", id = "scale", name = "Scale", editor = "choice", default = 1, items = function() return table.keys2(const.Scale, true, 1, 10, 100, 1000, 1000000) end, },
		{ category = "Range", id = "step", name = "Step", editor = "number", default = 1, scale = function(obj) return obj.scale end, },
		{ category = "Range", id = "slider", name = "Slider", editor = "bool", default = false, },
		{ category = "Range", id = "min", name = "Min", editor = "number", default = min_int64 },
		{ category = "Range", id = "max", name = "Max", editor = "number", default = max_int64 },
	},
	editor = "range",
	EditorName = "Range property",
	EditorSubmenu = "Basic property",
}

---
--- Generates additional property code for a `PropertyDefRange` object.
---
--- This function is responsible for generating the property code for a `PropertyDefRange` object, which is a type of property definition used in the game editor. The generated code includes information about the scale, step, slider, minimum, and maximum values of the property.
---
--- @param code CodeBuilder The code builder object to append the generated code to.
--- @param translate boolean Whether the property is translatable or not.
---
function PropertyDefRange:GenerateAdditionalPropCode(code, translate)
	if self.scale ~= 1 then
		code:appendf(type(self.scale) == "number" and "scale = %d, " or "scale = \"%s\", ", self.scale)
	end
	if self.step ~= 1 then code:appendf("step = %d, ", self.step) end
	if self.slider then code:append("slider = true, ") end
	if self.min ~= PropertyDefRange.min then code:appendf("min = %d, ", self.min) end
	if self.max ~= PropertyDefRange.max then code:appendf("max = %d, ", self.max) end
end

---
--- Callback function that is called when the "Slider" property of a `PropertyDefNumber` object is set in the editor.
---
--- If the "Slider" property is set to true, this function will automatically set the "Min" property to 0 and the "Max" property to 100 times the current scale value, if the "Min" and "Max" properties are set to their default values.
---
--- @param prop_id string The ID of the property that was set
--- @param old_value any The previous value of the property
--- @param ged table The GED (Game Editor) object associated with the property
---
function PropertyDefRange:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "slider" and self.slider then
		if self.min == PropertyDefRange.min then self.min = 0 end
		if self.max == PropertyDefRange.max then self.max = 100 * (const.Scale[self.scale] or self.scale) end
	end
end

local function translate_only(obj) return not obj.translate end
TextGenderOptions = {
	{value = false, text = "None"},
	{value = "ask", text = "Request translation gender for each language (for nouns)"},
	{value = "variants", text = "Generate separate translation texts for each gender"},
}

DefineClass.PropertyDefText = {
	__parents = { "PropertyDef" },
	properties = {
		{ category = "Text", id = "default", name = "Default value", editor = "text", default = false, translate = function (obj) return obj.translate end, },
		{ category = "Text", id = "translate", name = "Translate", editor = "bool", default = true, },
		{ category = "Text", id = "wordwrap", name = "Wordwrap", editor = "bool", default = false, },
		{ category = "Text", id = "gender", name = "Gramatical gender", editor = "choice", default = false, items = TextGenderOptions,
			no_edit = translate_only, dont_save = translate_only },
		{ category = "Text", id = "lines", name = "Lines", editor = "number", default = false, },
		{ category = "Text", id = "max_lines", name = "Max lines", editor = "number", default = false, },
		{ category = "Text", id = "trim_spaces", name = "Trim Spaces", editor = "bool", default = true, },
		{ category = "Text", id = "context", name = "Context", editor = "text", default = "", 
			no_edit = translate_only, dont_save = translate_only }
	},
	editor = "text",
	EditorName = "Text property",
	EditorSubmenu = "Basic property",
}

---
--- Callback function that is called when the "Translate" property of a `PropertyDefText` object is set in the editor.
---
--- This function updates the localized property "default" based on the value of the "translate" property.
---
--- @param prop_id string The ID of the property that was set
--- @param old_value any The previous value of the property
--- @param ged table The GED (Game Editor) object associated with the property
---
function PropertyDefText:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "translate" then
		self:UpdateLocalizedProperty("default", self.translate)
	end
end

---
--- Generates additional property code for a `PropertyDefText` object.
---
--- This function appends various property values to the provided `code` object, including:
--- - `translate`: Whether the property should be translated.
--- - `wordwrap`: Whether the text should be word-wrapped.
--- - `lines`: The number of lines for the text.
--- - `max_lines`: The maximum number of lines for the text.
--- - `trim_spaces`: Whether to trim leading and trailing spaces from the text.
--- - `context`: The context for the text, which may include a gender specification.
---
--- @param code CodeBuffer The code buffer to append the property values to.
--- @param translate boolean Whether the property should be translated.
---
function PropertyDefText:GenerateAdditionalPropCode(code, translate)
	if self.translate then code:append("translate = true, ") end
	if self.wordwrap then code:append("wordwrap = true, ") end
	if self.lines then code:appendf("lines = %d, ", self.lines) end
	if self.max_lines then code:appendf("max_lines = %d, ", self.max_lines) end	
	if self.trim_spaces==false then	code:append("trim_spaces = false, ") end
	local context = self.translate and self.context or ""
	if context ~= "" then
		assert(not self.gender, "Custom context code is not compatible with gender specification") -- you should include |gender-ask or |gender-variants in the function result
		code:append("context = ", context, ", ")
	elseif self.gender then
		code:append('context = "|gender-', self.gender, '", ')
	end
end

DefineClass.PropertyDefChoice = {
	__parents = { "PropertyDef" },
	properties = {
		{ category = "Choice", id = "default", name = "Default value", editor = "choice", default = false, items = EmulatePropEval("items", {""}) },
		{ category = "Choice", id = "items", name = "Items", editor = "expression", default = false, },
		{ category = "Choice", id = "show_recent_items", name = "Show recent items", editor = "number", default = 0, },
	},
	translate = false,
	editor = "choice",
	EditorName = "Choice property",
	EditorSubmenu = "Basic property",
}

---
--- Generates additional property code for a `PropertyDefChoice` object.
---
--- This function appends the following property values to the provided `code` object:
--- - `items`: The list of items for the choice property.
--- - `show_recent_items`: The number of recent items to show in the choice property.
---
--- @param code CodeBuffer The code buffer to append the property values to.
--- @param translate boolean Whether the property should be translated.
---
function PropertyDefChoice:GenerateAdditionalPropCode(code, translate)
	if self.items then
		code:append("items = ")
		ValueToLuaCode(self.items, nil, code)
		code:append(", ")
	end
	if self.show_recent_items and self.show_recent_items ~= 0 then
		code:appendf("show_recent_items = %d,", self.show_recent_items)
	end
end

---
--- Gets the preset class associated with the choice property.
---
--- If the `items` property is set, this function extracts the preset class name from the source code of the `items` property.
---
--- @return string|nil The preset class name, or `nil` if no preset class is associated with the choice property.
---
function PropertyDefChoice:GetConvertToPresetIdClass()
	local preset_class
	if self.items then
		local src = GetFuncSourceString(self.items)
		local _, _, capture = string.find(src, 'PresetsCombo%("([%w_+-]*)"%)')
		preset_class = capture
	end
	return preset_class
end

DefineClass.PropertyDefCombo = {
	__parents = { "PropertyDef" },
	properties = {
		{ category = "Combo", id = "default", name = "Default value", editor = "combo", default = false, items = EmulatePropEval("items", {""}) },
		{ category = "Combo", id = "items", name = "Items", editor = "expression", default = false, },
		{ category = "Combo", id = "translate", name = "Translate", editor = "bool", default = false, },
		{ category = "Combo", id = "show_recent_items", name = "Show recent items", editor = "number", default = 0, },
	},
	editor = "combo",
	EditorName = "Combo property",
	EditorSubmenu = "Basic property",
}

PropertyDefCombo.GenerateAdditionalPropCode = PropertyDefChoice.GenerateAdditionalPropCode

DefineClass.PropertyDefPickerBase = {
	__parents = { "PropertyDef" },
	properties = {
		{ category = "Picker", id = "default", name = "Default value", editor = "combo", default = false, items = EmulatePropEval("items", {""}) },
		{ category = "Picker", id = "items", name = "Items", editor = "expression", default = false, },
		{ category = "Picker", id = "max_rows", name = "Max rows", editor = "number", default = false, help = "Maximum number of rows displayed." },
		{ category = "Picker", id = "multiple", name = "Multiple selection", editor = "bool", default = false, },
		{ category = "Picker", id = "small_font", name = "Small font", editor = "bool", default = false, },
		{ category = "Picker", id = "filter_by_prop", name = "Filter by prop", editor = "text", default = false, help = "Links this property to a text property with the specified id that serves as a filter." },
	},
}

---
--- Generates additional property code for a PropertyDefPickerBase object.
---
--- This function is responsible for generating the additional property code for a PropertyDefPickerBase object, which is a base class for various picker-related property definitions.
---
--- @param code       A code object to which the additional property code will be appended.
--- @param translate  A boolean indicating whether the property should be translated.
---
function PropertyDefPickerBase:GenerateAdditionalPropCode(code, translate)
	PropertyDefChoice.GenerateAdditionalPropCode(self, code, translate)
	if self.max_rows       then code:appendf("max_rows = %d, ", self.max_rows) end
	if self.multiple       then code:append ("multiple = true, ") end
	if self.small_font     then code:append ("small_font = true, ") end
	if self.filter_by_prop then code:appendf("filter_by_prop = \"%s\", ", self.filter_by_prop) end
end

DefineClass.PropertyDefTextPicker = {
	__parents = { "PropertyDefPickerBase" },
	properties = {
		{ category = "Picker", id = "horizontal", name = "Horizontal", editor = "bool", default = false, help = "Display items horizontally." },
	},
	editor = "text_picker",
	EditorName = "Text picker property",
	EditorSubmenu = "Extras",
}

---
--- Generates additional property code for a PropertyDefTextPicker object.
---
--- This function is responsible for generating the additional property code for a PropertyDefTextPicker object, which is a subclass of PropertyDefPickerBase.
---
--- @param code       A code object to which the additional property code will be appended.
--- @param translate  A boolean indicating whether the property should be translated.
---
function PropertyDefTextPicker:GenerateAdditionalPropCode(code, translate)
	PropertyDefPickerBase.GenerateAdditionalPropCode(self, code, translate)
	if self.horizontal then code:append("horizontal = true, ") end
end

DefineClass.PropertyDefTexturePicker = {
	__parents = { "PropertyDefPickerBase" },
	properties = {
		{ category = "Picker", id = "thumb_width", name = "Width", editor = "number", default = false, },
		{ category = "Picker", id = "thumb_height", name = "Height", editor = "number", default = false, },
		{ category = "Picker", id = "thumb_zoom", name = "Zoom", editor = "number", min = 100, max = 200, slider = true, default = false, help = "Scale the texture up, displaying only the middle part with Width x Height dimensions.", },
		{ category = "Picker", id = "alt_prop", name = "Alt prop", editor = "text", default = false, help = "Id of another property that gets set by Alt-click on this property.", },
		{ category = "Picker", id = "base_color_map", name = "Base color map", editor = "bool", default = false, help = "Use to display a base color map texture in the correct colors.", },
	},
	editor = "texture_picker",
	EditorName = "Texture picker property",
	EditorSubmenu = "Extras",
}

---
--- Generates additional property code for a PropertyDefTexturePicker object.
---
--- This function is responsible for generating the additional property code for a PropertyDefTexturePicker object, which is a subclass of PropertyDefPickerBase. It sets various properties related to the texture picker, such as the thumbnail width and height, zoom level, alternate property, and whether to use a base color map.
---
--- @param code       A code object to which the additional property code will be appended.
--- @param translate  A boolean indicating whether the property should be translated.
---
function PropertyDefTexturePicker:GenerateAdditionalPropCode(code, translate)
	PropertyDefPickerBase.GenerateAdditionalPropCode(self, code, translate)
	if self.thumb_width    then code:appendf("thumb_width = %d, ", self.thumb_width) end
	if self.thumb_height   then code:appendf("thumb_height = %d, ", self.thumb_height) end
	if self.thumb_zoom     then code:appendf("thumb_zoom = %d, ", self.thumb_zoom) end
	if self.alt_prop       then code:appendf("alt_prop = \"%s\", ", self.alt_prop) end
	if self.base_color_map then code:append ("base_color_map = true, ") end
end

DefineClass.PropertyDefSet = {
	__parents = { "PropertyDef" },
	properties = {
		{ category = "Set", id = "default", name = "Default value", editor = "set", default = false, items = EmulatePropEval("items", {""}), three_state = function(obj) return obj.three_state end, max_items_in_set = function(obj) return obj.max_items_in_set end, },
		{ category = "Set", id = "items", name = "Items", editor = "expression", default = false, },
		{ category = "Set", id = "arbitrary_value", name = "Allow arbitrary value", editor = "bool", default = false, },
		{ category = "Set", id = "three_state", name = "Three-state", editor = "bool", default = false, help = "Each set item can have one of the three value 'nil', 'true', or 'false'." },
		{ category = "Set", id = "max_items_in_set", name = "Max items", editor = "number", default = 0, help = "Max number of items in the set (0 = no limit)." },
	},
	translate = false,
	editor = "set",
	EditorName = "Set property",
	EditorSubmenu = "Basic property",
}

---
--- Generates additional property code for a PropertyDefSet object.
---
--- This function is responsible for generating the additional property code for a PropertyDefSet object, which is a subclass of PropertyDef. It sets various properties related to the set property, such as whether it is a three-state set, whether arbitrary values are allowed, and the maximum number of items in the set.
---
--- @param code       A code object to which the additional property code will be appended.
--- @param translate  A boolean indicating whether the property should be translated.
---
function PropertyDefSet:GenerateAdditionalPropCode(code, translate)
	if self.three_state then code:append("three_state = true, ") end
	if self.arbitrary_value then code:append("arbitrary_value = true, ") end
	if self.max_items_in_set ~= 0 then code:appendf("max_items_in_set = %d, ", self.max_items_in_set) end
	if self.items then 
		code:append("items = ")
		ValueToLuaCode(self.items, nil, code)
		code:append(", ")
	end
end

DefineClass.PropertyDefGameStatefSet = {
	__parents = { "PropertyDef" },
	properties = {
		{ category = "Set", id = "default", name = "Default value", editor = "set", default = false, items = function() return GetGameStateFilter() end, three_state = true, },
	},
	translate = false,
	editor = "set",
	EditorName = "GameState Set property",
	EditorSubmenu = "Basic property",
}

---
--- Generates additional property code for a PropertyDefGameStatefSet object.
---
--- This function is responsible for generating the additional property code for a PropertyDefGameStatefSet object, which is a subclass of PropertyDef. It sets the `three_state` property to `true`, and the `items` property to a function that returns the result of `GetGameStateFilter()`. It also adds a button to the property editor with the name "Check Game States" and the function `PropertyDefGameStatefSetCheck`.
---
--- @param code       A code object to which the additional property code will be appended.
--- @param translate  A boolean indicating whether the property should be translated.
---
function PropertyDefGameStatefSet:GenerateAdditionalPropCode(code, translate)
	code:append("three_state = true, items = function (self) return GetGameStateFilter() end, ")
	code:append('buttons = { {name = "Check Game States", func = "PropertyDefGameStatefSetCheck"}, },')
end

---
--- Checks the game states associated with a PropertyDefGameStatefSet object and displays a message dialog.
---
--- This function is called when the "Check Game States" button is clicked in the property editor for a PropertyDefGameStatefSet object. It retrieves the game states associated with the object's property and displays them in a message dialog.
---
--- @param _, obj     The object containing the PropertyDefGameStatefSet property.
--- @param prop_id    The ID of the PropertyDefGameStatefSet property.
--- @param ged        The property editor dialog.
---
function PropertyDefGameStatefSetCheck(_, obj, prop_id, ged)
	ged:ShowMessage("Test Result", GetMismatchGameStates(obj[prop_id]))
end

DefineClass.PropertyDefColor = {
	__parents = { "PropertyDef" },
	properties = {
		{ category = "Color", id = "default", name = "Default value", editor = "color", default = RGB(0, 0, 0), },
	},
	editor = "color",
	EditorName = "Color property",
	EditorSubmenu = "Basic property",
}

DefineClass.PropertyDefImage = {
	__parents = { "PropertyDef" },
	properties = {
		{ category = "Image", id = "default",        name = "Default value", editor = "image", default = false, },
		{ category = "Image", id = "img_size",       name = "Image box", editor = "number", default = 200, },
		{ category = "Image", id = "img_box",        name = "Image border", editor = "number", default = 1, },
		{ category = "Image", id = "base_color_map", name = "Base color", editor = "bool", default = false, },
	},
	editor = "image",
	EditorName = "Image preview property",
	EditorSubmenu = "Extras",
}

---
--- Generates additional property code for a PropertyDefImage object.
---
--- This function is responsible for generating the additional property code for a PropertyDefImage object, which is a subclass of PropertyDef. It sets the `img_size` property to the value of `self.img_size`, the `img_box` property to the value of `self.img_box`, and the `base_color_map` property to the boolean value of `self.base_color_map`.
---
--- @param code       A code object to which the additional property code will be appended.
--- @param translate  A boolean indicating whether the property should be translated.
---
function PropertyDefImage:GenerateAdditionalPropCode(code, translate)
	code:appendf("img_size = %d, img_box = %d, base_color_map = %s, ", self.img_size, self.img_box, tostring(self.base_color_map)) 
end

DefineClass.PropertyDefGrid = {
	__parents = { "PropertyDef" },
	properties = {
		{ category = "Grid", id = "default", name = "Default value", editor = "grid", default = false, },
		{ category = "Grid", id = "frame",   name = "Frame", editor = "number", default = 0, },
		{ category = "Grid", id = "color",   name = "Color", editor = "bool", default = false },
		{ category = "Grid", id = "min",     name = "Min Size", editor = "number", default = 0, },
		{ category = "Grid", id = "max",     name = "Max Size", editor = "number", default = 0 },
	},
	editor = "grid",
	EditorName = "Grid property",
	EditorSubmenu = "Extras",
}

---
--- Generates additional property code for a PropertyDefGrid object.
---
--- This function is responsible for generating the additional property code for a PropertyDefGrid object, which is a subclass of PropertyDef. It sets the `frame` property to the value of `self.frame`, the `min` property to the value of `self.min`, the `max` property to the value of `self.max`, and the `color` property to the boolean value of `self.color`.
---
--- @param code       A code object to which the additional property code will be appended.
--- @param translate  A boolean indicating whether the property should be translated.
---
function PropertyDefGrid:GenerateAdditionalPropCode(code, translate)
	if self.frame > 0 then code:appendf("frame = %d, ", self.frame) end
	if self.min > 0 then code:appendf("min = %d, ", self.min) end
	if self.max > 0 then code:appendf("max = %d, ", self.max) end
	if self.color then code:append("color = true, ") end
end

DefineClass.PropertyDefMaterial = {
	__parents = { "PropertyDef" },
	properties = {
		{ category = "Color", id = "default", name = "Default value", editor = "rgbrm", default = RGBRM(200, 200, 200, 0, 0) },
	},
	editor = "rgbrm",
	EditorName = "Material property",
	EditorSubmenu = "Extras",
}

DefineClass.PropertyDefBrowse = {
	__parents = { "PropertyDef" },
	properties = {
		{ category = "Browse", id = "default", name = "Default value", editor = "browse", default = false, },
		{ category = "Browse", id = "folder", name = "Folder", editor = "text", default = "UI", },
		{ category = "Browse", id = "filter", name = "Filter", editor = "text", default = "Image files|*.tga", },
		{ category = "Browse", id = "extension", name = "Force extension", editor = "text", default = false,
			buttons = { { name = "No extension", func = function(self) self.extension = "" ObjModified(self) end, } },
		},
		{ category = "Browse", id = "image_preview_size", name = "Image preview size", editor = "number", default = 0, },
	},
	editor = "browse",
	EditorName = "Browse property",
	EditorSubmenu = "Basic property",
}

---
--- Generates additional property code for a PropertyDefBrowse object.
---
--- This function is responsible for generating the additional property code for a PropertyDefBrowse object, which is a subclass of PropertyDef. It sets the `folder` property to the value of `self.folder`, the `filter` property to the value of `self.filter`, the `force_extension` property to the value of `self.extension`, and the `image_preview_size` property to the value of `self.image_preview_size`.
---
--- @param code       A code object to which the additional property code will be appended.
--- @param translate  A boolean indicating whether the property should be translated.
---
function PropertyDefBrowse:GenerateAdditionalPropCode(code, translate)
	local folder, filter = self.folder or "", self.filter or ""
	if folder ~= "" then
		-- detect if we have a table or a single string for self.folder
		if folder:match("^%s*[{\"]") then
			code:appendf("folder = %s, ", self.folder)
		else
			code:appendf("folder = \"%s\", ", self.folder)
		end
	end
	if self.filter    ~= "" then code:appendf("filter = \"%s\", ", self.filter) end
	if self.extension ~= PropertyDefBrowse.extension then code:appendf("force_extension = \"%s\", ", self.extension) end
	if self.image_preview_size > 0 then code:appendf("image_preview_size = %i, ", self.image_preview_size) end
end


DefineClass.PropertyDefUIImage = {
	__parents = { "PropertyDef" },
	properties = {
		{ category = "Browse", id = "default", name = "Default value", editor = "ui_image", default = false, },
		{ category = "Browse", id = "filter", name = "Filter", editor = "text", default = "All files|*.*", },
		{ category = "Browse", id = "extension", name = "Force extension", editor = "text", default = false,
			buttons = { { name = "No extension", func = function(self) self.extension = "" ObjModified(self) end, } },
		},
		{ category = "Browse", id = "image_preview_size", name = "Image preview size", editor = "number", default = 0, },
	},
	editor = "ui_image",
	EditorName = "UI image property",
	EditorSubmenu = "Basic property",
}

---
--- Generates additional property code for a PropertyDefUIImage object.
---
--- This function is responsible for generating the additional property code for a PropertyDefUIImage object, which is a subclass of PropertyDef. It sets the `filter` property to the value of `self.filter`, the `force_extension` property to the value of `self.extension`, and the `image_preview_size` property to the value of `self.image_preview_size`.
---
--- @param code       A code object to which the additional property code will be appended.
--- @param translate  A boolean indicating whether the property should be translated.
---
function PropertyDefUIImage:GenerateAdditionalPropCode(code, translate)
	if self.filter    ~= PropertyDefUIImage.filter    then code:appendf("filter = \"%s\", ", self.filter) end
	if self.extension ~= PropertyDefUIImage.extension then code:appendf("force_extension = \"%s\", ", self.extension) end
	if self.image_preview_size > 0 then code:appendf("image_preview_size = %i, ", self.image_preview_size) end
end

DefineClass.PropertyDefFunc = {
	__parents = { "PropertyDef" },
	properties = {
		{ category = "Func", id = "params", name = "Params", editor = "text", default = "self", },
		{ category = "Func", id = "default", name = "Default value", editor = "func", default = empty_func, lines = 1, max_lines = 20, params = function (self) return self.params end, },
	},
	editor = "func",
	EditorName = "Func property",
	EditorSubmenu = "Code",
}

---
--- Converts the value of a PropertyDefFunc object to a string with color formatting.
---
--- If the value is the `empty_func` function, this method returns a formatted string
--- that represents the function with the specified parameters. Otherwise, it simply
--- returns the value as a string.
---
--- @param value The value to be converted to a string.
--- @return The formatted string representation of the value.
---
function PropertyDefFunc:ToStringWithColor(value)
	if value == empty_func then
		return PropertyDef.ToStringWithColor(self, string.format("function (%s) end", self.params), "function")
	end
	return PropertyDef.ToStringWithColor(self, value)
end


---
--- Generates the default value code for a PropertyDefFunc object.
---
--- If the `default` property is not set, this method returns the string `"false"`. Otherwise, it generates the source code for the default value function using the `GetFuncSourceString` function, passing the `default` property, an empty string, and the `params` property (or `"self"` if `params` is not set).
---
--- @param self The PropertyDefFunc object.
--- @return The source code for the default value function.
---
function PropertyDefFunc:GenerateDefaultValueCode()
	if not self.default then return "false" end
	return GetFuncSourceString(self.default, "", self.params or "self")
end

---
--- Generates additional property code for a PropertyDefFunc object.
---
--- If the `params` property is set and is not equal to `"self"`, this method appends the `params` property to the `code` object using the `appendf` method, with the format `"params = "%s", "`.
---
--- @param self The PropertyDefFunc object.
--- @param code The code object to append the additional property code to.
--- @param translate A boolean indicating whether the property should be translated.
---
function PropertyDefFunc:GenerateAdditionalPropCode(code, translate)
	if self.params and self.params ~= "self" then
		code:appendf("params = \"%s\", ", self.params)
	end
end

DefineClass.PropertyDefExpression = {
	__parents = { "PropertyDef" },
	properties = {
		{ category = "Expression", id = "params", name = "Params", editor = "text", default = "self", },
		{ category = "Expression", id = "default", name = "Default value", editor = "expression", default = false, params = function(self) return self.params end, },
	},
	editor = "expression",
	EditorName = "Expression property",
	EditorSubmenu = "Code",
}

---
--- Generates the default value code for a PropertyDefExpression object.
---
--- If the `default` property is not set, this method returns the string `"false"`. Otherwise, it generates the source code for the default value function using the `GetFuncSourceString` function, passing the `default` property, an empty string, and the `params` property (or `"self"` if `params` is not set).
---
--- @param self The PropertyDefExpression object.
--- @return The source code for the default value function.
---
function PropertyDefExpression:GenerateDefaultValueCode()
	if not self.default then return "false" end
	return GetFuncSourceString(self.default, "", self.params or "self")
end

---
--- Generates additional property code for a PropertyDefExpression object.
---
--- If the `params` property is set and is not equal to `"self"`, this method appends the `params` property to the `code` object using the `appendf` method, with the format `"params = "%s", "`.
---
--- @param self The PropertyDefExpression object.
--- @param code The code object to append the additional property code to.
--- @param translate A boolean indicating whether the property should be translated.
---
function PropertyDefExpression:GenerateAdditionalPropCode(code, translate)
	if self.params and self.params ~= "self" then
		code:appendf("params = \"%s\", ", self.params)
	end
end

DefineClass.PropertyDefShortcut = {
	__parents = { "PropertyDef" },
	properties = {
		{ category = "Expression", id = "shortcut_type", name = "Shortcut type", editor = "choice", default = "keyboard&mouse", items = {
			"keyboard&mouse",
			"keyboard",
			"gamepad"
		}, },
		{ category = "Expression", id = "default", name = "Default value", editor = "text", default = "", no_edit = true, },
	},
	editor = "shortcut",
	EditorName = "Shortcut property",
	EditorSubmenu = "Extras",
}

---
--- Generates additional property code for a PropertyDefShortcut object.
---
--- This method appends the `shortcut_type` property to the `code` object using the `appendf` method, with the format `"shortcut_type = "%s", "`.
---
--- @param self The PropertyDefShortcut object.
--- @param code The code object to append the additional property code to.
--- @param translate A boolean indicating whether the property should be translated.
---
function PropertyDefShortcut:GenerateAdditionalPropCode(code, translate)
	code:appendf("shortcut_type = \"%s\", ", self.shortcut_type) 
end

----- Presets - preset_id & preset_id_list

---
--- Checks if a class definition has a constant "Group" property.
---
--- @param classdef The class definition to check.
--- @return boolean true if the class definition has a constant "Group" property, false otherwise.
---
function IsPresetWithConstantGroup(classdef)
	if not classdef then return end
	local prop = classdef:GetPropertyMetadata("Group")
	return not prop or prop_eval(prop.no_edit, classdef, prop, true) or prop_eval(prop.read_only, classdef, prop, true)	
end

DefineClass.PropertyDefPresetIdBase = {
	__parents = { "PropertyDef" },
	properties = {
		{ category = "PresetId", id = "preset_class", name = "Preset class", editor = "choice", default = "",
			items = ClassDescendantsCombo("Preset", false, function(name, class)
				return not IsKindOfClasses(class, "ClassDef", "ClassDefSubItem")
			end),
		},
		{ category = "PresetId", id = "preset_group", name = "Preset group", editor = "choice", default = "",
			help = "Restricts the choice to the specified group of the preset class.",
			items = function(obj)
				local class = g_Classes[obj.preset_class]
				local preset_class = class.PresetClass or obj.preset_class
				return class and PresetGroupsCombo(preset_class) or empty_table
			end,
			no_edit = function(obj) -- disable group restriction for classes with uneditable "Group" property
				local class = g_Classes[obj.preset_class]
				return not class or IsPresetWithConstantGroup(class)
			end, },
		{ category = "PresetId", id = "preset_filter", name = "PresetFilter", editor = "func", params = "preset, obj, prop_meta", lines = 1, max_lines = 20, default = false },
		{ category = "PresetId", id = "extra_item", name = "Extra item", editor = "text", default = false },
		{ category = "PresetId", id = "default", name = "Default value", editor = "choice",
			items = function(obj)
				local class = g_Classes[obj.preset_class]
				if class and (class.GlobalMap or IsPresetWithConstantGroup(class) or obj.preset_group ~= "") then
					return PresetsCombo(obj.preset_class, obj.preset_group ~= "" and obj.preset_group, {"", obj.extra_item or nil})
				end
				return { false }
			end, default = false },
	},
	editor = "preset_id",
	EditorName = "PresetId property",
	EditorSubmenu = "Basic property",
}

---
--- Generates additional property code for a PresetId property.
---
--- @param code The code object to append the generated code to.
--- @param translate A function to translate strings.
---
function PropertyDefPresetIdBase:GenerateAdditionalPropCode(code, translate)
	if self.preset_class ~= "" then code:appendf("preset_class = \"%s\", ", self.preset_class) end
	if self.preset_group ~= "" then code:appendf("preset_group = \"%s\", ", self.preset_group) end
	if self.extra_item         then code:appendf("extra_item = \"%s\", ",   self.extra_item)   end
	self:AppendFunctionCode(code, "preset_filter")
end

---
--- Handles changes to the `preset_class` and `preset_group` properties of a `PropertyDefPresetIdBase` object.
---
--- When the `preset_class` property is changed, the `preset_group` and `default` properties are reset to `nil`.
--- When the `preset_group` property is changed, the `default` property is reset to `nil`.
---
--- This function is called when the editor sets a property on the `PropertyDefPresetIdBase` object.
---
--- @param prop_id (string) The ID of the property that was changed.
--- @param old_value (any) The previous value of the property.
--- @param ... (any) Additional arguments passed to the function.
---
function PropertyDefPresetIdBase:OnEditorSetProperty(prop_id, old_value, ...)
	if prop_id == "preset_class" then
		self.preset_group = nil
		self.default = nil
	elseif prop_id == "preset_group" then
		self.default = nil
	end
	ObjModified(self)
end

---
--- Generates an error message if the `preset_class` property is not configured correctly.
---
--- If the `preset_class` does not have a `GlobalMap` or is not part of a `ConstantGroup`, and the `preset_group` is not set, this function will return an error message explaining the issue and suggesting a solution.
---
--- @return string|nil The error message, or `nil` if there is no error.
---
function PropertyDefPresetIdBase:GetError()
	local class = g_Classes[self.preset_class]
	if class and not (class.GlobalMap or IsPresetWithConstantGroup(class) or self.preset_group ~= "") then
		return string.format("%s doesn't have GlobalMap - all presets can't be listed. Please specify a Preset group.\n\nIf you want all presets to be selectable, either add GlobalMap, or create two properties - one for selecting a preset group and another for selecting a preset from that group.", self.preset_class)
	end
end

DefineClass.PropertyDefPresetId = {
	__parents = { "PropertyDefPresetIdBase" },
}

DefineClass.PropertyDefPresetIdList = {
	__parents = { "PropertyDefPresetIdBase", "WeightedListProps" },
	properties = {
		{ category = "PresetId", id = "default", name = "Default value", editor = "preset_id_list",
			preset_class = function(obj) return obj.preset_class end,
			preset_group = function(obj) return obj.preset_group end,
			extra_item = function(obj) return obj.extra_item end,
			default = {}, },
	},
	editor = "preset_id_list",
	EditorName = "PresetId list property",
	EditorSubmenu = "Lists",
}

---
--- Generates additional property code for the `PropertyDefPresetIdList` class.
---
--- This function is called to generate the additional code for the `PropertyDefPresetIdList` class, which is a subclass of `PropertyDefPresetIdBase`.
---
--- @param code CodeBuffer The code buffer to append the generated code to.
--- @param translate function The translation function to use for localized strings.
---
function PropertyDefPresetIdList:GenerateAdditionalPropCode(code, translate)
	PropertyDefPresetIdBase.GenerateAdditionalPropCode(self, code, translate)
	code:append("item_default = \"\"")
	self:GenerateWeightPropCode(code)
	code:append(", ")
end


----- Nested object & nested list

local function BaseClassCombo(obj, prop_meta, validate_fn)
	if validate_fn == "validate_fn" then
		-- function for preset validation, checks whether the property value is from "items"
		return "validate_fn", function(value, obj, prop_meta)
			local class = g_Classes[value]
			return value == "" or IsKindOf(class, "PropertyObject") and not IsKindOf(class, "CObject")
		end
	end
	return ClassDescendantsList("PropertyObject", function(name, def)
		return not def.__ancestors.CObject and name ~= "CObject"
	end, "")
end

DefineClass.PropertyDefObject = {
	__parents = { "PropertyDef" },
	default = false,
	editor = "object",
	properties = {
		{ category = "Property", id = "base_class", name = "Base class", editor = "choice", items = function() return ClassDescendantsListInclusive("Object") end, default = "Object" },
		{ category = "Property", id = "format_func", name = "Format", editor = "func", default = GetObjectPropEditorFormatFuncDefault, lines = 1, max_lines = 10, params = "gameobj"},
	},	
	EditorName = "Object property",
	EditorSubmenu = "Objects",
}

---
--- Generates additional property code for the `PropertyDefObject` class.
---
--- This function is called to generate the additional code for the `PropertyDefObject` class, which is a subclass of `PropertyDef`.
---
--- @param code CodeBuffer The code buffer to append the generated code to.
--- @param translate function The translation function to use for localized strings.
---
function PropertyDefObject:GenerateAdditionalPropCode(code, translate)
	code:appendf("base_class = \"%s\", ", self.base_class)
	self:AppendFunctionCode(code, "format_func")
end

DefineClass.PropertyDefNestedObj = {
	__parents = { "PropertyDef" },
	properties = {
		{ category = "Nested Object", id = "base_class", name = "Base class", editor = "choice", items = BaseClassCombo, default = "PropertyObject" },
		{ category = "Nested Object", id = "inclusive", name = "Allow base class", editor = "bool", default = false, },
		{ category = "Nested Object", id = "no_descendants", name = "No descendants", editor = "bool", default = false, },
		{ category = "Nested Object", id = "all_descendants", name = "Allow all descendants", editor = "bool", default = false, no_edit = function (self) return self.no_descendants end, },
		{ category = "Nested Object", id = "class_filter", name = "ClassFilter", editor = "func", default = false, lines = 1, max_lines = 20, params = "name, class, obj"},
		{ category = "Nested Object", id = "format", name = "Format in Ged", editor = "text", default = "<EditorView>", },
		{ category = "Nested Object", id = "auto_expand", name = "Auto Expand", editor = "bool", default = false, },
		{ category = "Nested Object", id = "default", name = "Default value", editor = "bool", default = false, no_edit = true, },
	},
	editor = "nested_obj",
	EditorName = "Nested object property",
	EditorSubmenu = "Objects",
}

---
--- Generates additional property code for the `PropertyDefNestedObj` class.
---
--- This function is called to generate the additional code for the `PropertyDefNestedObj` class, which is a subclass of `PropertyDef`. It appends the necessary property code to the provided `code` buffer, including the `base_class`, `inclusive`, `no_descendants`, `all_descendants`, `auto_expand`, `format`, and `class_filter` properties.
---
--- @param code CodeBuffer The code buffer to append the generated code to.
--- @param translate function The translation function to use for localized strings.
---
function PropertyDefNestedObj:GenerateAdditionalPropCode(code, translate)
	code:appendf("base_class = \"%s\", ", self.base_class)
	if self.inclusive then code:append("inclusive = true, ") end
	if self.no_descendants then code:append("no_descendants = true, ")
	elseif self.all_descendants then code:append("all_descendants = true, ") end
	if self.auto_expand then code:appendf("auto_expand = true, ") end
	if self.format ~= PropertyDefNestedObj.format then code:appendf("format = \"%s\"", self.format) end
	self:AppendFunctionCode(code, "class_filter")
end

---
--- Returns an error message if the `base_class` property is set to `"PropertyObject"`.
---
--- This function is called to check if the `base_class` property of the `PropertyDefNestedObj` class is set to `"PropertyObject"`. If so, it returns an error message indicating that the base class should be specified.
---
--- @return string|nil An error message if the `base_class` is `"PropertyObject"`, otherwise `nil`.
---
function PropertyDefNestedObj:GetError()
	if self.base_class == "PropertyObject" then
		return "Please specify base class for the nested object(s)."
	end
end

DefineClass.PropertyDefNestedList = {
	__parents = { "PropertyDef" },
	properties = {
		{ category = "Nested List", id = "base_class", name = "Base class", editor = "choice", items = BaseClassCombo, default = "PropertyObject" },
		{ category = "Nested List", id = "inclusive", name = "Allow base class", editor = "bool", default = false, },
		{ category = "Nested List", id = "no_descendants", name = "No descendants", editor = "bool", default = false, },
		{ category = "Nested List", id = "all_descendants", name = "Allow all descendants", editor = "bool", default = false, no_edit = function (self) return self.no_descendants end, },
		{ category = "Nested List", id = "class_filter", name = "ClassFilter", editor = "func", default = false, lines = 1, max_lines = 20, params = "name, class, obj"},
		{ category = "Nested List", id = "format", name = "Format in Ged", editor = "text", default = "<EditorView>", },
		{ category = "Nested List", id = "auto_expand", name = "Auto Expand", editor = "bool", default = false, },
		{ category = "Nested List", id = "default", name = "Default value", editor = "bool", default = false, no_edit = true, },
	},
	editor = "nested_list",
	EditorName = "Nested list property",
	EditorSubmenu = "Lists",
}

PropertyDefNestedList.GenerateAdditionalPropCode = PropertyDefNestedObj.GenerateAdditionalPropCode
PropertyDefNestedList.GetError = PropertyDefNestedObj.GetError

DefineClass.PropertyDefPropertyArray = {
	__parents = { "PropertyDef" },
	properties = {
		{ category = "Dynamic Props", id = "from", name = "Generate id from", editor = "choice", default = false,
			items = { "Table keys", "Table values", "Table field values", "Preset ids" },
		},
		{ category = "Dynamic Props", id = "field", name = "Table field", editor = "text", translate = false, default = "",
			no_edit = function(self) return self.from ~= "Table field values" end,
		},
		{ category = "Dynamic Props", id = "items", name = "Items", editor = "expression", default = false, 
			no_edit = function(self) return self.from == "Preset ids" end,
		},
		{ category = "Dynamic Props", id = "preset", name = "Preset class", editor = "choice", default = "",
			items = ClassDescendantsCombo("Preset"),
			no_edit = function(self) return self.from ~= "Preset ids" end,
		},
		{ category = "Dynamic Props", id = "prop_meta_update", name = "Update prop_meta", editor = "func", params = "self, prop_meta", default = false, 
			help = "Update the prop_meta of each generated property from prop_meta.id, prop_meta.index (consecutive number), and prop_meta.prest/value.",
		},
		{ category = "Dynamic Props", id = "prop", name = "Property template", editor = "nested_obj", base_class = "PropertyDef", auto_expand = true, default = false,
			suppress_props = { id = true, name = true, category = true, dont_save = true, no_edit = true, template = true, },
		},
	},
	editor = "property_array",
	EditorName = "Property array",
	EditorSubmenu = "Objects",
	default = false,
}

---
--- Generates additional property code for a PropertyDefPropertyArray object.
---
--- @param code CodeBuffer The code buffer to append the generated code to.
--- @param translate boolean Whether to translate the generated code.
---
function PropertyDefPropertyArray:GenerateAdditionalPropCode(code, translate)
	local from_preset = self.from == "Preset ids" and self.preset ~= "" and self.preset
	if self.prop and (from_preset or not from_preset and self.items ~= false) then
		if from_preset then
			code:appendf("from = '%s', ", self.preset)
		else
			code:append("items = ")
			ValueToLuaCode(self.items, nil, code)
			code:appendf(", from = '%s', ", self.from)
			if self.from == "Table field values" then
				code:appendf("field = '%s', ", self.field)
			end
			if self.prop_meta_update then
				code:appendf("prop_meta_update = ")
				ValueToLuaCode(self.prop_meta_update, nil, code)
				code:appendf(", ")
			end
		end
		code:append("\nprop_meta =\n")
		self.prop.id = " "
		self.prop:GenerateCode(code, translate)
	end
end

DefineClass.PropertyDefScript = {
	__parents = { "PropertyDef" },
	properties = {
		{ category = "Script", id = "condition", name = "Is condition list", editor = "bool", default = false, },
		{ category = "Script", id = "params_exp", name = "Params is an expression", editor = "bool", default = false, },
		{ category = "Script", id = "params", name = "Params", editor = "text", default = "self", },
		{ category = "Script", id = "script_domain", name = "Script domain", editor = "choice", default = false, items = function() return ScriptDomainsCombo() end },
	},
	default = false,
	editor = "script",
	EditorName = "Script",
	EditorSubmenu = "Code",
}

---
--- Generates additional property code for a PropertyDefScript object.
---
--- @param code CodeBuffer The code buffer to append the generated code to.
--- @param translate boolean Whether to translate the generated code.
---
function PropertyDefScript:GenerateAdditionalPropCode(code, translate)
	if self.condition then
		code:append('class = "ScriptConditionList", ')
	end
	if self.params_exp then
		code:appendf('params = function(self) return %s end, ', self.params)
	else
		code:appendf('params = "%s", ', self.params)
	end
	if self.script_domain then
		code:appendf('script_domain = "%s", ', self.script_domain)
	end
end


----- Primitive lists

DefineClass.WeightedListProps = {
	__parents = { "PropertyObject" },
	properties = {
		{ category = "Weights", id = "weights", name = "Weights", editor = "bool", default = false, 
			no_edit = function(obj) return obj:DisableWeights() end, help = "Associates weights to the list items"},
		{ category = "Weights", id = "weight_default", name = "Default Weight", editor = "number", default = 100, 
			no_edit = function(obj) return not obj.weights end, help = "Default weight for each list item" },
		{ category = "Weights", id = "value_key", name = "Value Key", editor = "text", default = "value", 
			no_edit = function(obj) return not obj.weights end, help = "Name of the 'value' key in each list item. Can be a number too." },
		{ category = "Weights", id = "weight_key", name = "Weight Key", editor = "text", default = "weight", 
			no_edit = function(obj) return not obj.weights end, help = "Name of the 'weight' key in each list item. Can be a number too." },
	},
	DisableWeights = empty_func,
}

---
--- Gets the value and weight keys for a weighted list.
---
--- If the `value_key` or `weight_key` properties are empty strings, they are set to "value" and "weight" respectively.
--- If the `value_key` or `weight_key` properties are numbers, they are converted to strings.
---
--- @return string value_key The key for the list item value.
--- @return string weight_key The key for the list item weight.
---
function WeightedListProps:GetItemKeys()
	local value_key = self.value_key
	if value_key == "" then
		value_key = "value"
	end
	value_key = tonumber(value_key) or value_key
	
	local weight_key = self.weight_key
	if weight_key == "" then
		weight_key = "weight"
	end
	weight_key = tonumber(weight_key) or weight_key
	
	return value_key, weight_key
end

---
--- Generates the weight property code for a weighted list.
---
--- If the `weights` property is false, this function does nothing.
--- Otherwise, it appends the following properties to the provided `code` object:
--- - `weights = true`: Indicates that the list has weights.
--- - `value_key = <value>`: The key used to access the value of each list item.
--- - `weight_key = <weight>`: The key used to access the weight of each list item.
--- - `weight_default = <default>`: The default weight to use for list items that don't have a weight specified.
---
--- @param code CodeBuffer The code buffer to append the weight property code to.
---
function WeightedListProps:GenerateWeightPropCode(code)
	if not self.weights then
		return
	end
	code:append(", weights = true")
	local value_key, weight_key = self:GetItemKeys()
	if value_key ~= "value" then
		code:append(", value_key = ")
		ValueToLuaCode(value_key, nil, code)
	end
	if weight_key ~= "weight" then
		code:append(", weight_key = ")
		ValueToLuaCode(weight_key, nil, code)
	end
	if self.weight_default ~= 100 then
		code:append(", weight_default = ")
		ValueToLuaCode(self.weight_default, nil, code)
	end
end
	
DefineClass.PropertyDefPrimitiveList = {
	__parents = { "PropertyDef", "WeightedListProps" },
	properties = {
		{ category = "List", id = "item_default", name = "Item Default", editor = "text", default = false, },
		{ category = "List", id = "items", name = "Items", editor = "expression", default = false, },
		{ category = "List", id = "max_items", name = "Max number of items", editor = "number", default = -1, },
	},
	editor = "",
	EditorName = "",
}

---
--- Determines whether weights should be disabled for this property definition.
---
--- Weights are disabled if the editor is not "number_list" or "string_list".
---
--- @return boolean Whether weights should be disabled
---
function PropertyDefPrimitiveList:DisableWeights()
	return self.editor ~= "number_list" and self.editor ~= "string_list"
end

---
--- Generates additional property code for a primitive list property definition.
---
--- This function appends the following properties to the provided `code` object:
--- - `item_default = <item_default>`: The default value for each item in the list.
--- - `items = <items>`: The list of items for the property.
--- - `arbitrary_value = true`: Indicates that arbitrary values are allowed for the list items.
--- - `max_items = <max_items>`: The maximum number of items allowed in the list.
--- - Weight properties generated by `GenerateWeightPropCode()`.
---
--- @param code CodeBuffer The code buffer to append the additional property code to.
--- @param translate boolean Whether to translate the property values.
---
function PropertyDefPrimitiveList:GenerateAdditionalPropCode(code, translate)
	code:append("item_default = ")
	ValueToLuaCode(self.item_default, nil, code)
	code:append(", items = ")
	ValueToLuaCode(self.items, nil, code)
	if self.arbitrary_value then
		code:append(", arbitrary_value = true")
	end
	if self.max_items >= 0 then
		code:append(", max_items = ")
		ValueToLuaCode(self.max_items, nil, code)
	end
	self:GenerateWeightPropCode(code)
	code:append(", ")
end

DefineClass.PropertyDefNumberList = {
	__parents = { "PropertyDefPrimitiveList" },
	
	properties = {
		{ category = "List", id = "default", name = "Default value", editor = "number_list",
				default = {}, item_default = function(self) return self.item_default end, items = EmulatePropEval("items", {0}) },
		{ category = "List", id = "item_default", name = "Item Default", editor = "number", default = 0, },
	},
	
	editor = "number_list",
	EditorName = "Number list property",
	EditorSubmenu = "Lists",
}

DefineClass.PropertyDefStringList = {
	__parents = { "PropertyDefPrimitiveList" },
	
	properties = {
		{ category = "List", id = "default", name = "Default value", editor = "string_list",
				default = {}, items = EmulatePropEval("items", {""}),
				item_default = function(self) return self.item_default end, 
				arbitrary_value = function(self) return self.arbitrary_value end, },
		{ category = "List", id = "item_default", name = "Item default", editor = "combo",
				default = "", items = EmulatePropEval("items", {""}) },
		{ category = "List", id = "arbitrary_value", name = "Allow arbitrary value", editor = "bool", default = false, },
	},
	
	editor = "string_list",
	EditorName = "String list property",
	EditorSubmenu = "Lists",
}

DefineClass.PropertyDefTList = {
	__parents = { "PropertyDefPrimitiveList" },
	
	properties = {
		{ category = "List", id = "default", name = "Default value", editor = "T_list",
					default = {}, item_default = function(self) return self.item_default end, items = EmulatePropEval("items", {""}) },
		{ category = "List", id = "item_default", name = "Item default", editor = "text", default = "", translate = true},
		{ category = "Text", id = "context", name = "Context", editor = "text", default = "", }
	},
	
	editor = "T_list",
	EditorName = "Translated list property",
	EditorSubmenu = "Lists",
}

--- Generates additional property code for a translated list property.
---
--- This function is called when generating the property code for a `PropertyDefTList` object.
--- It calls the `GenerateAdditionalPropCode` function of the parent `PropertyDefPrimitiveList` class,
--- and then appends the `context` property to the generated code if it is not empty.
---
--- @param code table The code table to append the generated code to.
--- @param translate boolean Whether the property is a translated property.
function PropertyDefTList:GenerateAdditionalPropCode(code, translate)
	PropertyDefPrimitiveList.GenerateAdditionalPropCode(self, code, translate)
	if self.context and self.context ~= "" then
		code:append("context = " .. self.context .. ", ")
	end
end

DefineClass.PropertyDefHelp = {
	__parents = { "PropertyDef" },
	default = false,
	editor = "help",
	EditorName = "Help text",
	EditorSubmenu = "Extras",
}


----- ClassConstDef

local const_items = {
	{ text = "Bool", value = "bool" },
	{ text = "Number", value = "number" },
	{ text = "Text", value = "text" },
	{ text = "Translated Text", value = "translate" },
	{ text = "Point", value = "point" },
	{ text = "Box", value = "rect" },
	{ text = "Color", value = "color" },
	{ text = "Range", value = "range" },
	{ text = "Image", value = "browse" },
	{ text = "Table", value = "prop_table" },
	{ text = "String List", value = "string_list" },
	{ text = "Number List", value = "number_list" },
}

DefineClass.ClassConstDef = {
	__parents = { "ClassDefSubItem" },
	properties = {
		{ category = "Const", id = "name", name = "Name", editor = "text", default = "", validate = ValidateIdentifier },
		{ category = "Const", id = "type", name = "Type", editor = "choice", default = "bool", items = const_items, },
		{ category = "Const", id = "value", name = "Value", editor = function(self) return self.type == "translate" and "text" or self.type end,
			translate = function(self) return self.type == "translate" end, default = false,
			lines = function(self) return self.type == "prop_table" and 3 or self.type == "text" and 1 end,
			max_lines = function(self) return self.type == "text" and 256 end, },
		{ category = "Const", id = "untranslated", name = "Untranslated", editor = "bool",
			no_edit = function(self) return self.type ~= "translate" and self.type ~= "text" end, default = false, }
	},
	EditorName = "Class member",
	EditorSubmenu = "Code",
}

--- Handles the behavior when the `type` property of a `ClassConstDef` is changed.
---
--- When the `type` property changes from `"text"` to `"translate"`, the `value` property is updated to be a localized property.
--- When the `type` property changes from `"translate"` to `"text"`, the `value` property is updated to be a non-localized property.
--- If the `type` property changes to anything else, the `value` property is set to `nil`.
---
--- @param prop_id string The ID of the property that was changed.
--- @param old_value any The previous value of the property.
--- @param ged table The GED (GUI Editor Definition) object associated with the `ClassConstDef`.
function ClassConstDef:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "type" then
		local value = self.type
		if value == "text" and old_value == "translate" then
			self:UpdateLocalizedProperty("value", false)
		elseif value == "translate" and old_value == "text" then
			self:UpdateLocalizedProperty("value", true)
		else
			self.value = nil
		end
	end
end

--- Returns the value of the `ClassConstDef` object.
---
--- If the `type` property is "text" or "translate" and the `value` property is `nil`, an empty string is returned.
--- Otherwise, the `value` property is returned.
---
--- @return any The value of the `ClassConstDef` object.
function ClassConstDef:GetValue()
	if not self.value and (self.type == "text" or self.type == "translate") then
		return ""
	end
	return self.value
end

--- Returns the editor view for a `ClassConstDef` object.
---
--- The editor view is a string that represents how the `ClassConstDef` object should be displayed in the editor.
--- If the `type` property is "translate", the editor view will include the name of the property and its value, which may be an untranslated string.
--- If the `type` property is not "translate", the editor view will include the name of the property and its value.
---
--- @return string The editor view for the `ClassConstDef` object.
function ClassConstDef:GetEditorView()
	local result = "<color 45 138 138>Class.</color>"
	if self.type == "translate" then
		result = result .. string.format(self.untranslated and '%s = Untranslated(%s)' or '%s = T(%s)', self.name, self:ToStringWithColor(TDevModeGetEnglishText(self:GetValue())))
	else
		result = result .. string.format("%s = %s", self.name, self:ToStringWithColor(self:GetValue()))
	end
	return result
end

--- Generates the Lua code for a `ClassConstDef` object.
---
--- If the `name` property of the `ClassConstDef` object does not match the pattern `^[%w_]+$`, this function returns without generating any code.
---
--- If the `untranslated` property is true, the generated code will use the `Untranslated()` function to wrap the value of the `ClassConstDef` object. The type of the value is determined by the `type` property:
--- - If `type` is "text", the value is passed directly to `ValueToLuaCode()`.
--- - If `type` is "translate", the value is passed to `TDevModeGetEnglishText()` before being passed to `ValueToLuaCode()`.
---
--- If the `untranslated` property is false, the value of the `ClassConstDef` object is passed directly to `ValueToLuaCode()`.
---
--- @param code CodeGenerator The `CodeGenerator` object to append the generated code to.
function ClassConstDef:GenerateCode(code)
	if not self.name:match("^[%w_]+$") then return end
	if self.untranslated then
		code:append("\t", self.name, " = Untranslated(" )
		if self.type == "text" then
			ValueToLuaCode(self:GetValue(), nil, code)
		elseif self.type == "translate" then
			ValueToLuaCode(TDevModeGetEnglishText(self:GetValue()), nil, code)
		end
		code:append("),\n")
		return
	end
	code:append("\t", self.name, " = ") 
	ValueToLuaCode(self:GetValue(), nil, code)
	code:append(",\n")
end


----- ClassMethodDef

local default_methods = {
	"",
	"GetEditorView()",
	"GetError()",
	"GetWarning()",
	"OnEditorSetProperty(prop_id, old_value, ged)",
	"OnEditorNew(parent, ged, is_paste)",
	"OnEditorDelete(parent, ged)",
	"OnEditorSelect(selected, ged)",
}

---
--- Generates a combo box of known methods for a `ClassMethodDef` object.
---
--- The combo box includes a list of default methods, as well as any methods defined in the parent classes of the `ClassDef` object associated with the `ClassMethodDef`.
---
--- The default methods are:
--- - ""
--- - "GetEditorView()"
--- - "GetError()"
--- - "GetWarning()"
--- - "OnEditorSetProperty(prop_id, old_value, ged)"
--- - "OnEditorNew(parent, ged, is_paste)"
--- - "OnEditorDelete(parent, ged)"
--- - "OnEditorSelect(selected, ged)"
---
--- The combo box is sorted alphabetically, with the default methods appearing first, followed by a separator, and then the methods from the parent classes.
---
--- @param method_def ClassMethodDef The `ClassMethodDef` object to generate the combo box for.
--- @return table A table of strings representing the items in the combo box.
function ClassMethodDefKnownMethodsCombo(method_def)
	local defaults = { delete = true }
	for _, method in ipairs(default_methods) do
		local name = method:match("(.+)%(")
		if name then defaults[name] = true end
	end

	local methods = {}
	local class_def = GetParentTableOfKind(method_def, "ClassDef")
	for _, parent in ipairs(class_def.DefParentClassList) do
		local class = g_Classes[parent]
		while class and class.class ~= "PropertyObject" and class.class ~= "Preset" do
			for k, v in pairs(class) do
				if type(v) == "function" then
					local name, params, body = GetFuncSource(v)
					local sep_idx = name and name:find(":", 1, true)
					if sep_idx then
						name = name:sub(sep_idx + 1)
						if not defaults[name] then
							methods[#methods + 1] = string.format("%s(%s)", name, params:trim_spaces())
						end
					end
				end
			end
			class = getmetatable(class)
		end
	end
	table.sort(methods)
	return #methods == 0 and default_methods or table.iappend(table.iappend(table.copy(default_methods), {"---"}), methods)
end

DefineClass.ClassMethodDef = {
	__parents = { "ClassDefSubItem" },
	properties = {
		{ category = "Method", id = "name", name = "Name", editor = "combo", default = "",
			items = ClassMethodDefKnownMethodsCombo,
			validate = function (self, value)
				local sep_idx = type(value) == "string" and value:find("(", 1, true)
				local name = sep_idx and value:sub(1, sep_idx - 1) or value
				if type(value) ~= "string" or not name:match("^[%w_]*$") then
					return "Value must be a valid identifier or a function prototype."
				end
			end, },
		{ category = "Method", id = "params", name = "Params", editor = "text", default = "", },
		{ category = "Method", id = "comment", name = "Comment", editor = "text", default = "", lines = 1, max_lines = 5, },
		{ category = "Method", id = "code", name = "Code", editor = "func", default = false, lines = 1, max_lines = 100,
			params = function (self) return self.params == "" and "self" or "self, " .. self.params end, },
	},
	EditorName = "Method",
	EditorSubmenu = "Code",
}

---
--- Gets the editor view for a ClassMethodDef object.
---
--- @param self ClassMethodDef The ClassMethodDef object.
--- @return string The editor view string.
function ClassMethodDef:GetEditorView()
	local ret = string.format("<color 75 105 198>function</color> <color 45 138 138>Class:</color>%s(%s)", self.name, self.params)
	if self.comment ~= "" then
		ret = string.format("%s <color 0 128 0> -- %s", ret, self.comment)
	end
	return ret
end

---
--- Generates the Lua code for a ClassMethodDef object.
---
--- @param code table The code table to append the generated code to.
--- @param class_name string The name of the class.
function ClassMethodDef:GenerateCode(code, class_name)
	if not self.name:match("^[%w_]+$") then return end
	code:appendf("function %s:%s(%s)\n", class_name, self.name, self.params)
	local name, params, body = GetFuncSource(self.code)
	if type(body) == "string" then
		body = string.split(body, "\n")
	end
	code:append("\t", body and table.concat(body, "\n\t") or "", "\n")
	code:append("end\n\n")
end

---
--- Checks if the code of the ClassMethodDef object contains the specified code snippet.
---
--- @param self ClassMethodDef The ClassMethodDef object.
--- @param snippet string The code snippet to search for.
--- @return boolean True if the code contains the snippet, false otherwise.
function ClassMethodDef:ContainsCode(snippet)
	local name, params, body = GetFuncSource(self.code)
	if type(body) == "table" then
		body = table.concat(body, "\n")
	end
	return body and body:find(snippet, 1, true)
end

---
--- Handles changes to the name property of a ClassMethodDef object.
---
--- When the name property is changed, this function updates the name and parameters
--- of the ClassMethodDef object based on the new name.
---
--- @param self ClassMethodDef The ClassMethodDef object.
--- @param prop_id string The ID of the property that was changed.
--- @param old_value any The old value of the property.
--- @param ged any The GED object associated with the property change.
function ClassMethodDef:OnEditorSetProperty(prop_id, old_value, ged)
	local method = self.name
	if prop_id == "name" and method:find("(", 1, true) then
		self.name = method:match("(.+)%(")
		self.params = method:sub(#self.name + 2, -2)
	end
end


----- ClassGlobalCodeDef

DefineClass.ClassGlobalCodeDef = {
	__parents = { "ClassDefSubItem" },
	properties = {
		{ id = "comment", name = "Comment", editor = "text", default = "", },
		{ id = "code", name = "Code", editor = "func", default = false, lines = 1, max_lines = 100, params = "", },
	},
	EditorName = "Code",
	EditorSubmenu = "Code",
}

---
--- Returns the editor view for the ClassGlobalCodeDef object.
---
--- If the comment property is empty, the editor view is simply "code".
--- Otherwise, the editor view is "code <color 0 128 0>-- {comment}</color>", where {comment} is the value of the comment property.
---
--- @param self ClassGlobalCodeDef The ClassGlobalCodeDef object.
--- @return string The editor view for the ClassGlobalCodeDef object.
function ClassGlobalCodeDef:GetEditorView()
	if self.comment == "" then
		return "code"
	end
	return string.format("code <color 0 128 0>-- %s</color>", self.comment)
end

---
--- Generates the code for a ClassGlobalCodeDef object.
---
--- This function takes the code and class name from the ClassGlobalCodeDef object and appends it to the provided code table. If the comment property is not empty, it is included in the generated code as a comment.
---
--- @param self ClassGlobalCodeDef The ClassGlobalCodeDef object.
--- @param code table A table to append the generated code to.
--- @param class_name string The name of the class.
function ClassGlobalCodeDef:GenerateCode(code, class_name)
	local name, params, body = GetFuncSource(self.code)
	if not body then return end
	code:append("----- ", class_name, " ", self.comment, "\n\n")
	if type(body) == "table" then
		for _, line in ipairs(body) do
			code:append(line, "\n")
		end
	else
		code:append(body)
	end
	code:append("\n")
end
