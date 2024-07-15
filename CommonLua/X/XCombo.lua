if FirstLoad then
	OpenXCombo = false
end

DefineClass.XComboButton = {
	__parents = { "XTextButton" },
	Dock = "right",
	Padding = box(1, 3, 1, 1),
	Margins = box(2, 0, 0, 0),
	Icon = "CommonAssets/UI/arrowdown-40.tga",
	IconScale = point(500, 500),
	Background = RGB(38, 146, 227),
	RolloverBackground = RGB(24, 123, 197),
	PressedBackground = RGB(13, 113, 187),
	DisabledBackground = RGB(128, 128, 128),
}

-- The actual combo list items inherit XComboListItem and are defined as XTemplates
DefineClass.XComboListItem = {
	__parents = { "XTextButton" },
	Image = "CommonAssets/UI/round-frame-20.tga",
	FrameBox = box(9, 9, 9, 9),
	ImageScale = point(500, 500),
	Background = RGBA(0, 0, 0, 0),
	RolloverTemplate = "GedPropRollover",
	UseClipBox = false,
}

DefineClass.XCombo = {
	__parents = { "XFontControl", "XContextControl" },
	properties = {
		{ category = "General", id = "Translate", editor = "bool", default = false, },
		{ category = "General", id = "VirtualItems", editor = "bool", default = false, },
		{ category = "General", id = "Value", editor = "text", default = "", no_edit = true },
		{ category = "General", id = "DefaultValue", editor = "text", default = "" },
		{ category = "General", id = "Items", editor = "expression", default = false, params = "self" },
		{ category = "General", id = "RefreshItemsOnOpen", editor = "bool", default = false },
		{ category = "General", id = "MaxItems", editor = "number", default = 25, },
		{ category = "General", id = "ArbitraryValue", name = "Allow arbitrary value", editor = "bool", default = true, },
		{ category = "General", id = "AutoSelectAll", editor = "bool", default = true, },
		{ category = "General", id = "SetValueOnLoseFocus", editor = "bool", default = true, },
		{ category = "General", id = "ButtonTemplate", editor = "choice", default = "XComboButton", items = function() return XTemplateCombo("XTextButton") end, },
		{ category = "General", id = "ListItemTemplate", editor = "choice", default = "XComboListItemLight", items = function() return XTemplateCombo("XComboListItem") end, },
		{ category = "General", id = "Hint", editor = "text", default = "", },
		{ category = "Most Recently Used Items", id = "MRUStorageId", name = "Storage Id",    editor = "text",   default = "", },
		{ category = "Most Recently Used Items", id = "MRUCount",     name = "Entries count", editor = "number", default =  5, },
		{ category = "Interaction", id = "OnValueChanged", editor = "func", params = "self, value", default = empty_func },
		{ category = "Interaction", id = "OnItemRightClicked", editor = "func", params = "self, value", default = empty_func },
	},
	Padding = box(2, 1, 1, 1),
	BorderWidth = 1,
	BorderColor = RGB(128, 128, 128),
	DisabledBorderColor = RGBA(128, 128, 128, 128),
	Background = RGB(240, 240, 240),
	FocusedBackground = RGB(255, 255, 255),
	PopupBackground = RGB(255, 255, 255),
	value = false,
	
	popup = false,
	last_text = false,
	mru_list = false,
	mru_value_changed = false,
	suppress_autosuggest = false,
	-- operation to be performed after items are fetched
	pending_input = false,
	pending_input_type = false,
}

local function ItemId(item)
	if type(item) == "table" then
		return item.id or (item.value ~= nil and item.value)
	end
	return item
end

local function ItemText(item)
	if type(item) == "table" then
		return item.name or item.text or item.id
	end
	return tostring(item)
end

local function RawText(text, translate)
	if translate then
		assert(not text or IsT(text))
		return text and TDevModeGetEnglishText(text)
	end
	return text
end

local function StringText(text, translate)
	if translate then
		assert(not text or IsT(text))
		return text and _InternalTranslate(text)
	end
	return text
end

