DefineClass.XRollover = {
	__parents = { "InitDone" },
	properties = {
		{ category = "Rollover", id = "RolloverTranslate", editor = "bool", default = true, },
		{ category = "Rollover", id = "RolloverTemplate", editor = "choice", default = "", items = function() return XTemplateCombo("XRolloverWindow") end, },
		{ category = "Rollover", id = "RolloverAnchor", editor = "choice", default = "smart", items = xpopup_anchor_types, },
		{ category = "Rollover", id = "RolloverAnchorId", editor = "text", default = "", },
		{ category = "Rollover", id = "RolloverText", editor = "text", default = "", translate = function(obj) return obj:GetProperty("RolloverTranslate") end, lines = 3, },
		{ category = "Rollover", id = "RolloverDisabledText", editor = "text", default = "", translate = function(obj) return obj:GetProperty("RolloverTranslate") end, lines = 3, },
		{ category = "Rollover", id = "RolloverOffset", editor = "margins", default = box(0, 0, 0, 0), },
	},
}

XGenerateGetSetFuncs(XRollover)

---
--- Resolves the rollover anchor for the current object.
---
--- @param context table The context for the rollover, which may contain an `anchor` field.
--- @param pos table|nil The position to use as the anchor if no other anchor is found.
--- @return table The anchor for the rollover, which may be a node with an `interaction_box` or `box` field, or a `sizebox` with the position if no other anchor is found.
---
function XRollover:ResolveRolloverAnchor(context, pos)
	if context and context.anchor then return context.anchor end
	local anchor
	local id = self.RolloverAnchorId
	if id ~= "" then
		local node = self
		anchor = node and rawget(node, id)
		if not anchor then
			while true do
				node = node:ResolveId("node")
				if not node then break end
				if id == "node" or node.Id == id then
					anchor = node
					break
				end
				anchor = node and rawget(node, id)
				if anchor then break end
			end
		end
	end
	return anchor and (anchor.interaction_box or anchor.box) or pos and sizebox(pos:x(), pos:y(), 1, 1) or self.interaction_box or self.box
end

---
--- Handles changes to the `RolloverTranslate` property of an `XRollover` object.
---
--- When the `RolloverTranslate` property is edited, this function updates the localized properties `RolloverText` and `RolloverDisabledText` accordingly, and marks the object as modified.
---
--- @param prop_id string The ID of the property that was changed.
--- @param old_value any The previous value of the property.
---
function XRollover:OnXTemplateSetProperty(prop_id, old_value)
	-- toggle text properties between Ts and strings when RolloverTranslate is edited
	if prop_id == "RolloverTranslate" then
		self:UpdateLocalizedProperty("RolloverText", self.RolloverTranslate)
		self:UpdateLocalizedProperty("RolloverDisabledText", self.RolloverTranslate)
		ObjModified(self)
	end
end


----- XRolloverWindow

DefineClass.XRolloverWindow = {
	__parents = { "XPopup", "XDrawCache" },
	HandleMouse = false,
	ChildrenHandleMouse = false,
	ZOrder = 1000000,
	RefreshInterval = 1000,
}

---
--- Initializes an `XRolloverWindow` object.
---
--- This function is called when an `XRolloverWindow` is created. It sets the anchor and anchor type for the window based on the provided context, and creates a thread to periodically update the rollover content.
---
--- @param parent any The parent object of the `XRolloverWindow`.
--- @param context table The context for the `XRolloverWindow`, which should contain a `control` field.
---
function XRolloverWindow:Init(parent, context)
	assert(context.control)
	if context.control then
		self:SetAnchor(context.control:ResolveRolloverAnchor(context))
		self:SetAnchorType(context.RolloverAnchor or context.control:GetRolloverAnchor())
	end
	if self.RefreshInterval then
		self:CreateThread("UpdateRolloverContent", function(self)
			while true do
				Sleep(self.RefreshInterval)
				self:UpdateRolloverContent()
			end
		end, self)
	end
