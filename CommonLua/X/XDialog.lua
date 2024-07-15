if FirstLoad then
	Dialogs = {}
end

---
--- Opens a dialog window using the specified template, parent, context, and reason.
---
--- @param template string The template name to use for the dialog.
--- @param parent XWindow The parent window for the dialog.
--- @param context table The context data to pass to the dialog.
--- @param reason string The reason for opening the dialog.
--- @param id string The unique identifier for the dialog.
--- @param prop_preset XDialogProperties The property preset to apply to the dialog.
--- @return XDialog The opened dialog.
---
function OpenDialog(template, parent, context, reason, id, prop_preset)
	id = id or template
	local dialog = GetDialog(id)
	if dialog then
		if context then
			dialog:SetContext(context)
		end
		local mode = ResolveValue(context, "Mode")
		if mode ~= nil then
			dialog:SetMode(mode)
		end
	else
		assert(Dialogs[id] == nil)
		dialog = XTemplateSpawn(template, parent, context)
		assert(IsKindOf(dialog, "XDialog"))
		if not dialog then
			return
		end
		dialog.XTemplate = XTemplates[template] and template or nil
		Dialogs[id] = dialog
		Dialogs[dialog] = id
		if not parent or parent.window_state == "open" then
			if prop_preset then
				dialog:CopyProperties(prop_preset, prop_preset:GatherTemplateProperties())
			end
			dialog:Open()
		end
	end
	if IsKindOf(dialog, "XDialog") then
		dialog:AddOpenReason(reason)
	end
	return dialog
end

---
--- Closes a dialog window with the specified identifier and result.
---
--- @param id string The unique identifier for the dialog to close.
--- @param result any The result to pass when closing the dialog.
--- @param reason string The reason for closing the dialog.
--- @return XDialog The closed dialog.
---
function CloseDialog(id, result, reason)
	local dialog = GetDialog(id)
	if dialog then
		if IsKindOf(dialog, "XDialog") then
			dialog:RemoveOpenReason(reason, result)
		else
			dialog:Close(result)
		end
		return dialog
	end
end

