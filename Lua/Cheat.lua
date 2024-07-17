if FirstLoad then
	g_CheatsEnabledInC = Platform.cheats
end
Platform.cheats = rawget(_G, "g_CheatsEnabledInC")

---
--- Checks if cheats are enabled.
---
--- @return boolean True if cheats are enabled, false otherwise.
---
function AreCheatsEnabled()
	return Platform.cheats or Platform.trailer or AreModdingToolsActive()
end

function OnMsg.InitSessionCampaignObjects()
	gv_Cheats.Teleport = Platform.developer
	gv_Cheats.WeakDamage = false
	gv_Cheats.StrongDamage = false
	gv_Cheats.GodMode = {}
	gv_Cheats.InfiniteAP = {}
	gv_Cheats.Invulnerability = {}
	gv_Cheats.AutoResolve = false
	gv_Cheats.FreeParts = false
	gv_Cheats.FreeMeds = false
	gv_Cheats.SkillCheck = false
	gv_Cheats.FastActivity = false
	gv_Cheats.FullVisibility = false
	gv_Cheats.CombatUIHidden = false
	gv_Cheats.IWUIHidden = false
	gv_Cheats.ReplayUIHidden = false
	gv_Cheats.OptionalUIHidden = false
	gv_Cheats.BigGuns = false
	gv_Cheats.AlwaysHit = false
	gv_Cheats.AlwaysMiss = false
	gv_Cheats.SignatureNoCD = false
	gv_Cheats.oneHpEnemies = false
	gv_Cheats.ShowSquadsPower = false
	
	for _, side in ipairs(SideDefs) do
		gv_Cheats.GodMode[side.Id] = false
		gv_Cheats.InfiniteAP[side.Id] = false
		gv_Cheats.Invulnerability[side.Id] = false
	end
end

---
--- Checks if a cheat is enabled.
---
--- @param id string The ID of the cheat to check.
--- @param side string (optional) The side to check the cheat for, if the cheat has side-specific values.
--- @return boolean True if the cheat is enabled, false otherwise.
---
function CheatEnabled(id, side)
	if Platform.developer and id == "Teleport" then return true end
	if not gv_Cheats then return false end
	local value = gv_Cheats[id]
	if type(value) == "table" then
		value = (side and value[side]) or false		
	end
	return value
end

local function GetSideUnits(side)
	local idx = table.find(g_Teams, "side", side)
	return idx and g_Teams[idx].units
end

---
--- Enables or disables a cheat by ID and optionally by side.
---
--- @param id string The ID of the cheat to enable or disable.
--- @param state boolean (optional) The new state of the cheat. If not provided, the cheat will be toggled.
--- @param side string (optional) The side to enable or disable the cheat for, if the cheat has side-specific values.
--- @param args table (optional) Additional arguments for the cheat, such as a unit for the "PanicUnit" cheat.
---
function NetSyncEvents.CheatEnable(id, state, side, args)
	local tbl = gv_Cheats
	local key = id
	if type(gv_Cheats[id]) == "table" then
		if not side then
			return
		end
		tbl = gv_Cheats[id]
		key = side
	end
	
	if state == nil then -- toggle
		state = not tbl[key]
	else
		state = not not state -- enforce bool
	end
	tbl[key] = state
	
	if id == "GodMode" then
		local units = GetSideUnits(side)
		for _, unit in ipairs(units) do
			unit:GodMode("god_mode", state)
		end
	elseif id == "InfiniteAP" then
		local units = GetSideUnits(side)
		for _, unit in ipairs(units) do
			unit:GodMode("infinite_ap", state)
		end
	elseif id == "Invulnerability" then
		local units = GetSideUnits(side)
		for _, unit in ipairs(units) do
			unit:GodMode("invulnerable", state)
		end
	elseif id == "FullVisibility" then
		g_VisibilityUpdated = false
		InvalidateVisibility()
	elseif id == "CombatUIHidden" then
		HideCombatUI(tbl.CombatUIHidden)
	elseif id == "IWUIHidden" then
		HideInWorldCombatUI(tbl.IWUIHidden, "cheat")
	elseif id == "ReplayUIHidden" then
		HideReplayUI(tbl.ReplayUIHidden)
	elseif id == "OptionalUIHidden" then
		HideOptionalUI(tbl.OptionalUIHidden)
	elseif id == "PanicUnit" then
		local unit = args
		if IsValid(unit) and IsKindOf(unit, "Unit") then
			unit:AddStatusEffect("Panicked")
		end
	elseif id == "BigGuns" then
		for _, unit in ipairs(g_Units) do
			unit:UpdateOutfit()
		end
	elseif id == "AlwaysHit" and state then
		gv_Cheats.AlwaysMiss = false
	elseif id == "AlwaysMiss" and state then
		gv_Cheats.AlwaysHit = false
	elseif id == "Teleport" then
		RevealAllSectors()
	elseif id == "OneHpEnemies" then
		for _, unit in ipairs(g_Units) do
			if (unit.team.side == "enemy1" or unit.team.side == "enemy2") and not unit:IsDead() then
				unit.HitPoints = state and 1 or unit.MaxHitPoints
			end
		end
		UpdateAllBadgesAndModes()
	end
end

