-- return false to make an object disappear even from the All category, e.g. when placing the object causes a crash
---
--- Checks if an entity is available to be used in the editor.
---
--- @param entity table The entity to check.
--- @param class_name string The name of the entity's class.
--- @return boolean True if the entity is available to be used in the editor, false otherwise.
---
function available_in_editor(entity, class_name)
	local class = g_Classes[class_name]
	return class and not rawget(class, "editor_force_excluded") and
		(class.variable_entity or IsValidEntity(entity)) and
		not IsTerrainEntityId(entity)
end

local new_artset = "<color 32 205 32>New"
local updated_artset = "<color 180 180 0>Updated"
local excluded_artset = "<color 205 32 32>Excluded"
local mods_artset = "<color 205 185 32>Mods"
local all_artset = "<color 185 32 205>All"
local bookmarks_artset = "<image CommonAssets/UI/Editor/fav_star 450 220 165 18>"
local extra_artsets = Platform.developer and
	{ new_artset, updated_artset, excluded_artset, all_artset, bookmarks_artset } or
	{ all_artset, bookmarks_artset }
local all_artsets
if not Platform.console and rawget(_G, "ArtSpecConfig") then
	CreateRealTimeThread(function()
		all_artsets = table.iappend(table.iappend({ "Any" }, ArtSpecConfig.ArtSets), extra_artsets)
	end)
end

local function store_as_by_category(self, prop_meta) return prop_meta.id .. "_for_" .. self:GetCategory() end

DefineClass.XEditorObjectPalette = {
	__parents = { "XEditorTool" },
	
	properties = {
		persisted_setting = true, auto_select_all = true, small_font = true,
		{ id = "ArtSets", name = "Art sets", editor = "text_picker", horizontal = true, name_on_top = true, default = { "Any" }, multiple = true,
			items = function(self)
				local ret = table.copy(all_artsets)
				if not self.update_times_cache_populated then
					table.remove_value(ret, updated_artset)
				end
				if ModsLoaded and #ModsLoaded > 0 then
					table.insert(ret, table.find(ret, all_artset), mods_artset)
				end
				return ret
			end,
		},
		{ id = "Category", name = "Categories", editor = "text_picker", horizontal = true, name_on_top = true, default = "Any",
		  items = function() return table.iappend({ "Any" }, ArtSpecConfig.Categories) end,
		  no_edit = function(obj) return table.find(obj:GetArtSets(), excluded_artset) or table.find(obj:GetArtSets(), all_artset) end,
		},
		{ id = "SubCategory", editor = "text_picker", horizontal = true, hide_name = true, name_on_top = true, default = "Any",
		  items = function(obj) return table.iappend({ "Any" }, ArtSpecConfig[obj:GetCategory().."Categories"] or empty_table) end,
		  no_edit = function(obj) return table.find(obj:GetArtSets(), excluded_artset) or table.find(obj:GetArtSets(), all_artset) or not ArtSpecConfig[obj:GetCategory().."Categories"] end,
		  store_as = store_as_by_category, -- remember value separately per Category
		},
		{ id = "Filter", editor = "text", default = "", name_on_top = true, allowed_chars = EntityValidCharacters, translate = false, },
		{ id = "ObjectClass", editor = "text_picker", default = empty_table, hide_name = true, multiple = true,
		  filter_by_prop = "Filter", items = function(self) return self:GetObjectClassList() end,
		  store_as = store_as_by_category, -- remember value separately per Category
		  virtual_items = true, bookmark_fn = "SetBookmark",
		},
		{ id = "_", editor = "buttons", buttons = { { name = "Clear bookmarks", func = "ClearBookmarks" } },
		  no_edit = function(obj) return not table.find(obj:GetArtSets(), bookmarks_artset) end,
		},
	},
	
	ToolSection = "Objects",
	FocusPropertyInSettings = "Filter",
	
	update_times_cache_populated = false,
}

