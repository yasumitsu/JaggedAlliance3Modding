-- area reached flags
local reachedPlayer = 1
local reachedBoss = 2

DefineClass.BossfightFaucheaux = {
	__parents = { "Encounter" },	
	
	default_assigned_area = false,
	
	-- state
	run_away = false,
	chosen_path = 1,
	boss = false,
	escape_turn = false,
	escaped = false,
	enemies_aware = false,
	
	reached_areas = false, -- after Faucheaux has started running
	released_areas = false,
}

g_SectorEncounters.K16 = "BossfightFaucheaux"

--- Determines whether the BossfightFaucheaux encounter should start.
---
--- @return boolean True if the encounter should start, false otherwise.
function BossfightFaucheaux:ShouldStart()
	return not GetQuestVar("05_TakeDownFaucheux", "Completed")
end

---
--- Initializes the `reached_areas` and `released_areas` properties of the `BossfightFaucheaux` class.
---
--- This function is called during the setup of the `BossfightFaucheaux` encounter to initialize the tracking of areas reached and released by the boss.
---
--- @function BossfightFaucheaux:Init
--- @return nil
function BossfightFaucheaux:Init()	
	self.reached_areas = {}
	self.released_areas = {}
end

---
--- Initializes the setup of the BossfightFaucheaux encounter.
---
--- This function is called during the setup of the BossfightFaucheaux encounter to initialize the assigned area for the encounter.
---
--- @function BossfightFaucheaux:Setup
--- @return nil
function BossfightFaucheaux:Setup()
	self:InitAssignedArea()
end

---
--- Retrieves the dynamic data associated with the BossfightFaucheaux encounter.
---
--- This function is called to get the current state of the BossfightFaucheaux encounter, which includes information such as whether the boss is running away, the chosen path, whether the boss has escaped, and the areas that have been reached and released.
---
--- @param data table A table to store the dynamic data of the BossfightFaucheaux encounter.
--- @return nil
function BossfightFaucheaux:GetDynamicData(data)
	data.run_away = self.run_away or nil
	data.chosen_path = (self.chosen_path ~= 1) and self.chosen_path or nil
	data.escape_turn = self.escape_turn or nil
	data.escaped = self.escaped or nil
	data.reached_areas = table.copy(self.reached_areas)
	data.released_areas = table.copy(self.released_areas)
	data.boss = IsValid(self.boss) and self.boss:GetHandle() or nil
	data.enemies_aware = self.enemies_aware or nil
end

---
--- Sets the dynamic data associated with the BossfightFaucheaux encounter.
---
--- This function is called to update the current state of the BossfightFaucheaux encounter, which includes information such as whether the boss is running away, the chosen path, whether the boss has escaped, and the areas that have been reached and released.
---
--- @param data table A table containing the dynamic data of the BossfightFaucheaux encounter.
--- @return nil
function BossfightFaucheaux:SetDynamicData(data)
	self.run_away = data.run_away
	self.chosen_path = data.chosen_path
	self.escape_turn = data.escape_turn
	self.escaped = data.escaped
	self.reached_areas = table.copy(data.reached_areas)
	self.released_areas = table.copy(data.released_areas)	
	self.boss = data.boss and HandleToObject[data.boss]
	self.enemies_aware = data.enemies_aware
end

local path1areas = {
	"Control_Zone_HQ",
	"Control_Zone_HQFront",
	"Control_Zone_Containers1",
	"Control_Zone_Containers2",
	"ControlZone_OpenCorridor2",
	"Control_Zone_FinalDest",	
}

local path2areas = {
	"Control_Zone_HQ",
	"Control_Zone_MessHall",
	"Control_Zone_Tents",
	"Control_Zone_Armory",
	"Control_Zone_Passage",
	"Control_Zone_OfficerRoom",
	"ControlZone_OpenCorridor2",
	"Control_Zone_FinalDest",
}

local detection_areas = {
	["Control_Zone_MessHall"] = true,
	["Control_Zone_HQFront"] = true,
	["Control_Zone_FaucheauxCabinet"] = true,
	["Control_Zone_HQ"] = true,
	["Control_Zone_Tents"] = true,
}

