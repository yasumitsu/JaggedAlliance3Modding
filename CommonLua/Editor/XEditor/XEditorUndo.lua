XEditorCopyScriptTag = "--[[HGE place script 2.0]]"
if FirstLoad then
	XEditorUndo = false
	EditorMapDirty = false
	EditorDirtyObjects = false
	EditorPasteInProgress = false
	EditorUndoPreserveHandles = false
end

local function init_undo()
	XEditorUndo = XEditorUndoQueue:new()
	SetEditorMapDirty(false)
end
OnMsg.ChangeMap = init_undo
OnMsg.LoadGame = init_undo

function OnMsg.SaveMapDone()
	SetEditorMapDirty(false)
end

---
--- Sets the editor map dirty flag.
---
--- When the map is dirty, it means that changes have been made to the map that need to be saved.
--- Calling this function with `true` will set the map as dirty and trigger a "EditorMapDirty" message.
--- Calling it with `false` will clear the dirty flag.
---
--- @param dirty boolean Whether the map is dirty or not.
---
function SetEditorMapDirty(dirty)
	EditorMapDirty = dirty
	if dirty then
		Msg("EditorMapDirty")
	end
end

local s_IsEditorObjectOperation = {
	["EditorCallbackMove"] = true,
	["EditorCallbackRotate"] = true,
	["EditorCallbackScale"] = true,
	["EditorCallbackClone"] = true,
}

function OnMsg.EditorCallback(id, objects)
	if s_IsEditorObjectOperation[id] then
		Msg("EditorObjectOperation", false, objects)
	end
end

-- the following object data keys are undo-related and not actual object properties
local special_props = { __undo_handle = true, class = true, op = true, after = true, eFlags = true, gFlags = true }
local ef_to_restore = const.efVisible | const.efCollision | const.efApplyToGrids
local gf_to_restore = const.gofPermanent | const.gofMirrored
local ef_to_ignore = const.efSelectable | const.efAudible
local gf_to_ignore = const.gofEditorHighlight | const.gofSolidShadow | const.gofRealTimeAnim | const.gofEditorSelection | const.gofAnimated

DefineClass.XEditorUndoQueue = {
	__parents = { "InitDone" },
	
	last_handle = 0,
	obj_to_handle = false,
	handle_to_obj = false,
	handle_remap = false, -- when pasting, store old_handle => new_handle for each pasted object here
	
	current_op = false,
	tracked_obj_data = false,
	collapse_with_previous = false,
	op_depth = 0,
	
	undo_queue = false,
	undo_index = 0,
	last_save_undo_index = 0,
	names_index = 1,
	names_to_queue_idx_map = false,
	watch_thread = false,
	undoredo_in_progress = false,
	update_collections_thread = false,
}

---
--- Initializes the XEditorUndoQueue object.
--- This function sets up the necessary data structures for managing undo/redo operations in the editor.
--- It creates a real-time thread that monitors the mouse capture state and resets the operation depth when necessary.
---
--- @
function XEditorUndoQueue:Init()
	self.obj_to_handle = {}
	self.handle_to_obj = {}
	self.undo_queue = {}
	self.names_to_queue_idx_map = {}
	self.watch_thread = CreateRealTimeThread(function()
		while true do
			while self.op_depth == 0 or terminal.desktop:GetMouseCapture() do
				Sleep(250)
			end
			--assert(false, "Undo error detected - please report this and the last thing you did in the editor!")
			self.op_depth = 0
			Sleep(250)
		end
	end)
end

---
--- Destroys the watch thread that monitors the mouse capture state and resets the operation depth when necessary.
---
function XEditorUndoQueue:Done()
	DeleteThread(self.watch_thread)
end


----- Handles

---
--- Gets the undo/redo handle for the given object.
---
--- If the object does not have an associated handle, a new handle is created and stored in the internal mappings.
---
--- @param obj table The object to get the undo/redo handle for.
--- @return number The undo/redo handle for the given object.
---
function XEditorUndoQueue:GetUndoRedoHandle(obj)
	assert(type(obj) == "table" and (obj.class or obj.Index))
	local handle = self.obj_to_handle[obj]
	if not handle then
		handle = self.last_handle + 1
		self.last_handle = handle
		self.obj_to_handle[obj] = handle
		self.handle_to_obj[handle] = obj
	end
	return handle
end

---
--- Gets the undo/redo object for the given handle.
---
--- If the handle is not found in the internal mappings, a new object is created and associated with the handle.
---
--- @param handle number The undo/redo handle for the object.
--- @param is_collection boolean Whether the object is a collection.
--- @param assign_specific_object table An optional specific object to assign to the handle.
--- @return table The undo/redo object for the given handle.
---
function XEditorUndoQueue:GetUndoRedoObject(handle, is_collection, assign_specific_object)
	if not handle then return false end
	
	-- support for pasting objects
	local obj = self.handle_to_obj[handle]
	if self.handle_remap then
		local new_handle = self.handle_remap[handle]
		if new_handle then
			return self.handle_to_obj[new_handle]
		else
			new_handle = assign_specific_object and self.obj_to_handle[assign_specific_object] or self.last_handle + 1
			
			self.handle_remap[handle] = new_handle
			handle = new_handle
			self.last_handle = Max(self.last_handle, handle)
			obj = nil
		end
	end
	
	if not obj then
		obj = assign_specific_object or {}
		self.handle_to_obj[handle] = obj
		self.obj_to_handle[obj] = handle
		if is_collection then
			Collection.SetIndex(obj, -1)
		end
	end
	return obj
end

---
--- Removes the undo/redo object associated with the given handle.
---
--- This function is used to clear the internal mappings between handles and undo/redo objects.
---
--- @param handle number The undo/redo handle to clear.
---
function XEditorUndoQueue:UndoRedoClear(handle)
	handle = self.handle_remap and self.handle_remap[handle] or handle
	local obj = self.handle_to_obj[handle]
	self.handle_to_obj[handle] = nil
	self.obj_to_handle[obj] = nil
end


----- Storing/restoring object properties

local function store_objects_prop(value)
	if not value then return false end
	local ret = {}
	for k, v in pairs(value) do
		ret[k] = IsValid(v) and XEditorUndo:GetUndoRedoHandle(v) or store_objects_prop(v)
	end
	return ret
end

local function restore_objects_prop(value)
	if not value then return false end
	local ret = {}
	for k, v in pairs(value) do
		ret[k] = type(v) == "table" and restore_objects_prop(v) or XEditorUndo:GetUndoRedoObject(v)
	end
	return ret
end

---
--- Processes the property value of an object for undo/redo purposes.
---
--- This function is responsible for handling different types of property values, such as collections, nested objects, and grids, and ensuring that they are properly stored and restored during undo/redo operations.
---
--- @param obj table The object whose property value is being processed.
--- @param id string The ID of the property being processed.
--- @param prop_meta table The metadata for the property being processed.
--- @param value any The value of the property being processed.
--- @return any The processed property value, suitable for undo/redo operations.
---
function XEditorUndoQueue:ProcessPropertyValue(obj, id, prop_meta, value)
	local editor = prop_meta.editor
	if id == "CollectionIndex" then
		return self:GetUndoRedoHandle(obj:GetCollection())
	elseif editor == "objects" then
		return store_objects_prop(value)
	elseif editor == "object" then
		return self:GetUndoRedoHandle(value)
	elseif editor == "nested_list" then
		local ret = value and {}
		for i, o in ipairs(value) do ret[i] = o:Clone() end
		return ret
	elseif editor == "nested_obj" or editor == "script" then
		return value and value:Clone()
	elseif editor == "grid" and value then
		return value:clone()
	else
		return value
	end
end

