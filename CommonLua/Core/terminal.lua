--- Ensures the `terminal` global variable exists, creating it if it does not.
--- This allows other parts of the codebase to safely access and modify the `terminal` table.
if not rawget(_G, "terminal") then
    terminal = {}
end

local terminal = terminal
if not terminal.targets then
	terminal.targets = {}
	terminal.activate_time = RealTime()
end

---
--- Adds a `TerminalTarget` object to the `terminal.targets` table and sorts the table by the `terminal_target_priority` field in descending order.
---
--- @param target TerminalTarget The `TerminalTarget` object to add to the `terminal.targets` table.
---
function terminal.AddTarget(target)
    assert(IsKindOf(target, "TerminalTarget"))
    table.insert_unique(terminal.targets, target)
    terminal.SortTargets()
end

---
--- Removes a `TerminalTarget` object from the `terminal.targets` table.
---
--- @param target TerminalTarget The `TerminalTarget` object to remove from the `terminal.targets` table.
---
function terminal.RemoveTarget(target)
    table.remove_entry(terminal.targets, target)
end

---
--- Sorts the `terminal.targets` table in descending order by the `terminal_target_priority` field.
---
function terminal.SortTargets()
    table.sortby_field_descending(terminal.targets, "terminal_target_priority")
end

---
--- Handles mouse events for the terminal system.
---
--- This function is called when a mouse event occurs, such as mouse position changes, mouse button presses/releases, and mouse wheel scrolling.
--- It iterates through the `terminal.targets` table and calls the `MouseEvent` method on each `TerminalTarget` object, passing the event details.
--- If any `TerminalTarget` object returns "break", the function immediately returns "break" to stop further processing.
--- If the event is a mouse wheel or mouse button event, the function checks for any associated shortcuts and calls the `terminal.Shortcut` function to handle the shortcut.
---
--- @param event string The type of mouse event that occurred, such as "OnMousePos", "OnMouseButtonDown", "OnMouseButtonUp", "OnMouseWheelBack", or "OnMouseWheelForward".
--- @param pt table The position of the mouse cursor, in the format `{x = x, y = y}`.
--- @param button string The mouse button that was pressed or released, such as "Left", "Right", or "Middle".
--- @param time number The timestamp of the mouse event.
--- @param last_pos_event boolean Whether this is the last position event in a series of mouse position events.
--- @return string|nil "break" if the function should stop processing the event, or nil if the event should continue to be processed.
---
function terminal.MouseEvent(event, pt, button, time, last_pos_event)
    if event == "OnMousePos" and not last_pos_event then
        return
    end

    for _, target in ipairs(terminal.targets) do
        local result = target:MouseEvent(event, pt, button, time)
        if result == "break" then
            return "break"
        end
    end
    if event == "OnMouseWheelBack" or event == "OnMouseWheelForward" then
        local button = event == "OnMouseWheelBack" and "WheelBack" or "WheelFwd"
        local shortcut = MouseShortcut(button)
        if shortcut then
            return terminal.Shortcut(shortcut, "mouse")
        end
    end
    if event == "OnMouseButtonDown" or event == "OnMouseButtonDoubleClick" then
        local shortcut = MouseShortcut(button)
        if shortcut then
            return terminal.Shortcut(shortcut, "mouse")
        end
    end
    if event == "OnMouseButtonUp" then
        local shortcut = MouseShortcut(button)
        if shortcut then
            return terminal.Shortcut("-" .. shortcut, "mouse")
        end
    end
end

---
--- Checks if the specified shortcut is currently pressed.
---
--- This function checks if all the key or button combinations that make up the specified shortcut are currently pressed. It supports both keyboard and gamepad shortcuts.
---
--- @param shortcut string The shortcut to check, in the format "key1+key2+key3" or "button1+button2+button3".
--- @return boolean true if the shortcut is currently pressed, false otherwise.
---
function terminal.IsShortcutPressed(shortcut)
    assert(IsAsyncCode())

    local sc_list = GetShortcuts(shortcut)
    for i = 1, 3 do
        if (sc_list[i] or "") ~= "" then
            local sc = SplitShortcut(sc_list[i])
            local all_pressed = true
            for j = 1, #sc do
                if i < 3 then
                    local vk = VKStrNamesInverse[sc[j]] or MouseVKStrNamesInverse[sc[j]]
                    if vk and (not terminal.IsKeyPressed(vk)) then
                        all_pressed = false
                        break
                    end
                else
                    if Platform.pc then
                        local pressed = false
                        for k = 0, XInput.MaxControllers() - 1 do
                            if XInput.IsCtrlButtonPressed(k, sc[j]) then
                                pressed = true
                                break
                            end
                        end
                        if not pressed then
                            all_pressed = false
                            break
                        end
                    else
                        if not XInput.IsCtrlButtonPressed(ActiveController, sc[j]) then
                            all_pressed = false
                            break
                        end
                    end
                end
            end
            if all_pressed then
                return true
            end
        end
    end

    return false
