if FirstLoad then
	LocalPlayersCount = 0
end

DefineClass.CharacterControl = {
	__parents = { "OldTerminalTarget", "InitDone" },
	active = false,
	character = false,
	camera_active = true,
	terminal_target_priority = -500,
}

---
--- Initializes the CharacterControl object with the given character.
--- Adds the CharacterControl object as a target to the terminal.
---
--- @param character table The character to associate with this CharacterControl object.
---
function CharacterControl:Init(character)
	self.character = character
	terminal.AddTarget(self)
end

---
--- Removes the CharacterControl object as a target from the terminal and deactivates it.
---
function CharacterControl:Done()
	terminal.RemoveTarget(self)
	self:SetActive(false)
end

---
--- Sets the active state of the CharacterControl object.
---
--- If the active state is changing, this function will call the appropriate
--- lifecycle functions (`OnActivate` or `OnInactivate`) and update the
--- game state accordingly.
---
--- @param active boolean The new active state of the CharacterControl object.
---
function CharacterControl:SetActive(active)
	if self.active == active then
		return
	end
	if active then
		self.active = active
		self:OnActivate()
	else
		self.active = active
		self:OnInactivate()
	end
	ChangeGameState("CharacterControl", active)
end

---
--- Sets the active state of the camera associated with this CharacterControl object.
---
--- @param active boolean The new active state of the camera.
---
function CharacterControl:SetCameraActive(active)
	self.camera_active = active
end

---
--- Called when the CharacterControl object is activated.
--- Synchronizes the CharacterControl object with the associated character.
---
function CharacterControl:OnActivate()
	self:SyncWithCharacter()
end

---
--- Called when the CharacterControl object is deactivated.
--- If the game is not paused, this function will synchronize the CharacterControl object with the associated character.
---
function CharacterControl:OnInactivate()
	if not IsPaused() then
		self:SyncWithCharacter()
	end
end

---
--- Gets the binding value for the specified binding.
---
--- @param binding table The binding to get the value for.
--- @return boolean|number|Point The value of the binding, or nil if the binding has no value.
---
function CharacterControl:GetBindingValue(binding)
end

---
--- Gets the action bindings for the specified action.
---
--- @param action string The action to get the bindings for.
--- @return table|nil The action bindings, or nil if no bindings are defined for the action.
---
function CharacterControl:GetActionBindings(action)
end

---
--- Gets the first action binding for the specified action.
---
--- @param action string The action to get the first binding for.
--- @return table|nil The first action binding, or nil if no bindings are defined for the action.
---
function CharacterControl:GetActionBinding1(action)
	local bindings = self:GetActionBindings(action)
	local binding = bindings and bindings[1]
	return binding and (binding.xbutton or binding.key or binding.mouse_button)
end

---
--- Gets the combined value of all bindings for the specified action.
---
--- @param action string The action to get the combined binding value for.
--- @return boolean|number|Point The combined value of all bindings for the specified action, or nil if no bindings are defined.
---
function CharacterControl:GetBindingsCombinedValue(action)
	local bindings = self:GetActionBindings(action)
	if not bindings then return end
	local best_value
	for i = 1, #bindings do
		local value = self:GetBindingValue(bindings[i])
		if value then
			if value == true then
				return true
			elseif type(value) == "number" then
				best_value = Max(value, best_value or 0)
			elseif IsPoint(value) then
				if not best_value or value:Len2() > best_value:Len2() then
					best_value = value
				end
			end	
		end
	end
	return best_value
end

---
--- Calls the binding functions for the specified bindings, passing the provided parameters.
---
--- @param bindings table The bindings to call.
--- @param param any The parameter to pass to the binding functions.
--- @param time number The time to pass to the binding functions.
--- @return string "continue" if all bindings were called successfully, otherwise the result of the first binding that returned a non-"continue" value.
---
function CharacterControl:CallBindingsDown(bindings, param, time)
	for i = 1, #bindings do
		local binding = bindings[i]
		if self:BindingModifiersActive(binding) then
			local result = binding.func(self.character, self, param, time)
			if result ~= "continue" then
				return result
			end
		end
	end
	return "continue"
end

---
--- Calls the binding functions for the specified bindings, passing the provided parameters.
---
--- @param bindings table The bindings to call.
--- @return string "continue" if all bindings were called successfully, otherwise the result of the first binding that returned a non-"continue" value.
---
function CharacterControl:CallBindingsUp(bindings)
	for i = 1, #bindings do
		local binding = bindings[i]
		local value = self:GetBindingsCombinedValue(binding.action)
		if not value then
			local result = binding.func(self.character, self)
			if result ~= "continue" then
				return result
			end
		end
	end
	return "continue"
end

---
--- Synchronizes the bindings of the character with the provided bindings.
---
--- @param bindings table The bindings to synchronize with the character.
---
function CharacterControl:SyncBindingsWithCharacter(bindings)
	for i = 1, #bindings do
		local binding = bindings[i]
		local value = binding.action and self:GetBindingsCombinedValue(binding.action)
		binding.func(self.character, self, value)
	end
end

---
--- Synchronizes the character with the CharacterControl instance.
---
--- This function is called to ensure the character's state is in sync with the CharacterControl instance.
---
--- @param self CharacterControl The CharacterControl instance.
---
function CharacterControl:SyncWithCharacter()
end

---
--- Binds the specified action to the keyboard and mouse synchronization.
---
--- @param action string The action to bind to the keyboard and mouse synchronization.
---
function BindToKeyboardAndMouseSync(action)
	local class = _G["CCA_"..action]
	assert(class)
	if class then
		class:BindToControllerSync(action, CC_KeyboardAndMouseSync)
	end
end

---
--- Binds the specified action to the Xbox controller synchronization.
---
--- @param action string The action to bind to the Xbox controller synchronization.
---
function BindToXboxControllerSync(action)
	local class = _G["CCA_"..action]
	assert(class)
	if class then
		class:BindToControllerSync(action, CC_XboxControllerSync)
	end
end

-- CharacterControlAction

DefineClass.CharacterControlAction = {
	__parents = {},
	ActionStop = false,
	IsKindOf = IsKindOf,
	HasMember = PropObjHasMember,
}

---
--- Handles the default action for a CharacterControlAction.
---
--- If no specific action is defined for the CharacterControlAction, this method will be called. It prints a message indicating that no action is defined for the CharacterControlAction class.
---
--- @param character table The character associated with the CharacterControlAction.
--- @return string "continue" to indicate that the action should continue to be processed.
---
function CharacterControlAction:Action(character)
	print("No Action defined: " .. self.class)
	return "continue"
