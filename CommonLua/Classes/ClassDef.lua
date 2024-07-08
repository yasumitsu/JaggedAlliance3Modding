DefineClass.PropertyTabDef = {
	__parents = { "PropertyObject" },
	properties = {
		{ id = "TabName", editor = "text", default = "" },
		{ id = "Categories", editor = "set", default = {}, items = function(self)
				local class_def = GetParentTableOfKind(self, "ClassDef")
				local categories = {}
				for _, classname in ipairs(class_def.DefParentClassList) do
					local base = g_Classes[classname]
					for _, prop_meta in ipairs(base and base:GetProperties()) do
						categories[prop_meta.category or "Misc"] = true
					end
				end
				for _, subitem in ipairs(class_def) do
					if IsKindOf(subitem, "PropertyDef") then
						categories[subitem.category or "Misc"] = true
					end
				end
				return table.keys2(categories, "sorted")
			end
		}
	},
	GetEditorView = function(self)
		return string.format("%s - %s", self.TabName, table.concat(table.keys2(self.Categories or empty_table), ", "))
	end,
}

DefineClass.ClassDef = {
	__parents = { "Preset" },
	properties = {
		{ id = "DefParentClassList", name = "Parent classes", editor = "string_list", items = function(obj, prop_meta, validate_fn)
				if validate_fn == "validate_fn" then
					-- function for preset validation, checks whether the property value is from "items"
					return "validate_fn", function(value, obj, prop_meta)
						return value == "" or g_Classes[value]
					end
				end
				return table.keys2(g_Classes, true, "")
			end
		},
		{ id = "DefPropertyTranslation", name = "Translate property names", editor = "bool", default = false, },
		{ id = "DefStoreAsTable", name = "Store as table", editor = "choice", default = "inherit", items = { "inherit", "true", "false" } },
		{ id = "DefPropertyTabs", name = "Property tabs", editor = "nested_list", base_class = "PropertyTabDef", inclusive = true, default = false, },
		{ id = "DefUndefineClass", name = "Undefine class", editor = "bool", default = false, },
	},
	DefParentClassList = { "PropertyObject" },
	
	ContainerClass = "ClassDefSubItem",
	PresetClass = "ClassDef",
	FilePerGroup = true,
	HasCompanionFile = true,
	GeneratesClass = true,
	DefineKeyword = "DefineClass",
	
	GedEditor = "ClassDefEditor",
	EditorMenubarName = "Class definitions",
	EditorIcon = "CommonAssets/UI/Icons/cpu.png",
	EditorMenubar = "Editors.Engine",
	EditorShortcut = "Ctrl-Alt-F3",
	EditorViewPresetPrefix = "<color 75 105 198>[Class]</color> ",
}

---
--- Finds a subitem in the ClassDef object by name.
---
--- @param name string The name of the subitem to find.
--- @return table|nil The subitem if found, otherwise nil.
function ClassDef:FindSubitem(name)
	for _, subitem in ipairs(self) do
		if subitem:HasMember("name") and subitem.name == name or subitem:IsKindOf("PropertyDef") and subitem.id == name then
			return subitem
		end
	end
end

---
--- Gets the default property value for a property in the ClassDef object.
---
--- If the property ID starts with "Def", it tries to find the default property value from the parent class list.
--- If a default value is found in a parent class, it returns that value.
--- Otherwise, it falls back to the default behavior of the Preset class.
---
--- @param prop_id string The ID of the property to get the default value for.
--- @param prop_meta table The metadata for the property.
--- @return any The default property value, or nil if not found.
function ClassDef:GetDefaultPropertyValue(prop_id, prop_meta)
	if prop_id:starts_with("Def") then
		local class_prop_id = prop_id:sub(4)
		-- try to find the default property value from the parent list
		-- this is not correct if there are multiple parent classes that have different default values for the property
		for i, class_name in ipairs(self.DefParentClassList) do
			local class = g_Classes[class_name]
			if class then
				local default = class:GetDefaultPropertyValue(class_prop_id)
				if default ~= nil then
					return default
				end
			end
		end
	end
	return Preset.GetDefaultPropertyValue(self, prop_id, prop_meta)
