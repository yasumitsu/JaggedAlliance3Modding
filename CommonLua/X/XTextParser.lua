local FindNextLineBreakCandidate = utf8.FindNextLineBreakCandidate
local GetLineBreakInfo = utf8.GetLineBreakInfo

local function SetFont(font, scale)
	local text_style = TextStyles[font]
	if not text_style then
		assert(false, string.format("Invalid text style '%s'", font))
		return 0, 0, 0
	end
	local font_id, height, baseline = text_style:GetFontIdHeightBaseline(scale:y())
	if not font_id or font_id < 0 then
		assert(false, string.format("Invalid font in text style '%s'", font))
		return 0, 0, 0
	end
	return font_id, height, baseline
end

 ------------ Layouting -----------
DefineClass.XTextBlock = {
	__parents = { "PropertyObject" },

	exec = false, -- for command blocks

	total_width = false, -- if this were to be placed on a single line, how long would it be?
	total_height = false,
	min_start_width = false, -- minimum required space to start the token.
	new_line_forbidden = false, -- should be started after the last token on the same line.
	end_line_forbidden = false,
	is_content = false, -- if the word wrapper should layout this.
}

---
--- Processes the `newline` tag in the XTextParser.
---
--- This function is called when the `newline` tag is encountered in the input text.
--- It creates a new line in the layout, with an optional left margin specified by the first argument.
---
--- @param state table The current parsing state.
--- @param args table The arguments passed to the `newline` tag.
---
tag_processors.newline = function(state, args)
	state:MakeFuncBlock(function(layout)
		layout.left_margin = (tonumber(args[1]) or 0) * state.scale:x() / 1000
		layout:NewLine(false)
	end)
end

---
--- Processes the `vspace` tag in the XTextParser.
---
--- This function is called when the `vspace` tag is encountered in the input text.
--- It sets the vertical space between lines in the layout, and then creates a new line.
---
--- @param state table The current parsing state.
--- @param args table The arguments passed to the `vspace` tag.
---
tag_processors.vspace = function(state, args)
	local vspace = tonumber(args[1])
	if not vspace then
		state:PrintErr("Vspace should be a number")
		return
	end
	state:MakeFuncBlock(function(layout)
		layout:SetVSpace(vspace)
		layout:NewLine(false)
	end)
end

---
--- Processes the `zwnbsp` tag in the XTextParser.
---
--- This function is called when the `zwnbsp` tag is encountered in the input text.
--- It creates a block with zero width and height, and sets the `new_line_forbidden` and `end_line_forbidden` flags to `true`.
---
--- @param state table The current parsing state.
--- @param args table The arguments passed to the `zwnbsp` tag.
---
tag_processors.zwnbsp = function(state, args)
	state:MakeBlock({
		total_width = 0,
		total_height = 0,
		min_start_width = 0,
		new_line_forbidden = true,
		end_line_forbidden = true,
		text = "",
	})
end

---
--- Processes the `linespace` tag in the XTextParser.
---
--- This function is called when the `linespace` tag is encountered in the input text.
--- It sets the line spacing for the current layout.
---
--- @param state table The current parsing state.
--- @param args table The arguments passed to the `linespace` tag.
---
tag_processors.linespace = function(state, args)
	local linespace = tonumber(args[1])
	if not linespace then
		state:PrintErr("Linespace should be a number")
		return
	end
	state:MakeFuncBlock(function(layout)
		layout.font_linespace = linespace
	end)
end

---
--- Processes the `valign` tag in the XTextParser.
---
--- This function is called when the `valign` tag is encountered in the input text.
--- It sets the vertical alignment and y-offset for the current layout.
---
--- @param state table The current parsing state.
--- @param args table The arguments passed to the `valign` tag.
---
tag_processors.valign = function(state, args)
	local alignment = args[1]
	assert(alignment == "top" or alignment == "center" or alignment == "bottom")
	state.valign = args[1]
	state.y_offset = MulDivTrunc(args[2] or 0, state.scale:x(), 1000)
end

---
--- Processes the `hide` tag in the XTextParser.
---
--- This function is called when the `hide` tag is encountered in the input text.
--- It skips over the text that is enclosed within the `hide` and `/hide` tags.
---
--- @param state table The current parsing state.
--- @param args table The arguments passed to the `hide` tag.
--- @param tok_idx_start integer The index of the starting token for the `hide` tag.
--- @return integer The number of tokens that were skipped.
---
tag_processors.hide = function(state, args, tok_idx_start)
	local tokens = state.tokens
	local hide_counter = 1
	local tok_idx = tok_idx_start + 1
	while tok_idx < #tokens do
		local token = tokens[tok_idx]
		tok_idx = tok_idx + 1
		if token.type == "hide" then
			hide_counter = hide_counter + 1
		elseif token.type == "/hide" then
			hide_counter = hide_counter - 1
			if hide_counter == 0 then
				break
			end
		end
	end
	return tok_idx - tok_idx_start
end

---
--- Processes the closing `/hide` tag in the XTextParser.
---
--- This function is called when the closing `/hide` tag is encountered in the input text.
--- It does nothing, but is still interpreted as a tag.
---
--- @param state table The current parsing state.
--- @param args table The arguments passed to the `/hide` tag.
---
tag_processors["/hide"] = function(state, args)
	-- do nothing but still interpret this as a tag
end

---
--- Processes the `background` tag in the XTextParser.
---
--- This function is called when the `background` tag is encountered in the input text.
--- It sets the background color of the text based on the provided arguments.
---
--- @param state table The current parsing state.
--- @param args table The arguments passed to the `background` tag.
---
tag_processors.background = function(state, args)
	if args[1] == "none" then
		state:PushStackFrame("background").background = RGBA(0,0,0,0)
		return
	end

	if #args == 1 then
		local color = tonumber(args[1])
		if not color then
			local style = TextStyles[GetTextStyleInMode(args[1], GetDarkModeSetting()) or args[1]]
			if not style then
				state:PrintErr("TextStyle could not be found (" .. args[1] .. ")")
				color = RGB(255, 255, 255)
			else
				color = style.TextColor
			end
		end
		assert(type(color) == "number")
		state:PushStackFrame("background").background_color = color
	else
		local num1 = tonumber(args[1]) or 255
		local num2 = tonumber(args[2]) or 255
		local num3 = tonumber(args[3]) or 255
		local num4 = tonumber(args[4]) or 255
		state:PushStackFrame("background").background_color = RGBA(num1, num2, num3, num4)
	end
end

---
--- Processes the closing `/background` tag in the XTextParser.
---
--- This function is called when the closing `/background` tag is encountered in the input text.
--- It removes the current background stack frame, effectively resetting the background color to the previous state.
---
--- @param state table The current parsing state.
--- @param args table The arguments passed to the `/background` tag.
---
tag_processors["/background"] = function(state, args)
	state:PopStackFrame("background")
end

---
--- Processes the `hyperlink` tag in the XTextParser.
---
--- This function is called when the `hyperlink` tag is encountered in the input text.
--- It sets the hyperlink properties of the text based on the provided arguments.
---
--- @param state table The current parsing state.
--- @param args table The arguments passed to the `hyperlink` tag.
---
tag_processors.hyperlink = function(state, args) -- check for "underline" as the last argument
	if     args[1] == "underline" then args[1], state.hl_underline = "", true
	elseif args[6] == "underline" then args[6], state.hl_underline = "", true
	elseif args[5] == "underline" then args[5], state.hl_underline = "", true
	elseif args[4] == "underline" then args[4], state.hl_underline = "", true
	elseif args[3] == "underline" then args[3], state.hl_underline = "", true
	end

	-- decode arguments
	if args[5] and args[5] ~= "" then -- <h function argument r g b [underline]>
		state.hl_argument = args[2]
		state.hl_hovercolor = RGB(tonumber(args[3]) or 255, tonumber(args[4]) or 255, tonumber(args[5]) or 255)
	elseif args[4] and args[4]~= "" then -- <h function r g b [underline]>
		state.hl_hovercolor = RGB(tonumber(args[2]) or 255, tonumber(args[3]) or 255, tonumber(args[4]) or 255)
	elseif args[3] and args[3]~= ""then -- <h function argument color [underline]>
		state.hl_argument = args[2]
		state.hl_hovercolor = const.HyperlinkColors[args[3]]
	else -- <h function color [underline]>
		state.hl_hovercolor = const.HyperlinkColors[args[2]]
	end

	state.hl_internalid = state.hl_internalid + 1
	state.hl_function = args[1]
	if state.hl_argument == "true" then
		state.hl_argument = true
	elseif state.hl_argument == "false" then
		state.hl_argument = false
	elseif tonumber(state.hl_argument) then
		state.hl_argument = tonumber(state.hl_argument)
	end
