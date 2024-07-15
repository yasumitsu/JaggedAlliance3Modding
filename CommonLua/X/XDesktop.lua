DefineClass.XDesktop = {
	__parents = { "XActionsHost" },
	LayoutMethod = "Box",

	keyboard_focus = false,
	modal_window = false,
	modal_log = false,
	mouse_capture = false,
	touch = false,
	last_mouse_pos = false,
	last_mouse_target = false,
	inactive = false,
	mouse_target_update = false,
	last_event_at = false,
	terminal_target_priority = -1,
	layout_thread = false,
	mouse_target_thread = false,
	focus_logging_enabled = false,
	rollover_logging_enabled = false,
	
	HandleMouse = true,
	IdNode = true,
}

function XDesktop:Init()
	self.desktop = self
	self.focus_log = {}
	self.modal_log = {}
	self.touch = {}
	self.modal_window = self
end

---
--- Handles the logic when a window is leaving the desktop.
--- This function is responsible for propagating the `OnMouseLeft` event to the appropriate controls
--- when the mouse cursor leaves the bounds of a window.
---
--- @param win XWindow The window that is leaving the desktop.
---
function XDesktop:WindowLeaving(win)
	local last_target = self.last_mouse_target
	if last_target and last_target:IsWithin(win) then
		local current = last_target
		while current do
			current:OnMouseLeft(self.last_mouse_pos, last_target)
			if current == win then break end
			current = current.parent
		end
		repeat
			win = win.parent
		until not win or win.HandleMouse
		self.last_mouse_target = win
	end
end

---
--- Handles the logic when a window is leaving the desktop.
--- This function is responsible for propagating the `OnMouseLeft` event to the appropriate controls
--- when the mouse cursor leaves the bounds of a window.
---
--- @param win XWindow The window that is leaving the desktop.
---
function XDesktop:WindowLeft(win)
	if self.mouse_capture == win then
		self:SetMouseCapture(false)
	end
	self:RemoveModalWindow(win)
	self:RemoveKeyboardFocus(win)
	if RolloverControl == win then
		XDestroyRolloverWindow("immediate")
	end
	for id, touch in pairs(self.touch) do
		if touch.target == win then
			touch.target = nil
		end
		if touch.capture == win then
			touch.capture = nil
		end
	end
end

----- keyboard

---
--- Returns the next candidate for keyboard focus.
---
--- The function iterates through the focus log, starting from the most recent focus, and returns the first window that is within the modal window, is visible, and is enabled.
---
--- @return XWindow|boolean The next focus candidate, or `false` if no suitable candidate is found.
---
function XDesktop:NextFocusCandidate()
	for i = #self.focus_log, 1, -1 do
		local win = self.focus_log[i]
		if win:IsWithin(self.modal_window) and win:IsVisible() and win:GetEnabled() then
			return win
		end
	end
	return false
end

---
--- Restores the keyboard focus to the next available focus candidate.
---
--- This function is responsible for setting the keyboard focus to the next window that is within the modal window, is visible, and is enabled. It is typically called when the current keyboard focus is lost or removed.
---
--- @return nil
---
function XDesktop:RestoreFocus()
	self:SetKeyboardFocus(self:NextFocusCandidate())
end

---
--- Sets the keyboard focus to the specified window.
---
--- This function is responsible for managing the keyboard focus within the desktop. It updates the focus log, ensures the focus is within the modal window and is visible and enabled, and notifies the parent windows of the focus change.
---
--- @param focus XWindow|nil The window to set as the keyboard focus, or `nil` to clear the focus.
--- @return nil
---
function XDesktop:SetKeyboardFocus(focus)
	assert(not focus or focus:IsWithin(self))
	local last_focus = self.keyboard_focus
	if last_focus == focus or focus and not focus:IsWithin(self) then
		return
	end

	if self.focus_logging_enabled then
		print("New Focus:", FormatWindowPath(focus))
		print(GetStack(2))
	end

	if focus then
		table.remove_entry(self.focus_log, focus)
		table.insert(self.focus_log, focus or nil)
		if not focus:IsWithin(self.modal_window) or not focus:IsVisible() then
			return
		end
	end

	if self.inactive then
		self.keyboard_focus = focus
		return
	end

	self.keyboard_focus = focus
	local common_parent = XFindCommonParent(last_focus, focus)
	local win = last_focus
	while win and win ~= common_parent do
		win:OnKillFocus(focus)
		win = win.parent
	end
	win = focus
	while win and win ~= common_parent do
		win:OnSetFocus(focus)
		win = win.parent
	end
