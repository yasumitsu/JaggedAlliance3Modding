ComboButtonsDelay = 100
KeyDoubleClickTime = 300

DefineClass.TriggerSource = {
	__parents = { "InitDone" },
	trigger_target = false,
}

--- Initializes the TriggerSource object with the specified target.
---
--- @param target table The target object for the trigger source.
function TriggerSource:Init(target)
	self.trigger_target = target
end

---
--- Raises a trigger on the target object.
---
--- @param trigger string|table The trigger or list of triggers to raise.
--- @param source table The source object for the trigger.
--- @return boolean True if the trigger was successfully raised, false otherwise.
function TriggerSource:RaiseTrigger(trigger, source)
	if not trigger then return end
	local target = self.trigger_target
	
	if source then
		target:SetStateContext("trigger_source", source)
	end
	if type(trigger) == "table" then
		for i = 1, #trigger do
			local trigger_processed = target:RaiseTrigger(trigger[i])
			if trigger_processed then
				break
			end
		end
	else
		target:RaiseTrigger(trigger)
	end
	
	return true
end

---
--- Sets the state context of the target object for the specified context(s).
---
--- @param context string|table The context or list of contexts to set.
--- @param value any The value to set for the context(s).
--- @return boolean True if the context(s) were successfully set, false otherwise.
function TriggerSource:SetTargetContext(context, value)
	local target = self.trigger_target

	if type(context) == "table" then
		local n = #context
		if n > 0 then
			for i = 1, n do
				target:SetStateContext(context[i], value)
			end
			return true
		end
	elseif type(context) == "string" then
		target:SetStateContext(context, value)
		return true
	end
end


DefineClass.TerminalTriggerSource =
{
	__parents = { "TriggerSource", "OldTerminalTarget" },
	active = true,
	controller_id = false,
	last_combo_button = false,
	last_combo_button_time = false,
	HoldButtonTime = 350,
	held_buttons = false,

	x_triggers = false,
	x_combo_buttons = false,
	x_triggers_up = false,
	x_triggers_hold = false,
	x_contexts = false,
	
	kb_triggers = false,
	kb_triggers_up = false,
	kb_triggers_hold = false,
	kb_triggers_double_click = false,
	kb_triggers_modifiers = false,
	kb_contexts = false,
	last_key = false,
	last_key_time = false,
	
	mouse_triggers = false,
	mouse_triggers_up = false,
	mouse_triggers_hold = false,
	mouse_contexts = false,

	terminal_target_priority = -500,
}

-- should be predifined in games
if FirstLoad then
	KeyboardTriggers = { down = {}, up = {}, hold = {}, contexts = {}, double_click = {}, modifiers = {} }
	MouseTriggers = { down = {}, up = {}, hold = {}, contexts = {}, modifiers = {} }
	XControllerTriggers = { down = {}, up = {}, hold = {}, contexts = {}, modifiers = {} }
	TerminalTriggerSourceList = {}
end

