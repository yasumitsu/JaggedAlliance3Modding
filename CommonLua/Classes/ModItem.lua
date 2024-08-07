if not config.Mods then
	DefineModItemPreset = empty_func
	g_FontReplaceMap = false
	return
end

DefineClass.ModItemUsingFiles = {
	__parents = { "ModItem" },
	properties = { 
		{category = "Mod", id = "CopyFiles", name = "CopyFileNames", default = false, editor = "prop_table", no_edit = true},
	}
}

---
--- Returns a list of associated files/folders for this ModItem.
--- This function should be implemented in the specific class to return the appropriate list.
---
--- @return table A list of file/folder names associated with this ModItem.
---
function ModItemUsingFiles:GetFilesList()
	-- implement in the specific class to return a list of associated files/folders
end

---
--- Returns a serialized list of files associated with this ModItem.
--- The list includes the mod content path, mod ID, and for each file:
--- - the filename
--- - the file contents
--- - whether the item is a folder or not
---
--- @param filesList table (optional) A list of file/folder names to serialize. If not provided, the list is obtained from `ModItemUsingFiles:GetFilesList()`.
--- @return table A serialized list of files and folders associated with this ModItem.
---
function ModItemUsingFiles:GetFilesContents(filesList)
	filesList = filesList or self:GetFilesList()
	local serializedFiles = {}
	serializedFiles.mod_content_path = self.mod.content_path
	serializedFiles.mod_id = self.mod.id
	for _, filename in ipairs(filesList) do
		local is_folder = IsFolder(filename)
		local err, data = AsyncFileToString(filename)
		table.insert(serializedFiles, { filename = filename, data = data, is_folder = is_folder })
	end
	return serializedFiles
end

---
--- Serializes the files associated with this ModItem when the editor is serializing the object.
--- If the editor is serializing the object, this function saves the list of files associated with this ModItem
--- to the `CopyFiles` property. The `CopyFiles` property is then cleared after the serialization is complete.
---
--- @param self ModItemUsingFiles The ModItemUsingFiles instance.
--- @param indent string The current indentation level.
--- @param pstr string The property string.
--- @param GetPropFunc function A function to get the property value.
--- @param injected_props table Any injected properties.
--- @return string The serialized code for this ModItemUsingFiles instance.
---
function ModItemUsingFiles.__toluacode(self, indent, pstr, GetPropFunc, injected_props)
	if GedSerializeInProgress then
		self.CopyFiles = self:GetFilesContents()
	end
	local code = ModItem.__toluacode(self, indent, pstr, GetPropFunc, injected_props)
	self.CopyFiles = nil
	return code
end

---
--- Pastes the files associated with this ModItem.
--- If the `CopyFiles` property is set, this function creates the necessary folders and writes the file contents to disk.
--- After the files have been pasted, the `CopyFiles` property is set to `nil`.
---
--- @param self ModItemUsingFiles The ModItemUsingFiles instance.
---
function ModItemUsingFiles:PasteFiles()
	if not self.CopyFiles then return end -- ResolvePasteFilesConflicts can clear the variable
	for _, file in ipairs(self.CopyFiles) do
		if file.filename and file.filename ~= "" then
			local folder = file.filename
			if not file.is_folder then
				folder = folder:match("^(.*)/[^/]*$")
			end
			
			local err = AsyncCreatePath(folder)
			if err then ModLogF("Error creating path:", err) end
				
			if not file.is_folder and file.data then
				local err = AsyncStringToFile(file.filename, file.data)
				if err then ModLogF("Error creating file:", err) end
			end
		end
	end
	self.CopyFiles = nil
end

-- replaces the "filename" of self.CopyFiles[index] with the new paths without conflicts
-- may also prompt user for a manual change to resolve the conflict
-- returns any necessary/handy info to be used in OnAfterPasteFiles
---
--- Resolves any conflicts that may occur when pasting files associated with this ModItem.
--- This function is called after the files have been pasted, and can be used to modify the file paths or prompt the user for manual changes.
---
--- @param self ModItemUsingFiles The ModItemUsingFiles instance.
--- @param ged GedEditor The GedEditor instance.
--- @return table Any changes made to the file paths, or other relevant information.
---
function ModItemUsingFiles:ResolvePasteFilesConflicts()
end

