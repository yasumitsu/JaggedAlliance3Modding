AppendClass.SetpiecePrg = {
	hidden_actors = false,
	properties = {
		{ category = "Play Settings", id = "CameraMode", name = "Camera-object behavior", editor = "choice", default = "Default",
			help = "The object hiding behavior of the camera during the setpiece.",
			items = function (self) return { "Default", "Hide all", "Show all" } end, },
		{ category = "Play Settings", id = "StopMercMovement", name = "Stop merc movement", editor = "bool", default = true, },
		{ category = "Play Settings", id = "Visibility", editor = "dropdownlist", items = {"Full", "Player"}, default = "Full", },
	},
}

AppendClass.XSetpieceDlg = {
	LeaveDialogsOpen = { "ZuluChoiceDialog" },
}
local oldOpen  = XSetpieceDlg.Open
--- Opens the XSetpieceDlg dialog.
-- Removes the "CombatLogMessageFader" class from the BlacklistedDialogClasses table, then calls the original XSetpieceDlg:Open() function.
function XSetpieceDlg:Open()
	table.remove_value(BlacklistedDialogClasses, "CombatLogMessageFader")
	oldOpen(self)
end

local oldClose = XSetpieceDlg.Close or XDialog.Close
--- Closes the XSetpieceDlg dialog.
-- Adds the "CombatLogMessageFader" class to the BlacklistedDialogClasses table, then calls the original XSetpieceDlg:Close() function.
-- @function XSetpieceDlg:Close
-- @return any result from the original XSetpieceDlg:Close() function
function XSetpieceDlg:Close()
	table.insert(BlacklistedDialogClasses, "CombatLogMessageFader")
	return oldClose(self)
end

--- Determines if the given object can be a setpiece actor.
-- @param idx The index of the object.
-- @param obj The object to check.
-- @return true if the object can be a setpiece actor, false otherwise.
function CanBeSetpieceActor(idx, obj)
	return IsKindOf(obj, "Unit") or not IsKindOf(obj, "EditorObject")
end

