GameVar("gv_LogData", {})

if FirstLoad then
	LogData = {}
	LogShowDebug = false
	CombatLogAnchorBox = false
	CombatLogAnchoredBoxes = {}
end

function OnMsg.GatherSessionData()	
	for i, item in ipairs(LogData) do
		gv_LogData[i] = {item[1], _InternalTranslate(item[2]), item[3]}
	end
end

function OnMsg.LoadSessionData()
	LogData = {}
	for i, item in ipairs(gv_LogData) do
		LogData[i] = {item[1], Untranslated(item[2]), item[3]}
	end
	local dlg = GetDialog("CombatLog")
	if dlg then
		dlg:UpdateText()
	end
end

function OnMsg.NewGameSessionStart()
	local dlg = GetDialog("CombatLog")
	if dlg then
		dlg:UpdateText()
	end
end

function OnMsg.EnterSector(game_start, load_game)
	if not (game_start or load_game) then
		gv_LogData = {}
		LogData = {}
		local dlg = GetDialog("CombatLog")
		if dlg then
			dlg:UpdateText()
		end
	end
end

--- Handles shortcut key presses when the mode dialog is visible.
---
--- If the desktop has a modal window and the mode dialog is visible, and the keyboard focus is not within the mode dialog, this function will pass the shortcut key press to the mode dialog.
---
--- @param shortcut string The shortcut key that was pressed.
--- @param source any The source of the shortcut key press.
--- @param ... any Additional arguments passed with the shortcut key press.
--- @return boolean Whether the shortcut key press was handled by the mode dialog.
function InGameInterface:OnShortcut(shortcut, source, ...)
	local desktop = self.desktop
	if desktop:GetModalWindow() == desktop and self.mode_dialog and self.mode_dialog:GetVisible() and desktop.keyboard_focus and not desktop.keyboard_focus:IsWithin(self.mode_dialog) then
		return self.mode_dialog:OnShortcut(shortcut, source, ...)
	end
end

local function lResolveCombatLogMessageActor(prevLine, name)
	-- Merge same name lines one after another
	if prevLine and prevLine[1] == name then
		return false 
	end

	if name == "debug" then
		return Untranslated("Debug")
	elseif name == "helper" or name == "importanthelper" then
		return "helper"
	elseif name == "short" then
		return T(502734170556, "AIMBot")
	elseif UnitDataDefs[name] then
		return UnitDataDefs[name].Nick or UnitDataDefs[name].Name or Untranslated(name)
	elseif IsT(name) then
		return name
	else
		return Untranslated(name)
	end
end

DefineClass.CombatLogAnchorAnimationWindow = {
	__parents = { "XDialog" },
	properties = {
		{ editor = "bool", id = "flip_vertically", default = false }
	},
	popup_time = 200,
	suppressesCombatLog = false,
}

---
--- Suppresses the combat log by hiding the combat log container and the combat log message fader.
---
--- This function is called when the CombatLogAnchorAnimationWindow is opened, to hide the combat log UI elements.
---
--- @param self CombatLogAnchorAnimationWindow The CombatLogAnchorAnimationWindow instance.
---
function CombatLogAnchorAnimationWindow:SuppressCombatLog()
	local dlg = GetDialog("CombatLog")
	if not dlg or dlg.window_state == "destroying" then return end
	dlg.idLogContainer:SetVisible(false)
	
	local fader = GetDialog("CombatLogMessageFader")
	if fader then fader:SetVisible(false) end
	
	self.suppressesCombatLog = true
end

---
--- Restores the combat log UI elements when the CombatLogAnchorAnimationWindow is closed.
---
--- This function is called when the CombatLogAnchorAnimationWindow is deleted, to show the combat log UI elements that were previously hidden.
---
--- @param self CombatLogAnchorAnimationWindow The CombatLogAnchorAnimationWindow instance.
---
function CombatLogAnchorAnimationWindow:OnDelete()
	if not self.suppressesCombatLog then return end
	local dlg = GetDialog("CombatLog")
	if not dlg then return end
	
	local fader = GetDialog("CombatLogMessageFader")
	if fader then fader:SetVisible(true) end
	
	dlg.idLogContainer:SetVisible(true)