---
--- Teleports the selected unit or squad to the cursor position.
---
--- If a satellite squad is selected, it will teleport the squad to the sector under the cursor.
--- If no squad is selected, it will teleport the selected unit(s) to the cursor position.
--- If no unit or squad is selected, it will print an error message.
---
--- @param none
--- @return none
---
function CheatTeleportToCursor()
	local sat = GetSatelliteDialog()
	if sat then
		local sel_sq = sat.selected_squad
		if not sel_sq then
			print("Teleport: There is no active squad")
		else
			local sectorWin = g_SatelliteUI and g_SatelliteUI:GetSectorOnPos("mouse")
			if not sectorWin then
				print("Teleport: There is no satellite sector under cursor")
			else
				NetSyncEvent("CheatSatelliteTeleportSquad", sel_sq.UniqueId, sectorWin.context.Id)
			end
		end
		return
	end
	if not SelectedObj and #Selection == 0 then
		print("Teleport: There is no active unit")
		return
	end
	local pos = GetCursorPassSlab()
	if not pos then
		print("Teleport: There is no proper teleport position at " .. tostring(pos))
		return
	end
	local function teleport(unit, pos)
		NetSyncEvent("StartCombatAction", netUniqueId, "Teleport", unit, g_Combat and 0 or false, pos) -- bypass some checks
	end
	if #Selection > 1 then
		local units = Selection
		local dest = GetUnitsDestinations(units, pos)
		for i, u in ipairs(units) do
			if dest[i] then
				teleport(u, point(point_unpack(dest[i])))
			end
		end
	elseif IsKindOf(SelectedObj, "Unit") then
		teleport(SelectedObj, pos)
	end
end

---
--- Cheats to level up a unit to a specified maximum level.
---
--- @param unit Unit The unit to level up. If not provided, the selected unit will be used.
--- @param maxLevel number The maximum level to level up the unit to. If not provided, the unit will be leveled up to the next level.
---
--- @return none
---
function NetSyncEvents.CheatLevelUp(unit, maxLevel)
	if not unit then unit = SelectedObj end
	if not unit then return end
	local cur_level = unit:GetLevel()
	local nXPTable = #XPTable
	local level = maxLevel and nXPTable or Min(cur_level + 1, nXPTable)
	local next_level_exp = GetXPTable(level)
	local xpDiff = next_level_exp - unit.Experience
	ReceiveStatGainingPoints(unit, xpDiff)
	unit.Experience = next_level_exp
	local newLevel = unit:GetLevel()
	if newLevel > cur_level then
		unit.perkPoints = unit.perkPoints + (newLevel - cur_level)
		TutorialHintsState.GainLevel = true
	end
	
	unit:SyncWithSession("map")
	ObjModified(unit)
	InventoryUIRespawn()
	PerksUIRespawn()
	
	CombatLog("important", T{134899495484, "<DisplayName> has reached <em>level <level></em>", SubContext(unit, { level = unit:GetLevel() })})
	Msg("UnitLeveledUp", unit)
end

---
--- Restores the energy of all mercenary units by removing any negative energy effects.
---
--- @return none
---
function NetSyncEvents.RestoreEnergy()
	for _, unit in sorted_pairs(gv_UnitData) do
		if IsMerc(unit) then
			for _, neg_energy_effect in ipairs(RedEnergyEffects) do
				unit:RemoveStatusEffect(neg_energy_effect)
				ObjModified(unit)
			end
		end
	end
end

---
--- Reveals all traps for the specified team.
---
--- @param side string The side of the team whose traps should be revealed.
---
--- @return none
---
function NetSyncEvents.CheatRevealTraps(side)
	local idx = table.find(g_Teams or empty_table, "side", side)
	if not idx then return end
	
	CheatRevealTraps(g_Teams[idx])
end

---
--- Synchronizes the CheatAddAmmo function over the network.
---
--- @param unit UnitInventory The unit to add ammo to.
---
--- @return none
---
function NetSyncEvents.CheatAddAmmo(unit)
	CheatAddAmmo(unit)
end

---
--- Adds ammunition to all units in the specified squad.
---
--- @param in_unit UnitInventory The unit to add ammo to. If not provided, the currently selected unit will be used.
---
--- @return none
---
function CheatAddAmmo(in_unit)
	if not in_unit then in_unit = SelectedObj end
	if not in_unit or not IsKindOf(in_unit, "UnitInventory") then return end
	
	local squadId = in_unit.Squad
	local unitsInSquad = gv_Squads[squadId].units
	
	for key, item in sorted_pairs(InventoryItemDefs) do
		if item.object_class=="Ammo" or item.object_class=="Ordnance" then
			AddItemToSquadBag(squadId, item.id, item:GetProperty("MaxStacks"))
		end
	end
	
	local unit
	local tempAmmo
	
	local function reload_weapon(weapon)
		if weapon.ammo then
			weapon.ammo.Amount = weapon.MagazineSize
		else			
			tempAmmo = PlaceInventoryItem(GetAmmosWithCaliber(weapon.Caliber, "sort")[1].id)
			tempAmmo.Amount = tempAmmo.MaxStacks
			weapon:Reload(tempAmmo, "suspend_fx" and true)
			DoneObject(tempAmmo)
		end
		ObjModified(weapon)
	end
	
	for i = 1, #unitsInSquad do
		unit = gv_UnitData[unitsInSquad[i]]
		unit:ForEachItem("Firearm", function(weapon)
			reload_weapon(weapon)
			for slot, sub in sorted_pairs(weapon.subweapons) do
				reload_weapon(sub)
			end
		end)
		InventoryUpdate(unit)
	end
end

---
--- Synchronizes the CheatAddMercStats function over the network.
---
--- This function is called when the CheatAddMercStats event is received over the network.
--- It calls the CheatAddMercStats function to apply the cheat to the currently selected unit.
---
--- @function NetSyncEvents.CheatAddMercStats
--- @return none
function NetSyncEvents.CheatAddMercStats()
	CheatAddMercStats()
end

