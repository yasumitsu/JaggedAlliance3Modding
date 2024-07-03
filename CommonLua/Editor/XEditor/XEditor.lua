SetupVarTable(editor, "editor.")

if FirstLoad then
	XEditorHideTexts = false
	XEditorOriginalHandleRand = HandleRand
end

XEditorHRSettings = { 
	ResolutionPercent = 100,
	EnablePreciseSelection = 1,
	ObjectCounter = 1,
	VerticesCounter = 1,
	TR_MaxChunksPerFrame=100000,
}

-- function for generating random handles (used by undo / map patches / map modding)
local handle_seed = AsyncRand()
---
--- Generates a new random handle using a seed value.
---
--- @param rand number The random value to use for generating the new handle.
--- @return number The new random handle.
function XEditorNewHandleRand(rand)
end

---
--- Gets the current seed value used for generating random handles.
---
--- @return number The current seed value.
function XEditorGetHandleSeed(seed)
end

---
--- Sets the seed value used for generating random handles.
---
--- @param seed number The new seed value to use.
function XEditorSetHandleSeed(seed)
end
function XEditorNewHandleRand(rand) rand, handle_seed = BraidRandom(handle_seed, rand) return rand end
function XEditorGetHandleSeed(seed) return handle_seed end
function XEditorSetHandleSeed(seed) handle_seed = seed end

---
--- Checks if the editor is currently active.
---
--- @return boolean True if the editor is active, false otherwise.
function IsEditorActive()
	return editor.Active
end

---
--- Activates the editor if it is not already active and the current map is not empty.
---
--- This function performs the following actions:
--- - Sets the `editor.Active` flag to `true`
--- - Pauses the update hash for the "Editor" context
--- - Executes any functions registered in the "GameEnteringEditor" message
--- - Opens the "XEditor" dialog
--- - Sets the `HandleRand` function to `XEditorNewHandleRand`
--- - Sends the "GameEnterEditor" message
--- - Suspends desync errors for the "Editor" context
---
--- @return nil
function EditorActivate()
	if Platform.editor and not editor.Active and GetMap() ~= "" then
		editor.Active = true
		NetPauseUpdateHash("Editor")
		local executeBeforeEnter = {}
		Msg("GameEnteringEditor", executeBeforeEnter)
		for _, fn in ipairs(executeBeforeEnter) do
			fn()
		end
		OpenDialog("XEditor")
		HandleRand = XEditorNewHandleRand
		Msg("GameEnterEditor")
		SuspendDesyncErrors("Editor")
	end
end

---
--- Deactivates the editor if it is currently active.
---
--- This function performs the following actions:
--- - Sets the `editor.Active` flag to `false`
--- - Executes any functions registered in the "GameExitEditor" message
--- - Sets the `HandleRand` function to `XEditorOriginalHandleRand`
--- - Closes the "XEditor" dialog
--- - Resumes the update hash for the "Editor" context
--- - Resumes desync errors for the "Editor" context
---
--- @return nil
function EditorDeactivate()
	if editor.Active then
		editor.Active = false
		local executeBeforeExit = {}
		Msg("GameExitEditor", executeBeforeExit)
		for _, fn in ipairs(executeBeforeExit) do
			fn()
		end
		HandleRand = XEditorOriginalHandleRand
		CloseDialog("XEditor")
		NetResumeUpdateHash("Editor")
		ResumeDesyncErrors("Editor")
	end
end

function OnMsg.ChangeMap(map)
	if map == "" then
		EditorDeactivate()
	end
end

if FirstLoad then
	CameraMaxZoomSpeed     = tonumber(hr.CameraMaxZoomSpeed)
	CameraMaxZoomSpeedSlow = tonumber(hr.CameraMaxZoomSpeedSlow)
	CameraMaxZoomSpeedFast = tonumber(hr.CameraMaxZoomSpeedFast)
end

function OnMsg.ChangeMapDone(map)
	if map == "" then return end
	
	local small_map_size = 1024 * guim
	local map_size = Max(terrain.GetMapSize())
	local coef = Max(map_size * 1.0 / small_map_size, 1.0)
	hr.CameraMaxZoomSpeed     = tostring(CameraMaxZoomSpeed     * coef)
	hr.CameraMaxZoomSpeedSlow = tostring(CameraMaxZoomSpeedSlow * coef)
	hr.CameraMaxZoomSpeedFast = tostring(CameraMaxZoomSpeedFast * coef)
