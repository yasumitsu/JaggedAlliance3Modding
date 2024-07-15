DefineClass.XDragAndDropControl = {
	__parents = { "XContextControl" },
	
	properties = {
		{ category = "Interaction", id = "ClickToDrag", editor = "bool", default = false, help = "By default dragging starts when the window is clicked and dragged. With this option dragging will begin on click instead." },
		{ category = "Interaction", id = "ClickToDrop", editor = "bool", default = false, help = "By default dragging stops when the button is let go. With this option dragging will stop on a second click instead." },
		{ category = "Interaction", id = "NavigateScrollArea", editor = "bool", default = true, help = "Use scroll area, scroll with scrollbars and mouse wheel while draging" },
	},

	MouseCursor = "CommonAssets/UI/HandCursor.tga",
	drag_win = false,
	drag_target = false,
	drag_button = false,
	pt_pressed = false,
	drag_origin = false,
	dist_tostart_drag = 7, -- Unscaled pixels
	ChildrenHandleMouse = false,
}

if FirstLoad then
	DragSource = false
	DragScrollbar = false
end

-- Drag callbacks

---
--- Called when the drag operation is started.
---
--- @param pt point The initial mouse position when the drag started.
--- @param button integer The mouse button that initiated the drag.
function XDragAndDropControl:OnDragStart(pt, button)
end

---
--- Called when the drag operation has a new target.
---
--- @param target table The new target object for the drag operation.
--- @param drag_win table The window being dragged.
--- @param drop_res table The result of the drop operation.
--- @param pt point The current mouse position.
function XDragAndDropControl:OnDragNewTarget(target, drag_win, drop_res, pt)
end

---
--- Called when a drag operation is dropped on this control.
---
--- @param target table The target object for the drop operation.
--- @param drag_win table The window being dragged.
--- @param drop_res table The result of the drop operation.
--- @param pt point The current mouse position.
function XDragAndDropControl:OnDragDrop(target, drag_win, drop_res, pt)
end

---
--- Called when a drag operation has ended.
---
--- @param drag_win table The window that was being dragged.
--- @param last_target table The last target object for the drag operation.
--- @param drag_res table The result of the drag operation.
function XDragAndDropControl:OnDragEnded(drag_win, last_target, drag_res)
end

-- Drop callbacks

---
--- Checks if the given drag window is a valid drop target for this control.
---
--- @param drag_win table The window being dragged.
--- @param pt point The current mouse position.
--- @param drag_source_win table The window that initiated the drag operation.
--- @return boolean true if the drag window is a valid drop target, false otherwise.
function XDragAndDropControl:IsDropTarget(drag_win, pt, drag_source_win)
end

---
--- Called when a drag operation is dropped on this control.
---
--- @param drag_win table The window being dragged.
--- @param pt point The current mouse position.
--- @param drag_source_win table The window that initiated the drag operation.
function XDragAndDropControl:OnDrop(drag_win, pt, drag_source_win)
end

---
--- Called when a drag operation enters this control.
---
--- @param drag_win table The window being dragged.
--- @param pt point The current mouse position.
--- @param drag_source_win table The window that initiated the drag operation.
function XDragAndDropControl:OnDropEnter(drag_win, pt, drag_source_win)
end

---
--- Called when a drag operation leaves this control.
---
--- @param drag_win table The window being dragged.
function XDragAndDropControl:OnDropLeave(drag_win)
end

-- Drag functions

---
--- Starts a drag operation with the given drag window and mouse position.
---
--- @param drag_win table The window being dragged.
--- @param pt point The current mouse position.
function XDragAndDropControl:StartDrag(drag_win, pt)
	self.drag_win = drag_win
	DragSource = self
	drag_win:AddDynamicPosModifier{
		id = "Drag",
		target = Platform.console and "gamepad" or "mouse",
	}
	local winRelativePt = point(drag_win.box:minx() - pt:x(), drag_win.box:miny() - pt:y())
	drag_win:AddInterpolation{
		id = "Move",
		type = const.intRect,
		duration = 0,
		originalRect = drag_win.box,
		-- target rect is relative to the mouse position in this case.
		targetRect = box(winRelativePt:x(), winRelativePt:y(), drag_win.box:sizex() + winRelativePt:x(), drag_win.box:sizey() + winRelativePt:y()),
	}
	drag_win:SetDock("ignore")
	drag_win:SetParent(self.desktop)
	drag_win.DrawOnTop = true
	self:UpdateDrag(drag_win, pt)
	self.desktop:SetMouseCapture(self)
end

