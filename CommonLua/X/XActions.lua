--[[@@@
@class XAction
Defines a UI action, which can be bound to buttons or used on its own.
Always initialize it with a parent or if that is not possible, call RegisterInHost afterwards with the correct XActionsHost
]]
DefineClass.XAction = {
	__parents = { "XRollover" },
	properties = {
		{ category = "Action", id = "ActionId", editor = "text", default = "" },
		{ category = "Action", id = "ActionMode", editor = "text", default = "" },
		{ category = "Action", id = "InheritedActionModes", editor = "text", default = "", read_only = true, help = "ActionModes inherited from parent if ActionMode is empty", dont_save = true },
		{ category = "Action", id = "ActionSortKey", editor = "text", default = "",
		  buttons = { { name = "Rebuild", func = "RebuildSortKeys" } },
		},
		{ category = "Action", id = "ActionTranslate", editor = "bool", default = true, },
		{ category = "Action", id = "ActionName", editor = "text", default = "", translate = function(obj) return obj:GetProperty("ActionTranslate") end, },
		{ category = "Action", id = "ActionDescription", editor = "text", default = "", translate = function(obj) return obj:GetProperty("ActionTranslate") end, },
		{ category = "Action", id = "ActionIcon", editor = "ui_image", default = "", },
		{ category = "Action", id = "ActionMenubar", editor = "text", default = "", },
		{ category = "Action", id = "ActionToolbar", editor = "text", default = "" },
		{ category = "Action", id = "ActionToolbarSplit", editor = "bool", default = false },
		{ category = "Action", id = "ActionToolbarSection", editor = "text", default = "" },
		{ category = "Action", id = "ActionUIStyle", editor = "choice", default = "auto", items = {"auto", "gamepad", "keyboard"}, }, 
		{ category = "Action", id = "ActionShortcut", editor = "shortcut", default = "" },
		{ category = "Action", id = "ActionShortcut2", editor = "shortcut", default = "" },
		{ category = "Action", id = "ActionGamepad", editor = "shortcut", shortcut_type = "gamepad", default = "" },
		{ category = "Action", id = "ActionGamepadHold", editor = "bool", default = false },
		{ category = "Action", id = "ActionBindable", editor = "bool", default = false },
		{ category = "Action", id = "ActionMouseBindable", editor = "bool", default = true },
		{ category = "Action", id = "ActionBindSingleKey", editor = "bool", default = false },
		{ category = "Action", id = "BindingsMenuCategory", editor = "text", default = "Default" },
		{ category = "Action", id = "ActionButtonTemplate", editor = "choice", default = false, items = function() return XTemplateCombo("XButton") end, },
		{ category = "Action", id = "ActionToggle", editor = "bool", default = false },
		{ category = "Action", id = "ActionToggled", editor = "func", params = "self, host", read_only = function(self) return not self:GetProperty("ActionToggle") end, },
		{ category = "Action", id = "ActionToggledIcon", editor = "ui_image", default = "", read_only = function(self) return not self:GetProperty("ActionToggle") end, },
		{ category = "Action", id = "ActionState", editor = "func", params = "self, host" },
		{ category = "Action", id = "OnActionEffect", editor = "choice", default = "", items = {"", "popup", "back", "close", "mode"}, },
		{ category = "Action", id = "OnActionParam", editor = "text", default = "" },
		{ category = "Action", id = "OnAction", editor = "func", params = "self, host, source, ...", },
		{ category = "Action", id = "OnShortcutUp", editor = "func", params = "self, host, source, ...", default = false },
		{ category = "Action", id = "OnAltAction", editor = "func", params = "self, host, source, ...", default = false},
		{ category = "Action", id = "IgnoreRepeated", editor = "bool", default = false },
		{ category = "Action", id = "ActionContexts", editor = "string_list", default = false }, 
		
		{ category = "FX", id = "FXMouseIn", editor = "text", default = "", },
		{ category = "FX", id = "FXPress", editor = "text", default = "", },
		{ category = "FX", id = "FXPressDisabled", editor = "text", default = "", },
		
		-- properties of XRollover should regard ActionTranslate
		{ category = "Rollover", id = "RolloverTranslate", editor = false },
		{ category = "Rollover", id = "RolloverAnchor", editor = false },
		{ category = "Rollover", id = "RolloverText", editor = "text", default = "", translate = function(obj) return obj:GetProperty("ActionTranslate") end, lines = 3, },
		{ category = "Rollover", id = "RolloverDisabledText", editor = "text", default = "", translate = function(obj) return obj:GetProperty("ActionTranslate") end, lines = 3, },
	},
	
	-- the default values are needed when saving and loading from AccountStorage
	default_ActionShortcut = false,
	default_ActionShortcut2 = false,
	default_ActionGamepad = false,
	
	shortcut_up_thread = false,
	host = false,
	
	multi_mode_cache = false
}

---
--- Registers the `XAction` instance with the specified `host` and binds any configured shortcuts.
---
--- If the `host` is provided, it will call the `_InternalAddAction` method on the host to add the action.
--- The `BindShortcuts` method is then called to bind any configured shortcuts for the action.
---
--- If the `OnShortcutUp` callback is defined and the `OnAction` is not the default `XAction.OnAction`, a real-time thread is created to monitor for the shortcut key release and call the `OnShortcutUp` callback when the key is released.
---
--- @param host table The host to register the action with.
--- @param replace_matching_id boolean If true, the action will replace any existing action with the same ID in the host.
function XAction:RegisterInHost(host, replace_matching_id)
	self.host = host
	if host then host:_InternalAddAction(self, replace_matching_id) end
	self:BindShortcuts()
	
	if self.OnShortcutUp and host and self.OnAction ~= XAction.OnAction then
		local oldAction = self.OnAction
		self.OnAction = function(self, ...)
			oldAction(self, ...)
			
			local keyOne = self.ActionShortcut and VKStrNamesInverse[self.ActionShortcut]
			local keyTwo = self.ActionShortcut2 and VKStrNamesInverse[self.ActionShortcut2]
			local downKey = (keyOne and terminal.IsKeyPressed(keyOne) and keyOne) or (keyTwo and terminal.IsKeyPressed(keyTwo) and keyTwo)
			
			if IsValidThread(self.shortcut_up_thread) then
				DeleteThread(self.shortcut_up_thread)
			end
			self.shortcut_up_thread = CreateRealTimeThread(function(self, ...)
				while downKey and terminal.IsKeyPressed(downKey) and not terminal.desktop.inactive do
					Sleep(16)
				end
				self.OnShortcutUp(self, ...)
			end, self, ...)
		end
	end
