local max_curve_points = 8

DefineClass.XCurveEditor = {
	__parents = { "XControl", "XActionsHost" },
	
	properties = {
		{ category = "General", id = "ControlPoints", editor = "number", default = 4, min = 2, max = max_curve_points, },
		{ category = "General", id = "MaxX", editor = "number", default = 1000, min = 1 },
		{ category = "General", id = "MinX", editor = "number", default = 0, min = 1 },
		{ category = "General", id = "MaxY", editor = "number", default = 1000, min = 1 },
		{ category = "General", id = "MinY", editor = "number", default = 0 },
		{ category = "General", id = "DisplayScaleX", editor = "number", default = 1000, min = 1, help = "Used for displaying numbers around the graph" },
		{ category = "General", id = "DisplayScaleY", editor = "number", default = 1000, min = 1, help = "Used for displaying numbers around the graph"},
		{ category = "General", id = "SnapX", editor = "number", default = 1, min = 1 },
		{ category = "General", id = "SnapY", editor = "number", default = 1, min = 1 },
		{ category = "General", id = "FixedX", editor = "bool", default = false },
		{ category = "General", id = "PushPointsOnMove", editor = "bool", default = true, },
		{ category = "General", id = "CurveColor", editor = "color", default = RGB(0,0,0),  },
		{ category = "General", id = "ControlPointMaxDist", editor = "number", default = 25,  },
		{ category = "General", id = "ControlPointColor", editor = "color", default = RGB(80, 80, 80),  },
		{ category = "General", id = "ControlPointCaptureColor", editor = "color", default = RGB(0,0,0),  },
		{ category = "General", id = "ControlPointHoverColor", editor = "color", default = RGB(130, 130, 130),  },
		{ category = "General", id = "GridUnitX", editor = "number", default = 100, },
		{ category = "General", id = "GridUnitY", editor = "number", default = 100, },
		{ category = "General", id = "GridColor", editor = "color", default = RGB(180, 180, 180),  },
		{ category = "General", id = "Smooth", editor = "bool", default = true, },
		{ category = "General", id = "ReadOnly", editor = "bool", default = false, },
		{ category = "General", id = "MinMaxRangeMode", editor = "bool", defalt = false, help = "Stores the /Min/ Value in point.z" },
	},
	
	OnCurveChanged = false,
	point_handles = false,
	capture_handle = false,
	hover_handle = false,
	points = false,
	scale_texts = false,
	font_id = false,

	text_space_required = false,
	MinMaxRangeMode = false,
}

-- debug helpers
for i = 1, max_curve_points do
	local xname = "x" .. i
	local yname = "y" .. i
	table.insert(XCurveEditor.properties, {
		category = "General", id = xname, editor = "number", min = 0, default = 0,
		max = function(obj) return obj.MaxX end, slider = true, --read_only = true,
		no_edit = function(obj) return i > obj.ControlPoints end,
	})
	table.insert(XCurveEditor.properties, {
		category = "General", id = yname, editor = "number", min = 0, default = 0,
		max = function(obj) return obj.MaxY end, slider = true, --read_only = true,
		no_edit = function(obj) return i > obj.ControlPoints end,
	})
	XCurveEditor["Get" .. xname] = function(obj) return obj.points[i]:x() end
	XCurveEditor["Get" .. yname] = function(obj) return obj.points[i]:y() end
	XCurveEditor["Set" .. xname] = function(obj, value) obj:MovePoint(i, obj.points[i]:SetX(value)) end
	XCurveEditor["Set" .. yname] = function(obj, value) obj:MovePoint(i, obj.points[i]:SetY(value)) end
end

---
--- Generates the UI elements for the control points of the curve editor.
--- This function creates the main control point handles and, if the `MinMaxRangeMode` is enabled, the additional min and max handles.
--- The control point handles are stored in the `point_handles` table.
---
--- @param self XCurveEditor The curve editor instance.
---
function XCurveEditor:GeneratePointUIElements()
	self.point_handles = {}
	for idx, pt in pairs(self.points) do
		local main_handle = XCurveEditorHandle:new({
			point_idx = idx,
			curve_editor = self,
		})
		
		table.insert(self.point_handles, main_handle)

		if self.MinMaxRangeMode then
			local handle = XCurveEditorMinHandle:new({
				point_idx = idx,
				curve_editor = self,
				parent = main_handle,
			})
			
			table.insert(self.point_handles, handle)
			handle = XCurveEditorMaxHandle:new({
				point_idx = idx,
				curve_editor = self,
				parent = main_handle,
			})
			
			table.insert(self.point_handles, handle)
		end
	end
end

---
--- Returns the range of the curve editor.
---
--- @return point The range of the curve editor, represented as a point with the X, Y, and Z components representing the minimum and maximum values.
---
function XCurveEditor:GetRange()
	return point(self.MaxX - self.MinX, self.MaxY - self.MinY, self.MaxY - self.MinY)
end

---
--- Returns the minimum range of the curve editor.
---
--- @return point The minimum range of the curve editor, represented as a point with the X, Y, and Z components representing the minimum values.
---
function XCurveEditor:GetRangeMin()
	return point(self.MinX, self.MinY, self.MinY)