end

---
--- Removes the keyboard focus from the specified window and its children.
---
--- If the window or its children have the keyboard focus, this function will remove the focus and restore the previous focus.
---
--- @param win XWindow The window to remove the keyboard focus from.
--- @param children boolean If true, remove the focus from all children of the window as well.
--- @return nil
---
function XDesktop:RemoveKeyboardFocus(win, children)
	local is_focused = win:IsFocused(children)
	local log = self.focus_log
	if children then
		for i = #log, 1, -1 do
			if log[i]:IsWithin(win) then
				table.remove(log, i)
			end
		end
	else
		table.remove_entry(log, win)
	end
	if is_focused then
		self:RestoreFocus()
	end
end

---
--- Returns the current keyboard focus.
---
--- @return XWindow The window that currently has keyboard focus.
---
function XDesktop:GetKeyboardFocus()
	return self.keyboard_focus
end

---
--- Returns the current keyboard focus.
---
--- @return XWindow The window that currently has keyboard focus.
---
function GetKeyboardFocus()
	local desktop = terminal and terminal.desktop
	return desktop and desktop:GetKeyboardFocus()
end

---
--- Displays a question dialog to the user and switches the controls to the specified state if the user confirms.
---
--- @param state string The control state to switch to, either "gamepad" or "keyboard".
--- @param title string The title of the question dialog.
--- @param text string The text of the question dialog.
--- @param ok_text string The text for the "OK" button. Defaults to "Yes".
--- @param cancel_text string The text for the "Cancel" button. Defaults to "No".
--- @return string The result of the question dialog, either "ok" or "cancel".
---
function WaitSwitchControls(state, title, text, ok_text, cancel_text)
	ok_text = ok_text or T(1138, "Yes")
	cancel_text = cancel_text or T(1139, "No")
	if WaitQuestion(terminal.desktop, title, text, ok_text, cancel_text, {forced_ui_style = state}) == "ok" then
		SwitchControls(state == "gamepad")
	end
end

---
--- Handles keyboard events for the XDesktop.
---
--- This function is responsible for processing keyboard events for the XDesktop. It first checks if auto controller handling is enabled and if the event is an "OnXButtonDown" event. If so, it either displays a popup to ask the user to switch to gamepad controls or automatically switches to gamepad controls, depending on the configuration.
---
--- After handling the auto controller logic, the function iterates through the keyboard focus hierarchy, calling the `HandleKeyboard` method on each focused window. If any of the focused windows return "break", the function returns "break" to indicate that the event has been handled.
---
--- @param event string The type of keyboard event, such as "OnKeyDown" or "OnKeyUp".
--- @param button string The name of the button that was pressed or released.
--- @param ... Any additional arguments passed with the event.
--- @return string "break" if the event has been handled, nil otherwise.
---
function XDesktop:KeyboardEvent(event, button, ...)
	if config.AutoControllerHandling and event == "OnXButtonDown" and AccountStorage and not GetUIStyleGamepad() then
		if config.AutoControllerHandlingType == "popup" then
			if not IsValidThread(SwitchControlQuestionThread) then
				SwitchControlQuestionThread = CreateRealTimeThread(function()
					WaitSwitchControls("gamepad", T(383758760550, "Switch to controller?"), T(207085726945, "Are you sure you want to use a controller?"))
				end)
				return "break"
			end
		elseif config.AutoControllerHandlingType == "auto" then
			SwitchControls(true)
		end
	end

	self.last_event_at = RealTime()
	local target = self.keyboard_focus
	while target do
		if target.HandleKeyboard then
			if target[event](target, button, ...) == "break" then
				-- print(tostring(target), event, ...)
				return "break"
			end
		end
		target = target.parent
	end
end

