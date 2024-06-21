--- Initializes global variables used for thread debugging and message handling.
-- This code is executed on first load of the module.
-- @section FirstLoad
-- @field PauseReasons table A table to store reasons for pausing threads.
-- @field ThreadDebugHook boolean Flag indicating whether the thread debug hook is enabled.
-- @field SuspendDebugHookReasons table A table to store reasons for suspending the debug hook.
-- @field MsgReactions table A table to store message reaction handlers.
if FirstLoad then
    PauseReasons = {}
    ThreadDebugHook = false
    SuspendDebugHookReasons = {}
    MsgReactions = {}
end
--- A table that maps message names to a list of static message handler functions.
-- @field message_to_staticfuncs table A table that maps message names to a list of static message handler functions.
-- @field threadPersist number A bit flag that indicates a thread should persist across map changes.
-- @field threadOnMap number A bit flag that indicates a thread is associated with the current map.
-- @field MsgReactions table A table that stores message reaction handlers.
local message_to_staticfuncs = {}
local threadPersist = 2 ^ 20
local threadOnMap = 2 ^ 21
local MsgReactions = MsgReactions

--- Calls all static message handlers and wakes up the threads sleeping with WaitMsg for the same message.
-- @cstyle void Msg(message, ...).
-- @param message any value used as message name.
--- Calls all static message handlers and wakes up the threads sleeping with WaitMsg for the same message.
-- @param message any value used as message name.
-- @function Msg
-- @tparam any ... additional arguments to pass to the message handlers
function Msg(message, ...)
    -- call static message handlers
    local funcs = message_to_staticfuncs[message]
    if funcs then
        for i = 1, #funcs do
            procall(funcs[i], ...)
        end
    end
    -- wakeup threads
    MsgThreads(message, ...)
    -- call Msg reactions
    local events = MsgReactions[message] or ""
    for i = 1, #events, 2 do
        local handler = events[i + 1]
        procall(handler, events[i], ...)
    end
end

--- Removes all static message handlers for the specified message.
-- @function MsgClear
-- @tparam any message The message name to clear the handlers for.
function MsgClear(message)
    message_to_staticfuncs[message] = nil
end

---
--- Dumps the message handlers registered in `message_to_staticfuncs` to a file.
---
--- @param file string|nil The file path to write the message handlers to. Defaults to "svnProject/MsgHandlers.txt".
--- @param lines boolean|nil If true, include the line numbers for each message handler.
--- @return string|nil The error message if there was an error writing to the file, otherwise nil.
--- @return string The contents of the generated file.
function DumpMsgHandlers(file, lines)
end
if Platform.developer then
    function DumpMsgHandlers(file, lines)
        file = file or "svnProject/MsgHandlers.txt"
        local out = pstr("", 64 * 1024)
        for msg, handlers in sorted_pairs(message_to_staticfuncs) do
            out:append("OnMsg.", msg, "\n")
            for _, handler in ipairs(handlers) do
                local info = debug.getinfo(handler, "S")
                out:append("\t", info.short_src or "???")
                if lines then
                    out:append("(", info.linedefined or "?", ")\n")
                else
                    out:append("\n")
                end
            end
            out:append("\n\n")
        end
        local err = AsyncStringToFile(file, out)
        if err then
            print("Error writing", file, err)
        end
        return err, out
    end
end

-- syntax
-- function OnMsg.<message>(...) end
-- OnMsg.<message> = function(...) end

