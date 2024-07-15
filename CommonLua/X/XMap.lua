local UIL = UIL
DefineClass.XMap = {
	__parents = { "XControl" },
	
	properties = {
		{ id = "UseCustomTime", editor = "bool", default = true, help = "If true, map object animations are done in Lua time, which is read from hr.UIL_CustomTime." },
		{ id = "map_size", name = "Map Size", editor = "point2d", default = point(1000, 1000) },
	},
	
	Clip = "self",
	UseClipBox = false, -- Disable UIL level clipping of children. Renderer will clip.
	MouseCursor = "UI/Cursors/Pda_Cursor.tga",
	
	translation_modId = 0,
	scale_modId = 1,

	scroll_start_pt = false,
	last_box = false,
	last_current_scale = false,
	last_scale = false,

	MouseWheelStep = 300,
	
	map_time_reference = false,
	real_time_reference = false,
	time_factor = 1000,
	
	max_zoom = 5000,
	
	rollover_padding = 15
}

--- Initializes the XMap object.
-- This function sets up the initial state of the XMap object, including the translation and scale parameters, and adds an interpolation modifier to the object.
-- The function also initializes the `map_time_reference` and `real_time_reference` properties, which are used for tracking time-related aspects of the map.
function XMap:Init()
	local mapModifier = {
		id = "map-window",
		type = const.intParamRect,
		translateParam = self.translation_modId,
		scaleParam = self.scale_modId,
		interpolate_clip = false
	}
	-- Reset params
	UIL.SetParam(self.translation_modId, 0, 0, 0)
	UIL.SetParam(self.scale_modId, 1000, 1000, 0)
	self:AddInterpolation(mapModifier)
	self.map_time_reference = 0
	self.real_time_reference = GetPreciseTicks()
end

--- Scrolls the map by the specified delta values.
-- @param dx The horizontal scroll delta.
-- @param dy The vertical scroll delta.
-- @param time The duration of the scroll animation in milliseconds.
-- @param int Whether the scroll should be interpolated.
-- @return The updated translation parameters.
function XMap:ScrollMap(dx, dy, time, int)
	local transX, transY = UIL.GetParam(self.translation_modId, "end")
	return self:SetMapScroll(transX + dx, transY + dy, time, int)
end

--- Sets the map scroll to the specified translation coordinates.
-- Clamps the translation to the map bounds based on the current scale.
-- @param transX The horizontal translation coordinate.
-- @param transY The vertical translation coordinate.
-- @param time The duration of the scroll animation in milliseconds (optional).
-- @param int Whether the scroll should be interpolated (optional).
-- @return The updated translation parameters.
function XMap:SetMapScroll(transX, transY, time, int)
	-- Clamp to map bounds.
	local scale = UIL.GetParam(self.scale_modId, "end")
	local win_box = self.box
	transX = Clamp(transX, - self.map_size:x() * scale / 1000 + win_box:maxx() + 1, win_box:minx())
	transY = Clamp(transY, - self.map_size:y() * scale / 1000 + win_box:maxy() + 1, win_box:miny())
	UIL.SetParam(self.translation_modId, transX, transY, time or 100, int)
end

--- Centers the map scroll on the specified coordinates.
-- @param x The x-coordinate to center on.
-- @param y The y-coordinate to center on.
-- @param time The duration of the scroll animation in milliseconds.
function XMap:CenterScrollOn(x, y, time)
	local scaleX, scaleY = UIL.GetParam(self.scale_modId, "end")
	x = MulDivRound(x, scaleX, 1000)
	y = MulDivRound(y, scaleY, 1000)
	local winSize = self.box:size()
	self:SetMapScroll(winSize:x() / 2 - x, winSize:y() / 2 - y, time)
end

--- Zooms the map by the specified scale factor.
-- @param scale The scale factor to zoom by. Positive values zoom in, negative values zoom out.
-- @param time The duration of the zoom animation in milliseconds (optional).
-- @param origin_pos The point on the map to use as the zoom origin (optional).
-- @return The updated scale parameters.
function XMap:ZoomMap(scale, time, origin_pos)
	return self:SetMapZoom(UIL.GetParam(self.scale_modId, "end") + scale, time, origin_pos)
end

--- Gets the maximum zoom scale for the map, scaled by the current map scale.
-- @return The maximum zoom scale for the map.
function XMap:GetScaledMaxZoom()
	return MulDivRound(self.max_zoom, self.scale:x(), 1000)
end

