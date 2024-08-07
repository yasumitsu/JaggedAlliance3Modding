--- Returns the viewport for the developer interface.
---
--- This function retrieves the viewport for the developer interface, which is either the `idViewport` node of the `XShortcutsTarget` object, or the `terminal.desktop` if the `XShortcutsTarget` object does not exist.
---
--- @return table The viewport for the developer interface.
function GetDevUIViewport()
	local ui = XShortcutsTarget
	return ui and rawget(ui, "idViewport") or terminal.desktop
end

DefineClass.DeveloperInterface = {
	__parents = { "XActionsHost" , "XDarkModeAwareDialog", "XDrawCache" },
	terminal_target_priority = -100,
	ZOrder = 10000000,
	IdNode = true,
	FocusOnOpen = false,
	
	ui_visible = true,
}

--- Initializes the DeveloperInterface class.
---
--- This function is called to initialize the DeveloperInterface class. It performs the following tasks:
--- - Adds the DeveloperInterface as a target to the terminal
--- - If the platform is in developer or editor mode (but not in the GED), it creates a developer menu
--- - Creates a viewport window for the DeveloperInterface
--- - Sets the parent of the dlgConsole and dlgConsoleLog windows to the viewport
--- - Creates a status box at the bottom of the viewport with a left-aligned and right-aligned text element
---
--- @param self The DeveloperInterface instance
function DeveloperInterface:Init()
	terminal.AddTarget(self)
	
	if (Platform.developer or Platform.editor) and not Platform.ged then
		self:CreateDevMenu()
	end
	
	XWindow:new({
		Id = "idViewport",
		Dock = "box",
	}, self)
	if rawget(_G, "dlgConsole") then
		dlgConsole:SetParent(self.idViewport)
	end
	if rawget(_G, "dlgConsoleLog") then
		dlgConsoleLog:SetParent(self.idViewport)
	end
	XDarkModeAwareDialog:new({ IdNode = false, Id = "idStatusBox", Dock = "box", Margins = box(3, 0, 5, 1), VAlign = "bottom", FocusOnOpen = "" }, self.idViewport)
	XText:new({
		Id = "idStatusTextLeft",
		VAlign = "bottom",
		TextHAlign = "left",
		TextStyle = "EditorTextBold",
		HandleMouse = false,
	}, self.idStatusBox)
	XText:new({
		Id = "idStatusTextRight",
		VAlign = "bottom",
		TextHAlign = "right",
		TextStyle = "EditorTextBold",
		HandleMouse = false,
	}, self.idStatusBox)
end

