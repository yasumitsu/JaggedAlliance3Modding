-- err, alias_type, { [<friend_id>] = <friend_name> }, { [blocked_id] = <blocked_name> }
---
--- Returns the list of the player's friends and blocked users.
---
--- @return string|nil error_message
--- @return string platform_name
--- @return table friends_list
--- @return table blocked_list
function PlatformGetFriends()
    return nil, "name", {}, {}
end

if Platform.steam then

    ---
    --- Handles the event when a new player joins the current network game.
    --- For each player in the game, except the local player, this function sets the "played with" status for their Steam ID.
    ---
    --- @param player table The player object that joined the game.
    --- @param info table Information about the player that joined the game.
    ---
    function OnMsg.NetPlayerInfo(player, info)
        if player.id ~= netUniqueId and info.steam_id64 then
            SteamSetPlayedWith(info.steam_id64)
        end
    end

    ---
    --- Handles the event when a new player joins the current network game.
    --- For each player in the game, except the local player, this function sets the "played with" status for their Steam ID.
    ---
    --- @param game_id string The ID of the game that was joined.
    --- @param player_id string The ID of the player that joined the game.
    ---
    function OnMsg.NetGameJoined(game_id, player_id)
        for k, v in sorted_pairs(netGamePlayers) do
            if k ~= netUniqueId and v.steam_id64 then
                SteamSetPlayedWith(v.steam_id64)
            end
        end
    end

    ---
    --- Returns the list of the player's friends and blocked users.
    ---
    --- @return string|nil error_message
    --- @return string platform_name
    --- @return table friends_list
    --- @return table blocked_list
    function PlatformGetFriends()
        local friends = SteamGetFriends()
        if not friends then
            return "getting friends error"
        end
        local blocked_users = SteamGetBlockedUsers()
        if not friends then
            return "getting blocked users error"
        end
        return nil, "steam", friends, blocked_users
    end

end --Platform.steam

if Platform.playstation then

if FirstLoad then
	g_LastPlayStationGetFriends = 0
	g_LastFriendList = {}
	g_LastBlockList = {}
