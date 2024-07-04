-- dummy placement helper for the default "Select" mode
DefineClass.XPlaceObjectsHelper = {
	__parents = { "XEditorPlacementHelper" },

	InXPlaceObjectTool = true,
	AllowRotationAfterPlacement = true,
	HasSnapSetting = true,
	Title = "Place objects (N)",
	ActionIcon = "CommonAssets/UI/Editor/Tools/SelectObjects.tga",
	ActionShortcut = "N",
}

DefineClass.XPlaceObjectTool = {
	__parents = { "XEditorObjectPalette", "XEditorPlacementHelperHost" },

	ToolTitle = "Place single object",
	Description = {
		"(drag after placement to rotate object)",
	},
	ActionSortKey = "05",
	ActionIcon = "CommonAssets/UI/Editor/Tools/PlaceSingleObject.tga", 
	ActionShortcut = "N",
	
	helper_class = "XPlaceObjectsHelper",
	ui_state = "none", -- "none" - no object attached to cursor, "cursor" - dragging an object to place, "rotate" - dragging with LMB held to rotate
	cursor_object = false,
	objects = false, -- stores cursor_object in a table to pass to placement helpers and undo operations
	feedback_line = false,
}

---
--- Initializes the XPlaceObjectTool by creating a cursor object.
---
--- This function is called when the XPlaceObjectTool is first created. It creates a cursor object that can be used to represent the object being placed by the tool.
---
--- @function [parent=XPlaceObjectTool] Init
--- @return nil
function XPlaceObjectTool:Init()
	self:CreateCursorObject()
end

---
--- Finalizes the pending operation and deletes the cursor object.
---
--- This function is called when the XPlaceObjectTool is done with its operation. It sets the mouse capture back to the desktop and deletes the cursor object that was used to represent the object being placed.
---
--- @function [parent=XPlaceObjectTool] Done
--- @return nil
function XPlaceObjectTool:Done()
	self.desktop:SetMouseCapture() -- finalize pending operation
	self:DeleteCursorObject()
end

---
--- Handles changes to the ObjectClass or Category properties of the XPlaceObjectTool.
---
--- When the ObjectClass or Category property is changed, this function creates a new cursor object to represent the object being placed.
---
--- @param prop_id string The property that was changed, either "ObjectClass" or "Category".
--- @param ... any Additional arguments passed to the function.
--- @return nil
function XPlaceObjectTool:OnEditorSetProperty(prop_id, ...)
	if prop_id == "ObjectClass" or prop_id == "Category" then
		self:CreateCursorObject()
	end
	XEditorObjectPalette.OnEditorSetProperty(self, prop_id, ...)
end

---
--- Creates a cursor object for the placement helper.
---
--- This function is called to create a cursor object that represents the object being placed by the placement helper. The cursor object is used to provide visual feedback to the user during the placement process.
---
--- @function [parent=XEditorPlacementHelperHost] UpdatePlacementHelper
--- @return nil
function XEditorPlacementHelperHost:UpdatePlacementHelper()
	self:CreateCursorObject()
end

---
--- Creates a cursor object for the placement helper.
---
--- This function is called to create a cursor object that represents the object being placed by the placement helper. The cursor object is used to provide visual feedback to the user during the placement process.
---
--- @param id string|nil The ID of the object to create the cursor for. If not provided, a random object from the current ObjectClass will be used.
--- @return CObject|nil The created cursor object, or nil if the creation failed.
function XPlaceObjectTool:CreateCursorObject(id)
	self:DeleteCursorObject()
	id = id or table.rand(self:GetObjectClass())
	if id then
		local obj = XEditorPlaceObject(id, "cursor_object")
		if obj then
			obj:SetHierarchyEnumFlags(const.efVisible)
			obj:ClearHierarchyEnumFlags(const.efCollision + const.efWalkable + const.efApplyToGrids)
			EditorCursorObjs[obj] = true -- excludes the object from being processed in certain cases
			obj:SetCollection(Collections[editor.GetLockedCollectionIdx()])
			self.cursor_object = obj
			self.objects = { self.cursor_object }
			self.ui_state = "cursor"
			self:UpdateCursorObject()
			assert(not self.placement_helper.operation_started)
			self.placement_helper:StartOperation(terminal.GetMousePos(), self.objects)
			Msg("EditorCallback", "EditorCallbackPlaceCursor", table.copy(self.objects))
			return obj
		end
	end
