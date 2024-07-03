----- XEditorPlacementHelper
--
-- Each placement helper defines a sub-mode of the default XSelectObjectsTool.
-- Leaf children of XEditorPlacementHelper define shortcust, icons, and rollover
-- descriptions, and are auto-displayed as buttons in the editor statusbar.
--
-- Placement helpers define the editor's behavior when objects are dragged upon
-- or after initial placement. Editor gizmos are also implemented as placement helpers.
--
-- The base class is abstract and only defines methods/members that need to be present.

DefineClass.XEditorPlacementHelper = {
	__parents = { "InitDone" },
	
	operation_started = false,
	local_cs = false,
	snap = false,
	
	HasLocalCSSetting = false,
	HasSnapSetting = false,
	InXPlaceObjectTool = false,
	InXSelectObjectsTool = false,
	AllowRotationAfterPlacement = false,
	UsesCodeRenderables = false,
	
	Title = "None",
	Description = false,
	ActionSortKey = "0",
	ActionIcon = "CommonAssets/UI/Editor/Tools/VertexNudge.tga", -- proxy icon for testing
	ActionShortcut = "",
	ActionShortcut2 = "",
}

--- Provides a description for the XEditorPlacementHelper.
---
--- The description is used to display information about the placement helper in the editor UI.
function XEditorPlacementHelper:GetDescription()
end

---
--- Checks if clicking on the given mouse position should start an object movement operation.
---
--- @param mouse_pos table The current mouse position.
--- @return boolean true if clicking on this position should start object movement, false otherwise.
function XEditorPlacementHelper:CheckStartOperation(mouse_pos)
	-- return true if clicking on this position should start object movement
end

---
--- Starts the object movement operation.
---
--- This function is called when the user clicks on a position that should start an object movement operation, as determined by the `CheckStartOperation` function.
---
--- @param mouse_pos table The current mouse position.
--- @param objects table The objects that are being moved.
function XEditorPlacementHelper:StartOperation(mouse_pos, objects)
	-- initialize and start the movement operation here; you can assume CheckStartOperation was called and returned true
	self.operation_started = true
end

---
--- Performs the object movement operation.
---
--- This function is called to execute the object movement operation that was started by the `StartOperation` function.
---
--- @param mouse_pos table The current mouse position.
--- @param objects table The objects that are being moved.
function XEditorPlacementHelper:PerformOperation(mouse_pos, objects)
	-- perform object movement here
end

---
--- Called when the movement operation ends.
---
function XEditorPlacementHelper:EndOperation(objects)
	-- called when the movement operation ends
	self.operation_started = false
end


----- XEditorGizmo, base class for editor gizmos

DefineClass.XEditorGizmo = {
	__parents = { "XEditorPlacementHelper", "Mesh" },
	
	InXSelectObjectsTool = true,
	UsesCodeRenderables = true,
	
	thickness = 75,
	opacity = 110,
	scale = 85,
	sensitivity = 100,
	update_thread = false,
}

---
--- Prevents the properties of the Mesh class from appearing in the tool settings.
---
--- This function is used to override the default behavior of the Mesh class, which would normally expose its properties in the tool settings. By returning an empty table, this function ensures that the Mesh class properties are not displayed in the tool settings.
---
--- @return table An empty table to prevent the Mesh class properties from appearing in the tool settings.
---
function XEditorGizmo:GetProperties()
	return empty_table -- prevent properties of the Mesh class from appearing in the tool settings
end

---
--- Initializes the XEditorGizmo and starts a real-time thread to update its properties and render it.
---
--- The update thread runs continuously while the XEditorGizmo is valid, updating the thickness, opacity, scale, and sensitivity properties from the XEditorSettings, and then calling the Render function to display the gizmo.
---
--- @
function XEditorGizmo:Init()
	self.update_thread = CreateRealTimeThread(function()
		while IsValid(self) do
			self.thickness = XEditorSettings:GetGizmoThickness()
			self.opacity = XEditorSettings:GetGizmoOpacity()
			self.scale = XEditorSettings:GetGizmoScale()
			self.sensitivity = XEditorSettings:GetGizmoSensitivity()
			self:Render()
			WaitNextFrame()
		end
	end)
end

