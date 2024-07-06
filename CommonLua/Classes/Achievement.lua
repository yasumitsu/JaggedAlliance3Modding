ach_print = CreatePrint{
	--"ach",
}

-- Game-specific hooks, titles should override these:

---
--- Checks if the given achievement can be unlocked.
---
--- @param achievement string The ID of the achievement to check.
--- @return boolean, string Whether the achievement can be unlocked, and the reason if it cannot.
function CanUnlockAchievement(achievement)
	local reasons = {}
	Msg("UnableToUnlockAchievementReasons", reasons, achievement)
	local reason = next(reasons)
	return not reason, reason
end

-- Platform-specific functions:

---
--- Asynchronously unlocks the specified achievement.
---
--- @param achievement string The ID of the achievement to unlock.
function AsyncAchievementUnlock(achievement) 
	Msg("AchievementUnlocked", achievement)
end

---
--- Synchronizes the achievements between the game and the platform.
---
function SynchronizeAchievements() end

PlatformCanUnlockAchievement = return_true

CheatPlatformUnlockAllAchievements = empty_func
CheatPlatformResetAllAchievements = empty_func

-- Common functions:

-- return unlocked, secret
---
--- Gets the flags for the specified achievement.
---
--- @param achievement string The ID of the achievement to get the flags for.
--- @return boolean, boolean Whether the achievement is unlocked, and whether the achievement is secret.
function GetAchievementFlags(achievement)
	return AccountStorage.achievements.unlocked[achievement], AchievementPresets[achievement].secret
end

---
--- Gets the number of unlocked achievements and the total number of achievements.
---
--- @return integer, integer The number of unlocked achievements, and the total number of achievements.
function GetUnlockedAchievementsCount()
	local unlocked, total = 0, 0
	ForEachPreset(Achievement, function(achievement)
		if not achievement:IsCurrentlyUsed() then return end
		unlocked = unlocked + (AccountStorage.achievements.unlocked[achievement.id] and 1 or 0)
		total = total + 1
	end)
	return unlocked, total
end

---
--- Checks the progress of the specified achievement and unlocks it if the target is reached.
---
--- @param achievement string The ID of the achievement to check.
--- @param dont_unlock_in_provider boolean If true, the achievement will not be unlocked in the platform provider.
---
function _CheckAchievementProgress(achievement, dont_unlock_in_provider)
	local progress = AccountStorage.achievements.progress[achievement] or 0
	local target = AchievementPresets[achievement].target
	if target and progress >= target then
		AchievementUnlock(achievement, dont_unlock_in_provider)
	end
end

local function EngineCanUnlockAchievement(achievement)
	if Platform.demo then return false, "not available in demo" end
	if GameState.Tutorial then
		return false, "in tutorial"
	end
	if AccountStorage.achievements.unlocked[achievement] then
		return false, "already unlocked"
	end
	assert(AchievementPresets[achievement])
	if not AchievementPresets[achievement] then
		return false, "dlc not present"
	end
	return PlatformCanUnlockAchievement(achievement)
end

local function CanModifyAchievementProgress(achievement)
	-- 1. Engine-specific reasons not to modify  achievement progress?
	local success, reason = EngineCanUnlockAchievement(achievement)
	if not success then
		ach_print("cannot modify achievement progress, forbidden by engine check ", achievement, reason)
		return false
	end	
	
	-- 2. Game-specific reasons not to modify achievement progress?
	local success, reason = CanUnlockAchievement(achievement)
	if not success then
		ach_print("cannot modify achievement progress, forbidden by title-specific check ", achievement, reason)
		return false
	end	
	
	return true
end

---
--- Adds progress to the specified achievement. If the progress reaches the target, the achievement will be unlocked.
---
--- @param achievement string The ID of the achievement to add progress to.
--- @param progress number The amount of progress to add.
--- @param max_delay_save number The maximum delay in milliseconds before saving the account storage.
---
--- @return boolean true if the progress was added successfully, false otherwise.
---
function AddAchievementProgress(achievement, progress, max_delay_save)
	if not CanModifyAchievementProgress(achievement) then
		return
	end
	
	local ach = AchievementPresets[achievement]	
	local current = AccountStorage.achievements.progress[achievement] or 0
	local save_storage = not ach.save_interval or ((current + progress) / ach.save_interval > (current / ach.save_interval))
	local total = current + progress
	local target = ach.target or 0
	if total >= target then
		total = target
		save_storage = false
	end
	AccountStorage.achievements.progress[achievement] = total
	if save_storage then
		SaveAccountStorage(max_delay_save)
	end
	Msg("AchievementProgress", achievement)
	_CheckAchievementProgress(achievement)
	
	return true
end

---
--- Clears the progress for the specified achievement. This will reset the progress to 0.
---
--- @param achievement string The ID of the achievement to clear the progress for.
--- @param max_delay_save number The maximum delay in milliseconds before saving the account storage.
---
--- @return boolean true if the progress was cleared successfully, false otherwise.
---
function ClearAchievementProgress(achievement, max_delay_save)
	if not CanModifyAchievementProgress(achievement) then
		return
	end

	AccountStorage.achievements.progress[achievement] = 0
	SaveAccountStorage(max_delay_save)
	Msg("AchievementProgress", achievement)
	
	return true
end

-- Synchronous version, launches a thread
--- Unlocks the specified achievement.
---
--- @param achievement string The ID of the achievement to unlock.
--- @param dont_unlock_in_provider boolean (optional) If true, the achievement will not be unlocked in the achievement provider.
---
--- @return boolean true if the achievement was unlocked successfully, false otherwise.
function AchievementUnlock(achievement, dont_unlock_in_provider)
	if not CanModifyAchievementProgress(achievement) then
		return
	end
	
	-- We set this before the thread, as otherwise calling AchievementUnlock twice will attempt to unlock it twice
	AccountStorage.achievements.unlocked[achievement] = true
	if not dont_unlock_in_provider then
		AsyncAchievementUnlock(achievement)
	end
	
	SaveAccountStorage(5000)
	return true
end

if Platform.developer then
	function AchievementUnlockAll()
		CreateRealTimeThread(function()
			for id, achievement_data in sorted_pairs(AchievementPresets) do
				AchievementUnlock(id)
				Sleep(100)
			end
		end)
	end
end

function OnMsg.NetConnect()
	local unlocked = AccountStorage and AccountStorage.achievements and AccountStorage.achievements.unlocked
	if not unlocked then return end
	
	local achievements = {}
	ForEachPreset(Achievement, function(achievement)
		if unlocked[achievement.id] then
			table.insert(achievements, achievement.id)
		end
	end)
	
	NetGossip("AllAchievementsUnlocked", achievements)
end