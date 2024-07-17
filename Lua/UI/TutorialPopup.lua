DefineClass.TutorialPopupClass = {
	__parents = { "XPopup" },
	
	visible_reasons = false,
	forced_direction = false,
	
	textContent = false,
	preset = false
}

--- Updates the text content of the TutorialPopup based on the current preset.
---
--- If a preset is defined, the function will retrieve the appropriate text content
--- (either GamepadText or Text) and set it on the idText element of the popup.
--- The text is also translated using the textContext of the popup.
---
--- @param self TutorialPopupClass The instance of the TutorialPopupClass.
function TutorialPopupClass:UpdateText()
	local preset = self.preset
	if not preset then return end

	local text = GetUIStyleGamepad() and preset.GamepadText or preset.Text
	local ctx = SubContext(self.textContext, { em = "<color EmStyleBlue>" })
	text = text and Untranslated(_InternalTranslate(text, ctx))
	self.idText:SetText(text)
end

function OnMsg.TranslationChanged()
	if CurrentTutorialPopup then
		CurrentTutorialPopup:UpdateText()
	end
end

local function lGetOverlapping(popup)
	if RolloverWin and not popup:IsWithin(RolloverWin) and BoxIntersectsBox(popup.idContent.box, RolloverWin.box) then
		return true
	end
	
	local igi = GetInGameInterfaceModeDlg()
	local startBut = igi and igi:ResolveId("idStartButton")
	local startMenuOpen = startBut and startBut.desktop.modal_window
	if startMenuOpen and startMenuOpen.Id == "idStartMenu" then
		if BoxIntersectsBox(popup.idContent.box, startMenuOpen.box) then
			return true
		end
	end
	
	local th = GetCurrentTalkingHead()
	if th and BoxIntersectsBox(popup.idContent.box, th.box) then
		return true
	end
	return false
end

--- Opens the TutorialPopup and creates a thread to observe for overlapping UI elements.
---
--- The thread will continuously check if the TutorialPopup is overlapping with any other UI elements
--- such as the rollover window, the start menu, or the talking head. If an overlap is detected,
--- the TutorialPopup will be hidden temporarily until the overlap is resolved.
---
--- Once the overlap is resolved, the TutorialPopup will be made visible again.
---
--- @param self TutorialPopupClass The instance of the TutorialPopupClass.
function TutorialPopupClass:Open()
	XPopup.Open(self)
	self:CreateThread("rollover-observer", function()
		while self.window_state ~= "destroying" do
			local wasHidden = false
			local overlapping = lGetOverlapping(self)
			while overlapping do
				self:SetVisible(false, false, "rollover")
				WaitMsg("DestroyRolloverWindow", 500)
				Sleep(300)
				wasHidden = true
				overlapping = lGetOverlapping(self)
			end
			if wasHidden then Sleep(500) end

			self:SetVisible(true, false, "rollover")
			WaitMsg("CreateRolloverWindow", 500)
		end
	end)
end

--- Sets the visibility of the TutorialPopup.
---
--- This function manages the visibility of the TutorialPopup based on various reasons. It maintains a table of visible reasons, where each reason can be set to true or false. The popup is only visible if all reasons are true.
---
--- @param self TutorialPopupClass The instance of the TutorialPopupClass.
--- @param vis boolean Whether the popup should be visible or not.
--- @param time number (optional) The time in milliseconds for the visibility change to take effect.
--- @param reason string (optional) The reason for the visibility change. If not provided, "base" is used.
function TutorialPopupClass:SetVisible(vis, time, reason)
	if not self.visible_reasons then self.visible_reasons = { ["base"] = true } end
	reason = reason or "base"
	
	self.visible_reasons[reason] = vis
	
	local anyReasonsNo = false
	for i, value in pairs(self.visible_reasons) do
		if not value then
			anyReasonsNo = true
			break
		end
	end
	
	local shouldBeVisible = not anyReasonsNo
	local isVisible = self:GetVisible()
	if isVisible ~= shouldBeVisible then
		XPopup.SetVisible(self, shouldBeVisible, time)
	end
end

---
--- Updates the layout of the TutorialPopupClass.
---
--- This function is responsible for positioning the TutorialPopup within the safe area of the screen, taking into account the anchor point, margins, and arrow positioning. It determines the optimal position for the popup based on the available space and sets the box and arrow properties accordingly.
---
--- @param self TutorialPopupClass The instance of the TutorialPopupClass.
---
function TutorialPopupClass:UpdateLayout()
	--if not self.layout_update then return end
	
	local margins_x1, margins_y1, margins_x2, margins_y2 = ScaleXY(self.scale, self.Margins:xyxy())
	local anchor = self:GetAnchor()
	local safe_area_x1, safe_area_y1, safe_area_x2, safe_area_y2 = self:GetSafeAreaBox()
	local x, y = self.box:minxyz()
	local width, height = self.measure_width - margins_x1 - margins_x2, self.measure_height - margins_y1 - margins_y2
	
	local space = anchor:minx() - safe_area_x1 - width - margins_x2
	local a_type = "left"
	if space < safe_area_x2 - anchor:maxx() - width - margins_x1 then
		space = safe_area_x2 - anchor:maxx() - width - margins_x1
		a_type = "right"
	elseif space < anchor:miny() - safe_area_y1 - height - margins_y2 then
		space = anchor:miny() - safe_area_y1 - height - margins_y2
		a_type = "top"
	elseif space < safe_area_y2 - anchor:maxy() - height - margins_y1 then
		space = safe_area_y2 - anchor:maxy() - height - margins_y1
		a_type = "bottom"
	end
	
	if self.forced_direction then
		a_type = self.forced_direction
	end
	
	local arrowX, arrowY = 20, 30
	arrowX, arrowY = ScaleXY(self.scale, arrowX, arrowY)
	
	if a_type == "left" then
		x = anchor:minx() - width - margins_x2
		y = anchor:miny() - height - margins_y2 + arrowY * 2

		self.idArrow:SetHAlign("right")
		self.idArrow:SetVAlign("bottom")
		self.idArrow:SetFlipX(true)
		self.idArrow:SetFlipY(false)
		self.idArrow:SetAngle(0)
		self.idArrow:SetMargins(box(0, 0, 0, 30))
	elseif a_type == "right" then
		x = anchor:maxx() + margins_x1
		y = anchor:miny() - height - margins_y2 + arrowY * 2
		
		self.idArrow:SetHAlign("left")
		self.idArrow:SetVAlign("bottom")
		self.idArrow:SetFlipX(false)
		self.idArrow:SetFlipY(false)
		self.idArrow:SetAngle(0)
		self.idArrow:SetMargins(box(0, 0, 0, 30))
	elseif a_type == "right-top" then
		x = anchor:maxx() + margins_x1
		y = anchor:miny() - height - margins_y2 + arrowY * 2
		
		self.idArrow:SetHAlign("left")
		self.idArrow:SetVAlign("top")
		self.idArrow:SetFlipX(false)
		self.idArrow:SetFlipY(false)
		self.idArrow:SetAngle(0)
		self.idArrow:SetMargins(box(0, 30, 0, 0))
		
		a_type = "right"
	elseif a_type == "top" then
		x = anchor:minx() - margins_x1 - arrowX
		y = anchor:miny() - height
		
		self.idArrow:SetHAlign("left")
		self.idArrow:SetVAlign("bottom")
		self.idArrow:SetFlipX(false)
		self.idArrow:SetFlipY(false)
		self.idArrow:SetAngle(-90 * 60)
		self.idArrow:SetMargins(box(30, 0, 0, 0))
	elseif a_type == "bottom" then
		x = anchor:minx() - margins_x1 - arrowX
		y = anchor:maxy() + margins_y2
		
		self.idArrow:SetHAlign("left")
		self.idArrow:SetVAlign("top")
		self.idArrow:SetFlipX(false)
		self.idArrow:SetFlipY(false)
		self.idArrow:SetAngle(90 * 60)
		self.idArrow:SetMargins(box(30, 0, 0, 0))
	elseif a_type == "top-center-no-arrow" then
		x = anchor:minx() - abs(anchor:minx() + width / 2 - (anchor:minx() + anchor:sizex() / 2))
		y = anchor:miny() - height
		
		self.idArrow:SetVisible(false)
	end
	
	-- fit window to safe area
	if x + width + margins_x2 > safe_area_x2 then
		x = safe_area_x2 - width - margins_x2
	elseif x < safe_area_x1 then
		x = safe_area_x1
	end
	if y + height + margins_y2 > safe_area_y2 then
		y = safe_area_y2 - height - margins_y2
	elseif y < safe_area_y1 then
		y = safe_area_y1
	end
	
	-- layout
	self:SetBox(x, y, width, height)
	XControl.UpdateLayout(self)
