-------------------------------------------------[ NetCloudSocket ]------------------------------------------------------

DefineClass.NetCloudSocket = {
	__parents = { "DataSocket" },
	callback_id = false,
	friends = false,
	friend_names = false,
	chat_room_guests = false,
	chat_room = false,
	
	timeout = Platform.ps4 and 6 * 60 * 60 * 1000 or nil,
	msg_size_max = 16*1024*1024,
}

--- Handles the disconnection event for the NetCloudSocket.
---
--- When the socket is disconnected, this function is called. It first calls the parent class's `OnDisconnect` function, then checks if the current socket is the `netSwarmSocket`. If so, it calls `NetForceDisconnect` with the provided `reason` or `true` if no reason is given.
---
--- @param reason string|boolean The reason for the disconnection, or `true` if no reason is provided.
function NetCloudSocket:OnDisconnect(reason)
	DataSocket.OnDisconnect(self, reason)
	if netSwarmSocket == self then
		NetForceDisconnect(reason or true)
	end
end

--- Handles the event when the account logs in from another computer.
---
--- When the `netSwarmSocket` is the current socket, this function is called to print a message indicating that the account has logged in from another computer.
---
--- @param self NetCloudSocket The NetCloudSocket instance.
function NetCloudSocket:rfnNewLogin()
	if netSwarmSocket == self then
		print("Net: account logged in from another computer")
	end
end

--- Handles the event when the player leaves the game.
---
--- This function is called when the player leaves the game. It creates a new real-time thread and calls the `NetLeaveGame` function with the provided `reason`.
---
--- @param self NetCloudSocket The NetCloudSocket instance.
--- @param reason string The reason for leaving the game.
function NetCloudSocket:rfnLeaveGame(reason)
	CreateRealTimeThread(NetLeaveGame, reason)
end

-- chat functionality

-- to send a chat message use NetSend("rfnChatMsg", message)
---
--- Handles the processing of a chat message received from the network.
---
--- This function is called when a chat message is received from the network. It first checks if the sender is not blocked, then creates a real-time thread to handle the message processing.
---
--- In the real-time thread, it first checks if the sender is on the Xbox platform. If so, it verifies that the user has the necessary permissions to view the target's presence and communicate using text. If the permissions are not granted, the message is not processed.
---
--- The message and the sender's name are then filtered based on the platform. On the Xbox platform, the message is filtered using the `FilterString` function, and the sender's name is kept as the first word. On the Nintendo Switch platform, the message is masked for profanity using the `AsyncSwitchMaskProfanityWordsInText` function.
---
--- Finally, the `Msg` function is called with the "Chat" message type, passing the sender's name, account ID, and the filtered message.
---
--- @param player_name string The name of the player who sent the message.
--- @param account_id string The account ID of the player who sent the message.
--- @param platform string The platform of the player who sent the message.
--- @param message string The content of the chat message.
---
function NetCloudSocket:rfnChatMsg(player_name, account_id, platform, message)
	if not self.friends or self.friends[account_id] ~= "blocked" then
		CreateRealTimeThread(function(player_name, account_id, message)
			if Platform.xbox then
				local idx = table.find(netSwarmSocket["chat_room_guests"], 1, account_id)
				if not idx then return end
				local allowed = CheckPermissionWithUser("ViewTargetPresence")
				if not allowed then return end
				allowed = CheckPermissionWithUser("CommunicateUsingText")
				if not allowed then return end
			end
			if Platform.xbox then
				message = FilterString(message, "full")
				player_name = FilterString(player_name, "keep first")
			elseif Platform.switch then
				message = AsyncSwitchMaskProfanityWordsInText(message)
			end
			Msg("Chat", player_name, account_id, message)
		end, player_name, account_id, message)
	end
end

---
--- Sends a system chat message to the game's chat system.
---
--- @param message string The message to be sent as a system chat message.
--- @param ... any Additional parameters to be passed to the `Msg` function.
---
function NetCloudSocket:rfnChatSysMsg(message, ...)
	Msg("SysChat", message, ...)
end