---
--- Initializes a new XCombo instance.
---
--- @param parent table The parent window of the XCombo instance.
--- @param context table The context in which the XCombo instance is created.
---
function XCombo:Init(parent, context)
	local edit = XEdit:new({
		Id = "idEdit", 
		VAlign = "center",
		Padding = box(0, 0, 0, 0),
		Background = RGBA(0, 0, 0, 0),
		BorderColor = RGBA(0, 0, 0, 0),
		BorderWidth = 0,
		AllowEscape = false,
		Hint = self.Hint,
		OnMouseButtonDown = function(edit, pt, button)
			if button == "L" and not self.popup then
				self:OpenCombo()
				if self.AutoSelectAll then return "break" end
			end
			return XEdit.OnMouseButtonDown(edit, pt, button)
		end,
		OnShortcut = function(edit, shortcut, source, ...)
			if shortcut == "Enter" then
				self:TextChanged(self:GetText())
				if self:IsPopupOpen() then
					self:CloseCombo()
					return "break"
				end
			end
			if shortcut == "ButtonA" then
				self:OpenCombo("select")
				return "break"
			end
			return XEdit.OnShortcut(edit, shortcut, source, ...)
		end,
		OnKillFocus = function(edit, new_focus)
			local popup = self.popup
			if not self.SetValueOnLoseFocus or popup and new_focus and new_focus:IsWithin(popup) then
				return XEdit.OnKillFocus(edit)
			end
			local text = self:GetText()
			if text ~= self.last_text then
				self.last_text = text
				self:TextChanged(text)
			end
			return XEdit.OnKillFocus(edit)
		end,
		OnTextChanged = function(edit)
			XEdit.OnTextChanged(edit)
			if self.suppress_autosuggest then
				self.suppress_autosuggest = false
				return
			end
			self:OpenCombo("suggest")
		end,
	}, self, context)
	edit:SetFontProps(self)
	edit:SetTranslate(self.Translate)
	self:SetButtonTemplate(self.ButtonTemplate)
end

--- Returns whether the combo box popup is currently open.
---
--- @return boolean
--- @public
function XCombo:IsPopupOpen()
	return self.popup and self.popup.window_state ~= "destroying"
end

--- Opens the XCombo window.
---
--- @param ... any additional arguments to pass to XContextWindow.Open
--- @return void
function XCombo:Open(...)
	if rawget(self, "value") == nil then
		self:SetValue(self.DefaultValue, true)
	end
	XContextWindow.Open(self, ...)
end

---
--- Sets the button template for the XCombo widget.
---
--- @param template_id string The ID of the button template to use.
--- @return void
---
function XCombo:SetButtonTemplate(template_id)
	if self:HasMember("idButton") then
		if self.idButton.window_state == "open" then
			self.idButton:Close()
		else
			self.idButton:delete()
		end
	end	
	self.ButtonTemplate = template_id
	local button = XTemplateSpawn(self.ButtonTemplate, self, self.context)
	button:SetId("idButton")
	button.OnPress = function(button)
		if self:IsPopupOpen() then
			self:CloseCombo()
		else
			self:OpenCombo("select")
		end
	end
end

LinkFontPropertiesToChild(XCombo, "idEdit")
LinkPropertyToChild(XCombo, "Translate", "idEdit")

--- Closes the XCombo popup window when the XCombo widget is deleted.
---
--- @return void
function XCombo:OnDelete()
	self:CloseCombo()
end

--- Resolves the items for the XCombo widget.
---
--- @return table The resolved items for the XCombo widget.
function XCombo:ResolveItems()
	local items = self.Items
	while type(items) == "function" do
		items = items(self)
	end
	return type(items) == "table" and items or empty_table
end

-- if value ~= text, SetValue needs to fetch the items. Use this function if you already know the text
-- This function is not validating the value!!!
---
--- Sets the value and text of the XCombo widget, optionally without notifying the value change.
---
--- @param value any The new value to set for the XCombo widget.
--- @param text string The new text to set for the XCombo widget.
--- @param dont_notify boolean (optional) If true, the OnValueChanged event will not be triggered.
--- @return void
---
function XCombo:SetValueWithText(value, text, dont_notify)
	self:SetText(text or "")
	local old_value = self:GetValue()
	if old_value ~= value then
		self.value = value
		if not dont_notify then
			self:OnValueChanged(self.value)
		end
	end
