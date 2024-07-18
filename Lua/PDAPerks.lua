--- Returns a sorted list of unique perk stat values.
---
--- This function filters the `CharacterEffectDefs` table to find all perk definitions,
--- and then extracts the unique stat values for perks that have a tier of "Bronze",
--- "Silver", or "Gold". The resulting list is sorted.
---
--- @return table A sorted list of unique perk stat values.
function GetPerkStatAmountGroups()
	local perks = table.filter(CharacterEffectDefs, function(k, v)
		return v.object_class == "Perk"
	end)
	
	local groups = {}
	for k, perk in pairs(perks) do
		if perk.Stat and perk.StatValue and table.find({"Bronze", "Silver", "Gold"}, perk.Tier) then
			table.insert_unique(groups, perk.StatValue)
		end
	end
	table.sort(groups)
	return groups
end

-- context uses UnitData
DefineClass.PDAPerks = {
	__parents = { "XDialog" },
	
	unit = false,
	SelectedPerkIds = false,
	PerkPoints = 0,
	totalPerks = 0
}

---
--- Determines if a perk can be unlocked for the given unit.
---
--- @param unit table The unit for which to check the perk unlock conditions.
--- @param perk table The perk definition to check.
--- @return boolean True if the perk can be unlocked, false otherwise.
---
function PDAPerks:CanUnlockPerk(unit, perk)
	if unit[perk.Stat] < perk.StatValue then
		return false
	else
		local x = 0
		for _, perkId in ipairs(self.SelectedPerkIds) do
			local aPerk = CharacterEffectDefs[perkId]
			if aPerk.Stat == perk.Stat and aPerk.Tier ~= perk.Tier and aPerk.Tier ~= "Gold" then
				x = x + 1
			end
		end
		
		if perk.Tier == "Silver" and #unit:GetPerksByStat(perk.Stat) + x < const.RequiredPerksForSilver then
			return false
		elseif perk.Tier == "Gold" and #unit:GetPerksByStat(perk.Stat) + x < const.RequiredPerksForGold then
			return false
		else
			return true
		end
	end
end

---
--- Selects or deselects a perk for the current unit.
---
--- @param perkId string The ID of the perk to select or deselect.
--- @param selected boolean True to select the perk, false to deselect it.
---
function PDAPerks:SelectPerk(perkId, selected)
	if not self.SelectedPerkIds then
		self.SelectedPerkIds = {}
	end
	local oldPerks = {}
	local newPerks = {}
	if selected then
		oldPerks = self:CurrentlyAvailablePerks()
		table.insert(self.SelectedPerkIds, perkId)
		self.PerkPoints = self.PerkPoints - 1
	else
		table.remove_entry(self.SelectedPerkIds, perkId)
		self.PerkPoints = self.PerkPoints + 1
		self:CheckPerkSelection(perkId)
	end
	
	self:ResolveId("idPerksContent"):RespawnContent()
	
	if selected then
		newPerks = self:CurrentlyAvailablePerks()
		local newAvailablePerks = table.subtraction(newPerks, oldPerks)
		if next(newAvailablePerks) then
			--create effect for newly added perks
			CreateRealTimeThread(function(perksDlg)
				for _, perk in ipairs(newAvailablePerks) do
					local perkWindowId = "id" .. perk.id
					local perkUI = perksDlg:ResolveId("idPerksContent"):ResolveId("idPerksScrollArea"):ResolveId(perkWindowId)
					perkUI:ResolveId("idPerkLearned"):SetVisible(false)
					perkUI:SetTransparency(255)
					perkUI:SetTransparency(0, 300)
				end
			end, self)
		end
	end
	
	local evaluation = self:ResolveId("node")
	local toolbar = evaluation:ResolveId("idToolBar")
	toolbar:RebuildActions(evaluation)
end

