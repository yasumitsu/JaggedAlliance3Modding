DefineClass.ModifyWeaponDlg = {
	__parents = { "XContextWindow" },
	
	-- Rotation
	mouseDown = false,
	mouseUpWait = false,
	lastTickMouseDown = false,
	mouseDownRotationAxis = false,
	mouseDownRotationAngle = false,
	leftBinding = false,
	rightBinding = false,
	nodeParent = false,
	
	playerUnits = false,
	sector = false,

	weaponModel = false,
	weaponClone = false,
	weaponConditionOnOpen = false,
	
	canEdit = true,
	active_weapon_spot = false,
	spotToUI = false,
	
	selectedWeapon = false, -- Index in the weapon list
	selectedWeaponItemId = false, -- Unique item id of the selected weapon
	
	maxZoom = 200,
	minZoom = 100,
	currentZoom = 100,
	
	weaponSlideInThread = false,
	render_mode_open = false,
}

local angleRotatePerTick = 20
local uiRefreshFreq = 200

---
--- Opens the ModifyWeaponDlg window and sets up the necessary state for modifying a weapon.
---
--- This function is responsible for the following tasks:
--- - Canceling any active drag operations
--- - Setting the render mode to "scene" if it was previously "ui"
--- - Playing a start FX for the ModifyWeaponUI
--- - Setting the game flags on the g_Cabinet object
--- - Determining the owner of the weapon being modified (either the currently selected unit or a looted weapon)
--- - Collecting all the weapons possessed by the owner's squad
--- - Setting the selected weapon to be displayed in the UI
--- - Creating a thread to handle the rotation logic for the weapon model
--- - Resolving the "node" element in the UI
---
--- @param ... Any additional arguments passed to the Open function
function ModifyWeaponDlg:Open(...)
	CancelDrag()
	if GetRenderMode() == "ui" then
		self.render_mode_open = "ui"
		SetRenderMode("scene")
	end

	--Pause("ModifyWeaponDlg")
	PlayFX("ModifyWeaponUI", "start", false, false, g_Cabinet:GetPos())
	Msg("ModifyWeaponDialogOpened")
	g_Cabinet:SetGameFlags(const.gofRealTimeAnim)
	
	local partsDisplay = self.idResourceIndicator
	local owner = self.context.owner
	local looted = false
	-- Container marker, stash etc. (Not sure if the modification logic actually supports this :/)
	if not IsKindOfClasses(owner, "Unit", "UnitData") or owner:IsDead() or (owner.Squad and gv_Squads[owner.Squad] and gv_Squads[owner.Squad].Side ~= "player1") then
		looted = true
		owner = Selection[1]
	end
	local ownerSquad = false
	if looted then
		if gv_SatelliteView then
			ownerSquad = g_SatelliteUI.selected_squad
		else
			ownerSquad = gv_Squads[g_CurrentSquad]
		end
		if not ownerSquad then
			local inventoryUnit = GetInventoryUnit()
			if inventoryUnit and inventoryUnit.Squad then
				ownerSquad = gv_Squads[inventoryUnit.Squad]
			end
		end
	else
		ownerSquad = gv_Squads[owner.Squad]
	end
	
	self.sector = ownerSquad and ownerSquad.CurrentSector or gv_CurrentSectorId or "A1"
	partsDisplay:SetContext(self.sector)

	XContextWindow.Open(self, ...)
	
	local leftBinding = GetShortcuts("actionRotLeft")
	local rightBinding = GetShortcuts("actionRotRight")
	self.leftBinding = leftBinding and GetCameraVKCodeFromShortcut(leftBinding[1]) or false
	self.rightBinding = rightBinding and GetCameraVKCodeFromShortcut(rightBinding[1]) or false

	self:CreateThread("rotateThread", function()
		while self.window_state ~= "destroying" do
			self:LogicProc()
			WaitNextFrame()
		end
	end)
	
	self.nodeParent = self:ResolveId("node")

	-- Collect all weapons the squad posseses.
	local allWeapons, selectedWeapon = GetPlayerWeapons(ownerSquad, owner, self.context.slot)
	local playerUnits = GetPlayerMercsInSector(self.sector)
	for idx, id in ipairs(playerUnits) do
		playerUnits[idx] = gv_SatelliteView and gv_UnitData[id] or g_Units[id] or gv_UnitData[id]
	end
	if looted then
		allWeapons[#allWeapons + 1] = { weapon = self.context.weapon, slot = self.context.slot }
		selectedWeapon = self.context.weapon
		self.canEdit = false
	end
	self.idLootedWeapon:SetVisible(looted)
	
	self.allWeapons = allWeapons
	self.playerUnits = playerUnits

	local selectedWeaponIdx = table.find(allWeapons, "weapon", selectedWeapon)
	assert(selectedWeapon and selectedWeaponIdx)
	if not selectedWeaponIdx then return end
	self:SetWeapon(selectedWeaponIdx)
end

if FirstLoad then
	g_SetWeaponWaitThread = false
	g_CachedAnimation = { thread = false, index = false, direction = false}
end
---
--- Sets the current weapon being displayed in the ModifyWeaponDlg.
--- This function handles the visual representation of the weapon, including:
--- - Creating a clone of the weapon to track changes
--- - Attaching the weapon model to a fake origin object
--- - Generating UI elements for modifiable weapon slots
--- - Animating the transition between different weapons
---
--- @param index number The index of the weapon to set in the `allWeapons` table
--- @param direction number (optional) The direction of the weapon transition animation (1 or -1)
---
function ModifyWeaponDlg:SetWeapon(index, direction)
	-- if an animation delay is running, cache the input until it ends
	if IsValidThread(g_SetWeaponWaitThread) then
		g_CachedAnimation.index = index
		g_CachedAnimation.direction = direction
		if IsValidThread(g_CachedAnimation.thread) then DeleteThread(g_CachedAnimation.thread) end
		g_CachedAnimation.thread = CreateGameTimeThread(function()
			WaitWakeup()
			self:SetWeapon(g_CachedAnimation.index, g_CachedAnimation.direction)
		end)
		return 
	else
		g_SetWeaponWaitThread = false
		table.clear(g_CachedAnimation)
	end
	
	self:CloseContextMenu()
	direction = direction or 1

	local ctx = self.allWeapons[index]
	local weapon = ctx.weapon
	local fakeOriginObject = g_Cabinet
	self:SetContext(ctx)
	self.selectedWeapon = index
	self.selectedWeaponItemId = weapon.id
	
	-- Copy the weapon. This copy doesn't have a visual object
	-- and is used for showing property changes.
	local weaponClone = weapon:UIClone()
	self.weaponClone = weaponClone
	weaponClone:ApplyModifiersList(self.weaponClone.applied_modifiers)
	rawset(weaponClone, "cloned_weapon", true) -- For debugging
	-- Record the condition of the weapon when set to display changes between modifications in the current session only.
	self.weaponConditionOnOpen = weaponClone.Condition
	
	NetSyncEvent("WeaponModifyLookingAtWeapon", netUniqueId, weapon.id)
	
	self.idWeaponMeta:SetContext(self.weaponClone, true)
	self.idCondition:SetContext(self.weaponClone, true)
	self.idTextAboveButtons:SetContext(self.weaponClone, true)
	self.idWeaponParts:DeleteChildren()
	
	local weaponModel = weaponClone:CreateVisualObj(self)
	weaponClone:UpdateVisualObj(weaponModel)
	weaponModel:SetPos(fakeOriginObject:GetPos())
	weaponModel:SetForcedLOD(0)
	weaponModel:SetGameFlags(const.gofRealTimeAnim)
	weaponModel:SetGameFlags(const.gofAlwaysRenderable)
	weaponModel:ClearEnumFlags(const.efVisible)
	
	local function lDetachWeaponFromRotation(wep)
		local px, py, pz = wep:GetVisualPosXYZ()
		local axis = wep:GetVisualAxis()
		local angle = wep:GetVisualAngle()
		wep:Detach()
		wep:SetPos(px, py, pz)
		wep:SetAxis(axis)
		wep:SetAngle(angle)
		return px, py, pz
	end
	
	local function lAttachModelToFakeOrigin(wep)
		local attachSpot = wep:GetSpotBeginIndex("Center")
		local spotPosition = wep:GetSpotPos(attachSpot)
		if wep:GetComponentFlags(const.cofComponentAttach) ~= 0 then
			wep:SetAttachOffset(fakeOriginObject:GetPos() - spotPosition)
		end
		fakeOriginObject:Attach(wep)
	end

	if IsKindOf(weapon, "Pistol") then
		--weaponModel:SetScale(200)
		self.maxZoom = 650
		self.minZoom = 400
	elseif IsKindOf(weapon, "MachineGun") then
		--weaponModel:SetScale(120)
		self.maxZoom = 120
		self.minZoom = 120
	elseif IsKindOf(weapon, "Mortar") then
		weaponModel:SetScale(70)
		self.maxZoom = 120
		self.minZoom = 120
	else
		weaponModel:SetScale(120)
		self.maxZoom = 400
		self.minZoom = 120
	end
	self.currentZoom = self.minZoom

	-- Generate UI for all modifiable slots
	local spotToUI = {}
	local visualSpots = {}
	for i, slot in ipairs(Presets.WeaponUpgradeSlot.Default) do
		local slotId = slot.id
		local idx = table.find(weapon.ComponentSlots, "SlotType", slotId)
		local enabled = idx and weapon.ComponentSlots[idx].Modifiable

		if enabled then
			local wnd = XTemplateSpawn("WeaponComponentWindow", self.idWeaponParts, 
			SubContext(weapon, 
				{
					slot = weapon.ComponentSlots[idx],
					slotPreset = slot,
					DisplayName = slot.DisplayName
				}
			))
			wnd:Open()
			spotToUI[slotId] = wnd
			
			local spotPos = GetWeaponSpotPosForModifyUI(weaponModel, slotId)
			local _, spotPosScreen = GameToScreen(spotPos)
			visualSpots[#visualSpots + 1] = { slotId = slotId, pos = spotPosScreen }
		end
	end

	-- Delete old (in an animated fashion)
	if self.weaponModel then
		
		-- t = S/v
		local swapTimePerDistance = 5
		local function lGetTimeForPath(obj, dest)
			local dist = dest:Dist(obj:GetPos())
			return dest, DivRound(dist, swapTimePerDistance)
		end
		
		local offset = 1200 * direction
		
		-- Attach and detach to have final pos
		lAttachModelToFakeOrigin(weaponModel) -- attach outside thread so ui windows can be sorted
		self.weaponSlideInThread = CreateRealTimeThread(function(oldObj, newObj)
			local px, py, pz = lDetachWeaponFromRotation(newObj)
			newObj:SetPos(point(px + offset, py, pz))
			newObj:SetEnumFlags(const.efVisible)
			newObj:SetPos(lGetTimeForPath(newObj, point(px, py, pz)))	
		
			local px, py, pz = lDetachWeaponFromRotation(oldObj)
			local pipi = fakeOriginObject:GetPos()
			pipi:SetX(pipi:x() - offset)

			local pt, time = lGetTimeForPath(oldObj, point(pipi:x() - offset, py, pz))
			oldObj:SetPos(pt, time) 
			Sleep(time)
			DoneObject(oldObj)
			
			if newObj ~= self.weaponModel then return end

			-- Reattach new (but reset various stuff first)
			newObj:SetAngle(0)
			newObj:SetAxis(axis_z)
			newObj:SetPos(fakeOriginObject:GetPos())
			lAttachModelToFakeOrigin(newObj)
			UIL.Invalidate()
		end, self.weaponModel, weaponModel)
		self.weaponModel = false
	else
		lAttachModelToFakeOrigin(weaponModel)
		weaponModel:SetEnumFlags(const.efVisible)
	end
	self.weaponModel = weaponModel
	self:ApplyZoom()
	
	-- We want the auto-update without relinquishing ownership of the object.
	local setWeaponCompFunc = weaponClone.SetWeaponComponent
	weaponClone.SetWeaponComponent = function(self, ...)
		setWeaponCompFunc(self, ...)
		weaponClone:UpdateVisualObj(weaponModel)
	end
	
	-- Order by visual order
	table.sort(visualSpots, function(a, b)
		local aX = a.pos and a.pos:x() or 0
		local bX = b.pos and b.pos:x() or 0
		return aX > bX
	end)
	for slotId, wnd in pairs(spotToUI) do
		local idx = table.find(visualSpots, "slotId", slotId)
		wnd:SetZOrder(idx)
	end
	self.spotToUI = spotToUI
	RunWhenXWindowIsReady(self.idWeaponParts, function(self)
		if GetUIStyleGamepad() then
			self:SetSelection(1)
		end
	end, self.idWeaponParts)
	
	-- add small delay while the animation is running
	g_SetWeaponWaitThread = CreateRealTimeThread(function()
		Sleep(250)
		if IsValidThread(g_CachedAnimation.thread) then Wakeup(g_CachedAnimation.thread) end
	end)
	
	--[[local wnd = XTemplateSpawn("WeaponColorWindow", self.idWeaponParts, 
	SubContext(weapon, 
		{
			slot = { AvailableComponents = Presets.WeaponColor.Default, SlotType = "Color" },
			slotPreset = { id = "Origin", model = weaponModel, DisplayName = T(522749505615, "Color"), },
			DisplayName = T(522749505615, "Color"),
		}
	))
	wnd:Open()]]
	
	self:UpdateWeaponProps()
	self.idWeaponChangeTrigger:SetContext(weapon, false)
end

---
--- Completes the weapon modification process and performs the following actions:
--- - If the render mode is open, sets the render mode back to "ui"
--- - Notifies that the selected object has been modified
--- - Respawns the inventory UI
--- - Plays the "ModifyWeaponUI" end FX
---
--- @param self ModifyWeaponDlg The instance of the ModifyWeaponDlg class
---
function ModifyWeaponDlg:Done()
	if self.render_mode_open then
		SetRenderMode("ui")
	end

	--Resume("ModifyWeaponDlg")
	ObjModified(SelectedObj)
	InventoryUIRespawn()
	PlayFX("ModifyWeaponUI", "end")
end

---
--- Calculates the cost of changes to a weapon's components.
---
--- @param self ModifyWeaponDlg The instance of the ModifyWeaponDlg class
--- @param slotFilter string|nil The slot to filter the changes by, or nil to check all slots
--- @param placedComponentOverride string|nil The component to override the placed component with, or nil to use the actual placed component
--- @return table The costs of the changes, keyed by resource type
--- @return boolean Whether any changes were made
--- @return boolean Whether the player can afford the changes
--- @return table Whether the player can afford each individual cost, keyed by resource type
---
function ModifyWeaponDlg:GetChangesCost(slotFilter, placedComponentOverride)
	if not self.context.weapon then return {}, false, true, {} end

	local actualWeapon = self.context.weapon
	local weapon = self.weaponClone
	local components = weapon.components
	local costs = { }
	local anyChanged = false
	for slot, itemId in pairs(actualWeapon.components) do
		local placedComponent = placedComponentOverride or components[slot] or ""
		if placedComponent ~= itemId and (not slotFilter or slot == slotFilter) then
			local item
			if slot == "Color" then
				item = Presets.WeaponColor.Default[placedComponent]
			else
				item = WeaponComponents[placedComponent]
			end

			local partCost = item and item.Cost or 0 -- Unequip cost?
			if partCost ~= 0 then
				if costs["Parts"] then
					costs["Parts"] = costs["Parts"] + partCost
				else
					costs["Parts"] = partCost
				end
			end
			
			for i, cost in ipairs(item and item.AdditionalCosts) do
				if costs[cost.Type] then
					costs[cost.Type] = costs[cost.Type] + cost.Amount
				else
					costs[cost.Type] = cost.Amount
				end
			end

			anyChanged = true
		end
	end

	if CheatEnabled("FreeParts") then
		return costs, anyChanged, true, {}
	end
	
	local canAfford = true
	local canAffordPerCost = {}
	for typ, cost in pairs(costs) do
		local costPreset = SectorOperationResouces[typ]
		local has = costPreset.current(self.sector)
		if has < cost then
			canAfford = false
			canAffordPerCost[typ] = false
		else
			canAffordPerCost[typ] = true
		end
	end

	return costs, anyChanged, canAfford, canAffordPerCost
end

---
--- Pays the costs associated with modifying a weapon.
---
--- @param costs table The costs to pay, where the keys are the resource types and the values are the amounts to pay.
---
function ModifyWeaponDlg:PayCosts(costs)
	for typ, cost in sorted_pairs(costs) do
		local costPreset = SectorOperationResouces[typ]
		costPreset.pay(self.sector, cost)
	end
end

---
--- Gets a table of weapon components that are blocked by the given component.
---
--- @param partId string The ID of the weapon component.
--- @param weaponClass string The class of the weapon.
--- @return table A table of weapon component IDs that are blocked by the given component.
---
function GetComponentsBlockedByComponent(partId, weaponClass)
	local blockComponents = {}
	for i, preset in pairs(WeaponComponentBlockPairs) do
		if preset.Weapon == weaponClass then
			if preset.ComponentBlockOne == partId then
				blockComponents[preset.ComponentBlockTwo] = true
			elseif preset.ComponentBlockTwo == partId then
				blockComponents[preset.ComponentBlockOne] = true
			end
		end
	end
	return blockComponents
end

---
--- Checks if any of the attached weapon components block the given component.
---
--- @param weapon table The weapon object.
--- @param partDef table The definition of the weapon component to check.
--- @return boolean, string Whether any attached components block the given component, and the ID of the blocking component if so.
---
function GetComponentBlocksAnyOfAttachedSlots(weapon, partDef)
	if partDef and partDef.BlockSlots and next(partDef.BlockSlots) then
		for i, slot in ipairs(partDef.BlockSlots) do
			local attachedCompThere = weapon.components[slot]
			local defaultComponentData = table.find_value(weapon.ComponentSlots, "SlotType", slot)
			local defaultComponent = defaultComponentData and defaultComponentData.DefaultComponent or ""
			if attachedCompThere ~= "" and attachedCompThere ~= defaultComponent then
				return true, attachedCompThere
			end
		end
	end
end

---
--- Resets the FSR2 temporal effect.
---
--- This function checks if the current temporal effect type is "fsr2", and if so, resets the temporal effect.
---
--- @function ResetFsr2
--- @return nil
---
function ResetFsr2()
	if hr.TemporalGetType() == "fsr2" then
		hr.TemporalReset()
	end
end

---
--- Restores the weapon components of a clone weapon to match the source weapon.
---
--- @param cloneWeapon table The clone weapon object.
--- @param sourceWeapon table The source weapon object.
---
function RestoreCloneWeaponComponents(cloneWeapon, sourceWeapon)
	local cloneComponents = cloneWeapon.components
	for slot, component in pairs(sourceWeapon.components) do
		if cloneComponents[slot] ~= component then
			cloneWeapon:SetWeaponComponent(slot, component)
		end
	end
	ResetFsr2()
end

---
--- Checks if a weapon slot can be modified.
---
--- @param slot table The weapon slot to check.
--- @param partId string The ID of the weapon component to check.
--- @return boolean, string, string Whether the slot can be modified, the reason if not, and the ID of the blocking component if blocked.
---
function ModifyWeaponDlg:CanModifySlot(slot, partId)
	local weapon = self.context.weapon
	local slotName = slot.SlotType
	local blocked = false
	
	-- Check if slot is blocked
	for name, attached in pairs(weapon.components) do
		local def = WeaponComponents[attached]
		if def and def.BlockSlots and next(def.BlockSlots) then
			if table.find(def.BlockSlots, slotName) then
				blocked = attached
				break
			end
		end
	end
	if blocked then return false, "blocked", blocked end
	
	-- Check if placing any of the slot options is possible due to a blocked slot having a component in it already.
	if slot and slot.AvailableComponents then
		local anyPossible, impossibleBecauseOf = false
		for i, component in ipairs(slot.AvailableComponents) do
			local def = WeaponComponents[component]
			local blocksAny, blockedId = GetComponentBlocksAnyOfAttachedSlots(weapon, def)
			impossibleBecauseOf = impossibleBecauseOf or blockedId
			if not blocksAny then
				anyPossible = true
				break
			end
		end
		if not anyPossible then
			return false, "blocked", impossibleBecauseOf
		end
	end
	
	-- If a part id is provided, check if it blocks any of the current components,
	-- or if it itself blocked by an attached component.
	if partId then
		-- Check if there's an attached component in a slot that this component will block
		local partDef = WeaponComponents[partId]
		local blocksAny, blockedId = GetComponentBlocksAnyOfAttachedSlots(weapon, partDef)
		if blocksAny then
			return false, "blocked", blockedId
		end
	
		for name, attached in pairs(weapon.components) do
			local componentsBlock = GetComponentsBlockedByComponent(attached, weapon.class)
			if componentsBlock[partId] then -- Attached is blocking me
				return false, "blocked", attached
			end
		end
		
		local componentsWillBlock = GetComponentsBlockedByComponent(partId, weapon.class)
		for name, attached in pairs(weapon.components) do
			if componentsWillBlock[attached] then -- Blocking already attached
				return false, "blocked", attached
			end
		end
	end

	local anyOptions = false
	local anyAffordable = false
	local equipped = weapon.components[slotName]
	for i, comp in ipairs(slot.AvailableComponents) do
		if comp ~= equipped then
			anyOptions = true
			local costs, _, affordable = self:GetChangesCost(slotName, comp)
			if affordable then
				anyAffordable = true
				break
			end
		end
	end
	if anyOptions and not anyAffordable then return true, "cantAfford" end

	return true
end

---
--- Checks if the specified weapon slot has changes compared to the original weapon.
---
--- @param slot string The name of the weapon slot to check.
--- @return boolean True if the slot has changes, false otherwise.
---
function ModifyWeaponDlg:SlotHasChanges(slot)
	local placedComponent = self.weaponClone.components[slot] or ""
	local originalComponent = self.context.weapon.components[slot] or ""
	
	return placedComponent ~= originalComponent
end

---
--- Converts a weapon modification difficulty value to a localized text string based on the given mercenary skill level.
---
--- @param context_obj table The context object containing the modification difficulty and mercenary skill level.
--- @param difficulty number The weapon modification difficulty value.
--- @param mercSkill number The mercenary's mechanical skill level.
--- @return string The localized text string representing the weapon modification difficulty.
---
function TFormat.ModificationDifficultyToText(context_obj, difficulty, mercSkill)
	if not difficulty or not mercSkill then return Untranslated("Error") end
	local skillDiff = mercSkill - difficulty
	if skillDiff < 50 then
		return T(998267627242, --[[Weapon modification difficulty]] "<red>Impossible</red>")
	elseif skillDiff < 70 then
		return T(722888273329, --[[Weapon modification difficulty]] "Hard")
	elseif skillDiff < 90 then
		return T(444596827186, --[[Weapon modification difficulty]] "Moderate")
	elseif skillDiff < 120 then
		return T(700940162389, --[[Weapon modification difficulty]] "Easy")
	else
		return T(368429330332, --[[Weapon modification difficulty]] "Trivial")
	end
end

---
--- Retrieves the parameters needed to calculate the weapon modification difficulty.
---
--- @param componentToChangePreset table The preset information for the component being changed.
--- @return number, string, number, boolean The player's mechanical skill level, the ID of the most skilled player unit, the modification difficulty, and whether the modification is allowed.
---
function ModifyWeaponDlg:GetModificationDifficultyParams(componentToChangePreset)
	local playerMechSkill, mostSkilled = false, false
	for i, u in ipairs(self.playerUnits) do
		local mechSkill = u.Mechanical
		if not playerMechSkill or mechSkill > playerMechSkill then
			playerMechSkill = mechSkill
			mostSkilled = u.session_id
		end
	end
	if not playerMechSkill then return end
	
	local difficulty = componentToChangePreset and componentToChangePreset.ModificationDifficulty or 0
	return playerMechSkill, mostSkilled, difficulty, (playerMechSkill - difficulty > 10)
end

---
--- Rolls a skill check against a given difficulty, returning the outcome and the result.
---
--- @param playerMechSkill number The player's mechanical skill level.
--- @param difficulty number The difficulty of the skill check.
--- @return string, number The outcome of the skill check ("crit-success", "success", "crit-fail", "fail") and the result of the skill check.
---
function RollSkillDifficulty(playerMechSkill,difficulty)
	local skillDiff = playerMechSkill - difficulty
	local rand = AsyncRand(100)
	local result = skillDiff - rand
	if CheatEnabled("SkillCheck") and result <= 0 then
		if result == 0 then 
			result = 1
		else
			result = - result
		end		
	end
	
	local outcome = ""
	if result > 80 then
		outcome = "crit-success"
	elseif result > 0 then
		outcome = "success"
	elseif result < -80 then
		outcome = "crit-fail"
	elseif result <= 0 then
		outcome = "fail"
	end
	return outcome, result
end			

---
--- Applies the changes to the specified weapon modification slot.
---
--- @param modSlot string The modification slot to apply the changes to.
--- @param skipChance boolean Whether to skip the chance roll for the modification.
---
function ModifyWeaponDlg:ApplyChangesSlot(modSlot, skipChance)
	assert(modSlot)
	if not modSlot then return end

	local actualWeapon = self.context.weapon
	local owner = self.context.owner
	local slot = self.context.slot
	if not self.canEdit then return end
	assert(type(self.context.owner) == "string")
	
	local costs, anyChanges, canAfford = self:GetChangesCost(modSlot)
	if not anyChanges or not canAfford then return end
	
	local componentToChangeTo = self.weaponClone.components[modSlot]
	local componentToChangePreset = WeaponComponents[componentToChangeTo]
	local playerMechSkill, bestMechSkillUnit, difficulty, allowed = self:GetModificationDifficultyParams(componentToChangePreset)
	if not playerMechSkill or not allowed then return end
	
	-- Changing to empty is free
	if componentToChangeTo == "" then
		skipChance = true
	end

	-- This needs to be in a thread as the popup needs to close first.
	-- We can't call the function before closing it as then we cannot observe its changes on the weapon clone.
	CreateMapRealTimeThread(function()
		local success, unit, modAdded
		if not skipChance then
			-- Doesn't have to be synced as the UI is per player, and only the result is sent over.
			local itemOwnerUnit = table.find_value(self.playerUnits, "session_id", owner)
			local outcome, result = RollSkillDifficulty(playerMechSkill, difficulty)
			if outcome == "fail" or outcome == "crit-fail" then
				-- Lose only part costs, no special costs
				local partCosts = costs["Parts"]
				if partCosts then
					self:PayCosts({ ["Parts"] = partCosts })
				end
				
				local conditionLoss = MulDivRound(result, 100 - actualWeapon.Reliability, 100)
				if outcome == "crit-fail" then
					conditionLoss = -actualWeapon.Condition
				end
				
				PlayFX("WeaponModificationFail", "start")
				if conditionLoss ~= 0 then
					if outcome == "fail" then
						CombatLog("important", T{455033345702, "Modification failed. <weapon> has lost Condition.", weapon = actualWeapon.DisplayName, val = conditionLoss})
						CombatLog("debug", T{Untranslated("Modification failed - <weapon> lost <val> condition"), weapon = actualWeapon.DisplayName, val = conditionLoss})
					elseif outcome == "crit-fail" then
						CombatLog("important", T{674809527450, "Modification failed. <weapon> has lost Condition.", weapon = actualWeapon.DisplayName, val = conditionLoss})
						CombatLog("debug", T{Untranslated("Modification critical failure (<val> condition loss)"), val = conditionLoss})
					end
					NetSyncEvent("WeaponModifyCondition", owner, slot, conditionLoss)
				else
					CombatLog("important", T(238606985729, "Modification failed."))
				end
				return
			end
			
			PlayFX("WeaponModificationSuccess", "start")
			
			-- Critical win - upgrade doesn't cost anything
			if outcome == "crit-success" then
				local precentOfPartsToRefund = 50
				local costsNotRefunded = {}
				
				local costsString = {}
				for costType, amount in sorted_pairs(costs) do
					if costType ~= "Parts" then
						costsNotRefunded[costType] = amount
						goto continue
					end
				
					local refundedAmount = MulDivRound(amount, precentOfPartsToRefund, 100)
					local nonRefundedAmount = amount - refundedAmount
					costsNotRefunded[costType] = nonRefundedAmount
					
					local costPreset = SectorOperationResouces[costType]
					local name = costPreset.name
					costsString[#costsString + 1] = Untranslated(refundedAmount) .. " " .. name
					::continue::
				end
				if #costsString > 0 then
					costsString = table.concat(costsString, ", ")
					CombatLog("important", T{979284579828, "Modification of <weapon> successful - <costs> refunded", weapon = actualWeapon.DisplayName, costs = costsString})
					CombatLog("debug", T{Untranslated("Modification critical success - refunded <costs>."), costs = costsString})
				else
					CombatLog("important", T{753849538837, "Modification of <weapon> successful", weapon = actualWeapon.DisplayName})
					CombatLog("debug", T(Untranslated("Modification critical success.")))
				end
				self:PayCosts(costsNotRefunded)
			else
				self:PayCosts(costs)
				CombatLog("important", T{753849538837, "Modification of <weapon> successful", weapon = actualWeapon.DisplayName})
			end
			unit = table.find_value(self.playerUnits, "session_id", bestMechSkillUnit)
			success = true
			modAdded = true
		else
			CombatLog("important", T{753849538837, "Modification of <weapon> successful", weapon = actualWeapon.DisplayName})
			success = true
		end
		
		local clone = self.weaponClone
		clone:SetWeaponComponent(modSlot, componentToChangeTo)
		clone:UpdateVisualObj(self.weaponModel)

		local oldComponent = actualWeapon.components[modSlot]
		NetSyncEvent("WeaponModified", owner, slot, clone.components, clone.components.Color, success, modAdded, bestMechSkillUnit, modSlot, oldComponent)
		
		CreateMapRealTimeThread(function()
			if oldComponent and oldComponent ~= "" then
				PlayFX("WeaponComponentDetached", "start", oldComponent)
				Sleep(1000)
			end
			if componentToChangeTo and componentToChangeTo ~= "" then
				PlayFX("WeaponComponentAttached", "start", componentToChangeTo)
			end
		end)
		-- PlayFX("WeaponColorChanged", "end", actualWeapon, colorId)
		-- weapon:UpdateColorMod(self.weaponModel) -- The weapon in the cabinet
		-- weapon:UpdateColorMod() -- The weapon in the world
		--[[ObjModified(actualWeapon)
		self.idToolBar:OnUpdateActions()]]
		if success then
			local mechanic = gv_SatelliteView and gv_UnitData[bestMechSkillUnit] or g_Units[bestMechSkillUnit]
			Msg("WeaponModifiedSuccess", actualWeapon, unit, modAdded, mechanic, modSlot, oldComponent)
		end
	end)
end

---
--- Returns the mouse position scaled to the current UI scale.
---
--- @return point The scaled mouse position.
function ModifyWeaponDlg:GetMousePos()
	local pos = terminal.GetMousePos()
	return point(MulDivRound(pos:x(), 1000, self.scale:x()), MulDivRound(pos:y(), 1000, self.scale:y()))
end

---
--- Zooms the weapon modification dialog in by 25 units.
---
--- This function is called when the user scrolls the mouse wheel forward on the dialog.
--- It increases the current zoom level by 25 units, clamping the value between the minimum and maximum zoom levels.
--- The new zoom level is then applied to the camera using the `ApplyZoom()` function.
---
--- @return nil
function ModifyWeaponDlg:OnMouseWheelForward()
	local currentZoom = self.currentZoom
	currentZoom = currentZoom + 25
	self.currentZoom = Clamp(currentZoom, self.minZoom, self.maxZoom)
	self:ApplyZoom()
end

---
--- Zooms the weapon modification dialog out by 25 units.
---
--- This function is called when the user scrolls the mouse wheel backward on the dialog.
--- It decreases the current zoom level by 25 units, clamping the value between the minimum and maximum zoom levels.
--- The new zoom level is then applied to the camera using the `ApplyZoom()` function.
---
--- @return nil
function ModifyWeaponDlg:OnMouseWheelBack()
	local currentZoom = self.currentZoom
	currentZoom = currentZoom - 25
	self.currentZoom = Clamp(currentZoom, self.minZoom, self.maxZoom)
	self:ApplyZoom()
end

---
--- Applies the current zoom level to the camera.
---
--- This function is called to update the camera's zoom level to the current zoom level stored in the `self.currentZoom` variable.
--- The zoom level is clamped between the minimum and maximum zoom levels defined in the `self.minZoom` and `self.maxZoom` variables.
---
--- @return nil
function ModifyWeaponDlg:ApplyZoom()
	cameraTac.SetZoom(1000 - self.currentZoom, 50)
end

---
--- Handles the logic for rotating the weapon model in the Modify Weapon dialog.
---
--- This function is responsible for handling keyboard and mouse input to rotate the weapon model
--- displayed in the Modify Weapon dialog. It updates the rotation of the weapon model based on
--- user input, and applies the changes to the underlying weapon object.
---
--- @param self ModifyWeaponDlg The instance of the ModifyWeaponDlg class.
--- @return nil
function ModifyWeaponDlg:LogicProc()
	if terminal.desktop.inactive or not IsValid(g_Cabinet) then return end

	local axis, angle = g_Cabinet:GetAxis(), g_Cabinet:GetAngle()

	-- Keyboard rotation
	if self.nodeParent == terminal.desktop:GetKeyboardFocus() then
		if self.leftBinding and terminal.IsKeyPressed(self.leftBinding) then
			axis, angle = ComposeRotation(axis, angle, axis_z, angleRotatePerTick * 60)
			g_Cabinet:SetAxisAngle(axis, angle, 100)
		elseif self.rightBinding and terminal.IsKeyPressed(self.rightBinding) then
			axis, angle = ComposeRotation(axis, angle, axis_z, -angleRotatePerTick * 60)
			g_Cabinet:SetAxisAngle(axis, angle, 100)
		end
	end
	
	-- Mouse rotation
	local curLeftDown = terminal.IsLRMMouseButtonPressed()
	if curLeftDown and not self.mouseDown then
		-- Record the click position and rotation settings at click.
		self.mouseDown = self:GetMousePos()
		self.mouseDownRotationAxis = axis
		self.mouseDownRotationAngle = angle
		if self.weaponModel and self.weaponModel.weapon then
			PlayFX("WeaponModificationRotate", "start", self.weaponModel.weapon.object_class, self.weaponModel.fx_actor_class)
		end
	elseif not curLeftDown and self.mouseDown then
		self.mouseDown = false
		self.mouseUpWait = false
	end
	
	if self.mouseDown and not self.mouseUpWait then
		local mouseTarget = self:GetMouseTarget(terminal.GetMousePos())
		if mouseTarget ~= self then
			return
		end
		
		if self.mouseDown and self:CloseContextMenu() then
			return
		end
	
		-- Modify the rotation of the weapon relative to what it was when the click began.
		-- Once let go the changes will be applied.
		local currentPos = self:GetMousePos()
		
		-- Prevent jittering, don't update rotation if the movement is too small
		if self.lastTickMouseDown and (currentPos - self.lastTickMouseDown):Len() > 1 then
			local diff = currentPos - self.mouseDown
			axis, angle = ComposeRotation(self.mouseDownRotationAxis, self.mouseDownRotationAngle, axis_z, -diff:x() * 10)
			axis, angle = ComposeRotation(axis, angle, axis_x, diff:y() * 10)
			g_Cabinet:SetAxisAngle(axis, angle, 100)
		end
		self.lastTickMouseDown = currentPos
	end
	
	local gamepadState, gamepadId
	if GetUIStyleGamepad() then
		gamepadState, gamepadId = GetActiveGamepadState()
	end

	if gamepadState then
		local rtS = gamepadState.RightThumb
		local nRtS = rtS == point20 and point20 or Normalize(rtS)
	
		-- Zoom
		local ltHeld = XInput.IsCtrlButtonPressed(gamepadId, "LeftTrigger")
		if ltHeld then
			nRtS = MulDivRound(nRtS, 25, 4096) -- zoom speed
			
			local currentZoom = self.currentZoom
			currentZoom = currentZoom + nRtS:y()
			self.currentZoom = Clamp(currentZoom, self.minZoom, self.maxZoom)
			self:ApplyZoom()
			return
		end

		nRtS = MulDivRound(nRtS, 10, 4096) -- rotate speed
		local axis, angle = g_Cabinet:GetAxis(), g_Cabinet:GetAngle()
		axis, angle = ComposeRotation(axis, angle, axis_z, -nRtS:x() * 10)
		axis, angle = ComposeRotation(axis, angle, axis_x, -nRtS:y() * 10)
		g_Cabinet:SetAxisAngle(axis, angle, 100)
	end
end

---
--- Updates the weapon properties in the UI.
--- This function is called when the weapon properties have been modified.
--- It updates the UI elements to reflect the changes, and marks the weapon and sector as modified.
---
--- @param self ModifyWeaponDlg The instance of the ModifyWeaponDlg class.
---
function ModifyWeaponDlg:UpdateWeaponProps()
	local container = self.idWeaponProps[1]
	if not container then return end
	local anyModified = false
	
	for i=1, #container do
		local element = container[i]
		if element.HasValueChanged then
			anyModified = element:HasValueChanged()
			if anyModified then break end
		end
	end
	
	for i=1, #container do
		local element = container[i]
		if element.UpdateValue then
			element:UpdateValue(anyModified and "modified")
		end
	end
	
	local realWeapon = self.context.weapon
	self.weaponClone.Condition = realWeapon.Condition
	ObjModified(self.sector)
	ObjModified(self.weaponClone)
	self.idCondition.idBar:UpdateValue()
	self.idToolBar:OnUpdateActions()
	
	ResetFsr2()
end

---
--- Sets the active weapon spot in the UI.
---
--- @param self ModifyWeaponDlg The instance of the ModifyWeaponDlg class.
--- @param spot string The name of the weapon spot that is active.
--- @param reason string The reason for setting the active spot, either "selected" or "rollover".
---
function ModifyWeaponDlg:SetActiveSpot(spot, reason)
	if not self.active_weapon_spot then
		self.active_weapon_spot = {}
	end
	self.active_weapon_spot[reason] = spot
	
	if reason == "selected" then
		if spot then
			for i, p in ipairs(self.idWeaponParts) do
				p:ApplyStyle(p.context.slotPreset.id == spot and "normal" or "deselected")
			end
		else
			for i, p in ipairs(self.idWeaponParts) do
				p:ApplyStyle("normal")
			end
		end
	end
end

---
--- Draws the background for the ModifyWeaponDlg UI.
---
--- This function is responsible for drawing a visual indicator on the UI to show the currently
--- selected or hovered weapon spot. It uses the `GetWeaponSpotPosForModifyUI` function to
--- determine the position of the weapon spot, and then draws a circle around that position.
---
--- @param self ModifyWeaponDlg The instance of the ModifyWeaponDlg class.
---
function ModifyWeaponDlg:DrawBackground()
	local drawToSpot = false
	if self.active_weapon_spot then
		if self.active_weapon_spot["selected"] then
			drawToSpot = self.active_weapon_spot["selected"]
		else
			drawToSpot = self.active_weapon_spot["rollover"]
		end
	end

	local weaponModel = self.weaponModel
	local ui = self.spotToUI and self.spotToUI[drawToSpot]
	if weaponModel and drawToSpot and ui and not IsValidThread(self.weaponSlideInThread) then
		local spotPos = GetWeaponSpotPosForModifyUI(weaponModel, drawToSpot)
		local _, spotPosScreen = GameToScreen(spotPos)
		UIL.DrawLineAntialised(5, ui.box:min(), spotPosScreen, self.idCircle.ImageColor)
		local sizeX, sizeY = ScaleXY(self.scale, 20, 20)
		self.idCircle:SetBox(spotPosScreen:x() - sizeX/2, spotPosScreen:y() - sizeY/2, sizeX, sizeY)
	else
		self.idCircle:SetBox(0, 0, 0, 0)
	end
end

---
--- Determines the position of a weapon spot on the weapon model for rendering in the ModifyWeaponDlg UI.
---
--- This function is responsible for finding the correct position of a weapon spot on the weapon model
--- based on the specified `drawToSpot` parameter. It handles various cases where the weapon spot
--- may be named differently or attached to a different component than expected.
---
--- @param weaponModel WeaponModel The weapon model object.
--- @param drawToSpot string The name of the weapon spot to draw.
--- @return Vector3 The position of the weapon spot in world coordinates.
---
function GetWeaponSpotPosForModifyUI(weaponModel, drawToSpot)
	local spotIdx = -1
	local dependency = drawToSpot == "Side" and "Side1" or SlotDependencies[drawToSpot]

	-- AKSU doesnt have a barrel spot or components, but it has it as a modifiable slot.
	if not dependency then
		local values = table.values(SlotDependencies)
		local keys = table.keys(SlotDependencies)
		for i, v in ipairs(values) do
			if v == drawToSpot then
				local key = keys[i]
				if weaponModel:GetSpotBeginIndex(key) ~= -1 then
					dependency = key
				end
			end
		end
	end
	
	-- Some components are named by a different slot than the one they attach to.
	-- Usually in these cases there's only one component, but we handle the case where
	-- there are multiple ones which specifically all attach to the same other slot.
	if not dependency then
		local slotPreset = weaponModel.weapon and weaponModel.weapon.ComponentSlots
		slotPreset = slotPreset and table.find_value(slotPreset, "SlotType", drawToSpot)
		if slotPreset and slotPreset.AvailableComponents then
			local allOnSingleSpot = true
			local singleSpot = false
			
			for i, availComp in ipairs(slotPreset.AvailableComponents) do
				local component = WeaponComponents[availComp]
				local componentVisuals = component and component.Visuals
				for _, visual in ipairs(componentVisuals) do
					if visual.Entity and visual.Slot then
						if not singleSpot then
							singleSpot = visual.Slot
						elseif visual.Slot ~= singleSpot then
							allOnSingleSpot = false
							break
						end
					end
				end
				
				if not allOnSingleSpot then break end
			end
			
			if allOnSingleSpot then
				dependency = singleSpot
			end
		end
	end
	
	-- Try to resolve the object and spot index of the dependency slot
	if dependency then
		if weaponModel.parts[dependency] then
			local partVisual = weaponModel.parts[dependency]
			local dependencySpot = partVisual:GetSpotBeginIndex(drawToSpot)
			if dependencySpot ~= -1 then
				weaponModel = partVisual
				spotIdx = dependencySpot
			end
		end
		
		if spotIdx == -1 then
			spotIdx = weaponModel:GetSpotBeginIndex(dependency)
		end
		
		if spotIdx == -1 then
			spotIdx = weaponModel:GetSpotBeginIndex(drawToSpot)
		end
	else
		spotIdx = weaponModel:GetSpotBeginIndex(drawToSpot)
	end
	
	return weaponModel:GetSpotPos(spotIdx)
end

local lExtraStatExceptions = { "Damage", "WeaponRange", "AimAccuracy", "CritChance", "BaseAP", "ShootAP" }

-- Returns a list of all weapon component modifications which aren't tied to specific stats.
-- Things such as "Attached Grenade Launcher" etc.
---
--- Collects and combines the effects of all weapon components in the given list.
---
--- @param components table|nil A table of weapon component names, or nil to use the components from the weapon clone.
--- @return string, table The combined effects as a string, and a table of the individual effects.
---
function ModifyWeaponDlg:GetWeaponComponentsCombinedEffects(components)
	if not self.weaponClone then -- Initial open
		return
	end

	local collectedData = {}
	components = components or self.weaponClone.components
	for slot, comp in pairs(components) do
		if #(comp or "") == 0 or not WeaponComponents[comp] then goto continue end
		
		local compPreset = WeaponComponents[comp]
		local data = GetWeaponComponentDescriptionData(compPreset)
		for key, mod in pairs(data) do
			if not table.find(lExtraStatExceptions, key) then
				local value = mod.value
				if collectedData[key] and value then
					collectedData[key].value = collectedData[key].value + value
				else
					collectedData[key] = mod
				end
			end
		end
		
		::continue::
	end
	
	local lines = {}
	for i, mod in sorted_pairs(collectedData) do
		lines[#lines + 1] = Untranslated("<bullet_point> " .. _InternalTranslate(mod.display, mod))
	end

	return table.concat(lines, "\n"), collectedData
end

DefineClass.FakeOriginObject = {
	__parents = { "Object", "ComponentInterpolation" },
	entity = "InvisibleObject",
	flags = { gofAlwaysRenderable = true }
}

DefineClass.WeaponComponentWindowClass = {
	__parents = { "XContextWindow" }
}

---
--- Sets the active spot in the ModifyWeaponDlg when the WeaponComponentWindowClass receives a rollover event.
---
--- @param rollover boolean Whether the rollover event is active or not.
---
function WeaponComponentWindowClass:OnSetRollover(rollover)
	local modifyWeaponDlg = self:ResolveId("node")
	modifyWeaponDlg:SetActiveSpot(rollover and self.context.slotPreset.id, "rollover")
end

---
--- Closes the context menu associated with the ModifyWeaponDlg.
---
--- @return boolean True if a context menu was closed, false otherwise.
---
function ModifyWeaponDlg:CloseContextMenu()
	if self.idChoicePopup then
		self.idChoicePopup:Close()
		self.idChoicePopup = false
		return true
	end
	return false
end

---
--- Toggles the options for the WeaponComponentWindowClass.
---
--- This function is responsible for:
--- - Closing the context menu associated with the ModifyWeaponDlg
--- - Setting the selection of the parent list, if applicable
--- - Spawning a new WeaponModChoicePopup context menu
--- - Setting the active spot in the ModifyWeaponDlg
--- - Restoring the actual component in the preview weapon
--- - Hiding/showing the text above the buttons in the ModifyWeaponDlg
--- - Setting the focus on the new context menu
---
--- @param self WeaponComponentWindowClass The instance of the WeaponComponentWindowClass
---
function WeaponComponentWindowClass:ToggleOptions()
	local modifyWeaponDlg = self:ResolveId("node")
	modifyWeaponDlg:CloseContextMenu()
	
	local parentList = self.parent
	local myIdx = parentList and table.find(parentList, self)
	if myIdx and GetUIStyleGamepad() then
		parentList:SetSelection(myIdx)
	else
		parentList:SetSelection(false)
	end
	
	local slotType = self.context.slot.SlotType
	local ctxMenu = XTemplateSpawn("WeaponModChoicePopup", modifyWeaponDlg, self.context)
	ctxMenu:SetZOrder(999)
	ctxMenu:SetAnchor(self.box)
	ctxMenu:Open()
	ctxMenu.OnDelete = function()
		if not modifyWeaponDlg.context then return end -- Window deleted
		
		modifyWeaponDlg:SetActiveSpot(false, "selected")
		-- Restore actual component in preview weapon.
		RestoreCloneWeaponComponents(modifyWeaponDlg.weaponClone, modifyWeaponDlg.context.weapon)
		modifyWeaponDlg.idTextAboveButtons:SetVisible(true)
	end
	modifyWeaponDlg:SetActiveSpot(slotType, "selected")
	--self.desktop:SetModalWindow(ctxMenu)
	ctxMenu:SetFocus()
	modifyWeaponDlg.idTextAboveButtons:SetVisible(false)
	modifyWeaponDlg.idChoicePopup = ctxMenu
	XDestroyRolloverWindow()
end

---
--- Handles the context update for the WeaponComponentWindowClass.
---
--- This function is responsible for:
--- - Setting the state of the UI elements based on whether the weapon slot can be modified or not.
--- - Displaying the appropriate state icon and overlay based on the modification status.
--- - Adjusting the desaturation and transparency of the UI elements based on the modification status.
---
--- @param self WeaponComponentWindowClass The instance of the WeaponComponentWindowClass
--- @param context table The context data for the WeaponComponentWindowClass
---
function WeaponComponentWindowClass:OnContextUpdate(context)
	local modifyDlg = self:ResolveId("node")
	local canModify, err = modifyDlg:CanModifySlot(self.context.slot)
	
	local uiParent = self.idCurrent
	if err == "blocked" then
		uiParent.idStateIcon:SetImage("UI/Icons/mod_blocked")
		uiParent.idOverlay:SetVisible(true)
		uiParent.idIcon:SetDesaturation(255)
		uiParent.idImage:SetDesaturation(255)
		uiParent:SetTransparency(25)
	elseif err == "cantAfford" then
		uiParent.idStateIcon:SetImage("UI/Icons/mod_parts_lack")
		uiParent.idStateIcon:SetImageColor(GameColors.I)
		uiParent.idOverlay:SetVisible(true)
		uiParent.idIcon:SetDesaturation(255)
		uiParent.idImage:SetDesaturation(255)
		uiParent:SetTransparency(25)
	else
		uiParent.idStateIcon:SetImage("")
		uiParent.idOverlay:SetVisible(false)
		uiParent.idIcon:SetDesaturation(0)
		uiParent.idImage:SetDesaturation(0)
		uiParent:SetTransparency(0)
	end	
end

function OnMsg.ChangeMap()
	CloseDialog("ModifyWeaponDlg", true)
end

DefineClass.WeaponComponentCost = {
	__parents = { "PropertyObject" },
	properties = {
		{ id = "Amount", editor = "number", default = 0 },
		{ id = "Type", editor = "choice", items = function() return table.imap(SectorOperationResouces, "id") end, default = false },
	}
}

---
--- Returns a string representation of the WeaponComponentCost object for the editor view.
---
--- @return string The editor view string for the WeaponComponentCost object.
---
function WeaponComponentCost:GetEditorView()
	return Untranslated((self.Type or "") .. " " .. (self.Amount or ""))
end

DefineClass.WeaponComponentModificationStat = {
	__parents = { "PropertyObject" },
	properties = {
		{ id = "Name", editor = "text", default = false, translate = true },
		{ id = "NumericalAmount", name = "Numerical Amount (Unused)", editor = "number", default = false },
	}
}

---
--- Returns a string representation of the WeaponComponentModificationStat object for the editor view.
---
--- @return string The editor view string for the WeaponComponentModificationStat object.
---
function WeaponComponentModificationStat:GetEditorView()
	return Untranslated(Untranslated(self.Name or "") .. " " .. Untranslated(self.NumericalAmount or ""))
end

---
--- Returns a table of data describing the modifications to a weapon component.
---
--- @param componentPreset WeaponComponentPreset The weapon component preset to get the description data for.
--- @return table The data describing the modifications to the weapon component.
---
function GetWeaponComponentDescriptionData(componentPreset)
	local data = {}
--[[	for i, mod in ipairs(componentPreset.Modifications) do
		local prop = mod.target_prop
		local preset = Presets.WeaponPropertyDef.Default[prop]
		if not preset then
			goto continue
		end
		
		local value = false
		if mod.mod_mul > 1000 then
			local numValue = MulDivRound(mod.mod_mul - 1000, 1, 10)
			data[prop] = { value = numValue, display = T(312841259660, "<display_name> <percentWithSign(value)>"), display_name = preset.display_name}
		elseif mod.mod_add ~= 0 then
			local numValue = false
			if string.find(prop, "AP") then
				data[prop] = { value = mod.mod_add / const.Scale.AP, display = T(219147079229, "<display_name> <numberWithSign(value)> AP"), display_name = preset.display_name}
			else
				data[prop] = { value = mod.mod_add, display = T(843499809680, "<display_name> <numberWithSign(value)>"), display_name = preset.display_name}
			end
		elseif prop == "Caliber" then
			local newCaliber = Presets.Caliber.Default[mod.value]
			if newCaliber then
				data["Caliber"] = { display = T{883968614570, "<display_name> <CaliberName>", CaliberName = newCaliber.Name}, display_name = preset.display_name}
			end
		end
		
		::continue::
	end]]
	
	-- Resolve text values similarly to GetComponentEffectValue
	for i, effectName in ipairs(componentPreset.ModificationEffects) do
		local effect = WeaponComponentEffects[effectName]
		if effect and effect.Description then
			local text = _InternalTranslate(effect.Description, componentPreset) -- Apply component values
			text = _InternalTranslate(Untranslated(text), effect) -- Apply effect values
			data[effectName] = { display = Untranslated(text) }
		end
	end
	
	return data
end

---
--- Returns a table of data describing the modifications to a weapon component.
---
--- @param componentPreset WeaponComponentPreset The weapon component preset to get the description data for.
--- @return table The data describing the modifications to the weapon component.
---
function GetWeaponComponentDescription(componentPreset)
	local data = GetWeaponComponentDescriptionData(componentPreset)
	local lines = {}
	if componentPreset.Description then
		lines[#lines + 1] = T{componentPreset.Description, componentPreset}
	end
	
	local indices = {}
	for modName, mod in sorted_pairs(data) do
		local text = Untranslated("<bullet_point> " .. _InternalTranslate(mod.display, mod))
		lines[#lines + 1] = text
		
		local effect = WeaponComponentEffects[modName]
		if effect then
			indices[text] = effect.SortKey
		end
	end
	
	if #lines == 0 then
		return T(575725466022, "No changes")
	end
	
	table.sort(lines, function(a, b)
		local indexA = indices[a] or 0
		local indexB = indices[b] or 0
		return indexA < indexB
	end)
	
	return table.concat(lines, "\n"), data
end

---
--- Returns a table of data describing the properties of a weapon that can be modified.
---
--- @param item WeaponClone The weapon whose properties are to be described.
--- @return table A table of data describing the modifiable properties of the weapon.
---
function GetWeaponModifyProperties(item)		
	local statList = {}
	local dmgPreset = Presets.WeaponPropertyDef.Default.Damage
	statList[#statList + 1] = { max = dmgPreset.max_progress, bind_to = dmgPreset.bind_to }
	
	local baseAttack = item:GetBaseAttack(false, "force")
	local baseAction = CombatActions[baseAttack]
	local baseAttackPreset = Presets.WeaponPropertyDef.Default.ShootAP
	statList[#statList + 1] = { 
		GetShootAP = function(it)
			return baseAttackPreset:GetProp(it or item)/const.Scale.AP
		end,
		Getbase_ShootAP = function(it)
			return baseAttackPreset:Getbase_Prop(it or item)/const.Scale.AP
		end,
		max = 10,
		display_name = T{310685041358, "Attack Cost (<Name>)", Name = baseAction.DisplayNameShort or baseAction.DisplayName},
		id = "ShootAP",
		reverse_bar = true,
		description = baseAttackPreset.description
	}

	local rangePreset = Presets.WeaponPropertyDef.Default.WeaponRange
	statList[#statList + 1] = { max = rangePreset.max_progress, bind_to = rangePreset.bind_to }

	local critPreset = item.owner and Presets.WeaponPropertyDef.Default.CritChance or Presets.WeaponPropertyDef.Default.MaxCritChance
	local weaponModDlg = GetDialog("ModifyWeaponDlg").idModifyDialog
	local crit = 0
	local unit_id = weaponModDlg.context.owner
	statList[#statList + 1] = {
		GetCritChance = function(it)
			return critPreset:GetProp(it or item, unit_id )
		end,
		Getbase_CritChance = function(it)
			return critPreset:Getbase_Prop(it or item, unit_id )
		end,
		max = critPreset.max_progress,
		display_name = critPreset.display_name,
		id = "CritChance",
		description = critPreset.description
	}

	local aimAcc = Presets.WeaponPropertyDef.Default.AimAccuracy
	statList[#statList + 1] = { max = aimAcc.max_progress, bind_to = aimAcc.bind_to }

	return statList
end

-- unused currently
---
--- Checks if a weapon property should be displayed in the weapon modification dialog.
---
--- @param property table The weapon property to check
--- @param weapon table The weapon being modified
--- @return boolean True if the property should be displayed, false otherwise
---
function DisplayWeaponPropertyInWeaponMod(property, weapon)
	if not weapon:IsWeapon() or not property:DisplayForContext(weapon) then return end
	return not not table.find(properties_to_show, property.id)
end

-- API for prop change tracking
-- HasValueChanged -> bool
-- UpdateValue(anyChanged) -> void

-- There are three objects whose stats are checked for changed.
-- WeaponClone represents the state of the weapon currently being modified + any pending changes.
-- WeaponCloneBase represents the state of the weapon without any modifications.
-- ModifyDlg.Context.Weapon represents the actual weapon being modified.

-- Bars show current changes relative to the base state (WeaponCloneBase)
-- When there is a pending change the actual weapon is checked to determine which stats the
-- pending change will modify, and the data is represented once again relative to the base state.

DefineClass.WeaponModProgressLineClass = {
	__parents = { "XWindow" },
	IdNode = true,
	MinWidth = 400,
	MinHeight = 25,
	MaxHeight = 25,
	Transparency = 0,
	HandleMouse = true,
	
	dataBinding = false,
	dataSource = false,
	metaSource = false,
	metaPropSource = false,
	
	baseValueOverride = false
}

---
--- Sets up a weapon modification progress line in the weapon modification dialog.
---
--- @param propItem table The property item to set up the progress line for
--- @param weapon table The weapon being modified
---
function WeaponModProgressLineClass:Setup(propItem, weapon)
	local dataBinding = propItem.bind_to
	local dataSource = weapon
	local metaSource = false
	local metaPropSource = false
	if not dataBinding then -- Custom
		dataBinding = propItem.id
		dataSource = propItem
		metaSource = propItem
		metaPropSource = propItem
	else -- Weapon property
		metaSource = Presets.WeaponPropertyDef.Default[dataBinding]
		metaPropSource = weapon:GetPropertyMetadata(dataBinding)
	end

	if metaSource then
		self.idText:SetText(metaSource.display_name)
		self:SetRolloverTitle(metaSource.display_name)
		self:SetRolloverText(metaSource.description)
	end

	self:SetReverseBar(propItem.reverse_bar)
	self:SetMaxProgress(propItem.max)
	
	self.dataBinding = dataBinding -- The name of the property (bind_to/id)
	self.dataSource = dataSource -- The object the value of the property will be taken from (weapon/custom)
	self.metaSource = metaSource -- The object which describes the property, design wise (Presets.WeaponPropertyDef.Default/custom)
	self.metaPropSource = metaPropSource -- The object which describes the property, max values etc. (prop_meta/custom)
	self.baseValueOverride = propItem.baseValueOverride
	self:UpdateValue()
end

---
--- Retrieves the value of a property from a data source, handling different types of bindings.
---
--- @param source table The data source object containing the property value.
--- @param binding string The name of the property to retrieve.
--- @param dataSourceOverride table An optional data source object to use instead of the default one.
--- @return any The value of the specified property.
---
function GetValueFromBinding(source, binding, dataSourceOverride)
	if source["Get" .. binding] then
		return source["Get" .. binding](dataSourceOverride)
	else
		return (dataSourceOverride or source)[binding]
	end
end

---
--- Checks if the value of a property has changed from the actual weapon's value.
---
--- @param self WeaponModProgressLineClass The instance of the WeaponModProgressLineClass.
--- @return boolean True if the value has changed, false otherwise.
---
function WeaponModProgressLineClass:HasValueChanged()
	local weaponModDlg = self:ResolveId("node"):ResolveId("node")
	local binding = self.dataBinding
	local source = self.dataSource
	local value = GetValueFromBinding(source, binding)
	local actualWeapon = weaponModDlg.context.weapon
	local valActual = GetValueFromBinding(source, binding, actualWeapon) or value
	
	return value ~= valActual
end

---
--- Updates the value display and progress bar for a weapon modification property.
---
--- @param self WeaponModProgressLineClass The instance of the WeaponModProgressLineClass.
--- @param anyModified boolean (optional) Whether any modifications have been made to the weapon.
--- @return number The updated value of the property.
---
function WeaponModProgressLineClass:UpdateValue(anyModified)
	local weaponModDlg = self:ResolveId("node"):ResolveId("node")
	local binding = self.dataBinding
	local source = self.dataSource
	local prop_meta = self.metaPropSource
	local value = GetValueFromBinding(source, binding)
	
	local val_base = value
	if self.baseValueOverride then
		val_base = self.baseValueOverride
	elseif prop_meta.modifiable and source["base_" .. prop_meta.id] then -- Modified property
		val_base = source["base_" .. prop_meta.id]
	else -- Complex variable calculated with a function
		local baseTemplate = weaponModDlg.weaponClone and g_Classes[weaponModDlg.weaponClone.class]
		val_base = GetValueFromBinding(source, binding, baseTemplate) or value
	end

	if self:HasValueChanged() or not anyModified then
		self:SetTransparency(0)
	else
		self:SetTransparency(155)
	end
	
	-- special-case heavy weapons' damage
	-- todo: look into if this still works.
	local obj = source
	if IsKindOf(obj, "HeavyWeapon") and prop_meta.id == "Damage" then
		value = obj:GetBaseDamage()
		val_base = obj:GetBaseDamage()
	end

	local scale = prop_meta.scale
	if type(scale) == "string" then
		scale = const.Scale[scale]
	end
	scale = scale or 1

	local ctrl = self		
	local reverse = ctrl:GetReverseBar()
	local text = ctrl:CreatePropValText(value, scale)
	if ctrl:GetPercentValue() then
		text = text .. "%"
	end

	self:ResolveId("idPropVal"):SetText(text)
	
	-- bar
	local max = self:GetMaxProgress()
	value = Clamp(value or 0, 0, max)
	val_base = Clamp(val_base or 0, 0, max)
	
	local progress = self:ResolveId("idProgressbar")
	local progress_base = self:ResolveId("idProgressbarBase")
	local differenceText = self:ResolveId("idDifference")
	progress_base:SetVisible(value ~= val_base)
	if value == val_base then
		progress:SetProgress(value)	
		progress_base:SetProgress(value)	
		progress_base:SetProgressImage("UI/Inventory/weapon_meter.tga")
		progress:SetProgressImage("UI/Inventory/weapon_meter.tga")	
		differenceText:SetText("")
	elseif value < val_base then
		progress:SetProgress(val_base)	
		progress_base:SetProgress(value)	
		progress:SetProgressImage(reverse and "UI/Inventory/weapon_meter_green.tga" or "UI/Inventory/weapon_meter_red.tga")
		progress_base:SetProgressImage("UI/Inventory/weapon_meter.tga")
		differenceText:SetTextStyle(reverse and "WeaponModStatChangeGood" or "WeaponModStatChangeBad")
		differenceText:SetText(T{773757152128, "<numberWithSign(val)>", val = value - val_base})
	elseif value > val_base then
		progress:SetProgress(value)	
		progress_base:SetProgress(val_base)	
		progress:SetProgressImage(reverse and "UI/Inventory/weapon_meter_red.tga" or "UI/Inventory/weapon_meter_green.tga")
		progress_base:SetProgressImage("UI/Inventory/weapon_meter.tga")
		differenceText:SetTextStyle(reverse and "WeaponModStatChangeBad" or "WeaponModStatChangeGood")
		differenceText:SetText(T{773757152128, "<numberWithSign(val)>", val = value - val_base})
	end
	self:Invalidate()
	return value
end

---
--- Formats the additional weapon description for a given context.
---
--- @param ctx table The context containing information about the weapon.
--- @return string The formatted additional weapon description.
---
function TFormat.AdditionalWeaponDescription(ctx)
	local abilities = {}
	if ctx.HandSlot == "OneHanded" then
		abilities[#abilities + 1] = T(889647869376, "One-Handed")
	elseif ctx.HandSlot == "TwoHanded" then
		abilities[#abilities + 1] = T(199744246598, "Two-Handed")
	end
	
	if IsKindOf(ctx, "HeavyWeapon") then
		local combatAction = ctx:GetBaseAttack()
		abilities[#abilities + 1] = CombatActions[combatAction].DisplayName
		return table.concat(abilities, ", ")
	end
	
	for i, ab in ipairs(ctx.AvailableAttacks) do
		abilities[#abilities + 1] = CombatActions[ab].DisplayName
	end
	abilities = table.concat(abilities, ", ")
	return abilities .. "<newline>" .. ctx.AdditionalHint
end

DefineClass.WeaponModToolbarButtonClass = {
	__parents = { "XTextButton" },
	shortcut = false,
	FXMouseIn = "buttonRollover",
	FXPress = "buttonPress",
	Padding = box(8, 0, 8, 0),
	MinHeight = 26,
	MaxHeight = 26,
	MinWidth = 124,
	SqueezeX = true
}

---
--- Opens the container for the WeaponModToolbarButtonClass.
---
--- The container is created using the "XWindow" template and set to use a horizontal list layout, centered horizontally and vertically. The idLabel is set as the parent of the container, and if the button has an associated action, a PDACommonButtonActionShortcut is also added to the container.
---
--- Finally, the XTextButton.Open method is called to open the button.
---
function WeaponModToolbarButtonClass:Open()
	local container = XTemplateSpawn("XWindow", self)
	container:SetLayoutMethod("HList")
	container:SetHAlign("center")
	container:SetVAlign("center")
	self.idLabel:SetParent(container)
	if rawget(self, "action") then
		self.shortcut = XTemplateSpawn("PDACommonButtonActionShortcut", container, self.action)
	end
	XTextButton.Open(self)
end

---
--- Sets the enabled state of the WeaponModToolbarButtonClass and its child elements.
---
--- @param enabled boolean Whether the button should be enabled or disabled.
---
function WeaponModToolbarButtonClass:SetEnabled(enabled)
	XTextButton.SetEnabled(self, enabled)
	self.idLabel:SetEnabled(enabled)
	if self.shortcut then
		self.shortcut:SetEnabled(enabled)
	end	
end

DefineClass.WeaponModPrefabCameraPos = {
	__parents = { "CObject" },
	flags = { efApplyToGrids = false, efCollision = false },
	entity = "City_CinemaProjector"
}

DefineClass.WeaponModCMTPlane = {
	__parents = { "CObject" },
	flags = { efApplyToGrids = false, efCollision = false },
	entity = "CMTPlane",
}

DefineClass.WeaponModChoicePopupClass = {
	__parents = { "XPopup", "XActionsHost" }
}

-- Returns all weapons owned by a specific squad for locally controlled mercs, and optionally
-- the copy of a specific weapon owned by a specific teammate
---
--- Returns all weapons owned by a specific squad for locally controlled mercs, and optionally
--- the copy of a specific weapon owned by a specific teammate.
---
--- @param ownerSquad table The squad whose weapons to retrieve.
--- @param selectedOwner Unit|UnitData|nil The specific teammate whose weapon to retrieve, or nil to get all weapons.
--- @param selectedSlot number The packed position of the weapon to retrieve.
--- @return table, Firearm|false All weapons owned by the squad, and the selected weapon if specified.
---
function GetPlayerWeapons(ownerSquad, selectedOwner, selectedSlot)
	local allWeapons = {}
	local selectedWeapon = false
	for i, teamMate in ipairs((ownerSquad or empty_table).units) do
		local unitData = false
		if IsKindOf(selectedOwner, "Unit") then
			unitData = g_Units[teamMate]
		elseif IsKindOf(selectedOwner, "UnitData") then
			unitData = gv_UnitData[teamMate]
		elseif not selectedOwner then
			unitData = gv_SatelliteView and gv_UnitData[teamMate] or g_Units[teamMate]
		end
		if unitData and unitData:IsLocalPlayerControlled() then
			unitData:ForEachItem("Firearm", function(item, slot)
				allWeapons[#allWeapons + 1] = { weapon = item, slot = unitData:GetItemPackedPos(item), slotName = slot, owner = teamMate }
			end)

			if selectedOwner and teamMate == selectedOwner.session_id then
				selectedWeapon = unitData:GetItemAtPackedPos(selectedSlot)
			end
		end
	end
	
	return allWeapons, selectedWeapon
end

---
--- Opens the Modify Weapon dialog from the player's inventory.
---
--- @param selUnit Unit|nil The selected unit, or nil to use the first unit in the selection.
---
function OpenModifyFromInventory(selUnit)
	if IsInMultiplayerGame() and g_Combat then return end
	local selObj = selUnit or Selection[1]
	if not selObj or not gv_Squads[selObj.Squad] then return end
	local allWeps = GetPlayerWeapons(gv_Squads[selObj.Squad])
	if #allWeps == 0 then return end
	local sessionId = selUnit.session_id
	local first = table.findfirst(allWeps, function(idx, wep) return wep.owner == sessionId end)
	first = first and allWeps[first] or allWeps[1]
	first.owner = gv_SatelliteView and gv_UnitData[first.owner] or g_Units[first.owner]
	OpenDialog("ModifyWeaponDlg", nil, first)
end

---
--- Formats an error message when a weapon modification is blocked by another component.
---
--- @param context table The context in which the error occurred.
--- @param by string The name of the component that is blocking the modification.
--- @return string The formatted error message.
---
function TFormat.BlockedByError(context, by)
	if not by then return end
	local component = WeaponComponents[by]
	if not component then return end
	return T{215167554166, "<error>Can't modify slot, blocked by <compName>.</error>", compName = component.DisplayName}
end

local oldIsolatedFunc = GetIsolatedObjectScreenshotSelection
---
--- Gets the screenshot selection for the Modify Weapon dialog.
---
--- If the Modify Weapon dialog is open, this function returns the weapon model and any lights in the prefab as the objects to include in the screenshot.
--- Otherwise, it calls the original `GetIsolatedObjectScreenshotSelection` function.
---
--- @return table The objects to include in the screenshot.
---
function GetIsolatedObjectScreenshotSelection()
	local dlg = GetDialog("ModifyWeaponDlg")
	if dlg and dlg.idModifyDialog then
		local prefab = dlg.prefab
		local prefabObjs = prefab.objs
		local objectsToShow = {dlg.idModifyDialog.weaponModel}
		for i, obj in ipairs(prefabObjs) do
			if IsKindOf(obj, "Light") then
				objectsToShow[#objectsToShow + 1] = obj
			end
		end
		return objectsToShow
	end
	return oldIsolatedFunc()
end

function OnMsg.PostIsolatedObjectScreenshot()
	StopAllHiding("screenshot")
	ReloadTriggerTargetPairs()
	ResumeAllHiding("screenshot")
	HideCombatUI(false)
	HideInWorldCombatUI(false, "screenshot")
end

function OnMsg.PreIsolatedObjectScreenshot()
	HideCombatUI(true)
	HideInWorldCombatUI(true, "screenshot")
end

MapVar("g_WeaponModificationOpenOnPlayer", {})
MapVar("g_WeaponModificationWeaponLookingAt", {})

---
--- Notifies the game that the Weapon Modification dialog has been spawned for the given player.
---
--- This function updates the `g_WeaponModificationOpenOnPlayer` table to indicate that the Weapon Modification dialog is open for the specified player.
---
--- @param playerId number The ID of the player for whom the Weapon Modification dialog has been spawned.
---
function NetSyncEvents.WeaponModifyDialogSpawn(playerId)
	if not g_WeaponModificationOpenOnPlayer then g_WeaponModificationOpenOnPlayer = {} end
	g_WeaponModificationOpenOnPlayer[playerId] = true
end

---
--- Notifies the game that the Weapon Modification dialog has been closed for the given player.
---
--- This function updates the `g_WeaponModificationOpenOnPlayer` and `g_WeaponModificationWeaponLookingAt` tables to indicate that the Weapon Modification dialog is no longer open for the specified player.
---
--- @param playerId number The ID of the player for whom the Weapon Modification dialog has been closed.
---
function NetSyncEvents.WeaponModifyDialogDespawn(playerId)
	if not g_WeaponModificationOpenOnPlayer then g_WeaponModificationOpenOnPlayer = {} end
	if not g_WeaponModificationWeaponLookingAt then g_WeaponModificationWeaponLookingAt = {} end

	g_WeaponModificationOpenOnPlayer[playerId] = false
	g_WeaponModificationWeaponLookingAt[playerId] = false
	ObjModified("WeaponModificationWeaponLookingChanged")
end

---
--- Notifies the game that a player is looking at a specific weapon in the Weapon Modification dialog.
---
--- This function updates the `g_WeaponModificationWeaponLookingAt` table to indicate that the specified player is looking at the given weapon in the Weapon Modification dialog. It also stores the current real-time timestamp for this event.
---
--- @param playerId number The ID of the player who is looking at the weapon.
--- @param weaponId number The ID of the weapon the player is looking at.
---
function NetSyncEvents.WeaponModifyLookingAtWeapon(playerId, weaponId)
	if not g_WeaponModificationWeaponLookingAt then g_WeaponModificationWeaponLookingAt = {} end

	g_WeaponModificationWeaponLookingAt[playerId] = weaponId
	g_WeaponModificationWeaponLookingAt[tostring(playerId) .. "time"] = RealTime()
	ObjModified("WeaponModificationWeaponLookingChanged")
end

---
--- Checks if another player is currently looking at the same weapon as the player in the Weapon Modification dialog.
---
--- This function retrieves the weapon ID that the player is currently looking at in the Weapon Modification dialog, and compares it to the weapon ID that the other player is looking at. If the other player is looking at the same weapon, and their timestamp is older than the player's timestamp, this function returns `true`. Otherwise, it returns `false`.
---
--- @return boolean true if another player is looking at the same weapon, false otherwise
---
function OtherPlayerLookingAtSameWeapon()
	local modifyDlg = GetDialog("ModifyWeaponDlg")
	modifyDlg = modifyDlg and modifyDlg.idModifyDialog
	if not modifyDlg then return end
	if not g_WeaponModificationWeaponLookingAt then return end
	if not IsCoOpGame() then return end
	
	local weaponId = modifyDlg.selectedWeaponItemId
	local otherPlayerId = GetOtherPlayerId()
	local otherPlayerWeapon = g_WeaponModificationWeaponLookingAt[otherPlayerId]
	
	-- Looking at same weapon
	if otherPlayerWeapon and otherPlayerWeapon == weaponId then
		local time = g_WeaponModificationWeaponLookingAt[netUniqueId .. "time"]
		local otherPlayerTime = g_WeaponModificationWeaponLookingAt[otherPlayerId .. "time"]
		if otherPlayerTime < time then return true end
	end
	
	return false
end

function OnMsg.NetPlayerLeft(player)
	local playerId = player and player.id
	if not playerId then return end
	NetSyncEvents.WeaponModifyDialogDespawn(playerId)
end

---
--- Closes the Weapon Modification dialog and waits for all players to close their dialogs.
---
--- This function first closes the Weapon Modification dialog and the Fullscreen Game Dialogs. It then waits for all players to close their Weapon Modification dialogs before returning. This ensures that the game state is properly synchronized across all players in a co-op game.
---
--- The function also waits a short time after closing the dialogs to allow the camera to adjust, preventing potential visual glitches.
---
--- @return nil
---
function CloseWeaponModificationCoOpAware()
	assert(CanYield())

	local inventoryUI = GetDialog("FullscreenGameDialogs")
	if inventoryUI then
		inventoryUI:Close()
	end

	local weaponModification = GetDialog("ModifyWeaponDlg")
	if weaponModification then
		weaponModification:Close()
	end

	local anyOpen = true
	while anyOpen do
		anyOpen = false
		for playerId, isOpen in sorted_pairs(g_WeaponModificationOpenOnPlayer) do
			local playerIsHere = table.find(netGamePlayers, "id", playerId)
			if isOpen and playerIsHere then
				anyOpen = true
			end
		end
		if not anyOpen then break end
		Sleep(100)
	end
	
	-- Wait for camera to adjust a bit, prevents weird flickers
	-- time is not random, it's roughly the default camera interpolations that happen at combat start
	Sleep(default_interpolation_time + 50)
end

function OnMsg.CanSaveGameQuery(query)
	if GetDialog("ModifyWeaponDlg") then
		query.modify_weapon_dialog = true
	end
end

---
--- Gets the icon for a weapon component.
---
--- @param item table The weapon component item.
--- @param weapon table The weapon the component is for.
--- @return string The icon for the weapon component.
---
function GetWeaponComponentIcon(item, weapon)
	local icon = item.Icon
	
	for _, descr in ipairs(item.Visuals) do
		if descr:Match(weapon.class) and #(descr.Icon or "") > 0 then
			icon = descr.Icon
		end
	end
	return icon
end