DefineClass.XButton = {
	__parents = { "XContextControl" },

	properties = {
		{ category = "General", id = "RepeatStart", name = "Start repeating time", editor = "number", default = 0, },
		{ category = "General", id = "RepeatInterval", name = "Repeat interval", editor = "number", default = 0, },
		{ category = "General", id = "OnPressEffect", editor = "choice", default= "", items = {"", "close", "action"}, },
		{ category = "General", id = "OnPressParam", editor = "text", default = "" },
		{ category = "General", id = "OnPress", name = "On press", editor = "func", params = "self, gamepad" },
		{ category = "General", id = "AltPress", name = "Allow alternative press", editor = "bool", default = false, },
		{ category = "General", id = "OnAltPress", name = "On alt press", editor = "func", params = "self, gamepad" },
		
		{ category = "Visual", id = "RolloverBackground", name = "Rollover background", editor = "color", default = RGBA(255, 255, 255, 255), },
		{ category = "Visual", id = "RolloverBorderColor", name = "Rollover border color", editor = "color", default = RGBA(0, 0, 0, 0), },
		{ category = "Visual", id = "PressedBackground", name = "Pressed background", editor = "color", default = RGBA(255, 255, 255, 255), },
		{ category = "Visual", id = "PressedBorderColor", name = "Pressed border color", editor = "color", default = RGBA(0, 0, 0, 0), },
		{ category = "Visual", id = "PressedOffset", name = "Pressed offset", editor = "number", default = 1, },
	},

	Background = RGBA(255, 255, 255, 255),
	FocusedBackground = RGBA(255, 255, 255, 255),
	MouseCursor = "CommonAssets/UI/HandCursor.tga",
	state = "mouse-out",
	ChildrenHandleMouse = false,
	RolloverOnFocus = true,
	action = false,
	touch_press_dist = 20*20, -- square for max move distance before press
	
	AltPressButton = "ButtonX",
	AltPressButtonUp = "-ButtonX",
	AltPressButtonDown = "+ButtonX",
}

---
--- Opens the button and sets up any necessary state.
---
--- If the button has an associated action with the "action" press effect, the action is retrieved from the actions host.
--- If the action is disabled, the button is set to disabled.
--- If the action has a gamepad hold behavior, the action is added to the actions host's hold buttons.
--- If the action has an alt action, the alt press flag is set to true.
--- Finally, the base XContextControl:Open() function is called.
---
--- @param ... any additional arguments to pass to XContextControl:Open()
function XButton:Open(...)
	local host = GetActionsHost(self, true)
	if not self.action and self.OnPressEffect == "action" then
		self.action = host and host:ActionById(self.OnPressParam) or nil
	end
	if self:IsActionDisabled(host) then
		self:SetEnabled(false)
	end
	if self.action and self.action.ActionGamepadHold and self.action.ActionGamepad then
		host.action_hold_buttons = host.action_hold_buttons  or {}
		host.action_hold_buttons[self.action.ActionId] = self
	end

	if self.action and self.action.OnAltAction then
		self.AltPress = true
	end
	XContextControl.Open(self, ...)
end

---
--- Checks if the button's associated action is disabled.
---
--- @param host table The actions host for the button.
--- @param ... any additional arguments to pass to the action's ActionState method.
--- @return boolean true if the action is disabled, false otherwise.
function XButton:IsActionDisabled(host, ...)
	return self.action and self.action:ActionState(host, ...) == "disabled"
end