---
--- Represents a table of message handlers.
---
--- This table is used to store and manage message handlers that are registered using the `OnMsg` syntax.
--- Message handlers can be added to this table using the `__newindex` metamethod, which automatically
--- appends new handlers to the list of handlers for a given message.
---
--- The `MsgClear` function can be used to remove all static message handlers for a specified message.
---
--- The `DumpMsgHandlers` function can be used to write the currently registered message handlers to a file.
---
OnMsg = {}
---
--- Provides a metatable for the `OnMsg` table that automatically appends new message handlers to the list of handlers for a given message.
---
--- When a new key-value pair is added to the `OnMsg` table, the `__newindex` metamethod is called, which checks if there is an existing list of handlers for the given message. If so, it appends the new handler to the list. If not, it creates a new list with the new handler.
---
--- This allows message handlers to be easily registered using the `OnMsg` syntax, without having to manually manage the list of handlers for each message.
---
setmetatable(OnMsg, {__newindex=function(_, message, func)
    local funcs = message_to_staticfuncs[message]
    if funcs then
        funcs[#funcs + 1] = func
    else
        message_to_staticfuncs[message] = {func}
    end
end})

---
--- Stops the current thread and removes it from the thread registry.
---
--- This function is used to halt the execution of the current thread. It removes the thread from the thread registry, effectively removing it from the game's main loop.
---
--- @function Halt
--- @return void
function Halt()
    DeleteThread(CurrentThread(), true)
end

---
--- Clears all game threads that are registered with the `threadOnMap` flag.
---
--- This function iterates through the `ThreadsRegister` table, which contains all the registered threads, and deletes any threads that have the `threadOnMap` flag set. This is typically used to clean up all the threads that were created for the current map when the map is changed or the game is loaded.
---
--- @function ClearGameThreads
--- @return void
function ClearGameThreads()
    for thread in pairs(ThreadsRegister) do
        if ThreadHasFlags(thread, threadOnMap) then
            DeleteThread(thread)
        end
    end
end

---
--- Called when a new map is about to be loaded.
---
--- This function resets the game time and updates the render engine time when a new map is loaded.
---
--- @function OnMsg.PreNewMap
--- @return void
function OnMsg.PreNewMap()
    ResetGameTime()
    UpdateRenderEngineTime()
end

---
--- Called when a new map has finished loading.
---
--- This function resets the game time and updates the render engine time when a new map has finished loading.
---
--- @function OnMsg.PostDoneMap
--- @return void
function OnMsg.PostDoneMap()
    -- reset game time
    assert(not IsGameTimeThread())
    ClearGameThreads()
    ResetGameTime()
    UpdateRenderEngineTime()
end

---
--- Called when the game is loaded.
---
--- This function updates the render engine time when the game is loaded.
---
--- @function OnMsg.LoadGame
--- @return void
function OnMsg.LoadGame()
    UpdateRenderEngineTime()
end

---
--- Handles errors that occur in a thread.
---
--- @param thread table The thread that encountered the error.
--- @param err string The error message.
---
function ThreadErrorHandler(thread, err)
    err = string.match(tostring(err), ".-%.lua:%d+: (.*)") or err
    error(thread, err)
end

--- Stop game time advancement.
-- @cstyle void Pause(reason).
-- @return void.

---
--- Pauses the game and optionally pauses sounds.
---
--- @param reason string|boolean The reason for pausing the game. If false, the reason is not recorded.
--- @param keepSounds boolean If true, sounds will not be paused.
--- @return void
function Pause(reason, keepSounds)
    reason = reason or false
    if next(PauseReasons) == nil then
        PauseGame()
        if not keepSounds then
            PauseSounds(1, true)
        end
        Msg("Pause", reason)
        PauseReasons[reason] = true
        if IsGameTimeThread() and CanYield() then
            InterruptAdvance()
        end
    else
        PauseReasons[reason] = true
    end
end

--- Resume game time advancement.
-- @cstyle void Resume(reason).
-- @return void.

---
--- Resumes the game and optionally resumes sounds.
---
--- @param reason string|boolean The reason for resuming the game. If false, the reason is not recorded.
--- @return void
function Resume(reason)
    reason = reason or false
    if PauseReasons[reason] ~= nil then
        PauseReasons[reason] = nil
        if next(PauseReasons) == nil then
            ResumeGame()
            ResumeSounds(1)
            Msg("Resume", reason)
        end
    end
end

--- Returns if game is paused.
-- @cstyle bool IsPaused().
-- @return true; if the tame is pause, false otherwise.
--- Checks if the game is paused.
---
--- This function is only available when not running from the command line.
---
--- @return boolean true if the game is paused, false otherwise
function IsPaused()
    return GetGamePause()
end
if not Platform.cmdline then
    IsPaused = GetGamePause
end

---
--- Toggles the game pause state.
---
--- If the game is currently paused due to the "UI" reason, this function will resume the game.
--- Otherwise, it will pause the game with the "UI" reason and return true.
---
--- @return boolean true if the game was paused, false if the game was resumed
function TogglePause()
    if PauseReasons["UI"] then
        Resume("UI")
    else
        Pause("UI")
        return true
    end
end

---
--- Returns a comma-separated string of the current pause reasons.
---
--- @return string A comma-separated string of the current pause reasons.
function _GetPauseReasonsStr()
    local list = {}
    for reason in pairs(PauseReasons) do
        list[#list + 1] = type(reason) == "table" and reason.class or tostring(reason)
    end
    table.sort(list)
    return table.concat(list, ", ")
end

--- Called when a bug report is about to be generated.
--
-- This function is called when a bug report is about to be generated. If there are any active pause reasons, it will print them to the bug report.
--
-- @param print_func A function that can be used to print information to the bug report.
function OnMsg.BugReportStart(print_func)
    if next(PauseReasons) ~= nil then
        print_func("Active pause reasons:", _GetPauseReasonsStr())
    end
end

--- Toggles between normal and high (x10) speed.
-- @cstyle void ToggleHighSpeed().
-- @return void.

---
--- Toggles between normal and high (x10) speed.
---
--- If the current time factor is the default, this function will set the time factor to 10 times the default.
--- Otherwise, it will set the time factor back to the default.
---
--- @param sync boolean (optional) If true, the time factor change will be synchronized across clients. Defaults to false.
--- @return void
function ToggleHighSpeed(sync)
    if GetTimeFactor() ~= const.DefaultTimeFactor then
        SetTimeFactor(const.DefaultTimeFactor, sync)
    else
        SetTimeFactor(const.DefaultTimeFactor * 10, sync)
    end
end

---
--- Makes the given thread persistent, preventing it from being deleted when the outer thread is deleted.
---
--- @param thread thread The thread to make persistent.
--- @return void
function MakeThreadPersistable(thread)
    ThreadSetFlags(thread, threadPersist)
end

-- Use this when a waiting function must not be interrupted (i.e. by deleting the outer thread)
---
--- Waits for a real-time thread to complete and returns its result.
---
--- This function creates a new real-time thread that calls the provided function `f` with the given arguments `...`. It then waits for the thread to complete and returns the result.
---
--- @param f function The function to be executed in the real-time thread.
--- @param ... any The arguments to be passed to the function `f`.
--- @return any The result of the function `f`.
function WaitRealTimeThread(f, ...)
    local params = pack_params(...)
    local thread
    thread = CreateRealTimeThread(function()
        Msg(thread, f(unpack_params(params)))
    end)
    return select(2, WaitMsg(thread))
end


---
--- Initializes a table to store threads waiting for a single execution of a function.
---
--- This code is executed on the first load of the module. It creates a new table `ThreadsWaitingSingle` and sets its metatable to use weak values, allowing the garbage collector to remove entries when the threads are no longer referenced.
---
--- @module CommonLua.Core.cthreads
--- @within CommonLua.Core
--- @usage
--- 
if FirstLoad then
    ThreadsWaitingSingle = {}
    setmetatable(ThreadsWaitingSingle, {__mode="v"})
end

-- Same as WaitRealTimeThread, but makes sure only one copy of the inner function is running
---
--- Waits for a single execution of the given function `f` to complete and returns its result.
---
--- This function creates a new real-time thread that calls the provided function `f` with the given arguments `...`. If a thread for `f` already exists, it waits for that thread to complete and returns the result. Otherwise, it creates a new thread and stores it in the `ThreadsWaitingSingle` table, which uses weak values to allow the garbage collector to remove entries when the threads are no longer referenced.
---
--- @param f function The function to be executed in the real-time thread.
--- @param ... any The arguments to be passed to the function `f`.
--- @return any The result of the function `f`.
function WaitSingleRealTimeThread(f, ...)
    local thread = ThreadsWaitingSingle[f]
    if not thread then
        local params = pack_params(...)
        thread = CreateRealTimeThread(function()
            Msg(thread, f(unpack_params(params)))
            ThreadsWaitingSingle[f] = nil
        end)
        ThreadsWaitingSingle[f] = thread
    end
    return select(2, WaitMsg(thread))
end

----

--- Waits for the specified game time to elapse.
---
--- This function waits for the specified game time to elapse, using the current time factor to determine the actual sleep duration. If the game time thread is being used, it simply sleeps for the remaining time. Otherwise, it waits by repeatedly checking the game time and sleeping for short intervals until the target time is reached.
---
--- @param end_time number The game time at which to return.
function WaitGameTime(end_time)
    assert(CanYield())
    if not CanYield() then
        return
    end
    if IsGameTimeThread() then
        Sleep(end_time - GameTime())
        return
    end
    while true do
        local factor = Max(1, GetTimeFactor())
        local sleep = Min(50, MulDivRound(end_time - GameTime(), 1000, factor))
        if sleep <= 0 then
            break
        end
        WaitMsg("ChangeGameSpeed", sleep)
    end
end

---
--- Configures the Backtrace setting based on the current platform.
---
--- If the `config.Backtrace` setting is `nil`, it is set to `true` if the current platform is a PC, is not a command-line application, and is in developer mode. Otherwise, it is set to `false`.
---
--- This setting determines whether the application should generate a backtrace when an error occurs.
---
--- @param config table The configuration table to update.
if config.Backtrace == nil then
    config.Backtrace = Platform.pc and not Platform.cmdline and Platform.developer
end

--- Resolves the appropriate thread debug hook to use based on the current configuration and state.
---
--- This function checks the current state of the application, including whether there are any suspended debug hook reasons, whether the heatmap profiler or function profiler is enabled, whether the Lua debugger is active, and whether backtracing is enabled. It then returns the appropriate debug hook function to use, which may be one of the following:
---
--- - `SetBacktraceHook`: Used when the heatmap profiler, function profiler, or backtrace setting is enabled.
--- - `DebuggerSetHook`: Used when the Lua debugger is active.
--- - `SetInfiniteLoopDetectionHook`: Used when infinite loop detection is enabled.
---
--- If there are any suspended debug hook reasons, this function will return `nil`, indicating that no debug hook should be used.
---
--- @return function|nil The appropriate debug hook function to use, or `nil` if no debug hook should be used.
function ResolveThreadDebugHook()
    if next(SuspendDebugHookReasons) then
        return
    end
    local SetBacktraceHook = rawget(_G, "SetBacktraceHook")
    if SetBacktraceHook and (config.HeatmapProfile or config.FunctionProfiler) then
        return SetBacktraceHook
    end
    local DebuggerSetHook = rawget(_G, "DebuggerSetHook")
    local DAServer = rawget(_G, "DAServer")
    if DebuggerSetHook and (rawget(_G, "g_LuaDebugger") or (DAServer and DAServer.listen_socket)) then
        return DebuggerSetHook
    end
    if SetBacktraceHook and config.Backtrace then
        return SetBacktraceHook
    end
    local SetInfiniteLoopDetectionHook = rawget(_G, "SetInfiniteLoopDetectionHook")
    if SetInfiniteLoopDetectionHook then
        return SetInfiniteLoopDetectionHook
    end
end

---
--- Sets the debug hook for all registered threads.
---
--- This function sets the debug hook for all registered threads in the `ThreadsRegister` table. If a `hook` function is provided, it is used as the debug hook. Otherwise, the default `debug.sethook` function is used.
---
--- After setting the debug hook for all registered threads, the function also sets the debug hook for the current thread and calls `ThreadsEnableDebugHook` to enable the debug hook for all registered threads.
---
--- The `ThreadDebugHook` variable is set to the provided `hook` function, or `false` if no hook was provided.
---
--- @param hook function|nil The debug hook function to set for all registered threads, or `nil` to use the default `debug.sethook` function.
function SetThreadDebugHook(hook)
    local set_hook = hook or debug.sethook
    for thread, _ in pairs(ThreadsRegister) do
        set_hook(thread)
    end
    set_hook()
    ThreadsEnableDebugHook(hook)
    ThreadDebugHook = hook or false
end

---
--- Updates the debug hook for all registered threads.
---
--- This function first retrieves the current debug hook using `GetThreadDebugHook()`. It then calls `ResolveThreadDebugHook()` to determine the appropriate debug hook function to use based on the current state of the application (e.g. whether profiling or debugging is enabled).
---
--- If the new debug hook function is different from the current one, `SetThreadDebugHook()` is called to update the debug hook for all registered threads.
---
--- This function is used to ensure that the debug hook is properly set for all threads, and that it is updated when the application's state changes.
---
--- @function UpdateThreadDebugHook
function UpdateThreadDebugHook()
    local old_hook = GetThreadDebugHook()
    local new_hook = ResolveThreadDebugHook()
    if old_hook ~= new_hook then
        SetThreadDebugHook(new_hook)
    end
end

---
--- Suspends the debug hook for all registered threads.
---
--- This function adds the provided `reason` to the `SuspendDebugHookReasons` table, and then calls `UpdateThreadDebugHook()` to update the debug hook for all registered threads.
---
--- This function is used to temporarily suspend the debug hook for all registered threads, for example when the application is in a state where the debug hook should not be active (e.g. during profiling).
---
--- @param reason string|boolean The reason for suspending the debug hook, or `false` if no specific reason is provided.
function SuspendThreadDebugHook(reason)
    reason = reason or false
    SuspendDebugHookReasons[reason] = true
    UpdateThreadDebugHook()
end

---
--- Resumes the debug hook for all registered threads.
---
--- This function removes the provided `reason` from the `SuspendDebugHookReasons` table, and then calls `UpdateThreadDebugHook()` to update the debug hook for all registered threads.
---
--- This function is used to resume the debug hook for all registered threads, for example when the application is no longer in a state where the debug hook should be suspended (e.g. after profiling has completed).
---
--- @param reason string|boolean The reason for resuming the debug hook, or `false` if no specific reason is provided.
function ResumeThreadDebugHook(reason)
    reason = reason or false
    SuspendDebugHookReasons[reason] = nil
    UpdateThreadDebugHook()
end

---
--- Iterates over the upvalues and local variables of a given thread, calling a callback function for each one.
---
--- This function uses the Lua debug API to retrieve information about the upvalues and local variables of the specified thread. It calls the provided `callback` function for each upvalue and local variable, passing the name, value, and any additional arguments provided.
---
--- The callback function should return `true` to stop the iteration, or `false` to continue.
---
--- @param thread thread The thread to inspect.
--- @param callback function The callback function to call for each upvalue and local variable.
--- @param ... any Additional arguments to pass to the callback function.
--- @return boolean True if the iteration was stopped by the callback function, false otherwise.
function ForEachThreadUpvalue(thread, callback, ...)
    local getinfo = debug.getinfo
    local getupvalue = debug.getupvalue
    local getlocal = debug.getlocal
    local level = 0
    while getinfo(thread, level + 1, "l") do
        level = level + 1
    end
    for l = level, 1, -1 do
        local info = getinfo(thread, l, "Snlf")
        if not info then
            break
        end
        if info.func then
            local idx = 1
            while true do
                local name, value = getupvalue(info.func, idx)
                if not name then
                    break
                end
                if value and callback(name, value, ...) then
                    return true
                end
                idx = idx + 1
            end
        end
        local idx = 1
        while true do
            local name, value = getlocal(thread, l, idx)
            if not name then
                break
            end
            if value and callback(name, value, ...) then
                return true
            end
            idx = idx + 1
        end
    end
end

--- Returns the current thread debug hook.
---
--- The thread debug hook is a function that is called whenever a thread is resumed or suspended. It can be used to monitor and debug the execution of threads.
---
--- @return function The current thread debug hook.
function GetThreadDebugHook()
    return ThreadDebugHook
end
---
--- Periodically reports thread profiling information to the console.
---
--- This function is called in a real-time thread that runs every 1000 milliseconds.
--- It collects profiling data for all registered threads, separating real-time and game-time threads.
--- The profiling data includes the number of threads, resumes, total time, memory allocations, and memory usage.
---
--- The reporting behavior is controlled by the `ReportThreads` global variable:
--- - If `ReportThreads` is `"full"`, all threads are reported regardless of their impact.
--- - If `ReportThreads` is `"short"`, only threads with a significant impact (time > 100ms or allocations > 200) are reported.
--- - If `ReportThreads` is `false` or any other value, no reporting is done.
---
--- The reported information is formatted in a table with columns for thread name, number of threads, resumes, time, allocations, and memory usage.
--- At the end, the totals for real-time and game-time threads are also reported.
---
--- This function is only executed if the game is not in the `goldmaster` or `cmdline` mode, and only on the first load of the game.

if FirstLoad and not Platform.goldmaster and not Platform.cmdline then

    ReportThreads = false

    CreateRealTimeThread(function()
        while true do
            Sleep(1000)
            if (ReportThreads == "full" or ReportThreads == "short") and not IsPaused() then
                local rt_threads, rt_resumes, rt_time, rt_allocs, rt_mem = 0, 0, 0, 0, 0
                local gt_threads, gt_resumes, gt_time, gt_allocs, gt_mem = 0, 0, 0, 0, 0
                local threads = {}
                for thread, src in pairs(ThreadsRegister) do
                    local resumes, time, allocs, mem = ThreadProfilerData(thread, "reset")
                    if not resumes then
                        return
                    end -- profiler is not active
                    local info = threads[src]
                    if info then
                        info.threads = info.threads + 1
                        info.resumes = info.resumes + resumes
                        info.time = info.time + time
                        info.allocs = info.allocs + allocs
                        info.mem = info.mem + mem
                    else
                        threads[src] = {name=src, threads=1, resumes=resumes, time=time, allocs=allocs, mem=mem}
                    end
                    if IsRealTimeThread(thread) then
                        rt_threads = rt_threads + 1
                        rt_resumes = rt_resumes + resumes
                        rt_time = rt_time + time
                        rt_allocs = rt_allocs + allocs
                        rt_mem = rt_mem + mem
                    else
                        gt_threads = gt_threads + 1
                        gt_resumes = gt_resumes + resumes
                        gt_time = gt_time + time
                        gt_allocs = gt_allocs + allocs
                        gt_mem = gt_mem + mem
                    end
                end
                local list = {}
                local skipped = 0
                for src, info in pairs(threads) do
                    if ReportThreads == "full" or info.time > 100 or info.allocs > 200 then
                        table.insert(list, info)
                    else
                        skipped = skipped + 1
                    end
                end

                cls()
                print(
                    "<tab 400 right>threads<tab 470 right>resumes<tab 540 right>time<tab 610 right>allocs<tab 680 right>mem<tab 750 right>")
                table.sortby_field_descending(list, "time")
                for i = 1, #list do
                    local t = list[i]
                    local suffix = t.name:sub(1, 6) == "<color" and "</color>" or ""
                    printf(
                        "%s<tab 400 right>%d<tab 470 right>%d<tab 540 right>%d<tab 610 right>%d<tab 680 right>%d<tab 750 right>%s",
                        t.name, t.threads, t.resumes, t.time, t.allocs, t.mem, suffix)
                end
                if skipped > 0 then
                    printf("Skipped %d low impact threads, type ReportThreads='full' to see all", skipped)
                end
                printf("real time threads %d, resumes %d, time %d, allocs %d, mem %d", rt_threads, rt_resumes, rt_time,
                    rt_allocs, rt_mem)
                printf("game time threads %d, resumes %d, time %d, allocs %d, mem %d", gt_threads, gt_resumes, gt_time,
                    gt_allocs, gt_mem)
            end
        end
    end)

end -- ReportThreads

---
--- Gathers a set of permanent functions and values related to the cthreads module.
---
--- This function is called by the game engine to gather a set of permanent functions and values
--- that should be preserved across game sessions. The functions and values gathered here
--- are used to restore the state of the cthreads module when the game is loaded.
---
--- @param permanents table A table that the permanent functions and values should be added to.
--- @param direction string The direction of the persistence, either "save" or "load".
---
function OnMsg.PersistGatherPermanents(permanents, direction)
    permanents["cthread.CreateRealTimeThread"] = CreateRealTimeThread
    permanents["cthread.CreateMapRealTimeThread"] = CreateMapRealTimeThread
    permanents["cthread.LaunchRealTimeThread"] = LaunchRealTimeThread
    permanents["cthread.CreateGameTimeThread"] = CreateGameTimeThread
    permanents["cthread.ThreadDebugHook"] = ThreadDebugHook
    permanents["cthread.Sleep"] = Sleep
    permanents["cthread.GameTime"] = GameTime
    permanents["cthread.DeleteThread"] = DeleteThread
    permanents["cthread.InterruptAdvance"] = InterruptAdvance
    permanents["cthread.WaitWakeup"] = WaitWakeup
    permanents["cthread.WaitMsg"] = WaitMsg
    permanents["cthread.PlayState"] = CObject.PlayState -- this is another sleeping function found in the thread stack
end

---
--- Saves the state of the cthreads module when the game is saved.
---
--- This function is called by the game engine when the game is being saved. It gathers the
--- necessary information about the cthreads module, such as the current game time and the
--- state of all persistent threads, and stores it in the provided data table. This data
--- can then be used to restore the state of the cthreads module when the game is loaded.
---
--- @param data table The table to store the persistent data in.
---
function OnMsg.PersistSave(data)
    assert(not ThreadHasFlags(CurrentThread(), threadPersist))

    data["cthreads.time"] = GameTime()
    -- all persistable threads in an array {thread, flags, [src], [time], ...}
    data["cthreads.threads"] = ThreadsPersistSave()

    -- presistable threads waiting on a message
    -- preserve the order of the waiting threads
    local message_threads = {}
    for message, threads in pairs(ThreadsMessageToThreads) do
        local t
        for i = 1, #threads do
            local thread = threads[i]
            if ThreadHasFlags(thread, threadPersist) then
                t = t or {}
                t[#t + 1] = thread
            end
        end
        message_threads[message] = t
    end
    data["cthreads.message_threads"] = message_threads
end

---
--- Loads the state of the cthreads module when the game is loaded.
---
--- This function is called by the game engine when the game is being loaded. It restores the
--- state of the cthreads module, including the current game time and the state of all
--- persistent threads, from the provided data table. This allows the game to continue
--- running from the saved state.
---
--- @param data table The table containing the persistent data to load.
---
function OnMsg.PersistLoad(data)
    ClearGameThreads()
    ResetGameTime(data["cthreads.time"])
    ThreadsPersistLoad(data["cthreads.threads"])

    -- threads waiting on a message
    local message_threads = data["cthreads.message_threads"]
    local message_to_threads = ThreadsMessageToThreads
    local thread_to_message = ThreadsThreadToMessage
    for message, threads in pairs(message_threads) do
        local threads_array = message_to_threads[message]
        if not threads_array then
            threads_array = {}
            message_to_threads[message] = threads_array
        end
        for i = 1, #threads do
            local thread = threads[i]
            threads_array[#threads_array + 1] = thread
            thread_to_message[thread] = message
        end
    end
end

----------- thread lock/unlock key

---
--- Stores the current thread that holds a lock for a given key.
---
--- This table maps lock keys to the current thread that holds the lock for that key.
---
ThreadLockThreads = rawget(_G, "ThreadLockThreads") or {}
ThreadLockWaitingThreads = rawget(_G, "ThreadLockWaitingThreads") or {}

---
--- Attempts to acquire a lock on the given key. If the lock is already held by another thread, the current thread will be added to a waiting queue for that key.
---
--- @param key string The key to acquire a lock on.
--- @param timeout number (optional) The maximum time in seconds to wait for the lock before returning false.
--- @return boolean True if the lock was successfully acquired, false otherwise.
---
function ThreadLockKey(key, timeout)
    if not CanYield() then
        return false
    end
    local thread = ThreadLockThreads[key]
    if IsValidThread(thread) then
        local waiting_threads = ThreadLockWaitingThreads[key]
        if waiting_threads then
            waiting_threads[#waiting_threads + 1] = CurrentThread()
        else
            waiting_threads = {CurrentThread()}
            ThreadLockWaitingThreads[key] = waiting_threads
        end
        local success = WaitWakeup(timeout)
        table.remove_entry(waiting_threads, CurrentThread())
        if not waiting_threads[1] and ThreadLockWaitingThreads[key] == waiting_threads then
            ThreadLockWaitingThreads[key] = nil
        end
        return success
    end
    ThreadLockThreads[key] = CurrentThread()
    return true
end

---
--- Unlocks a thread lock for the given key.
---
--- If the current thread holds the lock for the given key, this function will remove the lock and wake up the next waiting thread (if any) to acquire the lock.
---
--- @param key string The key to unlock.
--- @return any The return values of the function that originally acquired the lock.
---
function ThreadUnlockKey(key, ...)
    if CurrentThread() == ThreadLockThreads[key] then
        local waiting_threads = ThreadLockWaitingThreads[key]
        local thread = waiting_threads and waiting_threads[1]
        if waiting_threads then
            table.remove(waiting_threads, 1)
        end
        thread = IsValidThread(thread) and thread or nil
        ThreadLockThreads[key] = thread
        Wakeup(thread)
    end
    return ...
end

--- Disables the Lua debug hook if the `config.DisableLuaHooks` flag is set.
---
--- This function is used to suspend the Lua debug hook when the `config.DisableLuaHooks` flag is enabled. This can be useful for improving performance or disabling certain debugging features.
---
--- @param key string The key to acquire a lock on.
--- @param timeout number (optional) The maximum time in seconds to wait for the lock before returning false.
--- @return boolean True if the lock was successfully acquired, false otherwise.
if config.DisableLuaHooks then
    SuspendThreadDebugHook("config.DisableLuaHooks")
end
