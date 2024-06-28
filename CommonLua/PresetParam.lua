---
--- Defines a base class for preset parameters.
---
--- The `PresetParam` class provides a base implementation for preset parameters, which are used to store and manage parameter values for presets in the game.
---
--- The class has the following properties:
--- - `Name`: The name of the parameter.
--- - `Value`: The value of the parameter.
--- - `Tag`: A read-only text representation of the parameter, which can be used to display the parameter's value in-game.
---
--- The class also provides the following methods:
--- - `GetTag()`: Returns the parameter's tag, which is the parameter name enclosed in angle brackets (e.g. `<MyParameter>`).
--- - `GetError()`: Returns an error message if the parameter name is invalid (e.g. empty or contains non-alphanumeric characters).
---
--- Subclasses of `PresetParam` can be defined to provide specialized behavior for different types of parameters, such as numeric or percentage parameters.
DefineClass.PresetParam = {
	__parents = { "PropertyObject", },
	properties = {
		{ id = "Name", editor = "text", default = false, },
		{ id = "Value", editor = "number", default = 0, },
		{ id = "Tag", editor = "text", translate = false, read_only = true, default = "", help = "Paste this tag into texts to display the parameter's value.", },
	},
	EditorView = Untranslated("Param <Name> = <Value>"),
	Type = "number",
}

---
--- Returns the parameter's tag, which is the parameter name enclosed in angle brackets (e.g. `<MyParameter>`).
---
--- @return string The parameter's tag.
function PresetParam:GetTag()
	return "<" .. (self.Name or "") .. ">"
end

---
--- Returns an error message if the parameter name is invalid (e.g. empty or contains non-alphanumeric characters).
---
--- @return string The error message, or an empty string if the parameter name is valid.
function PresetParam:GetError()
	if not self.Name then
		return "Please name your parameter."
	elseif not self.Name:match("^[%w_]*$") then
		return "Parameter name must only contain alpha-numeric characters and underscores."
	end
end

---
--- Defines a preset parameter that represents a numeric value.
---
--- The `PresetParamNumber` class is a subclass of `PresetParam` that provides specialized behavior for numeric parameters. It has the following properties:
---
--- - `Value`: The numeric value of the parameter.
---
--- The `EditorName` property is set to "New Param (number)" to provide a default name for this type of parameter in the editor.
---
--- Subclasses of `PresetParamNumber` can be defined to provide additional specialized behavior for different types of numeric parameters, such as integer or floating-point parameters.
---
DefineClass.PresetParamNumber = {
	__parents = { "PresetParam", },
	properties = {
		{ id = "Value", editor = "number", default = 0, },
	},
	EditorName = "New Param (number)",
}

---
--- Defines a preset parameter that represents a numeric percentage value.
---
--- The `PresetParamPercent` class is a subclass of `PresetParam` that provides specialized behavior for percentage parameters. It has the following properties:
---
--- - `Value`: The numeric value of the parameter, represented as a percentage.
---
--- The `EditorView` property is set to display the parameter name and value with a percent sign (e.g. "Param <Name> = <Value>%").
---
--- The `EditorName` property is set to "New Param (percent)" to provide a default name for this type of parameter in the editor.
---
--- Subclasses of `PresetParamPercent` can be defined to provide additional specialized behavior for different types of percentage parameters.
---
DefineClass.PresetParamPercent = {
	__parents = { "PresetParam", },
	properties = {
		{ id = "Value", editor = "number", default = 0, scale = "%" },
	},
	EditorView = Untranslated("Param <Name> = <Value>%"),
	EditorName = "New Param (percent)",
}

---
--- Returns the tag for this preset parameter, which is the parameter name enclosed in angle brackets and followed by a percent sign.
---
--- @return string The tag for this preset parameter.
function PresetParamPercent:GetTag()
	return "<" .. (self.Name or "") .. ">%"
end

