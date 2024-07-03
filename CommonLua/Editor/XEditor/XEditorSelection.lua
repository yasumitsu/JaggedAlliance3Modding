if FirstLoad then
	XEditorSelection = {}
	XEditorSelectSingleObjects = 0
end

---
--- Returns the first valid object in the XEditorSelection table.
---
--- @return table|nil The first valid object in the XEditorSelection table, or nil if none are valid.
function selo()
	for _, obj in ipairs(XEditorSelection) do
		if IsValid(obj) then return obj end
	end
end

---
--- Returns a table containing all selected objects in the editor.
---
--- @param permanent_only boolean If true, only return objects that are marked as permanent.
--- @return table The selected objects.
function editor.GetSel(permanent_only)
	local sel = {}
	for _, obj in ipairs(XEditorSelection) do
		if IsValid(obj) and (not permanent_only or obj:GetGameFlags(const.gofPermanent) ~= 0) then sel[#sel + 1] = obj end
	end
	return sel
end

---
--- Checks if the given object is currently selected in the editor.
---
--- @param obj table The object to check.
--- @return boolean True if the object is selected, false otherwise.
function editor.IsSelected(obj)
	return IsValid(obj) and obj:GetGameFlags(const.gofEditorSelection) ~= 0
end

---
--- Returns the number of unique collections represented in the current editor selection, and a table of those collections.
---
--- @return number The number of unique collections in the selection.
--- @return table The unique collections in the selection.
function editor.GetSelUniqueCollections()
	local collections, count = {}, 0
	for _, obj in ipairs(XEditorSelection) do
		if IsValid(obj) then
			local col = obj:GetRootCollection()
			if col and not collections[col] then
				collections[col] = true
				count = count + 1
			end
		end
	end
	return count, collections
end

-- Removes all child objects (as per GetEditorParentObject) for which the parent is also in the selection;
-- this makes sure that e.g. move works properly, as the parent will also move child objects
---
--- Removes all child objects (as per GetEditorParentObject) for which the parent is also in the selection.
--- This ensures that operations like move work properly, as the parent will also move child objects.
---
--- @return table The updated selection, with child objects removed.
function editor.SelectionCollapseChildObjects()
	local objs = XEditorSelection
	local i, count = 1, #objs
	while i <= count do
		local obj = objs[i]
		if editor.IsSelected(obj:GetEditorParentObject()) then
			obj:ClearHierarchyGameFlags(const.gofEditorSelection)
			objs[i] = objs[count]
			objs[count] = nil
			count = count - 1
		else
			i = i + 1
		end
	end
	return objs
end

---
--- Notifies the editor that the selection has changed.
---
--- @param dont_notify boolean If true, the notification will be skipped.
function editor.SelectionChanged(dont_notify)
	if not dont_notify then
		editor.SelectionCollapseChildObjects()
		Msg("EditorSelectionChanged", editor.GetSel())
	end
end

---
--- Clears the editor selection.
---
--- @param dont_notify boolean If true, the selection changed notification will be skipped.
function editor.ClearSel(dont_notify)
	if #XEditorSelection == 0 then
		return
	end
	for _, obj in ipairs(XEditorSelection) do
		if IsValid(obj) and obj:GetGameFlags(const.gofEditorSelection) ~= 0 then
			obj:ClearHierarchyGameFlags(const.gofEditorSelection | const.gofRealTimeAnim)
		end
	end
	XEditorSelection = {}
	editor.SelectionChanged(dont_notify)
end

---
--- Adds an object to the editor selection.
---
--- @param obj table The object to add to the selection.
--- @param dont_notify boolean If true, the selection changed notification will be skipped.
--- @param force boolean If true, the object will be added to the selection even if it is already selected.
---
function editor.AddObjToSel(obj, dont_notify, force)
	if force or IsValid(obj) and obj:GetGameFlags(const.gofEditorSelection) == 0 then
		obj:SetHierarchyGameFlags(const.gofEditorSelection)
		table.insert(XEditorSelection, obj)
		editor.SelectionChanged(dont_notify)
	end
end

---
--- Removes an object from the editor selection.
---
--- @param obj table The object to remove from the selection.
--- @param dont_notify boolean If true, the selection changed notification will be skipped.
--- @param force boolean If true, the object will be removed from the selection even if it is not selected.
---
function editor.RemoveObjFromSel(obj, dont_notify, force)
	if force or IsValid(obj) and obj:GetGameFlags(const.gofEditorSelection) ~= 0 then
		if table.remove_value(XEditorSelection, obj) then
			obj:ClearHierarchyGameFlags(const.gofEditorSelection)
			editor.SelectionChanged(dont_notify)
		end
	end
end

---
--- Adds one or more objects to the editor selection.
---
--- @param ol table The objects to add to the selection.
--- @param dont_notify boolean If true, the selection changed notification will be skipped.
---
function editor.AddToSel(ol, dont_notify)
	if #(ol or "") == 0 then
		return
	end
	local flags = const.gofEditorSelection
	for _, obj in ipairs(ol) do
		if IsValid(obj) and obj:GetGameFlags(flags) == 0 then
			obj:SetHierarchyGameFlags(const.gofEditorSelection)
			table.insert(XEditorSelection, obj)
		end
	end
	editor.SelectionChanged(dont_notify)
end

---
--- Removes one or more objects from the editor selection.
---
--- @param ol table The objects to remove from the selection.
--- @param to_remove table (optional) A table of objects to remove, where the keys are the objects and the values are booleans indicating whether the object should be removed.
---
function editor.RemoveFromSel(ol, to_remove)
	if #XEditorSelection == 0 then
		return
	end
	
	to_remove = to_remove or {}
	local flags = const.gofEditorSelection
	for _, obj in ipairs(ol) do
		to_remove[obj] = not IsValid(obj) or obj:GetGameFlags(flags) ~= 0
	end
	
	if next(to_remove) then
		local new_sel = {}
		for _, obj in ipairs(XEditorSelection) do
			if not to_remove[obj] then
				new_sel[#new_sel + 1] = obj
			elseif IsValid(obj) then
				obj:ClearHierarchyGameFlags(flags)
			end
		end
		XEditorSelection = new_sel
		editor.SelectionChanged()
	end
end

---
--- Changes the editor selection with undo/redo support.
---
--- @param sel table The new selection.
--- @param dont_notify boolean If true, the selection changed notification will be skipped.
---
function editor.ChangeSelWithUndoRedo(sel, dont_notify)
	XEditorUndo:BeginOp()
	editor.SetSel(sel, dont_notify)
	XEditorUndo:EndOp()
end

---
--- Sets the editor selection with undo/redo support.
---
--- @param sel table The new selection.
--- @param dont_notify boolean If true, the selection changed notification will be skipped.
---
function editor.SetSel(sel, dont_notify)
	if #sel == 0 then
		editor.ClearSel(dont_notify)
		return
	end
	if #XEditorSelection == 0 then
		editor.AddToSel(sel, dont_notify)
		return
	end
	if table.equal_values(sel, XEditorSelection) then
		return
	end
	local flags = const.gofEditorSelection
	local prev_sel = table.validate(XEditorSelection)
	for _, obj in ipairs(prev_sel) do
		obj:ClearHierarchyGameFlags(flags)
	end
	local new_sel = {}
	for _, obj in ipairs(sel) do
		if IsValid(obj) and obj:GetGameFlags(flags) == 0 then
			obj:SetHierarchyGameFlags(flags)
			table.insert(new_sel, obj)
		end
	end
	XEditorSelection = new_sel
	editor.SelectionChanged(dont_notify)
end

---
--- Deletes the current editor selection with undo/redo support.
---
--- This function first gets the current selection, then begins an undo operation and suspends pass edits. It then sends an "EditorCallbackDelete" message with the selected objects, deletes each object, clears the selection, and resumes pass edits. Finally, it ends the undo operation.
---
--- @param none
--- @return none
---
function editor.DelSelWithUndoRedo()
	local sel = editor.GetSel()
	if #sel == 0 then return end
	XEditorUndo:BeginOp{ objects = sel, name = string.format("Deleted %d objects", #sel) }
	SuspendPassEditsForEditOp()
	Msg("EditorCallback", "EditorCallbackDelete", sel)
	for _, obj in ipairs(sel) do obj:delete() end
	editor.ClearSel()
	ResumePassEditsForEditOp()
	XEditorUndo:EndOp()
end

---
--- Clears the current editor selection with undo/redo support.
---
--- This function first begins an undo operation, then clears the current selection, and finally ends the undo operation.
---
--- @param none
--- @return none
---
function editor.ClearSelWithUndoRedo()
	XEditorUndo:BeginOp()
	editor.ClearSel()
	XEditorUndo:EndOp()
end

---
--- Mirrors the current editor selection.
---
--- This function first gets the positions of all selected objects, then calculates the pivot point as the average of all positions. It then iterates through the selected objects again, toggling the mirrored state of each object and adjusting its position based on the pivot point.
---
--- @param sel table The current editor selection.
--- @return none
---
function editor.MirrorSel(sel)
	local positions = {}
	for _, obj in ipairs(sel) do
		if IsValid(obj) then 
			table.insert(positions, obj:GetPos())
		end
	end
	if #positions == 0 then return end
	
	local pivot = point(0, 0, 0)
	for _, pos in ipairs(positions) do pivot = pivot + pos end
	pivot = pivot / #positions
	for _, obj in ipairs(sel) do
		if IsValid(obj) then
			obj:SetMirrored(obj:GetGameFlags(const.gofMirrored) == 0)
			local newPos = obj:GetPos()
			local distToPivot = pivot - newPos
			
			newPos = newPos:SetY(pivot:y() + distToPivot:y())
			obj:SetPos(newPos)
		end
	end
end

---
--- Checks if all objects in the current editor selection are of the specified class.
---
--- @param class string The class to check against.
--- @return boolean True if all selected objects are of the specified class, false otherwise.
---
function editor.IsSelectionKindOf(class)
	local has_objs
	for _, obj in ipairs(XEditorSelection) do
		if IsValid(obj) then
			if not obj:IsKindOf(class) then
				return false
			end
			has_objs = true
		end
	end
	return has_objs
end
