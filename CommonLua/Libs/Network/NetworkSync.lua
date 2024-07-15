if Libs.Network ~= "sync" then return end

if Platform.developer then
	function OnMsg.NetGameJoined(game_id, unique_id)
		pairs = totally_async_pairs
	end

	function OnMsg.NetGameLeft(reason)
		pairs = g_old_pairs
	end
end

local HashSendInterval = config.HashSendInterval or Platform.developer and 100 or 300

MapGameTimeRepeat("NetHashThread", HashSendInterval, function(sleep)
	if sleep and netInGame and Game then
		local hash = NetGetHashValue()
		NetUpdateHash("NetHashThread", GameTime() / sleep, hash)
		NetGameSend("rfnPlayerHash", GameTime() / sleep, hash)
		NetResetHashValue()
	end
end)


MapGameTimeRepeat("InteractionRandScheduleReset", 10000, function()
	ResetInteractionRand(now())
end)


----- AdvanceGameTime

MapVar("AdvanceToGameTimeLimit", 0)
MapVar("ForceAdvanceToGameTime", 0)

if FirstLoad then
__AdvanceGameTime = AdvanceGameTime
end
 
---
--- Advances the game time by the specified amount.
---
--- @param time number The amount of time to advance the game by.
---
--- This function is responsible for advancing the game time while taking into account various limits and constraints. It checks if the game is in a network game, and if so, it ensures that the time being advanced does not exceed certain limits. If the time being advanced would exceed the `AdvanceToGameTimeLimit` or `ForceAdvanceToGameTime` limits, the function adjusts the time accordingly. Finally, it calls the `__AdvanceGameTime` function to actually advance the game time.
function AdvanceGameTime(time)
	if netInGame then
		if (AdvanceToGameTimeLimit or 0) - time < 0 then
			time = AdvanceToGameTimeLimit or 0
		end
		if (ForceAdvanceToGameTime or 0) - time > 0 then
			time = ForceAdvanceToGameTime or 0
			if time - GameTime() > 100 then
				time = GameTime() + 100
			end
		end
		if GameTime() - time > 0 then
			time = GameTime()
		end
	end
	__AdvanceGameTime(time)
end

---
--- Advances the game time by the specified amount, taking into account various limits and constraints.
---
--- @param delta number The amount of time to advance the game by.
--- @param time_factor number The time factor to apply to the game time advancement.
--- @param time number The current game time.
---
--- This function is responsible for advancing the game time while ensuring that the time being advanced does not exceed certain limits. It checks if the `AdvanceToGameTimeLimit` is set, and if so, it adjusts the time factor and the `ForceAdvanceToGameTime` and `AdvanceToGameTimeLimit` variables accordingly to try to catch up if the game is more than 50ms real time behind.
function NetEvents.AdvanceTime(delta, time_factor, time)
	if AdvanceToGameTimeLimit then
		if AdvanceToGameTimeLimit - GameTime() > 50 * time_factor / 1000 then -- try to catch up if more than 50ms real time behind
			__SetTimeFactor(time_factor * 11 / 10)
		else
			__SetTimeFactor(time_factor)
		end
		ForceAdvanceToGameTime = AdvanceToGameTimeLimit - 2000
		AdvanceToGameTimeLimit = AdvanceToGameTimeLimit + delta * time_factor / 1000
	end
end

function OnMsg.NetGameJoined(game_id, unique_id)
	-- GameTime is conrolled by the online game
	ForceAdvanceToGameTime = GameTime()
	AdvanceToGameTimeLimit = GameTime()
end


----- Pause/Resume

if FirstLoad then
NetPause = false
end

if config.LocalToNetPause then

	function Pause(reason)
		reason = reason or false
		if next(PauseReasons) == nil then
			NetSetPause(true)
			PauseSounds(1, true)
			Msg("Pause", reason)
			PauseReasons[reason] = true
			if IsGameTimeThread() then InterruptAdvance() end
		else
			PauseReasons[reason] = true
		end
	end

	function Resume(reason)
		reason = reason or false
		if PauseReasons[reason] ~= nil then
			PauseReasons[reason] = nil
			if next(PauseReasons) == nil then
				NetSetPause(false)
				ResumeSounds(1)
				Msg("Resume", reason)
			end
		end
	end

	function IsPaused()
		return NetPause
	end

