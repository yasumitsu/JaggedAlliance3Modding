local turbo_gametime, turbo_realtime
if FirstLoad then
  TurboSpeedOrigFactor = false
end
local SaveTimeFactor = function(factor)
  TurboSpeedOrigFactor = factor or 0
end

function TurboSpeed(enable, stop_non_game_events)
  if enable and not TurboSpeedOrigFactor then
    TurboSpeedOrigFactor = GetTimeFactor()
    PauseInfiniteLoopDetection("TurboSpeed")
    SetTimeFactor(const.MaxSaneTimeFactor)
    table.change(_G, "TurboSpeed", {SetTimeFactor = SaveTimeFactor})
    table.change(config, "TurboSpeed", {ThreadsSkipTimeThreshold = 10000})
    ObjModified("Time")
    print("Turbo mode ON")
    turbo_gametime = GameTime()
    turbo_realtime = GetPreciseTicks()
    if stop_non_game_events then
      SuspendObjModified("TurboSpeed")
      table.change(config, "TurboSpeed_StopHooks", {FloatingTextEnabled = false, AutosaveSuspended = true})
    end
    if not config.TurboSpeedLeaveHooks then
      SuspendThreadDebugHook("TurboSpeed")
    end
  elseif not enable and TurboSpeedOrigFactor then
    ResumeThreadDebugHook("TurboSpeed")
    table.restore(config, "TurboSpeed", true)
    table.restore(config, "TurboSpeed_StopHooks", true)
    table.restore(_G, "TurboSpeed", true)
    SetTimeFactor(TurboSpeedOrigFactor)
    TurboSpeedOrigFactor = false
    ObjModified("Time")
    local speed = 1
    if turbo_gametime and turbo_realtime then
      speed = (GameTime() - turbo_gametime) / Max(1, GetPreciseTicks() - turbo_realtime)
    end
    printf("Turbo mode OFF x%d", speed)
    ResumeObjModified("TurboSpeed")
    ResumeInfiniteLoopDetection("TurboSpeed")
  end
end