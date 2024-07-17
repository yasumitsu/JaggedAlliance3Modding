local function lUpdateSquadCurrentSector(squad, old_sector, new_sector, from_map)
	if old_sector == new_sector then return end
	local dir = gv_DeploymentDir
	gv_DeploymentDir = false
	
	local comingFromUnderground = IsSectorUnderground(old_sector)
	local goingToUnderground = IsSectorUnderground(new_sector)
	
	-- If coming from and moving to an underground sector, we are moving underground.
	if comingFromUnderground and goingToUnderground then
		comingFromUnderground = false
		goingToUnderground = false
	end
	
	if not dir and old_sector then
		if comingFromUnderground then
			dir = "Underground"
		else
			local old_y, old_x = sector_unpack(old_sector)
			local new_y, new_x = sector_unpack(new_sector)
			if old_x < new_x then
				dir = "West"
			elseif old_x > new_x then
				dir = "East"
			elseif old_y < new_y then
				dir = "North"
			elseif old_y > new_y then
				dir = "South"
			end
		end
	end
	if not dir and new_sector and goingToUnderground then
		dir = "Underground"
	end
	for _, session_id in ipairs(squad.units) do
		local merc = gv_UnitData[session_id]
		merc.arrival_dir = dir or "North"
		merc.already_spawned_on_map = false
		merc.retreat_to_sector = false
	end
	if #GetSectorSquadsFromSide(gv_CurrentSectorId, "player1") == 0 then -- all squads left current sector, reload map if someone returns and then close satellite view
		ForceReloadSectorMap = true -- if a squad returns to the map and the satellite is closed without map reload, we need to reload exploration
		ObjModified(Game)
		Msg("AllSquadsLeftSector")
	end
end

---
--- Returns the player and enemy squads that should be spawned in the given sector for tactical combat.
---
--- @param sector_id string The ID of the sector to get the squads for.
--- @return table, table The player squads and enemy squads to spawn.
---
function GetSectorSquadsToSpawnInTactical(sector_id)
	return GetSquadsInSector(sector_id, "exclude_travelling", "include_militia", "exclude_arriving")
end

---
--- Checks the presence of units on the map and respawns squads if necessary.
---
--- This function is responsible for ensuring that the units in each squad are properly
--- represented on the map. It checks if a squad is present in the current sector and
--- if its units have already been spawned. If a squad is present but its units have
--- not been spawned, it respawns the squad. If a squad is not present, it removes
--- the units from the map.
---
--- The function also removes any released mercs or units that are no longer in a squad.
--- Finally, it updates the team setup and ensures the current squad is properly set.
---
--- @return nil
function LocalCheckUnitsMapPresence()
	if not gv_Squads then return end
	local update_map
	local respawn_squads
	for i, squad in ipairs(g_SquadsArray) do
		local squadSector = squad.CurrentSector
		local squadPresent = squadSector == gv_CurrentSectorId and not IsSquadTravelling(squad)
		for _, session_id in ipairs(squad.units) do
			local unit = g_Units[session_id]
			local ud = gv_UnitData[session_id]
		
			if not squadPresent and unit then
				DoneObject(unit)
				update_map = true
			elseif squadPresent and not (unit and ud.already_spawned_on_map) then
				respawn_squads = true
				update_map = true
			end
		end
	end
	
	if respawn_squads then
		MapForEachMarker("GridMarker", nil, function(marker)
			marker:RecalcAreaPositions()
		end)
		UpdateEntranceAreasVisibility()
	
		local conflict = GetSectorConflict()
		local player, enemy = GetSectorSquadsToSpawnInTactical(gv_CurrentSectorId)
		local squads = player
		table.iappend(squads, enemy)
		SpawnSquads(table.map(squads, "UniqueId"), conflict and conflict.spawn_mode or "explore")
	end
	
	-- remove released mercs or units who are no longer in a squad (like deleted enemy units from ModifySectorEnemySquads)
	for i = #g_Units, 1, -1 do
		local unit = g_Units[i]
		if (unit:IsMerc() and not unit.Squad) or not unit.session_id then
			DoneObject(unit)
			update_map = true
		end
	end
	if update_map then
		SetupTeamsFromMap()
		EnsureCurrentSquad()
	end
	ForceUpdateCommonUnitControlUI()
end

--- Synchronizes the presence of units on the map with the current squad information.
---
--- This function is called by the `NetSyncEvents.CheckUnitsMapPresence()` function to ensure that the units in the game world match the current state of the squads. It handles spawning and despawning units as needed based on the squad's current sector and travel status.
---
--- @return nil
function NetSyncEvents.CheckUnitsMapPresence()
	LocalCheckUnitsMapPresence()
end

---
--- Teleports a satellite squad to the specified sector.
---
--- @param squad_id string The unique ID of the squad to teleport.
--- @param sector_id string The ID of the sector to teleport the squad to.
---
function NetSyncEvents.CheatSatelliteTeleportSquad(squad_id, sector_id)
	local squad = gv_Squads[squad_id]
	if sector_id == squad.CurrentSector then return end
	
	local sector = gv_Sectors[sector_id]
	local squadWnd = g_SatelliteUI.squad_to_wnd[squad_id]
	if not squadWnd then return end
	local prev_sector_id = GetSquadPrevSector(squadWnd:GetVisualPos(), sector_id, sector.XMapPosition)
	local curr_sector = gv_Sectors[squad.CurrentSector]
	if curr_sector.conflict then
		ResolveConflict(curr_sector)
	end
	-- reset operation
	SectorOperation_CancelByGame(squad.units, false, true)
	
	-- Ensure previous sector is valid
	if IsTravelBlocked(sector_id, prev_sector_id) then
		ForEachSectorCardinal(sector_id, function(s)
			if not IsTravelBlocked(sector_id, s) then
				prev_sector_id = s
				return "break"
			end
		end)
	end
	
	SetSatelliteSquadCurrentSector(squad, sector_id, nil, "teleport", prev_sector_id)
	if not gv_Sectors[sector_id].reveal_allowed then -- Teleported to unrevealed sector.
		print("You teleported to an unrevealed sector. Use the 'Reveal All Sectors' cheat or you won't see your squad.")
	end
	
	squad.Retreat = false
	squad:CancelTravel()
	ObjModified("gv_SatelliteView")
	ObjModified(gv_Squads)
end

---
--- Checks if a squad has reached its destination.
---
--- @param squad table The squad to check.
--- @return boolean True if the squad has reached its destination, false otherwise.
function SquadReachedDest(squad)
	return not squad.route or #squad.route == 1 and squad.route[1][1] == squad.CurrentSector
end

---
--- Starts a shortcut movement for a satellite squad.
---
--- @param squad_id string The unique ID of the squad to start the shortcut movement.
--- @param startTime number The start time of the shortcut movement.
--- @param startSector string The ID of the sector where the shortcut movement starts.
---
function NetSyncEvents.SatelliteStartShortcutMovement(squad_id, startTime, startSector)
	SatelliteStartShortcutMovement(squad_id, startTime, startSector)
end

---
--- Starts a shortcut movement for a satellite squad.
---
--- @param squad_id string The unique ID of the squad to start the shortcut movement.
--- @param startTime number The start time of the shortcut movement.
--- @param startSector string The ID of the sector where the shortcut movement starts.
---
function SatelliteStartShortcutMovement(squad_id, startTime, startSector)
	local squad = gv_Squads[squad_id]
	squad.traversing_shortcut_start = startTime
	squad.traversing_shortcut_start_sId = startSector
	RecalcRevealedSectors()
	Msg("SquadStartTraversingShortcut", squad)
end

---
--- Handles the event when a satellite squad reaches a sector.
---
--- @param squad_id string The unique ID of the satellite squad that reached the sector.
--- @param sector_id string The ID of the sector that the satellite squad reached.
--- @param ... any Additional parameters passed with the event.
---
function NetSyncEvents.SatelliteReachSector(squad_id, sector_id, ...)
	local squad = gv_Squads[squad_id]
	SetSatelliteSquadCurrentSector(squad, sector_id, ...)
end

---
--- Sets the side of a satellite squad.
---
--- @param unique_id string The unique ID of the satellite squad.
--- @param side string The side to set for the satellite squad.
---
function SetSatelliteSquadSide(unique_id, side)
	local squad = unique_id and gv_Squads[unique_id]
	if squad then
		squad.Side = side
		RemoveSquadsFromLists(squad)
		AddSquadToLists(squad)
	end
	ObjModified(squad)
end

---
--- Checks if a given sector is a water sector.
---
--- @param sector table|string The sector to check. Can be a table representing the sector, or a string with the sector ID.
--- @return boolean True if the sector is a water sector, false otherwise.
---
function IsWaterSector(sector)
	if type(sector) == "string" then
		sector = gv_Sectors[sector]
	end

	return sector and sector.Passability == "Water"
end

---
--- Sets the current sector for a satellite squad.
---
--- @param squad table The satellite squad.
--- @param sector_id string The ID of the sector the squad has reached.
--- @param update_pos boolean Whether to update the squad's visual position.
--- @param teleport boolean Whether the squad has teleported to the sector.
--- @param prev_sector_id string The ID of the previous sector the squad was in.
---
function SetSatelliteSquadCurrentSector(squad, sector_id, update_pos, teleport, prev_sector_id)
	RemoveSquadFromSectorList(squad, squad.CurrentSector)
	AddSquadToSectorList(squad, sector_id)

	prev_sector_id = prev_sector_id or squad.CurrentSector
	squad.arrive_in_sector = false
	squad.PreviousSector = prev_sector_id
	squad.CurrentSector = sector_id
	local prev_sector = gv_Sectors[prev_sector_id]
	local sector = gv_Sectors[sector_id]
	
	if teleport then
		squad.returning_water_travel = false
		squad.water_route = false
		SetSquadWaterTravel(squad, false)
		squad.route = false
		squad.uninterruptable_travel = false
	else
		local previousSectorIsWater = IsWaterSector(prev_sector)
		local currentSectorIsWater = IsWaterSector(sector)
		
		if not previousSectorIsWater and prev_sector_id then
			squad.PreviousLandSector = prev_sector_id
		end
		
		-- If not retreating then add all previous sectors in the water route property.
		if not squad.returning_water_travel then
			if not previousSectorIsWater and currentSectorIsWater then
				squad.water_route = { prev_sector_id }
			end
			
			if previousSectorIsWater then
				if not currentSectorIsWater then
					squad.water_route = false
				elseif squad.water_route then
					table.insert(squad.water_route, prev_sector_id)
				end
			end
		end
		
		-- If not travelling over water, reset trackers.
		if not currentSectorIsWater and (not prev_sector or previousSectorIsWater) then
			squad.returning_water_travel = false
			squad.water_route = false
		end
	end
	
	Msg("SquadSectorChanged", squad)
	lUpdateSquadCurrentSector(squad, prev_sector_id, sector_id)
	
	if update_pos then
		squad.XVisualPos = sector.XMapPosition
	end
	
	local wasShortcut = false
	if squad.traversing_shortcut_start then
		wasShortcut = true
	end
	
	if teleport then
		squad.traversing_shortcut_start_sId = false
		squad.traversing_shortcut_start = false
		SatelliteReachSectorCenter(squad.UniqueId, sector_id, prev_sector_id)
		Msg("SquadTeleported", squad)
	else
		-- check for conflict
		CheckAndEnterConflict(sector, squad, wasShortcut and squad.CurrentSector or prev_sector_id)
	end
	
	if wasShortcut then
		squad.traversing_shortcut_start = false
		squad.traversing_shortcut_start_sId = false
		squad.traversing_shortcut_water = false
	end
	
	-- Optimization
	-- Only update sector visuals when enemies move (as they can move out of the visible area)
	-- and when the previous or current sector has an underground sector (as it could be toggled)
	if not g_SatelliteUI then return end
	if squad.Side ~= "player1" or gv_Sectors[sector_id .. "_Underground"] or gv_Sectors[prev_sector_id .. "_Underground"] then
		g_SatelliteUI:UpdateSectorVisuals(prev_sector_id)
		g_SatelliteUI:UpdateSectorVisuals(sector_id)
	end
	
	if wasShortcut then
		RecalcRevealedSectors()
		
		local squad_id = squad.UniqueId
		local squadWnd = g_SatelliteUI.squad_to_wnd[squad_id]
		if squadWnd then
			local endSector = gv_Sectors[sector_id]
			local endSectorPos = endSector.XMapPosition
			squadWnd:SetPos(endSectorPos:x(), endSectorPos:y())
		end
	end
	
	ObjModified(gv_Squads)
	ObjModified(squad)
	ObjModified(gv_Sectors[sector_id])
end