-- chat participant info is { account_id, name, platform, GetLanguage(), platform_id (xbox only) }
-- see NetJoinChatRoom for the fields after the name
---
--- Handles the addition of a new guest to the chat room.
---
--- This function is called when a new guest joins the chat room. It adds the guest's information to the `chat_room_guests` table and sends a system chat message to notify other participants of the new guest's arrival. It also sends a `ChatRoomGuestsChange` message to notify listeners of the change in the guest list.
---
--- @param id string The unique identifier of the new guest.
--- @param info table The information about the new guest, including their name, account ID, platform, and language.
---
function NetCloudSocket:rfnGuestJoin(id, info)
	if self.chat_room_guests then
		self.chat_room_guests[id] = info
		Msg("SysChat", "join", unpack_params(info))
		Msg("ChatRoomGuestsChange", self.chat_room_guests)
	end
end

---
--- Handles the removal of a guest from the chat room.
---
--- This function is called when a guest leaves the chat room. It removes the guest's information from the `chat_room_guests` table and sends a system chat message to notify other participants of the guest's departure. It also sends a `ChatRoomGuestsChange` message to notify listeners of the change in the guest list.
---
--- @param id string The unique identifier of the guest who left.
---
function NetCloudSocket:rfnGuestLeave(id)
	if self.chat_room_guests then
		local info = self.chat_room_guests[id]
		self.chat_room_guests[id] = false
		Msg("SysChat", "leave", unpack_params(info))
		Msg("ChatRoomGuestsChange", self.chat_room_guests)
	end
end

-- to send a whisper use NetCall("rfnWhisper", receiver_alias, receiver_alias_type, message)
---
--- Handles the receipt of a whisper message from another player.
---
--- This function is called when a whisper message is received from another player. It checks if the connection is official and if the sender is not blocked, then processes the message. If the platform is Switch, it masks any profanity words in the message before displaying it.
---
--- @param sender_name string The name of the player who sent the whisper message.
--- @param sender_account_id string The account ID of the player who sent the whisper message.
--- @param message string The content of the whisper message.
---
function NetCloudSocket:rfnWhisper(sender_name, sender_account_id, message)
	if NetIsOfficialConnection() and (not self.friends or self.friends[sender_account_id or false] ~= "blocked") then
		if Platform.switch then
			message = AsyncSwitchMaskProfanityWordsInText(message)
		end
		Msg("Whisper", sender_name, sender_account_id, message)
	end
end

---
--- Sends a chat message to the current chat room.
---
--- This function checks if the `netSwarmSocket` is connected. If it is not connected, it returns the string "disconnected". If the message length exceeds 200 characters, it returns the string "params". Otherwise, it calls the `rfnChatMsg` function on the `netSwarmSocket` and returns the result.
---
--- @param message string The chat message to be sent.
--- @return string The result of the chat message operation.
---
function NetChatMsg(message)
	if not netSwarmSocket then
		return "disconnected"
	end
	if utf8.len(message) > 200 then return "params" end
	return netSwarmSocket:Call("rfnChatMsg", message)
end

-- if no index is provided it is automatically selected
---
--- Joins the specified chat room.
---
--- This function is used to join a chat room. It first determines the platform the player is on (Xbox, desktop, PS4, or Switch) and retrieves the player's unique identifier (XUID for Xbox, or nil for other platforms). It then calls the `rfnJoinChatRoom` function on the `netSwarmSocket` to join the specified chat room. If the join is successful, it updates the `chat_room_guests` and `chat_room` properties of the `netSwarmSocket` with the information returned from the server. It then sends a `JoinChatRoom` message to notify listeners of the successful join.
---
--- @param room string The name of the chat room to join.
--- @param index number|nil The index of the chat room to join, if provided.
--- @return string|nil The error message if the join failed, or nil if the join was successful.
---
function NetJoinChatRoom(room, index)
	local platform
	local id = false
	if Platform.xbox then
		platform = "xbox"
		id = Xbox.GetXuid()
	elseif Platform.desktop then
		platform = "desktop"
	elseif Platform.ps4 then
		platform = "ps4"
	elseif Platform.switch then
		platform = "switch"
	end
	local err, room_info, guests = NetCall("rfnJoinChatRoom", room, type(index) == "number" and index or nil, platform, GetLanguage(), id)
	if err == "same" then return end
	if err then return err end
	if netSwarmSocket then
		netSwarmSocket.chat_room_guests = guests or {}
		netSwarmSocket.chat_room = room_info
		-- string.format("%s #%d", room_info.name, room_info.index) or false
	end
	Msg("JoinChatRoom", err, netSwarmSocket and netSwarmSocket.chat_room, guests)