end

---
--- Initializes the `XAction` instance and registers it with the specified host.
---
--- If a `replace_matching_id` parameter is provided, the action will replace any existing action with the same ID in the host.
---
--- @param parent table The parent object of the `XAction` instance.
--- @param context table The context object for the `XAction` instance.
--- @param replace_matching_id boolean If true, the action will replace any existing action with the same ID in the host.
function XAction:Init(parent, context, replace_matching_id)
	self:RegisterInHost(GetActionsHost(parent), replace_matching_id)
end

---
--- Binds any configured shortcuts for the `XAction` instance.
---
--- If the `ActionBindable` property is true, the function will attempt to load any saved shortcuts from the `AccountStorage.Shortcuts` table, using the `ActionId` property as the key. If any saved shortcuts are found, they will be set using the `SetActionShortcuts` method.
---
--- If no saved shortcuts are found, the function will use the default values stored in the `default_ActionShortcut`, `default_ActionShortcut2`, and `default_ActionGamepad` properties.
---
--- @function XAction:BindShortcuts
--- @return nil
function XAction:BindShortcuts()
	self.default_ActionShortcut = self.ActionShortcut
	self.default_ActionShortcut2 = self.ActionShortcut2
	self.default_ActionGamepad = self.ActionGamepad
	if self.ActionBindable then
		local bindings = AccountStorage and AccountStorage.Shortcuts[self.ActionId]
		if bindings then
			self:SetActionShortcuts(bindings[1] or self.ActionShortcut, bindings[2] or self.ActionShortcut2, bindings[3] or self.ActionGamepad)
		end
	end
end

local function RemoveShortcut(action, name, shortcut)
	shortcut = shortcut or ""
	local old_shortcut = action[name]
	if shortcut == old_shortcut then
		-- no change
		return
	end
	
	action[name] = nil
	local host = action.host
	if not host then return end
	
	-- unregister old shortcut
	host:CallHostParents("RemoveShortcutToAction", action, old_shortcut)
end

local function AddShortcut(action, name, shortcut)
	shortcut = shortcut or ""
	local old_shortcut = action[name]
	if shortcut == old_shortcut then
		-- no change
		return
	end
	
	action[name] = shortcut
	local host = action.host
	if not host then return end
	
	-- register new one
	host:CallHostParents("AddShortcutToAction", action, shortcut)
end

--- Sets the action shortcuts for the XAction.
---
--- This function removes any existing shortcuts and adds the new ones specified.
---
--- @param shortcut string The new shortcut for the primary action.
--- @param shortcut2 string The new shortcut for the secondary action.
--- @param shortcut_gamepad string The new shortcut for the gamepad action.
function XAction:SetActionShortcuts(shortcut, shortcut2, shortcut_gamepad)
	-- remove old shortcuts before adding any of the new ones
	RemoveShortcut(self, "ActionShortcut", shortcut)
	RemoveShortcut(self, "ActionShortcut2", shortcut2)
	RemoveShortcut(self, "ActionGamepad", shortcut_gamepad)
	-- add new shortcuts
	AddShortcut(self, "ActionShortcut", shortcut)
	AddShortcut(self, "ActionShortcut2", shortcut2)
	AddShortcut(self, "ActionGamepad", shortcut_gamepad)
end

--- Sets the action menubar for the XAction.
---
--- This function removes any existing menubar action and adds the new one specified.
---
--- @param menubar table The new menubar for the action.
function XAction:SetActionMenubar(menubar)
	local host = self.host
	if host and self.ActionMenubar ~= menubar then
		host:CallHostParents("RemoveMenubarAction", self)
	end
	self.ActionMenubar = menubar
	if not host then return end
	host:CallHostParents("AddMenubarAction", self)
end

--- Sets the action toolbar for the XAction.
---
--- This function removes any existing toolbar action and adds the new one specified.
---
--- @param toolbar table The new toolbar for the action.
function XAction:SetActionToolbar(toolbar)
	local host = self.host
	if host and self.ActionToolbar ~= toolbar then
		host:CallHostParents("RemoveToolbarAction", self)
	end
	self.ActionToolbar = toolbar
	if not host then return end
	host:CallHostParents("AddToolbarAction", self)
end

--- Sets the action sort key for the XAction.
---
--- This function sets the sort key for the action, which is used to determine the order of actions in menus and toolbars. If the action has a host, it will invalidate the action sort key on the host, causing the host to re-sort its actions.
---
--- @param sort_key string The new sort key for the action.
function XAction:SetActionSortKey(sort_key)
	self.ActionSortKey = sort_key
	if not self.host then return end
	self.host:InvalidateActionSortKey(self)
end

--- Handles the action state for the XAction.
---
--- This function is called when the action state changes, such as when the action is enabled or disabled. The host parameter is the object that owns the action.
---
--- @param host table The object that owns the action.
function XAction:ActionState(host)
end

--- Handles when the action is toggled.
---
--- This function is called when the action's state is toggled, such as when the action is enabled or disabled. The host parameter is the object that owns the action.
---
--- @param host table The object that owns the action.
function XAction:ActionToggled(host)
end

--- Handles the action when it is triggered.
---
--- This function is called when the action is triggered, such as when the user clicks on the action in a menu or toolbar. The function checks the `OnActionEffect` property of the action and performs the corresponding action, such as closing the host window, setting the mode of the host dialog, or opening a popup menu.
---
--- @param host table The object that owns the action.
--- @param source table The object that triggered the action.
--- @param ... any Additional parameters passed to the action.
function XAction:OnAction(host, source, ...)
	local effect = self.OnActionEffect
	local param = self.OnActionParam
	if effect == "close" and host and host.window_state ~= "destroying" then
		host:Close(param ~= "" and param or nil, source, ...)
	elseif effect == "mode" and host then
		assert(IsKindOf(host, "XDialog"))
		host:SetMode(param)
	elseif effect == "back" and host then
		assert(IsKindOf(host, "XDialog"))
		SetBackDialogMode(host)
	elseif effect == "popup" then
		local actions_view = GetParentOfKind(source, "XActionsView")
		if actions_view then
			actions_view:PopupAction(self.ActionId, host, source)
		else
			XShortcutsTarget:OpenPopupMenu(self.ActionId, terminal.GetMousePos())
		end
	else
		--print(self.ActionId, "activated")
	end
