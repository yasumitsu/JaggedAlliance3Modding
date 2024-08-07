DefineClass.CrosshairUI = {
	__parents = { "XContextWindow" },
	attachPos = false,
	attachSpotIdx = false,
	cachedScreenPos = false,
	reconModeLastAnchor = false,
	
	update_targets = false,
	show_data_for_action = false,
	cached_results = false,
		
	defaultTargetPart = false,
	targetPart = false,
	
	aim = 0,
	maxAimTotal = 0,
	maxAimPossible = 0,
	minAimPossible = 0,
	
	mouseIn = false,
	dynamic = false,
	time_dilation = false,

	-- UI stuff
	darkness_tutorial = false, -- used to track whether to show the darkness tutorial
	aim_tutorial_shown_already = false, -- used to track whether the aim tutorial was shown this crosshair opening
	attack_cursor = false, -- caches the crosshair cursor to be querried by various places instead of recalculating
	selected_part_target_mouseover = false, -- whether the selected part is currently selected because the target is mouseovered

	crosshair_gamepad_list = "body_parts",

	-- Test
	update_targets = true
}

--- Initializes the CrosshairUI class.
-- This function sets up the default body part for the crosshair UI, and updates the aim information.
-- The default body part is determined by looking up the g_DefaultShotBodyPart value in the context.body_parts table, or using the first body part if the default is not found.
-- The targetPart field is also set to the default body part.
-- The UpdateAim function is called to update the aim-related fields of the CrosshairUI instance.
function CrosshairUI:Init()
	-- We need to assign the default body part because the body part UI spawns as it will
	-- try to read information provided by UpdateAim
	local defaultBodyPart = table.find_value(self.context.body_parts, "id", g_DefaultShotBodyPart) or self.context.body_parts[1]
	self.defaultTargetPart = defaultBodyPart
	assert(defaultBodyPart)
	
	self.targetPart = defaultBodyPart
	self:UpdateAim()
end

