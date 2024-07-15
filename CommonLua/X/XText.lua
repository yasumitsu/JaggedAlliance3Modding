DefineClass.XText = {
	__parents = { "XTranslateText" },
	
	-- text properties that affect the draw cache should have invalidate = "measure"
	properties = {
		{ category = "General", id = "Text", editor = "text", default = "", translate = function (obj) return obj:GetProperty("Translate") end, lines = 1, },
		{ category = "General", id = "WordWrap", editor = "bool", default = true, invalidate = "measure", },
		{ category = "General", id = "Shorten", editor = "bool", default = false, invalidate = "measure", },
		{ category = "General", id = "ShortenString", editor = "text", default = "...", translate = false, lines = 1, invalidate = "layout", trim_spaces = false },
		{ category = "General", id = "HideOnEmpty", editor = "bool", default = false, invalidate = "measure", },
		{ category = "Layout", id = "TextHAlign", editor = "choice", default = "left", items = { "left", "center", "right" }, invalidate = "measure", },
		{ category = "Layout", id = "TextVAlign", editor = "choice", default = "top", items = { "top", "center", "bottom" }, invalidate = true, },
		{ category = "Visual", id = "Angle", editor = "number", default = 0, invalidate = "measure",  min = 0, max = 360*60 - 1, scale = "deg"},
		{ category = "Visual", id = "ImageScale", editor = "number", default = 500, invalidate = "measure", },
		{ category = "Visual", id = "UnderlineOffset", editor = "number", default = 0 },

		{ category = "Debug", id = "draw_cache_text_width", read_only = true, editor = "number", },
		{ category = "Debug", id = "draw_cache_text_height", read_only = true, editor = "number", },
		{ category = "Debug", id = "text_width", read_only = true, editor = "number", },
		{ category = "Debug", id = "text_height", read_only = true, editor = "number", },
		{ category = "Debug", id = "DebugText", read_only = true, editor = "text", default = "", lines = 1, max_lines = 10 },
		{ category = "Debug", id = "DebugButtons", editor = "buttons", buttons = {{name = "Copy XText cloning code to clipboard", func = "CopyDebugText"}} },
	},
	
	Clip = "parent & self",
	Padding = box(2, 2, 2, 2),

	draw_cache = {},
	draw_cache_text_width = 0,
	draw_cache_text_height = 0,
	draw_cache_text_wrapped = false,
	draw_cache_text_shortened = false,
	force_update_draw_cache = false,
	invert_colors = false, -- used for Ged help rollovers in dark mode
	
	scaled_underline_offset = 0,
	text_width = 0,
	text_height = 0,
	hovered_hyperlink = false,
	touch = false,
}

---
--- Returns the debug text for the XText object.
---
--- @return string The debug text for the XText object.
function XText:GetDebugText()
	return self.text or ""
end

---
--- Copies the debug text of the XText object to the clipboard.
---
--- This function is used to generate a debug code snippet that can be used to
--- recreate the current state of the XText object. It captures the current
--- size, text, and various properties of the XText object and generates a
--- call to the `XTextDebug` function that can be used to display the object
--- in a debug window.
---
--- @return nil
function XText:CopyDebugText()
	local width, height = self.box:sizexyz()
	local args = {
		MulDivRound(width, 1000, self.scale:x()),
		MulDivRound(height, 1000, self.scale:y()),
		self:GetDebugText(),
	}
	
	local props = {
		"WordWrap", "Shorten", "TextHAlign", "TextVAlign",
		"ImageScale", "TextStyle", "TextFont", "TextColor", "ShadowType", "ShadowSize", "ShadowColor", "RolloverTextColor", "DisabledTextColor"
	}
	for _, id in ipairs(props) do
		table.insert(args, id)
		table.insert(args, self:GetProperty(id))
	end
	
	args = table.map(args, function(v) return ValueToLuaCode(v) end)
	local func = "XTextDebug(" .. table.concat(args, ", ") .. ")"
	CopyToClipboard(func)
end