---
--- Creates a developer menu in the DeveloperInterface.
---
--- This function is called to create a developer menu in the DeveloperInterface. It performs the following tasks:
--- - Loads the ToolbarItems from LocalStorage, or creates a default set if it doesn't exist
--- - Creates a menu bar with the "DevMenu" menu entries
--- - Creates a top container with a search box and toolbar
--- - The search box allows searching and executing actions from the menu
--- - The toolbar contains buttons that can be added/removed from the toolbar
---
--- @param self The DeveloperInterface instance
function DeveloperInterface:CreateDevMenu()
	LocalStorage.ToolbarItems = LocalStorage.ToolbarItems or { ["DE_BugReport"] = true, ["DE_Screenshot"] = true }
	
	local bar = XMenuBar:new({
		Id = "idMenubar",
		Dock = "top",
		MenuEntries = "DevMenu",
		ShowIcons = true,
		IconReservedSpace = 25,
		TextStyle = "DevMenuBar",
		AutoHide = false,
	}, self)
	
	local top_container = XWindow:new({
		Dock = "top",
		BorderWidth = 1,
		BorderColor = RGB(160, 160, 160),
		Background = RGB(255, 255, 255),
		FoldWhenHidden = true,
	}, self)
	local menu_searchbox = XCombo:new({
		Id = "idMenubarSearchbox",
		Dock = "right",
		TextStyle = "DevMenuBar",
		MinWidth = 200,
		MaxLines = 5,
		PopupBackground = RGB(54, 54, 54),
		ArbitraryValue = false,
		ListItemTemplate = GetDarkModeSetting() and "XComboXTextListItemDark" or "XComboXTextListItemLight",
		Hint = "Search...",
		MRUStorageId = "MenuSearch",
		MRUCount = 10,
		VirtualItems = true,
		SetValueOnLoseFocus = false,
		
		Items = function() return self:SearchBoxEntries() end,
		GetText = function(combo) return RemoveDiacritics(XCombo.GetText(combo)) end,
		OnValueChanged = function(combo, value)
			local host = GetActionsHost(combo.idEdit)
			local action = host:ActionById(value)
			if action and action.ActionName then
				local action_name = action.ActionTranslate and _InternalTranslate(action.ActionName) or action.ActionName
				print(string.format("Executing: %s", action_name))
				host:OnAction(action, combo)
				if not IsEditorActive() then
					self:Toggle()
				end
			end
			combo:SetValueWithText(false, "", "dont_notify")
			combo:SetFocus(false, true)
		end,
		OnItemRightClicked = function(combo, value)
			local host = GetActionsHost(combo.idEdit)
			local action = host:ActionById(value)
			if action and action.ActionName then
				DeveloperInterface.AddRemoveFromToolbar(action, self)
			end
		end,
		
		just_focused = false,
	}, top_container)
	menu_searchbox.idEdit.OnKbdKeyUp = function(self, virtual_key, ...)
		if virtual_key == const.vkTilde and not menu_searchbox.just_focused and not IsEditorActive() then
			XShortcutsTarget:Toggle()
		end
		menu_searchbox.just_focused = false
		return XEdit.OnKbdKeyUp(self, virtual_key, ...)
	end
	menu_searchbox.idEdit.ShouldProcessChar = function(self, char, ...)
		return char ~= "`" and XTextEditor.ShouldProcessChar(self, char, ...)
	end
	menu_searchbox.OnKbdKeyDown = function(self, vkey, ...)
		if vkey == const.vkEsc then
			self:SetText("")
			self:SetFocus(false, true)
			return "break"
		elseif vkey == const.vkEnter then
			local popup = self.popup
			local container = popup and popup.idContainer
			local first_entry = container and container[1]
			if first_entry and first_entry.class == "XVirtualContent" then
				first_entry = first_entry[1]
			end
			if first_entry and first_entry:HasMember("OnPress") then
				first_entry:OnPress()
				return "break"
			end
		end
	end
	menu_searchbox.GetCurrentComboItems = function(self, mode)
		local pattern = self:GetText()
		if pattern == "" then
			self.mru_list = false -- force reload most recently used items
			return XCombo.GetCurrentComboItems(self, mode)
		end
		
		local item_scores = { }
		for i, item in ipairs(self:ResolveItems()) do
			local text = item.search_text
			local match, fuzzy_score, match_indices = string.fuzzy_match(pattern, text)
			if (match or fuzzy_score) and match_indices and next(match_indices) then
				local exact_score = string.find_lower(text, pattern) and 1 or 0
				table.sort(match_indices)
				table.insert(item_scores, {
					text = text,
					item = item,
					fuzzy_score = fuzzy_score,
					exact_score = exact_score,
					match_indices = match_indices,
				})
			end
		end
		
		table.sort(item_scores, function(a, b)
			if a.exact_score == b.exact_score then
				if a.fuzzy_score == b.fuzzy_score then
					return a.text < b.text
				end
				return a.fuzzy_score > b.fuzzy_score
			end
			return a.exact_score > b.exact_score
		end)
		
		for i = #item_scores, 30, -1 do
			if item_scores[i].exact_score ~= 0 then
				break
			end
			item_scores[i] = nil
		end
		
		local items = table.map(item_scores, function(item_score)
			local text = item_score.text
			text = HighlightFuzzyMatches(text, item_score.match_indices, "<color 32 196 32>", "</color>")
			return {
				name = text .. (item_score.item.extra_text or ""),
				value = item_score.item.value,
			}
		end)
		
		local selected_item
		if mode == "select" then
			selected_item = items[1]
		end
		
		return items, empty_table, selected_item
	end
	XToolBar:new({
		Dock = "left",
		Padding = box(1, 1, 1, 1),
		Toolbar = "DevToolbar",
		Show = "icon",
		ButtonTemplate = "EditorToolbarButton",
		ToggleButtonTemplate = "EditorToolbarToggleButton",
		RolloverAnchor = "bottom",
	}, top_container)
	local text = XText:new({
		Dock = "right",
		VAlign = "center",
		TextStyle = "EditorToolbar",
		Padding = box(0, 0, 25, 0),
	}, top_container)
	text:SetText("Right-click an item/submenu to add/remove it here...")
