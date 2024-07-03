DefineClass.XDeleteObjectsTool = {
	__parents = { "XEditorBrushTool", "XEditorObjectPalette" },
	properties = {
		{ id = "buttons", editor = "buttons", default = false, buttons = {{name = "Clear selected objects", func = "ClearSelection"}} },
	},
	
	ToolTitle = "Delete objects",
	Description = {
		"(<style GedHighlight>hold Ctrl</style> to delete objects on a select terrain)",
	},
	ActionSortKey = "07",
	ActionIcon = "CommonAssets/UI/Editor/Tools/DeleteObjects.tga", 
	ActionShortcut = "D",
	
	deleted_objects = false,
	start_terrain = false,
}

---
--- Starts the drawing process for the delete objects tool.
--- This function is called when the tool is activated and the user starts drawing.
---
--- It suspends pass edits to the editor, initializes a table to track deleted objects,
--- and determines if the user is holding the Ctrl key to delete objects on a specific terrain type.
---
--- @param pt Vector3 The starting point of the drawing
---
function XDeleteObjectsTool:StartDraw(pt)
	SuspendPassEdits("XEditorDeleteObjects")
	self.deleted_objects = {}
	self.start_terrain = terminal.IsKeyPressed(const.vkControl) and terrain.GetTerrainType(pt)
end

---
--- Draws the delete objects tool on the editor canvas.
---
--- This function is called when the delete objects tool is active and the user is drawing on the canvas.
--- It iterates through the selected object classes and deletes any visible, permanent objects that are within the cursor radius.
--- If the user is holding the Ctrl key, it only deletes objects on the same terrain type as the starting point of the drawing.
---
--- @param pt1 Vector3 The starting point of the drawing
--- @param pt2 Vector3 The ending point of the drawing
---
function XDeleteObjectsTool:Draw(pt1, pt2)
	local classes = self:GetObjectClass()
	local radius = self:GetCursorRadius()
	local callback = function(o) 
		if not self.deleted_objects[o] and XEditorFilters:IsVisible(o) and o:GetGameFlags(const.gofPermanent) ~= 0 then
			if not self.start_terrain or terrain.GetTerrainType(o:GetPos()) == self.start_terrain then
				self.deleted_objects[o] = true
				o:ClearEnumFlags(const.efVisible)
			end
		end 
	end
	if #classes > 0 then
		for _, class in ipairs(classes) do
			MapForEach(pt1, pt2, radius, class, callback)
		end
	else
		MapForEach(pt1, pt2, radius, callback)
	end
end

---
--- Ends the drawing process for the delete objects tool.
--- This function is called when the user finishes drawing with the delete objects tool.
---
--- It restores the visibility of any deleted objects, creates an undo operation for the deleted objects,
--- sends a callback to notify other systems of the deleted objects, and then deletes the objects.
--- Finally, it resumes pass edits to the editor and resets the deleted objects table.
---
--- @param pt Vector3 The ending point of the drawing
---
function XDeleteObjectsTool:EndDraw(pt)
	if next(self.deleted_objects) then
		local objs = table.validate(table.keys(self.deleted_objects))
		for _, obj in ipairs(objs) do obj:SetEnumFlags(const.efVisible) end
		XEditorUndo:BeginOp({ objects = objs, name = string.format("Deleted %d objects", #objs) })
		Msg("EditorCallback", "EditorCallbackDelete", objs)
		for _, obj in ipairs(objs) do obj:delete() end
		XEditorUndo:EndOp()
	end
	ResumePassEdits("XEditorDeleteObjects")
	self.deleted_objects = false
end

---
--- Returns the cursor radius for the delete objects tool.
---
--- @return number The X radius of the cursor
--- @return number The Y radius of the cursor
---
function XDeleteObjectsTool:GetCursorRadius()
	local radius = self:GetSize() / 2
	return radius, radius
end

---
--- Clears the selection of the XDeleteObjectsTool.
--- This function sets the object class to an empty table and notifies that the object has been modified.
---
function XDeleteObjectsTool:ClearSelection()
	self:SetObjectClass({})
	ObjModified(self)
end
