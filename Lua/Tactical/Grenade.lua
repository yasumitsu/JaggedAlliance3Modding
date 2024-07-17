local dirPX = 0
local dirNX = 1
local dirPY = 2
local dirNY = 3
local dirPZ = 4
local dirNZ = 5
local sizex = const.SlabSizeX
local sizey = const.SlabSizeY
local sizez = const.SlabSizeZ

MapVar("MapIncendiaryGrenadeZones", {})
MapVar("MapSmokeZones", {})
MapVar("MapFlareOnGround", {})

DefineClass.Grenade = {
	__parents = { "QuickSlotItem", "GrenadeProperties", "InventoryStack", "BaseWeapon", "BobbyRayShopOtherProperties" },
	RolloverClassTemplate = "Throwables",
	base_skill = "Dexterity",
}

---
--- Returns the rollover type for the grenade item.
---
--- @return string The rollover type for the grenade item.
function Grenade:GetRolloverType()
	return self.ItemType or "Throwables"
end

---
--- Returns the accuracy of the grenade when thrown at the given distance.
---
--- @param dist number The distance the grenade is being thrown.
--- @return number The accuracy of the grenade throw, as a percentage.
function Grenade:GetAccuracy(dist)
	return 100
end

---
--- Returns the maximum range at which the grenade can be aimed and thrown.
---
--- @param unit Unit The unit throwing the grenade.
--- @return number The maximum range at which the grenade can be aimed and thrown.
function Grenade:GetMaxAimRange(unit)
	local str = IsKindOf(unit, "Unit") and unit.Strength or 100
	local range = MulDivRound(self.BaseRange, Max(0, 100 - str), 100) + MulDivRound(self.ThrowMaxRange, Min(100, str), 100)
	return Max(1, range)
end

---
--- Returns the maximum range at which the grenade can be thrown.
---
--- @return number The maximum range of the grenade throw.
function Grenade:GetMaxRange()
	return self.AreaOfEffect * const.SlabSizeX * 3 / 2
end

---
--- Checks if the grenade is a gas grenade based on the given or the grenade's own AOE type.
---
--- @param aoeType string The AOE type of the grenade, or nil to use the grenade's own AOE type.
--- @return boolean True if the grenade is a gas grenade, false otherwise.
function Grenade:IsGasGrenade(aoeType)
	aoeType = aoeType or self.aoeType
	return aoeType == "smoke" or aoeType == "teargas" or aoeType == "toxicgas"
end

---
--- Checks if the grenade is a fire grenade based on the given or the grenade's own AOE type.
---
--- @param aoeType string The AOE type of the grenade, or nil to use the grenade's own AOE type.
--- @return boolean True if the grenade is a fire grenade, false otherwise.
function Grenade:IsFireGrenade(aoeType)
	return (aoeType or self.aoeType) == "fire"
end

---
--- Prepares the grenade for throwing by the given thrower.
---
--- If the grenade is an explosive grenade, this function will show the throwing tutorial.
---
--- @param thrower Unit The unit throwing the grenade.
--- @param visual any The visual object associated with the grenade.
---
function Grenade:OnPrepareThrow(thrower, visual)
	if InventoryItemDefs[self.class] and InventoryItemDefs[self.class].group == "Grenade - Explosive" then
		ShowThrowingTutorial()
	end
end

---
--- Called when the grenade has finished being thrown by the given thrower.
---
--- If the current tutorial is the "Throwing" tutorial, this function sets the `TutorialHintsState.Throwing` flag to `true`.
---
--- @param thrower Unit The unit that threw the grenade.
---
function Grenade:OnFinishThrow(thrower)
	if GetCurrentOpenedTutorialId() == "Throwing" then
		TutorialHintsState.Throwing = true
	end
end

---
--- Called when the grenade is thrown by the given thrower.
---
--- This function sets the "fly" animation on the visual objects associated with the grenade, and sets the `TutorialHintsState.Throwing` flag to `true` if the current tutorial is the "Throwing" tutorial.
---
--- @param thrower Unit The unit that threw the grenade.
--- @param visual_objs table A table of visual objects associated with the grenade.
---
function Grenade:OnThrow(thrower, visual_objs)	
	for _, obj in ipairs(visual_objs) do
		if obj:HasAnim("fly") then
			obj:SetAnim(1, "fly")
		end
	end
	
	if GetCurrentOpenedTutorialId() == "Throwing" then
		TutorialHintsState.Throwing = true
	end
end

---
--- Called when the grenade has landed on the ground.
---
--- This function plays a noise alert for the landing of the grenade, applies the explosion damage, and destroys the visual object associated with the grenade.
---
--- @param thrower Unit The unit that threw the grenade.
--- @param attackResults table The results of the attack, including the area of effect type and whether the ground should be burned.
--- @param visual_obj any The visual object associated with the grenade.
---
function Grenade:OnLand(thrower, attackResults, visual_obj)
	if not CurrentThread() then
		CreateGameTimeThread(Grenade.OnLand, self, thrower, attackResults, visual_obj)
		return
	end
	Sleep(160)
	if self.ThrowNoise > 0 then
		-- <Unit> Heard a thud
		PushUnitAlert("noise", visual_obj, self.ThrowNoise, Presets.NoiseTypes.Default.ThrowableLandmine.display_name)
	end
	if self.Noise > 0 then
		PushUnitAlert("noise", visual_obj, self.Noise, Presets.NoiseTypes.Default.Grenade.display_name)
	end
	attackResults.aoe_type = self.aoeType
	attackResults.burn_ground = self.BurnGround
	ApplyExplosionDamage(thrower, visual_obj, attackResults)
	if IsValid(visual_obj) and not IsKindOf(visual_obj, "GridMarker") then
		DoneObject(visual_obj)
	end
end

Grenade.PrecalcDamageAndStatusEffects = ExplosionPrecalcDamageAndStatusEffects

---
--- Calculates the damage bonus for a unit's use of grenades.
---
--- @param unit Unit The unit whose grenade damage bonus is being calculated.
--- @return number The grenade damage bonus for the given unit.
---
function GetGrenadeDamageBonus(unit)
	return MulDivRound(const.Combat.GrenadeStatBonus, unit.Explosives, 100)
end

---
--- Calculates the area of effect parameters for a grenade attack.
---
--- @param action_id string The ID of the action being performed.
--- @param attacker Unit The unit that is attacking with the grenade.
--- @param target_pos Vector3 The position of the target.
--- @param step_pos Vector3 The position of the step.
--- @return table The area of effect parameters for the grenade attack.
---
function Grenade:GetAreaAttackParams(action_id, attacker, target_pos, step_pos)
	target_pos = target_pos or self:GetPos()
	local aoeType = self.aoeType
	local max_range = self.AreaOfEffect
	if aoeType == "fire" then
		max_range = 2
	end
	local params = {
		attacker = false,
		weapon = self,
		target_pos = target_pos,
		step_pos = target_pos,
		stance = "Prone",
		min_range = self.AreaOfEffect,
		max_range = max_range,
		center_range = self.CenterAreaOfEffect,
		damage_mod = 100,
		attribute_bonus = 0,
		can_be_damaged_by_attack = true,
		aoe_type = aoeType,
		explosion = true, -- damage dealt depends on target stance
		explosion_fly = self.DeathType == "BlowUp",
	}
	if self.coneShaped then
		params.cone_length = self.AreaOfEffect * const.SlabSizeX
		params.cone_angle = self.coneAngle * 60
		params.target_pos = RotateRadius(params.cone_length, CalcOrientation(step_pos or attacker, target_pos), target_pos)
		if not params.target_pos:IsValidZ() or params.target_pos:z() - terrain.GetHeight(params.target_pos) <= 10*guic then
			params.target_pos = params.target_pos:SetTerrainZ(10*guic)
		end
	end
	if IsKindOf(attacker, "Unit") then
		params.attacker = attacker
		--params.attribute_bonus = GetGrenadeDamageBonus(attacker) -- already applied in GetBaseDamage
	end
	return params
end

local GrenadeCustomDescriptions = {
	["fire"] = T(933586341461, "Sets an area on fire and inflicts <em>Burning</em>."),
	["smoke"] = T(487595290755, "Ranged attacks passing through gas become <em>grazing</em> hits."),
	["teargas"] = T(411101296173, "Inflicts <em>Blinded</em>, making affected characters less accurate. Ranged attacks passing through gas become <em>grazing</em> hits."),
	["toxicgas"] = T(298305721189, "Inflicts <em>Choking</em>, forcing affected characters to take damage and lose energy, eventually fall <em>unconscious</em>. Ranged attacks passing through gas become <em>grazing</em> hits."),
}

--- Returns a custom action description for the grenade based on its aoeType.
---
--- @param units table The units affected by the grenade.
--- @return string The custom action description for the grenade.
function Grenade:GetCustomActionDescription(units)
	return GrenadeCustomDescriptions[self.aoeType] -- if the table value is nil the default action description will be used
end