---
--- Sets a bookmark for an object in the XEditorObjectPalette.
---
--- @param id string The ID of the object to set the bookmark for.
--- @param value boolean|nil The value to set the bookmark to. If `nil`, the bookmark will be removed.
---
function XEditorObjectPalette:SetBookmark(id, value)
	local bookmarks = LocalStorage.XEditorObjectBookmarks or {}
	bookmarks[id] = value or nil
	LocalStorage.XEditorObjectBookmarks = bookmarks
	SaveLocalStorage()
end

---
--- Clears all bookmarks in the XEditorObjectPalette and resets the art sets to "Any".
---
--- This function is used to clear all bookmarks that have been set for objects in the
--- XEditorObjectPalette. It removes the bookmarks from the LocalStorage and then
--- resets the art sets to "Any". Finally, it notifies the editor that the object
--- palette has been modified.
---
--- @function XEditorObjectPalette:ClearBookmarks
--- @return nil
function XEditorObjectPalette:ClearBookmarks()
	LocalStorage.XEditorObjectBookmarks = {}
	SaveLocalStorage()
	self:SetArtSets{"Any"}
	ObjModified(self)
end

---
--- Initializes the XEditorObjectPalette.
---
--- This function is called to initialize the XEditorObjectPalette. It selects the classes of the objects from the current selection in the object palette, and sets the art sets, category, sub-category, and filter based on the selected objects.
---
--- @function XEditorObjectPalette:Init
--- @return nil
function XEditorObjectPalette:Init()
	-- select the classes of the objects from the current selection in the object palette
	if #editor.GetSel() > 0 and not self.ToolKeepSelection then
		local classes = {}
		for _, obj in ipairs(editor.GetSel()) do
			classes[obj.class] = true
		end
		editor.ClearSel()
		
		local prop_meta = self:GetPropertyMetadata("ObjectClass")
		local items = prop_eval(prop_meta.items, self, prop_meta)
		local existing_classes = {}
		local filtered_out_classes = {}
		local 	filter_string = string.lower(self:GetFilter())
		for _, item in ipairs(items) do
			if string.find(string.lower(item.id), filter_string, 1, true) then
				existing_classes[item.id] = true
			else
				filtered_out_classes[item.id] = true
			end
		end
		
		local reset_sets, reset_filter
		for class in pairs(classes) do
			if filtered_out_classes[class] then
				reset_filter = true
			elseif not existing_classes[class] then
				reset_sets = true
			end
		end
		if reset_sets then
			self:SetArtSets{"Any"}
			self:SetCategory("Any")
			self:SetSubCategory("Any")
			self:SetFilter("")
		elseif reset_filter then
			self:SetFilter("")
		end
		
		self:SetObjectClass(table.keys(classes))
	end
end

---
--- Validates the art sets selected in the object palette.
---
--- This function ensures that the "Any", "New", "Updated", and "Excluded" art sets are only selected alone, and removes them from the list of selected art sets if they are not the only one selected.
---
--- @return table The validated list of selected art sets.
function XEditorObjectPalette:ValidatedArtSets()
	local sets = self:GetArtSets()
	if not Platform.developer then
		table.remove_value(sets, new_artset)
		table.remove_value(sets, updated_artset)
		table.remove_value(sets, excluded_artset)
	elseif not self.update_times_cache_populated then
		table.remove_value(sets, updated_artset)
	end
	if     table.find(sets, "Any") or #sets == 0 then return { "Any" }
	elseif table.find(sets, new_artset)          then return { new_artset }
	elseif table.find(sets, updated_artset)      then return { updated_artset }
	elseif table.find(sets, excluded_artset)     then return { excluded_artset }
	else return sets end
end

