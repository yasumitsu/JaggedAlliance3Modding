local work_modes = {
	{ id = 1, name = "Make passable<right>(Alt-1)" },
	{ id = 2, name = "Make impassable<right>(Alt-2)" },
	{ id = 3, name = "Clear both<right>(Alt-3)" }
}

DefineClass.XPassabilityBrush = {
	__parents = { "XEditorBrushTool" },
	properties = {
		persisted_setting = true, auto_select_all = true,
		{ id = "WorkMode", name = "Work Mode", editor = "text_picker", default = 1, max_rows = 3, items = work_modes, },
		{ id = "SquareBrush",   name = "Square brush",    editor = "bool", default = true, no_edit = not const.PassTileSize },
	},
	
	ToolSection = "Terrain",
	ToolTitle = "Forced passability",
	Description = {
		"Force sets/clears passability."
	},
	ActionSortKey = "20",
	ActionIcon = "CommonAssets/UI/Editor/Tools/Passability.tga", 
	ActionShortcut = "Alt-P",
	cursor_tile_size = const.PassTileSize
}

--- Initializes the XPassabilityBrush tool.
-- Sets the terrain debug draw mode to 1 and sets the terrain overlay to "passability".
-- This function is called when the XPassabilityBrush tool is activated.
function XPassabilityBrush:Init()
	hr.TerrainDebugDraw = 1
	DbgSetTerrainOverlay("passability")
end

--- Resets the terrain debug draw mode to 0 when the XPassabilityBrush tool is deactivated.
-- This function is called when the XPassabilityBrush tool is deactivated.
function XPassabilityBrush:Done()
	hr.TerrainDebugDraw = 0
end