---
--- Handles the press action for the button.
---
--- If the button has an alt press enabled, it checks if the alt press is active. If not, it returns without doing anything.
--- It then plays the action FX for the button.
--- If the button is not enabled and the press is not forced, it returns without doing anything.
--- If the alt press is active, it calls the `OnAltPress` function. Otherwise, it calls the `OnPress` function.
--- If the window state is not "destroying", it checks if the button's associated action is disabled. If so, it sets the button to disabled.
---
--- @param alt boolean Whether the alt press is active.
--- @param force boolean Whether the press is forced.
--- @param gamepad boolean Whether the press is from a gamepad.
function XButton:Press(alt, force, gamepad)
	if alt and not self.AltPress then return end
	self:PlayActionFX(force)
	if not self.enabled and not force then
		return
	end
	if alt then
		self:OnAltPress(gamepad)
	else
		self:OnPress(gamepad)
	end
	if self.window_state ~= "destroying" then
		local host = GetActionsHost(self, true)
		if self:IsActionDisabled(host) then
			self:SetEnabled(false)
		end
	end
end

---
--- Handles the press action for the button.
---
--- If the button has an "close" OnPressEffect, it finds the nearest XDialog parent and closes it with the OnPressParam as the close reason.
--- If the button has an associated action, it calls the action's OnAction method on the actions host.
---
--- @param gamepad boolean Whether the press is from a gamepad.
function XButton:OnPress(gamepad)
	local effect = self.OnPressEffect
	if effect == "close" then
		local win = self.parent
		while win and not win:IsKindOf("XDialog") do
			win = win.parent
		end
		if win then
			win:Close(self.OnPressParam ~= "" and self.OnPressParam or nil)
		end
	elseif self.action then
		local host = GetActionsHost(self, true)
		if host then
			host:OnAction(self.action, self, gamepad)
		end
	end
end

---
--- Handles the alt press action for the button.
---
--- If the button has an associated action with an `OnAltAction` method, it calls the `OnAltAction` method on the actions host.
---
--- @param gamepad boolean Whether the press is from a gamepad.
function XButton:OnAltPress(gamepad)
	if self.action and self.action.OnAltAction then
		local host = GetActionsHost(self, true)
		if host then
			self.action:OnAltAction(host, self, gamepad)
		end
	end
end

---
--- Handles the button down event for the XButton.
---
--- If the button is not enabled, it plays a sound effect and returns "break" to stop further processing.
--- If the button is in the "mouse-in" or "mouse-out" state, it changes the state to "pressed-in" and sets the mouse capture if the event is from a mouse.
--- If the button has a RepeatStart value greater than 0, it creates a thread that will repeatedly call the Press function until the button is released.
---
--- @param alt boolean Whether the alt key is pressed.
--- @param mouse boolean Whether the event is from a mouse.
--- @return string "break" to stop further processing of the event.
function XButton:OnButtonDown(alt, mouse)
	if alt and not self.AltPress then return end
	if not self.enabled then
		self:Press(alt, nil, not mouse) --play sound FX
		return "break"
	end
	if self.state == "mouse-in" or self.state == "mouse-out" then 
		self.state = "pressed-in"
		if mouse then
			self.desktop:SetMouseCapture(self)
		end
		self:Invalidate()
		if self.RepeatStart > 0 then
			self:DeleteThread("repeat")
			self:CreateThread("repeat", function(self, alt) 
				Sleep(self.RepeatStart)
				while self.state == "pressed-in" or self.state == "pressed-out" do
					self:Press(alt, nil, not mouse)
					Sleep(self.RepeatInterval)
				end
			end, self, alt)
		end
	end
	return "break"
end

---
--- Handles the button up event for the XButton.
---
--- If the button is in the "pressed-in" state, it changes the state to "mouse-in" and calls the `Press` function.
--- If the button is in the "pressed-out" state, it changes the state to "mouse-out" and calls the `Press` function.
---
--- @param alt boolean Whether the alt key is pressed.
--- @param mouse boolean Whether the event is from a mouse.
--- @return string "break" to stop further processing of the event.
function XButton:OnButtonUp(alt, mouse)
	if alt and not self.AltPress then return end
	if self.state == "pressed-in" then
		self.state = "mouse-in"
		self:Invalidate()
		if mouse then
			self.desktop:SetMouseCapture()
		end
		self:Press(alt, nil, not mouse)
	elseif self.state == "pressed-out" then 
		self.state = "mouse-out"
		self:Invalidate()
		if mouse then
			self.desktop:SetMouseCapture()
		end
	end
	return "break"