--- Sets the map zoom to the specified scale.
-- Clamps the scale to the minimum and maximum allowed values.
-- If an origin position is provided, the map will be scrolled to keep that point centered.
-- @param scale The new scale factor for the map.
-- @param time The duration of the zoom animation in milliseconds (optional).
-- @param origin_pos The point on the map to use as the zoom origin (optional).
-- @return The updated scale parameters.
function XMap:SetMapZoom(scale, time, origin_pos)
	local current_scale = UIL.GetParam(self.scale_modId)
	local min_scale = Max(1000 * self.box:sizex() / self.map_size:x(), 1000 * self.box:sizey() / self.map_size:y())
	scale = Clamp(scale, min_scale, self:GetScaledMaxZoom())
	time = time or 100
	UIL.SetParam(self.scale_modId, scale, scale, time)
	if origin_pos then
		local transX, transY = UIL.GetParam(self.translation_modId)
		local dx = origin_pos:x() - MulDivRound(origin_pos:x() - transX, scale, current_scale)
		local dy = origin_pos:y() - MulDivRound(origin_pos:y() - transY, scale, current_scale)
		self:SetMapScroll(dx, dy, time)
	end

	self.last_scale = current_scale
	self.current_scale = scale
	for _, win in ipairs(self) do
		if win.UpdateZoom then
			win:UpdateZoom(current_scale, scale, time)
		end
	end
end

--- Converts a map position to a screen position.
-- @param pos The map position to convert.
-- @param time The time in milliseconds for the conversion animation (optional).
-- @return The screen position corresponding to the given map position.
function XMap:MapToScreenPt(pos, time)
	local scaleX, scaleY = UIL.GetParam(self.scale_modId, time)
	local transX, transY = UIL.GetParam(self.translation_modId, time)

	return point(
		MulDivRound(pos:x(), scaleX, 1000) + transX,
		MulDivRound(pos:y(), scaleY, 1000) + transY
	)
end

--- Converts a map box to a screen box.
-- @param b The map box to convert.
-- @param time The time in milliseconds for the conversion animation (optional).
-- @return The screen box corresponding to the given map box.
function XMap:MapToScreenBox(b, time)
	local scaleX, scaleY = UIL.GetParam(self.scale_modId, time)
	local transX, transY = UIL.GetParam(self.translation_modId, time)

	return box(
		MulDivRound(b:minx(), scaleX, 1000) + transX,
		MulDivRound(b:miny(), scaleY, 1000) + transY,
		MulDivRound(b:maxx(), scaleX, 1000) + transX,
		MulDivRound(b:maxy(), scaleY, 1000) + transY
	)
end

--- Converts a screen position to a map position.
-- @param pos The screen position to convert.
-- @param time The time in milliseconds for the conversion animation (optional).
-- @return The map position corresponding to the given screen position.
function XMap:ScreenToMapPt(pos, time)
	local scaleX, scaleY = UIL.GetParam(self.scale_modId, time)
	local transX, transY = UIL.GetParam(self.translation_modId, time)

	return point(
		MulDivRound(pos:x() - transX, 1000, scaleX),
		MulDivRound(pos:y() - transY, 1000, scaleY)
	)
end

--- Converts a screen box to a map box.
-- @param b The screen box to convert.
-- @param time The time in milliseconds for the conversion animation (optional).
-- @return The map box corresponding to the given screen box.
function XMap:ScreenToMapBox(b, time)
	local scaleX, scaleY = UIL.GetParam(self.scale_modId, time)
	local transX, transY = UIL.GetParam(self.translation_modId, time)

	return box(
		MulDivRound(b:minx() - transX, 1000, scaleX),
		MulDivRound(b:miny() - transY, 1000, scaleY),
		MulDivRound(b:maxx() - transX, 1000, scaleX),
		MulDivRound(b:maxy() - transY, 1000, scaleY)
	)
end

-- Don't move children as their positions are relative to the map.
--- Sets the bounding box of the XMap control.
-- This function sets the bounding box of the XMap control, but does not move any child windows.
-- @param x The x-coordinate of the top-left corner of the bounding box.
-- @param y The y-coordinate of the top-left corner of the bounding box.
-- @param width The width of the bounding box.
-- @param height The height of the bounding box.
-- @param move_children (optional) A boolean indicating whether to move the child windows or not. This parameter is ignored in this implementation.
-- @param ... Additional arguments passed to the underlying XWindow.SetBox function.
-- @return The bounding box of the XMap control.
function XMap:SetBox(x, y, width, height, move_children, ...)
	return XWindow.SetBox(self, x, y, width, height, "dont-move", ...)
end

--- Overrides the default layout behavior for the XMap control.
-- This function is used to prevent the default layout method from positioning the child windows of the XMap control. 
-- Instead, the child windows are positioned using the `XMapWindow:SetBox()` function, which sets the bounding box of the child window based on its map space coordinates.
-- This ensures that the child windows are positioned correctly relative to the map, rather than being positioned by the default layout algorithm.
function XMap:Layout(x, y, width, height)
	-- do not use a layout method to position the children, this is already done
end

--- Updates the layout of the XMap control.
-- This function is responsible for positioning the child windows of the XMap control. It iterates over all the child windows and sets the bounding box of each XMapWindow child based on its map space coordinates. This ensures that the child windows are positioned correctly relative to the map, rather than being positioned by the default layout algorithm.
-- After positioning the child windows, the function calls the `XControl.UpdateLayout()` function to update the layout of the XMap control itself.
function XMap:UpdateLayout()
	for _, win in ipairs(self) do
		if IsKindOf(win, "XMapWindow") then
			assert(win.Dock == "ignore") -- XMapWindow children should not participate in the "classical" layout, they are positioned here
			win:SetBox(win:GetMapSpaceBox())
		end
	end
	XControl.UpdateLayout(self)
