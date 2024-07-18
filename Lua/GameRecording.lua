--- Loads a game-specific save from the provided `gameRecord` table.
---
--- @param gameRecord table The game record table containing the save data.
function ReplayLoadGameSpecificSave(gameRecord)
	Pause("load-replay-save")
	LoadGameSessionData(gameRecord.start_save)
	Resume("load-replay-save")
end

config.GameReplay_EventsDuringPlaybackExpected = true

if FirstLoad then
origSetTimeFactor = SetTimeFactor
end

local test_time = 50000
if FirstLoad then
	GameTesting = false
end

function OnMsg.GameTestsBegin(auto_test)
	GameTesting = true
end

function OnMsg.GameTestsEnd(auto_test)
	GameTesting = false
end

function OnMsg.Resume()
	if GameTesting then __SetTimeFactor(test_time) end
end

function OnMsg.GameReplayStart()
	GameRecord = false
	SetGameRecording(false)
end

function OnMsg.GameReplaySaved(path)
	print("Saved replay " .. path)
	GameRecord = false
	SetGameRecording(false)
end

local _netFuncsToOverride = { "NetSyncEvent", "NetEchoEvent" }
local _netFuncToNetFuncArray = { ["NetSyncEvent"] = "NetSyncEvents", ["NetEchoEvent"] = "NetEvents" }
local _defaultNetFunc = "NetSyncEvent"
_replayDesynced = false

--- Returns whether a game replay is currently being recorded.
---
--- @return boolean True if a game replay is being recorded, false otherwise.
function IsGameReplayRecording()
	return not not GameRecord
end

---
--- Stops the current game replay and cleans up related state.
---
--- If a game replay is currently being played back, this function will:
--- - Delete the game replay thread
--- - Reset the `GameReplayThread` variable to `false`
--- - Resume the "UI" thread
--- - Send the "GameReplayEnd" message
--- - Reset the `GameRecord` variable to `false`
---
function StopGameRecord()
	if IsValidThread(GameReplayThread) then
		DeleteThread(GameReplayThread)
		GameReplayThread = false
		Resume("UI")
		Msg("GameReplayEnd")
		GameRecord = false
	end
end

---
--- Handles the end of a game replay.
---
--- This function is called when the "ReplayEnded" event is received during a game replay.
--- It prints a message indicating that the replay is done, and deletes the `GameReplayThread` if it is valid.
--- Finally, it sends the "GameReplayEnd" message to notify other parts of the system that the replay has ended.
---
function NetSyncEvents.ReplayEnded()
	GameTestsPrint("Replay done")
	if IsValidThread(GameReplayThread) then DeleteThread(GameReplayThread) end
	Msg("GameReplayEnd")
end

