--- Initializes the mouse cursor state on first load.
-- If the platform is not a console, the mouse cursor is initially hidden.
-- The `HideMouseCursor` and `ShowMouseCursor` functions are assigned to `engineHideMouseCursor` and `engineShowMouseCursor` respectively.
-- Two tables are initialized to track reasons for showing and hiding the mouse cursor:
--   - `ShowMouseReasons`: any reasons present here will cause the mouse cursor to be shown
--   - `ForceHideMouseReasons`: any reasons present here will override any show reasons and force the mouse cursor to be hidden
--   - `ForceShowMouseReasons`: any reasons present here will override any hide reasons and force the mouse cursor to be shown
if FirstLoad then
    g_MouseConnected = not Platform.console
    engineHideMouseCursor, engineShowMouseCursor = HideMouseCursor, ShowMouseCursor

    -- a mouse cursor is shown if there is a reason to show it, and there is no "force hide" reason to hide it
    ShowMouseReasons = {}
    ForceHideMouseReasons = {} -- any reasons present here override any show reasons above
    ForceShowMouseReasons = {} -- any reasons present here override any hide reasons above
end

--- Hides the mouse cursor if there are no reasons to show it and no reasons to force it to be shown.
-- If the terminal desktop exists, it resets the mouse position target.
-- Calls the `engineHideMouseCursor` function to hide the mouse cursor.
-- Sends a message indicating that the mouse cursor has been hidden.
-- @param reason (optional) the reason for hiding the mouse cursor
function HideMouseCursor(reason)
    reason = reason or false
    ShowMouseReasons[reason] = nil
    if (next(ShowMouseReasons) == nil or next(ForceHideMouseReasons)) and next(ForceShowMouseReasons) == nil then
        if terminal.desktop then
            terminal.desktop:ResetMousePosTarget()
        end
        engineHideMouseCursor()
        Msg("ShowMouseCursor", false)
    end
end

--- Shows the mouse cursor if there are no reasons to hide it and no reasons to force it to be hidden.
-- Calls the `engineShowMouseCursor` function to show the mouse cursor.
-- Sends a message indicating that the mouse cursor has been shown.
-- @param reason (optional) the reason for showing the mouse cursor
function ShowMouseCursor(reason)
    reason = reason or false
    if next(ShowMouseReasons) == nil and next(ForceHideMouseReasons) == nil then
        engineShowMouseCursor()
        Msg("ShowMouseCursor", true)
    end
    ShowMouseReasons[reason] = true
end

--- Forces the mouse cursor to be hidden, regardless of any reasons to show it.
-- If there are no reasons to force the mouse cursor to be shown, the mouse cursor is hidden.
-- Resets the mouse position target on the terminal desktop.
-- Calls the `engineHideMouseCursor` function to hide the mouse cursor.
-- Sends a message indicating that the mouse cursor has been hidden.
-- @param reason (optional) the reason for forcing the mouse cursor to be hidden
function ForceHideMouseCursor(reason)
    reason = reason or false
    ForceHideMouseReasons[reason] = true
    if next(ForceShowMouseReasons) == nil then
        if terminal.desktop then
            terminal.desktop:ResetMousePosTarget()
        end
        engineHideMouseCursor()
        Msg("ShowMouseCursor", false)
    end
end

--- Removes a reason for forcibly hiding the mouse cursor.
-- If there are no more reasons to force the mouse cursor to be hidden, and there are no reasons to show the mouse cursor, the mouse cursor is shown.
-- Calls the `engineShowMouseCursor` function to show the mouse cursor.
-- Sends a message indicating that the mouse cursor has been shown.
-- @param reason (optional) the reason for no longer forcing the mouse cursor to be hidden
function UnforceHideMouseCursor(reason)
    reason = reason or false
    ForceHideMouseReasons[reason] = nil
    if next(ForceHideMouseReasons) == nil and next(ShowMouseReasons) then
        engineShowMouseCursor()
        Msg("ShowMouseCursor", true)
    end
end

--- Forces the mouse cursor to be shown, regardless of any reasons to hide it.
-- If there are no reasons to force the mouse cursor to be hidden, the mouse cursor is shown.
-- Calls the `engineShowMouseCursor` function to show the mouse cursor.
-- Sends a message indicating that the mouse cursor has been shown.
-- @param reason (optional) the reason for forcing the mouse cursor to be shown
function ForceShowMouseCursor(reason)
    reason = reason or false
    ForceShowMouseReasons[reason] = true
    engineShowMouseCursor()
    Msg("ShowMouseCursor", true)
end

--- Removes a reason for forcibly showing the mouse cursor.
-- If there are no more reasons to force the mouse cursor to be shown, and there are no reasons to show the mouse cursor, the mouse cursor is hidden.
-- Calls the `engineHideMouseCursor` function to hide the mouse cursor.
-- Sends a message indicating that the mouse cursor has been hidden.
-- @param reason (optional) the reason for no longer forcing the mouse cursor to be shown
function UnforceShowMouseCursor(reason)
    reason = reason or false
    ForceShowMouseReasons[reason] = nil
    if (next(ShowMouseReasons) == nil or next(ForceHideMouseReasons)) and next(ForceShowMouseReasons) == nil then
        if terminal.desktop then
            terminal.desktop:ResetMousePosTarget()
        end
        engineHideMouseCursor()
        Msg("ShowMouseCursor", false)
    end
end

--- Resets the mouse cursor state by clearing the `ShowMouseReasons` table, setting the `ForceHideMouseReasons` table to only contain the "MouseDisconnected" reason, and calling the `HideMouseCursor` function.
function ResetMouseCursor()
    ShowMouseReasons = {}
    ForceHideMouseReasons = {["MouseDisconnected"]=ForceHideMouseReasons["MouseDisconnected"]}
    HideMouseCursor()
end

OnMsg.Start = ResetMouseCursor

--- Enables or disables mouse control for the camera.
-- @param val boolean indicating whether to enable or disable mouse control
function MouseRotate(val)
    for i = 1, camera.GetViewCount() do
        camera3p.EnableMouseControl(val and i == 1, i)
    end
end

--- Handles the mouse cursor visibility when the mouse is inside the game window.
-- If there are no reasons to force the mouse cursor to be shown or hidden, the mouse cursor is hidden.
-- Calls the `engineShowMouseCursor` and `engineHideMouseCursor` functions to show and hide the mouse cursor.
function OnMsg.MouseInside()
    if (next(ShowMouseReasons) == nil or next(ForceHideMouseReasons)) and next(ForceShowMouseReasons) == nil then
        engineShowMouseCursor()
        engineHideMouseCursor()
    end
end