end

--- Dispatches a shortcut event to all registered terminal targets.
---
--- @param shortcut string The shortcut to dispatch, in the format "key1+key2+key3" or "button1+button2+button3".
--- @param source string The source of the shortcut, either "keyboard" or "gamepad".
--- @param ... any Additional arguments to pass to the shortcut handler.
--- @return string "break" if any of the targets returned "break", nil otherwise.
function terminal.Shortcut(shortcut, source, ...)
    for _, target in ipairs(terminal.targets) do
        if target:OnShortcut(shortcut, source, ...) == "break" then
            return "break"
        end
    end
end

--- Dispatches a system event to all registered terminal targets.
---
--- @param event string The system event to dispatch.
--- @param ... any Additional arguments to pass to the system event handler.
--- @return string "break" if any of the targets returned "break", nil otherwise.
function terminal.SysEvent(event, ...)
    for _, target in ipairs(terminal.targets) do
        local result = target:SysEvent(event, ...)
        if result == "break" then
            return "break"
        end
    end
end

--- Dispatches a touch event to all registered terminal targets.
---
--- @param event string The touch event to dispatch.
--- @param ... any Additional arguments to pass to the touch event handler.
--- @return string "break" if any of the targets returned "break", nil otherwise.
function terminal.TouchEvent(event, ...)
    for _, target in ipairs(terminal.targets) do
        local result = target:TouchEvent(event, ...)
        if result == "break" then
            return "break"
        end
    end
end

--- Dispatches a keyboard event to all registered terminal targets.
---
--- @param event string The keyboard event to dispatch, either "OnKbdKeyDown" or "OnKbdKeyUp".
--- @param ... any Additional arguments to pass to the keyboard event handler.
--- @return string "break" if any of the targets returned "break", nil otherwise.
local function KeyboardEventDispatch(event, ...)
    for _, target in ipairs(terminal.targets) do
        if target:KeyboardEvent(event, ...) == "break" then
            return "break"
        end
    end
    if event == "OnKbdKeyDown" then
        local virtual_key, repeated = ...
        local shortcut = KbdShortcut(virtual_key)
        if shortcut then
            return terminal.Shortcut(shortcut, "keyboard", nil, repeated)
        end
    end
    if event == "OnKbdKeyUp" then
        local virtual_key = ...
        local shortcut = KbdShortcut(virtual_key)
        if shortcut then
            return terminal.Shortcut("-" .. shortcut, "keyboard")
        end
    end
end

--- Dispatches a keyboard event to all registered terminal targets.
---
--- If the event is "OnKbdKeyDown" or "OnKbdKeyUp", the function will call `KeyboardEventDispatch` with the remaining arguments.
--- Otherwise, it will call `KeyboardEventDispatch` with the `char` argument and the remaining arguments.
---
--- @param event string The keyboard event to dispatch, either "OnKbdKeyDown" or "OnKbdKeyUp".
--- @param char string The character of the key that was pressed or released.
--- @param ... any Additional arguments to pass to the keyboard event handler.
--- @return string "break" if any of the targets returned "break", nil otherwise.
function terminal.KeyboardEvent(event, char, ...)
    -- Drop the first argument "char", as it is meaningless in case of OnKbdKeyDown or OnKbdKeyUp and can only cause confusion
    if event == "OnKbdKeyDown" or event == "OnKbdKeyUp" then
        return KeyboardEventDispatch(event, ...)
    else
        return KeyboardEventDispatch(event, char, ...)
    end
end


