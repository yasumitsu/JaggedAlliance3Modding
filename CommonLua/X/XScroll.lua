DefineClass.XScroll = {
	__parents = { "XPropControl" },
	properties = {
		{ category = "Scroll", id = "Min", editor = "number", default = 0 },
		{ category = "Scroll", id = "Max", editor = "number", default = 100 },
		{ category = "Scroll", id = "Scroll", editor = "number", default = 0, dont_save = true },
		{ category = "Scroll", id = "PageSize", editor = "number", default = 1 },
		{ category = "Scroll", id = "StepSize", editor = "number", default = 1 },
		{ category = "Scroll", id = "FullPageAtEnd", editor = "bool", default = false },
		{ category = "Scroll", id = "SnapToItems", editor = "bool", default = false },
		{ category = "Scroll", id = "AutoHide", editor = "bool", default = false, },
		{ category = "Scroll", id = "Horizontal", name = "Horizontal", editor = "bool", default = false, },
		{ category = "Scroll", id = "ThrottleTime", name = "Throttle time", editor = "number", default = 0, help = "Use -1 to update the value once per frame"},
		{ category = "Scroll", id = "ModifyObj", name = "Call ObjModified", editor = "bool", default = false, },
	},
	FoldWhenHidden = true,
	set_prop_thread = false,
}

---
--- Sets the scroll range of the XScroll control.
---
--- @param min number The minimum value of the scroll range.
--- @param max number The maximum value of the scroll range.
function XScroll:SetScrollRange(min, max)
	max = Max(max, min)
	if self.Min == min and self.Max == max then return end
	self.Min = min
	self.Max = max
	self:SetScroll(self.Scroll)
end

---
--- Sets the step size of the XScroll control.
---
--- @param step number The new step size for the scroll control. Must be at least 1.
function XScroll:SetStepSize(step)
	self.StepSize = Max(1, step)
end

---
--- Scrolls the target control into view of the XScroll control.
---
--- This function is used to ensure that the target control is fully visible within the
--- scrollable area of the XScroll control. It adjusts the scroll position as needed
--- to bring the target control into view.
---
--- @function XScroll:ScrollIntoView
--- @return nil
function XScroll:ScrollIntoView()
end

---
--- Determines whether the XScroll control should be visible based on the size of the target control.
---
--- If the AutoHide property is enabled, this function checks if the target control's content box
--- is larger than the target control's size. If the content box is larger, the XScroll control
--- should be visible to allow scrolling. Otherwise, the XScroll control should be hidden.
---
--- @return boolean Whether the XScroll control should be visible
function XScroll:ShouldShow()
	if not self.AutoHide then return true end
	local target = self:ResolveId(self.Target)
	assert(target, "What is this scroll scrolling if it has no target?")
	if not target then return end
	if self.Horizontal then
		return target.scroll_range_x - target.content_box:sizex() > 0
	end
	return target.scroll_range_y - target.content_box:sizey() > 0
end

---
--- Snaps the scroll position to the nearest step size.
---
--- This function ensures that the scroll position is a multiple of the step size, by
--- adding the remainder of the current position divided by the step size to the current
--- position. This aligns the scroll position to the nearest step.
---
--- The function also clamps the scroll position to the valid range, ensuring it does not
--- exceed the minimum or maximum values.
---
--- @param current number The current scroll position.
--- @return number The snapped scroll position.
function XScroll:SnapScrollPosition(current)
	current = current + (self.Min - current) % self.StepSize
	
	local scroll_end = self.Max - (self.FullPageAtEnd and self.PageSize or 0)
	return Clamp(current, self.Min, scroll_end)
end

---
--- Sets the scroll position of the XScroll control.
---
--- This function updates the scroll position of the XScroll control to the specified `current` value.
--- If the new scroll position is different from the current position, the function will update the
--- `Scroll` property and call `Invalidate()` to trigger a redraw of the control.
---
--- @param current number The new scroll position to set.
--- @return boolean Whether the scroll position was updated.
function XScroll:DoSetScroll(current)
	if self.Scroll ~= current then
		self.Scroll = current
		self:Invalidate()
		return true
	end
end

---
--- Sets the scroll position of the XScroll control.
---
--- This function updates the scroll position of the XScroll control to the specified `current` value.
--- If the new scroll position is different from the current position, the function will update the
--- `Scroll` property and call `Invalidate()` to trigger a redraw of the control.
---
--- @param current number The new scroll position to set.
--- @return boolean Whether the scroll position was updated.
function XScroll:SetScroll(current)
	if self.AutoHide then
		self:SetVisible(self:ShouldShow())
	end
	return self:DoSetScroll(self:SnapScrollPosition(current))
end

---
--- Sets the page size of the XScroll control.
---
--- This function updates the page size of the XScroll control to the specified `page_size` value.
--- The page size is snapped to a multiple of the step size, ensuring that the scroll position
--- is always aligned to the nearest step. If the new page size is different from the current
--- page size, the function will update the `PageSize` property and call `SetScroll()` to
--- update the scroll position and trigger a redraw of the control.
---
--- @param page_size number The new page size to set.
--- @return void
function XScroll:SetPageSize(page_size)
	page_size = page_size - page_size % self.StepSize
	local new_size = Max(page_size, 1)
	if self.PageSize == new_size then return end
	self.PageSize = new_size
	self:SetScroll(self.Scroll)
end

---
--- Scrolls the XScroll control to the specified `current` position.
---
--- If the scroll position is updated, this function will also notify the target object
--- (if set) by calling its `OnScrollTo` method, and update the bound property (if set)
--- with the new scroll position.
---
--- @param current number The new scroll position to set.
--- @return boolean Whether the scroll position was updated.
function XScroll:ScrollTo(current)
	if self:SetScroll(current) then
		local target = self:ResolveId(self.Target)
		if target then
			target:OnScrollTo(self.Scroll, self)
		end
		if self.BindTo ~= "" then
			local obj = ResolvePropObj(self.context)
			if self.ThrottleTime == 0 then
				SetProperty(obj, self.BindTo, self.Scroll)
				if self.ModifyObj then
					ObjModified(obj)
				end
			elseif not IsValidThread(self.set_prop_thread) then
				self.set_prop_thread = CreateRealTimeThread(function(self)
					repeat
						local value = self.Scroll
						SetProperty(obj, self.BindTo, self.Scroll)
						if self.ModifyObj then
							ObjModified(obj)
						end
						if self.ThrottleTime == -1 then
							WaitNextFrame()
						else
							Sleep(self.ThrottleTime)
						end
					until value == self.Scroll
					self.set_prop_thread = false
				end, self)
			else
			end
		end
		return true
	end
end

local eval = prop_eval

---
--- Called when a property of the XScroll control is updated.
---
--- This function is responsible for updating the step size and scroll range of the control
--- based on the provided property metadata. It also scrolls the control to the new value
--- if the property value is a number.
---
--- @param context table The context object for the property evaluation.
--- @param prop_meta table The metadata for the updated property.
--- @param value any The new value of the property.
---
function XScroll:OnPropUpdate(context, prop_meta, value)
	if prop_meta then
		self:SetStepSize(eval(prop_meta.step, context, prop_meta) or self.StepSize)
		self:SetScrollRange(eval(prop_meta.min, context, prop_meta) or self.Min, eval(prop_meta.max, context, prop_meta) or self.Max)
	end
	assert(type(value) == "number")
	if type(value) == "number" then
		self:ScrollTo(value)
	end
end


----- XScrollControl

DefineClass.XScrollControl = {
	__parents = { "XScroll" },
	properties = {
		{ category = "Scroll", id = "MinThumbSize", editor = "number", default = 15 },
	},
	current_pos = false,
	current_offset = false,
	ChildrenHandleMouse = false,
	touch = false
}


