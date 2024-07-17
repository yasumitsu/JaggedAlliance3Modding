MapVar("g_UnitEnemies", {})
MapVar("g_UnitAllEnemies", {})
MapVar("g_UnitAllies", {})

---
--- Checks if two sides are allies.
---
--- @param side1 string The first side to check.
--- @param side2 string The second side to check.
--- @return boolean True if the sides are allies, false otherwise.
---
function SideIsAlly(side1, side2)
	if side1 == "ally" then side1 = "player1" end
	if side2 == "ally" then side2 = "player1" end
	if side1 == "enemyNeutral" then side1 = "enemy1" end
	if side2 == "enemyNeutral" then side2 = "enemy1" end
	return side1 == side2
end

---
--- Checks if two sides are enemies.
---
--- @param side1 string The first side to check.
--- @param side2 string The second side to check.
--- @return boolean True if the sides are enemies, false otherwise.
---
function SideIsEnemy(side1, side2)
	if side1 == "enemyNeutral" and not GameState.Conflict then side1 = "neutral" end
	if side2 == "enemyNeutral" and not GameState.Conflict then side2 = "neutral" end
	return side1 ~= "neutral" and side2 ~= "neutral" and not SideIsAlly(side1, side2)
end

---
--- Checks if the given unit is an enemy of the player.
---
--- @param unit table The unit to check.
--- @return boolean True if the unit is an enemy of the player, false otherwise.
---
function IsPlayerEnemy(unit)
	return unit.team and SideIsEnemy("player1", unit.team.side)
end

local dirty_relations = false  --heh

---
--- Recalculates the diplomacy relations between all teams.
--- This function updates the `g_UnitEnemies`, `g_UnitAllEnemies`, and `g_UnitAllies` global variables
--- based on the current state of the teams and their visibility.
---
--- This function is called when the diplomacy relations need to be recalculated, such as when
--- the `InvalidateDiplomacy()` function is called.
---
--- @return nil
---
function RecalcDiplomacy()
	dirty_relations = false
	local unit_Enemies = {}
	local unit_AllEnemies = {}
	local unit_Allies = {}

	for idx1, team in ipairs(g_Teams) do
		local team_units = team.units
		if #team_units > 0 then
			local team_visibility = g_Visibility[team]
			local team_enemy_mask = team.enemy_mask
			local team_ally_mask = team.ally_mask
			for idx2, team2 in ipairs(g_Teams) do
				local team2_units = team2.units
				if #team2_units > 0 then
					if band(team_enemy_mask, team2.team_mask) ~= 0 then
						-- all the units of the team have the same enemies. we provide them the same tables
						local all_enemies = unit_AllEnemies[team_units[1]]
						if all_enemies then
							table.iappend(all_enemies, team2_units)
						else
							all_enemies = table.icopy(team2_units)
							for i, unit in ipairs(team_units) do
								unit_AllEnemies[unit] = all_enemies
							end
						end
						if team_visibility and #team_visibility > 0 then
							for i, unit in ipairs(team_units) do
								if unit:IsAware() then
									local enemies = unit_Enemies[unit]
									for j, other in ipairs(team2_units) do
										if team_visibility[other] then
											enemies = enemies or {}
											table.insert(enemies, other)
										end
									end
									if enemies and not unit_Enemies[unit] then
										unit_Enemies[unit] = enemies
										for j = i + 1, #team_units do
											local unit2 = team_units[j]
											if unit2:IsAware() then
												unit_Enemies[unit2] = enemies
											end
										end
									end
									break
								end
							end
						end
					elseif band(team_ally_mask, team2.team_mask) ~= 0 then
						for i, unit in ipairs(team_units) do
							local allies = unit_Allies[unit]
							local start_idx = 0
							if allies then
								start_idx = #allies
								table.iappend(allies, team2_units)
							else
								allies = table.icopy(team2_units)
								unit_Allies[unit] = allies
							end
							if team == team2 then
								table.remove(allies, start_idx + i) -- remove unit
							end
						end
					end
				end
			end
		end
	end
	g_UnitEnemies = unit_Enemies
	g_UnitAllEnemies = unit_AllEnemies
	g_UnitAllies = unit_Allies

	Msg("UnitRelationsUpdated")
end

---
--- Invalidates the diplomacy system, forcing a recalculation of unit relationships.
--- This should be called when any changes are made that could affect unit diplomacy, such as
--- changing team alliances or enemy relationships.
---
--- When diplomacy is invalidated, the `DiplomacyInvalidated` message is sent.
---
function InvalidateDiplomacy()
	NetUpdateHash("InvalidateDiplomacy")
	dirty_relations = true
	if g_Combat then 
		g_Combat.visibility_update_hash = false
	end
	Msg("DiplomacyInvalidated")
end

MapVar("g_Diplomacy", {})

local function OnGetRelations()
	if dirty_relations then
		RecalcDiplomacy()
	end
end