end

---
--- Handles the mouse button down event for the XButton.
---
--- If the left mouse button is pressed, it calls the `OnButtonDown` function with `alt` set to `false` and `mouse` set to `true`.
--- If the right mouse button is pressed, it calls the `OnButtonDown` function with `alt` set to `true` and `mouse` set to `true`.
---
--- @param pt table The position of the mouse cursor.
--- @param button string The mouse button that was pressed ("L" or "R").
--- @return string "break" to stop further processing of the event.
function XButton:OnMouseButtonDown(pt, button)
	if button == "L" then
		return self:OnButtonDown(false, true)
	elseif button == "R" then
		return self:OnButtonDown(true, true)
	end
end

---
--- Handles the mouse button up event for the XButton.
---
--- If the left mouse button is released, it calls the `OnButtonUp` function with `alt` set to `false` and `mouse` set to `true`.
--- If the right mouse button is released, it calls the `OnButtonUp` function with `alt` set to `true` and `mouse` set to `true`.
---
--- @param pt table The position of the mouse cursor.
--- @param button string The mouse button that was released ("L" or "R").
--- @return string "break" to stop further processing of the event.
function XButton:OnMouseButtonUp(pt, button)
	if button == "L" then
		return self:OnButtonUp(false, true)
	elseif button == "R" then
		return self:OnButtonUp(true, true)
	end
end

---
--- Sets the rollover state of the XButton.
---
--- When the rollover state is set to true, the button's state is updated to "mouse-in" or "pressed-in" depending on the current state.
--- When the rollover state is set to false, the button's state is updated to "mouse-out" or "pressed-out" depending on the current state.
--- The button's appearance is then invalidated to reflect the new state.
---
--- @param rollover boolean Whether the button is in a rollover state or not.
function XButton:OnSetRollover(rollover)
	XControl.OnSetRollover(self, rollover)
	if rollover then
		if self.state == "mouse-out" then
			self.state = "mouse-in"
		elseif self.state == "pressed-out" then
			self.state = "pressed-in"
		end
	else
		if self.state == "mouse-in" then
			self.state = "mouse-out"
		elseif self.state == "pressed-in" then
			self.state = "pressed-out"
		end
	end
	self:Invalidate()
end

---
--- Handles the loss of capture for the XButton.
---
--- When the button loses capture, its state is updated to reflect the new state. If the button was in a "pressed-in" state, it is updated to "mouse-in". If the button was in a "pressed-out" state, it is updated to "mouse-out". The button's appearance is then invalidated to reflect the new state.
---
--- @method OnCaptureLost
function XButton:OnCaptureLost()
	if self.state == "pressed-in" then
		self.state = "mouse-in"
	elseif self.state == "pressed-out" then
		self.state = "mouse-out"
	end
	self:Invalidate()
end

-- touch
---
--- Handles the beginning of a touch event on the XButton.
---
--- When the button is in the "mouse-in" or "mouse-out" state, this function is called to handle the start of a touch event. It updates the button's state to "pressed-out", records the start position and time of the touch, and then calls `OnTouchMoved` to handle the initial touch movement. The function then returns "capture" to indicate that the button has captured the touch event.
---
--- @param id number The unique identifier of the touch event.
--- @param pos Vector2 The initial position of the touch event.
--- @param touch table The touch event data.
--- @return string "capture" to indicate that the button has captured the touch event.
function XButton:OnTouchBegan(id, pos, touch)
	if self.state == "mouse-in" or self.state == "mouse-out" then
		touch.start_pos = pos
		touch.start_time = RealTime()
		self.state = "pressed-out"
		self:OnTouchMoved(id, pos, touch)
		return "capture"
	end
end