if Platform.developer then
	if FirstLoad then
		DebugXTextContainer = false
	end

	function XTextDebug(width, height, text, ...)
		if DebugXTextContainer then
			DebugXTextContainer:delete()
		end
		
		DebugXTextContainer = XWindow:new({
			Id = "XTextDebugContainer",
			Background = RGBA(0, 0, 0, 128),
		}, terminal.desktop)
		local ctrl = XText:new({
			HAlign = "center",
			VAlign = "center",
		}, DebugXTextContainer)
		
		local props = table.pack(...)
		for i = 1, #props, 2 do
			ctrl:SetProperty(props[i], props[i + 1])
		end
		ctrl:SetMinWidth(width)
		ctrl:SetMaxWidth(width)
		ctrl:SetMinHeight(height)
		ctrl:SetMaxHeight(height)
		ctrl:SetText(text)
		ctrl:SetRollover(false)
	end
	
	function OnMsg.DbgClear()
		if DebugXTextContainer then
			DebugXTextContainer:delete()
			DebugXTextContainer = false
		end
	end
end

---
--- Invalidates the measure of the `XText` control, forcing it to re-measure its content on the next layout pass.
---
--- This function sets the `force_update_draw_cache` flag to `true`, which will cause the `UpdateDrawCache` function to re-generate the draw cache for the control's text when it is next measured.
---
--- @param self XText The `XText` control instance.
--- @param ... Any additional arguments passed to the `XWindow.InvalidateMeasure` function.
--- @return boolean The return value of the `XWindow.InvalidateMeasure` function.
---
function XText:InvalidateMeasure(...)
	self.force_update_draw_cache = true
	return XWindow.InvalidateMeasure(self, ...)
end

---
--- Measures the size of the `XText` control's content, taking into account the maximum width and height constraints.
---
--- This function updates the `draw_cache` of the `XText` control, which is used to render the text. It then returns the width and height of the text content, clamped to the maximum height.
---
--- @param self XText The `XText` control instance.
--- @param max_width number The maximum width available for the control.
--- @param max_height number The maximum height available for the control.
--- @return number, number The width and height of the text content.
---
function XText:Measure(max_width, max_height)
	self.content_measure_width = max_width
	self.content_measure_height = max_height
	self:UpdateDrawCache(max_width, max_height, self.force_update_draw_cache)
	self.force_update_draw_cache = false
	return self.text_width, Clamp(self.text_height, self.font_height, max_height)
end

---
--- Updates the measure of the `XText` control, taking into account the maximum width and height constraints.
---
--- If the `HideOnEmpty` flag is set and the text is empty, this function updates the draw cache, sets the measure width and height to 0, and invalidates the layout of the parent control. Otherwise, it calls the `XTranslateText.UpdateMeasure` function to update the measure.
---
--- @param self XText The `XText` control instance.
--- @param max_width number The maximum width available for the control.
--- @param max_height number The maximum height available for the control.
---
function XText:UpdateMeasure(max_width, max_height)
	if self.HideOnEmpty and self.text == "" then
		self:UpdateDrawCache(max_width, max_height, true)
		self.force_update_draw_cache = false
		if 0 ~= self.measure_width or 0 ~= self.measure_height then
			self.measure_width = 0
			self.measure_height = 0
			if self.parent then
				self.parent:InvalidateLayout()
			end
		end
		self.measure_update = false
		return
	end
	return XTranslateText.UpdateMeasure(self, max_width, max_height)
end

---
--- Lays out the `XText` control, updating the draw cache if necessary and triggering a re-layout if the new text layout requires more space.
---
--- This function is called after the `Measure` function has been called, and the control has been allocated a certain width and height. If the allocated width and height are greater than 0, it updates the draw cache using the `UpdateDrawCache` function. If the new text layout requires more space than the allocated width and height, it triggers a re-layout by calling `InvalidateMeasure`.
---
--- Finally, it calls the `XTranslateText.Layout` function to perform the actual layout of the control.
---
--- @param self XText The `XText` control instance.
--- @param x number The x-coordinate of the control.
--- @param y number The y-coordinate of the control.
--- @param width number The width of the control.
--- @param height number The height of the control.
--- @return number, number The width and height of the control after layout.
---
function XText:Layout(x, y, width, height)
	-- After Measure, at the time of Layout we might be allocated less space than requested (as returned by Measure), so:
	--  a) update the draw cache (as the text layout might need to change due to wordwrapping)
	--  b) if the new text layout requires more space, trigger a UI re-layout by calling InvalidateMeasure
	if width > 0 and height > 0 and self:UpdateDrawCache(width, height) then
		self:InvalidateMeasure()
		self.force_update_draw_cache = false -- prevent the subsequent call to Measure from force-updating the draw cache, that was just updated
	end
	return XTranslateText.Layout(self, x, y, width, height)