end

---
--- Focuses the menu search input box if the `XEditorSettings:GetAutoFocusMenuSearch()` setting is enabled.
---
--- This function is likely called when the developer interface is shown or when the user interacts with the menu search functionality.
---
--- @function DeveloperInterface:FocusSearch
--- @return nil
function DeveloperInterface:FocusSearch()
	if XEditorSettings:GetAutoFocusMenuSearch() then
		self.idMenubarSearchbox:SetFocus(true, false)
	end
end

---
--- Handles keyboard shortcuts for the Developer Interface.
---
--- If the "~" shortcut is pressed repeatedly while cheats are enabled, the Developer Interface is shown and the menu search input box is focused.
---
--- Otherwise, the default `XDialog.OnShortcut` implementation is called.
---
--- @param shortcut string The keyboard shortcut that was activated.
--- @param source string The source of the shortcut (e.g. "keyboard").
--- @param controller_id string The ID of the controller that triggered the shortcut.
--- @param repeated boolean Whether the shortcut was repeated.
--- @param ... any Additional arguments passed to the shortcut handler.
--- @return string|nil "break" if the shortcut was handled, nil otherwise.
function DeveloperInterface:OnShortcut(shortcut, source, controller_id, repeated, ...)
	if AreCheatsEnabled() and shortcut == "~" and source == "keyboard" and repeated then
		self:SetUIVisible(true)
		self.idMenubarSearchbox.just_focused = true
		self.idMenubarSearchbox:SetFocus(true, false)
		return "break"
	end
	return XDialog.OnShortcut(self, shortcut, source, controller_id, repeated, ...)
end

function OnMsg.XActionActivated(host, action, source)
	if host == XShortcutsTarget and source ~= "keyboard" then
		local name = action.ActionName
		local shortcut = action.ActionShortcut
		if action.ActionName ~= "" and action.OnActionEffect ~= "popup" then
			LocalStorage.XComboMRU = LocalStorage.XComboMRU or {}
			LocalStorage.XComboMRU.MenuSearch = LocalStorage.XComboMRU.MenuSearch or {}
			
			local id = action.ActionId
			local list = LocalStorage.XComboMRU.MenuSearch
			table.remove_value(list, id)
			table.insert(list, 1, id)
			if host.idMenubarSearchbox and #list > host.idMenubarSearchbox.MRUCount then
				table.remove(list)
			end
			SaveLocalStorageDelayed()
		end
	end
end

---
--- Gets the name of an action.
---
--- If the action has a translation defined, the translated name is returned. Otherwise, the original name is returned with any HTML tags stripped.
---
--- @param action table The action to get the name for.
--- @return string The name of the action.
function get_action_name(action)
	local name = action.ActionName
	if action.ActionTranslate then
		name = _InternalTranslate(name, nil, false)
	end
	return name:strip_tags()
end