---
--- Lists all the dialog IDs that have been opened.
---
--- @return table A table of dialog IDs.
---
function ListDialogs()
	local dlgs = {}
	for k,v in pairs(Dialogs) do
		if type(k)=="string" then
			dlgs[#dlgs + 1] = k
		end
	end
	table.sort(dlgs)
	return dlgs	
end

---
--- Lists all the dialog IDs that have been opened.
---
--- @return table A table of dialog IDs.
---
function ListAllDialogs()
	return PresetsCombo("XTemplate", nil, "InGameInterface")()
end

---
--- Removes the specified open reason from all open dialog windows.
---
--- @param reason string The reason to remove from open dialog windows.
--- @param result any The result to pass when closing the dialog.
---
function RemoveOpenReason(reason, result)
	for dialog in pairs(Dialogs) do
		if IsKindOf(dialog, "XDialog") then
			dialog:RemoveOpenReason(reason, result)
		end
	end
end

---
--- Gets the dialog associated with the given ID or window.
---
--- @param id_or_win string|XWindow The ID of the dialog or the window instance.
--- @return XDialog|nil The dialog instance, or nil if not found.
---
function GetDialog(id_or_win)
	if type(id_or_win) == "table" and IsKindOf(id_or_win, "XWindow") then
		return GetParentOfKind(id_or_win, "XDialog")
	end
	return Dialogs[id_or_win]
end

---
--- Opens a dialog and waits for it to be closed.
---
--- @param ... any Arguments to pass to OpenDialog
--- @return any The result returned from the dialog's Wait() method
---
function WaitDialog(...)
	local dialog = OpenDialog(...)
	if dialog then
		return dialog:Wait()
	end
end

---
--- Ensures that the specified dialog is open, and returns the dialog instance.
---
--- If the dialog is not already open, this function will open it and return the instance.
---
--- @param dlg string|XWindow The ID of the dialog or the window instance to open.
--- @return XDialog The dialog instance.
---
function EnsureDialog(dlg)
	local dialog = GetDialog(dlg)
	if not dialog then
		local t = GetInGameInterface()
		if not t then
			ShowInGameInterface(true)
			t = GetInGameInterface()
		end
		dialog = OpenDialog(dlg, t)
	end
	return dialog
end

---
--- Gets the current mode of the specified dialog.
---
--- @param id_or_win string|XWindow The ID of the dialog or the window instance.
--- @return string|nil The current mode of the dialog, or nil if the dialog is not found.
---
function GetDialogMode(id_or_win)
	local dlg = GetDialog(id_or_win)
	return dlg and dlg.Mode
end

---
--- Gets the current mode parameter of the specified dialog.
---
--- @param id_or_win string|XWindow The ID of the dialog or the window instance.
--- @return any The current mode parameter of the dialog, or nil if the dialog is not found.
---
function GetDialogModeParam(id_or_win)
	local dlg = GetDialog(id_or_win)
	return dlg and dlg.mode_param
end

---
--- Sets the mode of the specified dialog.
---
--- @param id_or_win string|XWindow The ID of the dialog or the window instance.
--- @param mode string The new mode to set for the dialog.
--- @param mode_param any The parameter to pass to the new mode.
---
function SetDialogMode(id_or_win, mode, mode_param)
	local dlg = GetDialog(id_or_win)
	if dlg then
		dlg:SetMode(mode, mode_param)
	end
end

---
--- Sets the dialog back to the previous mode.
---
--- @param id_or_win string|XWindow The ID of the dialog or the window instance.
---
function SetBackDialogMode(id_or_win)
	local dlg = GetDialog(id_or_win)
	if dlg then
		local mode = table.remove(dlg.mode_log)
		if mode then
			dlg:SetMode(mode[1], mode[2])
			table.remove(dlg.mode_log)
		end
	end
end

---
--- Gets the dialog context of the specified dialog.
---
--- @param id_or_win string|XWindow The ID of the dialog or the window instance.
--- @return table|nil The context of the dialog, or nil if the dialog is not found.
---
function GetDialogContext(id_or_win)
	local dlg = GetDialog(id_or_win)
	return dlg and dlg.context
end

---
--- Gets the UI path of the specified window.
---
--- @param win XWindow|nil The window to get the UI path for. If nil, the window under the mouse cursor will be used.
--- @param parent XWindow|false The parent window to stop at. If false, the desktop will be used.
--- @return string The UI path of the window.
---
function _GetUIPath(win, parent)
	win = win or (parent or terminal.desktop):GetMouseTarget(terminal:GetMousePos())
	parent = parent or false
	local wins = {}
	local w = win
	local f
	while w and w ~= parent do
		local name = Dialogs[w] or rawget(w, "XTemplate") or w.class
		local id = rawget(w, "Id")
		if id and name ~= id and id ~= "" then
			name = name .. "(" .. id .. ")"
		end
		local z = w.ZOrder ~= 1 and w.ZOrder
		if z then
			name = name .. "[" .. z .. "]"
		end
		if not w:IsVisible() then
			name = name .. "|X|"
		end
		if not f and w:IsFocused() then
			f = w
			name = name .. "*"
		end
		table.insert(wins, 1, name)
		w = w.parent or false
	end
	return table.concat(wins, " - ")
end

---
--- Prints a list of all open dialogs, including their UI path, ID, Z-order, visibility, and focus state.
---
--- @param print_func function The function to use for printing the dialog information.
--- @param indent string The indentation to use for the printed output.
--- @param except table A table of dialog names to exclude from the output.
---
function _PrintDialogs(print_func, indent, except)
	except = except or {}
	indent = indent or ""
	print_func = print_func or print
	local texts = {}
	for name, dlg in pairs(Dialogs) do
		if type(name) == "string" and type(dlg) == "table" and not table.find(except,name) then
			texts[#texts + 1] = _GetUIPath(dlg, terminal.desktop)
			
			if dlg:IsKindOf("BaseLoadingScreen") then
				texts[#texts + 1] = "\t" .. ValueToLuaCode(dlg:GetOpenReasons())
			end
		end
	end
	table.sort(texts)
	local indents = {}
	for i=1,#texts do
		local txt = texts[i]
		for j=i+1,#texts do
			local t = texts[j]
			 local b, e = string.find(t, txt, 1, true)
			 if b then
				indents[j] = (indents[j] or 0) + 1
				texts[j] = string.sub(t, e+1)
			 end
		end
	end
	for i=1,#texts do
		local txt = texts[i]
		if indents[i] then
			txt = string.rep("\t", indents[i]) .. txt
		end
		print_func(indent, txt)
	end
end

function OnMsg.BugReportStart(print_func)
	print_func("Screen size: ", UIL.GetScreenSize())
	if next(Dialogs) ~= nil then
		print_func("Opened dialogs: (notation: (n) = Id, [n] = ZOrder, |X| = Invisible, * = Focused)")
		_PrintDialogs(print_func, "\t")
		print_func("")
	end
end

---
--- Closes all open dialogs, except for those specified in the `except` table.
--- Cancels any active virtual keyboard on Xbox platforms.
--- Closes all open messages and questions.
---
--- @param except table A table of dialog IDs to exclude from being closed.
--- @param force_loading_screens boolean If true, loading and saving screens will also be closed.
---
function CloseAllDialogs(except, force_loading_screens)
	if Platform.xbox then
		AsyncOpCancel(ActiveVirtualKeyboard)
	end
	CloseAllMessagesAndQuestions()
	local dialogs = ListDialogs()
	for i = 1, #dialogs do
		local dialog = dialogs[i]
		if except and except[dialog] then
			print("Skipping dialog " .. dialog)
		elseif not force_loading_screens and (IsKindOf(GetDialog(dialog), "BaseLoadingScreen") or IsKindOf(GetDialog(dialog), "BaseSavingScreen")) then
			-- should be closed by the code that opened them
		else
			CloseDialog(dialog)
		end
	end
end

---
--- Recursively closes all dialogs with the given ID.
---
--- @param id number The ID of the dialog to close.
--- @param ... number Additional dialog IDs to close.
---
function CloseDialogs(id, ...)
	if not id then return end
	CloseDialog(id)
	return CloseDialogs(...)
end

----- XDialog

DefineClass.XDialog = {
	__parents = { "XActionsHost" },
	properties = {
		{ category = "General", id = "InitialMode", editor = "text", default = "" },
		{ category = "General", id = "Mode", editor = "text", default = "", read_only = true, },
		{ category = "General", id = "InternalModes", name = "Internal modes", editor = "text", default = "", help = "A list of internal modes. When present, any mode outside of the list will be propagated to the parent dialog."},
		{ category = "General", id = "gamestate", Name = "Game state", editor = "text", default = "" },
		{ category = "General", id = "FocusOnOpen", editor = "choice", default = "self", items = {"", "self", "child"}, },
		{ category = "Visual", id = "HideInScreenshots", editor = "bool", default = false },
	},
	XTemplate = false,
	Translate = true,
	IdNode = true,
	open_reasons = false,
	result = false,
	close_controller_id = false, -- which controller was used to close the dialog
	mode_log = false,
	mode_param = false,
}

---
--- Initializes an XDialog instance with the provided parent and context.
---
--- @param parent table The parent of the XDialog instance.
--- @param context table A table containing initialization parameters for the XDialog instance.
---
function XDialog:Init(parent, context)
	self.InitialMode = ResolveValue(context, "Mode") or self.InitialMode
	self.mode_log = ResolveValue(context, "mode_log") or {}
end

---
--- Closes the XDialog instance.
---
--- @param reason string The reason for closing the dialog.
--- @param source string The source of the close action, e.g. "gamepad".
--- @param controller_id number The ID of the controller used to close the dialog.
--- @param ... any Additional arguments to pass to the close action.
---
function XDialog:Close(reason, source, controller_id, ...)
	if source == "gamepad" then
		self.close_controller_id = controller_id
	end
	XActionsHost.Close(self, reason, source, controller_id, ...)
end

---
--- Marks the XDialog instance as closed and performs cleanup tasks.
---
--- @param result any The result of the dialog closure.
---
function XDialog:Done(result)
	Msg("DialogClose", self, result)
	local id = Dialogs[self]
	Dialogs[self] = nil
	if id and Dialogs[id] == self then
		Dialogs[id] = nil
		if self.gamestate ~= "" then
			ChangeGameState(self.gamestate, false)
		end
	end
	self.result = result
	Msg(self)
end

---
--- Opens the XDialog instance.
---
--- @param ... any Additional arguments to pass to the open action.
---
function XDialog:Open(...)
	if not self.HostInParent then
		self:ResolveRelativeFocusOrder()
	end
	self:SetFocus_OnOpen(self.FocusOnOpen)
	XActionsHost.Open(self, ...)
	Msg("DialogOpen", self, self.InitialMode)
	if self.InitialMode ~= "" then
		self:SetMode(self.InitialMode)
	end
	if self.gamestate ~= "" then
		ChangeGameState(self.gamestate, true)
	end
end

---
--- Sets the focus of the XDialog instance on open.
---
--- If `focus` is "self", the dialog itself will receive focus.
--- If `focus` is "child", the nearest child control will receive focus.
---
--- @param focus string The focus mode to use on open.
---
function XDialog:SetFocus_OnOpen(focus)
	focus = focus or self.FocusOnOpen
	if focus == "self" then
		self:SetFocus()
	elseif focus == "child" then
		local child = self:GetRelativeFocus(point(1, 1), "nearest")
		if child then
			child:SetFocus()
		end
	end
end

---
--- Waits for the XDialog instance to close and returns its result.
---
--- This function should only be called from asynchronous code. It will block until the dialog is closed, and return the dialog's result, the dialog instance itself, and the ID of the close controller.
---
--- @return any The result of the dialog.
--- @return XDialog The dialog instance.
--- @return string The ID of the close controller.
---
function XDialog:Wait()
	assert(IsAsyncCode())
	if self.window_state == "open" then
		assert(not self:GetThreadName(), "The window thread will be deleted before self:Wait() returns")
		WaitMsg(self)
	end
	return self.result, self, self.close_controller_id
end

---
--- Adds a reason for the XDialog instance to be open.
---
--- The `open_reasons` table is used to track the reasons why the dialog is open. When the last reason is removed, the dialog will automatically close.
---
--- @param reason string|boolean The reason for the dialog to be open. If `nil` or `true`, a generic reason will be used.
---
function XDialog:AddOpenReason(reason)
	self.open_reasons = self.open_reasons or {}
	self.open_reasons[reason or true] = true
end

---
--- Removes a reason for the XDialog instance to be open.
---
--- The `open_reasons` table is used to track the reasons why the dialog is open. When the last reason is removed, the dialog will automatically close.
---
--- @param reason string|boolean The reason for the dialog to be open. If `nil` or `true`, a generic reason will be used.
--- @param result any The result to pass to the `Close` function when the last reason is removed.
--- @return boolean `true` if the dialog was closed, `false` otherwise.
---
function XDialog:RemoveOpenReason(reason, result)
	local open_reasons = self.open_reasons
	reason = reason or true
	if open_reasons and open_reasons[reason] then
		open_reasons[reason] = nil
		if next(open_reasons) == nil and self.window_state ~= "destroying" then
			self:Close(result)
			return true
		end
	end
end

---
--- Returns the reasons why the XDialog instance is open.
---
--- The `open_reasons` table is used to track the reasons why the dialog is open. When the last reason is removed, the dialog will automatically close.
---
--- @return table The reasons why the dialog is open.
---
function XDialog:GetOpenReasons()
	return self.open_reasons or empty_table
end

local function callOnModeChange(win, mode, dialog)
	if win == dialog or not IsKindOf(win, "XDialog") then
		for _, win in ipairs(win or empty_table) do
			callOnModeChange(win, mode, dialog)
		end
	end
	win:OnDialogModeChange(mode, dialog)
end

---
--- Checks if the given `mode` matches the specified `list` of dialog modes.
---
--- The `list` parameter is a comma-separated string of dialog mode names. The function checks if the `mode` parameter matches any of the modes in the list.
---
--- @param mode string The dialog mode to check.
--- @param list string The list of dialog modes to check against.
--- @return boolean `true` if the `mode` matches one of the modes in the `list`, `false` otherwise.
---
function MatchDialogMode(mode, list)
	if not list or list == "" then return end
	if mode == "" then
		return list:starts_with(",") -- the first mode in the list can be ""
	end
	if mode == list then
		return true
	end
	if not list:find(mode, 1, true) then
		return
	end
	for m in list:gmatch("([%w%-_]+)") do
		if m == mode then
			return true
		end
	end	
end

---
--- Returns a table of dialog modes from the given comma-separated string.
---
--- The function takes an optional `list` parameter, which is a comma-separated string of dialog mode names. If `list` is not provided, it defaults to `self.InternalModes`. The function returns a table of the individual dialog mode names.
---
--- If the `list` starts with a comma, the first mode in the list will be an empty string. Otherwise, the first element in the returned table will be `nil`.
---
--- @param list string The comma-separated list of dialog mode names.
--- @return table An array of dialog mode names.
---
function XDialog:GetModes(list)
	list = list or self.InternalModes or ""
	local arr = { list:starts_with(",") and "" or nil }
	for m in list:gmatch("([%w%-_]+)") do
		arr[#arr + 1] = m
	end	
	return arr
end

---
--- Sets the mode of the dialog.
---
--- If the specified `mode` does not match any of the internal modes, the function checks if the dialog has a parent dialog and recursively sets the mode on the parent dialog.
---
--- The function logs the previous mode and mode parameter in `self.mode_log`, updates `self.Mode` and `self.mode_param`, and then sends a "DialogSetMode" message with the old and new mode information.
---
--- Finally, the function calls `self:CallOnModeChange()` to notify any listeners of the mode change.
---
--- @param mode string The new mode to set for the dialog.
--- @param mode_param any Optional parameter to pass along with the mode change.
---
function XDialog:SetMode(mode, mode_param)
	if not MatchDialogMode(mode, self.InternalModes) then
		local dlg = GetParentOfKind(self.parent, "XDialog")
		if dlg then
			dlg:SetMode(mode, mode_param)
			return
		end
	end
	self.mode_log[#self.mode_log + 1] = { self.Mode, self.mode_param }
	local old_mode = self.Mode
	self.Mode = mode
	self.mode_param = mode_param
	Msg("DialogSetMode", self, mode, mode_param, old_mode)
	self:CallOnModeChange()
end

---
--- Calls any registered callbacks for the mode change event.
---
--- This function is called after the dialog mode has been updated via `XDialog:SetMode()`. It iterates through any registered callbacks and calls them with the new mode and the dialog instance.
---
--- @param self XDialog The dialog instance.
---
function XDialog:CallOnModeChange()
	callOnModeChange(self, self.Mode, self)
end

----- XLayer

DefineClass.XLayer = {
	__parents = { "XDialog" },
	FocusOnOpen = "",
}


----- XOpenLayer

DefineClass.XOpenLayer = {
	__parents = { "XWindow" },
	properties = {
		{ category = "General", id = "Layer", editor = "combo", default = "", items = function() return XTemplateCombo("XLayer") end, },
		{ category = "General", id = "LayerId", editor = "text", default = "", },
		{ category = "General", id = "Mode", editor = "text", default = false, },
	},
	Dock = "ignore",
	visible = false,
	dialog = false,
	xtemplate = false,
}

---
--- Opens a dialog layer.
---
--- This function is called when an `XOpenLayer` instance is opened. It checks if a `Layer` property is set, and if so, it opens a new dialog using the `OpenDialog` function. The context for the new dialog is created by optionally adding a `Mode` property to the existing context.
---
--- @param self XOpenLayer The `XOpenLayer` instance being opened.
---
function XOpenLayer:Open()
	if self.Layer ~= "" then
		local context = self:GetContext()
		if self.Mode then
			context = SubContext(context, { Mode = self.Mode })
		end
		local id = self.LayerId ~= "" and self.LayerId or nil
		self.dialog = OpenDialog(self.Layer, nil, context, self, id, self.xtemplate)
	end
end

---
--- Closes the dialog layer opened by the `XOpenLayer:Open()` function.
---
--- This function is called when the `XOpenLayer` instance is done being used. It checks if a dialog was opened, and if so, it removes the open reason for that dialog using a real-time thread.
---
--- @param self XOpenLayer The `XOpenLayer` instance being closed.
---
function XOpenLayer:Done()
	if self.dialog then
		CreateRealTimeThread(self.dialog.RemoveOpenReason, self.dialog, self)
	end
end


----- XContentTemplate

DefineClass.XContentTemplate = {
	__parents = { "XActionsHost" },
	properties = {
		{ category = "Template", id = "RespawnOnContext", name = "Respawn on context update", editor = "bool", default = true, },
		{ category = "Template", id = "RespawnOnDialogMode", name = "Respawn on mode change", editor = "bool", default = true, },
		{ category = "Template", id = "RespawnExpression", name = "Respawn on expression change", editor = "expression", default = empty_func, params = "self, context", 
			dont_save = function(self) return self.RespawnOnContext end },
	},
	IdNode = true,
	HostInParent = true,
	xtemplate = false,
	respawn_value = false,
}

---
--- Initializes an `XContentTemplate` instance.
---
--- This function is called when an `XContentTemplate` instance is created. It sets the `xtemplate` property to the provided `xtemplate` argument, and initializes the `respawn_value` property by calling the `RespawnExpression` function with the provided `context` argument.
---
--- @param self XContentTemplate The `XContentTemplate` instance being initialized.
--- @param parent any The parent of the `XContentTemplate` instance.
--- @param context table The context for the `XContentTemplate` instance.
--- @param xtemplate XTemplate The template for the `XContentTemplate` instance.
---
function XContentTemplate:Init(parent, context, xtemplate)
	self.xtemplate = xtemplate
	self.respawn_value = self:RespawnExpression(context)
end

---
--- Called when the context of the `XContentTemplate` instance is updated.
---
--- This function checks if the `RespawnOnContext` property is set. If it is, and the window is in the "open" state, the `RespawnContent()` function is called to recreate the content of the template.
---
--- If `RespawnOnContext` is not set, the function checks if the `respawn_value` property has changed by comparing it to the result of the `RespawnExpression()` function. If the values are different, the `respawn_value` property is updated and the `RespawnContent()` function is called if the window is in the "open" state.
---
--- @param self XContentTemplate The `XContentTemplate` instance.
--- @param context table The updated context for the `XContentTemplate` instance.
--- @param ... any Additional arguments passed to the function.
---
function XContentTemplate:OnContextUpdate(context, ...)
	if self.RespawnOnContext then
		if self.window_state == "open" then
			self:RespawnContent()
		end
	else
		local respawn_value = self:RespawnExpression(context)
		if rawget(self, "respawn_value") ~= respawn_value then
			self.respawn_value = respawn_value
			if self.window_state == "open" then
				self:RespawnContent()
			end
		end
	end
end

---
--- Called when the dialog mode of the `XContentTemplate` instance changes.
---
--- If the `RespawnOnDialogMode` property is set, this function calls the `RespawnContent()` function to recreate the content of the template.
---
--- @param self XContentTemplate The `XContentTemplate` instance.
--- @param mode string The new dialog mode.
--- @param dialog XDialog The dialog that the `XContentTemplate` instance is associated with.
---
function XContentTemplate:OnDialogModeChange(mode, dialog)
	if self.RespawnOnDialogMode then
		self:RespawnContent()
	end
end

---
--- Respawns the content of the `XContentTemplate` instance.
---
--- This function is responsible for recreating the content of the `XContentTemplate` instance. It performs the following steps:
---
--- 1. Stores the current keyboard focus and rollover state.
--- 2. Deletes all existing children and actions from the `XContentTemplate` instance.
--- 3. Evaluates the children of the `xtemplate` and adds them to the `XContentTemplate` instance.
--- 4. Opens all the newly added children.
--- 5. Invalidates the measure and layout of the `XContentTemplate` instance.
--- 6. Resolves the relative focus order of the children.
--- 7. Creates a new thread to handle the restoration of the keyboard focus and rollover state.
---
--- @param self XContentTemplate The `XContentTemplate` instance.
---
function XContentTemplate:RespawnContent()
	local xtemplate = self.xtemplate
	if xtemplate then
		local desktop = self.desktop
		local focus = desktop.keyboard_focus
		local focus_order = focus and focus:IsWithin(self) and focus:GetFocusOrder()
		local gamepad_rollover = RolloverControl and RolloverControl == focus and RolloverGamepad
		local mouse_rollover = RolloverControl and RolloverControl == desktop.last_mouse_target and RolloverControl:IsWithin(self)
		self:DeleteChildren()
		self:ClearActions()
		xtemplate:EvalChildren(self, self.context)
		for _, win in ipairs(self) do
			win:Open()
		end
		self:InvalidateMeasure()
		self:InvalidateLayout()
		local host = GetActionsHost(self, true)
		if not host or host == self then
			self:ResolveRelativeFocusOrder()
		elseif host and not host:GetThread("resolve_focus") then
			host:CreateThread("resolve_focus", host.ResolveRelativeFocusOrder, host)
		end
		self:DeleteThread("rollover")
		self:CreateThread("rollover", function(self, focus_order, gamepad_rollover, mouse_rollover)
			local focus = self:GetRelativeFocus(focus_order, "nearest")
			if focus then
				focus:SetFocus()
			end
			if focus and gamepad_rollover then
				XCreateRolloverWindow(focus, true, true)
			elseif mouse_rollover then
				local win = XGetRolloverControl()
				if win and win:IsWithin(self) then
					XCreateRolloverWindow(win, false, true)
				end
			end
		end, self, focus_order, gamepad_rollover, mouse_rollover)
		Msg("XWindowRecreated", self)
	end
end


----- XContentTemplateScrollArea

DefineClass.XContentTemplateScrollArea = {
	__parents = { "XScrollArea", "XContentTemplate" },
}


----- XContentTemplateList

DefineClass.XContentTemplateList = {
	__parents = { "XList", "XContentTemplate" },
	MouseScroll = false,
	properties = {
		{ category = "General", id = "KeepSelectionOnRespawn", editor = "bool", default = false },
	},
}

---
--- Handles shortcut key events for the XContentTemplateList class.
---
--- This function is called when a shortcut key is pressed while the XContentTemplateList
--- instance has focus. It first checks if the shortcut is handled by the base XList class,
--- and if so, returns the result. Otherwise, it passes the shortcut to the XActionsHost
--- class to handle.
---
--- @param shortcut string The name of the shortcut key that was pressed.
--- @param source table The object that triggered the shortcut.
--- @param ... any Additional arguments passed with the shortcut.
--- @return string "break" if the shortcut was handled, otherwise nil.
function XContentTemplateList:OnShortcut(shortcut, source, ...)
	if XList.OnShortcut(self, shortcut, source, ...) == "break" then
		return "break"
	end
	return XActionsHost.OnShortcut(self, shortcut, source, ...)
end

---
--- Opens the XContentTemplateList and generates the item hash table.
---
--- This function is called to open the XContentTemplateList. It first generates the item hash table by calling the `GenerateItemHashTable()` function. Then it calls the `Open()` function of the `XContentTemplate` class to perform the actual opening of the list. Finally, it creates a new thread to set the initial selection of the list by calling the `SetInitialSelection()` function.
---
--- @param ... any Additional arguments passed to the `Open()` function.
function XContentTemplateList:Open(...)
	self:GenerateItemHashTable()
	XContentTemplate.Open(self, ...)
	self:CreateThread("SetInitialSelection", self.SetInitialSelection, self)
end

---
--- Respawns the content of the XContentTemplateList and optionally preserves the current selection.
---
--- This function is called to respawn the content of the XContentTemplateList. It first checks if the `KeepSelectionOnRespawn` property is set to `true` and if there is a current selection. If so, it stores the first selected item in the `last_selection` variable. It then calls the `RespawnContent()` function of the `XContentTemplate` class to respawn the content. After that, it generates a new item hash table by calling the `GenerateItemHashTable()` function. It then deletes the existing "SetInitialSelection" thread and creates a new one, passing the `last_selection` variable to the `SetInitialSelection()` function to set the initial selection.
---
--- @param last_selection table|nil The previously selected item, if any, to be restored after respawning the content.
function XContentTemplateList:RespawnContent()
	local last_selection
	if self.KeepSelectionOnRespawn and next(self.selection) then
		last_selection = self.selection[1]
	end
	XContentTemplate.RespawnContent(self)
	self:GenerateItemHashTable()
	self:DeleteThread("SetInitialSelection")
	self:CreateThread("SetInitialSelection", self.SetInitialSelection, self, last_selection)
end