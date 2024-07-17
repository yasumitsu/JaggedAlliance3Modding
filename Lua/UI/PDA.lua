-- Super specific hack for the PDA screen where we want its children to be inside it,
-- but the frame to be on the outside below specific children (DrawOnTop).
DefineClass.PDAScreen = {
	__parents = { "XImage", "XAspectWindow" },
	vignette_image = "UI/PDA/pda_vignette",
	vignette_image_id = false,
	
	light_image = "UI/PDA/T_PDA_Frame_Light",
	light_image_id = false,
	light_color_interp = false,
	
	light_image_buttons = "UI/PDA/T_PDA_Frame_Buttons_Light",
	light_image_buttons_id = false,
	buttons_wnd = false,
	
	screen_background_img = "UI/PDA/T_PDA_Background",
	screen_background_img_id = false,
	
	screen_on_interp = false,
	screen_on = false,
	
	Fit = "smallest"
}

-- These two are here for breakpointing purposes

---
--- Measures the size of the PDAScreen window.
---
--- This function overrides the `Measure` method of the `XAspectWindow` class to provide custom measurement logic for the PDAScreen window.
---
--- @param ... any additional arguments passed to the base class `Measure` method
--- @return number, number the measured width and height of the PDAScreen window
---
function PDAScreen:Measure(...)
	return XAspectWindow.Measure(self, ...)
end

---
--- Invalidates the measurement of the PDAScreen window.
---
--- This function overrides the `InvalidateMeasure` method of the `XAspectWindow` class to provide custom invalidation logic for the PDAScreen window.
---
--- @param ... any additional arguments passed to the base class `InvalidateMeasure` method
---
function PDAScreen:InvalidateMeasure(...)
	XAspectWindow.InvalidateMeasure(self, ...)
end

-- This function is a mix of the functionality XFitContent and XAspectWindow
-- in order to achieve scale-based fitting at a specific aspect ratio
local box0 = box(0, 0, 0, 0)
---
--- Sets the layout space for the PDAScreen window.
---
--- This function overrides the `SetLayoutSpace` method of the `XAspectWindow` class to provide custom layout logic for the PDAScreen window.
---
--- @param x number the x-coordinate of the layout space
--- @param y number the y-coordinate of the layout space
--- @param width number the width of the layout space
--- @param height number the height of the layout space
---
function PDAScreen:SetLayoutSpace(x, y, width, height)
	local fit = self.Fit
	if fit == "none" then
		XWindow.SetLayoutSpace(self, x, y, width, height)
	end
	
	assert(self.Margins == box0)
	assert(self.Padding == box0)
	local aspect_x, aspect_y = self.Aspect:xy()
	local h_align = self.HAlign
	if fit == "smallest" or fit == "largest" then
		local space_is_wider = width * aspect_y >= height * aspect_x
		fit = space_is_wider == (fit == "largest") and "width" or "height"
	end
	if fit == "width" then
		local h = width * aspect_y / aspect_x
		local v_align = self.VAlign
		if v_align == "top" then
		elseif v_align == "center" or v_align == "stretch" then
			y = y + (height - h) / 2
		elseif v_align == "bottom" then
			y = y + (height - h)
		end
		height = h
	elseif fit == "height" then
		local w = height * aspect_x / aspect_y
		local h_align = self.HAlign
		if h_align == "left" then
		elseif h_align == "center" or h_align == "stretch" then
			x = x + (width - w) / 2
		elseif h_align == "right" then
			x = x + (width - w)
		end
		width = w
	end
	
	-- 1920x1080 taken from GetUIScale()
	-- The target resolution should be in the same aspect ratio as the requested one.
	-- In our case it works out :)
	local scaleX = MulDivRound(width, 1000, 1920)
	local scaleY = MulDivRound(height, 1000, 1080)
	
	for _, child in ipairs(self) do
		if child.Id ~= "idDiode" then
			child:SetOutsideScale(point(scaleX, scaleY))
		else
			-- pda image size, which the diode is cut from
			local diodeScaleX = MulDivRound(width, 1000, 1900)
			local diodeScaleY = MulDivRound(height, 1000, 990)
			
			-- diode image size 338x233 with two columns
			local diodeWidth = MulDivRound(338 / 2, diodeScaleX, 1000)
			local diodeHeight = MulDivRound(233, diodeScaleY, 1000)
			
			child:SetOutsideScale(point(1000, 1000))
			child:SetBox(x, y, diodeWidth + 1, diodeHeight + 1)
		end
	end

	self:SetBox(x, y, width, height)
end

---
--- Opens the PDA screen.
--- Initializes the necessary resources and assets for the PDA screen, such as the vignette image, light image, and screen background image.
--- Sets up an interpolation for the light color, which will animate the light color over time.
--- Turns on the PDA screen by calling the `TurnOnScreen()` function.
--- Finally, calls the `XImage.Open()` function to open the PDA screen.
---
--- @param self PDAScreen The PDA screen instance.
function PDAScreen:Open()
	self.vignette_image_id = ResourceManager.GetResourceID(self.vignette_image)
	self.light_image_id = ResourceManager.GetResourceID(self.light_image)
	self.light_image_buttons_id = ResourceManager.GetResourceID(self.light_image_buttons)
	self.screen_background_img_id = ResourceManager.GetResourceID(self.screen_background_img)
	self.buttons_wnd = self:ResolveId("idButtonFrame")

	self.light_color_interp = {
		id = "light_interp",
		type = const.intColor,
		startValue = RGBA(255, 255, 255, 210),
		endValue = RGBA(255, 255, 255, 255),
		duration = 200,
		flags = bor(const.intfRealTime, const.intfPingPong, const.intfLooping),
		modifier_type = const.modInterpolation,
		start = GetPreciseTicks()
	}

	self:TurnOnScreen()
	XImage.Open(self)
end

---
--- Turns off the PDA screen.
--- Deletes the "turn_screen_on" thread and sets the `screen_on` flag to `false`.
---
--- @param self PDAScreen The PDA screen instance.
function PDAScreen:TurnOffScreen()
	self:DeleteThread("turn_screen_on")
	self.screen_on = false
end

---
--- Turns on the PDA screen.
--- Initializes an interpolation for the screen's alpha value, which will animate the screen's appearance over time.
--- Creates a thread that waits for a delay, sets the `screen_on` flag to 1, invalidates the screen, waits for another interval, sets the `screen_on` flag to 2, invalidates the screen, and then sends a "PDAScreenFullyOn" message.
---
--- @param self PDAScreen The PDA screen instance.
--- @param delay number (optional) The delay before the screen turns on, in milliseconds.
function PDAScreen:TurnOnScreen(delay)
	local screenOnDelay = 550
	local screenOnIntr = 130
	self.screen_on_interp = {
		id = "screen_on_interp",
		type = const.intAlpha,
		startValue = 0,
		endValue = 255,
		duration = screenOnIntr,
		flags = const.intfRealTime,
		modifier_type = const.modInterpolation,
		start = GetPreciseTicks() + screenOnDelay,
	}
	self:Invalidate()
	self:CreateThread("turn_screen_on", function()
		Sleep(screenOnDelay)
		self.screen_on = 1
		self:Invalidate()
		Sleep(screenOnIntr)
		self.screen_on = 2
		self:Invalidate()
		Msg("PDAScreenFullyOn")
	end)
end

---
--- Draws the content of the PDA screen.
--- This function is a no-op and does not perform any drawing.
---
--- @param self PDAScreen The PDA screen instance.
function PDAScreen:DrawContent()
	-- nop
end

---
--- Draws the background of the PDA screen.
--- This function is a no-op and does not perform any drawing.
---
--- @param self PDAScreen The PDA screen instance.
function PDAScreen:DrawBackground()
	-- nop
end

local irOutside = const.irOutside
---
--- Draws the children of the PDA screen, including the background, content, and any windows or light effects.
---
--- @param self PDAScreen The PDA screen instance.
--- @param clip_box table The clipping box to use for drawing.
function PDAScreen:DrawChildren(clip_box)
	if self.window_state ~= "open" then return end
	local UseClipBox = self.UseClipBox
	local scaleX, scaleY = ScaleXY(self.scale, self.ImageScale:xy())
	local topMod = false
	
	local drawBg = not self.screen_on or self.screen_on == 1
	local drawWindows = self.screen_on and self.screen_on >= 1
	
	-- Black background - simulates screen off
	local node = self:ResolveId("node")
	if drawBg then
		UIL.DrawFrame(self.screen_background_img_id, self.box, self.Rows, self.Columns, self:GetRow(), self:GetColumn(),
			empty_box, not self.TileFrame, self.TransparentCenter, scaleX, scaleY, self.FlipX, self.FlipY)
			
		node.idDisplayPopupHost:DrawWindow(clip_box)
	else
		UIL.DrawSolidRect(node.idDisplay.box, black)
	end
	
	-- All of the PDA content, except windows which are DrawOnTop
	if drawWindows then
		topMod = UIL.ModifiersGetTop()
		UIL.PushModifier(self.screen_on_interp)

		for _, win in ipairs(self) do
			if win.visible and not win.outside_parent and
				(not UseClipBox or win.box:Intersect2D(clip_box) ~= irOutside) then
				if not win.DrawOnTop then
				
					if win == node.idRolloverArea then
						-- Punchtrough sector operations dim
						if g_SatTimelineUI and GetDialog("SectorOperationsUI") then
							g_SatTimelineUI:DrawWindow()
						end
					end
				
					win:DrawWindow(clip_box)
				end
			end
		end
		
		UIL.ModifiersSetTop(topMod)

		UIL.DrawFrame(self.vignette_image_id, node.idDisplay.box, self.Rows, self.Columns, self:GetRow(), self:GetColumn(),
			empty_box, not self.TileFrame, self.TransparentCenter, scaleX, scaleY, self.FlipX, self.FlipY)
	end

	-- The PDA frame.
	XImage.DrawBackground(self)
	XImage.DrawContent(self)

	-- DrawOnTop windows. These are on top of the PDA frame. Stuff like the dog tags and other decoration.
	for _, win in ipairs(self) do
		if win.DrawOnTop and win.visible and not win.outside_parent and (not UseClipBox or win.box:Intersect2D(clip_box) ~= irOutside)
			and win ~= self.buttons_wnd then
			win:DrawWindow(clip_box)
		end
	end

	-- If the screen is on, draw light effects.
	if self.screen_on then
		-- Screen light
		if self.light_color_interp then
			topMod = UIL.ModifiersGetTop()
			UIL.PushModifier(self.light_color_interp)
		end
		UIL.DrawFrame(self.light_image_id, self.box, self.Rows, self.Columns, self:GetRow(), self:GetColumn(),
			empty_box, not self.TileFrame, self.TransparentCenter, scaleX, scaleY, self.FlipX, self.FlipY)
		if topMod then
			UIL.ModifiersSetTop(topMod)
		end
			
		-- Top buttons
		if self.buttons_wnd then
			self.buttons_wnd:DrawWindow(clip_box)
		end
		
		-- Light reflecting off of buttons mask.
		if self.light_color_interp then
			topMod = UIL.ModifiersGetTop()
			UIL.PushModifier(self.light_color_interp)
		end
		if self.buttons_wnd then
			UIL.DrawFrame(self.light_image_buttons_id, self.buttons_wnd.box, self.Rows, self.Columns, self:GetRow(), self:GetColumn(),
				empty_box, not self.TileFrame, self.TransparentCenter, scaleX, scaleY, self.FlipX, self.FlipY)
		end	
		if topMod then
			UIL.ModifiersSetTop(topMod)
		end
	end
end

---
--- Gets the mouse target for the PDAScreen.
---
--- If the SatTimelineUI is visible and the mouse is over it, the mouse target from the SatTimelineUI is returned.
--- Otherwise, the mouse target from the XImage is returned.
---
--- @param pt table The point to check for the mouse target.
--- @return table|nil The mouse target, or nil if no target is found.
--- @return table|nil The mouse context, or nil if no context is found.
---
function PDAScreen:GetMouseTarget(pt)
	if g_SatTimelineUI and GetDialog("SectorOperationsUI") and g_SatTimelineUI:MouseInWindow(pt) then
		local tar, cur = g_SatTimelineUI:GetMouseTarget(pt)
		if tar then return tar, cur end
	end

	local mT, mC = XImage.GetMouseTarget(self, pt)
	if mT then return mT, mC end
end

-- XTextButton that can also be selected.
DefineClass.XSelectableTextButton = {
	__parents = { "XTextButton" },
	properties = {
		{ id = "selected", editor = "bool", default = false },
	},
	Translate = true,
	cosmetic_state = "none",
	FXMouseIn = "buttonRollover",
	FXPress = "buttonPress",
	FXPressDisabled = "IactDisabled"
}

---
--- Opens the XSelectableTextButton and updates its state.
---
--- This function is called to open the XSelectableTextButton. It first calls the `Open()` function of the parent `XTextButton` class, and then updates the state of the button by calling the `UpdateState()` function.
---
--- @function XSelectableTextButton:Open
--- @return nil
function XSelectableTextButton:Open()
	XTextButton.Open(self)
	self:UpdateState()
end

---
--- Sets the rollover state of the XSelectableTextButton.
---
--- This function is called when the button's rollover state changes. It updates the visual appearance of the button to reflect the rollover state.
---
--- @function XSelectableTextButton:SetRolloverState
--- @return nil
function XSelectableTextButton:SetRolloverState()
	-- impl
end

---
--- Sets the selected state of the XSelectableTextButton.
---
--- This function is called when the button's selected state changes. It updates the visual appearance of the button to reflect the selected state.
---
--- @function XSelectableTextButton:SetSelectedState
--- @return nil
function XSelectableTextButton:SetSelectedState()
	-- impl
end

---
--- Sets the disabled state of the XSelectableTextButton.
---
--- This function is called when the button's enabled state changes to disabled. It updates the visual appearance of the button to reflect the disabled state.
---
--- @function XSelectableTextButton:SetDisabledState
--- @return nil
function XSelectableTextButton:SetDisabledState()
	-- impl
end

---
--- Sets the default state of the XSelectableTextButton.
---
--- This function is called when the button's state needs to be reset to the default appearance. It updates the visual appearance of the button to reflect the default state.
---
--- @function XSelectableTextButton:SetDefaultState
--- @return nil
function XSelectableTextButton:SetDefaultState()
	-- impl
end

---
--- Updates the visual state of the XSelectableTextButton based on its current enabled, selected, and rollover states.
---
--- This function is called whenever the button's state changes to ensure the visual appearance reflects the new state. It checks the current cosmetic state of the button and calls the appropriate state-specific function to update the appearance (SetDisabledState, SetSelectedState, SetRolloverState, SetDefaultState).
---
--- @function XSelectableTextButton:UpdateState
--- @return nil
function XSelectableTextButton:UpdateState()
	local cosmetic_state = self.cosmetic_state
	if not self.enabled then
		if cosmetic_state == "disabled" then return end
		self:SetDisabledState()
		self.cosmetic_state = "disabled"
	elseif self.selected then
		if cosmetic_state == "selected" then return end
		self:SetSelectedState()
		self.cosmetic_state = "selected"
	elseif self.rollover then
		if cosmetic_state == "rollover" then return end
		self:SetRolloverState()
		self.cosmetic_state = "rollover"
	else
		if cosmetic_state == "default" then return end
		self:SetDefaultState()
		self.cosmetic_state = "default"
	end
end

---
--- Sets the rollover state of the XSelectableTextButton.
---
--- This function is called when the button's rollover state changes. It updates the visual appearance of the button to reflect the rollover state.
---
--- @param rollover boolean Whether the button is in a rollover state or not.
--- @return nil
function XSelectableTextButton:SetRollover(rollover)
	if self.selected and rollover then return end
	XTextButton.SetRollover(self, rollover)
	self:UpdateState()
end

---
--- Sets the selected state of the XSelectableTextButton.
---
--- This function is called when the button's selected state changes. It updates the visual appearance of the button to reflect the selected state.
---
--- @param selected boolean Whether the button is in a selected state or not.
--- @return nil
function XSelectableTextButton:SetSelected(selected)
	self.selected = selected
	self:UpdateState()
end

---
--- Sets the enabled state of the XSelectableTextButton.
---
--- This function is called when the button's enabled state changes. It updates the visual appearance of the button to reflect the enabled state.
---
--- @param enabled boolean Whether the button is enabled or not.
--- @return nil
function XSelectableTextButton:SetEnabled(enabled)
	XTextButton.SetEnabled(self, enabled)
	self:UpdateState()
end

DefineClass.PDACommonButtonClass = {
	__parents = { "XTextButton" },
	shortcut = false,
	shortcut_gamepad = false,
	applied_gamepad_margin = false,
	
	FXMouseIn = "buttonRollover",
	FXPress = "buttonPress",
	FXPressDisabled = "IactDisabled",
	Padding = box(8, 0, 8, 0),
	MinHeight = 26,
	MaxHeight = 26,
	MinWidth = 124,
	SqueezeX = true,
	MouseCursor = "UI/Cursors/Pda_Hand.tga",
}