end

---
--- Updates the draw cache for the `XText` control, taking into account the maximum width and height constraints.
---
--- If the `text` property is empty or the `width` is 0, this function sets the `draw_cache`, `draw_cache_text_wrapped`, `text_width`, and `text_height` properties to 0. Otherwise, it calls the `XTextMakeDrawCache` function to generate the draw cache, and updates the `draw_cache_text_width`, `draw_cache_text_height`, `text_width`, `text_height`, and `draw_cache_text_shortened` properties accordingly.
---
--- If the `force` parameter is true, or if the `draw_cache_text_width` or `draw_cache_text_height` properties have changed, this function will update the draw cache. It will also update the `scaled_underline_offset` property based on the `UnderlineOffset` and `scale` properties.
---
--- @param self XText The `XText` control instance.
--- @param width number The maximum width available for the control.
--- @param height number The maximum height available for the control.
--- @param force boolean (optional) If true, the draw cache will be updated regardless of whether the dimensions have changed.
--- @return boolean True if the text width or height has increased, false otherwise.
---
function XText:UpdateDrawCache(width, height, force)
	local old_text_width, old_text_height = self.text_width, self.text_height
	if force or
	   self.draw_cache_text_width ~= width and (self.draw_cache_text_wrapped or width < self.text_width) or
	   self.draw_cache_text_height ~= height and self.Shorten
	then
		self.draw_cache_text_width = width
		self.draw_cache_text_height = height
		
		if self.text == "" or width <= 0 then
			self.draw_cache, self.draw_cache_text_wrapped, self.text_width, self.text_height = empty_table, false, 0, 0
		else
			self.draw_cache, self.draw_cache_text_wrapped, self.text_width, self.text_height, self.draw_cache_text_shortened = XTextMakeDrawCache(self.text, {
				IsEnabled = self:GetEnabled(),
				EffectColor = self.ShadowColor,
				DisabledEffectColor = self.DisabledShadowColor,
				
				start_font_name = (self.TextFont and self.TextFont ~= "") and self.TextFont or self:GetTextStyle(),
				start_color = self.TextColor,
				invert_colors = self.invert_colors,
				max_width = width,
				max_height = height,
				scale = self.scale,
				default_image_scale = self.ImageScale,
				effect_type = self.ShadowType,
				effect_size = self.ShadowSize,
				effect_dir = self.ShadowDir,
				alignment = self.TextHAlign,
				
				word_wrap = self.WordWrap,
				shorten = self.Shorten,
				shorten_string = self.ShortenString,
			})
		end
		self:GetFontId() -- initialize self.font_height, self.font_baseline
	end
	local _, h = ScaleXY(self.scale, 0, self.UnderlineOffset)
	self.scaled_underline_offset = h
	return self.text_width > old_text_width or self.text_height > old_text_height
end

local function tab_resolve_x(draw_info, sizex)
	local x = draw_info.x
	if draw_info.control_wide_center then
		return x + sizex / 2
	end
	return x >= 0 and x or sizex + x + 1
end

local one = point(1, 1)
local target_box = box()