end
function OnMsg.ClassesPostprocess()
	ClassDescendants("CharacterControlAction", function(class_name, class)
		if class.GetAction == CharacterControlAction.GetAction and class.Action then
			local f = function(...)
				return class:Action(...)
			end
			class.GetAction = function() return f end
		end
		if class.GetActionSync == CharacterControlAction.GetActionSync and class.ActionStop then
			local action_name = string.sub(class_name, #"CCA_" + 1)
			local function f(character, controller)
				local value = controller:GetBindingsCombinedValue(action_name)
				if not value then
					class:ActionStop(character, controller)
				end
				return "continue"
			end
			class.GetActionSync = function() return f end
		end
	end)
end
---
--- Handles the default action for a CharacterControlAction.
---
--- If no specific action is defined for the CharacterControlAction, this method will be called. It prints a message indicating that no action is defined for the CharacterControlAction class.
---
--- @param character table The character associated with the CharacterControlAction.
--- @return string "continue" to indicate that the action should continue to be processed.
---
function CharacterControlAction:GetAction()
end
---
--- Handles the default action synchronization for a CharacterControlAction.
---
--- If no specific action synchronization is defined for the CharacterControlAction, this method will be called. It should return a function that will be used to synchronize the action with the game controller.
---
--- @param character table The character associated with the CharacterControlAction.
--- @param controller table The game controller associated with the CharacterControlAction.
--- @return function The function to be used for action synchronization.
---
function CharacterControlAction:GetActionSync()
end

---
--- Binds the action synchronization function for a CharacterControlAction to the provided bindings.
---
--- If a synchronization function is defined for the CharacterControlAction, it is added to the provided bindings list. This allows the action synchronization to be properly registered with the game controller.
---
--- @param action string The name of the action to bind.
--- @param bindings table A table of bindings to add the synchronization function to.
---
function CharacterControlAction:BindToControllerSync(action, bindings)
	local f = self:GetActionSync()
	if f and not table.find(bindings, "func", f) then
		table.insert(bindings, { action = action, func = f })
	end
end

---
--- Binds a keyboard action to the provided key and modifiers.
---
--- This method is used to bind a keyboard action to the game controller. The action can be bound to a specific key, with optional modifiers such as "double-click" or "hold".
---
--- @param action string The name of the action to bind.
--- @param key string The key to bind the action to.
--- @param mod1 string|nil The first modifier for the action (e.g. "double-click", "hold").
--- @param mod2 string|nil The second modifier for the action.
---
function CharacterControlAction:BindKey(action, key, mod1, mod2)
	local f = self:GetAction()
	if f then
		if mod1 == "double-click" then
			BindToKeyboardEvent(action, "double-click", f, key, mod2)
		elseif mod1 == "hold" then
			BindToKeyboardEvent(action, "hold", f, key, mod2)
		else
			BindToKeyboardEvent(action, "down", f, key, mod1, mod2)
		end
	end
	if mod1 == "double-click" or mod1 == "hold" then
		mod1, mod2 = mod2, nil
	end
	f = self:GetActionSync()
	if f then
		BindToKeyboardEvent(action, "up", f, key)
		if mod1 then
			BindToKeyboardEvent(action, "up", f, mod1)
		end
		if mod2 then
			BindToKeyboardEvent(action, "up", f, mod2)
		end
	end
end

---
--- Binds a mouse action to the provided button and key modifier.
---
--- This method is used to bind a mouse action to the game controller. The action can be bound to a specific mouse button, with an optional key modifier.
---
--- @param action string The name of the action to bind.
--- @param button string The mouse button to bind the action to. Can be "MouseMove" for mouse movement.
--- @param key_mod string|nil The key modifier for the action (e.g. "ctrl", "alt").
---
function CharacterControlAction:BindMouse(action, button, key_mod)
	assert(key_mod ~= "double-click" and key_mod ~= "hold", "Not supported mouse modifiers")
	local f = self:GetAction()
	if f then
		if button == "MouseMove" then
			BindToMouseEvent(action, "mouse_move", f, nil, key_mod)
		else
			BindToMouseEvent(action, "down", f, button, key_mod)
		end
	end
	f = self:GetActionSync()
	if f then
		if button ~= "MouseMove" then
			BindToMouseEvent(action, "up", f, button)
		end
		if key_mod then
			BindToKeyboardEvent(action, "up", f, key_mod)
		end
	end
end

---
--- Binds an action to an Xbox controller button and optional modifiers.
---
--- This method is used to bind an action to an Xbox controller button, with optional key modifiers.
---
--- @param action string The name of the action to bind.
--- @param button string The Xbox controller button to bind the action to.
--- @param mod1 string|nil The first key modifier for the action (e.g. "hold", "ctrl").
--- @param mod2 string|nil The second key modifier for the action.
---
function CharacterControlAction:BindXboxController(action, button, mod1, mod2)
	local f = self:GetAction()
	if f then
		if mod1 == "hold" then
			BindToXboxControllerEvent(action, "hold", f, button, mod2)
		else
			BindToXboxControllerEvent(action, "down", f, button, mod1, mod2)
		end
	end
	if mod1 == "hold" then
		mod1, mod2 = mod2, nil
	end
	f = self:GetActionSync()
	if f then
		BindToXboxControllerEvent(action, "up", f, button)
		if mod1 then
			BindToXboxControllerEvent(action, "up", f, mod1)
		end
		if mod2 then
			BindToXboxControllerEvent(action, "up", f, mod2)
		end
	end
end

-- Navigation

if FirstLoad then
	UpdateCharacterNavigationThread = false
end

function OnMsg.DoneMap()
	UpdateCharacterNavigationThread = false
end

local function CalcNavigationVector(controller, camera_view)
	local pt = controller:GetBindingsCombinedValue("Move_Direction")
	if pt then
		return Rotate(pt:SetX(-pt:x()), XControlCameraGetYaw(camera_view) - 90*60)
	end
	local x = (controller:GetBindingsCombinedValue("Move_CameraRight") and 32767 or 0) + (controller:GetBindingsCombinedValue("Move_CameraLeft") and -32767 or 0)
	local y = (controller:GetBindingsCombinedValue("Move_CameraForward") and 32767 or 0) + (controller:GetBindingsCombinedValue("Move_CameraBackward") and -32767 or 0)
	if x ~= 0 or y ~= 0 then
		return Rotate(point(-x,y), XControlCameraGetYaw(camera_view) - 90*60)
	end
end

---
--- Updates the character's navigation based on the controller input.
---
--- @param character table The character object.
--- @param controller table The controller object.
--- @return string "continue" to indicate the function should continue executing.
---
function UpdateCharacterNavigation(character, controller)
	local dir = CalcNavigationVector(controller, character.camera_view)
	character:SetStateContext("navigation_vector", dir)
	if dir and not IsValidThread(UpdateCharacterNavigationThread) then
		UpdateCharacterNavigationThread = CreateMapRealTimeThread(function()
			repeat
				Sleep(20)
				if IsPaused() then break end
				local update
				for loc_player = 1, LocalPlayersCount do
					local o = PlayerControlObjects[loc_player]
					if o and o.controller then
						local dir = CalcNavigationVector(o.controller, o.camera_view)
						o:SetStateContext("navigation_vector", dir)
						update = update or dir and true
					end
				end
			until not update
			UpdateCharacterNavigationThread = false
		end)
	end
	return "continue"
end

DefineClass("CCA_Navigation", "CharacterControlAction")
DefineClass("CCA_Move_CameraForward", "CCA_Navigation")
DefineClass("CCA_Move_CameraBackward", "CCA_Navigation")
DefineClass("CCA_Move_CameraLeft", "CCA_Navigation")
DefineClass("CCA_Move_CameraRight", "CCA_Navigation")

---
--- Binds a keyboard event to the navigation action.
---
--- @param action string The name of the navigation action to bind.
--- @param key string The keyboard key to bind the action to.
---
function CCA_Navigation:BindKey(action, key)
	BindToKeyboardEvent(action, "down", UpdateCharacterNavigation, key)
	BindToKeyboardEvent(action, "up", UpdateCharacterNavigation, key)
end
---
--- Binds an Xbox controller event to the navigation action.
---
--- @param action string The name of the navigation action to bind.
--- @param button string The Xbox controller button to bind the action to.
---
function CCA_Navigation:BindXboxController(action, button)
	BindToXboxControllerEvent(action, "down", UpdateCharacterNavigation, button)
	BindToXboxControllerEvent(action, "up", UpdateCharacterNavigation, button)
end
---
--- Returns the synchronous action function for the navigation action.
---
--- @return function The synchronous action function for the navigation action.
---
function CCA_Navigation:GetActionSync()
	return UpdateCharacterNavigation
end

-- Move_Direction
DefineClass("CCA_Move_Direction", "CharacterControlAction")
---
--- Asserts that binding a 2D direction to a key is not implemented.
---
--- @param action string The name of the navigation action to bind.
--- @param key string The keyboard key to bind the action to.
--- @param mod1 string (optional) The first modifier key to bind the action to.
--- @param mod2 string (optional) The second modifier key to bind the action to.
---
function CCA_Move_Direction:BindKey(action, key, mod1, mod2)
	assert(false, "Can't bind 2D direction to a key")
end
---
--- Asserts that binding a 2D direction to a mouse is not implemented.
---
--- @param action string The name of the navigation action to bind.
--- @param button string The mouse button to bind the action to.
--- @param key_mod string (optional) The keyboard modifier key to bind the action to.
---
function CCA_Move_Direction:BindMouse(action, button, key_mod)
	assert(false, "Mouse cursor could be converted to a direction. Not implemented.")
end
---
--- Binds an Xbox controller event to the navigation action.
---
--- @param action string The name of the navigation action to bind.
--- @param button string The Xbox controller button to bind the action to. Must be either "LeftThumb" or "RightThumb".
---
function CCA_Move_Direction:BindXboxController(action, button)
	assert(button == "LeftThumb" or button == "RightThumb")
	BindToXboxControllerEvent(action, "change", UpdateCharacterNavigation, button)
end
---
--- Returns the synchronous action function for the navigation action.
---
--- @return function The synchronous action function for the navigation action.
---
function CCA_Move_Direction:GetActionSync()
	return UpdateCharacterNavigation
end

-- RotateCamera
---
--- Updates the camera rotation based on the combined value of the "CameraRotate_Left" and "CameraRotate_Right" bindings.
---
--- @param character table The character whose camera should be rotated.
--- @param controller table The character's controller.
--- @return string "continue" to indicate the action should continue.
---
function UpdateCameraRotate(character, controller)
	if not g_LookAtObjectSA then
		local dir = (controller:GetBindingsCombinedValue("CameraRotate_Left") and -1 or 0) + (controller:GetBindingsCombinedValue("CameraRotate_Right") and 1 or 0)
		camera3p.SetAutoRotate(90*60*dir)
	end
	return "continue"
end

DefineClass("CCA_CameraRotate", "CharacterControlAction")
DefineClass("CCA_CameraRotate_Left", "CCA_CameraRotate")
DefineClass("CCA_CameraRotate_Right", "CCA_CameraRotate")

---
--- Binds a keyboard event to the camera rotation action.
---
--- @param action string The name of the camera rotation action to bind.
--- @param key string The keyboard key to bind the action to.
---
function CCA_CameraRotate:BindKey(action, key)
	BindToKeyboardEvent(action, "down", UpdateCameraRotate, key)
	BindToKeyboardEvent(action, "up", UpdateCameraRotate, key)
end
---
--- Binds an Xbox controller event to the camera rotation action.
---
--- @param action string The name of the camera rotation action to bind.
--- @param button string The Xbox controller button to bind the action to. Must be either "LeftThumb" or "RightThumb".
---
function CCA_CameraRotate:BindXboxController(action, button)
	BindToXboxControllerEvent(action, "down", UpdateCameraRotate, button)
	BindToXboxControllerEvent(action, "up", UpdateCameraRotate, button)
end
---
--- Returns the synchronous action function for the camera rotation action.
---
--- @return function The synchronous action function for the camera rotation action.
---
function CCA_CameraRotate:GetActionSync()
	return UpdateCameraRotate
end

if FirstLoad then
	InGameMouseCursor = false
end

-- CameraRotate_Mouse
DefineClass("CCA_CameraRotate_Mouse", "CharacterControlAction")
---
--- Starts the camera rotation action using the mouse.
---
--- @param character table The character whose camera should be rotated.
--- @return string "break" to indicate the action should stop.
---
function CCA_CameraRotate_Mouse:Action(character)
	if not (character and character.controller and character.controller.camera_active) then
		return "continue"
	end
	if InGameMouseCursor then
		HideMouseCursor("InGameCursor") -- although MouseRotate(true) hides the mouse, IsMouseCursorHidden() depends on it
	else
		SetMouseDeltaMode(false)
	end
	MouseRotate(true)
	Msg("CameraRotateStart", "mouse")
	return "break"
end
---
--- Stops the camera rotation action using the mouse.
---
--- @param character table The character whose camera should stop rotating.
--- @return string "continue" to indicate the action should continue.
---
function CCA_CameraRotate_Mouse:ActionStop(character)
	MouseRotate(false)
	if InGameMouseCursor then
		ShowMouseCursor("InGameCursor")
	else
		HideMouseCursor("InGameCursor")
		SetMouseDeltaMode(true) -- prevents the mouse to leave the game window
	end
	Msg("CameraRotateStop", "mouse")
	return "continue"
end
---
--- Returns the synchronous action function for the camera rotation action.
---
--- @param character table The character whose camera should be rotated.
--- @param controller table The character controller.
--- @return function The synchronous action function for the camera rotation action.
---
function CCA_CameraRotate_Mouse:GetActionSync(character, controller)
	local function f(character, controller)
		local value = not CameraLocked and (MouseRotateCamera == "always" or controller:GetBindingsCombinedValue("CameraRotate_Mouse"))
		if value then
			return self:Action(character, controller)
		else
			return self:ActionStop(character, controller)
		end
	end
	return f
end

-- KeyboardAndMouse Control

DefineClass.CC_KeyboardAndMouse = {
	__parents = { "CharacterControl" },
	KeyHoldButtonTime = 350,
	KeyDoubleClickTime = 300,
	key_hold_thread = false,
	key_last_double_click = false,
	key_last_double_click_time = 0,
}

---
--- Activates the keyboard and mouse character control.
---
--- This function is called when the keyboard and mouse character control is activated.
--- It shows the in-game mouse cursor if it is enabled.
---
--- @param self table The keyboard and mouse character control instance.
---
function CC_KeyboardAndMouse:OnActivate()
	CharacterControl.OnActivate(self)
	if InGameMouseCursor then
		ShowMouseCursor("InGameCursor")
	end
end

---
--- Deactivates the keyboard and mouse character control.
---
--- This function is called when the keyboard and mouse character control is deactivated.
--- It hides the in-game mouse cursor if it was enabled.
---
--- @param self table The keyboard and mouse character control instance.
---
function CC_KeyboardAndMouse:OnInactivate()
	CharacterControl.OnInactivate(self)
	DeleteThread(self.key_hold_thread)
	self.key_hold_thread = nil
	self.key_last_double_click = nil
	self.key_last_double_click_time = nil
	HideMouseCursor("InGameCursor")
	MouseRotate(false)
end

---
--- Sets the camera active state for the keyboard and mouse character control.
---
--- This function is called to set the camera active state for the keyboard and mouse character control.
--- If the character control is active and the camera is not active, mouse rotation is disabled.
---
--- @param self table The keyboard and mouse character control instance.
--- @param active boolean The new active state for the camera.
---
function CC_KeyboardAndMouse:SetCameraActive(active)
	CharacterControl.SetCameraActive(self, active)
	if self.active and not self.camera_active then
		MouseRotate(false)
	end
end

---
--- Gets the action bindings for the keyboard and mouse character control.
---
--- This function returns the action bindings for the keyboard and mouse character control.
--- The action bindings define the key and mouse button combinations that trigger specific actions.
---
--- @param self table The keyboard and mouse character control instance.
--- @param action string The name of the action to get the bindings for.
--- @return table The action bindings for the specified action.
---
function CC_KeyboardAndMouse:GetActionBindings(action)
	return CC_KeyboardAndMouse_ActionBindings[action]
end

---
--- Gets the binding value for the specified action binding.
---
--- This function checks if the character control is active and if the required key or mouse button is pressed.
--- It also checks if the required modifier keys are active.
---
--- @param self table The keyboard and mouse character control instance.
--- @param binding table The action binding to check.
--- @return boolean The binding value, true if the binding is active, false otherwise.
---
function CC_KeyboardAndMouse:GetBindingValue(binding)
	if not self.active or binding.key and not terminal.IsKeyPressed(binding.key) then
		return false
	end
	if binding.mouse_button then
		local pressed = self:IsMouseButtonPressed(binding.mouse_button)
		if pressed == false then
			return false
		end
	end
	if not self:BindingModifiersActive(binding) then
		return false
	end
	return true
end

---
--- Checks if the specified mouse button is pressed.
---
--- This function checks if the specified mouse button is currently pressed. It uses the `terminal.IsLRMX1X2MouseButtonPressed()` function to determine the state of the mouse buttons.
---
--- @param self table The keyboard and mouse character control instance.
--- @param button string The name of the mouse button to check. Can be "LButton", "RButton", "MButton", "XButton1", or "XButton2".
--- @return boolean True if the specified mouse button is pressed, false otherwise.
---
function CC_KeyboardAndMouse:IsMouseButtonPressed(button)
	local pressed, _
	if button == "LButton" then
		pressed = terminal.IsLRMX1X2MouseButtonPressed()
	elseif button == "RButton" then
		_, pressed = terminal.IsLRMX1X2MouseButtonPressed()
	elseif button == "MButton" then
		_, _, pressed = terminal.IsLRMX1X2MouseButtonPressed()
	elseif button == "XButton1" then
		_, _, _, pressed = terminal.IsLRMX1X2MouseButtonPressed()
	elseif button == "XButton2" then
		_, _, _, _, pressed = terminal.IsLRMX1X2MouseButtonPressed()
	elseif button == "MouseWheelFwd" or button == "MouseWheelBack" then
		return false
	end
	return pressed
end

---
--- Checks if the required modifier keys for a binding are active.
---
--- This function checks if all the modifier keys specified in the binding are currently pressed. It uses the `self:IsMouseButtonPressed()` and `terminal.IsKeyPressed()` functions to determine the state of the modifier keys.
---
--- @param self table The keyboard and mouse character control instance.
--- @param binding table The action binding to check.
--- @return boolean True if all the required modifier keys are active, false otherwise.
---
function CC_KeyboardAndMouse:BindingModifiersActive(binding)
	local keys = binding.key_modifiers
	if keys then
		for i = 1, #keys do
			local key_or_button = keys[i]
			if key_or_button == "MouseWheelFwd" or key_or_button == "MouseWheelBack" then
				return false
			end
			local pressed = self:IsMouseButtonPressed(key_or_button)
			if pressed == nil then
				pressed = terminal.IsKeyPressed(key_or_button)
			end
			if not pressed then
				return false
			end
		end
	end
	return true
end

-- keyboard events
---
--- Handles keyboard key down events for the character control.
---
--- This function is called when a keyboard key is pressed. It checks for various types of key events, such as double-clicks, key holds, and regular key downs, and calls the appropriate binding functions.
---
--- @param self table The keyboard and mouse character control instance.
--- @param virtual_key number The virtual key code of the pressed key.
--- @param repeated boolean Whether the key press is a repeat event.
--- @param time number The time of the key press event.
--- @return string "continue" if the event should be passed to other handlers, or a custom return value if the event was handled.
---
function CC_KeyboardAndMouse:OnKbdKeyDown(virtual_key, repeated, time)
	if repeated or not self.active then
		return "continue"
	end
	-- double click
	if CC_KeyboardKeyDoubleClick[virtual_key] then
		if self.key_last_double_click == virtual_key and RealTime() - self.key_last_double_click_time < self.KeyDoubleClickTime then
			self.key_last_double_click = false
			self:CallBindingsDown(CC_KeyboardKeyDoubleClick[virtual_key], true, time)
		else
			self.key_last_double_click = virtual_key
			self.key_last_double_click_time = RealTime()
		end
	end
	-- hold
	if CC_KeyboardKeyHold[virtual_key] then
		DeleteThread(self.key_hold_thread)
		self.key_hold_thread = CreateRealTimeThread(function(self, virtual_key, time)
			Sleep(self.KeyHoldButtonTime)
			self.key_hold_thread = false
			if terminal.IsKeyPressed(virtual_key) then
				self:CallBindingsDown(CC_KeyboardKeyHold[virtual_key], true, time)
			end
		end, self, virtual_key, time)
	end
	-- down
	local result
	if CC_KeyboardKeyDown[virtual_key] then
		result = self:CallBindingsDown(CC_KeyboardKeyDown[virtual_key], true, time)
	end
	return result or "continue"
end

---
--- Handles keyboard key up events for the character control.
---
--- This function is called when a keyboard key is released. It checks for various types of key events, such as key holds, and calls the appropriate binding functions.
---
--- @param self table The keyboard and mouse character control instance.
--- @param virtual_key number The virtual key code of the released key.
--- @return string "continue" if the event should be passed to other handlers, or a custom return value if the event was handled.
---
function CC_KeyboardAndMouse:OnKbdKeyUp(virtual_key)
	if not self.active then
		return "continue"
	end
	if CC_KeyboardKeyHold[virtual_key] and self.key_hold_thread then
		DeleteThread(self.key_hold_thread)
		self.key_hold_thread = false
	end
	if CC_KeyboardKeyUp[virtual_key] then
		local result = self:CallBindingsUp(CC_KeyboardKeyUp[virtual_key])
		return result
	end
	return "continue"
end

-- mouse events

---
--- Handles mouse button down events for the character control.
---
--- This function is called when a mouse button is pressed. It checks for various types of mouse button events and calls the appropriate binding functions.
---
--- @param self table The keyboard and mouse character control instance.
--- @param button string The name of the mouse button that was pressed.
--- @param pt table The position of the mouse cursor when the button was pressed.
--- @param time number The time when the button was pressed.
--- @return string "continue" if the event should be passed to other handlers, or a custom return value if the event was handled.
---
function CC_KeyboardAndMouse:OnMouseButtonDown(button, pt, time)
	if not self.active then
		return "continue"
	end
	if CC_MouseButtonDown[button] then
		local result = self:CallBindingsDown(CC_MouseButtonDown[button], true, time)
		if result ~= "continue" then
			return result
		end
	end
	return "continue"
end

---
--- Handles mouse button up events for the character control.
---
--- This function is called when a mouse button is released. It checks for various types of mouse button up events and calls the appropriate binding functions.
---
--- @param self table The keyboard and mouse character control instance.
--- @param button string The name of the mouse button that was released.
--- @param pt table The position of the mouse cursor when the button was released.
--- @param time number The time when the button was released.
--- @return string "continue" if the event should be passed to other handlers, or a custom return value if the event was handled.
---
function CC_KeyboardAndMouse:OnMouseButtonUp(button, pt, time)
	if not self.active then
		return "continue"
	end
	if CC_MouseButtonUp[button] then
		local result = self:CallBindingsUp(CC_MouseButtonUp[button], false, time)
		if result ~= "continue" then
			return result
		end
	end
	return "continue"
end

---
--- Handles left mouse button down events for the character control.
---
--- This function is called when the left mouse button is pressed. It calls the appropriate binding functions for the left mouse button down event.
---
--- @param self table The keyboard and mouse character control instance.
--- @param ... any Additional arguments passed to the function.
--- @return string "continue" if the event should be passed to other handlers, or a custom return value if the event was handled.
---
function CC_KeyboardAndMouse:OnLButtonDown(...)
	return self:OnMouseButtonDown("LButton", ...)
end
---
--- Handles left mouse button up events for the character control.
---
--- This function is called when the left mouse button is released. It calls the appropriate binding functions for the left mouse button up event.
---
--- @param self table The keyboard and mouse character control instance.
--- @param ... any Additional arguments passed to the function.
--- @return string "continue" if the event should be passed to other handlers, or a custom return value if the event was handled.
---
function CC_KeyboardAndMouse:OnLButtonUp(...)
	return self:OnMouseButtonUp("LButton", ...)
end
---
--- Handles left mouse button double click events for the character control.
---
--- This function is called when the left mouse button is double clicked. It calls the appropriate binding functions for the left mouse button down event.
---
--- @param self table The keyboard and mouse character control instance.
--- @param ... any Additional arguments passed to the function.
--- @return string "continue" if the event should be passed to other handlers, or a custom return value if the event was handled.
---
function CC_KeyboardAndMouse:OnLButtonDoubleClick(...)
	return self:OnMouseButtonDown("LButton", ...)
end
---
--- Handles right mouse button down events for the character control.
---
--- This function is called when the right mouse button is pressed. It calls the appropriate binding functions for the right mouse button down event.
---
--- @param self table The keyboard and mouse character control instance.
--- @param ... any Additional arguments passed to the function.
--- @return string "continue" if the event should be passed to other handlers, or a custom return value if the event was handled.
---
function CC_KeyboardAndMouse:OnRButtonDown(...)
	return self:OnMouseButtonDown("RButton", ...)
end
---
--- Handles right mouse button up events for the character control.
---
--- This function is called when the right mouse button is released. It calls the appropriate binding functions for the right mouse button up event.
---
--- @param self table The keyboard and mouse character control instance.
--- @param ... any Additional arguments passed to the function.
--- @return string "continue" if the event should be passed to other handlers, or a custom return value if the event was handled.
---
function CC_KeyboardAndMouse:OnRButtonUp(...)
	return self:OnMouseButtonUp("RButton", ...)
end
---
--- Handles right mouse button double click events for the character control.
---
--- This function is called when the right mouse button is double clicked. It calls the appropriate binding functions for the right mouse button down event.
---
--- @param self table The keyboard and mouse character control instance.
--- @param ... any Additional arguments passed to the function.
--- @return string "continue" if the event should be passed to other handlers, or a custom return value if the event was handled.
---
function CC_KeyboardAndMouse:OnRButtonDoubleClick(...)
	return self:OnMouseButtonDown("RButton", ...)
end
---
--- Handles middle mouse button down events for the character control.
---
--- This function is called when the middle mouse button is pressed. It calls the appropriate binding functions for the middle mouse button down event.
---
--- @param self table The keyboard and mouse character control instance.
--- @param ... any Additional arguments passed to the function.
--- @return string "continue" if the event should be passed to other handlers, or a custom return value if the event was handled.
---
function CC_KeyboardAndMouse:OnMButtonDown(...)
	return self:OnMouseButtonDown("MButton", ...)
end
---
--- Handles middle mouse button up events for the character control.
---
--- This function is called when the middle mouse button is released. It calls the appropriate binding functions for the middle mouse button up event.
---
--- @param self table The keyboard and mouse character control instance.
--- @param ... any Additional arguments passed to the function.
--- @return string "continue" if the event should be passed to other handlers, or a custom return value if the event was handled.
---
function CC_KeyboardAndMouse:OnMButtonUp(...)
	return self:OnMouseButtonUp("MButton", ...)
end
function CC_KeyboardAndMouse:OnMButtonDoubleClick(...)
	return self:OnMouseButtonDown("MButton", ...)
end
---
--- Handles X button 1 down events for the character control.
---
--- This function is called when the X button 1 is pressed. It calls the appropriate binding functions for the X button 1 down event.
---
--- @param self table The keyboard and mouse character control instance.
--- @param ... any Additional arguments passed to the function.
--- @return string "continue" if the event should be passed to other handlers, or a custom return value if the event was handled.
---
function CC_KeyboardAndMouse:OnXButton1Down(...)
	return self:OnMouseButtonDown("XButton1", ...)
end
function CC_KeyboardAndMouse:OnXButton1Up(...)
	return self:OnMouseButtonUp("XButton1", ...)
end
function CC_KeyboardAndMouse:OnXButton1DoubleClick(...)
	return self:OnMouseButtonDown("XButton1", ...)
end
---
--- Handles X button 2 down events for the character control.
---
--- This function is called when the X button 2 is pressed. It calls the appropriate binding functions for the X button 2 down event.
---
--- @param self table The keyboard and mouse character control instance.
--- @param ... any Additional arguments passed to the function.
--- @return string "continue" if the event should be passed to other handlers, or a custom return value if the event was handled.
---
function CC_KeyboardAndMouse:OnXButton2Down(...)
	return self:OnMouseButtonDown("XButton2", ...)
end
function CC_KeyboardAndMouse:OnXButton2Up(...)
	return self:OnMouseButtonUp("XButton2", ...)
end
function CC_KeyboardAndMouse:OnXButton2DoubleClick(...)
	return self:OnMouseButtonDown("XButton2", ...)
end

---
--- This function is called when the mouse wheel is scrolled forward. It calls the appropriate binding functions for the mouse wheel forward event.
---
--- @param self table The keyboard and mouse character control instance.
--- @param pt table The mouse position.
--- @param time number The time when the event occurred.
--- @return string "continue" if the event should be passed to other handlers, or a custom return value if the event was handled.
---
function CC_KeyboardAndMouse:OnMouseWheelForward(pt, time)
	if not self.active then
		return "continue"
	end
	local result = self:CallBindingsDown(CC_MouseWheelFwd, true, time)
	if result ~= "break" then
		result = self:CallBindingsDown(CC_MouseWheel, 1, time)
	end
	return result
end
---
--- This function is called when the mouse wheel is scrolled backward. It calls the appropriate binding functions for the mouse wheel backward event.
---
--- @param self table The keyboard and mouse character control instance.
--- @param pt table The mouse position.
--- @param time number The time when the event occurred.
--- @return string "continue" if the event should be passed to other handlers, or a custom return value if the event was handled.
---
function CC_KeyboardAndMouse:OnMouseWheelBack(pt, time)
	if not self.active then
		return "continue"
	end
	local result = self:CallBindingsDown(CC_MouseWheelBack, true, time)
	if result ~= "break" then
		result = self:CallBindingsDown(CC_MouseWheel, -1, time)
	end
	return result
end

---
--- This function is called when the mouse position changes. It calls the appropriate binding functions for the mouse move event.
---
--- @param self table The keyboard and mouse character control instance.
--- @param pt table The mouse position.
--- @param time number The time when the event occurred.
--- @return string "continue" if the event should be passed to other handlers, or a custom return value if the event was handled.
---
function CC_KeyboardAndMouse:OnMousePos(pt, time)
	if not self.active then
		return "continue"
	end
	local result = self:CallBindingsDown(CC_MouseMove, pt, time)
	return result
end

--- Synchronizes the keyboard and mouse character control instance with the character.
---
--- This function is responsible for synchronizing the bindings between the keyboard and mouse character control instance and the character. It calls the `SyncBindingsWithCharacter` function, passing the `CC_KeyboardAndMouseSync` table as an argument.
---
--- @param self table The keyboard and mouse character control instance.
function CC_KeyboardAndMouse:SyncWithCharacter()
	self:SyncBindingsWithCharacter(CC_KeyboardAndMouseSync)
end

local function ResetKeyboardAndMouseBindings()
	CC_KeyboardKeyDown = {}
	CC_KeyboardKeyUp = {}
	CC_KeyboardKeyHold = {}
	CC_KeyboardKeyDoubleClick = {}
	CC_MouseButtonDown = {}
	CC_MouseButtonUp = {}
	CC_MouseWheel = {}
	CC_MouseWheelFwd = {}
	CC_MouseWheelBack = {}
	CC_MouseMove = {}
	CC_KeyboardAndMouse_ActionBindings = {}
	CC_KeyboardAndMouseSync = {}
end

if FirstLoad then
	ResetKeyboardAndMouseBindings()
end

---
--- Binds a keyboard key to an action.
---
--- @param action string The name of the action to bind.
--- @param key number The key code of the keyboard key to bind.
--- @param mod1 number The first modifier key code (e.g. KMOD_CTRL, KMOD_SHIFT).
--- @param mod2 number The second modifier key code (e.g. KMOD_CTRL, KMOD_SHIFT).
---
function BindKey(action, key, mod1, mod2)
	local class = _G["CCA_"..action]
	assert(class)
	if class then
		class:BindKey(action, key, mod1, mod2)
	end
end

---
--- Binds a mouse button to an action.
---
--- @param action string The name of the action to bind.
--- @param button number The mouse button code to bind.
--- @param key_mod number The modifier key code (e.g. KMOD_CTRL, KMOD_SHIFT).
---
function BindMouse(action, button, key_mod)
	local class = _G["CCA_"..action]
	assert(class)
	if class then
		class:BindMouse(action, button, key_mod)
	end
end

local function ResolveRefBindings(list, bindings)
	for i = 1, #list do
		local action = list[i][1]
		local blist = bindings[action]
		for j = #blist, 1, -1 do
			local binding = blist[j]
			for k = #binding, 1, -1 do
				local ref = bindings[binding[k]]
				if ref then
					if #ref == 0 then
						table.remove(blist,j)
					else
						table.remove(binding, k)
						for m = 2, #ref do
							table.insert(blist, j, table.copy(binding))
						end
						for m = 1, #ref do
							local rt = ref[m]
							local binding_mod = blist[j+m-1]
							for n = #rt, 1, -1 do
								table.insert(binding_mod, k+n-1, rt[n])
							end
						end
					end
				end
			end
		end
	end
end

---
--- Reloads the keyboard and mouse bindings from the provided default and predefined bindings.
---
--- @param default_bindings table A table of default keyboard and mouse bindings.
--- @param predefined_bindings table A table of predefined keyboard and mouse bindings.
---
function ReloadKeyboardAndMouseBindings(default_bindings, predefined_bindings)
	ResetKeyboardAndMouseBindings()
	if not default_bindings then
		return
	end
	local bindings = {}
	for i = 1, #default_bindings do
		local default_list = default_bindings[i]
		local action = default_list[1]
		bindings[action] = {}
		local predefined_list = predefined_bindings and predefined_bindings[action]
		for j = 1, Max(predefined_list and #predefined_list or 0, #default_list-1) do
			local binding = predefined_list and predefined_list[j] or nil
			if binding == nil then
				binding = default_list and default_list[j+1]
			end
			if binding and #binding > 0 then
				local t = {}
				for k = 1, #binding do
					t[k] = type(binding[k]) == "string" and const["vk"..binding[k]] or binding[k]
				end
				table.insert(bindings[action], t)
			end
		end
	end
	ResolveRefBindings(default_bindings, bindings)
	for i = 1, #default_bindings do
		local action = default_bindings[i][1]
		local blist = bindings[action]
		for j = 1, #blist do
			local binding = blist[j]
			if type(binding[1]) == "number" then
				BindKey(action, binding[1], binding[2], binding[3])
			else
				BindMouse(action, binding[1], binding[2], binding[3])
			end
			if binding[2] then
				if type(binding[2]) == "number" then
					BindKey(action, binding[2], binding[1], binding[3])
				else
					BindMouse(action, binding[2], binding[1], binding[3])
				end
			end
			if binding[3] then
				if type(binding[3]) == "number" then
					BindKey(action, binding[3], binding[1], binding[2])
				else
					BindMouse(action, binding[3], binding[1], binding[2])
				end
			end
		end
		BindToKeyboardAndMouseSync(action)
	end
end

---
--- Binds a keyboard event to an action.
---
--- @param action string The action to bind the event to.
--- @param event string The type of event to bind (down, up, hold, double-click).
--- @param func function The function to call when the event is triggered.
--- @param key number The key code of the key to bind the event to.
--- @param mod1 number|nil The first key modifier to use (e.g. KMOD_CTRL).
--- @param mod2 number|nil The second key modifier to use (e.g. KMOD_SHIFT).
---
function BindToKeyboardEvent(action, event, func, key, mod1, mod2)
	local binding = { action = action, key = key, func = func }
	if mod1 or mod2 then
		binding.key_modifiers = {}
		binding.key_modifiers[#binding.key_modifiers+1] = mod1
		binding.key_modifiers[#binding.key_modifiers+1] = mod2
	end
	local list
	if event == "down" then
		list = CC_KeyboardKeyDown
		CC_KeyboardAndMouse_ActionBindings[action] = CC_KeyboardAndMouse_ActionBindings[action] or {}
		table.insert(CC_KeyboardAndMouse_ActionBindings[action], binding)
	elseif event == "up" then
		list = CC_KeyboardKeyUp
	elseif event == "hold" then
		list = CC_KeyboardKeyHold
	elseif event == "double-click" then
		list = CC_KeyboardKeyDoubleClick
	end
	list[key] = list[key] or {}
	table.insert(list[key], binding)
end

---
--- Binds a mouse event to an action.
---
--- @param action string The action to bind the event to.
--- @param event string The type of event to bind (down, up, mouse_move).
--- @param func function The function to call when the event is triggered.
--- @param button string The mouse button to bind the event to (e.g. "Left", "Right", "Middle", "MouseWheel", "MouseWheelFwd", "MouseWheelBack").
--- @param key_mod number|nil The key modifier to use (e.g. KMOD_CTRL).
---
function BindToMouseEvent(action, event, func, button, key_mod)
	local binding = { action = action, mouse_button = button, func = func }
	if key_mod then
		binding.key_modifiers = {}
		binding.key_modifiers[#binding.key_modifiers+1] = key_mod
	end
	if event == "down" or button == "MouseWheel" then
		CC_KeyboardAndMouse_ActionBindings[action] = CC_KeyboardAndMouse_ActionBindings[action] or {}
		table.insert(CC_KeyboardAndMouse_ActionBindings[action], binding)
	end
	if button == "MouseWheel" then
		table.insert(CC_MouseWheel, binding)
	elseif button == "MouseWheelFwd" then
		table.insert(CC_MouseWheelFwd, binding)
	elseif button == "MouseWheelBack" then
		table.insert(CC_MouseWheelBack, binding)
	elseif event == "down" then
		CC_MouseButtonDown[button] = CC_MouseButtonDown[button] or {}
		table.insert(CC_MouseButtonDown[button], binding)
	elseif event == "up" then
		CC_MouseButtonUp[button] = CC_MouseButtonUp[button] or {}
		table.insert(CC_MouseButtonUp[button], binding)
	elseif event == "mouse_move" then
		table.insert(CC_MouseMove, binding)
	end
end


-- XboxController

DefineClass.CC_XboxController = {
	__parents = { "CharacterControl" },
	xbox_controller_id = false,
	XboxHoldButtonTime = 350,
	xbox_hold_thread = false,
	XBoxComboButtonsDelay = 100,
	xbox_last_combo_button = false,
	xbox_last_combo_button_time = 0,
}

---
--- Initializes the CC_XboxController instance with the specified character and controller ID.
---
--- @param character table The character associated with this CC_XboxController instance.
--- @param controller_id number The ID of the Xbox controller.
---
function CC_XboxController:Init(character, controller_id)
	self.xbox_controller_id = controller_id
end

---
--- Activates the CC_XboxController instance.
---
--- This function is called when the CC_XboxController instance is activated. It calls the `OnActivate` function of the parent `CharacterControl` class, and if the `xbox_controller_id` is set and the camera is active, it enables the Xbox controller for the camera.
---
--- @param self CC_XboxController The CC_XboxController instance.
---
function CC_XboxController:OnActivate()
	CharacterControl.OnActivate(self)
	if self.xbox_controller_id and self.camera_active then
		camera3p.EnableController(self.xbox_controller_id)
	end
end

---
--- Sets the camera active state for the CC_XboxController instance.
---
--- This function is called to set the camera active state for the CC_XboxController instance. If the camera is active and the Xbox controller ID is set, it enables the controller for the camera. If the camera is inactive, it disables the controller for the camera.
---
--- @param self CC_XboxController The CC_XboxController instance.
--- @param active boolean The new active state for the camera.
---
function CC_XboxController:SetCameraActive(active)
	CharacterControl.SetCameraActive(self, active)
	if self.xbox_controller_id and self.active then
		if self.camera_active then
			camera3p.EnableController(self.xbox_controller_id)
		else
			camera3p.DisableController(self.xbox_controller_id)
		end
	end
end

---
--- Deactivates the CC_XboxController instance.
---
--- This function is called when the CC_XboxController instance is deactivated. It calls the `OnInactivate` function of the parent `CharacterControl` class, deletes the `xbox_hold_thread` thread, and if the `xbox_controller_id` is set, it disables the Xbox controller for the camera.
---
--- @param self CC_XboxController The CC_XboxController instance.
---
function CC_XboxController:OnInactivate()
	CharacterControl.OnInactivate(self)
	DeleteThread(self.xbox_hold_thread)
	self.xbox_hold_thread = nil
	if self.xbox_controller_id then
		XInput.SetRumble(self.xbox_controller_id, 0, 0)
		camera3p.DisableController(self.xbox_controller_id)
	end
end

---
--- Gets the action bindings for the specified action.
---
--- @param self CC_XboxController The CC_XboxController instance.
--- @param action string The action to get the bindings for.
--- @return table The action bindings for the specified action.
---
function CC_XboxController:GetActionBindings(action)
	return CC_XboxController_ActionBindings[action]
end

---
--- Gets the binding value for the specified action binding.
---
--- This function is called to retrieve the value of the specified action binding. It first checks if the CC_XboxController instance is active. If it is not active, the function returns without a value.
---
--- Next, it checks if the binding has an associated Xbox button. If the button is not currently pressed, the function returns without a value.
---
--- The function then checks if the binding modifiers are active. If the modifiers are not active, the function returns without a value.
---
--- Finally, the function retrieves the current state of the Xbox controller button and returns its value.
---
--- @param self CC_XboxController The CC_XboxController instance.
--- @param binding table The action binding to get the value for.
--- @return number The value of the specified action binding.
---
function CC_XboxController:GetBindingValue(binding)
	if not self.active then
		return
	end
	local button = binding.xbutton
	if button and not XInput.IsCtrlButtonPressed(self.xbox_controller_id, button) then
		return
	end
	if not self:BindingModifiersActive(binding) then
		return
	end
	local value = XInput.CurrentState[self.xbox_controller_id][button]
	return value
end

---
--- Checks if the binding modifiers are active.
---
--- This function checks if all the modifier buttons specified in the binding are currently pressed on the Xbox controller. If any of the modifier buttons are not pressed, the function returns false, indicating that the binding modifiers are not active.
---
--- @param self CC_XboxController The CC_XboxController instance.
--- @param binding table The action binding to check the modifiers for.
--- @return boolean True if the binding modifiers are active, false otherwise.
---
function CC_XboxController:BindingModifiersActive(binding)
	local buttons = binding.x_modifiers
	if buttons then
		for i = 1, #buttons do
			if not XInput.IsCtrlButtonPressed(self.xbox_controller_id, buttons[i]) then
				return false
			end
		end
	end
	return true
end

---
--- Handles the button down event for an Xbox controller.
---
--- This function is called when an Xbox controller button is pressed. It first checks if the CC_XboxController instance is active and if the controller ID matches the instance's Xbox controller ID. If either of these conditions is not met, the function returns "continue" to allow other handlers to process the event.
---
--- If the button that was pressed is a "hold" button, the function creates a real-time thread that will wait for the hold time to elapse, and then call the corresponding binding handlers if the button is still pressed.
---
--- If the button that was pressed has a "down" binding, the function calls the corresponding binding handlers.
---
--- If the button that was pressed is part of a button combo, the function checks if the previous button in the combo was pressed within the combo time delay. If so, it calls the corresponding combo binding handlers.
---
--- Finally, the function updates the last combo button and time, and returns the result of the binding handlers or "continue" if no binding handlers were called.
---
--- @param self CC_XboxController The CC_XboxController instance.
--- @param button number The button that was pressed.
--- @param controller_id number The ID of the Xbox controller.
--- @return string "continue" if the event was not handled, or the result of the binding handlers.
---
function CC_XboxController:OnXButtonDown(button, controller_id)
	if not self.active or controller_id ~= self.xbox_controller_id then
		return "continue"
	end
	-- hold
	if CC_XboxButtonHold[button] then
		DeleteThread(self.xbox_hold_thread)
		self.xbox_hold_thread = CreateRealTimeThread(function(self, button, controller_id)
			Sleep(self.XboxHoldButtonTime)
			self.xbox_hold_thread = false
			if XInput.IsCtrlButtonPressed(self.xbox_controller_id, button) then
				local xstate = XInput.CurrentState[controller_id]
				self:CallBindingsDown(CC_XboxButtonHold[button], xstate[button])
			end
		end, self, button, controller_id)
	end
	local result
	if CC_XboxButtonDown[button] then
		result = self:CallBindingsDown(CC_XboxButtonDown[button], true)
	end
	if CC_XboxButtonCombo[button] then
		local handlers = self.xbox_last_combo_button and RealTime() - self.xbox_last_combo_button_time < self.XBoxComboButtonsDelay and CC_XboxButtonCombo[button][self.xbox_last_combo_button]
		if handlers then
			local result = self:CallBindingsDown(handlers, true)
			if result and result ~= "continue" then
				self.xbox_last_combo_button = false
				return result
			end
		end
		self.xbox_last_combo_button = button
		self.xbox_last_combo_button_time = RealTime()
	end
	return result or "continue"
end

---
--- This function is called when an Xbox controller button is released. It first checks if the CC_XboxController instance is active and if the controller ID matches the instance's Xbox controller ID. If either of these conditions is not met, the function returns "continue" to allow other handlers to process the event.
---
--- If the released button was the last button in a button combo, the function resets the last combo button and time.
---
--- If the released button had a "hold" binding, the function deletes the real-time thread that was waiting for the hold time to elapse.
---
--- If the released button had an "up" binding, the function calls the corresponding binding handlers.
---
--- Finally, the function returns "continue" to allow other handlers to process the event.
---
--- @param self CC_XboxController The CC_XboxController instance.
--- @param button number The button that was released.
--- @param controller_id number The ID of the Xbox controller.
--- @return string "continue" if the event was not handled, or the result of the binding handlers.
---
function CC_XboxController:OnXButtonUp(button, controller_id)
	if not self.active or controller_id ~= self.xbox_controller_id then
		return "continue"
	end
	if self.xbox_last_combo_button == button then
		self.xbox_last_combo_button = false
	end
	if CC_XboxButtonHold[button] and self.xbox_hold_thread then
		DeleteThread(self.xbox_hold_thread)
		self.xbox_hold_thread = false
	end
	if CC_XboxButtonUp[button] then
		local result = self:CallBindingsUp(CC_XboxButtonUp[button])
		if result ~= "continue" then
			return result
		end
	end
	return "continue"
end

---
--- This function is called when a new input packet is received from the Xbox controller. It first checks if the CC_XboxController instance is active and if the controller ID matches the instance's Xbox controller ID. If either of these conditions is not met, the function returns "continue" to allow other handlers to process the event.
---
--- The function then iterates through the list of buttons defined in CC_XboxControllerNewPacket and calls the corresponding binding handlers with the current state of the button.
---
--- Finally, the function returns "continue" to allow other handlers to process the event.
---
--- @param self CC_XboxController The CC_XboxController instance.
--- @param controller_id number The ID of the Xbox controller.
--- @param last_state table The previous state of the Xbox controller.
--- @param current_state table The current state of the Xbox controller.
--- @return string "continue" if the event was not handled.
---
function CC_XboxController:OnXNewPacket(_, controller_id, last_state, current_state)
	if not self.active or controller_id ~= self.xbox_controller_id then
		return "continue"
	end
	for i = 1, #CC_XboxControllerNewPacket do
		local button = CC_XboxControllerNewPacket[i]
		self:CallBindingsDown(CC_XboxControllerNewPacket[button], current_state[button])
	end
	return "continue"
end

---
--- Synchronizes the bindings of the CC_XboxController instance with the character.
---
--- This function calls the SyncBindingsWithCharacter method of the CC_XboxController instance, passing the CC_XboxControllerSync table as an argument.
---
--- The CC_XboxControllerSync table contains a list of functions that should be called to synchronize the state of the CC_XboxController instance with the character.
---
--- @param self CC_XboxController The CC_XboxController instance.
---
function CC_XboxController:SyncWithCharacter()
	self:SyncBindingsWithCharacter(CC_XboxControllerSync)
end

local function ResetXboxControllerBindings()
	CC_XboxButtonDown = {}
	CC_XboxButtonUp = {}
	CC_XboxButtonHold = {}
	CC_XboxButtonCombo = {}
	CC_XboxControllerNewPacket = {}
	CC_XboxController_ActionBindings = {}
	CC_XboxControllerSync = {}
	table.insert(CC_XboxControllerSync,{ func = function() MouseRotate(false) end})
end

if FirstLoad then
	ResetXboxControllerBindings()
end

---
--- Reloads the Xbox controller bindings using the provided default and predefined bindings.
---
--- This function first resets the Xbox controller bindings by calling `ResetXboxControllerBindings()`.
--- It then iterates through the `default_bindings` table and creates a `bindings` table that contains the
--- predefined bindings or the default bindings if no predefined bindings are available.
---
--- Finally, it resolves any reference bindings using `ResolveRefBindings()` and then binds the actions
--- to the Xbox controller using `BindXboxController()` and `BindToXboxControllerSync()`.
---
--- @param default_bindings table A table of default bindings for the Xbox controller.
--- @param predefined_bindings table (optional) A table of predefined bindings for the Xbox controller.
---
function ReloadXboxControllerBindings(default_bindings, predefined_bindings)
	ResetXboxControllerBindings()
	if not default_bindings then
		return
	end
	local bindings = {}
	for i = 1, #default_bindings do
		local default_list = default_bindings[i]
		local action = default_list[1]
		bindings[action] = {}
		local predefined_list = predefined_bindings and predefined_bindings[action]
		for i = 1, Max(predefined_list and #predefined_list or 0, #default_list-1) do
			local binding = predefined_list and predefined_list[i] or nil
			if binding == nil then
				binding = default_list and default_list[i+1]
			end
			if binding and #binding > 0 then
				local t = {}
				for k = 1, #binding do
					t[k] = binding[k]
				end
				table.insert(bindings[action], t)
			end
		end
	end
	ResolveRefBindings(default_bindings, bindings)
	for i = 1, #default_bindings do
		local action = default_bindings[i][1]
		local blist = bindings[action]
		for j = 1, #blist do
			local binding = blist[j]
			BindXboxController(action, unpack_params(binding))
		end
		BindToXboxControllerSync(action)
	end
end

---
--- Binds an action to an Xbox controller button.
---
--- This function retrieves the class associated with the given `action` and calls its `BindXboxController` method, passing the `action`, `button`, `mod1`, and `mod2` parameters.
---
--- @param action string The name of the action to bind.
--- @param button string The button on the Xbox controller to bind the action to.
--- @param mod1 string (optional) The first modifier button to use with the action.
--- @param mod2 string (optional) The second modifier button to use with the action.
---
function BindXboxController(action, button, mod1, mod2)
	local class = _G["CCA_"..action]
	assert(class)
	if class then
		class:BindXboxController(action, button, mod1, mod2)
	end
end

---
--- Binds an action to an Xbox controller event.
---
--- This function binds an action to an Xbox controller event, such as button down, up, hold, or combo. It also supports binding actions to the "sync" event, which is used to synchronize actions with the Xbox controller.
---
--- @param action string The name of the action to bind.
--- @param event string The event to bind the action to, such as "down", "up", "hold", "combo", "change", or "sync".
--- @param func function The function to call when the event is triggered.
--- @param button string (optional) The button on the Xbox controller to bind the action to.
--- @param mod1 string (optional) The first modifier button to use with the action.
--- @param mod2 string (optional) The second modifier button to use with the action.
---
function BindToXboxControllerEvent(action, event, func, button, mod1, mod2)
	if event == "sync" then
		if action or not table.find(CC_XboxControllerSync, "func", func) then
			local binding = { action = action, func = func }
			table.insert(CC_XboxControllerSync, binding)
		end
		return
	end
	local binding = { action = action, xbutton = button, func = func }
	if mod1 or mod2 then
		binding.x_modifiers = {}
		binding.x_modifiers[#binding.x_modifiers+1] = mod1
		binding.x_modifiers[#binding.x_modifiers+1] = mod2
	end
	local list
	if event == "down" then
		CC_XboxController_ActionBindings[action] = CC_XboxController_ActionBindings[action] or {}
		table.insert(CC_XboxController_ActionBindings[action], binding)
		list = CC_XboxButtonDown
	elseif event == "up" then
		list = CC_XboxButtonUp
		table.insert_unique(CC_XboxButtonUp, button)
	elseif event == "hold" then
		list = CC_XboxButtonHold
	elseif event == "combo" then
		list = CC_XboxButtonCombo
	elseif event == "change" then
		CC_XboxController_ActionBindings[action] = CC_XboxController_ActionBindings[action] or {}
		table.insert(CC_XboxController_ActionBindings[action], binding)
		table.insert_unique(CC_XboxControllerNewPacket, button)
		list = CC_XboxControllerNewPacket
	else
		return
	end
	if not list[button] then
		list[button] = {}
	end
	table.insert(list[button], binding)
end