end

---
--- Leaves the current chat room.
---
--- This function is used to leave the current chat room. It calls the `rfnLeaveChatRoom` function on the `netSwarmSocket` to leave the current chat room. If the leave is successful, it updates the `chat_room_guests` and `chat_room` properties of the `netSwarmSocket` to indicate that the user has left the chat room. It then sends a `LeaveChatRoom` message to notify listeners of the successful leave.
---
--- @return string|nil The error message if the leave failed, or nil if the leave was successful.
---
function NetLeaveChatRoom()
	local err = NetCall("rfnLeaveChatRoom")
	if netSwarmSocket then
		netSwarmSocket.chat_room_guests = {}
		netSwarmSocket.chat_room = false
	end
	Msg("LeaveChatRoom", err)
	return err
end

---
--- Enumerates the available chat rooms.
---
--- This function is used to retrieve a list of the available chat rooms. It calls the `rfnEnumChatRooms` function on the `netSwarmSocket` to get the list of chat rooms. The `room` parameter can be used to filter the list of chat rooms by name.
---
--- @param room string|nil The name of the chat room to filter the list by, or nil to get all chat rooms.
--- @return table|nil, string|nil The list of chat rooms, or nil if an error occurred. The second return value is the error message if an error occurred.
---
function NetEnumChatRooms(room)
	return NetCall("rfnEnumChatRooms", room)
end

if FirstLoad then
	PSNAllowOfficialConnection = false -- enabled online access for consoles
	XboxAllowOfficialConnection = false
	NintendoAllowOfficialConnection = false
end

---
--- Makes the user offline.
---
--- This function is used to make the user offline. It performs the following actions:
--- - Calls `NetLeaveChatRoom()` to leave the current chat room.
--- - Calls `NetLeaveGame()` to leave the current game.
--- - Calls `NetDisconnect()` to disconnect from the network.
--- - Sets `PSNAllowOfficialConnection`, `XboxAllowOfficialConnection`, and `NintendoAllowOfficialConnection` to `false` to prevent official connections.
---
--- This function is typically called when the user wants to go offline, or when the network connection is lost.
---
--- @return nil
---
function NetMakeUserOffline() -- may stay connected but this is not a connection initiated by him
	CreateRealTimeThread(NetLeaveChatRoom)
	NetLeaveGame()
	NetDisconnect()
	PSNAllowOfficialConnection = false
	XboxAllowOfficialConnection = false
	NintendoAllowOfficialConnection = false
end

function OnMsg.NetDisconnect()
	PSNAllowOfficialConnection = false
	XboxAllowOfficialConnection = false
	NintendoAllowOfficialConnection = false
end

---
--- Checks if the current network connection is an official connection.
---
--- This function checks if the current network connection is an official connection, meaning that the user is connected and can join games and chat rooms. It performs the following checks:
---
--- - Checks if the user is connected to the network using `NetIsConnected()`.
--- - Checks if the user is on a PlayStation platform and if `PSNAllowOfficialConnection` is `false`.
--- - Checks if the user is on an Xbox platform and if `XboxAllowOfficialConnection` is `false`.
--- - Checks if the user is on a Nintendo Switch platform and if `NintendoAllowOfficialConnection` is `false`.
---
--- If any of these checks fail, the function returns `nil`, indicating that the current connection is not an official connection. Otherwise, it returns `true`, indicating that the current connection is an official connection.
---
--- @return boolean|nil True if the current connection is an official connection, `nil` otherwise.
---
function NetIsOfficialConnection() -- connected AND can join games/rooms
	if not NetIsConnected() or
		Platform.playstation and not PSNAllowOfficialConnection or
		Platform.xbox and not XboxAllowOfficialConnection or
		Platform.switch and not NintendoAllowOfficialConnection
	then
		return
	end
	return not netRestrictedAccount
end