end

---
--- Returns the maximum range of the curve editor.
---
--- @return point The maximum range of the curve editor, represented as a point with the X, Y, and Z components representing the maximum values.
---
function XCurveEditor:GetRangeMax()
	return point(self.MaxX, self.MaxY, self.MaxY)
end

---
--- Initializes the XCurveEditor instance.
---
--- This function sets up the initial points for the curve editor based on the `ControlPoints` property. It calculates the range of the curve editor and inserts the points into the `points` table. Finally, it calls the `GeneratePointUIElements` function to create the UI elements for the points.
---
--- @return nil
---
function XCurveEditor:Init()
	self.points = {  }
	local max_points = self.ControlPoints - 1
	local range = self:GetRange()
	assert(range:x() > 0 and range:y() > 0)
	for i = 0, max_points do
		local y = i * range:y() / max_points
		table.insert(self.points, point(i * range:x() / max_points, y, y))
	end
	self:GeneratePointUIElements()

end

---
--- Returns the size of the control points in the curve editor.
---
--- @return point The size of the control points, represented as a point with the X and Y components representing the width and height respectively.
---
function XCurveEditor:GetControlPointSize()
	return point(ScaleXY(self.scale, 10, 10))
end

---
--- Returns the bounding box of the graph area in the curve editor.
---
--- The bounding box is calculated based on the size of the control points and any additional space required for text. The top-left padding is set to half the control point size, and the bottom-right padding is set to half the control point size plus any additional space required for text.
---
--- @return box The bounding box of the graph area in the curve editor.
---
function XCurveEditor:GetGraphBox()
	local control_size = self:GetControlPointSize()
	local topleft_padding = control_size / 2
	local bottomright_padding = control_size / 2
	
	local text_space_required = self.text_space_required
	if text_space_required then
		bottomright_padding = point(Max(text_space_required:x(), bottomright_padding:x()), Max(text_space_required:y(), bottomright_padding:y()))
	end
	return box(self.content_box:min() + topleft_padding, self.content_box:max() - bottomright_padding)
end

---
--- Transforms a point from the curve editor's coordinate space to the graph area's coordinate space.
---
--- The transformation involves the following steps:
--- 1. Get the bounding box of the graph area using `XCurveEditor:GetGraphBox()`.
--- 2. Get the range of the curve editor using `XCurveEditor:GetRange()`.
--- 3. Calculate the base point, which is the bottom-left corner of the graph area.
--- 4. Subtract the minimum range value from the input point to get the point relative to the curve editor's origin.
--- 5. Flip the Y-coordinate of the point to match the graph area's coordinate system.
--- 6. Scale the point to fit within the graph area's bounding box using `MulDivRoundPoint()`.
--- 7. Add the base point to the transformed point to get the final point in the graph area's coordinate space.
---
--- @param pos point The point to transform from the curve editor's coordinate space to the graph area's coordinate space.
--- @return point The transformed point in the graph area's coordinate space.
---
function XCurveEditor:TransformPoint(pos)
	local draw_box = self:GetGraphBox()
	local ranges = self:GetRange()
	local base = point(draw_box:minx(), draw_box:maxy())

	pos = pos - self:GetRangeMin()
	pos = point(pos:x(), -pos:y())
	return base + MulDivRoundPoint(draw_box:size(), pos, ranges)
end

local function FitScaleTexts(min_value, max_value, display_scale, size_getter, available_space, min_space_between)
	local begin_text = FormatNumberProp(min_value, display_scale, 2)
	local end_text = FormatNumberProp(max_value, display_scale, 2)
	local text_list = {}
	local secondary_axis_length = 0

	local function subdivide(left_value, right_value, left_pos, right_pos)
		left_pos = left_pos + min_space_between
		right_pos = right_pos - min_space_between
		local diff = right_pos - left_pos
		if diff <= 10 then -- do not attempt to add text if we have less than 10 pixels
			return
		end
		local target_value = (left_value + right_value) / 2
		local text = FormatNumberProp(target_value, display_scale, 2)
		local size, secondary_len = size_getter(text)
		if size > diff then
			return
		end
		secondary_axis_length = Max(secondary_axis_length, secondary_len)
		table.insert(text_list, text)
		local mid = left_pos + diff / 2
		table.insert(text_list, mid - size / 2)

		subdivide(left_value, target_value, left_pos, mid - size / 2)
		subdivide(target_value, right_value, mid + size / 2, right_pos)
	end
	local begin_text_size, secondary_len1 = size_getter(begin_text)
	local end_text_size, secondary_len2 = size_getter(end_text)
	secondary_axis_length = Max(secondary_axis_length, Max(secondary_len1, secondary_len2))

	table.insert(text_list, begin_text)
	table.insert(text_list, 0)
	subdivide(min_value, max_value, 0, available_space)
	table.insert(text_list, end_text)
	table.insert(text_list, available_space - end_text_size)

	return text_list, secondary_axis_length
end

