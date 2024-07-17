DefineClass.BossfightPierre = {
	__parents = { "Encounter" },	
	
	default_assigned_area = false,	
	boss = false,
	guards_melee = false,
	guard_heavy = false,
	guard_rpg = false,
	
	enrage_turn = 4, -- timer to make sure Pierre and his melee guards go hand-to-hand
	fallback_turn = false,
	area_tactics = true,
}

g_SectorEncounters.H4 = "BossfightPierre"

--- Determines whether the BossfightPierre encounter should start.
---
--- This function checks if the "FortressFirstCapture" quest variable is false.
--- If the variable is false, the encounter should start.
---
--- @return boolean true if the encounter should start, false otherwise
function BossfightPierre:ShouldStart()
	return not GetQuestVar("ErnieSideQuests", "FortressFirstCapture")
end

--- Initializes the BossfightPierre encounter by setting up the boss and guard units.
---
--- This function iterates through various groups of units and assigns them to the
--- corresponding properties of the BossfightPierre object, such as `boss`, `guard_rpg`,
--- `guard_heavy`, and `guards_melee`.
---
--- @function BossfightPierre:Setup
--- @return nil
function BossfightPierre:Setup()	
	for _, obj in ipairs(Groups.LegionRocketeer_SlowReloader) do
		if IsKindOf(obj, "Unit") then
			self.guard_rpg = obj
			break
		end
	end
	for _, obj in ipairs(Groups.PierreGuard_Ordnance) do
		if IsKindOf(obj, "Unit") then
			self.guard_heavy = obj
			break
		end
	end
	self.guards_melee = {}
	for _, obj in ipairs(Groups.PierreGuard_Stormer) do
		if IsKindOf(obj, "Unit") then
			table.insert(self.guards_melee, obj)
		end
	end
	
	for _, obj in ipairs(Groups.Pierre) do
		if IsKindOf(obj, "Unit") then
			self.boss = obj
			break
		end
	end	
end

--- Serializes the dynamic data of the BossfightPierre encounter to a table.
---
--- This function iterates through the various properties of the BossfightPierre object,
--- such as `boss`, `guards_melee`, `guard_heavy`, `guard_rpg`, `enrage_turn`,
--- `area_tactics`, and `fallback_turn`, and stores their handles or values in a table.
--- This table can then be used to restore the state of the encounter later.
---
--- @param data table A table to store the dynamic data
--- @return nil
function BossfightPierre:GetDynamicData(data)
	data.boss = IsValid(self.boss) and self.boss:GetHandle() or nil
	data.guards_melee = {}
	for i, unit in ipairs(self.guards_melee) do
		local handle = IsValid(unit) and not unit:IsDead() and unit:GetHandle()
		if handle then
			table.insert(data.guards_melee, handle)
		end
	end
	data.guard_heavy = IsValid(self.guard_heavy) and self.guard_heavy:GetHandle() or nil
	data.guard_rpg = IsValid(self.guard_rpg) and self.guard_rpg:GetHandle() or nil
	data.enrage_turn = self.enrage_turn
	data.area_tactics = self.area_tactics
	data.fallback_turn = self.fallback_turn
end

--- Restores the dynamic data of the BossfightPierre encounter from a serialized table.
---
--- This function takes a table containing the serialized dynamic data of the BossfightPierre
--- encounter, and restores the state of the encounter by setting the appropriate properties
--- of the BossfightPierre object, such as `boss`, `guards_melee`, `guard_heavy`, `guard_rpg`,
--- `enrage_turn`, `area_tactics`, and `fallback_turn`.
---
--- @param data table A table containing the serialized dynamic data
--- @return nil
function BossfightPierre:SetDynamicData(data)
	self.boss = data.boss and HandleToObject[data.boss]
	self.guards_melee = {}
	for _, handle in ipairs(data.guards_melee) do
		table.insert(self.guards_melee, HandleToObject[handle])
	end
	self.guard_heavy = data.guard_heavy and HandleToObject[data.guard_heavy]
	self.guard_rpg = data.guard_rpg and HandleToObject[data.guard_rpg]
	
	self.enrage_turn = data.enrage_turn
	self.area_tactics = data.area_tactics
	self.fallback_turn = data.fallback_turn
end