end

--- Called when the layout of the XMap control is complete.
-- This function is responsible for ensuring that the map area is properly clamped and that the child windows are updated with the correct zoom level.
-- If the bounding box of the XMap control has changed since the last layout, the function forces a reclamping of the map area to ensure that the map is properly positioned within the control.
-- If the bounding box has not changed, the function iterates over the child windows and calls the `UpdateZoom` function on any child windows that have that function, passing in the previous and current zoom levels.
-- This ensures that the child windows are properly updated to reflect the current zoom level of the map.
function XMap:OnLayoutComplete()
	if self.last_box ~= self.box then
		-- Force a reclamp to the map area.
		self:ScrollMap(0, 0, 0)
		self:ZoomMap(0, 0)
		self.last_box = self.box
	else
		-- Children's UpdateZoom needs to be ran after layout.
		for _, win in ipairs(self) do
			if win.UpdateZoom then
				win:UpdateZoom(self.last_scale, self.current_scale, 0)
			end
		end
	end
end

--- Gets the mouse target within the XMap control.
-- @param pt The screen-space point to check for a mouse target.
-- @return The mouse target window, or nil if no target was found.
function XMap:GetMouseTarget(pt)
	return XWindow.GetMouseTarget(self, self:ScreenToMapPt(pt))
end

--- Handles the start of a mouse scroll operation on the XMap control.
-- When the user presses the left or middle mouse button, this function records the starting screen-space position of the mouse cursor and initiates the scroll operation.
-- It also updates the translation modifier ID to ensure that the translation is properly applied during the scroll operation.
-- @param pt The screen-space position of the mouse cursor when the button was pressed.
-- @param button The mouse button that was pressed ("L" for left, "M" for middle).
function XMap:OnMouseButtonDown(pt, button)
	if button == "L" or button == "M" then
		self.scroll_start_pt = pt
		UIL.SetParam(self.translation_modId, UIL.GetParam(self.translation_modId))
		self:ScrollStart()
	end
end

--- Initiates a scroll operation on the XMap control.
-- This function is called when the user presses the left or middle mouse button on the XMap control, indicating the start of a scroll operation.
-- It records the starting screen-space position of the mouse cursor and updates the translation modifier ID to ensure that the translation is properly applied during the scroll operation.
function XMap:ScrollStart()

end

--- Stops the current scroll operation on the XMap control.
-- This function is called when the user releases the left or middle mouse button after initiating a scroll operation.
-- It resets the `scroll_start_pt` property to `false`, indicating that the scroll operation has ended.
function XMap:ScrollStop()
	self.scroll_start_pt = false
end

--- Handles the end of a mouse scroll operation on the XMap control.
-- When the user releases the left or middle mouse button after initiating a scroll operation, this function calculates the inertia of the scroll based on the distance the mouse cursor has moved. It then applies the calculated inertia to the map scroll.
-- @param pt The screen-space position of the mouse cursor when the button was released.
-- @param button The mouse button that was released ("L" for left, "M" for middle).
function XMap:OnMouseButtonUp(pt, button)
	if button == "L" or button == "M" then
		-- Calculations here are based on what feels good, and are not scientific :P
		local prevPos = self:ScreenToMapPt(self.scroll_start_pt or pt)
		local currentPos = self:ScreenToMapPt(pt)
		local diff = (currentPos - prevPos)
		
		local diffClamped = Min(diff:Len(), 500)
		local inertiaPower = Lerp(500, 1, diffClamped, 500) -- boost inertia based on difference
		inertiaPower = inertiaPower / 100
		diff = diff * inertiaPower
		
		self:ScrollStop()
		self:ScrollMap(diff:x(), diff:y(), 500, "cubic out") -- interpolate based on distance
	end
end

--- Handles the mouse position during a scroll operation on the XMap control.
-- When the user is scrolling the map by dragging with the left or middle mouse button, this function is called to update the map position based on the current mouse cursor position.
-- It calculates the difference between the current mouse position and the starting position of the scroll operation, and applies that difference to the map scroll.
-- @param pt The current screen-space position of the mouse cursor.
function XMap:OnMousePos(pt)
	if self.scroll_start_pt then
		self:ScrollMap(pt:x() - self.scroll_start_pt:x(), pt:y() - self.scroll_start_pt:y(), 25)
		self.scroll_start_pt = pt
	end
end

--- Handles the mouse wheel scroll forward event on the XMap control.
-- This function is called when the user scrolls the mouse wheel forward on the XMap control.
-- It stops the current scroll operation, zooms the map in by the configured `MouseWheelStep` amount, and interpolates the zoom over 100 milliseconds. The zoom is centered on the current mouse cursor position.
-- @param pos The screen-space position of the mouse cursor when the wheel was scrolled.
-- @return "break" to indicate that the event has been handled and should not propagate further.
function XMap:OnMouseWheelForward(pos)
	self:ScrollStop()
	self:ZoomMap(self.MouseWheelStep, 100, pos)
	return "break"
end