---
--- Starts scrolling the XScrollControl.
---
--- This function is called when the user starts scrolling the control by clicking and dragging the mouse.
--- It calculates the initial position of the scroll thumb based on the mouse position and sets the `current_pos`
--- and `current_offset` properties accordingly. The function returns `true` if scrolling can be started,
--- `false` otherwise (e.g. if the control is disabled).
---
--- @param pt table The initial mouse position.
--- @return boolean Whether scrolling was successfully started.
---
function XScrollControl:StartScroll(pt)
	if not self.enabled then return false end
	local pos = self.Horizontal and pt:x() - self.content_box:minx() or pt:y() - self.content_box:miny()
	local min, max = self:GetThumbRange()
	self.current_pos = min
	self.current_offset = pos - self.current_pos
	if self.current_offset < 0 or self.current_offset > max - min then
		self.current_offset = (max - min) / 2
	end
	return true
end

---
--- Starts scrolling the XScrollControl when the user clicks and drags the mouse.
---
--- This function is called when the user starts scrolling the control by clicking and dragging the mouse.
--- It calculates the initial position of the scroll thumb based on the mouse position and sets the `current_pos`
--- and `current_offset` properties accordingly. The function returns `true` if scrolling can be started,
--- `false` otherwise (e.g. if the control is disabled).
---
--- @param pt table The initial mouse position.
--- @return boolean Whether scrolling was successfully started.
---
function XScrollControl:OnMouseButtonDown(pt, button)
	if button == "L" then
		if self:StartScroll(pt) then
			if not self.touch then
				self.desktop:SetMouseCapture(self)
			end
			self:OnMousePos(pt)
		end
		return "break"
	end
end

---
--- Updates the current scroll position based on the mouse position.
---
--- This function is called when the user drags the mouse while scrolling. It calculates the new scroll position
--- based on the mouse position and the current scroll offset, and updates the `current_pos` property accordingly.
--- The function then calls `ScrollTo()` to update the scroll position of the control.
---
--- @param pt table The current mouse position.
--- @return string Always returns "break" to indicate that the event has been handled.
---
function XScrollControl:OnMousePos(pt)
	if not self.current_pos then return end
	local pos, size
	if self.Horizontal then
		pos = pt:x() - self.content_box:minx() - self.current_offset
		size = Max(1, self.content_box:sizex() - self:GetThumbSize())
	else
		pos = pt:y() - self.content_box:miny() - self.current_offset
		size = Max(1, self.content_box:sizey() - self:GetThumbSize())
	end
	pos = Clamp(pos, 0, size)
	self.current_pos = pos
	self:ScrollTo(self.Min + pos * Max(1, self.Max - self.Min - (self.FullPageAtEnd and self.PageSize or 0) + 1) / size)
	return "break"
end

---
--- Handles the mouse button up event during scrolling.
---
--- This function is called when the user releases the mouse button after scrolling. It updates the current scroll position based on the final mouse position and releases the mouse capture.
---
--- @param pt table The final mouse position.
--- @param button string The mouse button that was released ("L" for left button).
--- @return string Always returns "break" to indicate that the event has been handled.
---
function XScrollControl:OnMouseButtonUp(pt, button)
	if button == "L" then
		self:OnMousePos(pt)
		self.desktop:SetMouseCapture()
		return "break"
	end
end

---
--- Releases the mouse capture and resets the current scroll position when the user loses the mouse capture.
---
--- This function is called when the user loses the mouse capture, for example when the mouse leaves the control or the user releases the mouse button. It sets the `current_pos` and `current_offset` properties to `false` to indicate that there is no longer an active scroll operation.
---
--- @return nil
---
function XScrollControl:OnCaptureLost()
	self.current_pos = false
	self.current_offset = false
end

---
--- Handles the start of a touch event on the scroll control.
---
--- This function is called when the user starts touching the scroll control. It sets the `touch` flag to indicate that a touch event is in progress, clears the keyboard focus, and calls the `OnMouseButtonDown()` function to handle the start of the scroll operation.
---
--- @param id number The unique identifier for the touch event.
--- @param pt table The initial touch position.
--- @param touch table The touch event object.
--- @return string Returns "capture" to indicate that the touch event should be captured by the control.
---
function XScrollControl:OnTouchBegan(id, pt, touch)
	self.touch = true
	terminal.desktop:SetKeyboardFocus(false)
	self:OnMouseButtonDown(pt, "L")
	return "capture"
end

---
--- Handles the touch move event during scrolling.
---
--- This function is called when the user moves their finger on the touch screen while scrolling. It calls the `OnMousePos()` function to update the current scroll position based on the new touch position.
---
--- @param id number The unique identifier for the touch event.
--- @param pt table The current touch position.
--- @param touch table The touch event object.
--- @return string Always returns "break" to indicate that the event has been handled.
---
function XScrollControl:OnTouchMoved(id, pt, touch)
	return self:OnMousePos(pt)
end

---
--- Handles the end of a touch event on the scroll control.
---
--- This function is called when the user lifts their finger from the touch screen, ending the touch event. It sets the `touch` flag to `false` to indicate that the touch event has ended, and returns `"break"` to indicate that the event has been handled.
---
--- @return string Returns `"break"` to indicate that the event has been handled.
---
function XScrollControl:OnTouchEnded()
	self.touch = false
	return "break"
end

---
--- Handles the cancellation of a touch event on the scroll control.
---
--- This function is called when a touch event is cancelled, such as when the user's finger leaves the screen during a touch event. It sets the `touch` flag to `false` to indicate that the touch event has ended, and returns `"break"` to indicate that the event has been handled.
---
--- @return string Returns `"break"` to indicate that the event has been handled.
---
function XScrollControl:OnTouchCancelled()
	self.touch = false
	return "break"
end

---
--- Calculates the size of the scroll thumb based on the size of the content area and the page size.
---
--- The thumb size is calculated as a proportion of the content area size, based on the page size relative to the total range of the scroll. The thumb size is clamped to a minimum size specified by `self.MinThumbSize`.
---
--- @return number The calculated size of the scroll thumb.
---
function XScrollControl:GetThumbSize()
	local area = self.Horizontal and self.content_box:sizex() or self.content_box:sizey()
	local page_size = area * self.PageSize / Max(1, self.Max - self.Min)
	return Clamp(page_size, self.MinThumbSize, area)
end

---
--- Calculates the range of the scroll thumb based on the size of the content area and the current scroll position.
---
--- The function first calculates the size of the scroll thumb using the `GetThumbSize()` function. It then calculates the position of the thumb within the content area based on the current scroll position. The function returns the start and end positions of the thumb within the content area.
---
--- @return number, number The start and end positions of the scroll thumb within the content area.
---
function XScrollControl:GetThumbRange()
	local thumb_size = self:GetThumbSize()
	local area = self.Horizontal and self.content_box:sizex() or self.content_box:sizey()
	local pos = self.current_pos or ((area - thumb_size) * (self.Scroll - self.Min) / Max(1, self.Max - self.Min - (self.FullPageAtEnd and self.PageSize or 0)))
	return pos, pos + thumb_size
end


----- XScrollBar

DefineClass.XScrollBar = {
	__parents = { "XScrollControl" },
	properties = {
		{ category = "Visual", id = "ScrollColor", name = "Scroll", editor = "color", default = RGBA(169, 169, 169, 255), },
		{ category = "Visual", id = "DisabledScrollColor", name = "Disabled scroll", editor = "color", default = RGBA(169, 169, 169, 96), },
	},
	FullPageAtEnd = true,
	Background = RGB(240, 240, 240),
	DisabledBackground = RGB(240, 240, 240),
}

---
--- Draws the content of the scroll bar, including the thumb.
---
--- The function first calculates the range of the scroll thumb within the content box, based on the current scroll position. It then draws a border rectangle within the content box, using the appropriate color (either the scroll color or the disabled scroll color) based on whether the scroll bar is enabled or not.
---
--- @param self XScrollBar The XScrollBar instance.
---
function XScrollBar:DrawContent()
	local content_box = self.content_box
	if self.Horizontal then
		local x1, x2 = self:GetThumbRange()
		content_box = box(content_box:minx() + x1, content_box:miny(), content_box:minx() + x2, content_box:maxy())
	else
		local y1, y2 = self:GetThumbRange()
		content_box = box(content_box:minx(), content_box:miny() + y1, content_box:maxx(), content_box:miny() + y2)
	end
	UIL.DrawBorderRect(FitBoxInBox(content_box, self.content_box), 0, 0, 0, self.enabled and self.ScrollColor or self.DisabledScrollColor)
