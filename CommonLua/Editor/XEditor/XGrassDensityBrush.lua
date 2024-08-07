DefineClass.XGrassDensityBrush =
{
	__parents = { "XEditorBrushTool" },
	properties =
	{
		persisted_setting = true, auto_select_all = true, slider = true,
		{ id = "LevelMode", name = "Mode", editor = "dropdownlist", default = "Lower & Raise", items = { "Lower & Raise", "Raise Only", "Lower Only", "Draw on Empty" } },
		{ id = "MinDensity", name = "Min grass density", editor = "number", min = 0, max = 100, default = 0},
		{ id = "MaxDensity", name = "Max grass density", editor = "number", min = 0, max = 100, default = 100},
		{ id = "GridVisible", name = "Toggle grid visibilty", editor = "bool", default = true},
		{ id = "TerrainDebugAlphaPerc", name = "Grid opacity", editor = "number",
		  default = 80, min = 0, max = 100, slider = true, no_edit = function(self) return not self:GetGridVisible() end },
	},
	
	ToolSection = "Terrain",
	ToolTitle = "Terrain grass density",
	Description = {
		"Defines the grass density of the terrain.",
		"(<style GedHighlight>hold Ctrl</style> to draw on a select terrain)\n(<style GedHighlight>Alt-click</style> to see grass density at the cursor)"
	},
	ActionSortKey = "21",
	ActionIcon = "CommonAssets/UI/Editor/Tools/GrassDensity.tga", 
	ActionShortcut = "Alt-N",
	
	prev_alpha = false,
	start_terrain = false,
}

---
--- Initializes the XGrassDensityBrush tool.
--- If the "GridVisible" property is set to true, this function will show the grid.
---
function XGrassDensityBrush:Init()
	if self:GetProperty("GridVisible") then
		self:ShowGrid()
	end
end

---
--- Hides the grid when the XGrassDensityBrush tool is done being used.
---
function XGrassDensityBrush:Done()
	self:HideGrid()
end

---
--- Shows the terrain grid for the XGrassDensityBrush tool.
--- This function sets the TerrainDebugDraw flag to 1 to enable the grid display,
--- and stores the previous TerrainDebugAlphaPerc value to restore it later.
--- It then sets the TerrainDebugAlphaPerc to the value returned by GetTerrainDebugAlphaPerc(),
--- and sets the terrain overlay to "grass".
---
--- @function XGrassDensityBrush:ShowGrid
--- @return nil
function XGrassDensityBrush:ShowGrid()
	hr.TerrainDebugDraw = 1
	self.prev_alpha = hr.TerrainDebugAlphaPerc
	hr.TerrainDebugAlphaPerc = self:GetTerrainDebugAlphaPerc()
	DbgSetTerrainOverlay("grass")
end

---
--- Hides the terrain grid for the XGrassDensityBrush tool.
--- This function sets the TerrainDebugDraw flag to 0 to disable the grid display,
--- and restores the previous TerrainDebugAlphaPerc value.
---
--- @function XGrassDensityBrush:HideGrid
--- @return nil
function XGrassDensityBrush:HideGrid()
	hr.TerrainDebugDraw = 0
	hr.TerrainDebugAlphaPerc = self.prev_alpha
end

---
--- Handles the mouse button down event for the XGrassDensityBrush tool.
--- If the left mouse button is pressed while the Alt key is held down, this function
--- will print the grass density value at the current terrain cursor position.
--- Otherwise, it will call the parent class's OnMouseButtonDown function.
---
--- @param pt table The position of the mouse cursor.
--- @param button string The mouse button that was pressed ("L" for left, "R" for right).
--- @return string "break" if the left mouse button was pressed with Alt, otherwise nil.
---
function XGrassDensityBrush:OnMouseButtonDown(pt, button)
	if button == "L" and terminal.IsKeyPressed(const.vkAlt) then
		local grid = editor.GetGridRef("grass_density")
		local value = grid:get(GetTerrainCursor() / const.GrassTileSize)
		print("Grass density at cursor:", value)
		return "break"
	end
	return XEditorBrushTool.OnMouseButtonDown(self, pt, button)
end

---
--- Starts the drawing operation for the XGrassDensityBrush tool.
--- This function begins a new undo operation for the grass density changes,
--- and stores the current terrain type at the starting point if the Control key is pressed.
---
--- @param pt table The starting position of the brush.
--- @return nil
function XGrassDensityBrush:StartDraw(pt)
	XEditorUndo:BeginOp{grass_density = true, name = "Changed grass density"}
	self.start_terrain = terminal.IsKeyPressed(const.vkControl) and terrain.GetTerrainType(pt)
end

---
--- Draws the grass density brush on the terrain.
---
--- @param pt1 table The starting position of the brush.
--- @param pt2 table The ending position of the brush.
---
function XGrassDensityBrush:Draw(pt1, pt2)
	editor.SetGrassDensityInSegment(pt1, pt2, self:GetSize() / 2, self:GetMinDensity(), self:GetMaxDensity(), self:GetLevelMode(), self.start_terrain or -1)
end

---
--- Ends the drawing operation for the XGrassDensityBrush tool.
--- This function ends the current undo operation for the grass density changes.
---
--- @param pt1 table The starting position of the brush.
--- @param pt2 table The ending position of the brush.
--- @param invalid_box table The bounding box of the area that needs to be redrawn.
--- @return nil
function XGrassDensityBrush:EndDraw(pt1, pt2, invalid_box)
	XEditorUndo:EndOp(nil, invalid_box)
end

---
--- Returns the radius of the cursor for the XGrassDensityBrush tool.
---
--- @return number The x-radius of the cursor.
--- @return number The y-radius of the cursor.
function XGrassDensityBrush:GetCursorRadius()
	local radius = self:GetSize() / 2
	return radius, radius
end

---
--- Handles changes to the editor properties for the XGrassDensityBrush tool.
---
--- This function is called when the editor properties for the XGrassDensityBrush tool are changed. It updates the tool's behavior based on the changes to the properties.
---
--- @param prop_id string The ID of the property that was changed.
--- @param old_value any The previous value of the property.
--- @param ged table The editor GUI object that triggered the property change.
---
function XGrassDensityBrush:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "GridVisible" then
		if self:GetProperty("GridVisible") then
			self:ShowGrid()
		else
			self:HideGrid()
		end
	elseif prop_id == "MinDensity" or prop_id == "MaxDensity" then
		local min = self:GetProperty("MinDensity")
		local max = self:GetProperty("MaxDensity")
		if prop_id == "MinDensity" then
			if min > max then
				self:SetProperty("MaxDensity", min)
			end
		else
			if max < min then
				self:SetProperty("MinDensity", max)
			end
		end
	elseif prop_id == "TerrainDebugAlphaPerc" then
		hr.TerrainDebugAlphaPerc = self:GetTerrainDebugAlphaPerc()
	end
end
