DefineClass.Console = {
	__parents = { "XWindow" },
	
	IdNode = true,
	ZOrder = 200000000,
	Dock = "box",
	
	history_queue = false,
	history_queue_idx = 0,
	
	completion_list = false,
	-- completion popup related
	completion_popup = false,
	completion_last_suggestion = false, -- used to autoselect a better item on popup refresh
	-- used by tab rotation
	completion_start_idx = false,
	completion_list_idx = 0,
}

---
--- Initializes the Console UI element.
---
--- @param self Console The Console instance.
--- @return void
function Console:Init()
	XEdit:new({
		Id = "idEdit",
		Dock = "bottom",
		TextStyle = "Console",
		MaxLen = 2048,
		OnTextChanged = function(edit)
			XEdit.OnTextChanged(edit)
			self:TextChanged()
		end,
		OnShortcut = function(edit, shortcut, source, ...)
			if shortcut == "Tab" then return "continue" end
			return XEdit.OnShortcut(edit, shortcut, source, ...)
		end
	}, self)
	self:UpdateMargins()
	self.history_queue = {}
end

---
--- Updates the margins of the console's edit control.
---
--- This function sets the margins of the console's edit control to provide
--- some padding around the text input, and to ensure the text input is
--- positioned above the virtual keyboard when it is displayed.
---
--- @param self Console The Console instance.
--- @return void
function Console:UpdateMargins()
	self.idEdit.Margins = box(10, 0, 10, VirtualKeyboardHeight() + 10)
end

---
--- Updates the auto-complete suggestions based on the current text in the console's edit control.
---
--- This function is called whenever the text in the console's edit control changes. It checks if the
--- auto-complete popup is currently displayed, and if so, updates the list of suggestions. If the
--- auto-complete popup is not displayed, it checks if the user has been rotating through the
--- suggestions, and if so, updates the state accordingly.
---
--- @param self Console The Console instance.
--- @return void
function Console:TextChanged()
	-- wait the text control to update its cursor pos.
	if self:IsThreadRunning("UpdateSuggestions") then
		return
	end
	self:CreateThread("UpdateSuggestions", function()
		if self.completion_popup then
				self:UpdateCompletionList()
				self:UpdateAutoCompleteDialog()
		elseif self.completion_list and self.completion_start_idx and self.completion_list_idx <= #self.completion_list then
			-- Detect rotations so we don't clear the completion state
			local text = self.idEdit:GetText()
			local completion_text = self.completion_list[self.completion_list_idx].value
			if not string.ends_with(text, completion_text) then
				self.completion_list = false
				self.completion_start_idx = false
				self.completion_list_idx = 0
			end
		else
			self.completion_list = false
			self.completion_start_idx = false
			self.completion_list_idx = 0
		end
	end)
end

---
--- Handles the behavior when the Console loses focus.
---
--- If the auto-complete popup is currently displayed, this function checks if the new focus is
--- not within the auto-complete popup. If so, it closes the auto-complete popup.
---
--- After handling the auto-complete popup, this function calls the base class's `OnKillFocus`
--- implementation.
---
--- @param self Console The Console instance.
--- @param new_focus XWindow The new focused window.
--- @return void
function Console:OnKillFocus(new_focus)
	if self.completion_popup then
		if not new_focus or not new_focus:IsWithin(self.completion_popup) then
			self:CloseAutoComplete()
		end
	end
	XWindow.OnKillFocus(self, new_focus)
end

---
--- Closes the auto-complete popup and deletes the Console instance.
---
--- @param self Console The Console instance.
--- @return void
function Console:delete()
	self:CloseAutoComplete()
	XWindow.delete(self)
end

