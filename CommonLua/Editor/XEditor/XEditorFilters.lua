-- There are several reasons for which an object could be hidden:
--  a) it is manually hidden with the "Hide selected/unselected" functionality
--  b) it is hidden by making an editor filter button red, e.g. you hide all Rocks
--  c) it is hidden by the floor filter
--
-- We keep a separate table (with object keys) for each "hide reason" and update the
-- objects hidden state according to these tables.

local function reset_filters()
	editor.XFiltersInitedForCurrentMap = false
	editor.HiddenManually = {}
	editor.HiddenByFilter = {}
	editor.HiddenByFloor = {}
	editor.Unselectable = {}
end

if FirstLoad then
	reset_filters()
end

local update_hidden_state

local function CheckFilteredCategories()
	if not LocalStorage.FilteredCategories["All"] then LocalStorage.FilteredCategories["All"] = "visible" end
	if LocalStorage.FilteredCategories["Roofs"] == nil then LocalStorage.FilteredCategories["Roofs"] = true end
	if not LocalStorage.FilteredCategories["HideFloor"] or type(LocalStorage.FilteredCategories["HideFloor"]) ~= "number" then LocalStorage.FilteredCategories["HideFloor"] = 0 end
	SaveLocalStorage()
end

---
--- Applies the editor filters to the current map.
---
--- If the XEditor dialog is open and the filters have not been initialized for the current map, this function will:
--- - Check the filtered categories in the local storage
--- - Activate the filters using `XEditorFilters:ActivateFilters()`
--- - Set `editor.XFiltersInitedForCurrentMap` to `true`
---
--- If the XEditor dialog is not open, this function will call `XEditorFiltersUpdateVisibility()` to update the visibility of objects based on the current filter state.
---
--- Finally, this function sets the object detail level to "High" and disables the application of filters.
---
--- @function XEditorFiltersApply
function XEditorFiltersApply()
	if GetDialog("XEditor") and not editor.XFiltersInitedForCurrentMap then
		CheckFilteredCategories()
		XEditorFilters:ActivateFilters()
		editor.XFiltersInitedForCurrentMap = true
	else
		XEditorFiltersUpdateVisibility()
	end
	EngineSetObjectDetail("High", "dont apply filters")
end

---
--- Resets the editor filters and applies them to the current map if the editor is active.
---
--- @param map string The current map name.
---
function XEditorFiltersReset(map)
	reset_filters()
	if IsEditorActive() and map ~= "" then
		XEditorFiltersApply()
	end
end

---
--- Updates the visibility of objects in the current map based on the current filter state.
---
--- This function suspends pass edits, iterates through all attached objects in the map, and calls `update_hidden_state` on each object to determine if it should be hidden or shown based on the current filter settings.
---
--- After updating the visibility of all objects, this function resumes pass edits.
---
--- @function XEditorFiltersUpdateVisibility
function XEditorFiltersUpdateVisibility()
	SuspendPassEdits("XEditorFiltersUpdateVisibility")
	MapForEach("map", "attached", false, update_hidden_state)
	ResumePassEdits("XEditorFiltersUpdateVisibility")
end

OnMsg.ChangeMapDone = XEditorFiltersReset
OnMsg.GameEnterEditor = XEditorFiltersApply
OnMsg.GameExitEditor = GameToolsRestoreObjectsVisibility
OnMsg.PreSaveMap = GameToolsRestoreObjectsVisibility
OnMsg.PostSaveMap = XEditorFiltersApply

---
--- Updates the hidden state of the given object based on the current filter settings.
---
--- @param obj Object The object to update the hidden state for.
--- @return boolean Whether the object is now hidden.
---
update_hidden_state = function(obj)
	local hide = editor.HiddenManually[obj] or editor.HiddenByFilter[obj] or editor.HiddenByFloor[obj]
	if hide then
		GameToolsHideObject(obj)
		return true
	else
		GameToolsShowObject(obj)
		return false
	end
end

----- Manually showing/hiding objects