end

--- Handles property changes for the XAction.
---
--- This function is called when a property of the XAction is changed, such as the `ActionTranslate` or `ActionSortKey` properties. It updates the localized properties of the action, such as the `ActionName`, `RolloverText`, and `RolloverDisabledText`, when the `ActionTranslate` property is changed. It also sets the `RequireActionSortKeys` flag on the parent XTemplate when the `ActionSortKey` property is changed.
---
--- @param prop_id string The ID of the property that was changed.
--- @param old_value any The previous value of the property.
function XAction:OnXTemplateSetProperty(prop_id, old_value)
	-- toggle text properties between Ts and strings when ActionTranslate is edited
	if prop_id == "ActionTranslate" then
		self:UpdateLocalizedProperty("ActionName", self.ActionTranslate)
		self:UpdateLocalizedProperty("RolloverText", self.ActionTranslate)
		self:UpdateLocalizedProperty("RolloverDisabledText", self.ActionTranslate)
		ObjModified(self)
	end
	if prop_id == "ActionSortKey" and self.ActionSortKey ~= "" then
		local preset = GetParentTableOfKind(self, "XTemplate")
		preset.RequireActionSortKeys = true
	end
end

--- Checks if the action is enabled in the given mode.
---
--- This function checks if the action is enabled in the given mode. If the `ActionMode` property is empty, the action is always enabled. If the `ActionMode` property matches the given mode, the action is enabled. If the `ActionMode` property contains multiple modes, the function checks if the given mode is one of the modes in the `ActionMode` property.
---
--- @param mode string The mode to check if the action is enabled in.
--- @return boolean True if the action is enabled in the given mode, false otherwise.
function XAction:EnabledInMode(mode)
	local myMode = self.ActionMode
	if myMode == "" then return true end
	if mode == myMode then return true end

	if not self.multi_mode_cache or self.multi_mode_cache.strsrc ~= myMode then
		local modeCache = { strsrc = myMode }
		for str in string.gmatch(myMode, "([%w%-_]+)") do
			modeCache[str] = true
		end
		self.multi_mode_cache = modeCache
	end
	return self.multi_mode_cache[mode]
end

local function assign_sortkeys(node, sortkey)
	if node:IsKindOf("XTemplateAction") and node.ActionId ~= "" then
		if node.ActionSortKey ~= "" then
			print("Overwriting SortKey of", node.ActionId, "to", node.ActionSortKey)
		end
		node:SetActionSortKey(tostring(sortkey * 10))
		sortkey = sortkey + 1
	end
	for _, item in ipairs(node) do
		sortkey = assign_sortkeys(item, sortkey)
	end
	return sortkey
end

--- Rebuilds the sort keys for all actions in the given root node.
---
--- This function assigns sort keys to each action in the given root node, starting from 100 and incrementing by 10 for each action. This ensures that the actions are sorted in the order they appear, with numerical order coinciding with alphabetical order.
---
--- If the user cancels the operation, the function will return without making any changes.
---
--- @param root XTemplate The root node to rebuild the sort keys for.
--- @param prop_id string The property ID that triggered the rebuild.
--- @param ged GEDialog The GEDialog instance that triggered the rebuild.
--- @param btn_param any Any additional parameters passed from the button that triggered the rebuild.
function XAction:RebuildSortKeys(root, prop_id, ged, btn_param)
	if ged:WaitQuestion("Rebuild SortKeys", "This will assign SortKeys to each Action in the current file, in the order\nthey appear, overwriting existing ones.\n\nContinue?", "OK", "Cancel") ~= "ok" then
		return
	end
	assign_sortkeys(root, 100) -- start from 100 so that alphabetical order and numerical order coincide
	root.RequireActionSortKeys = true
	ObjModified(self)
	ObjModified(root)
end

----- XActionsHost

DefineClass.XActionsHost = {
	__parents = { "XContextWindow", "XHoldButton" },
	properties = {
		{ category = "Actions", id = "ActionsMode", editor = "text", default = "", },
		{ category = "Actions", id = "Translate", editor = "bool", default = false, },
		{ category = "Actions", id = "HostInParent", editor = "bool", default = false, },
	},
	actions = false,
	shortcut_to_actions = false,
	menubar_actions = false,
	toolbar_actions = false,
	action_hold_buttons = false,
	
	dirty_actions_order = false,
	dirty_menubars = false,
	dirty_toolbars = false,
	dirty_shortcuts = false,
}

--- Initializes the XActionsHost instance.
---
--- This function sets up the necessary data structures to manage actions, shortcuts, menubars, and toolbars. It also registers any actions that have already been created and added to the host.
---
--- @param self XActionsHost The XActionsHost instance being initialized.
function XActionsHost:Init()
	self.actions = self.actions or {}
	self.shortcut_to_actions = {}
	self.menubar_actions = {}
	self.toolbar_actions = {}
	self.dirty_menubars = {}
	self.dirty_toolbars = {}
	self.dirty_shortcuts = {}
	-- register already created actions in the host
	for _, action in ipairs(self.actions) do
		action:RegisterInHost(self)
	end
end

---
--- Clears all actions associated with this XActionsHost instance.
---
--- If the XActionsHost is hosted within a parent XActionsHost, this function will also remove the actions from the parent host.
--- 
--- This function clears the following data structures:
--- - `self.actions`: the list of actions associated with this host
--- - `self.shortcut_to_actions`: the mapping of shortcuts to actions
--- - `self.menubar_actions`: the list of actions associated with the menubar
--- - `self.toolbar_actions`: the list of actions associated with the toolbar
---
--- @param self XActionsHost The XActionsHost instance to clear the actions from.
function XActionsHost:ClearActions()
	if self.HostInParent then
		local host = GetActionsHost(self.parent)
		if host then
			for _, action in ipairs(host and self.actions) do
				host:RemoveAction(action)
			end
		end
	end
	table.clear(self.actions)
	table.clear(self.shortcut_to_actions)
	table.clear(self.menubar_actions)
	table.clear(self.toolbar_actions)
end

