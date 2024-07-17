MapVar("g_GamepadTarget", false)

-- Works alongside the current IModeCommonUnitControl to provide gamepad support
DefineClass.GamepadUnitControl = {
	__parents = { "InterfaceModeDialog" },
	gamepad_thread = false,
	world_cursor = false,
	world_cursor_visible = false,

	move_button_down_time = false,
	last_potential_target = false,
	potential_interactable_gamepad_resolved = false
}

DefineClass.GamepadWorldCursor = {
	__parents = { "SpawnFXObject" },
	flags = { gofAlwaysRenderable = true },
}

---
--- Attaches the `GamepadWorldCursor` object to the specified `obj`.
--- This sets the object's component flags, special orientation, and game flags to make it always renderable.
---
--- @param obj table The object to attach the `GamepadWorldCursor` to.
---
function GamepadWorldCursor:Attach(obj)
	CObject.Attach(self, obj)
	obj:AddComponentFlags(const.cofComponentExtraTransform)
	obj:SetSpecialOrientation(const.soGamepadCursor)
	obj:SetGameFlags(const.gofAlwaysRenderable)
end

---
--- Initializes the gamepad world cursor object and attaches it to the interface.
--- The world cursor is a visual representation of the cursor position on the game world,
--- and is used to provide feedback to the player when using a gamepad.
---
--- This function creates the `GamepadWorldCursor` object, sets its position to the current
--- cursor position, and attaches it to a container window in the interface. The container
--- window is created if it doesn't already exist, and is positioned in the center of the
--- screen.
---
--- @param self table The `GamepadUnitControl` object instance.
---
function GamepadUnitControl:InitializeWorldCursor()
	assert(not self.world_cursor)
	if self.world_cursor then return end

	local wObj = PlaceObject("GamepadWorldCursor")--PlaceSingleTileStaticContourMesh(RGB(255, 255,255), nil, true)
	wObj:SetPos(GetCursorPos())
	self.world_cursor = wObj
	
	local cursorImageContainer = self.idGamepadCenterAnchor
	if not cursorImageContainer then
		cursorImageContainer = XTemplateSpawn("XWindow", self)
		cursorImageContainer:SetId("idGamepadCenterAnchor")
		cursorImageContainer:SetZOrder(-100)
		cursorImageContainer:SetHAlign("center")
		cursorImageContainer:SetVAlign("center")
		cursorImageContainer:SetLayoutMethod("VList")
		cursorImageContainer:SetMinWidth(80)
		cursorImageContainer:SetMaxWidth(80)
		if self.window_state == "open" then cursorImageContainer:Open() end
	end

	local cursorAttachedUI = XTemplateSpawn("XPopup", self)
	cursorAttachedUI:SetId("idGamepadAttached")
	cursorAttachedUI:SetMargins(box(10, 0, 0, 0))
	cursorAttachedUI:SetAnchorType("right")
	cursorImageContainer.OnLayoutComplete = function()
		cursorAttachedUI:SetAnchor(cursorImageContainer.box)
	end
	cursorImageContainer:InvalidateLayout()
	cursorAttachedUI:SetBackground(RGBA(0, 0, 0, 0))
	cursorAttachedUI:SetBorderWidth(0)
	--cursorAttachedUI:AddDynamicPosModifier({id = "attached_ui", target = wObj})
	if self.window_state == "open" then cursorAttachedUI:Open() end
end

---
--- Clears the world cursor object and its associated UI elements.
---
--- This function removes the `GamepadWorldCursor` object and closes the `idGamepadAttached` UI element that is attached to it. This is typically called when the gamepad UI mode is deactivated or the world cursor is no longer needed.
---
--- @param self table The `GamepadUnitControl` object instance.
---
function GamepadUnitControl:ClearWorldCursor()
	if not self.world_cursor then return end

	DoneObject(self.world_cursor)
	self.world_cursor = false
	
	if self.idGamepadAttached then
		self.idGamepadAttached:Close()
	end
end

local function lUpdateGamepadThread()
	local igi = GetInGameInterfaceModeDlg()
	if not IsKindOf(igi, "GamepadUnitControl") then 
		if GetUIStyleGamepad() then
			ForceHideMouseCursor("GamepadActive")
		else
			UnforceHideMouseCursor("GamepadActive")
		end	
		return 
	end
	if GetUIStyleGamepad() then
		-- Remove the mouse rollover from where the mouse is.
		if terminal.desktop then
			terminal.desktop:MouseEvent("OnMousePos", terminal.GetMousePos())
		end	
		igi:ResumeGamepadThread()
	else
		igi:StopGamepadThread()
	end