---
--- Applies a stat boost cheat to the currently selected unit.
---
--- This function is called when the CheatAddMercStats event is received over the network.
--- It applies a 10-point boost to each of the unit's stats.
---
--- @param unit UnitInventory The currently selected unit to apply the cheat to.
--- @return none
function CheatAddMercStats()
	local unit = SelectedObj
	if not unit or not IsMerc(unit) then return end
	
	for _, stat in ipairs(GetUnitStatsCombo()) do
		local modId = string.format("StatBoost-%s-%s-%d", stat, unit.session_id, GetPreciseTicks())
		GainStat(unit, stat, 10, modId)
	end
end

---
--- Hides or shows the in-game combat UI elements.
---
--- This function is responsible for hiding or showing various UI elements related to the in-game combat UI, such as the unit control panel, targeting blackboard, and combat log. It also resets the effects target position when hiding the UI.
---
--- @param hide boolean Whether to hide the combat UI elements or show them.
--- @return none
function HideCombatUI(hide)
	local dlg = GetInGameInterfaceModeDlg()
	if dlg and dlg:IsKindOf("IModeCommonUnitControl") then
		dlg.idLeft:SetVisible(not hide)
		dlg.idLeftTop:SetVisible(not hide)
		dlg.idBottom:SetVisible(not hide)
		dlg.idRight:SetVisible(not hide)
		dlg.idMenu:SetVisible(not hide)
		
		local blackboard = dlg.targeting_blackboard
		if blackboard and blackboard.movement_avatar and blackboard.movement_avatar.rollover then
			if hide then
				blackboard.movement_avatar_visible = blackboard.movement_avatar:GetEnumFlags(const.efVisible) ~= 0
				blackboard.movement_avatar:SetVisible(false)
			elseif blackboard.movement_avatar_visible then
				blackboard.movement_avatar_visible = nil
				blackboard.movement_avatar:SetVisible(true)
			end
			blackboard.movement_avatar.rollover:SetTransparency(hide and 255 or 0)
		end
		if blackboard and blackboard.fx_path then
			for i, mesh in ipairs(blackboard.fx_path.steps_objects) do
				mesh:SetVisible(not hide)
			end
		end
		
		dlg.effects_target_pos_last = false -- Reset fx
	end
	local badge_dlg = GetDialog("BadgeHolderDialog")
	if badge_dlg then
		badge_dlg:SetVisible(not hide)
	end
	if hide then
		HideCombatLog()
	end
	local combatLogFader = GetDialog("CombatLogMessageFader")
	if combatLogFader then
		combatLogFader:SetVisible(not hide)
	end
	
	local tutorialDialog = GetDialog("TutorialPopupDialog")
	if tutorialDialog then
		tutorialDialog:SetVisible(not hide)
	end
end

MapVar("InWorldCombatUIHiddenCodeRenderables", false)

if FirstLoad then
	HiddenInWorldCombatUIReasons = {}
end

---
--- Hides or shows the in-world combat UI based on the provided `hide` and `reason` parameters.
---
--- If `hide` is true, the function will hide the in-world combat UI if it is not already hidden. The `reason` parameter is used to track the reasons for hiding the UI.
---
--- If `hide` is false, the function will show the in-world combat UI if all the reasons for hiding it have been cleared.
---
--- @param hide boolean Whether to hide or show the in-world combat UI.
--- @param reason string The reason for hiding the in-world combat UI.
function HideInWorldCombatUI(hide, reason)
	if hide then
		if not next(HiddenInWorldCombatUIReasons) then
			DoHideInWorldCombatUI(true)
		end
		HiddenInWorldCombatUIReasons[reason] = true
	else
		HiddenInWorldCombatUIReasons[reason] = nil
		if not next(HiddenInWorldCombatUIReasons) then
			DoHideInWorldCombatUI(false)
		end
	end
end

---
--- Hides or shows the in-world combat UI based on the provided `hide` parameter.
---
--- If `hide` is true, the function will hide the in-world combat UI if it is not already hidden. It will store the hidden CodeRenderableObjects in a table called `InWorldCombatUIHiddenCodeRenderables`.
---
--- If `hide` is false, the function will show the in-world combat UI by restoring the visibility of the previously hidden CodeRenderableObjects.
---
--- The function also clears the object marking on any Interactable objects in the current map.
---
--- @param hide boolean Whether to hide or show the in-world combat UI.
function DoHideInWorldCombatUI(hide)
	local dlg = GetInGameInterfaceModeDlg()
	if dlg and dlg:IsKindOf("IModeCommonUnitControl") then
		dlg.effects_target_pos_last = false -- Reset fx
	end

	if hide then 
		InWorldCombatUIHiddenCodeRenderables = setmetatable({}, weak_values_meta)
		MapForEach("map", "CodeRenderableObject", function(o)
			if not o:IsKindOfClasses("Wire", "BlackPlane") then 
				if not (o:GetEnumFlags(const.efVisible) == 0) then 
					table.insert(InWorldCombatUIHiddenCodeRenderables, o)
					o:ClearEnumFlags(const.efVisible)
				end
			end
		end)
	else
		for _, o in ipairs(InWorldCombatUIHiddenCodeRenderables) do
			if IsValid(o) then
				o:SetEnumFlags(const.efVisible)
			end
		end
	end
	
	if GetMap() ~= "" then
		MapForEach("map", "Interactable", function(o)
			if not o.until_interacted_with_highlight then return end
			
			local visuals = o.visuals_cache
			for i, v in ipairs(visuals) do
				v:SetObjectMarking(-1)
				v:ClearHierarchyGameFlags(const.gofObjectMarking)
			end
		end)
	end
end

---
--- Hides or shows the replay UI based on the provided `hide` parameter.
---
--- If `hide` is true, the function will hide the replay UI. If `hide` is false, the function will show the replay UI.
---
--- @param hide boolean Whether to hide or show the replay UI.
function HideReplayUI(hide)
	ObjModified("replay_ui")