end

---
--- Opens the CombatLogAnchorAnimationWindow and sets its visibility based on whether a combat log anchor box exists.
---
--- This function is called to open the CombatLogAnchorAnimationWindow. It first sets the window as an anchored box, then sets the window's visibility based on whether a combat log anchor box already exists. Finally, it calls the base XDialog:Open() function to open the window.
---
--- @param self CombatLogAnchorAnimationWindow The CombatLogAnchorAnimationWindow instance.
---
function CombatLogAnchorAnimationWindow:Open()
	-- Turn invisible if an anchor exists.
	-- This will trigger the animation in OnLayoutComplete
	CombatLogAnchoredBoxes[self] = true
	self:SetVisible(not CombatLogAnchorBox)
	XDialog.Open(self)
end

---
--- Closes the CombatLogAnchorAnimationWindow and removes it from the CombatLogAnchoredBoxes table.
---
--- This function is called to close the CombatLogAnchorAnimationWindow. It removes the window from the CombatLogAnchoredBoxes table and then calls the base XDialog:Close() function to close the window.
---
--- @param self CombatLogAnchorAnimationWindow The CombatLogAnchorAnimationWindow instance.
---
function CombatLogAnchorAnimationWindow:Close()
	CombatLogAnchoredBoxes[self] = nil
	XDialog.Close(self)
end

function OnMsg.CombatLogVisibleChanged(state)
	if state == "start hiding" then
		PlayFX("CombatLogClose", "start")
	elseif state == "start showing" then
		PlayFX("CombatLogOpen", "start")
	end
end

---
--- Animates the closing of the CombatLogAnchorAnimationWindow.
---
--- This function is responsible for animating the closing of the CombatLogAnchorAnimationWindow. It can either hide the window instead of closing it, or close it instantly without animation.
---
--- @param self CombatLogAnchorAnimationWindow The CombatLogAnchorAnimationWindow instance.
--- @param hideInsteadOfClose boolean If true, the window will be hidden instead of closed.
--- @param instant boolean If true, the window will be closed or hidden instantly without animation.
---
function CombatLogAnchorAnimationWindow:AnimatedClose(hideInsteadOfClose, instant)
	self:DeleteThread("animation-open")
	if not self:IsVisible() then
		self.open = false
		return
	end
	
	if instant then
		Msg("CombatLogVisibleChanged", "start hiding")
		if hideInsteadOfClose then
			self:SetVisible(false)
			self.open = false
		else
			self:Close()
		end
		return
	end

	if self:GetThread("animation-close") then return end
	self:CreateThread("animation-close", function()
		self:AddInterpolation{
			id = "size",
			type = const.intRect,
			duration = self.popup_time,
			originalRect = self.box,
			targetRect = CombatLogAnchorBox,
		}
		Msg("CombatLogVisibleChanged", "start hiding")
		Sleep(self.popup_time)
		if self.window_state ~= "open" then return end

		if hideInsteadOfClose then
			self:SetVisible(false)
			self.open = false
		else
			self:Close()
		end
	end)
end

---
--- Animates the opening of the CombatLogAnchorAnimationWindow.
---
--- This function is responsible for animating the opening of the CombatLogAnchorAnimationWindow. It sets the window's box to match the CombatLogAnchorBox, makes the window visible, and adds an interpolation animation to smoothly transition the window's size to the target size.
---
--- @param self CombatLogAnchorAnimationWindow The CombatLogAnchorAnimationWindow instance.
---
function CombatLogAnchorAnimationWindow:AnimatedOpen()
	local combatLogFader = GetDialog("CombatLogMessageFader")
	if combatLogFader then combatLogFader:DeleteChildren() end
		
	self:DeleteThread("animation-close")
	if self:GetThread("animation-open") then return end
	self:CreateThread("animation-open", function()
		Sleep(1)		
		if self.visible then return end

		self:SetBoxFromAnchor()
		self:SetVisible(true)
		self:AddInterpolation{
			id = "size",
			type = const.intRect,
			duration = self.popup_time,
			originalRect = self.box,
			targetRect = CombatLogAnchorBox,
			flags = const.intfInverse
		}
		local isCombatLog = IsKindOf(self, "CombatLogWindow")
		if isCombatLog then Msg("CombatLogVisibleChanged", "start showing") end
		Sleep(self.popup_time)
		if isCombatLog then Msg("CombatLogVisibleChanged", "visible") end
	end)