--- Dispatches a file event to all registered terminal targets.
---
--- @param event string The file event to dispatch, such as "OnFileChanged" or "OnFileDeleted".
--- @param filename string The name of the file that triggered the event.
--- @return string "break" if any of the targets returned "break", nil otherwise.
function terminal.FileEvent(event, filename)
    for _, target in ipairs(terminal.targets) do
        local result = target:FileEvent(event, filename)
        if result == "break" then
            return "break"
        end
    end
end

--- A table of gamepad buttons that should be treated as repeatable input.
---
--- This table maps button names to boolean values, where a true value indicates that the button should be treated as repeatable input.
--- Repeatable input means that the button will generate multiple events when held down, rather than just a single event when pressed and released.
---
--- The buttons included in this table are:
--- - D-Pad buttons (Left, Right, Up, Down)
--- - Left thumbstick buttons (Up, Up-Right, Right, Down-Right, Down, Down-Left, Left, Up-Left)
--- - Right thumbstick buttons (Up, Down, Down-Right, Right, Up-Right)
--- - Left and Right shoulder buttons
---
--- This table is used by the `terminal.XEvent` function to determine which gamepad button events should be treated as repeatable.
RepeatableXButtons = {["DPadLeft"]=true, ["DPadRight"]=true, ["DPadUp"]=true, ["DPadDown"]=true, ["LeftThumbUp"]=true,
    ["LeftThumbUpRight"]=true, ["LeftThumbRight"]=true, ["LeftThumbDownRight"]=true, ["LeftThumbDown"]=true,
    ["LeftThumbDownLeft"]=true, ["LeftThumbLeft"]=true, ["LeftThumbUpLeft"]=true, ["RightThumbUp"]=true,
    ["RightThumbDown"]=true, ["RightThumbDownRight"]=true, ["RightThumbRight"]=true, ["RightThumbUpRight"]=true,
    ["LeftShoulder"]=true, ["RightShoulder"]=true}

---
--- Dispatches an X-input (gamepad) event to all registered terminal targets.
---
--- This function handles the following X-input events:
--- - `OnXButtonDown`: Dispatches the corresponding gamepad button press shortcut to the terminal targets.
--- - `OnXButtonUp`: Dispatches the corresponding gamepad button release shortcut to the terminal targets.
--- - `OnXButtonRepeat`: Dispatches the corresponding gamepad button repeat shortcut to the terminal targets, but only for buttons marked as repeatable in the `RepeatableXButtons` table.
---
--- @param event string The X-input event to dispatch, such as "OnXButtonDown", "OnXButtonUp", or "OnXButtonRepeat".
--- @param ... any Additional arguments to pass to the X-input event handler.
--- @return string "break" if any of the targets returned "break", nil otherwise.
function terminal.XEvent(event, ...)
    for _, target in ipairs(terminal.targets) do
        if target:XEvent(event, ...) == "break" then
            return "break"
        end
    end
    if event == "OnXButtonDown" then
        local button, controller_id = ...
        local shortcut = XInputShortcut(button, controller_id)
        if shortcut then
            if terminal.Shortcut("+" .. shortcut, "gamepad", controller_id) == "break" then
                return "break"
            end
            return terminal.Shortcut(shortcut, "gamepad", controller_id)
        end
    end
    if event == "OnXButtonUp" then
        local button, controller_id = ...
        local shortcut = XInputShortcut(button, controller_id)
        if shortcut then
            return terminal.Shortcut("-" .. shortcut, "gamepad", controller_id)
        end
    end
    if event == "OnXButtonRepeat" then
        local button, controller_id = ...
        if RepeatableXButtons[button] then
            local shortcut = XInputShortcut(button, controller_id)
            if shortcut then
                return terminal.Shortcut(shortcut, "gamepad", controller_id, true)
            end
        end
    end
end

----- TerminalTarget

---
--- Defines a terminal target class with a priority value.
---
--- The `TerminalTarget` class is used to handle various events (mouse, keyboard, system, touch, X-input, file) for a terminal target. The `terminal_target_priority` field is used to determine the order in which terminal targets are processed when handling these events.
---
--- @class TerminalTarget
--- @field terminal_target_priority number The priority of the terminal target, used to determine the order in which targets are processed.
DefineClass.TerminalTarget = {__parents={"PropertyObject"}, terminal_target_priority=0}

