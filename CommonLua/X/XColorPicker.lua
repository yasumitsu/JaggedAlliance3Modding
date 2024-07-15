DefineClass.ColorPalette = {
	__parents = {"Preset"},
	properties = {
		{id = "Group", editor = false, }
	},

	EditorMenubar = "Editors.Art",
	EditorMenubarName = "Color Palette",
}

local color_palette_rows = 6
local color_palette_columns = 8
local color_palette_total = color_palette_rows * color_palette_columns

--- Returns a plain object representation of the color palette.
---
--- The returned object has properties named `color1` through `color{color_palette_total}` and `text1` through `text{color_palette_total}` that correspond to the color and text values in the color palette.
---
--- @return table A plain object representation of the color palette.
function ColorPalette:ColorsPlainObj()
	local obj = {}
	for i = 1, color_palette_total do
		local p = "color" .. i
		obj[p] = self[p]
	end
	for i = 1, color_palette_total do
		local p = "text" .. i
		obj[p] = self[p]
	end
	return obj
end

for i = 1, color_palette_total do
	local category = "Row" .. ((i - 1) / color_palette_columns) + 1
	table.insert(ColorPalette.properties, {
		id = "color" .. i,
		name = "Color " .. i,
		editor = "color",
		default = RGBA(0, 0, 0, 255),
		category = category,
	})
	table.insert(ColorPalette.properties, {
		id = "text" .. i,
		name = "Text " .. i,
		editor = "text",
		translate = false,
		default = "",
		category = category,
	})
end

if FirstLoad then
	CurrentColorPalette = false
end

function OnMsg.ClassesBuilt()
	CurrentColorPalette = CurrentColorPalette or ColorPalette:new({})
end

function OnMsg.DataLoaded()
	CurrentColorPalette = Presets.ColorPalette and Presets.ColorPalette.Default and Presets.ColorPalette.Default[1] or CurrentColorPalette
end

--- Updates the current color palette to the default color palette from the presets.
---
--- This function is called after the color palette is saved. It sets the `CurrentColorPalette`
--- variable to the first default color palette from the `Presets.ColorPalette.Default` table,
--- if it exists. Otherwise, it keeps the current `CurrentColorPalette` value.
function ColorPalette:OnPostSave()
	CurrentColorPalette = Presets.ColorPalette and Presets.ColorPalette.Default and Presets.ColorPalette.Default[1] or CurrentColorPalette
end

--------------------- Color Picker code --------------------

local function GetColorMode(component)
	if component == "HUE" or component == "SATURATION" or component == "BRIGHTNESS"then
		return "HSV"
	end
	if component == "RED" or component == "GREEN" or component == "BLUE" then
		return "RGB"
	end
end

local ComponentShaderFlags = {
	["RED"]        = const.modColorPickerRed,
	["GREEN"]      = const.modColorPickerGreen,
	["BLUE"]       = const.modColorPickerBlue,
	["SATURATION"] = const.modColorPickerSaturation,
	["BRIGHTNESS"] = const.modColorPickerBrightness,
	["HUE"]        = const.modColorPickerHue,
	["ALPHA"]      = const.modColorPickerAlpha,
}

local function IsColorSame(a, b)
	return a.RED == b.RED and a.BLUE == b.BLUE and a.GREEN == b.GREEN and a.ALPHA == b.ALPHA
		and a.HUE == b.HUE and a.SATURATION == b.SATURATION and a.BRIGHTNESS == b.BRIGHTNESS
end

local function RecalculateHSVComponentsOf(color)
	local h, s, v
	if color.RED == 0 and color.GREEN == 0 and color.BLUE == 0 then
		h, s, v = 0, 0, 0
	else
		h, s, v = UIL.RGBtoHSV(MulDivRound(color.RED, 255, 1000), MulDivRound(color.GREEN, 255, 1000), MulDivRound(color.BLUE, 255, 1000))
	end
	
	color.HUE = MulDivRound(h, 1000, 255)
	color.SATURATION = MulDivRound(s, 1000, 255)
	color.BRIGHTNESS = MulDivRound(v, 1000, 255)
end

local function RecalculateRGBComponentsOf(color)
	-- hue 255 should be interpreted as 0
	local hue = MulDivRound(color.HUE, 255, 1000)
	if hue == 255 then hue = 0 end
	
	local r, g, b = UIL.HSVtoRGB(hue, MulDivRound(color.SATURATION, 255, 1000), MulDivRound(color.BRIGHTNESS, 255, 1000))
	color.RED = MulDivRound(r, 1000, 255)
	color.GREEN = MulDivRound(g, 1000, 255)
	color.BLUE = MulDivRound(b, 1000, 255)
end

local function GetRGBAComponentsIn255Of(color)
	return MulDivRound(color.RED, 255, 1000), MulDivRound(color.GREEN, 255, 1000), MulDivRound(color.BLUE, 255, 1000), MulDivRound(color.ALPHA, 255 , 1000)
end

---
--- Converts a color value from a string representation to a RGBA table.
---
--- The string representation can be in the following formats:
--- - `r,g,b,a`: Comma-separated RGBA values, where each value is between 0 and 255.
--- - `r,g,b`: Comma-separated RGB values, where each value is between 0 and 255. The alpha value will be set to 255.
--- - `0xHHHHHH` or `#HHHHHH`: Hexadecimal color value, where H is a hexadecimal digit (0-9, A-F, a-f). The alpha value will be set to 255 if the hexadecimal value has 6 or fewer digits.
--- - `value`: A decimal or hexadecimal number that represents the color value. The function will attempt to parse the value as decimal first, and then as hexadecimal if the decimal parsing fails.
---
--- @param value string The string representation of the color.
--- @param prefer_dec boolean (optional) If true, the function will prefer to parse the value as a decimal number instead of a hexadecimal number.
--- @return RGBA The color value as a table with the keys `RED`, `GREEN`, `BLUE`, and `ALPHA`.
function ConvertColorFromText(value, prefer_dec)
	local r, g, b, a = value:match("^([^,]+),([^,]+),([^,]+),([^,]+)")
	if not r then
		a = 255
		r, g, b = value:match("^([^,]+),([^,]+),([^,]+)")
	end
	if not r then
		local hex = value:match("^%s*0[xX]([0-9a-fA-F]+)")
		if not hex then
			hex = value:match("^%s*#([0-9a-fA-F]+)")
		end
		if hex and #hex > 0 then
			local hex_value = tonumber(hex, 16)
			if hex_value then
				r, g, b, a = GetRGBA(hex_value)
				if a == 0 and #hex <= 6 then
					a = 255
				end
			end
		end
	end
	if not r then
		local hex_value = tonumber(value, prefer_dec and 10 or 16)
		if hex_value then
			r, g, b, a = GetRGBA(hex_value)
		end
	end
	
	r, g, b, a = tonumber(r) or 0, tonumber(g) or 0, tonumber(b) or 0, tonumber(a) or 0
	r = Clamp(r, 0, 255)
	g = Clamp(g, 0, 255)
	b = Clamp(b, 0, 255)
	a = Clamp(a, 0, 255)
	return RGBA(r, g, b, a)
