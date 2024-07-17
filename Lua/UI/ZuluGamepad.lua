
function OnMsg.XInputInited()
	--lock gamepad thumbsticks while not in gamepad mode to avoid moving the camera
	--(also see OnMsg.GamepadUIStyleChanged in MarsMessengeQuestionBox.lua)
	local lock = GetUIStyleGamepad() and 0 or 1
	hr.XBoxLeftThumbLocked = lock
	hr.XBoxRightThumbLocked = lock
	hr.GamepadMouseSensitivity = GetAccountStorageOptionValue("GamepadCursorMoveSpeed") or 11
	hr.GamepadMouseAcceleration = 400 -- in percent
	hr.GamepadMouseAccelerationMax = 1000 --  in percent (unlimited)
	hr.GamepadMouseAccelerationExponent = 200
	hr.GamepadMouseSpeedUp = 200 -- in percent
	hr.GamepadMouseSpeedUpTime = 1500
	hr.GamepadMouseSpeedDownTime = 200
	hr.GamepadMouseSpeedUpThreshold = 90
end

function OnMsg.GamepadUIStyleChanged()
	SetDisableMouseViaGamepad(not GetUIStyleGamepad(), "UIStyle")
	ObjModified("GamepadUIStyleChanged")
end

if FirstLoad then
ZuluMouseViaGamepadDisableReasons = false
ZuluMouseViaGamepadEnableReasons = false
ZuluMouseViaGamepadDisableRightClickReasons = false
end

function OnMsg.NewGame()
	ZuluMouseViaGamepadDisableReasons = GetUIStyleGamepad() and {} or { "UIStyle" }
	ZuluMouseViaGamepadEnableReasons = {}
	ZuluMouseViaGamepadDisableRightClickReasons = {}

	-- Some popups transcend game barriers (controller disconnected)
	local persistentDisablingPopups = {}
	for _, popup in ipairs(g_ZuluMessagePopup) do
		if popup.window_state ~= "destroying" then
			SetEnabledMouseViaGamepad(popup.GamepadVirtualCursor, popup)
			SetDisableMouseViaGamepad(not popup.GamepadVirtualCursor, popup)
		end
	end
end

function OnMsg.DoneGame()
	ZuluMouseViaGamepadDisableReasons = false
	ZuluMouseViaGamepadEnableReasons = false
	ZuluMouseViaGamepadDisableRightClickReasons = false
end

---
--- Disables or enables the mouse via gamepad for the specified reason.
---
--- @param disable boolean Whether to disable the mouse via gamepad.
--- @param reason string The reason for disabling/enabling the mouse via gamepad.
---
function SetDisableMouseViaGamepad(disable, reason)
	if not ZuluMouseViaGamepadDisableReasons then ZuluMouseViaGamepadDisableReasons = {} end

	local existingReasonIdx = table.find(ZuluMouseViaGamepadDisableReasons, reason)
	if existingReasonIdx and not disable then
		table.remove(ZuluMouseViaGamepadDisableReasons, existingReasonIdx)
	elseif not existingReasonIdx and disable then
		table.insert(ZuluMouseViaGamepadDisableReasons, reason)
	end
	
	local isEnabled = IsZuluMouseViaGamepadEnabled()
	ShowMouseViaGamepad(isEnabled)
end

---
--- Enables or disables the mouse via gamepad for the specified reason.
---
--- @param enable boolean Whether to enable the mouse via gamepad.
--- @param reason string The reason for enabling/disabling the mouse via gamepad.
---
function SetEnabledMouseViaGamepad(enable, reason)
	if not ZuluMouseViaGamepadEnableReasons then ZuluMouseViaGamepadEnableReasons = {} end

	local existingReasonIdx = table.find(ZuluMouseViaGamepadEnableReasons, reason)
	if not existingReasonIdx and enable then
		table.insert(ZuluMouseViaGamepadEnableReasons, reason)
	elseif existingReasonIdx and not enable then
		table.remove(ZuluMouseViaGamepadEnableReasons, existingReasonIdx)
	end
	
	local isEnabled = IsZuluMouseViaGamepadEnabled()
	ShowMouseViaGamepad(isEnabled)