---
--- Lays out the XCurveEditor window and generates the scale texts.
---
--- @param x number The x-coordinate of the window.
--- @param y number The y-coordinate of the window.
--- @param width number The width of the window.
--- @param height number The height of the window.
--- @return boolean The return value of the parent `XWindow:Layout()` function.
function XCurveEditor:Layout(x, y, width, height)
	local ret = XWindow.Layout(self, x, y, width, height)
	self:GenerateTexts()
	return ret
end

---
--- Generates the scale texts for the XCurveEditor window.
---
--- This function is responsible for calculating the layout and positioning of the scale texts
--- that are displayed along the X and Y axes of the XCurveEditor window. It determines the
--- appropriate font size, text spacing, and positioning based on the available space in the
--- content box of the window.
---
--- @param self XCurveEditor The XCurveEditor instance.
--- @return boolean The return value of the parent `XWindow:Layout()` function.
function XCurveEditor:GenerateTexts()
	self.font_id = TextStyles.GedDefault:GetFontIdHeightBaseline(self.scale:y())
	self.text_space_required = point(0, 0)

	local _, font_height = UIL.MeasureText("AQj", self.font_id)
	local vertical_texts, min_width = FitScaleTexts(self.MinY, self.MaxY, self.DisplayScaleY, function(str)
		local width, height = UIL.MeasureText(str, self.font_id)
		return height, width
	end, self.content_box:sizey() - font_height, 10)
	local horizontal_texts = FitScaleTexts(0, self.MaxX, self.DisplayScaleX, function(str)
		local width, height = UIL.MeasureText(str, self.font_id)
		return width, height
	end, self.content_box:sizex() - min_width, 10)

	self.text_space_required = point(min_width, font_height)
	local graph_box = self:GetGraphBox()
	local content_box_min = self.content_box:min()

	self.scale_texts = {}
	for i = 2, #vertical_texts, 2 do
		local start_pos = point(graph_box:maxx(), graph_box:maxy() - vertical_texts[i] - font_height) - content_box_min
		vertical_texts[i] = sizebox(start_pos, point(UIL.MeasureText(vertical_texts[i - 1], self.font_id)))
	end
	for i = 2, #horizontal_texts, 2 do
		local start_pos = point(graph_box:minx() + horizontal_texts[i], graph_box:maxy()) - content_box_min
		horizontal_texts[i] = sizebox(start_pos, point(UIL.MeasureText(horizontal_texts[i - 1], self.font_id)))
	end

	table.iappend(vertical_texts, horizontal_texts)
	self.scale_texts = vertical_texts
end


local function min_point(a, b)
	return point(Min(a:x(), b:x()), Min(a:y(), b:y()), Min(a:z(), b:z()))
end
local function max_point(a, b)
	return point(Max(a:x(), b:x()), Max(a:y(), b:y()), Max(a:z(), b:z()))
