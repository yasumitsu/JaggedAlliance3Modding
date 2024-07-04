DefineClass.XTerrainTypeBrush = {
	__parents = { "XEditorBrushTool" },
	properties = {
		persisted_setting = true,
		{  id = "FlatOnly", name = "Draw on flat only", editor = "bool", default = false,
			persisted_setting = false, no_edit = function(self) return self.draw_on_height end, },
		{  id = "DrawOnHeight", name = "Draw on height", editor = "number", scale = "m", default = false,
			persisted_setting = false, no_edit = function(self) return not self.draw_on_height end, },
		
		{	id = "Filter", editor = "text", default = "", allowed_chars = EntityValidCharacters, translate = false, },
		{	id = "Texture", name = "Texture <style GedHighlight>(Alt-click sets vertical texture)</style>", editor = "texture_picker", default = false,
			filter_by_prop = "Filter",
			alt_prop = "VerticalTexture", base_color_map = true,
			thumb_width = 101, thumb_height = 49,
			small_font = true, multiple = true, items = GetTerrainTexturesItems,
			help = "Select multiple textures (placed according to pattern's gray levels) by holding Ctrl and/or Shift.\nSelect a vertical texture for sloped terrain by holding Alt.",
		},
		
		{	id = "VerticalTexture", name = "Vertical texture", editor = "text", default = "", no_edit = true },
		{	id = "VerticalTexturePreview", name = "Vertical texture", editor = "image", default = "", base_color_map = true,
			img_width = 101, img_height = 49,
			no_edit = function(self) return self:GetVerticalTexture() == "" end,
			persisted_setting = false,
			buttons = {{name = "Clear", func = function(self)
				self:SetProperty("VerticalTexture", "")
				self:GatherTerrainIndices()
				ObjModified(self)
			end}},
		},
		{	id = "VerticalThreshold", name = "Vertical threshold",
			editor = "number", default = 45 * 60, min = 0, max = 90 * 60, slider = true, scale = "deg",
			no_edit = function(self) return self:GetVerticalTexture() == "" end,
		},
		
		{	id = "Pattern", editor = "texture_picker", default = "CommonAssets/UI/Editor/TerrainBrushesThumbs/default.tga",
			thumb_size = 74,
			small_font = true, max_rows = 2, base_color_map = true,
			items = function()
				local files = io.listfiles("CommonAssets/UI/Editor/TerrainBrushesThumbs", "*")
				local items = {}
				local default
				for _, file in ipairs(files) do
					local name = file:match("/(%w+)[ .A-Za-z0-1]*$")
					if name then
						if name == "default" then
							default = file
						else
							items[#items + 1] = { text = name, image = file, value = file, }
						end
					end	
				end
				table.sortby_field(items, "text")
				if default then
					table.insert(items, 1, { text = "default", image = default, value = default, })
				end
				return items
			end
		},
		{	id = "PatternScale", name = "Pattern scale",
			editor = "number", default = 100, min = 10, max = 1000, step = 10, scale = 100, slider = true, exponent = 2,
			no_edit = function(self) return self:GetPattern() == self:GetDefaultPropertyValue("Pattern") end,
		},
		{	id = "PatternThreshold", name = "Pattern threshold",
			editor = "number", default = 50, min = 1, max = 99, scale = 100, slider = true,
			no_edit = function(self) return self:GetPattern() == self:GetDefaultPropertyValue("Pattern") end,
		},
	},
	
	terrain_indices = false,
	terrain_vertical_index = false,
	pattern_grid = false,
	start_pt = false,
	partial_invalidate_time = 0,
	partial_invalidate_box = false,
	
	draw_on_height = false,
	GetDrawOnHeight = function(self) return self.draw_on_height end,
	SetDrawOnHeight = function(self, v) self.draw_on_height = v self.FlatOnly = v and true end,
	
	ToolSection = "Terrain",
	ToolTitle = "Terrain texture",
	Description = {
		"(<style GedHighlight>hold Ctrl</style> to draw only over a single terrain)\n(<style GedHighlight>Alt-Click</style> to pick texture / vertical texture)"
	},
	ActionSortKey = "19",
	ActionIcon = "CommonAssets/UI/Editor/Tools/Terrain.tga", 
	ActionShortcut = "T",
}

--- Initializes the XTerrainTypeBrush instance.
-- This function is called to set up the initial state of the brush.
-- It gathers the terrain indices and the pattern for the brush, and
-- sets the initial texture if none is set.
function XTerrainTypeBrush:Init()
	self:GatherTerrainIndices()
	self:GatherPattern()
	if not self:GetTexture() then
		self:SetTexture{GetTerrainTexturesItems()[1].value}
	end
end

--- Frees the pattern grid used by the XTerrainTypeBrush instance.
-- This function is called when the brush is no longer needed, to clean up any resources it was using.
-- It ensures that the pattern grid, if it was created, is properly freed and released.
function XTerrainTypeBrush:Done()
	if self.pattern_grid then
		self.pattern_grid:free()
	end
end

--- Gets the terrain index for the given terrain texture.
-- @param texture The terrain texture to get the index for.
-- @return The index of the terrain texture, or nil if not found.
local function GetTerrainIndex(texture)
	for idx, preset in pairs(TerrainTextures) do
		if preset.id == texture then
			return idx
		end
	end
end

--- Gathers the terrain indices for the textures set in the brush.
-- This function iterates through the textures set in the brush and finds the corresponding terrain indices.
-- The terrain indices are stored in the `terrain_indices` table, and the index of the vertical texture is stored in `terrain_vertical_index`.
function XTerrainTypeBrush:GatherTerrainIndices()
	self.terrain_indices = {}
	local textures = self:GetTexture()
	for _, texture in ipairs(textures) do
		local index = GetTerrainIndex(texture)
		if index then
			table.insert(self.terrain_indices, index)
		end
	end
	self.terrain_vertical_index = GetTerrainIndex(self:GetProperty("VerticalTexture")) or -1
end

--- Gathers the pattern for the XTerrainTypeBrush instance.
-- This function is called to set up the initial state of the brush.
-- It ensures that the pattern grid, if it was created, is properly freed and released.
-- If the brush's pattern is not the default value, it creates a new pattern grid from the brush's pattern.
function XTerrainTypeBrush:GatherPattern()
	if self.pattern_grid then
		self.pattern_grid:free()
		self.pattern_grid = false
	end
	if self:GetPattern() ~= self:GetDefaultPropertyValue("Pattern") then
		self.pattern_grid = ImageToGrids(self:GetPattern(), false)
	end
end

--- Gets the terrain image for the vertical texture preview.
-- @return The terrain image for the vertical texture preview, or nil if not found.
function XTerrainTypeBrush:GetVerticalTexturePreview()
	local terrain_data = table.find_value(GetTerrainTexturesItems(), "value", self:GetVerticalTexture())
	return terrain_data and GetTerrainImage(terrain_data.image)
end

--- Checks if the terrain at the given point is vertically sloped.
-- The terrain is considered vertically sloped if the normal vector of the terrain at the given point and the surrounding points has a z-component less than or equal to the cosine of the vertical threshold angle.
-- @param pt The point to check the terrain slope at.
-- @return True if the terrain is vertically sloped, false otherwise.
function XTerrainTypeBrush:IsTerrainSlopeVertical(pt)
	local cos = cos(self:GetVerticalThreshold())
	local tile = const.TypeTileSize / 2
	return terrain.GetTerrainNormal(pt):z() <= cos and
		terrain.GetTerrainNormal(pt + point(-tile, -tile)):z() <= cos and
		terrain.GetTerrainNormal(pt + point( tile, -tile)):z() <= cos and
		terrain.GetTerrainNormal(pt + point(-tile,  tile)):z() <= cos and
		terrain.GetTerrainNormal(pt + point( tile,  tile)):z() <= cos
end

--- Handles the mouse button down event for the XTerrainTypeBrush.
-- If the left mouse button is pressed while the Alt key is held down, this function checks the terrain type under the mouse cursor. If the terrain type is valid, it sets the vertical texture or the texture of the brush based on whether the terrain is vertically sloped or not. It then gathers the terrain indices and marks the object as modified.
-- If the mouse button down event is not handled by this function, it delegates to the parent XEditorBrushTool.OnMouseButtonDown function.
-- @param pt The point where the mouse button was pressed.
-- @param button The mouse button that was pressed ("L" for left, "R" for right, "M" for middle).
-- @return "break" if the event was handled, nil otherwise.
function XTerrainTypeBrush:OnMouseButtonDown(pt, button)
	if button == "L" and terminal.IsKeyPressed(const.vkAlt) then
		local index = terrain.GetTerrainType(self:GetWorldMousePos())
		if not TerrainTextures[index] then
			return "break"
		end
		local texture = TerrainTextures[index].id
		if self:IsTerrainSlopeVertical(GetTerrainCursor()) then
			self:SetVerticalTexture(texture)
		else
			self:SetTexture({texture})
		end
		self:GatherTerrainIndices()
		ObjModified(self)
		return "break"
	end
	return XEditorBrushTool.OnMouseButtonDown(self, pt, button)
end

--- Handles changes to the editor properties for the XTerrainTypeBrush.
-- This function is called when the "Texture", "VerticalTexture", or "Pattern" properties are changed.
-- When the "Texture" or "VerticalTexture" property is changed, it calls the `GatherTerrainIndices()` function to update the terrain indices.
-- When the "Pattern" property is changed, it calls the `GatherPattern()` function to update the pattern grid.
-- @param prop_id The ID of the property that was changed.
-- @param old_value The previous value of the property.
-- @param ged The GED object associated with the property.
function XTerrainTypeBrush:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "Texture" or prop_id == "VerticalTexture" then
		self:GatherTerrainIndices()
	elseif prop_id == "Pattern" then
		self:GatherPattern()
	end
end

--- Starts the drawing operation for the XTerrainTypeBrush.
-- This function is called when the drawing operation begins. It sets up the initial state for the drawing operation, including the starting point, the starting terrain type (if the Control key is pressed), and the partial invalidation box.
-- If the `FlatOnly` flag is set, it also sets the `draw_on_height` property to the height of the terrain at the starting point, and marks the object as modified.
-- Finally, it begins a new undo operation with the name "Changed terrain type".
-- @param pt The starting point of the drawing operation.
function XTerrainTypeBrush:StartDraw(pt)
	self.start_pt = pt
	self.start_terrain = terminal.IsKeyPressed(const.vkControl) and terrain.GetTerrainType(pt)
	self.partial_invalidate_time = 0
	self.partial_invalidate_box = box()
	if self.FlatOnly then
		self.draw_on_height = self.draw_on_height or terrain.GetHeight(pt)
		ObjModified(self)
	end
	XEditorUndo:BeginOp{terrain_type = true, name = "Changed terrain type"}
end

--- Draws the terrain type brush on the terrain.
-- This function is called during the drawing operation of the XTerrainTypeBrush. It sets the terrain type in the specified segment of the terrain, and invalidates the terrain type in the partial invalidation box to ensure the changes are reflected in the editor.
-- @param pt1 The starting point of the drawing operation.
-- @param pt2 The ending point of the drawing operation.
function XTerrainTypeBrush:Draw(pt1, pt2)
	if #self.terrain_indices == 0 then return end
	
	local bbox = editor.SetTerrainTypeInSegment(
		self.start_pt, self.start_terrain or -1, pt1, pt2, self:GetSize() / 2,
		self.terrain_indices, self.terrain_vertical_index, self:GetProperty("VerticalThreshold"),
		self.pattern_grid or nil, self:GetProperty("PatternScale"), self:GetProperty("PatternThreshold"),
		self.draw_on_height or nil)
	
	-- the call above does not invalidate the terrain; take care to not invalidate it too often
	local time = GetPreciseTicks()
	self.partial_invalidate_box:InplaceExtend(bbox)
	if time - self.partial_invalidate_time > 30 then
		terrain.InvalidateType(self.partial_invalidate_box)
		self.partial_invalidate_time = time
		self.partial_invalidate_box = box()
	end
	
	hr.TemporalReset()
end

--- Ends the drawing operation for the XTerrainTypeBrush.
-- This function is called when the drawing operation ends. It invalidates the terrain type in the partial invalidation box to ensure the changes are reflected in the editor, sends a message to notify that the terrain type has changed, and ends the current undo operation.
-- @param pt1 The ending point of the drawing operation.
-- @param pt2 The ending point of the drawing operation.
-- @param invalid_box The bounding box of the area that needs to be invalidated.
function XTerrainTypeBrush:EndDraw(pt1, pt2, invalid_box)
	terrain.InvalidateType(self.partial_invalidate_box)
	Msg("EditorTerrainTypeChanged", invalid_box)
	XEditorUndo:EndOp(nil, invalid_box)
	self.start_pt = false
end

--- Handles keyboard shortcuts for the XTerrainTypeBrush.
-- This function is called when a keyboard shortcut is triggered for the XTerrainTypeBrush. It handles the "+" and "-" shortcuts to cycle through the available terrain textures.
-- @param shortcut The name of the triggered shortcut.
-- @param source The source of the shortcut (e.g. keyboard, mouse).
-- @param ... Additional arguments passed with the shortcut.
-- @return "break" if the shortcut was handled, otherwise passes the call to the parent class.
function XTerrainTypeBrush:OnShortcut(shortcut, source, ...)
	if shortcut == "+" or shortcut == "-" or shortcut == "Numpad +" or shortcut == "Numpad -" then
		local textures = self:GetTexture()
		if #textures ~= 1 then return end
		
		local terrains = GetTerrainTexturesItems()
		local index = table.find(terrains, "value", textures[1])
		if shortcut == "+" or shortcut == "Numpad +" then
			index = index + 1
			index = index > #terrains and 1 or index
		else
			index = index - 1
			index = index < 1 and #terrains or index
		end
		self:SetTexture({terrains[index].value})
		self:GatherTerrainIndices()
		
		return "break"
	else
		return XEditorBrushTool.OnShortcut(self, shortcut, source, ...)
	end
end

--- Returns the cursor radius for the XTerrainTypeBrush.
-- This function calculates the cursor radius based on the size of the brush. The radius is returned as both the x and y components.
-- @return The x and y components of the cursor radius.
function XTerrainTypeBrush:GetCursorRadius()
	local radius = self:GetSize() / 2
	return radius, radius
end