end

function OnMsg.GamepadUIStyleChanged()
	-- This needs to be delayed due to ReloadLua calling GamepadUIStyleChanged
	DelayedCall(0, lUpdateGamepadThread)
end

---
--- Stops the gamepad thread and clears the world cursor.
---
--- This function stops the gamepad thread, clears the world cursor, resets the gamepad target, spawns helper texts, unlocks the camera, sets the gamepad selection target to false, focuses the action bar, and restores the camera tac move speed and gamepad UI settings.
---
--- @param self table The `GamepadUnitControl` object instance.
---
function GamepadUnitControl:StopGamepadThread()
	if IsValidThread(self.gamepad_thread) then DeleteThread(self.gamepad_thread) end
	
	self:ClearWorldCursor()
	
	g_GamepadTarget = false
	self:SpawnHelperTexts()
	hr.CameraTacMoveSpeed = CameraTacMoveSpeed
	UnlockCamera("ActionBarGamepad")
	self:GamepadSelectionSetTarget(false)
	self:FocusActionBar(false)
	
	ObjModified("combat_bar")
	ObjModified("combat_bar_enemies")
	UnforceHideMouseCursor("GamepadActive")
	ObjModified(APIndicator)
	table.restore(hr, "gamepad-ui", true)
end

---
--- Resumes the gamepad thread and initializes the world cursor.
---
--- This function creates a new real-time thread that calls `ThreadProc()` on each frame while the window is not being destroyed. It also initializes the world cursor, modifies the combat bar and AP indicator, forces the mouse cursor to be hidden, and changes some gamepad UI settings.
---
--- @param self table The `GamepadUnitControl` object instance.
--- @param start boolean (optional) Whether this is the initial start of the gamepad thread.
---
function GamepadUnitControl:ResumeGamepadThread(start)
	if IsValidThread(self.gamepad_thread) then return end
	self.gamepad_thread = CreateRealTimeThread(function()
		while self.window_state ~= "destroying" do
			self:ThreadProc()
			WaitNextFrame()
		end
	end)
	
	self:InitializeWorldCursor()

	ObjModified("combat_bar")
	--if not Platform.trailer and not start and not gv_SatelliteView then OpenCombatLog() end
	ForceHideMouseCursor("GamepadActive")
	ObjModified(APIndicator)
	table.change(hr, "gamepad-ui", {CameraTacMouseEdgeScrolling = false, GamepadPreciseSelectionPos = 1})
	self.show_world_ui = true
	g_RolloverShowMoreInfo = true
end

---
--- Opens the GamepadUnitControl interface and resumes the gamepad thread.
---
--- This function sets the gamepad selection target to false, moves the camera to the selected unit's position, opens the InterfaceModeDialog, and resumes the gamepad thread if the UI style is set to gamepad.
---
--- @param self table The `GamepadUnitControl` object instance.
---
function GamepadUnitControl:Open()
	self:GamepadSelectionSetTarget(false)

	-- Move camera to the selected unit.
	local unit = Selection and Selection[1]
	local pos, lookat, t, zoom, props
	if unit then
		pos = unit:GetPos()
	else
		pos = point30
	end
	
	InterfaceModeDialog.Open(self)
	if not GetUIStyleGamepad() then return end
	self:ResumeGamepadThread("start")
end