end

---
--- Sets the network game pause state.
---
--- If `pause` is `true`, the game is paused. If `pause` is `false`, the game is resumed.
--- If `pause` is `nil`, the pause state is set to `false`.
---
--- If the game is in a network session, the pause state is synchronized with the other clients.
--- If the game is not in a network session, the time factor is set based on the current pause state.
---
--- @param pause boolean|nil The new pause state.
function NetSetPause(pause)
	NetPause = pause or false
	if netInGame then
		NetChangeGameInfo({ pause = NetPause })
	else
		SetTimeFactor(GetTimeFactor())
	end
end

function OnMsg.NetGameJoined(game_id, unique_id)
	if netGameInfo.pause == nil then
		NetSetPause(NetPause)
	else
		NetSetPause(netGameInfo.pause)
	end
end


----- TimeFactor

if FirstLoad then
__SetTimeFactor = SetTimeFactor
__GetTimeFactor = GetTimeFactor
end

---
--- Gets the current network time factor.
---
--- The network time factor is a value between 0 and `const.MaxTimeFactor` that controls the game time speed.
--- A value of 0 will pause the game, while a value of 1 will run the game at normal speed.
---
--- @return number The current network time factor.
function GetTimeFactor()
	return NetTimeFactor or const.DefaultTimeFactor
end
GameVar("NetTimeFactor", GetTimeFactor)

---
--- Sets the network time factor.
---
--- The network time factor is a value between 0 and `const.MaxTimeFactor` that controls the game time speed.
--- A value of 0 will pause the game, while a value of 1 will run the game at normal speed.
---
--- If the game is in a network session, the time factor is synchronized with the other clients.
--- If the game is not in a network session, the time factor is set directly.
---
--- @param time_factor number The new network time factor.
function SetTimeFactor(time_factor)
	NetTimeFactor = Clamp(time_factor or const.DefaultTimeFactor, 0, const.MaxTimeFactor)
	if netInGame then
		if netGameInfo.time_factor ~= NetTimeFactor then
			NetChangeGameInfo({ time_factor = NetTimeFactor })
		end
	else
		__SetTimeFactor(NetPause and 0 or NetTimeFactor)
	end
end

function OnMsg.NetGameInfo(info)
	if info.pause ~= nil or info.time_factor ~= nil then
		NetPause = netGameInfo.pause or false
		NetTimeFactor = netGameInfo.time_factor or const.DefaultTimeFactor
		__SetTimeFactor(NetTimeFactor)
	end
end

function OnMsg.LoadGame()
	SetTimeFactor(GetTimeFactor())
end
 
function OnMsg.NetGameJoined(game_id, unique_id)
	SetTimeFactor(netGameInfo.time_factor or GetTimeFactor())
end

function OnMsg.NetGameLeft()
	SetTimeFactor(GetTimeFactor())
end




----- Sync events

---
--- Checks if the current code is being executed asynchronously.
---
--- If `config.IgnoreSyncCheckErrors` is true, this function will always return true.
--- Otherwise, it will return the result of `IsAsyncCode()`.
---
--- @return boolean True if the current code is being executed asynchronously, false otherwise.
function SyncCheck_NetSyncEventDispatch()
	if config.IgnoreSyncCheckErrors then
		return true
	end
	return IsAsyncCode()
end