---
--- Retrieves the object data for the specified object, including its properties and flags, for undo/redo purposes.
---
--- @param obj table The object to retrieve data for.
--- @return table The object data, including its properties and flags.
---
function XEditorUndoQueue:GetObjectData(obj)
	local data = {
		__undo_handle = self:GetUndoRedoHandle(obj),
		class = obj.class
	}
	for _, prop_meta in ipairs(obj:GetProperties()) do
		local id = prop_meta.id
		assert(not special_props[id])
		local value = obj:GetProperty(id)
		if (EditorUndoPreserveHandles and id == "Handle") or not obj:ShouldCleanPropForSave(id, prop_meta, value) then
			data[id] = self:ProcessPropertyValue(obj, id, prop_meta, value)
		end
	end
	data.eFlags = band(obj:GetEnumFlags(), ef_to_restore)
	data.gFlags = band(obj:GetGameFlags(), gf_to_restore)
	return data
end

local function get_flags_xor(flags1, flags2, flagsList)
	local result = {}
	for i, flag in pairs(flagsList) do
		if flag ~= "gofDirtyTransform" and flag ~= "gofDirtyVisuals" and flag ~= "gofEditorSelection" then
			if band(flags1, shift(1, i - 1)) ~= band(flags2, shift(1, i - 1)) then
				table.insert(result, flag.name or flag)
			end
		end
	end
	return table.concat(result, ", ")
end

---
--- Restores an object from the provided object data, including its properties and flags, for undo/redo purposes.
---
--- @param obj table The object to restore.
--- @param obj_data table The object data, including its properties and flags, to restore the object with.
--- @param prev_data table The previous object data, used to restore default property values if necessary.
--- @return table The restored object.
---
function XEditorUndoQueue:RestoreObject(obj, obj_data, prev_data)
	if not IsValid(obj) then return end
	assert(obj.class ~= "CollectionsToHideContainer")
	for _, prop_meta in ipairs(obj:GetProperties()) do
		local id = prop_meta.id
		local value = obj_data[id]
		if value == nil and prev_data and prev_data[id] then
			value = obj:GetDefaultPropertyValue(id, prop_meta)
		end
		if value ~= nil then
			local prop = prop_meta.editor
			if id == "CollectionIndex" then
				if value == 0 then
					CObject.SetCollectionIndex(obj, 0)
				else
					local collection = self:GetUndoRedoObject(value, "Collection")
					if obj_data.class == "Collection" and collection.Index == editor.GetLockedCollectionIdx() then
						editor.AddToLockedCollectionIdx(obj.Index)
					end
					CObject.SetCollectionIndex(obj, collection.Index)
				end
			elseif prop == "objects" then
				obj:SetProperty(id, restore_objects_prop(value))
			elseif prop == "object" then
				obj:SetProperty(id, self:GetUndoRedoObject(value))
			elseif prop == "nested_list" then
				local objects = {}
				for i, o in ipairs(value) do objects[i] = o:Clone() end
				obj:SetProperty(id, value and objects)
			elseif prop == "nested_obj" then
				obj:SetProperty(id, value and value:Clone())
			elseif id == "Handle" then
				if EditorUndoPreserveHandles and not EditorPasteInProgress then
					-- resolve handle collisions, e.g. from multiple applied map patches
					local start, size = GetHandlesAutoLimits()
					while HandleToObject[value] do
						value = value + 1
						if value >= start + size then
							value = start
						end
					end
					obj:SetProperty(id, value)
				end
			else
				obj:SetProperty(id, value)
			end
		end
	end
	if obj_data.eFlags then
		obj:SetEnumFlags(obj_data.eFlags) obj:ClearEnumFlags(band(bnot(obj_data.eFlags), ef_to_restore))
		obj:SetGameFlags(obj_data.gFlags) obj:ClearGameFlags(band(bnot(obj_data.gFlags), gf_to_restore))
		obj:ClearGameFlags(const.gofEditorHighlight)
	end
	return obj
end


----- Undo/redo operations
--
-- Capturing undo data works using the concept of tracked objects. Start capturing an undo operation
-- by calling BeginOp; complete it with EndOp; in-between add extra tracked objects via StartTracking.
-- 
-- Objects are assigned "undo handles" to keep their identity between undo & redo operations that might
-- delete them. The tracked objects' initial states are kept by handle in 'tracked_obj_data'. For newly
-- created objects the value kept will be 'false'.
--
-- Complex objects such as Volumes/Rooms are handles via the concept of "children" objects (e.g. Slab).
-- Whenever the an object is tracked, we get related objects via GetEditorRelatedObjects/GetEditorParentObject.
-- The state of those object also get tracked automatically.
--
-- BeginOp takes a table of settings to provide it with information about what needs to be tracked:
-- 1. Pass a list of objects in the "objects" field.
-- 2. Mark any grid that will be changed as a "true" field in settings, e.g. { terrain_type = true }.
-- 3. Pass the operation name for the list of operations combo as e.g. { name = "Deleted objects" }.
--
-- EndOp only takes a list of extra objects to be tracked - usually newly created objects during the operation.
--
-- BeginOp/EndOp calls can be nested - a new undo operation is created and pushed into the undo queue when
-- the last EndOp call balances out with BeginOp calls. This allows for easy tracking of editor operations
-- that use other operations to complete, or merging different editor operations into a single one.
--
-- The editor's copy/paste & map patching funcionalities uses the same mechanism for capturing/storing objects.
-- When pasting or applying a patch, newly created objects are assigned new handles via a handle remapping
-- mechanism to prevent collisions with existing handles (see handle_remap member).
--
-- The 'data' member of ObjectsEditOp is a single table with entries for each affected object in order:
--  { op = "delete", __undo_handle = 1, <props>... },
--  { op = "create", __undo_handle = 1, <props>... },
--  { op = "update", __undo_handle = 1, after = { <new_props>... }, <old_props>... },