---
--- Handles changes to the object palette's properties, ensuring that the "Any", "New", "Updated", and "Excluded" art sets are only selected alone.
---
--- This function is called when the object palette's properties are updated, such as the selected art sets or category. It ensures that the special art sets are only selected alone, and updates the category and subcategory properties accordingly.
---
--- @param prop_id string The ID of the property that was changed.
--- @param old_value any The previous value of the property.
--- @param ged table The GED object associated with the property change.
--- @return nil
function XEditorObjectPalette:OnEditorSetProperty(prop_id, old_value, ged)
	local update
	
	-- the Any, New, Updated, Excluded and All art sets can only be selected alone
	if prop_id == "ArtSets" then
		self:SetArtSets(self:ValidatedArtSets())
		local prop = self:GetPropertyMetadata("Category")
		if prop.no_edit(self) then
			self:SetCategory("Any")
		end
		update = true
	end
	if prop_id == "ArtSets" or prop_id == "Category" then
		local prop = self:GetPropertyMetadata("SubCategory")
		if prop.no_edit(self) then
			self:SetSubCategory("Any")
			update = true
		end
	end
	
	if update then
		GedForceUpdateObject(self)
	end
end

local function eval(val, ...)
	if type(val) == "function" then
		return val(...)
	end
	return val
end

if FirstLoad then
	g_EditorObjectPaletteThread = false
end

---
--- Populates the modification time cache for placeable objects in the editor.
---
--- This function is called to populate a cache of modification times for placeable objects in the editor. It does this by enumerating all placeable objects and evaluating their modification times. The cache is populated asynchronously in a separate thread to avoid blocking the main thread.
---
--- @return nil
function XEditorObjectPalette:PopulateModificationTimeCache()
	if not self.update_times_cache_populated and not g_EditorObjectPaletteThread then
		g_EditorObjectPaletteThread = CreateRealTimeThread(function()
			local time, time1 = GetPreciseTicks(), GetPreciseTicks()
			XEditorEnumPlaceableObjects(function(id, name, artset, category, subcategory, custom_tag, creation_time, modification_time, ...)
				eval(modification_time, ...)
				if GetPreciseTicks() - time >= 10 then
					Sleep(20)
					time = GetPreciseTicks()
				end
			end)
			self.update_times_cache_populated = true
			ObjModified(self)
		end)
	end
end

function XEditorObjectPalette:GetObjectClassList()
	local sets, sets_by_key = self:ValidatedArtSets(), {}
	for _, set in ipairs(sets) do
		sets_by_key[set] = true
	end
	local single_set = #sets <= 1 and (sets[1] or "Any")
	
	self:PopulateModificationTimeCache()
	
	local ret, processed_ids = {}, {}
	local now, week = Platform.developer and os.time(os.date("!*t")), 7*24*60*60
	local cat = self:GetCategory()
	local subcat = self:GetSubCategory()
	local settings_hash = xxhash(0, table.hash(sets_by_key), self.update_times_cache_populated, cat, subcat)
	if settings_hash == self.cached_settings_hash then
		return self.cached_objects_list
	end
	
	local bookmarks = LocalStorage.XEditorObjectBookmarks or {}
	XEditorEnumPlaceableObjects(function(id, name, artset, category, subcategory, custom_tag, creation_time, modification_time, data)
		-- filter by artset / category / subcategory
		if not processed_ids[id] and (cat == "Any" or category == cat) and (subcat == "Any" or subcategory == subcat) then
			creation_time = creation_time and eval(creation_time, data)
			modification_time = modification_time and self.update_times_cache_populated and eval(modification_time, data)
			local is_new = creation_time and now - creation_time < week
			local is_updated = modification_time and now - modification_time < week
			if single_set == all_artset or
			  (single_set == excluded_artset and not artset) or
			  (single_set == bookmarks_artset and bookmarks[id]) or
			  (single_set == mods_artset and artset == "Mods") or
			   artset and ((single_set == new_artset and not custom_tag and is_new) or
				            (single_set == updated_artset and not custom_tag and not is_new and is_updated) or
				            (single_set == "Any" or sets_by_key[artset]))
			then
				local suffix
				if custom_tag then
					suffix = custom_tag
				elseif is_new then
					suffix = new_artset .. (single_set == new_artset and " " .. os.date("%d.%m", creation_time) or "")
				elseif is_updated then
					suffix = updated_artset .. (single_set == updated_artset and " " .. os.date("%d.%m", modification_time) or "")
				end
				ret[#ret + 1] = { id = id, text = suffix and (name .. "<right>" .. suffix) or name, bookmarked = bookmarks[id],
					documentation = data and data.documentation,
				}
			end
		end
		processed_ids[id] = true
	end)
	
	table.sortby_field(ret, "text")
	self.cached_objects_list = ret
	self.cached_settings_hash = settings_hash
	return ret