---
--- Picks a parameter from a list of parameters defined in a preset object.
---
--- @param root table The root object that contains the parameter bindings.
--- @param obj table The object that contains the parameter bindings.
--- @param prop_id string The property ID of the parameter to be picked.
--- @param ged table The GED (Game Editor) object that provides access to the editor functionality.
---
--- This function first retrieves the list of parameters defined in the preset object associated with the given object. It then presents the user with a list of parameter names to choose from, either automatically selecting the first parameter if there is only one, or prompting the user to select a parameter if there are multiple. The selected parameter is then bound to the specified property of the object, and the object and its root are marked as modified.
---
function PickParam(root, obj, prop_id, ged)
	local param_obj = ged:GetParentOfKind(obj, "Preset").Parameters
	local params = {}
	local params_to_num = {}
	for _,item in ipairs(param_obj) do
		if item.Name then
			params[#params + 1] = item.Name
			params_to_num[item.Name] = item.Value
		end
	end
	
	if #params == 0 then
		ged:ShowMessage("Error", "There are no Parameters defined for this Preset.")
		return
	end
	
	local pick = obj.param_bindings and obj.param_bindings[prop_id] or params[1]
	if #params > 1 then
		pick = ged:WaitUserInput("Select Param", pick, params)
		if not pick then return end
	end
	obj.param_bindings = obj.param_bindings or {}
	obj.param_bindings[prop_id] = pick
	obj:SetProperty(prop_id, params_to_num[pick])
	GedForceUpdateObject(obj)
	ObjModified(obj)
	ObjModified(root)
end

local function PresetParamOnEditorNew(obj, parent, ged)
	local preset = ged:GetParentOfKind(parent, "Preset") or obj
	if obj:IsKindOf("PresetParam") then
		local preset_param_cache = g_PresetParamCache[preset] or {}
		preset_param_cache[obj.Name] = obj.Value
		g_PresetParamCache[preset] = preset_param_cache
	elseif preset:HasMember("HasParameters") and preset.HasParameters == true and not obj:HasMember("param_bindings") then
		rawset(obj, "param_bindings", false)
	end
end

local function PresetParamOnEditorSetProperty(obj, prop_to_change, prev_value, ged)
	local preset = ged.selected_object
	if not preset then return end
	
	if obj:IsKindOf("PresetParam") then
		local preset_param_cache = g_PresetParamCache[preset] or {}
		
		if prop_to_change == "Value" then
			preset:ForEachSubObject(function(subobj, parents, key, param_name, new_value)
				for prop, param in pairs(rawget(subobj, "param_bindings")) do
					if param == param_name then
						subobj:SetProperty(prop, new_value)
						ObjModified(subobj)
					end
				end
			end, obj.Name, obj.Value)
		elseif prop_to_change == "Name" then
			preset:ForEachSubObject(function(subobj, parents, key, new_name, old_name)
				for prop, param in pairs(rawget(subobj, "param_bindings")) do
					if param == old_name then
						subobj.param_bindings[prop] = new_name
						ObjModified(subobj)
					end
				end
			end, obj.Name, prev_value)
			
			preset_param_cache[prev_value] = nil
		end
		
		preset_param_cache[obj.Name] = obj.Value
		g_PresetParamCache[preset] = preset_param_cache
	elseif obj:HasMember("param_bindings") and obj.param_bindings and obj.param_bindings[prop_to_change] then
		obj.param_bindings[prop_to_change] = nil
	end
end

local function PresetParamOnEditorDelete(obj, parent, ged)
	local preset = ged.selected_object
	if not preset then return end
	
	if obj:IsKindOf("PresetParam") then
		preset:ForEachSubObject(function(subobj, parents, key, deleted_param)
			for prop, param in pairs(rawget(subobj, "param_bindings")) do
				if param == deleted_param then
					subobj.param_bindings[prop] = nil
					ObjModified(subobj)
				end
			end
		end, obj.Name)
		
		if g_PresetParamCache[preset] then
			g_PresetParamCache[preset][obj.Name] = nil
		end
	end
end

function OnMsg.GedNotify(obj, method, ...)
	if method == "OnEditorNew" then
		PresetParamOnEditorNew(obj, ...)
	elseif method == "OnEditorSetProperty" then
		PresetParamOnEditorSetProperty(obj, ...)
	elseif method == "OnAfterEditorDelete" then
		PresetParamOnEditorDelete(obj, ...)
	end
end