end

DefineClass.TutorialPopupDialog = {
	__parents = {"XDialog"},
	ZOrder = 2,
	FocusOnOpen = false
}

---
--- Opens the TutorialPopupDialog.
--- If the "CombatUIHidden" cheat is enabled, the dialog is set to be invisible.
---
--- @function TutorialPopupDialog:Open
--- @return nil
function TutorialPopupDialog:Open()
	XDialog.Open(self)

	if CheatEnabled("CombatUIHidden") then
		self:SetVisible(false)
	end
end

if FirstLoad then
CurrentTutorialPopup = false
CanShowTutorialPopup = true
end

---
--- Closes the currently open tutorial popup, optionally skipping the delay before allowing another popup to be shown.
---
--- @param skipDelay boolean Whether to skip the delay before allowing another popup to be shown.
--- @return nil
function CloseCurrentTutorialPopup(skipDelay)
	skipDelay = true -- force no delay after closing popup to prevent edge cases where next popup would not show (waiting for desing decion if queue needs to be added for all those that would try to be shown during the pause after a close of popup)
	if CurrentTutorialPopup and CurrentTutorialPopup.window_state ~= "destroying" then
		CurrentTutorialPopup:Close()
	end
	CurrentTutorialPopup = false
	if skipDelay then
		CanShowTutorialPopup = true
		Msg("TutorialPopupClosed")
	else
		local dlg = EnsureDialog("TutorialPopupDialog")
		dlg:DeleteThread("EnablePopupsDelay")
		dlg:CreateThread("EnablePopupsDelay", function()
			Sleep(1000)
			CanShowTutorialPopup = true
			Msg("TutorialPopupClosed")
		end)
	end
end

---
--- Returns the ID of the currently open tutorial popup.
---
--- @return string|nil The ID of the currently open tutorial popup, or `nil` if no popup is open.
function GetCurrentOpenedTutorialId()
	return CurrentTutorialPopup and CurrentTutorialPopup.idText and CurrentTutorialPopup.idText.context.id
end

---
--- Opens a tutorial popup on the screen.
---
--- @param onWindow boolean|nil The window or UI element to anchor the popup to.
--- @param parent Dialog|nil The parent dialog for the popup.
--- @param preset TutorialPreset The preset configuration for the popup.
--- @param textContext table|nil Additional context information for the popup text.
--- @return TutorialPopup|boolean The opened tutorial popup, or `false` if the popup could not be opened.
function OpenTutorialPopup(onWindow, parent, preset, textContext)
	local onWindow = onWindow or false
	if not preset then return false end
	if not preset:IsRelatedToCurrentCampaign() then return false end
	local enabled_option = GetAccountStorageOptionValue("HintsEnabled")
	if not enabled_option then
		return false
	end
	
	if not HasAnyMercsControlled() then
		return -- Do not show popups for "spectator"
	end
	
	if not CanShowTutorialPopup then
		return
	end
	
	--do not show popup tutorial if dissmised or special cases like Aiming
	local state = TutorialHintsState.mode[preset.id]
	if preset.id ~= "Aiming" and preset.id ~= "APRanOut" and state == "dismissed" then
		return false
	end
	
	parent = parent or EnsureDialog("TutorialPopupDialog")
	
	local popup = XTemplateSpawn("TutorialPopup", parent, preset)
	
	if preset.StaticPopup then
		local dlg = GetInGameInterfaceModeDlg()
		local logBtn = dlg and dlg:ResolveId("idCombatLogButton")
		local cmdBtn = dlg and dlg:ResolveId("idStartButton")
		popup.idArrow:SetVisible(false)
		
		if cmdBtn then
			popup.forced_direction = "top"
			onWindow = cmdBtn
		elseif logBtn then
			popup.forced_direction = "bottom"
			onWindow = logBtn
		else
			assert(false, "Cannot find place to attach static tutorial.")
		end
	end
	
	if onWindow then
		popup:SetAnchorType("smart")
		popup:SetAnchor(onWindow.box)
	end
	popup.idTitle:SetText(T(630309726328, "TUTORIAL"))
	
	popup:Open()
	popup:SetVisible(true)
	popup.preset = preset
	popup.textContext = textContext
	popup:UpdateText()
	CurrentTutorialPopup = popup
	CanShowTutorialPopup = false
	return popup
end

---
--- Opens a tutorial popup on the satellite map.
---
--- @param onWindow table|nil The UI element to anchor the popup to
--- @param parent table|nil The parent dialog for the popup
--- @param preset table The preset configuration for the popup
--- @param textContext table|nil Additional text context for the popup
--- @return table|false The opened popup, or false if it couldn't be opened
---
function OpenTutorialPopupSatelliteMap(onWindow, parent, preset, textContext)
	if not preset then return false end
	if not preset:IsRelatedToCurrentCampaign() then return false end
	local enabled_option = GetAccountStorageOptionValue("HintsEnabled")
	if not enabled_option then
		return false
	end
	
	if not CanShowTutorialPopup then
		return
	end
	
	--do not show popup tutorial if dismissed or special cases like Aiming
	local state = TutorialHintsState.mode[preset.id]
	if preset.id ~= "Aiming" and state == "dismissed" then
		return false
	end

	if not parent then
		parent = GetDialog("PDADialogSatellite")
		parent = parent and parent:ResolveId("idTutorialPopup")
	end
	
	local popup = XTemplateSpawn("TutorialPopup", parent, preset)
	
	if preset.StaticPopup then
		local dlg = GetInGameInterfaceModeDlg()
		local logBtn = dlg and dlg:ResolveId("idCombatLogButton")
		local cmdBtn = dlg and dlg:ResolveId("idStartButton")
		popup.idArrow:SetVisible(false)
		
		if cmdBtn then
			popup.forced_direction = "top"
			onWindow = cmdBtn
		elseif logBtn then
			popup.forced_direction = "bottom"
			onWindow = logBtn
		else
			assert(false, "Cannot find place to attach static tutorial.")
		end
	end
	
	if onWindow then
		popup:SetAnchorType("smart")
		popup:SetAnchor(onWindow.box)
	end
	popup.idTitle:SetText(T(630309726328, "TUTORIAL"))

	popup:Open()
	popup.preset = preset
	popup.textContext = textContext
	popup:UpdateText()
	if IsKindOf(onWindow, "XMapRolloverable") then
		onWindow:SetupMapSafeArea(popup)
		popup:CreateThread("update-pos", function()
			while popup.window_state ~= "destroying" do
				onWindow:SetupMapSafeArea(popup)
				popup:InvalidateLayout()
				Sleep(16)
			end
		end)
	end	
	popup:SetVisible(true)
	
	CurrentTutorialPopup = popup
	CanShowTutorialPopup = false
	return popup
end

