---
--- Defines a class named "TestValidator".
---
--- This class is likely used for testing or validation purposes, but its specific functionality is not clear from the provided code snippet.
---
--- @class TestValidator
--- @field [parent=#TestValidator]
DefineClass("TestValidator")

IsGameReplayRunning = empty_func

if Platform.developer then
	RecursiveCallMethods.GetTestData = "call"
end

---
--- Checks if game recording is supported.
---
--- @return boolean true if game recording is supported, false otherwise
function IsGameRecordingSupported()
    return config.SupportGameRecording and Libs.Network == "sync"
end

GameRecordVersion = 2

---
--- Applies the specified record version by setting the appropriate constants.
---
--- @param record table|nil The game record to apply the version for. If nil, the current version is used.
function ApplyRecordVersion(record)
    local version = not record and GameRecordVersion or record.version or 1
    if version == GameRecordCurrentVersion then
        return
    end
    GameRecordCurrentVersion = version
    if version == 1 then
        RECORD_GTIME = 1
        RECORD_EVENT = 2
        RECORD_PARAM = 3
        -- RECORD_RAND = 4
        -- RECORD_HANDLE = 5
        RECORD_RTIME = 6
        RECORD_ETYPE = 7
        -- RECORD_HASH = 8
        RECORD_SPEED = 9
    else
        RECORD_GTIME = 1
        RECORD_EVENT = 2
        RECORD_PARAM = 3
        RECORD_RTIME = 4
        RECORD_ETYPE = 5
        RECORD_SPEED = 6
    end
end

if FirstLoad then
	GameRecordCurrentVersion = false
	ApplyRecordVersion()
end

config.GameRecordsPath = "AppData/GameRecords"
local records_path = config.GameRecordsPath

---
--- Declares global variables for game record and replay state.
---
--- @global GameRecord boolean Indicates if a game record is currently active.
--- @global GameReplay boolean Indicates if a game replay is currently running.
--- @global GameReplayThread thread The thread running the game replay.
MapVar("GameRecord", false) -- to be available in the saves
MapVar("GameReplay", false)
MapVar("GameReplayThread", false)

if FirstLoad then
	GameRecordScheduled = false
	
	GameReplayScheduled = false
	GameReplayPath = false
	GameReplaySaveLoading = false
	GameReplayUnresolved = false
	GameReplayWaitMap = false
	GameReplayToInject = false
	GameReplayFastForward = false

	GameRecordSaveRequests = false
end

---
--- Checks if a game replay is currently running.
---
--- @return boolean true if a game replay is running, false otherwise
---
function IsGameReplayRunning()
    return IsValidThread(GameReplayThread) and GameReplay
end

---
--- Checks if game recording is supported. If not, the function returns early.
---
--- @return boolean true if game recording is supported, false otherwise
---
if not IsGameRecordingSupported() then
    return
end

local IsGameReplayRunning = IsGameReplayRunning

function OnMsg.ChangeMap()
	GameReplayPath = false
	GameRecordScheduled = false
	StopGameReplay()
end
 
---
--- Handles the new map loading event, starting game recording if it was scheduled.
---
--- @global GameRecord boolean Indicates if a game record is currently active.
--- @global GameRecordScheduled boolean Indicates if a game record was scheduled to start.
---
function OnMsg.NewMapLoaded()
    GameReplay = false
    GameRecord = GameRecordScheduled
    GameRecordScheduled = false
    if not not GameRecord then
        Msg("GameRecordingStarted")
    end
end

---
--- Handles the event when a network game is joined.
---
--- This function is called when a network game is joined. It sets the `GameRecord` flag to `false`, indicating that no game recording is currently active.
---
function OnMsg.NetGameJoined()
	GameRecord = false
end

---
--- Handles the event when the game tests begin.
---
--- This function is called when the game tests begin. It sets the `EnableGameRecording` configuration to `false`, disabling game recording during the game tests.
---
--- @param auto_test boolean Indicates if the game tests were run automatically.
---
function OnMsg.GameTestsBegin(auto_test)
    table.change(config, "GameTests_GameRecording", {EnableGameRecording=false})
end

---
--- Handles the event when the game tests end.
---
--- This function is called when the game tests end. It restores the `GameTests_GameRecording` configuration to its original state.
---
--- @param auto_test boolean Indicates if the game tests were run automatically.
---
function OnMsg.GameTestsEnd(auto_test)
    table.restore(config, "GameTests_GameRecording", true)
end

---
--- Serializes the given parameters using the custom serialization functions.
---
--- @param ... any The parameters to serialize.
--- @return string The serialized parameters.
---
function SerializeRecordParams(...)
    return SerializeEx(const.SerializeCustom, CustomSerialize, ...)
end

---
--- Deserializes the given serialized parameters using the custom deserialization functions.
---
--- @param params_str string The serialized parameters.
--- @return any The deserialized parameters.
---
function UnserializeRecordParams(params_str)
	return UnserializeEx(const.SerializeCustom, CustomUnserialize, params_str)
end

---
--- Prepares the given game record for saving by setting the `game_time` field to the current game time.
---
--- @param record table The game record to prepare for saving. If not provided, the `GameRecord` global variable is used.
---
function PrepareRecordForSaving(record)
    record = record or GameRecord
    if record ~= GameRecord then
        return
    end
    record.game_time = GameTime()
end

---
--- Plays a recorded game session.
---
--- This function is responsible for replaying a recorded game session. It takes a game record object and an optional start index, and plays back the recorded events in the correct order and timing.
---
--- @param record table The game record to play back. If not provided, the `GameReplayScheduled` global variable is used.
--- @param start_idx number (optional) The index of the first event to play back. If not provided, the playback starts from the beginning of the record.
---
function PlayGameRecord(record, start_idx)
    record = record or GameReplayScheduled
    if not record then
        return
    end
    assert(IsGameTimeThread())
    assert(record.start_rand == MapLoadRandom)
    start_idx = start_idx or 1
    GameReplay = record
    GameReplayScheduled = false
    GameReplaySaveLoading = false
    GameReplayThread = CurrentThread()
    if GameReplayWaitMap then
        WaitWakeup() -- ensure the map loading is complete
    end
    ApplyRecordVersion(record)
    local desync_any
    local total_time = Max((record[#record] or empty_table)[RECORD_GTIME] or 0, record.game_time or 0)
    local start_time = GameTime()
    if start_idx > #record or start_time > record[start_idx][RECORD_GTIME] then
        GameTestsPrint("Replay injection start mismatch!")
        start_idx = 1
        while start_idx <= #record and start_time > record[start_idx][RECORD_GTIME] do
            start_idx = start_idx + 1
        end
    end
    local version = record.version or 1
    GameTestsPrint("Replay start at", Min(start_idx, #record), "/", #record, "events", "|", start_time, "/", total_time,
        "ms", "|", "Lua rev", record.lua_rev or 0, "/", LuaRevision, "|", "assets rev", record.assets_rev or 0, "/",
        AssetsRevision)
    for i = start_idx, #record do
        local event_time = record[i][RECORD_GTIME]
        local delay = event_time - now()
        local yield
        if delay > 0 then
            yield = record[i][RECORD_SPEED] == 0
            Sleep(delay)
        else
            local last_record = record[i - 1]
            local prev_real_time = last_record and last_record[RECORD_RTIME] or record.real_time
            yield = prev_real_time ~= record[i][RECORD_RTIME]
        end
        if yield then
            -- make sure all game time threads created by the previous event have been started 
            WaitAllOtherThreads()
        end
        if GameReplayThread ~= CurrentThread() or GameReplay ~= record then
            return
        end
        print("Replay", i, '/', #record)
        CreateGameTimeThread(function(record, i)
            local entry = record[i]
            local event, params_str = entry[RECORD_EVENT], entry[RECORD_PARAM]
            GameReplayUnresolved = false
            local success, err = ExecuteSyncEvent(event, UnserializeRecordParams(params_str))
            if not success then
                GameTestsError("Replay", i, '/', #record, event, err)
            end
            if GameReplayUnresolved then
                GameTestsPrint("Replay", i, '/', #record, event, "unresolved objects:")
                for _, data in ipairs(GameReplayUnresolved) do
                    local handle, class, pos = table.unpack(data)
                    GameTestsPrint("\t", class, handle, "at", pos)
                end
            end
            Msg("GameRecordPlayed", i, record)
        end, record, i)
    end
    Sleep((record.game_time or 0) - now())
    Sleep(0)
    Sleep(0)
    Sleep(0)
    Sleep(0)

    GameTestsPrint("Replay finished")
    Msg("GameReplayEnd", record)
end

local function IsSameClass(obj, class)
	if not obj then
		return -- object handle changed or object not yet spawned
	end
	if not class or obj.class == class then
		return true
	end
	local classdef = g_Classes[class]
	return not classdef or IsKindOf(classdef, obj.class) or IsKindOf(obj, class) -- recorded class renamed
end

---
--- Serializes an object for recording in the game replay system.
---
--- This function checks if the object is a valid sync object, and if so, adds its handle and class to the record's handles table. It then returns a table containing the object's handle, class, and position.
---
--- @param obj table The object to serialize.
--- @return table|nil A table containing the object's handle, class, and position, or nil if the object is not a valid sync object.
---
function CustomSerialize(obj)
    local handle = obj.handle
    if handle and IsValid(obj) and obj:IsValidPos() then
        if obj:GetGameFlags(const.gofSyncObject | const.gofPermanent) == 0 then
            StoreErrorSource(obj, "Async object in sync event")
        end
        local record = GameRecord
        local handles = record and record.handles
        if handles then
            local class = obj.class
            handles[handle] = class
            return {handle, class, obj:GetPos()}
        end
    end
end

---
--- Unserializes an object from a game replay record.
---
--- This function takes a table containing the handle, class, and position of an object, and attempts to find the corresponding object in the game world. If the object is found and is of the same class, it is returned. If the object is not found, the function attempts to find an object of the same class at the recorded position. If that fails, the function adds the table to the `GameReplayUnresolved` table for later resolution.
---
--- @param tbl table A table containing the handle, class, and position of an object.
--- @return table|nil The object corresponding to the input table, or `nil` if the object could not be found or resolved.
---
function CustomUnserialize(tbl)
    local handle, class, pos = table.unpack(tbl)
    local obj = HandleToObject[handle]
    if IsSameClass(obj, class) then
        return obj
    end
    local map_obj = MapGetFirst(pos, 0, class)
    if map_obj then
        return map_obj
    end
    GameReplayUnresolved = table.create_add(GameReplayUnresolved, tbl)
end

---
--- Overrides the specified game event with a custom implementation that records the event parameters during normal gameplay, and ignores the event during game replay.
---
--- @param event_type string The name of the game event to override.
---
function CreateRecordedEvent(event_type)
    local origGameEvent = _G[event_type]
    _G[event_type] = function(event, ...)
        if IsGameReplayRunning() then
            if not config.GameReplay_EventsDuringPlaybackExpected then
                print("Ignoring", event_type, event, "during replay!")
            end

            return
        end
        local record = GameRecord
        if record then
            local params, err = SerializeRecordParams(...)
            assert(params, err)
            CreateGameTimeThread(function(event, event_type, record, params)
                -- in a thread to have the correct sync values (as the event will be started in a thread)
                local time = GameTime()
                local n = #record
                while n > 0 and record[n][RECORD_GTIME] > time do
                    record[n] = nil
                    n = n - 1
                end
                n = n + 1
                record[n] = {[RECORD_GTIME]=time, [RECORD_EVENT]=event, [RECORD_PARAM]=params,
                    [RECORD_RTIME]=RealTime(), [RECORD_ETYPE]=event_type, [RECORD_SPEED]=GetTimeFactor()}
                if config.GameRecordingAutoSave then
                    SaveGameRecord()
                end
            end, event, event_type, record, params)
        end
        return origGameEvent(event, ...)
    end
end

---
--- Overrides the `InitMapLoadRandom` function to record the random seed used during normal gameplay, and replay the recorded random seed during game replay.
---
--- This function is called by `RegisterGameRecordOverrides` to set up the game recording functionality.
---
--- @function CreateRecordedMapLoadRandom
--- @return number The random seed used for map loading.
function CreateRecordedMapLoadRandom()
    local origInitMapLoadRandom = InitMapLoadRandom
    InitMapLoadRandom = function()
        local rand
        if GameReplayScheduled then
            CreateGameTimeThread(PlayGameRecord)
            rand = GameReplayScheduled.start_rand
        else
            rand = origInitMapLoadRandom()
            if mapdata and mapdata.GameLogic and config.EnableGameRecording then
                assert(Game)
                assert(not IsGameReplayRunning())
                GameReplay = false
                GameRecordScheduled = {start_rand=rand, map_name=GetMapName(), map_hash=mapdata.NetHash,
                    os_time=os.time(), real_time=RealTime(), game=CloneObject(Game), lua_rev=LuaRevision,
                    assets_rev=AssetsRevision, handles={}, version=GameRecordVersion,
                    net_update_hash=config.DebugReplayDesync}
                Msg("GameRecordScheduled")
            end
        end
        return rand
    end
end

---
--- Overrides the `GenerateSyncHandle` function to handle the case where the handle should be associated with another object that has not yet been spawned due to a previous desync during game replay.
---
--- This function is called by `RegisterGameRecordOverrides` to set up the game recording functionality.
---
--- @function CreateRecordedGenerateHandle
--- @return function The overridden `GenerateSyncHandle` function.
function CreateRecordedGenerateHandle()
    local origGenerateSyncHandle = GenerateSyncHandle
    GenerateSyncHandle = function(self)
        local h0, h = NextSyncHandle, origGenerateSyncHandle()
        if IsGameReplayRunning() and GameReplay.NextSyncHandle and GameReplay.handles
            and not IsSameClass(self, GameReplay.handles[h]) then
            -- the handle should be associated with another object, not yet spawn because of a previois desync
            NextSyncHandle = GameReplay.NextSyncHandle
            h = origGenerateSyncHandle()
            NextSyncHandle = h0
        end
        return h
    end
end

---
--- This function registers overrides for game recording functionality.
---
--- It creates the following overrides:
--- - `CreateRecordedEvent` to override the `NetSyncEvent` function
--- - `CreateRecordedMapLoadRandom` to override the `InitMapLoadRandom` function
--- - `CreateRecordedGenerateHandle` to override the `GenerateSyncHandle` function
---
--- These overrides are used to capture and replay game state during a game recording session.
---
--- @function RegisterGameRecordOverrides
function RegisterGameRecordOverrides()
    CreateRecordedEvent("NetSyncEvent")
    CreateRecordedMapLoadRandom()
    CreateRecordedGenerateHandle()
end

---
--- Registers overrides for game recording functionality.
---
--- This function is called when classes are generated, and sets up the following overrides:
--- - `CreateRecordedEvent` to override the `NetSyncEvent` function
--- - `CreateRecordedMapLoadRandom` to override the `InitMapLoadRandom` function
--- - `CreateRecordedGenerateHandle` to override the `GenerateSyncHandle` function
---
--- These overrides are used to capture and replay game state during a game recording session.
---
function OnMsg.ClassesGenerate()
    RegisterGameRecordOverrides()
    GameTests.PlayGameRecords = TestGameRecords
end

---
--- Runs a series of tests for game records.
---
--- This function loads and replays each game record associated with the project's test cases.
--- It prints information about the test records and reports any errors that occur during the replay.
---
--- @function TestGameRecords
--- @return nil
function TestGameRecords()
    local list = {}
    for _, test in ipairs(GetHGProjectTests()) do
        for _, info in ipairs(test.test_replays) do
            local name = string.format("%s.%s", test.id, info:GetRecordName())
            if info.Disabled then
                GameTestsPrint("Skipping disabled test replay", name)
            else
                list[#list + 1] = {name=name, record=info.Record}
            end
        end
    end
    GameTestsPrintf("Found %d game records to test.", #(list or ""))
    for i, entry in ipairs(list) do
        GameTestsPrintf("Testing record %d/%d %s", i, #list, entry.name)
        local st = RealTime()
        local err, record = LoadGameRecord(entry.record)
        if err then
            GameTestsPrintf("Failed to load record %s", entry.record, err)
        else
            err = ReplayGameRecord(record)
            if err then
                GameTestsError("Replay error:", err)
            elseif not WaitReplayEnd() then
                GameTestsError("Replay timeout.")
            else
                GameTestsPrint("Replay finished in:", RealTime() - st, "ms")
            end
        end
    end
end

local function GenerateRecordPath(record)
	local err = AsyncCreatePath(records_path)
	if err then 
		assert(err)
		return false
	end
	record = record or GameRecord
	local name = string.format("Record_%s_%s", os.date("%Y_%m_%d_%H_%M_%S", record.os_time), GetMapName())
	if record.continue then
		name = name .. "_continue"
	end
	return string.format("%s/%s.lua", records_path, name)
end

--- Saves the current game record to a file.
---
--- If `GameRecord` is not set, this function does nothing.
---
--- The record is saved asynchronously in a separate thread to avoid blocking the main game loop.
--- The save path is generated using `GenerateRecordPath()` if `GameReplayPath` is not set.
--- The `NextSyncHandle` field of the `GameRecord` is updated before saving.
---
--- @function SaveGameRecord
--- @return nil
function SaveGameRecord()
    if not GameRecord then
        return
    end
    local path = GameReplayPath or GenerateRecordPath(GameRecord)
    GameRecord.NextSyncHandle = NextSyncHandle
    if not GameRecordSaveRequests then
        GameRecordSaveRequests = {}
        CreateRealTimeThread(function()
            while true do
                for path, record in pairs(GameRecordSaveRequests) do
                    GameRecordSaveRequests[path] = nil
                    WaitSaveGameRecord(path, record)
                end
                if not next(GameRecordSaveRequests) then
                    GameRecordSaveRequests = false
                    break
                end
            end
        end)
    end
    GameRecordSaveRequests[path] = GameRecord
end

--- Saves the current game record to a file.
---
--- The record is saved asynchronously in a separate thread to avoid blocking the main game loop.
--- The save path is generated using `GenerateRecordPath()` if `GameReplayPath` is not set.
--- The `NextSyncHandle` field of the `GameRecord` is updated before saving.
---
--- @param path string|nil The path to save the game record to. If not provided, `GenerateRecordPath()` is used.
--- @param record table|nil The game record to save. If not provided, `GameRecord` is used.
--- @return string|nil The path where the game record was saved, or an error message if the save failed.
function WaitSaveGameRecord(path, record)
    record = record or GameRecord
    if not record then
        return
    end
    PrepareRecordForSaving(record)
    local code = pstr("return ", 64 * 1024)
    TableToLuaCode(record, nil, code)
    path = path or GenerateRecordPath(record)
    local err = AsyncStringToFile(path, code)
    if err then
        return err
    end
    Msg("GameReplaySaved", path)
    return nil, path
end

---
--- Replays a previously recorded game session.
---
--- This function loads a game record from a file and replays the game session. The game record can be provided as a table or as a file path. If the record is provided as a file path, the function will attempt to load the record from the file.
---
--- The function will first stop any currently running game replay, then load the game record and start a new replay. If the record has a `start_save` field, the function will load a specific saved game state before starting the replay. Otherwise, the function will create a new game instance and change the map to the one specified in the record.
---
--- @param record table|string The game record to replay, or the file path to the game record.
--- @return string|nil An error message if the replay failed to start, or `nil` if the replay started successfully.
function ReplayGameRecord(record)
    record = record or not IsGameReplayRunning() and GameRecord or GameReplay
    local err
    if type(record) == "string" then
        local _, _, ext = SplitPath(record)
        local path = ext ~= "" and record or string.format("%s/%s.lua", records_path, record)
        err, record = LoadGameRecord(path)
    end
    if not record then
        return err or "No record found!"
    end
    PrepareRecordForSaving(record)
    Msg("GameRecordEnd", record)
    StopGameReplay()
    Msg("GameReplayStart", record)
    GameReplayScheduled = record
    if record.start_save then
        GameReplaySaveLoading = true
        GameReplayThread = CreateRealTimeThread(ReplayLoadGameSpecificSave, record)
    else
        CloseMenuDialogs()
        CreateRealTimeThread(function()
            LoadingScreenOpen("idLoadingScreen", "ReplayGameRecord")
            GameReplayWaitMap = true
            local game = CloneObject(record.game)
            ChangeMap("")
            NewGame(game)
            local map_name = record.map_name
            local map_hash = record.map_hash
            if map_hash and map_hash ~= table.get(MapData, map_name, "NetHash") then
                local matched
                for map, data in sorted_pairs(MapData) do
                    if map_hash == data.NetHash then
                        matched = map
                        break
                    end
                end
                if not matched then
                    GameTestsPrint("Replay map has been modified!")
                elseif matched ~= map_name then
                    GameTestsPrint("Replay map changed to", matched)
                end
                map_name = matched or map_name
            end
            ChangeMap(map_name)
            GameReplayWaitMap = false
            Wakeup(GameReplayThread)
            LoadingScreenClose("idLoadingScreen", "ReplayGameRecord")
        end)
    end
end

---
--- Resaves a game record to the specified path.
---
--- If the record has a `start_save` field, the function asserts that the feature is not implemented.
--- Otherwise, it closes any open menu dialogs, creates a real-time thread to perform the following steps:
---   - Modifies the `config` table to set `FixedMapLoadRandom` to the record's `start_rand` value, and `StartGameOnPause` to `true`.
---   - Changes the map to the record's `map_name`.
---   - Restores the `config` table to its previous state.
---   - Sets the `GameReplayPath` global to the specified path.
---
--- @param path string The path to the game record file to resave.
--- @return string|nil An error message if the record could not be loaded, or `nil` on success.
function ResaveGameRecord(path)
    local _, _, ext = SplitPath(path)
    local path = ext ~= "" and path or string.format("%s/%s.lua", records_path, path)
    local err, record = LoadGameRecord(path)
    if not record then
        return err or "No record found!"
    end
    StopGameReplay()
    if record.start_save then
        assert(false, "Not implemented!")
    else
        CloseMenuDialogs()
        CreateRealTimeThread(function()
            table.change(config, "ResaveGameRecord", {FixedMapLoadRandom=record.start_rand, StartGameOnPause=true})
            ChangeMap(record.map_name)
            table.restore(config, "ResaveGameRecord")
            GameReplayPath = path
        end)
    end
end

---
--- Waits for the game replay to end.
---
--- This function blocks until a "GameReplayEnd" message is received, or the map is changing or the replay thread is no longer valid.
---
--- @return boolean true if the replay ended successfully, false otherwise
function WaitReplayEnd()
    while not WaitMsg("GameReplayEnd", 100) do
        if not IsChangingMap() and not IsValidThread(GameReplayThread) then
            return
        end
    end
    return true
end

---
--- Stops the current game replay.
---
--- This function checks if the `GameReplayThread` is valid, and if so, sets `GameReplayScheduled` to `false`, `GameReplayThread` to `false`, and sends a "GameReplayEnd" message. It then deletes the `GameReplayThread` with the `true` flag to force its termination.
---
--- @return boolean true if the replay was successfully stopped, false otherwise
function StopGameReplay()
    local thread = not GameReplaySaveLoading and GameReplayThread
    if not IsValidThread(thread) then
        return
    end
    GameReplayScheduled = false
    GameReplayThread = false
    Msg("GameReplayEnd")
    DeleteThread(thread, true)
    return true
end

---
--- Loads a game record from the specified file path.
---
--- @param path string The file path of the game record to load.
--- @return string|nil An error message if the load failed, or nil if the load was successful.
--- @return table The loaded game record.
function LoadGameRecord(path)
    local func, err = loadfile(path, nil, _ENV)
    if not func then
        return err
    end
    local success, record = procall(func)
    if not success then
        return record
    end
    return nil, record
end

---
--- Handles the loading of a game replay.
---
--- This function is called when a game is loaded. It checks if a game replay is scheduled to be injected. If so, it stops the current game replay, verifies that the saved game record matches the replay to be injected, and then creates a new game time thread to play the injected replay.
---
--- @return nil
function OnMsg.LoadGame()
    if not GameReplayToInject then
        return
    end
    StopGameReplay()
    if not GameRecord then
        print("Replay injection failed: No saved record found (maybe a saved game during a replay?)")
        return
    end
    for _, key in ipairs {"start_rand", "map_name", "os_time", "lua_rev", "assets_rev"} do
        if GameRecord[key] ~= GameReplayToInject[key] then
            print("Replay injection failed: Wrong game!")
            return
        end
    end
    print("Replay Injection Success.")
    CreateGameTimeThread(PlayGameRecord, GameReplayToInject, #GameRecord + 1)
    GameReplayToInject = false
end

---
--- Toggles the injection of a game replay.
---
--- If a record is provided, it is set as the game replay to be injected. If the provided record matches the current `GameReplayToInject`, the injection is cancelled. Otherwise, the record is set as the game replay to be injected.
---
--- If no record is provided, the current `GameReplayToInject` is set to `false`.
---
--- @param record table|nil The game record to be injected, or `nil` to cancel the injection.
--- @return nil
function ToggleGameReplayInjection(record)
    record = record or GameRecord or GameReplay
    if record and record == GameReplayToInject then
        record = false
        print("Replay Injection Cancelled")
    elseif record then
        print("Replay Injection Ready")
    else
        print("No record found to inject")
    end
    GameReplayToInject = record
end

----

---
--- Loads a game-specific save file and calls a callback function when the load is complete.
---
--- This function is a placeholder that should be implemented by the game developer to handle loading of game-specific save data. It is called when a game replay is being loaded, to allow the game to load any additional save data required for the replay.
---
--- @param save table The game-specific save data to be loaded.
--- @param callbackOnload function The callback function to be called when the load is complete.
--- @return boolean true if the load was successful, false otherwise.
function ReplayLoadGameSpecificSave(save, callbackOnload)
    print("You must implement your game loading function in ReplayLoadGameSpecificSave to use game replays with saves.")
    return true
end

---
--- Toggles the fast forward mode for the current game replay.
---
--- If the game replay is not running, fast forward mode is disabled.
--- If the `set` parameter is provided, the fast forward mode is set to that value.
--- If the `set` parameter is not provided, the fast forward mode is toggled.
---
--- @param set boolean|nil The desired state of the fast forward mode. If `nil`, the mode is toggled.
--- @return nil
function ReplayToggleFastForward(set)
    if not IsGameReplayRunning() then
        set = false
    elseif set == nil then
        set = not GameReplayFastForward
    end
    if GameReplayFastForward == set then
        return
    end
    GameReplayFastForward = set
    TurboSpeed(set, true)
end

---
--- Called when a game replay has ended.
---
--- If the game replay was in fast forward mode, it is toggled off.
--- If the game replay was being recorded, the recording is allowed to continue.
---
--- @param record table The game replay that has ended.
--- @return nil
function OnMsg.GameReplayEnd(record)
    if GameReplayFastForward then
        ReplayToggleFastForward()
    end
    -- allow to continue the recording
    if record then
        record.continue = true
        GameRecord = record
    end
end

---
--- Called when a game replay is played.
---
--- If the game replay is in fast forward mode, this function checks if the replay is near the end. If so, it stops the fast forward mode and sets the time factor back to 0.
---
--- @param i number The index of the current event in the replay.
--- @param record table The game replay that is being played.
--- @return nil
function OnMsg.GameRecordPlayed(i, record)
	if record and GameReplayFastForward then
		local events_before_end = config.ReplayFastForwardBeforeEnd or 10
		if i >= #record - events_before_end then
			print(events_before_end, "events before the end reached, stopping fast forward...")
			ReplayToggleFastForward()
			SetTimeFactor(0)
		end
	end
end

----

if config.DebugReplayDesync then

if FirstLoad then
	GameRecordSyncLog = false
	GameRecordSyncTest = false
	GameRecordSyncIdx = false
	HashLogSize = 32
end

function OnMsg.AutorunEnd()
	pairs = totally_async_pairs
end

function OnMsg.ReloadLua()
	pairs = g_old_pairs
end

function OnMsg.NetUpdateHashReasons(enable_reasons)
	local record = GameRecord or GameRecordScheduled or GameReplay or GameReplayScheduled
	enable_reasons.GameRecord = record and record.net_update_hash and true or nil
end

function OnMsg.LoadGame()
	GameRecordSyncLog = false
end

local function StartSyncLogSaving(replay)
	local err = AsyncCreatePath("AppData/ReplaySyncLogs")
	if err then
		print("Failed to create NetHashLogs folder:", err)
		return
	end
	GameRecordSyncLog = true
	GameRecordSyncTest = replay and ((GameRecordSyncTest or 0) + 1) or false
	GameRecordSyncIdx = 1
end

function OnMsg.GameRecordScheduled()
	StartSyncLogSaving()
end

function OnMsg.GameReplayStart()
	StartSyncLogSaving(true)
end

function OnMsg.GameReplayEnd(record)
	NetSaveHashLog("E", "Replay", GameRecordSyncTest)
	GameRecordSyncLog = false
end

function OnMsg.GameRecordEnd(record)
	NetSaveHashLog("E", "Record")
	GameRecordSyncLog = false
end

function OnMsg.SyncEvent()
	if not GameRecordSyncIdx then
		return
	end
	if GameRecordSyncTest then
		NetSaveHashLog(GameRecordSyncIdx, "Replay", GameRecordSyncTest)
	else
		NetSaveHashLog(GameRecordSyncIdx, "Record")
	end
	GameRecordSyncIdx = GameRecordSyncIdx + 1
end

    ---
    --- Saves a hash log to a file in the "AppData/ReplaySyncLogs" directory.
    ---
    --- @param prefix string|nil The prefix to use for the log file name.
    --- @param logtype string The type of log, e.g. "Record" or "Replay".
    --- @param suffix string|nil The suffix to use for the log file name.
    ---
    function NetSaveHashLog(prefix, logtype, suffix)
        if not GameRecordSyncLog then
            return
        end
        local str = pstr("")
        NetGetHashLog(str)
        if #str == 0 then
            return
        end
        local path = string.format("AppData/ReplaySyncLogs/%s%s%s.log", (prefix and tostring(prefix) .. "_" or ""),
            logtype, suffix and ("_" .. tostring(suffix)) or "")
        CreateRealTimeThread(function(path, str)
            local err = AsyncStringToFile(path, str)
            if err then
                printf("Failed to save %s: %s", path, err)
            end
        end, path, str)
    end

function OnMsg.BugReportStart(print_func)
	local replay = IsGameReplayRunning()
	if not replay then return end
	print_func("\nGame replay running:", replay.lua_rev, replay.assets_rev)
end

end -- config.DebugReplayDesync

if Platform.developer then

    ---
    --- Collects test data for the TestValidator.
    ---
    --- This function is an internal implementation detail of the TestValidator class.
    --- It collects test data that can be used to validate the correctness of the test data.
    --- The collected data is returned as a table.
    ---
    --- @return table The collected test data.
    ---
    function TestValidator:CollectTestData()
        local data = {}
        if Platform.developer then
            self:GetTestData(data)
        end
        return data
    end

    --- Compares the original test data with the newly collected test data, and reports an error if they don't match.
    ---
    --- This function is an internal implementation detail of the TestValidator class.
    --- It is called when the test data needs to be validated against the original data.
    --- If the data doesn't match, it will print an error message with the differences.
    ---
    --- @param orig_data table The original test data collected previously.
    ---
    function TestValidator:rfnTestData(orig_data)
        local new_data = self:CollectTestData()
        local ignore_missing = true -- avoid breaking existing tests when adding or removing test validation entries
        if table.equal_values(orig_data, new_data, -1, ignore_missing) then
            return
        end
        GameTestsError("Test data validation failed for", self.class, "\n--- Orig data: ", ValueToStr(orig_data),
            "\n--- New data: ", ValueToStr(new_data))
    end

    ---
    --- Collects test data for the TestValidator and validates it against the original data.
    ---
    --- This function is an internal implementation detail of the TestValidator class.
    --- It collects test data that can be used to validate the correctness of the test data,
    --- and then compares the new data with the original data, reporting an error if they don't match.
    ---
    --- @function TestValidator:CreateValidation
    --- @return nil
    ---
    function TestValidator:CreateValidation()
        local data = self:CollectTestData()
        if next(data) == nil then
            print("No test data to validate!")
            return
        end
        NetSyncEvent("ObjFunc", self, "rfnTestData", data)
        print("Test data collected:", ValueToStr(data))
    end

    --- Asynchronously validates the test data for the TestValidator.
    ---
    --- This function is an internal implementation detail of the TestValidator class.
    --- It collects the test data and compares it to the original data, reporting any differences.
    ---
    --- @function TestValidator:AsyncCheatValidate
    --- @return nil
    function TestValidator:AsyncCheatValidate()
        self:CreateValidation()
    end

    ---
    --- Creates a script to update the source code and assets to the specified revisions.
    ---
    --- This function is an internal implementation detail of the game replay system.
    --- It generates a batch script that can be used to update the local source code and assets
    --- to the revisions recorded in the current game replay.
    ---
    --- @param none
    --- @return none
    ---
    function ReplayCreateUpdateScript()
        local record = GameReplay or GameRecord
        if not record then
            print("No replay running!")
            return
        end

        local lua_rev = record.lua_rev or LuaRevision
        local assets_rev = record.assets_rev or AssetsRevision

        local src_path = ConvertToOSPath("svnSrc/")
        local assets_path = ConvertToOSPath("svnAssets/")

        local scrip = {"@echo off", "cd " .. src_path, "svn cleanup", "svn up -r " .. lua_rev, "cd " .. assets_path,
            "svn cleanup", "svn up -r " .. assets_rev}
        local path = string.format("%sUpdateToRev_%d_%d.bat", src_path, lua_rev, assets_rev)
        local err = AsyncStringToFile(path, table.concat(scrip, "\n"))
        if err then
            print("Failed to create script:", err)
        else
            print("Script created at:", path)
        end
    end

end -- Platform.developer