DefineClass.PDACommonCheckButtonClass = {
	__parents = { "XCheckButton" },
	shortcut = false,
	shortcut_gamepad = false,
	applied_gamepad_margin = false,
	
	FXMouseIn = "buttonRollover",
	FXPress = "buttonPress",
	FXPressDisabled = "IactDisabled",
	Padding = box(8, 0, 8, 0),
	MinHeight = 26,
	MaxHeight = 26,
	MinWidth = 124,
	SqueezeX = true,
	MouseCursor = "UI/Cursors/Pda_Hand.tga",
	Icon = "UI/PDA/WEBSites/Bobby Rays/delivery_checkbox.png",
}

---
--- Opens a container window for the PDACommonButtonClass and sets up the layout and visibility of the button's shortcut controls.
---
--- This function is called when the button is opened. It creates a container window, sets its layout and alignment properties, and adds the button's label to the container. If the button has an associated action, it also creates a shortcut control for the action and, if the action has a gamepad shortcut, a gamepad-specific shortcut control.
---
--- The gamepad-specific shortcut control is set to be visible only when the UI style is gamepad, and it is responsible for updating its own visibility and the clip box of its parent container when the UI style changes.
---
--- @param self PDACommonButtonClass The button instance.
--- @return nil
function PDACommonButtonClass:Open()
	local container = XTemplateSpawn("XWindow", self)
	container:SetLayoutMethod("HList")
	container:SetHAlign("center")
	container:SetVAlign("center")
	container:SetId("idContainer")
	self.idLabel:SetParent(container)
	
	if rawget(self, "action") then
		self.shortcut = XTemplateSpawn("PDACommonButtonActionShortcut", container, self.action)

		local gamepadShortcut = self.action.ActionGamepad
		if (gamepadShortcut or "") ~= "" then
			self.shortcut_gamepad = XTemplateSpawn("XContextControl", self, "GamepadUIStyleChanged")
			self.shortcut_gamepad:SetLayoutMethod("HList")			
			self.shortcut_gamepad:SetHAlign("left")
			self.shortcut_gamepad:SetVAlign("center")
			self.shortcut_gamepad:SetId("idGamepadShortcut")
			self.shortcut_gamepad:SetIdNode(true)
			self.shortcut_gamepad:SetUseClipBox(false)
			self.shortcut_gamepad.OnContextUpdate = function(this,context,...)
				local gamepad = GetUIStyleGamepad()
				this:SetVisible(gamepad)
				this.parent:InvalidateLayout()
				this.parent.parent:SetClip(not gamepad and "parent & self" or false)
			end
			local keys = SplitShortcut(gamepadShortcut)
			for i = 1, #keys do
				local image_path, scale = GetPlatformSpecificImagePath(keys[i])
				local img = XTemplateSpawn("XImage", self.shortcut_gamepad)				
				img:SetUseClipBox(false)
				img:SetImage(image_path)
				img:SetImageScale(point(650,650))				
				img:SetDisabledImageColor(RGBA(255,255,255,255))	
			end
		end		
	end
	XTextButton.Open(self)
end

---
--- Measures the width and height of the PDACommonButtonClass instance, taking into account the width of any gamepad-specific shortcut controls.
---
--- If the UI style is gamepad, the function adds half the width of the gamepad shortcut control to the overall width of the button. This ensures that the button's layout accounts for the additional space required by the gamepad shortcut.
---
--- @param self PDACommonButtonClass The button instance.
--- @param ... Any additional arguments passed to the Measure function.
--- @return number, number The measured width and height of the button.
function PDACommonButtonClass:Measure(...)
	local width, height = XTextButton.Measure(self, ...)
	
	if GetUIStyleGamepad() then
		local gamepadShortcut = self.shortcut_gamepad
		if gamepadShortcut then
			width = width + gamepadShortcut.measure_width / 2.5
		end
	end
	
	return width, height
end

---
--- Positions the gamepad shortcut control relative to the button's layout.
---
--- If the UI style is gamepad, this function adjusts the position and margins of the button to accommodate the gamepad shortcut control. The shortcut control is positioned to the left of the button, with a margin that is proportional to the shortcut control's width.
---
--- @param self PDACommonButtonClass The button instance.
function PDACommonButtonClass:OnLayoutComplete()
	local gamepadShortcut = self.shortcut_gamepad
	if gamepadShortcut then
		local width = gamepadShortcut.measure_width
		local height = gamepadShortcut.measure_height
		local marginX = width / 2.5
		
		self.shortcut_gamepad:SetBox(
			self.box:minx() - width + marginX,
			self.box:miny() + self.box:sizey() / 2 - height / 2,
			width,
			gamepadShortcut.measure_height
		)

		local marginShouldBe = 0
		if GetUIStyleGamepad() then
			marginShouldBe = MulDivRound(marginX, 1000, self.scale:x())
		end
		
		if self.applied_gamepad_margin ~= marginShouldBe then
			local margin = self.Margins
			self:SetMargins(box(
				margin:minx() - (self.applied_gamepad_margin or 0) + marginShouldBe,
				margin:miny(),
				margin:maxx(),
				margin:maxy()
			))
			self.applied_gamepad_margin = marginShouldBe
		end
	end
end

---
--- Sets the enabled state of the button and its child controls.
---
--- When the button is disabled, the label text is dimmed, the container transparency is increased, and any associated shortcuts are also disabled.
---
--- @param self PDACommonButtonClass The button instance.
--- @param enabled boolean Whether the button should be enabled or disabled.
---
function PDACommonButtonClass:SetEnabled(enabled)
	XTextButton.SetEnabled(self, enabled)
	self.idLabel:SetEnabled(enabled)
	if self.idContainer then
		self.idContainer:SetTransparency(enabled and 0 or 102)
	end
	if self.shortcut then
		self.shortcut:SetEnabled(enabled)
	end
	if self.shortcut_gamepad then
		for _, ctrl in ipairs(self.shortcut_gamepad) do
			ctrl:SetEnabled(enabled)
		end
	end
end

-- The link button looks like a generic web URL. The interesting thing here is that
-- the size of the text grows when it is hovered. To prevent it from moving around
-- there are two seperate texts, with the smaller one centered on the larger.
DefineClass.PDALinkButtonClass = {
	__parents = { "XSelectableTextButton" },
	properties = {
		{ category = "Visual", id = "ActiveTextStyle", name = "Active TextStyle", editor = "text", default = "WebLinkButton_Heavy" },
	},
}

---
--- Sets the active text style for the link button's rollover label.
---
--- @param self PDALinkButtonClass The link button instance.
--- @param value string The new text style to use for the rollover label.
---
function PDALinkButtonClass:SetActiveTextStyle(value)
	self:ResolveId("idLabelRollover"):SetTextStyle(value)
	self.ActiveTextStyle = value
end

---
--- Sets whether the button should use an XText or XLabel control for the label.
---
--- @param self PDALinkButtonClass The link button instance.
--- @param value boolean Whether to use an XText or XLabel control.
--- @param context table The context to use when creating the new control.
---
function PDALinkButtonClass:SetUseXTextControl(value, context)
	local class = value and "XText" or "XLabel"
	local label = rawget(self, "idLabel")
	if label then
		context = label.context
		label:delete()
	end
	label = g_Classes[class]:new({
		Id = "idLabel",
		VAlign = "center",
		HAlign = "center",
		Translate = self.Translate,
		Clip = false,
		UseClipBox = false,
		UnderlineOffset = 3
	}, self, context)
	label:SetFontProps(self)
	self.UseXTextControl = value
end

---
--- Initializes a new PDALinkButtonClass instance.
---
--- @param self PDALinkButtonClass The link button instance.
--- @param parent table The parent object of the link button.
--- @param context table The context to use when creating the link button.
---
function PDALinkButtonClass:Init(parent, context)
	XText:new({
		Id = "idLabelRollover",
		HAlign = "center",
		VAlign = "center",
		Translate = true,
		TextStyle = "WebLinkButton_Heavy",
		Visible = false,
		Clip = false,
		UseClipBox = false,
		UnderlineOffset = 3
	}, self, context)
end

---
--- Sets the text of the link button.
---
--- @param self PDALinkButtonClass The link button instance.
--- @param text string The text to set on the link button.
---
function PDALinkButtonClass:SetText(text)
	self.Text = text
	local label = self:ResolveId("idLabel")
	local labelRollover = self:ResolveId("idLabelRollover")

	if labelRollover and self.selected then
		labelRollover:SetText(text)
		return
	end

	local t = T(645668111730, "<underline>") .. text .. T(539474781052, "</underline>")
	label:SetText(t)
	if labelRollover then labelRollover:SetText(t) end
end

---
--- Sets the selected state of the link button.
---
--- @param self PDALinkButtonClass The link button instance.
---
function PDALinkButtonClass:SetSelectedState()
	local label = self:ResolveId("idLabel")
	local labelRollover = self:ResolveId("idLabelRollover")
	if labelRollover then labelRollover:SetVisible(true) labelRollover:SetRollover(false) end
	label:SetVisible(false)
	self:SetText(self.Text)
end

---
--- Sets the rollover state of the link button.
---
--- @param self PDALinkButtonClass The link button instance.
---
function PDALinkButtonClass:SetRolloverState()
	local label = self:ResolveId("idLabel")
	local labelRollover = self:ResolveId("idLabelRollover")
	if labelRollover then labelRollover:SetVisible(true) labelRollover:SetRollover(true) end
	label:SetVisible(false)
end

---
--- Sets the disabled state of the link button.
---
--- @param self PDALinkButtonClass The link button instance.
---
function PDALinkButtonClass:SetDisabledState()
	local label = self:ResolveId("idLabel")
	local labelRollover = self:ResolveId("idLabelRollover")
	if labelRollover then labelRollover:SetVisible(false) labelRollover:SetRollover(false) end
	label:SetVisible(true)
end

---
--- Sets the default state of the link button.
---
--- @param self PDALinkButtonClass The link button instance.
---
function PDALinkButtonClass:SetDefaultState()
	local label = self:ResolveId("idLabel")
	local labelRollover = self:ResolveId("idLabelRollover")
	if labelRollover then labelRollover:SetVisible(false) labelRollover:SetRollover(false) end
	label:SetVisible(true)
end

DefineClass.PDASatelliteClass = {
	__parents = { "PDAClass" }
}

---
--- Opens the PDA satellite view.
---
--- This function pauses the "pda" game state, opens the PDA class, and sends a "OpenPDA" message.
---
--- @param self PDASatelliteClass The PDASatelliteClass instance.
---
function PDASatelliteClass:Open()
	Pause("pda", "keepSounds")
	PDAClass.Open(self)
	Msg("OpenPDA")
end

---
--- Closes the PDA satellite view and resumes the "pda" game state.
---
--- This function sends a "ClosePDA" message and resumes the "pda" game state.
---
--- @param self PDASatelliteClass The PDASatelliteClass instance.
---
function PDASatelliteClass:Done()
	Msg("ClosePDA")
	Resume("pda")
end

---
--- Closes the PDA satellite view and performs necessary synchronization tasks.
---
--- This function checks if the PDA can be closed, and if so, it synchronizes unit properties, checks unit map presence, and synchronizes item containers. It then closes the PDA dialog and sets the rendering mode to "scene". If the PDA is being forcefully closed, it skips the synchronization tasks and immediately closes the dialog.
---
--- @param self PDASatelliteClass The PDASatelliteClass instance.
--- @param force boolean If true, the PDA is closed immediately without performing synchronization tasks.
--- @return boolean Whether the PDA was successfully closed.
---
function PDASatelliteClass:Close(force)
	if not force and not self:CanCloseCheck("close") then -- Unused in satellite
		return false
	end
	
	local starting_net_game = netInGame and not netGameInfo.started
	if not starting_net_game and not GameState.entering_sector then
		SyncUnitProperties("session")
		NetSyncEvents.CheckUnitsMapPresence()
		NetSyncEvents.SyncItemContainers()
		
		-- This should be sync via CloseSatelliteView
		-- NetSyncEvent("SyncUnitProperties", "session")
		-- NetSyncEvent("CheckUnitsMapPresence")
		-- NetSyncEvent("SyncItemContainers")
		assert(not IsAsyncCode())
	end
	
	XDialog.Close(self)
	if force then
		--XDialog.Close(self)
	elseif not self.closing then
		self.closing = true
		SetRenderMode("scene")
		self:DeleteThread("loading_bar")
		self:StartPDALoading(nil, T(663409032614, "CLOSING"))
	end
end

DefineClass.PDAClass = {
	__parents = { "XDialog" },
	ZOrder = 2,

	mouse_cursor = false,
}

---
--- Opens the PDA dialog and performs necessary synchronization tasks.
---
--- This function checks if the PDA is being opened from the satellite view. If so, it synchronizes unit properties. If the PDA is being opened from elsewhere, it triggers a network event to synchronize unit properties.
---
--- The function then sets the initial mode of the PDA based on the context, and opens the PDA dialog.
---
--- @param self PDAClass The PDAClass instance.
---
function PDAClass:Open()
	-- If satellite is open it has already synced unit->unit_data
	if not gv_SatelliteView then
		if IsKindOf(self, "PDASatelliteClass") then -- Opening this is sync
			SyncUnitProperties("map")
			assert(not IsAsyncCode())
		else
			NetSyncEvent("SyncUnitProperties", "map")
		end
	end
	
	if self.context and self.context.Mode then
		self.InitialMode = self.context.Mode
	end
	XDialog.Open(self)
	ObjModified("pda_url")
end

---
--- Checks if the PDA dialog can be closed.
---
--- This function checks if the current tab content in the PDA dialog has a `CanClose` member function. If it does, it calls that function and returns its result. Otherwise, it returns `true`, indicating that the PDA dialog can be closed.
---
--- @param self PDAClass The PDAClass instance.
--- @param nextMode string The next mode to transition to.
--- @param mode_params table Optional parameters for the next mode.
--- @return boolean True if the PDA dialog can be closed, false otherwise.
---
function PDAClass:CanCloseCheck(nextMode, mode_params)
	local tabContent = self:ResolveId("idContent")
	if tabContent and tabContent:HasMember("CanClose") then
		if not tabContent:CanClose(nextMode, mode_params) then return end
	end
	
	return true
end

---
--- Closes the PDA dialog, checking if it can be closed first.
---
--- This function first checks if the current tab content in the PDA dialog has a `CanClose` member function. If it does, it calls that function and checks if the PDA dialog can be closed. If the `CanClose` function returns `false`, the function returns without closing the dialog.
---
--- If the `CanClose` function returns `true` or if the `CanClose` function does not exist, the function proceeds to close the PDA dialog using the `XDialog.Close` function.
---
--- @param self PDAClass The PDAClass instance.
--- @param force boolean (optional) If `true`, the PDA dialog will be closed regardless of the result of the `CanClose` check.
---
function PDAClass:Close(force)
	if not force and not self:CanCloseCheck("close") then
		return
	end
	XDialog.Close(self)
end

---
--- Handles the event when the player closes the first merc selection.
---
--- This function is called when the player closes the first merc selection. It checks if the PDA dialog is open and not in the process of closing or being destroyed. If the PDA dialog is open, it calls the `PDAClass:Close()` function to close the dialog. It also sets the `gv_AIMBrowserEverClosed` global variable to `true`.
---
--- @param none
--- @return none
---
function NetSyncEvents.AnyPlayerClosedFirstMercSelection()
	local pda = GetDialog("PDADialog")
	if pda and pda.window_state ~= "destroying" and pda.window_state ~= "closing" then
		pda:Close()
	end
	gv_AIMBrowserEverClosed = true
end

