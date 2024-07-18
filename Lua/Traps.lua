MaxTrapTriggerRadius = 5
local voxelSizeX = const.SlabSizeX

DefineClass.TrapExplosionProperties = {
	__parents = { "ExplosiveProperties" },
	properties = {
		{ category = "Trap", id = "BaseDamage", name = "Base Damage", 
			editor = "number", default = 30, template = true, min = 0, max = 200, },
		{ category = "Trap", id = "Noise", name = "Noise", help = "in tiles", 
			editor = "number", default = 20, template = true, min = 0, max = 100, },
		{ category = "Trap", id = "aoeType", name = "AOE Type", editor = "dropdownlist", items = {"none", "fire", "smoke", "teargas", "toxicgas"}, default = "none", help = "additional effect that happens after the explosion (optional)" },
	}
}

-- This class holds the properties of a trap, and is reused by those
-- who want to show them/set them without trap logic behind it. Such as TrapSpawnMarker
DefineClass.TrapProperties = {
	__parents = { "TrapExplosionProperties", "DamagePredictable" },
	properties = {
		{ category = "Trap", id = "visibility", name = "Visible By", editor = "set", default = set{ enemy1 = true, enemy2 = true, enemyNeutral = true, neutral = true }, items = function() return Sides end,
			help = "Teams which can see this trap regardless of where their members are." },
		{ category = "Trap", id = "visibilityRange", name = "Visible At (Voxels)", editor = "number", default = 3, help = "How far the trap can be seen from." },
		{ category = "Trap", id = "revealDifficulty", name = "Reveal Skill Requirement", editor = "combo", items = const.DifficultyPresetsNew, arbitrary_value = false, default = "Easy",
			help = "The required explosives skill to reveal the trap when within default voxels." },
		{ category = "Trap", id = "disarmDifficulty", name = "Disarm Requirement", editor = "combo", items = const.DifficultyPresetsNew, arbitrary_value = false, default = "Medium",
			help = "The required mechanical skill to disarm the trap." },
		{ category = "Trap", id = "randomDifficulty", name = "Randomize Difficulty", editor = "bool", default = true,
			help = "Randomly add -10/10 points to the disarm difficulty of the trap."},
		{ category = "Trap", id = "triggerChance", name = "Trigger Chance", editor = "combo", items = const.DifficultyPresetsNew, arbitrary_value = false, default = "VeryHard",
			help = "The percent chance for the trap to trigger when disarming fails or is walked over." },
		{ category = "Trap", id = "done", name = "Triggered", editor = "bool", default = false, help = "Whether the trap is considered to have already been disarmed and/or triggered." },
		{ category = "Trap", id = "triggerRadius", name = "Trigger At (Voxels)", editor = "number", default = 1, help = "How many voxels to trigger from." },
	},
}

---
--- Returns a table of property values that are different from the default values.
---
--- @return table The table of property values that are different from the default values.
function TrapProperties:GetPropertyList()
	local properties = TrapProperties:GetProperties()
	local values = {}
	for i = 1, #properties do
		local prop = properties[i]
		if not prop_eval(prop.dont_save, self, prop) then
			local prop_id = prop.id
			local value = self:GetProperty(prop_id)
			local is_default = value == nil or value == self:GetDefaultPropertyValue(prop_id, prop)
			if not is_default then
				values[prop_id] = value
			end
		end
	end
	return values
end

---
--- Applies a list of property values to the current object.
---
--- @param list table The table of property values to apply.
---
function TrapProperties:ApplyPropertyList(list)
	for name, value in pairs(list) do
		if self:HasMember(name) then
			self:SetProperty(name, value)
		end
	end
end

-- This class implements the basic trap functionality
DefineClass.Trap = {
	__parents = { "TrapProperties", "GameDynamicDataObject" },
	properties = {
		{ category = "Visuals", id = "DisplayName", name = "Display Name", editor = "text", default = T(726087963038, "Trap"), translate = true, no_edit = true },
	},
	
	additionalDifficulty = 0, -- Difficulty added by random difficulty
	disarmed = false,
	done = false,
	dud = false,
	visible = true,
	toExplode = false,
	discovered_trap = false,
	
	-- PrecalcDamageAndStatusEffects compatibility
	IgnoreCoverReduction = 0,
	AppliedEffect = "",
}

