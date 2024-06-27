---
--- Opens the X Window Inspector application and selects the window under the mouse cursor.
---
--- @param context table The context to use when opening the GedApp.
---
function OpenXWindowInspector(context)
	PauseLuaThreads("XWindowInspector")
	CreateRealTimeThread(function()
		local target = terminal.desktop:GetMouseTarget(terminal.GetMousePos()) or terminal.desktop
		local gedTarget = GetParentOfKind(target, "GedApp")
		if gedTarget then
			context.dark_mode = gedTarget.dark_mode
		end
		local ged = OpenGedApp("XWindowInspector", terminal.desktop, context)
		if ged then
			GedXWindowInspectorSelectWindow(ged, target)
		else
			ResumeLuaThreads("XWindowInspector")
		end
	end)
end

function OnMsg.LuaThreadsPaused()
	ObjModified(terminal.desktop) -- updates the status text, which is bound with context "root" (which happens to be the desktop)
end

---
--- Returns the status of whether Lua threads are currently paused or running.
---
--- @return string The status of Lua threads, either "Lua threads are PAUSED to freeze the UI!" or "Threads currently running..."
---
function GedThreadsPausedStatus()
	return AreLuaThreadsPaused() and "<style GedError>Lua threads are PAUSED to freeze the UI!" or "Threads currently running..."
end

---
--- Toggles the pause state of Lua threads.
---
--- If Lua threads are currently paused, this function will resume them. If there are still
--- other reasons for the threads to be paused, a warning message will be shown.
---
--- If Lua threads are currently running, this function will pause them.
---
--- @param ged GedApp The GedApp instance to show the warning message in.
---
function GedTogglePauseLuaThreads(ged)
	local was_paused = next(PauseLuaThreadsReasons)
	if was_paused then
		ResumeLuaThreads("XWindowInspector")
		local pause_reason = next(PauseLuaThreadsReasons)
		if pause_reason then
			ged:ShowMessage("Warning", string.format("Lua threads are still paused due to reason %s", pause_reason))
		end
	else
		PauseLuaThreads("XWindowInspector")
	end
end

if FirstLoad then
	GedXWindowInspectors = {}
	GedXWindowInspectorSelection = setmetatable({}, weak_keys_meta)
	GedXWindowInspectorTerminalTarget = false
end