end

---
--- Updates the cursor object to match the current placement point.
---
--- This function is called to update the position and orientation of the cursor object to match the current placement point. The cursor object is used to provide visual feedback to the user during the placement process.
---
--- @param self XPlaceObjectTool The instance of the XPlaceObjectTool class.
--- @return nil
function XPlaceObjectTool:UpdateCursorObject()
	XEditorSnapPos(self.cursor_object, editor.GetPlacementPoint(GetTerrainCursor()), point30)
end

---
--- Places the cursor object as a permanent game object.
---
--- This function is called to finalize the placement of the cursor object as a permanent game object. It restores the hierarchy enum flags, sets the game flags, adds the object to the editor selection, and either allows rotation of the object after placement or finalizes the placement.
---
--- @param self XPlaceObjectTool The instance of the XPlaceObjectTool class.
--- @return nil
function XPlaceObjectTool:PlaceCursorObject()
	local obj = self.cursor_object
	obj:RestoreHierarchyEnumFlags() -- will rebuild surfaces if required
	obj:SetHierarchyEnumFlags(const.efVisible)
	EditorCursorObjs[obj] = nil
	obj:SetGameFlags(const.gofPermanent)
	
	XEditorUndo:BeginOp{ name = "Placed 1 object" }
	editor.AddToSel(obj)
	
	if self.placement_helper.AllowRotationAfterPlacement then
		self.desktop:SetMouseCapture(self)
		ForceHideMouseCursor("XPlaceObjectTool")
		SuspendPassEdits("XPlaceObjectTool")
		self.ui_state = "rotate"
	else
		self:FinalizePlacement()
	end
end

---
--- Finalizes the placement of the cursor object as a permanent game object.
---
--- This function is called to finalize the placement of the cursor object as a permanent game object. It ends the current operation, adds the placed objects to the editor selection, and creates a new cursor object for further placement.
---
--- @param self XPlaceObjectTool The instance of the XPlaceObjectTool class.
--- @return nil
function XPlaceObjectTool:FinalizePlacement()
	XEditorUndo:EndOp(self.objects)
	Msg("EditorCallback", "EditorCallbackPlace", table.copy(self.objects))
	self.cursor_object = nil
	self:CreateCursorObject()
end

---
--- Deletes the cursor object and cleans up the state of the XPlaceObjectTool.
---
--- This function is called to delete the cursor object and reset the state of the XPlaceObjectTool. It first ends any ongoing placement operation, then deletes the cursor object, and finally resets the state of the tool.
---
--- @param self XPlaceObjectTool The instance of the XPlaceObjectTool class.
--- @return nil
function XPlaceObjectTool:DeleteCursorObject()
	if self.placement_helper.operation_started then
		self.placement_helper:EndOperation(self.objects)
	end
	local obj = self.cursor_object
	if obj then
		-- use pcall, as some objects involed in gameplay will crash when created/deleted from the editor
		local ok = pcall(obj.delete, self.cursor_object)
		if not ok and IsValid(obj) then -- a Done method failed, at least delete the C object
			CObject.delete(obj)
		end
		self.cursor_object = nil
	end
	self.objects = nil
	self.ui_state = "none"
end


----- Mouse behavior - rotate object after placement

---
--- Handles the mouse button down event for the XPlaceObjectTool.
---
--- This function is called when the user presses the left mouse button while the tool is in the "cursor" state. It ends the current placement operation, places the cursor object, and returns "break" to indicate that the event has been handled.
---
--- @param self XPlaceObjectTool The instance of the XPlaceObjectTool class.
--- @param pt Vector3 The position of the mouse cursor.
--- @param button string The mouse button that was pressed.
--- @return string "break" if the event was handled, otherwise the result of calling the parent class's OnMouseButtonDown method.
function XPlaceObjectTool:OnMouseButtonDown(pt, button)
	if button == "L" and self.ui_state == "cursor" then
		assert(self.placement_helper.operation_started)
		self.placement_helper:EndOperation(self.objects)
		self:PlaceCursorObject()
		return "break"
	end
	return XEditorTool.OnMouseButtonDown(self, pt, button)