end


----- XEditor (the main fullscreen transparent dialog for the map editor)
--
-- This dialog's mode is the name of the XEditorTool currently active and created as a child dialog

DefineClass.XEditor = {
	__parents = { "XDialog" },
	Dock = "box",
	InitialMode = "XEditorTool",
	ZOrder = -1,
	
	mode = false,
	mode_dialog = false,
	play_box = false,
	toolbar_context = false,
	help_popup = false,
}

--- Opens the XEditor dialog, which is the main fullscreen transparent dialog for the map editor.
---
--- This function initializes the editor mode, sets up the editor UI elements, and notifies editor objects of the editor entering.
--- It also sets the default tool to the XSelectObjectsTool and optionally shows the editor help text if it hasn't been shown before.
---
--- @param ... Additional arguments passed to the XDialog:Open method
function XEditor:Open(...)
	local size = terrain.GetMapSize()
	XChangeCameraTypeLayer:new({ CameraType = "cameraMax", CameraClampXY = size, CameraClampZ = 2 * size }, self)
	XPauseLayer:new({ togglePauseDialog = false, keep_sounds = true }, self)
	
	-- editor mode init
	XShortcutsSetMode("Editor", function() EditorDeactivate() end)
	XEditorHRSettings.EnableCloudsShadow = EditorSettings:GetCloudShadows() and 1 or 0
	table.change(hr, "Editor", XEditorHRSettings)
	SetSplitScreenEnabled(false, "Editor")
	ShowMouseCursor("Editor")
	
	self.toolbar_context = {
		filter_buttons = LocalStorage.FilteredCategories,
		roof_visuals_enabled = LocalStorage.FilteredCategories["Roofs"],
	}
	OpenDialog("XEditorToolbar", XShortcutsTarget, self.toolbar_context):SetVisible(EditorSettings:GetEditorToolbar())
	OpenDialog("XEditorStatusbar", XShortcutsTarget, self.toolbar_context)
	
	if EditorSettings:GetShowPlayArea() then
		self.play_box = PlaceTerrainBox(GetPlayBox(), nil, nil, nil, nil, "depth test")
	end
	
	-- open editor
	XDialog.Open(self, ...)
	CreateRealTimeThread(XEditorUpdateHiddenTexts)
	self:NotifyEditorObjects("EditorEnter")
	ShowConsole(false)
	
	if IsKindOf(XShortcutsTarget, "XDarkModeAwareDialog") then
		XShortcutsTarget:SetDarkMode(GetDarkModeSetting())
	end
	
	-- set up default tool
	self:SetMode("XSelectObjectsTool")
	editor.SetSel(SelectedObj and { SelectedObj } or Selection)
	
	-- open help the first time
	if not LocalStorage.editor_help_shown then
		self:ShowHelpText()
		LocalStorage.editor_help_shown = true
		SaveLocalStorage()
	end
end

---
--- This function is responsible for closing the XEditor and performing necessary cleanup tasks.
---
--- It performs the following actions:
--- - Sets the shortcut mode to "Game"
--- - Restores the HR settings to the default state
--- - Enables split-screen mode
--- - Hides the mouse cursor
--- - Closes the XEditorToolbar, XEditorStatusbar, and XEditorRoomTools dialogs
--- - Clears the editor selection
--- - Clears the status text on the XShortcutsTarget
--- - Deletes the map buttons
--- - Closes the help popup if it's open
--- - Destroys the play box if it's valid
--- - Notifies the editor objects that the editor is exiting
--- - Closes the XEditor dialog
---
--- @param ... Additional arguments passed to the XDialog:Close method
function XEditor:Close(...)
	-- editor mode deinit
	XShortcutsSetMode("Game")
	table.restore(hr, "Editor")
	SetSplitScreenEnabled(true, "Editor")
	HideMouseCursor("Editor")
	CloseDialog("XEditorToolbar")
	CloseDialog("XEditorStatusbar")
	CloseDialog("XEditorRoomTools")
	editor.ClearSel()
	XShortcutsTarget:SetStatusTextLeft("")
	XShortcutsTarget:SetStatusTextRight("")
	XEditorDeleteMapButtons()
	if self.help_popup and self.help_popup.window_state == "open" then
		self.help_popup:Close()
	end
	
	if IsValid(self.play_box) then
		DoneObject(self.play_box)
	end
	
	-- close editor
	self:NotifyEditorObjects("EditorExit")
	XDialog.Close(self, ...)