---
--- Generates a list of search entries for the Developer Interface menu bar.
---
--- The search entries are generated from the actions registered with the Developer Interface.
--- Each entry includes the action name, any associated shortcut, and the path to the action in the menu hierarchy.
---
--- @return table A list of search entries, where each entry is a table with the following fields:
---   - search_text: The text to use for searching
---   - extra_text: Additional text to display alongside the search text
---   - text: The full text to display in the search results
---   - value: The action ID
---
function DeveloperInterface:SearchBoxEntries()
	local actions_by_id = {}
	for _, action in ipairs(self:GetActions()) do
		if action.ActionId ~= "" then
			actions_by_id[action.ActionId] = action
		end
	end
	
	local menubar = self:ResolveId("idMenubar")
	local menu_entries = menubar.MenuEntries
	
	local result = {}
	for _, action in ipairs(self:GetActions()) do
		if self:FilterAction(action) and action.ActionName ~= "" and action.OnActionEffect ~= "popup" then
			-- find path to root menu
			local parent, path = action, {}
			while parent and parent.ActionMenubar ~= menu_entries do
				parent = actions_by_id[parent.ActionMenubar]
				if parent then
					table.insert(path, get_action_name(parent))
				end
			end
			
			if parent then
				local name = get_action_name(action)
				if not string.find(name, "unused") then
					local shortcut = ""
					if action.ActionShortcut and action.ActionShortcut ~= "" then
						shortcut = string.format(" <alpha 156>(%s)<alpha 255>", action.ActionShortcut)
					end
					
					local path = table.concat(table.reverse(path), " / ")
					path = path:gsub("%.%.%.", ""):trim_spaces()
					
					local extra_text = string.format("%s<right><alpha 156>\t%s", shortcut, path)
					table.insert(result, { search_text = name, extra_text = extra_text, text = name .. extra_text, value = action.ActionId })
				end
			end
		end
	end
	table.sortby_field(result, "search_text")
	return result
end

--- Adds or removes an action from the toolbar.
---
--- This function is called when an action's "OnAltAction" event is triggered. It checks if the action is currently in the toolbar, and if so, prompts the user to confirm removing it. If the action is not in the toolbar, it prompts the user to confirm adding it.
---
--- After the user's confirmation, the function updates the toolbar items in the local storage and calls `DeveloperInterface:UpdateToolbar()` to reflect the changes.
---
--- @param action table The action to be added or removed from the toolbar.
--- @param self table The DeveloperInterface instance.
function DeveloperInterface.AddRemoveFromToolbar(action, self)
	CreateRealTimeThread(function()
		local toolbar_items = LocalStorage.ToolbarItems or empty_table
		if toolbar_items[action.ActionId] then
			if WaitQuestion(self, Untranslated("Confirm Action"), Untranslated("Remove this action from the toolbar?")) == "ok" then
				LocalStorage.ToolbarItems[action.ActionId] = nil
				SaveLocalStorage()
				self:UpdateToolbar()
			end
		else
			if WaitQuestion(self, Untranslated("Confirm Action"), Untranslated("Add this action to the toolbar?")) == "ok" then
				LocalStorage.ToolbarItems[action.ActionId] = true
				SaveLocalStorage()
				self:UpdateToolbar()
			end
		end
	end)
end

---
--- Updates the toolbar in the Developer Interface.
---
--- This function is responsible for setting up the toolbar actions in the Developer Interface. It iterates through all the actions and sets the appropriate properties for each action, such as the action toolbar, icon, and sort key.
---
--- The function first retrieves the toolbar items from the local storage. It then loops through all the actions and checks if the action's `ActionMenubar` property is not empty and if the `ActionToolbar` property is either empty or set to "DevToolbar". For each matching action, it sets the `OnAltAction` property to `DeveloperInterface.AddRemoveFromToolbar`, sets the `ActionToolbar` property based on whether the action is in the toolbar items, sets the `ActionIcon` property to a default icon if it's empty, and sets the `ActionSortKey` property based on the action's name.
---
--- After updating the actions, the function calls `self:ActionsUpdated()` to notify the interface that the actions have been updated, and `self:SetDarkMode(GetDarkModeSetting())` to set the dark mode setting.
---
--- @param self table The DeveloperInterface instance.
function DeveloperInterface:UpdateToolbar()
	local toolbar_items = LocalStorage.ToolbarItems or empty_table
	for _, action in ipairs(self:GetActions()) do
		if action.ActionMenubar ~= "" and (action.ActionToolbar == "" or action.ActionToolbar == "DevToolbar") then
			action.OnAltAction = DeveloperInterface.AddRemoveFromToolbar
			action:SetActionToolbar(toolbar_items[action.ActionId] and "DevToolbar")
			action.ActionIcon = action.ActionIcon ~= "" and action.ActionIcon or "CommonAssets/UI/Icons/circle close cross delete remove.tga"
			if action.ActionSortKey == "" then
				local sort_key = action.ActionTranslate and _InternalTranslate(action.ActionName) or action.ActionName
				action:SetActionSortKey((action.ActionIcon == "CommonAssets/UI/Menu/folder.tga" and " " or "") .. sort_key)
			end
		end
	end
	self:ActionsUpdated()
	self:SetDarkMode(GetDarkModeSetting())