end

---
--- Animates the opening of the CombatLogAnchorAnimationWindow.
---
--- This function is called when the layout of the CombatLogAnchorAnimationWindow is complete. It checks if the CombatLogAnchorBox is available and if there is no ongoing animation to close the window. If these conditions are met, it calls the `AnimatedOpen()` function to animate the opening of the window.
---
--- @param self CombatLogAnchorAnimationWindow The CombatLogAnchorAnimationWindow instance.
---
function CombatLogAnchorAnimationWindow:OnLayoutComplete()
	if not CombatLogAnchorBox or self:GetThread("animation-close") then return end
	self:AnimatedOpen()
end

---
--- Sets the box of the CombatLogAnchorAnimationWindow based on the CombatLogAnchorBox.
---
--- This function is responsible for positioning the CombatLogAnchorAnimationWindow relative to the CombatLogAnchorBox. It calculates the appropriate x, y coordinates and dimensions for the window based on the anchor box and any height limits. The window is then positioned and sized accordingly.
---
--- @param self CombatLogAnchorAnimationWindow The CombatLogAnchorAnimationWindow instance.
---
function CombatLogAnchorAnimationWindow:SetBoxFromAnchor()
	local x, y, width, height = false, false, false, false
	
	width, height = self.measure_width, self.measure_height

	local heightLimitPoint = GetCombatLogHeightLimit()
	local _, marginY = ScaleXY(self.scale, 0, 5)
	if heightLimitPoint then
		heightLimitPoint = heightLimitPoint - marginY
	end
	
	if self.flip_vertically then
		if heightLimitPoint and CombatLogAnchorBox:miny() + height >= heightLimitPoint then
			x, y = CombatLogAnchorBox:minx(), CombatLogAnchorBox:miny() - height + CombatLogAnchorBox:sizey()
		else
			x, y = CombatLogAnchorBox:minx(), CombatLogAnchorBox:miny()
		end
	else
		local max = CombatLogAnchorBox:miny() + height
		if heightLimitPoint and max >= heightLimitPoint then
			local belowHeightPoint = max - heightLimitPoint
			x, y = CombatLogAnchorBox:minx(), CombatLogAnchorBox:miny() - belowHeightPoint
		else
			x, y = CombatLogAnchorBox:minx(), CombatLogAnchorBox:miny()
		end
	end

	if self.Dock == "ignore" then
		self:SetBox(x, y, width, height, true)
	elseif self.SetBoxFromAnchorInternal then
		self:SetBoxFromAnchorInternal(x, y)
	end
end

function OnMsg.CombatLogButtonChanged()
	-- Ensure combat log is open.
	if not GetDialog("CombatLog") then
		local dlg = OpenDialog("CombatLog")
		dlg:SetVisible(false)
	end
	
	-- Invalidate any UIs attached to this button.
	for wnd, visible in pairs(CombatLogAnchoredBoxes) do
		if wnd and wnd.window_state ~= "destroying" then
			wnd:SetBoxFromAnchor()
		end
	end

	-- Ensure combat log doesn't clip into anything.
	local log = GetDialog("CombatLog")
	log:SetBoxFromAnchor()
end

CombatLogDefaultZOrder = 2
table.insert(BlacklistedDialogClasses, "CombatLogMessageFader")
DefineClass.CombatLogMessageFader = {
	__parents = { "XDialog" },
	Dock = "ignore",
	ZOrder = CombatLogDefaultZOrder,
	LayoutMethod = "VList",
	FocusOnOpen = "",
	MinWidth = 500,
	MaxWidth = 500,

	
	Clip = "self",
	HandleMouse = false,
	ChildrenHandleMouse = false
}

