if FirstLoad then
	s_AchievementReceivedSignals = {}
	s_AchievementUnlockedSignals = {}
	_AchievementsToUnlock = {}
	_UnlockThread = false
	g_SteamIdToAchievementName = {}
	g_AchievementNameToSteamId = {}
end

function OnMsg.DataLoaded()
	g_SteamIdToAchievementName = {}
	g_AchievementNameToSteamId = {}
	ForEachPreset(Achievement, function(achievement, group_list) 
		local steam_id = achievement.steam_id ~= "" and achievement.steam_id or achievement.id
		g_SteamIdToAchievementName[steam_id] = achievement.id
		g_AchievementNameToSteamId[achievement.id] = steam_id
	end)
end

-- Steam account -> AccountStorage sync policy 
TransferUnlockedAchievementsFromSteam = true

---
--- Called when Steam achievements have been received.
--- Broadcasts the `s_AchievementReceivedSignals` message.
---
function OnSteamAchievementsReceived()
	Msg(s_AchievementReceivedSignals)
end

---
--- Called when a Steam achievement has been unlocked.
--- Broadcasts the `s_AchievementUnlockedSignals` message.
---
--- @param unlock_status string The status of the achievement unlock, either "success" or "failure".
---
function OnSteamAchievementUnlocked(unlock_status)
	if unlock_status == "success" then
		Msg(s_AchievementUnlockedSignals)
	end
end

local function WaitGetAchievements()
	if IsSteamLoggedIn() and SteamQueryAchievements(table.values(table.map(AchievementPresets, "steam_id"))) then
		local ok, data
		if WaitMsg( s_AchievementReceivedSignals, 5 * 1000 ) then
			data = SteamGetAchievements()
			if data then
				return true, table.map(data, g_SteamIdToAchievementName)
			end
		end
	end

	return false
end

local function GetSteamAchievementIds(achievements)
	local steam_achievements = { }
	for i, name in ipairs(achievements) do
		if AchievementPresets[name] then
			local steam_id = g_AchievementNameToSteamId[name]
			if not steam_id then
				print("Achievement", name, "doesn't have a Steam ID!")
			else
				table.insert(steam_achievements, steam_id)
			end
		end
	end
	return steam_achievements
end

local function WaitAchievementUnlock(achievements)
	if not Platform.steam or not IsSteamLoggedIn() then
		return true
	end
	local steam_achievements = GetSteamAchievementIds(achievements)
	local steam_unlocked = SteamUnlockAchievements(steam_achievements) and WaitMsg(s_AchievementUnlockedSignals, 5*1000)
	if not steam_unlocked then
		-- Currently our publisher wants to test if achievements work even if they haven't been
		-- created in the steam backend.
		-- To do this we unlock all achievements in AccountStorage even if they haven't been unlocked in steam.
		-- We also pop a notification if steam failed to unlock the achievement.
		Msg("SteamUnlockAchievementsFailed", steam_achievements)
	end
	return true
end

-------------------------------------------[ Higher level functions ]-----------------------------------------------

-- Asynchronous version, launches a thread
---
--- Asynchronously unlocks the specified achievement.
---
--- If the achievement is not already unlocked, it is added to a queue of achievements to be unlocked.
--- A separate thread is created to process the queue of achievements to be unlocked.
--- For each achievement in the queue, it attempts to unlock the achievement using `WaitAchievementUnlock`.
--- If the unlock is successful, a "AchievementUnlocked" message is sent.
--- If the unlock fails, the achievement is marked as not unlocked in the `AccountStorage.achievements.unlocked` table.
---
--- @param achievement string The name of the achievement to be unlocked.
---
function AsyncAchievementUnlock(achievement)
	_AchievementsToUnlock[achievement] = true
	if not IsValidThread(_UnlockThread) then
		_UnlockThread = CreateRealTimeThread( function()
			local achievement = next(_AchievementsToUnlock)
			while achievement do
				if WaitAchievementUnlock{achievement} then
					Msg("AchievementUnlocked", achievement)
				else
					AccountStorage.achievements.unlocked[achievement] = false
				end
				_AchievementsToUnlock[achievement] = nil
				achievement = next(_AchievementsToUnlock)
			end
		end)
	end
end

---
--- Synchronizes the achievements between the game's AccountStorage and the Steam platform.
---
--- This function checks the progress of achievements in the AccountStorage, and automatically unlocks them if the progress is sufficient. It then transfers the unlocked achievements from the AccountStorage to the Steam platform, and vice versa.
---
--- The function runs in a separate real-time thread to avoid blocking the main game loop. It also checks for changes to the AccountStorage.achievements.unlocked table during the synchronization process, and aborts the synchronization if changes are detected.
---
--- If the synchronization is successful, the function saves the updated AccountStorage to disk.
---
--- @function SynchronizeAchievements
--- @return nil
function SynchronizeAchievements()
	if not IsSteamLoggedIn() then return end
	
	-- check progress, auto-unlock if sufficient progress is made
	for k, v in pairs(AccountStorage.achievements.progress) do
		_CheckAchievementProgress(k, "don't unlock in provider")
	end
	
	local account_storage_unlocked = AccountStorage.achievements.unlocked
	CreateRealTimeThread(function()
		if account_storage_unlocked ~= AccountStorage.achievements.unlocked then
			print("Synchronize achievements aborted!")
			return
		end
		
		-- transfer unlocked achievements to Steam account
		WaitAchievementUnlock(table.keys(account_storage_unlocked))

		if not TransferUnlockedAchievementsFromSteam then
			return
		end
		
		if account_storage_unlocked ~= AccountStorage.achievements.unlocked then
			print("Synchronize achievements aborted!")
			return
		end
		
		-- transfer unlocked achievements to AccountStorage
		local ok, steam_unlocked = WaitGetAchievements()
		
		if account_storage_unlocked ~= AccountStorage.achievements.unlocked then
			print("Synchronize achievements aborted!")
			return
		end
		
		if not ok then
			print("Synchronize achievements failed!")
			return
		end
		
		local save = false
		for i = 1, #steam_unlocked do
			local id = steam_unlocked[i]
			if not account_storage_unlocked[id] then
				save = true
			end
			account_storage_unlocked[id] = true
		end
		if save then
			SaveAccountStorage(5000)
		end
	end)
end

---
--- Unlocks all achievements registered in the `AchievementPresets` table for the Steam platform.
---
--- This function is a cheat/debug utility and should not be used in production code.
---
--- @function CheatPlatformUnlockAllAchievements
--- @return nil
function CheatPlatformUnlockAllAchievements()
	if not Platform.steam or not IsSteamLoggedIn() then end
	local steam_achievements = GetSteamAchievementIds(table.keys(AchievementPresets, true))
	SteamUnlockAchievements(steam_achievements)
end

---
--- Resets all achievements registered in the `AchievementPresets` table for the Steam platform.
---
--- This function is a cheat/debug utility and should not be used in production code.
---
--- @function CheatPlatformResetAllAchievements
--- @return nil
function CheatPlatformResetAllAchievements()
	if not Platform.steam or not IsSteamLoggedIn() then end
	local steam_achievements = GetSteamAchievementIds(table.keys(AchievementPresets, true))
	SteamResetAchievements(steam_achievements)
end
