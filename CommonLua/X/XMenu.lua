DefineClass.XMenuEntry = {
	__parents = { "XButton", "XEmbedIcon", "XEmbedLabel" },
	properties = {
		{ category = "General", id = "IconReservedSpace", editor = "number", default = 0, },
		{ category = "General", id = "IconMaxHeight", editor = "number", default = 26, },
		{ category = "General", id = "Shortcut", editor = "shortcut", default = "", },
		{ category = "General", id = "Toggled", editor = "bool", default = false, },
		{ category = "General", id = "ToggledBackground", editor = "color", default = RGBA(40, 163, 255, 128), },
		{ category = "General", id = "ToggledBorderColor", editor = "color", default = RGBA(0, 0, 0, 0), },
	},
	LayoutMethod = "HList",
	VAlign = "center",
	HAlign = "stretch",
	Padding = box(2, 2, 2, 2),
	Background = RGBA(0, 0, 0, 0),
	RolloverBackground = RGBA(40, 163, 255, 128),
	PressedBackground = RGBA(40, 163, 255, 140),
	AltPress = true,
}

--- Initializes the XMenuEntry object.
---
--- This function sets the minimum width and maximum height of the icon associated with the XMenuEntry object.
--- It also sets the image fit mode of the icon to "scale-down".
---
--- @param parent table The parent object of the XMenuEntry.
--- @param context table The context object associated with the XMenuEntry.
function XMenuEntry:Init(parent, context)
	self.idIcon:SetMinWidth(self.IconReservedSpace)
	self.idIcon:SetMaxHeight(self.IconMaxHeight)
	self.idIcon:SetImageFit("scale-down")
end

LinkPropertyToChild(XMenuEntry, "IconReservedSpace", "idIcon", "MinWidth")
LinkPropertyToChild(XMenuEntry, "IconMaxHeight", "idIcon", "MaxHeight")
XMenuEntry.OnSetRollover = XButton.OnSetRollover

--- Sets the shortcut text for the XMenuEntry.
---
--- If the shortcut text is not empty, a new XLabel object is created and added to the right side of the XMenuEntry. The shortcut label is disabled and inherits the font properties of the XMenuEntry.
---
--- @param shortcut_text string The text to display as the shortcut.
function XMenuEntry:SetShortcut(shortcut_text)
	local shortcut = rawget(self, "idShortcut") or shortcut_text ~= "" and XLabel:new({
		Dock = "right",
		VAlign = "center",
		Margins = box(10, 0, 0, 0),
	}, self)
	if shortcut then
		shortcut:SetEnabled(false)
		shortcut:SetFontProps(self)
		shortcut:SetText(shortcut_text)
	end
end

--- Returns the shortcut text associated with the XMenuEntry.
---
--- If the XMenuEntry has a shortcut label, this function returns the text of that label. Otherwise, it returns an empty string.
---
--- @return string The shortcut text for the XMenuEntry.
function XMenuEntry:GetShortcut()
	local shortcut = rawget(self, "idShortcut")
	return shortcut and shortcut:GetText() or ""
end

--- Sets the toggled state of the XMenuEntry.
---
--- If the toggled state is changed, the XMenuEntry is invalidated to trigger a redraw.
---
--- @param toggled boolean The new toggled state of the XMenuEntry.
function XMenuEntry:SetToggled(toggled)
	toggled = toggled or false
	if self.Toggled ~= toggled then
		self.Toggled = toggled
		self:Invalidate()
	end
end

--- Calculates the background color of the XMenuEntry based on its state.
---
--- If the XMenuEntry is disabled, the DisabledBackground color is returned.
--- If the XMenuEntry is in a pressed state, the PressedBackground color is returned.
--- If the XMenuEntry is in a mouse-over state, the RolloverBackground color is returned.
--- Otherwise, the Toggled state is checked and the ToggledBackground or Background color is returned.
--- If the FocusedBackground is different from the calculated Background, the FocusedBackground is returned if the XMenuEntry is focused.
---
--- @return color The calculated background color for the XMenuEntry.
function XMenuEntry:CalcBackground()
	if not self.enabled then return self.DisabledBackground end
	if self.state == "pressed-in" or self.state == "pressed-out" then
		return self.PressedBackground
	end
	if self.state == "mouse-in" then
		return self.RolloverBackground
	end
	local FocusedBackground, Background = self.FocusedBackground, self.Toggled and self.ToggledBackground or self.Background
	if FocusedBackground == Background then return Background end
	return self:IsFocused() and FocusedBackground or Background
end