end


----- XScrollThumb

DefineClass.XScrollThumb = {
	__parents = { "XScrollControl" },
	properties = {
		{ category = "Scroll", id = "FixedSizeThumb", name = "Fixed size thumb", editor = "bool", default = true, },
	}
}

---
--- Sets the scroll position of the XScrollThumb and moves the thumb to the new position.
---
--- This function first calls the `DoSetScroll` function of the parent `XScrollControl` class, which updates the scroll position. If the scroll position was successfully updated, this function then calls the `MoveThumb` function to move the thumb to the new position. If the scroll position was not updated, this function still calls `MoveThumb` to ensure the thumb is in the correct position.
---
--- @param self XScrollThumb The XScrollThumb instance.
--- @param scroll number The new scroll position.
--- @return boolean Whether the scroll position was successfully updated.
---
function XScrollThumb:DoSetScroll(scroll)
	if XScrollControl.DoSetScroll(self, scroll) then
		self:MoveThumb()
		return true
	end
	self:MoveThumb()
end

---
--- Lays out the XScrollThumb and moves the thumb to the new position.
---
--- This function first calls the `Layout` function of the parent `XScrollControl` class, which updates the layout of the control. It then calls the `MoveThumb` function to move the thumb to the new position.
---
--- @param self XScrollThumb The XScrollThumb instance.
--- @param x number The new x-coordinate of the control.
--- @param y number The new y-coordinate of the control.
--- @param width number The new width of the control.
--- @param height number The new height of the control.
---
function XScrollThumb:Layout(x, y, width, height)
	XScrollControl.Layout(self, x, y, width, height)
	self:MoveThumb()
end

---
--- Gets the size of the XScrollThumb.
---
--- If `FixedSizeThumb` is true, this function returns the fixed size of the thumb, either the width or height depending on the orientation of the scroll. Otherwise, it calls the `GetThumbSize` function of the parent `XScrollControl` class to get the size of the thumb.
---
--- @param self XScrollThumb The XScrollThumb instance.
--- @return number The size of the thumb.
---
function XScrollThumb:GetThumbSize()
	if self.FixedSizeThumb then
		return self.Horizontal and self.idThumb.measure_width or self.idThumb.measure_height
	else
		return XScrollControl.GetThumbSize(self)
	end
end

---
--- Moves the XScrollThumb to the new position based on the current scroll range.
---
--- This function first checks if the `idThumb` member exists. If it does not, the function returns without doing anything.
---
--- The function then calculates the new position of the thumb based on the current scroll range. If the scroll is horizontal, the thumb is positioned horizontally between the minimum and maximum scroll range. If the scroll is vertical, the thumb is positioned vertically between the minimum and maximum scroll range.
---
--- Finally, the function sets the layout space of the `idThumb` member to the new position and size.
---
--- @param self XScrollThumb The XScrollThumb instance.
---
function XScrollThumb:MoveThumb()
	if not self:HasMember("idThumb") then
		return
	end
	local x1, y1, x2, y2 = self.content_box:xyxy()
	local min, max = self:GetThumbRange()
	self.idThumb:SetDock("ignore")
	if self.Horizontal then
		self.idThumb:SetLayoutSpace(x1 + min, y1, max - min, y2 - y1)
	else
		self.idThumb:SetLayoutSpace(x1, y1 + min, x2 - x1, max - min)
	end
end


----- XSleekScroll

DefineClass.XSleekScroll = {
	__parents = { "XScrollThumb" },
	FullPageAtEnd = true,
	FixedSizeThumb = false,
	Background = RGB(240, 240, 240),
	ThumbScale = point(500, 500)
}

---
--- Initializes an XSleekScroll instance.
---
--- This function creates a new XFrame instance with the following properties:
--- - Id: "idThumb"
--- - Dock: "ignore"
--- - Image: "CommonAssets/UI/round-frame-20.tga"
--- - ImageScale: self.ThumbScale
--- - FrameBox: box(9, 9, 9, 9)
--- - Background: RGBA(169, 169, 169, 255)
--- - DisabledBackground: RGBA(169, 169, 169, 96)
---
--- The function then calls the `SetHorizontal` method with the `Horizontal` property of the XSleekScroll instance.
---
--- @param self XSleekScroll The XSleekScroll instance.
---
function XSleekScroll:Init()
	XFrame:new({
		Id = "idThumb",
		Dock = "ignore",
		Image = "CommonAssets/UI/round-frame-20.tga",
		ImageScale = self.ThumbScale,
		FrameBox = box(9, 9, 9, 9),
		Background = RGBA(169, 169, 169, 255),
		DisabledBackground = RGBA(169, 169, 169, 96),
	}, self)
	self:SetHorizontal(self.Horizontal)
end

---
--- Sets the orientation of the XSleekScroll instance.
---
--- This function sets the `Horizontal` property of the XSleekScroll instance, which determines whether the scroll is horizontal or vertical. It also sets the `MinWidth`, `MaxWidth`, `MinHeight`, and `MaxHeight` properties based on the orientation, and then calls `InvalidateMeasure()` and `InvalidateLayout()` to update the layout.
---
--- @param self XSleekScroll The XSleekScroll instance.
--- @param horizontal boolean True if the scroll should be horizontal, false if it should be vertical.
---
function XSleekScroll:SetHorizontal(horizontal)
	self.Horizontal = horizontal
	self.MinWidth = horizontal and 0 or 7
	self.MaxWidth = horizontal and 1000000 or 7
	self.MinHeight = horizontal and 7 or 0
	self.MaxHeight = horizontal and 7 or 1000000
	self:InvalidateMeasure()
	self:InvalidateLayout()
end

----- XRangeScroll

DefineClass.XRangeScroll = {
	__parents = { "XScrollThumb" },
	properties = {
		{ category = "Scroll", id = "Scroll", editor = "range", default = range(0, 0), dont_save = true, },
		{ category = "Scroll", id = "left_arrow_image", name = "Left Arrow", editor = "ui_image", default = "CommonAssets/UI/Controls/RangeSlider/arrowleft.tga", },
		{ category = "Scroll", id = "right_arrow_image", name = "Right Arrow", editor = "ui_image", default = "CommonAssets/UI/Controls/RangeSlider/arrowright.tga", },
		{ category = "Scroll", id = "up_arrow_image", name = "Up Arrow", editor = "ui_image", default = "CommonAssets/UI/Controls/RangeSlider/arrowup.tga", },
		{ category = "Scroll", id = "down_arrow_image", name = "Down Arrow", editor = "ui_image", default = "CommonAssets/UI/Controls/RangeSlider/arrowdown.tga", },
		{ category = "Scroll", id = "ThumbBackground", editor = "color", default = RGBA(169, 169, 169, 255), },
		{ category = "Scroll", id = "ThumbRolloverBackground", editor = "color", default = RGBA(180, 180, 180, 255), },
		{ category = "Scroll", id = "ThumbPressedBackground", editor = "color", default = RGBA(200, 200, 200, 255), },
		{ category = "Scroll", id = "horizontal_cursor", name = "Horizontal Cursor", editor = "ui_image", default = "CommonAssets/UI/Controls/resize03.tga", },
		{ category = "Scroll", id = "vertical_cursor", name = "Vertical Cursor", editor = "ui_image", default = "CommonAssets/UI/Controls/resize04.tga", },
		{ category = "Scroll", id = "ScrollColor", name = "Scroll", editor = "color", default = RGBA(169, 169, 169, 255), },
		{ category = "Scroll", id = "DisabledScrollColor", name = "Disabled scroll", editor = "color", default = RGBA(169, 169, 169, 96), },
	},
	Scroll = range(0, 0),
	MinThumbSize = 16,
	Background = RGB(240, 240, 240),
	ThumbScale = point(500, 500),
	mouse_in = false,
	idThumb = false,
}

