MapVar("g_Encounter", false)

if FirstLoad then
	g_SectorEncounters = {} -- [sector_id] = encouner classname
end

-- common bossfight logic: area/marker assignment, callbacks
DefineClass.Encounter = {
	__parents = { "GameDynamicSpawnObject" },

	default_assigned_area = 0,
	original_area = false,
}

---
--- Initializes the Encounter object.
---
--- This function sets the global `g_Encounter` variable to the current Encounter object,
--- creates a new `TacticalMap` object if it doesn't already exist, and initializes the
--- `original_area` table to store the original areas of units.
---
--- Finally, it sets the position of the Encounter object to the center of the map.
---
function Encounter:Init()
	g_Encounter = self
	if not g_TacticalMap then
		g_TacticalMap = TacticalMap:new()
	end
	self.original_area = {}
	
	self:SetPos(point(terrain.GetMapSize()) / 2)
end

---
--- Determines if the Encounter object can scout.
---
--- This function always returns `false`, indicating that the Encounter object cannot scout.
---
function Encounter:CanScout()
	return false
end

---
--- Stores the original areas of units in the `data.original_area` table.
---
--- This function iterates through the `self.original_area` table, which contains the original areas of units in the encounter. For each unit, it retrieves the unit's handle and the corresponding original area, and stores this information in the `data.original_area` table.
---
--- @param data table The table to store the original areas in.
---
function Encounter:GetDynamicData(data)
	data.original_area = {}
	for unit, area in pairs(self.original_area) do
		if unit then
			data.original_area[unit:GetHandle()] = area
		end
	end
end

---
--- Sets the original areas of units in the Encounter object.
---
--- This function takes a table of original areas, where the keys are unit handles and the values are the original areas. It then stores these original areas in the `self.original_area` table, using the unit objects as the keys.
---
--- @param data table The table of original areas, where the keys are unit handles and the values are the original areas.
---
function Encounter:SetDynamicData(data)
	self.original_area = {}
	for handle, area in pairs(data.original_area) do
		local unit = HandleToObject[handle] or false
		self.original_area[unit] = area
	end
end

---
--- Assigns the initial areas for enemy units in the encounter.
---
--- This function iterates through all units in the game, and for each enemy unit that is not in the "CombatFreeRoam" group, it assigns the unit to an area on the tactical map. If the unit does not have a primary area assigned, it is assigned to the `default_assigned_area` of the encounter. The original area of each unit is stored in the `g_Encounter.original_area` table.
---
--- @param self Encounter The encounter object.
---
function Encounter:InitAssignedArea()
	for _, unit in ipairs(g_Units) do
		if unit.team.player_enemy and not table.find(unit.Groups or empty_table, "CombatFreeRoam") then
			local area = g_TacticalMap:GetUnitPrimaryArea(unit)
			if (area or 0) == 0 then
				StoreErrorSource(unit, "Enemy unit starting combat in non-marked area!")
				area = self.default_assigned_area or 0
			end
			g_TacticalMap:AssignUnit(unit, area, "reset")
			g_Encounter.original_area[unit] = area
		end
	end
end

---
--- Determines if the encounter should start.
---
--- @return boolean true if the encounter should start, false otherwise
---
function Encounter:ShouldStart()
end
---
--- Handles the event when a unit dies in the encounter.
---
--- This function is called when a unit dies during the encounter. It can be used to perform any necessary actions or cleanup related to the unit's death.
---
--- @param self Encounter The encounter object.
--- @param unit table The unit that died.
---
function Encounter:OnUnitDied(unit)
end
---
--- Handles the event when a unit is downed in the encounter.
---
--- This function is called when a unit is downed during the encounter. It can be used to perform any necessary actions or cleanup related to the unit's downing.
---
--- @param self Encounter The encounter object.
--- @param unit table The unit that was downed.
---
function Encounter:OnUnitDowned(unit)
end
---
--- Handles the event when a unit's turn starts in the encounter.
---
--- This function is called when a unit's turn starts during the encounter. It can be used to perform any necessary actions or setup related to the unit's turn.
---
--- @param self Encounter The encounter object.
--- @param unit table The unit whose turn is starting.
---
function Encounter:OnTurnStart(unit)
end
---
--- Handles the event when damage is done during the encounter.
---
--- This function is called when damage is done during the encounter. It can be used to perform any necessary actions or cleanup related to the damage.
---
--- @param self Encounter The encounter object.
--- @param attacker table The unit that dealt the damage.
--- @param target table The unit that received the damage.
--- @param dmg number The amount of damage dealt.
--- @param hit_descr table The description of the hit that caused the damage.
---
function Encounter:OnDamageDone(attacker, target, dmg, hit_descr)
end
---
--- Sets up the encounter.
---
--- This function is called to initialize the encounter. It can be used to perform any necessary setup or initialization tasks for the encounter.
---
--- @param self Encounter The encounter object.
---
function Encounter:Setup()
end
---
--- Finalizes the turn for the encounter.
---
--- This function is called at the end of a unit's turn during the encounter. It can be used to perform any necessary cleanup or end-of-turn actions.
---
--- @param self Encounter The encounter object.
---
function Encounter:FinalizeTurn()
end

function OnMsg.UnitDied(unit)
	if g_Encounter and not g_Encounter:ShouldStart() then
		g_Encounter:delete()
		g_Encounter = false
	end
	if IsKindOf(g_Encounter, "Encounter") then
		g_Encounter:OnUnitDied(unit)
	end
end

function OnMsg.UnitDowned(unit)
	if g_Encounter and not g_Encounter:ShouldStart() then
		g_Encounter:delete()
		g_Encounter = false
	end
	if IsKindOf(g_Encounter, "Encounter") then
		g_Encounter:OnUnitDowned(unit)
	end
end

function OnMsg.TurnStart(unit)
	if not g_Teams[g_CurrentTeam].player_enemy then return end
	if g_Encounter and not g_Encounter:ShouldStart() then
		g_Encounter:delete()
		g_Encounter = false
	end
	if IsKindOf(g_Encounter, "Encounter") then
		g_Encounter:OnTurnStart(unit)
	end
end

function OnMsg.DamageDone(attacker, target, dmg, hit_descr)
	if g_Encounter and not g_Encounter:ShouldStart() then
		g_Encounter:delete()
		g_Encounter = false
	end
	if IsKindOf(g_Encounter, "Encounter") then
		g_Encounter:OnDamageDone(attacker, target, dmg, hit_descr)
	end
end

function OnMsg.CombatStart(dynamic_data)
	if dynamic_data then return end
	if g_Encounter and not g_Encounter:ShouldStart() then
		g_Encounter:delete()
		g_Encounter = false
	end
	for sector_id, classname in pairs(g_SectorEncounters) do		
		if sector_id == gv_CurrentSectorId and g_Classes[classname] and g_Classes[classname]:ShouldStart() then
			g_Encounter = g_Classes[classname]:new()
			g_Encounter:Setup()
		end
	end
end

function OnMsg.CombatEnd()
	if g_Encounter then
		g_Encounter:delete()
		g_Encounter = false
	end
end