end

    ---
    --- Retrieves a list of users from the PlayStation Network API.
    ---
    --- @param psn_id string The PSN ID of the user to retrieve the list for.
    --- @param limit number The maximum number of users to retrieve per request.
    --- @param url_template string The URL template to use for the API request.
    --- @param list_name string The name of the list to retrieve (e.g. "friendsList", "blockList").
    --- @return string|nil error_message
    --- @return table users_list The list of users retrieved from the API.
    function GetUsersList(psn_id, limit, url_template, list_name)
        local users_list = {}
        local count = 0
        for start = 0, 2000, limit do
            local url = string.format(url_template, tostring(psn_id), limit, start)
            local err, http_code, result = AsyncOpWait(PSNAsyncOpTimeout, nil, "AsyncPlayStationWebApiRequest",
                "userProfile", url, "", "GET", "", {})
            if err or http_code ~= 200 then
                local err, http_error = JSONToLua(result)
                return err or http_code, result
            end
            local err, users = JSONToLua(result)
            if err or not users then
                return "json error"
            end
            for _, user_t in ipairs(users[list_name]) do
                count = count + 1
                table.insert(users_list, user_t)
            end
            if count >= users.totalItemCount then
                break
            end
        end
        return nil, users_list
    end

    ---
    --- Retrieves the public online IDs for a list of account IDs.
    ---
    --- The PlayStation API has a limit of 100 accounts per request, so this function
    --- batches the account IDs and makes multiple requests to retrieve all the
    --- public online IDs.
    ---
    --- @param account_ids table A table of account IDs to retrieve the public online IDs for.
    --- @return string|nil error_message An error message if there was a problem retrieving the public online IDs.
    --- @return table assocs A table mapping account IDs to their corresponding public online IDs.
    ---
    function GetPublicIds(account_ids)
        -- PlayStation API has a limit of 100 accounts per request
        local batches = {}
        local count = 0
        local account_ids_string = ""
        for _, acc_id in pairs(account_ids) do
            if count == 99 then
                count = 0
                table.insert(batches, account_ids_string)
                account_ids_string = ""
            end
            account_ids_string = account_ids_string .. (count == 0 and "" or ",") .. acc_id
            count = count + 1
        end
        table.insert(batches, account_ids_string)

        local online_ids = {}
        local count = 0
        for _, accounts_id_string in ipairs(batches) do
            local url = string.format("/v1/users/profiles?accountIds=%s", accounts_id_string)
            local err, http_code, result = AsyncOpWait(PSNAsyncOpTimeout, nil, "AsyncPlayStationWebApiRequest",
                "userProfile", url, "", "GET", "", {})
            if err or http_code ~= 200 then
                local err, http_error = JSONToLua(result)
                return err or http_code, result
            end
            local err, users = JSONToLua(result)
            if err or not users then
                return "json error"
            end
            for _, user_t in ipairs(users and users.profiles) do
                count = count + 1
                table.insert(online_ids, tostring(user_t.onlineId or ""))
            end
        end

        local assocs = {}
        for idx, id in ipairs(account_ids) do
            assocs[id] = online_ids[idx]
        end
        return nil, assocs
    end

    ---
    --- Retrieves the list of friends and blocked users for the current platform.
    ---
    --- @return string|nil error_message An error message if there was a problem retrieving the friends and blocked users.
    --- @return string platform The name of the current platform ("psn", "xboxlive", or "nintendo").
    --- @return table friends A table mapping account IDs to their corresponding public online IDs.
    --- @return table blocked A table mapping account IDs of blocked users to empty strings.
    ---
    function PlatformGetFriends()
        local time = os.time()
        if time - g_LastPlayStationGetFriends > 60 then -- more than a minute ago
            g_LastPlayStationGetFriends = time
            -- can use psn_id instead of "me" for friendsList, but not blockList
            local user = "me"
            -- Get friends
            local friends_list = {}
            local err, friends_list = GetUsersList(user, 500, "/v1/users/%s/friends?limit=%d&offset=%d", "friends")
            if err then
                return "GET friendList failed: " .. err
            end

            -- Get blocked users
            local block_list = {}
            err, block_list = GetUsersList(user, 2000, "/v1/users/%s/blocks?limit=%d&offset=%d", "blocks")
            if err then
                return "GET blockList failed: " .. err
            end

            -- get online (public) ids from the account ids
            local total_ids = {}
            for _, id in ipairs(friends_list) do
                table.insert(total_ids, id)
            end
            for _, id in ipairs(block_list) do
                table.insert(total_ids, id)
            end
            local err, public_ids = GetPublicIds(total_ids)
            if err then
                return "GET Public IDs failed: " .. err
            end

            -- recover the association between account id and online id
            g_LastFriendList = {}
            for _, friend in ipairs(friends_list) do
                g_LastFriendList[friend] = public_ids[friend]
            end
            g_LastBlockList = {}
            for _, blocked in ipairs(block_list) do
                g_LastBlockList[friend] = public_ids[blocked]
            end
        end
        return nil, "psn", g_LastFriendList, g_LastBlockList
    end

end --Platform.playstation

if Platform.xbox then

    ---
    --- Retrieves the list of friends and blocked users for the current Xbox Live account.
    ---
    --- @return string|nil error message, if any
    --- @return string platform identifier, always "xboxlive"
    --- @return table friends list, where keys are hashed XUIDs and values are gamertags
    --- @return table blocked list, where keys are hashed XUIDs and values are empty strings
    ---
    function PlatformGetFriends()
        local err, console_friends_xuid = AsyncXboxGetFriends()
        if err then
            return err
        end
        local err, consoles_friends_gamertags = AsyncXboxGetGamertagsFromXuids(console_friends_xuid)
        if err then
            return err
        end
        local friends = {}
        for i, xuid in ipairs(console_friends_xuid) do
            friends[HashXUID(tostring(xuid))] = consoles_friends_gamertags[i]
        end

        local blocked = {}
        local err, console_blocked = AsyncXboxGetAvoidList()
        for _, XUID in ipairs(console_blocked or empty_table) do
            blocked[HashXUID(tostring(XUID))] = "" -- this will force the backed to lookup the name
        end
        return nil, "xboxlive", friends, blocked
    end

function OnMsg.XboxAppStateChanged()
	if XboxAppState == "full" then
		CreateRealTimeThread(UpdatePlatformFriends, {}, {})
	end
end

end -- Platform.xbox