---
--- Initializes a new instance of the `XRangeScroll` class.
---
--- This function creates a new `XWindow` panel and two `XFrame` instances to represent the left and right thumbs of the range scroll. It sets the initial properties of the thumbs, such as their background colors, minimum width, and image scale. It also sets the `Horizontal` property of the `XRangeScroll` instance based on the value of the `Horizontal` property.
---
--- @param self XRangeScroll The `XRangeScroll` instance to initialize.
---
function XRangeScroll:Init()
	local panel = XWindow:new({ Dock = "box" }, self)
	self.idPaddingPanel = panel
	XFrame:new({
		Id = "idThumbLeft",
		Dock = "ignore",
		ImageScale = self.ThumbScale,
		MinWidth = self.MinThumbSize * 2,
		Background = self.ThumbBackground,
		DisabledBackground = RGBA(169, 169, 169, 96),
		RolloverBackground = RGBA(0, 0, 0, 0),
	}, panel)
	XFrame:new({
		Id = "idThumbRight",
		Dock = "ignore",
		ImageScale = self.ThumbScale,
		MinWidth = self.MinThumbSize * 2,
		Background = self.ThumbBackground,
		DisabledBackground = RGBA(169, 169, 169, 96),
	}, panel)
	self.idThumb = self.idThumbLeft
	self:SetHorizontal(self.Horizontal)
end

---
--- Called when the mouse enters the XRangeScroll control.
---
--- This function sets the `mouse_in` property to `true` and then calls the `OnMouseEnter` function of the parent `XScrollThumb` class.
---
--- @param self XRangeScroll The `XRangeScroll` instance.
--- @param ... Additional arguments passed to the parent `OnMouseEnter` function.
--- @return Any value returned by the parent `OnMouseEnter` function.
---
function XRangeScroll:OnMouseEnter(...)
	self.mouse_in = true
	return XScrollThumb.OnMouseEnter(self, ...)
end

---
--- Called when the mouse pointer moves over the XRangeScroll control.
---
--- This function is responsible for updating the background color of the closest thumb to the mouse pointer to the `ThumbRolloverBackground` color, and the background color of the other thumb to the `ThumbBackground` color. This provides visual feedback to the user about which thumb is closest to the mouse pointer.
---
--- @param self XRangeScroll The `XRangeScroll` instance.
--- @param pt table The current position of the mouse pointer.
--- @param ... Additional arguments passed to the parent `OnMousePos` function.
--- @return Any value returned by the parent `OnMousePos` function.
---
function XRangeScroll:OnMousePos(pt, ...)
	if not self.current_pos then
		local closest_thumb, second_thumb = self:GetClosestThumb(pt)
		if closest_thumb and second_thumb then
			closest_thumb:SetBackground(self.ThumbRolloverBackground)
			second_thumb:SetBackground(self.ThumbBackground)
		end
	end
	return XScrollThumb.OnMousePos(self, pt, ...)
end

---
--- Called when the mouse pointer is released over the XRangeScroll control.
---
--- This function sets the `mouse_in` property to `false` and then calls the `OnMouseLeft` function of the parent `XScrollThumb` class. If the mouse pointer is not currently over the control, it also sets the background color of the closest thumb to the `ThumbBackground` color.
---
--- @param self XRangeScroll The `XRangeScroll` instance.
--- @param pt table The current position of the mouse pointer.
--- @param ... Additional arguments passed to the parent `OnMouseLeft` function.
--- @return Any value returned by the parent `OnMouseLeft` function.
---
function XRangeScroll:OnMouseLeft(pt, ...)
	self.mouse_in = false
	if not self.current_pos then
		local closest_thumb = self:GetClosestThumb(pt)
		if closest_thumb then
			closest_thumb:SetBackground(self.ThumbBackground)
		end
	end
	return XScrollThumb.OnMouseLeft(self, pt, ...)
end

---
--- Sets the scroll position of the XRangeScroll control.
---
--- If the current scroll position is a range, the function sets the `from` and `to` values of the range.
--- If the current scroll position is a single value, the function sets the `from` and `to` values based on which thumb is currently selected.
---
--- @param self XRangeScroll The `XRangeScroll` instance.
--- @param current number|table The current scroll position, which can be a single number or a range table with `from` and `to` fields.
--- @return boolean Whether the scroll position was updated.
---
function XRangeScroll:DoSetScroll(current)
	local from, to
	if IsRange(current) then
		from, to = current.from, current.to
	else
		if self.idThumb == self.idThumbLeft then
			to = self.Scroll.to
			from = Min(current, to)
		else
			from = self.Scroll.from
			to = Max(current, from)
		end
	end
	if self.Scroll.from ~= from or self.Scroll.to ~= to then
		self.Scroll = range(from, to)
		self:InvalidateLayout()
		return true
	end
end

---
--- Snaps the scroll position to the nearest valid value.
---
--- If the current scroll position is a range, the function simply returns the current value.
--- If the current scroll position is a single value, the function calls the `SnapScrollPosition` function of the parent `XScrollThumb` class to snap the value to the nearest valid position.
---
--- @param self XRangeScroll The `XRangeScroll` instance.
--- @param current number|table The current scroll position, which can be a single number or a range table with `from` and `to` fields.
--- @return number|table The snapped scroll position.
---
function XRangeScroll:SnapScrollPosition(current)
	if IsRange(current) then
		return current
	end
	return XScrollThumb.SnapScrollPosition(self, current)
end

---
--- Sets the orientation of the `XRangeScroll` control.
---
--- This function sets the orientation of the `XRangeScroll` control to either horizontal or vertical. It updates the minimum and maximum width and height of the control, sets the padding and image of the thumb controls, and sets the mouse cursor based on the orientation.
---
--- @param self XRangeScroll The `XRangeScroll` instance.
--- @param horizontal boolean Whether the orientation should be horizontal (true) or vertical (false).
---
function XRangeScroll:SetHorizontal(horizontal)
	self.Horizontal = horizontal
	self.MinWidth = horizontal and 0 or 7
	self.MaxWidth = horizontal and 1000000 or 7
	self.MinHeight = horizontal and 7 or 0
	self.MaxHeight = horizontal and 7 or 1000000
	if horizontal then
		self.idPaddingPanel:SetPadding(box(self.MinThumbSize, 0, self.MinThumbSize, 0))
		self.idThumbLeft:SetImage(self.left_arrow_image)
		self.idThumbRight:SetImage(self.right_arrow_image)
		self:SetMouseCursor(self.horizontal_cursor)
	else
		self.idPaddingPanel:SetPadding(box(0, self.MinThumbSize, 0, self.MinThumbSize))
		self.idThumbLeft:SetImage(self.down_arrow_image)
		self.idThumbRight:SetImage(self.up_arrow_image)
		self:SetMouseCursor(self.vertical_cursor)
	end
	self:InvalidateMeasure()
	self:InvalidateLayout()
end

---
--- Gets the range of the thumb based on the current scroll position.
---
--- If the current thumb is the left thumb, the function calculates the position of the left thumb based on the `Scroll.from` value. If the current thumb is the right thumb, the function calculates the position of the right thumb based on the `Scroll.to` value.
---
--- The function returns the starting position and the ending position of the thumb within the scroll area.
---
--- @param self XRangeScroll The `XRangeScroll` instance.
--- @return number, number The starting and ending position of the thumb.
---
function XRangeScroll:GetThumbRange()
	local thumb_size = self:GetThumbSize()
	local scroll
	if self.idThumb == self.idThumbLeft then
		scroll = self.Scroll.from
	else
		scroll = self.Scroll.to
	end
	local area = self.Horizontal and self.content_box:sizex() or self.content_box:sizey()
	local pos = self.current_pos or ((area - thumb_size) * (scroll - self.Min) / Max(1, self.Max - self.Min - (self.FullPageAtEnd and self.PageSize or 0)))
	return pos, pos + thumb_size
end

