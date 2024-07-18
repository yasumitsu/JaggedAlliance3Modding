local old_NetWaitGameStart = NetWaitGameStart
g_dbgFasterNetJoin = false --Platform.developer
---
--- Waits for the game to start in a multiplayer game.
---
--- @param timeout number The maximum time to wait for the game to start, in milliseconds.
--- @return string|boolean The result of the wait operation. Can be "disconnected", "host left", or false if the game started successfully.
---
function NetWaitGameStart(timeout)
	if not netInGame then return "disconnected" end
	if netGamePlayers and table.count(netGamePlayers) <= 1 then
		--something fucks up in this scenario, when a player has left and we try to load a new game
		--server never starts the game even though we say we are ready
		NetGameSend("rfnStartGame")
		netDesync = false
		return (not NetIsHost()) and "host left" or false --not an error
	end
	
	-- to cancel out the "NetWaitGameStart" before the timeout in case we detect that the host left the game
	local cur_thread = CurrentThread()
	local thread_result = "waiting"
	local net_wait_thread = CreateRealTimeThread(function()
		local err = old_NetWaitGameStart(timeout)
		if thread_result == "waiting" then thread_result = err or false end
		Wakeup(cur_thread)
	end)
	local net_player_left_thread = CreateRealTimeThread(function()
		WaitMsg("NetPlayerLeft")
		if thread_result == "waiting" then thread_result = "player left" end
		Wakeup(cur_thread)
	end)
	local net_game_left_thread = CreateRealTimeThread(function()
		WaitMsg("NetGameLeft")
		if thread_result == "waiting" then thread_result = "net_game_left" end
		Wakeup(cur_thread)
	end)
	local net_disconnect_thread = CreateRealTimeThread(function()
		WaitMsg("NetDisconnect")
		if thread_result == "waiting" then thread_result = "disconnected" end
		Wakeup(cur_thread)
	end)
	WaitWakeup()
	if IsValidThread(net_wait_thread) then DeleteThread(net_wait_thread) end
	if IsValidThread(net_player_left_thread) then DeleteThread(net_player_left_thread) end
	if IsValidThread(net_game_left_thread) then DeleteThread(net_game_left_thread) end
	if IsValidThread(net_disconnect_thread) then DeleteThread(net_disconnect_thread) end
	return thread_result
end

local shield_vars = {}
local orig_cbs = {}

function OnMsg.ChangeMap()
	shield_vars = {}
end

--fire the ev once until cb fires and only on host
---
--- Fires a network synchronization event on the host once.
---
--- This function is a wrapper around `FireNetSyncEventOnce` that ensures the event is only fired on the host.
---
--- @param event string The name of the network synchronization event to fire.
--- @param ... any Arguments to pass to the network synchronization event.
---
function FireNetSyncEventOnHostOnce(event, ...)
	if netInGame and not NetIsHost() then return end
	FireNetSyncEventOnce(event, ...)
end

---
--- Fires a network synchronization event on the host once.
---
--- This function is a wrapper around `FireNetSyncEventOnce` that ensures the event is only fired on the host.
---
--- @param event string The name of the network synchronization event to fire.
--- @param ... any Arguments to pass to the network synchronization event.
---
function FireNetSyncEventOnce(event, ...)
	--sanity checks
	--if IsChangingMap() then return end --some events are fired before change map finishes..
	if GetMapName() == "" then return end
	if GameReplayScheduled then return end --dont play these events when waiting for record to start or they get played twice
	--if netGameInfo and netGameInfo.started == false then return end
	
	local shieldVarName = string.format("%s%d_fired", event, xxhash(Serialize(...)))
	local svv = shield_vars[shieldVarName]
	local time = AdvanceToGameTimeLimit or GameTime()
	if svv and time - svv < 1500 then return end
	
	orig_cbs[event] = orig_cbs[event] or NetSyncEvents[event]
	NetSyncEvents[event] = function(...)
		--print("FireNetSyncEventOnce received", event)
		shield_vars[shieldVarName] = nil
		NetSyncEvents[event] = orig_cbs[event]
		orig_cbs[event] = nil
		NetSyncEvents[event](...)
	end
	
	shield_vars[shieldVarName] = time
	--print("FireNetSyncEventOnce fire", event, GameTime(), AdvanceToGameTimeLimit, svv)
	NetSyncEvent(event, ...)
end

---
--- Checks if the current game is in a multiplayer session.
---
--- @return boolean true if the current game is in a multiplayer session, false otherwise
---
function IsInMultiplayerGame()
	return netInGame and table.count(netGamePlayers) > 1
end

---
--- Gets information about the other player in a multiplayer game.
---
--- @return table The information about the other player in the game.
---
function GetOtherNetPlayerInfo()
	local otherPlayer = netUniqueId == 1 and 2 or 1
	return netGamePlayers[otherPlayer]
end

---
--- Loads a network game session.
---
--- @param game_type string The type of the network game.
--- @param game_data string The compressed data for the network game session.
--- @param metadata table The metadata for the network game session.
--- @return boolean|string True if the game was loaded successfully, or an error message if it failed.
---
function LoadNetGame(game_type, game_data, metadata)
	local success, err = sprocall(_LoadNetGame, game_type, game_data, metadata)
	return not success and "failed sprocall" or err -- or false
end

