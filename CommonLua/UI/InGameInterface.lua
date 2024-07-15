function OnMsg.Autorun()
	InGameInterface.InitialMode = config.InitialInGameInterfaceMode or config.InGameSelectionMode
end

DefineClass.InGameInterface = {
	__parents = { "XDialog" }, 
	mode = false,
	mode_dialog = false,
	Dock = "box",
}

---
--- Opens the InGameInterface dialog and sets up the initial state.
---
--- @param self InGameInterface The InGameInterface instance.
--- @param ... Any additional arguments to pass to the XDialog:Open() function.
---
function InGameInterface:Open(...)
	XDialog.Open(self, ...)
	self:SetFocus()
	ShowMouseCursor("InGameInterface")
	Msg("InGameInterfaceCreated", self)
end

---
--- Closes the InGameInterface dialog and hides the mouse cursor.
---
--- @param self InGameInterface The InGameInterface instance.
--- @param ... Any additional arguments to pass to the XDialog:Close() function.
---
function InGameInterface:Close(...)
	XDialog.Close(self, ...)
	HideMouseCursor("InGameInterface")
end

---
--- Handles the OnXButtonDown event for the InGameInterface dialog.
---
--- If the InGameInterface dialog is the modal window and has a mode dialog set, this function
--- forwards the OnXButtonDown event to the mode dialog.
---
--- @param self InGameInterface The InGameInterface instance.
--- @param button number The button that was pressed (1 = left, 2 = right, 3 = middle).
--- @param controller_id number The ID of the controller that triggered the event.
--- @return boolean True if the event was handled, false otherwise.
---
function InGameInterface:OnXButtonDown(button, controller_id)
	if self.desktop:GetModalWindow() == self.desktop and self.mode_dialog then
		return self.mode_dialog:OnXButtonDown(button, controller_id)
	end
end

---
--- Handles the OnXButtonUp event for the InGameInterface dialog.
---
--- If the InGameInterface dialog is the modal window and has a mode dialog set, this function
--- forwards the OnXButtonUp event to the mode dialog.
---
--- @param self InGameInterface The InGameInterface instance.
--- @param button number The button that was released (1 = left, 2 = right, 3 = middle).
--- @param controller_id number The ID of the controller that triggered the event.
--- @return boolean True if the event was handled, false otherwise.
---
function InGameInterface:OnXButtonUp(button, controller_id)
	if self.desktop:GetModalWindow() == self.desktop and self.mode_dialog then
		return self.mode_dialog:OnXButtonUp(button, controller_id)
	end
end

---
--- Handles the OnShortcut event for the InGameInterface dialog.
---
--- If the InGameInterface dialog is the modal window and has a mode dialog set, this function
--- forwards the OnShortcut event to the mode dialog.
---
--- @param self InGameInterface The InGameInterface instance.
--- @param shortcut string The shortcut that was triggered.
--- @param source string The source of the shortcut (e.g. "keyboard", "controller").
--- @param ... Any additional arguments to pass to the mode dialog's OnShortcut function.
--- @return boolean True if the event was handled, false otherwise.
---
function InGameInterface:OnShortcut(shortcut, source, ...)
	local desktop = self.desktop
	if desktop:GetModalWindow() == desktop and self.mode_dialog and self.mode_dialog:GetVisible() and desktop.keyboard_focus and not desktop.keyboard_focus:IsWithin(self.mode_dialog) then
		return self.mode_dialog:OnShortcut(shortcut, source, ...)
	end
end

