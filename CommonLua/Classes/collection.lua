local max_collection_idx = const.GameObjectMaxCollectionIndex
local GetCollectionIndex = CObject.GetCollectionIndex

MapVar("Collections", {})
MapVar("CollectionsByName", {})
MapVar("g_ShowCollectionLimitWarning", true)

DefineClass.Collection = {
	__parents = { "Object" },
	flags = { efWalkable = false, efApplyToGrids = false, efCollision = false },
	
	properties = {
		category = "Collection",
		{ id = "Name", editor = "text", default = "", },
		{ id = "Index", editor = "number", default = 0, min = 0, max = max_collection_idx, read_only = true, },
		{ id = "Locked", editor = "bool", default = false, dont_save = true, },
		{ id = "ParentName", name = "Parent", editor = "text", default = "", read_only = true, dont_save = true, },
		{ id = "Type", editor = "text", default = "", read_only = true, },
		{ id = "HideFromCamera", editor = "bool", default = false, help = "Makes collection use HideTop system to hide from camera regardless of the presence of HideTop objects within it or the objects' position relative to the playable area."},
		{ id = "DontHideFromCamera", editor = "bool", default = false, help = "If true, HideTop objects in this collection will be ignored. HideFromCamera will override this."},
		{ id = "HandleCount", name = "Handles Count", editor = "number", default = 0, read_only = true, dont_save = true, },
		{ id = "Graft", name = "Change parent", editor = "dropdownlist", default = "",
			items = function(self)
				local names = GetCollectionNames()
				if self.Name ~= "" then
					table.remove_entry(names, self.Name)
				end
				return names
			end,
			buttons = { { name = "Set", func = "SetParentButton" } },
			dont_save = true,
		},
	},
	
	-- non-editor stubs
	UpdateLocked = empty_func,
	SetLocked = empty_func,
}

-- hide unnused properties from CObject
for i = 1, #CObject.properties do
	local prop = table.copy(CObject.properties[i])
	prop.no_edit = true
	table.insert(Collection.properties, prop)
end

-- property getters ----------------------------------

---
--- Returns the name of the parent collection of the current collection.
---
--- @return string The name of the parent collection, or an empty string if the collection has no parent.
function Collection:GetParentName()
	local parent = self:GetCollection()
	return parent and parent.Name or ""
end

------------------------------------------------------

if Platform.developer then
	---
 --- Sets the collection index of the current collection.
 ---
 --- @param new_index number The new index to set for the collection.
 --- @return boolean, string Whether the operation was successful, and an optional error message.
 function Collection:SetCollectionIndex(new_index)
 	-- Check if the new index is the same as the current index
 	if new_index and new_index ~= 0 and self.Index and self.Index ~= 0 then
 		if new_index == self.Index then
 			return false, "[Collection] The parent index is the same!"
 		end
 		
 		-- Check if the new parent is a child of the current collection
 		local parent = Collections[new_index]
 		if parent and parent:GetCollectionRelation(self.Index) then
 			return false, "[Collection] The parent is a child!"
 		end
 	end
 	
 	-- Set the new collection index
 	return CObject.SetCollectionIndex(self, new_index)
 end

end

---
--- Returns a unique identifier for the collection.
---
--- @return number The unique identifier for the collection.
function Collection:GetObjIdentifier()
	return xxhash(self.Name, self.Index)
end

---
--- Returns the number of attached objects and the total number of reserved handles for the collection.
---
--- @return number, number The total number of reserved handles and the total number of attached objects for the collection.
function Collection:GetHandleCount()
	local pool = 0
	local count = 0
	MapForEach("map", "attached", false, "collection", self.Index, true, "Object", function(obj)
		pool = pool + 1 + obj.reserved_handles
		count = count + 1
	end)
	return pool, count
end