---
--- Initializes a TerminalTriggerSource object, which is responsible for handling input events
--- and triggering actions in a terminal-based user interface.
---
--- @param target table The target object that the TerminalTriggerSource will interact with.
--- @param controller_id number The ID of the game controller associated with this TerminalTriggerSource.
---
function TerminalTriggerSource:Init(target, controller_id)
	TerminalTriggerSourceList[#TerminalTriggerSourceList + 1] = self
	self.kb_triggers = KeyboardTriggers.down
	self.kb_triggers_up = KeyboardTriggers.up
	self.kb_triggers_hold = KeyboardTriggers.hold
	self.kb_triggers_double_click = KeyboardTriggers.double_click
	self.kb_triggers_modifiers = KeyboardTriggers.modifiers
	self.kb_contexts = KeyboardTriggers.contexts
	self.x_triggers = XControllerTriggers.down
	self.x_combo_buttons = XControllerTriggers.combo_buttons
	self.x_triggers_up = XControllerTriggers.up
	self.x_triggers_hold = XControllerTriggers.hold
	self.x_contexts = XControllerTriggers.contexts
	self.mouse_triggers = MouseTriggers.down
	self.mouse_triggers_up = MouseTriggers.up
	self.mouse_triggers_hold = MouseTriggers.hold
	self.mouse_contexts = MouseTriggers.contexts

	self.controller_id = controller_id
	self.held_buttons = {}
	terminal.AddTarget(self)
	self:RestoreContext(true)
end

---
--- Finalizes and cleans up the TerminalTriggerSource object.
---
--- Removes the TerminalTriggerSource from the global TerminalTriggerSourceList, stops any active rumble effects,
--- deactivates the TerminalTriggerSource, removes it as a target from the terminal, and clears its context.
---
--- @method Done
--- @return nil
function TerminalTriggerSource:Done()
	table.remove_value(TerminalTriggerSourceList, self)
	if self.controller_id then
		XInput.SetRumble(self.controller_id, 0, 0)
	end
	self:SetActive(false)
	terminal.RemoveTarget(self)
	self:ClearContext()
end

---
--- Disables the keyboard input handling for the TerminalTriggerSource.
---
--- This function sets the following properties to `false`:
--- - `OnKbdKeyDown`
--- - `OnKbdKeyUp`
--- - `kb_triggers`
--- - `kb_triggers_up`
--- - `kb_triggers_hold`
--- - `kb_triggers_double_click`
--- - `kb_triggers_modifiers`
--- - `kb_contexts`
---
--- This effectively disables all keyboard input handling for the TerminalTriggerSource.
---
function TerminalTriggerSource:DisableKeyboard()
	self.OnKbdKeyDown = false
	self.OnKbdKeyUp = false
	self.kb_triggers = false
	self.kb_triggers_up = false
	self.kb_triggers_hold = false
	self.kb_triggers_double_click = false
	self.kb_triggers_modifiers = false
	self.kb_contexts = false
end

---
--- Sets the active state of the TerminalTriggerSource.
---
--- When the TerminalTriggerSource is active, it will process input events and raise triggers. When it is inactive, it will stop processing input and clear any held buttons.
---
--- @param active boolean Whether the TerminalTriggerSource should be active or not.
--- @return nil
function TerminalTriggerSource:SetActive(active)
	if self.active == active then
		return
	end
	self.active = active
	if active then
		self:OnActivate()
	else
		if self.controller_id then
			XInput.SetRumble(self.controller_id, 0, 0)
		end
		for button, thread in pairs(self.held_buttons) do
			DeleteThread(thread)
			self.held_buttons[button] = nil
		end
		self:OnDeactivate()
	end
end

---
--- Tracks a button press and triggers a callback after the button has been held for a specified duration.
---
--- @param button_id string The ID of the button to track.
--- @param trigger function The callback function to call when the button has been held for the specified duration.
--- @return nil
function TerminalTriggerSource:TrackHoldButton(button_id, trigger)
	self:StopTrackingHoldButton(button_id)
	if trigger and button_id and not self.held_buttons[button_id] then
		self.held_buttons[button_id] = CreateRealTimeThread(function()
			Sleep(self.HoldButtonTime)
			self.held_buttons[button_id] = nil
			if self.active and not IsPaused() then
				self:RaiseTrigger(trigger)
			end
		end)
	end
end

---
--- Stops tracking a button hold for the specified button ID.
---
--- @param button_id string The ID of the button to stop tracking.
--- @return nil
function TerminalTriggerSource:StopTrackingHoldButton(button_id)
	assert(self.held_buttons)
	local thread = button_id and self.held_buttons[button_id]
	if thread then
		DeleteThread(thread)
		self.held_buttons[button_id] = nil
	end
end

---
--- Handles the button down event for an Xbox controller button.
---
--- This function is responsible for tracking button hold events, setting the target context, and raising any associated triggers when an Xbox controller button is pressed.
---
--- @param button string The ID of the button that was pressed.
--- @param controller_id number The ID of the controller that the button was pressed on.
--- @return string "continue" if the event was not fully processed, "break" if the event was fully processed.
function TerminalTriggerSource:OnXButtonDown(button, controller_id)
	if not self.active or not self.x_triggers or not button or controller_id ~= self.controller_id or IsPaused() then
		return "continue"
	end
	self:TrackHoldButton(button, self.x_triggers_hold[button])
	local context = self:SetTargetContext(self.x_contexts[button], true)
	local trigger_processed = self:RaiseTrigger(self.x_triggers[button], "XBOXController")
	local combo_trigger_processed
	if self.x_combo_buttons[button] then
		if self.last_combo_button and RealTime() - self.last_combo_button_time < ComboButtonsDelay then
			local combo_trigger = self.x_triggers[self.last_combo_button .. button] or self.x_triggers[button..self.last_combo_button]
			if combo_trigger then
				combo_trigger_processed = self:RaiseTrigger(combo_trigger, "XBOXController")
			end
		end
		if combo_trigger_processed then
			self.last_combo_button = false
		else
			self.last_combo_button = button
			self.last_combo_button_time = RealTime()
		end
	end
	return (context or trigger_processed or combo_trigger_processed) and "break" or "continue"
end

---
--- Handles the button up event for an Xbox controller button.
---
--- This function is responsible for stopping the tracking of a button hold event, setting the target context, and raising any associated triggers when an Xbox controller button is released.
---
--- @param button string The ID of the button that was released.
--- @param controller_id number The ID of the controller that the button was released on.
--- @return string "continue" if the event was not fully processed, "break" if the event was fully processed.
function TerminalTriggerSource:OnXButtonUp(button, controller_id)
	if not button or not self.x_triggers or controller_id ~= self.controller_id then
		return "continue"
	end
	if self.last_combo_button == button then
		self.last_combo_button = false
	end
	self:StopTrackingHoldButton(button)
	if not self.active or IsPaused() then
		return "continue"
	end
	local context = self:SetTargetContext(self.x_contexts[button], false)
	local trigger_processed = self:RaiseTrigger(self.x_triggers_up[button], "XBOXController")
	return (context or trigger_processed) and "break" or "continue"
end

local no_input = point20
local function InputToWorldVector(v, view)
	if not v then
		return no_input
	end
	local x, y = v:xy()
	return Rotate(point(-x,y), XControlCameraGetYaw(view) - 90*60)
end

---
--- Updates the thumb stick input values and sets the corresponding target contexts.
---
--- This function is responsible for converting the raw thumb stick input values from the controller
--- into world-space vectors, and then setting the appropriate target contexts for those vectors.
---
--- @param current_state table The current state of the controller, containing the thumb stick input values.
---
function TerminalTriggerSource:UpdateThumbs(current_state)
	local camera_hook
	if type(current_state) == "table" then
		local view = self.trigger_target.camera_view
		local value1 = InputToWorldVector(current_state.LeftThumb, view)
		local value2 = InputToWorldVector(current_state.RightThumb, view)
		local processed1 = self:SetTargetContext(self.x_contexts.LeftThumbVector, value1)
		local processed2 = self:SetTargetContext(self.x_contexts.RightThumbVector, value2)
		camera_hook = processed1 and value1:Len2D() > 0 or processed2 and value2:Len2D() > 0
	end
end

---
--- This function is responsible for processing new input packets from an Xbox controller.
---
--- It updates the target contexts for the left and right thumb sticks, as well as the left and right triggers, based on the current state of the controller.
---
--- @param _ any Unused parameter.
--- @param controller_id number The ID of the controller that the input packet is from.
--- @param last_state table The previous state of the controller.
--- @param current_state table The current state of the controller.
--- @return string "continue" to indicate that the event was not fully processed.
---
function TerminalTriggerSource:OnXNewPacket(_, controller_id, last_state, current_state)
	if not self.active or controller_id ~= self.controller_id or IsPaused() then
		return "continue"
	end
	self:UpdateThumbs(current_state)
	self:SetTargetContext(self.x_contexts.LeftTriggerVector, current_state.LeftTrigger)
	self:SetTargetContext(self.x_contexts.RightTriggerVector, current_state.RightTrigger)
	return "continue"
end

---
--- Updates the mouse camera.
---
--- This function is responsible for updating the camera view based on the current mouse position.
---
function TerminalTriggerSource:UpdateMouseCamera()
end

---
--- Updates the mouse camera and navigation vector based on the current mouse position.
---
--- This function is responsible for updating the camera view and setting the navigation vector
--- based on the current mouse position. It checks if the trigger source is active, the keyboard
--- triggers are available, and the game is not paused. If the conditions are met, it gets the
--- keyboard direction vector and sets the navigation vector target context if the vector is
--- not zero.
---
--- @param pt table The current mouse position.
--- @return string "continue" to indicate that the event was not fully processed.
---
function TerminalTriggerSource:OnMousePos(pt)
	if not self.active or not self.kb_triggers or IsPaused() then
		return "continue"
	end
	-- Have the character walk in the direction he's facing.
	local vector = self:GetKeyboardDir("navigation_vector", false, false)
	if vector then
		local x, y = vector:xy()
		if x ~= 0 or y ~= 0 then
			self:SetTargetContext("navigation_vector", vector)
		end
	end
	return "continue"
end

---
--- Handles mouse button down events.
---
--- This function is responsible for handling mouse button down events. It checks if the trigger source is active, the mouse and keyboard triggers are available, and the game is not paused. If the conditions are met, it updates the mouse camera, starts tracking the hold button, sets the target context for the mouse button, and raises the mouse button trigger.
---
--- @param button string The name of the mouse button that was pressed.
--- @param track_id string The ID of the button being tracked.
--- @return string "continue" to indicate that the event was not fully processed, or "break" to indicate that the event was fully processed.
---
function TerminalTriggerSource:_OnButtonDown(button, track_id)
	if not self.active or not self.mouse_triggers or not self.kb_triggers or IsPaused() then
		return "continue"
	end
	
	self:UpdateMouseCamera()
	self:TrackHoldButton(track_id, self.mouse_triggers_hold[button])
	local context = self:SetTargetContext(self.mouse_contexts[button], true)
	local trigger = self:RaiseTrigger(self.mouse_triggers[button], "Mouse")
	
	return (context or trigger) and "break" or "continue"
end

---
--- Handles mouse button up events.
---
--- This function is responsible for handling mouse button up events. It checks if the trigger source is active, the mouse and keyboard triggers are available, and the game is not paused. If the conditions are met, it stops tracking the hold button, updates the mouse camera, sets the target context for the mouse button, and raises the mouse button up trigger.
---
--- @param button string The name of the mouse button that was released.
--- @param track_id string The ID of the button being tracked.
--- @return string "continue" to indicate that the event was not fully processed, or "break" to indicate that the event was fully processed.
---
function TerminalTriggerSource:_OnButtonUp(button, track_id)
	self:StopTrackingHoldButton(track_id)
	if not self.active or not self.mouse_triggers or not self.kb_triggers or IsPaused() then
		return "continue"
	end
	
	self:UpdateMouseCamera()
	local context = self:SetTargetContext(self.mouse_contexts[button], false)
	local trigger_processed = self:RaiseTrigger(self.mouse_triggers_up[button], "Mouse")
	
	return (context or trigger_processed) and "break" or "continue"
end

---
--- Handles left mouse button down events.
---
--- This function is responsible for handling left mouse button down events. It checks if the trigger source is active, the mouse and keyboard triggers are available, and the game is not paused. If the conditions are met, it updates the mouse camera, starts tracking the hold button, sets the target context for the left mouse button, and raises the left mouse button trigger.
---
--- @param button string The name of the mouse button that was pressed.
--- @param track_id string The ID of the button being tracked.
--- @return string "continue" to indicate that the event was not fully processed, or "break" to indicate that the event was fully processed.
---
function TerminalTriggerSource:OnLButtonDown()
	return self:_OnButtonDown("LButton", "left_mouse_button")
end

TerminalTriggerSource.OnLButtonDoubleClick = TerminalTriggerSource.OnLButtonDown

---
--- Handles left mouse button up events.
---
--- This function is responsible for handling left mouse button up events. It checks if the trigger source is active, the mouse and keyboard triggers are available, and the game is not paused. If the conditions are met, it stops tracking the hold button, updates the mouse camera, sets the target context for the left mouse button, and raises the left mouse button up trigger.
---
--- @param button string The name of the mouse button that was released.
--- @param track_id string The ID of the button being tracked.
--- @return string "continue" to indicate that the event was not fully processed, or "break" to indicate that the event was fully processed.
---
function TerminalTriggerSource:OnLButtonUp()
	return self:_OnButtonUp("LButton", "left_mouse_button")
end

---
--- Handles right mouse button down events.
---
--- This function is responsible for handling right mouse button down events. It checks if the trigger source is active, the mouse and keyboard triggers are available, and the game is not paused. If the conditions are met, it updates the mouse camera, starts tracking the hold button, sets the target context for the right mouse button, and raises the right mouse button trigger.
---
--- @param button string The name of the mouse button that was pressed.
--- @param track_id string The ID of the button being tracked.
--- @return string "continue" to indicate that the event was not fully processed, or "break" to indicate that the event was fully processed.
---
function TerminalTriggerSource:OnRButtonDown()
	return self:_OnButtonDown("RButton", "right_mouse_button")
end

TerminalTriggerSource.OnRButtonDoubleClick = TerminalTriggerSource.OnRButtonDown

---
--- Handles right mouse button up events.
---
--- This function is responsible for handling right mouse button up events. It checks if the trigger source is active, the mouse and keyboard triggers are available, and the game is not paused. If the conditions are met, it stops tracking the hold button, updates the mouse camera, sets the target context for the right mouse button, and raises the right mouse button up trigger.
---
--- @param button string The name of the mouse button that was released.
--- @param track_id string The ID of the button being tracked.
--- @return string "continue" to indicate that the event was not fully processed, or "break" to indicate that the event was fully processed.
---
function TerminalTriggerSource:OnRButtonUp()
	return self:_OnButtonUp("RButton", "right_mouse_button")
end

---
--- Handles middle mouse button down events.
---
--- This function is responsible for handling middle mouse button down events. It checks if the trigger source is active, the mouse and keyboard triggers are available, and the game is not paused. If the conditions are met, it updates the mouse camera, starts tracking the hold button, sets the target context for the middle mouse button, and raises the middle mouse button trigger.
---
--- @param button string The name of the mouse button that was pressed.
--- @param track_id string The ID of the button being tracked.
--- @return string "continue" to indicate that the event was not fully processed, or "break" to indicate that the event was fully processed.
function TerminalTriggerSource:OnMButtonDown()
	return self:_OnButtonDown("MButton", "middle_mouse_button")
end

TerminalTriggerSource.OnMButtonDoubleClick = TerminalTriggerSource.OnMButtonDown

---
--- Handles middle mouse button up events.
---
--- This function is responsible for handling middle mouse button up events. It checks if the trigger source is active, the mouse and keyboard triggers are available, and the game is not paused. If the conditions are met, it stops tracking the hold button, updates the mouse camera, sets the target context for the middle mouse button, and raises the middle mouse button up trigger.
---
--- @param button string The name of the mouse button that was released.
--- @param track_id string The ID of the button being tracked.
--- @return string "continue" to indicate that the event was not fully processed, or "break" to indicate that the event was fully processed.
function TerminalTriggerSource:OnMButtonUp()
	return self:_OnButtonUp("MButton", "middle_mouse_button")
end

---
--- Handles left mouse button down events.
---
--- This function is responsible for handling left mouse button down events. It checks if the trigger source is active, the mouse and keyboard triggers are available, and the game is not paused. If the conditions are met, it updates the mouse camera, starts tracking the hold button, sets the target context for the left mouse button, and raises the left mouse button trigger.
---
--- @param button string The name of the mouse button that was pressed.
--- @param track_id string The ID of the button being tracked.
--- @return string "continue" to indicate that the event was not fully processed, or "break" to indicate that the event was fully processed.
---
function TerminalTriggerSource:OnXButton1Down()
	return self:_OnButtonDown("XButton1", "mouse_xbutton1")
end

TerminalTriggerSource.OnXButton1DoubleClick = TerminalTriggerSource.OnXButton1Down

---
--- Handles left mouse button up events.
---
--- This function is responsible for handling left mouse button up events. It checks if the trigger source is active, the mouse and keyboard triggers are available, and the game is not paused. If the conditions are met, it stops tracking the hold button, updates the mouse camera, sets the target context for the left mouse button, and raises the left mouse button up trigger.
---
--- @param button string The name of the mouse button that was released.
--- @param track_id string The ID of the button being tracked.
--- @return string "continue" to indicate that the event was not fully processed, or "break" to indicate that the event was fully processed.
function TerminalTriggerSource:OnXButton1Up()
	return self:_OnButtonUp("XButton1", "mouse_xbutton1")
end

---
--- Handles right mouse button down events.
---
--- This function is responsible for handling right mouse button down events. It checks if the trigger source is active, the mouse and keyboard triggers are available, and the game is not paused. If the conditions are met, it updates the mouse camera, starts tracking the hold button, sets the target context for the right mouse button, and raises the right mouse button trigger.
---
--- @param button string The name of the mouse button that was pressed.
--- @param track_id string The ID of the button being tracked.
--- @return string "continue" to indicate that the event was not fully processed, or "break" to indicate that the event was fully processed.
function TerminalTriggerSource:OnXButton2Down()
	return self:_OnButtonDown("XButton2", "mouse_xbutton2")
end

TerminalTriggerSource.OnXButton2DoubleClick = TerminalTriggerSource.OnXButton2Down

---
--- Handles right mouse button up events.
---
--- This function is responsible for handling right mouse button up events. It checks if the trigger source is active, the mouse and keyboard triggers are available, and the game is not paused. If the conditions are met, it stops tracking the hold button, updates the mouse camera, sets the target context for the right mouse button, and raises the right mouse button up trigger.
---
--- @param button string The name of the mouse button that was released.
--- @param track_id string The ID of the button being tracked.
--- @return string "continue" to indicate that the event was not fully processed, or "break" to indicate that the event was fully processed.
function TerminalTriggerSource:OnXButton2Up()
	return self:_OnButtonUp("XButton2", "mouse_xbutton2")
end

---
--- Handles keyboard key down events.
---
--- This function is responsible for handling keyboard key down events. It checks if the trigger source is active, the keyboard triggers are available, and the game is not paused. If the conditions are met, it updates the mouse camera, starts tracking the hold button, sets the target context for the keyboard key, and raises the keyboard key trigger.
---
--- @param virtual_key number The virtual key code of the key that was pressed.
--- @param repeated boolean Whether the key press was repeated.
--- @return string "continue" to indicate that the event was not fully processed, or "break" to indicate that the event was fully processed.
---
function TerminalTriggerSource:OnKbdKeyDown(virtual_key, repeated)
	if repeated or not virtual_key or not self.active or not self.kb_triggers or IsPaused() then
		return "continue"
	end
	self:UpdateMouseCamera()
	self:TrackHoldButton(virtual_key, self.kb_triggers_hold[virtual_key])
	local modifiers = self.kb_triggers_modifiers[virtual_key]

	local context = self:SetKbdTargetContext(virtual_key, true)
	for i = 1, modifiers and #modifiers or 0 do
		local t = modifiers[i]
		if t.context then
			local raise = true
			for j = 1, #t do
				raise = raise and terminal.IsKeyPressed(t[j])
			end
			context = raise and self:SetTargetContext(t.context, true) or context
		end
	end

	if self.kb_triggers_double_click[virtual_key] then
		if self.last_key == virtual_key and RealTime() - self.last_key_time < KeyDoubleClickTime then
			self.last_key = false
			self:RaiseTrigger(self.kb_triggers_double_click[virtual_key], "Keyboard")
		else
			self.last_key = virtual_key
			self.last_key_time = RealTime()
		end
	end

	local trigger_processed = self:RaiseTrigger(self.kb_triggers[virtual_key], "Keyboard")
	for i = 1, modifiers and #modifiers or 0 do
		local t = modifiers[i]
		if t.trigger then
			local raise = true
			for j = 1, #t do
				raise = raise and terminal.IsKeyPressed(t[j])
			end
			trigger_processed = raise and self:RaiseTrigger(t.trigger, "Keyboard") or trigger_processed
		end
	end

	return (context or trigger_processed) and "break" or "continue"
end

---
--- Handles keyboard key up events for the TerminalTriggerSource.
---
--- @param virtual_key number The virtual key code of the key that was released.
--- @param repeated boolean Whether the key release was repeated.
--- @return string "continue" to indicate that the event was not fully processed, or "break" to indicate that the event was fully processed.
---
function TerminalTriggerSource:OnKbdKeyUp(virtual_key, repeated)
	self:StopTrackingHoldButton(virtual_key)
	if repeated or not virtual_key or not self.active or not self.kb_triggers or IsPaused() then
		return "continue"
	end
	self:UpdateMouseCamera()
	local context = self:SetKbdTargetContext(virtual_key, false)
	local trigger_processed = self:RaiseTrigger(self.kb_triggers_up[virtual_key], "Keyboard")

	local modifiers = self.kb_triggers_modifiers[virtual_key]
	for i = 1, modifiers and #modifiers or 0 do
		if modifiers[i].context then
			self:SetTargetContext(modifiers[i].context, nil)
		end
	end
	return (context or trigger_processed) and "break" or "continue"
end

---
--- Calculates the keyboard direction based on the current keyboard state.
---
--- @param context string The context for the keyboard direction.
--- @param virtual_key number The virtual key code of the currently pressed key.
--- @param key_down boolean Whether the key is currently pressed down.
--- @return vector2 The keyboard direction as a vector2, or nil if no direction is detected.
---
function TerminalTriggerSource:GetKeyboardDir(context, virtual_key, key_down)
	if not context and self.kb_contexts then
		return
	end
	local x, y
	for vk, desc in pairs(self.kb_contexts) do
		local dir = type(desc) == "table" and desc[1] == context and desc.dir
		if dir then
			-- IsKeyPressed for the currently processed key returns the opposite
			if (vk == virtual_key and key_down) or (vk ~= virtual_key and terminal.IsKeyPressed(vk)) then
				if dir == "left" then
					if not x then x = -1 elseif x > 0 then x = 0 end
				elseif dir == "right" then
					if not x then x = 1 elseif x < 0 then x = 0 end
				elseif dir == "down" then
					if not y then y = -1 elseif y > 0 then y = 0 end
				elseif dir == "up" then
					if not y then y = 1 elseif y < 0 then y = 0 end
				end
			end
		end
	end
	if x or y then
		local v = InputToWorldVector(point(x or 0, y or 0) * 32767)
		return v
	end
end

---
--- Sets the keyboard target context for the specified virtual key.
---
--- @param virtual_key number The virtual key code of the currently pressed key.
--- @param key_down boolean Whether the key is currently pressed down.
--- @return boolean Whether the target context was successfully set.
---
function TerminalTriggerSource:SetKbdTargetContext(virtual_key, key_down)
	if not self.kb_contexts then return end
	local context = self.kb_contexts[virtual_key]
	local value = key_down
	if type(context) == "table" and context.dir then
		value = self:GetKeyboardDir(context[1], virtual_key, key_down) or no_input
	end
	local result = self:SetTargetContext(context, value)
	return result
end

---
--- Restores the context of the TerminalTriggerSource object.
---
--- @param reset boolean (optional) If true, the context will be reset before restoring.
---
--- This function restores the context of the TerminalTriggerSource object, which includes the keyboard and Xbox controller input states. It first checks the keyboard input and sets the corresponding context values. Then, it checks the Xbox controller input and sets the corresponding context values. Finally, it applies the restored context to the trigger target object.
---
--- If the `reset` parameter is provided and is true, the context will be cleared before restoring.
---
function TerminalTriggerSource:RestoreContext(reset)
	local contexts = {}
	local function SetContext(context, value)
		if type(context) == "table" then
			for i = 1, #context do
				local id = context[i]
				if IsPoint(value) and IsPoint(contexts[id]) and value:Len() < contexts[id]:Len() then
					-- nothing
				else
					contexts[id] = value or contexts[id] or false
				end
			end
		elseif type(context) == "string" then
			local id = context
			if IsPoint(value) and IsPoint(contexts[id]) and value:Len() < contexts[id]:Len() then
				-- nothing
			else
				contexts[id] = value or contexts[id] or false
			end
		end
	end
	-- keyboard
	if self.kb_contexts then
		for virtual_key, context in pairs(self.kb_contexts) do
			local value = false
			if terminal.IsKeyPressed(virtual_key) then
				if type(context) == "table" and context.dir then
					value = self:GetKeyboardDir(context[1], virtual_key, virtual_key) or no_input
				else
					value = true
				end
			end
			SetContext(context, value)
		end
	end
	-- XBOX controller
	local controller_id = self.controller_id
	local controller_state = false
	if controller_id then
		controller_state = XInput.CurrentState[controller_id]
		assert(type(controller_state) == "table", "Trigger source associated to an invalid controller " .. controller_id)
	end
	if self.x_contexts then
		for button, context in pairs(self.x_contexts) do
			local value = false
			if controller_id then
				if button == "LeftThumbVector" then
					value = InputToWorldVector(controller_state.LeftThumb, self.trigger_target.camera_view)
				elseif button == "RightThumbVector" then
					value = InputToWorldVector(controller_state.RightThumb, self.trigger_target.camera_view)
				elseif button == "LeftTriggerVector" then
					value = controller_state.LeftTrigger
				elseif button == "RightTriggerVector" then
					value = controller_state.RightTrigger
				else
					value = XInput.IsCtrlButtonPressed(controller_id, button)
				end
			end
			SetContext(context, value)
		end
	end
	-- apply contexts
	for id, value in pairs(contexts) do
		local set = reset or self.trigger_target:GetStateContext(id)
		if set then
			self:SetTargetContext(id, value)
		end
	end
end

---
--- Activates the TerminalTriggerSource and restores its context.
--- Raises up triggers for keyboard and controller buttons.
---
--- @param self TerminalTriggerSource
function TerminalTriggerSource:OnActivate()
	if not self.trigger_target then return end

	self:RestoreContext()

	-- raise up triggers for buttons
	local up_triggers = {}
	if self.kb_triggers_up then
		for virtual_key, trigger_id in pairs(self.kb_triggers_up) do
			up_triggers[trigger_id] = not terminal.IsKeyPressed(virtual_key)
		end
	end
	if self.controller_id and self.x_triggers_up then
		for button, trigger_id in pairs(self.x_triggers_up) do
			if up_triggers[trigger_id] ~= false then
				up_triggers[trigger_id] = not XInput.IsCtrlButtonPressed(self.controller_id, button)
			end
		end
	end
	for trigger_id, raise in pairs(up_triggers) do
		if raise then
			self:RaiseTrigger(trigger_id)
		end
	end
end

---
--- Deactivates the TerminalTriggerSource and clears its context.
---
--- @param self TerminalTriggerSource
function TerminalTriggerSource:OnDeactivate()
	if not self.trigger_target then return end
	self:SetTargetContext("navigation_vector", nil)
end

---
--- Clears the state context of the trigger target object.
---
--- @param self TerminalTriggerSource
function TerminalTriggerSource:ClearContext()
	ClearTerminalStateObjectContext(self.trigger_target)
end

---
--- Clears the state context of the given terminal state object.
---
--- @param obj table The terminal state object to clear the context for.
function ClearTerminalStateObjectContext(obj)
	if not IsValid(obj) then return end
	local list = GetTerminalStateObjectContexts()
	for i = 1, #list do
		local context = list[i]
		obj:SetStateContext(context, nil)
	end
end

---
--- Gets a list of all the terminal state object contexts used in the application.
---
--- @return table A list of all the terminal state object contexts.
function GetTerminalStateObjectContexts()
	local t = {}
	local function AddContexts(context)
		if type(context) == "table" then
			for i = 1, #context do
				t[context[i]] = true
			end
		else
			t[context] = true
		end
	end
	for virtual_key, context in pairs(KeyboardTriggers.contexts) do
		AddContexts(context)
	end
	for button, context in pairs(XControllerTriggers.contexts) do
		AddContexts(context)
	end
	local list = {}
	for k in sorted_pairs(t) do
		list[#list+1] = k
	end
	return list
end

function OnMsg.Resume()
	for i = 1, #TerminalTriggerSourceList do
		local ts = TerminalTriggerSourceList[i]
		if ts.active then
			ts:OnActivate()
		end
	end
end
