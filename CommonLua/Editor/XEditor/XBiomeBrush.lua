if not config.EditableBiomeGrid then return end

function OnMsg.PresetSave(class)
	local brush = XEditorGetCurrentTool()
	local classdef = g_Classes[class]
	if IsKindOf(classdef, "Biome") and IsKindOf(brush, "XBiomeBrush") then
		brush:UpdateItems()
	end
end

DefineClass.XBiomeBrush = {
	__parents = { "XMapGridAreaBrush" },
	properties = {
		{	id = "edit_button", editor = "buttons", default = false,
			buttons = { { name = "Edit biome presets", func = function() OpenPresetEditor("Biome") end } },
			no_edit = function(self) return self.selection_available end,
		},
	},
	
	GridName = "BiomeGrid",
	
	ToolSection = "Terrain",
	ToolTitle = "Biome",
	Description = {
		"Defines the biome areas on the map.",
		"(<style GedHighlight>Ctrl-click</style> to select & lock areas)\n" ..
		"(<style GedHighlight>Shift-click</style> to select entire biomes)\n" ..
		"(<style GedHighlight>Alt-click</style> to get the biome at the cursor)"
	},
	ActionSortKey = "22",
	ActionIcon = "CommonAssets/UI/Editor/Tools/TerrainBiome.tga", 
	ActionShortcut = "B",
}

--- Returns a list of palette items for the biome grid.
---
--- The palette items include a blank item, followed by all the biome presets.
--- Each palette item has the following properties:
--- - `text`: The display name of the palette item, which includes the biome ID and group if available.
--- - `value`: The grid value associated with the biome preset.
--- - `image`: The image to display for the palette item (always the "white.dds" image).
--- - `color`: The palette color associated with the biome preset.
---
--- @return table The list of palette items for the biome grid.
function XBiomeBrush:GetGridPaletteItems()
	local white = "CommonAssets/System/white.dds"
	local items = {{text = "Blank", value = 0, image = white, color = RGB(0, 0, 0)}}
	local only_id = #(Presets.Biome or "") < 2
	ForEachPreset("Biome", function(preset)
		table.insert(items, {
			text = only_id and preset.id or (preset.id .. "\n" .. preset.group),
			value = preset.grid_value,
			image = white,
			color = preset.palette_color})
	end)
	return items
end

--- Returns the biome palette used by the XBiomeBrush.
---
--- @return table The biome palette.
function XBiomeBrush:GetPalette()
	return DbgGetBiomePalette()
end
