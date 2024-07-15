DefineClass.XToolBar = {
	__parents = { "XActionsView" },
	properties = {
		{ category = "Actions", id = "Toolbar", editor = "text", default = "", },
		{ category = "Actions", id = "Show", editor = "choice", default = "both", items = {"icon", "text", "both"}, },
		{ category = "Actions", id = "SeparatorColor", editor = "color", default = RGB(160, 160, 160), },
		{ category = "Actions", id = "ButtonTemplate", editor = "choice", default = "XTextButton", items = XTemplateCombo("XButton"), },
		{ category = "Actions", id = "ToggleButtonTemplate", editor = "choice", default = "XToggleButton",
			items = function(self, prop_meta, validate_fn)
				if validate_fn == "validate_fn" then
					-- function for preset validation, checks whether the property value is from "items"
					return "validate_fn", function(value, obj, prop_meta)
						return XTemplateCombo("XToggleButton")(self, prop_meta, "validate_fn") or
						       XTemplateCombo("XCheckButton")(self, prop_meta, "validate_fn")
					end
				end
				return table.union(XTemplateCombo("XToggleButton")(self), XTemplateCombo("XCheckButton")(self))
			end, },
		{ category = "Actions", id = "ToolbarSectionTemplate", editor = "choice", default = "GedToolbarSection", items = XTemplateCombo("XWindow"), },
		{ category = "Actions", id = "FocusOnClick", editor = "bool", default = true, },
		{ category = "Actions", id = "AutoHide", editor = "bool", default = true, },
	},
	LayoutMethod = "HList",
	IdNode = true,
	Background = RGB(255, 255, 255),
	FoldWhenHidden = true,
}

---
--- Returns the button parent of the XToolBar instance.
---
--- @return XWindow The button parent of the XToolBar instance.
---
function XToolBar:GetButtonParent()
	return self
end

