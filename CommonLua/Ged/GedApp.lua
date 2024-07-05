function OnMsg.SystemActivate()
	if rawget(_G, "g_GedApp") and Platform.ged then
		g_GedApp.connection:Send("rfnGedActivated", false)
	end
end

GedDisabledOp = "(disabled)"
GedCommonOps = {
	{ Id = "MoveUp",    Name = "Move up",   Icon = "CommonAssets/UI/Ged/up.tga",        Shortcut = "Alt-Up", },
	{ Id = "MoveDown",  Name = "Move down", Icon = "CommonAssets/UI/Ged/down.tga",      Shortcut = "Alt-Down", },
	{ Id = "MoveOut",   Name = "Move out",  Icon = "CommonAssets/UI/Ged/left.tga",      Shortcut = "Alt-Left", },
	{ Id = "MoveIn",    Name = "Move in",   Icon = "CommonAssets/UI/Ged/right.tga",     Shortcut = "Alt-Right", },
	{ Id = "Delete",    Name = "Delete",    Icon = "CommonAssets/UI/Ged/delete.tga",    Shortcut = "Delete", Split = true, },
	{ Id = "Cut",       Name = "Cut",       Icon = "CommonAssets/UI/Ged/cut.tga",       Shortcut = "Ctrl-X", },
	{ Id = "Copy",      Name = "Copy",      Icon = "CommonAssets/UI/Ged/copy.tga",      Shortcut = "Ctrl-C", },
	{ Id = "Paste",     Name = "Paste",     Icon = "CommonAssets/UI/Ged/paste.tga",     Shortcut = "Ctrl-V", },
	{ Id = "Duplicate", Name = "Duplicate", Icon = "CommonAssets/UI/Ged/duplicate.tga", Shortcut = "Ctrl-D", Split = true, },
	{ Id = "DiscardEditorChanges", Name = "Discard editor changes", Icon = "CommonAssets/UI/Ged/cleaning_brush.png", Shortcut = "Ctrl-Alt-D", },
	{ Id = "Undo",      Name = "Undo",      Icon = "CommonAssets/UI/Ged/undo.tga",      Shortcut = "Ctrl-Z", },
	{ Id = "Redo",      Name = "Redo",      Icon = "CommonAssets/UI/Ged/redo.tga",      Shortcut = "Ctrl-Y", Split = true, },
}

DefineClass.GedApp = {
	__parents = { "XActionsHost", "XDarkModeAwareDialog" },
	properties = {
		{ category = "GedApp", id = "HasTitle", editor = "bool", default = true, },
		{ category = "GedApp", id = "Title", editor = "text", default = "", no_edit = function(obj) return not obj:GetProperty("HasTitle") end },
		{ category = "GedApp", id = "AppId", editor = "text", default = "", },
		{ category = "GedApp", id = "ToolbarTemplate", editor = "choice", default = "GedToolBar", items = XTemplateCombo("XToolBar"), },
		{ category = "GedApp", id = "MenubarTemplate", editor = "choice", default = "GedMenuBar", items = XTemplateCombo("XMenuBar"), },
		{ category = "GedApp", id = "CommonActionsInMenubar", editor = "bool", default = true, },
		{ category = "GedApp", id = "CommonActionsInToolbar", editor = "bool", default = true, },
		{ category = "GedApp", id = "InitialWidth", editor = "number", default = 1600, },
		{ category = "GedApp", id = "InitialHeight", editor = "number", default = 900, },
		{ category = "GedApp", id = "DiscardChangesAction", editor = "bool", default = true, },
	},
	LayoutMethod = "HPanel",
	LayoutHSpacing = 0,
	IdNode = true,
	Background = RGB(160, 160, 160),
	connection = false,
	in_game = false,
	settings = false,
	first_update = true, -- used by GedListPanel/GedTreePanel
	all_panels = false,
	interactive_panels = false, -- mapping context => panel
	actions_toggled = false, -- mapping actionid => toggled (only for Toggled actions)
	ui_status = false,
	ui_update_time = 0,
	ui_questions = false,
	ui_status_delay_time = 0,
	ui_status_delay_thread = false,
	last_focused_panel = false,
	last_focused_tree_or_list_panel = false,
	blink_thread = false, -- see GedOpError
	blink_border_color = RGBA(0, 0, 0, 0),
	progress_text = false,
	progress_bar = false,
	
	-- support for next/previous match when a search with "Search in properties and sub-objects" is active
	search_value_filter_text = false,
	search_value_results = false,
	search_value_panel = false,
	search_result_idx = 1,
	display_search_result = false,
}

---
--- Initializes the GedApp instance.
---
--- @param parent table The parent object.
--- @param context table The context data for the GedApp instance.
---
function GedApp:Init(parent, context)
	if Platform.ged then rawset(_G, "g_GedApp", self) end
	
	for k, v in pairs(context) do
		rawset(self, k, v)
	end
	if Platform.ged and self.connection then
		self.connection:Send("rfnGedActivated", true)
	end
	
	self.connection.app = self
	self.actions_toggled = {}
	self.ui_status = {}
	self:SetHasTitle(true)
	if not self.in_game then
		self.HAlign = "stretch"
		self.VAlign = "stretch"
		if self.ui_scale then
			self:SetScaleModifier(point(self.ui_scale * 10, self.ui_scale * 10))
		end
	end
	hr.MaxFps = Min(60, self.max_fps)
	ShowMouseCursor("GedApp")
	
	XAction:new({
		ActionId = "idSearch",
		ActionToolbar = false,
		ActionShortcut = "Ctrl-F",
		ActionContexts = {},
		ActionMenubar = false,
		ActionName = "Search",
		ActionTranslate = false,
		OnAction = function(action, ged_app, src)
			local panel = ged_app.last_focused_panel
			if panel and IsKindOf(panel, "GedPanel") then
				panel:OpenSearch()
			end
		end
	}, self)
	
	XAction:new({
		ActionId = "idExpandCollapseNode",
		ActionToolbar = false,
		ActionShortcut = "Alt-C",
		ActionContexts = {},
		ActionMenubar = false,
		ActionName = "Expand/collapse selected node's children",
		ActionTranslate = false,
		OnAction = function(action, ged_app, src)
			local panel = ged_app.last_focused_panel
			if panel and IsKindOf(panel, "GedTreePanel") then
				panel.idContainer:ExpandNodeByPath(panel.idContainer:GetFocusedNodePath() or empty_table)
				panel.idContainer:ExpandCollapseChildren(panel.idContainer:GetFocusedNodePath() or empty_table, not "recursive", "user_initiated")				
			end
		end
	}, self)
	XAction:new({
		ActionId = "idExpandCollapseTree",
		ActionToolbar = false,
		ActionShortcut = "Shift-C",
		ActionContexts = {},
		ActionMenubar = false,
		ActionName = "Expand/collapse tree",
		ActionTranslate = false,
		OnAction = function(action, ged_app, src)
			local panel = ged_app.last_focused_panel
			if IsKindOf(panel, "GedTreePanel") then
				panel.idContainer:ExpandCollapseChildren({}, "recursive", "user_initiated")
			elseif IsKindOf(panel, "GedPropPanel") then
				panel:ExpandCollapseCategories()
			end
		end
	}, self)
	
	if self.MenubarTemplate ~= "" then XTemplateSpawn(self.MenubarTemplate, self) end
	if self.ToolbarTemplate ~= "" then XTemplateSpawn(self.ToolbarTemplate, self) end
	
	if not self.in_game then
		self.status_ui = StdStatusDialog:new({}, self.desktop, { dark_mode = self.dark_mode })
		self.status_ui:SetVisible(false)
		self.status_ui:Open()
	end
	
	self:SetContext("root")
end

---
--- Adds common actions to the GedApp instance, such as File, Edit, Undo, Redo, and other common operations.
--- This function is responsible for creating and configuring the actions that will be available in the application's
--- menubar and toolbar.
---
--- The function checks the `interactive_panels` table to determine which actions should be enabled or disabled based
--- on the current state of the application. It also handles the creation of the "File" and "Edit" menubar items if
--- `CommonActionsInMenubar` is true.
---
--- @param self GedApp The GedApp instance.
function GedApp:AddCommonActions()
	if not self.interactive_panels then return end
	
	if self.CommonActionsInMenubar then
		if not self:ActionById("File") then
			XAction:new({
				ActionId = "File",
				ActionName = "File",
				ActionMenubar = "main",
				ActionTranslate = false,
				ActionSortKey = "1",
				OnActionEffect = "popup",
			}, self)
		end
		if not self:ActionById("Edit") then
			XAction:new({
				ActionId = "Edit",
				ActionName = "Edit",
				ActionMenubar = "main",
				ActionTranslate = false,
				ActionSortKey = "1",
				OnActionEffect = "popup",
			}, self)
		end
	end
	
	local has_undo = false -- if at least one panel with ActionsClass set
	for _, panel in pairs(self.interactive_panels) do
		has_undo = has_undo or panel.ActionsClass ~= "None"
	end
	
	local needs_separator = false
	for _, data in ipairs(GedCommonOps) do
		local id = data.Id
		local is_undo = id == "Undo" or id == "Redo" or id == "DiscardEditorChanges"
		local contexts = {}
		for _, panel in pairs(self.interactive_panels) do
			if not is_undo and panel[id] ~= "" and panel[id] ~= GedDisabledOp then
				if panel:IsKindOf("GedListPanel") then
					table.insert(contexts, panel.ItemActionContext)
				elseif panel:IsKindOf("GedTreePanel") then
					if panel.EnableForRootLevelItems or id == "Paste" then
						table.insert(contexts, panel.RootActionContext)
					end
					table.insert(contexts, panel.ChildActionContext)
				elseif panel:IsKindOf("GedPropPanel") then
					table.insert(contexts, panel.PropActionContext)
				end
			end
		end
		
		if is_undo and has_undo or next(contexts) then
			XAction:new({
				ActionId = id,
				ActionMenubar = self.CommonActionsInMenubar and "Edit",
				ActionToolbar = self.CommonActionsInToolbar and "main",
				ActionToolbarSplit = data.Split,
				ActionTranslate = false,
				ActionName = data.Name,
				ActionIcon = data.Icon,
				ActionShortcut = data.Shortcut,
				ActionSortKey = "1",
				ActionContexts = contexts,
				ActionState = function(self, host) return host:CommonActionState(self.ActionId) end,
				OnAction = function(self, host, source) host:CommonAction(self.ActionId) end,
			}, self)
			needs_separator = true
		end
		
		if data.Split and needs_separator then
			XAction:new({
				ActionMenubar = "Edit",
				ActionName = "-----",
				ActionTranslate = false,
				ActionSortKey = "1",
			}, self)
			needs_separator = false
		end
	end
