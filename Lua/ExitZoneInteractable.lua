DefineClass.ExitZoneInteractable = {
	__parents = { "EditorVisibleObject", "Interactable", "Object", "GridMarker" },
	properties = {
		{ category = "Enabled Logic", editor = "bool", id = "HideVisualWhenDisabled", default = false },
		{ category = "Travel", editor = "combo", id = "SectorOverride", items = function() return GetCampaignSectorsCombo() end, default = false },
		{ category = "Travel", editor = "bool", id = "IsUnderground", name = "IsUndergroundExit", default = false },
		{ category = "Travel", editor = "bool", id = "RetreatInConflictOnlyIfCameFromHere", default = false },
		{ category = "Travel", editor = "choice", name = "Entity", id = "entity", items = function() return table.get(Presets, "EntityVariation", "Default", "TravelObject", "Entities") or { "UITravelObject_01" } end, default = "UITravelObject_01" },
	},

	-- Change in GridMarkerType editor
	AreaWidth = 5,
	AreaHeight = 5,
	
	BadgePosition = "average",
	Type = "ExitZoneInteractable",
	
	fake_visual_obj = false, -- Object to be used when one isn't explicitly placed
	discovered = true
}

--- Initializes a fake visual object for the ExitZoneInteractable.
---
--- The fake visual object is used when an ExitZoneInteractable is not explicitly placed in the game world. It is created by placing an object with the specified entity and setting its properties to match the ExitZoneInteractable.
---
--- The fake visual object is added to the visuals_cache of the ExitZoneInteractable, so that it is included in the rendering of the object.
function ExitZoneInteractable:InitFakeVO()
	if not self.fake_visual_obj then
		local obj = PlaceObject(self.entity)
		obj:SetColorizationPalette(g_DefaultColorsPalette)
		obj:SetEnumFlags(const.efSelectable)
		obj:ClearGameFlags(const.gofPermanent)
		obj:SetCollision(false)
		obj.spawner = self
		self.fake_visual_obj = obj
		if self.visuals_cache then
			self.visuals_cache[#self.visuals_cache + 1] = self.fake_visual_obj
		end
	end
end

--- Initializes the fake visual object for the ExitZoneInteractable.
---
--- The fake visual object is used when an ExitZoneInteractable is not explicitly placed in the game world. It is created by placing an object with the specified entity and setting its properties to match the ExitZoneInteractable.
---
--- The fake visual object is added to the visuals_cache of the ExitZoneInteractable, so that it is included in the rendering of the object.
---
--- Additionally, this function evaluates whether a fake visual object is needed for the ExitZoneInteractable based on its properties.
function ExitZoneInteractable:GameInit()
	self:InitFakeVO()
	self:EvaluateNeedForFakeVisual()
end

--- Cleans up the fake visual object associated with the ExitZoneInteractable.
---
--- If a fake visual object is present, it is removed from the game world by calling `DoneObject()`. The `fake_visual_obj` field is then set to `false` to indicate that the fake visual object has been cleaned up.
function ExitZoneInteractable:Done()
	if IsValid(self.fake_visual_obj) then
		DoneObject(self.fake_visual_obj)
		self.fake_visual_obj = false
	end
end

--- Sets the entity of the ExitZoneInteractable and updates the fake visual object to match.
---
--- @param value string The new entity to set for the ExitZoneInteractable.
function ExitZoneInteractable:Setentity(value)
	self:ChangeEntity(value)
	if IsValid(self.fake_visual_obj) then
		self.fake_visual_obj:ChangeEntity(value)
		self.fake_visual_obj:SetColorizationPalette(g_DefaultColorsPalette)
	end
	self:SetColorizationPalette(g_DefaultColorsPalette)
	self.entity = value
end

--- Populates the visual cache for the ExitZoneInteractable.
---
--- This function calls the `PopulateVisualCache` function of the parent `Interactable` class, and then removes the `ExitZoneInteractable` itself from the `visuals_cache` table, as an `ExitZoneInteractable` should never be its own visual.
---
--- The function then iterates through the `visuals_cache` table and sets the `visual_of_interactable` field of any `Interactable` objects to the current `ExitZoneInteractable`.
---
--- Finally, the function commented out a block of code that would have added the `fake_visual_obj` to the `visuals_cache` table. This functionality is likely handled elsewhere in the codebase.
function ExitZoneInteractable:PopulateVisualCache()
	Interactable.PopulateVisualCache(self)
	table.remove_value(self.visuals_cache, self) -- ExitZoneInteractable is never its own visual.
	
	local visuals = self.visuals_cache
	for i, obj in ipairs(visuals) do
		if IsKindOf(obj, "Interactable") then
			obj.visual_of_interactable = self
		end
	end
	
--[[	if IsValid(self.fake_visual_obj) then
		self.visuals_cache[#self.visuals_cache + 1] = self.fake_visual_obj
	end]]
end

local function lUpdateVisualsOfExitZoneInteractables()
	FireNetSyncEventOnHost("UpdateVisualsOfExitZoneInteractables")
end

--- Iterates through all `ExitZoneInteractable` objects in the current sector and updates their fake visual objects based on the current game state.
---
--- If the current sector is in conflict, the function will skip updating the fake visual objects for `ExitZoneInteractable` objects that have the `RetreatInConflictOnlyIfCameFromHere` flag set.
---
--- The function also marks all sectors that can be accessed from the current sector as discovered.
function NetSyncEvents.UpdateVisualsOfExitZoneInteractables()
	local sector = gv_Sectors[gv_CurrentSectorId]
	local inConflict = sector and sector.conflict
	
	MapForEach("map", "ExitZoneInteractable", function(o)
		 o:EvaluateNeedForFakeVisual()
		 
		 if o.RetreatInConflictOnlyIfCameFromHere and inConflict then return end
		 
		 if o:IsMarkerEnabled() then
			 -- Mark all sectors that can be accessed from this sector as discovered
			 local nextSector = o:GetNextSector()
			 if nextSector then
				nextSector.discovered = true
			 end
		 end
	end)
end

OnMsg.ExplorationStart = lUpdateVisualsOfExitZoneInteractables
OnMsg.DeploymentStarted = lUpdateVisualsOfExitZoneInteractables
OnMsg.CombatEnd = lUpdateVisualsOfExitZoneInteractables

---
--- Evaluates whether the `ExitZoneInteractable` object needs a fake visual object and updates its visibility and collision state accordingly.
---
--- The function first initializes the fake visual object using `self:InitFakeVO()`. It then resolves the visual objects associated with the `ExitZoneInteractable` and checks if the number of visual objects is 0 or less than or equal to 2. If the conditions are met, the function sets `shouldHave` to `true`, indicating that a fake visual object should be created.
---
--- The function also checks if the `HideVisualWhenDisabled` flag is set and if the `ExitZoneInteractable` is not enabled. If both conditions are true, the function sets `shouldHave` to `false`.
---
--- Next, the function checks if the `ExitZoneInteractable` has a valid next sector. If not, it sets `shouldHave` to `false`.
---
--- Finally, the function sets `shouldHave` to `true` if the editor is active, and updates the visibility and collision state of the fake visual object accordingly.
---
--- The function also tries to find a suitable spot for the fake visual object by checking the surrounding voxels for any existing `GridMarker` objects. If a suitable spot is found, the function sets the position of the fake visual object to that spot.
---
function ExitZoneInteractable:EvaluateNeedForFakeVisual()
	self:InitFakeVO()

	local visualObjects = ResolveInteractableVisualObjects(self)
	local shouldHave
	if #visualObjects == 0 then
		shouldHave = true
	elseif #visualObjects <= 2 then
		local o1, o2 = visualObjects[1], visualObjects[2]
		if (not o1 or o1 == self or o1 == self.fake_visual_obj) and
			(not o2 or o2 == self or o2 == self.fake_visual_obj) then
			shouldHave = true
		end
	end

	if shouldHave and self.HideVisualWhenDisabled and not self:IsMarkerEnabled() then
		shouldHave = false
	end
	
	local nextSector = self:GetNextSector()
	if not nextSector then
		shouldHave = false
	end
	
	shouldHave = shouldHave or IsEditorActive()
	if shouldHave then
		if self.visuals_cache and not table.find(self.visuals_cache, self.fake_visual_obj) then
			self.visuals_cache[#self.visuals_cache + 1] = self.fake_visual_obj
		end
		self.fake_visual_obj:SetEnumFlags(const.efVisible)
		self.fake_visual_obj:SetCollision(true)
	else
		if self.visuals_cache then
			table.remove_value(self.visuals_cache, self.fake_visual_obj)
		end
		self.fake_visual_obj:ClearEnumFlags(const.efVisible)
		self.fake_visual_obj:SetCollision(false)
	end
	
	local dirs = {
		point(const.SlabSizeX, 0, 0),
		point(const.SlabSizeX, 0, 0),
		point(0, const.SlabSizeY, 0),
		point(0, -const.SlabSizeY, 0)
	}
	
	local spotForFakeInteractable = false
	for i, d in ipairs(dirs) do
		local voxel = self:GetPos() + d
		local bbox = GetVoxelBBox(voxel, false, true)
		local boxHasZ = bbox:minz()
		local any = MapGetFirst(bbox, "GridMarker", function(obj) -- NOTE: enumerating in the voxel may be faster than all GridMarkers
			if not boxHasZ then return true end
			
			local x, y, z = obj:GetPosXYZ()
			if not z then z = terrain.GetHeight(x, y) end

			return bbox:PointInside(x, y, z)
		end)
		if not any then
			spotForFakeInteractable = voxel
			break
		end
	end
	
	self.fake_visual_obj:SetPos(spotForFakeInteractable)
	self.fake_visual_obj:SetAngle(self:GetAngle())
end

---
--- Called when the ExitZoneInteractable enters the editor.
--- Calls the EditorEnter method of the EditorVisibleObject base class,
--- and then evaluates the need for a fake visual object.
---
function ExitZoneInteractable:EditorEnter()
	EditorVisibleObject.EditorEnter(self)
	self:EvaluateNeedForFakeVisual()
end

---
--- Called when the ExitZoneInteractable is exiting the editor.
--- Calls the EditorExit method of the EditorVisibleObject and Interactable base classes,
--- and then evaluates the need for a fake visual object.
---
function ExitZoneInteractable:EditorExit()
	EditorVisibleObject.EditorExit(self)
	Interactable.EditorExit(self)
	self:EvaluateNeedForFakeVisual()
end

---
--- Called when the ExitZoneInteractable is moved in the editor.
--- Evaluates the need for a fake visual object to represent the ExitZoneInteractable.
---
function ExitZoneInteractable:EditorCallbackMove()
	self:EvaluateNeedForFakeVisual()
end

---
--- Called when the ExitZoneInteractable is rotated in the editor.
--- Evaluates the need for a fake visual object to represent the ExitZoneInteractable.
---
function ExitZoneInteractable:EditorCallbackRotate()
	self:EvaluateNeedForFakeVisual()
end

---
--- Called when the ExitZoneInteractable is placed in the editor.
---
function ExitZoneInteractable:EditorCallbackPlace()

end

---
--- Gets the next sector that the ExitZoneInteractable leads to.
---
--- @return table|boolean, boolean The next sector, and whether it is an underground sector.
---
function ExitZoneInteractable:GetNextSector()
	if not gv_CurrentSectorId then return false end

	local sectorId, underground = false, false
	if self:IsUndergroundExit() then
		sectorId = gv_Sectors[gv_CurrentSectorId].GroundSector or (gv_CurrentSectorId .. "_Underground")
		underground = self.Groups[1]
	else
		local selfIsUnderground = not not gv_Sectors[gv_CurrentSectorId].GroundSector
		
		for _, dir in ipairs(const.WorldDirections) do
			if self:IsInGroup(dir) then
				local neighSectorId = GetNeighborSector(gv_CurrentSectorId, dir)
				
				-- Underground sectors exits in world directions can only lead to
				-- other underground sectors
				if selfIsUnderground and not IsSectorUnderground(neighSectorId) then
					neighSectorId = false
				end
				
				if neighSectorId and
					not IsTravelBlocked(gv_CurrentSectorId, neighSectorId) and
					not GetDirectionProperty(neighSectorId, gv_CurrentSectorId, "BlockTravelRiver") and
					gv_Sectors[neighSectorId].Map then
					
					sectorId = neighSectorId
					break
				end
			end
		end
	end
	
	if self.SectorOverride then
		sectorId = self.SectorOverride
	end

	return gv_Sectors[sectorId], underground
end

---
--- Checks if the ExitZoneInteractable is an underground exit.
---
--- @return boolean True if the ExitZoneInteractable is an underground exit, false otherwise.
---
function ExitZoneInteractable:IsUndergroundExit()
	return self:IsInGroup("Underground") or self.IsUnderground
end

---
--- Updates the badge text for the ExitZoneInteractable.
---
--- This function checks the current state of the ExitZoneInteractable and sets the text of the
--- interactable badge accordingly. The text will depend on whether the player is in a conflict
--- zone, if they are going underground, or if they are exiting to a new sector.
---
--- @param self ExitZoneInteractable The ExitZoneInteractable instance.
---
function ExitZoneInteractable:BadgeTextUpdate()
	local withCursor = table.find(self.highlight_reasons, "cursor")
	local badgeInstance = self.interactable_badge
	if not badgeInstance or badgeInstance.ui.window_state == "destroying" then return end
	
	if IsUnitPartOfAnyActiveBanter(self) then
		badgeInstance.ui.idText:SetVisible(false)
		return
	end
	
	local unit = UIFindInteractWith(self)
	if unit then	
		local currentSect = gv_Sectors[gv_CurrentSectorId]
		if not currentSect then return end

		local nextSect, underground = self:GetNextSector()
		local nextMapName = nextSect and GetSectorText(nextSect)
		local action = self:GetInteractionCombatAction(unit)
		badgeInstance.ui.idText:SetContext(unit)
		
		local text = action:GetActionDisplayName({unit, self})
		if g_TestExploration then
			text = Untranslated("Cant Travel in Exploration Test")
		elseif underground then
			if IsSectorUnderground(gv_CurrentSectorId) then
				text = T(705526346094, "Exit")
			else
				text = T(749506366915, "Go Underground")
			end
		elseif currentSect.conflict then
			text = T(482029101969, "Retreat To <Map>")
		else
			text = T(500843659226, "Exit To <Map>")
		end

		badgeInstance.ui.idText:SetText(T{text, Map = nextMapName})
	end
	badgeInstance.ui.idText:SetVisible(withCursor)
end

---
--- Determines the appropriate combat action for interacting with the ExitZoneInteractable.
---
--- This function checks various conditions to determine the appropriate combat action for interacting with the ExitZoneInteractable. It takes into account whether the marker is enabled, if deployment has started, if the player is retreating from a conflict zone, and if the next sector has a disabled travel option.
---
--- @param self ExitZoneInteractable The ExitZoneInteractable instance.
--- @param unit Unit The unit attempting to interact with the ExitZoneInteractable.
--- @return CombatAction|boolean The appropriate combat action, or false if interaction is not allowed.
---
function ExitZoneInteractable:GetInteractionCombatAction(unit)
	if not self:IsMarkerEnabled() then return false end
	if gv_DeploymentStarted then return false end
	
	if self.RetreatInConflictOnlyIfCameFromHere then
		local group = self.Groups
		group = group and group[1]
		
		local sector = gv_Sectors[gv_CurrentSectorId]
		if sector and sector.conflict and unit and unit.arrival_dir ~= group then
			return false
		end
	end

	local sector = gv_Sectors[gv_CurrentSectorId]
	if sector and sector.conflict and sector.conflict.disable_travel then return false end
	
	local nextSector = self:GetNextSector()
	if not nextSector then
		return false
	end

	if unit and (unit:IsDowned() or unit:IsDead()) then
		return false
	end

	return CombatActions.Interact_Exit
end

MapVar("g_RetreatThread", false)

---
--- Initiates the process for a unit to leave the current sector through the ExitZoneInteractable.
---
--- This function checks if there is an existing retreat thread running, and if not, creates a new real-time thread to execute the `UnitLeaveSectorInternal` function with the provided unit.
---
--- @param self ExitZoneInteractable The ExitZoneInteractable instance.
--- @param unit Unit The unit attempting to leave the sector.
---
function ExitZoneInteractable:UnitLeaveSector(unit)
	if IsValidThread(g_RetreatThread) then return end
	g_RetreatThread = CreateRealTimeThread(ExitZoneInteractable.UnitLeaveSectorInternal, self, unit)
end

---
--- Checks if the given unit is inside the ExitZoneInteractable's area or the entrance marker's area.
---
--- @param self ExitZoneInteractable The ExitZoneInteractable instance.
--- @param u Unit The unit to check.
--- @return boolean True if the unit is inside the area, false otherwise.
---
function ExitZoneInteractable:IsUnitInside(u)
	local entranceMarker = MapGetMarkers("Entrance", self.Groups and self.Groups[1])
	entranceMarker = entranceMarker and entranceMarker[1] or self
	return self:IsInsideArea(u) or entranceMarker:IsInsideArea(u)
end

-- Original Spec: http://mantis.haemimontgames.com/view.php?id=147486
-- Cases
-- 1. Conflict All Units
--	2. Conflict Partial Units
--	3. No Conflict All Units
--	4. No Conflict Partial Units
-- Subcases, apply these to to each of the above cases.
--	1. Going towards a sector with travel time 0 (cities/roads)
--	2. Going towards a sector with travel time above 0
--	3. To Underground
--	4. To Overground
---
--- Executes the internal logic for a unit to leave the current sector through the ExitZoneInteractable.
---
--- This function checks if the unit can be controlled, finds the next sector the unit should move to, and then determines which squads and units are able to leave the current sector. It then handles the logic for either leaving the sector during a conflict or during exploration, depending on the current sector state.
---
--- @param self ExitZoneInteractable The ExitZoneInteractable instance.
--- @param unit Unit The unit attempting to leave the sector.
---
function ExitZoneInteractable:UnitLeaveSectorInternal(unit)
	if not unit:CanBeControlled() then return end

	local sector, underground = self:GetNextSector()
	if not sector then return end
	local sector_id = sector.Id
	
	local playerSquads = GetSquadsOnMap()
	local leavingSquads = {}
	for i, squadId in ipairs(playerSquads) do
		local squad = gv_Squads[squadId]
		if not squad then goto continue end
	
		-- Find which units can leave
		local thisSquadHasLeavingUnit = false
		for _, id in ipairs(squad.units or empty_table) do
			local u = g_Units[id]
			if u and u:IsLocalPlayerControlled() and self:IsUnitInside(u) and self:IsMarkerEnabled() then
				thisSquadHasLeavingUnit = true
				break
			end
		end
		if thisSquadHasLeavingUnit then
			leavingSquads[#leavingSquads + 1] = squadId
		end
	
		::continue::
	end
	
	local leavingUnits = {}
	for i, squadId in ipairs(leavingSquads) do
		local squad = gv_Squads[squadId]
		if not squad then goto continue end
		
		-- Check if the squad has any tired units
		local exhausted = GetSquadTiredUnits(squad, "Exhausted")
		if exhausted then
			local exhausted_ids = ShowExhaustedUnitsQuestion(squad, exhausted)
			if exhausted_ids then
				-- This needs to be sync so that the split happens completely before we proceed with the exit.
				-- This function it self isn't sync due to various UI popups etc.
				SyncSplitSquad(squad.UniqueId, exhausted_ids)
				ObjModified("hud_squads")
			else
				goto continue
			end
		end
	
		-- Find which units can leave
		for _, id in ipairs(squad.units or empty_table) do
			local u = g_Units[id]
			if u and u:CanBeControlled() and self:IsUnitInside(u) and self:IsMarkerEnabled() then
				table.insert(leavingUnits, u.session_id)
			end
		end
		
		::continue::
	end
	
	local spawned_units = 0
	for i, squadId in ipairs(playerSquads) do
		local squad = gv_Squads[squadId]
		if not squad then goto continue end
		
		for _, id in ipairs(squad.units or empty_table) do
			local u = g_Units[id]
			if u then
				spawned_units = spawned_units + 1
			end
		end
		
		::continue::
	end
	
	-- All were filtered out.
	if #leavingUnits == 0 then return end

	if gv_Sectors[gv_CurrentSectorId].conflict then
		LeaveSectorConflict(sector_id, leavingUnits, underground, spawned_units, unit)
	else
		LeaveSectorExploration(sector_id, leavingUnits, underground, nil, unit:IsLocalPlayerControlled())
	end
end

---
--- Returns the first `ExitZoneInteractable` marker found in the same group as the given `marker`.
---
--- @param marker table The marker to search for an `ExitZoneInteractable` in the same group.
--- @return table|nil The first `ExitZoneInteractable` marker found, or `nil` if none was found.
function GetExitZoneInteractableFromMarker(marker)
	if not marker then return end
	local exitInteractable = MapGetMarkers("ExitZoneInteractable", marker.Groups and marker.Groups[1])
	return exitInteractable and exitInteractable[1]
end

---
--- Retreats the specified units from the current sector during a conflict.
---
--- @param sectorId integer The ID of the sector to leave.
--- @param units table A table of unit session IDs to retreat.
--- @param underground boolean Whether the retreat is going underground or not.
--- @param totalPlayerUnits integer The total number of player units.
--- @param initiatingUnit table The unit that initiated the retreat.
---
--- @return nil
function LeaveSectorConflict(sectorId, units, underground, totalPlayerUnits, initiatingUnit)
	local names = {}
	for _, u in ipairs(units) do
		local unitData = gv_UnitData[u]
		names[#names + 1] = _InternalTranslate(unitData.Nick)
	end
	names = table.concat(names, ", ")
	
	local initiatedByLocalPlayer = initiatingUnit:IsLocalPlayerControlled()
	local state_func = nil
	if not initiatedByLocalPlayer then
		state_func = function() return "disabled" end
	end
	local three_choices = #units > 1
	local res = WaitPopupChoice(GetInGameInterfaceModeDlg(), {
		translate = true,
		text = T{867511434762, "Do you want to retreat the following mercs - <u(names)>?", names = names},
		choice1 = three_choices and T(288455844681, "Retreat All") or T(1138, "Yes"),
		choice1_state_func = state_func,
		choice1_gamepad_shortcut = "ButtonX",
		choice2 = three_choices and T{162642612318, "Retreat <merc>", merc = initiatingUnit.Nick} or T(967444875712, "Cancel"),
		choice2_state_func = three_choices and state_func or nil,
		choice2_gamepad_shortcut = three_choices and "ButtonY" or "ButtonB",
		choice3 = three_choices and T(1000246, "Cancel") or nil,
		choice3_gamepad_shortcut = "ButtonB",
		sync_close = initiatedByLocalPlayer,
	})
	
	if res == 1 then

	elseif res == 2 and three_choices then
		units = {initiatingUnit.session_id}
	else
		return
	end
	
	if #units < totalPlayerUnits then
		NetSyncEvent("RetreatUnits", units, sectorId, underground, totalPlayerUnits - #units)
	else
		LeaveSectorExploration(sectorId, units, underground, true)
	end
end

---
--- Creates a question box that has its OK button enabled only for `localPlayer == true`.
--- The cancel button is enabled for all clients to avoid failure states.
--- Cancel/OK on `localPlayer == true` closes the box on all clients.
---
--- @param parent XWindow The parent window for the question box.
--- @param caption string The caption for the question box.
--- @param text string The text to display in the question box.
--- @param ok_text string The text for the OK button.
--- @param cancel_text string The text for the cancel button.
--- @param obj any An optional object to pass to the callback functions.
--- @param localPlayer boolean Whether the question box is for the local player.
--- @return string, any, any The result of the question box, the dataset, and the input state at close.
---
function WaitQuestion_ZuluSync(parent, caption, text, ok_text, cancel_text, obj, localPlayer)
	--creates a question box that has it's ok enabled only for localPlayer == true
	--cancel is enabled for all clients to evade failure states
	--cancel/ok on localPlayer == true closes box on all clients
	assert(type(parent) == "table" and parent.IsKindOf and parent:IsKindOf("XWindow"), "The first argument must be a parent window. Don't just create 'global' messages, attach them to the correct parent so they'd share their lifetimes.", 1)
	local dialog
	if IsKindOf(caption, "XDialog") then
		dialog = caption
	else
		local func = nil
		if not localPlayer then
			func = function() return "disabled" end
		end
		dialog = CreateQuestionBox(parent, caption, text, ok_text, cancel_text, obj, func, nil, nil, localPlayer)
	end
	local result, dataset, xInputStateAtClose = dialog:Wait() 
	return result, dataset, xInputStateAtClose
end

---
--- Leaves the current sector and enters a new sector, either going underground or above ground.
--- Displays a confirmation dialog to the player before leaving the sector.
---
--- @param sectorId number The ID of the sector to enter.
--- @param units table A table of unit IDs that are leaving the sector.
--- @param underground boolean Whether the player is going underground or not.
--- @param skipNotify boolean Whether to skip displaying the confirmation dialog.
--- @param localPlayer boolean Whether the operation is for the local player.
---
function LeaveSectorExploration(sectorId, units, underground, skipNotify, localPlayer)
	if not skipNotify then
		local popupText
		if underground then
			if IsSectorUnderground(gv_CurrentSectorId) then
				popupText = T(528652976882, "Are you sure you want to exit?")
			else
				popupText = T(261972368205, "Are you sure you want to go underground?")
			end
		else
			popupText = T{397573113952, "Are you sure you want to leave sector <SectorName(current_sector)> and enter sector <SectorName(next_sector)>?", 
				current_sector = gv_Sectors[gv_CurrentSectorId],
				next_sector = gv_Sectors[sectorId],
			}
		end
		
		if WaitQuestion_ZuluSync(GetInGameInterfaceModeDlg(), T(814633909510, "Confirm"), popupText, T(689884995409, "Yes"), T(782927325160, "No"), nil, localPlayer) ~= "ok" then
			return
		end
	end
			
	local special_entrance = underground
	
	local squads = {}
	local playerSquads = GetSquadsOnMap()
	for i, squadId in ipairs(playerSquads) do
		local squad = gv_Squads[squadId]
		if not squad then goto continue end
		
		-- This squad initiated retreat but all the non-retreating units died.
		local thisSquadHasLeavingUnit = false
		for _, id in ipairs(squad.units or empty_table) do
			local u = g_Units[id]
			local ud = gv_UnitData[id]
			if not u and ud and ud.retreat_to_sector then
				thisSquadHasLeavingUnit = true
			end
		end
		if thisSquadHasLeavingUnit then
			table.insert_unique(squads, squadId)
		end
		
		::continue::
	end
	
	for i, u in ipairs(units) do
		local unit = g_Units[u] or gv_UnitData[u]
		local squadId = unit.Squad
		table.insert_unique(squads, squadId)
	end
	
	-- Check for busy squads
	local squadsToMove = {}
	for i, sqId in ipairs(squads) do
		local squad = gv_Squads[sqId]
		local squadToMove = CheckSquadBusy(sqId)
		if squadToMove then 
			squadsToMove[#squadsToMove + 1] = squadToMove
		end
	end
	if #squadsToMove == 0 then return end

	NetSyncEvent("LeaveSectorMap", sectorId, false, special_entrance, squadsToMove)
end

-- Map retreat from non-adjacent sectors is possible when
-- an exit zone interactable has its destination overriden.
-- In these cases travel instantly.
---
--- Checks if two sectors are adjacent on the map.
---
--- @param s1Id number The ID of the first sector.
--- @param s2Id number The ID of the second sector.
--- @return boolean True if the sectors are adjacent, false otherwise.
---
function AreAdjacentSectors(s1Id, s2Id)
	return GetSectorDistance(s1Id, s2Id) <= 1
end

---
--- Moves an entire squad to a different sector on the map.
---
--- @param squad_id number The ID of the squad to move.
--- @param to_sector_id number The ID of the sector to move the squad to.
--- @param from_sector_id number The ID of the sector the squad is currently in.
--- @return boolean True if the squad was moved instantly, false otherwise.
---
function RetreatMoveWholeSquad(squad_id, to_sector_id, from_sector_id)
	local squad = gv_Squads[squad_id]

	local route = GenerateRouteDijkstra(from_sector_id, to_sector_id)
	if not route then route = {to_sector_id} end
	route = {route} -- waypointify
	
	local time = GetSectorTravelTime(from_sector_id, to_sector_id, route, squad.units)
	local instant = not time or time <= 0
	
	-- When the link is multiple sectors teleport between them (186068)
	if route and route[1] and #route[1] > 1 then instant = true end
	
	local from_sector = gv_Sectors[from_sector_id]
	local to_sector = gv_Sectors[to_sector_id]
	
	if not instant then
		-- Tick needs to be considered passed in order for the squad to be considered travelling.
		route.satellite_tick_passed = true
		SetSatelliteSquadRetreatRoute(squad, route, "keepJoiningSquads", "from_map")
	else
		squad.Retreat = false
		if not gv_SatelliteView then SyncUnitProperties("map") end
		SetSatelliteSquadCurrentSector(squad, to_sector_id, "update_pos", "teleported")
		-- For player units we need to sync back to the unit as they will sync back to the unit data in the despawn function
		if not gv_SatelliteView then SyncUnitProperties("session") end
	end
	return instant
end

local function lMoveWholeSquadTacticalView(squad_id, sector_id)
	return RetreatMoveWholeSquad(squad_id, sector_id, gv_CurrentSectorId)
end

---
--- Retreats a single unit to the specified sector.
---
--- @param unit table The unit to retreat.
--- @param sector_id number The ID of the sector to retreat the unit to.
---
function RetreatUnit(unit, sector_id)
	Msg("UnitRetreat", unit)
	local team = unit.team
	unit:Despawn()
	gv_UnitData[unit.session_id].retreat_to_sector = sector_id
	if g_Combat then
		if g_Teams[g_CurrentTeam] == team then
			g_Combat:NextUnit(team, "force")
		end
		g_Combat:CheckEndTurn()
	end
	ObjModified(Game)
	ObjModified(Selection)
	ObjModified("hud_squads")
end

---
--- Cancels the retreat of a unit by resetting its retreat information and arrival direction.
---
--- @param ud table The unit data of the unit to cancel the retreat for.
---
function CancelUnitRetreat(ud)
	-- Try to get the units in the direction they retreated to
	if IsSectorUnderground(ud.retreat_to_sector) then
		ud.arrival_dir = "Underground"
	else
		local dirToRetreatSector = GetSectorDirection(gv_CurrentSectorId, ud.retreat_to_sector)
		ud.arrival_dir = dirToRetreatSector
	end

	ud.retreat_to_sector = false
	ud.already_spawned_on_map = false
end

-- Used for resuming retreat if the last units on the map die
GameVar("gv_LastRetreatedUnit", false)
GameVar("gv_LastRetreatedEntrance", false)

---
--- Retreats the specified units to the given sector, and moves any whole squads that have all units retreated.
---
--- @param session_ids table An array of unit session IDs to retreat.
--- @param sector_id number The ID of the sector to retreat the units to.
--- @param underground boolean Whether the retreat is to an underground sector.
--- @param remaining number The number of units remaining to retreat.
---
function NetSyncEvents.RetreatUnits(session_ids, sector_id, underground, remaining)
	local units = {}
	for _, id in ipairs(session_ids) do
		local unit = g_Units[id]
		if not unit then
			assert(false, "Trying to retreat non existent unit")
			return
		end
		units[#units + 1] = unit
	end

	-- When retreating in conflict force cancel operations of units. (219850)
	SectorOperation_CancelByGame(units)

	-- Record in case the rest of the units die.
	-- We need to call LeaveSectorExploration then.
	gv_LastRetreatedUnit = #session_ids > 0 and session_ids[1]
	gv_LastRetreatedEntrance = { sector_id, underground }

	local check_squads = {}
	for _, unit in ipairs(units) do
		RetreatUnit(unit, sector_id)
		table.insert_unique(check_squads, unit.Squad)
	end
	
	-- check if there are new squads with all mercs retreated
	local squadsToMove = {}
	for _, id in ipairs(check_squads) do
		local retreat_whole_squad = true
		local squad = gv_Squads[id]
		for _, unit in ipairs(squad.units or empty_table) do
			if not gv_UnitData[unit].retreat_to_sector then
				retreat_whole_squad = false
				break
			end
		end
		if retreat_whole_squad then
			lMoveWholeSquadTacticalView(squad.UniqueId, sector_id)
			table.insert(squadsToMove, squad.UniqueId)
		end
	end
	EnsureCurrentSquad()
	ShowTacticalNotification("allyRetreat", nil, T(312444150797, "Retreated successfully"), { number = remaining })
	
	if #squadsToMove > 0 and #GetAllPlayerUnitsOnMap() <= 0 then --no guys left on map
		NetSyncEvents.LeaveSectorMap(sector_id, false, underground, squadsToMove)
	end
end

---
--- Synchronizes the splitting of a squad.
---
--- This function is called when a squad needs to be split, for example when some units in the squad are busy and others are available. It sends a "SplitSquad" event to synchronize the split across the network, and waits for the confirmation that the split has occurred.
---
--- @param squad_id number The ID of the squad to be split.
--- @param available table A table of unit IDs that are available to be split off into a new squad.
--- @return number The ID of the new squad that was created.
function SyncSplitSquad(squad_id, available)
	assert(CanYield())
	NetSyncEvent("SplitSquad", squad_id, available)
	local err, newSquad, oldSquad
	while oldSquad ~= squad_id do
		err, newSquad, oldSquad = WaitMsg("SyncSplitSquad", 1000)
		if err then
			break
		end
	end
	return newSquad
end

---
--- Synchronizes the splitting of a squad.
---
--- This function is called when a squad needs to be split, for example when some units in the squad are busy and others are available. It sends a "SplitSquad" event to synchronize the split across the network, and waits for the confirmation that the split has occurred.
---
--- @param squad_id number The ID of the squad to be split.
--- @param available table A table of unit IDs that are available to be split off into a new squad.
--- @return number The ID of the new squad that was created.
function CheckSquadBusy(squad_id)
	local busy, available = GetSquadBusyAvailable(squad_id)
	if next(busy) then
		local res = GetSplitMoveChoice(busy, available)
		if res == "split" then
			return SyncSplitSquad(squad_id, available)
		elseif res == "cancel" then
			return false
		end
	end
	return squad_id
end

---
--- Synchronizes the leaving of a sector map.
---
--- This function is called when a squad needs to leave the current sector map and travel to a different sector. It handles various aspects of the squad movement, such as canceling ongoing operations, moving the squad to the new sector, and handling any special entrance requirements.
---
--- @param dest_sector_id number The ID of the destination sector.
--- @param spawn_mode string The spawn mode to use when loading the destination sector (e.g. "explore", "attack").
--- @param special_entrance string An optional special entrance direction to use for the squad when arriving at the destination sector.
--- @param squad_ids table A table of squad IDs that are being moved.
---
function NetSyncEvents.LeaveSectorMap(dest_sector_id, spawn_mode, special_entrance, squad_ids)
	if g_Combat and not g_Combat.combat_started then return end
	if IsSetpiecePlaying() then return end

	SectorOperation_SquadOnMove(gv_CurrentSectorId, squad_ids)

	local squads = GetSquadsWithIds(squad_ids)
	local curSector = gv_Sectors[gv_CurrentSectorId]

	-- Apply unaware to non-player units when leaving the map.
	-- This will be synced to the unit data inside MoveWholeSquad
	for _, unit in ipairs(g_Units) do
		if unit.team and not unit.team.player_team then
			unit:AddStatusEffect("Unaware")
		else
			if unit:HasStatusEffect("ManningEmplacement") then
				unit:LeaveEmplacement("instant")
			elseif unit:HasStatusEffect("StationedMachineGun") then
				unit:MGPack()
			end
		end
	end

	-- travel or teleport to other sector instantly
	local satellite = false
	for i, squad in ipairs(squads) do
		-- stop operations
		if dest_sector_id ~= squad.CurrentSector then
			local units = squad.units
			SectorOperation_CancelByGame(units, false, true)
		end

		-- move
		local instant = lMoveWholeSquadTacticalView(squad.UniqueId, dest_sector_id)
		satellite = satellite or not instant
		
		for _, id in ipairs(squad.units) do
			local unit = g_Units[id]
			if unit then
				RetreatUnit(unit, dest_sector_id)
			end
		end
		
		-- Clear retreat flag from units
		for _, u in ipairs(squad.units) do
			local ud = gv_UnitData[u]
			ud.retreat_to_sector = false
		end
		
		-- Overwrite arrival direction with special entrance if any.
		-- This will affect the deployment on the new sector.
		if special_entrance then
			for _, u in ipairs(squad.units) do
				local ud = gv_UnitData[u]
				ud.arrival_dir = special_entrance
			end
		end
	end
	
	local conflict = curSector.conflict
	local bRetreat = false
	for i, squad in ipairs(squads) do
		if conflict then
			if satellite then squad.Retreat = true end
			bRetreat = true
		end
	end
	
	if conflict then
		ResolveConflict(curSector, bRetreat and "no_voice", false, bRetreat)
	end
	
	-- Retreat triggered while in satellite mode, such as by a merc release.
	-- In this case don't force an explore as it can be jarring.
	if gv_SatelliteView then return end
	
	if satellite then
		ForceReloadSectorMap = true
		LocalCheckUnitsMapPresence()
		CreateRealTimeThread(function()
			OpenSatelliteView()
			SetCampaignSpeed(Game.CampaignTimeFactor, "UI")
		end)
	else
		if not spawn_mode then
			local destSector = gv_Sectors[dest_sector_id]
			spawn_mode = destSector and destSector.conflict and "attack" or "explore"
		end
		CreateGameTimeThread(function()
			LoadSector(dest_sector_id, spawn_mode) --pause wants to yield, but it can't
		end)
	end
end

-- Promote half-way retreating squads into full retreating squads should all their units have been released.
function OnMsg.MercReleased(_, squadId)
	local squad = gv_Squads[squadId]
	if not squad then return end
	
	local squadUnitsLeft = squad.units
	local allRetreating, retreatingTo = true, false
	for i, u in ipairs(squadUnitsLeft) do
		local ud = gv_UnitData[u]
		if not ud.retreat_to_sector then
			allRetreating = false
		elseif not retreatingTo then
			retreatingTo = ud.retreat_to_sector
		end
	end
	if allRetreating then
		local currentSector = squad.CurrentSector
		local underground = currentSector .. "_Underground" == retreatingTo or retreatingTo .. "_Underground" == currentSector
		LeaveSectorExploration(retreatingTo, squadUnitsLeft, underground, true)
	end
end

MapVar("gv_RetreatOrTravelOption", false)

---
--- Checks the visibility of the retreat button based on the currently selected unit and the presence of an exit zone interactable.
---
--- If a unit is selected and is inside an entrance marker, the function checks if there is an exit zone interactable for the corresponding direction. If an exit zone interactable is found and the selected unit can interact with it, the `gv_RetreatOrTravelOption` global variable is set to the exit zone interactable. Otherwise, the `gv_RetreatOrTravelOption` is set to `false`.
---
--- The function is triggered by various events, such as exploration ticks, combat steps, selection changes, and turn starts.
---
--- @function CheckRetreatButtonVisibility
--- @return nil
function CheckRetreatButtonVisibility()
	local selectedUnit = Selection and Selection[1]
	if not selectedUnit or (IsKindOf(selectedUnit, "Unit") and not selectedUnit:CanBeControlled()) then
		gv_RetreatOrTravelOption = false
		ObjModified("gv_RetreatOrTravelOption")
		return
	end

	local markers = MapGetMarkers("Entrance")
	for i, m in ipairs(markers) do
		if m:IsMarkerEnabled() and m:IsInsideArea(selectedUnit) then
			local exitInteractable = MapGetMarkers("ExitZoneInteractable", m.Groups and m.Groups[1])
			exitInteractable = exitInteractable and exitInteractable[1]
			
			if exitInteractable and exitInteractable:GetInteractionCombatAction(selectedUnit) then
				gv_RetreatOrTravelOption = exitInteractable
				ObjModified("gv_RetreatOrTravelOption")
				return
			end
		end
	end
	
	gv_RetreatOrTravelOption = false
	ObjModified("gv_RetreatOrTravelOption")
end

OnMsg.ExplorationTick = CheckRetreatButtonVisibility
OnMsg.CombatGotoStep = CheckRetreatButtonVisibility
OnMsg.SelectedObjChange = CheckRetreatButtonVisibility
OnMsg.SelectionChange = CheckRetreatButtonVisibility
OnMsg.TurnStart = CheckRetreatButtonVisibility
OnMsg.RepositionEnd = CheckRetreatButtonVisibility

---
--- Returns the closest `ExitZoneInteractable` object to the given position or object.
---
--- @param pos_or_obj table|Object The position or object to find the closest `ExitZoneInteractable` to.
--- @return Object|false The closest `ExitZoneInteractable` object, or `false` if none were found.
function GetClosestExitZoneInteractable(pos_or_obj)
	local closestExitZone = false
	MapForEach("map", "ExitZoneInteractable", function(o)
		if not closestExitZone then
			closestExitZone = o
			return
		end
		closestExitZone = closestExitZone and IsCloser(pos_or_obj, o, closestExitZone) and o or closestExitZone
	end)
	
	return closestExitZone
end

if Platform.developer then
local function lCheckMapEntrances(campaign_preset, sector, errors)
	errors = errors or {}

	local sectors = campaign_preset.Sectors or empty_table
	local directions = { }
	for _, dir in ipairs(const.WorldDirections) do
		local neighSectorId = GetNeighborSector(sector.Id, dir, campaign_preset)
		if neighSectorId then
			local sector = table.find_value(sectors, "Id", neighSectorId)
			if sector and sector.Passability ~= "Blocked" then
				directions[#directions + 1] = dir
			end
		end
	end
	
	local blockedTravel = sector.BlockTravel or empty_table
	for i, dir in ipairs(directions) do
		if not blockedTravel[dir] and not next(MapGetMarkers("ExitZoneInteractable", dir)) then
			errors[#errors + 1] = string.format("No ExitZoneInteractable on map '%s' for direction '%s'", GetMapName(), dir)
		end
	end
	
	return errors
end

function OnMsg.SaveMap()
	local campaign = Game and Game.Campaign or rawget(_G, "DefaultCampaign") or "HotDiamonds"
	local campaign_presets = rawget(_G, "CampaignPresets") or empty_table
	local campaign_preset = campaign_presets[campaign]

	local sectors = campaign_preset and campaign_preset.Sectors or empty_table
	
	local sector = false
	for i, s in ipairs(sectors) do
		if s.Map == CurrentMap then
			sector = s
			break
		end
	end
	if not sector or sector.GroundSector then return end
	
	local errors = lCheckMapEntrances(campaign_preset, sector)
	for i, err in ipairs(errors) do
		StoreErrorSource(i, err)
	end
end

---
--- Checks the entrances of all maps in the current campaign.
--- This function is called when the map is saved to ensure that all maps have an ExitZoneInteractable for each passable direction.
--- If any maps are missing an ExitZoneInteractable, an error is stored for that map.
---
--- @param campaign string The current campaign name.
--- @param campaign_presets table The table of campaign presets.
--- @param sectors table The table of sectors in the current campaign.
--- @param maps table The list of map names to check.
--- @param mapToSector table The mapping of map names to their corresponding sectors.
--- @return table The list of errors found during the check.
---
function CheckEntrancesOfAllMaps()
	if not CanYield() then
		CreateRealTimeThread(CheckEntrancesOfAllMaps)
		return
	end

	local campaign = Game and Game.Campaign or rawget(_G, "DefaultCampaign") or "HotDiamonds"
	local campaign_presets = rawget(_G, "CampaignPresets") or empty_table
	local campaign_preset = campaign_presets[campaign]

	local sectors = campaign_preset and campaign_preset.Sectors or empty_table
	local maps = {}
	local mapToSector = {}
	for i, s in ipairs(sectors) do
		if s.Map and not s.GroundSector then
			maps[#maps + 1] = s.Map
			mapToSector[s.Map] = s
		end
	end
	
	local errors = {}
	ForEachMap(maps, function()
		local sector = mapToSector[CurrentMap]
		errors = lCheckMapEntrances(campaign_preset, sector, errors)
	end)

	while IsChangingMap() do Sleep(100) end

	for i, err in ipairs(errors) do
		StoreErrorSource(false, err)
	end
	Inspect(errors)
end
end