-- Modify Size metadata depending on the SquareBrush property
if const.PassTileSize then
	---
 --- Returns the property metadata for the specified property ID.
 ---
 --- If the property ID is "Size" and the cursor is a square brush, the returned metadata will have a custom "Size (tiles)" property with a slider and additional formatting.
 ---
 --- @param prop_id string The ID of the property to get the metadata for.
 --- @return table The property metadata.
 ---
 function XPassabilityBrush:GetPropertyMetadata(prop_id)
		local sizex = const.PassTileSize
		if prop_id == "Size" and self:IsCursorSquare() then
			local help = string.format("1 tile = %sm", _InternalTranslate(FormatAsFloat(sizex, guim, 2)))
			return {
				id = "Size", name = "Size (tiles)", help = help, editor = "number", slider = true,
				default = sizex, scale = sizex, min = sizex, max = 100 * sizex, step = sizex,
				persisted_setting = true, auto_select_all = true,
			}
		end

		return table.find_value(self.properties, "id", prop_id)
	end

	---
 --- Returns a table of property metadata for the XPassabilityBrush tool.
 ---
 --- The property metadata includes information such as the property ID, name, help text, editor type, and other settings.
 ---
 --- @return table A table of property metadata for the XPassabilityBrush tool.
 ---
 function XPassabilityBrush:GetProperties()
		local props = {}
		for _, prop in ipairs(self.properties) do
			props[#props + 1] = self:GetPropertyMetadata(prop.id)
		end
		return props
	end
	
	---
 --- Callback function that is called when the "SquareBrush" property is set.
 --- This function updates the size of the brush to match the new square brush setting.
 ---
 --- @param prop_id string The ID of the property that was changed.
 --- @param old_value any The previous value of the property.
 --- @param ged table The GED (GUI Editor) object associated with the property.
 ---
 function XPassabilityBrush:OnEditorSetProperty(prop_id, old_value, ged)
		if prop_id == "SquareBrush" then
			self:SetSize(self:GetSize())
		end
	end
end

---
--- Begins an undo operation for changes to passability and impassability in the editor.
---
--- This function should be called at the start of a series of passability and impassability changes
--- to allow the user to undo those changes as a single operation.
---
--- @param pt point The starting point of the passability/impassability changes.
---
function XPassabilityBrush:StartDraw(pt)
	XEditorUndo:BeginOp{ passability = true, impassability = true, name = "Changed passability" }
end

---
--- Returns the bounding box for the passability brush.
---
--- The bounding box is calculated based on the current cursor position, the brush size, and whether the brush is square or circular.
---
--- @return box The bounding box for the passability brush.
---
function XPassabilityBrush:GetBrushBox()
	local radius_in_tiles = self:GetCursorRadius() / self.cursor_tile_size
	local normal_radius = (self.cursor_tile_size / 2) + self.cursor_tile_size * radius_in_tiles
	local small_radius = normal_radius - self.cursor_tile_size
	
	local cursor_pt = GetTerrainCursor()
	local center = point(
		DivRound(cursor_pt:x(), self.cursor_tile_size) * self.cursor_tile_size,
		DivRound(cursor_pt:y(), self.cursor_tile_size) * self.cursor_tile_size
	):SetTerrainZ()
	local min = center - point(normal_radius, normal_radius)
	local max = center + point(normal_radius, normal_radius)
	
	local size_in_tiles = self:GetSize() / self.cursor_tile_size
	-- For an odd-sized brush the radius is asymetrical and needs adjustment
	if size_in_tiles > 1 and size_in_tiles % 2 == 0 then
		local diff = cursor_pt - center
		if diff:x() < 0 and diff:y() < 0 then
			min = center - point(normal_radius, normal_radius)
			max = center + point(small_radius, small_radius)
		elseif diff:x() > 0 and diff:y() < 0 then
			min = center - point(small_radius, normal_radius)
			max = center + point(normal_radius, small_radius)
		elseif diff:x() < 0 and diff:y() > 0 then
			min = center - point(normal_radius, small_radius)
			max = center + point(small_radius, normal_radius)
		else
			min = center - point(small_radius, small_radius)
			max = center + point(normal_radius, normal_radius)
		end
	end
	
	return box(min, max)
end

---
--- Draws a passability brush on the terrain based on the current work mode.
---
--- If the brush is square, it sets the passability and impassability of the brush box.
--- If the brush is circular, it sets the passability and impassability of the circular area.
---
--- The work mode determines whether the brush sets the terrain as passable, impassable, or neither.
---
--- @param last_pos point The previous cursor position.
--- @param pt point The current cursor position.
---
function XPassabilityBrush:Draw(last_pos, pt)
	if self:GetSquareBrush() then
		local mode = self:GetWorkMode()
		local brush_box = self:GetBrushBox()
		
		if mode == 1 then
			editor.SetPassableBox(brush_box, true)
		elseif mode == 2 then
			editor.SetPassableBox(brush_box, false)
			editor.SetImpassableBox(brush_box, true)
		else
			editor.SetPassableBox(brush_box, false)
			editor.SetImpassableBox(brush_box, false)
		end
		return
	end
	
	local radius = self:GetSize() / 2
	local mode = self:GetWorkMode()
	if mode == 1 then
		editor.SetPassableCircle(pt, radius, true)
	elseif mode == 2 then
		editor.SetPassableCircle(pt, radius, false)
		editor.SetImpassableCircle(pt, radius, true)
	else
		editor.SetPassableCircle(pt, radius, false)
		editor.SetImpassableCircle(pt, radius, false)
	end
end

---
--- Ends the drawing operation for the passability brush, rebuilding the passability of the affected terrain area.
---
--- @param pt1 point The start position of the brush.
--- @param pt2 point The end position of the brush.
--- @param invalid_box box The bounding box of the area affected by the brush.
---
function XPassabilityBrush:EndDraw(pt1, pt2, invalid_box)
	invalid_box = GrowBox(invalid_box, const.PassTileSize * 2)
	
	XEditorUndo:EndOp(nil, invalid_box)
	terrain.RebuildPassability(invalid_box)
	Msg("EditorPassabilityChanged")
end

---
--- Determines if the cursor is currently in square brush mode.
---
--- @return boolean True if the cursor is in square brush mode, false otherwise.
---
function XPassabilityBrush:IsCursorSquare()
	return const.PassTileSize and self:GetSquareBrush()
end

---
--- Returns the extra flags to use for the cursor when the passability brush is active.
---
--- If the cursor is in square brush mode, the `const.mfPassabilityFieldSnapped` flag is returned, otherwise 0 is returned.
---
--- @return integer The extra flags to use for the cursor.
---
function XPassabilityBrush:GetCursorExtraFlags()
	return self:IsCursorSquare() and const.mfPassabilityFieldSnapped or 0
end

---
--- Handles keyboard shortcuts for the passability brush tool.
---
--- If the shortcut is "Alt-1", "Alt-2", or "Alt-3", the work mode of the brush is set to the corresponding number (1, 2, or 3) and the object is marked as modified. The function then returns "break" to indicate that the shortcut has been handled.
---
--- If the shortcut is not one of the above, the function delegates to the `XEditorBrushTool.OnShortcut` method.
---
--- @param shortcut string The keyboard shortcut that was triggered.
--- @param ... any Additional arguments passed to the shortcut handler.
--- @return string "break" if the shortcut was handled, otherwise the result of `XEditorBrushTool.OnShortcut`.
---
function XPassabilityBrush:OnShortcut(shortcut, ...)
	if shortcut == "Alt-1" or shortcut == "Alt-2" or shortcut == "Alt-3" then
		self:SetWorkMode(tonumber(shortcut:sub(-1)))
		ObjModified(self)
		return "break"
	else
		return XEditorBrushTool.OnShortcut(self, shortcut, ...)
	end
end

---
--- Returns the cursor radius for the passability brush.
---
--- The cursor radius is calculated as half the size of the brush.
---
--- @return number The x-radius of the cursor.
--- @return number The y-radius of the cursor.
---
function XPassabilityBrush:GetCursorRadius()
	local radius = self:GetSize() / 2
	return radius, radius
end
