GameVar("gv_Deployment", false)
GameVar("gv_DeploymentStarted", false)
GameVar("gv_DeploymentDir", false)
MapVar("gv_Redeployment", false)
MapVar("RedeploymentThread", false)

DefineClass.DeploymentMarker = {
	__parents = {"GridMarker"},
	
	properties = {
		{ category = "Grid Marker", id = "Type", name = "Type", editor = "dropdownlist", items = {"DeployArea"}, default = "DeployArea", no_edit = true },
		{ category = "Marker", id = "Reachable", name = "Reachable only", editor = "bool", default = false, help = "Area of marker includes only tiles reachable from marker position, not the entire rectangle"},
		{ category = "Marker", id = "GroundVisuals", name = "Ground Visuals", editor = "bool", default = true, help = "Show ground mesh on the marker area"},
		{ category = "Trigger Logic", id = "Trigger", name = "Trigger", editor = "dropdownlist", items = { "always", }, default = "always", no_edit = true},
		{ category = "Trigger Logic", id = "TriggerEffects", name = "Effects", editor = "nested_list", base_class = "Effect", default = false, no_edit = true},
		{ category = "Deployment", id = "AlternateEntrance", name = "Alternate Entrance", editor = "bool", default = false},
	},
}

--- Initializes the DeploymentMarker object and updates its visuals based on the marker type.
function DeploymentMarker:Init()
	self:UpdateVisuals(self.Type, true)
end 

--- Placeholder function for the DeploymentMarker:TriggerThreadProc() method.
-- This method is currently empty and does not contain any implementation.
-- It is likely a placeholder for future functionality related to the deployment marker's trigger logic.
function DeploymentMarker:TriggerThreadProc()
end

---
--- Determines whether the deployment marker's area is visible.
---
--- The marker's area is visible if the editor is active, or if the deployment has started and the marker is enabled.
---
--- @return boolean
--- @see DeploymentMarker:IsMarkerEnabled
function DeploymentMarker:IsAreaVisible()
	return IsEditorActive() or gv_DeploymentStarted and self:IsMarkerEnabled()
end

local deploy_types = {"Entrance", "Defender", "DefenderPriority", "DeployArea"}
---
--- Checks if the given marker is a deployment marker.
---
--- @param marker GridMarker
--- @return boolean
---
function IsDeployMarker(marker)
	return not not table.find(deploy_types, marker.Type)
end