end

DefineClass.XColorPicker = {
	__parents = { "XControl", "XActionsHost" },
	
	properties = {
		{ category = "General", id = "AdditionalComponent", editor = "choice", default = "none", items = {"none", "alpha", "intensity"} },
		{ category = "General", id = "ShowColorPalette", editor = "bool", default = true },
	},
	
	LayoutMethod = "HList",
	Padding = box(5, 5, 5, 5),
	BorderWidth = 1,
	BorderColor = RGB(32, 32, 32),
	Background = 0,
	FocusedBackground = 0,
	
	MaxHeight = 350,
	
	selected_checkbox = false,
	strip_color_component = false,
	current_color = false, -- table
	OnColorChanged = false,
	RolloverMode = false,
}

---
--- Updates the currently selected color in the color palette.
---
--- This function is responsible for updating the border color of the currently selected color in the color palette grid. It compares the current color of the XColorPicker to the background color of each color button in the palette grid, and sets the border color of the currently selected button to a different color to indicate that it is selected.
---
--- @param self XColorPicker The XColorPicker instance.
---
function XColorPicker:UpdateCurrentlySelectedPaletteColor()
	if not rawget(self, "PaletteGrid") then return end
	local current_color = RGB(GetRGB(self:GetColor()))
	for i = 1, color_palette_total do
		local ctrl =  self["idButtonColor" .. i]
		if RGB(GetRGB(ctrl.Background)) == current_color then
			ctrl.BorderColor = RGB(167, 167, 167)
		else
			ctrl.BorderColor = RGB(0, 0, 0)
		end
	end
end