---
--- Stops the real-time thread that updates the XEditorGizmo properties and rendering.
---
--- This function is called when the XEditorGizmo is no longer needed, and it deletes the update thread that was created in the `Init()` function. This ensures that the gizmo is properly cleaned up and stops consuming resources when it is no longer being used.
---
--- @return nil
---
function XEditorGizmo:Done()
	DeleteThread(self.update_thread)
end

---
--- Renders the XEditorGizmo.
---
--- This function is responsible for rendering the XEditorGizmo, which is a visual representation of the editor's placement and selection tools. It is called regularly by the update thread created in the `Init()` function to update the gizmo's appearance based on the current settings.
---
--- @return nil
---
function XEditorGizmo:Render()
end


----- XObjectPlacementHelper - sample implementation / base class, a helper that moves selected/placed objects

DefineClass.XObjectPlacementHelper = {
	__parents = { "XEditorPlacementHelper" },
	
	InXPlaceObjectTool = true,
	InXSelectObjectsTool = true,
	
	init_drag_position = false,
	init_move_positions = false,
	init_orientations = false,
}

---
--- Checks if an operation should be started when the user drags an already selected object.
---
--- This function is called to determine if an operation should be started when the user drags an object that is already selected in the editor. It checks if there is an object at the current cursor position, and if that object is currently selected.
---
--- @param mouse_pos table The current mouse position.
--- @return boolean true if an operation should be started, false otherwise.
---
function XObjectPlacementHelper:CheckStartOperation(mouse_pos)
	local obj = GetObjectAtCursor()
	return obj and editor.IsSelected(obj) -- start operation when we drag an already selected object
end

---
--- Starts an operation to move the specified objects.
---
--- This function is called when the user starts an operation to move one or more selected objects in the editor. It suspends pass edits for the edit operation, initializes the starting positions and orientations of the objects, and sets a flag to indicate that an operation has started.
---
--- @param mouse_pos table The current mouse position.
--- @param objects table A list of objects to be moved.
--- @return nil
---
function XObjectPlacementHelper:StartOperation(mouse_pos, objects)
	SuspendPassEditsForEditOp(objects)
	self:StartMoveObjects(mouse_pos, objects)
	self.operation_started = true
end

---
--- Performs the current operation on the specified objects.
---
--- This function is called to execute the current operation (e.g. moving objects) on the provided list of objects. It delegates the actual operation to the `MoveObjects` function, which can be overridden in derived classes to implement custom behavior.
---
--- @param mouse_pos table The current mouse position.
--- @param objects table A list of objects to perform the operation on.
--- @return nil
---
function XObjectPlacementHelper:PerformOperation(mouse_pos, objects)
	self:MoveObjects(mouse_pos, objects)
end

---
--- Ends the current operation on the specified objects.
---
--- This function is called when the user finishes an operation (e.g. moving objects) in the editor. It resets the state variables that were used to track the operation, and resumes pass edits for the edit operation.
---
--- @param objects table A list of objects that the operation was performed on.
--- @return nil
---
function XObjectPlacementHelper:EndOperation(objects)
	self.init_drag_position = false
	self.init_move_positions = false
	self.init_orientations = false
	self.operation_started = false
	ResumePassEditsForEditOp()
end

---
--- Initializes the starting positions and orientations of the objects to be moved.
---
--- This function is called when an operation to move one or more selected objects is started. It stores the initial positions and orientations of the objects in preparation for the move operation.
---
--- @param mouse_pos table The current mouse position.
--- @param objects table A list of objects to be moved.
--- @return nil
---
function XObjectPlacementHelper:StartMoveObjects(mouse_pos, objects)
	self.init_drag_position = GetTerrainCursor()
	self.init_move_positions = {}
	self.init_orientations = {}
	for i, o in ipairs(objects) do
		self.init_move_positions[i] = o:GetPos()
		self.init_orientations[i] = { o:GetOrientation() }
	end
end