end

---
--- Disables or enables the right-click functionality of the mouse via gamepad for the specified reason.
---
--- @param disable boolean Whether to disable the right-click functionality of the mouse via gamepad.
--- @param reason string The reason for disabling/enabling the right-click functionality of the mouse via gamepad.
---
function SetDisableMouseRightClickReason(disable, reason)
	if not ZuluMouseViaGamepadDisableRightClickReasons then ZuluMouseViaGamepadDisableRightClickReasons = {} end

	local existingReasonIdx = table.find(ZuluMouseViaGamepadDisableRightClickReasons, reason)
	if not existingReasonIdx and disable then
		table.insert(ZuluMouseViaGamepadDisableRightClickReasons, reason)
	elseif existingReasonIdx and not disable then
		table.remove(ZuluMouseViaGamepadDisableRightClickReasons, existingReasonIdx)
	end
end

---
--- Checks if the mouse via gamepad is currently enabled.
---
--- @return boolean true if the mouse via gamepad is enabled, false otherwise
---
function IsZuluMouseViaGamepadEnabled()
	if ZuluMouseViaGamepadDisableReasons and #ZuluMouseViaGamepadDisableReasons > 0 then return false end
	if not ZuluMouseViaGamepadEnableReasons or #ZuluMouseViaGamepadEnableReasons == 0 then return false end
	return true
end

DefineClass.ZuluMouseViaGamepad = {
	__parents = { "MouseViaGamepad" },
	
	LeftClickButton = "ButtonA",
	LeftClickButtonAlt = "TouchPadClick",
	RightClickButton = "ButtonX",
	DoubleClickTime = 250,
}

local function IsRSScrollButton(button)
	local button = GetInvertPDAThumbsShortcut(button)

	return button=="RightThumbUp" or button=="RightThumbUpLeft" or button=="RightThumbUpRight"   
		 or button=="RightThumbDown"  or button=="RightThumbDownLeft" or button=="RightThumbDownRight" 
end

local function GetRSScrollTarget(pt)
	local target =  terminal.desktop.modal_window:GetMouseTarget(pt)
	local scroll = target and GetParentOfKind(target, "XScrollArea")
	return scroll
end

local function ExecRSScrollFn(pt, fn, button, controller_id )
	if IsRSScrollButton(button)  then
		local scroll = GetRSScrollTarget(pt)
		if scroll then
			scroll[fn](scroll, button, controller_id)
			return "break"
		end		
		return true
	end	
end

---
--- Handles the OnXButtonDown event for the ZuluMouseViaGamepad class.
---
--- This function is called when an X button is pressed on the gamepad. It updates the mouse target, handles right-click scrolling, and dispatches mouse button down events.
---
--- @param button string The button that was pressed (e.g. "ButtonA", "ButtonX")
--- @param controller_id number The ID of the controller that triggered the event
--- @return string "break" if the event was handled, "continue" otherwise
---
function ZuluMouseViaGamepad:OnXButtonDown(button, controller_id)
	if not self.enabled then return end
	
	if button == self.LeftClickButtonAlt then
		button = self.LeftClickButton
	end

	local pt = GamepadMouseGetPos()
	local trg = terminal.desktop:UpdateMouseTarget(pt)
	local target = trg
	if IsKindOf(target, "XDragAndDropControl") and target.drag_win then
		target = target.drag_win
		if ExecRSScrollFn(pt, "OnXButtonDown", button, controller_id )  then
			return "break"	
		end
	end
	while target~=terminal.desktop do
		local res = target:OnXButtonDown(button, controller_id)
		if res=="break" then
			return "break"
		end	
		target = target.parent
	end
	
	if not self.visible then
		ForceHideMouseCursor("MouseViaGamepad")
		self:SetVisible(true)
		GamepadMouseSetPos(terminal.GetMousePos())
	end
	
	local mouse_btn = false
	if button == self.LeftClickButton then
		mouse_btn = "L"
	elseif button == self.RightClickButton then
		local leftTriggerOn = XInput.IsCtrlButtonPressed(controller_id, "LeftTrigger")
		local rightTriggerOff = XInput.IsCtrlButtonPressed(controller_id, "RightTrigger")
		local noTriggerOn = not leftTriggerOn and not rightTriggerOff
	
		if noTriggerOn and #(ZuluMouseViaGamepadDisableRightClickReasons or empty_table) == 0 then
			mouse_btn = "R"
		end
	end

	if mouse_btn then
		local now = now()
		local last_click_time = self.LastClickTimes[mouse_btn]
		self.LastClickTimes[mouse_btn] = now
		local is_double_click = last_click_time and (now - last_click_time) <= self.DoubleClickTime
		if is_double_click then
			local target = trg
			while target~=terminal.desktop do
				local res = target:OnMouseButtonDoubleClick( pt, mouse_btn, "gamepad")
				if res=="break" then
					return "break"
				end	
				target = target.parent
			end
			return terminal.MouseEvent("OnMouseButtonDoubleClick", pt, mouse_btn, "gamepad")
		else
			return terminal.MouseEvent("OnMouseButtonDown", pt, mouse_btn, "gamepad")
		end
	end
	
	return "continue"