--- Determines whether the given unit should hold its position.
---
--- This function checks if the given unit has the "Sniper" or "Ordnance" AI keyword, and returns true if either of these keywords are found.
---
--- @param unit table The unit to check
--- @return boolean True if the unit should hold its position, false otherwise
function BossfightPierre:ShouldHoldPosition(unit)
	return table.find(unit.AIKeywords, "Sniper") or table.find(unit.AIKeywords, "Ordnance")
end

--- Handles the turn start logic for the BossfightPierre encounter.
---
--- This function is called at the start of each turn during the BossfightPierre encounter. It
--- determines the appropriate tactics and behavior for the boss and his guards based on the
--- current state of the encounter, such as the number of player units in the area, the current
--- turn, and whether the boss has entered an "enrage" state.
---
--- The function assigns the boss and guards to specific areas on the tactical map, sets their
--- script archetypes (e.g. "GuardArea", "Brute", "Soldier"), and ensures they are equipped with
--- the appropriate weapons for their roles.
---
--- @param self BossfightPierre The BossfightPierre object
--- @return nil
function BossfightPierre:OnTurnStart()		
	local player_units_in_area, enemy_units_in_area = g_TacticalMap:CountUnitsInAreas()
	local plrunits = 0
	plrunits = plrunits + (player_units_in_area.PierreFight_DetectAssault_Yard_1 or 0)
	plrunits = plrunits + (player_units_in_area.PierreFight_DetectAssault_Yard_2 or 0)
	plrunits = plrunits + (player_units_in_area.PierreFight_DetectFlanking_BackPass or 0)
	plrunits = plrunits + (player_units_in_area.PierreFight_DetectFlanking_MainBuilding or 0)
	plrunits = plrunits + (player_units_in_area.PierreFight_Yard_Transition or 0)
	plrunits = plrunits + (player_units_in_area.PierreFight_InnerPerimeter_MainBuilding or 0)

	local area_tactics = self.area_tactics and (g_Combat.current_turn < self.enrage_turn)

	if area_tactics and plrunits < 2 then
		self.boss.script_archetype = "GuardArea"
		for _, guard in ipairs(self.guards_melee) do
			guard.script_archetype = "GuardArea"
		end
		
		local mg_detect = (player_units_in_area.PierreFight_DetectFlanking_MG or 0) > 1
		if g_Combat.current_turn == 1 or mg_detect then 
			g_TacticalMap:AssignUnit(self.boss, nil)
			g_TacticalMap:AssignUnit(self.boss, "PierreFight_Yard_Hangar", nil, g_TacticalMap.PriorityHigh)
			g_TacticalMap:AssignUnit(self.boss, "PierreFight_Yard_Containers", nil, g_TacticalMap.PriorityMedium)
			if mg_detect then
				g_TacticalMap:AssignUnit(self.boss, "PierreFight_FlankingDefense_Yard", nil, g_TacticalMap.PriorityMedium)
			else
				g_TacticalMap:AssignUnit(self.boss, "PierreFight_Yard_SideHangar", nil, g_TacticalMap.PriorityMedium)
			end
			for _, guard in ipairs(self.guards_melee) do
				g_TacticalMap:AssignUnit(guard, nil)
				g_TacticalMap:AssignUnit(guard, "PierreFight_Yard_Hangar", nil, g_TacticalMap.PriorityHigh)
				g_TacticalMap:AssignUnit(guard, "PierreFight_Yard_Containers", nil, g_TacticalMap.PriorityMedium)
				if mg_detect then
					g_TacticalMap:AssignUnit(guard, "PierreFight_FlankingDefense_Yard", nil, g_TacticalMap.PriorityMedium)
				else
					g_TacticalMap:AssignUnit(guard, "PierreFight_Yard_SideHangar", nil, g_TacticalMap.PriorityMedium)
				end
			end
		end
		
		if self.fallback_turn and g_Combat.current_turn > self.fallback_turn then
			-- "Fallback!" continuation
			-- assign units from PierreFight_Yard_Transition and PierreFight_FlankingDefense_Yard (3.2) to PierreFight_InnerPerimeter_MainBuilding
			local units = table.union(g_TacticalMap:GetUnitsInArea("PierreFight_Yard_Transition"), g_TacticalMap:GetUnitsInArea("PierreFight_FlankingDefense_Yard"))
			for _, unit in ipairs(units) do
				if not self:ShouldHoldPosition(unit) then
					unit.script_archetype = "GuardArea"
					g_TacticalMap:AssignUnit(unit, "PierreFight_InnerPerimeter_MainBuilding", "reset")
				end
			end
		elseif (self.fallback_turn and self.fallback_turn == g_Combat.current_turn) or g_Combat.current_turn >= 3 then
			-- "Fallback!"
			
			-- assign units from PierreFight_Yard_SideHangar to PierreFight_InnerPerimeter_Cannon
			local units = g_TacticalMap:GetUnitsInArea("PierreFight_Yard_SideHangar")
			for _, unit in ipairs(units) do
				if not self:ShouldHoldPosition(unit) then
					unit.script_archetype = "GuardArea"
					g_TacticalMap:AssignUnit(unit, "PierreFight_InnerPerimeter_Cannon", "reset")
				end
			end
			
			-- assign units from PierreFight_Yard_Hangar and PierreFight_Yard_Containers to PierreFight_InnerPerimeter_MainBuilding, sub PierreFight_Yard_Transition, sub PierreFight_FlankingDefense_Yard
			units = table.union(g_TacticalMap:GetUnitsInArea("PierreFight_Yard_Hangar"), g_TacticalMap:GetUnitsInArea("PierreFight_Yard_Containers"))
			for _, unit in ipairs(units) do
				if not self:ShouldHoldPosition(unit) then
					unit.script_archetype = "GuardArea"
					g_TacticalMap:AssignUnit(unit, nil)
					g_TacticalMap:AssignUnit(unit, "PierreFight_InnerPerimeter_MainBuilding", nil, g_TacticalMap.PriorityHigh)
					g_TacticalMap:AssignUnit(unit, "PierreFight_Yard_Transition", nil, g_TacticalMap.PriorityMedium)
					g_TacticalMap:AssignUnit(unit, "PierreFight_FlankingDefense_Yard", nil, g_TacticalMap.PriorityLow)
				end
			end
		end		
	else
		if plrunits >= 2 then
			self.area_tactics = false
		end
		for _, unit in ipairs(self.boss.team.units) do
			g_TacticalMap:AssignUnit(unit, nil)
			unit.script_archetype = nil
		end

		self.guard_heavy.AIKeywords = table.copy(self.guard_heavy.AIKeywords)
		if self.guard_rpg then
			self.guard_rpg.AIKeywords = table.copy(self.guard_rpg.AIKeywords)
		end
		
		if g_Combat.current_turn >= self.enrage_turn then
			self.boss.script_archetype = "Brute"
			for _, guard in ipairs(self.guards_melee) do
				guard.script_archetype = "Brute"
			end
			
			table.insert_unique(self.guard_heavy.AIKeywords, "Ordnance")		
		else
			-- check Pierre for charge attack, go melee or ranged based on that
			local boss = self.boss
			local enemies = GetEnemies(boss)
			local can_charge 
			local ap = CombatActions.GloryHog:ResolveValue("move_ap") * const.Scale.AP
			for _, enemy in ipairs(enemies) do
				if GetChargeAttackPosition(boss, enemy, ap, "GloryHog") then
					can_charge = true
					break
				end
			end
			if can_charge then
				self.boss.script_archetype = "Brute"
				for _, guard in ipairs(self.guards_melee) do
					guard.script_archetype = "Brute"
				end
			else
				self.boss.script_archetype = "Soldier"
				for _, guard in ipairs(self.guards_melee) do
					guard.script_archetype = "Soldier"
				end
			end
			
			table.remove_value(self.guard_heavy.AIKeywords, "Ordnance")
		end
		
		-- RPG Guard
		if self.guard_rpg then
			if g_Combat.current_turn > 3 then
				table.insert_unique(self.guard_rpg.AIKeywords, "Ordnance")
			else
				table.remove_value(self.guard_rpg.AIKeywords, "Ordnance")
			end
		end
	end

	-- GuardArea assignment (fallback)
	for _, unit in ipairs(self.boss.team.units) do
		if unit.script_archetype == "GuardArea" and not g_TacticalMap:GetAssignedAreas(unit) then
			g_TacticalMap:AssignUnit(unit, nil)
			g_TacticalMap:AssignUnit(unit, "PierreFight_InnerPerimeter_MainBuilding", nil, g_TacticalMap.PriorityHigh)
			g_TacticalMap:AssignUnit(unit, "PierreFight_Yard_Transition", nil, g_TacticalMap.PriorityMedium)
			g_TacticalMap:AssignUnit(unit, "PierreFight_FlankingDefense_Yard", nil, g_TacticalMap.PriorityLow)
		end
	end	
	
	-- make sure Pierre and his guards are on the correct weapon set for their archetypes
	self:EquipProperWeapon(self.boss)
	for _, guard in ipairs(self.guards_melee) do
		self:EquipProperWeapon(guard)
	end
	self:EquipProperWeapon(self.guard_rpg)