local function lGetWindowOfMerc(merc_id)
	local partyUI = GetInGameInterfaceModeDlg()
	partyUI = partyUI and partyUI:ResolveId("idParty")
	partyUI = partyUI and partyUI:ResolveId("idPartyContainer")
	partyUI = partyUI and partyUI:ResolveId("idParty")
	partyUI = partyUI and partyUI:ResolveId("idContainer")
	local idx
	if partyUI then
		idx = table.findfirst(partyUI, function(idx, mem) return mem.context and mem.context.session_id == merc_id end)
	end	 
	return idx and partyUI[idx]
end

local function lShowAPPopup(preset, unit, presetNameOverride)
	while not unit:CanBeControlled() do
		Sleep(200)
	end
	local minAp = const["Action Point Costs"].Walk
	if unit.ActionPoints >= minAp then
		return --handle edge case where ending turn while finishing action would result in reaching this point in next turn when the unit has new ap
	end
	if TutorialHintsState[presetNameOverride or preset.id] then return end
	
	local windowOfMerc = lGetWindowOfMerc(unit.session_id)
	if not windowOfMerc then return end
	
	local isTutorial = preset.id == "LevelUpPopup"
	local attachUI = false
	if isTutorial then
		attachUI = windowOfMerc.idLevelUp
	else
		attachUI = windowOfMerc.idAPIndicator
	end
	if not attachUI or not g_Combat then return end
	
	local popup = OpenTutorialPopup(attachUI, false, preset, unit)
	if not popup then return end
	popup:CreateThread("hide-when-not-turn", function(unit)
		while popup.window_state ~= "destroying" and popup.window_state ~= "closing" do
			local shouldBeVisible = IsNetPlayerTurn() and not IsRepositionPhase()
			local isVisible = not not popup:IsVisible()
			if shouldBeVisible ~= isVisible then
				popup:SetVisible(shouldBeVisible)	
			end
			
			if isTutorial and GetDialog("PDADialog") or (not isTutorial and not g_Combat) or SelectedObj ~= unit then
				CloseCurrentTutorialPopup()
			end
			
			Sleep(100)
		end
	end, unit)
	TutorialHintsState[presetNameOverride or preset.id] = true
end

function OnMsg.CombatActionEnd(unit)
	if not unit:IsLocalPlayerControlled() then return end
	if not g_Combat then return end
	if not IsNetPlayerTurn() then return end
	
	local minAp = const["Action Point Costs"].Walk
	if unit.ActionPoints < minAp then
		PlayFX("UnitOutOfAP", "start")
		local preset = TutorialHints.APRanOut
		if TutorialHintsState.APRanOut then return end
		CreateMapRealTimeThread(lShowAPPopup, preset, unit)
	else
		local preset = TutorialHints.APUsage
		if TutorialHintsState.APUsage then return end
		CreateMapRealTimeThread(lShowAPPopup, preset, unit)
	end
end

function OnMsg.SelectedObjChange()
	if IsValidThread(g_CombatActionEndThread) then return end -- Auto unit switch
	
	if SelectedObj and g_Combat and not TutorialHintsState.APRanOut_Selection then
		if SelectedObj.ActionPoints < const["Action Point Costs"].Walk then
			CreateMapRealTimeThread(function()
				Sleep(100)
				if SelectedObj then
					lShowAPPopup(TutorialHints.APRanOut, SelectedObj, "APRanOut_Selection")
				end
			end)
		end
	end
end

function OnMsg.SelectionChange()
	ShowBandageTutorial()
end

function OnMsg.DamageDone()
	ShowBandageTutorial()
end

function OnMsg.TurnEnded(teamId)
	local t = g_Teams and g_Teams[teamId]
	if t and t.side == NetPlayerSide() then
		CloseCurrentTutorialPopup("skipDelay")
		TutorialHintsState.MoraleChange = TutorialHintsState.MoraleChangeShown and true
		TutorialHintsState.Bombard = TutorialHintsState.BombardShown and true
	end
end

local function lSatelliteViewUnpauseTutorial()
	local satDiag = GetDialog("PDADialogSatellite")
	local parent = satDiag and satDiag:ResolveId("idTutorialPopup")
	local unpauseButton = satDiag and satDiag:ResolveId("idContent")
	unpauseButton = unpauseButton and unpauseButton:ResolveId("idSpeedControls")
	if not parent or not unpauseButton then return end
	
	local preset = TutorialHints.SatelliteTimeControl
	local popup = OpenTutorialPopup(unpauseButton, parent, preset)
	if not popup then return end
	popup.forced_direction = "top"
	popup:CreateThread("wait-unpause", function()
		WaitMsg("SatelliteTick")
		CloseCurrentTutorialPopup()
	end)
end

function OnMsg.OpenSatelliteView()
	if Game.CampaignTime ~= Game.CampaignTimeStart or not InitialConflictNotStarted() then return end
	CreateRealTimeThread(lSatelliteViewUnpauseTutorial) -- We need ui to layout
end


function OnMsg.OpenSatelliteView()
	CloseCurrentTutorialPopup("skipDelay")
	CreateRealTimeThread(function()
		Sleep(1) -- wait for the layout to finish so that the tutorials are correctly attached
		ShowTrainMilitiaTutorial()
		ShowWoundedTutorial()
		MineDepletingTutorial()
		ShowSatViewFinances()
	end)
	
	if not TutorialHintsState.TravelPlaced and Game and Game.Campaign == "HotDiamonds" then
		local canShow = gv_InitialHiringDone and gv_Sectors and not gv_Sectors.I1.conflict and gv_Sectors.I1.Side == "player1"
		if not canShow then return end
		
		local preset = TutorialHints.SatelliteTravelToErnie
		local ernieSectorWindow = g_SatelliteUI.sector_to_wnd["H2"]
		local popup = OpenTutorialPopupSatelliteMap(ernieSectorWindow, false, preset)
		if not popup then return end
		popup:CreateThread("wait-unpause", function()
			while popup.window_state ~= "destroying" and popup.window_state ~= "closing" do
				if TutorialHintsState.TravelPlaced then
					CloseCurrentTutorialPopup()
				end
				Sleep(100)
			end
		end)
	end
end

function OnMsg.CloseSatelliteView()
	CloseCurrentTutorialPopup("skipDelay")
	TutorialHintsState.OutpostShields = TutorialHintsState.OutpostShieldsShown and true
	TutorialHintsState.MineDepleting = TutorialHintsState.MineDepletingShown and true
	TutorialHintsState.SatViewFinances = TutorialHintsState.SatViewFinancesShown and true
end

function OnMsg.UnitLeveledUp(unit)
	if not unit:IsLocalPlayerControlled() then return end
	
	local preset = TutorialHints.LevelUpPopup
	if TutorialHintsState.LevelUpPopup then return end
	CreateMapRealTimeThread(lShowAPPopup, preset, unit)
end

---
--- Shows a tutorial popup for the stealth mechanic in the game.
---
--- The popup is anchored to the "idHideButtonFrame" UI element in the "InGameInterfaceModeDlg" dialog.
--- The popup is forced to display at the top of the screen and is attached to the action bar.
--- The combat bar hiding animation is applied while the popup is displayed.
---
--- The popup is closed if the "idHideButtonFrame" UI element is no longer present, if any player-controlled units are in a "Hidden" status effect, or if combat starts.
---
--- @return nil
function ShowStealthTutorialPopup()
	if TutorialHintsState.StealthPopup then return end
	local igi = GetInGameInterfaceModeDlg()
	local stealthFrame = igi and igi:ResolveId("idHideButtonFrame")
	if not stealthFrame then return end
	
	local preset = TutorialHints.StealthPopup
	local popup = OpenTutorialPopup(stealthFrame, false, preset)
	if not popup then return end
	TutorialHintsState.StealthPopup = true
	popup.forced_direction = "top"
	popup.attachedToAB = true
	ApplyCombatBarHidingAnimation(igi:ResolveId("idBottomBar"), true, true)
	
	local mercs = GetAllPlayerUnitsOnMap()
	popup:CreateThread("check-hidden", function()
		while popup.window_state ~= "destroying" and popup.window_state ~= "closing" do
			local igi = GetInGameInterfaceModeDlg()
			local stealthFrame = igi and igi:ResolveId("idHideButtonFrame")
			if not stealthFrame then
				CloseCurrentTutorialPopup()
			else
				popup:SetAnchor(stealthFrame.box)
				popup:InvalidateLayout()
			end
			
			for i, m in ipairs(mercs) do
				if m:HasStatusEffect("Hidden") then
					CloseCurrentTutorialPopup()
				end
			end
			
			if g_Combat then
				CloseCurrentTutorialPopup()
			end
			
			Sleep(100)
		end
	end)
