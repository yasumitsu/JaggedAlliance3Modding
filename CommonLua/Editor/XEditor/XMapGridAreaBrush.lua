-- Override this class to create editor brushes for grids defined with DefineMapGrid

DefineClass.XMapGridAreaBrush = {
	__parents = { "XEditorBrushTool" },
	properties = {
		auto_select_all = true,
		{	id = "TerrainDebugAlphaPerc", name = "Opacity", editor = "number",
			default = 50, min = 0, max = 100, slider = true,
		},
		{	id = "WriteValue", name = "Value", editor = "texture_picker", default = "Blank",
			thumb_width = 101, thumb_height = 35, small_font = true, items = function(self) return self:GetGridPaletteItems() end,
		},
		{	id = "mask_help", editor = "help", help = "<center><style GedHighlight>You can only draw outside the grey mask.</style>\n",
			no_edit = function(self) return not self.selection_available end,
		},
		{	id = "mask_buttons", editor = "buttons", default = false,
			buttons = {
				{ name = "Clear (Esc)", func = "ClearSelection" },
				{ name = "Invert (I)", func = "InvertSelection" },
				{ name = "Fill area (F)", func = "FillSelection" },
			},
			no_edit = function(self) return not self.selection_available end,
		},
	},
	
	-- settings
	GridName = false, -- grid name, as defined with DefineMapGrid
	GridTileSize = false,
	Grid = false,
	
	-- state
	saved_alpha = false,
	add_connected_area = false,
	add_every_tile = false,
	selection_grid = false,
	selection_available = false,
	
	-- overrides
	CreateBrushGrid = empty_func,
	GetGridPaletteItems = empty_func,
	GetPalette = empty_func,
}

--- Initializes the XMapGridAreaBrush instance.
-- This function is called to set up the initial state of the brush, including configuring the grid, palette, and selection grid.
-- It also saves the initial terrain debug alpha value and enables terrain debug drawing.
function XMapGridAreaBrush:Init()
	self:Initialize()
end

--- Initializes the XMapGridAreaBrush instance.
-- This function is called to set up the initial state of the brush, including configuring the grid, palette, and selection grid.
-- It also saves the initial terrain debug alpha value and enables terrain debug drawing.
function XMapGridAreaBrush:Initialize()
	if (not self.GridName or not _G[self.GridName]) and not self.Grid and not self:CreateBrushGrid() then
		assert(false, "Grid area brush has no configured grid or configured grid was not found")
		return
	end
		
	local items = self:GetGridPaletteItems()
	if not table.find(items, "value", self:GetWriteValue()) then
		self:SetWriteValue(items[1].value)
	end
	
	local grid = self.Grid or _G[self.GridName]
	local w, h = grid:size()
	self.selection_grid = NewHierarchicalGrid(w, h, 64, 1)
	self:SelectionOp("clear")
	
	self:UpdateItems()
	self.saved_alpha = hr.TerrainDebugAlphaPerc
	hr.TerrainDebugDraw = 1
	hr.TerrainDebugAlphaPerc = self:GetTerrainDebugAlphaPerc()
end

--- Finalizes the XMapGridAreaBrush instance.
-- This function is called to clean up the state of the brush, including restoring the initial terrain debug alpha value and disabling terrain debug drawing.
-- It also frees the selection grid used by the brush.
function XMapGridAreaBrush:Done()
	if (not self.GridName and not self.Grid) or not self.selection_grid then return	end
	
	hr.TerrainDebugDraw = 0
	hr.TerrainDebugAlphaPerc = self.saved_alpha
	DbgSetTerrainOverlay("") -- prevent further access to self.selection_grid (which is getting freed) from C++
	self.selection_grid:free()
end

--- Updates the items in the grid area brush.
-- This function is responsible for uploading the current palette to the debug overlay and updating the UI to reflect any changes.
-- It uses the `DbgSetTerrainOverlay` function to update the debug overlay with the current palette and the grid and selection grid associated with the brush.
-- It also calls `ObjModified(self)` to notify the UI that the brush has been modified.
function XMapGridAreaBrush:UpdateItems()
	-- Upload new palette to the debug overlay
	DbgSetTerrainOverlay("grid", self:GetPalette(), self.Grid or _G[self.GridName], self.selection_grid)
	-- Update UI
	ObjModified(self)
end

--- Hides the debug overlay associated with the XMapGridAreaBrush.
-- This function is used to clear the debug overlay that was previously set using the `DbgSetTerrainOverlay` function.
-- It is typically called when the brush is no longer needed or when the debug overlay needs to be hidden.
function XMapGridAreaBrush:HideDebugOverlay()
	DbgSetTerrainOverlay("")
end

--- Begins a new drawing operation on the map grid.
-- This function is called when the user starts a new drawing operation using the XMapGridAreaBrush. It creates a new undo operation for the current grid, with the grid name as the key and a descriptive name for the operation.
-- @param pt The starting point of the drawing operation.
function XMapGridAreaBrush:StartDraw(pt)
	XEditorUndo:BeginOp{[self.GridName] = true, name = string.format("Edited grid - %s", self.GridName)}
