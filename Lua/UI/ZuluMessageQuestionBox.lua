----- ZuluMessageDialog
DefineClass.ZuluMessageDialog = {
	__parents = { "ZuluModalDialog", "XDarkModeAwareDialog" },
	
	HandleKeyboard = true,
	--DrawOnTop = true,
	template = "ZuluMessageDialogTemplate",
	ZOrder = 1000,
	
	-- prevent dark mode, e.g. when popped from Map Editor
	UpdateControlDarkMode = empty_func,
	UpdateChildrenDarkMode = empty_func,
}

--- Initializes the ZuluMessageDialog instance.
-- This function is called to set up the dialog when it is first created.
-- It spawns the template specified in the `template` field and assigns it to the dialog.
function ZuluMessageDialog:Init()
	XTemplateSpawn(self.template, self, self.context)
end

---
--- Opens the ZuluMessageDialog instance.
---
--- This function is called to open the dialog and set up its initial state. It calls the parent `ZuluModalDialog:Open()` function, sets the dialog's focus, adds the dialog to the `g_OpenMessageBoxes` table, and sets the text and title of the dialog's UI elements based on the `context` table passed to the dialog.
---
--- @param self ZuluMessageDialog The ZuluMessageDialog instance.
--- @param ... any Additional arguments passed to the `Open()` function.
function ZuluMessageDialog:Open(...)
	ZuluModalDialog.Open(self, ...)

	self:SetFocus()

	g_OpenMessageBoxes[self] = true
	self.idMain.idText:SetText(self.context.text)
	self.idMain.idTitle:SetText(self.context.title)
end

---
--- Closes the ZuluMessageDialog instance.
---
--- This function is called to close the dialog and clean up its state. It removes the dialog from the `g_OpenMessageBoxes` table and calls the parent `ZuluModalDialog:Close()` function to handle the actual closing of the dialog.
---
--- @param self ZuluMessageDialog The ZuluMessageDialog instance.
--- @param ... any Additional arguments passed to the `Close()` function.
function ZuluMessageDialog:Close(...)
	g_OpenMessageBoxes[self] = nil
	ZuluModalDialog.Close(self, ...)
end

---
--- Prevents the ZuluMessageDialog from being closed.
---
--- This function disables the action buttons in the dialog's action bar, and sets the `OnShortcut` function to an empty function to prevent the dialog from being closed via keyboard shortcuts.
---
--- @param self ZuluMessageDialog The ZuluMessageDialog instance.
function ZuluMessageDialog:PreventClose()
	local actionButtons = self.idMain.idActionBar
	if actionButtons then
		actionButtons.RebuildActions = empty_func
		actionButtons = actionButtons[1]
	end
	for i, a in ipairs(actionButtons) do
		if IsKindOf(a, "XTextButton") then
			a:SetEnabled(false)
		end
	end
	self.OnShortcut = empty_func
end
---
--- Prevents the ZuluMessageDialog from handling mouse button up events.
---
--- This function is called when the mouse button is released on the ZuluMessageDialog. It returns "break" to prevent the default handling of the event, effectively disabling mouse button up functionality for the dialog.
---
--- @param self ZuluMessageDialog The ZuluMessageDialog instance.
--- @return string "break" to prevent default handling of the event.

function ZuluMessageDialog:OnMouseButtonDown()
	return "break"
end

---
--- Prevents the ZuluMessageDialog from handling mouse button up events.
---
--- This function is called when the mouse button is released on the ZuluMessageDialog. It returns "break" to prevent the default handling of the event, effectively disabling mouse button up functionality for the dialog.
---
--- @param self ZuluMessageDialog The ZuluMessageDialog instance.
--- @return string "break" to prevent default handling of the event.
function ZuluMessageDialog:OnMouseButtonUp()
	return "break"
end