local easingCubic = GetEasingIndex("Cubic out")
---
--- This function is responsible for the main gamepad thread logic. It handles the following:
--- - Hiding/showing the gamepad cursor based on various conditions
--- - Updating the target for the gamepad cursor
--- - Handling combat movement mode and updating lines of fire
--- - Showing/hiding tips for the gamepad cursor based on the current target
--- - Adjusting the camera speed based on the distance to the current interactable object
--- - Spawning helper texts for various gamepad actions (attack, select, move, etc.)
--- - Hiding the helper texts when the camera tac mode is not active or the focus is in another UI
---
--- @param self table The `GamepadUnitControl` object instance.
function GamepadUnitControl:ThreadProc()
	local combatAttackMode = IsKindOf(self, "IModeCombatAttackBase")
	local hideGamePadCursor = IsSetpiecePlaying() or
									gv_SatelliteView or
									#Selection == 0 or
									(SelectedObj and not SelectedObj:CanBeControlled()) or
									CurrentActionCamera or
									(combatAttackMode and self.crosshair) or
									(GetDialog("PhotoMode") and GetDialog("PhotoMode").isWorldUIHidden)

	self.world_cursor:SetVisible(not hideGamePadCursor)
	self.world_cursor_visible = not hideGamePadCursor
	if not self.visible then return end
	
	local cursorPos = GetCursorPos(self.movement_mode and "walkable")
	
	--self.world_cursor:SetPos(cursorPos) --done via special orientation
	
	if self.UpdateTarget then
		self:UpdateTarget(cursorPos)
	end

	local combatMovementMode = false
	local combatMovementIgi = IsKindOf(self, "IModeCombatMovement")
	if combatMovementIgi then
		self:UpdateLinesOfFire()
		combatMovementMode = g_Combat and self.movement_mode
	end

	-- Show/Hide tip
	local target = self.potential_target
	local interactable = self.potential_interactable
	local lastPotentialTarget = self.last_potential_target
	local lastPotentialInteractable = self.last_potential_interactable
	local potentialTargetIsSelectedUnit = false
	if lastPotentialTarget then
		potentialTargetIsSelectedUnit = table.find(Selection, lastPotentialTarget)
	end
	
	if not not lastPotentialTarget ~= not not target then
		if target then
			PlayFX("GamepadCursorOverUnit", "start", self.world_cursor)
		else
			PlayFX("GamepadCursorOverUnit", "end", self.world_cursor)
		end
	end
	
	if not target and not not lastPotentialInteractable ~= not not interactable then
		if interactable then
			PlayFX("GamepadCursorOverInteractable", "start", self.world_cursor)
		else
			PlayFX("GamepadCursorOverInteractable", "end", self.world_cursor)
		end
	end
	
	self.last_potential_target = target
	self.last_potential_interactable = interactable
								
	local hintShown = false

	-- Attack detection
	if not hintShown and combatAttackMode and self.action and self.action.id == "Bandage" then
		self:SpawnHelperTexts("ButtonASmall", T(648304184409, "Bandage"))
		hintShown = true
	elseif not hintShown and combatAttackMode then
		self:SpawnHelperTexts("ButtonASmall", T(516305772518, "Attack"))
		hintShown = true
	end
	
	local settingSpeed = GetAccountStorageOptionValue("GamepadCameraMoveSpeed") or GamepadCameraTacMoveSpeed
	local cameraSpeed = settingSpeed
	local snapMaxDist = const.SlabSizeX
	local speedCap = 500
	local interactableAroundCursor = self.potential_interactable or self.potential_target
	if self.potential_interactable_gamepad_resolved then
		local obj = self.potential_interactable_gamepad_resolved[interactableAroundCursor]
		if obj then
			interactableAroundCursor = obj
		end
	end
	
	if interactableAroundCursor then
		local distToIt = cursorPos:Dist(interactableAroundCursor)
		distToIt = Min(distToIt, snapMaxDist)
		cameraSpeed = Lerp(speedCap, Max(settingSpeed / 2, speedCap), EaseCoeff(easingCubic, distToIt, snapMaxDist), snapMaxDist)
	end
	
	if Selection[1] and not hintShown then	
		local attackable = IsKindOf(target, "Unit") and target.team:IsEnemySide(Selection[1].team) and not target:IsDead()
		if attackable then
			self:SpawnHelperTexts("ButtonASmall", T(516305772518, "Attack"), target)
			hintShown = true
		end
	end
	
	-- Select/Interact/Move
	if not hintShown then
		if lastPotentialTarget and lastPotentialTarget:CanBeControlled() and not potentialTargetIsSelectedUnit then
			self:SpawnHelperTexts("ButtonASmall", T(775961618506, "Select"), lastPotentialTarget)
			if not g_CursorContour then
				--HandleMovementTileContour(false, lastPotentialTarget:GetPos(), "CombatAttack")
			end
			ContourPolylineSetColor(lastPotentialTarget, "GamepadCursor")
			hintShown = true
		elseif interactable then
			local action = interactable:GetInteractionCombatAction()
			if action then
				local closest_unit = ChooseClosestObject(Selection, interactable)
				self:SpawnHelperTexts("ButtonASmall", T{action:GetActionDisplayName(closest_unit), target = interactable, unit = closest_unit})
				hintShown = true
			end
		elseif gv_Deployment then
			self:SpawnHelperTexts({"ButtonASmall"},{T(602300303403, "Deploy merc")})
			hintShown = true
		elseif #Selection > 0 and not combatAttackMode and GetPassSlabXYZ(cursorPos) then
			if combatMovementIgi and not combatMovementMode then
				local combatPath = Selection[1] and GetCombatPath(Selection[1])
				if combatPath and table.count(combatPath.destinations) > 1 then
					self:SpawnHelperTexts("ButtonASmall", T(928032104770, "Movement Mode"))
					hintShown = true
				end
			elseif combatMovementIgi and combatMovementMode then
				self:SpawnHelperTexts({"ButtonASmall"}, {T(463014525696, "Move")})				
				hintShown = true
			else
				if #Selection > 1 then
					self:SpawnHelperTexts({"ButtonASmall"}, {T(463014525696, "Move")})				
				else
					self:SpawnHelperTexts({"ButtonASmall", "ButtonASmallHold"}, {T(463014525696, "Move"),T(657923169702, "Move squad")})				
				end					
				hintShown = true
			end
		end
	end
	
	if not cameraTac.IsActive() then
		hintShown = false
		cameraSpeed = settingSpeed
	end
	
	-- Hide if focus is in another ui like the action bar
	if terminal.desktop.keyboard_focus ~= self and not self:IsWithin(terminal.desktop.keyboard_focus) then
		hintShown = false
	end
	
	if hideGamePadCursor then
		hintShown = false
	end

	if not hintShown then
		self:SpawnHelperTexts()
	end
	hr.CameraTacMoveSpeed = cameraSpeed