-- not XUID means the player is not on Xbox Live or the caller is not on Xbox Live
-- err == "not found" means the player is offline
-- err == "disconnected" or "timeout" mean that the connection with the swarm was lost or timed out
---
--- Gets the XUID (Xbox User ID) for the specified account ID.
---
--- @param account_id string The account ID to get the XUID for.
--- @return string|nil The XUID for the specified account ID, or `nil` if the XUID could not be retrieved.
---
function NetGetXUID(account_id)
	return NetCall("rfnGetXUID", account_id)
end

---
--- Gets the PlayStation Network (PSN) account ID for the specified account ID.
---
--- @param account_id string The account ID to get the PSN account ID for.
--- @return string|nil The PSN account ID for the specified account ID, or `nil` if the PSN account ID could not be retrieved.
---
function NetGetPSNID(account_id)
	return NetCall("rfnGetPSNAccountId", account_id)
end

-- Callback functionality (used for callbacks from web calls/ops)

---
--- Gets the callback ID for this NetCloudSocket instance.
---
--- If the callback ID has not been set yet, this function will call the `rfnGetCallbackId` remote function to retrieve a new callback ID and store it in the `callback_id` field of the NetCloudSocket instance.
---
--- @return string|nil The callback ID for this NetCloudSocket instance, or `nil` if an error occurred while retrieving the callback ID.
---
function NetCloudSocket:GetCallbackId()
	if not self.callback_id then
		local err, callback_id = self:Call("rfnGetCallbackId")
		if err then return err end
		self.callback_id = { callback_id }
	end
	return false, self.callback_id[1] 
end

---
--- Dispatches a callback message to the registered callback ID.
---
--- This function is called when a remote function call has completed and a response needs to be sent back to the caller.
---
--- @param ... any The arguments to pass to the callback function.
---
function NetCloudSocket:rfnCallback(...)
	if self.callback_id then
		Msg(self.callback_id, ...)
	end
end

-- friends

---
--- Initializes the friends list for the NetCloudSocket instance.
---
--- @param friends_list table A table mapping account IDs to player names for the user's friends.
--- @param invitations table A table mapping account IDs to player names for friend invitations received by the user.
--- @param invitations_sent table A table mapping account IDs to player names for friend invitations sent by the user.
--- @param blocked table A table mapping account IDs to player names for users blocked by the user.
---
--- This function is called when the initial friends list is received from the server. It populates the `friends` and `friend_names` tables with the appropriate status for each friend or blocked user.
---
--- The `friends` table maps account IDs to friend status strings, which can be "offline", "online", "playing", "invited", "invite_sent", or "blocked".
---
--- The `friend_names` table maps account IDs to player names.
---
--- After initializing the friends list, this function sends a "FriendsChange" message with the initial friends data.
---
function NetCloudSocket:rfnFriendList(friends_list, invitations, invitations_sent, blocked)
	local friends, friend_names = {}, {}
	self.friends = friends
	self.friend_names = friend_names
	for k, v in pairs(friends_list) do
		friends[k] = "offline"
		friend_names[k] = v
	end
	for k, v in pairs(invitations) do
		friends[k] = "invited"
		friend_names[k] = v
	end
	for k, v in pairs(invitations_sent) do
		friends[k] = "invite_sent"
		friend_names[k] = v
	end
	for k, v in pairs(blocked) do
		friends[k] = "blocked"
		friend_names[k] = v
	end
	Msg("FriendsChange", friends, friend_names, "init")
end

---
--- Updates the status of a friend in the NetCloudSocket instance.
---
--- @param player_name string The name of the player.
--- @param account_id any The account ID of the player.
--- @param status string The new status of the player. Can be "offline", "online", "playing", or any other custom status.
---
--- This function updates the `friends` and `friend_names` tables with the new status and player name for the given account ID. It then sends a "FriendsChange" message with the updated friends data.
---
function NetCloudSocket:rfnFriendStatus(player_name, account_id, status)
	self.friends = self.friends or {}
	self.friend_names = self.friend_names or {}
	if type(status) == "number" then
		status = status == 0 and "offline" or status == 1 and "online" or status == 2 and "playing" or status
	end
	self.friends[account_id] = status
	self.friend_names[account_id] = player_name
	Msg("FriendsChange", self.friends, self.friend_names, "status")