---
--- Returns a table of all perks that are currently available for the unit to unlock.
---
--- This function checks the unit's current perk selection and returns a table of all perks that:
--- - Have an object_class of "Perk"
--- - Have a Tier of "Bronze", "Silver", or "Gold"
--- - Have not already been unlocked by the unit
--- - Can be unlocked by the unit based on the CanUnlockPerk function
--- - Are not currently selected by the unit
---
--- @return table A table of perk definitions that are currently available for the unit to unlock.
---
function PDAPerks:CurrentlyAvailablePerks()
	local unlockablePerks = {}
	for _, perk in pairs(CharacterEffectDefs) do
		if perk.object_class == "Perk"
			and (perk.Tier == "Bronze" or perk.Tier == "Silver" or perk.Tier == "Gold")
			and not HasPerk(self.unit, perk.id)
			and self:CanUnlockPerk(self.unit, perk)
			and not table.find(self.SelectedPerkIds, perk.id) then
				table.insert(unlockablePerks, perk)
		end
	end
	return unlockablePerks
end

---
--- Checks the current perk selection and removes any perks that the unit can no longer unlock.
---
--- This function is called when a perk is deselected. It iterates through the currently selected perks and removes any that the unit can no longer unlock, such as perks with a "Gold" tier. The function also updates the unit's perk points to reflect the removed perks.
---
--- @param deselectedId string The ID of the perk that was just deselected.
---
function PDAPerks:CheckPerkSelection(deselectedId)
	local perk = CharacterEffectDefs[deselectedId]
	if perk.Tier == "Gold" then return end

	local changed = true
	while changed do
		changed = false
		for _, perkId in ipairs(self.SelectedPerkIds) do
			local aPerk = CharacterEffectDefs[perkId]
			if not self:CanUnlockPerk(self.unit, aPerk) then
				table.remove_entry(self.SelectedPerkIds, perkId)
				self.PerkPoints = self.PerkPoints + 1
				changed = true
				break
			end
		end
	end
end

---
--- Handles the confirmation of selected perks for a unit.
---
--- When a unit confirms their perk selection, this function is called to apply the selected perks to the unit's data. It updates the unit's perk points and adds the selected perks as status effects. It also animates the selected perks in the perks layout UI and triggers a "PerksLearned" message.
---
--- @param unit_id string The ID of the unit whose perks are being confirmed.
--- @param selectedPerks table A table of perk IDs that the unit has selected.
---
function NetSyncEvents.ConfirmPerks(unit_id, selectedPerks)
	local unitData = gv_UnitData[unit_id]
	local unit = g_Units[unit_id]
	
	for _, perkId in ipairs(selectedPerks) do
		unitData:AddStatusEffect(perkId)
		unitData.perkPoints = unitData.perkPoints - 1
		if unit then -- manual update to Unit
			unit:AddStatusEffect(perkId)
			unit.perkPoints = unit.perkPoints - 1
		end
	end
	
	CreateRealTimeThread(function() -- Animate selected perks
		ObjModified(unitData)
		ObjModified(unit)
		local _, perksDlg = WaitMsg("PerksLayoutDone")
		for _, perkId in ipairs(selectedPerks) do
			local perkWindowId = "id" .. perkId
			perksDlg:ResolveId("idPerksContent"):ResolveId("idPerksScrollArea"):ResolveId(perkWindowId):Animate()
		end
		PlayFX("activityPerkLevelup", "start")
	end)

	TutorialHintsState.LevelUp = true
	Msg("PerksLearned", unitData, selectedPerks)
end

---
--- Confirms the selected perks for a unit.
---
--- When a unit confirms their perk selection, this function is called to apply the selected perks to the unit's data. It updates the unit's perk points and adds the selected perks as status effects. It also animates the selected perks in the perks layout UI and triggers a "PerksLearned" message.
---
--- @param self PDAPerk The PDAPerk instance.
---
function PDAPerks:ConfirmPerks()
	if not self.SelectedPerkIds then return end
	local unitData = self.unit
	NetSyncEvent("ConfirmPerks", unitData.session_id, self.SelectedPerkIds)
end

DefineClass.PDAAIMEvaluation = {
	__parents = { "XDialog" },
	mercIdsArray = {},
	selectedMercArrayId = false,
}

---
--- Opens the PDAAIMEvaluation dialog and initializes it with the list of hired mercenaries.
---
--- If a unit is provided in the dialog mode parameter, the dialog will select that unit. Otherwise, it will select the first mercenary in the list.
---
--- The initial mode of the dialog is set based on the dialog mode parameter, falling back to "record" if no mode is provided.
---
--- @param self PDAAIMEvaluation The PDAAIMEvaluation instance.
---
function PDAAIMEvaluation:Open()
	self.mercIdsArray = GetHiredMercIds()
	self.selectedMercArrayId = 1
	
	local mode_param = GetDialogModeParam(self.parent) or GetDialogModeParam(GetDialog("PDADialog")) or GetDialog("PDADialog").context
	if mode_param and mode_param.unit then
		self:SelectMerc(mode_param.unit)
	end
	
	self.InitialMode = mode_param and mode_param.sub_page or "record"
	
	XDialog.Open(self)