end

---
--- Finds the GedPropPanel where the object from the current panel is displayed and that supports pasting properties.
--- This allows pasting properties even if the current panel has no operations.
---
--- @param panel GedPanel The current panel
--- @return GedPropPanel|nil The GedPropPanel where the object is displayed and that supports pasting properties, or nil if not found
---
function GedApp:FindPropPanelForPropertyPaste(panel)
	-- look for a GedPropPanel where the object from the current panel is displayed (and it supports paste)
	-- allow pasting properties in this case even if the current panel has no ops
	if panel and panel:HasMember("SelectionBind") then
		local panel_bindings = panel.SelectionBind:split(",")
		for _, prop_panel in pairs(self.interactive_panels) do
			if prop_panel:IsKindOf("GedPropPanel") and prop_panel.Paste ~= "" and prop_panel.Paste ~= GedDisabledOp and
			   table.find(panel_bindings, prop_panel.context) then
				return prop_panel
			end
		end
	end
end

local reCommaList = "([%w_]+)%s*,%s*"
---
--- Determines the state of a common action in the GedApp.
---
--- @param id string The ID of the common action to check the state for.
--- @return string The state of the common action, which can be "hidden", "disabled", or nil (enabled).
---
function GedApp:CommonActionState(id)
	if id == "DiscardEditorChanges" then
		return (not rawget(self, "PresetClass") or not self.DiscardChangesAction or config.ModdingToolsInUserMode) and "hidden"
	elseif id ~= "Undo" and id ~= "Redo" then
		local panel = self:GetLastFocusedPanel()
		if IsKindOf(panel, "GedTreePanel") and not panel.EnableForRootLevelItems then
			local selection = panel:GetSelection()
			if selection and #selection == 1 and id ~= "Paste" then
				return "disabled"
			end
		end
		
		-- Disable most common operations for read-only presets/objects
		if panel then
			-- Check if selection obj is read-only
			local sel_read_only
			if panel.SelectionBind then
				for bind in string.gmatch(panel.SelectionBind .. ",", reCommaList) do
					sel_read_only = sel_read_only or self.connection:Obj(bind .. "|read_only")
					if sel_read_only then
						break
					end
				end
			else
				sel_read_only = self.connection:Obj(panel.context .. "|read_only")
			end
			
			-- "sel_read_only == nil" means the binding object is changing, so actions should be disabled
			if sel_read_only == nil then
				sel_read_only = true
			end
			
			-- Panel context IS NOT read-only but the selection bind IS read-only (ex. Leftmost preset tree panel)
			if not panel.read_only and sel_read_only then
				-- Disable all operations when Modding, otherwise leave only Copy and Paste
				if (id ~= "Copy" and id ~= "Paste") or config.ModdingToolsInUserMode then
					return "disabled"
				end
			-- Panel context IS read-only but the selection bind IS read-only (ex. Middle preset panel (container items panel))
			elseif panel.read_only and sel_read_only then
				-- Disable all operations except Copy
				if id ~= "Copy" then
					return "disabled"
				end
			end
		end
		
		if not panel or not IsKindOf(panel, "GedPanel") or panel[id] == "" or panel[id] == GedDisabledOp then
			if id ~= "Paste" or not self:FindPropPanelForPropertyPaste(panel) then
				return "disabled"
			end
		end
	end
end

---
--- Handles common actions for the GedApp, such as Undo, Redo, DiscardEditorChanges, and various panel-specific actions like Copy, Paste, MoveUp, MoveDown, MoveIn, MoveOut, and Delete.
---
--- @param id string The ID of the common action to perform.
function GedApp:CommonAction(id)
	if id == "Undo" then
		self:Undo()
	elseif id == "Redo" then
		self:Redo()
	elseif id == "DiscardEditorChanges" then
		self:DiscardEditorChanges()
	else
		local panel = self:GetLastFocusedPanel()
		local op = panel[id]
		if panel:IsKindOf("GedPropPanel") then
			if id == "Copy" then
				self:Op(op, panel.context, panel:GetSelectedProperties(), panel.context)
			elseif id == "Paste" then
				self:Op(op, panel.context, panel:GetSelectedProperties(), panel.context)
			else
				assert(false, "Unknown common action " .. id .. "; prop panels only have Copy & Paste common actions")
			end
		elseif id == "MoveUp" or id == "MoveDown" or id == "MoveIn" or id == "MoveOut" or id == "Delete" then
			self:Op(op, panel.context, panel:GetMultiSelection())
		elseif id == "Cut" or id == "Copy" or id == "Paste" or id == "Duplicate" then
			if id == "Paste" and (op == "" or op == GedDisabledOp) then
				panel = self:FindPropPanelForPropertyPaste(panel)
				self:Op(panel[id], panel.context)
			else
				self:Op(op, panel.context, panel:GetMultiSelection(), panel.ItemClass(self))
			end
		else
			assert(false, "Unknown common action " .. id)
		end
	end
end

---
--- Sets whether the GedApp has a title bar.
---
--- If `has_title` is true, a title bar is added to the top of the GedApp. The title bar contains the app title and a close button.
--- If `has_title` is false, the title bar is removed.
---
--- @param has_title boolean Whether the GedApp should have a title bar.
---
function GedApp:SetHasTitle(has_title)
	self.HasTitle = has_title
	
	if self.in_game and self.HasTitle then
		if not self:HasMember("idTitleContainer") then
			XMoveControl:new({
				Id = "idTitleContainer",
				Dock = "top",
			}, self)
			XLabel:new({
				Id = "idTitle",
				Dock = "left",
				Margins = box(4, 2, 4, 2),
				TextStyle = "GedTitle",
			}, self.idTitleContainer)
			XTextButton:new({
				Dock = "right",
				OnPress = function(n) 
					self:Exit() 
				end,
				Text = "X",
				LayoutHSpacing = 0,
				Padding = box(1, 1, 1, 1),
				Background = RGBA(0, 0, 0, 0),
				RolloverBackground = RGB(204, 232, 255),
				PressedBackground = RGB(121, 189, 241),
				VAlign = "center",
				TextStyle = "GedTitle",
			}, self.idTitleContainer)
		end
	elseif self:HasMember("idTitleContainer") then
		self.idTitleContainer:Done()
	end
end