end

---
--- Updates the anchor and layout of the `XRolloverWindow` when the associated control moves.
---
--- This function is called when the control associated with the `XRolloverWindow` has moved. It updates the anchor of the window to match the new position of the control, and invalidates the layout of the window to ensure it is properly positioned.
---
--- @param control any The control that has moved.
---
function XRolloverWindow:ControlMove(control)
	self:SetAnchor(control:ResolveRolloverAnchor())
	self:InvalidateLayout()
end

---
--- Updates the content of the `XRolloverWindow`.
---
--- This function is called periodically to update the content of the `XRolloverWindow`. It retrieves the `idContent` field of the `XRolloverWindow` object and calls its `OnContextUpdate` method, passing the current context.
---
function XRolloverWindow:UpdateRolloverContent()
	local content = rawget(self, "idContent")
	if content then
		content:OnContextUpdate(content.context)
	end
end

----- globals

if FirstLoad then
	RolloverWin = false
	RolloverControl = false
	RolloverGamepad = false
end

---
--- Destroys the current rollover window if it exists.
---
--- If the rollover window is currently displayed, this function will destroy it. If the `immediate` parameter is true, the window will be immediately deleted. Otherwise, the window will be closed.
---
--- @param immediate boolean If true, the window will be immediately deleted. Otherwise, it will be closed.
---
function XDestroyRolloverWindow(immediate)
	local win, control = RolloverWin, RolloverControl
	RolloverWin = false
	RolloverControl = false
	if win and win.window_state ~= "destroying" then
		Msg("DestroyRolloverWindow", win, control)
		if immediate then
			win:delete()
		else
			win:Close()
		end
	end
end

---
--- Creates a new rollover window for the given control.
---
--- This function is responsible for creating a new rollover window for the specified control. It first destroys any existing rollover window, then checks if the control has a valid rollover template. If so, it creates a new rollover window using the control's rollover text and context, and associates it with the control. The new rollover window is stored in the `RolloverWin` global variable, and the control is stored in the `RolloverControl` global variable.
---
--- @param control any The control for which to create the rollover window.
--- @param gamepad boolean Whether the rollover window is being created for a gamepad.
--- @param immediate boolean If true, any existing rollover window will be immediately destroyed. Otherwise, it will be closed.
--- @param context table An optional context table to use when creating the rollover window.
--- @return any The newly created rollover window, or `false` if no window was created.
---
function XCreateRolloverWindow(control, gamepad, immediate, context)
	XDestroyRolloverWindow(immediate)
	local modal = terminal.desktop:GetModalWindow()
	if control and control:GetRolloverTemplate() ~= "" then
		local T_text = context and context.RolloverText or control:GetRolloverText()
		local T_context = SubContext(control:GetContext(), context)
		if (T_text or "") ~= "" and (not T_text or not IsT(T_text) or _InternalTranslate(T_text, T_context) ~= "") and (not modal or modal == terminal.desktop or control:IsWithin(modal)) then
			RolloverWin = control:CreateRolloverWindow(gamepad, context) or false
			RolloverControl = control
			RolloverGamepad = gamepad or false
			if Platform.ged then
				g_GedApp:UpdateChildrenDarkMode(RolloverWin)
			end
			Msg("CreateRolloverWindow", RolloverWin, control)
			Msg("XWindowRecreated", RolloverWin)
		end
	end
	return RolloverWin
end

---
--- Retrieves the control that the mouse is currently hovering over and has a valid rollover template.
---
--- This function recursively searches the desktop's mouse target and mouse capture controls to find the control that has a valid rollover template and rollover text. It returns the first such control it finds, or `false` if no valid control is found.
---
--- @param desktop any The desktop to search for the rollover control. If not provided, the global `terminal.desktop` is used.
--- @return any The control with a valid rollover template, or `false` if none is found.
---
function XGetRolloverControl(desktop)
	desktop = desktop or terminal.desktop
	local win = desktop.last_mouse_target or desktop.mouse_capture
	while win and win.window_state ~= "destroying" do
		local T_text = win:GetRolloverText()
		local T_context = win:GetContext()
		if win:GetRolloverTemplate() ~= "" and T_text ~= "" and (not T_text or not IsT(T_text) or _InternalTranslate(T_text, T_context) ~= "") then
			return win
		end
		win = win.parent
	end
