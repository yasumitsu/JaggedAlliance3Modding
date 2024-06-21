--- Initializes the camera lock and unlock reason tables when the game is first loaded.
-- This ensures the camera lock state is properly reset when a new map is loaded.
if FirstLoad then
    s_CameraLockReasons = {}
    s_CameraUnlockReasons = {}
end

---
--- Locks the camera with the given reason.
--- If the camera was not previously locked, sends the "OnLockCamera" message.
---
--- @param reason string|boolean The reason for locking the camera. If not provided, defaults to `false`.
function LockCamera(reason)
    local locked = IsCameraLocked()
    s_CameraLockReasons[reason or false] = true
    UpdateCameraLock()
    if locked ~= IsCameraLocked() then
        Msg("OnLockCamera")
    end
end

---
--- Unlocks the camera with the given reason.
--- If the camera was previously locked, sends the "OnLockCamera" message.
---
--- @param reason string|boolean The reason for unlocking the camera. If not provided, defaults to `false`.
function UnlockCamera(reason)
    s_CameraLockReasons[reason or false] = nil
    UpdateCameraLock()
end

---
--- Forces the camera to be unlocked with the given reason.
--- If the camera was previously locked, sends the "OnLockCamera" message.
---
--- @param reason string|boolean The reason for unlocking the camera. If not provided, defaults to `false`.
function ForceUnlockCameraStart(reason)
    s_CameraUnlockReasons[reason or false] = true
    UpdateCameraLock()
end

---
--- Removes the given reason for forcibly unlocking the camera.
--- If the camera was previously locked, sends the "OnLockCamera" message.
---
--- @param reason string|boolean The reason for forcibly unlocking the camera. If not provided, defaults to `false`.
function ForceUnlockCameraEnd(reason)
    s_CameraUnlockReasons[reason or false] = nil
    UpdateCameraLock()
end

---
--- Resets the camera lock state when a new map is loaded.
---
--- This function is called in response to the `ChangeMap` message, and ensures that the
--- camera lock state is properly reset when a new map is loaded. It clears the
--- `s_CameraLockReasons` and `s_CameraUnlockReasons` tables, and then calls `UpdateCameraLock()`
--- to update the camera lock state.
---
--- @function OnMsg.ChangeMap
--- @return nil
function OnMsg.ChangeMap()
    s_CameraLockReasons = {}
    s_CameraUnlockReasons = {}
    UpdateCameraLock()
end

---
--- Updates the camera lock state based on the current lock and unlock reasons.
---
--- If there are any active unlock reasons, or no active lock reasons, the camera is unlocked.
--- Otherwise, the camera is locked.
---
--- This function is called whenever the lock or unlock reasons change, to ensure the camera
--- lock state is up-to-date.
---
--- @function UpdateCameraLock
--- @return nil
function UpdateCameraLock()
    if next(s_CameraUnlockReasons) or next(s_CameraLockReasons) == nil then
        camera.Unlock(1)
    else
        camera.Lock(1)
    end
end

---
--- Checks if the camera is currently locked.
---
--- If no reason is provided, this function returns `true` if the camera is locked for any reason.
--- If a reason is provided, this function returns `true` if the camera is locked for that specific reason.
---
--- @param reason string|boolean The reason to check for. If not provided, the function checks if the camera is locked for any reason.
--- @return boolean `true` if the camera is locked, `false` otherwise.
function IsCameraLocked(reason)
    if not reason then
        return next(s_CameraLockReasons) ~= nil
    end
    for r, _ in pairs(s_CameraLockReasons) do
        if r == reason then
            return true
        end
    end
    return false
end

---
--- Unlocks the mouse when the camera is locked, to prevent the game from entering an unresponsive state when opening a dialog during camera rotation.
---
--- This function is called in response to the `OnMsg.OnLockCamera` message, which is triggered when the camera is locked.
---
--- @function OnMsg.OnLockCamera
--- @return nil
function OnMsg.OnLockCamera()
    SetMouseDeltaMode(false)
end
function OnMsg.OnLockCamera() -- free mouse when locking camera (ex. don't leave unresponsive game state when opening a dialog during camera rotation)
    SetMouseDeltaMode(false)
end

---
--- Prints the camera lock reasons.
---
--- @param reasons table The table of camera lock reasons.
--- @param print_func function The print function to use.
--- @param indent string The indentation to use for each line.
---
local function _PrintCameraLockReasons(reasons, print_func, indent)
    print_func = print_func or print
    for reason in pairs(reasons) do
        print_func(indent, type(reason) == "table" and reason.class or tostring(reason))
    end
end

---
--- Prints the active camera lock and unlock reasons when a bug report is started.
---
--- This function is called in response to the `OnMsg.BugReportStart` message, which is triggered when a bug report is started.
---
--- @function OnMsg.BugReportStart
--- @param print_func function The print function to use for printing the camera lock and unlock reasons.
--- @return nil
function OnMsg.BugReportStart(print_func)
    if next(s_CameraLockReasons) ~= nil then
        print_func("Active camera lock reasons:")
        _PrintCameraLockReasons(s_CameraLockReasons, print_func, "\t")
        print_func("")
    end
    if next(s_CameraUnlockReasons) ~= nil then
        print_func("Active camera unlock reasons:")
        _PrintCameraLockReasons(s_CameraUnlockReasons, print_func, "\t")
        print_func("")
    end
end
