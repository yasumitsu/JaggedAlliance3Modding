DefineClass.XChangeHeightBrush = {
	__parents = { "XEditorBrushTool" },
	properties = {
		editor = "number", slider = true, persisted_setting = true, auto_select_all = true,
		{ id = "ClampToLevels", name = "Clamp to levels", editor = "bool", default = true, no_edit = not const.SlabSizeZ },
		{ id = "SquareBrush",   name = "Square brush",    editor = "bool", default = true, no_edit = not const.SlabSizeZ },
		{ id = "Height",     default = 10 * guim, scale = "m", min = guic, max = 100 * guim, step = guic }, -- see GetPropertyMetadata
		{ id = "Smoothness", default = 75,        scale = "%", min = 0,    max = 100, no_edit = function(self) return self:IsCursorSquare() end },
		{ id = "DepositionMode",  name = "Deposition mode",    editor = "bool", default = true },
		{ id = "Strength",   default = 50,        scale = "%", min = 10,        max = 100, no_edit = function(self) return not self:GetDepositionMode() end },
		{ id = "RegardWalkables", name = "Limit to walkables", editor = "bool", default = false },
	},
	
	ToolSection = "Height",
	Description = {
		"Use deposition mode to gradually add/remove height as you drag the mouse.",
		"(<style GedHighlight>hold Shift</style> to align to world directions)\n(<style GedHighlight>hold Ctrl</style> for inverse operation)",
	},
	
	mask_grid = false,
}

---
--- Initializes the mask grid for the XChangeHeightBrush tool.
--- The mask grid is used to store the height changes made by the brush.
--- The grid is initialized with the size of the terrain height map.
---
--- @function XChangeHeightBrush:Init
--- @return nil
function XChangeHeightBrush:Init()
	local w, h = terrain.HeightMapSize()
	self.mask_grid = NewComputeGrid(w, h, "F")
end

---
--- Cleans up the resources used by the XChangeHeightBrush tool.
--- Clears the original height grid and frees the memory used by the mask grid.
---
--- @function XChangeHeightBrush:Done
--- @return nil
function XChangeHeightBrush:Done()
	editor.ClearOriginalHeightGrid()
	self.mask_grid:free()
end