---
--- Schedules a sync event to be executed at a specific time.
---
--- @param event string The name of the sync event to schedule.
--- @param params table|false Optional parameters to pass to the sync event function.
--- @param time number|nil The time at which the sync event should be executed. If not provided, the current game time will be used.
--- @param ... any Additional arguments to pass to the sync event function.
---
--- @return nil
function ScheduleSyncEvent(event, params, time, ...)
	if not SyncEventsQueue then return end
	local func = NetSyncEvents[event]
	if not func then
		assert(false, "No such sync event: " .. tostring(event))
		return
	end
	time = time or GameTime()
	SyncEventsQueue[#SyncEventsQueue + 1] = { time, event, params or false, ... }
	Wakeup(PeriodicRepeatThreads["SyncEvents"])
end

local ScheduleOfflineSyncEvent = ScheduleSyncEvent

if Platform.developer then
	-- simulate network random delay in an offline game
	ScheduleOfflineSyncEvent = function(event, params)
		if netSimulateLagAvg == 0 then
			return ScheduleSyncEvent(event, params)
		end
		CreateRealTimeThread(function()
			local time = GameTime()
			Sleep(GetLagEventDelay())
			ScheduleSyncEvent(event, params, time)
		end)
	end
end

---
--- Sends a network synchronization event.
---
--- This function is responsible for handling the logic of sending a network synchronization event. It checks if the current code is being executed asynchronously, asserts that the event exists in the `NetSyncEvents` table, and then either sends the event over the network or schedules it to be executed offline.
---
--- @param event string The name of the sync event to send.
--- @param ... any Additional arguments to pass to the sync event function.
---
--- @return boolean|nil True if the event was sent successfully, or nil if the event was scheduled offline.
function NetSyncEvent(event, ...)
	assert(SyncCheck_NetSyncEventDispatch())
	assert(NetSyncEvents[event])
	if NetSyncLocalEffects[event] then
		NetSyncLocalEffects[event](...)
	end
	NetStats.events_sent = NetStats.events_sent + 1
	if netInGame then
		return SendEvent("rfnSyncEvent", event, ...)
	else
		local params, err = Serialize(...)
		assert(params, err)
		if netBufferedEvents then
			netBufferedEvents[#netBufferedEvents + 1] = pack_params(event, params)
			return
		end
		NetGossip("SyncEvent", GameTime(), event, params)
		return ScheduleOfflineSyncEvent(event, params)
	end
end

---
--- Executes a network synchronization event.
---
--- This function is responsible for executing a network synchronization event. It first checks if there is a revert function registered for the event, and if so, calls it. It then logs the event and updates the network hash. Finally, it calls the event function registered in the `NetSyncEvents` table, if it exists, and returns the result.
---
--- @param event string The name of the sync event to execute.
--- @param ... any Additional arguments to pass to the sync event function.
---
--- @return boolean|nil True if the event was executed successfully, or nil if the event function does not exist.
--- @return string|nil An error message if the event function does not exist.
function ExecuteSyncEvent(event, ...)
	local revert_func = NetSyncRevertLocalEffects[event]
	if revert_func then
		procall(revert_func, ...)
	end
	
	Msg("SyncEvent", event, ...)
	NetUpdateHash("SyncEvent", event, ...)
	
	local func = NetSyncEvents[event]
	if not func then
		return false, "no such sync event"
	end
	
	return procall(func, ...)
end

local Sleep = Sleep
---
--- Waits for all other threads to complete.
---
--- This function is used to ensure that all other threads have completed before proceeding. It does this by calling `Sleep(0)` multiple times, which allows other threads to run and complete their work.
---
--- @function WaitAllOtherThreads
--- @return nil
function WaitAllOtherThreads()
	Sleep(0) Sleep(0) Sleep(0) Sleep(0) Sleep(0) Sleep(0) Sleep(0) Sleep(0) Sleep(0) Sleep(0)
	Sleep(0) Sleep(0) Sleep(0) Sleep(0) Sleep(0) Sleep(0) Sleep(0) Sleep(0) Sleep(0) Sleep(0)
end

---
--- Executes a hook for a network synchronization event.
---
--- This function is a placeholder for executing any custom hooks or logic before a network synchronization event is executed. It takes the event name, the serialized parameters, and any additional arguments passed to the event function.
---
--- @param event string The name of the sync event being executed.
--- @param params string The serialized parameters for the sync event.
--- @param ... any Additional arguments to pass to the sync event hook.
---
--- @return nil
function ExecuteSyncEventHook(event, params, ...)
end

MapVar("SyncEventsQueue", {})
MapGameTimeRepeat("SyncEvents", -1, function()
	if IsChangingMap() then
		WaitMsg("PostNewMapLoaded")
		assert(GameTime() == 0)
	end
	local queue = SyncEventsQueue
	while true do
		local event_data = queue[1]
		if not event_data then
			break
		end
		table.remove(queue, 1)
		local time, event, params = event_data[1], event_data[2], event_data[3]
		Sleep(time - GameTime())
		WaitAllOtherThreads()
		ExecuteSyncEventHook(event, params, unpack_params(event_data, 4))
		ExecuteSyncEvent(event, Unserialize(params))
		InterruptAdvance()
	end
	Msg("SyncEventsProcessed")
	WaitWakeup()
end)

---
--- Handles a network event received from the cloud socket.
---
--- This function is called when a network event is received from the cloud socket. It checks if the event parameters are compressed, and if so, decompresses them. It then either buffers the event for later processing, or processes the event immediately.
---
--- If the event is buffered, it is added to the `netBufferedEvents` table for later processing.
---
--- If the event is processed immediately, it checks if there is a handler for the event in the `NetEvents` table, and if so, calls the handler with the deserialized parameters. It also checks if there is a handler for the event in the `NetSyncEvents` table, and if so, schedules the event for synchronization.
---
--- @param event string The name of the network event.
--- @param params string The serialized parameters for the network event.
--- @param advance_time number The amount of time to advance the game time by.
--- @param time_factor number The time factor to apply to the game time advancement.
---
--- @return nil
function NetCloudSocket:rfnEvent(event, params, advance_time, time_factor)
	if params:byte(1) == 255 then
		params = DecompressPstr(params, 2)
	end
	if netBufferedEvents then
		netBufferedEvents[#netBufferedEvents + 1] = pack_params(event, params, advance_time, time_factor)
		return
	end
	NetStats.events_received = NetStats.events_received + 1
	if NetEvents[event] then
		sprocall(NetEvents[event], Unserialize(params))
		ProcessMissingHandles(event, params)
	end
	if NetSyncEvents[event] then
		local time = AdvanceToGameTimeLimit or GameTime()
		assert(time >= 0)
		if advance_time then
			NetEvents.AdvanceTime(advance_time, time_factor)
		end
		ScheduleSyncEvent(event, params, time)
	end
end

---
--- Calls a method on an object, ensuring the method exists and is a function.
---
--- This function is used to safely call a method on an object, ensuring that the object is not nil, the method name starts with "rfn", and the method is a function. If any of these conditions are not met, an assertion error is raised.
---
--- @param obj table The object to call the method on.
--- @param rfn string The name of the method to call.
--- @param ... any The arguments to pass to the method.
---
--- @return nil
function NetSyncEvents.ObjFunc(obj, rfn, ...)
	if not obj then
		assert(false, "Unresolved object calling " .. rfn)
		return
	end
	if not string.starts_with(rfn, "rfn") then
		assert(false, "Invalid method name " .. rfn)
		return
	end
	local func = obj[rfn]
	if type(func) ~= "function" then
		assert(false, "No such method " .. obj.class .. "." .. rfn)
		return
	end
	func(obj, ...)
end

---
--- Calls a method on multiple objects, ensuring the method exists and is a function.
---
--- This function is used to safely call a method on a list of objects, ensuring that each object is not nil, the method name starts with "rfn", and the method is a function. If any of these conditions are not met for any object, an assertion error is raised.
---
--- @param objs table[] The list of objects to call the method on.
--- @param rfn string The name of the method to call.
--- @param ... any The arguments to pass to the method.
---
--- @return nil
function NetSyncEvents.MultiObjFunc(objs, rfn, ...)
	for _, obj in ipairs(objs) do
		NetSyncEvents.ObjFunc(obj, rfn, ...)
	end
end


------ Game ready/start/stop

---
--- Sets the game ready to start.
---
--- This function is used to notify the network that the game is ready to start. It sends a message to the network with the "rfnReadyToStart" method, passing a boolean value indicating whether the game is ready or not.
---
--- @param ready boolean Whether the game is ready to start.
---
--- @return string|nil The error message if there was an error sending the message, or nil if the message was sent successfully.
function NetGameSetReadyToStart(ready)
	return NetGameSend("rfnReadyToStart", ready and true or false)
end

---
--- Waits for the game to start, setting the game as ready to start.
---
--- This function is used to wait for the game to start, after setting the game as ready to start. It sends a message to the network indicating that the game is ready to start, and then waits for the "NetGameInfo" message to indicate that the game has started. If the game does not start within the specified timeout, the function returns an error message.
---
--- @param timeout number The maximum time to wait for the game to start, in milliseconds. If not provided, the default is 60000 (1 minute).
---
--- @return string|nil The error message if the game did not start within the timeout, or nil if the game started successfully.
function NetWaitGameStart(timeout)
	if netGameInfo.started then return end
	local err = NetGameSetReadyToStart(true)
	if err then return err end
	local time = RealTime() + (timeout or 60000)
	while RealTime() - time < 0 do
		WaitMsg("NetGameInfo", 500)
		if netGameInfo.started then
			netDesync = false
			return
		end
	end
	return "timeout"
end


----- NetUpdateHash

-- these two cannot be used in a Sync network
---
--- Creates a temporary network object.
---
--- This function is used to create a temporary network object that can be used for network synchronization. The object is not persisted and is only valid for the current game session.
---
--- @param obj any The object to be synchronized over the network.
---
--- @return nil
function NetTempObject(obj)
end

---
--- Creates a network object.
---
--- This function is used to create a network object that can be used for network synchronization. The object is persisted and can be used across multiple game sessions.
---
--- @param obj any The object to be synchronized over the network.
---
--- @return nil
function NetObject(obj)
end
function NetTempObject(obj) end
function NetObject(obj) end

---
--- Forces a desync in the network synchronization.
---
--- This function is used to intentionally force a desync in the network synchronization. It calls the `NetUpdateHash` function with the reason "Forced Desync". This can be used for debugging or testing purposes, but should be avoided in production code as it can cause issues with network synchronization.
---
--- @param reason string The reason for the forced desync.
function Desync()
	NetUpdateHash("Forced Desync")
end

function OnMsg.NetGameJoined(game_id, unique_id)
	NetResetHashLog(HashLogSize)
	NetSetUpdateHash()
end

function OnMsg.NetGameLeft(reason)
	NetResetHashLog(HashLogSize)
	NetSetUpdateHash()
end

--[[ the check is performed on the C side
function NetUpdateHashCheck(reason, ...)
	local ok = IsGameTimeThread() or CurrentMap == "" or IsEditorActive() or GameTime() == 0 or ChangingMap or config.RealTimeNetUpdateHash
	if not ok then
		local params = {reason, ...}
		assert(ok, "NetUpdateHashCheck failed (real time thread?)")
		local text = pstr("", 256)
		for i, param in ipairs(params) do
			if i > 1 then text:append(", ") end
			if type(param) == "string" then
				text:append('"', param, '"')
			elseif IsValid(param) then
				text:appendf("%s(%d)", param.class, rawget(param, "handle") or 0)
			else
				text:append(tostring(param) or "???")
			end
		end
		print("NetUpdateHashCheck failed params", text)
	end
end
--]]

oldNotify = Notify
---
--- Notifies an object by calling a specified method on it. If the game time is 0, it calls the original `Notify` function. Otherwise, it creates a new game time thread to call the method on the object.
---
--- @param obj table The object to notify.
--- @param method string|function The method to call on the object, or a function to call with the object as the argument.
function Notify(obj, method)
	if GameTime() == 0 then
		return oldNotify(obj, method)
	end
	CreateGameTimeThread(function(obj, method)
		if IsValid(obj) then
			if type(method) == "function" then
				method(obj)
			else
				obj[method](obj)
			end
		end
	end, obj, method)
end

---
--- Cancels a notification. This function is not present in the sync network.
---
--- @param none
--- @return none
function CancelNotify()
	assert(not "Not present in sync network")
end