----- XEditorBrushTool
--
-- Implements the following functionality:
--  1. Calls StartDraw, Draw, EndDraw, passing brush position in world coordinates
--  2. Supports horizontal/vertical snapping when holding Shift
--  3. Supports drawing a brush cursor

DefineClass.XEditorBrushTool = {
	__parents = { "XEditorTool" },
	properties = {
		{ id = "Size", editor = "number", default = 30 * guim, scale = "m", min = const.HeightTileSize, max = 300 * guim, step = guim / 10,
		  slider = true, persisted_setting = true, auto_select_all = true, sort_order = -1, exponent = 3, },
	},
	
	UsesCodeRenderables = true,
	
	first_pos = false,
	last_pos = false,
	snap_axis = 0,
	invalid_box = false,
	
	cursor_mesh = false,
	cursor_circles = 2,
	cursor_max_tiles = const.SlabSizeZ and (const.MaxTerrainHeight / const.SlabSizeZ) or 100,
	cursor_tile_size = const.SlabSizeX,
	cursor_verts = 100,
	cursor_default_flags = const.mfOffsetByTerrainCursor + const.mfTerrainDistorted + const.mfWorldSpace,
}

--- Initializes the brush tool by creating a cursor.
-- This function is called after the brush tool is created to set up its initial state.
function XEditorBrushTool:Init()
	DelayedCall(0, self.CreateCursor, self)
end

--- Finalizes the brush tool by destroying the cursor and handling any cleanup when the tool is done being used.
-- This function is called when the brush tool is no longer needed, such as when the user stops using the tool.
function XEditorBrushTool:Done()
	if self.last_pos then -- destroyed while drawing
		self:OnMouseButtonUp()
	end
	self:DestroyCursor()
end


----- Drawing

--- Returns the current world position of the mouse cursor, with the Z coordinate set to an invalid value.
-- This function is used to get the current position of the mouse cursor in world space, while ensuring that the Z coordinate is set to an invalid value. This is typically used when the brush tool needs to track the mouse position for drawing operations, but does not want to use the actual terrain height at the mouse position.
-- @return The current world position of the mouse cursor, with the Z coordinate set to an invalid value.
function XEditorBrushTool:GetWorldMousePos()
	return GetTerrainCursor():SetInvalidZ()
end

---
--- Handles the mouse button down event for the brush tool.
--- This function is called when the user presses the left mouse button while the brush tool is active.
---
--- It initializes the brush drawing state, including the starting position, the bounding box for the affected area,
--- and starts the drawing process. It also captures the mouse cursor and hides it to provide a custom cursor.
---
--- @param pt table The current mouse position in screen coordinates.
--- @param button string The mouse button that was pressed ("L" for left, "R" for right, etc.).
--- @return string "break" to indicate that the event has been handled and should not be propagated further.
function XEditorBrushTool:OnMouseButtonDown(pt, button)
	if button == "L" then
		self.snap_axis = 0
		self.first_pos = self:GetWorldMousePos()
		self.last_pos = self.first_pos
		self.invalid_box = editor.GetSegmentBoundingBox(self.last_pos, self.last_pos, self:GetAffectedRadius(), self:IsCursorSquare())
		self:StartDraw(self.last_pos)
		self:Draw(self.last_pos, self.last_pos)
		self.desktop:SetMouseCapture(self)
		ForceHideMouseCursor("XEditorBrushTool")
		return "break"
	end
	return XEditorTool.OnMouseButtonDown(self, pt, button)
end

--- Returns the current world position of the mouse cursor, with the Z coordinate optionally snapped to the nearest axis.
-- This function is used to get the current position of the mouse cursor in world space, while optionally snapping the position to the nearest axis if the Shift key is pressed.
-- @return The current world position of the mouse cursor, with the Z coordinate optionally snapped to the nearest axis.
function XEditorBrushTool:GetWorldPos()
	local pos = self:GetWorldMousePos()
	if terminal.IsKeyPressed(const.vkShift) then
		pos = self:SnapPosToAxis(pos)
	end
	return pos
end

---
--- Handles the mouse position event for the brush tool.
--- This function is called when the user moves the mouse while the brush tool is active.
---
--- It updates the bounding box for the affected area based on the current mouse position, and redraws the brush at the new position.
---
--- @param pt table The current mouse position in screen coordinates.
--- @param button string The mouse button that is currently pressed ("L" for left, "R" for right, etc.).
--- @return string "break" to indicate that the event has been handled and should not be propagated further.
function XEditorBrushTool:OnMousePos(pt, button)
	if self.last_pos then
		local pos = self:GetWorldPos()
		self.invalid_box:InplaceExtend(editor.GetSegmentBoundingBox(self.last_pos, pos, self:GetAffectedRadius(), self:IsCursorSquare()))
		self:Draw(self.last_pos, pos)
		self.last_pos = pos
		return "break"
	end
	return XEditorTool.OnMousePos(self, pt, button)