--- Handles the mouse wheel scroll backward event on the XMap control.
-- This function is called when the user scrolls the mouse wheel backward on the XMap control.
-- It stops the current scroll operation, zooms the map out by the configured `MouseWheelStep` amount, and interpolates the zoom over 100 milliseconds. The zoom is centered on the current mouse cursor position.
-- @param pos The screen-space position of the mouse cursor when the wheel was scrolled.
-- @return "break" to indicate that the event has been handled and should not propagate further.
function XMap:OnMouseWheelBack(pos)
	self:ScrollStop()
	self:ZoomMap(-self.MouseWheelStep, 100, pos)
	return "break"
end

--- Handles the mouse left button up event on the XMap control.
-- This function is called when the user releases the left mouse button on the XMap control.
-- It stops the current scroll operation.
function XMap:OnMouseLeft()
	self:ScrollStop()
end

--- Handles the loss of capture for the XMap control.
-- This function is called when the XMap control loses capture, for example when the user releases the mouse button outside of the control.
-- It stops the current scroll operation.
function XMap:OnCaptureLost()
	self:ScrollStop()
end

--- Sets the time factor for the XMap.
-- This function updates the time factor for the XMap, which affects the speed at which time passes in the map. It also updates the map time reference and real time reference to ensure that the map time is correctly calculated.
-- @param factor The new time factor to apply to the map.
function XMap:SetTimeFactor(factor)
	local mapTime = self:GetMapTime()
	self.map_time_reference = mapTime
	self.real_time_reference = GetPreciseTicks()
	local oldFactor = factor
	self.time_factor = factor
	for _, win in ipairs(self) do
		if win.UpdateTimeFactor then
			win:UpdateTimeFactor(oldFactor, factor, mapTime)
		end
	end
end

--- Gets the current map time.
-- This function calculates the current map time by taking the difference between the current real-time and the real-time reference, scaling it by the current time factor, and adding it to the map time reference.
-- @return The current map time.
function XMap:GetMapTime()
	local timeDifference = GetPreciseTicks() - self.real_time_reference
	return self.map_time_reference + MulDivRound(timeDifference, self.time_factor, 1000)
end


----- XMapWindow

DefineClass.XMapWindow = {
	__parents = { "XWindow", "XMapRolloverable" },
	Dock = "ignore",
	UseClipBox = false,
	ScaleWithMap = true,
	
	HAlign = "center",
	VAlign = "center",
	
	-- Position in map coordinates
	PosX = 0,
	PosY = 0,
	
	map = false
}

--- Sets the width of the XMapWindow.
-- This function sets the minimum and maximum width of the XMapWindow to the provided `width` value. This ensures that the window will have a fixed width.
-- @param width The new width to set for the XMapWindow.
function XMapWindow:SetWidth(width)
	self.MinWidth = width
	self.MaxWidth = width
end

--- Sets the height of the XMapWindow.
-- This function sets the minimum and maximum height of the XMapWindow to the provided `height` value. This ensures that the window will have a fixed height.
-- @param height The new height to set for the XMapWindow.
function XMapWindow:SetHeight(height)
	self.MinHeight = height
	self.MaxHeight = height
end

--- Gets the map space box for this XMapWindow.
-- This function calculates the bounding box of the XMapWindow in map space coordinates. It takes into account the window's position, alignment, and size constraints to determine the final box.
-- @return The x, y, width, and height of the XMapWindow's bounding box in map space coordinates.
function XMapWindow:GetMapSpaceBox()
	local minX, minY = ScaleXY(self.scale, self.MinWidth, self.MinHeight)
	local maxX, maxY = ScaleXY(self.scale, self.MaxWidth, self.MaxHeight)
	
	local width = Clamp(self.measure_width, minX, maxX)
	local height = Clamp(self.measure_height, minY, maxY)
	
	local x, y = self.PosX, self.PosY
	local HAlign, VAlign = self.HAlign, self.VAlign
	if HAlign == "center" then
		x = x - width / 2
	elseif HAlign == "right" then
		x = x + width
	end
	
	if VAlign == "center" then
		y = y - height / 2
	elseif VAlign == "bottom" then
		y = y + height
	end
	
	return x, y, width, height
end

--- Sets the parent of the XMapWindow.
-- This function sets the parent of the XMapWindow to the provided parent object. It also retrieves the XMap object that is the parent of the XMapWindow.
-- @param ... The arguments passed to the parent XWindow.SetParent function.
-- @return The result of calling the parent XWindow.SetParent function.
function XMapWindow:SetParent(...)
	XWindow.SetParent(self, ...)
	self.map = GetParentOfKind(self, "XMap")
end

--- Updates the measure of the XMapWindow.
-- This function updates the measure of the XMapWindow by setting the maximum width and height to the map size, if the XMapWindow has a parent XMap. Otherwise, it calls the parent XWindow.UpdateMeasure function with the provided max_width and max_height parameters.
-- @param max_width The maximum width to set for the XMapWindow.
-- @param max_height The maximum height to set for the XMapWindow.
-- @return The result of calling the parent XWindow.UpdateMeasure function.
function XMapWindow:UpdateMeasure(max_width, max_height)
	if self.map then
		max_width, max_height = self.map.map_size:xy()
	end
	return XWindow.UpdateMeasure(self, max_width, max_height)
