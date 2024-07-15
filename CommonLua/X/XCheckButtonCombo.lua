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

DefineClass.XCheckButtonCombo = {
	__parents = { "XFontControl", "XContextControl" },
	properties = {
		{ category = "General", id = "Editable", editor = "bool", default = false, },
		{ category = "General", id = "Items", editor = "expression", default = false, params = "self" },
		{ category = "Interaction", id = "OnCheckButtonChanged", editor = "func", params = "self, id, value", default = empty_func },
		{ category = "Interaction", id = "OnTextChanged", editor = "func", params = "self, value", default = empty_func },
		{ category = "Interaction", id = "OnComboOpened", editor = "func", params = "self, popup", default = empty_func },
	},
	Padding = box(2, 1, 1, 1),
	BorderWidth = 1,
	BorderColor = RGB(128, 128, 128),
	DisabledBorderColor = RGBA(128, 128, 128, 128),
	Background = RGB(240, 240, 240),
	FocusedBackground = RGB(255, 255, 255),
	PopupBackground = RGB(255, 255, 255),
	
	last_text = false,
}

--- Initializes a new XCheckButtonCombo instance.
---
--- This function sets up the UI elements for the XCheckButtonCombo, including a button for opening the combo popup and an editable text field.
---
--- The button is created as an XTextButton with an arrow down icon, and is positioned on the right side of the control. The text field is created as an XEdit control, and is positioned in the center of the control. The text field has several event handlers attached to it:
--- - OnShortcut: Handles the Enter key press, which triggers the TextChanged event and closes the combo popup.
--- - OnSetFocus: Disables the text field when it receives focus.
--- - OnKillFocus: Enables the text field when it loses focus, triggers the TextChanged event, and closes the combo popup if the new focus is not within the combo popup.
---
--- The text field is also configured to automatically select all text when it receives focus.
function XCheckButtonCombo:Init()
	XTextButton:new({
		Id = "idButton",
		Dock = "right",
		Padding = box(2, 3, 2, 1),
		Margins = box(2, 0, 0, 0),
		Icon = "CommonAssets/UI/arrowdown-40.tga",
		IconScale = point(500, 500),
		Background = RGB(38, 146, 227),
		RolloverBackground = RGB(24, 123, 197),
		PressedBackground = RGB(13, 113, 187),
		DisabledBackground = RGB(128, 128, 128),
		OnPress = function(button) self:Toggle() end,
	}, self)
	local edit = XEdit:new({
		Id = "idEdit",
		Dock = "box",
		VAlign = "center",
		BorderWidth = 0,
		AutoSelectAll = true,
		OnShortcut = function(edit, shortcut, source, ...)
			if shortcut == "Enter" then
				self:TextChanged()
				self:CloseCombo()
				return "break"
			end
			return XEdit.OnShortcut(edit, shortcut, source, ...)
		end,
		OnSetFocus = function(edit, ...)
			edit:SetEnabled(false)
			XEdit.OnSetFocus(edit, ...)
		end,
		OnKillFocus = function(edit, new_focus)
			edit:SetEnabled(self.Editable)
			
			local popup = self.popup
			if popup and new_focus and new_focus:IsWithin(popup) then
				return XEdit.OnKillFocus(edit)
			end
			self:TextChanged()
			return XEdit.OnKillFocus(edit)
		end,
	}, self)
	edit:SetFontProps(self)
	edit:SetEnabled(self.Editable)
end

--- Sets whether the text field of the XCheckButtonCombo is editable.
---
--- @param value boolean Whether the text field should be editable.
function XCheckButtonCombo:SetEditable(value)
	self.idEdit:SetEnabled(value)
end

--- Sets the text of the XCheckButtonCombo's text field.
---
--- @param text string The new text to set.
function XCheckButtonCombo:SetText(text)
	self.idEdit:SetText(text)
end

--- Handles the text change event for the XCheckButtonCombo.
---
--- This function is called whenever the text in the XCheckButtonCombo's text field is changed. It updates the `last_text` field with the new text and then calls the `OnTextChanged` callback with the new text.
---
--- @param self XCheckButtonCombo The XCheckButtonCombo instance.
function XCheckButtonCombo:TextChanged()
	local text = self.idEdit:GetText()
	if text ~= self.last_text then
		self.last_text = text
		self:OnTextChanged(text)
	end
end

--- Resolves the items for the XCheckButtonCombo.
---
--- This function is used to get the list of items that will be displayed in the XCheckButtonCombo's popup. If the `Items` field is a function, it will be called to get the list of items. Otherwise, the `Items` field is returned as-is.
---
--- @param self XCheckButtonCombo The XCheckButtonCombo instance.
--- @return table The list of items to be displayed in the popup.
function XCheckButtonCombo:ResolveItems()
	local items = self.Items
	while type(items) == "function" do
		items = items(self)
	end
	return type(items) == "table" and items or empty_table
end

--- Closes the XCheckButtonCombo's popup.
---
--- This function is used to close the popup that is displayed when the XCheckButtonCombo is toggled. It checks if the popup exists on the desktop and, if so, closes it.
---
--- @param self XCheckButtonCombo The XCheckButtonCombo instance.
--- @return boolean True if the popup was closed, false otherwise.
function XCheckButtonCombo:CloseCombo()
	local popup = rawget(self.desktop, "idCheckButtonComboPopup")
	if popup then
		popup:Close()
		return true
	end
end

--- Toggles the XCheckButtonCombo's popup.
---
--- This function is used to open or close the popup that is displayed when the XCheckButtonCombo is toggled. It first closes any existing popup, then creates a new popup with a list of items that can be selected. The popup is positioned relative to the XCheckButtonCombo's box, and is set to be modal and have focus.
---
--- @param self XCheckButtonCombo The XCheckButtonCombo instance.
function XCheckButtonCombo:Toggle()
	self:CloseCombo()
	
	local popup = XPopupList:new({
		Id = "idCheckButtonComboPopup",
		LayoutMethod = "VList",
		DrawOnTop = true,
		OnMouseButtonUp = function(self, pt, button)
			if button == "L" then
				if not self:MouseInWindow(pt) then
					self:Close()
				end
				return "break"
			elseif button == "R" then
				self:Close()
				return "break"
			end
		end,
	}, self.desktop)
	
	for idx, item in ipairs(self:ResolveItems()) do
		local check = XCheckButton:new({
			OnChange = function(checkbox, value) self:OnCheckButtonChanged(checkbox.Id, value) end,
			
			-- three state support
			Icon = "CommonAssets/UI/check-threestate-40.tga",
			IconRows = 3,
			OnPress = function(self)
				local row = self.IconRow + 1
				if row > 2 then
					row = 1
				end
				self:SetIconRow(row)
				self:OnRowChange(row)
			end,
			OnRowChange = function(self, row)
				if row ~= 3 then
					XCheckButton.OnRowChange(self, row)
				end
			end,
		}, popup.idContainer)
		
		check:SetFontProps(self)
		check:SetId(ItemId(item))
		check:SetText(ItemText(item))
		check:SetEnabled(item.read_only ~= true)
		if item.value == Undefined() then
			check:SetIconRow(3)
		else
			check:SetCheck(item.value)
		end
	end
	
	self:OnComboOpened(popup)
	popup.idContainer:SetBackground(self.PopupBackground)
	popup:SetAnchor(self.box)
	popup:SetAnchorType("drop")
	popup:Open()
	popup:SetModal()
	popup:SetFocus()
	popup.popup_parent = self
	if Platform.ged then
		g_GedApp:UpdateChildrenDarkMode(popup)
	end
	Msg("XWindowRecreated", popup)
end