local irInside = const.irInside
local Intersect2D = empty_box.Intersect2D
---
--- Draws the children of the CombatLogMessageFader dialog, respecting the visibility, DrawOnTop flag, and clip box.
---
--- @param clip_box table The clip box to use when drawing the children.
---
function CombatLogMessageFader:DrawChildren(clip_box)
	local chidren_on_top
	local UseClipBox = self.UseClipBox
	for _, win in ipairs(self) do
		if not win.visible or win.outside_parent then goto continue end
		if win.DrawOnTop then
			chidren_on_top = true
			goto continue
		end
		
		local intersection = Intersect2D(self.content_box, win.box)
		if intersection == irInside then
			win:DrawWindow(clip_box)
		end

		::continue::
	end

	if chidren_on_top then
		for _, win in ipairs(self) do
			if win.DrawOnTop and win.visible and not win.outside_parent and (not UseClipBox or Intersect2D(win.box, clip_box) ~= irOutside) then
				win:DrawWindow(clip_box)
			end
		end
	end
end

---
--- Updates the layout of the CombatLogMessageFader dialog.
---
--- This function is responsible for positioning the CombatLogMessageFader dialog on the screen, taking into account the position of the bottom bar and the height limit of the combat log.
---
--- @param self CombatLogMessageFader The CombatLogMessageFader dialog instance.
---
function CombatLogMessageFader:UpdateLayout()
	if not self.layout_update then return end
	
	if GetUIStyleGamepad() then
		local bottomBar
		local verticalOffset
		if not gv_SatelliteView then
			local igi = GetInGameInterfaceModeDlg()
			bottomBar = igi and igi.idBottomBar
			verticalOffset = 25
		else
			bottomBar = g_SatTimelineUI
			verticalOffset = -50
		end
		
		if bottomBar then
			local _, yMargin = ScaleXY(self.scale, 0, verticalOffset)
			local bbbbox = bottomBar.box
			self:SetBox(
				bbbbox:minx() + bbbbox:sizex() / 2 - self.measure_width / 2,
				bbbbox:miny() - self.measure_height - yMargin,
				self.measure_width,
				self.measure_height
			)
			XDialog.UpdateLayout(self)
			return
		end
	end
	
	local heightLimitPoint = GetCombatLogHeightLimit()
	local _, marginY = ScaleXY(self.scale, 0, 5)
	if heightLimitPoint then
		heightLimitPoint = heightLimitPoint - marginY
	end

	local x = CombatLogAnchorBox and CombatLogAnchorBox:minx() or 0
	local y = CombatLogAnchorBox and CombatLogAnchorBox:maxy() or 0
	local height = 0
	for i, w in ipairs(self) do
		height = height + w.measure_height
		if i > 4 then break end
	end

	local yMax = y + height
	if heightLimitPoint and yMax >= heightLimitPoint then
		local belowHeightPoint = yMax - heightLimitPoint
		y = y - belowHeightPoint
	end
	
	self:SetBox(x, y, self.measure_width, height)
	XDialog.UpdateLayout(self)
end

DefineClass.CombatLogText = {
	__parents = { "XText" },
	Translated = true,
	Padding = box(0, 0, 0, 0),
	TextStyle = "CombatLog",
	HAlign = "left",
	VAlign = "top",
	
	rendered_least_once = false
}

--- Overrides the `DrawWindow` method of the `XWindow` class to set the `rendered_least_once` flag to `true` before calling the parent implementation.
---
--- This method is part of the implementation of the `CombatLogText` class, which is likely a subclass of `XWindow` that represents a text element in the combat log UI. The `rendered_least_once` flag is likely used to track whether the text element has been rendered at least once, which may be useful for optimization or other purposes.
function CombatLogText:DrawWindow(...)
	self.rendered_least_once = true
	return XWindow.DrawWindow(self, ...)
end


DefineClass.CombatLogWindow = {
	__parents = { "CombatLogAnchorAnimationWindow" },
	
	Dock = "ignore",
	ZOrder = CombatLogDefaultZOrder,
	
	scroll_area = false,
	main_textbox = false,
	FocusOnOpen = "",
	open = false
}

