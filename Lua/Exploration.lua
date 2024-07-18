if FirstLoad then
	g_LastExploration = false -- For debug
end

MapVar("g_Exploration", false)

DefineClass.Exploration = {
	__parents = { "InitDone" },
	
	-- Threads
	visibility_thread = false,
	npc_custom_highlight_thread = false,
	map_border_thread = false,
	sus_thread = false,
	npc_movement_thread = false,
	
	-- Sus meshes
	nearby_enemies = false,
	hash_nearby_enemies = false,
	fx_nearby_enemies = false,
}

---
--- Initializes the Exploration module.
---
--- This function is called when the Exploration mode is started. It sets up the necessary threads and checks for any active enemies to trigger combat mode.
---
--- @function Exploration:Init
--- @return nil
function Exploration:Init()
	assert(not g_Combat)
	NetUpdateHash("Exploration_Init")
	if #(g_Teams or "") == 0 then
		SetupDummyTeams()
	end
	UpdateTeamDiplomacy()
	Msg("ExplorationStart")

	self.visibility_thread = CreateGameTimeThread(Exploration.VisibilityInvalidateThread, self)
	self.npc_custom_highlight_thread = CreateGameTimeThread(Exploration.NPCCustomHighlightThread, self)
	self.map_border_thread = CreateGameTimeThread(Exploration.UpdateMapBorderThread, self)
	self.sus_thread = CreateGameTimeThread(Exploration.SusThread, self)
	self.npc_movement_thread = CreateGameTimeThread(Exploration.NPCMovementThread, self)
	
	-- sanity check
	local team = GetPoVTeam()
	local alive_player_units
	for _, unit in ipairs(team.units) do
		alive_player_units = alive_player_units or not unit:IsDead()
	end
	if not alive_player_units then return end
	for _, unit in ipairs(g_Units) do
		if not unit:IsDead() and unit:IsAware() and unit.team and unit.team:IsEnemySide(team) then
			NetSyncEvent("ExplorationStartCombat")
			return
		end
	end
end

---
--- Cleans up the Exploration module when it is finished.
---
--- This function is called when the Exploration mode is ending. It stops all the threads that were created in the `Exploration:Init()` function and performs any necessary cleanup.
---
--- @function Exploration:Done
--- @return nil
function Exploration:Done()
	if IsValidThread(self.visibility_thread) then DeleteThread(self.visibility_thread) end
	
	if IsValidThread(self.npc_custom_highlight_thread) then
		DeleteThread(self.npc_custom_highlight_thread)
		HighlightCustomUnitInteractables("delete")
	end
	
	if IsValidThread(self.map_border_thread) then DeleteThread(self.map_border_thread) end
	if IsValidThread(self.sus_thread) then
		NetUpdateHash("Exploration:Done_killing_sus_thread")
		DeleteThread(self.sus_thread)
		self:UpdateSusVisualization(false)
	end
	if IsValidThread(self.npc_movement_thread) then DeleteThread(self.npc_movement_thread) end
end

------------
-- Threads
------------

---
--- Runs a thread that updates the visibility of the game world during Exploration mode.
---
--- This thread is responsible for regularly updating the visibility of the game world, which includes calling `VisibilityUpdate()`, `UpdateApproachBanters()`, `UpdateMarkerAreaEffects()`, and broadcasting `ExplorationComputedVisibility` and `ExplorationTick` messages.
---
--- The thread runs in a loop, sleeping for 500 milliseconds between each iteration. During each iteration, it performs the following tasks:
---
--- 1. Calls `VisibilityUpdate()` to update the visibility of the game world.
--- 2. Calls `UpdateApproachBanters()` to update approach banters.
--- 3. Broadcasts the `ExplorationComputedVisibility` message if it has been at least 1 second since the last time it was broadcast.
--- 4. Calls `UpdateMarkerAreaEffects()` to update marker area effects.
--- 5. Broadcasts the `ExplorationTick` message with a time of 500 milliseconds.
--- 6. Calls `ListCallReactions(g_Units, "OnExplorationTick")` to notify all units of the exploration tick.
---
--- @function Exploration:VisibilityInvalidateThread
--- @return nil
function Exploration:VisibilityInvalidateThread()
	local last_computed_visibility_msg_time = 0
	while true do
		assert(g_Exploration and not g_Combat)
		VisibilityUpdate()
		
		UpdateApproachBanters()
		if GameTime() > last_computed_visibility_msg_time then
			Msg("ExplorationComputedVisibility")
			last_computed_visibility_msg_time = GameTime() + 1000
		end
		UpdateMarkerAreaEffects()
		
		local timeBetweenTicks = 500
		Sleep(timeBetweenTicks)
		Msg("ExplorationTick", timeBetweenTicks)
		ListCallReactions(g_Units, "OnExplorationTick")
	end