---
--- Handles the movement of a touch event on the XButton.
---
--- When the button has captured a touch event, this function is called to handle the movement of the touch. It checks if the touch has moved beyond the touch press distance, and if so, it checks if there is an ancestor of type XScrollArea. If there is, it cancels the touch event on the button and passes it to the scroll area instead.
---
--- If the touch remains within the touch press distance, the function updates the button's state based on whether the touch position is inside or outside the button's window. If the button was in the "pressed-in" state and the touch moves outside the window, the state is updated to "pressed-out". If the button was in the "pressed-out" state and the touch moves back inside the window, the state is updated to "pressed-in". The button's appearance is then invalidated to reflect the new state.
---
--- @param id number The unique identifier of the touch event.
--- @param pos Vector2 The current position of the touch event.
--- @param touch table The touch event data.
--- @return string "break" to indicate that the touch event has been handled.
function XButton:OnTouchMoved(id, pos, touch)
	if touch.capture == self then
		local dist_diff = pos:Dist2D2(touch.start_pos)
		if dist_diff > self.touch_press_dist then
			-- if there is an ancestor of type XScrollArea, allow it to be scrolled
			local scroll_area = GetParentOfKind(self, "XScrollArea")
			if scroll_area then
				self:OnTouchCancelled(id, pos, touch)
				touch.capture = nil -- release capture
				touch.target = scroll_area -- target is now the scroll area
				return scroll_area:OnTouchBegan(id, pos, touch)
			end
		end
		if self.state == "pressed-in" and not self:PointInWindow(pos) then
			self.state = "pressed-out"
			self:Invalidate()
			self:PlayHoverFX(false)
		elseif self.state == "pressed-out" and self:PointInWindow(pos) then
			self.state = "pressed-in"
			self:Invalidate()
			self:PlayHoverFX(true)
		end
		return "break"
	end
end

---
--- Handles the end of a touch event on the XButton.
---
--- This function is called when a touch event ends on the XButton. It first calls the `OnTouchMoved` function to update the button's state based on the final touch position. If the button was in the "pressed-in" state when the touch ended, the `Press` function is called to trigger the button's press action. Finally, the `OnTouchCancelled` function is called to handle any cleanup or state changes needed when the touch event is cancelled.
---
--- @param id number The unique identifier of the touch event.
--- @param pos Vector2 The final position of the touch event.
--- @param touch table The touch event data.
--- @return string "break" to indicate that the touch event has been handled.
function XButton:OnTouchEnded(id, pos, touch)
	self:OnTouchMoved(id, pos, touch)
	if self.state == "pressed-in" then
		self:Press(false)
	end
	return self:OnTouchCancelled(id, pos, touch)
end

---
--- Handles the cancellation of a touch event on the XButton.
---
--- This function is called when a touch event is cancelled on the XButton. It updates the button's state to "mouse-out" if it was not already in that state, plays the hover effect if the button was in the "pressed-in" state, and invalidates the button's appearance to reflect the new state.
---
--- @param id number The unique identifier of the touch event.
--- @param pos Vector2 The position of the touch event when it was cancelled.
--- @param touch table The touch event data.
--- @return string "break" to indicate that the touch event has been handled.
function XButton:OnTouchCancelled(id, pos, touch)
	if self.state ~= "mouse-out" then
		if self.state == "pressed-in" then
			self:PlayHoverFX(false)
		end
		self.state = "mouse-out"
		self:Invalidate()
		return "break"
	end
end