end

--- Handles the XButton up event for the ZuluMouseViaGamepad control.
---
--- This function is called when an XButton (e.g. gamepad button) is released while the mouse cursor is being controlled by the gamepad.
---
--- It updates the mouse target, handles drag and drop events, and propagates the XButton up event to the target control and its parent controls until the desktop is reached.
---
--- @param button number The button that was released (e.g. self.LeftClickButton, self.RightClickButton)
--- @param controller_id number The ID of the gamepad controller that triggered the event
--- @return string "break" if the event was handled, "continue" otherwise
function ZuluMouseViaGamepad:OnXButtonUp(button, controller_id)
	if not self.enabled then return end

	if button == self.LeftClickButtonAlt then
		button = self.LeftClickButton
	end

	local pt = GamepadMouseGetPos()
	local target = terminal.desktop:UpdateMouseTarget(pt)
	if IsKindOf(target, "XDragAndDropControl") and target.drag_win then
		target = target.drag_win
		if ExecRSScrollFn(pt, "OnXButtonUp", button, controller_id ) then
			return "break"	
		end
	end
	while target and target~=terminal.desktop do
		local res = target:OnXButtonUp(button, controller_id)
		if res=="break" then
			return "break"
		end	
		target = target.parent
	end
	return MouseViaGamepad.OnXButtonUp(self, button, controller_id)
end

--- Handles the XButton repeat event for the ZuluMouseViaGamepad control.
---
--- This function is called when an XButton (e.g. gamepad button) is held down while the mouse cursor is being controlled by the gamepad.
---
--- It updates the mouse target, handles drag and drop events, and propagates the XButton repeat event to the target control and its parent controls until the desktop is reached.
---
--- @param button number The button that was held down (e.g. self.LeftClickButton, self.RightClickButton)
--- @param controller_id number The ID of the gamepad controller that triggered the event
--- @return string "break" if the event was handled, "continue" otherwise
function ZuluMouseViaGamepad:OnXButtonRepeat(button, controller_id)
	if not self.enabled then return end

	local pt = GamepadMouseGetPos()
	local target = terminal.desktop:UpdateMouseTarget(pt)
	if IsKindOf(target, "XDragAndDropControl") and target.drag_win then
		target = target.drag_win
		if ExecRSScrollFn(pt, "OnXButtonRepeat", button, controller_id ) then
			return "break"	
		end
	end
	
	while target and target~=terminal.desktop do
		local res = target:OnXButtonRepeat(button, controller_id)
		if res=="break" then
			return "break"
		end	
		target = target.parent
	end
	return "continue"
end