---
--- Updates the UI status of the GedApp.
---
--- If the GedApp is in-game, this function does nothing.
---
--- If `force` is false and the last UI update was less than 250 milliseconds ago, this function will wait until 250 milliseconds have passed since the last update and then call itself with `force` set to true.
---
--- Otherwise, this function updates the UI status text displayed in the GedApp. If the `ui_status` table is empty, the status UI is hidden. Otherwise, the status text is set to the concatenation of all the `text` fields in the `ui_status` table.
---
--- @param force boolean Whether to force an update of the UI status, even if it was recently updated.
---
function GedApp:UpdateUiStatus(force)
	if self.in_game then return end

	if not force and now() - self.ui_update_time < 250 then
		CreateRealTimeThread(function()
			Sleep(now() - self.ui_update_time)
			self:UpdateUiStatus(true)
		end)
		return
	end
	self.ui_update_time = now()

	if #self.ui_status == 0 then
		self.status_ui:SetVisible(false)
		return
	end
	
	local texts = {}
	for _, status in ipairs(self.ui_status) do
		texts[#texts + 1] = status.text
	end
	self.status_ui.idText:SetText(table.concat(texts, "\n"))
	self.status_ui:SetVisible(true)
end

---
--- Opens the GedApp and performs additional setup.
---
--- This function is called when the GedApp is opened. It performs the following steps:
---
--- 1. Calls `CreateProgressStatusText()` to create the progress status text UI element.
--- 2. Calls `XActionsHost.Open(self, ...)` to open the GedApp.
--- 3. Calls `AddCommonActions()` to add common actions to the GedApp.
--- 4. If the `AppId` is not empty, calls `ApplySavedSettings()` to apply any saved settings.
--- 5. Calls `SetDarkMode(GetDarkModeSetting())` to set the dark mode setting.
--- 6. Calls `OnContextUpdate(self.context, nil)` to update the context of the GedApp.
---
--- @param ... any additional arguments passed to the `Open()` function
---
function GedApp:Open(...)
	self:CreateProgressStatusText()
	
	XActionsHost.Open(self, ...)
	self:AddCommonActions()
	if self.AppId ~= "" then
		self:ApplySavedSettings()
	end
	self:SetDarkMode(GetDarkModeSetting())
	self:OnContextUpdate(self.context, nil)
end

---
--- Creates the progress status text UI element for the GedApp.
---
--- This function is responsible for creating the progress status text UI element that is displayed at the bottom of the first interactive panel in the GedApp. The progress status text UI element consists of a parent window, a progress bar, and a text element.
---
--- The progress status text UI element is hidden by default, and is only made visible when the `SetProgressStatus()` function is called with a non-nil `text` parameter.
---
--- @return nil
function GedApp:CreateProgressStatusText()
	if not self.interactive_panels then return end
	
	-- find first interactive panel, add the progress status text on its bottom
	for _, panel in ipairs(self.all_panels) do
		if self.interactive_panels[panel.context or false] then
			local parent = XWindow:new({
				Dock = "bottom",
				FoldWhenHidden = true,
				Margins = box(2, 1, 2, 1),
			}, panel)
			self.progress_bar = XWindow:new({
				DrawContent = function(self, clip_box)
					local bbox = self.content_box
					local sizex = MulDivRound(bbox:sizex(), self.progress, self.total_progress)
					UIL.DrawSolidRect(sizebox(bbox:min(), bbox:size():SetX(sizex)), RGBA(128, 128, 128, 128))
				end,
			}, parent)
			self.progress_text = XText:new({
				Background = RGBA(0, 0, 0, 0),
				TextStyle = "GedDefault",
				TextHAlign = "center",
			}, parent)
			parent:SetVisible(false)
			break
		end
	end
end

---
--- Sets the progress status text and progress bar for the GedApp.
---
--- This function is responsible for setting the progress status text and progress bar for the GedApp. It takes three parameters:
---
--- - `text`: the text to display in the progress status text UI element
--- - `progress`: the current progress value, which is used to update the progress bar
--- - `total_progress`: the total progress value, which is used to update the progress bar
---
--- If the `text` parameter is `nil`, the progress status text UI element is hidden. Otherwise, the progress status text UI element is made visible and the progress bar and text are updated accordingly.
---
--- @param text string|nil The text to display in the progress status text UI element
--- @param progress number The current progress value
--- @param total_progress number The total progress value
--- @return nil
function GedApp:SetProgressStatus(text, progress, total_progress)
	if not self.progress_text then return end
	if not text then
		self.progress_text.parent:SetVisible(false)
		return
	end
	rawset(self.progress_bar, "progress", progress)
	rawset(self.progress_bar, "total_progress", total_progress)
	self.progress_bar:Invalidate()
	self.progress_text:SetText(text)
	self.progress_text.parent:SetVisible(true)
end

---
--- Returns the default window box for the GedApp.
---
--- This function returns the default window box for the GedApp. If the app is running in-game, the window box is adjusted to fit within the game's viewport. Otherwise, the window box is positioned at (30, 30) on the screen.
---
--- @return sizebox The default window box for the GedApp.
function GedApp:GedDefaultBox()
	local ret = sizebox(20, 20, self.InitialWidth, self.InitialHeight)
	return ret + (self.in_game and GetDevUIViewport().box:min() or point(30, 30))
end

---
--- Applies the saved settings for the GedApp.
---
--- This function is responsible for applying the saved settings for the GedApp. It first loads the settings from the settings file, if it exists, and applies them to the GedApp. This includes setting the window box, resizing the resizable panels, and restoring the collapsed state of the interactive panels.
---
--- @return nil
function GedApp:ApplySavedSettings()
	self.settings = io.exists(self:SettingsPath()) and LoadLuaTableFromDisk(self:SettingsPath()) or {}
	self:SetWindowBox(self.settings.box or self:GedDefaultBox())
	if self.settings.resizable_panel_sizes then
		self:SetSizeOfResizablePanels()
	end
	
	local search_values = self.settings.search_in_props
	if search_values then
		for context, panel in pairs(self.interactive_panels) do
			local setting_value = search_values[context]
			if panel.SearchValuesAvailable and setting_value ~= nil and panel.search_values ~= setting_value then
				panel:ToggleSearchValues("no_settings_update")
			end
		end
	end
	
	local collapsed_categories = self.settings.collapsed_categories or empty_table
	for context, panel in pairs(self.interactive_panels) do
		panel.collapsed_categories = collapsed_categories[context] or {}
	end
end

---
--- Sets the window box for the GedApp.
---
--- This function is responsible for setting the window box for the GedApp. If the app is running in-game, the window box is adjusted to fit within the game's viewport. Otherwise, the window box is positioned at the specified coordinates on the screen.
---
--- @param box sizebox The new window box for the GedApp.
--- @return nil
function GedApp:SetWindowBox(box)
	if self.in_game then
		local viewport = GetDevUIViewport().box:grow(-20)
		if viewport:Intersect2D(box) ~= const.irInside then
			box = self:GedDefaultBox()
		end
		self:SetDock("ignore")
		self:SetBox(box:minx(), box:miny(), box:sizex(), box:sizey())
	else
		terminal.OverrideOSWindowPos(box:min())
		ChangeVideoMode(box:sizex(), box:sizey(), 0, true, false)
	end
end

---
--- Sets the size of the resizable panels in the GedApp.
---
--- This function is responsible for setting the maximum width and height of the resizable panels in the GedApp. It retrieves the saved panel size settings from the `self.settings.resizable_panel_sizes` table and applies them to the corresponding panels. If a panel cannot be found, the settings are ignored.
---
--- @return nil
function GedApp:SetSizeOfResizablePanels()
	if not self.settings.resizable_panel_sizes then return end
	for id, data in pairs(self.settings.resizable_panel_sizes) do
		local panel = self:ResolveId(id)
		if panel then 
			panel:SetMaxWidth(data.MaxWidth)
			panel:SetMaxHeight(data.MaxHeight)
		end
	end
end

---
--- Deletes the connection associated with the GedApp instance.
---
--- This function is responsible for deleting the connection associated with the GedApp instance. It is typically called when the GedApp is being closed or exited.
---
--- @return nil
function GedApp:Exit()
	self.connection:delete()
end

---
--- Closes the GedApp instance and saves its settings.
---
--- This function is responsible for closing the GedApp instance and saving its settings before the app is closed. It calls the `SaveSettings()` function to persist the current window box and resizable panel sizes, and then calls the `Close()` function of the `XActionsHost` class to handle the actual closing of the app.
---
--- @param ... any Additional arguments passed to the `Close()` function.
--- @return nil
function GedApp:Close(...)
	self:SaveSettings()
	XActionsHost.Close(self, ...)
end

---
--- Returns the path to the settings file for the GedApp instance.
---
--- This function constructs the file path for the settings file associated with the GedApp instance. The path includes the app ID and an optional preset class subcategory. If the app is running in-game, the filename will be prefixed with "ig_".
---
--- @return string The full path to the settings file.
function GedApp:SettingsPath()
	local subcategory = ""
	if rawget(self, "PresetClass") then subcategory = "-" .. self.PresetClass end
	local filename = string.format("AppData/Ged/%s%s%s.settings", self.in_game and "ig_" or "", self.AppId, subcategory)
	return filename
end

---
--- Saves the settings for the GedApp instance, including the window box size and the sizes of any resizable panels.
---
--- This function is responsible for persisting the current state of the GedApp instance to a settings file. It first retrieves the current window box size using the `GetWindowBox()` function, and then calls the `SavePanelSize()` function to save the sizes of any resizable panels. Finally, it constructs the full path to the settings file using the `SettingsPath()` function, creates the necessary directory structure, and saves the settings table to disk using the `SaveLuaTableToDisk()` function.
---
--- @return boolean True if the settings were successfully saved, false otherwise.
function GedApp:SaveSettings()
	if not self.settings then return end
	self.settings.box = self:GetWindowBox()
	self:SavePanelSize()

	local filename = self:SettingsPath()
	local path = SplitPath(filename)
	AsyncCreatePath(path)
	return SaveLuaTableToDisk(self.settings, filename)
end

---
--- Saves the sizes of any resizable panels in the GedApp instance to the settings table.
---
--- This function iterates through all the child elements of the GedApp instance and checks if they are not `XPanelSizer` instances and do not have a `Dock` property set. For each eligible child, it saves the `MaxHeight` and `MaxWidth` properties to the `resizable_panel_sizes` table in the `settings` table of the GedApp instance.
---
--- @return nil
function GedApp:SavePanelSize()
	if not self.settings["resizable_panel_sizes"] then
		self.settings["resizable_panel_sizes"] = {}
	end

	for _, child in ipairs(self) do
		if not child:IsKindOf("XPanelSizer") and not child.Dock then
			self.settings.resizable_panel_sizes[child.Id] = {
				MaxHeight = child.MaxHeight,
				MaxWidth = child.MaxWidth
			}
		end
	end
end

---
--- Activates the GedApp instance with the provided context.
---
--- This function sets the properties of the GedApp instance to the values in the provided context table. If the `BringToTop` function is available on the `terminal` object, it is called to bring the app to the top of the window stack.
---
--- @param context table The context to activate the GedApp instance with.
--- @return boolean True if the app was brought to the top, false otherwise.
function GedApp:Activate(context)
	for k, v in pairs(context) do
		rawset(self, k, v)
	end
	if rawget(terminal, "BringToTop") then
		return terminal.BringToTop()
	end
	return false
end

---
--- Gets the window box for the GedApp instance.
---
--- If the GedApp instance is running in-game, this function returns the `box` property of the instance. Otherwise, it returns a new `sizebox` with the position of the OS window and the size of the `box` property.
---
--- @return sizebox The window box for the GedApp instance.
function GedApp:GetWindowBox()
	if self.in_game then
		return self.box
	end
	return sizebox(terminal.GetOSWindowPos(), self.box:size())
end

---
--- Updates the context of the GedApp instance and performs various actions based on the provided view.
---
--- This function is responsible for updating the title of the GedApp instance, fetching global data as needed, and updating the property names in the GedPropPanel instances. It also calls the `CheckUpdateItemTexts` function to update the item texts in the "warnings_cache" and "dirty_objects" views.
---
--- @param context table The context to update the GedApp instance with.
--- @param view string The view to update the GedApp instance for.
--- @return nil
function GedApp:OnContextUpdate(context, view)
	if not view then
		if self.HasTitle then
			local title = self.Title
			title = _InternalTranslate(IsT(title) and title or T{title}, self, false)
			if self.in_game then
				self.idTitle:SetText(title)
			else
				terminal.SetOSWindowTitle(title)
			end
		end
		
		-- fetch global data, as needed
		if self.WarningsUpdateRoot then
			self.connection:BindObj("root|warnings_cache", "root", "GedGetCachedDiagnosticMessages")
		end
		if #GetChildrenOfKind(self, "GedPropPanel") > 0 then
			self.connection:BindObj("root|categories", "root", "GedGlobalPropertyCategories")
		end
		if self.PresetClass then
			self.connection:BindObj("root|prop_stats", "root", "GedPresetPropertyUsageStats", self.PresetClass)
		end
		if self.PresetClass or self.AppId == "ModEditor" then
			self.connection:BindObj("root|dirty_objects", "root", "GedGetDirtyObjects")
		end
	end
	if view == "prop_stats" then
		for _, panel in ipairs(self.all_panels) do
			if panel.context and IsKindOf(panel, "GedPropPanel") then
				panel:UpdatePropertyNames(panel.ShowInternalNames)
			end
		end
	end
	self:CheckUpdateItemTexts(view)
end

---
--- Updates the item texts in the "warnings_cache" and "dirty_objects" views of the GedApp instance.
---
--- This function iterates through all the panels in the GedApp instance and calls the `UpdateItemTexts` function on each panel that has a context set. This is used to update the item texts in the "warnings_cache" and "dirty_objects" views.
---
--- @param view string The view to update the item texts for.
--- @return nil
function GedApp:CheckUpdateItemTexts(view)
	if view == "warnings_cache" or view == "dirty_objects" then
		for _, panel in ipairs(self.all_panels) do
			if panel.context then -- cached detached panels as property editors get recreated by GedPropPanel:RebuildControls
				panel:UpdateItemTexts()
			end
		end
	end
end

---
--- Sets the title of the GedApp instance.
---
--- This function updates the title of the GedApp instance and then calls the `OnContextUpdate` function to update the UI.
---
--- @param title string The new title for the GedApp instance.
--- @return nil
function GedApp:SetTitle(title)
	self.Title = title
	self:OnContextUpdate(self.context, nil)
end

---
--- Adds a panel to the GedApp instance.
---
--- This function adds the given panel to the `all_panels` table of the GedApp instance. If the panel is interactive and not embedded, it is also added to the `interactive_panels` table, with a unique focus column assigned to it.
---
--- @param context string The context of the panel to add.
--- @param panel GedPanelBase The panel to add to the GedApp instance.
--- @return nil
function GedApp:AddPanel(context, panel)
	self.all_panels = self.all_panels or {}
	self.all_panels[#self.all_panels + 1] = panel
	
	if panel.Interactive and not panel.Embedded then
		self.interactive_panels = self.interactive_panels or {}
		if not self.interactive_panels[context] then
			local focus_column = 1
			for _, panel in pairs(self.interactive_panels) do
				focus_column = Max(focus_column, panel.focus_column + 1000)
			end
			panel.focus_column = focus_column
			self.interactive_panels[context] = panel
		end
	end
end

---
--- Removes a panel from the GedApp instance.
---
--- This function removes the given panel from the `all_panels` table of the GedApp instance. If the panel is interactive and not embedded, it is also removed from the `interactive_panels` table.
---
--- @param panel GedPanelBase The panel to remove from the GedApp instance.
--- @return nil
function GedApp:RemovePanel(panel)
	table.remove_value(self.all_panels, panel)
	for id, obj in pairs(self.interactive_panels or empty_table) do
		if obj == panel then
			self.interactive_panels[id] = nil
			return
		end
	end
end

---
--- Sets the selection for the specified panel context.
---
--- This function sets the selection for the panel associated with the given context. If the `selection` parameter is provided, the panel's selection is updated accordingly. If `notify` or `restoring_state` is true, the panel's search is canceled before the selection is set. If `focus` is true, the panel is set as the last focused panel and its container is given focus.
---
--- @param panel_context string The context of the panel to set the selection for.
--- @param selection table A table of indices representing the selected items.
--- @param multiple_selection boolean Whether the selection allows multiple items to be selected.
--- @param notify boolean Whether to notify the panel of the selection change.
--- @param restoring_state boolean Whether the selection is being restored from a saved state.
--- @param focus boolean Whether to set the panel as the last focused panel and give its container focus.
--- @return nil
function GedApp:SetSelection(panel_context, selection, multiple_selection, notify, restoring_state, focus)
	local panel = self.interactive_panels[panel_context]
	if not panel then return end
	if selection and (notify or restoring_state) then
		panel:CancelSearch("dont_select")
	end
	panel:SetSelection(selection, multiple_selection, notify, restoring_state)
	if not restoring_state then
		panel:SetPanelFocused()
	end
	if focus then
		self.last_focused_panel = panel -- will suppress GedPanelBase:OnSetFocus() which binds the object, selected in the panel
		self.last_focused_tree_or_list_panel = panel
		self:ActionsUpdated()
		panel.idContainer:SetFocus()
	end
end

---
--- Sets the search string for the specified panel context.
---
--- This function sets the search string for the panel associated with the given context. If a search string is provided, the panel's search is updated accordingly. If no search string is provided, the panel's search is canceled.
---
--- @param panel_context string The context of the panel to set the search string for.
--- @param search_string string The search string to set for the panel.
--- @return nil
function GedApp:SetSearchString(panel_context, search_string)
	local panel = self.interactive_panels[panel_context]
	if not panel then return end
	
	if not search_string then
		panel:CancelSearch()
		return
	end
	if panel.idSearchEdit then
		panel.idSearchEdit:SetText(search_string)
		panel:UpdateFilter()
	end
end

---
--- Selects the siblings of the currently focused panel's selection.
---
--- This function selects the siblings of the items currently selected in the focused panel. If `selected` is true, the siblings are added to the selection. If `selected` is false, the siblings are removed from the selection.
---
--- @param selection table A table of indices representing the selected items.
--- @param selected boolean Whether to add or remove the siblings from the selection.
--- @return nil
function GedApp:SelectSiblingsInFocusedPanel(selection, selected)
	local panel = self.last_focused_panel
	if panel then
		local first_selected, all_selected = panel:GetSelection()
		for _, idx in ipairs(selection) do
			if selected then
				table.insert_unique(all_selected, idx)
			else
				table.remove_value(all_selected, idx)
			end
		end
		panel:SetSelection(first_selected, all_selected, not "notify")
	end
end

---
--- Sets the selection for the specified panel context.
---
--- This function sets the selection for the panel associated with the given context. The `prop_list` parameter is a list of IDs to select in the panel.
---
--- @param context string The context of the panel to set the selection for.
--- @param prop_list table A list of IDs to select in the panel.
--- @return nil
function GedApp:SetPropSelection(context, prop_list) -- list with id's to select
	if not context or not self.interactive_panels[context] then return end
	self.interactive_panels[context]:SetSelection(prop_list)
end

---
--- Sets the last focused panel.
---
--- This function sets the last focused panel. If the new panel is different from the previous last focused panel, it updates the `last_focused_panel` and `last_focused_tree_or_list_panel` properties, and calls the `ActionsUpdated` function.
---
--- @param panel table The new last focused panel.
--- @return boolean True if the last focused panel was updated, false otherwise.
function GedApp:SetLastFocusedPanel(panel)
	if self.last_focused_panel ~= panel then
		self.last_focused_panel = panel
		if IsKindOfClasses(panel, "GedTreePanel", "GedListPanel") then
			self.last_focused_tree_or_list_panel = panel
		end
		self:ActionsUpdated()
		return true
	end
end

---
--- Gets the last focused panel.
---
--- This function returns the last focused panel in the GedApp instance.
---
--- @return table The last focused panel.
function GedApp:GetLastFocusedPanel()
	return self.last_focused_panel
end

---
--- Gets the current state of the GedApp instance.
---
--- This function returns a table containing the state of the interactive panels in the GedApp instance. If the `window_state` is not "destroying", it iterates through the `interactive_panels` table and gets the state of each panel, storing it in the returned table. The `focused_panel` field in the returned table is set to the context of the last focused tree or list panel.
---
--- @return table The current state of the GedApp instance.
function GedApp:GetState()
	local state = {}
	if self.interactive_panels and self.window_state ~= "destroying" then
		for context, panel in pairs(self.interactive_panels) do
			state[context] = panel:GetState()
		end
	end
	state.focused_panel = self.last_focused_tree_or_list_panel and self.last_focused_tree_or_list_panel.context
	return state
end

---
--- Handles mouse button down events for the GedApp instance.
---
--- This function is called when a mouse button is pressed on the GedApp instance. If the left mouse button is pressed, it sets the focus on the last focused panel. It then returns "break" to indicate that the event has been handled and should not be propagated further.
---
--- @param pt table The position of the mouse pointer when the button was pressed.
--- @param button string The name of the mouse button that was pressed ("L" for left, "R" for right, "M" for middle).
--- @return string "break" to indicate that the event has been handled.
function GedApp:OnMouseButtonDown(pt, button)
	if button == "L" then
		if self.last_focused_panel then
			self.last_focused_panel:SetPanelFocused()
		end
		return "break"
	end
end

---
--- Handles mouse wheel forward events for the GedApp instance.
---
--- This function is called when the mouse wheel is scrolled forward on the GedApp instance. It returns "break" to indicate that the event has been handled and should not be propagated further.
---
--- @return string "break" to indicate that the event has been handled.
function GedApp:OnMouseWheelForward()
	return "break"
end

---
--- Handles mouse wheel back events for the GedApp instance.
---
--- This function is called when the mouse wheel is scrolled backward on the GedApp instance. It returns "break" to indicate that the event has been handled and should not be propagated further.
---
--- @return string "break" to indicate that the event has been handled.
function GedApp:OnMouseWheelBack()
	return "break"
end

---
--- Sets the toggled state of the specified action.
---
--- @param action_id string The ID of the action to toggle.
--- @param toggled boolean The new toggled state of the action.
function GedApp:SetActionToggled(action_id, toggled)
	self.actions_toggled[action_id] = toggled
	self:ActionsUpdated()
end

---
--- Performs a named operation on the specified object.
---
--- This function is used to execute a named operation on the specified object. The operation is sent to the connection, along with the current application state, the name of the operation, and any additional arguments required by the operation.
---
--- @param op_name string The name of the operation to perform.
--- @param obj table The object on which the operation should be performed.
--- @param ... any Additional arguments required by the operation.
function GedApp:Op(op_name, obj, ...)
	self.connection:Send("rfnOp", self:GetState(), op_name, obj, ...)
end

---
--- Saves the current state of the GedApp instance.
---
--- This function is called when the application needs to save its current state. It checks if the keyboard focus is on a GedPropEditor instance, and if so, sends the current value of the property being edited to the game.
---
--- @return nil
function GedApp:OnSaving()
	local focus = self.desktop.keyboard_focus
	if focus then
		local prop_editor = GetParentOfKind(focus, "GedPropEditor")
		if prop_editor and not prop_editor.prop_meta.read_only then
			prop_editor:SendValueToGame()
		end
	end
end

---
--- Sends a request to the game connection to execute a global function.
---
--- This function is used to send a request to the game connection to execute a global function, without modifying any objects. The function name and any additional arguments are passed to the connection, which then executes the function on the game side.
---
--- @param rfunc_name string The name of the global function to execute.
--- @param ... any Additional arguments to pass to the global function.
--- @return nil
function GedApp:Send(rfunc_name, ...)
end
function GedApp:Send(rfunc_name, ...) -- for calls that don't modify objects
	self.connection:Send("rfnRunGlobal", rfunc_name, ...)
end

---
--- Sends a request to the game connection to execute a global function and returns the result.
---
--- This function is used to send a request to the game connection to execute a global function, without modifying any objects. The function name and any additional arguments are passed to the connection, which then executes the function on the game side and returns the result.
---
--- @param rfunc_name string The name of the global function to execute.
--- @param ... any Additional arguments to pass to the global function.
--- @return any The result of the global function execution.
function GedApp:Call(rfunc_name, ...) -- for calls that return a value
	return self.connection:Call("rfnRunGlobal", rfunc_name, ...)
end

---
--- Sends a request to the game connection to execute a method on an object.
---
--- This function is used to send a request to the game connection to execute a method on an object, without modifying any other objects. The object name, method name, and any additional arguments are passed to the connection, which then executes the method on the game side.
---
--- @param obj_name string The name of the object on which to execute the method.
--- @param func_name string The name of the method to execute.
--- @param ... any Additional arguments to pass to the method.
--- @return nil
function GedApp:InvokeMethod(obj_name, func_name, ...)
	self.connection:Send("rfnInvokeMethod", obj_name, func_name, ...)
end

---
--- Sends a request to the game connection to execute a method on an object and returns the result.
---
--- This function is used to send a request to the game connection to execute a method on an object, without modifying any other objects. The object name, method name, and any additional arguments are passed to the connection, which then executes the method on the game side and returns the result.
---
--- @param obj_name string The name of the object on which to execute the method.
--- @param func_name string The name of the method to execute.
--- @param ... any Additional arguments to pass to the method.
--- @return any The result of the method execution.
function GedApp:InvokeMethodReturn(obj_name, func_name, ...) -- for calls that return a value
	return self.connection:Call("rfnInvokeMethod", obj_name, func_name, ...)
end

---
--- Sends a request to the game connection to undo the last action.
---
--- This function is used to send a request to the game connection to undo the last action performed, without modifying any objects. The request is sent to the connection, which then executes the undo operation on the game side.
---
--- @return nil
function GedApp:Undo()
	self.connection:Send("rfnUndo")
end

---
--- Sends a request to the game connection to redo the last undone action.
---
--- This function is used to send a request to the game connection to redo the last action that was undone, without modifying any objects. The request is sent to the connection, which then executes the redo operation on the game side.
---
--- @return nil
function GedApp:Redo()
	self.connection:Send("rfnRedo")
end

---
--- Stores the current state of the GedApp application.
---
--- This function is used to send a request to the game connection to store the current state of the GedApp application. The state is obtained by calling the `GedApp:GetState()` function and then sent to the connection, which stores the state on the game side.
---
--- @return nil
function GedApp:StoreAppState()
	self.connection:Send("rfnStoreAppState", self:GetState())
end

---
--- Sends a request to the game connection to select and bind an object.
---
--- This function is used to send a request to the game connection to select and bind an object. The object name, address, and method name are passed to the connection, which then selects and binds the object on the game side.
---
--- @param name string The name of the object to select and bind.
--- @param obj_address string The address of the object to select and bind.
--- @param func_name string The name of the method to execute on the bound object.
--- @param ... any Additional arguments to pass to the method.
--- @return nil
function GedApp:SelectAndBindObj(name, obj_address, func_name, ...)
	self.connection:Send("rfnSelectAndBindObj", name, obj_address, func_name, ...)
end

---
--- Sends a request to the game connection to select and bind multiple objects.
---
--- This function is used to send a request to the game connection to select and bind multiple objects. The object name, address, and a list of indexes are passed to the connection, which then selects and binds the objects on the game side. The function name and any additional arguments are also passed to the connection to be executed on the bound objects.
---
--- @param name string The name of the objects to select and bind.
--- @param obj_address string The address of the objects to select and bind.
--- @param all_indexes table A list of indexes of the objects to select and bind.
--- @param func_name string The name of the method to execute on the bound objects.
--- @param ... any Additional arguments to pass to the method.
--- @return nil
function GedApp:SelectAndBindMultiObj(name, obj_address, all_indexes, func_name, ...)
	self.connection:Send("rfnSelectAndBindMultiObj", name, obj_address, all_indexes, func_name, ...)
end

---
--- Discards any unsaved changes in the editor.
---
--- This function is used to discard any unsaved changes that have been made in the editor. It sends a request to the game connection to discard the changes, effectively reverting the editor state to the last saved version.
---
--- @return nil
function GedApp:DiscardEditorChanges()
	self:Send("GedDiscardEditorChanges")
end

---
--- Retrieves the last error that occurred in the game connection.
---
--- This function is used to retrieve the last error that occurred in the game connection. It calls the `rfnGetLastError` method on the connection to get the error text and the time the error occurred. The time is then adjusted to be relative to the game's real-time clock.
---
--- @return string The error text.
--- @return number The time the error occurred, relative to the game's real-time clock.
function GedApp:GetGameError()
	local error_text, error_time = self.connection:Call("rfnGetLastError")
	return error_text, error_time and (error_time - self.game_real_time)
end

---
--- Displays a message dialog with the given title and text.
---
--- This function is used to display a message dialog to the user, with the specified title and text. The dialog is displayed in the application's desktop.
---
--- @param title string The title of the message dialog.
--- @param text string The text to display in the message dialog.
--- @return nil
function GedApp:ShowMessage(title, text)
	StdMessageDialog:new({}, self.desktop, { title = title, text = text, dark_mode = self.dark_mode }):Open()
end

---
--- Displays a question dialog with the given title, text, and optional buttons.
---
--- This function is used to display a question dialog to the user, with the specified title and text. The dialog can optionally include "OK" and "Cancel" buttons with custom text. The dialog is displayed in the application's desktop.
---
--- @param title string The title of the question dialog.
--- @param text string The text to display in the question dialog.
--- @param ok_text string (optional) The text to display on the "OK" button.
--- @param cancel_text string (optional) The text to display on the "Cancel" button.
--- @return boolean True if the "OK" button was clicked, false if the "Cancel" button was clicked or the dialog was closed.
function GedApp:WaitQuestion(title, text, ok_text, cancel_text)
	local dialog = StdMessageDialog:new({}, self.desktop, {
		title = title or "",
		text = text or "",
		ok_text = ok_text ~= "" and ok_text,
		cancel_text = cancel_text ~= "" and cancel_text,
		translate = false,
		question = true,
		dark_mode = self.dark_mode,
	})
	dialog:Open()
	
	self.ui_questions = self.ui_questions or {}
	table.insert(self.ui_questions, dialog)
	
	local result, win = dialog:Wait()
	if self.ui_questions then
		table.remove_value(self.ui_questions, dialog)
	end
	return result
end

---
--- Closes the first question dialog in the `ui_questions` list, if it exists.
---
--- This function is used to close the first question dialog that was opened using the `GedApp:WaitQuestion()` function. It is typically called when the user wants to cancel or delete the current operation.
---
--- @return nil
function GedApp:DeleteQuestion() -- cancel is already taken as the default "answer"
	local question = self.ui_questions and self.ui_questions[1]
	if question then
		question:Close("delete") -- the waiting thread should remove it form the list
	end
end

---
--- Displays a dialog to get user input.
---
--- This function is used to display a dialog to the user, allowing them to enter input. The dialog has a title, a default value, and a list of items to choose from.
---
--- @param title string The title of the input dialog.
--- @param default string The default value to display in the input field.
--- @param items table A table of items to display in the dialog.
--- @return string The user's input, or nil if the dialog was closed.
function GedApp:WaitUserInput(title, default, items)
	local dialog = StdInputDialog:new({}, self.desktop, { title = title, default = default, items = items, dark_mode = self.dark_mode })
	dialog:Open()
	local result, win = dialog:Wait()
	return result
end

---
--- Displays a dialog to allow the user to select an item from a list.
---
--- This function is used to display a dialog to the user, allowing them to select an item from a list of options. The dialog has a title, a default selected item, and a specified number of lines to display.
---
--- @param items table A table of items to display in the dialog.
--- @param caption string The title of the input dialog.
--- @param start_selection string The default selected item in the list.
--- @param lines number The number of lines to display in the dialog.
--- @return string The selected item, or nil if the dialog was closed.
function GedApp:WaitListChoice(items, caption, start_selection, lines)
	local dialog = StdInputDialog:new({}, terminal.desktop, { title = caption, default = start_selection, items = items, lines = lines } )
	dialog:Open()
	local result, win = dialog:Wait()
	return result
end

---
--- Sets the UI status text and optionally sets a delay before clearing the status.
---
--- This function is used to update the UI status text, which is typically displayed in a status bar or similar UI element. The status text can be set with an optional delay, after which the status will be automatically cleared.
---
--- @param id string A unique identifier for the status message.
--- @param text string The text to display in the UI status.
--- @param delay number (optional) The delay in seconds before the status is automatically cleared.
--- @return nil
function GedApp:SetUiStatus(id, text, delay)
	local idx = table.find(self.ui_status, "id", id) or (#self.ui_status + 1)
	if not text then
		table.remove(self.ui_status, idx)
	else
		self.ui_status[idx] = { id = id, text = text }
	end
	self:UpdateUiStatus()
	if delay then
		self.ui_status_delay_time = RealTime() + delay
		if not self.ui_status_delay_thread then
			self.ui_status_delay_thread = CreateRealTimeThread(function()
				while self.ui_status_delay_time - RealTime() > 0 do
					Sleep(self.ui_status_delay_time - RealTime())
				end
				self:SetUiStatus(id)
				self.ui_status_delay_thread = nil
			end)
		end
	end
end

---
--- Opens a browse dialog to allow the user to select a folder or file.
---
--- This function is used to open a browse dialog that allows the user to select a folder or file. The dialog can be configured to allow the user to create a new folder, and to allow multiple selections.
---
--- @param folder string The initial folder to display in the browse dialog.
--- @param filter string (optional) A file filter to apply to the browse dialog.
--- @param create boolean (optional) Whether to allow the user to create a new folder.
--- @param multiple boolean (optional) Whether to allow multiple selections.
--- @return string|table The selected folder or file(s), or nil if the dialog was closed.
function GedApp:WaitBrowseDialog(folder, filter, create, multiple)
	return OpenBrowseDialog(folder, filter or "", not not create, not not multiple)
end

---
--- Displays an error message in the UI with a blinking border around the main window.
---
--- This function is used to display an error message to the user, with a blinking red border around the main window to draw attention to the error. The border will blink three times, then the border color will be reset.
---
--- @param error_message string The error message to display.
--- @return nil
function GedApp:GedOpError(error_message)
	if not self.blink_thread then
		self.blink_thread = CreateRealTimeThread(function()
			for i = 1, 3 do
				self.blink_border_color = RGB(220, 0, 0)
				self:Invalidate()
				Sleep(50)
				self.blink_border_color = RGBA(0, 0, 0, 0)
				self:Invalidate()
				Sleep(50)
			end
			self.blink_border_color = nil
			self.blink_thread = nil
			self:Invalidate()
		end)
	end
	if type(error_message) == "string" and error_message ~= "error" and error_message ~= "" then
		self:ShowMessage("Error", error_message)
	end
end

---
--- Draws the children of the GedApp object, and optionally draws a blinking border around the main window if the `blink_border_color` property is set.
---
--- @param clip_box table The bounding box to use for clipping the child elements.
--- @return nil
function GedApp:DrawChildren(clip_box)
	XActionsHost.DrawChildren(self, clip_box)
	if self.blink_border_color ~= RGBA(0, 0, 0, 0) then
		local box = (self:GetLastFocusedPanel() or self).box
		UIL.DrawBorderRect(box, 2, 2, self.blink_border_color, RGBA(0, 0, 0, 0))
	end
end

--- Returns the data for the currently displayed search result.
---
--- This function returns the data for the currently displayed search result, if a search has been performed and the results are being displayed. The data is returned as a table, which may contain various properties related to the search result.
---
--- @return table|nil The data for the currently displayed search result, or nil if no search has been performed or the results are not being displayed.
function GedApp:GetDisplayedSearchResultData()
	return self.display_search_result and self.search_value_results and self.search_value_results[self.search_result_idx]
end

---
--- Attempts to highlight the search match in child panels of the given parent panel.
---
--- This function iterates through all the child panels of the given parent panel and checks if the panel's context matches the search selection. If a match is found, the `TryHighlightSearchMatch()` function is called on the panel to highlight the search match.
---
--- @param parent_panel table The parent panel to search for child panels.
--- @return nil
function GedApp:TryHighlightSearchMatchInChildPanels(parent_panel)
	if not parent_panel.SelectionBind then return end
	for bind in string.gmatch(parent_panel.SelectionBind .. ",", reCommaList) do
		local bind_dot = bind .. "."
		for _, panel in ipairs(self.all_panels) do
			local context = panel.context
			if panel.window_state ~= "destroying" and context and (context == bind or context:starts_with(bind_dot)) then
				panel:TryHighlightSearchMatch()
			end
		end
	end	
end

---
--- Focuses the specified property editor within the given panel.
---
--- This function locates the property editor with the specified ID within the panel identified by the given panel ID. If the property editor is found, it is given focus.
---
--- @param panel_id string The ID of the panel containing the property editor.
--- @param prop_id string The ID of the property editor to focus.
--- @return nil
function GedApp:FocusProperty(panel_id, prop_id)
	local panel = self.interactive_panels[panel_id]
	local prop_editor = panel and panel:LocateEditorById(prop_id)
	if prop_editor then
		local focus = prop_editor:GetRelativeFocus(point(0, 0), "next") or prop_editor
		focus:SetFocus()
	end
end

---
--- Opens a context menu with actions related to the specified action context.
---
--- This function creates a new XPopupMenu instance and configures it with the provided action context and anchor point. The menu is then opened and returned.
---
--- @param action_context string The action context to use for the context menu entries.
--- @param anchor_pt table The anchor point to use for positioning the context menu.
--- @return table The opened XPopupMenu instance.
function GedApp:OpenContextMenu(action_context, anchor_pt)
	if not action_context or not anchor_pt or action_context == "" then return end
	local menu = XPopupMenu:new({
		ActionContextEntries = action_context,
		Anchor = anchor_pt,
		AnchorType = "mouse",
		MaxItems = 12,
		GetActionsHost = function() return self end,
		popup_parent = self,
		RebuildActions = function(menu, host)
			XPopupMenu.RebuildActions(menu, host)
			for _, entry in ipairs(menu.idContainer) do
				if entry.action.OnActionEffect == "popup" then
					XLabel:new({
						Dock = "right",
						ZOrder = -1,
						Margins = box(5, 0, 0, 0),
					}, entry):SetText(">")
				end
			end
		end,
	}, terminal.desktop)
	menu:Open()
	return menu
end

----- Dark Mode support

---
--- Determines the current dark mode setting.
---
--- If the dark mode setting is "Follow system", the function will return the system's dark mode setting. Otherwise, it will return whether the dark mode setting is enabled or not.
---
--- @return boolean Whether dark mode is enabled or not.
function GetDarkModeSetting()
	local setting = rawget(_G, "g_GedApp") and g_GedApp.dark_mode
	if setting == "Follow system" then
		return GetSystemDarkModeSetting()
	else
		return setting and setting ~= "Light"
	end
end

local menubar = RGB(64, 64, 64)
local l_menubar = RGB(255, 255, 255) 

local menu_selection = RGB(100, 100, 100)
local l_menu_selection = RGB(204, 232, 255)

local toolbar = RGB(64, 64, 64)
local l_toolbar = RGB(255, 255, 255)

local panel = RGB(42, 41, 41)
local panel_title = RGB(64, 64, 64)
local panel_background_tab = RGB(96, 96, 96)
local panel_rollovered_tab = RGB(110, 110, 110)
local panel_child = RGBA(0, 0, 0, 0)
local panel_focused_border = RGB(100, 100, 100)

local l_panel = RGB(255, 255, 255)
local l_panel_title = RGB(220, 220, 220)
local l_panel_background_tab = RGB(196, 196, 196)
local l_panel_rollovered_tab = RGB(240, 240, 240)
local l_panel_child = RGBA(0, 0, 0, 0)
local l_panel_focused_border = RGB(0, 0, 0)

local l_prop_button_focused =  RGB(24, 123, 197)
local l_prop_button_rollover = RGB(24, 123, 197)
local l_prop_button_pressed =  RGB(38, 146, 227)
local l_prop_button_disabled = RGB(128, 128, 128)
local l_prop_button_background = RGB(38, 146, 227)

local prop_button_focused =  RGB(193, 193, 193)
local prop_button_rollover = RGB(100, 100, 100)
local prop_button_pressed =  RGB(105, 105, 105)
local prop_button_disabled = RGB(93, 93, 93)
local prop_button_background = RGB(105, 105, 105)

local scroll = RGB(131, 131, 131)
local scroll_pressed = RGB(211, 211, 211)
local scroll_rollover = RGB(170, 170, 170)
local scroll_background = RGB(64, 64, 64)
local button_divider = RGB(100, 100, 100)

local l_scroll = RGB(169, 169, 169)
local l_scroll_pressed = RGB(100, 100, 100)
local l_scroll_rollover = RGB(128, 128, 128)
local l_scroll_background = RGB(240, 240, 240)
local l_button_divider = RGB(169, 169, 169)

local edit_box = RGB(54, 54, 54)
local edit_box_border = RGB(130, 130, 130)
local edit_box_focused = RGB(42, 41, 41)

local l_edit_box = RGB(240, 240, 240)
local l_edit_box_border = RGB(128, 128, 128)
local l_edit_box_focused = RGB(255, 255, 255)

local propitem_selection = RGB(20, 109, 171)
local subobject_selection = RGB(40, 50, 70)
local panel_item_selection = RGB(70, 70, 70)

local l_propitem_selection = RGB(121, 189, 241)
local l_subobject_selection = RGB(204, 232, 255)
local l_panel_item_selection = RGB(204, 232, 255)

local button_border = RGB(130, 130, 130)
local button_pressed_background = RGB(191, 191, 191)
local button_toggled_background = RGB(150, 150, 150)
local button_rollover = RGB(70, 70, 70)

local l_button_border = RGB(240, 240, 240)
local l_button_pressed_background = RGB(121, 189, 241)
local l_button_toggled_background = RGB(35, 97, 171)
local l_button_rollover = RGB(204, 232, 255)

local checkbox_color = RGB(128, 128, 128)
local checkbox_disabled_color = RGBA(128, 128, 128, 128)

---
--- Updates the dark mode state of all child controls of the specified window.
---
--- @param win GedWindow The window whose child controls should be updated.
---
function GedApp:UpdateChildrenDarkMode(win)
	if win.window_state ~= "destroying" then
		self:UpdateControlDarkMode(win)
		if not IsKindOfClasses(win, "XMenuBar", "XToolBar", "GedPanelBase", "GedPropSet") then
			for _, child in ipairs(win or self) do
				self:UpdateChildrenDarkMode(child)
			end
		end
	end
end

---
--- Sets the text style of the specified control based on the current dark mode state.
---
--- @param control GedControl The control to set the text style for.
--- @param dark_mode boolean Whether dark mode is enabled or not.
---
function SetUpTextStyle(control, dark_mode)
	local new_style = GetTextStyleInMode(rawget(control, "TextStyle"), dark_mode)
	if new_style then
		control:SetTextStyle(new_style)
	elseif control.TextStyle:starts_with("GedDefault") then
		control:SetTextStyle(dark_mode and "GedDefaultDark" or "GedDefault")
	elseif control.TextStyle:starts_with("GedSmall") then
		control:SetTextStyle(dark_mode and "GedSmallDark" or "GedSmall")
	end
end
local function SetUpTextStyle(control, dark_mode)
	local new_style = GetTextStyleInMode(rawget(control, "TextStyle"), dark_mode)
	if new_style then
		control:SetTextStyle(new_style)
	elseif control.TextStyle:starts_with("GedDefault") then
		control:SetTextStyle(dark_mode and "GedDefaultDark" or "GedDefault")
	elseif control.TextStyle:starts_with("GedSmall") then
		control:SetTextStyle(dark_mode and "GedSmallDark" or "GedSmall")
	end
end

local function SetUpDarkModeButton(button, dark_mode)
	SetUpTextStyle(button, dark_mode)
	button:SetBackground(dark_mode and prop_button_background or l_prop_button_background)
	button:SetFocusedBackground(dark_mode and prop_button_focused or l_prop_button_focused)
	button:SetRolloverBackground(dark_mode and prop_button_rollover or l_prop_button_rollover)
	button:SetPressedBackground(dark_mode and prop_button_pressed or l_prop_button_pressed)
	button:SetDisabledBackground(dark_mode and prop_button_disabled or l_prop_button_disabled)
end

local function SetUpDarkModeSetItem(button, dark_mode)
	SetUpTextStyle(button, dark_mode)
	button:SetBackground(RGBA(0, 0, 0, 0))
	if dark_mode and not button:GetEnabled() then
		button:SetToggledBackground(dark_mode and prop_button_disabled or l_propitem_selection)
		button:SetDisabledBackground(dark_mode and RGBA(0, 0, 0, 0) or l_prop_button_disabled)
	else
		button:SetFocusedBackground(dark_mode and prop_button_focused or l_prop_button_focused)
		button:SetPressedBackground(dark_mode and propitem_selection or l_propitem_selection)
		button:SetToggledBackground(dark_mode and propitem_selection or l_propitem_selection)
		button:SetDisabledBackground(dark_mode and prop_button_disabled or l_prop_button_disabled)
	end
end

local function SetUpIconButton(button, dark_mode)
	button.idIcon:SetImageColor(dark_mode and RGB(210, 210, 210) or button.parent.Id == "idNumberEditor" and RGB(0, 0, 0) or nil)
	button:SetBackground(RGBA(0, 0, 0, 1)) -- 1 is used as alpha because we don't touch control with color == 0
	if IsKindOf(button, "XCheckButton") then
		button:SetBorderColor(RGBA(0, 0, 0, 0))
		button:SetIconColor(dark_mode and checkbox_color or RGB(0, 0, 0))
		button:SetDisabledIconColor(checkbox_disabled_color)
	else
		button:SetRolloverBorderColor(dark_mode and button_border or l_button_border)
		button:SetRolloverBackground(dark_mode and button_rollover or l_button_rollover)
		button:SetPressedBackground(dark_mode and button_pressed_background or l_button_pressed_background)
		
		if IsKindOf(button, "XToggleButton") and button:GetToggledBackground() == button:GetDefaultPropertyValue("ToggledBackground") then
			button:SetToggledBackground(dark_mode and button_toggled_background or l_button_toggled_background)
		end
		
		-- Set border color if it hasn't been manually set
		local border_color = button:GetBorderColor()
		local other_mode_border_color = not dark_mode and button_border or l_button_border
		if border_color == button:GetDefaultPropertyValue("BorderColor") or border_color == other_mode_border_color then
			button:SetBorderColor(dark_mode and button_border or l_button_border)
		end
	end
end

---
--- Updates the dark mode settings for a control in the GedApp.
--- @param control table The control to update the dark mode settings for.
---
function GedApp:UpdateControlDarkMode(control)
	local dark_mode = self.dark_mode
	local new_style = GetTextStyleInMode(rawget(control, "TextStyle"), dark_mode)
	
	if IsKindOf(control, "XRolloverWindow") and IsKindOf(control[1], "XText") then
		control[1].invert_colors = true
	end
	if control.Id == "idPopupBackground" then
		control:SetBackground(dark_mode and RGB(54, 54, 54) or RGB(240, 240, 240))
	end
	if IsKindOf(control, "GedApp") then
		control:SetBackground(dark_mode and button_divider or nil)
	end
	if IsKindOf(control, "GedPropEditor") then
		control.SelectionBackground = dark_mode and panel_item_selection or l_panel_item_selection
	end
	if IsKindOf(control, "XList") then
		control:SetBorderColor(dark_mode and edit_box_border or l_edit_box_border)
		control:SetFocusedBorderColor(dark_mode and edit_box_border or l_edit_box_border)
		control:SetBackground(dark_mode and panel or l_panel)
		control:SetFocusedBackground(dark_mode and panel or l_panel)
	end
	if IsKindOf(control, "XListItem") then
		local prop_editor = GetParentOfKind(control, "GedPropEditor")
		if prop_editor and not IsKindOfClasses(prop_editor, "GedPropPrimitiveList", "GedPropEmbeddedObject") then
			control:SetSelectionBackground(dark_mode and propitem_selection or l_propitem_selection)
		else
			control:SetSelectionBackground(dark_mode and panel_item_selection or l_panel_item_selection)
		end
		control:SetFocusedBorderColor(dark_mode and panel_focused_border or l_panel_focused_border)
	end
	
	if IsKindOf(control, "XMenuBar") then
		control:SetBackground(dark_mode and menubar or l_menubar)
		for _, menu_item in ipairs(control) do
			SetUpTextStyle(menu_item.idLabel, dark_mode)
			menu_item:SetRolloverBackground(dark_mode and menu_selection or l_menu_selection)
			menu_item:SetPressedBackground(dark_mode and menu_selection or l_menu_selection)
		end
		return
	end
	if IsKindOf(control, "ShortcutEditor") then
		control:SetBackground(dark_mode and menubar or l_menubar)
		control:SetFocusedBackground(dark_mode and menubar or l_menubar)
		for _, win in ipairs(control.idContainer.idModifiers) do
			if IsKindOf(win, "XToggleButton") then
				SetUpDarkModeSetItem(win, dark_mode)
			end
		end
		return
	end
	if IsKindOf(control, "XPopup") then
		control:SetBackground(dark_mode and menubar or l_menubar)
		control:SetFocusedBackground(dark_mode and menubar or l_menubar)
		for _, entry in ipairs(control.idContainer) do
			if entry:IsKindOf("XButton") then
				entry:SetRolloverBackground(dark_mode and menu_selection or l_menu_selection)
			end
		end
		return
	end 
	if IsKindOf(control, "XToolBar") then
		control:SetBackground(dark_mode and toolbar or l_toolbar)
		for _, toolbar_item in ipairs(control) do
			-- divider line betweeen action buttons
			if not IsKindOf(toolbar_item, "XTextButton") and not IsKindOf(toolbar_item, "XToggleButton") then
				toolbar_item:SetBackground(dark_mode and button_divider or l_button_divider)
			else
				SetUpIconButton(toolbar_item, dark_mode)
			end
		end
		return
	end
	if IsKindOf(control, "GedPropSet") then
		self:UpdateChildrenDarkMode(control.idLabelHost)
		control.idContainer:SetBorderColor(dark_mode and edit_box_border or l_edit_box_border)
		for _, win in ipairs(control.idContainer) do
			if IsKindOf(win, "XToggleButton") then
				SetUpDarkModeSetItem(win, dark_mode)
			else 
				self:UpdateChildrenDarkMode(win)
			end
		end
		return
	end
	if IsKindOf(control, "GedPropScript") then
		control.idEditHost:SetBorderColor(dark_mode and edit_box_border or l_edit_box_border)
		return
	end
	if IsKindOf(control, "XCurveEditor") then
		control:SetCurveColor(dark_mode and l_scroll or nil)
		control:SetControlPointColor(dark_mode and l_scroll or nil)
		control:SetControlPointHoverColor(dark_mode and button_divider or nil)
		control:SetControlPointCaptureColor(dark_mode and scroll_background or nil)
		control:SetGridColor(dark_mode and scroll_background or nil)
		return
	end
	if IsKindOf(control, "GedPanelBase") then
		if control.Id == "idStatusBar" then
			control:SetBackground(dark_mode and panel_title or l_panel_title)
		else
			control:SetBackground(dark_mode and panel or l_panel)
		end
		if control:ResolveId("idTitleContainer") then
			control.idTitleContainer:SetBackground(dark_mode and panel_title or l_panel_title)
			control.idTitleContainer:ResolveId("idTitle"):SetTextStyle(new_style or GetTextStyleInMode(control.Embedded and "GedDefault" or "GedTitleSmall", dark_mode))
		end
		if control:ResolveId("idSearchResultsText") then
			control:ResolveId("idSearchResultsText"):SetTextStyle(GetTextStyleInMode("GedDefault", dark_mode))
		end
		for _, child_control in ipairs(control) do 
			if	child_control.Id == "idContainer" then
				if child_control:HasMember("TextStyle") then
					SetUpTextStyle(child_control, dark_mode)
				end
				if child_control:HasMember("FocusedBackground") then
					child_control:SetFocusedBackground(dark_mode and panel_child or l_panel_child)
				end
				if child_control:HasMember("SelectionBackground") then
					child_control:SetSelectionBackground(dark_mode and panel_item_selection or l_panel_item_selection)
					child_control:SetFocusedBorderColor(dark_mode and panel_focused_border or l_panel_focused_border)
				end
				child_control:SetBackground(dark_mode and panel_child or l_panel_child)
				
				if IsKindOfClasses(control, "GedPropPanel", "GedTreePanel") then
					local noProps = control.idContainer:ResolveId("idNoPropsToShow")
					if noProps then
						SetUpTextStyle(noProps, dark_mode)
					else
						control:SetFocusedBackground(dark_mode and panel or l_panel)
						local container = control.idContainer
						for _, prop_win in ipairs(container) do
							for _, prop_child in ipairs(prop_win) do
								if IsKindOf(prop_child, "XTextButton") then
									SetUpDarkModeButton(prop_child, dark_mode)
								else
									self:UpdateChildrenDarkMode(prop_child)
								end
							end
						end
						for _, control in ipairs(control.idTitleContainer) do
							if IsKindOf(control, "XTextButton") then
								SetUpIconButton(control, dark_mode)
							end
						end
					end
				elseif IsKindOf(control, "GedBreadcrumbPanel") then
					local container = control.idContainer
					for _, win in ipairs(container) do
						if IsKindOf(win, "XButton") then
							win:SetRolloverBackground(dark_mode and RGB(72, 72, 72) or l_button_rollover)
							SetUpTextStyle(win[1], dark_mode)
						end
					end
				elseif IsKindOf(control, "GedTextPanel") then
					control.idContainer:SetTextStyle(new_style or GetTextStyleInMode("GedTextPanel", dark_mode))
				else
					self:UpdateChildrenDarkMode(child_control)
				end	
			elseif child_control.Id == "idTitleContainer" then
				local search = control:ResolveId("idSearchContainer")
				search:SetBackground(RGBA(0, 0, 0, 0))
				search:SetBorderColor(dark_mode and panel_focused_border or l_panel_focused_border)
				
				local edit = control:ResolveId("idSearchEdit")
				self:UpdateEditControlDarkMode(edit, dark_mode)
				edit:SetTextStyle(new_style or GetTextStyleInMode("GedDefault", dark_mode))
				edit:SetBackground(dark_mode and edit_box_focused or l_edit_box_focused)
				edit:SetHintColor(dark_mode and RGBA(210, 210, 210, 128) or nil)
				
				SetUpIconButton(control:ResolveId("idToggleSearch"), dark_mode)
				SetUpIconButton(control:ResolveId("idCancelSearch"), dark_mode)
				SetUpDarkModeButton(control:ResolveId("idSearchHistory"), dark_mode)
				
				for _, tab_button in ipairs(control.idTabContainer) do
					tab_button:SetToggledBackground(dark_mode and panel or l_panel)
					tab_button:SetToggledBorderColor(dark_mode and panel or l_panel)
					tab_button:SetBackground(dark_mode and panel_background_tab or l_panel_background_tab)
					tab_button:SetPressedBackground(dark_mode and panel_rollovered_tab or l_panel_rollovered_tab)
					tab_button:SetRolloverBackground(dark_mode and panel_rollovered_tab or l_panel_rollovered_tab)
					tab_button:SetBorderColor(dark_mode and panel_title or l_panel_title)
					tab_button:SetRolloverBorderColor(dark_mode and panel_title or l_panel_title)
					tab_button:SetTextStyle(dark_mode and "GedButton" or "GedDefault")
				end
			elseif IsKindOf(child_control, "XSleekScroll") then
				child_control.idThumb:SetBackground(dark_mode and scroll or l_scroll)
				child_control:SetBackground(dark_mode and scroll_background or l_scroll_background)
			elseif child_control.Id ~= "idViewErrors" and child_control.Id ~= "idPauseResume" then
				self:UpdateChildrenDarkMode(child_control)
			end
		end
		return
	end

	if control.Id == "idPanelDockedButtons" then
		control:SetBackground(dark_mode and panel_title or l_panel_title)
		return
	end
	
	if IsKindOf(control, "XRangeScroll") then
		control:SetThumbBackground(dark_mode and scroll or l_scroll)
		control:SetThumbRolloverBackground(dark_mode and scroll_rollover or l_scroll_rollover)
		control:SetThumbPressedBackground(dark_mode and scroll_pressed or l_scroll_pressed)
		control.idThumbLeft:SetBackground(dark_mode and scroll or l_scroll)
		control.idThumbRight:SetBackground(dark_mode and scroll or l_scroll)
		control:SetScrollColor(dark_mode and scroll or l_scroll)
		control:SetBackground(dark_mode and scroll_background or l_scroll_background)
	end

	if IsKindOf(control, "XTextButton") then
		SetUpIconButton(control, dark_mode)
	end
	if IsKindOf(control, "XFontControl") then
		if control.Id == "idWarningText" then
			return
		end
		SetUpTextStyle(control, dark_mode)
	end	
	if IsKindOf(control, "XCombo") or IsKindOf(control, "XCheckButtonCombo") then
		control:SetBackground(dark_mode and edit_box or l_edit_box)
		control:SetFocusedBackground(dark_mode and edit_box or l_edit_box)
		control:SetBorderColor(dark_mode and edit_box_border or l_edit_box_border)
		control:SetFocusedBorderColor(dark_mode and edit_box_border or l_edit_box_border)
		if IsKindOf(control, "XCombo") and (control:GetListItemTemplate() == "XComboListItemDark" or control:GetListItemTemplate() == "XComboListItemLight") then
			control:SetListItemTemplate(dark_mode and "XComboListItemDark" or "XComboListItemLight")
			control.PopupBackground = dark_mode and panel or l_panel
		end
	end	
	if IsKindOf(control, "XComboButton") then
		SetUpDarkModeButton(control, dark_mode)
	end	
	if IsKindOf(control, "XScrollArea") and not IsKindOf(control, "XMultiLineEdit") and not IsKindOf(control, "XList") then
		control:SetBackground(dark_mode and panel or l_panel)
	end
	if IsKindOf(control, "XMultiLineEdit") then
		if GetParentOfKind(control, "GedMultiLinePanel") then
			control:SetTextStyle(new_style or GetTextStyleInMode("GedMultiLine", dark_mode))
		else
			control:SetTextStyle(new_style or GetTextStyleInMode("GedDefault", dark_mode))
			if control.parent.Id == "idEditHost" then
				control.parent:SetBorderColor(dark_mode and edit_box_border or l_edit_box_border)
			end
		end
		self:UpdateEditControlDarkMode(control, dark_mode)
	end
	if IsKindOf(control, "XEdit") then
		control:SetTextStyle(new_style or GetTextStyleInMode("GedDefault", dark_mode))
		self:UpdateEditControlDarkMode(control, dark_mode)
	end
	if IsKindOf(control, "XTextEditor") then
		control:SetHintColor(dark_mode and RGBA(210, 210, 210, 128) or nil)
	end
	if IsKindOf(control, "XSleekScroll") then
		control.idThumb:SetBackground(dark_mode and scroll or l_scroll)
		control:SetBackground(dark_mode and scroll_background or l_scroll_background)
	end
	if IsKindOf(control, "XToggleButton") and control.Id == "idInputListener" then
		control:SetPressedBackground(dark_mode and propitem_selection or l_propitem_selection)
		control:SetToggledBackground(dark_mode and propitem_selection or l_propitem_selection)
	end
end

function OnMsg.GedPropertyUpdated(property)
	if IsKindOf(property, "GedPropSet") then
		GetParentOfKind(property, "GedApp"):UpdateChildrenDarkMode(property)
	end
end


----- GedBindView

DefineClass.GedBindView = {
	__parents = { "XContextWindow" },
	Dock = "ignore",
	visible = false,
	properties = {
		{ category = "General", id = "BindView", editor = "text", default = "", },
		{ category = "General", id = "BindRoot", editor = "text", default = "", },
		{ category = "General", id = "BindField", editor = "text", default = "", },
		{ category = "General", id = "BindFunc", editor = "text", default = "", },
		{ category = "General", id = "ControlId", editor = "text", default = "", },
		{ category = "General", id = "GetBindParams", editor = "expression", params = "self, control", },
		{ category = "General", id = "OnViewChanged", editor = "func", params = "self, value, control", },
	},
	MinWidth = 0,
	MinHeight = 0,
}

---
--- Opens the GedBindView window.
---
--- @param self GedBindView The GedBindView instance.
--- @param ... any Additional arguments passed to XContextWindow.Open.
function GedBindView:Open(...)
	XContextWindow.Open(self, ...)
	self.app = GetParentOfKind(self.parent, "GedApp")
end
---
--- Unbinds the object associated with the GedBindView instance.
---
--- This function is called when the GedBindView is being closed or destroyed.
--- It ensures that any object bindings associated with the GedBindView are properly
--- removed from the application's connection object.
---
--- @param self GedBindView The GedBindView instance.
function GedBindView:Done()
	local connection = self.app and self.app.connection
	if connection then
		connection:UnbindObj(self.context .. "|" .. self.BindView)
	end
end


---
--- Gets the bind parameters for the specified control.
---
--- @param self GedBindView The GedBindView instance.
--- @param control any The control to get the bind parameters for.
--- @return any The bind parameters for the specified control.
function GedBindView:GetBindParams(control)
end

---
--- Updates the context and view for the GedBindView instance.
---
--- This function is called when the context or view associated with the GedBindView
--- instance has changed. It is responsible for updating the object bindings and
--- notifying the view of the changes.
---
--- @param self GedBindView The GedBindView instance.
--- @param context string The current context.
--- @param view string The current view.
function GedBindView:OnContextUpdate(context, view)
	self.app = self.app or GetParentOfKind(self.parent, "GedApp")
	local connection = self.app and self.app.connection
	if not connection then return end
	if not view and self.BindView ~= "" then -- obj changed
		local path = self.BindRoot == "" and context or self.BindRoot
		if self.BindField ~= "" then
			path = {path, self.BindField}
		end
		connection:BindObj(context .. "|" .. self.BindView, path, self.BindFunc ~= "" and self.BindFunc, self:GetBindParams(self:ResolveId(self.ControlId)))
	end
	if view == self.BindView or (self.BindView == "") then -- view changed
		local name = self.BindView ~= "" and context .. "|" .. self.BindView or context
		local value = connection.bound_objects[name]
		self:OnViewChanged(value, self:ResolveId(self.ControlId))
	end
end

---
--- This function is called when the view associated with the GedBindView instance has changed.
--- It is responsible for updating the view with the new value.
---
--- @param self GedBindView The GedBindView instance.
--- @param value any The new value for the view.
--- @param control any The control associated with the view.
function GedBindView:OnViewChanged(value, control)
end

---
--- Rebuilds the sub-item actions for a panel.
---
--- @param panel any The panel to rebuild the sub-item actions for.
--- @param actions_def table A table of action definitions.
--- @param default_submenu string The default submenu for new sub-item actions.
--- @param toolbar string The toolbar to add new sub-item actions to.
--- @param menubar string The menubar to add new sub-item actions to.
function RebuildSubItemsActions(panel, actions_def, default_submenu, toolbar, menubar)
	local host = GetActionsHost(panel)
	local actions = host:GetActions()
	for i = #(actions or ""), 1, -1 do
		local action = actions[i]
		if action.ActionId:starts_with("NewItemEntry_") or action.ActionId:starts_with("NewSubitemMenu_") then
			host:RemoveAction(action)
		end
	end
	
	if type(actions_def) == "table" and #actions_def > 0 then
		local submenus = {}
		for _, def in ipairs(actions_def) do
			local submenu = def.EditorSubmenu or default_submenu
			if submenu ~= "" then
				submenus[submenu] = true
				XAction:new({
					ActionId = "NewItemEntry_" .. def.Class,
					ActionMenubar = "NewSubitemMenu_" .. submenu,
					ActionToolbar = def.EditorIcon and toolbar,
					ActionIcon = def.EditorIcon,
					ActionName = def.EditorName or def.Class,
					ActionTranslate = false,
					ActionShortcut = def.EditorShortcut,
					OnActionParam = def.Class,
					OnAction = function(self, host, source)
						if panel:IsKindOf("GedTreePanel") then
							host:Op("GedOpTreeNewItemInContainer", panel.context, panel:GetSelection(), self.OnActionParam)
						else
							host:Op("GedOpListNewItem", panel.context, panel:GetSelection(), self.OnActionParam)
						end
					end,
				}, host)
			end
		end
		
		for submenu in sorted_pairs(submenus) do
			XAction:new({
				ActionId = "NewSubitemMenu_" .. submenu,
				ActionMenubar = menubar,
				ActionName = submenu,
				ActionTranslate = false,
				ActionSortKey = "2",
				OnActionEffect = "popup",
				ActionContexts = { "ContentPanelAction", "ContentRootPanelAction", "ContentChildPanelAction" },
			}, host)
		end
	end
end