---
--- Handles the closing action of the PDA dialog.
---
--- This function is responsible for handling the closing action of the PDA dialog. It checks various conditions to determine the appropriate action to take:
---
--- 1. If the initial conflict has not started and the player has no squads, it creates a thread to display a popup asking the player to hire at least one merc. If the player chooses to go back to the main menu, the function will load the main menu.
---
--- 2. If the initial conflict has not started and the player has not closed the AIM browser before, it checks if the player has less than 3 mercs in their squads. If so, it displays a warning popup asking the player if they want to proceed with a smaller team. If the player confirms, the function will close the PDA dialog and trigger the "AnyPlayerClosedFirstMercSelection" event.
---
--- 3. If none of the above conditions are met, the function simply closes the PDA dialog.
---
--- @param self PDAClass The PDAClass instance.
--- @param host table The host object for the PDA dialog.
---
function PDAClass:CloseAction(host)
	if InitialConflictNotStarted() and not AnyPlayerSquads() then
		host:CreateThread("no-mercs-hired", function()
			local popupHost = self:ResolveId("idDisplayPopupHost")
			if not popupHost then return end

			local resp = WaitQuestion(
				popupHost,
				T(547757159419, "Hire some mercs"),
				T(947959749616, "You have to hire at least one merc to continue. It is recommended to start with an initial team of at least <em>three mercs</em>."),
				T(146978930234, "Main Menu"),
				T(413525748743, "Ok"))
			if resp == "ok" then -- which is actually 'main menu' while 'ok' is actually cancel
				resp = WaitQuestion(
					popupHost,
					T(118482924523, "Are you sure?"),
					T(705675457888, "Are you sure you want to go back to the main menu? All game progress will be lost."),
					T(1138, "Yes"),
					T(1139, "No"))
				if resp == "ok" then
					CreateRealTimeThread(function()
						LoadingScreenOpen("idLoadingScreen", "main menu")
						host:Close()
						OpenPreGameMainMenu("")
						LoadingScreenClose("idLoadingScreen", "main menu")
					end)
				end
			end
		end)
	elseif InitialConflictNotStarted() and not gv_AIMBrowserEverClosed then
		host:CreateThread("check-merc-count",
			function()
				if CountPlayerMercsInSquads("AIM", "include_imp") < 3 then
					local popupHost = self:ResolveId("idDisplayPopupHost")
					if not popupHost then return true end
					
					if GetAccountStorageOptionValue("HintsEnabled") then
						local tooLittleMercWarning = CreateQuestionBox(
							popupHost,
							T(290674714505, "Hint"),
							T(374167370987, "It is recommended to start with an initial team of at least <em>three mercs</em>. Are you sure you want to proceed with a smaller team?"),
							T(689884995409, "Yes"), 
							T(782927325160, "No"))
						local resp = tooLittleMercWarning:Wait()
						if resp ~= "ok" then		
							return
						end
					end
				end
				
				-- Temp override, new design is going to satellite view instead of enter sector
				if true then
					self:Close()
					NetSyncEvent("AnyPlayerClosedFirstMercSelection")
					return
				end
			
				local playerSquads = GetPlayerMercSquads()
				if not playerSquads or #playerSquads == 0 then return end
				local firstSquad = playerSquads[1] -- Easier than looking for starting sector
				local startingSector = firstSquad.CurrentSector
				assert(startingSector)
				assert(CanGoInMap(startingSector))
				UIEnterSector(startingSector, true)
			end
		)
	else
		self:Close()
	end
end

function OnMsg.PreLoadSessionData()
	CloseDialog("PDADialog")
end

DefineClass.PDAMoneyText = {
	__parents = { "XText", "XDrawCache" },
	
	money_amount = false
}

--- Opens the PDAMoneyText UI element and sets its money amount to the current game money.
function PDAMoneyText:Open()
	self:SetMoneyAmount(Game.Money)
	XText.Open(self)
end

---
--- Sets the money amount displayed in the PDAMoneyText UI element.
---
--- @param amount number The new money amount to display.
function PDAMoneyText:SetMoneyAmount(amount)
	self:SetText(T{868875791784, "<balanceDisplay(Money)>", Money = amount})
	self.money_amount = amount
end

---
--- Animates the change in the money display on the PDA UI.
---
--- @param amount number The amount of money to animate.
function PDAClass:AnimateMoneyChange(amount)
	local moneyDisplay = self.idMoney
	if not moneyDisplay or moneyDisplay.window_state == "destroying" then return end
	
	if moneyDisplay:GetThread("money_animation") then
		moneyDisplay:DeleteThread("money_animation")
	end

	moneyDisplay:CreateThread("money_animation", function()
		local color = amount > 0 and RGB(30, 255, 10) or RGB(255, 0, 0)
		local center = moneyDisplay.box:Center()
		if not moneyDisplay:FindModifier("make-big") then
			moneyDisplay:AddInterpolation{
				type = const.intRect,
				duration = 100,
				originalRect = sizebox(center, 100, 100),
				targetRect = sizebox(center, 120, 120),
				id = "make-big"
			}
		end
		moneyDisplay:AddInterpolation{
			type = const.intColor,
			duration = 200,
			startValue = RGB(255, 255, 255),
			endValue = color,
			id = "change-color"
		}
		
		local startingMoney = moneyDisplay.money_amount
		local targetMoney = Game.Money
		local timeToInterpolate = 150
		local timeStep = 10
		for t = 0, timeToInterpolate do
			local animatedAmount = Lerp(startingMoney, targetMoney, t, timeToInterpolate)
			moneyDisplay:SetMoneyAmount(animatedAmount)
			Sleep(timeStep)
		end
		moneyDisplay:SetMoneyAmount(targetMoney)

		moneyDisplay:RemoveModifier("make-big")
		moneyDisplay:RemoveModifier("change-color")
	end)
end

local modes_with_combat_log = {
	"satellite"
}

---
--- Sets the mode of the PDA UI.
---
--- @param mode string The mode to set the PDA to.
--- @param mode_param any Optional parameter for the mode.
--- @param skipCanCloseCheck boolean Optional flag to skip the can close check.
---
function PDAClass:SetMode(mode, mode_param, skipCanCloseCheck)
	if mode == self.Mode then return end

	if not skipCanCloseCheck and not self:CanCloseCheck(mode, mode_param) then
		return
	end

	self.idDisplayPopupHost:DeleteChildren()
	
	local initialMode = #(self.Mode or "") == 0
	self:StartPDALoading()
	XDialog.SetMode(self, mode, mode_param)
	
	-- Hide combat log if opening a tab where it shouldn't be visible, while it's open.
	local show_combat_log = not not table.find(modes_with_combat_log, mode)
	local combat_log = GetDialog("CombatLog")
	if not show_combat_log and combat_log then
		combat_log:AnimatedClose(true, true)
	end
	
	Msg("PDATabOpened", mode)

	-- Otherwise the respawn will cause a double open.
	if not initialMode then
		ObjModified("pda_tab")
	end
	
	ObjModified("PDAButtons")
end

-- Window that is always square, used for the level display in PDAMercItem
DefineClass.XSquareWindow = {
	__parents = { "XWindow" }
}

---
--- Sets the box of the square window to the given dimensions, ensuring the window remains square.
---
--- @param x number The x-coordinate of the window.
--- @param y number The y-coordinate of the window.
--- @param width number The width of the window.
--- @param height number The height of the window.
---
function XSquareWindow:SetBox(x, y, width, height)
	local biggerSide = Max(width, height)
	if biggerSide == width then
		--y = y - (biggerSide - height)
	elseif biggerSide == height then
		x = x - (biggerSide - width)
	end
	XWindow.SetBox(self, x, y, biggerSide, biggerSide)
end

DefineClass.MessengerScrollbar = {
	__parents = { "XScrollThumb" },
	properties = {
		{ id = "UnscaledWidth", editor = "number", name = "Scrollbar Width", default = 20 },
	},
	Background = RGB(86, 86, 86),
	FullPageAtEnd = true,
	FixedSizeThumb = false,
	MinThumbSize = 32,
	ChildrenHandleMouse = true
}

---
--- Initializes the MessengerScrollbar object.
---
--- This function creates a new XFrame object with the ID "idThumb" and sets the Dock property to "ignore". It also sets the Horizontal property of the XSleekScroll object.
---
--- @param self MessengerScrollbar The MessengerScrollbar object being initialized.
---
function MessengerScrollbar:Init()
	XFrame:new({
		Id = "idThumb",
		Dock = "ignore"
	}, self)
	XSleekScroll.SetHorizontal(self, self.Horizontal)
end

---
--- Opens the MessengerScrollbar and sets up the scrollbar thumb and arrow buttons.
---
--- This function sets the minimum and maximum width of the scrollbar to the `UnscaledWidth` property. It then calls the `XScrollThumb.Open()` function to open the scrollbar.
---
--- Next, it sets the image and frame box of the scrollbar thumb. It then creates two arrow buttons, one for scrolling up and one for scrolling down, and attaches them to the scrollbar. The arrow buttons are positioned at the top and bottom of the scrollbar, respectively, and their `OnPress` functions call the `ScrollUp()` and `ScrollDown()` functions on the target object.
---
--- @param self MessengerScrollbar The MessengerScrollbar object being opened.
---
function MessengerScrollbar:Open()
	self.MinWidth = self.UnscaledWidth
	self.MaxWidth = self.UnscaledWidth
	XScrollThumb.Open(self)
	
	local thumb = self.idThumb
	thumb:SetImage("UI/PDA/os_scrollbar")
	thumb:SetFrameBox(box(3,3,3,3))

	local topArr = XTemplateSpawn("PDASmallButton", self)
	topArr:SetCenterImage("UI/PDA/T_PDA_ScrollArrow")
	topArr.idCenterImg:SetHAlign("stretch")
	topArr.idCenterImg:SetVAlign("stretch")
	topArr.idCenterImg:SetMargins(box(3, 3, 3, 3))
	topArr.idCenterImg:SetImageFit("width")
	topArr:SetDock("ignore")
	topArr:SetId("idTopArrow")
	topArr.OnPress = function(o)
		local target = self:ResolveId(self.Target)
		if not target then return end
		target:ScrollUp()
	end
	topArr:Open()

	local bottomArr = XTemplateSpawn("PDASmallButton", self)
	bottomArr:SetCenterImage("UI/PDA/T_PDA_ScrollArrow")
	bottomArr.idCenterImg:SetFlipY(true)
	bottomArr.idCenterImg:SetHAlign("stretch")
	bottomArr.idCenterImg:SetVAlign("stretch")
	bottomArr.idCenterImg:SetMargins(box(3, 3, 3, 3))
	bottomArr.idCenterImg:SetImageFit("width")
	bottomArr:SetDock("ignore")
	bottomArr:SetId("idBottomArrow")
	bottomArr.OnPress = function(o)
		local target = self:ResolveId(self.Target)
		if not target then return end
		target:ScrollDown()
	end
	bottomArr:Open()
end

---
--- Handles the rollover state of the MessengerScrollbar.
---
--- This function is called when the rollover state of the MessengerScrollbar changes. It currently does nothing, as the rollover state is not used in the implementation of the MessengerScrollbar.
---
--- @param self MessengerScrollbar The MessengerScrollbar object.
--- @param rollover boolean Whether the MessengerScrollbar is in a rollover state or not.
---
function MessengerScrollbar:OnSetRollover(rollover)
	-- nop
end

---
--- Called when the MessengerScrollbar loses mouse capture.
---
--- This function is called when the MessengerScrollbar loses mouse capture. It calls the `OnCaptureLost` function of the `XScrollThumb` class, and then sets the rollover state of the MessengerScrollbar based on whether the mouse is still within the window.
---
--- @param self MessengerScrollbar The MessengerScrollbar object.
---
function MessengerScrollbar:OnCaptureLost()
	XScrollThumb.OnCaptureLost(self)
	self:OnSetRollover(self:MouseInWindow(terminal.GetMousePos()))
end

---
--- Measures the size of the MessengerScrollbar.
---
--- This function is called to measure the size of the MessengerScrollbar. It simply delegates the measurement to the `XScrollThumb.Measure` function.
---
--- @param self MessengerScrollbar The MessengerScrollbar object.
--- @param max_w number The maximum width available for the MessengerScrollbar.
--- @param max_h number The maximum height available for the MessengerScrollbar.
--- @return number, number The measured width and height of the MessengerScrollbar.
---
function MessengerScrollbar:Measure(max_w, max_h)
	return XScrollThumb.Measure(self, max_w, max_h)
end

---
--- Sets the box dimensions of the MessengerScrollbar and updates the positions of the top and bottom arrows.
---
--- @param self MessengerScrollbar The MessengerScrollbar object.
--- @param x number The x-coordinate of the box.
--- @param y number The y-coordinate of the box.
--- @param width number The width of the box.
--- @param height number The height of the box.
---
function MessengerScrollbar:SetBox(x, y, width, height)
	XSleekScroll.SetBox(self, x, y, width, height)
	if not self.idTopArrow or not self.idBottomArrow then return end

	local iw, ih = ScaleXY(self.scale, self.UnscaledWidth, self.UnscaledWidth)
	self.idTopArrow:SetBox(x, y, iw, ih)
	self.idBottomArrow:SetBox(x, y + height - ih, iw, ih)

	self.content_box = sizebox(x, y + ih, width, height - ih * 2)
end

---
--- Draws the background of the MessengerScrollbar.
---
--- This function is responsible for drawing the background of the MessengerScrollbar. It uses the `UIL.DrawSolidRect` function to draw a solid rectangle with the color specified by the `Background` property of the MessengerScrollbar.
---
--- @param self MessengerScrollbar The MessengerScrollbar object.
---
function MessengerScrollbar:DrawBackground()
	UIL.DrawSolidRect(self.content_box, self.Background)
end

---
--- Draws the window and its children.
---
--- This function is responsible for drawing the MessengerScrollbar window and its child elements. It first calls the `XWindow.DrawWindow` function to draw the window itself, and then calls the `XWindow.DrawChildren` function to draw the child elements. This ensures that the children are drawn on top of the window background.
---
--- @param self MessengerScrollbar The MessengerScrollbar object.
--- @param clip_box table The clipping box to use when drawing the window and its children.
---
function MessengerScrollbar:DrawWindow(clip_box)
	-- Prevent the children from being drawn with the tint modifier, and then draw them separately
	XWindow.DrawWindow(self, clip_box)
	XWindow.DrawChildren(self, clip_box)
end

DefineClass.MessengerScrollbar_Gold = {
	__parents = { "MessengerScrollbar" },
	Background = RGB(255,255,255),
}

---
--- Opens the MessengerScrollbar_Gold object and sets up its visual elements.
---
--- This function is responsible for initializing the visual elements of the MessengerScrollbar_Gold object, including the scrollbar thumb and the top and bottom arrow buttons. It sets the size and appearance of these elements, and also sets up the event handlers for the arrow buttons to handle scrolling.
---
--- @param self MessengerScrollbar_Gold The MessengerScrollbar_Gold object to be opened.
---
function MessengerScrollbar_Gold:Open()
	self.MinWidth = self.UnscaledWidth
	self.MaxWidth = self.UnscaledWidth
	XScrollThumb.Open(self)
	
	local thumb = self.idThumb
	thumb:SetImage("UI/PDA/WEBSites/Bobby Rays/scrollbar")
	thumb:SetFrameBox(box(3,3,3,3))
	thumb:SetMargins(box(2,0,2,0))

	local topArr = XTemplateSpawn("PDASmallButton", self)
	topArr:SetCenterImage("UI/PDA/WEBSites/Bobby Rays/scrollbar_up")
	topArr.idCenterImg:SetHAlign("stretch")
	topArr.idCenterImg:SetVAlign("stretch")
	topArr.idCenterImg:SetImageColor(RGB(255,255,255))
	topArr.idCenterImg:SetImageFit("stretch")
	topArr:SetDock("ignore")
	topArr:SetId("idTopArrow")
	topArr.OnPress = function(o)
		local target = self:ResolveId(self.Target)
		if not target then return end
		target:ScrollUp()
	end
	topArr:Open()

	local bottomArr = XTemplateSpawn("PDASmallButton", self)
	bottomArr:SetCenterImage("UI/PDA/WEBSites/Bobby Rays/scrollbar_down")
	bottomArr.idCenterImg:SetHAlign("stretch")
	bottomArr.idCenterImg:SetVAlign("stretch")
	bottomArr.idCenterImg:SetImageColor(RGB(255,255,255))
	bottomArr.idCenterImg:SetImageFit("stretch")
	bottomArr:SetDock("ignore")
	bottomArr:SetId("idBottomArrow")
	bottomArr.OnPress = function(o)
		local target = self:ResolveId(self.Target)
		if not target then return end
		target:ScrollDown()
	end
	bottomArr:Open()
end

DefineClass.MessengerScrollbarHorizontal = {
	__parents = { "XScrollThumb" },
	properties = {
		{ id = "UnscaledWidth", editor = "number", name = "Scrollbar Width", default = 20 },
	},
	Horizontal = true,
	Background = RGB(86, 86, 86),
	FullPageAtEnd = true,
	FixedSizeThumb = false,
	MinThumbSize = 32,
	ChildrenHandleMouse = true
}

--- Initializes the MessengerScrollbarHorizontal object.
-- This function sets up the necessary components for the horizontal scrollbar, including creating the thumb frame and setting the scrollbar to be horizontal.
-- @function MessengerScrollbarHorizontal:Init
-- @return nil
function MessengerScrollbarHorizontal:Init()
	XFrame:new({
		Id = "idThumb",
		Dock = "ignore",
		Horizontal = self.Horizontal
	}, self)
	XSleekScroll.SetHorizontal(self, self.Horizontal)
end

