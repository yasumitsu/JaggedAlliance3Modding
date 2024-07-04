
DefineClass.XSmoothHeightBrush = {
	__parents = { "XEditorBrushTool" },
	properties = {
		editor = "number", slider = true, persisted_setting = true, auto_select_all = true,
		{ id = "Strength", default = 50,        scale = "%", min = 10,       max = 100,        step = 10 },
		{ id = "RegardWalkables", name = "Limit to walkables", editor = "bool", default = false },
	},
	
	ToolSection = "Height",
	ToolTitle = "Smooth height",
	Description = {
		"Removes jagged edges and softens terrain features."
	},
	ActionSortKey = "12",
	ActionIcon = "CommonAssets/UI/Editor/Tools/Smooth.tga", 
	ActionShortcut = "S",
	
	blurred_grid = false,
	mask_grid = false,
}

--- Initializes the XSmoothHeightBrush tool.
-- Creates the blurred grid and mask grid used by the tool, and initializes the blurred grid.
-- This function is called when the tool is first created or selected.
function XSmoothHeightBrush:Init()
	local w, h = terrain.HeightMapSize()
	self.blurred_grid = NewComputeGrid(w, h, "F")
	self.mask_grid = NewComputeGrid(w, h, "F")
	self:InitBlurredGrid()
end

--- Finalizes the XSmoothHeightBrush tool.
-- Clears the original height grid, and frees the blurred grid and mask grid used by the tool.
-- This function is called when the tool is no longer needed or is deselected.
function XSmoothHeightBrush:Done()
	editor.ClearOriginalHeightGrid()
	self.blurred_grid:free()
	self.mask_grid:free()
end

--- Initializes the blurred grid used by the XSmoothHeightBrush tool.
-- This function stores the original height grid, copies it into the blurred grid, and then asynchronously blurs the blurred grid using the current brush strength and size.
-- This function is called when the tool is first created or when the brush strength or size is changed.
function XSmoothHeightBrush:InitBlurredGrid()
	editor.StoreOriginalHeightGrid(false) -- false = don't use for GetTerrainCursor
	editor.CopyFromOriginalHeight(self.blurred_grid)

	local blur_size = MulDivRound(self:GetStrength(), self:GetSize(), guim * const.HeightTileSize * 3)
	AsyncBlurGrid(self.blurred_grid, Max(blur_size, 1))
end

-- called via Msg when height is changed via this brush, or via undo
--- Updates the blurred grid used by the XSmoothHeightBrush tool.
-- This function copies the changed area of the height grid back into the blurred grid, and then asynchronously blurs only that area to update the blurred grid.
-- @param bbox The bounding box of the changed area.
function XSmoothHeightBrush:UpdateBlurredGrid(bbox)
	bbox = terrain.ClampBox(GrowBox(bbox, 512 * guim)) -- TODO: make updating the blurred grid in the changed area only not produce sharp changes at the edges

	local grid_box = bbox / const.HeightTileSize
	
	-- copy the changed area back into blurred grid, and blur only that area to update it
	local height_part = editor.GetGrid("height", bbox)
	self.blurred_grid:copyrect(height_part, grid_box - grid_box:min(), grid_box:min())
	height_part:free()
	
	local blur_size = MulDivRound(self:GetStrength(), self:GetSize(), guim * const.HeightTileSize * 3)
	AsyncBlurGrid(self.blurred_grid, grid_box, Max(blur_size, 1)) -- update the blurred version of the terrain grid in the edited box
end

--- Handles the final height changes after the XSmoothHeightBrush tool has been used.
-- This function is called when the height changes are finalized, and it updates the blurred grid used by the XSmoothHeightBrush tool to reflect the changes.
-- @param bbox The bounding box of the changed area.
function OnMsg.EditorHeightChangedFinal(bbox)
	local brush = XEditorGetCurrentTool()
	if IsKindOf(brush, "XSmoothHeightBrush") then
		brush:UpdateBlurredGrid(bbox)
	end
end

--- Handles changes to the Strength or Size properties of the XSmoothHeightBrush tool.
-- When the Strength or Size property is changed, this function reinitializes the blurred grid used by the tool.
-- @param prop_id The ID of the property that was changed.
-- @param old_value The previous value of the property.
-- @param ged The GED object associated with the property.
function XSmoothHeightBrush:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "Strength" or prop_id == "Size" then
		self:InitBlurredGrid()
	end
end

--- Starts the drawing operation for the XSmoothHeightBrush tool.
-- This function is called when the user starts using the XSmoothHeightBrush tool to modify the terrain height.
-- It stores the original height grid, clears the mask grid, and begins a new undo operation.
-- @param pt The starting point of the brush stroke.
function XSmoothHeightBrush:StartDraw(pt)
	XEditorUndo:BeginOp{ height = true , name = "Changed height" }
	editor.StoreOriginalHeightGrid(false) -- false = don't use for GetTerrainCursor
	self.mask_grid:clear()