end

local function FindWeaponByClass(unit, class, slot)
	if not slot then
		slot = unit.current_weapon
	elseif slot == "alt" then
		slot = (unit.current_weapon == "Handheld A") and "Handheld B" or "Handheld A"
	end
	
	local weapons = unit:GetEquippedWeapons(slot)

	for _, weapon in ipairs(weapons) do
		if IsKindOf(weapon, class) and (class ~= "Firearm" or not IsKindOf(weapon, "HeavyWeapon")) then
			return weapon
		end
		if IsKindOf(weapon, "Firearm") then		
			for slot, sub in sorted_pairs(weapon.subweapons) do
				if IsKindOf(sub, class) and (class ~= "Firearm" or not IsKindOf(sub, "HeavyWeapon")) then
					return sub
				end			
			end
		end
	end
end


---
--- Equips the proper weapon for the given unit based on its archetype and AI keywords.
---
--- @param unit Unit The unit to equip the proper weapon for.
---
function BossfightPierre:EquipProperWeapon(unit)
	if not IsValidTarget(unit) then return end
	
	if table.find(unit.AIKeywords, "Ordnance") then
		-- make sure we have a heavy weapon
		if not FindWeaponByClass(unit, "HeavyWeapon") and FindWeaponByClass(unit, "HeavyWeapon", "alt") then
			unit:SwapActiveWeapon()
		end
	elseif unit:GetArchetype().id == "Brute" then
		-- prefer to have melee weapon or shotgun
		if not FindWeaponByClass(unit, "MeleeWeapon") then
			if FindWeaponByClass(unit, "MeleeWeapon", "alt") then
				unit:SwapActiveWeapon()
			elseif not FindWeaponByClass(unit, "Shotgun") and FindWeaponByClass(unit, "Shotgun", "alt") then
				unit:SwapActiveWeapon()
			end
		end
	else
		-- prefer to have AR -> SMG -> Firearm
		if not FindWeaponByClass(unit, "AssaultRifle") then
			if FindWeaponByClass(unit, "AssaultRifle", "alt") then
				unit:SwapActiveWeapon()
			elseif not FindWeaponByClass(unit, "SubmachineGun") then
				if FindWeaponByClass(unit, "SubmachineGun", "alt") then
					unit:SwapActiveWeapon()
				elseif not FindWeaponByClass(unit, "Firearm") and FindWeaponByClass(unit, "Firearm", "alt") then
					unit:SwapActiveWeapon()
				end
			end
		end
	end
