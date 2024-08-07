if FirstLoad then
	g_Units = {}
	g_Teams = {}
	g_CurrentTeam = false
	g_CurrentSquad = false
end

---
--- Resets the global state variables related to the Zulu tactical system.
---
--- This function is called when the map is changed or a new game is started.
---
--- It closes the in-game interface, if it exists, and resets the following global variables:
--- - `g_Units`: a table containing all the units in the game
--- - `g_Teams`: a table containing all the teams in the game
--- - `g_CurrentTeam`: the currently selected team
--- - `g_CurrentSquad`: the currently selected squad
---
--- After resetting these variables, the function sends a "CurrentSquadChanged" message.
---
function ResetZuluStateGlobals()
	local igi = GetInGameInterface()
	if igi then igi:Close() end
	
	g_Units = {}
	g_Teams = {}
	g_CurrentTeam = false
	g_CurrentSquad = false
	Msg("CurrentSquadChanged")
end

OnMsg.ChangeMap = ResetZuluStateGlobals
OnMsg.NewGame = ResetZuluStateGlobals
OnMsg.NewGameSessionStart = ResetZuluStateGlobals

if FirstLoad then
	SideDefs = false
	Sides = false
end

DefineClass.CampaignSide = {
	__parents = { "PropertyObject", },
	properties = {
		{ id = "Id", editor = "text", default = false, },
		{ id = "DisplayName", name = "Display Name", editor = "text", default = false, translate = true, },
		{ id = "Player", editor = "bool", default = false, },
		{ id = "Enemy", editor = "bool", default = false, },
	},
}

function OnMsg.ClassesBuilt()
	SideDefs = {
		CampaignSide:new{ Id = "neutral",      DisplayName = T(521973101724, "Neutral") },
		CampaignSide:new{ Id = "player1",      DisplayName = T(222892508302, "Player 1"), Player = true },
		CampaignSide:new{ Id = "player2",      DisplayName = T(942355779355, "Player 2"), Player = true },
		CampaignSide:new{ Id = "enemy1",       DisplayName = T(692913892455, "Enemy 1"), Enemy = true },
		CampaignSide:new{ Id = "enemy2",       DisplayName = T(456135028453, "Enemy 2"), Enemy = true },
		CampaignSide:new{ Id = "enemyNeutral", DisplayName = T(607169506860, "Enemy Neutral"), },
		CampaignSide:new{ Id = "ally",         DisplayName = T(346100175449, "Ally"), },
	}
	Sides = table.map(SideDefs, "Id")
end