---
--- Handles shortcut events for the XDesktop.
---
--- This function is responsible for processing shortcut events for the XDesktop. It first checks if the shortcut event came from a mouse source. If so, it iterates through the mouse capture hierarchy, calling the `OnShortcut` method on each focused window. If any of the focused windows return "break", the function returns "break" to indicate that the event has been handled.
---
--- If the shortcut event did not come from a mouse source, it iterates through the keyboard focus hierarchy, calling the `OnShortcut` method on each focused window. If any of the focused windows return "break", the function returns "break" to indicate that the event has been handled.
---
--- @param shortcut string The name of the shortcut that was triggered.
--- @param source string The source of the shortcut event, either "mouse" or "keyboard".
--- @param ... Any additional arguments passed with the event.
--- @return string "break" if the event has been handled, nil otherwise.
---
function XDesktop:OnShortcut(shortcut, source, ...)
	if source == "mouse" then
		local target = self.last_mouse_target or self.mouse_capture
		while target and target ~= self do
			if target.window_state ~= "destroying" then
				if target:OnShortcut(shortcut, source, ...) == "break" then
					return "break"
				end
			end
			target = target.parent
		end
	else
		local focus = self.keyboard_focus
		while focus and focus ~= self do
			if focus.HandleKeyboard then
				if focus:OnShortcut(shortcut, source, ...) == "break" then
					return "break"
				end
			end
			focus = focus.parent
		end
	end
end

---
--- Handles the system virtual keyboard event.
---
--- This function is called when the system virtual keyboard is activated or deactivated. It is responsible for resizing the console window to accommodate the virtual keyboard.
---
--- @function XDesktop:OnSystemVirtualKeyboard
---
function XDesktop:OnSystemVirtualKeyboard()
	ConsoleLogResize()
	ConsoleResize()
end

----- gamepad

---
--- Handles XDesktop events.
---
--- This function is responsible for processing XDesktop events. If the XDesktop is not inactive, it first checks if the mouse is not being controlled by a gamepad. If so, it resets the last mouse target and mouse position target. It then calls the `KeyboardEvent` function to handle the event.
---
--- @param event string The name of the event that was triggered.
--- @param ... Any additional arguments passed with the event.
--- @return any The result of the `KeyboardEvent` function.
---
function XDesktop:XEvent(event, ...)
	if not self.inactive then
		if not IsMouseViaGamepadActive() then
			self:SetLastMouseTarget(false)
			self:ResetMousePosTarget()
		end
		return self:KeyboardEvent(event, ...)
	end
end

----- mouse

---
--- Sets the mouse capture for the XDesktop.
---
--- This function is responsible for setting the mouse capture for the XDesktop. If the provided `win` parameter is not within the modal window, the mouse capture is set to `false`. The previous mouse capture is stored in the `old_capture` variable, and if it is not the same as the new capture, the `OnCaptureLost` function is called on the old capture.
---
--- @param win table|boolean The window to set as the mouse capture, or `false` to release the capture.
---
function XDesktop:SetMouseCapture(win)
	if not win or not win:IsWithin(self.modal_window) then
		win = false
	end
	local old_capture = self.mouse_capture
	if old_capture == win then return end
	self.mouse_capture = win
	if old_capture then
		old_capture:OnCaptureLost(self.last_mouse_pos)
	end
end

---
--- Returns the current mouse capture for the XDesktop.
---
--- The mouse capture is the window that is currently receiving mouse events. This function returns the window that is currently set as the mouse capture, or `false` if there is no mouse capture.
---
--- @return table|boolean The window that is currently set as the mouse capture, or `false` if there is no mouse capture.
---
function XDesktop:GetMouseCapture()
	return self.mouse_capture
end

---
--- Restores the modal window for the XDesktop.
---
--- This function is responsible for restoring the modal window for the XDesktop. It iterates through the `modal_log` table, which contains a list of modal windows, and finds the topmost visible modal window. It then sets this window as the new modal window using the `SetModalWindow` function.
---
--- @return nil
---
function XDesktop:RestoreModalWindow()
	local win
	local log = self.modal_log
	for i = #log,1,-1 do
		if log[i]:IsVisible() and (not win or log[i]:IsOnTop(win)) then
			win = log[i]
		end
	end
	self.desktop:SetModalWindow(win or self)
