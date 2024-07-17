if FirstLoad then
	CombatActions_Waiting = {} -- packed: action_id, unit, ap, ...
	CombatActions_RunningState = {}
	CombatActions_StartThread = false
	CombatActions_LastStartedAction = {}
	CombatActions_UnitAction = {}
	CombatActionTargetFilters = {}
	LocalPlayer_InterruptSent = false
	CombatSaveGameRequest = false
end

function OnMsg.NewMap()
	CombatActions_Waiting = {}
	CombatActions_RunningState = {}
	CombatActions_LastStartedAction =  {}
	CombatActions_UnitAction = {}
	CombatActions_StartThread = false
	LocalPlayer_InterruptSent = false
	CombatSaveGameRequest = false
end

CustomCombatActions = {}
NetStartCombatActions = {}

---
--- Checks if a combat action cannot be started for the given action ID and unit.
---
--- @param action_id string The ID of the combat action to check.
--- @param unit table The unit that the action is being performed on.
--- @return boolean True if the action cannot be started, false otherwise.
---
function CombatActionCannotBeStarted(action_id, unit)
	if g_Combat then
		for u, state in pairs(CombatActions_RunningState) do
			if state ~= "PostAction" then
				return true
			end
		end
	else
		local state = unit and CombatActions_RunningState[unit]
		if state and state ~= "PostAction" and action_id ~= "MoveItems" and action_id ~= "MoveMultiItems" and action_id ~= "DestroyItem" then
			local actionPreset = CombatActions[action_id]
			local unitCanBeInterrupted = actionPreset and actionPreset.InterruptInExploration
			if not unitCanBeInterrupted then
				return true
			end
		end
	end
	return false
end

---
--- Cancels a combat action that was started on the network.
---
--- @param action_id string The ID of the combat action that was started.
--- @param unit table The unit that the action was being performed on.
---
function NetStartActionCanceled(action_id, unit)
	if unit and unit.aim_action_id == action_id then
		NetSyncEvent("Aim", unit)
	end
end

---
--- Cancels a combat action that was started on the network.
---
--- @param action_id string The ID of the combat action that was started.
--- @param unit table The unit that the action was being performed on.
---
function ActionCanceled(action_id, unit)
	if unit and unit.aim_action_id == action_id then
		unit:SetAimTarget()
	end
end

---
--- Starts a combat action on the network.
---
--- @param action_id string The ID of the combat action to start.
--- @param unit table The unit that the action is being performed on.
--- @param ap number The action points required for the combat action.
--- @param args table Any additional arguments required for the combat action.
--- @param ... any Any additional arguments required for the combat action.
--- @return boolean True if the combat action was started successfully, false otherwise.
---
function NetStartCombatAction(action_id, unit, ap, args, ...)
	local net_cmd = NetStartCombatActions[action_id]
	-- action_id ~= "MoveItems": temporary fix for not being able to execute many MoveItems actions one after another
	if action_id ~= "MoveItems" and action_id ~= "MoveMultiItems" and action_id ~= "DestroyItem" and net_cmd and net_cmd.unit == unit and net_cmd.ap == ap then
		NetStartActionCanceled(action_id, unit)
		return		-- already registered to travel the network, skip it
	end
	if g_UnitAwarenessPending then
		NetStartActionCanceled(action_id, unit)
		return -- don't start new combat actions while there are units waiting to become aware
	end
	
	if CombatActionCannotBeStarted(action_id, unit) then
		NetStartActionCanceled(action_id, unit)
		return
	end
	
	if g_Combat then
		-- Unit became uncontrollable, it probably died
		-- This can happen when spamming commands and the unit dies
		if unit and not unit:CanBeControlled() then
			NetStartActionCanceled(action_id, unit)
			return
		end
		if not IsNetPlayerTurn() or g_Combat:IsLocalPlayerEndTurn() then
			NetStartActionCanceled(action_id, unit)
			return
		end
		if unit then
			if not ap or ap < 0 or not unit:UIHasAP(ap, action_id, args) then
				NetStartActionCanceled(action_id, unit)
				return false
			end
		end
		ap = ap or 0 -- combat mark
	else
		ap = false -- out of combat mark
	end
	NetSyncEvent("StartCombatAction", netUniqueId, action_id, unit, ap, args, ...)
	return true
end

---
--- Handles the local effects of starting a combat action.
--- This function is called when a combat action is started on the local player's turn.
---
--- @param player_id number The unique ID of the player who started the combat action.
--- @param action_id string The ID of the combat action that was started.
--- @param unit table The unit that the combat action was performed on.
--- @param ap number The action points consumed by the combat action.
--- @param ... any Any additional arguments required for the combat action.
---
function NetSyncLocalEffects.StartCombatAction(player_id, action_id, unit, ap, ...)
	NetStartCombatActions[action_id] = {unit = unit, ap = ap}
	if unit then
		unit.actions_nettravel = unit.actions_nettravel + 1
		if (ap or 0) > 0 then
			unit.ui_reserved_ap = unit.ui_reserved_ap + ap
		end
	end
	if action_id == "Interrupt" then
		LocalPlayer_InterruptSent = true
		Msg("NetSentInterrupt")
	else
		LocalPlayer_InterruptSent = false
	end
end

---
--- Reverts the local effects of starting a combat action.
--- This function is called when a combat action is reverted on the local player's turn.
---
--- @param player_id number The unique ID of the player who started the combat action.
--- @param action_id string The ID of the combat action that was reverted.
--- @param unit table The unit that the combat action was performed on.
--- @param ap number The action points consumed by the combat action.
--- @param ... any Any additional arguments required for the combat action.
---
function NetSyncRevertLocalEffects.StartCombatAction(player_id, action_id, unit, ap, ...)
	if player_id ~= netUniqueId then
		return
	end
	NetStartCombatActions[action_id] = nil
	if unit then
		unit.actions_nettravel = Max(0, unit.actions_nettravel - 1)
		if ap and ap > 0 then
			unit.ui_reserved_ap = Max(0, unit.ui_reserved_ap - ap)
		end
	end
	if action_id == "Interrupt" then
		LocalPlayer_InterruptSent = false
	end
end

---
--- Handles the start of a combat action on the network.
---
--- @param player_id number The unique ID of the player who started the combat action.
--- @param action_id string The ID of the combat action that was started.
--- @param unit table The unit that the combat action was performed on.
--- @param ap number The action points consumed by the combat action.
--- @param ... any Any additional arguments required for the combat action.
---
function NetSyncEvents.StartCombatAction(player_id, action_id, unit, ap, ...)
	if not g_Combat ~= not ap then
		ActionCanceled(action_id, unit)
		return -- combat mode changed
	end
	if g_Combat then
		if not IsNetPlayerTurn(player_id) then
			ActionCanceled(action_id, unit)
			return
		end
	end
	if action_id == "Interrupt" then
		InterruptPlayerActions(player_id)
		return
	end
	StartCombatAction(action_id, unit, ap, ...)
end

---
--- Starts a combat action on the specified unit.
---
--- @param action_id string The ID of the combat action to start.
--- @param unit table The unit on which the combat action will be performed.
--- @param ap number The action points consumed by the combat action.
--- @param ... any Any additional arguments required for the combat action.
---
function StartCombatAction(action_id, unit, ap, ...)
	if g_Combat then
		if unit then
			unit:ConsumeAP(ap, action_id, ...)
		end
		if g_ItemNetEvents[action_id] then
			CancelUnitWaitingActions(unit)
		end
		table.insert(CombatActions_Waiting, pack_params(action_id, unit, ap, ...))
		RunCombatActions()
	else
		RunCombatAction(action_id, unit, 0, ...)
	end
end

---
--- Sets the combat action state for the specified unit.
---
--- @param unit table The unit for which to set the combat action state.
--- @param state string|nil The new combat action state for the unit. Can be "start", "PostAction", or nil to clear the state.
---
function SetCombatActionState(unit, state)
	assert(not state or not unit:IsDead())
	state = state or nil
	local prev_state = CombatActions_RunningState[unit]
	if prev_state == state then
		return
	end
	unit:NetUpdateHash("CombatActionState", state)
	CombatActions_RunningState[unit] = state
	Msg("CombatActionStateChange", unit, state)
	if not state then
		Msg("CombatPostAction", unit)
		Msg("CombatActionEnd", unit)
		unit:CallReactions("OnCombatActionEnd")
	elseif state == "start" then
		Msg("CombatActionStart", unit)
		unit:CallReactions("OnCombatActionStart")
	elseif state == "PostAction" then
		Msg("CombatPostAction", unit)
	end
	ObjModified(unit)
	if g_Combat and #CombatActions_Waiting == 0 and not next(CombatActions_RunningState) then
		g_Combat:CheckEndTurn()
		return
	end
	if CombatSaveGameRequest or not next(CombatActions_RunningState) or prev_state and prev_state ~= "PostAction" and (not state or state == "PostAction") then
		RunCombatActions()
	end