end

---
--- Handles the effects when an enemy unit is downed during the boss fight.
---
--- If the boss is valid and within 5 tiles of the downed unit, the boss will become enraged for 3 turns.
---
--- @param unit Unit The enemy unit that was downed.
---
function BossfightPierre:OnEnemyFall(unit)
	if g_Combat and IsValid(self.boss) and not self.boss:IsDead() and self.boss:GetDist(unit) < 5 * const.SlabSizeX then
		self.enrage_turn = g_Combat.current_turn + 3
	end
end

---
--- Handles the effects when an enemy unit is downed during the boss fight.
---
--- If the boss is valid and within 5 tiles of the downed unit, the boss will become enraged for 3 turns.
---
--- @param unit Unit The enemy unit that was downed.
---
function BossfightPierre:OnUnitDied(unit)
	if not g_Combat or not self.boss then return end
	if unit.team == self.boss.team and not table.find(unit.AIKeywords, "Sniper") then
		self.fallback_turn = g_Combat.current_turn
		if g_Teams[g_CurrentTeam] == self.boss.team then
			self.fallback_turn = self.fallback_turn + 1
		end
	elseif unit:IsOnEnemySide(self.boss) then
		self:OnEnemyFall(unit)
	end
end

---
--- Handles the effects when an enemy unit is downed during the boss fight.
---
--- If the boss is valid and within 5 tiles of the downed unit, the boss will become enraged for 3 turns.
---
--- @param unit Unit The enemy unit that was downed.
---
function BossfightPierre:OnUnitDowned(unit)
	return self:OnUnitDied(unit)
end