--- Handles the mouse position event for the ZuluMouseViaGamepad control.
---
--- This function is called when the mouse cursor position is updated while the mouse cursor is being controlled by the gamepad.
---
--- It returns "continue" to indicate that the event has not been handled and should be propagated further.
---
--- @param pt table The new mouse cursor position as a table with x and y fields
--- @return string "continue" to indicate the event has not been handled
function ZuluMouseViaGamepad:OnMousePos(pt)
	return "continue"
end

MouseViaGamepadHideSkipReasons["GamepadActive"] = true
MouseViaGamepadHideSkipReasons["MouseDisconnected"] = true

---
--- Shows or hides the virtual mouse cursor controlled by the gamepad.
---
--- @param show boolean True to show the virtual mouse cursor, false to hide it.
---
function ShowMouseViaGamepad(show)
	local mouse_win = GetMouseViaGamepadCtrl()
	if not mouse_win and show then
		mouse_win = ZuluMouseViaGamepad:new({}, terminal.desktop)
	end
	if mouse_win then
		if show then
			ForceHideMouseCursor("MouseViaGamepad")
			
			local _, val = terminal.desktop:GetMouseTarget(GamepadMouseGetPos())
			local cursor = val
			if (cursor or "") == "" then
				cursor = const.DefaultMouseCursor
			end

			mouse_win:SetCursorImage(cursor)
			mouse_win:SetEnabled(true)
			
			-- Consoles with no mouse attached will not have this thread active.
			-- We start the rollover thread and assign it both to the global and
			-- as managed by the UI in order to ensure it is cleaned up properly and
			-- also it wont duplicate if an actual mouse is connected to the console.
			if not IsValidThread(RolloverThread) then
				mouse_win:CreateThread("rollover-thread", MouseRollover)
				RolloverThread = mouse_win:GetThread("rollover-thread")
			end
		else
			DeleteMouseViaGamepad()
			UnforceHideMouseCursor("MouseViaGamepad")
			XDestroyRolloverWindow(true)
			terminal.desktop.last_mouse_pos = terminal.GetMousePos()
			terminal.SetMousePos(GamepadMouseGetPos())
		end
		hr.GamepadMouseEnabled = show
	end
end

DefineClass.VirtualCursorManager = {
	__parents = { "XWindow" },
	properties = {
		{ id = "Reason", editor = "text", default = "", help = "Reason for disable or enable of the virtual mouse." },
		{ id = "ActionType", name = "Enable", editor = "bool", default = true, help = "true: enable virtual mouse, false: disable virtual mouse" },
	}
}

---
--- Opens the virtual cursor manager window and enables or disables the virtual mouse cursor based on the ActionType property.
---
--- @param self VirtualCursorManager The virtual cursor manager instance.
---
function VirtualCursorManager:Open()
	XWindow.Open(self)
	if self.ActionType then
		SetEnabledMouseViaGamepad(true, self.Reason)
	else
		SetDisableMouseViaGamepad(true, self.Reason)
	end
end

---
--- Deletes the virtual cursor manager window and disables or enables the virtual mouse cursor based on the ActionType property.
---
--- @param self VirtualCursorManager The virtual cursor manager instance.
---
function VirtualCursorManager:OnDelete()
	if self.ActionType then
		SetEnabledMouseViaGamepad(false, self.Reason)
	else
		SetDisableMouseViaGamepad(false, self.Reason)
	end
end

function OnMsg.ClassesGenerate(classes)
	table.insert(classes.SplashScreen.__parents, "ZuluModalDialog")
end
	
local lCommonSplashText = SplashText
---
--- Displays a splash screen with the given arguments and disables the mouse via gamepad while the splash screen is open.
---
--- @param ... any Arguments to pass to the common splash text function.
--- @return table The splash screen dialog.
---
function SplashText(...)
	local dlg = lCommonSplashText(...)
	SetDisableMouseViaGamepad(true, "splash")
	dlg.OnDelete = function()
		SetDisableMouseViaGamepad(false, "splash")
	end
	return dlg
end

texts_to_add_in_loc = {
	--Additional Options
	T(613515802678, "Hide selection helpers"),
	T(498814044233, "Hides the selection helper texts in the center of the screen in Tactical View."),
}