end

---
--- Handles the mouse button up event for the brush tool.
--- This function is called when the user releases the mouse button while the brush tool is active.
---
--- If the brush tool was actively drawing, it releases the mouse capture and calls the `OnCaptureLost` function to finalize the drawing.
---
--- If the brush tool was not actively drawing, it calls the parent `OnMouseButtonUp` function.
---
--- @param pt table The current mouse position in screen coordinates.
--- @param button string The mouse button that was released ("L" for left, "R" for right, etc.).
--- @return string "break" to indicate that the event has been handled and should not be propagated further.
function XEditorBrushTool:OnMouseButtonUp(pt, button)
	if self.last_pos then
		self.desktop:SetMouseCapture() -- calls OnCaptureLost below
		return "break"
	end
	return XEditorTool.OnMouseButtonUp(self, pt, button)
end

---
--- Handles the loss of mouse capture for the brush tool.
--- This function is called when the mouse capture is lost while the brush tool is actively drawing.
---
--- It finalizes the drawing by extending the bounding box for the affected area and calling the `EndDraw` function to complete the drawing operation.
--- It then releases the forced mouse cursor visibility.
---
--- @param self XEditorBrushTool The brush tool instance.
--- @return nil
function XEditorBrushTool:OnCaptureLost()
	local pos = self:GetWorldPos()
	self.invalid_box:InplaceExtend(editor.GetSegmentBoundingBox(self.last_pos, pos, self:GetAffectedRadius(), self:IsCursorSquare()))
	self:EndDraw(self.last_pos, pos, self.invalid_box)
	UnforceHideMouseCursor("XEditorBrushTool")
	self.last_pos = false
end

---
--- Snaps the given position to the nearest axis-aligned position based on the first position.
--- If the first position and the given position are close to an axis, the position is snapped to that axis.
--- Otherwise, the position is snapped to the axis with the larger distance.
---
--- @param pos table The position to be snapped.
--- @return table The snapped position.
function XEditorBrushTool:SnapPosToAxis(pos)
	local x0, y0 = self.first_pos:xy()
	local x1, y1 = pos:xy()
	if self.snap_axis == 0 then
		local dx, dy = abs(x1 - x0), abs(y1 - y0)
		if dx > guim and dy < guim then
			self.snap_axis = 1
		elseif dy > guim and dx < guim then
			self.snap_axis = 2
		elseif dx > guim and dy > guim then
			self.snap_axis = dx > dy and 1 or 2
		end
	end
	if self.snap_axis == 1 then
		return pos:SetY(y0)
	elseif self.snap_axis == 2 then
		return pos:SetX(x0)
	end
	return pos
end


----- Shortcuts 

---
--- Handles keyboard shortcuts for the brush tool.
---
--- This function is called when a keyboard shortcut is triggered while the brush tool is active.
--- It handles various shortcuts for adjusting the brush size, such as using the mouse wheel or square bracket keys.
--- It also ensures that certain shortcuts are ignored while the mouse is being captured for drawing.
---
--- @param self XEditorBrushTool The brush tool instance.
--- @param shortcut string The name of the triggered shortcut.
--- @param source string The source of the shortcut (e.g. "keyboard", "mouse").
--- @param ... any Additional arguments passed with the shortcut.
--- @return string|nil The result of the shortcut handling, or "break" to prevent further processing.
function XEditorBrushTool:OnShortcut(shortcut, source, ...)
	local key = string.gsub(shortcut, "^Shift%-", "") -- ignore Shift, use it to decrease step size
	local divisor = terminal.IsKeyPressed(const.vkShift) and 10 or 1
	if shortcut == "Shift-MouseWheelFwd" then
		self:SetSize(self:GetSize() + (self:IsCursorSquare() and const.SlabSizeX or guim * (self:GetSize() < 10 * guim and 1 or 5)))
		return "break"
	elseif shortcut == "Shift-MouseWheelBack" then
		self:SetSize(self:GetSize() - (self:IsCursorSquare() and const.SlabSizeX or guim * (self:GetSize() <= 10 * guim and 1 or 5)))
		return "break"
	elseif key == "]" then
		self:SetSize(self:GetSize() + (self:IsCursorSquare() and const.SlabSizeX or guim / divisor))
		return "break"
	elseif key == "[" then
		self:SetSize(self:GetSize() - (self:IsCursorSquare() and const.SlabSizeX or guim / divisor))
		return "break"
	end
	
	-- don't change tool modes, allow undo, etc. while in the process of dragging
	if terminal.desktop:GetMouseCapture() and shortcut ~= "Ctrl-F1" and shortcut ~= "Escape" then
		return "break"
	end
	
	return XEditorTool.OnShortcut(self, shortcut, source, ...)
