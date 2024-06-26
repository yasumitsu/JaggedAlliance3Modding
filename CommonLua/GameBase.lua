-- base game functions needed for loading a map, moved from EditorGame.lua in order to detach the editor from the game

---
--- Waits for the specified number of frames to pass before returning.
---
--- @param count number The number of frames to wait for.
function WaitNextFrame(count)
    local persistError = collectgarbage -- we reference a C function so trying to persist WaitNextFrame will result in an error
    local frame = GetRenderFrame() + (count or 1)
    while GetRenderFrame() - frame < 0 do
        WaitMsg("OnRender", 30)
    end
end

---
--- Waits for the specified number of frames or a minimum amount of time to pass before returning.
---
--- @param frames number The number of frames to wait for.
--- @param ms number The minimum amount of time in milliseconds to wait for.
function WaitFramesOrSleepAtLeast(frames, ms)
    local end_frame = GetRenderFrame() + (frames or 1)
    local end_time = now() + ms
    while GetRenderFrame() < end_frame or now() < end_time do
        Sleep(1)
    end
end