end

---
--- Performs post-load operations on the ClassDef object.
---
--- This function is called after the ClassDef object has been loaded.
--- It sets the `translate_in_ged` property of each property definition in the ClassDef
--- to the value of the `DefPropertyTranslation` property of the ClassDef.
--- It then calls the `PostLoad` function of the parent `Preset` class.
---
--- @param self ClassDef The ClassDef object.
function ClassDef:PostLoad()
	for key, prop_def in ipairs(self) do
		prop_def.translate_in_ged = self.DefPropertyTranslation
	end
	Preset.PostLoad(self)
end

---
--- Performs pre-save operations on the ClassDef object.
---
--- This function is called before the ClassDef object is saved.
--- It converts the 'name' and 'help' properties of each property definition in the ClassDef
--- to/from the 'Ts' format based on the value of the 'DefPropertyTranslation' property.
--- It also sets the 'translate_in_ged' property of each property definition to the value of
--- the 'DefPropertyTranslation' property.
---
--- @param self ClassDef The ClassDef object.
function ClassDef:OnPreSave()
	-- convert texts to/from Ts if the 'translated' value changed
	local translate = self.DefPropertyTranslation
	for key, prop_def in ipairs(self) do
		if IsKindOf(prop_def, "PropertyDef") then
			local convert_text = function(value)
				local prop_translated = not value or IsT(value)
				if prop_translated and not translate then
					return value and TDevModeGetEnglishText(value) or false
				elseif not prop_translated and translate then
					return value and value ~= "" and T(value) or false 
				end
				return value
			end
			prop_def.name = convert_text(prop_def.name)
			prop_def.help = convert_text(prop_def.help)
			prop_def.translate_in_ged = translate
		end
	end
end

---
--- Generates the companion file code for the ClassDef object.
---
--- This function is responsible for generating the code that defines the ClassDef object in the companion file.
--- It performs the following steps:
--- 1. If the `DefUndefineClass` property is true, it appends a line to undefine the class.
--- 2. It appends the `DefineKeyword` (e.g. "Class") followed by the `id` of the ClassDef object.
--- 3. It calls the `GenerateParents` function to generate the `__parents` table.
--- 4. It calls the `AppendGeneratedByProps` function to append any generated properties.
--- 5. It calls the `GenerateProps` function to generate the `properties` table.
--- 6. It calls the `GenerateConsts` function to generate any constant definitions.
--- 7. It appends a closing `}` for the class definition.
--- 8. It calls the `GenerateMethods` function to generate any method definitions.
--- 9. It calls the `GenerateGlobalCode` function to generate any global code.
---
--- @param self ClassDef The ClassDef object.
--- @param code CodeWriter The CodeWriter object to append the generated code to.
---
function ClassDef:GenerateCompanionFileCode(code)
	if self.DefUndefineClass then
		code:append("UndefineClass('", self.id, "')\n")
	end
	code:append(self.DefineKeyword, ".", self.id, " = {\n")
	self:GenerateParents(code)
	self:AppendGeneratedByProps(code)
	self:GenerateProps(code)
	self:GenerateConsts(code)
	code:append("}\n\n")
	self:GenerateMethods(code)
	self:GenerateGlobalCode(code)
end

---
--- Generates the parent class list for the ClassDef object.
---
--- This function is responsible for generating the `__parents` table for the ClassDef object. It appends the parent class names to the `__parents` table in the generated companion file code.
---
--- @param self ClassDef The ClassDef object.
--- @param code CodeWriter The CodeWriter object to append the generated code to.
---
function ClassDef:GenerateParents(code)
	local parents = self.DefParentClassList
	if #(parents or "") > 0 then
		code:append("\t__parents = { \"", table.concat(parents, "\", \""), "\", },\n")
	end