end

---
--- Calculates the size of the gamepad cursor based on the distance and angle between the camera position and the target position.
---
--- @param pos Vector3 The position of the cursor.
--- @param lookat Vector3 The position the camera is looking at.
--- @param img UIElement The image element representing the cursor.
--- @return number The size of the cursor image.
function CalculateGamepadCursorSize(pos, lookat, img)
	local dz = abs(pos:z() - lookat:z())
	local d = pos:Dist(lookat)
	local aspect = MulDivRound(dz, 1000, d)	-- aspect is cos function of camera tilt angle
	
	return MulDivRound(img.parent.box:sizex(), aspect*100, 100*GetUIScale())
end

---
--- Spawns helper texts for the gamepad UI, displaying button prompts and associated text.
---
--- @param buttons table|string A table of button names or a single button name.
--- @param texts table|string A table of text strings or a single text string.
--- @param target table The target object for the helper texts.
---
function GamepadUnitControl:SpawnHelperTexts(buttons, texts, target)
	local helpText = self.idGamepadAttached and self.idGamepadAttached.idHelpText

	if not buttons then
		if helpText then
			helpText:Close()
		end
		return
	end

	if not helpText then
		helpText = XTemplateSpawn("XText", self.idGamepadAttached)
		helpText:SetId("idHelpText")
		helpText:Open()
		helpText.Clip = false
		helpText.UseClip = false
		helpText.Translate = true
		helpText.HAlign = "left"
		helpText.VAlign = "top"
		helpText:SetTextVAlign("center")
	end

	if type(buttons) ~= "table" then buttons = { buttons } end
	if IsT(texts) then texts = { texts } end 

	local textConstruct = T{""}
	for i, button in ipairs(buttons) do		
		if i ~= 1 then
			textConstruct = textConstruct .. T(420993559859, "<newline>")
		end
		textConstruct = textConstruct .. TLookupTag("<"..button..">") .. " " .. texts[i]
	end

	local apIndicator = self:ResolveId("idApIndicator")
	local apText = false
	if apIndicator and apIndicator.text_wnd then
		apText = apIndicator.text_wnd.Text
		textConstruct = textConstruct .. "\n" .. apText
		
		local dangerIcon = apIndicator.danger_icon
		if dangerIcon and dangerIcon.danger then
			textConstruct = T(684252334678, "<image UI/Hud/attack_of_opportunity 2000><newline>") .. textConstruct
		end
	end

	helpText:SetText(textConstruct)
	helpText:SetTextStyle("GamepadHint")
end

---
--- Cleans up the state of the GamepadUnitControl object when the unit control is done.
--- Handles the movement tile contour, clears the world cursor, sets the AP indicator to false with the "unreachable" state, and updates all badges.
--- If a gamepad thread is active, it is deleted.
---
function GamepadUnitControl:Done()
	HandleMovementTileContour()
	if IsValidThread(self.gamepad_thread) then
		DeleteThread(self.gamepad_thread)
	end
	self:ClearWorldCursor()
	SetAPIndicator(false, "unreachable")
	UpdateAllBadges()
end

---
--- Handles a shortcut button press event for the GamepadUnitControl object.
--- Logs a "UserInputMade" message and then delegates the shortcut handling to the InterfaceModeDialog.OnShortcut method.
---
--- @param button string The name of the shortcut button that was pressed.
--- @param source string The source of the shortcut button press.
--- @param controller_id number The ID of the controller that triggered the shortcut.
--- @return boolean The result of the InterfaceModeDialog.OnShortcut call.
---
function GamepadUnitControl:OnShortcut(button, source, controller_id)
	Msg("UserInputMade")
	return InterfaceModeDialog.OnShortcut(self, button, source, controller_id)
