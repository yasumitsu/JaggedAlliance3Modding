----- XEditorTool
-- Base class for all tools that supports:
--  1. Open/close tool setting using Ged (hosted in-game by default)
--  2. Restore focus back to the tool window when mouse leaves the settings
--  3. Context menu

DefineClass.XEditorTool = {
	__parents = { "XDialog", "XEditorToolSettings" },
	properties = {
		{ id = "DisplayInGame", editor = "bool", default = true, shared_setting = true, no_edit = true, },
	},
	HandleMouse = true,
	UsesCodeRenderables = false,
	
	-- refedine in child classes
	ToolTitle = "None",
	ToolSection = false,
	ToolKeepSelection = false, -- don't clear the selection when switching to this tool
	Description = false,
	ActionSortKey = "99",
	ActionIcon = false,
	ActionShortcut = false,
	ActionShortcut2 = false,
	FocusPropertyInSettings = false, -- text property to auto-focus in the settings, e.g. place object's Filter field
	FocusPropertySingleTime = false,
	PropertyTabs = false,
}

---
--- Sets the context for the XEditorTool instance.
---
--- The context is a table that contains key-value pairs representing properties of the tool.
--- This method iterates over the context table and sets the corresponding properties on the tool instance.
---
--- @param context table|nil The context table to set. If nil, an empty table is used.
---
function XEditorTool:SetContext(context)
	-- set tool class members via the context, e.g. ToolTitle
	for key, value in pairs(context or empty_table) do
		if self:HasMember(key) then
			self[key] = value
		end
	end
end

---
--- Handles the mouse button down event for the XEditorTool.
---
--- If the right mouse button is clicked and the camera is not locked, this function performs the following actions:
--- - If the current tool is not the default tool, it sets the default tool and returns "break" to stop further processing.
--- - If there is no selection, it selects the object under the cursor (if any).
--- - If the Ctrl key is pressed, it opens the context menu for the selected object(s).
--- - If there is a selection, it opens the GED game object editor for the selected object(s).
---
--- @param pos table The position of the mouse cursor.
--- @param button string The mouse button that was pressed.
--- @return string "break" if the event was handled, nil otherwise.
---
function XEditorTool:OnMouseButtonDown(pos, button)
	if not camera.IsLocked(1) and button == "R" then
		-- right-click closes every tool other than "Select Objects"
		if not XEditorIsDefaultTool() then
			XEditorSetDefaultTool()
			return "break"
		end
		
		-- select object under cursor ONLY if there is no selection (motivation - some objects are hard to select by clicking on them)
		if #editor.GetSel() == 0 then
			local obj = GetObjectAtCursor()
			if obj then
				editor.AddToSel(editor.SelectionPropagate({obj}))
			end
		end
		
		-- open object properties or display context menu
		local sel_count = #editor.GetSel()
		local open_context_menu = terminal.IsKeyPressed(const.vkControl) == (EditorSettings:GetCtrlRightClickOpens() == "ContextMenu")
		if open_context_menu then
			local context = "NoSelection"
			if sel_count == 1 then
				context = "SingleSelection"
			elseif sel_count > 1 then
				context = "MultipleSelection"
			end
			XEditorOpenContextMenu(context, pos)
		elseif sel_count > 0 then
			OpenGedGameObjectEditor(editor.GetSel())
		end
		return "break"
	end
end

---
--- Handles keyboard shortcuts for the XEditorTool.
---
--- If the "Escape" shortcut is pressed and the current tool is not the default tool, this function sets the default tool and returns "break" to stop further processing.
--- Otherwise, it calls the parent class's OnShortcut method.
---
--- @param shortcut string The keyboard shortcut that was pressed.
--- @param source table The source of the shortcut event.
--- @param ... any Additional arguments passed to the shortcut event.
--- @return string "break" if the event was handled, nil otherwise.
---
function XEditorTool:OnShortcut(shortcut, source, ...)
	if shortcut == "Escape" and not XEditorIsDefaultTool() then
		XEditorSetDefaultTool()
		return "break"
	end
	return XDialog.OnShortcut(self, shortcut, source, ...)
end


----- Editor settings panel update thread
-- 1. Opens/closes the GedApp for editing tool settings when necessary
-- 2. Reopens it when the DisplayInGame property changes
-- 3. Updates its root object when the editor tool changes
-- 4. Manages focus between the tool settings, the editor toolbar/statusbar, and the editor tool window

if FirstLoad then
	XEditorSettingsGed = false
	XEditorSettingsJustOpened = false
	XEditorSettingsUpdateThread = false