end

---
--- Handles the mouse position event for the XPlaceObjectTool.
---
--- This function is called when the user moves the mouse while the tool is active. It performs different actions depending on the current UI state of the tool:
---
--- - If the UI state is "cursor", it updates the cursor object or performs the current placement operation.
--- - If the UI state is "rotate", it calculates the new rotation angle for the cursor object based on the mouse position and creates a feedback line to visualize the rotation.
--- - If the UI state is neither "cursor" nor "rotate", it calls the parent class's OnMousePos method.
---
--- @param self XPlaceObjectTool The instance of the XPlaceObjectTool class.
--- @param pt Vector3 The current position of the mouse cursor.
--- @param button string The mouse button that is currently pressed (if any).
--- @return string "break" if the event was handled, otherwise the result of calling the parent class's OnMousePos method.
function XPlaceObjectTool:OnMousePos(pt, button)
	XEditorRemoveFocusFromToolbars()
	
	if self.ui_state == "cursor" then
		if self.helper_class == "XPlaceObjectsHelper" then
			self:UpdateCursorObject()
		else
			assert(self.placement_helper.operation_started)
			self.placement_helper:PerformOperation(pt, self.objects)
		end
		return "break"
	elseif self.ui_state == "rotate" then
		local obj = self.cursor_object
		local pt1, pt2 = obj:GetPos(), GetTerrainCursor()
		if pt1:Dist2D(pt2) > 10 * guic then
			local angle = XEditorSettings:AngleSnap(CalcOrientation(pt2, pt1))
			XEditorSetPosAxisAngle(obj, pt1, obj:GetAxis(), angle)
			self:CreateFeedbackLine(pt1, pt2)
		end
		return "break"
	end
	return XEditorTool.OnMousePos(self, pt, button)
end

---
--- Handles the mouse button up event for the XPlaceObjectTool.
---
--- This function is called when the user releases the mouse button while the tool is active. It performs different actions depending on the current UI state of the tool:
---
--- - If the UI state is "rotate" and the left mouse button was released, it releases the mouse capture, which will call the OnCaptureLost function.
--- - Otherwise, it calls the parent class's OnMouseButtonUp method.
---
--- @param self XPlaceObjectTool The instance of the XPlaceObjectTool class.
--- @param pt Vector3 The current position of the mouse cursor.
--- @param button string The mouse button that was released.
--- @return string "break" if the event was handled, otherwise the result of calling the parent class's OnMouseButtonUp method.
function XPlaceObjectTool:OnMouseButtonUp(pt, button)
	if button == "L" and self.ui_state == "rotate" then
		self.desktop:SetMouseCapture() -- will call OnCaptureLost
		return "break"
	end
	return XEditorTool.OnMouseButtonUp(self, pt, button)
end

---
--- Called when the mouse capture is lost for the XPlaceObjectTool.
---
--- This function performs the following actions:
--- - Deletes the feedback line used for visual feedback during placement.
--- - Unforces the mouse cursor to be hidden.
--- - Resumes pass edits that were suspended during the placement operation.
--- - Finalizes the placement of the object.
---
--- @param self XPlaceObjectTool The instance of the XPlaceObjectTool class.
function XPlaceObjectTool:OnCaptureLost()
	self:DeleteFeedbackLine()
	UnforceHideMouseCursor("XPlaceObjectTool")
	ResumePassEdits("XPlaceObjectTool", "ignore_errors")
	self:FinalizePlacement()
end