---
--- Generates classes and functions related to the XWindow tree view.
---
--- The `XWindow.TreeView` class is defined, which provides a visual representation of the XWindow hierarchy.
--- The `XWindow.NodeColor` function sets the color of the node based on whether it has child nodes.
--- The `XWindow.PlacementText` function generates the text to be displayed for each node, including the template name, dock information, and debug template comment.
--- The `XWindow.OnEditorSelect` function is called when a node is selected in the editor, and updates the `GedXWindowInspectorSelection` table with the selected node.
---
function OnMsg.ClassesGenerate()
	assert(not (XWindow.TreeView or XWindow.PlacementText or XWindow.OnEditorSelect))
	XWindow.TreeView = T(408752573312, "<NodeColor><class> <color 128 128 128><Id><PlacementText>")
	XWindow.NodeColor = function(self)
		return self.IdNode and #self > 0 and "<color 75 105 198>" or ""
	end
	XWindow.PlacementText = function(self)
		local ret = { (self:GetProperty("Id") ~= "") and "" or nil }
		local dbg_template = rawget(self, "__dbg_template_template") or rawget(self, "__dbg_template")
		if dbg_template then
			ret[#ret+1] = "T: " .. dbg_template
		end
		local dock = self:GetProperty("Dock")
		if dock then
			ret[#ret+1] = "Dock: " .. dock
		end
		local dbg_template_comment = rawget(self, "__dbg_template_comment")
		if dbg_template_comment then
			ret[#ret+1] = "<color 0 128 0>" .. dbg_template_comment
		end
		return Untranslated(table.concat(ret, " "))
	end
	XWindow.OnEditorSelect = function(self, selected, ged)
		if selected then
			GedXWindowInspectorSelection[ged] = self
		end
	end
end

local function GedUpdateActionToggled(actionid, value)
	for k, socket in pairs(GedConnections) do
		if socket.app_template == "XWindowInspector" or socket.app_template == "GedParticleEditor" then
			socket:Send("rfnApp", "SetActionToggled", actionid, value)
		end
	end
end

local function GedUpdateInspectorActions(socket)
	socket:Send("rfnApp", "SetActionToggled", "FocusLogging", terminal.desktop.focus_logging_enabled)
	socket:Send("rfnApp", "SetActionToggled", "RolloverLogging", terminal.desktop.rollover_logging_enabled)
	socket:Send("rfnApp", "SetActionToggled", "ContextLogging", XContextUpdateLogging)
	socket:Send("rfnApp", "SetActionToggled", "RolloverMode", GedXWindowInspectorTerminalTarget and GedXWindowInspectorTerminalTarget.enabled)
end

function OnMsg.GedOpened(ged_id)
	local ged = GedConnections[ged_id]
	if ged and ged.app_template == "XWindowInspector" then
		table.insert(GedXWindowInspectors, ged)
	end
	if ged and (ged.app_template == "XWindowInspector" or ged.app_template == "GedParticleEditor") then
		GedUpdateInspectorActions(ged)
	end
end

---
--- Binds a Ged object to a global variable.
---
--- @param ged table The Ged object to bind.
--- @param path string The path to the object within the Ged.
--- @param global_name string The name of the global variable to bind the object to.
---
function GedRpcBindToGlobal(ged, path, global_name)
	local obj = ged:ResolveObj(path)
	rawset(_G, global_name, obj)
end

---
--- Handles the closing of a Ged window inspector.
---
--- When a Ged window inspector is closed, this function removes it from the list of active inspectors.
--- If there are no more active inspectors, it resumes any suspended Lua threads related to the window inspector.
---
--- @param ged_id string The ID of the Ged window inspector that was closed.
---
function OnMsg.GedClosing(ged_id)
	table.remove_entry(GedXWindowInspectors, "ged_id", ged_id)
	if not next(GedXWindowInspectors) then
		ResumeLuaThreads("XWindowInspector")
	end
end

---
--- Handles modifications to XWindow objects in the Ged window inspectors.
---
--- This function is called when an XWindow object is modified. It performs the following actions:
--- - Validates the selected windows in the Ged window inspectors and updates the selection if the modified object was previously selected.
--- - Closes any Ged window inspectors that have a deleted root object.
--- - For each Ged window inspector that has the modified window as its root, it creates a new thread to call the `ObjModified` function and update the selection.
---
--- @param win table The XWindow object that was modified.
--- @param child table The child XWindow object that was modified.
--- @param leaving boolean Indicates whether the child object is being removed from the window hierarchy.
---
function OnMsg.XWindowModified(win, child, leaving)
	if #GedXWindowInspectors == 0 then return end

	if leaving then
		-- validate selected windows
		for ged, selection in pairs(GedXWindowInspectorSelection) do
			if child == selection then
				GedXWindowInspectorSelection[ged] = win
			end
		end
		
		-- close inspectors with deleted root objects
		for _, inspector in ipairs(GedXWindowInspectors) do
			if child == inspector:ResolveObj("root") then
				inspector:Close()
			end
		end
	end

	repeat
		for _, inspector in ipairs(GedXWindowInspectors) do
			if win == inspector:ResolveObj("root") then
				-- go through a thread, so multiple changes to a XWindow only result in a single call
				if not win:IsThreadRunning("XWindowInspectorObjModified") then
					local ged, modified = inspector, win
					win:CreateThread("XWindowInspectorObjModified", function()
						ObjModified(modified)
						GedXWindowInspectorSelectWindow(ged, GedXWindowInspectorSelection[ged])
					end)
				end
			end
		end
		win = win.parent
	until not win
end

local function GetItemPath(root, control)
	local path = {}
	if not root or not control or not control:IsWithin(root) then
		return path
	end
	local target = control
	while target.parent and target ~= root do
		local idx = table.find(target.parent, target)
		table.insert(path, 1, idx)
		target = target.parent
	end
	return path
end

---
--- Selects a window in the GedXWindowInspector.
---
--- @param socket table The GedXWindowInspector instance.
--- @param win table The window to select.
function GedXWindowInspectorSelectWindow(socket, win)
	local root = socket:ResolveObj("root")
	if socket.selected_object ~= win then
		socket:SetSelection("root", GetItemPath(root, win))
		socket.selected_object = win
	end
end

---
--- Gets the path of an XWindow object in the terminal desktop.
---
--- @param obj table The XWindow object to get the path for.
--- @return table The path of the XWindow object, where each element is a table with the following fields:
---   - text: The text representation of the XWindow object.
---   - path: The path of the XWindow object, where each element is the index of the object in its parent's children table.
---
function GedGetXWindowPath(obj)
	local data = {}
	repeat
		table.insert(data, 1, {
			text = _InternalTranslate(XWindow.TreeView, obj, false),
			path = GetItemPath(terminal.desktop, obj),
		})
		obj = obj.parent
	until not obj
	return data
end

---
--- Defines a terminal target that enables a "rollover mode" for selecting windows in the GedXWindowInspector.
---
--- The rollover mode allows the user to hover over a window in the terminal desktop and have that window selected in the GedXWindowInspector.
---
--- @class RolloverModeTerminalTarget
--- @field enabled boolean Whether the rollover mode is currently enabled.
--- @field callback function The callback function to call when the rollover mode is used.
--- @field terminal_target_priority number The priority of this terminal target, set to a high value to ensure it is processed before other targets.
DefineClass.RolloverModeTerminalTarget = {
	__parents = { "TerminalTarget" },
	
	enabled = false,
	callback = false,
	terminal_target_priority = 20000000,
}

---
--- Handles mouse events for the rollover mode terminal target.
---
--- This function is called when the user interacts with the terminal desktop while the rollover mode is enabled. It processes mouse button down and move events, and calls the registered callback function with the appropriate status.
---
--- @param event string The type of mouse event that occurred ("OnMouseButtonDown" or "OnMouseMove").
--- @param pt table The coordinates of the mouse pointer.
--- @param button string The mouse button that was pressed ("L" for left, "R" for right).
--- @param time number The time the mouse event occurred.
--- @return string "break" to indicate the event has been handled, or "continue" to allow other targets to process the event.
function RolloverModeTerminalTarget:MouseEvent(event, pt, button, time)
	if not self.enabled then
		return "continue"
	end
	
	local target = terminal.desktop:GetMouseTarget(pt) or terminal.desktop
	if event == "OnMouseButtonDown" then
		self.enabled = false
		if button == "R" then
			self.callback(target, "cancel")
		else
			self.callback(target, "done")
		end
		GedUpdateActionToggled("RolloverMode", false)
	else
		self.callback(target, "update")
	end
	return "break"
end

---
--- Enables or disables the rollover mode for the RolloverModeTerminalTarget.
---
--- When the rollover mode is enabled, the callback function will be called with the current mouse target when the user interacts with the terminal desktop.
---
--- @param enabled boolean Whether to enable or disable the rollover mode.
--- @param callback function The callback function to call when the rollover mode is used. The callback will be called with the current mouse target and a status string ("cancel" or "done").
function RolloverModeTerminalTarget:EnableRolloverMode(enabled, callback)
	if self.callback and self.enabled then
		self.callback(false, "cancel")
	end
	self.enabled = enabled
	self.callback = callback
	GedUpdateActionToggled("RolloverMode", self.enabled)
end

local flashing_window = false
---
--- Enables or disables the rollover mode for the GedXWindowInspectorTerminalTarget.
---
--- When the rollover mode is enabled, the callback function will be called with the current mouse target when the user interacts with the terminal desktop.
---
--- @param enabled boolean Whether to enable or disable the rollover mode.
--- @param callback function The callback function to call when the rollover mode is used. The callback will be called with the current mouse target and a status string ("cancel" or "done").
function XRolloverMode(enabled, callback)
	if not GedXWindowInspectorTerminalTarget then
		GedXWindowInspectorTerminalTarget = RolloverModeTerminalTarget:new()
		terminal.AddTarget(GedXWindowInspectorTerminalTarget)
	end
	GedXWindowInspectorTerminalTarget:EnableRolloverMode(enabled, callback)
end

---
--- Enables or disables the rollover mode for the GedXWindowInspectorTerminalTarget.
---
--- When the rollover mode is enabled, the callback function will be called with the current mouse target when the user interacts with the terminal desktop.
---
--- @param socket table The socket object to use for resolving the selected window.
--- @param enabled boolean Whether to enable or disable the rollover mode.
function GedRpcRolloverMode(socket, enabled)
	local old_sel = socket:ResolveObj("SelectedWindow")
	XRolloverMode(enabled, function(window, status)
		if window then
			if status == "cancel" then
				GedXWindowInspectorSelectWindow(socket, old_sel)
			else
				GedXWindowInspectorSelectWindow(socket, window)
			end
		end
	end)
end

---
--- Enables a color picker rollover mode that allows the user to select a color by hovering over the desktop.
---
--- When the rollover mode is enabled, the callback function will be called with the current mouse target when the user interacts with the terminal desktop. The callback will request a pixel from the current mouse position and update the property of the selected object with the color of the pixel.
---
--- @param ged table The GED object to use for resolving the selected object.
--- @param name string The name of the object to update the color property for.
--- @param prop_id number The property ID of the color property to update.
function GedRpcColorPickerRollover(ged, name, prop_id)
	local obj = ged:ResolveObj(name)
	if not obj then return end

	local thread_status = "updating"
	CreateRealTimeThread(function()
		flashing_window = {
			BorderWidth = 2,
			BorderColor = RGB(200, 0, 0),
			Box = terminal.desktop.box,
			Thread = false,
		}
		UIL.Invalidate()

		SetPostProcPredicate("debug_color_pick", true)

		local old_value = obj:GetProperty(prop_id)
		while thread_status == "updating" do
			local pixel = ReturnPixel()
			if pixel and pixel ~= obj:GetProperty(prop_id) then
				obj:SetProperty(prop_id, pixel)
				ObjModified(obj)
			end
			Sleep(10)
		end
		if thread_status == "cancel" then
			obj:SetProperty(prop_id, old_value)
			ObjModified(obj)
		end

		SetPostProcPredicate("debug_color_pick", false)
		
		flashing_window = false
		UIL.Invalidate()
	end)
	XRolloverMode(true, function(window, status)
		if status == "done" then
			thread_status = "done"
		elseif status == "cancel" then
			thread_status = "cancel"
		else			
			local pos = terminal.GetMousePos()
			RequestPixel(pos:x(), pos:y())
		end
	end)
	terminal.BringToTop()
end

--- Sends a message to the remote application to set the selection to the currently focused window or the next focus candidate.
---
--- @param socket table The socket object used to communicate with the remote application.
function GedRpcInspectFocusedWindow(socket)
	local desktop = terminal.desktop
	local target = desktop:GetKeyboardFocus() or desktop:NextFocusCandidate()
	socket:Send("rfnApp", "SetSelection", "root", target and GetItemPath(socket:ResolveObj("root"), target))
end

--- Toggles the focus logging state for the terminal desktop.
---
--- @param socket table The socket object used to communicate with the remote application.
--- @param enabled boolean Whether to enable or disable focus logging.
function GedRpcToggleFocusLogging(socket, enabled)
	terminal.desktop.focus_logging_enabled = enabled
	GedUpdateActionToggled("FocusLogging", enabled)
end

--- Toggles the rollover logging state for the terminal desktop.
---
--- @param socket table The socket object used to communicate with the remote application.
--- @param enabled boolean Whether to enable or disable rollover logging.
function GedRpcToggleRolloverLogging(socket, enabled)
	terminal.desktop.rollover_logging_enabled = enabled
	GedUpdateActionToggled("RolloverLogging", enabled)
end

--- Toggles the context logging state for the terminal desktop.
---
--- @param socket table The socket object used to communicate with the remote application.
--- @param enabled boolean Whether to enable or disable context logging.
function GedRpcToggleContextLogging(socket, enabled)
	XContextUpdateLogging = enabled
	GedUpdateActionToggled("ContextLogging", enabled)
end

--- Flashes the window represented by the given object.
---
--- @param obj table The object representing the window to flash.
function XFlashWindow(obj)
	if not obj then return end
	if flashing_window then
		DeleteThread(flashing_window.Thread)
	end
	flashing_window = {
		BorderWidth = 1,
		BorderColor = RGB(0, 0, 0),
		Box = box(0, 0, 0, 0),
		Thread = false,
	}
	flashing_window.Thread = CreateRealTimeThread(function()
		for i = 1, 5 do
			local target = obj.interaction_box or obj.box
			if obj.window_state == "destroying" or not target then
				break
			end
			flashing_window.Box = target
			flashing_window.BorderColor = RGB(255, 255, 255)
			UIL.Invalidate()
			Sleep(50)
			flashing_window.BorderColor = RGB(0, 0, 0)
			UIL.Invalidate()
			Sleep(50)
		end
		flashing_window = false
		UIL.Invalidate()
	end)
end

---
--- Flashes the window represented by the given object.
---
--- @param socket table The socket object used to communicate with the remote application.
--- @param obj_name string The name of the object representing the window to flash.
function GedRpcFlashWindow(socket, obj_name)
	local obj = socket:ResolveObj(obj_name)
	XFlashWindow(obj)
end

--- Opens the GedApp "XWindowInspector" for the given object.
---
--- @param socket table The socket object used to communicate with the remote application.
--- @param obj_name string The name of the object to inspect.
function GedRpcXWindowInspector(socket, obj_name)
	local obj = socket:ResolveObj(obj_name)
	CreateRealTimeThread(function()
		OpenGedApp("XWindowInspector", obj)
	end)
end

---
--- Draws a flashing border around the window represented by the `flashing_window` table.
---
--- This function is responsible for rendering the flashing border effect around a window. It checks if the `flashing_window` table is set, and if so, it draws a border rectangle using the `BorderWidth`, `BorderColor`, and `Box` properties of the `flashing_window` table.
---
--- @function GedXWindowInspectorFlashWindow
function GedXWindowInspectorFlashWindow()
	if flashing_window then
		local border_width = flashing_window.BorderWidth
		UIL.DrawBorderRect(flashing_window.Box, border_width, border_width, flashing_window.BorderColor, RGBA(0, 0, 0, 0))
	end
end

function OnMsg.Start()
	if Platform.desktop then
		UIL.Register("GedXWindowInspectorFlashWindow", XDesktop.terminal_target_priority + 1)
	end
end