end

---
--- Runs a combat action for the specified unit.
---
--- @param action_id string The ID of the combat action to run.
--- @param unit table The unit that will perform the combat action.
--- @param ap number The amount of action points the unit will consume.
--- @param ... any Additional arguments required by the combat action.
---
--- @return nil
---
function RunCombatAction(action_id, unit, ap, ...)
	CombatActions_LastStartedAction.action_id = action_id
	CombatActions_LastStartedAction.unit = unit
	CombatActions_LastStartedAction.start_time = GameTime()
	CombatActions_UnitAction[unit] = action_id
	if action_id == "Move" and unit:IsMerc() then 
		g_SelectedObjLastActionIsMovement = true
	else
		g_SelectedObjLastActionIsMovement = false
	end

	local func = CustomCombatActions[action_id]
	if func then
		func(unit, ap, ...)
	else
		local action = CombatActions[action_id]
		if action then
			action:Run(unit, ap, ...)
		end
		if action.ActivePauseBehavior == "queue" then
			if IsActivePaused() then
				unit:SetQueuedAction(action_id)
			end
		elseif action.ActivePauseBehavior == "unpause" then
			if IsActivePaused() then
				SetActivePause(false)
			end
			if not g_Combat then
				ExplorationStartExclusiveAction(unit)
			end
		end
	end
	Msg("RunCombatAction", action_id, unit, ap)
end