---
--- Waits for a controller disconnected message and returns the controller ID.
---
--- This function creates a modal message box that is displayed on top of the loading screen, informing the user that a controller has been disconnected and they need to connect a controller to resume playing. The function then waits for the user to acknowledge the message and returns the controller ID that was disconnected.
---
--- @return number The ID of the controller that was disconnected.
---
function WaitControllerDisconnectedMessage()
	local dialog = CreateMessageBox(
		terminal.desktop,
		T{836013651979, "Active <controller> disconnected", controller = Platform.playstation and g_PlayStationWirelessControllerText or T(704811499954, "Controller")},
		Platform.playstation and T(306576723489, --[[PS controller message]] "Please connect a controller to resume playing.") or T(925406686039, "Please connect a controller to resume playing.")
	)
	dialog:SetZOrder(BaseLoadingScreen.ZOrder + 1)
	dialog:SetModal(true) -- needs to be a modal to battle loading screen
	dialog:SetDrawOnTop(true)
	local _, _, controller_id = dialog:Wait()
	return controller_id
end

---
--- Handles the case when a controller is disconnected during gameplay.
---
--- This function is called when a controller is disconnected while the game is running. It enables all controllers, waits for the user to acknowledge a message box indicating that a controller has been disconnected, and then enables only the disconnected controller.
---
--- If the game is not in a network game, the function also pauses the game while the user is waiting to reconnect the controller.
---
--- @return nil
---
function ConsolePlatformControllerDisconnected()
	XInput.ControllerEnable("all", true)
	if IsValidThread(SwitchControlQuestionThread) then return end

	SwitchControlQuestionThread = CreateRealTimeThread(function()
		if not netInGame then 
			SetPauseLayerPause(true, "ControllerDisconnected")
		end
		local controller_id
		while true do
			controller_id = WaitControllerDisconnectedMessage()
			if controller_id then
				break
			end
			Sleep(5)
		end
		XInput.ControllerEnable("all", false)
		XInput.ControllerEnable(controller_id, true)
		if not netInGame then
			SetPauseLayerPause(false, "ControllerDisconnected")
		end
	end)
end

local function lGetMousePosVirtualAware()
	if GetUIStyleGamepad() then
		if IsMouseViaGamepadActive() then
			return GamepadMouseGetPos()
		else
			return point20
		end
	end
	return false
end

-- Prevent moving the hardware mouse from showing rollovers etc.
local oldMouseEvent = XDesktop.MouseEvent
---
--- Handles mouse events for the desktop, switching controls to gamepad mode if a mouse button is pressed while in gamepad UI style.
---
--- @param event string The type of mouse event, such as "OnMouseButtonDown".
--- @param pt table The position of the mouse cursor, as a table with `x` and `y` fields.
--- @param button string The mouse button that was pressed or released.
--- @param meta string Metadata about the mouse event, such as whether it was triggered by a gamepad.
--- @param ... any Additional arguments passed to the mouse event handler.
--- @return any The result of calling the original `XDesktop.MouseEvent` function.
---
function XDesktop:MouseEvent(event, pt, button, meta, ...)
	if event == "OnMouseButtonDown" and GetUIStyleGamepad() and meta ~= "gamepad" then
		SwitchControls(false)
	end

	pt = lGetMousePosVirtualAware() or pt
	return oldMouseEvent(self, event, pt, button, meta, ...)
end

---
--- Checks if the cursor is currently within the window bounds.
---
--- @return boolean true if the cursor is within the window bounds, false otherwise
---
function IsCursorInWindow()
	local p = HardwareGetMousePos()
	local x, y = p:xy()
	--p is relative to top left window corner
	if x < 0 or y < 0 then return false end
	local r = UIL.GetScreenSize()
	local rx, ry = r:xy()
	if x - rx > 0 or y - ry > 0 then return false end
	
	return true
end