---
--- Draws the content of the XText object within the specified clip box.
---
--- @param clip_box box The clip box to use for drawing the content.
---
function XText:DrawContent(clip_box)
	local content_box = self.content_box
	local destx, desty = content_box:minxyz()
	local sizex, sizey = content_box:sizexyz()
	
	local effect_size = self.ShadowSize
	if self.TextVAlign == "center" then
		desty = desty + (sizey - self.text_height - effect_size) / 2
	elseif self.TextVAlign == "bottom" then
		desty = content_box:maxy() - self.text_height
	end
	
	local clip_y1, clip_y2 = clip_box:miny(), clip_box:maxy()
	
	local underline_start_x, underline_color
	local angle = self.Angle
	local hovered_hyperlink_id = self.hovered_hyperlink and self.hovered_hyperlink.hl_internalid or -1
	local StretchTextShadow = UIL.StretchTextShadow
	local StretchTextOutline = UIL.StretchTextOutline
	local StretchText = UIL.StretchText
	local DrawImage = UIL.DrawImage
	local PushModifier = UIL.PushModifier
	local ModifiersGetTop = UIL.ModifiersGetTop
	local ModifiersSetTop = UIL.ModifiersSetTop
	local DrawSolidRect = UIL.DrawSolidRect
	local UseClipBox = self.UseClipBox
	local irOutside = const.irOutside
	
	local default_color = self:CalcTextColor()
	for y, draw_list in pairs(self.draw_cache) do
		local list_n = #draw_list
		for n, draw_info in ipairs(draw_list) do
			local x = tab_resolve_x(draw_info, sizex)
			local h = draw_info.height
			local vdest = desty + y + draw_info.y_offset
			if not UseClipBox or vdest + h >= clip_y1 and vdest <= clip_y2 then
				if draw_info.text then
					target_box:InplaceSetSize(destx + x, vdest, draw_info.width, h)
					local hl_hovered = hovered_hyperlink_id == draw_info.hl_internalid
					local color = hl_hovered and draw_info.hl_hovercolor or draw_info.color or default_color
					local underline = draw_info.underline or hl_hovered and draw_info.hl_underline
					if not underline_start_x and underline then
						underline_start_x = target_box:minx()
						underline_color = draw_info.underline_color or color
					end
					
					local background_color = draw_info.background_color
					if background_color and GetAlpha(background_color) > 0 then
						local bg_box = box(target_box:minx() - 2, target_box:miny(), target_box:maxx(), target_box:maxy())
						DrawSolidRect(bg_box, background_color)
					end
					
					if not UseClipBox or target_box:Intersect2D(clip_box) ~= irOutside then
						local effect_size = draw_info.effect_size or effect_size
						local effect_type = draw_info.effect_type
						local effect_color = draw_info.effect_color or self.ShadowColor
						local effect_dir = draw_info.effect_dir or one
						local _, _, _, effect_alpha = GetRGBA(effect_color)
						if effect_alpha ~= 0 and effect_size > 0 then
							local off = effect_size
							if effect_type == "shadow" then
								StretchTextShadow(draw_info.text, target_box, draw_info.font, color, effect_color, off, effect_dir, angle)
							elseif effect_type == "extrude" then
								StretchTextShadow(draw_info.text, target_box, draw_info.font, color, effect_color, off, effect_dir, angle, true)
							elseif effect_type == "outline" then
								StretchTextOutline(draw_info.text, target_box, draw_info.font, color, effect_color, off, angle)
							elseif effect_type == "glow" then
								local glow_size = MulDivRound(off * 1000, self.scale:x(), 1000);
								UIL.StretchTextSDF(draw_info.text, target_box, draw_info.font,
									"base_color", color,
									"glow_color", effect_color,
									"glow_size", glow_size)
							else -- normal
								StretchText(draw_info.text, target_box, draw_info.font, color, angle)
							end
						else -- normal
							StretchText(draw_info.text, target_box, draw_info.font, color, angle)
						end
					end
					local underline_to_end = underline and n == list_n
					if underline_start_x and (not underline or underline_to_end) then
						local baseline = vdest + self.font_baseline + self.scaled_underline_offset
						local end_x = underline_to_end and target_box:maxx() or target_box:minx()
						DrawSolidRect(box(underline_start_x, baseline, end_x, baseline + 1), underline_color)
						underline_start_x = nil
					end
				elseif draw_info.horizontal_line then
					local margin = draw_info.margin
					local thickness = MulDivRound(draw_info.scale, draw_info.thickness, 1000)
					local midy = vdest + MulDivRound(draw_info.scale, draw_info.space_above, 1000)
					local ymin = midy - DivCeil(thickness, 2)
					local ymax = midy + thickness / 2
					local xmin = destx + margin
					local xmax = destx + sizex - margin
					DrawSolidRect(box(xmin, ymin, xmax, ymax), draw_info.color or default_color)
				else
					local mtop
					if draw_info.base_color_map then
						mtop = ModifiersGetTop()
						PushModifier{
							modifier_type = const.modShader,
							shader_flags = const.modIgnoreAlpha,
						}
					end
					
					target_box:InplaceSetSize(destx + x, vdest, draw_info.width, h)
					DrawImage(draw_info.image, target_box, draw_info.image_size_org, draw_info.image_color)
					
					if mtop then
						ModifiersSetTop(mtop)
					end
				end
			end
		end
	end
end