---
--- Rebuilds the actions displayed in the XToolBar instance.
---
--- @param host XWindow The host window that contains the toolbar actions.
---
function XToolBar:RebuildActions(host)
	local parent = self:GetButtonParent()
	parent:DeleteChildren()
	local context = host.context
	local sections = {}
	local focus_on_click = self.FocusOnClick
	local actions = host:GetToolbarActions(self.Toolbar)
	for i, action in ipairs(actions) do
		if host:FilterAction(action) then
			local container = parent
			if action.ActionToolbarSection ~= "" then 
				local section = action.ActionToolbarSection
				if not sections[section] then 
					sections[section] = XTemplateSpawn(self.ToolbarSectionTemplate, container, context)
					sections[section]:Open()
					sections[section]:SetName(section)
				end	
				container = sections[section]:GetContainer()
			end
			local button = XTemplateSpawn(action.ActionToggle and self.ToggleButtonTemplate or action.ActionButtonTemplate or self.ButtonTemplate, container, context)
			local on_press = button.OnPress
			button.OnPress = function(self, ...)
				if focus_on_click then
					self:SetFocus()
				end
				on_press(self, ...)
				if focus_on_click then
					self:SetFocus(false)
				end
			end
			if action.ActionToggle then
				button:SetToggled(action:ActionToggled(host))
			end
			button.action = action
			if self.Show ~= "icon" then
				button:SetTranslate(action.ActionTranslate)
				if action.ActionTranslate then
					button:SetText(action.ActionName ~= "" and action.ActionName or Untranslated(action.ActionId))
				else
					button:SetText(action.ActionName ~= "" and action.ActionName or action.ActionId)
				end
			end
			if action.FXMouseIn ~= "" then
				button:SetFXMouseIn(action.FXMouseIn)
			end
			if action.FXPress ~= "" then
				button:SetFXPress(action.FXPress)
			end
			if action.FXPressDisabled ~= "" then
				button:SetFXPressDisabled(action.FXPressDisabled)
			end
			if action.ActionImage ~= "" then
				button:SetImage(action.ActionImage)
			end
			if action.ActionImageScale then
				button:SetImageScale(action.ActionImageScale)
			end
			if action.ActionFrameBox then
				button:SetFrameBox(action.ActionFrameBox)
			end
			if action.ActionFocusedBackground then
				button:SetFocusedBackground(action.ActionFocusedBackground)
			end
			if action.ActionPressedBackground then
				button:SetPressedBackground(action.ActionPressedBackground)
			end
			if action.ActionRolloverBackground then
				button:SetRolloverBackground(action.ActionRolloverBackground)
			end
			if self.Show ~= "text" then
				button:SetIcon(action.ActionIcon)
			end
			button.GetRolloverText = function(self)
				local enabled = self:GetEnabled()
				return not enabled and action.RolloverDisabledText ~= "" and action.RolloverDisabledText
						or action.RolloverText ~= "" and action.RolloverText
						or action.ActionName
			end
			button.GetRolloverOffset = function(self)
				return action.RolloverOffset ~= empty_box and action.RolloverOffset or self.RolloverOffset
			end
			button.GetRolloverAnchor = function(self) return self.parent and self.parent:GetRolloverAnchor() end
			button:SetId("id" .. action.ActionId)
			button:Open()
			
			if action.ActionToolbarSplit and i ~= #actions then
				self:AddToolbarSplit()
			end
		end
	end
	if self.AutoHide then
		self:SetVisibleInstant(#self > 0)
	end
end

---
--- Adds a toolbar split to the XToolBar.
--- A toolbar split is a vertical separator that divides the toolbar buttons.
---
--- @param self XToolBar The XToolBar instance.
---
function XToolBar:AddToolbarSplit()
	XWindow:new({
		Background = self.SeparatorColor,
		Margins = box(4, 2, 4, 2),
		MinWidth = 2,
	}, self):Open()
end

---
--- Displays a popup menu with actions for the given action ID.
---
--- @param self XToolBar The XToolBar instance.
--- @param action_id string The ID of the action to display the popup menu for.
--- @param host table The host object for the popup menu.
--- @param source XWindow The source window for the popup menu anchor.
---
function XToolBar:PopupAction(action_id, host, source)
	local menu = XPopupMenu:new({
		MenuEntries = action_id,
		Anchor = IsKindOf(source, "XWindow") and source.box,
		AnchorType = "bottom",
		GetActionsHost = function(self) return host end,
		DrawOnTop = true,
		popup_parent = self,
	}, terminal.desktop)
	menu:SetShowIcons(true)
	menu:Open()
end

-- Used to allow gamepad selection on XToolbar by integrating the existing XList functionality
DefineClass.XToolBarList = {
	__parents = { "XToolBar" },
	list = false
}

---
--- Initializes an XToolBarList instance.
---
--- The XToolBarList is a subclass of XToolBar that integrates the XList functionality to allow gamepad selection on the toolbar.
---
--- This function sets up the XList instance that will be used for the toolbar buttons, configuring its layout and appearance properties.
---
--- @param self XToolBarList The XToolBarList instance.
---
function XToolBarList:Init()
	local list = XTemplateSpawn("XList", self, self.context)
	list:SetIdNode(false)
	list:SetLayoutMethod(self.LayoutMethod)
	list:SetBackground(RGBA(0,0,0,0))
	list:SetFocusedBackground(RGBA(0,0,0,0))
	list:SetBorderColor(RGBA(0,0,0,0))
	list:SetFocusedBorderColor(RGBA(0,0,0,0))
	list:SetLayoutHSpacing(self.LayoutHSpacing)
	list:SetLayoutVSpacing(self.LayoutVSpacing)
	list:SetRolloverAnchor(self.RolloverAnchor)
	self.list = list
	
	local syncProps = { "LayoutHSpacing", "LayoutVSpacing", "LayoutMethod", "RolloverAnchor" }
	for i, f in ipairs(syncProps) do
		local setterName = "Set" .. f
		local mySetter = self[setterName]
		local listSetter = list[setterName]
		if mySetter and listSetter then
			self[setterName] = function(self, ...)
				mySetter(self, ...)
				listSetter(list, ...)
			end
		end
	end
end

---
--- Returns the parent container for the toolbar buttons.
---
--- This function returns the XList instance that is used to manage the layout and appearance of the toolbar buttons.
---
--- @param self XToolBarList The XToolBarList instance.
--- @return XList The parent container for the toolbar buttons.
---
function XToolBarList:GetButtonParent()
	return self.list
end

---
--- Sets the focus on the XList instance that manages the toolbar buttons.
---
--- This function forwards the focus call to the XList instance, allowing the gamepad selection to be controlled on the toolbar.
---
--- @param self XToolBarList The XToolBarList instance.
--- @param ... Any additional arguments to pass to the XList:SetFocus() function.
--- @return boolean Whether the focus was successfully set.
---
function XToolBarList:SetFocus(...)
	return self.list:SetFocus(...)
end

---
--- Rebuilds the toolbar actions and sets the initial selection on the toolbar list.
---
--- This function is called to update the toolbar actions and ensure the initial selection is set on the toolbar list. It first calls the `XToolBar:RebuildActions()` function to rebuild the actions, then sets the initial selection on the `self.list` XList instance.
---
--- @param self XToolBarList The XToolBarList instance.
--- @param ... Any additional arguments to pass to the `XToolBar:RebuildActions()` function.
---
function XToolBarList:RebuildActions(...)
	XToolBar.RebuildActions(self, ...)
	self.list:SetInitialSelection()
end