---
--- Triggers the boss to retreat.
---
--- This function is called when the boss takes damage or when the player reaches certain areas. It sets the `run_away` flag, calculates the chances of the boss escaping via two different paths, and selects a path for the boss to take. The boss's script archetype is also updated to indicate that the boss is retreating.
---
--- @param self BossfightFaucheaux The BossfightFaucheaux instance.
--- @return nil
function BossfightFaucheaux:TriggerRetreat()
	if self.run_away then
		return
	end
	self.run_away = true
	
	local path1alive, path1total = 0, 0
	local path2alive, path2total = 0, 0
	
	for _, unit in ipairs(g_Units) do
		local x, y, z = unit:GetPosXYZ()
		local unit_pos = point_pack(x, y, z)
		local area = g_TacticalMap:GetUnitPrimaryArea(unit)
		local original_area = self.original_area[unit]
		
		if unit.team.player_enemy and table.find(path1areas, original_area) then
			if not unit:IsDead() then
				path1alive = path1alive + 1
			end
			path1total = path1total + 1
		end
		
		if unit.team.player_enemy and table.find(path2areas, original_area) then
			if not unit:IsDead() then
				path2alive = path2alive + 1
			end
			path2total = path2total + 1
		end
	end
	
	local chance1 = MulDivRound(path1alive, 100, Max(1, path1total))
	local chance2 = MulDivRound(path2alive, 100, Max(1, path2total))
	
	if chance1 + chance2 > 0 then
		local roll = InteractionRand(chance1 + chance2, "Bossfight")
		self.chosen_path = (roll <= chance1) and 1 or 2
	end
	self.boss.script_archetype = "Faucheaux_BossRetreating"
end

---
--- Triggers the boss to retreat when the boss takes damage.
---
--- This function is called when the boss takes damage. It triggers the boss to retreat by calling the `TriggerRetreat()` function.
---
--- @param self BossfightFaucheaux The BossfightFaucheaux instance.
--- @param attacker Unit The unit that attacked the boss.
--- @param target Unit The boss unit that was attacked.
--- @param dmg number The amount of damage dealt to the boss.
--- @param hit_descr string A description of the hit.
--- @return nil
function BossfightFaucheaux:OnDamageDone(attacker, target, dmg, hit_descr)
	if target == self.boss then
		self:TriggerRetreat()
	end
end

---
--- Handles the logic for when an area is reached during the boss retreat.
---
--- This function is called when a player unit or the boss unit reaches a new area during the boss retreat. It updates the state of the retreat based on which areas have been reached.
---
--- @param self BossfightFaucheaux The BossfightFaucheaux instance.
--- @param area string The name of the area that was reached.
--- @param flag integer A flag indicating whether the area was reached by a player unit (reachedPlayer) or the boss unit (reachedBoss).
--- @return nil
function BossfightFaucheaux:OnAreaReached(area, flag)
	if not self.run_away then 
		if flag == reachedPlayer and self.enemies_aware and detection_areas[area] then
			self:TriggerRetreat()
		end
		return 
	end
	
	if flag == reachedPlayer then
		if area == "Control_Zone_KillingField1" or area == "Control_Zone_KillingField2" or area == "Control_Zone_Containers1" or area == "Control_Zone_Armory" then
			self.released_areas.Control_Zone_EastWall = true
		end
		if area == "Control_Zone_KillingField1" or area == "Control_Zone_KillingField2" or area == "Control_Zone_Containers1" or area == "Control_Zone_MessHall" then
			self.released_areas.Control_Zone_BlastEntrance = true
			self.released_areas.Control_Zone_WestPicket = true
			self.released_areas.Control_Zone_WestTower = true
		end
		if area == "Control_Zone_OpenCorridor1" or area == "Control_Zone_Containers1" or area == "Control_Zone_Tents" then
			self.released_areas.Control_Zone_WallWest = true
			self.released_areas.Control_Zone_RadioTower = true
		end
	elseif flag == reachedBoss then
		if area == "Control_Zone_Tents" then
			self.released_areas.Control_Zone_EastWall = true
		end
		if area == "Control_Zone_Containers1" or area == "Control_Zone_Armory" then
			self.released_areas.Control_Zone_BlastEntrance = true
			self.released_areas.Control_Zone_WestPicket = true
			self.released_areas.Control_Zone_WestTower = true
			self.released_areas.Control_Zone_WallWest = true
			self.released_areas.Control_Zone_RadioTower = true
		end
		if area == "Control_Zone_FinalDest" then
			self.escape_turn = g_Combat.current_turn + 1
		end
	end