end

---
--- Hides or shows the optional UI.
---
--- @param hide boolean Whether to hide or show the optional UI.
function HideOptionalUI(hide)
	ObjModified("combat_tasks")
end

---
--- Checks if the mod with the ID "KAJY0RB" is loaded.
---
--- @return boolean true if the mod is loaded, false otherwise
function CthVisible()
	return table.find(ModsLoaded, "id", "KAJY0RB")
end

---
--- Resets the perk points of the given unit.
---
--- This function iterates through the unit's status effects, and for each Perk effect that is a level up, it removes the status effect and adds one perk point back to the unit.
---
--- @param unit StatusEffectObject The unit whose perk points should be reset.
---
function NetSyncEvents.CheatRespecPerkPoints(unit)
	for _, effect in ipairs(unit.StatusEffects) do
		if IsKindOf(effect, "Perk") and effect:IsLevelUp() then
			unit:RemoveStatusEffect(effect.class)
			unit.perkPoints = unit.perkPoints + 1
		end
	end
	ObjModified(unit)
end

---
--- Resets the perk points of the given unit.
---
--- This function iterates through the unit's status effects, and for each Perk effect that is a level up, it removes the status effect and adds one perk point back to the unit.
---
--- @param unit StatusEffectObject The unit whose perk points should be reset.
---
function CheatRespecPerkPoints(unit)
	CheatLog("RespecPerkPoints")
	if not IsKindOf(unit, "StatusEffectObject") then return end
	NetSyncEvent("CheatRespecPerkPoints", unit)
end

---
--- Boosts the stats of the given unit to the specified amount.
---
--- This function sets the following stats of the given unit to the specified amount:
--- - Health
--- - Agility
--- - Dexterity
--- - Strength
--- - Wisdom
--- - Leadership
--- - Marksmanship
--- - Mechanical
--- - Explosives
--- - Medical
---
--- @param unit StatusEffectObject The unit whose stats should be boosted. If not provided, the currently selected unit will be used.
--- @param amount number The amount to set the unit's stats to. If not provided, 90 will be used.
---
function CheatBoostUnitStats(unit, amount)
	unit = unit or SelectedObj
	amount = amount or 90
	unit.Health = amount
	unit.Agility = amount
	unit.Dexterity = amount
	unit.Strength = amount
	unit.Wisdom = amount
	unit.Leadership = amount
	unit.Marksmanship = amount
	unit.Mechanical = amount
	unit.Explosives = amount
	unit.Medical = amount
end

---
--- Adds a new merc to the squad.
---
--- This function creates a new unit data for the given merc ID if it doesn't exist, adds the merc to the squad, and notifies the player that a new merc has been hired.
---
--- @param id string The ID of the merc to add to the squad.
---
function NetSyncEvents.CheatAddMerc(id)
	local ud = gv_UnitData[id]
	if not ud then -- Non-merc units will not have unit data.
		ud = CreateUnitData(id, id, InteractionRand(nil, "Satellite"))
	end
	
	UIAddMercToSquad(id)
	HiredMercArrived(gv_UnitData[id])
	Msg("MercHired", id, 0, 14)
end

---
--- Logs a cheat event with optional parameters.
---
--- This function logs a cheat event to the debug console and sends a network gossip message with the cheat name and optional parameters.
---
--- @param cheat string The name of the cheat that was executed.
--- @param param any The first optional parameter to log with the cheat.
--- @param param2 any The second optional parameter to log with the cheat.
---
function CheatLog(cheat, param, param2)
	if param2 then
		DebugPrint("Cheat", cheat, param, param2)
		NetGossip("Cheat", cheat, param, param2, GetCurrentPlaytime(), Game and Game.CampaignTime)
	elseif param then
		DebugPrint("Cheat", cheat, param)
		NetGossip("Cheat", cheat, param, GetCurrentPlaytime(), Game and Game.CampaignTime)
	else
		DebugPrint("Cheat", cheat)
		NetGossip("Cheat", cheat, GetCurrentPlaytime(), Game and Game.CampaignTime)
	end
end

---
--- Selects a unit under the mouse cursor.
---
--- This function attempts to select a unit based on the mouse cursor position. It first checks if the mouse is over a combat badge, and if so, selects the unit associated with that badge. If not, it checks if the mouse is over a status effect icon, and if so, selects the unit associated with that icon. If neither of those conditions are met, it selects the first unit found in the voxel at the cursor position.
---
--- @param none
--- @return none
---
function CheatSelectAnyUnit()
	CheatLog("SelectAnyUnit")
	
	local obj
	local mouseTarget = terminal.desktop.last_mouse_target
	if mouseTarget.parent and IsKindOf(mouseTarget.parent, "CombatBadge") then
		obj = mouseTarget.parent.unit
	elseif IsKindOf(mouseTarget, "StatusEffectIcon") then
		obj = mouseTarget:ResolveId("node"):ResolveId("node").unit
	end
	obj = obj or SelectionMouseObj()
	if not IsKindOf(obj, "Unit") then
		obj = MapGetFirst(GetVoxelBBox(GetCursorPos()), "Unit")
	end
	SelectObj(obj)
end

---
--- Clears the current selection of units.
---
--- This function clears the current selection of units, effectively deselecting any units that were previously selected.
---
--- @param none
--- @return none
---
function CheatClearSelection()
	CheatLog("ClearSelection")
	SelectObj()
end

---
--- Grants the selected unit additional action points.
---
--- This function grants the currently selected unit a specified amount of additional action points. It first checks if there is a combat in progress and if a unit is currently selected. If those conditions are met, it sends a network event to synchronize the action point grant with other clients.
---
--- @param ap number The amount of additional action points to grant to the selected unit.
--- @return none
---
function CheatGrantSelectedObjAP(ap)
	CheatLog("GrantSelectedObjAP", ap)
	if not g_Combat or not SelectedObj then return end
	NetSyncEvent("CheatGrantObjAP", SelectedObj, ap)