---
--- Clears all actions associated with this XActionsHost instance.
---
--- If the XActionsHost is hosted within a parent XActionsHost, this function will also remove the actions from the parent host.
--- 
--- This function clears the following data structures:
--- - `self.actions`: the list of actions associated with this host
--- - `self.shortcut_to_actions`: the mapping of shortcuts to actions
--- - `self.menubar_actions`: the list of actions associated with the menubar
--- - `self.toolbar_actions`: the list of actions associated with the toolbar
---
--- @param self XActionsHost The XActionsHost instance to clear the actions from.
function XActionsHost:Done()
	self:ClearActions()
end

---
--- Notifies the XActionsHost that the actions have been updated.
---
--- This function creates a new thread called "UpdateActionViews" that will update the views associated with the actions, such as the menubar and toolbar.
---
--- @param self XActionsHost The XActionsHost instance.
function XActionsHost:ActionsUpdated()
	if not self:GetThread("UpdateActionViews") then
		self:CreateThread("UpdateActionViews", self.UpdateActionViews, self, self)
	end
end

---
--- Sets the actions mode for this XActionsHost instance.
---
--- If the actions mode is changed, this function will call `XActionsHost:ActionsUpdated()` to notify the host that the actions have been updated.
---
--- @param self XActionsHost The XActionsHost instance.
--- @param mode string The new actions mode to set.
function XActionsHost:SetActionsMode(mode)
	if self.ActionsMode ~= mode then
		self.ActionsMode = mode
		self:ActionsUpdated()
	end
end

---
--- Marks the specified action as having an invalid sort key, triggering a re-sort of the relevant action lists.
---
--- This function sets the `dirty_actions_order` flag, indicating that the actions need to be re-sorted. It also sets the `dirty_menubars`, `dirty_toolbars`, and `dirty_shortcuts` flags for the relevant action lists, so that they will be re-sorted when their respective lists are accessed.
---
--- @param self XActionsHost The XActionsHost instance.
--- @param action table The action that has an invalid sort key.
function XActionsHost:InvalidateActionSortKey(action)
	self.dirty_actions_order = true
	if action.ActionMenubar ~= "" then
		self.dirty_menubars[action.ActionMenubar] = true
	end
	if action.ActionToolbar ~= "" then
		self.dirty_toolbars[action.ActionToolbar] = true
	end
	if action.ActionShortcut ~= "" then
		self.dirty_shortcuts[action.ActionShortcut] = true
	end
	if action.ActionShortcut2 ~= "" then
		self.dirty_shortcuts[action.ActionShortcut2] = true
	end
	if action.ActionGamepad ~= "" then
		self.dirty_shortcuts[action.ActionGamepad] = true
	end
end

local function sort_actions(actions)
	table.stable_sort(actions, function(a,b)
		return a.ActionSortKey < b.ActionSortKey
	end)
end

---
--- Gets the actions managed by this XActionsHost instance.
---
--- If the `dirty_actions_order` flag is set, this function will sort the actions based on their `ActionSortKey` values before returning them. This ensures that the actions are returned in the correct sorted order.
---
--- @param self XActionsHost The XActionsHost instance.
--- @return table The actions managed by this XActionsHost instance.
function XActionsHost:GetActions()
	if self.dirty_actions_order then
		sort_actions(self.actions)
		self.dirty_actions_order = nil
	end
	return self.actions
end

---
--- Gets the actions associated with the specified menubar.
---
--- If the `dirty_menubars` flag is set for the specified menubar, this function will sort the actions based on their `ActionSortKey` values before returning them. This ensures that the actions are returned in the correct sorted order.
---
--- @param self XActionsHost The XActionsHost instance.
--- @param menubar string The name of the menubar.
--- @return table The actions associated with the specified menubar.
function XActionsHost:GetMenubarActions(menubar)
	if self.dirty_menubars[menubar] then
		sort_actions(self.menubar_actions[menubar])
		self.dirty_menubars[menubar] = nil
	end
	return self.menubar_actions[menubar]
end

---
--- Gets the actions associated with the specified toolbar.
---
--- If the `dirty_toolbars` flag is set for the specified toolbar, this function will sort the actions based on their `ActionSortKey` values before returning them. This ensures that the actions are returned in the correct sorted order.
---
--- @param self XActionsHost The XActionsHost instance.
--- @param toolbar string The name of the toolbar.
--- @return table The actions associated with the specified toolbar.
function XActionsHost:GetToolbarActions(toolbar)
	if self.dirty_toolbars[toolbar] then
		sort_actions(self.toolbar_actions[toolbar])
		self.dirty_toolbars[toolbar] = nil
	end
	return self.toolbar_actions[toolbar]
end

---
--- Gets the actions associated with the specified shortcut.
---
--- If the `dirty_shortcuts` flag is set for the specified shortcut, this function will sort the actions based on their `ActionSortKey` values before returning them. This ensures that the actions are returned in the correct sorted order.
---
--- @param self XActionsHost The XActionsHost instance.
--- @param shortcut string The name of the shortcut.
--- @return table The actions associated with the specified shortcut.
function XActionsHost:GetShortcutActions(shortcut)
	if self.dirty_shortcuts[shortcut] then
		sort_actions(self.shortcut_to_actions[shortcut])
		self.dirty_shortcuts[shortcut] = nil
	end
	return self.shortcut_to_actions[shortcut]
end

---
--- Calls the specified function on the current XActionsHost instance, and then recursively calls the same function on any parent XActionsHost instances.
---
--- @param self XActionsHost The current XActionsHost instance.
--- @param func string The name of the function to call.
--- @param ... any Arguments to pass to the function.
---
function XActionsHost:CallHostParents(func, ...)
	self[func](self, ...)
	if self.HostInParent then
		local host = GetActionsHost(self.parent)
		if host then
			host:CallHostParents(func, ...)
			return
		end
	end
end

local function add_sorted(actions, action)
	actions = actions or {}
	local i = 1
	local key = action.ActionSortKey
	local skip_add
	while i <= #actions and actions[i].ActionSortKey <= key do
		if actions[i] == action then
			-- don't duplicate actions
			skip_add = true
			break
		end
		i = i + 1
	end
	if not skip_add then
		table.insert(actions, i, action)
	end
	return actions
end

