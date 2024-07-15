local max_thumb_value = (1 << 15) - 1

DefineClass.MouseViaGamepad = {
	__parents = { "XWindow", "TerminalTarget" },
	properties = {
		{ category = "General", id = "enabled", name = "Enabled", editor = "bool", default = false },
	},
	
	Id = "idMouseViaGamepad",
	IdNode = true,
	HandleMouse = false,
	Dock = "box",
	ZOrder = 10000000, -- above everything, even above loading screens
	DrawOnTop = true,
	Clip = false,
	UseClipBox = false,
	
	LeftClickButton = "ButtonA",
	RightClickButton = "ButtonB",
	LastClickTimes = false,
	DoubleClickTime = 300, --ms
}

---
--- Initializes the MouseViaGamepad class.
--- This function is called when the MouseViaGamepad instance is created.
--- It adds the instance as a target to the terminal, initializes the LastClickTimes table,
--- and creates a new XImage instance for the cursor.
---
--- @function [parent=#MouseViaGamepad] Init()
--- @return nil
---
function MouseViaGamepad:Init()
	terminal.AddTarget(self)
	
	self.LastClickTimes = { }
	
	local image = XImage:new({
		Id = "idCursor",
		HAlign = "left",
		VAlign = "top",
		Clip = false,
		UseClipBox = false,
	}, self)
	image:AddDynamicPosModifier({id = "cursor", target = "gamepad"})
end

---
--- Removes the MouseViaGamepad instance as a target from the terminal.
---
--- @function [parent=#MouseViaGamepad] Done()
--- @return nil
---
function MouseViaGamepad:Done()
	terminal.RemoveTarget(self)
end

---
--- Handles the gamepad mouse state when a new packet is received.
--- This function is called when a new gamepad input packet is received.
--- It checks the state of the left and right triggers, and enables or disables the gamepad mouse based on their values.
---
--- @param _ any unused parameter
--- @param controller_id number the ID of the gamepad controller
--- @param last_state table the previous state of the gamepad
--- @param current_state table the current state of the gamepad
--- @return nil
---
function MouseViaGamepad:OnXNewPacket(_, controller_id, last_state, current_state)
	if not self.enabled then return end
	
	local left_trigger = current_state.LeftTrigger > 0
	local right_trigger = current_state.RightTrigger > 0
	hr.GamepadMouseEnabled = not left_trigger and not right_trigger
end

---
--- Handles the gamepad mouse button down event.
--- This function is called when a gamepad button is pressed.
--- It checks if the button is the left or right click button, and if so, it updates the mouse position, checks for double clicks, and triggers the appropriate mouse event.
---
--- @param button number the gamepad button that was pressed
--- @param controller_id number the ID of the gamepad controller
--- @return string "continue" if the event was not handled, or nil if the event was handled
---
function MouseViaGamepad:OnXButtonDown(button, controller_id)
	if not self.enabled then return end
	
	if not self.visible then
		ForceHideMouseCursor("MouseViaGamepad")
		self:SetVisible(true)
		GamepadMouseSetPos(terminal.GetMousePos())
	end
	
	local mouse_btn = (button == self.LeftClickButton and "L") or (button == self.RightClickButton and "R")
	if mouse_btn then
		local pt = GamepadMouseGetPos()
		
		local now = now()
		local last_click_time = self.LastClickTimes[mouse_btn]
		self.LastClickTimes[mouse_btn] = now
		local is_double_click = last_click_time and (now - last_click_time) <= self.DoubleClickTime
		if is_double_click then
			return terminal.MouseEvent("OnMouseButtonDoubleClick", pt, mouse_btn, "gamepad")
		else
			return terminal.MouseEvent("OnMouseButtonDown", pt, mouse_btn, "gamepad")
		end
	end
	return "continue"
end

---
--- Handles the gamepad mouse button up event.
--- This function is called when a gamepad button is released.
--- It checks if the button is the left or right click button, and if so, it triggers the appropriate mouse up event.
---
--- @param button number the gamepad button that was released
--- @param controller_id number the ID of the gamepad controller
--- @return string "continue" if the event was not handled, or nil if the event was handled
---
function MouseViaGamepad:OnXButtonUp(button, controller_id)
	local mouse_btn = (button == self.LeftClickButton and "L") or (button == self.RightClickButton and "R")
	if mouse_btn then
		local pt = GamepadMouseGetPos()
		return terminal.MouseEvent("OnMouseButtonUp", pt, mouse_btn)
	end
	return "continue"
end

---
--- Handles the mouse position update event when using a gamepad.
--- This function is called when the mouse position is updated while using a gamepad.
--- It checks if the mouse is visible, and if so, it hides the mouse cursor and sets the gamepad mouse position to the new position.
---
--- @param pt table the new mouse position
--- @return string "continue" if the event was not handled, or nil if the event was handled
---
function MouseViaGamepad:OnMousePos(pt)
	if not self.enabled then return end
	
	if self.visible then
		UnforceHideMouseCursor("MouseViaGamepad")
		self:SetVisible(false)
	end
	GamepadMouseSetPos(pt)
	
	return "continue"
end

---
--- Sets whether the gamepad mouse functionality is enabled or disabled.
---
--- When enabled, this function creates a thread that updates the mouse position based on gamepad input.
--- When disabled, this function stops the update thread and removes the forced mouse cursor hide.
---
--- @param enabled boolean whether to enable or disable the gamepad mouse functionality
---
function MouseViaGamepad:SetEnabled(enabled)
	self.enabled = enabled
	hr.GamepadMouseEnabled = enabled
	if enabled then
		if not self:IsThreadRunning("UpdateMousePosThread") then
			self:CreateThread("UpdateMousePosThread", self.UpdateMousePosThread, self)
		end
	else
		UnforceHideMouseCursor("MouseViaGamepad")
		if self:IsThreadRunning("UpdateMousePosThread") then
			self:DeleteThread("UpdateMousePosThread")
		end
	end
end

---
--- Sets the cursor image for the gamepad mouse.
---
--- @param image string the image to set for the cursor
---
function MouseViaGamepad:SetCursorImage(image)
	self.idCursor:SetImage(image)
end

---
--- Updates the mouse position based on gamepad input.
---
--- This function is called in a separate thread to continuously update the mouse position
--- while the gamepad mouse functionality is enabled. It retrieves the current gamepad
--- mouse position, sets the terminal mouse position to that value, and then calls the
--- `OnMousePos` event on the parent object.
---
--- The function will run in an infinite loop, waiting for the next frame and checking
--- if the gamepad mouse position has changed since the last update.
---
--- @function MouseViaGamepad:UpdateMousePosThread
--- @return nil
function MouseViaGamepad:UpdateMousePosThread()
	GamepadMouseSetPos(terminal.GetMousePos())

	local previous_pos
	while true do
		WaitNextFrame()
		local pos = GamepadMouseGetPos()
		if pos ~= previous_pos then
			terminal.SetMousePos(pos)
			self.parent:MouseEvent("OnMousePos", pos)
			
			previous_pos = pos
		end
	end
end

----------------------
---
--- Gets the mouse control window for the gamepad mouse functionality.
---
--- @return table|nil the mouse control window, or nil if it doesn't exist
---
function GetMouseViaGamepadCtrl()
	return terminal.desktop and rawget(terminal.desktop, "idMouseViaGamepad")
end

MouseViaGamepadHideSkipReasons = {
	["MouseViaGamepad"] = true,
}

function OnMsg.ShowMouseCursor(visible)
	local mouse_win = GetMouseViaGamepadCtrl()
	if not mouse_win then return end
	
	local show = not not next(ShowMouseReasons)
	
	local force_hide
	for reason in pairs(ForceHideMouseReasons) do
		if not MouseViaGamepadHideSkipReasons[reason] then
			force_hide = true
			break
		end
	end
	
	local my_visible = show and not force_hide
	
	mouse_win:SetVisible(my_visible)
end

function OnMsg.MouseCursor(cursor)
	local mouse_win = GetMouseViaGamepadCtrl()
	if not mouse_win then return end
	
	local path, name, ext = SplitPath(cursor)
	--local gamepad_cursor = string.format("%s%s_pad%s", path, name, ext)
	local gamepad_cursor = string.format("%s%s%s", path, name, ext)
	mouse_win:SetCursorImage(gamepad_cursor)
end

---
--- Shows or hides the mouse control window for the gamepad mouse functionality.
---
--- @param show boolean Whether to show or hide the mouse control window.
---
function ShowMouseViaGamepad(show)
	local mouse_win = GetMouseViaGamepadCtrl()
	if not mouse_win and show then
		mouse_win = MouseViaGamepad:new({}, terminal.desktop)
	end
	if mouse_win then
		if show then
			ForceHideMouseCursor("MouseViaGamepad")
			mouse_win:SetVisible(true)
			GamepadMouseSetPos(terminal.GetMousePos())
		end	
		mouse_win:SetEnabled(show)
	end
end

---
--- Deletes the mouse control window for the gamepad mouse functionality.
---
function DeleteMouseViaGamepad()
	local mouse_win = GetMouseViaGamepadCtrl()
	if mouse_win then
		mouse_win:delete()
	end	
end

---
--- Checks if the gamepad mouse functionality is active.
---
--- @return boolean true if the gamepad mouse is enabled, false otherwise
---
function IsMouseViaGamepadActive()
	return hr.GamepadMouseEnabled == true or hr.GamepadMouseEnabled == 1
end
