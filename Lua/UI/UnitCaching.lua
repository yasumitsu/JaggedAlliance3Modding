MapVar("g_precalcCache", {})

---
--- Calculates the bullet damage for a single segment of a line-of-fire (LOF) attack.
---
--- @param segment_hit_data table The hit data for the current LOF segment.
--- @param attack_args table The attack arguments.
---
function CalcLOFSegmentBulletDamage(segment_hit_data, attack_args)
	for k, v in pairs(attack_args) do
		if not segment_hit_data[k] then
			segment_hit_data[k] = v
		end
	end
	local stuck = true
	local ally_hits_count = 0
	local enemy_hits_count = 0
	local allyHit
	if segment_hit_data.hits then
		segment_hit_data.record_breakdown = false
		segment_hit_data.weapon:BulletCalcDamage(segment_hit_data)
		if not attack_args.prediction then
			AddBulletRicochetHits(segment_hit_data, attack_args)
		end
		-- recheck if target is actually hit
		for _, hit in ipairs(segment_hit_data.hits) do
			if hit.is_target then
				stuck = false
			end
			if hit.enemy_hit then
				enemy_hits_count = enemy_hits_count + 1
			elseif hit.ally_hit then
				ally_hits_count = ally_hits_count + 1
				if not allyHit then
					allyHit = hit.obj.session_id
				end
			end
		end
	end
	segment_hit_data.stuck = stuck
	segment_hit_data.ally_hits_count = ally_hits_count
	segment_hit_data.enemy_hits_count = enemy_hits_count
	segment_hit_data.allyHit = allyHit
end

local function CalcLOFBulletDamage(attack_data, attack_args)
	if not attack_data then
		return
	end
	local stuck = true
	local best_ally_hits_count
	for j, segment_hit_data in ipairs(attack_data.lof) do
		CalcLOFSegmentBulletDamage(segment_hit_data, attack_args)
		stuck = stuck and segment_hit_data.stuck
		if not best_ally_hits_count or segment_hit_data.ally_hits_count < best_ally_hits_count then
			best_ally_hits_count = segment_hit_data.ally_hits_count
		end
	end
	attack_data.stuck = stuck
	attack_data.best_ally_hits_count = best_ally_hits_count or 0
	for k, v in pairs(attack_args) do
		if attack_data[k] == nil then
			attack_data[k] = v
		end
	end
end