--- Opens the MessengerScrollbarHorizontal object, setting up the necessary components for the horizontal scrollbar.
-- This function creates the thumb frame, sets the scrollbar to be horizontal, and spawns the top and bottom arrow buttons.
-- @function MessengerScrollbarHorizontal:Open
-- @return nil
function MessengerScrollbarHorizontal:Open()
	self.MinHeight = self.UnscaledWidth
	self.MaxHeight = self.UnscaledWidth
	XScrollThumb.Open(self)
	
	local thumb = self.idThumb
	thumb:SetImage("UI/PDA/os_scrollbar")
	thumb:SetFrameBox(box(3,3,3,3))

	local topArr = XTemplateSpawn("PDASmallButton", self)
	topArr:SetCenterImage("UI/PDA/T_PDA_ScrollArrow")
	topArr.idCenterImg:SetHAlign("stretch")
	topArr.idCenterImg:SetVAlign("stretch")
	topArr.idCenterImg:SetMargins(box(3, 3, 3, 3))
	topArr.idCenterImg:SetAngle(-90 * 60)
	topArr.idCenterImg:SetImageFit("width")
	topArr:SetDock("ignore")
	topArr:SetId("idTopArrow")
	topArr.OnPress = function(o)
		local target = self:ResolveId(self.Target)
		if not target then return end
		target:ScrollLeft()
	end
	topArr:Open()

	local bottomArr = XTemplateSpawn("PDASmallButton", self)
	bottomArr:SetCenterImage("UI/PDA/T_PDA_ScrollArrow")
	bottomArr.idCenterImg:SetFlipY(true)
	bottomArr.idCenterImg:SetHAlign("stretch")
	bottomArr.idCenterImg:SetVAlign("stretch")
	bottomArr.idCenterImg:SetMargins(box(3, 3, 3, 3))
	bottomArr.idCenterImg:SetAngle(-90 * 60)
	bottomArr.idCenterImg:SetImageFit("width")
	bottomArr:SetDock("ignore")
	bottomArr:SetId("idBottomArrow")
	bottomArr.OnPress = function(o)
		local target = self:ResolveId(self.Target)
		if not target then return end
		target:ScrollRight()
	end
	bottomArr:Open()
end

--- Handles the rollover state of the MessengerScrollbarHorizontal object.
-- This function is called when the rollover state of the scrollbar changes. However, it currently does nothing.
-- @function MessengerScrollbarHorizontal:OnSetRollover
-- @param rollover boolean Whether the scrollbar is in a rollover state or not.
-- @return nil
function MessengerScrollbarHorizontal:OnSetRollover(rollover)
	-- nop
end

--- Handles the loss of capture for the MessengerScrollbarHorizontal object.
-- This function is called when the scrollbar loses its capture, such as when the user releases the mouse button. It restores the rollover state of the scrollbar based on the current mouse position.
-- @function MessengerScrollbarHorizontal:OnCaptureLost
-- @return nil
function MessengerScrollbarHorizontal:OnCaptureLost()
	XScrollThumb.OnCaptureLost(self)
	self:OnSetRollover(self:MouseInWindow(terminal.GetMousePos()))
end

--- Measures the size of the MessengerScrollbarHorizontal object.
-- This function is called to determine the size of the scrollbar. It delegates the measurement to the parent XScrollThumb class.
-- @function MessengerScrollbarHorizontal:Measure
-- @param max_w number The maximum width available for the scrollbar.
-- @param max_h number The maximum height available for the scrollbar.
-- @return number, number The measured width and height of the scrollbar.
function MessengerScrollbarHorizontal:Measure(max_w, max_h)
	return XScrollThumb.Measure(self, max_w, max_h)
end

--- Sets the bounding box of the MessengerScrollbarHorizontal object.
-- This function is responsible for setting the position and size of the scrollbar, as well as the position of the top and bottom arrow buttons.
-- @function MessengerScrollbarHorizontal:SetBox
-- @param x number The x-coordinate of the scrollbar's bounding box.
-- @param y number The y-coordinate of the scrollbar's bounding box.
-- @param width number The width of the scrollbar's bounding box.
-- @param height number The height of the scrollbar's bounding box.
-- @return nil
function MessengerScrollbarHorizontal:SetBox(x, y, width, height)
	XSleekScroll.SetBox(self, x, y, width, height)
	if not self.idTopArrow or not self.idBottomArrow then return end

	local iw, ih = ScaleXY(self.scale, self.UnscaledWidth, self.UnscaledWidth)
	self.idTopArrow:SetBox(x, y, iw, ih)
	self.idBottomArrow:SetBox(x + width - iw, y, iw, ih)

	self.content_box = sizebox(x + iw, y, width - iw * 2, height)
end

-- This scroll area aggressively makes sure you only scroll in increments of the step size
-- in order to provide the best "!ShowPartialItems" experience

DefineClass.SnappingScrollBar = {
	__parents = { "XScrollThumb" },
	SnapToItems = true,
	FullPageAtEnd = false
}

---
--- Calculates the size of the thumb for the SnappingScrollBar.
--- The thumb size is calculated based on the size of the content area and the page size.
---
--- @param self SnappingScrollBar The SnappingScrollBar instance.
--- @return number The calculated size of the thumb.
function SnappingScrollBar:GetThumbSize()
	local area = self.Horizontal and self.content_box:sizex() or self.content_box:sizey()
	local page_size = MulDivRound(area, self.PageSize, Max(1, self.Max - self.Min))
	return Clamp(page_size, self.MinThumbSize, area)
end

local function lMapToRange(value, leftMin, leftMax, rightMin, rightMax)
	if leftMax - leftMin == 0 then
		return rightMin
	end
	return rightMin + (value - leftMin) * (rightMax - rightMin) / (leftMax - leftMin)
end

---
--- Calculates the range of the thumb for the SnappingScrollBar.
--- The thumb range is calculated based on the size of the content area and the current scroll position.
---
--- @param self SnappingScrollBar The SnappingScrollBar instance.
--- @return number, number The start and end positions of the thumb.
function SnappingScrollBar:GetThumbRange()
	local thumb_size = self:GetThumbSize()
	local area = (self.Horizontal and self.content_box:sizex() or self.content_box:sizey()) - thumb_size
	local pos = lMapToRange(self.Scroll, self.Min, self.Max - self.PageSize, 0, area)
	return pos, pos + thumb_size
end

---
--- Sets the scroll position of the SnappingScrollBar.
---
--- @param self SnappingScrollBar The SnappingScrollBar instance.
--- @param current number The new scroll position.
--- @return boolean Whether the scroll position was changed.
function SnappingScrollBar:SetScroll(current)
	self.FullPageAtEnd = true
	local changed = XScroll.SetScroll(self, current)
	self:MoveThumb()
	return changed
end

DefineClass.SnappingScrollArea = {
	__parents = { "XScrollArea", "XContentTemplateList" },
	properties = {
		{ category = "General", id = "RightThumbScroll", editor = "bool", default = false, help = "Vertical scroll with RThumb" },
	},
	Background = RGBA(0, 0, 0, 0),
	BorderColor = RGBA(0, 0, 0, 0),
	FocusedBackground = RGBA(0, 0, 0, 0),
	FocusedBorderColor = RGBA(0, 0, 0, 0),
	ShowPartialItems = false,
	MouseScroll = true,
	GamepadInitialSelection = false,
	base_scroll_range_y = false
}

---
--- Updates the calculations for the SnappingScrollArea.
--- This function is responsible for updating the item grid layout, the scroll range, and the scroll bar properties.
---
--- @param self SnappingScrollArea The SnappingScrollArea instance.
function SnappingScrollArea:UpdateCalculations()
	if not self.base_scroll_range_y then return end -- Not measured yet.

	if self.LayoutMethod == "HWrap" then
		self.item_hashes = {}
		local currentY, currentYValue = 0, false
		local currentX = 1
		for i, window in ipairs(self) do
			local windowY = window.box:miny()
			if windowY ~= currentYValue then
				currentX = 1
				currentY = currentY + 1
				currentYValue = windowY
			end
			
			window.GridX = currentX
			window.GridY = currentY
			self.item_hashes[currentX .. currentY] = i
			
			currentX = currentX + 1
		end
	else
		self:GenerateItemHashTable()
	end

	local newStep = self.MouseWheelStep
	local b = self.content_box
	local pageHeight = (b:sizey() / newStep) * newStep
	local roundErrorLeftOver = b:sizey() - pageHeight -- Round out to even steps.
	local totalSteps = DivCeil(self.base_scroll_range_y - roundErrorLeftOver, newStep) * newStep
	self.scroll_range_y = totalSteps

	-- Update the scroll bar
	local scroll = self:ResolveId(self.VScroll)
	scroll:SetStepSize(newStep)
	scroll:SetPageSize(pageHeight)
	
	scroll:SetScrollRange(0, Max(0, totalSteps))
end

---
--- Completes the layout of the SnappingScrollArea and updates the scroll bar properties.
---
--- This function is called after the layout of the SnappingScrollArea is complete. It ensures that the scroll bar is properly configured to work with the SnappingScrollArea, including setting the thumb size, thumb range, and scroll snapping behavior.
---
--- If the SnappingScrollArea is empty, this function simply returns. Otherwise, it calculates a new mouse wheel step size based on the size of the first item and the layout spacing, and then updates the calculations for the SnappingScrollArea.
---
--- @param self SnappingScrollArea The SnappingScrollArea instance.
function SnappingScrollArea:OnLayoutComplete()
	local scroll = self:ResolveId(self.VScroll)
	if not IsKindOf(scroll, "SnappingScrollBar") then
		scroll.GetThumbSize = SnappingScrollBar.GetThumbSize
		scroll.GetThumbRange = SnappingScrollBar.GetThumbRange
		scroll.SetScroll = SnappingScrollBar.SetScroll
		scroll.SnapToItems = true
		scroll.FullPageAtEnd = false
	end

	if #self == 0 then return end

	local oldStep = self.MouseWheelStep
	local _, scaledSpacing = ScaleXY(self.scale, 0, self.LayoutVSpacing)
	local newStep = self[1].box:sizey() + scaledSpacing
	if newStep == 0 then return end
	self:SetMouseWheelStep(newStep)
	self:UpdateCalculations()
end

---
--- Measures the preferred size of the SnappingScrollArea.
---
--- This function is called to determine the preferred size of the SnappingScrollArea. It first calls the base class's Measure function to get the initial preferred size, then adjusts the preferred height based on the height of the first item in the SnappingScrollArea.
---
--- If the first item has a non-zero measure height, the preferred height is adjusted to be a multiple of the first item's height. This ensures that the SnappingScrollArea's content will snap to the height of the first item.
---
--- @param self SnappingScrollArea The SnappingScrollArea instance.
--- @param preferred_width number The preferred width of the SnappingScrollArea.
--- @param preferred_height number The preferred height of the SnappingScrollArea.
--- @return number, number The adjusted preferred width and height of the SnappingScrollArea.
function SnappingScrollArea:Measure(preferred_width, preferred_height)
	preferred_width, preferred_height = XScrollArea.Measure(self, preferred_width, preferred_height)
	self.base_scroll_range_y = self.scroll_range_y
	if self[1] then
		local h = self[1].measure_height
		if h ~= 0 then 
			preferred_height = (preferred_height / h) * h
		end
	end
	return preferred_width, preferred_height
end

---
--- Scrolls the SnappingScrollArea to the specified coordinates.
---
--- If the `force` parameter is true, this function will scroll the SnappingScrollArea to the specified coordinates regardless of any other constraints. Otherwise, it will call the base class's `ScrollTo` function to perform the scrolling.
---
--- @param self SnappingScrollArea The SnappingScrollArea instance.
--- @param x number The x-coordinate to scroll to.
--- @param y number The y-coordinate to scroll to.
--- @param force boolean If true, the scroll will be forced to the specified coordinates.
--- @return boolean True if the scroll was successful, false otherwise.
function SnappingScrollArea:ScrollTo(x, y, force)
	if force then return end
	return XScrollArea.ScrollTo(self, x, y)
end

local function IsItemSelectable(child)
	return (not child:HasMember("IsSelectable") or child:IsSelectable()) and child:GetVisible()
end

---
--- Finds the next selectable grid item in the specified direction.
---
--- This function is used to navigate through the items in a grid layout. It takes the current item and a direction, and returns the index of the next selectable item in that direction.
---
--- If the current item is `nil`, the function will return the index of the first selectable item in the grid, or `false` if there are no selectable items.
---
--- @param self SnappingScrollArea The SnappingScrollArea instance.
--- @param item number The index of the current item.
--- @param dir string The direction to move in ("Left", "Right", "Up", "Down").
--- @return number|boolean The index of the next selectable item, or `false` if there are no more selectable items in the specified direction.
function SnappingScrollArea:NextGridItem(item, dir)
	local item_count = self:GetItemCount()
	if not item then
		return item_count > 0 and 1 or false
	end
	
	local current = self[item]
	local x, y = current.GridX, current.GridY
	if dir == "Left" then
		x = x - 1
	elseif dir == "Right" then
		x = x + (current.GridWidth - 1) + 1
	elseif dir == "Up" then
		y = y - 1
	elseif dir == "Down" then
		y = y + (current.GridHeight - 1) + 1
	end
	if x > 0 and y > 0 then
		local i = self.item_hashes[x .. y]
		-- find the first selectable item on the desired row
		while not i and x > 1 do
			x = x - 1
			i = self.item_hashes[x .. y]
		end
		while i and i > 0 and i <= item_count and not IsItemSelectable(self[i]) do
			i = self:NextGridItem(i, self.LayoutMethod == "HWrap" and "Right" or dir)
		end
		return i and i > 0 and i <= item_count and i or false
	end
end

---
--- Handles keyboard shortcuts for the SnappingScrollArea.
---
--- If the layout method is "HWrap", this function temporarily switches to "Grid" layout to handle the shortcut, then switches back.
---
--- If the RightThumbScroll property is true and the layout method is "VList", the function remaps the "RightThumb" shortcuts to "LeftThumb" shortcuts.
---
--- @param self SnappingScrollArea The SnappingScrollArea instance.
--- @param shortcut string The keyboard shortcut.
--- @param source any The source of the shortcut.
--- @param ... any Additional arguments.
--- @return any The return value of the XContentTemplateList.OnShortcut function.
function SnappingScrollArea:OnShortcut(shortcut, source, ...)
	if self.RightThumbScroll and self.LayoutMethod == "VList" and string.starts_with(shortcut, "RightThumb")then
		shortcut = string.gsub(shortcut, "RightThumb", "LeftThumb")
	end	
	if self.LayoutMethod == "HWrap" then
		self.LayoutMethod = "Grid"
		local returnVal = XContentTemplateList.OnShortcut(self, shortcut, source, ...)
		self.LayoutMethod = "HWrap"
		return returnVal
	end
	return XContentTemplateList.OnShortcut(self, shortcut, source, ...)
end

-- Check template for more info
DefineClass.PDASectionHeaderClass = {
	__parents = { "XWindow" },
	properties = {
		{ id = "text", editor = "text", name = "Text", default = false, translate = true },
	},
}

---
--- Opens the PDASectionHeaderClass window and sets the text.
---
--- @param self PDASectionHeaderClass The PDASectionHeaderClass instance.
---
function PDASectionHeaderClass:Open()
	self.idText:SetText(self.text)
	XWindow.Open(self)
end

DefineClass.PDARolloverClass = {
	__parents = { "XRolloverWindow" },
	pda = false
}

---
--- Opens the PDARolloverClass window and sets its parent to the PDADialog's rollover area if the PDADialog is visible.
---
--- This function ensures that the rollover window is kept within the application content by updating the layout after setting the parent.
---
--- @param self PDARolloverClass The PDARolloverClass instance.
---
function PDARolloverClass:Open()
	XRolloverWindow.Open(self)
	local pda = GetDialog("PDADialog") or GetDialog("PDADialogSatellite")
	local InGameMenu = GetDialog("InGameMenu")
	if pda and pda:IsVisible() and pda.idDisplay and not InGameMenu then
		self.pda = pda.idRolloverArea
		self:SetParent(pda.idRolloverArea)
		-- Keep the rollover within the application content
		self:UpdateLayout()
	end
end

---
--- Gets the safe area box for the PDARolloverClass window.
---
--- If the PDARolloverClass window does not have a parent PDADialog, this function returns the safe area box for the XRolloverWindow.
--- Otherwise, it returns the content box of the PDADialog's rollover area.
---
--- @param self PDARolloverClass The PDARolloverClass instance.
--- @return table The safe area box in the format {x1, y1, x2, y2}.
---
function PDARolloverClass:GetSafeAreaBox()
	if not self.pda then
		return XRolloverWindow.GetSafeAreaBox(self)
	end
	return self.pda.content_box:xyxy()
end

---
--- Gets the font name with the appropriate size and arguments for the current engine options.
---
--- If the font name contains "HMGothic" and the engine options are set to "Low" effects, the function will return the font name with the size and arguments appended.
--- Otherwise, it will simply return the original font name.
---
--- @param fontName string The font name to be converted.
--- @return string The converted font name.
---
function GetProjectConvertedFont(fontName)
	if string.match(fontName, "HMGothic") and EngineOptions.Effects == "Low" then
		local sizeAndArgs = string.match(fontName, ",.*")
		if sizeAndArgs then
			return "HMGothic Regular" .. sizeAndArgs
		end
	end
	return fontName