end


----- Objects palette generator - XEditorEnumPlaceableObjects
--
-- It must call the provided callback for each placeable object, passing the following parameters to the callback, in order:
-- "id"                                            - the id with which XEditorPlaceObject will be called to create the object
-- "name"                                          - the name with which to display the object
-- "editor_artset"                                 - if == nil, the object will appear in the Excluded artset
-- "editor_category", "editor_subcategory"         - classification categories for the objects palette 
-- "custom_display_tag" (optional)                 - tag to be displayed to the right of the object's name
-- "creation_time", "modification_time" (optional) - functions to get the time the object was created and last modified
--
-- Call XEditorUpdateObjectPalette to force the editor to refresh the palette if it is currently open.

---
--- Enumerates all placeable objects in the editor, calling the provided callback for each object.
---
--- The callback is called with the following parameters:
--- - `id`: the id with which `XEditorPlaceObject` will be called to create the object
--- - `name`: the name with which to display the object
--- - `editor_artset`: if `nil`, the object will appear in the Excluded artset
--- - `editor_category`, `editor_subcategory`: classification categories for the objects palette
--- - `custom_display_tag` (optional): tag to be displayed to the right of the object's name
--- - `creation_time`, `modification_time` (optional): functions to get the time the object was created and last modified
---
--- After enumerating all objects, call `XEditorUpdateObjectPalette` to force the editor to refresh the palette if it is currently open.
---
--- @param callback function The callback function to call for each placeable object
function XEditorEnumPlaceableObjects(callback)
	ClassDescendantsList("CObject", function(name, class)
		if name ~= "Light" and class:IsKindOf("Light") then
			callback(name, "Light_" .. name, "Common", "Effects")
			return
		end
		
		-- entity specs are only available in developer mode; skip WIP/Placeholder/New/Updated tags in this case
		local entity = class:GetEntity()
		local entity_spec = Platform.developer and EntitySpecPresets[entity]
		local missing_spec = Platform.developer and not EntitySpecPresets[entity]
		local placeholder = entity_spec and entity_spec.placeholder
		local wip_entity = entity_spec and entity_spec.status ~= "Ready"
		if available_in_editor(entity, name) then
			local data = EntityData[entity] or empty_table
			callback(name, name, data.editor_artset, data.editor_category, data.editor_subcategory,
				missing_spec and "<color 145 254 32>No ArtSpec" or
				placeholder  and "<color 180 180  0>Proxy" or
				wip_entity   and "<color 205  32 32>WIP",
				entity_spec  and function(entity_spec) return entity_spec:GetCreationTime() end,
				entity_spec  and function(entity_spec) return entity_spec:GetModificationTime() end,
				entity_spec)
		end
	end)
	ForEachPreset("ParticleSystemPreset", function(parsys)
		callback(parsys.id, "ParSys_" .. parsys.id, "Common", "Effects")
	end)
	ForEachPreset("FXSourcePreset", function(fxsource)
		assert(not g_Classes[fxsource.id])
		callback(fxsource.id, fxsource.id, "Common", "Effects")
	end)
	callback("WaterFill", "WaterLevel", "Common", "Markers")
	callback("SoundSource", "SoundSource", "Common", "Markers")
	if const.SlabSizeX then
		callback("EditorLineGuide", "LineGuide", "Common", "Markers")
	end
end

XEditorPlaceableObjectsComboCache = false