---
--- Prevents the ZuluMessageDialog from handling mouse wheel forward events.
---
--- This function is called when the mouse wheel is scrolled forward on the ZuluMessageDialog. It returns "break" to prevent the default handling of the event, effectively disabling mouse wheel forward functionality for the dialog.
---
--- @param self ZuluMessageDialog The ZuluMessageDialog instance.
--- @return string "break" to prevent default handling of the event.
function ZuluMessageDialog:OnMouseWheelForward()
	return "break"
end

---
--- Prevents the ZuluMessageDialog from handling mouse wheel back events.
---
--- This function is called when the mouse wheel is scrolled backward on the ZuluMessageDialog. It returns "break" to prevent the default handling of the event, effectively disabling mouse wheel back functionality for the dialog.
---
--- @param self ZuluMessageDialog The ZuluMessageDialog instance.
--- @return string "break" to prevent default handling of the event.
function ZuluMessageDialog:OnMouseWheelBack()
	return "break"
end

---
--- Creates a message box dialog with the specified caption, text, and optional OK button text.
---
--- @param parent XWindow The parent window for the message box.
--- @param caption string The title or caption of the message box.
--- @param text string The text content of the message box.
--- @param ok_text string (optional) The text for the OK button.
--- @param obj table (optional) An object associated with the message box.
--- @param extra_action XAction (optional) An additional action to include in the message box.
--- @return ZuluMessageDialog The created message box dialog.
function CreateMessageBox(parent, caption, text, ok_text, obj, extra_action)
	parent = parent or terminal.desktop
	
	-- This happens rarely when an account storage error pops up.
	if not parent.ChildrenHandleMouse then
		parent:SetChildrenHandleMouse(true)
		print("Message box in non-mouse handling parent")
	end
	
	local context = {
		title = caption,
		text = text,
		obj = obj
	}
	
	local actions = {}
	actions[#actions + 1] = XAction:new({
		ActionId = "idOk",
		ActionName = ok_text or T(6877, "OK"),
		ActionShortcut = "Escape",
		ActionShortcut2 = "Enter",
		ActionGamepad = "ButtonA",
		ActionToolbar = "ActionBar",
		OnActionEffect = "close",
		OnActionParam = "ok",
	})
	actions[#actions + 1] = extra_action
	
	local msg = ZuluMessageDialog:new({actions = actions}, parent, context)
	msg.OnShortcut = function(self, shortcut, source, ...)
		if shortcut == "ButtonB" or shortcut == "1" then
			self:Close("ok")
			return "break"
		end
		return ZuluModalDialog.OnShortcut(self, shortcut, source, ...)
	end
	msg:Open()
	return msg
end

-- Zulu's CreateQuestionBox/CreateMessageBox uses the ZuluMessageDialog class which inherits ZuluModalDialog
-- ZuluModalDialog doesn't use XWindow:SetModal but instead stretches over the whole parent (usually the whole screen)
-- and captures all input below it. This means that any windows outside of the parent will still be clickable (and undimmed).
-- If spawning the question box in tactical view use the default terminal.desktop or InGameInterface() or whatever you use
-- normally. When spawning it in the PDADialog use GetDialog("PDADialog"):ResolveId("idDisplayPopupHost") which will cause
-- it to spawn inside the screen (logically and visually). The PDA frame buttons which are outside the screen will
-- not allow input while the popup is open via additional logic.

-- added sync_close -> try and close the box on all remote clients on input
---
--- Synchronizes the closure of a message box across all remote clients.
---
--- When a message box is closed on the local client, this function will find any open message boxes on remote clients that have the same text and title, and close them.
---
--- @param text string The text of the message box.
--- @param title string The title of the message box.
--- @param btn string The button that was clicked to close the message box ("ok" or "cancel").
---
function NetEvents.SyncMsgBoxClosed(text, title, btn)
	for msg_box, _ in pairs(g_OpenMessageBoxes) do
		if msg_box.window_state ~= "destroying" and
			msg_box:HasMember("idMain") and --any assert here will lead to msg box blocking client forever...
			msg_box.idMain:HasMember("idText") and
			_InternalTranslate(msg_box.idMain.idText:GetText()) == text and
			msg_box.idMain:HasMember("idTitle") and
			_InternalTranslate(msg_box.idMain.idTitle:GetText()) == title then
			msg_box:Close("remote")
		end
	end
end

---
--- Creates a new question box dialog.
---
--- @param parent table The parent window for the dialog.
--- @param caption string The title of the dialog.
--- @param text string The message text to display in the dialog.
--- @param ok_text string (optional) The text for the "OK" button.
--- @param cancel_text string (optional) The text for the "Cancel" button.
--- @param obj table (optional) An object associated with the dialog.
--- @param ok_state_fn function (optional) A function that returns the state of the "OK" button.
--- @param cancel_state_fn function (optional) A function that returns the state of the "Cancel" button.
--- @param template table (optional) A template to use for the dialog.
--- @param sync_close boolean (optional) Whether to synchronize the closure of the dialog across remote clients.
--- @return table The created dialog.
---
function CreateQuestionBox(parent, caption, text, ok_text, cancel_text, obj, ok_state_fn, cancel_state_fn, template, sync_close)
	parent = parent or terminal.desktop
	local context = {
		title = caption,
		text = text,
		obj = obj
	}
	local actions = {}
	local on_close = empty_func
	if netInGame and sync_close then
		on_close = function(action, host, btn)
			NetEvent("SyncMsgBoxClosed", _InternalTranslate(text), _InternalTranslate(caption), btn)
		end
	end
	
	actions[#actions + 1] = XAction:new({
		ActionId = "idOk",
		ActionName = ok_text or T(6878, "OK"),
		ActionShortcut = "Enter",
		ActionShortcut2 = "1",
		ActionGamepad = "ButtonA",
		ActionToolbar = "ActionBar",
		ActionState = function(self, host)
			return ok_state_fn and ok_state_fn(obj) or "enabled"
		end,
		OnAction = function(self, host, source)
			on_close(self, host, "ok")
			host:Close("ok")
			return "break"
		end
	})
	actions[#actions + 1] = XAction:new({
		ActionId = "idCancel",
		ActionName = cancel_text or T(6879, "Cancel"),
		ActionShortcut = "Escape",
		ActionShortcut2 = "2",
		ActionGamepad = "ButtonB",
		ActionToolbar = "ActionBar",
		ActionState = function(self, host)
			return cancel_state_fn and cancel_state_fn(obj) or "enabled"
		end,
		OnAction = function(self, host, source)
			on_close(self, host, "cancel")
			host:Close("cancel")
			return "break"
		end
	})
	
	local initArgs = { actions = actions }
	if template then
		initArgs.template = template
	end
	local msg = ZuluMessageDialog:new(initArgs, parent, context)
	msg:Open()
	return msg