end

--- Sets the value of the XCombo widget, optionally without validating the value.
---
--- @param value any The new value to set for the XCombo widget.
--- @param do_not_validate boolean (optional) If true, the value will be set without validating it against the available items.
--- @return boolean True if the value was changed, false otherwise.
function XCombo:SetValue(value, do_not_validate)
	if not do_not_validate and not self.Items then
		self.pending_input = value
		self.pending_input_type = "value"
		self:FetchItemsAndValidate()
		return
	end
	
	for _, item in ipairs(self:ResolveItems()) do
		if ItemId(item) == value then
			self:SetText(ItemText(item))
			if self.value ~= ItemId(item) then
				self.value = ItemId(item)
				self:OnValueChanged(self.value)
			end
			return
		end
	end
	
	local old_value = self:GetValue()
	if self.ArbitraryValue or do_not_validate then
		self.value = value
		self:SetText(value == Undefined() and value or tostring(value))
	else
		self.value = nil
	end
	
	self:UpdateMRUList()
	
	if old_value ~= self:GetValue() then
		self:OnValueChanged(self:GetValue())
		return true
	end
end

--- Sets the text of the XCombo widget.
---
--- @param text any The new text to set for the XCombo widget. If `Undefined()`, the hint will be set to "Undefined" and the text will be an empty string.
function XCombo:SetText(text)
	self.suppress_autosuggest = true
	if text == Undefined() then
		self.idEdit:SetHint("Undefined")
		text = ""
	else
		self.idEdit:SetHint("")
	end
	self.idEdit:SetText(text)
	self.last_text = text
	self.idEdit.cursor_pos = #text
end

--- Handles the text change event for the XCombo widget.
---
--- This function is called when the text in the XCombo widget is changed. It checks if the new text matches any of the items in the XCombo's list, and updates the value accordingly. If the new text does not match any item and the ArbitraryValue flag is set, the value is updated to the new text. Otherwise, the value is reverted to the last valid value.
---
--- @param text any The new text entered in the XCombo widget.
function XCombo:TextChanged(text)
	local translate = self:GetTranslate()
	local raw_text = RawText(text, translate)
	
	if not self.Items then
		self.pending_input = raw_text
		self.pending_input_type = "text"
		self:FetchItemsAndValidate()
		return
	end
	
	for _, item in ipairs(self:ResolveItems()) do
		if RawText(ItemText(item), translate) == raw_text then
			if self.value ~= ItemId(item) then
				self.value = ItemId(item)
				self:OnValueChanged(self.value)
			end
			return
		end
	end
	
	if self.ArbitraryValue then
		if self.value ~= text then
			self.value = text
			self:OnValueChanged(self:GetValue())
		end
	else
		self:SetValue(self:GetValue()) -- revert to last valid value
	end
end

--- Returns the current value of the XCombo widget.
---
--- If the `value` field is `nil`, this function returns the `DefaultValue` of the XCombo widget instead.
---
--- @return any The current value of the XCombo widget.
function XCombo:GetValue()
	local value = rawget(self, "value")
	if value == nil then
		return self.DefaultValue
	else
		return value
	end
end

--- Returns the text currently displayed in the XCombo widget.
---
--- @return string The text currently displayed in the XCombo widget.
function XCombo:GetText()
	return self.idEdit:GetText()
end

--- Handles keyboard shortcuts for the XCombo widget.
---
--- This function is called when a keyboard shortcut is triggered while the XCombo widget has focus.
---
--- If the "Down" shortcut is triggered, it will open the combo box popup if it is not already open, or set focus to the popup if it is open.
---
--- If the "Escape" or "ButtonB" shortcut is triggered, it will close the combo box popup if it is open, or revert the text field to the current/old value if the popup is not open.
---
--- If any other shortcut is triggered while the popup is open, the shortcut is passed to the popup to handle.
---
--- @param shortcut string The name of the triggered keyboard shortcut.
--- @param source any The source of the keyboard event.
--- @param ... any Additional arguments passed with the keyboard event.
--- @return string|nil Returns "break" to indicate the shortcut has been handled, or nil to allow further processing.
function XCombo:OnShortcut(shortcut, source, ...)
	local popup = self.popup
	if shortcut == "Down" then
		if not popup then
			self:OpenCombo("select")
		else
			popup:SetFocus()
			popup:OnShortcut(shortcut, source, ...)
		end
		return "break"
	elseif shortcut == "Escape" or shortcut == "ButtonB" then
		if self:IsPopupOpen() then
			self:CloseCombo()
			return "break"
		else
			self:SetValue(self:GetValue(), "do_not_validate") -- revert text field to the current/old value
		end
	elseif popup and popup.window_state ~= "destroying" then
		local res = popup:OnShortcut(shortcut, source, ...)
		return res
	end