--- Returns a function that provides a list of all placeable objects in the editor.
---
--- The returned function will cache the list of placeable objects the first time it is called,
--- and return the cached list on subsequent calls. This is to avoid repeatedly enumerating
--- all placeable objects, which can be a slow operation.
---
--- @return function A function that returns a list of all placeable objects in the editor.
function XEditorPlaceableObjectsCombo()
	return function()
		if XEditorPlaceableObjectsComboCache then return XEditorPlaceableObjectsComboCache end
	
		local ret = { "" }
		XEditorEnumPlaceableObjects(function(id) ret[#ret + 1] = id end)
		table.sort(ret)
		XEditorPlaceableObjectsComboCache = ret
		return ret
	end
end

---
--- Places an object in the editor based on the specified ID.
---
--- If the ID corresponds to a ParticleSystemPreset, it will place a particle system.
--- If the ID corresponds to an FXSourcePreset, it will place an FXSource object.
--- If the ID corresponds to a class in g_Classes, it will place an object of that class, if it is available in the editor.
---
--- @param id string The ID of the object to place.
--- @param is_cursor_object boolean Whether the object should be placed as a cursor object.
--- @return table|nil The placed object, or nil if the placement failed.
---
function XEditorPlaceObject(id, is_cursor_object)
	if ParticleSystemPresets[id] then
		return PlaceParticles(id)
	end
	if FXSourcePresets[id] then
		local obj = FXSource:new()
		obj:SetFxPreset(id)
		obj:OnEditorSetProperty("FXPreset")
		return obj
	end
	if g_Classes[id] then
		local entity = g_Classes[id]:GetEntity()
		if available_in_editor(entity, id) then -- the place tool might have remembered a class that is no longer available
			return XEditorPlaceObjectByClass(id, nil, is_cursor_object)
		end
	end
end

---
--- Returns the ID of the specified object.
---
--- If the object is a ParSystem, the function returns the name of the particles.
--- Otherwise, it returns the class of the object.
---
--- @param obj table The object to get the ID for.
--- @return string The ID of the object.
---
function XEditorPlaceId(obj)
	if IsKindOf(obj, "ParSystem") then
		return obj:GetParticlesName()
	else
		return obj.class
	end
end

---
--- Places an object in the editor based on the specified class.
---
--- If the class has any colorization materials, the object will be created with those materials.
---
--- @param class string The class of the object to place.
--- @param obj_table table Optional table of properties to set on the object.
--- @param is_cursor_object boolean Whether the object should be placed as a cursor object.
--- @return table|nil The placed object, or nil if the placement failed.
---
function XEditorPlaceObjectByClass(class, obj_table, is_cursor_object)
	obj_table = obj_table or {}
	if is_cursor_object then
		EditorCursorObjs[obj_table] = true
	end
	
	local colorizations = ColorizationMaterialsCount(g_Classes[class]:GetEntity()) or 0
	local ok, res = pcall(PlaceObject, class, obj_table, colorizations > 0 and const.cofComponentColorizationMaterial)
	if not ok then
		print("Object", class, "failed to initialize and might not function properly in gameplay.")
	end
	return IsValid(res) and res or nil
end

-- boots up the place tool and selects object with the specified id (in most cases = object class) for placing
---
--- Starts the place object tool in the XEditor and sets the object class to the specified ID.
---
--- @param id string The ID of the object class to place.
--- @return table The cursor object created for placing the object.
---
function XEditorStartPlaceObject(id)
	local editor = OpenDialog("XEditor")
	editor:SetMode("XPlaceObjectTool")
	editor.mode_dialog:SetObjectClass{ id }
	return editor.mode_dialog:CreateCursorObject(id)
end

---
--- Updates the object palette in the XEditor.
---
--- This function is called when the classes have been built, and updates the object palette in the XEditor
--- if the current tool is the XEditorObjectPalette.
---
--- @param tool_class string The current tool class in the XEditor.
---
function XEditorUpdateObjectPalette()
	local tool_class = GetDialogMode("XEditor")
	if tool_class and g_Classes[tool_class]:IsKindOf("XEditorObjectPalette") then
		ObjModified(GetDialog("XEditor").mode_dialog)
	end
end

function OnMsg.ClassesBuilt() CreateRealTimeThread(XEditorUpdateObjectPalette) end