---
--- Initializes an XColorPicker instance.
---
--- This function is responsible for setting up the various components of the XColorPicker, including the color square, color strip, alpha strip, and color palette grid. It also sets up the input controls for adjusting the color components, and handles events such as color changes and double-clicks.
---
--- @param self XColorPicker The XColorPicker instance.
--- @param rollover_color_picker_mode boolean Whether the color picker is in rollover mode.
---
function XColorPicker:Init(rollover_color_picker_mode)
	local gedapp = rawget(_G, "g_GedApp")
	local scale = (gedapp and gedapp.color_picker_scale or 100) * 10
	self:SetScaleModifier(point(scale, scale))

	self.current_color = {
		RED = 0,
		GREEN = 0,
		BLUE = 0,
		HUE = 0,
		SATURATION = 0,
		BRIGHTNESS = 0,
		ALPHA = 1000,
	}
	
	XColorSquare:new({
		Id = "idColorSquare",
		MinWidth = 200,
		MinHeight = 200,
		Margins = box(2, 2, 2, 2),
		Background = RGB(255, 255, 255),
		OnColorChanged = function(square, color, double_click)
			self:SetColorInternal(color)
			if double_click then
				self:Close()
			end
		end,
	}, self)

	XColorStrip:new({
		Id = "idColorStrip",
		MinWidth = 300,
		MinHeight = 45,
		slider_orientation = "horizontal",
		OnColorChanged = function(stripe, color) self:UpdateComponent(self.strip_color_component, color[self.strip_color_component]) end
	}, self):SetDock("bottom")
	
	XColorStrip:new({
		Id = "idAlphaStrip",
		MinWidth = 45,
		MinHeight = 200,
		Margins = box(2, 2, 2, 2),
		OnColorChanged = function(stripe, color) self:UpdateComponent("ALPHA", color.ALPHA) end
	}, self):SetVisible(self.AdditionalComponent ~= "none")
	if self.AdditionalComponent == "none" then
		self.idAlphaStrip:SetDock("ignore")
	end
	
	XWindow:new({
		Id = "idRightPanel",
		LayoutMethod = "VList",
		MinWidth = 150,
		MinHeight = 200,
		BorderColor = RGB(0, 0, 0),
		BorderWidth = 0,
		Padding = box(2, 0, 2, 0),
		Pargins = box(2, 0, 0, 0),
	}, self)

	local color_palette = gedapp and gedapp.color_palette or CurrentColorPalette or false
	XWindow:new({
		Id = "PaletteGrid",
		LayoutMethod = "VList",
		BorderColor = RGB(0, 0, 0),
		BorderWidth = 0,
		Padding = box(2, 2, 2, 2),
	}, self.idRightPanel)
	for y = 1, color_palette_rows do
		local row = XWindow:new({
			LayoutMethod = "HList",
		}, self.PaletteGrid)
		for x = 1, color_palette_columns do
			local color_idx = (x + (y - 1) * color_palette_columns)
			local color = color_palette and color_palette["color" .. color_idx] or RGB(255,255,255)
			local text = color_palette and color_palette["text" .. color_idx] or ""
			XButton:new({
				Id = "idButtonColor" .. color_idx,
				Background = color,
				RolloverBackground = color,
				PressedBackground = color,
				MinWidth = 30,
				MinHeight = 20,
				BorderColor = RGB(0, 0, 0),
				RolloverBorderColor = RGB(32, 32, 32),
				PressedBorderColor = RGB(64, 64, 64),
				BorderWidth = 2,
				Margins = box(2, 2, 2, 2),
				OnPress = function()
					self:SetColor(color)
				end,
				RolloverTranslate = false,
				RolloverTemplate = "GedPropRollover",
				RolloverTitle = text,
				RolloverText = text,
			}, row)
		end
	end
	self:UpdateCurrentlySelectedPaletteColor()
	
	XWindow:new({
		Id = "idInputs",
		LayoutMethod = "HPanel",
		VAlign = "center",
		HAlign = "center",
		MinWidth = 300,
		MinHeight = 200,
		Padding = box(4, 2, 4, 2),
		Background = RGBA(0, 0, 0, 0),
	}, self.idRightPanel)

	local left_inputs = XWindow:new({
		Id = "left",
		LayoutMethod = "VList",
		MinWidth = 150,
	}, self.idInputs)
	local right_inputs = XWindow:new({
		Id = "right",
		LayoutMethod = "VList",
		MinWidth = 150,
	}, self.idInputs)

	local hue_checkbox = self:MakeComponent({
		idEdit = "idHue",
		ComponentId = "HUE",
		Name = "H",
		Suffix = "°",
		Max = 360,
		focus_order = point(0, 0),
		parent = left_inputs,
		OnValueEdited = function(component_id, number) self:UpdateComponent(component_id, MulDivRound(number, 1000, 360)) end,
	})
	
	self:MakeComponent({
		idEdit = "idSat",
		ComponentId = "SATURATION",
		Name = "S",
		Suffix = "%",
		Max = 100,
		focus_order = point(0, 1),
		parent = left_inputs,
		OnValueEdited = function(component_id, number) self:UpdateComponent(component_id, MulDivRound(number, 1000, 100)) end,
	})
	
	self:MakeComponent({
		idEdit = "idBri",
		ComponentId = "BRIGHTNESS",
		Name = "B",
		Suffix = "%",
		Max = 100,
		focus_order = point(0, 2),
		parent = left_inputs,
		OnValueEdited = function(component_id, number) self:UpdateComponent(component_id, MulDivRound(number, 1000, 100)) end,
	})

	self:MakeComponent({
		idEdit = "idRed",
		ComponentId = "RED",
		Name = "R",
		Max = 255,
		focus_order = point(0, 3),
		parent = right_inputs,
		OnValueEdited = function(component_id, number) self:UpdateComponent(component_id, MulDivRound(number, 1000, 255))  end,
		Selectable = true,
	})
	
	self:MakeComponent({
		idEdit = "idGreen",
		ComponentId = "GREEN",
		Name = "G",
		Max = 255,
		focus_order = point(0, 4),
		parent = right_inputs,
		OnValueEdited = function(component_id, number) self:UpdateComponent(component_id, MulDivRound(number, 1000, 255))  end,
	})
	
	self:MakeComponent({
		idEdit = "idBlue",
		ComponentId = "BLUE",
		Name = "B",
		Max = 255,
		focus_order = point(0, 5),
		parent = right_inputs,
		OnValueEdited = function(component_id, number) self:UpdateComponent(component_id, MulDivRound(number, 1000, 255))  end,
	})
	
	if self.AdditionalComponent ~= "none" then
		self:MakeComponent({
			idEdit = "idAlpha",
			parent = right_inputs,
			ComponentId = "ALPHA",
			Name = self.AdditionalComponent == "alpha" and "A" or "I",
			Max = 255,
			VSpacing = 0,
			Selectable = false,
			focus_order = point(0, 6),
			OnValueEdited = function(component_id, number) self:UpdateComponent(component_id, MulDivRound(number, 1000, 255))  end,
		})
	end

	local bottom_left = XWindow:new({
	}, left_inputs)
	
	local hex_value = XEdit:new({
		Id = "idHexView",
		HAlign = "stretch",
		VAlign = "center",
	}, bottom_left)
	
	hex_value:SetText("0xFFFFFFFF")
	local function RefetchHexValue()
		local color_text = hex_value:GetText()
		local color = ConvertColorFromText(color_text)
		if color and color ~= self:GetColor() then
			self:SetColor(color)
		end
	end
	hex_value.OnKillFocus = function(self, ...)
		RefetchHexValue()
		return XEdit.OnKillFocus(self, ...)
	end
	hex_value.OnShortcut = function(self, shortcut, ...)
		if shortcut == "Enter" then
			RefetchHexValue()
			return "break"
		end
		return XEdit.OnShortcut(self, shortcut, ...)
	end

	hex_value:SetAutoSelectAll(true)

	if self.RolloverMode then
		local button = XTemplateSpawn("GedToolbarButton", bottom_left)
		button:SetDock("left")
		button:SetHAlign("left")
		button:SetVAlign("center")
		button:SetIcon("CommonAssets/UI/Ged/filter.tga")
		button:SetRolloverText("Pick color from game")
		button.OnPress = function(b)
			self.RolloverMode()
			self:Done()
		end
	end
	
	self:SetStripComponent("HUE", hue_checkbox)
	self:UpdateDisplayedComponents()
end

---
--- Updates a specific color component of the current color in the XColorPicker.
---
--- @param component_id string The ID of the color component to update (e.g. "RED", "GREEN", "BLUE", "HUE", "SATURATION", "BRIGHTNESS", "ALPHA")
--- @param value number The new value for the specified color component
---
function XColorPicker:UpdateComponent(component_id, value)
	local new_color = table.copy(self.current_color)
	new_color[component_id] = value
	
	-- recalculate others fields that might have changed
	local colorMode = GetColorMode(component_id)
	if colorMode == "RGB" then
		RecalculateHSVComponentsOf(new_color)
	elseif colorMode == "HSV" then
		RecalculateRGBComponentsOf(new_color)
	end
	self:SetColorInternal(new_color)
end

