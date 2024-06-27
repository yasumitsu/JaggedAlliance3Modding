-- Presets
-- Inherit preset class, if GedEditor is provided, a menu entry is created for editing
-- Presets[class] - the array part is a list of all preset groups, the name part maps to group by name
-- Presets[class][group] - the array part is a list of all presets in the group, the name part maps to preset by name
-- Presets[class][group][id] - the preset of <class> with <group> and <id>
-- Preset.id - unique id within the group
-- Preset.group - group id
---
--- Preset class that inherits from `GedEditedObject`, `Container`, and `InitDone`.
--- Presets are used to store and manage configuration settings for various game systems.
--- The class provides properties and methods for managing preset groups, IDs, save locations, parameters, comments, and other metadata.
---
--- @class Preset
--- @field group string The group the preset belongs to.
--- @field id string The unique identifier of the preset within its group.
--- @field save_in string The location where the preset is saved.
--- @field StoreAsTable boolean Whether the preset should be stored as a table for optimized loading.
--- @field PropertyTranslation boolean Whether property translation is enabled for the preset.
--- @field PersistAsReference boolean Whether the preset should be persisted as a reference.
--- @field UnpersistedPreset boolean Whether the preset is a special fallback preset used when a preset is missing during savegame loading.
--- @field __hierarchy_cache boolean Whether the preset has a cached hierarchy.
--- @field PresetIdRegex string The regular expression pattern for valid preset IDs.
--- @field HasGroups boolean Whether the preset has groups.
--- @field PresetGroupPreset boolean The preset class for the preset group.
--- @field HasSortKey boolean Whether the preset has a sort key.
--- @field HasParameters boolean Whether the preset has parameters.
--- @field HasObsolete boolean Whether the preset is obsolete.
--- @field PresetClass boolean The override for the preset class.
--- @field FilePerGroup boolean Whether each preset group is saved in a separate file.
--- @field SingleFile boolean Whether the presets are saved in a single file or each in its own file.
--- @field LocalPreset boolean Whether the preset is a local preset that is not added to subversion.
--- @field GlobalMap boolean The global table where the preset IDs are stored if they need to be globally unique.
--- @field FilterClass boolean The class used to filter the preset.
--- @field SubItemFilterClass boolean The class used to filter the preset's sub-items.
--- @field AltFormat boolean An alternative format string for the preset tree panel in the Ged editor.
--- @field HasCompanionFile boolean Whether the preset has a companion file.
--- @field GeneratesClass boolean Whether the preset generates a class.
--- @field TODOItems boolean The list of TODO items for the preset.
--- @field NoInstances boolean Whether the preset cannot be instantiated in the editor.
--- @field GedEditor string The name of the Ged editor used for the preset.
--- @field SingleGedEditorInstance boolean Whether only one editor instance can be opened at a time.
--- @field EditorMenubarName string The name of the editor in the dev menu.
--- @field EditorMenubarSortKey string The sort key for the editor in the dev menu.
--- @field EditorShortcut boolean The shortcut to the editor.
--- @field EditorIcon boolean The icon for the editor in the dev menu.
--- @field EditorMenubar string The position of the editor in the dev menu.
--- @field EditorName boolean The name of the editor as viewed inside the editors.
--- @field EditorView string The view template for the editor.
--- @field EditorViewPresetPrefix string The prefix for the preset view in the editor.
--- @field EditorViewPresetPostfix string The postfix for the preset view in the editor.
--- @field EditorCustomActions boolean The custom actions for the editor.
--- @field EnableReloading boolean Whether reloading is enabled for the preset.
--- @field ValidateAfterSave boolean Whether validation is performed after saving the preset.
DefineClass.Preset = {
	__parents = { "GedEditedObject", "Container", "InitDone" },
	properties = {
		{ category = "Preset", id = "Group", editor = "combo", default = "Default", 
			items = function(obj)
				local group_class = g_Classes[obj.PresetGroupPreset]
				if group_class then
					assert(_G[group_class.GlobalMap]) -- groups need to have unique ids
					return PresetsCombo(group_class.PresetClass or group_class.class)()
				else
					return PresetGroupsCombo(obj.PresetClass or obj.class)()
				end
			end,
			validate = function(self, value, ged)
				-- presets in the new group must not have the same id
				local groups = Presets[self.PresetClass or self.class]
				local presets = groups and groups[value]
				if presets and presets[self.id] and presets[self.id].save_in == self.save_in then
					return "A preset with the same id exists in the target group."
				end
				local group_class = g_Classes[self.PresetGroupPreset]
				if group_class then
					local map = _G[group_class.GlobalMap]
					assert(map) -- preset's group class must have a global map
					if not map or not map[value] then
						return "Preset group doesn't exist."
					end
				elseif value == "" then
					return "Preset group can't be empty."
				end
			end,
			no_edit = function (obj) return not obj.HasGroups end, },
			
		{ category = "Preset", id = "SaveIn", name = "Save in", editor = "choice", default = "", 
			items = function(obj) return obj:GetPresetSaveLocations() end, },

		{ category = "Preset", id = "Id", editor = "text", default = "", validate = function(self, value) 
			-- ids must be valid identifiers
			if type(value) ~= "string" or not value:match(self.PresetIdRegex) then
				return "Id must be a valid identifier (starts with a letter, contains letters/numbers/_ only)."
			end
			-- ids must be unique in the group
			local groups = Presets[self.PresetClass or self.class]
			local presets = groups and groups[self.group]
			local with_same_id = presets and presets[value]
			if with_same_id and with_same_id ~= self and with_same_id:GetSaveFolder() == self:GetSaveFolder() then
				return "A preset with this Id already exists in this group (for the same save location)."
			end
			-- for some presets ids must be globally unique
			with_same_id = self.GlobalMap and _G[self.GlobalMap][value]
			if with_same_id and with_same_id ~= self and with_same_id:GetSaveFolder() == self:GetSaveFolder() then
				return "A preset with this Id already exists."
			end
		end},
		{ category = "Preset", id = "SortKey", name = "Sort key", editor = "number", default = 0, 
			no_edit = function(obj) return not obj.HasSortKey end, 
			dont_save = function(obj) return not obj.HasSortKey end,
			help = "An arbitrary number used to sort items in ascending order" },
		{ category = "Preset", id = "Parameters", name = "Parameters", editor = "nested_list",
			base_class = "PresetParam", default = false, no_edit = function(self) return not self.HasParameters end,
			help = "Create named parameters for numeric values and use them in multiple places.\n\nFor example, if an event checks that an amount of money is present, subtracts this exact amount, and displays it in its text, you can create an Amount parameter and reference it in all three places. When you later adjust this amount, you can do it from a single place.\n\nThis can prevent omissions and errors when numbers are getting tweaked later.",
		},
		-- hidden property for param bindings, injected to all subobjects for saving purposes
		{ id = "param_bindings", editor = "prop_table", default = false, no_edit = true,
			inject_in_subobjects = function(self) return self.HasParameters end, },
		{ category = "Preset", id = "Comment", name = "Comment", editor = "text", default = "", 
			lines = 1, max_lines = 10 },
		{ category = "Preset", id = "TODO", name = "To do", 
			editor = "set", default = false, 
			no_edit = function(self) return not self.TODOItems end, 
			dont_save = function(self) return not self.TODOItems end, 
			items = function (self) return self.TODOItems end, },
		{ category = "Preset", id = "Obsolete", editor = "bool", default = false, 
			no_edit = function(self) return not self.HasObsolete end, 
			dont_save = function(self) return not self.HasObsolete end, 
			help = "Obsolete presets are kept for backwards compatibility and should not be visible in the game", },
		{ category = "Preset", id = "Documentation", editor = "documentation", dont_save = true, sort_order = 9999999 }, -- display collapsible Documentation at this position
	},
	group = "Default",
	id = "",
	save_in = "",

	StoreAsTable = true, -- to optimize loading times
	PropertyTranslation = false,
	PersistAsReference = true, -- when true preset instances will only be referenced by savegames, if false used preset instance data will be saved
	UnpersistedPreset = false, -- a special preset ID used as a fallback if a preset is missing during savegame loading
	__hierarchy_cache = true,
	
	-- preset settings
	PresetIdRegex = "^[%w_+-]*$",
	HasGroups = true,
	PresetGroupPreset = false,
	HasSortKey = false,
	HasParameters = false,
	HasObsolete = false,
	PresetClass = false, -- override preset class
	FilePerGroup = false, -- save each preset group in a separate file
	SingleFile = true, -- save in a single file or each preset in its own file (if FilePerGroup is false)
	LocalPreset = false, -- if set the file will not be added to subversion
	GlobalMap = false, -- if set the ids will be globally unique and stored in this global table
	FilterClass = false,
	SubItemFilterClass = false,
	AltFormat = false, -- an alternative format string for the preset tree panel in Ged, e.g. to show presets by display name instead of id
	HasCompanionFile = false,
	GeneratesClass = false,
	TODOItems = false,
	NoInstances = false, -- do not allow instantiating the preset in the editor

	-- Ged editor settings
	GedEditor = "PresetEditor",
	SingleGedEditorInstance = true, -- At most one editor can be opened at any time.
	EditorMenubarName = "", -- name of editor in dev menu, empty string means "use the class name"
	EditorMenubarSortKey = "",
	EditorShortcut = false, -- shortcut to editor
	EditorIcon = false, -- icon of the dev menu entry
	EditorMenubar = "Editors", -- position in the dev menu
	EditorName = false, -- name as viewed inside the editors, e.g. name in the menu for creating a new object/subitem
	EditorView = Untranslated("<EditorViewPresetPrefix><def(id,'[unnamed preset]')><EditorViewPresetPostfix><EditorViewTODO><color 0 128 0><opt(u(Comment),' ','')><color 128 128 128><opt(u(save_in),' - ','')>"),
	EditorViewPresetPrefix = "",
	EditorViewPresetPostfix = "",
	EditorCustomActions = false,
	
	EnableReloading = true,
	ValidateAfterSave = false,
}

if FirstLoad then
	g_PresetParamCache = setmetatable({}, weak_keys_meta)
	g_PresetLastSavePaths = rawget(_G, "g_PresetLastSavePaths") or setmetatable({}, weak_keys_meta)
	g_PresetAllSavePaths = setmetatable({}, weak_keys_meta)
	g_PresetDirtySavePaths = {}
	g_PresetFileTimestampAtSave = {}
	g_PresetCurrentLuaFileSavePath = false
	g_PresetForbidSerialize = false
	g_PresetRefreshingFunctionValues = false
	g_PendingPresetImageAdds = false
	PresetsLoadingFileName = false
end

---
--- Gathers the editor custom actions for the preset.
---
--- @param actions table The table to append the custom actions to.
---
function Preset:GatherEditorCustomActions(actions)
	table.iappend(actions, self.EditorCustomActions) 
end

---
--- Returns the editor view for this preset.
---
--- @return string The editor view for this preset.
---
function Preset:GetEditorView()
	return self.EditorView
end

---
--- Returns the rollover text for this preset.
---
--- @return string The rollover text for this preset.
---
function Preset:GetPresetRolloverText()
end

---
--- Returns the preset status text.
---
--- @return string The preset status text.
---
function Preset:GetPresetStatusText()
	return ""
end

---
--- Returns whether the preset is read-only.
---
--- @return boolean Whether the preset is read-only.
---
function Preset:IsReadOnly()
	return config.ModdingToolsInUserMode
end

---
--- Returns whether the preset is currently open in the GED.
---
--- @return boolean Whether the preset is open in the GED.
---
function Preset:IsOpenInGed()
	local presets = Presets[self.PresetClass or self.class]
	return not not GedObjects[presets]
end

---
--- Removes the preset from the preset groups and restores the previous preset if it exists.
---
--- @param self Preset The preset object.
---
function Preset:Done()
	local id = self.id
	local groups = Presets[self.PresetClass or self.class]
	local presets = groups[self.group]
	if presets then
		table.remove_entry(presets, self)
		if presets[id] == self then
			presets[id] = nil
			--restore old preset
			for i=#presets,1,-1 do
				local preset_i = presets[i]
				if preset_i ~= self and preset_i.id == id then
					presets[id] = preset_i
					break
				end
			end
		end
		if #presets == 0 then
			table.remove_entry(groups, presets)
			groups[self.group] = nil
		end
	end
	local global = rawget(_G, self.GlobalMap)
	if global and global[id] == self then
		global[id] = nil
		--restore old preset
		for i=#groups,1,-1 do
			local group_i = groups[i]
			for j=#group_i,1,-1 do
				local preset_j = group_i[j]
				if preset_j ~= self and preset_j.id == id then
					global[id] = preset_j
					goto found
				end
			end
		end
		::found::
	end
end