end

---
--- Generates the properties table for the ClassDef object.
---
--- This function is responsible for generating the `properties` table for the ClassDef object. It iterates through the `PropertyDef` sub-items and generates the property definitions. If the `GeneratePropExtraCode` function is overridden, it calls that function for each property definition to allow for custom property generation.
---
--- @param self ClassDef The ClassDef object.
--- @param code CodeWriter The CodeWriter object to append the generated code to.
---
function ClassDef:GenerateProps(code)
	local extra_code_fn = self.GeneratePropExtraCode ~= ClassDef.GeneratePropExtraCode and
		function(prop_def) return self:GeneratePropExtraCode(prop_def) end
	self:GenerateSubItemsCode(code, "PropertyDef", "\tproperties = {\n", "\t},\n", self.DefPropertyTranslation, extra_code_fn )
end

---
--- Generates any extra code for a property definition.
---
--- This function is a placeholder that can be overridden by subclasses to generate any additional code for a property definition. The default implementation does nothing.
---
--- @param prop_def PropertyDef The property definition object.
---
function ClassDef:GeneratePropExtraCode(prop_def)
end

---
--- Appends a constant definition to the generated code.
---
--- This function is responsible for generating the constant definition for a property, if the property value differs from the default value. It checks if the property value is different from the alternative default value and the actual default value, and if so, it appends the constant definition to the generated code.
---
--- @param code CodeWriter The CodeWriter object to append the generated code to.
--- @param prop_id string The property ID.
--- @param alternative_default any The alternative default value for the property.
--- @param def_prop_id string The default property ID.
---
function ClassDef:AppendConst(code, prop_id, alternative_default, def_prop_id)
	def_prop_id = def_prop_id or "Def" .. prop_id
	local value = rawget(self, def_prop_id)
	if value == nil then return end
	local def_value = self:GetDefaultPropertyValue(def_prop_id)
	if value ~= alternative_default and value ~= def_value then
		code:append("\t", prop_id, " = ")
		code:appendv(value)
		code:append(",\n")
	end
end

---
--- Generates the constant definitions for the ClassDef object.
---
--- This function is responsible for generating the constant definitions for the ClassDef object. It checks if the `DefStoreAsTable` and `DefPropertyTabs` properties are set, and if so, it appends the corresponding constant definitions to the generated code. It then calls the `GenerateSubItemsCode` function to generate any additional constant definitions from `ClassConstDef` sub-items.
---
--- @param code CodeWriter The CodeWriter object to append the generated code to.
---
function ClassDef:GenerateConsts(code)
	if self.DefStoreAsTable ~= "inherit" then
		code:append("\tStoreAsTable = ", self.DefStoreAsTable, ",\n")
	end
	if self.DefPropertyTabs then
		code:append("\tPropertyTabs = ")
		code:appendv(self.DefPropertyTabs, "\t")
		code:append(",\n")
	end
	self:GenerateSubItemsCode(code, "ClassConstDef")
end

---
--- Generates the method definitions for the ClassDef object.
---
--- This function is responsible for generating the method definitions for the ClassDef object. It calls the `GenerateSubItemsCode` function to generate the code for any `ClassMethodDef` sub-items.
---
--- @param code CodeWriter The CodeWriter object to append the generated code to.
---
function ClassDef:GenerateMethods(code)
	self:GenerateSubItemsCode(code, "ClassMethodDef", "", "", self.id)
end

---
--- Generates the global code for the ClassDef object.
---
--- This function is responsible for generating the global code for the ClassDef object. It calls the `GenerateSubItemsCode` function to generate the code for any `ClassGlobalCodeDef` sub-items.
---
--- @param code CodeWriter The CodeWriter object to append the generated code to.
---
function ClassDef:GenerateGlobalCode(code)
	self:GenerateSubItemsCode(code, "ClassGlobalCodeDef", "", "", self.id)
end