end
tag_processors.h = tag_processors.hyperlink

---
--- Resets the hyperlink properties of the current parsing state.
---
--- This function is called when the `/hyperlink` tag is encountered in the input text.
--- It resets the hyperlink-related properties of the current parsing state, such as the
--- hyperlink function, argument, hover color, and underline flag.
---
--- @param state table The current parsing state.
--- @param args table The arguments passed to the `/hyperlink` tag.
---
tag_processors["/hyperlink"] = function(state, args)
	state.hl_function = nil
	state.hl_argument = nil
	state.hl_hovercolor = nil
	state.hl_underline = nil
end
tag_processors["/h"] = tag_processors["/hyperlink"]

---
--- Sets the color of the shadow effect.
---
--- This function is called when the `shadowcolor` tag is encountered in the input text.
--- It sets the color of the shadow effect in the current parsing state.
---
--- @param state table The current parsing state.
--- @param args table The arguments passed to the `shadowcolor` tag.
---
tag_processors.shadowcolor = function(state, args)
	local effect_color
	if args[1] == "none" then
		effect_color = RGBA(0, 0, 0, 0)
	else
		if not (args[1] ~= "" and args[2] ~= "" and args[3] ~= "") then
			state:PrintErr("found tag 'shadowcolor' without 3 value for RGB :", text, n)
		end
		effect_color = RGB(tonumber(args[1]) or 255, tonumber(args[2]) or 255, tonumber(args[3]) or 255)
	end
	local frame = state:PushStackFrame("effect")
	frame.effect_color = effect_color
end

---
--- Removes the shadow effect from the current parsing state.
---
--- This function is called when the `/shadowcolor` tag is encountered in the input text.
--- It removes the shadow effect from the current parsing state by popping the "effect" stack frame.
---
--- @param state table The current parsing state.
--- @param args table The arguments passed to the `/shadowcolor` tag.
---
tag_processors["/shadowcolor"] = function(state, args)
	state:PopStackFrame("effect")
end

local effect_types = {
	shadow = "shadow",
	glow = "glow",
	outline = "outline",
	extrude = "extrude",
	["false"] = false,
	["none"] = false,
}

---
--- Processes the `effect` tag in the input text.
---
--- This function is called when the `effect` tag is encountered in the input text.
--- It sets the various properties of the effect (type, color, size, direction) in the current parsing state.
---
--- @param state table The current parsing state.
--- @param args table The arguments passed to the `effect` tag.
---
tag_processors["effect"] = function(state, args)
	local effect_type = "shadow"
	local effect_color = RGB(64, 64, 64)
	local effect_size = 2
	local effect_dir = point(1,1)

	local effect_type = effect_types[args[1]]
	if effect_type == nil then
		state:PrintErr("tag effect with invalid type", args[1])
		effect_type = false
	end
	effect_size = tonumber(args[2]) or 2
	effect_color = RGB(tonumber(args[3]) or 255, tonumber(args[4]) or 255, tonumber(args[5]) or 255)
	effect_dir = point(tonumber(args[6]) or 1, tonumber(args[7]) or 1)

	local frame = state:PushStackFrame("effect")
	frame.effect_color = effect_color
	frame.effect_size = effect_size
	frame.effect_type = effect_type
	frame.effect_dir = effect_dir
end

---
--- This function is called when the `/effect` tag is encountered in the input text.
--- It removes the current effect from the parsing state by popping the "effect" stack frame.
---
--- @param state table The current parsing state.
--- @param args table The arguments passed to the `/effect` tag.
---
tag_processors["/effect"] = function(state, args)
	state:PopStackFrame("effect")
end