end

-- Check manually due to SelectFirstValidItem/SelectLastValidItem
-- checking enabled in addition to CanBeSelected
---
--- Selects the first selectable item in the given list, moving the selection in the specified direction.
---
--- @param list table The list of items to select from.
--- @param direction string The direction to move the selection, either "right" or "left".
---
function SelectFirstSelectableItemInList(list, direction)
	local itemToSelect = direction == "right" and 1 or #list
	if itemToSelect and list[itemToSelect] then
		local idx = list:NextSelectableItem(itemToSelect, 0, direction == "right" and 1 or -1)
		if idx then
			list:SetSelection(idx)
		end
	end
end
---
--- Focuses the action bar in the specified direction.
---
--- If `direction` is not provided, the action bar is hidden and the focus is set to the current window.
--- If `direction` is provided, the action bar is shown and the selection is moved in the specified direction.
---
--- @param direction string (optional) The direction to move the selection, either "right" or "left".
---
function GamepadUnitControl:FocusActionBar(direction)
	if g_GamepadTarget then return end
	
	local bottomBar = self:ResolveId("idBottomBar")
	local combatActionsBar = self:ResolveId("idCombatActionsContainer")
	
	if not direction then
		ApplyCombatBarHidingAnimation(bottomBar, false)
		--UnlockCamera("ActionBarGamepad")

		if combatActionsBar then
			combatActionsBar:SetSelection(false)
		end
		if self.window_state ~= "destroying" then self:SetFocus() end
		return
	end

	if combatActionsBar then
		combatActionsBar:SetFocus()
		
		local currentAction = self.action
		if currentAction then
			local buttonIdx = table.find(combatActionsBar, "Id", currentAction.id)
			combatActionsBar:SetSelection(buttonIdx)
			direction = false -- If already selected then dont move selection on initial focus
		end
		
		if direction then
			SelectFirstSelectableItemInList(combatActionsBar, direction)
		end

		if Selection then SnapCameraToObj(Selection[1], true) end
		
		ApplyCombatBarHidingAnimation(bottomBar, true)
		--LockCamera("ActionBarGamepad")
	end
end

---
--- Checks if the action bar is focused and unfocuses it if not.
---
--- This function is called after a delay to check if the keyboard focus is still within the action bar or stance button. If not, it unfocuses the action bar by setting the gamepad target to false.
---
--- @function GamepadUnitControl:ActionBarUnfocusCheck
--- @return nil
function GamepadUnitControl:ActionBarUnfocusCheck()
	-- Delayed call
	CreateRealTimeThread(function()
		local focus = self.desktop.keyboard_focus
		if not focus then return end
	
		local stanceButton = self:ResolveId("idStanceButton")
		local actionButtonsBar = self:ResolveId("idActionButtonsBar") 
		if not focus:IsWithin(actionButtonsBar) and not focus:IsWithin(stanceButton) then
			self:GamepadSelectionSetTarget(false)
		end
	end)
end