---
--- Gets the thumb that is closest to the given point.
---
--- If the point is to the left of the midpoint between the two thumbs, the left thumb is returned as the closest thumb. Otherwise, the right thumb is returned as the closest thumb.
---
--- @param self XRangeScroll The `XRangeScroll` instance.
--- @param pt Vector2 The point to check against the thumb positions.
--- @return XControl, XControl The closest thumb and the other thumb.
---
function XRangeScroll:GetClosestThumb(pt)
	if not self.enabled then return end
	local cboxl, cboxr = self.idThumbLeft.content_box, self.idThumbRight.content_box
	local mid_point
	if self.Horizontal then
		mid_point = cboxl:maxx() + (cboxr:minx() - cboxl:maxx()) / 2
	else
		mid_point = cboxl:maxy() + (cboxr:miny() - cboxl:maxy()) / 2
	end
	if pt:x() < mid_point then
		return self.idThumbLeft, self.idThumbRight
	else
		return self.idThumbRight, self.idThumbLeft
	end
end

---
--- Starts the scroll operation by determining the closest thumb to the given point.
---
--- If the closest thumb is found, it sets the current thumb to the closest thumb and updates its background to the `ThumbPressedBackground`. It then calls the `StartScroll` function of the `XScrollThumb` class to handle the scroll operation.
---
--- @param self XRangeScroll The `XRangeScroll` instance.
--- @param pt Vector2 The point to check against the thumb positions.
--- @return boolean Whether the scroll operation was started successfully.
---
function XRangeScroll:StartScroll(pt)
	local closest_thumb = self:GetClosestThumb(pt)
	if not closest_thumb then return end
	self.idThumb = closest_thumb
	closest_thumb:SetBackground(self.ThumbPressedBackground)
	return XScrollThumb.StartScroll(self, pt)
end

---
--- Called when the capture of the XRangeScroll is lost.
---
--- Resets the background of the left and right thumbs to the `ThumbBackground`, and then calls the `OnCaptureLost` function of the `XScrollThumb` class.
---
--- @param self XRangeScroll The `XRangeScroll` instance.
--- @return boolean Whether the capture lost operation was successful.
---
function XRangeScroll:OnCaptureLost()
	self.idThumbLeft:SetBackground(self.ThumbBackground)
	self.idThumbRight:SetBackground(self.ThumbBackground)
	return XScrollThumb.OnCaptureLost(self)
end

---
--- Moves the thumbs of the XRangeScroll control to their appropriate positions based on the current scroll values.
---
--- The function calculates the position of the left and right thumbs based on the current scroll values and the size of the control's content area. It then sets the layout space of the left and right thumb controls to the calculated positions.
---
--- @param self XRangeScroll The XRangeScroll instance.
---
function XRangeScroll:MoveThumb()
	local x1, y1, x2, y2 = self.content_box:xyxy()
	local thumb_size = self:GetThumbSize()
	local area = self.Horizontal and self.content_box:sizex() or self.content_box:sizey()
	local posl = (area - thumb_size) * (self.Scroll.from - self.Min) / Max(1, self.Max - self.Min - (self.FullPageAtEnd and self.PageSize or 0))
	local posr = (area - thumb_size) * (self.Scroll.to - self.Min) / Max(1, self.Max - self.Min - (self.FullPageAtEnd and self.PageSize or 0))
	if self.Horizontal then
		self.idThumbLeft:SetLayoutSpace(x1 + posl, y1, thumb_size, y2 - y1)
		self.idThumbRight:SetLayoutSpace(x1 + posr, y1, thumb_size, y2 - y1)
	else
		self.idThumbLeft:SetLayoutSpace(x1, y1 + posl, x2 - x1, thumb_size)
		self.idThumbRight:SetLayoutSpace(x1, y1 + posr, x2 - x1, thumb_size)
	end
end

--- Draws the content of the XRangeScroll control, including the left and right thumbs.
---
--- This function first calls the `DrawContent` function of the `XScrollThumb` class to draw the content of the thumbs. It then calculates the position of the fill box between the left and right thumbs, and draws a border rectangle around it using the `UIL.DrawBorderRect` function. The color of the border rectangle is determined by the `ScrollColor` or `DisabledScrollColor` property, depending on whether the control is enabled or not.
---
--- @param self XRangeScroll The `XRangeScroll` instance.
function XRangeScroll:DrawContent()
	XScrollThumb.DrawContent(self)
	local cboxl, cboxr = self.idThumbLeft.content_box, self.idThumbRight.content_box
	local minx, miny, maxx, maxy
	if self.Horizontal then
		minx, miny = cboxl:minx() + (cboxl:maxx() - cboxl:minx()) / 2, cboxl:miny()
		maxx, maxy = cboxr:minx() + (cboxr:maxx() - cboxr:minx()) / 2, cboxr:maxy()
	else
		minx, miny = cboxl:minx(), cboxl:miny() + (cboxl:maxy() - cboxl:miny()) / 2
		maxx, maxy = cboxr:maxx(), cboxr:miny() + (cboxr:maxy() - cboxr:miny()) / 2
	end
	local fill_box = box(minx, miny, maxx, maxy)
	UIL.DrawBorderRect(FitBoxInBox(fill_box, self.content_box), 0, 0, 0, self.enabled and self.ScrollColor or self.DisabledScrollColor)
end

----- XScrollArea

DefineClass.XScrollArea = {
	__parents = { "XControl" },
	properties = {
		{ category = "Scroll", id = "OffsetX", editor = "number", default = 0, dont_save = true, },
		{ category = "Scroll", id = "OffsetY", editor = "number", default = 0, dont_save = true, },
		{ category = "Scroll", id = "MinHSize", name = "Min horizontal size", editor = "bool", default = true, },
		{ category = "Scroll", id = "MinVSize", name = "Min vertical size", editor = "bool", default = true, },
		{ category = "Scroll", id = "HScroll", editor = "text", default = "", },
		{ category = "Scroll", id = "VScroll", editor = "text", default = "", },
		{ category = "Scroll", id = "MouseWheelStep", editor = "number", default = 80, },
		{ category = "Visual", id = "ShowPartialItems", editor = "bool", default = true, },
		{ category = "Visual", id = "ScrollInterpolationTime", editor = "number", min = 0, max = 500, slider = true, default = 0, },
		{ category = "Visual", id = "ScrollInterpolationEasing", editor = "choice", default = GetEasingIndex("Cubic in"), items = function(self) return GetEasingCombo() end, },
		{ category = "General", id = "MouseScroll", Name = "Scroll with mouse", editor = "bool", default = true, },
	},
	Clip = "parent & self",
	scroll_range_x = 0,
	scroll_range_y = 0,
	pending_scroll_into_view = false,
	pending_scroll_allow_interpolation = false,
	PendingOffsetX = 0,
	PendingOffsetY = 0,
}

--- Clears the contents of the `XScrollArea` control.
---
--- If `keep_children` is `false`, this function will delete all child controls of the `XScrollArea`. It then scrolls the control to the top-left position (0, 0) and resets the `pending_scroll_into_view` flag.
---
--- @param self XScrollArea The `XScrollArea` instance.
--- @param keep_children boolean If `true`, the child controls will not be deleted.
function XScrollArea:Clear(keep_children)
	if not keep_children then
		self:DeleteChildren()
	end
	self:ScrollTo(0, 0)
	self.pending_scroll_into_view = false
end