end
--- Draws the XSmoothHeightBrush on the terrain.
-- This function is called when the user is actively using the XSmoothHeightBrush tool to modify the terrain height.
-- It draws the brush on the terrain using the current brush settings, updates the height grid with the blurred changes, and optionally clamps the height to walkable areas.
-- @param pt1 The starting point of the brush stroke.
-- @param pt2 The ending point of the brush stroke.
function XSmoothHeightBrush:Draw(pt1, pt2)
	local _, outer_radius = self:GetCursorRadius()
	local bbox = editor.DrawMaskSegment(self.mask_grid, pt1, pt2, self:GetSize() / 4, self:GetSize(), "max", self:GetStrength() * 1.0 / 100.0)
	editor.SetHeightWithMask(self.blurred_grid, self.mask_grid, bbox)
	
	if self:GetRegardWalkables() then
		editor.ClampHeightToWalkables(bbox)
	end
	Msg("EditorHeightChanged", false, bbox)
end

function XSmoothHeightBrush:Draw(pt1, pt2)
	local _, outer_radius = self:GetCursorRadius()
	local bbox = editor.DrawMaskSegment(self.mask_grid, pt1, pt2, self:GetSize() / 4, self:GetSize(), "max", self:GetStrength() * 1.0 / 100.0)
	editor.SetHeightWithMask(self.blurred_grid, self.mask_grid, bbox)
	
	if self:GetRegardWalkables() then
		editor.ClampHeightToWalkables(bbox)
	end
	Msg("EditorHeightChanged", false, bbox)
end

--- Ends the drawing operation for the XSmoothHeightBrush tool.
-- This function is called when the user finishes using the XSmoothHeightBrush tool to modify the terrain height.
-- It calculates the bounding box of the modified area, sends a message to notify that the height has changed, and ends the current undo operation.
-- @param pt1 The starting point of the brush stroke.
-- @param pt2 The ending point of the brush stroke.
-- @param invalid_box The bounding box of the modified area.
function XSmoothHeightBrush:EndDraw(pt1, pt2, invalid_box)
	local bbox = editor.GetSegmentBoundingBox(pt1, pt2, self:GetSize(), self:IsCursorSquare())
	Msg("EditorHeightChanged", true, bbox)
	XEditorUndo:EndOp(nil, invalid_box)
end

--- Handles keyboard shortcuts for the XSmoothHeightBrush tool.
-- This function is called when the user presses a keyboard shortcut while using the XSmoothHeightBrush tool.
-- It first checks if the shortcut is handled by the base XEditorBrushTool class, and if so, returns "break" to indicate the shortcut has been handled.
-- If the shortcut is not handled by the base class, it checks if the shortcut is "+" or "-" (or their numpad equivalents) to increase or decrease the brush strength, respectively.
-- If the Shift key is pressed, the step size for adjusting the brush strength is divided by 10.
-- @param shortcut The keyboard shortcut that was pressed.
-- @param source The source of the shortcut (e.g. keyboard, mouse, etc.).
-- @param ... Additional arguments passed with the shortcut.
-- @return "break" if the shortcut was handled, nil otherwise.
function XSmoothHeightBrush:OnShortcut(shortcut, source, ...)
	if XEditorBrushTool.OnShortcut(self, shortcut, source, ...) then
		return "break"
	end
	
	local key = string.gsub(shortcut, "^Shift%-", "") -- ignore Shift, use it to decrease step size
	local divisor = terminal.IsKeyPressed(const.vkShift) and 10 or 1
	if key == "+" or key == "Numpad +" then
		self:SetStrength(self:GetStrength() + 10)
		return "break"
	elseif key == "-" or key == "Numpad -" then
		self:SetStrength(self:GetStrength() - 10)
		return "break"
	end
end

--- Returns the height of the cursor for the XSmoothHeightBrush tool.
-- The cursor height is calculated as a fraction of the brush strength, scaled by the global UI scale factor (guim).
-- @return The height of the cursor for the XSmoothHeightBrush tool.
function XSmoothHeightBrush:GetCursorHeight()
	return self:GetStrength() / 3 * guim
end

--- Returns the radius of the cursor for the XSmoothHeightBrush tool.
-- The cursor radius is calculated as half the size of the brush.
-- @return The x and y radius of the cursor for the XSmoothHeightBrush tool.
function XSmoothHeightBrush:GetCursorRadius()
	return self:GetSize() / 2, self:GetSize() / 2
end

--- Returns the affected radius of the XSmoothHeightBrush tool.
-- The affected radius is equal to the size of the brush.
-- @return The affected radius of the XSmoothHeightBrush tool.
function XSmoothHeightBrush:GetAffectedRadius()
	return self:GetSize()
end
