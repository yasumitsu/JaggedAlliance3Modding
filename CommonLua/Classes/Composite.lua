----- Composite objects with components of base class CompositeClass that can be turned on and off
--
-- create the specific classes, setting their components and properties, using the Ged editor that will appear
-- properties of all components that have template = true in their metadata are editable in the Ged editor
-- use AutoResolveMethod to defind how to combine methods present in multiple components

const.ComponentsPropCategory = "Components"

DefineClass.CompositeDef = {
	__parents = { "Preset" },
	properties = {
		{ category = "Preset", id = "object_class", name = "Object Class", editor = "choice", default = "", items = function(self) return ClassDescendantsCombo(self.ObjectBaseClass, true) end, },
		{ category = "Preset", id = "code", name = "Global Code", editor = "func", default = false, lines = 1, max_lines = 100, params = "",
			no_edit = function(self) return IsKindOf(self, "ModItem") end,
		},
	},
	
	-- Preset settings
	GeneratesClass = true,
	SingleFile = false,
	GedShowTemplateProps = true,
	
	-- CompositeDef settings
	ObjectBaseClass = false,
	ComponentClass = false,
	
	components_cache = false,
	components_sorting = false,
	properties_cache = false,
	EditorMenubarName = false,
	
	EditorViewPresetPostfix = Untranslated(" <style GedSmall><color 164 128 64><object_class></color></style>"),
	Documentation = "This is a preset that results in a composite class definition. You can look at it as a template from which objects are created.\n\nThe generated class will inherit the specified Object Class and all component classes.",
}

---
--- Creates a new instance of a CompositeDef class.
---
--- @param class table The class definition of the CompositeDef.
--- @param obj table The object to initialize the CompositeDef with.
--- @return table The new instance of the CompositeDef class.
---
function CompositeDef.new(class, obj)
	local object = Preset.new(class, obj)
	object.object_class = CompositeDef.GetObjectClass(object)
	return object
end

---
--- Returns the object class for the CompositeDef.
---
--- If the `object_class` property is not an empty string, it returns that. Otherwise, it returns the `ObjectBaseClass` property.
---
--- @return string The object class for the CompositeDef.
---
function CompositeDef:GetObjectClass()
	return self.object_class ~= "" and self.object_class or self.ObjectBaseClass
end

---
--- Returns the list of component classes for the CompositeDef.
---
--- If the `ComponentClass` property is not set, an empty table is returned.
--- Otherwise, the function uses `ClassDescendantsList` to get a list of all classes that inherit from the `ComponentClass`.
--- The list is cached and sorted based on the `ComponentSortKey` property of each component class.
--- The function can also filter the list to return only active or inactive components based on the `filter` parameter.
---
--- @param filter string (optional) If set to "active", returns only the active components. If set to "inactive", returns only the inactive components.
--- @return table The list of component classes for the CompositeDef.
---
function CompositeDef:GetComponents(filter)
	if not self.ComponentClass then return empty_table end

	local components_cache = self.components_cache
	if not components_cache then
		local sorting_keys = {}
		local component_class = g_Classes[self.ComponentClass]
		local blacklist = component_class.BlackListBaseClasses
		components_cache = ClassDescendantsList(self.ComponentClass, function(classname, class, base_class, base_def, sorting_keys, blacklist)
			if class:IsKindOf(base_class) or base_def:IsKindOf(classname)
				or IsKindOf(g_Classes[class.__generated_by_class or false], "CompositeDef")
				or class:IsKindOfClasses(blacklist) then
				return
			end
			if (class.ComponentSortKey or 0) ~= 0 then
				sorting_keys[classname] = class.ComponentSortKey
			end
			return true
		end, self.ObjectBaseClass, g_Classes[self.ObjectBaseClass], sorting_keys, blacklist)
		local classdef = g_Classes[self.class]
		rawset(classdef, "components_cache", components_cache)
		rawset(classdef, "components_sorting", sorting_keys)
	end
	if filter == "active" then
		return table.ifilter(components_cache, function(_, classname) return self:GetProperty(classname) end)
	elseif filter == "inactive" then
		return table.ifilter(components_cache, function(_, classname) return not self:GetProperty(classname) end)
	end
	return components_cache
end

