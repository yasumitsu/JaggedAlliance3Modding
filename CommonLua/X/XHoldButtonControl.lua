const.HoldButtonFillTime = 1000

DefineClass.XHoldButton = {
	__parents = { "PropertyObject" },
	properties = {
		{ category = "Interaction" ,id = "CursorsFolder", editor = "text", default = "UI/Cursors/", },
		{ category = "Interaction", id = "CursorsCount", editor = "number", default = 6, },
		{ category = "Interaction", id = "OnHoldDown", editor = "func", params = "self, pt, button"},
	},
	pt_pressed = false,
	pressed_button =  false, 
	delay_wait_time = false,
	start_time = false,
	prev_mouse_cursor = false,
	registered_buttons = false,
}

---
--- Initializes the list of registered hold buttons.
--- The list of hold buttons is specified in the `HoldGamepadButtons` property.
--- Each button in the list is added to the `registered_buttons` table, where the key is the button name and the value is `true`.
---
--- If the `HoldGamepadButtons` property is empty, the `registered_buttons` table will contain a single empty string key.
---
--- @function XHoldButton:InitButtons
--- @return nil
function XHoldButton:InitButtons()
	local list = self.HoldGamepadButtons or ""
	self.registered_buttons = { list:starts_with(",") and "" or nil }
	for btn in list:gmatch("([%w%-_]+)") do
		self.registered_buttons[btn] = true
	end	
end

--print("pressed, onhold", pt, button)
---
--- Called when the hold button is pressed down.
---
--- @param pt table The position of the mouse cursor when the button was pressed.
--- @param button string The name of the button that was pressed.
---
function XHoldButton:OnHoldDown(pt, button)
	
end

---
--- Updates the mouse cursor during the hold button animation.
---
--- If `i` is `nil`, the mouse cursor is restored to the previous cursor.
--- Otherwise, the mouse cursor is set to the corresponding hold button cursor image.
---
--- @param i number The current index of the hold button animation (0-based).
--- @param shortcut string The name of the button being held down.
---
function XHoldButton:OnHoldButtonTick(i, shortcut)	
	if not i then -- restore after up
		if self.prev_mouse_cursor then
			self:SetMouseCursor(self.prev_mouse_cursor)		
			Msg("MouseCursor",self.prev_mouse_cursor)
		end	
		return
	end
	local img = self.CursorsFolder.."hold"..i..".tga"
	self:SetMouseCursor(img)
	Msg("MouseCursor",img)
end

---
--- Called when the hold button is repeatedly pressed down.
---
--- If the button is currently being held down, and the delay time has elapsed, this function will start the hold button animation. The animation will gradually change the mouse cursor to a series of "hold" cursor images over the duration of the `const.HoldButtonFillTime` constant.
---
--- @param button string The name of the button that is being held down.
--- @param controller_id number The ID of the controller that is being used.
---
function XHoldButton:OnHoldButtonRepeat(button, controller_id)	
	--print("repeat A", button, self.delay_wait_time and now() - self.delay_wait_time)
	if self.pressed_button and self.pressed_button==button and not self:IsThreadRunning("hold button") and (now() - self.delay_wait_time)>=300 and not self.start_time then				
		self.start_time = now()
		self.prev_mouse_cursor = self.prev_mouse_cursor or self:GetMouseCursor() or const.DefaultMouseCursor
		-- start button 		
		local count = self.CursorsCount
		local sleep_time = const.HoldButtonFillTime/count
		local last = const.HoldButtonFillTime - sleep_time*count
		self:OnHoldButtonTick(0, button)	
		self:CreateThread("hold button", function()
			for i=1, (count-1) do
				--print("change cursor", i)
				if i == (count - 1) then
					sleep_time = sleep_time + last
				end	
				Sleep(sleep_time)
				self:OnHoldButtonTick(i, button)	
			end		
		end)
	end	
end