if Platform.switch then

    ---
    --- Retrieves the list of friends and blocked users for the current Nintendo Switch account.
    ---
    --- @return string|nil error message, if any
    --- @return string platform identifier, always "nintendo"
    --- @return table friends list, where keys are hashed friend IDs and values are friend names
    --- @return table blocked list, where keys are hashed blocked IDs and values are empty strings
    ---
    function PlatformGetFriends()
        local err, friend_ids, friend_names = Switch.GetFriends()
        if err then
            return err
        end
        local friends = {}
        for i = 1, #friend_ids do
            friends[string.format("%s:%s", netEnvironment, friend_ids[i])] = friend_names[i]
        end
        local err, blocked_ids = Switch.GetBlocked()
        if err then
            return err
        end
        local blocked = {}
        for i = 1, #blocked_ids do
            blocked[string.format("%s:%s", netEnvironment, blocked_ids[i])] = ""
        end

        return nil, "nintendo", friends, blocked
    end

end -- Platform.switch

---
--- Updates the platform friends and blocked lists for the current account.
---
--- This function retrieves the current friends and blocked lists from the platform,
--- compares them to the last known state stored in the account storage, and performs
--- the necessary actions to keep the local state in sync (sending friend requests,
--- unfriending, blocking, unblocking).
---
--- @param friends table The current friends list, where keys are account IDs and values are friend status.
--- @param friend_names table The current friend names, where keys are account IDs and values are friend names.
---
function UpdatePlatformFriends(friends, friend_names)
    if not AccountStorage or not NetIsConnected() then
        return
    end
    local err, alias_type, platform_friends, platform_blocked = PlatformGetFriends()
    if err or not friends then
        return err
    end

    local stored_friends = AccountStorage.platform_friends or empty_table
    local stored_blocked = AccountStorage.platform_blocked or empty_table

    -- confirm invitations from people with names matching our friends
    local platform_friends_by_name = table.invert(platform_friends)
    for account_id, status in pairs(friends) do
        local name = friend_names[account_id]
        if status == "invited" and platform_friends_by_name[name] then
            NetFriendRequest(name, platform_friends_by_name[name], alias_type)
        end
    end

    local friends_changed
    -- send invitation to new friends (compared to the last seen list)
    for id, name in pairs(platform_friends) do
        if not stored_friends[id] then
            friends_changed = true
            NetFriendRequest(name, id, alias_type)
        end
    end

    -- unfriend people who we have unfriended in the platform (compared to last seen list)
    for id in pairs(stored_friends) do
        if not platform_friends[id] then
            friends_changed = true
            NetUnfriend(id, alias_type)
        end
    end

    -- block players (compared to the last seen blocked list)
    for id, name in pairs(platform_blocked) do
        if not stored_blocked[id] then
            friends_changed = true
            NetBlock(name, id, alias_type)
        end
    end

    -- unblock players (compared to the last seen blocked list)
    for id in pairs(stored_blocked) do
        if not platform_blocked[id] then
            friends_changed = true
            NetUnblock(id, alias_type)
        end
    end

    if friends_changed then
        AccountStorage.platform_friends = platform_friends
        AccountStorage.platform_blocked = platform_blocked
        SaveAccountStorage(5000)
    end
end

---
--- Handles changes to the player's friends list.
---
--- This function is called when the player's friends list changes, either due to new friends being added, existing friends being removed, or the blocked list changing.
---
--- It ensures that the player's local friend and blocked lists are kept up-to-date with the platform's lists, by sending friend requests, unfriending, blocking, and unblocking as necessary.
---
--- @param friends table The current list of the player's friends, with their account IDs as keys and their friend status as values.
--- @param friend_names table The current list of the player's friends, with their account IDs as keys and their names as values.
--- @param event string The type of event that triggered this function, either "init" or something else.
function OnMsg.FriendsChange(friends, friend_names, event)
    if not AccountStorage then
        return
    end
    if event == "init" then
        local time = os.time()
        if time - (AccountStorage.friend_reset_time or 0) > 7 * 24 * 60 * 60 then
            AccountStorage.platform_friends = {}
            AccountStorage.platform_blocked = {}
            AccountStorage.friend_reset_time = time
        end
        CreateRealTimeThread(UpdatePlatformFriends, friends, friend_names)
    end
end