end

--- Checks if a given point is within the bounds of the XMapWindow.
-- @param pt The point to check, represented as a table with x and y fields.
-- @return True if the point is within the bounds of the XMapWindow, false otherwise.
function XMapWindow:PointInWindow(pt)
	local f = pt[self.Shape] or pt.InBox
	local box = self:GetInterpolatedBox(false, self.interaction_box)
	return f(pt, box)
end

local no_scale = point(1000, 1000)
--- Sets the outside scale of the XMapWindow.
-- This function sets the outside scale of the XMapWindow. If the XMapWindow is set to scale with the map, it uses a scale of `no_scale` (1000, 1000), otherwise it uses the provided `scale` parameter.
-- @param scale The scale to set for the XMapWindow.
-- @return The result of calling the parent XWindow.SetOutsideScale function.
function XMapWindow:SetOutsideScale(scale)
	-- scale is already taken into account in XMap
	return XWindow.SetOutsideScale(self, self.ScaleWithMap and no_scale or scale)
end

--- Updates the time factor for all child windows of the XMapWindow.
-- This function iterates through all child windows of the XMapWindow and calls their `UpdateTimeFactor` function, if it exists. This allows each child window to update its own time-dependent behavior based on the new time factor.
-- @param oldFactor The previous time factor.
-- @param newFactor The new time factor.
-- @param currentMapTime The current map time.
function XMapWindow:UpdateTimeFactor(oldFactor, newFactor, currentMapTime)
	for i, w in ipairs(self) do
		if w.UpdateTimeFactor then
			w:UpdateTimeFactor(oldFactor, newFactor, currentMapTime)
		end
	end
end

--- Updates the zoom level of the XMapWindow.
-- If the XMapWindow is set to scale with the map, this function removes the "reverse-zoom" modifier and returns.
-- Otherwise, it adds an interpolation modifier to the XMapWindow that scales the window from its current size to a size of (1000, 1000) over a duration of 0 seconds.
-- @param prevZoom The previous zoom level.
-- @param newZoom The new zoom level.
-- @param time The current time.
function XMapWindow:UpdateZoom(prevZoom, newZoom, time)
	if self.ScaleWithMap then
		self:RemoveModifier("reverse-zoom")
		return
	end
	
	self:AddInterpolation({
		id = "reverse-zoom",
		type = const.intRect,
		interpolate_clip = false,
		OnLayoutComplete = function(modifier, window)
			modifier.originalRect = sizebox(self.PosX, self.PosY, newZoom, newZoom)
			modifier.targetRect = sizebox(self.PosX, self.PosY, 1000, 1000)
		end,
		duration = 0
	})
end

-- Should be inherited by child windows of XMapWindows
DefineClass.XMapRolloverable = {
	__parents = { "XWindow", "XRollover" }
}

---
--- Resolves the rollover anchor for the XMapRolloverable object.
---
--- If the `RolloverAnchorId` property is set, this function calls `XRollover.ResolveRolloverAnchor` to resolve the anchor. Otherwise, it uses the interpolated box of the object.
---
--- If the object has an `XMap` parent, the anchor is mapped to the screen box using `XMap:MapToScreenBox`. Otherwise, the anchor is returned as-is.
---
--- @param context table The context for the rollover.
--- @param pos point The position of the rollover.
--- @return table The resolved rollover anchor.
function XMapRolloverable:ResolveRolloverAnchor(context, pos)
	local b = #(self.RolloverAnchorId or "") > 0 and XRollover.ResolveRolloverAnchor(self, context, pos) or self:GetInterpolatedBox()
	local map = GetParentOfKind(self, "XMap")
	return map and map:MapToScreenBox(b, "end") or b
end

---
--- Sets up the map safe area for a rollover window.
---
--- The function retrieves the parent XMap of the XMapRolloverable object, and calculates the safe area box for the rollover window. The safe area box is defined as the map box, with a padding of `map.rollover_padding` on each side.
---
--- The function also sets two functions on the rollover window:
--- - `GetSafeAreaBox()`: Returns the calculated safe area box.
--- - `GetAnchor()`: Returns the resolved rollover anchor for the XMapRolloverable object.
---
--- @param wnd table The rollover window to set up.
function XMapRolloverable:SetupMapSafeArea(wnd)
	local map = GetParentOfKind(self, "XMap")
	wnd.GetSafeAreaBox = function()
		local x, y, mx, my = map.box:xyxy()
		local rolloverPadX, rolloverPadY = ScaleXY(map.scale, map.rollover_padding, map.rollover_padding)
		return x + rolloverPadX, y + rolloverPadY, mx - rolloverPadX * 2, my - rolloverPadY * 2
	end
	wnd.GetAnchor = function(s)
		return self:ResolveRolloverAnchor(wnd.context)
	end
end