--- SetupDummyTeams()
---
--- Creates a table of dummy teams for each campaign side, ensuring that there is a team for every side defined in SideDefs.
--- If a team for a side already exists in g_Teams, it is reused. Otherwise, a new CombatTeam is created and added to g_Teams.
--- The returned side_to_team table maps each side ID to its corresponding CombatTeam.
---
--- @return table side_to_team A table mapping each side ID to its corresponding CombatTeam
function SetupDummyTeams()
	if not g_Teams then g_Teams = {} end

	local side_to_team = {}
	for _, side in ipairs(SideDefs) do
		local team = table.find_value(g_Teams, "side", side.Id)
		if not team then
			team = CombatTeam:new {
				side = side.Id,
				control = (side.Id == "player1" or side.Id == "player2") and "UI" or "AI",
				team_color = (side.Id == "player1" or side.Id == "player2") and RGB(0, 0, 200) or RGB(200, 0, 0),
			}
			g_Teams[#g_Teams+1] = team
		end
		team.units = {}
		side_to_team[team.side] = team
	end
	
	return side_to_team
end

local function filter_unit(u)
	return IsValid(u) and (not u.team or #u.team.units == 0 or not u.team:IsDefeated()) 
end

---
--- Sets up teams from the map data, creating a team for each campaign side.
--- This function ensures that there is a team for every side defined in SideDefs.
--- If a team for a side already exists in g_Teams, it is reused. Otherwise, a new CombatTeam is created and added to g_Teams.
--- The function also assigns units to their respective teams, and handles wounded units in player teams.
---
--- @param reset_teams boolean Whether to reset the teams before setting them up
--- @return nil
function SetupTeamsFromMap(reset_teams)
	local units = MapGet("map", "Unit", filter_unit) or {}
	local detached_units = MapGet("detached", "Unit", filter_unit) or {}
	g_Units = table.union(units, detached_units)
	
	-- Create a team for all campaign sides - you don't know who's gonna show up :)
	local side_to_team = SetupDummyTeams()
	
	SuppressTeamUpdate = true
	for _, unit in ipairs(units) do
		if CheckUniqueSessionId(unit) then
			g_Units[unit.session_id] = unit
		end
		local side = unit:GetSide(reset_teams)
		local team = side_to_team[side]
		table.insert_unique(team.units, unit)
		unit:SetTeam(team)
	end
	for _, unit in ipairs(g_Units) do
		if not unit.team then
			unit:SetTeam(side_to_team.neutral)
		end
	end
	
	-- for player teams only: check for wounded units and start on -1 morale if there are any
	for _, team in ipairs(g_Teams) do
		if team.player_team then
			local wounded
			for _, unit in ipairs(team.units) do
				wounded = wounded or unit:HasStatusEffect("Wounded")
			end
			if wounded then 
				team.morale = -1
			end
		end
	end
	
	-- Is this ever used? Seems like no.
	for i, u in ipairs(g_Units) do
		assert(not u.Group)
	end
	
	SuppressTeamUpdate = false
	Msg("TeamsUpdated")
end

---
--- Sends a unit to a specified team.
---
--- @param unit Unit The unit to be sent to the team.
--- @param team Team The team to which the unit will be sent.
---
function SendUnitToTeam(unit, team)
	local hasTeam = not not unit.team

	assert(team)
	if hasTeam then
		table.remove_value(unit.team.units, unit)
	end	
	table.insert(team.units, unit)
	unit:SetTeam(team)
	AddToGlobalUnits(unit)	
	Msg("UnitSideChanged", unit, team)
end

function OnMsg.ChangeMapDone(map)
	if map ~= "" and mapdata.GameLogic then
		g_Units = MapGet("map", "Unit") or {}
	end
end

function OnMsg.CloseSatelliteView()
	EnsureCurrentSquad()
	ObjModified("hud_squads")
	
	local team = GetCurrentTeam()
	if team then
		for i, u in ipairs(team.units or empty_table) do
			ObjModified(u)
		end
	end
end

-- 1. Ensures that there is a currently selected unit
-- 2. Ensures that the currently selected squad is correct (squad of selected units)

-- Cases in which there might not be a selected unit:
-- 1. Selected units left the sector
-- 2. Squad was destroyed
---
--- Ensures that the currently selected squad is correct (squad of selected units).
---
--- This function handles the following cases:
--- - If there are no selected units, it sets the current squad to the squad of the first unit in the current team.
--- - If the selected units are not all from the same squad, it sets the current squad to the squad with the most selected units.
--- - If the current selection is fine (all units are from the same squad), it does nothing.
---
--- @return Unit|nil The first unit in the current team, or nil if there are no units in the current team.
---
function EnsureCurrentSquad()
	if #(Selection or "") == 0 then
		local squadsOnMap, team = GetSquadsOnMap()
		local selectedSquadIdx = table.find(squadsOnMap, g_CurrentSquad)
		
		if not selectedSquadIdx and team then
			ResetCurrentSquad(team)
			selectedSquadIdx = table.find(squadsOnMap, g_CurrentSquad)
		end
		
		if selectedSquadIdx then -- first try to select a unit from the current squad
			for _, unit in ipairs(g_Units) do
				if unit.Squad == g_CurrentSquad and not unit:IsDead() and not unit:IsDowned() and unit:IsLocalPlayerControlled() then
					SuppressNextSelectionChangeVR = true
					DelayedCall(0, SelectObj, unit) -- this will trigger selection logic which will bring us back here
					return
				end
			end
		end
	else	
		-- check if current selection is fine first (only unit selection changed or w/e)
		local allFromSelectedSquad = true
		for i, u in ipairs(Selection) do
			if u.Squad ~= g_CurrentSquad then
				allFromSelectedSquad = false
				break
			end
		end
		if allFromSelectedSquad then return end
		
		-- Set g_CurrentSquad to be the squad with the most units selected.
		local unitsPerSquad = {}
		for i, u in ipairs(Selection) do
			local squad = u:GetSatelliteSquad()
			if squad then
				unitsPerSquad[squad.UniqueId] = (unitsPerSquad[squad.UniqueId] or 0) + 1
			end
		end
	
		local maxCount, maxCountId = 0, 0
		for sqId, unitCount in pairs(unitsPerSquad) do
			if unitCount > maxCount then
				maxCount = unitCount
				maxCountId = sqId
			end
		end
		
		if g_CurrentSquad == maxCountId then return end
		
		g_CurrentSquad = maxCountId
		Msg("CurrentSquadChanged")
	end
end

---
--- Resets the current squad to the first unit in the given team.
---
--- @param currentTeam table The current team.
--- @return Unit|nil The first unit in the team, or nil if no units are selected.
function ResetCurrentSquad(currentTeam)
	local firstUnit
	if Selection and #Selection > 0 then
		firstUnit = Selection[1]
	else
		firstUnit = currentTeam.units[1]
	end
	local squad = firstUnit and firstUnit:GetSatelliteSquad()
	g_CurrentSquad = squad and squad.UniqueId or false
	Msg("CurrentSquadChanged")
	return firstUnit
end

---
--- Checks if the given unit has a unique session ID.
---
--- If another unit with the same session ID already exists, this function will assert and return false.
---
--- @param unit Unit The unit to check.
--- @return boolean True if the unit has a unique session ID, false otherwise.
---
function CheckUniqueSessionId(unit)
	local session_id = unit.session_id
	local same_id_unit = g_Units[session_id] and g_Units[session_id] ~= unit
	if same_id_unit then
		assert(false, string.format("Two units with the same session_id %s?", session_id))
		return false
	end
	return true
end

---
--- Adds a unit to the global units table, ensuring the unit has a unique session ID.
---
--- @param unit Unit The unit to add to the global units table.
--- @return boolean True if the unit was added successfully, false otherwise.
function AddToGlobalUnits(unit)
	if not CheckUniqueSessionId(unit) then
		return
	end
	table.insert_unique(g_Units, unit)
	g_Units[unit.session_id] = unit
end

---
--- Returns all the units that belong to the player's team.
---
--- @return table|nil The units of the player's team, or nil if no player team is found.
function GetAllPlayerUnitsOnMap()
	local team = table.find_value(g_Teams, "side", "player1")
	return team and team.units
end

---
--- Returns a table of session IDs for all units belonging to the player's team.
---
--- @return table The session IDs of all player units on the map.
---
function GetAllPlayerUnitsOnMapSessionId()
	local units = GetAllPlayerUnitsOnMap()
	return table.map(units, "session_id")
end

---
--- Returns the current team.
---
--- @return table|nil The current team, or nil if no team is found.
---
function GetCurrentTeam()
	return GetPoVTeam()
end

---
--- Returns the current team based on the current game state.
---
--- If the game is in combat mode, the current team can be an enemy team, so this function
--- returns the first allied team instead.
---
--- If there is no current selection, this function returns the player's team.
--- If the current selection is a unit, this function returns the unit's team.
---
--- @return table|nil The current team, or nil if no team is found.
---
function GetPoVTeam()
	if g_Combat then
		-- The current team can be an enemy team, return the first allied team instead.
		local active_team = g_Teams[g_CurrentTeam or 1]
		if active_team and (active_team.control ~= "UI" or not active_team.player_ally) then
			for _, team in ipairs(g_Teams) do
				if team.control == "UI" and team.player_ally then
					return team
				end
			end
		end
		return active_team
	end
	
	if not Selection or #Selection == 0 then
		for _, team in ipairs(g_Teams) do
			if team.side == "player1" then
				return team
			end
		end
	elseif IsKindOf(Selection[1], "Unit") then
		return Selection[1].team
	end
end



---
--- Checks if the entire current team is selected.
---
--- This function checks if all units in the current team that are controlled by the local player are selected.
--- It returns false if the game is in combat mode, as there is no multiselect allowed in that case.
---
--- @return boolean true if the entire current team is selected, false otherwise
---
function WholeTeamSelected()
	if g_Combat then return false end -- No multiselect
	local team = GetFilteredCurrentTeam()
	
	local unitsCanControl = {}
	for i, u in ipairs(team and team.units) do
		if u:IsLocalPlayerControlled() then
			unitsCanControl[#unitsCanControl + 1] = u
		end
	end
	
	if #unitsCanControl ~= #Selection then return false end
	for i, s in ipairs(Selection) do
		if not table.find(unitsCanControl, s) then
			return false
		end
	end
	return true
end

---
--- Retrieves the current team, optionally filtered by the current squad.
---
--- If a `team` parameter is provided, it will be used as the current team. Otherwise, the current team is retrieved using `GetCurrentTeam()`.
---
--- If there is a current squad filter, the returned team will be a filtered version containing only the units that are part of the current squad. The filtered team will have the following properties:
--- - `DisplayName`: The name of the current squad
--- - `side`: The side of the current squad
--- - `control`: The control of the original team
--- - `units`: The units that are part of the current squad
---
--- If the current squad has no valid units, the original team is returned.
---
--- @param team table|nil The team to filter, or nil to use the current team
--- @return table The filtered current team
---
function GetFilteredCurrentTeam(team)
	team = team or GetCurrentTeam()

	-- If there is a current squad filter units from it only.
	if team and team.units and g_CurrentSquad then
		local teamFiltered = {
			DisplayName = false,
			side = false,
			control = team.control
		}
		
		local units = {}
		local squad = gv_Squads[g_CurrentSquad]
		if not squad then 
			ResetCurrentSquad(team)
			squad = gv_Squads[g_CurrentSquad]
			if not squad then return team end
		end
		
		teamFiltered.DisplayName = Untranslated(squad.Name)
		teamFiltered.side = squad.Side

		for i, u in ipairs(squad.units) do
			local unit = g_Units[u]
			if IsValid(unit) then --and not unit:IsDead() then
				units[#units + 1] = unit
			end
		end
		
		if #units == 0 then
			ResetCurrentSquad(team)
			return team
		end
	
		teamFiltered.units = units
		team = teamFiltered
	end
	
	return team
end

--- Returns a list of units that are part of the specified squad.
---
--- @param squadId string The ID of the squad to get the units for.
--- @return table The list of units in the specified squad.
function GetMapUnitsInSquad(squadId)
	local squad = gv_Squads[squadId]
	if not squad then return {} end
	
	local units = {}
	for i, u in ipairs(squad.units) do
		local unitOnMap = g_Units[u]
		if unitOnMap then
			units[#units + 1] = unitOnMap
		end
	end
	return units
end

--- Returns the campaign player team.
---
--- This function returns the team object for the player's team in a campaign game. It checks if the game is a hot seat or competitive game, and if so, returns nothing. Otherwise, it iterates through the list of teams and returns the team with a side of "player1".
---
--- @return table|nil The player's team, or nil if the game is a hot seat or competitive game.
function GetCampaignPlayerTeam()
	if IsHotSeatGame() or IsCompetitiveGame() then return end

	for i, team in ipairs(g_Teams) do
		if team.side == "player1" then
			return team
		end
	end
end