---
--- Sets the gamepad selection target.
---
--- This function is responsible for managing the state of the gamepad selection target. It handles the logic for setting the target, updating the UI elements, and managing the camera behavior.
---
--- @param target string|false The target to set. Can be "first", "prev", "next", or false to clear the target.
--- @return nil
function GamepadUnitControl:GamepadSelectionSetTarget(target)
	local bottomBar = self:ResolveId("idBottomBar")
	local combatActionsBar = self:ResolveId("idCombatActionsContainer")
	local signatureBar = self:ResolveId("idSignatureAbilitiesContainer")
	local hideButton = self:ResolveId("idHideButton")
	local stanceButton = self:ResolveId("idStanceButton")
	stanceButton = stanceButton and stanceButton:ResolveId("idStanceButtons")

	if not GetUIStyleGamepad() then
		target = false
	end

	if not target then
		g_GamepadTarget = false
		ObjModified("combat_bar_enemies")
		
		ApplyCombatBarHidingAnimation(bottomBar, false)
		UnlockCamera("ActionBarGamepad")

		if combatActionsBar then
			combatActionsBar:SetSelection(false)
			combatActionsBar:ShowSelected()
		end
		
		if signatureBar then
			signatureBar:SetSelection(false)
			signatureBar:ShowSelected()
		end
		
		if hideButton then
			hideButton:SetSelected(false)
		end
		
		if stanceButton then
			stanceButton:SetSelection(false)
		end
		
		if self.window_state ~= "destroying" then
			if self.desktop.keyboard_focus and self.desktop.keyboard_focus:IsWithin(bottomBar) then
				self:SetFocus()
			end
		end
		
		if cameraTac.GetIsInOverview() then
			local deployMenu = self:ResolveId("idDeployMenu")
			if deployMenu then
				deployMenu.idList:SetFocus(true)
			end
		end
		
		return
	end

	local selUnit = Selection[1]
	local allTargets = GetTargetsToShowAboveActionBarSorted(selUnit, self)
	if #allTargets == 0 then
		self:GamepadSelectionSetTarget(false)
		return
	end
	
	if not g_GamepadTarget then
		target = "first"
	end
	
	if target == "first" then
		target = allTargets[1]
	elseif target == "prev" then
		local tIdx = table.find(allTargets, g_GamepadTarget)
		if not tIdx then
			target = allTargets[#allTargets]
		else
			tIdx = tIdx - 1
			if tIdx == 0 then
				tIdx = #allTargets
			end
			target = allTargets[tIdx]
		end
	elseif target == "next" then
		local tIdx = table.find(allTargets, g_GamepadTarget)
		if not tIdx then
			target = allTargets[#allTargets]
		else
			tIdx = tIdx + 1
			if tIdx == #allTargets + 1 then
				tIdx = 1
			end
			target = allTargets[tIdx]
		end
	end
	
	if bottomBar then
		ApplyCombatBarHidingAnimation(bottomBar, true)
		LockCamera("ActionBarGamepad")
	end
	
	if not g_GamepadTarget and target and combatActionsBar then
		combatActionsBar:SetFocus()
		local firstSel = combatActionsBar:GetFirstValidItemIdx()
		combatActionsBar:SetSelection(firstSel)
	end
	
	if target then
		SnapCameraToObj(target, true)
	end
	
	g_GamepadTarget = target or false
	ObjModified("combat_bar_enemies")
end

function OnMsg.SelectionChange()
	if g_Combat then return end
	
	local igi = GetInGameInterfaceModeDlg()
	if IsKindOf(igi, "GamepadUnitControl") then
		igi:GamepadSelectionSetTarget(false)
	end
end

function OnMsg.SelectedObjChange()
	if not g_Combat then return end
	
	local igi = GetInGameInterfaceModeDlg()
	if IsKindOf(igi, "GamepadUnitControl") then
		igi:GamepadSelectionSetTarget(false)
	end
end

---
--- Determines the combat action button to use based on a priority list.
---
--- The function checks the visibility of the combat actions in the priority list
--- and returns the first one that is enabled.
---
--- @return CombatActions The combat action button to use.
---
function DetermineUnitCombatActionButtonX()
	local priorityList = {
		CombatActions.Hide,
		CombatActions.Reveal,
	}
	for i, c in ipairs(priorityList) do
		if c:GetVisibility(Selection) == "enabled" then
			return c
		end
	end
end

---
--- Gets the state of the active gamepad.
---
--- @return table, number The current gamepad state and the gamepad ID.
---
function GetActiveGamepadState()
	for i = 0, XInput.MaxControllers() - 1 do
		if XInput.IsControllerConnected(i) then
			return XInput.CurrentState[i], i
		end
	end
end

-- Overriden from common to allow checking ButtonPressTime in the XEvent call
-- and support suppressing
---
--- Handles XInput events, such as button presses and releases.
---
--- This function is called when an XInput event occurs. It updates the state of the XInput buttons, including the initial press time and repeat time. It also forwards the event to the terminal's XEvent handler.
---
--- @param action string The type of XInput event, such as "OnXButtonDown" or "OnXButtonUp".
--- @param nCtrlId number The ID of the gamepad that generated the event.
--- @param button number The button that was pressed or released.
--- @param ... any Additional arguments passed with the event.
---
function XEvent(action, nCtrlId, button, ...)
	if action == "OnXButtonDown" then
		local repeat_time = XInput.InitialRepeatButtonTimeSpecific[button] or XInput.InitialRepeatButtonTime
		local real_time = RealTime()
		XInput.LastPressTime = real_time
		XInput.ButtonPressTime[nCtrlId][button] = real_time + repeat_time
		XInput.InitialButtonPressTime[nCtrlId][button] = real_time
	end

	if not terminal.desktop.inactive then 
		if action == "OnXNewPacket" then
			procall(terminal.XEvent, action, nil, nCtrlId, ...)
		else
			procall(terminal.XEvent, action, button, nCtrlId, ...)
		end
	end

	-- repeat support
	if action == "OnXButtonUp" then
		XInput.ButtonPressTime[nCtrlId][button] = nil
		XInput.InitialButtonPressTime[nCtrlId][button] = nil
	end
end

DefineConstInt("Default", "GamePadButtonHoldTime", 300)

---
--- Checks if a gamepad button has been held down for a specified duration.
---
--- @param button number The button to check.
--- @param time number (optional) The minimum time in milliseconds the button must be held down. Defaults to `const.GamePadButtonHoldTime`.
--- @return boolean True if the button has been held down for the specified time, false otherwise.
---
function IsXInputHeld(button, time)
	local time = time or const.GamePadButtonHoldTime
	local gamepadState, gamepadId = GetActiveGamepadState()
	local pressTime = gamepadState and XInput.InitialButtonPressTime[gamepadId]
	pressTime = pressTime and pressTime[button]
	local timeWasPressed = pressTime and RealTime() - pressTime

	return timeWasPressed and timeWasPressed >= time
end

---
--- Suppresses the button up hold check for the specified gamepad button.
---
--- This function is used to prevent the `IsXInputHeld` function from detecting a button hold for the specified button. It clears the button's press time from the `XInput.InitialButtonPressTime` and `XInput.ButtonPressTime` tables.
---
--- @param button number The button to suppress the hold check for.
---
function XInputSuppressButtonUpHoldCheck(button)
	local gamepadState, gamepadId = GetActiveGamepadState()
	local pressTime = gamepadState and XInput.InitialButtonPressTime[gamepadId]
	if pressTime and pressTime[button] then
		pressTime[button] = nil
	end
	
	pressTime = XInput.ButtonPressTime[gamepadId]
	if pressTime and pressTime[button] then
		pressTime[button] = nil
	end
end

MapVar("GamepadStaggeredFloorChangeThread", false)

GamepadFloorChangeStaggerTime = 500

---
--- Moves the camera's floor up one level in a staggered fashion.
---
--- This function creates a real-time thread that continuously moves the camera's floor up by one level, with a delay between each movement. The movement is staggered to provide a smooth transition.
---
--- The thread will continue running until the camera is locked or the thread is manually deleted.
---
--- @function GamepadStaggeredFloorUp
--- @return nil
function GamepadStaggeredFloorUp()
	if IsValidThread(GamepadStaggeredFloorChangeThread) then return end
	
	GamepadStaggeredFloorChangeThread = CreateRealTimeThread(function()
		while true do
			if camera.IsLocked() then return end
			cameraTac.SetFloor(
				cameraTac:GetFloor() + 1,
				hr.CameraTacInterpolatedMovementTime * 10,
				hr.CameraTacInterpolatedVerticalMovementTime * 10
			)
			Sleep(GamepadFloorChangeStaggerTime)
		end
	end)
end

---
--- Moves the camera's floor down one level in a staggered fashion.
---
--- This function creates a real-time thread that continuously moves the camera's floor down by one level, with a delay between each movement. The movement is staggered to provide a smooth transition.
---
--- The thread will continue running until the camera is locked or the thread is manually deleted.
---
--- @function GamepadStaggeredFloorDown
--- @return nil
function GamepadStaggeredFloorDown()
	if IsValidThread(GamepadStaggeredFloorChangeThread) then return end
	
	GamepadStaggeredFloorChangeThread = CreateRealTimeThread(function()
		while true do
			if camera.IsLocked() then return end
			cameraTac.SetFloor(
				cameraTac:GetFloor() - 1,
				hr.CameraTacInterpolatedMovementTime * 10,
				hr.CameraTacInterpolatedVerticalMovementTime * 10
			)
			Sleep(GamepadFloorChangeStaggerTime)
		end
	end)
end

---
--- Stops the staggered camera floor change thread.
---
--- This function checks if the `GamepadStaggeredFloorChangeThread` is valid and running, and if so, deletes the thread. This effectively stops the continuous staggered movement of the camera's floor.
---
--- @function GamepadStaggerFloorChangeEnd
--- @return nil
function GamepadStaggerFloorChangeEnd()
	if IsValidThread(GamepadStaggeredFloorChangeThread) then DeleteThread(GamepadStaggeredFloorChangeThread) end
end

---
--- Shows the floor display for the gamepad UI.
---
--- This function is responsible for displaying the floor hint cursor in the gamepad UI. It checks if the `gamepad_thread` is valid and spawns the "FloorDisplay" template accordingly. If the thread is not valid, it spawns the "FloorDisplay" template directly on the `self` object and adds a dynamic position modifier to attach it to the mouse.
---
--- The function also resets the hiding of the floor display dialog and sets its margins.
---
--- @function GamepadUnitControl:ShowFloorDisplay
--- @return nil
function GamepadUnitControl:ShowFloorDisplay()
	local dlg
	if IsValidThread(self.gamepad_thread) then
		local floorDisplayDlg = self.idGamepadAttached.idFloorHintCursor
		if floorDisplayDlg then
			floorDisplayDlg:ResetHiding()
			return
		end

		dlg = XTemplateSpawn("FloorDisplay", self.idGamepadAttached)
		dlg:Open()
	else
		local floorDisplayDlg = self.idFloorHintCursor
		if floorDisplayDlg then
			floorDisplayDlg:ResetHiding()
			return
		end

		dlg = XTemplateSpawn("FloorDisplay", self)
		dlg:AddDynamicPosModifier({id = "attached_ui", target = "mouse"})
		dlg:Open()
	end
	dlg:ResetHiding()
	dlg:SetMargins(box(20, 0, 0, 0))
end

---
--- Sets the focus on the stance list in the gamepad UI.
---
--- This function is responsible for setting the focus on the stance list in the gamepad UI. It first retrieves the in-game interface mode dialog and the stance button, and then the stance list. If the stance list is not available, the function returns.
---
--- The function then retrieves the currently selected unit and its current stance. It iterates through the stance list to find the index of the current stance, and sets the focus and selection on that index.
---
--- Finally, the function applies the combat bar hiding animation to the bottom bar of the in-game interface mode dialog.
---
--- @function GamepadFocusStanceList
--- @return nil
function GamepadFocusStanceList()
	local igi = GetInGameInterfaceModeDlg()
	local stanceButton = igi and igi.idStanceButton
	local stanceList = stanceButton and stanceButton.idStanceButtons
	if not stanceList then return end
	
	local unit = Selection and Selection[1]
	if not unit then return end

	local currentStanceId = "Stance" .. unit.stance
	local currentStanceAction = CombatActions[currentStanceId]
	if not currentStanceAction then return end
	
	local currentStanceId = -1
	for i, stanceButton in ipairs(stanceList) do
		if stanceButton.context and stanceButton.context.action == currentStanceAction then
			currentStanceId = i
			break
		end
	end
	if currentStanceId == -1 then return end
	
	stanceList:SetFocus()
	stanceList:SetSelection(currentStanceId)
	
	local bottomBar = igi:ResolveId("idBottomBar")
	ApplyCombatBarHidingAnimation(bottomBar, true)
	--LockCamera("ActionBarGamepad")
end

local lPingCooldownMax = 5 -- No more than this many pings in the last this many seconds.

if FirstLoad then
g_RecentPings = false
PingCooldownThread = false
end

---
--- Handles the network synchronization of a player ping event.
---
--- This function is called when a player pings the map. It plays a visual effect for the ping, places a temporary badge object at the ping location, and schedules the badge object to be removed after 1.5 seconds.
---
--- @param pos The position of the ping on the map.
--- @param playerId The unique identifier of the player who made the ping.
---
function NetSyncEvents.PlayerPing(pos, playerId)
	PlayFX(playerId == netUniqueId and "PlayerPing" or "Player2Ping", "start", "Unit", false, pos)

	local badgeObject = PlaceObject("Object")
	badgeObject:SetPos(pos)
	CreateBadgeFromPreset("PingBadge", badgeObject)
	CreateMapRealTimeThread(function()
		Sleep(1500)
		if IsValid(badgeObject) then
			DoneObject(badgeObject)
		end
	end)
end

---
--- Handles the network synchronization of a player ping event.
---
--- This function is called when a player pings the map. It plays a visual effect for the ping, places a temporary badge object at the ping location, and schedules the badge object to be removed after 1.5 seconds.
---
--- @param pos The position of the ping on the map.
--- @param playerId The unique identifier of the player who made the ping.
---
function PlayerPing()
	if g_RecentPings and g_RecentPings > lPingCooldownMax then return end
	if not netInGame then return end
	NetSyncEvent("PlayerPing", GetCursorPos(), netUniqueId)
	
	g_RecentPings = (g_RecentPings or 0) + 1
	if not IsValidThread(PingCooldownThread) then
		PingCooldownThread = CreateRealTimeThread(function()
			while g_RecentPings > 0 do
				Sleep(1000)
				g_RecentPings = g_RecentPings - 1
			end
		end)
	end
end