end

---
--- Notifies all editor objects in the map that the editor is exiting.
---
--- This function suspends pass edits, iterates through all editor objects in the map,
--- and calls the `method` function on each object that is not currently selected by the cursor.
--- After iterating through all objects, it resumes pass edits.
---
--- @param method string The name of the method to call on each editor object
function XEditor:NotifyEditorObjects(method)
	SuspendPassEdits("Editor")
	MapForEach(true, "EditorObject", function(obj)
		if not EditorCursorObjs[obj] then
			obj[method](obj)
		end
	end)
	ResumePassEdits("Editor")
end

---
--- Sets the editor mode and opens the corresponding mode dialog.
---
--- @param mode string The name of the editor mode to set.
--- @param context any Optional context parameter to pass to the mode dialog.
---
function XEditor:SetMode(mode, context)
	if mode == self.Mode and (context or false) == self.mode_param then return end
	if self.mode_dialog then
		self.mode_dialog:Close()
		XPopupMenu.ClosePopupMenus()
	end
	
	self:UpdateStatusText()
	
	assert(IsKindOf(g_Classes[mode], "XEditorTool"))
	self.mode_dialog = OpenDialog(mode, self, context)
	self.mode_param = context
	self.Mode = mode
	self:ActionsUpdated()
	GetDialog("XEditorToolbar"):ActionsUpdated()
	GetDialog("XEditorStatusbar"):ActionsUpdated()
	XEditorUpdateToolbars()
	if not self.mode_dialog.ToolKeepSelection then
		editor.ClearSel()
	end
	self.mode_dialog:SetFocus()
	
	Msg("EditorToolChanged", mode, IsKindOf(self.mode_dialog, "XEditorPlacementHelperHost") and self.mode_dialog.helper_class)
end

---
--- Updates the status text displayed in the editor.
---
--- The status text is displayed in the bottom left of the editor window and provides information about the current map being edited.
--- The status text includes the map's display name or ID, and may also include additional information about the map's modding status and any active map variations.
---
--- @param self XEditor The XEditor instance.
function XEditor:UpdateStatusText()
	local left_status = mapdata.ModMapPath and _InternalTranslate(mapdata.DisplayName, nil, false) or mapdata.id
	if config.ModdingToolsInUserMode then
		local extra_row =
			(not mapdata.ModMapPath and not editor.ModItem) and "<color 255 60 60>Original map - saving disabled!" or
			not editor.IsModdingEditor() and "<color 255 60 60>Editor not opened from a mod item - saving disabled!" or
			editor.ModItem:IsPacked() and "<color 255 60 60>The map's mod is not unpacked for editing - saving disabled!" or
				string.format("%s%s", editor.ModItem:GetEditorMessage(), Literal(editor.ModItem.mod.title)) -- a saveable mod map
		left_status = string.format("%s\n%s", left_status, extra_row)
	else
		left_status = left_status .. (mapdata.group ~= "Default" and " (" .. mapdata.group .. ")" or "")
		if EditedMapVariation then
			left_status = string.format("%s\n<style EditorMapVariation>Variation: %s", left_status, EditedMapVariation.id)
			if EditedMapVariation.save_in ~= "" then
				left_status = left_status .. string.format(" (%s)", EditedMapVariation.save_in)
			end
		end
	end	
	
	XShortcutsTarget:SetStatusTextLeft(left_status)
	XShortcutsTarget:SetStatusTextRight(string.format("Object details: %s (Ctrl-Alt-/)", EngineOptions.ObjectDetail))
	XEditorCreateMapButtons()
end

---
--- Shows a help popup with tips for using the map editor.
---
--- The help popup is displayed in the center of the screen and provides a brief overview of the camera controls and other basic editor functionality.
---
--- @param self XEditor The XEditor instance.
function XEditor:ShowHelpText()
	self.help_popup = CreateMessageBox(XShortcutsTarget,
		Untranslated("Welcome to the Map Editor!"),
		Untranslated([[Here are some short tips to get you started.

Camera controls:
  • <mouse_wheel_up> - zoom in/out
  • hold <middle_click> - pan the camera
  • hold Ctrl - faster movement
  • hold Alt - look around
  • hold Ctrl+Alt - rotate camera

Look through the editor tools on the left - for example, press N to place objects.

Use <right_click> to access object properties and actions.]]))
end


