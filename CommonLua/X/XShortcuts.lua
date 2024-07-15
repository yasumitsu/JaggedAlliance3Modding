if FirstLoad then
XShortcutsTarget = false
XShortcutsThread = false
XShortcutsModeExitFunc = empty_func
end
XShortcutsThread = XShortcutsThread or CreateRealTimeThread(function()
	if not XShortcutsTarget then
		XShortcutsTarget = DeveloperInterface:new({}, terminal.desktop)
		XShortcutsTarget:SetUIVisible(false)
		XShortcutsTarget:Open()
	end
	if not Platform.ged then
		WaitDataLoaded()
		-- Wait for default action shortcuts from AccountStorage.Shortcuts
		while not AccountStorage and not PlayWithoutStorage() do
			WaitMsg("AccountStorageChanged")
		end
	end
	ReloadShortcuts()
	NonBindableKeys = GatherNonBindableKeys()
end)

function OnMsg.DataLoaded()
	XShortcutsThread = XShortcutsThread or CreateRealTimeThread(ReloadShortcuts)
end

function OnMsg.PresetSave(class)
	local classdef = g_Classes[class]
	if IsKindOf(classdef, "XTemplate") then
		XShortcutsThread = XShortcutsThread or CreateRealTimeThread(ReloadShortcuts)
	end
end

---
--- Reloads the shortcuts for the XShortcutsTarget object.
--- This function is responsible for clearing the existing shortcuts and
--- repopulating the target with new shortcuts from various sources.
--- It is typically called when the shortcuts need to be updated, such as
--- when a preset is saved or when the AccountStorage changes.
---
--- @param none
--- @return none
---
function ReloadShortcuts()
	PauseInfiniteLoopDetection("ReloadShortcuts")
	table.clear(XShortcutsTarget.actions)
	table.clear(XShortcutsTarget.shortcut_to_actions)
	table.clear(XShortcutsTarget.menubar_actions)
	table.clear(XShortcutsTarget.toolbar_actions)
	
	if Platform.ged then
		if XTemplates.CommonShortcuts then
			XTemplateSpawn("CommonShortcuts", XShortcutsTarget)
		end
		if XTemplates.GedShortcuts then
			XTemplateSpawn("GedShortcuts", XShortcutsTarget)
		end
	else
		ForEachPresetInGroup("XTemplate", "Shortcuts", function(preset)
			XTemplateSpawn(preset.id, XShortcutsTarget)
		end)
		Msg("Shortcuts", XShortcutsTarget)
	end

	ResumeInfiniteLoopDetection("ReloadShortcuts")
	Msg("ShortcutsReloaded")
	XShortcutsTarget:UpdateToolbar()
	XShortcutsThread = false
end