---
--- Initializes a new trap object.
---
--- This function is called when a new trap object is created. It sets the additional difficulty of the trap based on a random value, and adds the trap to the global `g_Traps` table.
---
--- @param self Trap The trap object being initialized.
---
function Trap:Init()
	if self.randomDifficulty then
		self.additionalDifficulty = InteractionRand(20, "Traps") / 2
	end
	
	if g_Traps then
		g_Traps[#g_Traps + 1] = self
	end
end

---
--- Initializes the game state for a trap object.
---
--- This function is called when a trap object is first created. It checks if the trap is placed below the terrain, and stores an error source if so.
---
--- @param self Trap The trap object being initialized.
---
function Trap:GameInit()
	local pos = self:GetPos()
	local actual_trap = (not IsKindOf(self, "Door")) and (self.boobyTrapType ~= BoobyTrapTypeNone) -- :(
	if not self.spawned_by_explosive_object and pos ~= InvalidPos() and actual_trap and pos:IsValidZ() and pos:z() < terrain.GetHeight(pos) then
		StoreErrorSource(self, "Trap placed below terrain")
	end
end

---
--- Retrieves the dynamic data for the trap object.
---
--- This function is called to get the current state of the trap object, including whether it is disarmed, discovered, or completed. The retrieved data is stored in the provided `data` table.
---
--- @param self Trap The trap object.
--- @param data table A table to store the dynamic data for the trap.
---
function Trap:GetDynamicData(data)
	if self.done then data.done = self.done end
	if self.randomDifficulty then data.additionalDifficulty = self.additionalDifficulty end
	if self.disarmed then data.disarmed = self.disarmed end
	if self.discovered_trap then data.discovered_trap = self.discovered_trap end
end

---
--- Sets the dynamic data for the trap object.
---
--- This function is called to update the current state of the trap object, including whether it is disarmed, discovered, or completed. The provided `data` table contains the updated values for these properties.
---
--- @param self Trap The trap object.
--- @param data table A table containing the updated dynamic data for the trap.
---
function Trap:SetDynamicData(data)
	self.done = data.done or false
	self.additionalDifficulty = data.additionalDifficulty or 0
	self.disarmed = data.disarmed or false
	self.dud = data.dud or false
	if data.discovered_trap ~= nil then
		self.discovered_trap = data.discovered_trap
	end
end

---
--- Marks the trap as discovered.
---
--- This function is called when the trap is discovered by a player or other entity. It sets the `discovered_trap` flag to `true`, indicating that the trap has been found.
---
--- @param self Trap The trap object.
---
function Trap:CheckDiscovered()
	self.discovered_trap = true
end

---
--- Returns the combat log message for when a trap is disarmed.
---
--- @param self Trap The trap object.
--- @return string The combat log message for disarming the trap.
---
function Trap:GetDisarmCombatLogMessage()
	return T(747957833518, "<TrapName> <em>disarmed</em> by <Nick> <em>(<stat>)</em>")
end

---
--- Attempts to disarm a trap.
---
--- This function is called when a unit attempts to disarm a trap. It checks the unit's relevant stat (e.g. Explosives) against the trap's disarm difficulty, and determines whether the disarm attempt is successful or not. If successful, it logs the disarm event, awards the unit some parts, and marks the trap as disarmed. If the disarm attempt fails, it triggers the trap.
---
--- @param self Trap The trap object.
--- @param unit table The unit attempting to disarm the trap.
--- @param stat string (optional) The stat used for the disarm check. Defaults to "Explosives".
--- @return string "success" if the disarm attempt was successful, "fail" otherwise.
---
function Trap:AttemptDisarm(unit, stat)
	if IsSetpiecePlaying() then return end
	stat = stat or "Explosives"
	
	local statPreset = table.find_value(UnitPropertiesStats:GetProperties(), "id", stat)
	local statT = statPreset and statPreset.name or Untranslated("Unknown Stat")
	local disarmCheck = unit[stat]
	
	if HasPerk(unit, "MrFixit") then
		disarmCheck = disarmCheck + CharacterEffectDefs.MrFixit:ResolveValue("mrfixit_bonus")
	end
	
	local trapName = self:GetTrapDisplayName()
	local success = (disarmCheck > DifficultyToNumber(self.disarmDifficulty) + self.additionalDifficulty) or CheatEnabled("SkillCheck")
	if success then
		local msg = self:GetDisarmCombatLogMessage()
		local msgCtx = SubContext(unit, {TrapName = trapName, stat = statT})
		CombatLog("important", T{msg, msgCtx})
		CreateFloatingText(self:GetVisualPos(), T{386434780847, "<em><stat></em> success", TrapName = trapName, stat = statT}, "BanterFloatingText")
		
		--Get parts for successful disarm
		local partsCount = 1 + unit:Random(2)
		AddItemToSquadBag(unit.Squad, "Parts", partsCount)
		CreateFloatingText(unit:GetVisualPos(), T{178669996888, "Salvaged <Amount> parts", Amount = partsCount})
		
		self.disarmed = true
		self.done = true
		ObjModified("combat_bar_traps")
		PlayFX("TrapDisarmed", "start", self)
	else
		CreateFloatingText(self:GetVisualPos(), T{338382091310, "<em><stat></em> failure!", TrapName = trapName, stat = statT}, "BanterFloatingText")
		self:TriggerTrap(unit)
	end
	Msg("TrapDisarm", self, unit, success, stat)
	
	return success and "success" or "fail"
end

---
--- Triggers a trap, causing it to explode.
---
--- This function is called to trigger a trap, causing it to explode and damage the specified victim. The trap's Explode method is called with the victim, attacker, and other relevant parameters.
---
--- @param self Trap The trap object.
--- @param victim table The unit or object that triggered the trap.
--- @param attacker table (optional) The unit or object that caused the trap to be triggered.
---
function Trap:TriggerTrap(victim, attacker)
	self:Explode(victim, nil, nil, attacker)
end

---
--- Explodes a trap, causing damage and other effects.
---
--- This function is called to explode a trap, causing damage to the specified victim and other effects. The trap's FXGrenade object is placed at the trap's position, and the explosion damage is calculated and applied. If the trap is a dud, a dud message is logged and the explosion FX is played.
---
--- @param victim table The unit or object that triggered the trap.
--- @param fx_actor string (optional) The FX actor class to use for the explosion.
--- @param state string (optional) The state to set the trap to after the explosion.
--- @param attacker table (optional) The unit or object that caused the trap to be triggered.
---
function Trap:Explode(victim, fx_actor, state, attacker)
	self.victim = victim
	self.done = true
	ObjModified("combat_bar_traps")
	
	-- Track who exploded the trap and handle chain explosions
	self.attacker = IsKindOf(attacker, "Trap") and attacker.attacker or attacker
	
	local trapName = self:GetTrapDisplayName()
	local pos = self:GetPos()
	local proj = PlaceObject("FXGrenade")
	proj.fx_actor_class = fx_actor or "Landmine"
	proj:SetPos(pos)
	proj:SetOrientation(self:GetOrientation())
	
	-- Check if dud
	local rand = InteractionRand(100)
	if rand > DifficultyToNumber(self.triggerChance) then
		self.discovered_trap = true
		self.dud = true
		CombatLog("important", T{536546697372, "<TrapName> was a dud.", TrapName = trapName})
		CreateFloatingText(self:GetVisualPos(), T{372675206288, "<TrapName> was <em>a dud</em>", TrapName = trapName}, "BanterFloatingText")
		PlayFX("Explosion", "failed", self)
		DoneObject(proj)
		return
	end
	
	if IsKindOf(self, "ContainerMarker") and not self:GetItemInSlot("Inventory", "QuestItem") then
		self.enabled = false
		self:UpdateHighlight()
	end
	
	state = state or "explode"
	CreateGameTimeThread(function()
		-- Moved ExplosionDamage and DoneObject here, so that if the current thread is the unit's that attempting the disarm
		-- it will still clean up the object.
		local isOnGround = true
		if self.spawned_by_explosive_object then
			isOnGround = IsOnGround(self.spawned_by_explosive_object)
		end
		ExplosionDamage(self, self, pos, proj, "fly_off", not isOnGround)
		DoneObject(proj)
		if state ~= "explode" then Sleep(50) end
		if self:HasState(state) then
			self:SetState(state)
		end
	end)

	if not self.spawned_by_explosive_object then
		-- Exploded
		CombatLog("important", T{811751960646, "<TrapName> <em>detonated</em>!", TrapName = trapName})
		CreateFloatingText(self:GetVisualPos(), T{463301911995, "<TrapName> <em>explodes</em>!", TrapName = trapName}, "BanterFloatingText")
	end
end

-- Weapon, Action, and Unit API

---
--- Applies hit damage reduction to the trap.
---
--- @param hit table The hit information.
--- @param weapon table The weapon that caused the hit.
--- @param hit_body_part string The body part that was hit.
--- @param attack_pos vector3 The position of the attack.
--- @param ignore_cover boolean Whether to ignore cover.
--- @param ignore_armor boolean Whether to ignore armor.
--- @param record_breakdown boolean Whether to record the damage breakdown.
---
function Trap:ApplyHitDamageReduction(hit, weapon, hit_body_part, attack_pos, ignore_cover, ignore_armor, record_breakdown)
end

---
--- Calculates the parameters for an area-of-effect attack for the trap.
---
--- @param action_id string The ID of the action being performed.
--- @param attacker table The entity performing the attack.
--- @param target_pos vector3 The position of the target.
--- @param step_pos vector3 The position of the attack step.
--- @return table The parameters for the area-of-effect attack.
---
function Trap:GetAreaAttackParams(action_id, attacker, target_pos, step_pos)
	target_pos = target_pos or self:GetPos()
	local aoeType = self.aoeType
	local range = self.AreaOfEffect
	if aoeType == "fire" then
		range = 2
	end
	local params = {
		attacker = attacker,
		weapon = self,
		target_pos = target_pos,
		step_pos = step_pos or target_pos,
		stance = "Standing",
		min_range = range,
		max_range = range,
		center_range = self.CenterAreaOfEffect,
		damage_mod = 100,
		attribute_bonus = 0,
		aoe_type = aoeType,
		can_be_damaged_by_attack = true,
		explosion = true, -- damage dealt depends on target stance
	}
	return params
end

---
--- Returns the trajectory of the trap.
---
--- @return table The trajectory of the trap, which is a table of positions.
---
function Trap:GetTrajectory()
	return { { pos = self:GetPos() } }
end

---
--- Returns the impact force of the trap.
---
--- @return number The impact force of the trap, which is always 0.
---
function Trap:GetImpactForce()
	return 0
end

---
--- Returns the distance impact force of the trap.
---
--- @return number The distance impact force of the trap, which is always 0.
---
function Trap:GetDistanceImpactForce()
	return 0
end

---
--- Precalculates the damage and status effects for a trap.
---
--- @param ... Additional arguments to pass to the `ExplosionPrecalcDamageAndStatusEffects` function.
--- @return table The precalculated damage and status effects.
---
function Trap:PrecalcDamageAndStatusEffects(...)
	return ExplosionPrecalcDamageAndStatusEffects(self, ...)
end

---
--- Checks if the trap is dead.
---
--- @return boolean True if the trap is dead, false otherwise.
---
function Trap:IsDead()
	return self.done
end

---
--- Checks if the trap will damage the given hit.
---
--- @param hit table The hit to check if it will be damaged.
--- @return boolean True if the trap will damage the hit, false otherwise.
---
function Trap:HitWillDamage(hit)
	return true
end

---
--- Checks if the trap has any status effects.
---
--- @return boolean False, as traps do not have any status effects.
---
function Trap:HasStatusEffect()
	return false
end

---
--- Checks if the trap can be attacked.
---
--- @return boolean False, as traps cannot be attacked.
---
function Trap:CanBeAttacked()
	return false
end

---
--- Determines whether the trap should be discoverable.
---
--- @return boolean True if the trap should be discoverable, false otherwise.
---
function Trap:RunDiscoverability()
	return not self.spawned_by_explosive_object and (self:CanBeAttacked() or not self.discovered_trap)
end

---
--- Returns the body parts that the trap can target.
---
--- @return table The list of body parts that the trap can target.
---
function Trap:GetBodyParts()
	return { Presets.TargetBodyPart.Default.Trap }
end

---
--- Returns the display name of the trap.
---
--- @return string The display name of the trap.
---
function Trap:GetTrapDisplayName()
	return self.DisplayName
end

---
--- Returns a list of visible traps for the given attacker.
---
--- @param attacker table The attacker object.
--- @param class string (optional) The class of traps to filter for. Defaults to "Trap".
--- @param exact boolean (optional) If true, the class must match exactly. Otherwise, it checks if the trap is a kind of the given class.
--- @return table A list of visible traps.
---
function GetVisibleTraps(attacker, class, exact)
	class = class or "Trap"
	local filtered = {}
	local visible = g_AttackableVisibility[attacker] or empty_table
	for i, t in ipairs(visible) do
		local classMatch = false
		if exact then
			classMatch = t.class == class
		else
			classMatch = IsKindOf(t, class)
		end
		if classMatch and not t.done and not t:IsDead() then
			filtered[#filtered + 1] = t
		end
	end
	return filtered
end

---
--- Returns the best visible trap for the given attacker.
---
--- @param attacker table The attacker object.
--- @param traps table (optional) The list of traps to consider. If not provided, it will use the result of `GetVisibleTraps`.
--- @return table, string The best visible trap and its status ("good" or "bad").
---
function GetBestVisibleTrap(attacker, traps)
	traps = traps or GetVisibleTraps(attacker)
	
	local closest = false
	for i, t in ipairs(traps) do
		if UIIsObjectAttackGood(t) then
			return t, "good"
		end
		
		if not closest or IsCloser(attacker, t, closest) then
			closest = t
		end
	end
	
	return closest, "bad"
end

---
--- Reveals all traps on the map for the given team.
---
--- @param team table The team whose traps should be revealed. If not provided, the current player's team is used.
---
function CheatRevealTraps(team)
	if not team then
		team = GetPoVTeam()
		if g_Combat then
			g_Combat.visibility_update_hash = 0
		end
	end
	if not team then return end

	local traps = MapGet("map", "Trap")
	for _, trap in ipairs(traps or empty_table) do
		if IsKindOf(trap, "BoobyTrappable") and trap.boobyTrapType == BoobyTrapTypeNone then goto continue end
	
		local in_sight
		for _, unit in ipairs(team.units) do
			if unit:GetDist(trap) <= unit:GetSightRadius(trap) then
				in_sight = true
				break
			end
		end
		if in_sight then
			trap.visibility[team.side] = true
			if IsKindOf(trap, "Landmine") then
				trap.discovered_by[team.side] = true
			end
			trap.discovered_trap = true
			if IsKindOf(trap, "BoobyTrappable") then
				trap:UpdateHighlight()
			end
		end
		
		::continue::
	end
	InvalidateVisibility()
end

LandmineTriggerType = {
	"Contact", -- Grenade
	"Proximity", -- Landmine
	"Timed",
	"Remote",
	"Proximity-Timed"
}

local LandmineTriggerTypeDisplayName = {
	T(209120891331, "grenade"),
	T(188077683373, "proximity triggered"),
	T(179251814136, "timed"),
	T(711268279145, "remotely triggered"),
	T(815333890835, "proximity triggered with a timer"),
}

local lLandmineTriggerToInventoryText = {
	T(842390201083, "CON"),
	T(116809452892, "PRO"),
	T(276592979687, "TIM"),
	T(531315317082, "REM"),
	T(241009334356, "PRT"),
}

--- Generates a table of IDs for all ExplosiveSubstance inventory items.
---
--- This function iterates through all InventoryItemCompositeDef presets and
--- collects the IDs of those that have an object class that inherits from
--- ExplosiveSubstance.
---
--- @return table An array of inventory item IDs for ExplosiveSubstance items.
function ExplosiveSubstanceCombo()
	local arr = {}
	ForEachPreset("InventoryItemCompositeDef", function(o)
		local class = o.object_class and g_Classes[o.object_class]
		if class and IsKindOf(class, "ExplosiveSubstance") then
			arr[#arr + 1] = o.id
		end
	end)
	return arr
end

--- Generates a table of IDs for all Grenade inventory items.
---
--- This function iterates through all InventoryItemCompositeDef presets and
--- collects the IDs of those that have an object class of "Grenade".
---
--- @return table An array of inventory item IDs for Grenade items.
function GrenadeCombo()
	local arr = {}
	ForEachPreset("InventoryItemCompositeDef", function(o)
		if o.object_class == "Grenade" then
			arr[#arr + 1] = o.id
		end
	end)
	return arr
end

DefineClass.LandmineProperties = {
	__parents = { "PropertyObject" },
	properties = {
		{ category = "Trap", id = "TriggerType", editor = "choice", items = LandmineTriggerType, default = "Contact", template = true },
		{ category = "Trap", id = "TimedExplosiveTurns", editor = "number", default = 1, template = true, help = "In exploration each turn is 5 seconds." },
		{ category = "Trap", id = "GrenadeExplosion", editor = "combo", items = GrenadeCombo, default = false },
	}
}

-- Conditionally visible trap which explodes when you step on it.
DefineClass.Landmine = {
	__parents = { "Interactable", "Trap", "CombatObject", "VoxelSnappingObj", "LandmineProperties" },
	visible = false,
	TriggerType = "Proximity",

	flags = { efApplyToGrids = false },
	DisplayName = T(328265525186, "Landmine"),
	entity = "MilitaryCamp_Landmine",

	victim = false,
	discovered_by = false,
	trigger_radius_fx = false,
	triggerRadius = 1,
	
	timer_text = false,
	timer_passed = false,
	team_side = "neutral",
	attacker = false,
	
	sector_init_called = false -- After all the dynamic data has been set.
}

--- Initializes a new Landmine object.
---
--- This function sets the initial hit points, max hit points, and visibility of the Landmine.
--- It also initializes the discovered_by table, which tracks which teams have discovered the Landmine.
---
--- @param self Landmine The Landmine object being initialized.
function Landmine:Init()
	self.HitPoints = 1
	self.MaxHitPoints = 1
	self.discovered_by = {}
	
	self:SetVisible(self.visible)
end

---
--- Initializes a Landmine object when the sector it is in is entered.
---
--- This function sets the `sector_init_called` flag to true, indicating that the Landmine has been initialized for the current sector.
--- It then updates the visual effects for the timed explosion and the trigger radius of the Landmine.
---
--- @param self Landmine The Landmine object being initialized.
---
function Landmine:EnterSectorInit()
	self.sector_init_called = true
	self:UpdateTimedExplosionFx()
	self:UpdateTriggerRadiusFx()
end

function OnMsg.EnterSector()
	MapForEach("map", "Landmine", Landmine.EnterSectorInit)
	MapForEach("map", "ExplosiveObject", ExplosiveObject.EnterSectorInit)
end

function OnMsg.DbgStartExploration()
	MapForEach("map", "Landmine", Landmine.EnterSectorInit)
	MapForEach("map", "ExplosiveObject", ExplosiveObject.EnterSectorInit)
end

--- Returns the initial maximum hit points of the Landmine.
---
--- This function returns the initial maximum hit points of the Landmine object. The Landmine's maximum hit points are set to 1 in the `Landmine:Init()` function.
---
--- @return integer The initial maximum hit points of the Landmine.
function Landmine:GetInitialMaxHitPoints()
	return 1
end

---
--- Moves the Landmine object and updates the trigger radius visual effects.
---
--- This function is called when the Landmine object is moved in the editor. It first calls the `VoxelSnappingObj.EditorCallbackMove()` function to handle the movement of the object. It then calls the `Landmine:UpdateTriggerRadiusFx()` function to update the visual effects for the trigger radius of the Landmine.
---
--- @param self Landmine The Landmine object being moved.
---
function Landmine:EditorCallbackMove()
	VoxelSnappingObj.EditorCallbackMove(self)
	self:UpdateTriggerRadiusFx()
end

---
--- Checks if the Landmine is visible to the specified team.
---
--- This function returns true if the Landmine is visible to the specified team, either because it has been discovered by that team or because its visibility flag is set for that team.
---
--- @param self Landmine The Landmine object.
--- @param side integer The team side to check visibility for.
--- @return boolean True if the Landmine is visible to the specified team, false otherwise.
function Landmine:SeenByTeam(side)
	return self.visibility[side] or self.discovered_by[side]
end

---
--- Checks if the specified unit has discovered the Landmine.
---
--- This function checks if the specified unit has discovered the Landmine. If the unit has not seen the Landmine, it checks if the unit's Explosives skill is greater than or equal to the Landmine's reveal difficulty. If the unit can see the Landmine or has the required Explosives skill, the Landmine's discovered_by flag for the unit's team is set to true, and the discovered_trap flag is set to true. A "TrapDiscovered" message is then sent.
---
--- @param self Landmine The Landmine object.
--- @param unit table The unit to check for discovery of the Landmine.
--- @return boolean True if the Landmine has been discovered by the unit, false otherwise.
function Landmine:CheckDiscovered(unit)
	if not self:SeenBy(unit) then
		local numDiff = DifficultyToNumber(self.revealDifficulty)
		if numDiff == -1 or unit.Explosives <= numDiff then
			return false
		end
	end

	-- If the visibility check passed the team can now see the trap forever.
	self.discovered_by[unit.team.side] = true
	self.discovered_trap = true
	Msg("TrapDiscovered", self, unit)
end

---
--- Checks if the specified unit can see the Landmine.
---
--- This function returns true if the specified unit can see the Landmine, either because the Landmine is visible to the unit's team or because the unit has discovered the Landmine.
---
--- @param self Landmine The Landmine object.
--- @param unit table The unit to check if it can see the Landmine.
--- @return boolean True if the unit can see the Landmine, false otherwise.
function Landmine:SeenBy(unit)
	return IsValid(unit) and self:SeenByTeam(unit.team.side)
end

---
--- Returns the combat action for interacting with the Landmine.
---
--- If the Landmine is visible and not done, this function returns the "Interact_Disarm" combat action preset, which allows the unit to interact with the Landmine to disarm it.
---
--- @param self Landmine The Landmine object.
--- @param unit table The unit attempting to interact with the Landmine.
--- @return table|nil The combat action for interacting with the Landmine, or nil if the Landmine is not visible or is already done.
function Landmine:GetInteractionCombatAction(unit)
	if not self.visible or self.done then return end
	return Presets.CombatAction.Interactions.Interact_Disarm
end

---
--- Returns the position(s) where a unit can interact with the Landmine.
---
--- This function calculates the position(s) where a unit can interact with the Landmine. It first snaps the Landmine's position to the nearest voxel, then checks the surrounding voxels to find positions that the unit can occupy. If the unit and the Landmine are on the same pass slab, the function returns the unit's pass slab with the "ignore_occupied" flag set to true. Otherwise, it returns a table of valid interaction positions.
---
--- @param self Landmine The Landmine object.
--- @param unit table The unit attempting to interact with the Landmine.
--- @return table|nil The position(s) where the unit can interact with the Landmine, or nil if no valid positions are found.
function Landmine:GetInteractionPos(unit)
	local voxel_x, voxel_y, voxel_z = SnapToVoxel(self:GetPosXYZ())
	local step = voxelSizeX
	local positions
	
	local unitPassSlab = unit and GetPassSlab(unit)
	if GetPassSlab(self) == unitPassSlab then
		return { unitPassSlab, ["ignore_occupied"] = true }
	end

	for dy = -1, 1 do
		for dx = -1, 1 do
			local x = voxel_x + step * dx
			local y = voxel_y + step * dy
			local pos = GetPassSlab(voxel_x + step * dx, voxel_y + step * dy, voxel_z)
			if pos and CanOccupy(unit, pos) then
				if dx ~= 0 or dy ~= 0 or GetPassSlab(unit) == pos then
					positions = positions or {}
					table.insert(positions, pos)
				end
			end
		end
	end
	return positions
end

---
--- Saves the dynamic data of the Landmine object.
---
--- This function saves the dynamic data of the Landmine object, including the number of turns the Landmine has been set to explode (TimedExplosiveTurns) and whether the Landmine has been discovered by any players (discovered_by).
---
--- @param self Landmine The Landmine object.
--- @param data table The table to store the dynamic data in.
function Landmine:GetDynamicData(data)
	data.TimedExplosiveTurns = self.TimedExplosiveTurns
	if next(self.discovered_by or empty_table) then
		data.discovered_by = self.discovered_by
	end
end

---
--- Sets the dynamic data of the Landmine object.
---
--- This function sets the dynamic data of the Landmine object, including whether the Landmine has been discovered by any players (discovered_by) and the number of turns the Landmine has been set to explode (TimedExplosiveTurns).
---
--- @param self Landmine The Landmine object.
--- @param data table The table containing the dynamic data to set.
function Landmine:SetDynamicData(data)
	if data.discovered_by then
		self.discovered_by = data.discovered_by

		if self.discovered_by["player1"] then
			self.discovered_trap = true
		end
	end
	self.TimedExplosiveTurns = data.TimedExplosiveTurns
end

---
--- Sets the visibility of the Landmine object.
---
--- This function sets the visibility of the Landmine object. If the Landmine is done and not a dud, it will clear the visible flag. Otherwise, it will set the visible flag and set the opacity to 100 or 0 depending on the `visible` parameter. It also updates the trigger radius FX.
---
--- @param self Landmine The Landmine object.
--- @param visible boolean Whether the Landmine should be visible or not.
function Landmine:SetVisible(visible)
	self.visible = visible
	if self.done and not self.dud then
		self:ClearEnumFlags(const.efVisible)
	else
		self:SetEnumFlags(const.efVisible)
		self:SetOpacity(visible and 100 or 0)
	end
	self:UpdateTriggerRadiusFx()
end

---
--- Determines if the Landmine object can be attacked.
---
--- This function returns true, indicating that the Landmine object can be attacked.
---
--- @return boolean true
function Landmine:CanBeAttacked()
	return true
end

---
--- Sets the visibility of the Landmine object when entering the editor.
---
--- This function sets the Landmine object to be visible and sets its opacity to 100 when entering the editor.
---
--- @param self Landmine The Landmine object.
function Landmine:EditorEnter()
	self:SetEnumFlags(const.efVisible)
	self:SetOpacity(100)
end

---
--- Sets the visibility of the Landmine object when exiting the editor.
---
--- This function sets the visibility of the Landmine object to the value of the `visible` property when exiting the editor.
---
--- @param self Landmine The Landmine object.
function Landmine:EditorExit()
	self:SetVisible(self.visible)
end

---
--- Sets the trigger radius of the Landmine object.
---
--- This function sets the trigger radius of the Landmine object. The trigger radius is the number of voxels away from the trap that it should trigger from. The function also updates the trigger radius FX.
---
--- @param self Landmine The Landmine object.
--- @param value number The new trigger radius value.
function Landmine:SettriggerRadius(value)
	self.triggerRadius = value
	self:UpdateTriggerRadiusFx()
	assert(value <= MaxTrapTriggerRadius)
end

---
--- Gets the trigger distance of the Landmine object.
---
--- The triggerRadius property is the number of voxels away from the trap that it should trigger from.
--- Since the trap is at the center of a voxel itself, we need to add half a voxel to that, and due to
--- the property being one-indexed, including the trap's voxel, we subtract one.
---
--- @param self Landmine The Landmine object.
--- @return number The trigger distance of the Landmine object.
function Landmine:GetTriggerDistance()
	-- The triggerRadius property is the number of voxels away from the trap that it should trigger from.
	-- Since the trap is at the center of a voxel itself, we need to add half a voxel to that, and due to
	-- the property being one-indexed, including the trap's voxel, we subtract one.
	return (self.triggerRadius - 1) * voxelSizeX + voxelSizeX / 2
end

---
--- Updates the timed explosives in the game.
---
--- This function iterates through the list of traps (`g_Traps`) and updates the timed explosion FX for any traps that have a `TriggerType` of "Timed". Optionally, it can filter the traps by their `team_side` property.
---
--- @param timePassed number (optional) The amount of time passed since the last update, in seconds.
--- @param sideFilter string (optional) The team side to filter the traps by.
function UpdateTimedExplosives(timePassed, sideFilter)
	if not g_Traps then return end
	
	for i, obj in ipairs(g_Traps) do
		if rawget(obj, "TriggerType") == "Timed" and (not sideFilter or sideFilter == obj.team_side) then
			obj:UpdateTimedExplosionFx(timePassed)
		end
	end
end

function OnMsg.CombatStart()
	UpdateTimedExplosives()
end

function OnMsg.CombatEnd()
	UpdateTimedExplosives()
end

function OnMsg.ExplorationTick(timePassed)
	if g_Combat then return end
	UpdateTimedExplosives(timePassed)
end

---
--- Removes all dynamic landmines from the game.
---
--- This function iterates through the list of traps (`g_Traps`) and removes any objects that are of type "DynamicSpawnLandmine". It also removes the objects from the `g_Traps` table.
---
function RemoveAllDynamicLandmines()
	MapForEach("map", "DynamicSpawnLandmine", function(o)
		DoneObject(o)
		table.remove_value(g_Traps, o)
	end)
end

ExplosiveTrapQueryThread = false

function OnMsg.EnterSatelliteViewBlockerQuery(query)
	if g_Combat then return false end

	local foundPotentialExplosion = false
	for i, obj in ipairs(g_Traps) do
		if rawget(obj, "TriggerType") == "Timed" and not obj.done then
			foundPotentialExplosion = true
			break
		end
	end
	
	if not foundPotentialExplosion then return false end
	query[#query + 1] = "timed_explosives"
	
	if IsValidThread(ExplosiveTrapQueryThread) then
		return
	end
	
	ExplosiveTrapQueryThread = CreateMapRealTimeThread(function()
		local modeDlg = GetInGameInterfaceModeDlg()
		local choiceUI = CreateQuestionBox(modeDlg,
			T(725118714344, "Timed Explosions"),
			T(124470289668, "There are timed explosives nearby, entering Sat View will instantly detonate them. Are you sure?"),
			T(413525748743, "Ok"),
			T(6879, "Cancel"),
			"sat-blocker"
		)
		
		local pauseLayer = XTemplateSpawn("XPauseLayer", choiceUI)
		pauseLayer:Open()

		local prompt = choiceUI:Wait()
		if prompt == "ok" then
			NetSyncEvent("TriggerTimedTrapsSatelliteViewEnter")
		end
	end)
end

---
--- This function is called when the player enters the satellite view while there are timed explosives nearby. It triggers all the timed traps in the `g_Traps` table, causing them to explode. It then runs the `SatelliteToggleActionRun()` function to toggle the satellite view.
---
--- The function creates a new game time thread that loops through the `g_Traps` table and triggers any timed traps that have not yet exploded. It does this in a loop to ensure that any explosions triggered by the initial traps also cause their associated traps to explode. After all timed traps have been triggered, the function calls `SatelliteToggleActionRun()` to toggle the satellite view.
---
--- @function NetSyncEvents.TriggerTimedTrapsSatelliteViewEnter
--- @return nil
function NetSyncEvents.TriggerTimedTrapsSatelliteViewEnter()
	ExplosiveTrapQueryThread = CreateGameTimeThread(function()
		-- We need to loop explode them since explosions can trigger
		-- other timed explosions (cars etc)
		local anyExploded = true
		while anyExploded do
			anyExploded = false
			for i, obj in ipairs(g_Traps) do
				if rawget(obj, "TriggerType") == "Timed" and not obj.done then
					obj:TriggerTrap()
					anyExploded = true
				end
			end
			Sleep(200)
		end
		
		SatelliteToggleActionRun()
	end)
end

---
--- This function is called repeatedly at a 1 second interval to play a ticking sound effect for any visible timed or proximity traps that have not yet been triggered.
---
--- It loops through the `g_Traps` table and checks each trap to see if it has the `TriggerType` of "Timed" or "Proximity" and has not yet been triggered (`trap.done == false`). If the trap meets these conditions and is visible, it plays the "ExplosiveTick" FX on the trap.
---
--- This function is likely used to provide auditory feedback to the player about the status of any active traps in the game world.
---
--- @function MapGameTimeRepeat
--- @param string name The name of the repeating game time thread
--- @param integer interval The interval in milliseconds at which the function should be called
--- @param function callback The function to be called at each interval
--- @return nil
MapGameTimeRepeat("TrapsTickingSound", 1000, function()
	for _, trap in ipairs(g_Traps) do
		if not trap.done and (trap.TriggerType == "Timed" or trap.TriggerType == "Proximity") and trap.visible then
			PlayFX("ExplosiveTick", "start", trap)
		end
	end
end)

Traps_CombatTurnToTime = 5000
---
--- Updates the visual effect for a timed explosive trap, including displaying a countdown timer.
---
--- If the trap has already been triggered (`self.done`) or is not a timed trap (`self.TriggerType ~= "Timed"`), the function will remove any existing countdown timer visual effect.
---
--- If the trap is a valid timed trap, the function will create a countdown timer visual effect if one does not already exist. It will then update the timer text to display the remaining time until the trap explodes.
---
--- If the remaining time is 0 or less than 1 second in combat mode, the function will mark the trap as ready to explode (`self.toExplode = true`).
---
--- @function Landmine:UpdateTimedExplosionFx
--- @param integer|string addTime The amount of time in milliseconds to add to the countdown timer, or the string "delete" to remove the timer
--- @return nil
function Landmine:UpdateTimedExplosionFx(addTime)
	if not self.sector_init_called then return end
	if self.done or self.TriggerType ~= "Timed" or addTime == "delete" then
		if self.timer_text then
			self.timer_text:delete()
			self.timer_text = false
		end
		return
	end

	if not self.timer_text and not self.spawned_by_explosive_object then
		self.timer_text = CreateBadgeFromPreset("TrapTimerBadge", { target = self, spot = "Origin"})
		self.timer_text.ui.idText:SetVisible(true)
	end
	self.timer_passed = self.timer_passed or 0

	if addTime then
		self.timer_passed = self.timer_passed + addTime
	end

	local timePassed = self.timer_passed
	local timeToExplosion = self.TimedExplosiveTurns * Traps_CombatTurnToTime
	timeToExplosion = timeToExplosion - timePassed

	local bombIcon = T(173303509811, "<image UI/Hud/bomb> ")
	if g_Combat and self.timer_text then
		local turns = DivCeil(timeToExplosion, Traps_CombatTurnToTime)
		self.timer_text.ui.idText:SetText(bombIcon .. T{116423252311, "<turns> turn(s)", turns = turns})
		if turns == 1 then
			local text = self.timer_text.ui.idText.Text
			self.timer_text.ui.idText:SetText(T{465158248448, "<red><text></red>", text = text})
		end
	elseif self.timer_text then
		self.timer_text.ui.idText:SetText(bombIcon .. T{918858375439, "<secondsToExplore>", secondsToExplore = timeToExplosion / 1000})
	end
	
	if timeToExplosion <= 0 or (g_Combat and timeToExplosion < 1000) then
		if g_Combat then
			self.toExplode = true
		else
			self:TriggerTrap()
		end
	end
end

---
--- Triggers all timed explosives that are ready to explode.
--- Locks the camera movement, adjusts the combat camera, and triggers the trap.
--- After triggering the trap, the camera is unlocked.
---
--- @function TriggerTimedExplosives
--- @return nil
function TriggerTimedExplosives()
	for _, trap in ipairs(g_Traps) do
		if trap.toExplode and not trap.done then
			LockCameraMovement("TimedExplosives")
			AdjustCombatCamera("set")
			local cameraClose = DoPointsFitScreen({trap:GetVisualPos()}, nil, const.Camera.BufferSizeNoCameraMov)
			if not cameraClose then
				SnapCameraToObj(trap:GetVisualPos(), "force",  GetStepFloor(trap))
				Sleep(1000)
			end
			trap:TriggerTrap(nil, trap.attacker)
			Sleep(1000)
		end
	end
	UnlockCameraMovement("TimedExplosives")
end

---
--- Updates the visual effect for the trigger radius of the landmine.
---
--- @param delete boolean Whether to delete the existing trigger radius effect.
--- @return boolean True if the trigger radius effect was updated, false otherwise.
function Landmine:UpdateTriggerRadiusFx(delete)
	local range = (self.triggerRadius or 0) * voxelSizeX / 2
	if self.done or not self.visible or range == 0 or (self.TriggerType ~= "Proximity" and self.TriggerType ~= "Proximity-Timed") or delete or not self:IsValidPos() then
		if self.trigger_radius_fx then
			DoneObject(self.trigger_radius_fx)
			self.trigger_radius_fx = false
		end
		return
	end
	
	local origin = self:GetPos()
	local step_positions, step_objs, los_values = GetAOETiles(origin, "Standing", range)
	self.trigger_radius_fx = CreateAOETilesCylinder(step_positions, step_objs, self.trigger_radius_fx, origin, range, los_values)
	self.trigger_radius_fx:SetColorFromTextStyle("MineRange")
	return true
end

---
--- Determines whether a hit will damage the landmine.
---
--- @param hit table The hit information.
--- @return boolean True if the hit will damage the landmine, false otherwise.
function Landmine:HitWillDamage(hit)
	if hit and (hit.stray or hit.explosion or (hit.aoe and not hit.obj_is_target)) then return false end
	return true
end

---
--- Triggers the landmine trap when it takes damage.
---
--- @param dmg number The amount of damage the landmine takes.
--- @param attacker table The entity that is attacking the landmine.
--- @param description table The details of the hit that caused damage.
---
function Landmine:TakeDamage(dmg, attacker, description)
	if self.done then return end
	if not self:HitWillDamage(description) then return end
	self:TriggerTrap(attacker, attacker)
end

---
--- Determines whether the landmine is dead.
---
--- @param ... any Additional arguments passed to the base class's IsDead method.
--- @return boolean True if the landmine is dead, false otherwise.
function Landmine:IsDead(...)
	return Trap.IsDead(self, ...)
end

---
--- Triggers the landmine trap when certain conditions are met.
---
--- @param victim table The entity that triggered the trap.
--- @param attacker table The entity that is attacking the landmine.
---
function Landmine:TriggerTrap(victim, attacker)
	if self.done then return end -- We need to check if exploded because overwatch logic (which triggers this) doesnt
	if IsSetpiecePlaying() then return end
	
	if self.TriggerType == "Proximity-Timed" then
		self:SetVisible(true)
		self.TriggerType = "Timed"
		self.triggerRadius = 0
		self:UpdateTimedExplosionFx()
		self:UpdateTriggerRadiusFx("delete")
		return
	end
	
	self:UpdateTriggerRadiusFx("delete")
	self:UpdateTimedExplosionFx("delete")
	if #(self.GrenadeExplosion or "") > 0 then
		self:ExplodeAsGrenade(victim, self.fx_actor_class, nil, attacker)
	else
		self:Explode(victim, self.fx_actor_class, nil, attacker)
	end
	self:SetVisible(false)
end

---
--- Explodes the landmine as a grenade.
---
--- @param victim table The entity that triggered the trap.
--- @param fx_actor string The name of the FX actor to use for the explosion.
--- @param state table Additional state information for the explosion.
--- @param attacker table The entity that is attacking the landmine.
---
function Landmine:ExplodeAsGrenade(victim, fx_actor, state, attacker)
	self.victim = victim
	self.done = true
	ObjModified("combat_bar_traps")
	
	-- Track who exploded the trap and handle chain explosions
	self.attacker = IsKindOf(attacker, "Trap") and attacker.attacker or attacker
	
	local trapName = self:GetTrapDisplayName()
	
	-- Check if dud
	local rand = InteractionRand(100)
	if rand > DifficultyToNumber(self.triggerChance) then
		self.discovered_trap = true
		self.dud = true
		CombatLog("important", T{536546697372, "<TrapName> was a dud.", TrapName = trapName})
		CreateFloatingText(self:GetVisualPos(), T{372675206288, "<TrapName> was <em>a dud</em>", TrapName = trapName}, "BanterFloatingText")
		PlayFX("Explosion", "failed", self)
		return
	end
	
	if IsKindOf(self, "ContainerMarker") and not self:GetItemInSlot("Inventory", "QuestItem") then
		self.enabled = false
		self:UpdateHighlight()
	end
	
	local weapon = PlaceObject(self.GrenadeExplosion)
	if not weapon then return end
	
	local target_pos = self:GetPos()
	
	local fxClass = fx_actor or weapon.class
	local mineSpecificIdx = string.find(fxClass, "_Mine")
	if mineSpecificIdx then
		fxClass = string.sub(fxClass, 1, mineSpecificIdx - 1)
	end
	
	local proj = PlaceObject("FXGrenade")
	proj.fx_actor_class = fxClass
	proj:SetPos(target_pos)
	proj:SetOrientation(self:GetOrientation())
	
	CreateGameTimeThread(function()
		local attackProps = weapon:GetAreaAttackParams(nil, self, target_pos)
		local props = GetAreaAttackResults(attackProps)
		props.trajectory = { { pos = target_pos } }
		props.explosion_pos = target_pos
		weapon:OnLand(self, props, proj)
	end)

	if not self.spawned_by_explosive_object then
		-- Exploded
		CombatLog("important", T{811751960646, "<TrapName> <em>detonated</em>!", TrapName = trapName})
		CreateFloatingText(self:GetVisualPos(), T{463301911995, "<TrapName> <em>explodes</em>!", TrapName = trapName}, "BanterFloatingText")
	end
end

--- Attempts to disarm a landmine trap.
---
--- This function is called when a unit attempts to disarm a landmine trap. It updates the trigger radius and timed explosion FX, then calls the base `Trap:AttemptDisarm()` function to handle the disarm attempt. If the disarm is successful, it also destroys any attached objects to the landmine.
---
--- @param unit table The unit attempting to disarm the landmine.
--- @return boolean True if the disarm attempt was successful, false otherwise.
function Landmine:AttemptDisarm(unit)
	self:UpdateTriggerRadiusFx("delete")
	self:UpdateTimedExplosionFx("delete")
	local success = Trap.AttemptDisarm(self, unit)
	if success then
		self:ForEachAttach(function(attach) 
			attach:DestroyAttaches()
		end)
	end
end

-- Always visible shootable trap that triggers when killed
DefineClass.ExplosiveContainer = {
	__parents = { "Trap", "CombatObject", "GroundAlignedObj", "AnimMomentHook", "Interactable" },
	flags = { cofComponentCollider = true, efPathExecObstacle = false, efResting = false },
	DisplayName = T(558157857737, "Explosive Container"),
	properties = {
		{ category = "Trap", id = "visibility", no_edit = true },
		{ category = "Trap", id = "visibilityRange", no_edit = true },
		{ category = "Trap", id = "revealDifficulty", no_edit = true },
		{ category = "Trap", id = "disarmDifficulty", no_edit = true },
		{ category = "Trap", id = "randomDifficulty", no_edit = true},
		{ category = "Trap", id = "triggerChance", no_edit = true },
		{ category = "Trap", id = "done", no_edit = true },
		{ category = "Trap", id = "triggerRadius", no_edit = true },
	},
	triggerRadius = 0,
	triggerChance = "Always",
	fx_actor = "FragGrenade",
	anim_moments_single_thread = true,
	anim_moments_hook = true,
	AreaObjDamageMod = 500,
	CenterObjDamageMod = 500,
	
	discovered_trap = true
}

--- Checks if the ExplosiveContainer object is dead.
---
--- This function overrides the `CombatObject:IsDead()` function to determine if the ExplosiveContainer object is dead.
---
--- @param ... Any additional arguments passed to the `CombatObject:IsDead()` function.
--- @return boolean True if the ExplosiveContainer object is dead, false otherwise.
function ExplosiveContainer:IsDead(...)
	return CombatObject.IsDead(self, ...)
end

--- Gets the combat action for interacting with the ExplosiveContainer.
---
--- If the ExplosiveContainer is not done, this function returns the default ranged attack action for the given unit. Otherwise, it returns the Interact_Attack combat action preset.
---
--- @param unit table The unit attempting to interact with the ExplosiveContainer.
--- @return table|nil The combat action for interacting with the ExplosiveContainer, or nil if no action is available.
function ExplosiveContainer:GetInteractionCombatAction(unit)
	if self.done then return end
	local action = unit and unit:GetDefaultAttackAction("ranged")
	if not action then return end
	return Presets.CombatAction.Interactions.Interact_Attack
end

--- Gets the interaction position for the ExplosiveContainer.
---
--- This function returns the position of the given unit, which is used as the interaction position for the ExplosiveContainer.
---
--- @param unit table The unit attempting to interact with the ExplosiveContainer.
--- @return table The interaction position for the ExplosiveContainer.
function ExplosiveContainer:GetInteractionPos(unit)
	return unit and unit:GetPos()
end

local lBarrelStateRandom = {
	{ 2, "explode" }, -- Leaves cover, animated
	{ 5, "destroyed" }, -- Leaves obstacle
	{ 3, "disappear" },
}

--- Handles the death of an ExplosiveContainer object.
---
--- This function is called when the ExplosiveContainer object dies. It determines the state of the object based on its position and a random seed, and then explodes the object accordingly.
---
--- @param attacker table The unit that attacked the ExplosiveContainer object.
function ExplosiveContainer:OnDie(attacker)
	if self.done then return end
	
	local p = self:GetPos()
	local z = p:z()
	local isOnGround = not z or z == const.InvalidZ
	if not isOnGround then
		local s = GetFloorSlab(self:GetGridCoords())
		if s and s:IsInvulnerable() then
			isOnGround = true --on invulnerable floor
		end
	end
	local randomSeed = IsKindOf(attacker, "Unit") and attacker:Random() or p:x() + p:y()
	local state = isOnGround and GetWeightedRandom(lBarrelStateRandom, randomSeed) or "disappear"
	self:Explode(false, state == "explode" and self.fx_actor or "Explosive_Barrel", state, attacker)
	if state == "disappear" then
		self:ClearEnumFlags(const.efVisible+const.efCollision)
	end
end

--- Sets the dynamic data for the ExplosiveContainer.
---
--- This function is called to set the dynamic data for the ExplosiveContainer object. If the ExplosiveContainer is already marked as "done", it will clear the visibility and collision flags.
---
--- @param data table The dynamic data to set for the ExplosiveContainer.
function ExplosiveContainer:SetDynamicData(data)
	if self.done then
		self:ClearEnumFlags(const.efVisible+const.efCollision)
	end
end

--- Determines if the ExplosiveContainer can be attacked.
---
--- This function returns true, indicating that the ExplosiveContainer can be attacked.
---
--- @return boolean True, indicating the ExplosiveContainer can be attacked.
function ExplosiveContainer:CanBeAttacked()
	return true
end

DefineClass.ExplosiveContainerFuelBunker = {
	__parents = { "ExplosiveContainer" },
	DisplayName = T(503486228435, "Fuel Bunker"),
	fx_actor = "FuelBunker",

	BaseDamage = 60,
	AreaOfEffect = 5,
	Noise = 40
}

DefineClass.ExplosiveContainerBarrel = {
	__parents = { "ExplosiveContainer" },
	DisplayName = T(332342380396, "Explosive Barrel"),
	fx_actor = "ExplosiveBarrel",
	
	BaseDamage = 40,
	AreaOfEffect = 3,
	Noise = 40
}

DefineClass.ExplosiveContainerGasBottle = {
	__parents = { "ExplosiveContainer" },
	DisplayName = T(237967294998, "Gas Bottle"),
	fx_actor = "GasBottle",
	
	BaseDamage = 20,
	AreaOfEffect = 3,
	Noise = 10
}

TrapUIGroupings = {
	{ GetList = function(unit) return unit and GetVisibleTraps(unit, "Landmine", true) end, icon = "UI/Hud/mine_target" },
	{ GetList = function(unit) return unit and GetVisibleTraps(unit, "DynamicSpawnLandmine", true) end, icon = "UI/Hud/mine_target" },
	{ GetList = function(unit) return unit and GetVisibleTraps(unit, "ExplosiveContainer") end, icon = "UI/Hud/barrel_target" },
}

DefineClass.CustomTrapShip = {
	__parents = { "Landmine" },
	DisplayName = T(983980637653, "Boom Trap"),
	entity = "City_CinemaProjector",
	discovered_trap = true,
	visible = true
}

DefineClass.CustomKettleTrap = {
	__parents = { "Landmine" },
	DisplayName = T(983980637653, "Boom Trap"),
	TriggerType = "Proximity-Timed",
	entity = "Shanty_Kettle_01",
	discovered_trap = true,
	visible = true,
	triggerRadius = 3
}

--- Callback function that is called when the CustomKettleTrap is placed in the editor.
--- This function is used to perform any necessary setup or initialization when the trap is placed.
function CustomKettleTrap:EditorCallbackPlace()

end

--- Callback function that is called when the CustomKettleTrap is moved in the editor.
--- This function is used to perform any necessary setup or initialization when the trap is moved.
function CustomKettleTrap:EditorCallbackMove()

end

-- Trap which triggers on interaction.

---
--- Triggers an electrical trap, dealing damage to the victim.
---
--- If no victim is provided, the function will find the nearest valid unit within a 2-voxel radius of the trap.
--- If the trap has a trigger chance, there is a chance the trap will be a dud and not deal any damage.
--- If the trap is not a dud, it will deal the trap's base damage to the victim and play an electrical trap trigger effect.
---
--- @param self table The trap object
--- @param victim table|nil The victim unit to trigger the trap on
function ElectricalTrap(self, victim)
	if not victim then
		victim = MapGetFirst(self:GetPos(), voxelSizeX * 2, "Unit", function(o) return not o:IsDead() end)
		if not victim then
			return
		end
	end

	victim = IsKindOf(victim, "CombatObject") and victim or victim[1]
	self.done = true
	self.victim = victim
	ObjModified("combat_bar_traps")
	
	local trapName = self:GetTrapDisplayName()

	local rand = InteractionRand(100)
	if rand > DifficultyToNumber(self.triggerChance) then
		self.dud = true
		CombatLog("important", T{116666792112, "<TrapName> was a dud", TrapName = trapName})
		CreateFloatingText(self:GetVisualPos(), T{372675206288, "<TrapName> was <em>a dud</em>", TrapName = trapName}, "BanterFloatingText")
		return
	end

	CombatLog("important", T{863806952729, "Zapped by <TrapName> for <em><damage> damage</em>", TrapName = trapName, damage=self.BaseDamage})
	CreateFloatingText(self:GetVisualPos(), T{960360356009, "Zapped by <TrapName>", TrapName = trapName}, "BanterFloatingText")
	local damage = self.BaseDamage
	victim:TakeDamage(damage, self, { })
	PlayFX("ElectricalTrapTrigger", "start", self, victim)
end

---
--- Triggers an alarm trap, logging an important combat log message and creating a floating text effect.
--- The trap also pushes a unit alert for "noise" with the trap's noise level.
---
--- @param self table The trap object
--- @param victim table|nil The victim unit that triggered the trap
function AlarmTrap(self, victim)
	self.done = true
	self.victim = victim
	ObjModified("combat_bar_traps")
	
	local trapName = self:GetTrapDisplayName()
	
	CombatLog("important", T{708668155307, "<TrapName> triggered an alarm.", TrapName = trapName})
	CreateFloatingText(self:GetVisualPos(), T{708668155307, "<TrapName> triggered an alarm.", TrapName = trapName}, "BanterFloatingText")
	PushUnitAlert("noise", self, self.Noise, Presets.NoiseTypes.Default.Trap.display_name)
	PlayFX("AlarmTrapTrigger", "start", self)
end

const.BoobyTrapNone = 1
const.BoobyTrapExplosive = 2
const.BoobyTrapElectric = 3
const.BoobyTrapAlarm = 4

local lBoobyTrapTypes = {
	{ text = "None", id = const.BoobyTrapNone },
	{ text = "Explosive", id = const.BoobyTrapExplosive, func = Trap.Explode },
	{ text = "Electrical", id = const.BoobyTrapElectric, func = ElectricalTrap },
	{ text = "Alarm", id = const.BoobyTrapAlarm, func = AlarmTrap },
}

local lBoobyTrapNone = const.BoobyTrapNone
local lBoobyTrapVisibilityRange = 10
BoobyTrapTypeNone = lBoobyTrapNone

MapVar("g_Traps", false)
MapVar("g_AttackableVisibility", {})

local function lTrapVisibilityUpdate(unit)
	if not g_Traps then
		g_Traps = MapGet("map", "Trap") or false
	end

	-- Gather mines around the unit sight radius and inside the interactable's visibility range.
	local unitSightRange = unit:GetSightRadius()
	local discoveredAround, hiddenAround

	for i, t in ipairs(g_Traps) do
		if not IsValid(t) then
			goto continue
		end
		local is_landmine = IsKindOf(t, "Landmine")
		local discovered = t.discovered_trap

		if not discovered and is_landmine and t:SeenBy(unit) then
			discovered = true
			t.discovered_trap = true
		end
		if not discovered and t.done then
			discovered = true
			t.discovered_trap = true
		end

		if discovered and is_landmine and not t.visible then
			t:SetVisible(true)
		end

		if not t:RunDiscoverability() then
			goto continue
		end

		if t.discovered_trap then
			local range = unit:GetSightRadius(t)
			if IsCloser(unit, t, range) then
				if not discoveredAround then discoveredAround = {} end
				discoveredAround[#discoveredAround + 1] = t
			end
		else
			local range = (t.visibilityRange - 1) * voxelSizeX + voxelSizeX / 2
			if IsCloser(unit, t, range) then
				if not hiddenAround then hiddenAround = {} end
				hiddenAround[#hiddenAround + 1] = t
			end
		end

		::continue::
	end

	-- Stuff like booby traps would prefer LOS checks to their visual objs rather than
	-- the invisible marker itself.
	if hiddenAround then
		local trapsLosCheck = {}
		for i, t in ipairs(hiddenAround) do
			trapsLosCheck[i] = t.los_check_obj or t
		end
		local los_any, losData = CheckLOS(trapsLosCheck, unit, unitSightRange)
		if los_any then
			for i, t in ipairs(hiddenAround) do
				if losData[i] then
					t:CheckDiscovered(unit)
					if t.discovered_trap then
						if not discoveredAround then discoveredAround = {} end
						discoveredAround[#discoveredAround + 1] = t
					end
				end
			end
		end
	end

	-- Perform LOS check and record attackable traps which are currently visible.
	local attackableVisibleFill
	for i, t in ipairs(discoveredAround) do
		if not t.visible and IsKindOf(t, "Landmine") then
			t:SetVisible(true)
		end
		if t:CanBeAttacked() then
			if not attackableVisibleFill then attackableVisibleFill = {} end
			attackableVisibleFill[#attackableVisibleFill + 1] = t
			attackableVisibleFill[t] = true
		end
	end

	local prevVisible = g_AttackableVisibility[unit]
	g_AttackableVisibility[unit] = attackableVisibleFill

	prevVisible = prevVisible or empty_table
	local nowVisible = attackableVisibleFill or empty_table
	if Selection and Selection[1] == unit and not table.iequal(prevVisible, nowVisible) then
		ObjModified("combat_bar_traps")
	end
end

local function lUpdateTrapVisibility()
	local units = GetAllPlayerUnitsOnMap()
	local vis = g_AttackableVisibility
	for i, u in ipairs(units) do
		lTrapVisibilityUpdate(u)
		-- also build team visibility
		local tvis = vis[u.team]
		if not tvis then
			tvis = {}
			vis[u.team] = tvis
		end
		for _, obj in ipairs(vis[u]) do
			if not tvis[obj] then
				tvis[#tvis + 1] = obj
				tvis[obj] = true
			end
		end
	end
end

function OnMsg.CombatApplyVisibility()
	if g_Combat and not g_Combat.combat_started then return end -- Everyone repositions while combat is starting.
	lUpdateTrapVisibility()
end

OnMsg.ExplorationTick = lUpdateTrapVisibility

DefineClass.BoobyTrappable = {
	__parents = { "Trap", "Interactable", "EditorTextObject" },
	properties = {
		{ id = "visibility", no_edit = true },
		{ id = "visibilityRange", no_edit = true },
		{ id = "done", no_edit = true },
		{ id = "triggerRadius", no_edit = true },
		{ category = "Trap", id = "boobyTrapType", name = "Booby Trap Type", editor = "combo", items = lBoobyTrapTypes, default = lBoobyTrapNone, help = "The kind of trap to activate." },
	},
	triggerRadius = 0,
	visibilityRange = lBoobyTrapVisibilityRange,
	Noise = 30,
	discovered_trap = false,
	editor_text_class = "TextEditor",
	editor_text_color = const.clrBlue,
}

local lDiscoveredTrapHighlight = 2

---
--- Sets the booby trap type for this object.
---
--- If the trap type is set to "Explosive" and the object has any invulnerable combat objects, an error is stored.
---
--- @param value string The new booby trap type to set.
---
function BoobyTrappable:SetboobyTrapType(value)
	self.boobyTrapType = value
	if lBoobyTrapTypes[value].text == "Explosive" and rawget(self, "objects") then
		local objects = self.objects
		for i, o in ipairs(objects) do
			if IsKindOf(o, "CombatObject") and o:IsInvulnerable() then
				StoreErrorSource(self, "Invulnerable object in exploding booby trap")
			end
		end
	end
end

---
--- Returns the appropriate trap stat for the current booby trap type.
---
--- If the trap type is "Alarm" or "Electrical", the trap stat is "Mechanical".
--- Otherwise, the trap stat is "Explosives".
---
--- @return string The trap stat for the current booby trap type.
---
function BoobyTrappable:GetTrapStat()
	-- todo: maybe move the stat as a property in lBoobyTrapTypes
	local trapType = self.boobyTrapType
	local trapTypeName = lBoobyTrapTypes[trapType].text
	if trapTypeName == "Alarm" or trapTypeName == "Electrical" then
		return "Mechanical"
	end

	return "Explosives"
end

---
--- Returns the appropriate action name for disarming the booby trap.
---
--- If the trap type is "Alarm" or "Electrical", the action name is "Disable <target.GetTrapDisplayName>".
--- Otherwise, the action name is the display name for the "Interact_Disarm" combat action.
---
--- @return string The action name for disarming the booby trap.
---
function BoobyTrappable:GetDisarmActionName()
	-- todo: maybe move the stat as a property in lBoobyTrapTypes
	local trapType = self.boobyTrapType
	local trapTypeName = lBoobyTrapTypes[trapType].text
	if trapTypeName == "Alarm" or trapTypeName == "Electrical" then
		return T(461461205145, "Disable <target.GetTrapDisplayName>")
	end

	return CombatActions.Interact_Disarm.DisplayName
end

---
--- Returns the appropriate combat log message for disarming the booby trap.
---
--- If the trap type is "Alarm" or "Electrical", the message is "Disabled <TrapName> by <Nick> (<stat>)".
--- Otherwise, the message is the default disarm combat log message.
---
--- @return string The combat log message for disarming the booby trap.
---
function BoobyTrappable:GetDisarmCombatLogMessage()
	-- todo: maybe move the stat as a property in lBoobyTrapTypes
	local trapType = self.boobyTrapType
	local trapTypeName = lBoobyTrapTypes[trapType].text
	if trapTypeName == "Alarm" or trapTypeName == "Electrical" then
		return T(841192968999, "<TrapName> <em>disabled</em> by <Nick> <em>(<stat>)</em>")
	end

	return Trap.GetDisarmCombatLogMessage(self)
end

---
--- Attempts to disarm the booby trap.
---
--- @param unit Unit The unit attempting to disarm the trap.
--- @return boolean True if the disarm attempt was successful, false otherwise.
---
function BoobyTrappable:AttemptDisarm(unit)
	local disarmStat = self:GetTrapStat()
	local success = Trap.AttemptDisarm(self, unit, disarmStat)
	self:UpdateHighlight()
	return success
end

---
--- Returns the appropriate combat action and icon for disarming the booby trap.
---
--- If the trap type is not "None", the trap has been discovered, and the unit is not null, this function returns the "Interact_Disarm" combat action and an appropriate icon based on the trap type.
---
--- @param unit Unit The unit attempting to disarm the trap.
--- @return CombatAction, string The combat action and icon for disarming the trap, or false if the trap cannot be disarmed.
---
function BoobyTrappable:GetInteractionCombatAction(unit)
	if self.done or not unit then return false end
	if self.boobyTrapType == lBoobyTrapNone then return false end
	if not self.discovered_trap then
		return false
	end
	
	local stat = self:GetTrapStat()
	local icon
	if stat == "Mechanical" then
		icon = "UI/Hud/iw_mechanical_trap"
	else
		icon = "UI/Hud/iw_disarm"
	end

	return Presets.CombatAction.Interactions.Interact_Disarm, icon
end

---
--- Returns the appropriate highlight color for the booby trap.
---
--- If the trap has been discovered and is not done, the highlight color is set to `lDiscoveredTrapHighlight`. Otherwise, the highlight color is determined by the `Interactable.GetHighlightColor()` function.
---
--- @return string The highlight color for the booby trap.
---
function BoobyTrappable:GetHighlightColor()
	if self.discovered_trap and not self.done and not IsObjectDestroyed(self) then
		return lDiscoveredTrapHighlight
	end
	return Interactable.GetHighlightColor(self)
end

---
--- Highlights the BoobyTrappable object intensely, and sets the highlight color to lDiscoveredTrapHighlight if the object has been discovered and is not done.
---
--- @param visible boolean Whether to make the highlight visible or not.
--- @param reason string The reason for the highlight.
---
function BoobyTrappable:HighlightIntensely(visible, reason)
	Interactable.HighlightIntensely(self, visible, reason)
	if not visible and self:GetHighlightColor() == lDiscoveredTrapHighlight then
		SetInteractionHighlightRecursive(self, true, true, self.highlight_collection, lDiscoveredTrapHighlight)
	end
end

---
--- Highlights the BoobyTrappable object if it has been discovered, or calls the base Interactable.UnitNearbyHighlight function if it has not been discovered.
---
--- @param time number The duration of the highlight in seconds.
--- @param cooldown number The cooldown period between highlights in seconds.
--- @param force boolean Whether to force the highlight to be shown.
--- @return boolean Whether the highlight was successfully applied.
---
function BoobyTrappable:UnitNearbyHighlight(time, cooldown, force)
	if self.discovered_trap then
		self:UpdateHighlight()
		return
	end
	
	return Interactable.UnitNearbyHighlight(self, time, cooldown, force)
end

---
--- Updates the highlight of the BoobyTrappable object.
---
--- This function removes any existing interactable highlights, recalculates the highlight intensity, and updates the interactable badge if it exists.
---
--- @param self BoobyTrappable The BoobyTrappable object to update the highlight for.
---
function BoobyTrappable:UpdateHighlight()
	-- Remove old interactable highlights
	for i = 1, 4 do
		SetInteractionHighlightRecursive(self, false, true, self.highlight_collection, i, "passed-color")
	end
	-- Will cause trap hightlight to recalculate
	self:HighlightIntensely(false, "discovered_trap")
	
	local badgeInstance = self.interactable_badge
	if badgeInstance and badgeInstance.ui.window_state ~= "destroying" then
		self:UpdateInteractableBadge(true, self:GetInteractionVisuals())
	end
end

---
--- Checks if the BoobyTrappable object has been discovered by the given unit.
---
--- If the boobyTrapType is lBoobyTrapNone, the function returns immediately.
--- If the revealDifficulty is set to -1, the function returns immediately.
--- Otherwise, the function checks the unit's boobyTrapStat against the revealDifficulty.
--- If the unit's stat is greater than the revealDifficulty, the function sets the discovered_trap flag to true, sends a "TrapDiscovered" message, updates the highlight, and interrupts the unit's command if it was "InteractWith" and the unit is interruptable.
---
--- @param unit Unit The unit that is checking the trap.
---
function BoobyTrappable:CheckDiscovered(unit)
	if self.boobyTrapType == lBoobyTrapNone then return end
	if DifficultyToNumber(self.revealDifficulty) == -1 then
		return
	end

	local boobyTrapStat = self:GetTrapStat()
	local mercStat = unit[boobyTrapStat]
	if mercStat <= DifficultyToNumber(self.revealDifficulty) then
		return
	end

	self.discovered_trap = true
	Msg("TrapDiscovered", self, unit)
	self:UpdateHighlight()
	
	if unit.command == "InteractWith" and unit:IsInterruptable() then
		unit:InterruptCommand("Idle")
	end
end

---
--- Triggers the trap associated with the BoobyTrappable object.
---
--- If the trap has already been triggered or a setpiece is playing, the function returns false.
--- If the trap type is lBoobyTrapNone, the function returns false.
--- If the victim is an NPC, the function returns false.
--- Otherwise, the function creates a new game thread that calls the trap's trigger function and updates the trap's highlight.
---
--- @param self BoobyTrappable The BoobyTrappable object.
--- @param victim Unit The unit that triggered the trap.
--- @return boolean True if the trap was triggered, false otherwise.
---
function BoobyTrappable:TriggerTrap(victim)
	if self.done or IsSetpiecePlaying() then return false end
	local trapType = self.boobyTrapType
	if trapType == lBoobyTrapNone then return false end
	if victim:IsNPC() then return end
	CreateGameTimeThread(function(self, victim, trapType)
		lBoobyTrapTypes[trapType].func(self, victim)
		self:UpdateHighlight()
	end, self, victim, trapType)
	return true
end

---
--- Checks if the BoobyTrappable object is discoverable.
---
--- @return boolean True if the BoobyTrappable object is discoverable, false otherwise.
---
function BoobyTrappable:RunDiscoverability()
	if IsObjectDestroyed(self) then return false end
	return self.boobyTrapType ~= lBoobyTrapNone and not self.discovered_trap
end

---
--- Returns a string representation of the trap type for the BoobyTrappable object.
---
--- If the trap type is lBoobyTrapNone, an empty string is returned.
--- Otherwise, the function finds the trap type in the lBoobyTrapTypes table and returns the corresponding text.
---
--- @return string A string representation of the trap type.
---
function BoobyTrappable:EditorGetText()
	if self.boobyTrapType == lBoobyTrapNone then return end
	
	local trap = table.find_value(lBoobyTrapTypes, "id", self.boobyTrapType)
	
	return string.format("Trapped(%s)", trap.text)
end

function OnMsg.TrapDiscovered(trap, unit)
	if trap.team_side == "player1" or trap.team_side == "player2" then return end
	local isBarrel = IsKindOf(trap, "Explosive_Barrel") 
	local isTimed = trap.TriggerType == "Timed"
	local isBoobyTrap = IsKindOf(trap, "BoobyTrappable")
	if isBarrel or isTimed or isBoobyTrap then return end
	PlayVoiceResponse(unit, "MineFound")
	
	local text = T(724647939669, "Trap Detected")
	if IsKindOf(trap, "Landmine") then
		text = T(382962292537, "Landmine detected")
	end
	ShowBanterFloatingText(trap, text, false, true)
end

DefineClass.DynamicSpawnLandmine = {
	__parents = { "Landmine", "GameDynamicSpawnObject", "Shapeshifter", "SyncObject", "SpawnFXObject" },
	discovered = true,
	discovered_trap = true,
	entity = false,
	spawned_by_explosive_object = false,
}

---
--- Initializes the DynamicSpawnLandmine object.
---
--- If the object is dead, it is set to be invisible. Otherwise, its collision is enabled.
---
function DynamicSpawnLandmine:GameInit()
	if self:IsDead() then
		self:SetVisible(false)
	else
		self:SetCollision(true)
	end
end

---
--- Saves the dynamic data of the DynamicSpawnLandmine object to the provided data table.
---
--- @param data table The table to save the dynamic data to.
---
function DynamicSpawnLandmine:GetDynamicData(data)
	data.additionalDifficulty = self.additionalDifficulty
	data.AreaObjDamageMod = self.AreaObjDamageMod
	data.CenterObjDamageMod = self.CenterObjDamageMod
	data.CenterUnitDamageMod = self.CenterUnitDamageMod
	data.DeathType = self.DeathType

	data.TriggerType = self.TriggerType
	data.timer_passed = self.timer_passed or nil
	data.BaseDamage = self.BaseDamage
	data.AreaOfEffect = self.AreaOfEffect
	data.Noise = self.Noise
	data.fx_actor_class = self.fx_actor_class
	
	if self.item_thrown then
		data.item_thrown = self.item_thrown
	else
		data.DisplayName = TGetID(self.DisplayName) -- in case it was spawned in some other way
	end
	
	data.team_side = self.team_side
	data.triggerRadius = self.triggerRadius
	data.spawned_by_explosive_object = IsValid(self.spawned_by_explosive_object) and self.spawned_by_explosive_object:GetHandle() or nil
	data.attacker = IsValid(self.attacker) and self.attacker:GetHandle() or nil
	data.triggerChance = self.triggerChance
end

---
--- Sets the dynamic data of the DynamicSpawnLandmine object from the provided data table.
---
--- @param data table The table containing the dynamic data to set.
---
function DynamicSpawnLandmine:SetDynamicData(data)
	self.additionalDifficulty = data.additionalDifficulty
	self.AreaObjDamageMod = data.AreaObjDamageMod
	self.CenterObjDamageMod = data.CenterObjDamageMod
	self.CenterUnitDamageMod = data.CenterUnitDamageMod
	self.DeathType = data.DeathType

	self.TriggerType = data.TriggerType
	self.timer_passed = data.timer_passed or nil
	self.BaseDamage = data.BaseDamage
	self.AreaOfEffect = data.AreaOfEffect
	self.Noise = data.Noise
	self.fx_actor_class = data.fx_actor_class or "PipeBomb_OnGround" -- Fallback for old saves
	self.item_thrown = data.item_thrown
	self.team_side = data.team_side or "player1"
	self.spawned_by_explosive_object = HandleToObject[data.spawned_by_explosive_object or false]
	self.attacker = HandleToObject[data.attacker or false]
	self.triggerChance = data.triggerChance
	
	-- temp: old saving + when not spawned by an item (if there is such a case)
	local savedDisplayName = false
	if data.DisplayName then
		if IsT(data.DisplayName) then -- developer mode only, old saves
			savedDisplayName = data.DisplayName
		elseif type(data.DisplayName) == "number" then
			local tid = data.DisplayName
			savedDisplayName = T{tid, TranslationTable[tid]}
		end
	end
	
	if self.item_thrown then
		local item = g_Classes[self.item_thrown]
		if item and item.DisplayName then -- Possible for item to have been deleted or marker
		
			-- temp: Ensure the name is the same
			if savedDisplayName then
				local oldNameStr = _InternalTranslate(savedDisplayName)
				local newNameStr = _InternalTranslate(item.DisplayName)
				assert(oldNameStr == newNameStr)
			end
		
			savedDisplayName = item.DisplayName
		end
	end
	
	self.DisplayName = savedDisplayName or T(696476572701, "Explosive")
	
	if data.triggerRadius then
		self.triggerRadius = data.triggerRadius
	end
	
	-- Old save compat
	if self.TriggerType ~= "Proximity" and self.TriggerType ~= "Proximity-Timed" then
		self.triggerRadius = 0
	end
	-- Old save compat 2 (ExplosiveObject)
	local terrain_z = terrain.GetHeight(self)
	local x, y, z = self:GetPosXYZ()
	if not z or z < terrain_z then
		self:SetPos(x, y, terrain_z)
	end
end

--- Determines whether the given side can see the landmine.
---
--- If the landmine was thrown by the player, enemy teams cannot discover it.
---
--- @param side string The team side to check visibility for.
--- @return boolean True if the landmine is visible to the given side, false otherwise.
function DynamicSpawnLandmine:SeenByTeam(side)
	if side == "enemy1" or side == "enemy2" then
		if self.team_side == "player1" then
			return false
		end
	end
	
	return Landmine.SeenByTeam(self, side)
end

--- Determines whether the given unit can see the landmine.
---
--- If the landmine was thrown by the player, enemy teams cannot discover it.
---
--- @param unit table The unit to check visibility for.
--- @return boolean True if the landmine is visible to the given unit, false otherwise.
function DynamicSpawnLandmine:SeenBy(unit)
	-- Enemies cannot discover landmines thrown by the player
	local unitSide = unit.team and unit.team.side
	if unitSide == "enemy1" or unitSide == "enemy2" then
		if self.team_side == "player1" then
			return false
		end
	end
	
	return true
end

--- Sets the landmine to be visible.
---
--- This function is used to make the landmine visible to all players, regardless of team.
function DynamicSpawnLandmine:SetVisible()
	Landmine.SetVisible(self, true)
end

--- Sets the collision state of the landmine and its attached FXGrenade.
---
--- @param value boolean The new collision state to set.
function DynamicSpawnLandmine:SetCollision(value)
	Landmine.SetCollision(self, value)
	local grenade = self:GetAttach("FXGrenade")
	if grenade then
		grenade:SetCollision(self, value)
	end
end

DefineClass.ExplosiveSubstance = {
	__parents = { "InventoryStack", "TrapExplosionProperties", "BobbyRayShopOtherProperties" },
	properties = {
		{ id = "dbg_explosion_buttons", no_edit = true },
	},
}
DefineClass.ExplosiveSubstanceSquadBagItem = {
	__parents = { "ExplosiveSubstance" , "SquadBagItem"},
}

DefineClass.HideGrenadeExplosiveProperties = {
	__parents = { "PropertyObject" }
}

function OnMsg.ClassesGenerate(classdefs)
	local explosivePropClass = classdefs.ExplosiveProperties
	local explosiveProps = explosivePropClass.properties
	local stripClass = classdefs.HideGrenadeExplosiveProperties
	stripClass.properties = {}
	for i, p in ipairs(explosiveProps) do
		local copy =  table.copy(p)
		copy.no_edit = p.id ~= "dbg_explosion_buttons"
		stripClass.properties[#stripClass.properties + 1] = copy
	end
end

DefineClass.ThrowableTrapItem = {
	__parents = { "Grenade", "LandmineProperties", "HideGrenadeExplosiveProperties" },
	properties = {
		{ category = "Trap", id = "ExplosiveType", editor = "choice", items = ExplosiveSubstanceCombo, default = "TNT", template = true },
	},
	triggerChance = "Always", -- cant be a dud

	BaseDamage = 0,
	AreaOfEffect = 0
}

--- Initializes the ThrowableTrapItem by setting its BaseDamage and AreaOfEffect properties based on the ExplosiveType preset.
---
--- This function is called during the initialization of a ThrowableTrapItem object.
---
--- @param self ThrowableTrapItem The ThrowableTrapItem instance being initialized.
function ThrowableTrapItem:Init()
	local explosiveTypePreset = self:GetExplosiveTypePreset()
	self.BaseDamage = explosiveTypePreset.BaseDamage
	self.AreaOfEffect = explosiveTypePreset.AreaOfEffect
	
	self:CopyProperties(explosiveTypePreset, TrapExplosionProperties:GetProperties())
end

--- Returns the explosive type preset for the ThrowableTrapItem.
---
--- This function is used to retrieve the preset configuration for the explosive type
--- associated with the ThrowableTrapItem instance.
---
--- @return table The explosive type preset.
function ThrowableTrapItem:GetExplosiveTypePreset()
	return g_Classes[self.ExplosiveType]
end

--- Overrides the default `Grenade:GetAttackResults` function to ensure that cinematic kills do not play.
---
--- This function is called when calculating the attack results for a `ThrowableTrapItem` object. It calls the base `Grenade:GetAttackResults` function and then sets the `killed_units` field of the results to `false` to prevent cinematic kills from playing.
---
--- @param self ThrowableTrapItem The `ThrowableTrapItem` instance.
--- @param action string The action being performed (e.g. "attack").
--- @param attack_args table The arguments for the attack.
--- @return table The attack results.
function ThrowableTrapItem:GetAttackResults(action, attack_args)
	local results = Grenade.GetAttackResults(self, action, attack_args)
	results.killed_units = false -- Make sure cinematic kills dont play
	return results
end

--- Handles the landing behavior of a ThrowableTrapItem.
---
--- This function is called when a ThrowableTrapItem lands after being thrown. It performs different actions depending on the TriggerType of the trap:
---
--- - For "Contact" traps, it calls the base Grenade:OnLand function.
--- - For other trigger types, it pushes unit alerts for the thrown and landing noises, places a DynamicSpawnLandmine object at the final trajectory point, and copies the explosive type properties to the new landmine.
---
--- @param self ThrowableTrapItem The ThrowableTrapItem instance.
--- @param thrower Unit The unit that threw the trap.
--- @param attackResults table The attack results for the thrown trap.
--- @param visual_obj Object The visual object representing the thrown trap.
function ThrowableTrapItem:OnLand(thrower, attackResults, visual_obj)
	if self.TriggerType == "Contact" then
		Grenade.OnLand(self, thrower, attackResults, visual_obj)
		return
	end
	
	PushUnitAlert("thrown", visual_obj, thrower)

	-- <Unit> Heard a thud
	PushUnitAlert("noise", visual_obj, self.ThrowNoise, Presets.NoiseTypes.Default.ThrowableLandmine.display_name)

	local finalPointOfTrajectory = attackResults.explosion_pos	
	assert(finalPointOfTrajectory, "Where'd that grenade fall?")
	if not finalPointOfTrajectory then return end
	 
	local teamSide = thrower and thrower.team and thrower.team.side
	assert(teamSide)
	teamSide = teamSide or "player1"
	
	local newLandmine = PlaceObject("DynamicSpawnLandmine", {
		-- The landmine properties need to be set at init time
		TriggerType = self.TriggerType, 
		triggerRadius = (self.TriggerType == "Proximity" or self.TriggerType == "Proximity-Timed") and 1 or 0,
		TimedExplosiveTurns = self.TimedExplosiveTurns,
		DisplayName = self.DisplayName,
		triggerChance = self.triggerChance,
		fx_actor_class = self.class .. "_OnGround",
		item_thrown = self.class,
		team_side = teamSide,
		attacker = thrower,
	})
	
	if IsValid(visual_obj) then
		DoneObject(visual_obj)
	end
	
	-- Copy explosive type config to the mine
	local explosiveTypePreset = self:GetExplosiveTypePreset()
	newLandmine:CopyProperties(explosiveTypePreset, TrapExplosionProperties:GetProperties())
	
	-- Add explosive skill to landmine damage.
	newLandmine.BaseDamage = thrower:GetBaseDamage(self)
	
	-- Throwable mines are seen by all
	newLandmine.discovered_by[teamSide] = true
	newLandmine:SetPos(finalPointOfTrajectory)
	newLandmine:EnterSectorInit()
	VisibilityUpdate(true)

	table.iclear(attackResults)
	attackResults.trap_placed = true
end


--- Returns the base damage of the explosive type associated with this ThrowableTrapItem.
---
--- @return number The base damage of the explosive type.
function ThrowableTrapItem:GetBaseDamage()
	local explosiveType = self:GetExplosiveTypePreset()
	return explosiveType.BaseDamage
end

---
--- Returns a description of the custom action for this ThrowableTrapItem.
---
--- @param action string The name of the action.
--- @param units table<Unit> The units affected by the action.
--- @return string The description of the custom action.
---
function ThrowableTrapItem:GetCustomActionDescription(action, units)
	local explosiveType = self:GetExplosiveTypePreset()
	local triggerTypeId = table.find(LandmineTriggerType, self.TriggerType)
	local triggerTypeDisplayName = LandmineTriggerTypeDisplayName[triggerTypeId]
	
	local extraHint = self.TriggerType == "Timed" and T{343333394143, "<newline><newline>Explodes after <turns> turns (or <seconds> seconds out of combat)",
		turns = self.TimedExplosiveTurns,
		seconds = (self.TimedExplosiveTurns * Traps_CombatTurnToTime) / 1000
	} or ""
	
	local damage = 0
	if units and #units > 0 then
		damage = units[1]:GetBaseDamage(self)
	else
		damage = self:GetBaseDamage()
	end

	return T{454367151019, "Throw a <em><TriggerType></em> explosive armed with <em><ExplosiveType></em>, dealing <em><damage> damage</em> in the area.",
		TriggerType = triggerTypeDisplayName,
		ExplosiveType = explosiveType.DisplayName,
		damage = damage
	} .. extraHint
end

---
--- Returns the UI text for the item slot of this ThrowableTrapItem.
---
--- @return string The UI text for the item slot.
function ThrowableTrapItem:GetItemSlotUI()
	local text = InventoryStack.GetItemSlotUI(self)
	local triggerTypeId = table.find(LandmineTriggerType, self.TriggerType)
	text = lLandmineTriggerToInventoryText[triggerTypeId] .. " " .. text
	return text
end

---
--- Validates the position of an explosion for a ThrowableTrapItem.
---
--- @param explosion_pos vec3 The position of the explosion.
--- @param attack_args table The attack arguments.
--- @return vec3 The validated ground position for the explosion, or nil if the position is not valid.
---
function ThrowableTrapItem:ValidatePos(explosion_pos, attack_args)
	local newGroundPos
	if explosion_pos then
		local slab, slab_z = WalkableSlabByPoint(explosion_pos, "downward only")
		local z = explosion_pos:z()
		if slab_z and slab_z <= z and slab_z >= z - guim then
			newGroundPos = explosion_pos:SetZ(slab_z)
		else
			-- check for collision geometry between explosion_pos and ground
			newGroundPos = explosion_pos:SetTerrainZ()
			local col, pts = CollideSegmentsNearest(explosion_pos, newGroundPos)
			if col then
				newGroundPos = pts[1]
			end
		end
	end
	if newGroundPos and attack_args and attack_args.obj and (g_AIExecutionController or attack_args.opportunity_attack_type == "Retaliation") then
		if IsTrapClose(newGroundPos) then
			newGroundPos = nil
		end
	end
	return newGroundPos
end

DefineClass.TrapDetonator = {
	__parents = { "InventoryItem", "BobbyRayShopOtherProperties" },
	properties = {
		{ category = "Detonator", id = "AreaOfEffect", name = "Area of Effect", help = "the area within which the detonator blows up traps",
			editor = "number", default = 3, template = true, min = 0, max = 20, },
		{ category = "Detonator", id = "ThrowRange", name = "Throw Range", help = "the range up to which the detonator can be targeted",
			editor = "number", default = 10, template = true, min = 0, max = 20, }
	}
}

---
--- Gets the visual object for the trap detonator.
---
--- @param attacker Unit The unit that is using the trap detonator.
--- @return Object The visual object for the trap detonator.
---
function TrapDetonator:GetVisualObj(attacker)
	return attacker
end

---
--- Returns the maximum number of objects that can be pierced by the trap detonator.
---
--- @return integer The maximum number of pierced objects.
---
function TrapDetonator:GetMaxPiercedObjects()
	return 1
end

---
--- Gets the attack results for the trap detonator.
---
--- @param action string The action being performed.
--- @param attack_args table The attack arguments.
--- @return table The attack results.
---
function TrapDetonator:GetAttackResults(action, attack_args)
	local target_pos = attack_args.target_pos
	if not target_pos then
		local lof_idx = table.find(attack_args.lof, "target_spot_group", attack_args.target_spot_group or "Torso")
		local lof_data = attack_args.lof and attack_args.lof[lof_idx or 1]
		target_pos = lof_data and lof_data.target_pos
	end
	
	local traps = MapGet(target_pos, self.AreaOfEffect * voxelSizeX, "Landmine", function(o)
		return o.TriggerType == "Remote" and not o.done
	end)
	
	local hits = {}
	for i, t in ipairs(traps) do
		hits[i] = {
			obj = t,
			damage = 99999
		}
	end
	
	hits.trajectory = { { pos = target_pos } }
	
	return hits
end

---
--- Gets the area attack parameters for the trap detonator.
---
--- @param ... any Additional arguments passed to the function.
--- @return table The area attack parameters.
---
function TrapDetonator:GetAreaAttackParams(...)
	return Trap.GetAreaAttackParams(self, ...)
end

---
--- Validates the position of the trap detonator.
---
--- @param ... any Additional arguments passed to the function.
--- @return boolean True if the position is valid, false otherwise.
---
function TrapDetonator:ValidatePos(...)
	return Grenade.ValidatePos(self, ...)
end

---
--- Gets the trap detonator currently equipped by the given unit.
---
--- @param unit table The unit to check for the trap detonator.
--- @return table|nil The trap detonator item, or nil if not found.
---
function GetUnitEquippedDetonator(unit)
	return unit:GetItemInSlot("Handheld A", "TrapDetonator") or
		unit:GetItemInSlot("Handheld B", "TrapDetonator") or
		unit:GetItemInSlot("Inventory", "TrapDetonator")
end

---
--- Returns a table of all available grenade types.
---
--- @return table An array of grenade type IDs.
---
function GrenadeCombo()
	local arr = {}
	ForEachPreset("InventoryItemCompositeDef", function(o)
		if IsKindOf(g_Classes[o.object_class], "Grenade") then
			arr[#arr + 1] = o.id
		end
	end)
	return arr
end

DefineClass.GrenadeThrowMarker = {
	__parents = { "GridMarker" },
	properties = {
		{ category = "Marker", id = "GrenadeType", items = GrenadeCombo, editor = "choice", default = "" }
	}
}

---
--- Executes the trigger effects for the grenade throw marker.
---
--- @param context table The context of the trigger effects.
---
function GrenadeThrowMarker:ExecuteTriggerEffects(context)
	self.trigger_count = self.trigger_count + 1
	ObjModified(self)
	
	if #(self.GrenadeType or "") == 0 then return end
	local weapon = PlaceObject(self.GrenadeType)
	if not weapon then return end
	
	local target_pos = self:GetPos()
	local attackProps = weapon:GetAreaAttackParams(nil, self, target_pos)
	local props = GetAreaAttackResults(attackProps)
	props.trajectory = { { pos = target_pos } }
	props.explosion_pos = target_pos
	weapon:OnLand(self, props, self)
end

---
--- Checks if a trap is within a specified distance from a given position.
---
--- @param trapPos table The position of the trap to check.
--- @param distance number (optional) The maximum distance to check for traps. Defaults to the voxel size.
--- @return boolean true if a trap is within the specified distance, false otherwise.
---
function IsTrapClose(trapPos, distance)
	distance = distance or voxelSizeX
	for i, t in ipairs(g_Traps) do
		if IsValid(t) and not t.done then
			if IsCloser(t, trapPos, distance) then
				return true
			end
		end
	end
end

AppendClass.EntitySpecProperties = {
	properties = {
		{ category = "ExplosiveObject", id = "explosive_type", items = GrenadeCombo, editor = "choice", default = "FragGrenade",
		no_edit = function(self) return not string.find(self.class_parent, "ExplosiveObject") end, help = "The type of explosive that will be activated when destroyed.", entitydata = true, },
		}
}

DefineClass.ExplosiveObject = {
	__parents = { "CombatObject", "GameDynamicDataObject" },
	explodePart = false,
	dying = false,
}

---
--- Saves the dynamic data of the ExplosiveObject.
---
--- @param data table The table to store the dynamic data in.
---
function ExplosiveObject:GetDynamicData(data)
	data.explodePartHandle = IsValid(self.explodePart) and self.explodePart.handle or nil
	data.dying = self.dying or nil
end

---
--- Initializes the sector for the explodePart of the ExplosiveObject.
---
--- If the explodePart exists and is not done, this function will play the "burning-start" FX.
---
function ExplosiveObject:EnterSectorInit()
	if self.explodePart and not self.explodePart.done then
		PlayFX("Explosion", "burning-start", self)
	end
end

---
--- Restores the dynamic data of the ExplosiveObject.
---
--- @param data table The table containing the dynamic data to restore.
---
function ExplosiveObject:SetDynamicData(data)
	if data.explodePartHandle then
		self.explodePart = HandleToObject[data.explodePartHandle]
	end
	self.dying = data.dying or false
end

---
--- Handles the direct damage taken by an ExplosiveObject.
---
--- If the ExplosiveObject is in the "idle" state, has no explodePart, and the damage is greater than 20, it will trigger a delayed explosion.
--- If the ExplosiveObject is in the "idle" state and the explodePart is done, it will call the OnDie function of the CombatObject.
--- Otherwise, it will call the TakeDirectDamage function of the CombatObject.
---
--- @param dmg number The amount of damage taken.
--- @param floating boolean Whether the damage is floating-point.
--- @param log_type string The type of log message.
--- @param log_msg string The log message.
--- @param attacker table The attacker entity.
--- @param hit_descr table The hit description.
---
function ExplosiveObject:TakeDirectDamage(dmg, floating, log_type, log_msg, attacker, hit_descr)
	local inIdle = self:GetStateText():starts_with("idle")
	if inIdle and not self.explodePart and dmg > 20  then
		self:DelayedExplosion(attacker and attacker.team and attacker.team.side)
	end
	if inIdle and self.explodePart and self.explodePart.done then
		CombatObject.OnDie(self, attacker, hit_descr)
	else
		CombatObject.TakeDirectDamage(self, dmg, floating, log_type, log_msg, attacker, hit_descr)
	end
end

---
--- Triggers a delayed explosion for the ExplosiveObject.
---
--- This function creates a DynamicSpawnLandmine object that will explode after a random number of turns. The explosion properties are copied from the ExplosiveObject's explosive type preset. The landmine is placed at the same position and orientation as the ExplosiveObject, and its visibility is set to false.
---
--- @param side number The team side of the attacker, if any.
---
function ExplosiveObject:DelayedExplosion(side)
	local ent = EntityData[self:GetEntity()]
	ent = ent and ent.entity

	self.explodePart = PlaceObject("DynamicSpawnLandmine", {
		TriggerType = "Timed", 
		triggerRadius = 0,
		TimedExplosiveTurns = InteractionRand(3, "Traps") + 1,
		triggerChance = "Always",
		fx_actor_class = self.class,
		spawned_by_explosive_object = self,
		ExplosiveType = ent and ent.explosive_type or "C4",
		team_side = side -- We want the mine to run its turn in the same time as its attacker
	})
	self.explodePart.UpdateInteractableBadge = function() end
	local explosiveTypePreset = g_Classes[self.explodePart.ExplosiveType]
	self.explodePart:CopyProperties(explosiveTypePreset, TrapExplosionProperties:GetProperties())
	PlayFX("Explosion", "burning-start", self)

	local terrain_z = terrain.GetHeight(self)
	local x, y, z = self:GetPosXYZ()
	if not z or z < terrain_z then
		z = terrain_z
	end
	self.explodePart:SetPos(x, y, z)
	self.explodePart:SetOrientation(self:GetOrientation())
	Landmine.SetVisible(self.explodePart, false)
	self.explodePart:EnterSectorInit()
end

---
--- Executes the explosion logic when the ExplosiveObject dies.
---
--- If the ExplosiveObject is in the "idle" state and does not have an explodePart, it will trigger a delayed explosion using the `DelayedExplosion` function. If the explodePart is not done, it will sleep for 500 milliseconds and then trigger the trap. Finally, it will call the `OnDie` function of the `CombatObject` class.
---
--- @param attacker table The attacker that caused the ExplosiveObject to die.
--- @param hit_descr table A table containing information about the hit that caused the ExplosiveObject to die.
---
function ExplosiveObject:ExecOnDieExplosion(attacker, hit_descr)
	if self:GetStateText():starts_with("idle") then	
		if not self.explodePart then
			self:DelayedExplosion()
		end
		if not self.explodePart.done then
			Sleep(500)
			self.explodePart:TriggerTrap(nil, attacker)
		end
	end
	CombatObject.OnDie(self, attacker, hit_descr)
end

---
--- Executes the explosion logic when the ExplosiveObject dies.
---
--- If the ExplosiveObject is in the "idle" state and does not have an explodePart, it will trigger a delayed explosion using the `DelayedExplosion` function. If the explodePart is not done, it will sleep for 500 milliseconds and then trigger the trap. Finally, it will call the `OnDie` function of the `CombatObject` class.
---
--- @param attacker table The attacker that caused the ExplosiveObject to die.
--- @param hit_descr table A table containing information about the hit that caused the ExplosiveObject to die.
---
function ExplosiveObject:OnDie(attacker, hit_descr)
	if self.dying then return end
	self.dying = true
	CreateGameTimeThread(ExplosiveObject.ExecOnDieExplosion, self, attacker, hit_descr)
end