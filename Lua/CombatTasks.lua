GameVar("gv_CombatTaskCDs", {})

---
--- Generates a set of combat tasks for the current map units.
---
--- @param amount number The number of combat tasks to generate. Defaults to 1.
--- @return boolean True if combat tasks were generated, false otherwise.
function GenerateCombatTasks(amount)
	amount = amount or 1
	for i = 1, amount do
		local unitTasks = GetAvailableCombatTasks()
		if #unitTasks <= 0 then print("No more eligible combat tasks.") return end
		
		local unitTaskCombo = unitTasks[InteractionRand(#unitTasks, "CombatTasks") + 1]
		local unitId = unitTaskCombo.unitId
		
		local taskId
		local favouredRoll = InteractionRand(100, "CombatTasks")
		if #unitTaskCombo.favoured > 0 and favouredRoll < const.CombatTask.FavouredChance then
			taskId = unitTaskCombo.favoured[InteractionRand(#unitTaskCombo.favoured, "CombatTasks") + 1]
		else
			taskId = unitTaskCombo.general[InteractionRand(#unitTaskCombo.general, "CombatTasks") + 1]
		end
		
		local taskDef = CombatTaskDefs[taskId]
		GiveCombatTask(taskDef, unitId)
	end
	RefreshCombatTasks()
	return true
end

---
--- Generates a list of available combat tasks for the current map units.
---
--- @return table A table of available combat task combinations, where each entry has the following fields:
---   - unitId: the session ID of the unit
---   - general: a list of general combat task IDs that are available for the unit
---   - favoured: a list of favoured combat task IDs that are available for the unit
---
function GetAvailableCombatTasks()
	local presets = PresetArray(CombatTask)
	local units = GetCurrentMapUnits()
	local result = {}
	
	for _, unit in ipairs(units) do
		if not gv_CombatTaskCDs[unit.session_id] or gv_CombatTaskCDs[unit.session_id] <= Game.CampaignTime then
			local availableTasks = {}
			for _, preset in ipairs(presets) do
				if not gv_CombatTaskCDs[preset.id] or gv_CombatTaskCDs[preset.id] <= Game.CampaignTime then
					if preset:CanBeSelected(unit) then
						availableTasks[#availableTasks+1] = preset.id
					end
				end
			end
			
			if #availableTasks > 0 then
				result[#result+1] = {}
				result[#result].unitId = unit.session_id
				result[#result].general = availableTasks
				
				local favouredTasks = {}
				for _, taskId in ipairs(availableTasks) do
					if CombatTaskDefs[taskId]:IsFavoured(unit) then
						favouredTasks[#favouredTasks+1] = taskId
					end
				end
				result[#result].favoured = favouredTasks
			end
		end
	end
	
	return result
end

---
--- Gives a combat task to the specified unit.
---
--- @param preset CombatTaskDef The combat task definition to give to the unit.
--- @param unitId number The session ID of the unit to receive the combat task.
---
function GiveCombatTask(preset, unitId)
	local unit = g_Units[unitId]
	if not unit then return end
	
	CreateGameTimeThread(function()
		WaitLoadingScreenClose()
		Sleep(1000)
		PlayVoiceResponse(unit, "CombatTaskGiven")
	end)
	
	-- add CD to the preset
	local cooldown = Game.CampaignTime + preset.cooldown
	gv_CombatTaskCDs[preset.id] = cooldown
	
	local mercCooldown = Game.CampaignTime + const.CombatTask.MercCooldown
	gv_CombatTaskCDs[unitId] = mercCooldown
	
	unit:AddCombatTask(preset.id)
	RefreshCombatTasks()
end

---
--- Returns a list of all active combat tasks in the current sector.
---
--- @return table A table containing all active combat tasks in the current sector.
---
function GetCombatTasksInSector()
	if #g_Units <= 0 then return end
	local units = GetCurrentMapUnits()
	
	local tasks = {}
	for _, unit in ipairs(units) do
		for _, task in ipairs(unit.combatTasks) do
			tasks[#tasks+1] = task
		end
	end
	
	return tasks
end

---
--- Finds an active combat task with the specified ID.
---
--- @param id number The ID of the combat task to find.
--- @return table|boolean The combat task if found, or false if not found.
---
function FindActiveCombatTask(id)
	local units = GetCurrentMapUnits()
	for _, unit in ipairs(units) do
		local task = unit:FirstCombatTaskById(id)
		if task then
			return task
		end
	end
	return false
end

-- Give New Tasks
---
--- Rolls for combat tasks in the current sector.
---
--- This function checks the requirements for generating combat tasks in the current sector, such as the number of enemies, whether the first conflict has been won, and the cooldown period. If the requirements are met, it generates a random chance of creating a new combat task.
---
--- @param sector table The current sector.
--- @return boolean True if a combat task was successfully generated, false otherwise.
---
function RollForCombatTasks()
	local sector = gv_Sectors[gv_CurrentSectorId]
	
	if CountAnyEnemies("skipAnimals") < const.CombatTask.RequiredEnemies then return end
	if sector.combatTaskGenerate == "afterFirstConflict" and not sector.firstConflictWon then return end
	if sector.combatTaskGenerate ~= "always" then return end
	if	gv_CombatTaskCDs[sector.Id] and Game.CampaignTime < gv_CombatTaskCDs[sector.Id] then return end
	
	local chance = const.CombatTask.ChanceToGive
	for i = 1, sector.combatTaskAmount do
		local roll = InteractionRand(100, "CombatTasks")
		if roll < chance then
			local success = GenerateCombatTasks(1)
			if success then
				local sectorCooldown = Game.CampaignTime + const.CombatTask.SectorCooldown
				gv_CombatTaskCDs[sector.Id] = sectorCooldown
			end
		end
	end
end

---
--- Synchronizes the initialization of combat tasks across the network.
---
--- This function is called when the game enters a new sector, and is responsible for initializing combat tasks. If the `g_TestCombat` table has a `combatTask` field, it will generate a combat task for a random unit on the map using the preset defined in `CombatTaskDefs`. Otherwise, it will call the `RollForCombatTasks()` function to generate combat tasks based on the sector's requirements.
---
--- @param game_start boolean Whether the game is starting for the first time.
--- @param load_game boolean Whether the game is being loaded from a saved game.
---
function NetSyncEvents.InitCombatTasks()
	if g_TestCombat and g_TestCombat.combatTask then
		local units = GetCurrentMapUnits()
		local unitId = units[InteractionRand(#units, "CombatTasks") + 1].session_id
		local preset = CombatTaskDefs[g_TestCombat.combatTask]
		GiveCombatTask(preset, unitId)
	else
		RollForCombatTasks()
	end
end

function OnMsg.EnterSector(game_start, load_game)
	if game_start or load_game or (netInGame and not NetIsHost()) then return end
	NetSyncEvent("InitCombatTasks")
end

-- Finish Tasks
---
--- Finishes all combat tasks in the current sector that are in progress.
---
--- For each combat task in the current sector that is in progress, this function checks if the task has been completed or failed based on the task's current progress and the required progress. If the task has been completed, it calls the `Complete()` method on the task. If the task has failed, it calls the `Fail()` method on the task.
---
--- @return nil
function FinishCombatTasks()
	local tasks = GetCombatTasksInSector()
	for _, task in ipairs(tasks) do
		if task.state == "inProgress" then
			local completed = (task.currentProgress >= task.requiredProgress and not task.reverseProgress) 
								or (task.currentProgress < task.requiredProgress and task.reverseProgress)
			if completed then
				task:Complete()
			else
				task:Fail()
			end
		end
	end
end

function OnMsg.CombatEnd()
	if CountAnyEnemies() <= 0 then
		FinishCombatTasks()
	end
end

-- Check for firstConflictWon
function OnMsg.ConflictEnd(sector, bNoVoice, playerAttacking, playerWon, isAutoResolve, isRetreat, fromMap)
	if not sector.firstConflictWon and playerWon and IsPlayerSide(sector.Side) then
		sector.firstConflictWon = true
	end
end

-- Fail Associated Tasks
function OnMsg.UnitDied(unit)
	if IsMerc(unit) then
		for _, task in ipairs(unit.combatTasks) do
			task:Fail()
		end
	end
end

function OnMsg.UnitRetreat(unit)
	if IsMerc(unit) then
		for _, task in ipairs(unit.combatTasks) do
			task:Fail()
		end
	end
end

-- UI
MapVar("CombatTaskUIAnimations", {})

---
--- Marks the combat tasks as modified, triggering a refresh of the UI.
---
--- @return nil
function RefreshCombatTasks()
	ObjModified("combat_tasks")
end

OnMsg.OpenSatelliteView = RefreshCombatTasks
OnMsg.CloseSatelliteView = RefreshCombatTasks

-- Merc of the week
GameVar("gv_CombatTasksCompleted", 0)
GameVar("gv_RecentlyCompletedCombatTasks", {})

function OnMsg.CombatTaskFinished(taskId, unit, success)
	if success then
		gv_CombatTasksCompleted = gv_CombatTasksCompleted + 1
		gv_RecentlyCompletedCombatTasks[#gv_RecentlyCompletedCombatTasks+1] = {
			taskId = taskId,
			unitId = unit.session_id
		}
		
		if gv_CombatTasksCompleted % const.CombatTask.CompletedForBonus == 0 then
			CombatTaskBonusReward()
			SendMercOfTheWeekEmail()
			gv_RecentlyCompletedCombatTasks = {}
		end
	end
end

---
--- Provides a bonus reward for completing a set number of combat tasks.
---
--- The bonus amount is defined by the `const.CombatTask.BonusReward` constant.
--- The bonus is added to the player's money balance.
--- A combat log entry is also created to record the bonus reward.
---
--- @return nil
function CombatTaskBonusReward()
	local bonus = const.CombatTask.BonusReward
	CombatLog("important", T{646683516115, "Combat task completion bonus - received <money(bonus)>", bonus = bonus})
	AddMoney(bonus, "deposit")
end

---
--- Sends an email to the player about the "Merc of the Week" bonus reward.
---
--- The email is selected randomly from a preset group of emails.
--- The email context includes the unit ID and task ID of a recently completed combat task,
--- as well as the bonus reward amount.
---
--- @return nil
function SendMercOfTheWeekEmail()
	local emailGroup = Presets.Email.MercOfTheWeek
	local emailPreset = emailGroup[InteractionRand(#emailGroup, "CombatTasks")+1]
	local combo = gv_RecentlyCompletedCombatTasks[InteractionRand(#gv_RecentlyCompletedCombatTasks, "CombatTasks")+1]
	local context = {unitId = combo.unitId, taskId = combo.taskId, reward = const.CombatTask.BonusReward}
	ReceiveEmail(emailPreset.id, context)
end