---
--- Creates a rollover window for the XMapRolloverable object.
---
--- This function creates a new rollover window using the `XTemplateSpawn` function, and sets up the map safe area for the rollover window. The safe area is defined as the map box, with a padding of `map.rollover_padding` on each side.
---
--- The function also sets two functions on the rollover window:
--- - `GetSafeAreaBox()`: Returns the calculated safe area box.
--- - `GetAnchor()`: Returns the resolved rollover anchor for the XMapRolloverable object.
---
--- @param gamepad boolean Whether the rollover is being created for a gamepad.
--- @param context table The context for the rollover.
--- @param pos point The position of the rollover.
--- @return table The created rollover window, or `false` if the window could not be created.
function XMapRolloverable:CreateRolloverWindow(gamepad, context, pos)
	context = SubContext(self:GetContext(), context)
	context.control = self
	context.anchor = self:ResolveRolloverAnchor(context, pos)
	context.gamepad = gamepad
	
	local win = XTemplateSpawn(self:GetRolloverTemplate(), nil, context)
	if not win then return false end
	self:SetupMapSafeArea(win)
	win:Open()
	local map = GetParentOfKind(self.parent, "XMap")
	if map then
		DelayedCall(0, function()
			map:InvalidateLayout()
		end)
	end
	return win
end


----- XMapObject

DefineClass.XMapObject = {
	__parents = { "XMapWindow" },
	HandleMouse = true,
	currentInterp = false,
	currentResize = false,
}

---
--- Returns the current position of the XMapObject as a point.
---
--- @return point The current position of the XMapObject.
function XMapObject:GetPos()
	return point(self.PosX, self.PosY)
end

---
--- Returns the current visual position of the XMapObject as a point.
---
--- The visual position is calculated based on the object's layout box and alignment properties. If the object is being interpolated, the interpolated position is returned.
---
--- @return point The current visual position of the XMapObject.
function XMapObject:GetVisualPos()
	local uiBox = self.layout_update and sizebox(self:GetMapSpaceBox()) or self.box
	local b = self:GetInterpolatedBox("move", uiBox)
	
	local x, y = b:minxyz()
	local width, height = uiBox:sizexyz()
	
	local HAlign, VAlign = self.HAlign, self.HAlign
	if HAlign == "center" then
		x = x + width / 2
	elseif HAlign == "right" then
		x = x - width
	end
	
	if VAlign == "center" then
		y = y + height / 2
	elseif VAlign == "bottom" then
		y = y - height
	end
	
	return point(x, y)
end

---
--- Returns the current visual size of the XMapObject as a point.
---
--- The visual size is calculated based on the object's layout box. If the object is being resized, the interpolated size is returned.
---
--- @return point The current visual size of the XMapObject.
function XMapObject:GetVisualSize()
	local uiBox = self.layout_update and sizebox(self:GetMapSpaceBox()) or self.box
	local b = self:GetInterpolatedBox("resize", uiBox)
	return b:size()
end

---
--- Updates the time factor for any ongoing interpolations on the XMapObject.
---
--- If the object has a current movement interpolation, it will update the interpolation to match the new time factor. If the object has a current resize interpolation, it will update the resize interpolation to match the new time factor.
---
--- After updating the interpolations, it will call the `XMapWindow.UpdateTimeFactor` function to allow the window to update any other time-dependent properties.
---
--- @param ... Additional arguments to pass to `XMapWindow.UpdateTimeFactor`.
function XMapObject:UpdateTimeFactor(...)
	if self.currentInterp then
		local interp = self.currentInterp
		local x, y, time = self:GetContinueInterpolationParams(interp.startX, interp.startY, interp.endX, interp.endY, interp.time, self:GetVisualPos())
		if x then self:SetPos(x, y, time) end
	end
	if self.currentResize then
		local interp = self.currentResize
		local x, y, time = self:GetContinueInterpolationParams(interp.startX, interp.startY, interp.endX, interp.endY, interp.time, self:GetVisualSize())
		if x then self:SetSize(x, y, time, interp.hOrigin, interp.vOrigin) end
	end
	
	XMapWindow.UpdateTimeFactor(self, ...)
end

---
--- Calculates the parameters needed to continue an interpolation between two points over a given time.
---
--- @param startX number The starting X coordinate of the interpolation.
--- @param startY number The starting Y coordinate of the interpolation.
--- @param endX number The ending X coordinate of the interpolation.
--- @param endY number The ending Y coordinate of the interpolation.
--- @param totalTime number The total time of the interpolation.
--- @param currentXY point The current position of the object being interpolated.
--- @return number|false endX The ending X coordinate of the interpolation, or false if the interpolation has completed.
--- @return number|false endY The ending Y coordinate of the interpolation, or false if the interpolation has completed.
--- @return number|false timeLeft The remaining time of the interpolation, or false if the interpolation has completed.
function GetContinueInterpolationParams(startX, startY, endX, endY, totalTime, currentXY)
	-- Inverse lerp to find where along the path the object is
	local start = point(startX, startY)
	local diff = point(endX, endY) - start
	local passed = currentXY - start
	local passedDDiff = Dot(passed, diff)
	local percentPassed = passedDDiff ~= 0 and MulDivRound(passedDDiff, 1000, Dot(diff, diff)) or 0

	-- Find time left (in real time)
	local timeLeft = totalTime - MulDivRound(totalTime, percentPassed, 1000)
	if timeLeft <= 0 then
		return false
	end
	
	return endX, endY, timeLeft