---
--- Returns the hyperlink information and its bounding box at the given point.
---
--- @param ptCheck vec2 | nil The point to check for hyperlinks. If `nil`, returns the first hyperlink found.
--- @return table|boolean draw_info The hyperlink information, or `false` if no hyperlink is found.
--- @return box link_box The bounding box of the hyperlink.
function XText:GetHyperLink(ptCheck)
	local content_box = self.content_box
	local basex, basey = content_box:minxyz()
	local sizex = content_box:sizex()
	for cache_y, draw_list in pairs(self.draw_cache) do
		for _, draw_info in ipairs(draw_list) do
			if draw_info.hl_function then
				local x = basex + tab_resolve_x(draw_info, sizex)
				local y = basey + cache_y
				if not ptCheck then
					return draw_info, box(
						x, y, 
						x + draw_info.width, y + draw_info.height )
				end
				
				local checkx = ptCheck:x() - x
				local checky = ptCheck:y() - y
				if checkx >= 0 and checkx <= draw_info.width and
					checky >= 0 and checky <= draw_info.height then
					return draw_info, box(
						x, y, 
						x + draw_info.width, y + draw_info.height )
				end
			end
		end
	end
	return false
end

---
--- Returns whether the XText instance has any hyperlinks.
---
--- @return boolean Has hyperlinks
function XText:HasHyperLinks()
	for y, draw_list in pairs(self.draw_cache) do
		for _, draw_info in ipairs(draw_list) do
			if draw_info.hl_function then
				return true
			end
		end
	end
	return false
end

---
--- Handles the activation of a hyperlink in the XText instance.
---
--- @param hyperlink string The name of the hyperlink function to call.
--- @param argument any The argument to pass to the hyperlink function.
--- @param hyperlink_box box The bounding box of the hyperlink.
--- @param pos vec2 The position where the hyperlink was activated.
--- @param button string The mouse button that was used to activate the hyperlink ("L" for left, "R" for right).
function XText:OnHyperLink(hyperlink, argument, hyperlink_box, pos, button)
	local f, obj = ResolveFunc(self.context, hyperlink)
	if f then
		f(obj, argument)
	end
end

---
--- Handles the double-click activation of a hyperlink in the XText instance.
---
--- @param hyperlink string The name of the hyperlink function to call.
--- @param argument any The argument to pass to the hyperlink function.
--- @param hyperlink_box box The bounding box of the hyperlink.
--- @param pos vec2 The position where the hyperlink was double-clicked.
--- @param button string The mouse button that was used to double-click the hyperlink ("L" for left, "R" for right).
function XText:OnHyperLinkDoubleClick(hyperlink, argument, hyperlink_box, pos, button)
end

---
--- Handles the rollover of a hyperlink in the XText instance.
---
--- @param hyperlink string The name of the hyperlink function to call.
--- @param hyperlink_box box The bounding box of the hyperlink.
--- @param pos vec2 The position where the hyperlink was hovered over.
function XText:OnHyperLinkRollover(hyperlink, hyperlink_box, pos)
end

---
--- Handles the beginning of a touch event on the XText instance.
---
--- If the touch position is on a hyperlink, the hyperlink is stored in the `touch` field
--- so that it can be handled in the `OnTouchEnded` event.
---
--- @param id number The unique identifier for the touch event.
--- @param pt vec2 The position of the touch event.
--- @param touch table The touch event object.
--- @return string "break" to indicate that the touch event has been handled.
function XText:OnTouchBegan(id, pt, touch)
	self.touch = self:GetHyperLink(pt)
	if self.touch then
		return "break"
	end
end

---
--- Handles the touch move event on the XText instance.
---
--- This function is called when the user moves their finger on the touch screen while interacting with the XText instance.
--- It updates the mouse position and returns "break" to indicate that the touch event has been handled.
---
--- @param id number The unique identifier for the touch event.
--- @param pt vec2 The position of the touch event.
--- @param touch table The touch event object.
--- @return string "break" to indicate that the touch event has been handled.
function XText:OnTouchMoved(id, pt, touch)
	self:OnMousePos(pt)
	return "break"
end

---
--- Handles the end of a touch event on the XText instance.
---
--- If the touch position is on a hyperlink that was stored in the `touch` field during the `OnTouchBegan` event,
--- the hyperlink function is called with the appropriate arguments.
---
--- @param id number The unique identifier for the touch event.
--- @param pt vec2 The position of the touch event.
--- @param touch table The touch event object.
--- @return string "break" to indicate that the touch event has been handled.
function XText:OnTouchEnded(id, pt, touch)
	local h, link_box = self:GetHyperLink(pt)
	if h and h == self.touch then
		self:OnHyperLink(h.hl_function, h.hl_argument, link_box, pt, "L")
	end
	self.touch = false
	return "break"
