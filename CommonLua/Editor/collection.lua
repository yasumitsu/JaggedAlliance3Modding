local unavailable_msg = "Not available in game mode! Retry in the editor!"

---
--- Returns whether the collection is currently locked.
---
--- @return boolean locked Whether the collection is locked.
function Collection:GetLocked()
	return self.Index == editor.GetLockedCollectionIdx()
end

---
--- Sets the locked state of the collection.
---
--- @param locked boolean Whether to lock the collection.
function Collection:SetLocked(locked)
	local idx = self.Index
	if idx == 0 then
		return
	end
	local prev_locked = self:GetLocked()
	if locked and prev_locked or not locked and not prev_locked then
		return
	end
	Collection.UnlockAll()
	if prev_locked then
		return
	end
	editor.ClearSel()
	editor.SetLockedCollectionIdx(idx)
	MapSetGameFlags(const.gofWhiteColored, "map", "CObject")
	MapForEach("map", "collection", idx, true, function(o) o:ClearHierarchyGameFlags(const.gofWhiteColored) end)
end

---
--- Returns the currently locked collection.
---
--- @return table|nil locked_collection The currently locked collection, or nil if no collection is locked.
function Collection.GetLockedCollection()
	local locked_idx = editor.GetLockedCollectionIdx()
	return locked_idx ~= 0 and Collections[locked_idx]
end

---
--- Unlocks all collections in the editor.
---
--- @return boolean success Whether the unlock operation was successful.
function Collection.UnlockAll()
	if editor.GetLockedCollectionIdx() == 0 then
		return false
	end
	editor.SetLockedCollectionIdx(0)
	MapClearGameFlags(const.gofWhiteColored, "map", "CObject")
	return true
end