end

---
--- Calculates the parameters needed to continue an interpolation between two points over a given time.
---
--- @param startX number The starting X coordinate of the interpolation.
--- @param startY number The starting Y coordinate of the interpolation.
--- @param endX number The ending X coordinate of the interpolation.
--- @param endY number The ending Y coordinate of the interpolation.
--- @param totalTime number The total time of the interpolation.
--- @param currentXY point The current position of the object being interpolated.
--- @return number|false endX The ending X coordinate of the interpolation, or false if the interpolation has completed.
--- @return number|false endY The ending Y coordinate of the interpolation, or false if the interpolation has completed.
--- @return number|false timeLeft The remaining time of the interpolation, or false if the interpolation has completed.
function XMapObject:GetContinueInterpolationParams(...)
	return GetContinueInterpolationParams(...)
end

---
--- Sets the position of the XMapObject to the specified coordinates over the given time.
---
--- @param posX number The new X coordinate of the object.
--- @param posY number The new Y coordinate of the object.
--- @param time number The time in milliseconds over which to interpolate the position change.
---
--- If `time` is 0 or `nil`, the position is set immediately without any interpolation.
--- If the object is already in the process of moving, the current interpolation is canceled and the new position is set.
--- The object's layout and measure are invalidated after the position is updated.
---
function XMapObject:SetPos(posX, posY, time)
	if not time or time == 0 then
		if self:RemoveModifier("move") then
			Msg(self)
		end
		self.currentInterp = false
		if self.PosX == posX and self.PosY == posY then return end
		self.PosX = posX
		self.PosY = posY
		self:InvalidateLayout()
		return
	end

	if self:FindModifier("move") then
		-- Find where we've interpolated to and apply that as the current pos.
		local visualPos = self:GetVisualPos()
		self.PosX, self.PosY = visualPos:xy()
	end

	self.currentInterp = { startX = self.PosX, startY = self.PosY, endX = posX, endY = posY, time = time }
	local map = self.map
	if map then
		if map.time_factor == 0 then
			time = 0
		else
			time = MulDivRound(time, 1000, map.time_factor)
		end
	end

	local diffX = self.PosX - posX
	local diffY = self.PosY - posY
	self.PosX = posX
	self.PosY = posY
	self:InvalidateLayout()

	self:AddInterpolation({
		id = "move",
		type = const.intRect,
		interpolate_clip = false,
		OnLayoutComplete = XMapObjectInterpolationOnLayoutComplete,
		originalRect = sizebox(0, 0, 1000, 1000),
		targetRect = sizebox(diffX, diffY, 1000, 1000),
		duration = time,
		autoremove = time ~= 0,
		on_complete = function()
			if time == 0 then return end -- Frozen time
			self.currentInterp = false
			Msg(self)
		end,
		flags = map.UseCustomTime and bor(const.intfInverse, const.intfUILCustomTime) or const.intfInverse,
		no_invalidate_on_remove = true
	}, 1)
end

local function lGetResizeOrigins(hOrigin, vOrigin, width, height, startWidth, startHeight)
	local posX, posY = 0, 0
	if hOrigin == "right" then
		posX = startWidth - width
	end
	if vOrigin == "bottom" then
		posY = startHeight - height
	end
	return posX, posY
end

---
--- Sets the size of the XMapObject, with an optional animation.
---
--- @param width number The new width of the object.
--- @param height number The new height of the object.
--- @param time number The duration of the resize animation in milliseconds. If 0 or nil, the resize is immediate.
--- @param hOrigin string The horizontal origin point for the resize. Can be "left", "center", or "right".
--- @param vOrigin string The vertical origin point for the resize. Can be "top", "center", or "bottom".
function XMapObject:SetSize(width, height, time, hOrigin, vOrigin)
	if not time or time == 0 then
		self:RemoveModifier("resize")
		self.currentResize = false
		
		local posX, posY = lGetResizeOrigins(hOrigin, vOrigin, width, height, self.MaxWidth, self.MaxHeight)
		self.PosX = self.PosX + posX
		self.PosY = self.PosY + posY
		
		self:SetWidth(width)
		self:SetHeight(height)
		
		self:InvalidateLayout()
		self:InvalidateMeasure()
		return
	end

	if self:FindModifier("resize") then
		local visualSize = self:GetVisualSize()
		local vwidth, vheight = visualSize:xy()
	
		-- Calculate position offset
		local current = self.currentResize
		local posX, posY = lGetResizeOrigins(current.hOrigin, current.vOrigin, vwidth, vheight, current.startX, current.startY)
		self.PosX = self.PosX + posX
		self.PosY = self.PosY + posY
		self:SetWidth(vwidth)
		self:SetHeight(vheight)
		self:RemoveModifier("resize")
		self:InvalidateMeasure()
		self:InvalidateLayout()
	end

	self.currentResize = {
		startX = self.MaxWidth,
		startY = self.MaxHeight,
		endX = width,
		endY = height,
		time = time,
		hOrigin = hOrigin,
		vOrigin = vOrigin
	}
	local map = self.map
	if map then
		if map.time_factor == 0 then
			time = 0
		else
			time = MulDivRound(time, 1000, map.time_factor)
		end
	end
	
	if time == 0 then
		return
	end