local function remove_after(tbl, idx)
	while tbl[idx] do
		table.remove(tbl, #tbl)
	end
end

---
--- Removes all elements from the `state.stackable_state` table starting from index 2 to the end.
---
--- This function is used to reset the parsing state by removing all elements from the `state.stackable_state` table, except for the first element.
---
--- @param state table The current parsing state.
--- @param args table The arguments passed to the `reset` tag.
---
tag_processors.reset = function(state, args)
	remove_after(state.stackable_state, 2)
end

---
--- Handles the processing of text in the XTextParser.
--- This function is responsible for breaking down the input text into lines and handling tab characters.
---
--- @param state table The current parsing state.
--- @param text string The text to be processed.
---
tag_processors.text = function(state, text)
	-- handles \n and word_wrap
	local lines = {}
	local pos_bytes = 1
	local text_bytes = #text
	while pos_bytes <= text_bytes do
		local new_line_start_idx, new_line_end_idx = string.find(text, "\r?\n", pos_bytes)
		if not new_line_start_idx then
			new_line_start_idx = text_bytes + 1
			new_line_end_idx = text_bytes + 1
		end
		local line = string.sub(text, pos_bytes, new_line_start_idx - 1)
		table.insert(lines, line)
		
		pos_bytes = new_line_end_idx + 1
	end
	if string.sub(text, text_bytes) == "\n" then
		table.insert(lines, "")
	end

	for idx, line in ipairs(lines) do
		if idx > 1 then
			state:MakeFuncBlock(function(layout)
				layout:NewLine(false)
			end)
		end

		local line_byte_idx = 1
		while true do
			local istart, iend = string.find(line, "\t", line_byte_idx, true)
			local part = string.sub(line, line_byte_idx, (istart or 0) - 1)
			
			state:MakeTextBlock(part)

			if istart then
				local width, height = UIL.MeasureText("    ", state:fontId())
				state:MakeBlock({
					total_width = width,
					total_height = height,
					min_start_width = width,
					new_line_forbidden = false,
					end_line_forbidden = false,
					text = false,
				})
			else
				break
			end
			
			line_byte_idx = iend + 1
		end
	end
end

---
--- Processes an image tag in the text parser.
---
--- @param state table The current state of the text parser.
--- @param args table The arguments passed to the image tag.
---
tag_processors.image = function(state, args)
	local image = args[1]

	local image_size_org_x, image_size_org_y = UIL.MeasureImage(image)
	local current_image_scale_x, current_image_scale_y
	local arg2_scale = tonumber(args[2])
	if arg2_scale then
		current_image_scale_x = MulDivTrunc(arg2_scale * state.default_image_scale, state.scale:x(), 1000 * 1000)
		current_image_scale_y = MulDivTrunc(arg2_scale * state.default_image_scale, state.scale:y(), 1000 * 1000)
	else
		current_image_scale_x, current_image_scale_y = state.image_scale:xy()
	end
	
	local num1 = tonumber(args[3]) or 255
	local num2 = tonumber(args[4]) or 255
	local num3 = tonumber(args[5]) or 255
	local image_color = RGB(num1, num2, num3)
	
	if image_size_org_x == 0 and image_size_org_y == 0 then
		state:PrintErr("image not found in tag :", image)
	else
		local image_size_x = MulDivTrunc(image_size_org_x, current_image_scale_x, 1000)
		local image_size_y = MulDivTrunc(image_size_org_y, current_image_scale_y, 1000)
		local base_color_map = args[3] == "rgb" or args[6] == "rgb" -- if 3-d arg is the color then try 6-th
	
		state:MakeBlock({
			total_width = image_size_x,
			total_height = image_size_y,
			min_start_width = image_size_x,
			image_size_org_x = image_size_org_x,
			image_size_org_y = image_size_org_y,
			image = image,
			base_color_map = base_color_map,
			image_color = image_color,
			new_line_forbidden = true,
		})
	end
end


---
--- Processes a color tag in the text parser.
---
--- @param state table The current state of the text parser.
--- @param args table The arguments passed to the color tag.
---
tag_processors.color = function(state, args)
	local color
	if #args == 1 then
		color = tonumber(args[1])
		if not color then
			local style = TextStyles[GetTextStyleInMode(args[1], GetDarkModeSetting()) or args[1]]
			if not style then
				state:PrintErr("TextStyle could not be found (" .. args[1] .. ")")
				color = RGB(255, 255, 255)
			else
				color = style.TextColor
			end
		end
		assert(type(color) == "number")
	else
		local num1 = tonumber(args[1]) or 255
		local num2 = tonumber(args[2]) or 255
		local num3 = tonumber(args[3]) or 255
		local num4 = tonumber(args[4]) or 255
		color = RGBA(num1, num2, num3, num4)
	end
	-- used for Ged help rollovers in dark mode
	if state.invert_colors then
		local r, g, b, a = GetRGBA(color)
		if r == g and g == b then
			local v = Max(240 - r, 0)
			color = RGBA(v, v, v, a)
		end
	end
	state:PushStackFrame("color").color = color
end

---
--- Processes an alpha tag in the text parser.
---
--- @param state table The current state of the text parser.
--- @param args table The arguments passed to the alpha tag.
---
tag_processors.alpha = function(state, args)
	local alpha = tonumber(args[1])
	local top = state:GetStackTop()
	local r, g, b = GetRGB(top.color or top.start_color)
	state:PushStackFrame("color").color = RGBA(r, g, b, alpha)
end

---
--- Processes the end of a color tag in the text parser.
---
--- @param state table The current state of the text parser.
--- @param args table The arguments passed to the "/color" tag.
---
tag_processors["/color"] = function(state, args)
	state:PopStackFrame("color")
end
tag_processors["/alpha"] = tag_processors["/color"]

---
--- Processes a scale tag in the text parser.
---
--- @param state table The current state of the text parser.
--- @param args table The arguments passed to the scale tag.
---
tag_processors.scale = function(state, args)
	local scale_num = tonumber(args[1] or 1000)
	if not scale_num then
		state:PrintErr("Bad scale ", args[1])
		return
	end
	state.scale = state.original_scale * Max(1, scale_num) / 1000
	state.imagescale = state.scale
	local top = state:GetStackTop()
	local next_id, height = SetFont(top.font_name, state.scale)
	local frame = state:PushStackFrame("scale")
	frame.font_id = next_id
	frame.font_height = height
end

---
--- Processes an imagescale tag in the text parser.
---
--- @param state table The current state of the text parser.
--- @param args table The arguments passed to the imagescale tag.
---
tag_processors.imagescale = function(state, args)
	local scale_num = tonumber(args[1] or state.default_image_scale)
	if not scale_num then
		state:PrintErr("Bad scale ", args[1])
		return
	end

	state.image_scale = state.original_scale * Max(1, scale_num) / 1000
end

---
--- Processes a style tag in the text parser.
---
--- @param state table The current state of the text parser.
--- @param args table The arguments passed to the style tag.
---
tag_processors.style = function(state, args)
	local style = TextStyles[GetTextStyleInMode(args[1], GetDarkModeSetting()) or args[1]]
	if style then
		local next_id, height = SetFont(args[1], state.scale)
		local frame = state:PushStackFrame("style")
		frame.font_id = next_id
		frame.font_height = height
		frame.font_name = args[1]
		frame.color = style.TextColor
		frame.effect_color = style.ShadowColor
		frame.effect_size = style.ShadowSize
		frame.effect_type = style.ShadowType
		frame.effect_dir = style.ShadowDir
	else
		state:PrintErr("Invalid style", args[1])
	end
end

---
--- Processes the end of a style tag in the text parser.
---
--- @param state table The current state of the text parser.
--- @param args table The arguments passed to the "/style" tag.
---
tag_processors["/style"] = function(state, args)
	state:PopStackFrame("style")
end

---
--- Processes a wordwrap tag in the text parser.
---
--- @param state table The current state of the text parser.
--- @param args table The arguments passed to the wordwrap tag.
---
--- This function sets the word wrap behavior of the text layout based on the provided arguments.
--- If the argument is "on" or "off", it will print an error and return, as the argument should be a boolean value.
--- Otherwise, it will set the `word_wrap` property of the layout to the provided boolean value.
---
tag_processors.wordwrap = function(state, args)
	local word_wrap = args[1]
	if word_wrap == "on" or word_wrap == "off" then
		state:PrintErr("WordWrap should be on or off")
		return
	end

	state:MakeFuncBlock(function(layout)
		layout.word_wrap = word_wrap == "on"
	end)
end

---
--- Processes a right alignment tag in the text parser.
---
--- @param state table The current state of the text parser.
--- @param args table The arguments passed to the "right" tag.
---
--- This function sets the alignment of the text layout to "right".
---
tag_processors.right = function(state, args)
	state:MakeFuncBlock(function(layout)
		layout:SetAlignment("right")
	end)
end

---
--- Processes a left alignment tag in the text parser.
---
--- @param state table The current state of the text parser.
--- @param args table The arguments passed to the "left" tag.
---
--- This function sets the alignment of the text layout to "left".
---
tag_processors.left = function(state, args)
	state:MakeFuncBlock(function(layout)
		layout:SetAlignment("left")
	end)
end

---
--- Processes a center alignment tag in the text parser.
---
--- @param state table The current state of the text parser.
--- @param args table The arguments passed to the "center" tag.
---
--- This function sets the alignment of the text layout to "center".
---
tag_processors.center = function(state, args)
	state:MakeFuncBlock(function(layout)
		layout:SetAlignment("center")
	end)
end

---
--- Processes a tab tag in the text parser.
---
--- @param state table The current state of the text parser.
--- @param args table The arguments passed to the "tab" tag.
---
--- This function sets a tab position in the text layout. The first argument is the tab position in pixels, and the second argument is the tab alignment ("left", "right", or "center").
---
tag_processors.tab = function(state, args)
	state:MakeFuncBlock(function(layout)
		--assert(not layout.word_wrap) -- tabs do not work with word wrap
		local tab_pos = tonumber(args[1]) * state.scale:x() / 1000
		if not tab_pos then
			layout:PrintErr("Bad tab pos", args[1])
			return
		end
		layout:SetTab(tab_pos, args[2])
	end)
end

---
--- Processes an underline tag in the text parser.
---
--- @param state table The current state of the text parser.
--- @param args table The arguments passed to the "underline" tag.
---
--- This function sets the underline state and color of the text layout. The first argument is the color of the underline, which can be a named color from the `TextStyles` table or an RGB value. If no color is provided, the underline is set to the default color.
---
tag_processors.underline = function(state, args)
	if args[1] and (args[2] and args[3] or TextStyles[args[1]] or tonumber(args[1])) then
		if args[2] and args[3] then
			state.underline_color = RGB(tonumber(args[1]) or 255, tonumber(args[2]) or 255, tonumber(args[3]) or 255)
		else
			state.underline_color = TextStyles[args[1]] and TextStyles[args[1]].TextColor or tonumber(args[1])
		end
	else
		state.underline_color = false
	end
	state.underline = true
end

---
--- Processes a horizontal line tag in the text parser.
---
--- @param state table The current state of the text parser.
--- @param args table The arguments passed to the "horizontal_line" tag.
---
--- This function creates a block in the text layout to represent a horizontal line. The first argument is the thickness of the line in pixels, the second argument is the margin around the line, the third argument is the space above the line, and the fourth argument is the space below the line. If no arguments are provided, default values are used.
---
--- The horizontal line is drawn using the current text color and scale.
---
tag_processors.horizontal_line = function(state, args)
	local thickness = args[1] or 1
	local margin = args[2] or 0
	local space_above = args[3] or 5
	local space_below = args[4] or 50
	local stack = state:GetStackTop()
	local color = stack.color
	local scale = Max(stack.font_height and MulDivRound(1000, stack.font_height, 20) or 0, 1000)
	state:MakeBlock({
		min_start_width = 9999999, 
		total_width = 9999999,
		total_height = MulDivRound(scale, space_above + space_below + thickness, 1000),
		space_above = space_above,
		space_below = space_below,
		horizontal_line = true,
		thickness = thickness,
		margin = margin,
		color = color,
		scale = scale,
	})
end

---
--- Resets the underline state and color of the text layout.
---
--- @param state table The current state of the text parser.
--- @param args table The arguments passed to the "/underline" tag.
---
--- This function sets the underline state to `false` and the underline color to `false`, effectively disabling the underline.
---
tag_processors["/underline"] = function(state, args)
	state.underline = false
	state.underline_color = false
end

DefineClass.BlockBuilder = {
	__parents = {"InitDone"},

	IsEnabled = false,
	first_error = false,

	line_height = 0,
	valign = "center",
	y_offset = 0,
	stackable_state = false,
	underline = false,
	underline_color = RGBA(0, 0, 0, 0),
	scale = point(1000, 1000),
	original_scale = point(1000, 1000),
	default_image_scale = 1000,
	image_scale = point(1000, 1000),

	hl_internalid = 0,
	hl_function = false,
	hl_argument = false,
	hl_hovercolor = false,
	hl_underline = false,

	blocks = false,
}

---
--- Initializes the BlockBuilder object.
---
--- This function sets up the initial state of the BlockBuilder object, including the default font, color, and effect settings. It also initializes an empty table to store the blocks that will be built.
---
--- @param self table The BlockBuilder object being initialized.
---
function BlockBuilder:Init()
	self.stackable_state = {
		{
			font_id = 0,
			font_name = "Console", -- needs to be an existing TextStyle; this one's in Common
			color = false,
			font_height = 32,
			effect_color = 0,
			effect_size = 0,
			effect_type = false,
			effect_dir = point(1,1),
			start_color = 0,
		}
	}

	self.blocks = {}
end

---
--- Processes a list of tokens and handles them according to their type.
---
--- This function takes a list of tokens and the original source text, and processes each token by calling the appropriate handler function based on the token type. If an invalid token type is encountered, an error is printed.
---
--- @param self table The BlockBuilder object.
--- @param tokens table A list of tokens to process.
--- @param src_text string The original source text.
---
function BlockBuilder:ProcessTokens(tokens, src_text)
	self.tokens = tokens
	self.src_text = src_text

	local token_idx = 1
	while token_idx <= #tokens do
		self.token_idx = token_idx
		local token = tokens[token_idx]
		local handler = tag_processors[token.type]
		local offset
		if handler then 
			offset = handler(self, token.args or token.text, token_idx) or 1
		else
			self:PrintErr("Encountered invalid token", token.type)
			offset = 1
		end
		token_idx = token_idx + offset
	end
end

---
--- Returns the top frame of the stackable state.
---
--- @return table The top frame of the stackable state.
---
function BlockBuilder:GetStackTop()
	return self.stackable_state[#self.stackable_state]
end

---
--- Pushes a new frame onto the stackable state.
---
--- This function creates a new frame based on the top frame of the stackable state, and pushes it onto the stack. The new frame's `tag` field is set to the provided `tag` argument.
---
--- @param self table The BlockBuilder object.
--- @param tag string The tag to associate with the new frame.
--- @return table The new frame that was pushed onto the stack.
---
function BlockBuilder:PushStackFrame(tag)
	assert(tag and type(tag) == "string")
	local stack = self.stackable_state
	assert(#stack >= 1)
	local new_frame = table.copy(stack[#stack])
	new_frame.tag = tag
	stack[#stack + 1] = new_frame
	return new_frame
end

---
--- Pops a frame from the stackable state.
---
--- This function removes the top frame from the stackable state. If the top frame's `tag` does not match the provided `tag` argument, an error message is printed.
---
--- @param self table The BlockBuilder object.
--- @param tag string The tag to match the top frame's tag against.
--- @return table The popped frame.
---
function BlockBuilder:PopStackFrame(tag)
	assert(tag and type(tag) == "string")
	local stack = self.stackable_state
	local top = stack[#stack]
	if #stack == 1 then
		self:PrintErr("Tag", tag, "has no more frames to pop.")
		return top
	end
	if top.tag ~= tag then
		self:PrintErr("Tag \"" .. top.tag .. "\" was closed with tag \"" .. tag .. "\"")
	end
	table.remove(stack)
	return top
end

DefineClass.XTextParserError = {
	__parents = {"PropertyObject"},
	src_text = "",

	__eq = function(self, other)
		if not IsKindOf(self, "XTextParserError") or not IsKindOf(other, "XTextParserError") then return false end
		return self.src_text == other.src_text
	end,
}

---
--- Prints an error message with the current token information.
---
--- This function formats an error message by combining the provided error arguments with the current token information. It stores the first error message encountered and associates it with the source text.
---
--- @param self table The BlockBuilder object.
--- @param ... any The error message arguments to format.
---
function BlockBuilder:PrintErr(...)
	local err = self:FormatErr(...)
	local token_list = {}
	for i = 1, #self.tokens do
		local token = self.tokens[i]
		local str = ""
		if token.type == "text" then
			str = token.text
		else
			str = "<color 40 160 40><literal " .. (#token.text + 2) .. "><" .. token.text .. "></color>"
		end
		table.insert(token_list, str)
		if self.token_idx == i then
			table.insert(token_list, "<color 160 40 40><literal 8><<<ERROR</color>")
		end
	end

	if not self.first_error then
		err = string.format("<color 160 40 40>XText Parse Error: </color><literal %s>%s\n%s", #err, err, table.concat(token_list, "<color 40 40 140> || </color>"))
		self.first_error = err
		StoreErrorSource(XTextParserError:new({src_text = self.src_text}), err)
	end
end

---
--- Formats an error message by combining the provided error arguments.
---
--- This function takes a variable number of arguments and concatenates them into a single error message string. It is used to format error messages that can be printed or stored.
---
--- @param self table The BlockBuilder object.
--- @param ... any The error message arguments to format.
--- @return string The formatted error message.
---
function BlockBuilder:FormatErr(...)
	local err = ""
	for _, arg in ipairs(table.pack(...)) do
		err = err .. tostring(arg) .. " "
	end
	return err
end

---
--- Returns the font ID of the current text block.
---
--- This function retrieves the font ID of the current text block from the top of the stack in the BlockBuilder object.
---
--- @return number The font ID of the current text block.
---
function BlockBuilder:fontId()
	return self:GetStackTop().font_id
end

---
--- Creates a new text block and adds it to the block list.
---
--- This function creates a new text block with the specified properties and adds it to the list of blocks maintained by the BlockBuilder object. The text block is represented by a table with various fields that define its appearance and behavior.
---
--- @param self table The BlockBuilder object.
--- @param cmd table The table of properties for the new text block.
---
function BlockBuilder:MakeBlock(cmd)
	local top = self:GetStackTop()
	cmd.height = top.font_height
	cmd.font = cmd.font or top.font_id
	cmd.color = top.color
	cmd.effect_color = top.effect_color
	cmd.effect_type = top.effect_type
	cmd.effect_size = top.effect_size
	cmd.effect_dir = top.effect_dir
	cmd.line_height = Max(self.line_height, top.font_height)
	cmd.y_offset = self.y_offset
	cmd.background_color = top.background_color
	
	cmd.underline = self.underline
	cmd.underline_color = self.underline and self.underline_color or false

	cmd.hl_function = self.hl_function
	cmd.hl_argument = self.hl_argument
	cmd.hl_underline = self.hl_underline
	cmd.hl_hovercolor = self.hl_hovercolor
	cmd.hl_internalid = self.hl_internalid


	if not IsKindOf(cmd, "XTextBlock") then
		cmd = XTextBlock:new(cmd)
	end
	
	table.insert(self.blocks, cmd)
end

---
--- Creates a new text block and adds it to the block list.
---
--- This function creates a new text block with the specified properties and adds it to the list of blocks maintained by the BlockBuilder object. The text block is represented by a table with various fields that define its appearance and behavior.
---
--- @param self table The BlockBuilder object.
--- @param text string The text to be displayed in the text block.
---
function BlockBuilder:MakeTextBlock(text)
	local width, height = UIL.MeasureText(text, self:fontId())
	local break_candidate = FindNextLineBreakCandidate(text, 1)
	local min_width = width
	if break_candidate and break_candidate < #text then
		min_width = UIL.MeasureText(text, self:fontId(), 1, break_candidate - 1)
	end
	local cannot_start_line, cannot_end_line = GetLineBreakInfo(text)
	self:MakeBlock({
		text = text,
		valign = self.valign,
		total_width = width,
		total_height = height,
		min_start_width = min_width,
		new_line_forbidden = cannot_start_line,
		end_line_forbidden = cannot_end_line,
	})
end

---
--- Creates a new text block and adds it to the block list.
---
--- This function creates a new text block with the specified function and adds it to the list of blocks maintained by the BlockBuilder object.
---
--- @param self table The BlockBuilder object.
--- @param func function The function to be executed in the text block.
---
function BlockBuilder:MakeFuncBlock(func)
	table.insert(self.blocks, XTextBlock:new({ exec = func }))
end

DefineClass.BlockLayouter = {
	__parents = {"PropertyObject"},

	tokens = false,
	blocks = false,
	draw_cache = false,

	pos_x = 0,
	left_margin = 0,
	line_position_y = 0,
	last_font_height = 0,
	line_height = 0,
	font_linespace = 0,

	word_wrap = true,
	shorten = true,
	shorten_string = false,
	max_width = 1000000,
	max_height = 1000000,

	--tab support
	alignment = "left",
	tab_x = 0,
	draw_cache_start_idx_current_line = 1,
	
	line_content_width = 0,
	line_was_word_wrapped = false,
	measure_width = 0,
	suppress_drawing_until = false,

	contains_wordwrapped_content = false,
}

local MeasureText = UIL.MeasureText
local Advance = utf8.Advance
local function FindTextThatFitsIn(line, start_idx, font_id, max_width, required_leftover_space, line_max_width)
	local pixels_reached = 0
	local byte_idx = start_idx
	local line_bytes = #line
	
	while byte_idx <= line_bytes do
		local next_break_idx = FindNextLineBreakCandidate(line, byte_idx)
		if not next_break_idx then
			break
		end

		--local wrapped_chunk = string.sub(line, byte_idx, next_break_idx - 1)
		local chunk_size = MeasureText(line, font_id, byte_idx, next_break_idx - 1)
		if next_break_idx >= line_bytes then
			chunk_size = chunk_size + required_leftover_space
		end
		if chunk_size + pixels_reached > max_width then
			-- can't fit even one word in the line? => split the text
			local split_text = max_width == line_max_width and pixels_reached == 0
			if not split_text then
				-- the next word wouldn't fit alone on the next line (without the leading space)? => split the text
				local idx = byte_idx
				if string.byte(line, idx) == 32 then -- eat empty space at the beginning
					idx = idx + 1
				end
				if MeasureText(line, font_id, idx, next_break_idx - 1) > line_max_width then
					split_text = true
				end
			end
			if split_text then
				local curr_break_idx = byte_idx
				while curr_break_idx < next_break_idx do
					local next_idx = Advance(line, curr_break_idx, 1)
					chunk_size = MeasureText(line, font_id, byte_idx, next_idx - 1)
					if chunk_size > max_width - pixels_reached then break end
					curr_break_idx = next_idx
				end
				byte_idx = curr_break_idx
				return string.sub(line, start_idx, byte_idx - 1), byte_idx - start_idx
			end
			break
		end
		pixels_reached = pixels_reached + chunk_size
		byte_idx = next_break_idx
	end

	if pixels_reached == 0 then
		return "", 0, 0
	end

	return string.sub(line, start_idx, byte_idx - 1), byte_idx - start_idx
end

--- Finalizes the current line in the block layouter.
---
--- This function is responsible for updating the draw cache with the final
--- positions and sizes of the elements in the current line. It also updates
--- the overall measure width of the block layouter based on the width of the
--- current line.
---
--- If the current line has a tab stop, the function will also finish the tab
--- by aligning the elements in the line based on the tab position.
---
--- @param self BlockLayouter The block layouter instance.
function BlockLayouter:FinalizeLine()
	self:FinishTab()
	
	if not self.draw_cache then self.draw_cache = {} end
	local draw_cache_line = self.draw_cache[self.line_position_y]
	if draw_cache_line then
		self.measure_width = Max(self.measure_width, self.line_content_width)
		for _, item in ipairs(draw_cache_line) do
			item.line_height = self.line_height
			
			if item.valign == "top" then
				item.y_offset = item.y_offset + 0
			elseif item.valign == "center" then
				item.y_offset = item.y_offset + (item.line_height - item.height) / 2
			elseif item.valign == "bottom" then
				item.y_offset = item.y_offset + item.line_height - item.height
			else
				assert(false)
			end
		end
	end
	self.line_content_width = 0
	self.line_was_word_wrapped = false
end

--- Starts a new line in the block layouter.
---
--- This function is responsible for finalizing the current line, updating the
--- line position, resetting the line height, and setting the starting position
--- for the next line. It also handles suppressing drawing until the next line
--- is started.
---
--- @param self BlockLayouter The block layouter instance.
--- @param word_wrapped Boolean indicating whether the new line was word-wrapped.
function BlockLayouter:NewLine(word_wrapped)
	self:FinalizeLine()

	self.line_position_y = self.line_position_y + Max(self.last_font_height / 2, self.line_height + self.font_linespace)
	self.line_height = 0
	self.pos_x = self.left_margin
	assert(word_wrapped == true or word_wrapped == false)
	self.line_was_word_wrapped = word_wrapped

	self.draw_cache_start_idx_current_line = 1

	if self.suppress_drawing_until == "new_line" then
		self.suppress_drawing_until = false
	end
end

--- Sets the alignment for the block layouter.
---
--- This function is responsible for setting the alignment for the block layouter.
--- If the alignment changes, it will finish the current tab and update the alignment.
--- If the alignment is not "left", the tab position will be reset to 0.
---
--- @param self BlockLayouter The block layouter instance.
--- @param align string The new alignment to set. Can be "left", "center", or "right".
function BlockLayouter:SetAlignment(align)
	if self.alignment ~= align then
		self:FinishTab()
		self.alignment = align

		if self.alignment ~= "left" then
			self.tab_x = 0
		end
	end
end

---
--- Sets the tab position and alignment for the block layouter.
---
--- This function is responsible for setting the tab position and alignment for the block layouter.
--- If the alignment changes, it will finish the current tab and update the alignment.
--- If the alignment is not "left", the tab position will be reset to 0.
---
--- @param self BlockLayouter The block layouter instance.
--- @param tab number The new tab position to set.
--- @param alignment string The new alignment to set. Can be "left", "center", or "right".
function BlockLayouter:SetTab(tab, alignment)
	if self.alignment ~= (alignment or "left") then
		self:SetAlignment(alignment or "left")
	else
		self:FinishTab()
	end
	self.tab_x = tab
end

---
--- Finishes the current tab in the block layouter.
---
--- This function is responsible for finalizing the current tab in the block layouter. It updates the positions of the items in the draw cache to align with the current tab position and alignment. It also updates the line content width and resets the tab position.
---
--- @param self BlockLayouter The block layouter instance.
function BlockLayouter:FinishTab()
	if not self.draw_cache then self.draw_cache = {} end
	local draw_cache_line = self.draw_cache[self.line_position_y]
	if not draw_cache_line then return end
	
	local draw_cache_start_idx = self.draw_cache_start_idx_current_line
	local used_width = 0
	for idx = draw_cache_start_idx, #draw_cache_line do
		local item = draw_cache_line[idx]
		used_width = Max(used_width, item.x + item.width)
	end

	local shift, alignment = 0, self.alignment
	if alignment == "center" then
		shift = -used_width / 2
	elseif alignment == "right" then
		shift = -used_width
	end

	shift = shift + self.tab_x

	for idx = draw_cache_start_idx, #draw_cache_line do
		local item = draw_cache_line[idx]
		item.x = item.x + shift
		if alignment == "center" then
			item.control_wide_center = true
		end
	end

	self.line_content_width = Max(self.line_content_width + used_width, used_width + self.tab_x)
	self.tab_x = 0
	self.draw_cache_start_idx_current_line = #draw_cache_line + 1
	self.pos_x = self.left_margin
end

---
--- Returns the available width for the current line in the block layouter.
---
--- This function calculates the available width for the current line by subtracting the current position (self.pos_x) from the maximum width (self.max_width). If the result is negative, it returns 0 to ensure the available width is never negative.
---
--- @param self BlockLayouter The block layouter instance.
--- @return number The available width for the current line.
function BlockLayouter:AvailableWidth()
	return Max(0, self.max_width - self.pos_x)
end

---
--- Prints an error message with the prefix "DrawCache err".
---
--- @param ... any Arguments to be printed along with the error message.
function BlockLayouter:PrintErr(...)
	print("DrawCache err", ...)
end

---
--- Sets the vertical space for the current line.
---
--- This function updates the `line_height` property of the `BlockLayouter` instance to the maximum of the current `line_height` and the provided `space` value. This ensures the line height is set to the tallest item on the current line.
---
--- @param self BlockLayouter The block layouter instance.
--- @param space number The vertical space to set for the current line.
function BlockLayouter:SetVSpace(space)
	self.line_height = Max(self.line_height, space)
end

-- this function considers requirements imposed by the text from adjacent blocks,
-- e.g. if the next block starts with a , it can't go onto the next line
local function CalcRequiredLeftoverSpace(blocks, idx)
	local pixels = 0
	while idx <= #blocks do
		local block = blocks[idx]
		if block.exec then
			break
		end
		
		local prev_block = blocks[idx - 1]
		if (prev_block and prev_block.end_line_forbidden) or block.new_line_forbidden then
			pixels = pixels + block.min_start_width
			if block.min_start_width < block.total_width then
				break
			end
		else
			break
		end

		idx = idx + 1
	end

	return pixels
end

---
--- Lays out the text of a block using word wrapping.
---
--- This function is called when the `word_wrap` property of the `BlockLayouter` instance is `true`. It iterates through the text of the block, finding the maximum amount of text that can fit on the current line, and drawing that text using the `DrawTextOnLine` function. If the text cannot fit on the current line, a new line is created using the `TryCreateNewLine` function.
---
--- @param self BlockLayouter The block layouter instance.
--- @param block table The block to lay out.
--- @param required_leftover_space number The amount of space that must be left over on the current line.
function BlockLayouter:LayoutWordWrappedText(block, required_leftover_space)
	assert(self.word_wrap)
	local line = block.text
	
	local byte_idx = 1
	local line_bytes = #line
	while byte_idx <= line_bytes do
		local has_just_word_wrapped = self.pos_x == self.left_margin and self.line_was_word_wrapped
		if has_just_word_wrapped then
			self.contains_wordwrapped_content = true
			if string.byte(line, byte_idx) == 32 then -- eat empty space at the beginning
				byte_idx = byte_idx + 1
				if byte_idx > line_bytes then
					break
				end
			end
		end
		
		local wrapped_text, advance_bytes =
			FindTextThatFitsIn(line, byte_idx, block.font, self:AvailableWidth(), required_leftover_space, self.max_width - self.left_margin)
		if #wrapped_text == 0 then
			if self.pos_x ~= self.left_margin then
				self:TryCreateNewLine()
			else -- this should only happen if even a single letter can't fit in the total width
				local next_pos = utf8.Advance(line, byte_idx, 1) - 1
				assert(UIL.MeasureText(line, block.font, byte_idx, next_pos) > self.max_width - self.left_margin)
				-- put the entire text on the current line
				wrapped_text = string.sub(line, byte_idx)
				advance_bytes = #wrapped_text
			end
		end
		
		self:DrawTextOnLine(block, wrapped_text)
		byte_idx = byte_idx + advance_bytes
	end
end

---
--- Draws text on the current line of the block layout.
---
--- This function is responsible for rendering the text content of a block on the current line. It takes the block object and an optional text parameter, and measures the width and height of the text to be drawn. If the text exceeds the available width, it is trimmed using the `UIL.TrimText` function and the `suppress_drawing_until` property is set to indicate that the next line should be used.
---
--- The function then calls the `DrawOnLine` function to actually render the text on the current line, passing in various properties from the block object such as the font, color, effect settings, alignment, and underline/highlight information.
---
--- @param self BlockLayouter The block layouter instance.
--- @param block table The block object containing the text to be drawn.
--- @param text string (optional) The text to be drawn. If not provided, the `text` property of the block object is used.
function BlockLayouter:DrawTextOnLine(block, text)
	text = text or block.text
	if text == "" then
		return
	end
	local text_width, text_height = UIL.MeasureText(text, block.font)
	if self.shorten and not self.word_wrap then
		local available = self:AvailableWidth()
		if text_width > available then
			text = UIL.TrimText(text, block.font, available, 0, self.shorten_string)
			text_width, text_height = UIL.MeasureText(text, block.font)
			self.suppress_drawing_until = "new_line"
			self.has_word_wrapped = true
		end
	end
	self:DrawOnLine({
		text = text,
		width = text_width,
		height = block.height,
		font = block.font,
		effect_color = block.effect_color or false,
		effect_type = block.effect_type or false,
		effect_size = block.effect_size or false,
		effect_dir = block.effect_dir or false,
		color = block.color,
		line_height = block.line_height,
		valign = block.valign,
		y_offset = block.y_offset,
		background_color = block.background_color,

		underline = block.underline,
		underline_color = block.underline_color,
		hl_function = block.hl_function,
		hl_argument = block.hl_argument,
		hl_underline = block.hl_underline,
		hl_hovercolor = block.hl_hovercolor or block.color,
		hl_internalid = block.hl_function and block.hl_internalid,
	})
end

---
--- Lays out a block of text, image, or horizontal line within the block layout.
---
--- This function is responsible for rendering a block of content within the block layout. It handles different types of blocks, including text, images, and horizontal lines.
---
--- For text blocks, it calls the `DrawTextOnLine` function to render the text on the current line. If the text exceeds the available width, it is trimmed and the `suppress_drawing_until` property is set to indicate that the next line should be used.
---
--- For image blocks, it creates an image element and draws it on the current line.
---
--- For horizontal line blocks, it draws a horizontal line on the current line.
---
--- If the block does not contain any of the above types, it simply reserves the space for the block without rendering anything.
---
--- @param self BlockLayouter The block layouter instance.
--- @param block table The block object to be laid out.
--- @param required_leftover_space number The required leftover space for the block.
function BlockLayouter:LayoutBlock(block, required_leftover_space)
	if rawget(block, "text") then
		if block.text == "" then
			return
		end

		if self.word_wrap then
			self:LayoutWordWrappedText(block, required_leftover_space)
		else
			self:DrawTextOnLine(block)
		end
	elseif rawget(block, "image") then
		-- create image
		self:DrawOnLine({
			image = block.image,
			base_color_map = block.base_color_map,
			width = block.total_width,
			height = block.total_height,
			line_height = block.total_height,
			image_size_org = box(0, 0, block.image_size_org_x, block.image_size_org_y),
			valign = "center",
			y_offset = block.y_offset,
			image_color = block.image_color,
		})
	elseif rawget(block, "horizontal_line") then
		self:DrawOnLine({
			width = block.total_width,
			height = block.total_height,
			line_height = block.total_height,
			horizontal_line = block.horizontal_line,
			thickness = block.thickness,
			space_above = block.space_above,
			space_below = block.space_below,
			margin = block.margin,
			valign = "center",
			y_offset = 0,
			color = block.color,
			scale = block.scale,
		})
	else
		-- just take the space without doing anyting
		self:DrawOnLine({
			width = block.total_width,
			height = block.total_height,
			line_height = block.total_height,
		})
	end
end

---
--- Attempts to create a new line in the text layout.
---
--- If word wrapping is enabled, this function will create a new line and return `true`.
--- Otherwise, it will return `false` to indicate that a new line was not created.
---
--- @return boolean Whether a new line was created.
function BlockLayouter:TryCreateNewLine()
	if self.word_wrap then
		self:NewLine(true)
		return true
	end
	return false
end

---
--- Attempts to shorten the text of a draw cache element to fit within the available space.
---
--- If the text of the element can be shortened to fit within the available space, this function will modify the `text` field of the element and return `true`.
--- Otherwise, it will return `false`.
---
--- @param elem table The draw cache element to shorten.
--- @param space_available number The maximum available space for the element.
--- @return boolean Whether the element was successfully shortened.
function BlockLayouter:ShortenDrawCacheElement(elem, space_available)
	if rawget(elem, "text") then
		local text = elem.text
		local byte_idx = #text + 1
		while byte_idx > 0 do
			local test_text = text:sub(1, byte_idx - 1) .. (self.shorten_string or "...")
			local x_reached = elem.x + UIL.MeasureText(test_text, elem.font)
			if x_reached <= space_available then
				elem.text = test_text
				return true
			end

			byte_idx = utf8.Retreat(text, byte_idx, 1)
		end
	end
	return false
end

--[===[
	This is an extremly simple shortening for the most common case. Finds the last completely visible line and tries adding "..." at the end.
	Removes the rest of the content after that. Should be OKish for paragraphs of text.
	Why this is not perfect:
	- You can't really measure "..." as those symbols vary based on previous letter. We have subpixel rendering (per word). So measure_width("...") != measure_width("lastword...") - measure_width("lastword")
	- We support images/icons. What happens when an icon happens to be at the end of the line? Remove the icon, potentially replace it with "...". If "..." can't fit we might need to merge it with the last words and remove a few letters from there as well.
	- If "..." happens to be after an icon, what font should be used?
	- We support "empty" lines of variable heights. See <vspace 80> tag. See also <tab> tag and right/center aligned text.
	- We don't know the height of the current line until it is *completely* done. All of the content should be processed before shortening can happen.
	And non-technical questions:
	- Is appending ... ok for all languages we support? After which letters is it OK to do that?
]===]

---
--- Checks if the provided draw cache contains multiple lines.
---
--- @param draw_cache table The draw cache to check.
--- @return boolean True if the draw cache contains multiple lines, false otherwise.
function BlockLayouter:IsDrawCacheMultiline(draw_cache)
	local line_counter = 0
	for _, val in pairs(draw_cache) do
		line_counter = line_counter + 1
		if line_counter >= 2 then
			return true
		end
	end
	return false
end

---
--- Shortens the draw cache by removing lines that don't fit within the maximum height.
--- If the draw cache contains multiple lines, this function will attempt to shorten the last line that fits within the maximum height by removing characters from the end of the line until it fits.
--- If the last line cannot be shortened enough to fit, the function will remove the remaining lines that don't fit.
---
--- @param self BlockLayouter The BlockLayouter instance.
--- @return nil
function BlockLayouter:ShortenDrawCache()
	local draw_cache = self.draw_cache

	if not self:IsDrawCacheMultiline(draw_cache) then
		return
	end

	local last_line_that_fit = 0
	local excess_lines = 0
	for y, data in sorted_pairs(draw_cache) do
		local max_y = y + data[1].line_height
		if max_y <= self.max_height then
			last_line_that_fit = y
		else
			excess_lines = excess_lines + 1
		end
	end

	if excess_lines == 0 then
		return
	end

	self.draw_cache_text_shortened = false
	local line = draw_cache[last_line_that_fit]
	for i = #line, 1, -1 do
		local item = line[i]
		if self:ShortenDrawCacheElement(item, self.max_width) then
			self.draw_cache_text_shortened = true
			break
		else
			line[i] = nil
		end
	end

	for _, y in ipairs(table.keys(draw_cache)) do
		if y > last_line_that_fit then
			draw_cache[y] = nil
		end
	end
end

---
--- Lays out the blocks of content (images, text, etc.) and generates a draw cache for rendering.
---
--- @param self BlockLayouter The BlockLayouter instance.
--- @return table The draw cache, the maximum width, and the final y-position.
function BlockLayouter:LayoutBlocks()
	local blocks = self.blocks
	assert(blocks)
	local draw_cache = {}
	self.draw_cache = draw_cache
	
	-- blocks are a list of visual content (images/texts + )
	local block_idx = 1
	local last_block_with_content = false
	while block_idx <= #blocks do
		local block = blocks[block_idx]
		-- layout stuff and write to draw_cache
		if block.exec then
			block.exec(self)
		elseif not self.suppress_drawing_until then
			-- do layouting
			local required_leftover_space = 0
			if self.word_wrap then
				local new_line_allowed = not last_block_with_content or (not last_block_with_content.end_line_forbidden and not block.new_line_forbidden)
				if new_line_allowed and block.min_start_width > self:AvailableWidth() then
					self:TryCreateNewLine()
				end
				-- calculate space required by next block(s), e.g. if their initial character can't begin a new line
				required_leftover_space = CalcRequiredLeftoverSpace(blocks, block_idx + 1)
			end
			self:LayoutBlock(block, required_leftover_space)
			last_block_with_content = block
		end

		block_idx = block_idx + 1
	end
	self:FinalizeLine()

	if self.shorten and self.word_wrap and self.max_height < BlockLayouter.max_height then
		self:ShortenDrawCache()
	end

	return draw_cache, self.measure_width, self.line_position_y + self.line_height
end


---
--- Draws a command on the current line of the block layout.
---
--- @param cmd table The command to draw, containing information such as width, line height, and whether it is an image, text, or horizontal line.
---
function BlockLayouter:DrawOnLine(cmd)
	assert(cmd.width > 0)
    -- Note that we DO not create a new line here. Let LayoutBlocks or the TextWordWrap to do it if they decide to.
	cmd.x = self.pos_x
	
	self.pos_x = self.pos_x + cmd.width
	self.line_height = Max(Max(self.line_height, cmd.line_height), cmd.total_height)
	self.last_font_height = self.line_height

	if cmd.image or cmd.text or cmd.horizontal_line then
		if not self.draw_cache then self.draw_cache = { } end
		if not self.draw_cache[self.line_position_y] then
			self.draw_cache[self.line_position_y] = { }
		end
		
		table.insert(self.draw_cache[self.line_position_y], cmd)
	end
end

---
--- Compiles the given text into a set of tokens that can be used to build a draw cache.
---
--- @param text string The text to be compiled.
--- @return boolean|nil Returns false if the text could not be compiled, or nil if the compilation was successful.
---
function XTextCompileText(text)
	local tokens = XTextTokenize(text)
	if #tokens == 0 then
		return false
	end

	local draw_state = BlockBuilder:new( {
		first_error = false,
		PrintErr = function(self, ...)
			if not self.first_error then
				local err = self:FormatErr(...)
				self.first_error = err
			end
		end
	})
	draw_state:ProcessTokens(tokens, text)
	return draw_state.first_error
end

---
--- Creates a draw cache for the given text and properties.
---
--- @param text string The text to create the draw cache for.
--- @param properties table A table of properties to use when creating the draw cache, including:
---   - `start_font_name` (string): The name of the starting font.
---   - `scale` (point): The scale to apply to the text.
---   - `default_image_scale` (number): The default scale to apply to images.
---   - `invert_colors` (boolean): Whether to invert the colors.
---   - `IsEnabled` (boolean): Whether the text is enabled.
---   - `EffectColor` (color): The color to use for effects.
---   - `DisabledEffectColor` (color): The color to use for effects when disabled.
---   - `effect_size` (number): The size of the effect.
---   - `effect_type` (string): The type of effect to use.
---   - `effect_dir` (string): The direction of the effect.
---   - `start_color` (color): The starting color.
---   - `max_width` (number): The maximum width of the text.
---   - `max_height` (number): The maximum height of the text.
---   - `word_wrap` (boolean): Whether to wrap the text.
---   - `shorten` (boolean): Whether to shorten the text.
---   - `shorten_string` (string): The string to use for shortening the text.
---   - `alignment` (string): The alignment of the text.
--- @return table, boolean, number, number, boolean The draw cache, whether the text contains word-wrapped content, the width, the height, and whether the text was shortened.
---
function XTextMakeDrawCache(text, properties)
	local tokens = XTextTokenize(text)
	if #tokens == 0 then
		return {}
	end
	local start_font_id, start_font_height = SetFont(properties.start_font_name, properties.scale)
	
	local draw_state = BlockBuilder:new( {
		IsEnabled = properties.IsEnabled,
		
		scale = properties.scale or point(1000, 1000),
		original_scale = properties.scale or point(1000, 1000),
		default_image_scale = properties.default_image_scale or 500,
		image_scale = MulDivTrunc(properties.scale, properties.default_image_scale, 1000),
		invert_colors = properties.invert_colors,
	})
	local top = draw_state.stackable_state[1]
	top.font_id = start_font_id or top.font_id
	top.font_name = properties.start_font_name or top.font_name
	top.color = false
	top.font_height = start_font_height or top.font_height
	top.effect_color = properties.IsEnabled and properties.EffectColor or properties.DisabledEffectColor
	top.effect_size = properties.effect_size
	top.effect_type = properties.effect_type
	top.effect_dir = properties.effect_dir
	top.start_color = properties.start_color
	top.background_color = 0

	draw_state:ProcessTokens(tokens, text)

	assert(draw_state.blocks)
	local block_layouter = BlockLayouter:new({
		blocks = draw_state.blocks,
		max_width = properties.max_width,
		max_height = properties.max_height,
		word_wrap = properties.word_wrap,
		shorten = properties.shorten,
		shorten_string = properties.shorten_string,
	})
	block_layouter:SetAlignment(properties.alignment or "left")

	local draw_cache, width, height = block_layouter:LayoutBlocks()
	return draw_cache or {}, block_layouter.contains_wordwrapped_content, Clamp(width, 0, properties.max_width), height, block_layouter.draw_cache_text_shortened
end

if Platform.developer then
local test_string = 
	[===[<underline> Underlined text. </underline>
<color 120 20 120>Color is 120 20 120</color>.
<color GedError>Color from TextStyle GedError</color>
Tags off: <tags off><color 255 0 0>Should not be red.</color><tags on>
<left>Left aligned text
<right>Right aligned text
<center>Center aligned text
<left>Left...<right>.. and right on the same line.
<left>Image: <image CommonAssets/UI/Ged/left>
Tab commands set the current "X" position to a certain value. Use carefully as elements may overlap. Tab is <tags off><left><tags on> with offset.
<tab 40>Tab to 40<tab 240>Tab to 240<newline>
Forced newline:<newline><tags off><newline><tags on> tag is always guaranteed to work(newlines might be trimmed by UI)
<style GedError>A new TextStyle by id GedError.</style>
<style GedDefault>GedDefault style in dark mode</style>
VSpace 80 following...<newline>
<vspace 80>...to here.
Word wrapping that works even when mixing with CJK languages. Note that the font might not have glyphs: 你知道我是谁吗？我可是玉皇大。
<effect glow 15 255 0 255>Shadows support...
<shadowcolor 0 255 0>With another color& legacy tag</shadowcolor>no stack, so default color</effect>
<scale 1800>Scaling support.<scale 1000>
<imagescale 3000><image CommonAssets/UI/HandCursor>
<hyperlink abc 255 0 0 underline>This is a hyperlink with ID abc and color 255 0 0</hyperlink>
The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog.
]===]

	function RunXTextParserTest(test)
		local game_question = StdMessageDialog:new({}, terminal.desktop, { question = true, title = "ABC", text = "" })
		game_question.MaxWidth = 10000
		game_question.idContainer.MaxWidth = 100000
		game_question.idContainer.Background = RGB(95, 83, 222)

		
		local effect_size = 2

		local text_ctrl = XText:new({
			MaxWidth = 412,
			MaxHeight = 800,
			
			ShadowSize = effect_size,
			WordWrap = true,
			Shorten = true,
		}, game_question.idContainer)
		text_ctrl:SetText(test_string)
		text_ctrl:SetOutsideScale(point(1000, 1000))
		game_question:Open()

		-- test core C methods
		local test_case = "AB C EF在茂。密"
		assert(#test_case == 19)
		assert(FindNextLineBreakCandidate(test_case, 1) == 3)
		assert(FindNextLineBreakCandidate(test_case, 3) == 5)
		assert(FindNextLineBreakCandidate(test_case, 5) == 8)
		assert(FindNextLineBreakCandidate(test_case, 8) == 11)
		assert(FindNextLineBreakCandidate(test_case, 11) == 17)
		assert(FindNextLineBreakCandidate(test_case, 17) == 20)
		assert(FindNextLineBreakCandidate(test_case, 20) == nil)
	end
end

local default_forbidden_sof = [[.-
!%), .:; ? ]}¢°·’†‡›℃∶、。〃〆〕〗〞﹚﹜！＂％＇），．：；？！］｝～
)]｝〕〉》」』】〙〗〟’｠»
ヽヾーァィゥェォッャュョヮヵヶぁぃぅぇぉっゃゅょゎゕゖㇰㇱㇲㇳㇴㇵㇶㇷㇸㇹㇺㇻㇼㇽㇾㇿ々〻
‐゠–〜
? !‼⁇⁈⁉
・、 : ; ,
。.
!%), .:; ? ]}¢°’†‡℃〆〈《「『〕！％），．：；？］]]

local default_forbidden_eol = [[
$(£¥·‘〈《「『【〔〖〝﹙﹛＄（．［｛￡￥
([｛〔〈《「『【〘〖〝‘｟«
$([\\{£¥‘々〇〉》」〔＄（［｛｠￥￦#
]]

DefineClass.BreakCandidateRange = {
	__parents = {"PropertyObject"},
	properties = {
		{id = "Begin", editor = "number", default = 0,},
		{id = "End", editor = "number", default = 0,},
		{id = "Comment", editor = "text", default = "", },
		{id = "Enabled", editor = "bool", default = true, }
	},
}

---
--- Called when a property of the `BreakCandidateRange` class is edited in the editor.
--- This function updates the global line break configuration based on the changes made to the `BreakCandidateRange` properties.
---
--- @param prop_id string The ID of the property that was changed.
--- @param old_value any The previous value of the property.
--- @param ged table The editor object that triggered the property change.
---
function BreakCandidateRange:OnEditorSetProperty(prop_id, old_value, ged)
	local parent = GetParentTableOfKind(self, "XTextParserVars")
	parent:Apply()
end

---
--- Returns a string representation of the `BreakCandidateRange` object for the editor.
---
--- @return string A string in the format `"<begin>-<end> <comment>"` representing the `BreakCandidateRange` object.
---
function BreakCandidateRange:GetEditorView()
	return string.format("%x-%x %s", self.Begin, self.End, self.Comment)
end

DefineClass.XTextParserVars = {
	__parents = {"PersistedRenderVars"},

	properties = {
		{text_style = "Console", id = "ForbiddenSOL", help = "Characters that should not start lines", lines = 5, max_lines = 25, word_wrap = true, editor = "text", default = default_forbidden_sof},
		{text_style = "Console", id = "ForbiddenEOL", help = "Characters that should not end lines", lines = 5, max_lines = 25, word_wrap = true, editor = "text", default = default_forbidden_eol},
		{id = "BreakCandidates", help = "UTF8 Ranges that allow breaking before them. Space character is always included even if not in the list.", editor = "nested_list", default = false, base_class = "BreakCandidateRange", inclusive = true, },
		
	}
}

---
--- Applies the line break configuration settings defined in the `XTextParserVars` class.
---
--- This function updates the global line break configuration based on the values of the `ForbiddenSOL`, `ForbiddenEOL`, and `BreakCandidates` properties of the `XTextParserVars` class.
---
--- The `ForbiddenSOL` and `ForbiddenEOL` properties define the characters that should not be allowed to start or end a line, respectively. The `BreakCandidates` property defines a list of UTF-8 character ranges that are allowed to be used as line break candidates.
---
--- This function is called whenever a property of the `XTextParserVars` class is edited in the editor, in order to update the global line break configuration.
---
--- @param self XTextParserVars The `XTextParserVars` object whose properties are being applied.
---
function XTextParserVars:Apply()
	const.LineBreak_ForbiddenSOL = string.gsub(self.ForbiddenSOL, " ", "")
	const.LineBreak_ForbiddenEOL = string.gsub(self.ForbiddenEOL, " ", "")
	local tbl = {}
	for idx, pair in ipairs(self.BreakCandidates or empty_table) do
		if pair.Enabled then
			tbl[#tbl+1] = pair.Begin
			tbl[#tbl+1] = pair.End
		end
	end
	utf8.SetLineBreakCandidates(tbl)
end