---
--- Adds bullet ricochet hits to the given `segment_hit_data`.
---
--- @param segment_hit_data table The segment hit data to add ricochet hits to.
--- @param attack_args table The attack arguments.
---
function AddBulletRicochetHits(segment_hit_data, attack_args)
	local hits = segment_hit_data.hits
	local last_hit = hits[#hits]
	local stuck_pos = segment_hit_data.stuck_pos or segment_hit_data.lof_pos2
	if not last_hit or last_hit.pos ~= stuck_pos or not last_hit.norm then
		return
	end
	local surf_fx_type = GetObjMaterial(last_hit.pos, last_hit.obj)
	if not surf_fx_type and IsKindOf(hit.obj, "FXObject") then
		surf_fx_type = hit.obj.fx_actor_class or hit.obj.class
	end
	if not BulletRicochetMaterials[surf_fx_type] then
		return
	end
	local lof_args = table.copy(attack_args)
	local ricochet_start_pos = last_hit.pos
	local norm = last_hit.norm
	local dir = segment_hit_data.lof_pos2 - segment_hit_data.lof_pos1
	local ricochet_dir = dir - MulDivRound(norm, 2 * Dot(dir, norm), Dot(norm, norm))
	local ricochet_end_pos = ricochet_start_pos + SetLen(ricochet_dir, const.RicochetDistance)
	lof_args.attack_pos = ricochet_start_pos + SetLen(ricochet_dir, guic) -- get away from the collision
	lof_args.target_pos = ricochet_end_pos
	lof_args.fire_relative_point_attack = false
	lof_args.clamp_to_target = true
	lof_args.extend_shot_start_to_attacker = false
	lof_args.can_hit_attacker = true
	lof_args.ignore_los = true
	lof_args.inside_attack_area_check = false
	lof_args.forced_hit_on_eye_contact = false
	lof_args.penetration_class = -1 -- stuck on the first hit
	lof_args.max_penetration_range = -1
	lof_args.can_use_covers = false
	lof_args.emplacement_weapon = false
	lof_args.ricochet = true
	local attack_data = CheckLOF(ricochet_end_pos, lof_args)
	local lof = attack_data.lof and attack_data.lof[1]
	local ricochet_hit = lof and lof.hits and lof.hits[1]
	table.insert(hits, ricochet_hit or { pos = ricochet_end_pos })
	last_hit.ricochet = true
	segment_hit_data.ricochet_pos = hits[#hits].pos
	if ricochet_hit then
		ricochet_hit.stray = true
		segment_hit_data.weapon:BulletCalcDamage(segment_hit_data, #hits)
	end
end

---
--- Retrieves the line of fire (LOF) data for the given attacker and targets.
---
--- @param attacker table The attacking unit.
--- @param targets table|Point The target(s) to check the LOF for.
--- @param attack_args table The attack arguments.
--- @return table The LOF data for the targets.
---
function GetLoFData(attacker, targets, attack_args)
	local target = (IsPoint(targets) or IsValid(targets)) and targets
	
	local action_id = attack_args and attack_args.action_id or attacker:GetDefaultAttackAction("ranged").id
	local action = action_id and CombatActions[action_id]
	local weapon = attack_args and attack_args.weapon or action and action:GetAttackWeapons(attacker)
	local weapon_visual = attack_args and attack_args.weapon_visual or IsKindOf(weapon, "Firearm") and weapon:GetVisualObj(attacker) or false

	--local weapon = attacker and attacker:GetActiveWeapons("Firearm")
	if not weapon then
		return not target and {}
	end
	local lof_args = attack_args and table.copy(attack_args) or {}
	lof_args.action_id = action_id
	lof_args.obj = attacker
	lof_args.weapon = weapon
	lof_args.weapon_visual = weapon_visual
	lof_args.output_collisions = true
	if lof_args.prediction == nil then
		lof_args.prediction = true
	end
	if not lof_args.penetration_class and IsKindOf(weapon, "BaseWeapon") then
		lof_args.penetration_class = weapon:GetPenetrationClass()
	end
	lof_args.output_collisions = true
	if not weapon or weapon.WeaponType == "GrenadeLauncher" then
		lof_args.aimIK = false -- Grenade Launcher aim position depends on the trajectory, it's not the target position
	else
		lof_args.aimIK = attacker:CanAimIK(weapon)
	end
	if not lof_args.attack_pos and IsKindOf(weapon, "FirearmBase") and weapon.emplacement_weapon and weapon_visual then
		lof_args.emplacement_weapon = true
		lof_args.attack_pos = weapon_visual:GetSpotLocPos(weapon_visual:GetSpotBeginIndex("Muzzle"))
		lof_args.step_pos = weapon_visual:GetSpotPos(weapon_visual:GetSpotBeginIndex("Unit"))
	end
	lof_args.force_hit_seen_target = not config.DisableForcedHitSeenTarget
	if action_id == "Overwatch" then
		lof_args.can_stuck_on_unit = false
	end

	local targets_attack_data
	local lof_idx = target and lof_args.prediction and lof_args.lof and lof_args.target_spot_group and table.find(lof_args.lof, "target_spot_group", lof_args.target_spot_group)
	if lof_idx then
		targets_attack_data = table.copy(lof_args)
		targets_attack_data.lof = { lof_args.lof[lof_idx] }
	else
		targets_attack_data = CheckLOF(targets, lof_args)
		lof_args.target = nil
		lof_args.target_dummy = nil
		lof_args.target_pos = nil
		lof_args.lof = nil
		if IsKindOf(weapon, "Firearm") then
			if target then
				CalcLOFBulletDamage(targets_attack_data, lof_args)
			else
				for i, attack_data in ipairs(targets_attack_data) do
					CalcLOFBulletDamage(attack_data, lof_args)
				end
			end
		end
	end
	return targets_attack_data
end

------------------------------------------------ LOF Cache ------------------------------------------------
-- LOF data to all enemies, CTH etc --

---
--- Checks if an enemy's attack is considered "good" for the current unit.
---
--- This function is used to determine if an enemy's attack should be considered "good" for the current unit. It checks the `g_UIAttackCache` or `g_UIAttackCachePredicted` cache to see if the enemy's attack is marked as "good". If the cache is not available or the current unit is not selected, the function returns `false`.
---
--- @param enemy table The enemy unit to check.
--- @return boolean True if the enemy's attack is considered "good", false otherwise.
function UIIsEnemyAttackGood(enemy) -- grey out on enemy head icons
	local cache = g_UIAttackCachePredicted and g_UIAttackCachePredicted or g_UIAttackCache
	
	if not cache or not Selection or not Selection[1] then return false end
	if not cache.goodAttack then return false end
	return not not cache.goodAttack[enemy]
end

---
--- Checks if an enemy's attack is considered "good" for the current unit.
---
--- This function is used to determine if an enemy's attack should be considered "good" for the current unit. It checks the `g_UIAttackCache` or `g_UIAttackCachePredicted` cache to see if the enemy's attack is marked as "good". If the cache is not available or the current unit is not selected, the function returns `false`.
---
--- @param enemy table The enemy unit to check.
--- @return boolean True if the enemy's attack is considered "good", false otherwise.
function UIIsObjectAttackGood(enemy) -- grey out on enemy head icons
	local cache = g_UIAttackCachePredicted and g_UIAttackCachePredicted or g_UIAttackCache
	
	if not cache or not Selection or not Selection[1] then return false end
	if not cache.goodAttackObject then return false end
	return not not cache.goodAttackObject[enemy]
end

---
--- Returns the "good attack" cache for the currently selected unit.
---
--- The "good attack" cache is a table that maps enemy units to boolean values indicating whether their attacks are considered "good" for the currently selected unit. This function retrieves the appropriate cache, either the predicted cache (`g_UIAttackCachePredicted`) or the regular cache (`g_UIAttackCache`), and returns it.
---
--- If the cache is not available or the current unit is not selected, this function returns `false`.
---
--- @return table|boolean The "good attack" cache, or `false` if the cache is not available.
function UIGetEnemiesGoodAttack() -- used by lines of fire
	local cache = g_UIAttackCachePredicted and g_UIAttackCachePredicted or g_UIAttackCache
	
	local currentUnit = Selection and Selection[1]
	if not cache or not currentUnit then return false end
	if not cache.goodAttack then return false end
	if cache.for_unit ~= currentUnit.session_id then return false end
	
	return cache.goodAttack
end

---
--- Checks if any enemy's attack is considered "good" for the current unit.
---
--- This function is used to determine if any enemy's attack should be considered "good" for the current unit. It checks the `g_UIAttackCache` or `g_UIAttackCachePredicted` cache to see if any enemy's attack is marked as "good". If the cache is not available or the current unit is not selected, the function returns `false`.
---
--- If an `action` is provided, the function will recheck the cache for the current action, taking into account the action's attack weapons, maximum aim range, and targets.
---
--- @param action table The action to check for good attacks, or `nil` to check the overall cache.
--- @return boolean True if any enemy's attack is considered "good", false otherwise.
function UIAnyEnemyAttackGood(action) -- auto free aim
	if not g_UIAttackCache or not Selection or not Selection[1] then return false end
	if not action then
		return not not g_UIAttackCache.anyEnemyGoodAttack--anyGoodAttack
	end
	
	-- recheck for the current action, if given
	local unit = Selection[1]
	local weapon = action:GetAttackWeapons(unit)
	if not IsKindOfClasses(weapon, "Firearm", "MeleeWeapon") then return false end

	local max_range = action:GetMaxAimRange(unit, weapon)
	max_range = max_range or weapon.WeaponRange
	max_range = max_range and (max_range * const.SlabSizeX)

	local lof_args = {
		obj = unit,
		action_id = action.id,
		weapon = weapon,
		range = max_range,
		clamp_to_target = true,
		step_pos = unit:GetOccupiedPos(),
	}
	local visibleEnemies = action:GetTargets({unit})
	if action.ActionType == "Ranged Attack" then
		local lof_data = visibleEnemies and #visibleEnemies > 0 and GetLoFData(unit, visibleEnemies, lof_args)
		for i, e in ipairs(visibleEnemies) do
			local lof = lof_data[i]
			lof_data[e] = lof
			
			local isGoodAttack = false
			for i, bodyPartLof in ipairs(lof and lof.lof) do
				local bodyPartGood = not bodyPartLof.stuck and not bodyPartLof.outside_attack_area and bodyPartLof.target_los
				if bodyPartGood then
					return true
				end
			end
		end
	elseif action.ActionType == "Melee Attack" then
		local targets = GetMeleeAttackTargets(unit)
		for i, e in ipairs(targets) do
			if unit:IsOnEnemySide(e) then
				return true
			end
		end
		if action:GetAnyTarget(Selection) then
			return true
		end
	end	
	return false
end

---
--- Checks if the currently selected unit can see the given enemy unit.
---
--- @param enemy Unit The enemy unit to check visibility for.
--- @return boolean True if the selected unit can see the enemy, false otherwise.
---
function UIEnemyCanSee(enemy)
	if not Selection or not Selection[1] then return true end
	return HasVisibilityTo(Selection[1], enemy)
end

---
--- Checks if the cached line-of-sight (LOS) data for the given attacker, target, action, and weapon is valid and can be used, or if new LOS data needs to be calculated.
---
--- @param attacker Unit The unit performing the attack.
--- @param target Unit The target of the attack.
--- @param action IModeCombatAttackBase The action being performed.
--- @param gotoPos Vector3 The position the attacker is moving to.
--- @param weapon IWeapon The weapon being used for the attack.
--- @param forceNoCache boolean If true, the cached LOS data will not be used and new data will be calculated.
--- @return table The cached LOS data if valid, or new LOS data calculated using GetLoFData().
---
function UIGetCachedLoFOrReal(attacker, target, action, gotoPos, weapon, forceNoCache)
	local canUseCache = not forceNoCache
	if not Selection or not Selection[1] or attacker ~= Selection[1] then
		canUseCache = false
	elseif not g_UIAttackCache or not g_UIAttackCache.lof_cache then
		canUseCache = false
	elseif g_UIAttackCache.lof_cache_src.attackerId ~= attacker.session_id then
		canUseCache = false
	elseif g_UIAttackCache.lof_cache_src.actionId ~= action.id then
		canUseCache = false
	elseif g_UIAttackCache.lof_cache_src.fromPos ~= gotoPos then
		canUseCache = false
	elseif g_UIAttackCache.lof_cache_src.weapon ~= weapon then
		canUseCache = false
	elseif not g_UIAttackCache.lof_cache[target] then
		canUseCache = false
	end
	
	if canUseCache then
		return g_UIAttackCache.lof_cache[target]
	else
		local lof_params = {
			action_id = action.Id,
			weapon = weapon,
			step_pos = gotoPos,
		}
		local lof_data = GetLoFData(attacker, target, lof_params)
		return lof_data
	end
end

---
--- Returns a list of visible enemy units that the given attacker can target.
---
--- @param attacker Unit The unit performing the action.
--- @param igi IModeCombatAttackBase The action being performed.
--- @return table A list of visible enemy units that the attacker can target.
---
function GetTargetsToShowAboveActionBar(attacker, igi)
	if not attacker then return {} end
	
	if igi and IsKindOf(igi, "IModeCombatAttackBase") then
		local action = igi.action or igi.context.action
		return action and action:GetTargets({attacker}) or empty_table;
	end
	
	local team = attacker.team
	local visibleUnits = team and g_Visibility[team] or empty_table
	local visibleEnemies = table.ifilter(visibleUnits, function(idx, o)
		return IsValid(o) and attacker:IsOnEnemySide(o) and not o:HasStatusEffect("Hidden")
	end)
	return visibleEnemies
end

---
--- Returns a list of visible enemy units that the given attacker can target, sorted by a custom unit order.
---
--- @param attacker Unit The unit performing the action.
--- @param igi IModeCombatAttackBase The action being performed.
--- @return table A list of visible enemy units that the attacker can target, sorted by a custom unit order.
---
function GetTargetsToShowAboveActionBarSorted(attacker, igi)
	local targets = GetTargetsToShowAboveActionBar(attacker, igi)
	local unitOrder = g_unitOrder[attacker] or empty_table
	table.stable_sort(targets, function(a, b)
		local orderA = unitOrder[a] or 0
		local orderB = unitOrder[b] or 0
		return orderA < orderB
	end)
	return targets
end

---
--- Returns a list of visible enemy units that the given attacker can target.
---
--- @param attacker Unit The unit performing the action.
--- @return table A list of visible enemy units that the attacker can target.
---
function GetTargetsToShowInPartyUI(attacker)
	if not attacker then return {} end
	local visibleUnits = attacker and g_Visibility[attacker] or empty_table
	local visibleEnemies = table.ifilter(visibleUnits, function(idx, o)
		return IsValid(o) and attacker:IsOnEnemySide(o) and not o:HasStatusEffect("Hidden")
	end)
	return visibleEnemies
end

MapVar("g_UIAttackCache", function() return {} end)

---
--- Precalculates the line-of-fire (LOF) data for the given unit's default attack action, and caches the results.
---
--- This function is used to precompute the LOF data for the selected unit's default attack action, and store the results in a cache. The cache includes information about which enemy units can be targeted by the unit's default attack, as well as whether any of those targets have a clear line of fire.
---
--- @param unit Unit The unit performing the action.
--- @param action IModeCombatAttackBase The action being performed.
--- @param pos Vector3 The position from which the action is being performed.
--- @param cacheTable table The cache table to store the results in.
---
function PrecalcLOFUI(unit, action, pos, cacheTable)
	if not Selection then return end
	if unit ~= Selection[1] or unit:IsDead() then return end

	local startTime = GetPreciseTicks()

	local defaultAction 
	if action and action.ActionType == "Ranged Attack" then
		defaultAction  = action
	end
	defaultAction = defaultAction or unit:GetDefaultAttackAction("ranged") or unit:GetDefaultAttackAction() or action
	if defaultAction.group == "FiringModeMetaAction" then
		defaultAction = GetUnitDefaultFiringModeActionFromMetaAction(unit, defaultAction)
	end

	local unitWeapon = defaultAction:GetAttackWeapons(unit)
	if not IsKindOfClasses(unitWeapon, "Firearm", "MeleeWeapon") then return end

	local max_range = defaultAction:GetMaxAimRange(unit, unitWeapon)
	max_range = max_range or unitWeapon.WeaponRange
	max_range = max_range and (max_range * const.SlabSizeX)

	local lof_args = {
		obj = unit,
		action_id = defaultAction.id,
		weapon = unitWeapon,
		range = max_range,
		clamp_to_target = true,
		step_pos = pos or unit:GetOccupiedPos(),
	}

	cacheTable = cacheTable or g_UIAttackCache
	cacheTable.for_unit = unit.session_id
	if not cacheTable.goodAttack then cacheTable.goodAttack = {} end
	table.clear(cacheTable.goodAttack)
	local goodAttackCache = cacheTable.goodAttack
	local anyGoodAttack = false
	local anyEnemyGoodAttack = false

	local visibleEnemies = defaultAction:GetTargets({unit})
	if defaultAction.ActionType == "Ranged Attack" then
		local lof_data = visibleEnemies and #visibleEnemies > 0 and GetLoFData(unit, visibleEnemies, lof_args)
		for i, e in ipairs(visibleEnemies) do
			local lof = lof_data[i]
			lof_data[e] = lof
			
			local isGoodAttack = false
			for i, bodyPartLof in ipairs(lof and lof.lof) do
				local bodyPartGood = not bodyPartLof.stuck and not bodyPartLof.outside_attack_area and bodyPartLof.target_los
				if bodyPartGood then
					isGoodAttack = true
					break
				end
			end

			anyGoodAttack = anyGoodAttack or isGoodAttack
			anyEnemyGoodAttack = anyEnemyGoodAttack or (isGoodAttack and unit:IsOnEnemySide(e))
			goodAttackCache[e] = isGoodAttack
		end
		cacheTable.lof_cache = lof_data
		cacheTable.lof_cache_src = { attackerId = unit.session_id, actionId = defaultAction.id, fromPos = pos, weapon = unitWeapon }
	elseif defaultAction.ActionType == "Melee Attack" then
		local targets = GetMeleeAttackTargets(unit)
		if targets and #targets > 0 then
			anyGoodAttack = true
			for i, e in ipairs(targets) do
				if unit:IsOnEnemySide(e) then
					goodAttackCache[e] = true
					anyEnemyGoodAttack = true
				end
			end
		end
	else -- fallback
		cacheTable.lof_cache = false
		cacheTable.lof_cache_src = false
	end
	cacheTable.anyGoodAttack = anyGoodAttack
	cacheTable.anyEnemyGoodAttack = anyEnemyGoodAttack
	cacheTable.enemies = visibleEnemies
	
	if not cacheTable.goodAttackObject then cacheTable.goodAttackObject = {} end
	table.clear(cacheTable.goodAttackObject)
	local goodAttackObject = cacheTable.goodAttackObject
	
	if defaultAction.ActionType == "Ranged Attack" then
		--assert(unit.team.side == "player1") -- Enemy selected ?! (Happens in tests)
		local visibleTraps = g_AttackableVisibility[unit]
		if visibleTraps and #visibleTraps > 0 then
			lof_args.target_spot_group = ""
			local lof_data = GetLoFData(unit, visibleTraps, lof_args)
			for i, lof in ipairs(lof_data) do
				local isGoodAttack = lof and not lof.stuck and not lof.outside_attack_area and lof.los ~= 0 
				local obj = visibleTraps[i]
				goodAttackObject[obj] = isGoodAttack
			end
		end
	end
	
	if cacheTable ~= g_UIAttackCache then return end
	UpdateEnemyUIOrderForUnit(unit)
	ObjModified("unit_precalc")
	ObjModified("any_precalc")
	
	local igi = GetInGameInterfaceModeDlg()
	if igi and igi.crosshair and igi.crosshair.window_state ~= "destroying" then
		igi.crosshair.cached_results = false -- Invalidate cache
		igi.crosshair:UpdateAim()
	end
	
	if UIRebuildSpam then
		print("UnitRecalc", GetPreciseTicks() - startTime)
	end
end

--- Precalculates UI actions for the given unit if needed.
---
--- This function checks if the given unit is the currently selected unit, and if the game is in combat mode and the combat has started. It also checks if the game is in satellite view or a setpiece is playing, and if the unit is not in an idle command or has a combat action in progress.
---
--- If the conditions are met, this function calls the `PrecalcLOFUI` function with a delay of 0 ticks, and returns `true`. Otherwise, it returns `false`.
---
--- @param unit Unit The unit to precalculate UI actions for.
--- @return boolean Whether the precalculation was performed.
function PrecalcUIIfNeeded(unit)
	if not Selection or not Selection[1] then return end
	if unit and unit ~= Selection[1] then return end
	if g_Combat and not g_Combat.combat_started then return end
	if gv_SatelliteView or IsSetpiecePlaying() then return end
	if not unit:IsIdleCommand() or HasCombatActionInProgress(unit) then return end

	DelayedCall(0, PrecalcLOFUI, unit)
	return true
end

OnMsg.UnitStanceChanged = PrecalcUIIfNeeded
OnMsg.TurnStart = PrecalcUIIfNeeded
OnMsg.GameOptionsChanged = PrecalcUIIfNeeded
OnMsg.UnitAwarenessChanged = PrecalcUIIfNeeded

local function lSelectionChangedRecalc()
	local unit = Selection[1]
	if unit and IsKindOf(unit, "Unit") then
		unit:RecalcUIActions()
		PrecalcUIIfNeeded(unit)
		ObjModified("combat_bar")
	end
end

function OnMsg.SelectionChange() -- This is the event in which Selection is already changed, but is before SelectedObjChange.
	if g_Combat then return end
	lSelectionChangedRecalc()
end

function OnMsg.SelectedObjChange() -- This is the event the combat visibility application is on.
	if not g_Combat then return end
	lSelectionChangedRecalc()
end

function OnMsg.CoOpPartnerSelectionChanged(unitsSelected)
	local primarySelect = unitsSelected and unitsSelected[1]
	local unit = primarySelect and g_Units[primarySelect]
	if unit then
		unit:RecalcUIActions()
	end
end

function OnMsg.ExplorationTick()
	if g_Combat then return end
	if IsSetpiecePlaying() then return end
	
	local selUnit = Selection[1]
	if selUnit and selUnit.command ~= "GotoSlab" then
		if not PrecalcUIIfNeeded(selUnit) then return end
		selUnit:FlushCombatCache()
		selUnit:RecalcUIActions()
	end
end

function OnMsg.CombatComputedVisibility()
	if not g_Combat or not SelectedObj then return end
	PrecalcUIIfNeeded(SelectedObj)
	SelectedObj:RecalcUIActions()
end

-- Enemies change their cover orientation when the closest unit changes position.
function OnMsg.TargetDummiesChanged(unit)
	if not SelectedObj then return end
	if g_Combat and not g_Combat.combat_started then return end -- Everyone repositions while combat is starting.
	local weapon = SelectedObj:GetActiveWeapons()
	local action = SelectedObj:GetDefaultAttackAction()
	local range = AIGetWeaponCheckRange(SelectedObj, weapon, action)
	if not range or not IsCloser(SelectedObj, unit, range + 1) then return end
	PrecalcUIIfNeeded(SelectedObj)
end

------------------------------------------------ Unit Head Prediction ------------------------------------------------

MapVar("g_UIAttackCachePredicted", false)
---
--- Enables or disables the prediction mode for UI enemy head icons.
---
--- When enabled, the function initializes the `g_UIAttackCachePredicted` table and causes a recalculation of effects in the `UpdateTarget` function of the in-game interface mode dialog.
---
--- When disabled, the function sets `g_UIAttackCachePredicted` to `false` and modifies the `unit_precalc` and `any_precalc` objects.
---
--- @param enable boolean Whether to enable or disable the prediction mode
---
function UIEnemyHeadIconsPredictionMode(enable)
	if not enable then
		if not g_UIAttackCachePredicted then return end
	
		g_UIAttackCachePredicted = false
		ObjModified("unit_precalc")
		ObjModified("any_precalc")
		return
	end
	if g_UIAttackCachePredicted then return end
	
	g_UIAttackCachePredicted = {}
	
	-- Cause recalculation of effects in :UpdateTarget
	local dlg = GetInGameInterfaceModeDlg()
	dlg.effects_target_pos_last = false
end

function OnMsg.EffectsTargetPosUpdated(dialog, pt)
	if not g_UIAttackCachePredicted then return end
	
	local unit = Selection[1]
	if not unit then return end
	PrecalcLOFUI(unit, rawget(dialog, "action"), pt, g_UIAttackCachePredicted)
	
	if not g_UIAttackCachePredicted.visibility then g_UIAttackCachePredicted.visibility = {} end
	table.clear(g_UIAttackCachePredicted.visibility)
	local visibility = g_UIAttackCachePredicted.visibility
	local stanceToTake = dialog.targeting_blackboard and dialog.targeting_blackboard.playerToDoStanceAtEnd or unit.stance
	for i, e in ipairs(g_UIAttackCachePredicted.enemies) do
		visibility[e] = unit:CanSee(e, pt, stanceToTake)
	end
	
	ObjModified("unit_precalc")
	ObjModified("any_precalc")
end

------------------------------------------------ Combat Action Cache ------------------------------------------------
-- Holds things such as the available combat actions, default attack action, etc --

---
--- Flushes the combat cache for the unit.
---
--- This function is used to clear the cached combat-related information for the unit, such as available actions, default attack, etc. This is typically done when the unit's equipment or other relevant properties change, to ensure the cache is up-to-date.
---
--- @param self Unit The unit instance.
---
function Unit:FlushCombatCache()
	self.combat_cache = false
end

itemCombatSkillsList = {
	"ThrowGrenadeA",
	"ThrowGrenadeB",
	"ThrowGrenadeC",
	"ThrowGrenadeD",
	"Bandage",
	"ChangeWeapon",
	"RemoteDetonation"
}

---
--- Determines whether the unit should swap its current weapon.
---
--- This function checks the current weapon of the unit and determines whether it should be swapped with the alternate weapon set. The decision is based on the following rules:
---
--- 1. If the current weapon is not a valid base weapon, swap if any valid base weapon is found in the alternate set.
--- 2. If the current weapon is not a firearm or melee weapon, swap if any firearm or melee weapon is found in the alternate set.
--- 3. If the current weapon is a valid firearm or melee weapon, do not swap.
---
--- @param self Unit The unit instance.
--- @return boolean Whether the unit should swap its current weapon.
---
function Unit:ShouldSwapWeapons()
	local alt = (self.current_weapon == "Handheld A") and "Handheld B" or "Handheld A"
	
	if not self:GetItemInSlot(self.current_weapon, "BaseWeapon") then
		-- no weapon at all, swap if any is found in the alt set
		return not not self:GetItemInSlot(alt, "BaseWeapon")
	elseif not self:GetItemInSlot(self.current_weapon, "Firearm") and not self:GetItemInSlot(self.current_weapon, "MeleeWeapon") then
		-- no firearm or melee weapon, swap if any is found in the alt set
		return not not self:GetItemInSlot(alt, "Firearm") or not not self:GetItemInSlot(alt, "MeleeWeapon")
	end
	return false
end

local function add_weapon_attacks(actions, unit, weapon)
	if IsKindOf(weapon, "MachineGun") and not unit:HasStatusEffect("StationedMachineGun") then
		table.insert_unique(actions, "MGSetup")
	elseif IsKindOf(weapon, "HeavyWeapon") then
		table.insert_unique(actions, weapon:GetBaseAttack())
	elseif IsKindOf(weapon, "Firearm") then
		for _, id in ipairs(weapon.AvailableAttacks or empty_table) do
			table.insert_unique(actions, id)
		end
	elseif IsKindOf(weapon, "MeleeWeapon") then
		if weapon.Charge then
			table.insert_unique(actions, "Charge")
		else
			table.insert_unique(actions, "Brutalize")
		end
	elseif not weapon then
		table.insert_unique(actions, "Brutalize")
	end
end

local l_get_throwable_knife

---
--- Retrieves the throwable knife item from the unit's current or alternate weapon set.
---
--- This function iterates through the items in the unit's current weapon set and the alternate weapon set to find a melee weapon that has the `CanThrow` property set to `true`. The first such item found is returned.
---
--- @param self Unit The unit instance.
--- @return MeleeWeapon|nil The throwable knife item, or `nil` if no throwable knife is found.
---
function Unit:GetThrowableKnife()
	l_get_throwable_knife = nil
	self:ForEachItemInSlot(self.current_weapon, function(item)
		if IsKindOf(item, "MeleeWeapon") and item.CanThrow then
			l_get_throwable_knife = item
			return "break"
		end
	end)
	if not l_get_throwable_knife then
		local alt_set = self.current_weapon == "Handheld A" and "Handheld B" or "Handheld A"
		self:ForEachItemInSlot(alt_set, function(item)
			if IsKindOf(item, "MeleeWeapon") and item.CanThrow then
				l_get_throwable_knife = item
				return "break"
			end
		end)
	end
	return l_get_throwable_knife
end

---
--- Enumerates the UI actions available for the unit.
---
--- This function retrieves the list of available UI actions for the unit, including weapon attacks, signature abilities, and common actions.
---
--- @param self Unit The unit instance.
--- @return table The list of available UI actions.
---
function Unit:EnumUIActions()
	local actions = {}
	
	if g_Combat or (IsUnitPrimarySelectionCoOpAware(self) and not g_Overwatch[self]) then
		-- weapon attacks (from first weapon only)
		local action = self:GetDefaultAttackAction()
		actions[1] = action.id
		
		local main_weapon, offhand_weapon = self:GetActiveWeapons()		
		add_weapon_attacks(actions, self, main_weapon)
		
		-- allow dual-wielding with a flare gun
		if IsKindOf(main_weapon, "FlareGun") or IsKindOf(offhand_weapon, "FlareGun") then
			add_weapon_attacks(actions, self, offhand_weapon)
		end
		
		if self:GetThrowableKnife() then
			actions[#actions + 1] = "KnifeThrow"
		end
		
		if table.find(actions, "DualShot") then
			-- special case: add left/right hand shot modes automatically
			table.insert_unique(actions, "LeftHandShot")
			table.insert_unique(actions, "RightHandShot")
		end
		
		if IsKindOf(main_weapon, "FirearmBase") then
			for slot, sub in sorted_pairs(main_weapon.subweapons) do
				add_weapon_attacks(actions, self, sub)
			end
			if main_weapon:HasComponent("EnableFullAuto") then
				table.insert_unique(actions, "AutoFire")
			end
		end
				
		if #actions == 0 then
			actions[1] = "UnarmedAttack"
		end
	end
	
	-- add signature abilities (if any)
	for _, skill in ipairs(Presets.CombatAction.SignatureAbilities) do
		local id = skill.id
		if string.match(id, "DoubleToss") then 
			id = "DoubleToss"
		end
		if id and self:HasStatusEffect(id) then
			actions[#actions + 1] = skill.id
		end
	end
	
	-- common actions
	ForEachPresetInGroup("CombatAction", "Default", function(def)
		actions[#actions + 1] = def.id
	end)

	if g_Combat or IsUnitPrimarySelectionCoOpAware(self) then
		-- actions from consumables
		if self:GetItemInSlot("Handheld A", "Grenade", 1, 1) then actions[#actions + 1] = "ThrowGrenadeA" end
		if self:GetItemInSlot("Handheld A", "Grenade", 2, 1) then actions[#actions + 1] = "ThrowGrenadeB" end
		if self:GetItemInSlot("Handheld B", "Grenade", 1, 1) then actions[#actions + 1] = "ThrowGrenadeC" end
		if self:GetItemInSlot("Handheld B", "Grenade", 2, 1) then actions[#actions + 1] = "ThrowGrenadeD" end

		if GetUnitEquippedMedicine(self) then
			actions[#actions + 1] = "Bandage"
		end
		
		if GetUnitEquippedDetonator(self) then
			actions[#actions + 1] = "RemoteDetonation"
		end
		
		-- todo: merc-related actions (perk/adrenaline skills)
	end

	actions[#actions + 1] = "ItemSkills"
	
	return actions
end

---
--- Recalculates the UI actions for a unit based on its current state and equipment.
--- This function is responsible for determining the set of actions that should be displayed in the unit's UI.
--- It handles various special cases, such as units manning machine guns or equipped with grenades, and ensures that the actions are properly sorted and grouped.
---
--- @param self Unit The unit for which to recalculate the UI actions.
--- @param force boolean (optional) If true, forces the UI actions to be recalculated even if no changes have been detected.
--- @return table The updated list of UI actions for the unit.
---
function Unit:RecalcUIActions(force)
	local actions
	
	if self:GetBandageTarget() then
		actions = { "StopBandaging" }
	elseif self:HasStatusEffect("StationedMachineGun") or self:HasStatusEffect("ManningEmplacement") then
		actions = {}
		local action = self:GetDefaultAttackAction()
		actions[#actions + 1] = action.id
		ForEachPresetInGroup("CombatAction", "MachineGun", function(def)
			if def.id ~= "MGSetup" then
				actions[#actions + 1] = def.id
			end
		end)
		
		-- additional available actions
		actions[#actions + 1] = "Reload"
		actions[#actions + 1] = "Unjam"
	else
		actions = self:EnumUIActions() 
		if not actions then -- EnumUIActions decided to swap
			return
		end
	end
	
	-- move hidden actions to the back and mark actions visible in ui
	local ui_actions = {}
	local vis_idx = 1
	local old_actions = self.ui_actions
	self.ui_actions = ui_actions

	if actions then
		table.sort(actions, function(a, b)
			local actionA = CombatActions[a]
			local actionB = CombatActions[b]
			return actionA.SortKey < actionB.SortKey
		end)

		-- First pass, find actions which combine into firing modes.
		-- This should setup the right default attack action as well.
		local firingModes = {}
		for i = 1, #actions do
			local id = actions[i]
			local caction = CombatActions[id]
			local state = "hidden"
			
			local firingModeId = caction.FiringModeMember
			if not firingModeId then goto continue end

			if caction.ShowIn == "CombatActions" and (g_Combat or (#(Selection or empty_table) == 1 or caction.MultiSelectBehavior ~= "hidden")) then
				local target = caction.RequireTargets and caction:GetDefaultTarget(self)
				state = caction:GetVisibility({self}, target)
			end

			if state ~= "hidden" then
				if not firingModes[firingModeId] then
					firingModes[firingModeId] = {}
				end
				table.insert(firingModes[firingModeId], id)
				ui_actions[id] = state
			end

			::continue::
		end
		
		-- Check if dual shot attack mode is active.
		-- This has higher priotity because it disables other firing modes
		local dual_shot_state
		for modeName, mode in pairs(firingModes) do
			if modeName == "AttackDual" then
				for i, m in ipairs(mode) do
					if ui_actions[m] == "enabled" then
						dual_shot_state = "enabled"
					end
				end
			end
		end
		
		-- Show firing mode action only if more than one action is available.
		for modeName, mode in pairs(firingModes) do
			local defaultFireMode = mode[1]
			if #mode > 1 and (modeName ~= "AttackDual" or dual_shot_state ~= "hidden") then
				ui_actions[modeName] = "enabled"
				
				-- Weapon default
				local defaultAction = self:GetDefaultAttackAction(false, "force_ungrouped")
				if defaultAction.FiringModeMember == modeName and ui_actions[defaultAction.id] == "enabled" then
					defaultFireMode = defaultAction.id
				else
					-- First enabled.
					for i, m in ipairs(mode) do
						if ui_actions[m] == "enabled" then
							defaultFireMode = m
							break
						end
					end
				end
			else
				ui_actions[modeName] = "disabled"
			end
			
			-- When showing dual attacking hide other firing modes
			if modeName ~= "AttackDual" and dual_shot_state == "enabled" then
				ui_actions[modeName] = "hidden"
				for i, m in ipairs(mode) do
					ui_actions[m] = "hidden"
				end
			elseif dual_shot_state ~= "enabled" and modeName == "AttackDual" then
				for i, m in ipairs(mode) do
					ui_actions[m] = "hidden"
				end
			end

			mode.take_idx_from = mode[1]
			ui_actions[modeName .. "default"] = defaultFireMode
			assert(ui_actions[modeName .. "default"])	
		end

		local doubleTossCount = 0
		local grenadeModes = {}
		for i = 1, #actions do
			local id = actions[i]
			local caction = CombatActions[id]
			
			local state = "hidden"
			if caction.ShowIn == "CombatActions" or caction.ShowIn == "SignatureAbilities" then
				if ui_actions[id] then
					state = ui_actions[id]
				elseif g_Combat or (#(Selection or empty_table) == 1 or caction.MultiSelectBehavior ~= "hidden") then
					local target = caction.RequireTargets and CombatActionGetOneAttackableEnemy(caction, self)
					state = caction:GetVisibility({self}, target)
				end
			end

			-- special-case grenade throws in case multiple identical grenades are equipped
			if state ~= "hidden" then -- todo: remove this special case, make it generic, it causes issues with displaying signatures
				local action_type
				if string.match(id, "DoubleToss") then 
					action_type = "DoubleToss"
				elseif string.match(id, "ThrowGrenade") then
					action_type = "ThrowGrenade"
				end
				if action_type then
					grenadeModes[action_type] = grenadeModes[action_type] or {}
					local weapon = caction:GetAttackWeapons(self)
					if not weapon or grenadeModes[action_type][weapon.class] then
						state = "hidden"
						if action_type == "DoubleToss" then
							doubleTossCount = doubleTossCount + 1
							if doubleTossCount == 4 then
								state = "disabled"
							end
						end
					end
					if weapon then
						grenadeModes[action_type][weapon.class] = grenadeModes[action_type][weapon.class] or {}
						local equipped = self.current_weapon == "Handheld A" and (id == "ThrowGrenadeA" or  id == "ThrowGrenadeB") or
						                 self.current_weapon == "Handheld B" and (id == "ThrowGrenadeC" or  id == "ThrowGrenadeD")
						grenadeModes[action_type][weapon.class][id] = equipped
					end
				end
			end

			if state ~= "hidden" then
				local firingModeId = caction.FiringModeMember
				if firingModeId and ui_actions[firingModeId] == "enabled" then
					-- Firing mode actions are shown in the position of the first action in the mode,
					-- the mode actions themselves are not shown.
					if firingModes[firingModeId].take_idx_from == id then
						table.insert(ui_actions, vis_idx, firingModeId)
						vis_idx = vis_idx + 1
					end
				elseif CombatActions[id].group ~= "Hidden" then
					table.insert(ui_actions, vis_idx, id)
					vis_idx = vis_idx + 1
				end
				ui_actions[id] = state
			elseif caction.ShowIn ~= "Special" and not caction.ShowIn then
				ui_actions[#ui_actions + 1] = id
			end
		end
		
		--go through the grenade modes to place equipped in ui_actions with priority (to first consume from equipped nades)
		for action, _ in pairs(grenadeModes) do
			for grenadeType, _ in pairs(grenadeModes[action]) do
				for actionName, _ in pairs (grenadeModes[action][grenadeType]) do
					if grenadeModes[action][grenadeType][actionName] and not table.find(ui_actions, actionName) then
						for otherActionName, _ in pairs (grenadeModes[action][grenadeType]) do
							if table.find(ui_actions, otherActionName) then
								ui_actions[otherActionName] = nil
								ui_actions[actionName] = "enabled"
								ui_actions[table.find(ui_actions, otherActionName)] = actionName
								break
							end
						end
					end
				end
			end
		end
	end
	
	-- Put the signature ability in the 13th place always
	for i, id in ipairs(ui_actions) do 
		local caction = CombatActions[id]
		if caction.group == "SignatureAbilities" then
			if ui_actions[13] then
				local swapped = table.remove(ui_actions, 13)
				ui_actions[i] = swapped
				ui_actions[13] = id
			else
				table.remove(ui_actions, i)
				if #ui_actions < 12 then
					for j = #ui_actions + 1, 12 do
						ui_actions[j] = "empty"
					end
				end
				ui_actions[13] = id
			end
			break
		end
	end
	
	if vis_idx > 14 then
		-- Remove item skills. They will be represented by ItemSkills.
		for i, itemSkill in ipairs(itemCombatSkillsList) do
			if ui_actions[itemSkill] then
				local actionIdx = table.find(ui_actions, itemSkill)
				if actionIdx then
					table.remove(ui_actions, actionIdx)
					vis_idx = vis_idx - 1
				end
			end
		end
		vis_idx = vis_idx + 1
	else
		ui_actions["ItemSkills"] = false
	end
	
	assert(vis_idx <= 14, "This unit has too many actions - they cant fit on the UI! (12)")

	if self == Selection[1] then
		local allMatch = false
		-- Verify that any actions have changed.
		if old_actions then
			allMatch = true
			for i, a in ipairs(old_actions) do
				if ui_actions[i] ~= a or old_actions[a] ~= ui_actions[a] then
					allMatch = false
					break
				end
			end
		end
		if not allMatch or force then ObjModified("combat_bar") end
	end
	return ui_actions
end

local function OnUnitInventoryChanged(obj)
	obj:FlushCombatCache()
	Notify(obj, "OnGearChanged")
	if not obj:IsNPC() then
		obj:RecalcUIActions()
	end
	if obj == SelectedObj then 
		if g_Combat and GetInGameInterfaceMode() ~= "IModeCombatMovement" then
			SetInGameInterfaceMode("IModeCombatMovement")
		end
		PrecalcUIIfNeeded(obj)
	end
end

function OnMsg.InventoryChange(obj)
	if not IsKindOf(obj, "Unit") then return end 
	if HasCombatActionInProgress(obj) then
		CreateGameTimeThread(function()
			WaitCombatActionsEnd(obj)
			OnUnitInventoryChanged(obj)
		end)
	else
		OnUnitInventoryChanged(obj)
	end
end

function OnMsg.WeaponReloaded(unit)
	if IsKindOf(unit, "Unit") then
		CreateGameTimeThread(function()
			unit:RecalcUIActions()			
			PrecalcUIIfNeeded(unit)
		end)
	end
end

-- UI Actions update
MapVar("g_UIActionsThread", false)
local lastUIActionsUpdateTime = false

local function lUIActionsUpdate()
	-- During combat initiation a lot of units reposition and spam this function.
	if g_Combat and not g_Combat.combat_started then return end
	
	if IsValidThread(g_UIActionsThread) or (g_UIActionsThread and GameTime() == lastUIActionsUpdateTime) then
		return
	end
	lastUIActionsUpdateTime = GameTime()

	-- run in a thread to avoid overly aggressive updates 
	g_UIActionsThread = CreateGameTimeThread(function()
		if IsSetpiecePlaying() then return end
		if not SelectedObj then return end
		WaitCombatActionsEnd(SelectedObj)
		if not SelectedObj then return end
		SelectedObj:FlushCombatCache()
		SelectedObj:RecalcUIActions()
		g_UIActionsThread = false
	end)
end

OnMsg.CombatStart = lUIActionsUpdate
OnMsg.TurnStart = lUIActionsUpdate
OnMsg.CombatEnd = lUIActionsUpdate
OnMsg.CombatActionEnd = lUIActionsUpdate
OnMsg.UnitAPChanged = lUIActionsUpdate

function OnMsg.UnitMovementDone(unit)
	if unit:IsAmbientUnit() then return end
	if not g_Combat and not (unit.team and unit.team:IsPlayerControlled()) then return end
	
	for _, u in ipairs(g_Units) do
		if u == unit or u:GetLastAttack() == unit then
			u.last_attack_session_id = false
		end
	end
	lUIActionsUpdate()
end

--- Unit Order, Used to order the targets above the combat action bar.

MapVar("g_unitOrder", {})

---
--- Updates the UI order for all enemy units of the given team.
---
--- @param team table The team whose enemy units' UI order should be updated.
---
function UpdateEnemyUIOrder(team)
	if not team or not team.player_team then return end
	
	g_unitOrder = {}
	for i, u in ipairs(team.units) do
		UpdateEnemyUIOrderForUnit(u)
	end
end

---
--- Updates the UI order for a single enemy unit.
---
--- @param unit table The enemy unit whose UI order should be updated.
---
function UpdateEnemyUIOrderForUnit(unit)
	local unitOrder = {}
	for i, otherU in ipairs(g_Units) do
		local x, y, z = SnapToPassSlabXYZ(otherU)
		local dist = x and unit:GetDist(x, y, z) or unit:GetDist(otherU)
		-- Enemies with good attacks are prioritized
		if UIIsEnemyAttackGood(otherU) then dist = -(max_int-dist) end
		unitOrder[otherU] = dist
	end
	g_unitOrder[unit] = unitOrder
end

function OnMsg.TurnStart(teamId)
	UpdateEnemyUIOrder(g_Teams[teamId])
end

function OnMsg.UnitMovementDone(obj)
	UpdateEnemyUIOrder(obj and obj.team)
end