----- UI

---
--- Reloads the editor shortcuts and sets the sort keys for the "Editor Settings" and "Editor Help Text" actions.
---
--- This function is called in response to the `ShortcutsReloaded` message, which is likely triggered when the editor shortcuts are updated or reloaded.
---
--- The `XShortcutsTarget` is a global object that manages the editor's shortcut actions. This function sets the sort keys for the "Editor Settings" and "Editor Help Text" actions to ensure they are displayed in the desired order in the editor's shortcut UI.
---
--- @function OnMsg.ShortcutsReloaded
function OnMsg.ShortcutsReloaded()
	XShortcutsTarget:ActionById("E_EditorSettings"):SetActionSortKey("999998")
	XShortcutsTarget:ActionById("E_EditorHelpText"):SetActionSortKey("999999")
end

---
--- Called when the editor selection changes.
---
--- This function is called whenever the selection in the editor changes. It notifies the `XEditor` dialog that the toolbar context has been modified, which may trigger updates to the toolbar or other UI elements.
---
--- @function OnMsg.EditorSelectionChanged
function OnMsg.EditorSelectionChanged()
	local xeditor = GetDialog("XEditor")
	if xeditor then
		ObjModified(xeditor.toolbar_context)
	end
end

---
--- Called when the visibility of the dev menu changes.
---
--- This function is called when the visibility of the dev menu is toggled. It sets the visibility of the XEditorToolbar dialog based on the current editor settings.
---
--- @param visible boolean Whether the dev menu is now visible.
function OnMsg.DevMenuVisible(visible)
	local toolbar = GetDialog("XEditorToolbar")
	if toolbar then
		toolbar:SetVisible(visible and EditorSettings:GetEditorToolbar())
	end
end

function OnMsg.ChangeMapDone()
	if IsEditorActive() then
		local dlg = GetDialog("XEditor")
		dlg:NotifyEditorObjects("EditorEnter")
		dlg:UpdateStatusText()
		if not cameraMax.IsActive() then
			cameraMax.Activate()
		end
	end
end


----- Toggle code renderables on when a tool needs them

---
--- Called when the editor tool changes.
---
--- This function is called when the active tool in the editor is changed. It checks if the new tool or its helper class requires code renderables, and if so, enables the code renderables feature. It also sets a flag to indicate that the editor settings dialog has just been opened.
---
--- @param mode string The new editor tool mode.
--- @param helper_class string The helper class for the new editor tool, if any.
function OnMsg.EditorToolChanged(mode, helper_class)
	if g_Classes[mode].UsesCodeRenderables or helper_class and g_Classes[helper_class].UsesCodeRenderables then
		if hr.RenderCodeRenderables == 0 then
			hr.RenderCodeRenderables = 1
			local statusbar = GetDialog("XEditorStatusbar")
			if statusbar then
				statusbar:ActionsUpdated()
			end
			ExecuteWithStatusUI("Code renderables turned ON!", function() Sleep(2000) end)
		end
	end
	XEditorSettingsJustOpened = XEditorGetCurrentTool().FocusPropertyInSettings
end

---
--- Called when the editor selection changes.
---
--- This function is called when the active selection in the editor is changed. If the code renderables feature is currently disabled, it displays a message to the user suggesting they press Alt-Shift-R to show the selection.
---
--- @param sel table The new selection of editor objects.
function OnMsg.EditorSelectionChanged(sel)
	if hr.RenderCodeRenderables == 0 and #sel > 0 then
		ExecuteWithStatusUI("Code renderables are OFF!\n\nPress Alt-Shift-R to show selection.", function() Sleep(1000) end)
	end
end


----- Context menu

if FirstLoad then
	XEditorContextMenu = false
end

---
--- Opens the XEditor context menu at the specified position.
---
--- @param context table The context object for the context menu.
--- @param pos table The position to open the context menu at.
function XEditorOpenContextMenu(context, pos)
	XEditorContextMenu = XShortcutsTarget:OpenContextMenu(context, pos)
end

---
--- Checks if the XEditor context menu is currently open.
---
--- @return boolean true if the XEditor context menu is open, false otherwise
function XEditorIsContextMenuOpen()
	return XEditorContextMenu and XEditorContextMenu.window_state == "open"
end


----- Autosave

if FirstLoad then
	EditorAutosaveThread = false
	EditorAutosaveNextTime = false
end