---
--- Sets the internal color of the XColorPicker.
---
--- @param color table The new color to set, represented as a table with keys for each color component (RED, GREEN, BLUE, ALPHA, HUE, SATURATION, BRIGHTNESS).
---
function XColorPicker:SetColorInternal(color)
	if not IsColorSame(self.current_color, color) then
		self.current_color = color
		if self.OnColorChanged then
			self:OnColorChanged(RGBA(GetRGBAComponentsIn255Of(color)))
		end
		self:UpdateDisplayedComponents()
		self.idColorSquare:SetColor(color)
		self.idColorStrip:SetColor(color)
		self.idAlphaStrip:SetColor(color)

		self:UpdateCurrentlySelectedPaletteColor()
	end
end

---
--- Returns the current color of the XColorPicker as an RGBA value.
---
--- @return RGBA The current color of the XColorPicker.
---
function XColorPicker:GetColor()
	return RGBA(GetRGBAComponentsIn255Of(self.current_color))
end

---
--- Sets the current color of the XColorPicker.
---
--- @param color RGBA The new color to set for the XColorPicker.
---
function XColorPicker:SetColor(color)
	color = color or RGBA(0, 0, 0, 0)
	local r, g, b, a = GetRGBA(color)
	local new_color = {
		RED = MulDivRound(r, 1000, 255),
		GREEN = MulDivRound(g, 1000, 255),
		BLUE = MulDivRound(b, 1000, 255),
		ALPHA = MulDivRound(a, 1000, 255),
	}
	RecalculateHSVComponentsOf(new_color)
	self:SetColorInternal(new_color)
end

---
--- Updates the displayed components of the XColorPicker to reflect the current color.
---
function XColorPicker:UpdateDisplayedComponents()
	local color = self.current_color
	self.idHue:SetText(tostring(MulDivRound(color.HUE, 360, 1000)))
	self.idSat:SetText(tostring(MulDivRound(color.SATURATION, 1, 10)))
	self.idBri:SetText(tostring(MulDivRound(color.BRIGHTNESS, 1, 10)))
	self.idRed:SetText(tostring(MulDivRound(color.RED, 255, 1000)))
	self.idGreen:SetText(tostring(MulDivRound(color.GREEN, 255, 1000)))
	self.idBlue:SetText(tostring(MulDivRound(color.BLUE, 255, 1000)))
	self.idHexView:SetText(string.format("0x%08X", self:GetColor()))
	if self.AdditionalComponent ~= "none" then
		self.idAlpha:SetText(tostring(MulDivRound(color.ALPHA, 255, 1000)))
	end
end

---
--- Sets the currently selected color component strip in the XColorPicker.
---
--- @param id string The ID of the color component to set as the selected strip.
--- @param control XCheckButton The check button control for the selected color component.
---
function XColorPicker:SetStripComponent(id, control)
	if self.selected_checkbox then
		self.selected_checkbox:SetCheck(false)
	end
	control:SetCheck(true)
	self.selected_checkbox = control
	
	self.strip_color_component = id
	self.idColorSquare:SetConstantColorComponent(id)
	self.idColorStrip:SetEditedColorComponent(id)
	self.idAlphaStrip:SetEditedColorComponent("ALPHA")
	
	self:UpdateDisplayedComponents()
end

---
--- Creates a component for the XColorPicker UI, including a check button, labels, and a number editor.
---
--- @param params table A table of parameters for the component, including:
---   - Min (number): The minimum value for the number editor.
---   - Max (number): The maximum value for the number editor.
---   - Selectable (boolean): Whether the component is selectable.
---   - VSpacing (number): The vertical spacing between the component and the previous one.
---   - ComponentId (string): The ID of the color component to set as the selected strip.
---   - Name (string): The name of the component.
---   - Suffix (string): The suffix to display for the component.
---   - idEdit (string): The ID of the number editor control.
---   - OnValueEdited (function): A callback function to be called when the value of the number editor is edited.
---   - focus_order (point): The focus order of the number editor control.
--- @param parent XWindow The parent window for the component.
--- @return XCheckButton The check button control for the component.
---
function XColorPicker:MakeComponent(params)
	params.Min = params.Min or 0
	params.Max = params.Max or 255
	params.Selectable = params.Selectable ~= false

	local parent = XWindow:new({
		Margins = box(0, 0, 0, params.VSpacing or 10),
	}, params.parent)
	
	local check_box = XCheckButton:new({
		Dock = "left",
		VAlign = "center",
		OnChange = function(control, check)
			self:SetStripComponent(params.ComponentId, control)
		end,
	}, parent)
	
	if not params.Selectable then
		check_box:SetVisible(false)
	end

	XLabel:new({
		Dock = "left",
		VAlign = "center",
	}, parent):SetText(params.Name .. ":")
	
	XLabel:new({
		Dock = "right",
		VAlign = "center",
		MinWidth = 25,
	}, parent):SetText(params.Suffix or "")
	
	CreateNumberEditor(
		XWindow:new({
			Dock = "box",
			VAlign = "center",
		}, parent),
		params.idEdit,
		function(multiplier)
			local value = tonumber(self[params.idEdit]:GetText()) or 0
			params.OnValueEdited(params.ComponentId, Clamp(value + multiplier, params.Min, params.Max))
		end,
		function(multiplier)
			local value = tonumber(self[params.idEdit]:GetText()) or 0
			params.OnValueEdited(params.ComponentId, Clamp(value - multiplier, params.Min, params.Max))
		end
	)
	local edit_control = self[params.idEdit]
	edit_control:SetFocusOrder(params.focus_order or point(0, 0))
	edit_control.OnKillFocus = function(self)
		if self then
			local value = tonumber(edit_control:GetText()) or 0
			params.OnValueEdited(params.ComponentId, Clamp(value, params.Min, params.Max))
			XEdit.OnKillFocus(self)
		end
	end
	
	return check_box
end


---- Strip color picker