---
--- Gets the available entrance markers for the given arrival direction.
---
--- Entrance markers are always enabled as mercs can enter from there, except in the case of "custom" deployment.
--- If going underground, additional deployment markers with the "AlternateEntrance" property are also included.
---
--- @param arrival_dir string The arrival direction of the unit
--- @return table The available entrance markers
---
function GetAvailableEntranceMarkers(arrival_dir)
	-- Entrance markers are always enabled as mercs can enter from there.
	-- There are quest cases in which we might want to disable them though, which is denoted by gv_Deployment
	local markers 
	if gv_Deployment ~= "custom" then
		markers = MapGetMarkers("Entrance", g_GoingAboveground and "Underground" or arrival_dir, function(marker)
			return marker:IsMarkerEnabled()
		end)
	else
		markers = {}
	end
	if not g_GoingAboveground then
		markers = markers or {}

		-- Add alt entrance deployment markers.
		local additionalEntrances = MapGetMarkers("DeployArea", arrival_dir, function(marker)
			return marker:IsMarkerEnabled()
		end)
		table.iappend(markers, additionalEntrances)

		MapForEach("map", "DeploymentMarker", function (marker, markers)
			if not marker.AlternateEntrance and marker:IsMarkerEnabled() then
				markers[#markers + 1] = marker
			end
		end, markers)
	end
	
	return markers
end

---
--- Gets the available deployment markers for the given unit.
---
--- If the deployment mode is "defend", this function returns the available defender markers that are not blocked by enemy units.
--- Otherwise, it returns the available entrance markers based on the unit's arrival direction.
---
--- @param some_unit Unit The unit to get the available deployment markers for. If not provided, the selected unit is used.
--- @return table The available deployment markers
---
function GetAvailableDeploymentMarkers(some_unit)
	local markers = {}
	some_unit = some_unit or SelectedObj
	if gv_Deployment == "defend" then
		markers = MapGetMarkers("Defender", false, function(m) return m:IsMarkerEnabled() end)
		local player_side = NetPlayerSide()
		local non_blocked_markers = {}
		for _, marker in ipairs(markers) do
			local area = marker:GetAreaBox()
			local blocked = false
			for _, unit in ipairs(g_Units) do
				if SideIsEnemy(player_side, unit.team.side) and not unit:IsDead() and area:Point2DInside(unit) then
					blocked = true
					break
				end
			end
			if not blocked then
				table.insert(non_blocked_markers, marker)
			end
		end
		
		return #non_blocked_markers > 0 and non_blocked_markers or {markers[1]}
	elseif some_unit then
		markers = GetAvailableEntranceMarkers(some_unit.arrival_dir)
	end
	return markers
end

---
--- Gets the enemy deployment markers for the current sector.
---
--- This function retrieves the available entrance markers for the enemy squads in the current sector.
--- It iterates through the enemy squads and collects the available entrance markers based on the arrival direction of the first unit in each squad.
---
--- @return table The enemy deployment markers
---
function GetEnemyDeploymentMarkers()
	local markers = {}
	local _, enemy_squads = GetSquadsInSector(gv_CurrentSectorId)
	for _, squad in ipairs(enemy_squads) do
		local dir = squad.units and squad.units[1] and gv_UnitData[squad.units[1]] and gv_UnitData[squad.units[1]].arrival_dir
		if dir then
			local available = GetAvailableEntranceMarkers(dir)
			for _, marker in ipairs(available) do
				table.insert_unique(markers, marker)
			end
		end
	end
	return markers
end

---
--- Updates the visibility and badges of available deployment markers.
---
--- This function is responsible for managing the display of deployment markers on the map.
--- It checks the current deployment state and updates the visibility and badges of the markers accordingly.
--- If the deployment has started, it shows the available deployment markers and adds badges to them.
--- If the deployment has not started, it hides all deployment markers and removes any badges.
---
--- @return nil
---
function UpdateAvailableDeploymentMarkers()
	if gv_DeploymentStarted then
		local enemy_markers = GetEnemyDeploymentMarkers()
		local available = GetAvailableDeploymentMarkers()
		MapForEachMarker("GridMarker", nil, function(marker)
			if IsDeployMarker(marker) then
				if not table.find_value(available, marker) then
					marker:HideArea()
					DeleteBadgesFromTargetOfPreset("DeploymentAreaBadge", marker)
				else
					if not TargetHasBadgeOfPreset("DeploymentAreaBadge", marker) then
						CreateBadgeFromPreset("DeploymentAreaBadge", marker)
					end
					if not marker:IsAreaShown() then
						marker:ShowArea()
					end
				end
				if gv_Deployment == "defend" then
					if not table.find_value(enemy_markers, marker) then
						DeleteBadgesFromTargetOfPreset("EnemyDeploymentAreaBadge", marker)
					else
						if not TargetHasBadgeOfPreset("EnemyDeploymentAreaBadge", marker) then
							CreateBadgeFromPreset("EnemyDeploymentAreaBadge", marker)
						end
					end
				end
			end
		end)
	else
		UpdateEntranceAreasVisibility()
		MapForEachMarker("GridMarker", nil, function(marker)
			if marker.Type == "DeployArea" then
				marker:HideArea()
			end
			DeleteBadgesFromTargetOfPreset("DeploymentAreaBadge", marker)
			DeleteBadgesFromTargetOfPreset("EnemyDeploymentAreaBadge", marker)
		end)
	end
end

---
--- Checks if the first squad deployment has been completed.
---
--- This function checks if all units in the current team have been deployed, or if a specific squad has been deployed.
---
--- @param squad_id (optional) The ID of the squad to check. If not provided, it checks all squads.
--- @return boolean True if the first squad deployment has been completed, false otherwise.
---
function IsFirstSquadDeployment(squad_id) -- check all squads if not squad_id is provided
	local team = GetCurrentTeam()
	if team then
		for i, u in ipairs(team.units) do
			if (not squad_id or u.Squad == squad_id) and u:IsLocalPlayerControlled() and IsUnitDeployed(u) then
				return false
			end
		end
	end
	return true
end

---
--- Checks if the deployment is ready.
---
--- This function checks if all units in the current team have been deployed.
---
--- @return boolean True if the deployment is ready, false otherwise.
---
function IsDeploymentReady()
	local team = GetCurrentTeam()
	if team then
		for i, u in ipairs(team.units) do
			if not IsUnitDeployed(u) then
				return false
			end
		end
	end
	return true
end

---
--- Gets the units for the current deployment squad.
---
--- @param local_player_controlled_only boolean If true, only returns units controlled by the local player.
--- @return table The units in the current deployment squad.
---
function GetCurrentDeploymentSquadUnits(local_player_controlled_only)
	local units = {}
	local currentSquad = gv_Squads[g_CurrentSquad]
	for i, session_id in ipairs(currentSquad.units) do
		local u = g_Units[session_id]
		if not local_player_controlled_only or u:IsLocalPlayerControlled() then
			units[#units + 1] = u
		end
	end
	return units
end

if FirstLoad then
	DeployButtonVisible = true
end

---
--- Hides the deployment button.
---
function HideDeployButton()
	DeployButtonVisible = false
end

---
--- Shows the deployment button.
---
function ShowDeployButton()
	DeployButtonVisible = true
end

---
--- Checks if the deployment button should be hidden.
---
--- @return boolean True if the deployment button should be hidden, false otherwise.
---
function ShouldHideDeployButton()
	return not DeployButtonVisible
end

---
--- Shows or hides the units on the deployment screen.
---
--- @param bShow boolean If true, shows the units. If false, hides the units.
--- @param bLclPlayer boolean If true, only shows units controlled by the local player.
---
function ShowUnitsOnDeployment(bShow, bLclPlayer)
	if bShow then
		local igi = GetInGameInterfaceModeDlg()
		if not IsKindOf(igi, "IModeDeployment") or not igi.units_deployed then
			igi = false
		end
	
		for _, t in ipairs(g_Teams) do
			if t.side == "player1" or t.side == "player2" then -- show only player units, enemies will be handled in exploration VisibilityThread
				for i, unit in ipairs(t.units) do
					if bLclPlayer == unit:IsLocalPlayerControlled() then
						unit:SetVisible(true)
						
						-- Mark unit as deployed. It should be in a valid deploy position due to LocalDeployUnitsOnMarker in StartDeployment
						if igi then
							igi.units_deployed[unit] = true
							igi.cursor_voxel = false -- Force recalc
						end
					end
				end
			end
		end
	else
		for _, t in ipairs(g_Teams) do
			if t.side == "player1" or t.side == "player2" or t.side == "enemy1" or t.side == "enemy2" then
				for i, unit in ipairs(t.units) do
					unit:SetVisible(false)
				end
			end
		end
	end
	ObjModified("DeployUpdated")
	ObjModified("UpdateTacticalNotification")
end

---
--- Determines whether the deployment phase should be skipped.
---
--- @param mode string|nil The deployment mode, if any. Can be "attack" or "defend".
--- @return boolean True if the deployment phase should be skipped, false otherwise.
---
function SkipDeployment(mode)
	if gv_Deployment then
		return false
	elseif not mode then
		return true
	end
	if g_TestCombat and g_TestCombat.skip_deployment then
		return true
	end	
	-- temp comment out, check SetupDeployOrExploreUI
	--[[if mode == "attack" or mode == "defend" then
		return false
	end]]

	local currentSector = gv_Sectors[gv_CurrentSectorId]
	local conflict = IsConflictMode(gv_CurrentSectorId)

	if not currentSector.enabled_auto_deploy or not conflict then
		return true
	end

	if g_GoingAboveground then
		return true
	end

	return false
end

---
--- Sets the deployment mode for the current tactical situation.
---
--- @param deploy string|nil The deployment mode to set. Can be "defend" or nil to disable deployment mode.
---
function SetDeploymentMode(deploy)
	local defend_mode = deploy == "defend" or not deploy and gv_Deployment == "defend"
	gv_Deployment = deploy
	deploy = not not deploy
	local update_visuals = {}
	if defend_mode then
		if deploy then
			MapForEachMarker("GridMarker", nil, function(marker)
				if (marker.Type == "Defender" or marker.Type == "DefenderPriority") and marker:IsMarkerEnabled() then
					table.insert_unique(g_InteractableAreaMarkers, marker)
					update_visuals[#update_visuals + 1] = marker
				end
			end)
		else
			MapForEachMarker("GridMarker", nil, function(marker)
				if (marker.Type == "Defender" or marker.Type == "DefenderPriority") and marker:IsMarkerEnabled() then
					marker:RemoveFloatTxt()
					table.remove_value(g_InteractableAreaMarkers, marker)
					update_visuals[#update_visuals + 1] = marker
				end
			end)
		end
		
	else
		update_visuals = MapGetMarkers("Entrance", g_GoingAboveground and "Underground" or nil)
		table.iappend(update_visuals, MapGetMarkers("DeployArea"))
		if deploy then
			if not g_GoingAboveground then
				MapForEachMarker("GridMarker", nil, function(marker)
					if marker:IsKindOf("DeploymentMarker") then
						table.insert_unique(g_InteractableAreaMarkers, marker)
					end
				end)
			end
		else
			if not g_GoingAboveground then
				MapForEachMarker("GridMarker", nil, function(marker)
					if marker:IsKindOf("DeploymentMarker") then
						marker:RemoveFloatTxt()
						table.remove_value(g_InteractableAreaMarkers, marker)
					end
				end)
			end
		end
	end
	for _, marker in ipairs(update_visuals) do
		marker.Reachable = true--not deploy
		if marker.area_ground_mesh then
			marker.area_ground_mesh:UpdateState()
		end
		marker:UpdateVisuals(deploy and "DeployArea" or marker.Type, "force")
		marker:RecalcAreaPositions()
		if not marker:IsAreaVisible() then
			marker:HideArea()
		end
	end
	if not deploy then
		UpdateAvailableDeploymentMarkers()
		HideTacticalNotification("deployMode")
		Msg("DeploymentModeDone")
	end
	Msg("DeploymentModeSet", deploy)
end

---
--- Displays a notification message based on the deployment status of the current team's units.
---
--- @param context_obj table The context object associated with the notification.
--- @return string The notification message to be displayed.
---
function TFormat.DeployModeNotif(context_obj)
	local non_deployed = 0
	local non_deployed_lcl_player = 0
	local deployed = 0
	local team = GetCurrentTeam()
	local totalUnits = 0
	if team then
		for i, u in ipairs(team.units) do
			if not IsUnitDeployed(u) then
				non_deployed = non_deployed + 1
				if u:IsLocalPlayerControlled() then
					non_deployed_lcl_player = non_deployed_lcl_player + 1
				end
			else
				deployed = deployed + 1
			end
		end
		totalUnits = #team.units
	end
	local sector = gv_Sectors[gv_CurrentSectorId]
	if non_deployed_lcl_player <= 0 and non_deployed > 0 then
		local other_player_info = GetOtherNetPlayerInfo()
		return T{616675804493, "<other_player> Deploying", other_player = Untranslated(other_player_info and other_player_info.name or "N/A")}
	else
		return T{673244787391, "Deploy Merc(s) (<deployed>/<total>)", deployed = deployed, total = totalUnits}
	end
end

---
--- Checks if there is any Intel available for the current sector.
---
--- @param context_obj table The context object associated with the Intel check.
--- @return string|boolean The message to display if there is no Intel available, or false if Intel is available.
---
function TFormat.IntelForSector(context_obj)
	local sector = gv_Sectors[gv_CurrentSectorId]
	if sector and sector.Intel and not sector.intel_discovered then
		return T(244800584080, "No Intel for this sector")
	end
	return false
end

---
--- Retrieves the rollover text for a deployment area marker.
---
--- @param marker table The deployment area marker.
--- @return string The rollover text for the marker.
---
function GetDeploymentAreaRollover(marker)
	if marker.DeployRolloverText ~= "" then
		return marker.DeployRolloverText
	end

	if marker.Type == "Entrance" then
		if marker:IsInGroup("North") then
			return T(147747736813, "North Deployment Zone")
		elseif marker:IsInGroup("South") then
			return T(565574703512, "South Deployment Zone")
		elseif marker:IsInGroup("East") then
			return T(189571269539, "East Deployment Zone")
		elseif marker:IsInGroup("West") then
			return T(998300938139, "West Deployment Zone")
		end
	end
	return T(419061570457, "Deployment Area")
end

OnMsg.CustomInteractableEffectsDone = UpdateAvailableDeploymentMarkers

---
--- Checks if a unit is seen by any deployment markers.
---
--- @param unit table The unit to check.
--- @param markers table|nil The deployment markers to check against. If not provided, all available deployment markers will be used.
--- @return boolean True if the unit is seen by any deployment marker, false otherwise.
---
function IsUnitSeenByAnyDeploymentMarker(unit, markers)
	markers = markers or GetAvailableDeploymentMarkers()
	-- If the unit can see the marker, we consider it seeing back.
	-- This will cause weather effects and such to apply.
	-- The code below is a circle x rectangle collision.
	local unitSightRadius = unit:GetSightRadius()
	local ux, uy = unit:GetPosXYZ()
	local half_slabsize = const.SlabSizeX / 2
	for i, m in ipairs(markers) do
		local mx, my = m:GetPosXYZ()
		local distX = abs(ux - mx)
		local markerWidth = m.AreaWidth * half_slabsize
		local dx = distX - markerWidth
		if dx <= unitSightRadius then
			local distY = abs(uy - my)
			local markerHeight = m.AreaHeight * half_slabsize
			local dy = distY - markerHeight
			if dy <= unitSightRadius then
				if distX <= markerWidth / 2 or distY <= markerHeight / 2 then
					return true
				end
				-- Pythagoras
				if dx * dx + dy * dy <= unitSightRadius * unitSightRadius then
					return true
				end
			end
		end
	end
	return false
end

---
--- Checks if a unit is stuck at a given position, based on the available deployment markers.
---
--- @param unit table The unit to check.
--- @param pos table The position to check for the unit.
--- @param pfclass table|nil The pathfinding class to use. If not provided, it will be calculated.
--- @param destinations table|nil The available deployment marker positions. If not provided, they will be retrieved.
--- @return boolean True if the unit is stuck at the given position, false otherwise.
---
function IsStuckedMercPos(unit, pos, pfclass, destinations)
	if not pfclass then
		pfclass = CalcPFClass("player1")
	end
	if not destinations then
		destinations = {}
		local markers = GetAvailableEntranceMarkers(unit.arrival_dir)
		for i, marker in ipairs(markers) do
			local pos = GetPassSlab(marker)
			if pos then
				table.insert(destinations, pos)
			end
		end
	end
	if #destinations == 0 then
		return false
	end
	local has_path, closest_pos = pf.HasPosPath(pos, destinations, pfclass)
	if has_path and table.find(destinations, closest_pos) then
		return false
	end
	return true
end

---
--- Checks if any of the player's units are stuck at their current positions, based on the available deployment markers.
---
--- @param unit table The unit to check.
--- @param pos table The position to check for the unit.
--- @param pfclass table|nil The pathfinding class to use. If not provided, it will be calculated.
--- @param destinations table|nil The available deployment marker positions. If not provided, they will be retrieved.
--- @return boolean True if any of the player's units are stuck at their current positions, false otherwise.
---
function HasStuckedMercs()
	local destinations, dummy
	local pfclass = CalcPFClass("player1")
	for _, t in ipairs(g_Teams) do
		if t.side == "player1" or t.side == "player2" then
			for i, unit in ipairs(t.units) do
				if unit:IsLocalPlayerControlled() and unit:IsValidPos() and not unit:IsDead() then
					if not destinations then
						local markers = GetAvailableEntranceMarkers(unit.arrival_dir)
						if not markers then
							return
						end
						destinations = {}
						for i, marker in ipairs(markers) do
							local pos = GetPassSlab(marker)
							if pos then
								table.insert(destinations, pos)
							end
						end
					end
					if #destinations == 0 then
						return
					end
					-- invalidate the path
					local start_pos = unit.traverse_tunnel and unit.traverse_tunnel:GetExit() or GetPassSlab(unit) or unit:GetPos()
					local pfflags = const.pfmImpassableSource
					local has_path, closest_pos = pf.HasPosPath(start_pos, destinations, pfclass, 0, 0, nil, 0, nil, pfflags)
					if not has_path or not table.find(destinations, closest_pos) then
						return true
					end
				end
			end
		end
	end
	DoneObject(dummy)
	return false
end

---
--- Checks if any of the player's units are stuck at their current positions, and sets the `gv_Redeployment` global variable accordingly.
---
--- This function is called after a delay when the passability of the map changes or combat ends, to check if any of the player's units are stuck and need to be redeployed.
---
--- @return nil
---
function RedeploymentCheck()
	local redeploy = false
	if mapdata.GameLogic and Game and not g_Combat then
		if HasStuckedMercs() then
			redeploy = true
		end
	end
	gv_Redeployment = redeploy
	ObjModified("gv_Redeployment")
end

---
--- Schedules a delayed check for any of the player's units that may be stuck at their current positions.
---
--- This function is called when the passability of the map changes or combat ends, to check if any of the player's units need to be redeployed.
---
--- The check is performed after a 2 second delay, to allow the game state to stabilize.
---
--- @return nil
---
function RedeploymentCheckDelayed()
	if not mapdata.GameLogic or not Game then
		return
	elseif g_Combat then
		return
	elseif IsValidThread(RedeploymentThread) then
		return
	elseif GameState.disable_redeploy_check then
		return
	end
	RedeploymentThread = CreateGameTimeThread(function()
		Sleep(2000)
		RedeploymentCheck()
	end)
end

OnMsg.OnPassabilityChanged = RedeploymentCheckDelayed
OnMsg.CombatEnd = RedeploymentCheckDelayed