---
--- Dispatches the corresponding mouse event to the terminal target.
---
--- @param event string The mouse event to dispatch, such as "OnMouseMove", "OnMouseButtonDown", etc.
--- @param ... any Additional arguments to pass to the mouse event handler.
--- @return string "break" if the event handler returned "break", nil otherwise.
function TerminalTarget:MouseEvent(event, ...)
    return self[event](self, ...)
end

---
--- Dispatches the corresponding keyboard event to the terminal target.
---
--- @param event string The keyboard event to dispatch, such as "OnKbdChar", "OnKbdKeyDown", or "OnKbdKeyUp".
--- @param ... any Additional arguments to pass to the keyboard event handler.
--- @return string "break" if the event handler returned "break", nil otherwise.
function TerminalTarget:KeyboardEvent(event, ...)
    return self[event](self, ...)
end

---
--- Dispatches the corresponding system event to the terminal target.
---
--- @param event string The system event to dispatch, such as "OnSysResize", "OnSysActivate", etc.
--- @param ... any Additional arguments to pass to the system event handler.
--- @return string "break" if the event handler returned "break", nil otherwise.
function TerminalTarget:SysEvent(event, ...)
    return self[event](self, ...)
end

---
--- Dispatches the corresponding touch event to the terminal target.
---
--- @param event string The touch event to dispatch, such as "OnTouchMove", "OnTouchStart", or "OnTouchEnd".
--- @param ... any Additional arguments to pass to the touch event handler.
--- @return string "break" if the event handler returned "break", nil otherwise.
function TerminalTarget:TouchEvent(event, ...)
    return self[event](self, ...)
end

---
--- Dispatches the corresponding X-input event to the terminal target.
---
--- @param event string The X-input event to dispatch, such as "OnXButtonDown", "OnXButtonUp", or "OnXButtonRepeat".
--- @param ... any Additional arguments to pass to the X-input event handler.
--- @return string "break" if the event handler returned "break", nil otherwise.
function TerminalTarget:XEvent(event, ...)
    return self[event](self, ...)
end

---
--- Handles a shortcut event for the terminal target.
---
--- @param shortcut string The shortcut identifier.
--- @param source any The source of the shortcut event.
--- @param controller_id number The ID of the controller that triggered the shortcut.
--- @param repeated boolean Whether the shortcut event is a repeat.
--- @param ... any Additional arguments to pass to the shortcut event handler.
--- @return string "break" if the event handler returned "break", nil otherwise.
function TerminalTarget:OnShortcut(shortcut, source, controller_id, repeated, ...)
end

---
--- Dispatches the corresponding file event to the terminal target.
---
--- @param event string The file event to dispatch.
--- @param ... any Additional arguments to pass to the file event handler.
--- @return string "break" if the event handler returned "break", nil otherwise.
function TerminalTarget:FileEvent(event, ...)
    return self[event](self, ...)
end

-----|| event handler funcs start ||-------
---
--- Handles a mouse button double click event for the terminal target.
---
--- @param pt table The position of the mouse pointer.
--- @param button number The mouse button that was double clicked.
--- @return string "break" if the event handler returned "break", nil otherwise.
function TerminalTarget:OnMouseButtonDoubleClick(pt, button)
    return self:OnMouseButtonDown(pt, button)
end

---
--- Handles a gamepad button repeat event for the terminal target.
---
--- If the button is a repeatable X button, this function will call the `OnXButtonUp` and `OnXButtonDown` event handlers in succession.
---
--- @param button number The gamepad button that is being repeated.
--- @param controller_id number The ID of the controller that is triggering the button repeat event.
--- @return string "break" if either the `OnXButtonUp` or `OnXButtonDown` event handlers returned "break", nil otherwise.
function TerminalTarget:OnXButtonRepeat(button, controller_id)
    if RepeatableXButtons[button] then
        local up_result = self:OnXButtonUp(button, controller_id)
        local down_result = self:OnXButtonDown(button, controller_id)
        if up_result == "break" or down_result == "break" then
            return "break"
        end
    end
end