---
--- Applies explosion damage to targets within the specified area of effect.
---
--- @param attacker table The unit or object that caused the explosion.
--- @param weapon table The weapon or explosive object that caused the explosion.
--- @param pos point The position of the explosion.
--- @param fx_actor table The visual effect actor for the explosion.
--- @param force_flyoff boolean If true, forces all affected units to be knocked back by the explosion.
--- @param disableBurnFx boolean If true, disables any burn effects from the explosion.
--- @param ignore_targets table A list of units to ignore when applying explosion damage.
--- @return table The results of the area attack, including information about damaged and killed units.
function ExplosionDamage(attacker, weapon, pos, fx_actor, force_flyoff, disableBurnFx, ignore_targets)
	local aoe_params = weapon:GetAreaAttackParams(nil, attacker, pos)
	local effects = {}
	if not aoe_params.aoe_type or aoe_params.aoe_type == "none" then
		effects[1] = "CancelShot"
	end
	if (weapon.AppliedEffect or "") ~= "" then
		effects[#effects + 1] = weapon.AppliedEffect
	end
	aoe_params.prediction = false
	local original_mask
	if attacker and attacker.spawned_by_explosive_object then
		original_mask = collision.GetAllowedMask(attacker.spawned_by_explosive_object)
		local ignore_self = 0
		collision.SetAllowedMask(attacker.spawned_by_explosive_object, ignore_self)
	end
	
	local results = GetAreaAttackResults(aoe_params, 0, effects)
	CompileKilledUnits(results)
	
	if original_mask then
		collision.SetAllowedMask(attacker.spawned_by_explosive_object, original_mask)
	end
	
	if force_flyoff then
		for i, h in ipairs(results) do
			h.explosion_fly = true
		end
	end
	if IsKindOf(weapon, "ExplosiveProperties") then
		results.burn_ground = weapon.BurnGround
	end
	results.weapon = weapon
	ApplyExplosionDamage(attacker, fx_actor, results, weapon.Noise, disableBurnFx, ignore_targets)
end

---
--- Gets the position of the explosion decal.
---
--- @param pos point The position of the explosion.
--- @return point The position of the explosion decal.
---
function GetExplosionDecalPos(pos)
	local offset = guim
	local lowest_z = pos:z()
	for dx = -offset, offset, offset do
		for dy = -offset, offset, offset do
			local z = terrain.GetHeight(pos + point(dx, dy, 0))
			lowest_z = (z < lowest_z) and z or lowest_z
		end
	end
	lowest_z = Max(lowest_z, pos:z() - guim)
	return pos:SetZ(lowest_z - 25 * guic)
end

MapVar("g_LastExplosionTime", false)

local function igMolotovDestroyOrBurn(obj, dist2)
	if dist2 < sizex*sizex then
		return "destroy"
	end
	if dist2 > 2*sizex*sizex then
		return "impact"
	end
	return InteractionRand(100, "Explosion") < 50 and "destroy" or "burn"
end

local function igExplosionDestroyOrBurn(obj, dist2, range)
	if dist2 > range*range then
		return "impact"
	end
	return "destroy"
end

local function GetExplosionFXPos(visual_obj_or_pos)
	local pos = IsPoint(visual_obj_or_pos) and visual_obj_or_pos or visual_obj_or_pos:GetPos() --light fx use this pos, alternatively we could make them not affect stealth
	if not pos:IsValidZ() then
		pos = pos:SetTerrainZ() -- only when pos is on invalidz so we can still get walkable slabs that are over the terrain if the position is right
	end
	local slab, slab_z = WalkableSlabByPoint(pos)
	local z = pos:z()
	
	if slab_z then
		if slab_z <= z and slab_z >= z - guim then
			pos = pos:SetZ(slab_z)
		end
	else
		pos = GetExplosionDecalPos(pos)
	end
	
	return pos
end

---
--- Applies explosion damage to targets within the explosion's area of effect.
---
--- @param attacker Unit|nil The unit that caused the explosion.
--- @param fx_actor CombatObject|Point The object or position where the explosion visual effects should be played.
--- @param results table A table of explosion hit results, containing information about the damage and effects of the explosion.
--- @param noise CombatObject|nil The object that caused the noise of the explosion.
--- @param disableBurnFx boolean|nil Whether to disable the burn visual effects.
--- @param ignore_targets table|nil A table of targets to ignore for the explosion damage.
---
function ApplyExplosionDamage(attacker, fx_actor, results, noise, disableBurnFx, ignore_targets)
	if not CurrentThread() then
		CreateGameTimeThread(ApplyExplosionDamage, attacker, fx_actor, results, noise, disableBurnFx)
		return
	end

	local gas = results.aoe_type == "smoke" or results.aoe_type == "teargas" or results.aoe_type == "toxicgas"
	local fire = results.aoe_type == "fire"
	
	local pos
	local surf_fx_type
	local fx_action
	if fx_actor then
		pos = GetExplosionFXPos(fx_actor)
		surf_fx_type = GetObjMaterial(pos)
		if fire then
			fx_action = "ExplosionFire"
		elseif gas then
			fx_action = "ExplosionGas"
		else
			fx_action = "Explosion"
		end
		PlayFX(fx_action, "start", fx_actor, surf_fx_type, pos)
	end
	Sleep(100)
	if fx_actor and not disableBurnFx then
		PlayFX(fx_action, "end", fx_actor, surf_fx_type, pos)
	end
	local burn_ground = true
	if results.burn_ground ~= nil then
		burn_ground = results.burn_ground
	end
	if not fire and not gas and burn_ground and results.target_pos then
		--PlaceWindModifierExplosion(results.target_pos, results.range)
		if not disableBurnFx then
			local fDestroyOrBurn = (results.aoe_type == "fire") and igMolotovDestroyOrBurn or igExplosionDestroyOrBurn
			Explosion_ProcessGrassAndShrubberies(results.target_pos, results.range/2, fDestroyOrBurn)
		end
	end

	local attack_reaction, weapon
	if IsKindOf(attacker, "DynamicSpawnLandmine") and IsKindOf(attacker.attacker, "Unit") then
		attack_reaction = true
		weapon = attacker
		attacker = attacker.attacker
	elseif IsKindOf(attacker, "Unit") then
		attack_reaction = true
		weapon = results.weapon
	end
	
	local hit_units = {}
	ignore_targets = ignore_targets or empty_table
	for _, hit in ipairs(results) do
		local obj = hit.obj
		hit.explosion = true
		if IsValid(obj) then --after fx sleep this obj can no longer be valid
			if not ignore_targets[obj] then
				if IsKindOf(obj, "Unit") then
					if not hit_units[obj] then
						hit_units[obj] = hit
					else
						hit_units[obj].damage = hit_units[obj].damage + hit.damage
					end
				elseif IsKindOf(obj, "CombatObject") then
					obj:TakeDamage(hit.damage, attacker, hit)
				elseif IsKindOf(obj, "Destroyable") and hit.damage > 0 then
					obj:Destroy()
				end
			end
		end
	end
	--pp units so they know wheather they would need to fall down before dying
	for u, hit in sorted_handled_obj_key_pairs(hit_units or empty_table) do
		if not ignore_targets or not ignore_targets[u] then
			u:ApplyDamageAndEffects(attacker, hit.damage, hit, hit.armor_decay)
		end
	end
	
	if fx_actor and attacker and not attacker.spawned_by_explosive_object then
		PushUnitAlert("thrown", fx_actor, attacker)
	end
	if fx_actor and noise then
		PushUnitAlert("noise", fx_actor, noise, Presets.NoiseTypes.Default.Explosion.display_name)
	end
	
	if fire then
		ExplosionCreateFireAOE(attacker, results, fx_actor)
	elseif gas then
		ExplosionCreateSmokeAOE(attacker, results, fx_actor)
	end

	if attack_reaction then
		AttackReaction("ThrowGrenadeA", {obj = attacker, weapon = weapon}, results)
	end
	NetUpdateHash("g_LastExplosionTime_set")
	g_LastExplosionTime = GameTime()
end

---
--- Generates a table of all Grenade inventory item IDs.
---
--- @param items table|nil A table to append the Grenade item IDs to. If not provided, a new table will be created.
--- @return table A table containing all Grenade inventory item IDs.
function GrenadesComboItems(items)
	items = items or {}
	ForEachPresetInGroup("InventoryItemCompositeDef", "Grenade", function(o) items[#items+1] = o.id end)
	return items
end

---
--- Calculates the trajectory of a grenade thrown by the given attack arguments.
---
--- @param attack_args table The attack arguments, including the attacker object, animation, and other relevant data.
--- @param target_pos vector3 The target position for the grenade.
--- @param angle number The angle at which the grenade should be launched, in radians. If not provided, the angle will be determined based on the relative heights of the attacker and target.
--- @param max_bounces number The maximum number of bounces the grenade can make before landing.
--- @return table A table containing the trajectory of the grenade, represented as a series of positions.
---
function Grenade:CalcTrajectory(attack_args, target_pos, angle, max_bounces)
	local attacker = attack_args.obj
	local anim_phase = attacker:GetAnimMoment(attack_args.anim, "hit") or 0
	local attack_offset = attacker:GetRelativeAttachSpotLoc(attack_args.anim, anim_phase, attacker, attacker:GetSpotBeginIndex("Weaponr"))
	local step_pos = attack_args.step_pos
	if not step_pos:IsValidZ() then
		step_pos = step_pos:SetTerrainZ()
	end
	local pos0 = step_pos:SetZ(step_pos:z() + attack_offset:z())
	if not angle then
		if target_pos:z() - pos0:z() > const.SlabSizeZ / 2 then
			angle = const.Combat.GrenadeLaunchAngle_Incline
		else
			angle = const.Combat.GrenadeLaunchAngle
		end
	end
	local sina, cosa = sincos(angle)
	local aim_pos = pos0 + Rotate(point(cosa, 0, sina), CalcOrientation(pos0, target_pos))
	local grenade_pos = GetAttackPos(attack_args.obj, step_pos, axis_z, attack_args.angle, aim_pos, attack_args.anim, anim_phase, attack_args.weapon_visual)
	if grenade_pos:Equal2D(target_pos) then
		return empty_table
	end

	local dir = target_pos - grenade_pos
	local bounce_diminish = 40
	local vec
	local can_bounce = self.CanBounce
	if attack_args.can_bounce ~= nil then
		can_bounce = attack_args.can_bounce
	end
	max_bounces = can_bounce and max_bounces or 0
	if can_bounce then
		max_bounces = 1
	end
	if max_bounces > 0 then
		local coeff = 1000
		local d = 10 * bounce_diminish
		for i = 1, max_bounces do
			coeff = coeff + d
			d = MulDivRound(d, bounce_diminish, 100)
		end
		local bounce_target_pos = grenade_pos + MulDivRound(dir, 1000, coeff)
		vec = CalcLaunchVector(grenade_pos, bounce_target_pos, angle, const.Combat.Gravity)
	else
		vec = CalcLaunchVector(grenade_pos, target_pos, angle, const.Combat.Gravity)
	end
	local time = MulDivRound(grenade_pos:Dist2D(target_pos), 1000, Max(vec:Len2D(), 1))
	if time == 0 then
		return empty_table
	end
	local trajectory = CalcBounceParabolaTrajectory(grenade_pos, vec, const.Combat.Gravity, time, 20, max_bounces, bounce_diminish)
	return trajectory
end

---
--- Validates the given explosion position.
---
--- @param explosion_pos table The position of the explosion.
--- @return table The validated explosion position.
function Grenade:ValidatePos(explosion_pos)
	return explosion_pos
end

---
--- Calculates the trajectory of a grenade thrown from the given attack position to the target position.
---
--- @param attack_args table The attack arguments, including information about the attacker, target, and other parameters.
--- @param attack_pos table The position from which the grenade is launched.
--- @param target_pos table The target position for the grenade.
--- @param mishap boolean Whether the grenade trajectory is a mishap (i.e. an unintended deviation from the target).
--- @return table The calculated trajectory of the grenade.
function Grenade:GetTrajectory(attack_args, attack_pos, target_pos, mishap)
	if not attack_pos and attack_args.lof then
		local lof_idx = table.find(attack_args.lof, "target_spot_group", attack_args.target_spot_group)
		local lof_data = attack_args.lof[lof_idx or 1]
		attack_pos = lof_data.attack_pos
	end

	if not attack_pos then 
		return {}
	end
	
	-- sanity-check the target pos
	local pass = SnapToPassSlab(target_pos)
	local valid_target = true
	if pass then
		pass = pass:IsValidZ() and pass or pass:SetTerrainZ()
		if abs(pass:z() - target_pos:z()) >= 2*const.SlabSizeZ then
			valid_target = false
		end
	else 
		valid_target = false
	end
		
	-- try the different trajectories to pick a suitable one
	local angles = {}
		
	if valid_target or mishap then 
		if target_pos:z() - attack_pos:z() >= 2*const.SlabSizeZ then
			angles[1] = const.Combat.GrenadeLaunchAngle_Incline
			angles[2] = const.Combat.GrenadeLaunchAngle
		else
			-- throwing down/level, prefer low arc
			if target_pos:z() - attack_pos:z() <= const.SlabSizeZ / 2 then
				angles[1] = const.Combat.GrenadeLaunchAngle_Low
			end
			angles[#angles+1] = const.Combat.GrenadeLaunchAngle
			if not GameState.Underground then
				angles[#angles+1] = const.Combat.GrenadeLaunchAngle_Incline
			end
		end
	end
	
	local attacker = attack_args.obj

	local best_dist, best_trajectory = attacker:GetDist(target_pos), {}
	for _, angle in ipairs(angles) do		
		local trajectory = self:CalcTrajectory(attack_args, target_pos, angle, (angle == const.Combat.GrenadeLaunchAngle_Low) and 1 or 0)		
		local hit_pos = (#trajectory > 0) and trajectory[#trajectory].pos
		if hit_pos and (hit_pos:Dist(trajectory[1].pos) > 0) then 
			if IsCloser(hit_pos, target_pos, const.SlabSizeX) then
				return trajectory
			end
			local dist = hit_pos:Dist(target_pos)
			if dist < best_dist then
				best_dist, best_trajectory = dist, trajectory
			end
		end
	end
	return best_trajectory
end

---
--- Calculates the attack results for a grenade action, including the trajectory, explosion position, and area-of-effect damage.
---
--- @param action table The action object that triggered the attack.
--- @param attack_args table The arguments for the attack, including the attacker, target position, and other relevant data.
--- @return table The results of the attack, including the trajectory, explosion position, and damage to units.
---
function Grenade:GetAttackResults(action, attack_args)
	local attacker = attack_args.obj
	local explosion_pos = attack_args.explosion_pos
	local trajectory = {}
	local mishap
	if not explosion_pos and attack_args.lof then
		local lof_idx = table.find(attack_args.lof, "target_spot_group", attack_args.target_spot_group)
		local lof_data = attack_args.lof[lof_idx or 1]
		local attack_pos = lof_data.attack_pos
		local target_pos = lof_data.target_pos

		-- mishap & stealth kill checks
		if not attack_args.prediction and IsKindOf(self, "MishapProperties") then
			local chance = self:GetMishapChance(attacker, target_pos)
			if CheatEnabled("AlwaysMiss") or attacker:Random(100) < chance then
				mishap = true

				-- Try a couple of times to get a valid deviated position
				local validPositionTries = 0
				local maxPositionTries = 5
				while validPositionTries < maxPositionTries do
					local dv = self:GetMishapDeviationVector(attacker, target_pos)
					local deviatePosition = target_pos + dv
					local trajectory = self:GetTrajectory(attack_args, attack_pos, deviatePosition, "mishap")
					local finalPos = #trajectory > 0 and trajectory[#trajectory].pos
					if finalPos and self:ValidatePos(finalPos, attack_args) then
						target_pos = deviatePosition
						break
					end
					validPositionTries = validPositionTries + 1
				end
				attacker:ShowMishapNotification(action)
			end
		end

		trajectory = self:GetTrajectory(attack_args, attack_pos, target_pos, mishap)
		if #trajectory > 0 then
			explosion_pos = trajectory[#trajectory].pos
		end
		explosion_pos = self:ValidatePos(explosion_pos, attack_args)
	end
	
	local results
	if explosion_pos then
		local aoe_params = self:GetAreaAttackParams(action.id, attacker, explosion_pos, attack_args.step_pos)
		if attack_args.stealth_attack then
			aoe_params.stealth_attack_roll = not attack_args.prediction and attacker:Random(100) or 100
		end
		aoe_params.prediction = attack_args.prediction
		if aoe_params.aoe_type ~= "none" or IsKindOf(self, "Flare") then
			aoe_params.damage_mod = "no damage"
		end
		results = GetAreaAttackResults(aoe_params)
		CompileKilledUnits(results)

		local radius = aoe_params.max_range * const.SlabSizeX
		local explosion_voxel_pos = SnapToVoxel(explosion_pos) + point(0, 0, const.SlabSizeZ / 2)
		local impact_force = self:GetImpactForce()
		local unit_damage = {}
		for _, hit in ipairs(results) do
			local obj = hit.obj
			if not obj or hit.damage == 0 then goto continue end
			
			local dist = hit.obj:GetDist(explosion_voxel_pos)
			if IsKindOf(obj, "Unit") then
				if not obj:IsDead() then
					unit_damage[obj] = (unit_damage[obj] or 0) + hit.damage
					if unit_damage[obj] >= obj:GetTotalHitPoints() then
						results.killed_units = results.killed_units or {}
						table.insert_unique(results.killed_units, obj)
					end
				end
			end
			hit.impact_force = impact_force + self:GetDistanceImpactForce(dist)
			hit.explosion = true
			::continue::
		end
	else
		results = {}
	end
	results.trajectory = trajectory
	results.explosion_pos = explosion_pos
	results.weapon = self
	results.mishap = mishap
	results.no_damage = IsKindOf(self, "Flare")
	
	return results
end

--- Creates a visual object for the grenade.
---
--- @param owner Unit The unit that owns the grenade.
--- @return GrenadeVisual The created visual object.
function Grenade:CreateVisualObj(owner)
	local grenade = owner:AttachGrenade(self)
	return grenade
end

--- Gets the visual object for the grenade.
---
--- @param attacker Unit The unit that owns the grenade.
--- @param force boolean If true, forces the creation of a new visual object.
--- @return GrenadeVisual The visual object for the grenade.
function Grenade:GetVisualObj(attacker, force)
	local grenade = attacker:GetAttach("GrenadeVisual")
	if not grenade or force then
		-- AI has skipped the UI part
		grenade = attacker:AttachGrenade(self)
	end
	return grenade
end

---[[
--- Adds a debug voxel to the scene.
---
--- @param pt Vector3 The position of the voxel.
--- @param color Color The color of the voxel.
function DbgAddVoxel(pt, color)
	pt = SnapToVoxel(pt)
	local x, y, z = pt:xyz()
	local bx = box(x - const.SlabSizeX/2, y - const.SlabSizeY/2, z, x + const.SlabSizeX/2, y + const.SlabSizeY/2, z + const.SlabSizeZ)
	DbgAddBox(bx, color)
end

--- Calculates the launch vector for a grenade based on the start and end positions, launch angle, and gravity.
---
--- @param start_pt Vector3 The starting position of the grenade.
--- @param end_pt Vector3 The target position of the grenade.
--- @param angle number The launch angle in radians (optional, defaults to const.Combat.GrenadeLaunchAngle).
--- @param gravity number The gravity acceleration (optional, defaults to const.Combat.Gravity).
--- @return Vector3 The launch vector for the grenade.
function CalcLaunchVector(start_pt, end_pt, angle, gravity)
	if not start_pt or not end_pt then
		return
	end
	assert(start_pt:IsValidZ() and end_pt:IsValidZ())

	angle = angle or const.Combat.GrenadeLaunchAngle

	local dist = start_pt:Dist2D(end_pt)
	local dir = SetLen((end_pt - start_pt):SetZ(0), guim)

	local y0 = start_pt:z()
	local yt = end_pt:z()

	local sina, cosa = sin(angle), cos(angle)

	local t1 = MulDivRound(gravity or const.Combat.Gravity, dist*dist, guim) -- scale guim^2
	local t2 = 2*cosa*cosa -- scale 4k^2
	local t3 = (yt - y0) * guim -- scale guim^2
	local t4 = MulDivRound(dist, sina * guim, cosa) -- scale guim^2

	local v0 = MulDivRound(sqrt(t1), guim, Max(1, MulDivRound(sqrt(t2), sqrt(Max(0, -t3+t4)), 4096)))
	local v0x = MulDivRound(v0, cosa, 4096)
	local v0y = MulDivRound(v0, sina, 4096)

	return SetLen(dir, v0x) + point(0, 0, v0y)
end

---
--- Checks if the given object is a breakable window.
---
--- @param obj table The object to check.
--- @return boolean True if the object is a breakable window, false otherwise.
function IsBreakableWindow(obj)
	return IsKindOf(obj, "SlabWallWindow") and obj:IsWindow() and obj:IsBreakable() and not obj:IsBroken()
end

--[[
function CalcBounceParabolaTrajectory(start_pt, launch_speed, gravity, time, tStep, max_bounces, diminish, no_collision)
	local t = 0	
	local pos = start_pt
	local v = launch_speed
	local vg = point(0, 0, -(gravity or const.Combat.Gravity))
	local trajectory = {}
	local bounce_flags = const.efVisible + const.efCollision

	if not v:IsValidZ() then
		v = v:SetZ(0)
	end

	while terrain.IsPointInBounds(pos) and pos:z() >= terrain.GetHeight(pos) do
		table.insert(trajectory, { pos = pos, t = t })

		t = t + tStep
		local vnext = v + MulDivRound(vg, tStep, 1000)
		local posnext = pos + MulDivRound(vnext, tStep, 1000)
		local hit_water

		local function bounce(pt, normal, obj)
			if hit_water then 
				return 
			end
			
			if normal == point30 then
				normal = axis_z
			end
			local len = Dot(normal, v) / normal:Len()
			-- reflect the velocity vector
			local proj = SetLen(normal, len)
			local velocity = vnext:Len()
			vnext = SetLen(vnext - (2 * proj), velocity)
			if diminish then
				vnext = MulDivRound(vnext, diminish, 100)
			end

			-- correct the position
			local move_dist = posnext:Dist(pos)
			local hit_dist = pos:Dist(pt)
			local refl_dist = move_dist - hit_dist
			if refl_dist > 0 and vnext ~= point30 then
				table.insert(trajectory, {pos = pt, t = t - tStep + MulDivRound(tStep, hit_dist, move_dist), obj = obj, bounce = true})
				pos = pt
				posnext = pt + SetLen(vnext, refl_dist)
			end
			max_bounces = max_bounces - 1
		end

		-- window detection
		local ipt = terrain.IntersectSegment(pos, posnext)
		if not no_collision then
			local obj, pt, normal = GetClosestRayObj(pos, ipt or posnext, bounce_flags, 0, function(obj, x, y, z)
				local window = IsBreakableWindow(obj) or nil
				local water = IsKindOf(obj, "WaterPlane") or nil
				if window or water then
					local pt = point(x, y, z)
					local move_dist = posnext:Dist(pos)
					local hit_dist = pos:Dist(pt)
					if hit_dist > 0 and move_dist > 0 and vnext ~= point30 then
						local time = t - tStep + MulDivRound(tStep, hit_dist, move_dist)
						local step = { pos = pt, t = time, obj = obj }
						if window then
							step.window = true
						end
						if water then
							hit_water = #trajectory
							step.water = true
						end
						table.insert(trajectory, step)
						pos = pt
						posnext = pt + SetLen(vnext, hit_dist)
						t = time + tStep
					end
					return false
				end
				return true
			end, 0, const.cmDefaultObject)
			if obj and (not obj:IsKindOf("SlabWallDoor") or obj:IsDead() or obj.pass_through_state ~= "open") then				
				bounce(pt, normal, obj)
				if t >= time or max_bounces < 0 then
					-- end before collision pos to avoid detonating inside collision geometry
					local dist = pos:Dist(pt)
					local adj_dist = dist - 10*guic
					if adj_dist <= 0 then
						break
					end
					local end_pt = pos + SetLen(pt - pos, adj_dist)
					local time = t - tStep + MulDivRound(tStep, adj_dist, dist)
					table.insert(trajectory, { pos = end_pt, obj = obj, t = time })
					break
				end
			end
		end

		if ipt then
			bounce(ipt, terrain.GetTerrainNormal(ipt), "terrain")
			if max_bounces < 0 or t >= time then
				break
			end
		end

		pos, v = posnext, vnext
	end

	-- before returning make sure the trajectory stays above ground & has contents
	if #trajectory == 0 then
		table.insert(trajectory, { pos = start_pt, t = 0 })
	end
	if #trajectory == 1 then
		table.insert(trajectory, { pos = start_pt + SetLen(launch_speed, 10*guic), t = 1 })
	end
	
	for _, step in ipairs(trajectory) do
		if step.pos:z() < terrain.GetHeight(step.pos) then
			step.pos = step.pos:SetTerrainZ()
		end
	end
	
	return trajectory
end
--]]

---
--- Animates the trajectory of a thrown grenade object.
---
--- @param visual_obj FXGrenade The visual object representing the grenade.
--- @param trajectory table A table of trajectory steps, each with a position and time.
--- @param rotation_axis Vector3 The axis around which the grenade rotates.
--- @param rpm number The revolutions per minute of the grenade rotation.
--- @param surf_fx string The name of the surface effect to play when the grenade hits a surface.
--- @param explosion_fx string The name of the explosion effect to play when the grenade detonates.
---
function AnimateThrowTrajectory(visual_obj, trajectory, rotation_axis, rpm, surf_fx, explosion_fx)
	local time = trajectory[#trajectory].t
	local angle = MulDivTrunc(rpm * 360, time, 1000)
	local hit_water

	if rpm ~= 0 then
		visual_obj:SetAxis(rotation_axis)
	end

	local t = 0
	local pos, dir
	
	for i, step in ipairs(trajectory) do
		local step_time = step.t - t
		local dist = pos and step.pos:Dist(pos) or 0
		if dist > 0 then
			dir = step.pos - pos
			--[[if i == 1 and step_time == 0 then
				local idx = i
				local dt, d = 0, 0
				while dt <= 0 or d <= 0 do
					idx = idx + 1
					d = trajectory[idx].pos:Dist(trajectory[i].pos)
					dt = trajectory[idx].t - trajectory[i].t
				end
				step_time = MulDivRound(dt, dist, d)
			end--]]
		end

		step_time = Max(0, step_time)
		pos = step.pos
		visual_obj:SetPos(pos, step_time)
		local st = 0
		while st < step_time do
			local dt = Min(20, step_time - st)
			if rpm ~= 0 then
				visual_obj:SetAngle(visual_obj:GetAngle() + MulDivTrunc(angle, dt, time), dt)
			end
			st = st + dt
			Sleep(dt)
		end
		t = step.t
		local obj = IsValid(step.obj) and step.obj or nil
		if IsBreakableWindow(obj) then
			obj:SetWindowState("broken")
			obj = nil
		end
		if surf_fx and not hit_water and (obj or i == #trajectory or step.bounce) then
			local surf_fx_type = GetObjMaterial(pos, obj)
			local fx_target = surf_fx_type or obj
			PlayFX(surf_fx, "start", visual_obj, fx_target, pos)
		end
		if step.water then
			hit_water = true
		end
	end

	visual_obj:SetAxis(axis_z)
	visual_obj:SetAngle(dir and dir:Len2D() > 0 and CalcOrientation(dir) or 0)

	if explosion_fx then
		local pos = GetExplosionFXPos(visual_obj)
		local surf_fx_type = GetObjMaterial(pos)
		dir = dir and dir:SetZ(0)
		if dir and dir:Len() > 0 then
			dir = SetLen(dir, 4096)
		else
			dir = axis_z
		end
		PlayFX(explosion_fx, "start", visual_obj, surf_fx_type, pos, dir)
	end
	Msg("GrenadeDoneThrow")
end

---
--- Resolves the target position for a grenade based on the given parameters.
---
--- @param target table|vec3 The target object or position.
--- @param startPos vec3 The starting position of the grenade.
--- @param grenade table The grenade object.
--- @return vec3 The resolved target position.
function ResolveGrenadeTargetPos(target, startPos, grenade)
	target = IsValid(target) and target:GetPos() or target
	if not IsPoint(target) then return false end
	
	-- Move target pos a bit behind cursor for cone shaped explosions
	if grenade and grenade.coneShaped and startPos:Dist(target) > 0 then
		local z = target:z()
		target = target + SetLen(startPos - target, const.SlabSizeX/2)
		if z and target:z() ~= z then
			target = target:SetZ(z)
		end
	end
	
	if target:IsValidZ() then
		target = target:SetZ(target:z() + const.SlabSizeZ / 2)
	else
		target = target:SetTerrainZ(const.SlabSizeZ / 2)
	end
	return target
end

DefineClass.FXGrenade = {
	__parents = { "SpawnFXObject", "ComponentCustomData" },
	flags = { efCollision = false, efApplyToGrids = false, gofRealTimeAnim = false }
}

DefineClass.GrenadeVisual = {
	__parents = { "FXGrenade" },
	custom_equip = false,
	equip_index = 0,
}

---
--- Periodically updates the state of incendiary grenades, smoke zones, and flares on the map.
---
--- This function is called every 500 milliseconds to update the remaining time for any active incendiary grenades, smoke zones, and flares on the map. If any incendiary grenades have their remaining time reduced to 0, the function will update the overall fire state of the game map.
---
--- @param none
--- @return none
MapGameTimeRepeat("ExplosionFiresUpdate", 500, function()
	if g_Combat or g_StartingCombat then return end -- handled on NewCombatTurn msg

	local change
	for _, fire in ipairs(MapIncendiaryGrenadeZones) do
		if fire:UpdateRemainingTime(500) then
			change = true
		end
	end
	if change then
		UpdateMapBurningState(GameState.FireStorm)
	end
	for _, zone in ipairs(MapSmokeZones) do
		zone:UpdateRemainingTime(500)
	end
	for _, flare in ipairs(MapFlareOnGround) do
		flare:UpdateRemainingTime(500)
	end
end)

local function EnvEffectReaction(zone_type, attacker, target, damage)
	if not attacker then return end

	local attack_args = {obj = attacker, target = target}
	local results = {}
	results.area_hits = { {obj = target, aoe = true, damage = damage} }
	results.hit_objs = { target }
	results.hit_objs[target] = true
	results.killed_units = {}
	results.env_effect = true
	if target:IsDead() then
		table.insert(results.killed_units, target)
		if target:IsCivilian() and target.Affiliation == "Civilian" and attacker then
			CivilianDeathPenalty()
		end		
	end
	AttackReaction(zone_type, attack_args, results)
end

---
--- Periodically updates the state of units that are on fire.
---
--- This function is called every 500 milliseconds to update the remaining time for any active burning effects on units. If a unit is no longer in range of a fire, the burning effect is removed. Otherwise, the unit takes damage from the burning effect.
---
--- @param unit The unit to check for burning effects.
--- @param voxels The visual voxels of the unit. If not provided, they will be retrieved.
--- @param combat_moment The current combat moment ("start turn", "end turn", or nil).
--- @return none
---
function EnvEffectBurningTick(unit, voxels, combat_moment)
	local inside
	if next(g_DistToFire) ~= nil then
		if not voxels then
			voxels = unit:GetVisualVoxels()
		end
		local fire, dist = AreVoxelsInFireRange(voxels)
		inside = fire and dist < const.SlabSizeX
	end
	local effect = unit:GetStatusEffect("Burning")
	if effect then
		if not inside then
			local x, y, z = unit:GetVisualPosXYZ()
			if terrain.IsWater(x, y, z) then
				local water_z = terrain.GetWaterHeight(x, y)
				local dz = (z or terrain.GetHeight(x, y)) - water_z
				if dz >= const.FXWaterMinOffsetZ and dz <= const.FXWaterMaxOffsetZ then
					unit:RemoveStatusEffect("Burning")
					return
				end
			end
		end
		local start_time
		if combat_moment ~= "end turn" then
			if g_Combat or g_StartingCombat then
				return
			end
			start_time = effect:ResolveValue("burning_start_time")
			if GameTime() - start_time < 5000 then
				return
			end
		end
		local damage = Burning:ResolveValue("damage")
		unit:TakeDirectDamage(damage, T{529212078060, "<damage> (Burning)", damage = damage})
		if inside then
			if g_Combat or g_StartingCombat then
				start_time = GameTime()
			else
				start_time = (start_time or effect:GetParameter("burning_start_time")) + 5000
			end
			effect:SetParameter("burning_start_time", start_time)
		else
			unit:RemoveStatusEffect("Burning")
		end
	elseif inside then
		unit:AddStatusEffect("Burning")
	end
end

---
--- Handles the tick logic for the Toxic Gas environment effect.
---
--- @param unit table The unit affected by the Toxic Gas.
--- @param voxels table The voxels occupied by the unit.
--- @param combat_moment string The current combat moment ("start turn", "end turn", etc.).
---
function EnvEffectToxicGasTick(unit, voxels, combat_moment)
	local inside, protected, attacker
	if next(g_SmokeObjs) ~= nil then
		if not voxels then
			voxels = unit:GetVisualVoxels()
		end
		local smoke
		for _, voxel in ipairs(voxels) do
			local smoke_obj = g_SmokeObjs[voxel]
			if smoke_obj and smoke_obj:GetGasType() == "toxicgas" then
				smoke = smoke_obj
				inside = true
				break
			end
		end
		if inside then
			local mask = unit:GetItemInSlot("Head", "GasMaskBase")
			protected = mask and mask.Condition > 0
			for _, zone in ipairs(smoke.zones) do
				if zone.owner then
					attacker = zone.owner
					break
				end
			end
		end
	end
	
	if inside and protected and attacker then
		-- awareness reactions (there will be no damage/negative effects)
		PushUnitAlert("attack", attacker, unit)
	end
	
	inside = inside and not protected
	
	local effect = unit:GetStatusEffect("Choking")
	if effect then
		local start_time = effect:ResolveValue("choking_start_time")
		if (combat_moment == "end turn") or (not g_Combat and not g_StartingCombat and GameTime() >= start_time + 5000) then			
			local damage = Choking:ResolveValue("damage")
			unit:TakeDirectDamage(damage, T{698692719911, "<damage> (Choking)", damage = damage})
			EnvEffectReaction("toxicgas", attacker, unit, damage)
			if g_Combat or g_StartingCombat then
				start_time = GameTime()
			else
				start_time = start_time + 5000
			end
			if inside then
				effect:SetParameter("choking_start_time", start_time)
			else
				unit:RemoveStatusEffect("Choking")
			end
			local tiredness = RollSkillCheck(unit, "Health") and 1 or 2
			unit:ChangeTired(tiredness)
		end
	elseif inside then
		unit:AddStatusEffect("Choking")
		EnvEffectReaction("toxicgas", attacker, unit, 0)
	end	
end

---
--- Handles the effects of tear gas on a unit during a tactical combat situation.
---
--- @param unit table The unit being affected by the tear gas.
--- @param voxels table A list of voxel positions the unit is occupying.
--- @param combat_moment string The current stage of the combat round ("start turn" or "end turn").
---
function EnvEffectTearGasTick(unit, voxels, combat_moment)
	local inside, protected, attacker
	if next(g_SmokeObjs) ~= nil then
		if not voxels then
			voxels = unit:GetVisualVoxels()
		end
		local smoke
		for _, voxel in ipairs(voxels) do
			local smoke_obj = g_SmokeObjs[voxel]
			if smoke_obj and smoke_obj:GetGasType() == "teargas" then
				smoke = smoke_obj
				inside = true
				break
			end
		end
		if inside then
			local mask = unit:GetItemInSlot("Head", "GasMaskBase")
			protected = mask and mask.Condition > 0
			for _, zone in ipairs(smoke.zones) do
				if zone.owner then
					attacker = zone.owner
					break
				end
			end
		end
	end
	
	if inside and protected and attacker then
		-- awareness reactions (there will be no damage/negative effects)
		PushUnitAlert("attack", attacker, unit)
	end
	inside = inside and not protected
	
	local effect = unit:GetStatusEffect("Blinded")
	if effect then
		local start_time = effect:ResolveValue("blinded_start_time")
		if (combat_moment == "end turn") or (not g_Combat and not g_StartingCombat and GameTime() >= start_time + 5000) then
			-- choking damage/end will happen on end turn in combat		
			if g_Combat or g_StartingCombat then
				start_time = GameTime()
			else
				start_time = start_time + 5000
			end
			if inside then
				effect:SetParameter("blinded_start_time", start_time)
			else
				unit:RemoveStatusEffect("Blinded")
			end
		elseif combat_moment == "start turn" and inside then
			if not RollSkillCheck(unit, "Health") then
				unit:AddStatusEffect("Panicked")
			end
		end
	elseif inside then
		unit:AddStatusEffect("Blinded")
		EnvEffectReaction("teargas", attacker, unit, 0)
	end	
end

---
--- Handles the effects of smoke on units during a combat tick.
---
--- @param unit table The unit being affected by the smoke.
--- @param voxels table A table of voxels that the unit is currently occupying.
--- @param combat_moment string The current combat moment (e.g. "start turn", "end turn").
---
function EnvEffectSmokeTick(unit, voxels, combat_moment)
	local inside
	if next(g_SmokeObjs) ~= nil then
		if not voxels then
			voxels = unit:GetVisualVoxels()
		end
		for _, voxel in ipairs(voxels) do
			local smoke = g_SmokeObjs[voxel]
			if smoke and (smoke:GetGasType() == "smoke") then
				inside = true
				break
			end
		end
	end
	
	local effect = unit:GetStatusEffect("Smoked")
	if effect then
		local start_time = effect:ResolveValue("smoked_start_time")
		if (combat_moment == "end turn") or (not g_Combat and not g_StartingCombat and GameTime() >= start_time + 5000) then
			if g_Combat or g_StartingCombat then
				start_time = GameTime()
			else
				start_time = start_time + 5000
			end
			if inside then
				effect:SetParameter("smoked_start_time", start_time)
			else
				unit:RemoveStatusEffect("Smoked")
			end
		end
	elseif inside then
		unit:AddStatusEffect("Smoked")
	end	
end

---
--- Handles the effects of darkness on a unit during a combat tick.
---
--- @param unit table The unit being affected by the darkness.
--- @param voxels table A table of voxels that the unit is currently occupying.
---
function EnvEffectDarknessTick(unit, voxels)
	if IsIlluminated(unit, voxels, "sync") then
		if unit:HasStatusEffect("Darkness") then
			unit:RemoveStatusEffect("Darkness")
		end
	else
		if not unit:HasStatusEffect("Darkness") then
			unit:AddStatusEffect("Darkness")
		end
	end
end

---
--- Handles the periodic environmental effects on units of a given side.
---
--- @param side_type string The type of side to update, can be "player", "neutral", or "other".
--- @param time number The time in milliseconds between each update.
---
--- This function updates the environmental effects on all units of the specified side type. It checks for units that are on fire, exposed to toxic gas, tear gas, smoke, or darkness, and applies the appropriate effects to them. The function sleeps for the specified time between each unit update to spread out the processing load.
---
--- If there are no units of the specified side type, the function simply sleeps for the specified time and returns.
---
--- The function is called periodically by the game engine to update the environmental effects on units.
---
function EnvEffectsUpdate(side_type, time)
	if IsSetpiecePlaying() then
		Sleep(time)
		return
	end
	local units = {}
	for _, team in ipairs(g_Teams) do
		if side_type == "player" then
			if team.player_team then
				table.iappend(units, team.units)
			end
		else
			local team_side = team.side
			if team_side == "enemyNeutral" then
				team_side = GameState.Conflict and "enemy1" or "neutral"
			end
			if side_type == "neutral" then
				if team_side == "neutral" then
					table.iappend(units, team.units)
				end
			else
				if team_side ~= "neutral" then
					table.iappend(units, team.units)
				end
			end
		end
	end
	local count = #units
	if count == 0 then
		Sleep(time)
		return
	end
	local iclear = table.iclear
	local voxels = {}
	for i = 1, count do
		Sleep(i * time / count - (i - 1) * time / count)
		local unit = units[i]
		if IsValid(unit) and not unit:IsDead() then
			iclear(voxels)
			unit:GetVisualVoxels(nil, nil, voxels)
			EnvEffectBurningTick(unit, voxels)
			EnvEffectToxicGasTick(unit, voxels)
			EnvEffectTearGasTick(unit, voxels)
			EnvEffectSmokeTick(unit, voxels)
			EnvEffectDarknessTick(unit, voxels)
		end
	end
end

MapGameTimeRepeat("EnvEffectsPlayer", 0, function() return EnvEffectsUpdate("player", 100) end)
MapGameTimeRepeat("EnvEffectsNeutral", 0, function() return EnvEffectsUpdate("neutral", 500) end)
MapGameTimeRepeat("EnvEffectsOther", 0, function() return EnvEffectsUpdate("other", 300) end)

function OnMsg.NewCombatTurn()
	local change
	for _, fire in ipairs(MapIncendiaryGrenadeZones) do
		if fire:UpdateRemainingTime(5000) then
			change = true
		end
	end
	if change then
		UpdateMapBurningState(GameState.FireStorm)
	end
	for _, zone in ipairs(MapSmokeZones) do
		zone:UpdateRemainingTime(5000)
	end
	for _, flare in ipairs(MapFlareOnGround) do
		flare:UpdateRemainingTime(5000)
	end
end

MapVar("g_FireAreas", {})

function OnMsg.DoneMap()
	for _, fire in ipairs(g_FireAreas) do
		DoneObject(fire)
	end
end

DefineClass.MolotovFireObj = {
	__parents = { "SpawnFXObject" },
}

DefineClass.IncendiaryGrenadeZone = {
	__parents = { "GameDynamicSpawnObject", "SpawnFXObject" },
	
	remaining_time = false,
	fire_positions = false,
	campaign_time = false,
	owner = false,
	
	visuals = false,
}

--- Initializes an IncendiaryGrenadeZone object.
---
--- This function is called when an IncendiaryGrenadeZone object is created. It adds the object to the MapIncendiaryGrenadeZones table, sets the campaign_time property, and plays the "FireZone" start FX.
---
--- @param self IncendiaryGrenadeZone The IncendiaryGrenadeZone object being initialized.
function IncendiaryGrenadeZone:GameInit()
	table.insert(MapIncendiaryGrenadeZones, self)
	self.campaign_time = self.campaign_time or Game.CampaignTime
	PlayFX("FireZone", "start", self)
end

--- Updates the remaining time of an IncendiaryGrenadeZone object.
---
--- This function is called to update the remaining time of an IncendiaryGrenadeZone object. It checks if the remaining time has reached 0 or if the campaign time has passed, in which case it destroys the object. If the remaining time drops below 5000, it plays the "subside" FX for the FireZone and the MolotovFire objects associated with the zone.
---
--- @param self IncendiaryGrenadeZone The IncendiaryGrenadeZone object whose remaining time is being updated.
--- @param delta number The amount of time (in milliseconds) to subtract from the remaining time.
--- @return boolean True if the object should be destroyed, false otherwise.
function IncendiaryGrenadeZone:UpdateRemainingTime(delta)
	local remaining = self.remaining_time - delta
	
	if remaining <= 0 or self.campaign_time < Game.CampaignTime then
		DoneObject(self)
		return true
	elseif self.remaining_time > 5000 and remaining <= 5000 then
		-- update particles
		PlayFX("FireZone", "subside", self)
		for i, obj in ipairs(self.visuals) do
			if IsKindOf(obj, "MolotovFireObj") then
				PlayFX("MolotovFire", "subside", obj)
			end
		end
	end
	self.remaining_time = remaining
end

--- Adds the IncendiaryGrenadeZone object to the g_FireAreas table.
---
--- This function is called when an IncendiaryGrenadeZone object is initialized. It adds the object to the global g_FireAreas table, which is likely used to track all active fire areas in the game.
---
--- @param self IncendiaryGrenadeZone The IncendiaryGrenadeZone object being initialized.
function IncendiaryGrenadeZone:Init()
	table.insert_unique(g_FireAreas, self)
end

--- Destroys an IncendiaryGrenadeZone object.
---
--- This function is called when an IncendiaryGrenadeZone object is no longer needed. It removes the object from the MapIncendiaryGrenadeZones and g_FireAreas tables, destroys all visual objects associated with the zone, and plays the "end" FX for the FireZone.
---
--- @param self IncendiaryGrenadeZone The IncendiaryGrenadeZone object being destroyed.
function IncendiaryGrenadeZone:Done()
	table.remove_value(MapIncendiaryGrenadeZones, self)
	for _, obj in ipairs(self.visuals) do
		DoneObject(obj)
	end
	self.visuals = nil
	table.remove_value(g_FireAreas, self)
	PlayFX("FireZone", "end", self)
end

--- Serializes the dynamic data of the IncendiaryGrenadeZone object.
---
--- This function is called to serialize the dynamic data of the IncendiaryGrenadeZone object, which includes the remaining time, fire positions, campaign time, and owner. The serialized data can be used to restore the state of the object later.
---
--- @param self IncendiaryGrenadeZone The IncendiaryGrenadeZone object whose dynamic data is being serialized.
--- @param data table The table to store the serialized data in.
function IncendiaryGrenadeZone:GetDynamicData(data)
	data.remaining_time = self.remaining_time or nil
	data.fire_positions = self.fire_positions and table.copy(self.fire_positions) or nil
	data.campaign_time = self.campaign_time or nil
	data.owner = IsValid(self.owner) and self.owner:GetHandle() or nil
end

--- Sets the dynamic data of the IncendiaryGrenadeZone object.
---
--- This function is called to restore the state of the IncendiaryGrenadeZone object from serialized data. It sets the remaining time, campaign time, owner, and fire positions of the object, and creates the visual effects for the fire.
---
--- @param self IncendiaryGrenadeZone The IncendiaryGrenadeZone object whose dynamic data is being set.
--- @param data table The table containing the serialized data to restore the object's state.
function IncendiaryGrenadeZone:SetDynamicData(data)
	self.remaining_time = data.remaining_time
	self.campaign_time = data.campaign_time or Game.CampaignTime
	self.owner = HandleToObject[data.owner or false]
	if self.campaign_time < Game.CampaignTime then
		return
	end
	if data.fire_positions then
		self.fire_positions = table.copy(data.fire_positions)
		self:CreateVisuals("instant")
	end
	CreateGameTimeThread(function()
		Sleep(1) -- delay until loading is done and game has started for real, otherwise PlaySound can fail due to actor being too far
		PlayFX("FireZone", "start", self)
	end)
end

---
--- Creates the visual effects for an IncendiaryGrenadeZone object.
---
--- This function is responsible for creating the visual effects associated with an IncendiaryGrenadeZone object. It first removes any existing visual objects, then creates a new explosion effect at the zone's position. It then creates a series of fire objects at the positions specified in the `fire_positions` table, and applies a "Burning" status effect to any nearby units.
---
--- @param self IncendiaryGrenadeZone The IncendiaryGrenadeZone object whose visuals are being created.
--- @param instant boolean If true, the fire objects are created immediately without any delay.
function IncendiaryGrenadeZone:CreateVisuals(instant)
	for _, obj in ipairs(self.visuals) do
		DoneObject(obj)		
	end
	self.visuals = {}
	
	local pos = GetExplosionFXPos(self)
	PlayFX("MolotovExplosion", "start", self, false, pos)
	
	if not instant then
		Sleep(150)
	end
		
	for i, pos in ipairs(self.fire_positions) do
		local fire = PlaceObject("MolotovFireObj")
		fire:SetPos(pos)
		PlayFX("MolotovFire", "start", fire)
		table.insert(self.visuals, fire)
		
		if not instant then
			for _, unit in ipairs(g_Units) do
				if not unit:IsDead() and unit:GetDist(pos) < const.SlabSizeX / 2 and not unit:HasStatusEffect("Burning") then
					unit:AddStatusEffect("Burning")
				end
			end
			Sleep(100)
		end
	end
end

---
--- Creates an area of fire from an explosive grenade.
---
--- This function is responsible for creating the visual effects and fire objects associated with an explosive grenade. It first checks if the explosion position is in water, and if so, creates a splash effect and floating text. Otherwise, it calculates the possible locations for fire objects based on the terrain and nearby floor slabs. It then checks the line of sight to these locations and creates a new IncendiaryGrenadeZone object with the valid fire positions. The number of fire turns is determined by the current game state (e.g. rain, dust storm, fire storm).
---
--- @param attacker Unit The unit that threw the grenade.
--- @param attackResults table The results of the grenade attack.
--- @param fx_actor Object The object that should be used as the source for the visual effects.
function ExplosionCreateFireAOE(attacker, attackResults, fx_actor)
	local trajectory = attackResults.trajectory	or empty_table
	local pos = #trajectory > 0 and trajectory[#trajectory].pos or attackResults.target_pos
	if not pos then return end
	
	local water = terrain.IsWater(pos) and terrain.GetWaterHeight(pos)
	if water and (not pos:IsValidZ() or water >= pos:z()) then
		pos = pos:IsValidZ() and pos or pos:SetTerrainZ()
		PlayFX("GrenadeSplash", "start", fx_actor, false, pos)
		CreateFloatingText(pos:SetZ(water), T(760226092433, "Sunk"))
		return
	end
	local radius = const.SlabSizeX + const.SlabSizeX / 2
	
	local x, y, z = VoxelToWorld(WorldToVoxel(pos))
	pos = GetExplosionFXPos(point(x, y, z))

	-- possible locations are terrain + floor slabs in range
	local zoffs = point(0, 0, const.SlabSizeZ / 2)

	local target_locs = MapGet(pos, radius + const.SlabSizeX, "FloorSlab") or {}
	table.imap_inplace(target_locs, function(slab) return slab:GetPos() end)
	target_locs = table.ifilter(target_locs, function(idx, loc, pos)
		return pos:Dist2D(loc) / const.SlabSizeX <= 1
	end, pos)

	local limit = DivCeil(radius, const.SlabSizeX) * const.SlabSizeX
	for dx = -limit, limit, const.SlabSizeX do
		for dy = -limit, limit, const.SlabSizeY do
			local epos = GetExplosionFXPos(point(x+dx, y+dy, z))
			if epos and epos:Dist2D(pos) / const.SlabSizeX <= 1 then
				target_locs[#target_locs + 1] = epos
			end
		end
	end
	
	target_locs = table.ifilter(target_locs, function(idx, loc)
		return not terrain.IsWater(loc) or terrain.GetWaterHeight(loc) < loc:z()
	end)
	table.sort(target_locs, function(a, b) return a:Dist(pos) < b:Dist(pos) end)
	
	local los_targets = table.map(target_locs, function(loc)
		if loc:IsValidZ() then
			return loc + zoffs
		end
		return loc:SetTerrainZ(const.SlabSizeZ / 2)
	end)
		
	local los_any, los_to_targets = CheckLOS(los_targets, pos)
	if not los_any then
		return
	end
	
	local fire_locs = {}
	
	local explosion_pos, min_dist
	for i, loc in ipairs(los_targets) do
		if los_to_targets[i] then
			fire_locs[#fire_locs + 1] = target_locs[i]
			local dist = target_locs[i]:Dist(pos)
			if not explosion_pos or dist < min_dist then
				explosion_pos, min_dist = target_locs[i], dist
			end			
		end
	end
			
	if #fire_locs > 0 then
		local num_turns = 4	
		local step_pos = SnapToPassSlab(explosion_pos) or point(VoxelToWorld(WorldToVoxel(explosion_pos)))
		local volume = EnumVolumes(step_pos, "smallest")
		if not volume then	
			if GameState.RainHeavy or GameState.DustStorm then
				num_turns = 2
			elseif GameState.FireStorm then
				num_turns = 6
			end
		end
		local fire = IncendiaryGrenadeZone:new{
			fire_positions = fire_locs,
			remaining_time = num_turns * 5000,
		}
		if IsKindOf(attacker, "Unit") then
			fire.owner = attacker
		end
		fire:SetPos(explosion_pos)
		CreateGameTimeThread(IncendiaryGrenadeZone.CreateVisuals, fire)
		UpdateMapBurningState(GameState.FireStorm)		
	end
end

local function IsOutsideSmokeArea(x, y, z)
	if x < -2 or x > 3 or y < -2 or y > 3 then
		return true
	end
	if (x == -2 or x == 3) and (y == -2 or y == 3) then
		return true
	end
	if x > -1 and x < 2 and y > -1 and y < 2 then
		return abs(z) >= 3
	elseif x > -2 and x < 3 and y > -2 and y < 3 then
		return abs(z) >= 2
	end
	return z ~= 0
end

---
--- Calculates voxel blocking information for the game map.
---
--- This function iterates through all the slabs in the map and determines which voxels are blocked based on the slab types and properties. The resulting block information is stored in a table that maps voxel coordinates and directions to boolean values indicating if the voxel is blocked.
---
--- @param iter number (optional) The number of times to recalculate the voxel blocking information. Defaults to 1.
--- @return table The table of voxel blocking information.
function calc_voxelblocking(iter)
	iter = iter or 1
	ic("start")
	local slabs = MapGet("map", "Slab")
	ic("map enum done")

	local block_slabs = {}
	local function set_block_slab(gx, gy, gz, dir)
		local key = bor(band(gx, 0xffff), shift(band(gy, 0xffff), 16), shift(band(gz, 0xffff), 32), shift(dir, 48))
		block_slabs[key] = true
	end
	
	local tStart = GetPreciseTicks()
	local g0x, g0y, g0z = 0, 0, 0
	for i = 1, iter do
		block_slabs = {}
		for _, slab in ipairs(slabs) do
			local gx, gy, gz, side = slab:GetGridCoords()
			if IsKindOf(slab, "FloorSlab") then
				set_block_slab(gx-g0x, gy-g0y, gz-g0z, dirNZ)
				set_block_slab(gx-g0x, gy-g0y, gz-1-g0z, dirPZ)
			elseif IsKindOf(slab, "CeilingSlab") then
				set_block_slab(gx-g0x, gy-g0y, gz-g0z, dirPZ)
				set_block_slab(gx-g0x, gy-g0y, gz+1-g0z, dirNZ)
			elseif IsKindOf(slab, "WallSlab") then
				local blocked = slab.isVisible
				local height = 1
				if not blocked and slab.wall_obj then
					height = slab.wall_obj.height
					if IsKindOf(slab.wall_obj, "SlabWallDoor") then
						blocked = not slab.wall_obj:IsDead() and slab.wall_obj.pass_through_state == "closed"
					elseif IsKindOf(slab.wall_obj, "SlabWallWindow") then
						blocked = slab.wall_obj.pass_through_state == "intact"
					end
				end
				if blocked then
					local dir = Rotate(point(1, 0, 0), slab:GetAngle())
					local x, y = dir:xy()
					local neg
					if x > 0 then
						dir = dirPX
						neg = dirNX
					elseif x < 0 then
						dir = dirNX
						neg = dirPX
					elseif y > 0 then
						dir = dirPY
						neg = dirNY
					else -- y < 0
						dir = dirNY
						neg = dirPY
					end
					for i = 1, height do
						set_block_slab(gx-g0x, gy+i-1-g0y, gz-g0z, dir)
						set_block_slab(gx+x-g0x, gy+y+i-1-g0y, gz-g0z, neg)
					end
				end
			end
		end
	end
	local time = GetPreciseTicks() - tStart
	printf("%d recalcs on %d slabs done in %d ms, %d ms/recalc", iter, #slabs, time, time/iter)
	
	return block_slabs
end

MapVar("g_VoxelBlock", false)
---
--- Checks if a voxel at the given grid coordinates is blocked in the specified direction.
---
--- @param gx number The x-coordinate of the voxel.
--- @param gy number The y-coordinate of the voxel.
--- @param gz number The z-coordinate of the voxel.
--- @param dir number The direction to check for blockage.
--- @return boolean True if the voxel is blocked in the specified direction, false otherwise.
---
function IsVoxelBlocked(gx, gy, gz, dir)
	local key = bor(band(gx, 0xffff), shift(band(gy, 0xffff), 16), shift(band(gz, 0xffff), 32), shift(dir, 48))
	return g_VoxelBlock[key]
end

---
--- Checks if a voxel at the given coordinates can be reached from another voxel at the given coordinates.
---
--- @param x1 number The x-coordinate of the starting voxel.
--- @param y1 number The y-coordinate of the starting voxel.
--- @param z1 number The z-coordinate of the starting voxel.
--- @param x2 number The x-coordinate of the target voxel.
--- @param y2 number The y-coordinate of the target voxel.
--- @param z2 number The z-coordinate of the target voxel.
--- @return boolean, boolean True if the target voxel can be reached, and true if the path is blocked, respectively.
---
function VoxelCanReach(x1, y1, z1, x2, y2, z2)
	if x1 == x2 and y1 == y2 and z1 == z2 then
		return true, false
	end
	local reached, blocked = false, false
	if x2 > x1 then
		if IsVoxelBlocked(x1, y1, z1, dirPX) then
			blocked = true
		else
			local r, b = VoxelCanReach(x1+1, y1, z1, x2, y2, z2)
			reached = reached or r
			blocked = blocked or b
		end
	end
	if x2 < x1 then
		if IsVoxelBlocked(x1, y1, z1, dirNX) then
			blocked = true
		else
			local r, b = VoxelCanReach(x1-1, y1, z1, x2, y2, z2)
			reached = reached or r
			blocked = blocked or b
		end
	end
	if y2 > y1 then
		if IsVoxelBlocked(x1, y1, z1, dirPY) then
			blocked = true
		else
			local r, b = VoxelCanReach(x1, y1+1, z1, x2, y2, z2)
			reached = reached or r
			blocked = blocked or b
		end
	end
	if y2 < y1 then
		if IsVoxelBlocked(x1, y1, z1, dirNY) then
			blocked = true
		else
			local r, b = VoxelCanReach(x1, y1-1, z1, x2, y2, z2)
			reached = reached or r
			blocked = blocked or b
		end
	end
	if z2 > z1 then
		if IsVoxelBlocked(x1, y1, z1, dirPZ) then
			blocked = true
		else
			local r, b = VoxelCanReach(x1, y1, z1+1, x2, y2, z2)
			reached = reached or r
			blocked = blocked or b
		end
	end
	if z2 < z1 then
		if IsVoxelBlocked(x1, y1, z1, dirNZ) then
			blocked = true
		else
			local r, b = VoxelCanReach(x1, y1, z1-1, x2, y2, z2)
			reached = reached or r
			blocked = blocked or b
		end
	end
	return reached, blocked
--[[	
	if x1 == x2 and y1 == y2 and z1 == z2 then
		return true
	end
	if x2 < x1 and not IsVoxelBlocked(x1, y1, z1, dirPX) and VoxelCanReach(x1+1, y1, z1, x2, y2, z2) then
		return true
	end
	if x2 < x1 and not IsVoxelBlocked(x1, y1, z1, dirNX) and VoxelCanReach(x1-1, y1, z1, x2, y2, z2) then
		return true
	end
	if y2 > y1 and not IsVoxelBlocked(x1, y1, z1, dirPY) and VoxelCanReach(x1, y1+1, z1, x2, y2, z2) then
		return true
	end
	if y2 < y1 and not IsVoxelBlocked(x1, y1, z1, dirNY) and VoxelCanReach(x1, y1-1, z1, x2, y2, z2) then
		return true
	end
	if z2 > z1 and not IsVoxelBlocked(x1, y1, z1, dirPZ) and VoxelCanReach(x1, y1, z1+1, x2, y2, z2) then
		return true
	end
	if z2 < z1 and not IsVoxelBlocked(x1, y1, z1, dirNZ) and VoxelCanReach(x1, y1, z1+1, x2, y2, z2) then
		return true
	end
	return false--]]
end

---
--- Checks if there is a line of sight between two units in the game world.
---
--- @param unit1 table The first unit to check line of sight for.
--- @param unit2 table The second unit to check line of sight for.
--- @return string The line of sight status, either "clear", "partial", or "blocked".
---
function VoxelLOS(unit1, unit2)
	local head1 = select(2, unit1:GetVisualVoxels())
	local head2 = select(2, unit2:GetVisualVoxels())
	
	if not g_VoxelBlock then
		g_VoxelBlock = calc_voxelblocking()
	end
	
	local voxel_box = box(point(-const.SlabSizeX/2, -const.SlabSizeY/2, 0), point(const.SlabSizeX/2, const.SlabSizeY/2, const.SlabSizeZ))

	--clear_smoke_dbg_visuals()
	
	local gx1, gy1, gz1 = point_unpack(head1)
	local gx2, gy2, gz2 = point_unpack(head2)
	
	--local mesh = PlaceBox(voxel_box + point(VoxelToWorld(gx1, gy1, gz1)), const.clrGreen, nil, false)
	--table.insert(g_dbgSmokeVisuals, mesh)	
	--mesh = PlaceBox(voxel_box + point(VoxelToWorld(gx2, gy2, gz2)), const.clrBlue, nil, false)
	--table.insert(g_dbgSmokeVisuals, mesh)
	
	local dx, dy, dz = abs(gx2-gx1), abs(gy2-gy1), abs(gz2-gz1)
	local sx = (gx2 > gx1) and 1 or -1
	local sy = (gy2 > gy1) and 1 or -1
	local sz = (gz2 > gz1) and 1 or -1
	local p1, p2
	local x, y, z = gx1, gy1, gz1
	local voxels = {}
	if dx > dy and dx > dz then
		p1 = 2*dy-dx
		p2 = 2*dz-dx
		while x ~= gx2 do
			x = x + sx
			if p1 >= 0 then
				y = y + sy
				p1 = p1 - 2*dx
			end
			if p2 >= 0 then
				z = z + sz
				p2 = p2 - 2*dx
			end
			p1 = p1 + 2*dy
			p2 = p2 + 2*dz
			table.insert(voxels, point_pack(x, y, z))
		end
	elseif dy > dz then
		p1 = 2*dx-dy
		p2 = 2*dz-dy
		while y ~= gy2 do
			y = y + sy
			if p1 >= 0 then
				x = x + sx
				p1 = p1 - 2*dy
			end
			if p2 >= 0 then
				z = z + sz
				p2 = p2 - 2*dy
			end
			p1 = p1 + 2*dx
			p2 = p2 + 2*dz
			table.insert(voxels, point_pack(x, y, z))
		end
	else
		p1 = 2*dx-dz
		p2 = 2*dy-dz
		while z ~= gz2 do
			z = z + sz
			if p1 >= 0 then
				x = x + sx
				p1 = p1 - 2*dz
			end
			if p2 >= 0 then
				y = y + sy
				p2 = p2 - 2*dz
			end
			p1 = p1 + 2*dx
			p2 = p2 + 2*dy
			table.insert(voxels, point_pack(x, y, z))
		end
	end
	x, y, z = gx1, gy1, gz1	
	local los_reached, los_blocked
	for _, pt in ipairs(voxels) do
		local nx, ny, nz = point_unpack(pt)
		local reached, blocked = VoxelCanReach(x, y, z, nx, ny, nz)
		los_reached = los_reached or reached
		los_blocked = los_blocked or blocked
		if los_reached and los_blocked then
			break
		end
		--[[local color
		if reached and not blocked then
			color = const.clrWhite
		elseif reached then
			color = const.clrYellow
		else
			color = const.clrRed
		end
		mesh = PlaceBox(voxel_box + point(VoxelToWorld(nx, ny, nz)), color, nil, false)
		table.insert(g_dbgSmokeVisuals, mesh)--]]
		x, y, z = nx, ny, nz
	end
	if los_reached and los_blocked then
		return "partial"
	elseif los_reached then
		return "clear"
	end
	return "blocked"
end

---
--- Runs a test to calculate the voxel line-of-sight (LOS) between all units in the game.
--- This function is used for debugging and testing purposes.
---
--- It performs the following steps:
--- 1. Calculates the voxel blocking information using `calc_voxelblocking()`.
--- 2. Iterates over all units in the game `num` times.
--- 3. For each unit, it checks the LOS to all other valid and non-dead units using `VoxelLOS()`.
--- 4. It keeps track of the number of "clear", "partial", and "blocked" LOS results.
--- 5. It prints the total number of LOS checks performed, the time taken, and the breakdown of the LOS results.
---
--- @function test_voxel_los
--- @return nil
function test_voxel_los()
	g_VoxelBlock = calc_voxelblocking()
	
	local t = GetPreciseTicks()
	local num = 10
	local total = 0
	local stats = {}
	for i = 1, num do
		for _, unit in ipairs(g_Units) do
			if not IsValid(unit) or unit:IsDead() then 
				goto continue 
			end
			for _, other in ipairs(g_Units) do
				if IsValid(other) and not other:IsDead() then
					local result = VoxelLOS(unit, other)
					stats[result] = (stats[result] or 0) + 1
					total = total + 1
				end
			end
			::continue::
		end	
	end
	local time = GetPreciseTicks() - t
	printf("%d recalcs done in %d ms, %d ms/cycle", num, time, time / num)
	printf("results received: %d", total)
	if total > 0 then
		for k, n in sorted_pairs(stats) do
			printf("  %s: %d (%d%%)", k, n, MulDivRound(n, 100, total))
		end
	end
end

---
--- Propagates smoke in a grid, starting from a given origin point.
---
--- This function calculates the smoke propagation in a grid, taking into account
--- terrain and obstacles. It uses a breadth-first search algorithm to explore
--- the grid and mark voxels as blocked or unblocked based on the terrain and
--- obstacles.
---
--- @param g0x number The x-coordinate of the origin point in voxel space.
--- @param g0y number The y-coordinate of the origin point in voxel space.
--- @param g0z number The z-coordinate of the origin point in voxel space.
--- @param gdx number The x-dimension of the grid in voxels.
--- @param gdy number The y-dimension of the grid in voxels.
--- @return table, table The smoke map and the blocked voxel map.
---
function PropagateSmokeInGrid(g0x, g0y, g0z, gdx, gdy)
	local smoke = {}
	local queue = { point_pack(0, 0, 0) }
	local blocked = {}
	local block_slabs = {}
	
	local function set_block_slab(gx, gy, gz, dir)
		local key = bor(band(gx, 0xffff), shift(band(gy, 0xffff), 16), shift(band(gz, 0xffff), 32), shift(dir, 48))
		block_slabs[key] = true
	end
	local function is_blocked(gx, gy, gz, dir)
		local key = bor(band(gx, 0xffff), shift(band(gy, 0xffff), 16), shift(band(gz, 0xffff), 32), shift(dir, 48))
		return block_slabs[key]
	end

	local wpt = point(VoxelToWorld(g0x, g0y, g0z))
	local slabs = MapGet(wpt, 5*const.SlabSizeX, "Slab")
	for _, slab in ipairs(slabs) do
		local gx, gy, gz, side = slab:GetGridCoords()
		if IsKindOf(slab, "FloorSlab") then
			set_block_slab(gx-g0x, gy-g0y, gz-g0z, dirNZ)
			set_block_slab(gx-g0x, gy-g0y, gz-1-g0z, dirPZ)
		elseif IsKindOfClasses(slab, "CeilingSlab", "RoofSlab") then
			set_block_slab(gx-g0x, gy-g0y, gz-g0z, dirPZ)
			set_block_slab(gx-g0x, gy-g0y, gz+1-g0z, dirNZ)
		elseif IsKindOf(slab, "WallSlab") then
			local blocked = slab.isVisible
			local height = 1
			if not blocked and slab.wall_obj then
				height = slab.wall_obj.height
				if IsKindOf(slab.wall_obj, "SlabWallDoor") then
					blocked = not slab.wall_obj:IsDead() and slab.wall_obj.pass_through_state == "closed"
				elseif IsKindOf(slab.wall_obj, "SlabWallWindow") then
					blocked = slab.wall_obj.pass_through_state == "intact"
				end
			end
			if blocked then
				local dir = Rotate(point(1, 0, 0), slab:GetAngle())
				local x, y = dir:xy()
				local neg
				if x > 0 then
					dir = dirPX
					neg = dirNX
				elseif x < 0 then
					dir = dirNX
					neg = dirPX
				elseif y > 0 then
					dir = dirPY
					neg = dirNY
				else -- y < 0
					dir = dirNY
					neg = dirPY
				end
				for i = 1, height do
					set_block_slab(gx-g0x, gy+i-1-g0y, gz-g0z, dir)
					set_block_slab(gx+x-g0x, gy+y+i-1-g0y, gz-g0z, neg)
				end
			end
		end
	end

	local function try_spill(px, py, pz, dx, dy, dz)
		local vx, vy, vz = px + dx, py + dy, pz + dz
		local prevpack = point_pack(px, py, pz)
		local packed = point_pack(vx, vy, vz)
		if IsOutsideSmokeArea(vx*gdx, vy*gdy, vz) then
			local dir
			if dx > 0 then 
				dir = dirPX 
			elseif dx < 0 then
				dir = dirNX
			elseif dy > 0 then
				dir = dirPY
			elseif dy < 0 then
				dir = dirNY
			elseif dz > 0 then
				dir = dirPZ
			else
				dir = dirNZ
			end
			blocked[prevpack] = bor(blocked[prevpack] or 0, shift(1, dir))
			return
		end
		
		local pt = point(VoxelToWorld(g0x, g0y, g0z))
		local wpt = pt + point(vx * const.SlabSizeX, vy * const.SlabSizeY, vz * const.SlabSizeZ)
		smoke[point_pack(0, 0, 0)] = wpt
		-- check terrain
		if dz < 0 and terrain.GetHeight(wpt) > wpt:z() + sizez/2 then
			--DbgAddVector(pt + point(px * sizex, py * sizey, pz * sizez + sizez/4), point(0, 0, -sizez/2), const.clrRed)
			blocked[prevpack] = bor(blocked[prevpack] or 0, shift(1, dirNZ))
			return
		end
		if dz > 0 then
			-- check the floor of the new tile
			if is_blocked(px, py, pz, dirPZ) then
				--DbgAddVector(pt + point(px * sizex, py * sizey, vz * sizez - sizez/4), point(0, 0, sizez/2), const.clrRed)
				blocked[prevpack] = bor(blocked[prevpack] or 0, shift(1, dirPZ))
				return
			end
		elseif dz < 0 then
			-- check the floor of the previous tile
			if is_blocked(px, py, pz, dirNZ) then
				--DbgAddVector(pt + point(px * sizex, py * sizey, pz * sizez + sizez/4), point(0, 0, -sizez/2), const.clrRed)
				blocked[prevpack] = bor(blocked[prevpack] or 0, shift(1, dirNZ))
				return
			end
		else
			-- check for wall slabs (at the respective edge)
			local side
			local dirShift
			if dx > 0 then
				side = "E" -- 0
				dirShift = dirPX
			elseif dx < 0 then
				side = "W" -- 180
				dirShift = dirNX
			elseif dy > 0 then
				side = "S" -- 90
				dirShift = dirPY
			else -- dy < 0
				side = "N" -- 270
				dirShift = dirNY
			end
			if is_blocked(px, py, pz, dirShift) then
				--DbgAddVector(pt + point(px*sizex + dx*sizex/4, py*sizey + dy*sizey/4, pz*sizez + sizez/2), point(dx*sizex/2, dy*sizey/2, 0), const.clrRed)
				blocked[prevpack] = bor(blocked[prevpack] or 0, shift(1, dirShift))
				return
			end
		end
		if smoke[packed] then return end -- needs to be after the blocked checks to make sure we're not missing information about blocked voxel to voxel transition
				
		smoke[packed] = wpt
		queue[#queue + 1] = packed
	end
	
	local idx = 1
	while idx <= #queue do
		local x, y, z = point_unpack(queue[idx])
		idx = idx + 1
		
		try_spill(x, y, z,  1, 0, 0)
		try_spill(x, y, z, -1, 0, 0)
		try_spill(x, y, z, 0,  1, 0)
		try_spill(x, y, z, 0, -1, 0)
		try_spill(x, y, z, 0, 0,  1)
		try_spill(x, y, z, 0, 0, -1)
	end
	
	return smoke, blocked
end

local function FindSmokeObjPos(smoke, blocked)
	-- find a place for the smoke grenade obj: nearest voxel to original target (0, 0, 0)
	local smoke_obj_ppos, min_dist2
	local mask = bor(shift(1, dirPX), shift(1, dirPY), shift(1, dirNX), shift(1, dirNY))
	for packed, _ in pairs(smoke) do
		-- only consider voxels that are blocked downwards and do not have blocked x/y sides
		local value = blocked[packed] or 0
		if band(value, shift(1, dirNZ)) ~= 0 and band(value, mask) == 0 then 
			local x, y, z = point_unpack(packed)
			local dist2 = (x*x*guim*guim) + (y*y*guim*guim) + (z*z*guim*guim)
			if not smoke_obj_ppos or min_dist2 > dist2 then
				smoke_obj_ppos, min_dist2 = packed, dist2
			end
		end
	end
	return smoke_obj_ppos
end

MapVar("g_dbgSmokeVisuals", {})

--- Clears all debug visuals related to smoke grenade testing.
---
--- This function is used to clean up any debug visuals that were created during the
--- testing of smoke grenades. It clears all debug vectors, texts, and destroys any
--- objects that were created as part of the smoke grenade visualization.
function clear_smoke_dbg_visuals()
	DbgClearVectors()
	DbgClearTexts()
	for _, obj in ipairs(g_dbgSmokeVisuals) do
		DoneObject(obj)
	end
end

---
--- Runs a test for smoke grenade visuals, creating a debug visualization of the smoke propagation.
---
--- This function is used for testing and debugging the smoke grenade behavior. It creates a visual
--- representation of the smoke propagation, including the smoke volume, blocked directions, and
--- the position of the smoke object.
---
--- @param target The target position for the smoke grenade, or nil to use the terrain cursor.
---
function test_smoke(target)
	if not CurrentThread() then
		CreateRealTimeThread(test_smoke, target)
		return
	end
	local target = target or GetTerrainCursor()
	local pt = SnapToPassSlab(target) or target
	local voxel_box = box(point(-const.SlabSizeX/2, -const.SlabSizeY/2, 0), point(const.SlabSizeX/2, const.SlabSizeY/2, const.SlabSizeZ))

	local g0x, g0y, g0z = WorldToVoxel(pt)

	target = target:SetTerrainZ()
	if not pt:IsValidZ() then
		pt = pt:SetTerrainZ()
	end
	
	clear_smoke_dbg_visuals()
	DbgAddVector(target, point(0, 0, 2*guim), const.clrGreen)
	
	local smoke_box, mesh
	smoke_box = voxel_box + pt	
	mesh = PlaceBox(smoke_box, const.clrGreen, nil, false)
	table.insert(g_dbgSmokeVisuals, mesh)
	
	local cx, cy = pt:xy()
	local tx, ty = target:xy()
	local ax, ay 
	if SelectedObj then
		ax, ay = SelectedObj:GetPosXYZ()
	end
	
	-- pick directions to form the 2x2 block
	local gdx = tx - cx
	if gdx == 0 and ax then gdx = tx - ax end
	gdx = (gdx ~= 0) and (gdx / abs(gdx)) or 1
	
	local gdy = ty - cy
	if gdy == 0 and ay then gdy = ty - ay end
	gdy = (gdy ~= 0) and (gdy / abs(gdy)) or 1

	-- check for walls in the direction of the spill
	local sizex = const.SlabSizeX
	local sizey = const.SlabSizeY
	local sizez = const.SlabSizeZ

	local midpt = pt + point(gdx*sizex/2, gdy*sizey/2, 0) 

	DbgAddVector(midpt, point(0, 0, 5*guim), const.clrMagenta)

	DbgAddVector(pt + point(gdx * sizex / 4, 0, sizez / 2), point(gdx*2*guim, 0, 0), const.clrGreen)
	DbgAddVector(pt + point(0, gdy * sizey / 4, sizez / 2), point(0, gdy*2*guim, 0), const.clrGreen)
			
	local smoke, blocked = PropagateSmokeInGrid(g0x, g0y, g0z, gdx, gdy)
	local voffset = {
		point(sizex/4, 0, sizez/2), point(-sizex/4, 0, sizez/2),
		point(0, sizey/4, sizez/2), point(0, -sizey/4, sizez/2),
		point(0, 0, 3*sizez/4), point(0, 0, sizez/4),
	}
	local vbody = {
		point(sizex/2, 0, 0), point(-sizex/2, 0, 0),
		point(0, sizey/2, 0), point(0, -sizey/2, 0),
		point(0, 0, sizez/2), point(0, 0, -sizez/2),
	}
	for packed, wpt in pairs(smoke) do
		local smoke_box = voxel_box + wpt
		assert(IsPoint(wpt))
		local mesh = PlaceBox(smoke_box, const.clrGray, nil, false)
		table.insert(g_dbgSmokeVisuals, mesh)
		
		local block_mask = blocked[packed]
		
		for i = dirPX, dirNZ do
			local color = band(block_mask, shift(1, i)) == 0 and const.clrGreen or const.clrRed
			DbgAddVector(wpt + voffset[i+1], vbody[i+1], color)
		end
	end
	
	local smoke_obj_ppos = FindSmokeObjPos(smoke, blocked)
	
	if smoke_obj_ppos then
		local x, y, z = point_unpack(smoke_obj_ppos)
		local pos = pt + point(x*sizex, y*sizex, z*sizez)
		local obj = PlaceObject("GrenadeVisual", {fx_actor_class = "SmokeGrenadeSpinner"} )
		obj:SetPos(pos)
		table.insert(g_dbgSmokeVisuals, obj)
	end
end

---
--- Creates a smoke area of effect (AOE) explosion.
---
--- @param attacker Unit|nil The unit that caused the explosion.
--- @param results table The results of the explosion, containing information like the trajectory and target position.
--- @param fx_actor any The actor that should play the explosion effects.
---
function ExplosionCreateSmokeAOE(attacker, results, fx_actor)
	local trajectory = results.trajectory	or empty_table
	local pos = #trajectory > 0 and trajectory[#trajectory].pos or results.target_pos
	if not pos then return end
	
	local water = terrain.IsWater(pos) and terrain.GetWaterHeight(pos)
	if water and (not pos:IsValidZ() or water >= pos:z()) then
		pos = pos:IsValidZ() and pos or pos:SetTerrainZ()
		PlayFX("GrenadeSplash", "start", fx_actor, false, pos)	
		CreateFloatingText(pos:SetZ(water), T(760226092433, "Sunk"))
		return
	end
	pos = SnapToPassSlab(pos) or pos
	
	local dx, dy = 1, 1
	for i = #trajectory - 1, 1, -1 do
		local step = trajectory[i]
		if step.pos:Dist2D(pos) > 0 then
			local px, py = step.pos:xy()
			local x, y = pos:xy()
			dx = (px == x) and 1 or ((x - px) / abs(x - px))
			dy = (py == y) and 1 or ((y - py) / abs(y - py))
			break
		end
	end
	
	local turns = 4
	local step_pos = SnapToPassSlab(pos) or point(VoxelToWorld(WorldToVoxel(pos)))
	local volume = EnumVolumes(step_pos, "smallest")
	if not volume then	
		if GameState.RainHeavy or GameState.DustStorm then
			turns = 2
		else
			turns = 3
		end
	end
		
	local zone = SmokeZone:new{smoke_dx = dx, smoke_dy = dy, remaining_time = turns * 5000, gas_type = results.aoe_type}
	if IsKindOf(attacker, "Unit") then
		zone.owner = attacker
	end
	zone:SetPos(pos)
	zone:PropagateSmoke()
end

MapVar("g_SmokeObjs", {}) -- ppos -> smoke obj

DefineClass.SmokeObj = {
	__parents = { "SpawnFXObject" },
	flags = { efVisible = false, efApplyToGrids = false, cfSmokeObj = true },
	
	entity = "SolidVoxel",	
	zones = false, -- zone refs
}

--- Returns the gas type of the first smoke zone that this smoke object is a part of.
---
--- @return string|false The gas type of the first smoke zone, or `false` if the smoke object is not part of any smoke zones.
function SmokeObj:GetGasType()
	return self.zones and self.zones[1] and self.zones[1].gas_type
end

--- Initializes a new SmokeObj instance.
---
--- This function is called when a new SmokeObj is created. It initializes the `zones` table to store any smoke zones that this object is a part of, and invalidates the visibility of the object to trigger a redraw.
function SmokeObj:Init()
	self.zones = {}
	InvalidateVisibility()
end

--- Marks the SmokeObj as no longer visible and triggers a redraw.
---
--- This function is called when the SmokeObj is being destroyed or removed from the game. It invalidates the visibility of the object, which will trigger a redraw of the object in the game world.
function SmokeObj:Done()
	InvalidateVisibility()
end

DefineClass.SmokeZone = {
	__parents = { "GameDynamicSpawnObject", "SpawnFXObject" },
	
	remaining_time = false,
	gas_type = false,
	smoke_positions = false,
	owner = false,
	smoke_dx = 1,
	smoke_dy = 1,
	
	spinner = false,
	campaign_time = false,
}

--- Initializes a new SmokeZone instance.
---
--- This function is called when a new SmokeZone is created. It adds the SmokeZone to the MapSmokeZones table, sets the campaign_time property, and plays a "start" FX for the SmokeZone's gas_type.
---
--- @param self SmokeZone The SmokeZone instance being initialized.
function SmokeZone:GameInit()
	table.insert(MapSmokeZones, self)
	self.campaign_time = self.campaign_time or Game.CampaignTime
	PlayFX("SmokeZone", "start", self, self.gas_type)
end

--- Destroys the SmokeZone instance and removes all associated smoke objects.
---
--- This function is called when the SmokeZone is being destroyed or removed from the game. It removes the SmokeZone from the MapSmokeZones table, removes all smoke objects associated with the SmokeZone, and plays an "end" FX for the SmokeZone's gas_type.
function SmokeZone:Done()
	table.remove_value(MapSmokeZones, self)
	for _, wpt in pairs(self.smoke_positions) do
		self:RemoveSmokeFromPos(point_pack(WorldToVoxel(wpt)))
	end
	if IsValid(self.spinner) then
		DoneObject(self.spinner)
	end
	self.spinner = nil
	PlayFX("SmokeZone", "end", self, self.gas_type)
end

--- Removes a smoke object from a specific position in the game world.
---
--- This function is called when a smoke object needs to be removed from a specific position. It removes the smoke object from the list of smoke objects associated with the SmokeZone, plays an "end" FX for the smoke object's gas type, and destroys the smoke object if it is no longer associated with any SmokeZone.
---
--- @param self SmokeZone The SmokeZone instance that is removing the smoke object.
--- @param ppos table The position of the smoke object to be removed, represented as a packed point.
function SmokeZone:RemoveSmokeFromPos(ppos)
	local obj = g_SmokeObjs[ppos]
	if not IsValid(obj) then return end
	table.remove_value(obj.zones, self)
	PlayFX("VoxelGas", "end", obj, self.gas_type)
	if #obj.zones == 0 then
		DoneObject(obj)
		g_SmokeObjs[ppos] = nil
	else
		PlayFX("VoxelGas", "start", obj, obj:GetGasType())
	end
end

--- Propagates smoke from a SmokeZone object.
---
--- This function is responsible for updating the smoke positions associated with a SmokeZone. It first determines the grid coordinates of the SmokeZone, then uses the PropagateSmokeInGrid function to determine which grid positions should have smoke. It then removes any existing smoke objects that are no longer in the propagated smoke positions, and creates new smoke objects for any new propagated positions. Finally, it updates the smoke_positions table with the new propagated smoke positions, and creates a spinning visual effect for the SmokeZone if one does not already exist.
---
--- @param self SmokeZone The SmokeZone instance whose smoke is being propagated.
function SmokeZone:PropagateSmoke()
	local gx, gy, gz = WorldToVoxel(self)
	local smoke, blocked = PropagateSmokeInGrid(gx, gy, gz, self.smoke_dx, self.smoke_dy)
	
	-- remove existing smoke if it no longer propagates there (e.g. a fire started there, door closed, etc)
	for ppos, wpt in pairs(self.smoke_positions) do
		local gppos = point_pack(WorldToVoxel(wpt))
		if not smoke[ppos] then
			self:RemoveSmokeFromPos(gppos)
		end
	end
	
	-- update self.smoke_positions from smoke & create smoke objs if necessary
	for _, wpt in pairs(smoke) do
		local ppos = point_pack(WorldToVoxel(wpt))
		local obj = g_SmokeObjs[ppos]
		local gas_type = obj and obj:GetGasType()
		if not obj then
			obj = PlaceObject("SmokeObj")
			obj:SetPos(wpt)
			g_SmokeObjs[ppos] = obj
		end
		table.insert_unique(obj.zones, self)
		if not gas_type then
			PlayFX("VoxelGas", "start", obj, self.gas_type)
		end
	end
	self.smoke_positions = smoke
	
	if not self.spinner then
		local ppos = FindSmokeObjPos(smoke, blocked)
		if ppos then
			local x, y, z = point_unpack(ppos)
			local pos = self:GetPos() + point(x*sizex, y*sizex, z*sizez)
			local fx_class = "SmokeGrenadeSpinner"
			if self.gas_type == "teargas" then
				fx_class = "TearGasGrenadeSpinner"
			elseif self.gas_type == "toxicgas" then
				fx_class = "ToxicGasGrenadeSpinner"
			end
			local obj = PlaceObject("GrenadeVisual", {fx_actor_class = fx_class} )
			obj:SetPos(pos)
			obj:SetAnim(1, "rotating")
			PlayFX("SmokeGrenadeSpin", "start", obj)
			self.spinner = obj
		else
			self.spinner = "none" -- non-false/nil value to indicate we couldn't find a place for the object
		end
	end
end

---
--- Updates the remaining time of a smoke zone and removes the zone if the time has expired.
---
--- @param delta number The time delta since the last update.
--- @return boolean True if the smoke zone was removed, false otherwise.
---
function SmokeZone:UpdateRemainingTime(delta)
	local remaining = self.remaining_time - delta
	
	if remaining <= 0 or self.campaign_time < Game.CampaignTime then
		DoneObject(self)
		return true
	end
	self.remaining_time = remaining
	
	self:PropagateSmoke()
end

---
--- Serializes the dynamic data of the SmokeZone object.
---
--- @param data table A table to store the serialized data.
---
function SmokeZone:GetDynamicData(data)
	data.remaining_time = self.remaining_time or nil
	data.gas_type = self.gas_type or nil
	data.campaign_time = self.campaign_time or nil
	data.owner = self.owner and self.owner:GetHandle() or nil
	data.smoke_positions = self.smoke_positions and table.copy(self.smoke_positions) or nil
	if self.spinner and not IsValid(self.spinner) then
		data.spinner = self.spinner
	end
end

---
--- Sets the dynamic data of the SmokeZone object.
---
--- @param data table A table containing the dynamic data to set.
---   - remaining_time: number The remaining time of the smoke zone.
---   - gas_type: string The type of gas in the smoke zone.
---   - spinner: any A reference to the spinner object.
---   - owner: Object The owner of the smoke zone.
---   - campaign_time: number The campaign time when the smoke zone was created.
---   - smoke_positions: table A table of smoke positions.
---
function SmokeZone:SetDynamicData(data)
	self.remaining_time = data.remaining_time
	self.gas_type = data.gas_type
	self.spinner = data.spinner
	self.owner = HandleToObject[data.owner or false]
	self.campaign_time = data.campaign_time or Game.CampaignTime
	if self.campaign_time < Game.CampaignTime then
		return
	end
	if data.smoke_positions then
		self.smoke_positions = table.copy(data.smoke_positions)
		self:PropagateSmoke()
	end
	CreateGameTimeThread(function() 
		Sleep(1) -- delay until loading is done and game has started for real, otherwise PlaySound can fail due to actor being too far
		PlayFX("SmokeZone", "start", self)
	end)
end

---
--- Toggles the debug visualization of smoke objects and units in the game.
---
--- When enabled, this function will create visual boxes representing the smoke objects and units in the game. The boxes will be colored based on the type of gas in the smoke object.
---
--- When disabled, this function will remove all the debug visualization objects.
---
function ToggleGasDebug()
	if g_dbgSmokeVisuals then
		for _, obj in ipairs(g_dbgSmokeVisuals) do
			DoneObject(obj)
		end
		g_dbgSmokeVisuals = false
		return
	end
	
	g_dbgSmokeVisuals = {}
	local voxel_box = box(point(-const.SlabSizeX/2, -const.SlabSizeY/2, 0), point(const.SlabSizeX/2, const.SlabSizeY/2, const.SlabSizeZ))
	for ppos, obj in pairs(g_SmokeObjs) do
		local pt = point(VoxelToWorld(point_unpack(ppos)))		
		if not pt:IsValidZ() then
			pt = pt:SetTerrainZ()
		end
		
		local gas_box = voxel_box + pt
		local color = const.clrGray
		local gas = obj:GetGasType()
		if gas == "teargas" then
			color = const.clrYellow
		elseif gas == "toxicgas" then
			color = const.clrGreen
		end
		local mesh = PlaceBox(gas_box, color, nil, false)
		table.insert(g_dbgSmokeVisuals, mesh)
	end
	
	for _, unit in ipairs(g_Units) do
		local voxels, head = unit:GetVisualVoxels()		
		for _, voxel in ipairs(voxels) do
			local pt = point(VoxelToWorld(point_unpack(voxel)))
			local unit_box = MulDivRound(voxel_box, 9, 10) + pt
			local color = const.clrWhite
			if voxel == head then
				if g_SmokeObjs[head] then
					color = const.clrRed
				else
					color = const.clrBlue
				end
			end
			local mesh = PlaceBox(unit_box, color, nil, false)
			table.insert(g_dbgSmokeVisuals, mesh)
		end
	end
end

DefineClass.Flare = {
	__parents = { "Grenade" },
	properties = {
		{ category = "Combat", id = "Expires", editor = "bool", default = true, template = true, },
		{ category = "Combat", id = "ExpirationTurns", editor = "number", min = 1, default = 4, template = true, },
		{ category = "Combat", id = "Despawn", editor = "bool", default = false, template = true },
	},
}

---
--- Called when the Flare grenade is about to be thrown.
--- This function is called on the client that is throwing the grenade.
---
--- @param thrower Unit The unit throwing the grenade.
--- @param visual GameVisualObject The visual representation of the grenade.
---
function Flare:OnPrepareThrow(thrower, visual)
	--this happens on one client only
	PlayFX("Flare", "start", visual)
	ResetVoxelStealthParamsCache()
end

---
--- Called when the Flare grenade has finished being thrown.
--- This function is called on the client that threw the grenade.
---
--- @param thrower Unit The unit that threw the grenade.
---
function Flare:OnFinishThrow(thrower)
	ResetVoxelStealthParamsCache()
end

---
--- Called when the Flare grenade has landed on the ground.
--- This function is called on the client that threw the grenade.
---
--- @param thrower Unit The unit that threw the grenade.
--- @param attackResults table The results of the grenade attack.
--- @param visual_obj GameVisualObject The visual representation of the grenade.
---
function Flare:OnLand(thrower, attackResults, visual_obj)
	local pos = attackResults.explosion_pos
	local snapped = false
	local sync = false
	if pos then
		snapped = SnapToPassSlab(pos:xyz()) or pos
		if snapped then
			sync = true
		end
	end
	if not snapped then
		snapped = IsValid(visual_obj) and visual_obj:GetPos()
	end
	if not snapped then
		return
	end
	pos = pos or snapped
	if snapped:IsValidZ() then
		pos = pos:SetZ(snapped:z())
	else
		pos = pos:SetInvalidZ()
	end
	local flare = PlaceObject("FlareOnGround")
	flare:SetPos(pos)
	flare.item_class = self.class
	flare.campaign_time = Game.CampaignTime
	flare.Despawn = self.Despawn
	if self.Expires then
		flare.remaining_time = self.ExpirationTurns * 5000
	end
	flare:UpdateVisualObj()
	PushUnitAlert("thrown", flare, thrower)
	
	if self.ThrowNoise > 0 then
		-- <Unit> Heard a thud
		PushUnitAlert("noise", visual_obj, self.ThrowNoise, Presets.NoiseTypes.Default.ThrowableLandmine.display_name)
	end
	if IsValid(visual_obj) then
		DoneObject(visual_obj)
	end
end

DefineClass.FlareOnGround = {
	__parents = { "GameDynamicSpawnObject" },
	item_class = "FlareStick",
	visual_obj = false,
	remaining_time = -1,
	campaign_time = false,
	Despawn = true,
}

--- Adds the current FlareOnGround object to the global MapFlareOnGround table.
-- This function is called when a new FlareOnGround object is created, and ensures
-- that the object is tracked in the global table for later processing.
function FlareOnGround:GameInit()
	table.insert(MapFlareOnGround, self)
end

--- Removes the current FlareOnGround object from the global MapFlareOnGround table.
-- This function is called when a FlareOnGround object is destroyed, and ensures
-- that the object is removed from the global table.
function FlareOnGround:Done()
	table.remove_value(MapFlareOnGround, self)
end

--- Updates the visual object associated with the FlareOnGround instance.
--
-- If the visual object is not valid, a new one is created with the appropriate
-- actor class based on the item_class property.
--
-- The visual object is then attached to the FlareOnGround instance, and if the
-- start_fx parameter is true, the "Flare" FX is played on the visual object.
--
-- Finally, the voxel stealth parameters cache is reset to ensure the visual
-- changes are properly reflected.
--
-- @param start_fx boolean Whether to play the "Flare" FX on the visual object.
function FlareOnGround:UpdateVisualObj(start_fx)
	if not IsValid(self.visual_obj) then
		self.visual_obj = PlaceObject("GrenadeVisual", {fx_actor_class = self.item_class .. "_OnGround"})
	end
	self:Attach(self.visual_obj)
	if start_fx then
		PlayFX("Flare", "start", self.visual_obj)
	end
	ResetVoxelStealthParamsCache()
end

---
--- Updates the remaining time for a FlareOnGround object.
---
--- If the campaign time has changed since the last update, the object is destroyed.
--- Otherwise, the remaining time is decremented by the provided delta value.
--- When the remaining time reaches 0, the "Flare" FX is stopped, and the object is either
--- despawned or its remaining time is set to -1 to indicate it is no longer active.
---
--- @param delta number The time delta to subtract from the remaining time.
---
function FlareOnGround:UpdateRemainingTime(delta)
	if Game.CampaignTime ~= self.campaign_time then
		DoneObject(self)
		return
	end
	if self.remaining_time < 0 then return end
	
	self.remaining_time = Max(0, self.remaining_time - delta)
	if self.remaining_time == 0 then
		PlayFX("Flare", "end", self.visual_obj)
		local attaches = self.visual_obj:GetAttaches("Weapon_FlareStick_OnGround")
		for _, obj in ipairs(attaches) do
			PlayFX("Flare", "end", obj)
		end
		if self.Despawn then
			DoneObject(self)
		else
			self.remaining_time = -1
		end
		ResetVoxelStealthParamsCache()
	end
end

---
--- Forcefully updates the remaining time for all FlareOnGround objects to a very large value, effectively making them never expire.
---
--- This function is likely used for testing or debugging purposes, to keep flares active indefinitely.
---
--- @function TestKillFlares
--- @return nil
function TestKillFlares()
	for _, f in ipairs(MapFlareOnGround) do
		f:UpdateRemainingTime(99999999)
	end
end

---
--- Retrieves the dynamic data for a FlareOnGround object.
---
--- The dynamic data includes the item class, remaining time, and campaign time of the FlareOnGround object.
---
--- @param data table A table to store the dynamic data.
--- @return nil
function FlareOnGround:GetDynamicData(data)
	data.item_class = self.item_class
	data.remaining_time = self.remaining_time
	data.campaign_time = self.campaign_time
end

---
--- Sets the dynamic data for a FlareOnGround object.
---
--- The dynamic data includes the item class, remaining time, and campaign time of the FlareOnGround object.
---
--- @param data table A table containing the dynamic data to set.
--- @return nil
function FlareOnGround:SetDynamicData(data)
	self.item_class = data.item_class
	self.remaining_time = data.remaining_time
	self.campaign_time = data.campaign_time
	self:UpdateVisualObj(self.remaining_time ~= 0)
end

DefineClass.Weapon_SmokeGrenade = { __parents = {"Weapon_SmokeGrenade_Base"}, entity = "Weapon_SmokeGrenade", }
DefineClass.Weapon_SmokeGrenade_Spinning = { __parents = {"Weapon_SmokeGrenade_Base"}, entity = "Weapon_SmokeGrenade", }
DefineClass.Weapon_TearGasGrenade = { __parents = {"Weapon_SmokeGrenade_Base"}, entity = "Weapon_SmokeGrenade", }
DefineClass.Weapon_TearGasGrenade_Spinning = { __parents = {"Weapon_SmokeGrenade_Base"}, entity = "Weapon_SmokeGrenade", }
DefineClass.Weapon_ToxicGasGrenade = { __parents = {"Weapon_SmokeGrenade_Base"}, entity = "Weapon_SmokeGrenade", }
DefineClass.Weapon_ToxicGasGrenade_Spinning = { __parents = {"Weapon_SmokeGrenade_Base"}, entity = "Weapon_SmokeGrenade", }

DefineClass.Weapon_PipeBomb = { __parents = {"GrenadeVisual"}, entity = "Weapon_PipeBomb", }
DefineClass.Weapon_PipeBomb_OnGround = { __parents = {"GrenadeVisual"}, entity = "Weapon_PipeBomb", }

DefineClass.Weapon_FlareStick = { __parents = {"GrenadeVisual"}, entity = "World_Flarestick_01", }
DefineClass.Weapon_FlareStick_OnGround = { __parents = {"GrenadeVisual"}, entity = "World_Flarestick_01", }
DefineClass.Weapon_GlowStick = { __parents = {"GrenadeVisual"}, entity = "Weapon_GlowStick", }
DefineClass.Weapon_GlowStick_OnGround = { __parents = {"GrenadeVisual"}, entity = "Weapon_GlowStick", }

DefineClass.Weapon_ProximityTNT = { __parents = {"GrenadeVisual"}, entity = "Explosive_TNT", }
DefineClass.Weapon_ProximityTNT_OnGround = { __parents = {"GrenadeVisual"}, entity = "Explosive_TNT", }
DefineClass.Weapon_RemoteTNT = { __parents = {"GrenadeVisual"}, entity = "Explosive_TNT", }
DefineClass.Weapon_RemoteTNT_OnGround = { __parents = {"GrenadeVisual"}, entity = "Explosive_TNT", }
DefineClass.Weapon_TimedTNT = { __parents = {"GrenadeVisual"}, entity = "Explosive_TNT", }
DefineClass.Weapon_TimedTNT_OnGround = { __parents = {"GrenadeVisual"}, entity = "Explosive_TNT", }

DefineClass.Weapon_ProximityC4 = { __parents = {"GrenadeVisual"}, entity = "Explosive_C4", }
DefineClass.Weapon_ProximityC4_OnGround = { __parents = {"GrenadeVisual"}, entity = "Explosive_C4", }
DefineClass.Weapon_RemoteC4 = { __parents = {"GrenadeVisual"}, entity = "Explosive_C4", }
DefineClass.Weapon_RemoteC4_OnGround = { __parents = {"GrenadeVisual"}, entity = "Explosive_C4", }
DefineClass.Weapon_TimedC4 = { __parents = {"GrenadeVisual"}, entity = "Explosive_C4", }
DefineClass.Weapon_TimedC4_OnGround = { __parents = {"GrenadeVisual"}, entity = "Explosive_C4", }

DefineClass.Weapon_ProximityPETN = { __parents = {"GrenadeVisual"}, entity = "Explosive_PETN", }
DefineClass.Weapon_ProximityPETN_OnGround = { __parents = {"GrenadeVisual"}, entity = "Explosive_PETN", }
DefineClass.Weapon_RemotePETN = { __parents = {"GrenadeVisual"}, entity = "Explosive_PETN", }
DefineClass.Weapon_RemotePETN_OnGround = { __parents = {"GrenadeVisual"}, entity = "Explosive_PETN", }
DefineClass.Weapon_TimedPETN = { __parents = {"GrenadeVisual"}, entity = "Explosive_PETN", }
DefineClass.Weapon_TimedPETN_OnGround = { __parents = {"GrenadeVisual"}, entity = "Explosive_PETN", }