end


----- Cursor

---
--- Creates a new cursor mesh for the brush tool.
---
--- This function is responsible for creating and updating the visual cursor for the brush tool. It sets up the cursor mesh, calls the `UpdateCursor()` function to generate the cursor geometry, and starts a thread to continuously update the cursor.
---
--- @param self XEditorBrushTool The brush tool instance.
function XEditorBrushTool:CreateCursor()
	if self.cursor_mesh then
		self:DestroyCursor()
	end

	local cursor = Mesh:new()
	cursor:SetShader(ProceduralMeshShaders.mesh_linelist)
	self.cursor_mesh = cursor
	self:UpdateCursor()
	
	self:CreateThread("UpdateCursorThread", function()
		while true do
			self:UpdateCursor()
			Sleep(100)
		end
	end)
	self:OnCursorCreate(self.cursor_mesh)
end

function XEditorBrushTool:OnCursorCreate(cursor_mesh)
end

---
--- Creates a new circle cursor mesh for the brush tool.
---
--- This function is responsible for creating the visual cursor for the brush tool when the cursor is in a circular shape. It generates the vertex data for the inner and outer circles of the cursor and returns the resulting vertex string.
---
--- @param self XEditorBrushTool The brush tool instance.
--- @return pstr The vertex data for the cursor mesh.
function XEditorBrushTool:CreateCircleCursor()
	local vpstr = pstr("")
	
	local cursor_verts = self.cursor_verts
	local inner_rad, outer_rad = self:GetCursorRadius()

	vpstr = AppendCircleVertices(nil, nil, inner_rad, self:GetCursorColor())
	vpstr = AppendCircleVertices(vpstr, nil, outer_rad, self:GetCursorColor())
	return vpstr
end

---
--- Creates a new square cursor mesh for the brush tool.
---
--- This function is responsible for generating the vertex data for a square-shaped cursor. It calculates the number of tiles required to cover the cursor's outer radius, and then appends vertices for each tile to the vertex string. The resulting vertex string is returned.
---
--- @param self XEditorBrushTool The brush tool instance.
--- @return pstr The vertex data for the cursor mesh.
function XEditorBrushTool:CreateSquareCursor()
	local vpstr = pstr("")
	
	local inner_rad, outer_rad = self:GetCursorRadius()
	local tilesize = self.cursor_tile_size
	local tiles = outer_rad * 2 / tilesize
	local offset_x, offset_y, offset_xy = point(tilesize, 0, 0), point(0, tilesize, 0), point(tilesize, tilesize, 0)
	for x = 0, tiles - 1 do
		for y = 0, tiles - 1 do
			local start_pt = point(x * tilesize - outer_rad, y * tilesize - outer_rad, 0)
			vpstr:AppendVertex(start_pt, self:GetCursorColor(), 0)
			vpstr:AppendVertex(start_pt + offset_x)
			vpstr:AppendVertex(start_pt)
			vpstr:AppendVertex(start_pt + offset_y)
			if x == tiles - 1 then
				vpstr:AppendVertex(start_pt + offset_x)
				vpstr:AppendVertex(start_pt + offset_xy)
			end
			if y == tiles - 1 then
				vpstr:AppendVertex(start_pt + offset_y)
				vpstr:AppendVertex(start_pt + offset_xy)
			end
		end
	end
	
	return vpstr
end

