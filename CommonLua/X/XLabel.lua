DefineClass.XLabel = {
	__parents = { "XTranslateText" },
	
	HandleMouse = false,
	Padding = box(2, 0, 2, 0),
	ShadowColor = RGBA(0, 0, 0, 48),
	ShadowSize = 1,
	
	highlighted_text = false,
	ignore_case = false,
}

local UIL = UIL
---
--- Measures the size of the text content for the XLabel object.
---
--- @param preferred_width number The preferred width for the label.
--- @param preferred_height number The preferred height for the label.
--- @return number, number The measured width and height of the label's text.
---
function XLabel:Measure(preferred_width, preferred_height)
	local width, height = UIL.MeasureText(self.text, self:GetFontId())
	return width, Max(height, self.font_height)
end

local function find_next(str_lower, str, substr, start_pos)
	local idx = string.find(str_lower, substr, start_pos, true)
	if idx then
		return str:sub(start_pos, idx - 1), str:sub(idx, idx + #substr - 1)
	else
		return str:sub(start_pos)
	end
end

local one = point(1, 1)
local StretchText = UIL.StretchText
local StretchTextShadow = UIL.StretchTextShadow
local StretchTextOutline = UIL.StretchTextOutline
local MeasureToCharStart = UIL.MeasureToCharStart
---
--- Draws the content of the XLabel object, including any text shadows or highlights.
---
--- @param self XLabel The XLabel object to draw.
---
function XLabel:DrawContent()
	local text = self.text
	if text == "" then return end
	local shadow_type = self.ShadowType
	local shadow_size = self.ShadowSize
	local shadow_color = self:GetEnabled() and self.ShadowColor or self.DisabledShadowColor
	local cbox = self.content_box
	local font = self:GetFontId()
	if GetAlpha(shadow_color) == 0 or shadow_size == 0 then -- no shadow
		StretchText(text, cbox, font, self:CalcTextColor(), 0)
	elseif shadow_type == "shadow" then
		StretchTextShadow(text, cbox, font, self:CalcTextColor(), shadow_color, shadow_size, one, 0)
	elseif shadow_type == "extrude" then
		StretchTextShadow(text, cbox, font, self:CalcTextColor(), shadow_color, shadow_size, one, 0, true)
	elseif shadow_type == "outline" then
		StretchTextOutline(text, cbox, font, self:CalcTextColor(), shadow_color, shadow_size, 0)
	end
	
	if self.highlighted_text then
		local lower_text = self.ignore_case and text:lower() or text
		local other, word = find_next(lower_text, text, self.highlighted_text, 1)
		if word then
			local len_word = utf8.len(word)
			local len_other = utf8.len(other)
			local x1 = MeasureToCharStart(text, font, len_other + 1)
			local x2 = MeasureToCharStart(text, font, len_word + len_other + 1)
			local x, y1, _, y2 = cbox:xyxy()
			StretchText(word, box(x + x1, y1, x + x2, y2), font, self.highlight_color)
		end
	end
end

---
--- Highlights the specified text in the XLabel object with the given color.
---
--- @param text string The text to highlight.
--- @param color table The color to use for the highlighted text.
--- @param ignore_case boolean If true, the highlighting will be case-insensitive.
---
function XLabel:HighlightText(text, color, ignore_case)
	if self.highlighted_text == text and self.highlight_color == color and self.ignore_case == ignore_case then return end
	self.highlighted_text = text
	self.highlight_color = color
	self.ignore_case = ignore_case
	self:Invalidate()
end

DefineClass.XEmbedLabel = {
	__parents = { "XTranslateText" },
	properties = {
		{ category = "Visual", id = "UseXTextControl", editor = "bool", default = false, },
	},
}

---
--- Initializes an XEmbedLabel object.
---
--- @param parent table The parent object of the XEmbedLabel.
--- @param context table The context for the XEmbedLabel.
---
function XEmbedLabel:Init(parent, context)
	self:SetUseXTextControl(self.UseXTextControl, context)
	self:SetTranslate(self.Translate)
	self:SetText(self.Text)
end

---
--- Sets whether the XEmbedLabel should use an XText or XLabel control.
---
--- @param value boolean Whether to use an XText control.
--- @param context table The context for the XEmbedLabel.
---
function XEmbedLabel:SetUseXTextControl(value, context)
	local class = value and "XText" or "XLabel"
	local label = rawget(self, "idLabel")
	if label then
		context = label.context
		label:delete()
	end
	label = g_Classes[class]:new({
		Id = "idLabel",
		VAlign = "center",
		Translate = self.Translate
	}, self, context)
	label:SetFontProps(self)
	self.UseXTextControl = value
end

LinkTextPropertiesToChild(XEmbedLabel, "idLabel")