end

---
--- Runs a thread that highlights custom unit interactables during Exploration mode.
---
--- This thread is responsible for regularly highlighting custom unit interactables in the game world. It does this by calling the `HighlightCustomUnitInteractables()` function every 2 seconds.
---
--- The thread runs in a loop, sleeping for 2000 milliseconds between each iteration. During each iteration, it performs the following task:
---
--- 1. Calls `HighlightCustomUnitInteractables()` to highlight custom unit interactables.
---
--- @function Exploration:NPCCustomHighlightThread
--- @return nil
function Exploration:NPCCustomHighlightThread()
	while true do
		assert(g_Exploration and not g_Combat)
		HighlightCustomUnitInteractables()
		Sleep(2000)
	end
end

---
--- Runs a thread that updates the visibility of the map border area markers.
---
--- This thread is responsible for regularly updating the visibility of the map border area markers based on the current cursor position. It does this by calling the `UpdateBorderAreaMarkerVisibility()` function every 50 milliseconds.
---
--- The thread runs in a loop, sleeping for 50 milliseconds between each iteration. During each iteration, it performs the following task:
---
--- 1. Calls `UpdateBorderAreaMarkerVisibility()` with the current cursor position to update the visibility of the map border area markers.
---
--- @function Exploration:UpdateMapBorderThread
--- @return nil
function Exploration:UpdateMapBorderThread()
	while true do
		assert(g_Exploration and not g_Combat)
		if gv_CurrentSectorId then
			local cursor_pos = GetCursorPos()
			UpdateBorderAreaMarkerVisibility(cursor_pos)
		end
		Sleep(50)
	end
end

