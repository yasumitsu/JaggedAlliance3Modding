
DefineClass.XDef = {
	__parents = { "Preset", "XDefWindow", },
	properties = {
		{ category = "Preset", id = "__class", name = "Class", editor = "choice", default = "XWindow", show_recent_items = 7, items = function(self) return ClassDescendantsCombo("XWindow", true) end, },
		{ category = "Preset", id = "DefUndefineClass", name = "Undefine class", editor = "bool", default = false, },
	},
	GlobalMap = "XDefs",
	
	ContainerClass = "XDefSubItem",
	PresetClass = "XDef",
	HasCompanionFile = true,
	GeneratesClass = true,
	HasSortKey = true,
	SingleFile = false,
	
	EditorMenubarName = "XDef Editor",
	EditorShortcut = "Alt-Shift-F3",
	EditorName = "XDef",
	EditorMenubar = "Editors.UI",
	EditorIcon = "CommonAssets/UI/Icons/backspace.png",
}

--- Generates the companion file code for an XDef object.
---
--- @param code table The code table to append the generated code to.
--- @param dlc string The DLC name (optional).
--- @return string An error message if the class already exists in the global namespace, otherwise nil.
function XDef:GenerateCompanionFileCode(code, dlc)
	local class_exists_err = self:CheckIfIdExistsInGlobal()
	if class_exists_err then
		return class_exists_err
	end
	if self.DefUndefineClass then
		code:append("UndefineClass('", self.id, "')\n")
	end
	code:appendf("DefineClass.%s = {\n", self.id, self.id)
	self:GenerateParents(code)
	self:AppendGeneratedByProps(code)
	self:GenerateFlags(code)
	self:GenerateConsts(code, dlc)
	code:append("}\n\n")
	self:GenerateGlobalCode(code)
end

DefineClass.XDefSubItem = {
	__parents = { "Container" },
	properties = {
		{ category = "Def", id = "comment", name = "Comment", editor = "text", default = "", },
	},
	TreeView = T(357198499972, "<class> <color 0 128 0><comment>"),
	EditorView = Untranslated("<TreeView>"),
	EditorName = "Sub Item",
	ContainerClass = "XDefSubItem",
}

DefineClass.XDefGroup = {
	__parents = { "XDefSubItem" },
	properties = {
		{ category = "Def", id = "__context_of_kind", name = "Require context of kind", editor = "text", default = "" },
		{ category = "Def", id = "__context", name = "Context expression", editor = "expression", params = "parent, context" },
		{ category = "Def", id = "__parent", name = "Parent expression", editor = "expression", params = "parent, context" },
		{ category = "Def", id = "__condition", name = "Condition", editor = "expression", params = "parent, context", },
	},
	TreeView = T(551379353577, "Group<ConditionText> <color 0 128 0><comment>"),
	EditorName = "Group",
}

---
--- Returns the parent of the current XDefGroup.
---
--- @param parent table The parent of the current XDefGroup.
--- @param context table The current context.
--- @return table The parent of the current XDefGroup.
function XDefGroup.__parent(parent, context)
	return parent
end

---
--- Returns the current context.
---
--- @param parent table The parent of the current XDefGroup.
--- @param context table The current context.
--- @return table The current context.
function XDefGroup.__context(parent, context)
	return context
end

---
--- Evaluates the condition for the current XDefGroup.
---
--- @param parent table The parent of the current XDefGroup.
--- @param context table The current context.
--- @return boolean True if the condition is met, false otherwise.
function XDefGroup.__condition(parent, context)
	return true
end

---
--- Returns the condition text for the current XDefGroup.
---
--- @return string The condition text for the current XDefGroup.
function XDefGroup:ConditionText()
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

-- function XDefGroup:Eval(parent, context)
-- 	local kind = self.__context_of_kind
-- 	if kind == "" 
-- 		or type(context) == kind
-- 		or IsKindOf(context, kind)
-- 		or (IsKindOf(context, "Context") and context:IsKindOf(kind)) 
-- 	then
-- 		context = self.__context(parent, context)
-- 		parent = self.__parent(parent, context)
-- 		if not self.__condition(parent, context) then
-- 			return
-- 		end
-- 		return self:EvalElement(parent, context)
-- 	end
-- end

-- function XDefGroup:EvalElement(parent, context)
-- 	return self:EvalChildren(parent, context)
-- end

DefineClass.XDefWindow = {
	__parents = { "PropertyObject" },
	properties = {
		{ category = "Def", id = "__class", name = "Class", editor = "choice", default = "XWindow", show_recent_items = 7,
			items = function() return ClassDescendantsCombo("XWindow", true) end, },
	},
}

---
--- Returns the property tabs for the XDefWindow.
---
--- @return table The property tabs for the XDefWindow.
function XDefWindow:GetPropertyTabs()
	return XWindowPropertyTabs
end