end

--- Sets the focus order of the XCombo widget.
---
--- This function sets the focus order of the internal edit control of the XCombo widget.
---
--- @param focus_order number The new focus order for the XCombo widget.
function XCombo:SetFocusOrder(focus_order)
	self.idEdit:SetFocusOrder(focus_order)
end

--- Gets the focus order of the XCombo widget.
---
--- This function retrieves the focus order of the internal edit control of the XCombo widget.
---
--- @param focus_order number The focus order to set for the XCombo widget.
function XCombo:GetFocusOrder(focus_order)
	self.idEdit:GetFocusOrder(focus_order)
end

--- Sets the focus of the XCombo widget.
---
--- This function sets the focus of the internal edit control of the XCombo widget.
---
--- @param set boolean Whether to set the focus or not.
--- @param children boolean Whether to set the focus on the children of the widget.
--- @return boolean Whether the focus was successfully set.
function XCombo:SetFocus(set, children)
	return self.idEdit:SetFocus(set, children)
end

--- Checks if the XCombo widget has focus.
---
--- This function checks if the internal edit control of the XCombo widget has focus.
---
--- @param include_children boolean Whether to include the focus state of the widget's children.
--- @return boolean Whether the XCombo widget has focus.
function XCombo:IsFocused(include_children)
	return self.idEdit:IsFocused(include_children)
end

--- Closes the combo box when the widget loses focus.
---
--- This function is called when the XCombo widget loses focus. It checks if the new focus is not within the popup window, and if so, it closes the combo box.
---
--- @param new_focus table The new focused widget.
function XCombo:OnKillFocus(new_focus)
	if not (new_focus and new_focus:IsWithin(self.popup)) then
		self:CloseCombo()
	end
end

--- Closes the combo box when it is open.
---
--- This function is called to close the combo box popup window if it is currently open. It clears the selection in the edit control and closes the popup window. If the `RefreshItemsOnOpen` flag is set, it also sets the `Items` property to `nil` to force a refresh of the items when the combo box is reopened.
---
--- @param self XCombo The XCombo instance.
function XCombo:CloseCombo()
	local popup = self.popup
	if popup and popup.window_state == "open" then
		self.idEdit:ClearSelection()
		popup:Close()
	end
	if self.RefreshItemsOnOpen then
		self.Items = nil
	end
end

--- Loads the Most Recently Used (MRU) list for the XCombo widget.
---
--- This function loads the MRU list for the XCombo widget from the local storage. It first checks if the MRUStorageId is set and if the mru_list is not already loaded. If the MRUStorageId is empty or the mru_list is already loaded, the function returns.
---
--- The function then retrieves the MRU data from the local storage and filters out any invalid items by checking if they exist in the list of resolved items. The filtered MRU data is then mapped to the actual items and stored in the mru_list property of the XCombo instance.
---
--- @param self XCombo The XCombo instance.
function XCombo:LoadMRUList()
	local mru_id = self.MRUStorageId
	if mru_id == "" or self.mru_list then
		return
	end
	self.mru_list = {}
	
	LocalStorage.XComboMRU = LocalStorage.XComboMRU or {}
	local mru_data = LocalStorage.XComboMRU[mru_id] or empty_table
	if next(mru_data) then
		-- gather all valid items by id to filter out the valid MRU entries
		local items_by_id = {}
		for i, item in ipairs(self:ResolveItems()) do
			items_by_id[ItemId(item)] = item
		end
		mru_data = table.ifilter(mru_data, function(idx, id) return items_by_id[id] end)
		self.mru_list = table.map(mru_data, function(id) return items_by_id[id] end)
	end