---
--- Sets the index of the collection.
---
--- @param new_index number The new index to set for the collection.
--- @return boolean Whether the operation was successful.
function Collection:SetIndex(new_index)
	new_index = new_index or 0
	local old_index = self.Index
	local collections = Collections
	if old_index ~= new_index or not collections[old_index] then
		if new_index ~= 0 then
			-- Check if we're creating a new collection or loading an existing one on map load
			if collections[new_index] or new_index < 0 or new_index > max_collection_idx then
				new_index = AsyncRand(max_collection_idx) + 1
				
				local loop_index = new_index
				while collections[new_index] do
					new_index = new_index + 1
					if new_index == loop_index then
						break
					elseif new_index > max_collection_idx then
						new_index = 1 -- circle around after the last index
					end
				end
			end
			
			if not IsChangingMap() then
				if collections[new_index] then -- no free index was found
					CreateMessageBox(
						terminal.desktop,
						Untranslated("Error"),
						Untranslated("Collection not created - collection limit exceeded!")
					)
					return false
				end
				
				-- If there are less than 10% free collection indexes => display a warning
				if g_ShowCollectionLimitWarning then
					local collections_count = #table.keys(collections) + 1 -- account for the new collection
					if collections_count >= MulDivRound(max_collection_idx, 90, 100) then
						CreateMessageBox(
							terminal.desktop,
							Untranslated("Warning"),
							Untranslated(string.format("There are %d collections on this map, approaching the limit of %d.", collections_count, max_collection_idx))
						)
						g_ShowCollectionLimitWarning = false -- disable the warning until next map (re)load
					end
				end
			end
			
			collections[new_index] = self
		end
		
		if old_index ~= 0 and collections[old_index] == self then
			self:SetLocked(false)
			local parent_index = new_index ~= 0 and new_index or GetCollectionIndex(self)
			MapForEach(true, "collection", old_index, function(o, idx) o:SetCollectionIndex(idx) end, parent_index)
			collections[old_index] = nil
		end
		
		self.Index = new_index
		Collection.UpdateLocked()
	end
	return true
end

---
--- Returns the root collection index for the given collection index.
---
--- If the given collection index is not the locked collection index, this function
--- will traverse up the collection hierarchy until it finds the root collection
--- index, which is the locked collection index or 0 if no locked collection exists.
---
--- @param col_idx number The collection index to find the root for.
--- @return number The root collection index.
---
function Collection.GetRoot(col_idx)
	if col_idx and col_idx ~= 0 then
		local locked_idx = editor.GetLockedCollectionIdx()
		if col_idx ~= locked_idx then
			local collections = Collections
			while true do
				local col_obj = collections[col_idx]
				if not col_obj then
					assert(false, "Root collection error")
					return 0
				end
				local parent_idx = GetCollectionIndex(col_obj)
				if not parent_idx or parent_idx == 0 or parent_idx == locked_idx then
					break
				end
				col_idx = parent_idx
			end
		end
	end
	return col_idx
end

---
--- Initializes the collection object by setting the game object flag to permanent.
---
--- This function is called during the initialization of a collection object to mark it as a
--- permanent game object that should not be destroyed when the game state changes.
---
--- @param self Collection The collection object being initialized.
---
function Collection:Init()
	self:SetGameFlags(const.gofPermanent)
end

---
--- Marks the collection object as done and removes it from the collection index and name lookup.
---
--- This function is called when the collection object is no longer needed and should be
--- removed from the game state. It removes the collection from the collection index and
--- name lookup, allowing the object to be garbage collected.
---
--- @param self Collection The collection object being marked as done.
---
function Collection:Done()
	self:SetIndex(false)
	self:SetName(false)
end

---
--- Sets the name of the collection object.
---
--- This function is used to set the name of a collection object. It ensures that the name is unique
--- within the collection name lookup table (`CollectionsByName`). If the new name is already in use,
--- it will automatically generate a new unique name by appending a numeric suffix.
---
--- @param self Collection The collection object whose name is being set.
--- @param new_name string The new name to be set for the collection object.
--- @return string The final name that was set for the collection object.
---
function Collection:SetName(new_name)
	new_name = new_name or ""
	local old_name = self.Name
	local CollectionsByName = CollectionsByName
	if old_name ~= new_name or not CollectionsByName[old_name] then
		CollectionsByName[old_name] = nil
		if new_name ~= "" then
			local orig_prefix, new_name_idx
			while CollectionsByName[new_name] do
				if not orig_prefix then
					-- Check if the name ends with a number
					local idx = string.find(new_name, "_%d+$")
					-- The old name with unique incremented index
					orig_prefix = idx and string.sub(new_name, 1, idx - 1) or new_name
					new_name_idx = idx and tonumber(string.sub(new_name, idx + 1)) or 0
				end
				new_name_idx = new_name_idx + 1
				new_name = string.format("%s_%d", orig_prefix , new_name_idx)
			end
			CollectionsByName[new_name] = self
		end
		self.Name = new_name
	end
	return new_name
end