---
--- Runs a thread that updates the suspicion visualization for player units during Exploration mode.
---
--- This thread is responsible for regularly updating the suspicion visualization for player units based on the current state of the game. It does this by calling the `UpdateSusVisualization()` function every 35 milliseconds.
---
--- The thread runs in a loop, sleeping for 35 milliseconds between each iteration. During each iteration, it performs the following tasks:
---
--- 1. Calls `UpdateSusVisualization()` with the current state of the game to update the suspicion visualization for player units.
--- 2. Checks if the game is in Exploration mode and not in Combat mode.
--- 3. Retrieves the first player unit on the map and updates the `ExplorationSuspicionThread` network hash with information about the player unit, the number of enemy units, and whether any attack actions are in progress.
--- 4. If the game is not in the sync loading state, and the player unit is valid, it retrieves all enemy units and updates the suspicion of the player unit and its allied units based on the presence of enemy units. It then alerts any pending units.
---
--- @function Exploration:SusThread
--- @return nil
function Exploration:SusThread()
	self:UpdateSusVisualization(empty_table)
	while true do
		assert(g_Exploration and not g_Combat)
		local pus = GetAllPlayerUnitsOnMap()
		local unit = pus and pus[1]
		NetUpdateHash("ExplorationSuspicionThread", GameState.sync_loading, unit or false, #(GetAllEnemyUnits(unit) or ""), HasAnyAttackActionInProgress())
		if not GameState.sync_loading and unit and unit.team and not HasAnyAttackActionInProgress() then
			local enemies = GetAllEnemyUnits(unit)
			if #enemies > 0 then
				local allies = GetAllAlliedUnits(unit)
				allies = table.copy(allies)
				allies[#allies + 1] = unit
				local changes = UpdateSuspicion(allies, enemies, "intermediate") -- Enemies alerted by allies (incl merc)
				allies = table.ifilter(allies, function(_, u) return u.team and not u.team.player_team end)
				UpdateSuspicion(enemies, allies) -- Allies alerted by enemies
				AlertPendingUnits("sync_code")
				
				if changes then
					self:UpdateSusVisualization(changes)
				end
			else
				self:UpdateSusVisualization(false)
			end
		end

		Sleep(35)
	end
end

---
--- Updates the suspicion visualization for player units during Exploration mode.
---
--- This function is responsible for updating the suspicion visualization for player units based on the current state of the game. It does this by spawning and managing detection meshes for units that have raised suspicion or are hidden.
---
--- If the `data` parameter is `false` or the game is in a setpiece, the function will remove all detection meshes and reset the suspicion of all player units to 0.
---
--- Otherwise, the function will:
--- - Spawn new detection meshes for units that have raised suspicion or are hidden.
--- - Update the progress of existing detection meshes based on the unit's suspicion level.
--- - Manage the orientation of the detection meshes based on whether the unit is being seen by an enemy.
--- - Delete detection meshes for units that are no longer valid.
--- - Update the `UnitsSusBeingRaised` global table with the units that have had their suspicion raised.
---
--- @param data table|false The data containing information about the nearby enemies and their suspicion levels.
--- @return nil
function Exploration:UpdateSusVisualization(data)
	local playerMercs = GetAllPlayerUnitsOnMap()
	if not data or IsSetpiecePlaying() then
		for _, obj in ipairs(self.fx_nearby_enemies) do
			DoneObject(obj)
		end
		self.hash_nearby_enemies = false
		self.nearby_enemies = false
		
		local change
		for _, unit in pairs(playerMercs) do
			change = change or unit.suspicion ~= 0
			unit.suspicion = 0
		end
		if change then
			UnitsSusBeingRaised = {}
			ObjModified("UnitsSusBeingRaised")
		end
		
		return
	end
	
	self.nearby_enemies = data
	self.hash_nearby_enemies = self.hash_nearby_enemies or {}
	local drawnData = self.hash_nearby_enemies
	
	if not self.fx_nearby_enemies then self.fx_nearby_enemies = {} end
	
	-- Spawn detection mesh for units that having sus raised or are hidden.
	-- If they are just hidden the mesh is shown without the arrow (mesh3)
	local stillValid = {}
	for i, ally in ipairs(playerMercs) do
		local dataForAlly = table.find_value(data, "sees", ally)
		local shouldHaveMesh = (ally.suspicion or 0) > 0 or ally:HasStatusEffect("Hidden") or dataForAlly
		if not shouldHaveMesh then goto continue end
	
		local hash = ally.handle
		stillValid[hash] = true
		
		-- Create new line
		if not drawnData[hash] then
			local newMesh = SpawnDetectionIndicator(ally)
			drawnData[hash] = newMesh
			self.fx_nearby_enemies[#self.fx_nearby_enemies + 1] = newMesh
		end

		local mesh = drawnData[hash]
		mesh:SetProgress(MulDivRound(ally.suspicion or 0, 1000, SuspicionThreshold))
		
		if dataForAlly then
			mesh:SetGameFlags(const.gofLockedOrientation)
		
			local unit = dataForAlly.unit
			mesh:Face(unit:GetPos())
			mesh:Rotate(axis_z, 90 * 60)
			mesh.mesh3:SetVisible(true) -- The arrow
		elseif mesh:GetGameFlags(const.gofLockedOrientation) ~= 0 then
			mesh:ClearGameFlags(const.gofLockedOrientation)
			mesh:SetAngle(90 * 60)
			mesh.mesh3:SetVisible(false) -- The arrow
		end

		::continue::
	end
	
	local raisingSus = {}
	for _, d in ipairs(data) do
		local unit = d.unit
		local ally = d.sees
		
		-- Assign keys for easy lookup by badge logic
		if not data[unit] or data[unit].amount < d.amount then
			data[unit] = d
		end
		
		local hash = ally.handle
		if d.amount > 0 or unit:HasStatusEffect("Suspicious") then
			if unit.command ~= "OverheardConversationHeadTo" then
				EnsureUnitHasAwareBadge(unit)
				PlayUnitStartleAnim(unit)
				raisingSus[hash] = true
			end
		end
	end

	UnitsSusBeingRaised = raisingSus
	ObjModified("UnitsSusBeingRaised")
	
	-- Delete lines that are no longer valid
	local fade_out = MercDetectionConsts:GetById("MercDetectionConsts").fade_out
	for hash, mesh in pairs(drawnData) do
		if not stillValid[hash] then
			if IsValid(mesh) then
				mesh:SetOpacity(0, fade_out)
				CreateMapRealTimeThread(function()
					Sleep(fade_out)
					if IsValid(mesh) then
						DoneObject(mesh)
					end
				end)
			end
			drawnData[hash] = nil
			
			table.remove_value(self.fx_nearby_enemies, mesh)
		end
	end
end

---
--- Runs a thread that handles NPC movement in the Exploration mode.
--- This thread is responsible for periodically calling `NpcRandomMovement()` to make NPCs move around randomly.
--- The thread sleeps for 2 seconds initially, then enters a loop where it calls `NpcRandomMovement()` every 10 seconds.
--- The thread asserts that the `g_Exploration` object exists and that `g_Combat` is `nil`, ensuring that this thread only runs during Exploration mode.
---
--- @function Exploration:NPCMovementThread
--- @return nil
function Exploration:NPCMovementThread()
	Sleep(2 * 1000)
	while true do
		assert(g_Exploration and not g_Combat)
		--NetUpdateHash("NpcRandomMovement_ThreadProc")
		NpcRandomMovement()
		Sleep(10 * 1000)
	end
end

-----------
-- API
-----------

---
--- Synchronizes the start of the Exploration mode.
--- This function is responsible for setting up the Exploration mode, including:
--- - Ensuring the in-game interface is in the "Exploration" mode
--- - Resetting the camera settings
--- - Ensuring there is no existing Exploration instance and creating a new one
--- - Selecting the next unit if no unit is currently selected
--- - Selecting all local player-controlled units on the map if using a gamepad
---
--- @function SyncStartExploration
--- @return nil
function SyncStartExploration()
	if not GetInGameInterface() then
		ShowInGameInterface(true, false, { Mode = "IModeExploration" })
	elseif not GetInGameInterfaceMode() ~= "IModeExploration" then
		SetInGameInterfaceMode("IModeExploration")
	end
	cameraTac.SetForceOverview(false)
	cameraTac.SetForceMaxZoom(false)
	cameraTac.SetFixedLookat(false)
	
	if g_LastExploration then
		local oldSusThread = g_LastExploration.sus_thread
		assert(not IsValidThread(oldSusThread)) -- Double explore
	end
	if g_Exploration then -- Ensure we dont leak double threads
		DoneObject(g_Exploration)
	end
	
	assert(not g_Combat)
	NetUpdateHash("SyncStartExploration")
	g_Exploration = Exploration:new()
	g_LastExploration = g_Exploration
	
	if not SelectedObj then
		local igi = GetInGameInterfaceModeDlg()
		if igi then
			igi:NextUnit()
		end
	end
	
	if GetUIStyleGamepad() then
		local unitsInMap = GetAllPlayerUnitsOnMap()
		unitsInMap = table.ifilter(unitsInMap, function(_, o) return o:IsLocalPlayerControlled() and not o:IsDead() end)
		SelectionSet(unitsInMap)
	end
end

---
--- Synchronizes the start of the Exploration mode by calling the `SyncStartExploration` function.
---
--- This function is responsible for setting up the Exploration mode, including:
--- - Ensuring the in-game interface is in the "Exploration" mode
--- - Resetting the camera settings
--- - Ensuring there is no existing Exploration instance and creating a new one
--- - Selecting the next unit if no unit is currently selected
--- - Selecting all local player-controlled units on the map if using a gamepad
---
--- @function NetSyncEvents.StartExploration
--- @return nil
function NetSyncEvents.StartExploration()
	SyncStartExploration()
end

---
--- Synchronizes the start of the Exploration mode by calling the `SyncStartExploration` function.
---
--- This function is responsible for triggering the start of the Exploration mode on the server.
---
--- @function StartExploration
--- @return nil
function StartExploration()
	NetSyncEvent("StartExploration")
end

---
--- Synchronizes the start of combat mode by calling the `ExplorationStartCombat` function.
---
--- This function is responsible for transitioning from Exploration mode to Combat mode, including:
--- - Ensuring there is no existing Combat instance and creating a new one
--- - Stopping any active Exploration mode
--- - Evaluating any "starting combat" TCEs and waiting for any setpieces that might be triggered
--- - Setting up the new Combat instance, including the starting unit and current team
--- - Starting the new Combat instance and switching the in-game interface mode to "IModeCombatMovement"
---
--- @function NetSyncEvents.ExplorationStartCombat
--- @param team_idx (number|nil) The index of the team that is starting combat
--- @param unit_id (number|nil) The ID of the unit that is starting combat
--- @return nil
function NetSyncEvents.ExplorationStartCombat(team_idx, unit_id)
	if g_Combat or g_StartingCombat then return end
	if not g_Exploration then return end -- can occur via GroupAlert prior to deploy
	if config.GamepadTestOnly then return end
	
	print("starting combat")
	if not (GameState.Conflict or GameState.ConflictScripted) then
		KickOutUnits()
	end
	
	-- Find the team and unit that goes first.
	local team
	if team_idx ~= nil then
		if team_idx then
			team = g_Teams[team_idx]
		end
	else
		team = GetPoVTeam()
	end
	local unit = unit_id and g_Units[unit_id]
	
	SetActivePause() -- make sure active pause is off
	g_StartingCombat = true
	g_Exploration:Done()
	g_Exploration = false

	CreateGameTimeThread(function()
		if g_Combat then
			return
		end
		
		local igi = GetInGameInterfaceMode()
		if IsKindOf(igi, "IModeExploration") then
			igi:StopFollow()
		end
			
		CloseWeaponModificationCoOpAware()
		
		-- Evaluate TCEs for any "starting combat" tces, and wait for any
		-- setpieces that might be triggered (FaucheuxLeave)
		QuestTCEEvaluation()
		while IsSetpiecePlaying() do
			WaitMsg("SetpieceEnded", 100)
		end
		
		-- setup combat
		local combat = Combat:new{
			stealth_attack_start = g_LastAttackStealth,
			last_attack_kill = g_LastAttackKill,
		}
		g_Combat = combat
		g_Combat.starting_unit = unit

		if team then
			g_CurrentTeam = table.find(g_Teams, team)
		end

		if #Selection > 1 and g_CurrentTeam and g_Combat:AreEnemiesAware(g_CurrentTeam) then
			SelectObj()
		end

		--start combat
		combat:Start()
		SetInGameInterfaceMode("IModeCombatMovement")
	end)
end

--------
-- LOGIC
--------

--- Checks if there are any enemy teams present in the game.
---
--- @return boolean true if there are any enemy teams with units, false otherwise
function AreEnemiesPresent()
	for i, team in ipairs(g_Teams) do
		if (team.side == "enemy1" or team.side == "enemy2") and next(team.units) then
			return true
		end
	end
end

--- Performs random movement for NPCs (non-player characters) in the game.
---
--- This function iterates through all AI-controlled teams and their units, and
--- randomly moves each valid unit to a nearby position. The movement is
--- constrained to a radius around the unit's current position, and the target
--- position is snapped to the nearest valid navigation slab.
---
--- @return nil
function NpcRandomMovement()
	local radius = 10*guim
	NetUpdateHash("NpcRandomMovement_Start")
	for i, team in ipairs(g_Teams) do
		if team.control == "AI" then
			--NetUpdateHash("NpcRandomMovement", team.side, hashParamTable(team.units))
			for j, unit in ipairs(team.units) do
				--NetUpdateHash("NpcRandomMovement1", unit, unit.command, unit:IsDead())
				if not unit.command and unit:IsValidPos() and not unit:IsDead() and not IsSetpieceActor(unit) and not unit.being_interacted_with then
					local cx, cy, cz = unit:GetVisualPosXYZ()
					local dx = unit:Random(2*radius) - radius
					local dy = unit:Random(2*radius) - radius
					local target_pos = SnapToPassSlab(cx + dx, cy + dy, cz)
					if target_pos then
						unit:SetCommand("GotoSlab", target_pos)
					end
				end
			end
		end
	end
end