---
--- Sets the group for the preset.
---
--- @param self Preset The preset object.
--- @param group string The new group for the preset.
---
function Preset:SetGroup(group)
	if g_PresetRefreshingFunctionValues then -- reloading after save to refresh function values with correct debug info
		self.group = group
		return
	end
	
	group = group ~= "" and group or "Default"
	local id = self.id
	local groups = Presets[self.PresetClass or self.class]
	local presets = groups[self.group]
	if presets then
		table.remove_entry(presets, self)
		if presets[id] == self then
			presets[id] = nil
			--restore old preset
			for i=#presets,1,-1 do
				local preset_i = presets[i]
				if preset_i ~= self and preset_i.id == id then
					presets[id] = preset_i
					break
				end
			end
		end
		if #presets == 0 then
			table.remove_entry(groups, presets)
			groups[self.group] = nil
		end
	end
	self.group = group
	presets = groups[group]
	if not presets then
		presets = {}
		groups[group] = presets
		groups[#groups + 1] = presets
	end
	presets[#presets + 1] = self
	if id ~= "" then
		presets[id] = self
		if ParentTableCache[self] then
			UpdateParentTable(self, presets) -- set the correct table parent after undo operations
		end
	end
	ObjModified(groups)
end

--- Returns the group for the preset.
---
--- @return string The group for the preset.
function Preset:GetGroup()
	return self.group
end

--- Sets the ID of the preset.
---
--- If the preset is being reloaded after a save, the ID is set directly without any additional logic.
---
--- Otherwise, the function performs the following steps:
--- - Retrieves the group table for the preset's class or class.
--- - Stores the old ID of the preset.
--- - If the preset is registered in a global table, removes the old ID from the global table and tries to restore the old preset.
--- - If a new ID is provided, checks if there is an existing preset with the same ID in the global table, and if so, asserts that the save location is different.
--- - Updates the global table with the new ID, if provided.
--- - Retrieves the group table for the preset's group.
--- - If the group table exists, removes the old ID from the group table and tries to restore the old preset.
--- - If the group table does not exist, creates a new group table and adds it to the groups table.
--- - Sets the new ID for the preset.
--- - If a new ID is provided, adds the preset to the group table under the new ID, and updates the parent table cache if necessary.
---
--- @param id string The new ID for the preset.
function Preset:SetId(id)
	if g_PresetRefreshingFunctionValues then -- reloading after save to refresh function values with correct debug info
		self.id = id
		return
	end
	
	local groups = Presets[self.PresetClass or self.class]
	local old_id = self.id
	local global = rawget(_G, self.GlobalMap)
	if global then
		if global[old_id] == self then
			global[old_id] = nil
			--restore old preset
			for i=#groups,1,-1 do
				local group_i = groups[i]
				for j=#group_i,1,-1 do
					local preset_j = group_i[j]
					if preset_j ~= self and preset_j.id == old_id then
						global[old_id] = preset_j
						goto found
					end
				end
			end
			::found::
		end
		if id ~= "" then
			local existing = global[id]
			if existing and existing ~= self then
				assert(self:GetSaveIn() ~= existing:GetSaveIn(),
					string.format("Multiple copies of presets with id %s exist in %s.", id, self.save_in))
			end
			global[id] = self
		end
	end
	local presets = groups[self.group]
	if presets then
		if presets[old_id] == self then
			presets[old_id] = nil
			--restore old preset
			for i=#presets,1,-1 do
				local preset_i = presets[i]
				if preset_i ~= self and preset_i.id == old_id then
					presets[old_id] = preset_i
					break
				end
			end
		end
	else
		assert(false, "You should call :Register() on new presets")
		presets = { }
		groups[self.group] = presets
		groups[#groups + 1] = presets
	end
	self.id = id
	if id ~= "" then
		presets[id] = self
		if ParentTableCache[self] or ParentTableCache[presets] then
			UpdateParentTable(self, presets) -- set the correct table parent after undo operations
		end
	end
end

---
--- Returns the unique identifier of the preset.
---
--- @return string The unique identifier of the preset.
function Preset:GetId()
	return self.id
end

---
--- Sets the save location for the preset.
---
--- @param save_in string The save location for the preset. Can be an empty string, in which case the save location will be set to `nil`.
function Preset:SetSaveIn(save_in)
	self.save_in = save_in ~= "" and save_in or nil
end

---
--- Returns the save location for the preset.
---
--- @return string The save location for the preset.
function Preset:GetSaveIn()
	return self.save_in
end

---
--- Returns the save location type for the preset.
---
--- @return string The save location type, either "common" or "game".
function Preset:GetSaveLocationType()
	local save_in = self:GetSaveIn()
	if save_in == "Common" or save_in == "Ged" or save_in:starts_with("Lib") then
		return "common"
	end
	return "game"
end

---
--- Returns a list of default save locations for presets.
---
--- The list includes the "Common" location, as well as a location for each loaded library.
---
--- @return table A table of save location options, with `text` and `value` fields for each option.
function GetDefaultSaveLocations()
	local locations = DlcComboItems{ text = "Common", value = "Common" }
	ForEachLib(nil, function(lib, path, locations)
		locations[#locations + 1] = { text = "lib " .. lib, value = "Libs/" .. lib }
	end, locations)
	return locations
end

---
--- Returns a list of default save locations for presets.
---
--- The list includes the "Common" location, as well as a location for each loaded library.
---
--- @return table A table of save location options, with `text` and `value` fields for each option.
function Preset:GetPresetSaveLocations()
	return GetDefaultSaveLocations()
end

---
--- Performs post-load actions for the Preset object.
---
--- If the Preset has parameters, it iterates through all sub-objects and sets the `param_bindings` field to `false` if the object is not a `PresetParam`.
---
--- If the Preset has any parameters, it creates a cache of the parameter names and values and stores it in the `g_PresetParamCache` table.
---
--- @function Preset:PostLoad
--- @return nil
function Preset:PostLoad()
	if self.HasParameters then
		self:ForEachSubObject(function(obj)
			if not obj:IsKindOf("PresetParam") then
				rawset(obj, "param_bindings", rawget(obj, "param_bindings") or false)
			end
		end)
	end
	if #(self.Parameters or empty_table) > 0 then
		local cache = {}
		for _, param in ipairs(self.Parameters) do
			cache[param.Name] = param.Value
		end
		g_PresetParamCache[self] = cache
	end
end

---
--- Resolves the value of the specified key for the Preset object.
---
--- If the key is not found in the Preset object, it checks the `g_PresetParamCache` table for the value.
---
--- @param key string The key to resolve the value for.
--- @return any The resolved value for the specified key.
function Preset:ResolveValue(key)
	local value = self:GetProperty(key)
	if not value and g_PresetParamCache[self] then
		return g_PresetParamCache[self][key]
	end
	return value
end

---
--- Registers a Preset object with the Presets table.
---
--- If the Preset's group does not exist in the Presets table, it creates a new entry for the group.
--- The Preset is then added to the group's list of presets.
---
--- If the Preset has an ID, it is also added to the Presets table using the ID as the key.
--- If the Preset has a GlobalMap defined, the Preset is also added to the global table using the ID as the key.
---
--- @param id string (optional) The ID to use for the Preset in the Presets table.
--- @param update_parent_table_cache boolean (optional) Whether to update the parent table cache.
--- @return nil
function Preset:Register(id, update_parent_table_cache)
	local group = self.group
	local groups = Presets[self.PresetClass or self.class]
	local presets = groups[group]
	if not presets then
		presets = {}
		groups[group] = presets
		groups[#groups + 1] = presets
	end
	presets[#presets + 1] = self
	
	if update_parent_table_cache then
		UpdateParentTable(presets, groups)
		ParentTableModified(self, presets, "recursive")
	end
	
	id = id or self.id
	if id ~= "" then
		presets[id] = self
		local global = rawget(_G, self.GlobalMap)
		if global then
			global[id] = self
		end
	end
end

---
--- Returns a string representation of the TODO items that are set on the Preset.
---
--- The returned string will be formatted as " <color 255 140 0>[item1 item2 item3]</color>" if any TODO items are set, or an empty string if no TODO items are set.
---
--- @return string The formatted string representation of the TODO items.
---
function Preset:GetEditorViewTODO()
	local v
	local todo = self.TODO or empty_table
	for _, item in ipairs(self.TODOItems) do
		if todo[item] then
			if v then
				v[#v + 1] = " "
			else
				v = {" <color 255 140 0>["}
			end
			v[#v + 1] = item
		end
	end
	if not v then return "" end
	v[#v + 1] = "]</color>"
	return Untranslated(table.concat(v, ""))
end

-- The preset has just been saved; update its function values from
-- reloaded_obj, so the resaved functions have correct debug info.
---
--- Recursively resets the function values of a preset object to the values of a reloaded object.
---
--- This function is used to update the debug information of functions in a preset object after it has been reloaded.
---
--- @param preset The preset object to update.
--- @param reloaded_obj The reloaded object to copy function values from.
---
function preset_reset_fn_values(preset, reloaded_obj)
	for k, v in pairs(preset) do
		if k ~= "__index" then
			local reloaded_value = reloaded_obj[k]
			if type(v) == "table" and type(reloaded_value) == "table" then
				preset_reset_fn_values(v, reloaded_value)
			elseif type(v) == "function" and type(reloaded_value) == "function" then
				preset[k] = reloaded_value
			end
		end
	end
end

---
--- Finds the original preset object that corresponds to the current preset object.
---
--- This function searches the `Presets` table for the preset object that has the same `PresetClass` (or `class`), `group`, `id`, and `save_in` as the current preset object.
---
--- @return table|nil The original preset object, or `nil` if it cannot be found.
---
function Preset:FindOriginalPreset()
	local presets = Presets[self.PresetClass or self.class][self.group]
	for _, original_preset in ipairs(presets) do
		if original_preset.id == self.id and original_preset.save_in == self.save_in then
			return original_preset
		end
	end
end

---
--- Refreshes the function values of a preset object to the values of the original preset object.
---
--- This function is used to update the debug information of functions in a preset object after it has been reloaded.
---
--- @param self The preset object to update.
---
function Preset:RefreshFunctionValues()
	local original_preset = self:FindOriginalPreset()
	assert(original_preset, "Unable to find a preset that was just saved")
	if original_preset then
		preset_reset_fn_values(original_preset, self)
		original_preset:MarkClean()
	end
end

-- set up special functions for loading presets, so we can capture the filenames they are loaded from
local function instrument_loading(fn_name)
	return function(...)
		local old_fn = dofile
		dofile = function(name, fenv)
			PresetsLoadingFileName = name
			old_fn(name, fenv)
			PresetsLoadingFileName = false
		end
		_G[fn_name](...)
		dofile = old_fn
	end
end

LoadPresetFiles = instrument_loading("dofolder_files")
LoadPresetFolders = instrument_loading("dofolder_folders")
LoadPresetFolder = instrument_loading("dofolder")
---
--- Loads presets from the specified file.
---
--- This function is used to load presets from a file. It sets the `PresetsLoadingFileName` global variable to the file name, calls `pdofile` to load the presets, and then sets `PresetsLoadingFileName` back to `false`.
---
--- @param name string The file name to load the presets from.
--- @param fenv table The environment to use when loading the presets.
---
LoadPresets = function(name, fenv)
	PresetsLoadingFileName = name
	pdofile(name, fenv)
	PresetsLoadingFileName = false
end

---
--- Stores the file paths that a preset was loaded from.
---
--- This function is called when a preset is loaded from a file. It stores the file name that the preset was loaded from in the `g_PresetLastSavePaths` table, and also stores a list of any companion files (such as auto-generated files) that were loaded along with the preset in the `g_PresetAllSavePaths` table. If any of the companion files are missing, it asserts an error.
---
--- @param self The preset object.
---
function Preset:StoreLoadedFromPaths()
	if PresetsLoadingFileName and Platform.developer and not Platform.cmdline and not Platform.console and self.class ~= "DLCPropsPreset" then
		g_PresetLastSavePaths[self] = PresetsLoadingFileName
		
		local save_paths = self:GetCompanionFilesList(PresetsLoadingFileName)
		if save_paths then
			for key, name in pairs(save_paths) do
				if not io.exists(name) then
					assert(false, string.format("Missing auto-generated file\n%s\n\nTry resaving presets to regenerate it.", name))
				end
			end
			save_paths[false] = g_PresetLastSavePaths[self] -- main preset file
			g_PresetAllSavePaths[self] = save_paths
		end
	end
end

---
--- Loads a preset from a table or array of data.
---
--- This function is used to load a preset from a table or array of data. It creates a new instance of the preset object, registers it, and stores the paths that the preset was loaded from.
---
--- If `self.StoreAsTable` is true, the function creates a new instance of the preset object using the `data` table. If `g_PresetRefreshingFunctionValues` is true, the function refreshes the function values of the object and returns without registering it. Otherwise, the function registers the object.
---
--- If `self.StoreAsTable` is false, the function creates a new instance of the preset object using the `arr` array. If `g_PresetRefreshingFunctionValues` is true, the function sets the ID and group of the object, refreshes the function values, and returns without registering it. Otherwise, the function registers the object and sets the object properties using the `data` table.
---
--- Finally, the function calls the `StoreLoadedFromPaths()` method of the preset object to store the paths that the preset was loaded from.
---
--- @param data table The table of data to load the preset from.
--- @param arr table The array of data to load the preset from.
--- @return table The loaded preset object.
---
function Preset:__fromluacode(data, arr)
	local obj
	if self.StoreAsTable then
		obj = self:new(data)
		if g_PresetRefreshingFunctionValues then -- reloading after save to refresh function values with correct debug info
			obj:RefreshFunctionValues()
			return
		else
			obj:Register()
		end
	else
		obj = self:new(arr)
		if g_PresetRefreshingFunctionValues then -- reloading after save to refresh function values with correct debug info
			-- SetId, SetGroup do not register the preset if g_PresetRefreshingFunctionValues is set
			SetObjPropertyList(obj, data)
			obj:RefreshFunctionValues()
			return
		else
			obj:Register()
			SetObjPropertyList(obj, data)
		end
	end
	obj:StoreLoadedFromPaths()
	return obj
end

---
--- Serializes the preset object to Lua code.
---
--- This function is used to serialize the preset object to Lua code. It first checks if serialization is forbidden, and if so, it asserts with an error message. Otherwise, it calls the `__toluacode()` method of the `InitDone` class to perform the serialization.
---
--- @param ... any Additional arguments to pass to the `__toluacode()` method.
--- @return any The serialized Lua code.
---
function Preset:__toluacode(...)
	assert(not g_PresetForbidSerialize, "Attempt to save preset not from Ged - are you storing presets instead of their ids in a savegame?\nPreset class: " .. self.class .. "\nPreset id: " .. self.id)
	return InitDone.__toluacode(self, ...)
end

-- doesn't register the preset, so we don't wipe the existing preset with the same id (if still present)
---
--- Creates a new instance of the preset object using the provided data.
---
--- If `self.StoreAsTable` is true, the function creates a new instance of the preset object using the `table` parameter. If `self.StoreAsTable` is false, the function creates a new instance of the preset object using the `arr` parameter, sets the `id` and `group` properties, and then sets the object properties using the `table` parameter.
---
--- @param table table The table of data to load the preset from.
--- @param arr table The array of data to load the preset from.
--- @return table The loaded preset object.
---
function Preset:__paste(table, arr)
	local ret
	if self.StoreAsTable then
		ret = self:new(table)
	else
		ret = self:new(arr)
		ret.SetId = function(self, id) self.id = id end
		ret.SetGroup = function(self, group) self.group = group end
		SetObjPropertyList(ret, table)
		ret.SetId = nil
		ret.SetGroup = nil
	end
	return ret
end

---
--- Constructs the save folder path for the preset object.
---
--- This function determines the appropriate save folder path for the preset object based on the `save_in` parameter or the `save_in` property of the preset object. The function returns the constructed save folder path as a string.
---
--- @param save_in string (optional) The name of the DLC or other save location. If not provided, the `save_in` property of the preset object is used.
--- @return string The constructed save folder path.
---
function Preset:GetSaveFolder(save_in)
	save_in = save_in or self.save_in
	if save_in == "" then return "Data" end
	if save_in == "Common" then return "CommonLua/Data" end
	if save_in:starts_with("Libs/") then
		return string.format("CommonLua/%s/Data", save_in)
	end
	-- save_in is a DLC name
	return string.format("svnProject/Dlc/%s/Presets", save_in)
end

---
--- Normalizes a game path by removing redundant slashes and backslashes.
---
--- This function takes a file path as input and returns a normalized version of the path. It removes any redundant slashes or backslashes, and ensures that the path uses forward slashes consistently.
---
--- @param path string The file path to normalize.
--- @return string The normalized file path.
---
function NormalizeGamePath(path)
	if not path then return end
	return path:gsub("%s*[/\\]+[/\\%s]*", "/")
end
local NormalizeSavePath = NormalizeGamePath

---
--- Gets the normalized save path for the preset object.
---
--- This function constructs the save path for the preset object using the `GetSavePath` function, and then normalizes the resulting path by removing any redundant slashes or backslashes.
---
--- @return string|boolean The normalized save path, or `false` if the save path could not be constructed.
---
function Preset:GetNormalizedSavePath()
	local path = self:GetSavePath()
	if not path or path == "" then return false end
	return NormalizeSavePath(path)
end

---
--- Constructs the save path for the preset object.
---
--- This function determines the appropriate save path for the preset object based on the `save_in` parameter, the `group` parameter, and various properties of the preset object. The function returns the constructed save path as a string.
---
--- @param save_in string (optional) The name of the DLC or other save location. If not provided, the `save_in` property of the preset object is used.
--- @param group string (optional) The group of the preset object. If not provided, the `group` property of the preset object is used.
--- @return string|nil The constructed save path, or `nil` if the save path could not be constructed.
---
function Preset:GetSavePath(save_in, group)
	group = group or self.group
	local class = self.PresetClass or self.class
	local folder = self:GetSaveFolder(save_in)
	if not folder then return end
	if self.FilePerGroup then
		if type(self.FilePerGroup) == "string" then
			return string.format("%s/%s/%s-%s.lua", folder, self.FilePerGroup, class, group)
		else
			return string.format("%s/%s-%s.lua", folder, class, group)
		end
	elseif self.SingleFile then
		return string.format("%s/%s.lua", folder, class)
	elseif self.GlobalMap then
		return string.format("%s/%s/%s.lua", folder, class, self.id)
	else
		return string.format("%s/%s/%s-%s.lua", folder, class, group, self.id)
	end
end

-- constructs the companion file path (the default is "<preset>.generated.lua" in the Lua code folder) from self:GetSavePath()'s return value
---
--- Constructs the save path for the companion file of the preset object.
---
--- This function takes the save path of the preset object and modifies it to construct the save path for the companion file. The companion file is typically named "<preset>.generated.lua" and is saved in the same directory as the preset file, but with the "Data" directory replaced by the "Lua" directory. For DLC presets, the companion file is saved in the "Code" directory instead of the "Presets" directory.
---
--- @param path string The save path of the preset object.
--- @return string|nil The constructed save path for the companion file, or `nil` if the save path could not be constructed.
---
function Preset:GetCompanionFileSavePath(path)
	if not path then return end
	if path:starts_with("Data") then
		path = path:gsub("^Data", "Lua") -- save in the game folder
	elseif path:starts_with("CommonLua/Data") then
		path = path:gsub("^CommonLua/Data", "CommonLua/Classes") -- save in common lua
	elseif path:starts_with("CommonLua/Libs/") then -- lib
		path = path:gsub("/Data/", "/Classes/")
	else
		path = path:gsub("^(svnProject/Dlc/[^/]*)/Presets", "%1/Code") -- save in a DLC
	end
	return path:gsub(".lua$", ".generated.lua")
end

---
--- Returns a table with key-file_name pairs if multiple companion files should be generated for this preset.
---
--- The `GenerateCompanionFileCode` function will be called once for each file, with the `key` passed as a parameter.
---
--- @param save_path string The save path of the preset object.
--- @return table|nil A table with key-file_name pairs, or `nil` if no companion files should be generated.
---
function Preset:GetCompanionFilesList(save_path)
	-- return a table with <key, file_name> pairs if you want to generate multiple companion files for this preset
	-- GenerateCompanionFileCode will be called once for each file, with <key> passed as a parameter
	assert(self.id ~= "") -- called for the class instead of the object?
	if self.HasCompanionFile then
		return { [true] = self:GetCompanionFileSavePath(save_path) }
	end
end

local generated_preset_files_header = "-- ========== GENERATED BY <PresetClass> Editor<opt(u(EditorShortcut),' (',')')> DO NOT EDIT MANUALLY! ==========\n\n"

---
--- Generates the header for a companion file.
---
--- The header includes a warning message indicating that the file was generated and should not be edited manually.
---
--- @param key string|boolean The key associated with the companion file, if multiple companion files are generated.
--- @return pstr The generated header as a pstr object.
---
function Preset:GetCompanionFileHeader(key)
	local titleT = T(generated_preset_files_header, { PresetClass = self.class, EditorShortcut = self.EditorShortcut })
	local header = _InternalTranslate(titleT, nil, not "check_errors") or exported_files_header_warning
	
	-- returns the initial pstr to which the companion file code will be appended
	return pstr(header, 16384)
end

---
--- Generates the code for a companion file.
---
--- This function is called when the `GetCompanionFilesList` function returns a table with key-file_name pairs. The `key` parameter is used to identify which companion file is being generated.
---
--- @param code pstr The pstr object to which the companion file code should be appended.
--- @param key string|boolean The key associated with the companion file, if multiple companion files are generated.
---
function Preset:GenerateCompanionFileCode(code, key)
	-- override this to generate companion file code; 'key' is used when multiple companion files exist - see GetCompanionFilesList
end

---
--- Checks if the ID of the current preset already exists in the global namespace.
---
--- This function is used to ensure that the ID of the preset does not conflict with any existing global variables or classes.
---
--- @return string|nil An error message if the ID already exists, or `nil` if the ID is unique.
---
function Preset:GetError()
	return self:CheckIfIdExistsInGlobal()
end

---
--- Checks if the ID of the current preset already exists in the global namespace.
---
--- This function is used to ensure that the ID of the preset does not conflict with any existing global variables or classes.
---
--- @param preset Preset The preset object to check. If not provided, the current preset object is used.
--- @return string|nil An error message if the ID already exists, or `nil` if the ID is unique.
---
function Preset:CheckIfIdExistsInGlobal(preset)
	preset = preset or self
	if preset.GeneratesClass then
		-- Check if a class with this id as name has already been generated by another preset
		-- The __generated_by_class prop can be used to check the class of the preset that generated a certain class
		local name = rawget(_G, preset.id)
		local class = g_Classes[preset.id]
		if name and name == class then
			-- Generated class exists and preset is not DLC
			local generated_by = class.__generated_by_class
			if preset.save_in == "" and generated_by and generated_by ~= "EntityClass" and generated_by ~= preset.class then
				return string.format("Another preset (%s - %s) has already generated a class with this name!", preset.id, class.__generated_by_class)
			-- Non-generated class exists
			elseif not generated_by then
				return string.format("The class \"%s\" already exists!", preset.id)
			end
		-- Global name exists
		elseif name and name ~= class then
			return string.format("The id \"%s\" is a reserved global name!", preset.id)
		end
	end
end

---
--- Appends a property to the generated code that indicates the class that generated the current class.
---
--- @param code CodeWriter The code writer to append the property to.
--- @param preset Preset The preset object that generated the current class. If not provided, the current preset object is used.
---
function Preset:AppendGeneratedByProps(code, preset)
	preset = preset or self
	-- The __generated_by_class prop can be used to check the class of the preset that generated a certain class
	code:append(string.format("\t__generated_by_class = \"%s\",\n\n", preset.class))
end

---
--- Generates the code for the current preset.
---
--- This function is responsible for generating the code for the current preset. It uses the `ValueToLuaCode` function to convert the preset's properties into Lua code, and appends the generated code to the provided `code` object.
---
--- @param code CodeWriter The code writer to append the generated code to.
---
function Preset:GenerateCode(code)
	ValueToLuaCode(self, nil, code, {} --[[ make ValueToLuaCode process property injection ]])
	code:append("\n\n")
end

---
--- Returns the localization context base for the preset.
---
--- If the preset has a `GlobalMap`, the context base is `"{class} {id}"`.
--- Otherwise, the context base is `"{class} {group} {id}"`.
---
--- @return string The localization context base for the preset.
---
function Preset:LocalizationContextBase()
	if self.GlobalMap then
		return string.format("%s %s", self.class, self.id)
	else
		return string.format("%s %s %s", self.class, self.group, self.id)
	end
end

---
--- Returns the last saved path for the current preset.
---
--- If a last saved path is stored in the `g_PresetLastSavePaths` table for this preset, that path is returned. Otherwise, the normalized save path for the preset is returned.
---
--- @return string The last saved path for the current preset.
---
function Preset:GetLastSavePath()
	return g_PresetLastSavePaths[self] or self:GetNormalizedSavePath()
end

local function create_name_template_with_id(name_template, id)
	return name_template:gsub("%%s", id)
end

local function is_template_ui_image_property(prop)
	return prop.editor == "ui_image" and prop.placeholder ~= nil and prop.name_template ~= nil
end

local function get_template_ext_dest_path(ui_image, id)
	local _1, _2, ext = SplitPath(ui_image.placeholder) 
	local dest = create_name_template_with_id(ui_image.name_template, id)
	local path = "svnAssets/Source/" .. dest .. ext
	return ext, dest, path
end

---
--- Creates and sets the default UI image for the given object.
---
--- @param ui_image table The UI image configuration, containing the placeholder, name template, and ID.
--- @param id string The ID of the object.
--- @param object table The object to set the UI image for.
--- @param skipNonDefault boolean If true, the function will not create a new UI image if the object already has a non-default value for the UI image.
--- @return string The created property, or an empty string if no new property was created.
---
function CreateAndSetDefaultUIImage(ui_image, id, object, skipNonDefault)
	local createdProperty = ""
	
	local ext, dest, osPathDest = get_template_ext_dest_path(ui_image, object.id)
	local osPathOrig = ui_image.placeholder
	
	-- has non default id, so we don't want to create anything
	if skipNonDefault and object[ui_image.id] ~= nil and object[ui_image.id] ~= dest then 
		return createdProperty
	end
	
	if not io.exists(osPathDest) then
		local err = AsyncCopyFile(osPathOrig, osPathDest)
		if err then
			print("Failed copying placeholder portrait " .. osPathOrig .. " to " .. osPathDest)
			print(err)
			return err
		else 
			createdProperty = "Created " .. ui_image.id .. " for " .. object.id .. "!"
			local ok, msg = SVNAddFile(osPathDest)
			if not ok then
				print("Failed to add (" .. osPathDest .. ") to SVN!")
				print(msg)
			end
		end
	end
	object[ui_image.id] = dest
	return createdProperty
end

---
--- Creates a name for a new preset based on the editor name or the preset class.
---
--- @param self table The Preset object.
--- @return string The generated name for the new preset.
---
function Preset:CreateNameFromEditorName()
	local name
	if self.EditorName and self.EditorName ~= "" then
		name = "New" .. self.EditorName
	elseif self.id and self.id ~= "" then
		return self.id
	else
		return "New" .. self.class
	end
	
	name = string.split(name, " ")
	
	for idx, seq in ipairs(name) do
		local newSeq = string.gsub(seq, "%(.-%)", "")
		newSeq = string.gsub(newSeq, "%A", "")
		newSeq = string.gsub(newSeq, "^%l", string.upper)
		name[idx]  = newSeq
	end
	
	name = table.concat(name, "")

	return name
end

---
--- Handles the creation of a new preset in the editor.
---
--- @param parent table The parent object of the new preset.
--- @param ged table The GED (Game Editor) object associated with the new preset.
--- @param is_paste boolean Whether the new preset is being pasted from another location.
--- @param old_id string The ID of the old preset, if this is a paste operation.
---
function Preset:OnEditorNew(parent, ged, is_paste, old_id)
	if Platform.developer and is_paste then
		for id, prop_meta in pairs(self:GetProperties()) do
			-- when user changes the image, if the current image does not exist or matches the template, and it exists, we delete it
			if is_template_ui_image_property(prop_meta) then
				local isDefault = hasDefaultUIImage(prop_meta, self, old_id)
				if isDefault then
					self[prop_meta.id] = create_name_template_with_id(prop_meta.name_template, self.id)
				end
			end
		end
	end
	
	self.group = self:IsPropertyDefault("group") and parent[1] and parent[1].group or self.group
	self.id = self:GenerateUniquePresetId(self:IsPropertyDefault("id") and self:CreateNameFromEditorName() or self.id)
	self:Register(self.id, "update_parent_table_cache")
	self:PostLoad()
	self:MarkDirty()
	if not is_paste then self:SortPresets() end -- because GedOpTreePaste already calls it after pasting (one or more) items
end

---
--- Handles actions to be performed after a new preset is created in the editor.
---
--- @param parent table The parent object of the new preset.
--- @param ged table The GED (Game Editor) object associated with the new preset.
--- @param is_paste boolean Whether the new preset is being pasted from another location.
---
function Preset:OnAfterEditorNew(parent, ged, is_paste)
	local presets = Presets[self.PresetClass or self.class]
	ObjModified(presets)
end

RecursiveCallMethods.OnPreSave = "call"
---
--- Handles actions to be performed before a preset is saved.
---
--- @param by_user_request boolean Whether the save was initiated by the user.
--- @param ged table The GED (Game Editor) object associated with the preset.
---
function Preset:OnPreSave(by_user_request, ged)
	if not Platform.developer or not by_user_request then return end
	
	g_PendingPresetImageAdds = g_PendingPresetImageAdds or {}
	
	for id, prop_meta in pairs(self:GetProperties()) do
		if is_template_ui_image_property(prop_meta) then
			local property = CreateAndSetDefaultUIImage(prop_meta, self.id, self, false)
			if property and property ~= "" then
				table.insert(g_PendingPresetImageAdds, property)
			end
		end
	end

	if next(g_PendingPresetImageAdds) == nil then g_PendingPresetImageAdds = false end
end

RecursiveCallMethods.OnPostSave = "call"
---
--- Handles actions to be performed after a preset has been saved.
---
--- @param by_user_request boolean Whether the save was initiated by the user.
--- @param ged table The GED (Game Editor) object associated with the preset.
---
function Preset:OnPostSave(by_user_request, ged)
end

---
--- Gets a table of all file paths associated with this preset, including the main preset file path.
---
--- @param main_path string The main file path for the preset, or nil to use the preset's default save path.
--- @return table A table of file paths, where the keys are the file names and the values are the full file paths.
---
function Preset:GetAllFileSavePaths(main_path)
	main_path = main_path or self:GetSavePath()
	local paths = self:GetCompanionFilesList(main_path) or {}
	paths[false] = main_path
	return paths
end

-- Patch the debug info for the existing functional values to the source code being saved,
-- allowing Edit Code and breakpoints to work without reloading any presets after saving
---
--- Handles the serialization of a function, ensuring that the debug information is properly set for the saved code.
---
--- @param pstr string The serialized function string.
--- @param func function The function being serialized.
---
function OnMsg.OnFunctionSerialized(pstr, func)
	-- N.B: THIS CAUSES CORRUPTION, e.g. saved presets have bogus symbols instead of function 'end' clauses
	--[[if g_PresetCurrentLuaFileSavePath then
		local result, count = pstr:str():gsub("\n", "\n") -- find line number
		SetFuncDebugInfo(g_PresetCurrentLuaFileSavePath, count + 1, func)
	end]]
end

-- filters out DLC properties with SaveAsTable == true
---
--- Determines whether a property should be cleaned before saving it as part of a preset.
---
--- @param id string The ID of the property.
--- @param prop_meta table The metadata for the property.
--- @param value any The value of the property.
--- @return boolean Whether the property should be cleaned before saving.
---
function Preset:ShouldCleanPropForSave(id, prop_meta, value)
	local dlc = prop_meta.dlc
	return g_PresetCurrentLuaFileSavePath and dlc and dlc ~= self.save_in or
		PropertyObject.ShouldCleanPropForSave(self, id, prop_meta, value)
end

-- filters out DLC properties with SaveAsTable == false
---
--- Gets the property value for saving, filtering out DLC properties that should not be saved.
---
--- @param id string The ID of the property.
--- @param prop_meta table The metadata for the property.
--- @return any The property value to be saved.
---
function Preset:GetPropertyForSave(id, prop_meta)
	local dlc = prop_meta.dlc
	if not (g_PresetCurrentLuaFileSavePath and dlc and dlc ~= self.save_in) then
		return self:GetProperty(id)
	end
end

---
--- Generates the save data for a preset, including the code for the preset's companion files.
---
--- @param file_path string The file path of the main preset file.
--- @param preset_list table A list of presets to generate the save data for.
--- @param code_pstr string The initial code string to use as the base for the save data.
--- @return string The generated save data, including the code for the preset's companion files.
---
function Preset:GetSaveData(file_path, preset_list, code_pstr)
	local code = code_pstr or self:GetCompanionFileHeader()
	for _, preset in ipairs(preset_list) do
		preset:GenerateCode(code)
	end
	return code
end

---
--- Generates the save data for all files associated with a preset, including the code for the preset's companion files.
---
--- @param file_path string The file path of the main preset file.
--- @param preset_list table A list of presets to generate the save data for.
--- @return table The generated save data, including the code for the preset's companion files, keyed by file path.
---
function Preset:GetAllFilesSaveData(file_path, preset_list)
	for _, preset in ipairs(preset_list) do
		local save_paths = preset:GetCompanionFilesList(file_path)
		if save_paths then
			save_paths[false] = file_path
			g_PresetAllSavePaths[preset] = save_paths
		else
			g_PresetLastSavePaths[preset] = file_path
		end	
	end
	
	-- prepare a file_path / code structure for all files
	local file_data = preset_list[1]:GetAllFileSavePaths(file_path)
	for key, path in pairs(file_data) do
		file_data[key] = { file_path = path, code = self:GetCompanionFileHeader(key) }
	end
	
	-- generate main file data
	g_PresetCurrentLuaFileSavePath = "@"..file_path
	file_data[false].code = self:GetSaveData(file_path, preset_list, file_data[false].code)
	g_PresetCurrentLuaFileSavePath = false
	
	-- generate code for companion files
	for _, preset in ipairs(preset_list) do
		for key, data in pairs(file_data) do
			if key then -- skip main file, it's already generated above
				preset:GenerateCompanionFileCode(data.code, key)
			end
		end
	end
	return file_data
end

---
--- Handles renaming of preset files during the save process.
---
--- This function is called when a preset is being saved, and checks if the current save path is different from the last saved path for that preset. If so, it moves the files associated with the preset to the new save path.
---
--- @param save_path string The current save path for the preset.
--- @param path_to_preset_list table A table mapping save paths to lists of presets.
---
function Preset:HandleRenameDuringSave(save_path, path_to_preset_list)
	local preset_list = path_to_preset_list[save_path]
	if #preset_list ~= 1 or self.SingleFile or self.FilePerGroup then
		return
	end
	
	local preset = preset_list[1]
	local last_save_path = g_PresetLastSavePaths[preset]
	if not last_save_path or last_save_path == save_path then
		return
	end
	
	local last_save_presets = path_to_preset_list[last_save_path]
	assert(last_save_presets) -- file_map should have been generated by SaveAll
	if not last_save_presets then
		return
	end
	
	local old_paths = g_PresetAllSavePaths[preset] or { [false] = g_PresetLastSavePaths[preset] }
	local new_paths = preset:GetAllFileSavePaths(save_path)
	for key, path in pairs(old_paths) do
		local ok, msg = SVNMoveFile(path, new_paths[key])
		if not ok then
			printf("Failed to move file %s to %s. %s", path, new_paths[key], tostring(msg))
		end
	end
end

---
--- Preloads the source code of Lua functions saved in a PropertyObject.
---
--- This function recursively traverses the properties of the given object, and for any properties that are Lua functions, it fetches the source code of those functions. This is done to ensure the function source code is available during the save process, as it may not be possible to fetch it at that time.
---
--- @param obj PropertyObject The object to preload function source codes for.
--- @return string The result of the preload operation. Can be "preloaded" if any source codes were preloaded, or "error" if any errors occurred.
---
function PreloadFunctionsSourceCodes(obj)
	local result
	if IsKindOf(obj, "PropertyObject") then
		for _, prop in ipairs(obj:GetProperties()) do
			if prop.editor == "func" or prop.editor == "expression" then
				local func = obj:GetProperty(prop.id)
				if func and not obj:IsDefaultPropertyValue(prop.id, prop, func) then
					local name, params, body = GetFuncSource(func)
					if not body then return "error" end
					result = "preloaded"
				end
			elseif prop.editor == "nested_obj" or prop.editor == "script" then
				local child = obj:GetProperty(prop.id)
				if child then
					local res = PreloadFunctionsSourceCodes(child)
					if res == "error" then return "error" end
					result = res or result
				end
			elseif prop.editor == "nested_list" then
				for _, child in ipairs(obj:GetProperty(prop.id)) do
					local res = PreloadFunctionsSourceCodes(child)
					if res == "error" then return "error" end
					result = res or result
				end
			end
		end
		
		for _, child in ipairs(obj) do
			local res = PreloadFunctionsSourceCodes(child)
			if res == "error" then return "error" end
			result = res or result
		end
	end
	return result
end

---
--- Saves the preset files to disk.
---
--- This function is responsible for saving all the preset files to disk. It collects all the dirty presets, preloads the source code of any Lua functions in the presets, and then saves the presets to their respective files. It also handles any file renames that may have occurred during the save process.
---
--- @param file_map table A table mapping file paths to lists of presets to save in those files.
--- @param by_user_request boolean Whether the save was initiated by the user.
--- @param ged table The game editor instance.
--- @return table A table mapping saved presets to their save paths.
---
function Preset:SaveFiles(file_map, by_user_request, ged)
	SuspendFileSystemChanged("SaveFiles")
	table.clear(g_PresetDirtySavePaths)
	
	local path_to_preset_list = table.map(file_map, function(value) return { } end)
	local class = self.PresetClass or self.class
	ForEachPresetExtended(class, function(preset, group)
		local editor_data = preset:EditorData()
		local path = editor_data.save_path or preset:GetNormalizedSavePath()
		local preset_list = path_to_preset_list[path]
		if preset_list then
			-- Check if this preset id exists as a global name/class
			local class_exists_err = self:CheckIfIdExistsInGlobal(preset)
			if class_exists_err then
				print(class_exists_err)
				assert(false, class_exists_err)
			else
				table.insert(preset_list, preset)
			end
		end
	end)
	
	-- fetch the source of any Lua functions here, as we might not be able to do that mid-save
	local msg_displayed
	local lua_source_failed_files = {}
	for path, preset_list in pairs(path_to_preset_list) do
		for _, preset in ipairs(preset_list) do
			Msg("OnPreSavePreset", preset, by_user_request, ged)
			procall(preset.OnPreSave, preset, by_user_request, ged)
			
			local result = PreloadFunctionsSourceCodes(preset)
			if result == "error" then
				table.insert(lua_source_failed_files, path)
			elseif not msg_displayed and result == "preloaded" then
				print("Fetching source code of Lua functions saved in presets...")
				msg_displayed = true
			end
		end
	end
	
	if by_user_request and next(lua_source_failed_files) then
		local files = table.concat(lua_source_failed_files, "\n")
		ged:ShowMessage("Error Saving",
			string.format("Could not fetch a function's source code in file%s:\n\n%s", #files > 1 and "s" or "", files))
	end
	
	local to_delete = {}
	for path, preset_list in sorted_pairs(path_to_preset_list) do
		self:HandleRenameDuringSave(path, path_to_preset_list)
		ContextCache = {}
		
		if #preset_list > 0 then
			printf("Saving %s...", path)
			
			local file_data = self:GetAllFilesSaveData(path, preset_list) -- key => { file_path = "...", code = "..." }
			local errors
			for key, data in pairs(file_data) do
				local err = SaveSVNFile(data.file_path, data.code, self.LocalPreset)
				if err then
					errors = true
					printf("Failed to save %s... %s", data.file_path, err)
				end
			end
			
			if not errors then
				-- reload the file and apply the newly-loaded function values, so that they include the proper debug info
				if Platform.developer and by_user_request and not self:IsKindOfClasses("MapDataPreset", "ConstDef") then
					g_PresetRefreshingFunctionValues = true
					dofile(path)
					g_PresetRefreshingFunctionValues = false
					CacheLuaSourceFile(path, file_data[false].code) -- make sure we have a cached Lua source that matches the loaded Lua file
				end
				
				for _, preset in ipairs(preset_list) do
					preset:MarkClean()
				end
				
				local ferr, timestamp = AsyncGetFileAttribute(path, "timestamp")
				if ferr then
					print("Failed to get timestamp for", path)
				else
					g_PresetFileTimestampAtSave[path] = timestamp
				end
			end
		else
			local paths = self:GetAllFileSavePaths(path)
			for key, path in pairs(paths) do
				table.insert(to_delete, path)
			end
		end
	end
	
	local saved_presets = {}
	for path, preset_list in pairs(path_to_preset_list) do
		for _, preset in ipairs(preset_list) do
			Msg("OnPostSavePreset", preset, by_user_request, ged)
			procall(preset.OnPostSave, preset, by_user_request, ged)
			saved_presets[preset] = path
		end
	end
	
	local res, err = SVNDeleteFile(to_delete)
	ResumeFileSystemChanged("SaveFiles")
	return saved_presets
end

---
--- Saves the current preset to the specified file path.
---
--- @param by_user_request boolean Whether the save was initiated by the user.
--- @param ged table The game editor object.
---
function Preset:Save(by_user_request, ged)
	local dirty_paths = {}
	dirty_paths[self:GetNormalizedSavePath()] = true
	dirty_paths[self:GetLastSavePath()] = true
	self:SortPresets()
	self:SaveFiles(dirty_paths, by_user_request, ged)
	if by_user_request then
		self:OnDataSaved()
		self:OnDataUpdated()
		Msg("PresetSave", self.PresetClass or self.class, not "force_save_all", by_user_request, ged)
	end
end

---
--- Collects and runs the save process for all presets of the given class.
---
--- @param force_save_all boolean Whether to force saving all presets, even if they are not dirty.
--- @param by_user_request boolean Whether the save was initiated by the user.
--- @param ged table The game editor object.
--- @return table The saved presets.
---
function Preset:SaveAllCollectAndRun(force_save_all, by_user_request, ged)
	PauseInfiniteLoopDetection("Preset:SaveAllCollectAndRun")
	
	local dirty_paths = {}
	local class = self.PresetClass or self.class
	ForEachPresetExtended(class, function(preset, group)
		local path = preset:GetNormalizedSavePath()
		if path and (force_save_all or preset:IsDirty()) then
			preset:EditorData().save_path = path
			dirty_paths[path] = true
			dirty_paths[g_PresetLastSavePaths[preset] or path] = true
		end
	end)
	
	for path, preset_class in pairs(g_PresetDirtySavePaths) do
		if preset_class == class then
			dirty_paths[path] = true
		end
	end
	
	local saved_presets = self:SaveFiles(dirty_paths, by_user_request, ged)
	ResumeInfiniteLoopDetection("Preset:SaveAllCollectAndRun")
	return saved_presets
end

---
--- Saves all presets of the given class.
---
--- @param force_save_all boolean Whether to force saving all presets, even if they are not dirty.
--- @param by_user_request boolean Whether the save was initiated by the user.
--- @param ged table The game editor object.
--- @return table The saved presets.
---
function Preset:SaveAll(force_save_all, by_user_request, ged)
	local class = self.PresetClass or self.class
	ReloadingDisabled["saveall_" .. class] = "wait"
	
	local start_time = GetPreciseTicks()
	self:SortPresets()
	ForEachPresetExtended(self, CreateDLCPresetsForSaving) -- properties with dlc = ... are saved to the DLC folder by creating fake presets
	local saved_presets = self:SaveAllCollectAndRun(force_save_all, by_user_request, ged)
	CleanupDLCPresetsForSaving()
	self:OnDataSaved()
	self:OnDataUpdated()
	Msg("PresetSave", class, force_save_all, by_user_request, ged)
	printf("%s presets saved in %d ms", class, GetPreciseTicks() - start_time)
	
	ReloadingDisabled["saveall_" .. class] = false
	
	if by_user_request then
		if Platform.developer and g_PendingPresetImageAdds then
			table.insert(g_PendingPresetImageAdds, "\nDon't forget to commit the assets folder!")
			ged:ShowMessage("Placeholder images were created!", table.concat(g_PendingPresetImageAdds, "\n") )
			g_PendingPresetImageAdds = false
		end
	end
	
	return saved_presets
end

---
--- Handles the deletion of a preset from the editor.
---
--- If the preset is not a single file or file per group, it deletes all the files associated with the preset.
--- It also updates the last save path and dirty save paths for the preset.
--- If the preset has any UI image properties, it checks if the current image matches the template and deletes it from SVN if it does.
---
--- @param group table The group the preset belongs to.
--- @param ged table The game editor object.
---
function Preset:OnEditorDelete(group, ged)
	if not self.SingleFile and not self.FilePerGroup then
		local fn = self.LocalPreset and AsyncFileDelete or SVNDeleteFile
		for key, path in pairs(self:GetAllFileSavePaths()) do
			fn(path)
		end
		g_PresetLastSavePaths[self] = nil
		g_PresetAllSavePaths[self] = nil
	end
	local path = self:GetLastSavePath()
	if path then
		g_PresetDirtySavePaths[path] = self.PresetClass or self.class
	end
	
	if Platform.developer then
		for k,prop_meta in pairs(self:GetProperties()) do
			-- when user changes the image, if the current image matches the template, and it exists, we delete it
			if is_template_ui_image_property(prop_meta) then
				local ext, dest, osPathDest = get_template_ext_dest_path(prop_meta, self.id)
				if self[prop_meta.id] == dest or self[prop_meta.id] == nil and io.exists(osPathDest) then
					local ok, msg = SVNDeleteFile(osPathDest)
					if not ok then
						print("Failed to remove (" .. osPathDest .. ") from SVN!")
						print("SVN MSG: " .. msg)
					end
				end
			end
		end
	end
end

if FirstLoad or ReloadForDlc then
	Presets = rawget(_G, "Presets") or {}
	setmetatable(Presets, {
		__newindex = function(self, key, value)
			assert(key == (_G[key].PresetClass or key))
			rawset(self, key, value)
		end
	})
end

---
--- Builds the Presets table by iterating over all classes that inherit from the Preset class.
--- For each Preset class, it creates a new entry in the Presets table, and if the class has a GlobalMap
--- defined, it creates a new table in the global namespace with that name and associates it with the Preset class.
---
--- @param name string The name of the Preset class.
--- @param class table The Preset class.
--- @param Presets table The Presets table to be populated.
---
function OnMsg.ClassesBuilt()
	ClassDescendantsList("Preset", function(name, class, Presets)
		local preset_class = class.PresetClass or name
		Presets[preset_class] = Presets[preset_class] or {}
		
		local map = class.GlobalMap
		if map then
			assert(type(map) == "string")
			rawset(_G, map, rawget(_G, map) or {})
		end
	end, Presets)
end

---
--- Persists the permanents table with preset data.
---
--- This function is called when the game is saving or loading data. It iterates over all the preset classes
--- and adds their preset data to the permanents table. If the preset class has a GlobalMap defined, it adds
--- the presets from that global map. Otherwise, it adds the presets from the Presets table.
---
--- @param permanents table The permanents table to be populated with preset data.
--- @param direction string The direction of the data persistence, either "load" or "save".
---
function OnMsg.PersistGatherPermanents(permanents, direction)
	local format = string.format
	for preset_class_name, groups in pairs(Presets) do
		local preset_class = g_Classes[preset_class_name]
		if (direction == "load" or preset_class.PersistAsReference) and preset_class_name ~= "ListItem" then
			if preset_class.GlobalMap then
				for preset_name, preset in pairs(_G[preset_class.GlobalMap]) do
					permanents[format("Preset:%s.%s", preset_class_name, preset_name)] = preset
				end
			end
			if not preset_class.GlobalMap or direction == "load" then
				for group_name, group in pairs(groups or empty_table) do
					if type(group_name) == "string" then
						for preset_name, preset in pairs(group or empty_table) do
							if type(preset_name) == "string" then
								permanents[format("Preset:%s.%s.%s", preset_class_name, group_name, preset_name)] = preset
							end
						end
					end
				end
			end
		end
	end
	permanents["Preset:UnpersistedMissingPreset.MissingPreset"] = UnpersistedMissingPreset:new{id = "MissingPreset"}
end

Preset.persist_baseclass = "Preset"
---
--- Attempts to unpersist a missing preset class.
---
--- If the preset class is found in the `g_Classes` table, this function calls the `UnpersistMissingPreset` method on that class, passing the `id` and `permanents` arguments.
--- If the preset class is not found, this function returns the `Preset:UnpersistedMissingPreset.MissingPreset` preset from the `permanents` table.
---
--- @param id string The ID of the missing preset, in the format "Preset:class_name.preset_name".
--- @param permanents table The permanents table containing preset data.
--- @return table The unpersisted missing preset, or the `Preset:UnpersistedMissingPreset.MissingPreset` preset if the class is not found.
---
function Preset:UnpersistMissingClass(id, permanents)
	assert(id:starts_with("Preset:"))
	local dot = id:find(".", 9, true)
	local preset_class = g_Classes[id:sub(8, dot and dot - 1)]
	return preset_class and preset_class:UnpersistMissingPreset(id, permanents) or permanents["Preset:UnpersistedMissingPreset.MissingPreset"]
end

---
--- Attempts to unpersist a missing preset class.
---
--- If the preset class has a `GlobalMap` defined and an `UnpersistedPreset` property, this function attempts to retrieve the preset from the global map. If the preset is found, it is returned.
--- If the preset class does not have a `GlobalMap` or `UnpersistedPreset` property, or the preset is not found in the global map, this function iterates through the `Presets` table for the preset class and returns the first preset it finds.
---
--- @param id string The ID of the missing preset, in the format "Preset:class_name.preset_name".
--- @param permanents table The permanents table containing preset data.
--- @return table The unpersisted missing preset, or the `Preset:UnpersistedMissingPreset.MissingPreset` preset if the class is not found.
---
function Preset:UnpersistMissingPreset(id, permanents)
	if self.GlobalMap and self.UnpersistedPreset then
		local preset = table.get(_G, self.GlobalMap, self.UnpersistedPreset)
		if preset then
			return preset
		end
	end
	local preset_class_name = self.PresetClass or self.class
	for group, presets in sorted_pairs(Presets[preset_class_name]) do
		local preset = presets[1]
		if preset then
			return preset
		end
	end
end

-- Fallback Preset class for when a preset can't be found due to change of group or deletion
---
--- Defines a class for an unpersisted missing preset.
---
--- This class is used as a fallback when a preset cannot be found due to changes in the group or deletion of the preset.
---
--- @class DefineClass.UnpersistedMissingPreset
--- @field GedEditor boolean Indicates whether the preset has a GED editor.
--- @field __parents table The parent classes of this class.
---
DefineClass.UnpersistedMissingPreset = {
	__parents = { "Preset" },
	GedEditor = false,
}

function Preset:OnDataSaved()
end

function Preset:OnDataReloaded()
end

function Preset:OnDataUpdated() -- called after initial load, save and reload
end

function OnMsg.DataLoaded()
	local g_Classes = g_Classes
	for class_name in pairs(Presets) do
		local class = g_Classes[class_name]
		if class then
			class:OnDataUpdated()
		end
	end
end

---
--- Returns the path to a preset within the Presets table.
---
--- @param target table The preset object to get the path for.
--- @return table The path to the preset, containing the group index and preset index.
---
function PresetGetPath(target)
	if not target then return end
	local groups = Presets[target.PresetClass or target.class]
	local group = groups[target.group]
	assert(group)
	local group_index = table.find(groups, group)
	local preset_index = table.find(group, target)
	return { group_index, preset_index }
end

-- returns true if the current ui_image matches the ui_image template name (with the supplied id)
---
--- Checks if the current UI image matches the default UI image template with the given ID.
---
--- @param ui_image table The UI image property metadata.
--- @param obj table The object containing the UI image property.
--- @param oldId string The old ID of the object.
--- @return boolean True if the current UI image matches the default template, false otherwise.
---
function hasDefaultUIImage(ui_image, obj, oldId)
	local currentImage = obj[ui_image.id]
	local defaultImage = create_name_template_with_id(ui_image.name_template, oldId)
	
	return currentImage == defaultImage
end

---
--- Called when a property of the preset is edited in the editor.
---
--- This function handles various actions when a property of the preset is changed, such as:
--- - If the "Id" property is changed, it renames the corresponding UI image file in the file system and SVN.
--- - If a UI image property is changed and the current image matches the default template, it deletes the image file.
--- - If the "Id", "SortKey", or "Group" property is changed, it calls `Preset:SortPresets()` to resort the presets.
---
--- @param prop_id string The ID of the property that was changed.
--- @param old_value any The old value of the property.
--- @param ged table The GED (Game Editor Data) object associated with the preset.
---
function Preset:OnEditorSetProperty(prop_id, old_value, ged)
	local oldId = prop_id == "Id" and old_value or self.id
	local newId = self.id
	
	-- when user changes the image, if the current image matches the template, we delete it
	local prop_meta = self:GetPropertyMetadata(prop_id)
	if prop_id == prop_meta.id and is_template_ui_image_property(prop_meta) then
		local ext, dest, osPathDest = get_template_ext_dest_path(prop_meta, self.id)
		local patternFileExists = io.exists(osPathDest)
		if self[prop_id] and (old_value == dest or old_value == nil and patternFileExists) then
			local err = AsyncDeletePath(osPathDest)
			if err then
				print(err)
			else
				local ok, msg = SVNDeleteFile(osPathDest)
				if not ok then
					print("Failed to remove file from SVN!")
				end
			end
		end
	elseif prop_id == "Id" then
		for id, prop_meta in pairs(self:GetProperties()) do
			-- when the user changes the id, if the current image matches the template (with old id), and it exists, we rename it
			 if is_template_ui_image_property(prop_meta) then
				
				local ext, prevLocalDest, prevPath = get_template_ext_dest_path(prop_meta, oldId)
				local _, nextLocalDest, nextPath = get_template_ext_dest_path(prop_meta, self.id)
				
				local currentImage = self[prop_meta.id]
				
				if hasDefaultUIImage(prop_meta, self, oldId) then
					self[prop_meta.id] = nextLocalDest
					local ok, msg = SVNMoveFile(prevPath, nextPath)
					if not ok then
						printf("Failed to move file %s to %s. %s", prevPath, nextPath, tostring(msg))
					end
				end
			end
		end
	end
	
	if prop_id == "Id" or prop_id == "SortKey" or prop_id == "Group" then
		self:SortPresets()
	end
end

--- Compares two presets based on their sort key, ID, and save order.
---
--- @param self Preset The first preset to compare.
--- @param other Preset The second preset to compare.
--- @return boolean True if the first preset should come before the second preset, false otherwise.
function Preset:Compare(other)
	if self.HasSortKey then
		local k1, k2 = self.SortKey, other.SortKey
		if k1 ~= k2 then
			return k1 < k2
		end
	end
	local k1, k2 = self.id, other.id
	if k1 ~= k2 then
		return k1 < k2
	end
	return self.save_in < other.save_in
end

---
--- Sorts the presets in the specified preset class.
---
--- This function first sorts the presets within each group by their sort key, and then sorts the groups by the sort key of the first preset in each group. If a preset does not have a sort key, the groups are sorted by the group name instead.
---
--- @param self Preset The preset instance.
function Preset:SortPresets()
	local presets = Presets[self.PresetClass or self.class] or empty_table
	if self.HasSortKey then
		table.sort(presets, function(a, b)
			local k1, k2 = a[1] and a[1].SortKey or 0, b[1] and b[1].SortKey or 0
			if k1 ~= k2 then
				return k1 < k2
			end
			return a[1].group < b[1].group
		end)
	else
		table.sort(presets, function(a, b) return a[1].group < b[1].group end)
	end
	for _, group in ipairs(presets) do
		table.sort(group, self.Compare)
	end
	ObjModified(presets)
end

---
--- Creates a print function that outputs to the DebugPrint function.
---
--- @param prefix string The prefix to use for the print function.
--- @param format string The format string to use for the print function.
--- @param output function The output function to use for the print function.
---
--- @return function The created print function.
preset_print = CreatePrint{
	"preset",
	format = "printf",
	output = DebugPrint,
}

---
--- Validates the integrity of preset data.
---
--- This function checks for missing DLCs, validates preset properties, and reports any errors or warnings.
---
--- @param validate_all boolean If true, validates all presets regardless of whether they have a ValidateAfterSave flag. If false, only validates presets with the ValidateAfterSave flag.
--- @param game_tests boolean If true, reports errors and warnings through the GameTests system. If false, stores the errors and warnings in the preset objects.
--- @param verbose boolean If true, provides more detailed error and warning messages.
---
--- @return table A table of preset validation errors, where each entry is a table with the preset, the warning message, and the warning type ("error" or "warning").
function ValidatePresetDataIntegrity(validate_all, game_tests, verbose)
	if validate_all then
		local dlc = DbgAreDlcsMissing()
		if dlc then
			if GameTestsRunning then
				GameTestsPrint("Presets are validated with DLCs missing:", dlc)
			else
				CreateMessageBox(nil, Untranslated("Warning"), Untranslated{"<red>Presets were validated with DLCs missing (<dlc>).\n\nInvalid errors about missing references may occur.", dlc = Untranslated(dlc)})
			end
		end
	end
	
	Msg("ValidatingPresets")
	SuspendThreadDebugHook("PresetIntegrity")
	NetPauseUpdateHash("PresetIntegrity")
	
	for class, presets in pairs(Presets) do
		if class ~= "ListItem" then
			PopulateParentTableCache(presets)
		end
	end
	
	local validation_start = GetPreciseTicks()
	local property_errors = {}
	for class, presets in pairs(Presets) do
		local preset_class = _G[class]
		if preset_class.ValidateAfterSave or validate_all then
			for _, group in ipairs(presets) do
				for _, preset in ipairs(group) do
					local warning = GetDiagnosticMessage(preset, verbose, verbose and "\t")
					if warning then
						table.insert(property_errors, { preset, warning[1], warning[2]})
					end
				end
			end
		end
	end
	
	preset_print("Preset validation took %i ms.", GetPreciseTicks() - validation_start)
	
	NetResumeUpdateHash("PresetIntegrity")
	ResumeThreadDebugHook("PresetIntegrity")
	Msg("ValidatingPresetsDone")
	
	if #property_errors > 0 then
		local indent = verbose and "\n\t" or " "
		for _, err in ipairs(property_errors) do
			local preset = err[1]
			local warn_msg = err[2]
			assert(type(warn_msg) == "string")
			local warn_type = err[3]
			local address = string.format("%s.%s.%s", preset.PresetClass or preset.class, preset.group, preset:GetIdentification())
			
			if game_tests then
				if warn_type == "error" then
					local assert_msg = string.format("[ERROR] %s:%s%s.\n\tUse Debug->ValidatePresetDataIntegrity from the game menu for more info.", address, indent, warn_msg)
					GameTestsErrorf(assert_msg)
				else
					local err_msg = string.format("[WARNING] %s:%s%s", address, indent, warn_msg)
					GameTestsPrintf(err_msg)
				end
			else
				local err_msg = string.format("<color %s>[!]</color> %s:%s%s", warn_type == "warning" and RGB(255, 140, 0) or RGB(240, 0, 0), address, indent, warn_msg)
				StoreErrorSource(preset, err_msg)
			end
		end
	end
	return property_errors
end

---
--- Saves presets and optionally validates preset data integrity.
---
--- @param class string The class of presets to save.
--- @param force_save_all string|nil If set to "resave_all", forces saving all presets regardless of validation.
--- @param by_user_request boolean|nil Whether the save was triggered by a user request.
--- @param ged table|nil The game event data.
---
function OnMsg.PresetSave(class, force_save_all, by_user_request, ged)
	local preset_class = g_Classes[class]
	if Platform.developer and force_save_all ~= "resave_all" and preset_class.ValidateAfterSave then
		ValidatePresetDataIntegrity(false, false)
	end
end

---
--- Handles post-processing of presets after they have been loaded.
--- This function is called in response to the `DataPostprocess` message.
---
--- It performs the following tasks:
--- - Sorts the presets for each preset class.
--- - Calls the `PostLoad` method on each preset to allow for any post-processing.
--- - Verifies that each preset has registered the file it was loaded from, to ensure proper saving.
---
--- @param start number The start time of the post-processing, in precise ticks.
---
function OnMsg.DataPostprocess()
	local start = GetPreciseTicks()
	
	for class, presets in pairs(Presets) do
		_G[class]:SortPresets()
		for _, group in ipairs(presets) do
			for _, preset in ipairs(group) do
				assert(not IsFSUnpacked() or g_PresetLastSavePaths[preset] ~= nil, "A preset didn't register the file it was loaded from; use LoadPresetXXX functions to load presets.\n\nThis problem could lead to saving issues when the preset's save location changes.")
				preset:PostLoad()
			end
		end
	end
	
	preset_print("Preset postprocess took %i ms.", GetPreciseTicks() - start)
end

---
--- Iterates over all presets of the specified class, including presets with duplicate IDs (due to DLC loading).
---
--- @param class string|table The class of presets to iterate over. Can be a string or a table with a `PresetClass` or `class` field.
--- @param func function The function to call for each preset. The function should take the following arguments:
---                    - `preset` (table): The preset object.
---                    - `group` (table): The group the preset belongs to.
---                    - `...` (any): Additional arguments passed to the function.
--- @param ... (any) Additional arguments to pass to the `func` function.
---
--- @return any The last return value of the `func` function, or the original `...` arguments if `func` did not return anything.
---
function ForEachPresetExtended(class, func, ...) -- includes all presets even when with duplicate IDs (due to DLC loading)
	class = g_Classes[class] or class -- get class table
	class = class.PresetClass or class.class
	for group_index, group in ipairs(Presets[class] or empty_table) do
		for preset_index, preset in ipairs(group) do
			if func(preset, group, ...) == "break" then
				return ...
			end
		end
	end
	return ...
end

---
--- Iterates over all presets of the specified class, excluding presets with duplicate IDs (due to DLC loading).
---
--- @param class string|table The class of presets to iterate over. Can be a string or a table with a `PresetClass` or `class` field.
--- @param func function The function to call for each preset. The function should take the following arguments:
---                    - `preset` (table): The preset object.
---                    - `group` (table): The group the preset belongs to.
---                    - `...` (any): Additional arguments passed to the function.
--- @param ... (any) Additional arguments to pass to the `func` function.
---
--- @return any The last return value of the `func` function, or the original `...` arguments if `func` did not return anything.
---
function ForEachPreset(class, func, ...) -- does not return presets with duplicate IDs (due to DLC loading)
	class = g_Classes[class] or class -- get class table
	class = class.PresetClass or class.class
	for group_index, group in ipairs(Presets[class]) do
		for preset_index, preset in ipairs(group) do
			local id = preset.id
			if (id == "" or group[id] == preset) and not preset.Obsolete then
				if func(preset, group, ...) == "break" then
					return ...
				end
			end
		end
	end
	return ...
end

---
--- Generates an array of presets for the specified class, optionally filtering them using the provided function.
---
--- @param class string|table The class of presets to generate the array for. Can be a string or a table with a `PresetClass` or `class` field.
--- @param func function (optional) The function to use to filter the presets. The function should take the following arguments:
---                    - `preset` (table): The preset object.
---                    - `group` (table): The group the preset belongs to.
---                    - `...` (any): Additional arguments passed to the function.
--- @param ... (any) Additional arguments to pass to the `func` function.
---
--- @return table An array of presets that match the provided filter function, or all presets if no filter function is provided.
---
function PresetArray(class, func, ...)
	return ForEachPreset(class, function(preset, group, presets, func, ...)
		if not func or func(preset, group, ...) then
			presets[#presets + 1] = preset
		end
	end, {}, func, ...)
end

---
--- Generates an array of presets for the specified class and input group, optionally filtering them using the provided function.
---
--- @param class string|table The class of presets to generate the array for. Can be a string or a table with a `PresetClass` or `class` field.
--- @param input_group string The group to generate the array for.
--- @param func function (optional) The function to use to filter the presets. The function should take the following arguments:
---                    - `preset` (table): The preset object.
---                    - `group` (table): The group the preset belongs to.
---                    - `...` (any): Additional arguments passed to the function.
--- @param ... (any) Additional arguments to pass to the `func` function.
---
--- @return table An array of presets that match the provided filter function, or all presets in the input group if no filter function is provided.
---
function PresetGroupArray(class, input_group, func, ...)
	return ForEachPresetInGroup(class, input_group, function(preset, group, presets, func, ...)
		if not func or func(preset, group, ...) then
			presets[#presets + 1] = preset
		end
	end, {}, func, ...)
end

---
--- Iterates over all presets in the specified group for the given class, and calls the provided function for each preset.
---
--- @param class string|table The class of presets to iterate over. Can be a string or a table with a `PresetClass` or `class` field.
--- @param group string The name of the group to iterate over.
--- @param func function The function to call for each preset. The function should take the following arguments:
---                    - `preset` (table): The preset object.
---                    - `group` (table): The group the preset belongs to.
---                    - `...` (any): Additional arguments passed to the function.
--- @param ... (any) Additional arguments to pass to the `func` function.
---
--- @return any The return value of the last call to the `func` function, or the last value in the `...` arguments.
---
function ForEachPresetInGroup(class, group, func, ...)
	if type(class) == "table" then
		class = class.PresetClass or class.class
	end
	group = (Presets[class] or empty_table)[group]
	for preset_index, preset in ipairs(group) do
		if group[preset.id] == preset and not preset.Obsolete then
			if func(preset, group, ...) == "break" then
				return ...
			end
		end
	end
	return ...
end

---
--- Iterates over all preset groups for the specified class and calls the provided function for each group.
---
--- @param class string|table The class of presets to iterate over. Can be a string or a table with a `PresetClass` or `class` field.
--- @param func function The function to call for each preset group. The function should take the following arguments:
---                    - `group` (string): The name of the preset group.
---                    - `...` (any): Additional arguments passed to the function.
--- @param ... (any) Additional arguments to pass to the `func` function.
---
--- @return any The return value of the last call to the `func` function, or the last value in the `...` arguments.
---
function ForEachPresetGroup(class, func, ...)
	if type(class) == "table" then
		class = class.PresetClass or class.class
	end
	for _, group in ipairs(Presets[class] or empty_table) do
		if group[1] and group[1].group ~= "" then
			func(group[1].group, ...)
		end
	end
	return ...
end

---
--- Returns a sorted list of all preset group names for the specified class.
---
--- @param class string The class of presets to get the group names for.
--- @return table A sorted table of preset group names.
---
function PresetGroupNames(class)
	local groups = {}
	for _, group in ipairs(Presets[class] or empty_table) do
		if group[1] and group[1].group ~= "" then
			groups[#groups + 1] = group[1].group
		end
	end
	table.sort(groups)
	return groups
end

---
--- Returns a function that generates a list of preset group names for the specified class, optionally including additional entries.
---
--- @param class string The class of presets to get the group names for.
--- @param additional string|table Optional additional group names to include in the list.
--- @return function A function that returns a table of preset group names.
---
function PresetGroupsCombo(class, additional)
	return function()
		local groups = PresetGroupNames(class)
		if type(additional) == "table" then
			for i, entry in ipairs(additional) do
				table.insert(groups, i, entry)
			end
		else
			table.insert(groups, 1, "")
			if additional then
				table.insert(groups, 2, additional)
			end
		end
		return groups
	end
end

---
--- Generates a combo box list of preset IDs for the specified class and group.
---
--- @param class string The class of presets to get the IDs for.
--- @param group string The group of presets to get the IDs for.
--- @param additional string|table Optional additional IDs to include in the list.
--- @param filter function Optional filter function to apply to each preset.
--- @param format string Optional format string to apply to each preset ID.
--- @return function A function that returns a table of preset IDs.
---
function PresetsCombo(class, group, additional, filter, format)
	return function(obj, prop_meta)
		local ids = {}
		local encountered = {}
		if class and class ~= "" then
			local classdef = g_Classes[class]
			if not group and classdef and classdef.GlobalMap then -- list all presets
				ForEachPreset(class, function(preset, preset_group, ids)
					local id = preset.id
					if id ~= "" and (not filter or filter(preset, obj, prop_meta)) and not encountered[id] then
						ids[#ids + 1] = id
						encountered[id] = preset
					end
				end, ids)
			else
				local class = classdef and classdef.PresetClass or class
				group = group or IsPresetWithConstantGroup(classdef) and classdef.group or false
				assert(group, "PresetsCombo requres a group when presets are not with unique ids (GlobalMap = true) or with a constant group")
				for _, preset in ipairs((Presets[class] or empty_table)[group]) do
					local id = preset.id
					if id ~= "" and not encountered[id] and (not filter or filter(preset, obj, prop_meta)) then
						ids[#ids + 1] = id
						encountered[id] = preset
					end
				end
			end
		end
		table.sort(ids)
		if type(additional) == "table" then
			for i = #additional, 1, -1 do
				table.insert(ids, 1, additional[i])
			end
		elseif additional ~= nil then
			table.insert(ids, 1, additional)
		end
		if format then
			for i, id in ipairs(ids) do
				local preset = encountered[id]
				if preset then
					ids[i] = { value = id, text = _InternalTranslate(format, preset) }
				else
					ids[i] = { value = id, }
				end
			end
		end
		return ids
	end
end

---
--- Generates a combo box with preset IDs for a specific class and group.
---
--- @param class string The class name for the presets.
--- @param group string The group name for the presets.
--- @param filter? function(preset, group) A function to filter the presets.
--- @param first_entry? string|"no_empty" The first entry in the combo box, or "no_empty" to not include an empty entry.
--- @param format? function(preset) A function to format the preset ID.
--- @return function() A function that returns a table of preset IDs.
function PresetGroupCombo(class, group, filter, first_entry, format)
	return function()
		local ids = first_entry ~= "no_empty" and {first_entry or ""} or {}
		local encountered = {}
		local classdef = g_Classes[class]
		local preset_class = classdef and classdef.PresetClass or class
		assert(preset_class)
		for _, preset in ipairs((Presets[preset_class] or empty_table)[group]) do
			if preset.id ~= "" and not encountered[preset.id] and (not filter or filter(preset, group)) then
				ids[#ids + 1] = format and _InternalTranslate(format, preset) or preset.id
				encountered[preset.id] = true
			end
		end
		return ids
	end
end

---
--- Generates a combo box with preset IDs for multiple groups of a specific class.
---
--- @param class string The class name for the presets.
--- @param groups table A table of group names for the presets.
--- @param filter? function(preset, group) A function to filter the presets.
--- @param first_entry? string|"no_empty" The first entry in the combo box, or "no_empty" to not include an empty entry.
--- @param format? function(preset) A function to format the preset ID.
--- @return function() A function that returns a table of preset IDs.
function PresetMultipleGroupsCombo(class, groups, filter, first_entry, format)
	return function()
		local ids = first_entry ~= "no_empty" and {first_entry or ""} or {}
		local encountered = {}
		local classdef = g_Classes[class]
		local preset_class = classdef and classdef.PresetClass or class
		assert(preset_class)
		for _, group in ipairs(groups or empty_table) do
			for _, preset in ipairs((Presets[preset_class] or empty_table)[group] or empty_table) do
				if preset.id ~= "" and not encountered[preset.id] and (not filter or filter(preset, group)) then
					ids[#ids + 1] = format and _InternalTranslate(format, preset) or preset.id
					encountered[preset.id] = true
				end
			end
		end
		return ids
	end
end

--- Generates a combo box with preset properties for a specific class or instance.
---
--- @param class_or_instance string|table The class name or instance for the presets.
--- @param prop string|table The property name or property metadata table.
--- @param additional any An additional value to include in the combo box.
--- @param recursive boolean Whether to recursively traverse nested objects and lists.
--- @return function() A function that returns a table of preset property values.
function PresetsPropCombo(class_or_instance, prop, additional, recursive)
	if type(class_or_instance) == "table" then
		class_or_instance = class_or_instance.PresetClass or class_or_instance.class
	end
	if type(prop) == "table" then
		prop = prop.id
	end
	if type(class_or_instance) ~= "string" then
		return
	end
	
	local function traverse(obj, prop, values, encountered, recursive)
		if not obj then
			return
		end
		local value = obj:ResolveValue(prop)
		if value and not encountered[value] then -- skip 'false' on purpose
			values[#values + 1] = value
			encountered[value] = true
		end
		if recursive then
			for _, prop_meta in ipairs(obj:GetProperties()) do
				local editor = prop_meta.editor
				if editor == "nested_obj" then
					traverse(obj:GetProperty(prop_meta.id), prop, values, encountered, recursive)
				elseif editor == "nested_list" then
					local value = obj:GetProperty(prop_meta.id)
					for _, subobj in ipairs(value or empty_table) do
						traverse(subobj, prop, values, encountered, recursive)
					end
				end
			end
			for _, subitem in ipairs(obj) do
				traverse(subitem, prop, values, encountered, recursive)
			end
		end
	end
	
	return function(obj)
		local encountered = {}
		local values = {}
		ForEachPreset(class_or_instance, function(preset, group, prop, values, encountered, recursive)
			traverse(preset, prop, values, encountered, recursive)
		end, prop, values, encountered, recursive)
		
		table.sort(values, function(a, b)
			return (IsT(a) and TDevModeGetEnglishText(a) or a) < (IsT(b) and TDevModeGetEnglishText(b) or b)
		end)
		if additional ~= nil and not table.find(values, additional) then
			table.insert(values, 1, additional)
		end
		return values
	end
end

---
--- Generates a unique preset ID based on the given name or the preset's own ID.
---
--- @param name string|nil The name to use for generating the unique ID. If not provided, the preset's own ID will be used.
--- @return string The generated unique preset ID.
---
function Preset:GenerateUniquePresetId(name)
end

---
--- Generates a list of unique tags from the presets of the given class or instance.
---
--- @param class_or_instance string|table The class or instance to get the tags from.
--- @param prop string The property to get the tags from.
--- @return function A function that, when called with an object, returns a list of unique tags.
---
function PresetsTagsCombo(class_or_instance, prop)
	if type(class_or_instance) == "table" then
		class_or_instance = class_or_instance.PresetClass or class_or_instance.class
	end
	if type(prop) == "table" then
		prop = prop.id
	end
	if type(class_or_instance) ~= "string" or type(prop) ~= "string" then
		return
	end
	return function(obj)
		local items = {}
		ForEachPreset(class_or_instance, function(preset, group, prop, items)
			local tags = preset:ResolveValue(prop)
			if next(tags) == 1 then
				for _, tag in ipairs(tags) do
					items[tag] = true
				end
			else
				for tag in pairs(tags) do
					items[tag] = true
				end
			end
		end, prop, items)
		return table.keys(items, true)
	end
end

---
--- Generates a unique preset ID based on the given name or the preset's own ID.
---
--- @param name string|nil The name to use for generating the unique ID. If not provided, the preset's own ID will be used.
--- @return string The generated unique preset ID.
---
function Preset:GenerateUniquePresetId(name)
	local id = name or self.id
	local group = self.group
	local class = self.PresetClass or self.class
	local global_map = _G[class].GlobalMap
	global_map = global_map and rawget(_G, global_map)
	group = Presets[class][group]
	if (not global_map or not global_map[id]) and (not group or not group[id]) then
		return id
	end
	
	local new_id
	local n = 0
	local id1, n1 = id:match("(.*)_(%d+)$")
	if id1 and n1 then
		id, n = id1, tonumber(n1)
	end
	repeat
		n = n + 1
		new_id = id .. "_" .. n
	until (not global_map or not global_map[new_id]) and (not group or not group[new_id])
	return new_id
end

---
--- Returns a table containing information about the editor context for the current preset.
---
--- @return table The editor context for the current preset.
---
function Preset:EditorContext()
	local PresetClass = self.PresetClass or self.class
	local classes = ClassDescendantsList(PresetClass, function(classname, class, PresetClass)
		return class.PresetClass == PresetClass and class.GedEditor == g_Classes[PresetClass].GedEditor and not rawget(class, "NoInstances")
	end, PresetClass)
	if not rawget(self, "NoInstances") then
		table.insert(classes, 1, PresetClass)
	end
	local mod_item_class = g_Classes["ModItem" .. PresetClass]
	
	local custom_actions = {}
	self:GatherEditorCustomActions(custom_actions)
	return {
		PresetClass = PresetClass,
		Classes = classes,
		ContainerClass = self.ContainerClass,
		ContainerTree = IsKindOf(g_Classes[self.ContainerClass], "Container")
			and g_Classes[self.ContainerClass].ContainerClass == self.ContainerClass or false,
		ContainerGraphItems = IsKindOf(self, "GraphContainer") and self:EditorItemsMenu(),
		ModItemClass = mod_item_class and mod_item_class.class,
		EditorShortcut = self.EditorShortcut,
		EditorCustomActions = custom_actions, -- avoid trying to serialize the metamethod
		FilterClass = self.FilterClass,
		SubItemFilterClass = self.SubItemFilterClass,
		AltFormat = self.AltFormat,
		WarningsUpdateRoot = "root",
		ShowUnusedPropertyWarnings = IsKindOf(g_Classes[PresetClass], "CompositeDef")
	}
end

---
--- Finds a preset in the specified preset class by its ID.
---
--- @param preset_class string The class of the preset to search for.
--- @param preset_id string The ID of the preset to find.
--- @param prop_id string (optional) The property name to use for the ID. Defaults to "id".
--- @return table|nil The found preset, or nil if not found.
---
function FindPreset(preset_class, preset_id, prop_id)
	prop_id = prop_id or "id"
	
	local presets = Presets[preset_class] or empty_table
	for _, group in ipairs(presets) do
		local preset = table.find_value(group, prop_id, preset_id)
		if preset then
			return preset
		end
	end
end

---
--- Finds a preset editor for the specified preset class.
---
--- @param preset_class string The class of the preset to search for.
--- @param activate boolean (optional) If true, the found preset editor will be activated.
--- @return table|nil The found preset editor, or nil if not found.
---
function FindPresetEditor(preset_class, activate)
	for _, conn in pairs(GedConnections) do
		if conn.context and conn.context.PresetClass == preset_class then
			if not activate then
				return conn
			end
			local activated = conn:Call("rfnApp", "Activate")
			if activated ~= "disconnected" then
				return conn
			end
		end
	end
end

---
--- Opens a preset editor for the specified preset class.
---
--- @param class_name string The name of the preset class to open the editor for.
--- @param context table (optional) The context to use for the preset editor.
--- @return table|nil The opened preset editor, or nil if it could not be opened.
---
function OpenPresetEditor(class_name, context)
	if not IsRealTimeThread() or not CanYield() then
		CreateRealTimeThread(OpenPresetEditor, class_name, context)
		return
	end
	
	local class = g_Classes[class_name]
	local editor_ctx = context or class:EditorContext() or empty_table
	if class.SingleGedEditorInstance then
		local ged = FindPresetEditor(editor_ctx.PresetClass, "activate")
		if ged then return ged end
	end
	
	local preset_class = g_Classes[class.PresetClass] or class
	local presets = Presets[preset_class.class]
	PopulateParentTableCache(presets)
	return OpenGedApp(class.GedEditor, presets, editor_ctx)
end

---
--- Opens a preset editor for the current preset.
---
--- If the current thread is not a real-time thread or cannot yield, this function will create a new real-time thread to execute the preset editor opening.
---
--- If a preset editor is successfully opened, the function will set the selection in the editor to the current preset's path.
---
--- @param self Preset The preset instance to open the editor for.
---
function Preset:OpenEditor()
	if not IsRealTimeThread() or not CanYield() then
		CreateRealTimeThread(Preset.OpenEditor, self)
		return
	end
	
	local ged = OpenPresetEditor(self.PresetClass or self.class)
	if ged and self.id ~= "" then
		ged:SetSelection("root", PresetGetPath(self))
	end
end

-- for ValidatePresetDataIntegrity
---
--- Returns the identification of the preset.
---
--- @return string The identification of the preset.
---
function Preset:GetIdentification()
	return self.id
end

-- persist the preset groups that are to be displayed collapsed in Ged
if Platform.developer and not Platform.ged then
	GedSaveCollapsedPresetGroupsThread = false
	
	---
 --- Saves the collapsed preset groups in the Ged tree panel.
 ---
 --- This function is called when the collapsed state of a preset group in the Ged tree panel changes.
 --- It collects the names of the collapsed preset groups and stores them in the "CollapsedPresetGroups" developer option.
 --- The next time the Ged tree panel is loaded, the collapsed state of the preset groups will be restored based on this saved data.
 ---
 function SaveCollapsedPresetGroups()
		local collapsed = {}
		for presets_name, groups in pairs(Presets) do
			for group_name, group in pairs(groups) do
				if type(group_name) == "string" and GedTreePanelCollapsedNodes[group] then
					table.insert(collapsed, { presets_name, group_name })
				end
			end
		end
		SetDeveloperOption("CollapsedPresetGroups", collapsed)
	end
	
	---
 --- Loads the collapsed preset groups from the "CollapsedPresetGroups" developer option and restores their collapsed state in the Ged tree panel.
 ---
 --- This function is called when the game is loaded to restore the previous collapsed state of preset groups in the Ged tree panel.
 ---
 --- It iterates through the list of collapsed preset groups stored in the "CollapsedPresetGroups" developer option and sets the corresponding groups in the Ged tree panel to be collapsed.
 ---
 --- @return nil
 function LoadCollapsedPresetGroups()
		local collapsed = GetDeveloperOption("CollapsedPresetGroups")
		if not collapsed then return end
		
		for _,item in ipairs(collapsed) do
			local preset_group = Presets[item[1]]
			local group = preset_group and preset_group[item[2]]
			if group then
				GedTreePanelCollapsedNodes[group] = true
			end
		end
	end
	
	function OnMsg.GedTreeNodeCollapsedChanged()
		if GedSaveCollapsedPresetGroupsThread ~= CurrentThread then
			DeleteThread(GedSaveCollapsedPresetGroupsThread)
		end
		GedSaveCollapsedPresetGroupsThread = CreateRealTimeThread(function() Sleep(250) SaveCollapsedPresetGroups() end)
	end
	
	function OnMsg.DataLoaded()
		LoadCollapsedPresetGroups()
	end
end


----- PropertyCategories

---
--- Defines a property category that can be used to organize properties in the editor.
---
--- The property category has the following properties:
---
--- - `SortKey`: A number that determines the order in which the category is displayed in the editor.
--- - `display_name`: The name of the category that is displayed in the editor.
--- - `SaveIn`: The location where the preset is saved.
---
--- The property category also has the following settings:
---
--- - `PresetIdRegex`: A regular expression that defines the allowed characters for the preset ID.
--- - `HasSortKey`: Indicates whether the category has a sort key.
--- - `SingleFile`: Indicates whether the category is stored in a single file.
--- - `GlobalMap`: The global map where the category is stored.
--- - `EditorViewPresetPostfix`: The text that is displayed after the category name in the editor view.
--- - `EditorMenubarName`: The name of the category in the editor menubar.
--- - `EditorMenubar`: The location of the category in the editor menubar.
--- - `EditorIcon`: The icon that is displayed for the category in the editor.
--- - `Documentation`: A description of the category and its purpose.
---
DefineClass.PropertyCategory = {
	__parents = { "Preset" },
	properties = {
		{ category = "Category", id = "SortKey", name = "Sort key", editor = "number", default = 0 },
		{ category = "Category", id = "display_name", name = "Display Name", editor = "text", translate = true, default = T(159662765679, "<u(id)>") },
		{ id = "SaveIn", editor = false},
	},
	
	PresetIdRegex = "^[%w _+-]*$",
	HasSortKey = true,
	SingleFile = true,
	GlobalMap = "PropertyCategories",
	EditorViewPresetPostfix = Untranslated("<color 128 128 128> = <SortKey>"),
	EditorMenubarName = "Property categories",
	EditorMenubar = "Editors.Engine",
	EditorIcon = "CommonAssets/UI/Icons/map sitemap structure.png",
	Documentation = "Allows you to create a custom property category sort order.\n\nBy default property categories have SortKey = 0, and are listed in the order they first appear as properties are defined."
}


--------------- Preset reloading ---------------

if FirstLoad then
	ReloadDataFiles = false
	ReloadPresetsThread = false
	ReloadPlannedTime = false
	ReloadingDisabled = {}
end

function OnMsg.ReloadLua()
	ReloadingDisabled["reloadlua"] = "wait"
end

function OnMsg.Autorun()
	ReloadingDisabled["reloadlua"] = false
end
--- Returns a list of paths for the preset save locations.
---
--- This function iterates over the preset save locations and returns a list of the corresponding save folders.
---
--- @return table A list of paths for the preset save locations.
function PresetSaveFolders()
	local paths = {}
	for a, save_in in ipairs(table.imap(Preset.GetPresetSaveLocations(), function(v) return v.value end) ) do
		table.insert(paths, Preset:GetSaveFolder(save_in))
	end
	return paths
end

function PresetSaveFolders()
	local paths = {}
	for a, save_in in ipairs(table.imap(Preset.GetPresetSaveLocations(), function(v) return v.value end) ) do
		table.insert(paths, Preset:GetSaveFolder(save_in))
	end
	return paths
end

---
--- Queues a request to reload all presets from files.
---
--- This function is used to trigger a reload of all presets from files. It checks if the reload is necessary and queues the reload to be executed in the next frame.
---
--- @param file string|nil The file that triggered the reload request, or nil if the reload is forced.
--- @param change string|nil The type of change that triggered the reload request, or nil if the reload is forced.
--- @param force_reload boolean Whether to force the reload, even if the file hasn't changed.
---
function QueueReloadAllPresets(file, change, force_reload)
	if Platform.ged or not force_reload and not Platform.developer then return end
	if file and not file:ends_with(".lua") then return end
	
	-- The resulting event was produced by us saving presets from the editor. No reason to reload.
	if not force_reload and g_PresetFileTimestampAtSave[file] then
		local err, timestamp = AsyncGetFileAttribute(file, "timestamp")
		if not err and g_PresetFileTimestampAtSave[file] == timestamp then
			return
		end
	end
	
	Msg("DataReload")
	preset_print("----- Reload request %s, %s", file, change)
	ReloadDataFiles = ReloadDataFiles or {}
	ReloadPlannedTime = now() + 500
	if file then
		ReloadDataFiles[file] = true
	end
	
	ReloadPresetsThread = ReloadPresetsThread or CreateRealTimeThread(function()
		while now() < ReloadPlannedTime or table.has_value(ReloadingDisabled, "wait") do
			Sleep(25)
		end
		
		PauseInfiniteLoopDetection("ReloadPresetsFromFiles")
		ReloadPresetsFromFiles()
		ResumeInfiniteLoopDetection("ReloadPresetsFromFiles")
		
		ReloadPresetsThread = false
		Msg("DataReloadDone")
		
		if ReloadDataFiles and table.has_value(ReloadDataFiles, true) then
			QueueReloadAllPresets() -- start the new reload
		end
	end)
end

---
--- Reloads all presets from files.
---
--- This function is used to trigger a reload of all presets from files. It checks if the reload is necessary and queues the reload to be executed in the next frame.
---
--- @param file string|nil The file that triggered the reload request, or nil if the reload is forced.
--- @param change string|nil The type of change that triggered the reload request
function ReloadPresetsFromFiles()
	if not Platform.developer and not Platform.cmdline then return end
	print("Reloading presets...")
	
	preset_print("Gathering preset types with (possibly) modified runtime data.")
	local changed_file_paths = ReloadDataFiles
	ReloadDataFiles = false
	local preset_classes_modified_in_ged = {}
	local presets_to_delete = {}
	
	-- do not reload files that do not compile
	local source_lua_files = {}
	local compiled_lua_files = {}
	for name in pairs(changed_file_paths) do
		if io.exists(name) then
			local err, content = AsyncFileToString(name)
			if not content then
				print(string.format("<color red>Unable to read Lua file '%s'</color>", name))
				changed_file_paths[name] = nil
			end
			local func, err = loadfile(name, nil, _ENV)
			if not func then
				print(string.format("<color red>Lua compilation error in '%s'</color>", name))
				changed_file_paths[name] = nil
			end
			if func and content then
				source_lua_files[name] = content
				compiled_lua_files[name] = func
			end
		end
	end
	
	for class_name, groups in pairs(Presets) do
		local class = _G[class_name]
		if class.EnableReloading then
			for _, group in ipairs(groups) do
				for _, preset in ipairs(group) do
					if changed_file_paths[preset:GetLastSavePath()] then
						presets_to_delete[preset] = true
						if preset:IsDirty() then
							preset_classes_modified_in_ged[class_name] = "conflict" -- presets from this class have modified runtime copies.
							presets_to_delete[preset] = "modified"
							preset_print("Conflict %s %s: old_hash %s, current_hash %s", class_name, preset.id, preset:EditorData().old_hash, preset:EditorData().current_hash)
						else
							preset_classes_modified_in_ged[class_name] = preset_classes_modified_in_ged[class_name] or "affected" -- No runtime changes, but will need to be reloaded
						end
					end
				end
			end
		end
	end
	
	local conflicted_classes = {}
	for class_name, value in pairs(preset_classes_modified_in_ged) do
		if value == "conflict" then
			table.insert(conflicted_classes, class_name)
		end
		preset_print("Preset file status %s %s", class_name, value)
	end
	
	if #conflicted_classes > 0 then
		if rawget(terminal, "BringToTop") then
			terminal.BringToTop()
		end
		local conflicted_preset_ids = table.map(table.keys(table.filter(presets_to_delete, function(k, v) return v == "modified" end)), function(preset) return preset.id end)
		
		-- The question is in the game and all opened Ged editors
		local title = ("Overwrite preset data?")
		local q = "Preset data loaded from a file is about to overwrite changes made in the editor.\n\n" ..
			"You will lose ALL changes you have made in the following editors: " .. table.concat(conflicted_classes) .. "\n" ..
			"Ged UNDO/REDO will be lost as well.\n\n" ..
			"Modified presets: " .. table.concat(conflicted_preset_ids, ", ") .. "\n\nContinue?"
		
		local result = GedAskEverywhere(title, q)
		if result ~= "ok" then
			print("Reload canceled.")
			Msg("DataReloadDone")
			return false
		end
	end
	
	-- DROP ALL presets from the affected files
	local dropped = 0
	for preset, _ in pairs(presets_to_delete) do
		preset:delete()
		dropped = dropped + 1
	end
	preset_print("Deleted %s presets.", dropped)
	
	-- Load the new presets
	local loaded_presets = {}
	local loaded_preset_count = 0
	local old_place_obj = PlaceObj
	rawset(_G, "PlaceObj", function(class, ...)
		local object_class = _G[class]
		local spawned_preset_class
		if not IsKindOf(object_class, "Preset") then
			return old_place_obj(class, ...)
		end
		spawned_preset_class = object_class.PresetClass or class
		if not _G[spawned_preset_class].EnableReloading then
			return "reloading_disabled"
		end
		preset_classes_modified_in_ged[spawned_preset_class] = preset_classes_modified_in_ged[spawned_preset_class] or "loaded"
		local object = old_place_obj(class, ...)
		loaded_presets[object] = true
		loaded_preset_count = loaded_preset_count + 1
		object:MarkDirty(not "notify") -- make the SaveAll call below re-save the preset
		return object
	end)
	SuspendObjModified("ReloadPresetsFromFiles")
	for name, func in pairs(compiled_lua_files) do
		PresetsLoadingFileName = name
		procall(func)
		CacheLuaSourceFile(name, source_lua_files[name]) -- make sure we have a cached Lua source that matches the loaded Lua file
	end
	PresetsLoadingFileName = false
	ResumeObjModified("ReloadPresetsFromFiles")
	rawset(_G, "PlaceObj", old_place_obj)
	
	preset_print("Loaded %s presets", loaded_preset_count)
	for preset in pairs(loaded_presets) do
		preset:PostLoad()
	end
	
	if not Platform.cmdline then
		preset_print("Updating Geds.")
		for class_name in pairs(preset_classes_modified_in_ged) do
			_G[class_name]:OnDataReloaded()
			_G[class_name]:OnDataUpdated()
			GedRebindRoot(Presets[class_name], Presets[class_name])
			PopulateParentTableCache(Presets[class_name])
		end
		
		preset_print("Resaving for reformatting and companion files.")
		for class_name in pairs(preset_classes_modified_in_ged) do
			_G[class_name]:SaveAll()
		end
	end
	
	preset_print("Data reload done.")
end

if Platform.developer then
	local exclude_presets = {
		-- Presets with frequent deltas
		"MapDataPreset", "ParticleSystemPreset", "PersistedRenderVars", "ThreePointLighting",
		-- HG presets
		"HGPreset", "HGAccount", "HGInventoryAsset",
		"HGMember", "HGMilestone", "HGProjectFeature", "HGTest",
		"Build_Settings",
	} 
	local preset_path_pattern = "([%w:/\\_-]+[/\\]([%w_-]+)[/\\]([%w_-]+).([%w.]+))"
	---
 --- Resaves all presets in the game, checking for any differences in the SVN repository.
 --- This function is used to test the integrity of the preset system and ensure that all presets can be properly resaved.
 ---
 --- @param game_tests boolean Whether this is being called from game tests
 --- @return nil
 
 function ResaveAllPresetsTest(game_tests)
		if not IsRealTimeThread() then
			CreateRealTimeThread(ResaveAllPresetsTest, game_tests)
			return
		end
		
		local errors = {}
		
		local ok, status = SVNStatus("svnProject/", "quiet") -- "quiet" ignores unversioned files
		if not ok then
			table.insert(errors, { nil, " Could not get status of svnProject/" })
			HandleResavePresetErrors(errors, game_tests)
			return
		end
		
		-- Resave all presets
		SuspendThreadDebugHook("ResaveAllPresetsTest")
		SuspendFileSystemChanged("ResaveAllPresetsTest")
		if game_tests then
			ChangeMap("")
		end
		
		-- Populate parent table cache
		for class, presets in sorted_pairs(Presets) do
			if class ~= "ListItem" then
				PopulateParentTableCache(presets)
			end
		end
		
		local count = 0
		for preset_name, _ in sorted_pairs(Presets) do
			if not table.find(exclude_presets, preset_name) then
				local preset = _G[preset_name]
				preset:SaveAll("resave_all")
				count = count + 1
			end
		end
		
		Sleep(250)
		ResumeFileSystemChanged("ResaveAllPresetsTest")
		ResumeThreadDebugHook("ResaveAllPresetsTest")
		
		local new_ok, new_status = SVNStatus("svnProject/", "quiet")
		if not new_ok then
			table.insert(errors, { nil, " Could not get status of svnProject/" })
			HandleResavePresetErrors(errors, game_tests)
			return
		end
		
		print("All presets resaved. Differences?", status ~= new_status and "Yes!!" or "No", "\nResaved preset classes: ", count)
		if status ~= new_status then
			local ok_diff, str = SVNDiff("svnProject/", "ignore_whitespaces", 20000)
			if not ok_diff then			
				table.insert(errors, { nil, " " .. str })
				
				if str == "Running process time out" then
					table.insert(errors, { nil, "The diff might be too long!" })
				end
				
				HandleResavePresetErrors(errors, game_tests)
				return
			end
			local only_whitespace_changes = str == ""
			local diff = {}
			
			-- Now that we know the diff is only whitespaces, get the details
			if only_whitespace_changes then
				ok_diff, str = SVNDiff("svnProject/")
			end
			
			local in_entity_data_diff = false
			for s in str:gmatch("[^\r\n]+") do
				local starts_with_index = string.sub(s, 1, 6) == "Index:"
				local ends_with_entity_data = string.sub(s, -25) == "_EntityData.generated.lua"
				
				if not in_entity_data_diff then
					-- _EntityData diff start
					in_entity_data_diff = starts_with_index and ends_with_entity_data
				else
					-- _EntityData diff end
					in_entity_data_diff = not (starts_with_index and not ends_with_entity_data)
				end
				
				-- Don't add _EntityData changes to the diff lines
				if not in_entity_data_diff then 
					diff[#diff+1] = s
				end
				if #diff == 30 then break end
			end
			
			-- Save which files are changed but don't count those with only whitespace changes or _EntityData
			-- Those are the files we want to log errors for
			local changed_files = {}
			for full_path, folder, file, ext in str:gmatch("Index:%s+" .. preset_path_pattern) do
				if file ~= "_EntityData" then
					table.insert(changed_files, { full_path = full_path, folder = folder, file = file, ext = ext })
				end
			end
			
			-- [NOTE] The diff is only in _EntityData.generated.lua files. This happens after committing a change in the ArtSpec editor 
			-- because this generates changes in both the Source and the Assets repositories. There's no need to do anything. 
			-- This diff will disappear in one of the next autobuilds.
			local only_entity_data_changes = #diff == 0
			
			-- Ignore changes if they're only in _EntityData files
			if not only_entity_data_changes and not only_whitespace_changes then
				table.insert(errors, { nil, " Resaving all presets created deltas! See changed files below. Use Tools->\"Resave All Presets\" from the game editor menu to test this.", "error" })
				
				-- Summary of changed files
				for full_path, folder, file, ext in new_status:gmatch("M%s+" .. preset_path_pattern) do
					-- Display _EntityData changes as warnings
					local entity_data_file = string.find(file, "_EntityData")
					-- Log errors only for files that have at least one non-whitespace change
					local whitespace_changes_file = not entity_data_file and table.find_value(changed_files, "file", file)
					if whitespace_changes_file and whitespace_changes_file.ext == ext then
						local err = string.format("Preset: %s   |   Preset type: %s   |   File: %s", string.find(file, "ClassDef") and "-" or file, folder, full_path)
						table.insert(errors, { nil, err, entity_data_file and "warning" or "error" })
					end
				end
				
				local err_msg = string.format("\nOld status:\n%s \nNew Status:\n%s \nDiff (up to 30 lines):\n%s", status, new_status, table.concat(diff, "\n"))
				table.insert(errors, { nil, err_msg, "warning" })
			end
		end
		
		--- Additional checks for integrity of the "preset -> generated file" pairs
		local preset_id_to_gen_file = {}
		for preset_name, presets in sorted_pairs(Presets) do
			local preset_class = _G[preset_name]
			
			if preset_class and preset_class.GeneratesClass then
				preset_id_to_gen_file[preset_name] = {}
				assert(preset_class:GetCompanionFileSavePath(preset_class:GetSavePath()))
				local gen_path = preset_class:GetCompanionFileSavePath(preset_class:GetSavePath())
				
				-- Check if generated file is missing for an existing preset entry
				ForEachPresetExtended(preset_name, function(preset, group)
					if preset:GetSavePath() then -- might be nil for mod items
						assert(preset:GetCompanionFileSavePath(preset:GetSavePath()))
						local preset_gen_path = preset:GetCompanionFileSavePath(preset:GetSavePath())
						-- Check if the generated file exists
						if io.exists(preset_gen_path) then
							if not preset_id_to_gen_file[preset_name][preset.save_in] then
								preset_id_to_gen_file[preset_name][preset.save_in] = {}
							end
							preset_id_to_gen_file[preset_name][preset.save_in][preset.id] = preset_gen_path
						else
							local err_msg = string.format("Generated lua file is missing for this preset: %s.%s.%s! Expected: %s", preset_name, preset.group, preset.id, preset_gen_path)
							table.insert(errors, { preset, err_msg })
						end
					end
				end)
				
				-- Check if a preset entry is missing for an existing generated file
				local preset_folder = string.match(gen_path, "(Lua/.+)/")
				if not preset_folder then
					goto continue
				end
				local files = io.listfiles(preset_folder, "*.generated.lua")
				local base_class = preset_class.ObjectBaseClass or preset_class.PresetClass or ""
				local extra_def_id = "__" .. base_class
				
				for _, f_path in ipairs(files) do
					if string.find(f_path, "ClassDef", 1, true) then
						goto skip_file
					end
					
					local id = string.match(f_path, "/.+/(.+)%.generated%.lua$") -- the file name is the preset id
					local dlc = string.match(f_path, "/Dlc/(.+)/Presets/") or "" -- get dlc name (if any)
					
					if id ~= extra_def_id and preset_id_to_gen_file[preset_name][dlc][id] ~= f_path then
						local err_msg = string.format("Preset entry is missing for this generated file: %s! Expected %s preset with id %s", f_path, preset_name, id )
						table.insert(errors, { nil, err_msg })
					end
					
					::skip_file::
				end	
			end
			
			::continue::
		end
		
		-- Process stored errors
		HandleResavePresetErrors(errors, game_tests)
	end
	
	function HandleResavePresetErrors(errors, game_tests)
		if #errors > 0 and not DbgAreDlcsMissing() then
			for idx, err in ipairs(errors) do
				local preset = err[1]
				local msg = err[2]
				assert(type(msg) == "string", "Error message should be a string")
				local err_type = err[3]
				
				if game_tests then
					if err_type == "warning" then
						GameTestsPrint(msg)
					else
						GameTestsError(msg)
					end
				else
					local err_msg = string.format("<color %s>[!]</color> %s", RGB(240, 0, 0), msg)
					if err_type == "warning" then
						StoreWarningSource(preset, err_msg)
					else
						StoreErrorSource(preset, err_msg)
					end
				end
			end
		end
	end
end

---
--- Filters a list of presets to only include those that are not forbidden.
---
--- @param presets table A list of presets to filter.
--- @return table A filtered list of presets that are not forbidden.
---
function GetAvailablePresets(presets)
	if not presets then
		return
	end
	local forbidden = {}
	Msg("GatherForbiddenPresets", presets, forbidden)
	if not next(forbidden) then
		return presets
	end
	local filtered = {}
	for _, preset in ipairs(presets) do
		if not forbidden[preset.id] then
			filtered[#filtered + 1] = preset
		end
	end
	return filtered
end

---
--- Displays a preset combo box with the available presets for the given class.
---
--- @param class string The class of presets to display.
--- @param default table The default preset to select in the combo box.
--- @param group string The group of presets to display, or nil to display all presets.
--- @return table A table of preset items, where each item is a table with `text` and `value` fields.
---
function DisplayPresetCombo(class, default, group)
	local function add_item(preset, group, items)
		if preset:filter() then
			items[#items + 1] = { text = preset:GetDisplayName(), value = preset.id }
		end
	end
	
	local items = {default}
	if group then
		ForEachPresetInGroup(class, group, add_item, items)
	else
		ForEachPreset(class, add_item, items)
	end
	return items
end

-- Bookmarks - preset or preset group unique path

---
--- Gets the unique path of a preset or preset group.
---
--- @param obj table The preset or preset group object.
--- @return table The unique path of the preset or preset group, as a table with two elements: the group name and the preset ID.
---
function GetPresetOrGroupUniquePath(obj)
	return IsKindOf(obj, "Preset") and
		{ obj:GetGroup(), obj:GetId() } or
		{ obj[1]:GetGroup() }
end

---
--- Gets a preset or preset group by its unique path.
---
--- @param class string The class of the preset or preset group.
--- @param path table The unique path of the preset or preset group, as a table with two elements: the group name and the preset ID.
--- @return table The preset or preset group object, or nil if not found.
---
function PresetOrGroupByUniquePath(class, path)
	local group, id = path[1], path[2]
	local class_table = g_Classes[class]
	local presets = Presets[class_table.PresetClass or class_table.class]
	local group = presets and presets[group]
	if not id then
		return group
	end
	return group and group[id]
end

---
--- Lists all presets of the given class that match the provided predicate function.
---
--- @param class string The class of the presets to list.
--- @param predicate function|nil An optional predicate function that takes a preset and returns a boolean indicating whether to include it in the list.
--- @param ... any Additional arguments to pass to the predicate function.
--- @return table A table of preset objects that match the predicate.
---
function ListPresets(class, predicate, ...)
	local list = {}
	ForEachPreset(class, function(preset, group, list, ...)
		local predicate_func = predicate and preset[predicate]
		if not preset.Obsolete and (not predicate_func or predicate_func(preset, ...)) then
			list[#list + 1] = preset
		end
	end, list, ...)
	return list
end

---
--- Lists the IDs of all presets of the given class that match the provided predicate function.
---
--- @param class string The class of the presets to list.
--- @param predicate function|nil An optional predicate function that takes a preset and returns a boolean indicating whether to include it in the list.
--- @param ... any Additional arguments to pass to the predicate function.
--- @return table A table of preset IDs that match the predicate.
---
function ListPresetIds(class, predicate, ...)
	local list = ListPresets(class, predicate, ...)
	for i, preset in ipairs(list) do
		list[i] = preset.id
	end
	return list
end