---
--- Moves the specified objects by the difference between the current mouse position and the initial drag position.
---
--- This function is a sample implementation of the `MoveObjects` function, which can be overridden in derived classes to implement custom behavior for moving objects. It calculates the vector of movement based on the difference between the current mouse position and the initial drag position, and then applies that movement to each of the specified objects.
---
--- @param mouse_pos table The current mouse position.
--- @param objects table A list of objects to be moved.
--- @return nil
---
function XObjectPlacementHelper:MoveObjects(mouse_pos, objects)
	local vMove = (GetTerrainCursor() - self.init_drag_position):SetZ(0)
	for i, obj in ipairs(objects) do
		obj:SetPos(self.init_move_positions[i] + vMove)
	end
	Msg("EditorCallback", "EditorCallbackMove", objects)
end
function XObjectPlacementHelper:MoveObjects(mouse_pos, objects) -- override in your child class (this is a sample implementation)
	local vMove = (GetTerrainCursor() - self.init_drag_position):SetZ(0)
	for i, obj in ipairs(objects) do
		obj:SetPos(self.init_move_positions[i] + vMove)
	end
	Msg("EditorCallback", "EditorCallbackMove", objects)
end


----- XEditorPlacementHelperHost

local helper_classes
---
--- Generates a list of buttons for the editor's placement helper UI.
---
--- This function retrieves a list of all `XEditorPlacementHelper` classes, sorts them by their `ActionSortKey` property, and creates a list of buttons for the editor's placement helper UI. Each button represents a different placement helper class, and can be used to select that helper class for the current tool.
---
--- @param tool_class string The name of the tool class that the placement helper is associated with.
--- @return table A list of buttons to be displayed in the editor's placement helper UI.
---
function helpers_button_list(tool_class)
	if not helper_classes then
		helper_classes = ClassLeafDescendantsList("XEditorPlacementHelper")
		table.sort(helper_classes, function(a, b) return g_Classes[a].ActionSortKey < g_Classes[b].ActionSortKey end)
	end
	local buttons = {}
	for _, class_name in ipairs(helper_classes) do
		local class = g_Classes[class_name]
		if class.Title ~= "None" and class["In" .. tool_class] then
			table.insert(buttons, {
				toggle = true,
				func = function(self, root, prop_id, ged, param) self:SetHelperClass(param) end,
				is_toggled = function(self) return self:GetHelperClass() == class_name end,
				name = class_name,
				param = class_name,
				icon = class.ActionIcon,
				icon_scale = 100,
				rollover = class.Title .. (class.Description and ("\n\n" .. table.concat(class.Description, "\n\n")) or ""),
				-- not part of the button definition - used by the tools the helpers are present it
				shortcut = class.ActionShortcut,
				shortcut2 = class.ActionShortcut2,
			})
		end
	end
	return buttons
end

DefineClass.XEditorPlacementHelperHost = {
	__parents = { "InitDone", "XEditorToolSettings" },
	
	helper_class = false, -- define the default helper in your tool
	placement_helper = false,
	prop_cache = false,
	props_from_helper = false,
}

---
--- Initializes the placement helper for the XEditorPlacementHelperHost.
---
--- This function creates a new instance of the placement helper class specified by the `helper_class` property and assigns it to the `placement_helper` property of the XEditorPlacementHelperHost.
---
--- @param self XEditorPlacementHelperHost The XEditorPlacementHelperHost instance.
---
function XEditorPlacementHelperHost:Init()
	self.placement_helper = g_Classes[self.helper_class]:new()
end

---
--- Deletes the placement helper associated with the XEditorPlacementHelperHost.
---
--- This function is called when the XEditorPlacementHelperHost is done being used, and it deletes the placement helper instance that was created in the `Init()` function.
---
--- @param self XEditorPlacementHelperHost The XEditorPlacementHelperHost instance.
---
function XEditorPlacementHelperHost:Done()
	self.placement_helper:delete()
end

---
--- Returns the title of the placement helper associated with the XEditorPlacementHelperHost.
---
--- If the placement helper has a `Title` property, it is returned. Otherwise, the `ToolTitle` property of the XEditorPlacementHelperHost is returned.
---
--- @param self XEditorPlacementHelperHost The XEditorPlacementHelperHost instance.
--- @return string The title of the placement helper.
---
function XEditorPlacementHelperHost:GetToolTitle()
	return self.placement_helper.Title or self.ToolTitle
end