local function SetpieceUpdateVisibility(setpiece, start)
	g_SetpieceFullVisibility = start and setpiece and (setpiece.Visibility == "Full") or false
	local pov_team = GetPoVTeam()
	local active_units = Selection
	if not active_units or (#active_units == 0) then
		active_units = SelectedObj
	end
	
	for _, actor in ipairs(setpiece.hidden_actors or empty_table) do
		if IsValid(actor) then
			if IsKindOf(actor, "Unit") then
				actor:RemoveStatusEffect("SetpieceHidden")
			else
				actor:SetVisible(true)
			end
		end
	end
	setpiece.hidden_actors = false
	
	ApplyUnitVisibility(active_units, pov_team, g_Visibility)
end

function OnMsg.SetpieceActorRegistered(actor)
	if IsKindOf(actor, "Unit") then
		if actor.carry_flare then
			actor:RoamDropFlare()
		end
		if actor.command == "Visit" then -- move from UnitAmbientLife.lua, original code added in r314224
			actor:SetBehavior()
			actor:SetCommand(false)
		elseif not IsMerc(actor) then
			-- Mercs are handled below in OnSetpieceStarted
			-- set other actors in SetpieceIdle as well - it starts an Idle animation, and no game logic will alter it until the set-piece is over
			actor:SetCommand("SetpieceIdle")
		end
	end
end

local function apply_camera_mode(CameraMode, HidesFloorsAbove)
	if CameraMode == "Default" then
		ShowAllTreeTops("auto")
		ShowAllCanopyTops("auto")
		ShowAllWalls("auto")
		ShowAllHideFromCameraCollections("auto")
	elseif CameraMode == "Hide all" then
		ShowAllTreeTops(false)
		ShowAllCanopyTops(false)
		ShowAllWalls(false)
		ShowAllHideFromCameraCollections(false)
	elseif CameraMode == "Show all" then
		ShowAllTreeTops(true)
		ShowAllCanopyTops(true)
		ShowAllWalls(true)
		ShowAllHideFromCameraCollections(true)	
	elseif CameraMode == "HideAboveFloor" then
		HideFloorsAbove(HidesFloorsAbove or 100)
	end
end	

---
--- Handles the start of a setpiece in the game.
---
--- This function is called when a setpiece is started. It performs various actions to prepare the game state for the setpiece, such as:
--- - Closing any open conversation dialogs
--- - Recalculating the visibility of game objects based on the setpiece's visibility settings
--- - Updating the highlight markings of all units
--- - Interrupting any ongoing commands for mercenary units and setting them to the "SetpieceIdle" command
--- - Applying any custom camera mode specified by the setpiece
--- - Suspending interactable highlights
---
--- @param setpiece table The setpiece object that has started
---
function OnSetpieceStarted(setpiece)
	assert(setpiece.TakePlayerControl) -- setpieces that don't take control from the player should be run directly via StartSetpiece in a game time thread
	
	CloseDialog("ConversationDialog")
	Msg("WillStartSetpiece")
	
	-- recalc visibility to apply setpiece.Visibility
	SetpieceUpdateVisibility(setpiece, true)
	
	-- update unit highlights to disable in scene
	for _, u in ipairs(g_Units) do
		u:UpdateHighlightMarking()
	end
	
	if setpiece.StopMercMovement then
		CancelWaitingActions(-1)
		local nonInterruptable = {}
		local units = {}
		for _, unit in ipairs(g_Units) do
			if IsMerc(unit) then
				unit:InterruptCommand("SetpieceIdle", "reset anim")
				units[#units + 1] = unit
				
				-- It is possible for a unit to be currently uninterruptable,
				-- such as if stealthing
				if not unit:IsInterruptable() then
					nonInterruptable[unit] = true
				end
			end
		end
		
		local cycles = 0 -- Prevent infinite loop
		repeat
			for i = #units, 1, -1 do
				if units[i].command == "SetpieceIdle" then
					table.remove(units, i)
				end
			end
			if #units > 0 then
				-- Try to reinterrupt ones that were uninterruptable
				for i, u in ipairs(units) do
					if nonInterruptable[u] then
						if u.traverse_tunnel then
							-- ignore the unit, they will get ported to destination if alive
							u:SetCommand("SetpieceIdle", "reset anim")
						else
							u:InterruptCommand("SetpieceIdle", "reset anim")
						end
					end
				end
			
				WaitMsg("Idle", 200)
			end
			cycles = cycles + 1
		until #units == 0 or cycles >= 10
		assert(cycles < 10) -- Setpiece start hung up :(
	end
	
	if setpiece.CameraMode ~= "Default" then
		apply_camera_mode(setpiece.CameraMode)
	end
	SuspendInteractableHighlights()
end

---
--- Called when a setpiece has ended.
---
--- This function is responsible for restoring the game state after a setpiece has finished playing.
--- It recalculates the visibility of the scene, resets any units that were in a "Setpiece" command,
--- and restores the camera mode and interactable highlights.
---
--- @param setpiece table The setpiece instance that has ended.
---
function OnSetpieceEnded(setpiece)
	assert(setpiece.TakePlayerControl) -- setpieces that don't take control from the player should be run directly via StartSetpiece in a game time thread
	
	-- recalc visibility to restore applied setpiece.Visibility
	SetpieceUpdateVisibility(setpiece)
	
	for _, unit in ipairs(g_Units) do
		if type(unit.command) == "string" and string.match(unit.command, "Setpiece") then
			unit:SetCommand("Idle")
			unit:UpdateOutfit()
		end
		-- update unit highlights to restore after scene
		unit:UpdateHighlightMarking()
	end
	
	apply_camera_mode("Default")
	ResumeInteractableHightlights()
end

-- sync starting setpieces

local setpiece_skipped = not IsSetpiecePlaying()
local function ShouldSyncSetpieceSkip()
	local playingReplay = IsGameReplayRunning()
	local recordingReplay = not not GameRecord
	return IsInMultiplayerGame() or playingReplay or recordingReplay
end

local function InitSPClickSync()
	setpiece_skipped = false
	if ShouldSyncSetpieceSkip() then
		InitPlayersClickedSync("Setpiece", 
			function() --on done waiting
				local dlg = GetDialog("XSetpieceDlg")
				if dlg then
					dlg.setpieceInstance:Skip()
					if rawget(dlg, "idSkipHint") then
						dlg.idSkipHint:SetVisible(false)
					end
				end
				setpiece_skipped = true
			end,
			function(player_id, data) --on player clicked
				local dlg = GetDialog("XSetpieceDlg")
				if dlg and rawget(dlg, "idSkipHint") then
					local cntrl = dlg.idSkipHint
					if data[netUniqueId] then
						cntrl:SetText(T(769124019747, "Waiting for <u(GetOtherPlayerNameFormat())>..."))
					else
						cntrl:SetText(T(270246785102, "<u(GetOtherPlayerNameFormat())> skipped the cutscene"))					
					end
					if not cntrl:GetVisible() then
						cntrl:SetVisible(true)
					end
				end
			end)
	end
end

---
--- Skips the current setpiece instance if it has not already been skipped.
--- If the setpiece skip should be synchronized across players, it will notify other players that the local player has clicked ready to skip the setpiece.
---
--- @param setpieceInstance table The current setpiece instance to skip
---
function SkipSetpiece(setpieceInstance)
	if setpiece_skipped then
		return --already skipped
	end
	
	if not ShouldSyncSetpieceSkip() then
		setpieceInstance:Skip()
		setpiece_skipped = true
	else
		LocalPlayerClickedReady("Setpiece")
	end
end

local old_start_setpiece = StartSetpiece
---
--- Handles the start of a setpiece, including synchronizing player control and tracking non-blocking setpieces.
---
--- @param id string The ID of the setpiece to start
--- @param test_mode boolean Whether the setpiece is being started in test mode
--- @param seed number The seed to use for the setpiece
--- @param setpiece_id_hash number The hash of the setpiece ID and seed
--- @param ... any Additional arguments to pass to the setpiece start function
--- @return table The setpiece state object
---
function NetSyncEvents.StartSetpiece(id, test_mode, seed, setpiece_id_hash, ...)
	local setpiece = Setpieces[id]
	local dlg = GetDialog("XSetpieceDlg")
	local setpiece_state
	if setpiece.TakePlayerControl and dlg then
		InitSPClickSync()
		dlg.setpieceInstance = old_start_setpiece(id, test_mode, seed, ...)
		setpiece_state = dlg.setpieceInstance
	else
		setpiece_state = old_start_setpiece(id, test_mode, seed, ...)
		if not g_NonBlockingSetpiecesPlaying then g_NonBlockingSetpiecesPlaying = {} end
		g_NonBlockingSetpiecesPlaying[#g_NonBlockingSetpiecesPlaying + 1] = setpiece_state
	end
	
	Msg(setpiece_id_hash, setpiece_state)
end

---
--- Starts a setpiece and synchronizes its state across the network.
---
--- @param id string The ID of the setpiece to start
--- @param test_mode boolean Whether the setpiece is being started in test mode
--- @param seed number The seed to use for the setpiece
--- @param ... any Additional arguments to pass to the setpiece start function
--- @return table The setpiece state object
---
function StartSetpiece(id, test_mode, seed, ...)
	local setpiece_id_hash = xxhash(id, seed)
	FireNetSyncEventOnHost("StartSetpiece", id, test_mode, seed, setpiece_id_hash, ...)
	local _, setpiece_state = WaitMsg(setpiece_id_hash)
	return setpiece_state
end


----- Zulu setpiece spawn marker, based on UnitMarker

UndefineClass("SetpieceSpawnMarker")
DefineClass.SetpieceSpawnMarker = {
	__parents = { "SetpieceSpawnMarkerBase", "UnitMarker" },
	properties = {
		{ id = "EnabledConditions", editor = false },
		{ id = "Name", editor = "text", default = "", },
		{ id = "ID", editor = false },
		{ id = "Comment", editor = false },
		{ id = "Reachable", editor = false },
		{ id = "Trigger", editor = false },
		{ id = "Conditions", editor = false },
		{ id = "Effects", editor = false },
		{ id = "Spawn_Conditions", editor = false },
		{ id = "Despawn_Conditions", editor = false },
		{ id = "sync_obj", editor = false },
		{ id = "Banters", editor = false },
		{ id = "ConflictIgnore", editor = false },
		{ category = "Spawn Object", id = "Groups",  name = "Additional groups", editor = "string_list", items = function() return GridMarkerGroupsCombo() end, default = false, arbitrary_value = true, },
	},
	DisplayName = "Spawn",
	ConflictIgnore = true,
}

SetpieceSpawnMarker.EditorGetText = SetpieceMarker.EditorGetText
SetpieceSpawnMarker.EditorCallbackClone = SetpieceMarker.EditorCallbackClone
SetpieceSpawnMarker.EditorCallbackPlace = SetpieceMarker.EditorCallbackPlace
SetpieceSpawnMarker.EditorCallbackDelete = SetpieceMarker.EditorCallbackDelete

function OnMsg.ClassesPostprocess()
	SetpieceSpawnMarker.Update = empty_func
	SetpieceSpawnMarker.UpdateText = empty_func
	SetpieceSpawnMarker.SnapToVoxel = empty_func
	SetpieceSpawnMarker.SetAngle = SetpieceMarker.SetAngle
	SetpieceSpawnMarker.SetAxisAngle = SetpieceMarker.SetAxisAngle
	SetpieceSpawnMarker.EditorCallbackMove = SetpieceMarker.EditorCallbackMove
end

---
--- Spawns the objects defined in the `UnitDataSpawnDefs` property of the `SetpieceSpawnMarker` instance.
---
--- If no `UnitDataSpawnDefs` are specified, an error is stored and the function returns.
---
--- This function also sets up a workaround for the `OnCommandStart` event of spawned `Unit` objects, to prevent the `ClearPath` command from interrupting animations set by `SetpieceAnimation`.
---
--- @return table The spawned objects
---
function SetpieceSpawnMarker:SpawnObjects()
	if not self.UnitDataSpawnDefs or #self.UnitDataSpawnDefs < 1 then 
		StoreErrorSource(self, "No UnitDataSpawnDefs are specified in the spawn marker - no units were spawned!")
		return
	end
	
	-- allow spawning multiple times for set-piece test purposes
	local objs = UnitMarker.SpawnObjects(self)
	self.objects = false
	self.last_spawned_objects = false
	
	-- workaround for OnCommandStart calling :ClearPath, which in itself interrupts animations set by SetpieceAnimation immediately after spawning
	for _, obj in ipairs(objs) do
		if IsKindOf(obj, "Unit") then
			obj.OnCommandStart = function(self)
				if self.command == "SetpieceIdle" then
					self.OnCommandStart = nil
				end
			end
		end
	end
	
	return objs
end


----- define Zulu set-piece commands here

DefineClass.SetpieceAssignFromSquad = {
	__parents = { "PrgSetpieceAssignActor" },
	properties = {
		{ id = "Squad", editor = "number", default = 1, },
		{ id = "Unit", editor = "number", default = 1, },
	},
	EditorView = Untranslated("Actor(s) '<AssignTo>' += squad <Squad> unit <Unit>"),
	EditorName = "Actor(s) from squad",
}

---
--- Finds the objects (units) in the specified squad and unit index.
---
--- @param state table The current state object.
--- @param Marker table The SetpieceSpawnMarker instance.
--- @param Squad number The index of the squad to find the unit in.
--- @param Unit number The index of the unit within the squad.
--- @return table The unit object, or an empty table if not found.
---
function SetpieceAssignFromSquad.FindObjects(state, Marker, Squad, Unit)
	local squads = GetSquadsInSector(gv_CurrentSectorId)
	local squad = squads and squads[Squad]
	return squad and squad.units and Groups[squad.units[Unit]] or empty_table
end


DefineClass.SetpieceIfQuestVar = {
	__parents = { "PrgIf" },
	properties = {
		{ id = "Repeat", editor = "bool", default = false, no_edit = true, },
		{ id = "Condition", editor = "expression", default = empty_func, no_edit = true, },
		{ id = "QuestId", name = "Quest id", editor = "preset_id", default = false,
			preset_class = "QuestsDef", preset_filter = function (preset, obj) return QuestHasVariable(preset, "QuestVarBool") end,
		},
		{ id = "Vars", name = "Vars to check", help = "Click on a variable to turn it green, click again to turn it red. The condition will check if all of the green are true AND all of the red are false.",
			editor = "set", default = false, three_state = true, items = function (self) return table.keys2(QuestGetVariables(self.QuestId), "sorted") end, },
	},
	EditorName = "Condition by quest variable",
	EditorSubmenu = "Code flow",
	StatementTag = "Basics",
}

---
--- Generates the expression code for the SetpieceIfQuestVar class.
---
--- @param for_preview boolean Whether the expression code is being generated for a preview.
--- @return string The expression code.
---
function SetpieceIfQuestVar:GetExprCode(for_preview)
	if not self.QuestId or not self.Vars or not next(self.Vars) then
		return "true"
	end
	
	local t = {}
	for k, v in sorted_pairs(self.Vars) do
		if for_preview then
			table.insert(t, string.format('%s%s', v and "" or "not ", k))
		else
			table.insert(t, string.format('%sGetQuestVar("%s", "%s")', v and "" or "not ", self.QuestId, k))
		end
	end
	return (for_preview and self.QuestId..": " or "") .. table.concat(t, " and ")
end


----- Death

DefineClass.SetpieceDeath = {
	__parents = { "PrgSetpieceCommand" },
	properties = {
		{ id = "Actors", name = "Actor(s)", editor = "choice", default = "", items = SetpieceActorsCombo, variable = true, },
		{ id = "Animation", editor = "choice", default = false, items = function() return UnitAnimationsCombo() end, },		
	},
	EditorName = "Death",
}

---
--- Returns the editor view string for the SetpieceDeath class.
---
--- @return string The editor view string.
---
function SetpieceDeath:GetEditorView()
	local suffix = self.Animation and string.format(" with '%s' anim", self.Animation) or ""
	return self:GetWaitCompletionPrefix() .. self:GetCheckpointPrefix() .. string.format("Actor(s) '%s' die%s", self.Actors, suffix)
end

---
--- Executes a thread that handles the death of a set of actors.
---
--- @param state table The current state of the setpiece.
--- @param Actors table The actors that will die.
--- @param Animation string The animation to play for the dying actors.
---
function SetpieceDeath.ExecThread(state, Actors, Animation)
	local dying = 0
	local message = CurrentThread()
	for _, actor in ipairs(Actors) do
		if IsValid(actor) then
			actor.HitPoints = 0
			PlayFX("Death", "start", actor)
			actor:SetCommand(function(self)
				self:PushDestructor(function(self)
					dying = dying - 1
					if dying <= 0 then
						Msg(message)
					end
				end)

				self:PlayDying(nil, nil, Animation)
				self:QueueCommand("Dead")
				
				-- Will not trigger gameplay events, so we must throw the message manually.
				self:SyncWithSession("map")
				Msg("UnitDieStart", self)
				Msg("UnitDiedOnSector", self, gv_CurrentSectorId)
				Msg("UnitDie", self)
			end)
			dying = dying + 1
		end
	end
	if dying > 0 then
		WaitMsg(message)
	end
	for _, actor in ipairs(Actors) do
		if IsValid(actor) then
			actor:DropLoot()
			actor:SyncWithSession("map")
		end
	end
end

---
--- Skips the death sequence for a set of actors, immediately setting them to the "Dead" state.
---
--- @param state table The current state of the setpiece.
--- @param Actors table The actors that will be skipped.
---
function SetpieceDeath.Skip(state, Actors)
	for _, actor in ipairs(Actors) do
		actor.HitPoints = 0
		if actor.command ~= "Dead" then
			actor:SetCommand(false)
			if actor.behavior ~= "Death" then
				actor:PlayDying(true)
			end
			actor:SetCommand("Dead")
			
			actor:SyncWithSession("map")
			Msg("UnitDieStart", actor)
			Msg("UnitDie", actor)
		end
		actor:DropLoot()
		actor:SyncWithSession("map")
	end
end


----- SetStance

---
--- Returns a table of available combat stances.
---
--- @return table The available combat stances.
---
function AnimStancesCombo()
	local items = { "CoverLow", "CoverHighLeft", "CoverHighRight" }
	ForEachPreset("CombatStance", function(obj) 
		items[#items + 1] = obj.id
	end)
	return items
end

---
--- Returns a table of available weapon options for use in a setpiece.
---
--- The returned table includes the following options:
--- - "Current Weapon": The actor's currently equipped weapon.
--- - "No Weapon": No weapon.
--- - All firearm inventory items defined in the "InventoryItemCompositeDef" preset.
---
--- @return table The available weapon options.
---
function AnimWeaponsCombo()
	local items = { "Current Weapon", "No Weapon" }
	ForEachPreset("InventoryItemCompositeDef", function(obj)
		local classdef = g_Classes[obj.object_class]
		if IsKindOf(classdef, "Firearm") then
			items[#items + 1] = obj.id
		end
	end)
	--[[ForEachPresetInGroup("InventoryItemCompositeDef", "Firearm", function(obj)
		items[#items + 1] = obj.id
	end)--]]
	--[[
	ForEachPresetInGroup("InventoryItemCompositeDef", "MeleeWeapon", function(obj)
		items[#items + 1] = obj.id
	end)
	ForEachPresetInGroup("InventoryItemCompositeDef", "HeavyWeapon", function(obj)
		items[#items + 1] = obj.id
	end)--]]
	return items
end

---
--- Waits for all actors in the given list to be in the "SetpieceIdle" command.
---
--- This function will wait until all actors in the list are in the "SetpieceIdle" command.
--- It will periodically check the command state of each actor and wait for a message
--- indicating that the "SetpieceIdle" command has started.
---
--- @param actors table A list of actors to wait for.
---
function WaitSetpieceIdle(actors)
	repeat
		local non_idle
		for _, actor in ipairs(actors) do
			if IsValid(actor) and actor.command ~= "SetpieceIdle" then
				non_idle = true
				break
			end
		end
		if not non_idle then break end
		WaitMsg("OnSetpieceIdleStart")
	until false
end

DefineClass.SetpieceSetStance = {
	__parents = { "PrgSetpieceCommand" },
	properties = {
		{ id = "Actors", name = "Actor(s)", editor = "choice", default = "", items = SetpieceActorsCombo, variable = true, },
		{ id = "Stance", name = "Stance", editor = "choice", default = "Standing", items = AnimStancesCombo },
		{ id = "Weapon", name = "Weapon", editor = "choice", default = "Current Weapon", items = AnimWeaponsCombo },
		{ id = "Transition", name = "Use transition anim", editor = "bool", default = true },
	},
	EditorName = "Set stance",
}

---
--- Returns a string representation of the editor view for the SetpieceSetStance command.
---
--- The returned string includes the wait completion prefix, checkpoint prefix, and a formatted
--- string that describes the actors, stance, and weapon specified for the command.
---
--- @return string The editor view string.
---
function SetpieceSetStance:GetEditorView()
	return self:GetWaitCompletionPrefix() .. self:GetCheckpointPrefix() ..
		string.format("Actor(s) '%s' in stance %s with %s", self.Actors == "" and "()" or self.Actors, self.Stance, self.Weapon)
end

local function lFilterDeadActors(actors)
	return table.ifilter(actors or empty_table, function(o) return IsValid(o) and not o:IsDead() end)
end

---
--- Executes the SetpieceSetStance command for the given actors, setting their stance and weapon.
---
--- This function will:
--- - Filter out any dead actors from the list
--- - Set the actors to the "SetpieceIdle" command
--- - Stop the actors in place and set their angle
--- - Set up the actors' weapons and weapon animation prefixes
--- - Transition the actors to the specified stance, including playing any transition animations
--- - Wait for all actors to reach the "SetpieceIdle" command
--- - Set the actors' stance to the specified stance
---
--- @param state The current state of the command execution
--- @param Actors A list of actors to set the stance for
--- @param stance The stance to set the actors to
--- @param weapon The weapon to equip the actors with
--- @param transition Whether to use a transition animation when changing stance
---
function SetpieceSetStance.ExecThread(state, Actors, stance, weapon, transition)
	Actors = lFilterDeadActors(Actors)
	local duration = 0
	for i, actor in ipairs(Actors) do
		if actor.species ~= "Human" then goto continue end
		if actor:HasStatusEffect("ManningEmplacement") then goto continue end
		if actor:GetBandageTarget() then goto continue end
		--if actor:IsDead() then goto continue end
		-- setup weapons, start transition anims
		actor:SetCommand("SetpieceIdle")
		
		-- Stop the unit in place.
		local unitPos = actor:GetVisualPos()
		if unitPos:IsValidZ() then
			local terrainZ = terrain.GetHeight(unitPos)
			if unitPos:z() == terrainZ then
				unitPos = unitPos:SetInvalidZ()
			end
		end
		actor:SetPos(unitPos)
		
		actor:SetAngle(actor:GetVisualAngle())
		local prefix = SetpieceSetStance.SetupActorWeapon(actor, weapon)
		actor:SetCommandParamValue("SetpieceIdle", "weapon_anim_prefix", prefix)
		actor:SetCommandParamValue("SetpieceSetStance", "weapon_anim_prefix", prefix)

		local stance1 = (actor.stance ~= "CoverLow") and actor.stance or "Crouch"
		local stance2 = (stance ~= "CoverLow") and stance or "Crouch"
		if stance1 == stance2 then
			local base_idle = actor:GetIdleBaseAnim(stance1)
			if not IsAnimVariant(actor:GetStateText(), base_idle) then
				local anim = actor:GetNearbyUniqueRandomAnim(base_idle)
				actor:SetState(anim)
			end
		else
			local transition_anim = string.format("%s%s_To_%s", prefix, stance1, stance2)
			actor:SetState(transition_anim)
			duration = Max(duration, actor:TimeToAnimEnd())
		end
		::continue::
	end
	
	state:SetSkipFn(SetpieceSetStance.SkipStanceOnly, CurrentThread())
	Sleep(duration)
	
	for i, actor in ipairs(Actors) do
		if actor.species ~= "Human" then
			actor:SetCommand("SetpieceSetStance", stance)
		end
	end
	WaitSetpieceIdle(Actors)
end

---
--- Sets the stance and weapon for a group of actors.
---
--- @param state table The current state of the game.
--- @param Actors table A list of actors to set the stance and weapon for.
--- @param stance string The stance to set for the actors.
--- @param weapon string The weapon to set for the actors.
---
function SetpieceSetStance.Skip(state, Actors, stance, weapon)
	Actors = lFilterDeadActors(Actors)
	for i, actor in ipairs(Actors) do
		local prefix = SetpieceSetStance.SetupActorWeapon(actor, weapon)
		actor:SetCommandParamValue("SetpieceIdle", "weapon_anim_prefix", prefix)
		actor:SetCommandParamValue("SetpieceSetStance", "weapon_anim_prefix", prefix)
		actor:SetCommand("SetpieceSetStance", stance)
	end
end

---
--- Sets the stance for a group of actors.
---
--- @param state table The current state of the game.
--- @param Actors table A list of actors to set the stance for.
--- @param stance string The stance to set for the actors.
---
function SetpieceSetStance.SkipStanceOnly(state, Actors, stance)
	Actors = lFilterDeadActors(Actors)
	for i, actor in ipairs(Actors) do
		actor:SetCommand("SetpieceSetStance", stance)
	end
end

---
--- Sets up the weapon animation prefix for an actor.
---
--- @param actor table The actor to set up the weapon animation prefix for.
--- @param set_weapon string The weapon to set up the animation prefix for. Can be "Current Weapon", "No Weapon", or a specific weapon name.
--- @return string The animation prefix for the actor's weapon.
---
function SetpieceSetStance.SetupActorWeapon(actor, set_weapon)
	local anim_prefix = "ar_"
	
	local weapon
	if set_weapon == "Current Weapon" then
		local item, item2 = actor:GetActiveWeapons()
		anim_prefix = GetWeaponAnimPrefix(item, item2)
		for _, item in ipairs{item, item2} do
			local weapon = item and item:GetVisualObj()
			if weapon then
				weapon:SetHierarchyEnumFlags(const.efVisible)
			end
		end
	else
		actor:DestroyAttaches("WeaponVisual")
		if set_weapon == "No Weapon" then
			anim_prefix = "civ_"
		else
			local item = PlaceInventoryItem(set_weapon)
			actor:ClearSlot("SetpieceWeapon")
			actor:AddItem("SetpieceWeapon", item)
			anim_prefix = GetWeaponAnimPrefix(item)
		end
		actor:UpdateOutfit()
	end
	
	return anim_prefix
end


----- GotoPosition

DefineClass.SetpieceGotoPosition = {
	__parents = { "PrgSetpieceCommand" },
	properties = {
		{ id = "Actors", name = "Actor(s)", editor = "choice", default = "", items = SetpieceActorsCombo, variable = true, },
		{ id = "Marker", name = "Pos marker", editor = "choice", default = "",
			items = SetpieceMarkersCombo("SetpiecePosMarker"), buttons = SetpieceMarkerPropButtons("SetpiecePosMarker"),
			no_validate = SetpieceCheckMap,
		},
		{ id = "Orient", name = "End Move Orient", editor = "bool", default = true },
		{ id = "UseRun", name = "Running", editor = "bool", default = true, help = "Considered when no move style is specified." },
		{ id = "StraightLine", name = "Straight line", editor = "bool", default = false },
		{ id = "Stance", name = "Stance", editor = "combo", default = "", items = { "", "Standing", "Crouch", "Prone" } },
		{ id = "animated_rotation", name = "Animated Rotation", editor = "bool", default = false },
		{ id = "RandomizePhase", name = "Randomize phase", editor = "bool", default = false, help = "When moving an actor group, randomizes the time each actor starts moving." },
		{ id = "MoveStyle", name = "Move style", editor = "combo", default = "", items = function (self) return GetMoveStyleCombo() end },
		{ id = "AnimSpeedModifier", name = "Anim Speed Modifier", editor = "number", default = 1000, min = 0, max = 65535, slider = true },
	},
	EditorName = "Go to (for Jagged Alliance 3 units)",
}

---
--- Generates the editor view for a SetpieceGotoPosition command.
---
--- @param self SetpieceGotoPosition The SetpieceGotoPosition instance.
--- @return string The editor view string.
---
function SetpieceGotoPosition:GetEditorView()
	return self:GetWaitCompletionPrefix() .. self:GetCheckpointPrefix() .. string.format("Actor(s) '<color 70 140 140>%s</color>' go to '<color 140 140 70>%s</color>' ", self.Actors, self.Marker)
end

---
--- Executes a SetpieceGotoPosition command, moving the specified actors to the given marker position.
---
--- @param state table The current state of the SetpieceGotoPosition command.
--- @param Actors table The actors to move.
--- @param Marker string The name of the marker to move the actors to.
--- @param Orient boolean Whether to orient the actors to the marker's angle.
--- @param UseRun boolean Whether to use a running animation.
--- @param StraightLine boolean Whether to move in a straight line.
--- @param Stance string The stance to use for the movement (e.g. "Standing", "Crouch", "Prone").
--- @param AnimatedRotation boolean Whether to use an animated rotation.
--- @param RandomizePhase boolean Whether to randomize the start time of the movement for each actor.
--- @param MoveStyle string The movement style to use.
--- @param AnimSpeedModifier number The animation speed modifier to apply.
---
function SetpieceGotoPosition.ExecThread(state, Actors, Marker, Orient, UseRun, StraightLine, Stance, AnimatedRotation, RandomizePhase, MoveStyle, AnimSpeedModifier)
	if not Actors or #Actors == 0 then return end
	local marker = SetpieceMarkerByName(Marker, "check")
	if not marker then return end

	local pts = marker:GetActorLocations(Actors)
	local angle = Orient and marker:GetAngle()

	for i, actor in ipairs(Actors) do
		actor:SetCommandParamValue("SetpieceGoto", "move_style", MoveStyle)
		actor:SetCommandParamValue("SetpieceGoto", "move_anim", UseRun and "Run" or "Walk")
		actor:SetCommandParamValue("SetpieceGoto", "move_speed_modifier", AnimSpeedModifier)
		actor:SetCommand("SetpieceGoto", pts[i], angle, Stance, StraightLine, AnimatedRotation, RandomizePhase and state.rand(1250))
	end
	while true do
		WaitMsg("UnitMovementDone", 100)
		local movement_done = true
		for _, actor in ipairs(Actors) do
			movement_done = movement_done and actor.command ~= "SetpieceGoto"
		end
		if movement_done then
			break
		end
	end
end

---
--- Skips the SetpieceGotoPosition command by directly setting the actors' positions and orientations.
---
--- @param state table The current state of the SetpieceGotoPosition command.
--- @param Actors table The actors to move.
--- @param Marker string The name of the marker to move the actors to.
--- @param Orient boolean Whether to orient the actors to the marker's angle.
--- @param UseRun boolean Whether to use a running animation.
---
function SetpieceGotoPosition.Skip(state, Actors, Marker, Orient, UseRun)
	local marker = SetpieceMarkerByName(Marker, "check")
	local valid_actors = table.ifilter(Actors, function(i, obj) return IsValid(obj) end)
	if not marker or #valid_actors == 0 then return end
	
	local pts = marker:GetActorLocations(valid_actors)
	
	for i, actor in ipairs(valid_actors) do
		actor:SetPos(pts[i])
		actor:SetCommand("SetpieceSetStance", actor.stance)
		if Orient then
			actor:SetAngle(marker:GetAngle())
		end
	end
end

-- SetpieceAnimationStyle

DefineClass.SetpieceAnimationStyle = {
	__parents = { "PrgSetpieceCommand" },
	properties = {
		{ id = "Actors", name = "Actor(s)", editor = "choice", default = "", items = SetpieceActorsCombo, variable = true, },
		{ id = "_desthelp", editor = "help", help = "Leave Destination empty to play the animation in place.", },
		{ id = "Marker", name = "Destination", editor = "choice", default = "",
			items = SetpieceMarkersCombo("SetpiecePosMarker"), buttons = SetpieceMarkerPropButtons("SetpiecePosMarker"),
			no_validate = SetpieceCheckMap,
		},
		{ id = "AnimationStyle", name = "Animation style", editor = "combo", default = "", items = function (self) return GetIdleStyleCombo() end },
		{ id = "Orient", name = "Use orientation", editor = "bool", default = true, },
		{ id = "AnimSpeed", name = "Animation speed", editor = "number", default = 1000, },
		{ id = "Duration", name = "Duration (ms)", editor = "number", default = 0, },
	},
	EditorName = "Play animation style",
}

if FirstLoad then
	SetpieceAnimationStyleThreads = setmetatable({}, weak_keys_meta)
end

---
--- Generates an editor view string for the SetpieceAnimationStyle command.
---
--- @param self table The SetpieceAnimationStyle instance.
--- @return string The editor view string.
---
function SetpieceAnimationStyle:GetEditorView()
	local marker_txt = self.Marker ~= "" and string.format(" to marker '<color 140 140 70>%s</color>'", self.Marker) or ""
	return self:GetWaitCompletionPrefix() .. self:GetCheckpointPrefix() ..
		string.format("Actor '<color 70 140 140>%s</color>' anim style'<color 140 70 140>%s</color>'%s",
			self.Actors == "" and "()" or self.Actors, self.AnimationStyle, marker_txt)
end

---
--- Executes a SetpieceAnimationStyle command, playing an animation style for the specified actors at the given destination marker.
---
--- @param state table The current state of the SetpieceAnimationStyle command.
--- @param Actors table A list of actors to play the animation style for.
--- @param Marker string The name of the destination marker to use.
--- @param AnimationStyle string The animation style to play.
--- @param Orient boolean Whether to orient the actors to the marker's angle.
--- @param AnimSpeed number The animation speed modifier to apply.
--- @param Duration number The duration of the animation in milliseconds.
---
function SetpieceAnimationStyle.ExecThread(state, Actors, Marker, AnimationStyle, Orient, AnimSpeed, Duration)
	if not Actors or #Actors == 0 or AnimationStyle == "" then return end
	local marker = SetpieceMarkerByName(Marker)
	if marker then
		marker:SetActorsPosOrient(Actors, false, 0, Orient)
	end
	for i, actor in ipairs(Actors) do
		actor:SetAnimSpeedModifier(AnimSpeed)
		if i >= 2 then
			SetpieceAnimationStyleThreads[actor] = CreateGameTimeThread(actor.PlayIdleStyle, actor, AnimationStyle, Duration)
		end
	end
	Actors[1]:PlayIdleStyle(AnimationStyle, Duration)
	
	SetpieceAnimationStyle.Skip(state, Actors)
end

---
--- Skips the current SetpieceAnimationStyle command by deleting any running animation threads and resetting the animation speed.
---
--- @param state table The current state of the SetpieceAnimationStyle command.
--- @param Actors table A list of actors to skip the animation style for.
---
function SetpieceAnimationStyle.Skip(state, Actors)
	for _, actor in ipairs(Actors) do
		local thread = SetpieceAnimationStyleThreads[actor]
		if thread then
			DeleteThread(thread)
			SetpieceAnimationStyleThreads[actor] = nil
		end
		actor:SetAnimSpeedModifier(1000)
	end
end

----- Shoot
if FirstLoad then
	SetpieceShootThreads = setmetatable({}, weak_keys_meta)
end

DefineClass.SetpieceShoot = {
	__parents = { "PrgSetpieceCommand" },
	properties = {
		{ id = "Actors", name = "Actor(s)", editor = "choice", default = "", items = SetpieceActorsCombo, variable = true, },
		{ id = "TargetType", name = "Target type", editor = "choice", items = { "Unit", "Point" }, default = "Unit", },
		{ id = "TargetUnits", name = "Target unit", editor = "choice", default = "", items = SetpieceActorsCombo, variable = true, no_edit = function(self) return self.TargetType ~= "Unit" end, },
		{ id = "TargetBodyPart", name = "Target Body Part", editor = "choice", items = PresetGroupCombo("TargetBodyPart", "Default"), default = "Torso", no_edit = function(self) return self.TargetType ~= "Unit" end, },
		{ id = "TargetPos", name = "Target pos", editor = "choice", default = "",
			items = SetpieceMarkersCombo("SetpiecePosMarker"), buttons = SetpieceMarkerPropButtons("SetpiecePosMarker"),
			no_validate = SetpieceCheckMap,
			no_edit = function(self) return self.TargetType ~= "Point" end,
		},
		{ id = "NumShots", name = "Num Shots", editor = "number", min = 1, max = 100, default = 1, },
		{ id = "ShotInterval", name = "Shot Interval", editor = "number", scale = "sec", min = 0, default = 0, help = "extra time added before restarting the shoot animation when firing multiple shots" },
		{ id = "InitialDelay", name = "Initial Delay", editor = "number", scale = "sec", min = 0, default = 0, },
		{ id = "AnimSpeed", name = "Anim Speed", editor = "number", scale = "%", min = 1, max = 1000, default = 100 },
		{ id = "TargetOffset", name = "Target Offset", editor = "number", scale = "m", min = 0, default = 0, no_edit = function(self) return self.TargetType ~= "Point" end, },
		{ id = "NumMisses", name = "Num Misses", editor = "number", min = 0, default = 0, max = function(self) return self.TargetType ~= "Point" and self.NumShots or 100 end, no_edit = function(self) return self.TargetType == "Point" end, help = "how many of the shots should be missing the target" },
	},
	EditorName = "Shoot",
}

---
--- Returns a string describing the editor view for the SetpieceShoot command.
---
--- @param self table The SetpieceShoot command instance.
--- @return string The editor view description.
---
function SetpieceShoot:GetEditorView()
	local target
	if self.TargetType == "Unit" then
		target = self.TargetUnits == "" and "()" or self.TargetUnits
		return self:GetWaitCompletionPrefix() .. self:GetCheckpointPrefix() .. string.format("Actor(s) '%s' shoots %s in the %s", self.Actors, target, self.TargetBodyPart)
	end
	assert(self.TargetType == "Point")
	target = self.TargetPos
	return self:GetWaitCompletionPrefix() .. self:GetCheckpointPrefix() .. string.format("Actor(s) '%s' shoots %s", self.Actors, target)
end

---
--- Executes a shooting sequence for the specified actors.
---
--- @param state table The current state of the setpiece.
--- @param Actors table The list of actors to perform the shooting.
--- @param TargetType string The type of target, either "Unit" or "Point".
--- @param TargetUnits table The list of target units.
--- @param TargetBodyPart string The body part of the target to aim at.
--- @param TargetPos string The name of the setpiece marker to use as the target position.
--- @param NumShots number The number of shots to fire.
--- @param ShotInterval number The time in seconds between each shot.
--- @param InitialDelay number The time in seconds to wait before starting the shooting.
--- @param AnimSpeed number The speed modifier for the shooting animation.
--- @param TargetOffset number The maximum offset in meters from the target position.
--- @param NumMisses number The number of shots that should miss the target.
---
--- @return nil
---
function SetpieceShoot.ExecThread(state, Actors, TargetType, TargetUnits, TargetBodyPart, TargetPos, NumShots, ShotInterval, InitialDelay, AnimSpeed, TargetOffset, NumMisses)
	local target_pt, target_obj = SetpieceShoot.ResolveTargetPt(state, TargetType, TargetUnits, TargetBodyPart, TargetPos)
	
	for _, actor in ipairs(Actors) do
		actor:SetCommand("SetpieceAimAt", target_pt)
	end
	-- wait aiming
	while true do
		local done = true
		for _, actor in ipairs(Actors) do
			done = done and actor.command == "SetpieceIdle"
		end
		if done then break end
		WaitMsg("SetpieceUnitAimed", 100)
	end
	
	local threads = SetpieceShootThreads
	for _, actor in ipairs(Actors) do
		if IsValidThread(threads[actor]) then
			DeleteThread(threads[actor])
			threads[actor] = nil
		end
		threads[actor] = CreateGameTimeThread(function()
			local weapon = actor:GetActiveWeapons("Firearm") or actor:GetActiveWeapons("RocketLauncher")
			local zooka = IsKindOf(weapon, "RocketLauncher")
			if not weapon then
				StoreErrorSource(actor, string.format("SetpieceShoot trying to fire an unsupported weapon of class '%s' for actor '%s'", weapon and weapon.class or "(nil)", actor.unitdatadef_id or actor.class))
				return
			end
			local ordnance, target_points
			local is_missed = {}
			
			local attack_data, lof_data
			if IsValid(target_obj) then
				attack_data = actor:ResolveAttackParams("SingleShot", target_obj, {target = target_obj, target_spot_group = TargetBodyPart})
				lof_data = attack_data.lof and attack_data.lof[1]
				target_pt = lof_data and lof_data.target_pos or target_pt
			else
				attack_data = actor:ResolveAttackParams("SingleShot", target_pt)
				if not attack_data.anim then
					attack_data.anim = actor:GetAttackAnim("SingleShot", actor.stance)
				end
			end
			actor:SetPos(attack_data.step_pos)
			local visual_obj = weapon:GetVisualObj(actor)
			
			if zooka then
				ordnance = weapon.ammo
				if not ordnance then
					-- find suitable ammo to fire
					for name, class in sorted_pairs(ClassDescendants("Ordnance")) do
						if class.Caliber == weapon.Caliber then
							ordnance = class
						end
					end
				end
				if not ordnance then
					StoreErrorSource(actor, string.format("SetpieceShoot unable to find suitable ordnance to fire from weapon of class '%s' for actor '%s'", weapon.class, actor.unitdatadef_id or actor.class))
					return
				end
			elseif IsValid(target_obj) then
				-- prepare target points in advance using CalcShotVectors
				local step_pos = attack_data.step_pos or actor:GetPos()
				local lof_pos1 = lof_data and lof_data.lof_pos1 or step_pos
				local num_misses = NumMisses or 0
				local num_hits = NumShots - num_misses
				local shot_attack_args = {target_spot_group = TargetBodyPart, stance = actor.stance, step_pos = step_pos}
				local lof_data = {lof_pos1 = lof_pos1, target_pos = target_pt}
				local hit_vectors, miss_vectors = Firearm:CalcShotVectors(actor, "SingleShot", target_obj, shot_attack_args, lof_data, 20*guic, guim, guim, num_hits, num_misses, 0)				
				local lowest
				target_points = {}
				for _, hit in ipairs(hit_vectors) do
					table.insert(target_points, hit.target_pos)
					if not lowest or (hit.target_pos:z() < lowest:z()) then
						lowest = hit.target_pos
					end
				end
				for _, miss in ipairs(miss_vectors) do
					table.insert(target_points, miss.target_pos)
					is_missed[point_pack(miss.target_pos)] = true
					if not lowest or (miss.target_pos:z() < lowest:z()) then
						lowest = miss.target_pos
					end
				end
				while #target_points < NumShots do -- fallback
					table.insert(target_points, target_pt)
					if not lowest or (target_pt:z() < lowest:z()) then
						lowest = target_pt
					end
				end
				table.sort(target_points, function(a, b) return lowest:Dist(a) < lowest:Dist(b) end)
			elseif TargetOffset and TargetOffset > 0 then
				-- prepare target points in advance by adding target offset
				local dir = (target_pt - actor:GetPos()):SetZ(0)
				if dir:Len2D2() > 0 then
					target_points = {}
					for i = 1, NumShots do
						local z = InteractionRand(TargetOffset, "Setpiece")
						local angle = InteractionRand(360*60, "Setpiece")
						target_points[i] = target_pt + RotateAxis(point(0, 0, z), dir, angle)
					end
				end
			end
			
			Sleep(InitialDelay)
			if IsValid(actor) then
				actor:SetAnimSpeedModifier(AnimSpeed*10)
			end
			for si = 1, NumShots do
				if not IsValid(actor) then break end
				local shot_target_pt = target_points and target_points[si] or target_pt
				actor:SetState(attack_data.anim, 0, 0)
				Sleep(actor:TimeToMoment(1, "hit") or 0)
				if visual_obj then
					assert(visual_obj:IsValidPos())
					local projectile_spawn_pos = GetWeaponSpotPos(visual_obj, "Muzzle")
					local action_dir = SetLen(shot_target_pt - projectile_spawn_pos, 4096)
					local fx_target = visual_obj.parts.Muzzle or visual_obj.parts.Barrel or visual_obj
					PlayFX("WeaponFire", "start", visual_obj, fx_target, projectile_spawn_pos, action_dir)
					if zooka then
						local dist = projectile_spawn_pos:Dist(shot_target_pt)
						local time = MulDivRound(dist, 1000, const.Combat.RocketVelocity)
						local trajectory = {
							{ pos = projectile_spawn_pos, t = 0 }, 
							{ pos = shot_target_pt, t = time },
						}
						local attaches = visual_obj:GetAttaches("OrdnanceVisual")
						local projectile
						if attaches then
							projectile = attaches[1] 
							projectile:Detach()
						else
							projectile = PlaceObject("OrdnanceVisual", {fx_actor_class = ordnance.class})
							local angle = CalcOrientation(projectile_spawn_pos, shot_target_pt)
							projectile:SetAngle(angle)
						end
						weapon:UpdateRocket()
						PlayFX("RocketFire", "start", projectile)
						
						--projectile:ChangeEntity(ordnance.Entity or "MilitaryCamp_Grenade_01")
						--projectile.fx_actor_class = ordnance.class
						
						local rotation_axis = RotateAxis(axis_x, axis_z, CalcOrientation(shot_target_pt, projectile_spawn_pos))
						CreateGameTimeThread(function()
							AnimateThrowTrajectory(projectile, trajectory, rotation_axis, 0)
							DoneObject(projectile)
						end)
					else
						local hit
						if is_missed[point_pack(shot_target_pt)] then
							hit = {
								distance = shot_target_pt:Dist(projectile_spawn_pos),
								pos = shot_target_pt,
								shot_dir = action_dir,
								setpiece = true,
							}
						else
							hit = {
								obj = target_obj,
								distance = shot_target_pt:Dist(projectile_spawn_pos),
								pos = shot_target_pt,
								shot_dir = action_dir,
								spot_group = TargetBodyPart,
								setpiece = true,
							}
						end
						CreateGameTimeThread(Firearm.ProjectileFly, Firearm, actor, projectile_spawn_pos, shot_target_pt, action_dir, const.Combat.BulletVelocity, {hit})
					end
				end
				Sleep(actor:TimeToAnimEnd())
				if si < NumShots and ShotInterval > 0 and not zooka then
					actor:RestoreAiming(shot_target_pt)
					Sleep(ShotInterval)
				end
			end
			if IsValid(actor) then
				actor:SetAnimSpeedModifier(1000)
			end
			threads[actor] = nil
			Msg("SetpieceShootDone")
		end)
	end
	
	while true do
		local all_done = true
		for _, actor in ipairs(Actors) do
			local thread = threads[actor]
			if IsValidThread(thread) then
				all_done = false
				break
			end
		end
		if all_done then break end
		WaitMsg("SetpieceShootDone", 100)
	end
	
	-- go back to aiming anims
	for _, actor in ipairs(Actors) do
		threads[actor] = nil
		if IsValid(actor) then
			actor:RestoreAiming(target_pt)
		end
	end
end

--- Skips the SetpieceShoot command for the given actors.
---
--- This function is used to cancel the SetpieceShoot command and restore the actors to their default state.
---
--- @param state table The state table passed to the SetpieceShoot command.
--- @param Actors table A list of actors to skip the SetpieceShoot command for.
--- @param TargetType string The type of target, either "Unit" or "Point".
--- @param TargetUnits table A list of target units.
--- @param TargetBodyPart string The body part of the target to aim at.
--- @param TargetPos string The position of the target.
function SetpieceShoot.Skip(state, Actors, TargetType, TargetUnits, TargetBodyPart, TargetPos)
	local target_pt = SetpieceShoot.ResolveTargetPt(state, TargetType, TargetUnits, TargetBodyPart, TargetPos)

	for _, actor in ipairs(Actors) do
		-- Delete all threads spawned by SetpieceShoot (if any)
		local thread = SetpieceShootThreads[actor]
		if IsValidThread(thread) then
			DeleteThread(thread)
			SetpieceShootThreads[actor] = nil
		end
		
		actor:SetAnimSpeedModifier(1000)
		actor:SetCommand("SetpieceIdle")
		actor:RestoreAiming(target_pt)
	end
end

---
--- Resolves the target point for a SetpieceShoot command.
---
--- This function takes the parameters of a SetpieceShoot command and determines the target point based on the target type and other parameters.
---
--- @param state table The state table passed to the SetpieceShoot command.
--- @param TargetType string The type of target, either "Unit" or "Point".
--- @param TargetUnits table A list of target units.
--- @param TargetBodyPart string The body part of the target to aim at.
--- @param TargetPos string The position of the target.
--- @return vec3, Entity The target point and the target entity (if applicable).
function SetpieceShoot.ResolveTargetPt(state, TargetType, TargetUnits, TargetBodyPart, TargetPos)
	local target_pt, target
	if TargetType == "Unit" then
		local n = #TargetUnits
		target = n > 0 and TargetUnits[1 + state.rand(n)]
		target_pt = target and target:GetStaticSpotPos(TargetBodyPart)
	else
		assert(TargetType == "Point")
		local marker = SetpieceMarkerByName(TargetPos, "check")
		target_pt = marker and marker:GetPos()
	end
	if target_pt and not target_pt:IsValidZ() then
		target_pt = target_pt:SetTerrainZ()
	end
	return target_pt, target
end


----- PlayAwarenessAnim

DefineClass.SetpiecePlayAwarenessAnim = {
	__parents = { "PrgSetpieceCommand" },
	properties = {
		{ id = "Actors", name = "Actor(s)", editor = "choice", default = "", items = SetpieceActorsCombo, variable = true, },
	},
	EditorName = "Play Become Aware",
}

---
--- Generates the editor view string for the SetpiecePlayAwarenessAnim command.
---
--- The editor view string is used to display a description of the command in the editor UI.
---
--- @param self SetpiecePlayAwarenessAnim The instance of the SetpiecePlayAwarenessAnim command.
--- @return string The editor view string.
function SetpiecePlayAwarenessAnim:GetEditorView()
	return self:GetWaitCompletionPrefix() .. self:GetCheckpointPrefix() .. string.format("Actor(s) '%s' become aware", self.Actors)
end

---
--- Executes the SetpiecePlayAwarenessAnim command by setting the "PlayAwarenessAnim" command on the specified actors, and then waiting for them to finish the "SetpieceIdle" command.
---
--- @param state table The state table passed to the SetpiecePlayAwarenessAnim command.
--- @param Actors table A list of actors to play the awareness animation on.
---
function SetpiecePlayAwarenessAnim.ExecThread(state, Actors)	
	for _, actor in ipairs(Actors) do
		if IsValid(actor) then
			actor:SetCommand("PlayAwarenessAnim", "SetpieceIdle")
		end
	end
	WaitSetpieceIdle(Actors)
end

---
--- Skips the "PlayAwarenessAnim" command on the specified actors by setting them to the "SetpieceIdle" command.
---
--- This function is used to cancel the "PlayAwarenessAnim" command and immediately set the actors to the "SetpieceIdle" state.
---
--- @param state table The state table passed to the SetpiecePlayAwarenessAnim command.
--- @param Actors table A list of actors to skip the "PlayAwarenessAnim" command on.
---
function SetpiecePlayAwarenessAnim.Skip(state, Actors)
	for _, actor in ipairs(Actors) do
		if IsValid(actor) then
			actor:SetCommand("SetpieceIdle")
		end
	end
end


----- Action camera

DefineClass.SetpieceActionCamera = {
	__parents = { "PrgSetpieceCommand" },
	properties = {
		{ id = "Actors", name = "Actor", editor = "choice", default = "", items = SetpieceActorsCombo, variable = true, },
		{ id = "Targets", name = "Target", editor = "choice", default = "", items = SetpieceActorsCombo, variable = true, },
		{ id = "Preset", name = "Action camera preset", editor = "preset_id", default = "Any", preset_class = "ActionCameraDef", extra_item = "Any", },
		{ id = "Position", editor = "choice", default = "Any", items = { "Any", "Left", "Right" }, },
		{ id = "TransitionTime", name = "Transition (ms)", editor = "number", default = 500, },
		{ id = "Duration", name = "Duration (ms)", editor = "number", default = 2000, },
		{ id = "FadeOutTime", name = "Fade out time (ms)", editor = "number", default = 700, },
		{ id = "Float", name = "Float camera around", editor = "bool", default = false, },
	},
	EditorName = "Action camera",
	EditorSubmenu = "Move camera",
}

---
--- Returns a string representation of the editor view for this SetpieceActionCamera command.
---
--- The returned string includes the wait completion prefix, checkpoint prefix, and a formatted string
--- that includes the names of the actors and targets for this command.
---
--- @return string The editor view string for this SetpieceActionCamera command.
---
function SetpieceActionCamera:GetEditorView()
	return self:GetWaitCompletionPrefix() .. self:GetCheckpointPrefix() .. string.format("Action camera from '%s' targeting '%s'", self.Actors, self.Targets)
end

---
--- Calculates the camera position, look-at point, and preset for an action camera.
---
--- This function is used to determine the appropriate camera settings for an action camera based on the
--- specified attacker, target, preset, and position parameters.
---
--- @param attacker table The actor that is the source of the action camera.
--- @param target table The actor or position that the action camera is targeting.
--- @param Preset string The name of the action camera preset to use, or "Any" to use a default camera.
--- @param Position string The desired position of the camera, either "Any", "Left", or "Right".
--- @return table, table, table The calculated camera position, look-at point, and preset.
---
function SetpieceActionCamera.CalcCamera(attacker, target, Preset, Position)
	local pos, lookat, preset
	if Preset ~= "Any" then
		local valid_cameras, all_cameras = {}, {}
		AddActionCameraForPreset(attacker, target, Presets.ActionCameraDef.Default[Preset], valid_cameras, all_cameras, Position)
		if #all_cameras < 1 then
			return CalcActionCamera(attacker, target, Position)
		end
		
		local cam = valid_cameras[1] or
			Position == "Any" and (#all_cameras[1][4] < #all_cameras[2][4] and all_cameras[1] or all_cameras[2]) or
			all_cameras[1]
		pos, lookat, preset = cam[1], cam[2], cam[3]
	else
		pos, lookat, preset = CalcActionCamera(attacker, target, Position)
	end
	return pos, lookat, preset
end

---
--- Executes a thread for an action camera command.
---
--- This function sets up and executes an action camera sequence, including calculating the camera position, look-at point, and preset, setting the action camera, and handling the fade-out at the end of the sequence.
---
--- @param state table The current state of the game.
--- @param Actors table The actors involved in the action camera sequence.
--- @param Targets table The targets of the action camera sequence.
--- @param Preset string The name of the action camera preset to use, or "Any" to use a default camera.
--- @param Position string The desired position of the camera, either "Any", "Left", or "Right".
--- @param TransitionTime number The duration of the camera transition in milliseconds.
--- @param Duration number The duration of the action camera sequence in milliseconds.
--- @param FadeOutTime number The duration of the fade-out at the end of the sequence in milliseconds.
--- @param Float boolean Whether the camera should float around the target.
--- @return nil
---
function SetpieceActionCamera.ExecThread(state, Actors, Targets, Preset, Position, TransitionTime, Duration, FadeOutTime, Float)
	local attacker, target = Targets[1], Actors[1]
	local pos, lookat, preset = SetpieceActionCamera.CalcCamera(attacker, target, Preset, Position)
	SetActionCameraDirect(attacker, target, pos, lookat, preset, not Float, MulDivRound(TransitionTime, 1000, GetTimeFactor()))
	Sleep(Max(Duration - FadeOutTime, 1))
	local dlg = GetDialog("XSetpieceDlg")
	if dlg then
		dlg:FadeOut(FadeOutTime)
	end	
	RemoveActionCamera("force")
end

---
--- Skips the current action camera sequence by removing the action camera.
---
--- @param state table The current state of the game.
--- @param ... any Additional arguments (not used).
--- @return nil
---
function SetpieceActionCamera.Skip(state, ...)
	RemoveActionCamera("force")
end

-- Single-unit Action Camera
DefineClass.SetpieceActionCameraSingle = {
	__parents = { "PrgSetpieceCommand" },
	properties = {
		{ id = "Actors", name = "Actor", editor = "choice", default = "", items = SetpieceActorsCombo, variable = true, },
		{ id = "TargetOffset", name = "Target Offset", editor = "number", default = 2*guim, scale = "m", min = 10*guic },
		{ id = "TargetHeight", name = "Target Height", editor = "number", default = 0, scale = "m" },
		{ id = "TargetAngleOffset", name = "Target Angle Offset", editor = "number", default = 0, scale = "deg" },
		{ id = "Preset", name = "Action camera preset", editor = "preset_id", default = "Any", preset_class = "ActionCameraDef", extra_item = "Any", },
		{ id = "Position", editor = "choice", default = "Any", items = { "Any", "Left", "Right" }, },
		{ id = "TransitionTime", name = "Transition (ms)", editor = "number", default = 500, },
		{ id = "Duration", name = "Duration (ms)", editor = "number", default = 2000, },
		{ id = "FadeOutTime", name = "Fade out time (ms)", editor = "number", default = 700, },
		{ id = "Float", name = "Float camera around", editor = "bool", default = false, },
	},
	EditorName = "Action camera (single)",
	EditorSubmenu = "Move camera",
}

--- Calculates the target position for a single-unit action camera.
---
--- @param Actors table A table of actors involved in the action camera sequence.
--- @param TargetOffset number The offset distance from the attacker to the target position.
--- @param TargetHeight number The height of the target position.
--- @param TargetAngleOffset number The angle offset from the attacker's angle to the target position.
--- @return point The calculated target position.
function SetpieceActionCameraSingle.CalcTarget(Actors, TargetOffset, TargetHeight, TargetAngleOffset)
	local attacker = Actors[1]
	if not IsValid(attacker) then return end
	local target = attacker:GetPos() + Rotate(point(TargetOffset, 0, 0), attacker:GetAngle() + TargetAngleOffset)
	target = target:SetTerrainZ(TargetHeight)
	return target
end

---
--- Executes the action camera sequence for a single unit.
---
--- @param state table The current state of the game.
--- @param Actors table A table of actors involved in the action camera sequence.
--- @param TargetOffset number The offset distance from the attacker to the target position.
--- @param TargetHeight number The height of the target position.
--- @param TargetAngleOffset number The angle offset from the attacker's angle to the target position.
--- @param Preset string The action camera preset to use.
--- @param Position string The position of the camera relative to the actors.
--- @param TransitionTime number The duration of the camera transition in milliseconds.
--- @param Duration number The duration of the action camera sequence in milliseconds.
--- @param FadeOutTime number The duration of the fade out effect in milliseconds.
--- @param Float boolean Whether to float the camera around the target.
--- @return nil
---
function SetpieceActionCameraSingle.ExecThread(state, Actors, TargetOffset, TargetHeight, TargetAngleOffset, Preset, Position, TransitionTime, Duration, FadeOutTime, Float)
	local target = SetpieceActionCameraSingle.CalcTarget(Actors, TargetOffset, TargetHeight, TargetAngleOffset)
	return SetpieceActionCamera.ExecThread(state, Actors, {target}, Preset, Position, TransitionTime, Duration, FadeOutTime, Float)
end

--- Returns a string that represents the editor view for the action camera (single) setpiece.
---
--- @return string The editor view string.
function SetpieceActionCameraSingle:GetEditorView()
	return self:GetWaitCompletionPrefix() .. self:GetCheckpointPrefix() .. string.format("Action camera (single) from '%s'", self.Actors)
end

---
--- Skips the current action camera sequence.
---
--- @param state table The current state of the game.
--- @param ... any Additional arguments (unused).
--- @return nil
---
function SetpieceActionCameraSingle.Skip(state, ...)
	RemoveActionCamera("force")
end


----- Tactical Camera

DefineClass.SetpieceTacCamera = {
	__parents = { "PrgSetpieceCommand" },
	properties = {
		{ id = "Actors", name = "Actor", editor = "choice", default = "", items = SetpieceActorsCombo, variable = true, },
		{ id = "TransitionTime", name = "Transition TIme", editor = "number", min = 0, default = 500, scale = "sec" },
		{ id = "FaceActor", name = "Face Actor", editor = "bool", default = false },
		{ id = "Zoom", name = "Set Zoom Level", editor = "bool", default = false },
		{ id = "ZoomLevel", name = "Zoom Level", editor = "number", slider = true,
			no_edit = function(self) return not self.Zoom end,
			min = hr.CameraTacMinZoom, max = hr.CameraTacMaxZoom,
			default = (hr.CameraTacMinZoom + hr.CameraTacMaxZoom) / 2, },
		{ id = "CustomFloor", name = "Set Floor", editor = "bool", default = false },
		{ id = "Floor", editor = "number", default = hr.CameraTacMinFloor, min = hr.CameraTacMinFloor, max = hr.CameraTacMaxFloor, slider = true, no_edit = function(self) return not self.CustomFloor end, },
	},
	EditorName = "Tactical camera",
	EditorSubmenu = "Move camera",
}

---
--- Rotates the tactical camera to face the specified actor.
---
--- @param obj table The actor to face the camera towards.
---
function SetpieceTacCamera.CameraFaceActor(obj)
	local angle = obj:GetAngle()
	local pos, look_at = cameraTac.GetPosLookAt()
		
	local dir = look_at - pos
	local len = dir:SetZ(0):Len()
		
	local new_lookat = pos + Rotate(point(len, 0, 0), angle - 180*60):SetZ(dir:z())
	cameraTac.SetCamera(pos, new_lookat, 0, hr.CameraTacPosEasing)
end

---
--- Executes the tactical camera command.
---
--- @param state table The current state of the game.
--- @param Actors table The actors to move the camera to.
--- @param TransitionTime number The time in milliseconds for the camera transition.
--- @param FaceActor boolean Whether to rotate the camera to face the first actor.
--- @param Zoom boolean Whether to set the zoom level.
--- @param ZoomLevel number The zoom level to set, between 0 and 1.
--- @param CustomFloor boolean Whether to set a custom floor level.
--- @param Floor number The floor level to set, between hr.CameraTacMinFloor and hr.CameraTacMaxFloor.
--- @return nil
---
function SetpieceTacCamera.ExecThread(state, Actors, TransitionTime, FaceActor, Zoom, ZoomLevel, CustomFloor, Floor)
	local actor = Actors[1]

	if FaceActor then
		SetpieceTacCamera.CameraFaceActor(actor)
	end
	
	if Zoom then
		cameraTac.SetZoom(ZoomLevel * 10)
	end
	TransitionTime = Max(0, TransitionTime)
	SnapCameraToObj(actor, "force", CustomFloor and Floor, TransitionTime)
	if TransitionTime > 0 then
		Sleep(TransitionTime)
	end
end

---
--- Returns a string that describes the current state of the tactical camera.
---
--- @return string The description of the tactical camera state.
---
function SetpieceTacCamera:GetEditorView()
	return self:GetWaitCompletionPrefix() .. self:GetCheckpointPrefix() .. string.format("Move tac camera to '%s'", self.Actors)
end

---
--- Skips the tactical camera command.
---
--- @param state table The current state of the game.
--- @param Actors table The actors to move the camera to.
--- @param TransitionTime number The time in milliseconds for the camera transition.
--- @param ... any Additional arguments to pass to the ExecThread function.
--- @return nil
---
function SetpieceTacCamera.Skip(state, Actors, TransitionTime, ...)
	return SetpieceTacCamera.Exec(state, Actors, 0, ...)
end

function OnMsg.CanSaveGameQuery(query)
	local dlg = GetDialog("XSetpieceDlg")
	if dlg then
		query.setpiece = dlg.setpiece
	end
end

---
--- Executes a setpiece in a real-time thread.
---
--- @param setpiece table The setpiece to test.
---
function NetSyncEvents.CheatPlaySetpiece(setpiece)
	CreateRealTimeThread(function()
		setpiece:Test()
	end)
end


----- Add a CameraMode property for hiding objects behavior into the common SetpieceCamera setpiece command

AppendClass.SetpieceCamera = { properties = {
	{ category = "Camera & Movement Type", id = "CameraMode", name = "Camera-object behavior", editor = "choice", default = "Default", help = "The object hiding behavior of the camera.", 
		items = function (self) return { "Default", "Hide all", "Show all", "HideAboveFloor" } end, },
	{ category = "Camera & Movement Type", id = "HidesFloorsAbove", name = "HidesFloorsAbove", editor = "number", default = 100, },
} }

local old_SetpieceCamera_ExecThread = SetpieceCamera.ExecThread
---
--- Executes a setpiece camera command in a real-time thread.
---
--- @param state table The current state of the game.
--- @param CamType string The type of camera to use.
--- @param Easing string The easing function to use for the camera movement.
--- @param Movement string The type of camera movement.
--- @param Interpolation string The type of camera interpolation.
--- @param Duration number The duration of the camera movement in milliseconds.
--- @param PanOnly boolean Whether to only pan the camera.
--- @param Lightmodel string The lightmodel to use.
--- @param LookAt1 table The first point to look at.
--- @param Pos1 table The first position.
--- @param LookAt2 table The second point to look at.
--- @param Pos2 table The second position.
--- @param FovX number The field of view in the X axis.
--- @param Zoom number The zoom level.
--- @param CamProps table Additional camera properties.
--- @param DOFStrengthNear number The depth of field strength for the near plane.
--- @param DOFStrengthFar number The depth of field strength for the far plane.
--- @param DOFNear number The near depth of field plane.
--- @param DOFFar number The far depth of field plane.
--- @param DOFNearSpread number The near depth of field spread.
--- @param DOFFarSpread number The far depth of field spread.
--- @param CameraMode string The camera mode to use.
--- @param HidesFloorsAbove number The number of floors above to hide.
--- @return nil
---
function SetpieceCamera.ExecThread(state, CamType, Easing, Movement, Interpolation, Duration, PanOnly, Lightmodel, LookAt1, Pos1, LookAt2, Pos2, FovX, Zoom, CamProps,DOFStrengthNear, DOFStrengthFar, DOFNear, DOFFar, DOFNearSpread, DOFFarSpread, CameraMode, HidesFloorsAbove)
	CameraMode = CameraMode == "Default" and state.setpiece.CameraMode or CameraMode
	apply_camera_mode(CameraMode, HidesFloorsAbove)
	old_SetpieceCamera_ExecThread(state, CamType, Easing, Movement, Interpolation, Duration, PanOnly, Lightmodel, LookAt1, Pos1, LookAt2, Pos2, FovX, Zoom, CamProps, DOFStrengthNear, DOFStrengthFar, DOFNear, DOFFar, DOFNearSpread, DOFFarSpread, CameraMode, HidesFloorsAbove)
	apply_camera_mode(state.setpiece and state.setpiece.CameraMode) -- no need to do this in .Skip, the setpiece always restores the Default behavior in OnSetpieceEnded
end


----- Light TOD Weather

DefineClass.SetpieceTODWeather = {
	__parents = { "PrgExec" },
	properties = {
		{ id = "TimeOfDay", name = "Time of Day", editor = "combo", default = "Day",
			items = function (self) return PresetsCombo("GameStateDef", "time of day", "Any") end,
		},
		{ id = "Weather", name = "Weather", editor = "combo", default = "Default", 
			items = function (self) return PresetsCombo("GameStateDef", "weather", "Default") end,
		},
	},
	StatementTag = "Setpiece",
	EditorName = "Time-of-day weather",
	EditorSubmenu = "Commands",
	EditorView = Untranslated("Sets <u(TimeOfDay)> <u(Weather)>"),
}

---
--- Sets the time of day and weather for the current setpiece.
---
--- @param TOD string The time of day to set.
--- @param Weather string The weather to set.
---
function SetpieceTODWeather:Exec(TOD, Weather)
	gv_ForceWeatherTodRegion = {tod = TOD, weather = Weather	}
	local lightmodel = mapdata:ChooseLightmodel()
	SetLightmodel(1, lightmodel)
end

DefineClass.SetStartCombatAnim = {
	__parents = { "PrgSetpieceCommand" },
	properties = {
		{ id = "Actors", name = "Actor", editor = "choice", default = "", items = SetpieceActorsCombo, variable = true, help = "The Actor will be used as the position to spawn the anim object." },
		{ id = "AnimObj", name = "Animation Object", editor = "text", default = "CinematicCamera", help = "Object to be spawned at the position of the Actor." },
		{ id = "Anim", name = "Animation", editor = "text", default = false, help = "Animation to be played from the animation obect." },
		{ id = "AnimDuration", name = "Animation Duration", editor = "number", default = false, help = "Desired Anim duration in ms. If left out - anim's default duration would be used." },
		{ id = "StartCombatLogic", name = "StartCombatLogic", editor = "bool", default = false, },
	},
	EditorName = "Unit - Camera Anim"
}

local AnimForAwareReasonTable = {
	["alerted"] = "camera_Standing_CombatBegin",
	["alerter"] = "camera_Standing_CombatBegin3",
	["attacked"] = "camera_Standing_CombatBegin4",
	["surprised"] = "camera_Standing_CombatBegin2",
}

---
--- Executes a setpiece command to start a combat animation.
---
--- @param state table The state of the setpiece command.
--- @param Actors table The actors to use for the animation.
--- @param AnimObj string The name of the animation object to spawn.
--- @param Anim string The name of the animation to play.
--- @param AnimDuration number The desired duration of the animation in milliseconds.
--- @param StartCombatLogic boolean Whether to start combat logic after the animation.
---
function SetStartCombatAnim.ExecThread(state, Actors, AnimObj, Anim, AnimDuration, StartCombatLogic)
	-- first, interrupt all other SetpieceCamera camera interpolations
	for _, command in ipairs(state and state.root_state.commands) do
		if command.thread ~= CurrentThread() and command.class == "SetStartCombatAnim" then
			Wakeup(command.thread) -- interrupts InterpolateCameraMaxWakeup
		end
	end
	
	local animObj = PlaceObj(AnimObj)
	animObj:SetOpacity(0)
	state.animObj = animObj
	local unit = table.rand(Actors, InteractionRand(1000000, "StartCombat"))
	state.unit = unit
	animObj:SetPos(unit:GetVisualPosXYZ())
	animObj:SetAngle(unit:GetAngle())

	local anim
	if Anim and Anim ~= "" then
		anim = Anim
	else
		local aware_reason = unit.pending_awareness_role
		local anim_variation =  AnimForAwareReasonTable[aware_reason]
		if anim_variation then
			anim = anim_variation
		else
			local randomAnim = InteractionRand(4, "CinematicCamera")
			if randomAnim == 0 then
				anim = "camera_Standing_CombatBegin"
			else
				anim = "camera_Standing_CombatBegin" .. (randomAnim + 1)
			end
			assert(false, string.format("Anim for aware reason '%s' was not found. Picked at random '%s'", tostring(aware_reason), tostring(anim)))
		end
	end
	
	local cleanAnim, angle = CheckAnimVisibility(animObj, anim, 120, unit)
	if cleanAnim then
		animObj:SetAngle(angle)
	else
		anim = "camera_Standing_CombatBegin_Fallback"
	end

	local floor = GetStepFloor(unit)
	SnapCameraToObj(unit, "force", floor, 0, "none")
	local camera = { GetCamera() }
	state.camera = camera
	
	animObj:SetStateText(anim, 0, 0)
	cameraMax.SetAnimObj(animObj)
	cameraMax.Activate()

	local originalAnimDuration = animObj:GetAnimDuration(anim)
	if AnimDuration then
		local animSpeedMod = MulDivRound( originalAnimDuration, 1000, AnimDuration) 
		animObj:SetAnimSpeedModifier(animSpeedMod)
	end
	local sleepTime = animObj:GetAnimDuration(anim)
	if sleepTime > 1 then
		Sleep(sleepTime)
	end
	
	if not StartCombatLogic and not AnimDuration then
		while not state.root_state:IsCompleted("TargetDead") do
			WaitMsg(state.root_state)
		end
	end
	
	cameraMax.Activate(false)
	if IsValid(animObj) then
		cameraMax.SetAnimObj(false)
		DoneObject(animObj)
	end
	cameraTac.Activate(true)
	SetCamera(unpack_params(camera))
	if StartCombatLogic then
		AdjustCombatCamera("set", "instant")
		LockCameraMovement("start_combat")
	end
	floor = GetStepFloor(unit)
	SnapCameraToObj(unit, "force", floor, 0, "none")
end

---
--- Skips the start combat animation and performs the following actions:
--- - Deactivates the cameraMax object
--- - If a state.animObj exists and is valid, sets the cameraMax object to false and destroys the animObj
--- - Activates the cameraTac object
--- - Sets the camera to the stored state.camera
--- - If StartCombatLogic is true, adjusts the combat camera and locks the camera movement
--- - Gets the step floor for the state.unit and snaps the camera to the unit
---
--- @param state table The state table containing the animation and camera information
--- @param Actors table The list of actors involved in the animation
--- @param AnimObj table The animation object
--- @param Anim string The name of the animation
--- @param AnimDuration number The duration of the animation
--- @param StartCombatLogic boolean Whether to start combat logic
--- @param ... any Additional arguments
function SetStartCombatAnim.Skip(state, Actors, AnimObj, Anim, AnimDuration, StartCombatLogic, ...)
	cameraMax.Activate(false)
	if state.animObj and IsValid(state.animObj) then
		cameraMax.SetAnimObj(false)
		DoneObject(state.animObj)
	end
	cameraTac.Activate(true)
	SetCamera(unpack_params(state.camera))
	if StartCombatLogic then
		AdjustCombatCamera("set", "instant")
		LockCameraMovement("start_combat")
	end
	local floor = GetStepFloor(state.unit)
	SnapCameraToObj(state.unit, "force", floor, 0, "none")
end


----- Hide Group

DefineClass.SetpieceHideGroup = {
	__parents = { "PrgSetpieceCommand" },
	properties = {
		{id = "Actors", name = "Actor(s)", editor = "choice", default = "", items = SetpieceActorsCombo, variable = true},
		{id = "EphemeralOnly", name = "Ephemeral Only", editor = "bool", default = false, help = "Hides only units marked as ephemeral"},
		{id = "ALOnly", name = "Ambient Life Only", editor = "bool", default = false, help = "Hides only AL units(spawned by AmbientZoneMarker)"},
	},
	EditorName = "Hide Group",
}

---
--- Returns a string representation of the editor view for this SetpieceHideGroup command.
---
--- @return string The editor view string
function SetpieceHideGroup:GetEditorView()
	return self:GetWaitCompletionPrefix() .. self:GetCheckpointPrefix() .. string.format("Hide Actor(s) '%s' die", self.Actors)
end

---
--- Executes the SetpieceHideGroup command, hiding the specified actors.
---
--- @param state table The state table containing the setpiece information.
--- @param Actors table The list of actors to hide.
--- @param EphemeralOnly boolean If true, only hides ephemeral units.
--- @param ALOnly boolean If true, only hides ambient life units.
---
function SetpieceHideGroup.ExecThread(state, Actors, EphemeralOnly, ALOnly)
	if not next(Actors) then return end
	
	local unit_actor_present
	for _, actor in ipairs(Actors) do
		if IsValid(actor) then
			if IsKindOf(actor, "Unit") then
				if (not EphemeralOnly or actor.ephemeral) and (not ALOnly or actor:IsAmbientUnit()) then
					actor:AddStatusEffect("SetpieceHidden")
					state.setpiece.hidden_actors = state.setpiece.hidden_actors or {}
					table.insert(state.setpiece.hidden_actors, actor)
					unit_actor_present = true
				end
			else
				actor:SetVisible(false)
				state.setpiece.hidden_actors = state.setpiece.hidden_actors or {}
				table.insert(state.setpiece.hidden_actors, actor)
			end
		end
	end
	if unit_actor_present then
		ReapplyUnitVisibility()
	end
end

---
--- Checks the visibility of an animation on a unit from the camera's perspective.
---
--- @param obj table The object that the animation is being played on.
--- @param anim string The name of the animation to check.
--- @param angleOffset number The angle offset to check around the object's current angle.
--- @param unit table The unit that the animation is being played on.
--- @param debug boolean If true, adds debug vectors to visualize the sight checks.
---
--- @return boolean Whether the animation is visible from the camera's perspective.
--- @return number The angle at which the animation is visible, or the original angle if no clear angle is found.
function CheckAnimVisibility(obj, anim, angleOffset, unit, debug)
	local animIdx = GetStateIdx(anim)
	local animDur = GetAnimDuration(obj:GetEntity(), anim)
	local cameraIdx = obj:GetSpotBeginIndex("Camera")
	
	local targetParts = {}
	--targetParts[1] = unit:GetSpotLocPos(unit:GetSpotBeginIndex("Torso"))
	--targetParts[2] = unit:GetSpotLocPos(unit:GetSpotBeginIndex("Groin"))
	targetParts[1] = unit:GetSpotLocPos(unit:GetSpotBeginIndex("Head"))
	
	local animPhases = {}
	animPhases[1] = 0
	animPhases[2] = MulDivRound(animDur, 17, 100)
	animPhases[3] = MulDivRound(animDur, 33, 100)
	animPhases[4] = MulDivRound(animDur, 50, 100)
	animPhases[5] = MulDivRound(animDur, 67, 100)
	animPhases[6] = MulDivRound(animDur, 84, 100)
	animPhases[7] = MulDivRound(animDur, 100, 100) - 1
	
	local clearSight = false
	local finalAngle = false
	local originAngle = obj:GetAngle()
	local cacheFirstAngle

	--Check 3 different angles: - angleOffset, original angle, + angleOffset.
	for testAngle = originAngle - angleOffset * 60, originAngle + angleOffset * 60, angleOffset * 60 do
		obj:SetAngle(testAngle)
		--Check different phases of the anim, if at least one body part of the unit could be seen.
		clearSight = true
		for phase, dur in ipairs(animPhases) do
			if not clearSight then break end
			local cameraSpot = obj:GetSpotLocPos(animIdx, dur, cameraIdx)
			--Check collision from camera to main spots of unit.
			for _, targetSpot in ipairs(targetParts) do
				if not clearSight then break end

				if debug then
					--red from first original angle, green from - offset, blue from + offset
					DbgAddVector(cameraSpot, targetSpot - cameraSpot, RGB(testAngle == originAngle and 255 or 0,testAngle == originAngle - angleOffset * 60 and 255 or 0,testAngle == originAngle + angleOffset * 60 and 255 or 0))
				end
				clearSight = IsSightClear(cameraSpot, targetSpot)
			end
		end
		
		--If first angle is clear, make sure that second (original angle) is not clear and only then return it as an option.
		if clearSight and testAngle ~= originAngle - angleOffset * 60 then
			finalAngle = testAngle
			break 
		elseif clearSight and testAngle == originAngle - angleOffset * 60 then
			cacheFirstAngle = testAngle
		elseif cacheFirstAngle then
			finalAngle = cacheFirstAngle
			clearSight = true
			break
		end
	end
	
	obj:SetAngle(originAngle)
	return clearSight, finalAngle
end

---
--- Checks if there is a clear line of sight between two positions.
---
--- @param cameraPos table The position of the camera.
--- @param targetPos table The position of the target.
--- @return boolean True if there is a clear line of sight, false otherwise.
---
function IsSightClear(cameraPos, targetPos)
	local obstacles = { min_dist = max_int }
	CalcSrcTarObstacles(cameraPos, targetPos, obstacles, nil, true)
	return obstacles and #obstacles == 0
 end
 
 function OnMsg.SetpieceStartExecution()
	CloseMenuDialogs()
 end
 
MapVar("g_NonBlockingSetpiecesPlaying", function() return {} end)

function OnMsg.SetpieceEndExecution(setpiece)
	if not g_NonBlockingSetpiecesPlaying then return end
	local stateIdx = table.find(g_NonBlockingSetpiecesPlaying, "setpiece", setpiece)
	table.remove(g_NonBlockingSetpiecesPlaying, stateIdx)
end

---
--- Skips all non-blocking setpieces that are currently playing.
---
--- This function is intended to be called from the game time thread.
--- It iterates through the list of non-blocking setpieces that are currently playing,
--- and calls the `Skip()` method on each one to skip their execution.
--- After skipping all the setpieces, the `g_NonBlockingSetpiecesPlaying` table is cleared.
---
--- @function SkipNonBlockingSetpieces
--- @return nil
---
function SkipNonBlockingSetpieces()
	assert(IsGameTimeThread())
	if not g_NonBlockingSetpiecesPlaying then return end
	for i, setpiece in ipairs(g_NonBlockingSetpiecesPlaying) do
		setpiece:Skip()
	end
	g_NonBlockingSetpiecesPlaying = {}
end


----- Play Effects (redefined for Jagged Alliance 3 to support effects with __waitexec that take time)

PrgPlayEffect.ForbiddenEffectClasses = { "PlaySetpiece", "UnitStartConversation" } -- list of classnames of effects which can't be placed in a PrgPlayEffect

---
--- Executes a sequence of effects in a new thread.
---
--- This function is used to execute a sequence of effects in a new thread, which is required for compatibility with existing setpieces. It ensures that actors are spawned correctly, as executing the effects was previously done via `WaitExecuteSequentialEffects`, which did that in a new thread.
---
--- The function iterates through the list of effects, executing each one in succession and storing the currently running effect in the setpiece state. After all effects have been executed, the state is updated to indicate that the sequence has completed.
---
--- @param state table The state of the setpiece, used to store the currently running effect.
--- @param effects table The list of effects to be executed.
---
function PrgPlayEffect.ExecThread(state, effects)
	-- required for compatibility with existing setpieces, e.g. for actors to be spawned
	-- (as executing the effects was done via WaitExecuteSequentialEffects, which did that in a new thread)
	Sleep(0)
	
	-- execute the effects in succession, storing the currently running effect in the setpiece state
	local stack = {}
	for idx, effect in ipairs(effects) do
		state[effects] = idx
		effect:ExecuteWait(stack)
	end
	state[effects] = #effects + 1
end

---
--- Skips the remaining effects in a sequence of effects.
---
--- This function is used to skip the execution of the remaining effects in a sequence that is being executed by `PrgPlayEffect.ExecThread()`. It checks the current index of the effects being executed, and skips the remaining effects from that point forward.
---
--- If an effect has a `__waitexec` field defined, it is assumed to be a special effect that requires a `__skip` method to be defined. In this case, the `__skip` method is called to skip the effect. Otherwise, the effect is simply executed using its `__exec` method.
---
--- @param state table The state of the setpiece, used to get the current index of the effects being executed.
--- @param effects table The list of effects to be skipped.
---
function PrgPlayEffect.Skip(state, effects)
	-- the execution thread has already been stopped (before the setpiece code calls Skip)
	-- skip the effects from the currently running one forward
	local current_idx = state[effects] or 1
	for i = current_idx, #effects do
		local e = effects[i]
		if e.__waitexec ~= Effect.__waitexec then
			assert(e.__skip) -- if __waitexec is defined, a special __skip is required
			e:__skip()
		else
			e:__exec()
		end
	end
end

---
--- Gets any errors associated with the effects in this PrgPlayEffect instance.
---
--- This function checks each effect in the `Effects` table of the PrgPlayEffect instance and returns any errors that are found. Errors can occur if the effect is of a forbidden type (as defined in `PrgPlayEffect.ForbiddenEffectClasses`), or if the effect has a `__waitexec` field defined but no `__skip` method.
---
--- @return string|nil A string containing any error messages, or `nil` if no errors were found.
---
function PrgPlayEffect:GetError()
	local results
	for _, e in ipairs(self.Effects) do
		local err
		if e:IsKindOfClasses(PrgPlayEffect.ForbiddenEffectClasses) then
			err = string.format("Effects of type %s can't be played from setpieces", e.class)
		elseif e.__waitexec ~= Effect.__waitexec and not e.__skip then
			err = string.format("Effect %s has __waitexec, but has no __skip method defined, so it can't be used in a setpiece", e.class)
		end
		if err then
			results = results or {}
			results[#results+1] = err
		end
	end
	if results then
		return table.concat(results, "\n")
	end
end

--- Closes the loading screen dialog when loading a saved game.
---
--- This function is used to close the loading screen dialog when loading a saved game. It checks if the loading screen dialog is open due to a "load savegame", "zulu load savegame", or "load game data" reason, and then closes the loading screen dialog for those reasons.
---
--- @function CloseLoadGameLoadingScreen
--- @return nil
function CloseLoadGameLoadingScreen()
	-- Fix for loading a save on a sector which had a setpiece added to OnEnterMap
	local loadingScreenDlg = GetDialog("XZuluLoadingScreen")
	local reasonsOpen = loadingScreenDlg and loadingScreenDlg:GetOpenReasons()
	if reasonsOpen and (reasonsOpen["load savegame"] or reasonsOpen["zulu load savegame"] or  reasonsOpen["load game data"]) then
		SectorLoadingScreenClose("idLoadingScreen", "load savegame")
		SectorLoadingScreenClose("idLoadingScreen", "zulu load savegame")
		SectorLoadingScreenClose("idLoadingScreen", "load game data")
	end
end