---
--- Shows all objects that were previously hidden manually.
---
--- This function suspends pass edits, iterates through all objects that were manually hidden, and calls `update_hidden_state` on each object to determine if it should be shown or remain hidden based on the current filter settings.
---
--- After updating the visibility of all objects, this function resumes pass edits.
---
function editor.ShowHidden()
	SuspendPassEdits("ShowHidden")
	local hidden = editor.HiddenManually
	editor.HiddenManually = setmetatable({}, weak_keys_meta)
	for obj in pairs(hidden) do
		update_hidden_state(obj)
	end
	ResumePassEdits("ShowHidden")
end

---
--- Hides all objects that are not currently selected in the editor.
---
--- This function suspends pass edits, iterates through all objects in the map that are not manually hidden and not currently selected, and hides them by setting the `editor.HiddenManually` flag and calling `GameToolsHideObject`.
---
--- After updating the visibility of all objects, this function resumes pass edits.
---
--- @function editor.HideUnselected
function editor.HideUnselected()
	SuspendPassEdits("HideUnselected")
	MapForEach("map", "attached", false, "CObject", nil, const.efVisible, function(obj)
		if not editor.IsSelected(obj) and not editor.HiddenManually[obj] then
			editor.HiddenManually[obj] = true
			GameToolsHideObject(obj)
		end
	end)
	ResumePassEdits("HideUnselected")
end

---
--- Hides all objects that are currently selected in the editor.
---
--- This function suspends pass edits, iterates through all objects that are currently selected, and hides them by setting the `editor.HiddenManually` flag and calling `GameToolsHideObject`.
---
--- After updating the visibility of all selected objects, this function clears the selection and resumes pass edits.
---
--- @function editor.HideSelected
--- @return nil
function editor.HideSelected()
	SuspendPassEdits("HideSelected")
	local objs = XEditorPropagateChildObjects(editor.GetSel()) -- hide the room if the room marker is selected
	for _, obj in ipairs(objs) do
		if not editor.HiddenManually[obj] then
			editor.HiddenManually[obj] = true
			GameToolsHideObject(obj)
		end
	end
	editor.ClearSel()
	ResumePassEdits("HideSelected")
end


----- Object categorization, category cache

DefineClass.TacticalCameraCollider = {
	__parents = { "Object" },
	flags = { efShadow = false, efSunShadow = false },
}

DefineClass("Animations", "Object")
DefineClass("XEditorFilters")

local EditorFilterCategories = false
function OnMsg.DataLoaded()
	EditorFilterCategories = false
end

---
--- Returns an empty table. This function is used to get a list of non-leaf marker classes for the editor filter system.
---
--- @return table
function GetEditorFilterNonLeafMarkerClasses()
	return {}
end