end
 
--- Draws a grid area on the map using the specified start and end points.
-- This function is responsible for updating the map grid with the current brush settings, such as the write value and the size of the brush.
-- It uses the `editor.SetGridSegment` function to update the grid segment between the specified start and end points, and then sends a "OnMapGridChanged" message to notify other parts of the application that the grid has been modified.
-- @param pt1 The starting point of the drawing operation.
-- @param pt2 The ending point of the drawing operation.
function XMapGridAreaBrush:Draw(pt1, pt2)
	local tile_size = MapGridTileSize(self.GridName) or self.GridTileSize
	local bbox = editor.SetGridSegment(self.Grid or _G[self.GridName], tile_size, pt1, pt2, self:GetSize() / 2, self:GetWriteValue(), self.selection_grid)
	Msg("OnMapGridChanged", self.GridName, bbox)
end

--- Ends the drawing operation on the map grid.
-- This function is called when the user completes a drawing operation using the XMapGridAreaBrush. It ends the current undo operation, clears the start point, and notifies the UI that the brush has been modified.
-- @param pt1 The starting point of the drawing operation.
-- @param pt2 The ending point of the drawing operation.
-- @param invalid_box The bounding box of the area that was modified.
function XMapGridAreaBrush:EndDraw(pt1, pt2, invalid_box)
	XEditorUndo:EndOp(nil, invalid_box)
	self.start_pt = false
	ObjModified(self) -- update palette items
end

--- Performs a selection operation on the grid associated with the XMapGridAreaBrush.
-- This function is responsible for executing various selection-related operations on the grid, such as clearing the selection, inverting the selection, or filling the selection with a specific value.
-- It uses the `editor.GridSelectionOp` function to perform the requested operation on the grid and the selection grid associated with the brush. If the operation results in a non-empty bounding box, it sends a "OnMapGridChanged" message to notify other parts of the application that the grid has been modified.
-- @param op The operation to perform on the selection, such as "clear", "invert", or "fill".
-- @param param An optional parameter for the operation, such as the value to fill the selection with.
function XMapGridAreaBrush:SelectionOp(op, param)
	local tile_size = MapGridTileSize(self.GridName) or self.GridTileSize
	local bbox = editor.GridSelectionOp(self.Grid or _G[self.GridName], self.selection_grid, tile_size, op, param)
	if bbox and not bbox:IsEmpty() then
		Msg("OnMapGridChanged", self.GridName, bbox)
	end
end

--- Clears the selection associated with the XMapGridAreaBrush.
-- This function is used to clear the current selection on the grid associated with the brush. It calls the `SelectionOp` function with the "clear" operation to remove the selection, sets the `selection_available` flag to `false`, and notifies the UI that the brush has been modified.
function XMapGridAreaBrush:ClearSelection()
	self:SelectionOp("clear")
	self.selection_available = false
	ObjModified(self)
end

--- Inverts the selection associated with the XMapGridAreaBrush.
-- This function is used to invert the current selection on the grid associated with the brush. It calls the `SelectionOp` function with the "invert" operation to toggle the selection state of each tile in the grid.
function XMapGridAreaBrush:InvertSelection()
	self:SelectionOp("invert")
end

---
--- Fills the current selection on the map grid with the write value of the brush.
--- If there is no current selection, it first selects the entire map by inverting the selection.
--- After filling the selection, it clears the selection and marks the brush as having no selection available.
---
--- @param self XMapGridAreaBrush The brush instance.
function XMapGridAreaBrush:FillSelection()
	XEditorUndo:BeginOp{[self.GridName] = true, name = string.format("Edited grid - %s", self.GridName)}
	
	if not self.selection_available then
		self:SelectionOp("invert") -- select entire map
	end
	self:SelectionOp("fill", self:GetWriteValue())
	self:SelectionOp("clear")
	self.selection_available = false
	ObjModified(self)
	
	XEditorUndo:EndOp()
end