end

---
--- Synchronizes the granting of additional action points to a unit across the network.
---
--- This function is called when a cheat event is triggered to grant additional action points to a selected unit. It interrupts any prepared attack the unit may have, grants the specified amount of additional action points, and recalculates the unit's UI actions.
---
--- @param unit Unit The unit to grant the additional action points to.
--- @param ap number The amount of additional action points to grant.
--- @return none
---
function NetSyncEvents.CheatGrantObjAP(unit, ap)
	unit:InterruptPreparedAttack() -- designers made me do it
	unit:GainAP(ap * const.Scale.AP)
	unit:RecalcUIActions()
end

---
--- Removes the specified amount of action points from the currently selected unit.
---
--- This function removes the specified amount of action points from the currently selected unit. It first checks if there is a combat in progress and if a unit is currently selected. If those conditions are met, it consumes the specified amount of action points from the selected unit.
---
--- @param ap number The amount of action points to remove from the selected unit.
--- @return none
---
function CheatRemoveSelectedObjAP(ap)
	CheatLog("RemoveSelectedObjAP", ap)
	if not g_Combat or not SelectedObj then return end
	
	SelectedObj:ConsumeAP(ap * const.Scale.AP)
end

---
--- Starts a debug combat scenario with two teams of mercenaries.
---
--- This function is used for debugging purposes. It creates a new combat scenario with two teams of mercenaries, one controlled by the player and one controlled by the AI. The teams are defined using the `TestTeamDef` class, which specifies the mercenaries in each team, their team color, and whether the team is controlled by the AI.
---
--- @param none
--- @return none
---
function CheatDbgStartCombat()
	CheatLog("DbgStartCombat", GetMapName())
	DbgStartCombat(GetMapName(), {
		TestTeamDef:new{
			mercs = { "Barry", "Ivan", "Buns" },
			team_color = RGB(0, 0, 200),
			ai_control = false,
		},
		TestTeamDef:new{
			mercs = { "Grizzly", "Grunty", "Gus" },
			team_color = RGB(200, 0, 0),
			ai_control = true,
			enemy = true
		},
	})
end

---
--- Adds a new weapon to the player's inventory.
---
--- This function is used to add a new weapon to the player's inventory. It takes a context table as an argument, which contains information about the weapon to be added, such as its ID. The function then calls the `UIPlaceInInventory` function to add the weapon to the player's inventory.
---
--- @param context table The context table containing information about the weapon to be added.
--- @return none
---
function CheatAddWeapon(context)
	CheatLog("AddWeapon", context.id)
	UIPlaceInInventory(nil, context)
end

---
--- Enables the teleport cheat functionality.
---
--- This function is used to enable the teleport cheat functionality. It logs the action to the cheat log and then synchronizes the cheat enable event across the network.
---
--- @param none
--- @return none
---
function CheatEnableTeleport()
	CheatLog("EnableTeleport")
	NetSyncEvent("CheatEnable", "Teleport", true)
end

---
--- Synchronizes a cheat enable event across the network.
---
--- This function is used to synchronize a cheat enable event across the network. It logs the cheat name to the cheat log and then calls the `NetSyncEvent` function to broadcast the cheat enable event to other clients.
---
--- @param cheat string The name of the cheat to enable.
--- @return none
---
function NetSyncCheatEnableIG(cheat)
	CheatLog(cheat)
	NetSyncEvent("CheatEnable", cheat)
end

---
--- Levels up the selected object to the specified maximum level.
---
--- This function is used to level up the selected object to the specified maximum level. It first checks if the selected object is a unit or unit data, and if so, it retrieves the unit from the context of the fullscreen game dialog. It then synchronizes the level up event across the network using the `NetSyncEvent` function.
---
--- @param max_level number The maximum level to level up the selected object to.
--- @return none
---
function CheatSelectedObjLevelUp(max_level)
	CheatLog("SelectedObjLevelUp", max_level)
	if IsKindOfClasses(SelectedObj, "Unit", "UnitData") then
		local u = SelectedObj
		local dlg = GetDialog("FullscreenGameDialogs")
		if dlg then
			u = dlg:GetContext().unit
		end
		NetSyncEvent("CheatLevelUp", u, max_level)
	end
end

---
--- Restores the energy of the player.
---
--- This function is used to restore the energy of the player. It logs the action to the cheat log and then synchronizes the energy restore event across the network.
---
--- @param none
--- @return none
---
function CheatRestoreEnergy()
	CheatLog("RestoreEnergy")
	NetSyncEvent("RestoreEnergy")
end

---
--- Reveals all traps on the map for the current player's team.
---
--- This function is used to reveal all traps on the map for the current player's team. It logs the action to the cheat log and then synchronizes the trap reveal event across the network.
---
--- @param none
--- @return none
---
function CheatRevealTrapsIG()
	CheatLog("RevealTraps")
	local pov_team = GetPoVTeam()
	if pov_team then
		NetSyncEvent("CheatRevealTraps", pov_team.side)
	end				
end

---
--- Synchronizes a cheat event across the network.
---
--- This function is used to log a cheat event and then synchronize it across the network using the `NetSyncEvent` function.
---
--- @param cheat string The name of the cheat event to log and synchronize.
--- @param param any The parameter(s) to pass to the cheat event.
--- @return none
---
function NetSyncCheatIG(cheat, param)
	CheatLog(cheat, param)
	NetSyncEvent(cheat, param)
end