end

---
--- Updates the awareness state of the boss and its team.
---
--- This function checks if any of the boss's team members are aware. If any team member is aware, it removes the "Unaware" status effect from all team members.
---
--- @param self BossfightFaucheaux The BossfightFaucheaux instance.
--- @return nil
function BossfightFaucheaux:UpdateAwareness()
	if not self.boss then return end
	
	local aware = self.enemies_aware
	if not aware then
		for _, unit in ipairs(g_Units) do
			if unit.team == self.boss.team then
				aware = aware or unit:IsAware()
			end
		end
	end
	if aware then
		for _, unit in ipairs(g_Units) do
			if unit.team == self.boss.team then
				unit:RemoveStatusEffect("Unaware")
			end
		end
		self.enemies_aware = true
	end
end

---
--- Updates the progress of the boss fight areas.
---
--- This function checks the areas that the player's units and the boss have reached, and updates the `reached_areas` table accordingly. It calls the `OnAreaReached` function when an area is reached by either the player or the boss.
---
--- @param self BossfightFaucheaux The BossfightFaucheaux instance.
--- @return nil
function BossfightFaucheaux:UpdateAreaProgress()
	assert(g_TacticalMap)
	if not self.run_away then 
		return 
	end
	for _, unit in ipairs(g_Units) do
		local areas = g_TacticalMap:GetUnitAreas(unit)
		if unit.team.player_team and not unit:IsDead() then
			for area_id in tac_area_ids(areas) do
				if band(self.reached_areas[area_id] or 0, reachedPlayer) == 0 then
					self.reached_areas[area_id] = bor(self.reached_areas[area_id] or 0, reachedPlayer)
					self:OnAreaReached(area_id, reachedPlayer)
				end
			end
		elseif unit == self.boss and not unit:IsDead() then
			for area_id in tac_area_ids(areas) do
				if band(self.reached_areas[area_id] or 0, reachedBoss) == 0 then
					self.reached_areas[area_id] = bor(self.reached_areas[area_id] or 0, reachedBoss)
					self:OnAreaReached(area_id, reachedBoss)
				end
			end
		end
	end
end