---
--- Provides metadata for the properties of the `XChangeHeightBrush` class, adjusting the `Size` and `Height` properties based on the `SquareBrush` and `ClampToLevels` properties.
---
--- @function XChangeHeightBrush:GetPropertyMetadata
--- @param prop_id string The ID of the property to get metadata for.
--- @return table The metadata for the specified property.
---
--- @function XChangeHeightBrush:GetProperties
--- @return table An array of property metadata for all properties of the `XChangeHeightBrush` class.
---
--- @function XChangeHeightBrush:OnEditorSetProperty
--- @param prop_id string The ID of the property that was set.
--- @param old_value any The previous value of the property.
--- @param ged any The GED (Graphical Editor) object associated with the property.
--- @return nil
if const.SlabSizeZ then -- modify Size/Height properties depending on SquareBrush/ClampToLevels properties
	function XChangeHeightBrush:GetPropertyMetadata(prop_id)
		local sizex, sizez = const.SlabSizeX, const.SlabSizeZ
		if prop_id == "Size" and self:IsCursorSquare() then
			local help = string.format("1 tile = %sm", _InternalTranslate(FormatAsFloat(sizex, guim, 2)))
			return { id = "Size", name = "Size (tiles)", help = help, default = sizex, scale = sizex, min = sizex, max = 100 * sizex, step = sizex, editor = "number", slider = true, persisted_setting = true, auto_select_all = true, }
		end
		if prop_id == "Height" and self:GetClampToLevels() then
			local help = string.format("1 step = %sm", _InternalTranslate(FormatAsFloat(sizez, guim, 2)))
			return { id = "Height", name = "Height (steps)", help = help, default = sizez, scale = sizez, min = sizez, max = self.cursor_max_tiles * sizez, step = sizez, editor = "number", slider = true, persisted_setting = true, auto_select_all = true, }
		end
		return table.find_value(self.properties, "id", prop_id)
	end

	function XChangeHeightBrush:GetProperties()
		local props = {}
		for _, prop in ipairs(self.properties) do
			props[#props + 1] = self:GetPropertyMetadata(prop.id)
		end
		return props
	end
	
	function XChangeHeightBrush:OnEditorSetProperty(prop_id, old_value, ged)
		if prop_id == "SquareBrush" or prop_id == "ClampToLevels" then
			self:SetSize(self:GetSize())
			self:SetHeight(self:GetHeight())
		end
	end
end

---
--- Starts the drawing operation for the XChangeHeightBrush.
--- This function is called when the brush starts drawing on the terrain.
--- It stores the original height grid and clears the mask grid.
---
--- @function XChangeHeightBrush:StartDraw
--- @param pt table The starting point of the brush stroke.
--- @return nil
---
function XChangeHeightBrush:StartDraw(pt)
	XEditorUndo:BeginOp{ height = true, name = "Changed height" }
	editor.StoreOriginalHeightGrid(true) -- true = use for GetTerrainCursor
	self.mask_grid:clear()
end

--- Draws the terrain height changes using the XChangeHeightBrush.
---
--- @param pt1 table The starting point of the brush stroke.
--- @param pt2 table The ending point of the brush stroke.
function XChangeHeightBrush:Draw(pt1, pt2)
	local inner_radius, outer_radius = self:GetCursorRadius()
	local op = self:GetDepositionMode() and "add" or "max"
	local strength = self:GetDepositionMode() and self:GetStrength() / 5000.0 or 1.0
	local bbox = editor.DrawMaskSegment(self.mask_grid, pt1, pt2, inner_radius, outer_radius, op, strength, strength, self:IsCursorSquare())
	editor.AddToHeight(self.mask_grid, self:GetCursorHeight() / const.TerrainHeightScale, bbox)
	
	if const.SlabSizeZ and self:GetClampToLevels() then
		editor.ClampHeightToLevels(config.TerrainHeightSlabOffset, const.SlabSizeZ, bbox, self.mask_grid)
	end
	if self:GetRegardWalkables() then
		editor.ClampHeightToWalkables(bbox)
	end
	Msg("EditorHeightChanged", false, bbox)
end

---
--- Ends the drawing operation for the XChangeHeightBrush.
--- This function is called when the brush finishes drawing on the terrain.
--- It calculates the bounding box of the drawn area and sends a message to notify that the terrain height has changed.
---
--- @param pt1 table The starting point of the brush stroke.
--- @param pt2 table The ending point of the brush stroke.
--- @param invalid_box table The bounding box of the invalid area.
--- @return nil
---
function XChangeHeightBrush:EndDraw(pt1, pt2, invalid_box)
	local _, outer_radius = self:GetCursorRadius()
	local bbox = editor.GetSegmentBoundingBox(pt1, pt2, outer_radius, self:IsCursorSquare())
	Msg("EditorHeightChanged", true, bbox)
	XEditorUndo:EndOp(nil, invalid_box)
end

--- Handles keyboard shortcuts for the XChangeHeightBrush.
---
--- This function is called when a keyboard shortcut is pressed while the XChangeHeightBrush is active.
--- It handles shortcuts for increasing and decreasing the brush height, as well as storing the original height grid and clearing the mask grid when the Ctrl key is pressed.
---
--- @param shortcut string The keyboard shortcut that was pressed.
--- @param source string The source of the shortcut (e.g. "keyboard", "controller").
--- @param controller_id number The ID of the controller that triggered the shortcut (if applicable).
--- @param repeated boolean Whether the shortcut was repeated (i.e. the key was held down).
--- @param ... any Additional arguments passed to the function.
--- @return string "break" if the shortcut was handled, nil otherwise.
function XChangeHeightBrush:OnShortcut(shortcut, source, controller_id, repeated, ...)
	if XEditorBrushTool.OnShortcut(self, shortcut, source, controller_id, repeated, ...) then
		return "break"
	end
	
	local key = string.gsub(shortcut, "^Shift%-", "")
	local divisor = terminal.IsKeyPressed(const.vkShift) and 10 or 1
	if key == "+" or key == "Numpad +" then
		self:SetHeight(self:GetHeight() + (self:GetClampToLevels() and const.SlabSizeZ or guim / divisor))
		return "break"
	elseif key == "-" or key == "Numpad -" then
		self:SetHeight(self:GetHeight() - (self:GetClampToLevels() and const.SlabSizeZ or guim / divisor))
		return "break"
	end
	
	if not repeated and (shortcut == "Ctrl" or shortcut == "-Ctrl") then
		editor.StoreOriginalHeightGrid(true)
		self.mask_grid:clear()
	end
end

---
--- Returns the inner and outer radius of the brush cursor.
---
--- The inner radius is calculated as the brush size multiplied by (100 - smoothness) / 100.
--- The outer radius is simply the brush size divided by 2.
---
--- @return number inner_radius The inner radius of the brush cursor.
--- @return number outer_radius The outer radius of the brush cursor.
---
function XChangeHeightBrush:GetCursorRadius()
	local inner_size = self:GetSize() * (100 - self:GetSmoothness()) / 100 
	return inner_size / 2, self:GetSize() / 2
end

--- Returns the current height of the brush cursor.
---
--- If the Ctrl key is pressed, the height is returned as a negative value, indicating that the terrain should be lowered. Otherwise, the height is returned as a positive value, indicating that the terrain should be raised.
---
--- @return number The current height of the brush cursor.
function XChangeHeightBrush:GetCursorHeight()
	local ctrlKey = terminal.IsKeyPressed(const.vkControl)
	return ctrlKey ~= self.LowerTerrain and -self:GetHeight() or self:GetHeight()
end

---
--- Checks if the brush cursor should be displayed as a square.
---
--- The cursor is displayed as a square if the `const.SlabSizeZ` constant is truthy and the brush is a square brush.
---
--- @return boolean True if the brush cursor should be displayed as a square, false otherwise.
---
function XChangeHeightBrush:IsCursorSquare()
	return const.SlabSizeZ and self:GetSquareBrush()
end

---
--- Returns the extra flags to be used when rendering the brush cursor.
---
--- If the brush cursor should be displayed as a square, the `const.mfTerrainHeightFieldSnapped` flag is returned. Otherwise, 0 is returned.
---
--- @return number The extra flags to be used when rendering the brush cursor.
---
function XChangeHeightBrush:GetCursorExtraFlags()
	return self:IsCursorSquare() and const.mfTerrainHeightFieldSnapped or 0
end

---
--- Returns the color of the brush cursor.
---
--- If the brush cursor should be displayed as a square, the color is set to RGB(16, 255, 16). Otherwise, the color is set to RGB(255, 255, 255).
---
--- @return number The color of the brush cursor.
---
function XChangeHeightBrush:GetCursorColor()
	return self:IsCursorSquare() and RGB(16, 255, 16) or RGB(255, 255, 255)
end

DefineClass.XRaiseHeightBrush = {
	__parents = { "XChangeHeightBrush" },
	LowerTerrain = false,
	ToolTitle = "Raise height",
	ActionSortKey = "09",
	ActionIcon = "CommonAssets/UI/Editor/Tools/Raise.tga", 
	ActionShortcut = "H",
}

DefineClass.XLowerHeightBrush = {
	__parents = { "XChangeHeightBrush" },
	LowerTerrain = true,
	ToolTitle = "Lower height",
	ActionSortKey = "10",
	ActionIcon = "CommonAssets/UI/Editor/Tools/Lower.tga", 
	ActionShortcut = "L",
}