---
--- Handles keyboard shortcuts for the Console.
---
--- This function is called when a keyboard shortcut is detected in the Console. It handles the
--- following shortcuts:
---
--- - Enter: If the auto-complete popup is visible, applies the active suggestion. Otherwise, executes the
---   current text in the Console and hides the Console.
--- - Down: If the auto-complete popup is not visible, navigates down the history.
--- - Up: If the auto-complete popup is not visible, navigates up the history.
--- - Tab: If the auto-complete popup is visible, applies the active suggestion. Otherwise, tries to
---   auto-complete the current text.
--- - Escape: If the auto-complete popup is visible, closes the auto-complete popup. Otherwise, hides the
---   Console.
---
--- For any other shortcuts, it routes them to the list control in the auto-complete popup, if it is visible.
---
--- @param self Console The Console instance.
--- @param shortcut string The name of the keyboard shortcut.
--- @param source string The source of the keyboard event.
--- @param ... any Additional arguments.
--- @return string "break" to indicate that the shortcut has been handled, or nil to let other handlers process it.
function Console:OnShortcut(shortcut, source, ...)
	if shortcut == "Enter" then
		if self.completion_popup then
			self:ApplyActiveSuggestion()
		else
			local text = self.idEdit:GetText()
			self.idEdit:SetText("")
			self:Show(false)
			if text == "" then
				ShowConsoleLogBackground(false, "immediate")
				return "break"
			end
			self:Exec(text)
		end
		return "break"
	elseif shortcut == "Down" then
		if not self.completion_popup then
			self:HistoryDown()
			return "break"
		end
	elseif shortcut == "Up" then
		if not self.completion_popup then
			self:HistoryUp()
			return "break"
		end
	elseif shortcut == "Tab" then
		if self.completion_popup then
			self:ApplyActiveSuggestion()
		else
			self:TryAutoComplete()
		end
		return "break"
	elseif shortcut == "Escape" then
		if self.completion_popup then
			self:CloseAutoComplete()
		else
			self:Show(false)
		end
		return "break"
	end
	
	-- Route unprocessed shortcuts to the list control
	if self.completion_popup then
		return self.completion_popup.idList:OnShortcut(shortcut, source, ...)
	end
end