end

DefineClass.PDACampaignPausingDlg = {
	__parents = { "XDialog" },
	properties = {
		{ editor = "text", id = "PauseReason", default = "PDACampaignPausingDlg" }
	}
}

---
--- Opens the PDACampaignPausingDlg dialog and pauses the campaign time.
---
--- This function is called to display the PDACampaignPausingDlg dialog and pause the campaign time. The pause reason is obtained from the PauseReason property of the dialog.
---
--- @param self PDACampaignPausingDlg The PDACampaignPausingDlg instance.
---
function PDACampaignPausingDlg:Open()
	XDialog.Open(self)
	PauseCampaignTime(GetUICampaignPauseReason(self.PauseReason))
end

---
--- Resumes the campaign time after the PDACampaignPausingDlg dialog is closed.
---
--- This function is called when the PDACampaignPausingDlg dialog is closed. It resumes the campaign time using the pause reason obtained from the PauseReason property of the dialog.
---
--- @param self PDACampaignPausingDlg The PDACampaignPausingDlg instance.
---
function PDACampaignPausingDlg:OnDelete()
	ResumeCampaignTime(GetUICampaignPauseReason(self.PauseReason))
end

---
--- Gets the appropriate icon for a quest based on its state.
---
--- @param questId string The ID of the quest.
--- @return string The path to the appropriate quest icon.
---
function GetQuestIcon(questId)
	local questDef = Quests[questId]
	local questState = gv_Quests[questId]

	local activeQuest = GetActiveQuest()

	local icon
	if activeQuest == questId then 
		icon = "UI/PDA/Quest/quest_selected"
	elseif QuestIsBoolVar(questState, "Completed", true) then
		icon = "UI/PDA/Quest/checkmark"
	elseif questDef.Main then
		icon = "UI/PDA/Quest/quest_main_"
	else
		icon = "UI/PDA/Quest/quest_side_ "
	end
	return icon
end

QuestGroups = {
	{ value = "The Fate Of Grand Chien", name = T(589059811655, "The Fate Of Grand Chien") },
	{ value = "Ernie Island", name = T(124129063161, "Ernie Island") },
	{ value = "Savanah", name = T(718471746619, "Savanna") },
	{ value = "Farmlands", name = T(160124069584, "Farmlands") },
	{ value = "Jungle", name = T(550382054096, "Jungle") },
	{ value = "Highlands", name = T(389232961179, "Highlands") },
	{ value = "Pantagruel", name = T(734135115036, "Pantagruel") },
	{ value = "Port Cacao", name = T(874186097952, "Port Cacao") },
	{ value = "Wetlands", name = T(351722511561, "Wetlands") },
	{ value = "Other", name = T(329506037614, "Other") }, -- fallback
}