end

---
--- Adds a new friend to the NetCloudSocket instance.
---
--- @param account_id any The account ID of the new friend.
--- @param player_name string The name of the new friend.
---
--- This function adds the new friend to the `friends` and `friend_names` tables, and sends a "FriendsChange" message with the updated friends data.
function NetCloudSocket:rfnAddFriend(account_id, player_name)
	self.friends[account_id] = "offline"
	self.friend_names[account_id] = player_name
	Msg("FriendsChange", self.friends, self.friend_names, "add")
end

---
--- Removes a friend from the NetCloudSocket instance.
---
--- @param account_id any The account ID of the friend to remove.
---
--- This function removes the specified friend from the `friends` and `friend_names` tables, and sends a "FriendsChange" message with the updated friends data.
function NetCloudSocket:rfnUnfriend(account_id)
	self.friends[account_id] = nil
	self.friend_names[account_id] = nil
	Msg("FriendsChange", self.friends, self.friend_names, "remove")
end

---
--- Blocks a friend in the NetCloudSocket instance.
---
--- @param player_name string The name of the player to block.
--- @param account_id any The account ID of the player to block.
---
--- This function adds the specified player to the `friends` and `friend_names` tables with a "blocked" status, and sends a "FriendsChange" message with the updated friends data.
function NetCloudSocket:rfnBlock(player_name, account_id)
	self.friends = self.friends or {}
	self.friend_names = self.friend_names or {}
	self.friends[account_id] = "blocked"
	self.friend_names[account_id] = player_name
	Msg("FriendsChange", self.friends, self.friend_names, "block")
end

---
--- Removes a block on a friend in the NetCloudSocket instance.
---
--- @param account_id any The account ID of the friend to unblock.
---
--- This function removes the specified friend from the `friends` and `friend_names` tables, and sends a "FriendsChange" message with the updated friends data.
function NetCloudSocket:rfnUnblock(account_id)
	self.friends[account_id] = nil
	self.friend_names[account_id] = nil
	Msg("FriendsChange", self.friends, self.friend_names, "unblock")
end

---
--- Sends a friend request to the specified player.
---
--- @param account_id any The account ID of the player to send the friend request to.
--- @param player_name string The name of the player to send the friend request to.
---
--- This function adds the specified player to the `friends` and `friend_names` tables with an "invited" status, and sends a "FriendsChange" message with the updated friends data. It also sends a "FriendRequest" message with the account ID and player name of the requested friend.
function NetCloudSocket:rfnFriendRequest(account_id, player_name)
	self.friends = self.friends or {}
	self.friend_names = self.friend_names or {}
	self.friends[account_id] = "invited"
	self.friend_names[account_id] = player_name
	Msg("FriendsChange", self.friends, self.friend_names, "request")
	Msg("FriendRequest", account_id, player_name)
end

---
--- Sends a friend invitation to the specified player.
---
--- @param account_id any The account ID of the player to send the friend invitation to.
--- @param player_name string The name of the player to send the friend invitation to.
---
--- This function adds the specified player to the `friends` and `friend_names` tables with an "invite_sent" status, and sends a "FriendsChange" message with the updated friends data.
function NetCloudSocket:rfnInviteFriend(account_id, player_name)
	self.friends = self.friends or {}
	self.friend_names = self.friend_names or {}
	self.friends[account_id] = "invite_sent"
	self.friend_names[account_id] = player_name
	Msg("FriendsChange", self.friends, self.friend_names, "invite")
end

---
--- Pings the NetCloudSocket instance.
---
--- This function is used to send a ping message to the NetCloudSocket instance, which can be used to keep the connection alive or check the connection status.
function NetCloudSocket:rfnPing()
end

if FirstLoad then
	g_UsedTickets = {}
end

---
--- Updates the list of used tickets.
---
--- @param tickets table The list of used tickets.
---
function NetCloudSocket:rfnUsedTickets(tickets)
	g_UsedTickets = tickets or {}
end

function OnMsg.NetDisconnect()
	g_UsedTickets = {}
end