---
--- Starts a drag operation with the given mouse position.
---
--- If a drag operation is already in progress, it will be stopped first.
---
--- @param pt point The current mouse position.
--- @return string "break" to indicate the drag operation has started and the event should be stopped.
function XDragAndDropControl:InternalDragStart(pt)
	if self.drag_win then
		self:StopDrag()
	end
	local drag_win = self:OnDragStart(pt, self.drag_button)

	if not drag_win then
		return
	end
	self:StartDrag(drag_win, pt)
	self.pt_pressed = false
	return "break"
end

---
--- Stops a drag operation with the given mouse position.
---
--- If a drop target is available, it will be notified of the drop event.
---
--- @param pt point The current mouse position.
function XDragAndDropControl:InternalDragStop(pt)
	local drag_win = self.drag_win
	self:UpdateDrag(drag_win, pt)
	local target = self.drag_target
	local drop_res = target and target:OnDrop(drag_win, pt, self)
	self:OnDragDrop(target, drag_win, drop_res, pt)
	self:StopDrag(drop_res)
end

---
--- Stops a drag operation and cleans up the drag state.
---
--- If a drop target is available, it will be notified of the drop event.
---
--- @param drag_res any The result of the drop operation, if any.
---
function XDragAndDropControl:StopDrag(drag_res)
	local drag_win = self.drag_win
	if drag_win then
		local last_target = self.drag_target
		self:UpdateDropTarget(nil, drag_win)
		self:OnDragEnded(drag_win, last_target, drag_res)
		drag_win:RemoveModifier("Drag")
		drag_win:RemoveModifier("Move")
	end
	DragSource = false
	self.drag_win = nil
	self.drag_target = nil
	self.desktop:SetMouseCapture()
end

---
--- Updates the drag state and drop target during a drag operation.
---
--- This function is responsible for determining the current drop target based on the
--- mouse position and the drag window. It will notify the previous and new drop
--- targets of the drag enter/leave events.
---
--- @param drag_win XWindow The window being dragged.
--- @param pt point The current mouse position.
---
function XDragAndDropControl:UpdateDrag(drag_win, pt)
	local target = self:GetDropTarget(drag_win, pt)
	self:UpdateDropTarget(target, drag_win, pt)
end

---
--- Updates the drop target during a drag operation.
---
--- This function is responsible for notifying the previous and new drop
--- targets of the drag enter/leave events. It will update the `drag_target`
--- field to the new target, if it has changed.
---
--- @param target XWindow|nil The new drop target, or `nil` if there is no drop target.
--- @param drag_win XWindow The window being dragged.
--- @param pt point The current mouse position.
---
function XDragAndDropControl:UpdateDropTarget(target, drag_win, pt)
	if (target or false) ~= self.drag_target then
		if self.drag_target then
			self.drag_target:OnDropLeave(drag_win, pt)
		end
		local drop_res
		if target then
			drop_res = target:OnDropEnter(drag_win, pt, self)
		end
		self.drag_target = target or nil
		-- !!! update mouse cursor
		self:OnDragNewTarget(target, drag_win, drop_res, pt)
	end
end

---
--- Gets the drop target for the given drag window and mouse position.
---
--- This function is called when the drag window is the same as the mouse target.
--- It allows the implementation to override the default behavior and return a
--- different drop target.
---
--- @param drag_win XWindow The window being dragged.
--- @param pt point The current mouse position.
--- @return XWindow|nil The new drop target, or `nil` if there is no drop target.
---
function XDragAndDropControl:OnTargetDragWnd(drag_win, pt)	
	return self
end

---
--- Gets the drop target for the given drag window and mouse position.
---
--- This function is called when the drag window is the same as the mouse target.
--- It allows the implementation to override the default behavior and return a
--- different drop target.
---
--- @param drag_win XWindow The window being dragged.
--- @param pt point The current mouse position.
--- @return XWindow|nil The new drop target, or `nil` if there is no drop target.
---
function XDragAndDropControl:GetDropTarget(drag_win, pt)
	local target = self.desktop.modal_window:GetMouseTarget(pt)
	if target == drag_win then
		target = self:OnTargetDragWnd(drag_win, pt)	
	end
	while target and not target:IsDropTarget(drag_win, pt, self) do
		target = target.parent
	end
	return target
end

-- XWindow functions

---
--- Handles mouse button down events for the drag and drop control.
---
--- This function is called when the user presses a mouse button while the drag and drop control is enabled. It checks if a drag operation is already in progress, and if so, it handles the click-to-drop behavior. If no drag operation is in progress, it starts a new drag operation if the `ClickToDrag` option is enabled.
---
--- @param pt point The current mouse position.
--- @param button number The mouse button that was pressed.
--- @return string "break" to indicate that the event has been handled and should not be propagated further.
---
function XDragAndDropControl:OnMouseButtonDown(pt, button)
	if not self.enabled then
		return "break"
	end
	if self.drag_win then
		if self.NavigateScrollArea then
			-- simulate scrollbar mouse capture (it is captured by drag_win) by saving it in DragScrollbar and calling its mouse functions
			local target = self.desktop.modal_window:GetMouseTarget(pt)
			if target and IsKindOf(target,"XScrollControl") then
				DragScrollbar = target
				target:StartScroll(pt)
				target:OnMousePos(pt)
			end
		end
		if self.ClickToDrop and button == self.drag_button then
			self:InternalDragStop(pt)
		end
		return "break"
	end
	
	self.pt_pressed = pt
	self.drag_button = button
	if self.ClickToDrag then
		return self:InternalDragStart(pt)
	end