---
--- Reaches the center of a sector in the satellite view.
---
--- @param squad_id string The unique ID of the squad.
--- @param sector_id string The ID of the sector the squad has reached.
--- @param prev_sector_id string The ID of the previous sector the squad was in.
--- @param dontUpdateRoute boolean (optional) If true, the route will not be updated.
--- @param dontCheckConflict boolean (optional) If true, conflict checking will be skipped.
--- @param reason string (optional) The reason for reaching the sector center.
---
function SatelliteReachSectorCenter(squad_id, sector_id, prev_sector_id, dontUpdateRoute, dontCheckConflict, reason)
	NetUpdateHash("SatelliteReachSectorCenter", squad_id, sector_id, prev_sector_id, dontUpdateRoute, dontCheckConflict)
	local squad = gv_Squads[squad_id]
	local route = squad.route
	local player_squad = squad.Side == "player1" or squad.Side == "player2"

	-- Delete route step
	local vrUnit, returningLandTravel = false, false
	if route and route[1] and not dontUpdateRoute then
		local thisSection = route[1]
		returningLandTravel = thisSection.returning_land_travel
		table.remove(thisSection, 1)

		-- Correct shortcut indices
		if thisSection.shortcuts then
			local shortcutsCorrected = {}
			for i, _ in pairs(thisSection.shortcuts) do
				local newIndex = i - 1
				if newIndex >= 1 then
					shortcutsCorrected[i - 1] = true
				end
			end
			thisSection.shortcuts = shortcutsCorrected
		end
		
		if not gv_Squads[squad_id] then return end -- Squad despawned.
		
		-- Reached end of route section
		if route[1] and #route[1] == 0 then
			table.remove(route, 1)
			local reached = #route == 0 -- reached final destination
			
			if reached and player_squad then
				squad.uninterruptable_travel = false
				squad.Retreat = false
				CombatLog("important", T{801526980739, "<SquadName> has reached <SectorId(sector)>", SquadName = Untranslated(squad.Name), sector = squad.CurrentSector})
				ObjModified("gv_SatelliteView")
				Msg("PlayerSquadReachedDestination", squad_id)
				
				if GetAccountStorageOptionValue("AutoPauseDestReached") then
					SetCampaignSpeed(0, "UI")
				end
			end

			if reached then
				squad.route = false
				Msg("SquadFinishedTraveling", squad)
				
				-- Dynamic DB squads despawn once they reach the destination
				if route.despawn_at_last_sector then
					squad.despawn_on_next_tick = true
				end
			end
		end
	elseif route and route.center_old_movement then
		local visualPos = GetSquadVisualPos(squad)
		assert(visualPos == gv_Sectors[sector_id].XMapPosition)
		route.center_old_movement = false
	end
	
	local nextSector = route and route[1]
	nextSector = nextSector and nextSector[1][1]
	local nextSectorIsWater = nextSector and gv_Sectors[nextSector].Passability == "Water"
	local currentSectorIsWater = gv_Sectors[sector_id].Passability == "Water"
	SetSquadWaterTravel(squad, nextSectorIsWater or currentSectorIsWater)
	
	-- sector event when a player squad reaches the sector center in satellite
	if player_squad then
		ExecuteSectorEvents("SE_OnSquadReachSectorCenter", sector_id)
	end
	NetUpdateHash("SatelliteReachSectorCenter_FireMessage", squad_id, sector_id)
	Msg("ReachSectorCenter", squad_id, sector_id, prev_sector_id)
	
	-- Check if joining a squad, or any squad wants to join this one
	if player_squad then
		if squad.joining_squad then
			-- Don't process further if squad joined another.
			if UpdateJoiningSquad(squad) then
				Msg("SquadStoppedTravelling", squad)
				return
			end
		else
			-- Loop in reverse as joining squads will remove items
			for i = #g_PlayerSquads, 1, -1 do
				local s = g_PlayerSquads[i]
				if s.joining_squad == squad.UniqueId and s.CurrentSector == squad.CurrentSector then
					UpdateJoiningSquad(s)
				end
			end
		end
	end
	
	if dontCheckConflict then return end
	local sector = gv_Sectors[sector_id]
	if IsEnemySquad(squad_id) and (sector.Side == "enemy1" or sector.Side == "enemy2") then
		return
	end
	
	-- check for conflict
	local conflictSide = CheckAndEnterConflict(sector, squad, prev_sector_id)
	-- check for forced conflict
	if sector.ForceConflict and player_squad and not squad.Retreat and not sector.conflict then
		EnterConflict(sector, prev_sector_id, conflictSide) -- should this be "locked" = sector.ForceConflict?
	end
	
	vrUnit = player_squad and (squad.units[AsyncRand(#squad.units) + 1] or squad.units[1])
	local isPrevSectorU = gv_Sectors[prev_sector_id] and gv_Sectors[prev_sector_id].GroundSector 
	-- Play VR
	if vrUnit and not sector.conflict and not returningLandTravel and (not reason or reason ~= "squad_split") then
		local unit = vrUnit
		if sector.InterestingSector and not sector.player_visited then
			PlayVoiceResponse(unit, "InterestingSector")
		elseif (not route or #route == 0) and not isPrevSectorU then
			PlayVoiceResponse(unit, "SectorArrived")
		elseif IsSquadTravelling(squad) then
			PlayVoiceResponse(unit, "Travelling")
		end
	end
	
	if player_squad then
		gv_Sectors[sector_id].player_visited = true
	end
	
	-- change side
	-- shield retreat as it can cause a recentering and we don't take over a sector while retreating from it
	local sideChanged = false
	if not sector.conflict and not squad.militia and not squad.Retreat then
		sideChanged = SatelliteSectorSetSide(sector_id, squad.Side)
	end

	if player_squad or sector.Guardpost then
		RecalcRevealedSectors()
	elseif sideChanged and g_SatelliteUI then
		g_SatelliteUI:UpdateSectorVisuals(sector_id)
	end
	if SquadCantMove(squad) then
		CreateGameTimeThread(function()
			--this will kill curr thread
			Msg("SquadStoppedTravelling", squad)
		end)
	end
end

---
--- Calculates the total travel time and breakdown for a given route.
---
--- @param start string The starting sector ID.
--- @param route table A table of waypoints, where each waypoint is a table of sector IDs.
--- @param squad table The squad object.
--- @return number The total travel time.
--- @return table A table of travel time breakdowns for each sector in the route.
function GetTotalRouteTravelTime(start, route, squad)
	if not start or not route then return 0, {} end

	local units = squad.units
	local side = squad.Side
	
	local previous = start
	local time = 0;
	local breakdown = false
	for i, w in ipairs(route) do
		for ii, s in ipairs(w) do
			if previous then
				local nextTravel, _, __, b = GetSectorTravelTime(previous, s, route, units, nil, nil, side)
				if b and #b > 0 then
					breakdown = b -- The breakdown for all sectors along the route should be the same if they're of the same terrain type.
				end
				if nextTravel then
					time = time + Max(nextTravel, lMinVisualTravelTime * 2)
				end
			end
			previous = s
		end
	end
	
	-- Subtract the time the squad has already crossed.
	-- This can occur when changing routes mid travel (such as cancelling).
	if not IsTraversingShortcut(squad) then
		local currentSectorId = squad.CurrentSector
		local currentSector = currentSectorId and gv_Sectors[currentSectorId]
		local targetPos = currentSector and currentSector.XMapPosition
		local visualPos = targetPos and GetSquadVisualPos(squad)
		local previousSectorId = visualPos and currentSectorId and targetPos and 
										GetSquadPrevSector(visualPos, currentSectorId, targetPos)
		
		local timeFirstSector = previousSectorId and
			GetSectorTravelTime(previousSectorId, currentSectorId, false, squad.units, nil, nil, squad.Side)
		if timeFirstSector then
			local prevPos = gv_Sectors[previousSectorId].XMapPosition
			local _, __, timeLeft = GetContinueInterpolationParams(
											prevPos:x(),
											prevPos:y(),
											targetPos:x(),
											targetPos:y(),
											timeFirstSector,
											visualPos)
			if timeLeft then
				local routeTimeCovered = time - timeLeft
				routeTimeCovered = DivCeil(routeTimeCovered, const.Scale.min) * const.Scale.min
				time = routeTimeCovered
			end
		end
	else
		local sectorFrom = squad.CurrentSector
		local sectorTo = route and route[1] and route[1][1]
		local shortcut = GetShortcutByStartEnd(sectorFrom, sectorTo)
		if shortcut then
			local travelTime = shortcut:GetTravelTime()
			local arrivalTime = squad.traversing_shortcut_start + travelTime
			local timeLeft = arrivalTime - Game.CampaignTime
			local timePassed = travelTime - timeLeft

			local routeTimeCovered = time - timePassed
			routeTimeCovered = DivCeil(routeTimeCovered, const.Scale.min) * const.Scale.min
			time = routeTimeCovered
		end
	end
	
	return time, breakdown or empty_table
end

--- Checks if the last sector in the given route is a water sector.
---
--- @param route table A table of route waypoints, where each waypoint is a table of sector IDs.
--- @return boolean True if the last sector in the route is a water sector, false otherwise.
function RouteEndsInWater(route)
	if #route > 0 and #route[#route] > 0 then
		local last_path = route[#route]
		local last_sector = last_path[#last_path]
		return gv_Sectors[last_sector].Passability == "Water"
	end
end

---
--- Checks if the given route contains a blocked sector.
---
--- @param route table A table of route waypoints, where each waypoint is a table of sector IDs.
--- @return boolean|number False if the route does not contain a blocked sector, otherwise the ID of the first blocked sector encountered.
function RouteOverBlockedSector(route)
	if not route then return false end
	for i, wp in ipairs(route) do
		for _, sectorId in ipairs(wp) do
			local sector = gv_Sectors[sectorId]
			if sector.Passability == "Blocked" then
				return sectorId
			end
		end
	end

	return false
end

---
--- Calculates the total price for a given route and squad.
---
--- @param route table A table of route waypoints, where each waypoint is a table of sector IDs.
--- @param squad table The squad object.
--- @return number The total price for the route.
--- @return number|boolean The ID of the first sector that the squad cannot afford to travel through, or false if the squad can afford the entire route.
function GetRouteTotalPrice(route, squad)
	local price = 0
	local pricePerSector = 0
	local cannotPayPast = false
	
	local prevSectorId = squad and squad.CurrentSector
	for i, r in ipairs(route) do
		for j, sector_id in ipairs(r or empty_table) do
			
			local prevSector = gv_Sectors[prevSectorId]
			local sector = gv_Sectors[sector_id]
			
			local shortcuts = r.shortcuts
			if shortcuts and shortcuts[j] then
				local shortcutPreset = GetShortcutByStartEnd(prevSectorId, sector_id)
				if shortcutPreset and shortcutPreset.water_shortcut then
					local cost = prevSector:GetTravelPrice(squad)
					price = price + cost * shortcutPreset.TravelTimeInSectors
				end
			end
			
			-- Get the cost from the port we just left
			if prevSector and prevSector.Passability == "Land and Water" and prevSector.Port and not prevSector.PortLocked then
				if sector.Passability == "Water" then
					pricePerSector = prevSector:GetTravelPrice(squad)
				end
			end
			-- Travelling on water still
			if sector.Passability == "Water" and pricePerSector then
				price = price + pricePerSector
			else
				pricePerSector = 0
			end
			
			if not cannotPayPast and not CanPay(price) then
				cannotPayPast = sector_id
			end
			
			prevSectorId = sector_id
		end
	end
	return price, cannotPayPast
end

--- Checks if a given route is forbidden for the specified squad.
---
--- @param route table A table of route waypoints, where each waypoint is a table of sector IDs.
--- @param squad table The squad object.
--- @return boolean True if the route is forbidden, false otherwise.
--- @return table A table of error messages.
--- @return number|boolean The ID of the first sector that the squad cannot travel through, or false if the squad can travel through the entire route.
--- @return boolean True if a waypoint can be placed at the end of the route, false otherwise.
function IsRouteForbidden(route, squad)
	if not route then return true end
	if route.invalid_shim then return true end
	
	local routePrice, cannotPayPast = GetRouteTotalPrice(route, squad)
	local firstErrorSectorId = false
	local canPlaceWaypoint = false

	local errors = {}
	
	if Platform.demo then
		local allowedSectors = {
			["I1"] = true,
			["I2"] = true,
			["I3"] = true,
			["H2"] = true,
			["H3"] = true,
			["H4"] = true,
		}
		
		for i, wp in ipairs(route) do
			for _, sectorId in ipairs(wp) do
				if not allowedSectors[sectorId] then
					firstErrorSectorId = sectorId
					errors[#errors + 1] = T(697751324120, "Not available in Demo")
					break
				end
			end
		end
	end
	
	if squad and squad.CurrentSector and gv_Sectors[squad.CurrentSector].conflict then
		errors[#errors + 1] = T(735827574209, "Squads in conflict can't receive travel orders.")
		firstErrorSectorId = firstErrorSectorId or squad.CurrentSector
	end
	
	if route.no_boat then
		errors[#errors + 1] = T(866576847121, "You do not have access to a port in order to cross water sectors.")
		firstErrorSectorId = firstErrorSectorId or route.no_boat
--[[	elseif not CanPay(routePrice) then
		errors[#errors + 1] = T(968093564193, "Not enough money to pay for boat travel.")
		firstErrorSectorId = firstErrorSectorId or cannotPayPast]]
	elseif RouteEndsInWater(route) then
		errors[#errors + 1] = T(368683270532, "The route ends in a water sector.")
		firstErrorSectorId = firstErrorSectorId or route[#route] and route[#route][#route[#route]]
		canPlaceWaypoint = true
	else
		local sectorId = RouteOverBlockedSector(route)
		if sectorId then
			-- Pathfinding will never pick it, so we only need to realistically consider it as the last sector.
			errors[#errors + 1] = T(399282935830, "The route ends on an impassable sector.")
			firstErrorSectorId = firstErrorSectorId or sectorId
		end
	end
	
	return #errors > 0, errors, firstErrorSectorId, canPlaceWaypoint
end

---
--- Gets the busy and available mercenaries in a squad.
---
--- @param squad_id number The ID of the squad.
--- @return table, table The busy mercenaries and the available mercenaries.
function GetSquadBusyAvailable(squad_id)
	local busy, available = {}, {}
	for _, merc_id in ipairs(gv_Squads[squad_id].units or empty_table) do
		local operation = gv_UnitData[merc_id].Operation 
		if operation~= "Idle" and operation ~= "Traveling" then
			busy[#busy + 1] = {merc_id = merc_id,operation = operation}
		else
			available[#available + 1] = merc_id
		end
	end
	
	return busy, available
end

---
--- Determines the appropriate action to take when a squad has busy mercenaries and available mercenaries.
---
--- @param busy table A table of busy mercenaries, where each entry is a table with fields `merc_id` and `operation`.
--- @param available table A table of available mercenaries, where each entry is a mercenary ID.
--- @return string The chosen action, which can be "split", "force", or "cancel".
function GetSplitMoveChoice(busy, available)
	local names = {}
	for _, data in ipairs(busy) do
		names[#names + 1] = gv_UnitData[data.merc_id].Nick
	end
	
	local singleMerc = #busy + #available == 1
	local anyAvailable = #available > 0
	local text
	if singleMerc then
		text = T{19660331151, "<em><list></em> is busy, do you want to move them anyway?", list = names[1]}
	elseif #busy > 1 and #available == 0 then
		text = T{153471084276, "<em><list></em> are busy, do you want to move them anyway?", list = ConcatListWithAnd(names)}
	elseif #busy > 1 then
		text = T{301515941137, "<em><list></em> are busy, do you want to split the squad?", list = ConcatListWithAnd(names)}
	else
		text = T{733472305625, "<em><list></em> is busy, do you want to split the squad?", list = names[1]}
	end
	
	local res = WaitPopupChoice(GetInGameInterface(), {
		translate = true,
		text = text,
		choice1 = T(681120834266, "Force Move"),
		choice1_gamepad_shortcut = "ButtonX",
		choice2 = (not singleMerc and anyAvailable) and T(743829766820, "Split Squad"),
		choice2_gamepad_shortcut = "ButtonY",
		choice3 = T(395359253564, "Cancel Move"),
		choice3_gamepad_shortcut = "ButtonB",
	})
	
	if res == 2 then
		return "split"
	elseif res == 1 then
		return "force"
	else
		return "cancel"
	end
end

---
--- Fixes the operation costs for mercenaries that have the "Doctor" and "Patient" operation professions when their "TreatWounds" operation is being cancelled.
---
--- @param busy table A table of busy mercenaries, where each entry is a table with fields `merc_id` and `operation`.
---
function FixTreatWoundsOperations(busy)
	for i, data in ipairs(busy) do
		local operation = data.operation
		local sector_operation = SectorOperations[operation]
		local merc  = gv_UnitData[data.merc_id]
		local refund_amount
		local prof_id = merc.OperationProfession
		if merc.OperationProfessions and merc.OperationProfessions["Doctor"] and merc.OperationProfessions["Patient"] then
			assert(operation=="TreatWounds")
			refund_amount = sector_operation:GetOperationCost(merc, "Patient")
			for _,cst in ipairs(sector_operation:GetOperationCost(merc, "Doctor")) do
				table.insert(refund_amount, cst)
			end
		else
			refund_amount = sector_operation:GetOperationCost(merc, prof_id)
		end
		NetSyncEvent("RestoreOperationCostAndSetOperation", data.merc_id, refund_amount, "Idle", prof_id, false,false, "check_completed")
	end
end

---
--- Attempts to assign a route to a satellite squad. If the squad has busy mercenaries, it will prompt the player to either split the squad or force move the busy mercenaries.
---
--- @param squad_id number The unique identifier of the squad.
--- @param route table A table of route data, where each entry is a table with fields `x`, `y`, and optionally `shortcuts`.
--- @return string|nil The result of the operation, which can be "split", "force", or "cancel". Returns nil if the operation was successful without user input.
---
function TryAssignSatelliteSquadRoute(squad_id, route)
	local busy, available = GetSquadBusyAvailable(squad_id)
	local res
	if next(busy) then
		res = GetSplitMoveChoice(busy, available)
		if res == "split" then
			NetSyncEvent("SplitMercsAndAssignRoute", table.map(busy, "merc_id"), squad_id, route, "keepJoiningSquad")
		elseif res == "force" then
			FixTreatWoundsOperations(busy)
			NetSyncEvent("AssignSatelliteSquadRoute", squad_id, route, "keepJoiningSquad")
		end
	else
		NetSyncEvent("AssignSatelliteSquadRoute", squad_id, route, "keepJoiningSquad")
	end
	
	return res == "cancel" and "cancel"
end

---
--- Cancels the travel of a satellite squad.
---
--- @param squad_id number The unique identifier of the squad.
--- @param keepJoiningSquad boolean Whether to keep the mercs in the squad after cancelling the travel.
--- @param force boolean Whether to force the cancellation of the travel.
---
--- @return nil
---
function NetSyncEvents.SquadCancelTravel(squad_id, keepJoiningSquad, force)
	local self = gv_Squads[squad_id]
	if not self then return end
	if not force and (SquadTravelCancelled(self) or not IsSquadTravelling(self, "skip_satellite_tick")) then
		return
	end

	local route = false
	-- If cancelling on a shortcut just stop after it
	-- todo: should we maybe backtrack?
	if IsTraversingShortcut(self) then
		route = {}
		route[1] = { self.route[1][1], shortcuts = { true } }
	-- Don't consider as water route if cancelling at last tile (which is supposed to be a land tile)
	elseif self.water_route and self.water_route[1] ~= self.CurrentSector then
		route = {}
		route[1] = table.reverse(self.water_route)
		self.returning_water_travel = true
	-- If currently not centered then return to center
	elseif not IsSquadInSectorVisually(self, self.CurrentSector) then
		route = {}
		route[1] = {self.CurrentSector, ["returning_land_travel"] = true}
	end

	local visualPos = g_SatelliteUI and g_SatelliteUI.squad_to_wnd[self.UniqueId] and g_SatelliteUI.squad_to_wnd[self.UniqueId]:GetVisualPos()
	NetSyncEvents.AssignSatelliteSquadRoute(self.UniqueId, route, keepJoiningSquad, visualPos, true)
end

---
--- Assigns a route to a satellite squad.
---
--- @param squad_id number The unique identifier of the squad.
--- @param route table The route to assign to the squad.
--- @param keepJoiningSquad boolean Whether to keep the mercs in the squad after assigning the route.
--- @param pos table The visual position of the squad.
--- @param cancel boolean Whether to cancel the squad's current travel.
---
--- @return nil
---
function NetSyncEvents.AssignSatelliteSquadRoute(squad_id, route, keepJoiningSquad, pos, cancel)
	NetUpdateHash("AssignSatelliteSquadRoute", squad_id, Game and Game.CampaignTime)
	local squad = gv_Squads[squad_id]
	if cancel then
		for _, unit_id in ipairs(squad.units) do
			local unit_data = gv_UnitData[unit_id]
			if unit_data.Operation == "Traveling" then
				unit_data:SetCurrentOperation("Idle")
			end
		end
	end
	SetSatelliteSquadRoute(squad, route, keepJoiningSquad, nil, pos)
end

---
--- Splits a satellite squad into two squads, with the specified mercs being moved to the new squad.
---
--- @param squad table The satellite squad to split.
--- @param merc_ids table A list of merc IDs to move to the new squad.
---
--- @return number The unique ID of the new squad.
---
function SplitSquad(squad, merc_ids)
	if #squad.units == 1 or #merc_ids == 0 then return squad.UniqueId end
	assert(squad.CurrentSector)
	if not squad.CurrentSector then return end
	
	local name = SquadName:GetNewSquadName(squad.Side)
	local squad_id = CreateNewSatelliteSquad({
		Side = squad.Side,
		CurrentSector = squad.CurrentSector,
		PreviousSector = squad.PreviousSector,
		PreviousLandSector = squad.PreviousLandSector,
		VisualPos = squad.VisualPos,
		Name = name
	}, merc_ids, nil, nil, nil, "squad_split"
	)

	return squad_id
end

---
--- Splits a satellite squad into two squads, with the specified mercs being moved to the new squad.
---
--- @param squad_id number The unique identifier of the squad to split.
--- @param merc_ids table A list of merc IDs to move to the new squad.
---
--- @return number The unique ID of the new squad.
---
function NetSyncEvents.SplitSquad(squad_id, merc_ids)
	local squad = gv_Squads[squad_id]
	local new_squad_id = SplitSquad(squad, merc_ids)
	Msg("SyncSplitSquad", new_squad_id, squad_id)
end

-- Split off busy mercs and set a route for the squad.
---
--- Splits a satellite squad into two squads, with the specified busy mercs being moved to the new squad, and assigns a route to the original squad.
---
--- @param busy_merc_ids table A list of merc IDs to move to the new squad.
--- @param old_squad_id number The unique identifier of the squad to split.
--- @param route table The route to assign to the original squad.
--- @param keepJoiningSquad boolean Whether to keep the mercs in the joining squad.
---
function NetSyncEvents.SplitMercsAndAssignRoute(busy_merc_ids, old_squad_id, route, keepJoiningSquad)
	local old_squad = gv_Squads[old_squad_id]
	SplitSquad(old_squad, busy_merc_ids)
	SetSatelliteSquadRoute(old_squad, route, keepJoiningSquad)
end

---
--- Sets the route for a satellite squad.
---
--- @param squad table The satellite squad to set the route for.
--- @param route table The route to set for the squad. Can be `false` to clear the route.
--- @param keepJoiningSquad boolean Whether to keep the squad in a joining state.
--- @param from string The source of the route update, either "from_map" or nil.
--- @param squadPos table The position of the squad.
---
function SetSatelliteSquadRoute(squad, route, keepJoiningSquad, from, squadPos)
	if g_TestCombat and not squad then return end
	assert(squad)
	
	NetUpdateHash("SetSatelliteRoute", squad.UniqueId, route, keepJoiningSquad, from, squadPos)
	
	local wasTravelling = IsSquadTravelling(squad)
	
	local nextSector = route and route[1] and route[1][1]
	local nextIsUnderground = nextSector and IsSectorUnderground(nextSector)
	
	local squadSectorPreset = squad.CurrentSector and gv_Sectors[squad.CurrentSector]
	local squadSectorGroundSectorId = squadSectorPreset and squadSectorPreset.GroundSector
	if squadSectorGroundSectorId and (nextSector and not nextIsUnderground) then
		local from_map = from == "from_map" 
		SetSatelliteSquadCurrentSector(squad, squadSectorGroundSectorId, from_map)
		SatelliteReachSectorCenter(squad.UniqueId, squad.CurrentSector, squad.PreviousSector)
		
		-- Manually remove the overground sector from the route.
		local firstWp = route and route[1]
		if firstWp and firstWp[1] == squadSectorGroundSectorId then
			table.remove(firstWp, 1)
			if #firstWp == 0 then
				table.remove(route, 1)
			else
				-- Correct shortcut indices if any
				if firstWp.shortcuts then
					local shortcutsCorrected = {}
					for i, _ in pairs(firstWp.shortcuts) do
						local newIndex = i - 1
						if newIndex >= 1 then
							shortcutsCorrected[i - 1] = true
						end
					end
					firstWp.shortcuts = shortcutsCorrected
				end
			end
			
			-- It is possible for there to be nothing else in the route as well.
			if #route == 0 then
				route = false
				
				local curSector = gv_Sectors[squad.CurrentSector]
				ObjModified(curSector)
				Msg("SquadStartedTravelling", squad)
			end
		end
	end
	
	if route and route[1] then
		assert(route[1].returning_land_travel or
				route[1][1] ~= squad.CurrentSector or
				route.water_route_assignment_route or
				squad.Retreat)
	end
	if squad.Retreat then squad.Retreat = false end
	
	-- If was pathing to join a squad, and a route is set - it no longer is. (Unless set by the tick itself)
	if not keepJoiningSquad and squad.joining_squad then
		TurnJoiningSquadIntoNormal(squad)
	end
	
	squad.route = route
	if squadPos and g_SatelliteUI and g_SatelliteUI.squad_to_wnd[squad.UniqueId] then
		g_SatelliteUI.squad_to_wnd[squad.UniqueId]:SetPos(squadPos:xy())
	end

	if squad.route then
		SectorOperation_CancelByGame(squad.units)
	else
		SetSatelliteSquadCurrentSector(squad, squad.CurrentSector, "update_pos", "teleport")
		Msg("SquadStoppedTravelling", squad)
		return
	end
	
	-- Prevent squads starting travel from briefly missing conflict.
	local curSector = gv_Sectors[squad.CurrentSector]
	if not wasTravelling and not squad.Retreat and not curSector.conflict then
		-- Used to mark this squad as not being centered despite not having moved yet.
		-- This will prevent other cases of briefly missing conflict,
		-- such as when the player squad is fast enough to exit the sector before the next check.
		-- This property doesn't need to persist so we'll just set to false right after to prevent side effects.
		squad.consider_visually_moved = true
		CheckAndEnterConflict(curSector, squad, squad.PreviousSector)
		squad.consider_visually_moved = false
	end
	
	-- If the first sector in the route is a water tile,
	-- we're water travelling from the get go.
	local first = route and route[1]
	first = first and first[1]
	SetSquadWaterTravel(squad, gv_Sectors[first].Passability == "Water")
	
	ObjModified(curSector)
	Msg("SquadStartedTravelling", squad)
end

---
--- Sets the travelling activity for a squad.
---
--- This function can be called outside of satellite view when exiting via interactable.
--- The reason being that the routes are calculated beforehand due to user input popups being able to cancel the exit altogether.
---
--- @param squad table The squad to set the travelling activity for.
---
function SetSquadTravellingActivity(squad)
	-- This function can be called outside of satellite view when exiting via interactable.
	-- The reason being that the routes are calculated beforehand due to user input popups being able to cancel the exit altogether.
	local manualSync = not gv_SatelliteView
	
	SectorOperation_CancelByGame(squad.units, false, true)
	for _, unit_id in ipairs(squad.units) do
	
		-- Sync unit to unitdata before we change the unitdata, so we can get
		-- the latest version of the unit
		local mapUnit = manualSync and g_Units[unit_id]
		if mapUnit then 
			mapUnit:SyncWithSession("map")
		end
		
		local unit_data = gv_UnitData[unit_id]
		
		local prev_operation = unit_data.Operation	
		unit_data:SetCurrentOperation("Traveling")
		if unit_data.TravelTimerStart == 0 then
			unit_data.TravelTimerStart = Game.CampaignTime
			unit_data.RestTimer = 0
			DbgTravelTimerPrint(unit_id, "start travel", "travel: ", unit_data.TravelTime / const.Scale.h or 0)
		end
		
		-- Sync new changes with unit
		if mapUnit then
			mapUnit:SyncWithSession("session")
		end		
	end
end

---
--- Sets the route for a satellite squad to a destination sector, but does not start the squad traveling.
---
--- This function is used to set up a "secret" route for a squad, where the squad will automatically travel to the destination sector after a specified time delay.
---
--- @param squad table The satellite squad to set the route for.
--- @param dest number The ID of the destination sector.
--- @param time number The time in seconds before the squad will automatically start traveling to the destination sector.
---
function SetSatelliteSquadSecretRoute(squad, dest, time)
	SetSatelliteSquadRoute(squad, false)
	squad.arrive_in_sector = {time = time, sector_id = dest}
	squad.CurrentSector = false
end

---
--- Sends a satellite squad on a route to a destination sector.
---
--- @param squad table The satellite squad to send on the route.
--- @param dest number The ID of the destination sector.
--- @param params table Optional parameters, including:
---   - enemy_guardpost (boolean) Whether to avoid enemy guard posts when generating the route.
---
--- @return boolean True if the route was successfully set, false otherwise.
---
function SendSatelliteSquadOnRoute(squad, dest, params)
	local route = GenerateRouteDijkstra(squad.CurrentSector, dest, squad.route, squad.units, params and params.enemy_guardpost and "enemy_guardpost", nil, squad.Side)
	if not route then
		assert(false, "SendSatelliteSquadOnRoute - spawned squad could not find route to target sector. " .. squad.CurrentSector .. "->" .. dest)
		return
	end
	route = {route} -- Waypointify
	SetSatelliteSquadRoute(squad, route)
end

---
--- Gets the visual position of a satellite squad.
---
--- If the squad has a corresponding window in the satellite UI, the travel position of that window is returned.
--- Otherwise, the squad's XVisualPos property is returned.
---
--- @param squad table The satellite squad to get the visual position for.
--- @return boolean|number The visual position of the squad, or false if the position could not be determined.
---
function GetSquadVisualPos(squad)
	local visPos = false
	if g_SatelliteUI and g_SatelliteUI.squad_to_wnd[squad.UniqueId] then
		local wnd = g_SatelliteUI.squad_to_wnd[squad.UniqueId]
		if wnd.box == empty_box then
			visPos = squad.XVisualPos
		else
			visPos = wnd:GetTravelPos()
		end
	else
		visPos = squad.XVisualPos
	end
	return visPos
end

---
--- Determines whether a satellite squad is visually present in a specified sector.
---
--- @param squad table The satellite squad to check.
--- @param sectorId number (optional) The ID of the sector to check. If not provided, the squad's current sector will be used.
--- @return boolean True if the squad is visually present in the specified sector, false otherwise.
---
function IsSquadInSectorVisually(squad, sectorId)
	local visPos = GetSquadVisualPos(squad)
	
	sectorId = sectorId or squad.CurrentSector
	local sector = gv_Sectors[sectorId]
	
	-- Workaround for legacy saves. Remove in the future.
	if not sector.XMapPosition then visPos = false end
	
	if squad.CurrentSector ~= sectorId then return false end
	if squad.consider_visually_moved then return false end
	if not visPos or visPos == sector.XMapPosition then return true end
	return false
end

---
--- Determines whether a satellite squad is currently travelling.
---
--- @param squad table The satellite squad to check.
--- @param regardlessSatelliteTickPassed boolean (optional) If true, the function will return true even if the satellite tick has not yet passed.
--- @return boolean True if the squad is currently travelling, false otherwise.
---
function IsSquadTravelling(squad, regardlessSatelliteTickPassed)
	if not squad then return false end
	if squad.arrival_squad then return true end
	if squad.Retreat then return true end

	local squadSectorId = squad.CurrentSector
	local squadSector = gv_Sectors[squadSectorId]
	if squadSector.conflict and IsSquadInSectorVisually(squad, squadSectorId) then
		return false
	end
	return squad.route and squad.route[1] and squad.route[1] and (squad.route.satellite_tick_passed or regardlessSatelliteTickPassed) and not squad.wait_in_sector
end

---
--- Determines whether two satellite squads are visually present in the same sector.
---
--- @param squad1 table The first satellite squad to check.
--- @param squad2 table The second satellite squad to check.
--- @param undergroundInsensitive boolean (optional) If true, the function will check if the squads are in the same ground sector, ignoring any underground sectors.
--- @return boolean True if the squads are visually present in the same sector, false otherwise.
---
function AreSquadsInTheSameSectorVisually(squad1, squad2, undergroundInsensitive)
	local sector1 = squad1.CurrentSector
	local sector2 = squad2.CurrentSector
	local visuallyThere1 = IsSquadInSectorVisually(squad1, sector1)
	local visuallyThere2 = IsSquadInSectorVisually(squad2, sector2)
	
	if undergroundInsensitive then
		sector1 = gv_Sectors[sector1].GroundSector or sector1
		sector2 = gv_Sectors[sector2].GroundSector or sector2
	end
	
	if sector1 ~= sector2 then return false end
	
	return visuallyThere1 and visuallyThere2
end

---
--- Determines whether a satellite squad is currently in a conflict sector.
---
--- @param squad table The satellite squad to check.
--- @return boolean True if the squad is currently in a conflict sector, false otherwise.
---
function IsSquadInConflict(squad)
	local squadSectorId = squad.CurrentSector
	local squadSector = gv_Sectors[squadSectorId]
	return squadSector.conflict and (not IsSquadTravelling(squad) and not IsTraversingShortcut(squad))
end

---
--- Determines whether the given satellite squad has a route.
---
--- @param squad table The satellite squad to check.
--- @return boolean True if the squad has a route, false otherwise.
---
function IsSquadHasRoute(squad)
	return squad and squad.route and squad.route[1] 
end

---
--- Determines whether the given satellite squad has reached its final destination.
---
--- @param squad table The satellite squad to check.
--- @return boolean True if the squad has reached its final destination, false otherwise.
---
function IsSquadInDestinationSector(squad)
	return squad and squad.route and #squad.route == 1 and #squad.route[1] == 1 and squad.route[1][1] == squad.CurrentSector
end

-- moving squad from sector to sector without player control
---
--- Moves a list of satellite squads from one sector to another without interruption.
---
--- @param squads_sectors_list table A list of sector IDs to move the squads through.
--- @param src_sector_id number The ID of the starting sector.
--- @param dest_sector_id number The ID of the destination sector.
---
function UninterruptableSquadTravel(squads_sectors_list, src_sector_id, dest_sector_id)
	local squads = {}
	for _, sector_id in ipairs(squads_sectors_list) do
		for i, squad in ipairs(g_SquadsArray) do
			if squad.CurrentSector == sector_id and 
				(squad.Side == "player1" or squad.Side == "player2") and not squad.arrival_squad then
				squads[#squads + 1] = squad
			end
		end
	end

	for i, squad in ipairs(squads) do
		local squadSector = squad.CurrentSector
		if src_sector_id  and src_sector_id ~= squadSector then
			SetSatelliteSquadCurrentSector(squad, src_sector_id, true, "teleport")
			if gv_Sectors[squadSector].conflict then ResolveConflict(gv_Sectors[squadSector], true) end
		end
		if src_sector_id == dest_sector_id then
			return
		end
		squad.uninterruptable_travel = true
		local route = GenerateRouteDijkstra(squad.CurrentSector, dest_sector_id, false, squad.units, nil, nil, squad.Side)
		if route then
			SetSatelliteSquadRoute(squad, { route })
		end	
	end
end

---
--- Determines whether the local player has authority over the given satellite squad.
---
--- @param squad table The satellite squad to check.
--- @return boolean True if the local player has authority over the squad, false otherwise.
---
function LocalPlayerHasAuthorityOverSquad(squad)
	if squad.uninterruptable_travel then 
		return false 
	end
	
	local count = 0
	local units = squad.units
	for i, session_id in ipairs(units) do
		local merc = gv_UnitData[session_id]
		if merc and merc:IsLocalPlayerControlled() then
			count = count + 1
		end
	end
	
	local unitCount = #units
	return count > unitCount / 2 or (unitCount % 2 == 0 and count == unitCount / 2 and NetIsHost())
end

---
--- Determines the final destination and whether the current sector is the destination for a given route.
---
--- @param startSector string The starting sector.
--- @param route table The route to the destination.
--- @return string The final destination sector.
--- @return boolean Whether the current sector is the final destination.
---
function GetSquadFinalDestination(startSector, route)
	if not route then
		return startSector, true
	end

	local routeDestination = false
	local isCurrent = true
	if route then
		local finalPoint = route[#route]
		if finalPoint then
			routeDestination = finalPoint[#finalPoint]
			isCurrent = routeDestination == startSector
		else
			routeDestination = startSector
			isCurrent = true
		end
	end
	
	return routeDestination, isCurrent
end

---
--- Gets a list of squads in the given sector that are not arrival squads and optionally belong to the specified sides.
---
--- @param sector_id string The ID of the sector to get squads from.
--- @param side1 string (optional) The first side to filter squads by.
--- @param side2 string (optional) The second side to filter squads by.
--- @return table A list of squads in the sector that match the specified criteria.
---
function GetSectorSquadsFromSide(sector_id, side1, side2)
	if not sector_id then return empty_table end
	local sector = gv_Sectors[sector_id]
	local squads = {}	
	for i, squad in ipairs(sector.all_squads) do
		if not squad.militia and not squad.arrival_squad and (not side1 or squad.Side == side1 or squad.Side == side2) then
			squads[#squads + 1] = squad
		end
	end
	return squads
end

---
--- Gets a list of squads in the given sector that are not arrival squads.
---
--- @param sector_id string The ID of the sector to get squads from.
--- @return table A list of squads in the sector that are not arrival squads.
---
function GetSectorSquads(sector_id)
	local squads = {}
	local sector = gv_Sectors[sector_id]
	for i, squad in ipairs(sector and sector.all_squads) do
		if not squad.arrival_squad then
			squads[#squads + 1] = squad
		end
	end
	return squads
end

---
--- Gets a list of all units in the given sector that belong to the player.
---
--- @param sector_id string The ID of the sector to get units from.
--- @param getUnits boolean (optional) If true, returns the actual unit objects, otherwise returns the unit IDs.
--- @return table A list of units in the sector that belong to the player.
---
function GetPlayerSectorUnits(sector_id, getUnits)
	local squads = GetSectorSquadsFromSide(sector_id, "player1","player2")
	local units = {}
	for _, squad in ipairs(squads) do
		for _, unit_id in ipairs(squad.units) do
			local unit = getUnits and g_Units[unit_id] or gv_UnitData[unit_id]
			assert(not table.find(units, unit))
			units[#units + 1] = unit
		end
	end
	return units
end

---
--- Filters a list of mercs based on a provided filter function.
---
--- @param mercs table A list of mercs to filter.
--- @param filter_func function The filter function to apply to each merc.
--- @return table A new list containing only the mercs that passed the filter.
---
function FilterMercs(mercs, filter_func)
	local filtered = {}
	for _, merc in ipairs(mercs) do
		if filter_func(merc) then
			filtered[#filtered + 1] = merc
		end
	end
	return filtered
end

---
--- Gets the merc with the highest value for the given stat from the provided list of mercs.
---
--- @param mercs table A list of mercs to search through.
--- @param stat string The stat to compare the mercs by.
--- @return table The merc with the highest value for the given stat, or nil if no mercs are available.
---
function GetBestStatMerc(mercs, stat)
	local best_stat = 0
	local best_merc
	for _, merc in ipairs(mercs) do
		if not merc:IsTravelling() and merc[stat] > best_stat then
			best_stat = merc[stat]
			best_merc = merc
		end
	end
	return best_merc
end

---
--- Gets a list of units by their IDs.
---
--- @param unitIds table A list of unit IDs.
--- @param getUnitData boolean If true, returns the unit data from `gv_UnitData`, otherwise returns the unit objects from `g_Units`.
--- @return table A list of units.
---
function GetUnitsByIds(unitIds, getUnitData)
	local units = {}
	for _, id in ipairs(unitIds) do
		units[#units+1] = getUnitData and gv_UnitData[id] or g_Units[id]
	end
	return units
end

---
--- Gets a list of units from the given squads.
---
--- @param squads table A list of squads, where each squad is a table with a `units` field containing a list of unit IDs.
--- @param getUnitData boolean If true, returns the unit data from `gv_UnitData`, otherwise returns the unit objects from `g_Units`.
--- @return table A list of units.
---
function GetUnitsFromSquads(squads, getUnitData)
	local units = {}
	for _, squad in ipairs(squads) do
		table.iappend(units, GetUnitsByIds(squad.units, getUnitData))
	end
	return units
end

---
--- Checks if there is a road between the given sectors.
---
--- @param from_sector_id number The ID of the starting sector.
--- @param to_sector_id number The ID of the destination sector.
--- @param cache_neighbors boolean If true, use cached neighbor information.
--- @return boolean True if there is a road between the sectors, false otherwise.
---
function HasRoad(from_sector_id, to_sector_id, cache_neighbors)
	return GetDirectionProperty(from_sector_id, to_sector_id, "Roads", cache_neighbors)
end

---
--- Checks if travel is blocked between the given sectors.
---
--- @param from_sector_id number The ID of the starting sector.
--- @param to_sector_id number The ID of the destination sector.
--- @param cache_neighbors boolean If true, use cached neighbor information.
--- @return boolean True if travel is blocked between the sectors, false otherwise.
---
function IsTravelBlocked(from_sector_id, to_sector_id, cache_neighbors)
	return GetDirectionProperty(from_sector_id, to_sector_id, "BlockTravel", cache_neighbors) or gv_Sectors[to_sector_id].Passability == "Blocked"
end

---
--- Gets a property value for the direction between two sectors.
---
--- @param from_sector_id number The ID of the starting sector.
--- @param to_sector_id number The ID of the destination sector.
--- @param prop_id string The property ID to retrieve.
--- @param cache_neighbors boolean If true, use cached neighbor information.
--- @return any The value of the specified property for the direction between the sectors, or nil if not found.
---
function GetDirectionProperty(from_sector_id, to_sector_id, prop_id, cache_neighbors)
	local from_sector = gv_Sectors[from_sector_id]
	if cache_neighbors then
		local dir = cache_neighbors[to_sector_id]
		local fs = dir and from_sector[prop_id]
		return fs and fs[dir]
	else
		for _, dir in ipairs(const.WorldDirections) do
			if GetNeighborSector(from_sector_id, dir) == to_sector_id then
				return from_sector[prop_id] and from_sector[prop_id][dir]
			end
		end
	end
end

local opposite_directions =
{
	North = "South",
	South = "North",
	East = "West",
	West = "East",
}

---
--- Checks if travel is blocked between the given sectors.
---
--- @param from_sector_id number The ID of the starting sector.
--- @param to_sector_id number The ID of the destination sector.
--- @param _ any Unused parameter.
--- @param pass_mode string The travel mode, such as "land_only", "land_water_boatless", etc.
--- @param __ any Unused parameter.
--- @param dir string The direction of travel.
--- @param cache_neighbors boolean If true, use cached neighbor information.
--- @return boolean True if travel is blocked between the sectors, false otherwise.
---
function SectorTravelBlocked(from_sector_id, to_sector_id, _, pass_mode, __, dir, cache_neighbors)
	local from_sector = gv_Sectors[from_sector_id]
	local to_sector = gv_Sectors[to_sector_id]
	
	if 
		IsTravelBlocked(from_sector_id, to_sector_id, cache_neighbors) or
		pass_mode == "land_only" and to_sector.Passability == "Water"
	then
		return true
	end
	
	if pass_mode ~= "land_water_river" and
		GetDirectionProperty(from_sector_id, to_sector_id, "BlockTravelRiver", cache_neighbors) then
		return true
	end
	
	if to_sector.Passability == "Water" then
		if pass_mode == "land_water_boatless" then
			return false
		elseif pass_mode == "land_water" or pass_mode == "land_water_river" then
			if from_sector.Passability == "Land" or from_sector.Passability == "Land and Water" then
				return not (from_sector.Port and not from_sector.PortLocked and from_sector.Side == "player1" and IsBoatAvailable())
			end
		end
	end
	
	return false
end

---
--- Checks if two sectors are in the same city.
---
--- @param sector_a table The first sector to compare.
--- @param sector_b table The second sector to compare.
--- @return boolean True if the sectors are in the same city, false otherwise.
---
function AreSectorsSameCity(sector_a, sector_b)
	if sector_a.City == sector_b.City and sector_a.City ~= "none" then
		return true
	end
	
	if sector_a.GroundSector == sector_b.Id or sector_b.GroundSector == sector_a.Id then
		return true
	end
	
	return false
end

---
--- Calculates the travel time between two sectors, taking into account various factors such as terrain, roads, and squad leadership.
---
--- @param from_sector_id integer The ID of the starting sector.
--- @param to_sector_id integer The ID of the destination sector.
--- @param route table (optional) A table containing information about the travel route, including whether a diamond briefcase is being transported.
--- @param units table (optional) A table of unit IDs for the units traveling.
--- @param pass_mode string (optional) The travel mode, such as "land_only", "land_water", etc.
--- @param _ any (unused)
--- @param side string (optional) The side of the units, such as "player1", "enemy1", or "diamonds".
--- @param dir any (unused)
--- @param cache_shortcuts table (optional) A cache of sector shortcuts.
--- @param cache_neighbors table (optional) A cache of neighboring sectors.
--- @return number, number, number, table The total travel time, the travel time for the first sector, the travel time for the second sector, and a breakdown of the travel time factors.
---
function GetSectorTravelTime(from_sector_id, to_sector_id, route, units, pass_mode, _, side, dir, cache_shortcuts, cache_neighbors)
	local shortcut
	if to_sector_id and not AreAdjacentSectors(from_sector_id, to_sector_id) then
		shortcut = GetShortcutByStartEnd(from_sector_id, to_sector_id)
	end
	
	-- If entering/exiting underground from overground then its always instant
	-- We need to specially handle this as it is possible for an overground sector to connect to
	-- another sector's underground sector (i.e. secret tunnel)
	local from_underground = IsSectorUnderground(from_sector_id)
	local to_underground = IsSectorUnderground(to_sector_id)
	if from_underground ~= to_underground then return 0 end
	
	if pass_mode == "display_invalid" then
		return 1
	end
	
	if not shortcut and (to_sector_id and SectorTravelBlocked(from_sector_id, to_sector_id, route, pass_mode, _, dir, cache_neighbors)) then
		return false
	end

	-- Since we don't pass in a reference to the squad we cant check squad.diamond_briefcase
	if route and route.diamond_briefcase then
		local time = const.Satellite.SectorTravelTimeDiamonds
		time = DivCeil(time, const.Scale.min) * const.Scale.min
		return time * 2, time, time, {}
	end
	
	local is_player = side and (side == "player1" or side == "player2")
	local breakdown = is_player and {} or false
	local max_leadership, max_leadership_merc = 0, false

	if is_player then
		for i, u in ipairs(units or empty_table) do
			local unit_data = gv_UnitData[u]

			if max_leadership < unit_data.Leadership then
				max_leadership = unit_data.Leadership
				max_leadership_merc = unit_data.session_id
			end	
		end
	end
	
	local squadModifier = is_player and 100 - (const.Satellite.SectorTravelTimeBase - max_leadership) or 0
	if is_player then
		breakdown[#breakdown + 1] = { Text = T(703764048855, "Squad Speed"), Value = squadModifier, Category = "squad",
			rollover = T{898857286023, "The squad speed is defined by the merc with the highest Leadership in the squad.<newline><mercName><right><stat>",
				mercName = max_leadership_merc and UnitDataDefs[max_leadership_merc] and UnitDataDefs[max_leadership_merc].Nick or Untranslated("???"),
				stat = max_leadership
			}
		}
	end
	
	local from_sector = gv_Sectors[from_sector_id]
	local to_sector = to_sector_id and gv_Sectors[to_sector_id]
	if to_sector then
		if AreSectorsSameCity(from_sector, to_sector) then
			return 0, 0, 0, breakdown
		end
		if (side == "enemy1" or side == "diamonds") and to_sector.ImpassableForEnemies then
			return false
		end
		if side == "diamonds" and to_sector.ImpassableForDiamonds then
			return false
		end
	end
	
	local terrain_type1 = gv_Sectors[from_sector_id].TerrainType
	local terrain_type2 = to_sector_id and gv_Sectors[to_sector_id].TerrainType
	
	-- Water terrain type isnt always applied to water passability tiles
	if gv_Sectors[from_sector_id] and gv_Sectors[from_sector_id].Passability == "Water" then terrain_type1 = "Water" end
	if gv_Sectors[to_sector_id] and gv_Sectors[to_sector_id].Passability == "Water" then terrain_type2 = "Water" end
	
	local travel_time_modifier1 = SectorTerrainTypes[terrain_type1] and SectorTerrainTypes[terrain_type1].TravelMod or 100
	local travel_time_modifier2 = to_sector_id and SectorTerrainTypes[terrain_type2] and SectorTerrainTypes[terrain_type2].TravelMod or travel_time_modifier1
	local hasRoad = false;
	if to_sector_id and HasRoad(from_sector_id, to_sector_id, cache_neighbors) then
		travel_time_modifier1 = const.Satellite.RoadTravelTimeMod
		travel_time_modifier2 = const.Satellite.RoadTravelTimeMod
		hasRoad = true
	end
	
	-- Special travel that is considered as travelling on the river but isn't through shortcuts.
	local isRiverSectors
	if cache_shortcuts ~= nil then
		isRiverSectors = IsRiverSector(from_sector_id, not not shortcut, cache_shortcuts)
	else
		isRiverSectors = not shortcut and IsRiverSector(from_sector_id) and IsRiverSector(to_sector_id, "two_way")
	end
	
	if is_player then
		local mod = travel_time_modifier2
		if isRiverSectors then
			breakdown[#breakdown + 1] = { Text = T(414143808849, "<em>(River)</em>"), Category = "sector-special", special = "road" }
		elseif mod ~= 0 and terrain_type1 ~= "Water" and terrain_type2 ~= "Water" and not shortcut then
			if hasRoad then
				breakdown[#breakdown + 1] = { Text = T(561135531078, "<em>(Road)</em>"), Value = 100 - mod, Category = "sector-special", special = "river" }
			end
			local difficultyText = false
			if mod == 100 then
				difficultyText = T(714191851131, --[[Terrain difficulty]] "Normal")
			elseif mod <= 25 then
				difficultyText = T(367857875968, --[[Terrain difficulty]] "Very Easy")
			elseif mod <= 75 then
				difficultyText = T(825299951074, --[[Terrain difficulty]] "Easy")
			elseif mod >= 150 then
				difficultyText = T(625725601692, --[[Terrain difficulty]] "Very Hard")
			elseif mod >= 120 then
				difficultyText = T(835764015096, --[[Terrain difficulty]] "Hard")
			end
			breakdown[#breakdown + 1] = { Text = T(379323289276, "Terrain"), Value = difficultyText, ValueType = "text", Category = "sector" }
		end
	end

	-- travel with the speed of the slowest unit
	travel_time_modifier1 = travel_time_modifier1
	travel_time_modifier2 = travel_time_modifier2
	local sector_travel_time = is_player and const.Satellite.SectorTravelTime or const.Satellite.SectorTravelTimeEnemy
	if squadModifier ~= 0 then
		-- speed is increased by:
		-- new_t = (S/V) * old_t where constant S == 100 and V == 100 + modifier
		sector_travel_time = MulDivRound(sector_travel_time, 100, 100 + squadModifier)
	end
	local travel_time_1 = sector_travel_time * travel_time_modifier1 / 100
	local travel_time_2 = sector_travel_time * travel_time_modifier2 / 100

	if to_sector_id == from_sector_id and #(units or "") > 0 then
		local ud = gv_UnitData[units[1]]
		local squad = ud and ud.Squad
		squad = squad and gv_Squads[squad]
		if squad then
			local squadPos = GetSquadVisualPos(squad)
			local retreatSector = from_sector.XMapPosition
			local from = GetSquadPrevSector(squadPos, from_sector_id, retreatSector)
			from = from and gv_Sectors[from].XMapPosition
			
			local diff = retreatSector - from
			local passed = squadPos - from
			local passedDDiff = Dot(passed, diff)
			local percentPassed = passedDDiff ~= 0 and MulDivRound(passedDDiff, 1000, Dot(diff, diff)) or 0
			travel_time_1 = MulDivRound(travel_time_1, percentPassed, 1000)
			travel_time_2 = 0
		end
	elseif shortcut then
		travel_time_2 = shortcut:GetTravelTime()
		travel_time_1 = 0
	elseif isRiverSectors then
		travel_time_2 = const.SatelliteShortcut.RiverTravelTime + 1
		travel_time_1 = 0
	end
	
	-- If landing from water or travelling in water move at a constant speed.
	local waterTravel = const.Satellite.SectorTravelTimeWater
	if terrain_type1 == "Water" or terrain_type2 == "Water" then
		travel_time_1 = waterTravel / 2
		travel_time_2 = waterTravel / 2
	end

	-- Round to campaign time increments
	travel_time_1 = DivCeil(travel_time_1, const.Scale.min) * const.Scale.min
	travel_time_2 = DivCeil(travel_time_2, const.Scale.min) * const.Scale.min
	
	return travel_time_1 + travel_time_2, travel_time_1, travel_time_2, breakdown
end

---
--- Synchronizes the arrival of a mercenary to a specific sector.
---
--- @param merc_id number The ID of the mercenary.
--- @param sector_id number The ID of the sector the mercenary is arriving at.
---
function NetSyncEvents.SetArrivingMercSector(merc_id, sector_id)
	LocalSetArrivingMercSector(merc_id, sector_id)
end

---
--- Synchronizes the arrival of a mercenary to a specific sector.
---
--- @param merc_id number The ID of the mercenary.
--- @param sector_id number The ID of the sector the mercenary is arriving at.
--- @param days number (optional) The number of days the mercenary is hired for.
---
function LocalSetArrivingMercSector(merc_id, sector_id, days)
	-- When a merc is hired as arriving they will start arriving at the default sector
	-- prior to the destination popup opening. Once the player picks a destination this
	-- function is called again with the chosen sector. We need to handle the case
	-- where the chosen destination is the default one as otherwise the merc will be
	-- added to their own squad a second time.
	local merc = gv_UnitData[merc_id]
	local prevArrivingSquad = merc.Squad
	
	local unitArriveTime = GetOperationTimeLeft(merc, "Arriving")
	local newMercSector = sector_id or GetCurrentCampaignPreset().InitialSector
	local squadToAddIn
	for i, s in ipairs(GetPlayerMercSquads()) do
		if s.Side == "player1" and s.CurrentSector == newMercSector and s.arrival_squad then

			-- Check when the arrival will end for units in this squad
			local willArriveWithThisSquad = true
			for i, u in ipairs(s.units) do
				local ud = gv_UnitData[u]
				local left = GetOperationTimeLeft(ud, "Arriving")
				if left ~= unitArriveTime then
					willArriveWithThisSquad = false
					break
				end
			end
			
			if #s.units >= const.Satellite.MercSquadMaxPeople then
				willArriveWithThisSquad = false
			end
			
			if willArriveWithThisSquad then
				squadToAddIn = s
				break
			end
			
		end
	end
	
	local bestArrivalDir = false
	local sector = gv_Sectors[newMercSector]
	ForEachSectorAround(newMercSector, 1, function(otherSector)
		if IsTravelBlocked(otherSector, newMercSector) then return end
		
		local otherSectorPreset = gv_Sectors[otherSector]
		if otherSectorPreset.Passability ~= "Water" and otherSectorPreset.Passability ~= "Land and Water" then return end
		
		local dir = GetSectorDirection(newMercSector, otherSector)
		bestArrivalDir = dir
	end)
	if bestArrivalDir then
		merc.arrival_dir = bestArrivalDir
	end
	
	local squad_id = squadToAddIn and squadToAddIn.UniqueId
	if prevArrivingSquad and squadToAddIn and squadToAddIn.UniqueId == prevArrivingSquad then
		return
	end
	if squadToAddIn then
		AddUnitsToSquad(squadToAddIn, {merc_id}, days, days and InteractionRand(nil, "Satellite"))	
	else
		squad_id = CreateNewSatelliteSquad({
				Side = "player1",
				CurrentSector = newMercSector,
				Name = Presets.SquadName.Default.Arriving.Name,
				arrival_squad = true
			}, {merc_id}, days)
	end
	
	if merc.Operation == "Arriving" then
		Msg("OperationChanged", merc, "Arriving", "Arriving")
	end
end

if FirstLoad then
	FilterUserTextsThread = false
end

function OnMsg.LoadGame()
	DeleteThread(FilterUserTextsThread)
end

function OnMsg.NewGame()
	DeleteThread(FilterUserTextsThread)
end

LoadingUnitName = T{977270273792, --[[ Merc Nick awaiting filtering; Limit to 8 characters ]] "Loading" }

---
--- Hires a merc and handles the associated logic, such as extending an existing contract, logging the hire, and updating the merc's state.
---
--- @param merc_id number The ID of the merc to be hired.
--- @param price number The price to be paid for hiring the merc.
--- @param medical number The medical cost associated with hiring the merc.
--- @param days number The number of days the merc is being hired for.
--- @return nil
function LocalHireMerc(merc_id, price, medical, days)
	local alreadyHired = gv_UnitData[merc_id] and gv_UnitData[merc_id].Squad
	local unitData = gv_UnitData[merc_id]
	
	if IsUserText(unitData.Nick) then 
		local loading = _InternalTranslate(LoadingUnitName)
		SetCustomFilteredUserTexts({ unitData.Nick, unitData.Name }, { loading, loading })
	end
	
	FilterUserTextsThread = CreateRealTimeThread(function()
		if IsUserText(unitData.Nick) then 
			local errors = AsyncFilterUserTexts({ unitData.Nick, unitData.Name })
			if errors then
				for _, err in ipairs(errors) do
					SetCustomFilteredUserText(err.user_text)
				end
			end
			Msg("TranslationChanged")
		end
		
		local timeFormatted = days and FormatCampaignTime(days * const.Scale.day, "in_days") or ""
		if alreadyHired then
			local newTotal = FormatCampaignTime((unitData.HiredUntil + days * const.Scale.day) - Game.CampaignTime, "in_days")
			CombatLog("short", T{595935156980, "<MercName> contract extended by <duration> (<newTotal>)",
				duration = timeFormatted,
				MercName = unitData.Name,
				newTotal = newTotal
			})
		elseif days then
			CombatLog("short", T{537438751389, "Hired <MercName> for <duration> (<money(price)>)", duration = timeFormatted, MercName = unitData.Nick or unitData.Name,price = price})
		else
			CombatLog("short", T{157053856815, "Hired <MercName> (<money(price)>)", MercName = unitData.Nick or unitData.Name, price = price})
		end
		FilterUserTextsThread = false
	end)

	AddMoney(-price, "salary", "noCombatLog")
	SetMercStateFlag(merc_id, "LastHirePayment", price)
	
	local currentDailySalary = (price and days) and DivRound(price - medical, days) or 0
	SetMercStateFlag(merc_id, "CurrentDailySalary", currentDailySalary)
	
	if alreadyHired then
		days = days or 0
		
		-- When the contract expires it is possible for a couple minutes extra to have passed
		-- due to rounding of satellite ticks. Since we want the UI to display the exact time
		-- in days when hired (ex. 3D instead of 2D 57m) we clamp the time to the campaign time
		-- if it is in the past.
		if not unitData.HiredUntil or unitData.HiredUntil < Game.CampaignTime then
			unitData.HiredUntil = Game.CampaignTime
		end
		unitData.HiredUntil = unitData.HiredUntil + days*const.Scale.day
		if g_Units[merc_id] then
			g_Units[merc_id].HiredUntil = unitData.HiredUntil
		end
		Msg("MercContractExtended", unitData)
	else
		-- Initial mercs arrive instantly.
		LocalSetArrivingMercSector(merc_id, false, days)
		NetSyncEvents.MercSetOperation(merc_id, "Arriving")
		
		-- Compensate contract with arrival time
		if unitData.HiredUntil then
			local arrivalTime = SectorOperations.Arriving:ProgressCompleteThreshold(unitData)
			unitData.HiredUntil = unitData.HiredUntil + arrivalTime
			Msg("UnitUpdateTimelineContractEvent", merc_id)
		end
		if not g_CurrentSquad then g_CurrentSquad = unitData.Squad end
	end
	
	ObjModified(unitData)
	ObjModified("coop button")
	ObjModified("MercHired")
	Msg("MercHired", merc_id, price, days, alreadyHired)
	gv_UnitData[merc_id]:CallReactions("OnMercHired", price, days, alreadyHired)
end

---
--- Returns the time it takes for a merc to arrive at a sector.
---
--- If the initial conflict has not started yet, the arrival time is halved.
---
--- @return number The time it takes for a merc to arrive at a sector, in hours.
---
function GetMercArrivalTime()
	if InitialConflictNotStarted() then return const.Satellite.MercArrivalTime / 2 end
	return const.Satellite.MercArrivalTime
end

---
--- Returns the time it takes for a merc to arrive at a sector, in hours.
---
--- If the initial conflict has not started yet, the arrival time is halved.
---
--- @return number The time it takes for a merc to arrive at a sector, in hours.
---
function TFormat.MercArrivalTimeHours()
	return GetMercArrivalTime() / const.Scale.h
end

local lArrivalDelayed = false
local lArrivedMercsQueue = false
local function lArrivalFxDelayed(merc, sectorId)
	if IsValidThread(lArrivalDelayed) then 
		lArrivedMercsQueue[#lArrivedMercsQueue + 1] = merc
		return
	end
	lArrivedMercsQueue = { merc }
	lArrivalDelayed = CreateMapRealTimeThread(function()
		WaitAllOtherThreads()

		local perSector = {}
		for i, m in ipairs(lArrivedMercsQueue) do
			local squad = gv_Squads[m.Squad]
			local sector = squad and squad.CurrentSector
			if not perSector[sector] then
				perSector[sector] = { m }
			else
				table.insert(perSector[sector], m)
			end
		end
		
		for sectorId, mercs in sorted_pairs(perSector) do
			local spawnedSectorName = GetSectorName(gv_Sectors[sectorId])
			
			local mercName = false
			local mercVr = false
			
			if #mercs == 1 then
				local merc = mercs[1]
				mercName = merc.Nick
				mercVr = merc

			else
				local nicks = {}
				for i, merc in ipairs(mercs) do
					nicks[#nicks + 1] = merc.Nick
				end
				mercName = ConcatListWithAnd(nicks)
				mercVr = table.rand(mercs)
			end
			
			CombatLog("important", T{540838596254, "<MercNick> arrived in <sectorName>", {
				MercNick = mercName,
				sectorName = spawnedSectorName
			}})
			PlayVoiceResponse(mercVr, "SectorArrived")
		end
	end)
end

---
--- Handles the arrival of a hired merc in the game world.
---
--- @param merc table The merc that has arrived.
--- @param days number The number of days the merc has been hired for.
---
function HiredMercArrived(merc, days)
	local merc_id = merc.session_id

	-- Find sector to place in.
	local arrivalSquad = merc.Squad
	if arrivalSquad then
		arrivalSquad = gv_Squads[arrivalSquad]
	end
	local newMercSector = arrivalSquad and arrivalSquad.CurrentSector
	newMercSector = newMercSector or GetCurrentCampaignPreset().InitialSector
	
	local squadToAddIn
	for i, s in ipairs(GetPlayerMercSquads()) do
		if not s.arrival_squad and s.CurrentSector == newMercSector and not IsSquadTravelling(s) and #s.units < const.Satellite.MercSquadMaxPeople then
			squadToAddIn = s
			break
		end
	end
	
	if squadToAddIn then
		if days then -- Just hired
			AddUnitsToSquad(squadToAddIn, {merc_id}, days, InteractionRand(nil, "Satellite"))
		else -- Actually arrived
			AddUnitToSquad(squadToAddIn.UniqueId, merc_id)
		end
	else
		CreateNewSatelliteSquad({
			Side = "player1",
			CurrentSector = newMercSector,
			Name = SquadName:GetNewSquadName("player1"),
			image = arrivalSquad and arrivalSquad.image
		}, {merc_id}, days)
	end
	
	if not days then
		lArrivalFxDelayed(merc)
	end
	
	merc:SetCurrentOperation("Idle")
	ObjModified(arrivalSquad)
end

---
--- Handles the network synchronization of hiring a mercenary.
---
--- @param merc_id string The ID of the mercenary being hired.
--- @param price number The price paid to hire the mercenary.
--- @param medical boolean Whether the mercenary has medical training.
--- @param days number The number of days the mercenary is hired for.
--- @param player_id string The ID of the player hiring the mercenary.
---
function NetSyncEvents.HireMerc(merc_id, price, medical, days, player_id)
	local alreadyHired = gv_UnitData[merc_id] and gv_UnitData[merc_id].Squad

	LocalHireMerc(merc_id, price, medical, days)
	
	-- Give control to the player that hired the merc, unless the merc was already hired
	-- which means their contract was extended
	if player_id and not alreadyHired then
		local ud = gv_UnitData[merc_id]
		ud.ControlledBy = player_id
	end
end

---
--- Creates an IMP mercenary data object based on the provided IMP test results.
---
--- @param impTest table The IMP test results.
--- @param sync boolean Whether this is a synchronization operation.
--- @return table The created IMP mercenary data object.
---
function CreateImpMercData(impTest, sync)
	if sync then
		g_ImpTest = impTest
	end
	local merc_id = impTest.final.merc_template.id
	local unitData = gv_UnitData[merc_id]
	local uni_template = UnitDataDefs[unitData.class]
	-- sets default values the first time merc is created
	if not impTest.final.nick then 
		impTest.final.nick = CreateUserText(_InternalTranslate(uni_template.Nick), "name") 
	end
	if not impTest.final.name then 
		impTest.final.name = CreateUserText(_InternalTranslate(uni_template.Name), "name") 
	end
	-- transfer stats, perks, names, nick
	if impTest.final.nick == "" then
		impTest.final.nick = CreateUserText("", "name")
	end
	if impTest.final.name == "" then
		impTest.final.name = CreateUserText("", "name")
	end
	unitData.Nick = impTest.final.nick
	unitData.Name = impTest.final.name
	--specialization and stats
	local stat_specialization_map = {Marksmanship = "Marksmen", Leadership="Leader", Medical = "Doctor", Explosives="ExplosiveExpert", Mechanical="Mechanic"}
	local max_stat
	local specialization = "AllRounder"
	for _, stat_data in ipairs(impTest.final.stats) do
		unitData:SetBase(stat_data.stat,stat_data.value)
		local spec = stat_specialization_map[stat_data.stat]
		if spec and (not max_stat and stat_data.value>80  or max_stat and stat_data.value> max_stat) then
			max_stat = stat_data.value
			specialization = spec
		end
	end
	unitData.Specialization = specialization
	unitData:InitDerivedProperties()
	
	if sync then
		unitData:RemoveAllCharacterEffects()
		
		if impTest.final.perks.personal and impTest.final.perks.personal.perk then
			unitData:AddStatusEffect(impTest.final.perks.personal.perk)
		end
		if impTest.final.perks.tactical then
			for i, perk_data in ipairs(impTest.final.perks.tactical) do
				if perk_data.perk then
					unitData:AddStatusEffect(perk_data.perk)
				end
			end
		end
	end
	return unitData
end

---
--- Hires an IMP merc and sets up the necessary data.
---
--- @param impTest table The IMP test data for the merc.
--- @param merc_id number The ID of the merc to hire.
--- @param price number The price to hire the merc.
--- @param days number The number of days to hire the merc for.
---
function NetSyncEvents.HireIMPMerc(impTest, merc_id, price, days)
	local unitData = CreateImpMercData(impTest, "sync")
	CombatLog("debug", "Imp Test final - " .. DbgImpPrintResult(impTest.final, "flat"))
	LocalHireMerc(merc_id, price, 0, days)
end

---
--- Releases a merc from the player's squad.
---
--- @param merc_id number The ID of the merc to release.
---
function NetSyncEvents.ReleaseMerc(merc_id)
	local unit = g_Units[merc_id] -- Could be on another map
	if not gv_SatelliteView and unit then
		unit:SyncWithSession("map")
		unit:Despawn()
	end

	local unit_data = gv_UnitData[merc_id]
	local squadId = unit_data.Squad
	SectorOperation_CancelByGame({unit_data}, false, true)

	PlayVoiceResponse(unit_data, "ContractExpired")
	
	-- Send inventory to stash
	local squad = gv_Squads[squadId]
	local sectorId = squad.CurrentSector

	local items = {}
	unit_data:ForEachItemInSlot("Inventory", function(item, _, x, y, items)
		if not item.locked then
			items[#items + 1] = item
		end
	end, items)
	AddToSectorInventory(sectorId,items)
	unit_data:ForEachItemInSlot("Inventory", function(item, slot, left, top, unit_data, sectorId)
		if not item.locked then
			unit_data:RemoveItem("Inventory", item, "no_update")
			NetUpdateHash("NetSyncEvents.ReleaseMerc_moving_items_params", item.class, item.id, sectorId)
		end	
	end, unit_data, sectorId)
	
	RemoveUnitFromSquad(unit_data, "despawn")
	unit_data.Squad = false
	unit_data.HiredUntil = false
	unit_data.HireStatus = "Available"
	Msg("MercHireStatusChanged", unit_data, "Hired", "Available")
	Msg("MercReleased", unit_data, squadId)
	NetSyncEvent("CheckUnitsMapPresence")
	DelayedCall(0, ObjModified, gv_Squads)
	
	if not gv_SatelliteView and unit then
		EnsureCurrentSquad()
	end
end

---
--- Adds a list of units to a squad.
---
--- @param squad table The squad to add the units to.
--- @param unit_ids table A list of unit IDs to add to the squad.
--- @param days number The number of days the units will be hired for.
--- @param seed number A random seed to use for generating the units.
---
function AddUnitsToSquad(squad, unit_ids, days, seed)
	if not squad.units then
		squad.units = {}
	end
	local hire = squad.Side == "player1"
	for _, unit_id in ipairs(unit_ids or empty_table) do
		local unit_data = gv_UnitData[unit_id] -- All mercs should be predefined from the start
		if not unit_data then unit_data = CreateUnitData(unit_id, false, seed) end -- Just in case

		AddUnitToSquad(squad.UniqueId, unit_id, false, #unit_ids > 1)
		if hire then
			if unit_data.HireStatus ~= "Hired" then
				assert(false, "AddUnitToSquad didnt set hired?")
				unit_data.HireStatus = "Hired"
				Msg("MercHireStatusChanged", unit_data, "Available", "Hired")
			end

			if days then
				unit_data.HiredUntil = Game.CampaignTime + days*const.Scale.day
			end
		end
	end
	
	ObjModified(gv_Squads)
	ObjModified(squad)
	
	-- check imp
	--Msg("UnitJoinedPlayerSquad", squad.UniqueId)
end

---
--- Gets a random squad logo that has not been used by any player squad.
---
--- @return string The path to the random squad logo image.
---
function GetRandomSquadLogo()
	local logos = g_SquadLogos
	local filteredLogos = {}
	
	for i, logo in ipairs(logos) do
		local used = false
		for _, squad in ipairs(g_PlayerSquads) do
			if squad.image == logo then
				used = true
				break
			end
		end
		if not used then
			filteredLogos[#filteredLogos+1] = logo
		end
	end
	
	if #filteredLogos > 0 then
		return filteredLogos[InteractionRand(#filteredLogos, "SquadLogo") + 1]
	else
		return logos[InteractionRand(#logos, "SquadLogo") + 1]
	end
end

---
--- Creates a new satellite squad with the given properties and units.
---
--- @param predef_props table The predefined properties for the new squad.
--- @param unit_ids table The IDs of the units to be added to the new squad.
--- @param days number The number of days the units will be hired for.
--- @param seed number The seed to use for randomization.
--- @param enemy_squad_def table The definition of the enemy squad.
--- @param reason string The reason for creating the new squad.
--- @return number The unique ID of the new squad.
---
function CreateNewSatelliteSquad(predef_props, unit_ids, days, seed, enemy_squad_def, reason)
	NetUpdateHash("CreateNewSatelliteSquad", hashParamTable(unit_ids), days, seed)
	local squad = SatelliteSquad:new(predef_props)
	local id = gv_NextSquadUniqueId
	
	if not squad.image then
		local is_player = squad.Side == "player1" or squad.Side == "player2"
		if is_player then
			squad.image = GetRandomSquadLogo()
		elseif squad.militia then
			squad.image = "UI/Icons/SateliteView/militia"
		else
			squad.image = "UI/Icons/SateliteView/enemy_squad"
		end
	end
	
	squad.UniqueId = id
	squad.enemy_squad_def = enemy_squad_def
	gv_Squads[id] = squad
	AddSquadToLists(squad)
	gv_NextSquadUniqueId = id + 1
	local current_sector = squad.CurrentSector
	local previous_sector = squad.PreviousSector
	AddUnitsToSquad(squad, unit_ids, days, seed or InteractionRand(nil, "Satellite"))
	
	if current_sector and not squad.arrival_squad and not predef_props.XVisualPos then
		SatelliteReachSectorCenter(id, current_sector, previous_sector, nil, nil, reason)
	end
	Msg("SquadSpawned", id, current_sector)

	return id
end

---
--- Adds a unit to the specified squad.
---
--- @param squad_id number The unique ID of the squad to add the unit to.
--- @param unit_id number The unique ID of the unit to add to the squad.
--- @param position number (optional) The position in the squad's unit list to insert the unit at. If not provided, the unit will be added to the end of the list.
--- @param multiple boolean (optional) If true, the function will not trigger any modification events.
---
function AddUnitToSquad(squad_id, unit_id, position, multiple)
	NetUpdateHash("AddUnitToSquad", squad_id, unit_id, position, multiple)
	local squad = gv_Squads[squad_id]
	local unit_data = gv_UnitData[unit_id]
	assert(squad)
	if not unit_data then return end
	
	local prev_squad_id = unit_data.Squad
	if prev_squad_id then
		OnChangeUnitSquad(unit_data, prev_squad_id, squad_id)
	end	
	RemoveUnitFromSquad(unit_data, "move")
	if position and position <= #squad.units then
		table.insert(squad.units, position, unit_id)
	else
		table.insert(squad.units, unit_id)
	end
	unit_data.Squad = squad.UniqueId
	if g_Units[unit_data.session_id] then
		g_Units[unit_data.session_id].Squad = squad.UniqueId
	end

	if not multiple then
		ObjModified(gv_Squads)
		ObjModified(squad)
	end
	if squad.Side == "player1" then
		if unit_data.HireStatus ~= "Hired" then
			unit_data.HireStatus = "Hired"
			if g_Units[unit_data.session_id] then
				g_Units[unit_data.session_id].HireStatus = "Hired"
			end
			Msg("MercHireStatusChanged", unit_data, "Available", "Hired")
		end
		Msg("UnitJoinedPlayerSquad", squad_id, unit_id)
	end
end

function OnMsg.MercHireStatusChanged(unitData, old, new)
	local unit = g_Units[unitData.session_data]
	if unit then
		unit.HireStatus = new
	end
end

--- Removes a unit from a squad.
---
--- @param unit_data table The unit data of the unit to remove from the squad.
--- @param reason string (optional) The reason for removing the unit from the squad, such as "despawn".
function RemoveUnitFromSquad(unit_data, reason)
	local squad_id = unit_data.Squad
	local squad = gv_Squads[squad_id]
	unit_data.OldSquad = squad_id
	unit_data.Squad = false
	if g_Units[unit_data.session_id] then
		-- Mercs will be automatically despawned when their UnitData doesn't have an associated squad.
		local unit = g_Units[unit_data.session_id]
		unit.OldSquad = squad_id
		if reason=="despawn" then
			unit.session_id = false
		end
		-- We want to show dead mercs on the map as part of the squad (if they are not the last member of that squad)
		if not (unit:IsDead() and unit:IsMerc() and squad and #squad.units > 1) then
			unit.Squad = false
		else
			unit_data.Squad = squad_id
		end
	end
	
	if not squad then
		return
	end

	table.remove_value(squad.units, unit_data.session_id)
	
	-- There is some bug with millitia units being present twice in 
	-- their squad for some reason 0.0
	while table.find(squad.units, unit_data.session_id) do
		assert(false) -- Unit was in the squad twice+ 0.0
		table.remove_value(squad.units, unit_data.session_id)
	end
	
	if not squad.units or #squad.units == 0 then
		Msg("PreSquadDespawned", squad_id, squad.CurrentSector, reason)
		if squad.militia then
			local sector = gv_Sectors[squad.CurrentSector]
			if sector then
				sector.militia_squad_id = false
			end
		end
		RemoveSquadsFromLists(gv_Squads[squad_id])
		gv_Squads[squad_id] = nil
		Msg("SquadDespawned", squad_id, squad.CurrentSector, squad.Side)
	end
	ObjModified(squad)
end

--- Removes all units from the given squad and despawns the squad.
---
--- @param squad table The squad to remove.
function RemoveSquad(squad)
	local units = squad.units or empty_table
	for i = #units, 1, -1 do
		RemoveUnitFromSquad(gv_UnitData[units[i]])
	end
end

---
--- Checks if a unit can join a squad that is far away from its current location.
---
--- @param unit_data table The unit data of the unit that is trying to join the squad.
--- @param squadFrom table The squad that the unit is currently in.
--- @param squadTo table The squad that the unit is trying to join.
--- @return string|nil "break" if the unit was successfully assigned to the new squad, nil otherwise.
---
function CheckSquadJoiningFarAway(unit_data, squadFrom, squadTo)
	local oldSquad = squadFrom
	local squad = squadTo
	
	-- If exact same pos via pause
	local squadFromPos = GetSquadVisualPos(squadFrom)
	local squadToPos = GetSquadVisualPos(squadTo)
	if squadFromPos and squadFromPos == squadToPos then
		return
	end
	
	local destination = GetSquadFinalDestination(squad.CurrentSector, squad.route)
	if squadFrom.CurrentSector == destination and
		not IsTraversingShortcut(squadFrom) and
		not IsTraversingShortcut(squadTo) then -- No need to path find.
		NetSyncEvent("JoinFarAwaySquad", unit_data.session_id, squad.UniqueId, oldSquad.UniqueId)
		return "break"
	end
	
	if WaitQuestion(terminal.desktop,
		T(824112417429, "Warning"),
		T{984693643526, "<squadName> is in sector <SectorId(sector)>. Do you want to send <mercNick> to sector <SectorId(sector)>?",
			squadName = Untranslated(squad.Name),
			sector = destination,
			mercNick = unit_data.Nick
		},
		T(689884995409, "Yes"),
		T(782927325160, "No")) == "ok"
	then
		-- 1. Assign to squad on shortcut (to squad at destination, squad at source)
		-- 2. Assign from squad on shortcut (to squad at destination, squad at source)
		local route = false
		if IsTraversingShortcut(oldSquad) then
			local shortcutDestination = GetSquadFinalDestination(oldSquad, oldSquad.route)
			local currentShortcutRoute = { oldSquad.route[1][1], shortcuts = { 1 } }
			
			if destination == shortcutDestination then
				route = { currentShortcutRoute }
			else
				route = GenerateRouteDijkstra(shortcutDestination, destination, false, empty_table, nil, nil, squad.Side)
				route = { currentShortcutRoute, route }
			end
		else
			route = GenerateRouteDijkstra(oldSquad.CurrentSector, destination, false, empty_table, nil, nil, squad.Side)
			route = {route} --waypointify
		end

		if unit_data:HasStatusEffect("Exhausted") then
			ShowExhaustedUnitsQuestion(oldSquad, {unit_data})
		elseif route then
			NetSyncEvent("JoinFarAwaySquad", unit_data.session_id, squad.UniqueId, oldSquad.UniqueId, route)
		else
			WaitMessage(terminal.desktop,
				T(824112417429, "Warning"),
				T{345921875430, "Couldn't find route to <SectorId(destination)>.", destination = destination},
				T(325411474155, "OK")
			)
		end
		return "break"
	else
		return "break"
	end
end

---
--- Attempts to swap the positions of two units in different squads.
---
--- If the units are in the same squad, their positions within that squad are swapped.
--- If the units are in different squads, the function checks if the squads are in conflict or if the units have not arrived at their initial sector. If either of these conditions is true, the swap is not allowed.
--- If the swap is allowed, the function uses the `NetSyncEvent` function to update the squad assignments for the two units.
---
--- @param unit_data1 table The unit data for the first unit to be swapped.
--- @param unit_data2 table The unit data for the second unit to be swapped.
function TrySwapMercs(unit_data1, unit_data2)
	local squad1 = unit_data1.Squad
	local squad1Obj = gv_Squads[squad1]
	local squad2 = unit_data2.Squad
	local squad2Obj = gv_Squads[squad2]
	local position1 = table.find(squad1Obj.units, unit_data1.session_id)
	local position2 = table.find(squad2Obj.units, unit_data2.session_id)

	-- Swap within same squad.
	if squad1 == squad2 then
		if unit_data1 == unit_data2 then return end
		NetSyncEvent("AssignUnitToSquad", squad2, unit_data1.session_id, position2, nil, true)
		NetSyncEvent("AssignUnitToSquad", squad1, unit_data2.session_id, position1)
		return
	end
	
	-- If both squads contain one unit each then swapping is not allowed.
	-- (What do we expect to happen here? Swap the squad names?)
	if #squad1Obj.units == 1 and #squad2Obj.units == 1 then
		return
	end
	
	-- The squad that has only one unit needs
	-- to be swapped second to prevent
	-- the squad from being destroyed.
	if #squad1Obj.units == 1 then
		squad1Obj, squad2Obj = squad2Obj, squad1Obj
		squad1, squad2 = squad2, squad1
		position1, position2 = position2, position1
		unit_data1, unit_data2 = unit_data2, unit_data1
	end

	CreateRealTimeThread(function()
		local sector1 = gv_Sectors[squad1Obj.CurrentSector]
		local sector2 = gv_Sectors[squad2Obj.CurrentSector]
	
		-- check if merc has arrived to his initial sector (for newly hired mercs)
		if not sector1 or not sector2 or squad1Obj.arrival_squad or squad2Obj.arrival_squad then
			WaitMessage(terminal.desktop,
				T(824112417429, "Warning"),
				T(974403355605, "You can't reassign newly hired mercs who have not arrived in Grand Chien yet."),
				T(325411474155, "OK")
			)
			return
		end
	
--[[		if sector1 ~= sector2 and sector1.conflict or sector2.conflict then
			WaitMessage(terminal.desktop,
				T(824112417429, "Warning"),
				T(587785554300, "You can't reassign mercs to a squad in conflict."),
				T(325411474155, "OK")
			)
			return
		end]]
		
		if sector1 ~= sector2 then
			-- But don't allow retreating from/to underground when there is a conflict (via squad management)
			if IsConflictMode(sector1.CurrentSector) or IsConflictMode(sector2.CurrentSector) then
				return
			end
		
			local resp1 = CheckSquadJoiningFarAway(unit_data1, squad1Obj, squad2Obj)
			local resp2 = CheckSquadJoiningFarAway(unit_data2, squad2Obj, squad1Obj)
			if resp1 == "break" or resp2 == "break" then return end
		end
		
		NetSyncEvent("AssignUnitToSquad", squad2, unit_data1.session_id, position2)
		NetSyncEvent("AssignUnitToSquad", squad1, unit_data2.session_id, position1)
	end)
end

---
--- Attempts to assign a unit to a squad.
---
--- @param unit_data table The unit data to be assigned.
--- @param squad_id number The ID of the squad to assign the unit to.
--- @param position number The position in the squad to assign the unit to.
---
function TryAssignUnitToSquad(unit_data, squad_id, position)
	local newSquad = not squad_id or squad_id < 0
	local squad = gv_Squads[squad_id]
	
	-- Moving to the same squad.
	if squad_id == unit_data.Squad and not position then
		return
	end
	
	if not unit_data or not newSquad and not gv_Squads[squad_id] then
		assert(false)
		return
	end

	CreateRealTimeThread(function()
		local oldSquad = gv_Squads[unit_data.Squad]
		local oldSector = oldSquad and oldSquad.CurrentSector

		if not newSquad then
			local unitCount, unitCountWithJoining = GetSquadUnitCountWithJoining(squad_id)

			-- Check if trying to join a full squad.
			if unitCount >= const.Satellite.MercSquadMaxPeople then
				return
			end
			
			if unitCountWithJoining >= const.Satellite.MercSquadMaxPeople then
				WaitMessage(terminal.desktop,
					T(824112417429, "Warning"),
					T(764068678037, "That squad will be full when units traveling towards it join."),
					T(325411474155, "OK")
				)
				return
			end
		end
		
		-- Check if trying to join the squad already joining.
		if not newSquad and oldSquad and oldSquad.joining_squad == squad.UniqueId then
			return
		end
		
		-- Check if new squad is in conflict. (But only if there was a previous sector)
--[[		local sector = not newSquad and oldSector and gv_Sectors[squad.CurrentSector]
		if not newSquad and sector and sector.conflict and oldSector ~= sector.Id then
			WaitMessage(terminal.desktop,
				T(824112417429, "Warning"),
				T(587785554300, "You can't reassign mercs to a squad in conflict."),
				T(325411474155, "OK")
			)
			return
		end]]
		
		-- check if merc has arrived to his initial sector (for newly hired mercs)
		if oldSquad and (not oldSquad.CurrentSector or oldSquad.arrival_squad) then
			WaitMessage(terminal.desktop,
				T(824112417429, "Warning"),
				T(974403355605, "You can't reassign newly hired mercs who have not arrived in Grand Chien yet."),
				T(325411474155, "OK")
			)
			return
		end

		if squad and (not squad.CurrentSector or squad.arrival_squad) then
			WaitMessage(terminal.desktop,
				T(824112417429, "Warning"),
				T(902906854574, "You can't reassign mercs to squads arriving in Grand Chien."),
				T(325411474155, "OK")
			)
			return
		end

		if not newSquad and oldSquad then
		
			-- Squads can join other squads that are above/underground on the same sector.
			local oldSquadSectorGround = oldSquad.CurrentSector
			oldSquadSectorGround = gv_Sectors[oldSquadSectorGround].GroundSector or oldSquadSectorGround
			local newSquadSectorGround = squad.CurrentSector
			newSquadSectorGround = gv_Sectors[newSquadSectorGround].GroundSector or newSquadSectorGround
			
			-- But don't allow retreating from/to underground when there is a conflict (via squad management)
			if IsConflictMode(oldSquad.CurrentSector) and oldSquad.CurrentSector ~= squad.CurrentSector then
				return
			end
			
			local squadTravelling = IsSquadTravelling(squad) or squad.Retreat
			local oldSquadTravelling = IsSquadTravelling(oldSquad) or oldSquad.Retreat
			
			if newSquadSectorGround ~= oldSquadSectorGround or
				IsTraversingShortcut(oldSquad) or oldSquadTravelling or
				IsTraversingShortcut(squad) or squadTravelling then
				if CheckSquadJoiningFarAway(unit_data, oldSquad, squad) == "break" then return end
			end
		end

		NetSyncEvent("AssignUnitToSquad", squad and squad.UniqueId, unit_data.session_id, position, newSquad)
		if oldSquad then ObjModified(oldSquad) end
		ObjModified(newSquad)
	end)
end

--- Sets the logo image for the specified squad.
---
--- @param squad_id string The unique identifier of the squad.
--- @param image string The image to set as the squad's logo.
function NetSyncEvents.SetSquadLogo(squad_id, image)
	local s = gv_Squads[squad_id]
	assert(s)
	s.image = image
	ObjModified(s)
end

--- Assigns a unit to a squad.
---
--- @param squad_id string The unique identifier of the squad to assign the unit to.
--- @param unit_id string The unique identifier of the unit to assign.
--- @param position number The position within the squad to assign the unit to.
--- @param create_new_squad boolean Whether to create a new squad for the unit.
--- @param swap boolean Whether to swap the unit with another unit in the squad.
function NetSyncEvents.AssignUnitToSquad(squad_id, unit_id, position, create_new_squad, swap)
	local unit_data = gv_Squads and gv_UnitData[unit_id]
	if not unit_data then
		return
	end
	if create_new_squad then
		local squadCreationProps = {
			Side = "player1",
			Name = SquadName:GetNewSquadName("player1")
		}
		
		-- Copy properties from the old squad
		local oldSquad = gv_Squads[unit_data.Squad]
		if oldSquad then
			squadCreationProps.CurrentSector = oldSquad.CurrentSector
			squadCreationProps.PreviousSector = oldSquad.PreviousSector
			squadCreationProps.PreviousLandSector = oldSquad.PreviousLandSector
			squadCreationProps.XVisualPos = GetSquadVisualPos(oldSquad)
		end

		squad_id = CreateNewSatelliteSquad(squadCreationProps, {unit_id})
		
		-- If the squad this unit was ejected from is traveling, 
		-- the new squad should travel to the next sector the old squad
		-- was travelling to, or align itself to the current sector if
		-- pre-reaching the current sector center.
		local newSquad = gv_Squads[squad_id]
		if oldSquad.route and IsSquadTravelling(oldSquad, oldSquad.Retreat and "tick-regardless") then
			local oldRoute = oldSquad.route
			local newRoute = {}
			newRoute.satellite_tick_passed = oldRoute.satellite_tick_passed
			if oldSquad.water_travel then
				newRoute = table.copy(oldSquad.route, "deep")
				newRoute.water_route_assignment_route = true
			else
				local nextSector = oldRoute[1][1]
				assert(nextSector)
				newRoute[1] = { nextSector }
				
				-- This will prevent this route from being cancelled and
				-- visually will act as a cancelled travel. Align to current.
				if nextSector == newSquad.CurrentSector then
					newRoute[1].returning_land_travel = true
				end
			end
			
			if IsTraversingShortcut(oldSquad, oldSquad.Retreat and "tick-regardless") then
				newRoute[1].shortcuts = { 1 }
				newSquad.traversing_shortcut_start = oldSquad.traversing_shortcut_start
				newSquad.traversing_shortcut_start_sId = oldSquad.traversing_shortcut_start_sId
				newSquad.traversing_shortcut_water = oldSquad.traversing_shortcut_water
			end

			SetSatelliteSquadRoute(newSquad, newRoute)
			newSquad.Retreat = oldSquad.Retreat
			
			if oldSquad.water_travel then
				assert(newSquad.water_travel)
				newSquad.water_travel_cost = oldSquad.water_travel_cost
				newSquad.water_travel_rest_timer = oldSquad.water_travel_rest_timer
				newSquad.water_route = table.find(oldSquad.water_route, "deep")
				newRoute.water_route_assignment_route = false
			end
		end
		
		-- This merc was retreated but the whole squad didnt get marked as
		-- retreating because the other mercs weren't retreated.
		if unit_data.retreat_to_sector and not newSquad.Retreat then
			local instant = RetreatMoveWholeSquad(newSquad.UniqueId, unit_data.retreat_to_sector, newSquad.CurrentSector)
			if not instant then
				newSquad.Retreat = true
			end
		end
	else
		local oldSquad = gv_Squads[unit_data.Squad]
		local newSquad = gv_Squads[squad_id]
		
		AddUnitToSquad(squad_id, unit_id, position, swap)
		
		-- Non-retreating unit moved into a retreating squad - squad stops retreating.
		-- If the retreat route was instant (to underground sector for instance),
		-- then the transfer should be invalid as the new squad would be in a different sector
		if newSquad.Retreat and not oldSquad.Retreat and not unit_data.retreat_to_sector then
			newSquad.Retreat = false
			SetSatelliteSquadRoute(newSquad, false)
		end
	end
	Msg("UnitAssignedToSquad", squad_id, unit_id, create_new_squad)
	ObjModified("hud_squads")
	
	-- If just moved to a retreating squad, this means that there might not
	-- be a non-retreating squad left here. Retreat via squad management xd (234437)
	local newSquad = gv_Squads[squad_id]
	if newSquad.Retreat then
		local sectorId = newSquad.CurrentSector
		local allySquads, enemySquads = GetSquadsInSector(sectorId, "excludeTravel", "includeMilitia", "excludeArrive", "excludeRetreat")
		local playerHere = #allySquads > 0
		if not playerHere then
			local sector = gv_Sectors[sectorId]
			assert(sector.conflict)
			if sector.conflict then
				ResolveConflict(sector, "no voice", false, "retreat")
			end
		end
	end
end

---
--- Reconstructs the names of squads that are being joined by units traveling from other sectors.
--- This function is called when the game session data is being gathered, to ensure the squad names are properly set.
---
--- The function iterates through all squads in the `gv_Squads` table, and for any squad that has the `joining_squad` field set, it generates a new name for the squad using the `GenerateJoiningSquadName` and `GenerateJoiningSquadName_Short` functions.
---
--- The generated name includes the nickname of the unit that is traveling to the squad, as well as the name of the squad that the unit is joining.
---
--- @function ReconstructJoiningSquadNames
--- @return nil
function ReconstructJoiningSquadNames()
	for _, squad in pairs(gv_Squads) do
		if squad.joining_squad then
			assert(#squad.units == 1, "Empty squad name should only happen when a single unit is traveling to squad in different sector.")
			squad.Name = GenerateJoiningSquadName(gv_UnitData[squad.units[1]].Nick, gv_Squads[squad.joining_squad] and gv_Squads[squad.joining_squad].Name or SquadName:GetNewSquadName("player1"))
			squad.ShortName = GenerateJoiningSquadName_Short(gv_UnitData[squad.units[1]].Nick, gv_Squads[squad.joining_squad] and gv_Squads[squad.joining_squad].Name or SquadName:GetNewSquadName("player1"))
		end
	end
end

function OnMsg.PreLoadSessionData()
	ReconstructJoiningSquadNames()
end

function OnMsg.GatherSessionData()
	for _, squad in pairs(gv_Squads) do
		if squad.joining_squad then 
			squad.Name = ""
		end
	end
end

function OnMsg.GatherSessionDataEnd()
	ReconstructJoiningSquadNames()
end

---
--- Generates a name for a squad that is being joined by a unit traveling from another sector.
---
--- The generated name includes the nickname of the unit that is traveling to the squad, as well as the name of the squad that the unit is joining.
---
--- @param unit_nick string The nickname of the unit that is traveling to the squad.
--- @param squad_name string The name of the squad that the unit is joining.
--- @return string The generated name for the joining squad.
---
function GenerateJoiningSquadName(unit_nick, squad_name)
	return T{590091407961, "<u(Name)> -> <u(OtherName)>", 
		Name = unit_nick, 
		OtherName = squad_name
	}
end

---
--- Generates a short name for a squad that is being joined by a unit traveling from another sector.
---
--- The generated short name includes the name of the squad that the unit is joining.
---
--- @param unit_nick string The nickname of the unit that is traveling to the squad.
--- @param squad_name string The name of the squad that the unit is joining.
--- @return string The generated short name for the joining squad.
---
function GenerateJoiningSquadName_Short(unit_nick, squad_name)
	return T{246115235863, "-> <u(OtherName)>",
		OtherName = SquadName:GetShortNameFromName(squad_name)
	}
end

---
--- Sets the retreat route for a satellite squad.
---
--- This function sets the retreat route for a satellite squad. It also sets the `Retreat` flag on the squad to `true` to allow the retreat route to be set, even if it is not a valid normal route.
---
--- @param squad table The satellite squad to set the retreat route for.
--- @param ... any Additional arguments to pass to `SetSatelliteSquadRoute`.
---
function SetSatelliteSquadRetreatRoute(squad, ...)
	squad.Retreat = true -- We need this to allow the retreat route to be set (if it isnt valid as a normal route)
	SetSatelliteSquadRoute(squad, ...)
	squad.Retreat = true -- We need this since SetRoute will reset the retreat status
end

---
--- Handles the joining of a unit to a satellite squad that is located in a different sector.
---
--- This function creates a new satellite squad for the joining unit, sets the retreat route if the old squad was retreating, and sets the route for the new squad based on the provided route or the old squad's travel state.
---
--- @param unit_id string The ID of the unit that is joining the squad.
--- @param joining_squad_id string The ID of the squad that the unit is joining.
--- @param old_squad_id string The ID of the squad that the unit is leaving.
--- @param route table The route for the new squad, or nil if no route is provided.
---
function NetSyncEvents.JoinFarAwaySquad(unit_id, joining_squad_id, old_squad_id, route)
	local oldSquad = gv_Squads[old_squad_id]
	local visPos = GetSquadVisualPos(oldSquad)	
	local squad_id = CreateNewSatelliteSquad({
			Side = "player1",
			CurrentSector = oldSquad.CurrentSector,
			PreviousSector = oldSquad.PreviousSector,
			PreviousLandSector = oldSquad.PreviousLandSector,
			Name = GenerateJoiningSquadName(gv_UnitData[unit_id].Nick, gv_Squads[joining_squad_id].Name),
			ShortName = GenerateJoiningSquadName_Short(gv_UnitData[unit_id].Nick, gv_Squads[joining_squad_id].Name),
			XVisualPos = visPos -- The new squad should be created on the same visual pos that the old squad was on.
		},
		{unit_id}
	)
	local squad = gv_Squads[squad_id]
	squad.joining_squad = joining_squad_id
	
	local oldSquadWasTravelling = IsSquadTravelling(oldSquad)
	if oldSquad.Retreat then
		-- If retreating make sure the retreat route is kept,
		-- UpdateJoiningSquad will set a true joining route after retreat finishes.
		route = table.copy(oldSquad.route, "deep")
		SetSatelliteSquadRetreatRoute(squad, route, "keep-join")
	elseif route then
		route.satellite_tick_passed = oldSquadWasTravelling
		SetSatelliteSquadRoute(squad, route, "keep-join")
	-- No route but old squad was travelling, this means that joining squad is probably on the same sector. Cancel travel to recenter.
	elseif oldSquadWasTravelling then 
		NetSyncEvents.SquadCancelTravel(squad_id, "keep-join", "force") -- now cancel the route
		if squad.route then squad.route.satellite_tick_passed = true end -- mark cancelled route as ongoing
	end
	
	if IsTraversingShortcut(oldSquad) then
		squad.traversing_shortcut_start = oldSquad.traversing_shortcut_start
		squad.traversing_shortcut_start_sId = oldSquad.traversing_shortcut_start_sId
		squad.traversing_shortcut_water = oldSquad.traversing_shortcut_water
	end
end

MapVar("gameOverState", 0)

local function lInternalCheckGameOver()
	if GameState.no_gameover then
		return
	end

	-- Another check got in before this thread,
	-- gameover threads will be spammed by the thread above.
	if gameOverState ~= 0 then return end
	
	-- Squad isnt defeated
	local playerTeam = GetCampaignPlayerTeam()
	if not playerTeam:IsDefeated() then return end
	gameOverState = 1
	
	-- The team is considered defeated, wait for their current command to finish (Die/GetDowned)
	WaitUnitsInIdleOrBehavior()
	
	-- Now kill everyone who is downed (IsIncapaciated() == true but not dead)
	for i, unit in ipairs(playerTeam.units) do
		if unit.behavior ~= "Dead" and unit.command ~= "Die" then
			unit:SetCommand("Die")
		end
	end
	
	-- Wait for all die commands to play out
	for i, unit in ipairs(playerTeam.units) do
		while unit.command == "Die" do
			WaitMsg("UnitDied", 1000)
		end
	end
	
	-- Just in case wait for everything to settle once more
	WaitUnitsInIdleOrBehavior()

	if g_Combat then
		g_Combat:End()
	end
	
	-- No more squads at all
	if not AnyPlayerSquads() then
		if Game.Money < 5000 then
			ShowPopupNotification("GameOverNoMoney")
		else
			ShowPopupNotification("IncapacitatedNoMercs")
		end
	else
		ShowPopupNotification("IncapacitatedWithMercs")
	end
	WaitAllPopupNotifications()
	
	-- PVP game, Combat test etc.
	if not next(gv_Squads) then 
		gameOverState = 3
		OpenPreGameMainMenu("")
		return
	end
	
	FireNetSyncEventOnHost("CheckGameOverAfterPopups")
end

local function lInternalCheckGameOverAfterPopups()
	-- The condition here prevents a gameover on loading a save before the initial sector enter.
	if not gv_SatelliteView and gv_CurrentSectorId and GameState.entered_sector then
		local squadsHere = GetSquadsInSector(gv_CurrentSectorId, true, false, true)
		if not squadsHere or #squadsHere == 0 then -- read the comment at the end to understand this
			gameOverState = 3
			
			-- Resolve conflict in case combat end didnt end it
			local currentSector = gv_Sectors[gv_CurrentSectorId]
			if currentSector and currentSector.conflict then
				-- In case of gameover we need to store the conflict's special properties (such as locking)
				currentSector.conflict_backup = table.copy(currentSector.conflict)
				ResolveConflict(currentSector, "noVoice", false, "retreat")
			end
			
			for i, u in ipairs(g_Units) do
				u:AddStatusEffect("Unaware")
			end
			
			-- If no mercs, pause the campaign time
			local playerSquads = GetPlayerMercSquads() or empty_table
			if #playerSquads == 0 then PauseCampaignTime("NoMercs") end
			OpenSatelliteView()
			return
		end
	end
end

---
--- Triggers a game over check after all popup notifications have been shown.
--- This function is called on the host when the "CheckGameOverAfterPopups" net sync event is received.
---
--- @function NetSyncEvents.CheckGameOverAfterPopups
--- @return nil
function NetSyncEvents.CheckGameOverAfterPopups()
	CreateGameTimeThread(lInternalCheckGameOverAfterPopups)
end

---
--- Triggers a game over check.
--- This function is called on the host when the "CheckGameOver" net sync event is received.
---
--- @function NetSyncEvents.CheckGameOver
--- @return nil
function NetSyncEvents.CheckGameOver()
	if gameOverState ~= 0 then return end

	CreateGameTimeThread(lInternalCheckGameOver)
end

---
--- Triggers a game over check.
--- This function is called on the host when the "CheckGameOver" net sync event is received.
---
--- @function CheckGameOver
--- @return nil
function CheckGameOver()
	FireNetSyncEventOnHost("CheckGameOver")
end

function OnMsg.MercHired()
	ResumeCampaignTime("NoMercs")
end

function OnMsg.ZuluGameLoaded()
	if gv_SatelliteView then return end
	gameOverState = 0
	CheckGameOver()
end

function OnMsg.SquadDespawned()
	if gv_SatelliteView then
		local playerSquads = GetPlayerMercSquads() or empty_table
		if #playerSquads == 0 then PauseCampaignTime("NoMercs") end
	end
end

function OnMsg.UnitDieStart(unit)
	if unit.session_id and gv_UnitData[unit.session_id] then
		local unitData = gv_UnitData[unit.session_id]
		Msg("MercHireStatusChanged", unitData, unitData.HireStatus, "Dead")
		unitData.HireStatus = "Dead"
		unitData.HiredUntil = Game.CampaignTime
		unitData.HitPoints = 0
		NetUpdateHash("UD_UnitDied", unit.session_id)
		RemoveUnitFromSquad(unitData)
		
		local unit = g_Units[unit.session_id]
		if unit then
			unit.HireStatus = "Dead"
			unit.HiredUntil = Game.CampaignTime
		end

		ObjModified(Selection)
		
		-- end game
		if unit and (unit.team.side == "player1" or unit.team.side == "player2") then
			CheckGameOver()
		end
	end
end

-- heal mercs and add new mercs to squad

--- Heals the unit data by setting the HitPoints to the specified value, or the MaxHitPoints if no value is provided.
---
--- @param data table The unit data to heal
--- @param [hp] number The new hit points value, or nil to set to MaxHitPoints
function HealUnitData(data, hp)
	data.HitPoints = hp or data.MaxHitPoints
	ObjModified(data)
end

--- Revives the unit data by setting the HitPoints to the specified value, or the MaxHitPoints if no value is provided. Additionally, it creates the starting equipment for the unit based on the randomization seed.
---
--- @param data table The unit data to revive
--- @param [hp] number The new hit points value, or nil to set to MaxHitPoints
function ReviveUnitData(data, hp)
	HealUnitData(data, hp)
	data:CreateStartingEquipment(data.randomization_seed)
end

--- Revives the unit by setting its health to the specified value, flushing its combat cache, updating its outfit, and initializing its merc weapons and actions.
---
--- @param u table The unit to revive
--- @param hp number The new hit points value for the unit
function ReviveUnit(u, hp)
	u:ReviveOnHealth(hp)
	u:FlushCombatCache()
	u:UpdateOutfit()
	u:InitMercWeaponsAndActions()
end

--- Synchronizes the healing of a merc unit over the network.
---
--- @param merc_id number The ID of the merc unit to heal.
function NetSyncEvents.HealMerc(merc_id)
	local unit_data = gv_UnitData[merc_id]
	if unit_data then
		HealUnitData(unit_data)
	end
	if IsValid(g_Units[merc_id]) then
		g_Units[merc_id]:ReviveOnHealth()
	end
end

local function GetMinUnvisitedPathSizeSector(unvisited, sector_path_size)
	local min = max_int
	local min_sector
	for sector, _ in sorted_pairs(unvisited) do
		if sector_path_size[sector] < min then
			min = sector_path_size[sector]
			min_sector = sector
		end
	end
	if min == max_int then return false end
	return min_sector
end

--- Checks if the given path has already been taken by the squad in the current sector.
---
--- @param curr string The current sector
--- @param neigh string The neighboring sector
--- @param route table The route taken by the squad
--- @param squad_curr_sector string The current sector of the squad
--- @return boolean True if the path has already been taken, false otherwise
function CheckIfPathTaken(curr, neigh, route, squad_curr_sector)
	local prevSect = squad_curr_sector
	for __, w in ipairs(route) do
		for ___, s in ipairs(w) do
			if prevSect == neigh and s == curr then
				return true
			end
			prevSect = s
		end
	end
	
	return false
end

PathingDirections = {"North", "South", "East", "West", "UpDown"}
DefineConstInt("Satellite", "AttackSquadPlayerSideWeight", 5)
---
--- Generates a route using Dijkstra's algorithm for a squad to travel from a start sector to an end sector.
---
--- @param start_sector string The ID of the start sector
--- @param end_sector string The ID of the end sector
--- @param fullRoute boolean Whether to generate a full route or just the next sector
--- @param units table The units in the squad
--- @param pass_mode string The mode of travel (e.g. "land_water", "land_water_boatless")
--- @param squad_curr_sector string The current sector of the squad
--- @param side string The side of the squad ("player1" or "enemy1")
--- @param noShortcuts boolean Whether to ignore satellite shortcuts
--- @return table|boolean The generated route, or false if no route could be found
function GenerateRouteDijkstra(start_sector, end_sector, fullRoute, units, pass_mode, squad_curr_sector, side, noShortcuts)
	if start_sector == end_sector and pass_mode ~= "display_invalid" then
		return false
	end
	
	local isEnemy = side == "enemy1" or side == "diamonds"
	pass_mode = pass_mode or (isEnemy and "land_water_boatless" or "land_water")
	
	-- Don't allow going into underground from satellite view, unless enemy
	local startIsUnderground = gv_Sectors and gv_Sectors[start_sector] and gv_Sectors[start_sector].GroundSector
	local endIsUnderground = gv_Sectors and gv_Sectors[end_sector] and gv_Sectors[end_sector].GroundSector
	if not startIsUnderground and endIsUnderground then
		if pass_mode ~= "display_invalid" and not isEnemy then
			return false
		end
	end
	
	local preferMySide = false
	if pass_mode == "enemy_guardpost" then
		preferMySide = true
		pass_mode = "land_water_boatless"
	end
	
	if GetSectorDistance(start_sector, end_sector) == 1 and pass_mode ~= "display_invalid" then
		local startSectorPreset = gv_Sectors[start_sector]
		local startIsUnderground = not not startSectorPreset.GroundSector
		local endIsUnderground = IsSectorUnderground(end_sector)
		if startIsUnderground and not endIsUnderground and not startSectorPreset.CanGoUp then
			return false
		end
	
		local dir = GetSectorDirection(start_sector, end_sector)
		local time = GetSectorTravelTime(start_sector, end_sector, fullRoute, units, pass_mode, squad_curr_sector, side, dir)
		if time then
			return { end_sector }
		end
	end

	local underground_sector_map = {}
	local unvisited_sectors = {}
	local sector_path_size = {}
	local prev, prevIsShortcut = {}, false
	for sector_id, sectorPreset in pairs(gv_Sectors) do
		if sector_id == start_sector then
			sector_path_size[sector_id] = 0
		else
			sector_path_size[sector_id] = max_int
		end
		unvisited_sectors[sector_id] = true
		
		if sectorPreset.GroundSector then
			underground_sector_map[sectorPreset.GroundSector] = sector_id
		end
	end
	
	local curr = start_sector
	while true do
		local currPreset = gv_Sectors[curr]
		local currentIsUnderground = not not currPreset.GroundSector
		
		for _, dir in ipairs(PathingDirections) do
			local neigh
			if dir == "UpDown" then
				if currentIsUnderground and
					((currPreset.CanGoUp and start_sector == curr) or pass_mode == "display_invalid") then -- Current is underground, has above ground
					neigh = currPreset.GroundSector
				elseif underground_sector_map[curr] and
						(pass_mode == "display_invalid" or (isEnemy and underground_sector_map[curr] == end_sector)) then -- Current is above ground, has underground
					-- Don't allow pathing into underground from overground, except for enemies (when their destination is underground like C7 mine)
					neigh = underground_sector_map[curr]
				end
			else
				neigh = GetNeighborSector(curr, dir)
				
				-- Underground in cardinal directions can only lead to another underground
				if currentIsUnderground and not IsSectorUnderground(neigh) then
					neigh = false
				end
			end
			
			if unvisited_sectors[neigh] then
				local time = GetSectorTravelTime(curr, neigh, fullRoute, units, pass_mode, squad_curr_sector, side, dir)
				if time then
					if preferMySide and side ~= gv_Sectors[neigh].Side then
						time = time * const.Satellite.AttackSquadPlayerSideWeight
					end
				
					local time_value = time + sector_path_size[curr]
					if time_value < sector_path_size[neigh] then
						sector_path_size[neigh] = time_value
						prev[neigh] = curr
					end
				end
			end
		end
		
		-- Check satellite shortcuts
		local shortcuts = noShortcuts and empty_table or GetShortcutsAtSector(curr, pass_mode == "retreat")
		for i, shortcut in ipairs(shortcuts) do
			local exit = shortcut.start_sector == curr and shortcut.end_sector or shortcut.start_sector
			if unvisited_sectors[exit] then
				local time = GetSectorTravelTime(curr, exit, fullRoute, units, pass_mode, squad_curr_sector, side)			
				if time then
					if preferMySide and side ~= gv_Sectors[exit].Side then
						time = time * const.Satellite.AttackSquadPlayerSideWeight
					end
				
					local time_value = time + sector_path_size[curr]
					if time_value < sector_path_size[exit] then
						sector_path_size[exit] = time_value
						prev[exit] = curr
						
						if not prevIsShortcut then prevIsShortcut = {} end
						if not prevIsShortcut[curr] then prevIsShortcut[curr] = {} end
						prevIsShortcut[curr][exit] = true
					end
				end
			end
		end
		
		unvisited_sectors[curr] = nil
		curr = GetMinUnvisitedPathSizeSector(unvisited_sectors, sector_path_size)

		if not curr then return false end
		if curr == end_sector then
			local s = curr
			local route_rev = {}
			local water_sectors = 0
			while s ~= start_sector do
				table.insert(route_rev, s)
				s = prev[s]
			end
			
			local reversedRoute = table.reverse(route_rev)
			local prevS = start_sector 
			for i, s in ipairs(reversedRoute) do
				if prevIsShortcut and prevIsShortcut[prevS] and prevIsShortcut[prevS][s] then
					if not reversedRoute.shortcuts then reversedRoute.shortcuts = {} end
					reversedRoute.shortcuts[i] = true
					
					if Platform.developer then
						local shortcutStart = prevS
						local shortcutEnd = s
						assert(GetShortcutByStartEnd(shortcutStart, shortcutEnd))
					end
				end
				prevS = s
			end

			return reversedRoute, sector_path_size[end_sector]
		end
	end
end

function OnMsg.SatelliteTick()
	local removeSquads = false

	SatelliteTickPerSectorActivityCalled  = {}-- reset operation update per tick 
	for _, squad in ipairs(g_SquadsArray) do
		if squad.route and not squad.route.satellite_tick_passed and not SquadCantMove(squad) then
			squad.route.satellite_tick_passed = true
			Msg("SquadTravellingTickPassed", squad)
		end
		
		local player_squad = IsPlayer1Squad(squad)
		if player_squad or not IsSquadTravelling(squad) then
			SatelliteUnitsTick(squad)
			ObjModified(gv_Sectors[squad.CurrentSector])
		end
		if squad.wait_in_sector and squad.wait_in_sector <= Game.CampaignTime then
			SatelliteSquadWaitInSector(squad, false)
		end
		
		if squad.despawn_on_next_tick and not IsSquadInConflict(squad) and not IsSquadTravelling(squad) then
			if not removeSquads then removeSquads = {} end
			removeSquads[#removeSquads + 1] = squad
		end
	end
	
	if removeSquads then
		for i, squad in ipairs(removeSquads) do
			RemoveSquad(squad)
		end
	end
end

---
--- Turns a squad that was previously joining another squad into a normal standalone squad.
--- This is done by:
--- - Setting the squad's `route` to `false`
--- - Setting the `joining_squad` field to `false`
--- - Generating a new squad name using `SquadName:GetNewSquadName("player1")`
--- - Setting the `ShortName` field to `false`
--- - Calling `ObjModified(squad)` to notify the game that the squad has been modified
---
--- @param squad table The squad to turn into a normal standalone squad
---
function TurnJoiningSquadIntoNormal(squad)
	squad.route = false
	squad.joining_squad = false
	squad.Name = SquadName:GetNewSquadName("player1")
	squad.ShortName = false
	ObjModified(squad)
end

---
--- Updates a squad that is currently joining another squad.
--- If the squad we wanted to join is gone, the joining squad is turned into a normal standalone squad.
--- If the squad has reached the destination, the unit is removed from the joining squad and added to the target squad.
--- If the squad has not reached the destination yet, a new route is generated towards the target squad's final destination.
---
--- @param squad table The squad that is currently joining another squad
--- @param canSetRoute boolean Whether a new route can be set for the squad
--- @return boolean True if the joining squad was successfully merged into the target squad, false otherwise
---
function UpdateJoiningSquad(squad, canSetRoute)
	local squadId = squad.UniqueId
	if not gv_Squads[squadId] then return end -- Squad doesn't exist anymore
	local joinSquad = gv_Squads[squad.joining_squad]
	
	-- The squad we wanted to join is gone. (died, merged into another squad, etc)
	if not joinSquad then
		TurnJoiningSquadIntoNormal(squad)
	-- Got to the destination
	elseif AreSquadsInTheSameSectorVisually(joinSquad, squad, "undergroundInsensitive") then
		squad.route = false
		local newSquad = joinSquad
		local unitId = squad.units[1]
		local unit_data = gv_UnitData[unitId]
		local bag = GetSquadBag(squad.UniqueId)
		if bag and next(bag) then
			AddItemsToSquadBag(newSquad.UniqueId, bag)
		end			
		RemoveUnitFromSquad(unit_data)
		table.insert(newSquad.units, unit_data.session_id)
		unit_data.Squad = newSquad.UniqueId

		ObjModified(newSquad)
		InventoryUIResetSquadBag()			
		return true
	elseif canSetRoute then
		-- Dont set new routes while retreat is in progress
		if squad.Retreat then return end
	
		local route = GenerateRouteDijkstra(squad.CurrentSector, GetSquadFinalDestination(joinSquad.CurrentSector, joinSquad.route), squad.route, squad.units, nil, nil, squad.Side)
		if route then
			SetSatelliteSquadRoute(squad, { route }, true)
		else
			-- no new route, cancel travel
			NetSyncEvents.SquadCancelTravel(squadId, not SquadCantMove(squad)) 
		end
	else
		-- If not, update route towards the joining squad.
		-- This needs to be done in a thread as this might be coming from the travel thread.
		CreateRealTimeThread(UpdateJoiningSquad, squad, "canSetRoute")
	end
end

---
--- Checks if the given squad belongs to the player1 faction.
---
--- @param squad table The squad to check
--- @return boolean True if the squad belongs to the player1 faction, false otherwise
---
function IsPlayer1Squad(squad)
	return not squad.militia and squad.Side == "player1"	
end

const.DbgTravelTimer = false
---
--- Prints a debug message for the travel timer if the `const.DbgTravelTimer` flag is set to true.
---
--- @param ... any Arguments to be printed.
---
function DbgTravelTimerPrint(...)
	if const.DbgTravelTimer then
		print(...)
	end
end

---
--- Calculates the additional tired time for a unit based on its current hit points.
---
--- Units with hit points above a certain threshold will get tired slower, while units with hit points below the threshold will get tired faster.
---
--- @param hp number The current hit points of the unit.
--- @return number The additional tired time for the unit, in hours.
---
function GetHPAdditionalTiredTime(hp)
	-- hp above this threshold will cause units to get tired slower (more time) (1% per hp)
	-- hp below this threshold will cause them to get tired faster (less time) (1% per hp)
	local hpLimit = const.Satellite.UnitTirednessTravelTimeHP
	local diff = Clamp(hp - hpLimit, -50, 25)
	return MulDivRound(const.Satellite.UnitTirednessTravelTime, diff, 100)
end

function OnMsg.ReachSectorCenter(squad_id, sector_id, prev_sector_id)
	local squad = gv_Squads[squad_id]
	local player_squad =  IsPlayer1Squad(squad)
	if not player_squad then return end

	local travelling = IsSquadTravelling(squad) and not IsSquadInDestinationSector(squad)
	local nonTireTravel = IsSquadWaterTravelling(squad) or IsTraversingShortcut(squad)
	for idx, id in ipairs(squad.units) do
		local unit_data = gv_UnitData[id]
		if unit_data.TravelTimerStart > 0 then
			
			local hp = unit_data.HitPoints
			local additional = GetHPAdditionalTiredTime(hp)
				
			NetUpdateHash("Tiredness", id, unit_data.TravelTimerStart, hp, additional, unit_data.Tiredness, nonTireTravel)
			
			if not nonTireTravel then	
				local TirednessThreshold = const.Satellite.UnitTirednessTravelTime + additional
				if not unit_data.WarnTired and  TirednessThreshold - unit_data.TravelTime <= MulDivRound(TirednessThreshold, 20, 100) and
					TirednessThreshold - unit_data.TravelTime > 0 then
					if unit_data.Tiredness == 0 then
						CombatLog("important", T{596219835266, "<name> is getting tired.", name = unit_data.Nick})
						unit_data.WarnTired = true
					elseif unit_data.Tiredness == 1 then
						CombatLog("important", T{512750148013, "<name> is getting exhausted.", name = unit_data.Nick})
						unit_data.WarnTired = true
					end
				end				
				
				if unit_data.TravelTime >= TirednessThreshold then
					if unit_data.Tiredness < 2 then
						unit_data:ChangeTired(1)						
					end
					DbgTravelTimerPrint("change tired: ", unit_data.session_id, unit_data.Tiredness)
					unit_data.TravelTime = 0
					unit_data.TravelTimerStart = Game.CampaignTime					
					unit_data.WarnTired = false
				end								
			end
		end
		
		-- If no longer travelling reset the activity to Idle
		if not travelling then
			DbgTravelTimerPrint("stop travel: ", unit_data.session_id, unit_data.Operation, (unit_data.TravelTime) / const.Scale.h)
			unit_data.TravelTimerStart = 0
			
			if unit_data.Operation == "Idle" or
				unit_data.Operation == "Traveling" or
				unit_data.Operation == "Arriving" then
				
				unit_data:SetCurrentOperation("Idle")
				if unit_data.RestTimer == 0 then
					DbgTravelTimerPrint("start rest: ", unit_data.session_id, unit_data.Operation)
					unit_data.RestTimer = Game.CampaignTime
				end
			end
		end
	end
end

OnMsg.OpenSatelliteView = function()
	local squads = GetPlayerMercSquads()
	for _, squad in ipairs(squads) do
		local mercs = squad.units
		for _, merc_id in ipairs(mercs) do
			local merc = gv_UnitData[merc_id]
			if not merc.Operation or merc.Operation == "Idle" then
				--this is a sync msg
				NetSyncEvents.MercSetOperation(merc_id, "Idle")
			end
		end
	end
end

---
--- Calculates the remaining rest time for a unit.
---
--- @param ud table The unit data table.
--- @param nextStepOnly boolean If true, only calculate the time remaining for the next rest step.
--- @return number|false The remaining rest time in seconds, or false if the unit is not resting or has no tiredness.
---
function SatelliteUnitRestTimeRemaining(ud, nextStepOnly)
	if ud.Tiredness == 0 then return false end
	if ud.RestTimer <= 0 then return false end
	local steps = nextStepOnly and 1 or ud.Tiredness
	return (const.Satellite.UnitTirednessRestTime * steps) - (Game.CampaignTime - ud.RestTimer)
end

if FirstLoad then
	SatelliteTickPerSectorActivityCalled = {}
end	

---
--- Ticks the units in a satellite squad, updating their operations and rest timers.
---
--- @param squad table The satellite squad to tick.
---
function SatelliteUnitsTick(squad)
	local player_squad = IsPlayer1Squad(squad)
	local nonTireTravel = IsSquadWaterTravelling(squad) or IsTraversingShortcut(squad)
	local squadUnits = table.copy(squad.units) -- Arriving activty will modify squad list
	local sector = gv_Sectors[squad.CurrentSector]
	local sector_id = sector.Id
	for _, id in ipairs(squadUnits) do
		local unit_data = gv_UnitData[id]
		local operation_id = unit_data.Operation
		local is_operation_started = operation_id=="Idle" or operation_id=="Traveling" or operation_id=="Arriving" or sector and sector.started_operations and sector.started_operations[operation_id]

		if not squad.Sleep then
			SatelliteTickPerSectorActivityCalled[sector_id]  = SatelliteTickPerSectorActivityCalled[sector_id] or {}
			if not SatelliteTickPerSectorActivityCalled[sector_id][operation_id] then
				SatelliteTickPerSectorActivityCalled[sector_id][operation_id] = true
				local sector = gv_Sectors[squad.CurrentSector]
				if is_operation_started then
					SectorOperations[operation_id]:SectorMercsTick(unit_data)
					is_operation_started = operation_id=="Idle" or operation_id=="Traveling" or operation_id=="Arriving" or sector and sector.started_operations and sector.started_operations[operation_id]
					
				else
					RecalcOperationETAs(sector,operation_id, "stopped")	
				end
			end
			if (player_squad or squad.villain) and is_operation_started and unit_data.Operation==operation_id then
				SectorOperations[operation_id]:Tick(unit_data)	
				
				local excludingActivity = operation_id ~= "Idle" and operation_id ~= "Traveling" and operation_id ~= "Arriving" and operation_id ~= "RAndR"
				local excludingProf = unit_data.OperationProfession ~= "Student" and unit_data.OperationProfession ~= "Patient"
				if excludingActivity and excludingProf and is_operation_started then
					if not squad.vrForActivity or not squad.vrForActivity[operation_id] or not squad.vrForActivity[operation_id].isPlayed then
						local remainingTimeH = (GetOperationTimerETA(unit_data) or 0)/ const.Scale.h
						local activityTimeH = (unit_data.OperationInitialETA or 0)/ const.Scale.h
						local passedTimeH = activityTimeH - remainingTimeH
						if remainingTimeH>0 and  passedTimeH >= const.Satellite.BusySatViewHours then 
							squad.vrForActivity = squad.vrForActivity or {}
							squad.vrForActivity[operation_id] = squad.vrForActivity[operation_id] or {}
							table.insert_unique(squad.vrForActivity[operation_id], id) 
						end
					end
				end
			end	
		end
		if unit_data.TravelTimerStart>0 then
			if not nonTireTravel then
				unit_data.TravelTime = unit_data.TravelTime + (Game.CampaignTime - unit_data.TravelTimerStart)
			end
			DbgTravelTimerPrint("update travel: ", unit_data.session_id, (unit_data.TravelTime)/const.Scale.h)
			unit_data.TravelTimerStart = Game.CampaignTime
		end	
		if player_squad then			
			if (SatelliteUnitRestTimeRemaining(unit_data, "next_step_only") or 1) <= 0 then				
				unit_data:SetTired(unit_data.Tiredness>0 and Max(unit_data.Tiredness - 1, 0) or unit_data.Tiredness)
				unit_data.RestTimer = Game.CampaignTime
				unit_data.TravelTimerStart = 0
				unit_data.TravelTime = 0
				DbgTravelTimerPrint(id, "rest", "travel:",(unit_data.TravelTime)/const.Scale.h, " rest ", (Game.CampaignTime - unit_data.RestTimer)/const.Scale.h)
			end
		end
		--NetUpdateHash("SatelliteUnitsTick", unit_data.session_id, unit_data.RestTimer, unit_data.Tiredness, unit_data.TravelTimerStart, unit_data.TravelTime)
		unit_data:Tick()
	end

	for operation_id, units in pairs(squad.vrForActivity) do
	 local is_operation_started = sector and sector.started_operations and sector.started_operations[operation_id]
		if is_operation_started and not squad.vrForActivity[operation_id].isPlayed then
			local randUnit = table.rand(units)
			PlayVoiceResponse(randUnit, "BusySatView")
			squad.vrForActivity[operation_id].isPlayed = true
		end
	end
	for _, id in ipairs(squad.units) do
		ObjModified(gv_UnitData[id])
	end
	if squad.arrive_in_sector and squad.arrive_in_sector.time <= Game.CampaignTime then
		local sector_id = squad.arrive_in_sector.sector_id
		SetSatelliteSquadCurrentSector(squad, sector_id, nil, "teleport")
	end
end

-- intel
---
--- Returns a list of intel IDs for the specified sector.
---
--- @param sector_id number The ID of the sector to get intel IDs for.
--- @return table A table of intel IDs for the specified sector.
function GetSectorIntelIds(sector_id)
	local campaign = GetCurrentCampaignPreset()
	local sector = table.find_value(campaign.Sectors, "Id", sector_id)
	return sector and table.values(sector.Intel or empty_table, "sorted", "Id") or empty_table
end

---
--- Returns the intel object and the sector for the given sector ID and item ID.
---
--- @param sector_id number The ID of the sector to get the intel object for.
--- @param item_id number The ID of the intel item to get.
--- @return table,table The intel object and the sector.
function GetSessionIntelObj(sector_id, item_id)
	local sector = gv_Sectors[sector_id]
	return sector and sector.intel[item_id], sector
end

---
--- Discovers intel for the specified sector.
---
--- @param sector_id number The ID of the sector to discover intel for.
--- @param suppressNotification boolean If true, suppress any notifications about the discovered intel.
function DiscoverIntelForSector(sector_id, suppressNotification)
	DiscoverIntelForSectors({sector_id}, suppressNotification)
end

---
--- Discovers intel for the specified sectors.
---
--- @param sector_ids table A table of sector IDs to discover intel for.
--- @param suppressNotification boolean If true, suppress any notifications about the discovered intel.
function DiscoverIntelForSectors(sector_ids, suppressNotification)
	NetUpdateHash("DiscoverIntelForSectors", suppressNotification, table.unpack(sector_ids))
	local discoveredFor = {}
	local alreadyKnown = false
	for i, s in ipairs(sector_ids) do
		local sector = gv_Sectors[s]
		if not sector or not sector.Intel then
			goto continue
		end
		
		if not suppressNotification then
			if sector.intel_discovered then
				alreadyKnown = true
			end
			discoveredFor[#discoveredFor + 1] = s
		end
		
		sector.intel_discovered = true
		NetUpdateHash("DiscoverIntelForSectors2", s)
		ObjModified(sector)
		Msg("IntelDiscovered", s)
		::continue::
	end
	
	if #discoveredFor == 0 then return end
	Msg("SectorsIntelDiscovered", discoveredFor)
	
	if #discoveredFor == 1 then
		local sector = gv_Sectors[discoveredFor[1]]
		local text = T{Presets.TacticalNotification.Default.intelFound.text, sector}
		if alreadyKnown then
			text = text .. T(504828030360, " (already known)")
		end
		CombatLog("important", text)
	else
		CombatLog("important", T{Presets.TacticalNotification.Default.intelFoundMultiple.text, sectors = discoveredFor})
	end
end

---
--- Gets a list of sector IDs that have undiscovered intel within the specified radius.
---
--- @param radius number (optional) The maximum distance from the current sector to include sectors in the result.
--- @return table A table of sector IDs that have undiscovered intel and are within the specified radius.
function GetSectorsAvailableForIntel(radius)
	local sectorIds = {} 
	for _, sector in sorted_pairs(gv_Sectors) do
		if sector.Intel and not sector.intel_discovered then
			if not radius or not gv_CurrentSectorId or GetSectorDistance(gv_CurrentSectorId, sector.Id) <= radius then
				sectorIds[#sectorIds + 1] = sector.Id
			end
		end
	end
	return sectorIds
end

---
--- Discovers intel for a random sector within the specified radius.
---
--- @param radius number (optional) The maximum distance from the current sector to include sectors in the result.
--- @param suppressNotification boolean (optional) If true, no notification will be shown when intel is discovered.
--- @return number The ID of the sector where intel was discovered.
function DiscoverIntelForRandomSector(radius, suppressNotification)
	local sectorIds = GetSectorsAvailableForIntel(radius)
	if #sectorIds == 0 then return end
	local sectorId = table.rand(sectorIds, InteractionRand(nil, "Satellite"))
	NetUpdateHash("DiscoverIntelForRandomSector", gv_CurrentSectorId, sectorId, table.unpack(sectorIds))
	DiscoverIntelForSector(sectorId, suppressNotification)
	return sectorId
end

function OnMsg.SectorsIntelDiscovered(discoveredFor)
	if #discoveredFor > 0 then
		GetInGameInterface():SetMode(GetInGameInterfaceMode())
		if g_Overview then
			VisualizeIntelMarkers(true)
		end
	end
end

---
--- Calculates the distance between two sectors.
---
--- @param sectorId1 number The ID of the first sector.
--- @param sectorId2 number The ID of the second sector.
--- @return number The distance between the two sectors.
function GetSectorDistance(sectorId1, sectorId2)
	local x1, y1 = sector_unpack(sectorId1)
	local x2, y2 = sector_unpack(sectorId2)
	
	return abs(x1 - x2) + abs(y1 - y2)
end

---
--- Determines the direction between two sectors.
---
--- @param sectorId1 number The ID of the first sector.
--- @param sectorId2 number The ID of the second sector.
--- @return string The direction from sectorId1 to sectorId2, one of "North", "South", "East", or "West".
function GetSectorDirection(sectorId1, sectorId2)
	local y1, x1 = sector_unpack(sectorId1)
	local y2, x2 = sector_unpack(sectorId2)
	if y1 == y2 then
		return x1 > x2 and "West" or "East"
	end
	return y1 > y2 and "North" or "South"
end

---
--- Gets the neighbor sector for the given sector and direction.
---
--- @param sector_id number The ID of the sector.
--- @param dir string The direction to get the neighbor sector for, one of "North", "South", "East", or "West".
--- @param campaign table (optional) The campaign preset to use. If not provided, the current campaign preset will be used.
--- @return number|boolean The ID of the neighbor sector, or false if there is no neighbor in the given direction.
function GetNeighborSector(sector_id, dir, campaign)
	local neigh_id
	local row, col = sector_unpack(sector_id)
	local campaign = campaign or GetCurrentCampaignPreset()
	if dir == "North" then
		if row == campaign.sector_rowsstart then
			return false
		end
		neigh_id = sector_pack(row - 1, col)
	elseif dir == "South" then
		local start_row = "A"
		if row == campaign.sector_rows then
			return false
		end
		neigh_id = sector_pack(row + 1, col)
	elseif dir == "East"  then
		if col == campaign.sector_columns then
			return false
		end
		neigh_id = sector_pack(row, col + 1)
	elseif dir == "West"  then
		if col == 1 then
			return false
		end
		neigh_id = sector_pack(row, col - 1)
	end
	
	-- Game only and not editor
	if gv_Sectors then
		local underground = IsSectorUnderground(sector_id)
		if underground then
			local undergroundId = neigh_id .. "_Underground"
			if gv_Sectors[undergroundId] then
				neigh_id = undergroundId
			end
		end
	end

	return neigh_id
end

---
--- Gets the neighbor sectors for the given sector.
---
--- @param sector_id number The ID of the sector.
--- @return table The neighbor sectors, with the sector ID as the key and the direction as the value.
function GetNeighborSectors(sector_id)
	local sectors = {}
	local row, col = sector_unpack(sector_id)
	local campaign = GetCurrentCampaignPreset()
	if row ~= campaign.sector_rowsstart then
		sectors[sector_pack(row - 1, col)] = "North"
	end
	if row ~= campaign.sector_rows then
		sectors[sector_pack(row + 1, col)] = "South"
	end
	if col ~= campaign.sector_columns then
		sectors[sector_pack(row, col + 1)] = "East"
	end
	if col ~= 1 then
		sectors[sector_pack(row, col - 1)] = "West"
	end
	return sectors
end

local function UpdateNeighborSector(sector, neigh_sector, dir, prop_id)
	if not neigh_sector then return end
	
	if not neigh_sector[prop_id] then
		neigh_sector:SetProperty(prop_id, set())
	end
	if sector[prop_id] and sector[prop_id][dir] then
		local prop_set = neigh_sector:GetProperty(prop_id)
		prop_set[opposite_directions[dir]] = true
		neigh_sector:SetProperty(prop_id, prop_set)
	else
		local prop_set = neigh_sector:GetProperty(prop_id)
		prop_set[opposite_directions[dir]] = false
		neigh_sector:SetProperty(prop_id, prop_set)
	end
end

---
--- Updates the direction properties of a neighboring sector.
---
--- @param sector table The current sector.
--- @param dir string The direction of the neighboring sector.
--- @param prop_id string The property ID to update.
--- @param session_update_only boolean If true, only update the session data, not the campaign data.
---
function UpdateNeighborSectorDirectionsProp(sector, dir, prop_id, session_update_only)
	local neigh_id = GetNeighborSector(sector.Id, dir)
	local currentCampaign = CampaignPresets[Game and Game.Campaign or "HotDiamonds"]
	local campaign_neigh_sector = table.find_value(currentCampaign.Sectors, "Id", neigh_id)
	if not session_update_only then UpdateNeighborSector(sector, campaign_neigh_sector, dir, prop_id) end
	UpdateNeighborSector(sector, gv_Sectors[neigh_id], dir, prop_id)
end

---
--- Updates the direction properties of all neighboring sectors of the given sector.
---
--- @param sector table The current sector.
--- @param prop_id string The property ID to update.
--- @param session_update_only boolean If true, only update the session data, not the campaign data.
---
function SatelliteSectorSetDirectionsProp(sector, prop_id, session_update_only)
	for _, dir in ipairs(const.WorldDirections) do
		UpdateNeighborSectorDirectionsProp(sector, dir, prop_id, session_update_only)
	end
end

---
--- Checks if the given squad is currently in combat.
---
--- @param squad_id number The unique ID of the squad to check.
--- @return boolean True if the squad is in combat, false otherwise.
---
function SquadIsInCombat(squad_id)
	if not g_Combat then 
		return false 
	end
	local squad = gv_Squads[squad_id]
	local sector_id = squad.CurrentSector
	if gv_ActiveCombat ~= sector_id then
		return false
	end	
	return not IsSquadTravelling(squad)
end

---
--- Returns the current location of the given squad.
---
--- If the squad is on a route, the function returns the current sector followed by the final destination sector.
--- Otherwise, it just returns the current sector.
---
--- @param context table The context object containing information about the squad.
--- @return string The current location of the squad.
---
function TFormat.SquadLocation(context)
	if not context then return "" end

	local routeDestination, isCurrent = GetSquadFinalDestination(context.CurrentSector, context.route)
	if not isCurrent and routeDestination then
		return T{712350743869, "<CurrentSector> > <routeDestination>", 
			CurrentSector = Untranslated(context.CurrentSector),
			routeDestination = Untranslated(routeDestination) 
		}
	else
		return Untranslated(context.CurrentSector)
	end
end

---
--- Returns the number of members in the given squad.
---
--- @param context table The context object containing information about the squad.
--- @return number The number of members in the squad.
---
function TFormat.SquadMemberCount(context)
	if not context then return 0 end
	if context.UniqueId == -1 then
		return #context.units
	end
	local squad = gv_Squads[context.UniqueId]
	return Untranslated(squad and tostring(#squad.units) or "0")
end

---
--- Returns the total power of the given squad.
---
--- @param context table The context object containing information about the squad.
--- @return number The total power of the squad.
---
function TFormat.GetSquadPower(context)
	if not context then return 0 end
	local power = GetSquadPower(context)
	return Untranslated(power)
end

---
--- Returns a list of units in the given squad that are in the specified tired state.
---
--- @param squad table The squad to check for tired units.
--- @param tired string The status effect to check for (e.g. "Exhausted").
--- @return table|nil A table of unit data for the tired units, or nil if there are none.
---
function GetSquadTiredUnits(squad, tired)
	local exhausted
	for _, u in ipairs(squad.units) do
		local ud = gv_UnitData[u]
		if ud:HasStatusEffect(tired) then
			exhausted = exhausted or {}
			table.insert(exhausted, ud)
		end
	end
	return exhausted
end

---
--- Displays a popup question to the user and pauses the campaign time while waiting for a response.
---
--- @param ... The arguments to pass to the WaitQuestion function.
--- @return boolean True if the user responded "ok", false otherwise.
---
function SatellitePopupQuestion(...)
	PauseCampaignTime(GetUICampaignPauseReason("Popup"))
	local res
	if WaitQuestion(...) == "ok" then
		res = true
	end
	ResumeCampaignTime(GetUICampaignPauseReason("Popup"))
	return res
end

---
--- Displays a popup message to the user and pauses the campaign time while waiting for a response.
---
--- @param ... The arguments to pass to the WaitMessage function.
--- @return boolean True if the user responded "ok", false otherwise.
---
function SatellitePopupMessage(...)
	PauseCampaignTime(GetUICampaignPauseReason("Popup"))
	local res
	if WaitMessage(...) == "ok" then
		res = true
	end
	ResumeCampaignTime(GetUICampaignPauseReason("Popup"))
	return res
end

---
--- Displays a popup question to the user and pauses the campaign time while waiting for a response. The popup will display a list of exhausted units in the given squad, and give the user the option to split the squad or stop the travel.
---
--- @param squad table The squad to check for exhausted units.
--- @param exhausted table|nil A table of exhausted unit data, or nil to retrieve it from the squad.
--- @return table|false A table of session IDs for the exhausted units if the user chose to split the squad, or false if the user chose to stop travel.
---
function ShowExhaustedUnitsQuestion(squad, exhausted)
	exhausted = GetSquadTiredUnits(squad, "Exhausted") or exhausted
	if not exhausted or #exhausted == 0 then return end

	local nicks = table.map(exhausted, "Nick")
	local exhausted_units_listed = table.concat(nicks, ", ")
	if exhausted and #exhausted < #squad.units then
		local destination = next(squad.route) and GetSquadFinalDestination(squad.CurrentSector, squad.route) or false
		local result = SatellitePopupQuestion(terminal.desktop,
								T(824112417429, "Warning"),
								T{246005211663, "Some mercs assigned to <em><squadName></em> are <em>exhausted</em> and can't travel anymore. The squad will stop to rest in <em><SectorName(sector_id)></em>. <newline><newline>You can split the squad and order non-exhausted mercs to carry on to <destination_sector_id>.\n\nExhausted mercs: <nicknames>",
									squadName = Untranslated(squad.Name),
									nicknames = exhausted_units_listed,
									sector_id = gv_Sectors[squad.CurrentSector],
									destination_sector_id = destination and gv_Sectors[destination].display_name or T(164957197964, "destination sector"),
								},
								T(167389155310, "Split squad"),
								T(849471603425, "Stop Travel"))
		return result and table.map(exhausted, "session_id") or false
	else
		local result = SatellitePopupMessage(terminal.desktop,
								T(824112417429, "Warning"),
								T{122112968253, "Some mercs assigned to <squadName> are exhausted and can't travel anymore. The squad will stop to rest in <sector_id>.\n\nExhausted mercs: <nicknames>",
									squadName = Untranslated(squad.Name),
									nicknames = exhausted_units_listed,
									sector_id = gv_Sectors[squad.CurrentSector].display_name,
								},
								T(849471603425, "Stop Travel"))
		return false
	end	
end

---
--- Checks if the given squad has any members with the specified tired status effect.
---
--- @param squad table The squad to check.
--- @param tired string The name of the tired status effect to check for.
--- @return boolean true if the squad has any members with the specified tired status effect, false otherwise.
---
function HasTiredMember(squad, tired)
	for _, u in ipairs(squad.units) do
		local ud = gv_UnitData[u]
		if ud:HasStatusEffect(tired) then
			return true
		end
	end
end

---
--- Gets a table of unit IDs for the exhausted units in the given squad.
---
--- @param squad table The squad to check for exhausted units.
--- @return table|nil A table of unit IDs for the exhausted units, or nil if there are no exhausted units.
---
function GetSquadExhaustedUnitIds(squad)
	local exhausted
	for _, u in ipairs(squad.units) do
		local ud = gv_UnitData[u]
		if ud:HasStatusEffect("Exhausted") then
			exhausted = exhausted or {}
			table.insert(exhausted, u)
		end
	end
	return exhausted
end

--[[function HandleExhaustedUnitsQuestion(squad, exhausted)
	if not gv_SatelliteView or not IsSquadTravelling(squad) or IsSquadInDestinationSector(squad) or not HasTiredMember(squad, "Exhausted") then
		return
	end
	if IsSquadWaterTravelling(squad) or squad.uninterruptable_travel then
		return
	end
	if SquadTravelCancelled(squad) then
		return
	end
	if not LocalPlayerHasAuthorityOverSquad(squad) then
		return
	end
	
	local exhausted_ids = ShowExhaustedUnitsQuestion(squad, exhausted)
	if exhausted_ids and #exhausted_ids < #squad.units then
		local squad_id = SplitSquad(squad, exhausted_ids)
		local new_squad = gv_Squads[squad_id]
		new_squad.water_route = squad.water_route and table.copy(squad.water_route, "deep") or false
		new_squad.route = squad.route and table.copy(squad.route, "deep") or false
		local oldSquadRoute
		if squad.water_route then
			oldSquadRoute = { table.reverse(new_squad.water_route) }
			new_squad.returning_water_travel = true
			new_squad.water_route = squad.water_route
		else
			-- It is expected for the squad to be centered when this is called,
			-- so we dont need to cancel travel so we just remove the current route.
			oldSquadRoute = false
		end
		NetSyncEvent("AssignSatelliteSquadRoute", squad_id, oldSquadRoute)
	else
		NetSyncEvent("SquadCancelTravel", squad.UniqueId)
	end
end]]

--- Returns a table of player squads in the specified sector.
---
--- @param sector_id number|nil The ID of the sector to get the player squads for. If nil, the current sector ID is used.
--- @return table A table of player squads in the specified sector.
function GetCurrentSectorPlayerSquads(sector_id)
	return GetSectorSquadsFromSide(sector_id or gv_CurrentSectorId,"player1","player2")
end

--- Returns a table of squads with the specified IDs.
---
--- @param squad_ids table|nil A table of squad IDs. If nil, an empty table is used.
--- @return table A table of squads with the specified IDs.
function GetSquadsWithIds(squad_ids)
	local squads = {}
	for _, id in ipairs(squad_ids or empty_table) do
		table.insert(squads, gv_Squads[id])
	end
	return squads
end

--- Sets whether the specified squad should wait in the current sector for the given time.
---
--- @param squad table The squad to set the wait time for.
--- @param time number|nil The time in seconds to wait in the current sector, or `false` to cancel waiting.
function SatelliteSquadWaitInSector(squad, time)
	local had = not not squad.wait_in_sector
	local willHave = not not time
	squad.wait_in_sector = time or false
	if had ~= willHave then Msg("SquadWaitInSectorChanged", squad) end
end

-- When sailing into water from land or moving in water should be true
-- Also when sailing from water into land
--- Sets whether the specified squad should travel by water or not.
---
--- @param squad table The squad to set the water travel flag for.
--- @param val boolean Whether the squad should travel by water or not.
function SetSquadWaterTravel(squad, val)
	local oldVal = squad.water_travel
	squad.water_travel = val
	
	if val == oldVal or squad.Side ~= "player1" then return end
	
	-- Water travel rest logic
	
	if val then -- Starting water travel
		squad.water_travel_rest_timer = Game.CampaignTime
	elseif (squad.water_travel_rest_timer or 0) > 0 then -- Finishing water travel
		local timePassed = Game.CampaignTime - squad.water_travel_rest_timer
		for i, u in ipairs(squad.units) do
			local ud = gv_UnitData[u]
			if timePassed >= const.Satellite.UnitTirednessRestTime then
				ud:SetTired(ud.Tiredness>0 and Max(ud.Tiredness - 1, 0) or ud.Tiredness)
			end
		end
		squad.water_travel_rest_timer = 0
	end
end

function OnMsg.EnterSector()
	local sector = gv_Sectors[gv_CurrentSectorId]
	if not sector then return end
	sector.discovered = true
end

function OnMsg.SquadSectorChanged(squad)
	if squad.Side == "player1" then
		local sector = gv_Sectors[squad.CurrentSector]
		sector.discovered = true
	end
end

function OnMsg.SquadStartedTravelling(squad)
	if squad.Side == "player1" then
		local route = squad.route
		for i, wp in ipairs(route) do
			for _, sId in ipairs(wp) do
				local sector = gv_Sectors[sId]
				sector.discovered = true
			end
		end
	end
end

---
--- Debugging function to mark all sectors as discovered.
---
--- This function is intended for debugging purposes only and should not be used in
--- production code. It sets the `discovered` flag to `true` for all sectors in the
--- `gv_Sectors` table, effectively marking all sectors as discovered.
---
--- @function DbgDiscoverAllSectors
--- @return nil
function DbgDiscoverAllSectors()
	for id, s in pairs(gv_Sectors) do
		s.discovered = true
	end
end

---
--- Fixes the `discovered` flag for sectors in the savegame session data.
---
--- This function is used to ensure that the `discovered` flag for sectors is correctly set
--- based on the `player_visited` flag in the savegame session data. It is intended to be
--- used as a savegame fixup, to correct any issues with the `discovered` flag that may
--- have occurred in older versions of the game.
---
--- @param session_data table The savegame session data.
--- @param _ any Unused parameter.
--- @param lua_ver number The version of Lua used in the savegame.
--- @return nil
function SavegameSessionDataFixups.SectorDiscoveredFix(session_data, _, lua_ver)
	if lua_ver and lua_ver > 347132 then return end

	local sectors = table.get(session_data, "gvars", "gv_Sectors")
	if not sectors then return end

	for i, s in pairs(sectors) do
		if s.player_visited then
			s.discovered = true
		end
	end
end