local function stub() end
----- mouse event handlers
TerminalTarget.OnMouseMove = stub
TerminalTarget.OnMousePos = stub
TerminalTarget.OnMouseButtonDown = stub
TerminalTarget.OnMouseButtonUp = stub
TerminalTarget.OnMouseWheelForward = stub
TerminalTarget.OnMouseWheelBack = stub
TerminalTarget.OnMouseOutside = stub
TerminalTarget.OnMouseInside = stub
----- keyboard event handlers
TerminalTarget.OnKbdChar = stub
TerminalTarget.OnKbdKeyDown = stub
TerminalTarget.OnKbdKeyUp = stub
----- keyboard ime event handlers
TerminalTarget.OnKbdIMEStartComposition = stub
TerminalTarget.OnKbdIMEEndComposition = stub
TerminalTarget.OnKbdIMEUpdateComposition = stub
----- system event handlers
TerminalTarget.OnSystemSize = stub
TerminalTarget.OnSystemVirtualKeyboard = stub
TerminalTarget.OnSystemActivate = stub
TerminalTarget.OnSystemInactivate = stub
TerminalTarget.OnSystemMinimize = stub
----- gamepad event handlers
TerminalTarget.OnXNewPacket = stub
TerminalTarget.OnXButtonUp = stub
TerminalTarget.OnXButtonDown = stub
----- touch event handlers
TerminalTarget.OnTouchBegan = stub
TerminalTarget.OnTouchMoved = stub
TerminalTarget.OnTouchStationary = stub
TerminalTarget.OnTouchEnded = stub
TerminalTarget.OnTouchCancelled = stub
----- file event handlers
TerminalTarget.OnFileDrop = stub
-----|| event handler funcs end ||-------

----- FilterEventsTarget

--- Defines a class `FilterEventsTarget` that inherits from `TerminalTarget`.
---
--- The `FilterEventsTarget` class is used to filter terminal events based on the
--- `allow_events` table. If the corresponding event type is set to `false` in
--- the `allow_events` table, the event will be blocked and not passed to the
--- terminal targets.
---
--- The `terminal_target_priority` field sets the priority of the
--- `FilterEventsTarget` instance, which determines the order in which it is
--- processed relative to other terminal targets.
---
--- @class FilterEventsTarget
--- @field terminal_target_priority number The priority of the `FilterEventsTarget` instance.
--- @field allow_events table A table that specifies which event types are allowed to pass through.
DefineClass.FilterEventsTarget = {__parents={"TerminalTarget"}, terminal_target_priority=10000000, allow_events=false}

--- Handles mouse events for the `FilterEventsTarget` class.
---
--- If the `allow_events.mouse` field is `true`, this function will return `"continue"` to allow the mouse event to propagate to other terminal targets. If `allow_events.mouse` is `false`, this function will return `"break"` to block the mouse event.
---
--- @param event string The type of mouse event (e.g. "OnMouseWheelForward", "OnMouseInside", etc.)
--- @param ... any Additional arguments passed with the mouse event
--- @return string "continue" to allow the event, "break" to block the event
function FilterEventsTarget:MouseEvent(event, ...)
    return self.allow_events.mouse and "continue" or "break"
end

--- Handles keyboard events for the `FilterEventsTarget` class.
---
--- If the `allow_events.keyboard` field is `true`, this function will return `"continue"` to allow the keyboard event to propagate to other terminal targets. If `allow_events.keyboard` is `false`, this function will return `"break"` to block the keyboard event.
---
--- @param event string The type of keyboard event
--- @param ... any Additional arguments passed with the keyboard event
--- @return string "continue" to allow the event, "break" to block the event
function FilterEventsTarget:KeyboardEvent(event, ...)
    return self.allow_events.keyboard and "continue" or "break"
end

--- Handles system events for the `FilterEventsTarget` class.
---
--- This function ensures that system events are never disallowed, regardless of the values in the `allow_events` table. It always returns `"continue"` to allow the system event to propagate to other terminal targets.
---
--- @param event string The type of system event
--- @param ... any Additional arguments passed with the system event
--- @return string "continue" to allow the event
function FilterEventsTarget:SysEvent(event, ...)
    -- system events are never disallowed
end

--- Handles gamepad events for the `FilterEventsTarget` class.
---
--- If the `allow_events["gamepad" .. (nCtrlId or "X")]` field is `true`, this function will return `"continue"` to allow the gamepad event to propagate to other terminal targets. If the field is `false`, this function will return `"break"` to block the gamepad event.
---
--- @param event string The type of gamepad event
--- @param button number The gamepad button that triggered the event
--- @param nCtrlId number The ID of the gamepad controller (optional)
--- @param ... any Additional arguments passed with the gamepad event
--- @return string "continue" to allow the event, "break" to block the event
function FilterEventsTarget:XEvent(event, button, nCtrlId, ...)
    return self.allow_events["gamepad" .. (nCtrlId or "X")] and "continue" or "break"