end

---
--- Handles the cancellation of a touch event on the XText instance.
---
--- This function is called when a touch event is cancelled, for example if the user lifts their finger off the screen.
--- It sets the `touch` field to `false` to indicate that the touch event has been cancelled, and returns "break" to indicate that the touch event has been handled.
---
--- @param id number The unique identifier for the touch event.
--- @param pos vec2 The position of the touch event.
--- @param touch table The touch event object.
--- @return string "break" to indicate that the touch event has been handled.
function XText:OnTouchCancelled(id, pos, touch)
	self.touch = false
	return "break"
end

---
--- Handles the mouse button down event on the XText instance.
---
--- If the touch position is on a hyperlink that was stored in the `touch` field during the `OnTouchBegan` event,
--- the hyperlink function is called with the appropriate arguments.
---
--- @param pos vec2 The position of the mouse event.
--- @param button number The mouse button that was pressed.
--- @return string "break" to indicate that the mouse event has been handled.
function XText:OnMouseButtonDown(pos, button)
	local h, link_box = self:GetHyperLink(pos)
	if h then
		self:OnHyperLink(h.hl_function, h.hl_argument, link_box, pos, button)
		return "break"
	end
end

---
--- Handles the mouse double-click event on the XText instance.
---
--- If the double-click position is on a hyperlink that was stored in the `touch` field during the `OnTouchBegan` event,
--- the hyperlink double-click function is called with the appropriate arguments.
---
--- @param pos vec2 The position of the mouse event.
--- @param button number The mouse button that was double-clicked.
--- @return string "break" to indicate that the mouse event has been handled.
function XText:OnMouseButtonDoubleClick(pos, button)
	local h, link_box = self:GetHyperLink(pos)
	if h then
		self:OnHyperLinkDoubleClick(h.hl_function, h.hl_argument, link_box, pos, button)
		return "break"
	end
end

---
--- Handles the mouse position event on the XText instance.
---
--- This function is called when the mouse position changes within the XText instance. It checks if the mouse position is over a hyperlink, and if so, calls the `OnHyperLinkRollover` function with the appropriate arguments. If the mouse is not over a hyperlink, it calls `OnHyperLinkRollover` with `false` arguments. Finally, it invalidates the XText instance to trigger a redraw.
---
--- @param pos vec2 The position of the mouse event.
function XText:OnMousePos(pos)
	if not pos then return end
	local h, link_box = self:GetHyperLink(pos)
	if self.hovered_hyperlink == h then
		return
	end
	self.hovered_hyperlink = h
	if h then
		self:OnHyperLinkRollover(h.hl_function, link_box, pos)
	else
		self:OnHyperLinkRollover(false, false, pos)
	end
	self:Invalidate()
end

---
--- Handles the mouse left button press event on the XText instance.
---
--- This function first calls the `OnMousePos` function to update the hovered hyperlink state, then it calls the `OnMouseLeft` function of the `XTranslateText` class with the provided arguments.
---
--- @param pt vec2 The position of the mouse event.
--- @param ... Any additional arguments passed to the `OnMouseLeft` function.
--- @return string "break" to indicate that the mouse event has been handled.
function XText:OnMouseLeft(pt, ...)
	self:OnMousePos(pt)
	return XTranslateText.OnMouseLeft(self, pt, ...)
end

--- Sets the text of the XText instance and updates the mouse position.
---
--- @param text string The new text to set for the XText instance.
function XText:SetText(text)
	XTranslateText.SetText(self, text)
	self:OnMousePos(self.desktop and self.desktop.last_mouse_pos)
end

---
--- Converts a given text string into a literal representation.
---
--- If the input `text` is an empty string or a table, it is returned as-is. Otherwise, the function wraps the `text` in a string format that indicates it is a literal value, including the length of the string.
---
--- @param text string The text to convert to a literal representation.
--- @return string The literal representation of the input text.
function Literal(text)
	if text == "" or IsT(text) then
		return text
	end
	return string.format("<literal %s>%s", #text, text)
end

---
--- Converts a given font name to a project-specific font.
---
--- This function simply returns the provided `fontName` as-is, without any conversion. It is a placeholder function that can be overridden in the project to provide custom font conversion logic.
---
--- @param fontName string The name of the font to convert.
--- @return string The converted font name.
function GetProjectConvertedFont(fontName)
	return fontName
end