end

---
--- Handles mouse events for the DeveloperInterface.
---
--- This function is called when a mouse event occurs on the DeveloperInterface. If the event is "OnMouseButtonDown", it closes any open popup menus. Otherwise, it forwards the event to the TerminalTarget.MouseEvent function.
---
--- @param self table The DeveloperInterface instance.
--- @param event string The type of mouse event that occurred.
--- @param ... any Additional arguments passed with the mouse event.
--- @return any The result of the TerminalTarget.MouseEvent function.
function DeveloperInterface:MouseEvent(event, ...)
	if event == "OnMouseButtonDown" then
		XPopupMenu.ClosePopupMenus()
	end
	return TerminalTarget.MouseEvent(self, event, ...)
end

---
--- Toggles the visibility of the DeveloperInterface UI.
---
--- This function is responsible for toggling the visibility of the DeveloperInterface UI. It sets the `ui_visible` property of the DeveloperInterface instance to the opposite of its current value, and then updates the visibility of all the windows in the DeveloperInterface, except for the `idViewport` window.
---
--- If the `idMenubarSearchbox` property is set, the function also handles the focus and text of the search box based on the new visibility state. If the UI is being made visible and the `XEditorSettings:GetAutoFocusMenuSearch()` setting is true, the function sets the focus on the search box. Otherwise, it clears the text of the search box and closes any open popup menus.
---
--- Finally, the function sends a "DevMenuVisible" message with the new visibility state.
---
--- @param self table The DeveloperInterface instance.
function DeveloperInterface:Toggle()
	self:SetUIVisible(not self.ui_visible)
end

---
--- Sets the visibility of the DeveloperInterface UI.
---
--- This function is responsible for toggling the visibility of the DeveloperInterface UI. It sets the `ui_visible` property of the DeveloperInterface instance to the opposite of its current value, and then updates the visibility of all the windows in the DeveloperInterface, except for the `idViewport` window.
---
--- If the `idMenubarSearchbox` property is set, the function also handles the focus and text of the search box based on the new visibility state. If the UI is being made visible and the `XEditorSettings:GetAutoFocusMenuSearch()` setting is true, the function sets the focus on the search box. Otherwise, it clears the text of the search box and closes any open popup menus.
---
--- Finally, the function sends a "DevMenuVisible" message with the new visibility state.
---
--- @param self table The DeveloperInterface instance.
--- @param visible boolean The new visibility state of the DeveloperInterface UI.
function DeveloperInterface:SetUIVisible(visible)
	if self.ui_visible == visible then return end

	self.ui_visible = visible
	for _, win in ipairs(self) do
		if win ~= self.idViewport then
			win:SetVisible(visible)
		end
	end
	
	if self.idMenubarSearchbox then
		if visible and XEditorSettings:GetAutoFocusMenuSearch() then
			self.idMenubarSearchbox:SetFocus(true, false)
		else
			self.idMenubarSearchbox:SetText("")
			XPopupMenu.ClosePopupMenus()
		end
		Msg("DevMenuVisible", visible)
	end
end

---
--- Sets the text of the left status bar.
---
--- This function sets the text of the left status bar in the DeveloperInterface. It updates the `idStatusTextLeft` property with the provided `text` parameter.
---
--- @param self table The DeveloperInterface instance.
--- @param text string The new text to display in the left status bar.
function DeveloperInterface:SetStatusTextLeft(text)
	self.idStatusTextLeft:SetText(text)
end