---
--- Creates a real-time thread that periodically saves the current map.
---
--- This function creates a real-time thread that checks the autosave time setting and saves the current map at the specified interval. If the autosave time is set to 0 or the modding tools are in user mode, the thread is not created.
---
--- @return nil
function EditorCreateAutosaveThread()
	EditorDeleteAutosaveThread()
	EditorAutosaveThread = CreateRealTimeThread(function()
		if EditorSettings:GetAutosaveTime() == 0 or config.ModdingToolsInUserMode then return end
		EditorAutosaveNextTime = EditorAutosaveNextTime or now() + EditorSettings:GetAutosaveTime() * 60 * 1000
		while true do
			if EditorAutosaveNextTime > now() then
				Sleep(EditorAutosaveNextTime - now())
			end
			XEditorSaveMap()
			EditorAutosaveNextTime = now() + EditorSettings:GetAutosaveTime() * 60 * 1000
		end
	end)
end

---
--- Deletes the real-time thread that periodically saves the current map.
---
--- This function deletes the thread created by `EditorCreateAutosaveThread()`. It is typically called when the editor is exited or the modding tools are switched to user mode.
---
--- @return nil
function EditorDeleteAutosaveThread()
	DeleteThread(EditorAutosaveThread)
end

OnMsg.GameEnterEditor = EditorCreateAutosaveThread
OnMsg.GameExitEditor = EditorDeleteAutosaveThread


----- Globals

---
--- Returns the current tool being used in the XEditor.
---
--- @return table The current tool being used in the XEditor.
function XEditorGetCurrentTool()
	return GetDialog("XEditor") and GetDialog("XEditor").mode_dialog
end

---
--- Checks if the current tool being used in the XEditor is the default tool.
---
--- @return boolean true if the current tool is the default "XSelectObjectsTool", false otherwise
function XEditorIsDefaultTool()
	return GetDialogMode("XEditor") == "XSelectObjectsTool"
end

---
--- Sets the default tool in the XEditor.
---
--- This function sets the default "XSelectObjectsTool" as the current tool in the XEditor. If the current tool is already the default tool, it updates the toolbar and marks the current tool as modified.
---
--- @param helper_class table The helper class to be used with the default tool.
--- @param properties table The properties to be used with the helper class.
---
--- @return nil
function XEditorSetDefaultTool(helper_class, properties)
	XEditorShowCustomFilters = false
	if XEditorIsDefaultTool() then
		ObjModified(XEditorGetCurrentTool())
		XEditorUpdateToolbars()
	end
	SetDialogMode("XEditor", "XSelectObjectsTool")
	if helper_class then
		GetDialog("XEditor").mode_dialog:SetHelperClass(helper_class, properties)
	end
end

---
--- Removes the keyboard focus from any toolbars or status bars in the XEditor.
---
--- This function checks if the currently focused control is part of the XEditor toolbar or status bar. If so, it removes the keyboard focus from that control.
---
--- @return nil
function XEditorRemoveFocusFromToolbars()
	local focused_ctrl = terminal.desktop:GetKeyboardFocus()
	if focused_ctrl and (GetDialog(focused_ctrl) == GetDialog("XEditorToolbar") or GetDialog(focused_ctrl) == GetDialog("XEditorStatusbar")) then
		terminal.desktop:RemoveKeyboardFocus(focused_ctrl, true)
	end
end

---
--- Updates the toolbars in the XEditor.
---
--- This function is responsible for updating the toolbars in the XEditor. It creates a new thread that waits 200 milliseconds before marking the toolbar context as modified. This helps prevent the toolbars from being updated too often, for example, when the user is quickly clicking the mouse.
---
--- @return nil
function XEditorUpdateToolbars()
	local editor = GetDialog("XEditor")
	if editor then -- make sure toolbars aren't updated "too often", e.g. with quick mouse clicks
		editor:DeleteThread("toolbar_update")
		editor:CreateThread("toolbar_update", function()
			Sleep(200)
			ObjModified(editor.toolbar_context)
		end)
	end
end

---
--- Updates the status text in the XEditor.
---
--- This function is responsible for updating the status text in the XEditor. It retrieves the XEditor dialog and calls its `UpdateStatusText()` method to update the status text.
---
--- @return nil
function XEditorUpdateStatusText()
end
function XEditorUpdateStatusText() -- above the status bar
	local editor = GetDialog("XEditor")
	if editor then
		editor:UpdateStatusText()
	end
