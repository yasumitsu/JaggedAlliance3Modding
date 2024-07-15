DefineClass.XCascade = {
	__parents = { "XActionsView" },
	properties = {
		{ category = "General", id = "MenuEntries", editor = "text", default = "", },
		{ category = "General", id = "ShowIcons", editor = "bool", default = false, },
		{ category = "General", id = "IconReservedSpace", editor = "number", default = 0, },
		{ category = "General", id = "CollapseTitles", editor = "bool", default = false, },
		{ category = "General", id = "ItemTemplate", editor = "text", default = "XTextButton" }
	},
	IdNode = true,
	VAlign = "stretch",
	HandleMouse = true,
	idSubCascade = false,
}

--- Initializes the XCascade UI element.
---
--- This function sets up the scroll area and container for the XCascade UI element.
--- The scroll area is created with the following properties:
--- - Id: "idScroll"
--- - Target: "idContainer"
--- - Dock: "right"
--- - Margins: box(1, 1, 1, 1)
--- - AutoHide: true
--- - MinThumbSize: 30
---
--- The container is created with the following properties:
--- - Id: "idContainer"
--- - VAlign: "top"
--- - LayoutMethod: "VList"
--- - VScroll: "idScroll"
function XCascade:Init()
	XSleekScroll:new({
		Id = "idScroll",
		Target = "idContainer",
		Dock = "right",
		Margins = box(1, 1, 1, 1),
		AutoHide = true,
		MinThumbSize = 30,
	}, self)
	XScrollArea:new({
		Id = "idContainer",
		VAlign = "top",
		LayoutMethod = "VList",
		VScroll = "idScroll",
	}, self)
end

--- Called when the XCascade UI element is deleted.
---
--- If the XCascade is a child of another XCascade, this function sets the parent XCascade to be uncollapsed.
function XCascade:OnDelete()
	if IsKindOf(self.parent, "XCascade") then
		self.parent:SetCollapsed(false)
	end
end

--- Displays a popup action menu for the XCascade UI element.
---
--- This function is called when an action is selected from the XCascade menu. It creates a new XCascade instance as a child of the current XCascade, with the selected action's menu entries. The new XCascade is positioned to the right of the current one, and inherits various properties from the parent XCascade such as IconReservedSpace, ShowIcons, CollapseTitles, and ItemTemplate.
---
--- @param action_id string The ID of the selected action
--- @param host table The host object that provides the menu actions
--- @param source table The source object that triggered the popup action
function XCascade:PopupAction(action_id, host, source)
	if self.idSubCascade then
		self.idSubCascade:Close()
	end
	local menu = g_Classes[self.class]:new({
		Id = "idSubCascade",
		MenuEntries = action_id,
		Dock = "right",
		GetActionsHost = function(self) return host end,
		IconReservedSpace = self.IconReservedSpace,
		ShowIcons = self.ShowIcons,
		CollapseTitles = self.CollapseTitles,
		ItemTemplate = self.ItemTemplate,
	}, self)
	menu:Open()
	menu:SetFocus()
	self:SetCollapsed(true)
end

---
--- Sets the collapsed state of the XCascade UI element.
---
--- When collapsed, the XCascade will display only the title bar and hide the content. The scroll bar will also be hidden.
--- When not collapsed, the XCascade will display the full content and the scroll bar will be visible.
---
--- @param collapsed boolean Whether the XCascade should be collapsed or not.
---
function XCascade:SetCollapsed(collapsed)
	self.idContainer:SetMaxWidth(collapsed and self.CollapseTitles and self.IconReservedSpace or 1000000)
	if collapsed then
		self.idScroll:SetAutoHide(false)
		self.idScroll:SetVisible(false)
	else
		self.idScroll:SetAutoHide(true)
	end
end

---
--- Handles mouse button down events for the XCascade UI element.
---
--- This function is called when the user clicks the left or right mouse button on the XCascade. If the left mouse button is clicked, the XCascade is set as the focused element and any open sub-cascades are closed. If the right mouse button is clicked, the XCascade is closed.
---
--- @param pt table The position of the mouse click
--- @param button string The mouse button that was clicked ("L" for left, "R" for right)
--- @return string "break" to indicate the event has been handled
---
function XCascade:OnMouseButtonDown(pt, button)
	if button == "L" then
		self:SetFocus()
		if self.idSubCascade then
			self.idSubCascade:Close()
		end
		return "break"
	end
	if button == "R" then
		self:Close()
		return "break"
	end
end

---
--- Rebuilds the actions displayed in the XCascade UI element.
---
--- This function is responsible for populating the XCascade with the menu entries provided by the host. It iterates through the menu entries, filters them based on the host's filtering logic, and creates a new entry in the XCascade for each valid action. The entry is configured with the action's properties, such as the translation, name, and icon (if enabled).
---
--- @param host table The host object that provides the menu entries.
---
function XCascade:RebuildActions(host)
	local menu = self.MenuEntries
	local context = host.context
	self.idContainer:DeleteChildren()
	for _, action in ipairs(host:GetMenubarActions(menu)) do
		if host:FilterAction(action) then
			local entry = XTemplateSpawn(self.ItemTemplate, self.idContainer, action) 
			entry.action = action
			entry:SetProperty("Translate", action.ActionTranslate)
			entry:SetProperty("Text", action.ActionName)
			entry:SetProperty("IconReservedSpace", self.IconReservedSpace)
			if self.ShowIcons then
				entry:SetProperty("Icon", action.ActionIcon)
			end
			entry:Open()
		end
	end
end