---
--- Updates the visual cursor for the brush tool.
---
--- This function is responsible for generating the vertex data for the brush tool's cursor and updating the cursor mesh. It checks if the cursor should be square or circular, and calls the appropriate function to generate the vertex data. If the cursor has a height, it also appends vertices for the height. Finally, it sets the mesh flags, position, and rendering flags for the cursor mesh.
---
--- @param self XEditorBrushTool The brush tool instance.
function XEditorBrushTool:UpdateCursor()
	local v_pstr 
	if self:IsCursorSquare() then
		v_pstr = self:CreateSquareCursor()
	else
		v_pstr = self:CreateCircleCursor()
	end
	
	local strength = self:GetCursorHeight()
	if strength then
		v_pstr:AppendVertex(point(0, 0, 0))
		v_pstr:AppendVertex(point(0, 0, strength))
	end
	
	self.cursor_mesh:SetMeshFlags(self.cursor_default_flags + self:GetCursorExtraFlags())
	self.cursor_mesh:SetMesh(v_pstr)
	self.cursor_mesh:SetPos(GetTerrainCursor())
	self.cursor_mesh:SetGameFlags(const.gofAlwaysRenderable)
end

---
--- Destroys the cursor mesh associated with the brush tool.
---
--- This function is responsible for cleaning up the cursor mesh when the brush tool is no longer needed. It first checks if the cursor mesh exists, and if so, it deletes the "UpdateCursorThread" thread and destroys the cursor mesh object. Finally, it sets the cursor mesh reference to `nil`.
---
--- @param self XEditorBrushTool The brush tool instance.
function XEditorBrushTool:DestroyCursor()
	if not self.cursor_mesh then return end
	self:DeleteThread("UpdateCursorThread")
	DoneObject(self.cursor_mesh)
	self.cursor_mesh = nil
end


----- Overrides

---
--- Starts the drawing process for the brush tool.
---
--- This function is called when the user starts drawing with the brush tool. It can be used to perform any necessary setup or initialization for the drawing process.
---
--- @param self XEditorBrushTool The brush tool instance.
--- @param pt point The starting point of the brush stroke.
---
function XEditorBrushTool:StartDraw(pt)
end

---
--- Draws the brush tool on the terrain.
---
--- This function is called when the user is actively drawing with the brush tool. It can be used to perform the actual drawing or painting operation on the terrain.
---
--- @param self XEditorBrushTool The brush tool instance.
--- @param pt1 point The starting point of the brush stroke.
--- @param pt2 point The ending point of the brush stroke.
---
function XEditorBrushTool:Draw(pt1, pt2)
end

---
--- Ends the drawing process for the brush tool.
---
--- This function is called when the user finishes drawing with the brush tool. It can be used to perform any necessary cleanup or finalization for the drawing process.
---
--- @param self XEditorBrushTool The brush tool instance.
--- @param pt1 point The starting point of the brush stroke.
--- @param pt2 point The ending point of the brush stroke.
---
function XEditorBrushTool:EndDraw(pt1, pt2)
end

---
--- Returns the inner and outer radius of the brush cursor.
---
--- The inner radius is the area where the brush will have full effect, and the outer radius is the area where the brush will have a fading effect.
---
--- @return number inner_radius The inner radius of the brush cursor.
--- @return number outer_radius The outer radius of the brush cursor.
function XEditorBrushTool:GetCursorRadius()
	return 5 * guim, 5 * guim
end

---
--- Returns the outer radius of the brush cursor.
---
--- The outer radius is the area where the brush will have a fading effect.
---
--- @return number outer_radius The outer radius of the brush cursor.
function XEditorBrushTool:GetAffectedRadius()
	local _, outer_radius = self:GetCursorRadius()
	return outer_radius
end

---
--- Returns the cursor color for the brush tool.
---
--- The cursor color is used to visually indicate the brush tool's position on the terrain.
---
--- @return number r The red component of the cursor color.
--- @return number g The green component of the cursor color.
--- @return number b The blue component of the cursor color.
function XEditorBrushTool:GetCursorColor()
	return RGB(255, 255, 255)
end

---
--- Returns the height of the brush cursor.
---
--- The height of the brush cursor is used to determine the vertical extent of the brush's effect on the terrain.
---
--- @return number cursor_height The height of the brush cursor.
function XEditorBrushTool:GetCursorHeight()
end

---
--- Returns whether the brush cursor should be displayed as a square.
---
--- If this function returns true, the brush cursor will be displayed as a square shape. If it returns false, the brush cursor will be displayed as a circular shape.
---
--- @return boolean is_cursor_square Whether the brush cursor should be displayed as a square.
function XEditorBrushTool:IsCursorSquare()
	return false
end

---
--- Returns any extra flags to apply to the brush cursor.
---
--- This function can be used to customize the appearance or behavior of the brush cursor.
---
--- @return number extra_flags The extra flags to apply to the brush cursor.
function XEditorBrushTool:GetCursorExtraFlags()
	return 0
end