end

--- Updates the Most Recently Used (MRU) list for the XCombo widget.
---
--- This function updates the MRU list for the XCombo widget by adding the current value to the beginning of the list. If the list exceeds the `MRUCount` limit, the last item is removed. The updated MRU list is then stored in the local storage using the `MRUStorageId`.
---
--- @param self XCombo The XCombo instance.
function XCombo:UpdateMRUList()
	if not self.mru_list or not self.mru_value_changed then return end
	
	local item_id = self.value
	local list = table.map(self.mru_list, function(item) return ItemId(item) end)
	table.remove_value(list, item_id)
	table.insert(list, 1, item_id)
	if #list > self.MRUCount then
		table.remove(list)
	end
	
	LocalStorage.XComboMRU[self.MRUStorageId] = list
	SaveLocalStorageDelayed()
	self.mru_value_changed = nil
	self.mru_list = nil
end

--- Gets the current combo items for the XCombo widget.
---
--- This function retrieves the current items to be displayed in the combo box. It first resolves the items and filters them based on the provided mode. If the mode is "suggest", it only includes items that start with the current text prefix. If the mode is not "suggest", it includes all items.
---
--- If the prefix is empty or the mode is not "suggest", the function also loads the most recently used (MRU) items and places them at the top of the list.
---
--- @param self XCombo The XCombo instance.
--- @param mode string The mode to use for filtering the items ("suggest" or nil).
--- @return table items The filtered items to be displayed in the combo box.
--- @return table extra_items Additional items that match the prefix but are not the top matches.
--- @return boolean selected_item The item that is currently selected.
--- @return boolean recently_used Indicates whether the items include recently used items.
function XCombo:GetCurrentComboItems(mode)
	local recently_used
	local items, extra_items = {}, {}
	
	local selected_item = false
	local translate = self:GetTranslate()
	local prefix_lower = string.trim_spaces(string.lower(StringText(self:GetText(), translate)))
	for i, item in ipairs(self:ResolveItems()) do
		local itemText = ItemText(item)
		itemText = string.lower(StringText(itemText, translate))
		local match = itemText:starts_with(prefix_lower)
		if mode ~= "suggest" or match then
			items[#items + 1] = item
		elseif itemText:find(prefix_lower, 1, true) then
			extra_items[#extra_items + 1] = item
		end
		if match and not selected_item then
			selected_item = item
		end
	end
	
	-- if not searching, put most recently used entries on top
	if prefix_lower == "" or mode ~= "suggest" then
		self:LoadMRUList()
		if next(self.mru_list) then
			assert(#extra_items == 0)
			extra_items = items
			items = table.copy(self.mru_list)
			recently_used = true
		end
	end
	
	return items, extra_items, selected_item, recently_used
end

---
--- Opens the combo box and displays the current items.
---
--- This function is responsible for opening the combo box and displaying the current items. It first checks if the combo box is enabled, and if there is an existing open combo box, it closes it. If the combo box doesn't have any items, it fetches the items and validates them.
---
--- The function then retrieves the current combo items using the `GetCurrentComboItems` function, which filters the items based on the provided mode. If there are extra items that match the prefix but are not the top matches, they are appended to the end of the items list.
---
--- A new `XPopupList` is created to display the items. The popup is scaled to match the combo box, and the items are added to the popup. The function also handles setting the focus, scrolling to the selected item, and creating a separator between the recently used items and the other items.
---
--- Finally, the function opens the popup, sets the `OpenXCombo` variable, and returns the popup.
---
--- @param self XCombo The XCombo instance.
--- @param mode string The mode to use for filtering the items ("suggest" or nil).
--- @return XPopupList The opened popup list.
function XCombo:OpenCombo(mode)
	if not self.enabled then return end
	if OpenXCombo then
		OpenXCombo:CloseCombo()
		if not mode then return end
	end
	self:SetFocus()
	
	if not self.Items then
		self.pending_input = mode
		self.pending_input_type = "opencombo"
		self:FetchItemsAndValidate()
		return
	end
	
	local items, extra_items, selected_item, recently_used = self:GetCurrentComboItems(mode)
	local sep_idx
	if extra_items and #extra_items > 0 then
		sep_idx = #items
		table.iappend(items, extra_items)
	end
	if #items == 0 then
		return
	end
	
	-- open popup
	local popup = XPopupList:new({
		AutoFocus = false,
		DrawOnTop = true,
	}, self.desktop:GetModalWindow() or self.desktop)
	
	-- popup should have the same scale as the combo
	popup:SetScaleModifier(self.scale)
	popup:SetOutsideScale(point(1000, 1000))
	
	local translate = self:GetTranslate()
	local virtual_items = self.VirtualItems
	for i, item in ipairs(items) do
		local context = SubContext(self.context, {
			idx = i,
			dimmed = not recently_used and sep_idx and i > sep_idx,
			combo = self,
			popup = popup,
			item = item,
			translate = translate,
			on_press = function(self)
				local combo = self.context.combo
				local popup = self.context.popup
				if combo:GetEnabled() then
					local value = combo.value
					combo:SetValue(ItemId(self.context.item))
					if value ~= combo.value then
						combo.mru_value_changed = true -- means we will update MRU list upon deleting the control
					end
				end
				if popup.window_state ~= "destroying" then
					combo:CloseCombo()
				end
			end,
			on_alt_press = self.OnItemRightClicked ~= empty_func and function(self)
				local combo = self.context.combo
				combo:OnItemRightClicked(ItemId(self.context.item))
			end
		})
		
		local entry = virtual_items and
			NewXVirtualContent(popup.idContainer, context, self.ListItemTemplate) or
			XTemplateSpawn(self.ListItemTemplate, popup.idContainer, context)
		if not recently_used then
			if mode == "select" then
				if self.value == ItemId(item) then
					entry:SetFocus()
					popup.idContainer:ScrollIntoView(entry)
				end
			elseif selected_item == item then
				popup.idContainer:ScrollIntoView(entry)
			end
		end
		
		if i == sep_idx then
			XWindow:new({ Background = RGBA(0, 0, 0, 196), MinHeight = 1, Margins = box(3, 0, 3, 0) }, popup.idContainer)
		end
	end
	popup.idContainer:SetBackground(self.PopupBackground)
	popup:SetAnchor(self.box)
	popup:SetAnchorType("drop")
	popup:SetMaxItems(self.MaxItems)
	popup.Close = function(...)
		OpenXCombo = false
		self.popup = false
		XPopupList.Close(...)
	end
	popup:Open()
	
	popup.popup_parent = self
	Msg("XWindowRecreated", popup)
	
	if self.AutoSelectAll and not mode then
		self.idEdit:SelectAll()
	end
	OpenXCombo = self
	self.popup = popup
	return popup
end

---
--- Fetches and validates the items for the XCombo control.
--- This function is called internally by the XCombo control to populate the list of items.
--- It creates a new thread to fetch the items, and then processes any pending input or focus changes.
---
--- @return none
---
function XCombo:FetchItemsAndValidate()
	assert(not self.Items)
	if self:IsThreadRunning("FetchItems") then
		return
	end
	self:CreateThread("FetchItems", function()
		self.Items = self:OnRequestItems() -- might sleep
		if self.window_state == "destroying" then
			return
		end
		
		local focused = self:IsFocused()
		if self.pending_input_type == "value" then
			self:SetValue(self.pending_input)
			if self.RefreshItemsOnOpen then
				self.Items = nil
			end
		elseif self.pending_input_type == "text" and not focused then
			self:TextChanged(self.pending_input)
		elseif self.pending_input_type == "opencombo" and (focused or self.desktop.keyboard_focus == self) then
			self:OpenCombo(self.pending_input)
		else
			self:SetValue(self:GetValue()) -- revalidate current value
		end
		self.pending_input = false
		self.pending_input_type = false
	end)
end

---
--- Fetches the items for the XCombo control.
--- This function is called internally by the XCombo control to populate the list of items.
--- It returns an empty table, which means there are no items to display in the XCombo.
---
--- @return table An empty table
---
function XCombo:OnRequestItems()
	return {}
end