end

---
--- Loads a resource even if there are errors.
---
--- @param err string The error message to display in the warning dialog.
--- @param alt_option string An optional alternative choice to display in the warning dialog.
--- @return boolean, boolean Whether the resource was loaded, and whether the alternative option was chosen.
---
function LoadAnyway(err, alt_option)
	DebugPrint("\nLoad anyway", ":", _InternalTranslate(err), "\n\n")
	local default_load_anyway = config.DefaultLoadAnywayAnswer
	if default_load_anyway ~= nil then
		return default_load_anyway
	end

	local parent = GetLoadingScreenDialog() or terminal.desktop
	local res = WaitPopupChoice(parent, {
			translate = true,
			text = err,
			title = T(1000599, "Warning"),
			choice1 = T(3686, "Load anyway"),
			choice1_gamepad_shortcut = "ButtonA",
			choice2 = T(1000246, "Cancel"),
			choice2_gamepad_shortcut = "ButtonB",
			choice3 = alt_option,
			choice3_gamepad_shortcut = "ButtonY",
		})
	return res ~= 2, res == 3
end

----- ZuluChoiceDialog
DefineClass.ZuluChoiceDialog = {
	__parents = {"ZuluMessageDialog"},
}

---
--- Initializes the ZuluChoiceDialog.
---
--- This function sets the campaign speed to 0 and creates a camera lock layer and a pause layer for the dialog.
---
function ZuluChoiceDialog:Init()
	SetCampaignSpeed(0, GetUICampaignPauseReason("ZuluChoiceDialog"))
	XCameraLockLayer:new({}, self)
	XPauseLayer:new({}, self)