---
--- Returns the properties of the XEditorPlacementHelperHost, including any properties from the placement helper.
---
--- This function first checks if the `prop_cache` property is set. If not, it creates a new table of properties by copying the properties from the `InitDone` class and the placement helper. It also sets the `props_from_helper` property to keep track of which properties come from the placement helper.
---
--- @param self XEditorPlacementHelperHost The XEditorPlacementHelperHost instance.
--- @return table The properties of the XEditorPlacementHelperHost.
---
function XEditorPlacementHelperHost:GetProperties()
	if not self.prop_cache then
		-- append the placement helper properties after ours
		local props = {}
		for _, prop_meta in ipairs(InitDone.GetProperties(self)) do
			props[#props + 1] = table.copy(prop_meta)
		end
		self.props_from_helper = {}
		for _, prop_meta in ipairs(self.placement_helper and self.placement_helper:GetProperties()) do
			self.props_from_helper[prop_meta.id] = true
			props[#props + 1] = table.copy(prop_meta)
		end
		self.prop_cache = props
	end
	return self.prop_cache
end

---
--- Gets the value of the specified property.
---
--- If the property is defined in the placement helper, its value is returned. Otherwise, the value of the property on the `XEditorPlacementHelperHost` instance is returned.
---
--- @param self XEditorPlacementHelperHost The XEditorPlacementHelperHost instance.
--- @param prop string The name of the property to get.
--- @return any The value of the specified property.
---
function XEditorPlacementHelperHost:GetProperty(prop)
	if self.props_from_helper and self.props_from_helper[prop] then
		return self.placement_helper:GetProperty(prop)
	end
	return PropertyObject.GetProperty(self, prop)
end

---
--- Sets the value of the specified property.
---
--- If the property is defined in the placement helper, its value is set on the placement helper. Otherwise, the value of the property on the `XEditorPlacementHelperHost` instance is set.
---
--- @param self XEditorPlacementHelperHost The XEditorPlacementHelperHost instance.
--- @param prop string The name of the property to set.
--- @param value any The value to set the property to.
---
function XEditorPlacementHelperHost:SetProperty(prop, value)
	if self.props_from_helper and self.props_from_helper[prop] then
		self.placement_helper:SetProperty(prop, value)
		return
	end
	PropertyObject.SetProperty(self, prop, value)
end

---
--- Gets the helper class name associated with this XEditorPlacementHelperHost instance.
---
--- @param self XEditorPlacementHelperHost The XEditorPlacementHelperHost instance.
--- @return string The helper class name.
---
function XEditorPlacementHelperHost:GetHelperClass()
	return self.helper_class
end

---
--- Sets the helper class for the XEditorPlacementHelperHost instance.
---
--- This function sets the helper class for the XEditorPlacementHelperHost instance. It updates the `prop_cache`, `props_from_helper`, and `helper_class` properties, and creates a new instance of the specified helper class if the current instance is not of the same class.
---
--- It also updates the status bar actions and notifies the editor that the tool has changed.
---
--- @param self XEditorPlacementHelperHost The XEditorPlacementHelperHost instance.
--- @param class_name string The name of the helper class to set.
--- @param properties table (optional) The properties to pass to the new helper class instance.
---
function XEditorPlacementHelperHost:SetHelperClass(class_name, properties)
	self.prop_cache = nil
	self.props_from_helper = nil
	self.helper_class = class_name
	if not IsKindOf(self.placement_helper, class_name) then
		self.placement_helper:delete()
		self.placement_helper = g_Classes[class_name]:new(properties)
	end
	local statusbar = GetDialog("XEditorStatusbar")
	if statusbar then
		statusbar:ActionsUpdated()
	end
	self:UpdatePlacementHelper()
	ObjModified(self)
	Msg("EditorToolChanged", GetDialog("XEditor").Mode, self.helper_class)
end

---
--- Updates the placement helper associated with this XEditorPlacementHelperHost instance.
---
--- This function is responsible for updating the placement helper associated with the XEditorPlacementHelperHost instance. It is typically called when the helper class is changed or when the editor tool is updated.
---
--- @param self XEditorPlacementHelperHost The XEditorPlacementHelperHost instance.
---
function XEditorPlacementHelperHost:UpdatePlacementHelper()
end

---
--- Handles keyboard shortcuts for the XEditorPlacementHelperHost.
---
--- This function is called when a keyboard shortcut is triggered. It checks if the shortcut corresponds to a button in the helpers_button_list for the current class. If a matching button is found, it sets the helper class to the button's name. If the placement helper has an `OnShortcut` method, it calls that method as well.
---
--- @param self XEditorPlacementHelperHost The XEditorPlacementHelperHost instance.
--- @param shortcut string The keyboard shortcut that was triggered.
--- @param source string The source of the shortcut (e.g. "keyboard", "menu").
--- @param ... any Additional arguments passed with the shortcut.
--- @return string "break" if the shortcut was handled, nil otherwise.
---
function XEditorPlacementHelperHost:OnShortcut(shortcut, source, ...)
	local buttons = helpers_button_list(self.class)
	local button = table.find_value(buttons, "shortcut", shortcut) or table.find_value(buttons, "shortcut2", shortcut)
	if button then
		if self.placement_helper.operation_started then
			self.desktop:SetMouseCapture() -- stop current operation if one is in progress
		end
		self:SetHelperClass(button.name)
		return "break"
	end
	if self.placement_helper:HasMember("OnShortcut") then
		return self.placement_helper:OnShortcut(shortcut, source, ...)
	end
end

---
--- Handles mouse button down events for the XEditorPlacementHelperHost.
---
--- This function is called when a mouse button is pressed. It checks if the left mouse button was pressed, and if so, it calls the `CheckStartOperation` method of the `placement_helper` object. If the operation can be started, it suspends pass edits for the edit operation, calls the `StartOperation` method of the `placement_helper` object, and sets the mouse capture to the `desktop` object. If the operation cannot be started, the function returns "break" to indicate that the event has been handled.
---
--- @param self XEditorPlacementHelperHost The XEditorPlacementHelperHost instance.
--- @param pt table The position of the mouse cursor.
--- @param button string The mouse button that was pressed ("L", "R", or "M").
--- @return string "break" if the event was handled, nil otherwise.
---
function XEditorPlacementHelperHost:OnMouseButtonDown(pt, button)
	if button == "L" then
		local ret = self.placement_helper:CheckStartOperation(pt, "btn_pressed")
		if ret == "break" then
			return "break"
		elseif ret then
			SuspendPassEditsForEditOp()
			self.placement_helper:StartOperation(pt, editor.GetSel())
			self.desktop:SetMouseCapture(self)
			return "break"
		end
	end
end

---
--- Handles mouse position events for the XEditorPlacementHelperHost.
---
--- This function is called when the mouse position changes. If the placement helper operation has started, it calls the `PerformOperation` method of the `placement_helper` object with the current mouse position and the current selection, and returns "break" to indicate that the event has been handled.
---
--- @param self XEditorPlacementHelperHost The XEditorPlacementHelperHost instance.
--- @param pt table The position of the mouse cursor.
--- @return string "break" if the event was handled, nil otherwise.
---
function XEditorPlacementHelperHost:OnMousePos(pt)
	if self.placement_helper.operation_started then
		self.placement_helper:PerformOperation(pt, editor.GetSel())
		return "break"
	end
end

---
--- Handles mouse button up events for the XEditorPlacementHelperHost.
---
--- This function is called when a mouse button is released. If the placement helper operation has started, it sets the mouse capture back to the desktop and returns "break" to indicate that the event has been handled.
---
--- @param self XEditorPlacementHelperHost The XEditorPlacementHelperHost instance.
--- @param pt table The position of the mouse cursor.
--- @param button string The mouse button that was released ("L", "R", or "M").
--- @return string "break" if the event was handled, nil otherwise.
---
function XEditorPlacementHelperHost:OnMouseButtonUp(pt, button)
	if self.placement_helper.operation_started then
		self.desktop:SetMouseCapture()
		return "break"
	end
end

---
--- Handles the loss of mouse capture for the XEditorPlacementHelperHost.
---
--- This function is called when the mouse capture is lost. If the placement helper operation has started, it calls the `EndOperation` method of the `placement_helper` object with the current selection, and resumes pass edits for the edit operation.
---
--- @param self XEditorPlacementHelperHost The XEditorPlacementHelperHost instance.
---
function XEditorPlacementHelperHost:OnCaptureLost()
	if self.placement_helper.operation_started then
		self.placement_helper:EndOperation(editor.GetSel())
		ResumePassEditsForEditOp()
	end
end
