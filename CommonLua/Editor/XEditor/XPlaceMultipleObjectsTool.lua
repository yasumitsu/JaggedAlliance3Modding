DefineClass.XPlaceMultipleObjectsTool = {
	__parents = { "XEditorBrushTool", "XEditorObjectPalette", "XPlaceMultipleObjectsToolBase" },
	properties = {
		slider = true, persisted_setting = true, auto_select_all = true,
		{ id = "AngleDeviation", name = "Angle deviation", editor = "number", default = 0, min = 0, max = 180, step = 1, },
		{ id = "Scale", editor = "number", default = 100, min = 10, max = 250, step = 1, },
		{ id = "ScaleDeviation", name = "Scale deviation", editor = "number", default = 0, min = 0, max = 100, step = 1, },
		{ id = "ColorMin", name = "Color min", editor = "color", default = RGB(100, 100, 100), },
		{ id = "ColorMax", name = "Color max", editor = "color", default = RGB(100, 100, 100), },
	},
	
	ToolTitle = "Place multiple objects",
	
	ActionSortKey = "06",
	ActionIcon = "CommonAssets/UI/Editor/Tools/PlaceMultipleObject.tga", 
	ActionShortcut = "A",
}

---
--- Returns the terrain normal, scale, scale deviation, angle deviation, color min, and color max parameters for the XPlaceMultipleObjectsTool.
---
--- @return number terrain_normal The terrain normal.
--- @return number scale The scale.
--- @return number scale_deviation The scale deviation.
--- @return number angle_deviation The angle deviation.
--- @return table color_min The minimum color.
--- @return table color_max The maximum color.
function XPlaceMultipleObjectsTool:GetParams()
	return self.terrain_normal, self:GetScale(), self:GetScaleDeviation(), self:GetAngleDeviation(), self:GetColorMin(), self:GetColorMax()
end

---
--- Returns the classes that can be placed using the XPlaceMultipleObjectsTool.
---
--- @return table The classes that can be placed.
function XPlaceMultipleObjectsTool:GetClassesForDelete()
	return self:GetObjectClass()
end

---
--- Returns the classes that can be placed using the XPlaceMultipleObjectsTool.
---
--- @return table The classes that can be placed.
function XPlaceMultipleObjectsTool:GetClassesForPlace()
	return self:GetObjectClass()
end