---
--- Handles keyboard and gamepad shortcuts for the XButton.
---
--- This function is called when a keyboard or gamepad shortcut is triggered for the XButton. It checks the shortcut and performs the appropriate action, such as triggering the button's press action or handling button down/up events.
---
--- @param shortcut string The name of the shortcut that was triggered.
--- @param source string The source of the shortcut (e.g. "keyboard", "gamepad").
--- @param ... any Additional arguments passed with the shortcut.
--- @return string "break" to indicate that the shortcut has been handled.
function XButton:OnShortcut(shortcut, source, ...)
	if shortcut == "Enter" or shortcut == "Space" or shortcut == "ButtonA" then
		self:Press(false)
		return "break"
	elseif self.AltPress and (shortcut == "Alt-Enter" or shortcut == "Alt-Space" or shortcut == self.AltPressButton) then
		self:Press(true)
		return "break"
	elseif shortcut == "+ButtonA" then
		return self:OnButtonDown(false)
	elseif shortcut == self.AltPressButtonDown then
		return self:OnButtonDown(true)
	elseif shortcut == "-ButtonA" then
		return self:OnButtonUp(false)
	elseif shortcut == self.AltPressButtonUp then
		return self:OnButtonUp(true)
	end
end

---
--- Calculates the background color of the XButton based on its current state.
---
--- @return table The background color to use for the XButton.
function XButton:CalcBackground()
	if not self.enabled then return self.DisabledBackground end
	if self.state == "pressed-in" or self.state == "pressed-out" then
		return self.PressedBackground
	end
	if self.state == "mouse-in" then
		return self.RolloverBackground
	end
	local FocusedBackground, Background = self.FocusedBackground, self.Background
	if FocusedBackground == Background then return Background end
	return self:IsFocused() and FocusedBackground or Background
end

---
--- Calculates the border color of the XButton based on its current state.
---
--- @return table The border color to use for the XButton.
function XButton:CalcBorderColor()
	if not self.enabled then return self.DisabledBorderColor end
	if self.state == "pressed-in" or self.state == "pressed-out" then
		return self.PressedBorderColor
	end
	if self.state == "mouse-in" then
		return self.RolloverBorderColor
	end
	local FocusedBorderColor, BorderColor = self.FocusedBorderColor, self.BorderColor
	if FocusedBorderColor == BorderColor then return BorderColor end
	return self:IsFocused() and FocusedBorderColor or BorderColor
end

--- Returns the rollover template for the XButton.
---
--- If the `RolloverTemplate` property is set, it returns that. Otherwise, it returns the rollover template from the button's `action` object, if it exists.
---
--- @return string The rollover template to use for the XButton.
function XButton:GetRolloverTemplate()
	local template = self.RolloverTemplate
	if template ~= "" then return template end
	local action = self.action
	return action and action:GetRolloverTemplate() or ""
end

---
--- Returns the rollover text for the XButton.
---
--- If the `RolloverText` property is set, it returns that. Otherwise, it returns the rollover text from the button's `action` object, if it exists. If the button is disabled, it returns the `RolloverDisabledText` property if set, otherwise the disabled rollover text from the `action` object.
---
--- @return string The rollover text to use for the XButton.
function XButton:GetRolloverText()
	local enabled = self:GetEnabled()
	local text = not enabled and self.RolloverDisabledText ~= "" and self.RolloverDisabledText or self.RolloverText
	if text ~= "" then return text end
	local action = self.action
	local disabled_text = action and action:GetRolloverDisabledText()
	return action and (not enabled and disabled_text ~= "" and disabled_text or action:GetRolloverText()) or ""
end

function OnMsg.ClassesPostprocess()
	if not config.GamepadAltPressUseButtonY then return end
	ClassDescendants("XButton", function(class_name, class)
		class.AltPressButton = "ButtonY"
		class.AltPressButtonUp = "-ButtonY"
		class.AltPressButtonDown = "+ButtonY"
	end)
	XButton.AltPressButton = "ButtonY"
	XButton.AltPressButtonUp = "-ButtonY"
	XButton.AltPressButtonDown = "+ButtonY"
end

----- XTextButton