-- applies whatever changes need to be applied after the files have been created (some change the files' contents, so it need to be after paste)
---
--- Called after the files associated with this ModItem have been pasted.
--- This function can be used to apply any additional changes or modifications to the pasted files.
---
--- @param self ModItemUsingFiles The ModItemUsingFiles instance.
--- @param changes_meta table Any changes made to the file paths, or other relevant information, from the ResolvePasteFilesConflicts function.
---
function ModItemUsingFiles:OnAfterPasteFiles(changes_meta)
end

---
--- Called after the ModItemUsingFiles instance has been created in the editor.
--- This function is responsible for resolving any conflicts that may occur when pasting files associated with this ModItem, and then actually pasting the files.
---
--- @param self ModItemUsingFiles The ModItemUsingFiles instance.
--- @param parent any The parent object of the ModItemUsingFiles instance.
--- @param ged GedEditor The GedEditor instance.
--- @param is_paste boolean Whether this is being called as part of a paste operation.
---
function ModItemUsingFiles:OnAfterEditorNew(parent, ged, is_paste)
	if self.CopyFiles and #self.CopyFiles > 0 then
		local changes_meta = self:ResolvePasteFilesConflicts(ged)
		self:PasteFiles()
		self:OnAfterPasteFiles(changes_meta)
	end
end

---
--- Called when the ModItemUsingFiles instance is deleted from the editor.
--- This function deletes any files associated with the ModItem.
---
--- @param self ModItemUsingFiles The ModItemUsingFiles instance.
--- @param parent any The parent object of the ModItemUsingFiles instance.
--- @param ged GedEditor The GedEditor instance.
---
function ModItemUsingFiles:OnEditorDelete(parent, ged)
	for _, path in ipairs(self:GetFilesList()) do
		if path ~= "" then AsyncFileDelete(path) end
	end
end


----- ModItemCode

DefineClass.ModItemCode = {
	__parents = { "ModItemUsingFiles" },
	properties = {
		{
			category = "Mod", id = "name", name = "Name", default = "Script", editor = "text", 
			validate = function(self, value)
				value = value:trim_spaces()
				if value == "" then
					return "Please enter a valid name"
				end
				return self.mod:ForEachModItem("ModItemCode", function(item)
					if item ~= self and item.name == value then
						return "A code item with that name already exists"
					end
				end)
			end,
		},
		{ category = "Code", id = "CodeFileName", name = "File name", default = "", editor = "text", read_only = true, buttons = {{name = "Open", func = "OpenCodeFile"}},},
		{ category = "Code", id = "CodeError", name = "Error", default = "", editor = "text", lines = 1, max_lines = 3, read_only = true, dont_save = true, translate = false, code = true },
		{ category = "Code", id = "Preview", name = "Preview", default = "", editor = "text", lines = 10, max_lines = 30, wordwrap = false, read_only = true, dont_save = true, translate = false, code = true },
	},
	EditorName = "Code",
	EditorSubmenu = "Assets",
	preview = "",
	Documentation = "This mod item allows you to load a single file of Lua code in the Lua environment of the game. The code can then directly affect the game, or be used by some other mod items.",
	DocumentationLink = "Docs/ModItemCode.md.html",
	TestDescription = "Reloads lua."
}

---
--- Called when a new ModItemCode instance is created in the editor.
--- This function sets the name of the ModItemCode instance to a unique name.
---
--- @param self ModItemCode The ModItemCode instance.
---
function ModItemCode:OnEditorNew()
	self.name = self:FindFreeFilename(self.name)
end

---
--- Ensures that the file for the ModItemCode instance exists. If the file does not exist, it creates an empty file at the expected file path.
---
--- @param self ModItemCode The ModItemCode instance.
---
function ModItemCode:EnsureFileExists()
	AsyncCreatePath(self.mod.content_path .. "Code/")
	local file_path = self:GetCodeFilePath()
	if file_path ~= "" and not io.exists(file_path) then
		AsyncStringToFile(file_path, "")
	end
end

---
--- Returns a list of file paths for the ModItemCode instance.
---
--- @return table A table containing the file path for the ModItemCode instance.
---
function ModItemCode:GetFilesList()
	self:EnsureFileExists()
	return {self:GetCodeFilePath()}
end

---
--- Resolves any conflicts that may arise when pasting a ModItemCode instance.
--- This function ensures that the name of the ModItemCode instance is unique by finding a free filename.
--- It also updates the filename of the first CopyFile associated with the ModItemCode instance to match the new filename.
---
--- @param self ModItemCode The ModItemCode instance.
---
function ModItemCode:ResolvePasteFilesConflicts()
	self.name = self:FindFreeFilename(self.name)
	self.CopyFiles[1].filename = self:GetCodeFilePath()
end

---
--- Called after a new instance of ModItemCode is created in the editor.
--- This function ensures that the file for the ModItemCode instance exists. If the file does not exist, it creates an empty file at the expected file path.
---
--- @param self ModItemCode The ModItemCode instance.
--- @param parent any The parent object of the ModItemCode instance.
--- @param ged any The editor GUI object.
--- @param is_paste boolean Whether the ModItemCode instance was pasted.
---
function ModItemCode:OnAfterEditorNew(parent, ged, is_paste)
	self:EnsureFileExists()
end

---
--- Called when a property of the ModItemCode instance is changed in the editor.
--- This function handles the case where the "name" property is changed. It ensures that the file for the ModItemCode instance is updated to match the new name.
---
--- @param self ModItemCode The ModItemCode instance.
--- @param prop_id string The ID of the property that was changed.
--- @param old_value any The old value of the property.
--- @param ged any The editor GUI object.
---
function ModItemCode:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "name" then
		local old_file_name = self:GetCodeFilePath(old_value)
		local new_file_name = self:GetCodeFilePath()
		AsyncCreatePath(self.mod.content_path .. "Code/")
		local err
		if io.exists(old_file_name) then
			local data
			err, data = AsyncFileToString(old_file_name)
			err = err or AsyncStringToFile(new_file_name, data)
			if err then
				ged:ShowMessage("Error", string.format("Error creating %s", new_file_name))
				self.name = old_value
				ObjModified(self)
				return
			end
			AsyncFileDelete(old_file_name)
		elseif not io.exists(new_file_name) then
			err = AsyncStringToFile(new_file_name, "")
		end
	end
end

---
--- Gets the code file name for the ModItemCode instance.
---
--- @param name string The name of the ModItemCode instance. If not provided, the name of the instance is used.
--- @return string The code file name for the ModItemCode instance.
---
function ModItemCode:GetCodeFileName(name)
	name = name or self.name or ""
	if name == "" then return end
	return string.format("Code/%s.lua", name:gsub('[/?<>\\:*|"]', "_"))
end

---
--- Opens the code file associated with the ModItemCode instance.
---
--- This function ensures that the code file exists, and then opens the file in the default file explorer application.
---
--- @param self ModItemCode The ModItemCode instance.
---
function ModItemCode:OpenCodeFile()
	self:EnsureFileExists()
	local file_path = self:GetCodeFilePath()
	if file_path ~= "" then
		CreateRealTimeThread(AsyncExec, "explorer " .. ConvertToOSPath(file_path))
	end
end

---
--- Gets the preview code for the ModItemCode instance.
---
--- This function reads the code file associated with the ModItemCode instance and returns its contents as a string.
---
--- @param self ModItemCode The ModItemCode instance.
--- @return string The preview code for the ModItemCode instance.
---
function ModItemCode:GetPreview()
	local err, code = AsyncFileToString(self:GetCodeFilePath())
	self.preview = code
	return code or ""
end

---
--- Finds a free filename for a ModItemCode instance.
---
--- This function checks the existing ModItemCode instances in the mod to find a unique filename for the current instance. It generates a new filename by appending a number to the end of the name until a unique filename is found.
---
--- @param self ModItemCode The ModItemCode instance.
--- @param name string The name of the ModItemCode instance.
--- @return string The free filename for the ModItemCode instance.
---
function ModItemCode:FindFreeFilename(name)
	if name == "" then return name end
	
	local existing_code_files = {}
	self.mod:ForEachModItem("ModItemCode", function(item)
		if item ~= self then 
			existing_code_files[item.name] = true
		end
	end)
	
	local n = 1
	local folder, file_name, ext = SplitPath(name)
	local matching_digits = file_name:match("(%d*)$")
	local n = matching_digits and tonumber(matching_digits) or -1
	file_name = file_name:sub(1, file_name:len() - matching_digits:len())
	local new_file_name = (file_name .. tostring(n > 0 and n or ""))
	while existing_code_files[new_file_name] or io.exists(folder .. new_file_name .. ext) do
		n = n + 1
		new_file_name = (file_name .. tostring(n > 0 and n or ""))
	end
	return folder .. new_file_name .. ext
end

---
--- Gets the error message for the ModItemCode instance.
---
--- This function checks if the code file associated with the ModItemCode instance exists. If the file does not exist, it returns a message indicating that the file needs to be created. If the file exists, it checks if there are any other ModItemCode instances with the same name, and returns a message indicating that there are multiple ModItemCode items pointing to the same script.
---
--- @param self ModItemCode The ModItemCode instance.
--- @return string The error message for the ModItemCode instance.
---
function ModItemCode:GetError()
	if not io.exists(self:GetCodeFilePath()) then return "No file! Click the 'Open' button to create it." end
	return self.mod:ForEachModItem("ModItemCode", function(item)
		if item ~= self and item.name == self.name then
			return "Multiple ModItemCode items point to the same script!"
		end
	end)
end

---
--- Reloads the mod code and displays a success message.
---
--- This function is called when the user wants to test the mod item. It first checks if the mod code has been updated, and if so, reloads the Lua code. It then notifies the user that the code has been loaded and is currently active in the game.
---
--- @param self ModItemCode The ModItemCode instance.
--- @param ged GedEditor The GedEditor instance.
---
function ModItemCode:TestModItem(ged)
	if self.mod:UpdateCode() then
		ReloadLua()
	end
	ObjModified(self)
	ged:ShowMessage("Information", "Your code has been loaded and is currently active in the game.")
end

function OnMsg.ModCodeChanged(file, change)
	for i,mod in ipairs(ModsLoaded) do
		if not mod.packed then
			mod:ForEachModItem("ModItemCode", function(item)
				if string.find_lower(file, item.name) then
					ObjModified(item)
					return "break"
				end
			end)
		end
	end
end


----- T funcs

local function DuplicateT(v)
	if getmetatable(v) == TConcatMeta then
		local ret = {}
		for _, t in ipairs(v) do
			table.insert(ret, DuplicateT(t))
		end
		return setmetatable(ret, TConcatMeta)
	end
	v = _InternalTranslate(v, false, false)
	return T{RandomLocId(), v}
end

---
--- Recursively duplicates the tables in the given object, preserving the T metatable.
---
--- This function is used to create a deep copy of an object that contains T objects. It recursively traverses the object, duplicating any tables it finds and preserving the T metatable on those tables.
---
--- @param obj table The object to duplicate.
--- @param visited table (optional) A table of visited objects, used to avoid infinite recursion.
--- @return table A deep copy of the input object, with T objects preserved.
---
function DuplicateTs(obj, visited)
	visited = visited or {}
	for key, value in pairs(obj) do
		if not MembersReferencingParents[key] then
			if value ~= "" and IsT(value) then
				obj[key] = DuplicateT(value)
			elseif type(value) == "table" and not visited[value] then
				visited[value] = true
				DuplicateTs(value, visited)
			end
		end
	end
end


----- ModItemPreset

---
--- Defines a ModItemPreset class that extends the Preset and ModItem classes.
---
--- The ModItemPreset class is used to define preset configurations for mod items in the game. It inherits from both the Preset and ModItem classes, and adds additional properties and functionality specific to mod items.
---
--- The function `DefineModItemPreset` is used to create a new ModItemPreset class. It takes a `preset` parameter, which is the name of the preset, and an optional `class` parameter, which is a table of properties and methods to be added to the new class.
---
--- The new class has the following properties and methods:
---
--- - `GedEditor`: A boolean flag indicating whether the preset should be editable in the GED editor.
--- - `ModdedPresetClass`: The name of the preset that this ModItemPreset is based on.
--- - `EditorView`: The editor view to use for this ModItemPreset.
--- - `__parents`: A table of parent classes for the new class, including "ModItemPreset" and the `preset` parameter.
--- - `GetError`: A method that returns any errors associated with the ModItemPreset.
--- - `EditorName`: The name of the ModItemPreset as it appears in the editor.
--- - `properties`: A table of properties for the ModItemPreset, including additional properties for the "Mod" category.
---
--- The function also defines a new class named "ModItem{preset}" that inherits from the new ModItemPreset class.
---
function DefineModItemPreset(preset, class)
	class = class or {}
	class.GedEditor = false
	class.ModdedPresetClass = preset
	class.EditorView = ModItem.EditorView
	class.__parents = { "ModItemPreset", preset, }
	class.GetError = ModItemPreset.GetError
	assert((class.EditorName or "") ~= "", "EditorName is required for mod item presets")
	if (class.EditorName or "") == "" then
		class.EditorName = preset
	end
	
	local properties = class.properties or {}
	local id_prop = table.copy(table.find_value(Preset.properties, "id", "Id"))
	local group_prop = table.copy(table.find_value(Preset.properties, "id", "Group"))
	id_prop.category = "Mod"
	group_prop.category = "Mod"
	table.insert(properties, id_prop)
	table.insert(properties, group_prop)
	table.insert(properties, { id = "Comment", no_edit = true, }) -- duplicates with ModItem's comment property
	table.insert(properties, { category = "Mod", id = "Documentation", dont_save = true, editor = "documentation", sort_order = 9999999 }) -- duplicates with ModItem's comment property
	table.insert(properties, { id = "new_in", editor = false })
	class.properties = properties
	
	UndefineClass("ModItem" .. preset)
	DefineClass("ModItem" .. preset, class)
	return class
end

---
--- Defines a new ModItemCompositeObject class that extends the ModItemPreset class.
---
--- The ModItemCompositeObject class is used to create a composite object that inherits from both the ModItemPreset and CompositeDef classes. This allows the object to have properties and functionality from both classes.
---
--- The `DefineModItemCompositeObject` function takes two parameters:
--- - `preset`: The name of the preset that the new class will be based on.
--- - `class`: An optional table of properties and methods to be added to the new class.
---
--- The function creates a new class by calling `DefineModItemPreset` with the `preset` and `class` parameters. It then sets the `__parents` property of the new class to include "ModItemCompositeObject" and the `preset` parameter.
---
--- The `new` method of the new class is defined to create a new object by calling the `new` methods of both the CompositeDef and ModItemPreset classes.
---
--- The `GetProperties` method of the new class is set to the `GetProperties` method of the ModItemCompositeObject class.
---
--- The new class is returned by the function.
---
function DefineModItemCompositeObject(preset, class)
	local class = DefineModItemPreset(preset, class)
	class.__parents = { "ModItemCompositeObject", preset, }
	class.new = function(class, obj)
		obj = CompositeDef.new(class, obj)
		obj = ModItemPreset.new(class, obj)
		return obj
	end
	class.GetProperties = ModItemCompositeObject.GetProperties
	return class
end

DefineClass.ModItemCompositeObject = {
	__parents = { "ModItemPreset" },

	mod_properties_cache = false,
}

function OnMsg.ClassesBuilt()
	ClassDescendantsList("ModItemPreset", function(name, class)
		for idx, prop in ipairs(class.properties) do
			if prop.category == "Preset" then
				prop = table.copy(prop)
				prop.category = "Mod"
				class.properties[idx] = prop
			end
		end
	end)
end

-- making this a local function to avoid duplication in the "Copy from" and "Copy from group"; mostly for the filter func
local function GetFilteredPresetsCombo(obj, group)
	return PresetsCombo(obj.PresetClass or obj.class,
								group,
								nil,
								function(preset) return preset ~= obj and not preset.Obsolete end)()
end

DefineClass.ModItemPreset = {
	__parents = { "Preset", "ModItem" },
	properties = {
		{ category = "Mod", id = "__copy_group", name = "Copy from group", default = "Default", editor = "combo", 
			items = function(obj)
				local candidate_groups = PresetGroupsCombo(obj.PresetClass or obj.class)()
				local groups = {}
				for _, group in ipairs(candidate_groups) do
					local num_presets = #(GetFilteredPresetsCombo(obj, group))
					if num_presets ~= 0 and group ~= "Obsolete" then table.insert(groups, group) end
				end
				return groups
			end,
			no_edit = function (obj) return not obj.HasGroups end, dont_save = true, },
		{ category = "Mod", id = "__copy", name = "Copy from", default = "", editor = "combo", 
			items = function(obj) 
				local group = obj.PresetClass ~= obj.ModdedPresetClass and not obj.HasGroups and obj.ModdedPresetClass or obj.__copy_group
				return GetFilteredPresetsCombo(obj, group) 
			end,
			dont_save = true, },
		{ id = "SaveIn", editor = false },
		{ id = "name", default = false, editor = false },
		{ id = "TODO", editor = false },
		{ id = "Obsolete", editor = false },
	},
	EditorView = ModItem.EditorView,
	GedEditor = false,
	ModItemDescription = T(159662765679, "<u(id)>"),
	ModdedPresetClass = false,
	save_in = "none",
	is_data = true,
	TestDescription = "Loads the mod item's data in the game."
}
---
--- Sets the save location for this ModItemPreset.
--- This method is a no-op, as ModItemPreset instances are saved in "none" location.
---
function ModItemPreset:SetSaveIn()
end

---
--- Returns the save location for this ModItemPreset, which is always "none".
---
--- @return string The save location for this ModItemPreset.
function ModItemPreset:GetSaveIn()
    return "none"
end

---
--- Returns `nil` for the save folder of this ModItemPreset, as it is not applicable.
---
--- @return nil The save folder for this ModItemPreset.
function ModItemPreset:GetSaveFolder()
    return nil
end

---
--- Returns `nil` for the save path of this ModItemPreset, as it is not applicable.
---
--- @return nil The save path for this ModItemPreset.
function ModItemPreset:GetSavePath()
    return nil
end

---
--- Returns the ID of this ModItemPreset as its name.
---
--- @return string The name of this ModItemPreset.
function ModItemPreset:Getname()
    return self.id
end

---
--- Returns the save location type for this ModItemPreset, which is always "mod".
---
--- @return string The save location type for this ModItemPreset.
function ModItemPreset:GetSaveLocationType()
    return "mod"
end

function ModItemPreset:SetSaveIn()                          end
function ModItemPreset:GetSaveIn()           return "none"  end
function ModItemPreset:GetSaveFolder()       return nil     end
function ModItemPreset:GetSavePath()         return nil     end
function ModItemPreset:Getname()             return self.id end
function ModItemPreset:GetSaveLocationType() return "mod"   end

---
--- Checks if the ModItemPreset is currently open in the Game Editor (GED).
---
--- @return boolean True if the ModItemPreset is open in the GED, false otherwise.
function ModItemPreset:IsOpenInGed()
	return Preset.IsOpenInGed(self) or ModItem.IsOpenInGed(self)
end

---
--- Deletes the ModItemPreset instance and any associated InitDone instance.
---
--- This function is used to remove the ModItemPreset from the system, typically when the user no longer needs or wants the preset.
---
--- @function ModItemPreset:delete
--- @return nil
function ModItemPreset:delete()
	Preset.delete(self)
	InitDone.delete(self)
end

---
--- Returns the file name for the companion code file of this ModItemPreset.
---
--- The companion code file is generated when the ModItemPreset is saved, and contains additional code that is associated with the preset.
---
--- @param name string|nil The name to use for the file name. If not provided, the ID of the ModItemPreset will be used.
--- @return string|nil The file name for the companion code file, or nil if the preset does not have a companion file.
function ModItemPreset:GetCodeFileName(name)
	if self.HasCompanionFile or self.GetCompanionFilesList ~= Preset.GetCompanionFilesList then
		name = name or self.id
		local sub_folder = IsKindOf(self, "CompositeDef") and self.ObjectBaseClass or self.PresetClass
		return name and name ~= "" and
			string.format("%s/%s.lua", sub_folder, name:gsub('[/?<>\\:*|"]', "_"))
	end
end

---
--- Returns a unique key for the specified property of this ModItemPreset.
---
--- The key is constructed by combining the class name, the preset ID, and the property ID.
---
--- @param prop_id string The ID of the property.
--- @return string The unique key for the specified property.
function ModItemPreset:GetPropOSPathKey(prop_id)
	return string.format("%s_%s_%s", self.class, self.id, prop_id)
end

---
--- Called before the ModItemPreset is saved.
---
--- This function is called just before the ModItemPreset is saved to disk. It allows the preset to perform any necessary pre-save operations, such as updating internal state or generating companion files.
---
--- The function returns the result of calling `ModItem.PreSave(self)`, which allows the base class to perform any additional pre-save operations.
---
--- @return boolean The result of calling `ModItem.PreSave(self)`.
function ModItemPreset:PreSave()
	self:OnPreSave()
	return ModItem.PreSave(self)
end

---
--- Called after the ModItemPreset is saved.
---
--- This function is called after the ModItemPreset has been successfully saved to disk. It allows the preset to perform any necessary post-save operations, such as generating companion files.
---
--- The function returns the result of calling `ModItem.PostSave(self)`, which allows the base class to perform any additional post-save operations.
---
--- @param saved_preset_classes table|nil A table of preset classes that were saved, or nil if no presets were saved.
--- @return boolean The result of calling `ModItem.PostSave(self)`.
function ModItemPreset:PostSave(saved_preset_classes)
	if saved_preset_classes then
		saved_preset_classes[self.PresetClass or self.class] = true
	end
	if self:GetCodeFileName() then
		local code = pstr("", 8 * 1024)
		local err = self:GenerateCompanionFileCode(code)
		if not err then
			local path = self:GetCodeFilePath()
			local folder = SplitPath(path)
			AsyncCreatePath(folder)
			AsyncStringToFile(path, code)
		end
	end
	self:OnPostSave()
	return ModItem.PostSave(self)
end

-- This is a request to store the preset to disk, e.g. from the "Save" button in the Script Editor
-- For a mod item, initiate a save of the mod items to do this
---
--- Saves the ModItemPreset.
---
--- This function is called when the user requests to save the ModItemPreset, such as by clicking a "Save" button in the Script Editor.
---
--- It delegates the actual saving of the ModItemPreset to the `mod:SaveItems()` function.
---
--- @param by_user_request boolean True if the save was requested by the user, false if it was triggered programmatically.
--- @param ged table The GameEditorData object associated with the ModItemPreset.
function ModItemPreset:Save(by_user_request, ged)
	self.mod:SaveItems()
end

---
--- Copies the properties from the given `preset` to this `ModItemPreset`.
---
--- This function is called when copying properties from another `ModItemPreset` instance. It copies the properties from the given `preset` to this instance, excluding certain properties like `Id`, `Group`, `comment`, and `__copy`.
---
--- @param preset ModItemPreset The `ModItemPreset` instance to copy properties from.
function ModItemPreset:OnCopyFrom(preset)
end

---
--- Gathers the properties of the ModItemPreset that are in the given blacklist.
---
--- This function is used to gather the properties of the ModItemPreset that are in the given blacklist. It is typically used when copying properties from one ModItemPreset to another, to exclude certain properties like "Id", "Group", "comment", and "__copy".
---
--- @param blacklist table A table of property IDs to exclude.
function ModItemPreset:GatherPropertiesBlacklisted(blacklist)
end

---
--- Handles changes to the properties of a `ModItemPreset` object.
---
--- This function is called when a property of the `ModItemPreset` object is changed in the editor. It performs various actions depending on the property that was changed.
---
--- If the "Id" property is changed, it deletes the old code file associated with the preset, as a new one will be generated upon saving.
---
--- If the "__copy" property is changed, it copies the properties from another `ModItemPreset` object to this one, excluding certain properties like "Id", "Group", "comment", and "__copy". It also performs additional actions like overriding emitter and sample functions, and marking the object as modified.
---
--- @param prop_id string The ID of the property that was changed.
--- @param old_value any The old value of the property.
--- @param ged table The `GameEditorData` object associated with the `ModItemPreset`.
function ModItemPreset:OnEditorSetProperty(prop_id, old_value, ged)
	Preset.OnEditorSetProperty(self, prop_id, old_value, ged)

	if prop_id == "Id" then
		if self:GetCodeFileName() then
			-- delete old code file, a new one will be generated upon saving
			AsyncFileDelete(self:GetCodeFilePath(old_value))
		end
	elseif prop_id == "__copy" then
		local preset_class = self.PresetClass or self.class
		local preset_group = self.PresetClass ~= self.ModdedPresetClass and not self.HasGroups and self.ModdedPresetClass or self.__copy_group
		local id = self.__copy
		local preset
		ForEachPresetExtended(preset_class,
			function(obj)
				if obj.group == preset_group and obj.id == id and obj ~= self then
					preset = obj
					return "break"
				end
			end
		)
		if not preset then
			return
		end
		
		local function do_copy()
			local blacklist = { "Id", "Group", "comment", "__copy" }
			self:GatherPropertiesBlacklisted(blacklist)
			CopyPropertiesBlacklisted(preset, self, blacklist)
			
			--copy even default value props to prevent leftovers from previous copies
			local presetProps = preset:GetProperties()
			for _, prop in ipairs(presetProps) do
				local propId = prop.id
				if not table.find(blacklist, propId) and preset:IsPropertyDefault(propId, prop) then
					self[propId] = nil
				end
			end
			
			table.iclear(self)
			local count = 0
			for _, value in ipairs(preset) do
				local err, copy = CopyValue(value)
				assert(not err, err)
				if not err then
					count = count + 1
					self[count] = copy
				end
			end
			PopulateParentTableCache(self)
			DuplicateTs(self)
			
			for _, sub_obj in ipairs(self) do
				if IsKindOf(sub_obj, "ParticleEmitter") then
					self:OverrideEmitterFuncs(sub_obj)
				end
				if IsKindOf(sub_obj, "SoundFile") then
					self:OverrideSampleFuncs(sub_obj)
				end
			end
			
			self:OnCopyFrom(preset)
			if ged and ged.app_template == "ModEditor" then
				ObjModified(ged:ResolveObj("root"))
			else
				ObjModifiedMod(self.mod)
			end
			ObjModified(self)
		end
		
		self.__copy = nil
		ObjModified(self)
		
		if ged and ged.app_template == "ModEditor" then
			CreateRealTimeThread(function()
				local fmt = "Do you want to copy all properties from %s.%s?\n\nThe current values of the ModItem properties will be lost."
				local msg = string.format(fmt, preset_group, id)
				if ged:WaitQuestion("Warning", msg, "Yes", "No") ~= "ok" then
					self.__copy = nil
					ObjModified(self)
					return
				end
				do_copy()
			end)
		else
			do_copy()
		end
	end
end

---
--- Handles the logic for when a ModItemPreset is created or pasted in the editor.
--- If the ModItemPreset is created/pasted in a Mod Editor, it will be added to the mod's items list.
--- If the ModItemPreset is created/pasted in a Preset Editor, the mod reference will be set from there.
---
--- @param parent table The parent object of the ModItemPreset.
--- @param ged table The GED (Graphical Editor) instance.
--- @param is_paste boolean Whether the ModItemPreset was pasted or not.
--- @param duplicate_id string The ID of the duplicated ModItemPreset.
--- @param mod_id string The ID of the mod the ModItemPreset belongs to.
function ModItemPreset:OnAfterEditorNew(parent, ged, is_paste, duplicate_id, mod_id)
	-- Mod item presets can be added through Preset Editors (see GedOpClonePresetInMod)
	-- In those cases the reference to the mod will be added from there
	if ged and ged.app_template ~= "ModEditor" then
		if self.mod then
			-- Update the mod manually
			if self.mod:ItemsLoaded() and not self.mod:IsPacked() then
				table.insert(self.mod.items, self)
				self:MarkDirty()
				self.mod:MarkDirty()
			end
			ObjModifiedMod(self.mod)
		end
		return
	end
	
	self:MarkDirty()
end

---
--- Handles the logic for when a ModItemPreset is deleted from the editor.
--- If the ModItemPreset is deleted from a Preset Editor, it will be removed from the mod's items list.
--- If the ModItemPreset is deleted from a Mod Editor, the ModdedPresetClass will be marked as modified.
---
--- @param mod table The mod the ModItemPreset belongs to.
--- @param ged table The GED (Graphical Editor) instance.
---
function ModItemPreset:OnEditorDelete(mod, ged)
	-- Update the mod and Mod Editor tree panel whenever a mod item is deleted from a Preset Editor
	if ged and ged.app_template ~= "ModEditor" then
		if self.mod and self.mod:ItemsLoaded() and not self.mod:IsPacked() then
			local idx = table.find(self.mod.items, self)
			if idx then
				table.remove(self.mod.items, idx)
				self.mod:MarkDirty()
				ObjModifiedMod(self.mod)
			end
		end
		return
	end
	
	if Presets[self.ModdedPresetClass] then
		ObjModified(Presets[self.ModdedPresetClass])
	end
end

---
--- Tests the ModItemPreset by loading it, saving it, and reloading the Lua code if the mod's code was updated.
---
--- @param ged table The GED (Graphical Editor) instance.
---
function ModItemPreset:TestModItem(ged)
	self:PostLoad()
	if self:GetCodeFileName() then
		self:PostSave()
		if self.mod:UpdateCode() then
			ReloadLua()
		end
		ged:ShowMessage("Information", "The preset has been loaded and is currently active in the game.")
	end
end

---
--- Handles the logic for when a ModItemPreset is loaded.
--- Calls the base ModItem:OnModLoad() function and then calls the PostLoad() function.
---
--- @param self ModItemPreset The ModItemPreset instance.
---
function ModItemPreset:OnModLoad()
	ModItem.OnModLoad(self)
	self:PostLoad()
end

---
--- Returns a warning message if the ModItemPreset is in an invalid state.
---
--- @return string|nil The warning message, or nil if there are no warnings.
---
function ModItemPreset:GetWarning()
	local warning = g_Classes[self.ModdedPresetClass].GetWarning(self)
	return warning or
		self:IsDirty() and self:GetCodeFileName() and "Use the Test button or save the mod to test your changes."
end

---
--- Returns an error message if the ModItemPreset is in an invalid state.
---
--- @return string|nil The error message, or nil if there are no errors.
---
function ModItemPreset:GetError()
	if self.id == "" then
		return "Please specify mod item Id."
	end
	return g_Classes[self.ModdedPresetClass].GetError(self)
end

---
--- Indicates whether the ModItemPreset is read-only.
---
--- @return boolean True if the ModItemPreset is read-only, false otherwise.
---
function ModItemPreset:IsReadOnly()
	return false
end

---
--- Returns a list of ModResourcePreset objects that represent the resources affected by this ModItemPreset.
---
--- @return table<ModResourcePreset> The list of affected resources.
---
function ModItemPreset:GetAffectedResources()
	if self.ModdedPresetClass and self.id and self.id ~= "" then
		local affected_resources = {}
		table.insert(affected_resources, ModResourcePreset:new({
			mod = self.mod,
			Class = self.ModdedPresetClass,
			Id = self.id,
			ClassDisplayName = self.EditorName,
		}))
		return affected_resources
	end

	return empty_table
end

function OnMsg.ClassesPostprocess()
	ClassDescendantsList("ModItemPreset", function(name, class)
		class.PresetClass = class.PresetClass or class.ModdedPresetClass
	end)
end

function OnMsg.ModsReloaded()
	for class, presets in pairs(Presets) do
		_G[class]:SortPresets()
	end
end

----- ModResourcePreset - Describes a preset affected by a mod. The preset can be either added or replaced, or have a specific property value changed.
DefineClass.ModResourcePreset = {
	__parents = { "ModResourceDescriptor" },
	properties = {
		{ id = "Class", name = "Preset class", editor = "text", default = false, },
		{ id = "Id", name = "Preset id", editor = "text", default = false, },
		{ id = "Prop", name = "Preset property", editor = "text", default = false, },
		{ id = "ClassDisplayName", name = "Class display name", editor = "text", default = false, },
	},
}

---
--- Checks if the current ModResourcePreset conflicts with the provided `other` ModResourcePreset.
---
--- @param other ModResourcePreset The other ModResourcePreset to check for conflict.
--- @return boolean True if the ModResourcePresets conflict, false otherwise.
---
function ModResourcePreset:CheckForConflict(other)
	return self.Class and self.Class == other.Class and self.Id and self.Id == other.Id and ((self.Prop and self.Prop == other.Prop) or (not self.Prop or not other.Prop))
end

---
--- Returns a text description of the ModResourcePreset.
---
--- @return string The text description of the ModResourcePreset.
---
function ModResourcePreset:GetResourceTextDescription()
	return string.format("%s \"%s\"", self.ClassDisplayName or self.Class, self.Id)
end

----- ModItemLightmodel

DefineModItemPreset("LightmodelPreset", {
	EditorName = "Lightmodel",
	EditorSubmenu = "Other",
	properties = {
		{ id = "cubemap_capture_preview" },
		{ id = "exterior_envmap" },
		{ id = "ext_env_exposure" },
		{ id = "ExteriorEnvmapImage" },
		{ id = "interior_envmap" },
		{ id = "int_env_exposure" },
		{ id = "InteriorEnvmapImage" },
		{ id = "env_exterior_capture_sky_exp" },
		{ id = "env_exterior_capture_sun_int" },
		{ id = "env_exterior_capture_pos" },
		{ id = "env_interior_capture_sky_exp" },
		{ id = "env_interior_capture_sun_int" },
		{ id = "env_interior_capture_pos" },
		{ id = "env_capture_map" },
		{ id = "env_capture" },
		{ id = "env_view_site" },
		{ id = "hdr_pano" },
		{ id = "lm_capture" },
		{ id = "__" },
	},
	Documentation = "Define a set of lighting parameters controlling the look of the day/night cycle.",
	TestDescription = "Overrides the current lightmodel."
})

---
--- Checks if the current ModResourcePreset conflicts with the provided `other` ModResourcePreset.
---
--- @param other ModResourcePreset The other ModResourcePreset to check for conflict.
--- @return boolean True if the ModResourcePresets conflict, false otherwise.
---
function ModItemLightmodelPreset:GetCubemapWarning()
end

---
--- Tests the ModItemLightmodelPreset by setting the LightmodelOverride to the current preset.
---
--- @param ged GameEntityData The game entity data.
---
function ModItemLightmodelPreset:TestModItem(ged)
	SetLightmodelOverride(1, LightmodelOverride ~= self and self)
end

----- ModItemEntity

ModEntityClassesCombo = {
	"",
	--common
	"AnimatedTextureObject", "AutoAttachObject",
	"Deposition", "Decal", "FloorAlignedObj", "Mirrorable",
}

DefineClass.BaseModItemEntity = {
	__parents = { "ModItemUsingFiles", "BasicEntitySpecProperties" },
	properties = {
		{ category = "Mod", id = "name", name = "Name", default = "", editor = "text", untranslated = true },
		{ category = "Mod", id = "entity_name", name = "Entity Name", default = "", editor = "text", read_only = true, untranslated = true },
		{ category = "Misc", id = "class_parent", name = "Class", editor = "combo", items = ModEntityClassesCombo, default = "", entitydata = true }, 
	},
	TestDescription = "Loads the entity in the engine and places a dummy object with it."
}

---
--- Called when a new instance of the `BaseModItemEntity` class is created in the editor.
--- Sets the `name` property to "Entity" if it is an empty string, otherwise leaves it unchanged.
---
--- @param mod ModItem The mod item that this entity belongs to.
--- @param ged GameEntityData The game entity data for this entity.
--- @param is_paste boolean True if this entity was pasted from another location, false otherwise.
---
function BaseModItemEntity:OnEditorNew(mod, ged, is_paste)
	self.name = self.name == "" and "Entity" or self.name
end

---
--- Imports the entity data for the `BaseModItemEntity` class.
---
--- @param root any The root object for the import.
--- @param prop_id string The ID of the property being imported.
--- @param socket any The socket object for the import.
--- @param btn_param any The button parameter for the import.
--- @param idx number The index of the import.
---
function BaseModItemEntity:Import(root, prop_id, socket, btn_param, idx)
end

---
--- Reloads all entities in the mod.
---
--- This function is called to reload all entities in the mod. It triggers the `ModsLoadAssets()` function, which is responsible for loading all mod assets, including entities.
---
--- @param root any The root object for the reload.
--- @param prop_id string The ID of the property being reloaded.
--- @param socket any The socket object for the reload.
--- @param btn_param any The button parameter for the reload.
--- @param idx number The index of the reload.
---
function BaseModItemEntity:ReloadEntities(root, prop_id, socket, btn_param, idx)
	ModsLoadAssets()
end

---
--- Exports the entity data for the `BaseModItemEntity` class.
---
--- This function is responsible for exporting the entity data for the `BaseModItemEntity` class. It calls the `ExportEntityDataForSelf()` function to get the base entity data, and then sets the `editor_artset` property to "Mods".
---
--- @return table The exported entity data.
---
function BaseModItemEntity:ExportEntityData()
	local data = self:ExportEntityDataForSelf()
	data.editor_artset = "Mods"
	return data
end

---
--- Saves the entity data for the `BaseModItemEntity` class.
---
--- This function is called after the mod item is saved. It exports the entity data for the `BaseModItemEntity` class and saves it to a file in the "Entities" directory of the mod's content path. The file name is based on the `entity_name` property of the `BaseModItemEntity` class.
---
--- @param ... any Additional arguments passed to the `PostSave` function.
---
function BaseModItemEntity:PostSave(...)
	ModItem.PostSave(self, ...)
	if self.entity_name == "" then return end
	local data = self:ExportEntityData()
	if not next(data) then return end
	local code = string.format("EntityData[\"%s\"] = %s", self.entity_name, ValueToLuaCode(data))
	local path = self:GetCodeFilePath()
	local folder = SplitPath(path)
	AsyncCreatePath(folder)
	AsyncStringToFile(path, code)
end

---
--- Gets the file name for the entity data.
---
--- This function is responsible for generating the file name for the entity data. It first checks if the `entity_name` property is empty, and if so, returns. Otherwise, it exports the entity data using the `ExportEntityData()` function, and then generates the file name by formatting the entity name with the "Entities/" prefix and the ".lua" extension.
---
--- @return string The file name for the entity data.
---
function BaseModItemEntity:GetCodeFileName()
	if self.entity_name == "" then return end
	local data = self:ExportEntityData()
	if not next(data) then return end
	return string.format("Entities/%s.lua", self.entity_name)
end

---
--- Tests a mod item by placing it in the game world.
---
--- This function is responsible for testing a mod item by placing it in the game world. It first checks if the `entity_name` property is empty, and if so, returns. Otherwise, it updates the mod code, loads the entity, waits for the delayed load entities, and forces the entity-related structures to reload. It then checks if a map is loaded, and if not, logs a message and returns. Finally, it places an object with the entity name at the cursor position and views the object.
---
--- @param ged any Additional arguments passed to the function.
---
function BaseModItemEntity:TestModItem(ged)
	if self.entity_name == "" then return end
	
	self.mod:UpdateCode()
	DelayedLoadEntity(self.mod, self.entity_name)
	WaitDelayedLoadEntities()
	Msg("BinAssetsLoaded") -- force entity-related structures reload - not needed for this visualization, but necessary to use this e.g. in a building a bit later
	ReloadLua()
	
	if GetMap() == "" then
		ModLogF("Entity testing only possible when a map is loaded")
		return
	end
	
	local obj = PlaceObject("Shapeshifter")
	obj:ChangeEntity(self.entity_name)
	obj:SetPos(GetTerrainCursorXY(UIL.GetScreenSize()/2))
	if IsEditorActive() then
		EditorViewMapObject(obj, nil, true)
	else
		ViewObject(obj)
	end
end

---
--- Checks if the mod item needs to be resaved.
---
--- This function checks if the mod's bin_assets property is true, which indicates that the mod item needs to be resaved.
---
--- @return boolean True if the mod item needs to be resaved, false otherwise.
---
function BaseModItemEntity:NeedsResave()
	if self.mod.bin_assets then return true end
end

local function DeleteIfEmpty(path)
	local err, files = AsyncListFiles(path, "*", "recursive")
	local err, folders = AsyncListFiles(path, "*", "recursive,folders")
	if #files == 0 and #folders == 0 then
		AsyncDeletePath(path)
	end
end

---
--- Gets a list of files associated with the mod item's entity.
---
--- This function retrieves a list of all files associated with the mod item's entity, including the .ent and .lua files, as well as any meshes, animations, materials, and textures. It first checks if the entity_name property is empty, and if so, returns. Otherwise, it parses the entity information and builds a list of all the relevant files. The function then removes any duplicate files from the list and returns the trimmed list.
---
--- @return table A list of file paths for the mod item's entity.
---
function BaseModItemEntity:GetFilesList()
	if self.entity_name == "" then return end
	local entity_root = self.mod.content_path .. "Entities/"
	local entity_name = self.entity_name
	local err, entity = ParseEntity(entity_root, entity_name)
	if err then
		return
	end
	
	local files_list = {}
	
	table.insert(files_list, entity_root .. entity_name .. ".ent")
	table.insert(files_list, entity_root .. entity_name .. ".lua")
	
	for _, name in ipairs(entity.meshes) do
		table.insert(files_list, entity_root .. name .. ".hgm")
	end
	for _, name in ipairs(entity.animations) do
		if io.exists(entity_root .. name .. ".hga") then
			table.insert(files_list, entity_root .. name .. ".hga")
		else
			table.insert(files_list, entity_root .. name .. ".hgacl")
		end
	end
	for _, name in ipairs(entity.materials) do
		table.insert(files_list, entity_root .. name .. ".mtl")
	end
	for _, name in ipairs(entity.textures) do
		table.insert(files_list, entity_root .. "Textures/" .. name .. ".dds")
		table.insert(files_list, entity_root .. "Textures/Fallbacks/" .. name .. ".dds")
	end
	
	-- remove duplicates
	local trimmed_files_list = {}
	for _, filename in ipairs(files_list) do
		if not files_list[filename] then
			files_list[filename] = true
			table.insert(trimmed_files_list, filename)
		end
	end
	return trimmed_files_list
end

---
--- Checks if the given mod item entity already exists in the specified mod.
---
--- @param mod table The mod to check for duplicates.
--- @param entity_name string The name of the entity to check for duplicates.
--- @return boolean True if the entity already exists in the mod, false otherwise.
---
function BaseModItemEntity:IsDuplicate(mod, entity_name)
	mod = mod or self.mod
	entity_name = entity_name or self.entity_name
	return mod:ForEachModItem("BaseModItemEntity", function(mc)
		if mc.entity_name == entity_name and mc ~= self then
			return true
		end
	end)
end

---
--- Resolves any conflicts that may arise when pasting a mod item entity.
---
--- If the entity name already exists in the mod, the function will create an empty entity instead, log a warning, and disable copying the files.
--- If the entity is being copied from a different mod, the function will update the file paths to use the current mod's ID.
---
--- @param ged table The game editor object.
---
function BaseModItemEntity:ResolvePasteFilesConflicts(ged)
	if self.entity_name and self:IsDuplicate(self.mod, self.entity_name) then
		ModLogF(string.format("Entity <%s> already exists in mod <%s>! Created empty entity, instead.", self.entity_name, self.mod.id))
		self.CopyFiles = false
		self.entity_name = ""
		self.name = "Entity"
		return
	end
	
	local prev_mod_id = self.CopyFiles.mod_id
	for _, file in ipairs(self.CopyFiles) do
		if prev_mod_id ~= self.mod.id then 
			file.filename = file.filename:gsub(prev_mod_id, self.mod.id)
		end
	end
end

local function CleanEntityFolders(entity_root, entity_name)
	DeleteIfEmpty(entity_root .. "Meshes/")
	DeleteIfEmpty(entity_root .. "Animations/")
	DeleteIfEmpty(entity_root .. "Materials/")
	DeleteIfEmpty(entity_root .. "Textures/Fallbacks/")
	DeleteIfEmpty(entity_root .. "Textures/")
	DeleteIfEmpty(entity_root)
end

---
--- Cleans up the entity folders when the entity is deleted from the editor.
---
--- @param mod table The mod that the entity belongs to.
--- @param ged table The game editor object.
---
function BaseModItemEntity:OnEditorDelete(mod, ged)
	if self.entity_name == "" then return end
	local entity_root = self.mod.content_path .. "Entities/"
	CleanEntityFolders(entity_root, self.entity_name)
end

---
--- Gets a list of all mod entities.
---
--- @param typ string (optional) The type of mod entities to retrieve. If not provided, all types will be returned.
--- @return table A list of mod entity names.
---
function GetModEntities(typ)
	local results = {}
	-- ignore type for now, return all types
	for _, mod in ipairs(ModsLoaded) do
		mod:ForEachModItem("BaseModItemEntity", function(mc)
			if mc.entity_name ~= "" then
				results[#results + 1] = mc.entity_name
			end
		end)
	end
	table.sort(results)
	return results
end

if FirstLoad then
	EntityLoadEntities = {}
end

---
--- Delays the loading of a mod entity until all other entities have been loaded.
---
--- This function is used to ensure that mod entities are loaded in the correct order, after all other
--- entities have been loaded. This helps prevent issues where a mod entity depends on other entities
--- that have not yet been loaded.
---
--- @param mod table The mod that the entity belongs to.
--- @param entity_name string The name of the entity to load.
---
function DelayedLoadEntity(mod, entity_name)
	local idx = table.find(EntityLoadEntities, 2, entity_name)
	if idx then
		if mod == EntityLoadEntities[idx][1] then
			return
		end
		ModLogF(true, "%s overrides entity %s from %s", mod.id, entity_name, EntityLoadEntities[idx][1].id)
		table.remove(EntityLoadEntities, idx)
	end
	local entity_filename = mod.content_path .. "Entities/" .. entity_name .. ".ent"
	if not io.exists(entity_filename) then
		ModLogF(true, "Failed to open entity file %s", entity_filename)
		return
	end
	EntityLoadEntities[#EntityLoadEntities+1] = {mod, entity_name, entity_filename}
end

---
--- Waits for and loads any delayed mod entities.
---
--- This function is called to load any mod entities that were delayed during the initial entity loading process.
--- It will load the delayed entities, reload the fade categories, reload the class entities, and log any failures.
---
function WaitDelayedLoadEntities()
	if #EntityLoadEntities > 0 then
		local list = EntityLoadEntities
		EntityLoadEntities = {}
		AsyncLoadAdditionalEntities( table.map(list, 3) )
		ReloadFadeCategories(true)
		ReloadClassEntities()
		Msg("EntitiesLoaded")
		Msg("AdditionalEntitiesLoaded")

		for i, data in ipairs(list) do
			if not IsValidEntity(data[2]) then
				ModLogF(true, "Mod %s failed to load %s", data[1]:GetModLabel("plainText"), data[2])
			end
		end
	end
end

---
--- Registers delayed loading of mod entities.
---
--- This function is used to ensure that mod entities are loaded in the correct order, after all other
--- entities have been loaded. This helps prevent issues where a mod entity depends on other entities
--- that have not yet been loaded.
---
--- @param mods table A table of mods to register delayed entity loading for.
---
function RegisterModDelayedLoadEntities(mods)
	for i, mod in ipairs(mods) do
		for j, entity_name in ipairs(mod.entities) do
			DelayedLoadEntity(mod, entity_name)
		end
	end
end

----

DefineClass.ModItemEntity = {
	__parents = { "BaseModItemEntity", "EntitySpecProperties" },
	
	EditorName = "Entity",
	EditorSubmenu = "Assets",
	
	properties = {
		{ category = "Mod", id = "import", name = "Import", editor = "browse", os_path = "AppData/ExportedEntities/", filter = "Entity files|*.ent", default = "", dont_save = true},
		{ category = "Mod", id = "buttons", editor = "buttons", default = false, buttons = {{name = "Import Entity Files", func = "Import"}, {name = "Reload entities (slow)", func = "ReloadEntities"}}, untranslated = true},
	},
	Documentation = "Imports art assets from Blender.",
	DocumentationLink = "Docs/ModItemEntity.md.html"
}

if Platform.developer then
	g_HgnvCompressPath = "svnSrc/Tools/hgnvcompress/Bin/hgnvcompress.exe"
	g_HgimgcvtPath = "svnSrc/Tools/hgimgcvt/Bin/hgimgcvt.exe"
	g_OpusCvtPath = "svnSrc/ExternalTools/opusenc.exe"
else
	g_HgnvCompressPath = "ModTools/AssetsProcessor/hgnvcompress.exe"
	g_HgimgcvtPath = "ModTools/hgimgcvt.exe"
	g_OpusCvtPath = "ModTools/opusenc.exe"
end

---
--- Parses an entity file and extracts the materials, meshes, animations, and textures.
---
--- @param root string The root directory of the entity file.
--- @param name string The name of the entity file.
--- @return string|nil, table The error message if an error occurred, or a table containing the extracted asset information.
---
function ParseEntity(root, name)
	local filename = root .. name .. ".ent"
	local err, xml = AsyncFileToString(filename)
	if err then return err end
	
	local entity = { materials = {}, meshes = {}, animations = {}, textures = {} }
	for asset in string.gmatch(xml, "<material file=\"(.-)%.mtl\"") do
		entity.materials[#entity.materials+1] = asset
	end
	for asset in string.gmatch(xml, "<anim file=\"(.-)%.hgac?l?\"") do
		entity.animations[#entity.animations+1] = asset
	end
	for asset in string.gmatch(xml, "<mesh file=\"(.-)%.hgm\"") do
		entity.meshes[#entity.meshes+1] = asset
	end
	for _, material in ipairs(entity.materials) do
		local err, mtl = AsyncFileToString(root .. material .. ".mtl")
		for map in string.gmatch(mtl, "Map Name=\"(.-)%.dds") do	
			entity.textures[#entity.textures+1] = map
		end
	end
	return nil, entity
end

---
--- Checks if the entity file for the current ModItem exists.
---
--- @return string|nil The error message if the entity file does not exist, or nil if it does exist.
---
function ModItemEntity:GetError()
	local entityName = self.entity_name
	if entityName and entityName ~= "" then
		if not io.exists(self.mod.content_path .. "Entities/" .. entityName .. ".ent") then
			return string.format("Cannot find entity file for %s", entityName)
		end
	end
end

---
--- Imports an entity file into the mod.
---
--- @param root string The root directory of the entity file.
--- @param prop_id string The property ID of the ModItem.
--- @param socket table The UI socket to display messages.
--- @param btn_param table The button parameters.
--- @param idx number The index of the ModItem.
--- @return nil
---
function ModItemEntity:Import(root, prop_id, socket, btn_param, idx)
	local import_root, entity_name, ext = SplitPath(self.import)
	if not entity_name or entity_name == "" then
		ModLogF(true, "Invalid entity filename")
		return
	end
	
	if self:IsDuplicate(self.mod, entity_name) then
		socket:ShowMessage("Duplicate Entity!", string.format("An Entity for <%s> already exists in this mod!", entity_name))
		return
	end
	
	local entity_root = self.mod.content_path .. "Entities/"
	local err = AsyncCreatePath(entity_root)
	if err then
		ModLogF(true, "Failed to create path %s: %s", entity_root, err)
	end

	ModLogF("Importing entity %s", entity_name)

	local dest_path = entity_root .. entity_name .. ext
	err = AsyncCopyFile(self.import, dest_path)
	if err then 
		ModLogF(true, "Failed to copy entity %s to %s: %s", entity_name, dest_path, err)
		return
	end
	
	local err, entity = ParseEntity(import_root, entity_name)
	if err then
		ModLogF(true, "Failed to open entity file %s: %s", dest_path, err)
		return
	end
	
	local function CopyAssetType(folder, tbl, exts, asset_type)
		local dest_path = entity_root .. folder
		
		for _, asset in ipairs(entity[tbl]) do
			local err = AsyncCreatePath(dest_path)
			if err then 
				ModLogF(true, "Failed to create path %s: %s", dest_path, err)
				break
			end
			local matched = false
			for _,ext in ipairs(type(exts) == "table" and exts or {exts}) do
				local src_filename
				if string.starts_with(asset, folder) then
					src_filename = import_root .. asset .. ext
				else
					src_filename = import_root .. folder .. asset .. ext
				end
				if io.exists(src_filename) then
					local dest_filename
					if string.starts_with(asset, folder) then
						dest_filename = entity_root .. asset .. ext
					else
						dest_filename = entity_root .. folder .. asset .. ext
					end
					err = AsyncCopyFile(src_filename, dest_filename)
					if err then
						ModLogF(true, "Failed to copy %s to %s: %s", src_filename, dest_filename, err)
					else
						ModLogF("Importing %s %s", asset_type, asset)
						ReloadEntityResource(dest_filename, "modified")
					end
					matched = true
				end
			end
			if not matched then
				ModLogF(true, "Missing file %s referenced in entity", asset)
			end
		end
	end
	
	CopyAssetType("Meshes/", "meshes", ".hgm", "mesh")
	CopyAssetType("Animations/", "animations", { ".hga", ".hgacl" }, "animation")
	CopyAssetType("Materials/", "materials", ".mtl", "material")
	CopyAssetType("Textures/", "textures", ".dds", "texture")
	
	local dest_path = entity_root .. "Textures/Fallbacks/"
	for _, asset in ipairs(entity.textures) do
		local err = AsyncCreatePath(dest_path)
		if err then 
			ModLogF(true, "Failed to create path %s: %s", dest_path, err)
			break
		end
		local src_filename = entity_root .. "Textures/" .. asset .. ".dds"
		local dest_filename = dest_path .. asset .. ".dds"
		local cmdline =  string.format("\"%s\" \"%s\" \"%s\" --truncate %d", ConvertToOSPath(g_HgimgcvtPath), ConvertToOSPath(src_filename), ConvertToOSPath(dest_filename), 64)
		local err = AsyncExec(cmdline, ".", true)
		if err then
			ModLogF(true, "Failed to generate backup for <%s: %s", asset, err)
		end
	end
	
	self.name = entity_name
	
	self.entity_name = entity_name
	self:StoreOSPaths()
	
	ObjModified(self)
end

----- ModItemFont

if FirstLoad then
	g_FontReplaceMap = {}
end

DefineClass.FontAsset = {
	__parents = { "InitDone" },
	
	properties = {
		{ id = "FontPath", name = "Font path", editor = "browse", 
			default = false, filter = "Font files|*.ttf;*.otf", 
			mod_dst = function() return GetModAssetDestFolder("Font") end },
	},
}

---
--- Finalizes the FontAsset object by deleting the font file associated with it.
--- This function is called when the FontAsset object is being destroyed.
---
--- @param self FontAsset The FontAsset object being finalized.
---
function FontAsset:Done()
	if self.FontPath then
		AsyncDeletePath(self.FontPath)
	end
end

---
--- Loads a font file at the specified path.
---
--- @param self FontAsset The FontAsset object.
--- @param font_path string The path to the font file to load.
--- @return boolean true if the font was loaded successfully, false otherwise.
---
function FontAsset:LoadFont(font_path)
	local file_list = {}
	table.insert(file_list, font_path)
	UIL.LoadFontFileList(file_list) -- !TODO: previously loaded fonts were reported as failure, incorrectly, see mantis 241725
	return true
end

---
--- Handles the event when the FontPath property of a FontAsset object is set in the editor.
--- This function is responsible for deleting the old font file, loading the new font file, and displaying success/failure messages.
---
--- @param self FontAsset The FontAsset object.
--- @param prop_id string The ID of the property that was set.
--- @param old_value string The previous value of the FontPath property.
--- @param ged table The GED (Game Editor) object associated with the FontAsset.
---
function FontAsset:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "FontPath" then				
		GedSetUiStatus("mod_import_font_asset", "Importing font...")
		-- Delete the old font file if there's one
		if old_value then
			AsyncDeletePath(old_value)
		end

		-- Load the new font
		if self.FontPath then
			local ok = self:LoadFont(self.FontPath)
			if not ok then
				ged:ShowMessage("Failed importing font", "The font file could not be processed correctly. Please try another font file or format. \nRead the mod item font documentation for more details on supported formats.")
				AsyncDeletePath(self.FontPath)
				self.FontPath = nil
			else
				ged:ShowMessage("Success", "Font loaded successfully.")
			end
		end
		
		GedSetUiStatus("mod_import_font_asset")
	end
end

local function font_items()
	return UIL.GetAllFontNames()
end

DefineClass.FontReplaceMapping = {
	__parents = { "InitDone" },
	
	properties = {
		{ id = "Replace", name = "Replace", editor = "choice", default = false, items = font_items },
		{ id = "With", name = "With", editor = "choice", default = false, items = font_items },
	},
}

---
--- Removes the font replacement mapping for the specified font.
---
--- @param self FontReplaceMapping The FontReplaceMapping object.
---
function FontReplaceMapping:Done()
	if self.Replace and g_FontReplaceMap then
		g_FontReplaceMap[self.Replace] = nil
	end
end

---
--- Updates the font replacement mapping when the "Replace" or "With" properties are changed.
---
--- If the "Replace" property is changed, the old font replacement is removed from the global `g_FontReplaceMap`.
---
--- If both "Replace" and "With" properties are set, a new font replacement mapping is added to the global `g_FontReplaceMap`.
---
--- Triggers a "TranslationChanged" message when the font replacement mapping is updated.
---
--- @param self FontReplaceMapping The FontReplaceMapping object.
--- @param prop_id string The property ID that was changed.
--- @param old_value any The old value of the changed property.
--- @param ged table The GED (Game Editor) object associated with the FontReplaceMapping.
---
function FontReplaceMapping:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "Replace" then
		if old_value and g_FontReplaceMap then
			g_FontReplaceMap[old_value] = nil
		end
	end
	
	if self.Replace and self.With and g_FontReplaceMap then
		g_FontReplaceMap[self.Replace] = self.With
		Msg("TranslationChanged")
	end
end

DefineClass.ModItemFont = {
	__parents = { "ModItemUsingFiles", },

	properties = {
		{ category = "Font assets", id = "AssetFiles", name = "Font asset files", editor = "nested_list", default = false, 
			base_class = "FontAsset", auto_expand = true, help = "Import TTF and OTF font files to be loaded into the game", },	
		
		{ category = "Font replace mapping", id = "ReplaceMappings", name = "Font replace mappings", editor = "nested_list", 
			default = false, base_class = "FontReplaceMapping", auto_expand = true, 
			help = "Choose fonts to replace and which fonts to replace them with", },
		
		{ category = "Font replace mapping", id = "TextStylesHelp", name = "TextStyles help", editor = "help", default = false, 
			help = "You can also replace individual text styles by adding \"TextStyle\" mod items.", },
	},
	
	EditorName = "Font",
	EditorSubmenu = "Assets",
	Documentation = "Imports new font files and defines which in-game fonts should be replaced by them.",
	DocumentationLink = "Docs/ModItemFont.md.html"
}

---
--- Initializes a new ModItemFont instance when it is created in the editor.
---
--- @param mod ModItem The ModItem instance that this ModItemFont belongs to.
--- @param ged table The GED (Game Editor) object associated with this ModItemFont.
--- @param is_paste boolean Whether this ModItemFont was created by pasting an existing one.
---
function ModItemFont:OnEditorNew(mod, ged, is_paste)
	self.name = "Font"
end

---
--- Returns the target path for font assets.
---
--- @return string The target path for font assets.
---
function ModItemFont:GetFontTargetPath()
	return SlashTerminate(self.mod.content_path) .. "Fonts"
end

---
--- Loads font assets, applies font replace mappings, and sends a "TranslationChanged" message when the mod is loaded.
---
--- This function is called when the ModItemFont instance is loaded as part of a mod.
---
function ModItemFont:OnModLoad()
	self:LoadFonts()
	self:ApplyFontReplaceMapping()
	Msg("TranslationChanged")
	
	ModItem.OnModLoad(self)
end

---
--- Removes any font replace mappings defined by this ModItemFont instance when the mod is unloaded, and sends a "TranslationChanged" message.
---
--- This function is called when the ModItemFont instance is unloaded as part of a mod.
---
function ModItemFont:OnModUnload()
	self:RemoveFontReplaceMapping()
	Msg("TranslationChanged")
	
	return ModItem.OnModUnload(self)
end

---
--- Loads font assets defined in the ModItemFont instance.
---
--- This function is called when the ModItemFont instance is loaded as part of a mod.
---
--- @return boolean True if the font files were successfully loaded, false otherwise.
---
function ModItemFont:LoadFonts()
	if not self.AssetFiles then return false end
	
	local file_list = {}
	for _, font_asset in ipairs(self.AssetFiles) do
		if font_asset.FontPath then
			table.insert(file_list, font_asset.FontPath)
		end
	end
	return UIL.LoadFontFileList(file_list)
end

---
--- Applies font replace mappings defined in the ModItemFont instance to the global g_FontReplaceMap.
---
--- This function is called when the ModItemFont instance is loaded as part of a mod.
---
--- @return boolean True if the font replace mappings were successfully applied, false otherwise.
---
function ModItemFont:ApplyFontReplaceMapping()
	if not self.ReplaceMappings or not g_FontReplaceMap then return false end
	
	for _, mapping in ipairs(self.ReplaceMappings) do
		if mapping.Replace and mapping.With then
			g_FontReplaceMap[mapping.Replace] = mapping.With
		end
	end
end

---
--- Removes any font replace mappings defined by this ModItemFont instance from the global g_FontReplaceMap.
---
--- This function is called when the ModItemFont instance is unloaded as part of a mod.
---
--- @return boolean True if the font replace mappings were successfully removed, false otherwise.
---
function ModItemFont:RemoveFontReplaceMapping()
	if not self.ReplaceMappings or not g_FontReplaceMap then return false end
	
	for _, mapping in ipairs(self.ReplaceMappings) do
		if mapping.Replace then
			g_FontReplaceMap[mapping.Replace] = nil
		end
	end
end

---
--- Returns a list of ModResourceFont instances that represent the font resources affected by the font replace mappings defined in this ModItemFont instance.
---
--- @return table<ModResourceFont> A table of ModResourceFont instances representing the affected font resources.
---
function ModItemFont:GetAffectedResources()
	if self.ReplaceMappings then
		local affected_resources = {}	
		for _, mapping in ipairs(self.ReplaceMappings) do
			if mapping.Replace and mapping.With then
				table.insert(affected_resources, ModResourceFont:new({
					mod = self.mod,
					Font = mapping.Replace
				}))
			end
		end
		return affected_resources
	end
	
	return empty_table
end

---
--- Returns a list of file paths for the font assets associated with this ModItemFont instance.
---
--- @return table<string> A table of file paths for the font assets.
---
function ModItemFont:GetFilesList()
	local slf = self
	local files_list = {}
	for _, font_asset in ipairs(self.AssetFiles) do
		table.insert(files_list, font_asset.FontPath or "")
	end
	return files_list
end

---
--- Finds a free filename by appending a number to the end of the provided name if a file with that name already exists.
---
--- @param name string The base filename to check for availability.
--- @return string The available filename.
---
function ModItemFont:FindFreeFilename(name)
	if name == "" then return name end
	local n = 1
	local folder, file_name, ext = SplitPath(name)
	local matching_digits = file_name:match("(%d*)$")
	local n = matching_digits and tonumber(matching_digits) or -1
	file_name = file_name:sub(1, file_name:len() - matching_digits:len())
	while io.exists(folder .. (file_name .. tostring(n > 0 and n or "")) .. ext) do
		n = n + 1
	end
	return folder .. (file_name .. tostring(n > 0 and n or "")) .. ext
end

---
--- Resolves any conflicts that may arise when pasting files for a ModItemFont instance.
---
--- This function iterates through the `CopyFiles` table and updates the `filename` property of each entry to use the mod's content path instead of the original mod content path. It then calls `FindFreeFilename` to ensure the filename is unique, and updates the `FontPath` property of the corresponding `AssetFiles` entry if the `data` property is not nil.
---
--- @param self ModItemFont The ModItemFont instance.
---
function ModItemFont:ResolvePasteFilesConflicts()
	for index, _ in ipairs(self.CopyFiles) do
		self.CopyFiles[index].filename = self.CopyFiles[index].filename:gsub(self.CopyFiles.mod_content_path, self.mod.content_path)
		self.CopyFiles[index].filename = self:FindFreeFilename(self.CopyFiles[index].filename)
		if self.CopyFiles[index].data then
			self.AssetFiles[index].FontPath = self.CopyFiles[index].filename
		end
	end
end

---
--- Called after a new ModItemFont instance is created in the editor.
--- This function creates the target path for the font files associated with this ModItemFont instance.
---
--- @param parent any The parent object of the ModItemFont instance.
--- @param ged any The editor GUI element associated with the ModItemFont instance.
--- @param is_paste boolean Whether the ModItemFont instance was created by pasting.
---
function ModItemFont:OnAfterEditorNew(parent, ged, is_paste)
	local err = AsyncCreatePath(self:GetFontTargetPath())
end

----- ModResourceFont - Describes a font replaced by a mod.
DefineClass.ModResourceFont = {
	__parents = { "ModResourceDescriptor" },
	properties = {
		{ id = "Font", name = "Font name", editor = "text", default = false, },
	},
}

---
--- Checks if the current ModResourceFont instance has a conflict with another ModResourceFont instance.
---
--- @param self ModResourceFont The current ModResourceFont instance.
--- @param other ModResourceFont The other ModResourceFont instance to check for conflicts.
--- @return boolean True if the Font property of the two instances are the same, false otherwise.
---
function ModResourceFont:CheckForConflict(other)
	return self.Font and self.Font == other.Font
end

---
--- Returns a text description of the ModResourceFont instance.
---
--- @param self ModResourceFont The ModResourceFont instance.
--- @return string The text description of the font.
---
function ModResourceFont:GetResourceTextDescription()
	return string.format("\"%s\" font", self.Font)
end

----- ModItemDecalEntity

local size_items = {
	{ id = "Small", name = "Small (10cm x 10cm)" },
	{ id = "Medium", name = "Medium (1m x 1m)" },
	{ id = "Large", name = "Large (10m x 10m)" },
}

local decal_group_items = {
	"Default", "Terrain", "TerrainOnly", "Unit",
}

DefineClass.ModItemDecalEntity =  {
	__parents = { "BaseModItemEntity" },
	
	EditorName = "Decal",
	EditorSubmenu = "Assets",
	
	properties = {
		{ category = "Decal", id = "size",         name = "Size", editor = "choice", default = "Small", items = size_items },
		{ category = "Decal", id = "BaseColorMap", name = "Basecolor map", editor = "browse", os_path = true, filter = "Image files|*.png;*.tga", default = "", mtl_map = "BaseColorDecal", dont_save = true },
		{ category = "Decal", id = "NormalMap",    name = "Normal map", editor = "browse", os_path = true, filter = "Image files|*.png;*.tga", default = "", mtl_map = "NormalMapDecal", dont_save = true },
		{ category = "Decal", id = "RMMap",        name = "Roughness/metallic map", editor = "browse", os_path = true, filter = "Image files|*.png;*.tga", default = "", mtl_map = "RMDecal", dont_save = true },
		{ category = "Decal", id = "AOMap",        name = "Ambient occlusion map", editor = "browse", os_path = true, filter = "Image files|*.png;*.tga", default = "", mtl_map = "AODecal", dont_save = true },
		{ category = "Decal", id = "TriplanarDecal",   name = "Triplanar",    editor = "bool",   default = false, mtl_prop = true, help = "When toggled the decal is projected along every axis, not only forward." },
		{ category = "Decal", id = "DoubleSidedDecal", name = "Double sided", editor = "bool",   default = true, mtl_prop = true, help = "When toggled the decal can be seen from the backside as well. This is useful for objects that can be hidden, like wall slabs." },
		{ category = "Decal", id = "DecalGroup",       name = "Group",        editor = "choice", default = "Default", items = decal_group_items, mtl_prop = true, help = "Determines what objects will have the decal projected onto.\n\nDefault - everything\nTerrain - the terrain, slabs and small terrain objects like grass, rocks and others\nTerrainOnly - only the terrain\nUnit - only units" },
		{ category = "Mod",   id = "entity_name", name = "Entity Name", default = "", editor = "text", untranslated = true },
		{ category = "Mod", id = "buttons", editor = "buttons", default = false, buttons = {{name = "Import Decal Files", func = "Import"}, {name = "Reload entities (slow)", func = "ReloadEntities"}}, untranslated = true},
		{ category = "Misc", id = "class_parent", name = "Class", editor = "combo", items = ClassDescendantsCombo("Decal", true), default = "", entitydata = true }, 
	},
	Documentation = "Defines decal which can be placed via the ActionFXDecal mod item.",
}

---
--- Imports a decal entity into the game.
---
--- @param root table The root table of the mod.
--- @param prop_id string The ID of the property being imported.
--- @param ged_socket table The GED socket used for importing.
---
--- This function performs the following steps:
--- 1. Composes the necessary folder paths for the decal entity.
--- 2. Creates the required directories for the entity, meshes, materials, and textures.
--- 3. Processes any image properties and imports them into the appropriate directories.
--- 4. Composes the file names for the entity, material, and mesh files.
--- 5. Creates the entity file, material file, and mesh file.
--- 6. Calls the OnModLoad() function and waits for delayed load entities.
--- 7. Sends a "BinAssetsLoaded" message.
--- 8. Sets the UI status and displays a success message.
---
function ModItemDecalEntity:Import(root, prop_id, ged_socket)
	GedSetUiStatus("mod_import_decal", "Importing...")
	
	local success = self:DoImport(root, prop_id, ged_socket)
	if not success then
		GedSetUiStatus("mod_import_decal")
		return
	end
	
	self:OnModLoad()
	WaitDelayedLoadEntities()
	Msg("BinAssetsLoaded")
	
	GedSetUiStatus("mod_import_decal")
	ged_socket:ShowMessage("Success", "Decal imported successfully!")
end

---
--- Imports a decal entity into the game.
---
--- @param root table The root table of the mod.
--- @param prop_id string The ID of the property being imported.
--- @param ged_socket table The GED socket used for importing.
---
--- This function performs the following steps:
--- 1. Composes the necessary folder paths for the decal entity.
--- 2. Creates the required directories for the entity, meshes, materials, and textures.
--- 3. Processes any image properties and imports them into the appropriate directories.
--- 4. Composes the file names for the entity, material, and mesh files.
--- 5. Creates the entity file, material file, and mesh file.
--- 6. Calls the OnModLoad() function and waits for delayed load entities.
--- 7. Sends a "BinAssetsLoaded" message.
--- 8. Sets the UI status and displays a success message.
---
function ModItemDecalEntity:DoImport(root, prop_id, ged_socket)
	--Compose folder paths
	local output_dir = ConvertToOSPath(self.mod.content_path)
	local ent_dir = output_dir .. "Entities/"
	local mesh_dir = ent_dir .. "Meshes/"
	local mtl_dir = ent_dir .. "Materials/"
	local texture_dir = ent_dir .. "Textures/"
	local fallback_dir = texture_dir .. "Fallbacks/"
	--Create folder structure
	if not self:CreateDirectory(ged_socket, ent_dir, "Entities") then return end
	if not self:CreateDirectory(ged_socket, mesh_dir, "Meshes") then return end
	if not self:CreateDirectory(ged_socket, mtl_dir, "Materials") then return end
	if not self:CreateDirectory(ged_socket, texture_dir, "Textures") then return end
	if not self:CreateDirectory(ged_socket, fallback_dir, "Fallbacks") then return end
	
	--Process images
	for i,prop_meta in ipairs(self:GetProperties()) do
		if prop_meta.mtl_map then
			local path = self:GetProperty(prop_meta.id)
			if path ~= "" then
				if not self:ImportImage(ged_socket, prop_meta.id, texture_dir, fallback_dir) then
					return
				end
			end
		end
	end
	
	--Compose file names
	local ent_file = self.entity_name .. ".ent"
	local ent_output = ent_dir .. ent_file
	
	local mtl_file = self.entity_name .. "_mesh.mtl"
	local mtl_output = mtl_dir .. mtl_file
	
	local mesh_file = self.entity_name .. "_mesh.hgm"
	local mesh_output = mesh_dir .. mesh_file
	
	--Create the entity file
	if not self:CreateEntityFile(ged_socket, ent_output, mesh_file, mtl_file) then
		return
	end
	
	--Create the material file
	if not self:CreateMtlFile(ged_socket, mtl_output) then
		return
	end
	
	--Create the mesh file
	if not self:CreateMeshFile(ged_socket, mesh_output) then
		return
	end
	
	return true
end

---
--- Creates a directory at the specified path.
---
--- @param ged_socket table The GED socket object.
--- @param path string The path to create the directory at.
--- @param name string The name of the directory being created.
--- @return boolean true if the directory was created successfully, false otherwise.
---
function ModItemDecalEntity:CreateDirectory(ged_socket, path, name)
	local err = AsyncCreatePath(path)
	if err then
		ged_socket:ShowMessage("Failed importing decal", string.format("Failed creating %s directory: %s.", name, err))
		return
	end
	
	return true
end

---
--- Generates a texture file name for a mod item decal.
---
--- @param prop_id string The ID of the property containing the texture path.
--- @param extension string The file extension to use for the texture file name.
--- @return string The generated texture file name.
---
function ModItemDecalEntity:GetTextureFileName(prop_id, extension)
	return string.format("mod_%s_%s%s", prop_id, self.entity_name, extension)
end

---
--- Validates an image for use as a decal in the game.
---
--- @param prop_id string The ID of the property containing the image path.
--- @param ged_socket table The GED socket object.
--- @return boolean true if the image is valid, false otherwise.
---
function ModItemDecalEntity:ValidateImage(prop_id, ged_socket)
	local path = self:GetProperty(prop_id)
	if not io.exists(path) then
		local prop_name = self:GetPropertyMetadata(prop_id).name
		ged_socket:ShowMessage("Failed importing decal", string.format("Import failed - the %s image was not found.", prop_name))
		return
	end
	
	local w, h = UIL.MeasureImage(path)
	if w ~= h then
		local prop_name = self:GetPropertyMetadata(prop_id).name
		ged_socket:ShowMessage("Failed importing decal", string.format("The import failed because the %s image width and height are wrong. Image must be a square and pixel width and height must be power of two (e.g. 1024, 2048, 4096, etc.).", prop_name))
		return
	end
	
	if w <= 0 or band(w, w - 1) ~= 0 then --check if there's only one bit set in the entire number (equivalent to it being a power of 2)
		local prop_name = self:GetPropertyMetadata(prop_id).name
		ged_socket:ShowMessage("Failed importing decal", string.format("The import failed because the %s image width and height are wrong. Image must be a square and pixel width and height must be power of two (e.g. 1024, 2048, 4096, etc.).", prop_name))
		return
	end
	
	return true
end

---
--- Imports an image for use as a decal in the game.
---
--- @param ged_socket table The GED socket object.
--- @param prop_id string The ID of the property containing the image path.
--- @param texture_dir string The directory to save the compressed texture file.
--- @param fallback_dir string The directory to save the fallback texture file.
--- @return boolean true if the image was successfully imported, false otherwise.
---
function ModItemDecalEntity:ImportImage(ged_socket, prop_id, texture_dir, fallback_dir)
	if not self:ValidateImage(prop_id, ged_socket) then
		return
	end
	
	local path = self:GetProperty(prop_id)
	local texture_name = self:GetTextureFileName(prop_id, ".dds")
	
	-- Create the compressed textures that we will use in the game from the uncompressed one provided by the mod	
	local texture_output = texture_dir .. texture_name
	local cmdline = string.format("\"%s\" -dds10 -24 bc1 -32 bc3 -srgb \"%s\" \"%s\"", ConvertToOSPath(g_HgnvCompressPath), path, texture_output)
	local err = AsyncExec(cmdline, "", true, false)
	if err then
		ged_socket:ShowMessage("Failed importing decal", string.format("Failed creating compressed image: <u(err)>.", err))
		return
	end
	
	-- Create the fallback for the compressed texture
	local fallback_output = fallback_dir .. texture_name
	cmdline = string.format("\"%s\" \"%s\" \"%s\" --truncate %d", ConvertToOSPath(g_HgimgcvtPath), texture_output, fallback_output, const.FallbackSize)
	local err = AsyncExec(cmdline, "", true, false)
	if err then
		ged_socket:ShowMessage("Failed importing decal", string.format("Failed creating fallback image: %s.", err))
		return
	end
	
	return true
end

---
--- Creates an entity file for a decal in the game.
---
--- @param ged_socket table The GED socket object.
--- @param ent_path string The path to save the entity file.
--- @param mesh_file string The name of the mesh file to use.
--- @param mtl_file string The name of the material file to use.
--- @return boolean true if the entity file was successfully created, false otherwise.
---
function ModItemDecalEntity:CreateEntityFile(ged_socket, ent_path, mesh_file, mtl_file)
	local placeholder_entity = string.format("DecMod_%s", self.size)
	local bbox = GetEntityBoundingBox(placeholder_entity)
	local bbox_min_str = string.format("%d,%d,%d", bbox:minxyz())
	local bbox_max_str = string.format("%d,%d,%d", bbox:maxxyz())
	local bcenter, bradius = GetEntityBoundingSphere(placeholder_entity)
	local bcenter_str = string.format("%d,%d,%d", bcenter:xyz())
	local lines = {
		'<?xml version="1.0" encoding="UTF-8"?>',
		'<entity path="">',
		'\t<state id="idle">',
		'\t\t<mesh_ref ref="mesh"/>',
		'\t</state>',
		'\t<mesh_description id="mesh">',
		'\t\t<src file=""/>',
		string.format('\t\t<mesh file="Meshes/%s"/>', mesh_file),
		string.format('\t\t<material file="Materials/%s"/>', mtl_file),
		string.format('\t\t<bsphere value="%s,%d"/>', bcenter_str, bradius),
		string.format('\t\t<box min="%s" max="%s"/>', bbox_min_str, bbox_max_str),
		'\t</mesh_description>',
		'</entity>',
	}
	
	local content = table.concat(lines, "\n")
	local err = AsyncStringToFile(ent_path, content)
	if err then
		ged_socket:ShowMessage("Failed importing decal", string.format("Failed creating entity file: %s.", err))
		return
	end
	
	return true
end

---
--- Creates a material file for a decal in the game.
---
--- @param ged_socket table The GED socket object.
--- @param mtl_path string The path to save the material file.
--- @return boolean true if the material file was successfully created, false otherwise.
---
function ModItemDecalEntity:CreateMtlFile(ged_socket, mtl_path)
	--prepare properties
	local mtl_props = {
		AlphaTestValue = 128,
		BlendType = "Blend",
		CastShadow = false,
		SpecialType = "Decal",
		Deposition = false,
		TerrainDistortedMesh = false,
	}
	for i,prop_meta in ipairs(self:GetProperties()) do
		local id = prop_meta.id
		if prop_meta.mtl_map then
			local path = self:GetProperty(id)
			mtl_props[prop_meta.mtl_map] = io.exists(path)
		elseif prop_meta.mtl_prop then
			mtl_props[id] = self:GetProperty(id)
		end
	end
	
	local lines = {
		'<?xml version="1.0" encoding="UTF-8"?>',
		'<Materials>',
		'\t<Material>',
	}
	--insert maps
	for i,prop_meta in ipairs(self:GetProperties()) do
		local id = prop_meta.id
		if prop_meta.mtl_map and mtl_props[prop_meta.mtl_map] then
			local path = self:GetTextureFileName(id, ".dds")
			table.insert(lines, string.format('\t\t<%s Name="%s" mc="0"/>', id, path))
		end
	end
	--insert properties
	for id,value in sorted_pairs(mtl_props) do
		local value_type, value_str = type(value), ""
		if value_type == "boolean" then
			value_str = value and "1" or "0"
		else
			value_str = tostring(value)
		end
		table.insert(lines, string.format('\t\t<Property %s="%s"/>', id, value_str))
	end
	table.insert(lines, '\t</Material>')
	table.insert(lines, '</Materials>')
	
	local content = table.concat(lines, "\n")
	local err = AsyncStringToFile(mtl_path, content)
	if err then
		ged_socket:ShowMessage("Failed importing decal", string.format("Failed creating material file: <u(err)>.", err))
		return
	end
	
	return true
end

---
--- Creates a mesh file for a decal entity.
---
--- @param ged_socket GEDSocket The GED socket to use for error reporting.
--- @param hgm_path string The path to the HGM file to create.
--- @return boolean True if the mesh file was created successfully, false otherwise.
---
function ModItemDecalEntity:CreateMeshFile(ged_socket, hgm_path)
	local placeholder_entity = string.format("DecMod_%s", self.size)
	local placeholder_file = placeholder_entity .. "_mesh.hgm"
	local placeholder_path = "Meshes/" .. placeholder_file
	
	local err = AsyncCopyFile(placeholder_path, hgm_path)
	if err then
		ged_socket:ShowMessage("Failed importing decal", string.format("Could not create a mesh file: %s.", err))
		return
	end
	
	return true
end

----- ModItemGameValue

DefineClass.ModItemGameValue = {
	__parents = { "ModItem" },
	properties = {
		{ id = "name", default = false, editor = false, },
		{ category = "GameValue", id = "category", name = "Category",  default = "Gameplay", editor = "choice",
			items = ClassCategoriesCombo("Consts")},
		{ category = "GameValue", id = "id",       name = "ID",        default = "", editor = "choice",
			items = ClassPropertiesCombo("Consts", "category", "") },
		{ category = "GameValue", id = "const_name",		name = "Name",          default = "", editor = "text",  read_only = true, dont_save = true},
		{ category = "GameValue", id = "help", 			name = "Help",     default = "", editor = "text",  read_only = true, dont_save = true},
		{ category = "GameValue", id = "default_value", name = "Default value", default = 0, editor = "number", read_only = true, dont_save = true},
		{ category = "GameValue", id = "percent", 		name = "Percent",       default = 0, editor = "number",},
		{ category = "GameValue", id = "amount", 			name = "Amount",        default = 0, editor = "number",},
		{ category = "GameValue", id = "modified_value",name = "Modified value",default = 0, editor = "number", read_only = true, dont_save = true},
	},
	EditorName = "Game value",
	EditorSubmenu = "Gameplay",
	is_data = true,
}

---
--- Gets the name of the game value constant associated with this ModItemGameValue.
---
--- @return string The name of the game value constant.
---
function ModItemGameValue:Getconst_name()
	local metadata = Consts:GetPropertyMetadata(self.id)
	return _InternalTranslate(metadata and metadata.name or "")
end

---
--- Handles the event when a property of the ModItemGameValue is set in the editor.
---
--- @param prop_id string The ID of the property that was set.
--- @param old_value any The previous value of the property.
--- @param ged GEDSocket The GED socket used for the editor.
---
function ModItemGameValue:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "category" then
		self.id = ""
	end
	ModItem.OnEditorSetProperty(self, prop_id, old_value, ged)
end

---
--- Gets the properties of the ModItemGameValue object, with additional metadata for certain properties.
---
--- @return table The properties of the ModItemGameValue object, with additional metadata for certain properties.
---
function ModItemGameValue:GetProperties()
	local properties = {}
	for _, prop_meta in ipairs(self.properties) do
		local prop_id = prop_meta.id
		if prop_id == "default_value" or prop_id == "amount" or prop_id == "modified_value" then
			local const_meta = Consts:GetPropertyMetadata(self.id)
			if const_meta then
				prop_meta = table.copy(prop_meta)
				prop_meta.scale = const_meta.scale
			end
		end
		properties[#properties + 1] = prop_meta
	end
	return properties
end

---
--- Gets the help text associated with the ModItemGameValue.
---
--- @return string The help text for the ModItemGameValue.
---
function ModItemGameValue:Gethelp()
	local metadata = Consts:GetPropertyMetadata(self.id)
	return _InternalTranslate(metadata and metadata.help or "")
end

---
--- Gets the default value of the ModItemGameValue.
---
--- @return number The default value of the ModItemGameValue.
---
function ModItemGameValue:Getdefault_value()
	return Consts:GetDefaultPropertyValue(self.id) or 0
end

---
--- Gets the modified value of the ModItemGameValue.
---
--- @return number The modified value of the ModItemGameValue.
---
function ModItemGameValue:Getmodified_value()
	local default_value = Consts:GetDefaultPropertyValue(self.id) or 0
	return MulDivRound(default_value, self.percent + 100, 100) + self.amount
end

---
--- Resets the properties of the ModItemGameValue object to their default values.
---
function ModItemGameValue:ResetProperties()
	self.id = self:GetDefaultPropertyValue("id")
	self.const_name = self:GetDefaultPropertyValue("const_name")
	self.help = self:GetDefaultPropertyValue("help")
	self.default_value = self:GetDefaultPropertyValue("default_value")
	self.modified_value = self:GetDefaultPropertyValue("modified_value")
end

---
--- Gets a description of the ModItemGameValue object.
---
--- @return string The description of the ModItemGameValue object.
---
function ModItemGameValue:GetModItemDescription()
	if self.id == "" then return "" end 
	local pct = self.percent ~= 0 and string.format(" %+d%%", self.percent) or ""
	local const_meta = Consts:GetPropertyMetadata(self.id)
	local prefix = self.amount > 0 and "+" or ""
	local amount = self.amount ~= 0 and prefix .. FormatNumberProp(self.amount, const_meta.scale) or ""
	return Untranslated(string.format("%s.%s %s %s", self.category, self.id, pct, amount))
end

---
--- Generates documentation for the ModItemGameValue class properties.
---
--- This function extracts the list of Consts class properties, groups them by category,
--- and generates documentation for each property, including the property name, ID, and help text.
--- The generated documentation is then saved to a file named "ModItemGameValue_list.md.html".
---
--- @return string|nil An error message if there was a problem generating the documentation, or nil on success.
---
function GenerateGameValueDoc()
	if not g_Classes.Consts then return end
	local output = {}
	local categories = ClassCategoriesCombo("Consts")()
	local out = function(...)
		output[#output+1] = string.format(...)
	end
	local props = Consts:GetProperties()
	for _, category in ipairs(categories) do
		out("## %s", category)
		for _, prop in ipairs(props) do
			if prop.category == category then
				out("%s\n:\t*g_Consts.%s*<br>\n\t%s\n", _InternalTranslate(prop.name), prop.id, _InternalTranslate(prop.help or prop.name))
			end
		end
	end
	local err, suffix = AsyncFileToString("svnProject/Docs/ModTools/empty.md.html")
	if err then return err end
	output[#output+1] = suffix
	AsyncStringToFile("svnProject/Docs/ModTools/ModItemGameValue_list.md.html", table.concat(output, "\n"))
end

----

---
--- Generates documentation for classes that inherit from the specified base class.
---
--- This function extracts a list of classes that inherit from the specified base class,
--- and generates documentation for each class, including the class name, its documentation,
--- and documentation for any properties that are not defined in the base class.
---
--- The generated documentation is then saved to a file named "Lua{base_class}Doc.md.html".
---
--- @param base_class string The name of the base class to generate documentation for.
--- @return string|nil An error message if there was a problem generating the documentation, or nil on success.
---
function GenerateObjectDocs(base_class)
	-- extract list of classes
	local list = ClassDescendantsList(base_class)
	
	-- generate documentation using the classes' Documentation property and property metadata
	local output = { string.format("# Documentation for *%s objects*\n", base_class) }
	local base_props = g_Classes[base_class]:GetProperties()
	
	local hidden_dlc_list = {}
	ForEachPreset("DLCConfig", function(p)
		if not p.public then hidden_dlc_list[p.id] = true end
	end)
	
	local hidden_classdef_list = {} 
	ForEachPreset(base_class.."Def", function(p)
		local save_in = p:HasMember("save_in") and p.save_in or nil
		if save_in and hidden_dlc_list[save_in] then 
			hidden_classdef_list[p.id] = p.save_in 
		end
	end)
	
	for _, name in ipairs(list) do
		local class = g_Classes[name]
		if class:HasMember("Documentation") and class.Documentation and not hidden_classdef_list[name] then 
			output[#output+1] = string.format("## %s\n", name)
			output[#output+1] = class.Documentation
			for _, prop in ipairs(class:GetProperties()) do
				if not table.find(base_props, "id", prop.id) then
					if prop.help and prop.help ~= "" then
						output[#output+1] = string.format("%s\n: %s\n", prop.name or prop.id, prop.help)
					else
						--print("Missing documentation for property", prop.name or prop.id, "of class", name)
					end
				end
			end
		else
			--print("Missing documentation for class", name)
		end
	end
	
	OutputDocsFile(string.format("Lua%sDoc.md.html", base_class), output)
end

if config.RunUnpacked and Platform.developer then
	-- Auto-generated docs for effects, conditions, etc.
	function OnMsg.PresetSave(class)
		local classdef = g_Classes[class]
		if IsKindOf(classdef, "ClassDef") then
			GenerateObjectDocs("Effect")
			GenerateObjectDocs("Condition")
		elseif IsKindOf(classdef, "ConstDef") then
			GenerateGameValueDoc()
		end
	end
end

---
--- Returns a list of all available languages, including a special "Any" option.
---
--- @return table The list of available languages, including the "Any" option.
---
function GetAllLanguages()
	local languages = table.copy(AllLanguages, "deep")
	table.insert(languages, 1, { value = "Any", text = "Any", iso_639_1 = "en" })
	return languages
end

DefineClass.ModItemLocTable = {
	__parents = { "ModItem" },
	properties = {
		{ id = "name", default = false, editor = false },
		{ category = "Mod", id = "language", name = "Language",  default = "Any", editor = "dropdownlist", items = GetAllLanguages() },
		{ category = "Mod", id = "filename", name = "Filename",  editor = "browse",  filter = "Comma separated values (*.csv)|*.csv", default = "" },
	},
	EditorName = "Localization",
	EditorSubmenu = "Assets",
	ModItemDescription = T(677060079613, "<u(language)>"),
	Documentation = "Adds translation tables to localize the game in other languages.",
	DocumentationLink = "Docs/ModItemLocTable.md.html",
	TestDescription = "Loads the translation table."
}	

---
--- Loads the translation table for the specified language when the mod is loaded.
---
--- If the language is set to "Any", the translation table will be loaded regardless of the current game language.
---
--- @param self ModItemLocTable The ModItemLocTable instance.
---
function ModItemLocTable:OnModLoad()
	ModItem.OnModLoad(self)
	if self.language == GetLanguage() or self.language == "Any" then
		if io.exists(self.filename) then
			LoadTranslationTableFile(self.filename)
			Msg("TranslationChanged")
		end
	end
end

---
--- Loads the translation table for the specified language when the mod is loaded.
---
--- If the language is set to "Any", the translation table will be loaded regardless of the current game language.
---
--- @param self ModItemLocTable The ModItemLocTable instance.
---
function ModItemLocTable:TestModItem()
	if io.exists(self.filename) then
		LoadTranslationTableFile(self.filename)
		Msg("TranslationChanged")
	end
end


----- XTemplate

DefineModItemPreset("XTemplate", {
	GetSaveFolder = function() end,
	EditorName = "UI Template (XTemplate)",
	EditorSubmenu = "Other",
	TestDescription = "Opens a preview of the template."
})

---
--- Opens a preview of the XTemplate UI template defined by the ModItemXTemplate.
---
--- @param self ModItemXTemplate The ModItemXTemplate instance.
--- @param ged table The GED table.
---
function ModItemXTemplate:TestModItem(ged)
	GedOpPreviewXTemplate(ged, self, false)
end

---
--- Gets the save folder path for the XTemplate ModItem.
---
--- @param self ModItemXTemplate The ModItemXTemplate instance.
--- @param ... any Additional arguments passed to the base GetSaveFolder function.
--- @return string The save folder path.
---
function ModItemXTemplate:GetSaveFolder(...)
	return ModItemPreset.GetSaveFolder(self, ...)
end

---
--- Gets the save path for the XTemplate ModItem.
---
--- @param self ModItemXTemplate The ModItemXTemplate instance.
--- @param ... any Additional arguments passed to the base GetSavePath function.
--- @return string The save path.
---
function ModItemXTemplate:GetSavePath(...)
	return ModItemPreset.GetSavePath(self, ...)
end

------ SoundPreset

DefineModItemPreset("SoundPreset", {
	EditorName = "Sound",
	EditorSubmenu = "Other",
	Documentation = "Defines sound presets which can be played via the ActionFXSound mod item.",
	DocumentationLink = "Docs/ModItemSound.md.html",
	TestDescription = "Plays the sound file."
})

---
--- Gets the sound file paths used by the ModItemSoundPreset.
---
--- @param self ModItemSoundPreset The ModItemSoundPreset instance.
--- @return table A table of sound file paths used by the preset, with the paths as keys and true as the values.
---
function ModItemSoundPreset:GetSoundFiles()
	local file_paths = SoundPreset.GetSoundFiles(self)
	for _, sound_file in ipairs(self) do
		local sound_path = sound_file:Getpath()
		if io.exists(sound_path) then
			file_paths[sound_path] = true
		end
	end
	return file_paths
end

---
--- Overrides the sample functions for a ModItemSoundPreset.
---
--- @param self ModItemSoundPreset The ModItemSoundPreset instance.
--- @param sample SoundFile The SoundFile instance to override the functions for.
---
function ModItemSoundPreset:OverrideSampleFuncs(sample)
	sample.GetFileFilter = function()
		return "Sample File|*.opus;*.wav"
	end
	sample.Setpath = function(obj, path)
		sample.file = path
	end
	sample.Getpath = function()
		if sample.file == "" then
			return ".opus"
		elseif string.ends_with(sample.file, ".opus") or string.ends_with(sample.file, ".wav") then
			return sample.file
		else
			return sample.file .. ".wav"
		end
	end
	sample.GetFileExt = function()
		return "opus"
	end
end

---
--- Called when the mod is loaded. Overrides the sample functions for the ModItemSoundPreset and loads the sound bank.
---
--- @param self ModItemSoundPreset The ModItemSoundPreset instance.
---
function ModItemSoundPreset:OnModLoad()
	--replace child funcs
	for _, sample in ipairs(self or empty_table) do
		if IsKindOf(sample, "SoundFile") then
			self:OverrideSampleFuncs(sample)
		end
	end
	ModItemPreset.OnModLoad(self)
	LoadSoundBank(self)
end

---
--- Tests the ModItemSoundPreset by loading the sound bank and playing the sound preset.
---
--- @param self ModItemSoundPreset The ModItemSoundPreset instance.
--- @param ged table The game entity data table.
---
function ModItemSoundPreset:TestModItem(ged)
	LoadSoundBank(self)
	GedPlaySoundPreset(ged)
end

---
--- Generates a unique preset ID for the ModItemSoundPreset.
---
--- @param self ModItemSoundPreset The ModItemSoundPreset instance.
--- @return string A unique preset ID for the ModItemSoundPreset.
---
function ModItemSoundPreset:GenerateUniquePresetId()
	return SoundPreset.GenerateUniquePresetId(self, "Sound")
end

------ ActionFX

local function GenerateUniqueActionFXHandle(mod_item)
	local mod_id = mod_item.mod.id
	local index = mod_item.mod:FindModItem(mod_item)
	while true do
		local handle = string.format("%s_%d", mod_id, index)
		local any_collisions
		mod_item.mod:ForEachModItem("ActionFX", function(other_item)
			if other_item ~= mod_item then
				if other_item.handle == handle then
					any_collisions = true
					return "break"
				end
			end
		end)
		if not any_collisions then
			return handle
		else
			index = index + 1
		end
	end
end

local function DefineModItemActionFX(preset, editor_name)
	local actionfx_mod_class = DefineModItemPreset(preset, {
		EditorName = editor_name,
		EditorSubmenu = "ActionFX",
		EditorShortcut = false,
		TestDescription = "Plays the fx with actor and target the selected merc."
	})
	
	actionfx_mod_class.SetId = function(self, id)
		self.handle = id
		return Preset.SetId(self, id)
	end

	actionfx_mod_class.GetSavePath = function(self, ...)
		return ModItemPreset.GetSavePath(self, ...)
	end

	actionfx_mod_class.delete = function(self)
		return g_Classes[self.ModdedPresetClass].delete(self)
	end

	actionfx_mod_class.TestModItem = function(self, ged)
		PlayFX(self.Action, self.Moment, SelectedObj, SelectedObj)
	end

	actionfx_mod_class.PreSave = function(self)
		if not self.handle and self.mod then
			if self.id == "" then
				self:SetId(self.mod:GenerateModItemId(self))
			end
			self.handle = self.id
		end
		return ModItemPreset.PreSave(self)
	end
	
	local properties = actionfx_mod_class.properties or {}
	table.iappend(properties, {
		{ id = "__copy_group" },
		{ id = "__copy" },
	})
	
	actionfx_mod_class.ModItemDescription = function (self)
		return self:DescribeForEditor()
	end
end

DefineModItemActionFX("ActionFXSound", "ActionFX Sound")
DefineModItemActionFX("ActionFXObject", "ActionFX Object")
DefineModItemActionFX("ActionFXDecal", "ActionFX Decal")
DefineModItemActionFX("ActionFXLight", "ActionFX Light")
DefineModItemActionFX("ActionFXColorization", "ActionFX Colorization")
DefineModItemActionFX("ActionFXParticles", "ActionFX Particles")
DefineModItemActionFX("ActionFXRemove", "ActionFX Remove")

function OnMsg.ModsReloaded()
	RebuildFXRules()
end

------ Particles

DefineClass.ModItemParticleTexture =  {
	__parents = { "ModItem" },
	
	properties ={
		{ category = "Texture", id = "import", name = "Import", editor = "browse", os_path = true, filter = "Image files|*.png;*.tga", default = "", dont_save = true },
		{ category = "Texture", id = "btn", editor = "buttons", default = false, buttons = {{name = "Import Particle Texture", func = "Import"}}, untranslated = true},
	}, 
}

---
--- Imports a particle texture for a mod.
---
--- @param root string The root directory of the mod.
--- @param prop_id string The ID of the property being imported.
--- @param ged_socket table The GED socket for displaying messages.
---
function ModItemParticleTexture:Import(root, prop_id, ged_socket)
	GedSetUiStatus("mod_import_particle_texture", "Importing...")
	
	local output_dir = ConvertToOSPath(self.mod.content_path)
	
	local w, h = UIL.MeasureImage(self.import)
	if w ~= h then
		assert(false, "Image is not square")
		ged_socket:ShowMessage("Failed importing texture", "The import failed because the image width and height are wrong. Image must be a square and pixel width and height must be power of two (e.g. 1024, 2048, 4096, etc.).")
		GedSetUiStatus("mod_import_particle_texture")
		return
	end
	
	if w <= 0 or band(w, w - 1) ~= 0 then --check if there's only one bit set in the entire number (equivalent to it being a power of 2)
		assert(false, "Image sizes are not power of 2")
		ged_socket:ShowMessage("Failed importing texture", "The import failed because the image width and height are wrong. Image must be a square and pixel width and height must be power of two (e.g. 1024, 2048, 4096, etc.).")
		GedSetUiStatus("mod_import_particle_texture")
		return
	end
	
	-- use the same file name, just add the .dds extension
	local dir, name, ext = SplitPath(self.import)
	local texture_name = name .. ".dds"
	local texture_dir = output_dir .. GetModAssetDestFolder("Particle Texture")
	local texture_output = texture_dir .. "/" .. texture_name
	local fallback_dir = texture_dir .. "Fallbacks/"
	local fallback_output = fallback_dir .. texture_name
		
	local err = AsyncCreatePath(texture_dir)
	if err then
		assert(false, "Failed to create mod textures dir")
		ged_socket:ShowMessage("Failed importing texture", string.format("Failed creating %s directory: %s.", "Textures", err))
		GedSetUiStatus("mod_import_particle_texture")
		return
	end
	
	err = AsyncCreatePath(fallback_dir)
	if err then
		assert(false, "Failed to create mod fallback dir")
		ged_socket:ShowMessage("Failed importing texture", string.format("Failed creating %s directory: %s.", "Fallbacks", err))
		GedSetUiStatus("mod_import_particle_texture")
		return
	end
	
	-- Create the compressed textures that we will use in the game from the uncompressed one provided by the mod	
	local cmdline = string.format("\"%s\" -dds10 -24 bc1 -32 bc3 -srgb \"%s\" \"%s\"", ConvertToOSPath(g_HgnvCompressPath), self.import, texture_output)
	local err, out = AsyncExec(cmdline, "", true, false)
	if err then
		assert(false, "Failed to create compressed texture image")
		ged_socket:ShowMessage("Failed importing texture", string.format("Failed creating compressed image: %s.", err))
		GedSetUiStatus("mod_import_particle_texture")
		return
	end
	
	-- Create the fallback for the compressed texture
	cmdline = string.format("\"%s\" \"%s\" \"%s\" --truncate %d", ConvertToOSPath(g_HgimgcvtPath), texture_output, fallback_output, const.FallbackSize)
	err = AsyncExec(cmdline, "", true, false)
	if err then
		assert(false, "Failed to create texture fallback")
		ged_socket:ShowMessage("Failed importing texture", string.format("Failed creating fallback image: %s.", err))
		GedSetUiStatus("mod_import_particle_texture")
		return
	end
	
	self:OnModLoad()
	
	GedSetUiStatus("mod_import_particle_texture")
	ged_socket:ShowMessage("Success", "Texture imported successfully!")
end

DefineModItemPreset("ParticleSystemPreset", {
	properties = {
		{ id = "ui", name = "UI Particle System" , editor = "bool", default = false, no_edit = true,  },
		{ id = "saving", editor = "bool", default = false, dont_save = true, no_edit = true, },
	},
	EditorName = "Particle system",
	EditorSubmenu = "Other",
	Documentation = "Creates a new particle system and defines its parameters.",
	TestDescription = "Places the particle  system on the screen center."
})

---
--- Returns the base path for textures used by this particle system preset.
---
--- @return string The base path for textures.
function ModItemParticleSystemPreset:GetTextureBasePath()
	return ""
end

function ModItemParticleSystemPreset:GetTextureTargetPath()
	return ""
end

function ModItemParticleSystemPreset:GetTextureTargetGamePath()
	return ""
end

---
--- Checks if the ModItemParticleSystemPreset object has been modified since the last save.
---
--- @return boolean True if the object has been modified, false otherwise.
function ModItemParticleSystemPreset:IsDirty()
	return ModItemPreset.IsDirty(self)
end

---
--- Called before the ModItemParticleSystemPreset object is saved.
--- Sets the `saving` flag to `true` and calls the `PreSave` method of the parent `ModItem` class.
---
--- @return nil
function ModItemParticleSystemPreset:PreSave()
	self.saving = true
	ModItem.PreSave(self)
end

---
--- Called after the ModItemParticleSystemPreset object is saved.
--- Sets the `saving` flag to `false` and calls the `PostSave` method of the parent `ModItem` class.
--- Also reloads the particle system after saving.
---
--- @return nil
function ModItemParticleSystemPreset:PostSave(...)
	self.saving = false
	ModItem.PostSave(self, ...)
	ParticlesReload(self:GetId())
end

---
--- Called after the ModItemParticleSystemPreset object is loaded.
--- Reloads the particle system after loading.
---
--- @return nil
function ModItemParticleSystemPreset:PostLoad()
	ParticleSystemPreset.PostLoad(self)
	ParticlesReload(self:GetId())
end

---
--- Overrides the texture and normalmap filter functions for the given particle emitter.
--- Also sets the `ShouldNormalizeTexturePath` function to return `false` if the `saving` flag is set.
---
--- @param emitter ParticleEmitter The particle emitter to override the functions for.
---
function ModItemParticleSystemPreset:OverrideEmitterFuncs(emitter)
	emitter.GetTextureFilter = function()
		return "Texture (*.dds)|*.dds"
	end
	
	emitter.GetNormalmapFilter = function()
		return "Texture (*.dds)|*.dds"
	end
	
	emitter.ShouldNormalizeTexturePath = function()
		return not self.saving
	end
end

---
--- Returns a list of texture folders used by the particle system preset.
---
--- @return table A table of texture folder paths.
---
function ModItemParticleSystemPreset:GetTextureFolders()
	return { "Textures/Particles" }
end

---
--- Called when the ModItemParticleSystemPreset object is loaded.
--- Replaces the child particle emitter functions with custom functions that override the texture and normalmap filter functions, and set the `ShouldNormalizeTexturePath` function to return `false` if the `saving` flag is set.
--- Also calls the `OnModLoad` method of the parent `ModItemPreset` class.
---
--- @return nil
function ModItemParticleSystemPreset:OnModLoad()
	-- replace child funcs
	self.saving = nil
	for _, child in ipairs(self) do
		if IsKindOf(child, "ParticleEmitter") then
			self:OverrideEmitterFuncs(child)
		end
	end
	ModItemPreset.OnModLoad(self)
end

---
--- Returns the name of the ModItemParticleSystemPreset object.
---
--- @return string The name of the ModItemParticleSystemPreset object.
---
function ModItemParticleSystemPreset:GetName()
	return ModItemPreset.GetName(self)
end


---
--- Overrides the EditorItemsMenu function to remove the "ParticleParam" item from the list of items displayed in the editor.
---
--- @return table A table of editor items, with the "ParticleParam" item removed.
---
function ModItemParticleSystemPreset:EditorItemsMenu()
	-- remove particle params from subitems
	local items = Preset.EditorItemsMenu(self)
	local idx = table.find(items, 1, "ParticleParam")
	if idx then
		table.remove(items, idx)
	end
	return items
end

if FirstLoad then
	TestParticleSystem = false
end

---
--- Tests the ModItemParticleSystemPreset by creating a particle system with the preset's ID and placing it at the terrain gamepad cursor position.
---
--- If a previous test particle system exists, it is destroyed before creating a new one.
---
--- @return nil
---
function ModItemParticleSystemPreset:TestModItem()
	if IsValid(TestParticleSystem) then
		DoneObject(TestParticleSystem)
	end
	TestParticleSystem = PlaceParticles(self.id)
	TestParticleSystem:SetPos(GetTerrainGamepadCursor()) -- place at screen center
end

----

DefineModItemPreset("ConstDef", { EditorName = "Constant", EditorSubmenu = "Gameplay" })

function OnMsg.ClassesPostprocess()
	local idx = table.find(ModItemConstDef.properties, "id", "Group")
	local prop = table.copy(ModItemConstDef.properties[idx])
	prop.name = "group" -- match the other props case
	prop.category = nil -- "Misc" category
	table.remove(ModItemConstDef.properties, idx)
	table.insert(ModItemConstDef.properties, table.find(ModItemConstDef.properties, "id", "type"), prop)
end

ModItemConstDef.GetSavePath = ModItemPreset.GetSavePath
ModItemConstDef.GetSaveData = ModItemPreset.GetSaveData

---
--- Assigns the values defined in the ModItemConstDef to the corresponding constant groups.
---
--- If the `group` property is not set or is an empty string, the values are assigned to the `const` table.
--- Otherwise, the values are assigned to the `const[self_group]` table.
---
--- If the `value` property is `nil`, the default value for the `type` property is used.
---
--- If the `id` property is an empty string, the value is appended to the constant group table.
--- Otherwise, the value is assigned to the constant group table using the `id` as the key.
---
--- @param self ModItemConstDef The ModItemConstDef instance.
---
function ModItemConstDef:AssignToConsts()
	local self_group = self.group or "Default"
	assert(self.group ~= "")
	local const_group = self_group == "Default" and const or const[self_group]
	if not const_group then
		const_group = {}
		const[self_group] = const_group
	end
	local value = self.value
	if value == nil then
		value = ConstDef:GetDefaultValueOf(self.type)
	end
	local id = self.id or ""
	if id == "" then
		const_group[#const_group + 1] = value
	else
		const_group[id] = value
	end
end

---
--- Saves the ModItemConstDef instance and then assigns its values to the corresponding constant groups.
---
--- This function is called after the ModItemConstDef instance is saved. It ensures that the constant values defined in the ModItemConstDef are properly assigned to the `const` table or the `const[self_group]` table, depending on the value of the `group` property.
---
--- @param self ModItemConstDef The ModItemConstDef instance.
--- @param ... Any additional arguments passed to the `PostSave` function.
--- @return any The return value of the `ModItemPreset.PostSave` function.
---
function ModItemConstDef:PostSave(...)
	self:AssignToConsts()
	return ModItemPreset.PostSave(self, ...)
end

---
--- Loads the ModItemConstDef and assigns its values to the corresponding constant groups.
---
--- This function is called when the mod is loaded. It ensures that the constant values defined in the ModItemConstDef are properly assigned to the `const` table or the `const[self_group]` table, depending on the value of the `group` property.
---
--- @param self ModItemConstDef The ModItemConstDef instance.
---
function ModItemConstDef:OnModLoad()
	ModItemPreset.OnModLoad(self)
	self:AssignToConsts()
end

---
--- Attempts to get the ModDef instance from the given object.
---
--- If the object is a ModDef instance, it is returned directly.
--- If the object is a ModItem instance, its `mod` property is returned.
--- If the object is neither a ModDef nor a ModItem, the function attempts to find the nearest parent ModItem instance and return its `mod` property.
---
--- @param obj any The object to get the ModDef instance from.
--- @return ModDef|nil The ModDef instance, or nil if it could not be found.
---
function TryGetModDefFromObj(obj)
	if IsKindOf(obj, "ModDef") then
		return obj
	elseif IsKindOf(obj, "ModItem") then
		return obj.mod
	else
		local mod_item_parent = GetParentTableOfKindNoCheck(obj, "ModItem")
		return mod_item_parent and mod_item_parent.mod
	end
end


----- ModItemChangeProp

local forbidden_classes = {
	Achievement = true,
	PlayStationActivities = true,
	RichPresence = true,
	TrophyGroup = true,
}

local function GlobalPresetClasses(self)
	local items = {}
	local classes = g_Classes
	for name in pairs(Presets) do
		if not forbidden_classes[name] then
			local classdef = classes[name]
			if classdef and classdef.GlobalMap then
				items[#items + 1] = name
			end
		end
	end
	table.sort(items)
	table.insert(items, 1, "")
	return items
end

local forbidden_props = {
	Id = true,
	Group = true,
	Comment = true,
	TODO = true,
	SaveIn = true,
}

local function PresetPropsCombo(self)
	local preset = self:ResolveTargetPreset()
	local props = preset and preset:GetProperties()
	local items = {}
	for _, prop in ipairs(props) do
		if not forbidden_props[prop.id] and
		   not prop_eval(prop.dont_save, preset, prop) and
		   not prop_eval(prop.no_edit  , preset, prop) and
		   not prop_eval(prop.read_only, preset, prop)
		then
			items[#items + 1] = prop.id
		end
	end
	table.sort(items)
	table.insert(items, 1, "")
	return items
end

if FirstLoad then
	ModItemChangeProp_OrigValues = {}
end
local orig_values = ModItemChangeProp_OrigValues

local function TargetFuncDefault(self, value, default)
	return value
end

local CanAppendToTableListProps = {
	dropdownlist = true,
	string_list = true,
	preset_id_list = true,
	number_list = true,
	point_list = true,
	T_list = true,
	nested_list = true,
	property_array = true,
}

local function CanAppendToTable(prop)
	return CanAppendToTableListProps[prop.editor]
end

DefineClass.ModItemChangePropBase = {
	__parents = { "ModItem" },
	properties = {
		{ category = "Change Property", id = "TargetClass",   name = "Class",          default = "",        editor = "choice", items = GlobalPresetClasses, reapply = true },
		{ category = "Change Property", id = "TargetId",      name = "Preset",         default = "",        editor = "choice", items = function(self, prop_meta) return PresetsCombo(self.TargetClass)(self, prop_meta) end,     no_edit = function(self) return not self:ResolveTargetMap() end, reapply = true },
		{ category = "Change Property", id = "TargetProp",    name = "Property",       default = "",        editor = "choice", items = PresetPropsCombo, no_edit = function(self) return not self:ResolveTargetPreset() end, reapply = true },
		{ category = "Change Property", id = "OriginalValue", name = "Original Value", default = false,     editor = "bool",         no_edit = function(self) return not self:ResolvePropTarget() end, dont_save = true, read_only = true, untranslated = true },
		{ category = "Change Property", id = "EditType",      name = "Edit Type",      default = "Replace", editor = "dropdownlist", no_edit = function(self) return not self:ResolvePropTarget() end, help = "<style GedHighlight>Replace:</style> completely overwrites property.\n<style GedHighlight>Append To Table:</style> adds new entries while keeping existing ones.\n<style GedHighlight>Code:</style> modifies the value by using code. Requires Lua knowledge.", reapply = true,
			items = function(self) 
				local options = {"Replace", "Code"}
				local propTarget = self:ResolvePropTarget()
				if CanAppendToTable(propTarget) then
					table.insert(options, "Append To Table")
				end
				return options
			end 
		},
		{ category = "Change Property", id = "TargetValue", name = "Value",  default = false,             editor = "bool",                                  no_edit = function(self) return not self:ResolvePropTarget() or self.EditType == "Code" end, dont_save = function(self) return self.EditType == "Code" end, untranslated = true },
		{ category = "Change Property", id = "TargetFunc",  name = "Change", default = TargetFuncDefault, editor = "func", params = "self, value, default", no_edit = function(self) return not self:ResolvePropTarget() or self.EditType ~= "Code" end, help = "Property change code. The expression parameters are the mod item, the current property value and the original property value. The current property value may differ from the original one in the presence of other mods, tweaking the same property." },
	},
	
	Documentation = "Changes a specific preset property value. Clicking the test button will apply the change.\n\nIf more than one mod changes the same preset property, the one that has loaded last will decide the final value. Defining the dependency list for a mod will ensure the load order of given mods and allow for some control over this problem.",
	EditorName = "Change property",
	EditorSubmenu = "Gameplay",
	tweaked_values = false,
	is_data = true,
	TestDescription = "Applies the change to the selected preset."
}

DefineClass("ModItemChangeProp", "ModItemChangePropBase")

---
--- Initializes the name of a `ModItemChangePropBase` instance to "ChangeProperty" when it is created or pasted in the editor.
---
--- @param mod table The mod instance that this `ModItemChangePropBase` belongs to.
--- @param ged table The editor instance that this `ModItemChangePropBase` is being created in.
--- @param is_paste boolean Whether this `ModItemChangePropBase` is being pasted from the clipboard.
---
function ModItemChangePropBase:OnEditorNew(mod, ged, is_paste)
	self.name = "ChangeProperty"
end

---
--- Returns a description of the ModItemChangePropBase instance.
---
--- If the name of the instance is empty, the description is a formatted string
--- containing the TargetId and TargetProp properties.
--- Otherwise, the description is the value of the ModItemDescription property.
---
--- @return string The description of the ModItemChangePropBase instance.
---
function ModItemChangePropBase:GetModItemDescription()
	if self.name == "" then
		return Untranslated("<u(TargetId)>.<u(TargetProp)>")
	end
	return self.ModItemDescription
end

---
--- Resolves the global map object for the target class of the `ModItemChangePropBase` instance.
---
--- The global map object is retrieved by looking up the `GlobalMap` property of the class definition for the `TargetClass` property of the `ModItemChangePropBase` instance.
---
--- @return table|nil The global map object for the target class, or `nil` if the class definition or global map name is not found.
---
function ModItemChangePropBase:ResolveTargetMap()
	local classdef = g_Classes[self.TargetClass]
	local name = classdef and classdef.GlobalMap
	return name and _G[name]
end

---
--- Resolves the target preset object for the `ModItemChangePropBase` instance.
---
--- The target preset object is retrieved by looking up the `TargetId` property of the `ModItemChangePropBase` instance in the global map object returned by `self:ResolveTargetMap()`.
---
--- @return table|nil The target preset object, or `nil` if the target map or preset object is not found.
---
function ModItemChangePropBase:ResolveTargetPreset()
	local map = self:ResolveTargetMap()
	return map and map[self.TargetId]
end

---
--- Resolves the property target for the `ModItemChangePropBase` instance.
---
--- The property target is retrieved by looking up the `TargetProp` property of the `ModItemChangePropBase` instance in the list of properties returned by `self:ResolveTargetPreset():GetProperties()`.
---
--- @return table|nil The property target, or `nil` if the property is not found.
---
function ModItemChangePropBase:ResolvePropTarget()
	local preset = self:ResolveTargetPreset()
	local props = preset and preset:GetProperties()
	return props and table.find_value(props, "id", self.TargetProp)
end

---
--- Sets the target value for the `ModItemChangePropBase` instance.
---
--- The target value is stored in the `tweaked_values` table, which is a nested table keyed by the `TargetClass`, `TargetId`, and `TargetProp` properties of the `ModItemChangePropBase` instance.
---
--- @param value any The new value to set for the target property.
---
function ModItemChangePropBase:SetTargetValue(value)
	self.tweaked_values = self.tweaked_values or {}
	table.set(self.tweaked_values, self.TargetClass, self.TargetId, self.TargetProp, value)
end

---
--- Gets the changed value for the `ModItemChangePropBase` instance.
---
--- The changed value is retrieved from the `tweaked_values` table, which is a nested table keyed by the `TargetClass`, `TargetId`, and `TargetProp` properties of the `ModItemChangePropBase` instance.
---
--- @return any|nil The changed value, or `nil` if no value has been set.
---
function ModItemChangePropBase:GetChangedValue()
	return table.get(self.tweaked_values, self.TargetClass, self.TargetId, self.TargetProp)
end

---
--- Gets the property value for the `ModItemChangePropBase` instance.
---
--- This function resolves the target preset object and the property target, and then retrieves the value of the property from the preset object. The value is then cloned to ensure it is a separate copy from the original.
---
--- @return any The cloned value of the target property.
---
function ModItemChangePropBase:GetPropValue()
	local preset = self:ResolveTargetPreset()
	local prop = preset and self:ResolvePropTarget()
	if prop then
		local value = preset:GetProperty(self.TargetProp)
		return preset:ClonePropertyValue(value, prop)
	end
end

---
--- Gets the target value for the `ModItemChangePropBase` instance.
---
--- If a changed value has been set using `SetTargetValue()`, that value is returned. Otherwise, if the `EditType` is "Append To Table", `false` is returned. Otherwise, the original property value is returned by calling `GetPropValue()`.
---
--- @return any The target value for the `ModItemChangePropBase` instance.
---
function ModItemChangePropBase:GetTargetValue()
	local value = self:GetChangedValue()
	if value ~= nil then
		return value
	end
	if self.EditType == "Append To Table" then
		return false
	end
	return self:GetPropValue()
end

---
--- Gets the original value for the `ModItemChangePropBase` instance.
---
--- If an original value has been set in the `orig_values` table, that value is returned. Otherwise, the original property value is returned by calling `GetPropValue()`.
---
--- @return any The original value for the `ModItemChangePropBase` instance.
---
function ModItemChangePropBase:GetOriginalValue()
	local orig_value = table.get(orig_values, self.TargetClass, self.TargetId, self.TargetProp)
	if orig_value ~= nil then
		return orig_value
	end
	return self:GetPropValue()
end

---
--- Overwrites the specified property in the `props` table with the values from the `prop` table.
---
--- @param prop_id string The ID of the property to overwrite.
--- @param props table The table of properties to overwrite.
--- @param prop table The table of property values to use for the overwrite.
---
function ModItemChangePropBase:OverwriteProp(prop_id, props, prop)
	local my_prop = table.find_value(props, "id", prop_id)
	local keep = { 
		id = my_prop.id,
		name = my_prop.name,
		category = my_prop.category,
		no_edit = my_prop.no_edit,
		dont_save = my_prop.dont_save,
		read_only = my_prop.read_only,
		os_path = my_prop.os_path,
	}
	table.clear(my_prop)
	table.overwrite(my_prop, prop)
	table.overwrite(my_prop, keep)
end

---
--- Gets the properties for the `ModItemChangePropBase` instance.
---
--- This function overrides the `ModItem.GetProperties()` function to handle special cases for properties with the `ComponentsPropCategory` category. For these properties, the `TargetValue` property is modified to display a help message indicating that object components cannot be modified with this mod item. The `EditType` property is also set to `no_edit` for these properties.
---
--- For other properties, the `TargetValue` and `OriginalValue` properties are overwritten with the values from the resolved property target.
---
--- @return table The properties for the `ModItemChangePropBase` instance.
---
function ModItemChangePropBase:GetProperties()
	local props = ModItem.GetProperties(self)
	local prop = self:ResolvePropTarget()
	if prop then
		if prop.category == const.ComponentsPropCategory then
			-- disallow changing CompositeDef components via ModItemChangeProp
			local help_prop = table.find_value(props, "id", "TargetValue")
			table.clear(help_prop)
			table.overwrite(help_prop, {
				category = "Mod", id = "TargetValue", editor = "help",
				help = "<center><style GedHighlight>Object components can't be modified with this mod item.\nPlease replace the entire preset instead."
			})
			table.find_value(props, "id", "EditType").no_edit = true
		else
			self:OverwriteProp("TargetValue", props, prop)
			self:OverwriteProp("OriginalValue", props, prop)
		end
	end
	return props
end

---
--- Applies the changes defined by the `ModItemChangePropBase` instance to the target preset.
---
--- If `apply` is `true`, the function will apply the changes by:
--- - Resolving the target preset
--- - Getting the original value of the target property
--- - Calculating the new value based on the `EditType` property
--- - Assigning the new value to the target preset
---
--- If `apply` is `false`, the function will revert the changes by:
--- - Resolving the target preset
--- - Assigning the original value of the target property back to the preset
---
--- @param apply boolean Whether to apply or revert the changes
---
function ModItemChangePropBase:ApplyChange(apply)
	local preset = self:ResolveTargetPreset()
	if not preset then return end
	local orig_value = table.get(orig_values, self.TargetClass, self.TargetId, self.TargetProp)
	local final_value
	if apply then
		local current_value = self:GetPropValue()
		local new_value
		if self.EditType == "Code" then
			local ok, res = procall(self.TargetFunc, self, current_value, orig_value or current_value)
			if ok then
				new_value = res
			else
				ModLogF("%s %s: %s", self.class, self.mod.title, res)
			end
		else
			new_value = self:GetChangedValue()
		end
		if new_value == nil then return end
		if orig_value == nil then
			orig_value = current_value
			table.set(orig_values, self.TargetClass, self.TargetId, self.TargetProp, orig_value)
		end
		if self.EditType == "Append To Table" then
			local temp = table.icopy(current_value)
			table.iappend(temp, new_value)
			new_value = temp
		end
		final_value = new_value
	elseif orig_value ~= nil then
		final_value = orig_value
		table.set(orig_values, self.TargetClass, self.TargetId, self.TargetProp, nil)
	end
	if final_value ~= nil then
		self:AssignValue(preset, final_value)
	end
end

---
--- Assigns the specified `value` to the `TargetProp` property of the `preset` object.
--- Also updates the `TargetProp` property of the `target_class` object if it exists and was generated by the same class as the `preset`.
--- Logs the assignment to the mod log.
---
--- @param preset table The preset object to assign the value to
--- @param value any The value to assign to the `TargetProp` property
---
function ModItemChangePropBase:AssignValue(preset, value)
	preset:SetProperty(self.TargetProp, value)
	preset:PostLoad()
	local target_class = g_Classes[self.TargetId]
	if target_class and target_class.__generated_by_class == preset.class then
		rawset(target_class, self.TargetProp, value)
	end
	ModLogF("%s %s: %s.%s = %s", self.class, self.mod.title, self.TargetId, self.TargetProp, ValueToStr(value))
end

---
--- Handles the behavior when a property of the `ModItemChangePropBase` object is set in the editor.
---
--- If the property being set has the `reapply` metadata flag, the following steps are performed:
--- 1. The new value of the property is stored in a temporary variable.
--- 2. The property is set back to the old value.
--- 3. `ApplyChange(false)` is called to revert any changes made by the property.
--- 4. The property is set to the new value.
--- 5. The `tweaked_values` table is cleared.
---
--- If the `EditType` is set to "Append To Table" and the target property cannot be appended to, the `EditType` is changed to "Replace".
---
--- Finally, the base `ModItem.OnEditorSetProperty` function is called to handle any other editor-related behavior.
---
--- @param prop_id string The ID of the property being set
--- @param old_value any The previous value of the property
--- @param ged table The editor-related data
---
function ModItemChangePropBase:OnEditorSetProperty(prop_id, old_value, ged)
	if self:GetPropertyMetadata(prop_id).reapply then
		local new_value = self.prop_id
		self.prop_id = old_value
		self:ApplyChange(false)
		self.prop_id = new_value
		self.tweaked_values = {}
	end
	
	local propTarget = self:ResolvePropTarget()
	if self.EditType == "Append To Table" and not CanAppendToTable(propTarget) then
		self.EditType = "Replace"
	end
	ModItem.OnEditorSetProperty(self, prop_id, old_value, ged)
end

---
--- Called when the mod is loaded. Applies any changes made by the `ModItemChangePropBase` object.
---
function ModItemChangePropBase:OnModLoad()
	ModItem.OnModLoad(self)
	self:ApplyChange(true)
end

---
--- Called when the mod is unloaded. Reverts any changes made by the `ModItemChangePropBase` object.
---
function ModItemChangePropBase:OnModUnload()
	ModItem.OnModUnload(self)
	self:ApplyChange(false)
end

---
--- Applies the changes made by the `ModItemChangePropBase` object, then reverts those changes.
---
--- This function is primarily used for testing purposes, to ensure that the changes made by the `ModItemChangePropBase` object are applied and reverted correctly.
---
--- @function ModItemChangePropBase:TestModItem
--- @return nil
function ModItemChangePropBase:TestModItem()
	self:ApplyChange(false)
	self:ApplyChange(true)
end

---
--- Applies the changes made by the `ModItemChangePropBase` object, then reverts those changes.
---
--- This function is primarily used for testing purposes, to ensure that the changes made by the `ModItemChangePropBase` object are applied and reverted correctly.
---
function ModItemChangePropBase:delete()
	self:ApplyChange(false)
end

local function DoModItemChangePropTargetSameProp(mod1, mod2)
	assert(mod1 and mod2)
	return mod1.TargetClass == mod2.TargetClass and mod1.TargetId == mod2.TargetId and mod1.TargetProp == mod2.TargetProp
end

---
--- Checks for warnings related to the `ModItemChangePropBase` object.
---
--- This function checks for various conditions that may cause warnings when modifying a property of a mod item. It checks if the target preset already exists, if the property is already modified by another mod item, and if the property is already modified by another loaded mod.
---
--- @function ModItemChangePropBase:GetWarning
--- @return string|nil The warning message, or `nil` if no warning is found.
function ModItemChangePropBase:GetWarning()
	local target_preset = self:ResolveTargetPreset()
	if target_preset and IsKindOf(target_preset, "ModItem") then
		return string.format("Changing the property '%s' of mod item '%s' is suggested to be done inside the dedicated preset mod item that already exists in this mod.", self.TargetProp, target_preset.id)
	end
	if not target_preset then
		if self.TargetClass ~= "" and self.TargetId ~= "" then
			return "The target preset to modify does not exist."
		end
		return
	end
	
	local ret = self.mod:ForEachModItem("ModItemChangePropBase", function(mod_item)
		if mod_item ~= self and DoModItemChangePropTargetSameProp(self, mod_item) then
			return string.format("The property '%s' is already modified in mod item '%s'", self.TargetProp, mod_item.name and mod_item.name ~= "" and mod_item.name or (mod_item.TargetId .. "." .. mod_item.TargetProp))
		end
	end)
	if ret then return ret end
	
	for _, mod in ipairs(ModsLoaded) do
		if mod:ItemsLoaded() then
			local ret = mod:ForEachModItem("ModItemChangePropBase", function(mod_item)
				if mod.id ~= self.mod.id then
					if DoModItemChangePropTargetSameProp(self, mod_item) then
						return string.format("The property '%s' is already modified in loaded mod '%s'/'%s'", self.TargetProp, mod.id, mod_item.name and mod_item.name ~= "" and mod_item.name or (mod_item.TargetId .. "." .. mod_item.TargetProp))
					end
				end
			end)
			if ret then return ret end
		end
	end
end

---
--- Returns a list of affected resources for the `ModItemChangePropBase` object.
---
--- This function checks the target class, id, and property of the `ModItemChangePropBase` object and returns a list of affected resources as `ModResourcePreset` objects. If the target class, id, and property are set, it retrieves the display name of the target class and creates a new `ModResourcePreset` object with the relevant information. If the target class, id, and property are not set, it returns an empty table.
---
--- @return table<ModResourcePreset> The list of affected resources.
function ModItemChangePropBase:GetAffectedResources()
	if self.TargetClass and self.TargetId and self.TargetProp then
		local display_name
		local mod_item_class = g_Classes["ModItem" .. self.TargetClass]
		if g_Classes[self.TargetClass] and mod_item_class then
			display_name = mod_item_class.EditorName
		end
	
		local affected_resources = {}
		table.insert(affected_resources, ModResourcePreset:new({
			mod = self.mod,
			Class = self.TargetClass,
			Id = self.TargetId,
			Prop = self.TargetProp,
			ClassDisplayName = display_name,
		}))
		return affected_resources
	end

	return empty_table
end

function OnMsg.ClassesPostprocess() -- reapply changed properties to generated classes
	for _, mod in ipairs(ModsLoaded) do
		if mod:ItemsLoaded() then
			mod:ForEachModItem("ModItemChangePropBase", function(mod_item)
				if mod_item.TargetProp ~= "__children" then
					local preset = mod_item:ResolveTargetPreset()
					local class = g_Classes[mod_item.TargetId]
					if class and preset and class.__generated_by_class == preset.class then
						rawset(class, mod_item.TargetProp, preset[mod_item.TargetProp])
					end
					if preset then
						preset:PostLoad()
					end
				end
			end)
		end
	end
end

------- ModItemConvertAsset

local function UpdateImportedFileStatus(importedFiles, totalFiles)
	GedSetUiStatus("importAssets", string.format("Importing(%s / %s)... ", importedFiles, totalFiles))
end

local function UIImageImport(srcFolder, destFolder, assetTypeInfo, ged_socket, importedFiles)
	--Find files from dest
	local err, assetsForImport = AsyncListFiles(srcFolder)
	local partialSuccess
	
	if err then
		return { string.format("Failed reading files in source folder: %s", srcFolder) }
	end
	
	--Create folders
	err = AsyncCreatePath(destFolder)
	if err then
		return { string.format("Failed creating '%s' directory: %s.", assetTypeInfo.folder, err) }
	end
	
	--Import and Convert found files and do not stop proccess for specific errors per files
	err = {}
	local totalNumber = assetsForImport and #assetsForImport
	for idx, fileName in ipairs(assetsForImport) do
		UpdateImportedFileStatus(idx, totalNumber)
		local dir, name, ext = SplitPath(fileName)
		
		if next(assetTypeInfo.ext) and not table.find(assetTypeInfo.ext, ext) then
			table.insert(err, string.format("Failed importing file '%s' : file type '%s' not supported", name, ext))
			goto continue
		end
		
		-- use the same file name, just add the .dds extension
		local imageName = name .. ".dds"
		local textureOutput = destFolder .. "/" .. imageName
		
		-- Create the compressed image that we will use in the game from the uncompressed one provided by the mod
		local cmdline = string.format("\"%s\" \"%s\" \"%s\" --mips 0 --compression BC7 --profile slow", ConvertToOSPath(g_HgimgcvtPath), fileName, textureOutput)
		local comprErr, out = AsyncExec(cmdline, "", true, false)
		if comprErr then
			table.insert(err, string.format("Failed creating compressed image for '%s': %s.", fileName, comprErr))
			goto continue
		else
			partialSuccess = true
		end
		
		::continue::
	end
	
	return err, partialSuccess
end

local function SoundImport(srcFolder, destFolder, assetTypeInfo, ged_socket, importedFiles)
	--Find files from dest
	local err, assetsForImport = AsyncListFiles(srcFolder)
	local partialSuccess
	
	if err then
		return { string.format("Failed reading files in source folder: %s", srcFolder) }
	end
	
	--Create folders
	err = AsyncCreatePath(destFolder)
	if err then
		return { string.format("Failed creating '%s' directory: %s.", assetTypeInfo.folder, err) }
	end
	
	--Import and Convert found files and do not stop proccess for specific errors per files
	err = {}
	local totalNumber = assetsForImport and #assetsForImport
	for idx, fileName in ipairs(assetsForImport) do
		UpdateImportedFileStatus(idx, totalNumber)
		local dir, name, ext = SplitPath(fileName)
		
		if next(assetTypeInfo.ext) and not table.find(assetTypeInfo.ext, ext) then
			table.insert(err, string.format("Failed importing file '%s' : file type '%s' not supported", name, ext))
			goto continue
		end
		
		-- use the same file name, just add the .opus extension
		local soundName = name .. ".opus"
		local soundOutput = destFolder .. "/" .. soundName
		
		-- Create the compressed sound that we will use in the game from the uncompressed one provided by the mod
		local cmdline = string.format("\"%s\" --serial 0 \"%s\" \"%s\"", ConvertToOSPath(g_OpusCvtPath), fileName, soundOutput)
		local comprErr, out = AsyncExec(cmdline, "", true, false)
		if comprErr then
			table.insert(err, string.format("Failed creating compressed sound for '%s': %s.", fileName, comprErr))
			goto continue
		else
			partialSuccess = true
		end
		
		::continue::
	end
	
	return err, partialSuccess
end

local function ParticleTexturesImport(srcFolder, destFolder, assetTypeInfo, ged_socket, importedFiles)
	--Find files from dest
	local err, assetsForImport = AsyncListFiles(srcFolder)
	local partialSuccess
	
	if err then
		return { string.format("Failed reading files in source folder: %s", srcFolder) }
	end
	
	--Create folders
	local fallbackDir = destFolder .. "/Fallbacks/"
	err = AsyncCreatePath(destFolder)
	if err then
		return { string.format("Failed creating '%s' directory: %s.", assetTypeInfo.folder, err) }
	end
	
	err = AsyncCreatePath(fallbackDir)
	if err then
		return string.format("Failed creating 'Fallbacks' directory: %s.", err)
	end
	
	--Import and Convert found files and do not stop proccess for specific errors per files
	err = {}
	local totalNumber = assetsForImport and #assetsForImport
	for idx, fileName in ipairs(assetsForImport) do
		UpdateImportedFileStatus(idx, totalNumber)
		local dir, name, ext = SplitPath(fileName)
		
		if next(assetTypeInfo.ext) and not table.find(assetTypeInfo.ext, ext) then
			table.insert(err, string.format("Failed importing file '%s' : file type '%s' not supported", name, ext))
			goto continue
		end
		
		local w, h = UIL.MeasureImage(fileName)
		local errMsg = string.format("The import of '%s' failed because the image width and height are wrong. Image must be a square and pixel width and height must be power of two (e.g. 1024, 2048, 4096, etc.).", fileName)
		if w ~= h then
			table.insert(err, errMsg)
			goto continue
		end
		
		if w <= 0 or band(w, w - 1) ~= 0 then --check if there's only one bit set in the entire number (equivalent to it being a power of 2)
			table.insert(err, errMsg)
			goto continue
		end
		
		-- use the same file name, just add the .dds extension
		local textureName = name .. ".dds"
		local textureOutput = destFolder .. "/" .. textureName
		local fallbackOutput = fallbackDir .. textureName
		
		-- Create the compressed textures that we will use in the game from the uncompressed one provided by the mod	
		local cmdline = string.format("\"%s\" -dds10 -24 bc1 -32 bc3 -srgb \"%s\" \"%s\"", ConvertToOSPath(g_HgnvCompressPath), fileName, textureOutput)
		local comprErr, out = AsyncExec(cmdline, "", true, false)
		if comprErr then
			table.insert(err, string.format("Failed creating compressed image for '%s': %s.", fileName, comprErr))
			goto continue
		end
		
		-- Create the fallback for the compressed texture
		cmdline = string.format("\"%s\" \"%s\" \"%s\" --truncate %d", ConvertToOSPath(g_HgimgcvtPath), textureOutput, fallbackOutput, const.FallbackSize)
		local fallbackErr = AsyncExec(cmdline, "", true, false)
		if fallbackErr then
			table.insert(err, string.format("Failed creating fallback image for '%s': %s.", fileName, fallbackErr))
			goto continue
		else
			partialSuccess = true
		end
		
		::continue::
	end
	
	return err
end

if FirstLoad then
	ModAssetTypeInfo = {
		["UI image"] = {folder = "Images", ext = {".png", ".jpg", ".tga"}, importFunc = UIImageImport},
		["Particle Texture"] = {folder = "ParticleTextures", ext = {".png", ".jpg", ".tga"}, importFunc = ParticleTexturesImport},
		["Sound"] = {folder = "Sounds", ext = {".wav"}, importFunc = SoundImport},
		["Font"] = {folder = "Fonts"},--used only for the folder prop that is accessed by the gedpropeditor browse
	}
end

---
--- Returns the destination folder for the specified asset type.
---
--- @param assetType string The asset type, e.g. "UI image", "Particle Texture", "Sound".
--- @return string The destination folder for the specified asset type.
function GetModAssetDestFolder(assetType)
	return ModAssetTypeInfo[assetType].folder
end

DefineClass.ModItemConvertAsset =  {
	__parents = { "ModItem" },
	
	EditorName = "Convert & import assets",
	EditorSubmenu = "Assets",
	Documentation = "Imports your <style GedHighlight>UI images, particle textures, and sound assets</style> into the mod folder. This copies them inside the mod folder and converts them to the specific format that the engine uses.\n\nNOTE: You need only one of these per asset type. Importing <style GedHighlight>always deletes the destination folder</style> before executing on all files in the Source Folder.",
	
	properties = {
		{ id = "assetType", name = "Asset Type", editor = "dropdownlist", default = "UI image", help = "Depending on this choice the import will convert the source files to the correct format for the game engine.",
			items = { "UI image", "Particle Texture", "Sound"}, arbitrary_value = false, 
		},
		{ id = "allowedExt", name = "Allowed Extensions", read_only = true, editor = "text", default = ""},
		{ id = "srcFolder", name = "Source Folder", editor = "browse", os_path = true, filter = "folder", default = "", dont_save = true, help = "The folder from which ALL assets of the selected type will be imported.\n<style GedHighlight>Note:</style> Do not give a path inside the mod itself as the import will already copy the files in the mod." },
		{ id = "destFolder", name = "Destination Folder", editor = "browse", filter = "folder", default = "", help = "The folder inside the mod in which the imported assets will be placed." },
		{ id = "btn", editor = "buttons", default = false, buttons = {{name = "Convert & Import Files From Source Folder", func = "Import"}}, untranslated = true},
	}, 
}

---
--- Imports assets of the specified type from the source folder into the mod's destination folder.
---
--- This function is called when the "Convert & Import Files From Source Folder" button is clicked in the editor.
--- It first checks for any errors or warnings, then deletes the destination folder, and finally imports the assets from the source folder.
--- The imported files are converted to the format required by the game engine.
---
--- @param root table The root object of the editor.
--- @param prop_id string The ID of the property that triggered the function.
--- @param ged_socket table The GED socket object.
---
function ModItemConvertAsset:Import(root, prop_id, ged_socket)
	CreateRealTimeThread(function()
		if self:GetError() then
			ged_socket:ShowMessage("Fail", "Please resolve the displayed error before importing assets!")
			return
		end
		
		local assetType = self.assetType
		local srcFolderOs = self.srcFolder
		local destFolderOS = ConvertToOSPath(self.destFolder)
		
		if ged_socket:WaitQuestion("Warning", string.format("Before the import, this will <style GedHighlight>DELETE</style> all content in the Destination Folder: <style GedHighlight>%s</style>\n\nAre you sure you want to continue?", destFolderOS), "Yes", "No") ~= "ok" then
			return
		end
		
		GedSetUiStatus("importAssets", "Importing...")
		local importedFiles = 0
		AsyncDeletePath(destFolderOS)
		local err, partialSuccess = ModAssetTypeInfo[assetType].importFunc(srcFolderOs, destFolderOS, ModAssetTypeInfo[assetType], ged_socket, importedFiles)
		
		if not next(err) then
			ged_socket:ShowMessage("Success", "Files imported successfully!")
		else
			local allErrors = table.concat(err, "\n")
			if partialSuccess then
				ged_socket:ShowMessage("Partial Success", string.format("Couldn't import all assets:\n\n%s", allErrors))
			else
				ged_socket:ShowMessage("Fail", string.format("Couldn't import assets:\n\n%s", allErrors))
			end
		end
		
		self:OnModLoad()
		
		GedSetUiStatus("importAssets")
	end)
end

---
--- Handles changes to the `assetType` property of the `ModItemConvertAsset` object.
---
--- When the `assetType` property is changed, this function updates the `destFolder` and `allowedExt` properties based on the new `assetType`.
--- If the `assetType` is not set, the `allowedExt` property is set to an empty string.
---
--- This function also calls the `OnEditorSetProperty` function of the parent `ModItemPreset` object.
---
--- @param prop_id string The ID of the property that was changed.
--- @param old_value any The previous value of the property.
--- @param ged table The GED socket object.
--- @return any The return value of the parent `OnEditorSetProperty` function.
---
function ModItemConvertAsset:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "assetType" and self.assetType then
		self.destFolder = self.mod.content_path .. ModAssetTypeInfo[self.assetType].folder
		self.allowedExt = table.concat(ModAssetTypeInfo[self.assetType].ext, " | ")
	end
	if not self.assetType then
		self.allowedExt = ""
	end
	
	return ModItemPreset.OnEditorSetProperty(self, prop_id, old_value, ged)
end

---
--- Initializes a new `ModItemConvertAsset` object.
---
--- This function is called when a new `ModItemConvertAsset` object is created. It sets the initial values for the `name`, `destFolder`, and `allowedExt` properties.
---
--- @param mod table The `ModItem` object that this `ModItemConvertAsset` belongs to.
--- @param ged table The GED socket object.
--- @param is_paste boolean Whether this object was created by pasting it from elsewhere.
---
function ModItemConvertAsset:OnEditorNew(mod, ged, is_paste)
	self.name = "ConvertAsset"
	self.destFolder = self.mod.content_path .. ModAssetTypeInfo[self.assetType].folder
	self.allowedExt = table.concat(ModAssetTypeInfo[self.assetType].ext, " | ")
end

---
--- Returns a description of the ModItemConvertAsset object.
---
--- The description is a string that includes the asset type and the name of the ModItemConvertAsset object.
---
--- @return string The description of the ModItemConvertAsset object.
---
function ModItemConvertAsset:ModItemDescription()
	return Untranslated(self.assetType .. " - " .. self.name)
end

---
--- Checks for warnings related to the `ModItemConvertAsset` object.
---
--- This function checks the following conditions and returns a warning message if any of them are true:
---
--- 1. If the `srcFolder` property is not empty, it checks if the `srcFolder` path is inside the mod's content path. If so, it returns a warning message.
--- 2. If the `mod` property is not `nil`, it checks if there are any other `ModItemConvertAsset` objects in the mod with the same `assetType`. If so, it returns a warning message.
---
--- @return string|nil The warning message, or `nil` if there are no warnings.
---
function ModItemConvertAsset:GetWarning()
	if self.srcFolder ~= "" then
		local srcFolderFullPath = ConvertToOSPath(self.srcFolder)
		local modFolderFullPath = ConvertToOSPath(self.mod.content_path)
		if string.starts_with(srcFolderFullPath, modFolderFullPath, true) then
			return "Source Folder should not point to a location inside the mod itself."
		end
	end
	
	if not self.mod then return end
	return self.mod:ForEachModItem("ModItemConvertAsset", function(item)
		if item ~= self and self.assetType == item.assetType then
			return "Having more than one Convert Asset mod item for the same asset type is not recommended as both overwrite the destination folder."
		end
	end)
end

---
--- Checks for errors in the `ModItemConvertAsset` object.
---
--- This function checks the following conditions and returns an error message if any of them are true:
---
--- 1. If the `name` property is empty, it returns an error message.
--- 2. If the `name` property is not unique among other `ModItemConvertAsset` objects in the same mod, it returns an error message.
--- 3. If the `assetType` property is `nil`, it returns an error message.
--- 4. If the `srcFolder` property is empty, it returns an error message.
--- 5. If the `srcFolder` path does not exist, it returns an error message.
---
--- @return string|nil The error message, or `nil` if there are no errors.
---
function ModItemConvertAsset:GetError()
	if not self.name or self.name == "" then
		return "Set a name for the mod item."
	end
	
	if self.name and self.mod then
		local ret = self.mod:ForEachModItem("ModItemConvertAsset", function(item)
			if item ~= self then
				if item.name == self.name then
					return string.format("The name of the mod item '%s' must be unique!", self.name)
				end
			end
		end)
		if ret then return ret end
	end

	if not self.assetType then
		return "Pick an asset type."
	end
	
	if not self.srcFolder or self.srcFolder == "" then
		return "Pick source folder path."
	end
	
	if not io.exists(self.srcFolder) then
		return "Source folder does not exist."
	end
end

----- ModResourceMap - Describes a map affected by a mod. 
----- The map can be changed by a map patch, which adds/changes/deletes objects and terrain or it can be replaced entirely.
----- If it's replaced entirely, only the Map property will be set.
DefineClass.ModResourceMap = {
	__parents = { "ModResourceDescriptor" },
	properties = {
		{ id = "Map", name = "Map", editor = "text", default = false, },
		{ id = "Objects", name = "Objects", editor = "prop_table", default = false, },
		{ id = "Grids", name = "Grids", editor = "prop_table", default = false, },
		{ id = "ObjBoxes", name = "Object Boxes", editor = "prop_table", default = false, },
	},
}

---
--- Checks for conflicts between two `ModResourceMap` objects.
---
--- @param other ModResourceMap The other `ModResourceMap` object to check for conflicts.
--- @return boolean, string|table Whether a conflict was found, and the reason for the conflict.
---
--- The function checks for conflicts between two `ModResourceMap` objects in the following ways:
--- - If the `Map` property is different, there is no conflict.
--- - If both objects have `Objects` tables, it checks if any of the object hashes match, indicating a conflict.
--- - If both objects have `Grids` tables, it checks if any of the grid areas intersect, and returns the grid name and intersection box if so.
--- - If both objects have `ObjBoxes` tables, it checks if any of the object boxes intersect, indicating a conflict.
--- - If no other conflicts are found, it returns `true` and the reason `"map_replaced"`, indicating that one map is replacing the other.
---
function ModResourceMap:CheckForConflict(other)
	if self.Map ~= other.Map then return false end

	if self.Objects and other.Objects then
		for _, hash in ipairs(self.Objects) do
			for _, o_hash in ipairs(other.Objects) do
				if hash == o_hash then
					return true, "objects"
				end
			end
		end
	end
	
	if self.Grids and other.Grids then
		for _, grid in ipairs(editor.GetGridNames()) do
			if self.Grids[grid] and other.Grids[grid] then
				local w, h = IntersectSize(self.Grids[grid], other.Grids[grid])
				if w > 0 and h > 0 then -- if only one is > 0 then only the borders are touching
					return true, { grid = grid, intersection_box = IntersectRects(self.Grids[grid], other.Grids[grid]) }
				end
			end
		end
	end
	
	if self.ObjBoxes and other.ObjBoxes then
		for _, bx in ipairs(self.ObjBoxes) do
			for _, o_bx in ipairs(other.ObjBoxes) do
				if bx:Intersect2D(o_bx) > 0 then
					return true, "objects"
				end
			end
		end
	end

	return true, "map_replaced"
end

---
--- Returns a text description of the resource conflict based on the provided reason.
---
--- @param reason string|table The reason for the resource conflict.
--- @return string The text description of the resource conflict.
---
function ModResourceMap:GetResourceTextDescription(reason)
	if reason == "map_replaced" then
		return string.format("\"%s\" map", self.Map)
	end

	if reason == "objects" then -- objects
		return string.format("Object(s) on the \"%s\" map", self.Map)
	end
	
	if type(reason) == "table" then -- grids
		return string.format("Area(s) of the \"%s\" map", self.Map)
	end
	
	return string.format("Area(s) or object(s) on the \"%s\" map", self.Map)
end