---
--- Called when a hold button is pressed down.
---
--- This function is called when a button is first pressed down and held. It records the position of the mouse cursor and the name of the button being pressed.
---
--- @param button string The name of the button that is being pressed down.
--- @param controller_id number The ID of the controller that is being used.
---
function XHoldButton:OnHoldButtonDown(button, controller_id)
	if not self.pressed_button then
		self.pt_pressed = GamepadMouseGetPos()
		self.pressed_button = button
		self.delay_wait_time= now()
		--print("pressed A",self.delay_wait_time)
	end	
end

---
--- Called when a hold button is released.
---
--- This function is called when a button that was being held down is released. It checks if the hold button animation has completed, and if so, calls the `OnHoldDown` function. Otherwise, it cancels the hold button animation.
---
--- @param button string The name of the button that is being released.
--- @param controller_id number The ID of the controller that is being used.
--- @return boolean Whether the hold button animation was successfully completed.
---
function XHoldButton:OnHoldButtonUp(button, controller_id)
--call on hold if time is passed or cancel if less
	local success
	if self.pressed_button and button==self.pressed_button then
		self:DeleteThread("hold button")
		--print("release A",self.start_time)
		if self.start_time and (now() - self.start_time) >= const.HoldButtonFillTime then
			self:OnHoldDown(self.pt_pressed,self.pressed_button)
			success = true
		end
		
		self.pt_pressed = false
		self.pressed_button = false
		self.delay_wait_time = false
		self.start_time = false
		
		self:OnHoldButtonTick(false, button)
		self.prev_mouse_cursor = false
	end
	return success
end
---------------------------
DefineClass.XHoldButtonControl = {
	__parents = {"XHoldButton", "XContextControl" },
	properties = {
		{ category = "Interaction", id = "HoldGamepadButtons", editor = "text"},
	},
	MouseCursor = "CommonAssets/UI/HandCursor.tga",
	pt_pressed = false,
	pressed_button =  false, 
	delay_wait_time = false,
	start_time = false,
	prev_mouse_cursor = false,
	registered_buttons = false,
}

---
--- Opens the XHoldButtonControl.
---
--- This function initializes the buttons for the XHoldButton and then opens the XContextControl.
---
--- @function XHoldButtonControl:Open
--- @return nil
function XHoldButtonControl:Open()
	XHoldButton.InitButtons(self)
	XContextControl.Open(self)
end

--print("pressed, onhold", pt, button)
---
--- Called when the hold button is released.
---
--- This function is called when the hold button is released, after the hold button has been pressed for at least the required hold time.
---
--- @param pt The point where the hold button was pressed.
--- @param button The button that was held.
---
function XHoldButtonControl:OnHoldDown(pt, button)
	
end

-- XWindow functions
---
--- Called when the hold button is repeatedly pressed.
---
--- This function is called when the hold button is repeatedly pressed, after the hold button has been pressed for at least the required hold time.
---
--- @param button The button that is being held down.
--- @param controller_id The ID of the controller that is being used.
---
function XHoldButtonControl:OnXButtonRepeat(button, controller_id)	
	if not self.registered_buttons or not self.registered_buttons[button]then return end
	return XHoldButton.OnHoldButtonRepeat(self, button, controller_id)	
end

---
--- Called when an X button is pressed down.
---
--- This function is called when an X button is pressed down, and it checks if the button is registered. If the button is registered, it calls the `XHoldButton.OnHoldButtonDown` function.
---
--- @param button The button that was pressed down.
--- @param controller_id The ID of the controller that was used.
--- @return nil
function XHoldButtonControl:OnXButtonDown(button, controller_id)
	if not self.registered_buttons or not self.registered_buttons[button]then return end
	return XHoldButton.OnHoldButtonDown(self,button, controller_id)
end

---
--- Called when an X button is released.
---
--- This function is called when an X button is released, after the button has been pressed down. It checks if the button is registered, and if so, calls the `XHoldButton.OnHoldButtonUp` function.
---
--- @param button The button that was released.
--- @param controller_id The ID of the controller that was used.
--- @return nil
function XHoldButtonControl:OnXButtonUp(button, controller_id)
	if not self.registered_buttons or not self.registered_buttons[button]then return end
	return XHoldButton.OnHoldButtonUp(self, button, controller_id)
end