end

---
--- Handles mouse button up events for the drag and drop control.
---
--- This function is called when the user releases a mouse button while the drag and drop control is enabled. It checks if a drag operation is in progress, and if so, it handles the click-to-drop behavior. If no drag operation is in progress, it checks if the mouse button that was released matches the button that started the drag operation, and if so, it resets the pressed button state.
---
--- @param pt point The current mouse position.
--- @param button number The mouse button that was released.
--- @return string "break" to indicate that the event has been handled and should not be propagated further.
---
function XDragAndDropControl:OnMouseButtonUp(pt, button)
	if not self.enabled then return "break" end
	if self.pt_pressed and self.drag_button == button then
		self.pt_pressed = false
		self.drag_button = false
		return "break"
	end

	local drag_win = self.drag_win
	if drag_win and DragScrollbar then
		DragScrollbar:OnMousePos(pt)
		DragScrollbar = false
	end	
	if not drag_win and self.drag_button ~= button then
		return "break"
	end
	if not self.ClickToDrop then
		self:InternalDragStop(pt)
		return "break"
	end
end

---
--- Handles mouse position events for the drag and drop control.
---
--- This function is called when the user moves the mouse while the drag and drop control is enabled. It checks if a drag operation is in progress, and if so, it updates the drag operation. If no drag operation is in progress, it checks if the mouse has moved far enough from the initial press position to start a drag operation, and if so, it starts the drag operation.
---
--- @param pt point The current mouse position.
--- @return string "break" to indicate that the event has been handled and should not be propagated further.
---
function XDragAndDropControl:OnMousePos(pt)
	if not self.enabled then return "break" end
	local scaledDistance = ScaleXY(self.scale, self.dist_tostart_drag)
	if self.pt_pressed and pt:Dist2D(self.pt_pressed)>=scaledDistance  then
		self:InternalDragStart(self.pt_pressed)
		return "break"
   end
	local drag_win = self.drag_win
	if drag_win then
		self:UpdateDrag(drag_win, pt)
		if DragScrollbar then
			DragScrollbar:OnMousePos(pt)
		end
		return "break"
	end
end

---
--- Handles mouse wheel forward events for the drag and drop control.
---
--- This function is called when the user scrolls the mouse wheel forward while the drag and drop control is enabled. It checks if a drag operation is in progress and the `NavigateScrollArea` flag is set. If so, it finds the nearest `XScrollArea` window under the mouse cursor and calls its `OnMouseWheelForward` method to scroll the area.
---
--- @param pt point The current mouse position.
--- @return string "break" to indicate that the event has been handled and should not be propagated further.
---
function XDragAndDropControl:OnMouseWheelForward(pt)
	if self.NavigateScrollArea and self.drag_win then
		local target = self.desktop.modal_window:GetMouseTarget(pt)
		local wnd = GetParentOfKind(target,"XScrollArea")
		if wnd then
			wnd:OnMouseWheelForward()
			return "break"
		end	
	end
end

---
--- Handles mouse wheel back events for the drag and drop control.
---
--- This function is called when the user scrolls the mouse wheel back while the drag and drop control is enabled. It checks if a drag operation is in progress and the `NavigateScrollArea` flag is set. If so, it finds the nearest `XScrollArea` window under the mouse cursor and calls its `OnMouseWheelBack` method to scroll the area.
---
--- @param pt point The current mouse position.
--- @return string "break" to indicate that the event has been handled and should not be propagated further.
---
function XDragAndDropControl:OnMouseWheelBack(pt)
	if self.NavigateScrollArea and self.drag_win then
		local target = self.desktop.modal_window:GetMouseTarget(pt)
		local wnd = GetParentOfKind(target,"XScrollArea")
		if wnd then
			wnd:OnMouseWheelBack()
			return "break"
		end	
	end
end

---
--- Handles the event when the drag and drop control loses capture.
---
--- This function is called when the drag and drop control loses capture, such as when the user releases the mouse button or the window loses focus. It stops the current drag operation and invalidates the control to force a redraw.
---
--- @return nil
---
function XDragAndDropControl:OnCaptureLost()
	if self.drag_win then
		self:StopDrag("capture_lost")
	end
	self:Invalidate()
end