---
--- Generates the code for sub-items of the ClassDef object.
---
--- This function is responsible for generating the code for any sub-items of the ClassDef object that are of the specified `subitem_class` type. It first checks if there are any sub-items of the specified type, and if so, it iterates through them and calls their `GenerateCode` function, optionally prepending and appending the `prefix` and `suffix` strings to the generated code.
---
--- @param code CodeWriter The CodeWriter object to append the generated code to.
--- @param subitem_class string The class name of the sub-items to generate code for.
--- @param prefix string (optional) A string to prepend to the generated code.
--- @param suffix string (optional) A string to append to the generated code.
--- @param ... any Additional arguments to pass to the sub-item's `GenerateCode` function.
---
function ClassDef:GenerateSubItemsCode(code, subitem_class, prefix, suffix, ...)
	local has_subitems
	for i, prop in ipairs(self) do
		if prop:IsKindOf(subitem_class) then
			has_subitems = true
			break
		end
	end
	
	if has_subitems then 
		if prefix then code:append(prefix) end
		for i, prop in ipairs(self) do
			if prop:IsKindOf(subitem_class) then
				prop:GenerateCode(code, ...)
			end
		end
		if suffix then code:append(suffix) end
	end
end

---
--- Generates the file save path for a companion file to a ClassDef object.
---
--- This function takes a file path and generates the appropriate save path for a companion file to a ClassDef object. The path is modified based on the starting directory of the original path, ensuring the companion file is saved in the correct location relative to the ClassDef files.
---
--- @param path string The original file path.
--- @return string The generated file save path for the companion file.
---
function ClassDef:GetCompanionFileSavePath(path)
	if path:starts_with("Data") then
		path = path:gsub("^Data", "Lua/ClassDefs") -- save in the game folder
	elseif path:starts_with("CommonLua/Data") then
		path = path:gsub("^CommonLua/Data", "CommonLua/Classes/ClassDefs") -- save in common lua
	elseif path:starts_with("CommonLua/Libs/") then -- lib
		path = path:gsub("/Data/", "/ClassDefs/")
	else
		path = path:gsub("^(svnProject/Dlc/[^/]*)/Presets", "%1/Code/ClassDefs") -- save in a DLC
	end
	return path:gsub(".lua$", ".generated.lua")
end


---
--- Checks for duplicate IDs in the ClassDef object and returns an error message if any are found.
---
--- This function iterates through the elements of the ClassDef object and checks if any of them have duplicate IDs. If a duplicate ID is found, it returns an error message indicating which ID is duplicated.
---
--- @return string|nil An error message if duplicate IDs are found, or nil if no duplicates are found.
---
function ClassDef:GetError()
	local names = {}
	for _, element in ipairs(self or empty_table) do
		local id = rawget(element, "id") or rawget(element, "id")
		if id then
			if names[id] then
				return "Some class members have matching ids - '"..element.id.."'"
			else
				names[id] = true
			end
		end
	end
end

