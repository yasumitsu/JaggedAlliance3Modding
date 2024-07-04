DefineClass.XLevelHeightBrush = {
	__parents = { "XEditorBrushTool" },
	properties = {
		editor = "number", slider = true, persisted_setting = true, auto_select_all = true,
		{ id = "LevelMode", name = "Mode", editor = "dropdownlist", default = "Lower & Raise", items = {"Lower & Raise", "Raise Only", "Lower Only"} },
		{ id = "ClampToLevels", name = "Clamp to levels", editor = "bool", default = true, no_edit = not const.SlabSizeZ },
		{ id = "SquareBrush",   name = "Square brush",    editor = "bool", default = true, no_edit = not const.SlabSizeZ },
		{ id = "Height",   default = 10 * guim, scale = "m", min = guic, max = const.MaxTerrainHeight, step = guic },
		{ id = "Falloff",  default = 100, scale = "%", min = 0,  max = 250, no_edit = function(self) return self:IsCursorSquare() end },
		{ id = "Strength", default = 100, scale = "%", min = 10, max = 100 },
		{ id = "RegardWalkables", name = "Limit to walkables", editor = "bool", default = false },
	},
	
	ToolSection = "Height",
	ToolTitle = "Level height",
	Description = {
		"Levels the terrain at the height of the starting point, creating a flat area.",
		"(<style GedHighlight>hold Shift</style> to align to world directions)\n(<style GedHighlight>hold Ctrl</style> to use the value in Height)\n(<style GedHighlight>Alt-click</style> to get the height at the cursor)",
	},
	ActionSortKey = "11",
	ActionIcon = "CommonAssets/UI/Editor/Tools/Level.tga", 
	ActionShortcut = "P",
	
	mask_grid = false,
}

--- Initializes the mask grid for the XLevelHeightBrush tool.
-- The mask grid is a 2D grid that stores the height values of the terrain. It is used to
-- calculate the changes to the terrain height when the brush is applied.
-- @function XLevelHeightBrush:Init
-- @return none
function XLevelHeightBrush:Init()
	local w, h = terrain.HeightMapSize()
	self.mask_grid = NewComputeGrid(w, h, "F")
end

--- Finalizes the XLevelHeightBrush tool by clearing the original height grid and freeing the mask grid.
-- This function is called when the tool is finished being used.
function XLevelHeightBrush:Done()
	editor.ClearOriginalHeightGrid()
	self.mask_grid:free()
end