end

-- allow_events[source] must be true for events to pass
--- Filters the terminal event sources by adding or removing a `FilterEventsTarget` object.
---
--- If `allow_events` is provided, a new `FilterEventsTarget` object is created with the specified `allow_events` table and `terminal_target_priority`. Any existing `FilterEventsTarget` objects are removed from the terminal targets.
---
--- If `allow_events` is not provided, any existing `FilterEventsTarget` objects are removed from the terminal targets.
---
--- @param allow_events table A table that specifies which event types are allowed to pass through.
--- @param priority number The priority of the `FilterEventsTarget` object.
function FilterTerminalEventSources(allow_events, priority)
    for _, target in ipairs(terminal.targets) do
        if IsKindOf(target, "FilterEventsTarget") then
            terminal.RemoveTarget(target)
            break
        end
    end
    if allow_events then
        FilterEventsTarget:new{allow_events=allow_events, terminal_target_priority=priority}
    end
end

--- Handles the reset of the device.
---
--- This function is called when the device is reset. It is currently empty and does not perform any actions.
function OnDeviceReset()
end

------------------ Sound Mute ----------------------
--- Handles the system inactivate event.
---
--- If the `config.DontMuteWhenInactive` flag is not set, this function will set the "Inactive" mute sound reason, which will mute all sounds while the system is inactive.
function OnMsg.SystemInactivate()
    if not config.DontMuteWhenInactive then
        SetMuteSoundReason("Inactive")
    end
end

--- Handles the system activate event.
---
--- This function is called when the system is activated. It sets the `activate_time` field of the `terminal` table to the current real time, and clears the "Inactive" mute sound reason, which will unmute all sounds.
function OnMsg.SystemActivate()
    terminal.activate_time = RealTime()
    ClearMuteSoundReason("Inactive")
end

------------------- Keyboard on consoles ---------------------
--- Initializes the `g_KeyboardConnected` global variable based on the platform.
---
--- If `FirstLoad` is true, `g_KeyboardConnected` is set to the opposite of `Platform.console`. This is likely used to track whether a keyboard is connected, as the platform may not provide explicit connection/disconnection events.
if FirstLoad then
    g_KeyboardConnected = not Platform.console
end

--- Handles keyboard and mouse connection/disconnection events on console platforms.
---
--- On console platforms, this code sets the `g_KeyboardConnected` and `g_MouseConnected` global variables based on keyboard and mouse connection/disconnection events. It also creates a real-time thread on Xbox platforms to periodically check the connection status and send the appropriate messages.
---
--- @module terminal
--- @within CommonLua.Core
if Platform.console then
    function OnMsg.KeyboardConnected()
        g_KeyboardConnected = true
    end

    function OnMsg.KeyboardDisconnected()
        g_KeyboardConnected = false
    end

    function OnMsg.MouseConnected()
        g_MouseConnected = true
        UnforceHideMouseCursor("MouseDisconnected")
    end

    function OnMsg.MouseDisconnected()
        g_MouseConnected = false
        ForceHideMouseCursor("MouseDisconnected")
    end

    function OnMsg.Autorun()
        if terminal.IsMouseEnabled() then
            Msg("MouseConnected")
        else
            Msg("MouseDisconnected")
        end
    end

    -- there are no keyboard or mouse connected messages on xbox, so we start a thread
    if Platform.xbox then
        if FirstLoad then
            KeyboardMouseSupportThread = false
        end

        DeleteThread(KeyboardMouseSupportThread)
        KeyboardMouseSupportThread = CreateRealTimeThread(function()
            while true do
                Sleep(5000)
                local mouse = terminal.IsMouseEnabled()
                local keyboard = terminal.IsKeyboardEnabled()
                if mouse ~= g_MouseConnected then
                    Msg(mouse and "MouseConnected" or "MouseDisconnected")
                end
                if keyboard ~= g_KeyboardConnected then
                    Msg(keyboard and "KeyboardConnected" or "KeyboardDisconnected")
                end
            end
        end)
    end
end