---
--- Loads a network game session.
---
--- @param game_type string The type of the network game.
--- @param game_data string The compressed data for the network game session.
--- @param metadata table The metadata for the network game session.
--- @return string|false An error message if the game failed to load, or false if the game loaded successfully.
---
function _LoadNetGame(game_type, game_data, metadata)
	assert(game_type == "CoOp")
	--why is this here:
	--when client is catching up to host this code will execute before sync part has finished executing
	--the code before the second fence changes game state and this will cause the already finished game to desync
	--this seems the easiest solution in this case, to wait for sync part to finish up and then load
	NetSyncEventFence()
	
	SectorLoadingScreenOpen(GetLoadingScreenParamsFromMetadata(metadata, "load net game"))
	WaitChangeMapDone()
	
	Msg("PreLoadNetGame")
	CloseBlockingDialogs()
	ResetZuluStateGlobals()
	
	Sleep(10) --give ui time to close "gracefully"...
	assert(game_data and #game_data > 0)
	NetSyncEventFence("_LoadNetGame")
	NetStartBufferEvents("_LoadNetGame")
	local err = LoadGameSessionData(game_data, metadata)
	NetStopBufferEvents("_LoadNetGame")
	if not err then
		Msg("NetGameLoaded")
	end
	SectorLoadingScreenClose(GetLoadingScreenParamsFromMetadata(metadata, "load net game"))
	return err
end

---
--- Handles the loading of a network game session.
---
--- This function is called when a "LoadGame" network event is received. It decompresses the game data, loads the game session, and waits for the game to start.
---
--- @param game_type string The type of the network game.
--- @param game_data string The compressed data for the network game session.
--- @param metadata table The metadata for the network game session.
---
function NetEvents.LoadGame(game_type, game_data, metadata)
	CreateRealTimeThread(function()
		-- if not netInGame then return end -- !TODO: very narrow timing issue, player may leave game just before this is run
		assert(netInGame)
		
		local err
		if metadata and metadata.campaign and not CampaignPresets[metadata.campaign] then
			err = "missing campaign"
		elseif not IsInMultiplayerGame() then
			err = "connection lost before load game"
		else
			err = LoadNetGame(game_type, Decompress(game_data), metadata)
		end
		
		if err then print("LoadNetGame failed:", err) end
		err = err or NetWaitGameStart()
		if err then
			print("NetWaitGameStart failed:", err)
			NetLeaveGame(err)
			OpenPreGameMainMenu("")
			ShowMPLobbyError("disconnect-after-leave-game", err)
		end
	end)
end

function OnMsg.ResetGameSession()
	NetLeaveGame("ResetGameSession")
end

function OnMsg.NetGameJoined(game_id, unique_id)
	if Game and NetIsHost() then
		NetGameSend("rfnStartGame")
		AdvanceToGameTimeLimit = GameTime()
	end
end

---
--- Starts a hosted network game session.
---
--- This function is called when a "rfnCreateGame" network event is received. It loads the game data, waits for the game to start, and handles any errors that occur during the process.
---
--- @param game_type string The type of the network game.
--- @param game_data string The compressed data for the network game session.
--- @param metadata table The metadata for the network game session.
--- @return string|nil An error message if the game failed to start, or nil if the game started successfully.
---
function StartHostedGame(game_type, game_data, metadata)
	local wasInMultiplayerGame = IsInMultiplayerGame()
	if not netInGame then
		OpenPreGameMainMenu("")
		WaitLoadingScreenClose() 
		ShowMPLobbyError("connect", "disconnected")
		return "disconnected"
	end
	assert(NetIsHost())
	LoadingScreenOpen(GetLoadingScreenParamsFromMetadata(metadata, "host game"))
	if IsChangingMap() then
		WaitMsg("ChangeMapDone", 5000)
	end
	NetGameCall("rfnStopGame")
	Pause("net")
	if not string.starts_with(game_data, "return") then
		game_data = "return " .. game_data
	end
	local err = NetEvent("LoadGame", game_type, Compress(game_data), metadata)
	if err then print("NetEvent failed:", err)
	elseif not netInGame or wasInMultiplayerGame ~= IsInMultiplayerGame() then
		err = "connection lost before load game"
	end
	err = err or LoadNetGame(game_type, game_data, metadata)
	--TODO: enter sector already calls this, so if it timeouted there its gona have to timeout here as well before we actually do something
	err = err or NetWaitGameStart()
	if err then
		NetLeaveGame(err)
		OpenPreGameMainMenu("")
		ShowMPLobbyError("disconnect-after-leave-game", err)
	end
	Resume("net")
	LoadingScreenClose(GetLoadingScreenParamsFromMetadata(metadata, "host game"))
	return err
end

PlatformCreateMultiplayerGame = rawget(_G, "PlatformCreateMultiplayerGame") or empty_func
PlatformJoinMultiplayerGame = rawget(_G, "PlatformJoinMultiplayerGame") or empty_func

---
--- Hosts a multiplayer game session.
---
--- This function is called to create and start a new multiplayer game session. It connects to the multiplayer service, retrieves the list of enabled mods, and creates a new game with the specified parameters. The function returns an error message if the game failed to start, or nil if the game started successfully.
---
--- @param visible_to string The visibility setting for the game session.
--- @param campaignId string The ID of the campaign to use for the game session.
--- @return string|nil An error message if the game failed to start, or nil if the game started successfully.
---
function HostMultiplayerGame(visible_to, campaignId)
	campaignId = campaignId or rawget(_G, "DefaultCampaign") or "HotDiamonds"
	local err = MultiplayerConnect()
	if err then
		ShowMPLobbyError("connect", err)
		return err
	end

	local mods = g_ModsUIContextObj or ModsUIObjectCreateAndLoad()
	while not g_ModsUIContextObj or not g_ModsUIContextObj.installed_retrieved do
		Sleep(100)
	end
	local enabledMods = {}
	for mod, enabled in pairs(mods.enabled) do
		if enabled then
			local modDef = {
				luaRev = mods.mod_defs[mod].lua_revision,
				title = mods.mod_defs[mod].title,
				steamId = mods.mod_defs[mod].steam_id,
			}
			table.insert(enabledMods, modDef)
		end
	end
	
	local game_name = netDisplayName .. "'s game"
	local game_type = "CoopGame"
	local max_players = 2
	local info = {
		map = GetMapName(),
		campaign = Game and Game.Campaign or campaignId,
		mods = enabledMods,
		day = Game and TFormat.day() or 1,
		host_id = netAccountId,
		name = game_name,
		platform = Platform,
	}
	
	local err = PlatformCreateMultiplayerGame(game_type, game_name, nil, visible_to, info, max_players)
	if err then
		return err
	end
	
	local err, game_id = NetCall("rfnCreateGame", "CoopGame", "coop", game_name, visible_to, info, max_players)
	if err then
		return err
	end
	
	err = NetJoinGame(nil, game_id)
	if err then
		print("NetJoinGame", err)
		return err
	end
end

---
--- Attempts to connect to the multiplayer server.
---
--- @return string|nil An error message if the connection failed, or `nil` if the connection was successful.
function MultiplayerConnect()
	if NetIsOfficialConnection() then return end

	local msg = CreateUnclickableMessagePrompt(T(908809691453, "Multiplayer"), T(994790984817, "Connecting..."))

	local err, auth_provider, auth_provider_data, display_name, developerMode = NetGetProviderLogin()
	if err then
		msg:Close()
		return err
	end
	
	if auth_provider == "auto" and not developerMode then
		msg:Close()
		return "unknown-auth"
	end
	
	-- It is possible to reach this NetConnect while being already connected but NetIsOfficialConnection == false
	-- due to the auto-connect thread. In this case we want to force a disconnection since NetConnect will not attempt to
	-- make a new official connection otherwise.
	NetForceDisconnect() 
	local err = NetConnect(config.SwarmHost, config.SwarmPort, auth_provider, auth_provider_data, display_name, config.NetCheckUpdates)
	if msg.window_state == "open" or msg.window_state == "closing" then msg:Close() end
	
	if not err and netRestrictedAccount then
		err = "restricted"
		NetForceDisconnect()
	end
	
	if err then
		print("NetConnect", err)
	end

	return err
end

---
--- Assigns control of a mercenary to a guest player.
---
--- @param merc_id number The ID of the mercenary to assign control of.
--- @param guest boolean Whether the mercenary should be assigned to a guest player.
---
function AssignMercControl(merc_id, guest)
	if not NetIsHost() then
		return
	end
	local value = not not guest
	NetEchoEvent("AssignControl", merc_id, value)
end

--- Assigns control of a mercenary to a guest player.
---
--- @param merc_id number The ID of the mercenary to assign control of.
--- @param value boolean Whether the mercenary should be assigned to a guest player (true) or the host player (false).
function NetEvents.AssignControl(merc_id, value)
	local unit_data = gv_UnitData and gv_UnitData[merc_id]
	if not unit_data then return end
	local prop_value = value and 2 or 1
	unit_data:SetProperty("ControlledBy", prop_value)
	local unit = g_Units[merc_id]
	if unit then
		unit.ControlledBy = prop_value
		Msg("UnitControlChanged", unit, prop_value)
	else
		Msg("UnitDataControlChanged", unit_data, prop_value)
	end
	ObjModified(unit_data)
end

if FirstLoad then
	g_CoOpReadyToEnd = false
end

---
--- Handles the synchronization of the "ready to end turn" state for co-op players.
---
--- When a player is ready to end their turn, this function updates the `g_CoOpReadyToEnd` table
--- to reflect the player's readiness. If all players are ready, it triggers the "EndTurn" event
--- to notify the host that the turn can be ended.
---
--- @param player_id number The ID of the player who has indicated they are ready to end their turn.
--- @param isReady boolean Whether the player is ready to end their turn (true) or not (false).
---
function NetSyncEvents.CoOpReadyToEndTurn(player_id, isReady)
	if not g_CoOpReadyToEnd then g_CoOpReadyToEnd = {} end

	g_CoOpReadyToEnd[player_id] = isReady
	if player_id == netUniqueId then
		ObjModified(SelectedObj)
		SelectObj(false)
	end
	
	local endTurnButton = Dialogs.IModeCombatMovement.idEndTurnFrame
	if endTurnButton then
		endTurnButton:OnContextUpdate(Selection, true)
	end
	
	local otherPlayerHasNoLivingUnits = true
	local team = GetCurrentTeam()
	for i, u in ipairs(team.units) do
		if not u:IsDead() and not u:IsLocalPlayerControlled() then
			otherPlayerHasNoLivingUnits = false
			break
		end
	end
	if otherPlayerHasNoLivingUnits then
		NetSyncEvent("EndTurn", netUniqueId)
		return
	end
	
	if not NetIsHost() or #g_CoOpReadyToEnd ~= #netGamePlayers then return end

	for uid, ready in pairs(g_CoOpReadyToEnd) do
		if not ready then
			return
		end
	end
	
	NetSyncEvent("EndTurn", netUniqueId)
end

---
--- Fires a network synchronization event on the host player.
---
--- If the current player is the host, this function will directly call `NetSyncEvent` with the provided arguments.
--- If the current player is not the host, this function will do nothing.
---
--- @param ... any The arguments to pass to `NetSyncEvent`.
---
function FireNetSyncEventOnHost(...)
	if not netInGame or NetIsHost() then
		NetSyncEvent(...)
	end
end

--------------------------------------------------------
--synced clickage on uis and things common impl.
--------------------------------------------------------
--TODO: this needs a different pattern
--sooner or later players_clicked_premature_events gets leaked for the next time
--and there is not good time to reset it
--i guess it should start with a sync event maybe so both players can init
if FirstLoad then
	players_clicked_sync = false
	players_clicked_hooks = false
end

---
--- Prints the current state of the `players_clicked_sync` table.
---
--- This function is likely used for debugging purposes, to inspect the current state of the player click synchronization system.
---
function ClickSyncDump()
	print(players_clicked_sync)
end

---
--- Initializes the players' clicked synchronization state for the given `reason`.
---
--- This function sets up the necessary data structures to track whether each player has clicked for the given `reason`. It also registers callback functions to be called when all players have clicked, and when a player clicks.
---
--- @param reason string The reason for tracking player clicks.
--- @param on_done_waiting function The callback function to call when all players have clicked.
--- @param on_player_clicked function The callback function to call when a player clicks.
---
function InitPlayersClickedSync(reason, on_done_waiting, on_player_clicked)
	assert((netInGame and next(netGamePlayers)) or IsGameReplayRecording() or IsGameReplayRunning())
	--print("----------InitPlayersClickedSync", reason)
	players_clicked_sync = players_clicked_sync or {}
	players_clicked_hooks = players_clicked_hooks or {}
	players_clicked_sync[reason] = {}
	players_clicked_hooks[reason] = {["on_done_waiting"] = on_done_waiting, ["on_player_clicked"] = on_player_clicked}
	local t = players_clicked_sync[reason]
	for _, data in pairs(netGamePlayers) do
		t[data.id] = false
	end
end

---
--- Checks if all players have clicked for the given `reason`.
---
--- This function iterates through the `players_clicked_sync` table for the given `reason` and checks if all the values are `true`, indicating that all players have clicked.
---
--- @param reason string The reason for tracking player clicks.
--- @return boolean true if all players have clicked, false otherwise.
---
function HaveAllPlayersClicked(reason)
	if not players_clicked_sync then return true end
	local t = players_clicked_sync[reason]
	if not t then return true end
	
	for _, v in pairs(t) do
		if not v then
			return false
		end
	end
	return true
end

---
--- Marks the end of waiting for all players to click for the given `reason`.
---
--- This function removes the tracking data for the given `reason` from the `players_clicked_sync` and `players_clicked_hooks` tables. It then calls the `on_done_waiting` callback function if it exists, indicating that all players have clicked.
---
--- @param reason string The reason for tracking player clicks.
---
function DoneWaitingForPlayersToClick(reason)
	if players_clicked_sync and players_clicked_sync[reason] then
		players_clicked_sync[reason] = nil
		local hooks = players_clicked_hooks[reason]
		players_clicked_hooks[reason] = nil
		if hooks.on_done_waiting then
			hooks.on_done_waiting()
		end
	end
end

function OnMsg.NetGameLeft(reason)
	for click_reason, data in pairs(players_clicked_sync or empty_table) do
		DoneWaitingForPlayersToClick(click_reason)
	end
end

function OnMsg.NetPlayerLeft(player, reason)
	for click_reason, data in sorted_pairs(players_clicked_sync or empty_table) do
		--this might not work for more than 2 players depending on how sync NetPlayerLeft is
		data[player.id] = nil
		if HaveAllPlayersClicked(click_reason) then
			DoneWaitingForPlayersToClick(click_reason)
		end
	end
end

---
--- Handles the event when a player clicks ready for a specific reason.
---
--- This function is called when a NetSyncEvent "PlayerClickedReady" is received. It updates the `players_clicked_sync` table to mark the given player as having clicked ready for the specified reason. If all players have now clicked ready, it calls the `DoneWaitingForPlayersToClick` function to indicate that the waiting is complete. Otherwise, it calls the `on_player_clicked` callback function in the `players_clicked_hooks` table for the given reason.
---
--- @param player_id number The ID of the player who clicked ready.
--- @param reason string The reason for tracking player clicks.
--- @param event_id any The ID of the sync event.
---
function NetSyncEvents.PlayerClickedReady(player_id, reason, event_id)
	--print("NetSyncEvents.PlayerClickedReady", player_id, reason)
	if not PlayersClickedSync_IsInitializedForReason(reason) then
		return
	end
	local t = players_clicked_sync[reason]
	if t[player_id] ~= false then return end
	
	t[player_id] = true
	local all_clicked = HaveAllPlayersClicked(reason)
	
	if all_clicked then
		DoneWaitingForPlayersToClick(reason)
	else
		local hooks = players_clicked_hooks[reason]
		if hooks.on_player_clicked then
			hooks.on_player_clicked(player_id, t)
		end
	end
end

---
--- Checks if the given player is waiting to click for the specified reason.
---
--- @param player_id number The ID of the player to check.
--- @param reason string The reason for tracking player clicks.
--- @return boolean true if the player is waiting to click, false otherwise.
---
function IsWaitingForPlayerToClick(player_id, reason)
	if players_clicked_sync then
		if players_clicked_sync[reason] then
			return players_clicked_sync[reason][player_id] == false
		end
	end
	return false
end

---
--- Checks if the player click sync has been initialized for the given reason.
---
--- @param reason string The reason for tracking player clicks.
--- @return boolean true if the player click sync has been initialized for the given reason, false otherwise.
---
function PlayersClickedSync_IsInitializedForReason(reason)
	if players_clicked_sync then
		if players_clicked_sync[reason] then
			return true
		end
	end
	return false
end

---
--- Notifies the server that the local player has clicked ready for the specified reason.
---
--- This function is called when the local player has clicked ready for a specific reason, such as during an outro sequence.
--- It checks if the game has started and if the local player is waiting to click for the specified reason. If so, it sends a network event to notify the server that the local player has clicked ready.
---
--- @param reason string The reason for tracking player clicks.
---
function LocalPlayerClickedReady(reason)
	--wait for netGameInfo.started, since it could go out 2 early and appear on only 1 client
	if netGameInfo.started and IsWaitingForPlayerToClick(netUniqueId, reason) then
		--TODO: on one hand, i dont like the player spamming net with clicks
		--on the other, event can get lost n shit;
		NetSyncEvent("PlayerClickedReady", netUniqueId, reason)
	end
end

--------------------------------------------------
--common outro/intro
--------------------------------------------------
local function lCloseSyncedDlg(self, msg)
	if self.window_state ~= "destroying" and self.window_state ~= "closing" then
		self:Close()
		Msg(msg)
	end
end

local function lOnPlayerClickedSyncDlg(self, player_id, data) --on player clicked
	if not self.idSkipHint:GetVisible() then
		self.idSkipHint:SetVisible(true)
	end
	if data[netUniqueId] then
		self.idSkipHint:SetText(T(769124019747, "Waiting for <u(GetOtherPlayerNameFormat())>..."))
	else
		if table.count(netGamePlayers) == 2 then
			self.idSkipHint:SetText(T(270246785102, "<u(GetOtherPlayerNameFormat())> skipped the cutscene"))
		else
			self.idSkipHint:SetText(T{181264542969, "<Count>/<Total> players skipped the cutscene", Count = table.count(data, function(k, v) return v end), Total = table.count(netGamePlayers)})
		end
	end
end
--------------------------------------------------
--outro impl
--------------------------------------------------
---
--- Handles keyboard and gamepad shortcuts for the comic dialog.
---
--- This function is called when a keyboard or gamepad shortcut is detected while the comic dialog is open. It checks if the shortcut is valid for the current game mode (single-player or multiplayer) and performs the appropriate action, such as closing the dialog or notifying other players of the local player's click.
---
--- @param self table The comic dialog object.
--- @param shortcut string The name of the detected shortcut.
--- @param source string The source of the shortcut (e.g. keyboard, gamepad).
--- @param ... Additional arguments passed to the function.
--- @return string The result of the shortcut handling, which can be "break" to stop further processing of the shortcut.
---
function ComicOnShortcut(self, shortcut, source, ...)
	if RealTime() - self.openedAt < 500 then return "break" end
	if RealTime() - terminal.activate_time < 500 then return "break" end
	
	if IsInMultiplayerGame() then
		if shortcut ~= "Escape" and shortcut ~= "ButtonB" and shortcut ~= "MouseL" then return "break" end
		assert(PlayersClickedSync_IsInitializedForReason("Outro"))
		LocalPlayerClickedReady("Outro")
	else
		if not self.idSkipHint:GetVisible() then
			self.idSkipHint:SetVisible(true)
			return "break"
		end
		if shortcut ~= "Escape" and shortcut ~= "ButtonB" and shortcut ~= "MouseL" then return "break" end
		self:Close()
	end
	return "break"
end


---
--- Handles the opening of the comic dialog.
---
--- This function is called when the comic dialog is opened. It sets up the dialog, including the skip hint text, and initializes the players' clicked sync for multiplayer games.
---
--- @param self table The comic dialog object.
--- @param ... Additional arguments passed to the function.
---
function ComicOnOpen(self, ...)
	XDialog.Open(self, ...)
	rawset(self, "openedAt", RealTime())
	
	if GetUIStyleGamepad(nil, self) then
		self.idSkipHint:SetText(T(576896503712, "<ButtonB> Skip"))
	else
		self.idSkipHint:SetText(T(696052205292, "<style SkipHint>Escape: Skip</style>"))
	end
	
	if IsInMultiplayerGame() then
		InitPlayersClickedSync("Outro",
			function() --on done
				OutroClose(self)
			end,
			function(player_id, data) --on player clicked
				lOnPlayerClickedSyncDlg(self, player_id, data)
			end)
	end
end

---
--- Closes the synced dialog with the given reason.
---
--- @param self table The dialog object.
---
function OutroClose(self)
	lCloseSyncedDlg(self, "OutroClosed")
end

--------------------------------------------------
--intro impl
--------------------------------------------------
---
--- Closes the synced dialog with the given reason.
---
--- @param self table The dialog object.
---
function IntroClose(self)
	lCloseSyncedDlg(self, "IntroClosed")
end

---
--- Handles the click event for the Intro dialog button.
---
--- If the game is in a multiplayer session, this function checks if the players' clicked sync for the Intro dialog has been initialized. If so, it marks the local player as having clicked the button. If the game is in single-player, this function simply closes the Intro dialog.
---
--- @param self table The Intro dialog object.
---
function IntroOnBtnClicked(self)
	if IsInMultiplayerGame() then
		if not PlayersClickedSync_IsInitializedForReason("Intro") then return end --click after end spam
		LocalPlayerClickedReady("Intro")
	else
		IntroClose(self)
	end
	return "break"
end

---
--- Initializes the players' clicked sync for the Intro dialog.
---
--- If the game is in a multiplayer session, this function sets up a sync mechanism to track when players have clicked the Intro dialog. When the dialog is closed, the "on done" callback is executed. When a player clicks the dialog, the "on player clicked" callback is executed with the player ID and any associated data.
---
--- @param self table The Intro dialog object.
---
function IntroOnOpen(self)
	if IsInMultiplayerGame() then
		InitPlayersClickedSync("Intro",
			function() --on done
				IntroClose(self)
			end,
			function(player_id, data) --on player clicked
				lOnPlayerClickedSyncDlg(self, player_id, data)
			end)
	end
end

------------------------------------------------
--synced loaded/loading state and msg
------------------------------------------------
---
--- Waits for the sync loading state to be complete.
---
--- This function blocks until the `sync_loading` game state is set to `false`, indicating that the sync loading process has finished.
---
--- @function WaitSyncLoadingDone
--- @return nil
function WaitSyncLoadingDone()
	if GameState.sync_loading then
		WaitGameState({sync_loading = false})
	end
end

---
--- Sets the game state to indicate that sync loading has started.
---
--- This function is called when the sync loading process begins. It sets the `sync_loading` game state to `true`, which can be used to track the progress of the sync loading.
---
--- @function NetSyncEvents.SyncLoadingStart
--- @return nil
function NetSyncEvents.SyncLoadingStart()
	ChangeGameState("sync_loading", true)
end
---
--- Handles the echo event for the start of sync loading.
---
--- This function is called when the `SyncLoadingStart` event is received, but the `sync_loading` game state has not yet been set to `true`. It attempts to wait for the `sync_loading` state to be set, and then sets it to `true` if it has not already been set.
---
--- This function is a fallback in case the `SyncLoadingStart` event is not received, and is used to ensure that the `sync_loading` state is properly set.
---
--- @function NetEvents.SyncLoadingStartEcho
--- @return nil
function NetEvents.SyncLoadingStartEcho()
	local function Dispatch()
		CreateGameTimeThread(function()
			local idx = table.find(SyncEventsQueue, 2, "SyncLoadingStart")
			local t = idx and SyncEventsQueue[idx][1]
			PauseInfiniteLoopDetection("SyncLoadingHack")
			while not GameState.sync_loading and
					IsValidThread(PeriodicRepeatThreads["SyncEvents"]) and
					t == GameTime() do
				WaitAllOtherThreads()
			end
			ResumeInfiniteLoopDetection("SyncLoadingHack")
			ChangeGameState("sync_loading", true)
		end)
	end

	CreateRealTimeThread(function()
		WaitAllOtherThreads()
		local idx = table.find(SyncEventsQueue, 2, "SyncLoadingStart")
		local attempts = 4
		local attempt = 0
		while not idx and not IsChangingMap() do
			--sync event might not have arrived yet, and might still arrive
			Sleep(5)
			idx = table.find(SyncEventsQueue, 2, "SyncLoadingStart")
			attempt = attempt + 1
			if attempt > attempts then
				break
			end
		end
		
		if not idx then
			if not idx then
				Dispatch()
				return
			end
		end
		local ev = idx and SyncEventsQueue[idx]
		local t = ev[1]
		local ts = GameTime()
		--while GameTime() < t and ts <= GameTime() and netGameInfo.started and not IsChangingMap() do
		--netGameInfo.started  makes it fire too early when leaving game to load a new game. that makes some fake desync logs n messages (game is already over);
		while GameTime() < t and ts <= GameTime() and not IsChangingMap() do 
			Sleep(Min(t - GameTime(), 12))
		end
		
		Dispatch()
	end)
end

--function NetSyncEvents.SyncLoadingDone()
---
--- Marks the end of the sync loading process.
--- This function is called when the sync loading process is complete.
--- It changes the game state to indicate that sync loading is finished,
--- and sends a message to notify other parts of the system.
---
function NetSyncEvents.SyncLoadingDone()
	ChangeGameState("sync_loading", false)
	Msg("SyncLoadingDone")
end

function OnMsg.GameStateChanged(changed)
	if not netInGame or NetIsHost() then
		if changed.loading then
			NetSyncEvent("SyncLoadingStart")
			--due to fencing this should no longer be needed, also it causes rare fake desyncs when sync and non sync event are vry temporaly misaligned 
			--NetEchoEvent("SyncLoadingStartEcho") --fallback if we leave map and sync doesnt fire
			
			CreateRealTimeThread(function()
				WaitLoadingScreenClose()
				NetSyncEvent("SyncLoadingDone")
			end)
		end
	end
end

---
--- Checks if the network game has started.
---
--- This function is not synchronized across the network. It checks the `netInGame` and `netGameInfo.started` flags to determine if the network game has started.
---
--- @return boolean true if the network game has started, false otherwise
function IsNetGameStarted() --this is not sync!
	return not netInGame or netGameInfo.started
end

------------------------------------------------
--netsync ev on net disconnect watch dog
--tries to recover events potentially lost on net disconnect
------------------------------------------------
if FirstLoad then
	sent_events = {}
	events_sent_while_disconnecting = {}
	disconnecting = false
end

function OnMsg.NewMap()
	--in case our dispatcher gets killed due to map change this can hang to true
	disconnecting = false
end

local function DispatchList(lst)
	for i = 1, #lst do
		NetSyncEvent(lst[i][1], unpack_params(lst[i][2]))
	end
	table.clear(lst)
end

function OnMsg.ClassesGenerate()
	local orig_func = _G["NetSyncEvent"]
	_G["NetSyncEvent"] = function(event, ...)
		if netInGame or disconnecting then
			sent_events[#sent_events + 1] = {event, pack_params(...)}
			if disconnecting then
				return
			end
		end
		orig_func(event, ...)
	end
end

local function findFirstSentEvent(event)
	for i = 1, #sent_events do
		if sent_events[i][1] == event then
			return i
		end
	end
end

function OnMsg.SyncEvent(event, ...)
	if not disconnecting and not netInGame then
		return
	end
	if #sent_events <= 0 then
		return
	end
	
	local idx = findFirstSentEvent(event)
	if idx then
		if idx ~= 1 then
			--some dropped event exists, possibly due to change map
			table.move(sent_events, idx + 1, #sent_events, 1)
			local to = #sent_events - idx + 1
			for j = #sent_events, to, -1 do
				sent_events[j] = nil
			end
		else
			table.remove(sent_events, idx)
		end
	end
end

function OnMsg.NetDisconnect()
	if #sent_events <= 0 then
		return
	end
	disconnecting = true
	print("Thread Created", #sent_events)
	CreateGameTimeThread(function()
		while SyncEventsQueue and #SyncEventsQueue > 0 do
			local t = GetThreadStatus(PeriodicRepeatThreads["SyncEvents"])
			if t > GameTime() then
				Sleep(t - GameTime())
			end
			WaitAllOtherThreads()
			InterruptAdvance()
		end
		disconnecting = false
		print("RE-Sending events", #sent_events)
		DispatchList(sent_events)
	end)
end

--test, kill connection before 5 secs after calling this
local events = 0
local thread = false

---
--- Initiates a test disconnection sequence.
---
--- This function creates a real-time thread that sends 500 "Testing" sync events over the network, with a 10 millisecond delay between each event. The number of events sent is tracked in the `events` variable. The thread is stored in the `thread` variable, and can be deleted by calling `DeleteThread(thread)`.
---
--- This function is likely used for testing or debugging purposes, to simulate a large number of sync events being sent over the network.
---
function TestDisc()
	DeleteThread(thread)
	events = 0
	thread = CreateRealTimeThread(function()
		for i = 1, 500 do
			NetSyncEvent("Testing", i)
			events = events + 1
			Sleep(10)
		end
	end)
end

---
--- Handles the receipt of a "Testing" sync event over the network.
---
--- This function is called when a "Testing" sync event is received over the network. It decrements the `events` variable and prints a message to the console indicating that the event was received, along with the event index and the remaining number of events.
---
--- This function is likely used for testing or debugging purposes, to verify that sync events are being properly received over the network.
---
function NetSyncEvents.Testing(i)
	events = events - 1
	print("!!!!!!!!!!!!!!!Testing received!", i, events)
end

------------------------------------------
--fence
------------------------------------------

MapVar("g_NetSyncFence", false)
if FirstLoad then
	g_NetSyncFenceWaiting = false
	g_NetSyncFenceInitBuffer = false
end

function OnMsg.DoneGame()
	--the fenced thread, if any, should be killed by its handlers, so we just need to clean up
	g_NetSyncFence = false
	g_NetSyncFenceWaiting = false
	g_NetSyncFenceInitBuffer = false
end

function OnMsg.SyncLoadingDone()
	if g_NetSyncFenceWaiting then
		return
	end
	FenceDebugPrint("SyncLoadingDone")
	--NetUpdateHash("g_NetSyncFence", not not g_NetSyncFence) --fence can be asynchroniously started (loadnetgame), in which case this may cause a false positive
	g_NetSyncFence = false
end

---
--- Handles the receipt of a "FenceReceived" sync event over the network.
---
--- This function is called when a "FenceReceived" sync event is received over the network. It updates the `g_NetSyncFence` table to indicate that the event has been received for the given player ID. Once all players have received the fence event, it calls the `StartBufferingAfterFence()` function to start buffering events after the fence.
---
--- @param playerId number The ID of the player who received the fence event.
---
function NetSyncEvents.FenceReceived(playerId)
	if not g_NetSyncFence then g_NetSyncFence = {} end
	FenceDebugPrint("-------FenceReceived", g_NetSyncFence, playerId)
	g_NetSyncFence[playerId] = true
	
	local eventNotFound = false
	for id, player in pairs(netGamePlayers) do
		if not g_NetSyncFence[id] then
			eventNotFound = true
			break
		end
	end
	
	if not eventNotFound then
		if g_NetSyncFenceInitBuffer then
			StartBufferingAfterFence()
			g_NetSyncFenceInitBuffer = false
		end
		Msg(g_NetSyncFence)
	end
end

---
--- Prints a debug message with the provided arguments.
---
--- This function is used to print debug messages with the provided arguments. If the `true` condition is true, the function will simply return without printing anything. Otherwise, it will convert all the arguments to strings and concatenate them, separated by commas, and print the resulting message.
---
--- @param ... any The arguments to be printed as a debug message.
---
function FenceDebugPrint(...)
	--print(...)
	if true then return end
	local args = {...}
	for i, a in ipairs(args) do
		args[i] = tostring(a)
	end
	DebugPrint(table.concat(args, ", ") .. "\n")
end

---
--- Starts buffering events after a network synchronization fence has been received.
---
--- This function is called after a network synchronization fence has been received, indicating that all previous network events have been processed. It starts buffering new network events to ensure that events for the next map are not dropped or executed before the map change occurs.
---
--- The function performs the following steps:
--- - Starts buffering network events using `NetStartBufferEvents()`.
--- - Moves any events that were already scheduled after the fence from the `SyncEventsQueue` to the `netBufferedEvents` table.
--- - Clears the `SyncEventsQueue` to ensure no events are dropped or executed before the map change.
--- - Sends a "rfnClearHash" message to the server to clear any passed caches stored on the server side.
--- - Deletes the "NetHashThread" periodic repeat thread to ensure no new hashes are generated for the current map after the hash reset.
---
function StartBufferingAfterFence()
	--we want to start buffering asap after fence
	--basically, all events before the fence are for the current map and all events after the fence are for the next map
	--we don't want to drop any, which may happen if next map events are already scheduled for some reason or another
	NetStartBufferEvents(g_NetSyncFenceInitBuffer)
	local q = SyncEventsQueue
	for i = 1, #(q or "") do
		--if events are already scheduled after the fence they will get dropped or executed before map change
		--presumably, these events are for the next map, so stick them in the buffer and rem from queue
		--tbh, I never got this to happen so it might not be possible
		local event_data = q[i]
		netBufferedEvents[#netBufferedEvents + 1] = pack_params(event_data[2], event_data[3], nil, nil)
	end
	table.clear(q)
	
	NetGameSend("rfnClearHash") --this clears passed caches stored server side so new hashes @ the same gametime doesn't cause desyncs
	if IsValidThread(PeriodicRepeatThreads["NetHashThread"]) then
		DeleteThread(PeriodicRepeatThreads["NetHashThread"]) --make sure no new hashes come from this map after hash reset
	end
end

-- Ensures that all previous net sync events in flight have been processed by the client
---
--- Synchronizes the network by waiting for all previous network events to be processed.
---
--- This function is used to ensure that all previous network synchronization events have been processed by the client before proceeding. It performs the following steps:
---
--- 1. Checks if the game is currently in a replay session. If so, it waits for the replay fence to be cleared before returning.
--- 2. Checks if the game is currently paused or if the map name is empty. If so, it returns early without performing the fence.
--- 3. Sends a "FenceReceived" network sync event to queue as the last event, ensuring that all previous events have been processed.
--- 4. Waits for the "FenceReceived" event to be received by all players, with a timeout of 60 seconds to prevent an endless wait.
--- 5. Clears the `g_NetSyncFence` and `g_NetSyncFenceWaiting` flags, and sets the `g_NetSyncFenceInitBuffer` flag based on the provided `init_buffer` parameter.
---
--- @param init_buffer boolean Whether to start buffering events after the fence is received.
--- @return string The result of the fence operation, which can be "replay", "Not on map", "Game paused", or nil if successful.
---
function NetSyncEventFence(init_buffer)
	assert(CanYield())
	if netBufferedEvents then
		return "Cant fence while buffering"
	end
	
	if IsGameReplayRunning() then
		if not g_NetSyncFence then g_NetSyncFence = {} end
		g_NetSyncFenceWaiting = true
		while not g_NetSyncFence[netUniqueId] do
			WaitMsg(g_NetSyncFence, 100)
		end
		g_NetSyncFenceWaiting = false
		g_NetSyncFence = false
		Msg("ReplayFenceCleared")
		return "replay"
	end
	
	-- The sync event queue is a map thread and wouldn't be running at this point.
	if GetMapName() == "" then
		--print("fence early out")
		return "Not on map"
	end
	-- If threads are stopped we wont get a response so dont bother. Happens with synthetic tests;
	if GetGamePause() then
		--print("fence early out")
		return "Game paused"
	end
	--FenceDebugPrint("FENCE-PRE-PRE-START", GetStack())
	FenceDebugPrint("FENCE PRE-START", g_NetSyncFence, "netGamePlayers count:", table.count(netGamePlayers), g_NetSyncFenceWaiting)
	if not g_NetSyncFence then g_NetSyncFence = {} end
	-- This will queue as the last net sync event, meaning that once it loops back
	-- all previous events would have as well.
	NetSyncEvent("FenceReceived", netUniqueId)
	FenceDebugPrint("FENCE START", g_NetSyncFence)
	local timeout = GetPreciseTicks()
	assert(g_NetSyncFenceWaiting == false)
	g_NetSyncFenceWaiting = true
	g_NetSyncFenceInitBuffer = init_buffer or false
	while IsInMultiplayerGame() or not g_NetSyncFence[netUniqueId] do
		-- Just in case, to prevent endless loading if something goes wrong here
		if GetPreciseTicks() - timeout > 60 * 1000 then
			FenceDebugPrint("NETFENCE TIMEOUT")
			break
		end
	
		local ok = WaitMsg(g_NetSyncFence, 100)
		if ok then 
			FenceDebugPrint("FENCE Msg received")
			break
		end
	end
	g_NetSyncFenceWaiting = false
	g_NetSyncFenceInitBuffer = false
	FenceDebugPrint("FENCE DONE", IsInMultiplayerGame(), (GetPreciseTicks() - timeout))
	assert(not netInGame or #(g_NetSyncFence or "") >= table.count(netGamePlayers))
	g_NetSyncFence = false
end

if Platform.developer and false then
	--this is only valid when fencing change map;
	function OnMsg.ClassesGenerate()
		local f = _G["NetSyncEvent"]
		_G["NetSyncEvent"] = function(event, ...)
			assert(not g_NetSyncFence or event == "FenceReceived", "" .. event .. " fired during fence!")
			return f(event, ...)
		end
	end
end

--------------------------------------- 
--sat view hash check
if Platform.developer then --they play release version..
	local hashes
	
	function OnMsg.InitSatelliteView()
		hashes = false
	end
	
	function OnMsg.ChangeMap()
		hashes = false
	end
	
	function NetSyncEvents.SatDesync(...)
		if not netDesync then
			hashes = false
			NetSyncEvents.Desync(...)
		end
	end
	
	function NetEvents.SyncHashesOnSatMap(player_id, time, hash)
		if netDesync then return end
		hashes = hashes or {}
		hashes[player_id] = hashes[player_id] or {}
		--assert(not hashes[player_id][time]) --rechecking during pause is ok
		hashes[player_id][time] = hash
		
		--assumes 2 players
		local h1 = hashes[1] and hashes[1][time]
		local h2 = hashes[2] and hashes[2][time]
		if h1 and h2 then
			hashes = false
			if h1 ~= h2 then
				--print(h1, h2, time)
				NetSyncEvent("SatDesync", netGameAddress, time, player_id, h1, h2)
			end
		end
	end
	
	function OnMsg.NewHour()
		if IsInMultiplayerGame() and not netDesync then
			NetEchoEvent("SyncHashesOnSatMap", netUniqueId, Game.CampaignTime, NetGetHashValue())
		end
	end
end
---------------------------------------
---
--- Removes a client from the current multiplayer game.
---
--- @param id number The unique ID of the client to remove.
--- @param reason? string The reason for removing the client (optional).
---
function NetEvents.RemoveClient(id, reason)
	if netUniqueId == id then
		NetLeaveGame(reason or "kicked")
	end
end

---------------------------------------
---
--- Closes the satellite view.
---
--- This function is called when the satellite view is closed. It sets the `gv_SatelliteView` global variable to `false` and sends a `CloseSatelliteView` message.
---
--- @function OnSatViewClosed
--- @return nil
function OnSatViewClosed()
	if not gv_SatelliteView then return end
	gv_SatelliteView = false
	ObjModified("gv_SatelliteView")
	Msg("CloseSatelliteView")
end

---
--- Closes the satellite view.
---
--- This function is called when the satellite view is closed. It sets the `gv_SatelliteView` global variable to `false` and sends a `CloseSatelliteView` message.
---
--- @function NetSyncEvents.SatelliteViewClosed
--- @return nil
function NetSyncEvents.SatelliteViewClosed()
	OnSatViewClosed()
end

-------------------------------------------
-------------------------------------------
-------------------------------------------

if Platform.developer then

--common stuff
---
--- Launches another client for multiplayer testing.
---
--- This function launches another instance of the game client with the specified command-line arguments.
---
--- @param varargs table|string Optional command-line arguments to pass to the new client instance.
--- @return nil
function LaunchAnotherClient(varargs)
	local exec_path = GetExecDirectory() .. "/" .. GetExecName()
	local path = string.format("\"%s\" -no_interactive_asserts -slave_for_mp_testing", exec_path)
	if varargs then
		if type(varargs) == "string" then
			varargs = {varargs}
		end
		for i, v in ipairs(varargs) do
			path = string.format("%s %s", path, v)
		end
	end
	print("os.exec", path)
	os.exec(path)
end

local function lRunErrFunc(func_name, ...)
	local err = _G[func_name](...)
	if err then
		GameTestsPrintf("Function returned an error[" .. func_name .. "]: " .. err)
	end
	return err
end

local function lDbgHostMultiplayerGame()
	return lRunErrFunc("HostMultiplayerGame", "private")
end

---
--- Connects to the multiplayer game.
---
--- This function attempts to connect to the multiplayer game and returns any errors that occur.
---
--- @return string|nil Any error that occurred during the connection, or nil if the connection was successful.
function lDbgMultiplayerConnect()
	return lRunErrFunc("MultiplayerConnect")
end

---
--- Hosts a multiplayer game, launches another client, and joins the game.
---
--- This function performs the following steps:
--- 1. Connects to the multiplayer game using `lDbgMultiplayerConnect()`.
--- 2. Hosts the multiplayer game using `lDbgHostMultiplayerGame()`.
--- 3. Launches another client with the address of the hosted game passed as a command-line argument.
--- 4. Waits for the other client to join the game.
---
--- @param test_func_name string (optional) The name of a test function to be passed as a command-line argument to the launched client.
--- @return string|nil Any error that occurred during the process, or nil if successful.
function HostMpGameAndLaunchAndJoinAnotherClient(test_func_name)
	print("HostMpGameAndLaunchAndJoinAnotherClient...")
	Pause("JoiningClients")
	local err = lDbgMultiplayerConnect()
	err = err or lDbgHostMultiplayerGame()
	if err then
		Resume("JoiningClients")
		return err
	end
	local address = netGameAddress
	local varargs = {"-test_mp_game_address=" .. tostring(address)}
	if test_func_name then
		table.insert(varargs, "-test_mp_func_name=" .. test_func_name)
	end
	LaunchAnotherClient(varargs)
	print("Waiting for client!")
	local ok = WaitMsg("NetGameLoaded", 90000)
	Resume("JoiningClients")
	if not ok then
		local err = "Timeout waiting for other client to launch/join!"
		print(err)
		return err
	end
end

---
--- Starts a new cooperative multiplayer game.
---
--- This function performs the following steps:
--- 1. Checks if the current thread is a real-time thread, and if not, creates a new real-time thread to execute the function.
--- 2. Checks if there is an existing MPTestSocket instance. If not, it initializes the MPTestListener, launches another client with the "-test_mp_dont_auto_quit" argument, and waits for the other client to be ready.
--- 3. Stops the current game, cleans up the game state, connects to the multiplayer game, and hosts the multiplayer game.
--- 4. Sends the "rfnJoinMeInGame" message to the MPTestSocket instance with the address of the hosted game.
--- 5. Waits for the other client to be ready, and then executes the ExecCoopStartGame function to start the cooperative multiplayer game.
---
--- @return nil
function TestCoopNewGame()
	if not IsRealTimeThread() then
		CreateRealTimeThread(TestCoopNewGame)
		return
	end
	
	if not g_MPTestSocket then
		--if no slave client running
		local varargs = {"-test_mp_dont_auto_quit"}
		InitMPTestListener()
		LaunchAnotherClient(varargs)
		if not WaitOtherClientReady() then
			return
		end
	end
	--todo: make a new game start from mm as well
	NetGameCall("rfnStopGame")
	DoneGame()
	CloseMPErrors()
	lDbgMultiplayerConnect()
	lDbgHostMultiplayerGame()
	g_MPTestSocket:Send("rfnJoinMeInGame", netGameAddress)
	if not WaitOtherClientReady() then
		return
	end
	
	ExecCoopStartGame()
end

if FirstLoad then
	TestCoopFuncs = {
	}
	g_MPTestingSlave = false
	g_MPTestingSocketPort = 6666
	g_MPTestListener = false
	g_MPTestSocket = false
end

DefineClass.MPTestSocket = {
	__parents = { "MessageSocket" },
	
	socket_type = "MPTestSocket",
}

---
--- Checks the hash values between the local game state and the remote game state.
--- This function is called when the game is paused, and will not work if the game is not paused.
---
--- @return nil
function MPTestSocket:CheckHashes()
	--this is for when game is paused and won't work if game not paused
	CreateRealTimeThread(function()
		local hisHash = self:Call("rfnGiveMeYourHash")
		print("Hashes equal:", NetGetHashValue() == hisHash)
	end)
end

---
--- Returns the hash value of the current game state.
---
--- This function is used to check the hash values between the local game state and the remote game state when the game is paused. It will not work if the game is not paused.
---
--- @return number The hash value of the current game state.
function MPTestSocket:rfnGiveMeYourHash()
	return NetGetHashValue()
end

---
--- Quits the current application.
---
--- This function is called when the client wants to quit the current application.
---
--- @return nil
function MPTestSocket:rfnQuit()
	quit()
end

---
--- Handles the handshake process between the client and server in a multiplayer test scenario.
---
--- This function is called when a handshake message is received from the remote client. It ensures that there is only one active MPTestSocket instance, and sets the master/slave status of the socket based on the g_MPTestingSlave global flag.
---
--- @param self MPTestSocket The instance of the MPTestSocket class.
--- @return nil
function MPTestSocket:rfnHandshake()
	print("Handshake received")
	if g_MPTestSocket ~= self then
		if IsValid(g_MPTestSocket) then
			g_MPTestSocket:Send("rfnQuit")
			g_MPTestSocket:delete()
		end
		
		g_MPTestSocket = self
	end
	if not g_MPTestSocket then
		g_MPTestSocket = self
		g_MPTestSocket:Send("rfnHandshake")
	else
		assert(g_MPTestSocket == self)
	end
	g_MPTestSocket.master = not g_MPTestingSlave
	g_MPTestSocket.slave = g_MPTestingSlave
end

---
--- Waits for the other client to be ready in a multiplayer test scenario.
---
--- This function waits for a message indicating that the other client is ready to join the game. It will wait for up to 90 seconds before timing out.
---
--- @return boolean true if the other client is ready, false otherwise
function WaitOtherClientReady()
	local ok, remote_err = WaitMsg("MPTest_OtherClientReady", 90000)
	if not ok then
		print("Timeout waiting for other client to boot")
	end
	return ok and not remote_err
end

---
--- Notifies the other client that this client is ready to join the game.
---
--- This function is called after the client has successfully connected to the game. It sends a message to the other client indicating that this client is ready to join the game.
---
--- @param self MPTestSocket The instance of the MPTestSocket class.
--- @param err string|nil An error message if there was a problem connecting to the game.
--- @return nil
function MPTestSocket:rfnReady(err)
	if err then
		print("rfnReady", err)
	end
	Msg("MPTest_OtherClientReady", err)
end

---
--- Joins the client in the specified game.
---
--- This function connects the client to the specified game address and sends a "rfnReady" message to the other client when the connection is established, indicating that this client is ready to join the game.
---
--- @param self MPTestSocket The instance of the MPTestSocket class.
--- @param game_address string The address of the game to join.
--- @return nil
function MPTestSocket:rfnJoinMeInGame(game_address)
	CreateRealTimeThread(function()
		local err = lDbgMultiplayerConnect()
		err = err or lRunErrFunc("NetJoinGame", nil, game_address)
		if err then
			print("rfnJoinMeInGame", err)
		end
		Sleep(100)
		CloseMPErrors()
		self:Send("rfnReady", err)
	end)
end

---
--- Prints the provided arguments to the console.
---
--- This function is a test method that can be used to print any provided arguments to the console. It is likely an implementation detail and not part of the public API.
---
--- @param ... any The arguments to print.
--- @return nil
function MPTestSocket:rfnTest(...)
	print("rfnTest", ...)
end

---
--- Initializes the MPTestListener, which listens for incoming connections on a range of ports.
---
--- This function creates a new MPTestSocket instance and attempts to listen for incoming connections on a range of ports. It will try different ports until it finds one that is available, and then print the port that the listener is initialized on.
---
--- @return boolean true if the listener was successfully initialized, false otherwise
function InitMPTestListener()
	if IsValid(g_MPTestListener) then
		g_MPTestListener:delete()
		g_MPTestListener = false
	end
	
	g_MPTestListener = BaseSocket:new{
		socket_type = "MPTestSocket",
	}
	
	local err
	local port_start = g_MPTestingSocketPort
	local port_end = port_start + 100
	
	for port = port_start, port_end do
		err = g_MPTestListener:Listen("*", port)
		if not err then
			g_MPTestListener.port = port
			break
		elseif err == "address in use" then
			print("InitMPTestListener: Address in use. Trying with another port...")
		else
			print("InitMPTestListener: failed", err)
			g_MPTestListener:delete()
			g_MPTestListener = false
			return false
		end
		Sleep(100)
	end
	print("InitMPTestListener Initialized @ port", g_MPTestListener.port)
	return true
end

---
--- Attempts to connect to a remote MPTestSocket on a range of ports.
---
--- This function creates a new MPTestSocket instance and attempts to connect to a remote MPTestSocket on a range of ports. It will try different ports until it finds one that is available, and then print a message indicating whether the connection was successful or not.
---
--- @return boolean true if the connection was successful, false otherwise
function MPTestConnectSocket()
	if not IsRealTimeThread() then
		CreateRealTimeThread(MPTestConnectToSlave)
		return
	end
	
	if IsValid(g_MPTestSocket) then
		g_MPTestSocket:delete()
		g_MPTestSocket = false
	end
	
	local err
	local port_start = g_MPTestingSocketPort
	local port_end = port_start + 100
	g_MPTestSocket = MPTestSocket:new()
	
	for port = port_start, port_end do
		err = g_MPTestSocket:WaitConnect(2000, "localhost", port)
		if not err then
			break
		elseif err == "no connection" then
			print("MPTestConnectSocket: not found on port", port, "trying next")
		else
			print("MPTestConnectSocket: failed", err)
			g_MPTestSocket:delete()
			g_MPTestSocket = false
			return false
		end
		Sleep(100)
	end
	
	if not err then
		print("MPTestConnectSocket Connected!")
		g_MPTestSocket:Send("rfnHandshake")
		return true
	else
		print("MPTestConnectSocket Failed to connect!")
		return false
	end
end

function OnMsg.Start()
	if true then return end
	local cmd = GetAppCmdLine()
	local is_slave_for_mp_testing = string.match(GetAppCmdLine() or "", "-slave_for_mp_testing")
	if is_slave_for_mp_testing then
		g_MPTestingSlave = true
		--generic second client entry point
		CreateRealTimeThread(function()
			WaitMsg("ChangeMapDone")
			print("im a slave", GetAppCmdLine())
			
			local address_str = string.match(GetAppCmdLine() or "", "-test_mp_game_address=(%S+)")
			local address = tonumber(address_str)
			
			if address then --if we got game address from cmd line join it
				Pause("JoiningClients")
				assert(address)
				local err
				err = lDbgMultiplayerConnect()
				err = err or lRunErrFunc("NetJoinGame", nil, address)
				if err then
					Sleep(5000)
					quit()
				end
				WaitMsg("NetGameLoaded")
				Resume("JoiningClients")
			end
			
			local test_func_name = string.match(GetAppCmdLine() or "", "-test_mp_func_name=(%S+)")
			if test_func_name then
				local func = TestCoopFuncs[test_func_name]
				if not func then
					print("Could not find test func from test_coop_func_name vararg!")
				else
					sprocall(func)
				end
			end
			
			print("client mp thread done!")
			if g_MPTestSocket then
				g_MPTestSocket:Send("rfnReady")
			end
			local dont_quit = string.match(GetAppCmdLine() or "", "-test_mp_dont_auto_quit")
			if not dont_quit then
				print("Quiting..")
				Sleep(5000)
				quit()
			end
		end)
	end
	if string.match(GetAppCmdLine() or "", "-mp_test_listen") then
		CreateRealTimeThread(InitMPTestListener)
	end
	if string.match(GetAppCmdLine() or "", "-mp_test_connect") then
		CreateRealTimeThread(function()
			Sleep(100) --give time if launching concurently
			MPTestConnectSocket()
		end)
	end
end

---
--- Navigates to the main menu.
---
--- This function is used to open the pre-game main menu. It is intended to be
--- called from a real-time thread.
---
--- @function GoToMM
--- @return nil
function GoToMM()
	if not IsRealTimeThread() then
		print("Not in rtt!")
		return
	end
	Sleep(100)
	OpenPreGameMainMenu()
	Sleep(100)
end

--test all attacks specific stuff
if FirstLoad then
	TestAllAttacksThreads = {
		KillPopupsThread = false,
		WatchDog = false,
		GameTimeProc = false,
		RealTimeProc = false,
	}
end
local function lKillUIPopups()
	Sleep(10)
	DeleteThread(TestAllAttacksThreads.KillPopupsThread)
	TestAllAttacksThreads.KillPopupsThread = CreateRealTimeThread(function()
		while true do
			local dlg = GetDialog("CoopMercsManagement") or GetDialog("PopupNotification")
			if dlg then
				dlg:Close()
			end
			Sleep(200)
		end
	end)
end

local function lTestDone()
	NetLeaveGame()
	NetDisconnect()
	Sleep(500)
	CloseMPErrors()
	print("HostStartAllAttacksCoopTest done")
end

local function lHostWatchDog()
	if IsValidThread(TestAllAttacksThreads.WatchDog) then
		DeleteThread(TestAllAttacksThreads.WatchDog)
	end
	TestAllAttacksThreads.WatchDog = CreateRealTimeThread(function()
		while TestAllAttacksTestRunning do
			if netDesync then
				GameTestsError("Test desynced!")
				break
			end
			if table.count(netGamePlayers) ~= 2 then
				GameTestsError("Client player left before test was done!")
				break
			end
			Sleep(250)
		end
		while IsChangingMap() do
			WaitMsg("ChangeMapDone")
		end
		
		DeleteThread(TestAllAttacksThreads.KillPopupsThread)
		DeleteThread(TestAllAttacksThreads.RealTimeProc)
		DeleteThread(TestAllAttacksThreads.GameTimeProc)
		
		lTestDone()
	end)
end

---
--- Starts the "All Attacks Coop Test" for the host player.
---
--- This function is responsible for setting up and running the "All Attacks Coop Test" for the host player. It performs the following steps:
---
--- 1. Deletes any existing threads related to the test.
--- 2. Checks if the function is being called from a real-time thread, and if not, creates a new real-time thread to run the function.
--- 3. Calls the `GameTestsNightly_AllAttacks` function, which is responsible for the actual test logic.
--- 4. Inside the `GameTestsNightly_AllAttacks` callback, it calls `HostMpGameAndLaunchAndJoinAnotherClient` to host a multiplayer game and join another client.
--- 5. If the `HostMpGameAndLaunchAndJoinAnotherClient` call is successful, it calls `lKillUIPopups` and `lHostWatchDog` to handle UI popups and monitor the test progress.
--- 6. Finally, it calls `lTestDone` to clean up and end the test.
---
--- @return nil
function HostStartAllAttacksCoopTest()
	--TODO: ping client @ other end to make sure everything is ok there
	for k, v in pairs(TestAllAttacksThreads) do
		DeleteThread(v)
		TestAllAttacksThreads[k] = false
	end
	
	if not IsRealTimeThread() then
		CreateRealTimeThread(HostStartAllAttacksCoopTest)
		return
	end
	local err
	GameTestsNightly_AllAttacks(function()
		err = HostMpGameAndLaunchAndJoinAnotherClient("TestAllAttacksClientSideFunc")
		if err then
			GameTestsError("HostMpGameAndLaunchAndJoinAnotherClient returned and error: " .. err)
			return err
		end
		lKillUIPopups()
		lHostWatchDog()
	end)
	
	lTestDone()
end

---
--- Runs the "All Attacks Coop Test" client-side logic.
---
--- This function is responsible for the client-side logic of the "All Attacks Coop Test". It performs the following steps:
---
--- 1. Kills any existing UI popups.
--- 2. Waits for the `TestAllAttacksThreads.GameTimeProc` flag to be set, indicating the start of the test.
--- 3. Continuously checks for a network desync or if the number of players in the game is not 2, indicating the test has ended.
--- 4. If a desync or incorrect number of players is detected, it prints the relevant information and returns, allowing the caller to quit the application.
---
--- @return nil
TestCoopFuncs.TestAllAttacksClientSideFunc = function()
	lKillUIPopups()
	while not TestAllAttacksThreads.GameTimeProc do
		--wait for test start sync msg
		Sleep(10)
	end
	while TestAllAttacksThreads.GameTimeProc do
		if netDesync or table.count(netGamePlayers) ~= 2 then
			--its over
			print("netDesync", netDesync)
			print("table.count(netGamePlayers)", table.count(netGamePlayers))
			return --caller will quit app, so we don't care if we leaked threads
		end
		Sleep(250)
	end
end

end --Platform.developer


function OnMsg.NetGameLeft(reason)
	--saw this leak once, not sure how
	if PauseReasons.net then
		Resume("net")
	end
end


---
--- Resets the voxel stealth parameters cache.
---
--- This function is responsible for resetting the cache of voxel stealth parameters. It is likely used to ensure that the stealth calculations are performed using up-to-date information.
---
--- @return nil
function NetSyncEvents.tst()
	ResetVoxelStealthParamsCache()
end

--overwrite func to add check for the AnalyticsEnabled option
---
--- Sends a network gossip message if the "AnalyticsEnabled" option is enabled.
---
--- This function is responsible for sending a network gossip message if the "AnalyticsEnabled" option is enabled and the `netAllowGossip` flag is true. The gossip message is sent using the `NetSend` function with the "rfnGossip" message type.
---
--- @param gossip table The gossip message to be sent.
--- @param ... any Additional arguments to be passed to the gossip message.
--- @return boolean True if the gossip message was sent, false otherwise.
function NetGossip(gossip, ...)
	if gossip and netAllowGossip and GetAccountStorageOptionValue("AnalyticsEnabled") == "On" then
		--LogGossip(TupleToLuaCodePStr(gossip, ...))
		return NetSend("rfnGossip", gossip, ...)
	end
end

function OnMsg.GameOptionsChanged()
	CreateRealTimeThread(function()
		if GetAccountStorageOptionValue("AnalyticsEnabled") == "On" then
			TryConnectToServer()
		else
			NetDisconnect("netClient")
		end
	end)
end

--overwrite func to add check for the AnalyticsEnabled option or MP game for reconnecting to server
---
--- Attempts to connect the client to the server.
---
--- This function is responsible for connecting the client to the server. It first checks if the command line is present, and if so, returns. Otherwise, it creates a real-time thread to handle the connection process.
---
--- The function first waits for the initial DLC load to complete, then waits for the AccountStorage to be available. If the platform is Xbox, it also waits for the user to be signed in.
---
--- The function then enters a loop that continues as long as the `config.SwarmConnect` flag is set. Inside the loop, it checks if the client is not connected and the "AnalyticsEnabled" option is set to "On". If so, it attempts to log in using the stored credentials or auto-login. If the login is successful, it connects to the server using the `NetConnect` function.
---
--- If the login or connection fails, the function doubles the wait time before retrying. If the error is "maintenance" or "not ready", the function waits exactly 5 minutes before retrying.
---
--- If the connection is successful, the function resets the wait time to 60 seconds. If the `config.SwarmConnect` flag is set to "ping", the function disconnects from the server and returns.
---
--- @return nil
function TryConnectToServer()
	if Platform.cmdline then return end
	g_TryConnectToServerThread = IsValidThread(g_TryConnectToServerThread) or CreateRealTimeThread(function()
		WaitInitialDlcLoad()
		while not AccountStorage do
			WaitMsg("AccountStorageChanged")
		end
		if Platform.xbox then
			WaitMsg("XboxUserSignedIn")
		end
		local wait = 60*1000
		while config.SwarmConnect do
			if not NetIsConnected() and GetAccountStorageOptionValue("AnalyticsEnabled") == "On" then
				local err, auth_provider, auth_provider_data, display_name = NetGetProviderLogin(false)
				if err then
					err, auth_provider, auth_provider_data, display_name = NetGetAutoLogin()
				end
				err = err or NetConnect(config.SwarmHost, config.SwarmPort, 
					auth_provider, auth_provider_data, display_name, config.NetCheckUpdates, "netClient")
				if err == "failed" or err == "version" then -- if we cannot login with these credentials stop trying
					return
				end
				if not err and config.SwarmConnect == "ping" or err == "bye" then
					NetDisconnect("netClient")
					return
				end
				wait = wait * 2 -- double the wait time on fail
				if err == "maintenance" or err == "not ready" then
					wait = 5*60*1000 -- wait exactly 5 mins if servers are not ready
				end
			end
			if NetIsConnected() then
				wait = 60*1000 -- on success reset the wait time
				if config.SwarmConnect == "ping" then
					NetDisconnect("netClient")
					return
				end
				WaitMsg("NetDisconnect")
			end
			Sleep(wait)
		end
	end)
end

---
--- Handles the synchronization of the NewMapLoaded event across the network.
---
--- @param map string The name of the newly loaded map.
--- @param net_hash number The network hash of the map.
--- @param map_random number The random seed used for the map.
--- @param seed_text string The seed text used for the map.
---
function NetSyncEvents.NewMapLoaded(map, net_hash, map_random, seed_text)
	--for logging purposes
	--feel free to put sync code here
end

function OnMsg.PostNewMapLoaded()
	FireNetSyncEventOnHost("NewMapLoaded", CurrentMap, mapdata.NetHash, MapLoadRandom, Game and Game.seed_text)
end

function OnMsg.PreLoadSessionData()
	local dlg = GetDialog("Intro")
	if dlg and (dlg.window_state == "open" or dlg.window_state == "closing") then
		dlg:Close()
	end
	
	local dlg = GetDialog("Credits")
	if dlg and (dlg.window_state == "open" or dlg.window_state == "closing") then
		dlg:Close()
	end
end

function OnMsg.NetGameJoined()
	local dlg = GetDialog("Credits")
	if dlg and (dlg.window_state == "open" or dlg.window_state == "closing") then
		dlg:Close()
	end
end
------------------------------wind
--override from common wind.lua
---
--- Updates the wind affected objects in the game world.
---
--- @param sync boolean If true, the wind affected objects are updated synchronously across the network.
---
function UpdateWindAffected(sync)
	if IsInMultiplayerGame() and not sync then
		FireNetSyncEventOnHost("UpdateWindAffected")
		return
	end

	MapForEach("map", "WindAffected", function(obj)
		obj:UpdateWind(sync)
	end)
end

---
--- Synchronizes the update of wind affected objects across the network.
---
--- This function is called by the network system to update the wind affected objects
--- in the game world in a synchronized manner across all clients.
---
function NetSyncEvents.UpdateWindAffected()
	UpdateWindAffected("sync")
end

if FirstLoad then
	netBufferedEventsReasons = {}
	Original_NetStopBufferEvents = NetStopBufferEvents
end


---
--- Stops buffering network events.
---
--- If there are no more reasons to buffer events, it calls the original `NetStopBufferEvents` function.
---
--- @param reason string|boolean The reason for stopping the buffering of events. If `false`, it removes all reasons.
---
function NetStopBufferEvents(reason)
	reason = reason or false
	netBufferedEventsReasons[reason] = nil
	if not next(netBufferedEventsReasons) then
		Original_NetStopBufferEvents()
	end
end

---
--- Starts buffering network events.
---
--- Adds the given reason to the list of reasons for buffering events. If there are any reasons to buffer events,
--- network events will be buffered until `NetStopBufferEvents` is called with all the reasons removed.
---
--- @param reason string|boolean The reason for starting the buffering of events. If `false`, it clears all reasons.
---
function NetStartBufferEvents(reason)
	reason = reason or false
	netBufferedEventsReasons[reason] = true
	netBufferedEvents = netBufferedEvents or {}
end