---
--- Returns a table of all enemy units for the given unit.
---
--- @param unit table The unit to get enemies for.
--- @return table A table of enemy units.
---
function GetEnemies(unit)
	OnGetRelations()
	return g_UnitEnemies[unit] or empty_table
end

---
--- Returns a table of all enemy units for the given unit.
---
--- @param unit table The unit to get enemies for.
--- @return table A table of enemy units.
---
function GetAllEnemyUnits(unit)
	OnGetRelations()
	return g_UnitAllEnemies[unit] or empty_table
end

---
--- Returns a table of all allied units for the given unit.
---
--- @param unit table The unit to get allies for.
--- @return table A table of allied units.
---
function GetAllAlliedUnits(unit)
	OnGetRelations()
	return g_UnitAllies[unit] or empty_table
end

---
--- Returns the nearest enemy unit to the given unit.
---
--- @param unit table The unit to find the nearest enemy for.
--- @param ignore_awareness boolean If true, ignore the unit's awareness when finding the nearest enemy.
--- @return table,number The nearest enemy unit and the distance to that unit.
---
function GetNearestEnemy(unit, ignore_awareness)
	local enemies = ignore_awareness and GetAllEnemyUnits(unit) or GetEnemies(unit)
	local nearest
	for _, enemy in ipairs(enemies) do
		if not nearest or IsCloser(unit, enemy, nearest) then
			nearest = enemy
		end
	end
	if nearest then
		return nearest, unit:GetDist(nearest)
	end
end

---
--- Updates the team diplomacy information.
---
--- This function updates the ally and enemy masks for each team based on the current game state.
--- It also sets flags indicating whether a team is the player's team, an ally of the player, or an enemy of the player.
--- The function then invalidates the diplomacy information and notifies the selection object that it has been modified.
---
--- @param none
--- @return none
---
function UpdateTeamDiplomacy()
	for i, team in ipairs(g_Teams) do
		team.team_mask = shift(1, i)
	end
	local player_side = NetPlayerSide()
	for _, team in ipairs(g_Teams) do
		team.ally_mask = team.team_mask
		team.enemy_mask = 0
		for _, other in ipairs(g_Teams) do
			if other ~= team then
				if SideIsAlly(team.side, other.side) then
					team.ally_mask = bor(team.ally_mask, other.team_mask)
				end
				if SideIsEnemy(team.side, other.side) then
					team.enemy_mask = bor(team.enemy_mask, other.team_mask)
				end
			end
		end
		
		if Game and Game.game_type == "HotSeat" then
			team.player_team = (team.side == "player1") or (team.side == "player2")
			team.player_ally = SideIsAlly("player1", team.side) or SideIsAlly("player2", team.side)
		else
			team.player_team = team.side == player_side
			team.player_ally = SideIsAlly(player_side, team.side)
		end
		team.player_enemy = SideIsEnemy(player_side, team.side)
		team.neutral = team.side == "neutral"
	end
	InvalidateDiplomacy()
	ObjModified(Selection)
end

OnMsg.ConflictStart = UpdateTeamDiplomacy
OnMsg.ConflictEnd = UpdateTeamDiplomacy

OnMsg.CombatStart = function() NetUpdateHash("CombatStart"); InvalidateDiplomacy() end
OnMsg.UnitSideChanged = function() NetUpdateHash("UnitSideChanged"); InvalidateDiplomacy() end
OnMsg.UnitDied = function() NetUpdateHash("UnitDied"); InvalidateDiplomacy() end
OnMsg.UnitDespawned = function(unit)
	NetUpdateHash("UnitDespawned"); 
	InvalidateDiplomacy() 
end
OnMsg.VillainDefeated = function() NetUpdateHash("VillainDefeated"); InvalidateDiplomacy() end
OnMsg.UnitAwarenessChanged = function() NetUpdateHash("UnitAwarenessChanged"); InvalidateDiplomacy() end
OnMsg.UnitStealthChanged = function() NetUpdateHash("UnitStealthChanged"); InvalidateDiplomacy() end

--- @brief Synchronizes the team diplomacy state across the network.
---
--- This function is called by the `NetSyncEvents` table to update the team diplomacy state
--- when a network sync event occurs. It simply calls the `UpdateTeamDiplomacy()` function
--- to perform the actual diplomacy update.
function NetSyncEvents.UpdateTeamDiplomacy()
	UpdateTeamDiplomacy()
end

--- @brief Synchronizes the team diplomacy state across the network.
---
--- This function is called by the `NetSyncEvents` table to update the team diplomacy state
--- when a network sync event occurs. It simply calls the `InvalidateDiplomacy()` function
--- to perform the actual diplomacy update.
function NetSyncEvents.InvalidateDiplomacy()
	InvalidateDiplomacy()
end

function OnMsg.TeamsUpdated()
	if IsRealTimeThread() then
		DelayedCall(0, FireNetSyncEventOnHost, "UpdateTeamDiplomacy")
	else
		UpdateTeamDiplomacy()
	end
end

function OnMsg.EnterSector(game_start, load_game)
	FireNetSyncEventOnHost("InvalidateDiplomacy")
end