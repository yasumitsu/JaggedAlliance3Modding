GameVar("gv_Achievements", {})

--- Resets all achievement data in the game.
---
--- This function clears all achievement progress, targets, and unlock state from the
--- `AccountStorage.achievements` table. It then saves the updated account storage.
---
--- This function should be called when the player's achievements need to be reset,
--- such as when starting a new game or resetting the player's progress.
function ResetAchievements()
	gv_Achievements = {}

	AccountStorage.achievements.progress = {}
	AccountStorage.achievements.target = {}
	AccountStorage.achievements.unlocked = {}
	AccountStorage.achievements.state = {}
	
	SaveAccountStorage()
end

--- Resets the progress, target, unlocked state, and current game state for the specified achievement.
---
--- This function removes the specified achievement from the `gv_Achievements` table, and removes
--- its associated progress, target, unlocked, and current game state from the `AccountStorage.achievements`
--- table. It then saves the updated account storage.
---
--- This function should be called when the player's progress for a specific achievement needs to be reset,
--- such as when starting a new game or resetting the player's progress.
---
--- @param id string The ID of the achievement to reset.
function ResetAchievement(id)
	gv_Achievements[id] = nil
	
	AccountStorage.achievements.progress[id] = nil
	AccountStorage.achievements.target[id] = nil
	AccountStorage.achievements.unlocked[id] = nil
	if AccountStorage.achievements.state then
		AccountStorage.achievements.state[id] = nil
	end
	
	SaveAccountStorage()
end

---
--- Gets the current game's achievement state for the specified achievement.
---
--- @param achievement string The ID of the achievement to get the state for.
--- @return boolean|nil The current state of the achievement, or `nil` if no state is available.
---
function GetAccountCurrentGameAchievementState(achievement)
	local state = AccountStorage.achievements.state
	if state then
		state = state[achievement]
		if state then
			return state[Game.id]
		end
	end
end

---
--- Sets the current game's achievement state for the specified achievement.
---
--- This function updates the `AccountStorage.achievements.state` table with the provided `state` for the specified `achievement` and the current `Game.id`. It then saves the updated account storage.
---
--- This function should be called when the player's progress for a specific achievement needs to be updated, such as when the player completes an achievement.
---
--- @param achievement string The ID of the achievement to set the state for.
--- @param state boolean The new state of the achievement.
---
function SetAccountCurrentGameAchievementState(achievement, state)
	AccountStorage.achievements.state = AccountStorage.achievements.state or {}
	AccountStorage.achievements.state[achievement] = AccountStorage.achievements.state[achievement] or {}
	AccountStorage.achievements.state[achievement][Game.id] = state
	
	SaveAccountStorage(5000)
end

-- Debug - remove for release
function OnMsg.AchievementUnlocked(achievement)
	local preset = AchievementPresets[achievement]
	local text = "Achievement Unlocked: "
	if preset.display_name then text = text .. "<em>" .. _InternalTranslate(preset.display_name) .. "</em>" .. ", " end
	if preset.description then text = text .. _InternalTranslate(preset.description, preset) end
	print(text)
end