---
--- Scrolls the `XScrollArea` control to the specified `x` and `y` coordinates.
---
--- If `force` is `true`, the scrolling is performed immediately. Otherwise, the scrolling is deferred to the next `DrawWindow` call, which can optimize multiple scroll requests from mouse messages.
---
--- If `allow_interpolation` is `true`, the scrolling will be interpolated over the duration specified by the `ScrollInterpolationTime` property, using the easing function specified by the `ScrollInterpolationEasing` property.
---
--- @param self XScrollArea The `XScrollArea` instance.
--- @param x number The horizontal scroll position.
--- @param y number The vertical scroll position.
--- @param force boolean If `true`, the scrolling is performed immediately.
--- @param allow_interpolation boolean If `true`, the scrolling will be interpolated.
--- @return boolean `true` if the scroll position changed, `false` otherwise.
function XScrollArea:ScrollTo(x, y, force, allow_interpolation)
	x = x or self.PendingOffsetX
	y = y or self.PendingOffsetY
	
	-- scrollbars might impose additional restrictions upon what scroll offets are allowed
	if self.PendingOffsetX ~= x then
		local scroll = self:ResolveId(self.HScroll)
		if scroll then
			x = scroll:SnapScrollPosition(x)
			scroll:SetScroll(x)
		end
	end
	if self.PendingOffsetY ~= y then
		local scroll = self:ResolveId(self.VScroll)
		if scroll then
			y = scroll:SnapScrollPosition(y)
			scroll:DoSetScroll(y)
		end
	end
	
	-- defer actual scrolling to the next DrawWindow call (optimization for multiple scroll requests from mouse messages)
	local ret = false
	if self.PendingOffsetX ~= x or self.PendingOffsetY ~= y then
		self.PendingOffsetX = x
		self.PendingOffsetY = y
		self:Invalidate()
		ret = true
	end
	
	self.pending_scroll_allow_interpolation = allow_interpolation
	if force then
		self:DoScroll(self.PendingOffsetX, self.PendingOffsetY)
	end
	return ret
end

---
--- Scrolls the `XScrollArea` control to the specified `x` and `y` coordinates.
---
--- If `force` is `true`, the scrolling is performed immediately. Otherwise, the scrolling is deferred to the next `DrawWindow` call, which can optimize multiple scroll requests from mouse messages.
---
--- If `allow_interpolation` is `true`, the scrolling will be interpolated over the duration specified by the `ScrollInterpolationTime` property, using the easing function specified by the `ScrollInterpolationEasing` property.
---
--- @param self XScrollArea The `XScrollArea` instance.
--- @param x number The horizontal scroll position.
--- @param y number The vertical scroll position.
--- @param force boolean If `true`, the scrolling is performed immediately.
--- @param allow_interpolation boolean If `true`, the scrolling will be interpolated.
--- @return boolean `true` if the scroll position changed, `false` otherwise.
function XScrollArea:DoScroll(x, y)
	local dx = self.OffsetX - x
	local dy = self.OffsetY - y
	if dx ~= 0 or dy ~= 0 then
		-- scroll
		self.OffsetX = x
		self.OffsetY = y
		for _, win in ipairs(self) do
			if not win.Dock then
				local win_box = win.box
				win:SetBox(win_box:minx() + dx, win_box:miny() + dy, win_box:sizex(), win_box:sizey())
			end
		end
		if self.ScrollInterpolationTime > 0 and self.pending_scroll_allow_interpolation then
			self:AddInterpolation{
				id = "smooth_scroll",
				type = const.intRect,
				duration = self.ScrollInterpolationTime,
				easing = self.ScrollInterpolationEasing,
				originalRect = self.box,
				targetRect = self:GetInterpolatedBox("smooth_scroll", self.box - point(dx, dy)),
				interpolate_clip = const.interpolateClipOff,
				flags = const.intfInverse,
			}
			self.pending_scroll_allow_interpolation = false
		end
		
		-- finalization
		self:RecalcVisibility()
		if Platform.desktop then
			local pt = terminal.GetMousePos()
			if self:MouseInWindow(pt) then
				self.desktop:RequestUpdateMouseTarget()
			end
		end
	end
end

local irInside = const.irInside
local irIntersect = const.irIntersect
--- Recalculates the visibility of the windows in the `XScrollArea`.
---
--- For each non-docked window in the `XScrollArea`, this function checks if the window's bounding box intersects with the content box of the `XScrollArea`. If the intersection is not fully inside the content box, and the `ShowPartialItems` flag is false, the window is marked as being outside the parent.
---
--- This function is typically called after the scroll position of the `XScrollArea` has changed, to update the visibility of the contained windows.
---
--- @param self XScrollArea The `XScrollArea` instance.
function XScrollArea:RecalcVisibility()
	local content = self.content_box
	local partial = self.ShowPartialItems
	for _, win in ipairs(self) do
		if not win.Dock then
			local intersect = content:Intersect2D(win.box)
			win:SetOutsideParent(intersect ~= irInside and not (intersect == irIntersect and partial))
		end
	end
end

---
--- Scrolls the `XScrollArea` to the specified position.
---
--- @param self XScrollArea The `XScrollArea` instance.
--- @param pos number The new scroll position.
--- @param scroll number The scroll direction to update (either the horizontal or vertical scroll).
---
function XScrollArea:OnScrollTo(pos, scroll)
	if scroll == self:ResolveId(self.VScroll) then
		self:ScrollTo(self.PendingOffsetX, pos)
	elseif scroll == self:ResolveId(self.HScroll) then
		self:ScrollTo(pos, self.PendingOffsetY)
	end
end

---
--- Measures the size of the `XScrollArea` control.
---
--- This function is called to determine the preferred size of the `XScrollArea` control. It takes into account the presence of scrollbars and adjusts the measured size accordingly.
---
--- @param self XScrollArea The `XScrollArea` instance.
--- @param preferred_width number The preferred width of the control.
--- @param preferred_height number The preferred height of the control.
--- @return number, number The measured width and height of the control.
---
function XScrollArea:Measure(preferred_width, preferred_height)
	local measure_width = self:ResolveId(self.HScroll) and 1000000 or preferred_width
	local measure_height = self:ResolveId(self.VScroll) and 1000000 or preferred_height
	local width, height = XControl.Measure(self, measure_width, measure_height)
	self.scroll_range_x = width
	self.scroll_range_y = height
	if self.MinHSize then
		preferred_width = Min(preferred_width, width)
	end
	if self.MinVSize then
		preferred_height = Min(preferred_height, height)
	end
	return preferred_width, preferred_height
end

local function lAnyNonDockedWindows(self)
	for i, w in ipairs(self) do
		if not w.Dock then return true end
	end
end

---
--- Lays out the `XScrollArea` control, taking into account the presence of scrollbars and adjusting the measured size accordingly.
---
--- This function is called to position and size the `XScrollArea` control and its child controls. It calculates the appropriate offsets and scroll ranges based on the content size and the available space.
---
--- @param self XScrollArea The `XScrollArea` instance.
--- @param x number The x-coordinate of the control.
--- @param y number The y-coordinate of the control.
--- @param width number The width of the control.
--- @param height number The height of the control.
---
function XScrollArea:Layout(x, y, width, height)
	-- can we accommodate the content better in our content box?
	local c_width, c_height = self.content_box:sizexyz()
	local offset_x, offset_y = self.PendingOffsetX, self.PendingOffsetY
	offset_x = Clamp(offset_x, 0, Max(0, self.scroll_range_x - c_width))
	offset_y = Clamp(offset_y, 0, Max(0, self.scroll_range_y - c_height))
	self:ScrollTo(offset_x, offset_y)
	-- layout
	width = self:ResolveId(self.HScroll) and Max(self.scroll_range_x, width) or width
	height = self:ResolveId(self.VScroll) and Max(self.scroll_range_y, height) or height
	if lAnyNonDockedWindows(self) then
		XWindowLayoutFuncs[self.LayoutMethod](self, x - self.OffsetX, y - self.OffsetY, width, height)
	end
	-- calc step for uniform layouts
	local h_step, v_step
	if self.LayoutMethod == "VList" and self.UniformRowHeight then
		local h_spacing, v_spacing = ScaleXY(self.scale, self.LayoutHSpacing, self.LayoutVSpacing)
		for _, win in ipairs(self) do
			if not win.Dock then
				v_step = Max(v_step, win.measure_height + v_spacing)
			end
		end
	end
	if self.LayoutMethod == "HList" and self.UniformColumnWidth then
		local h_spacing, v_spacing = ScaleXY(self.scale, self.LayoutHSpacing, self.LayoutVSpacing)
		for _, win in ipairs(self) do
			if not win.Dock then
				h_step = Max(h_step, win.measure_width + h_spacing)
			end
		end
	end
	-- setup scrollbars
	local scroll = self:ResolveId(self.HScroll)
	self.MouseWheelStep = v_step or self.MouseWheelStep
	if scroll then
		scroll:SetStepSize(h_step or 1)
		scroll:SetScrollRange(0, self.scroll_range_x)
		scroll:SetPageSize(self.content_box:sizex())
	end
	local scroll = self:ResolveId(self.VScroll)
	if scroll then
		scroll:SetStepSize(v_step or 1)
		scroll:SetScrollRange(0, self.scroll_range_y)
		scroll:SetPageSize(self.content_box:sizey())
	end