---
--- Reads the contents of a text file up to a specified number of lines, optionally filtering the lines.
---
--- This function reads the contents of a text file at the given path, up to the specified number of lines. It can also apply a filter function to the lines, only including lines that pass the filter.
---
--- @param path string The path to the text file.
--- @param lines_count number The maximum number of lines to read from the file.
--- @param filter_func function (optional) A function that takes a line as an argument and returns a boolean indicating whether the line should be included.
--- @return string The contents of the file, up to the specified number of lines, with a trailing "..." if the file was truncated.
---
function GetTextFilePreview(path, lines_count, filter_func)
	if lines_count and lines_count > 0 then
		local file, err = io.open(path, "r")
		if not err then
			local count = 1
			local lines = {}
			local line
			while count <= lines_count do
				line = file:read()
				if line == nil then break end
				for subline in line:gmatch("[^%\r?~%\n?]+") do
					if count == lines_count + 1 or (filter_func and filter_func(subline)) then
						break
					end
					lines[#lines + 1] = subline
					count = count + 1
				end
			end
			lines[#lines + 1] = ""
			lines[#lines + 1] = "..."
			file:close()
			return table.concat(lines, "\n")
		end
	end
end

local function CleanUpHTMLTags(text)
	text = text:gsub("<br>", "\n")
	text = text:gsub("<br/>", "\n")
	text = text:gsub("<script(.+)/script>", "")
	text = text:gsub("<style(.+)/style>", "")
	text = text:gsub("<!--(.+)-->", "")
	text = text:gsub("<link(.+)/>", "")
	return text
end

---
--- Gets the documentation for the given object, if it exists.
---
--- @param obj table The object to get the documentation for.
--- @return string The documentation for the object, or nil if it doesn't exist.
---
function GetDocumentation(obj)
	if type(obj) == "table" and PropObjHasMember(obj, "Documentation") and obj.Documentation and obj.Documentation ~= "" then
		return obj.Documentation
	end
end

--- Gets the documentation link for the given object, if it exists.
---
--- @param obj table The object to get the documentation link for.
--- @return string The documentation link for the object, or nil if it doesn't exist.
---
function GetDocumentationLink(obj)
	if type(obj) == "table" and PropObjHasMember(obj, "DocumentationLink") and obj.DocumentationLink and obj.DocumentationLink ~= "" then
		local link = obj.DocumentationLink
		assert(link:starts_with("Docs/"))
		if not link:starts_with("http") then
			link = ConvertToOSPath(link)
		end
		link = string.gsub(link, "[\n\r]", "")
		link = string.gsub(link, " ", "%%20")
		return link
	end
end

---
--- Opens the documentation link for the given object, if it exists.
---
--- @param root table The root object.
--- @param obj table The object to get the documentation link for.
--- @param prop_id string The property ID.
--- @param ged table The GED instance.
--- @param btn_param table The button parameters.
--- @param idx number The index.
---
function GedOpenDocumentationLink(root, obj, prop_id, ged, btn_param, idx)
	OpenUrl(GetDocumentationLink(obj), "force external browser")
end


----- AppendClassDef

DefineClass.AppendClassDef = {
	__parents = { "ClassDef" },
	properties = {
		{ id = "DefUndefineClass", editor = false, },
		
	},
	GeneratesClass = false,
	DefParentClassList = false,
	DefineKeyword = "AppendClass",
}


----- ListPreset

DefineClass.ListPreset = {
	__parents = { "Preset", },
	HasGroups = false,
	HasSortKey = true,
	EditorMenubar = "Editors.Lists",
}

-- deprecated and left for compatibility reasons, to be removed
DefineClass.ListItem = {
	__parents = { "Preset", },
	properties = {
		{ id = "Group", no_edit = false, },
	},
	HasSortKey = true,
	PresetClass = "ListItem",
}


-----

if Platform.developer and not Platform.ged then
	---
 --- Removes any unversioned ClassDef*.lua files from the svnProject/../ directory.
 ---
 --- @param root table The root object.
 --- @param obj table The object to get the documentation link for.
 --- @param prop_id string The property ID.
 --- @param ged table The GED instance.
 --- @param btn_param table The button parameters.
 --- @param idx number The index.
 ---
 function RemoveUnversionedClassdefs()
     local err, files = AsyncListFiles("svnProject/../", "*.lua", "recursive")
     local removed = 0
     for _, file in ipairs(files) do
         if string.match(file, "ClassDef%-.*%.lua$") and not SVNLocalInfo(file) then
             print("removing", file)
             os.remove(file)
             removed = removed + 1
         end
     end
     print(removed, "files removed")
 end
 function RemoveUnversionedClassdefs()
		local err, files = AsyncListFiles("svnProject/../", "*.lua", "recursive")
		local removed = 0
		for _, file in ipairs(files) do
			if string.match(file, "ClassDef%-.*%.lua$") and not SVNLocalInfo(file) then
				print("removing", file)
				os.remove(file)
				removed = removed + 1
			end
		end
		print(removed, "files removed")
	end
end