local eval = prop_eval
---
--- Returns the properties of the XDefWindow object, including any properties defined in the class hierarchy.
---
--- @return table The properties of the XDefWindow object.
function XDefWindow:GetProperties()
	--bp()
	local properties = table.icopy(self.properties)
	local class = g_Classes[self.__class]
	for _, prop_meta in ipairs(class and class:GetProperties()) do
		if not eval(prop_meta.dont_save, self, prop_meta) then
			properties[#properties + 1] = prop_meta
		end
	end
	return properties
end

local modified_base_props = {}

---
--- Sets the property of the XDefWindow object with the given ID to the specified value.
--- This function also clears the modified_base_props table for this object, indicating that the
--- properties have been updated.
---
--- @param id string The ID of the property to set.
--- @param value any The value to set the property to.
function XDefWindow:SetProperty(id, value)
	rawset(self, id, value)
	modified_base_props[self] = nil
end

---
--- Returns the property of the XDefWindow object with the given ID.
--- If the property is not found on the object, it will attempt to retrieve the default value for the property from the class.
---
--- @param id string The ID of the property to retrieve.
--- @return any The value of the property, or the default value if the property is not found.
function XDefWindow:GetProperty(id)
	local prop = PropertyObject.GetProperty(self, id)
	if prop then
		return prop
	else
		local class = g_Classes[self.__class]
		return class and class:GetDefaultPropertyValue(id)
	end
end

---
--- Returns the default property value for the given property ID on the XDefWindow object.
--- If the property is not found on the object, it will attempt to retrieve the default value for the property from the class.
---
--- @param id string The ID of the property to retrieve the default value for.
--- @param prop_meta table The metadata for the property.
--- @return any The default value of the property, or false if the property is not found.
function XDefWindow:GetDefaultPropertyValue(id, prop_meta)
	local prop_default = PropertyObject.GetDefaultPropertyValue(self, id, prop_meta)
	if prop_default then
		return prop_default
	end
	local class = g_Classes[self.__class]
	return class and class:GetDefaultPropertyValue(id, prop_meta) or false
end

-- function XDefWindow:EvalElement(parent, context)
-- 	local class = g_Classes[self.__class]
-- 	assert(class, self.class .. " class not found")
-- 	if not class then return end
-- 	local obj = class:new({}, parent, context, self)
	
-- 	local props = modified_base_props[self]
-- 	if not props then
-- 		props = GetPropsToCopy(self, obj:GetProperties())
-- 		modified_base_props[self] = props
-- 	end
	
-- 	for _, entry in ipairs(props) do
-- 		local id, value = entry[1], entry[2]
-- 		if type(value) == "table" and not IsT(value) then
-- 			value = table.copy(value, "deep")
-- 		end
-- 		obj:SetProperty(id, value)
-- 	end
-- 	self:EvalChildren(obj, context)
-- 	return obj
-- end

-- TODO: Check if an OnXDefSetProperty method is necessary 
---
--- Called when a property of the XDefWindow is set in the editor.
---
--- @param prop_id string The ID of the property that was set.
--- @param old_value any The previous value of the property.
---
function XDefWindow:OnEditorSetProperty(prop_id, old_value)
	-- local class = g_Classes[self.__class]
	-- if class and class:HasMember("OnXTemplateSetProperty") then
	-- 	class.OnXTemplateSetProperty(self, prop_id, old_value)
	-- end
end

---
--- Checks for errors in the XDefWindow object.
---
--- If the XDefWindow is an instance of `XContentTemplate`, this function checks if the `RespawnOnContext` and `ContextUpdateOnOpen` properties are both true, which would cause the children to be opened twice.
---
--- If the XDefWindow is an instance of `XEditableText`, this function checks if both the `Translate` and `UserText` properties are set, which is not allowed.
---
--- @return string|nil The error message if an error is found, otherwise `nil`.
function XDefWindow:GetError()
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

DefineClass.XDefWindowSubItem = {
	__parents = { "XDefWindow", "XDefGroup", },
	TreeView = T(700510148795, "<IdNodeColor><__class><ConditionText><opt(PlacementText,' <color 128 128 128>','')><opt(comment,' <color 0 128 0>')>"),
	EditorName = "Window",
}

---
--- Determines the color of the ID node for the XDefWindowSubItem.
---
--- If the `IdNode` property is `false` or `nil` and the `IdNode` property is not defined for the class, an empty string is returned.
---
--- If any child of the XDefWindowSubItem is an instance of `XDefGroup`, the color `<color 75 105 198>` is returned.
---
--- Otherwise, an empty string is returned.
---
--- @return string The color of the ID node, or an empty string if no color is applicable.
function XDefWindowSubItem:IdNodeColor()
	local idNode = rawget(self, "IdNode")
	if idNode == false or (idNode == nil and not _G[self.__class].IdNode) then
		return ""
	end
	for _,item in ipairs(self) do
		if IsKindOf(item, "XDefGroup") then
			return "<color 75 105 198>"
		end
	end
	return ""
end

---
--- Determines the placement text for an `XDefWindowSubItem` object.
---
--- If the `XDefWindowSubItem` is an instance of `XOpenLayer`, the placement text is the concatenation of the `Layer` and `Mode` properties.
---
--- Otherwise, the placement text is the `Id` property of the `XDefWindowSubItem`, optionally followed by the `Dock` property if it is set.
---
--- @return string The placement text for the `XDefWindowSubItem`.
function XDefWindowSubItem:PlacementText()
	local class = g_Classes[self.__class]
	if class and class:IsKindOf("XOpenLayer") then
		return Untranslated(self:GetProperty("Layer") .. " " .. self:GetProperty("Mode"))
	else
		local dock = self:GetProperty("Dock")
		dock = dock and (" Dock:" .. tostring(dock)) or ""
		return Untranslated(self:GetProperty("Id") .. dock)
	end
end

-- TODO: XDefProperty for each ClassDefSubItem except code and function, those two will hve their own equivalent here
-- Give them ContainerClass = "" to disallow children disallow children
-- Make them placeable only on the top level

-- function XDef.__parent(parent, context)
-- 	return parent
-- end

-- function XDef.__context(parent, context)
-- 	return context
-- end

-- function XDef.__condition(parent, context)
-- 	return true
-- end

-- function XWindow:Spawn(args, spawn_children, parent, context, ...)
-- 	local win = self:new(args, parent, context, ...)
-- 	if spawn_children then
-- 		self.SpawnChildren = spawn_children
-- 	end
-- 	self:SpawnChildren(parent, context, ...)
-- 	return win
-- end

--XWindow.SpawnChildren = empty_func

DefineClass.XWindowFlattened = {
	__parents = { "XWindow" },
}

---
--- Spawns a new instance of the `XWindowFlattened` class, optionally spawning its children.
---
--- @param args table The arguments to pass to the `XWindowFlattened` constructor.
--- @param spawn_children function|nil A function to call to spawn the children of the new window.
--- @param parent any The parent object of the new window.
--- @param context any The context object for the new window.
--- @param ... any Additional arguments to pass to the `XWindowFlattened` constructor.
--- @return XWindowFlattened The new instance of `XWindowFlattened`.
function XWindowFlattened:Spawn(args, spawn_children, parent, context, ...)
	if spawn_children then
		self.SpawnChildren = spawn_children
	end
	self:SpawnChildren(parent, context, ...)
end

---- Example XWindowTest XDef code

-- function test()
-- 	PlaceObj('XDef', {
-- 		group = "Common",
-- 		id = "AAATEST",
-- 		PlaceObj('XDefGroup', {
-- 			'comment', "Human",
-- 			'__context_of_kind', '"Human"',
-- 			'__context', function (parent, context) return context[1] end,
-- 			'__parent', function (parent, context) return parent[2] end,
-- 			'__condition', function (parent, context) return #context < #parent end,
-- 		}, {
-- 			PlaceObj('XDefSubItem', {
-- 				'__parent', function (parent, context) return parent[2] end,
-- 				'LayoutMethod', "HWrap",
-- 			}, {
-- 				PlaceObj('XDefSubItem', {
-- 					'__class', "XText",
-- 					'Id', "idText2",
-- 					'Text', "123",
-- 				}),
-- 			}),
-- 		}),
-- 		PlaceObj('XDefSubItem', {
-- 			'__class', "XText",
-- 			'Id', "idText",
-- 			'Text', "abc",
-- 		}),
-- 		PlaceObj('XDefProperty', {
-- 			'id', "test_prop",
-- 			'default', true,
-- 			'name', Untranslated("Test Prop"),
-- 		}),
-- 	})
-- end


-- ---- Example generated code

-- DefineClass.XWindowTest = {
-- 	__parents = { "XWindow" },
-- 	properties = {
-- 		{ category = "Test", id = "test_prop", name = "Test Prop", editor = "bool", default = true, },
-- 	}
-- }

-- function XWindowTest:SpawnChildren(parent, context)
-- 	-- alternatively remove the indentation with goto Humans
-- 	-- well you cant as local context and parent need to be defined 

-- 	-- XDefGroup
-- 	-- Humans -- coment
-- 	if IsKindOf(context, "Human") then -- __context_of_kind
-- 		local context = context[1] -- __context
-- 		local parent = parent[2] -- __parent
-- 		if #context < #parent then -- __condition
-- 			goto condition_failed
-- 		end
-- 		XWindow:Spawn({
-- 			LayoutMethod = "HWrap",
-- 			__parent = function(self, parent, context)
-- 				return parent
-- 			end,
-- 		}, function(self, parent, context)
-- 			-- passing the spawn children function like this saves an indentation level
-- 			XText:Spawn({
-- 				Id = "idText2",
-- 				Text = "123",
-- 			}, self)
-- 		end, parent, context)
-- 		::condition_failed::
-- 	end
-- 	--::Humans::
	
-- 	XText:Spawn({
-- 		Id = "idText",
-- 		Text = "abc",
-- 	}, parent)
-- end