--- Adds the specified action to the list of actions associated with the given shortcut.
---
--- If the shortcut is empty, this function does nothing.
---
--- The actions are sorted based on their `ActionSortKey` values to ensure they are returned in the correct order.
---
--- @param self XActionsHost The XActionsHost instance.
--- @param action table The action to add to the shortcut.
--- @param shortcut string The name of the shortcut to add the action to.
function XActionsHost:AddShortcutToAction(action, shortcut)
	if (shortcut or "") == "" then return end
	-- insert in list based on ActionSortKey
	self.shortcut_to_actions[shortcut] = add_sorted(self.shortcut_to_actions[shortcut], action)
end

---
--- Removes the specified action from the list of actions associated with the given shortcut.
---
--- If the shortcut is empty, this function does nothing.
---
--- @param self XActionsHost The XActionsHost instance.
--- @param action table The action to remove from the shortcut.
--- @param shortcut string The name of the shortcut to remove the action from.
function XActionsHost:RemoveShortcutToAction(action, shortcut)
	if (shortcut or "") == "" then return end
	local actions = self.shortcut_to_actions[shortcut]
	if not actions then return end
	table.remove_value(actions, action)
end

--- Adds the specified action to the list of actions associated with the given menubar.
---
--- If the menubar is empty, this function does nothing.
---
--- The actions are sorted based on their `ActionSortKey` values to ensure they are returned in the correct order.
---
--- @param self XActionsHost The XActionsHost instance.
--- @param action table The action to add to the menubar.
--- @param menubar string The name of the menubar to add the action to.
function XActionsHost:AddMenubarAction(action)
	local menubar = action.ActionMenubar
	if (menubar or "") == "" then return end
	self.menubar_actions[menubar] = add_sorted(self.menubar_actions[menubar], action)
end

---
--- Removes the specified action from the list of actions associated with the given menubar.
---
--- If the menubar is empty, this function does nothing.
---
--- @param self XActionsHost The XActionsHost instance.
--- @param action table The action to remove from the menubar.
function XActionsHost:RemoveMenubarAction(action)
	table.remove_entry(self.menubar_actions[action.ActionMenubar], action)
end

---
--- Adds the specified action to the list of actions associated with the given toolbar.
---
--- If the toolbar is empty, this function does nothing.
---
--- The actions are sorted based on their `ActionSortKey` values to ensure they are returned in the correct order.
---
--- @param self XActionsHost The XActionsHost instance.
--- @param action table The action to add to the toolbar.
function XActionsHost:AddToolbarAction(action)
	local toolbar = action.ActionToolbar
	if (toolbar or "") == "" then return end
	self.toolbar_actions[toolbar] = add_sorted(self.toolbar_actions[toolbar], action)
end

---
--- Removes the specified action from the list of actions associated with the given toolbar.
---
--- If the toolbar is empty, this function does nothing.
---
--- @param self XActionsHost The XActionsHost instance.
--- @param action table The action to remove from the toolbar.
---
function XActionsHost:RemoveToolbarAction(action)
	table.remove_entry(self.toolbar_actions[action.ActionToolbar], action)
end