end

---
--- Saves the current map, with an optional backup and force save.
---
--- This function is responsible for saving the current map. It first waits for any ongoing map changes to complete, then executes the save operation with a status UI message. The save operation is performed by calling the `SaveMap()` function, with optional parameters to skip the backup and force the save.
---
--- @param skipBackup boolean (optional) If true, the backup of the map will be skipped.
--- @param force boolean (optional) If true, the map will be saved even if there are no changes.
--- @return nil
function XEditorSaveMap(skipBackup, force)
	WaitChangeMapDone()
	ExecuteWithStatusUI(
		EditedMapVariation and "Saving map variation..." or "Saving map...",
		function() SaveMap(skipBackup, force) end,
		"wait")
end

---
--- Gets the visible objects in the map.
---
--- This function retrieves the objects in the map that are currently visible within the editor's frame. It filters the objects based on the provided `filter_func` function, which can be used to further refine the selection of objects.
---
--- @param filter_func function (optional) A function that takes an object and returns a boolean indicating whether the object should be included in the result.
--- @return table An array of objects that are currently visible in the editor's frame and pass the optional filter function.
function XEditorGetVisibleObjects(filter_func)
	local frame = (GetFrameMark() / 1024 - 1) * 1024
	filter_func = filter_func or function() return true end
	return MapGet("map", "attached", false, nil, const.efVisible, function(x) return x:GetFrameMark() - frame > 0 and filter_func(x) end) or empty_table
end

local function ApproxDisplayColor(color)
	local r, g, b = GetRGB(color)
	local upper_bound = Max(100, Max(r, Max(g, b)))
	r = MulDivRound(r, 255, upper_bound)
	g = MulDivRound(g, 255, upper_bound)
	b = MulDivRound(b, 255, upper_bound)
	return RGB(r, g, b)
end

---
--- Gets a list of terrain texture items for the XEditor.
---
--- This function retrieves a list of terrain texture items, where each item contains the texture ID, a color modifier, and an image representing the texture. The items are sorted by the texture ID.
---
--- @return table An array of terrain texture items, where each item is a table with the following fields:
---   - text: The texture ID
---   - value: The texture ID
---   - color: The approximate display color of the texture, calculated using the color modifier
---   - image: The image representing the texture
function GetTerrainTexturesItems()
	local items = {}	
	for _, descr in pairs(TerrainTextures) do
		local image = GetTerrainImage(descr.basecolor)
		items[#items + 1] = {
			text = descr.id,
			value = descr.id,
			color = ApproxDisplayColor(descr.color_modifier),
			image = image,
		}
	end
	table.sortby_field(items, "value")
	return items
end

---
--- Gets the current dark mode setting for the XEditor.
---
--- This function returns the current dark mode setting for the XEditor. If the setting is "Follow system", it will return the system's dark mode setting. Otherwise, it will return true if the setting is not "Light".
---
--- @return boolean Whether the XEditor is currently in dark mode.
function GetDarkModeSetting()
	local setting = XEditorSettings:GetDarkMode()
	if setting == "Follow system" then
		return GetSystemDarkModeSetting()
	else
		return setting and setting ~= "Light"
	end
end

---
--- Determines whether the given object can be selected in the XEditor.
---
--- This function checks if the object can be selected based on various conditions, including:
--- - Whether the object is valid and can be selected by the editor
--- - Whether the object is an `EditorLineGuide` and the slab size is not defined
--- - Whether the object passes the custom filters set in the XSelectObjectsTool
--- - Whether the object passes the filters defined in the `XEditorFilters` module
---
--- @param obj any The object to check for selection
--- @return boolean Whether the object can be selected
function CanSelect(obj)
	if not obj or not editor.CanSelect(obj) then
		if not const.SlabSizeX or not IsKindOf(obj, "EditorLineGuide") then
			return false
		end
	end
	if XEditorShowCustomFilters then
		local filter_mode = XSelectObjectsTool:GetFilterMode()
		local objects = XSelectObjectsTool:GetFilterObjects() or empty_table
		local filtered = objects[XEditorPlaceId(obj)]
		if filter_mode == "On" and not filtered or filter_mode == "Negate" and filtered then
			return false
		end
	end
	return XEditorFilters:CanSelect(obj)
end