if const.SlabSizeZ then -- modify Size/Height properties depending on SquareBrush/ClampToLevels properties
	function XLevelHeightBrush:GetPropertyMetadata(prop_id)
		local sizex, sizez = const.SlabSizeX, const.SlabSizeZ
		if prop_id == "Size" and self:IsCursorSquare() then
			local help = string.format("1 tile = %sm", _InternalTranslate(FormatAsFloat(sizex, guim, 2)))
			return { id = "Size", name = "Size (tiles)", help = help, default = sizex, scale = sizex, min = sizex, max = 100 * sizex, step = sizex, editor = "number", slider = true, persisted_setting = true, auto_select_all = true, }
		end
		if prop_id == "Height" and self:GetClampToLevels() then
			local help = string.format("1 step = %sm", _InternalTranslate(FormatAsFloat(sizez, guim, 2)))
			return { id = "Height", name = "Height (steps)", help = help, default = sizez, scale = sizez, min = sizez, max = self.cursor_max_tiles * sizez, step = sizez, editor = "number", slider = true, persisted_setting = true, auto_select_all = true }
		end
		return table.find_value(self.properties, "id", prop_id)
	end

	function XLevelHeightBrush:GetProperties()
		local props = {}
		for _, prop in ipairs(self.properties) do
			props[#props + 1] = self:GetPropertyMetadata(prop.id)
		end
		return props
	end
	
	function XLevelHeightBrush:OnEditorSetProperty(prop_id, old_value, ged)
		if prop_id == "SquareBrush" or prop_id == "ClampToLevels" then
			self:SetSize(self:GetSize())
			self:SetHeight(self:GetHeight())
		end
	end
end

--- Handles the mouse button down event for the XLevelHeightBrush tool.
-- If the left mouse button is pressed while the Alt key is held down, the terrain height at the cursor position is set to the current height of the brush.
-- Otherwise, the default behavior of the XEditorBrushTool is called.
-- @param pt The position of the mouse cursor.
-- @param button The mouse button that was pressed.
-- @return "break" if the height was set, otherwise the return value of the parent class's OnMouseButtonDown method.
function XLevelHeightBrush:OnMouseButtonDown(pt, button)
	if button == "L" and terminal.IsKeyPressed(const.vkAlt) then
		self:SetHeight(GetTerrainCursor():z())
		ObjModified(self)
		return "break"
	end
	return XEditorBrushTool.OnMouseButtonDown(self, pt, button)
end

--- Starts the drawing operation for the XLevelHeightBrush tool.
-- This function is called when the user starts drawing with the brush.
-- It performs the following actions:
-- - Begins a new undo operation with the name "Changed height"
-- - Stores the original height grid, but does not use it for the terrain cursor
-- - Clears the mask grid
-- - If the Control key is not pressed, sets the height of the brush to the current terrain height at the cursor position and marks the object as modified
-- @param pt The position of the mouse cursor.
function XLevelHeightBrush:StartDraw(pt)
	XEditorUndo:BeginOp{ height = true, name = "Changed height" }
	editor.StoreOriginalHeightGrid(false) -- false = don't use for GetTerrainCursor
	self.mask_grid:clear()
	if not terminal.IsKeyPressed(const.vkControl) then
		self:SetHeight(terrain.GetHeight(pt))
		ObjModified(self)
	end
end

--- Draws the terrain height brush on the map.
-- This function is responsible for applying the height changes to the terrain based on the brush properties.
-- It performs the following actions:
-- - Calculates the inner and outer radius of the brush cursor
-- - Determines the brush operation mode (add or max) and strength based on the brush properties
-- - Draws the mask segment on the mask grid using the calculated parameters
-- - Sets the terrain height using the mask grid and the brush height
-- - If the "Clamp to Levels" property is enabled, clamps the height to the nearest terrain level
-- - If the "Regard Walkables" property is enabled, clamps the height to the walkable areas
-- - Sends a message to notify that the terrain height has changed
-- @param pt1 The starting position of the brush stroke.
-- @param pt2 The ending position of the brush stroke.
function XLevelHeightBrush:Draw(pt1, pt2)
	local inner_radius, outer_radius = self:GetCursorRadius()
	local op = self:GetStrength() ~= 100 and "add" or "max"
	local strength = self:GetStrength() ~= 100 and self:GetStrength() / 5000.0 or 1.0
	local bbox = editor.DrawMaskSegment(self.mask_grid, pt1, pt2, inner_radius, outer_radius, op, strength, strength, self:IsCursorSquare())
	editor.SetHeightWithMask(self:GetHeight() / const.TerrainHeightScale, self.mask_grid, bbox, self:GetLevelMode())
	
	if const.SlabSizeZ and self:GetClampToLevels() then
		editor.ClampHeightToLevels(config.TerrainHeightSlabOffset, const.SlabSizeZ, bbox, self.mask_grid)
	end
	if self:GetRegardWalkables() then
		editor.ClampHeightToWalkables(bbox)
	end
	Msg("EditorHeightChanged", false, bbox)
end

--- Ends the drawing operation for the XLevelHeightBrush tool.
-- This function is called when the user finishes drawing with the brush.
-- It performs the following actions:
-- - Calculates the bounding box of the brush stroke
-- - Sends a message to notify that the terrain height has changed
-- - Ends the current undo operation
-- @param pt1 The starting position of the brush stroke.
-- @param pt2 The ending position of the brush stroke.
-- @param invalid_box The bounding box of the area that needs to be redrawn.
function XLevelHeightBrush:EndDraw(pt1, pt2, invalid_box)
	local _, outer_radius = self:GetCursorRadius()
	local bbox = editor.GetSegmentBoundingBox(pt1, pt2, outer_radius, self:IsCursorSquare())
	Msg("EditorHeightChanged", true, bbox)
	XEditorUndo:EndOp(nil, invalid_box)
end

--- Gets the inner and outer radius of the brush cursor.
-- The inner radius is calculated based on the brush size and falloff, while the outer radius is simply the brush size divided by 2.
-- @return The inner radius and outer radius of the brush cursor.
function XLevelHeightBrush:GetCursorRadius()
	local inner_size = self:GetSize() * 100 / (100 + 2 * self:GetFalloff())
	return inner_size / 2, self:GetSize() / 2
end

--- Determines if the brush cursor should be displayed as a square.
-- The cursor will be displayed as a square if the `SlabSizeZ` constant is set and the `GetSquareBrush` method returns true.
-- @return `true` if the brush cursor should be displayed as a square, `false` otherwise.
function XLevelHeightBrush:IsCursorSquare()
	return const.SlabSizeZ and self:GetSquareBrush()
end

--- Gets the extra flags to use when drawing the cursor for the XLevelHeightBrush tool.
-- If the cursor should be displayed as a square, the `mfTerrainHeightFieldSnapped` flag is returned.
-- Otherwise, 0 is returned.
-- @return The extra flags to use when drawing the cursor.
function XLevelHeightBrush:GetCursorExtraFlags()
	return self:IsCursorSquare() and const.mfTerrainHeightFieldSnapped or 0
end

--- Gets the color to use when drawing the cursor for the XLevelHeightBrush tool.
-- If the cursor should be displayed as a square, the color is set to RGB(16, 255, 16). Otherwise, the color is set to RGB(255, 255, 255).
-- @return The color to use when drawing the cursor.
function XLevelHeightBrush:GetCursorColor()
	return self:IsCursorSquare() and RGB(16, 255, 16) or RGB(255, 255, 255)
end