end

---
--- Recreates the rollover window for the specified control.
---
--- This function checks if the rollover window and control are valid, and if the control is still the current rollover control. If so, it destroys the existing rollover window and creates a new one using the `XCreateRolloverWindow` function.
---
--- @param win any The control for which to recreate the rollover window.
---
function XRecreateRolloverWindow(win)
	if RolloverWin and RolloverControl == win and win.window_state ~= "destroying" then
		if XGetRolloverControl() == win then
			XCreateRolloverWindow(win, RolloverGamepad, true)
		end
	end
end

---
--- Updates the content of the rollover window for the specified control.
---
--- This function checks if the rollover window and control are valid, and if the control is still the current rollover control. If so, it updates the content of the existing rollover window.
---
--- @param win any The control for which to update the rollover window.
---
function XUpdateRolloverWindow(win)
	if RolloverWin and RolloverControl == win and win.window_state ~= "destroying" then
		RolloverWin:UpdateRolloverContent()
	end
end

----- Rollover thread
if FirstLoad then
	RolloverEnabled = true
	RolloverLastControl = false
	RolloverCurrentControl = false
end

---
--- Enables or disables the rollover functionality.
---
--- When disabled, the rollover window will be destroyed.
---
--- @param enabled boolean Whether to enable or disable the rollover functionality.
---
function SetRolloverEnabled(enabled)
	RolloverEnabled = enabled
	if not enabled then
		XDestroyRolloverWindow(true)
	end
end

---
--- The MouseRollover function is responsible for managing the rollover window functionality in the application.
---
--- It continuously checks the current mouse position and the control under the mouse cursor. If the current rollover control has changed or the mouse has moved a significant distance, it updates the rollover window accordingly. The function also handles the timing of when to create and destroy the rollover window.
---
--- @param none
--- @return none
---
function MouseRollover()
	local last_pos = point20
	local timer
	local desktop = terminal.desktop
	local RolloverTime = const.RolloverTime
	local RolloverRefreshDistance = const.RolloverRefreshDistance
	
	while true do
		local pos = desktop.last_mouse_pos or terminal.GetMousePos()
		local ok, rollover_control = procall(XGetRolloverControl, desktop)
		RolloverCurrentControl = ok and rollover_control or false

		-- change rollover shortly
		if RolloverCurrentControl ~= RolloverLastControl
			or (RolloverLastControl and pos:Dist2D(last_pos) > RolloverRefreshDistance)
		then
			timer = timer or (RolloverCurrentControl ~= RolloverLastControl and RolloverTime or 0)
		elseif not RolloverLastControl then
			timer = false
		end

		if timer and timer < RolloverTime - const.RolloverDestroyTime then
			XDestroyRolloverWindow()
		end
		if timer and timer <= 0 and RolloverEnabled then
			XCreateRolloverWindow(RolloverCurrentControl, false)
			RolloverLastControl, last_pos = RolloverCurrentControl, pos
			timer = false
		end

		Sleep(100)
		timer = timer and timer - 100
	end
end

if FirstLoad then
	RolloverThread = false
end
if Platform.desktop then
	DeleteThread(RolloverThread)
	RolloverThread = CreateRealTimeThread(MouseRollover)
end

if Platform.console then
	function OnMsg.MouseConnected()
		DeleteThread(RolloverThread)
		RolloverThread = CreateRealTimeThread(MouseRollover)
	end

	function OnMsg.MouseDisconnected()
		DeleteThread(RolloverThread)
	end
end