DefineClass.TerrainColor = {
	__parents = { "Preset" },
	properties = {
		{ id = "value", editor = "number", default = 0, },
	},
	GedEditor = false,
}

---
--- Ensures that the `value` property of the `TerrainColor` class is properly initialized.
--- If the `value` property is 0, it attempts to extract the RGB color values from the `id` property
--- and sets the `value` property to the corresponding RGB color.
---
--- @param self TerrainColor
--- @return nil
function TerrainColor:PostLoad()
	if self.value == 0 then
		local r, g, b = self.id:match("^<color (%d+) (%d+) (%d+)")
		r, g, b = tonumber(r), tonumber(g), tonumber(b)
		self.value = r and g and b and RGB(r, g, b) or nil
	end
end

if const.ColorizeTileSize then -- ColorizeGrid support

local function get_colors() 
	local items = {}
	local encountered = {}
	ForEachPreset("TerrainColor", function(preset, group, ids)
		if preset.id ~= "" and not encountered[preset.id] then
			ids[#ids + 1] = preset.id
			encountered[preset.id] = true
		end
	end, items)
	table.sort(items, function(a, b) return a:strip_tags():lower() < b:strip_tags():lower() end)
	return items
end

DefineClass.XColorizeTerrainBrush = {
	__parents = { "XEditorBrushTool" },
	properties = {
		persisted_setting = true, auto_select_all = true, slider = true,
		{ id = "Blending", editor = "number", min = 1, max = 100, default = 100 },
		{ id = "Smoothness", editor = "number", min = 0, max = 100, default = 100 },
		{ id = "Roughness", editor = "number", min = -127, max = 127, default = 0, no_edit = const.ColorizeType ~= 8888 },
		{ id = "Color", editor = "color", default = RGB(200, 200, 200), alpha = false },
		{ id = "Buttons", editor = "buttons", default = false,
			buttons = {
				{ name = "Add to palette", func = "AddColorToPalette" },
				{ name = "Remove", func = "RemoveColorFromPalette" },
				{ name = "Rename", func = "RenamePaletteColor" },
			},
		},
		{ id = "ColorPalette", name = "Color Palette", editor = "text_picker", default = false, 
		  items = function (self) return get_colors end },
		{ id = "Pattern", editor = "texture_picker", default = "CommonAssets/UI/Editor/TerrainBrushesThumbs/default.tga",
		  thumb_size = 75, small_font = true, max_rows = 2, base_color_map = true,
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
	},
	
	ToolSection = "Colorization",
	ToolTitle = "Terrain colorization",
	Description = {
		"Tints the color of the terrain.",
		"(<style GedHighlight>hold Ctrl</style> to draw over select terrain)\n" ..
		"(use default color to clear colorization)\n" ..
		"(<style GedHighlight>Alt-click</style> to get the color at a point)"
	},
	ActionSortKey = "27",
	ActionIcon = "CommonAssets/UI/Editor/Tools/TerrainColorization.tga",
	ActionShortcut = "Alt-Q",
	
	mask_grid = false,
	init_grid = false,
	pattern_grid = false,
	start_pt = false,
	init_terrain_type = false,
	only_on_type = false,
}

--- Initializes the XColorizeTerrainBrush instance.
-- This function sets up the necessary grids and gathers the pattern for the terrain colorization brush.
-- @function [parent=#XColorizeTerrainBrush] Init
-- @return nil
function XColorizeTerrainBrush:Init()
	local w, h = terrain.ColorizeMapSize()
	self.mask_grid = NewComputeGrid(w, h, "F")
	self:GatherPattern()
end

--- Finalizes the XColorizeTerrainBrush instance by freeing the resources used by the brush.
-- This function frees the memory used by the mask grid and the pattern grid, if it exists.
-- @function [parent=#XColorizeTerrainBrush] Done
-- @return nil
function XColorizeTerrainBrush:Done()
	self.mask_grid:free()
	if self.pattern_grid then
		self.pattern_grid:free()
	end
end

--- Handles the mouse button down event for the XColorizeTerrainBrush.
-- If the left mouse button is pressed while the Alt key is held down, the function retrieves the color value at the current terrain cursor position and sets the brush color to that value. It then marks the object as modified.
-- If the left mouse button is pressed without the Alt key, the function calls the OnMouseButtonDown method of the parent XEditorBrushTool class.
-- @param pt The position of the mouse cursor.
-- @param button The mouse button that was pressed ("L" for left, "R" for right).
-- @return "break" if the Alt+left mouse button combination was handled, otherwise the return value of the parent class's OnMouseButtonDown method.
function XColorizeTerrainBrush:OnMouseButtonDown(pt, button)
	if button == "L" and terminal.IsKeyPressed(const.vkAlt) then
		local grid = editor.GetGridRef("colorize")
		local value = grid:get(GetTerrainCursor() / const.ColorizeTileSize)
		local r, g, b, a = GetRGBA(value)
		self:SetColor(RGB(r, g, b))
		ObjModified(self)
		return "break"
	end
	return XEditorBrushTool.OnMouseButtonDown(self, pt, button)
end

--- Starts the drawing process for the XColorizeTerrainBrush.
-- This function initializes the necessary grids and state for the terrain colorization brush.
-- If the Control key is pressed, the brush will only apply colorization to the initial terrain type.
-- @param pt The starting point of the brush stroke.
-- @return nil
function XColorizeTerrainBrush:StartDraw(pt)
	XEditorUndo:BeginOp{colorize = true, name = "Changed terrain colorization"}
	self.mask_grid:clear()
	self.init_grid = terrain.GetColorizeGrid()
	self.start_pt = pt
	self.init_terrain_type = terrain.GetTerrainType(pt)
	if terminal.IsKeyPressed(const.vkControl) then self.only_on_type = true end
end

--- Draws the terrain colorization brush on the terrain.
-- This function sets the colorization of the terrain within the specified segment, using the brush's current settings.
-- @param pt1 The starting point of the brush stroke.
-- @param pt2 The ending point of the brush stroke.
-- @return nil
function XColorizeTerrainBrush:Draw(pt1, pt2)
	local inner_radius, outer_radius = self:GetCursorRadius()
	editor.SetColorizationInSegment(self.mask_grid, self.init_grid, self.start_pt, pt1, pt2, self:GetBlending(), inner_radius, outer_radius,
		self:GetColor(), self:GetRoughness(), self.init_terrain_type, self.only_on_type,
		self.pattern_grid or nil, self:GetPatternScale())
end

--- Ends the drawing process for the XColorizeTerrainBrush.
-- This function cleans up the state of the brush after a drawing operation is completed.
-- It frees the initial colorization grid, resets the starting point and initial terrain type, and clears the "only on type" flag.
-- The function also ends the undo operation and grows the invalid box to include the full extent of the brush stroke.
-- @param pt1 The ending point of the brush stroke.
-- @param pt2 The ending point of the brush stroke.
-- @param invalid_box The bounding box of the area that was modified by the brush stroke.
-- @return nil
function XColorizeTerrainBrush:EndDraw(pt1, pt2, invalid_box)
	self.init_grid:free()
	self.start_pt = false
	self.init_terrain_type = false
	self.only_on_type = false
	XEditorUndo:EndOp(nil, GrowBox(invalid_box, const.ColorizeTileSize / 2)) -- the box is extended internally in editor.SetColorizationInSegment
end

--- Gathers the pattern for the XColorizeTerrainBrush.
-- This function initializes the pattern grid used by the terrain colorization brush. If a pattern has been set, it is loaded into the pattern grid. If no pattern is set, the default pattern is loaded instead.
-- @return nil
function XColorizeTerrainBrush:GatherPattern()
	if self.pattern_grid then
		self.pattern_grid:free()
		self.pattern_grid = false
	end
	self.pattern_grid = ImageToGrids(self:GetPattern(), false)
	if not self.pattern_grid then
		self:SetPattern(self:GetDefaultPropertyValue("Pattern"))
		self.pattern_grid = ImageToGrids(self:GetPattern(), false)
	end
end

--- Gets the inner and outer radius of the colorization brush cursor.
-- The inner radius is calculated as the brush size multiplied by (100 - smoothness) / 100. The outer radius is simply the brush size divided by 2.
-- @return number inner_radius The inner radius of the brush cursor.
-- @return number outer_radius The outer radius of the brush cursor.
function XColorizeTerrainBrush:GetCursorRadius()
	local inner_size = self:GetSize() * (100 - self:GetSmoothness()) / 100 
	return inner_size / 2, self:GetSize() / 2
end

--- Handles changes to the editor properties of the XColorizeTerrainBrush.
-- This function is called when certain properties of the XColorizeTerrainBrush are changed, such as the color palette, pattern, or color.
-- When the color palette is changed, the function sets the brush color to the selected color from the palette.
-- When the pattern is changed, the function gathers the new pattern for the brush.
-- When the color is changed, the function clears the selected color palette.
-- @param prop_id The ID of the property that was changed.
-- @return nil
function XColorizeTerrainBrush:OnEditorSetProperty(prop_id)
	if prop_id == "ColorPalette" then
		local preset = Presets.TerrainColor.Default[self:GetColorPalette()]
		local color = preset and preset.value
		if color then
			self:SetColor(color)
		end
	elseif prop_id == "Pattern" then
		self:GatherPattern()
	elseif prop_id == "Color" then
		self:SetColorPalette(false) -- clear the selected color
	end
end

--- Adds a new color to the terrain color palette.
-- This function prompts the user to enter a name for the new color, and then adds the color to the terrain color palette. The color is represented as an RGB value and the name is formatted as an XML color tag.
-- If a color with the same name already exists in the palette, the function will not add the new color.
-- @param self The XColorizeTerrainBrush instance.
-- @return nil
function XColorizeTerrainBrush:AddColorToPalette()
	local name = WaitInputText(nil, "Name Your Color:")
	local r, g, b = GetRGB(self:GetColor())
	name = name and string.format("<color %s %s %s>%s</color>", r, g, b, name)
	if self:GetColor() and name and not table.find(Presets.TerrainColor.Default, "id", name) then
		local color = TerrainColor:new()
		color:SetGroup("Default")
		color:SetId(name)
		color.value = self:GetColor()
		TerrainColor:SaveAll("force")
		ObjModified(self)
	end
end

--- Removes a color from the terrain color palette.
-- This function finds the index of the color with the given name in the `Presets.TerrainColor.Default` table, and then deletes that color from the table.
-- After removing the color, the function saves the updated terrain color palette and marks the `XColorizeTerrainBrush` object as modified.
-- @param self The `XColorizeTerrainBrush` instance.
-- @return nil
function XColorizeTerrainBrush:RemoveColorFromPalette()
	local name = self:GetColorPalette()
	local index = table.find(Presets.TerrainColor.Default, "id", name)
	if index then
		Presets.TerrainColor.Default[index]:delete()
	end
	TerrainColor:SaveAll("force")
	ObjModified(self)
end

--- Renames the currently selected color in the terrain color palette.
-- This function first sets the color of the XColorizeTerrainBrush to the value of the currently selected color in the palette. It then removes the currently selected color from the palette and adds a new color with a new name entered by the user.
-- @param self The XColorizeTerrainBrush instance.
-- @return nil
function XColorizeTerrainBrush:RenamePaletteColor()
	local name = self:GetColorPalette()
	self:SetColor(Presets.TerrainColor.Default[name].value)
	self:RemoveColorFromPalette()
	self:AddColorToPalette()
end

DefineClass.XColorizeObjectsTool = {
	__parents = { "XEditorBrushTool" },
	properties = {
		persisted_setting = true, slider = true,
		{ id = "ColorizationMode", name = "Colorization Mode", editor = "text_picker", items = function() return { "Colorize", "Clear" } end, default = "Colorize", horizontal = true, },
		{ id = "Affect", editor = "set", default = {}, items = function() return table.subtraction(ArtSpecConfig.Categories, {"Markers"}) end, horizontal = true, },
		{ id = "HeightTreshold", name = "Height Treshold", editor = "number", min = 0 * guim, max = 100 * guim, default = 5 * guim, step = guim, scale = "m", },
	},
	
	ActionSortKey = "28",
	ActionIcon = "CommonAssets/UI/Editor/Tools/TerrainObjectsColorization.tga", 
	ActionShortcut = "Alt-W",

	ToolSection = "Colorization",
	ToolTitle = "Terrain objects colorization",
	Description = {
		"Changes the tint of objects close to the terrain surface."
	},
}

--- Draws a colorization effect on terrain objects within the specified area.
-- This function iterates over all objects within the specified area (defined by the `pt1` and `pt2` points) and the cursor radius. For each object, it checks if the object's category is in the `Affect` set and if the object is close enough to the terrain (based on the `HeightTreshold` property). If the `ColorizationMode` is set to "Colorize", the function sets the `const.gofTerrainColorization` game flag on the object, otherwise it clears that flag.
-- @param self The `XColorizeObjectsTool` instance.
-- @param pt1 The first point defining the area to colorize.
-- @param pt2 The second point defining the area to colorize.
function XColorizeObjectsTool:Draw(pt1, pt2)
	MapForEach(pt1, pt2, self:GetCursorRadius(), function (o)
			local entityData = EntityData[o:GetEntity()]
			local ZOverTerrain = o:GetVisualPos():z() - terrain.GetHeight(o:GetPos())
			if type(entityData) == "table" and entityData.editor_category and self:GetAffect()[entityData.editor_category] and ZOverTerrain <= self:GetHeightTreshold() then
				if self:GetColorizationMode() == "Colorize" then o:SetHierarchyGameFlags(const.gofTerrainColorization)
				else o:ClearHierarchyGameFlags(const.gofTerrainColorization) end
			end
		end)
end

--- Returns the cursor radius for the XColorizeObjectsTool.
-- This function calculates the cursor radius based on the size of the tool. The radius is half the size of the tool.
-- @param self The XColorizeObjectsTool instance.
-- @return The x and y radius of the cursor.
function XColorizeObjectsTool:GetCursorRadius()
	local radius = self:GetSize() / 2
	return radius, radius
end

end -- ColorizeGrid support