---
--- Sets the text of the right status bar.
---
--- This function sets the text of the right status bar in the DeveloperInterface. It updates the `idStatusTextRight` property with the provided `text` parameter.
---
--- @param self table The DeveloperInterface instance.
--- @param text string The new text to display in the right status bar.
function DeveloperInterface:SetStatusTextRight(text)
	self.idStatusTextRight:SetText(text)
end

---
--- Highlights fuzzy matches in a given string.
---
--- This function takes a string, a list of indices representing the start and end positions of fuzzy matches, and open and close tags to wrap around the highlighted matches. It constructs a new string where the fuzzy matches are highlighted using the provided tags.
---
--- @param str string The input string to highlight fuzzy matches in.
--- @param indices table A table of indices representing the start and end positions of fuzzy matches.
--- @param tag_open string The opening tag to wrap around the highlighted matches.
--- @param tag_close string The closing tag to wrap around the highlighted matches.
--- @return string The input string with fuzzy matches highlighted.
function HighlightFuzzyMatches(str, indices, tag_open, tag_close)
	local result_n = 1
	local result = { }
	
	local i, n = 1, #indices
	
	local last_idx = 1
	while i <= n do
		local from_i = i
		local from_idx = indices[i]
		while i < n and from_idx + (i - from_i) + 1 == indices[i + 1] do
			i = i + 1
		end
		local to_idx = indices[i]
		
		local before = string.sub(str, last_idx, from_idx - 1)
		local at = string.sub(str, from_idx, to_idx)
		last_idx = to_idx + 1
		
		result[result_n] = Literal(before)
		result[result_n+1] = tag_open
		result[result_n+2] = Literal(at)
		result[result_n+3] = tag_close
		result_n = result_n + 4
		i = i + 1
	end
	
	if last_idx <= #str then
		result[result_n] = Literal(string.sub(str, last_idx))
		result_n = result_n + 1
	end
	
	return table.concat(result)
end

----- XDarkModeAwareDialog

local menubar = RGB(41, 41, 41)
local background = RGB(64, 64, 64)
local section_background = RGB(41, 41, 41)
local border = RGB(28, 28, 28)
local rollover = RGB(117, 117, 117)
local toggle = RGB(171, 171, 171)
local pressed = RGB(171, 171, 171)
local text = "XEditorToolbarDark"
local button_pressed_background = RGB(191, 191, 191)
local button_rollover = RGB(100, 100, 100)
local edit_box = RGB(54, 54, 54)
local edit_box_border = RGB(130, 130, 130)
local edit_box_focused = RGB(42, 41, 41)
local menu_entry_icons_background = RGB(96, 96, 96)

local l_background = RGB(255, 255, 255)
local l_section_background = RGB(228, 228, 228)
local l_border = RGB(160, 160, 160)
local l_rollover = RGB(211, 208, 208)
local l_toggle = RGB(180, 180, 180)
local l_pressed = RGB(201, 197, 197)
local l_text = "XEditorToolbarLight"
local l_menubar = RGB(255, 255, 255)
local l_button_pressed_background = RGB(121, 189, 241)
local l_button_rollover = RGB(204, 232, 255)
local l_edit_box = RGB(240, 240, 240)
local l_edit_box_border = RGB(128, 128, 128)
local l_edit_box_focused = RGB(255, 255, 255)

local checkbox_color = RGB(128, 128, 128)
local checkbox_disabled_color = RGBA(128, 128, 128, 128)

DefineClass.XDarkModeAwareDialog = {
	__parents = { "XDialog" },
	Translate = false,
	
	dark_mode = false,
}

---
--- Opens the dialog and sets the dark mode based on the current setting.
---
--- @param self XDarkModeAwareDialog
--- @param ... any
--- @return nil
function XDarkModeAwareDialog:Open(...)
	XDialog.Open(self, ...)
	self:SetDarkMode(GetDarkModeSetting())
end

---
--- Updates the dark mode settings for an edit control.
---
--- @param control XEditControl The edit control to update.
--- @param dark_mode boolean Whether dark mode is enabled.
---
function XDarkModeAwareDialog:UpdateEditControlDarkMode(control, dark_mode)
	control:SetBackground(dark_mode and edit_box or l_edit_box)
	control:SetBorderColor(dark_mode and edit_box_border or l_edit_box_border)
	control:SetFocusedBorderColor(dark_mode and edit_box_border or l_edit_box_border)
	control:SetFocusedBackground(dark_mode and edit_box_focused or l_edit_box_focused)