end
---
--- Moves a control point in the XCurveEditor.
---
--- This function is responsible for moving a control point in the XCurveEditor. It ensures that the
--- point is snapped to the nearest grid position, and that the point does not go outside the valid
--- range of the curve. If the `PushPointsOnMove` option is enabled, it will also push any other
--- points that are affected by the move.
---
--- @param index number The index of the control point to move.
--- @param pos point The new position for the control point.
--- @return point The final position of the moved control point.
function XCurveEditor:MovePoint(index, pos)
	local z = pos:z()
	assert(z and type(z) == "number")
	local points = self.points
	assert(index >= 1 and index <= self.ControlPoints and index <= #points)

	local old_pos = points[index]
	local min_pos = self:GetRangeMin()
	local max_pos = self:GetRangeMax()

	if self.FixedX or index == 1 or index == #points then
		min_pos = min_pos:SetX(old_pos:x())
		max_pos = max_pos:SetX(old_pos:x())
	end

	if not self.PushPointsOnMove then
		if index > 1 then
			min_pos = max_point(min_pos, points[index - 1])
		end
		if index < #point then
			max_pos = min_point(max_pos, points[index + 1])
		end
	end

	pos = point((pos:x() + self.SnapX / 2) / self.SnapX * self.SnapX,
				(pos:y() + self.SnapY / 2) / self.SnapY * self.SnapY,
				(pos:z() + self.SnapY / 2) / self.SnapY * self.SnapY)

	pos = min_point(max_point(pos, min_pos), max_pos)
	points[index] = pos

	if self.PushPointsOnMove and not self.FixedX then
		for i = 1, index - 1 do
			if points[i]:x() > pos:x() then
				points[i] = points[i]:SetX(pos:x())
			end
		end
		for i = index + 1, #points do
			if points[i]:x() < pos:x() then
				points[i] = points[i]:SetX(pos:x())
			end
		end
	end

	if self.OnCurveChanged and old_pos ~= pos then
		self.OnCurveChanged(self)
		self:Invalidate()
	end

	return pos
end


---
--- Handles mouse button down events for the XCurveEditor.
---
--- When the left mouse button is pressed, this function captures the currently hovered handle and sets the mouse capture to the XCurveEditor. It then calls `OnMousePos` to update the position of the captured handle.
---
--- @param pt table The current mouse position.
--- @param button string The mouse button that was pressed ("L" for left, "R" for right, etc.).
--- @return string "break" to indicate the event has been handled.
function XCurveEditor:OnMouseButtonDown(pt, button)
	if button == "L" then
		self.capture_handle = self.hover_handle
		self:SetFocus()
		self.desktop:SetMouseCapture(self)
		self:OnMousePos(pt)
		return "break"
	end
end

---
--- Handles the rollover state of the XCurveEditor control.
---
--- When the rollover state changes, this function updates the `hover_handle` property and invalidates the control to trigger a redraw.
---
--- @param rollover boolean Whether the control is currently in a rollover state.
---
function XCurveEditor:OnSetRollover(rollover)
	XControl.OnSetRollover(self, rollover)
	if not rollover then
		self.hover_handle = false
		self:Invalidate()
	end
end

---
--- Handles mouse button up events for the XCurveEditor.
---
--- When the left mouse button is released, this function releases the captured handle, updates the position of the captured handle, releases the mouse capture, and invalidates the control to trigger a redraw.
---
--- @param pt table The current mouse position.
--- @param button string The mouse button that was released ("L" for left, "R" for right, etc.).
--- @return string "break" to indicate the event has been handled.
function XCurveEditor:OnMouseButtonUp(pt, button)
	if button == "L" then
		self.capture_handle = false
		self:OnMousePos(pt)
		self.desktop:SetMouseCapture()
		self:Invalidate()
		return "break"
	end
end

---
--- Gets the handle that is currently hovered over by the mouse pointer.
---
--- This function iterates through all the point handles in the XCurveEditor and calculates the distance between each handle and the current mouse position. It returns the handle with the smallest distance, as long as the distance is within a certain threshold. If no handle is close enough to the mouse, it returns `false`.
---
--- @param pt table The current mouse position.
--- @return table|boolean The hovered handle, or `false` if no handle is hovered.
function XCurveEditor:GetHoveredHandle(pt)
	local handles = self.point_handles
	local best_handle = -1
	local best_dist = 999999
	for i, handle in ipairs(handles) do
		local dist = handle:HoverScore(self:TransformPoint(handle:GetPos()), pt)
		if dist < best_dist then
			best_handle = handle
			best_dist = dist
		end
	end

	local max_dist = ScaleXY(self.scale, self.ControlPointMaxDist)
	if best_dist < max_dist * max_dist then
		return best_handle
	end
	return false
end

---
--- Handles mouse position events for the XCurveEditor.
---
--- This function is called when the mouse pointer moves within the XCurveEditor control. It updates the `hover_handle` property to indicate which handle, if any, is currently being hovered over by the mouse. If the mouse capture is owned by this control, it updates the position of the captured handle to match the current mouse position.
---
--- @param pt table The current mouse position.
--- @return string "break" to indicate the event has been handled.
function XCurveEditor:OnMousePos(pt)
	local old_hover = self.hover_handle
	self.hover_handle = self:GetHoveredHandle(pt)
	if old_hover ~= self.hover_handle then
		self:Invalidate()
	end
	if self.desktop:GetMouseCapture() ~= self then 
		self.capture_handle = false
		return "break"
	end
	if not self.capture_handle then
		return "break"
	end
	if self.ReadOnly then 
		return "break"
	end
	local content_box = self:GetGraphBox()
	local pos = self:GetRangeMin() + MulDivRoundPoint(point(pt:x() - content_box:minx(), content_box:maxy() - pt:y()), self:GetRange(), content_box:size())
	self.capture_handle:SetPos(pos)
	return "break"
end

local function RoundUp(x, alignment)
	if x % alignment == 0 then return x end
	return (x / alignment) * alignment + alignment
end

---
--- Draws a grid overlay on the XCurveEditor control.
---
--- The grid is drawn using horizontal and vertical lines spaced according to the `GridUnitX` and `GridUnitY` properties. The grid lines are drawn from the minimum to the maximum values of the curve, as defined by the `GetRangeMin()` and `GetRangeMax()` methods.
---
--- The color of the grid lines is defined by the `GridColor` property.
---
--- @param self XCurveEditor The XCurveEditor instance.
function XCurveEditor:DrawGrid()
	local range = self:GetRange()
	local max_values = self:GetRangeMax()
	local min_values = self:GetRangeMin()
	
	if self.GridUnitX > 0 then
		for x = RoundUp(min_values:x(), self.GridUnitX), max_values:x(), self.GridUnitX do
			UIL.DrawLine(self:TransformPoint(point(x, min_values:y())), self:TransformPoint(point(x, max_values:y())), self.GridColor)
		end
	end
	if self.GridUnitY > 0 then
		for y = RoundUp(min_values:y(), self.GridUnitY), max_values:y(), self.GridUnitY do
			UIL.DrawLine(self:TransformPoint(point(min_values:x(), y)), self:TransformPoint(point(max_values:x(), y)), self.GridColor)
		end
	end
end

---
--- Draws the control points for the curve editor.
---
--- The control points are drawn as circles with a size defined by the `GetControlPointSize()` method. The color of the control points is determined by their state:
--- - Normal: `ControlPointColor`
--- - Hovered: `ControlPointHoverColor`
--- - Captured: `ControlPointCaptureColor`
---
--- The control points are positioned based on the `points` table, which contains the curve data. The control points are drawn within the `graph_box` area of the curve editor.
---
--- @param self XCurveEditor The XCurveEditor instance.
function XCurveEditor:DrawControlPoints()
	local graph_box = self:GetGraphBox()
	local base = point(graph_box:minx(), graph_box:maxy())
	local points = self.points
	local size = self:GetControlPointSize() / 2

	for idx = 1, #self.point_handles do
		local handle = self.point_handles[idx]
		local color = self.ControlPointColor
		if handle:IsCaptured() then
			color = self.ControlPointCaptureColor
		elseif handle:IsHovered() then
			color = self.ControlPointHoverColor
		end
		
		local pixel_pos = self:TransformPoint(handle:GetPos(true))
		handle:Draw(graph_box, base, size, color, pixel_pos)
	end
end

---
--- Draws the background of the graph area in the XCurveEditor.
---
--- This function is responsible for rendering the background of the graph area, which typically includes a grid or other visual elements to help the user understand the coordinate system and scale of the curve being edited.
---
--- @param self XCurveEditor The XCurveEditor instance.
--- @param graph_box sizebox The bounding box of the graph area.
--- @param points table A table of points representing the curve being edited.
---
function XCurveEditor:DrawGraphBackground(graph_box, points)

end

---
--- Draws the scale texts for the XCurveEditor.
---
--- This function is responsible for rendering the scale texts that indicate the values along the x and y axes of the curve editor. It will display the current value of the captured control point if one is being dragged.
---
--- The scale texts are positioned within the `graph_box` area of the curve editor, and their color is determined by the `CurveColor` property of the XCurveEditor instance.
---
--- @param self XCurveEditor The XCurveEditor instance.
function XCurveEditor:DrawScaleTexts()
	--display current value whiel dragging
	if self.capture_handle then
		local pos = self.capture_handle:GetPos()
		local graph_box = self:GetGraphBox()
		
		local x_pos_text = FormatNumberProp(pos:x(), self.DisplayScaleX, 2)
		local x_pos_text_size = point(UIL.MeasureText(x_pos_text, self.font_id))
		local y_pos_text = FormatNumberProp(pos:y(), self.DisplayScaleY, 2)
		local y_pos_text_size = point(UIL.MeasureText(y_pos_text, self.font_id))
		local pixel_pos = self:TransformPoint(pos)
		
		local draw_text_x = Min(Max(pixel_pos:x() - x_pos_text_size:x() / 2, 0), graph_box:maxx() - x_pos_text_size:x())
		UIL.StretchText(x_pos_text, sizebox(point(draw_text_x, graph_box:maxy()), x_pos_text_size), self.font_id, self.CurveColor)
		local draw_text_y = Min(Max(pixel_pos:y() - x_pos_text_size:y() / 2, 0), graph_box:maxy() - x_pos_text_size:y())
		UIL.StretchText(y_pos_text, sizebox(point(graph_box:maxx(), draw_text_y), y_pos_text_size), self.font_id, self.CurveColor)
		return
	end

	local content_box_min = self.content_box:min()
	-- draw static texts. Cached and recalcualted only when needed as we might need to do more complex logic to decide out what to render and where
	local texts = self.scale_texts
	if not texts then
		self:GenerateTexts()
		texts = self.scale_texts
	end
	if texts then
		local StretchText = UIL.StretchText
		for i = 1, #texts, 2 do
			StretchText(texts[i], Offset(texts[i + 1], content_box_min), self.font_id, self.CurveColor)
		end
	end
end

local function DrawCurveWithPoints(smooth, points, color)
	if smooth then
		local step = 3
		local last_pt = points[1]
		for i = 1, #points - 1 do
			local left_pt_prev = points[i - 1] or points[i]
			local left_pt = points[i]
			local right_pt = points[i + 1]
			local diff_x = right_pt:x() - left_pt:x()
			local right_pt_next = points[i + 2] or points[i + 1]
			for x = left_pt:x() + step, right_pt:x(), step do
				--TODO: Use some other sample func
				local pt = CatmullRomSpline(left_pt_prev, left_pt, right_pt, right_pt_next, MulDivRound(x - left_pt:x(), 1000, diff_x ), 1000)
				pt = pt:SetX(x)
				UIL.DrawLine(last_pt, pt, color)
				last_pt = pt
			end
		end
	else
		local last_pt = points[1]
		for i = 2, #points do
			local pt = points[i]
			UIL.DrawLine(last_pt, pt, color)
			last_pt = pt
		end
	end
end
---
--- Draws the curve and associated elements in the graph box of the XCurveEditor.
---
--- This function is responsible for rendering the curve itself, as well as any additional
--- visual elements related to the curve, such as the min/max range mode curve.
---
--- @param self XCurveEditor The XCurveEditor instance.
---
function XCurveEditor:DrawCurve()
	assert(self.points[1]:z())
	local graph = self:GetGraphBox()
	local points = {}
	for key, value in ipairs(self.points) do
		points[key] = self:TransformPoint(value)
	end
	DrawCurveWithPoints(self.Smooth, points, self.CurveColor)
	if self.MinMaxRangeMode then
		points = {}
		for key, value in ipairs(self.points) do
			points[key] = self:TransformPoint(point(value:x(), value:z()))
		end
		DrawCurveWithPoints(self.Smooth, points, self.CurveColor)
	end

	UIL.DrawLine(point(graph:maxx(), graph:miny()), graph:max(), self.CurveColor)
	UIL.DrawLine(point(graph:minx(), graph:maxy()), graph:max(), self.CurveColor)
end

---
--- Draws the content of the XCurveEditor, including the graph background, grid, curve, control points, and scale texts.
---
--- This function is responsible for rendering the entire visual representation of the XCurveEditor, including all its
--- graphical elements.
---
--- @param self XCurveEditor The XCurveEditor instance.
---
function XCurveEditor:DrawContent()
	local graph_box = self:GetGraphBox()
	self:DrawGraphBackground(graph_box, self.points)
	self:DrawGrid()
	self:DrawCurve()
	self:DrawControlPoints()

	self:DrawScaleTexts()
end

---
--- Ensures that all points in the XCurveEditor are within the valid range.
---
--- This function iterates through all the points in the XCurveEditor and clamps each point
--- to the minimum and maximum values defined by the XCurveEditor's range. The first and
--- last points are also set to the minimum and maximum X values, respectively.
---
--- @param self XCurveEditor The XCurveEditor instance.
---
function XCurveEditor:ValidatePoints()
	for i = 1, #self.points do
		local pt = self.points[i]
		self.points[i] = max_point(min_point(pt, self:GetRangeMax()), self:GetRangeMin())
	end
	self.points[1] = self.points[1]:SetX(self.MinX)
	self.points[#self.points] = self.points[#self.points]:SetX(self.MaxX)
end

------------ XCurveEditorHandle -------------
-- Spec of movable UI elements in the graph

DefineClass.XCurveEditorHandle = {
	__parents = {"PropertyObject"},

	type = false,
	point_idx = false,
	curve_editor = false,
	box = false,
	parent = false,
}

---
--- Sets the position of the XCurveEditorHandle to the specified point.
---
--- This function updates the position of the XCurveEditorHandle by modifying the corresponding point in the XCurveEditor's points table. It calculates a new point with the same X coordinate as the specified point, but with a Y coordinate that is the average of the old point's Y and Z coordinates.
---
--- @param self XCurveEditorHandle The XCurveEditorHandle instance.
--- @param pt point The new position for the handle.
--- @return point The new position of the handle after it has been updated.
---
function XCurveEditorHandle:SetPos(pt)
	local old_pt = self.curve_editor.points[self.point_idx]
	local height = (old_pt:z() - old_pt:y()) / 2
	local new_point = point(pt:x(), pt:y() - height, pt:y() + height)

	self.curve_editor:MovePoint(self.point_idx, new_point)
	return self:GetPos("refetch")
end

---
--- Gets the current position of the XCurveEditorHandle.
---
--- This function returns the current position of the XCurveEditorHandle as a `point` object. The position is calculated by taking the average of the Y and Z coordinates of the corresponding point in the XCurveEditor's points table.
---
--- @param self XCurveEditorHandle The XCurveEditorHandle instance.
--- @param refetch boolean (optional) If true, the position is refetched from the XCurveEditor's points table.
--- @return point The current position of the XCurveEditorHandle.
---
function XCurveEditorHandle:GetPos(refetch)
	local pt = self.curve_editor.points[self.point_idx]
	return point(pt:x(), (pt:y() + pt:z()) / 2)
end

---
--- Gets the bounding box of the XCurveEditorHandle.
---
--- This function calculates the bounding box of the XCurveEditorHandle based on the position of the corresponding point in the XCurveEditor's points table. The size of the bounding box depends on whether the XCurveEditor is in MinMaxRangeMode or not.
---
--- @param self XCurveEditorHandle The XCurveEditorHandle instance.
--- @return box The bounding box of the XCurveEditorHandle.
---
function XCurveEditorHandle:GetBox()
	local old_pt = self.curve_editor.points[self.point_idx]
	if self.curve_editor.MinMaxRangeMode then
		local height = (old_pt:z() - old_pt:y())
		local height_in_pixels = MulDivRound(height, self.curve_editor:GetGraphBox():sizey(), self.curve_editor:GetRange():y())
		local half_control_point_width = self.curve_editor:GetControlPointSize():x() / 4
		local pixel_pos = self.curve_editor:TransformPoint(old_pt)
		self.box = box(point(pixel_pos:x() - half_control_point_width, pixel_pos:y() - height_in_pixels),
					   point(pixel_pos:x() + half_control_point_width, pixel_pos:y()))
	else
		local half_control_point_width = self.curve_editor:GetControlPointSize():x() / 2
		local pixel_pos = self.curve_editor:TransformPoint(old_pt)
		self.box = box(point(pixel_pos:x() - half_control_point_width, pixel_pos:y() - half_control_point_width),
					   point(pixel_pos:x() + half_control_point_width, pixel_pos:y() + half_control_point_width))
	end
	return self.box
end

---
--- Calculates a "hover score" for the XCurveEditorHandle based on the distance between the handle's position and the mouse position.
---
--- If the Shift key is pressed, the hover score is set to a very high value (1000000) to ensure the handle is always selected.
---
--- Otherwise, the hover score is calculated as the squared distance between the handle's position and the mouse position. If the mouse position is within a 10x10 pixel box around the handle, the hover score is set to 0 to indicate the handle is being hovered over.
---
--- @param self XCurveEditorHandle The XCurveEditorHandle instance.
--- @param self_pt point The current position of the XCurveEditorHandle.
--- @param mouse_pt point The current position of the mouse cursor.
--- @return number The hover score for the XCurveEditorHandle.
function XCurveEditorHandle:HoverScore(self_pt, mouse_pt)
	if terminal.IsKeyPressed(const.vkShift) then
		return 1000000
	end

	local is = self:GetBox():Intersect(box(mouse_pt - point(10, 10), mouse_pt + point(10, 10)))
	if is ~= const.irOutside then
		return 0
	end
	
	return mouse_pt:Dist2(self_pt)
end

---
--- Draws the XCurveEditorHandle on the graph.
---
--- This function draws a solid rectangle representing the XCurveEditorHandle on the graph. The size and position of the rectangle are determined by the bounding box of the handle, which is calculated in the `XCurveEditorHandle:GetBox()` function. The color of the rectangle is specified by the `color` parameter.
---
--- @param self XCurveEditorHandle The XCurveEditorHandle instance.
--- @param graph_box box The bounding box of the graph.
--- @param base point The base position of the graph.
--- @param size point The size of the handle.
--- @param color color The color of the handle.
--- @param pixel_pos point The position of the handle in pixel coordinates.
---
function XCurveEditorHandle:Draw(graph_box, base, size, color, pixel_pos)
	UIL.DrawSolidRect(self:GetBox(), color)
end

DefineClass.XCurveEditorMinHandle = {
	__parents = {"XCurveEditorHandle"},
}

---
--- Sets the position of the XCurveEditorMinHandle.
---
--- This function updates the position of the XCurveEditorMinHandle by modifying the corresponding point in the curve editor's points array. The new point is created by taking the x-coordinate from the provided `pt` parameter, and the minimum of the y-coordinate from the `pt` parameter and the z-coordinate of the old point. The z-coordinate of the old point is preserved in the new point.
---
--- After updating the point, the function calls `self.curve_editor:MovePoint()` to notify the curve editor of the position change, and then returns the new position of the handle by calling `self:GetPos("refetch")`.
---
--- @param self XCurveEditorMinHandle The XCurveEditorMinHandle instance.
--- @param pt point The new position for the handle.
--- @return point The new position of the handle.
function XCurveEditorMinHandle:SetPos(pt)
	local old_pt = self.curve_editor.points[self.point_idx]
	local new_pt = point(pt:x(), Min(pt:y(), old_pt:z()), old_pt:z())

	self.curve_editor:MovePoint(self.point_idx, new_pt)
	return self:GetPos("refetch")
end

---
--- Checks if the XCurveEditorHandle is currently captured.
---
--- This function checks if the XCurveEditorHandle instance is currently captured by the curve editor. It does this by traversing the parent hierarchy of the handle, starting from the current handle, and checking if the `curve_editor.capture_handle` property matches the current handle or any of its parents.
---
--- @param self XCurveEditorHandle The XCurveEditorHandle instance.
--- @return boolean True if the handle is currently captured, false otherwise.
function XCurveEditorHandle:IsCaptured()
	local capture = self.curve_editor.capture_handle
	local current = self
	while current do
		if capture == current then return true end
		current = current.parent
	end
	return false
end

---
--- Checks if the XCurveEditorHandle is currently hovered over.
---
--- This function checks if the XCurveEditorHandle instance is currently hovered over by the curve editor. It does this by traversing the parent hierarchy of the handle, starting from the current handle, and checking if the `curve_editor.hover_handle` property matches the current handle or any of its parents.
---
--- @param self XCurveEditorHandle The XCurveEditorHandle instance.
--- @return boolean True if the handle is currently hovered over, false otherwise.
function XCurveEditorHandle:IsHovered()
	local capture = self.curve_editor.hover_handle
	local current = self
	while current do
		if capture == current then return true end
		current = current.parent
	end
	return false
end

---
--- Returns the current position of the XCurveEditorMinHandle.
---
--- This function retrieves the current position of the XCurveEditorMinHandle by accessing the `points` array of the associated `curve_editor` object and returning a `point` object with the x and y coordinates of the point at the `point_idx` index.
---
--- @param self XCurveEditorMinHandle The XCurveEditorMinHandle instance.
--- @param refetch boolean (unused) Indicates whether to refetch the position.
--- @return point The current position of the handle.
function XCurveEditorMinHandle:GetPos(refetch)
	local pt = self.curve_editor.points[self.point_idx]
	return point(pt:x(), pt:y())
end


---
--- Calculates the hover score for the XCurveEditorMaxHandle.
---
--- The hover score is calculated as the squared distance between the given `self_pt` and `mouse_pt`. This is used to determine how close the mouse cursor is to the handle, which is used for hover detection.
---
--- @param self XCurveEditorMaxHandle The XCurveEditorMaxHandle instance.
--- @param self_pt point The current position of the handle.
--- @param mouse_pt point The current position of the mouse cursor.
--- @return number The hover score, which is the squared distance between the handle and the mouse cursor.
function XCurveEditorMinHandle:HoverScore(self_pt, mouse_pt)
	return mouse_pt:Dist2(self_pt)
end

---
--- Draws the XCurveEditorMinHandle on the graph.
---
--- This function draws a solid rectangle representing the XCurveEditorMinHandle on the graph. The rectangle is positioned at the `pixel_pos` coordinate and has a size of `size`. The color of the rectangle is specified by the `color` parameter.
---
--- @param self XCurveEditorMinHandle The XCurveEditorMinHandle instance.
--- @param graph_box box The bounding box of the graph.
--- @param base number The base position of the graph.
--- @param size number The size of the handle.
--- @param color color The color of the handle.
--- @param pixel_pos point The pixel position of the handle.
function XCurveEditorMinHandle:Draw(graph_box, base, size, color, pixel_pos)
	UIL.DrawSolidRect(box(pixel_pos - size, pixel_pos + size), color)
end


DefineClass.XCurveEditorMaxHandle = {
	__parents = {"XCurveEditorHandle"},
}

---
--- Sets the position of the XCurveEditorMaxHandle.
---
--- This function updates the position of the XCurveEditorMaxHandle by modifying the corresponding point in the `points` array of the associated `curve_editor` object. The new point's x-coordinate is set to the x-coordinate of the provided `pt` parameter, while the y-coordinate is set to the maximum of the y-coordinate of the provided `pt` parameter and the existing y-coordinate of the point.
---
--- @param self XCurveEditorMaxHandle The XCurveEditorMaxHandle instance.
--- @param pt point The new position for the handle.
--- @return point The current position of the handle after the update.
function XCurveEditorMaxHandle:SetPos(pt)
	local old_pt = self.curve_editor.points[self.point_idx]
	local new_pt = point(pt:x(), old_pt:y(), Max(pt:y(), old_pt:y()))

	self.curve_editor:MovePoint(self.point_idx, new_pt)
	return self:GetPos("refetch")
end

---
--- Gets the current position of the XCurveEditorMaxHandle.
---
--- This function returns the current position of the XCurveEditorMaxHandle as a point with the x-coordinate set to the x-coordinate of the corresponding point in the `points` array of the associated `curve_editor` object, and the y-coordinate set to the z-coordinate of the same point.
---
--- @param self XCurveEditorMaxHandle The XCurveEditorMaxHandle instance.
--- @param refetch boolean (optional) If true, the position is re-fetched from the `curve_editor` object.
--- @return point The current position of the handle.
function XCurveEditorMaxHandle:GetPos(refetch)
	local pt = self.curve_editor.points[self.point_idx]
	return point(pt:x(), pt:z())
end


---
--- Calculates the hover score for the XCurveEditorMaxHandle.
---
--- This function calculates the hover score for the XCurveEditorMaxHandle by computing the squared distance between the provided `self_pt` and `mouse_pt` points. The smaller the distance, the higher the hover score, indicating that the mouse is closer to the handle.
---
--- @param self XCurveEditorMaxHandle The XCurveEditorMaxHandle instance.
--- @param self_pt point The position of the handle.
--- @param mouse_pt point The current mouse position.
--- @return number The hover score for the handle.
function XCurveEditorMaxHandle:HoverScore(self_pt, mouse_pt)
	return mouse_pt:Dist2(self_pt)
end

---
--- Draws the XCurveEditorMaxHandle on the graph.
---
--- This function draws a solid rectangle representing the XCurveEditorMaxHandle on the graph. The rectangle is centered at the handle's pixel position, with a size specified by the `size` parameter. The color of the rectangle is specified by the `color` parameter.
---
--- @param self XCurveEditorMaxHandle The XCurveEditorMaxHandle instance.
--- @param graph_box box The bounding box of the graph.
--- @param base point The base position of the graph.
--- @param size point The size of the handle.
--- @param color color The color of the handle.
--- @param pixel_pos point The pixel position of the handle.
function XCurveEditorMaxHandle:Draw(graph_box, base, size, color, pixel_pos)
	UIL.DrawSolidRect(box(pixel_pos - size, pixel_pos + size), color)
end


DefineClass.TestPicker = {
	__parents = {"PropertyObject"},
	properties = {
		{id = "test1", editor = "packedcurve", default = PackCurveParams(point(0, 127000), point(40000, 0), point(80000, 255000), point(255000, 0)),}
	}
}