---
--- Sets the loyalty of a city.
---
--- This function is used to set the loyalty of a city. It logs the action to the cheat log and then synchronizes the city loyalty change event across the network.
---
--- @param city string The name of the city to modify the loyalty for.
--- @param loyalty number The new loyalty value to set for the city.
--- @return none
---
function CheatSetLoyalty(city, loyalty)
	CheatLog("SetLoyalty", city, loyalty)
	NetSyncEvent("CheatCityModifyLoyalty", city, loyalty)
end

---
--- Toggles the visibility of tree roofs.
---
--- This function is used to toggle the visibility of tree roofs in the game. It logs the action to the cheat log and then toggles the visibility of the "ActionShortcut" visibility system.
---
--- @param none
--- @return none
---
function CheatToggleHideTreeRoofs()
	CheatLog("ToggleHideTreeRoofs")
	ToggleVisibilitySystems("ActionShortcut")
end

---
--- Adds a mercenary to the player's squad.
---
--- This function is used to add a mercenary to the player's squad. If the player does not have any squads, it will start an exploration to add the mercenary. Otherwise, it will synchronize the mercenary addition event across the network.
---
--- @param merc_id string The ID of the mercenary to add to the squad.
--- @return none
---
function CheatAddMercIG(merc_id)
	CheatLog("AddMerc")
	if not next(GetPlayerMercSquads()) then
		DbgStartExploration(nil, {merc_id})
	else
		NetSyncEvent("CheatAddMerc", merc_id)
	end
end

---
--- Removes a mercenary from the player's squad.
---
--- This function is used to remove a mercenary from the player's squad. If the player is not in combat, it will remove the mercenary from the squad. Otherwise, it will display a warning message that the mercenary cannot be removed while in combat.
---
--- @param merc string The ID of the mercenary to remove from the squad.
--- @return none
---
function CheatRemoveMercIG(merc)
	CheatLog("RemoveMerc")
	if not g_Combat then
		UIRemoveMercFromSquad(merc)
		ObjModified("hud_squads")
	else
		CreateMessageBox(self.desktop, T({"Warning."}), T({"You must be out of combat to remove a mercenary."}), T({"OK"})) 
	end
end

---
--- Sets the hire status of a mercenary.
---
--- This function is used to set the hire status of a mercenary. It updates the hire status in the `gv_UnitData` table and the corresponding `g_Units` object. If the status is set to "Dead", the `HiredUntil` field is set to the current campaign time. If the status is set to "Hired", the mercenary is added to the squad and the `HiredMercArrived` function is called. If the status is set to anything else, the `HiredUntil` field is set to `false`.
---
--- @param merc_id string The ID of the mercenary to set the hire status for.
--- @param status string The new hire status for the mercenary.
--- @return none
---
function CheatSetMercHireStatus(merc_id, status)
	CheatLog("SetMercHireStatus", merc_id, status)
	local merc = gv_UnitData[merc_id]
	merc.HireStatus = status	
	if status == "Dead" then
		merc.HiredUntil = Game.CampaignTime
	elseif status == "Hired" then
		UIAddMercToSquad(merc_id)
		HiredMercArrived(merc, 14)
	else
		merc.HiredUntil = false
	end
	
	local mercUnit = g_Units[merc_id]
	if mercUnit then 
		mercUnit.HireStatus = status
		mercUnit.HiredUntil = merc.HiredUntil
	end
	print("Set", merc_id, "to", status)
end

---
--- Sets the hire status of a mercenary and rehires them.
---
--- This function is used to set the hire status of a mercenary to "Hired" and add them to the player's squad. It updates the hire status, hired until date, and messenger online status in the `gv_UnitData` table and the corresponding `g_Units` object. The mercenary is then added to the squad and the `HiredMercArrived` function is called.
---
--- @param merc_id string The ID of the mercenary to set the hire status for.
--- @param status string The new hire status for the mercenary. This should always be "Hired" for this function.
--- @return none
---
function CheatSetMercHireStatusWithRehire(merc_id, status)
	CheatLog("SetMercHireStatusWithRehire", merc_id, status)
	local merc = gv_UnitData[merc_id]
	UIAddMercToSquad(merc_id)
	HiredMercArrived(merc, 1)
	merc.HireStatus = "Hired"
	merc.MessengerOnline = true
	merc.HiredUntil = Game.CampaignTime + const.Scale.day
	local mercUnit = g_Units[merc_id]
	if mercUnit then 
		mercUnit.HireStatus = "Hired"
		mercUnit.MessengerOnline = true
		mercUnit.HiredUntil = Game.CampaignTime + const.Scale.day
	end
	print("Set", merc_id, "to", status)
end

--- Toggles the point of view (POV) team for a given cheat.
---
--- This function is used to enable a cheat for the current point of view (POV) team. It first retrieves the current POV team using the `GetPoVTeam()` function. If a POV team is found, it then sends a network sync event to enable the specified cheat for that team's side.
---
--- @param cheat string The name of the cheat to enable.
--- @return none
function CheatPoVTeam(cheat)
	CheatLog("PoVTeam", cheat)
	local pov_team = GetPoVTeam()
	if pov_team then
		NetSyncEvent("CheatEnable", cheat, nil, pov_team.side)
	end
end

---
--- Heals all mercenaries on the player's team.
---
--- This function is used to heal all mercenaries that are on the player's team. It iterates through all units in the `g_Units` table, and for each unit that is on the player's team, it checks if the unit is dead. If the unit is dead, it attempts to revive the unit by adding them back to their old squad. If the unit is not dead, it sends a network sync event to heal the unit.
---
--- @return none
---
function CheatHealAllMercs()
	CheatLog("HealAllMercs")
	UIHealAllMercs()
end