end

---
--- Updates the dark mode settings for all child controls of the dialog.
---
--- @param self XDarkModeAwareDialog The dialog instance.
--- @param win table The child controls to update.
---
function XDarkModeAwareDialog:UpdateChildrenDarkMode(win)
	for _, child in ipairs(win) do
		if child:IsKindOf("XDarkModeAwareDialog") then
			child:SetDarkMode(self.dark_mode)
		elseif not child:IsKindOf("XDialog") and child ~= dlgConsoleLog then
			self:UpdateControlDarkMode(child)
			self:UpdateChildrenDarkMode(child)
		end
	end
end

TextStyle_ToLightMode = false
TextStyle_ToDarkMode = false

function OnMsg.DataLoaded()
	TextStyle_ToLightMode = false
	TextStyle_ToDarkMode = false
end

---
--- Retrieves the appropriate text style based on the current dark mode setting.
---
--- @param style string The text style to retrieve.
--- @param dark_mode boolean Whether dark mode is enabled.
--- @return string The appropriate text style for the given dark mode setting.
---
function GetTextStyleInMode(style, dark_mode)
	if not style then
		return
	end
	if not TextStyle_ToLightMode then
		TextStyle_ToLightMode = {}
		TextStyle_ToDarkMode = {}
		for style, preset in pairs(TextStyles or empty_table) do
			local dark_mode = preset.DarkMode or (TextStyles[style.."DarkMode"] and style.."DarkMode")
			if dark_mode then
				TextStyle_ToDarkMode[style] = dark_mode
				TextStyle_ToDarkMode[dark_mode] = dark_mode
				TextStyle_ToLightMode[dark_mode] = style
				TextStyle_ToLightMode[style] = style
			end
		end
	end
	if dark_mode then
		return TextStyle_ToDarkMode[style]
	else
		return TextStyle_ToLightMode[style]
	end
end