--[[	if time == 0 then
		local visSize = self:GetVisualSize()
		width = visSize:x()
		height = visSize:y()
	end]]
	
	local posX, posY = lGetResizeOrigins(hOrigin, vOrigin, width, height, self.MaxWidth, self.MaxHeight)
	self:AddInterpolation{
		id = "resize",
		type = const.intRect,
		interpolate_clip = false,
		OnLayoutComplete = XMapObjectInterpolationOnLayoutComplete,
		originalRect = sizebox(0, 0, self.MaxWidth, self.MaxHeight),
		targetRect = sizebox(posX, posY, width, height),
		duration = time,
		autoremove = time ~= 0,
		on_complete = function()
			if time == 0 then return end -- Frozen time
			self.currentResize = false
			self.PosX = self.PosX + posX
			self.PosY = self.PosY + posY
			self:SetWidth(width)
			self:SetHeight(height)
			self:InvalidateMeasure()
			self:InvalidateLayout()
		end,
		flags = map.UseCustomTime and const.intfUILCustomTime,
	}

	self:InvalidateLayout()
	self:InvalidateMeasure()
end

---
--- Callback function that is called when the layout of an XMapObject is complete.
--- This function adjusts the original and target rectangles of the interpolation
--- to account for the position of the XMap window.
---
--- @param modifier table The interpolation modifier object.
--- @param window table The XMap window object.
---
function XMapObjectInterpolationOnLayoutComplete(modifier, window)
	local ogRect = modifier.unoffsetOgRect or modifier.originalRect
	local tarRect = modifier.unoffsetTarRect or modifier.targetRect

	if not modifier.unoffsetOgRect then
		modifier.unoffsetOgRect = ogRect
		modifier.unoffsetTarRect = tarRect
	end

	modifier.originalRect = Offset(ogRect, window.box:min())
	modifier.targetRect = Offset(tarRect, window.box:min())
end


----- Test

if FirstLoad then
winTest = false
end

---
--- Draws a checkerboard pattern on the XMap.
---
--- The checkerboard pattern is drawn using alternating white and black squares, each 100x100 pixels in size.
--- The pattern covers the entire area of the XMap, from (0, 0) to (map_size.x, map_size.y).
---
--- @param self table The XMap object.
---
function XMap:DrawContent()
	-- Draw debug checkerboard
	local colorOne = RGB(255, 255, 255)
	local colorTwo = RGB(0, 0, 0)

	for y = 0, self.map_size:y(), 100 do
		for x = 0, self.map_size:x(), 100 do
			local color = (x / 100 + y / 100) % 2 == 0 and colorTwo or colorOne
			UIL.DrawSolidRect(sizebox(x, y, 100, 100), color)
		end
	end
end

---
--- Spawns an XWindow with an XMap inside, and allows the user to right-click on the map to add a test object.
---
--- This function is used for testing and debugging purposes. It creates an XWindow with an XMap inside, and allows the user to right-click on the map to add a test object. The test object is a simple XMapObject with a blue background, positioned at the location of the right-click.
---
--- @function TestXMap
--- @return nil
function TestXMap()
	if winTest then
		winTest:Close()
		winTest = false
	end

	winTest = XTemplateSpawn("XWindow")
	winTest:SetMinWidth(1200)
	winTest:SetMinHeight(800)
	winTest:SetMaxWidth(1200)
	winTest:SetMaxHeight(800)
	winTest:SetHAlign("center")
	winTest:SetVAlign("center")
	winTest:SetId("idTest")

	local map = XTemplateSpawn("XMap", winTest)
	rawset(map, "test_obj", false)
	map.UseCustomTime = false

	map.OnMouseButtonUp = function(self, pt, button)
		if button == "R" then
			local map_pos = self:ScreenToMapPt(pt)
			if self.test_obj then
				self.test_obj:SetPos(map_pos:x(), map_pos:y(), 300)
			else
				self.test_obj = AddTestObjectToMap(map_pos:xy())
			end
		end
		return XMap.OnMouseButtonUp(self, pt, button)
	end

	winTest:Open()
end

---
--- Spawns a new XMapObject with a blue background and adds it to the specified map.
---
--- @param posX number The x-coordinate of the object's position.
--- @param posY number The y-coordinate of the object's position.
--- @param map XMap The map to add the object to. If not provided, the function will use the `winTest` map.
--- @return XMapObject The newly created XMapObject.
function AddTestObjectToMap(posX, posY, map)
	map = map or winTest and winTest[1]
	if not map then return end
	
	local obj = XTemplateSpawn("XMapObject", map)
	obj:SetBackground(RGB(44, 88, 151))
	obj.PosX = posX
	obj.PosY = posY
	obj:SetWidth(30)
	obj:SetHeight(60)

	obj:Open()
	return obj
end

--]]