---
--- Sets the mode of the InGameInterface dialog.
---
--- If the current mode dialog is set, it will be closed before the new mode dialog is opened.
--- If a mode string is provided, a new mode dialog will be created and opened.
--- If a mode dialog instance is provided, it will be set as the new mode dialog.
---
--- @param self InGameInterface The InGameInterface instance.
--- @param mode_or_dialog string|XDialog The mode to set, or the mode dialog instance to use.
--- @param context table Optional context to pass to the mode dialog.
---
function InGameInterface:SetMode(mode_or_dialog, context)
	if self.mode_dialog then
		self.mode_dialog:Close()
	end
	local mode = mode_or_dialog
	if type(mode) == "string" then
		local class = mode and g_Classes[mode]
		assert(class)
		self.mode_dialog = class and OpenDialog(mode, self, context)
	else
		assert(IsKindOf(mode, "XDialog"))
		mode:SetParent(self)
		mode:SetContext(context)
		mode:Open()
		self.mode_dialog = mode
		mode = mode_or_dialog.class
	end
	Msg("IGIModeChanging", self.Mode, mode)
	self.mode_log[#self.mode_log + 1] = { self.Mode, self.mode_param }
	self.Mode = mode
	self.mode_param = context
	Msg("IGIModeChanged", mode)
	self:CallOnModeChange()
end

---
--- Gets the InGameInterface dialog instance.
---
--- @return InGameInterface|nil The InGameInterface dialog instance, or nil if it doesn't exist.
---
function GetInGameInterface()
	return GetDialog("InGameInterface")
end

---
--- Gets the top-level InGameInterface dialog instance.
---
--- @return InGameInterface|nil The top-level InGameInterface dialog instance, or nil if it doesn't exist.
---
function GetTopInGameInterfaceParent()
	return GetInGameInterface()
end

---
--- Gets the current mode of the InGameInterface dialog.
---
--- @return string The current mode of the InGameInterface dialog.
---
function GetInGameInterfaceMode()
	return GetDialogMode("InGameInterface")
end

---
--- Checks if the current code is running in an asynchronous context, or if the `IgnoreSyncCheckErrors` configuration option is set.
---
--- @return boolean True if the current code is running asynchronously or if `IgnoreSyncCheckErrors` is set, false otherwise.
---
function SyncCheck_InGameInterfaceMode()
	if config.IgnoreSyncCheckErrors then
		return true
	end
	return IsAsyncCode()
end

---
--- Sets the current mode of the InGameInterface dialog.
---
--- @param mode string The new mode to set for the InGameInterface dialog.
--- @param context any Optional context to pass to the mode change.
---
function SetInGameInterfaceMode(mode, context)
	assert(SyncCheck_InGameInterfaceMode())
	SetDialogMode("InGameInterface", mode, context)
end

---
--- Gets the mode dialog of the InGameInterface.
---
--- @param mode string|nil The mode to get the dialog for. If nil, the current mode will be used.
--- @return InGameInterfaceModeDlg|nil The mode dialog, or nil if it doesn't exist or the mode doesn't match.
---
function GetInGameInterfaceModeDlg(mode)
	local igi = GetInGameInterface()
	if igi and (not mode or mode == igi:GetMode()) then
		return igi.mode_dialog
	end
end

---
--- Shows or hides the in-game interface dialog.
---
--- @param bShow boolean Whether to show or hide the in-game interface dialog.
--- @param instant boolean Whether to show/hide the dialog instantly or with a transition animation.
--- @param context any Optional context to pass to the dialog.
---
function ShowInGameInterface(bShow, instant, context)
	if not mapdata.GameLogic and not GetInGameInterface() then
		return
	end
	if not bShow and not GetInGameInterface() then 
		return
	end
	local dlg = OpenDialog("InGameInterface", nil, context)
	dlg:SetVisible(bShow, instant)
	dlg.desktop:RestoreFocus()
end

-- deactivate mode dialog and set it to select
---
--- Closes the current mode of the InGameInterface dialog.
---
--- @param mode string|nil The mode to close. If nil, the current mode will be closed.
---
function CloseInGameInterfaceMode(mode)
	local igi = GetInGameInterface()
	if igi and (not mode or (igi:GetMode() == mode and igi.mode_dialog.window_state ~= "destroying")) then
		if igi:GetMode() ~= igi.InitialMode then
			igi:SetMode(igi.InitialMode)
		end
	end
end

function OnMsg.GameEnterEditor()
	ShowInGameInterface(false)
	ShowPauseDialog(false, "force")
end

function OnMsg.GameExitEditor()
	if GetInGameInterface() then
		ShowInGameInterface(true)
	end
	if GetTimeFactor() == 0 then
		ShowPauseDialog(true)
	end
end

function OnMsg.StoreSaveGame(storing)
	local igi = GetInGameInterface()
	if not igi or not XTemplates["LoadingAnim"] then return end
	if storing then
		OpenDialog("LoadingAnim", igi:ResolveId("idLoadingContainer") or igi, nil, "StoreSaveGame")
	else
		CloseDialog("LoadingAnim", nil, "StoreSaveGame")
	end
end

local highlight_thread, highlight_obj, highlight_oldcolor
---
--- Highlights and views an object in the game.
---
--- @param obj table The object to highlight and view.
---
function ViewAndHighlightObject(obj)
	if highlight_obj then
		highlight_obj:SetColorModifier(highlight_oldcolor)
		DeleteThread(highlight_thread)
	end
	highlight_obj = obj
	highlight_oldcolor = obj:GetColorModifier()
	highlight_thread = CreateRealTimeThread(function()
		if IsValid(obj) then
			ViewObject(obj)
			Sleep(200)
			for i = 1, 5 do
				if not IsValid(obj) then break end
				obj:SetColorModifier(RGB(255, 255, 255))
				Sleep(75)
				if not IsValid(obj) then break end
				obj:SetColorModifier(highlight_oldcolor)
				Sleep(75)
			end
		end
		highlight_obj = nil
		highlight_thread = nil
		highlight_oldcolor = nil
	end)
end

function OnMsg.ChangeMapDone()
	HideMouseCursor("system")
	if Platform.developer and not mapdata.GameLogic then
		ShowMouseCursor("system")
	end
end