---
--- Sends a friend request to the specified player.
---
--- @param player_name string The name of the player to send the friend request to.
--- @param alias any The alias of the player to send the friend request to.
--- @param alias_type string The type of the alias of the player to send the friend request to.
---
--- This function sends a friend request to the specified player by calling the "rfnFriendRequest" function on the `netSwarmSocket` instance. If the `netSwarmSocket` instance is not available, it returns "disconnected".
function NetFriendRequest(player_name, alias, alias_type)
	if not netSwarmSocket then
		return "disconnected"
	end
	return netSwarmSocket:Call("rfnFriendRequest", player_name, alias, alias_type)
end

---
--- Removes the specified player from the friend list.
---
--- @param alias string The alias of the player to remove from the friend list.
--- @param alias_type string The type of the alias of the player to remove from the friend list.
---
--- This function removes the specified player from the `friends` and `friend_names` tables, and sends a "FriendsChange" message with the updated friends data.
function NetUnfriend(alias, alias_type)
	if not netSwarmSocket then
		return "disconnected"
	end
	return netSwarmSocket:Call("rfnUnfriend", alias, alias_type)
end

---
--- Blocks the specified player.
---
--- @param player_name string The name of the player to block.
--- @param alias any The alias of the player to block.
--- @param alias_type string The type of the alias of the player to block.
---
--- This function blocks the specified player by calling the "rfnBlock" function on the `netSwarmSocket` instance. If the `netSwarmSocket` instance is not available, it returns "disconnected".
function NetBlock(player_name, alias, alias_type)
	if not netSwarmSocket then
		return "disconnected"
	end
	return netSwarmSocket:Call("rfnBlock", player_name, alias, alias_type)
end

---
--- Removes the specified player from the blocked list.
---
--- @param alias string The alias of the player to unblock.
--- @param alias_type string The type of the alias of the player to unblock.
--- @param account_id string The account ID of the player to unblock.
---
--- This function removes the specified player from the blocked list by calling the "rfnUnblock" function on the `netSwarmSocket` instance. If the `netSwarmSocket` instance is not available, it returns "disconnected".
function NetUnblock(alias, alias_type, account_id)
	if not netSwarmSocket then
		return "disconnected"
	end
	return netSwarmSocket:Call("rfnUnblock", alias, alias_type, account_id) 
end

---
--- Reports the specified player to the server.
---
--- @param player_name string The name of the player to report.
--- @param alias any The alias of the player to report.
--- @param alias_type string The type of the alias of the player to report.
--- @param reason string The reason for reporting the player.
---
--- This function reports the specified player to the server by calling the "rfnReport" function on the `netSwarmSocket` instance. If the `netSwarmSocket` instance is not available, it returns "disconnected".
---
--- @return string The result of the report operation.
function NetReportPlayer(player_name, alias, alias_type, reason)
	if not netSwarmSocket then
		return "disconnected"
	end
	return netSwarmSocket:Call("rfnReport", player_name, alias, alias_type, reason)
end

---
--- Pings the specified player.
---
--- @param account_id string The account ID of the player to ping.
---
--- This function pings the specified player by calling the "rfnPingPlayer" function on the `netSwarmSocket` instance. If the `netSwarmSocket` instance is not available, it returns "disconnected".
---
--- @return string The result of the ping operation.
function NetPingPlayer(account_id)
	if not netSwarmSocket then
		return "disconnected"
	end
	return netSwarmSocket:Call("rfnPingPlayer", account_id)
end

-- game invites

-- to invite someone use NetCall/NetSend("rfnInvite", alias, alias_type, ...)
-- you need to be in a game to send invites - the other player automatically receives your game's address
-- (alias, alias_type) can be (account_id, "account") or any other (alias, alias_type) pair (see AccountAliasTypes)
-- to join the game from an invitation use NetJoinGame(nil, game_address)
---
--- Sends a game invitation to the specified player.
---
--- @param player_name string The name of the player to invite.
--- @param player_account_id string The account ID of the player to invite.
--- @param game_address string The address of the game to invite the player to.
--- @param ... any Additional parameters to pass to the invitation.
---
--- This function sends a game invitation to the specified player by calling the "GameInvite" message. If the player is not blocked, the invitation is sent. If the local player count is less than 2, the function returns `nil`, otherwise it returns `"in local coop"`.
---
--- @return string|nil The result of the invitation operation, or `nil` if the local player count is less than 2.
function NetCloudSocket:rfnInvite(player_name, player_account_id, game_address, ...)
	if not NetIsOfficialConnection() then return end
	if not self.friends or not player_account_id or self.friends[player_account_id] ~= "blocked" then
		Msg("GameInvite", player_name, player_account_id, game_address, ...)
	end
	return LocalPlayersCount >= 2 and "in local coop" or nil
