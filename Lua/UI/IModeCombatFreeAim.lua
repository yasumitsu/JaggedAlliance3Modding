DefineClass.IModeCombatFreeAim = {
	__parents = { "IModeCombatAttackBase" },
	lock_camera = false,
	attack_pos = false,
	tile_free_attack = false,
	fx_free_attack = false,
	disable_mouse_indicator = true,
	mouse_world_pos = false,
	
	firing_modes = false,
	current_firing_mode = false, -- separate just in case
	meta_action = false,
}

---
--- Opens the IModeCombatFreeAim mode.
--- Initializes the firing mode and meta action based on the attacker's available actions.
---
--- @param self IModeCombatFreeAim The instance of the IModeCombatFreeAim class.
---
function IModeCombatFreeAim:Open()
	IModeCombatAttackBase.Open(self)

	local action = self.action
	local attacker = self.attacker
	if action.group == "FiringModeMetaAction" then
		local defaultMode, firingModes = GetUnitDefaultFiringModeActionFromMetaAction(attacker, action)
		
		local possibleOnes = {}
		for i, fm in ipairs(firingModes) do
			local actionEnabled = attacker.ui_actions[fm.id]
			actionEnabled = actionEnabled == "enabled"
			if actionEnabled then
				possibleOnes[#possibleOnes + 1] = fm
			end
		end
		if #possibleOnes > 1 then
			self.current_firing_mode = defaultMode
			self.firing_modes = possibleOnes
			self.meta_action = self.action
			self.action = self.current_firing_mode
		end
	end
end

---
--- Cycles through the available firing modes for the current attacker.
---
--- @param self IModeCombatFreeAim The instance of the IModeCombatFreeAim class.
---
function IModeCombatFreeAim:CycleFiringMode()
	local firing_modes = self.firing_modes
	if not firing_modes then return end

	local id = self.current_firing_mode.id
	local curTargetIdx = table.find(firing_modes, "id", id) or 0
	curTargetIdx = curTargetIdx + 1
	if curTargetIdx > #firing_modes then
		curTargetIdx = 1
	end
	local action = firing_modes[curTargetIdx]
	self.current_firing_mode = action
	self.action = self.current_firing_mode
	self.attacker.lastFiringMode = action.id
	
	self:UpdateTarget()
end

---
--- Cleans up the state of the IModeCombatFreeAim mode.
---
--- This function is called when the mode is exited. It removes any visual
--- highlights, clears damage prediction, and updates the UI state.
---
--- @param self IModeCombatFreeAim The instance of the IModeCombatFreeAim class.
---
function IModeCombatFreeAim:Done()
	if self.fx_free_attack then
		SetInteractionHighlightRecursive(self.fx_free_attack, false, true)
		self.fx_free_attack = false
	end
	self.tile_free_attack = false
	ClearDamagePrediction()
	SetAPIndicator(false, "free-aim")
	UpdateAllBadges()
end


---
--- Updates the target for the free-aim mode.
---
--- This function is responsible for updating the visual target indicator and
--- applying damage prediction for the current free-aim action.
---
--- @param self IModeCombatFreeAim The instance of the IModeCombatFreeAim class.
--- @param ... Any additional arguments passed to the function.
---
function IModeCombatFreeAim:UpdateTarget(...)
	if not SelectedObj or not SelectedObj:IsIdleCommand() then return end

	IModeCombatAttackBase.UpdateTarget(self, ...)
	
	local tile, fx_target = self:GetFreeAttackTarget(self.potential_target, self.attacker)
	if self.fx_free_attack ~= fx_target then
		self.tile_free_attack = tile
		if self.fx_free_attack then
			SetInteractionHighlightRecursive(self.fx_free_attack, false, true)
			self.fx_free_attack = false
		end

		if fx_target then
			self.fx_free_attack = fx_target
			SetInteractionHighlightRecursive(fx_target, true, true)
		end

		local attacker = SelectedObj or Selection[1]
		local action = self.action
		--ApplyDamagePrediction(attacker, action, {target = tile})

		if action.id and tile then
			NetSyncEvent("Aim", attacker, action.id, tile)
		end
	end
end

---
--- Disables the target setting functionality for the IModeCombatFreeAim mode.
---
--- This function is a stub that always returns false, effectively disabling the
--- target setting functionality in this mode. This is likely done to prevent
--- the user from setting a target manually while in the free-aim mode, and
--- instead rely on the automatic target selection logic.
---
--- @return boolean Always returns false.
---
function IModeCombatFreeAim:SetTarget()
	return false
end

---
--- Disables the lines of fire visualization for the IModeCombatFreeAim mode.
---
--- This function is a stub that does nothing, effectively disabling the lines of
--- fire visualization in this mode. This is likely done to prevent the user from
--- seeing the lines of fire while in the free-aim mode, and instead rely on the
--- automatic target selection logic.
---
function IModeCombatFreeAim:UpdateLinesOfFire() -- do not show lines of fire while in this mode
end

---
--- Shows the covers and shields for the given world position and cover object.
---
--- This function is a wrapper around `IModeCommonUnitControl.ShowCoversShields` that
--- handles the logic for displaying covers and shields in the free-aim mode.
---
--- @param world_pos table The world position to show the covers and shields for.
--- @param cover table The cover object to show the covers and shields for.
---
function IModeCombatFreeAim:ShowCoversShields(world_pos, cover)
	IModeCommonUnitControl.ShowCoversShields(self, world_pos, cover)
end

---
--- Handles the mouse button down event for the IModeCombatFreeAim mode.
---
--- This function is responsible for handling the logic when the user clicks the
--- left mouse button (or gamepad equivalent) while in the free-aim mode. It
--- determines the target for the attack based on the current cursor position,
--- and then performs the attack if the target is valid.
---
--- The function first checks if the selected object can be controlled. If not,
--- it returns without doing anything.
---
--- It then checks if the click was a left mouse button click or a gamepad
--- equivalent. If so, it proceeds to handle the attack logic.
---
--- The function calls `GetFreeAttackTarget` to determine the target for the
--- attack, which can be either a valid object or a position in the world. It
--- then performs various checks based on the type of attack (e.g. MG burst
--- fire, melee attack) to ensure the attack is valid and within the appropriate
--- range and line of sight.
---
--- If the attack is valid, the function calls `FreeAttack` to perform the
--- attack. If the attack is not valid, it reports the appropriate attack error.
---
--- @param pt table The screen position of the mouse click.
--- @param button string The mouse button that was clicked, or nil if it was a gamepad click.
--- @return string|nil If the attack was successfully performed, returns "break" to indicate the event has been handled; otherwise, returns nil.
---
function IModeCombatFreeAim:OnMouseButtonDown(pt, button)	
	if not IsValid(SelectedObj) or not SelectedObj:CanBeControlled() then
		return
	end
	
	local gamepadClick = false
	if not button and GetUIStyleGamepad() then
		gamepadClick = true
	end

	if button == "L" or gamepadClick then
		if IsValidThread(self.real_time_threads and self.real_time_threads.move_and_attack) then
			return
		end
		-- special-case MG burst attack free aim to be restricted in the attack cone
		local target, target_obj = self:GetFreeAttackTarget(self.potential_target, self.attacker)
		if GetUIStyleGamepad() and self.action.AimType == "cone" and self.target_as_pos then
			target = self.target_as_pos
		end
		if self.action.id == "MGBurstFire" then
			local overwatch = g_Overwatch[SelectedObj]
			if overwatch and overwatch.permanent then
				if SelectedObj:HasStatusEffect("ManningEmplacement") then
					if IsCloser2D(SelectedObj, target, guim) then
						ReportAttackError(target or SelectedObj, AttackDisableReasons.OutOfRange)
						return
					end
				end
				local angle = overwatch.orient or CalcOrientation(SelectedObj:GetPos(), overwatch.target_pos)
				if not CheckLOS(target, SelectedObj, overwatch.dist, SelectedObj.stance, overwatch.cone_angle, angle) then
					ReportAttackError(target or SelectedObj, AttackDisableReasons.OutOfRange)
					return
				end
			end
		elseif self.action.ActionType == "Melee Attack" then
			if IsValid(target_obj) then
				local step_pos = self.attacker:GetClosestMeleeRangePos(target_obj)
				if step_pos then
					local args = {target = target_obj, goto_pos = step_pos, free_aim = true}
					if CheckAndReportImpossibleAttack(self.attacker, self.action, args) == "enabled" then
						if self.action.IsTargetableAttack and IsKindOf(target_obj, "Unit") then	
							self.action:UIBegin({self.attacker}, args)
						else
							self:StartMoveAndAttack(self.attacker, self.action, target_obj, step_pos, args)
						end
					end
					return "break"
				elseif g_Combat then
					ReportAttackError(GetCursorPos(), AttackDisableReasons.TooFar)
					return
				end
			else
				ReportAttackError(GetCursorPos(), AttackDisableReasons.NoTarget)
				return
			end
		end
		if self.attacker ~= target then 
			FreeAttack(SelectedObj, target, self.action, self.context.free_aim, self.target_as_pos, self.meta_action)
		else 
			ReportAttackError(target or SelectedObj, AttackDisableReasons.InvalidSelfTarget)
		end
		return
	end
	return IModeCombatAttackBase.OnMouseButtonDown(self, pt, button)
end


--target can be only unit or point
---
--- Gets the free attack target based on the current cursor position and selected object.
---
--- @param target table|nil The current target object, if any.
--- @param attacker_or_pos table The attacker object or the position of the attacker.
--- @return table, table The target object or position, and the object to use for FX.
---
function IModeCombatFreeAim:GetFreeAttackTarget(target, attacker_or_pos)
	local spawnFXObject
	local objForFX
	-- check target
	if IsValid(target) then
		objForFX = target
		return target, objForFX
	else
		target = self:GetUnitUnderMouse()
		if not target then
			local solid, transparent = GetPreciseCursorObj()
			local obj = transparent or solid
			obj = not IsKindOf(obj, "Slab") and SelectionPropagate(obj) or obj
			if IsKindOf(obj, "Object") and not obj:IsInvulnerable() and (IsKindOf(obj, "CombatObject") and not obj.is_destroyed or ShouldDestroyObject(obj)) then
				target = obj
			end
		end
		
		--target could be combatObject/vulnerable object or false
		
		-- edge case for machine guns emplacements, currently they should not be targeted
		if IsKindOf(target, "MachineGunEmplacement") then
			target = false
		end
		
		-- edge case for dynamicspawnlandmine
		if IsKindOf(target, "DynamicSpawnLandmine") then
			spawnFXObject = target
			target = target:GetAttach(1)
		elseif self.action.ActionType == "Melee Attack" then
			spawnFXObject = target
		end
		
		if target then
			objForFX = target
			local hitSpotIdx = target:GetSpotBeginIndex("Hit")
			if hitSpotIdx ~= -1 then
				hitSpotIdx = target:GetNearestSpot("Hit", attacker_or_pos)
			end
			
			--if hitspot exists -> set pos to it
			if hitSpotIdx > 0 then
				target = target:GetSpotPos(hitSpotIdx) 
			else
			--if no hitspot -> set pos to the middle of the bboxf
				local bbox = GetEntityBBox(target:GetEntity())
				target = target:GetVisualPos() + bbox:Center()
			end
		else
		--if there is no target -> set pos to the cursor 
			target = GetCursorPos()
		end 
	end
	
	return spawnFXObject or target, objForFX
end

---
--- Performs a free-aim attack with the given unit, target, and action.
---
--- @param unit table|nil The unit performing the attack. If not provided, the selected unit is used.
--- @param target table|nil The target of the attack. If not provided, the function will attempt to find a valid target under the cursor.
--- @param action table The action to be executed for the attack.
--- @param isFreeAim boolean Whether the attack is a free-aim attack.
--- @param target_as_pos table|nil The position to use as the target, if the target is not a valid object.
--- @param meta_action_crosshair table|nil The meta-action crosshair to use for the attack.
---
--- @return table|nil The object that should be used for spawning FX, or the target position.
--- @return table The object that should be used for FX.
function FreeAttack(unit, target, action, isFreeAim, target_as_pos, meta_action_crosshair)
	if not target then return end

	unit = unit or SelectedObj	
	if not IsValid(unit) or unit:IsDead() then
		return
	end	
	if not CanYield() then
		return CreateRealTimeThread(FreeAttack, unit, target, action, isFreeAim, target_as_pos, meta_action_crosshair)
	end
	
	if IsKindOf(target, "Unit") then 
		-- revert to normal attack mode to this unit
		action = meta_action_crosshair or action
		local args = {target = target, free_aim = isFreeAim}
		local state, reason = action:GetUIState({unit}, args)--add free_aim
		if state == "enabled" or (state == "disabled" and reason == AttackDisableReasons.InvalidTarget) then
			action:UIBegin({unit}, args)
		else
			CheckAndReportImpossibleAttack(unit, action, args)
		end
		return
	end
	
	SelectObj(unit)

	local cursor_pos = terminal.GetMousePos()
	if GetUIStyleGamepad() then
		local front
		front, cursor_pos = GameToScreen(GetCursorPos())
	end

	RequestPixelWorldPos(cursor_pos)
	local preciseAttackPt
	if action.AimType == "cone" and target_as_pos then
		preciseAttackPt = target_as_pos
	else
		local time = now()
		while not preciseAttackPt and now() < time + 150 do
			WaitNextFrame()
			preciseAttackPt = ReturnPixelWorldPos()
		end
		preciseAttackPt = preciseAttackPt or GetCursorPos()
	end
	
	local camera_pos = camera.GetEye()
	-- the target point may be outside the target object collision surfaces, so we extend the line a bit
	local segment_end_pos = camera_pos + SetLen(preciseAttackPt - camera_pos, camera_pos:Dist(preciseAttackPt) + guim)
	local rayObj, pt, normal = GetClosestRayObj(camera_pos, segment_end_pos, const.efVisible, 0, function(o)
		if o:GetOpacity() == 0 then
			return false
		end
		return true
	end, 0, const.cmDefaultObject)
	local args = { target = pt or target }

	if action.group == "FiringModeMetaAction" then
		action = GetUnitDefaultFiringModeActionFromMetaAction(unit, action)
	end
	local state, reason = action:GetUIState({unit}, args) 
	if state == "enabled" or (state == "disabled" and reason == AttackDisableReasons.InvalidTarget) then
		action:Execute({unit}, args)
	else
		CheckAndReportImpossibleAttack(unit, action, args)
	end
end