end

---
--- Starts a real-time thread that periodically updates the editor settings panel.
---
--- The thread checks if the current editor tool has any editable properties. If so, it opens the GedApp for editing the tool settings. If the tool's DisplayInGame property changes, the thread reopens the GedApp. It also updates the GedApp's root object when the editor tool changes.
---
--- The thread also manages the focus between the tool settings, the editor toolbar/statusbar, and the editor tool window.
---
--- This function is called when the GameEnterEditor message is received.
---
--- @return void
---
function OnMsg.GameEnterEditor()
	if not IsValidThread(XEditorSettingsUpdateThread) then
		XEditorSettingsUpdateThread = CreateRealTimeThread(function()
			while true do
				XEditorSettingsUpdate()
				Sleep(100)
			end
		end)
	end
end

local function editable_prop_count(class)
	local count = 0
	for _, prop in ipairs(class:GetProperties()) do
		if not prop_eval(prop.no_edit, class, prop) then
			count = count + 1
		end
	end
	return count
end

local function room_tools_visible(visible)
	local room_tools = GetDialog("XEditorRoomTools")
	if room_tools then
		room_tools:SetVisibleInstant(visible)
	end
end

---
--- Periodically updates the editor settings panel.
---
--- This function checks if the current editor tool has any editable properties. If so, it opens the GedApp for editing the tool settings. If the tool's DisplayInGame property changes, the function reopens the GedApp. It also updates the GedApp's root object when the editor tool changes.
---
--- The function also manages the focus between the tool settings, the editor toolbar/statusbar, and the editor tool window.
---
--- This function is called when the GameEnterEditor message is received.
---
--- @return void
---
function XEditorSettingsUpdate()
	local editor_tool = XEditorGetCurrentTool()
	
	local should_open = editor_tool and editable_prop_count(editor_tool) ~= 0
	if not XEditorSettingsGed and should_open then
		XEditorSettingsGed = OpenGedApp("XEditorToolSettingsPanel", editor_tool, nil, nil, editor_tool:GetDisplayInGame())
		room_tools_visible(not editor_tool:GetDisplayInGame())
	end
	
	if XEditorSettingsGed then
		if not should_open or editor_tool:GetDisplayInGame() ~= XEditorSettingsGed.context.in_game then
			local settings = XEditorSettingsGed
			XEditorSettingsGed = false
			CloseGedApp(settings, "wait")
			room_tools_visible(true)
		elseif XEditorSettingsGed:ResolveObj("root") ~= editor_tool then
			XEditorSettingsGed:BindObj("root", editor_tool)
		end
	end
	
	local desktop = terminal.desktop
	local focused_ctrl = desktop:GetKeyboardFocus()
	if desktop:GetMouseTarget(terminal.GetMousePos()) == editor_tool or XEditorSettingsJustOpened then
		if XEditorSettingsGed and XEditorSettingsGed.context.in_game then
			-- auto-focus a specified text field, e.g. the Filter text field for placing objects
			if editor_tool.FocusPropertyInSettings then
				local settings_dialog = GetDialog("XEditorToolSettingsPanel")
				local prop_editor = settings_dialog and settings_dialog.idPropPanel:LocateEditorById(editor_tool.FocusPropertyInSettings)
				if prop_editor and focused_ctrl ~= prop_editor.idEdit and (not editor_tool.FocusPropertySingleTime or XEditorSettingsJustOpened) then
					desktop:RemoveKeyboardFocus(settings_dialog, true)
					desktop:SetKeyboardFocus(prop_editor.idEdit)
				end
			else -- restore focus to XEditorTool when the mouse leaves the XEditorToolSettingsPanel window
				local focused_app = GetParentOfKind(focused_ctrl, "GedApp")
				if focused_app and focused_app.AppId == "XEditorToolSettingsPanel" then
					desktop:RemoveKeyboardFocus(focused_app, true)
				end
			end
		end
		
		XEditorRemoveFocusFromToolbars()
		XEditorSettingsJustOpened = false
	end
end

function OnMsg.GedClosing(id)
	-- settings closed out of game?
	if XEditorSettingsGed and GedConnections[id].app_template == "XEditorToolSettingsPanel" then
		local editor_tool = XEditorGetCurrentTool()
		if editor_tool then
			editor_tool:SetDisplayInGame(true)
		end
	end
end