---
--- Heals all mercenaries on the player's team.
---
--- This function is used to heal all mercenaries that are on the player's team. It iterates through all units in the `g_Units` table, and for each unit that is on the player's team, it checks if the unit is dead. If the unit is dead, it attempts to revive the unit by adding them back to their old squad. If the unit is not dead, it sends a network sync event to heal the unit.
---
--- @return none
---
function UIHealAllMercs()
	for _, u in ipairs(g_Units) do
		if u.team and u.team.player_team then
			local dead = u:IsDead()
			if dead then
				UIAddMercToSquad(u.session_id, u.OldSquad) -- we want to try reviving units in their old squad, if it is still valid
			else
				NetSyncEvent("HealMerc", u.session_id)
			end
		end
	end
end

---
--- Gets the camera's look-at terrain position.
---
--- This function retrieves the camera's look-at position and sets the terrain Z-coordinate for that position.
---
--- @return table The camera's look-at terrain position.
---
function GetCameraLookatTerrainPos()
	local _, lookat = GetCamera()
	return lookat:SetTerrainZ()
end

local function checkSquad(squad)
	if squad then
		local check_sector = gv_SatelliteView or squad.CurrentSector == gv_CurrentSectorId
		if check_sector and squad.Side == "player1" and #(squad.units or "") < const.Satellite.MercSquadMaxPeople then
			return squad
		end
	end
end

-- Cheat
local function getSquadForNewMerc()
	local satellite = GetSatelliteDialog()
	local squad = checkSquad(satellite and satellite:HasMember("selected_squad") and satellite.selected_squad) -- selected squad in satellite
	squad = squad or checkSquad(gv_Squads[g_CurrentSquad])
	if not squad then -- if no squad was found, choose first non-full player squad
		 for _, s in ipairs(GetPlayerMercSquads()) do
			if checkSquad(s) then
				squad = s
				break
			end
		 end
	end
	return squad
end

