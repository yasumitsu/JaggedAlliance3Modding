DefineClass.XRampBrush = {
	__parents = { "XEditorBrushTool" },
	properties = {
		editor = "number", slider = true, persisted_setting = true, auto_select_all = true,
		{ id = "Falloff", default = 100, scale = "%", min = 0, max = 250 },
	},
	
	ToolSection = "Height",
	ToolTitle = "Ramp",
	Description = {
		"Creates an inclined plane between two points.",
		"(<style GedHighlight>hold Shift</style> to align to world directions)",
	},
	ActionSortKey = "14",
	ActionIcon = "CommonAssets/UI/Editor/Tools/slope.tga", 
	ActionShortcut = "/",
	
	old_bbox = false,
	ramp_grid = false,
	mask_grid = false,
}

--- Initializes the ramp grid and mask grid for the XRampBrush tool.
-- This function is called when the XRampBrush tool is initialized.
-- It creates two compute grids, one for the ramp and one for the mask, with the same size as the terrain height map.
-- The ramp grid is used to store the height values of the ramp, and the mask grid is used to store the mask for the ramp.
function XRampBrush:Init()
	local w, h = terrain.HeightMapSize()
	self.ramp_grid = NewComputeGrid(w, h, "F")
	self.mask_grid = NewComputeGrid(w, h, "F")
end


--- Cleans up the resources used by the XRampBrush tool.
-- This function is called when the XRampBrush tool is no longer needed.
-- It clears the original height grid, and frees the memory used by the ramp grid and mask grid.
function XRampBrush:Done()
	editor.ClearOriginalHeightGrid()
	self.ramp_grid:free()
	self.mask_grid:free()
end

--- Begins a new height editing operation for the XRampBrush tool.
-- This function is called when the user starts drawing with the XRampBrush tool.
-- It stores the original height grid, which will be used to restore the terrain height after the editing operation is complete.
-- The height editing operation is given the name "Changed height".
function XRampBrush:StartDraw(pt)
	XEditorUndo:BeginOp{ height = true, name = "Changed height" }
	editor.StoreOriginalHeightGrid(true) -- true = use for GetTerrainCursor
end

--- Draws a ramp between two points on the terrain using the XRampBrush tool.
--
-- This function is responsible for creating the ramp grid and mask grid, and then applying the ramp to the terrain.
-- It first gets the original height values at the two points, and then uses the GetCursorRadius function to determine the inner and outer radius of the brush.
-- The mask grid is then filled using DrawMaskSegment, and the ramp grid is filled with the height values between the two points.
-- Finally, the SetHeightWithMask function is called to apply the ramp to the terrain, and a message is sent to notify that the terrain height has changed.
--
-- @param pt1 The first point of the ramp
-- @param pt2 The second point of the ramp
function XRampBrush:Draw(pt1, pt2)
	pt1 = self.first_pos
	if pt1 == pt2 then return end
	self.mask_grid:clear()
	self.ramp_grid:clear()
	
	local h1 = editor.GetOriginalHeight(pt1) / const.TerrainHeightScale
	local h2 = editor.GetOriginalHeight(pt2) / const.TerrainHeightScale
	local inner_radius, outer_radius = self:GetCursorRadius()
	local bbox = editor.DrawMaskSegment(self.mask_grid, pt1, pt2, inner_radius, outer_radius, "max")
	editor.DrawMaskSegment(self.ramp_grid, pt1, pt2, outer_radius, outer_radius, "set", h1, h2)
	
	local extended_box = AddRects(self.old_bbox or bbox, bbox)
	editor.SetHeightWithMask(self.ramp_grid, self.mask_grid, extended_box)
	Msg("EditorHeightChanged", false, extended_box)
	self.old_bbox = bbox
end

--- Ends a height editing operation for the XRampBrush tool.
--
-- This function is called when the user finishes drawing with the XRampBrush tool.
-- It calculates the bounding box of the edited area, and sends a message to notify that the terrain height has changed.
-- The XEditorUndo:EndOp function is called to complete the height editing operation.
--
-- @param pt1 The first point of the ramp
-- @param pt2 The second point of the ramp
function XRampBrush:EndDraw(pt1, pt2)
	local _, outer_radius = self:GetCursorRadius()
	local bbox = editor.GetSegmentBoundingBox(pt1, pt2, outer_radius, self:IsCursorSquare())
	local extended_box = AddRects(self.old_bbox or bbox, bbox)
	self.old_bbox = nil
	Msg("EditorHeightChanged", true, extended_box)
	XEditorUndo:EndOp(nil, extended_box)
end

--- Returns the inner and outer radius of the cursor for the XRampBrush tool.
--
-- The inner radius is calculated as the brush size multiplied by 100 divided by the sum of 100 and twice the brush falloff.
-- The outer radius is simply the brush size divided by 2.
--
-- @return The inner radius and outer radius of the cursor.
function XRampBrush:GetCursorRadius()
	local inner_size = self:GetSize() * 100 / (100 + 2 * self:GetFalloff())
	return inner_size / 2, self:GetSize() / 2
end