---
--- Dumps the current shortcuts and their associated actions to a text file.
---
--- @param filename string (optional) The name of the file to write the shortcuts to. If not provided, "XShortcuts.txt" will be used.
--- @return none
---
function XDumpShortcuts(filename)
	local shortcut_to_actions = {}
	local action_to_shortcuts = {}
	local function Add(action, shortcut)
		if (shortcut or "") == "" then
			return
		end
		local name = action.ActionName or ""
		if name == "" then
			name = action.ActionId or "?"
		end
		if IsT(name) then
			name = TTranslate(name, action)
		end
		local menu = action.ActionMenubar or ""
		if menu ~= "" then
			name = name .. " (" .. menu .. ")"
		end
		shortcut_to_actions[shortcut] = table.create_add_unique(shortcut_to_actions[shortcut], name)
		action_to_shortcuts[name] = table.create_add_unique(action_to_shortcuts[name], shortcut)
	end
	for _, action in ipairs(XShortcutsTarget:GetActions()) do
		Add(action, action.ActionShortcut)
		Add(action, action.ActionShortcut2)
	end
	
	local list = {}
	for shortcut, actions in pairs(shortcut_to_actions) do
		list[#list + 1] = shortcut .. ": " .. table.concat(actions, ", ")
	end
	table.sort(list)
	local shortcut_to_actions_result = table.concat(list, "\n")
	
	local list = {}
	for name, shortcuts in pairs(action_to_shortcuts) do
		list[#list + 1] = name .. ": " .. table.concat(shortcuts, ", ")
	end
	table.sort(list)
	local action_to_shortcuts_result = table.concat(list, "\n")
	
	local result = {
		"Shortcut to Actions:\n",
		"----------------------------------------------------------------------------------\n",
		"\n",
		shortcut_to_actions_result,
		"\n\n\n\n\n\n\n\n\n\n\n\n\n\n",
		"Action to Shortcuts:\n",
		"----------------------------------------------------------------------------------\n",
		"\n",
		action_to_shortcuts_result
	}
	filename = filename or "XShortcuts.txt"
	AsyncStringToFile(filename, result)
	OpenTextFileWithEditorOfChoice(filename)
end

---
--- Sets the mode of the XShortcutsTarget object and updates its visibility.
---
--- @param mode string The mode to set for the XShortcutsTarget object. Can be "Editor" or another mode.
--- @param exit_func function An optional function to be called when exiting the current mode.
---
function XShortcutsSetMode(mode, exit_func)
	if XShortcutsTarget and XShortcutsTarget:GetActionsMode() ~= mode then
		XShortcutsTarget:SetActionsMode(mode)
		XShortcutsTarget:SetUIVisible(mode == "Editor")
		local old_exit_func = XShortcutsModeExitFunc
		XShortcutsModeExitFunc = exit_func or empty_func
		old_exit_func()
	end
end

---
--- Splits a shortcut string into a table of individual keys.
---
--- @param shortcut string The shortcut string to split.
--- @return table A table of individual keys in the shortcut.
---
function SplitShortcut(shortcut)
	local keys
	if shortcut ~= "" then
		keys = string.split(shortcut, "-")
		local count = #keys
		--fix for when the last key is "-" or "Numpad -"
		if keys[count] == "" then
			keys[count] = nil
			keys[count-1] = keys[count-1] .. "-"
		end
	end
	return keys or {}
end

if FirstLoad then
	s_XShortcutsTargetCache = {}
end

---
--- Gets the shortcuts associated with the specified action ID.
---
--- @param action_id string The ID of the action to get shortcuts for.
--- @return table|boolean A table containing the shortcuts for the action, or false if no shortcuts are found.
---
function GetShortcuts(action_id) --cpy paste from sim/ui/shortcuts
	local action = s_XShortcutsTargetCache[action_id]
	if not action then
		action = XShortcutsTarget and XShortcutsTarget:ActionById(action_id)
		s_XShortcutsTargetCache[action_id] = action
	end
	local saved = AccountStorage and AccountStorage.Shortcuts[action_id]
	if saved or action then
		local shortcut = (saved and saved[1]) or (action and action.ActionShortcut)
		local shortcut2 = (saved and saved[2]) or (action and action.ActionShortcut2)
		local shortcut_gamepad = (saved and saved[3]) or (action and action.ActionGamepad)
		if (shortcut or "") ~= "" or (shortcut2 or "") ~= "" or (shortcut_gamepad or "") ~= "" then
			return {shortcut, shortcut2, shortcut_gamepad}
		end
	end
	return false
end

---
--- Gets the gamepad shortcut for the specified action ID.
---
--- @param action_id string The ID of the action to get the gamepad shortcut for.
--- @return string|nil The gamepad shortcut for the action, or nil if no shortcut is found.
---
function GetGamepadShortcut(action_id)
	local shortcuts = GetShortcuts(action_id)
	return shortcuts and shortcuts[3]
end

function OnMsg.ShortcutsReloaded()
	s_XShortcutsTargetCache = {}
end

---
--- Checks if the specified binding is associated with the given shortcut ID.
---
--- @param binding string The binding to check.
--- @param shortcut_id string The ID of the shortcut to check.
--- @return boolean True if the binding is associated with the shortcut, false otherwise.
---
function CheckShortcutBinding(binding, shortcut_id)
	return table.find(GetShortcuts(shortcut_id) or empty_table, binding)
end