DefineClass.XTextButton = {
	__parents = { "XButton", "XFrame", "XEmbedIcon", "XEmbedLabel" },
	properties = {
		{ category = "Image", id = "ColumnsUse", editor = "text", default = "aaaaa", }, -- 'help' is generated below
		{ category = "Image", id = "ShowGamepadShortcut", editor = "bool", default = false, },
		{ category = "Visual", id = "ShowKeyboardShortcut", editor = "bool", default = false, },
		{ category = "Visual", id = "KeyboardShortcutTextStyle", editor = "text", default = "", },
	},
	ContextUpdateOnOpen = true,
	LayoutMethod = "HList",
	LayoutHSpacing = 2,
	HandleMouse = true,
	SqueezeX = false,
	SqueezeY = false,
}

--- Initializes the XTextButton.
---
--- Sets the horizontal alignment of the label to be centered.
--- Sets the columns use property of the button based on the ColumnsUse property.
function XTextButton:Init()
	self.idLabel:SetHAlign("center")
	self:SetColumnsUse(self.ColumnsUse)
end

---
--- Handles the tick event for the hold button on the XTextButton.
---
--- If the button has an action with a gamepad hold action, this function updates the visibility and image of the hold shortcut icon based on the current hold progress.
---
--- @param i number The current hold progress, from 0 to the maximum hold time.
--- @param shortcut string The name of the gamepad button being held.
function XTextButton:OnHoldButtonTick(i, shortcut)
	if not self.action or not self.action.ActionGamepadHold then return end
	self.idHoldShortcut:SetVisible(not not i)
	
	if i then 
		self.idHoldShortcut:SetImage("UI/DesktopGamepad/hold" .. i)
	end
end

---
--- Opens the XTextButton and sets up any gamepad or keyboard shortcuts associated with the button's action.
---
--- If the button has an associated action with a gamepad shortcut, this function creates an image for the gamepad shortcut and an optional image for the gamepad hold shortcut.
---
--- If the button has an associated action with a keyboard shortcut, this function creates a label for the keyboard shortcut.
---
--- The visibility and appearance of the shortcut images/labels are controlled by the ShowGamepadShortcut and ShowKeyboardShortcut properties of the XTextButton.
---
--- @param self XTextButton The XTextButton instance.
function XTextButton:Open()
	XButton.Open(self)
	local action = self.action
	if action then
		local action_ui_style = action.ActionUIStyle
		if self.ShowGamepadShortcut and (action_ui_style == "auto" and GetUIStyleGamepad() or action_ui_style == "gamepad") and action.ActionGamepad ~= "" then
			local keys = SplitShortcut(action.ActionGamepad)
			for i = 1, #keys do
				local image_path, scale = GetPlatformSpecificImagePath(keys[i])
				local img = XImage:new({
					Id = "idActionShortcut",
					Image = image_path,
					ZOrder = 0,
					ImageScale = point(scale, scale),
					enabled = self.enabled,
				}, self)
				if action.ActionGamepadHold then
					local over_img = XImage:new({
						Id = "idHoldShortcut",
						Image = "UI/DesktopGamepad/hold0",
						ZOrder = 0,
						ImageScale = point(scale, scale),
						enabled = self.enabled,
					}, self)
				end
				img:Open()
				if action.ActionGamepadHold then
					over_img:Open()
				end
			end
		elseif self.ShowKeyboardShortcut and (action_ui_style == "auto" and not GetUIStyleGamepad() or action_ui_style == "keyboard") and action.ActionShortcut ~= "" then
			local label = XLabel:new({
				Id = "idActionShortcut",
				ZOrder = 0,
				TextStyle = self.KeyboardShortcutTextStyle ~= "" and self.KeyboardShortcutTextStyle or self.TextStyle,
				VAlign = "center",
				Translate = true,
				enabled = self.enabled,
			}, self):Open()
			local name = KeyNames[VKStrNamesInverse[action.ActionShortcut]]
			label:SetText(T{629765447024, "<name>", name = name})
		end
	end
end

--- Sets the text of the XTextButton.
---
--- @param self XTextButton The XTextButton instance.
--- @param text string The new text to set for the button.
function XTextButton:SetText(text)
	self.Text = text
	local label = self:ResolveId("idLabel")
	if label then
		label:SetDock(text == "" and "ignore" or false)
		label:SetText(text)
	end