---
--- Sets the collection for the current object.
---
--- If the given collection is the locked collection, the object's index is added to the locked collection index.
--- Otherwise, the object's collection is set to the given collection.
---
--- @param self Collection The collection object.
--- @param collection Collection The new collection to set for the object.
---
function Collection:SetCollection(collection)
	if collection and collection.Index == editor.GetLockedCollectionIdx() then
		editor.AddToLockedCollectionIdx(self.Index)
	end
	CObject.SetCollection(self, collection)
end

---
--- Called when a property of the editor is set.
---
--- This function is called when a property of the editor is set. It updates the tree in the editor to reflect the changes.
---
--- @param self Collection The collection object.
--- @param prop_id number The ID of the property that was set.
--- @param old_value any The old value of the property.
--- @param ged table The GED (Graphical Editor) object that triggered the property change.
---
function Collection:OnEditorSetProperty(prop_id, old_value, ged)
	ged:ResolveObj("root"):UpdateTree()
end

---
--- Creates a new collection object.
---
--- This function creates a new collection object with the given name, index, and optional object. If the index is not provided, it will be set to -1. If a name is provided, it will be set as the name of the collection. The function will then update the collections editor and return the new collection object.
---
--- @param name string (optional) The name of the new collection.
--- @param idx number (optional) The index of the new collection. If not provided, it will be set to -1.
--- @param obj table (optional) The object to associate with the new collection.
--- @return Collection The new collection object.
---
function Collection.Create(name, idx, obj)
	idx = idx or -1
	local col = Collection:new(obj)
	if col:SetIndex(idx) then
		if name then
			col:SetName(name)
		end
		UpdateCollectionsEditor()
		return col
	end
	DoneObject(col)
end

---
--- Checks if the collection is empty.
---
--- @param self Collection The collection object.
--- @param permanents boolean (optional) If true, only permanent objects are counted. If false or not provided, all objects are counted.
--- @return boolean True if the collection is empty, false otherwise.
---
function Collection:IsEmpty(permanents)
	return MapCount("map", "collection", self.Index, true, nil, nil, permanents and const.gofPermanent or nil ) == 0
end

local function RemoveTempObjects(objects)
	for i = #(objects or ""), 1, -1 do
		local obj = objects[i]
		if obj:GetGameFlags(const.gofPermanent) == 0 or obj:GetParent() then
			table.remove(objects, i)
		end
	end
end

