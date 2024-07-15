DefineClass.ConsoleLog = {
	__parents = { "XWindow" },
	IdNode = true,
	Dock = "box",
	ZOrder = 2000000,
	background_thread = false,
}

---
--- Initializes the ConsoleLog window.
--- Creates a new XText object with the specified properties and sets its text style to "ConsoleLog".
--- Also calls the UpdateMargins() function to set the margins of the text object.
---
--- @param self ConsoleLog The ConsoleLog object being initialized.
---
function ConsoleLog:Init()
	local text = XText:new({
		Id = "idText",
		Dock = "bottom",
		Translate = false,
		TextVAlign = "bottom",
	}, self)
	text:SetTextStyle("ConsoleLog")
	self:UpdateMargins()
end

---
--- Updates the margins of the ConsoleLog window's text object.
--- Sets the margins of the text object to 10 pixels on the left and right, and 40 pixels plus the height of the virtual keyboard on the bottom.
---
--- @param self ConsoleLog The ConsoleLog object whose margins are being updated.
---
function ConsoleLog:UpdateMargins()
	self.idText.Margins = box(10, 0, 10, 40 + VirtualKeyboardHeight())
end

---
--- Sets the text of the ConsoleLog window's text object.
---
--- @param self ConsoleLog The ConsoleLog object whose text is being set.
--- @param text string The new text to be displayed in the ConsoleLog window.
---
function ConsoleLog:SetText(text)
	self.idText:SetText(text)
end

---
--- Clears the text displayed in the ConsoleLog window.
---
--- @param self ConsoleLog The ConsoleLog object whose text is being cleared.
---
function ConsoleLog:ClearText()
	self.idText:SetText("") 
end

---
--- Appends the given text to the console log, optionally adding a new line.
---
--- @param self ConsoleLog The ConsoleLog object whose text is being appended.
--- @param text string The text to be appended to the console log.
--- @param bNewLine boolean (optional) If true, the text will be added on a new line.
---
function ConsoleLog:AddLogText(text, bNewLine)
	local old_text = self.idText:GetText()
	local new_text
	if text and old_text ~= "" then
		new_text = old_text
	else
		new_text = ""
	end
	
	if bNewLine then
		new_text = new_text .. "\n<reset>" .. text
	else
		new_text = new_text .. text
	end
	
	if self.content_box:sizey() > 0 then
		local new_lines = {}
		local i = 1
		while true do
			local start_idx, end_idx = string.find (new_text, "\n", i , true)
			if not start_idx then
				break
			end
			i = end_idx+1
			table.insert(new_lines, i)
		end
		
		local self_height = self.content_box:sizey() - self.idText.Margins:maxy()
		local maxlines = (self_height / self.idText:GetFontHeight()) - 1
		if #new_lines > maxlines then
			new_text = string.sub(new_text, new_lines[#new_lines-maxlines])
		end
	end
	
	self:SetText(new_text)
end

--- @brief Checks if the mouse cursor is within the window of the ConsoleLog object.
---
--- This function always returns false, indicating that the mouse cursor is not within the window.
---
--- @param self ConsoleLog The ConsoleLog object to check.
--- @param pt table The position of the mouse cursor.
--- @return boolean Always returns false.
function ConsoleLog:MouseInWindow(pt)
	return false
end

--- Shows or hides the background of the ConsoleLog object.
---
--- If `visible` is true, the background is shown immediately with an alpha value of 96.
--- If `visible` is false, the background is hidden over a 3 second period, fading out gradually.
---
--- @param self ConsoleLog The ConsoleLog object.
--- @param visible boolean If true, the background is shown. If false, the background is hidden.
--- @param immediate boolean If true, the background change is immediate. If false, the background change is gradual.
--- @return none
function ConsoleLog:ShowBackground(visible, immediate)
	if config.ConsoleDim ~= 0 then
		DeleteThread(self.background_thread)
		if visible or immediate then
			self:SetBackground(RGBA(0, 0, 0, visible and 96 or 0))
		else
			self.background_thread = CreateRealTimeThread(function()
				Sleep(3000)
				local r, g, b, a = GetRGBA(self:GetBackground())
				while a > 0 do
					a = Max(0, a - 5)
					self:SetBackground(RGBA(0, 0, 0, a))
					Sleep(20)
				end
			end)
		end
	end
end

-- Global functions
dlgConsoleLog = rawget(_G, "dlgConsoleLog") or false
--- Shows or hides the ConsoleLog UI element.
---
--- If `visible` is true, the ConsoleLog is created and shown. If `visible` is false, the ConsoleLog is hidden.
---
--- @param visible boolean If true, the ConsoleLog is shown. If false, the ConsoleLog is hidden.
--- @return none
function ShowConsoleLog(visible)
	if visible and not dlgConsoleLog then
		dlgConsoleLog = ConsoleLog:new({}, GetDevUIViewport())
	end
	if dlgConsoleLog then
		dlgConsoleLog:SetVisible(visible)
	end
end

--- Destroys the ConsoleLog UI element.
---
--- If the ConsoleLog UI element exists, it is deleted and the dlgConsoleLog variable is set to false.
---
--- @return none
function DestroyConsoleLog()
	if dlgConsoleLog then
		dlgConsoleLog:delete()
		dlgConsoleLog = false
	end
end

--- Shows or hides the background of the ConsoleLog UI element.
---
--- If `visible` is true, the background is shown. If `visible` is false, the background is hidden.
---
--- If `immediate` is true, the background change is immediate. If `immediate` is false, the background change is gradual.
---
--- @param visible boolean If true, the background is shown. If false, the background is hidden.
--- @param immediate boolean If true, the background change is immediate. If false, the background change is gradual.
--- @return none
function ShowConsoleLogBackground(visible, immediate)
	if dlgConsoleLog then
		dlgConsoleLog:ShowBackground(visible, immediate)
	end
end

--- Updates the margins of the ConsoleLog UI element.
---
--- This function is called to update the margins of the ConsoleLog UI element when the window is resized.
---
--- @return none
function ConsoleLogResize()
	if dlgConsoleLog then
		dlgConsoleLog:UpdateMargins()
	end
end

--- Adds text to the console log.
--
-- If the console log is currently loading, the text is added to a real-time thread to be processed later.
-- Otherwise, the text is added to the console log immediately.
--
-- @param text string The text to add to the console log.
-- @param bNewLine boolean If true, a new line is added after the text.
-- @return none
function AddConsoleLog(text, bNewLine)
	if Loading then
		CreateRealTimeThread(function(text, bNewLine)
			AddConsoleLog(text, bNewLine)
		end, text, bNewLine)
		return
	end
	Msg("ConsoleLine", text, bNewLine)
	if dlgConsoleLog then
		dlgConsoleLog:AddLogText(text, bNewLine)
	end
end

--- Clears the console text log.
-- @cstyle void cls().
-- @return none.

function cls() -- Clear console log
	if dlgConsoleLog then 
		dlgConsoleLog:ClearText()
	end	
end