---
--- Runs all the combat actions that are waiting to be executed.
---
--- This function is responsible for managing the execution of combat actions. It checks if there are any combat actions waiting to be executed, and if so, it runs them one by one. It also handles cases where the game is being saved, and ensures that the save game process is completed before continuing with the combat actions.
---
--- The function creates a game time thread to handle the execution of the combat actions, which allows it to run in the background without blocking the main game loop.
---
--- @return nil
---
function RunCombatActions()
	if not CombatSaveGameRequest and (#CombatActions_Waiting == 0 or IsValidTarget(CombatActions_StartThread)) then
		return
	end
	CombatActions_StartThread = CreateGameTimeThread(function()
		while CombatSaveGameRequest and not next(CombatActions_RunningState) do
			CombatSaveGameRequest = false
			MPSaveGame()
			WaitMsg("MPSaveGameDone")
		end
		local can_start = not CombatSaveGameRequest
		local idx = 1
		while idx <= #CombatActions_Waiting do
			local adata = CombatActions_Waiting[idx]
			local action_id, unit, ap = unpack_params(adata, 1, 3)
			local combat_action = CombatActions[action_id]
			if unit and unit:IsDead() and action_id ~= "Teleport" then
				table.remove(CombatActions_Waiting, idx)
			elseif combat_action and combat_action.LocalChoiceAction then
				-- open loot dialog
				if unit and (CombatActions_RunningState[unit] or table.find(CombatActions_Waiting, 2, unit) < idx) then
					idx = idx + 1
				else
					table.remove(CombatActions_Waiting, idx)
					RunCombatAction(unpack_params(adata))
				end
			else
				local run_action = can_start and not CombatActions_RunningState[unit]
				if run_action and next(CombatActions_RunningState) then
					if not combat_action or not combat_action.SimultaneousPlay then
						run_action = false
					else
						for u, state in pairs(CombatActions_RunningState) do
							if state ~= "PostAction" then
								run_action = false
								break
							end
						end
					end
				end
				if run_action then
					table.remove(CombatActions_Waiting, idx)
					if not combat_action or not combat_action.SimultaneousPlay or not g_Combat:GetActiveUnit(unit) then
						g_Combat:SetActiveUnit(unit)
					end
					RunCombatAction(unpack_params(adata))
				else
					idx = idx + 1
					can_start = can_start and combat_action and combat_action.SimultaneousPlay
				end
			end
		end
		if g_Combat then
			g_Combat:CheckEndTurn()
		end
	end)
end

---
--- Checks if the local player can interrupt any combat actions.
---
--- @return boolean true if the local player can interrupt any combat actions, false otherwise
function LocalPlayerCanInterrupt()
	if LocalPlayer_InterruptSent then
		return false
	end
	local units = Selection
	for i, unit in ipairs(units or empty_table) do
		if unit.actions_nettravel > 0 then
			return true
		end
		if g_Combat then
			if HasCombatActionInProgress(unit) then
				return true
			end
		else
			if unit.action_interrupt_callback and not unit.interrupt_callback then
				return true
			end
		end
	end
	return false
end

---
--- Interrupts all player actions for the specified player.
---
--- @param player_id number The ID of the player whose actions should be interrupted.
---
function InterruptPlayerActions(player_id)
	local mask = NetPlayerControlMask(player_id)
	local side = NetPlayerSide(player_id)
	CancelWaitingActions(mask)
	local team_idx = table.find(g_Teams, "side", side)
	local units = team_idx and g_Teams[team_idx].units
	local interrupted
	for i, unit in ipairs(units or empty_table) do
		if unit:IsControlledBy(mask) then
			unit:Interrupt()
			interrupted = true
		end
	end
	ShowTacticalNotification("actionInterrupted")
	if interrupted and g_Combat and GetInGameInterfaceMode() ~= "IModeCombatMovement" then
		SetInGameInterfaceMode("IModeCombatMovement")
	end
end

---
--- Checks if the specified unit has a combat action in progress.
---
--- @param unit table The unit to check for a combat action in progress.
--- @return boolean true if the unit has a combat action in progress, false otherwise.
function HasCombatActionInProgress(unit)
	return (CombatActions_RunningState[unit] or HasCombatActionWaiting(unit) or unit.move_attack_in_progress) and IsValid(unit) and not unit:IsDead()
end

---
--- Checks if the specified unit has a combat action waiting.
---
--- @param unit table The unit to check for a combat action waiting.
--- @return boolean true if the unit has a combat action waiting, false otherwise.
function HasCombatActionWaiting(unit)
	--this function is sync, it represents the synced state of a unit on all clients
	if table.find(CombatActions_Waiting, 2, unit) then
		return true
	end
	return false
end

---
--- Waits for all combat actions of the specified unit to end.
---
--- @param unit table The unit to wait for combat actions to end.
function WaitCombatActionsEnd(unit)
	while HasCombatActionInProgress(unit) do
		WaitMsg("CombatActionEnd", 200)
	end
end

---
--- Waits for the specified unit's combat action to reach the "PostAction" state.
---
--- @param unit table The unit to wait for the combat action to reach the "PostAction" state.
function WaitCombatActionsPostAction(unit)
	while HasCombatActionInProgress(unit) and CombatActions_RunningState[unit] ~= "PostAction" do
		WaitMsg("CombatPostAction", 200)
	end
end

---
--- Checks if any combat action is currently in progress.
---
--- @param check_all boolean If true, checks all units for combat actions in progress. If false, only checks the units with a running state.
--- @return boolean true if any combat action is in progress, false otherwise.
function HasAnyCombatActionInProgress(check_all)
	if #CombatActions_Waiting > 0 then
		return true
	end
	if check_all then
		for _, u in ipairs(g_Units) do
			if HasCombatActionInProgress(u) then
				return true
			end
		end
	else
		for u, state in pairs(CombatActions_RunningState) do
			if HasCombatActionInProgress(u) then
				return true
			end
		end
	end
	return false
end

---
--- Checks if any attack action is currently in progress.
---
--- @return boolean true if any attack action is in progress, false otherwise.
function HasAnyAttackActionInProgress()
	for _, adata in ipairs(CombatActions_Waiting) do
		local action_id, unit, ap = unpack_params(adata, 1, 3)
		local action = CombatActions[action_id]
		if action.ActionType == "Ranged Attack" or action.ActionType == "Melee Attack" then
			return true
		end
	end
	for u, state in pairs(CombatActions_RunningState) do
		local action_id = CombatActions_UnitAction[u]
		if HasCombatActionInProgress(u) and action_id then
			local action = CombatActions[action_id]
			if action and (action.ActionType == "Ranged Attack" or action.ActionType == "Melee Attack") then
				return true
			end
		end
	end
end

---
--- Waits for all combat actions to end.
---
function WaitAllCombatActionsEnd()
	while HasAnyCombatActionInProgress() do
		WaitMsg("CombatActionEnd", 200)
	end
end

---
--- Waits for all other combat actions to end.
---
--- @param unit table The unit to wait for other combat actions to end.
function WaitOtherCombatActionsEnd(unit)
	while true do
		local wait
		for u, state in pairs(CombatActions_RunningState) do
			if u ~= unit and HasCombatActionInProgress(u) then
				wait = true
				break
			end
		end
		if not wait then
			return
		end
		WaitMsg("CombatActionEnd", 200)
	end
end

---
--- Interrupts the combat actions of units controlled by the player.
---
--- @param unit table The unit whose combat actions should be interrupted.
function CombatActionInterruped(unit)
	if g_Combat and unit.team and unit.team.control == "UI" then
		-- interrupt the other ordered actions by players that controll this unit
		local mask = 0
		for player_id = 1, Max(1, #netGamePlayers) do
			local pmask = NetPlayerControlMask(player_id)
			if unit:IsControlledBy(pmask) then
				mask = mask | pmask
			end
		end
		CancelWaitingActions(mask)
	end
end

---
--- Cancels all waiting combat actions controlled by the specified player mask.
---
--- @param mask number The player control mask to cancel actions for.
---
function CancelWaitingActions(mask)
	for i = #CombatActions_Waiting, 1, -1 do
		local adata = CombatActions_Waiting[i]
		local action_id, unit, ap = unpack_params(adata, 1, 3)
		if unit and unit:IsControlledBy(mask) then
			unit:GainAP(ap)
			table.remove(CombatActions_Waiting, i)
			Msg("CombatActionCanceled", unpack_params(adata))
		end
	end
end

---
--- Cancels all waiting combat actions for the specified unit.
---
--- @param unit table The unit whose waiting combat actions should be cancelled.
---
function CancelUnitWaitingActions(unit)
	for i = #CombatActions_Waiting, 1, -1 do
		local adata = CombatActions_Waiting[i]
		local action_id, u, ap = unpack_params(adata, 1, 3)
		if u == unit then
			unit:GainAP(ap)
			table.remove(CombatActions_Waiting, i)
			Msg("CombatActionCanceled", unpack_params(adata))
		end
	end
end

function OnMsg:TurnEnded()
	assert(not next(CombatActions_RunningState))
	CombatActions_Waiting = {}
	CombatActions_RunningState = {}
	if CombatSaveGameRequest then
		MPSaveGame()
	end
end

---
--- Teleports the specified unit to the given location.
---
--- @param unit table The unit to teleport.
--- @param ap number The amount of action points to spend on the teleport.
--- @param ... any The location parameters to pass to the unit's Teleport command.
---
function CustomCombatActions.Teleport(unit, ap, ...)
	unit:SetCommand("Teleport", ...)
end

---
--- Determines if a combat action change is needed and what type of change is required.
---
--- @param required_mode table The required interface mode for the action.
--- @param action table The combat action.
--- @param unit table The unit performing the action.
--- @param target table The target of the action.
--- @param freeAim boolean Whether the action is in free aim mode.
---
--- @return boolean|string,table,table Whether a change is needed, the current interface mode dialog, and the target.
---
function CombatActionChangeNeededTryRetainTarget(required_mode, action, unit, target, freeAim)
	local targetParamOrDefault = target or action:GetDefaultTarget(unit)

	local dlg = GetInGameInterfaceModeDlg()
	local iModeMismatch = not IsKindOf(dlg, "IModeCombatAttackBase") or not IsKindOf(dlg, required_mode)
	if iModeMismatch then return "change-mode", dlg, targetParamOrDefault end
	
	-- If the action and target match, no change needed.
	-- "not target" will detect pressing the action key twice.
	local actionCameraSame = action.ActionCamera == dlg.action.ActionCamera
	if dlg.action == action and actionCameraSame and (not target or target == dlg.target) then return false, dlg, target end
	
	-- Changing actions within the same interface mode, with no defined target means
	-- this click came from pressing another action key. Check if the current target can be maintained.
	if not target and dlg.target and IsKindOf(dlg, "IModeCombatAttack") then
		local validTargets = action:GetTargets({unit})
		if table.find(validTargets, dlg.target) then
			if not actionCameraSame then
				return true, dlg, dlg.target
			end

			return "change-action", dlg, dlg.target
		end
	end
	
	if freeAim ~= dlg.context.free_aim then
		return "change-free-aim", dlg
	end

	return true, dlg, targetParamOrDefault
end

ActionsWhichHighlightTargets = {
	"Interact",
	"Lockpick",
	"Cut",
	"Break"
}

---
--- Handles the choice of interactable targets for a combat action.
---
--- @param self table The combat action.
--- @param units table The units performing the action.
--- @param args table The arguments for the action.
---
--- If the current interface mode is `IModeCommonUnitControl`, this function will:
--- - Get the targets for the combat action.
--- - Show a combat action target choice UI, highlighting the targets.
--- - Set the `OnDelete` callback for the UI to unhighlight the targets.
---
--- If the current interface mode is not `IModeCommonUnitControl`, this function will simply execute the combat action.
---
function CombatActionInteractablesChoice(self, units, args)
	local mode_dlg = GetInGameInterfaceModeDlg()
	if IsKindOf(mode_dlg, "IModeCommonUnitControl") then
		local targets = self:GetTargets(units)
		local combatChoiceUI = mode_dlg:ShowCombatActionTargetChoice(self, units, targets)
		if combatChoiceUI then
			combatChoiceUI.OnDelete = function(self)
				for i, t in ipairs(targets) do
					t:HighlightIntensely(false, "actionsChoice")
				end
			end
		end
	else
		self:Execute(units[1], args)
	end
end

if FirstLoad then
CombatActionStartThread = false
end

---
--- Starts a combat action for the given units.
---
--- @param self table The combat action.
--- @param units table The units performing the action.
--- @param args table The arguments for the action.
--- @param mode string The interface mode for the combat action.
--- @param noChangeAction boolean Whether to prevent changing the action.
---
--- This function handles the start of a combat action, including:
--- - Checking if the unit can perform the action.
--- - Determining if free aim mode is required.
--- - Handling the case where there are no valid targets in range.
--- - Changing the interface mode to the appropriate combat mode.
--- - Synchronizing the action with the server.
---
function CombatActionAttackStart(self, units, args, mode, noChangeAction)
	mode = mode or "IModeCombatAttackBase"
	local unit = units[1]
	if IsValidThread(CombatActionStartThread) then
		DeleteThread(CombatActionStartThread)
	end
	CombatActionStartThread = CreateRealTimeThread(function()
		if HasCombatActionInProgress(unit) then
			return
		end
		if g_Combat then
			WaitCombatActionsEnd(unit)
		end
		if not IsValid(unit) or unit:IsDead() or not unit:CanBeControlled() then
			return
		end
		if PlayerActionPending(unit) then
			return
		end
		if not g_Combat and not unit:IsIdleCommand() then
			NetSyncEvent("InterruptCommand", unit, "Idle")
		end

		local target = args and args.target
		local freeAim = args and args.free_aim or not UIAnyEnemyAttackGood(self)
		if freeAim and not g_Combat and self.basicAttack and self.ActionType == "Melee Attack" then
			local action = GetMeleeAttackAction(self, unit)
			freeAim = action.id ~= "CancelMark"
		end
		freeAim = freeAim and (self.id ~= "CancelMark")
		if not self.IsTargetableAttack and IsValid(target) and freeAim then
			local ap = self:GetAPCost(unit, args)
			NetStartCombatAction(self.id, unit, ap, args)
			return
		end
		
		local isFreeAimMode = mode == "IModeCombatAttack" or mode == "IModeCombatMelee" 
		if not isFreeAimMode and mode == "IModeCombatAreaAim" then
			local weapon = self:GetAttackWeapons(unit)
			isFreeAimMode = not IsOverwatchAction(self.id) and IsKindOf(weapon, "Firearm") and not IsKindOfClasses(weapon, "HeavyWeapon", "FlareGun")
		end
		isFreeAimMode = isFreeAimMode and self.id ~= "Bandage"
		
		if isFreeAimMode and not self.RequireTargets and (not target) and freeAim then
			CreateRealTimeThread(function()
				local prompt = "ok"
				if (not args or not args.free_aim) and g_Combat then
					local modeDlg = GetInGameInterfaceModeDlg()
					local text = T(871884306956, "There are no valid enemy targets in range. You can target the attack freely instead. <em>Free Aim</em> ranged attacks consume AP normally and can target anything, even empty spaces.")
					if mode == "IModeCombatMelee" then
						text = T(306912792200, "There are no valid enemy targets in range. If you wish to attack a non-hostile target, you can target the attack freely instead. <em>Free Aim</em> melee attacks consume AP normally and can target any adjacent unit.")
					end
					local choiceUI = CreateQuestionBox(
						modeDlg,
						T(333335408841, "Free Aim"),
						text,
						T(333335408841, "Free Aim"),
						T(1000246, "Cancel"))
					prompt = choiceUI:Wait()
				end
				if prompt == "ok" then
					args = args or {}
					args.free_aim = true
					CombatActionAttackStart(self, units, args, "IModeCombatFreeAim", noChangeAction)
				end
			end)
			return
		elseif mode == "IModeCombatMelee" and target then
			local weapon = self:GetAttackWeapons(unit)
			local ok, reason = unit:CanAttack(target, weapon, self)
			if not ok then
				ReportAttackError(args.target, reason)
				return
			end
			--if not IsMeleeRangeTarget(unit, nil, nil, target) then			
				--ReportAttackError(args.target, AttackDisableReasons.CantReach)
				--return
			--end
		end
		
		-- Check what actually needs switching
		local changeNeeded, dlg, targetGiven = CombatActionChangeNeededTryRetainTarget(mode, self, unit, target, freeAim)
		if mode == "IModeCombatAttack" and changeNeeded then
			target = targetGiven
		end

		-- Clicking a single target skill twice will cause the attack to proceed
		if not changeNeeded then
			local abilityWhichAttacksWhenClickedAgain = true
			if self.AimType == "cone" or self.AimType == "parabola aoe" then
				abilityWhichAttacksWhenClickedAgain = false
			end
			if not abilityWhichAttacksWhenClickedAgain then
				return
			end
			
			if dlg.crosshair then
				dlg.crosshair:Attack()
			else
				dlg:Confirm()
			end
			return
		end
		
		-- This should prob have something to do with action.RequireTarget
		-- but that isn't a reliable indicator.
		if mode == "IModeCombatAttack" and not target then return end
		
		-- Changing actions requires notifying the dialog to exit quietly.
		if changeNeeded == "change-action" then
			dlg.context.changing_action = true
		end
		
		-- It is possible for the unit to have been deselected in all our waiting.
		-- Of for the action to have been disabled.
		local state = self:GetUIState(units)
		if not SelectedObj or state ~= "enabled" then
			return
		end

		if mode == "IModeCombatAttack" and self.id ~= "MarkTarget" then
			-- The unit might step out of cover, changing their position. We want to calculate the action camera from
			-- the position where the unit will be rather than where it is, as it could show an angle we dont want (ex. crosshair on unit)
			assert(IsValid(unit))
			
			local action = self
			if self.group == "FiringModeMetaAction" then
				action = GetUnitDefaultFiringModeActionFromMetaAction(unit, self)
			end
			
			NetSyncEvent("Aim", unit, action.id, target)
			if not IsActivePaused() then
				WaitMsg("AimIdleLoop", 800)
			end
		end
		
		-- Patch selection outside of combat to remove multiselection
		-- We're not doing this through SelectObj as the selection changed msg
		-- will cancel the action.
		if not g_Combat then
			for i, u in ipairs(Selection) do
				if u ~= unit then
					HandleMovementTileContour({u})
				end
			end
			Selection = { unit }
		end

		local modeDlg = GetInGameInterfaceModeDlg()
		modeDlg.dont_return_camera_on_close = true
		SetInGameInterfaceMode(mode, {
			action = self,
			attacker = unit,
			target = target,
			aim = args and args.aim,
			free_aim = freeAim,
			changing_action = changeNeeded == "change-action"
		})
	end)
end

---
--- Gets the valid tiles for a melee combat action.
---
--- @param attacker table The attacking unit.
--- @param target table The target unit.
--- @return table The valid tiles for the melee combat action.
function MeleeCombatActionGetValidTiles(attacker, target)
	local tiles
	if g_Combat then
		local attacker_stance = attacker.species == "Human" and "Standing" or nil
		local combatPath = GetCombatPath(attacker, attacker_stance)
		tiles = combatPath:GetReachableMeleeRangePositions(target, true)
	else
		tiles = GetMeleeRangePositions(attacker, target, nil, true)
	end
	return tiles
end

-- Used to get the cost of moving to a target in melee abilities.
---
--- Calculates the action cost for a melee combat action, taking into account the move cost and stance change cost.
---
--- @param unit table The attacking unit.
--- @param args table The arguments for the combat action, including the target and optional stance.
--- @param target table The target unit.
--- @param ap number The base action points cost.
--- @return number The total action points cost, including move and stance change.
--- @return number The base action points cost.
--- @return string The stance to use for the action.
---
function CombatActionMeleeActionCost(unit, args, target, ap)
	-- ignore move part when pos == false
	-- this happens when validating the cost in multiplayer
	local stance = args and args.stance
	local goto_pos = args and args.goto_pos
	if goto_pos == false or (goto_pos == nil and target == unit) then
		return ap, ap, stance
	end

	if not IsValid(target) then return -1, ap end

	if goto_pos == nil then
		goto_pos = unit:GetClosestMeleeRangePos(target, nil, stance)
		if not goto_pos then
			return -1, ap
		end
	end
	local goto_ap = 0
	local stance_ap = 0
	if stance and stance ~= unit.stance then
		stance_ap = unit:GetStanceToStanceAP(args.stance)
	end
	
	if goto_pos ~= SnapToVoxel(unit:GetPos()) then
		goto_ap = CombatActions.Move:GetAPCost(unit, { goto_pos = goto_pos, stance = args and args.stance })
		if not goto_ap or goto_ap < 0 then
			return -1, ap
		end
		goto_ap = Max(0, goto_ap - Max(0, unit.free_move_ap))
	end
	return ap + goto_ap + stance_ap, ap, stance
end

---
--- Calculates the action cost for an interaction combat action, taking into account the move cost.
---
--- @param self table The combat action instance.
--- @param unit table The attacking unit.
--- @param args table The arguments for the combat action, including the target and optional goto position.
--- @return number The total action points cost, including move.
--- @return number The base action points cost.
---
function CombatActionInteractionGetCost(self, unit, args)
	if not g_Combat or args and args.skip_cost then
		return 0, 0
	end

	local target = args and args.target
	local goto_ap = 0
	if args and args.goto_pos ~= false then
		local pos = args.goto_pos or target and unit:GetInteractionPosWith(target)
		goto_ap = pos and CombatActions.Move:GetAPCost(unit, { goto_pos = pos })
		args.ap_cost_breakdown = { move_cost = goto_ap }
		if not goto_ap or goto_ap < 0 then
			return -1, 0
		end
		--goto_ap = Max(0, goto_ap - Max(0, unit.free_move_ap))
	end
	
	local ap
	if args and args.override_ap_cost then
		ap = args.override_ap_cost
	elseif IsKindOf(target, "CustomInteractable") then
		ap = target.ActionPoints
	else
		ap = self.ActionPoints
	end

	return goto_ap + ap, ap
end

---
--- Executes a combat action with a move.
---
--- @param self table The combat action instance.
--- @param unit table The attacking unit.
--- @param args table The arguments for the combat action, including the target and optional goto position.
---
function CombatActionExecuteWithMove(self, unit, args)
	if not args or not args.target then return end
	if #unit > 0 then
		unit = ChooseClosestObject(unit, args.target)
	end
	if not args.goto_pos then
		args.goto_pos = unit:GetInteractionPosWith(args.target)
	end
	args.goto_ap = args.goto_pos ~= SnapToVoxel(unit:GetPos()) and CombatActions.Move:GetAPCost(unit, args) or 0
	local ap, action_ap = self:GetAPCost(unit, args)
	NetStartCombatAction(self.id, unit, ap, args)
end

---
--- Checks if a combat action is busy for the given unit.
---
--- This function checks if the unit has a combat action waiting, is not in an idle command, or has actions being networked.
---
--- @param action table The combat action instance.
--- @param unit table The unit to check.
--- @return boolean Whether the unit is busy with a combat action.
---
function CombatActionIsBusy(action, unit)
	--this func is not sync, it checks local not yet synced actions as well
	return HasCombatActionWaiting(unit) or not unit:IsIdleCommand() or unit.actions_nettravel > 0 
end

---
--- Gets a list of attackable enemies for the given combat action.
---
--- This function retrieves the list of visible enemies for the attacker, and checks if each enemy can be attacked
--- using the specified weapon and combat action. The list of attackable enemies is returned.
---
--- @param self table The combat action instance.
--- @param attacker table The attacking unit.
--- @param weapon table The weapon to use for the attack.
--- @param filter function An optional filter function to apply to the targets.
--- @param ... any Additional arguments to pass to the filter function.
--- @return table A list of attackable enemies.
---
function CombatActionGetAttackableEnemies(self, attacker, weapon, filter, ...)
	local attackable = {}
	if not attacker or (self.ActionType ~= "Melee Attack" and self.ActionType ~= "Ranged Attack") then 
		return attackable 
	end
	local visibleTargets = attacker:GetVisibleEnemies()
	local weps = weapon or self:GetAttackWeapons(attacker)
	for i, t in ipairs(visibleTargets) do
		if IsValid(t) and (not filter or filter(t, ...)) then
			local canAttack, err = attacker:CanAttack(t, weps, self, 0)
			if canAttack then
				attackable[#attackable + 1] = t
			end
		end
	end
	return attackable
end

---
--- Gets the first attackable enemy for the given combat action.
---
--- This function retrieves the list of visible enemies for the attacker, and checks if each enemy can be attacked
--- using the specified weapon and combat action. The first attackable enemy is returned.
---
--- @param action table The combat action instance.
--- @param attacker table The attacking unit.
--- @param weapon table The weapon to use for the attack.
--- @param filter function An optional filter function to apply to the targets.
--- @param ... any Additional arguments to pass to the filter function.
--- @return table|nil The first attackable enemy, or nil if no enemy is attackable.
---
function CombatActionGetOneAttackableEnemy(action, attacker, weapon, filter, ...)
	if not IsValid(attacker) or (action.ActionType ~= "Melee Attack" and action.ActionType ~= "Ranged Attack") then 
		return 
	end
	local visibleTargets = attacker:GetVisibleEnemies()
	weapon = weapon or action:GetAttackWeapons(attacker)
	for i, t in ipairs(visibleTargets) do
		if IsValid(t) and (not filter or filter(t, ...)) then
			local canAttack, err = attacker:CanAttack(t, weapon, action, 0)
			if canAttack then
				return t
			end
		end
	end
end

--- Gets the UI state for a combat action that uses firing modes.
---
--- This function first calls `CombatActionGenericAttackGetUIState` to get the base UI state for the combat action.
--- If the base state is "enabled", it then checks the available firing modes for the unit and returns "enabled" if any of the firing mode actions are enabled.
--- If no firing mode actions are enabled, it returns "disabled".
---
--- @param self table The combat action instance.
--- @param units table A list of units involved in the combat action.
--- @param args table Optional arguments to pass to the combat action.
--- @return string The UI state for the combat action, either "enabled", "disabled", or "hidden".
--- @return string|nil The reason the action is disabled, if applicable.
function CombatActionFiringMetaGetUIState(self, units, args)
	local actionState, err = CombatActionGenericAttackGetUIState(self, units, args)
	if actionState ~= "enabled" then return actionState, err end
	
	-- Any firing mode should be enabled
	local unit = units[1]
	local _, firingModes = unit:ResolveDefaultFiringModeAction(self)
	for i, fmAction in ipairs(firingModes) do
		local actionEnabled = fmAction:GetUIState(units, args)
		if actionEnabled == "enabled" then return "enabled" end
	end
	
	return "disabled"
end

---
--- Gets the UI state for a combat action based on the current game state and the unit's abilities.
---
--- This function first checks if the game is paused and not actively paused, in which case it returns "disabled" with the reason "InvalidTarget".
--- It then checks if the unit has a signature recharge, and if so, returns "disabled" with the reason "SignatureRecharge" or "SignatureRechargeOnKill" depending on the recharge type.
--- Next, it checks if the unit has enough AP to perform the action, and if not, returns "disabled" with the reason "NoAP".
--- If the action has a target specified, it checks if the unit can attack that target, and returns "enabled" if so, or "disabled" with the error reason.
--- If the action does not require targets, it checks if the unit can attack without a target, and returns "enabled" if so, or "disabled" with the error reason.
--- If the action requires a target and none is available, it returns "disabled" with the reason "NoTarget".
---
--- @param self table The combat action instance.
--- @param units table A list of units involved in the combat action.
--- @param args table Optional arguments to pass to the combat action.
--- @return string The UI state for the combat action, either "enabled", "disabled", or "hidden".
--- @return string|nil The reason the action is disabled, if applicable.
function CombatActionGenericAttackGetUIState(self, units, args)
	if netInGame and (IsPaused() and not IsActivePaused()) then
		return "disabled", AttackDisableReasons.InvalidTarget
	end
	local unit = units[1]
	
	local recharge = unit:GetSignatureRecharge(self.id)
	if recharge then
		if recharge.on_kill then
			return "disabled", AttackDisableReasons.SignatureRechargeOnKill
		end
		return "disabled", AttackDisableReasons.SignatureRecharge
	end
	
	if not (args and args.skip_ap_check) then
		local cost = self:GetAPCost(unit, args)
		if cost < 0 then return "hidden" end
		if not unit:UIHasAP(cost) then return "disabled", GetUnitNoApReason(unit) end
	end

	local wep = args and args.weapon or self:GetAttackWeapons(unit)
	if args and args.target then
		local canAttack, err = unit:CanAttack(
			args.target,
			wep,
			self,
			args and args.aim or 0,
			args and args.goto_pos,
			not "skip_cost",
			args and args.free_aim
		)
		if not canAttack then return "disabled", err end
		return "enabled"
	end
	
	if not self.RequireTargets then
		local canAttack, err = unit:CanAttack(false, wep, self, args and args.aim or 0, nil, args and args.skip_ap_check)
		if not canAttack then return "disabled", err end
		return "enabled"
	end

	local target = self:GetAnyTarget(units)
	if not target then
		return "disabled", AttackDisableReasons.NoTarget
	end
	return "enabled"
end

--- Calculates the damage for an area-of-effect (AOE) attack.
---
--- @param self CombatAction The combat action instance.
--- @param unit Unit The unit performing the attack.
--- @param base_damage_mod number An optional modifier to the base damage.
--- @return number The total damage.
--- @return number The base damage.
--- @return number The bonus damage.
--- @return table The area attack parameters.
function CombatActionsAOEGenericDamageCalculation(self, unit, base_damage_mod)
	local weapon = self:GetAttackWeapons(unit)
	if not weapon then return 0 end

	local params = weapon:GetAreaAttackParams(self.id, unit)
	local base = unit:GetBaseDamage(weapon)
	base = MulDivRound(base, 100 + (base_damage_mod or 0), 100)
	local mod = params.damage_mod + params.attribute_bonus
	local damage = MulDivRound(base, mod, 100)
	local bonus = MulDivRound(base, params.attribute_bonus, 100)
	base = damage - bonus

	return damage, base, bonus, params
end

---
--- Calculates the generic damage for an attack.
---
--- @param self CombatAction The combat action instance.
--- @param unit Unit The unit performing the attack.
--- @param args table Optional arguments, including:
---   - weapon: the weapon to use for the attack
---   - aim: the aim value to use for the attack
---   - goto_pos: the position to move to for the attack
--- @return number The base damage.
--- @return number The bonus damage.
--- @return number The critical chance.
--- @return table The attack parameters, including:
---   - critChance: the critical chance
---   - min: the minimum damage
---   - max: the maximum damage
---
function CombatActionsAttackGenericDamageCalculation(self, unit, args)
	local weapon = args and args.weapon or self:GetAttackWeapons(unit)
	if not weapon then 
		return 0, 0, 0, { critChance = 0, min = 0, max = 0 }
	end
	if not IsKindOf(unit, "Unit") then
		local base = unit:GetBaseDamage(weapon)
		return base, base
	end
	local args = args or {}
	if not args.aim then
		local dlg = GetInGameInterfaceModeDlg() 
		if IsKindOf(dlg, "IModeCombatAttackBase") and dlg.crosshair then
			args.aim = dlg.crosshair.aim
		end
	end
	local critChance = unit:CalcCritChance(weapon, GetCurrentUITarget(), self, args, args.goto_pos)
	local base = unit:GetBaseDamage(weapon)
	local hit = {
		weapon = weapon,
		critical = critChance,
		actionType = self.ActionType,
		ignore_obj_damage_mod = true,
	}
	weapon:PrecalcDamageAndStatusEffects(unit, false, unit:GetPos(), base, hit)
	base = hit.damage or base
	
	return base, base, 0, { critChance = critChance, min = base, max = base }
end

---
--- Calculates the dispersion area for an attack and checks for any units within that area that may be affected.
---
--- @param hits table A table of hit results to be updated with any additional units affected by the dispersion.
--- @param weapon Weapon The weapon used for the attack.
--- @param attacker Unit The unit performing the attack.
--- @param target Unit|point The target of the attack.
--- @return table The updated hits table.
---
function CombatActionAttackResultsDisperseWarning(hits, weapon, attacker, target)
	local attacker_pos = attacker:GetPos()
	local target_pos = IsPoint(target) and target or target:GetPos()
	local distance = attacker_pos:Dist(target_pos)
	local dispersion = weapon:GetMaxDispersion(distance)
	local minz = terrain.GetHeight(attacker_pos) + const.SlabSizeZ / 2
	if not attacker_pos:IsValidZ() or attacker_pos:z() < minz then
		attacker_pos = attacker_pos:SetZ(minz)
	end
	
	local base_shape = {}
	local vAT = attacker_pos - target_pos
	local perpendicular = point(vAT:y(), -vAT:x())
	local side_a = target_pos + SetLen(perpendicular, dispersion)
	local side_b = target_pos - SetLen(perpendicular, dispersion)
	base_shape[#base_shape + 1] = attacker_pos
	base_shape[#base_shape + 1] = side_a
	base_shape[#base_shape + 1] = side_b
	perpendicular = point(perpendicular:y(), -perpendicular:x())
	base_shape[#base_shape + 1] = side_a + SetLen(perpendicular, distance * 2)
	base_shape[#base_shape + 1] = side_b + SetLen(perpendicular, distance * 2)
	
	local vertices = {
		point(-const.SlabSizeX / 2, -const.SlabSizeY / 2),
		point( const.SlabSizeX / 2, -const.SlabSizeY / 2),
		point( const.SlabSizeX / 2,  const.SlabSizeY / 2),
		point(-const.SlabSizeX / 2,  const.SlabSizeY / 2),
	}
	local ms_points = {}
	for _, pt in ipairs(base_shape) do
		for _, vert in ipairs(vertices) do
			ms_points[#ms_points + 1] = pt + vert
		end
	end
	
	local ms_shape = ConvexHull2D(ms_points)
	local attacker_team = attacker.team
	for i, u in ipairs(g_Units) do
		if u == attacker or not u.team or u.team:IsEnemySide(attacker_team) then goto continue end
		if IsPointInsidePoly2D(u:GetPos(), ms_shape) then
			hits[#hits + 1] = {
				obj = u,
				damage = 0,
				conditional_damage = 0,
				ignore_armor = true
			}
		end
		::continue::
	end
	return hits
end

---
--- Appends a "Free Aim" suffix to the name of a combat action if the player can control the unit and there are visible enemies in range.
---
--- @param action table The combat action object.
--- @param unit table The unit performing the action.
--- @param name string The original name of the combat action.
--- @return string The updated name of the combat action.
---
function CombatActionsAppendFreeAimActionName(action, unit, name)
	if not unit:CanBeControlled() then
		return name
	end

	if not UIAnyEnemyAttackGood() then
		name = name .. T(587521561381, " (Free Aim)")
	end
	return name
end

---
--- Appends a "Free Aim" description to the given action description if the player can control the unit and there are visible enemies in range.
---
--- @param action table The combat action object.
--- @param unit table The unit performing the action.
--- @param descr string The original description of the combat action.
--- @param ignore_check boolean Whether to ignore the check for visible enemies.
--- @return string The updated description of the combat action.
---
function CombatActionsAppendFreeAimDescription(action, unit, descr, ignore_check)
	if ignore_check or UIAnyEnemyAttackGood() then
		if GetUIStyleGamepad() then
			local image_path, scale = GetPlatformSpecificImagePath("LeftThumbClick")
			local image_path2, scale2 = GetPlatformSpecificImagePath("RightTrigger")
			local imageCombined = Untranslated("<image " .. image_path2 .. ">+<image " .. image_path .. ">")
			descr = descr .. T{714791806470, "<newline><newline><flavor><shortcut> Free Aim Mode</flavor>", shortcut = imageCombined}
		else
			local text = GetShortcutButtonT("actionFreeAim")
			descr = descr .. T{434227846947, "<newline><newline><flavor>[<shortcut>] Free Aim Mode</flavor>", shortcut = text}
		end
	else
		descr = descr .. T(636120454494, "<newline><newline><flavor>Free Aim - no visible enemies in range</flavor>")
	end
	return descr
end

---
--- Enters free aim mode with the unit's default combat action.
---
--- If the mouse is over an action button, the action from that button is used instead of the unit's default attack action.
---
--- @param unit table The unit to enter free aim mode for.
---
function EnterFreeAimWithDefaultCombatAction(unit)
	-- If the mouse is over an action button, take its action instead.
	local defaultAction
	local combatActions = GetInGameInterfaceModeDlg()
	combatActions = combatActions and combatActions:ResolveId("idCombatActionsContainer")
	if combatActions then
		for i, b in ipairs(combatActions) do
			if b.rollover then
				defaultAction = b.context.action
				break
			end
		end
	end

	if not defaultAction then
		defaultAction = unit:GetDefaultAttackAction()--("ranged")
	end
	
	if defaultAction:GetUIState({unit}) ~= "enabled" then return end
	defaultAction:UIBegin({unit}, {free_aim = true})
end

--- Plays a custom error sound or animation when the given combat action is not available.
---
--- @param action table The combat action that is not available.
--- @param unit table The unit that attempted to use the combat action.
function CombatActionPlayCustomError(action, unit)
	--local _, err = action:GetUIState({unit})
	--nop ph
end

---
--- Generates a description for a grenade combat action.
---
--- @param action table The combat action for the grenade.
--- @param units table The units affected by the grenade.
--- @return string The description for the grenade combat action.
---
function CombatActionGrenadeDescription(action, units)
	local baseDescription = T(519947740930, "Affects a designated area.")
	
	local unit = units[1]
	local weapon = action:GetAttackWeapons(unit)
	if not weapon then return baseDescription end
	
	if weapon:HasMember("GetCustomActionDescription") then
		local descr = weapon:GetCustomActionDescription(action, units)
		if descr and descr ~= "" then
			return descr
		end
	end

	local base = unit:GetBaseDamage(weapon)
	local bonus = GetGrenadeDamageBonus(unit)
	local damage = MulDivRound(base, 100 + bonus, 100)
	local text = T{baseDescription, damage = damage, basedamage = base, bonusdamage = damage - base}
	if (weapon.AdditionalHint or "") ~= "" then
		text = text  .. "<newline>" .. weapon.AdditionalHint
	end
	return text
end


---
--- Gets the default firing mode action for the given unit and meta action.
---
--- @param unit table The unit to get the default firing mode action for.
--- @param metaAction table The meta action to get the default firing mode action for.
--- @param nonUnitDefault boolean If true, returns the first action in the list instead of the unit's default.
--- @return table The default firing mode action, or the first action in the list if `nonUnitDefault` is true.
--- @return table The list of actions.
---
function GetUnitDefaultFiringModeActionFromMetaAction(unit, metaAction, nonUnitDefault)
	local def_id, actions = unit:ResolveDefaultFiringModeAction(metaAction, true)
	if nonUnitDefault then
		return actions and actions[1], actions
	end
	return CombatActions[def_id], actions
end

local dev_shortcuts

---
--- Strips developer shortcuts from the given action.
---
--- This function is only executed when the game is in developer mode. It removes any
--- developer-specific shortcuts from the action, such as those defined in the
--- `XShortcutsTarget` table, to prevent them from being displayed in the UI.
---
--- @param action table The combat action to strip developer shortcuts from.
---
function StripDeveloperShortcuts(action)
	if Platform.developer then
		if not dev_shortcuts then
			dev_shortcuts = {}
			for _, action in ipairs(XShortcutsTarget:GetActions()) do
				if not action.ActionId:starts_with("combatAction") and action.ActionMode ~= "Editor" then
					dev_shortcuts[action.ActionShortcut] = true
					dev_shortcuts[action.ActionShortcut2] = true
				end
			end
		end
		
		local s1, s2, sg = action.ActionShortcut, action.ActionShortcut2, action.ActionGamepad
		if s1 and s1 ~= "" and dev_shortcuts[s1] then s1 = nil end
		if s2 and s2 ~= "" and dev_shortcuts[s2] then s2 = nil end
		action:SetActionShortcuts(s1, s2, sg)
	end
end

---
--- Gets the weapon set that is the opposite of the given weapon set.
---
--- @param currentSet string The current weapon set, either "Handheld A" or "Handheld B".
--- @return string The opposite weapon set.
---
function GetOtherWeaponSet(currentSet)
	if currentSet == "Handheld A" then return "Handheld B" end
	if currentSet == "Handheld B" then return "Handheld A" end
	-- ???
	return "Handheld A"
end

---
--- Gets the display name for a weapon change action.
---
--- This function is used to retrieve the display name for a weapon change action, which is
--- displayed in the UI when the player switches between different weapon sets. It iterates
--- through the items in the opposite weapon set of the currently equipped weapons, and
--- collects the display names of any weapons found. If no weapons are found, it uses the
--- display name of the unarmed weapon.
---
--- @param unit table The unit whose weapon change action display name is being retrieved.
--- @return string The display name for the weapon change action.
---
function GetWeaponChangeActionDisplayName(unit)
	local itemTypes = {}
	if unit then
		local otherSet = unit.current_weapon == "Handheld A" and "Handheld B" or "Handheld A"
		unit:ForEachItemInSlot(otherSet, function(item, slot_name, left, top, itemTypes)
			if item:IsWeapon() then
				itemTypes[#itemTypes + 1] = item.DisplayName
			end
		end)
		if #itemTypess == 0 then
			local unarmed_weapon = unit:GetActiveWeapons("UnarmedWeapon")
			itemTypes[#itemTypes + 1] = unarmed_weapon.DisplayName
		end
	end
	local weaponsTxt = table.concat(itemTypes, "/")
	return T{887065293634, "Switch to <weaponsTxt>", weaponsTxt = weaponsTxt}
end

---
--- Gets the weapons for a unit, including the active weapons if they are not in the inventory.
---
--- @param unit table The unit to get the weapons for.
--- @param otherSet boolean Whether to get the weapons from the opposite weapon set.
--- @return table The list of weapons for the unit.
---
function GetUnitWeapons(unit, otherSet)
	if not unit then return empty_table end
	
	local weps = otherSet and GetOtherWeaponSet(unit.current_weapon) or unit.current_weapon
	local items = unit:GetItemsInWeaponSlot(weps)
	if not otherSet then
		-- Things such as manning an emplacement change the active weapon without
		-- being equipped through the inventory. If the active weapon returned is
		-- not present in the inventory, show it instead
		local wep1, wep2 = unit:GetActiveWeapons()
		if (wep1 and not table.find(items, wep1)) or (wep2 and not table.find(items, wep2)) then
			items = { wep1, wep2 }
		end
	end
	
	local anyWeapon = false
	for i, item in ipairs(items) do
		if item:IsWeapon() then
			anyWeapon = true
			break
		end
	end
	if not anyWeapon and #items ~= 2 then
		local unarmed = unit:GetActiveWeapons("UnarmedWeapon")
		table.insert(items, 1, unarmed)
	end
	return items
end

---
--- Checks if a given combat action is valid for an ally target.
---
--- @param action table The combat action to check.
--- @return boolean True if the combat action is valid for an ally target, false otherwise.
---
function IsCombatActionForAlly(action)
end
function IsCombatActionForAlly(action) 
	if not action then return false end
	
	local isActionEnabled = SelectedObj and SelectedObj.ui_actions and SelectedObj.ui_actions
	isActionEnabled = isActionEnabled and isActionEnabled[action.id] == "enabled"
	if not isActionEnabled then return false end

	local targets = action:GetTargets({SelectedObj})
	local allyTargers = GetAllAlliedUnits(SelectedObj)
	for _, target in ipairs(targets) do
		if table.find(allyTargers, target) or target == SelectedObj then
			return true
		end
	end
	
	return false
end

---
--- Checks if a target is valid for a machine gun burst fire combat action.
---
--- @param target table The target to check.
--- @param units table The units performing the combat action.
--- @return boolean True if the target is valid for the machine gun burst fire combat action, false otherwise.
---
function CombatActionTargetFilters.MGBurstFire(target, units)
	local attacker = units[1]
	if #units > 1 then
		units = {attacker}
	end
	local overwatch = g_Overwatch[attacker]
	if overwatch and overwatch.permanent then
		-- only fire in the cone when set
		local angle = overwatch.orient or CalcOrientation(attacker, overwatch.target_pos)
		local los_any = CheckLOSRange(target, attacker, overwatch.dist, attacker.stance, overwatch.cone_angle, angle)
		return los_any
	end	
	return true
end

---
--- Checks if a target is valid for a charge combat action.
---
--- @param target table The target to check.
--- @param attacker table The unit performing the charge action.
--- @param move_ap number The action points available for the charge movement.
--- @param action_id string The ID of the charge action.
--- @return boolean True if the target is valid for the charge combat action, false otherwise.
---
function CombatActionTargetFilters.Charge(target, attacker, move_ap, action_id)
	local goto_pos, _, dist_error, line_error = GetChargeAttackPosition(attacker, target, move_ap, action_id)
	return not dist_error and not line_error and not not goto_pos
end

---
--- Checks if a target is valid for a hyena charge combat action.
---
--- @param target table The target to check.
--- @param attacker table The unit performing the hyena charge action.
--- @param move_ap number The action points available for the hyena charge movement.
--- @param jump_dist number The maximum distance the hyena can jump.
--- @param action_id string The ID of the hyena charge action.
--- @return boolean True if the target is valid for the hyena charge combat action, false otherwise.
---
function CombatActionTargetFilters.HyenaCharge(target, attacker, move_ap, jump_dist, action_id)
	local goto_pos, _, _, dist_error, line_error = GetHyenaChargeAttackPosition(attacker, target, move_ap, jump_dist, action_id)
	return not dist_error and not line_error and not not goto_pos
end

---
--- Checks if a target is within a specified range of the attacker for a knife throw combat action.
---
--- @param target table The target to check.
--- @param attacker table The unit performing the knife throw action.
--- @param range number The maximum range for the knife throw.
--- @return boolean True if the target is within the specified range, false otherwise.
---
function CombatActionTargetFilters.KnifeThrow(target, attacker, range)
	return IsCloser(attacker, target, range + 1)
end

---
--- Checks if a target is valid for a melee attack combat action.
---
--- @param target table The target to check.
--- @param attacker table The unit performing the melee attack.
--- @return boolean True if the target is valid for the melee attack combat action, false otherwise.
---
function CombatActionTargetFilters.MeleeAttack(target, attacker)
	--return attacker ~= target and IsMeleeRangeTarget(attacker, nil, nil, target)
	return attacker ~= target
end

---
--- Checks if a target is valid for a pindown combat action.
---
--- @param target table The target to check.
--- @param attacker table The unit performing the pindown action.
--- @param weapon table The weapon used for the pindown action.
--- @return boolean True if the target is valid for the pindown combat action, false otherwise.
---
function CombatActionTargetFilters.Pindown(target, attacker, weapon)
	if not weapon then
		return false
	end
	if not VisibilityCheckAll(attacker, target, nil, const.uvVisible) then
		return false
	end
	local body_parts = target:GetBodyParts(weapon)
	for _, def in ipairs(body_parts) do
		if attacker:HasPindownLineCached(target, def.id, attacker:GetOccupiedPos()) then
			return true
		end
	end
end

---
--- Retrieves a list of valid targets for the Bandage combat action.
---
--- @param unit table The unit performing the Bandage action.
--- @param mode string The mode for retrieving targets. Can be "any" to return the first valid target, or "all" to return a list of all valid targets.
--- @param range_mode string The mode for checking the range to the target. Can be "ignore" to ignore range, "reachable" to only include targets that are reachable within the unit's AP, or "melee" to only include targets within melee range.
--- @return table|nil A table of valid targets, or nil if no valid targets are found.
---
function GetBandageTargets(unit, mode, range_mode)
	local targets = (mode ~= "any") and {}
	if unit:HasStatusEffect("Bleeding") or (unit.HitPoints < unit.MaxHitPoints) then
		if mode == "any" then 
			return unit
		end
		targets[1] = unit
	end
	local allies = GetAllAlliedUnits(unit)
	if unit.team and unit.team.player_team then
		-- enable player to bandage neutral units as well
		allies = table.icopy(allies)
		for _, team in ipairs(g_Teams) do
			if team.neutral then
				table.iappend(allies, team.units)
			end
		end
	end
	local base_cost = CombatActions.Bandage:GetAPCost(unit)
	for _, ally in ipairs(allies) do
		if not ally:IsDead() and ((ally.HitPoints < ally.MaxHitPoints) or ally:IsDowned() or ally:HasStatusEffect("Bleeding") or ally:HasStatusEffect("Unconscious")) then
			local range_ok = range_mode == "ignore" or IsMeleeRangeTarget(unit, nil, nil, ally)
			if range_mode == "reachable" and base_cost > 0 then
				if g_Combat then
					local pos = unit:GetClosestMeleeRangePos(ally)
					if pos then
						local path = GetCombatPath(unit)
						local ap = path:GetAP(pos)
						if ap then 
							local cost = base_cost + Max(0, ap - unit.free_move_ap)
							range_ok = unit:HasAP(cost)
						end
					end
				else
					range_ok = true
				end
			end
			
			if range_ok then
				if mode == "any" then
					return ally
				end
				targets[#targets +1] = ally
			end
		end
	end
	return targets
end

---
--- Returns a list of valid melee attack targets for the given attacker.
---
--- @param attacker Unit The unit performing the melee attack.
--- @param mode string The mode of target selection. Can be "any" to return the first valid target, or nil to return a list of all valid targets.
--- @return Unit|table<Unit> The target(s) for the melee attack.
function GetMeleeAttackTargets(attacker, mode)
	local targets
	for _, target in ipairs(g_Units) do
		if target ~= attacker and not target:IsDead() and IsMeleeRangeTarget(attacker, nil, nil, target) then
			if mode == "any" then
				return target
			end
			targets = targets or {}
			targets[#targets + 1] = target
		end
	end
	return targets
end

---
--- Calculates the action point (AP) cost for a melee attack action.
---
--- @param action table The melee attack action.
--- @param unit Unit The unit performing the melee attack.
--- @param args table Optional arguments, including:
---   - goto_pos table The position the unit needs to move to in order to perform the melee attack.
---   - target Unit The target of the melee attack.
---   - action_cost_only boolean If true, only the base action cost is returned, without any movement cost.
---   - ap_cost_breakdown table A table to store the breakdown of the AP cost (attack cost, move cost, total cost).
--- @return number The total AP cost for the melee attack, including any movement cost.
---
function GetMeleeAttackAPCost(action, unit, args)
	local cost
	if action.CostBasedOnWeapon then
		local weapon = action:GetAttackWeapons(unit, args)	
		cost = weapon and unit:GetAttackAPCost(action, weapon, nil, args and args.aim or 0, action.ActionPointDelta) or -1
	else
		cost = action.ActionPoints
	end
	if args and args.action_cost_only then
		return cost
	end
	local goto_pos = args and args.goto_pos
	if not goto_pos and args and args.target then
		goto_pos = unit:GetClosestMeleeRangePos(args.target)
	end
	local attack_cost = cost
	local move_cost = 0
	if cost >= 0 and goto_pos then
		local path = GetCombatPath(unit)
		move_cost = path:GetAP(goto_pos)
		cost = cost + Max(0, move_cost or 0)
	end
	if args and type(args.ap_cost_breakdown) == "table" then
		args.ap_cost_breakdown.attack_cost = attack_cost
		args.ap_cost_breakdown.move_cost = move_cost
		args.ap_cost_breakdown.total_cost = cost
	end
	return cost
end

---
--- Creates a melee range area visualization for the given unit.
---
--- @param unit Unit The unit for which to create the melee range area.
--- @param vstate string (optional) The visualization state, defaults to "Cast".
--- @param mode string (optional) The mode for the melee range area, defaults to "Ally".
--- @return MeleeAOEVisuals The created melee range area visualization.
---
function CombatActionCreateMeleeRangeArea(unit, vstate, mode)
	local voxels = GetMeleeRangePositions(unit)
	voxels = voxels or {}
	local pos = unit:GetPos()
	table.insert(voxels, point_pack(pos))
	return MeleeAOEVisuals:new({vstate = vstate or "Cast"}, nil, {voxels = voxels, pos = pos, mode =  mode or "Ally"})
end

---
--- Redirects an XAction to a corresponding CombatAction.
---
--- @param xactionName string The name of the XAction to redirect.
--- @param obj table The object containing the UI actions.
--- @return CombatAction, table The redirected CombatAction and its associated action table.
---
function XActionRedirectToCombatAction(xactionName, obj)
	local actions = obj.ui_actions
	for i, actionId in ipairs(actions) do
		local combatAction = CombatActions[actionId]
		local redirectAction = combatAction and combatAction.KeybindingFromAction
		if redirectAction and redirectAction == xactionName then
			return combatAction, actions[actionId]
		end
	end
end

---
--- Gets the signature action description for the given action.
---
--- @param action table The action to get the description for.
--- @return string The signature action description.
---
function GetSignatureActionDescription(action)
	local perk = CharacterEffectDefs[action.id]
	local description = perk and T{perk.Description, perk} or action.Description
	if (description or "") == "" then
		description = action:GetActionDisplayName()
	end
	return description
end

---
--- Gets the signature action display name for the given action.
---
--- @param action table The action to get the display name for.
--- @return string The signature action display name.
---
function GetSignatureActionDisplayName(action)
	local perk = CharacterEffectDefs[action.id]
	local name = perk and perk.DisplayName or action.DisplayName
	if (name or "") == "" then
		name = Untranslated(action.id)
	end
	return name
end

---
--- Checks if the given action ID corresponds to an Overwatch action.
---
--- @param actionId string The ID of the action to check.
--- @return boolean True if the action ID corresponds to an Overwatch action, false otherwise.
---
function IsOverwatchAction(actionId)
	return actionId == "Overwatch" or actionId == "DanceForMe" or actionId == "EyesOnTheBack" or actionId == "MGSetup" or actionId == "MGRotate"
end

---
--- Gets the icon for a throwable item.
---
--- @param self table The object containing the throwable item.
--- @param unit table The unit that the throwable item belongs to.
--- @return string The icon for the throwable item.
---
function GetThrowItemIcon(self, unit)
	local weapon = self:GetAttackWeapons(unit)
	local icon = IsKindOf(weapon, "GrenadeProperties") and weapon.ActionIcon or ""
	return (icon ~= "") and icon or self.Icon
end

---
--- Gets the appropriate melee attack action for the given action and unit.
---
--- @param action table The action to get the melee attack action for.
--- @param unit table The unit that the action belongs to.
--- @return table The appropriate melee attack action.
---
function GetMeleeAttackAction(action, unit)
	if not g_Combat and action.basicAttack and action.ActionType == "Melee Attack" then
		return (unit and unit.marked_target_attack_args) and CombatActions.CancelMark or CombatActions.MarkTarget
	end
	return action
end