end

---
--- Selects the next mercenary in the list of hired mercenaries.
---
--- If the currently selected mercenary is the last one in the list, the selection wraps around to the first mercenary. Otherwise, the selection moves to the next mercenary in the list.
---
--- The selected mercenary is then passed to the `SelectMerc` function to update the dialog context.
---
--- @param self PDAAIMEvaluation The PDAAIMEvaluation instance.
---
function PDAAIMEvaluation:SelectNextMerc()
	if self.selectedMercArrayId == #self.mercIdsArray then 
		self.selectedMercArrayId = 1
	else
		self.selectedMercArrayId = self.selectedMercArrayId + 1
	end
	
	local unit = gv_UnitData[self.mercIdsArray[self.selectedMercArrayId]]
	self:SelectMerc(unit)
end

---
--- Selects the previous mercenary in the list of hired mercenaries.
---
--- If the currently selected mercenary is the first one in the list, the selection wraps around to the last mercenary. Otherwise, the selection moves to the previous mercenary in the list.
---
--- The selected mercenary is then passed to the `SelectMerc` function to update the dialog context.
---
--- @param self PDAAIMEvaluation The PDAAIMEvaluation instance.
---
function PDAAIMEvaluation:SelectPrevMerc()
	if self.selectedMercArrayId == 1 then
		self.selectedMercArrayId = #self.mercIdsArray
	else
		self.selectedMercArrayId = self.selectedMercArrayId - 1
	end
	
	local unit = gv_UnitData[self.mercIdsArray[self.selectedMercArrayId]]
	self:SelectMerc(unit)
end

---
--- Selects the specified mercenary and updates the dialog context.
---
--- If the specified mercenary is the currently selected mercenary, the "stats" tab is activated in the record view.
---
--- @param self PDAAIMEvaluation The PDAAIMEvaluation instance.
--- @param unit table The unit data for the selected mercenary.
---
function PDAAIMEvaluation:SelectMerc(unit)
	local index = table.find(self.mercIdsArray, unit.session_id)
	self.selectedMercArrayId = index
	
	local record = self:ResolveId("idRecord")
	local oldMode = record and record.Mode
	
	self:SetContext(unit)
	
	if oldMode and oldMode == "stats" then
		self:ResolveId("idRecord"):ResolveId("idStatsTab"):OnPress()
	end
end

---
--- Opens the character screen for the specified unit, with an optional sub-mode.
---
--- If a full-screen game dialog is open, it is closed. If the current interface mode is a combat attack mode, the interface mode is set to either combat movement or exploration mode.
---
--- The PDA dialog is opened or set to the "browser" mode, with the "evaluation" sub-page and the specified unit's data.
---
--- @param unit table The unit data for the character to display.
--- @param subMode string The optional sub-mode to display in the PDA dialog.
---
function OpenCharacterScreen(unit, subMode)
	local full_screen = GetDialog("FullscreenGameDialogs")
	if full_screen and full_screen.window_state == "open" then
		full_screen:Close()
	end

	local dlg = GetInGameInterfaceModeDlg()
	if IsKindOf(dlg, "IModeCombatAttackBase") then
		SetInGameInterfaceMode(g_Combat and "IModeCombatMovement" or "IModeExploration", {suppress_camera_init = true})
	end

	local pda = GetDialog("PDADialog")
	local mode_param = { browser_page = "evaluation", sub_page = subMode }
	if IsMerc(unit) then
		mode_param.unit = gv_UnitData[unit.session_id]
	end
	
	if not pda then
		mode_param.Mode = "browser"
		pda = OpenDialog("PDADialog", GetInGameInterface(), mode_param )
		return
	end

	if pda.Mode ~= "browser" then
		pda:SetMode("browser", mode_param)
		return
	end
	
	if pda.idContent.Mode ~= "evaluation" then
		pda.idContent:SetMode("evaluation", mode_param)
		return
	end
end