end

--- Updates the layout of the XScrollArea control.
---
--- This function is called to update the layout of the XScrollArea control. It performs the following tasks:
--- - Calls the `XControl.UpdateLayout` function to update the layout of the control.
--- - If there are any pending scroll-into-view operations, it scrolls the control to ensure that the specified child or box is visible.
--- - Recalculates the visibility of the control's contents if there is no pending scroll.
--- - Calls the `XControl.UpdateLayout` function again to ensure the layout is up-to-date.
---
--- @param self XScrollArea The XScrollArea control instance.
function XScrollArea:UpdateLayout()
	XControl.UpdateLayout(self)
	if self.pending_scroll_into_view then
		local content_box = self.content_box
		for _, child_or_box in ipairs(self.pending_scroll_into_view) do
			if IsBox(child_or_box) then
				child_or_box = Offset(child_or_box, content_box:minx() - self.OffsetX, content_box:miny() - self.OffsetY)
			end
			self:ScrollIntoView(child_or_box)
		end
		self.pending_scroll_into_view = false
	end
	
	self.layout_update = false
	if self.PendingOffsetX == self.OffsetX and self.PendingOffsetY == self.OffsetY then
		-- recalc visibility after layout if there is no pending scroll
		-- scrolling recalcs visibility
		self:RecalcVisibility()
		XControl.UpdateLayout(self)
	end
end

--- Scrolls the XScrollArea control to ensure that the specified child or box is visible.
---
--- This function is used to scroll the XScrollArea control to ensure that the specified child or box is visible within the control's content area. If the child or box is not fully visible, the function will adjust the scroll offsets to bring it into view.
---
--- If the XScrollArea control is currently undergoing a layout update, the function will store the child or box to be scrolled into view and perform the scrolling operation later, after the layout update is complete.
---
--- @param self XScrollArea The XScrollArea control instance.
--- @param child_or_box Box|XControl The child control or box to scroll into view.
--- @param boxOnTop boolean (optional) If true, the function will attempt to position the child or box at the top of the content area, rather than just ensuring it is visible.
function XScrollArea:ScrollIntoView(child_or_box, boxOnTop)
	if not child_or_box or not IsBox(child_or_box) and child_or_box.window_state == "destroying" then
		return
	end
	
	local content_box = self.content_box
	if self.layout_update then
		self.pending_scroll_into_view = self.pending_scroll_into_view or {}
		-- store boxes in relative coordinates, so that further scrolling or moving the control won't affect them
		if IsBox(child_or_box) then
			child_or_box = Offset(child_or_box, self.OffsetX - content_box:minx(), self.OffsetY - content_box:miny())
		end
		table.insert(self.pending_scroll_into_view, child_or_box)
		return
	end
	
	--[[local parent_scroll_area = GetParentOfKind(self.parent, "XScrollArea")
	if parent_scroll_area then
		parent_scroll_area:ScrollIntoView(child_or_box)
	end]]
	
	local child_box = IsBox(child_or_box) and child_or_box or child_or_box.box
	
	local HScroll = self:ResolveId(self.HScroll)
	if HScroll then HScroll:ScrollIntoView(child_box:minx() - content_box:minx() + self.OffsetX) end
	
	local VScroll = self:ResolveId(self.VScroll)
	if VScroll then VScroll:ScrollIntoView(child_box:miny() - content_box:miny() + self.OffsetY) end
	
	local offset_x, offset_y = self.PendingOffsetX, self.PendingOffsetY
	child_box = Offset(child_box, self.OffsetX - offset_x, self.OffsetY - offset_y)
	if child_box:minx() < content_box:minx() then
		offset_x = offset_x - content_box:minx() + child_box:minx()
	elseif child_box:maxx() > content_box:maxx() then
		offset_x = offset_x - content_box:maxx() + child_box:maxx()
	end
	if child_box:miny() < content_box:miny() then
		offset_y = offset_y - content_box:miny() + child_box:miny()
	elseif child_box:maxy() > content_box:maxy() then
		local childOffset
		if boxOnTop then
			childOffset = Min(child_box:miny() + content_box:sizey(), content_box:miny() + self.scroll_range_y - offset_y)
		else
			childOffset = child_box:maxy()
		end
		offset_y = offset_y - content_box:maxy() + childOffset
	end
	self:ScrollTo(offset_x, offset_y, not "force", "allow_interpolation")
end

---
--- Scrolls the XScrollArea up by the specified mouse wheel step.
---
--- If the scroll area has a vertical scroll bar, the scroll position is adjusted vertically.
--- If the scroll area has no vertical scroll bar but a horizontal scroll bar, the scroll position is adjusted horizontally.
---
--- @param self XScrollArea The XScrollArea instance.
--- @return boolean Whether the scroll operation was successful.
function XScrollArea:ScrollUp()
	local horizontal = (self.HScroll or "") ~= ""
	local vertical = (self.VScroll or "") ~= ""
	local x, y = self.PendingOffsetX, self.PendingOffsetY
	if vertical or not horizontal then
		local max = Max(0, self.scroll_range_y - self.content_box:sizey())
		y = Clamp(y - self.MouseWheelStep, 0, max)
	else
		local max = Max(0, self.scroll_range_x - self.content_box:sizex())
		x = Clamp(x - self.MouseWheelStep, 0, max)
	end
	return self:ScrollTo(x, y, not "force", "allow_interpolation")
end

---
--- Scrolls the XScrollArea down by the specified mouse wheel step.
---
--- If the scroll area has a vertical scroll bar, the scroll position is adjusted vertically.
--- If the scroll area has no vertical scroll bar but a horizontal scroll bar, the scroll position is adjusted horizontally.
---
--- @param self XScrollArea The XScrollArea instance.
--- @return boolean Whether the scroll operation was successful.
function XScrollArea:ScrollDown()
	local horizontal = (self.HScroll or "") ~= ""
	local vertical = (self.VScroll or "") ~= ""
	local x, y = self.PendingOffsetX, self.PendingOffsetY
	if vertical or not horizontal then
		local max = Max(0, self.scroll_range_y - self.content_box:sizey())
		y = Clamp(y + self.MouseWheelStep, 0, max)
	else
		local max = Max(0, self.scroll_range_x - self.content_box:sizex())
		x = Clamp(x + self.MouseWheelStep, 0, max)
	end
	return self:ScrollTo(x, y, not "force", "allow_interpolation")
end

---
--- Scrolls the XScrollArea left by the specified mouse wheel step.
---
--- If the scroll area has a horizontal scroll bar, the scroll position is adjusted horizontally.
--- If the scroll area has no horizontal scroll bar but a vertical scroll bar, the scroll position is adjusted vertically.
---
--- @param self XScrollArea The XScrollArea instance.
--- @return boolean Whether the scroll operation was successful.
function XScrollArea:ScrollLeft()
	local horizontal = (self.HScroll or "") ~= ""
	local vertical = (self.VScroll or "") ~= ""
	local x, y = self.PendingOffsetX, self.PendingOffsetY
	if not vertical or horizontal then
		local max = Max(0, self.scroll_range_x - self.content_box:sizex())
		x = Clamp(x - self.MouseWheelStep, 0, max)
	else
		local max = Max(0, self.scroll_range_y - self.content_box:sizey())
		y = Clamp(y - self.MouseWheelStep, 0, max)
	end
	return self:ScrollTo(x, y, not "force", "allow_interpolation")