end

-- to send a data message to another player use 
--    NetCall/NetSend("rfnPlayerMessage", account_id, data_type, ...)
--    if the player is offline the response will be "unknown address"
-- such message will be received on the other side as Msg("NetPlayerMessage", response, ...)
---
--- Sends a player message to the specified player.
---
--- @param player_name string The name of the player to send the message to.
--- @param player_account_id string The account ID of the player to send the message to.
--- @param data_type string The type of data to send in the message.
--- @param ... any Additional parameters to include in the message.
---
--- This function sends a player message to the specified player by calling the "NetPlayerMessage" message. If the player is not blocked, the message is sent. If the connection is not an official connection, the function returns without doing anything.
---
--- @return any The response from the message, if any.
function NetCloudSocket:rfnPlayerMessage(player_name, player_account_id, data_type, ...)
	if not NetIsOfficialConnection() then return end
	if not self.friends or self.friends[player_account_id or false] ~= "blocked" then
		local response = {}
		Msg("NetPlayerMessage", response, player_name, player_account_id, data_type, ...)
		return unpack_params(response)
	end
end

---
--- Saves a game for the specified player.
---
--- @param player_account_id string The account ID of the player whose game should be saved.
--- @param savegame table The savegame data to be saved.
---
--- This function saves the specified savegame data for the player with the given account ID. It checks if the local player is currently in a game, and if so, it finds the player ID for the given account ID and sends a "NetSavegame" message with the player ID, account ID, and savegame data.
function NetCloudSocket:rfnSavegame(player_account_id, savegame)
	if netInGame then
		local player_id = table.find(netGamePlayers, "account_id", player_account_id)
		assert(player_id)
		if player_id then
			Msg("NetSavegame", player_id, player_account_id, savegame)
		end
	end
end


-- automatch

if FirstLoad then
	netAutomatch = false
end

---
--- Starts an automatch process for the specified match type and information.
---
--- @param match_type string The type of match to start.
--- @param info table Any additional information required for the match type.
---
--- This function cancels any existing automatch, sets the current automatch type, and calls the "rfnStartMatch" function to initiate the automatch process. If an error occurs, the automatch is canceled and a "NetMatchFound" message is sent.
---
--- @return string|nil The error message, if any.
--- @return number|nil The estimated time to find a match.
--- @return table|nil The list of players in the match.
--- @return number|nil The quality of the match.
function NetStartAutomatch(match_type, info)
	NetCancelAutomatch()
	netAutomatch = match_type
	local err, time, players, quality = NetCall("rfnStartMatch", match_type, info)
	if err then
		netAutomatch = false
		Msg("NetMatchFound")
	end
	return err, time, players, quality
end

---
--- Cancels any existing automatch process.
---
--- This function cancels any ongoing automatch process by setting the `netAutomatch` flag to `false`, sending a "NetMatchFound" message, and calling the "rfnCancelMatch" function to notify the server of the cancellation.
---
--- @return nil
function NetCancelAutomatch()
	if netAutomatch then
		netAutomatch = false
		Msg("NetMatchFound")
		NetSend("rfnCancelMatch")
	end
end

---
--- Handles the event when a match is found during an automatch process.
---
--- @param match_type string The type of match that was found.
--- @param game_id number The ID of the game session for the found match.
---
--- This function is called when a match is found during an automatch process. It checks if the current automatch type matches the found match type, and if so, it sends a "NetMatchFound" message with the match type and game ID, and sets the `netAutomatch` flag to `false` to indicate that the automatch process has completed.
---
function NetCloudSocket:rfnMatchFound(match_type, game_id)
	if netAutomatch == match_type then
		Msg("NetMatchFound", match_type, game_id)
		netAutomatch = false
	end
end

OnMsg.NetDisconnect = NetCancelAutomatch