---
--- Collects the given objects into a new collection, or moves them to an existing collection.
---
--- If the objects all belong to the same root collection, they are moved to that collection's locked collection.
--- If the objects belong to multiple root collections, a new collection is created and the objects are added to it.
--- If the root collection of the objects is empty after the objects are removed, the root collection is destroyed.
---
--- @param objects table The objects to be collected.
--- @return boolean False if the operation was cancelled, true otherwise.
---
function Collection.Collect(objects)
	local uncollect = true
	local trunk
	local locked = Collection.GetLockedCollection()
	objects = objects or empty_table
	RemoveTempObjects(objects)
	if #objects > 0 then
		trunk = objects[1]:GetRootCollection()
		for i = 2, #objects do
			if trunk ~= objects[i]:GetRootCollection() then
				uncollect = false
				break
			end
		end
	end
	if trunk and trunk ~= locked and uncollect then
		local op_name = string.format("Removed %d objects from collection", #objects)
		table.insert(objects, trunk) -- add 'trunk' collection to the list of affected objects, as it could be deleted
		XEditorUndo:BeginOp{ objects = objects, name = op_name }
		for i = 1, #objects - 1 do
			objects[i]:SetCollection(locked)
		end
		if trunk:IsEmpty() then
			print("Destroyed collection: " .. trunk.Name)
			table.remove(objects) -- 'trunk' is at the last index
			Msg("EditorCallback", "EditorCallbackDelete", { trunk })
			DoneObject(trunk)
		else
			print(op_name .. ":" .. trunk.Name)
		end
		XEditorUndo:EndOp(objects)
		UpdateCollectionsEditor()
		return false
	end
	
	local col = Collection.Create()
	if not col then
		return false
	end
	
	XEditorUndo:BeginOp{ objects = objects, name = "Created collection" }
	
	col:SetCollection(locked)
	local classes = false
	if #objects > 0 then
		classes = {}
		local obj_to_add = {}
		for i = 1, #objects do
			local obj = objects[i]
			classes[obj.class] = (classes[obj.class] or 0) + 1
			while true do
				local obj_col = obj:GetCollection()
				if not obj_col or obj_col == locked then
					break
				end
				obj = obj_col
			end
			obj_to_add[obj] = true
		end
		for obj in pairs(obj_to_add) do
			obj:SetCollection(col)
		end
		table.insert(objects, col)
		UpdateCollectionsEditor()
	end
	
	local name = false
	if classes then
		local max = 0
		for class, count in pairs(classes) do
			if max < count then
				max = count
				name = class
			end
		end
	end
	col:SetName("col_" .. (name or col.Index))
	
	XEditorUndo:EndOp(objects)
	
	print("Collection created: " .. col.Name)
	return col
end

---
--- Adds the currently selected objects to the specified collection.
---
--- This function first removes any temporary objects from the selection, then
--- determines the destination collection for the selected objects. If the
--- selected objects belong to different collections, the function will use the
--- first non-locked collection found as the destination.
---
--- The function then performs an undo operation to add the selected objects to
--- the destination collection, and updates the collections editor to reflect
--- the changes.
---
--- @param none
--- @return none
function Collection.AddToCollection()
	local sel = editor.GetSel()
	RemoveTempObjects(sel)
	local locked_col = Collection.GetLockedCollection()
	local dest_col
	local objects = {}
	for i = 1, #sel do
		local col = sel[i] and sel[i]:GetRootCollection()
		if col and col ~= locked_col then
			objects[col] = true
			dest_col = col
		else
			objects[sel[i]] = true
		end
	end
	if dest_col then
		XEditorUndo:BeginOp{ objects = sel, name = string.format("Added %d objects to collection", #sel) }
		for obj in pairs(objects) do
			if obj ~= dest_col then
				obj:SetCollection(dest_col)
			end
		end
		XEditorUndo:EndOp(sel)
		UpdateCollectionsEditor()
		print("Collection modified: " .. dest_col.Name)
	end
end

---
--- Gets the full path of a collection, starting from the root collection.
---
--- @param idx number The index of the collection to get the path for.
--- @return string The full path of the collection.
function Collection.GetPath(idx)
	local path = {}
	while idx ~= 0 do
		local collection = Collections[idx]
		if not collection then
			break
		end
		table.insert(path, 1, collection.Name)
		idx = GetCollectionIndex(collection)
	end
	return table.concat(path, '/')
end

---
--- Gets the save path for a collection by its name.
---
--- @param name string The name of the collection.
--- @return string The save path for the collection.
function GetSavePath(name)
	return string.format("data/collections/%s.lua", name)
end


local function DoneSilent(col)
	Collections[col.Index] = nil
	col.Index = 0
	DoneObject(col)
end

local function add_obj(obj, list)
	local col = obj:GetCollection()
	if not col then
		return
	end
	local objs = list[col]
	if objs then
		objs[#objs + 1] = obj
	else
		list[col] = {obj}
	end
end

local function GatherCollectionsEnum(obj, cols, is_deleted)
	local col_idx = GetCollectionIndex(obj)
	if col_idx ~= 0 and not is_deleted[obj] then
		cols[col_idx] = true
	end
end

---
--- Destroys all empty collections in the game.
---
--- This function is called when an editor operation ends, and it will remove any collections that have no objects associated with them.
---
--- It first gathers all the collections that have objects, and then removes any collections that have no objects and are not the parent of any other collections.
---
--- @param remove_invalid boolean (optional) If true, the function will completely remove the empty collections. If false, it will just set the collection to be inactive.
--- @param min_objs_per_col number (optional) The minimum number of objects required for a collection to be considered valid. Default is 1.
---
function Collection.DestroyEmpty()
	local to_delete, is_deleted = {}, {}
	local work_done
	repeat
		local cols = {}
		MapForEach(true, "collected", true, GatherCollectionsEnum, cols, is_deleted)
		work_done = false
		for index, col in pairs(Collections) do
			if not is_deleted[col] and not cols[index] then
				table.insert(to_delete, col)
				is_deleted[col] = true
				work_done = true
			end
		end
	until not work_done
	
	XEditorUndo:BeginOp{ objects = to_delete, name = "Deleted empty collections" }
	Msg("EditorCallback", "EditorCallbackDelete", to_delete)
	DoneObjects(to_delete)
	XEditorUndo:EndOp()
end

-- cleanup empty collections after every operation
OnMsg.EditorObjectOperationEnding = Collection.DestroyEmpty

-- returns all collections containing objects and remove the rest if specified
---
--- Returns a list of valid collections, optionally removing invalid collections.
---
--- This function first gathers all collections and their associated objects, then removes any collections that have no objects and are not the parent of any other collections.
---
--- @param remove_invalid boolean (optional) If true, the function will completely remove the empty collections. If false, it will just set the collection to be inactive.
--- @param min_objs_per_col number (optional) The minimum number of objects required for a collection to be considered valid. Default is 1.
--- @return table The list of valid collections
--- @return number The number of collections removed
---
function Collection.GetValid(remove_invalid, min_objs_per_col)
	min_objs_per_col = min_objs_per_col or 1
	local colls = {}
	local col_to_subs = {}
	MapForEach("detached" , "Collection", function(obj)
		colls[#colls + 1] = obj
		add_obj(obj, col_to_subs)
	end)
	local col_to_objs = {}
	MapForEach("map", "attached", false, "collected", true, "CObject", function(obj)
		add_obj(obj, col_to_objs)
	end)
	local count0 = #colls
	while true do
		local ready = true
		for i = #colls,1,-1 do
			local col = colls[i]
			local objects = col_to_objs[col] or ""
			if #objects == 0 then
				local subs = col_to_subs[col] or ""
				if #subs < 2 then
					ready = false
					local parent_idx = GetCollectionIndex(col) or 0
					for j=1,#subs do
						subs[j]:SetCollectionIndex(parent_idx)
					end
					local parent_subs = parent_idx and col_to_subs[parent_idx]
					if parent_subs then
						table.remove_value(parent_subs, col)
						table.iappend(parent_subs, subs)
					end
					col_to_subs[col] = nil
					table.remove(colls, i)
					if remove_invalid then
						DoneSilent(col)
					else
						col:SetCollection(false)
					end
				end
			end
		end
		if ready then
			break
		end
	end
	for col, objs in pairs(col_to_objs) do
		local subs = col_to_subs[col] or ""
		if #subs > 0 then
			assert(#objs > 0, "Invalid collection detected")
		elseif #objs < min_objs_per_col then
			local parent_idx = GetCollectionIndex(col) or 0
			for i=1,#objs do
				objs[i]:SetCollectionIndex(parent_idx)
			end
			table.remove_entry(colls, col)
			if remove_invalid then
				DoneSilent(col)
			else
				col:SetCollection(false)
			end
		end
	end
	UpdateCollectionsEditor()
	return colls, count0 - #colls
end


-- remove all nested collections on the map (max_cols is 0 by default, which means remove all collections from the map)
---
--- Removes all nested collections on the map.
---
--- @param max_cols number|nil The maximum number of nested collections to remove. If not provided, all nested collections will be removed.
--- @return number The number of collections that were removed.
function Collection.RemoveAll(max_cols)
	max_cols = max_cols or 0
	local removed = 0
	if max_cols > 0 then
		local map = {}
		MapForEach("map", "CObject", function(obj)
			local levels = 0
			local col = obj:GetCollection()
			if not col then
				return
			end
			local new_col = map[col]
			if new_col == nil then
				local cols = {col}
				local col_i = col
				while true do
					col_i = col_i:GetCollection()
					if not col_i then
						break
					end
					cols[#cols + 1] = col_i
					assert(#cols < 100)
				end
				new_col = #cols > max_cols and cols[#cols - max_cols + 1]
				map[col] = new_col
			end
			if new_col then
				obj:SetCollection(new_col)
			end
		end)
		for col, new_col in pairs(map) do
			if new_col then
				DoneSilent(col)
				removed = removed + 1
			end
		end
		MapForEach("detached", "Collection", function(col)
			if map[col] == nil then
				DoneSilent(col)
				removed = removed + 1
			end
		end)
	else
		MapForEach("map", "CObject", function(obj)
			obj:SetCollectionIndex(0)
		end	)
		MapForEach("detached", "Collection", function(col)
			DoneSilent(col)
			removed = removed + 1
		end)
	end
	UpdateCollectionsEditor()
	return removed
end

-- remove all contained objects including those in nested collections
---
--- Destroys a collection and removes all objects contained within it, including those in nested collections.
---
--- @param center Vector3 The center position to use for deleting objects within a radius.
--- @param radius number The radius around the center position to use for deleting objects.
---
function Collection:Destroy(center, radius)
	local idx = self.Index
	if idx ~= 0 then
		SuspendPassEdits(self)
		if center and radius then
			MapDelete(center, radius, "attached", false, "collection", idx, true)
		else
			MapDelete("map", "attached", false, "collection", idx, true)
		end
		for _, col in pairs(Collections) do
			if col:GetCollectionRelation(idx) then
				DoneSilent(col)
			end
		end
		ResumePassEdits(self)
	end
	DoneSilent(self)
	UpdateCollectionsEditor()
end

UpdateCollectionsEditor = empty_func