--- Calculates the border color of the XMenuEntry based on its state.
---
--- If the XMenuEntry is disabled, the DisabledBackground color is returned.
--- If the XMenuEntry is in a pressed state, the PressedBackground color is returned.
--- If the XMenuEntry is in a mouse-over state, the RolloverBackground color is returned.
--- Otherwise, the Toggled state is checked and the ToggledBorderColor or BorderColor is returned.
--- If the FocusedBorderColor is different from the calculated BorderColor, the FocusedBorderColor is returned if the XMenuEntry is focused.
---
--- @return color The calculated border color for the XMenuEntry.
function XMenuEntry:CalcBorderColor()
	if not self.enabled then return self.DisabledBackground end
	if self.state == "pressed-in" or self.state == "pressed-out" then
		return self.PressedBackground
	end
	if self.state == "mouse-in" then
		return self.RolloverBackground
	end
	local FocusedBorderColor, BorderColor = self.FocusedBorderColor, self.Toggled and self.ToggledBorderColor or self.BorderColor
	if FocusedBorderColor == BorderColor then return BorderColor end
	return self:IsFocused() and FocusedBorderColor or BorderColor
end


----- XPopupMenu

DefineClass.XPopupMenu = {
	__parents = { "XPopupList", "XActionsView", "XFontControl" },
	properties = {
		{ category = "Actions", id = "ActionContextEntries", editor = "text", default = "", },
		{ category = "Actions", id = "MenuEntries", editor = "text", default = "", },
		{ category = "Actions", id = "ShowIcons", editor = "bool", default = false, },
		{ category = "Actions", id = "IconReservedSpace", editor = "number", default = 0, },
		{ category = "Actions", id = "ButtonTemplate", editor = "choice", default = "XMenuEntry", items = function() return XTemplateCombo("XMenuEntry") end, },
	},
	LayoutMethod = "VList",
	Background = RGB(248, 248, 248),
	FocusedBackground = RGB(248, 248, 248),
	DisabledBackground = RGB(192, 192, 192),
	BorderWidth = 1,
}

--- Opens the XPopupMenu and updates the actions.
---
--- This function overrides the `XPopupList:Open()` function and adds a call to `XPopupMenu:OnUpdateActions()` after the parent function is called.
---
--- @param ... Any additional arguments to pass to the `XPopupList:Open()` function.
function XPopupMenu:Open(...)
	XPopupList.Open(self, ...)
	self:OnUpdateActions()
end

---
--- Closes all open popup menus in the current desktop.
---
--- This function recursively searches for the keyboard focus and closes any XPopupMenu instances that are parents of the focused window.
---
--- @return nil
function XPopupMenu:ClosePopupMenus()
	local focus = terminal.desktop:GetKeyboardFocus()
	while GetParentOfKind(focus, "XPopupMenu") do
		focus:SetFocus(false)
		focus = terminal.desktop:GetKeyboardFocus()
	end
end

---
--- Opens a new popup menu with the specified action ID.
---
--- This function creates a new `XPopupMenu` instance and sets its properties based on the current `XPopupMenu` instance. The new menu is then opened and displayed.
---
--- @param action_id string The action ID to use for the new popup menu.
--- @param host table The actions host to use for the new popup menu.
--- @param source XWindow The source window to use for the new popup menu's anchor.
---
function XPopupMenu:PopupAction(action_id, host, source)
	local menu = XPopupMenu:new({
		MenuEntries = action_id,
		Anchor = IsKindOf(source, "XWindow") and source.box,
		AnchorType = "right",
		popup_parent = self,
		GetActionsHost = function(self) return host end,
		DrawOnTop = true,
	}, terminal.desktop)
	menu:SetFontProps(self)
	menu:SetShowIcons(self.ShowIcons)
	menu:SetIconReservedSpace(self.IconReservedSpace)
	menu:Open()
end