---
--- Opens the CombatLogWindow and sets up its initial state.
---
--- This function is part of the implementation of the CombatLogWindow class, which is likely a UI element that displays a combat log in the game.
---
--- When the window is opened, this function performs the following tasks:
--- - Calls the Open method of the parent CombatLogAnchorAnimationWindow class to perform any necessary initialization.
--- - Retrieves the scroll area element of the window and stores it in the self.scroll_area field.
--- - Calls the UpdateText method to update the text displayed in the window.
--- - Checks if there is a PDADialogSatellite window open, and if so, sets the window's z-order to 1 and sets its parent to the idDisplayPopupHost element of the satellite window. Otherwise, it sets the z-order to CombatLogDefaultZOrder and sets the parent to the in-game interface.
---
--- @param ... any additional arguments passed to the Open method
function CombatLogWindow:Open(...)
	CombatLogAnchorAnimationWindow.Open(self, ...)
	self.scroll_area = self:ResolveId("idScrollArea")
	self:UpdateText()
	
	local satellite = GetDialog("PDADialogSatellite")
	if satellite and satellite.window_state ~= "destroying" then
		self:SetZOrder(1)
		local popupHost = satellite:ResolveId("idDisplayPopupHost")
		self:SetParent(popupHost)
	else
		self:SetZOrder(CombatLogDefaultZOrder)
		self:SetParent(GetInGameInterface())
	end
end

---
--- Opens the CombatLogWindow with an animated transition.
---
--- This function is part of the implementation of the CombatLogWindow class, which is likely a UI element that displays a combat log in the game.
---
--- When the window is opened, this function performs the following tasks:
--- - Checks if the window is already open, and returns if so.
--- - Retrieves the PDADialogSatellite window, and if it exists and the CombatLogWindow is not within it, sets the CombatLogWindow's z-order to 1 and sets its parent to the idDisplayPopupHost element of the satellite window.
--- - Calls the AnimatedOpen method of the parent CombatLogAnchorAnimationWindow class to perform the animated opening of the window.
--- - Calls the ScrollToBottom method to scroll the window to the bottom.
--- - Sets the open flag to true to indicate that the window is now open.
---
--- @return nil
function CombatLogWindow:AnimatedOpen()
	if self.open then return end
	
	local satellite = GetDialog("PDADialogSatellite")
	if satellite and not self:IsWithin(satellite) and satellite.window_state ~= "destroying" then
		local popupHost = satellite:ResolveId("idDisplayPopupHost")
		self:SetZOrder(1)
		self:SetParent(popupHost)
		self:UpdateMeasure(self.last_max_width, self.last_max_height)
	end
	
	CombatLogAnchorAnimationWindow.AnimatedOpen(self)
	self:ScrollToBottom()
	self.open = true
end

---
--- Called when the CombatLogWindow is deleted.
---
--- This function is part of the implementation of the CombatLogWindow class, which is likely a UI element that displays a combat log in the game.
---
--- When the CombatLogWindow is deleted, this function sends a "CombatLogVisibleChanged" message to notify other parts of the game that the combat log window has been closed.
---
--- @return nil
function CombatLogWindow:OnDelete()
	Msg("CombatLogVisibleChanged")
end

---
--- Called when the layout of the CombatLogWindow is complete.
---
--- This function is part of the implementation of the CombatLogWindow class, which is likely a UI element that displays a combat log in the game.
---
--- When the layout of the CombatLogWindow is complete, this function checks if the window is visible. If it is, it calls the OnLayoutComplete method of the parent CombatLogAnchorAnimationWindow class to perform any additional layout-related tasks.
---
--- This function is likely called as part of the UI layout and rendering process, and ensures that the CombatLogWindow is properly positioned and sized when its layout is complete.
---
--- @param ... any additional arguments passed to the OnLayoutComplete method
--- @return nil
function CombatLogWindow:OnLayoutComplete(...)
	if self.visible then -- The OnLayoutComplete animation can cause this window to appear when hidden.
		CombatLogAnchorAnimationWindow.OnLayoutComplete(self)
	end
end