end

local function FindItemWnd(id, ref)
	local itemWindow
	local itemCtrl
	local slots = GetMercInventoryDlg() and GetMercInventoryDlg().slots or {}
	for slot_ctrl, val in pairs(slots) do
		if IsKindOf(slot_ctrl, "BrowseInventorySlot") then
			local unit = slot_ctrl:GetContext()
			unit:ForEachItemInSlot("Inventory", id, function(item, slot, l, t, slot_ctrl)
				if (not ref or ref == item.id) and not itemWindow then
					itemWindow = slot_ctrl:FindItemWnd(item)
					itemCtrl = slot_ctrl
				end
			end, slot_ctrl)
			if itemWindow then
				break
			end
		end
	end
	return itemWindow, itemCtrl
end

local function lInventoryPopupValuableItem()		
	local preset = TutorialHints.ValuableItem
	local itemWdw, itemCtrl = FindItemWnd("TinyDiamonds")
	local itemRef = itemWdw and itemWdw.context.id
	if not itemRef then return end
	local popup = OpenTutorialPopup(itemWdw, GetDialog(itemWdw):ResolveId("idDlgContent"), preset)
	if not popup then return end
	popup:CreateThread("observe", function()
		while popup.window_state ~= "destroying" and popup.window_state ~= "closing" do
			local itemWdw, itemCtrl = FindItemWnd("TinyDiamonds", itemRef)
			itemRef = itemWdw and itemWdw.context.id
			local isInsideScrollArea = itemCtrl and itemRef and itemCtrl.parent.parent.box:Point2DInside(point(itemWdw.box:minx(), itemWdw.box:miny()))
			if not isInsideScrollArea then
				popup:SetVisible(false)
			elseif itemWdw then
				popup:SetAnchor(itemWdw.box)
				popup:InvalidateLayout()
				popup:SetVisible(true)
			end
			if TutorialHintsState.ValuableItem then
				CloseCurrentTutorialPopup()
			end
			Sleep(16)
		end
		CloseCurrentTutorialPopup()
	end)
end

function OnMsg.OpenInventorySubDialog(autoResolve)
	if not autoResolve then CloseCurrentTutorialPopup("skipDelay") end
	local unitFromCurrentSquad = g_CurrentSquad and gv_Squads[g_CurrentSquad] and gv_Squads[g_CurrentSquad].units and gv_Squads[g_CurrentSquad].units[1]
	if unitFromCurrentSquad and HasItemInSquad(unitFromCurrentSquad, "TinyDiamonds", 1) and not TutorialHintsState.ValuableItem then
		CreateRealTimeThread(lInventoryPopupValuableItem)
	end
	if unitFromCurrentSquad and HasItemInSquad(unitFromCurrentSquad, "Combination_BalancingWeight", 1) 
	and HasItemInSquad(unitFromCurrentSquad, "Knife", 1) and not TutorialHintsState.Combine then
		CreateRealTimeThread(CombineTutorial)
	end
end

function OnMsg.RespawnedInventory()
	local unitFromCurrentSquad = g_CurrentSquad and gv_Squads[g_CurrentSquad] and gv_Squads[g_CurrentSquad].units and gv_Squads[g_CurrentSquad].units[1]
	if IsInventoryOpened() and unitFromCurrentSquad and HasItemInSquad(unitFromCurrentSquad, "TinyDiamonds", 1) then
		CreateRealTimeThread(lInventoryPopupValuableItem)
	end
end

function OnMsg.CloseInventorySubDialog(autoResolve)
	if not autoResolve then
		CloseCurrentTutorialPopup("skipDelay")
	end
end

function OnMsg.CashInItem(item)
	if item.class == "TinyDiamonds" then
		TutorialHintsState.ValuableItem = true
	end
end

local function IsHudActionAvailable(actionId)
	local dlg = GetInGameInterfaceModeDlg()
	local actions = dlg and dlg:ResolveId("idCombatActionsContainer")

	for _, hudBtn in ipairs(actions) do
		if hudBtn.Id == actionId and hudBtn.enabled then
			return hudBtn
		end
	end
	return false
end

---
--- Shows a tutorial popup for the sneak mode.
---
--- @param unit table The unit that triggered the tutorial.
---
function ShowSneakModeTutorialPopup(unit)
	if not unit or unit:HasStatusEffect("Hidden") then return end
	if TutorialHintsState.SneakMode then return end
	local igi = GetInGameInterfaceModeDlg()
	local stealthFrame = igi and igi:ResolveId("idHideButtonFrame")
	if not stealthFrame then return end
	
	local preset = TutorialHints.SneakMode
	local popup = OpenTutorialPopup(stealthFrame, false, preset)
	if not popup then return end
	popup.forced_direction = "top"
	popup.attachedToAB = true
	ApplyCombatBarHidingAnimation(igi:ResolveId("idBottomBar"), true, true)
	
	popup:CreateThread("sneakMode-hide", function(unit)
		while popup.window_state ~= "destroying" and popup.window_state ~= "closing" do

			if TutorialHintsState.SneakMode or unit:HasStatusEffect("Hidden") or not unit.marked_target_attack_args then
				CloseCurrentTutorialPopup()
			end
			Sleep(100)
		end
	end, unit)
end

---
--- Shows a tutorial popup for the sneak approach mode.
---
--- @param unit table The unit that triggered the tutorial.
---
function ShowSneakApproachTutorialPopup(unit)
	if not unit or not unit:HasStatusEffect("Hidden") then return end
	if TutorialHintsState.SneakApproach then return end
	
	if GetCurrentOpenedTutorialId() == "SneakMode" then
		CloseCurrentTutorialPopup("noDelay")
	end
	local preset = TutorialHints.SneakApproach
	local popup = OpenTutorialPopup(nil, false, preset)
	if not popup then return end
	
	popup:CreateThread("sneakAppproach-hide", function(unit)
		while popup.window_state ~= "destroying" and popup.window_state ~= "closing" do
			if TutorialHintsState.SneakApproach or g_Combat or not unit.marked_target_attack_args then
				CloseCurrentTutorialPopup()
			end
			Sleep(100)
		end
	end, unit)
end

function OnMsg.UnitStealthChanged(unit)
	if unit and unit.marked_target_attack_args then
		ShowSneakApproachTutorialPopup(unit)
	end
end

---
--- Checks if there are any unread tutorials.
---
--- @return boolean true if there are unread tutorials, false otherwise
---
function UnreadTutorials()
	local currentHints = TutorialGetHelpMenuHints()
	local readTable = TutorialHintsState and TutorialHintsState.read or empty_table
	for _, hint in pairs(currentHints) do
		if not readTable[hint.id] then 
			return true
		end
	end
	return false
end

function OnMsg.SetpieceEnded(setpiece)
	if Game and setpiece.id == "FlagHillLanding" then
		ShowControlsExplorationTutorial()
	end
end