local veg_prefix = "Veg"
---
--- Returns a list of editor filter categories.
---
--- This function initializes and returns a list of editor filter categories. The categories are defined in a specific order to handle overlapping categories correctly.
---
--- The categories are:
--- - "All": Includes all objects
--- - "Light": Includes light objects
--- - "ParSystem": Includes particle system objects
--- - "SoundSource": Includes sound source objects
--- - "TwoPointsAttach": Includes objects that attach to two points
--- - "GridMarker": Includes grid marker objects
--- - "BakedTerrainDecal": Includes baked terrain decal objects
--- - "TacticalCameraCollider": Includes tactical camera collider objects
--- - "CMTPlane": Includes CMT plane objects
--- - "Room": Includes room objects
--- - "EditorLineGuide": Includes editor line guide objects
--- - "DestroyedSlabMarker": Includes destroyed slab marker objects
--- - "WaterObj": Includes water objects
--- - "BlackPlane": Includes black plane objects
--- - "Animations": Includes animation objects
--- - "Mesh": Includes mesh objects
--- - "AmbientLifeMarker": Includes ambient life marker objects
--- - "Vegs": Includes vegetation objects
--- - "HideTop": Includes objects that are hidden by a parent object
---
--- @return table The list of editor filter categories
function XEditorFilters.GetCategories()
	if not Platform.developer or Platform.console then return end
	local categories = EditorFilterCategories
	if not categories then
		-- PLEASE, PLEASE, PLEASE, add NARROW categories before WIDE ones in case of overlap!!!
		categories = {}
		table.insert(categories, "All")
		table.insert(categories, "Light")
		table.insert(categories, "ParSystem")
		table.insert(categories, "SoundSource")
		table.insert(categories, "TwoPointsAttach")
		if g_Classes.GridMarker then
			table.insert(categories, "GridMarker")
		end
		table.insert(categories, "BakedTerrainDecal")
		table.insert(categories, "TacticalCameraCollider")
		table.insert(categories, "CMTPlane")
		if const.SlabSizeX then
			table.insert(categories, "Room")
			table.insert(categories, "EditorLineGuide")
			table.insert(categories, "DestroyedSlabMarker")
		end
		table.insert(categories, "WaterObj")
		table.insert(categories, "BlackPlane")
		table.insert(categories, "Animations")
		table.insert(categories, "Mesh")
		
		-- REPEAT N1, add NARROW categories before WIDE ones in case of overlap!!!
		local classes = ClassLeafDescendantsList("EditorMarker")
		classes = table.union(classes, GetEditorFilterNonLeafMarkerClasses())
		table.sort(classes)
		if g_Classes.AmbientLifeMarker then
			for i = #classes, 1, -1 do
				if IsKindOf(g_Classes[classes[i]], "AmbientLifeMarker") then
					table.remove(classes, i)
				end
			end
			table.insert(categories, "AmbientLifeMarker")
		end
		categories = table.union(categories, classes)
		-- ALL MARKER categories MUST be added by this point, because the code below adds the wider "Markers" category coming from the Art Spec
		
		-- REPEAT N2, add NARROW categories before WIDE ones in case of overlap!!!
		local artSpecCategories = table.copy(ArtSpecConfig.Categories)
		table.sort(artSpecCategories)
		for _, cat in ipairs(artSpecCategories) do
			if cat == "Vegs" then
				for _, subcat in ipairs(ArtSpecConfig.VegsCategories) do
					if subcat ~= "Other" then
						table.insert(categories, veg_prefix..subcat)
					end
				end
				table.insert(categories, "Vegs")
			elseif cat ~= "Other" then
				table.insert(categories, cat)
			end
		end
		
		-- REPEAT N3, add NARROW categories before WIDE ones in case of overlap!!!
		if g_Classes.HideTop then table.insert(categories, "HideTop") end
		
		-- let the game modify editor filter categories
		Msg("EditorFilterCategories", categories)
	end
	EditorFilterCategories = categories
	return categories
end