---
--- Gets a list of available mercenaries by name.
---
--- This function retrieves a list of all available mercenaries, excluding those that are currently assigned to a squad. The list is sorted alphabetically by the mercenary's name.
---
--- @param show_all boolean (optional) If true, the function will return all mercenaries, including those that are currently assigned to a squad.
--- @return table A table of available mercenaries, where each entry is a table with two elements: the mercenary's name (string) and the mercenary's data (table).
---
function GetAvailableMercsByName(show_all)
	local available = {}
	local current_merc_ids = {}
	for _, s in ipairs(g_SquadsArray) do
		for _, merc_id in ipairs(s.units or empty_table) do
			current_merc_ids[merc_id] = true
		end
	end
	for k, v in pairs(UnitDataDefs) do
		if IsMerc(v) and (not current_merc_ids[k] or show_all) and v.Nick then
			available[#available + 1] = {[1] = _InternalTranslate(v.Nick), [2] = v}
		end
	end
	table.sort(available, function(a, b) return a[1] < b[1] end)
	return available
end

---
--- Gets a list of available mercenaries grouped by the first letter of their name.
---
--- This function retrieves a list of all available mercenaries, excluding those that are currently assigned to a squad. The mercenaries are grouped by the first letter of their name, with each group containing a list of mercenary data.
---
--- @param groups_count number (optional) The number of groups to create. Defaults to 4.
--- @param show_all boolean (optional) If true, the function will return all mercenaries, including those that are currently assigned to a squad.
--- @param justNames boolean (optional) If true, the function will return a list of mercenary IDs instead of the full mercenary data.
--- @return table A table of mercenary groups, where each group is a table with the following fields:
---   - start_char: the first character of the names in this group
---   - end_char: the last character of the names in this group
---   - display_name: a formatted name for the group
---   - [1..n]: the mercenary data for each mercenary in the group
---
function GetGroupedMercsForCheats(groups_count, show_all, justNames)
	groups_count = groups_count or 4
	local mercs = GetAvailableMercsByName(show_all)
	
	if not next(mercs) then return end
	
	local per_group = Max(#mercs / groups_count, 1)
	local groups = {[1] = {start_char = string.sub(mercs[1][1], 1, 1)}}
	local idx = 1
	
	if justNames then
		local mercsList = {}
		for i, m in ipairs(mercs) do
			if not Presets.UnitDataCompositeDef.IMP[m[2].id] then
				table.insert(mercsList, m[2].id)
			end
		end
		return mercsList
	end
	
	for i, m in ipairs(mercs) do
		local first_char = string.sub(m[1], 1, 1)
		local prev_first_char = mercs[i-1] and string.sub(mercs[i-1][1], 1, 1)
		local try_less_per_group = idx % 2 == 0 and per_group - #groups[idx] < 4
		if idx < groups_count and (#groups[idx] >= per_group or try_less_per_group) and first_char ~= prev_first_char then
			groups[idx].end_char = prev_first_char
			idx = idx + 1
			groups[idx] = {start_char = first_char}
		end
		table.insert(groups[idx], m[2])
	end
	groups[idx].end_char = string.sub(mercs[#mercs][1], 1, 1)
	for _, group in ipairs(groups) do
		group.display_name = Untranslated("<u(start_char)> .. <u(end_char)>", group)
	end
	
	groups[#groups + 1] = { display_name = Untranslated("Beasts"), UnitDataDefs.Beast_Crocodile, UnitDataDefs.Beast_Hyena, UnitDataDefs.Schliemann }
	
	return groups
end

-- Cheats

local function GetMercSquad(merc_id, squad_id)
	local squad = squad_id and checkSquad(gv_Squads[squad_id]) or getSquadForNewMerc()
	if type(merc_id)~= "string" then
		merc_id = merc_id.selected_object and merc_id.selected_object.id
	end
	if not merc_id then
		assert(false, "Wrong merc param passed to function")
		return
	end
	
	return merc_id, squad
end

---
--- Adds a merc to a squad.
---
--- @param merc_id string|table The ID of the merc to add, or a table containing the merc's `selected_object` field.
--- @param squad_id string|nil The ID of the squad to add the merc to. If not provided, a new squad will be created.
---
function UIAddMercToSquad(merc_id, squad_id)
	local merc_id, squad = GetMercSquad(merc_id, squad_id)
	if merc_id then
		NetSyncEvent("AddMercToSquad", merc_id, squad and squad.UniqueId, GetCameraLookatTerrainPos())
	end
end

---
--- Removes a merc from a squad.
---
--- @param merc table The merc to remove from the squad.
---
function UIRemoveMercFromSquad(merc)
	if merc then
		NetSyncEvent("RemoveMercFromSquad", merc.session_id)
	end
end

---
--- Quickly tests a unit by adding it to a new squad and entering a test combat sector.
---
--- @param merc_id string|table The ID of the merc to test, or a table containing the merc's `selected_object` field.
--- @param squad_id string|nil The ID of the squad to add the merc to. If not provided, a new squad will be created.
---
function UIQuickTestUnit(merc_id, squad_id)
	if type(merc_id)~= "string" then
		merc_id = merc_id.selected_object and merc_id.selected_object.id
	end
	if merc_id then
		for _, squad in pairs(gv_Squads) do
			RemoveSquad(squad)
		end
		LocalAddMercToSquad(merc_id, nil, GetCameraLookatTerrainPos())
		TestCombatEnterSector(Presets.TestCombat.Test["Test_SingleMerc"])
	end
end

---
--- Adds a merc to a squad.
---
--- @param merc_id string|table The ID of the merc to add, or a table containing the merc's `selected_object` field.
--- @param squad_id string|nil The ID of the squad to add the merc to. If not provided, a new squad will be created.
--- @param spawn_pos table The position to spawn the merc at.
--- @param hp number The hit points to set the merc to.
---
function LocalAddMercToSquad(merc_id, squad_id, spawn_pos, hp)
	local squad = squad_id and gv_Squads[squad_id]
	if not squad then
		squad_id = CreateNewSatelliteSquad({Side = "player1", CurrentSector = gv_CurrentSectorId, Name = SquadName:GetNewSquadName("player1")}, {})
		squad = gv_Squads[squad_id]
	end
	
	local unit_data = gv_UnitData[merc_id]
	local hire_days = not (unit_data and unit_data.HiredUntil) and 14 -- do not hire for more days if the merc was already hired
	AddUnitsToSquad(squad, {merc_id}, hire_days, InteractionRand(nil, "Satellite"))
	
	-- deal with dead mercs
	local unit = g_Units[merc_id]
	if not unit then
		local unit_data = gv_UnitData[merc_id]
		if unit_data and unit_data.HitPoints == 0 then
			ReviveUnitData(unit_data, hp)
		end
		unit = SpawnUnit(merc_id, merc_id, spawn_pos)
		unit.already_spawned_on_map = true
	else
		local dead = unit:IsDead()
		if dead then
			local unit_data = gv_UnitData[merc_id]
			ReviveUnitData(unit_data, hp)
			unit:SyncWithSession("session")
			ReviveUnit(unit, hp)
		end
	end
	
	-- add unit to team
	unit:SetSide(squad.Side)
	ObjModified(gv_Squads)
	ObjModified("hud_squads")
end

---
--- Synchronizes adding a merc to a squad across the network.
---
--- @param merc_id string The ID of the merc to add.
--- @param squad_id string|nil The ID of the squad to add the merc to. If not provided, a new squad will be created.
--- @param spawn_pos table The position to spawn the merc at.
---
function NetSyncEvents.AddMercToSquad(merc_id, squad_id, spawn_pos)
	LocalAddMercToSquad(merc_id, squad_id, spawn_pos)
end

---
--- Removes a merc from a squad.
---
--- @param merc_id string The ID of the merc to remove.
---
function LocalRemoveMercFromSquad(merc_id)
	local merc = g_Units[merc_id]
	if merc then
		merc:Despawn()
	end
end

---
--- Removes a merc from a squad.
---
--- @param merc_id string The ID of the merc to remove.
---
function NetSyncEvents.RemoveMercFromSquad(merc_id)
	LocalRemoveMercFromSquad(merc_id)
end

---
--- Spawns an enemy squad in the specified sector.
---
--- @param sector_id string The ID of the sector to spawn the enemy squad in.
--- @param enemy_squad_id string The ID of the enemy squad to spawn. If not provided, defaults to "EmeraldCoast".
--- @return table The newly created enemy squad.
---
function CheatSpawnEnemySquad(sector_id, enemy_squad_id)
	enemy_squad_id = enemy_squad_id or "EmeraldCoast"
	local enemy_squad_def = enemy_squad_id and EnemySquadDefs[enemy_squad_id]
	if not enemy_squad_def then
		return
	end
	
	local generated_unit_ids, generated_unit_names, generated_sources, generated_appearances = GenerateRandEnemySquadUnits(enemy_squad_id)	
	local units = GenerateUnitsFromTemplates(sector_id, generated_unit_ids, "Cheat", generated_unit_names, generated_appearances)
	return CreateNewSatelliteSquad(
		{
			Side = "enemy1",
			CurrentSector = sector_id,
			Name = Untranslated("Cheat Spawned Squad")
		},
		units, nil, nil, enemy_squad_id
	)
end

---
--- Opens the AI debug interface if the game is not in a network session.
---
function CheatOpenAIDebug()
	if g_Combat and not netInGame then
		SetInGameInterfaceMode("IModeAIDebug")
	end
end