---
--- Creates a feedback line to visually represent the placement of an object.
---
--- This function creates a new mesh object and sets its properties to display a line between the given start and end points. The line is positioned in world space and its z-coordinate is set to the terrain height at the given points.
---
--- @param self XPlaceObjectTool The instance of the XPlaceObjectTool class.
--- @param pt1 Vector3 The start point of the feedback line.
--- @param pt2 Vector3 The end point of the feedback line.
function XPlaceObjectTool:CreateFeedbackLine(pt1, pt2)
	if not self.feedback_line then
		self.feedback_line = Mesh:new()
		self.feedback_line:SetShader(ProceduralMeshShaders.mesh_linelist)
		self.feedback_line:SetMeshFlags(const.mfWorldSpace)
		self.feedback_line:SetPos(point30)
	end
	local str = pstr()
	str:AppendVertex(pt1:SetTerrainZ())
	str:AppendVertex(pt2:SetTerrainZ())
	self.feedback_line:SetMesh(str)
end

---
--- Deletes the feedback line used for visual feedback during placement.
---
--- This function checks if a feedback line exists, and if so, deletes it and sets the feedback_line property to nil.
---
--- @param self XPlaceObjectTool The instance of the XPlaceObjectTool class.
function XPlaceObjectTool:DeleteFeedbackLine()
	if self.feedback_line then
		self.feedback_line:delete()
		self.feedback_line = nil
	end
end

----- Keyboard - auto-focus Filter field in the tool settings, route keystrokes to Ged if outside the game, shortcuts, etc.

---
--- Handles keyboard shortcuts for the XPlaceObjectTool.
---
--- This function is called when a keyboard shortcut is triggered while the XPlaceObjectTool is active. It checks the current state of the tool and performs different actions based on the shortcut pressed.
---
--- If the tool is in the "cursor" state, it handles shortcuts for cycling through the selected object classes, as well as ignoring certain shortcuts (like Ctrl-F1 and Escape) while the mouse is being dragged.
---
--- If the shortcut is not handled by the XPlaceObjectTool, it is passed to the XEditorSettings.OnShortcut function.
---
--- @param self XPlaceObjectTool The instance of the XPlaceObjectTool class.
--- @param shortcut string The keyboard shortcut that was triggered.
--- @param source string The source of the shortcut (e.g. "keyboard", "gamepad", etc.).
--- @param ... any Additional arguments passed with the shortcut.
--- @return string "break" if the shortcut was handled, otherwise nil.
function XPlaceObjectTool:OnShortcut(shortcut, source, ...)
	-- don't change tool modes, allow undo, etc. while in the process of dragging
	if terminal.desktop:GetMouseCapture() and shortcut ~= "Ctrl-F1" and shortcut ~= "Escape" then
		return "break"
	end
	
	if XEditorPlacementHelperHost.OnShortcut(self, shortcut, source, ...) == "break" then
		return "break"
	end
	
	if self.ui_state == "cursor" then
		if shortcut == "[" or shortcut == "]" then
			local dir = shortcut == "[" and -1 or 1
			local classes = self:GetObjectClass()
			SuspendPassEdits("XPlaceObjectToolCycle")
			if #classes > 1 then
				-- cycle between selected objects
				local idx = table.find(classes, self.cursor_object.class) + dir
				if idx <= 0 then
					idx = #classes
				elseif idx > #classes then
					idx = 1
				end
				self:CreateCursorObject(classes[idx])
			else
				-- cycle using the standard editor cycling logic
				local obj = CycleObjSubvariant(self.cursor_object, dir)
				self:CreateCursorObject(obj.class)
				obj:delete()
				self:SetObjectClass{obj.class}
				ObjModified(self)
			end
			ResumePassEdits("XPlaceObjectToolCycle")
			return "break"
		elseif shortcut == "Up" then
			return "break"
		elseif shortcut == "Down" then
			return "break"
		end
	end
	return XEditorSettings.OnShortcut(self, shortcut, source, ...)
end

function OnMsg.EditorCallback(id, objects)
	if id == "EditorCallbackPlace" and rawget(CObject, "GenerateFadeDistances") then
		for _, obj in ipairs(objects) do
			if IsValid(obj) then
				obj:GenerateFadeDistances()
			end
		end
	end
end