-- WARNING: This function should be kept VERY fast, it is called on every frame and mouse move in editor mode!
---
--- Gets the object at the current cursor position in the XEditor.
---
--- This function first checks if there are any already selected Decals or WaterObjs, and returns those with priority to allow editing them. If no such objects are found, it then gets the solid and transparent objects at the cursor position, and returns the one that can be selected. If no object can be selected, it uses the XEditorSettings:GetSmartSelection() setting to get the next object at the cursor position that can be selected. If still no object is found, it returns the next Decal or WaterObj at the cursor position that can be selected.
---
--- @return any The object at the current cursor position, or nil if no object can be selected.
function GetObjectAtCursor()
	-- return already selected Decals/WaterObjs with priority to allow editing them
	local sel = GetNextObjectAtScreenPos(function(o) return IsKindOfClasses(o, "Decal", "WaterObj") and editor.IsSelected(o) end, "topmost")
	if sel then return sel end
	
	local solid, transparent = GetPreciseCursorObj()
	local obj = (CanSelect(transparent) and transparent) or (CanSelect(solid) and solid)
	obj = obj or XEditorSettings:GetSmartSelection() and GetNextObjectAtScreenPos(CanSelect, "topmost")
	-- GetPreciseCursorObj never returns Decals/WaterObj; select those objects with lower priority if no other object was found
	return obj or GetNextObjectAtScreenPos(function(o) return IsKindOfClasses(o, "Decal", "WaterObj") and CanSelect(o) end, "topmost")
end

---
--- Checks if any of the given objects are instances of the `AlignedObj` class.
---
--- @param objs table A table of objects to check
--- @return boolean True if any of the objects are `AlignedObj` instances, false otherwise
function HasAlignedObjs(objs)
	for _, obj in ipairs(objs) do
		if obj:IsKindOf("AlignedObj") then
			return true
		end
	end
end

---
--- Snaps the position of the given object to the nearest grid position based on the specified delta.
---
--- If the object is an `AlignedObj`, it will call the `AlignObj` method on the object to align it to the new position.
--- If the object is not an `AlignedObj` and `by_slabs` is true, the delta will be snapped to the nearest slab size to preserve relative object distances.
--- Otherwise, the object's position will be set to the initial position plus the snapped delta.
---
--- @param obj EditorObject The object to snap the position of
--- @param initial_pos Vector3 The initial position of the object
--- @param delta Vector3 The delta to apply to the object's position
--- @param by_slabs boolean Whether to snap the delta by slab size
function XEditorSnapPos(obj, initial_pos, delta, by_slabs)
	if obj:IsKindOf("AlignedObj") then
		if obj.AlignObj ~= AlignedObj.AlignObj then -- editor should not assert when placing object that didn't implement AlignObj
			obj:AlignObj(initial_pos + delta)
		end
	elseif by_slabs then
		obj:SetPos(initial_pos + XEditorSettings:PosSnap(delta, "by_slabs")) -- snap the delta by slab to preserve relative object distances
	else
		obj:SetPos(XEditorSettings:PosSnap(initial_pos + delta))
	end
end

---
--- Sets the position, axis, and angle of the given object.
---
--- If the object is an `AlignedObj`, it will call the `AlignObj` method on the object to align it to the new position, axis, and angle.
--- Otherwise, it will set the object's position to the given position, and if an axis and angle are provided, it will set the object's axis and angle.
---
--- @param obj EditorObject The object to set the position, axis, and angle of
--- @param pos Vector3 The new position for the object
--- @param axis Vector3 The new axis for the object
--- @param angle number The new angle for the object
function XEditorSetPosAxisAngle(obj, pos, axis, angle)
	if obj:IsKindOf("AlignedObj") then
		obj:AlignObj(pos, angle, axis)
	else
		obj:SetPos(pos)
		if axis and angle then
			obj:SetAxisAngle(axis, angle)
		end
	end
end

local suspend_id = 1

---
--- Suspends the pass edits for the current edit operation.
---
--- This function is used to temporarily suspend the pass edits for the current edit operation, which is useful when making changes to a large number of objects. It saves the current state of the pass edits and the configuration, and increments the suspend ID. When the edits are resumed, the saved state is restored.
---
--- @param objs table|nil The objects to suspend the pass edits for. If not provided, the current selection is used.
function SuspendPassEditsForEditOp(objs)
	NetPauseUpdateHash("EditOp")
	table.change(config, "XEditor"..suspend_id, {
		PartialPassEdits = #(objs or editor.GetSel()) < 500,
	})
	SuspendPassEdits("XEditor"..suspend_id)
	suspend_id = suspend_id + 1
