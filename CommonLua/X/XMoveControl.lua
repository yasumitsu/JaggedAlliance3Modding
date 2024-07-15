DefineClass.XMoveControl = {
	__parents = { "XControl" },
	properties = {
		{ category = "Interaction", id = "ConstrainInParent", editor = "bool", default = false },
	},
	
	IdNode = false,
	Target = "node",
	HandleMouse = true,
	
	box_at_drag_start = false,
	pt_at_drag_start = false,
}

---
--- Applies an offset to the target object's position.
---
--- If the target object's `Dock` property is set to "ignore", the function sets the target's box to the new position and size.
--- Otherwise, it calculates the unscaled offset and sets the target's margins accordingly.
---
--- @param target table The target object to apply the offset to.
--- @param offsetP point The offset to apply to the target's position.
---
function XMoveControl:ApplyOffsetToTarget(target, offsetP)
	if target.Dock == "ignore" then
		local oldB = target.box
		target:SetBox(offsetP:x(), offsetP:y(), oldB:sizex(), oldB:sizey())
	else
		local unscale = MulDivRoundPoint(offsetP, point(1000, 1000), target.scale)
		target:SetMargins(box(unscale:x(), unscale:y(), 0, 0))
	end
end

---
--- Handles the mouse button down event for the XMoveControl.
---
--- When the left mouse button is pressed, this function:
--- - Resolves the target object to move
--- - Applies the current position of the target object as the offset
--- - Sets the horizontal and vertical alignment of the target object to "left" and "top"
--- - Sets the focus on the XMoveControl
--- - Captures the mouse to the XMoveControl
--- - Calls the OnDragStart() function
--- - Stores the current box and mouse position for later use
--- - Calls the OnMousePos() function to update the target object's position
---
--- @param pt point The current mouse position
--- @param button string The mouse button that was pressed ("L" for left)
--- @return string "break" to indicate the event has been handled
function XMoveControl:OnMouseButtonDown(pt, button)
	if button == "L" then
		local target = self:ResolveId(self.Target) or GetParentOfKind(self, self.Target)
		local curB = target.box
		self:ApplyOffsetToTarget(target, curB:min())
		target:SetHAlign("left")
		target:SetVAlign("top")
		self:SetFocus()
		self.desktop:SetMouseCapture(self)
		self:OnDragStart()
		
		self.box_at_drag_start = target.box
		self.pt_at_drag_start = pt
		
		self:OnMousePos(pt)
	end
	return "break"
end

---
--- Handles the mouse position event for the XMoveControl.
---
--- When the mouse is captured by the XMoveControl, this function:
--- - Calculates the difference between the current mouse position and the position at the start of the drag
--- - Applies the calculated offset to the target object's position
--- - Constrains the target object's position within its parent's margins, if the ConstrainInParent flag is set
--- - Calls the OnDragDelta() function with the calculated offset
--- - Applies the calculated offset to the target object using the ApplyOffsetToTarget() function
---
--- @param pt point The current mouse position
--- @return string "break" to indicate the event has been handled
function XMoveControl:OnMousePos(pt)
	if self.desktop:GetMouseCapture() == self then
		local old_box = self.box_at_drag_start
		local diff = pt - self.pt_at_drag_start
		local newbox = sizebox(old_box:min() + diff, old_box:size())
		
		local target = self:ResolveId(self.Target) or GetParentOfKind(self, self.Target)
		if self.ConstrainInParent then
			local x1, y1, x2, y2 = target:GetEffectiveMargins()
			local margins = box(-x1, -y1, x2, y2)
			newbox = FitBoxInBox(newbox + margins, target.parent.box) - margins
		end

		self:OnDragDelta(newbox:min() - target.box:min())
		self:ApplyOffsetToTarget(target, newbox:min())
	end
	return "break"
end

---
--- Handles the mouse button up event for the XMoveControl.
---
--- When the mouse button is released while the XMoveControl has mouse capture:
--- - Calls the OnMousePos() function to update the target object's position one last time
--- - Releases the mouse capture
--- - Calls the OnDragEnd() function to notify listeners that the drag operation has ended
---
--- @param pt point The current mouse position
--- @param button string The mouse button that was released ("L" for left, "R" for right, etc.)
--- @return string "break" to indicate the event has been handled
function XMoveControl:OnMouseButtonUp(pt, button)
	if self.desktop:GetMouseCapture() == self and button == "L" then
		self:OnMousePos(pt)
		self.desktop:SetMouseCapture()
		self:OnDragEnd()
	end
	return "break"
end

---
--- Handles the start of a drag operation for the XMoveControl.
---
--- This function is called when the user starts dragging the XMoveControl. It is responsible for
--- capturing the mouse and storing the initial position of the drag operation.
---
--- @function XMoveControl:OnDragStart
--- @return nil
function XMoveControl:OnDragStart()
end

---
--- Handles the end of a drag operation for the XMoveControl.
---
--- This function is called when the user finishes dragging the XMoveControl. It is responsible for
--- releasing the mouse capture and notifying listeners that the drag operation has ended.
---
--- @function XMoveControl:OnDragEnd
--- @return nil
function XMoveControl:OnDragEnd()
end

---
--- Handles the delta of a drag operation for the XMoveControl.
---
--- This function is called during a drag operation to update the position of the target object
--- based on the delta (difference) between the current mouse position and the previous mouse position.
---
--- @param delta point The delta (difference) between the current mouse position and the previous mouse position.
--- @return nil
function XMoveControl:OnDragDelta(delta)
end