---
--- Handles mouse button down events for the XMapGridAreaBrush.
--- This function is responsible for managing the selection behavior of the brush when the left mouse button is clicked.
--- If the `add_connected_area` or `add_every_tile` flags are set, it will perform a selection operation to add the connected area or every tile to the selection, respectively.
--- If the Alt key is pressed, it will set the write value of the brush to the value of the terrain under the cursor.
--- If the right mouse button is clicked and the selection is available, it will clear the selection.
---
--- @param self XMapGridAreaBrush The brush instance.
--- @param pt Vector2 The mouse position in screen space.
--- @param button string The mouse button that was pressed ("L" for left, "R" for right).
--- @return string The result of the operation, which may be "break" to stop further processing.
function XMapGridAreaBrush:OnMouseButtonDown(pt, button)
	if button == "L" then
		local selecting = self.add_connected_area or self.add_every_tile
		if selecting then
			local world_pt = self:GetWorldMousePos()
			if self.add_every_tile then
				self:SelectionOp("add every tile", world_pt)
			elseif self.add_connected_area then
				self:SelectionOp("add connected area", world_pt)
			end
			self.selection_available = true
			ObjModified(self)
			return "break"
		elseif terminal.IsKeyPressed(const.vkAlt) then
			local tile_size = MapGridTileSize(self.GridName)
			local value = self.Grid or _G[self.GridName]:get(GetTerrainCursor() / tile_size)
			self:SetWriteValue(value)
			ObjModified(self)
			return "break"
		end
	elseif button == "R" then
		if self.selection_available then
			self:ClearSelection()
			return "break"
		end
	end
	
	return XEditorBrushTool.OnMouseButtonDown(self, pt, button)
end

---
--- Handles keyboard key down events for the XMapGridAreaBrush.
--- This function is responsible for managing the selection behavior of the brush when the Control or Shift keys are pressed.
--- If the Control key is pressed, it sets the `add_connected_area` flag to true, which will cause the brush to select the connected area when the left mouse button is clicked.
--- If the Shift key is pressed, it sets the `add_every_tile` flag to true, which will cause the brush to select every tile when the left mouse button is clicked.
---
--- @param self XMapGridAreaBrush The brush instance.
--- @param vkey number The virtual key code of the pressed key.
--- @return string The result of the operation, which may be "break" to stop further processing.
function XMapGridAreaBrush:OnKbdKeyDown(vkey)
	local result
	if vkey == const.vkControl then
		self.add_connected_area = true
		result = "break"
	elseif vkey == const.vkShift then
		self.add_every_tile = true
		result = "break"
	end
	return result or XEditorBrushTool.OnKbdKeyDown(self, vkey)
end

---
--- Handles keyboard key up events for the XMapGridAreaBrush.
--- This function is responsible for managing the selection behavior of the brush when the Control or Shift keys are released.
--- If the Control key is released, it sets the `add_connected_area` flag to false, which will cause the brush to stop selecting the connected area when the left mouse button is clicked.
--- If the Shift key is released, it sets the `add_every_tile` flag to false, which will cause the brush to stop selecting every tile when the left mouse button is clicked.
---
--- @param self XMapGridAreaBrush The brush instance.
--- @param vkey number The virtual key code of the released key.
--- @return string The result of the operation, which may be "break" to stop further processing.
function XMapGridAreaBrush:OnKbdKeyUp(vkey)
	local result
	if vkey == const.vkControl then
		self.add_connected_area = false
		result = "break"
	elseif vkey == const.vkShift then
		self.add_every_tile = false
		result = "break"
	end
	return result or XEditorBrushTool.OnKbdKeyDown(self, vkey)
end

---
--- Handles keyboard shortcut events for the XMapGridAreaBrush.
--- This function is responsible for managing the selection behavior of the brush when certain keyboard shortcuts are used.
--- If the "Escape" shortcut is used and the selection is available, it clears the selection and returns "break" to stop further processing.
--- If the "I" shortcut is used, it inverts the current selection and returns "break" to stop further processing.
--- If the "F" shortcut is used, it fills the current selection and returns "break" to stop further processing.
--- For any other shortcut, it calls the base class's OnShortcut function.
---
--- @param self XMapGridAreaBrush The brush instance.
--- @param shortcut string The name of the shortcut.
--- @param source any The source of the shortcut.
--- @param ... any Additional arguments.
--- @return string The result of the operation, which may be "break" to stop further processing.
function XMapGridAreaBrush:OnShortcut(shortcut, source, ...)
	if shortcut == "Escape" and self.selection_available then
		self:ClearSelection()
		return "break"
	elseif shortcut == "I" then
		self:InvertSelection()
		return "break"
	elseif shortcut == "F" then
		self:FillSelection()
		return "break"
	end
	return XEditorBrushTool.OnShortcut(self, shortcut, source, ...)
end

---
--- Returns the cursor radius for the XMapGridAreaBrush.
---
--- @return number The x radius of the cursor.
--- @return number The y radius of the cursor.
function XMapGridAreaBrush:GetCursorRadius()
	local radius = self:GetSize() / 2
	return radius, radius
end

---
--- Handles setting the editor property for the XMapGridAreaBrush.
--- If the property ID is "TerrainDebugAlphaPerc", it sets the TerrainDebugAlphaPerc property to the value returned by GetTerrainDebugAlphaPerc().
---
--- @param self XMapGridAreaBrush The brush instance.
--- @param prop_id string The ID of the property to set.
function XMapGridAreaBrush:OnEditorSetProperty(prop_id)
	if prop_id == "TerrainDebugAlphaPerc" then
		hr.TerrainDebugAlphaPerc = self:GetTerrainDebugAlphaPerc()
	end
end