end

---
--- Resumes the pass edits for the current edit operation.
---
--- This function is used to resume the pass edits for the current edit operation after they have been temporarily suspended. It restores the saved state of the pass edits and the configuration, and decrements the suspend ID.
---
--- @param objs table|nil The objects to resume the pass edits for. If not provided, the current selection is used.
function ResumePassEditsForEditOp()
	suspend_id = suspend_id - 1
	ResumePassEdits("XEditor"..suspend_id, true)
	table.restore(config, "XEditor"..suspend_id, true)
	NetResumeUpdateHash("EditOp")
	assert(suspend_id >= 1)
end

---
--- Checks if the pass edits for the current edit operation are suspended.
---
--- This function returns true if the pass edits for the current edit operation have been suspended using the `SuspendPassEditsForEditOp` function, and false otherwise.
---
--- @return boolean True if the pass edits are suspended, false otherwise.
function ArePassEditsForEditOpSuspended()
	return suspend_id > 1
end
---
--- Generates a list of items for a combo box representing the groups that a set of objects belong to.
---
--- @param objects table The objects to generate the group items for.
--- @return table The list of combo box items representing the groups.
function XEditorGroupsComboItems(objects)
	-- ...
end

function XEditorGroupsComboItems(objects)
	local items = {}
	local read_only = #objects == 0
	local group_names = table.keys2(Groups or empty_table, "sorted")
	for _, name in ipairs(group_names) do
		local group = Groups[name]
		if next(group) then
			local in_group_count = #table.intersection(group, objects)
			items[#items + 1] = {
				id = name,
				value = not read_only and in_group_count == #objects and true or in_group_count > 0 and Undefined() or false,
				read_only = read_only,
			}
		end
	end
	return items
end

local cam_pos, cam_lookat, stored_sel

---
--- Shows or hides a set of objects in the editor.
---
--- If `show` is "select_permanently", the objects are selected and the camera is positioned to view them. If `show` is true, the objects are shown and the camera is positioned to view them. If `show` is false, the camera is restored to its previous position and the previous selection is restored.
---
--- @param objs table The objects to show or hide.
--- @param show string|boolean Whether to show the objects, hide them, or select them permanently.
function XEditorShowObjects(objs, show)
	if show == "select_permanently" then
		editor.ClearSel("dont_notify")
		editor.SetSel(objs)
		ViewObjects(objs)
		cam_pos, cam_lookat, stored_sel = nil, nil, nil
	elseif show then
		cam_pos, cam_lookat = GetCamera()
		stored_sel = editor.GetSel()
		editor.SetSel(objs, "dont_notify")
		ViewObjects(objs)
	elseif cam_pos then
		SetCamera(cam_pos, cam_lookat)
		editor.SetSel(stored_sel, "dont_notify")
	end
end

---
--- Updates the visibility of text objects in the editor based on the `XEditorHideTexts` flag.
---
--- For all text objects in the map, if the `hide_in_editor` flag is set, the object's visibility is toggled based on the value of `XEditorHideTexts`.
---
--- @param none
--- @return none
function XEditorUpdateHiddenTexts()
	for _, obj in ipairs(MapGet("map", "Text")) do
		if obj.hide_in_editor then
			obj:SetVisible(not XEditorHideTexts)
		end
	end
end

---
--- Allows the user to choose a map from a list and change the current map in the editor.
---
--- This function creates a real-time thread that displays a list of available maps (excluding old maps) in a window. The user can select a map from the list, and the function will then change the current map in the editor to the selected map.
---
--- @function XEditorChooseAndChangeMap
--- @return none
function XEditorChooseAndChangeMap()
	if IsMessageBoxOpen("XEditorChooseAndChangeMap") then return end
	CreateRealTimeThread(function()
		local caption = "Choose map:"
		local maps = table.ifilter(ListMaps(), function(idx, map) return not IsOldMap(map) end)
		table.insert(maps, 1, "")
		local parent_container = XWindow:new({}, terminal.desktop)
		parent_container:SetScaleModifier(point(1250, 1250))
		
		local map = WaitListChoice(parent_container, maps, caption, GetMapName(), nil, nil, "XEditorChooseAndChangeMap")
		if not map then return end
		
		DeveloperChangeMap(map)
	end)
end