DefineClass.XColorStrip = {
	__parents = { "XControl" },
	
	Padding = box(2, 2, 2, 2),
	BorderWidth = 1,
	BorderColor = RGBA(32, 32, 32, 255),
	Background = RGBA(0, 0, 0, 0),
	
	slider_orientation = "vertical",
	slider_color = RGB(32, 32, 32),
	slider_size = point(10, 20),
	slider_image_right = "CommonAssets/UI/arrowright-40.tga",
	slider_image_left = "CommonAssets/UI/arrowleft-40.tga",
	slider_image_down = "CommonAssets/UI/arrowdown-40.tga",
	slider_image_up = "CommonAssets/UI/arrowup-40.tga",
	slider_image_srect = box(0, 0, 16, 40),
	slider_image_srect_horizontal = box(0, 0, 40, 16),
	strip_background_image = "CommonAssets/UI/checker-pattern-40.tga",
	gradient_modifier = false,
	strip_color_component = false,
	current_color = false, -- table
	OnColorChanged = false,
}

--- Initializes the `XColorStrip` class.
--
-- This function is called when an `XColorStrip` object is created. It sets the initial values for the `current_color` table, which represents the current color of the color strip. It also adds a shader modifier to the object, which is used to modify the appearance of the color strip.
--
-- @function [parent=#XColorStrip] Init
-- @return nil
function XColorStrip:Init()
	self.current_color = {
		RED = 0,
		GREEN = 0,
		BLUE = 0,
		HUE = 0,
		SATURATION = 0,
		BRIGHTNESS = 0,
		ALPHA = 1000,
	}
	self.gradient_modifier = self:AddShaderModifier({
		modifier_type = const.modShader,
	})
end

--- Handles the mouse button up event for the XColorStrip control.
--
-- This function is called when the left mouse button is released on the XColorStrip control. It captures the mouse position and updates the current color of the strip based on the mouse position. If the `OnColorChanged` callback is set, it is called with the new color.
--
-- @function [parent=#XColorStrip] OnMouseButtonUp
-- @param pt The mouse position when the button was released.
-- @param button The mouse button that was released ("L" for left, "R" for right, "M" for middle).
-- @return "break" to indicate that the event has been handled.
function XColorStrip:OnMouseButtonDown(pt, button)
	if button == "L" then
		self.desktop:SetMouseCapture(self)
		self:OnMousePos(pt)
		return "break"
	end
end

--- Handles the mouse button up event for the XColorStrip control.
--
-- This function is called when the left mouse button is released on the XColorStrip control. It captures the mouse position and updates the current color of the strip based on the mouse position. If the `OnColorChanged` callback is set, it is called with the new color.
--
-- @function [parent=#XColorStrip] OnMouseButtonUp
-- @param pt The mouse position when the button was released.
-- @param button The mouse button that was released ("L" for left, "R" for right, "M" for middle).
-- @return "break" to indicate that the event has been handled.
function XColorStrip:OnMouseButtonUp(pt, button)
	if button == "L" then
		self:OnMousePos(pt)
		self.desktop:SetMouseCapture()
		return "break"
	end
end

--- Handles the mouse position event for the XColorStrip control.
--
-- This function is called when the mouse position changes while the left mouse button is held down on the XColorStrip control. It updates the current color of the strip based on the mouse position. If the `OnColorChanged` callback is set, it is called with the new color.
--
-- @function [parent=#XColorStrip] OnMousePos
-- @param pt The current mouse position.
-- @return "break" to indicate that the event has been handled.
function XColorStrip:OnMousePos(pt)
	if self.desktop:GetMouseCapture() ~= self then return "break" end
	
	local content_box = self.content_box
	local percent
	if self.slider_orientation == "vertical" then
		percent = 1000 - Clamp(MulDivRound(pt:y() - content_box:miny(), 1000, content_box:sizey()), 0, 1000)
	else
		percent = 1000 - Clamp(MulDivRound(pt:x() - content_box:minx(), 1000, content_box:sizex()), 0, 1000)
	end

	local new_color = table.copy(self.current_color)
	new_color[self.strip_color_component] = percent
	if GetColorMode(self.strip_color_component) == "RGB" then
		RecalculateHSVComponentsOf(new_color)
	else
		RecalculateRGBComponentsOf(new_color)
	end

	self:SetColor(new_color)
	if self.OnColorChanged then
		self:OnColorChanged(new_color)
	end
	
	self:Invalidate()
	return "break"
end

---
--- Sets the current color of the XColorStrip control.
---
--- If the current color is different from the provided `color` parameter, this function updates the current color and calls `UpdateGradientModifier()` to update the gradient modifier.
---
--- @param color table The new color to set for the XColorStrip control.
function XColorStrip:SetColor(color)
	if not IsColorSame(self.current_color, color) then
		self.current_color = color
		self:UpdateGradientModifier()
	end
end

--- Sets the color component that the XColorStrip control should edit.
--
-- If the current color component is different from the provided `component` parameter, this function updates the current color component and calls `UpdateGradientModifier()` to update the gradient modifier.
--
-- @function [parent=#XColorStrip] SetEditedColorComponent
-- @param component string The new color component to set for the XColorStrip control.
function XColorStrip:SetEditedColorComponent(component)
	if self.strip_color_component ~= component then
		self.strip_color_component = component
		self:UpdateGradientModifier()
	end
end

---
--- Returns the current value of the color component that the XColorStrip control is editing.
---
--- @return number The current value of the edited color component.
function XColorStrip:GetEditedColorComponent()
	return self.current_color[self.strip_color_component]
end

---
--- Updates the gradient modifier for the XColorStrip control based on the current color and color component being edited.
---
--- This function sets the `shader_flags` property of the `gradient_modifier` object based on the current `strip_color_component`. It then updates the modifier's color values based on the current `current_color` and the color mode for the `strip_color_component`.
---
--- If the `strip_color_component` is "RGB" or "ALPHA", the modifier's color values are set to the corresponding RGB and alpha values from the `current_color` table.
---
--- If the `strip_color_component` is "HUE", the modifier's color values are all set to 1000.
---
--- If the `strip_color_component` is neither "RGB", "ALPHA", nor "HUE", the modifier's color values are set to the corresponding HUE, SATURATION, BRIGHTNESS, and ALPHA values from the `current_color` table.
---
--- After updating the modifier, this function calls `self:Invalidate()` to trigger a redraw of the XColorStrip control.
---
function XColorStrip:UpdateGradientModifier()
	self.gradient_modifier.shader_flags = const.modColorPickerStrip | ComponentShaderFlags[self.strip_color_component]
	local modifier = self.gradient_modifier
	local color = self.current_color
	if GetColorMode(self.strip_color_component) == "RGB" or self.strip_color_component == "ALPHA" then
		modifier[1] = color.RED
		modifier[2] = color.GREEN
		modifier[3] = color.BLUE
		modifier[4] = color.ALPHA
	elseif self.strip_color_component == "HUE" then
		modifier[1] = 1000
		modifier[2] = 1000
		modifier[3] = 1000
		modifier[4] = 1000
	else
		modifier[1] = color.HUE
		modifier[2] = color.SATURATION
		modifier[3] = color.BRIGHTNESS
		modifier[4] = color.ALPHA
	end
	self:Invalidate()
end

local PushClipRect = UIL.PushClipRect
local PopClipRect = UIL.PopClipRect

---
--- Returns the size of the arrows for the XColorStrip control.
---
--- The size of the arrows is determined by the `slider_size` property and the `slider_orientation` property. If the `slider_orientation` is "vertical", the arrows size is the same as the `slider_size`. If the `slider_orientation` is not "vertical", the arrows size is the transpose of the `slider_size`.
---
--- @return point The size of the arrows for the XColorStrip control.
function XColorStrip:ArrowsSize()
	local arrows_size = point(ScaleXY(self.scale, self.slider_size:x(), self.slider_size:y()))
	if self.slider_orientation ~= "vertical" then
		arrows_size = point(arrows_size:y(), arrows_size:x())
	end
	return arrows_size
end

---
--- Returns the bounding box of the color strip, excluding the arrows.
---
--- The color strip's bounding box is calculated based on the `content_box` property and the size of the arrows. If the `slider_orientation` is "vertical", the strip box excludes the width of the arrows on the left and right sides. If the `slider_orientation` is not "vertical", the strip box excludes the height of the arrows on the top and bottom sides.
---
--- @return sizebox The bounding box of the color strip, excluding the arrows.
function XColorStrip:GetStripBox()
	local arrows_size = self:ArrowsSize()
	local content_box = self.content_box
	local strip_box
	if self.slider_orientation == "vertical" then
		strip_box = box(content_box:minx() + arrows_size:x(), content_box:miny(), content_box:maxx() - arrows_size:x(), content_box:maxy())
	else
		strip_box = box(content_box:minx(), content_box:miny() + arrows_size:y(), content_box:maxx(), content_box:maxy() - arrows_size:y())
	end
	return strip_box
end

-- DrawContent is called with modifiers enabled so the solid rect will actually be a gradient
---
--- Draws the content of the XColorStrip control.
---
--- The content of the XColorStrip control is drawn as a gradient or a rotated checkerboard pattern, depending on the `slider_orientation` property.
---
--- If the `slider_orientation` is "vertical", the content is drawn as a solid rectangle with a gradient from white to black.
---
--- If the `slider_orientation` is not "vertical", the content is drawn as a rotated checkerboard pattern using the `DrawImageFit` function. The checkerboard pattern is loaded from the "CommonAssets/UI/checker-pattern-40.tga" file.
---
--- @param clip_box sizebox The clipping box for the content.
function XColorStrip:DrawContent(clip_box)
	local strip_box = self:GetStripBox()
	if self.slider_orientation == "vertical" then
		UIL.DrawSolidRect(strip_box, RGBA(255, 255, 255, 255), RGBA(0, 0, 0, 0), point(1000, 1000), point(0, 0))
	else
		-- we use drawimagefit as it has all the properties we need, checker-pattern-40 is loaded anyway for the background.
		local w, h = UIL.MeasureImage("CommonAssets/UI/checker-pattern-40.tga")
		local center = strip_box:min() + strip_box:size() / 2
		local top_left = center - point(strip_box:sizey() / 2, strip_box:sizex() / 2)
		local rotated_box = sizebox(top_left:x(), top_left:y(), strip_box:sizey(), strip_box:sizex())
		UIL.DrawImageFit("CommonAssets/UI/checker-pattern-40.tga", rotated_box, rotated_box:sizex(), rotated_box:sizey(), box(0,0,w,h), RGB(255,255,255),
			0, --[[angle]] 90 * 60, --[[flips]] false, false)
	end
end

---
--- Draws the background of the XColorStrip control.
---
--- This function is currently empty, as the background is drawn in the `DrawWindow` function.
---
function XColorStrip:DrawBackground()
end

---
--- Draws the window of the XColorStrip control.
---
--- This function is responsible for drawing the background, border, and selection indicator of the XColorStrip control.
---
--- The background is drawn using the `DrawFrame` function, which draws a checkerboard pattern for the alpha values. The gradient is then drawn using the `XWindow.DrawWindow` function.
---
--- The border is drawn using the `DrawBorderRect` function, with the border width and color specified by the `BorderWidth` and `BorderColor` properties.
---
--- The selection indicator is drawn as an arrow on the left/right or top/bottom of the strip, depending on the `slider_orientation` property. The position of the arrow is calculated based on the `GetEditedColorComponent` function, which returns a value between 0 and 1000 representing the currently edited color component.
---
--- @param clip_box sizebox The clipping box for the window.
function XColorStrip:DrawWindow(clip_box)
	local content_box = self.content_box
	local arrows_size = self:ArrowsSize()
	
	-- draw the checkers background for alpha values
	local strip_box = self:GetStripBox()
	UIL.DrawFrame(self.strip_background_image, strip_box, 1, 1, 1, 1, box(0, 0, 0, 0), false, false, 350, 350, false, false)
	
	-- draw gradient
	XWindow.DrawWindow(self, clip_box)
	
	-- draw border
	local border_width, border_height = ScaleXY(self.scale, self.BorderWidth, self.BorderWidth)
	local border_box = GrowBox(strip_box, border_width)
	UIL.DrawBorderRect(border_box, border_width, border_height, self:CalcBorderColor(), RGBA(0, 0, 0, 0))

	-- draw the selection
	local weight = 1000 - Clamp(self:GetEditedColorComponent(), 0, 1000)
	if self.slider_orientation == "vertical" then
		local sliderY = content_box:miny() + MulDivRound(weight, content_box:sizey(), 1000)

		local left_arrow = sizebox(content_box:minx(), sliderY - arrows_size:y() / 2, arrows_size:x(), arrows_size:y())
		local right_arrow = sizebox(content_box:maxx() - arrows_size:x(), sliderY - arrows_size:y() / 2, arrows_size:x(), arrows_size:y())
		
		UIL.DrawImageFit(self.slider_image_right, left_arrow, arrows_size:x(), arrows_size:y(), self.slider_image_srect, self.slider_color, 0)
		UIL.DrawImageFit(self.slider_image_left, right_arrow, arrows_size:x(), arrows_size:y(), self.slider_image_srect, self.slider_color, 0)
	else
		local sliderX = content_box:minx() + MulDivRound(weight, content_box:sizex(), 1000)

		local up_arrow = sizebox(sliderX - arrows_size:x() / 2, content_box:miny(), arrows_size:x(), arrows_size:y())
		local down_arrow = sizebox(sliderX - arrows_size:x() / 2, content_box:maxy() - arrows_size:y(), arrows_size:x(), arrows_size:y())
		
		UIL.DrawImageFit(self.slider_image_down, up_arrow, arrows_size:x(), arrows_size:y(), self.slider_image_srect_horizontal, self.slider_color, 0)
		UIL.DrawImageFit(self.slider_image_up, down_arrow, arrows_size:x(), arrows_size:y(), self.slider_image_srect_horizontal, self.slider_color, 0)
	end
end


--- Square color picker

DefineClass.XColorSquare = {
	__parents = { "XControl" },
	
	Clip = "parent & self",
	Padding = box(2, 2, 2, 2),
	BorderWidth = 1,
	BorderColor = RGB(32, 32, 32),
	Background = RGB(255, 255, 255),
	
	slider_color = RGB(128, 128, 128),
	slider_size = point(20, 20),
	slider_image = "CommonAssets/UI/circle-20.tga",
	gradient_modifier = false,
	constant_color_component = false,
	edited_component_id1 = false,
	edited_component_id2 = false,
	current_color = false, -- table
	OnColorChanged = false,
}

--- Initializes the XColorSquare control.
--
-- This function sets up the initial state of the XColorSquare control, including the default color values and a shader modifier for the gradient.
--
-- The `current_color` table is initialized with the following default values:
--   - `RED`: 0
--   - `GREEN`: 0
--   - `BLUE`: 0
--   - `HUE`: 0
--   - `SATURATION`: 0
--   - `BRIGHTNESS`: 0
--   - `ALPHA`: 1000
--
-- The `gradient_modifier` field is set to a new shader modifier with the type `const.modShader`.
function XColorSquare:Init()
	self.current_color = {
		RED = 0,
		GREEN = 0,
		BLUE = 0,
		HUE = 0,
		SATURATION = 0,
		BRIGHTNESS = 0,
		ALPHA = 1000,
	}
	self.gradient_modifier = self:AddShaderModifier({
		modifier_type = const.modShader,
	})
end

--- Measures the size of the XColorSquare control.
--
-- This function calculates the size of the XColorSquare control based on the provided maximum width and height. It returns the minimum of the maximum width and height as both the width and height of the control.
--
-- @param max_width (number) The maximum allowed width of the control.
-- @param max_height (number) The maximum allowed height of the control.
-- @return (number, number) The width and height of the control.
function XColorSquare:Measure(max_width, max_height)
	local size = Min(max_width, max_height)
	return size, size
end

--- Handles the mouse button down event for the XColorSquare control.
--
-- This function is called when the left mouse button is pressed on the XColorSquare control. It sets the mouse capture for the control and calls the `OnMousePos` function to update the color based on the mouse position.
--
-- @param pt (Point) The current mouse position.
-- @param button (string) The mouse button that was pressed ("L" for left).
-- @return (string) "break" to indicate that the event has been handled.
function XColorSquare:OnMouseButtonDown(pt, button)
	if button == "L" then
		self.desktop:SetMouseCapture(self)
		self:OnMousePos(pt)
		return "break"
	end
end

--- Handles the mouse button up event for the XColorSquare control.
--
-- This function is called when the left mouse button is released on the XColorSquare control. It updates the color based on the final mouse position and releases the mouse capture for the control.
--
-- @param pt (Point) The current mouse position.
-- @param button (string) The mouse button that was released ("L" for left).
-- @return (string) "break" to indicate that the event has been handled.
function XColorSquare:OnMouseButtonUp(pt, button)
	if button == "L" then
		self:OnMousePos(pt)
		self.desktop:SetMouseCapture()
		return "break"
	end
end

--- Handles the mouse position event for the XColorSquare control.
--
-- This function is called when the mouse is moved while the left mouse button is pressed on the XColorSquare control. It updates the color of the control based on the current mouse position within the control's content box.
--
-- @param pt (Point) The current mouse position.
-- @return (string) "break" to indicate that the event has been handled.
function XColorSquare:OnMousePos(pt)
	if self.desktop:GetMouseCapture() ~= self then return "break" end
	local content_box = self.content_box
		
	local percent_x = 1000 - Clamp((pt:x() - content_box:minx()) * 1000 / content_box:sizex(), 0, 1000)
	local percent_y = 1000 - Clamp((pt:y() - content_box:miny()) * 1000 / content_box:sizey(), 0, 1000)
		
	local new_color = table.copy(self.current_color)
	new_color[self.edited_component_id1] = percent_x
	new_color[self.edited_component_id2] = percent_y
	if GetColorMode(self.constant_color_component) == "RGB" then
		RecalculateHSVComponentsOf(new_color)
	else
		RecalculateRGBComponentsOf(new_color)
	end
	
	self:SetColor(new_color)
	if self.OnColorChanged then
		self:OnColorChanged(new_color)
	end
	
	return "break"
end

--- Handles the mouse double click event for the XColorSquare control.
--
-- This function is called when the left mouse button is double clicked on the XColorSquare control. It triggers the OnColorChanged event with the current color and a flag indicating that the change was caused by a double click.
--
-- @param pt (Point) The current mouse position.
-- @param button (string) The mouse button that was double clicked ("L" for left).
-- @return (string) "break" to indicate that the event has been handled.
function XColorSquare:OnMouseButtonDoubleClick(pt, button)
	if self.OnColorChanged then
		self:OnColorChanged(self.current_color, true)
	end
	return "break"
end
--- Sets the color of the XColorSquare control.
--
-- This function is used to update the color of the XColorSquare control. If the new color is different from the current color, the current color is updated and the gradient modifier is updated accordingly.
--
-- @param color (table) A table representing the new color, with keys for the color components (e.g. RED, GREEN, BLUE, ALPHA).

function XColorSquare:SetColor(color)
	if not IsColorSame(self.current_color, color) then
		self.current_color = color
		self:UpdateGradientModifier()
	end
end

--- Sets the constant color component for the XColorSquare control.
--
-- This function is used to set the constant color component for the XColorSquare control. The constant color component determines which color component (RGB or HSV) will be held constant while the other two components are edited.
--
-- @param component (string) The name of the constant color component. Can be "RED", "GREEN", "BLUE", "HUE", "SATURATION", or "BRIGHTNESS".
function XColorSquare:SetConstantColorComponent(component)
	if self.constant_color_component ~= component then
		self.constant_color_component = component
		if component == "RED" then
			self.edited_component_id1, self.edited_component_id2 = "GREEN", "BLUE"
		elseif component == "GREEN" then
			self.edited_component_id1, self.edited_component_id2 = "RED", "BLUE"
		elseif component == "BLUE" then
			self.edited_component_id1, self.edited_component_id2 = "RED", "GREEN"
		elseif component == "HUE" then
			self.edited_component_id1, self.edited_component_id2 = "SATURATION", "BRIGHTNESS"
		elseif component == "SATURATION" then
			self.edited_component_id1, self.edited_component_id2 = "HUE", "BRIGHTNESS"
		elseif component == "BRIGHTNESS" then
			self.edited_component_id1, self.edited_component_id2 = "HUE", "SATURATION"
		end
		self:UpdateGradientModifier()
	end
end

--- Gets the two color components that are currently being edited in the XColorSquare control.
--
-- This function returns the values of the two color components that are currently being edited in the XColorSquare control. The specific components that are being edited depend on the value of the `constant_color_component` property.
--
-- @return (number, number) The values of the two edited color components.
function XColorSquare:GetEditedColorComponents()
	return self.current_color[self.edited_component_id1], self.current_color[self.edited_component_id2]
end

--- Updates the gradient modifier for the XColorSquare control.
--
-- This function is used to update the gradient modifier for the XColorSquare control. It sets the shader flags based on the constant color component, and then sets the color components in the gradient modifier based on whether the color mode is RGB or HSV.
--
-- @param self (XColorSquare) The XColorSquare instance.
function XColorSquare:UpdateGradientModifier()
	self.gradient_modifier.shader_flags = const.modColorPickerSquare | ComponentShaderFlags[self.constant_color_component]
	local modifier = self.gradient_modifier
	local color = self.current_color
	if GetColorMode(self.constant_color_component) == "RGB" then
		modifier[1] = color.RED
		modifier[2] = color.GREEN
		modifier[3] = color.BLUE
		modifier[4] = color.ALPHA
	else
		modifier[1] = color.HUE
		modifier[2] = color.SATURATION
		modifier[3] = color.BRIGHTNESS
		modifier[4] = color.ALPHA
	end
end

--- Draws the background of the XColorSquare control.
--
-- This function is responsible for drawing the background of the XColorSquare control. It is currently empty, as the background is likely drawn elsewhere in the code.
function XColorSquare:DrawBackground()
end

--- Draws the content of the XColorSquare control.
--
-- This function is responsible for drawing the content of the XColorSquare control. It draws a solid rectangle with a white fill and transparent border, covering the entire content area of the control.
--
-- @param self (XColorSquare) The XColorSquare instance.
-- @param clip_rect (box) The clipping rectangle to use when drawing the content.
function XColorSquare:DrawContent(clip_rect)
	UIL.DrawSolidRect(self.content_box, RGBA(255, 255, 255, 255), RGBA(0, 0, 0, 0), point(1000, 1000), point(0, 0))
end

--- Draws the window of the XColorSquare control.
--
-- This function is responsible for drawing the window of the XColorSquare control. It first calls the `DrawWindow` function of the `XWindow` class to draw the window. Then, it draws the border of the control, and the selection indicator within the content area of the control.
--
-- @param self (XColorSquare) The XColorSquare instance.
-- @param clip_rect (box) The clipping rectangle to use when drawing the window.
function XColorSquare:DrawWindow(clip_rect)
	-- draw the gradient
	XWindow.DrawWindow(self, clip_rect)
	
	local content_box = self.content_box
	
	-- draw border
	local border_width, border_height = ScaleXY(self.scale, self.BorderWidth, self.BorderWidth)
	local border_box = GrowBox(content_box, border_width)
	UIL.DrawBorderRect(border_box, border_width, border_height, self:CalcBorderColor(), RGBA(0, 0, 0, 0))
	
	-- draw the selection
	PushClipRect(content_box, true)
	local x, y = self:GetEditedColorComponents()
	local weight_x = 1000 - Clamp(x, 0, 1000)
	local weight_y = 1000 - Clamp(y, 0, 1000)
	
	local slider_pos = point(content_box:minx() + weight_x * content_box:sizex() / 1000, content_box:miny() + weight_y * content_box:sizey() / 1000)
	local slider_size = point(ScaleXY(self.scale, self.slider_size:x(), self.slider_size:y()))
	local slider_box = sizebox(slider_pos - slider_size / 2, slider_size)

	local circle_color = self.current_color.BRIGHTNESS < 500 and RGB(200, 200, 200) or RGB(32, 32, 32)
	UIL.DrawImageFit(self.slider_image, slider_box, slider_size:x(), slider_size:y(), box(0, 0, self.slider_size:x(), self.slider_size:y()), circle_color, 0)
	PopClipRect()
end