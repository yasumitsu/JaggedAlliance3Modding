XWindowPropertyTabs = {
	{ TabName = "Layout", Categories = { Layout = true, Children = true, } },
	{ TabName = "Visual", Categories = { Visual = true, FX = true, } },
	{ TabName = "Image", Categories = { Image = true, Animation = true, Icons = true --[[Zulu]], } },
	{ TabName = "Behavior", Categories = { General = true, ["Most Recently Used Items"] = true, Interaction = true, Scroll = true, Actions = true, GedApp = true, Progress = true --[[Zulu]], } },
	{ TabName = "Rollover", Categories = { Rollover = true, } },
}

---
--- Returns the class name that a given template ID represents.
---
--- @param template_id string The ID of the template to get the class name for.
--- @return string The class name that the template ID represents, or an empty string if the class name could not be determined.
---
function XTemplateClass(template_id)
	local templates = XTemplates
	for i = 1, 100 do
		local template = templates[template_id]
		local t = template and template.__is_kind_of or ""
		if t == "" then
			return g_Classes[template_id] and template_id
		end
		template_id = t
	end
	return ""
end

---
--- Returns a function that provides a list of XWindow classes and XTemplate IDs that are compatible with a given class.
---
--- @param class string (optional) The class to filter the list by. Defaults to "XWindow".
--- @param include_base boolean (optional) Whether to include the base class in the list. Defaults to true.
--- @return function The function that returns the list of compatible classes and templates.
---
function XTemplateCombo(class, include_base)
	return function(obj, prop_meta, validate_fn)
		if validate_fn == "validate_fn" then
			-- function for preset validation, checks whether the property value is from "items"
			return "validate_fn", function(value, obj, prop_meta)
				if value == "" then return true end
				class = class or "XWindow"
				local template = XTemplates[value]
				return template and IsKindOf(g_Classes[template.__is_kind_of], class) or IsKindOf(g_Classes[value], class) and (include_base ~= false or value ~= class)
			end
		end
	
		-- list all classes
		local list = ClassDescendantsCombo(class or "XWindow", include_base ~= false)()
		-- list all templates of this class
		ForEachPreset("XTemplate", function(template, group, list)
			if not class or IsKindOf(g_Classes[XTemplateClass(template.__is_kind_of)], class) then
				list[#list + 1] = template.id
			end
		end, list)
		return list
	end
end


----- XTemplate

DefineClass.XTemplate = {
	__parents = { "Preset" },
	properties = {
		{ category = "Template", id = "__is_kind_of", name = "Is kind of", editor = "choice", default = "", items = XTemplateCombo(), },
		{ category = "Template", id = "__content", name = "Template content parent", editor = "expression", params = "parent, context"},
		{ category = "Template", id = "recreate_after_save", name = "Recreate dialog after save", editor = "bool", default = false, },
		{ category = "Template", id = "RequireActionSortKeys", name = "Require sort keys", editor = "bool", default = false, },
	},
	GlobalMap = "XTemplates",
	HasSortKey = true,
	SingleFile = false,
	ContainerClass = "XTemplateElement",
	GedEditor = "XTemplateEditor",
	EditorShortcut = "Alt-F3",
	EditorName = "XTemplate",
	EditorMenubarName = "XTemplate Editor",
	EditorMenubar = "Editors.UI",
	EditorIcon = "CommonAssets/UI/Icons/delete.png",
	DocumentationLink = "Docs/LuaUI.md.html",
	Documentation = "Adds a new user interface panel.",
}

--- Provides the parent object for the template content.
---
--- This function is used as the value for the `__content` property of an `XTemplate` object.
--- It simply returns the `parent` argument, which is the parent object for the template content.
---
--- @param parent table The parent object for the template content.
--- @param context table The context object for the template.
--- @return table The parent object for the template content.
function XTemplate.__content(parent, context)
	return parent
end

--- Gets the template properties for the current XTemplate instance.
---
--- This function first checks if the current XTemplate instance has a parent template specified by the `__is_kind_of` property. If a parent template is found, it recursively calls `GetTemplateProperties()` on the parent template to get its properties.
---
--- If no parent template is found, it attempts to get the properties from the class specified by the `__is_kind_of` property.
---
--- The function then iterates through the elements of the current XTemplate instance and adds any `XTemplateProperty` elements to the list of properties.
---
--- @return table The list of template properties for the current XTemplate instance.
function XTemplate:GetTemplateProperties()
	local properties
	local __is_kind_of = self.__is_kind_of
	local template = XTemplates[__is_kind_of]
	if template then
		properties = template:GetTemplateProperties()
	else
		local class = g_Classes[__is_kind_of]
		properties = class and class:GetProperties()
	end
	properties = properties or empty_table
	local copy
	for i = 1, #self do
		if self[i].class == "XTemplateProperty" then
			copy = copy or table.icopy(properties)
			copy[#copy + 1] = self[i]
		end
	end
	return copy or properties
end

--- Gets the default property value for the specified property ID and metadata.
---
--- This function first checks if the property metadata is an `XTemplateProperty` instance, and if so, returns the `default` property of the metadata.
---
--- If the property metadata is not an `XTemplateProperty`, the function iterates through the elements of the `XTemplate` instance, looking for `XTemplateWindow` and `XTemplateTemplate` elements. For each of these elements, the function checks if the property ID is defined on the element, and if so, returns the value. If the property ID is not defined on the element, the function recursively calls `GetTemplateDefaultPropertyValue()` on the parent template (if it exists).
---
--- If the property ID is not found on any of the elements, the function returns the `default` property of the property metadata (if it exists).
---
--- @param prop_id string The ID of the property to get the default value for.
--- @param prop_meta table The metadata for the property.
--- @return any The default value for the specified property.
function XTemplate:GetTemplateDefaultPropertyValue(prop_id, prop_meta)
	prop_meta = prop_meta or self:GetPropertyMetadata(prop_id)
	if IsKindOf(prop_meta, "XTemplateProperty") then
		return prop_meta.default
	end
	for i = 1, #self do
		if self[i].class == "XTemplateWindow" then
			local value = rawget(self[i], prop_id)
			if value ~= nil then return value end
			local class = g_Classes[self[i].__class]
			return class and class:GetDefaultPropertyValue(prop_id, prop_meta)
		end
		if self[i].class == "XTemplateTemplate" then
			local value = rawget(self[i], prop_id)
			if value ~= nil then return value end
			local template = XTemplates[self[i].__template]
			return template and template ~= self and template:GetTemplateDefaultPropertyValue(prop_id, prop_meta)
		end
	end
	return prop_meta and prop_meta.default
end

local procall = procall
local ipairs = ipairs
--- Evaluates the XTemplate instance and returns the result.
---
--- This function iterates through the elements of the XTemplate instance and calls the `Eval()` function on each element. The first non-nil result from the `Eval()` function is stored and returned.
---
--- If the XTemplate instance has an `__is_kind_of` field, the function asserts that the first result is an instance of the class specified by `__is_kind_of`.
---
--- The function then iterates through the elements again, and for any elements of class `XTemplateProperty`, it calls the `Assign()` function on the element, passing the first result as the argument.
---
--- If the first result is not nil and the `Platform.developer` flag is true, the function sets the `__dbg_template` field of the first result to the `id` of the XTemplate instance.
---
--- @param parent table The parent object of the XTemplate instance.
--- @param context table The context object for the XTemplate instance.
--- @return any The result of evaluating the XTemplate instance.
function XTemplate:Eval(parent, context)
	local first_result
	for i, element in ipairs(self) do
		local ok, result = procall(element.Eval, element, parent, context)
		first_result = first_result or result
	end
	assert(not first_result or not XTemplateClass(self.__is_kind_of) or IsKindOf(first_result, XTemplateClass(self.__is_kind_of)))
	for i, element in ipairs(self) do
		if element.class == "XTemplateProperty" then
			element:Assign(first_result)
		end
	end
	if first_result and Platform.developer then
		rawset(first_result, "__dbg_template", self.id)
	end
	return first_result
end

--- Returns the save folder path for the XTemplate instance.
---
--- The save folder path is determined based on the `save_in` property of the XTemplate instance. If `save_in` is empty, the folder is "Lua". If `save_in` is "Common", the folder is "CommonLua/X". If `save_in` is "Ged", the folder is "CommonLua/Ged". If `save_in` is "GameGed", the folder is "Lua/Ged". If `save_in` starts with "Libs/", the folder is "CommonLua/" followed by `save_in`. Otherwise, the folder is "svnProject/Dlc/" followed by `save_in` and "/Presets".
---
--- @param save_in string The save location for the XTemplate instance.
--- @return string The save folder path for the XTemplate instance.
function XTemplate:GetSaveFolder(save_in)
	save_in = save_in or self.save_in
	if save_in == "" then return "Lua" end
	if save_in == "Common" then return "CommonLua/X" end
	if save_in == "Ged" then return "CommonLua/Ged" end
	if save_in == "GameGed" then return "Lua/Ged" end
	if save_in:starts_with("Libs/") then
		return "CommonLua/" .. save_in
	end
	-- save_in is a DLC name
	return string.format("svnProject/Dlc/%s/Presets", save_in)
end

--- Returns the save file path for the XTemplate instance.
---
--- The save file path is determined by calling `XTemplate:GetSaveFolder()` to get the save folder path, and then concatenating it with the filename based on the `id` of the XTemplate instance.
---
--- @return string The save file path for the XTemplate instance, or `nil` if the save folder path could not be determined.
function XTemplate:GetSavePath()
	local folder = self:GetSaveFolder()
	if not folder then return end
	return string.format("%s/XTemplates/%s.lua", folder, self.id)
end

--- Returns a table of preset save locations for the XTemplate instance.
---
--- The returned table includes the standard preset save locations, with two additional locations added:
--- - "Ged": Saves the preset in the "CommonLua/Ged" folder.
--- - "GameGed": Saves the preset in the "Lua/Ged" folder.
---
--- @return table The table of preset save locations for the XTemplate instance.
function XTemplate:GetPresetSaveLocations()
	local locations = Preset.GetPresetSaveLocations(self)
	table.insert(locations, 3, { text = "Ged", value = "Ged" })
	table.insert(locations, 4, { text = "GameGed", value = "GameGed" })
	return locations
end


--- Called after an XTemplate instance is saved.
---
--- If the `recreate_after_save` property is true and the template has an ID, this function will close the current dialog and reopen it with the same parent and context.
---
--- @param user_requested boolean Whether the save was user-initiated or not.
function XTemplate:OnPostSave(user_requested)
	local id = self.id
	if self.recreate_after_save and (id or "") ~= "" then
		local dlg = GetDialog(id)
		if dlg then
			local parent = dlg:GetParent()
			local context = dlg:GetContext()
			CloseDialog(id)
			OpenDialog(id, parent, context)
		end
	end
end


----- XTemplateElement

DefineClass.XTemplateElement = {
	__parents = { "Container" },
	properties = {
		{ category = "Template", id = "comment", name = "Comment", editor = "text", default = "", },
	},
	TreeView = T(357198499972, "<class> <color 0 128 0><comment>"),
	EditorView = Untranslated("<TreeView>"),
	EditorName = "Template Element",
	ContainerClass = "XTemplateElement",
}

--- Evaluates the children of the XTemplateElement and returns the first result.
---
--- This function iterates through the children of the XTemplateElement, calling the `Eval` function on each child and returning the first non-nil result. If the `comment` property of the XTemplateElement is not empty and the first result is not nil, the `__dbg_template_comment` field is set on the first result.
---
--- @param parent table The parent context for the evaluation.
--- @param context table The context for the evaluation.
--- @return any The first non-nil result from evaluating the children.
function XTemplateElement:Eval(parent, context)
	return self:EvalChildren(parent, context)
end

---
--- Evaluates the children of the XTemplateElement and returns the first result.
---
--- This function iterates through the children of the XTemplateElement, calling the `Eval` function on each child and returning the first non-nil result. If the `comment` property of the XTemplateElement is not empty and the first result is not nil, the `__dbg_template_comment` field is set on the first result.
---
--- @param parent table The parent context for the evaluation.
--- @param context table The context for the evaluation.
--- @return any The first non-nil result from evaluating the children.
function XTemplateElement:EvalChildren(parent, context)
	local first_result
	for i, element in ipairs(self) do
		local ok, result = procall(element.Eval, element, parent, context)
		first_result = first_result or result
	end
	if Platform.developer and self.comment ~= "" and first_result then
		rawset(first_result, "__dbg_template_comment", self.comment)
	end
	return first_result
end

---
--- Constructs a new instance of `XTemplateElement` and sets its properties based on the provided `props` table.
---
--- @param props table A table of key-value pairs representing the properties to set on the new `XTemplateElement` instance.
--- @param arr table An array of child elements to add to the new `XTemplateElement` instance.
--- @return table The new `XTemplateElement` instance with the specified properties and child elements.
function XTemplateElement:__fromluacode(props, arr)
	local obj = self:new(arr)
	for i = 1, #(props or ""), 2 do
		obj[props[i]] = props[i + 1]
	end
	return obj
end


----- XTemplateElementGroup

DefineClass.XTemplateElementGroup = {
	__parents = { "XTemplateElement" },
	properties = {
		{ category = "Template", id = "__context_of_kind", name = "Require context of kind", editor = "text", default = "" },
		{ category = "Template", id = "__context", name = "Context expression", editor = "expression", params = "parent, context" },
		{ category = "Template", id = "__parent", name = "Parent expression", editor = "expression", params = "parent, context" },
		{ category = "Template", id = "__condition", name = "Condition", editor = "expression", params = "parent, context", },
	},
	TreeView = T(551379353577, "Group<ConditionText> <color 0 128 0><comment>"),
	EditorName = "Group",
}

---
--- Returns the parent context for the evaluation.
---
--- This function is used within the `XTemplateElementGroup` class to determine the parent context for the evaluation of the template element group. It simply returns the `parent` parameter passed to the function.
---
--- @param parent table The parent context for the evaluation.
--- @param context table The context for the evaluation.
--- @return table The parent context for the evaluation.
function XTemplateElementGroup.__parent(parent, context)
	return parent
end

---
--- Returns the context for the evaluation.
---
--- This function is used within the `XTemplateElementGroup` class to determine the context for the evaluation of the template element group. It simply returns the `context` parameter passed to the function.
---
--- @param parent table The parent context for the evaluation.
--- @param context table The context for the evaluation.
--- @return table The context for the evaluation.
function XTemplateElementGroup.__context(parent, context)
	return context
end

---
--- Evaluates the condition for the `XTemplateElementGroup`.
---
--- This function is used within the `XTemplateElementGroup` class to determine whether the template element group should be evaluated. It always returns `true`, indicating that the template element group should always be evaluated.
---
--- @param parent table The parent context for the evaluation.
--- @param context table The context for the evaluation.
--- @return boolean `true` if the template element group should be evaluated, `false` otherwise.
function XTemplateElementGroup.__condition(parent, context)
	return true
end

---
--- Returns a formatted string representing the condition expression for the `XTemplateElementGroup`.
---
--- This function is used to generate a formatted string representation of the condition expression for the `XTemplateElementGroup`. If the condition expression is the same as the default condition expression defined in the class, an empty string is returned. Otherwise, the function extracts the function name, parameters, and body from the condition expression and formats it as a string, with the body wrapped in a `<color 128 128 220>cond:</color>` tag.
---
--- @return string The formatted condition expression string.
function XTemplateElementGroup:ConditionText()
	if self.__condition == g_Classes[self.class].__condition then
		return ""
	end

	-- get condition as a string
	local name, params, body = GetFuncSource(self.__condition)
	if type(body) == "table" then
		body = table.concat(body, "\n")
	end
	if body then
		body = body:match("^%s*return%s*(.*)") or body
		-- Put a space between < and numbers to avoid treating it like a tag
		body = string.gsub(body, "([%w%d])<(%d)", "%1< %2")
	end
	return body and " <color 128 128 220>cond:" .. body or ""
end

---
--- Evaluates the `XTemplateElementGroup` and returns the result.
---
--- This function is responsible for evaluating the `XTemplateElementGroup` and returning the result. It first checks the context type to ensure it matches the expected type, then calls the `__context` and `__parent` functions to get the appropriate context and parent. If the `__condition` function returns `false`, the function returns without further evaluation. Otherwise, it calls the `EvalElement` function to evaluate the element.
---
--- @param parent table The parent context for the evaluation.
--- @param context table The context for the evaluation.
--- @return any The result of evaluating the `XTemplateElementGroup`.
function XTemplateElementGroup:Eval(parent, context)
	local kind = self.__context_of_kind
	if kind == "" 
		or type(context) == kind
		or IsKindOf(context, kind)
		or (IsKindOf(context, "Context") and context:IsKindOf(kind)) 
	then
		context = self.__context(parent, context)
		parent = self.__parent(parent, context)
		if not self.__condition(parent, context) then
			return
		end
		return self:EvalElement(parent, context)
	end
end

---
--- Evaluates the children of the `XTemplateElementGroup` and returns the result.
---
--- This function is responsible for evaluating the children of the `XTemplateElementGroup` and returning the result. It calls the `Eval` function on each child element and returns the result.
---
--- @param parent table The parent context for the evaluation.
--- @param context table The context for the evaluation.
--- @return any The result of evaluating the children of the `XTemplateElementGroup`.
function XTemplateElementGroup:EvalElement(parent, context)
	return self:EvalChildren(parent, context)
end


----- XTemplateGroup

DefineClass("XTemplateGroup", "XTemplateElementGroup")


----- XTemplateCode

DefineClass.XTemplateCode = {
	__parents = { "XTemplateElement" },
	properties = {
		{ category = "Template", id = "copy_context", name = "Copy context", editor = "bool", default = false },
		{ category = "Template", id = "run", name = "Run", editor = "func", params = "self, parent, context", lines = 2, max_lines = 40 },
	},
	TreeView = T(519549090093, "Code <color 0 128 0><comment>"),
	EditorName = "Code",
	ContainerClass = "", -- disallow children
}

---
--- Evaluates the `XTemplateCode` element and returns the result.
---
--- This function is responsible for evaluating the `XTemplateCode` element and returning the result. It creates a sub-context if the `copy_context` property is set, and then calls the `run` function with the parent and sub-context.
---
--- @param parent table The parent context for the evaluation.
--- @param context table The context for the evaluation.
--- @return any The result of evaluating the `XTemplateCode` element.
function XTemplateCode:Eval(parent, context)
	local sub_context = self.copy_context and SubContext(context) or context
	return self:run(parent, sub_context)
end

---
--- Evaluates the `XTemplateCode` element and returns the result.
---
--- This function is responsible for evaluating the `XTemplateCode` element and returning the result. It creates a sub-context if the `copy_context` property is set, and then calls the `run` function with the parent and sub-context.
---
--- @param parent table The parent context for the evaluation.
--- @param context table The context for the evaluation.
--- @return any The result of evaluating the `XTemplateCode` element.
function XTemplateCode:run(parent, context)
end


----- XTemplateFunc

DefineClass.XTemplateFunc = {
	__parents = { "XTemplateElement" },
	properties = {
		{ category = "Template", id = "name", name = "Name", editor = "combo", default = "", items = {
			"OnContextUpdate(self, context, ...)",
			"OnMouseButtonDown(self, pos, button)",
			"OnShortcut(self, shortcut, source, ...)",
			"OnPress(self)",
			"OnSetRollover(self, rollover)",
			"SetEnabled(self, enabled)",
		}},
		{ category = "Template", id = "parent", name = "Parent", editor = "expression", params = "parent, context", },
		{ category = "Template", id = "func", name = "Func", editor = "func", default = false, 
			params = function(obj) local name, params = ParseFuncDecl(obj.name) return params or "self, ..." end },
	},
	TreeView = T(804254723579, "func <name> <color 0 128 0><comment>"),
	EditorName = "Function",
	ContainerClass = "", -- disallow children
}

---
--- Parses a function declaration string and returns the function name and parameter list.
---
--- This function takes a string representing a function declaration and extracts the function name and parameter list from it. The function declaration string should be in the format `"function_name(param1, param2, ...)"`.
---
--- @param decl string The function declaration string to parse.
--- @return string|nil The function name, or `nil` if the declaration could not be parsed.
--- @return string|nil The parameter list, or `nil` if the declaration could not be parsed.
function ParseFuncDecl(decl)
	decl = decl or ""
	local name, params = decl:match("^%s*([%w:_]+)%s*%(([%w%s,._]-)%)%s*$")
	name = name or decl:match("^%s*([%w:_]+)%s*$")
	return name, params
end

---
--- Returns the parent context for the evaluation.
---
--- This function is a helper function for the `XTemplateFunc` class. It simply returns the `parent` parameter passed to it, which represents the parent context for the evaluation.
---
--- @param parent table The parent context for the evaluation.
--- @param context table The context for the evaluation.
--- @return table The parent context for the evaluation.
function XTemplateFunc.parent(parent, context)
	return parent
end

---
--- Evaluates the XTemplateFunc and sets its function on the parent context.
---
--- This function is responsible for evaluating the XTemplateFunc and setting its associated function on the parent context. It first parses the function declaration to extract the function name, and then sets the function on the parent context if the function name and function are both valid. Finally, it evaluates the children of the XTemplateFunc.
---
--- @param parent table The parent context for the evaluation.
--- @param context table The context for the evaluation.
--- @return table The result of evaluating the children of the XTemplateFunc.
function XTemplateFunc:Eval(parent, context)
	local name = ParseFuncDecl(self.name)
	if name and self.func then
		parent = self.parent(parent, context)
		if parent then
			rawset(parent, name, self.func)
		end
	end
	return self:EvalChildren(parent, context)
end


----- XTemplateWindow

DefineClass.XTemplateWindowBase = {
	__parents = { "XTemplateElementGroup" },
	properties = {
		{ category = "Template", id = "__class", name = "Class", editor = "choice", default = "XWindow", show_recent_items = 7,
			items = function() return ClassDescendantsCombo("XWindow", true) end, },
	},
	TreeView = T(700510148795, "<IdNodeColor><__class><ConditionText><opt(PlacementText,' <color 128 128 128>','')><opt(comment,' <color 0 128 0>')>"),
	EditorName = "Window",
	PropertyTabs = XWindowPropertyTabs,
}

DefineClass("XTemplateWindow", "XTemplateWindowBase")

---
--- Returns the color of the IdNode for the XTemplateWindowBase.
---
--- This function checks the IdNode property of the XTemplateWindowBase. If the IdNode is false or nil, it returns an empty string. Otherwise, it checks if any of the child elements of the XTemplateWindowBase are instances of XTemplateElementGroup, and if so, returns the color code "<color 75 105 198>". If no child elements are XTemplateElementGroup instances, it returns an empty string.
---
--- @param self XTemplateWindowBase The XTemplateWindowBase instance to get the IdNode color for.
--- @return string The color code for the IdNode, or an empty string if the IdNode is not set or there are no XTemplateElementGroup child elements.
function XTemplateWindowBase:IdNodeColor()
	local idNode = rawget(self, "IdNode")
	if idNode == false or (idNode == nil and not _G[self.__class].IdNode) then
		return ""
	end
	for _,item in ipairs(self) do
		if IsKindOf(item, "XTemplateElementGroup") then
			return "<color 75 105 198>"
		end
	end
	return ""
end

---
--- Returns a string representing the placement text for an XTemplateWindowBase instance.
---
--- If the XTemplateWindowBase instance is an instance of XOpenLayer, the placement text will be the value of the "Layer" property and the "Mode" property.
---
--- If the XTemplateWindowBase instance is not an instance of XOpenLayer, the placement text will be the value of the "Id" property, and if the "Dock" property is set, it will also include the value of the "Dock" property.
---
--- @param self XTemplateWindowBase The XTemplateWindowBase instance to get the placement text for.
--- @return string The placement text for the XTemplateWindowBase instance.
function XTemplateWindowBase:PlacementText()
	local class = g_Classes[self.__class]
	if class and class:IsKindOf("XOpenLayer") then
		return Untranslated(self:GetProperty("Layer") .. " " .. self:GetProperty("Mode"))
	else
		local dock = self:GetProperty("Dock")
		dock = dock and (" Dock:" .. tostring(dock)) or ""
		return Untranslated(self:GetProperty("Id") .. dock)
	end
end

local eval = prop_eval
---
--- Returns the properties of the XTemplateWindowBase instance.
---
--- This function retrieves the properties of the XTemplateWindowBase instance by first copying the `properties` table, and then iterating through the class's properties. For each property, it checks if the `dont_save` condition is not met, and if so, adds the property metadata to the `properties` table.
---
--- @param self XTemplateWindowBase The XTemplateWindowBase instance to get the properties for.
--- @return table The properties of the XTemplateWindowBase instance.
function XTemplateWindowBase:GetProperties()
	local properties = table.icopy(self.properties)
	local class = g_Classes[self.__class]
	for _, prop_meta in ipairs(class and class:GetProperties() or empty_table) do
		if not eval(prop_meta.dont_save, self, prop_meta) then
			properties[#properties + 1] = prop_meta
		end
	end
	return properties
end

local modified_base_props = {}

---
--- Sets the value of a property on the XTemplateWindowBase instance.
---
--- This function sets the value of the specified property on the XTemplateWindowBase instance. It also clears the `modified_base_props` table for this instance, indicating that the properties have been updated.
---
--- @param self XTemplateWindowBase The XTemplateWindowBase instance to set the property on.
--- @param id string The ID of the property to set.
--- @param value any The new value for the property.
function XTemplateWindowBase:SetProperty(id, value)
	rawset(self, id, value)
	modified_base_props[self] = nil
end

---
--- Returns the value of the specified property on the XTemplateWindowBase instance.
---
--- If the property exists on the XTemplateWindowBase instance, its value is returned. Otherwise, the default property value is retrieved from the class associated with the XTemplateWindowBase instance.
---
--- @param self XTemplateWindowBase The XTemplateWindowBase instance to get the property from.
--- @param id string The ID of the property to get.
--- @return any The value of the specified property.
function XTemplateWindowBase:GetProperty(id)
	if self:HasMember(id) then
		return self[id]
	else
		local class = g_Classes[self.__class]
		return class and class:GetDefaultPropertyValue(id)
	end
end

---
--- Returns the default property value for the specified property ID on the XTemplateWindowBase instance.
---
--- If the property exists on the XTemplateWindowBase instance, its default value is returned. Otherwise, the default property value is retrieved from the class associated with the XTemplateWindowBase instance.
---
--- @param self XTemplateWindowBase The XTemplateWindowBase instance to get the default property value from.
--- @param id string The ID of the property to get the default value for.
--- @param prop_meta table The property metadata for the specified property ID.
--- @return any The default value of the specified property.
function XTemplateWindowBase:GetDefaultPropertyValue(id, prop_meta)
	if XTemplateWindowBase:HasMember(id) then
		return XTemplateWindowBase[id]
	end
	local class = g_Classes[self.__class]
	return class and class:GetDefaultPropertyValue(id, prop_meta) or false
end

---
--- Retrieves the properties to copy from the specified XTemplateWindowBase instance.
---
--- This function iterates through the provided list of property metadata and collects the non-nil property values from the XTemplateWindowBase instance. The resulting list of property ID-value pairs is returned.
---
--- @param self XTemplateWindowBase The XTemplateWindowBase instance to retrieve the properties from.
--- @param props table The list of property metadata to check.
--- @return table A list of property ID-value pairs to copy.
function GetPropsToCopy(self, props)
	local result = {}
	for _, prop_meta in ipairs(props) do
		local id = prop_meta.id
		local value = rawget(self, id)
		if value ~= nil then
			result[#result + 1] = { id, value }
		end
	end
	return result
end

---
--- Evaluates an XTemplate element and creates a new instance of the corresponding class.
---
--- This function retrieves the class associated with the XTemplateWindowBase instance, creates a new instance of that class, and copies the properties from the XTemplateWindowBase instance to the new instance. It then evaluates the children of the XTemplateWindowBase instance and returns the new instance.
---
--- @param self XTemplateWindowBase The XTemplateWindowBase instance to evaluate.
--- @param parent any The parent object of the new instance.
--- @param context any The context to use when evaluating the new instance.
--- @return any The new instance of the corresponding class.
function XTemplateWindowBase:EvalElement(parent, context)
	local class = g_Classes[self.__class]
	assert(class, "XTemplateWindow class not found")
	if not class then return end
	local obj = class:new({}, parent, context, self)
	
	local props = modified_base_props[self]
	if not props then
		props = GetPropsToCopy(self, obj:GetProperties())
		modified_base_props[self] = props
	end
	
	for _, entry in ipairs(props) do
		local id, value = entry[1], entry[2]
		if type(value) == "table" and not IsT(value) then
			value = table.copy(value, "deep")
		end
		obj:SetProperty(id, value)
	end
	self:EvalChildren(obj, context)
	return obj
end

---
--- Called when a property of the XTemplateWindowBase instance is set.
---
--- This function checks if the class associated with the XTemplateWindowBase instance has an `OnXTemplateSetProperty` method, and if so, calls that method with the property ID and old value as arguments.
---
--- @param self XTemplateWindowBase The XTemplateWindowBase instance.
--- @param prop_id string The ID of the property that was set.
--- @param old_value any The old value of the property.
---
function XTemplateWindowBase:OnEditorSetProperty(prop_id, old_value)
	local class = g_Classes[self.__class]
	if class and class:HasMember("OnXTemplateSetProperty") then
		class.OnXTemplateSetProperty(self, prop_id, old_value)
	end
end

---
--- Checks for errors in the XTemplateWindowBase instance.
---
--- This function checks for two specific errors:
--- 1. If the class associated with the XTemplateWindowBase instance is an XContentTemplate, it checks if the 'RespawnOnContext' and 'ContextUpdateOnOpen' properties are both true, which would cause children to be 'Opened' twice.
--- 2. If the class associated with the XTemplateWindowBase instance is an XEditableText, it checks if the 'Translate' and 'UserText' properties are both set, which is not allowed.
---
--- @return string|nil The error message, or nil if no error is found.
function XTemplateWindowBase:GetError()
	local class = g_Classes[self.__class]
	if IsKindOf(class, "XContentTemplate") then
		if self:GetProperty("RespawnOnContext") and self:GetProperty("ContextUpdateOnOpen") then
			return "'RespawnOnContext' and 'ContextUpdateOnOpen' shouldn't be simultaneously true. This will cause children to be 'Opened' twice."
		end
	end
	if IsKindOf(class, "XEditableText") then
		if self:GetProperty("Translate") and self:GetProperty("UserText") then
			return "'Translated text' and 'User text' properties can't be both set."
		end
	end
end


----- XTemplateTemplate

DefineClass.XTemplateTemplate = {
	__parents = { "XTemplateElementGroup" },
	properties = {
		{ category = "Template", id = "UseDialogModeAsTemplate", name = "Use Dialog Mode as Template", editor = "bool", default = false },
		{ category = "Template", id = "__template", name = "Template", editor = "preset_id", default = "", preset_class = "XTemplate",
			no_validate = function(self) return self.IgnoreMissing end,
			no_edit = function (self) return self.UseDialogModeAsTemplate end, },
		{ category = "Template", id = "IgnoreMissing", name = "Ignore missing template", editor = "bool", default = false,
			no_edit = function (self) return self.UseDialogModeAsTemplate end, },
	},
	TreeView = T(323454137582, "T: <ShowTemplateName><ConditionText> <color 0 128 0><comment>"),
	EditorName = "Invoke template",
	PropertyTabs = XWindowPropertyTabs,
}

---
--- Returns the name of the template used by this XTemplateTemplate instance.
---
--- If `UseDialogModeAsTemplate` is true, the name of the dialog mode template is returned.
--- Otherwise, if `__template` is not an empty string, the `__template` value is returned.
--- If neither of the above conditions are true, the string "???" is returned.
---
--- @return string The name of the template used by this XTemplateTemplate instance.
function XTemplateTemplate:ShowTemplateName()
	return self.UseDialogModeAsTemplate and Untranslated("Dialog.mode") or self.__template ~= "" and self.__template or Untranslated("???")
end

---
--- Returns the properties of the XTemplateTemplate instance, including any properties defined in the template referenced by `__template`.
---
--- If `UseDialogModeAsTemplate` is true, the properties of the XTemplateTemplate instance are returned.
--- Otherwise, the properties of the XTemplateTemplate instance are combined with the properties of the template referenced by `__template`.
---
--- @return table The properties of the XTemplateTemplate instance.
function XTemplateTemplate:GetProperties()
	if self.UseDialogModeAsTemplate then return self.properties end
	local properties = table.icopy(self.properties)
	local template = XTemplates[self.__template]
	for _, prop_meta in ipairs(template and template:GetTemplateProperties() or empty_table) do
		properties[#properties + 1] = prop_meta
	end
	return properties
end

---
--- Returns the value of the specified property for this XTemplateTemplate instance.
---
--- If the property is defined on the XTemplateTemplate instance, its value is returned.
--- Otherwise, if the property is defined on the template referenced by `__template`, the default value for that property is returned.
---
--- @param id string The ID of the property to retrieve.
--- @return any The value of the specified property.
function XTemplateTemplate:GetProperty(id)
	if self:HasMember(id) then
		return self[id]
	end
	local template = XTemplates[self.__template]
	return template and template:GetTemplateDefaultPropertyValue(id)
end

---
--- Returns the default value for the specified property of this XTemplateTemplate instance.
---
--- If the property is defined on the XTemplateTemplate instance, its default value is returned.
--- Otherwise, if the property is defined on the template referenced by `__template`, the default value for that property is returned.
---
--- @param id string The ID of the property to retrieve the default value for.
--- @param prop_meta table The metadata for the property.
--- @return any The default value of the specified property.
function XTemplateTemplate:GetDefaultPropertyValue(id, prop_meta)
	if XTemplateTemplate:HasMember(id) then
		return XTemplateTemplate[id]
	end
	local template = XTemplates[self.__template]
	return template and template:GetTemplateDefaultPropertyValue(id, prop_meta)
end

local modified_template_props = {}

---
--- Sets the specified property on the XTemplateTemplate instance to the given value.
---
--- This function also clears the `modified_template_props` table for this XTemplateTemplate instance, indicating that the properties have been updated.
---
--- @param id string The ID of the property to set.
--- @param value any The value to set the property to.
function XTemplateTemplate:SetProperty(id, value)
	rawset(self, id, value)
	modified_template_props[self] = nil
end

---
--- Evaluates an XTemplateTemplate element and applies any modified properties to the resulting object.
---
--- This function first retrieves the XTemplate associated with the XTemplateTemplate's `__template` field. If the `UseDialogModeAsTemplate` flag is set, it uses the XTemplate associated with the current dialog mode instead.
---
--- It then evaluates the XTemplate, creating a new object. If the XTemplateTemplate has any modified properties, it copies those properties to the new object.
---
--- Finally, it evaluates any child elements of the XTemplateTemplate and returns the resulting object.
---
--- @param parent table The parent object for the XTemplateTemplate.
--- @param context table The context for evaluating the XTemplateTemplate.
--- @return table The resulting object from evaluating the XTemplateTemplate.
function XTemplateTemplate:EvalElement(parent, context)
	local template = XTemplates[self.__template]
	if self.UseDialogModeAsTemplate then
		local dlg = GetDialog(parent)
		template = XTemplates[dlg and dlg.Mode or false]
	end	
	assert(template or self.__template == "" or self.UseDialogModeAsTemplate or self.IgnoreMissing, "XTemplate not found")
	if not template then return end
	local obj = template:Eval(parent, context)
	
	if obj then
		local props = modified_template_props[self]
		if not props then
			props = GetPropsToCopy(self, obj:GetProperties())
			modified_template_props[self] = props
		end
		for _, entry in ipairs(props) do
			local id, value = entry[1], entry[2]
			obj:SetProperty(id, value)
		end
		if Platform.developer then
			rawset(obj, "__dbg_template_template", self.__template)
		end
	end
	
	local content_parent = template.__content(obj, context)
	self:EvalChildren(content_parent, context)
	return obj
end


----- XTemplateProperty

DefineClass.XTemplateProperty = {
	__parents = { "XTemplateElement" },
	properties = {
		{ category = "Property", id = "category", name = "Category", editor = "text", default = false, },
		{ category = "Property", id = "id", name = "Id", editor = "text", default = "", validate = ValidateIdentifier },
		{ category = "Property", id = "editor", name = "Type", editor = "choice", default = "bool", items = { "bool", "number", "number_list", "text", "point", "choice", "color"}, },
		{ category = "Property", id = "default", name = "Default value", editor = function (obj) return obj.editor end, default = false,
			scale = function (obj) return obj.scale end, translate = function (obj) return obj.translate end, items = function(obj) return obj.items end},
		{ category = "Property", id = "items", name = "Items", editor = "expression", default = false, no_edit = function (obj) return obj.editor ~= "choice" end},
		{ category = "Property", id = "preset_class", name = "Preset class", editor = "choice", default = false, items = ClassDescendantsCombo("Preset"), no_edit = function (obj) return obj.editor ~= "preset_id" end},
		{ category = "Property", id = "extra_item", name = "Extra item", editor = "text", default = false },
		{ category = "Property", id = "scale", name = "Scale", editor = "choice", default = 1, no_edit = function (obj) return obj.editor ~= "number" end,
			items = function () return table.keys2(const.Scale, true, 1, 10, 100, 1000) end, },
		{ category = "Property", id = "translate", name = "Translate", editor = "bool", default = true, no_edit = function (obj) return obj.editor ~= "text" end},
		{ category = "Property", id = "Set", editor = "func", default = false, params = "self, value", },
		{ category = "Property", id = "Get", editor = "func", default = false, params = "self", },
		{ category = "Property", id = "name", name = "Name", editor = "text", translate = true, default = false},
		{ category = "Property", id = "help", name = "Help", editor = "text", translate = true, default = false},
	},
	
	ContainerClass = "", -- disallow children
	TreeView = T(534697746090, "Property <id> <color 0 128 0><comment>"),
	EditorName = "Property",
	
	dont_save = false,
	no_edit = false,
	no_validate = false,
	read_only = false,
	sort_order = false,
	name_on_top = false,
	hide_name = false,
	lines = false,
	max_lines = false,
	max_len = false,
	buttons = false,
	folder = false,
	filter = false,
	force_extension = false,
	validate = false,
	context = false,
	gender = false,
	min = min_int,
	max = max_int,
	step = 1,
	float = false,
	slider = false,
	wordwrap = false,
	text_style = false,
	os_path = false,
	realtime_update = false,
	max_items_in_set = false,
	base_class = "PropertyObject",
	auto_expand = false,
	preset_group = false,
	auto_select_all = false,
	allowed_chars = false,
	format = "<EditorView>",
	alpha = true,
	item_default = function(obj, prop_meta)
		if prop_meta.editor == "number_list" then return 0 end
	end,
	max_items = max_int,
	three_state = false,
	inject_in_subobjects = false,
	params = "",
}

---
--- Assigns the property to the parent object.
---
--- @param parent table The parent object to assign the property to.
--- @param context table The context for the assignment.
---
function XTemplateProperty:Assign(parent, context)
	local id = self.id or ""
	if id ~= "" then
		if self.Set then
			rawset(parent, "Set" .. id, self.Set)
		end
		if self.Get then
			rawset(parent, "Get" .. id, self.Get)
		end
		assert(rawget(parent, id) == nil) 
		local properties = rawget(parent, "properties")
		if not properties then
			properties = table.icopy(parent.properties)
			parent.properties = properties
		end
		properties[#properties + 1] = self
		rawset(parent, id, self.default)
	end
end

---
--- Handles the editor property change for an XTemplateProperty.
---
--- When the "editor" property is changed, the default value is set to `nil`.
---
--- @param prop_id string The ID of the property that was changed.
--- @param old_value any The previous value of the property.
--- @param ged table The GED (Game Editor Data) object associated with the property.
---
function XTemplateProperty:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "editor" then
		self.default = nil
	end
end

----- XTemplateMode

DefineClass.XTemplateMode = {
	__parents = { "XTemplateElement" },
	properties = {
		{ category = "Template", id = "mode", name = "Mode", editor = "text", default = "", help = "A single mode or a list of modes."},
	},
	TreeView = T(542491254779, "<color 178 16 16>Mode <mode> <color 0 128 0><comment>"),
	EditorName = "Mode",
}

---
--- Evaluates the XTemplateMode element for the given parent and context.
---
--- If the dialog's mode matches the mode of this XTemplateMode element, then the children of this element are evaluated.
---
--- @param parent table The parent object to evaluate the mode against.
--- @param context table The context for the evaluation.
--- @return boolean Whether the children of this XTemplateMode element should be evaluated.
---
function XTemplateMode:Eval(parent, context)
	local dialog = GetParentOfKind(parent, "XDialog")
	assert(dialog)
	if dialog and (dialog.Mode == self.mode or MatchDialogMode(dialog.Mode, self.mode)) then
		return self:EvalChildren(parent, context)
	end
end


----- XTemplateLayer

DefineClass.XTemplateLayer = {
	__parents = { "XTemplateElementGroup" },
	properties = {
		{ category = "Layer", id = "layer", name = "Layer", editor = "choice", default = "", items = XTemplateCombo("XLayer", false) },
		{ category = "Layer", id = "layer_id", name = "Layer Id", editor = "text", default = "", },
		{ category = "Layer", id = "mode", name = "Mode", editor = "text", default = false, },
	},
	TreeView = T(177501851434, "Layer <layer><ConditionText> <color 0 128 0><comment>"),
	EditorName = "Layer",
}

---
--- Gathers the template properties for the XTemplateLayer object.
---
--- This function collects all the properties defined for the layer associated with the XTemplateLayer object, excluding any properties that are marked as `dont_save`.
---
--- @param properties table The initial list of properties to gather. If not provided, an empty table is used.
--- @return table The list of gathered template properties.
---
function XTemplateLayer:GatherTemplateProperties(properties)
	properties = properties or {}
	local layer_props = {}
	for _, prop_meta in ipairs(XLayer:GetProperties()) do
		layer_props[prop_meta.id] = true
	end
	local class = g_Classes[self.layer]
	for _, prop_meta in ipairs(class and class:GetProperties()) do
		if not layer_props[prop_meta.id] and not eval(prop_meta.dont_save, self, prop_meta) then
			properties[#properties + 1] = prop_meta
		end
	end
	return properties
end

---
--- Gets the properties of the XTemplateLayer object.
---
--- This function collects all the properties defined for the layer associated with the XTemplateLayer object, excluding any properties that are marked as `dont_save`.
---
--- @param self XTemplateLayer The XTemplateLayer object to get the properties for.
--- @return table The list of gathered template properties.
---
function XTemplateLayer:GetProperties()
	return self:GatherTemplateProperties(table.icopy(self.properties))
end

---
--- Sets the value of a property on the XTemplateLayer object.
---
--- This function allows setting the value of a property on the XTemplateLayer object. It uses `rawset` to directly set the property value, bypassing any metatable or other special handling.
---
--- @param self XTemplateLayer The XTemplateLayer object to set the property on.
--- @param id string The ID of the property to set.
--- @param value any The value to set the property to.
---
function XTemplateLayer:SetProperty(id, value)
	rawset(self, id, value)
end

---
--- Gets the value of a property on the XTemplateLayer object.
---
--- This function retrieves the value of a property on the XTemplateLayer object. If the property is defined on the XTemplateLayer object, its value is returned. Otherwise, the function attempts to retrieve the default property value from the class associated with the layer.
---
--- @param self XTemplateLayer The XTemplateLayer object to get the property from.
--- @param id string The ID of the property to get.
--- @return any The value of the requested property.
---
function XTemplateLayer:GetProperty(id)
	if self:HasMember(id) then
		return self[id]
	else
		local class = g_Classes[self.layer]
		return class and class:GetDefaultPropertyValue(id)
	end
end

---
--- Gets the default property value for the specified property ID on the XTemplateLayer object.
---
--- If the property ID is defined on the XTemplateLayer object, its value is returned. Otherwise, the function attempts to retrieve the default property value from the class associated with the layer.
---
--- @param self XTemplateLayer The XTemplateLayer object to get the default property value from.
--- @param id string The ID of the property to get the default value for.
--- @param prop_meta table The property metadata (optional).
--- @return any The default value of the requested property, or false if the property is not found.
---
function XTemplateLayer:GetDefaultPropertyValue(id, prop_meta)
	if XTemplateLayer:HasMember(id) then
		return XTemplateLayer[id]
	end
	local class = g_Classes[self.layer]
	return class and class:GetDefaultPropertyValue(id, prop_meta) or false
end

---
--- Evaluates the XTemplateLayer element and its children.
---
--- If the layer property is not empty, this function creates a new XOpenLayer object with the layer, layer_id, and mode properties from the XTemplateLayer object. It then passes the new XOpenLayer object as the parent to the EvalChildren function, which evaluates the children of the XTemplateLayer.
---
--- @param self XTemplateLayer The XTemplateLayer object to evaluate.
--- @param parent XOpenLayer The parent XOpenLayer object.
--- @param context table The context table.
--- @return any The result of evaluating the XTemplateLayer and its children.
---
function XTemplateLayer:EvalElement(parent, context)
	if self.layer ~= "" then
		parent = XOpenLayer:new({
			xtemplate = self,
			Layer = self.layer,
			LayerId = self.layer_id,
			Mode = self.mode,
		}, parent, context)
	end
	return self:EvalChildren(parent, context)
end


----- XTemplateAction

DefineClass.XTemplateAction = {
	__parents = { "XTemplateElement", "XAction" },
	properties = {
		{ category = "Template", id = "__condition", name = "Condition", editor = "expression", params = "parent, context", },
		{ category = "Template", id = "replace_matching_id", name = "Replace matching Id", editor = "bool", default = false, },
	},
	TreeView = T(187418329984, "Action<ConditionText> <color 128 128 128><ActionId> <color 200 128 128><ActionShortcut> <color 200 200 128><ActionShortcut2> <color 64 164 164><ActionGamepad><color 0 128 0><comment>"),
	EditorName = "Action",
}

---
--- Evaluates the condition for the XTemplateAction.
---
--- @param parent XOpenLayer The parent XOpenLayer object.
--- @param context table The context table.
--- @return boolean Whether the condition is true.
---
function XTemplateAction.__condition(parent, context)
	return true
end

---
--- Generates a string representation of the condition for the XTemplateAction.
---
--- If the condition is the same as the default condition in the class, an empty string is returned.
--- Otherwise, the condition is extracted from the function source and formatted for display.
--- The formatted condition includes the action mode (if set) and the condition expression.
---
--- @return string The formatted condition text.
---
function XTemplateAction:ConditionText()
	if self.__condition == g_Classes[self.class].__condition then
		return ""
	end

	-- get condition as a string
	local name, params, body = GetFuncSource(self.__condition)
	if type(body) == "table" then
		body = table.concat(body, "\n")
	end
	if body then
		body = body:match("^%s*return%s*(.*)") or body
		-- Put a space between < and numbers to avoid treating it like a tag
		body = string.gsub(body, "([%w%d])<(%d)", "%1< %2")
	end
	
	-- concat mode and condition
	local ret = self.ActionMode == "" and "" or "mode:" .. self.ActionMode
	if body then
		ret = (ret == "" and "" or ret .. " ") .. "cond:" .. body
	end
	return ret == "" and "" or " <color 128 128 220>" .. ret
end

local xaction_props = false

---
--- Evaluates the XTemplateAction and generates an action object.
---
--- @param parent XOpenLayer The parent XOpenLayer object.
--- @param context table The context table.
--- @return XAction The generated action object.
---
function XTemplateAction:Eval(parent, context)
	if not self.__condition(parent, context) then
		return
	end
	
	if not xaction_props then
		xaction_props = {}
		for _, prop_meta in ipairs(XAction:GetProperties()) do
			xaction_props[prop_meta.id] = true
		end
	end
		
	local action = {}
	for id, value in pairs(self) do
		if xaction_props[id] then
			action[id] = value
		end
	end
	
	local parent_action = ResolveValue(context, "__action")
	if parent_action then
		if not action.ActionMenubar then
			action.ActionMenubar = parent_action.ActionId
		end
		if not action.ActionMode or action.ActionMode == "" then
			action.ActionMode = parent_action.ActionMode
			self.InheritedActionModes = action.ActionMode
		else
			self.InheritedActionModes = ""
		end
		if not action.BindingsMenuCategory then
			action.BindingsMenuCategory = parent_action.BindingsMenuCategory
		end
	end
	action = XAction:new(action, parent, context, self.replace_matching_id)
	self:EvalChildren(parent, SubContext(context, { __action = action }))
	if IsKindOf(parent, "XButton") then
		parent:SetOnPressEffect("action")
		parent:SetOnPressParam(action.ActionId)
		if IsKindOf(parent, "XTextButton") then
			if parent.Text == "" then
				parent:SetText(action.ActionName)
			end
			if parent:GetIcon() == "" then
				parent:SetIcon(action.ActionIcon)
			end
		end
	end
	if parent_action and action.ActionState == XAction.ActionState and parent_action.ActionState ~= XAction.ActionState then
		action.ActionState = parent_action.ActionState
	end
	return action
end

--- Handles setting a property on an XTemplateAction instance.
---
--- This function is called when a property of an XTemplateAction is set. It delegates to the `XAction.OnXTemplateSetProperty` function to handle the property change.
---
--- @param prop_id string The ID of the property that was changed.
--- @param old_value any The previous value of the property.
function XTemplateAction:OnEditorSetProperty(prop_id, old_value)
	XAction.OnXTemplateSetProperty(self, prop_id, old_value)
end

--- Returns a warning message if the XTemplateAction's ActionSortKey is required but empty.
---
--- This function is called to get a warning message for the XTemplateAction instance. If the XTemplate that this action belongs to requires ActionSortKeys, and the ActionSortKey is empty, this function will return a warning message.
---
--- @return string|nil The warning message, or nil if no warning is needed.
function XTemplateAction:GetWarning()
	local preset = GetParentTableOfKind(self, "XTemplate")
	if preset.RequireActionSortKeys and self.ActionId ~= "" and self.ActionSortKey == "" then
		return "Sort keys are required for all Actions within this XTemplate."
	end
end

--- Called when a new XTemplateAction instance is created in the editor.
---
--- If the XTemplateAction is being pasted, this function clears the ActionSortKey to prevent duplicate sort keys.
---
--- @param parent XTemplateElement The parent element of the new XTemplateAction.
--- @param ged table The editor GUI element data.
--- @param is_paste boolean Whether the XTemplateAction is being pasted.
function XTemplateAction:OnEditorNew(parent, ged, is_paste)
	if is_paste then
		self:SetActionSortKey("") -- don't allow duplicated sort keys
	end
end


----- XTemplateForEach

DefineClass.XTemplateForEach = {
	__parents = { "XTemplateElement" },
	properties = {
		{ category = "Template", id = "array", name = "Array", editor = "expression", params = "parent, context", },
		{ category = "Template", id = "map", name = "Map array index", editor = "expression", params = "parent, context, array, i", help = "map(parent, context, array, i) - maps index to an item\nBy default returns array and array[i]", },
		{ category = "Template", id = "condition", name = "Condition", editor = "expression", params = "parent, context, item, i", help = "condition(parent, context, item, i) - returns whether the item should be processed\nBy default returns true", },
		{ category = "Template", id = "unique", name = "Unique items only", editor = "bool", default = false, },
		{ category = "Template", id = "item_in_context", name = "Store item in context field", editor = "text", default = "", },
		{ category = "Template", id = "__context", name = "Context", editor = "expression", params = "parent, context, item, i, n", },
		{ category = "Template", id = "run_before", name = "Run before", editor = "func", params = "parent, context, item, i, n, last", },
		{ category = "Template", id = "run_after", name = "Run after", editor = "func", params = "child, context, item, i, n, last", },
	},
	TreeView = T(633743132666, "For each <color 0 128 0><comment>"),
	EditorName = "For each",
}

--- Returns the context object.
---
--- This function is used as the default implementation for the `array` property of the `XTemplateForEach` class. It simply returns the `context` object passed to it.
---
--- @param parent XTemplateElement The parent element of the `XTemplateForEach` instance.
--- @param context table The current context object.
--- @return table The context object.
function XTemplateForEach.array(parent, context)
	return context
end

--- Maps the array index to an item.
---
--- This function is used as the default implementation for the `map` property of the `XTemplateForEach` class. It simply returns the array element at the specified index.
---
--- @param parent XTemplateElement The parent element of the `XTemplateForEach` instance.
--- @param context table The current context object.
--- @param array table The array to be iterated over.
--- @param i integer The current index in the array.
--- @return any The item at the specified index in the array.
function XTemplateForEach.map(parent, context, array, i)
	return array and array[i]
end

--- Returns whether the item should be processed.
---
--- This function is used as the default implementation for the `condition` property of the `XTemplateForEach` class. It simply returns `true`, indicating that all items should be processed.
---
--- @param parent XTemplateElement The parent element of the `XTemplateForEach` instance.
--- @param context table The current context object.
--- @param item any The current item being processed.
--- @param i integer The current index of the item in the array.
--- @return boolean Whether the item should be processed.
function XTemplateForEach.condition(parent, context, item, i)
	return true
end

--- Runs before the children of the `XTemplateForEach` instance are evaluated.
---
--- This function is used as the default implementation for the `run_before` property of the `XTemplateForEach` class. It is called before the children of the `XTemplateForEach` instance are evaluated for each item in the array.
---
--- @param parent XTemplateElement The parent element of the `XTemplateForEach` instance.
--- @param context table The current context object.
--- @param item any The current item being processed.
--- @param i integer The current index of the item in the array.
--- @param n integer The current iteration number.
--- @param last integer The last index in the array.
function XTemplateForEach.run_before(parent, context, item, i, n, last)
end

--- Runs after the children of the `XTemplateForEach` instance are evaluated.
---
--- This function is used as the default implementation for the `run_after` property of the `XTemplateForEach` class. It is called after the children of the `XTemplateForEach` instance are evaluated for each item in the array.
---
--- @param child XTemplateElement The child element of the `XTemplateForEach` instance.
--- @param context table The current context object.
--- @param item any The current item being processed.
--- @param i integer The current index of the item in the array.
--- @param n integer The current iteration number.
--- @param last integer The last index in the array.
function XTemplateForEach.run_after(child, context, item, i, n, last)
end

--- Returns the context object to be used for the current iteration of the `XTemplateForEach` instance.
---
--- This function is used as the default implementation for the `__context` property of the `XTemplateForEach` class. It simply returns the current context object, without any modifications.
---
--- @param child XTemplateElement The child element of the `XTemplateForEach` instance.
--- @param context table The current context object.
--- @param item any The current item being processed.
--- @param i integer The current index of the item in the array.
--- @param n integer The current iteration number.
--- @return table The context object to be used for the current iteration.
function XTemplateForEach.__context(child, context, item, i, n)
	return context
end

---
--- Evaluates the `XTemplateForEach` element and processes the items in the array.
---
--- This function is responsible for iterating over the items in the array specified by the `XTemplateForEach` element, and evaluating the child elements for each item. It handles the logic for checking the condition, storing the item in the context, and calling the `run_before` and `run_after` functions.
---
--- @param parent XTemplateElement The parent element of the `XTemplateForEach` instance.
--- @param context table The current context object.
function XTemplateForEach:Eval(parent, context)
	local array, first, last, step = self.array(parent, context)
	if (not first or not last) and type(array) ~= "table" then return end
	local n = 1
	local item_in_context = self.item_in_context
	local seen = self.unique and {}
	last = last or #array
	for i = first or 1, last, step or 1 do
		local item = self.map(parent, context, array, i)
		if (not seen or not seen[item]) and self.condition(parent, context, item, i) then
			if seen then seen[item] = true end
			if item_in_context ~= "" then
				context = SubContext(context, {[item_in_context] = item})
			end
			local sub_context = self.__context(parent, context, item, i, n)
			self.run_before(parent, sub_context, item, i, n, last)
			local child = self:EvalChildren(parent, sub_context)
			self.run_after(child, sub_context, item, i, n, last)
			n = n + 1
		end
	end
end


----- XTemplateForEachPreset

DefineClass.XTemplateForEachPreset = {
	__parents = { "XTemplateElement" },
	properties = {
		{ category = "Template", id = "preset", name = "Preset", editor = "choice", default = false, items = ClassDescendantsCombo("Preset"), },
		{ category = "Template", id = "condition", name = "Condition", editor = "expression", params = "parent, context, preset, group", help = "condition(parent, context, preset, group) - returns whether the item should be processed\nBy default returns true", },
		{ category = "Template", id = "item_in_context", name = "Store preset in context field", editor = "text", default = "", },
		{ category = "Template", id = "__context", name = "Context", editor = "expression", params = "parent, context, preset, group", },
		{ category = "Template", id = "run_before", name = "Run before", editor = "func", params = "parent, context, preset, group", },
		{ category = "Template", id = "run_after", name = "Run after", editor = "func", params = "child, context, preset, group", },
	},
	TreeView = T(713267586754, "For each preset <preset> <color 0 128 0><comment>"),
	EditorName = "For each preset",
}

---
--- Evaluates the condition for processing a preset in the `XTemplateForEachPreset` element.
---
--- This function is responsible for determining whether a preset should be processed or not. It is called for each preset in the array specified by the `XTemplateForEachPreset` element.
---
--- @param parent XTemplateElement The parent element of the `XTemplateForEachPreset` instance.
--- @param context table The current context object.
--- @param preset table The preset to be evaluated.
--- @param group string The group the preset belongs to.
--- @return boolean Whether the preset should be processed.
function XTemplateForEachPreset.condition(parent, context, preset, group)
	return true
end

---
--- Runs before the children of the `XTemplateForEachPreset` element are evaluated.
---
--- This function is called before the children of the `XTemplateForEachPreset` element are evaluated for a given preset. It can be used to perform any necessary setup or preparation before the child elements are processed.
---
--- @param parent XTemplateElement The parent element of the `XTemplateForEachPreset` instance.
--- @param context table The current context object.
--- @param preset table The preset being processed.
--- @param group string The group the preset belongs to.
function XTemplateForEachPreset.run_before(parent, context, preset, group)
end

---
--- Runs after the children of the `XTemplateForEachPreset` element have been evaluated.
---
--- This function is called after the children of the `XTemplateForEachPreset` element have been evaluated for a given preset. It can be used to perform any necessary cleanup or post-processing after the child elements have been processed.
---
--- @param child XTemplateElement The child element that was just evaluated.
--- @param context table The current context object.
--- @param preset table The preset that was just processed.
--- @param group string The group the preset belongs to.
function XTemplateForEachPreset.run_after(child, context, preset, group)
end

---
--- Returns the current context object.
---
--- This function is called by the `XTemplateForEachPreset` element to get the current context object. It simply returns the `context` parameter passed to it.
---
--- @param child XTemplateElement The child element that was just evaluated.
--- @param context table The current context object.
--- @param preset table The preset that was just processed.
--- @param group string The group the preset belongs to.
--- @return table The current context object.
function XTemplateForEachPreset.__context(child, context, preset, group)
	return context
end

---
--- Evaluates the `XTemplateForEachPreset` element, processing each preset in the array specified by the `XTemplateForEachPreset` element.
---
--- This function is responsible for iterating over the presets and evaluating the child elements of the `XTemplateForEachPreset` element for each preset that meets the condition specified by the `condition` function.
---
--- @param parent XTemplateElement The parent element of the `XTemplateForEachPreset` instance.
--- @param context table The current context object.
function XTemplateForEachPreset:Eval(parent, context)
	local preset = g_Classes[self.preset]
	if not preset then return end
	ForEachPreset(preset.PresetClass or preset.class, function(preset, group, parent, context, item_in_context)
		if self.condition(parent, context, preset, group) then
			if item_in_context ~= "" then
				context = SubContext(context, {[item_in_context] = preset})
			end
			local sub_context = self.__context(parent, context, preset, group)
			self.run_before(parent, sub_context, preset, group)
			local child = self:EvalChildren(parent, sub_context)
			self.run_after(child, sub_context, preset, group)
		end
	end, parent, context, self.item_in_context)
end


----- XTemplateForEachAction

DefineClass.XTemplateForEachAction = {
	__parents = { "XTemplateElement" },
	properties = {
		{ category = "Template", id = "menubar", name = "Menubar", editor = "text", default = "", },
		{ category = "Template", id = "toolbar", name = "Toolbar", editor = "text", default = "", },
		{ category = "Template", id = "condition", name = "Condition", editor = "expression", params = "parent, context, action, i", help = "condition(parent, context, action, i) - returns whether the action should be processed\nBy default returns true", },
		{ category = "Template", id = "__context", name = "Context", editor = "expression", params = "parent, context, action, n", },
		{ category = "Template", id = "run_after", name = "Run after", editor = "func", params = "child, context, action, n", },
	},
	TreeView = T(584735601325, "For each action <toolbar><menubar> <color 0 128 0><comment>"),
	EditorName = "For each action",
}

--- Determines whether the current action should be processed.
---
--- @param parent XTemplateElement The parent element of the `XTemplateForEachAction` instance.
--- @param context table The current context object.
--- @param action table The current action being processed.
--- @param i integer The index of the current action in the actions array.
--- @return boolean Whether the current action should be processed.
function XTemplateForEachAction.condition(parent, context, action, i)
	return true
end

---
--- Returns the current context object.
---
--- @param child XTemplateElement The child element of the `XTemplateForEachAction` instance.
--- @param context table The current context object.
--- @param action table The current action being processed.
--- @param n integer The index of the current action in the actions array.
--- @return table The current context object.
function XTemplateForEachAction.__context(child, context, action, n)
	return context
end

---
--- Runs after the child element of the `XTemplateForEachAction` instance has been evaluated.
---
--- @param child XTemplateElement The child element of the `XTemplateForEachAction` instance.
--- @param context table The current context object.
--- @param action table The current action being processed.
--- @param n integer The index of the current action in the actions array.
function XTemplateForEachAction.run_after(child, context, action, n)
end

---
--- Evaluates the `XTemplateForEachAction` element, processing each action in the host's actions array.
---
--- @param parent XTemplateElement The parent element of the `XTemplateForEachAction` instance.
--- @param context table The current context object.
function XTemplateForEachAction:Eval(parent, context)
	local host = GetActionsHost(parent, true)
	local array = host and host:GetActions()
	if #(array or "") == 0 then return end
	local toolbar = self.toolbar
	local menubar = self.menubar
	local n = 1
	for i, action in ipairs(array) do
		if (toolbar == "" or toolbar == action.ActionToolbar)
			and (menubar == "" or menubar == action.ActionMenubar)
			and host:FilterAction(action)
			and self.condition(parent, context, action, i)
		then
			local sub_context = self.__context(parent, context, action, n)
			local child = self:EvalChildren(parent, sub_context)
			self.run_after(child, sub_context, action, n)
			n = n + 1
		end
	end
end


----- XTemplateInterpolation / XTemplateIntAlpha / XTemplateIntRect

DefineClass.XTemplateInterpolation = {
	__parents = { "XTemplateElement", },
	properties = {
		{ id = "interpolation_id", name = "Interpolation id", 
			editor = "text", default = "", max_lines = 1, },
		{ id = "inverse", name = "Inverse", 
			editor = "bool", default = false, },
		{ id = "looping", name = "Looping", 
			editor = "bool", default = false, },
		{ id = "ping_pong", name = "Ping-pong", 
			editor = "bool", default = false, },
		{ id = "game_time", name = "Game time", 
			editor = "bool", default = true, },
		{ id = "autoremove", name = "Auto remove", 
			editor = "bool", default = false, },
		{ id = "easing", name = "Easing", 
			editor = "choice", default = false, items = function (self) return GetEasingCombo() end, },
		{ id = "start", name = "Start offset", 
			editor = "number", default = 0, scale = "sec", step = 1000, },
		{ id = "duration", name = "Duration", 
			editor = "number", default = 1000, scale = "sec", step = 1000, },
	},
	ContainerClass = "",
	EditorName = "Interpolation",
}

---
--- Evaluates the interpolation defined by the `XTemplateInterpolation` class and adds it to the parent object.
---
--- @param parent table The parent object that the interpolation will be added to.
--- @param context table The context object that will be used to evaluate the interpolation.
---
function XTemplateInterpolation:Eval(parent, context)
	local interpolation = {
		id = self.interpolation_id ~= "" and self.interpolation_id or nil,
		autoremove = self.autoremove or nil,
		easing = self.easing ~= "" and self.easing or nil,
		flags = (self.inverse and const.intfInverse or 0)
			| (self.looping and const.intfLooping or 0)
			| (self.ping_pong and const.intfPingPong or 0)
			| (self.game_time and const.intfGameTime or 0),
		duration = self.duration,
		start = (self.game_time and GameTime() or GetPreciseTicks()) + self.start,
	}
	interpolation = self:GetInterpolation(interpolation, parent, context)
	if interpolation then
		parent:AddInterpolation(interpolation)
	end
end

---
--- Evaluates the interpolation defined by the `XTemplateInterpolation` class and adds it to the parent object.
---
--- @param interpolation table The interpolation object to be evaluated and added to the parent.
--- @param parent table The parent object that the interpolation will be added to.
--- @param context table The context object that will be used to evaluate the interpolation.
--- @return table The evaluated interpolation object, or `nil` if it could not be added.
---
function XTemplateInterpolation:GetInterpolation(interpolation, parent, context)
	return interpolation
end


DefineClass.XTemplateIntAlpha = {
	__parents = { "XTemplateInterpolation", },
	properties = {
		{ id = "alpha_start", name = "Alpha start", 
			editor = "number", default = 0, },
		{ id = "alpha_end", name = "Alpha end", 
			editor = "number", default = 255, },
	},
	TreeView = Untranslated("Interpolate opacity <alpha_start> -> <alpha_end> for <FormatScale(duration,'sec')> <color 0 128 0><comment>"),
	EditorName = "Interpolate opacity",
}

---
--- Evaluates the interpolation defined by the `XTemplateIntAlpha` class and adds it to the parent object.
---
--- @param interpolation table The interpolation object to be evaluated and added to the parent.
--- @param parent table The parent object that the interpolation will be added to.
--- @param context table The context object that will be used to evaluate the interpolation.
--- @return table The evaluated interpolation object, or `nil` if it could not be added.
---
function XTemplateIntAlpha:GetInterpolation(interpolation, parent, context)
	interpolation.type = const.intAlpha
	interpolation.startValue = self.alpha_start
	interpolation.endValue = self.alpha_end
	return interpolation
end


DefineClass.XTemplateIntRect = {
	__parents = { "XTemplateInterpolation", },
	properties = {
		{ id = "original", name = "Original box", 
			editor = "rect", default = box(0, 0, 1000, 1000), },
		{ id = "target", name = "Target box", 
			editor = "rect", default = box(0, 0, 1000, 1000), },
	},
	TreeView = Untranslated("Interpolate box for <FormatScale(duration,'sec')> <color 0 128 0><comment>"),
	EditorName = "Interpolate box",
}

---
--- Evaluates the interpolation defined by the `XTemplateIntRect` class and adds it to the parent object.
---
--- @param interpolation table The interpolation object to be evaluated and added to the parent.
--- @param parent table The parent object that the interpolation will be added to.
--- @param context table The context object that will be used to evaluate the interpolation.
--- @return table The evaluated interpolation object, or `nil` if it could not be added.
---
function XTemplateIntRect:GetInterpolation(interpolation, parent, context)
	interpolation.type = const.intRect
	interpolation.originalRect = self.original
	interpolation.targetRect = self.target
	return interpolation
end


----- XTemplateThread

DefineClass.XTemplateThread = {
	__parents = { "XTemplateElement", },
	properties = {
		{ id = "thread_name", name = "Thread name", 
			editor = "text", default = "", max_lines = 1, },
		{ id = "InParentDlg", name = "Create in Dialog parent", 
			editor = "bool", default = true, },
		{ id = "CloseOnFinish", name = "Close thread owner at the end", 
			editor = "bool", default = false, },
	},
	TreeView = Untranslated("<color 75 105 198><if(InParentDlg)>Dialog </if>Thread <thread_name><if(CloseOnFinish)> [Close]</if> <color 0 128 0><comment>"),
	EditorName = "Thread",
}

---
--- Evaluates the XTemplateThread class and creates a new thread to execute the elements within it.
---
--- @param parent table The parent object that the thread will be created in.
--- @param context table The context object that will be used to evaluate the thread elements.
---
function XTemplateThread:Eval(parent, context)
	local thread_name = self.thread_name == "" and self or self.thread_name
	local thread_win = self.InParentDlg and GetParentOfKind(parent, "XDialog") or parent
	thread_win:CreateThread(thread_name, function(self, parent, context, to_close)
		for i, element in ipairs(self) do
			local ok, result = sprocall(element.Eval, element, parent, context)
			if IsKindOf(result, "XWindow") and result.window_state == "new" then
				result:Open()
			end
		end
		if to_close then to_close:Close() end
	end, self, parent, context, self.CloseOnFinish and thread_win)
end


DefineClass.XTemplateThreadElement = {
	__parents = { "XTemplateElement", },
	ContainerClass = "",
}

DefineClass.XTemplateSleep = {
	__parents = { "XTemplateThreadElement", },
	properties = {
		{ id = "Time", 
			editor = "number", default = 1000, scale = "sec", },
	},
	TreeView = Untranslated("Sleep <Time> <color 0 128 0><comment>"),
	EditorName = "Sleep",
}

---
--- Evaluates the XTemplateSleep class and puts the current thread to sleep for the specified time.
---
--- @param parent table The parent object that the thread will be created in.
--- @param context table The context object that will be used to evaluate the thread elements.
---
function XTemplateSleep:Eval(parent, context)
	Sleep(self.Time)
end


----- XTemplateMoment / XTemplateWaitMoment

DefineClass.XTemplateMoment = {
	__parents = { "XTemplateThreadElement", },
	properties = {
		{ id = "moment", name = "Moment", 
			editor = "text", default = "", max_lines = 1, },
	},
	TreeView = Untranslated("Moment <color 0 255 255><u(moment)> <color 0 128 0><comment>"),
	EditorName = "Moment",
}

---
--- Evaluates the XTemplateMoment class and marks the specified moment as passed in the parent object.
---
--- @param parent table The parent object that the moment will be marked in.
--- @param context table The context object that will be used to evaluate the thread elements.
---
function XTemplateMoment:Eval(parent, context)
	parent = GetParentOfKind(parent, "XDialog") or parent
	if parent then 
		rawset(parent, "moments", rawget(parent, "moments") or {})
		parent.moments[self.moment] = RealTime() -- mark the moment as passed
	end
	Msg("Moment:" .. self.moment)
end


DefineClass.XTemplateWaitMoment = {
	__parents = { "XTemplateThreadElement", },
	properties = {
		{ id = "moment", name = "Moment", 
			editor = "text", default = "", max_lines = 1, },
		{ id = "timeout", name = "Timeout", 
			editor = "number", default = false, },
	},
	TreeView = Untranslated("Wait moment <color 0 255 255><u(moment)> <color 0 128 0><comment>"),
	EditorName = "Wait moment",
}

---
--- Evaluates the XTemplateWaitMoment class and waits for the specified moment to be marked as passed in the parent object.
---
--- @param parent table The parent object that the moment will be waited for.
--- @param context table The context object that will be used to evaluate the thread elements.
---
--- If the moment has already been marked as passed, this function will return immediately.
--- Otherwise, it will wait for the moment to be marked as passed, or until the specified timeout is reached.
---
function XTemplateWaitMoment:Eval(parent, context)
	parent = GetParentOfKind(parent, "XDialog") or parent
	local moments = parent and parent.moments
	if moments and moments[self.moment] then return end -- the moment has already passed
	WaitMsg("Moment:" .. self.moment, self.timeout)
end


----- XTemplateSound / XTemplateStopSound

DefineClass.XTemplateSound = {
	__parents = { "XTemplateThreadElement", },
	properties = {
		{ id = "Sample", 
			editor = "browse", default = false, folder = "Sounds", filter = "Sound file(*.*)|*.*", },
		{ id = "Type", 
			editor = "preset_id", default = "UI", preset_class = "SoundTypePreset", },
		{ id = "Volume", 
			editor = "number", default = 1000, min = 0, max = 1000, },
		{ id = "DelayBefore", name = "Delay before", 
			editor = "number", default = 0, scale = "sec", min = 0, },
		{ id = "FadeIn", name = "Fade in", 
			editor = "number", default = 0, scale = "sec", min = 0, },
		{ id = "DelayAfter", name = "Delay after", help = "This can be negative", 
			editor = "number", default = 0, scale = "sec", },
	},
	TreeView = Untranslated("Sound <u(Sample)> <color 0 128 0><comment>"),
	EditorName = "Sound",
}

---
--- Evaluates the XTemplateSound class and plays the specified sound.
---
--- @param parent table The parent object that the sound will be played for.
--- @param context table The context object that will be used to evaluate the thread elements.
---
--- This function will first wait for the specified delay before playing the sound.
--- It will then play the sound with the specified sample, type, volume, and fade-in duration.
--- If the parent object has a "playing_sounds" table, the sound handle will be stored in it.
--- Finally, the function will wait for the duration of the sound, plus any specified delay after.
---
function XTemplateSound:Eval(parent, context)
	Sleep(self.DelayBefore)
	parent = GetParentOfKind(parent, "XDialog") or parent
	local handle = PlaySound(self.Sample, self.Type, self.Volume, self.FadeIn)
	if parent then
		rawset(parent, "playing_sounds", rawget(parent, "playing_sounds") or {})
		parent.playing_sounds[self.Sample] = handle
	end
	Sleep(GetSoundDuration(handle))
	Sleep(self.DelayAfter)
end

DefineClass.XTemplateStopSound = {
	__parents = { "XTemplateThreadElement", },
	properties = {
		{ id = "Sample", 
			editor = "browse", default = false, folder = "Sounds", filter = "Sound file(*.*)|*.*", },
		{ id = "FadeOut", name = "Fade out", help = "This time is not included in the duration of StopSound.", 
			editor = "number", default = 0, scale = "sec", min = 0, },
	},
	TreeView = Untranslated("Stop sound <u(Sample)> <color 0 128 0><comment>"),
	EditorName = "Stop sound",
}

---
--- Stops a sound that was previously played using the `XTemplateSound:Eval()` function.
---
--- @param parent table The parent object that the sound was played for.
--- @param context table The context object that was used to evaluate the thread elements.
---
--- This function will first get the parent object of the specified `XDialog` type, or use the parent object directly if it is not an `XDialog`.
--- It will then get the "playing_sounds" table from the parent object, which stores the sound handles for sounds that were played.
--- If a sound handle is found for the specified sample, the function will fade out the sound using the specified `FadeOut` duration.
---
function XTemplateStopSound:Eval(parent, context)
	parent = GetParentOfKind(parent, "XDialog") or parent
	local playing_sounds = parent and rawget(parent, "playing_sounds")
	local handle = playing_sounds and playing_sounds[self.Sample] or -1
	if handle ~= -1 then
		SetSoundVolume(handle, -1, self.FadeOut)
	end
end


----- XTemplateConditionList

DefineClass.XTemplateConditionList = {
	__parents = { "XTemplateElement", },
	properties = {
		{ category = "Template", id = "conditions", name = "Conditions", 
			editor = "nested_list", default = false, base_class = "Condition", },
	},
	TreeView = Untranslated("Condition list <color 0 128 0><comment>"),
	EditorName = "Condition list",
}

---
--- Evaluates the condition list and executes the child elements if the conditions are met.
---
--- @param parent table The parent object that the condition list is being evaluated for.
--- @param context table The context object that is used to evaluate the conditions and child elements.
---
--- This function first evaluates the conditions in the `conditions` property using the `EvalConditionList` function. If the conditions are met, it then iterates through the child elements of the `XTemplateConditionList` and evaluates each one using the `Eval` function.
---
function XTemplateConditionList:Eval(parent, context)
	if EvalConditionList(self.conditions, context) then
		for i, element in ipairs(self) do
			element:Eval(parent, context)
		end
	end
end


----- XTemplateSlide

DefineClass.XTemplateSlide = {
	__parents = { "XTemplateElement", },
	properties = {
		{ id = "slide_id", name = "Slide id", 
			editor = "text", default = "SLIDE", },
		{ id = "transition", name = "Transition", 
			editor = "choice", default = "", items = function (self) return table.keys2(SlideTransitions, true, "") end, },
		{ id = "transition_time", name = "Transition time", 
			editor = "number", default = 0, no_edit = function(self) return self.__transition == "" end, scale = "sec", min = 0, },
		{ id = "transition_easing", name = "Transition easing", 
			editor = "choice", default = false, items = function (self) return GetEasingCombo() end, },
	},
	TreeView = Untranslated("<slide_id><if(transition)> transition <transition> <FormatScale(transition_time,'sec')></if> <color 0 128 0><comment>"),
	EditorName = "Slide",
}

---
--- Evaluates the slide and handles the transition between the current slide and the new slide.
---
--- @param parent table The parent object that the slide is being evaluated for.
--- @param context table The context object that is used to evaluate the slide and its transition.
---
--- This function first resolves the current slide using the `slide_id` property. If a current slide exists, it sets the `id` property to an empty string. It then evaluates the children of the slide using the `EvalChildren` function and assigns the resulting slide object the `slide_id` property. If a slide object is returned, it opens the slide and applies the specified transition, if any. If a current slide exists, it deletes the old slide.
---
function XTemplateSlide:Eval(parent, context)
	local old_slide = parent:ResolveId(self.slide_id)
	if old_slide then old_slide:SetId("") end
	local slide = self:EvalChildren(parent, context)
	if slide then
		slide:SetId(self.slide_id)
		slide:Open()
		local transition = SlideTransitions[self.transition]
		if transition then 
			transition(slide, old_slide, self.transition_time, self.transition_easing or nil)
		end
	end
	if old_slide then old_slide:delete() end
end

local box100 = box(0, 0, 100, 100)
SlideTransitions = {
	["Fade in"] = function (win, old_win, time, easing)
		win:AddInterpolation{
			type = const.intAlpha,
			startValue = 0,
			endValue = 255,
			duration = time,
			easing = easing,
		}
		Sleep(time)
	end,
	["Fade-to-black"] = function (win, old_win, time, easing)
		-- add a black window on top and fade it in and out
		local black_win = XWindow:new({
			ZOrder = -10000,
			Dock = "box",
			DrawOnTop = true,
			Background = RGB(0,0,0),
		}, win.parent)
		black_win:Open()
		local int = black_win:AddInterpolation{
			id = "fade-to-black",
			type = const.intAlpha,
			startValue = 0,
			endValue = 255,
			duration = time / 2,
			easing = easing,
		}
		win:SetVisible(false)
		Sleep(time / 2)
		win:SetVisible(true)
		int.start = nil
		int.flags = const.intfInverse
		black_win:AddInterpolation(int)
		Sleep(time / 2)
		black_win:Close()
	end,
	["Push left"] = function (win, old_win, time, easing)
		local rect = old_win and old_win.box or win.parent.box
		local offset = rect and rect:sizex() or 1000
		if old_win then
			old_win:AddInterpolation{
				type = const.intRect,
				originalRect = box100,
				targetRect = box(-offset, 0, -offset + 100, 100),
				duration = time,
				easing = easing,
			}
		end
		win:AddInterpolation{
			type = const.intRect,
			originalRect = box100,
			targetRect = box(offset, 0, offset + 100, 100),
			duration = time,
			easing = easing,
			flags = const.intfInverse,
			autoremove = true,
			no_invalidate_on_remove = true,
		}
		Sleep(time)
	end,
}


----- XTemplateVoice

DefineClass.XTemplateVoice = {
	__parents = { "XTemplateThreadElement", },
	properties = {
		{ id = "TimeBefore", name = "Time before", 
			editor = "number", default = 0, scale = "sec", },
		{ id = "TimeAfter", name = "Time after", 
			editor = "number", default = 0, scale = "sec", },
		{ id = "TimeAdd", name = "Additional time", 
			editor = "number", default = 0, scale = "sec", },
		{ id = "Actor", name = "Actor", 
			editor = "choice", default = false, items = function (self) return VoiceActors end, },
		{ id = "Volume", name = "Volume", 
			editor = "number", default = 1000, slider = true, min = 0, max = 1000, },
		{ id = "Text", name = "Text", 
			editor = "text", default = "", 
			context = VoicedContextFromField("Actor"), translate = true, lines = 3, max_lines = 10, },
		{ id = "TextId", name = "Text control id", 
			editor = "text", default = "TEXT", max_lines = 1, },
		{ id = "ShowText", name = "Show text", 
			editor = "choice", default = "Always", items = function (self) return {"Always", "Hide", "If subtitles option is enabled" } end, },
	},
	TreeView = Untranslated("<TextId> <if(Actor)><Actor>: </if><Text>"),
	EditorName = "Voiceover",
	SoundType = "Voiceover",
}

--- Returns the text and actor for the voice over.
---
--- @return string text The text to be spoken.
--- @return string actor The actor who will speak the text.
function XTemplateVoice:GetTextActor()
	return self.Text, self.Actor
end

---
--- Evaluates an XTemplateVoice object and plays the associated voice over.
---
--- @param parent table The parent object for the voice over.
--- @param context table The context for the voice over.
--- @return nil
function XTemplateVoice:Eval(parent, context)
	local text, actor = self:GetTextActor()
	local voice = VoiceSampleByText(text, actor)
	
	Sleep(self.TimeBefore)
	
	local text_control = parent:ResolveId(self.TextId)
	if text_control then
		if self.ShowText == "Always" then
			text_control:SetVisible(true)
		elseif self.ShowText == "Hide" then
			text_control:SetVisible(false)
		else
			text_control:SetVisible(GetAccountStorageOptionValue("Subtitles"))
		end
		if text_control:GetVisible() then
			text_control:SetText(text or "")
		end
	end
	
	local handle = voice and PlaySound(voice, self.SoundType, self.Volume)
	local duration = GetSoundDuration(handle or voice)
	if not duration or duration <= 0 then
		duration = 1000 + #_InternalTranslate(text, text_control and text_control.context) * 50
	end
	
	local dialog = GetParentOfKind(parent, "XDialog") or parent
	if dialog and handle then
		rawset(dialog, "playing_sounds", rawget(dialog, "playing_sounds") or {})
		dialog.playing_sounds[voice] = handle
	end
	
	Sleep(duration + self.TimeAdd)
	
	if dialog and handle then
		dialog.playing_sounds[voice] = nil
	end
	
	if text_control then
		text_control:SetVisible(false)
	end
	
	Sleep(self.TimeAfter)
end


----- globals

--- Spawns an XTemplate or a class based on the provided template_or_class parameter.
---
--- @param template_or_class string The name of the XTemplate or class to spawn.
--- @param parent table The parent object to attach the spawned template or class to.
--- @param context table The context to pass to the spawned template or class.
--- @return table The spawned template or class instance.
function XTemplateSpawn(template_or_class, parent, context)
	parent = parent or terminal.desktop
	local template = XTemplates[template_or_class]
	if template then
		return template:Eval(parent, context)
	end
	local class = g_Classes[template_or_class]
	if class then
		return class:new({}, parent, context)
	end
	assert(false, "XTemplate or class not found: " .. tostring(template_or_class))
end

--- Loads all XTemplate presets from various directories.
---
--- This function is responsible for loading all the XTemplate presets from different directories on the file system. It first initializes the `Presets.XTemplate` and `XTemplates` tables, then loads the preset files from various directories using the `LoadPresetFiles` function. After loading the presets, it sorts them using the `XTemplate:SortPresets()` function, and then calls the `PostLoad()` method on each preset. Finally, if the platform is in developer mode and not in the Ged environment, it loads the collapsed preset groups using the `LoadCollapsedPresetGroups()` function.
---
--- @return nil
function LoadXTemplates()
	Presets.XTemplate = {}
	XTemplates = {}
	LoadPresetFiles("Lua/Ged/XTemplates/")
	LoadPresetFiles("CommonLua/Ged/XTemplates/")
	LoadPresetFiles("CommonLua/X/XTemplates/")
	if not Platform.ged then
		ForEachLib("XTemplates/", function(lib, path) LoadPresetFiles(path) end)
		LoadPresetFiles("Lua/XTemplates/")
	end
	XTemplate:SortPresets()
	for _, group in ipairs(Presets.XTemplate) do
		for _, preset in ipairs(group) do
			preset:PostLoad()
		end
	end
	if Platform.developer and not Platform.ged then
		LoadCollapsedPresetGroups()
	end
end

if FirstLoad or ReloadForDlc then
	function OnMsg.ClassesBuilt()
		LoadXTemplates()
	end
end

--- Returns a status text indicating if the UI scale is not 100%.
---
--- This function checks the scale of the terminal.desktop object and returns a status text if the scale is not 100% (1000, 1000). If the scale is 100%, an empty string is returned.
---
--- @return string The status text indicating the UI scale, or an empty string if the scale is 100%.
function XTemplate:GetPresetStatusText()
	local scale = terminal.desktop.scale
	if scale:x() ~= 1000 or scale:y() ~= 1000 then
		return "UIScale is not 100%"
	end
	return ""
end