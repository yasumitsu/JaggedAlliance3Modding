local lAboveBadgeTexts = {
	-- Enemies
	NoSight = T(853501212617, "NO SIGHT"),
	NoLOF = T(625870963186, "NO LINE OF FIRE"),
	Suspicious = T(891958507003, "SUSPICIOUS"),
	Surprised = T(144402315512, "SURPRISED"),
	Unaware = T(395978046294, "UNAWARE"),
	-- Allies
	OutOfAmmo = T(846615723770, "OUT OF AMMO"),
	Reload = T(402669531723, "RELOAD"),
	Hidden = T(928205349561, "HIDDEN"),
	Bandaging = T(633661081662, "Bandaging"),
	InDanger = T(608680053799, "IN DANGER!"),
	-- queued actions (active pause
	QueuedAction = T(262910234067, "QUEUED ACTION"),
	
	InterruptAttacksRemaining = T(760116982146, "MAX. ATTACKS: <number>"),
}

-- The combat badge UI
DefineClass.CombatBadge = {
	__parents = { "XContextWindow", "XDrawCache" },
	badge_mode = false, -- This UI element can be used as a badge, or as normal UI (as in the crosshair)
	unit = false,
	active = false,
	active_reasons = false,
	selected = false,

	-- cached values
	mode = false,
	combat = false,
	inDanger = false,
	transp = -1,
	
	visible_reasons = false
}

--- Invalidates the XDrawCache for this CombatBadge instance.
---
--- This function is used for breakpointing purposes, to ensure the XDrawCache is properly invalidated.
function CombatBadge:Invalidate() -- For breakpointing
	XDrawCache.Invalidate(self)
end

---
--- Opens the CombatBadge UI element.
---
--- This function is responsible for initializing the CombatBadge when it is opened. It sets the badge mode, the associated unit, the visible reasons, and the active reasons. It then calls the parent `XContextWindow:Open()` function and updates the mode of the CombatBadge.
---
--- Finally, it sets the selected state of the CombatBadge based on whether the associated unit is in the current selection.
---
--- @function CombatBadge:Open
--- @return nil
function CombatBadge:Open()
	self.badge_mode = not not rawget(self, "xbadge-instance")
	self.unit = self.context
	self.visible_reasons = {
		["unit"] = self.unit.visible
	}
	self.active_reasons = {}
	XContextWindow.Open(self)

	self:UpdateMode()
	self:SetSelected(table.find(Selection, self.unit))
end

---
--- Determines the combat badge hiding mode based on various game conditions.
---
--- @return string The combat badge hiding mode, which can be one of the following:
---   - "Always": The combat badge is always visible.
---   - "PlayerTurn": The combat badge is only visible during the player's turn.
---   - "ShowTargetBadge": The combat badge is only visible for the target of an attack.
---   - "ActiveOnly": The combat badge is only visible when the associated unit is active.
---
function CombatBadge:GetCombatBadgeHidingMode()
	if table.find(g_ShowTargetBadge, self.context) then
		--mode used for showing the target's badge of an attack from AI
		return "ShowTargetBadge"
	end
	if self.combat then
		return "Always"
	end
	
	local optionValue = GetAccountStorageOptionValue("AlwaysShowBadges")
	if optionValue and optionValue == "Always" and self.mode == "friend" then
		return "Always"
	end
	
	for _, unit in ipairs(Selection) do
		if unit.marked_target_attack_args and unit.marked_target_attack_args.target == self.context then
			return "Always"
		end
	end
	
	if interactablesOn then
		return "Always"
	end
	
	return "ActiveOnly"
end

---
--- Updates the mode and layout of the combat badge based on the associated unit.
---
--- This function is responsible for determining the appropriate mode and layout for the combat badge based on the properties of the associated unit. It sets the mode, visibility, and active state of the combat badge accordingly.
---
--- @param self CombatBadge The combat badge instance.
---
function CombatBadge:UpdateMode()
	if self.window_state == "destroying" then return end

	local unit = self.unit
	if not IsKindOf(unit, "Unit") then
		if IsKindOf(unit, "Trap") then
			self:LayoutTrap()
		end
		return
	end
	
	local npc = unit:IsNPC() and unit.team and (not SideIsEnemy("player1", unit.team.side) or unit.team.player_ally)
	local friend = unit:IsPlayerAlly()
	local combat = not not g_Combat
	self.combat = combat
	
	local bar = self:ResolveId("idBar")
	local barSize = 12
	if unit.villain then
		barSize = 16
	end
	bar:SetMinHeight(barSize)
	bar:SetMaxHeight(barSize)
	
	if npc then
		if unit.ephemeral then
			self.mode = "npc-ambient"
		else
			self.mode = "npc"
		end
		self:LayoutNPC()
	elseif friend then
		self.mode = "friend"
		self:LayoutFriend()
	else
		self.mode = "enemy"
		self:LayoutEnemy()
	end
	
	-- Apply option, this is ran when the badge is created and whenever options are changed.
	-- More frequent updates are done in the corresponding functions (like UpdateActive).
	local optionValue = self:GetCombatBadgeHidingMode()
	if optionValue == "Always" then
		self:SetVisible(true, "option")
	elseif optionValue == "PlayerTurn" or optionValue == "ShowTargetBadge" then
		self:SetVisible(g_Combat and g_Teams[g_CurrentTeam] and g_Teams[g_CurrentTeam].control == "UI" and (not g_Combat.enemies_engaged or g_Combat.start_reposition_ended) or not g_Combat, "option")
	elseif optionValue == "ActiveOnly" then
		local isSus = (self.unit.suspicion or 0) > 0
		self:SetVisible(self.active or (self.mode == "friend" and isSus) or self.selected, "option")
	end
	
	self:SetActive(self.mode ~= "friend" and interactablesOn, "interactables")
end

---
--- Lays out the UI elements for an NPC combat badge.
---
--- If the NPC is in "ambient" mode, the badge is fully opaque. Otherwise, it is semi-transparent.
--- The NPC badge hides the mercenary icon, health bar, and status effects container.
--- The name stripe is set to a dark background color.
---
--- @param self CombatBadge The combat badge instance.
---
function CombatBadge:LayoutNPC()
	self.idMercIcon:SetVisible(false)
	self.idBar:SetVisible(false)
	self.idStatusEffectsContainer:SetVisible(false)
	self.idNameStripe:SetBackground(GameColors["DarkB"])
	
	if self.mode == "npc-ambient" then
		self:SetTransp(255)
	else
		self:SetTransp(127)
	end
end

---
--- Lays out the UI elements for a friendly combat badge.
---
--- If the friendly unit is downed, the mercenary icon, name stripe, and health bar are desaturated and semi-transparent.
--- Otherwise, the mercenary icon and name stripe are fully opaque, and the health bar uses the "friendly" color preset.
---
--- @param self CombatBadge The combat badge instance.
---
function CombatBadge:LayoutFriend()
	local combat = self.combat
	local unit = self.unit
	local hpBar = self.idBar
	
	if unit:IsDowned() then
		self.idMercIcon:SetDesaturation(255)
		self.idMercIcon:SetTransparency(75)
		self.idNameStripe:SetBackground(GameColors.D)
		self.idNameStripe:SetTransparency(75)
		hpBar:SetColorPreset("desaturated")
		hpBar:SetBackground(RGBA(35, 61, 78, 120))
		hpBar:SetBorderColor(RGBA(35, 61, 78, 120))
		hpBar:SetTransparency(75)
	else
		self.idMercIcon:SetDesaturation(0)
		self.idMercIcon:SetTransparency(0)
		self.idNameStripe:SetBackground(GetColorWithAlpha(GameColors.Player, 205))
		self.idNameStripe:SetTransparency(0)
		hpBar:SetColorPreset("friendly")
		hpBar:SetBackground(RGB(35, 61, 78))
		hpBar:SetBorderColor(RGB(35, 61, 78))
		hpBar:SetTransparency(0)
	end

	self.idMercIcon:SetVisible(true)
	self:UpdateLevelIndicator()
	self.idStatusEffectsContainer:SetVisible(true)
	hpBar:SetVisible(true)
	
	self:SetTransp(127)
end

---
--- Lays out the UI elements for an enemy combat badge.
---
--- If the enemy unit is a villain, the health bar is set to a fixed width of 100. Otherwise, it is set to a fixed width of 80.
--- If the context is marked for a stealth attack, the mercenary icon is hidden, the name stripe is set to a dark color, and the status effects container and health bar are hidden.
--- Otherwise, the NPC layout is used and the badge is set to be fully transparent.
---
--- @param self CombatBadge The combat badge instance.
---
function CombatBadge:LayoutEnemy()
	local combat = self.combat

	if combat then
		--self.idLeftText:SetVisible(true)
		self.idMercIcon:SetVisible(true)
		self:UpdateLevelIndicator()
		self.idNameStripe:SetBackground(GetColorWithAlpha(GameColors.Enemy, 205))
		
		self.idStatusEffectsContainer:SetVisible(true)
		
		local hpBar = self.idBar
		hpBar:SetVisible(true)
		hpBar:SetColorPreset("enemy")

		if self.unit.villain then
			hpBar:SetMinWidth(100)
			hpBar:SetMaxWidth(100)
		else
			hpBar:SetMinWidth(80)
			hpBar:SetMaxWidth(80)
		end

		self:SetTransp(127)
	elseif self.context:IsMarkedForStealthAttack() then
		self.idMercIcon:SetVisible(false)
		self:UpdateLevelIndicator()
		self.idNameStripe:SetBackground(GameColors["DarkB"])
		self.idStatusEffectsContainer:SetVisible(false)
		self.idBar:SetVisible(false)

		self:SetTransp(127)
	else
		self:LayoutNPC()
		self:SetTransp(0)
	end
	
	self:UpdateEnemyVisibility()
	self:UpdateActive()
end

---
--- Lays out the UI elements for a trap combat badge.
---
--- The mercenary icon is set to be visible and uses the "UI/Hud/enemy_level_01" image.
--- The name stripe background is set to a color with alpha 205 based on the GameColors.Enemy color.
--- The health bar is set to be invisible and uses the "enemy" color preset.
---
--- @param self CombatBadge The combat badge instance.
---
function CombatBadge:LayoutTrap()
	self.idMercIcon:SetVisible(true)
	self.idMercIcon:SetImage("UI/Hud/enemy_level_01") -- todo: custom icon for traps?
	self.idNameStripe:SetBackground(GetColorWithAlpha(GameColors.Enemy, 205))
	
	local hpBar = self.idBar
	hpBar:SetVisible(false)
	hpBar:SetColorPreset("enemy")
end

MapVar("active_badge", false)

---
--- Sets the active state of the combat badge.
---
--- The active state of the combat badge is controlled by a set of reasons, each of which can independently set the badge to be active or inactive. This function allows setting the active state for a specific reason.
---
--- When the active state changes, the `UpdateActive()` function is called to update the visual appearance of the badge.
---
--- @param self CombatBadge The combat badge instance.
--- @param active boolean Whether the badge should be active for the given reason.
--- @param reason string The reason for setting the active state. Defaults to "default".
---
function CombatBadge:SetActive(active, reason)
	if self.window_state == "destroying" then return end
	reason = reason or "default"
	
	local activeByReason = self.active_reasons[reason]
	self.active_reasons[reason] = active
	
	local anyActiveReason = false
	for r, a in pairs(self.active_reasons) do
		if a then
			anyActiveReason = true
		end
	end

	if self.active == anyActiveReason then return end
	self.active = anyActiveReason
	self:UpdateActive()
end

---
--- Sets the selected state of the combat badge.
---
--- When the selected state changes, the `UpdateSelected()` function is called to update the visual appearance of the badge.
---
--- @param self CombatBadge The combat badge instance.
--- @param selected boolean Whether the badge should be selected.
---
function CombatBadge:SetSelected(selected)
	if self.window_state == "destroying" then return end
	if self.selected == selected then return end

	self.selected = selected
	self:UpdateSelected()
end

---
--- Updates the active state of the combat badge.
---
--- This function is responsible for updating the visual appearance of the combat badge based on its active state. It sets the transparency and z-order of the badge, and determines whether the badge should be visible based on the current combat mode and the unit's suspicion level.
---
--- @param self CombatBadge The combat badge instance.
---
function CombatBadge:UpdateActive()
	if self.window_state == "destroying" then return end

	local mode = self.mode
	local combat = self.combat
	local active = self.active or not self.badge_mode
	local selected = self.selected

	if active or selected then
		self:SetTransp(0)
		if self.badge_mode then self:SetZOrder(2) end
	else
		local transp
		if self.mode == "npc-ambient" then
			transp = 255
		else
			transp = 127
		end
		self:SetTransp(transp)
		if self.badge_mode then self:SetZOrder(0) end
	end

	local mode = self:GetCombatBadgeHidingMode()
	if mode == "ActiveOnly" then
		local isSus = (self.unit.suspicion or 0) > 0
		self:SetVisible(active or (self.mode == "friend" and isSus) or selected, "option")
	elseif mode == "ShowTargetBadge" and table.find(g_ShowTargetBadge, self.unit) then
		self:SetVisible(active, "option")
	end
	
	self.idNameStripe:SetVisible(active or selected or (mode == "npc" or (mode == "enemy" and not combat)), "active")
	
	local unit = self.unit
	if active and FloatingTexts[unit] then
		-- Do the floating text update in another thread as there 
		-- is a layout waiting sleep there down the stack
		CreateRealTimeThread(function()
			for i, f in ipairs(FloatingTexts[unit]) do
				if IsKindOf(f, "UnitFloatingText") then
					f:RecalculateBox()
				end
			end
		end)
	end
end

--- Updates the selected state of the combat badge.
---
--- This function is responsible for updating the visual appearance of the combat badge when it is selected. It calls the `UpdateActive()` function to update the active state of the badge, and also updates the above-name text for the badge.
---
--- @param self CombatBadge The combat badge instance.
function CombatBadge:UpdateSelected()
	if self.mode ~= "friend" then return end
	self.idAboveName:OnContextUpdate()
	self:UpdateActive()
end

--- Sets the visibility of the combat badge.
---
--- This function is responsible for controlling the visibility of the combat badge. It takes a `visible` parameter that determines whether the badge should be shown or hidden, and a `reason` parameter that specifies the reason for the visibility change.
---
--- The function first checks if the visibility for the given reason has already been set to the desired value. If so, it returns without making any changes.
---
--- Otherwise, it updates the `visible_reasons` table, which keeps track of the visibility state for each reason. It then checks if any of the reasons have set the badge to be hidden, and if so, it sets the overall visibility of the badge to false. If all reasons have set the badge to be visible, it sets the overall visibility to true.
---
--- Finally, it calls the `XContextWindow.SetVisible()` function to actually update the visibility of the badge.
---
--- @param self CombatBadge The combat badge instance.
--- @param visible boolean Whether the badge should be visible or not.
--- @param reason string The reason for the visibility change.
function CombatBadge:SetVisible(visible, reason)
	reason = reason or "logic"
	if self.visible_reasons[reason] == visible then return end
	
	self.visible_reasons[reason] = visible
	local show = true
	for reason, v in pairs(self.visible_reasons) do
		if not v then
			show = false
			break
		end
	end
	
	if show == self.visible then return end
	XContextWindow.SetVisible(self, show)
end

--- Sets the transparency of the combat badge.
---
--- This function is responsible for setting the transparency of the combat badge. It takes a `val` parameter that specifies the new transparency value.
---
--- If the transparency has already been set to the desired value, the function returns without making any changes.
---
--- Otherwise, it calls the `SetTransparency()` function to update the transparency of the badge, and also updates the `transp` field to store the new transparency value.
---
--- @param self CombatBadge The combat badge instance.
--- @param val number The new transparency value.
function CombatBadge:SetTransp(val)
	if self.transp == val then return end
	self:SetTransparency(val)
	self.transp = val
end

---
--- Updates the text displayed above the combat badge for a given window.
---
--- This function is responsible for determining the text that should be displayed above the combat badge for a given unit. It checks various conditions related to the unit's status, such as whether it is an enemy, friend, or has certain status effects, and sets the text and style accordingly.
---
--- The function first checks if the badge's window is in the "destroying" state, in which case it simply hides the text. It then initializes the `text` and `style` variables, which will be used to set the text and style of the badge's name text.
---
--- Next, the function checks if the unit has any active overwatch attacks, and if so, sets the text and style accordingly. It then checks if the unit is an enemy and performs various checks related to the enemy's visibility, range, and status effects, setting the text and style based on the results.
---
--- If the unit is a friend, the function checks for various conditions related to the friend's weapon status, status effects, and potential damage, setting the text and style accordingly.
---
--- Finally, the function sets the visibility, text, and text style of the badge's name text window based on the determined values.
---
--- @param win XContextWindow The window containing the combat badge.
function CombatBadgeAboveNameTextUpdate(win)
	local badge = win:ResolveId("node")
	local unit = badge.unit
	local attacker = Selection and Selection[1]
	if badge.window_state == "destroying" then
		win:SetVisible(false)
		return
	end
	
	local text = false
	local style = false
	
	if not text and g_Overwatch[unit] then
		local overwatchData = g_Overwatch[unit]
		local numberOfAttacks = overwatchData and overwatchData.num_attacks
		if numberOfAttacks and numberOfAttacks > 0 then
			text = T{lAboveBadgeTexts.InterruptAttacksRemaining, number = numberOfAttacks}
			style = "BadgeName_Red"
		end
	end
	
	if badge.mode == "enemy" and attacker then
		local enemySeesPlayer = VisibilityCheckAll(attacker, unit, nil, const.uvVisible)
		local outOfRange = false
		if attacker and IsKindOf(attacker, "Unit") then	
			local canAttack = true
			local action = attacker:GetDefaultAttackAction()
			local wep = action and action:GetAttackWeapons(attacker)
			if IsKindOf(wep, "Firearm") then
				local distance = attacker:GetDist(unit) / const.SlabSizeX
				outOfRange = distance >= wep.WeaponRange
				if canAttack then canAttack = not outOfRange end
			else
				outOfRange = false
			end
		end

--[[		if outOfRange then
			text = lAboveBadgeTexts.NoRange
			style = "BadgeName_Red"]]
		if unit.StealthKillChance > -1 then -- Shown during damage prediction, such as mobile shot
			text = T(142002637794, "Stealth Kill")
			style = "BadgeName_Red" 
		elseif table.find(s_PredictionNoLofTargets, unit) then
			text = lAboveBadgeTexts.NoLOF
			style = "BadgeName_Red"
		elseif not enemySeesPlayer then
			text = lAboveBadgeTexts.NoSight
			style = "BadgeName_Red"
		elseif unit:HasStatusEffect("Suspicious") then
			text = lAboveBadgeTexts.Suspicious
			style = "BadgeName_Red"
		elseif unit:HasStatusEffect("Surprised") then
			text = lAboveBadgeTexts.Surprised
			style = "BadgeName_Red"
		elseif unit:HasStatusEffect("Unaware") then
			text = lAboveBadgeTexts.Unaware
			style = "BadgeName_Red"
		end
	elseif badge.mode == "friend" and (g_Combat or badge.selected) then
		if not text then
			local w1, w2 = unit:GetActiveWeapons("Firearm")
			if w1 and (not w1.ammo or w1.ammo.Amount == 0) then
				local ammoForWeapon = unit:GetAvailableAmmos(w1, nil, "unique")
				text = #ammoForWeapon == 0 and lAboveBadgeTexts.OutOfAmmo or lAboveBadgeTexts.Reload
				style = "BadgeName_Red"
			elseif w2 and (not w2.ammo or w2.ammo.Amount == 0) then
				local ammoForWeapon = unit:GetAvailableAmmos(w2, nil, "unique")
				text = #ammoForWeapon == 0 and lAboveBadgeTexts.OutOfAmmo or lAboveBadgeTexts.Reload
				style = "BadgeName_Red"
			end
		end

		if not text and unit:HasStatusEffect("Hidden") then
			text = lAboveBadgeTexts.Hidden
			style = "BadgeName_Red"
		end

		if not text and IsMerc(unit) and IsActivePaused() and unit.queued_action_id then
			local action = CombatActions[unit.queued_action_id]
			style = "BadgeName_Red"
			text = action and action.QueuedBadgeText or lAboveBadgeTexts.QueuedAction
		end

		if not text then
			if IsMerc(unit) then
				local operation = unit.Operation
				local operation_preset = SectorOperations[operation]
				if operation_preset.ShowInCombatBadge and gv_Sectors[gv_CurrentSectorId] and not gv_Sectors[gv_CurrentSectorId].conflict then
					text = operation_preset and operation_preset.display_name
					style = "BadgeName"
				end
			end
		end
		
		if not text then				
			local damagePredicted = unit.PotentialDamage > 0 or unit.SmallPotentialDamageIcon or unit.LargePotentialDamageIcon
			if damagePredicted then
				text = lAboveBadgeTexts.InDanger
				style = "BadgeName_Red"
			elseif unit:IsDowned() and not unit:HasStatusEffect("Unconscious") then
				local dieChance = 100 - (unit.Health + unit.downed_check_penalty)
				if FindBandagingUnit(unit) then
					dieChance = 0
				end
				
				local chanceAsText = false
				if dieChance > 75 then
					chanceAsText = DieChanceToText.VeryHigh
				elseif dieChance > 50 then
					chanceAsText = DieChanceToText.High
				elseif dieChance > 20 then
					chanceAsText = DieChanceToText.Moderate
				elseif dieChance > 0 then
					chanceAsText = DieChanceToText.Low
				elseif dieChance <= 0 then
					chanceAsText = DieChanceToText.None
				end
				
				text = T{778469746308, "Death Chance: <chanceAsText>", chanceAsText = chanceAsText}
				style = "BadgeName_Red"
			elseif unit:HasStatusEffect("BandageInCombat") then
				text = lAboveBadgeTexts.Bandaging
				style = "BadgeName"
			end
		end
	end
	
	win:SetVisible(not not text)
	win:SetText(text)
	win:SetTextStyle(style)
end

---
--- Updates the visibility of the enemy indicator in the combat badge.
---
--- This function is called to update the visibility of the enemy indicator in the combat badge. It first checks if the window state is "destroying", in which case it returns without doing anything. It then calls the `CombatBadgeAboveNameTextUpdate` function with the `idAboveName` parameter, and finally calls the `UpdateActive` function.
---
--- @param self CombatBadge The combat badge instance.
---
function CombatBadge:UpdateEnemyVisibility()
	if self.window_state == "destroying" then return end
	CombatBadgeAboveNameTextUpdate(self.idAboveName)
	self:UpdateActive()
end

---
--- Sets the layout space for the combat badge.
---
--- This function is responsible for setting the layout space for the combat badge. It first checks if the badge is in a specific mode, and if so, it uses a custom layout logic. Otherwise, it falls back to the default `XContextWindow.SetLayoutSpace` function.
---
--- The custom layout logic centers the badge relative to the provided space, taking into account the badge's mode and the stance of the associated unit. It also adjusts the bottom margin based on the unit's stance.
---
--- @param self CombatBadge The combat badge instance.
--- @param space_x number The x-coordinate of the layout space.
--- @param space_y number The y-coordinate of the layout space.
--- @param space_width number The width of the layout space.
--- @param space_height number The height of the layout space.
---
function CombatBadge:SetLayoutSpace(space_x, space_y, space_width, space_height)
	if not self.badge_mode then
		return XContextWindow.SetLayoutSpace(self, space_x, space_y, space_width, space_height)
	end

	local myBox = self.box
	local x, y = myBox:minx(), myBox:miny()
	local width = Min(self.measure_width, space_width)
	local height = Min(self.measure_height, space_height)
	
	local leftMargin = 0
	local notJustName = self.mode ~= "npc" and self.mode ~= "npc-ambient" and (self.mode ~= "enemy" and not self.combat)
	if notJustName then
		leftMargin = ScaleXY(self.scale, -15)
	end
	x = (space_x - width / 2) + leftMargin
	
	-- Center relative to self, rather than relative to the outside space (since the outside space is the whole screen).
	local unit = self.context
	local bottomMargin = notJustName and -10 or 0
	if IsKindOf(unit, "Unit") and IsValid(unit) then
		if unit.stance == "Prone" then
			bottomMargin = notJustName and -95 or -85
		elseif unit.stance == "Crouch" then
			bottomMargin = notJustName and -45 or -35
		end
	end
	
	local _, scaledBottomMargin = ScaleXY(self.scale, 0, bottomMargin)
	y = space_y - height - scaledBottomMargin
	
	-- Gotta push the height as otherwise the badge will go "offscreen" relative to 0,0
	height = height + abs(y)

	self:SetBox(x, y, width, height)
end

---
--- Updates the visibility of the co-op mark for the combat badge.
---
--- This function is responsible for managing the visibility of the co-op mark on the combat badge. It first checks if the game is in co-op mode, and if not, it hides the mark. Otherwise, it checks if another player is aiming at the unit associated with the combat badge. If so, it shows the mark and sets the badge to active with the "co-op-aim" mode.
---
--- If the badge is in "friend" mode, the function checks if the unit is controlled by another player and shows the mark accordingly. It also sets the badge to active if another player is selecting the unit.
---
--- In all other cases, the function hides the mark and sets the badge to inactive in the "co-op-aim" mode.
---
--- @param self CombatBadge The combat badge instance.
--- @param mark XContextWindow The co-op mark window.
---
function CombatBadge:UpdateCoOpMarkVisibility(mark)
	if not IsCoOpGame() then
		mark:SetVisible(false)
		return
	end

	local aimingAtUnit = IsOtherPlayerActingOnUnit(self.unit, "aim")
	if aimingAtUnit then
		mark:SetVisible(true)
		mark:SetImage("UI/Hud/coop_partner_attack")
		self:SetActive(true, "co-op-aim")
		return
	end

	if self.mode == "friend" then
		mark:SetVisible(self.unit.ControlledBy ~= netUniqueId)
		mark:SetImage("UI/Hud/coop_partner")
		self:SetActive(IsOtherPlayerActingOnUnit(self.unit, "select"), "co-op-aim")
	else
		mark:SetVisible(false)
		self:SetActive(false, "co-op-aim")
	end
end

---
--- Sets the active combat badge to be exclusive, deactivating any previously active badge.
---
--- This function is responsible for managing the active combat badge. If there is no active badge and no unit is provided, the function simply returns. If there is an active badge and the provided unit matches the active badge's unit, the function also returns.
---
--- If there is an active badge and its associated unit is valid, the function deactivates the active badge in "exclusive" mode. It then sets the provided unit's combat badge as the active badge, activating it in "exclusive" mode.
---
--- @param unit Unit The unit whose combat badge should be set as the active, exclusive badge.
---
function SetActiveBadgeExclusive(unit)
	if not active_badge and not unit then return end
	if active_badge and active_badge.unit == unit then return end

	if active_badge and active_badge.unit and IsValid(active_badge.unit) then
		active_badge:SetActive(false, "exclusive")
		active_badge = false
	end
	if unit and unit.ui_badge then
		unit.ui_badge:SetActive(true, "exclusive")
		active_badge = unit.ui_badge
	end
end

---
--- Iterates over all combat badges and calls the provided function for each valid combat badge.
---
--- @param func function The function to call for each valid combat badge.
---
function ForEachCombatBadge(func)
	if not g_Units then return end
	for i, u in ipairs(g_Units) do
		if u.ui_badge and u.ui_badge.window_state ~= "destroying" then
			func(u.ui_badge)
		end	
	end
end

local function lUpdateAllBadges()
	ForEachCombatBadge(function(b)
		if b.active then
			b:UpdateActive()
		end
		if b.selected then
			b:UpdateSelected()
		end
		if b.mode == "enemy" then
			b:UpdateEnemyVisibility()
		end
	end)
end

---
--- Updates all combat badges.
---
--- This function is responsible for updating the state of all combat badges. It calls the `lUpdateAllBadges` function after a small delay to ensure that all necessary updates are performed.
---
--- @function UpdateAllBadges
--- @return nil
function UpdateAllBadges()
	DelayedCall(0, lUpdateAllBadges)
end

local function lUpdateAllBadgesAndModes()
	ForEachCombatBadge(function(b)
		b:UpdateMode()
		if b.active then
			b:UpdateActive()
		end
		if b.selected then
			b:UpdateSelected()
		end
		b:UpdateEnemyVisibility()
		-- Some effects are only visible in combat/exploration
		ObjModified(b.unit.StatusEffects)
	end)
end

---
--- Updates all combat badges and their modes.
---
--- This function is responsible for updating the mode and state of all combat badges. It calls the `lUpdateAllBadgesAndModes` function after a small delay to ensure that all necessary updates are performed.
---
--- @function UpdateAllBadgesAndModes
--- @return nil
function UpdateAllBadgesAndModes()
	DelayedCall(0, lUpdateAllBadgesAndModes)
end

---
--- Updates the visibility of all combat badges in "enemy" mode.
---
--- This function is responsible for updating the visibility of all combat badges that are in "enemy" mode. It iterates over all combat badges and calls the `UpdateEnemyVisibility()` method on each badge that is in "enemy" mode.
---
--- @function UpdateEnemyVisibility
--- @return nil
function UpdateEnemyVisibility()
	ForEachCombatBadge(function(b)
		if b.mode == "enemy" then
			b:UpdateEnemyVisibility()
		end
	end)
end

function OnMsg.VisibilityUpdate()
	local pov_team = GetPoVTeam()
	ForEachCombatBadge(function(b)
		if b.unit.team ~= pov_team then
			-- visible only if the pov team has LOS to the unit (what about range?)
			b:SetVisible(VisibilityGetValue(pov_team, b.unit), "visibility")
		end
	end)
end

OnMsg.ExplorationStart = UpdateAllBadgesAndModes
OnMsg.TurnStart = UpdateAllBadgesAndModes
OnMsg.CombatStarting = UpdateAllBadgesAndModes
OnMsg.CombatEndAfterAwarenessReset = UpdateAllBadgesAndModes
OnMsg.EndTurn = UpdateAllBadges
OnMsg.TeamsUpdated = UpdateAllBadgesAndModes
OnMsg.UnitMovementDone = UpdateEnemyVisibility
OnMsg.VisibilityUpdate = UpdateAllBadges
OnMsg.RepositionStart = UpdateAllBadgesAndModes
OnMsg.RepositionEnd = UpdateAllBadgesAndModes
OnMsg.ExecutionControllerDeactivate = UpdateAllBadgesAndModes
OnMsg.EnemySighted = function(_, enemy)
	if enemy and enemy.ui_badge then
		enemy.ui_badge:UpdateMode()
		if enemy.ui_badge == "enemy" then
			enemy.ui_badge:UpdateEnemyVisibility()
		end
	end
end

function OnMsg.UnitSideChanged(unit)
	if unit and unit.ui_badge then
		unit.ui_badge:UpdateMode()
	end
end

function OnMsg.UnitStanceChanged(unit)
	if unit and unit.ui_badge then
		unit.ui_badge:InvalidateLayout()
	end
end

function OnMsg.SelectionChange()
	ForEachCombatBadge(function(b)
		b:SetSelected(table.find(Selection, b.unit))
		if b.mode == "enemy" then
			b:UpdateEnemyVisibility()
		end
	end)
end

function OnMsg.UnitAwarenessChanged(obj)
	if obj.ui_badge and obj.ui_badge.mode == "enemy" then
		obj.ui_badge:UpdateEnemyVisibility()
	end
end

function OnMsg.UnitDieStart(unit)
	DeleteBadgesFromTargetOfPreset("CombatBadge", unit)
	DeleteBadgesFromTargetOfPreset("NpcBadge", unit)
end

function OnMsg.VillainDefeated(unit)
	if unit and unit.ui_badge then
		unit.ui_badge:UpdateMode()
	end
end

function OnMsg.UnitDowned(unit)
	if unit and unit.ui_badge then
		unit.ui_badge:UpdateMode()
		unit.ui_badge:UpdateEnemyVisibility() -- updates death chance text
	end
end

function OnMsg.OnDownedRally(medic, unit)
	if unit and unit.ui_badge then
		unit.ui_badge:UpdateMode()
		unit.ui_badge:UpdateEnemyVisibility() -- updates death chance text
	end
end

--- Updates the level indicator icon for the combat badge.
---
--- If the badge is in "enemy" mode, the icon is set to the enemy role icon.
--- If the badge is in "friend" mode, the icon is set to the mercenary level icon.
--- The size of the icon is adjusted based on the mode.
---
--- @param self CombatBadge The combat badge instance.
function CombatBadge:UpdateLevelIndicator()
	local iconWin = self.idMercIcon
	if self.mode == "enemy" then
		local unit = self.unit
		iconWin:SetImage(GetEnemyIcon(unit.role or "Default"))
		if iconWin.MinWidth ~= 32 then
			iconWin:SetMinWidth(32)
			iconWin:SetMaxWidth(32)
			iconWin:SetMinHeight(36)
			iconWin:SetMaxHeight(36)
		end
	else
		iconWin:SetImage(GetMercIcon("merc", self.unit:GetLevel()))
		if iconWin.MinWidth ~= 31 then
			iconWin:SetMinWidth(31)
			iconWin:SetMaxWidth(31)
			iconWin:SetMinHeight(40)
			iconWin:SetMaxHeight(40)
		end
	end
end

--- Returns the icon file path for the specified enemy role.
---
--- @param role string The enemy role.
--- @return string The icon file path.
function GetEnemyIcon(role)
	local rolePreset = Presets.EnemyRole.Default and Presets.EnemyRole.Default[role]
	local file = rolePreset and rolePreset.BadgeIcon or "UI/Hud/enemy_head"
	return file
end

--- Returns the icon file path for the specified mercenary level.
---
--- @param prefix string The prefix for the icon file name.
--- @param level number The mercenary level.
--- @return string The icon file path.
function GetMercIcon(prefix, level)
	local iconLevel = Min(level, 10)
	iconLevel = iconLevel < 10 and "0" .. tostring(iconLevel) or tostring(iconLevel)
	return "UI/Hud/" .. prefix .. "_level_" .. iconLevel
end

function OnMsg.UnitLeveledUp(unit)
	if IsKindOf(unit, "Unit") and IsValid(unit) and unit.ui_badge and unit.ui_badge.window_state ~= "destroying" and unit.ui_badge.mode == "friend" then
		unit.ui_badge:UpdateLevelIndicator()
	end
	
	PlayFX("activityMercLevelup", "start")
end

-- Disable badge mouse interaction in movement mode
-- (IModeCombatMovement - choosing a movement pos)
if FirstLoad then
	MapVar("BadgesMovementMode", false)
end

--- Returns the mouse target, unless the movement mode is active, in which case it returns nil.
---
--- @param pt table The point to check for a mouse target.
--- @return table|nil The mouse target, or nil if the movement mode is active.
function CombatBadge:GetMouseTarget(pt)
	if BadgesMovementMode then return end
	return XContextWindow.GetMouseTarget(self, pt)
end

function OnMsg.UIMovementModeChanged(on)
	BadgesMovementMode = on
end