end

local a_charcode = string.byte("a")
---
--- Sets the columns used for the button's visual state.
---
--- @param self XTextButton The XTextButton instance.
--- @param columns_use string The string of column characters to use for the button's visual state.
function XTextButton:SetColumnsUse(columns_use)
	local max = 1
	for i = 1, #columns_use do
		max = Max(max, string.byte(columns_use, i))
	end
	self.ColumnsUse = columns_use
	self.Columns = max - a_charcode + 1
	self:Invalidate()
end

--- Disables the ability to set the column for the XTextButton.
---
--- This function is intentionally disabled and will always assert false if called.
--- The column for the XTextButton is determined automatically based on the button's state.
--- Users should not attempt to manually set the column, as this could lead to unexpected behavior.
function XTextButton:SetColumn()
	assert(false)
end

--- Sets the rollover state of the XTextButton.
---
--- @param self XTextButton The XTextButton instance.
--- @param rollover boolean The new rollover state to set for the button.
function XTextButton:SetRollover(rollover)
	XButton.SetRollover(self, rollover)
	local label = self:ResolveId("idLabel")
	if label then
		label:SetRollover(rollover)
	end
end

---
--- Handles the rollover state change for the XTextButton.
---
--- This function is called when the rollover state of the XTextButton changes.
--- It forwards the rollover state change to the parent XButton class.
---
--- @param self XTextButton The XTextButton instance.
--- @param rollover boolean The new rollover state of the button.
function XTextButton:OnSetRollover(rollover)
	XButton.OnSetRollover(self, rollover)
end

local state_to_column = {
	["mouse-out"  ] = 1,
	["mouse-in"   ] = 2,
	["pressed-out"] = 3,
	["pressed-in" ] = 4,
	["disabled"   ] = 5,
}

--- Gets the column index for the XTextButton based on its current state.
---
--- The column index is determined by the button's enabled state and current state.
--- The column index is looked up in the `state_to_column` table, which maps button states to column indices.
--- If the button is disabled, the column index for the "disabled" state is used.
---
--- @param self XTextButton The XTextButton instance.
--- @return integer The column index for the button's current state.
function XTextButton:GetColumn()
	local column = state_to_column[self.enabled and self.state or "disabled"]
	return (string.byte(self.ColumnsUse, column) or a_charcode) - a_charcode + 1
end

do
	local columns_use_prop = table.find_value(XTextButton.properties, "id", "ColumnsUse")
	local column_to_state = table.invert(state_to_column)
	columns_use_prop.help = ""
	for i=1,#column_to_state do
		columns_use_prop.help = string.format("%s%d - %s\n", columns_use_prop.help, i, column_to_state[i])
	end
end

----- XStateButton

DefineClass.XStateButton = {
	__parents = { "XTextButton" },
	TextColor = RGB(32, 32, 32),
	IconColor = RGB(32, 32, 32),
	DisabledTextColor = RGBA(32, 32, 32, 128),
	DisabledIconColor = RGBA(32, 32, 32, 128),
	Icon = "CommonAssets/UI/check-40.tga",
	IconScale = point(480, 480),
	IconRows = 2,
}

--- Called when the state of the XStateButton changes.
---
--- @param self XStateButton The XStateButton instance.
--- @param state integer The new state of the button.
function XStateButton:OnRowChange(row)
end

--- Called when the XStateButton is pressed.
---
--- This function increments the IconRow of the button, wrapping around to 1 if the maximum IconRows is reached. It then calls the OnRowChange function with the new row index.
---
--- @param self XStateButton The XStateButton instance.
function XStateButton:OnPress()
	local row = self.IconRow + 1
	if row > self.IconRows then
		row = 1
	end
	self:SetIconRow(row)
	self:OnRowChange(row)
	XTextButton.OnPress(self)
end


----- XCheckButton