---
--- Opens the CrosshairUI and performs various setup and initialization tasks.
---
--- This function is responsible for the following:
--- - Setting the selected part to the current target part
--- - Updating the aim information
--- - Hiding the target's UI badge if it exists
--- - Setting the AP indicator to false for "attack"
--- - Opening the XContextWindow
--- - Waiting for the CrosshairUI to become visible before setting focus on the selected body part button
--- - Creating a thread to handle gamepad control for navigating the body part buttons
---
--- @param ... any additional arguments passed to the Open function
function CrosshairUI:Open(...)
	if not self.context then return end -- Closed in Init/UpdateAim

	-- We can set the default part as the selected now that the UI has spawned.
	self:SetSelectedPart(self.targetPart)
	self:UpdateAim()
	
	local target = self.context.target
	self:UpdateBadgeHiding()
	if target and rawget(target, "ui_badge") then
		target.ui_badge:SetVisible(false)
	end
	
	SetAPIndicator(false, "attack")
	XContextWindow.Open(self, ...)
	-- We need to wait for visible to become true as the SetFocus from SetSelectedPart
	-- will go through while IsVisible is still false due to the crosshair wait
	self:CreateThread("wait-visible", function()
		while true do
			Sleep(200)
			if self.visible and not self:GetThread("actionCameraWait") then

				for _, child in ipairs(self.idButtonsContainer) do
					if rawget(child, "selected") then
						child:SetFocus()
						return
					end
				end
				
				break
			end
		end
	end)
	
	self:CreateThread("gamepad-control", function()
		local boxes = false
		local upDownAxis = point(0, 4096)
		local bodyPartBoxes = {}
		while true do
			WaitFramesOrSleepAtLeast(1, 33)
			if not GetUIStyleGamepad() then goto continue end
			
			local state = GetActiveGamepadState()
			if not state then goto continue end
			local gamePadStick = state.LeftThumb
			if gamePadStick == point20 then goto continue end
			gamePadStick = gamePadStick:SetY(-gamePadStick:y())
			gamePadStick = Normalize(gamePadStick)

			local centerOnBox = self.idTarget and self.idTarget.box
			centerOnBox = centerOnBox and centerOnBox:Center()
			
			table.clear(bodyPartBoxes)
			local bodyPartButtons = self.idButtonsContainer
			for i, bodyPartButt in ipairs(bodyPartButtons) do
				if bodyPartButt.visible then
					bodyPartBoxes[#bodyPartBoxes + 1] = bodyPartButt.box
					bodyPartBoxes["id" .. #bodyPartBoxes] = bodyPartButt.context 
				end
			end
			
			local highestDot, highestDotSel = false, false
			for choiceIdx, box in ipairs(bodyPartBoxes) do
				local vecTowardsBox = box:Center() - centerOnBox
				vecTowardsBox = Normalize(vecTowardsBox)
				local dot = Dot(gamePadStick, vecTowardsBox) / 4096
				if (not highestDot or dot > highestDot) and dot > 0 then
					highestDot = dot
					highestDotSel = bodyPartBoxes["id" .. choiceIdx]
				end
			end
			
			-- Check if closer to up/down
			if highestDot then
				local dotUp = Dot(gamePadStick, upDownAxis) / 4096
				if dotUp > highestDot and dotUp > 0 then
					highestDot = dotUp
					highestDotSel = false
				end
				
				local dotDown = Dot(gamePadStick, -upDownAxis) / 4096
				if dotDown > highestDot and dotDown > 0 then
					highestDot = dotDown
					highestDotSel = false
				end
			end
			
			if highestDotSel then
				self:SetSelectedPart(highestDotSel)
			end
			
			::continue::
		end
	end)
end

--- Handles the layout and interaction box for the CrosshairUI.
---
--- This function is called when the layout of the CrosshairUI is complete.
--- It sets the interaction box for the UI, and handles the VR voice response
--- based on the attack results and target information.
---
--- @param self CrosshairUI The CrosshairUI instance.
function CrosshairUI:OnLayoutComplete()
	if not self.dynamic then
		self:SetInteractionBox(self.box:minx(), self.box:miny(), point(1000, 1000), true)
	end
	local target = self.context.target
	local playVr = IsKindOf(self.parent, "IModeCombatAttack")
	if playVr and not target:IsPlayerAlly() and (not IsKindOf(target, "Unit") or not target:IsCivilian()) then
		-- Get attack results from crosshair to determine whether to play VR
		local attackResult = self and self.cached_results
		attackResult = attackResult and attackResult[self.context.action.id]
		
		local one_non_obstructed = false
		local bestChance = 0
		local worstChance = max_int
		local attackResultCalc = attackResult and attackResult.attackResultCalc
		local is_blind_fire = attackResultCalc and not not attackResultCalc.BlindFire
		for id, bodyPartData in pairs(attackResultCalc) do
			bestChance = Max(bestChance, bodyPartData.chance_to_hit)
			worstChance = Min(worstChance, bodyPartData.chance_to_hit)
			one_non_obstructed = one_non_obstructed or not bodyPartData.obstructed
		end
		
		local torsoAttackResult = attackResult and attackResult.attackResultCalc
		torsoAttackResult = torsoAttackResult and torsoAttackResult.Torso
		local torso_stealth_kill = torsoAttackResult and torsoAttackResult.stealth_attack
		local attacker = self.context.attacker
		local is_hidden = attacker:HasStatusEffect("Hidden") or torso_stealth_kill
		if not one_non_obstructed or is_blind_fire or bestChance <= 20 then
			PlayVoiceResponse(attacker, is_hidden and "AimAttack_LowStealth" or "AimAttack_Low")
		elseif bestChance > 20 then
			PlayVoiceResponse(attacker, is_hidden and "AimAttackStealth" or "AimAttack")
		end
	end	
end

--- Handles the cleanup and cleanup-related events when the CrosshairUI is deleted.
---
--- This function is called when the CrosshairUI is about to be deleted. It performs the following actions:
--- - Sends a "Aim" net sync event with the attacker context
--- - Restores the visibility of the UI badge on the target
--- - Clears the damage prediction
--- - Updates the badge hiding state
--- - Stops the camera from following the target if the CrosshairUI was dynamic
--- - Restores the default time factor if time dilation was applied
--- - Sets the target to false on the parent dialog if it exists and the window is not being destroyed due to confirmation or target change
--- - Calls the base class OnDelete function
---
--- @param self CrosshairUI The CrosshairUI instance.
--- @param reason string The reason for the deletion (e.g. "confirm-exploration", "target-change").
function CrosshairUI:OnDelete(reason)
	if self.context.attacker then
		NetSyncEvent("Aim", self.context.attacker)
	end
	if self.context.target then
		local badge = rawget(self.context.target, "ui_badge")
		if badge then badge:SetVisible(true) end
	end
	ClearDamagePrediction()
	self:UpdateBadgeHiding(true)
	
	if self.dynamic then
		cameraTac.SetFollowTarget(false)
	end
	if self.time_dilation then
		SetTimeFactor(const.DefaultTimeFactor)
	end
	
	local dlg = GetDialog(self)
	if dlg and dlg.target and dlg.window_state ~= "destroying" and reason ~= "confirm-exploration" and reason ~= "target-change" then
		dlg:SetTarget(false, true)
	end
	
	XContextWindow.OnDelete(self, reason)
end

--- Sets the interaction box for the CrosshairUI window and its child elements.
---
--- This function is responsible for setting the interaction box for the CrosshairUI window and its child elements, such as the buttons container and the firing mode container. It ensures that the interaction box encompasses the furthest elements in each container, allowing for proper interaction detection.
---
--- @param self CrosshairUI The CrosshairUI instance.
--- @param x number The x-coordinate of the interaction box.
--- @param y number The y-coordinate of the interaction box.
--- @param scale number The scale factor of the interaction box.
--- @param children table A table of child elements to include in the interaction box.
function CrosshairUI:SetInteractionBox(x, y, scale, children)
	XWindow.SetInteractionBox(self, x, y, scale, children)

	-- Fix interaction box in buttons container
	local treeWalk = self.idButtonsContainer
	if not treeWalk then return end -- Destroyed
	
	local furthestButton = self:ResolveId("idButtonTorso") or treeWalk[1]
	local furthestB = furthestButton and furthestButton.interaction_box
	if furthestB then 
		while true do
			local b = treeWalk.interaction_box
			if not b then break end
			treeWalk.interaction_box = AddRects(b, furthestB)
			if treeWalk == self then
				break
			end
			treeWalk = treeWalk.parent
		end
	end
	
	-- Fix interaction box in firing mode container
	treeWalk = self.idFireModeContainer
	if treeWalk then
		local furthestLeftButton, furthestBX = false, false
		for i, but in ipairs(treeWalk) do
			local b = but.interaction_box
			if b then
				if not furthestBX or b:minx() < furthestBX then
					furthestBX = b:minx()
					furthestLeftButton = b
				end
			end
		end
		if furthestLeftButton then
			while true do
				local b = treeWalk.interaction_box
				if not b then break end
				treeWalk.interaction_box = AddRects(b, furthestLeftButton)
				if treeWalk == self then
					break
				end
				treeWalk = treeWalk.parent
			end
		end
	end
end

--- Initiates an attack action for the current crosshair context.
---
--- This function checks if the current attacker can perform the attack action, and if so, it initiates the attack.
--- It handles various cases such as blindfire, cover, and not enough action points.
--- The function also updates the time dilation and darkness tutorial state if necessary.
---
--- @param self CrosshairUI The CrosshairUI instance.
function CrosshairUI:Attack()
	local selfContext = self.context
	local attacker = selfContext.attacker
	local action = selfContext.action
	local weapon = action:GetAttackWeapons(attacker)
	local target = selfContext.target
	local gotoPos = selfContext.meleeTargetPos
	local aim = self.aim

	if not IsValid(target) then
		return
	end

	if not IsKindOf(attacker, "Unit") or not attacker:CanBeControlled() or not weapon then
		return
	end
	
	-- Check if another action is ongoing
	if CombatActionCannotBeStarted(action.id, attacker) then
		return
	end
	
	-- Only units support the actual body part arg, see :UpdateAim for more info
	local bodyPartArg = ""
	if IsKindOf(target, "Unit") then
		bodyPartArg = self.targetPart.id
		
		-- If blindfire body part choose a random body part out of 
		-- the ones you have lof to. (188159)
		if bodyPartArg == "BlindFire" then
			local cachedResults = self.cached_results
			cachedResults = cachedResults[action.id]
			cachedResults = cachedResults.attackResultCalc
			
			local validOptions = {}
			for partName, partData in sorted_pairs(cachedResults) do
				if partName ~= "BlindFire" and partData.target_hit then
					validOptions[#validOptions + 1] = partName
				end
			end
			if #validOptions == 0 then validOptions[#validOptions + 1] = g_DefaultShotBodyPart end
			bodyPartArg = table.rand(validOptions)
		-- InCover body part selects the body part with highest cth (191329)
		elseif bodyPartArg == "InCover" then
			local cachedResults = self.cached_results
			cachedResults = cachedResults[action.id]
			cachedResults = cachedResults.attackResultCalc
			cachedResults = cachedResults and cachedResults["InCover"]
			
			local bodyPartId = cachedResults and cachedResults.actual_body_part
			if not bodyPartId then bodyPartId = g_DefaultShotBodyPart end
			bodyPartArg = bodyPartId
		end
	end

	local dialog = GetInGameInterfaceModeDlg()
	local args = {
		target = target,
		goto_pos = dialog.args_gotopos and gotoPos,
		target_spot_group = bodyPartArg,
		aim = aim
	}
	local shoot_ap = action:GetAPCost(attacker, args)
	if not attacker:UIHasAP(shoot_ap, action.id, args) then
		CombatLog("debug", T{Untranslated("Not enough action points"), attacker})
		return
	end

	local can_attack, reason = attacker:CanAttack(target, weapon, action, aim, gotoPos, nil, selfContext.free_aim)
	if not can_attack then
		CombatLog("debug", T{Untranslated("<error><reason></error>"), reason = reason})
		return
	end
	
	if dialog.args_gotopos then
		assert(gotoPos)
	end
	
	if self.time_dilation then
		SetTimeFactor(const.DefaultTimeFactor)
		self.time_dilation = false
	end
	
	if self.darkness_tutorial then
		self.darkness_tutorial = false
		TutorialHintsState.InDarkness = true
	end

	args.action_override = action
	dialog.action_params = args
	local dbgData = table.copy(args)
	local retVal = dialog:Confirm("crosshair")
	if retVal ~= "break" then
		dbgData.action_override = dbgData.action_override.id
		dbgData.target = dbgData.target.session_id
		dbgData.response = tostring(retVal)
		print(dbgData)
		CombatLog("debug", TableToLuaCode(dbgData))
		assert(not "For some reason the attack didn't go through.")
	end
	self:SetVisible(false)
end

---
--- Deletes the CrosshairUI window and updates the TutorialHintsState.
---
--- @param ... any
function CrosshairUI:delete(...)
	TutorialHintsState.WeaponRange = TutorialHintsState.WeaponRangeShown and true
	self.window_state = "pre-destroying"
	XWindow.delete(self, ...)
end

---
--- Sets the selected part of the crosshair UI.
---
--- @param part table|boolean The part to select, or `false` to deselect.
---
function CrosshairUI:SetSelectedPart(part)
	-- Catch rollover false on destroy. Since the crosshair closes after a unit state change we
	-- need to prevent the crosshair from calling functions that would use the old state.
	if self.window_state == "destroying" or self.window_state == "pre-destroying" then return end

	self.selected_part_target_mouseover = false

	if not part or not self.context.canTarget then
		self.targetPart = self.defaultTargetPart
	else
		self.targetPart = part
	end

	local target = self.context.target
	local attacker = self.context.attacker
	local action = self.show_data_for_action or self.context.action
	local goto_pos = self.context.meleeTargetPos
	if not goto_pos or goto_pos == attacker:GetPos() then
		NetSyncEvent("Aim", self.context.attacker, action.id, self.context.target, self.targetPart.id)
	end

	local attackResult = self.context.attackResultTable
	if attackResult and attackResult[self.targetPart.id] then
		attackResult = attackResult[self.targetPart.id]
		ApplyDamagePrediction(attacker, action, {
			target = target,
			target_spot_group = self.targetPart.id,
			multishot = attackResult and attackResult.crosshair_attack_args.multishot or nil,
			num_shots = attackResult and attackResult.crosshair_attack_args.num_shots or nil,
		}, attackResult)
	end

	self:UpdateBadgeHiding()

	local context = self.context

	-- Find which button is this part.
	local selectedButton = false
	for _, child in ipairs(self.idButtonsContainer) do
		child:SetSelected(false)

		local selected = part and child.context.id == part.id
		if selected then
			selectedButton = child
			child:SetSelected(true)
			child:SetFocus()
		end
		rawset(child, "selected", selected)

--[[		local desaturation = 0
		local apCost = action:GetAPCost(attacker, { target = target, goto_pos = goto_pos, aim = self.aim, target_spot_group = part and part.id })
		if not attacker:UIHasAP(apCost) then
			desaturation = 255
		end]]
	end
	
	if self.crosshair_gamepad_list ~= "body_parts" then
		self.crosshair_gamepad_list = "body_parts"
		ObjModified("GamepadUIStyleChanged")
	end
end

---
--- Handles the rollover state of the CrosshairUI.
---
--- When the mouse enters the UI, `self.mouseIn` is set to `true`. When the mouse leaves the UI, `self.mouseIn` is set to `false` and the selected part is cleared.
---
--- This function is called when the rollover state of the UI changes.
---
--- @param rollover boolean|nil The new rollover state. If `nil`, the rollover state is determined by the current gamepad UI style.
function CrosshairUI:OnSetRollover(rollover)
	rollover = rollover or GetUIStyleGamepad()
	self.mouseIn = rollover
	if not rollover then self:SetSelectedPart(false, true) end
	ObjModified("crosshair")
	XContextWindow.OnSetRollover(self, rollover)
end

---
--- Handles the mouse position events for the CrosshairUI.
---
--- When the mouse enters the UI, the selected part is set to the default target part. When the mouse leaves the UI, the selected part is cleared.
---
--- This function is called when the mouse position changes within the UI.
---
--- @param pt table The current mouse position.
function CrosshairUI:OnMousePos(pt)
	local igi = self.parent
	local mouseTarget = self.desktop.last_mouse_target
	local mouseInMyUI = not mouseTarget or (mouseTarget ~= self and mouseTarget:IsWithin(self))
	if igi and igi.potential_target == self.context.target and not mouseInMyUI then
		self:SetSelectedPart(self.defaultTargetPart)
		self.selected_part_target_mouseover = true
	elseif self.selected_part_target_mouseover then
		self:SetSelectedPart(false)
	end
end

---
--- Handles the mouse button down event for the CrosshairUI.
---
--- When the left mouse button is clicked, this function is called. Currently, it is commented out and does not perform any action.
---
--- @param pos table The current mouse position.
--- @param button string The mouse button that was pressed.
function CrosshairUI:OnMouseButtonDown(pos, button)
	if button == "L" then
		--self:Attack()
		--return "break"
	end
end

---
--- Updates the aim level of the CrosshairUI.
---
--- This function is responsible for calculating the chance to hit (CTH) and attack results for the current aim level. It caches the results to avoid redundant calculations.
---
--- The function also handles special cases such as blind fire, cover, and darkness, adjusting the CTH and attack results accordingly.
---
--- The function updates the UI elements to display the calculated CTH and other relevant information.
---
--- @param self CrosshairUI The CrosshairUI instance.
function CrosshairUI:UpdateAim()
	local pContext = self.context
	if not pContext then
		return
	end
	
	local attacker = pContext.attacker
	local action = self.show_data_for_action or pContext.action
	local target = pContext.target

	if not IsValid(target) or not action then
		return
	end

	local args = {
		target = target,
		goto_pos = pContext.meleeTargetPos,
		target_spot_group = self.targetPart.id,
		step_pos = pContext.override_pos,
		cth_breakdown = true,
		damage_breakdown = true,
		free_aim = pContext.free_aim
	}
	if not self.context.noAim then
		self.aim = self.aim or 0
		args.aim = self.aim
		
		-- make sure the attacker has the AP for the aiming
		while self.aim > 0 and action:GetUIState({ attacker }, args) ~= "enabled" do
			self.aim = self.aim - 1
			args.aim = self.aim
		end
	end
	
	-- Action can no longer be used.
	if action:GetUIState({ attacker }, args) ~= "enabled" then
		if not attacker.move_attack_in_progress then
			SetInGameInterfaceMode(g_Combat and "IModeCombatMovement" or "IModeExploration")
		end
		return
	end

	local attackResultTable = {}
	local cthTable = {}
	local critChance = 0
	
	-- Gather information from attack results, to display.
	if not self.cached_results then self.cached_results = {} end
	
	local cached_results = self.cached_results[action.id]
	local invalidCache = not cached_results or
									cached_results.aim ~= self.aim or
									cached_results.ap ~= attacker.ActionPoints or
									cached_results.free_move_ap ~= attacker.free_move_ap
									
		
	if invalidCache then
		local cthCalc, attackResultCalc = {}, {}
		local crit = 0
		
		-- Check for spotter unit, shows a specific icon and rollover
		local spotter = false
		for _, u in ipairs(attacker.team.units) do  
			if u ~= attacker and VisibilityCheckAll(u, target, nil, const.uvVisible) then
				spotter = u
			end
		end
		
		local spotterCth, noLoSCth, grazingProtected = false, false, false -- needed for ui
		local inDarkness = false -- needed for tutorials
		
		-- Non-unit targets (such as traps) need to provide an empty string as the target_spot_group (due to lof internal logic)
		local queryBodyParts = IsKindOf(target, "Unit") 
		for i, p in ipairs(pContext.body_parts) do
			local partId = p.id
			args.target_spot_group = queryBodyParts and partId or ""
			local results, attack_args = action:GetActionResults(attacker, args)
			cthCalc[partId] = results.chance_to_hit
			results.crosshair_attack_args = attack_args
			attackResultCalc[partId] = results
			
			-- skip calling ResolveAttackParams for every body part
			if results.lof then
				args.lof = results.lof
			end
			
			spotterCth = spotterCth or table.find(results.chance_to_hit_modifiers, "id", "SeenBySpotter")
			noLoSCth = noLoSCth or table.find(results.chance_to_hit_modifiers, "id", "NoLineOfSight")
			inDarkness = inDarkness or table.find(results.chance_to_hit_modifiers, "id", "Darkness")

			results.cantSeeBodyPart = false
			results.spotter = false -- no longer per body part but leaving this here for clarity
			
			local hitOnTarget = table.find_value(results, "obj", target)
			if hitOnTarget and hitOnTarget.grazing then
				results.grazing = true
				results.crit_chance = 0
				if hitOnTarget.grazing_reason == "cover" then
					grazingProtected = true
				end
			end
			
			if results and results.crit_chance then
				crit = results.crit_chance
			end
			
			local damage = 0
			for i, hit in ipairs(results) do
				if hit.obj == target then
					damage = damage + hit.damage + (hit.armor_prevented or 0)
				end
			end
			
			local aoeDamage = 0
			for i, hit in ipairs(results.area_hits) do
				if hit.obj == target then
					aoeDamage = aoeDamage + hit.damage + (hit.armor_prevented or 0)
				end
			end
			results.calculated_target_damage = damage
			results.calculated_target_aoeDamage = aoeDamage
		end

		if noLoSCth or spotterCth then
			local defaultPartId = self.defaultTargetPart.id
			cthCalc["BlindFire"] = cthCalc[defaultPartId]
			local attackResultCopy = table.copy(attackResultCalc[defaultPartId])
			attackResultCopy.cantSeeBodyPart = true
			attackResultCopy.spotter = spotterCth and spotter
			attackResultCalc["BlindFire"] = attackResultCopy
			
			-- Overwrite some of the torso data so it's more ambigious which
			-- part you're hitting
			attackResultCopy.chance_to_hit_modifiers = {
				{
					id = "Unknown",
					value = 0 ,
					name = T(553504408105, "Unknown Modifiers"),
				}
			}
			
			-- For debug functionality display the highest cth bodypart
			if CthVisible() then
				local highestCth = 0
				local highestCthPart = false
				for partName, partData in pairs(attackResultCalc) do
					local cth = partData.chance_to_hit
					if not highestCthPart or cth > highestCth then
						highestCthPart = partData
						highestCth = highestCth
					end
				end
				attackResultCopy.chance_to_hit_modifiers = highestCthPart.chance_to_hit_modifiers
				attackResultCopy.chance_to_hit = highestCthPart.chance_to_hit
				cthCalc["BlindFire"] = highestCthPart.chance_to_hit
			end
			
			local noneOfPartsHit = true
			for partName, partData in pairs(attackResultCalc) do
				if partData.target_hit then
					noneOfPartsHit = false
					break
				end
			end
			if not noneOfPartsHit then
				attackResultCopy.target_hit = true
			end
			
			self.targetPart = Presets.TargetBodyPart.Default.BlindFire
		elseif target:HasStatusEffect("Protected") and grazingProtected then
			local highestCth = 0
			local highestCthPart, highestCthId = false, false
			for partName, partData in pairs(attackResultCalc) do
				local cth = partData.chance_to_hit
				if not highestCthPart or cth > highestCth then
					highestCthPart = partData
					highestCth = highestCth
					highestCthId = partName
				end
			end
		
			-- InCover body part selects the body part with highest cth (191329)
			local attackResultCopy = table.copy(highestCthPart)
			attackResultCopy.actual_body_part = highestCthId			
			attackResultCopy.bodyPartDisplayName = Presets.TargetBodyPart.Default[highestCthId].display_name
			cthCalc["InCover"] = cthCalc[highestCthId]
			attackResultCalc["InCover"] = attackResultCopy
			
			self.targetPart = Presets.TargetBodyPart.Default.InCover
		elseif self.targetPart == Presets.TargetBodyPart.Default.BlindFire or
				 self.targetPart == Presets.TargetBodyPart.Default.InCover then -- No longer valid fake bodypart
			self.targetPart = g_DefaultShotBodyPart
		end
		
		self.cached_results[action.id] = {
			cthCalc = cthCalc,
			attackResultCalc = attackResultCalc,
			crit = crit,
			aim = self.aim,
			ap = attacker.ActionPoints,
			free_move_ap = attacker.free_move_ap,
		}
		
		if inDarkness and not TutorialHintsState.InDarkness then
			self.darkness_tutorial = true
		end

		local target_dummy
		local lof_data = args.lof and args.lof[1]
		local atk_results = attackResultCalc[args.target_spot_group or false]
		if lof_data then
			target_dummy = {
				obj = lof_data.obj,
				anim = lof_data.anim,
				phase = 0,
				pos = lof_data.step_pos,
				angle = lof_data.angle,
				stance = lof_data.stance,
			}
		elseif args.goto_pos and attacker:GetDist(args.goto_pos) > const.SlabSizeX / 2 then
			target_dummy = {
				obj = attacker,
				pos = args.goto_pos,
			}
		elseif atk_results and atk_results.step_pos then
			target_dummy = { 
				obj = attacker, 
				pos = atk_results.step_pos, 
			}
		end
		self.context.danger = AnyAttackInterrupt(attacker, target, action, target_dummy)
		if not self.context.danger and args.goto_pos then
			local combatPath = GetMeleeAttackCombatPath(action, attacker)
			local targetPath = combatPath and combatPath:GetCombatPathFromPos(args.goto_pos)
			if targetPath then
				self.context.danger = AnyInterruptsAlongPath(attacker, targetPath, "all", action)
			end
		end
	end

	assert(self.cached_results[action.id])
	local cachedRe = self.cached_results[action.id]
	cthTable = cachedRe.cthCalc
	attackResultTable = cachedRe.attackResultCalc
	critChance  = cachedRe.crit
	
	-- Write data to context
	if not action.AlwaysHits then
		pContext.cth = cthTable
	else
		pContext.cth = {}
	end
	pContext.attackResultTable = attackResultTable
	
	local actualAction = pContext.action -- Dont use "show_for_action" for these calculations
	local distToTarget = attacker:GetDist(target)
	pContext.attack_distance = DivCeil(distToTarget, const.SlabSizeX)
	
	local weapon1, _ = actualAction:GetAttackWeapons(attacker)
	pContext.weapon_range = actualAction:GetMaxAimRange(attacker, weapon1) or weapon1.WeaponRange
	assert(pContext.weapon_range)
	pContext.weapon_range = pContext.weapon_range or 0

	local dialog = GetInGameInterfaceModeDlg()
	self.attack_cursor = GetRangeBasedMouseCursor(dialog.penalty, actualAction, "attack")

	local bodyPartsUI = self:ResolveId("idButtonsContainer")
	for i, p in ipairs(bodyPartsUI) do
		local cth = CthVisible() and cthTable[p.context.id]
		if cth then
			p.idHitChance:SetText(T{483116174778, "<percent(cth)>", cth = cth})
		else
			p.idHitChance:SetVisible(false)
		end
	end
	ObjModified("crosshair")
	ObjModified("firing_mode")
	ObjModified(pContext)
	
	args.target_spot_group = self.targetPart.id -- restore potentially changed argument by the loop above
	if RolloverWin then
		RolloverWin:UpdateRolloverContent()
	end
	--self:SetScaleModifier(GetUIStyleGamepad() and point(1150, 1150) or point(1000, 1000))
	
	if self.idAPCostText then
		args.ap_cost_breakdown = {}
		local apCost = action:GetAPCost(attacker, args)	
		local free_move_ap_used = Min(args.ap_cost_breakdown.move_cost or 0, attacker.free_move_ap)
		apCost = apCost - Max(0, free_move_ap_used)
		-- round the cost to match before/after AP readings
		local unitAp = attacker:GetUIActionPoints()
		local before = unitAp / const.Scale.AP
		local after = (unitAp - apCost) / const.Scale.AP -- free move is already accounted for in apCost
		apCost = (before - after) * const.Scale.AP
		
		--local has_movement = action.AimType == "melee"
		--local apCost, unitAp = attacker:GetUIAdjustedActionCost(cost, has_movement)
		--apCost, unitAp = apCost * const.Scale.AP, unitAp * const.Scale.AP
		if g_Combat then
			self.idAPCostText:SetText(
				T{444327862984, "<apn(apCost)><style CrosshairAPTotal><valign bottom -2>/<apn(unitAp)> AP</style>", apCost = apCost, unitAp = unitAp}
			)
		else
			self.idAPCostText:SetText(T{235238255759, "<apn(apCost)><style CrosshairAPTotal><valign bottom -2> AP</style>", apCost = apCost})
		end
		if self.aim ~= 0 then
			self.idAPCostText:SetTextStyle("CrosshairAPCostYellow")
		else
			self.idAPCostText:SetTextStyle("CrosshairAPCost")
		end
	end
	
	WeaponRangeTutorial(self)
	ShowCrosshairTutorial(self)
end

---
--- Returns the previous aim level for the crosshair.
---
--- If the current aim level is the minimum, this function will return the maximum aim level.
---
--- @return integer The previous aim level
function CrosshairUI:GetPrevAimLevel()
	local aim = self.aim
	if not aim then return 0 end
	
	aim = aim - 1
	if aim < self.minAimPossible then
		aim = self.maxAimPossible
	end
	return aim
end

---
--- Returns the next aim level for the crosshair.
---
--- If the current aim level is the maximum, this function will return the minimum aim level.
---
--- @return integer The next aim level
function CrosshairUI:GetNextAimLevel()
	local aim = self.aim
	if not aim then return 0 end
	
	aim = aim + 1
	if aim > self.maxAimPossible then
		aim = self.minAimPossible
	end
	return aim
end

---
--- Toggles the aim level of the crosshair.
---
--- If `previous` is true, the previous aim level is set. Otherwise, the next aim level is set.
---
--- If the crosshair is not visible or aiming is disabled, this function does nothing.
---
--- @param previous boolean Whether to set the previous aim level
function CrosshairUI:ToggleAim(previous)
	if not self.visible or self.context.noAim then return end
	self.aim = previous and self:GetPrevAimLevel() or self:GetNextAimLevel()
	self:UpdateAim()
	PlayFX("SightAim")
	self:InvalidateLayout()
end

---
--- Checks if a point is within the interaction box of the CrosshairUI.
---
--- @param pt table The point to check, in the format `{x = x, y = y}`.
--- @return boolean True if the point is within the interaction box, false otherwise.
function CrosshairUI:PointInWindow(pt)
	local box = self.interaction_box
	if not box then return false end
	return pt.InBox(pt, box)
end

---
--- Returns the screen box for the CrosshairUI.
---
--- If the CrosshairUI is dynamic, this function returns the `interaction_box` property.
--- Otherwise, it returns the `box` property.
---
--- @return table The screen box for the CrosshairUI, in the format `{x = x, y = y, w = width, h = height}`.
function CrosshairUI:GetScreenBox()
	if self.dynamic then return self.interaction_box end
	return self.box
end

local function lEnsureBadgeIsHidden()
	local igi = GetInGameInterfaceModeDlg()
	if IsKindOf(igi, "IModeCombatAttackBase") and igi.crosshair and igi.crosshair.window_state ~= "destroying" then
		igi.crosshair:UpdateBadgeHiding()
	end
end

OnMsg.CombatApplyVisibility = lEnsureBadgeIsHidden
OnMsg.BadgeVisibilityUpdated = lEnsureBadgeIsHidden

---
--- Updates the visibility of badges based on the current state of the crosshair.
---
--- In action camera mode, all badges are hidden. Otherwise, badges are hidden for units that won't get hit and the target.
---
--- Special logic is applied for allies in the line of fire, where their combat danger indicator is handled.
---
--- @param restore boolean Whether to restore the badge visibility or hide them.
function CrosshairUI:UpdateBadgeHiding(restore)
	local badgeHolder = GetDialog("BadgeHolderDialog")
	if not badgeHolder then return end
	
	-- In action camera all badges are hidden
	if self.context.actionCamera then
		badgeHolder:SetVisible(restore and not CheatEnabled("CombatUIHidden"))
		return
	end
	
	if self.window_state == "destroying" then
		badgeHolder:SetVisible(restore and not CheatEnabled("CombatUIHidden"))
	end
	
	-- Hide badges of units who won't get hit, and the target.
	local target = self.context.target
	local attacker = self.context.attacker
	for i, u in ipairs(g_Units) do
		local unitBadges = g_Badges[u]
		if not unitBadges then goto continue end
		
		local predictedDamage = u.PotentialDamage ~= 0 or u.PotentialDamageConditional ~= 0 or u.SmallPotentialDamageIcon or u.LargePotentialDamageIcon
		local show = (predictedDamage and u ~= target) or ((u.suspicion or 0) > 0 and not g_Combat)
		show = show or restore
		show = not not show

		for i, b in ipairs(unitBadges) do
			if not b.ui or b.ui.window_state ~= "open" then goto continue end
			if b.preset == "AwareBadge" then goto continue end
			
			b.ui:SetVisible(show, "crosshair")
			if b.preset ~= "CombatBadge" then goto continue end
			
			-- Special logic for allies in the lof	
			local ally = u ~= attacker and u.team and not u.team:IsEnemySide(attacker.team)
			local inDanger = show and not restore
			if not ally then goto continue end

			-- AreaAim does this itself
			if inDanger then
				HandleMovementTileContour({u}, false, "CombatDanger")
			else
				HandleMovementTileContour({u})
			end
			::continue::
		end
		::continue::
	end
end

-- self is the interface mode as this used to be a member function
---
--- Spawns a crosshair UI element for a given action and target.
---
--- @param self table The CrosshairUI instance.
--- @param action table The action to use for the crosshair.
--- @param closeOnAttack boolean Whether to close the crosshair on attack.
--- @param meleeTargetPos table The position of a melee target.
--- @param target table The target for the crosshair.
--- @param dontWaitCamera boolean Whether to wait for the action camera to be in position.
--- @return table The spawned crosshair UI element.
---
function SpawnCrosshair(self, action, closeOnAttack, meleeTargetPos, target, dontWaitCamera)
	assert(SelectedObj)
	local attacker = self.attacker
	local target = target or self.target
	local canAim = action.IsAimableAttack
	
	local firingModes = false
	if action.group == "FiringModeMetaAction" then
		action, firingModes = GetUnitDefaultFiringModeActionFromMetaAction(attacker, action)
	end
	
	local minAimPossible, maxAimPossible, maxAimTotal = 0, 0, 0
	local startingAim = self and self.context and self.context.aim and canAim and self.context.aim
	if action.id == "PinDown" then -- PinDown is always as aimed as possible as if it was the default attack.
		canAim = false
		local defaultAction = attacker:GetDefaultAttackAction()
		local min, max, total = attacker:GetAimLevelRange(defaultAction, target, meleeTargetPos)
		minAimPossible = min
		startingAim, maxAimTotal, maxAimPossible = max, max, max
	elseif canAim then 
		minAimPossible, maxAimPossible, maxAimTotal = attacker:GetAimLevelRange(action, target, meleeTargetPos, self.context and self.context.free_aim) 
		startingAim = startingAim and Clamp(startingAim, minAimPossible, maxAimPossible) or minAimPossible
	end
	if maxAimTotal == 0 then canAim = false end -- The action allows aiming, but the weapon doesnt.
	
	local attachPos, attachSpotIdx, dynamic = false
	local function lCalculateAttachPos()
		-- We only use this when the crosshair isn't dynamic, therefore
		-- it is acceptable to use non-spot attaches (such as static positions in the world)
		local spotIdx = target:GetSpotBeginIndex("Torsostatic")
		if target.stance == "Crouch" then
			attachPos = target:GetSpotLoc(spotIdx)
			attachPos = attachPos:SetZ(attachPos:z() - 500)
			return
		elseif target.stance == "Prone" then
			spotIdx = target:GetSpotBeginIndex("Feetstatic")
			if spotIdx then
				attachPos = target:GetSpotLoc(spotIdx)
				attachPos = attachPos:SetZ(attachPos:z() + 200)
				return
			end
		end

		if spotIdx ~= -1 then
			attachPos = target
			attachSpotIdx = spotIdx
			return
		end
		
		spotIdx = target:GetSpotBeginIndex("Torso")
		if spotIdx == -1 then 
			spotIdx = target:GetSpotBeginIndex("Hit") -- Traps
			if spotIdx == -1 then
				spotIdx = target:GetSpotBeginIndex("Origin")
				attachPos = target:GetVisualPos()
			else
				attachPos = target:GetSpotLoc(spotIdx)
			end
		else
			attachPos = target:GetSpotLoc(spotIdx)
		end
		attachSpotIdx = nil
	end
	lCalculateAttachPos()
	
	local weapon1, weapon2 = action:GetAttackWeapons(attacker)
	local crosshair = XTemplateSpawn("ActionCameraCrosshair", self, { 
		attacker = attacker,
		target = target,
		action = action,
		noAim = not canAim,
		canTarget = action.IsTargetableAttack,
		meleeTargetPos = meleeTargetPos,
		closeOnAttack = closeOnAttack,
		step_pos = self.move_step_position,
		body_parts = target:GetBodyParts(weapon1),
		firingModes = table.icopy(firingModes),
		actionCamera = self.target_action_camera,
		free_aim = self.context and self.context.free_aim
	})
	crosshair.attachPos = attachPos
	crosshair.attachSpotIdx = attachSpotIdx
	crosshair.minAimPossible = minAimPossible
	crosshair.maxAimTotal = maxAimTotal
	crosshair.maxAimPossible = maxAimPossible
	crosshair.aim = startingAim
	crosshair:Open()

	if self.target_action_camera then
		crosshair:SetVisible(false)
		crosshair:CreateThread("actionCameraWait", function()
			if not dontWaitCamera then WaitMsg("ActionCameraInPosition") end
			lCalculateAttachPos()
			crosshair.attachPos = attachPos
			
			WaitMsg("OnRender")
			crosshair:SetVisible(true)
			crosshair:InvalidateLayout()
			Sleep(500)
		end)
	else
		if not g_Combat and not IsCoOpGame() then
			crosshair.time_dilation = true
			SetTimeFactor(const.DefaultTimeFactor / 2)
		end
	
		-- If no action cam, we need to actually attach to the target as the camera can be moved.
		crosshair:AddDynamicPosModifier({id = "attached_ui", target = attachPos, spot_idx = attachSpotIdx})
		crosshair.attachPos = false
		dynamic = true
		crosshair:CreateThread("actionCameraWait", function()
			if not dontWaitCamera then Sleep(500) end
			crosshair:InvalidateLayout()
			crosshair:SetVisible(true)
			if not g_Combat then cameraTac.SetFollowTarget(target) end
			Sleep(500)
		end)
	end
	
	local normalScale = point(1000, 1000)
	crosshair.dynamic = dynamic
	crosshair:CreateThread("UpdateInteractionBox", function (ctrl)
		local dialog = GetInGameInterfaceModeDlg()
		local visibleEnemiesBar = dialog:ResolveId("idVisibleEnemies")
		local lastPos = GetPassSlab(target)
		local initial_update
		while ctrl.window_state ~= "destroying" do
			WaitNextFrame(1)
			if not initial_update then
				initial_update = true
				ctrl:UpdateAim()
			end
			
			-- in exploration  we need to continuously check if the unit is visible
			if not g_Combat and IsValid(target) then
				local target_not_seen
				if IsKindOf(target, "Unit") then
					-- Checking visible directly will allow this to work with Livewire's perk
					-- and other game specific logic that consider the unit not visible but keeps it
					-- visually visible
					target_not_seen = not target.visible
				else
					target_not_seen = VisibilityGetValue(attacker.team, target) < const.uvVisible
				end

				if target_not_seen then
					SetInGameInterfaceMode("IModeExploration")
					return
				end
				
				local newPos = GetPassSlab(target)
				if newPos ~= lastPos then
					ctrl.cached_results = false
					ctrl:UpdateAim()
					lastPos = newPos
				end
			end
			
			if dynamic then
				local obj = attachPos -- point or obj
				if IsValid(obj) and attachSpotIdx ~= -1 then -- if obj attach to specific spot specified
					obj = obj:GetSpotLoc(attachSpotIdx)
				end
				
				if IsValid(obj) or IsPoint(obj) then
					local front, sx, sy = GameToScreenXY(obj)
					local b = ctrl.box
					if front then
						ctrl:SetInteractionBox(sx + b:minx(), sy + b:miny(), normalScale, true)
					end
				end
			end
		end
	end, crosshair)

	return crosshair
end

---
--- Changes the current action for the crosshair UI.
---
--- @param action table The new action to set.
---
function CrosshairUI:ChangeAction(action)
	self.context.attacker.lastFiringMode = action.id
	self.action = action
	self.context.action = action
		
	-- Recalculate stuff which is calculated on crosshair open
	local attacker = self.context.attacker
	local target = self.context.target
	local minAimPossible, maxAimPossible, maxAimTotal = attacker:GetAimLevelRange(action, target)
	local canAim = action.IsAimableAttack
	if maxAimTotal == 0 then canAim = false end
	self.context.noAim = not canAim 
	self.maxAimTotal = maxAimTotal
	self.maxAimPossible = maxAimPossible
	self.minAimPossible = minAimPossible
	
	self.aim = minAimPossible
	self:UpdateAim()
	
	if self.crosshair_gamepad_list ~= "firing_modes" then
		self.crosshair_gamepad_list = "firing_modes"
		ObjModified("GamepadUIStyleChanged")
	end
	
	ObjModified("firing_mode")
	ObjModified("crosshair")
end

---
--- Cycles through the available firing modes for the current crosshair action.
---
--- This function iterates through the list of available firing modes for the current
--- crosshair action, and selects the next enabled firing mode. The selected firing
--- mode is then set as the current action for the crosshair UI.
---
--- @param self CrosshairUI The CrosshairUI instance.
---
function CrosshairUI:CycleFiringModes()
	local id = self.context.action and self.context.action.id
	local firing_modes = self.context.firingModes or empty_table
	
	local attacker = self.context.attacker
	local curTargetIdx = table.find(firing_modes, "id", id) or 0
	for i = 1, #firing_modes do
		curTargetIdx = curTargetIdx + 1
		if curTargetIdx > #firing_modes then
			curTargetIdx = 1
		end
		
		local action = firing_modes[curTargetIdx]
		
		local actionEnabled = attacker.ui_actions[action.id]
		actionEnabled = actionEnabled == "enabled"
		
		if actionEnabled then
			self:ChangeAction(action)
			break
		end
	end
end

---
--- Sets the layout space for the CrosshairUI.
---
--- This function sets the layout space for the CrosshairUI, ensuring that the crosshair is positioned correctly on the screen. It calculates the screen position of the crosshair based on the attached position or a default position, and then sets the box of the crosshair target to fit within the specified space.
---
--- @param self CrosshairUI The CrosshairUI instance.
--- @param space_x number The x-coordinate of the layout space.
--- @param space_y number The y-coordinate of the layout space.
--- @param space_width number The width of the layout space.
--- @param space_height number The height of the layout space.
---
function CrosshairUI:SetLayoutSpace(space_x, space_y, space_width, space_height)
	local target = self:ResolveId("idTarget")
	if not target then return end
	
	local gTs
	if self.attachPos then		
		local attachPos = self.attachPos
		if IsValid(attachPos) and self.attachSpotIdx then
			attachPos = attachPos:GetSpotLoc(self.attachSpotIdx)
		end
		local front, toScreenX, toScreenY = GameToScreenXY(attachPos)
		if not front then return end
		gTs = point(toScreenX, toScreenY)
	else
		gTs = point20
	end
	
	-- Prevent the crosshair from moving tiny bits due to action camera movement or unit movement.
	if not self.cachedScreenPos then
		self.cachedScreenPos = gTs
	else
		if gTs:Dist2D(self.cachedScreenPos) < ScaleXY(self.scale, 15) then
			gTs = self.cachedScreenPos
		else
			self.cachedScreenPos = gTs
		end
	end

	local targetBox = target.box
	if targetBox == empty_box then return end
	
	local x, y = gTs:xy()
	local w, h = target.measure_width, target.measure_height
	local scale_x, scale_y = target.scale:xy()
	x = x - w / 2
	y = y - h / 2
	
	local enemy_info = self:ResolveId("idEnemyInfo")
	if enemy_info then
		y = y - MulDivRound(enemy_info.box:sizey(), 1000, scale_y)
	end

	local width = Min(self.measure_width, space_width)
	local height = Min(self.measure_height, space_height)
	self:SetBox(x, y, width, height)
end

---
--- Sets the visibility of the CrosshairUI and moves the selection in the current gamepad list if the UI is made visible.
---
--- @param visible boolean Whether to make the CrosshairUI visible or not.
--- @param ... any Additional arguments passed to XContextWindow.SetVisible.
---
function CrosshairUI:SetVisible(visible, ...)
	XContextWindow.SetVisible(self, visible, ...)
	if visible then
		self:MoveInCurrentGamepadList(0)
	end
end

---
--- Moves the selection in the current gamepad list for the CrosshairUI.
---
--- @param direction integer The direction to move the selection, either 1 or -1.
---
function CrosshairUI:MoveInCurrentGamepadList(direction)
	local crosshair = self
	local list = crosshair.crosshair_gamepad_list
	if list == "body_parts" then
		local selectedPart = crosshair.targetPart
		local slot = selectedPart and selectedPart.id
		local buttonIdx = crosshair.idButtonsContainer
		buttonIdx = table.find(buttonIdx, "context", selectedPart)
		if not buttonIdx then return "break" end
		
		buttonIdx = buttonIdx + direction
		local buttonNext = crosshair.idButtonsContainer[buttonIdx]
		if not buttonNext or not buttonNext.visible then return "break" end
		
		crosshair:SetSelectedPart(buttonNext.context)
	elseif list == "firing_modes" and crosshair.idFireModeContainer then
		local selectedFiringMode = crosshair.context.action
		local buttonIdx = false
		for i, b in ipairs(crosshair.idFireModeContainer) do
			if b.context.action == selectedFiringMode then
				buttonIdx = i
			end
		end
		if not buttonIdx then return "break" end
		
		buttonIdx = buttonIdx + direction
		local buttonNext = crosshair.idFireModeContainer[buttonIdx]
		if not buttonNext or not buttonNext.visible or not buttonNext.enabled then return "break" end
		if not buttonNext.context.action then return "break" end
		
		crosshair:ChangeAction(buttonNext.context.action)
	end
end

---
--- Handles the event when the player's unit swaps weapons.
---
--- If the selected object is the player's unit, this function updates the movement avatar and the crosshair UI based on the current game mode.
---
--- @param unit table The unit that swapped weapons.
---
function OnMsg.UnitSwappedWeapon(unit)
	if unit ~= SelectedObj then return end
	local igi = GetInGameInterfaceModeDlg()
	
	if IsKindOf(igi, "IModeCombatMovement") and igi.targeting_blackboard and igi.targeting_blackboard.movement_avatar then
		UpdateMovementAvatar(igi, nil, nil, "update_weapon")
	end
	
	if igi and igi.crosshair then
		if g_Combat then
			SetInGameInterfaceMode("IModeCombatMovement")
		else
			SetInGameInterfaceMode("IModeExploration")
		end
	end
end

-- buttons will be placed on the right side of the crosshair only
-- we start at <start_angle> deg and end at +<start_angle> deg (for an arc of 140 deg)
-- the radius of the crosshair image is <crosshair_radius>
-- buttons are aligned top left over the crosshair
-- here, we calculate the offsets to position them correctly
---
--- Calculates the offset for a crosshair button based on the button's position in the total number of buttons.
---
--- @param num integer The index of the button, starting from 1.
--- @param totalParts integer The total number of buttons.
--- @return number, number The x and y offsets for the button's position.
---
function CalculateCrosshairButtonOffset(num, totalParts)
	local crosshair_radius = 130
	local start_angle = -42
	local arc_size = abs(start_angle * 2)
	
	local angle = start_angle
	if totalParts > 1 then
		local interval = arc_size / (totalParts - 1)
		angle = (start_angle + (num - 1) * interval) * 60
	else
		angle = 0
	end

	local x, y = 0, 0
	x = MulDivRound(crosshair_radius, cos(angle), 4096) + crosshair_radius
	y = MulDivRound(crosshair_radius, sin(angle), 4096) + crosshair_radius
	
	return x, y
end

---
--- Calculates the offset for a crosshair fire mode button based on the button's position in the total number of buttons.
---
--- @param num integer The index of the button, starting from 1.
--- @param totalParts integer The total number of buttons.
--- @return number, number The x and y offsets for the button's position.
---
function CalculateCrosshairFireModeButtonOffset(num, totalParts)
	local crosshair_radius = 130
	local start_angle = -160
	local arc_size = -40
	
	local angle = start_angle
	if totalParts == 2 then
		arc_size = -20
		start_angle = -170
		angle = start_angle
	end
	
	if totalParts > 1 then
		local interval = arc_size / (totalParts - 1)
		angle = (start_angle + (num - 1) * interval) * 60
	else
		angle = angle * 60
	end

	local x, y = 0, 0
	x = MulDivRound(crosshair_radius, cos(angle), 4096) + crosshair_radius
	y = MulDivRound(crosshair_radius, sin(angle), 4096) + crosshair_radius
	
	return x + 1, y
end

CrosshairFiringModeDirection = {
	"LeftThumbUpLeft",
	"LeftThumbLeft",
	"LeftThumbDownLeft",
}
---
--- Calculates the status effects that should be displayed in the crosshair UI for a given attack.
---
--- @param crosshairCtx table The context of the crosshair UI, containing information about the attacker, target, and attack.
--- @param weapon table The weapon being used in the attack.
--- @param bodyPartId integer The ID of the body part being targeted.
--- @param action table The action being performed, containing information about the attack.
--- @param attackResultTable table The results of the attack, containing information about hit chances, ally hits, etc.
--- @return table A list of status effects to display in the crosshair UI.
---
function GetCrosshairAttackStatusEffects(crosshairCtx, weapon, bodyPartId, action, attackResultTable)
	if not attackResultTable then attackResultTable = { allyHit = false, friendly_fire_dmg = 0, chance_to_hit_modifiers = empty_table } end 

	local target = crosshairCtx.target
	local attacker = crosshairCtx.attacker
	local targetHasBodyParts = IsKindOf(target, "Unit")
	local errors = {}
	if attackResultTable.allyHit or (attackResultTable.friendly_fire_dmg or 0) > 0 then
		local allyHitEffect = g_Classes["AllyHit"]
		local name = false
		if attackResultTable.allyHit and gv_UnitData[attackResultTable.allyHit] then -- Single target
			local hitObj = gv_UnitData[attackResultTable.allyHit]
			if hitObj:IsNPC() then
				name = T{138171794693, "<DisplayName> (NPC)", hitObj}
			else
				name = T{733545694003, "<DisplayName>", hitObj}
			end
		elseif attackResultTable.hit_objs then -- AOE
			for i, hitObj in ipairs(attackResultTable.hit_objs) do
				if IsKindOf(hitObj, "Unit") and not attacker:IsOnEnemySide(hitObj) then
					if name then
						name = "multiple"
						break
					end
				
					if hitObj:IsNPC() then
						name = T{138171794693, "<DisplayName> (NPC)", hitObj}
					else
						name = T{733545694003, "<DisplayName>", hitObj}
					end
				end
			end
		else
			name = T(451028806650, "Unknown Ally")
		end
		
		local text = false
		if name == "multiple" then
			text = T(741562461024, "<color DescriptionTextRed>Multiple allies are in danger!</color>")
		else
			text = T{404834595320, "<color DescriptionTextRed><u(UnitName)> is in danger!</color>", UnitName = _InternalTranslate(name)}
		end

		errors[#errors + 1] = {
			Icon = allyHitEffect.Icon,
			DisplayName = allyHitEffect.DisplayName,
			Description = text,
			type = allyHitEffect.type
		}
	end

	if not g_Combat and IsActivePaused() and action.ActivePauseBehavior == "unpause" then
		errors[#errors + 1] = g_Classes["AttackUnpause"]
	end

	if crosshairCtx.danger then
		errors[#errors + 1] = g_Classes["Danger"]
	end
	
	-- In aoe attacks we only care about the projectile part
	local targetHit = false
	if attackResultTable.target_hit_projectile ~= nil then
		targetHit = attackResultTable.target_hit_projectile
	else
		targetHit = attackResultTable.target_hit
	end
	if action.ActionType == "Ranged Attack" and not targetHit then
		errors[#errors + 1] = g_Classes["ObscuredHit"]
	end
	
	if action.ActionType == "Ranged Attack" and attackResultTable.grazing then
		errors[#errors + 1] = g_Classes["GrazingHits"]
	end
	
	local cantSeeIdx = false
	if attackResultTable.cantSeeBodyPart then
		local cantSeeMod = g_Classes["CantSee"]
		local spotter = attackResultTable.spotter
		if spotter then
			cantSeeMod = {
				DisplayName = cantSeeMod.DisplayName,
				Icon = cantSeeMod.Icon,
				Description = T{521198297540, "<color DescriptionTextRed>Out of sight, but seen by <spotter>!</color>", spotter = spotter.Nick},
				type = cantSeeMod.type
			}
		end
		errors[#errors + 1] = cantSeeMod
		cantSeeIdx = #errors
	end
	
	if targetHasBodyParts then
		local armorPart, armorIcon, iconPath = target:IsArmored(bodyPartId)
		local armorPierced, ignored = target:IsArmorPiercedBy(weapon, attackResultTable.aim, bodyPartId, action)
		if armorPart and armorIcon then
			local icon = iconPath .. (armorPierced and "ignored_" or "") .. armorIcon
			
			local className = armorPierced and (ignored and "ArmoredIgnored" or "ArmoredPierced") or "Armored"
			local armorEffect = g_Classes[className]
			
			local err = {
				DisplayName = armorEffect.DisplayName,
				Icon = icon,
				Description = armorEffect.Description,
				type = armorEffect.type
			}
			
			if className == "Armored" and cantSeeIdx then
				table.insert(errors, cantSeeIdx, err)
			else
				errors[#errors + 1] = err
			end
		end
	end
	
	return errors
end

---
--- Retrieves the visible status effects and crosshair effects for a given unit.
---
--- @param unit Unit The unit to retrieve the effects for.
--- @return table The combined list of unit and crosshair effects.
---
function GetUnitVisibleStatusEffectsAndCrosshairEffects(unit)
	local unitEffects = {}
	if IsKindOf(unit, "Unit") then
		unitEffects = unit:GetUIVisibleStatusEffects()
	end
	local crosshair = GetInGameInterfaceModeDlg()
	crosshair = crosshair and crosshair.crosshair
	local crosshairCtx = crosshair and crosshair.context
	if not crosshairCtx then return unitEffects end
	
	local bodyPart = crosshair.targetPart
	local bodyPartId = bodyPart.id
	local attackResultTable = crosshairCtx.attackResultTable
	attackResultTable = attackResultTable and attackResultTable[bodyPartId]

	local attacker = crosshairCtx.attacker
	local action = crosshairCtx.action
	local weapon = action:GetAttackWeapons(attacker)
	local crosshairEffects = GetCrosshairAttackStatusEffects(crosshairCtx, weapon, bodyPartId, action, attackResultTable)
	table.iappend(unitEffects, crosshairEffects)
	
	return unitEffects
end

---
--- Populates the crosshair UI with information about the current attack.
---
--- @param win UIWindow The crosshair UI window.
--- @param attacker Unit The attacking unit.
--- @param action AttackAction The attack action.
--- @param attackResults AttackResults The results of the attack.
---
function PopulateCrosshairUICth(win, attacker, action, attackResults)
	local weapon = action:GetAttackWeapons(attacker)
	local dontShow = action.AlwaysHits
	win:SetVisible(not dontShow)
	if dontShow or not attackResults then return end

	local chanceToHit = attackResults.chance_to_hit
	local modifiers = attackResults.chance_to_hit_modifiers
	
	if CthVisible() then
		win.idChanceToHit:SetText(T{757275361770, "ACCURACY: <right><percent(chanceToHit)>", chanceToHit = chanceToHit})
		win.idChanceToHit.parent:SetZOrder(1)
	else
		win.idChanceToHit:SetText(T{906758075439, "ACCURACY", chanceToHit = chanceToHit})
		win.idChanceToHit.parent:SetZOrder(0)
	end
	if not modifiers then -- Invalid weapon, or invalid target, or something else
		win:SetVisible(false)
		return
	end
	
	-- Map and concat mods
	local concatList = {}
	for i, mod in ipairs(modifiers) do
		if mod.uiHidden then goto continue end
	
		if mod.value then -- Handle missing value just in case
			local sign = ""
			if mod.value > 0 then
				sign = "<color PDASectorInfo_Green>+</color>"
			elseif mod.value < 0 then
				sign = "<color DescriptionTextRed>-</color>"
			end
			if CthVisible() then sign = T{257328164584, "<percent(value)>", value = mod.value} end
			concatList[#concatList + 1] = T{221170966425, "<name><right><style PDABrowserTextLightBold><sign></style>", name = mod.name, sign = sign}
		else
			concatList[#concatList + 1] = mod.name
		end
		
		if mod.metaText then
			if IsT(mod.metaText) then
				concatList[#concatList + 1] = T{399490205680, "<left> <metaText>", metaText = mod.metaText}
			else
				for i, t in ipairs(mod.metaText) do
					concatList[#concatList + 1] = T{399490205680, "<left> <metaText>", metaText = t}
				end
			end
		end
		
		::continue::
	end
	local concatStr = table.concat(concatList, "\n<left>")
	win.idModifiers:SetVisible(true)
	win.idModifiers:SetText(Untranslated(concatStr))
end

-- mega hackery to get the rollover to split in two when there's not enough space for it
-- on the left nor the right side of the crosshair.
---
--- Splits the rollover UI element into two parts when there is not enough space to display it on either side of the crosshair.
--- This function is a hack to work around layout issues with the rollover UI.
---
--- @param rollover UIElement The rollover UI element to split.
---
function CrosshairRolloverCustomLayoutSplit(rollover)
	-- both children will be dock ignore which will cause the rollover to be of size 0
	rollover.MinWidth = 1

	if true then
		local self = rollover.idMercStatusMoreInfoContainer
		if self.Dock ~= "ignore" then
			self:SetDock("ignore")
		end
		local node = self:ResolveId("node")
		local anchor = node:GetAnchor()
		local left = node.box:minx() < anchor:minx()
		local leftMargin, topMargin = ScaleXY(rollover.scale, 20, 20)
		if not left then
			self:SetBox(anchor:maxx() + leftMargin, anchor:miny() - topMargin, self.measure_width, self.measure_height)
		else
			self:SetBox(anchor:minx() - self.measure_width - leftMargin, anchor:miny() - topMargin, self.measure_width, self.measure_height)
		end
	end
	
	if true then
		local self = rollover.idContent
		if self.Dock ~= "ignore" then
			self:SetDock("ignore")
		end
		local node = self:ResolveId("node")
		local anchor = node:GetAnchor()
		local left = node.box:minx() < anchor:minx()
		local leftMargin, topMargin = ScaleXY(rollover.scale, 20, 20)
		if left then
			self:SetBox(anchor:maxx() + leftMargin, anchor:miny() - topMargin, self.measure_width, self.measure_height)
		else
			self:SetBox(anchor:minx() - self.measure_width - leftMargin, anchor:miny() - topMargin, self.measure_width, self.measure_height)
		end
	end
end