-- clone the collections in the given group of objects
---
--- Duplicates the given objects and their associated collections.
---
--- @param objects table The objects to duplicate.
--- @return table The duplicated objects.
function Collection.Duplicate(objects)
	local duplicated = {}
	local collections = {}
	-- clone and assign collections:
	local locked_idx = editor.GetLockedCollectionIdx()
	for i = 1, #objects do
		local obj = objects[i]
		if IsValid(obj) then
			local col = obj:GetCollection()
			if not col then
				obj:SetCollectionIndex(locked_idx)
			elseif col.Index ~= locked_idx then
				local new_col = duplicated[col]
				if not new_col then
					new_col = col:Clone()
					duplicated[col] = new_col
					collections[#collections + 1] = col
				end
				obj:SetCollection(new_col)
			else
				obj:SetCollection(col)
			end
		end
	end
	
	-- fix collection hierarchy
	local i = #collections
	while i > 0 do
		local col = collections[i]
		local new_col = duplicated[col]
		local parent = col:GetCollection()
		i = i - 1
		
		if parent and parent.Index ~= locked_idx then
			local new_parent = duplicated[parent]
			if not duplicated[parent] then
				new_parent = parent:Clone()
				duplicated[parent] = new_parent
				i = i + 1
				collections[i] = parent
			end
			new_col:SetCollection(new_parent)
		else
			new_col:SetCollectionIndex(locked_idx)
		end
	end
	
	UpdateCollectionsEditor()
end

---
--- Updates the locked collection index in the editor.
--- This function is used to update the locked collection index, which is used to keep track of the currently selected collection in the editor.
---
--- @function Collection.UpdateLocked
--- @return nil
function Collection.UpdateLocked()
	editor.SetLockedCollectionIdx(editor.GetLockedCollectionIdx())
end

---
--- Resets the locked collection index in the editor when a new map is created.
---
--- This function is called when a new map is created, and it sets the locked collection index to 0.
--- The locked collection index is used to keep track of the currently selected collection in the editor.
---
--- @function OnMsg.NewMap
--- @return nil
function OnMsg.NewMap()
	editor.SetLockedCollectionIdx(0)
end

----

DefineClass.CollectionContent = {
	__parents = { "PropertyObject" },
	properties = {},
	col = false,
	children = false,
	objects = false,

	EditorView = Untranslated("<Name> <style GedConsole><color 0 255 200><Index></color></style>"),
}

---
--- Returns the children of the CollectionContent object.
---
--- @return table The children of the CollectionContent object.
function CollectionContent:GedTreeChildren()
	return self.children
end

---
--- Returns the name of the CollectionContent object.
---
--- If the CollectionContent object has a non-empty name, it is returned. Otherwise, "[Unnamed]" is returned.
---
--- @function CollectionContent:GetName
--- @return string The name of the CollectionContent object.
function CollectionContent:GetName()
	local name = self.col.Name
	return #name > 0 and name or "[Unnamed]"
end

--- Returns the index of the CollectionContent object.
---
--- If the index is greater than 0, it is returned. Otherwise, an empty string is returned.
---
--- @function CollectionContent:GetIndex
--- @return string The index of the CollectionContent object.
function CollectionContent:GetIndex()
	local index = self.col.Index
	return index > 0 and index or ""
end

---
--- Selects the CollectionContent object in the editor.
---
--- This function traverses the hierarchy of CollectionContent objects to find the path to the current object, and then sets the selection in the editor to that path.
---
--- @function CollectionContent:SelectInEditor
--- @return nil
function CollectionContent:SelectInEditor()
	local ged = GetCollectionsEditor()
	if not ged then
		return
	end

	local root = ged:ResolveObj("root")

	local path = {}
	local iter = self
	while iter and iter ~= root do
		local parent_idx = iter.col:GetCollectionIndex()
		if parent_idx and parent_idx > 0 then
			local parent = root.collection_to_gedrepresentation[Collections[parent_idx]]
			table.insert(path, 1, table.find(parent.children, iter))
			iter = parent
		else
			table.insert(path, 1, table.find(root, iter))
			break
		end
	end
	ged:SetSelection("root", path)
end


--- Handles the selection of a CollectionContent object in the editor.
---
--- When the CollectionContent object is selected, this function binds the object's properties to the editor's UI panels, and selects the object in the editor's hierarchy.
---
--- If the selection is the initial selection when the editor is first opened, the camera will not be moved to show the selected object in the editor.
---
--- @param selected boolean Whether the CollectionContent object is selected or not.
--- @param ged table The CollectionEditor object.
--- @return nil
function CollectionContent:OnEditorSelect(selected, ged)
	local is_initial_selection = not ged:ResolveObj("CollectionObjects")
	
	if selected then
		ged:BindObj("CollectionObjects", self.objects) -- for idObjects panel
		ged:BindObj("SelectedObject", self.col) -- for idProperties panel
	end

	if not IsEditorActive() then
		return
	end
	if selected then
		-- If this is the initial selection (when the editor is first opened) => don't move the camera
		ged:ResolveObj("root"):Select(self, not is_initial_selection and "show_in_editor")
	end
end


---
--- Unlocks all collections in the editor.
---
--- This function is called when the "Unlock All" action is triggered in the editor. It unlocks all collections, allowing the user to modify them.
---
--- @function CollectionContent:ActionUnlockAll
--- @return nil
function CollectionContent:ActionUnlockAll()
	if not IsEditorActive() then
		print(unavailable_msg)
		return
	end
	Collection.UnlockAll()
end

----

DefineClass.CollectionRoot = {
	__parents = { "InitDone" },

	collection_to_gedrepresentation = false,
	selected_col = false,
}

---
--- Handles various operations on the collection editor, such as creating a new collection, deleting a collection, locking/unlocking collections, and collecting/uncollecting objects.
---
--- @param ged table The CollectionEditor object.
--- @param name string The name of the operation to perform.
--- @return nil
function GedCollectionEditorOp(ged, name)
	if not IsEditorActive() then
		print(unavailable_msg)
		return
	end
	
	local gedcol = ged:ResolveObj("SelectedCollection")
	local root = ged:ResolveObj("root")
	local col = gedcol and gedcol.col
	local col_to_select = false
	
	if not col then
		return
	end
	
	if name == "new" then
		Collection.Collect()
	elseif name == "delete" then
		-- Prepare next collection to be selected in the editor
		local root_index = table.find(root, gedcol) or 0
		local nextColContent = root[root_index + 1]
		if nextColContent and nextColContent:GetIndex() ~= 0 then
			col_to_select = Collections[nextColContent:GetIndex()]
		end
		col:Destroy()
	elseif name == "lock" then
		col:SetLocked(true)
	elseif name == "unlock" then
		Collection.UnlockAll()
	elseif name == "collect" then
		col_to_select = Collection.Collect(editor.GetSel())
	elseif name == "uncollect" then
		DoneObject(col)
	elseif name == "view" then
		if gedcol and gedcol.objects then
			ViewObjects(gedcol.objects)
		end
	end
	root:UpdateTree()
	
	if root.collection_to_gedrepresentation and col_to_select then
		-- Select a new collection in the editor
		local gedrepr = root.collection_to_gedrepresentation[col_to_select]
		if gedrepr then
			gedrepr:SelectInEditor()
		end
	end
end

--- Selects a collection in the editor and locks its parent collection if necessary.
---
--- @param obj CollectionContent The collection content object to select.
--- @param show_in_editor boolean If true, the selected collection's objects will be shown in the editor.
function CollectionRoot:Select(obj, show_in_editor)
	if not IsEditorActive() or self.selected_collection == obj.col then
		return
	end

	local col = obj.col
	if not col:GetLocked() then
		local parent = col:GetCollection()
		if parent then
			parent:SetLocked(true)
		else
			Collection.UnlockAll()
		end
	end
	
	if show_in_editor then
		local col_objects = MapGet("map", "attached", false, "collection", col.Index)
		editor.ChangeSelWithUndoRedo(col_objects, "dont_notify")
		ViewObjects(col_objects)
	end
	
	self.selected_collection = obj.col
end

--- Initializes the CollectionRoot object and updates the tree of collections.
---
--- This function is called to initialize the CollectionRoot object and update the tree of collections
--- displayed in the editor. It calls the UpdateTree() method to populate the tree with the current
--- collections and their associated objects.
function CollectionRoot:Init()
	self:UpdateTree()
end
--- Selects a plain collection in the editor.
---
--- @param col Collection The collection to select.
function CollectionRoot:SelectPlainCollection(col)
	local obj = self.collection_to_gedrepresentation[col]
	if obj then
		self.selected_collection = obj.col
		obj:SelectInEditor()
	end
end

--- Updates the tree of collections displayed in the editor.
---
--- This function is responsible for populating the tree of collections and their associated objects
--- in the editor. It retrieves the current collections from the `Collections` table, and for each
--- collection, it creates a `CollectionContent` object that represents the collection and its
--- associated objects. The function then organizes the collections into a tree structure based on
--- their parent-child relationships, and updates the `collection_to_gedrepresentation` table to
--- map each collection to its corresponding `CollectionContent` object.
---
--- @return nil
function CollectionRoot:UpdateTree()
	table.iclear(self)
	if not Collections then
		return
	end
	self.collection_to_gedrepresentation = {}
	local collection_to_children = {}
	local col_to_objs = {}
	MapForEach("map", "attached", false, "collected", true, function(obj, col_to_objs)
		local idx = obj:GetCollectionIndex()
		col_to_objs[idx] = table.create_add(col_to_objs[idx], obj)
	end, col_to_objs)
	local count = 0
	for col_idx, col_obj in sorted_pairs(Collections) do
		local objects = col_to_objs[col_idx] or {}
		table.sortby_field(objects, "class")
		collection_to_children[col_obj.Index] = collection_to_children[col_obj.Index] or {}
		local children = collection_to_children[col_obj.Index]
		local gedrepr = CollectionContent:new({col = col_obj, objects = objects, children = children})
		self.collection_to_gedrepresentation[col_obj] = gedrepr

		local parent_index = col_obj:GetCollectionIndex()
		if parent_index > 0 then
			collection_to_children[parent_index] = collection_to_children[parent_index] or {}
			table.insert(collection_to_children[parent_index], gedrepr)
		else
			count = count + 1
			self[count] = gedrepr
		end
	end
	table.sort(self, function(a, b) a, b = a.col.Name, b.col.Name return #a > 0 and #b == 0 or #a > 0 and a < b end)
	ObjModified(self)
end

--- Handles the "EditorCallbackPlace" event, which is triggered when the editor performs a placement operation.
---
--- This function is responsible for updating the collections editor when the editor performs a placement operation.
---
--- @param id string The ID of the editor callback event.
function OnMsg.EditorCallback(id)
	if id == "EditorCallbackPlace" then
		UpdateCollectionsEditor()
	end
end

local openingCollectionEditor = false
---
--- Opens the Collections Editor and selects the specified collection.
---
--- This function is responsible for opening the Collections Editor and selecting a specific collection.
--- It deals with the case where the Collections Editor is already open and ensures that the specified
--- collection is selected.
---
--- @param obj table The object whose root collection should be selected in the Collections Editor.
function OpenCollectionEditorAndSelectCollection(obj)
	if openingCollectionEditor then return end
	openingCollectionEditor = true -- deal with multi selection and multiple calls from the button
	CreateRealTimeThread(function()
		local col = obj and obj:GetRootCollection()
		if not col then
			return
		end
		local ged = GetCollectionsEditor()
		if not ged then
			OpenCollectionsEditor(col)
			while not ged do
				Sleep(100)
				ged = GetCollectionsEditor()
			end
		end
		
		openingCollectionEditor = false
	end)
end

function OnMsg.EditorSelectionChanged(objects)
	local ged = GetCollectionsEditor()
	if not ged then
		return
	end
	local col = objects and objects[1] and objects[1]:GetRootCollection()
	if not col then return end

	local root = ged:ResolveObj("root")
	root:SelectPlainCollection(col)
end

local function get_auto_selected_collection()
	-- is the editor selection a single collection?
	local count, collections = editor.GetSelUniqueCollections()
	if count == 1 then
		return next(collections)
	end
	
	return Collection.GetLockedCollection()
end

--- Opens the Collections Editor and selects the specified collection.
---
--- This function is responsible for opening the Collections Editor and selecting a specific collection.
--- It deals with the case where the Collections Editor is already open and ensures that the specified
--- collection is selected.
---
--- @param collection_to_select table|nil The collection to select in the Collections Editor. If not provided, the first collection in the editor will be selected.
--- @return table|nil The Collections Editor instance, or nil if it could not be opened.
function OpenCollectionsEditor(collection_to_select)
	local ged = GetCollectionsEditor()
	if not ged then
		collection_to_select = collection_to_select or get_auto_selected_collection()
		
		CreateRealTimeThread(function()
			ged = OpenGedApp("GedCollectionsEditor", CollectionRoot:new{}) or false
			
			while not ged do
				Sleep(100)
				ged = GetCollectionsEditor()
			end
			
			local root = ged:ResolveObj("root")
			
			if collection_to_select then
				-- Wait for the initial GedPanel selection to finish (to call OnEditorSelect()) to avoid an infinite selection loop
				Sleep(100)
				root:SelectPlainCollection(collection_to_select)
				return
			end
			
			local firstColContent = root and root[1]
			local select_col = collection_to_select or (root and root[1])
			
			-- Select the first collection in the editor
			if firstColContent and firstColContent:GetIndex() ~= 0 then
				local firstCollection = Collections[firstColContent:GetIndex()]
				root:SelectPlainCollection(firstCollection)
			end
		end)
	end
	return ged
end

--- Gets the Collections Editor instance.
---
--- This function searches for the Collections Editor instance among the GedConnections
--- and returns it if found. The Collections Editor is identified by the "CollectionRoot"
--- object in the "root" of the GedConnections.
---
--- @return table|nil The Collections Editor instance, or nil if it could not be found.
function GetCollectionsEditor()
	for id, ged in pairs(GedConnections) do
		if IsKindOf(ged:ResolveObj("root"), "CollectionRoot") then
			return ged
		end
	end
end

---
--- Updates the Collections Editor with the latest changes.
---
--- This function is responsible for updating the Collections Editor with any changes that have been made to the collections. It first checks if a Collections Editor instance is available, and if so, it retrieves the root object of the editor and calls the `UpdateTree()` method to update the tree view.
---
--- If no Collections Editor instance is available, the function will attempt to retrieve one using the `GetCollectionsEditor()` function, and then call itself again after a short delay using `DelayedCall()`.
---
--- @param ged table|nil The Collections Editor instance, or `nil` if it could not be found.
---
function UpdateCollectionsEditor(ged)
	if ged then
		local root = ged:ResolveObj("root")
		if root then
			root:UpdateTree()
		end
	else
		ged = GetCollectionsEditor()
		if ged then
			DelayedCall(0, UpdateCollectionsEditor, ged)
		end
	end
end

---
--- Sets the parent button for the current collection.
---
--- If the `Graft` property of the collection is not empty, the function will attempt to find the collection with the name specified in `Graft` and set it as the parent of the current collection. If the parent collection is found, the function will check if the current collection is not already a child of the parent collection, to avoid creating a circular reference.
---
--- If the `Graft` property is empty or the parent collection cannot be found, the function will set the collection index to 0, effectively making the collection a top-level collection.
---
--- After setting the parent collection, the function will call `UpdateCollectionsEditor()` to update the Collections Editor with the latest changes.
---
--- @param _ any Unused parameter.
--- @param __ any Unused parameter.
--- @param ged table The Collections Editor instance.
function Collection:SetParentButton(_, __, ged)
	local parent = self.Graft ~= "" and CollectionsByName[ self.Graft ]
	if parent then
		local col = parent.Index
		while true do
			if col == 0 then break end
			if col == self.Index then
				printf("Can't set %s as parent, because it is a child of %s", self.Graft, self.Name)
				return
			end
			col = Collections[col]:GetCollectionIndex()
		end
		self:SetCollectionIndex( parent.Index )
	else
		self:SetCollectionIndex(0)
	end
	UpdateCollectionsEditor(ged)
end