---
--- Shows a tutorial popup that explains the controls for exploration.
---
--- The tutorial popup will be shown until the player moves a unit, or the popup is closed manually.
---
--- @param none
--- @return none
---
function ShowControlsExplorationTutorial()
	if not TutorialHintsState or TutorialHintsState.ControlsExploration then return end

	local preset = TutorialHints.ControlsExploration
	local popup = OpenTutorialPopup(nil, false, preset)
	if not popup then return end

	local unitMovedAt
	popup:CreateThread("observe-popup", function()
		while popup.window_state ~= "destroying" and popup.window_state ~= "closing" do
			if TutorialHintsState.ControlsExploration then
				CloseCurrentTutorialPopup()
			end
			
			unitMovedAt = unitMovedAt or (TutorialHintsState.FirstMove and RealTime())
			if unitMovedAt and unitMovedAt + 4 * 1000 <= RealTime() then
				TutorialHintsState.ControlsExploration = true
				CloseCurrentTutorialPopup()
			end
			Sleep(100)
		end
	end)
end

function OnMsg.NewMapLoaded()
	CurrentTutorialPopup = false
	CanShowTutorialPopup = true
end

function OnMsg.TurnStart(team)
	local teamData = g_Teams[team]
	if teamData and teamData.player_team then
		ShowControlsCombatTutorial()
	end
end

---
--- Shows a tutorial popup that explains the controls for combat.
---
--- The tutorial popup will be shown until the player moves a unit, or the popup is closed manually.
---
--- @param none
--- @return none
---
function ShowControlsCombatTutorial()
	if TutorialHintsState.ControlsCombat then return end

	local preset = TutorialHints.ControlsCombat
	local popup = OpenTutorialPopup(nil, false, preset)
	if not popup then return end
	local openedAt = GameTime()
	local unitMovedAt
	popup:CreateThread("observe-popup", function()
		while popup.window_state ~= "destroying" and popup.window_state ~= "closing" do
			if TutorialHintsState.ControlsCombat then
				CloseCurrentTutorialPopup()
			end
			
			local moveTable = table.values(gv_MercsLastMoveTime)
			local unitMovedAt = unitMovedAt or moveTable[table.findfirst(moveTable, function(mercId, movedAt) return movedAt > openedAt end)]
			if unitMovedAt then
				TutorialHintsState.ControlsCombat = true
				CloseCurrentTutorialPopup()
			end
			Sleep(100)
		end
	end)
end

function OnMsg.CombatActionStart(unit)
	if g_Combat and unit and unit:IsMerc() and g_CurrentTeam and g_Teams[g_CurrentTeam].control == "UI" and not s_CameraMoveLockReasons["grunty perk"] then
		TutorialHintsState.ControlsCombat = true
	end
end

---
--- Shows a tutorial popup that explains the transition to the satellite view.
---
--- The tutorial popup will be shown until the player closes it manually.
---
--- @param none
--- @return none
---
function ShowSatViewTutorial()
	if TutorialHintsState.SatViewTransition then return end
	
	local dlg = GetInGameInterfaceModeDlg()
	local cmdBtn = dlg and dlg:ResolveId("idStartButton")

	local preset = TutorialHints.SatViewTransition
	local popup = OpenTutorialPopup(cmdBtn, false, preset)
	if not popup then return end
	popup.forced_direction = "top"
	
	TutorialHintsState.SatViewTransition = true
end

---
--- Shows a tutorial popup that explains how to train militia.
---
--- The tutorial popup will be shown until the player closes it manually or the conditions for showing the tutorial are no longer met.
---
--- @param none
--- @return none
---
function ShowTrainMilitiaTutorial()
	if TutorialHintsState.TrainMilitia then return end
	
	if IsConflictMode(gv_CurrentSectorId) or gv_CurrentSectorId ~= "H2" or not g_CurrentSquad or not gv_Squads[g_CurrentSquad] or gv_Squads[g_CurrentSquad].Retreat then
		return
	end
	
	local dlg = GetDialog("PDADialogSatellite")
	local operationsBtn = dlg and dlg:ResolveId("idContent"):ResolveId("idTimeInner"):ResolveId("idOperationsBtn")

	local preset = TutorialHints.TrainMilitia
	local popup = OpenTutorialPopupSatelliteMap(operationsBtn, false, preset)
	if not popup then return end
	TutorialHintsState.TrainMilitiaShown = true

	popup:CreateThread("observe-popup", function()
		while popup.window_state ~= "destroying" and popup.window_state ~= "closing" do
			if TutorialHintsState.TrainMilitia then
				CloseCurrentTutorialPopup()
			end
			Sleep(100)
		end
	end)
end