local function add_child_objects(objects, method, param)
	local added = {}
	for _, obj in ipairs(objects) do
		added[obj] = true
	end
	for _, obj in ipairs(objects) do
		for _, related in ipairs(obj[method or "GetEditorRelatedObjects"](obj, param)) do
			if IsValid(related) and not added[related] then
				objects[#objects + 1] = related
				added[related] = true
			end
		end
	end
end

local function add_parent_objects(objects, for_copy, locked_collection)
	local added = {}
	for _, obj in ipairs(objects) do
		added[obj] = true
	end
	local i = 1
	while i <= #objects do
		local obj = objects[i]
		local parent = obj:GetEditorParentObject()
		if not for_copy and IsValid(parent) and not added[parent] then
			objects[#objects + 1] = parent
			added[parent] = true
		end
		local collection = obj:GetCollection()
		if IsValid(collection) and collection ~= locked_collection and not added[collection] then
			objects[#objects + 1] = collection
			added[collection] = true
		end
		i = i + 1
	end
end

---
--- Tracks the internal state of the specified objects in the undo queue.
---
--- This function is called internally by the undo queue to keep track of the state of objects
--- that are part of the current undo operation. It records the initial state of the objects
--- so that they can be restored later if the undo operation is performed.
---
--- @param objects table An array of objects to track
--- @param idx number The starting index in the `objects` array to begin tracking
--- @param created boolean Whether the objects were just created as part of the current operation
---
function XEditorUndoQueue:TrackInternal(objects, idx, created)
	local data = self.tracked_obj_data
	assert(data) -- tracking an object is only possible after :BeginOp is called to create an undo operation
	if not data then return end
	for i = idx, #objects do
		local obj = objects[i]
		local handle = self:GetUndoRedoHandle(obj)
		if data[handle] == nil then
			data[handle] = not created and self:GetObjectData(obj)
		end
	end
end

---
--- Starts tracking the specified objects in the undo queue.
---
--- This function is called internally by the undo queue to keep track of the state of objects
--- that are part of the current undo operation. It records the initial state of the objects
--- so that they can be restored later if the undo operation is performed.
---
--- @param objects table An array of objects to track
--- @param created boolean Whether the objects were just created as part of the current operation
--- @param omit_children boolean Whether to omit adding child objects to the tracking
---
function XEditorUndoQueue:StartTracking(objects, created, omit_children)
	objects = table.copy_valid(objects)
	for idx, obj in ipairs(objects) do
		assert(obj.class ~= "CollectionsToHideContainer")
	end
	if #objects == 0 then return end
	if not omit_children then
		add_child_objects(objects)
	end
	self:TrackInternal(objects, 1, created)
	
	local start_idx = #objects + 1
	add_parent_objects(objects)
	self:TrackInternal(objects, start_idx) -- non-explicit parents are assumed to have existed before the operation
	
	Msg("EditorObjectOperation", false, objects)
	EditorDirtyObjects = table.union(objects, table.validate(EditorDirtyObjects))
end

---
--- Begins a new undo operation, tracking the specified objects and storing the initial state of the editor.
---
--- This function is called to start a new undo operation. It records the initial state of the editor, including the current selection and any edited grids, so that the operation can be undone later.
---
--- @param settings table An optional table of settings for the undo operation. Supported settings are:
---   - `clipboard`: a boolean indicating whether to track the clipboard as part of the undo operation
---   - `collapse_with_previous`: a boolean indicating whether to collapse this undo operation with the previous one
---   - `objects`: an array of objects to track as part of the undo operation
--- @return nil
function XEditorUndoQueue:BeginOp(settings)
	if self.undoredo_in_progress then return end
	
	settings = settings or empty_table
	self.current_op = self.current_op or { clipboard = settings.clipboard }
	self.tracked_obj_data = self.tracked_obj_data or {}
	self.op_depth = self.op_depth + 1
	if self.op_depth == 1 then
		self.collapse_with_previous = settings.collapse_with_previous
		EditorDirtyObjects = empty_table
	end
	
	PauseInfiniteLoopDetection("Undo")
	
	if settings.objects then
		self:StartTracking(settings.objects)
	end
	
	-- store the "before" state of selection and edited grids
	local op = self.current_op
	if not op.selection then
		op.selection = SelectionEditOp:new()
		for i, obj in ipairs(editor.GetSel()) do
			op.selection.before[i] = self:GetUndoRedoHandle(obj)
		end
	end
	for _, grid in ipairs(editor.GetGridNames()) do
		if settings[grid] and not op[grid] then
			op[grid] = GridEditOp:new{ name = grid, before = editor.GetGrid(grid) }
		end
	end
	
	op.name = op.name or settings.name
	ResumeInfiniteLoopDetection("Undo")
end

-- collections must be at the front of undo data; collections need to be created first
-- and allocate/restore their indexes before objects are added to them via SetCollection
local function add_obj_data(data, obj_data)
	if obj_data then
		if obj_data.class == "Collection" then
			table.insert(data, 1, obj_data)
		else
			data[#data + 1] = obj_data
		end
	end
end

local function is_nop(obj_data)
	local after = obj_data.after
	for k, v in pairs(after) do
		if not special_props[k] and not CompareValues(obj_data[k], v) then
			return false
		end
	end
	for k in pairs(obj_data) do
		if after[k] == nil then
			return false
		end
	end
	return true
end

---
--- Returns whether an undo/redo operation capture is in progress.
---
--- @return boolean True if an undo/redo operation capture is in progress, false otherwise.
function XEditorUndoQueue:OpCaptureInProgress()
	return self.op_depth > 0
end

---
--- Asserts whether an undo/redo operation capture is in progress.
---
--- @return boolean True if an undo/redo operation capture is in progress, false otherwise.
function XEditorUndoQueue:AssertOpCapture()
	return not IsEditorActive() or IsChangingMap() or XEditorUndo.undoredo_in_progress or XEditorUndo:OpCaptureInProgress()
end

---
--- Ends an editor operation and generates an undo/redo operation for the changes made during the operation.
---
--- This function is called at the end of an editor operation to finalize the changes and generate an undo/redo operation.
--- It performs the following tasks:
--- - Asserts that an operation capture is in progress.
--- - Starts tracking the objects involved in the operation.
--- - Sends messages for final cleanup when an editor operation involving objects ends.
--- - Finalizes the operation when the BeginOp/EndOp calls become balanced.
--- - Captures the "after" data for the objects and creates the object undo operation.
--- - Returns the generated edit operation.
---
--- @param objects table The objects involved in the operation.
--- @param bbox table The bounding box of the operation.
--- @return table The generated edit operation.
function XEditorUndoQueue:EndOpInternal(objects, bbox)
	assert(self:OpCaptureInProgress(), "Unbalanced calls between BeginOp and EndOp")
	if not self:OpCaptureInProgress() then return end
	
	PauseInfiniteLoopDetection("Undo")
	
	if objects then
		self:StartTracking(objects, "created")
	end
	
	-- messages for final cleanup when an editor operation involving objects ends
	if self.op_depth == 1 then
		-- keeping op_depth == 1 at this point prevents an infinite loop if the Msgs invoke undo ops
		if next(self.tracked_obj_data) then
			Msg("EditorObjectOperation", true, table.validate(EditorDirtyObjects))
			Msg("EditorObjectOperationEnding")
		end
		EditorDirtyObjects = false
	end
	self.op_depth = self.op_depth - 1
	
	-- finalize operation when the BeginOp/EndOp calls become balanced
	if self.op_depth == 0 then
		local edit_operation = self.current_op
		
		-- drop selection op if selection is the same
		if edit_operation.selection then
			local selDiff = #editor.GetSel() ~= #edit_operation.selection.before
			for i, obj in ipairs(editor.GetSel()) do
				edit_operation.selection.after[i] = self:GetUndoRedoHandle(obj)
				if edit_operation.selection.after[i] ~= edit_operation.selection.before[i] then
					selDiff = true
				end
			end
			if not selDiff then
				edit_operation.selection:delete()
				edit_operation.selection = nil
			end
		end
		
		-- calculate grid diffs
		for _, grid in ipairs(editor.GetGridNames()) do
			local grid_op = edit_operation[grid]
			if grid_op then
				local before, after = grid_op.before, editor.GetGrid(grid)
				-- Find the boxes where there are differences between the two grids and save them in the op's array part
				local diff_boxes = editor.GetGridDifferenceBoxes(grid, after, before, bbox)
				if diff_boxes then
					for idx, box in ipairs(diff_boxes) do
						local change = {
							box = box,
							before = editor.GetGrid(grid, box, before),
							after = editor.GetGrid(grid, box, after),
						}
						table.insert(grid_op, change)
					end
				end
				before:free()
				after:free()
				grid_op.before = nil
			end
		end
		
		-- capture the "after" data and create the object undo operation
		self.handle_remap = nil
		if next(self.tracked_obj_data) then
			local data = {}
			for handle, obj_data in sorted_pairs(self.tracked_obj_data) do
				local obj = self.handle_to_obj[handle]
				if obj_data then
					if IsValid(obj) then
						obj_data.after = self:GetObjectData(obj)
						obj_data.op = "update"
						if is_nop(obj_data) then
							obj_data = nil
						end
					else
						if self.handle_to_obj[handle] then
							self:UndoRedoHandleClear(handle)
						end
						obj_data.op = "delete"
					end
				elseif IsValid(obj) then
					obj_data = self:GetObjectData(obj)
					obj_data.op = "create"
				end
				add_obj_data(data, obj_data)
			end
			edit_operation.objects = ObjectsEditOp:new{ data = data }
		end
		
		self.current_op = false
		self.tracked_obj_data = false
		ResumeInfiniteLoopDetection("Undo")
		return edit_operation
	end
	
	ResumeInfiniteLoopDetection("Undo")
end

---
--- Ends the current edit operation and adds it to the undo queue.
---
--- If there is an ongoing undo/redo operation in progress, this function will return without doing anything.
---
--- If the `collapse_with_previous` flag is set, this function will attempt to merge the current edit operation with the previous one in the undo queue, if they have the same name.
---
--- After the edit operation is added to the undo queue, the `UpdateOnOperationEnd` function is called to notify any listeners of the operation.
---
--- @param objects table The objects involved in the edit operation.
--- @param bbox table The bounding box of the edit operation.
--- @return table The edit operation that was added to the undo queue.
function XEditorUndoQueue:EndOp(objects, bbox)
	if self.undoredo_in_progress then return end
	
	local edit_operation = self:EndOpInternal(objects, bbox)
	if edit_operation then
		self:AddEditOp(edit_operation)
		if self.collapse_with_previous and self:CanMergeOps(self.undo_index - 1, self.undo_index, "same_names") then
			self:MergeOps(self.undo_index - 1, self.undo_index)
		end
		self.collapse_with_previous = false
		
		self:UpdateOnOperationEnd(edit_operation)
	end
end

---
--- Adds an edit operation to the undo queue.
---
--- This function appends the given `edit_operation` to the end of the `undo_queue` array. It also removes any undo operations that were added after the current undo index, effectively discarding any redo operations.
---
--- @param edit_operation table The edit operation to add to the undo queue.
---
function XEditorUndoQueue:AddEditOp(edit_operation)
	self.undo_index = self.undo_index + 1
	self.undo_queue[self.undo_index] = edit_operation
	for i = self.undo_index + 1, #self.undo_queue do
		self.undo_queue[i] = nil
	end
end

local allowed_keys = { name = true, objects = true }
---
--- Checks if the edit operations between the given indices can be merged.
---
--- This function checks if the edit operations between the given indices `idx1` and `idx2` can be merged. It does this by checking the following conditions:
---
--- 1. If `idx1` is less than 0, the function returns `false`.
--- 2. If the `same_names` parameter is `true`, the function checks if all the edit operations between `idx1` and `idx2` have the same name as the edit operation at `idx1`.
--- 3. The function checks if all the keys in the edit operations between `idx1` and `idx2` are in the `allowed_keys` table.
---
--- If all the conditions are met, the function returns `true`, indicating that the edit operations can be merged. Otherwise, it returns `false`.
---
--- @param idx1 number The starting index of the edit operations to check.
--- @param idx2 number The ending index of the edit operations to check.
--- @param same_names boolean If `true`, the function will check if all the edit operations have the same name.
--- @return boolean `true` if the edit operations can be merged, `false` otherwise.
function XEditorUndoQueue:CanMergeOps(idx1, idx2, same_names)
	if idx1 < 0 then return end
	local name = same_names and self.undo_queue[idx1].name
	for idx = idx1, idx2 do
		local edit_op = self.undo_queue[idx]
		for k in pairs(edit_op) do
			if not allowed_keys[k] then return end
		end
		if name and edit_op.name ~= name then return end
	end
	return true
end

---
--- Merges a series of edit operations in the undo queue.
---
--- This function takes a range of edit operations in the undo queue, specified by the `idx1` and `idx2` parameters, and merges them into a single edit operation. The merged operation will have the name specified by the `name` parameter, or the name of the first operation in the range if `name` is not provided.
---
--- The function works by analyzing the objects that were modified by the edit operations in the range. It constructs a new edit operation that represents the cumulative changes to those objects, taking into account create, update, and delete operations. The new edit operation is then inserted into the undo queue, replacing the original operations in the specified range.
---
--- @param idx1 number The starting index of the edit operations to merge.
--- @param idx2 number The ending index of the edit operations to merge.
--- @param name string (optional) The name to give the merged edit operation.
function XEditorUndoQueue:MergeOps(idx1, idx2, name)
	local before, after = {}, {} -- these store object data by handle, just like in tracked_obj_data
	for idx = idx1, idx2 do
		local edit_op = self.undo_queue[idx]
		local objs_data = edit_op and edit_op.objects and edit_op.objects.data
		for _, obj_data in ipairs(objs_data) do
			local op = obj_data.op
			local handle = obj_data.__undo_handle
			if before[handle] == nil then
				before[handle] = op ~= "create" and obj_data or false
			end
			after[handle] = op == "create" and obj_data or op == "update" and obj_data.after or false
		end
	end
	
	local data = {}
	for handle, obj_data in sorted_pairs(before) do
		if not obj_data then
			obj_data = after[handle]
			if obj_data then
				obj_data.op = "create"
			end
		elseif after[handle] then
			obj_data.after = after[handle]
			obj_data.op = "update"
		else
			obj_data.op = "delete"
		end
		add_obj_data(data, obj_data)
	end
	
	name = name or self.undo_queue[idx1].name
	for idx = idx1, #self.undo_queue do
		self.undo_queue[idx] = nil
	end
	table.insert(self.undo_queue, { name = name, objects = ObjectsEditOp:new{ data = data }})
	self.undo_index = idx1
end

---
--- Undoes or redoes a series of edit operations in the undo queue.
---
--- This function takes the current undo/redo operation type and whether to update map hashes. It retrieves the corresponding edit operation from the undo queue, performs the undo or redo operation, and updates the editor state accordingly.
---
--- @param op_type string The type of operation, either "undo" or "redo".
--- @param update_map_hashes boolean Whether to update map hashes for the edit operation.
---
function XEditorUndoQueue:UndoRedo(op_type, update_map_hashes)
	local undo = op_type == "undo"
	local edit_op = undo and self.undo_queue[self.undo_index] or self.undo_queue[self.undo_index + 1]
	if not edit_op then return end
	self.undo_index = undo and self.undo_index - 1 or self.undo_index + 1
	if self.undo_index < 0 or self.undo_index > #self.undo_queue then
		self.undo_index = Clamp(self.undo_index, 0, #self.undo_queue)
		return
	end
	
	self.undoredo_in_progress = true
	SuspendPassEditsForEditOp(edit_op.objects and edit_op.objects.data or empty_table)
	PauseInfiniteLoopDetection("XEditorEditOps")
	SuspendObjModified("XEditorEditOps")
	for _, op in sorted_pairs(edit_op) do
		if IsKindOf(op, "EditOp") then
			procall(undo and op.Undo or op.Do, op)
			if update_map_hashes then
				op:UpdateMapHashes()
			end
		end
	end
	if edit_op.clipboard then
		CopyToClipboard(edit_op.clipboard)
	end
	self:UpdateOnOperationEnd(edit_op)
	ResumeObjModified("XEditorEditOps")
	ResumeInfiniteLoopDetection("XEditorEditOps")
	ResumePassEditsForEditOp()
	self.undoredo_in_progress = false
end

---
--- Updates the editor state after a series of edit operations have completed.
---
--- This function is called when an undo or redo operation has finished. It performs the following tasks:
--- - Sets the editor map as dirty, indicating that changes have been made.
--- - Updates the editor toolbars to reflect the current state.
--- - If the edit operation involved objects, it creates a real-time thread to update the collections editor after a 1-second delay.
---
--- @param edit_op table The edit operation that has just completed.
---
function XEditorUndoQueue:UpdateOnOperationEnd(edit_op)
	for key in pairs(edit_op) do
		if key ~= "selection" and key ~= "clipboard" then
			SetEditorMapDirty(true)
		end
	end
	XEditorUpdateToolbars() -- doesn't update the toolbar if it was updated soon
	
	-- these are okay to be delayed by 1 sec.
	if edit_op.objects and not self.update_collections_thread then
		self.update_collections_thread = CreateRealTimeThread(function()
			Sleep(1000)
			UpdateCollectionsEditor()
			self.update_collections_thread = false
		end)
	end
end


----- Editor statusbar combo

---
--- Gets the names of the operations in the undo queue.
---
--- This function returns a table of strings representing the names of the operations in the undo queue. The names are formatted to indicate the current position in the undo/redo history.
---
--- @param plain boolean If true, the function will return the names without any formatting.
--- @return table The names of the operations in the undo queue.
---
function XEditorUndoQueue:GetOpNames(plain)
	local names = { "No operations" }
	local idx_map = { 0 }
	local cur_op_passed, cur_op_idx = false, false
	for i = 1, #self.undo_queue do
		local cur = self.undo_queue[i] and self.undo_queue[i].name
		cur_op_passed = cur_op_passed or i == self.undo_index + 1
		if cur then
			local prev = names[#names]
			if prev and string.ends_with(prev, cur) and not cur_op_passed then
				local n = (tonumber(string.match(prev, "%s(%d+)[^%s%d]")) or 1) + 1
				cur = string.format("%d. %dX %s", #names - 1, n, cur)
				names[#names] = cur
				idx_map[#idx_map] = i
			else
				if cur_op_passed then
					cur_op_idx = #idx_map
					cur_op_passed = false
				end
				table.insert(names, string.format("%d. %s", #names, cur))
				table.insert(idx_map, i)
			end
		end
	end
	
	if not plain then
		self.names_to_queue_idx_map = idx_map
		self.names_index = cur_op_idx or Max(#idx_map, 1)
		for i = self.names_index + 1, #names do
			names[i] = "<color 96 96 96>" .. names[i] .. "</color>"
		end
	end
	return names
end

---
--- Gets the index of the current operation name in the undo queue.
---
--- This function returns the index of the current operation name in the list of operation names returned by `XEditorUndoQueue:GetOpNames()`. This index corresponds to the current position in the undo/redo history.
---
--- @return number The index of the current operation name.
---
function XEditorUndoQueue:GetCurrentOpNameIdx()
	return self.names_index
end

---
--- Rolls the undo/redo queue to the specified operation index.
---
--- This function is used to navigate the undo/redo history. It will undo or redo operations until the queue is at the specified index.
---
--- @param new_index number The index of the operation to roll to in the undo/redo queue.
---
function XEditorUndoQueue:RollToOpIndex(new_index)
	if new_index ~= self.names_index then
		local new_undo_index = self.names_to_queue_idx_map[new_index]
		local op = self.undo_index > new_undo_index and "undo" or "redo"
		while self.undo_index ~= new_undo_index do
			self:UndoRedo(op)
		end
		self.names_index = new_index
	end
end


----- EditOp classes

DefineClass.EditOp = {
	__parents = { "InitDone" },
	StoreAsTable = true,
}

---
--- Executes the edit operation.
---
--- This function is called to perform the edit operation. It is responsible for applying the changes defined by the edit operation to the editor's state.
---
--- @return nil
---
function EditOp:Do()
end

---
--- Undoes the edit operation.
---
--- This function is called to undo the changes made by the edit operation. It is responsible for reverting the editor's state to the state before the edit operation was performed.
---
--- @return nil
---
function EditOp:Undo()
end

---
--- Updates the map hashes.
---
--- This function is responsible for updating the map hashes associated with the edit operation. It is called as part of the undo/redo process to ensure the editor's state is properly updated.
---
--- @return nil
---
function EditOp:UpdateMapHashes()
end

DefineClass.ObjectsEditOp = {
	__parents = { "EditOp" },
	data = false, -- see comments above XEditorUndo:BeginOp for details
	by_handle = false,
}

---
--- Gets the objects affected by the edit operation before it is performed.
---
--- This function returns a list of objects that will be affected by the edit operation before it is performed. This includes objects that will be deleted or updated by the operation.
---
--- @return table The list of affected objects.
---
function ObjectsEditOp:GetAffectedObjectsBefore()
	local ret = {}
	for _, obj_data in ipairs(self.data) do
		local op = obj_data.op
		if op == "delete" or op == "update" then
			local handle = obj_data.__undo_handle
			table.insert(ret, XEditorUndo:GetUndoRedoObject(handle))
		end
	end
	return ret
end

---
--- Gets the objects affected by the edit operation after it is performed.
---
--- This function returns a list of objects that will be affected by the edit operation after it is performed. This includes objects that will be created or updated by the operation.
---
--- @return table The list of affected objects.
---
function ObjectsEditOp:GetAffectedObjectsAfter()
	local ret = {}
	for _, obj_data in ipairs(self.data) do
		local op = obj_data.op
		if op == "create" or op == "update" then
			local handle = obj_data.__undo_handle
			table.insert(ret, XEditorUndo:GetUndoRedoObject(handle))
		end
	end
	return ret
end

---
--- Calls the EditorCallbackPreUndoRedo event before performing an undo or redo operation.
---
--- This function collects all the objects affected by the undo or redo operation and sends an EditorCallbackPreUndoRedo event with the list of affected objects.
---
--- @return nil
---
function ObjectsEditOp:EditorCallbackPreUndoRedo()
	local objs = {}
	for _, obj_data in ipairs(self.data) do
		table.insert(objs, XEditorUndo.handle_to_obj[obj_data.__undo_handle]) -- don't use GetUndoRedoObject, it has side effects
	end
	Msg("EditorCallbackPreUndoRedo", table.validate(objs))
end

---
--- Performs an edit operation on a set of objects.
---
--- This function is responsible for executing the edit operation, which can include creating, deleting, or updating objects. It also handles the necessary callbacks and notifications to ensure the editor state is properly updated.
---
--- @return nil
---
function ObjectsEditOp:Do()
	self:EditorCallbackPreUndoRedo()
	local newobjs = {}
	local oldobjs = {}
	local movedobjs = {}
	for _, obj_data in ipairs(self.data) do
		local op = obj_data.op
		local handle = obj_data.__undo_handle
		local obj = XEditorUndo:GetUndoRedoObject(handle)
		if op == "delete" then
			XEditorUndo:UndoRedoHandleClear(handle)
			oldobjs[#oldobjs + 1] = obj
		elseif op == "create" then
			obj = XEditorPlaceObjectByClass(obj_data.class, obj)
			XEditorUndo:RestoreObject(obj, obj_data)
			newobjs[#newobjs + 1] = obj
		else -- update
			XEditorUndo:RestoreObject(obj, obj_data.after, obj_data)
			if obj_data.after and obj_data.Pos ~= obj_data.after.Pos then
				movedobjs[#movedobjs + 1] = obj
			end
			ObjModified(obj)
		end
	end
	
	for _, obj_data in ipairs(self.data) do
		if obj_data.op ~= "delete" then
			local obj = XEditorUndo:GetUndoRedoObject(obj_data.__undo_handle)
			if IsValid(obj) and obj:HasMember("PostLoad") then
				obj:PostLoad("undo")
			end
		end
	end
	Msg("EditorCallback", "EditorCallbackPlace", table.validate(newobjs), "undo")
	Msg("EditorCallback", "EditorCallbackDelete", table.validate(oldobjs), "undo")
	Msg("EditorCallback", "EditorCallbackMove", table.validate(movedobjs), "undo")
	DoneObjects(oldobjs)
end

---
--- Undoes the changes made by an ObjectsEditOp operation.
---
--- This function is responsible for restoring the state of objects that were created, deleted, or modified by the ObjectsEditOp. It handles the necessary callbacks and notifications to ensure the editor state is properly updated.
---
--- @return nil
---
function ObjectsEditOp:Undo()
	self:EditorCallbackPreUndoRedo()
	local newobjs = {}
	local oldobjs = {}
	local movedobjs = {}
	for _, obj_data in ipairs(self.data) do
		local op = obj_data.op
		local handle = obj_data.__undo_handle
		local obj = XEditorUndo:GetUndoRedoObject(handle)
		if op == "delete" then
			obj = XEditorPlaceObjectByClass(obj_data.class, obj)
			XEditorUndo:RestoreObject(obj, obj_data)
			newobjs[#newobjs + 1] = obj
		elseif op == "create" then
			XEditorUndo:UndoRedoHandleClear(handle)
			oldobjs[#oldobjs + 1] = obj
		else -- update
			XEditorUndo:RestoreObject(obj, obj_data, obj_data.after)
			if obj_data.after and obj_data.Pos ~= obj_data.after.Pos then
				movedobjs[#movedobjs + 1] = obj
			end
			ObjModified(obj)
		end
	end
	
	for _, obj_data in ipairs(self.data) do
		if obj_data.op ~= "create" then
			local obj = XEditorUndo:GetUndoRedoObject(obj_data.__undo_handle)
			if IsValid(obj) and obj:HasMember("PostLoad") then
				obj:PostLoad("undo")
			end
		end
	end
	Msg("EditorCallback", "EditorCallbackPlace", table.validate(newobjs), "undo")
	Msg("EditorCallback", "EditorCallbackDelete", table.validate(oldobjs), "undo")
	Msg("EditorCallback", "EditorCallbackMove", table.validate(movedobjs), "undo")
	DoneObjects(oldobjs)
end

---
--- Updates the hash values for the map data based on the data in the ObjectsEditOp.
---
--- This function calculates a hash value for the data in the ObjectsEditOp and updates the `mapdata.ObjectsHash` and `mapdata.NetHash` values accordingly. This is likely used to track changes to the map data for synchronization or other purposes.
---
--- @param self ObjectsEditOp The ObjectsEditOp instance.
--- @return nil
---
function ObjectsEditOp:UpdateMapHashes()
	local hash = table.hash(self.data)
	mapdata.ObjectsHash = xxhash(mapdata.ObjectsHash, hash)
	mapdata.NetHash = xxhash(mapdata.NetHash, hash)
end

DefineClass.SelectionEditOp = {
	__parents = { "EditOp" },
	before = false,
	after = false,
}

---
--- Initializes the `SelectionEditOp` object.
---
--- This function sets the `before` and `after` tables to empty tables. These tables are used to store the handles of the objects that were selected before and after an edit operation, respectively.
---
--- @function SelectionEditOp:Init
--- @return nil
function SelectionEditOp:Init()
	self.before = {}
	self.after = {}
end

---
--- Sets the editor's selection to the objects specified in the `after` table.
---
--- This function is part of the `SelectionEditOp` class, which is used to track changes to the editor's selection. When an undo operation is performed, this function is called to restore the selection to the state it was in before the edit operation.
---
--- @function SelectionEditOp:Do
--- @return nil
function SelectionEditOp:Do()
	editor.SetSel(table.map(self.after, function(handle) return XEditorUndo:GetUndoRedoObject(handle) end))
end

---
--- Restores the editor's selection to the state it was in before the edit operation.
---
--- This function is part of the `SelectionEditOp` class, which is used to track changes to the editor's selection. When an undo operation is performed, this function is called to restore the selection to the state it was in before the edit operation.
---
--- @function SelectionEditOp:Undo
--- @return nil
function SelectionEditOp:Undo()
	editor.SetSel(table.map(self.before, function(handle) return XEditorUndo:GetUndoRedoObject(handle) end))
end

DefineClass.GridEditOp = {
	__parents = { "EditOp" },
	name = false,
	before = false,
	after = false,
	box = false,
}

---
--- Applies the changes specified in the `GridEditOp` object to the editor's grid.
---
--- This function is part of the `GridEditOp` class, which is used to track changes to the editor's grid. When a grid edit operation is performed, this function is called to apply the changes to the grid.
---
--- For each change in the `GridEditOp` object, this function sets the grid value for the specified name (e.g. "height" or "terrain_type") and box. If the name is "height", it also sends a "EditorHeightChanged" message. If the name is "terrain_type", it sends an "EditorTerrainTypeChanged" message.
---
--- @function GridEditOp:Do
--- @return nil
function GridEditOp:Do()
	for _, change in ipairs(self) do
		editor.SetGrid(self.name, change.after, change.box)
		if self.name == "height" then
			Msg("EditorHeightChanged", true, change.box)
		end
		if self.name == "terrain_type" then
			Msg("EditorTerrainTypeChanged", change.box)
		end
	end
end

---
--- Restores the editor's grid to the state it was in before the edit operation.
---
--- This function is part of the `GridEditOp` class, which is used to track changes to the editor's grid. When an undo operation is performed, this function is called to restore the grid to the state it was in before the edit operation.
---
--- For each change in the `GridEditOp` object, this function sets the grid value for the specified name (e.g. "height" or "terrain_type") and box. If the name is "height", it also sends a "EditorHeightChanged" message. If the name is "terrain_type", it sends an "EditorTerrainTypeChanged" message.
---
--- @function GridEditOp:Undo
--- @return nil
function GridEditOp:Undo()
	for _, change in ipairs(self) do
		editor.SetGrid(self.name, change.before, change.box)
		if self.name == "height" then
			Msg("EditorHeightChanged", true, change.box)
		end
		if self.name == "terrain_type" then
			Msg("EditorTerrainTypeChanged", change.box)
		end
	end
end

---
--- Updates the terrain and network hashes for the changes made in the `GridEditOp`.
---
--- This function is called after the `GridEditOp:Do()` function is executed. It calculates the hash values for the terrain and network data based on the changes made in the `GridEditOp`.
---
--- If the `GridEditOp` contains changes to the "height" or "terrain_type" properties, this function iterates through the changes and calculates the hash values for the "TerrainHash" and "NetHash" properties of the `mapdata` table.
---
--- @function GridEditOp:UpdateMapHashes
--- @return nil
function GridEditOp:UpdateMapHashes()
	if self.name == "height" or self.name == "terrain_type" then
		for _, change in ipairs(self) do
			local hash = change.after:hash()
			mapdata.TerrainHash = xxhash(mapdata.TerrainHash, hash)
			mapdata.NetHash = xxhash(mapdata.NetHash, hash)
		end
	end
end


----- Serialization for copy/paste/duplicate

---
--- Serializes a collection of editor objects into a table that can be used for copy/paste/duplicate operations.
---
--- This function takes a list of editor objects and a root collection, and returns a table containing the serialized data for those objects. The serialized data includes the object class, properties, and other metadata needed to recreate the objects.
---
--- The function first makes a copy of the input objects, then adds any child and parent objects that are necessary for the copy/paste/duplicate operation. It then iterates through the objects, serializing each one and adding the serialized data to the `obj_data` table. If the object is a `Collection`, the `Index` property is set to -1 to force the creation of a new collection index when pasting. If the object is in the root collection or `XEditorSelectSingleObjects` is 1, the `CollectionIndex` property is set to `nil` to ignore the collection.
---
--- The serialized data is returned as a table with a single key-value pair, where the key is `"obj_data"` and the value is the table of serialized object data.
---
--- @param objs table A list of editor objects to serialize
--- @param root_collection table The root collection for the editor objects
--- @return table The serialized data for the editor objects
function XEditorSerialize(objs, root_collection)
	local obj_data = {}
	local org_count = #objs
	
	objs = table.copy(objs)
	add_child_objects(objs)
	add_parent_objects(objs, "for_copy", root_collection)
	table.remove_value(objs, root_collection)
	
	Msg("EditorPreSerialize", objs) -- some debug functionalities hook up here to clear temporary visualization properties
	PauseInfiniteLoopDetection("XEditorSerialize")
	for idx, obj in ipairs(objs) do
		local data = XEditorUndo:GetObjectData(obj)
		if obj.class == "Collection" then
			data.Index = -1 -- force creation of new collections indexes when pasting collections
		end
		if obj:GetCollection() == root_collection or XEditorSelectSingleObjects == 1 then
			data.CollectionIndex = nil -- ignore collection
		end
		data.__original_object = idx <= org_count or nil
		add_obj_data(obj_data, data)
	end
	ResumeInfiniteLoopDetection("XEditorSerialize")
	Msg("EditorPostSerialize", objs)
	return { obj_data = obj_data }
end

---
--- Deserializes a collection of editor objects from a serialized data table.
---
--- This function takes a serialized data table and a root collection, and returns a list of the deserialized editor objects. The serialized data includes the object class, properties, and other metadata needed to recreate the objects.
---
--- The function first creates a new list of objects, and then iterates through the serialized data, creating a new object for each entry and restoring its properties. If the object is not already in a collection, it is added to the root collection. After all objects are created, the function calls the `PostLoad` method on each object, which allows the objects to perform any additional setup or cleanup. Finally, the function triggers an `EditorCallback` event with the list of original objects.
---
--- The function returns the list of original objects that were deserialized.
---
--- @param data table The serialized data table containing the object data
--- @param root_collection table The root collection for the editor objects
--- @param ... any Additional arguments to pass to the `EditorCallback` event
--- @return table The list of deserialized editor objects
function XEditorDeserialize(data, root_collection, ...)
	EditorPasteInProgress = true
	PauseInfiniteLoopDetection("XEditorPaste")
	SuspendPassEditsForEditOp(data.obj_data)
	XEditorUndo:BeginOp()
	XEditorUndo.handle_remap = {} -- will force the creation of new objects when resolving handles
	
	local objs, orig_objs = {}, {}
	for _, obj_data in ipairs(data.obj_data) do
		local obj = XEditorUndo:GetUndoRedoObject(obj_data.__undo_handle)
		obj = XEditorPlaceObjectByClass(obj_data.class, obj)
		obj = XEditorUndo:RestoreObject(obj, obj_data)
		if root_collection and not obj:GetCollection() then
			obj:SetCollection(root_collection) -- paste in the currently locked collection
		end
		objs[#objs + 1] = obj
		if obj_data.__original_object then
			orig_objs[#orig_objs + 1] = obj
		end
	end
	
	-- call PostLoad; it sometimes deletes objects (e.g. wires if they are partially unattached)
	for _, obj in ipairs(objs) do
		if obj:HasMember("PostLoad") then
			obj:PostLoad("paste")
		end
	end
	Msg("EditorCallback", "EditorCallbackPlace", table.validate(table.copy(orig_objs)), ...)
	
	XEditorUndo:EndOp(table.validate(objs))
	ResumePassEditsForEditOp()
	ResumeInfiniteLoopDetection("XEditorPaste")
	EditorPasteInProgress = false
	return orig_objs
end

---
--- Converts the given data table into a Lua code string that can be copied to the clipboard.
---
--- The function takes a data table and returns a Lua code string that represents the data. The resulting string is prefixed with the `XEditorCopyScriptTag` string, which is used to identify the data as coming from the XEditor copy/paste functionality.
---
--- @param data table The data table to convert to a Lua code string
--- @return string The Lua code string representing the data
function XEditorToClipboardFormat(data)
	return ValueToLuaCode(data, nil, pstr(XEditorCopyScriptTag, 32768)):str()
end

---
--- Pastes the given Lua code string, which represents editor objects, into the editor.
---
--- The function takes a Lua code string that was previously generated by `XEditorToClipboardFormat()`. It decodes the Lua code string into a data table, and then uses `XEditorDeserialize()` to deserialize the editor objects and place them in the editor.
---
--- If the Lua code string is not valid or does not contain the expected data, an error message is printed and the function returns without performing any action.
---
--- @param lua_code string The Lua code string to paste into the editor
---
function XEditorPaste(lua_code)
	local err, data = LuaCodeToTuple(lua_code, LuaValueEnv{ GridReadStr = GridReadStr })
	if err or type(data) ~= "table" or not data.obj_data then
		print("Error restoring objects:", err)
		return
	end
	local fn = data.paste_fn or "Default"
	if not XEditorPasteFuncs[fn] then
		print("Error restoring objects: invalid paste function ", fn)
		return
	end
	procall(XEditorPasteFuncs[fn], data, lua_code, "paste")
end


----- Interface functions for copy/paste/duplicate

---
--- Pastes the given editor objects into the editor at the current cursor position.
---
--- This function is used as the default paste function for the XEditor copy/paste functionality. It deserializes the given data table, which contains the editor objects to be pasted, and places them in the editor at the current cursor position, offset by the pivot point of the copied objects.
---
--- @param data table The data table containing the editor objects to be pasted
--- @param lua_code string The Lua code string that was used to copy the objects
--- @param ... any Additional arguments passed to the paste function
---
function XEditorPasteFuncs.Default(data, lua_code, ...)
	XEditorUndo:BeginOp{ name = "Paste" }
	
	local objs = XEditorDeserialize(data, Collection.GetLockedCollection(), ...)
	local place = editor.GetPlacementPoint(GetTerrainCursor())
	local offs = (place:IsValidZ() and place or place:SetTerrainZ()) - data.pivot
	objs = XEditorSelectAndMoveObjects(objs, offs)
	
	XEditorUndo.current_op.name = string.format("Pasted %d objects", #objs)
	XEditorUndo:EndOp(objs)
end

---
--- Copies the currently selected editor objects to the clipboard in a format that can be pasted back into the editor.
---
--- This function serializes the currently selected editor objects into a Lua code string that can be pasted back into the editor using `XEditorPaste()`. The serialized data includes the object data as well as the pivot point of the selected objects.
---
--- The serialized data is copied to the system clipboard, so it can be pasted into the editor or other applications.
---
--- @return none
---
function XEditorCopyToClipboard()
	local objs = editor.GetSel("permanent")
	
	local data = XEditorSerialize(objs, Collection.GetLockedCollection())
	data.pivot = CenterPointOnBase(objs)
	CopyToClipboard(XEditorToClipboardFormat(data))
end

---
--- Pastes the contents of the clipboard into the editor if it contains a valid serialized editor object.
---
--- This function checks the clipboard for a valid serialized editor object, and if found, pastes it into the editor at the current cursor position.
---
--- @return none
---
function XEditorPasteFromClipboard()
	local lua_code = GetFromClipboard(-1)
	if lua_code:starts_with(XEditorCopyScriptTag) then
		XEditorPaste(lua_code)
	end
end

---
--- Clones the given editor objects and adds them to their current collection.
---
--- If the objects are from a single selected collection, and the number of objects is less than the total number of objects in that collection, the cloned objects will be added to the same collection.
---
--- @param objs table The editor objects to clone
--- @return table The cloned editor objects
---
function XEditorClone(objs)
	-- cloned objects from a single selected collection are added to their current collection, as per level designers request
	local locked_collection = Collection.GetLockedCollection()
	local single_collection = editor.GetSingleSelectedCollection(objs)
	if single_collection and #objs < MapCount("map", "collection", single_collection.Index, true) then
		locked_collection = single_collection
	end
	return XEditorDeserialize(XEditorSerialize(objs, locked_collection), locked_collection, "clone")
end


----- Map patches (storing and restoring map changes from their undo operations)

---
--- Called when a map save operation is completed.
--- This function updates the last saved undo index, so that future undo operations will not undo past the last saved state.
---
--- @return none
---
function OnMsg.SaveMapDone()
	XEditorUndo.last_save_undo_index = XEditorUndo.undo_index
end

local function redo_and_capture(name)
	local op = XEditorUndo.undo_queue[XEditorUndo.undo_index + 1]
	local affected = { name = name }
	for key in pairs(op) do
		if key ~= "name" then
			affected[key] = true
		end
	end
	if op.objects then
		affected.objects = op.objects:GetAffectedObjectsBefore() 
	end
	
	XEditorUndo:BeginOp(affected)
	XEditorUndo:UndoRedo("redo", IsChangingMap() and "update_map_hashes")
	XEditorUndo:EndOp(op.objects and op.objects:GetAffectedObjectsAfter())
end

-- TODO: Only save hash_to_handle information for handles that are actually referenced in the patch
local function create_combined_patch_edit_op()
	if XEditorUndo.undo_index <= XEditorUndo.last_save_undo_index then
		return {}
	end
	
	Msg("OnMapPatchBegin")
	SuspendPassEditsForEditOp()
	PauseInfiniteLoopDetection("XEditorCreateMapPatch")
	
	-- undo operations back to the last map save
	local undo_index = XEditorUndo.undo_index
	while XEditorUndo.undo_index ~= XEditorUndo.last_save_undo_index do
		XEditorUndo:UndoRedo("undo")
	end
	
	-- store object identifying information (for objects that are to be deleted or modified - all they have undo handles)
	local hash_to_handle = {}
	for handle, obj in pairs(XEditorUndo.handle_to_obj) do
		if IsValid(obj) then
			assert(not hash_to_handle[obj:GetObjIdentifier()]) -- hash collision, likely the data used to construct the hash is identical
			hash_to_handle[obj:GetObjIdentifier()] = handle
		end
	end
	
	-- redo all undo operations, collapsing them into a single one
	EditorUndoPreserveHandles = true
	XEditorUndo:BeginOp()
	
	for idx = XEditorUndo.undo_index, undo_index - 1 do
		assert(XEditorUndo.undo_index == idx)
		redo_and_capture()
	end
	ResumeInfiniteLoopDetection("XEditorCreateMapPatch")
	ResumePassEditsForEditOp()
	
	-- get and cleanup the combined operation
	local edit_op = XEditorUndo:EndOpInternal()
	local obj_datas = edit_op.objects and edit_op.objects.data or empty_table
	for idx, obj_data in ipairs(obj_datas) do
		local op, handle = obj_data.op, obj_data.__undo_handle
		if op == "delete" then
			obj_datas[idx] = { op = op, __undo_handle = handle }
		elseif op == "update" then
			local after = obj_data.after
			for k, v in pairs(after) do
				if not special_props[k] and CompareValues(obj_data[k], v) then
					after[k] = nil
				end
			end
			obj_datas[idx] = { op = op, __undo_handle = handle, after = obj_data.after }
		end
	end
	edit_op.hash_to_handle = hash_to_handle
	edit_op.selection = nil
	
	assert(XEditorUndo.undo_index == undo_index)
	EditorUndoPreserveHandles = false
	Msg("OnMapPatchEnd")
	
	return edit_op
end

---
--- Creates a map patch file containing the changes made in the editor.
---
--- @param filename string|nil The filename to save the map patch to. Defaults to "svnAssets/Bin/win32/Bin/map.patch".
--- @param add_to_svn boolean|nil Whether to add the patch file to the SVN repository.
--- @return table|nil The hashes of changed objects, the affected grid boxes, and a compacted list of the affected objects' bounding boxes.
---
function XEditorCreateMapPatch(filename, add_to_svn)
	local edit_op = create_combined_patch_edit_op()
	
	-- serialize this combined operation, along with the object identifiers
	local str = "return " .. ValueToLuaCode(edit_op, nil, pstr("", 32768)):str()
	filename = filename or "svnAssets/Bin/win32/Bin/map.patch"
	local path = SplitPath(filename)
	AsyncCreatePath(path)
	local err = AsyncStringToFile(filename, str)
	if err then
		print("Failed to write patch file", filename)
		return
	end
	if add_to_svn then
		SVNAddFile(path)
		SVNAddFile(filename)
	end
	
	local affected_grids = {}
	for _, grid in ipairs(editor.GetGridNames()) do
		if edit_op[grid] then
			affected_grids[grid] = edit_op[grid].box
		end
	end
	
	edit_op.compacted_obj_boxes = empty_table
	if edit_op.objects then
		local affected_objs = edit_op.objects:GetAffectedObjectsAfter()
		local obj_box_list = {}
		for _, obj in ipairs(affected_objs) do
			assert(IsValid(obj))
			if IsValid(obj) then
				table.insert(obj_box_list, obj:GetObjectBBox())
			end
		end
		edit_op.compacted_obj_boxes = CompactAABBList(obj_box_list, 4 * guim, "optimize_boxes")
	end
	
	-- return:
	--  - hashes of changed objects (newly created objects are not included), 
	--  - affected grid boxes
	--  - a compacted list of the affected objects' bounding boxes (updated and created objects)
	return (edit_op.hash_to_handle and table.keys(edit_op.hash_to_handle)), affected_grids, edit_op.compacted_obj_boxes
end

---
--- Applies a map patch file to the current editor state.
---
--- @param filename string|nil The filename of the map patch file to apply. Defaults to "svnAssets/Bin/win32/Bin/map.patch".
---
function XEditorApplyMapPatch(filename)
	filename = filename or "svnAssets/Bin/win32/Bin/map.patch"
	
	local func, err = loadfile(filename)
	if err then
		print("Failed to load patch", filename)
		return
	end
	
	local edit_op = func()
	if not next(edit_op) then return end
	
	Msg("OnMapPatchBegin")
	XEditorUndo.handle_remap = {} -- as with pasting, generate new undo handles for the objects from the patch
	EditorUndoPreserveHandles = true -- restore object handles that were stored in the patch
	
	-- lookup objects to be deleted/modified by their stored identifier hashes
	local hash_to_handle = edit_op.hash_to_handle
	MapForEach(true, "attached", false, function(obj)
		local hash = obj:GetObjIdentifier()
		local handle = hash_to_handle[hash]
		if handle then
			XEditorUndo:GetUndoRedoObject(handle, nil, obj) -- "assign" this object to the handle, via handle_remap
		end
	end)
	
	-- apply the changes via the "redo" mechanism
	XEditorUndo:AddEditOp(edit_op)
	XEditorUndo.undo_index = XEditorUndo.undo_index - 1
	redo_and_capture("Applied map patch")
	
	-- remove the added edit op and readjust the undo index
	table.remove(XEditorUndo.undo_queue, XEditorUndo.undo_index - 1)
	XEditorUndo.undo_index = XEditorUndo.undo_index - 1
	
	EditorUndoPreserveHandles = false
	MapPatchesApplied = true
	Msg("OnMapPatchEnd")
end


----- Misc

---
--- Centers the given objects on the terrain base.
---
--- @param objs table<number, Object> The objects to center.
--- @return point The new center point of the objects.
---
function CenterPointOnBase(objs)
	local minz
	for _, obj in ipairs(objs) do
		local pos = obj:GetVisualPos()
		local z = Max(terrain.GetHeight(pos), pos:z())
		if not minz or minz > z then
			minz = z
		end
	end
	return CenterOfMasses(objs):SetZ(minz)
end

---
--- Selects and moves the given objects by the specified offset.
---
--- If the objects are aligned, the offset is snapped to a whole number of voxels
--- so that auto-snapped objects don't get displaced.
---
--- @param objs table<number, Object> The objects to select and move.
--- @param offs point The offset to move the objects by.
--- @return table<number, Object> The moved objects.
---
function XEditorSelectAndMoveObjects(objs, offs)
	editor.SetSel(objs)
	SuspendPassEditsForEditOp()
	objs = editor.SelectionCollapseChildObjects()
	if const.SlabSizeX and HasAlignedObjs(objs) then -- snap offset to a whole number of voxels, so auto-snapped object don't get displaced
		local x = offs:x() / const.SlabSizeX * const.SlabSizeX
		local y = offs:y() / const.SlabSizeY * const.SlabSizeY
		local z = offs:z() and (offs:z() + const.SlabSizeZ / 2) / const.SlabSizeZ * const.SlabSizeZ or 0
		offs = point(x, y, z)
	end
	for _, obj in ipairs(objs) do
		if obj:IsKindOf("AlignedObj") then
			obj:AlignObj(obj:GetPos() + offs)
		elseif obj:IsValidPos() then
			obj:SetPos(obj:GetPos() + offs)
		end
	end
	Msg("EditorCallback", "EditorCallbackMove", objs)
	ResumePassEditsForEditOp()
	return objs
end

-- Makes sure that if a parent object (as per GetEditorParentObject) is in the input list,
-- then all children objects are in the output, and vice versa. Used by XAreaCopyTool.
---
--- Propagates the parent and child objects of the given objects.
---
--- This function ensures that if a parent object is in the input list,
--- then all its child objects are also in the output list, and vice versa.
--- This is useful for operations that need to work on a complete hierarchy
--- of objects, such as copy/paste or move.
---
--- @param objs table<number, Object> The objects to propagate.
--- @return table<number, Object> The propagated objects.
---
function XEditorPropagateParentAndChildObjects(objs)
	add_parent_objects(objs)
	add_child_objects(objs)
	return objs
end

---
--- Propagates the child objects of the given objects.
---
--- This function ensures that all child objects of the given objects are included in the output list.
--- This is useful for operations that need to work on a complete hierarchy of objects, such as copy/paste or move.
---
--- @param objs table<number, Object> The objects to propagate.
--- @return table<number, Object> The propagated objects.
---
function XEditorPropagateChildObjects(objs)
	add_child_objects(objs)
	return objs
end

---
--- Collapses the child objects of the given objects.
---
--- This function ensures that if a child object is in the input list,
--- then its parent object is also included in the output list.
--- This is useful for operations that need to work on a complete hierarchy
--- of objects, such as copy/paste or move.
---
--- @param objs table<number, Object> The objects to collapse.
--- @return table<number, Object> The collapsed objects.
---
function XEditorCollapseChildObjects(objs)
	local objset = {}
	for _, obj in ipairs(objs) do
		objset[obj] = true
	end
	
	local i, count = 1, #objs
	while i <= count do
		local obj = objs[i]
		if objset[obj:GetEditorParentObject()] then
			objs[i] = objs[count]
			objs[count] = nil
			count = count - 1
		else
			i = i + 1
		end
	end
	return objs
end
