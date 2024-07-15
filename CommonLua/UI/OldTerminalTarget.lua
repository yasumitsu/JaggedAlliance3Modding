----- OldTerminalTarget

DefineClass.OldTerminalTarget = {
	__parents = { "TerminalTarget" },
}

---
--- Handles mouse button down events for the OldTerminalTarget class.
---
--- This function is called when a mouse button is pressed on the OldTerminalTarget object.
--- It checks which mouse button was pressed and calls the corresponding event handler function.
---
--- @param pt table The position of the mouse cursor when the button was pressed.
--- @param button string The name of the mouse button that was pressed ("L", "R", "M", "X1", "X2").
--- @return boolean Whether the event was handled.
---
function OldTerminalTarget:OnMouseButtonDown(pt, button)
	if button == "L" then
		return self:OnLButtonDown(pt)
	elseif button == "R" then
		return self:OnRButtonDown(pt)
	elseif button == "M" then
		return self:OnMButtonDown(pt)
	elseif button == "X1" then
		return self:OnXButton1Down(pt)
	elseif button == "X2" then
		return self:OnXButton2Down(pt)
	end
end

---
--- Handles mouse button up events for the OldTerminalTarget class.
---
--- This function is called when a mouse button is released on the OldTerminalTarget object.
--- It checks which mouse button was released and calls the corresponding event handler function.
---
--- @param pt table The position of the mouse cursor when the button was released.
--- @param button string The name of the mouse button that was released ("L", "R", "M", "X1", "X2").
--- @return boolean Whether the event was handled.
---
function OldTerminalTarget:OnMouseButtonUp(pt, button)
	if button == "L" then
		return self:OnLButtonUp(pt)
	elseif button == "R" then
		return self:OnRButtonUp(pt)
	elseif button == "M" then
		return self:OnMButtonUp(pt)
	elseif button == "X1" then
		return self:OnXButton1Up(pt)
	elseif button == "X2" then
		return self:OnXButton2Up(pt)
	end
end

---
--- Handles mouse button double click events for the OldTerminalTarget class.
---
--- This function is called when a mouse button is double clicked on the OldTerminalTarget object.
--- It checks which mouse button was double clicked and calls the corresponding event handler function.
---
--- @param pt table The position of the mouse cursor when the button was double clicked.
--- @param button string The name of the mouse button that was double clicked ("L", "R", "M", "X1", "X2").
--- @return boolean Whether the event was handled.
---
function OldTerminalTarget:OnMouseButtonDoubleClick(pt, button)
	if button == "L" then
		return self:OnLButtonDoubleClick(pt)
	elseif button == "R" then
		return self:OnRButtonDoubleClick(pt)
	elseif button == "M" then
		return self:OnMButtonDoubleClick(pt)
	elseif button == "X1" then
		return self:OnXButton1DoubleClick(pt)
	elseif button == "X2" then
		return self:OnXButton2DoubleClick(pt)
	end
end

----- mouse event handlers
local function stub() end
OldTerminalTarget.OnLButtonDown = stub
OldTerminalTarget.OnLButtonUp = stub
OldTerminalTarget.OnLButtonDoubleClick = stub
OldTerminalTarget.OnRButtonDown = stub
OldTerminalTarget.OnRButtonUp = stub
OldTerminalTarget.OnRButtonDoubleClick = stub
OldTerminalTarget.OnMButtonDown = stub
OldTerminalTarget.OnMButtonUp = stub
OldTerminalTarget.OnMButtonDoubleClick = stub
OldTerminalTarget.OnXButton1Down = stub
OldTerminalTarget.OnXButton1Up = stub
OldTerminalTarget.OnXButton1DoubleClick = stub
OldTerminalTarget.OnXButton2Down = stub
OldTerminalTarget.OnXButton2Up = stub
OldTerminalTarget.OnXButton2DoubleClick = stub