---
--- Assigns the boss unit to the next area in the specified path.
---
--- If the current area is found in the path, the boss is assigned to the next area in the path. If the current area is not found in the path, the boss is assigned to the nearest area in the path based on the distance to the area markers.
---
--- @param path table A table of area IDs representing the path.
--- @param cur_area string The current area the boss is in.
--- @return nil
function BossfightFaucheaux:AssignToNextArea(path, cur_area)
	local area_idx = table.find(path, cur_area)
	if area_idx then
		-- assign to next area
		local next_area_idx = Min(area_idx + 1, #path)
		local area = path[next_area_idx]
		g_TacticalMap:AssignUnit(self.boss, area, "reset", g_TacticalMap.PriorityHigh)
		if area == "ControlZone_OpenCorridor2" then
			g_TacticalMap:AssignUnit(self.boss, "ControlZone_OpenCorridor1", nil, g_TacticalMap.PriorityMedium)
		end		
		g_TacticalMap:AssignUnit(self.boss, cur_area, nil, g_TacticalMap.PriorityLow)
	else
		-- fallback: assign to the nearest area (dist to marker)
		local area, min_dist
		local markers = MapGetMarkers()
		for _, id in ipairs(path) do
			local idx = table.find(markers, "ID", id)
			if idx and id ~= "Control_Zone_OpenCorridor2" then
				local dist = self.boss:GetDist(markers[idx])
				if dist < (min_dist or dist + 1) then
					area, min_dist = id, dist
				end
			end
		end
		if area then
			g_TacticalMap:AssignUnit(self.boss, area, "reset")
		else
			assert(false, string.format("unable to find fallback area to assign Faucheaux following path %d; current area: %s", self.chosen_path, tostring(cur_area)))
		end
	end	
end

---
--- Updates the unit archetypes based on the current state of the boss fight.
---
--- If the boss is retreating, it sets the archetype of all enemy units to their base archetype, and sets the script archetype of units in areas that have not been released to "GuardArea". The boss's script archetype is set to "Faucheaux_BossRetreating" and it is assigned to the next area in the chosen path.
---
--- If the boss is not retreating, the boss is assigned to the "Control_Zone_FaucheauxCabinet" area.
---
--- @param self BossfightFaucheaux The BossfightFaucheaux instance.
--- @return nil
function BossfightFaucheaux:UpdateUnitArchetypes()
	assert(g_TacticalMap)
	for _, unit in ipairs(g_Units) do
		if unit.team.player_enemy and not unit:IsDead() then
			local def_id = unit.unitdatadef_id or false
			local classdef = g_Classes[def_id]
			local base_archetype = classdef and classdef.archetype
			if self.run_away and unit ~= self.boss then
				local orig_area = self.original_area[unit]
				unit.archetype = base_archetype
				if not self.released_areas[orig_area] then
					unit.scrpit_archetype = "GuardArea"
				else
					unit.scrpit_archetype = nil
				end
			else
				unit.scrpit_archetype = "GuardArea"
			end
		end
	end
	
	-- Faucheaux
	if self.run_away then
		self.boss.scrpit_archetype = "Faucheaux_BossRetreating"	
		
		local cur_area = g_TacticalMap:GetUnitPrimaryArea(self.boss)
		if cur_area == "Control_Zone_FinalDest" then
			g_TacticalMap:AssignUnit(self.boss, "Control_Zone_FinalDest", "reset")
		elseif self.chosen_path == 1 then
			self:AssignToNextArea(path1areas, cur_area)
		else
			self:AssignToNextArea(path2areas, cur_area)
		end
	else
		g_TacticalMap:AssignUnit(self.boss, "Control_Zone_FaucheauxCabinet", "reset")
	end
end

---
--- Handles the turn start logic for the BossfightFaucheaux instance.
---
--- If the boss is retreating and the escape turn has been reached, the boss will escape and the lose sequence will be triggered. The function will wait for the boss escape setpiece to start and end before continuing the rest of the logic.
---
--- If the boss has already escaped, the function will return early.
---
--- The function will find the boss unit from the Faucheux group, and then update the awareness, area progress, and unit archetypes for the encounter.
---
--- @param self BossfightFaucheaux The BossfightFaucheaux instance.
--- @return nil
function BossfightFaucheaux:OnTurnStart()	
	if g_Combat and self.escape_turn and g_Combat.current_turn >= self.escape_turn then
		-- lose sequence
		if not self.escaped then
			self.escaped = true
			-- in a thread so it can wait for the setpiece here
			CreateGameTimeThread(function()
				-- wait the boss escape setpiece to start
				while not IsSetpiecePlaying() do
					WaitMsg("SetpieceStarted", 10)
				end
				
				-- wait the boss escape setpiece to end
				while IsSetpiecePlaying() do
					WaitMsg("SetpieceEnded", 10)
				end
				
				-- run the rest of the logic now
				self:OnTurnStart()
			end)
			return
		end		
	end
	
	if self.escaped then return end
	
	for _, obj in ipairs(Groups.Faucheux) do
		if IsKindOf(obj, "Unit") then
			self.boss = obj
			break
		end
	end
	
	g_Encounter:UpdateAwareness()
	g_Encounter:UpdateAreaProgress()		
	g_Encounter:UpdateUnitArchetypes()	
end