---
--- Starts a scheduled game replay.
---
--- This function is called when a game replay is scheduled to be played back. It sets up the necessary state and creates a game time thread to execute the replay.
---
--- The function performs the following steps:
--- - Checks if a game replay is scheduled, and returns if not.
--- - Stores the scheduled replay record in the `GameReplay` variable.
--- - Resets the `next_hash` and `next_rand` fields of the `GameReplay` record.
--- - Resets the `_replayDesynced` flag to `false`.
--- - Creates a new game time thread to execute the replay.
---
--- Inside the game time thread, the function:
--- - Asserts that the game time is 0 and that the current thread is a game time thread.
--- - Asserts that the map name and start random seed match the recorded replay.
--- - Calculates the total game time of the replay.
--- - Prints a message indicating the start of the replay.
--- - Iterates through the replay record and schedules each event using `ScheduleSyncEvent`.
--- - Waits for the "ReplayFenceCleared" message for any "FenceReceived" events.
--- - Schedules a "ReplayEnded" event at the end of the replay.
--- - Creates a new game time thread to wait for the "GameReplayEnd" message.
---
--- @return nil
function ZuluStartScheduledReplay()
	if not GameReplayScheduled then return end
	local record = GameReplayScheduled
	GameReplayScheduled = false
	GameReplay = record
	GameReplay.next_hash = 1
	GameReplay.next_rand = 1
	_replayDesynced = false
	
	GameReplayThread = CreateGameTimeThread(function()
		if GameReplayThread ~= CurrentThread() and IsValidThread(GameReplayThread) then
			DeleteThread(GameReplayThread)
		end
		
		assert(GameTime() == 0)
		assert(IsGameTimeThread())
		assert(record.map_name == GetMapName())
		assert(record.start_rand == MapLoadRandom)
		
		local total_time = Max((record[#record] or empty_table)[RECORD_GTIME] or 0, record.game_time or 0)
		Msg("GameReplayStart")
		GameTestsPrint("Replay start:", #record, "events", "|", string.format(total_time * 0.001), "sec", "|", "Lua rev", record.lua_rev or 0, "/", LuaRevision, "|", "assets rev", record.assets_rev or 0, "/", AssetsRevision)
		for i = 1, #record do
			local entry = record[i]
			local event, params = entry[RECORD_EVENT], entry[RECORD_PARAM]
			local gtime, rtime, etype = entry[RECORD_GTIME], entry[RECORD_RTIME], entry[RECORD_ETYPE]
			
			ScheduleSyncEvent(event, Serialize(UnserializeRecordParams(params)), gtime)
			
			if event == "FenceReceived" then
				WaitMsg("ReplayFenceCleared")
			end
			
			if i == #record then
				ScheduleSyncEvent("ReplayEnded", false, gtime)
			end
		end
		
		GameReplayThread = CreateGameTimeThread(function()
			WaitMsg("GameReplayEnd")
		end)
	end)
end

function OnMsg.CanSaveGameQuery(query)
	query.replay_running = IsGameReplayRunning() or nil
	query.replay_recording = IsGameReplayRecording() or nil
end

if FirstLoad then
ContinueOnReplayDesync = not not Platform.trailer
end

local function lReplayDesynced()
	_replayDesynced = true

	if ContinueOnReplayDesync then
		return
	end
	
	DeleteThread(GameReplayThread)
	Msg("GameReplayEnd", GameReplay)
end

---
--- Registers game record overrides for various game events and functions.
--- This function is responsible for overriding certain game functions to record their behavior during gameplay.
---
--- The following overrides are registered:
--- - `CreateRecordedEvent`: Overrides the creation of recorded events.
--- - `CreateRecordedMapLoadRandom`: Overrides the creation of recorded map load random values.
--- - `CreateRecordedGenerateHandle`: Overrides the generation of recorded handles.
--- - `NetUpdateHash`: Overrides the net update hash function to track hash recording.
--- - `InteractionRand`: Overrides the interaction random function to track random value recording.
---
--- @function RegisterGameRecordOverrides
--- @return nil
function RegisterGameRecordOverrides()
	for i, event_type in ipairs(_netFuncsToOverride) do
		CreateRecordedEvent(event_type)
	end
	
	CreateRecordedMapLoadRandom()
	CreateRecordedGenerateHandle()

	if FirstLoad then -- overwrite only on first load as it is a C function
		local origNetUpdateNesh = NetUpdateHash
		local function hashRecordingUpdate(...)
			local hash = origNetUpdateNesh(...)
			NetHashRecordingTracker(...)
			return hash
		end
		NetUpdateHash = hashRecordingUpdate
	end

	local origInteractionRand = InteractionRand
	local function RecordedInteractionRand(...)
		local rand = origInteractionRand(...)
		InteractionRandRecordingTracker(rand, ...)
		return rand
	end
	InteractionRand = RecordedInteractionRand
end

---
--- Tracks and verifies the recorded random values during a game replay.
---
--- This function is responsible for tracking the random values that are recorded during a game replay. It checks that the random values being played back match the expected values recorded in the replay. If a mismatch is detected, it triggers a replay desync error.
---
--- @param rolledRand number The random value that was just rolled.
--- @param ... any Additional parameters related to the random value.
--- @return nil
function InteractionRandRecordingTracker(rolledRand, ...)
	local playingReplay = IsGameReplayRunning()
	local recordingReplay = IsGameReplayRecording()
	if not playingReplay and not recordingReplay then return end
	
	local paramsSerialized = Serialize({...})
	local hash = xxhash(GameTime(), rolledRand, paramsSerialized)
	
	if playingReplay then
		local expectedHashIdx = GameReplay.next_rand
		local expectedHashData = GameReplay.rand_list[expectedHashIdx]
		local expectedHash = type(expectedHashData) == "table" and expectedHashData[1] or expectedHashData
		
		if not expectedHash and expectedHashIdx > #GameReplay.rand_list then
			return -- its over!
		end
		
		if hash ~= expectedHash and not _replayDesynced then
			--randoms can start before record starts an event, but after load
			if expectedHashIdx == 1 and playingReplay and not recordingReplay then
				if GameState.loading_savegame or GameState.loading then
					return
				end
			end
			local params = {...}
			GameTestsError("Replay desynced @", GameTime(), "Rand expected", expectedHash, "but got", hash, " expectedHashIdx", expectedHashIdx)
			print("incoming :", GameTime(), rolledRand, GetStack())
			print("expected :", expectedHashData[4], expectedHashData[3], expectedHashData[5])
			lReplayDesynced()
		end
		GameReplay.next_rand = expectedHashIdx + 1
	elseif GameRecord and GameRecord.rand_list then
		--when rand_list gets serialized for saving, valid objs will get serialized as PlaceObject(..., which will then place them when the file is booted;
		--get rid of those now;
		local params = {...}
		for i = #params, 1, -1 do
			local o = params[i]
			if IsValid(o) then
				params[i] = string.format("Obj with class %s and handle %d", o.class, o:HasMember("handle") and o.handle or "N/A")
			end
		end
		GameRecord.rand_list[#GameRecord.rand_list + 1] = { hash, params, rolledRand, GameTime(), GetStack() }
	end
end

--- Converts a string to a comma-separated list of bytes for debugging purposes.
---
--- @param str string The input string to convert.
--- @return string A comma-separated list of bytes representing the input string.
function Dbg_StringToBytesAsString(str) -- For use with paramsSerialized
	return table.concat(({str}), ", ")
end

--- Tracks the net hash recording for game replays.
---
--- This function is responsible for checking the hash of the incoming network data
--- against the expected hash if the game is in replay mode, or recording the hash
--- if the game is in recording mode.
---
--- @param ... The parameters passed to the function. The first parameter is used to
---            determine if a new map has been loaded, which triggers the start of a
---            scheduled replay.
function NetHashRecordingTracker(...)
	local params = ({...})
	if GameReplayScheduled then
		if params[1] == "NewMapLoaded" then
			ZuluStartScheduledReplay()
		end
	end
	
	local playingReplay = IsGameReplayRunning()
	local recordingReplay = IsGameReplayRecording()
	if not playingReplay and not recordingReplay then return end

	-- Old replays dont have these captured.
	if GameReplay and GameReplay.lua_rev == 327744 then
		if params[1] == "ResetInteractionRand" or params[1] == "InteractionRand" then
			return
		end
	end

	-- Replay over event
	if playingReplay and params and params[1] == "SyncEvent" and params[2] == "ReplayEnded" then
		return
	end

	local paramsSerialized = Serialize(params) -- for debugging
	
	local netHashVal = NetGetHashValue()
	local hash = xxhash(GameTime(), netHashVal)
	assert(netHashVal ~= 1)
	
	-- Check if the incoming hash is the same as the next expected hash if replaying,
	-- or record it if recording.
	if playingReplay then
		local expectedHashIdx = GameReplay.next_hash
		local expectedHashData = GameReplay.hash_list[expectedHashIdx]
		local expectedHash = type(expectedHashData) == "table" and expectedHashData[1] or expectedHashData
		
		if not expectedHash and expectedHashIdx > #GameReplay.hash_list then
			return -- its over, no need to check anymore!
		end
		
		if hash ~= expectedHash and not _replayDesynced then
			GameTestsError("Replay desynced @", GameTime(), "Hash expected", expectedHash, "but got", hash)
			lReplayDesynced()
		end
		GameReplay.next_hash = expectedHashIdx + 1
	elseif GameRecord and GameRecord.hash_list then
		GameRecord.hash_list[#GameRecord.hash_list + 1] = { hash, paramsSerialized, GameTime(), GetStack() }
	end
end

---
--- Enables or disables game recording.
---
--- @param val boolean
---   `true` to enable game recording, `false` to disable it.
---
function SetGameRecording(val)
	config.EnableGameRecording = val
end

---
--- Creates a recorded map load random function that records the random seed used for map generation.
---
--- If a game replay is scheduled, the recorded random seed is used. Otherwise, a new random seed is generated and recorded.
---
--- @return number
---   The random seed used for map generation.
---
function CreateRecordedMapLoadRandom()
	local origInitMapLoadRandom = InitMapLoadRandom
	InitMapLoadRandom = function()
		if GameTime() ~= 0 then -- Coming from InitGameVar and not ChangeMap
			return origInitMapLoadRandom()
		end
		local rand
		if GameReplayScheduled then
			rand = GameReplayScheduled.start_rand
		else
			rand = origInitMapLoadRandom()
			if mapdata and mapdata.GameLogic and config.EnableGameRecording then
				assert(not IsGameReplayRunning())
				GameReplay = false
				print("Game is being recorded.")
				GameRecordScheduled = {
					start_rand = rand,
					map_name = GetMapName(),
					os_time = os.time(),
					real_time = RealTime(),
					game = Game,
					lua_rev = LuaRevision,
					assets_rev = AssetsRevision,
					handles = {},
					version = GameRecordVersion,
					hash_list = {},
					rand_list = {},
					net_update_hash = true
				}
			end
		end
		return rand
	end
end

---
--- Starts recording a game replay.
---
--- If a game replay is already scheduled, this function does nothing.
--- Otherwise, it creates a new real-time thread that gathers the current session data, enables game recording, and loads the gathered session data.
--- The gathered session data is stored in the `GameRecord.start_save` field.
---
function ZuluStartRecordingReplay()
	if GameReplayScheduled then return end
	
	CreateRealTimeThread(function()
		local save = GatherSessionData():str()
		SetGameRecording(true)
		assert(not GameRecord)
		LoadGameSessionData(save)
		GameRecord.start_save = save
		assert(GameRecord)
	end)
end

local function SuspendAutosave()
	config.AutosaveSuspended = true
end

local function ResumeAutosave()
	config.AutosaveSuspended = false
end

OnMsg.GameReplayStart = SuspendAutosave
OnMsg.GameRecordingStarted = SuspendAutosave
OnMsg.GameReplayEnd = ResumeAutosave
OnMsg.GameReplaySaved = ResumeAutosave

if FirstLoad then
ShowReplayUI = not not Platform.trailer
ReplayUISpeed = false
end

function OnMsg.GameReplayStart()
	ObjModified("replay_ui")
	if ShowReplayUI then
		ReplayUISpeed = ReplayUISpeed or const.DefaultTimeFactor
		SetTimeFactor(ReplayUISpeed)
		Pause("UI")
	end
end

function OnMsg.GameReplayEnd()
	GameRecord = false
	ObjModified("replay_ui")
	Resume("UI")
	SetTimeFactor(const.DefaultTimeFactor)
end

function OnMsg.GameRecordingStarted()
	ObjModified("replay_ui")
end

function OnMsg.GameReplaySaved()
	ObjModified("replay_ui")
end

-- During replay playback all incoming NetSyncEvents are bypassed.
---
--- Plays back a network synchronization event, handling the case where a game replay is running.
---
--- If a game replay is running, the event is passed to the corresponding `NetSyncEvents` handler.
--- Otherwise, the event is passed to the standard `NetSyncEvent` function.
---
--- @param eventId number The ID of the network synchronization event to play back.
--- @param ... any Additional arguments to pass to the event handler.
---
function PlaybackNetSyncEvent(eventId, ...)
	if IsGameReplayRunning() then
		NetSyncEvents[eventId](...)
	else
		NetSyncEvent(eventId, ...)
	end
end