--- Checks if the conditions are met to show the attack squad tutorial popup.
---
--- @param squad table The squad to check the conditions for.
--- @return none
function CheckAttackSquadCondition(squad)
	if GetDialog("SectorOperations") or GetDialog("PopupNotification") then 
		return 
	end
	if not TutorialHintsState.AttackSquad and squad and (squad.Side == "enemy1" or squad.Side == "enemy2") and g_SatelliteUI and squad.guardpost then
		local endDest = squad.route and squad.route[1][#squad.route[1]]
		if endDest then
			ShowAttackSquadTutorial(endDest)
		end
	end
end

---
--- Shows a tutorial popup that explains how to attack an enemy squad.
---
--- The tutorial popup will be shown when the player's squad is approaching an enemy squad's guard post.
---
--- @param endDest string The ID of the sector where the enemy squad's guard post is located.
--- @return none
---
function ShowAttackSquadTutorial(endDest) 
	if TutorialHintsState.AttackSquad then return end
	
	local endDestWindow = g_SatelliteUI and g_SatelliteUI.sector_to_wnd[endDest]

	local preset = TutorialHints.AttackSquad
	local popup = OpenTutorialPopupSatelliteMap(endDestWindow, false, preset, { sector_id = endDest})
	if not popup then return end
	TutorialHintsState.AttackSquad = true
end

---
--- Shows a tutorial popup that explains how to bandage a wounded merc.
---
--- The tutorial popup will be shown when the player has a merc with low health and the Bandage action is available.
---
--- @param none
--- @return none
---
function ShowBandageTutorial()
	if TutorialHintsState.Bandage then return end
	local isMercHurt = PlayerHasALowHealthMerc.__eval()
	if not isMercHurt then return end
	local dlg = GetInGameInterfaceModeDlg()
	local bandageBtn = IsHudActionAvailable("Bandage")

	if not bandageBtn then return end
	local preset = TutorialHints.Bandage
	local popup = OpenTutorialPopup(bandageBtn, false, preset)
	if not popup then return end
	popup.forced_direction = "top"
	popup.attachedToAB = true
	if bandageBtn then
		ApplyCombatBarHidingAnimation(dlg:ResolveId("idBottomBar"), true)
	end
	
	popup:CreateThread("observe-popup", function()
		while popup.window_state ~= "destroying" and popup.window_state ~= "closing" do
			local isMercHurt = PlayerHasALowHealthMerc.__eval()
			local dlg = GetInGameInterfaceModeDlg()
			local bandageBtn = IsHudActionAvailable("Bandage")

			if not isMercHurt then
				CloseCurrentTutorialPopup()
			elseif bandageBtn then
				popup:SetAnchor(bandageBtn.box)
				popup:InvalidateLayout()
			elseif not bandageBtn then
				CloseCurrentTutorialPopup()
			end
			Sleep(100)
		end
	end)
end

function OnMsg.QuestParamChanged(questId, param, prevVal, newVal)
	if questId == "02_LiberateErnie" and param == "Completed" and not prevVal and newVal then
		TutorialHintsState.WoundedCanShow = true
	end
end

function OnMsg.OperationCompleted(operation, mercs)
	if operation.id == "TreatWounds" and GetCurrentOpenedTutorialId() == "Wounded" then
		TutorialHintsState.Wounded = true
	end
end

function OnMsg.AutoResolvedConflict() ShowWoundedTutorial() end

---
--- Shows the tutorial popup for the "Wounded" tutorial.
---
--- The tutorial popup is displayed when a merc in the player's party is wounded, and the "TrainMilitia" tutorial is not currently open and the "SectorOperationsUI" dialog is not open.
---
--- The tutorial popup is anchored to the merc's icon in the party UI, and is hidden when the "SatelliteConflict" dialog is open.
---
--- The tutorial is closed when the "Wounded" tutorial state is set to true.
---
function ShowWoundedTutorial()
	if TutorialHintsState.Wounded or not TutorialHintsState.WoundedCanShow then return end
	
	CreateRealTimeThread(function()
		local isMilitiaPopup = GetCurrentOpenedTutorialId() == "TrainMilitia"
		local operationsOpened = GetDialog("SectorOperationsUI")
		local addDelay = 0
		if isMilitiaPopup or operationsOpened then
			addDelay = 2000
		end
		
		while isMilitiaPopup or operationsOpened do
			isMilitiaPopup = GetCurrentOpenedTutorialId() == "TrainMilitia"
			operationsOpened = GetDialog("SectorOperationsUI")
			Sleep(100)
		end
	
		if not GetDialog("PDADialogSatellite") then return end
		local partyUI = GetDialog("PDADialogSatellite")
		partyUI = partyUI and partyUI:ResolveId("idContent")
		partyUI = partyUI and partyUI:ResolveId("idPartyContainer")
		partyUI = partyUI and partyUI:ResolveId("idParty")
		partyUI = partyUI and partyUI:ResolveId("idContainer")
		local mercWindow
		local idx
		if partyUI then
			idx = table.findfirst(partyUI, function(idx, mem) return mem.context and mem.context:HasStatusEffect("Wounded") end)
		end	 
		mercWindow = idx and partyUI[idx]
		if not mercWindow then return end

		Sleep(addDelay)

		local preset = TutorialHints.Wounded
		local popup = OpenTutorialPopupSatelliteMap(mercWindow, GetDialog("PDADialogSatellite"), preset)
		if not popup then return end
		popup:SetVisible(false)
		TutorialHintsState.WoundedShown = true
		
		popup:CreateThread("observe-popup", function()
			while popup.window_state ~= "destroying" and popup.window_state ~= "closing" do
				popup:SetAnchor(mercWindow.box)
				popup:SetVisible(not GetDialog("SatelliteConflict"))
				popup:InvalidateLayout()
		
				if TutorialHintsState.Wounded then
					CloseCurrentTutorialPopup()
				end
				Sleep(100)
			end
		end)
	end)
end

function OnMsg.OnEnterMapVisual()
	local sectorData = gv_Sectors[gv_CurrentSectorId]
	if sectorData and sectorData.intel_discovered then 
		ShowIntelOverviewTutorial()
	end
end

---
--- Shows the Intel Overview tutorial popup.
---
--- The tutorial popup is displayed when the player has discovered the intel for the current sector.
--- The popup is hidden when the player enters the deployment phase or when the tutorial is completed.
---
--- @function ShowIntelOverviewTutorial
--- @return nil
function ShowIntelOverviewTutorial()
	if TutorialHintsState.IntelOverview then return end
	
	local preset = TutorialHints.IntelOverview
	local popup = OpenTutorialPopup(nil, nil, preset)
	if not popup then return end
	popup:SetVisible(false)
	
	popup:CreateThread("observe-popup", function()
		while popup.window_state ~= "destroying" and popup.window_state ~= "closing" do
			if TutorialHintsState.IntelOverview then
				CloseCurrentTutorialPopup()
			else
				if gv_Deployment then
					popup:SetVisible(false)
				else
					popup:SetVisible(true)
					if g_Overview then
						TutorialHintsState.IntelOverview = true
					end
				end
			end
			Sleep(100)
		end
	end)
end

---
--- Handles the tutorial popup for the morale change event.
---
--- The tutorial popup is displayed when the player's morale changes, and is hidden when the player enters combat or the reposition phase.
--- The popup is closed automatically after 7 seconds or when the tutorial is completed.
---
--- @function MoraleChangeTutorial
--- @return nil
function MoraleChangeTutorial()
	if TutorialHintsState.MoraleChange then return end
	
	local dlg = GetInGameInterfaceModeDlg()
	local moraleWindow
	moraleWindow = dlg and dlg:ResolveId("idLeftTop")
	moraleWindow = moraleWindow and moraleWindow:ResolveId("idParty")
	moraleWindow = moraleWindow and moraleWindow:ResolveId("idPartyContainer")
	moraleWindow = moraleWindow and moraleWindow:ResolveId("idMorale")
	moraleWindow = moraleWindow and moraleWindow:ResolveId("idMoraleIcon")

	if not moraleWindow then return end
	local preset = TutorialHints.MoraleChange
	local popup = OpenTutorialPopup(moraleWindow, nil, preset)
	if not popup then return end
	popup:SetVisible(false)
	popup.forced_direction = "bottom"
	TutorialHintsState.MoraleChangeShown = true
	local openedAt
	
	local startTimer
	popup:CreateThread("observe-popup", function()
		while popup.window_state ~= "destroying" and popup.window_state ~= "closing" do
			if not startTimer and (not g_Combat or IsNetPlayerTurn()) and not IsRepositionPhase() then
				popup:InvalidateLayout()
				popup:SetVisible(true)
				openedAt = RealTime()
				startTimer = true
			end
			
			if TutorialHintsState.MoraleChange then
				CloseCurrentTutorialPopup()
			elseif startTimer and openedAt + 7 * 1000 <= RealTime() then
				TutorialHintsState.MoraleChange = true
			elseif startTimer and not popup.visible then
				openedAt = openedAt + 100
			end
			Sleep(100)
		end
	end)
end

OnMsg.MoraleChange = MoraleChangeTutorial

function OnMsg.ReachSectorCenter(squadId, sectorId)
	if sectorId == "H3" and squadId and (gv_Squads[squadId].Side == "player1" or gv_Squads[squadId].Side == "player2") then
		OutpostShieldsTutorial()
	end
end

--- Displays a tutorial popup for the outpost shields feature in the "HotDiamonds" campaign.
---
--- This function is called when the player's squad reaches the "H4" sector. It checks if the tutorial has not been shown yet, and if the current game is the "HotDiamonds" campaign. It then opens a tutorial popup on the satellite map, centered on the "H4" sector. The popup will remain visible for 7 seconds, or until the player closes it.
---
--- @param none
--- @return none
function OutpostShieldsTutorial()
	if TutorialHintsState.OutpostShields or not g_SatelliteUI then return end
	if Game and Game.Campaign ~= "HotDiamonds" then return end
	local fortWindow = g_SatelliteUI.sector_to_wnd["H4"]
	if not fortWindow then return end
	
	local preset = TutorialHints.OutpostShields
	local popup = OpenTutorialPopupSatelliteMap(fortWindow, false, preset)
	if not popup then return end
	local openedAt = RealTime()
	TutorialHintsState.OutpostShieldsShown = true
	
	popup:CreateThread("observe-popup", function()
		while popup.window_state ~= "destroying" and popup.window_state ~= "closing" do
			if TutorialHintsState.OutpostShields then
				CloseCurrentTutorialPopup()
			elseif openedAt + 7 * 1000 <= RealTime() then
				TutorialHintsState.OutpostShields = true
			elseif not popup.visible then
				openedAt = openedAt + 100
			end
			Sleep(100)
		end
	end)
end

MapVar("g_HighlightItemsTutorialThread", false)

--- Displays a tutorial popup for the "Highlight Items" feature on the "I1" sector.
---
--- This function is called to show a tutorial popup that highlights important items on the "I1" sector. The popup will remain visible until the player closes it or the "HighlightItems" tutorial state is set to true.
---
--- @param none
--- @return none
function HighlightItemsTutorial()
	DeleteThread(g_HighlightItemsTutorialThread)
	g_HighlightItemsTutorialThread = CreateRealTimeThread(function()
		Sleep(1)
		if TutorialHintsState.HighlightItems then return end
		if not gv_CurrentSectorId or gv_CurrentSectorId ~= "I1" then return end

		local preset = TutorialHints.HighlightItems
		local popup = OpenTutorialPopup(false, false, preset)
		if not popup then return end

		TutorialHintsState.HighlightItemsShown = true
		
		popup:CreateThread("observe-popup", function()
			while popup.window_state ~= "destroying" and popup.window_state ~= "closing" do
				if TutorialHintsState.HighlightItems then
					CloseCurrentTutorialPopup()
				end
				Sleep(100)
			end
		end)
	end)
end

function OnMsg.MineDepleteStart(sectorId)
	TutorialHintsState.MineDepletingStart = true 
	MineDepletingTutorial(sectorId)
end

--- Displays a tutorial popup for the "Mine Depleting" feature on the specified sector.
---
--- This function is called to show a tutorial popup that explains the mine depleting mechanic on the specified sector. The popup will remain visible for 7 seconds or until the player closes it or the "MineDepleting" tutorial state is set to true.
---
--- @param sectorId string The ID of the sector where the mine depleting tutorial should be shown.
--- @return none
function MineDepletingTutorial(sectorId)
	if TutorialHintsState.MineDepleting or not g_SatelliteUI or not TutorialHintsState.MineDepletingStart then return end
	
	local mineWindow = g_SatelliteUI.sector_to_wnd[sectorId]
	if not mineWindow then return end
	
	local preset = TutorialHints.MineDepleting
	local popup = OpenTutorialPopupSatelliteMap(mineWindow, false, preset)
	if not popup then return end
	local openedAt = RealTime()
	TutorialHintsState.MineDepletingShown = true
	
	popup:CreateThread("observe-popup", function()
		while popup.window_state ~= "destroying" and popup.window_state ~= "closing" do
			if TutorialHintsState.MineDepleting then
				CloseCurrentTutorialPopup()
			elseif openedAt + 7 * 1000 <= RealTime() then
				TutorialHintsState.MineDepleting = true
			elseif not popup.visible then
				openedAt = openedAt + 100
			end
			Sleep(100)
		end
	end)
end

--- Shows a tutorial popup for the crosshair UI element.
---
--- This function is responsible for displaying a tutorial popup that explains the aiming mechanic to the player. The popup will be shown for a short period of time and will be positioned near the crosshair UI element.
---
--- @param crosshair table The crosshair UI element that the tutorial popup should be associated with.
--- @return none
function ShowCrosshairTutorial(crosshair)
	if CurrentTutorialPopup then return end
	local cont = crosshair.idButtonsContainer
	for i, wnd in ipairs(cont) do
		wnd:OnContextUpdate()
		XRecreateRolloverWindow(wnd)
	end
	if not crosshair.aim_tutorial_shown_already and AimedAttackTutorialCondition(crosshair) then
		local popup = OpenTutorialPopup(cont, terminal.desktop, TutorialHints.Aiming)
		if not popup then return end
		crosshair.darkness_tutorial = false -- Dont show darkness tutorial too
		crosshair.aim_tutorial_shown_already = true
		popup:SetVisible(false)
		popup:DeleteThread("rollover-observer")
		popup:SetZOrder(9999999)
		
		popup:CreateThread("observer", function()
			if crosshair.window_state == "destroying" then return end
			while crosshair.idContent.layout_update do
				Sleep(1)
			end
			if crosshair.window_state == "destroying" then return end
			
			Sleep(1000)
			popup:InvalidateLayout()
			popup:SetVisible(true)
			
			while popup.window_state ~= "destroying" and popup.window_state ~= "closing" do
				if crosshair.window_state ~= "open" then
					CloseCurrentTutorialPopup()
				elseif cont.interaction_box then
					popup:SetAnchor(cont.interaction_box)
					popup:InvalidateLayout()
				end						
				
				if crosshair.aim > 0 or not crosshair:IsVisible() then
					CloseCurrentTutorialPopup()
					return
				end
				
				Sleep(20)
			end
		end)
	end
end

---
--- This function displays a tutorial popup that explains the weapon range mechanic to the player. The popup will be shown for a short period of time and will be positioned near the "idRange" UI element of the crosshair.
---
--- @param crosshair table The crosshair UI element that the tutorial popup should be associated with.
--- @return none
function WeaponRangeTutorial(crosshair)
	if TutorialHintsState.WeaponRange or TutorialHintsState.WeaponRangeShown or CurrentTutorialPopup then return end
	
	if crosshair.context.action.ActionType ~= "Ranged Attack" then return end
	local maxRange = crosshair.context.weapon_range
	local range = crosshair.context.attack_distance
	if range <= maxRange / 2 then return end
	
	local cont = crosshair.idButtonsContainer
	if not cont then return end
	for i, wnd in ipairs(cont) do
		wnd:OnContextUpdate()
		XRecreateRolloverWindow(wnd)
	end
	
	local popup = OpenTutorialPopup(cont, terminal.desktop, TutorialHints.WeaponRange)
	if not popup then return end

	popup.forced_direction = "right"
	popup:SetVisible(false)
	popup:SetZOrder(9999999)
	
	popup:CreateThread("observer", function()
		Sleep(1000)
		if crosshair.window_state == "destroying" then 
			CloseCurrentTutorialPopup()
			return
		end
		while crosshair.window_state ~= "destroying" and (not crosshair.idContent or crosshair.idContent.layout_update) do
			Sleep(1)
		end
		if crosshair.window_state == "destroying" then 
			CloseCurrentTutorialPopup()
			return
		end
		
		popup:SetAnchor(cont:ResolveId("idRange").interaction_box)
		popup:InvalidateLayout()
		
		while popup.window_state ~= "destroying" and popup.window_state ~= "closing" do
			if crosshair.window_state ~= "open" then
				CloseCurrentTutorialPopup()
			elseif TutorialHintsState.WeaponRange or not crosshair:IsVisible() then
				CloseCurrentTutorialPopup()
			elseif cont.interaction_box then
				if not popup.layout_update and not lGetOverlapping(popup) then
					popup:SetVisible(true)
					TutorialHintsState.WeaponRangeShown = true
				end
			end						
			
			Sleep(20)
		end
	end)
	
end

---
--- Displays a tutorial popup for the item combination feature.
--- This function is called when the player needs to be shown a tutorial for combining items.
--- The tutorial popup is displayed near the item window for the "Combination_BalancingWeight" item.
--- The popup is positioned and sized to remain visible as the player interacts with the item window.
--- The tutorial popup is closed when the player has completed the tutorial or the item window is no longer visible.
---
--- @param none
--- @return none
---
function CombineTutorial()
	if TutorialHintsState.Combine then return end
	local preset = TutorialHints.Combine
	local itemWdw, itemCtrl = FindItemWnd("Combination_BalancingWeight")
	local itemRef = itemWdw and itemWdw.context.id
	if not itemRef then return end
	local popup = OpenTutorialPopup(itemWdw, GetMercInventoryDlg(), preset)
	if not popup then return end
	TutorialHintsState.CombineShown = true
	popup:CreateThread("observe", function()
		while popup.window_state ~= "destroying" and popup.window_state ~= "closing" do
			local itemWdw, itemCtrl = FindItemWnd("Combination_BalancingWeight", itemRef)
			itemRef = itemWdw and itemWdw.context.id
			local isInsideScrollArea = itemCtrl and itemRef and itemCtrl.parent.parent.box:Point2DInside(itemCtrl.box:Center())
			if not isInsideScrollArea then
				popup:SetVisible(false)
			elseif itemWdw then
				popup:SetAnchor(itemWdw.box)
				popup:InvalidateLayout()
				popup:SetVisible(true)
			end
			if TutorialHintsState.Combine then
				CloseCurrentTutorialPopup()
			end
			Sleep(16)
		end
		CloseCurrentTutorialPopup()
	end)
end

function OnMsg.RunCombatAction(action_id, unit, ap)
	if action_id == "CombineItems" and TutorialHintsState.CombineShown then
		TutorialHintsState.Combine = true
	end
end

---
--- Displays a tutorial popup for the unit stance feature.
--- This function is called when the player needs to be shown a tutorial for changing unit stances.
--- The tutorial popup is displayed near the stance button in the combat UI.
--- The popup is positioned and sized to remain visible as the player interacts with the stance button.
--- The tutorial popup is closed when the player has completed the tutorial or the stance button is no longer visible.
---
--- @param none
--- @return none
---
function ShowStanceTutorial()
	if TutorialHintsState.Stance then return end
	
	local dlg = GetInGameInterfaceModeDlg()
	local stanceBtn = dlg and dlg:ResolveId("idStanceButton"):ResolveId("idStanceButtons")

	if not stanceBtn then return end
	local preset = TutorialHints.Stance
	local popup = OpenTutorialPopup(stanceBtn, false, preset)
	if not popup then return end
	popup.forced_direction = "top"
	popup.attachedToAB = true
	if stanceBtn then
		ApplyCombatBarHidingAnimation(dlg:ResolveId("idBottomBar"), true)
	end
	
	popup:CreateThread("observe-popup", function()
		while popup.window_state ~= "destroying" and popup.window_state ~= "closing" do
			local dlg = GetInGameInterfaceModeDlg()
			local stanceBtn = dlg and dlg:ResolveId("idStanceButton"):ResolveId("idStanceButtons")
			
			if not stanceBtn or TutorialHintsState.Stance or not stanceBtn:IsVisible() then
				CloseCurrentTutorialPopup()
			elseif stanceBtn then
				popup:SetAnchor(stanceBtn.box)
				popup:InvalidateLayout()
			end
			Sleep(100)
		end
	end)
end

function OnMsg.TurnStart(teamId)
	local t = g_Teams and g_Teams[teamId]
	if t and t.side == NetPlayerSide() and g_Combat.current_turn and g_Combat.current_turn > 1 then
		ShowStanceTutorial()
	end
end

function OnMsg.UnitStanceChanged(unit)
	if unit and unit.action_command == "ChangeStance" and unit:IsMerc() then
		TutorialHintsState.Stance = true
	end
end

---
--- Shows the tutorial popup for the bombard action.
---
--- This function is called to display a tutorial popup that explains the bombard action to the player.
--- The popup is displayed only if the bombard tutorial has not been shown before, as indicated by the `TutorialHintsState.Bombard` flag.
--- The popup is displayed for a short period of time and is closed automatically when the `TutorialHintsState.Bombard` flag is set to `true`.
---
--- @function ShowBombardTutorial
--- @return none
function ShowBombardTutorial()
	CreateRealTimeThread(function()
		Sleep(1)
		if TutorialHintsState.Bombard then return end

		local preset = TutorialHints.Bombard
		local popup = OpenTutorialPopup(false, false, preset)
		if not popup then return end
		TutorialHintsState.BombardShown = true
		
		popup:CreateThread("observe-popup", function()
			while popup.window_state ~= "destroying" and popup.window_state ~= "closing" do
				if TutorialHintsState.Bombard then
					CloseCurrentTutorialPopup()
				end
				Sleep(100)
			end
		end)
	end)
end

---
--- Shows the tutorial popup for the throwing action.
---
--- This function is called to display a tutorial popup that explains the throwing action to the player.
--- The popup is displayed only if the throwing tutorial has not been shown before, as indicated by the `TutorialHintsState.Throwing` flag.
--- The popup is displayed for a short period of time and is closed automatically when the `TutorialHintsState.Throwing` flag is set to `true`.
---
--- @function ShowThrowingTutorial
--- @return none
function ShowThrowingTutorial()
	if TutorialHintsState.Throwing then return end

	local preset = TutorialHints.Throwing
	local popup = OpenTutorialPopup(false, false, preset)
	if not popup then return end

	popup:CreateThread("observe-popup", function()
		while popup.window_state ~= "destroying" and popup.window_state ~= "closing" do
			if TutorialHintsState.Throwing then
				CloseCurrentTutorialPopup()
			end
			Sleep(100)
		end
	end)
end

---
--- Shows a tutorial popup for the satellite view finances.
---
--- This function is called to display a tutorial popup that explains the satellite view finances to the player.
--- The popup is displayed only if the satellite view finances tutorial has not been shown before, as indicated by the `TutorialHintsState.SatViewFinances` flag.
--- The popup is displayed for a short period of time and is closed automatically when the `TutorialHintsState.SatViewFinances` flag is set to `true`.
---
--- @function ShowSatViewFinances
--- @return none
function ShowSatViewFinances()
	if GetMoneyProjection(14) >= 0 then return end
	if gv_PlayerSectorCounts.Mine <= 0 then return end
	if TutorialHintsState.SatViewFinances then return end
	
	local dlg = GetDialog("PDADialogSatellite")
	local predictedIncomeUI = dlg and dlg:ResolveId("idContent"):ResolveId("idTimeInner"):ResolveId("idPredictedIncome")

	local preset = TutorialHints.SatViewFinances
	local popup = OpenTutorialPopupSatelliteMap(predictedIncomeUI, false, preset)
	if not popup then return end
	popup.forced_direction = "top"
	TutorialHintsState.SatViewFinancesShown = true

	popup:CreateThread("observe-popup", function()
		while popup.window_state ~= "destroying" and popup.window_state ~= "closing" do
			if TutorialHintsState.SatViewFinances then
				CloseCurrentTutorialPopup()
			end
			Sleep(100)
		end
	end)
end

---
--- Shows a tutorial popup that explains how to select all units in the player's squad.
---
--- This function is called to display a tutorial popup that teaches the player how to select all units in their squad. The popup is displayed only if the "Select All" tutorial has not been shown before, as indicated by the `TutorialHintsState.SelectAll` flag.
--- The popup is displayed for a short period of time and is closed automatically when the `TutorialHintsState.SelectAll` flag is set to `true` or when a combat event occurs.
---
--- @function ShowSelectAllTutorial
--- @return none
function ShowSelectAllTutorial()
	local mercs = GetCurrentMapUnits()
	if #mercs <= 1 then return end
	if TutorialHintsState.SelectAll then return end
	
	local dlg = GetInGameInterfaceModeDlg()
	local onWindow = dlg:ResolveId("idParty"):ResolveId("idPartyContainer"):ResolveId("idSquadButtons")
	local preset = TutorialHints.SelectAll
	
	local popup = OpenTutorialPopup(onWindow, nil, preset)
	if not popup then return end
	TutorialHintsState.SelectAllShown = true
	
	popup.forced_direction = "right-top"
	
	popup:CreateThread("observe-popup", function()
		while popup.window_state ~= "destroying" and popup.window_state ~= "closing" do
			if TutorialHintsState.SelectAll or g_Combat then
				CloseCurrentTutorialPopup()
			end
			Sleep(100)
		end
	end)
end

function OnMsg.CombatEnd()
	if TutorialHintsState.SelectAllShown and TutorialHintsState.HighlightItemsShown then return end
	CreateGameTimeThread(function()
		Sleep(1000)
		ShowSelectAllTutorial()
		
		WaitMsg("TutorialPopupClosed")
		HighlightItemsTutorial()
	end)
end

function OnMsg.SelectionChange()
	if not TutorialHintsState.SelectAllShown then return end
	if TutorialHintsState.SelectAll then return end
	
	if WholeTeamSelected() then
		TutorialHintsState.SelectAll = true
	end
end

--- Checks if the player has any controlled mercenaries.
---
--- @return boolean true if the player has any controlled mercenaries, false otherwise
function HasAnyMercsControlled()
	local squads = GetPlayerMercSquads()
	for _, squad in pairs(squads) do
		for _, unitId in ipairs(squad.units) do
			local ud = gv_UnitData[unitId]
			if ud and ud:IsLocalPlayerControlled() then
				return true
			end
		end
	end
end