---
--- Collects and organizes quest data for the PDA interface.
---
--- This function retrieves all quest data, including quest groups, quest notes, and quest status, and organizes it into a structured format for display in the PDA interface.
---
--- @return table sections The list of quest groups, each with a name and a list of quests.
--- @return table perQuest The list of all quests, with their notes and status information.
---
function GetQuestLogData()
	local sections = {}
	for i, questGroup in ipairs(QuestGroups) do
		sections[#sections + 1] = {
			HideKey = questGroup.value,
			Name = questGroup.name
		}
	end
	
	local noteCategories = {}
	for i, s in ipairs(sections) do
		local l = {}
		s.Content = l
		noteCategories[s.HideKey] = l
	end
	
	-- Collect data for all quests.
	-- Visible notes, status etc.
	local perQuest = {}
	for q, quest in sorted_pairs(gv_Quests) do
		if quest.Hidden then
			goto continue
		end

		local read_lines = rawget(quest, "read_lines")
		if not read_lines then
			read_lines = {}
			rawset(quest, "read_lines", read_lines)
		end
		
		local questCompleted = QuestIsBoolVar(quest, "Completed",true)
		local questFailed = QuestIsBoolVar(quest, "Failed", true)
		
		if (questCompleted or questFailed) and not UIShowCompletedQuests then goto continue end

		if not quest.note_lines then goto continue end
		local questNotes = {}
		local latestTimestamp, earliestTimestamp = false
		for i, timestamp in pairs(quest.note_lines) do
			if not timestamp then goto continue end
		
			local noteDef = quest.NoteDefs and table.find_value(quest.NoteDefs, "Idx", i)
			if not noteDef then goto continue end

			local state = quest.notes_state
			if state and state[i] then
				state = state[i]
			else
				state = "visible"
			end
			
			local sectors = {}
			for j, b in ipairs(noteDef.Badges) do
				-- See HideQuestBadge effect
				local badgeHideIdentifier = badgeHideIdentifierNote .. tostring(i) .. "@" .. tostring(j)
				if not quest[badgeHideIdentifier] and b.Sector then
					sectors[#sectors+1] = b.Sector
				end
			end
			
			if not latestTimestamp then latestTimestamp = timestamp end
			if not earliestTimestamp then earliestTimestamp = timestamp end
			latestTimestamp = Max(timestamp, latestTimestamp)
			earliestTimestamp = Min(timestamp, earliestTimestamp)

			local readId = "nl" .. noteDef.Idx
			questNotes[#questNotes + 1] = {
				questPreset = quest,
				timestamp = timestamp,
				preset = noteDef,
				state = state,
				read = not not read_lines[readId] or questCompleted or questFailed,
				sectors = sectors,
				readId = readId,
				idx = noteDef.Idx
			}
			::continue::
		end
		
		if #questNotes > 0 then
			-- Completed lines on the bottom, otherwise sort by timestamp or index.
			table.sort(questNotes, function(a, b)
				local aCompleted = a.state == "completed"
				local bCompleted = b.state == "completed"
				
				local sortKeyA = a.timestamp
				local sortKeyB = b.timestamp
				if (aCompleted or bCompleted) and not (aCompleted and bCompleted) then
					if aCompleted then
						sortKeyA = 99999999999
					else
						sortKeyB = 99999999999
					end
				end
				
				if sortKeyA == sortKeyB then
					sortKeyA = a.idx
					sortKeyB = b.idx
				end
				return sortKeyA < sortKeyB
			end)
			
			local listId = quest.QuestGroup or "Other"
			
			perQuest[#perQuest + 1] = {
				id = quest.id,
				listId = listId,
				questHeader = {
					questPreset = quest,
					preset = {
						Text = quest.DisplayName
					},
					state = questFailed and "failed" or (questCompleted and "completed"),
					questHeader = true
				},
				questNotes = questNotes,
				latestTimestamp = latestTimestamp,
				earliestTimestamp = earliestTimestamp,
			}
		end
		::continue::
	end
	
	-- Process quest data into sections.
	-- Quests with latest timestamp notes (most recent developments) are on top.
	table.sort(perQuest, function(a, b)
		local questHeaderA = a.questHeader
		local questHeaderB = b.questHeader
		
		-- Order completed (and failed) quests last.
		local lastA = questHeaderA.state == "failed" or questHeaderA.state == "completed"
		local lastB = questHeaderB.state == "failed" or questHeaderB.state == "completed"
		if lastA ~= lastB then
			if lastA then return false end
			return true
		end
	
		return a.latestTimestamp > b.latestTimestamp
	end)
	for i, questData in ipairs(perQuest) do
		local list = noteCategories[questData.listId]
		list[#list + 1] = questData.questHeader
		
		for i, note in ipairs(questData.questNotes) do
			list[#list + 1] = note
		end
	end

	return sections, perQuest
end

DefineClass.PDAQuestsClass = {
	__parents = { "XDialog" },

	sections = false,
	questData = false,
	selected_quest = false,
}

--- Initializes the quest data for the PDAQuestsClass.
-- This function is called to set up the initial state of the quest data
-- for the PDA (Personal Digital Assistant) UI. It retrieves the quest log
-- data, sorts the quests, and sets the selected quest.
function PDAQuestsClass:Init()
	self:InitQuestData()
end

--- Initializes the quest data for the PDAQuestsClass.
-- This function is called to set up the initial state of the quest data
-- for the PDA (Personal Digital Assistant) UI. It retrieves the quest log
-- data, sorts the quests, and sets the selected quest.
function PDAQuestsClass:InitQuestData()
	local sections, perQuest = GetQuestLogData()
	self.sections = sections
	self.questData = perQuest
	
	local selQuest = false
	if not selQuest then
		local quests = GetAllQuestsForTracker()
		selQuest = quests and quests[1] and quests[1].Id
	end
	
	if not selQuest or not table.find(perQuest, "id", selQuest) then
		selQuest = GetActiveQuest() or (perQuest[1] and perQuest[1].id)
	end
	
	if self.idQuestScroll and self.idQuestScroll.window_state == "open" then
		self.idQuestScroll:RespawnContent()
	end
	
	if selQuest and (not self.selected_quest or not table.find(perQuest, "id", self.selected_quest)) then
		self:SetSelectedQuest(selQuest)
	end
end

--- Sets the selected quest for the PDAQuestsClass.
-- This function is used to set the currently selected quest in the PDA (Personal Digital Assistant) UI.
-- If the selected quest is already set and `force` is false, the function will return early.
-- Otherwise, it will update the `selected_quest` field, notify the actions host that the actions have been updated,
-- and modify the "selected_quest" object. It will also create a thread to select the quest in the quest list scroll area.
-- @param id The ID of the quest to select.
-- @param force If true, the selected quest will be set even if it is already the current selection.
function PDAQuestsClass:SetSelectedQuest(id, force)
	if self.selected_quest == id and not force then return end

	self.selected_quest = id
	local host = GetActionsHost(self, true)
	host:ActionsUpdated()
	ObjModified("selected_quest")
	
	self:DeleteThread("select-in-list")
	self:CreateThread("select-in-list", function()
		local scrollArea = self.idQuestScroll
		while not scrollArea do
			Sleep(1)
			scrollArea = self.idQuestScroll
		end
		if scrollArea.window_state == "destroying" then return end
		
		for i, questWin in ipairs(scrollArea) do
			local questPreset = questWin.context and questWin.context.questPreset
			local questId = questPreset and questPreset.id
			if questId == self.selected_quest then
				self.idQuestScroll:SetSelection(i)
				break
			end
		end
	end)
end

function OnMsg.ActiveQuestChanged()
	local pdaDiag = GetDialog("PDADialog")
	if not pdaDiag or pdaDiag.Mode ~= "quests" then return end
	pdaDiag:ActionsUpdated()
end

--- Returns the selected quest data.
-- This function retrieves the quest data for the currently selected quest in the PDA (Personal Digital Assistant) UI.
-- @return The quest data table for the selected quest, or nil if no quest is selected.
function PDAQuestsClass:GetSelectedQuestData()
	return table.find_value(self.questData, "id", self.selected_quest)
end

--- Formats a quest timestamp as a string in the format "MM/DD".
-- @param context_obj The object containing the timestamp to format.
-- @return The formatted timestamp string.
TFormat.QuestTimestamp = function(context_obj)
	local t = GetTimeAsTable(context_obj.timestamp)
	local day = string.format("%02d", t.day)
	local month = string.format("%02d", t.month)
	return Untranslated(month .. "/" .. day)
end

-- Quest Read Tracking
----------------------

---
--- Sets the read state of a quest line.
---
--- @param questState table The quest state table.
--- @param id string The ID of the quest line.
function SetQuestPropertyRead(questState, id)
	local read_lines = rawget(questState, "read_lines")
	if not read_lines then
		read_lines = {}
		rawset(questState, "read_lines", read_lines)
	end
	read_lines[id] = true
	ObjModified("quest_read")
	ObjModified("quests_tab_changed")
end

---
--- Checks if a quest line has been read.
---
--- @param quest_id string The ID of the quest.
--- @param line_idx number The index of the quest line.
--- @return boolean True if the quest line has been read, false otherwise.
---
function IsQuestLineUnread(quest_id, line_idx)
	local questState = gv_Quests[quest_id]
	local read_lines = rawget(questState, "read_lines")
	if not read_lines then
		return true
	end
	local readId = "nl" .. line_idx
	return not read_lines[readId]
end

---
--- Checks if any quest line in the game has not been read by the player.
---
--- @return boolean True if any quest line has not been read, false otherwise.
---
function GetAnyQuestUnread()
	for q, quest in pairs(gv_Quests) do
		local read_lines = rawget(quest, "read_lines")
		local completed = QuestIsBoolVar(quest, "Completed", true)
		if completed then goto continue end
		
		if quest.note_lines then
			for i, l in pairs(quest.note_lines) do
				if not l then goto continue end
				
				local noteDef = quest.NoteDefs and table.find_value(quest.NoteDefs, "Idx", i)
				if noteDef and IsQuestLineUnread(q, i) then
					return true
				end

				::continue::
			end
		end
		
		::continue::
	end
	
	return false
end

function OnMsg.QuestLinesUpdated(quest)
	ObjModified("quest_read")
end

---
--- Interpolates the visibility and size of an outline window based on whether the mouse is hovering over it.
---
--- @param outline_wnd table The outline window to interpolate.
--- @param rollover boolean True if the mouse is hovering over the outline window, false otherwise.
---
function PDAMercRolloverInterpolation(outline_wnd, rollover)
	if rollover then
		if outline_wnd.visible then return end
		local b = outline_wnd.box
		local center = b:Center()
		outline_wnd:AddInterpolation{
			id = "pop_up",
			type = const.intRect,
			duration = 200,
			originalRect = sizebox(center, 1000, 1000),
			targetRect = sizebox(center, 850, 850),
			flags = const.intfInverse
		}	
		outline_wnd:SetVisible(true)
	else
		outline_wnd:SetVisible(false)
	end
end

if FirstLoad then
UIShowCompletedQuests = true
end

---
--- Returns the action name for toggling the display of completed quests.
---
--- @return string The action name for toggling the display of completed quests.
---
function TFormat.ToggleCompletedQuestsActionName()
	return UIShowCompletedQuests and T(665579374373, "Hide Completed") or T(638113715955, "Show Completed")
end

DefineClass.PDASatelliteAIMMercClass = {
	__parents = { "XButton" },
	FXMouseIn = "MercPortraitRollover",
	FXPress = "MercPortraitPress",
	FXPressDisabled = "MercPortraitDisabled",
	
	selected = false,
}

---
--- Opens the PDASatelliteAIMMercClass and updates its style.
--- Sets the portrait image of the class based on the context.
--- Calls the Open method of the XButton class.
---
--- @param self PDASatelliteAIMMercClass The instance of the class.
---
function PDASatelliteAIMMercClass:Open()
	self:UpdateStyle()
	self.idPortrait:SetImage(self.context ~= "empty" and self.context.Portrait)
	XButton.Open(self)
end

---
--- Handles the press event for a PDASatelliteAIMMercClass instance.
--- If the instance is part of an XList, it sets the selection of the list to the current instance.
---
--- @param self PDASatelliteAIMMercClass The instance of the class.
---
function PDASatelliteAIMMercClass:OnPress()
	local list = self.parent
	list = IsKindOf(list, "XList") and list
	if list then
		list:SetSelection(table.find(list, self))
	end
end

---
--- Sets the selected state of the PDASatelliteAIMMercClass instance.
--- When selected, the HandleKeyboard property is set to false to allow the ButtonA action to propagate to the messenger.
---
--- @param self PDASatelliteAIMMercClass The instance of the class.
--- @param selected boolean The new selected state of the instance.
---
function PDASatelliteAIMMercClass:SetSelected(selected)
	self.selected = selected
	self.HandleKeyboard = not selected -- To allow ButtonA to propagate to the messenger
end

---
--- Handles the double click event for a PDASatelliteAIMMercClass instance.
--- When the instance is double clicked, it invokes the "check state" shortcut action on the PDADialog.
--- It then calls the OnMouseButtonDoubleClick method of the XButton class.
---
--- @param self PDASatelliteAIMMercClass The instance of the class.
--- @param pos table The position of the mouse click.
--- @param button string The mouse button that was clicked.
---
function PDASatelliteAIMMercClass:OnMouseButtonDoubleClick(pos, button)
	local dlg = GetDialog("PDADialog")
	InvokeShortcutAction(dlg, "idContact", dlg, "check state")
	XButton.OnMouseButtonDoubleClick(self, pos, button)
end

---
--- Updates the context and style of the PDASatelliteAIMMercClass instance.
---
--- @param self PDASatelliteAIMMercClass The instance of the class.
--- @param context table The new context for the instance.
---
function PDASatelliteAIMMercClass:OnContextUpdate(context)
	local selected = GetDialog(self).selected_merc == context.session_id
	self:SetSelected(selected)
	self:UpdateStyle()
end

---
--- Updates the style of the PDASatelliteAIMMercClass instance based on its context and selected state.
---
--- @param self PDASatelliteAIMMercClass The instance of the class.
---
function PDASatelliteAIMMercClass:UpdateStyle()
	if self.context == "empty" then return end

	local color, contrastColor, textStyle = false, false, false
	local icon, iconRolloverText = GetMercSpecIcon(self.context)
	local selected = self.selected
	
	if not selected then
		color = GameColors.DarkB
		contrastColor = GameColors.LightDarker
		textStyle = "Hire_MercName_Unselected"
	end
	
	local onlineStatusIcon = self.context.MessengerOnline
	local hireStatus = self.context.HireStatus
	local func = HireStatusToUIMercCardText[hireStatus]
	assert(func)
	func(self.context, self.idPrice)
	if hireStatus == "Hired" then
		color = GameColors.Player
		contrastColor = GameColors.LightDarker
		textStyle = "Hire_MercName_Unselected_Light"
		onlineStatusIcon = "hidden"
	elseif hireStatus == "Dead" then
		color = GameColors.Enemy
		contrastColor = GameColors.LightDarker
		textStyle = "Hire_MercName_Unselected_Light"
	end
	
	local hireStatusPreset = false
	local isPremium = false
	if MercPremiumAndNotUnlocked(self.context.Tier) then
		hireStatusPreset = Presets.MercHireStatus.Default["Premium"]
		isPremium = true
	elseif hireStatus == "Retired" or hireStatus == "Dead" or hireStatus == "MIA" then
		hireStatusPreset = Presets.MercHireStatus.Default[hireStatus]
	end
		
	if hireStatus == "Dead" or hireStatus == "MIA" then
		self.idPortrait:SetDesaturation(255)
		self.idPortraitBG:SetDesaturation(255)
	end
	
	if hireStatusPreset then
		icon = hireStatusPreset.icon or icon
		iconRolloverText = hireStatusPreset.RolloverText
		if onlineStatusIcon ~= "hidden" then onlineStatusIcon = false end
	end

	if selected then
		color = GameColors.Light
		contrastColor = GameColors.DarkB
		textStyle = "Hire_MercName_Selected"
	end

	if not selected then
		self.idContent:SetBackground(RGBA(0,0,0,0))
		self.idContent:SetBackgroundRectGlowColor(RGBA(0,0,0,0))
	end
	self.idSelectedRounding:SetVisible(selected)
	
	self.idOnlineStatusIcon:SetVisible(onlineStatusIcon ~= "hidden")
	self.idOnlineStatusIcon:SetImage(onlineStatusIcon and "UI/PDA/snype_on" or "UI/PDA/snype_off")
	if not onlineStatusIcon then
		self.idPortrait:SetDesaturation(255)
		self.idPortrait:SetTransparency(50)
	end
	self.idOffline:SetVisible(not onlineStatusIcon and not isPremium)

	self.idBottomSection:SetBackground(color)
	self.idClassIconBg:SetBackground(color)
	self.idClassIconBg:SetRolloverText(iconRolloverText)
	
	local price = GetMercPrice(self.context, 7, true)
	self.idExpensive:SetVisible(hireStatus == "Available" and price > Game.Money)

	self.idClassIcon:SetImage(icon)
	self.idClassIcon:SetImageColor(contrastColor)
	self.idName:SetTextStyle(textStyle)
end

GameVar("gv_SquadsAndMercsFolded", false)

DefineClass.SquadsAndMercsClass = {
	__parents = { "XContextWindow", "XDrawCache" },
	selected_squad = false,
	properties = {
		{ category = "SquadsAndMercs", id = "teamColor", name = "Team Color", editor = "color", default = RGBA(21, 132, 138, 255)},
	},
	IdNode = true
}

---
--- Initializes the SquadsAndMercsClass by selecting a squad.
--- If no squad is provided, it will select the default squad from the context or the current squad.
---
--- @param self SquadsAndMercsClass The instance of the SquadsAndMercsClass.
---
function SquadsAndMercsClass:Init()
	self:SelectSquad(false)
end

---
--- Updates the context of the SquadsAndMercsClass.
--- If the currently selected squad is no longer in the context, it selects a new squad.
---
--- @param self SquadsAndMercsClass The instance of the SquadsAndMercsClass.
--- @param ... any Additional arguments passed to the function.
---
function SquadsAndMercsClass:OnContextUpdate(...)
	if not self.selected_squad or not table.find(self.context, self.selected_squad) then
		self:SelectSquad(false, "skipRespawn")
	end
	XContextWindow.OnContextUpdate(self, ...)
end

---
--- Selects a squad for the SquadsAndMercsClass.
---
--- If no squad is provided, it will select the default squad from the context or the current squad.
---
--- @param self SquadsAndMercsClass The instance of the SquadsAndMercsClass.
--- @param squad table The squad to select, or `false` to select the default squad.
--- @param skipRespawn boolean If true, the squad selection will not trigger a respawn.
--- @return boolean, table, table Whether the squad selection changed, the new selected squad, and the old selected squad.
---
function SquadsAndMercsClass:SelectSquad(squad, skipRespawn)
	local old_squad = self.selected_squad or (g_CurrentSquad and gv_Squads[g_CurrentSquad])
	
	-- Ensure the squad with the selected units is current, in tactical view.
	if not g_SatelliteUI then
		EnsureCurrentSquad()
	end
	
	if not squad then
		-- Get default selection from the sat diag, if it's open and satellite gameplay is running.
		local dlg = GetSatelliteDialog()
		if dlg and IsValidThread(g_SatelliteThread) then
			squad = dlg and dlg.selected_squad
			if squad and not table.find_value(self.context, "UniqueId", squad.UniqueId) then
				squad = false
			end
		end
		
		if not squad then
			if self.context then
				squad = table.find_value(self.context, "UniqueId", g_CurrentSquad) or self.context[1]
			else
				squad = gv_Squads[g_CurrentSquad]
			end
		end
	end

	local changed = false
	local new_squad = squad
	-- This is always true as the selected_squads is always false because of the rebuild.
	if new_squad and self.selected_squad ~= new_squad then
		self.selected_squad = new_squad
		local squadData = gv_Squads[self.selected_squad.UniqueId]
		local isPlayer = squadData and (squadData.Side == "player1" or squadData.Side == "player2")
		if isPlayer then
			if old_squad and old_squad.UniqueId ~= new_squad.UniqueId then
				PlayFX("SquadSelected")
				Msg("NewSquadSelected", new_squad, old_squad)
			end
			g_CurrentSquad = new_squad.UniqueId
			Msg("CurrentSquadChanged")
		end

		changed = true
	end
	
	if self.window_state == "open" and not skipRespawn then
		for i, s in ipairs(self.idSquads) do
			s:ApplySelection()
		end
		self.idParty:SetContext(self.selected_squad)
		self.idTitle:OnContextUpdate(self.idTitle.context)
	end

	return changed, new_squad, old_squad
end

local function lUpdatePDAPowerButtonStateInternal(pda)
	local enabled, reason = GetSquadEnterSectorState()
	
	local powerBtn = pda:ResolveId("idPowerButton")
	if powerBtn then
		powerBtn:SetProperty("RolloverDisabledText", enabled and "" or reason)
		powerBtn:SetEnabled(enabled)
	end
	ObjModified("gv_SatelliteView")
end

--- Updates the power button state in the PDA dialog.
---
--- This function is called in response to various game events that may affect the
--- state of the power button in the PDA dialog, such as the squad travelling,
--- an operation changing, the sector center being reached, or the sector side
--- changing.
---
--- The function first retrieves the PDA dialog and the PDA satellite dialog, if
--- they exist, and then calls the `lUpdatePDAPowerButtonStateInternal` function
--- to update the power button state in each dialog.
---
--- @function UpdatePDAPowerButtonState
--- @return nil
function UpdatePDAPowerButtonState()
	local dlg = GetDialog("PDADialog")
	if dlg then lUpdatePDAPowerButtonStateInternal(dlg) end
	
	local dlgSat = GetDialog("PDADialogSatellite")
	if dlgSat then lUpdatePDAPowerButtonStateInternal(dlgSat) end
end

OnMsg.SquadTravellingTickPassed = UpdatePDAPowerButtonState
OnMsg.OperationChanged = UpdatePDAPowerButtonState
OnMsg.ReachSectorCenter = UpdatePDAPowerButtonState
OnMsg.SectorSideChanged = UpdatePDAPowerButtonState

DefineClass.CrosshairCircleButton = {
	__parents = { "XButton" },
	properties = {
		{ id = "left_side", editor = "bool", default = false }
	},
	
	circle_offset_x = false,
	circle_offset_y = false,
	
	fill_image = false,
	fill_image_obj = false,
	fill_image_src_rect = false,
	
	x_offset = 0,
	y_offset = 0
}

DefineClass.CrosshairButtonParent = {
	__parents = { "XWindow" }
}

--- Measures the size of the CrosshairButtonParent window and its child windows.
---
--- This function overrides the Measure function of the XWindow class to ensure that
--- all child windows have the same maximum width, even if their individual widths
--- differ. This is done to ensure that the child windows are aligned properly.
---
--- @function CrosshairButtonParent:Measure
--- @param ... - Additional arguments passed to the XWindow.Measure function
--- @return number, number - The measured width and height of the CrosshairButtonParent window
function CrosshairButtonParent:Measure(...)
	local x, y = XWindow.Measure(self, ...)
	
	local widest = 0
	for i, c in ipairs(self) do
		if c.measure_width > widest and c.visible then
			widest = c.measure_width
		end
	end
	for i, c in ipairs(self) do
		c.measure_width = widest
	end
	
	return x, y
end

---
--- Sets the layout space for the CrosshairCircleButton.
---
--- This function overrides the SetLayoutSpace function of the XWindow class to
--- adjust the position and size of the CrosshairCircleButton based on its
--- properties, such as the left_side flag and the circle_offset_x and
--- circle_offset_y values.
---
--- @param space_x number The x-coordinate of the layout space
--- @param space_y number The y-coordinate of the layout space
--- @param space_width number The width of the layout space
--- @param space_height number The height of the layout space
--- @return boolean True if the layout space was successfully set, false otherwise
function CrosshairCircleButton:SetLayoutSpace(space_x, space_y, space_width, space_height)
	local myBox = self.box
	local x, y = myBox:minx(), myBox:miny()
	local width = Min(self.measure_width, space_width)
	local height = Min(self.measure_height, space_height)

	local scaledX, scaledY = ScaleXY(self.scale, self.circle_offset_x, self.circle_offset_y)
	
	local xOffset
	if self.left_side then
		xOffset = scaledX - width + ScaleXY(self.scale, 19) -- center on the image width
	else
		xOffset = scaledX - ScaleXY(self.scale, 19) -- center on the image width
	end
	
	local yOffset = scaledY - height / 2
	space_x = space_x + xOffset
	space_y = space_y + yOffset
	
	self.x_offset = xOffset
	self.y_offset = yOffset
	return XWindow.SetLayoutSpace(self, space_x, space_y, space_width, space_height)
end

-- Draws windows in reverse, used for the floor display
DefineClass.XWindowReverseDraw = {
	__parents = { "XWindow" }
}

---
--- Draws the children windows of the XWindowReverseDraw class in reverse order.
---
--- This function overrides the DrawChildren method of the XWindow class to draw the
--- child windows in reverse order, starting from the last child window and going
--- backwards to the first child window. This is used for the floor display in the
--- game.
---
--- @param clip_box table The clipping box to use when drawing the child windows
--- @return nil
function XWindowReverseDraw:DrawChildren(clip_box)
	local chidren_on_top
	local UseClipBox = self.UseClipBox
	for i = #self, 1, -1 do
		local win = self[i]
		if win.visible and not win.outside_parent and (not UseClipBox or win.box:Intersect2D(clip_box) ~= irOutside) then
			if win.DrawOnTop then
				chidren_on_top = true
			else
				win:DrawWindow(clip_box)
			end
		end
	end
	if chidren_on_top then
		for i = #self, 1, -1 do
			local win = self[i]
			if win.DrawOnTop and win.visible and not win.outside_parent and (not UseClipBox or win.box:Intersect2D(clip_box) ~= irOutside) then
				win:DrawWindow(clip_box)
			end
		end
	end
end

DefineClass.OperationProgressBarSection = {
	__parents = { "ZuluFrameProgress" },
	properties = {
		{ category = "Visual", id = "ProgressColor", name = "Progress color", editor = "color", default =  const.HUDUIColors.selectedColored},
	},	
	Background = const.HUDUIColors.defaultColor,
}

---
--- Draws the background and progress bar for an OperationProgressBarSection.
---
--- This function is responsible for drawing the background and progress bar for an OperationProgressBarSection. It calculates the size of the progress bar based on the current progress and the alignment settings, and then draws the background and progress bar using the appropriate colors.
---
--- @param self OperationProgressBarSection The OperationProgressBarSection instance to draw the background and progress bar for.
--- @return nil
function OperationProgressBarSection:DrawBackground()
	local b = self.box
	local progressRatio = MulDivRound(self.Progress, 1000, self.MaxProgress)
	if self.Horizontal then
		local w = MulDivRound(b:sizex(), progressRatio, 1000)
		if self.HAlign == "right" then
			b = sizebox(b:minx() + (b:sizex() - w), b:miny(), w, b:sizey())
		else--if self.HAlign == "left" or self.HAlign == "center"  then
			b = sizebox(b:minx(), b:miny(), w, b:sizey())		
		end
	else
		local h = MulDivRound(b:sizey(), progressRatio, 1000)
		if self.VAlign == "bottom" then
			b = sizebox(b:minx(), b:miny() + (b:sizey() - h), b:sizex(), h)
		else
			b = sizebox(b:minx(), b:miny(), b:sizex(), h)
		end
	end
	UIL.DrawSolidRect(self.box, self.Background)
	UIL.DrawSolidRect(b, self.ProgressColor)
end

---
--- Disables drawing of child windows for this OperationProgressBarSection.
---
--- This function overrides the default `DrawChildren` behavior of the `XFrameProgress` class, effectively disabling the drawing of any child windows for this OperationProgressBarSection. This is likely done to ensure that the progress bar is drawn without any interference from child windows.
---
--- @param self OperationProgressBarSection The OperationProgressBarSection instance.
--- @param ... any Additional arguments passed to the `DrawChildren` function.
--- @return nil
function OperationProgressBarSection:DrawChildren()
 -- nop
end

DefineClass.OperationProgressBar = {
	__parents = { "OperationProgressBarSection" },
	
	ProgressColor = GameColors.J,
	Background    = GameColors.H,
	Horizontal    = true,
	HAlign        = "left",
}
---
--- Calls the default `DrawChildren` behavior of the `XFrameProgress` class.
---
--- This function overrides the `DrawChildren` function of the `OperationProgressBar` class, and simply calls the default `DrawChildren` implementation of the `XFrameProgress` class. This is likely done to ensure that any child windows of the `OperationProgressBar` are drawn as expected, without any additional customization.
---
--- @param self OperationProgressBar The `OperationProgressBar` instance.
--- @param ... any Additional arguments passed to the `DrawChildren` function.
--- @return nil
function OperationProgressBar:DrawChildren(...)
	return XFrameProgress.DrawChildren(self,...)
end

HUDButtonHeight = 75
local titleColor = const.PDAUIColors.titleColor
local selBorderColor = const.PDAUIColors.selBorderColor
local noClr = const.PDAUIColors.noClr
local selectedColored =const.HUDUIColors.selectedColored
local defaultColor = const.HUDUIColors.defaultColor
DefineClass.HUDButton = {
	__parents = { "XButton", "XTranslateText" },
	properties = {
		{ category = "Image", id = "Image", editor = "ui_image", default = "", },
		{ category = "Image", id = "Columns", editor = "number", default = 2, },
		{ category = "Image", id = "ColumnsUse", editor = "text", default = "ababa", },
	},

	FXMouseIn = "buttonRollover",
	FXPress = "buttonPress",
	FXPressDisabled = "IactDisabled",
	IdNode = true,
	Background = noClr,
	FocusedBackground = noClr,
	RolloverBackground = noClr,
	PressedBackground = noClr,
	Translate = true,

	HAlign = "center",
	VAlign = "center",
	MinWidth = 64,
	MaxWidth = 64,
	MinHeight = HUDButtonHeight,
	MaxHeight = HUDButtonHeight,
	
	selected = false,
	Padding = box(0, 0, 0, 0)
}

---
--- Initializes an instance of the `HUDButton` class.
---
--- This function is called during the initialization of an `HUDButton` instance. It sets up the visual elements of the button, including an `XImage` for the button's image and an `AutoFitText` for the button's text.
---
--- The `XImage` is set up with the following properties:
--- - `Id`: "idImage"
--- - `Column`: The result of calling `self:GetColumn()`
--- - `Image`: The value of `self.Image`
--- - `Columns`: The value of `self.Columns`
--- - `HAlign`: "center"
--- - `VAlign`: "top"
--- - `Margins`: box(0, -2, 0, 0)
---
--- The `AutoFitText` is set up with the following properties:
--- - `Id`: "idText"
--- - `TextStyle`: "HUDButtonKeybind" (temporary)
--- - `Text`: The value of `self.Text`
--- - `Translate`: The value of `self.Translate`
--- - `HAlign`: "center"
--- - `VAlign`: "bottom"
--- - `TextVAlign`: "center"
--- - `HideOnEmpty`: true
--- - `Margins`: box(0, 3, 0, 0)
--- - `SafeSpace`: 5
---
--- @param self HUDButton The `HUDButton` instance being initialized.
function HUDButton:Init()
	XTextButton.SetColumnsUse(self, self.ColumnsUse)

	local img = XTemplateSpawn("XImage", self)
	img:SetId("idImage")
	img:SetColumn(self:GetColumn())
	img:SetImage(self.Image)
	img:SetColumns(self.Columns)
	img:SetHAlign("center")
	img:SetVAlign("top")
	img:SetMargins(box(0, -2, 0, 0))

	local text = XTemplateSpawn("AutoFitText", self)
	text:SetId("idText")
	text:SetTextStyle("HUDButtonKeybind") -- temp
	text:SetText(self.Text)
	text:SetTranslate(self.Translate)
	text:SetHAlign("center")
	text:SetVAlign("bottom")
	text:SetTextVAlign("center")
	text:SetHideOnEmpty(true)
	text:SetMargins(box(0, 3, 0, 0))
	text.SafeSpace = 5
end

---
--- Opens the HUDButton instance.
---
--- @param self HUDButton The HUDButton instance being opened.
--- @param ... Any additional arguments passed to the Open function.
function HUDButton:Open(...)
	XButton.Open(self, ...)
end

---
--- Sets the text of the HUDButton instance.
---
--- @param self HUDButton The HUDButton instance.
--- @param text string The new text to set.
function HUDButton:SetText(text)
	self.Text = text
	if self.idText then self.idText:SetText(text) end
end

---
--- Sets the image of the HUDButton instance.
---
--- @param self HUDButton The HUDButton instance.
--- @param img string The new image to set.
function HUDButton:SetImage(img)
	if self.idImage then self.idImage:SetImage(img) end
end

---
--- Sets the number of columns for the HUDButton instance's image.
---
--- @param self HUDButton The HUDButton instance.
--- @param col number The new number of columns for the image.
function HUDButton:SetColumns(col)
	if self.idImage then self.idImage:SetColumns(col) end
end

---
--- Invalidates the HUDButton instance, updating the image column based on the current selection state.
---
--- @param self HUDButton The HUDButton instance being invalidated.
--- @param ... Any additional arguments passed to the Invalidate function.
function HUDButton:Invalidate(...)
	XButton.Invalidate(self, ...)
	if self.idImage then self.idImage:SetColumn(self:GetColumn()) end
end

---
--- Returns the column index of the HUDButton instance based on its selected state.
---
--- @param self HUDButton The HUDButton instance.
--- @return number The column index of the HUDButton instance.
function HUDButton:GetColumn()
	if self.selected then
		return 2
	end
	return XTextButton.GetColumn(self)
end

---
--- Sets the selected state of the HUDButton instance and updates its appearance accordingly.
---
--- @param self HUDButton The HUDButton instance.
--- @param sel boolean The new selected state of the HUDButton.
function HUDButton:SetSelected(sel)
	self.selected = sel
	self:SetBackground(sel and titleColor or noClr)
	self:SetBorderColor(sel and selBorderColor or noClr)
	self.idText:SetTextStyle(sel and "HUDButtonKeybindActive" or "HUDButtonKeybind")
end

---
--- Handles the rollover state of the HUDButton instance.
---
--- @param self HUDButton The HUDButton instance.
--- @param rollover boolean The new rollover state of the HUDButton.
function HUDButton:OnSetRollover(rollover)
	XButton.OnSetRollover(self, rollover)
end

---
--- Sets the enabled state of the HUDButton instance and updates its appearance accordingly.
---
--- @param self HUDButton The HUDButton instance.
--- @param enabled boolean The new enabled state of the HUDButton.
function HUDButton:SetEnabled(enabled)
	if enabled == self.enabled then return end
	XButton.SetEnabled(self, enabled)
	if not self.idImage then return end
	self.idImage:SetTransparency(enabled and 0 or 102)
	self.idImage:SetDesaturation(enabled and 0 or 255)
	if not enabled then
		self.idText:SetTextStyle("HUDButtonKeybind")
	end
end

---
--- Sets the action and rollover effect for the HUDButton instance.
---
--- @param self HUDButton The HUDButton instance.
--- @param value string The ID of the action to be associated with the button.
function HUDButton:SetOnPressParam(value)
	local host = GetActionsHost(self, true)
	if self.OnPressEffect == "action" then
		self.action = host and host:ActionById(value) or nil
		if not self.action then
			self.action = XShortcutsTarget:ActionById(value) or nil
		end
	end
	XButton.SetOnPressParam(self, value)
	self:SetFXMouseIn(value .. "Rollover")
end

local floorIcons = {
	["unselected"] = "UI/Hud/T_HUD_LevelIcon_Unselected_Down",
	["top-unselected"] = "UI/Hud/T_HUD_LevelIcon_Unselected_Up",
	["selected"] = "UI/Hud/T_HUD_LevelIcon_Selected_down",
	["top-selected"] = "UI/Hud/T_HUD_LevelIcon_Selected_Up",
}

DefineClass.FloorHUDButtonClass = {
	__parents = { "HUDButton" },
	current_floor = false
}

---
--- Opens the floor display for the HUDButton instance and sets up an observer thread to track changes in the current floor.
---
--- @param self FloorHUDButtonClass The FloorHUDButtonClass instance.
function FloorHUDButtonClass:Open()
	for i = 0, hr.CameraTacMaxFloor do
		local floorWnd = XTemplateSpawn("XWindow", self.idFloorDisplay)
		floorWnd:SetIdNode(true)
	
		local floorImg = XTemplateSpawn("XImage", floorWnd)
		floorImg:SetId("idImage")
		floorImg:SetImage(floorIcons["unselected"])
	end
	self.idFloorDisplay:InvalidateLayout()
	HUDButton.Open(self)

	self.current_floor = cameraTac.GetFloor()
	self:CreateThread("floor_observer", function()
		while self.window_state ~= "destroying" do
			WaitMsg("TacCamFloorChanged")
			self.current_floor = cameraTac.GetFloor()
			self:UpdateSelectedFloor()
		end
	end)
	self:UpdateSelectedFloor()
end

---
--- Updates the selected floor indicator in the floor display.
---
--- @param self FloorHUDButtonClass The FloorHUDButtonClass instance.
function FloorHUDButtonClass:UpdateSelectedFloor()
	local floorWndContainer = self.idFloorDisplay
	local selectedFloor = self.current_floor
	local maxFloor = hr.CameraTacMaxFloor
	for i, w in ipairs(floorWndContainer) do
		local topFloor = i == 1
		local topFloorPrefix = topFloor and "top-" or ""
		local selected = (maxFloor - (i - 1)) == selectedFloor
		local selectedPrefix = selected and "selected" or "unselected"
		w.idImage:SetImage(floorIcons[topFloorPrefix .. selectedPrefix])
		
		w:SetMargins(topFloor and selected and box(0, -2, 0, 0) or empty_box)
	end
end

local lHudMercHeight = 103
local lHudMercAdditionOnSelect = 5
DefineClass.HUDMercClass = {
	__parents = { "XButton" },
	properties = {
		{ id = "ClassIconOnRollover", editor = "bool", default = false },
		{ id = "LevelUpIndicator", editor = "bool", default = true }
	},
	
	FXMouseIn = "MercPortraitRollover",
	FXPress = "MercPortraitPress",
	FXPressDisabled = "MercPortraitDisabled",
	
	style = false,
	-- Whether "full" mode selection should look the same in disabled mode (it doesnt by default)
	full_selection_when_disabled = false
}

---
--- Opens the HUD merc button, setting up the portrait and class icon.
---
--- @param self HUDMercClass The HUDMercClass instance.
function HUDMercClass:Open()
	if self.idPortrait.Image == "" then
		if self.context == "empty" then
			self.idPortrait:SetImage(false)
		else
			local portraitPath = self.context.Portrait
			
			local templateId = IsKindOf(self.context, "Unit") and self.context.unitdatadef_id or -- tactical view
						IsKindOf(self.context, "UnitData") and self.context.class or -- satellite view
						type(self.context) == "table" and IsKindOf(self.context.template, "UnitData") and self.context.template.class -- enemy squad rollovers
			if templateId then
				portraitPath = GetTHPortraitForCharacter(templateId)
			end

			self.idPortrait:SetImage(portraitPath)
		end
	end

	local spec = Presets.MercSpecializations.Default
	spec = spec[self.context.Specialization]
	if spec then
		self.idClassIcon:SetImage(spec.icon)
	else
		local militiaIdx = self.context ~= "empty" and table.find(MilitiaUpgradePath, self.context.class)
		local militiaIcon = militiaIdx and MilitiaIcons[militiaIdx]
		if militiaIcon then
			self.idClassIcon:SetImage(militiaIcon)
			self.idClass:SetVisible(true)
		else
			self.idClass:SetVisible(false)
		end
	end
	
	self:SetupStyle()
	XButton.Open(self)
end

---
--- Sets up the style of the HUDMercClass based on the state of the associated context.
---
--- The function checks the state of the context (e.g. selected, downed, dead, low AP) and sets the appropriate style for the HUDMercClass UI elements such as the portrait, class icon, and bottom bar.
---
--- @param self HUDMercClass The HUDMercClass instance.
function HUDMercClass:SetupStyle()
	local style = "default"
	local is_unit = IsKindOf(self.context, "Unit")
	
	local selected = self.selected
	local downed = is_unit and self.context:IsDowned()
	local dead = IsKindOf(self.context, "PropertyObject") and self.context:HasMember("IsDead") and self.context:IsDead() or self.context.is_dead
	local bandaging = is_unit and self.context:HasStatusEffect("BandageInCombat")
	local beingBandaged = is_unit and self.context:HasStatusEffect("BeingBandaged")
	if dead then
		style = "dead"
		selected = false
	elseif downed then
		style = "downed"
		selected = false
	elseif selected == "full" then
		style = "selected-full"
	elseif selected then
		style = "selected"
	end
	
	local noAP = is_unit and g_Combat and self.context.ActionPoints < const["Action Point Costs"].Walk	
	if not downed and not dead and noAP then
		style = style .. "-noAP"
	end
	
	local lowAP = noAP
	if not noAP and is_unit then
		local defaultAction = self.context:GetDefaultAttackAction()
		local cost = defaultAction:GetAPCost(self.context)
		lowAP = not self.context:HasAP(cost)
		if lowAP then
			style = style .. "-lowAP"
		end
	end

	local enabled = self.enabled
	if not enabled then	
		style = style .. "-disabled"
	end
	
	local stealthy = is_unit and self.context:HasStatusEffect("Hidden")
	if stealthy then
		style = style .. "-stealthy"
	end
	
	if bandaging then
		style = style .. "-bandaging"
	end
	
	if beingBandaged then
		style = style .. "-bandaged"
	end
	
	if self.style == style then return end
	self.style = style

	local desaturate = dead or noAP or not enabled or bandaging
	desaturate = desaturate and 255
	if downed then
		desaturate = 180
	end
	self.idPortraitBG:SetDesaturation(desaturate or 0)
	self.idPortrait:SetDesaturation(desaturate or 0)
	
	local portraitFx = "Default"
	if beingBandaged then
		portraitFx = "UIFX_Portrait_Heal"
	elseif stealthy then
		portraitFx = "UIFX_Portrait_Stealth"
	elseif dead then
		portraitFx = "UIFX_Portrait_Killed"
	elseif downed then
		portraitFx = "UIFX_Portrait_Downed"
	end
	self.idPortrait:SetUIEffectModifierId(portraitFx)

	if downed then
		self.idPortrait:SetTransparency(50)
		self:SetTransparency(0)
		self.idBar:SetTransparency(120)
		self.idBar:SetColorPreset("desaturated")
	elseif dead then
		self.idSkull:SetVisible(true)
		self:SetTransparency(120)
		self.idBar:SetTransparency(0)
		self.idBar:SetColorPreset("default")
	else
		self.idSkull:SetVisible(false)
		self:SetTransparency(0)
		self.idBar:SetTransparency(0)
		self.idBar:SetColorPreset("default")
	end

	if enabled then
		self.idBottomPart:SetBackground(selected == "full" and noClr or defaultColor)
		self.idBottomPart:SetBackgroundRectGlowColor(selected == "full" and noClr or defaultColor)
	else -- idContent not visible in this case.
		self.idBottomPart:SetBackground(selected and selectedColored or defaultColor)
		self.idBottomPart:SetBackgroundRectGlowColor(selected and selectedColored or defaultColor)
	end
	self.idContent:SetBackground(selected and const.clrWhite or noClr)
	self.idContent:SetBackgroundRectGlowColor(selected and selectedColored or noClr)
	self.idContent:SetImage(selected and "UI/PDA/os_portrait_selection" or "")
	self.idBottomBar:SetVisible(selected and selected ~= "full")
	self.idName:SetTextStyle(selected == "full" and "PDAMercNameCard" or "PDAMercNameCard_Light")
	if self.idBar then
		self.idBar.maxHpChangedBgColor = selected == "full" and selectedColored or false
	end
	
	if not enabled and selected == "full" and self.full_selection_when_disabled then
		self.idBottomPart:SetBackground(noClr)
		self.idBottomPart:SetBackgroundRectGlowColor(noClr)
		self.idContent:SetDisabledBackground(const.clrWhite)
		self.idPortraitBG:SetDisabledImageColor(const.clrWhite)
	else
		self.idContent:SetDisabledBackground(noClr)
		self.idPortraitBG:SetDisabledImageColor(RGBA(255, 255, 255, 160))
	end
	
	-- Combat
	if self.idAPIndicator then
		self.idAPIndicator:SetBackground(selected and selectedColored or defaultColor)
		self.idAPIndicator:SetBackgroundRectGlowSize(selected and 0 or 1)
		self.idAPIndicator:SetBackgroundRectGlowColor(selected and selectedColored or defaultColor)
		self.idBandageIndicator:SetVisible(bandaging)
		self.idAPText:SetVisible(not bandaging)
		
		if lowAP then
			self.idAPText:SetTextStyle("HUDHeaderDarkRed")
		else
			self.idAPText:SetTextStyle(selected and "HUDHeaderDark" or "HUDHeader")
		end
		
		self.idBeingBandagedIndicator:SetVisible(beingBandaged)
		self.idWounded:SetVisible(not beingBandaged)
	end
	
	if self.idRadioAnim then
		self.idRadioAnim:SetImageColor(selected == "full" and defaultColor or selectedColored)
	end
	
	-- Satellite
	if self.idOperationContainer then
		self.idOperationContainer:SetBackground(selected and selectedColored or defaultColor)
		self.idOperationContainer:SetBackgroundRectGlowColor(selected and selectedColored or defaultColor)
		self.idOperationContainer.idOperation:SetImageColor(selected and GameColors.A or GameColors.J)
	end
	
	if self.context == "empty" then
		self.idName:SetText(Untranslated(" "))
	end
end

---
--- Sets the selected state of the HUDMercClass instance.
---
--- @param selected boolean Whether the instance is selected or not.
--- @return boolean Whether the selected state was changed.
function HUDMercClass:SetSelected(selected)
	if self.selected == selected then return false end
	self.selected = selected
	self:SetupStyle()
end

---
--- Sets the enabled state of the HUDMercClass instance.
---
--- @param enabled boolean Whether the instance should be enabled or not.
--- @return boolean Whether the enabled state was changed.
function HUDMercClass:SetEnabled(enabled)
	if self.selected == enabled then return end
	XButton.SetEnabled(self, enabled)
	self:SetupStyle()
end

---
--- Called when the HUDMercClass instance is set to be rolled over.
---
--- @param rollover boolean Whether the instance is being rolled over or not.
function HUDMercClass:OnSetRollover(rollover)
	if self.ClassIconOnRollover then
		self.idClass:SetVisible(rollover)
	end
	XButton.OnSetRollover(self, rollover)
end

---
--- Gets the mouse target for the HUDMercClass instance.
---
--- @param pt table The mouse position point.
--- @return table|nil The target object under the mouse, and the mouse cursor to use.
function HUDMercClass:GetMouseTarget(pt)
	if self.desktop.mouse_capture == self then
		return self, self:GetMouseCursor()
	end

	if self.HandleMouse then
		local content = self.idContent
		if content and content:MouseInWindow(pt) then
			local target, cursor = content:GetMouseTarget(pt)
			if target then return target, cursor end
			return self, self:GetMouseCursor()
		end
		
		local indicator = self.idOperationContainer or self.idAPIndicator
		if indicator and indicator:MouseInWindow(pt) then
			if indicator.HandleMouse then
				return indicator, indicator:GetMouseCursor()
			else
				return self, self:GetMouseCursor()
			end
		end
	end
	
	-- Prevent focuses on the hud merc window that aren't on the indicator or "content" container
	-- This fixes mouse focus in the empty part of the window box.
	local target, cursor = XContextControl.GetMouseTarget(self, pt)
	if target ~= self then
		return target, cursor
	end
end

DefineClass.SatelliteConflictSquadsAndMercsClass = {
	__parents = { "SquadsAndMercsClass" },
	currentSquadIndex = 1,
}

---
--- Updates the context of the SatelliteConflictSquadsAndMercsClass instance.
---
--- @param ... any Additional arguments passed to the function.
function SatelliteConflictSquadsAndMercsClass:OnContextUpdate(...)
	self.currentSquadIndex = table.find(self.context, self.selected_squad)
	self[1].idTitle:SetContext(self.selected_squad, true)
	SquadsAndMercsClass.OnContextUpdate(self, ...)
end

---
--- Advances to the next squad in the context of the SatelliteConflictSquadsAndMercsClass instance.
---
--- If there is only one squad in the context, this function does nothing.
--- Otherwise, it updates the `currentSquadIndex` to the next squad in the context, wrapping around to the first squad if the end of the list is reached.
--- It then calls `SelectSquad` with the new selected squad.
---
--- @return nil
function SatelliteConflictSquadsAndMercsClass:NextSquad()
	if #self.context <= 1 then return end
	
	if self.currentSquadIndex + 1 > #self.context then
		self.currentSquadIndex = 1
	else 
		self.currentSquadIndex = self.currentSquadIndex + 1
	end
	
	self:SelectSquad(self.context[self.currentSquadIndex])
end

DefineClass.XInventoryItemEmbed = {
	__parents = { "XContextWindow" },
	properties = {
		{ editor = "text", id = "slot", default = "" },
		{ editor = "number", id = "square_size", default = 70 },
		{ editor = "bool", id = "HideWhenEmpty", default = false },
		{ editor = "bool", id = "ShowOwner", default = false }
	},
	HandleMouse = true,
	ChildrenHandleMouse = true
}

---
--- Opens the XInventoryItemEmbed window and populates it with items from the context.
---
--- If the context is a table, it is used directly as the list of items.
--- If the context is a single InventoryItem, it is wrapped in a table.
--- If the `slot` property is set, the items in that slot of the inventory are used.
--- Otherwise, the items from the `inventory` context are used.
---
--- For each item, a new XContextImage is spawned and configured with the item's icon, rollover, and other properties.
--- The window's size is adjusted to fit the items, and the window is made visible if it is not empty.
---
--- @param self XInventoryItemEmbed The instance of the XInventoryItemEmbed class.
function XInventoryItemEmbed:Open()
	local inventory = self.context
	local items = {}
	if type(inventory) == "table" and not IsKindOf(inventory, "PropertyObject") then
		items = inventory
	elseif IsKindOf(inventory, "InventoryItem") then
		items = { inventory }
	elseif #(self.slot or "") > 0 then 
		inventory:ForEachItemInSlot(self.slot, function(slot_item, slot_name, item_left, item_top, items)
			items[#items + 1] = slot_item
		end, items)
	elseif next(inventory) then
		items = inventory
	end

	for i, item in ipairs(items) do
		local img = XTemplateSpawn("XContextImage", self, item);
		img:SetImage(item:GetItemUIIcon())
		img:SetImageFit("width")
		img:SetRolloverTemplate("RolloverInventory")
		local newRollover = UseNewInventoryRollover(item)
		img:SetRolloverAnchor(UseNewInventoryRollover(item) and "custom" or "center-top")
		if not newRollover then
			img:SetRolloverOffset(box(0, 0, 0, 10))
		end
		img:SetRolloverText("placeholder")
		img:SetHAlign("left")
		img:SetVAlign("top")
		img:SetHandleMouse(true)
		img:SetMinWidth(self.square_size * item:GetUIWidth())
		img:SetMaxWidth(self.square_size * item:GetUIWidth())
		img:SetMinHeight(self.square_size)
		img:SetMaxHeight(self.square_size)
		img:SetBackground(self.Background)
		img:SetFXMouseIn("PerkRollover")
		if item.SubIcon and item.SubIcon~="" then
			local item_subimg = XTemplateSpawn("XImage", img)	
			item_subimg:SetHAlign("left")
			item_subimg:SetVAlign("bottom")
			item_subimg:SetImage(item.SubIcon)
			item_subimg:SetMargins(box(2, 2, 2, 2))
			item_subimg:SetHandleMouse(false)
		end		
	end

	self:SetMinWidth(self.square_size)
	self:SetMinHeight(self.square_size)
	if #items > 0 then
		self:SetBackground(RGBA(0,0,0,0))
		if self.LayoutHSpacing == 0 then self:SetLayoutHSpacing(self.parent.LayoutHSpacing) end
		if self.LayoutVSpacing == 0 then self:SetLayoutVSpacing(self.parent.LayoutVSpacing) end
	end

	if self.HideWhenEmpty then
		self:SetVisible(#items > 0)
		-- List layouts will still add list spacing even if fold when hidden and invisible.
		-- Setting a dock is the only way to shortcircuit the layout.
		if #items == 0 and self.FoldWhenHidden then
			self:SetDock("ignore")
		else
			self:SetDock(false)
		end
	end
	XContextWindow.Open(self)
end

DefineClass.PDAPopupHost = {
	__parents = { "XWindow" }
}

DefineClass.PDAQuestsTabButtonClass = {
	__parents = { "XButton" },
	properties = {
		{id = "Text", editor = "text", translate = true},
		{id = "Image", editor = "ui_image"},
	}
}

--- Opens the PDAQuestsTabButtonClass window.
-- This function is called when the PDAQuestsTabButtonClass is opened.
-- It sets the image and text of the button to the values specified in the class properties.
-- @function PDAQuestsTabButtonClass:Open
-- @return nil
function PDAQuestsTabButtonClass:Open()
	XButton.Open(self)
	self.idImage:SetImage(self.Image)
	self.idText:SetText(self.Text)
end

--- Sets the enabled state of the PDAQuestsTabButtonClass.
-- When the button is disabled, the image is desaturated and the text is made transparent.
-- @function PDAQuestsTabButtonClass:SetEnabled
-- @param enabled boolean - true to enable the button, false to disable it
-- @return nil
function PDAQuestsTabButtonClass:SetEnabled(enabled)
	self.idImage:SetDesaturation(enabled and 0 or 255)
	self.idImage:SetTransparency(enabled and 0 or 120)
	self.idText:SetTransparency(enabled and 0 or 120)
	XButton.SetEnabled(self, enabled)
end

--- Sets the selected state of the PDAQuestsTabButtonClass.
-- When the button is selected, the background is visible, the image column is set to 2, and the text style is set to "PDAQuests_TabSelected".
-- When the button is not selected, the background is hidden, the image column is set to 1, and the text style is set to "PDAQuests_TabLabel".
-- The function also sets the visibility of the left and right separators based on the button's position in the list of buttons.
-- @function PDAQuestsTabButtonClass:SetSelected
-- @param selected boolean - true to set the button as selected, false to set it as not selected
-- @param myIdx number - the index of the current button in the list of buttons
-- @param selectedIdx number - the index of the currently selected button in the list of buttons
-- @return nil
function PDAQuestsTabButtonClass:SetSelected(selected, myIdx, selectedIdx)
	self.idBackground:SetVisible(selected)
	self.idImage:SetColumn(selected and 2 or 1)
	self.idText:SetTextStyle(selected and "PDAQuests_TabSelected" or "PDAQuests_TabLabel")
	self:SetDrawOnTop(selected)
	
	if self.idLeftSep then self.idLeftSep:SetVisible(myIdx == 1 and selectedIdx ~= myIdx - 1 and not selected) end
	if self.idRightSep then self.idRightSep:SetVisible(selectedIdx ~= myIdx + 1 and not selected) end
end

DefineClass.PDALoadingBar = {
	__parents = { "ZuluModalDialog" },
	Id = "idLoadingBar"
}

--- Updates the animation of the loading bar.
-- @function PDALoadingBar:UpdateAnim
-- @param percent number - the percentage of the loading bar to update, from 0 to 1000
-- @return nil
function PDALoadingBar:UpdateAnim(percent)
	local bar = self.idBar
	if not bar then return end
	local totalTicks = #bar
	local currentTick = MulDivRound(percent, totalTicks, 1000)
	bar:Update(currentTick)
end

if FirstLoad then
	g_PDALoadingFlavor = true
end

--- Checks if the PDA loading animation is currently active.
-- @function PDAClass:IsPDALoadingAnim
-- @return boolean - true if the PDA loading animation is active, false otherwise
function PDAClass:IsPDALoadingAnim()
	local popupHost = self:ResolveId("idDisplayPopupHost")
	if popupHost.idLoadingBar then
		return true
	end
	return pdaDiag:GetThread("loading_bar")
end

--- Starts the PDA loading animation and displays a loading bar.
-- @function PDAClass:StartPDALoading
-- @param callback function|string - An optional callback function to be executed when the loading is complete. If set to "inline", the callback will be executed immediately.
-- @param text string - An optional text to be displayed in the loading bar.
-- @return nil
function PDAClass:StartPDALoading(callback, text)
	if not g_PDALoadingFlavor then
		if callback and callback ~= "inline" then callback() end
		return
	end

	local popupHost = self:ResolveId("idDisplayPopupHost")
	if not popupHost then return end

	local loadingBar = XTemplateSpawn("PDALoadingBar", popupHost)
	loadingBar.idText:SetText(text or T(465707401297, "LOADING"))
	loadingBar:Open()
	
	local diod = self.idDiode

	loadingBar.OnDelete = function()
		diod:SetAnimate(false)
	end

	local func = function()
		local totalTime = 500 -- ms
		local increment = 10 -- animation regularity.
		local currentTime = 0
		loadingBar:UpdateAnim(0)
		diod:SetAnimate(true)
		diod:SetFPS(6)
		while currentTime < totalTime do
			Sleep(increment)
			currentTime = currentTime + increment
			loadingBar:UpdateAnim(MulDivRound(currentTime, 1000, totalTime))
		end
		diod:SetAnimate(false)
		
		loadingBar:UpdateAnim(1000)
		if loadingBar.window_state ~= "destroying" then
			loadingBar:Close()
			if callback and callback ~= "inline" then callback() end
		end
	end
	
	if callback == "inline" then
		func()
	else
		self:CreateThread("loading_bar", func)
	end
end

DefineClass.PDANotesClass = {
	__parents = { "XDialog" }
}

--- Opens the PDA notes dialog.
-- This function is called when the PDA notes dialog is opened.
-- It sets the mode of the sub-content based on the dialog mode parameter.
-- @function PDANotesClass:Open
-- @return nil
function PDANotesClass:Open()
	XDialog.Open(self)
	
	local subTab = false
	local mode_param = GetDialogModeParam(self.parent) or GetDialogModeParam(GetDialog("PDADialog")) or GetDialog("PDADialog").context
	if mode_param and mode_param.sub_tab then
		self.idSubContent:SetMode(mode_param.sub_tab)
	end
end

local function lClosePDADialog()
	local pda = GetDialog("PDADialog")
	if pda then
		pda:Close("force")
	end
end

--[[OnMsg.OpenSatelliteView = lClosePDADialog
OnMsg.CloseSatelliteView = lClosePDADialog]]
OnMsg.CombatStart = lClosePDADialog

web_banner_image_template = "UI/PDA/imp_banner_"
PDAActiveWebBanners = {
	{ Id = "PDABrowserMortuary", Image = web_banner_image_template .. "23" },
	{ Id = "PDABrowserSunCola", Image = web_banner_image_template .. "24" },
	{ Id = "PDABrowserAskThieves", Image = web_banner_image_template .. "22" },
	{ Id = "PDABrowserBobbyRay", Image = web_banner_image_template .. "21" },
}
messenger_banner_image_template = "UI/PDA/Chat/T_Call_Ad_"
PDAActiveMessengerBanners = {
	{ Id = "Error", Image = messenger_banner_image_template .. "01", mode = "page_error", mode_param = "404" },
	{ Id = "IMP", Image = messenger_banner_image_template .. "03", mode = "imp", },
	{ Id = "PDABrowserSunCola", Image = messenger_banner_image_template .. "04", mode = "banner_page", mode_param = "PDABrowserSunCola"},
	{ Id = "PDABrowserMortuary", Image = messenger_banner_image_template .. "05", mode = "banner_page", mode_param = "PDABrowserMortuary"},
	{ Id = "PDABrowserAskThieves", Image = messenger_banner_image_template .. "06", mode = "banner_page", mode_param = "PDABrowserAskThieves"},
	{ Id = "PDABrowserBobbyRay", Image = messenger_banner_image_template .. "07", mode = "banner_page", mode_param = "PDABrowserBobbyRay"},
}
---
--- Randomizes the active and inactive web banners displayed in the PDA.
--- This function is responsible for shuffling the lists of active and inactive web banners
--- and returning them.
---
--- @return table activeBanners The list of active web banners
--- @return table inactiveBanners The list of inactive web banners
---
function RandomizeBanners()
	local rand = BraidRandomCreate(AsyncRand(99999999))
	local activeBanners = PDAActiveWebBanners
	local inactiveBanners = {}
	
	for i=1,20 do
		local intAppend = i
		if i < 10 then intAppend = "0" .. i end
		table.insert(inactiveBanners, { Id = "PDABrowserError", Image = web_banner_image_template .. intAppend})
	end
	
	table.shuffle(inactiveBanners, rand())
	table.shuffle(activeBanners, rand())
	
	return activeBanners, inactiveBanners
end

---
--- Returns a random active messenger banner from the list of active messenger banners.
---
--- @return table A random active messenger banner from the list of active messenger banners.
---
function GetRandomMessengerAdBanner()
	return table.rand(PDAActiveMessengerBanners)
end

---
--- Returns the PDA browser dialog.
---
--- @return table The PDA browser dialog.
---
function GetPDABrowserDialog()
	return GetDialog("PDADialog").idApplicationContent[1]
end

---
--- Checks if the given link has been visited in the link aggregator.
---
--- @param link_aggregator table The link aggregator containing the visited links.
--- @param link string The link to check.
--- @return boolean true if the link has been visited, false otherwise.
---
function HyperlinkVisited(link_aggregator, link)
	return link_aggregator.clicked_links[link]
end

---
--- Marks a hyperlink as visited in the given link aggregator.
---
--- @param link_aggregator table The link aggregator containing the visited links.
--- @param link string The link to mark as visited.
---
function VisitHyperlink(link_aggregator, link)
	link_aggregator.clicked_links[link] = true
end

---
--- Resets the visited hyperlinks in the given link aggregator.
---
--- @param link_aggregator table The link aggregator containing the visited links.
---
function ResetVisitedHyperlinks(link_aggregator)
	link_aggregator.clicked_links = {}
end

---
--- Docks the specified browser tab.
---
--- @param tab string The browser tab to dock.
---
function DockBrowserTab(tab)
	SetDockBrowserTab(tab, false)
end

---
--- Undocks the specified browser tab.
---
--- @param tab string The browser tab to undock.
---
function UndockBrowserTab(tab)
	SetDockBrowserTab(tab, true)
end

---
--- Sets the docked state of the specified browser tab.
---
--- @param tab string The browser tab to set the docked state for.
--- @param val boolean The new docked state for the browser tab.
---
function SetDockBrowserTab(tab, val)
	if PDABrowserTabState[tab] then
		PDABrowserTabState[tab].locked = val
	else 
		PDABrowserTabState[tab] = { locked = val }
	end
end

---
--- Clears the volatile browser tabs in the PDA UI.
---
--- This function undocks the "banner_page", "page_error", and "bobby_ray_shop" browser tabs, if the "bobby_ray_shop" tab is not unlocked.
---
--- @function ClearVolatileBrowserTabs
--- @return nil
function ClearVolatileBrowserTabs()
	UndockBrowserTab("banner_page")
	UndockBrowserTab("page_error")
	if not BobbyRayShopIsUnlocked() then UndockBrowserTab("bobby_ray_shop") end
end

---
--- Enables the header button in the PDA UI.
---
--- @param self table The PDA UI object.
---
function PDAImpHeaderEnable(self)
	local header_button = GetDialog(self):ResolveId("idHeader"):ResolveId("idLeftLinks"):ResolveId(self:GetProperty("HeaderButtonId"))
	header_button:ResolveId("idLink"):SetTextStyle("PDAIMPContentTitleSelected")
end

---
--- Disables the header button in the PDA UI.
---
--- @param self table The PDA UI object.
---
function PDAImpHeaderDisable(self)
	local header_button = GetDialog(self):ResolveId("idHeader"):ResolveId("idLeftLinks"):ResolveId(self:GetProperty("HeaderButtonId"))
	header_button:ResolveId("idLink"):SetTextStyle("PDAIMPContentTitleActive")
end