local function is_obj_of_category(o, category)
	-- count some marker objects based on class and everything in art category "Markers" as markers
	local entityData = EntityData[o:GetEntity()]
	if category == "Markers" then
		return o:IsKindOfClasses("EditorVisibleObject", "EditorEntityObject") or entityData and entityData.editor_category == "Markers"
	end
	
	if category == "Slab" or (not table.find(ArtSpecConfig.Categories, category) and g_Classes[category]) then
		if category == "HideTop" then
			local parent = o:GetParent()
			if parent and parent:IsKindOf(category) and parent.Top and o == parent.Top and parent:GetGameFlags(const.gofSolidShadow) == 0 then
				return true
			end
		elseif category == "ParSystem" then
			if g_Classes.DecorStateFXObjectWithSound then
				return IsKindOfClasses(o, "ParSystem", "DecorStateFXObjectNoSound", "DecorStateFXObjectWithSound")
			else
				return IsKindOfClasses(o, "ParSystem")
			end
		elseif category == "BlackPlane" and g_Classes.BlackPlane then
			return IsKindOfClasses(o, "BlackPlaneBase", "BlackCylinder")
		else
			return o:IsKindOf(category)
		end
	else
		if category == "Effects" and IsKindOf(o, "FXSource") then
			return true
		end
		if type(entityData) == "table" and entityData.editor_category then
			if category ~= "Vegs" and category:starts_with(veg_prefix) then
				return entityData.editor_subcategory == category:sub(#veg_prefix + 1)
			end
			return entityData.editor_category == category
		end
	end
end

XEditorFiltersClassToCategory = {}

---
--- Determines the category of a given object based on its class and the current editor filter settings.
---
--- @param o table The object to determine the category for.
--- @return string The category of the object.
function XEditorFilters:GetObjCategory(o)
	local result = XEditorFiltersClassToCategory[o.class]
	if result then
		return result
	end
	
	result = "All"
	for _, category in ipairs(XEditorFilters.GetCategories()) do
		if LocalStorage.FilteredCategories[category] and is_obj_of_category(o, category) then
			result = category
			break 
		end
	end
	XEditorFiltersClassToCategory[o.class] = result
	return result
end

---
--- Returns the current filter for the specified category.
---
--- @param category string The category to get the filter for.
--- @return string The current filter for the specified category.
function XEditorFilters:GetFilter(category)
	return LocalStorage.FilteredCategories[category]
end


----- Toggling filters and visibility updates

---
--- Toggles the visibility filter for the specified category.
---
--- @param category string|table The category or categories to toggle the filter for. If a table, the filter will be toggled for all categories in the table.
--- @param visibility boolean Whether to toggle the visibility filter (true) or the selectability filter (false).
function XEditorFilters:ToggleFilter(category, visibility)
	local cat = type(category) == "table" and "All" or category
	if not LocalStorage.FilteredCategories[cat] then return end
	
	local cur_filter = LocalStorage.FilteredCategories[cat]
	local new_filter
	if visibility then
		new_filter = cur_filter == "invisible" and "visible" or "invisible"
	else
		new_filter = cur_filter == "visible" and "unselectable" or "visible"
	end
	
	if type(category) == "table" then
		for cat, locked in pairs(LocalStorage.LockedCategories) do 
			if locked then category[cat] = true end
		end
	end
	self:UpdateVisibility(category, new_filter)
end

---
--- Returns a list of objects that match the specified category or categories.
---
--- @param category string|table The category or categories to get the objects for. If a table, the objects that match any of the categories in the table will be returned.
--- @return table A list of objects that match the specified category or categories.
function XEditorFilters:GetObjects(category)
	local objs = type(category) == "table" and
		MapGet("map", "attached", false,                 function(o) return not IsClutterObj(o) and not category[XEditorFilters:GetObjCategory(o)] end) or
		MapGet("map", "attached", category == "HideTop", function(o) return not IsClutterObj(o) and XEditorFilters:GetObjCategory(o) == category end) or {}
	if type(category) == "table" and not category.HideTop and g_Classes.HideTop then
		return table.iappend(objs, MapGet("map", "attached", true, "HideTop"))
	end
	return objs
end

local function UpdateStorage(category, filter, categories)
	if LocalStorage.FilteredCategories[category] ~= filter then
		LocalStorage.FilteredCategories[category] = filter
		Msg("EditorCategoryFilterChanged", category, filter)
	end
	if type(categories) == "table" then
		for c in pairs(LocalStorage.FilteredCategories) do
			if not categories[c] and c ~= "Roofs" and c ~= "HideFloor" then
				if LocalStorage.FilteredCategories[c] ~= filter then
					LocalStorage.FilteredCategories[c] = filter
					Msg("EditorCategoryFilterChanged", c, filter)
				end
			end
		end
	end
	Msg("EditorFiltersChanged")
end

---
--- Updates the visibility of objects in the specified category.
---
--- @param category string|table The category or categories to update the visibility for. If a table, the visibility of objects in any of the categories in the table will be updated.
--- @param filter string The new visibility filter to apply. Can be "visible", "invisible", or "unselectable".
---
function XEditorFilters:UpdateVisibility(category, filter)
	SuspendPassEdits("UpdateVisibility")
	
	local objs = XEditorFilters:GetObjects(category)
	local filtered, unselectable = editor.HiddenByFilter, editor.Unselectable
	if filter == "visible" then
		for _, obj in ipairs(objs) do
			if filtered[obj] then
				filtered[obj] = nil
				update_hidden_state(obj)
			end
			unselectable[obj] = nil
		end
	elseif filter == "invisible" then
		for _, obj in ipairs(objs) do
			filtered[obj] = true
			unselectable[obj] = true
			GameToolsHideObject(obj)
		end
		editor.RemoveFromSel(objs)
	else -- "unselectable"
		for _, obj in ipairs(objs) do
			if filtered[obj] then
				filtered[obj] = nil
				update_hidden_state(obj)
			end
			unselectable[obj] = true
		end
		editor.RemoveFromSel(objs)
	end
	
	ResumePassEdits("UpdateVisibility")
	
	UpdateStorage(type(category) == "table" and "All" or category, filter, category)
	XEditorUpdateToolbars()
	EngineSetObjectDetail("High", "dont apply filters")
	SaveLocalStorage()
end

---
--- Adds the specified categories to the editor filters, making their objects visible.
---
--- @param categories string[] The categories to add to the editor filters.
---
function XEditorFilters:Add(categories)
	XEditorFiltersClassToCategory = {} -- clear class => category cache
	for _, category in ipairs(categories or empty_table) do
		if not LocalStorage.FilteredCategories[category] and table.find(self:GetCategories(), category) then
			LocalStorage.FilteredCategories[category] = "visible"
			LocalStorage.LockedCategories[category] = false
			self:UpdateVisibility(category, "visible")
		end
	end
	XEditorUpdateToolbars()
end

---
--- Removes the specified categories from the editor filters, making their objects visible.
---
--- @param categories string[] The categories to remove from the editor filters.
---
function XEditorFilters:Remove(categories)
	XEditorFiltersClassToCategory = {} -- clear class => category cache
	for _, category in ipairs(categories or empty_table) do
		self:UpdateVisibility(category, "visible")
		LocalStorage.FilteredCategories[category] = nil
		LocalStorage.LockedCategories[category] = nil
	end
	XEditorUpdateToolbars()
end

---
--- Determines whether the specified object can be selected.
---
--- @param obj any The object to check.
--- @return boolean True if the object can be selected, false otherwise.
---
function XEditorFilters:CanSelect(obj)
	return not editor.Unselectable[obj] and obj:GetGameFlags(const.gofSolidShadow) == 0
end

---
--- Determines whether the specified object is visible.
---
--- @param obj any The object to check.
--- @return boolean True if the object is visible, false otherwise.
---
function XEditorFilters:IsVisible(obj)
	return obj:GetEnumFlags(const.efVisible) ~= 0 and obj:GetGameFlags(const.gofSolidShadow) == 0
end

local get_category = XEditorFilters.GetObjCategory
local filter_state = LocalStorage.FilteredCategories

---
--- Determines whether the specified object is hidden by the editor filters.
---
--- @param obj any The object to check.
--- @return boolean True if the object is hidden, false otherwise.
---
function XEditorFilters:IsObjectHidden(obj)
	return self:GetObjectMode(obj) == "invisible"
end

---
--- Determines the object mode for the given object.
---
--- @param obj any The object to get the mode for.
--- @return string The mode of the object, either "invisible", "unselectable", or nil if the object is not filtered.
---
function XEditorFilters:GetObjectMode(obj)
	local category = get_category(XEditorFilters, obj)
	return filter_state[category]
end

---
--- Updates the visibility and selectability of the specified object based on the current editor filters.
---
--- @param obj any The object to update.
---
function XEditorFilters:UpdateObject(obj)
	-- WARNING: Optimized version below when we are processing all objects!
	local mode = XEditorFilters.GetObjectMode(XEditorFilters, obj)
	if mode == "invisible" or mode == "unselectable" then
		editor.HiddenByFilter[obj] = mode == "invisible"
		editor.Unselectable[obj] = true
		editor.RemoveObjFromSel(obj)
		update_hidden_state(obj)
	end
	if filter_state["HideTop"] == "invisible" and obj:IsKindOf("HideTop") and obj.Top then
		editor.HiddenByFilter[obj.Top] = true
		editor.Unselectable[obj.Top] = true
		GameToolsHideObject(obj.Top)
	end
end

---
--- Updates the visibility and selectability of the specified list of objects based on the current editor filters.
---
--- @param objs table A list of objects to update.
---
function XEditorFilters:UpdateObjectList(objs)
	for _, obj in ipairs(objs) do
		XEditorFilters:UpdateObject(obj)
	end
end

-- optimized version of calling XEditorFilters:UpdateObject for each object on the map
---
--- Updates the visibility and selectability of all objects in the map based on the current editor filters.
---
--- This function is an optimized version of calling `XEditorFilters:UpdateObject` for each object on the map.
---
--- @param unselectable table A table to store objects that are made unselectable by the filters.
--- @param filtered table A table to store objects that are hidden by the filters.
--- @param get_mode function A function to get the object mode for a given object.
--- @param tops_invisible boolean Whether the "HideTop" filter is set to "invisible".
---
function XEditorFilters:UpdateObjects()
	MapForEach("map", "attached", false, function(obj, unselectable, filtered, XEditorFilters, get_mode, tops_invisible)
		if IsClutterObj(obj) then
			return
		end
		local mode = get_mode(XEditorFilters, obj)
		if mode == "invisible" then
			filtered[obj] = true
			unselectable[obj] = true
			GameToolsHideObject(obj)
		elseif mode == "unselectable" then
			unselectable[obj] = true
		end
		if tops_invisible and obj:IsKindOf("HideTop") and obj.Top then
			filtered[obj.Top] = true
			unselectable[obj.Top] = true
			GameToolsHideObject(obj.Top)
		end
	end, editor.Unselectable, editor.HiddenByFilter, XEditorFilters, XEditorFilters.GetObjectMode, filter_state["HideTop"] == "invisible")
end

---
--- Activates the editor filters, updating the visibility and selectability of objects in the map.
---
--- This function suspends pass edits, updates the hidden and unselectable objects based on the current editor filters,
--- hides any objects that are manually hidden, and then resumes pass edits.
---
--- @function XEditorFilters:ActivateFilters
--- @return nil
function XEditorFilters:ActivateFilters()
	SuspendPassEdits("ActivateFilters")
	XEditorFilters:UpdateObjects()
	XEditorFilters:UpdateHiddenRoofsAndFloors()
	for obj in pairs(editor.HiddenManually) do
		GameToolsHideObject(obj)
	end
	ResumePassEdits("ActivateFilters")
end

---
--- Hides floors above the specified floor level and updates the visibility of objects based on the current editor filters.
---
--- This function is responsible for hiding floors above the specified floor level and updating the visibility of objects that are affected by the "HideFloor" filter.
---
--- @param floorIncr number The increment to apply to the current "HideFloor" filter value. Can be positive or negative.
--- @return number The updated "HideFloor" filter value.
function XEditorFilters:SetHideFloorFilter(floorIncr)
end

---
--- Updates the visibility of objects based on the current editor filters, including the "HideFloor" and "Roofs" filters.
---
--- This function is responsible for updating the visibility of objects in the map based on the current editor filters, including the "HideFloor" and "Roofs" filters. It hides objects that are above the specified floor level or are roofs, and updates the editor's selection accordingly.
---
--- @return number The updated "HideFloor" filter value.
function XEditorFilters:UpdateHiddenRoofsAndFloors()
end
if not const.SlabSizeX then
	XEditorFilters.UpdateHiddenRoofsAndFloors = empty_func
else

	function GetMapFloors()
		local floors = 0
		MapForEach("map", "Room", function(o)
			if o.floor > floors then
				floors = o.floor
			end
		end)
		return floors
	end

	GetRoomDataForObjCollection = empty_func
	local TableFind = table.find
	local GetGameFlags = CObject.GetGameFlags
	local GetCollectionIndex = CObject.GetCollectionIndex

	function XEditorFilters:SetHideFloorFilter(floorIncr)
		local floors = GetMapFloors()
		LocalStorage.FilteredCategories["HideFloor"] = Clamp(LocalStorage.FilteredCategories["HideFloor"] + (floorIncr or 0), 0, floors + 1)
		SaveLocalStorage()
		Msg("EditorCategoryFilterChanged", "HideFloor")
		return LocalStorage.FilteredCategories["HideFloor"]
	end

	function XEditorFilters:UpdateHiddenRoofsAndFloors()
		PauseInfiniteLoopDetection("HideFloor")
		
		local floors = GetMapFloors()
		local value = LocalStorage.FilteredCategories["HideFloor"]
		if value == 0 then value = floors + 2 end
		
		local hide_roofs = not LocalStorage.FilteredCategories["Roofs"] or nil
		local filtered, to_update = editor.HiddenByFloor, {}
		HideFloorsAbove(value - 1, function(obj, hide)
			filtered[obj] = hide or hide_roofs and IsKindOfClasses(obj, "BaseRoofWallSlab", "RoofSlab", "CeilingSlab") or nil
			to_update[obj] = true
		end)
		
		local gofOnRoof = const.gofOnRoof
		MapForEach("map", "attached", false, function(o, gofOnRoof, TableFind, GetGameFlags, GetCollectionIndex)
			if GetGameFlags(o, gofOnRoof) ~= 0 then
				filtered[o] = (to_update[o] and filtered[o]) or hide_roofs
				to_update[o] = true
			elseif (GetCollectionIndex(o) or 0) ~= 0 then
				for room, elements in pairs(GetRoomDataForObjCollection(o)) do
					if TableFind(elements, "Roof") then
						filtered[o] = (to_update[o] and filtered[o]) or hide_roofs
						to_update[o] = true
						break
					end
				end
			end
		end, gofOnRoof, TableFind, GetGameFlags, GetCollectionIndex)
		
		local hide_decals = value < floors + 2 or LocalStorage.FilteredCategories.Decal == "invisible" or nil
		MapForEach("map", "attached", false, "Decal", function(o)
			if GetGameFlags(o, const.gofOnRoof) ~= 0 then
				filtered[o] = hide_decals
				to_update[o] = true
			end
		end)
		
		for obj in pairs(to_update) do
			if not update_hidden_state(obj) then
				to_update[obj] = nil
			end
		end
		editor.RemoveFromSel(empty_table, to_update)
		
		if rawget(_G, "AreCoversShown") and AreCoversShown() then
			DbgDrawCovers(g_dbgCoversShown, s_CoversThreadBBox, "don't toggle")
		end
		
		SaveLocalStorage()
		ResumeInfiniteLoopDetection("HideFloor")
		return LocalStorage.FilteredCategories["HideFloor"]
	end
	
end -- const.SlabSizeX

local highlighed_category, highlighs_suspended

---
--- Highlights or unhighlights objects in the editor based on the specified category.
---
--- @param category string The category of objects to highlight or unhighlight.
--- @param highlight boolean True to highlight the objects, false to unhighlight them.
---
function XEditorFilters:HighlightObjects(category, highlight)
	if highlighs_suspended or not XEditorSettings:GetFilterHighlight() then return end
	
	local method = highlight and CObject.SetHierarchyGameFlags or CObject.ClearHierarchyGameFlags
	local objects = XEditorFilters:GetObjects(category)
	local flag = const.gofWhiteColored
	for _, obj in pairs(objects) do
		local col = obj:GetCollection()
		local locked = col and col:GetLocked() or not Collection.GetLockedCollection()
		if locked then
			method(obj, flag)
		end
	end
	highlighed_category = highlight and category
end

---
--- Suspends highlighting of objects in the editor.
---
--- This function will unhighlight any objects that were previously highlighted, and
--- set a flag to prevent further highlighting until `ResumeHighlights()` is called.
---
function XEditorFilters:SuspendHighlights()
	XEditorFilters:HighlightObjects(highlighed_category, false)
	highlighs_suspended = true
end

---
--- Resumes highlighting of objects in the editor.
---
--- This function will re-enable highlighting of objects that were previously suspended
--- using `XEditorFilters:SuspendHighlights()`.
---
function XEditorFilters:ResumeHighlights()
	highlighs_suspended = false
end

---
--- Callback function that is called when an object is placed or cloned in the editor.
---
--- This function updates the object list in the XEditorFilters module when an object is placed or cloned in the editor.
---
--- @param id string The ID of the editor callback, either "EditorCallbackPlace" or "EditorCallbackClone".
--- @param objs table A table of objects that were placed or cloned.
---
function OnMsg.EditorCallback(id, objs)
	if id == "EditorCallbackPlace" or id == "EditorCallbackClone" then
		XEditorFilters:UpdateObjectList(objs)
	end
end