end

---
--- Scrolls the XScrollArea right by the specified mouse wheel step.
---
--- If the scroll area has a horizontal scroll bar, the scroll position is adjusted horizontally.
--- If the scroll area has no horizontal scroll bar but a vertical scroll bar, the scroll position is adjusted vertically.
---
--- @param self XScrollArea The XScrollArea instance.
--- @return boolean Whether the scroll operation was successful.
function XScrollArea:ScrollRight()
	local horizontal = (self.HScroll or "") ~= ""
	local vertical = (self.VScroll or "") ~= ""
	local x, y = self.PendingOffsetX, self.PendingOffsetY
	if not vertical or horizontal then
		local max = Max(0, self.scroll_range_x - self.content_box:sizex())
		x = Clamp(x + self.MouseWheelStep, 0, max)
	else
		local max = Max(0, self.scroll_range_y - self.content_box:sizey())
		y = Clamp(y + self.MouseWheelStep, 0, max)
	end
	return self:ScrollTo(x, y, not "force", "allow_interpolation")
end

---
--- Scrolls the XScrollArea up by the specified mouse wheel step.
---
--- If the scroll area has a vertical scroll bar, the scroll position is adjusted vertically.
--- If the scroll area has no vertical scroll bar but a horizontal scroll bar, the scroll position is adjusted horizontally.
---
--- @param self XScrollArea The XScrollArea instance.
--- @return boolean Whether the scroll operation was successful.
function XScrollArea:OnMouseWheelForward()
	if not self.MouseScroll then return end
	if self:ScrollUp() or not GetParentOfKind(self.parent, "XScrollArea") then
		return "break"
	end
end

---
--- Scrolls the XScrollArea down by the specified mouse wheel step.
---
--- If the scroll area has a vertical scroll bar, the scroll position is adjusted vertically.
--- If the scroll area has no vertical scroll bar but a horizontal scroll bar, the scroll position is adjusted horizontally.
---
--- @param self XScrollArea The XScrollArea instance.
--- @return boolean Whether the scroll operation was successful.
function XScrollArea:OnMouseWheelBack()
	if not self.MouseScroll then return end
	if self:ScrollDown() or not GetParentOfKind(self.parent, "XScrollArea") then
		return "break"
	end
end


---- Touch

---
--- Handles the beginning of a touch event on the XScrollArea.
---
--- This function is called when a touch event begins on the XScrollArea. It sets the keyboard focus to false, stores the initial touch position and time, and returns "capture" to indicate that the touch event should be captured by the XScrollArea.
---
--- @param self XScrollArea The XScrollArea instance.
--- @param id number The unique identifier for the touch event.
--- @param pos Vector2 The initial touch position.
--- @param touch table The touch event data.
--- @return string "capture" to indicate that the touch event should be captured by the XScrollArea.
function XScrollArea:OnTouchBegan(id, pos, touch)
	terminal.desktop:SetKeyboardFocus(false)
	touch.start_pos = pos
	touch.start_time = RealTime()
	return "capture"
end

---
--- Handles the movement of a touch event on the XScrollArea.
---
--- This function is called when a touch event moves on the XScrollArea. It updates the scroll position of the XScrollArea based on the movement of the touch event. If the XScrollArea has a vertical scroll bar, the scroll position is adjusted vertically. If the XScrollArea has no vertical scroll bar but a horizontal scroll bar, the scroll position is adjusted horizontally.
---
--- @param self XScrollArea The XScrollArea instance.
--- @param id number The unique identifier for the touch event.
--- @param pos Vector2 The current touch position.
--- @param touch table The touch event data.
--- @return string "break" to indicate that the touch event should be handled by the XScrollArea and not propagated further.
function XScrollArea:OnTouchMoved(id, pos, touch)
	if touch.capture == self then
		local horizontal = (self.HScroll or "") ~= ""
		local vertical = (self.VScroll or "") ~= ""
		local last_pos = touch.last_pos or touch.start_pos
		local diff = pos - last_pos
		local x, y = self.PendingOffsetX, self.PendingOffsetY
		if vertical then
			local max = Max(0, self.scroll_range_y - self.content_box:sizey())
			y = Clamp(y - diff:y(), 0, max)
		end
		if horizontal then
			local max = Max(0, self.scroll_range_x - self.content_box:sizex())
			x = Clamp(x - diff:x(), 0, max)
		end
		touch.last_pos = pos
		if self:ScrollTo(x, y) or not GetParentOfKind(self.parent, "XScrollArea") then
			return "break"
		end
	end
end

local function empty_func() end
---
--- Draws the window for the XScrollArea.
---
--- This function is responsible for drawing the window of the XScrollArea. It first checks if the pending offset of the XScrollArea has changed from the current offset, and if so, it performs a scroll operation, updates the measure, and updates the layout. Finally, it calls the base `DrawWindow` function to draw the window.
---
--- @param self XScrollArea The XScrollArea instance.
--- @param clip_box table The clipping box for the window.
function XScrollArea:DrawWindow(clip_box)
	if self.PendingOffsetX ~= self.OffsetX or self.PendingOffsetY ~= self.OffsetY then
		self.Invalidate = empty_func
		self:DoScroll(self.PendingOffsetX, self.PendingOffsetY)
		-- Do full layout before drawing, making sure virtual items entering the view are (immediately) displayed correctly;
		-- UpdateMeasure/UpdateLayout won't do anything unless a newly "spawned" XVirtualContent child changed measure
		self:UpdateMeasure(self.parent.content_box:size():xy())
		XControl.UpdateLayout(self) -- use base method to prevent a call to RecalcVisibility
		self.Invalidate = nil
	end
	XControl.DrawWindow(self, clip_box)
end


----- XFitContent

DefineClass.XFitContent = {
	__parents = { "XControl" },
	properties = {
		{ category = "Visual", id = "Fit", name = "Fit", editor = "choice", default = "none", items = {"none", "width", "height", "smallest", "largest", "both"}, },
	},
}

local one = point(1000, 1000)
---
--- Updates the measure of the XFitContent control.
---
--- This function is responsible for updating the measure of the XFitContent control. It first checks if the measure needs to be updated, and if not, it returns. Otherwise, it sets the scale of all child controls to 1, and then calls the base `UpdateMeasure` function with a very large maximum width and height. It then calculates the actual content width and height, taking into account the parent's scale. If the content width or height is 0, it calls the base `UpdateMeasure` function with the original maximum width and height. Otherwise, it determines the appropriate scale factor based on the "Fit" property, and sets the scale modifier of the control accordingly. Finally, it calls the base `UpdateMeasure` function with the original maximum width and height.
---
--- @param self XFitContent The XFitContent instance.
--- @param max_width number The maximum width of the control.
--- @param max_height number The maximum height of the control.
function XFitContent:UpdateMeasure(max_width, max_height)
	if not self.measure_update then return end
	local fit = self.Fit
	if fit == "none" then
		XControl.UpdateMeasure(self, max_width, max_height)
		return
	end
	for _, child in ipairs(self) do
		child:SetOutsideScale(one)
	end
	self.scale = one
	XControl.UpdateMeasure(self, 1000000, 1000000)
	local content_width, content_height = ScaleXY(self.parent.scale, self.measure_width, self.measure_height)
	assert(content_width > 0 and content_height > 0)
	if content_width == 0 or content_height == 0 then
		XControl.UpdateMeasure(self, max_width, max_height)
		return
	end
	if fit == "smallest" or fit == "largest" then
		local space_is_wider = max_width * content_height >= max_height * content_width
		fit = space_is_wider == (fit == "largest") and "width" or "height"
	end
	local scale_x = max_width * 1000 / content_width
	local scale_y = max_height * 1000 / content_height
	if fit == "width" then
		scale_y = scale_x
	elseif fit == "height" then
		scale_x = scale_y
	end
	self:SetScaleModifier(point(scale_x, scale_y))
	XControl.UpdateMeasure(self, max_width, max_height)
end