local function lMouseSwitchControlSwitchProc()
	local currentTime = RealTime()
	
	local previousHardwareMousePos = IsCursorInWindow() and HardwareGetMousePos()
	while true do
		local hardwareMousePos = IsCursorInWindow() and HardwareGetMousePos()
		
		if hardwareMousePos and previousHardwareMousePos then
			local scaledThreshold = MulDivRound(200, GetUIScale(), 1000)
			if hardwareMousePos:Dist(previousHardwareMousePos) > scaledThreshold then
				DelayedCall(0, SwitchControls, false)
				break
			end
		end
		
		if RealTime() - currentTime > 1000 then
			previousHardwareMousePos = hardwareMousePos
		end
		
		Sleep(15)
	end
end

if FirstLoad then
	HardwareGetMousePos = terminal.GetMousePos
	function terminal.GetMousePos()
		return lGetMousePosVirtualAware() or HardwareGetMousePos()
	end
	
	HardwareSetMousePos = terminal.SetMousePos
	function terminal.SetMousePos(p)
		local recreateSwitchThread = false
		if IsValidThread(MouseMoveToSwitchControlsThread) then
			DeleteThread(MouseMoveToSwitchControlsThread)
			MouseMoveToSwitchControlsThread = false
			recreateSwitchThread = true
		end
		
		HardwareSetMousePos(p)
		
		if recreateSwitchThread then
			MouseMoveToSwitchControlsThread = CreateRealTimeThread(lMouseSwitchControlSwitchProc)
		end
	end
end

---
--- Continuously updates the mouse position on the screen based on the current gamepad mouse position.
--- This thread runs in the background and updates the mouse position whenever it changes.
--- The parent object is notified of the new mouse position via the `OnMousePos` event.
---
--- @function ZuluMouseViaGamepad:UpdateMousePosThread
--- @return nil
function ZuluMouseViaGamepad:UpdateMousePosThread()
	--GamepadMouseSetPos(GamepadMouseGetPos())

	local previous_pos
	while true do
		WaitNextFrame()
		local pos = GamepadMouseGetPos()
		if pos ~= previous_pos then
			--terminal.SetMousePos(pos)
			self.parent:MouseEvent("OnMousePos", pos)
			
			previous_pos = pos
		end
	end
end

if FirstLoad then
MouseMoveToSwitchControlsThread = false
end

function OnMsg.GamepadUIStyleChanged()
	if IsValidThread(MouseMoveToSwitchControlsThread) then
		DeleteThread(MouseMoveToSwitchControlsThread)
	end
	if not GetUIStyleGamepad() then return end
	
	GamepadMouseSetPos(HardwareGetMousePos())
	MouseMoveToSwitchControlsThread = CreateRealTimeThread(lMouseSwitchControlSwitchProc)
end

---
--- Handles a new input packet from the gamepad.
--- This function is called when a new input packet is received from the gamepad.
--- It is an override of the common `OnXNewPacket` function.
---
--- @param _ any unused parameter
--- @param controller_id number the ID of the controller that sent the input packet
--- @param last_state table the previous state of the controller
--- @param current_state table the current state of the controller
--- @return nil
function MouseViaGamepad:OnXNewPacket(_, controller_id, last_state, current_state)
	--nop override common
end

function OnMsg.OnXInputControllerDisconnected(controller)
	XInput.ControllerEnable("all", true)
end

function OnMsg.OnXInputControllerConnected(controller)
	local _, id = GetActiveGamepadState()
	if id then
		XInput.ControllerEnable("all", false)
		XInput.ControllerEnable(id, true)
	end
end

local original_func = GatherNonBindableKeys
---
--- Removes the "gamepadActionFreeAimToggle" action ID from the list of non-bindable keys.
---
--- This function is an override of the original `GatherNonBindableKeys` function. It first calls the original function to get the list of non-bindable keys, then removes the "gamepadActionFreeAimToggle" action ID from the list before returning the modified list.
---
--- @return table a list of non-bindable keys, with the "gamepadActionFreeAimToggle" action ID removed
function GatherNonBindableKeys()
	local ret = original_func()
	table.remove_entry(ret, "ActionId", "gamepadActionFreeAimToggle") --some sort of system action that uses ActionBindable to hide from key rebind ui and blocks rebinding of F
	return ret
end