---
--- Generates a description for the current XEditor tool.
---
--- @return string The description of the current XEditor tool.
---
function GedXEditorSettingsDescription()
	if XEditorIsDefaultTool() then return "" end
	local editor_tool = XEditorGetCurrentTool()
	local descr = editor_tool and editor_tool.Description
	descr = (type(descr) == "function") and descr(editor_tool) or descr
	descr = (type(descr) == "table") and descr or {descr}
	return descr and table.concat(descr, "\n\n") or ""
end


----- Toolbar

---
--- Handles the reloading of shortcuts for XEditor tools.
---
--- This function is called when the shortcuts are reloaded, and it creates new XAction objects for each XEditor tool and XEditor placement helper.
--- The XAction objects are added to the "XEditorToolbar" and "XEditorStatusbar" toolbars, respectively.
--- The XAction objects have various properties set, such as the tool title, shortcut, icon, and rollover text.
--- The XAction objects also have callbacks for toggling the active tool and handling the action of selecting a tool.
---
--- @return nil
---
function OnMsg.ShortcutsReloaded()
	local action_toolbar_section = "No Section"
	for _, class_name in ipairs(ClassLeafDescendantsList("XEditorTool")) do
		local tool = g_Classes[class_name]
		if tool.ActionIcon then
			local shortcut = tool.ActionShortcut and " (" .. tool.ActionShortcut .. ")" or ""
			local shortcut2 = tool.ActionShortcut2 and " (" .. tool.ActionShortcut2 .. ")" or ""
			local description = type(tool.Description) == "function" and tool.Description() or tool.Description
			local titleStyle = GetDarkModeSetting() and "<style XEditorRolloverBoldDark>" or "<style XEditorRolloverBold>"
			local rolloverText = titleStyle .. tool.ToolTitle .. shortcut .. shortcut2 .. "</style>\n" .. table.concat(description, "\n\n") 
			XAction:new({
				ActionId = tool.ToolTitle,
				ActionMode = "Editor",
				ActionName = tool.ToolTitle,
				ActionTranslate = false,
				ActionIcon = tool.ActionIcon,
				ActionShortcut = tool.ActionShortcut,
				ActionShortcut2 = tool.ActionShortcut2,
				ActionSortKey = tool.ActionSortKey,
				ActionToolbarSection = tool.ToolSection or action_toolbar_section,
				RolloverText = rolloverText,
				ActionToolbar = "XEditorToolbar",
				ActionToggle = true,
				ActionToggled = function(self, host)
					return GetDialogMode("XEditor") == class_name
				end,
				ActionState = tool.ToolActionState or empty_func,
				OnAction = function(self, host)
					if GetDialogMode("XEditor") ~= class_name then
						SetDialogMode("XEditor", class_name)
					end
				end,
			}, XShortcutsTarget)
		end
	end
	
	for _, class_name in ipairs(ClassLeafDescendantsList("XEditorPlacementHelper")) do
		local tool = g_Classes[class_name]
		if tool.Title ~= "None" and tool.ActionIcon then
			local shortcut = tool.ActionShortcut and " (" .. tool.ActionShortcut .. ")" or ""
			local rolloverText = "<style XEditorRolloverBold>" .. tool.Title .. "</style>"
			XAction:new({
				ActionId = tool.Title,
				ActionMode = "Editor",
				ActionName = tool.Title,  
				ActionIcon = tool.ActionIcon, 
				ActionShortcut = tool.ActionShortcut,
				ActionShortcut2 = tool.ActionShortcut2,
				ActionSortKey = tool.ActionSortKey,
				RolloverText = rolloverText,
				ActionToolbar = "XEditorStatusbar",
				ActionToggle = true,
				ActionToggled = function(self, host)
					local dialog = GetDialog("XSelectObjectsTool") or GetDialog("XPlaceObjectTool")
					return dialog and dialog:GetHelperClass() == class_name
				end,
				ActionState = function(self, host)
					if GetDialog("XSelectObjectsTool") and tool.InXSelectObjectsTool then return true
					elseif GetDialog("XPlaceObjectTool") and tool.InXPlaceObjectTool then return true end
					return "hidden"
				end,
				OnAction = function(self, host)
					local dialog = GetDialog("XSelectObjectsTool") or GetDialog("XPlaceObjectTool")
					if not dialog then
						SetDialogMode("XEditor", "XSelectObjectsTool")
						dialog = GetDialog("XSelectObjectsTool")
					end
					GetDialog(dialog.class):SetHelperClass(class_name)
				end,
			}, XShortcutsTarget)
		end
	end	
end