---
--- Updates the dark mode settings for a control and its children.
---
--- @param control table The control to update.
---
function XDarkModeAwareDialog:UpdateControlDarkMode(control)
	local not_set = RGBA(0, 0, 0, 0)
	local dark_mode = self.dark_mode
	local new_style = GetTextStyleInMode(rawget(control, "TextStyle"), dark_mode)
	
	if IsKindOf(control, "XTextButton") and control:GetColumnsUse() ~= "aaaaa" then
		return
	end
	
	if control.Id == "idSection" then
		control:SetBackground(dark_mode and section_background or l_section_background)
	elseif IsKindOf(control.parent, "XSleekScroll") then
		control:SetBackground(dark_mode and rollover or l_rollover)
	elseif control:GetBackground() ~= not_set and not IsKindOf(control, "XImage") and control.MinHeight ~= 1 then
		local is_combo = GetParentOfKind(control, "XCombo") or GetParentOfKind(control, "XCheckButtonCombo")
		control:SetBackground(dark_mode and background or is_combo and XComboButton.Background or l_background)
	end
	if control:GetBorderColor() ~= not_set then
		control:SetBorderColor(dark_mode and border or l_border)
	end
	if IsKindOf(control, "XCheckButton") then
		control:SetIconColor(dark_mode and checkbox_color or RGB(0, 0, 0))
		control:SetDisabledIconColor(dark_mode and checkbox_disabled_color or RGBA(0, 0, 0, 128))
	else
		if IsKindOf(control, "XComboButton") then
			if dark_mode then
				control:SetBackground(background)
				control:SetRolloverBackground(rollover)
				control:SetPressedBackground(pressed)
			else
				control:SetBackground(nil)
				control:SetRolloverBackground(nil)
				control:SetPressedBackground(nil)
			end
		elseif IsKindOf(control, "XButton") then
			if control:GetRolloverBackground() ~= not_set then
				control:SetRolloverBackground(dark_mode and rollover or l_rollover)
			end
			if control:GetPressedBackground() ~= not_set then
				control:SetPressedBackground(dark_mode and pressed or l_pressed)
			end
		end
		if IsKindOf(control, "XToggleButton") and control:GetToggledBackground() ~= not_set then
			control:SetToggledBackground(dark_mode and toggle or l_toggle)
		end
		if IsKindOf(control, "XMenuEntry") then
			control.idIcon:SetImageColor(dark_mode and RGB(230, 230, 230) or RGB(230, 230, 230))
			-- 0 => no background
			control.idIcon:SetBackground(dark_mode and menu_entry_icons_background or 0)
			control.idIcon:SetBorderColor(dark_mode and menu_entry_icons_background or 0)
			
			control:SetRolloverBackground(dark_mode and button_rollover or l_button_rollover)
			control:SetFocusedBackground(dark_mode and button_rollover or l_button_rollover)
			control:SetPressedBackground(dark_mode and button_pressed_background or l_button_pressed_background)
			control:SetToggledBackground(dark_mode and RGB(80, 80, 80) or RGB(224, 224, 224))
		end
		if IsKindOf(control, "XTextButton") and (control:GetIcon() or ""):starts_with("CommonAssets/UI/Editor/Tools/") then
			local image_name = control:GetIcon():match(".*/(.*)$")
			control:SetIcon((dark_mode and "CommonAssets/UI/Editor/Tools/" or "CommonAssets/UI/Editor/Tools/Light/") .. image_name)
		end
	end
	if IsKindOf(control, "XCombo") then
		self:UpdateEditControlDarkMode(control, dark_mode)
		self:UpdateControlDarkMode(control.idButton, dark_mode)
		if control:GetListItemTemplate() == "XComboListItemDark" or control:GetListItemTemplate() == "XComboListItemLight" then
			control:SetListItemTemplate(dark_mode and "XComboListItemDark" or "XComboListItemLight")
		end
		control.PopupBackground = dark_mode and background or l_background
	end	
	if IsKindOf(control, "XCheckButtonCombo") then
		self:UpdateEditControlDarkMode(control, dark_mode)
		self:UpdateControlDarkMode(control.idButton, dark_mode)
		control.PopupBackground = dark_mode and background or l_background
	end
	if IsKindOf(control, "XPopup") then
		control:SetFocusedBackground(dark_mode and background or l_background)
	end
	if IsKindOf(control, "XFontControl") and not IsKindOfClasses(control, "XCombo", "XCheckButtonCombo") then
		control:SetTextStyle(new_style or dark_mode and text or l_text)
	end
	if IsKindOf(control, "XTextEditor") then
		self:UpdateEditControlDarkMode(control, dark_mode)
		control:SetHintColor(dark_mode and RGBA(210, 210, 210, 128) or nil)
	end
end

function OnMsg.XWindowRecreated(win)
	if not win or win.window_state == "destroying" then return end

	local parent = win == RolloverWin and RolloverControl or win
	local popup = GetParentOfKind(parent, "XPopup")
	if popup then
		-- Popups can come from many places, make sure parent is XDarkModeAwareDialog
		while popup and IsKindOf(popup, "XPopup") do
			popup = popup.popup_parent
		end
		local dark_parent = IsKindOf(popup, "XDarkModeAwareDialog") and popup or GetParentOfKind(popup, "XDarkModeAwareDialog")
		if dark_parent then
			dark_parent:UpdateControlDarkMode(win)
			dark_parent:UpdateChildrenDarkMode(win)
			return
		end
	end
	parent = GetParentOfKind(parent, "XDarkModeAwareDialog")
	if parent then
		parent:UpdateControlDarkMode(win)
		parent:UpdateChildrenDarkMode(win)
	end
end

---
--- Sets the dark mode for the dialog and updates the dark mode for the dialog and its children.
---
--- @param mode boolean The dark mode to set.
---
function XDarkModeAwareDialog:SetDarkMode(mode)
	self.dark_mode = mode
	self:UpdateControlDarkMode(self)
	self:UpdateChildrenDarkMode(self)
end