DefineClass.XCheckButton = {
	__parents = { "XStateButton" },
	properties = {
		{ category = "General", id = "Check", editor = "bool", default = false, },
		{ category = "General", id = "OnChange", name = "On change", editor = "func", params = "self, check" },
	},
	Background = RGBA(0, 0, 0, 0),
	RolloverBackground = RGBA(0, 0, 0, 0),
	FocusedBackground = RGBA(0, 0, 0, 0),
	PressedBackground = RGBA(0, 0, 0, 0),
}

--- Sets the check state of the XCheckButton.
---
--- @param self XCheckButton The XCheckButton instance.
--- @param check boolean The new check state of the button.
function XCheckButton:SetCheck(check)
	self:SetIconRow(check and 2 or 1)
end

--- Gets the check state of the XCheckButton.
---
--- @param self XCheckButton The XCheckButton instance.
--- @return boolean The check state of the button.
function XCheckButton:GetCheck()
	return self.IconRow ~= 1
end

XCheckButton.SetToggled = XCheckButton.SetCheck

--- Called when the check state of the XCheckButton changes.
---
--- @param self XCheckButton The XCheckButton instance.
--- @param check boolean The new check state of the button.
function XCheckButton:OnChange(check)
end

--- Called when the icon row of the XCheckButton changes.
---
--- @param self XCheckButton The XCheckButton instance.
--- @param state number The new icon row state.
function XCheckButton:OnRowChange(state)
	self:OnChange(state ~= 1)
end


----- XToggleButton

DefineClass.XToggleButton = {
	__parents = { "XTextButton" },

	properties = {
		{ category = "General", id = "Toggled", editor = "bool", default = false, },
		{ category = "General", id = "OnChange", name = "On change", editor = "func", params = "self, toggled" },
		{ category = "Visual", id = "ToggledBackground", name = "Toggled background", editor = "color", default = RGBA(0, 0, 0, 0), },
		{ category = "Visual", id = "ToggledBorderColor", name = "Toggled border color", editor = "color", default = RGBA(0, 0, 0, 0), },
	},
}

--- Called when the XToggleButton is pressed.
---
--- This function toggles the state of the button and calls the parent class's `OnPress` function.
---
--- @param self XToggleButton The XToggleButton instance.
function XToggleButton:OnPress()
	self:SetToggled(not self.Toggled)
	XTextButton.OnPress(self)
end

--- Sets the toggled state of the XToggleButton.
---
--- @param self XToggleButton The XToggleButton instance.
--- @param toggled boolean The new toggled state of the button.
function XToggleButton:SetToggled(toggled)
	toggled = toggled or false
	if self.Toggled ~= toggled then
		self.Toggled = toggled
		self:OnChange(self.Toggled)
		self:Invalidate()
	end
end

--- Called when the toggled state of the XToggleButton changes.
---
--- @param self XToggleButton The XToggleButton instance.
--- @param toggled boolean The new toggled state of the button.
function XToggleButton:OnChange(toggled)
end

--- Calculates the background color of the XToggleButton based on its toggled state.
---
--- If the button is toggled, the background color is set to the `ToggledBackground` property.
--- Otherwise, the background color is calculated using the `XTextButton.CalcBackground` function.
---
--- @param self XToggleButton The XToggleButton instance.
--- @return color The calculated background color.
function XToggleButton:CalcBackground()
	return self.Toggled and self.ToggledBackground or XTextButton.CalcBackground(self)
end

--- Calculates the border color of the XToggleButton based on its toggled state.
---
--- If the button is toggled, the border color is set to the `ToggledBorderColor` property.
--- Otherwise, the border color is calculated using the `XTextButton.CalcBorderColor` function.
---
--- @param self XToggleButton The XToggleButton instance.
--- @return color The calculated border color.
function XToggleButton:CalcBorderColor()
	return self.Toggled and self.ToggledBorderColor or XTextButton.CalcBorderColor(self)
end