---
--- Adds an action to the XActionsHost instance, maintaining the correct sorted order of actions.
---
--- If the action has a matching ID in the existing actions, the existing action will be replaced.
--- The action will be added to the appropriate menubar and toolbar mappings, and its shortcuts will be added.
--- If the XActionsHost instance has a parent host, the action will also be added to the parent host.
---
--- @param self XActionsHost The XActionsHost instance.
--- @param action table The action to add.
--- @param replace_matching_id boolean If true, any existing action with the same ID will be replaced.
function XActionsHost:_InternalAddAction(action, replace_matching_id)
	local actions = self.actions
	local key = action.ActionSortKey
	local old_idx = replace_matching_id and self:RemoveAction(self:ActionById(action.ActionId))
	-- is the new action still on a correct place at the old index?
	if old_idx and (old_idx == 1 or actions[old_idx - 1].ActionSortKey <= key) and
	  (old_idx > #actions or actions[old_idx].ActionSortKey >= key) then
		table.insert(actions, old_idx, action)
	else
		-- insert in list based on ActionSortKey
		add_sorted(actions, action)
	end
	
	-- add action to menubar and toolbar mappings
	self:AddMenubarAction(action)
	self:AddToolbarAction(action)
	
	-- add action to shortcuts mapping
	self:AddShortcutToAction(action, action.ActionShortcut)
	self:AddShortcutToAction(action, action.ActionShortcut2)
	self:AddShortcutToAction(action, action.ActionGamepad)
	
	if self.HostInParent then
		local host = GetActionsHost(self.parent)
		if host then
			host:_InternalAddAction(action, replace_matching_id)
			return
		end
	end
	self:ActionsUpdated()
	--assert(action.ActionName == "" or (IsT(action.ActionName) or false) == self.Translate)
end

---
--- Removes an action from the XActionsHost instance.
---
--- This function removes the specified action from the XActionsHost's actions list, and also removes it from the menubar, toolbar, and shortcuts mappings. If the XActionsHost has a parent host, the action will also be removed from the parent host.
---
--- @param self XActionsHost The XActionsHost instance.
--- @param action table The action to remove.
--- @return number The index of the removed action, or nil if the action was not found.
---
function XActionsHost:RemoveAction(action)
	if not action then return end
	local actions = self.actions
	local idx = table.remove_entry(self.actions, action)
	
	-- remove action from menubar and toolbar mappings
	self:RemoveMenubarAction(action)
	self:RemoveToolbarAction(action)
	
	-- remove action from shortcuts mapping
	self:RemoveShortcutToAction(action, action.ActionShortcut)
	self:RemoveShortcutToAction(action, action.ActionShortcut2)
	self:RemoveShortcutToAction(action, action.ActionGamepad)
	
	if self.HostInParent then
		local host = GetActionsHost(self.parent)
		if host then
			host:RemoveAction(action)
			return
		end
	end
	self:ActionsUpdated()
	return idx
end

---
--- Sets whether the XActionsHost instance is hosted within a parent XActionsHost.
---
--- When the XActionsHost is hosted within a parent, actions added to the child host will also be added to the parent host. Similarly, actions removed from the child host will also be removed from the parent host.
---
--- @param self XActionsHost The XActionsHost instance.
--- @param host_in_parent boolean Whether the XActionsHost is hosted within a parent.
---
function XActionsHost:SetHostInParent(host_in_parent)
	if self.HostInParent == host_in_parent then return end
	self.HostInParent = host_in_parent
	local host = GetActionsHost(self.parent)
	if host then
		for _, action in ipairs(self.actions) do
			if host_in_parent then
				host:_InternalAddAction(action)
			else
				host:RemoveAction(action)
			end
		end
	end
end

---
--- Performs a sanity check on the actions in the XActionsHost instance.
---
--- This function checks for conflicting action IDs and conflicting shortcuts between actions. It is intended for use during development to help identify issues with the action configuration.
---
--- @param self XActionsHost The XActionsHost instance.
---
function XActionsHost:ActionsSanityCheck()
	--[[local ids, shortcuts = {}, {}
	for _, action in ipairs(self.actions) do
		if action.ActionId ~= "" then
			assert(not ids[action.ActionId], string.format("Conflicting action Id %s", action.ActionId))
			ids[action.ActionId] = action
		end
		
		local mode = action.ActionMode
		if not shortcuts[mode] then
			shortcuts[mode] = {}
		end
		local mode_actions = shortcuts[mode]
		if action.ActionShortcut ~= "" then
			local other = mode_actions[action.ActionShortcut]
			assert(not other, string.format("Conflicting shortcut %s (between actions %s & %s)", action.ActionShortcut, other and other.ActionId or "", action.ActionId))
			mode_actions[action.ActionShortcut] = action
		end
		if action.ActionShortcut2 ~= "" then
			local other = mode_actions[action.ActionShortcut2]
			assert(not other, string.format("Conflicting shortcut %s (between actions %s & %s)", action.ActionShortcut2, other and other.ActionId or "", action.ActionId))
			mode_actions[action.ActionShortcut2] = action
		end
	end]]
end

---
--- Updates the action views for the given window and its children.
---
--- If the window is an `XActionsView`, it calls `OnUpdateActions()` on it.
--- If the window is not an `XActionsHost` or is hosted within a parent, it recursively calls `UpdateActionViews()` on the window's children.
---
--- @param self XActionsHost The `XActionsHost` instance.
--- @param win table|XActionsView The window or list of windows to update.
---
function XActionsHost:UpdateActionViews(win)
	if Platform.developer then
		self:ActionsSanityCheck()
	end
	for _, win in ipairs(win) do
		if IsKindOf(win, "XActionsView") then
			win:OnUpdateActions()
		end
		if not IsKindOf(win, "XActionsHost") or win.HostInParent then
			self:UpdateActionViews(win)
		end
	end
end

---
--- Shows or hides the action bar associated with the `XActionsHost` instance.
---
--- @param self XActionsHost The `XActionsHost` instance.
--- @param bShow boolean Whether to show or hide the action bar.
---
function XActionsHost:ShowActionBar(bShow)
	local action_bar = self:HasMember("idActionBar") and self.idActionBar
	if action_bar then
		action_bar:SetVisible(bShow)
	end
end

---
--- Determines if the given action should be filtered based on the current action context.
---
--- If no action context is provided, the function checks if the action is enabled in the current actions mode and is not in a "hidden" state.
---
--- If an action context is provided, the function checks if the action's contexts include the given context and the action is not in a "hidden" state.
---
--- @param self XActionsHost The `XActionsHost` instance.
--- @param action table The action to filter.
--- @param action_context string|nil The current action context (optional).
--- @return boolean True if the action should be filtered, false otherwise.
---
function XActionsHost:FilterAction(action, action_context)
	if not action_context then
		return action:EnabledInMode(self.ActionsMode) and self:ActionState(action) ~= "hidden"
	end
	
	for _, context in ipairs(action.ActionContexts) do
		if context == action_context and self:ActionState(action) ~= "hidden" then
			return true
		end
	end
	return false
end

---
--- Determines the action state based on the action's properties and the current state of the `XActionsHost` instance.
---
--- If the action has an "on action effect" of "popup" and the action's "on action" is the default `XAction.OnAction`, and the action has no associated menubar or toolbar actions, the function returns "hidden" to hide the menu entry.
---
--- Otherwise, the function returns the action's own `ActionState` value.
---
--- @param self XActionsHost The `XActionsHost` instance.
--- @param action table The action to check the state for.
--- @return string The action state, either "hidden" or the action's own state.
---
function XActionsHost:ActionState(action)
	local action_id = action.ActionId
	if action.OnActionEffect == "popup" and action.OnAction == XAction.OnAction and
	   not self:HasMenubarActions(action_id) and not self:HasToolbarActions(action_id) then
	   return "hidden" -- hide menu entries with no children actions, that would result in an empty popup
	end
	return action:ActionState(self)
end

---
--- Determines if the given action has any associated menubar actions.
---
--- @param self XActionsHost The `XActionsHost` instance.
--- @param action_id string The ID of the action to check.
--- @return boolean True if the action has associated menubar actions, false otherwise.
---
function XActionsHost:HasMenubarActions(action_id)
	return next(self.menubar_actions[action_id])
end

---
--- Determines if the given action has any associated toolbar actions.
---
--- @param self XActionsHost The `XActionsHost` instance.
--- @param action_id string The ID of the action to check.
--- @return boolean True if the action has associated toolbar actions, false otherwise.
---
function XActionsHost:HasToolbarActions(action_id)
	return next(self.toolbar_actions[action_id])
end

---
--- Handles the action when it is activated.
---
--- If the action has an associated FX press effect, it will be played. If the action has the `ActionToggle` property set, the `ActionsUpdated` event will be triggered.
--- Finally, a "XActionActivated" message will be sent with the action, controller, and any additional arguments.
---
--- @param self XActionsHost The `XActionsHost` instance.
--- @param action table The action that was activated.
--- @param ctrl table The controller that triggered the action (if any).
--- @param ... any Additional arguments passed to the action.
--- @return any The return value of the action's `OnAction` function.
---
function XActionsHost:OnAction(action, ctrl, ...)
	local hasFx = ctrl and ctrl.FXPress
	local ret = action:OnAction(self, ctrl, ...)
	if #(action.FXPress or "") ~= 0 and not hasFx then PlayFX(action.FXPress, "start", action) end
	if action.ActionToggle then
		self:ActionsUpdated()
	end
	Msg("XActionActivated", self, action, ctrl, ...)
	return ret
end

---
--- Retrieves the action with the specified ID.
---
--- @param self XActionsHost The `XActionsHost` instance.
--- @param id string The ID of the action to retrieve.
--- @return table|nil The action with the specified ID, or `nil` if not found.
---
function XActionsHost:ActionById(id)
	return table.find_value(self.actions, "ActionId", id)
end

---
--- Determines if the given action ID has a shortcut that matches the provided shortcut string.
---
--- @param self XActionsHost The `XActionsHost` instance.
--- @param id string The ID of the action to check.
--- @param shortcut string The shortcut string to check against the action.
--- @return boolean True if the action has a shortcut that matches the provided shortcut, false otherwise.
---
function XActionsHost:IsActionShortcut(id, shortcut)
	local action = self:ActionById(id)
	if not action then return end
	return action.ActionShortcut == shortcut or action.ActionShortcut2 == shortcut or action.ActionGamepad == shortcut
end

---
--- Retrieves the first action that matches the provided shortcut, if the action is not disabled or hidden.
---
--- @param self XActionsHost The `XActionsHost` instance.
--- @param shortcut string The shortcut string to search for.
--- @param input table The input event that triggered the shortcut.
--- @param controller_id string The ID of the controller that triggered the shortcut.
--- @param repeated boolean Whether the shortcut was repeated.
--- @param ... any Additional arguments to pass to the action's `OnAction` function.
--- @return table|nil The first action that matches the provided shortcut, or `nil` if none found.
---
function XActionsHost:ActionByShortcut(shortcut, input, controller_id, repeated, ...)
	local found
	for _, action in ipairs(self:GetShortcutActions(shortcut)) do
		if (not action.IgnoreRepeated or not repeated) then
			if self:FilterAction(action) then
				local state = action:ActionState(self)
				if state ~= "disabled" and state ~= "hidden" then
					found = action
					break
				end
			end
		end
	end
	
	return found
end

--- Retrieves the first action that matches the provided gamepad shortcut, if the action is not disabled or hidden.
---
--- @param self XActionsHost The `XActionsHost` instance.
--- @param shortcut string The gamepad shortcut string to search for.
--- @return table|nil The first action that matches the provided shortcut, or `nil` if none found.
---
function XActionsHost:GamepadHoldActionByShortcut(shortcut)
	local found
	for _, action in ipairs(self:GetShortcutActions(shortcut)) do
		if action.ActionGamepadHold and self:FilterAction(action) then
			local state = action:ActionState(self)
			if state ~= "disabled" and state ~= "hidden" then
				found = action
				break
			end
		end
	end
	return found
end

if FirstLoad then
	KbdShortcutToRelation = {
		["Tab"] = "next",
		["Shift-Tab"] = "prev",
		["Up"] = "up",
		["Down"] = "down",
		["Left"] = "left",
		["Right"] = "right",
	}

	XShortcutToRelation = {
		["LeftThumbLeft"] = "left", ["LeftThumbDownLeft"] = "left", ["LeftThumbUpLeft"] = "left",
		["LeftThumbRight"] = "right", ["LeftThumbDownRight"] = "right", ["LeftThumbUpRight"] = "right",
		["LeftThumbUp"] = "up",
		["LeftThumbDown"] = "down",
		["DPadLeft"] = "left",
		["DPadRight"] = "right",
		["DPadUp"] = "up",
		["DPadDown"] = "down",
	}
end

--- Handles the gamepad hold action when a button is pressed.
---
--- @param self XActionsHost The `XActionsHost` instance.
--- @param pt table The point where the button was pressed.
--- @param button string The button that was pressed.
function XActionsHost:OnHoldDown(pt, button)
	local action = self:GamepadHoldActionByShortcut(button)
	action:OnAction(self,button)
end

---
--- Handles the tick event for a gamepad hold button.
---
--- @param self XActionsHost The `XActionsHost` instance.
--- @param i number The current tick index.
--- @param shortcut string The gamepad shortcut string to search for.
---
function XActionsHost:OnHoldButtonTick(i, shortcut)	
	local action = self:GamepadHoldActionByShortcut(shortcut)
	if not action then
		return 
	end	
	local ctrl = self.action_hold_buttons and self.action_hold_buttons[action.ActionId]
	if ctrl and ctrl:HasMember("OnHoldButtonTick") then
		ctrl:OnHoldButtonTick(i)
	else
		 XHoldButton.OnHoldButtonTick(self, i, shortcut)	
	end
end

---
--- Handles the repeat event for an X button on a gamepad.
---
--- @param self XActionsHost The `XActionsHost` instance.
--- @param shortcut string The gamepad shortcut string to search for.
--- @param controller_id number The ID of the controller that triggered the event.
--- @param ... any Additional arguments.
---
function XActionsHost:OnXButtonRepeat(shortcut, controller_id,...)
	if self.HostInParent then return end
	if not RepeatableXButtons[shortcut] then
		local found = self:GamepadHoldActionByShortcut(shortcut)
		if found then
			XHoldButton.OnHoldButtonRepeat(self,shortcut, controller_id)
			return "break"
		end	
	end
end

---
--- Handles the shortcut key press event for the `XActionsHost` instance.
---
--- @param self XActionsHost The `XActionsHost` instance.
--- @param shortcut string The shortcut key that was pressed.
--- @param source string The input source that triggered the shortcut (e.g. "gamepad", "keyboard").
--- @param controller_id number The ID of the controller that triggered the event.
--- @param ... any Additional arguments.
---
--- @return string|nil "break" if the shortcut was handled, nil otherwise.
---
function XActionsHost:OnShortcut(shortcut, source, controller_id, ...)
	if self.HostInParent then return end
	local found
	if source=="gamepad" then
		if shortcut:starts_with("-") then
			local org_shortcut = shortcut:gsub("-", "")
			found = self:GamepadHoldActionByShortcut(org_shortcut)
			if found then
				found =  XHoldButton.OnHoldButtonUp(self, org_shortcut, controller_id) 
				if found then
					return "break"
				end
			end	
		elseif shortcut:starts_with("+") then
			local org_shortcut = shortcut:gsub("+", "")
			found = self:GamepadHoldActionByShortcut(org_shortcut)
			if found then
				XHoldButton.OnHoldButtonDown(self,org_shortcut, controller_id)
			end	
		else
			found = self:GamepadHoldActionByShortcut(shortcut)
			if found then
				XHoldButton.OnHoldButtonRepeat(self,shortcut, controller_id)
			end
		end	
	end	
	local action = not found and self:ActionByShortcut(shortcut, source, controller_id, ...)
	if action then
		self:OnAction(action, source, controller_id, ...)
		return "break"
	end
	if source ~= "mouse" then
		local relation = (source == "keyboard") and KbdShortcutToRelation[shortcut] or XShortcutToRelation[shortcut]
		if relation then
			local focus = self.desktop and self.desktop.keyboard_focus
			local order = focus and focus:IsWithin(self) and focus:GetFocusOrder() or point(0, 0)
			focus = self:GetRelativeFocus(order, relation)
			if focus then
				-- the thread prevents Tab keys to be processed in OnKbdChar of the new focus
				CreateRealTimeThread(function()
					if focus.window_state ~= "destroying" then
						focus:SetFocus()
						if source == "gamepad" and RolloverControl ~= focus then
							XCreateRolloverWindow(focus, true)
						end
					end
				end)
				return "break"
			end
		end
	end
end

---
--- Opens a context menu for the given action context and anchor point.
---
--- @param action_context string The action context to use for the menu entries.
--- @param anchor_pt point The anchor point to use for positioning the menu.
--- @return XPopupMenu The opened popup menu.
---
function XActionsHost:OpenContextMenu(action_context, anchor_pt)
	if not action_context or not anchor_pt or action_context == "" then return end
	local menu = XPopupMenu:new({
		ActionContextEntries = action_context,
		Anchor = anchor_pt,
		AnchorType = "mouse",
		MaxItems = 12,
		GetActionsHost = function() return self end,
		popup_parent = self,
	}, terminal.desktop)
	menu:Open()
	return menu
end

---
--- Opens a popup menu for the given menubar ID and anchor point.
---
--- @param menubar_id string The ID of the menubar to use for the menu entries.
--- @param anchor_pt point The anchor point to use for positioning the menu.
--- @return XPopupMenu The opened popup menu.
---
function XActionsHost:OpenPopupMenu(menubar_id, anchor_pt)
	local menu = XPopupMenu:new({
		MenuEntries = menubar_id,
		Anchor = anchor_pt,
		AnchorType = "mouse",
		MaxItems = 12,
		GetActionsHost = function() return self end,
		popup_parent = self,
	}, terminal.desktop)
	menu:Open()
	return menu
end


----- XActionsView

DefineClass.XActionsView = {
	__parents = { "XContextWindow" },
	properties = {
		{ category = "General", id = "HideWithoutActions", name = "Hide without actions", editor = "bool", default = false },
	}
}

--- Gets the actions host for the current XActionsView instance.
---
--- @return XActionsHost The actions host for the current XActionsView instance.
function XActionsView:GetActionsHost()
	return GetActionsHost(self, true)
end

---
--- Opens the XActionsView and updates the actions displayed.
---
--- @param ... Any additional arguments to pass to the XContextWindow:Open() method.
---
function XActionsView:Open(...)
	XContextWindow.Open(self, ...)
	self:OnUpdateActions()
end

---
--- Handles the action when a popup menu item is selected.
---
--- @param action_id string The ID of the selected action.
--- @param host XActionsHost The actions host that owns the popup menu.
--- @param source any The source of the popup menu action.
---
function XActionsView:PopupAction(action_id, host, source)
	assert(false)
end

---
--- Updates the actions displayed in the XActionsView.
---
--- This function is called to rebuild the actions displayed in the XActionsView. It first retrieves the actions host for the current XActionsView instance using the `GetActionsHost()` function. If the host is not available or the window state is "new", the function returns without doing anything.
---
--- Otherwise, the function calls the `RebuildActions()` method on the actions host to update the actions displayed in the XActionsView. If the `HideWithoutActions` property is set to `true`, the function then sets the visibility of the XActionsView based on whether there are any actions to display.
---
--- Finally, the function sends a "XWindowRecreated" message to notify any interested parties that the XActionsView has been updated.
---
--- @param self XActionsView The XActionsView instance.
function XActionsView:OnUpdateActions()
	local host = self:GetActionsHost()
	if not host or self.window_state == "new" then return end
	self:RebuildActions(host)
	if self.HideWithoutActions then
		self:SetVisible(#self > 0)
	end
	Msg("XWindowRecreated", self)
end

---
--- Rebuilds the actions displayed in the XActionsView.
---
--- This function is called to rebuild the actions displayed in the XActionsView. It first retrieves the actions host for the current XActionsView instance using the `GetActionsHost()` function. If the host is not available or the window state is "new", the function returns without doing anything.
---
--- Otherwise, the function calls the `RebuildActions()` method on the actions host to update the actions displayed in the XActionsView. If the `HideWithoutActions` property is set to `true`, the function then sets the visibility of the XActionsView based on whether there are any actions to display.
---
--- Finally, the function sends a "XWindowRecreated" message to notify any interested parties that the XActionsView has been updated.
---
--- @param self XActionsView The XActionsView instance.
function XActionsView:RebuildActions(host)
end


----- globals

---
--- Retrieves the actions host for the current XActionsView instance.
---
--- This function recursively searches up the parent hierarchy of the given window object to find the first instance of an XActionsHost. If the final flag is set, it will continue searching until it finds an XActionsView instance and then call its GetActionsHost() method.
---
--- @param win XWindow The window object to start the search from.
--- @param final boolean If true, continue searching until an XActionsView is found.
--- @return XActionsHost|XWindow The actions host or the final window object found.
---
function GetActionsHost(win, final)
	while win and (not win:IsKindOf("XActionsHost") or win.HostInParent and final) do
		win = win.parent
		if final and win and win:IsKindOf("XActionsView") then
			return win:GetActionsHost()
		end
	end
	return win
end

---
--- Checks if the given modes are enabled in the provided modes.
---
--- This function takes two strings, `givenModes` and `modes`, and checks if any of the modes in `givenModes` are present in `modes`. The function returns `true` if any of the modes match, or if either `givenModes` or `modes` is an empty string. The function also returns `true` if either `givenModes` or `modes` contains the string "ForwardToC".
---
--- @param givenModes string The modes to check for.
--- @param modes string The modes to check against.
--- @return boolean True if any of the given modes are enabled, false otherwise.
function EnabledInModes(givenModes, modes)
	if givenModes == "" or modes == "" or modes == givenModes then return true end

	for givenMode in string.gmatch(givenModes, "([%w%-_]+)") do
		for mode in string.gmatch(modes, "([%w%-_]+)") do
			if givenMode == mode or givenMode == "ForwardToC" or mode == "ForwardToC" then
				return true
			end
		end
	end
	
	return false
end