--- Updates the completion list for the console's auto-complete functionality.
---
--- This function is responsible for generating the list of suggestions to display in the auto-complete popup when the user is typing in the console input field.
---
--- It first checks the current text in the input field and the cursor position, then generates a list of suggestions based on the user's input and the console's history.
---
--- The suggestions are stored in the `completion_list` table, which is then used to display the auto-complete popup.
---
--- @param self table The Console object.
function Console:UpdateCompletionList()
	self.completion_last_suggestion = self:ActiveSuggestion()
	
	local text = self.idEdit:GetText()
	local cursor_pos = self.completion_start_idx or self.idEdit:GetCursorCharIdx()
	local completion_list = {}
	for _, v in ipairs(self.history_queue) do
		if v:starts_with(text, "case insensitive") then
			completion_list[#completion_list + 1] = { name = v, value = v, kind = "h" }
		end
	end
	self.completion_list = GetAutoCompletionList(text, cursor_pos, completion_list)
		
end

--- Attempts to automatically complete the current text in the console input field.
---
--- This function is responsible for generating and applying the auto-complete suggestions when the user is typing in the console input field.
---
--- It first checks if there is any text in the input field. If the input field is empty, it generates a list of suggestions based on the console's history.
---
--- If there is text in the input field, it updates the completion list by calling the `UpdateCompletionList()` function. It then checks the size of the completion list and applies the active suggestion if the list is small enough (less than 6 items).
---
--- If the completion list is too large, it updates the auto-complete dialog to display the suggestions.
---
--- @param self table The Console object.
function Console:TryAutoComplete()
	local text = self.idEdit:GetText()
	if not self.history_queue then
			self:ReadHistory()
		end
	if text == "" then
		self.completion_list = table.map(self.history_queue, function(h)
			return { name = h, value = h, kind = "h" }
		end)
		self:UpdateAutoCompleteDialog()
		return
	end
		
	local list = self.completion_list
	if not list or #list == 0 then
		self:UpdateCompletionList()
	end
	list = self.completion_list
	
	if list and #list < 6 and #list > 0 then
		-- tab rotate
		if not self.completion_start_idx then
			self.completion_start_idx = self.idEdit:GetCursorCharIdx()
			local len
			for i, text in ipairs(list) do
				if not len or len > #text then
					len = #text
					self.completion_list_idx = i
				end
			end
		else		
			self.completion_list_idx = self.completion_list_idx + 1
			if self.completion_list_idx > #list then
				self.completion_list_idx = 1
			end
		end

		self:ApplyActiveSuggestion()
	else
		self:UpdateAutoCompleteDialog()
	end
end

---
--- Applies the active auto-completion suggestion to the input field.
---
--- If there is an active suggestion, it replaces the text in the input field with the completed text, adjusting the cursor position accordingly.
--- If the auto-completion popup is open, it is closed and the completion list is reset.
---
--- @param self table The Console object.
function Console:ApplyActiveSuggestion()
	local completed_text = self:ActiveSuggestion()
	if not completed_text then
		return
	end
	completed_text = completed_text.value

	local text = self.idEdit:GetText()

	local replace_end = self.idEdit:GetCursorCharIdx()
	local replace_start = self.completion_start_idx or self.idEdit:GetCursorCharIdx()

	local lower_text, lower_auto_complete = string.lower(text), string.lower(completed_text)
	local found = false
	for i = 1, replace_start do
		if string.find(lower_auto_complete, string.sub(lower_text, i, replace_start), nil, true) == 1 then
			replace_start = i
			found = true
			break
		end
	end
	local new_text
	if found then
		new_text = string.format("%s%s%s", string.sub(text, 1, replace_start - 1), completed_text, string.sub(text, replace_end + 1))
	else
		new_text = string.format("%s%s%s", string.sub(text, 1, replace_start), completed_text, string.sub(text, replace_end + 1))
	end
	
	self.idEdit:SetText(new_text)
	local new_cursor_pos = (found and replace_start - 1 or replace_start) + string.len(completed_text)
	self.idEdit:SetCursor(self.idEdit:CursorFromCharIdx(new_cursor_pos))
	if self.completion_popup then
		self:CloseAutoComplete()
		self.completion_list = false
	end
end

---
--- Returns the active auto-completion suggestion.
---
--- If the auto-completion popup is open, this function returns the currently selected suggestion from the popup list.
--- If the auto-completion popup is not open, but there is an active suggestion in the `completion_list`, this function returns that suggestion.
---
--- @param self table The Console object.
--- @return table|boolean The active auto-completion suggestion, or `false` if there is no active suggestion.
function Console:ActiveSuggestion()
	local popup = self.completion_popup
	local completion_list = self.completion_list
	local completion_list_idx = self.completion_list_idx
	if popup then
		local suggestion_idx = popup.idList.focused_item
		local completed_text = completion_list[suggestion_idx]
		return completed_text
	elseif completion_list and #completion_list > 0 and completion_list_idx > 0 and completion_list_idx <= #completion_list then
		return completion_list[completion_list_idx]
	end
	return false
end

---
--- Closes the auto-complete popup.
---
--- This function is responsible for closing the auto-complete popup when it is no longer needed. It checks if the `completion_popup` field is not `false`, and if so, it deletes the popup and sets the `completion_popup` field to `false`.
---
--- @param self table The Console object.
function Console:CloseAutoComplete()
	if self.completion_popup then
		self.completion_popup:delete()
		self.completion_popup = false
	end
end

---
--- Updates the auto-complete dialog for the console.
---
--- This function is responsible for creating and managing the auto-complete popup dialog that appears when the user is typing in the console. It checks if there are any auto-complete suggestions available, and if so, it creates a new popup with a list of the suggestions. The popup is positioned relative to the cursor position in the console's text input field.
---
--- @param self table The Console object.
function Console:UpdateAutoCompleteDialog()
	self:CloseAutoComplete()
	
	if not self.completion_list or #self.completion_list <= 0 then
		return
	end
	
	local popup = XPopup:new({
		IdNode = true,
		AutoFocus = false,
		ZOrder = self.ZOrder,
		BorderWidth = 1,
		BorderColor = RGB(16, 16, 16),
	}, self.desktop:GetModalWindow() or self.desktop)
	self.completion_popup = popup
	
	local list = XList:new({
		Id = "idList",
		VScroll = "idScroll",
		MaxHeight = 400,
		ForceInitialSelection = true,
		WorkUnfocused = true,
		BorderWidth = 0,
	}, popup)
	list.OnDoubleClick = function(container_list, item_idx)
		self:ApplyActiveSuggestion()
	end
	
	XSleekScroll:new({
		Id = "idScroll",
		Target = "idList",
		Dock = "right",
		Margins = box(1, 1, 1, 1),
		AutoHide = true,
	}, popup)
	
	for i, value in ipairs(self.completion_list) do
		list:CreateTextItem(Untranslated(string.format("<color 50 50 250>[%s]</color> %s", value.kind or "", value.name)), { Translate = true })
	end
	
	local x, _ = self.idEdit:GetCursorXY()
	local anchor_box = self.idEdit.box
	popup:SetAnchor(sizebox(x, anchor_box:miny(), anchor_box:sizex(), anchor_box:sizey()))
	popup:SetAnchorType("top")
	popup:Open()
	
	-- Select the best match based on last selection
	for i, value in ipairs(self.completion_list) do
		if value == self.completion_last_suggestion then
			list:SetSelection(i)
		end
	end
end

---
--- Adds a command to the console history queue, removing any previous copies of the command.
--- The history queue has a maximum size, so the oldest commands will be removed to make room for new ones.
--- The history queue index is also reset to the beginning.
---
--- @param txt string The command to add to the history queue.
---
function Console:AddHistory(txt)
	-- Remove previous copy of the string in the queue and push it in the front
	for k, v in ipairs(self.history_queue) do
		if v ==txt then
			table.remove(self.history_queue, k)
			break
		end
	end
	if #self.history_queue >= const.nConsoleHistoryMaxSize then
		table.remove(self.history_queue)
	end
	table.insert(self.history_queue, 1, txt)
	self.history_queue_idx = 0
	self:StoreHistory()
end

---
--- Moves the cursor to the previous command in the console history queue.
--- If the cursor is already at the beginning of the history queue, it will wrap around to the end.
---
--- @param self Console The Console instance.
---
function Console:HistoryDown()
	if self.history_queue_idx <= 1 then
		self.history_queue_idx = #self.history_queue
	else
		self.history_queue_idx = self.history_queue_idx - 1
	end
	self.idEdit:SetText(self.history_queue[self.history_queue_idx] or "")
end

---
--- Moves the cursor to the previous command in the console history queue.
--- If the cursor is already at the beginning of the history queue, it will wrap around to the end.
---
--- @param self Console The Console instance.
---
function Console:HistoryUp()
	if self.history_queue_idx + 1 <= #self.history_queue then
		self.history_queue_idx = self.history_queue_idx + 1
	else
		self.history_queue_idx = 1
	end

	self.idEdit:SetText(self.history_queue[self.history_queue_idx] or "")
end

---
--- Stores the console history queue in the local storage.
---
--- The history queue is stored in the `LocalStorage.history_log` table, where the first element (`LocalStorage.history_log[0]`) contains the number of entries in the queue. The rest of the elements (`LocalStorage.history_log[1]`, `LocalStorage.history_log[2]`, etc.) contain the actual history entries.
---
--- This function is called whenever the history queue is modified, to ensure the local storage is updated with the latest history.
---
--- @param self Console The Console instance.
function Console:StoreHistory()
	local i = 0
	LocalStorage.history_log = {}
	for j, k in ipairs(self.history_queue) do
		LocalStorage.history_log[j] = k
		i = i + 1
	end
	LocalStorage.history_log[0] = i + 1
	SaveLocalStorage()
end

---
--- Reads the console history queue from the local storage and populates the `history_queue` table.
---
--- The history queue is stored in the `LocalStorage.history_log` table, where the first element (`LocalStorage.history_log[0]`) contains the number of entries in the queue. The rest of the elements (`LocalStorage.history_log[1]`, `LocalStorage.history_log[2]`, etc.) contain the actual history entries.
---
--- This function is called to initialize the console history queue when the console is shown.
---
--- @param self Console The Console instance.
function Console:ReadHistory()
	local size = LocalStorage.history_log and LocalStorage.history_log[0] or 0
	self.history_queue = {}
	for i = 1, size do
		table.insert(self.history_queue, LocalStorage.history_log[i])
	end
	self.history_queue_idx = 0
end

---
--- A set of rules for the console to execute commands.
---
--- The rules are defined as a table of patterns and corresponding actions.
--- Each rule is defined as a Lua pattern and a format string that will be used to execute the command.
---
--- The following rules are defined:
---
--- - `^!$`: Clears the "ShowMe" window.
--- - `^!(.*)``: Shows the "ShowMe" window with the specified content.
--- - `^~(.*)``: Inspects the specified object.
--- - `^:\s*(.*)``: Calls the `rfnChatMsg` function with the specified message.
--- - `^*r\s*(.*)``: Creates a real-time thread and executes the specified code.
--- - `^*g\s*(.*)``: Creates a game-time thread and executes the specified code.
--- - `^(\a[\w.]*)``: Prints the result of executing the specified command.
--- - `(.*)``: Prints the specified value.
--- - `(.*)``: Executes the specified code.
--- - `^SSA?A?0\d+ (.*)``: Views the specified screenshot.
---
ConsoleRules = {
	{ "^!$", "ClearShowMe()" },
	{ "^!(.*)", "ShowMe('%s')" },
	{ "^~(.*)", "Inspect((%s))" },
	{ "^:%s*(.*)", "NetPrintCall('rfnChatMsg', '%s')" },
	{ "^*r%s*(.*)", "CreateRealTimeThread(function() %s end) return" },
	{ "^*g%s*(.*)", "CreateGameTimeThread(function() %s end) return" },
	{ "^(%a[%w.]*)$", "ConsolePrint(print_format(__run(%s)))" },
	{ "(.*)", "ConsolePrint(print_format(%s))" },
	{ "(.*)", "%s" },
	{ "^SSA?A?0%d+ (.*)", "ViewShot([[%s]])" },
}

---
--- Executes the specified console command text.
---
--- This function performs the following steps:
--- 1. Adds the command text to the console history queue.
--- 2. Logs the command text to the console log.
--- 3. Executes the command text using the `ConsoleExec` function and the `ConsoleRules` table.
--- 4. If there is an error executing the command, prints the error to the console log.
---
--- @param self Console The Console instance.
--- @param text string The console command text to execute.
function Console:Exec(text)
	self:AddHistory(text)
	AddConsoleLog("> ", true)
	AddConsoleLog(text, false)
	local err = ConsoleExec(text, ConsoleRules)
	if err then ConsolePrint(err) end
end

---
--- Executes the last command in the console history queue.
---
--- This function performs the following steps:
--- 1. Checks if the history queue is not empty.
--- 2. Executes the first command in the history queue using the `Console:Exec()` method.
---
--- @param self Console The Console instance.
function Console:ExecuteLast()
	if self.history_queue and #self.history_queue > 0 then
		self:Exec(self.history_queue[1])
	end
end

---
--- Shows or hides the console UI.
---
--- This function performs the following steps:
--- 1. Stores the current visibility state of the console.
--- 2. Sets the visibility of the console to the specified `show` parameter.
--- 3. Shows or hides the console log background.
--- 4. Sets the console to be modal or not based on the `show` parameter.
--- 5. If the console is being shown and was not previously visible:
---    - Sets the focus to the console's edit control.
---    - Clears the text in the console's edit control.
---    - Reads the console's history.
--- 6. If the console is being hidden:
---    - Closes the auto-complete feature.
---    - Unlocks the camera from the "Console" lock.
--- 7. If the console is being shown and the camera is in fly mode, locks the camera to the "Console" lock.
---
--- @param self Console The Console instance.
--- @param show boolean True to show the console, false to hide it.
function Console:Show(show)
	local was_visible = self:GetVisible()
	self:SetVisible(show)
	ShowConsoleLogBackground(show)
	
	self:SetModal(show)
	if show and not was_visible then
		self.idEdit:SetFocus()
		self.idEdit:SetText("")
		self:ReadHistory()
	end
	
	if not show then
		self:CloseAutoComplete()
		UnlockCamera("Console")
	elseif cameraFly.IsActive() then
		LockCamera("Console")
	end
end

function OnMsg.DesktopCreated()
	CreateConsole()
end

---
--- Destroys the console UI and removes it from the global namespace.
---
--- This function performs the following steps:
--- 1. Checks if the `dlgConsole` object exists in the global namespace.
--- 2. If `dlgConsole` exists, it is deleted and the reference is set to `false`.
--- 3. The `LuaConsole` engine variable is set to `false`.
--- 4. The console log is destroyed.
---
--- @function DestroyConsole
--- @return nil
function DestroyConsole()
	if rawget(_G, "dlgConsole") then
		dlgConsole:delete()
		dlgConsole = false
	end
	SetEngineVar("", "LuaConsole", false)
	DestroyConsoleLog()
end

---
--- Creates a new Console instance and sets it as the global `dlgConsole` object.
---
--- This function performs the following steps:
--- 1. Checks if the `dlgConsole` object already exists in the global namespace.
--- 2. If `dlgConsole` exists, it is deleted.
--- 3. A new `Console` instance is created and set as the global `dlgConsole` object.
--- 4. The `dlgConsole` object is hidden (set to `false`).
--- 5. The `LuaConsole` engine variable is set to `true`.
---
--- @function CreateConsole
--- @return nil
function CreateConsole()
	if rawget(_G, "dlgConsole") then
		dlgConsole:delete()
	end
	rawset(_G, "dlgConsole", Console:new({}, GetDevUIViewport()))
	dlgConsole:Show(false)
	SetEngineVar("", "LuaConsole", true)
end

if FirstLoad and rawget(_G, "ConsoleEnabled") == nil then
	ConsoleEnabled = false
end

---
--- Shows or hides the console UI.
---
--- This function performs the following steps:
--- 1. Checks if cheats are enabled, the console is enabled, or platform asserts are enabled. If not, the function returns.
--- 2. If the `visible` parameter is true and the `dlgConsole` object does not exist in the global namespace, it creates a new console instance using `CreateConsole()`.
--- 3. If the `visible` parameter is true and the platform is GED or asserts, it shows the console log using `ShowConsoleLog(true)`.
--- 4. If the `dlgConsole` object exists in the global namespace, it shows or hides the console UI based on the `visible` parameter.
---
--- @param visible boolean Whether to show or hide the console UI
--- @return nil
function ShowConsole(visible)
	if not (AreCheatsEnabled() or ConsoleEnabled or Platform.asserts) then
		return
	end
	
	if visible and not rawget(_G, "dlgConsole") then
		CreateConsole()
	end
	
	if visible and (Platform.ged or Platform.asserts) then
		ShowConsoleLog(true)
	end
	
	if rawget(_G, "dlgConsole") then
		dlgConsole:Show(visible)
	end
end

---
--- Resizes the console UI and updates the console log.
---
--- This function performs the following steps:
--- 1. If the `dlgConsole` object exists in the global namespace, it updates the console UI margins using `dlgConsole:UpdateMargins()`.
--- 2. It calls `ConsoleLogResize()` to resize the console log.
---
--- @function ConsoleResize
--- @return nil
function ConsoleResize()
	if rawget(_G, "dlgConsole") then
		dlgConsole:UpdateMargins()
	end
	ConsoleLogResize()
end

---
--- Executes the last command in the console.
---
--- This function checks if the `dlgConsole` object exists in the global namespace, and if so, calls the `ExecuteLast()` method on it to execute the last command in the console.
---
--- @function ConsoleExecuteLast
--- @return nil
function ConsoleExecuteLast()
	if rawget(_G, "dlgConsole") then
		dlgConsole:ExecuteLast()
	end
end

---
--- Enables or disables the console.
---
--- This function sets the `ConsoleEnabled` global variable to the provided `enabled` value. It also calls `ShowConsoleLog()` with the same `enabled` value to show or hide the console log.
---
--- @param enabled boolean Whether to enable or disable the console
--- @return nil
function ConsoleSetEnabled(enabled)
	enabled = enabled or false
	ConsoleEnabled = enabled
	ShowConsoleLog(enabled)
end

local signature_cache = { }
local function GetFunctionSignature(fn)
	if signature_cache[fn] then return signature_cache[fn] end
	if not fn or type(fn) ~= "function" then return end

	local info = debug.getinfo(fn)
	if info.what ~= "Lua" then return end
	
	local err, lua_file = AsyncFileToString(info.short_src)
	if err or not lua_file then return end
	
	local lines = string.split(lua_file, "\n")
	local line = lines[info.linedefined]
	if not line then return end
	
	local _, start_at = string.find(line, "function%s+")
	local end_at = string.find(line, ")", start_at)
	if not start_at or not end_at then return end
	
	local signature = line
	local open_braket_at = string.find(signature, "%(")
	
	local method_from = string.find(line, ":")
	local member_from = method_from or string.find(line, "%.")
	if member_from and member_from < open_braket_at then
		start_at = member_from
	end
	signature = string.sub(line, start_at + 1, end_at)
	open_braket_at = string.find(signature, "%(")
	
	local fn_name = string.sub(signature, 1, open_braket_at - 1)
	local params = string.sub(signature, open_braket_at + 1, -2)
	if method_from then
		--TODO params = (#params > 0) and ("self, " .. params) or "self"
	end
	local formatted_signature = fn_name .. "<color 150 150 150>(" .. params .. ")</color>"
	signature_cache[fn] = formatted_signature
	
	return formatted_signature
end

local function FormatValue(v)
	local vtype = type(v)
	if vtype == "string" then
		return string.format("\"%s\"", v)
	elseif vtype == "table" then
		if IsValid(v) then
			return string.format("obj:%s", v.class)
		else
			return string.format("table#%d", #v)
		end
	elseif IsPoint(v) and v == InvalidPos() then
		return "(invalid pos)"
	end
	
	return tostring(v)
end

_G.__enum = pairs
local env, blacklist
---
--- Generates an auto-completion list for the given input string and cursor position.
---
--- @param strEnteredSoFar string The input string entered so far.
--- @param nCursorPos number The current cursor position within the input string.
--- @param Result table An optional table to store the auto-completion results.
--- @return table The auto-completion results.
function GetAutoCompletionList(strEnteredSoFar, nCursorPos, Result)
	if not nCursorPos then
		nCursorPos = -1
	end
	local strEnteredToCursor = string.sub(strEnteredSoFar, 1, nCursorPos)
	local str1, str2
	local functions_only = false
	-- print("--")
	str1, str2 = string.match(strEnteredToCursor, "([%d%a_.%[%]]*)%[%s*\"([%d%a_]*)$")
	str2 = str2 or ""
	if not str1 then 
		-- print("CP1")
		str1, str2 = string.match(strEnteredToCursor, "([%d%a_%.%[%]]*)%s*%.%s*([%d%a_]*)$")
		str2 = str2 or ""
		if not str1 then
			str1, str2 = string.match(strEnteredToCursor, "([%d%a_%.%[%]]*)%s*%:%s*([%d%a_]*)$")
			if str1 then
				functions_only = true
			else
				-- print("CP2")
				str2 = string.match(strEnteredToCursor, "([%d%a_]*)$")
				str1 = ""
			end
		end
	end

	Result = Result or {}
	if str1 then
		-- print("str 1 -" .. str1 .. "; str2 -" .. str2)
		local TablesToAccess = {}
		local Gathered = {}
		local ResultCount = 0
		local original_env = _G
		
		blacklist = blacklist or Platform.asserts and empty_table or ModEnvBlacklist
		env = env or Platform.asserts and original_env or g_ConsoleFENV
		
		if str1 == "" then
			table.insert(TablesToAccess, {true, env})
			table.insert(TablesToAccess, {true, original_env})
		else
			table.insert(TablesToAccess, {pcall(load("return " .. str1, "", "t", env))})
			table.insert(TablesToAccess, {pcall(load("return _G." .. str1, "", "t", env))})
		end
		
		for _, v in ipairs(TablesToAccess) do
			local OK, TableToAccess = unpack_params(v)
			
			local meta = getmetatable(TableToAccess)
			if OK and functions_only and meta then
				table.insert(TablesToAccess, {true, meta})
			end

			if OK and type(TableToAccess) == "table" then
				for k,v in (meta and meta.__enum or pairs)(TableToAccess) do
					if not Gathered[k] and (TableToAccess ~= original_env or not blacklist[k]) then
						if type(k) == "string" and (not functions_only or type(v) == "function") then
							if string.starts_with(k, str2, true) then
								ResultCount = ResultCount + 1
								local signature = GetFunctionSignature(v)
								if signature then
									Result[#Result + 1] = { name = signature, value = k, kind = "f" }
								else
									if type(v) == "function" then
										Result[#Result + 1] = { name = string.format("%s<color 150 150 150>(...)</color>", k), value = k, kind = "f" }
									else
										Result[#Result + 1] = { name = string.format("%s<color 150 150 150> = %s</color>", k, FormatValue(v)), value = k, kind = "v" }
									end
								end
								
								Gathered[k] = true
								if ResultCount > 200 then break end
							end
						end
					end
				end
			end
			if ResultCount > 200 then break end
		end
	end
	table.sortby(Result, "value", CmpLower)
	return Result	
end