---
--- Rebuilds the actions in the XPopupMenu.
---
--- This function is responsible for rebuilding the actions displayed in the XPopupMenu. It iterates through the actions provided by the host and creates the necessary UI elements to represent each action.
---
--- @param host table The actions host to use for rebuilding the actions.
---
function XPopupMenu:RebuildActions(host)
	local menu = self.MenuEntries
	local popup = self.ActionContextEntries
	
	local context = host.context
	local last_is_separator = false
	self.idContainer:DeleteChildren()
	for _, action in ipairs(host:GetActions()) do
		if (#popup == 0 and #menu ~= 0 and action.ActionMenubar == menu and host:FilterAction(action)) or (#popup ~= 0 and host:FilterAction(action, popup)) then
			local name = action.ActionName
			name = IsT(name) and _InternalTranslate(name, nil, false) or name
			if name:starts_with("---") then
				if not last_is_separator then
					local separator = XWindow:new({
						Background = RGBA(128, 128, 128, 196),
						MinHeight = 1,
						MaxHeight = 1,
						Margins = box(5, 2, 5, 2),
					}, self.idContainer)
					separator:Open()
					last_is_separator = true
				end
			else
				last_is_separator = false
				
				local entry = XTemplateSpawn(self.ButtonTemplate, self.idContainer, context)
				entry.OnPress = function(this, gamepad)
					if action.OnActionEffect ~= "popup" and not terminal.IsKeyPressed(const.vkShift) then
						self:ClosePopupMenus()
					end
					host:OnAction(action, this)
					if action.ActionToggle and self.window_state ~= "destroying" then
						self:RebuildActions(host)
					end
				end
				entry.action = action
				entry.OnAltPress = function(this, gamepad)
					self:ClosePopupMenus()
					if action.OnAltAction then 
						action:OnAltAction(host, this)
					end
				end
				entry:SetFontProps(self)
				entry:SetTranslate(action.ActionTranslate)
				entry:SetText(action.ActionName)
				entry:SetIconReservedSpace(self.IconReservedSpace)
				if action.ActionToggle then
					entry:SetToggled(action:ActionToggled(host))
				end
				if self.ShowIcons then
					entry:SetIcon(action:ActionToggled(host) and action.ActionToggledIcon ~= "" and action.ActionToggledIcon or action.ActionIcon)
				end
				entry:SetShortcut(Platform.desktop and action.ActionShortcut or action.ActionGamepad)
				if action:ActionState(host) == "disabled" then
					entry:SetEnabled(false)
				end
				entry:Open()
			end
		end
	end
	
	if last_is_separator then -- trailing separator
		self.idContainer[#self.idContainer]:Close()
	end
	if #self.idContainer == 0 then
		self:Close()
	end
end


----- XMenuBar

DefineClass.XMenuBar = {
	__parents = { "XActionsView", "XFontControl" },
	properties = {
		{ category = "Actions", id = "MenuEntries", editor = "text", default = "", },
		{ category = "Actions", id = "ShowIcons", editor = "bool", default = false, },
		{ category = "Actions", id = "IconReservedSpace", editor = "number", default = 0, },
		{ category = "Actions", id = "AutoHide", editor = "bool", default = true, },
	},
	LayoutMethod = "HList",
	HAlign = "stretch",
	VAlign = "top",
	Background = RGB(255, 255, 255),
	FocusedBackground = RGB(255, 255, 255),
	DisabledBackground = RGB(255, 255, 255),
	TextColor = RGB(48, 48, 48),
	DisabledTextColor = RGBA(48, 48, 48, 160),
	FoldWhenHidden = true,
}

---
--- Displays a popup menu with actions for the given `action_id`.
---
--- @param action_id string The ID of the actions to display in the popup menu.
--- @param host table The host object that provides the actions.
--- @param source XWindow The source window that the popup menu is anchored to.
---
function XMenuBar:PopupAction(action_id, host, source)
	local menu = XPopupMenu:new({
		MenuEntries = action_id,
		Anchor = IsKindOf(source, "XWindow") and source.box,
		AnchorType = "drop",
		GetActionsHost = function(self) return host end,
		DrawOnTop = true,
		popup_parent = self,
	}, terminal.desktop)
	menu:SetFontProps(self)
	menu:SetShowIcons(self.ShowIcons)
	menu:SetIconReservedSpace(self.IconReservedSpace)
	menu:Open()
end

---
--- Rebuilds the actions displayed in the XMenuBar.
---
--- @param host table The host object that provides the actions.
---
function XMenuBar:RebuildActions(host)
	local menu = self.MenuEntries
	local context = host.context
	self:DeleteChildren()
	for _, action in ipairs(host:GetMenubarActions(menu)) do
		if action.ActionName ~= "" and host:FilterAction(action) then
			local entry = XTextButton:new({
				HAlign = "stretch",
				OnPress = function(self)
					host:OnAction(action, self)
				end,
				Background = RGBA(0, 0, 0, 0),
				RolloverBackground = RGBA(40, 163, 255, 128),
				PressedBackground = RGBA(40, 163, 255, 140),
				Translate = action.ActionTranslate,
				Text = action.ActionName,
				Image = "CommonAssets/UI/round-frame-20.tga",
				FrameBox = box(9, 9, 9, 9),
				ImageScale = point(500, 500),
				Padding = box(2, 2, 2, 2),
			}, self, context)
			entry:SetFontProps(self)
			entry:Open()
		end
	end
	if self.AutoHide then
		self:SetVisibleInstant(#self > 0)
	end
end