end

---
--- Restores the campaign speed to its previous value and removes the pause reason associated with the ZuluChoiceDialog.
---
function ZuluChoiceDialog:Done()
	SetCampaignSpeed(nil, GetUICampaignPauseReason("ZuluChoiceDialog"))
end

---
--- Handles the closing of a ZuluChoiceDialog by a remote client.
---
--- When a ZuluChoiceDialog is closed by a remote client, this function is called to close the dialog on the local client.
---
--- @param idx number The index of the choice that was selected to close the dialog.
---
function NetEvents.ZuluChoiceDialogClosed(idx)
	local dlg = terminal.desktop:GetModalWindow()
	if dlg and dlg.parent and IsKindOf(dlg.parent, "ZuluChoiceDialog") then
		dlg.parent:Close("remote")
	end
end

local lGamepadShortcutToKeyboard = {
	["ButtonB"] = "Escape",
	["ButtonA"] = "Enter",
	["ButtonY"] = "Space",
}

---
--- Creates a ZuluChoiceDialog with the specified parent and context.
---
--- The function sets up the actions for the dialog based on the choices defined in the context table. It also handles the closing of the dialog by a remote client.
---
--- @param parent table The parent of the ZuluChoiceDialog.
--- @param context table The context for the ZuluChoiceDialog, containing information about the choices to be displayed.
--- @return table The created ZuluChoiceDialog.
---
function CreateZuluPopupChoice(parent, context)
	local actions = {}
	
	context.title = context.title or T(387054111386, "Choice")
	local on_close = empty_func
	if netInGame and context.sync_close then
		on_close = function(action, host, idx)
			NetEvent("ZuluChoiceDialogClosed", idx)
		end
	end
	
	local maxChoiceIdx = 1
	local totalKeys = table.keys(context)
	for i = 1, #totalKeys do
		if context["choice" .. i] then
			maxChoiceIdx = i
		end
	end
	
	for i = 1, maxChoiceIdx do
		local choice = context["choice" .. i]
		if not choice and i == 1 then
			choice = T(325411474155, "OK")
		end
		if not choice then goto continue end
		
		local idx = i
		local gamePadShortcut = context["choice" .. idx .. "_gamepad_shortcut"]
		
		actions[#actions + 1] = XAction:new({
			ActionId = "idChoice" .. i,
			ActionName = choice,
			ActionToolbar = "ActionBar",
			OnAction = function(self, host, source)
				on_close(self, host, idx)
				host:Close(idx)
			end,
			ActionState = function(self, host, source)
				local f = context["choice" .. idx .. "_state_func"]
				return f and f() or "enabled"
			end,
			ActionShortcut = lGamepadShortcutToKeyboard[gamePadShortcut],
			ActionGamepad = gamePadShortcut
		})
		
		::continue::
	end

	return ZuluChoiceDialog:new({actions = actions}, parent or terminal.desktop, context)
end

--- Displays a popup dialog with a set of choices and waits for the user to select one.
---
--- @param parent table The parent UI element for the dialog.
--- @param context table A table containing the configuration for the dialog, including the title, choices, and optional callbacks.
--- @return number The index of the choice selected by the user.
function WaitPopupChoice(parent, context)
	local dialog = CreateZuluPopupChoice(parent, context)
	dialog:Open()
	return dialog:Wait()
end