---
--- Returns the list of properties for the CompositeDef.
---
--- The function first checks if the `ObjectBaseClass` property is set, and if so, it retrieves the properties from the corresponding class definition.
--- If the `ObjectBaseClass` property is not set, it returns the properties defined directly on the CompositeDef.
--- The function also handles merging properties from the base class and component classes, ensuring that property defaults are consistent and that read-only properties are properly marked.
---
--- @return table The list of properties for the CompositeDef.
---
function CompositeDef:GetProperties()
	local object_class = self:GetObjectClass()
	local object_def = g_Classes[object_class]
	assert(not object_class or object_def)
	if not object_def then
		return self.properties
	end
	
	local cache = self.properties_cache or {}
	if not cache[object_class] then
		local props, prop_data = {}, {}
		local function add_prop(prop, default, class)
			local added
			if not prop_data[prop.id] then
				added = true
				if prop.default ~= default then
					prop = table.copy(prop)
					prop.default = default
				end
				props[#props + 1] = prop
			else
				assert(prop_data[prop.id].default == default,
					string.format("Default value conflict for property '%s' in classes '%s' and '%s'", prop.id, prop_data[prop.id].class, class))
			end
			prop_data[prop.id] = { default = default, class = class }
			return added and prop or table.find_value(props, "id", prop.id)
		end
		
		for _, prop in ipairs(self.properties) do
			if prop.id ~= "code" then add_prop(prop, prop.default, self.class) end
		end
		for _, prop in ipairs(object_def.properties) do
			if prop.template then
				add_prop(prop, object_def:GetDefaultPropertyValue(prop.id), self.class)
			end
		end
		
		local components = self:GetComponents()
		for _, classname in ipairs(components) do
			local inherited = object_def:IsKindOf(classname) or false
			local help = inherited and "Inherited from the base class"
			local prop = { category = const.ComponentsPropCategory, id = classname, editor = "bool", default = inherited, read_only = inherited, help = help }
			add_prop(prop, inherited, self.class)
		end
		add_prop(table.find_value(self.properties, "id", "code"), self:GetDefaultPropertyValue("code"), self.class)
		for _, classname in ipairs(components) do
			if not object_def:IsKindOf(classname) then
				local component_def = g_Classes[classname]
				for _, prop in ipairs(component_def.properties) do
					local category = prop.category or classname
					local no_edit = prop.no_edit
					prop = table.copy(prop, "deep")
					prop.category = category
					prop = add_prop(prop, component_def:GetDefaultPropertyValue(prop.id), classname)
					local composite_owner_classes = prop.composite_owner_classes or {}
					composite_owner_classes[#composite_owner_classes + 1] = classname
					prop.composite_owner_classes = composite_owner_classes
					prop.no_edit = function(self, ...)
						if no_edit == true or type(no_edit) == "function" and no_edit(self, ...) then return true end
						local prop_meta = select(1, ...)
						for _, name in ipairs(prop_meta.composite_owner_classes or empty_table) do
							if rawget(self, name) then
								return
							end
						end
						return true
					end
				end
			end
		end
		
		-- store the cache in the class, this auto-invalidates it on Lua reload
		rawset(g_Classes[self.class], "properties_cache", cache)
		rawset(cache, object_class, props)
		return props
	end
	
	return cache[object_class]
end

---
--- Sets a property on the CompositeDef object.
---
--- If the property has a template and a setter function, the setter function is called to set the property value.
--- If the property is in the CompositeDef.properties table, the Preset.SetProperty function is called to set the property value.
--- If the property is not in the CompositeDef.properties table, and the value is not nil, and the property name matches a component in the object, the OnEditorNew function of the component is called.
--- Finally, the property value is set directly on the CompositeDef object using rawset.
---
--- @param prop_id string The ID of the property to set.
--- @param value any The value to set the property to.
--- @return any The new value of the property.
function CompositeDef:SetProperty(prop_id, value)
	local prop_meta = self:GetPropertyMetadata(prop_id)
	if prop_meta and prop_meta.template and prop_meta.setter then
		return prop_meta.setter(self, value, prop_id, prop_meta)
	end
	if table.find(CompositeDef.properties, "id", prop_id) then
		return Preset.SetProperty(self, prop_id, value)
	end
	if value and table.find(self:GetComponents(), prop_id) and _G[prop_id]:HasMember("OnEditorNew") then
		_G[prop_id].OnEditorNew(self) -- OnEditorNew can initialize component property defaults of e.g. nested_obj/list component properties
	end	
	rawset(self, prop_id, value)
end

---
--- Gets the value of a property on the CompositeDef object.
---
--- If the property has a template and a getter function, the getter function is called to retrieve the property value.
--- If the property is in the CompositeDef.properties table, the Preset.GetProperty function is called to retrieve the property value.
--- If the property is not in the CompositeDef.properties table, the default value from the property metadata is returned.
---
--- @param prop_id string The ID of the property to get.
--- @return any The value of the property.
function CompositeDef:GetProperty(prop_id)
	local prop_meta = self:GetPropertyMetadata(prop_id)
	if prop_meta and prop_meta.template and prop_meta.getter then
		return prop_meta.getter(self, prop_id, prop_meta)
	end
	local value = Preset.GetProperty(self, prop_id)
	if value ~= nil then
		return value
	end
	return prop_meta and prop_meta.default
end

---
--- Called when a property on the CompositeDef object is set in the editor.
---
--- If the property has a template and an 'edited' function, the 'edited' function is called to handle the property change.
--- Otherwise, the Preset.OnEditorSetProperty function is called to handle the property change.
---
--- @param prop_id string The ID of the property that was set.
--- @param old_value any The previous value of the property.
--- @param ged any The GED object associated with the property.
--- @return any The new value of the property.
function CompositeDef:OnEditorSetProperty(prop_id, old_value, ged)
	local prop_meta = self:GetPropertyMetadata(prop_id)
	if prop_meta and prop_meta.template and prop_meta.edited then
		return prop_meta.edited(self, old_value, prop_id, prop_meta)
	end
	return Preset.OnEditorSetProperty(self, prop_id, old_value, ged)
end

---
--- Clears the properties of inactive components in the CompositeDef object.
---
--- This function iterates through the inactive components of the CompositeDef object and removes any properties that are not defined in the CompositeDef's properties list. It then calls the __toluacode function of the Preset class.
---
--- @param ... any Additional arguments to pass to the Preset.__toluacode function.
--- @return any The result of calling Preset.__toluacode.
function CompositeDef:__toluacode(...)
	-- clear properties of the inactive components
	local properties = self:GetProperties()
	local find = table.find
	local rawget = rawget
	for _, classname in ipairs(self:GetComponents("inactive")) do
		for _, prop in ipairs(g_Classes[classname].properties) do
			if rawget(self, prop.id) ~= nil and not find(properties, "id", prop.id) then
				self[prop.id] = nil
			end
		end
	end
	return Preset.__toluacode(self, ...)
end

-- supports generating a different class for each DLC, including property values for this DLC; see PresetDLCSplitting.lua
-- return a table with <key, file_name> pairs to generate multiple companion files, where key = dlc
---
--- Returns a table of companion file paths for the CompositeDef object, grouped by DLC.
---
--- This function iterates through the properties of the CompositeDef object and generates a table of companion file paths, grouped by the DLC associated with each property. If a property does not have a DLC associated with it, the default save path is used.
---
--- @param save_path string The default save path for the companion files.
--- @return table A table of companion file paths, grouped by DLC.
function CompositeDef:GetCompanionFilesList(save_path)
	local files = { }
	for _, prop in pairs(self:GetProperties()) do
		local save_in = prop.dlc or ""
		if not files[save_in] then
			-- GetSavePath depends on self.group and self.id
			files[save_in] = self:GetCompanionFileSavePath(prop.dlc and self:GetSavePath(prop.dlc) or save_path)
		end
	end
	return files
end

---
--- Generates the companion file code for the CompositeDef object.
---
--- This function is responsible for generating the code for the companion file associated with the CompositeDef object. It first checks if the class ID of the CompositeDef object exists in the global namespace. If it does, it returns an error message. Otherwise, it generates the code for the companion file, including the class definition, parent classes, generated properties, flags, constants, and any additional global code.
---
--- @param code CodeWriter The CodeWriter object to append the generated code to.
--- @param dlc string The DLC associated with the CompositeDef object.
--- @return string|nil An error message if the class ID of the CompositeDef object already exists in the global namespace, or nil if the code generation was successful.
function CompositeDef:GenerateCompanionFileCode(code, dlc)
	local class_exists_err = self:CheckIfIdExistsInGlobal()
	if class_exists_err then
		return class_exists_err
	end
	
	code:appendf("UndefineClass('%s')\nDefineClass.%s = {\n", self.id, self.id)
	self:GenerateParents(code)
	self:AppendGeneratedByProps(code)
	self:GenerateFlags(code)
	self:GenerateConsts(code, dlc)
	code:append("}\n\n")
	self:GenerateGlobalCode(code)
end

---
--- Generates the parent class list for the CompositeDef object.
---
--- This function is responsible for generating the list of parent classes for the CompositeDef object. It first retrieves the object class of the CompositeDef object, and then checks if there are any active components associated with the CompositeDef object. If there are active components, it filters out any components that are already part of the object class hierarchy. If there are no active components, it sets the object class as the only parent. If there are active components and the `components_sorting` table is not empty, it inserts the object class at the beginning of the list and sorts the list based on the sorting keys in the `components_sorting` table. Otherwise, it appends the object class to the beginning of the list of active components.
---
--- @param code CodeWriter The CodeWriter object to append the generated code to.
function CompositeDef:GenerateParents(code)
	local object_class = self:GetObjectClass()
	
	local list = self:GetComponents("active")
	if #list > 0 then
		assert(list ~= self.components_cache)
		local object_def = g_Classes[object_class]
		assert(object_def)
		if object_def then
			list = table.ifilter(list, function(_, classname) return not object_def:IsKindOf(classname) end)
		end
	end
	if #list == 0 then
		code:appendf('\t__parents = { "%s" },\n', object_class)
		return
	end
	
	if next(self.components_sorting) then
		table.insert(list, 1, object_class)
		local sorting_keys = self.components_sorting
		table.stable_sort(list, function(class1, class2)
			return (sorting_keys[class1] or 0) < (sorting_keys[class2] or 0)
		end)
		code:append('\t__parents = { "', table.concat(list, '", "'), '" },\n')
	else
		code:appendf('\t__parents = { "%s", "', object_class)
		code:append(table.concat(list, '", "'))
		code:append('" },\n')
	end
end

ClassNonInheritableMembers.composite_flags = true

---
--- Generates the composite flags for the CompositeDef object.
---
--- This function is responsible for generating the composite flags for the CompositeDef object. It first retrieves the object class of the CompositeDef object and copies the `composite_flags` table from the object class. It then iterates through the active components of the CompositeDef object and merges the `composite_flags` tables from each component. If there are any composite flags, it appends them to the generated code.
---
--- @param code CodeWriter The CodeWriter object to append the generated code to.
function CompositeDef:GenerateFlags(code)
	local object_def = g_Classes[self:GetObjectClass()]
	assert(object_def)
	if not object_def then return end
	
	local flags = table.copy(object_def.composite_flags or empty_table)
	for _, component in ipairs(self:GetComponents("active")) do
		for flag, set in pairs(g_Classes[component].composite_flags) do
			assert(flags[flag] == nil)
			flags[flag] = set
		end
	end
	if not next(flags) then
		return
	end
	code:append('\tflags = { ')
	for flag, set in sorted_pairs(flags) do
		code:appendf("%s = %s, ", flag, set and "true" or "false")
	end
	code:append('},\n')
end

---
--- Determines whether a property should be included in the generated code and what it should be named.
---
--- This function is responsible for deciding whether a property should be included in the generated code and what it should be named. It checks if the property's ID is in the property metadata or if it is the "code" property. If either of these conditions is true, the function returns `false`, indicating that the property should not be included.
---
--- If the property's DLC matches the provided DLC or if the property has a DLC override, the function returns the property's main game property ID or the property ID.
---
--- @param prop table The property to be evaluated.
--- @param dlc string The DLC to be used for the evaluation.
--- @return string|false The name to be used for the property in the generated code, or `false` if the property should not be included.
function CompositeDef:IncludePropAs(prop, dlc)
	local id = prop.id
	if Preset:GetPropertyMetadata(id) or id == "code" then
		return false
	end
	if not prop.dlc and not (dlc ~= "" and prop.dlc_override) or prop.dlc == dlc then
		return prop.maingame_prop_id or prop.id
	end
end

---
--- Generates the constant properties for the CompositeDef object.
---
--- This function is responsible for generating the constant properties for the CompositeDef object. It iterates through the properties of the CompositeDef object and includes them in the generated code if they are not the default property value. The function returns a boolean indicating whether there are any embedded objects in the properties.
---
--- @param code CodeWriter The CodeWriter object to append the generated code to.
--- @param dlc string The DLC to be used for the evaluation of the properties.
--- @return boolean Whether there are any embedded objects in the properties.
function CompositeDef:GenerateConsts(code, dlc)
	local props = self:GetProperties()
	code:append(#props > 0 and "\n" or "")
	local has_embedded_objects = false
	for _, prop in ipairs(props) do
		local id = prop.id
		local include_as = self:IncludePropAs(prop, dlc)
		if include_as then
			local value = rawget(self, id)
			if not self:IsDefaultPropertyValue(id, prop, value) then
				code:append("\t", include_as, " = ")
				ValueToLuaCode(value, 1, code, {} --[[ enable property injection ]])
				code:append(",\n")
			end
		end
	end
	return has_embedded_objects
end

---
--- Generates the global code for the CompositeDef object.
---
--- This function is responsible for generating the global code for the CompositeDef object. If the `code` property of the CompositeDef object is not empty, this function appends the code to the provided CodeWriter object. The code can be either a table of lines or a string.
---
--- @param code CodeWriter The CodeWriter object to append the generated code to.
---
function CompositeDef:GenerateGlobalCode(code)
	if self.code and self.code ~= "" then
		code:append("\n")
		local name, params, body = GetFuncSource(self.code)
		if type(body) == "table" then
			for _, line in ipairs(body) do
				code:append(line, "\n")
			end
		elseif type(body) == "string" then
			code:append(body)
		end
		code:append("\n")
	end
end

---
--- Returns the file path for the generated Lua file of the CompositeDef object.
---
--- The file path is determined based on the `save_in` property of the CompositeDef object:
--- - If `save_in` is empty, the file is saved in `Lua/<class>/__<ObjectBaseClass>.generated.lua`.
--- - If `save_in` is "Common", the file is saved in `CommonLua/Classes/<class>/__<ObjectBaseClass>.generated.lua`.
--- - If `save_in` starts with "Libs/", the file is saved in `CommonLua/<save_in>/<class>/__<ObjectBaseClass>.generated.lua`.
--- - If `save_in` is a DLC name, the file is saved in `svnProject/Dlc/<save_in>/Presets/<class>/__<ObjectBaseClass>.generated.lua`.
---
--- @param path string (unused) The path to the file containing the CompositeDef object.
--- @return string The file path for the generated Lua file of the CompositeDef object.
function CompositeDef:GetObjectClassLuaFilePath(path)
	if self.save_in == "" then
		return string.format("Lua/%s/__%s.generated.lua", self.class, self.ObjectBaseClass)
	elseif self.save_in == "Common" then
		return string.format("CommonLua/Classes/%s/__%s.generated.lua", self.class, self.ObjectBaseClass)
	elseif self.save_in:starts_with("Libs/") then -- lib
		return string.format("CommonLua/%s/%s/__%s.generated.lua", self.save_in, self.class, self.ObjectBaseClass)
	else -- save_in is a DLC name
		return string.format("svnProject/Dlc/%s/Presets/%s/__%s.generated.lua", self.save_in, self.class, self.ObjectBaseClass)
	end
end

---
--- Returns a warning message if the class for this preset has not been generated yet.
---
--- This method checks if the class for the current CompositeDef object has been generated. If not, it returns a warning message indicating that the class needs to be saved before it can be used or referenced from elsewhere.
---
--- @return string|nil The warning message, or nil if the class has been generated.
function CompositeDef:GetWarning()
	if not g_Classes[self.id] then
		return "The class for this preset has not been generated yet.\nIt needs to be saved before it can be used or referenced from elsewhere."
	end
end

---
--- Checks for errors in the components of the CompositeDef object.
---
--- This method iterates through the components of the CompositeDef object and calls the `GetError` method on each component. If any component returns an error, this method returns that error.
---
--- @return string|nil The error message, or `nil` if no errors were found.
function CompositeDef:GetError()
	for _, component in ipairs(self:GetComponents()) do
		if self[component] then
			local err = g_Classes[component].GetError(self)
			if err then
				return err
			end
		end
	end
end

function OnMsg.ClassesPreprocess(classdefs)
	for name, classdef in pairs(classdefs) do
		if classdef.__parents and classdef.__parents[1] == "CompositeDef" then
			classdefs[classdef.ObjectBaseClass].__hierarchy_cache = true
		end
	end	
end

function OnMsg.ClassesBuilt()
	ClassDescendants("CompositeDef", function(class_name, class)
		if IsKindOf(class, "ModItem") then return end
		
		local objclass = class.ObjectBaseClass
		local path = class:GetObjectClassLuaFilePath()
		
		-- can't generate the file in packed builds, as we can't get Lua source for func properties
		if config.RunUnpacked and Platform.developer and not Platform.console then
			-- Map all component methods => list of components they are defined in
			local methods = {}
			for _, component in ipairs(class:GetComponents()) do
				for name, member in pairs(g_Classes[component]) do
					if type(member) == "function" and not RecursiveCallMethods[name] then
						local classlist = methods[name]
						if classlist then
							classlist[#classlist + 1] = component
						else
							methods[name] = { component }
						end
					end
				end
			end
			
			-- Generate the code for the CompositeDef's object class here
			local code = pstr(exported_files_header_warning, 16384)
			code:appendf("function __%sExtraDefinitions()\n", objclass)
			
			-- a) make GetComponents callable from the object class
			code:appendf("\t%s.components_cache = false\n", objclass)
			code:appendf("\t%s.GetComponents = %s.GetComponents\n", objclass, class_name)
			code:appendf("\t%s.ComponentClass = %s.ComponentClass\n", objclass, class_name)
			code:appendf("\t%s.ObjectBaseClass = %s.ObjectBaseClass\n\n", objclass, class_name)
			
			-- b) add default property values for ALL component properites, so accessing them is fine from the object class
			local objprops = _G[objclass].properties
			for _, prop in ipairs(class:GetProperties()) do
				if not table.find(class.properties, "id", prop.id) and not table.find(objprops, "id", prop.id) then
					code:append("\t", objclass, ".", prop.id, " = ")
					ValueToLuaCode(class:GetDefaultPropertyValue(prop.id, prop), nil, code, {} --[[ enable property injection ]])
					code:append("\n")
				end
			end
			code:append("end\n\n")
			code:appendf("function OnMsg.ClassesBuilt() __%sExtraDefinitions() end\n", objclass)
			
			-- Save the code and execute it now
			local err = SaveSVNFile(path, code, class.LocalPreset)
			if err then
				printf("Error '%s' saving %s", tostring(err), path)
				return
			end	
		end
		
		if io.exists(path) then
			dofile(path)
			_G[string.format("__%sExtraDefinitions", objclass)]()
		else
			-- saved in a DLC folder, in a pack file mounted somewhere in DlcFolders
			assert(path:starts_with("svnProject/Dlc/"))
			for _, dlc_folder in ipairs(rawget(_G, "DlcFolders")) do
				local path = string.format("%s/Presets/%s/__%s.generated.lua", dlc_folder, class_name, objclass)
				if io.exists(path) then
					dofile(path)
					_G[string.format("__%sExtraDefinitions", objclass)]()
					return
				end
			end
			assert(false, "Unable to find and execute " .. path .. " from a DLC folder.")
		end
	end)
end


----- Test/sample code below

--[[DefineClass.TestClass = {
	__parents = { "PropertyObject" },
	properties = {
		{ category = "General", id = "BaseProp1", editor = "text", default = "", translate = true, lines = 1, max_lines = 10, },
		{ category = "General", id = "BaseProp2", editor = "bool", default = true, },
	},
	Value = true,
	TestMethod = true,
}

DefineClass.TestClassComponent = {
	__parents = { "PropertyObject" }
}

DefineClass.TestClassComponent1 = {
	__parents = { "TestClassComponent" },
	properties = {
		{ id = "Component1Prop1", editor = "text", default = "", translate = true, lines = 1, max_lines = 10 },
		{ id = "Component1Prop2", editor = "bool", default = true },
	},
}

function TestClassComponent1:Value()
	return 1
end

function TestClassComponent1:TestMethod()
	return 1
end

DefineClass.TestClassComponent2 = {
	__parents = { "TestClassComponent" },
	properties = {
		{ id = "Component2Prop", editor = "number", default = 0 },
	},
}

function TestClassComponent2:Value()
	return 2
end

RecursiveCallMethods.Value = "+"
RecursiveCallMethods.TestMethod = "call"

DefineClass.TestCompositeDef = {
	__parents = { "CompositeDef" },
	
	-- composite def
	ObjectBaseClass = "TestClass",
	ComponentClass = "TestClassComponent",
	
	-- preset
	EditorMenubarName = "TestClass Composite Objects Editor",
	EditorMenubar = "Editors",
	EditorShortcut = "Ctrl-T",
	GlobalMap = "TestCompositeDefs",
}]]