end

---
--- Sets the modal window for the XDesktop.
---
--- This function is responsible for setting the modal window for the XDesktop. It first checks if the provided `win` parameter is within the XDesktop and is not the current modal window. If the conditions are met, it removes the window from the `modal_log` table and adds it to the end of the table if it is not the XDesktop itself. It then checks if the window is visible and on top of the current modal window. If these conditions are met, it sets the `modal_window` property to the provided window and performs additional actions, such as cancelling any touch events, destroying the rollover window, and setting the keyboard and mouse focus.
---
--- @param win table The window to set as the modal window.
--- @return nil
---
function XDesktop:SetModalWindow(win)
	if not win or not win:IsWithin(self) or win == self.modal_window then
		return
	end

	table.remove_entry(self.modal_log, win)
	if win ~= self then
		self.modal_log[#self.modal_log + 1] = win
	end

	if not win:IsVisible() or not win:IsOnTop(self.modal_window) then
		return
	end

	if self.focus_logging_enabled then
		print("Modal window:", FormatWindowPath(win))
	end
	self.modal_window = win
	
	for id, touch in pairs(self.touch) do
		if not touch.capture and not touch.target:IsWithin(win) then
			touch.target:OnTouchCancelled(id, touch.pos, touch)
			touch.target = nil
		end
	end

	if RolloverControl and not RolloverControl:IsWithin(win) then
		XDestroyRolloverWindow("immediate")
	end

	if self.keyboard_focus and not self.keyboard_focus:IsWithin(win) then
		self:SetKeyboardFocus(false)
	end
	self:RestoreFocus()

	if self.mouse_capture and not self.mouse_capture:IsWithin(win) then
		self:SetMouseCapture(false)
	end
	self:UpdateMouseTarget()
end

---
--- Removes the specified modal window from the XDesktop.
---
--- This function is responsible for removing the specified modal window from the `modal_log` table. If the specified window is the current modal window, it sets the `modal_window` property to `false`, calls `RestoreModalWindow()` to restore the previous modal window, and asserts that a modal window is set.
---
--- @param win table The window to remove from the modal log.
--- @return nil
---
function XDesktop:RemoveModalWindow(win)
	table.remove_entry(self.modal_log, win)
	if self.modal_window == win then
		self.modal_window = false
		self:RestoreModalWindow()
		assert(self.modal_window)
	end
end

---
--- Returns the current modal window.
---
--- @return table The current modal window.
---
function XDesktop:GetModalWindow()
	return self.modal_window
end

if FirstLoad then
	prev_cursor = false
end

---
--- Updates the mouse cursor based on the current mouse target.
---
--- This function is responsible for determining the appropriate mouse cursor to display based on the current mouse target. It first retrieves the mouse target and cursor from the modal window, or uses the mouse capture target if it exists. It then compares the current cursor to the previous cursor and updates the UI mouse cursor if it has changed.
---
--- @param pt table The current mouse position.
--- @return table The current mouse target.
---
function XDesktop:UpdateCursor(pt)
	pt = pt or self.last_mouse_pos
	if not pt then return end
	local target, cursor = self.modal_window:GetMouseTarget(pt)
	target = target or self.modal_window
	if self.mouse_capture and target ~= self.mouse_capture then
		cursor = self.mouse_capture:GetMouseCursor()
		target = false
	end
	
	local curr_cursor = cursor or const.DefaultMouseCursor
	if prev_cursor ~= curr_cursor then
		SetUIMouseCursor(curr_cursor)
		Msg("MouseCursor", curr_cursor)
		prev_cursor = curr_cursor
	end
	return target
end

---
--- Sets the last mouse target and triggers the appropriate mouse enter/leave events.
---
--- This function is responsible for updating the last mouse target and triggering the appropriate mouse enter and leave events. It first checks if the last mouse target has changed, and if so, it invalidates the previous and current targets to trigger a redraw. It then walks up the parent hierarchy of the previous and current targets, triggering the OnMouseLeft and OnMouseEnter events as appropriate.
---
--- @param target table The new mouse target.
--- @param pt table The current mouse position.
---
function XDesktop:SetLastMouseTarget(target, pt)
	local last_target = self.last_mouse_target
	if last_target == target then return end
	
	pt = pt or self.last_mouse_pos
	assert(not self.mouse_target_update, "Recursive mouse target update!")
	
	if self.rollover_logging_enabled then
		print("MouseTarget:", FormatWindowPath(target))
		if last_target then last_target:Invalidate() end
		if target then target:Invalidate() end
	end
	
	self.mouse_target_update = true
	self.last_mouse_target = target
	local common_parent = XFindCommonParent(last_target, target)
	local win = last_target
	while win and win ~= common_parent do
		win:OnMouseLeft(pt, last_target)
		win = win.parent
	end
	win = target
	while win and win ~= common_parent do
		win:OnMouseEnter(pt, target)
		win = win.parent
	end
	self.mouse_target_update = false
end

---
--- Updates the mouse target and cursor.
---
--- This function is responsible for updating the current mouse target and cursor. It first checks the current mouse position and updates the cursor accordingly. It then sets the last mouse target using the `SetLastMouseTarget` function, passing the updated target and mouse position.
---
--- @param pt table The current mouse position.
--- @return table The new mouse target.
function XDesktop:UpdateMouseTarget(pt)
	pt = pt or self.last_mouse_pos
	local target = self:UpdateCursor(pt) or false
	self:SetLastMouseTarget(target, pt)
	
	return target or self.mouse_capture
end

---
--- Handles mouse events on the XDesktop.
---
--- This function is responsible for updating the mouse target and cursor when a mouse event occurs. It first updates the mouse target using the `UpdateMouseTarget` function, passing the current mouse position. It then checks if the event is a mouse button down event and the user is using a gamepad. If so, it handles the auto controller handling configuration, either by showing a popup to switch to keyboard/mouse controls or automatically switching the controls.
---
--- Finally, it triggers the `OnMouseButtonDown`, `OnMouseButtonUp`, `OnMouseMove`, or `OnMouseWheel` event on the target window and its parent windows, until a window returns "break" to stop the event propagation.
---
--- @param event string The type of mouse event, such as "OnMouseButtonDown", "OnMouseButtonUp", "OnMouseMove", or "OnMouseWheel".
--- @param pt table The current mouse position.
--- @param button string The mouse button that was pressed or released.
--- @param time string The time of the mouse event, either "gamepad" or a number.
function XDesktop:MouseEvent(event, pt, button, time)
	local target = self:UpdateMouseTarget(pt)
	if config.AutoControllerHandling and event == "OnMouseButtonDown" and GetUIStyleGamepad() and (button == "L" or button == "R")
		and not GetParentOfKind(target, "DeveloperInterface")
		and not GetParentOfKind(target, "XPopupMenu")
		and not GetParentOfKind(target, "XBugReportDlg")
		and time ~= "gamepad"
	then
		if config.AutoControllerHandlingType == "popup" then
			if not IsValidThread(SwitchControlQuestionThread) then
				SwitchControlQuestionThread = CreateRealTimeThread(function()
					ForceShowMouseCursor("control scheme change")
					WaitSwitchControls("keyboard", T(477820487236, "Switch to mouse?"), T(184341668469, "Are you sure you want to switch to keyboard/mouse controls?"))
					UnforceShowMouseCursor("control scheme change")
				end)
				return "break"
			end
		elseif config.AutoControllerHandlingType == "auto" then
			SwitchControls(false)
		end
	end
	
	self.last_mouse_pos = pt
	self.last_event_at = RealTime()

	while target do
		if target.window_state ~= "destroying" then
			if target[event](target, pt, button) == "break" then
				-- print(event, button, pt, _GetUIPath(target))
				--[[
				if event == "OnMouseButtonDown" then
					local info = debug.getinfo(target[event])
					print("\t", info.short_src, info.linedefined)
				end
				--]]
				return "break"
			end
		end
		target = target.parent
	end
end

--- Resets the last known mouse position and target.
---
--- This function is used to clear the internal state related to the last mouse position and target. It is typically called when the mouse state needs to be reset, such as when the application loses focus or is minimized.
---
--- @function XDesktop:ResetMousePosTarget
--- @return nil
function XDesktop:ResetMousePosTarget()
	self.last_mouse_pos = false
	self.last_mouse_target = false
end

----- activation

---
--- Activates the XDesktop instance after it has been deactivated.
---
--- This function is called when the application becomes active again, such as when it is restored from minimized state. It resets the internal state of the XDesktop instance, including restoring keyboard focus and clearing the inactive flag.
---
--- @function XDesktop:OnSystemActivate
--- @return nil
function XDesktop:OnSystemActivate()
	if self.inactive then
		self:KeyboardEvent("OnSetFocus")
		self.inactive = false
		Msg("SystemActivate")
	end
end

---
--- Deactivates the XDesktop instance when the application becomes inactive.
---
--- This function is called when the application becomes inactive, such as when it is minimized. It sets the internal inactive flag, releases the mouse capture, and sends a "OnKillFocus" keyboard event to notify the UI that the application has lost focus.
---
--- @function XDesktop:OnSystemInactivate
--- @return nil
function XDesktop:OnSystemInactivate()
	if not self.inactive then
		self.inactive = true
		self:KeyboardEvent("OnKillFocus")
		self:SetMouseCapture(false)
		Msg("SystemInactivate")
	end
end

---
--- Notifies the XDesktop instance that the application has been minimized.
---
--- This function is called when the application is minimized, such as when the user clicks the minimize button. It sends a "SystemMinimize" message to notify the UI that the application has been minimized.
---
--- @function XDesktop:OnSystemMinimize
--- @return nil
function XDesktop:OnSystemMinimize()
	Msg("SystemMinimize")
end

---
--- Handles the system size change event for the XDesktop instance.
---
--- This function is called when the size of the application window changes. It updates the scale and size of the XDesktop instance to match the new window size, and sends a "SystemSize" message to notify the UI of the change.
---
--- @param pt point The new window size.
--- @return nil
function XDesktop:OnSystemSize(pt)
	local x, y = pt:xy()
	if x == 0 or y == 0 then
		return
	end
	local scale = GetUIScale(pt)
	self:SetOutsideScale(point(scale, scale))
	self:SetBox(0, 0, x, y)
	self:InvalidateMeasure()
	self:InvalidateLayout()
	Msg("SystemSize", pt)
end

---
--- Notifies the XDesktop instance that the mouse cursor has entered the application window.
---
--- This function is called when the mouse cursor enters the application window. It sends a "MouseInside" message to notify the UI that the mouse is inside the application.
---
--- @function XDesktop:OnMouseInside
--- @return nil
function XDesktop:OnMouseInside()
	Msg("MouseInside")
end

---
--- Notifies the XDesktop instance that the mouse cursor has left the application window.
---
--- This function is called when the mouse cursor leaves the application window. It sends a "MouseOutside" message to notify the UI that the mouse is outside the application.
---
--- @function XDesktop:OnMouseOutside
--- @return nil
function XDesktop:OnMouseOutside()
	Msg("MouseOutside")
end

---
--- Handles file drop events for the XDesktop instance.
---
--- This function is called when a file is dropped onto the application window. It checks if the file has a ".sav" or ".fbx" extension, and performs the appropriate action:
--- - If the file has a ".sav" extension, it loads the game state from the saved file.
--- - If the file has a ".fbx" extension, it opens the scene import editor with the dropped file.
---
--- @param filename string The path of the dropped file.
--- @return nil
function XDesktop:OnFileDrop(filename)
	if Platform.developer or Platform.asserts then
		if string.ends_with(filename, ".sav", true) then
			CreateRealTimeThread(function()
				WaitDataLoaded()
				local err = LoadGame(filename, { save_as_last = true })
				if err then
					OpenPreGameMainMenu()
				end
			end)
		end
		if string.ends_with(filename, ".fbx", true) then
			OpenSceneImportEditor(filename)
		end
	end
end

-- touch

---
--- Handles touch events for the XDesktop instance.
---
--- This function is called when a touch event occurs on the application window. It manages the state of touch events, including tracking touch points, capturing touch events, and dispatching touch events to the appropriate UI elements.
---
--- @param event string The type of touch event, such as "OnTouchBegan", "OnTouchMoved", "OnTouchEnded", or "OnTouchCancelled".
--- @param id number The unique identifier of the touch point.
--- @param pos table The position of the touch point, represented as a table with `x` and `y` fields.
--- @return string|nil The result of the touch event handling, which can be "capture" to indicate that the touch event has been captured, or nil if the touch event was not handled.
function XDesktop:TouchEvent(event, id, pos)
	local touch = self.touch[id]
	if touch then
		touch.event = event
		touch.pos = pos
	else
		touch = { id = id, event = event, pos = pos }
		self.touch[id] = touch
	end
	if event == "OnTouchEnded" or event == "OnTouchCancelled" then
		self.touch[id] = nil
	end
	
	local result
	if touch.capture then
		result = touch.capture[event](touch.capture, id, pos, touch)
	end
	
	if not result then
		local target = self:UpdateMouseTarget(pos)
		while target do
			if target.window_state ~= "destroying" then
				touch.target = target
				result = target[event](target, id, pos, touch)
				if result then
					break
				end
			end
			target = target.parent
		end
	end
	if result == "capture" then
		touch.capture = touch.target
		result = "break"
	end
	return result
end

-- draw

local UIL = UIL
---
--- Marks the XDesktop instance as invalidated, triggering a redraw of the UI.
---
--- This function is called when the state of the XDesktop instance has changed in a way that requires the UI to be redrawn. It sets the `invalidated` flag to `true` and calls the `UIL.Invalidate()` function to trigger the redraw.
---
--- @function XDesktop:Invalidate
--- @return nil
function XDesktop:Invalidate()
	if self.invalidated then return end
	self.invalidated = true
	UIL.Invalidate()
end

if false then -- debug invalidation
	IgnoreInvalidateSources = {
		"DeveloperInterface.lua",
		"uiConsoleLog.lua",
		"XControl.lua.* SetText",
		"KeyboardEventDispatch",
		"method ChangeHappiness",
	}
	function XDesktop:Invalidate()
		if not self.invalidated then
			local stack = GetStack()
			local show = true
			for _, text in ipairs(IgnoreInvalidateSources) do
				if stack:find(text) then
					show = false
					break
				end
			end
			if show then
				self.invalidated = true
				print(stack)
			end
		end
		UIL.Invalidate()
	end
	function XTranslateText:OnTextChanged(text)
		if not GetParentOfKind(self, "DeveloperInterface") then
			print(string.concat(" ", "TEXT CHANGE", self.text, "-->", text))
		end
	end
end

---
--- Marks the XDesktop instance as requiring a measure update, triggering a layout update.
---
--- This function is called when the state of the XDesktop instance has changed in a way that requires the layout to be recalculated. It sets the `measure_update` flag to `true` and calls the `XActionsHost.InvalidateMeasure()` function to trigger the layout update.
---
--- @param child XControl The child control that requires a measure update.
--- @return nil
function XDesktop:InvalidateMeasure(child)
	if self.measure_update then return end
	XActionsHost.InvalidateMeasure(self, child)
	if self.invalidated then return end
	self:RequestLayout()
end

---
--- Marks the XDesktop instance as requiring a layout update, triggering a layout recalculation.
---
--- This function is called when the state of the XDesktop instance has changed in a way that requires the layout to be recalculated. It sets the `layout_update` flag to `true` and calls the `XActionsHost.InvalidateLayout()` function to trigger the layout update.
---
--- @param self XDesktop The XDesktop instance that requires a layout update.
--- @return nil
function XDesktop:InvalidateLayout()
	if self.layout_update then return end
	XActionsHost.InvalidateLayout(self)
	if self.invalidated then return end
	self:RequestLayout()
end

---
--- Measures and lays out the XDesktop instance.
---
--- This function is responsible for updating the measure and layout of the XDesktop instance. It first calls `UpdateMeasure()` to update the measure of the desktop, then calls `UpdateLayout()` to update the layout, and finally calls `UpdateMouseTarget()` to update the mouse target. If the `measure_update` or `layout_update` flags are set, it calls `UpdateMeasure()` and `UpdateLayout()` again to ensure the layout is fully updated.
---
--- @param self XDesktop The XDesktop instance to measure and layout.
--- @return nil
function XDesktop:MeasureAndLayout()
	local w, h = self.box:sizexyz()
	self:UpdateMeasure(w, h)
	self:UpdateLayout()
	self:UpdateMouseTarget()
	if self.measure_update or self.layout_update then
		self:UpdateMeasure(w, h)
		self:UpdateLayout()
		self:UpdateMouseTarget()
	end
end

---
--- Requests a layout update for the XDesktop instance.
---
--- This function is responsible for triggering a layout update for the XDesktop instance. If there is a valid layout thread, it wakes up the thread to perform the layout update. If there is no valid layout thread, it creates a new real-time thread that will continuously update the layout as long as the XDesktop instance is active.
---
--- The layout update is performed by calling the `MeasureAndLayout()` function, which updates the measure and layout of the desktop. If there are any pending redraws, the layout update is skipped to avoid potential infinite loops.
---
--- @param self XDesktop The XDesktop instance that requires a layout update.
--- @return nil
function XDesktop:RequestLayout()
	if IsValidThread(self.layout_thread) then
		Wakeup(self.layout_thread)
	else
		self.layout_thread = CreateRealTimeThread(function(self)
			while true do
				if next(TextStyles) and not self.invalidated then -- if there is a redraw pending let it do the MeasureAndLayout
					PauseInfiniteLoopDetection("XDesktop.MeasureAndLayout")
					procall(self.MeasureAndLayout, self)
					ResumeInfiniteLoopDetection("XDesktop.MeasureAndLayout")
				end
				WaitWakeup()
			end
		end, self)
		if Platform.developer then
			ThreadsSetThreadSource(self.layout_thread, "LayoutThread")
		end
	end
end

---
--- Requests an update to the mouse target for the XDesktop instance.
---
--- This function is responsible for triggering an update to the mouse target for the XDesktop instance. If there is a valid mouse target thread, it wakes up the thread to perform the mouse target update. If there is no valid mouse target thread, it creates a new real-time thread that will continuously update the mouse target as long as the XDesktop instance is active.
---
--- The mouse target update is performed by calling the `UpdateMouseTarget()` function, which updates the mouse target of the desktop.
---
--- @param self XDesktop The XDesktop instance that requires a mouse target update.
--- @return nil
function XDesktop:RequestUpdateMouseTarget()
	if IsValidThread(self.mouse_target_thread) then
		Wakeup(self.mouse_target_thread)
	else
		self.mouse_target_thread = CreateRealTimeThread(function(self)
			while true do
				procall(self.UpdateMouseTarget, self)
				WaitWakeup()
			end
		end, self)
	end
end

--- Renders the XDesktop instance.
---
--- This function is responsible for rendering the XDesktop instance. It first checks if there are any pending text styles to be rendered. If there are, it pauses the infinite loop detection, calls the `MeasureAndLayout()` function to update the measure and layout of the desktop, calls the `DrawWindow()` function to draw the desktop, and then resumes the infinite loop detection.
---
--- @param self XDesktop The XDesktop instance to be rendered.
--- @return nil
function XRender()
	if not next(TextStyles) then return end
	
	PauseInfiniteLoopDetection("XRender")
	local desktop = terminal.desktop
	desktop:MeasureAndLayout()
	desktop:DrawWindow(desktop.box)
	ResumeInfiniteLoopDetection("XRender")
end

-- start

function OnMsg.Start()
	terminal.desktop = XDesktop:new()
	terminal.AddTarget(terminal.desktop)
	UIL.Register("XRender", terminal.desktop.terminal_target_priority)
	terminal.desktop:OnSystemSize(UIL.GetScreenSize())
	terminal.desktop:Open()
	Msg("DesktopCreated")
end

-- margin update

function OnMsg.EngineOptionsSaved()
	local desktop = terminal.desktop
	if desktop then
		desktop:InvalidateMeasure()
		desktop:InvalidateLayout()
	end
end

-- debug

if Platform.developer then
	function FormatWindowPath(win)
		if not win then return "" end
		local path = {}
		repeat
			table.insert(path, 1, _InternalTranslate(T(357840043382, "<class> <Id>"), win, false))
			win = win.parent
		until not win
		return table.concat(path, " / ")
	end
end