---
--- Scrolls the CombatLogWindow to the bottom of the scroll area.
---
--- This function is part of the implementation of the CombatLogWindow class, which is likely a UI element that displays a combat log in the game.
---
--- When called, this function first deletes any existing "delayed_scroll" thread, then creates a new thread to scroll the window to the bottom of the scroll area. The scrolling is performed asynchronously to avoid blocking the main thread.
---
--- If the scroll_area table is empty, the function simply returns without performing any scrolling.
---
--- @return nil
function CombatLogWindow:ScrollToBottom()
	self:DeleteThread("delayed_scroll")
	self:CreateThread("delayed_scroll", function()
		if #self.scroll_area == 0 then return end
		local lastLine = self.scroll_area[#self.scroll_area]
		self.scroll_area:ScrollIntoView(lastLine)
	end)
end

---
--- Called when the scale of the CombatLogWindow has changed.
---
--- This function is part of the implementation of the CombatLogWindow class, which is likely a UI element that displays a combat log in the game.
---
--- When the scale of the CombatLogWindow changes, this function calls the `ScrollToBottom()` method to scroll the window to the bottom of the scroll area. This ensures that the combat log remains visible and up-to-date after the window is resized.
---
--- @return nil
function CombatLogWindow:OnScaleChanged()
	self:ScrollToBottom()
end

---
--- Calculates the height limit for the combat log window.
---
--- This function is used to determine the maximum height that the combat log window should be allowed to occupy on the screen. It checks various UI elements and dialogs to find the appropriate height limit.
---
--- @return number The height limit for the combat log window, in pixels.
function GetCombatLogHeightLimit()
	if g_SatelliteUI then
		local satDiag = GetDialog(g_SatelliteUI)
		local startButton = satDiag and satDiag.idStartButton
		if startButton then
			return startButton.box:miny()
		end
	end

	local pda = GetDialog("PDADialogSatellite")
	if pda then
		return pda.idDisplay.box:maxy()
	end

	local igi = GetInGameInterfaceModeDlg()
	if not IsKindOf(igi, "IModeCommonUnitControl") then return end
	
	if igi and igi.idStartButton then
		return igi.idStartButton.box:miny()
	end
	
	local bottomLeftUI = igi.idLeft
	if not bottomLeftUI then return end
	local limitPoint = bottomLeftUI.box:miny()
	
	local weaponUI = igi.idWeaponUI
	if weaponUI and weaponUI.idOtherSets then
		--limitPoint = weaponUI.idOtherSets.box:miny()
	end
	
	return limitPoint
 end

local function FindLastFilterPassingLine()
	for i = #LogData - 1, 1, -1 do
		local item = LogData[i]
		if (item[1]~= "helper" or item[1]~= "importanthelper") and (item[1] ~= "debug" or LogShowDebug) then
			return item
		end
	end
end

local function lSetupText(textWnd, item, name)
	textWnd:SetTranslate(true)
	if name then
		if name == "helper" or name == "importanthelper" then
			textWnd:SetText(T{997455386796, "<indent><text>", indent = "  ", text = item[2]})
		else
			textWnd:SetText(T{632558295987, "<em><name></em>: <text>", name = name, text = item[2]})
		end
	else
		textWnd:SetText(T{588344253198, "><text>", text = item[2]})
	end
	if textWnd.window_state ~= "open" then textWnd:Open() end
end

---
--- Adds a new line to the combat log window.
---
--- @param item table The log data item to add to the window.
---
function CombatLogWindow:LineAdded(item)
	if item[1] == "debug" and not LogShowDebug then return end

	local isAtBottom = (self.scroll_area.scroll_range_y - self.scroll_area.content_box:sizey()) - self.scroll_area.PendingOffsetY < self.scroll_area.MouseWheelStep
	local newLabel = XTemplateSpawn("CombatLogText", self.scroll_area)
	lSetupText(newLabel, item, lResolveCombatLogMessageActor(FindLastFilterPassingLine(), item[1]))
	if isAtBottom then
		self.scroll_area:ScrollIntoView(newLabel)
	end
end

---
--- Updates the text in the combat log window.
---
--- This function is responsible for updating the text displayed in the combat log window. It iterates through the log data and sets up the text for each line, creating new labels as needed. It also ensures that the window scrolls to the bottom if the user was already at the bottom.
---
--- @param self CombatLogWindow The combat log window instance.
---
function CombatLogWindow:UpdateText()
	local idScrollArea = self.scroll_area
	local spawnedLines = #idScrollArea
	local textLines = #LogData
	local count = 0

	local prevFilteredLine = false
	for i, item in ipairs(LogData) do
		local name = item[1]
		if name ~= "debug" or LogShowDebug then
			count = count + 1
			local labelWindow
			local nameResolved = lResolveCombatLogMessageActor(prevFilteredLine, name)
			if count > spawnedLines then
				labelWindow = XTemplateSpawn("CombatLogText", idScrollArea)
			else
				labelWindow = idScrollArea[count]
			end
			lSetupText(labelWindow, item, nameResolved)
			prevFilteredLine = item
		end
	end

	while #idScrollArea > count do
		idScrollArea[#idScrollArea]:delete()
	end
	if #idScrollArea > 0 then
		idScrollArea:ScrollIntoView(idScrollArea[#idScrollArea])
	end
end

---
--- Handles the mouse button up event for the CombatLogWindow.
---
--- This function is called when the mouse button is released within the CombatLogWindow. It first checks if the mouse is within the window, and if so, it calls the parent class's `OnMouseButtonUp` function and returns "break" to indicate that the event has been handled.
---
--- @param self CombatLogWindow The CombatLogWindow instance.
--- @param pt table The mouse position.
--- @param ... Additional arguments passed to the function.
--- @return string "break" to indicate that the event has been handled.
---
function CombatLogWindow:OnMouseButtonDown(pt, ...)
	if not self:MouseInWindow(pt) then return end
	XDialog.OnMouseButtonDown(self, pt, ...)
	return "break"
end

---
--- Handles the mouse button up event for the CombatLogWindow.
---
--- This function is called when the mouse button is released within the CombatLogWindow. It first checks if the mouse is within the window, and if so, it calls the parent class's `OnMouseButtonUp` function and returns "break" to indicate that the event has been handled.
---
--- @param self CombatLogWindow The CombatLogWindow instance.
--- @param pt table The mouse position.
--- @param ... Additional arguments passed to the function.
--- @return string "break" to indicate that the event has been handled.
---
function CombatLogWindow:OnMouseButtonUp(pt, ...)
	if not self:MouseInWindow(pt) then return end
	XDialog.OnMouseButtonUp(self, pt, ...)
	return "break"
end

---
--- Handles the mouse wheel scroll back event for the CombatLogWindow.
---
--- This function is called when the mouse wheel is scrolled back within the CombatLogWindow. It first checks if the mouse is within the window, and if so, it calls the `OnMouseWheelBack` function of the `idScrollArea` and returns "break" to indicate that the event has been handled.
---
--- @param self CombatLogWindow The CombatLogWindow instance.
--- @param pt table The mouse position.
--- @param ... Additional arguments passed to the function.
--- @return string "break" to indicate that the event has been handled.
---
function CombatLogWindow:OnMouseWheelForward(pt, ...)
	if not self:MouseInWindow(pt) then return end
	local scroll = self:ResolveId("idScrollArea")
	scroll:OnMouseWheelForward(pt, ...)
	return "break"
end

---
--- Handles the mouse wheel scroll back event for the CombatLogWindow.
---
--- This function is called when the mouse wheel is scrolled back within the CombatLogWindow. It first checks if the mouse is within the window, and if so, it calls the `OnMouseWheelBack` function of the `idScrollArea` and returns "break" to indicate that the event has been handled.
---
--- @param self CombatLogWindow The CombatLogWindow instance.
--- @param pt table The mouse position.
--- @param ... Additional arguments passed to the function.
--- @return string "break" to indicate that the event has been handled.
---
function CombatLogWindow:OnMouseWheelBack(pt, ...)
	if not self:MouseInWindow(pt) then return end
	local scroll = self:ResolveId("idScrollArea")
	scroll:OnMouseWheelBack(pt, ...)
	return "break"
end

---
--- Logs a combat-related message to the combat log.
---
--- This function is responsible for adding a new line to the combat log. It checks if the combat UI is hidden, and if not, it adds a new line to the `LogData` table and notifies the `CombatLog` dialog if it exists. If the message is marked as "important", it also creates a fading text label in the `CombatLogMessageFader` dialog.
---
--- @param actor string The actor responsible for the message, or a special value like "important" or "debug".
--- @param msg string The message to be logged.
--- @param dontTHN boolean (optional) Whether to not translate the message.
---
function CombatLog(actor, msg, dontTHN)
	if CheatEnabled("CombatUIHidden") then return end

	if actor == "debug" and not IsT(msg) then
		msg = Untranslated(msg)
	end
	assert(msg and IsT(msg))

	local important = actor == "important" or actor == "importanthelper"
	if important then actor = "short" end

	local newLine = { actor, msg, Game and Game.CampaignTime or 0}
	LogData[#LogData + 1] = newLine
	
	local diag = GetDialog("CombatLog")
	if diag then diag:LineAdded(newLine) end
	
	ObjModified(LogData)
	
	if important and (not diag or not diag.open) then
		local nameResolved = lResolveCombatLogMessageActor(false, actor)
		local faderContainer = GetDialog("CombatLogMessageFader") or OpenDialog("CombatLogMessageFader")
		local labelWindow = XTemplateSpawn("CombatLogText", faderContainer)
		labelWindow:SetTextStyle("CombatLogFade")
		labelWindow:SetBackground(GetColorWithAlpha(GameColors.DarkB, 125))
		labelWindow:SetPadding(box(5, 5, 5, 5))
		
		labelWindow:SetMinWidth(faderContainer.MinWidth)
		labelWindow:SetMaxWidth(faderContainer.MaxWidth)

		-- Hide fading texts while in a conversation
		labelWindow:SetVisible(false, true)
		labelWindow:CreateThread(function()
			WaitPlayerControl()

			RunWhenXWindowIsReady(labelWindow, function()
				labelWindow:AddInterpolation({
					id = "move",
					type = const.intRect,
					OnLayoutComplete = IntRectTopLeftRelative,
					targetRect = labelWindow:CalcZoomedBox(600),
					originalRect = labelWindow.box,
					duration = 200,
					autoremove = true,
					flags = const.intfInverse
				})
			end)
			
			labelWindow:SetVisible(true, true)
			while not labelWindow.rendered_least_once do
				Sleep(5)
			end
			Sleep(10000)
			labelWindow.FadeOutTime = 400
			labelWindow:SetVisible(false)
			Sleep(labelWindow.FadeOutTime)
			labelWindow:Close()
		end)
		lSetupText(labelWindow, newLine, nameResolved)
	end
end

--- Hides the combat log dialog and deletes the children of the combat log message fader dialog.
---
--- @param nonInstant boolean (optional) If true, the combat log dialog will not be closed instantly.
function HideCombatLog(nonInstant)
	local combatLog = GetDialog("CombatLog")
	if combatLog then
		combatLog:AnimatedClose("hideInsteadOfClose", not nonInstant and "instant")
		local fader = GetDialog("CombatLogMessageFader")
		if fader then fader:DeleteChildren() end
	end
end

OnMsg.OpenPDA = HideCombatLog
OnMsg.CloseSatelliteView = HideCombatLog
OnMsg.ModifyWeaponDialogOpened = HideCombatLog
OnMsg.HideCombatLog = HideCombatLog

--- Returns the appropriate name style for a combat log entry based on the unit's affiliation.
---
--- @param unitTemplate table The unit template for the combat log entry.
--- @return string The name style to use for the combat log entry.
function GetCombatLogNameStyle(unitTemplate)
	local affil = unitTemplate and unitTemplate.Affiliation
	if affil == "AIM" then
		return "CombatLogNameMerc"
	elseif affil == "Legion" then
		return "CombatLogNameEnemy"
	end
	return "CombatLogButtonActive"
end

--- Opens the combat log dialog.
---
--- If the "CombatUIHidden" cheat is enabled, this function will not open the combat log dialog.
--- If the combat log dialog is already open, this function will animate it open.
--- If the combat log dialog is not open, this function will open the dialog.
function OpenCombatLog()
	if CheatEnabled("CombatUIHidden") then return end

	local combatLog = GetDialog("CombatLog")
	if combatLog then
		combatLog:AnimatedOpen()
		return
	end
	OpenDialog("CombatLog")
end