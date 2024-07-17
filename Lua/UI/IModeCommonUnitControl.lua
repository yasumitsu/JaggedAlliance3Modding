
redirectedIgiEvents = { "OnMousePos", "OnMouseButtonUp", "OnMouseButtonDown", "OnMouseWheelForward", "OnMouseWheelBack", "OnMouseButtonDoubleClick" }
function OnMsg.InGameInterfaceCreated(igi)
	igi.HandleMouse = true
	for i, e in ipairs(redirectedIgiEvents) do
		igi[e] = function(self, ...)
			for i, w in ipairs(self) do
				if w.visible then
					if w[e](w, ...) == "break" then
						return "break"
					end
				end
			end
		end
	end
end

---
--- Sets the current in-game interface mode.
---
--- @param mode string The new in-game interface mode to set.
--- @param context table Optional context data to pass to the new mode.
---
function SetInGameInterfaceMode(mode, context)
	SetDialogMode("InGameInterface", mode, context)
end

DefineClass.InterfaceModeDialog = {
	__parents = { "XDialog" },
}

local oldCreateFloatingText = CreateFloatingText

---
--- Creates a floating text UI element for the given target.
---
--- This function checks if the target is a valid Unit, and if so, ensures the Unit is visible and not dead before creating the floating text.
--- If the target is a Point, it ensures the Point has a valid Z coordinate before creating the floating text.
---
--- @param target Unit|Point The target for which to create the floating text.
--- @param ... any Additional arguments to pass to the underlying `oldCreateFloatingText` function.
--- @return boolean|any Returns `false` if the floating text could not be created, otherwise returns the result of the `oldCreateFloatingText` function.
---
function CreateFloatingText(target, ...)
	if CheatEnabled("CombatUIHidden") then
		return false
	end

	if IsKindOf(target, "Unit") then
		if not IsValid(target) or target:IsDead() or target:GetEnumFlags(const.efVisible) == 0 then
			return
		end
	end
	
	if IsPoint(target) and not target:IsValidZ() then
		target = target:SetTerrainZ()
	end
	
	return oldCreateFloatingText(target, ...)
end

DefineClass.IModeCommonUnitControl = {
	__parents = { "GamepadUnitControl" },
	HandleMouse = false,
	
	combatActionsPopup = false,
	
	fx_interactable = false,
	
	potential_target = false,
	potential_interactable = false,
	potential_interactable_action = false,
	potential_target_is_enemy = false,
	potential_target_via_voxel = false,
	action_targets = false,
	show_world_ui = false,
	
	target_pos = false,
	target_pos_has_unit = false,
	target_pos_occupied = false,
	effects_target_pos = false,
	effects_target_pos_last = false,
	cover_objs = false,
	
	fx_lof_offset = guim,
	fx_lof = false,
	
	movement_decal = "DecUIUnitTarget",
	movement_decal_scale = 130,
	movement_decal_shrink_time = 700,
	movement_decal_color = RGB(204, 204, 204),
}

---
--- Initializes the `IModeCommonUnitControl` class.
--- This function sets up the `cover_objs` table and creates two threads:
--- 1. `UpdateMousePos`: This thread updates the mouse position and calls `OnMousePos` if the window is visible and the gamepad thread is not running.
--- 2. `highlightInteractables`: This thread updates the interactables highlight based on various conditions, such as whether the camera is in tactical mode, the selected object is in combat, or the window is visible.
---
--- @param self IModeCommonUnitControl The instance of the `IModeCommonUnitControl` class.
function IModeCommonUnitControl:Init()
	self.cover_objs = {}
--[[	self:CreateThread("UpdateMousePos", function()
		ObjModified("inspect_mode")
		while self.window_state ~= "destroying" do
			local cursor = GetCursorPos()
			if self:IsVisible() and not IsValidThread(self.gamepad_thread) and self:IsWithin(self.desktop.last_mouse_target) then
				self:OnMousePos(terminal.GetMousePos())
			end
			Sleep(50)
		end
	end)]]
	self:CreateThread("highlightInteractables", function(ctrl)
		local dontAddNewInteractables
		while ctrl.window_state ~= "destroying" do
			dontAddNewInteractables = IsSetpiecePlaying() or not ctrl:IsVisible() or not ctrl:HighlightNewInteractables() or next(g_ZuluMessagePopup)
			if g_Combat and SelectedObj then
				dontAddNewInteractables = dontAddNewInteractables or not SelectedObj:IsIdleCommand() or HasCombatActionInProgress(SelectedObj)
			end
			if not cameraTac.IsActive() then
				dontAddNewInteractables = true
			end
			ctrl:UpdateInteractablesHighlight(dontAddNewInteractables)
			Sleep(100)
		end
	end, self)
end

if FirstLoad then
LastLoadedOrLoadingIMode = false
end
---
--- Opens the `IModeCommonUnitControl` window.
---
--- This function is called when the `IModeCommonUnitControl` window is opened. It performs the following actions:
--- - Sets the `LastLoadedOrLoadingIMode` global variable to the current class.
--- - Calls `SelectionAddedApplyFX(Selection)` to apply any selection-related effects.
--- - Calls the `Open()` function of the parent `GamepadUnitControl` class.
---
--- @param self IModeCommonUnitControl The instance of the `IModeCommonUnitControl` class.
--- @param ... any Additional arguments passed to the function.
function IModeCommonUnitControl:Open(...)
	LastLoadedOrLoadingIMode = self.class
	SelectionAddedApplyFX(Selection)
	GamepadUnitControl.Open(self, ...)
end

---
--- Closes the `IModeCommonUnitControl` window.
---
--- This function is called when the `IModeCommonUnitControl` window is closed. It performs the following actions:
--- - Calls `UpdateInteractablesHighlight(true)` to ensure the interactables highlight is cleared.
--- - Calls the `Close()` function of the parent `GamepadUnitControl` class.
---
--- @param self IModeCommonUnitControl The instance of the `IModeCommonUnitControl` class.
--- @param ... any Additional arguments passed to the function.
--- @return any The return value of the parent `GamepadUnitControl.Close()` function.
function IModeCommonUnitControl:Close(...)
	self:UpdateInteractablesHighlight(true)
	return GamepadUnitControl.Close(self, ...)
end

---
--- Clears the member object array of the specified member name.
---
--- This function is used to clear the member object array of the specified member name. It performs the following actions:
--- - Asserts that the specified member name exists in the class.
--- - If the member object array exists, it calls `DoneObject()` on each object in the array to destroy them.
--- - Sets the member object array to `nil`.
---
--- @param self IModeCommonUnitControl The instance of the `IModeCommonUnitControl` class.
--- @param member_name string The name of the member object array to clear.
function IModeCommonUnitControl:ClearMemberObj(member_name)
	assert(self:HasMember(member_name))
	if self[member_name] then
		DoneObject(self[member_name])
		self[member_name] = nil
	end
end

---
--- Clears the member object array of the specified member name.
---
--- This function is used to clear the member object array of the specified member name. It performs the following actions:
--- - Asserts that the specified member name exists in the class.
--- - If the member object array exists, it calls `DoneObject()` on each object in the array to destroy them.
--- - If `keep_table` is true, it clears the contents of the table but keeps the table object. Otherwise, it sets the member object array to `nil`.
---
--- @param self IModeCommonUnitControl The instance of the `IModeCommonUnitControl` class.
--- @param member_name string The name of the member object array to clear.
--- @param keep_table boolean If true, keeps the table object but clears its contents.
function IModeCommonUnitControl:ClearMemberObjArray(member_name, keep_table)
	assert(self:HasMember(member_name))
	for _, obj in ipairs(self[member_name]) do
		DoneObject(obj)
	end
	if keep_table then
		if self[member_name] then
			table.iclear(self[member_name])
		end
	else
		self[member_name] = nil
	end
end

--- Highlights any new interactable objects in the game.
---
--- This function is used to highlight any new interactable objects that have been added to the game. It returns `true` to indicate that the highlighting was successful.
---
--- @return boolean true if the highlighting was successful, false otherwise.
function IModeCommonUnitControl:HighlightNewInteractables()
	return true
end

MapVar("UnitsSusBeingRaised", function() return {} end)

---
--- Spawns a detection indicator for the specified unit.
---
--- This function creates a new `MercDetectionIndicator` object and attaches it to the specified unit. The indicator is locked to the unit's orientation and will follow the unit as it moves.
---
--- @param unit Unit The unit to attach the detection indicator to.
--- @return MercDetectionIndicator The spawned detection indicator.
function SpawnDetectionIndicator(unit)
	local lineMesh = MercDetectionIndicator:new({unit = unit})
	lineMesh:SetGameFlags(const.gofLockedOrientation)
	lineMesh.unit = unit
	unit:Attach(lineMesh)

	return lineMesh
end

---
--- Ensures that the specified unit has an "AwareBadge" badge attached to it.
---
--- If the unit does not already have an "AwareBadge" badge, this function will create a new one and attach it to the unit.
---
--- @param unit Unit The unit to ensure has an "AwareBadge" badge.
---
function EnsureUnitHasAwareBadge(unit)
	if not TargetHasBadgeOfPreset("AwareBadge", unit) then
		CreateBadgeFromPreset("AwareBadge", unit, unit)
	end
end

---
--- Plays a startled animation and voice response for the specified unit.
---
--- If the unit is a valid `Unit` object and is not already in the "IdleSuspicious" command, this function will create a new game thread to play a voice response and interrupt the unit's current command to the "IdleSuspicious" command.
---
--- @param unit Unit The unit to play the startled animation and voice response for.
---
function PlayUnitStartleAnim(unit)
	if IsKindOf(unit, "Unit") and unit.command ~= "IdleSuspicious" then
		CreateGameTimeThread(function()
			-- make sure the InterruptCommand call comes from another thread, as it may assert if it's the unit's command thread through a pcall (msg)
			PlayVoiceResponse(unit, "Startled")
			unit:InterruptCommand("IdleSuspicious")
		end)
	end
end

---
--- Handles the visibility and animation of the "AwareBadge" badge attached to a unit or SneakProjector object.
---
--- This function is responsible for managing the display of the "AwareBadge" badge based on the current state of the unit or SneakProjector. It determines whether the badge should be visible or not, and applies appropriate fade-in and pulse animations to the badge's image.
---
--- @param badge MercDetectionIndicator The "AwareBadge" badge attached to the unit or SneakProjector.
---
function UnitAwareBadgeProc(badge)
	local enemy = badge.context
	if g_Combat or g_StartingCombat or not IsValid(enemy) then
		DeleteBadgesFromTargetOfPreset("AwareBadge", enemy)
		return
	end

	local badgeShouldBeVisible = false
	local exp = g_Exploration
	local enemyData = exp and exp.nearby_enemies and exp.nearby_enemies[enemy]
	local enemyRaisingSus = enemyData and enemyData.amount > 0
	if IsKindOf(enemy, "SneakProjector") then
		if not enemyRaisingSus then
			DeleteBadgesFromTargetOfPreset("AwareBadge", enemy)
			return
		end

		badgeShouldBeVisible = true
	else -- unit
		assert(IsKindOf(enemy, "Unit"))
		local enemySus = enemy:HasStatusEffect("Suspicious")
		local shouldBeVisible = enemySus or enemyRaisingSus
		if enemy:IsDead() or not shouldBeVisible then
			DeleteBadgesFromTargetOfPreset("AwareBadge", enemy)
			return
		end
		
		badgeShouldBeVisible = enemy.visible
	end

	local image = badge.idImage
	local invisible = badge.idImage.transparency == 255
	if invisible then
		local fadeTime = 200
		local growTime = 500
	
		badge.idImage:SetTransparency(0, fadeTime)
		local interpData = {
			id = "pulse",
			type = const.intRect,
			duration = growTime,
			originalRect = sizebox(0, 0, 1000, 1000),
			targetRect = sizebox(0, 0, 1300, 1300),
			flags = const.intfPingPong,
			OnLayoutComplete = IntRectCenterRelative
		}
		badge.idImage:AddInterpolation(interpData)
	end
	badge:SetVisible(badgeShouldBeVisible)
	Sleep(100)
end

function OnMsg.UnitAwarenessChanged(obj)
	if obj:HasStatusEffect("Suspicious") then
		EnsureUnitHasAwareBadge(obj)
		PlayUnitStartleAnim(obj)
	end
end

----------------------------------------------------

---
--- Appends vertices for a union of circles to a mesh.
---
--- @param circle_centers table A table of circle center coordinates.
--- @param circle_radiuses table A table of circle radiuses.
--- @param mesh_str string The mesh string to append the vertices to.
--- @return string The updated mesh string.
function AppendVerticesUnionCircles(circle_centers, circle_radiuses, mesh_str)
	local color = const.clrWhite
	local subdiv = 128
	local width = guim*4/10
	local dash = 70
	local z_offset = guim/2
	AppendVerticesUnionCirclesMesh(mesh_str, circle_centers, circle_radiuses, subdiv, width, dash, z_offset, color)
end

-- Floor display

DefineClass.FloorDisplay = {
	__parents = {"XWindow"},
	Id = "idFloorHintCursor",
	Clip = false,
	UseClipBox = false,
	HAlign = "left",
	VAlign = "top",
	FadeOutTime = 300,
	ZOrder = 100
}

---
--- Opens the floor display window.
---
--- This function creates a new "FloorHUDButtonClass" window and a "XWindowReverseDraw" subwindow, sets the layout and ID of the subwindow, and then opens the main window.
---
--- @function FloorDisplay:Open
--- @return nil
function FloorDisplay:Open()
	local floorDisplay = XTemplateSpawn("FloorHUDButtonClass", self)
	local subWnd = XTemplateSpawn("XWindowReverseDraw", floorDisplay)
	subWnd:SetId("idFloorDisplay")
	subWnd:SetLayoutMethod("VList")
	subWnd:SetLayoutVSpacing(-4)
	subWnd:SetId("idFloorDisplay")
	XWindow.Open(self)
end

---
--- Resets the hiding behavior of the floor display window.
---
--- This function first checks if there is an existing "disappear" thread, and if so, deletes it. It then sets the window to be visible, and creates a new "disappear" thread that will:
--- - Sleep for 500 milliseconds
--- - Set the window to be invisible
--- - Sleep for the duration of the FadeOutTime property plus 1 millisecond
--- - Close the window
---
--- @function FloorDisplay:ResetHiding
--- @return nil
function FloorDisplay:ResetHiding()
	if self:GetThread("disappear") then
		self:DeleteThread("disappear")
	end
	self:SetVisible(true, true)
	self:CreateThread("disappear", function()
		Sleep(500)
		self:SetVisible(false)
		Sleep(self.FadeOutTime + 1)
		self:Close()
	end)
end

---
--- Toggles the floor display window when the mouse wheel is scrolled back while the Shift key is pressed.
---
--- This function is called when the mouse wheel is scrolled back while the Shift key is pressed. It calls the `ShowFloorDisplay()` function to toggle the visibility of the floor display window.
---
--- @function IModeCommonUnitControl:OnMouseWheelBack
--- @return nil
function IModeCommonUnitControl:OnMouseWheelForward()
	if terminal.IsKeyPressed(const.vkShift) then
		self:ShowFloorDisplay()
	end
end

---
--- Toggles the floor display window when the mouse wheel is scrolled back while the Shift key is pressed.
---
--- This function is called when the mouse wheel is scrolled back while the Shift key is pressed. It calls the `ShowFloorDisplay()` function to toggle the visibility of the floor display window.
---
--- @function IModeCommonUnitControl:OnMouseWheelBack
--- @return nil
function IModeCommonUnitControl:OnMouseWheelBack()
	if terminal.IsKeyPressed(const.vkShift) then
		self:ShowFloorDisplay()
	end
end

function OnMsg.TacCamFloorChanged()
	local igi = GetInGameInterfaceModeDlg()
	if igi and IsValidThread(igi.gamepad_thread) and igi.world_cursor_visible then
		igi:ShowFloorDisplay()
	end	
end

--

--- Cleans up the state of the IModeCommonUnitControl instance.
---
--- This function is called when the IModeCommonUnitControl instance is done being used. It performs the following actions:
--- - Deletes the "UpdateMousePos" thread
--- - Closes any open popup
--- - Clears any target covers
--- - Clears any lines of fire
---
--- @function IModeCommonUnitControl:Done
--- @return nil
function IModeCommonUnitControl:Done()
	self:DeleteThread("UpdateMousePos")
	self:ClosePopup()
	self:ClearTargetCovers()
	self:ClearLinesOfFire()
end

---
--- Closes the combat actions popup if it exists and is not already being destroyed.
---
--- If a new popup action is provided, this function will check if the current popup action matches the new one. If so, it will return `true` to indicate that no further action is needed.
---
--- @param newPopupAction table|nil The new popup action to compare against the current one
--- @return boolean True if the popup was closed and the new popup action matches the old one, false otherwise
function IModeCommonUnitControl:ClosePopup(newPopupAction) -- todo: delete these popup stuff
	if self.combatActionsPopup and self.combatActionsPopup.window_state ~= "destroying" then
		local popupAction = self.combatActionsPopup.action
		self.combatActionsPopup:Close()
		self.combatActionsPopup = false
		if popupAction and newPopupAction and newPopupAction.id == popupAction.id then return true end
	end
end

local function ExtractCombatActionTargetChoiceText(target, menu_pos)
	if IsKindOf(target, "Unit") then
		return target:GetDisplayName()
	end
	
	if IsKindOf(target, "PropertyObject") then
		if target:HasMember("DisplayName") then
			return target:GetProperty("DisplayName")
		end
	elseif target.DisplayName then
		return target.DisplayName
	end
	
	return T{639303826024, "<u(class)> <i>", class = target.class, i = menu_pos}
end

---
--- Displays a combat action target choice popup for the given action, units, and choices.
---
--- This function is responsible for collecting the available targets for the given combat action, and displaying a popup with the target choices. If there is only one available target and it is not disabled, the function will execute the combat choice directly without showing the popup.
---
--- @param action table The combat action for which to display the target choice
--- @param units table The units that can perform the combat action
--- @param choices table|nil The list of possible targets for the combat action
--- @param callback function|nil The callback function to call when a target is chosen
--- @param suppress_toggle boolean|nil Whether to suppress toggling the popup if the same action is selected
--- @return table The combat actions choice popup
function IModeCommonUnitControl:ShowCombatActionTargetChoice(action, units, choices, callback, suppress_toggle)
	--find possible targets
	choices = choices or action:GetTargets(units)
	if #choices == 0 then return end
	
	--collect avaliable targets
	local context = { }
	for idx, target in ipairs(choices) do
		local closest_unit = units[1]
		if #units > 1 then
			closest_unit = IsValid(target) and ChooseClosestObject(units, target) or units[1]
		end
	
		local combat_action
		if action.id == "Interact" then
			combat_action = target:GetInteractionCombatAction(closest_unit)
		else
			combat_action = action
		end
		if combat_action then
			local state = action:GetUIState({closest_unit}, { target = target })
			if state == "enabled" then
				local text
				if combat_action.group == "Interactions" then
					local display_name = combat_action:GetActionDisplayName(closest_unit)
					local apCost = (combat_action:GetAPCost(closest_unit) or 0) / const.Scale.AP
					text = T{display_name, unit = closest_unit, target = target}
					if g_Combat then
						text = text .. T{654731275801, " (<apCost> AP)", apCost = apCost}
					end
				else
					text = ExtractCombatActionTargetChoiceText(target, idx)
				end
				
				table.insert(context, {
					text = text,
					action = action,
					unit = closest_unit,
					target = target,
					callback = callback,
					uiCtx = rawget(target, "uiCtx"),
					rolloverTemplate = rawget(target, "rolloverTemplate"),
					icon = combat_action.Icon,
					disabled = rawget(target, "disabled")
				})
			end
		end
	end
	
	--only one available target - execute
	if not rawget(choices, "always_show") then
		if #context == 1 and not context[1].disabled then
			ExecuteCombatChoice(context[1])
			return
		end
	end

	if RolloverControl and IsKindOf(RolloverControl, "XTextButton") and RolloverWin then
		RolloverWin:Close()
		RolloverWin = false
	end
	
	-- If opening a choice for the same action, close the choice.
	if self:ClosePopup(action) and not suppress_toggle then return end
	local combatUnitPanel = self:ResolveId("idCombatUnitPanel")
	local actionButtonsBar = self:ResolveId("idActionButtonsBar")
	local actionsContainer = self:ResolveId("idCombatActionsContainer")
	
	local actionsChoicePopup = XTemplateSpawn("CombatActionsChoice", self, context)
	rawset(actionsChoicePopup, "action", action)
	actionsChoicePopup.width_wnd = actionsContainer
	self.combatActionsPopup = actionsChoicePopup

	local actionButton = table.find_value(actionsContainer, "Id", action.id)
	actionsChoicePopup:SetAnchor(actionButton.box)
	actionsChoicePopup:SetAnchorType("center-top")
	actionsChoicePopup:SetId("idCombatActionsPopup")

	actionsChoicePopup:Open()
	actionsChoicePopup.idChoiceActionsContainer:SetFocus()
	actionsChoicePopup.idChoiceActionsContainer:SetFocusedItem(1)
	
	-- Action button selection mode update
	actionButton:OnSetRollover(false, true)
	actionsChoicePopup.OnDelete = function()
		if actionButton.window_state == "destroying" then return end
		actionButton:OnSetRollover(false, true)
--[[		actionButton = combatUnitPanel:GetSelectedCombatActionButton()
		if actionButton then combatUnitPanel:UpdateCombatActionsRollover(actionButton) end]]
	end

	self.SetBox = function(this, ...)
		XDialog.SetBox(this, ...)
		local popup = this.combatActionsPopup
		if not popup then return end
		if not actionButton or actionButton.window_state == "destroying" then return end
		popup:SetAnchor(actionButton.box)
		popup:InvalidateLayout()
	end
	
	return actionsChoicePopup
end

---
--- Selects the next available unit in the current team, optionally forcing the selection or ignoring the camera snap.
---
--- @param team table The team to select the next unit from. If not provided, the current team is used.
--- @param force boolean If true, the next unit will be selected regardless of its availability.
--- @param ignore_snap boolean If true, the camera will not snap to the selected unit.
--- @param prev boolean If true, the previous unit will be selected instead of the next.
--- @return nil
function IModeCommonUnitControl:NextUnit(team, force, ignore_snap, prev)
	team = team or g_Teams and g_Teams[g_CurrentTeam]
	if not team or team.control ~= "UI" then return end
	local fTeam = GetFilteredCurrentTeam(team)

	local units = fTeam.units
	local current_unit = SelectedObj
	local idx = table.find(units, current_unit) or 1
	local n = #units

	if not units or not next(units) then return end

	local j = idx
	while true do
		if prev then j = j - 1 else j = j + 1 end
		if j < 1 then j = n end
		if j > n then j = 0 end
		if j == 0 then j = 1 end

		local unit = units[j]
		-- A hole in the team.units array? Happens on some saves for a short while because teams aren't initialized.
		if not unit then return end
		if self:UnitAvailableForNextUnitSelection(unit, force) then
			SelectObj(unit)
			if not ignore_snap then
				SnapCameraToObj(unit, "player-input")
			end
			return
		end
		
		if j == idx then return end
	end
end

---
--- Checks if the given unit is available for selection in the next unit cycle.
---
--- @param unit table The unit to check.
--- @return boolean True if the unit can be selected, false otherwise.
---
function IModeCommonUnitControl:UnitAvailableForNextUnitSelection(unit)
	return unit:CanBeControlled() and not unit:IsDowned()
end

---
--- Executes a combat choice.
---
--- @param data table The data for the combat choice, including the unit, target, action, and optional arguments.
---
function ExecuteCombatChoice(data)
	if data.callback then
		data.callback(data.unit, data.target, table.unpack(data.args or empty_table))
	else
		data.action:Execute({data.unit}, { target = data.target, table.unpack(data.args or empty_table) })
	end
end

---
--- Checks if the given unit can interact with the given target.
---
--- @param unit table The unit to check.
--- @param target table The target to check.
--- @param skip_cost boolean (optional) Whether to skip checking the cost of the interaction.
--- @param sync boolean (optional) Whether to perform the interaction synchronously.
--- @return boolean True if the unit can interact with the target, false otherwise.
---
function UICanInteractWith(unit, target, skip_cost, sync)
	if not IsValid(unit) or not IsValid(target) then return false end
	if not unit:CanBeControlled() then return false end
	return unit:CanInteractWith(target, false, skip_cost, nil, sync)
end

---
--- Checks if the given unit can interact with the given target synchronously.
---
--- @param unit table The unit to check.
--- @param target table The target to check.
--- @param skip_cost boolean (optional) Whether to skip checking the cost of the interaction.
--- @param sync boolean (optional) Whether to perform the interaction synchronously.
--- @return boolean True if the unit can interact with the target, false otherwise.
---
function CanInteractWith_SyncHelper(unit, target, skip_cost, sync)
	if not IsValid(unit) or not IsValid(target) then return false end
	if not unit:IsDisabled() then return false end
	return unit:CanInteractWith(target, false, skip_cost, nil, sync)
end

---
--- Finds the closest interactable unit from the current selection that can interact with the given target.
---
--- @param target table The target to interact with.
--- @param skipApCost boolean (optional) Whether to skip checking the cost of the interaction. Defaults to true.
--- @return table|boolean The closest interactable unit that can interact with the target, or false if no unit can interact.
---
function UIFindInteractWith(target, skipApCost)
	if skipApCost == nil then
		skipApCost = true
	end

	local action = false
	for i, sU in ipairs(Selection) do
		action = target:GetInteractionCombatAction(sU)
		if action then break end
	end
	if not action then return false end -- None of the units can even get the action.
	
	-- "all" and "hidden" will act as "nearest"
	local behavior = action.MultiSelectBehavior
	if behavior == "first" then
		for i, sU in ipairs(Selection) do
			if UICanInteractWith(sU, target, skipApCost) then
				return sU
			end
		end
	else -- "nearest" or "all"
		local obj = ChooseClosestObject(Selection, target, UICanInteractWith, skipApCost)
		return obj, behavior == "all" and "follow"
	end
end

---
--- Interacts with the given target using the given unit.
---
--- If the target is not an `Interactable` object, it will attempt to resolve it to an interactable object.
---
--- If the interaction action is "Interact_Attack", it will execute the unit's default ranged attack action if it is enabled.
---
--- Otherwise, it will execute the `CombatActions.Interact` action with the unit and target.
---
--- @param unit table The unit to use for the interaction.
--- @param target table The target to interact with.
---
function UIInteractWith(unit, target)
	if not IsValid(target) then return end
	if not IsKindOf(target, "Interactable") then
		target = ResolveInteractableObject(target)
		if target then return end
	end
	--[[-- Special case for interacting with units. If any merc is close enough start the interaction. (161064)
	local igi = GetInGameInterfaceModeDlg()
	if IsKindOf(igi, "IModeExploration") then
		local pos = unit:GetInteractionPosWith(target)
		if IsKindOf(target, "Unit") and not target:IsDead() then
			local playerUnits = GetAllPlayerUnitsOnMap()
			for i, u in ipairs(playerUnits) do
				if target ~= u and u:CanBeControlled() and not u:IsDead() and u:CloseEnoughToInteract(pos, target) then
					unit = u
					break
				end
			end
		end
	end]]
	local interactionAction = target:GetInteractionCombatAction(unit)
	if interactionAction.id == "Interact_Attack" then -- Special case so it doesn't go through the network.
		local args = {target = target}
		local action = unit:GetDefaultAttackAction("ranged")
		local state = action and CheckAndReportImpossibleAttack(unit, action, args)
		if state and state == "enabled" then
			action:UIBegin({unit}, args)
		end
		return
	end

	CombatActions.Interact:Execute({ unit }, { target = target })
end

function OnMsg.NewMapLoaded()
	-- covers: passability update(efCollision + efApplyToGrids) and interface calling IntersectSegmentWithObjects(efCollision + efSelectable)
	-- want to avoid very big objects placed outside the playable area
	local radius, surf = CalcMapMaxObjRadius(const.efCollision, const.efApplyToGrids + const.efSelectable, 0)
	SetMapMaxObjRadius(radius, surf)
end

local lInteractablePriorityList = { ["Unit"] = 1 }
---
--- Gets the interactable object under the cursor.
---
--- This function first tries to perform a precise selection of the interactable object under the cursor. If that fails, it falls back to a less precise selection method.
---
--- For gamepad controls, it performs a simpler check for interactable objects within a certain radius around the cursor position.
---
--- The function returns the interactable object and the associated unit, if any.
---
--- @return table|nil interactable The interactable object under the cursor, or nil if none found.
--- @return table|nil unit The unit associated with the interactable object, or nil if none found.
---
function IModeCommonUnitControl:GetInteractableUnderCursor()
	local interactables = { }
	local UIStyleGamepad = GetUIStyleGamepad()
	local cursor_pos = UIStyleGamepad and GetCursorPos() or GetTerrainCursor()

	-- Try precise selection first. 
	local solid = PreciseCursorObjAreaClosestOfType(false, lInteractablePriorityList)
	local obj = solid or SelectFromTerrainPoint(GetTerrainCursor())
	local interactable, all = ResolveInteractableObject(obj)
	if all and #all > 0 then
		table.iappend(interactables, all)
	elseif interactable then
		table.insert(interactables, interactable)
	-- Note: don't do it on gamepad as GetTerrainCursorObjSel is actually pretty heavy
	elseif not UIStyleGamepad then
		local obj = GetTerrainCursorObjSel()
		if obj and obj:IsKindOf("Decal") then
			obj = ResolveInteractableObject(obj)
			if obj then
				table.insert(interactables, obj)
			end
		end
	end

	-- Do a simpler check for gamepad as it doesnt have the pinpoint precision of a mouse.
	if UIStyleGamepad then
		local resolvedObjectsGamepad = {}
		self.potential_interactable_gamepad_resolved = resolvedObjectsGamepad

		-- Extra precision: skip interactables further away than the closest voxel center.
		local snappedVoxel = SnapToVoxel(cursor_pos)
		local vAround = GetVoxelBBox(snappedVoxel, 0.5, "with_z", "dont_snap")
		MapForEach(vAround, "CObject", const.efSelectable + const.efVisible, function(obj, resolvedObjectsGamepad, vAround, cursor_pos)
			-- We need to recheck bounds as mapget is 2D
			if not vAround:PointInside(obj:GetPosXYZ()) then
				return
			end

			local int, all = ResolveInteractableObject(obj)
			if all and #all > 0 then
				for i, int in ipairs(all) do
					if resolvedObjectsGamepad[int] then
						if IsCloser(cursor_pos, obj, resolvedObjectsGamepad[int]) then
							resolvedObjectsGamepad[int] = obj
						end
					else
						table.insert(resolvedObjectsGamepad, int)
						resolvedObjectsGamepad[int] = obj
					end
				end
			elseif int then
				if resolvedObjectsGamepad[int] then
					if IsCloser(cursor_pos, obj, resolvedObjectsGamepad[int]) then
						resolvedObjectsGamepad[int] = obj
					end
				else
					table.insert(resolvedObjectsGamepad, int)
					resolvedObjectsGamepad[int] = obj
				end
			end
		end, resolvedObjectsGamepad, vAround, cursor_pos)

		if next(resolvedObjectsGamepad) then
			-- Sort interactables by distance from cursor pos
			if #resolvedObjectsGamepad > 1 then
				table.sort(resolvedObjectsGamepad, function(a, b)
					return IsCloser(cursor_pos, resolvedObjectsGamepad[a], resolvedObjectsGamepad[b])
				end)
			end
			table.iappend(interactables, resolvedObjectsGamepad)
		end
	else
		-- not gamepad
		self.potential_interactable_gamepad_resolved = false
	end

	-- Cursor pos ray
	local camera_pos = camera.GetEye()
	local rayObj, ray_hit, normal = GetClosestVisibleRayObj(camera_pos, cursor_pos)
	if rayObj and not IsKindOf(rayObj, "TerrainCollision") then
		local interactable, all = ResolveInteractableObject(rayObj)
		if all and #all > 0 then -- Ray collision takes precedence
			for i, int in ipairs(all) do
				table.insert(interactables, i, int)
			end
		elseif interactable then
			table.insert(interactables, 1, interactable)
		end
	end
	
	-- Unit collisions are done through a separate function.
	--if #interactables == 0 then
		MapForEach(cursor_pos, guim * 3, "Unit", function(u, camera_pos, cursor_pos, ray_hit, interactables)
			if u:IsDead() and u:GetItemInSlot("InventoryDead") then
				local collided, hit_pos = GetBodyHitArea(camera_pos, cursor_pos, u)
				if collided and (not ray_hit or IsCloser(camera_pos, hit_pos, ray_hit)) then
					table.insert(interactables, u)
				end
			end
		end, camera_pos, cursor_pos, ray_hit, interactables)
	--end
	if #interactables == 0 then
		return
	end
	-- Return first valid
	local unit = UIFindInteractWith(interactables[1])
	if unit then
		return interactables[1], unit
	end
	if #interactables > 1 then
		-- It's possible for an interactable to have been captured
		-- by multiple of the collision methods above.
		local checked = { [interactables[1]] = true }
		for i = 2,  #interactables do
			local target = interactables[i]
			if not checked[target] then
				local unit = UIFindInteractWith(target)
				if unit then
					return target, unit
				end
				checked[target] = true
			end
		end
	end
end

---
--- Updates the highlight state of interactable objects under the cursor.
---
--- @param noNew boolean|nil If true, no new interactables will be highlighted.
--- @param force boolean|nil If true, the highlight will be updated even if the interactable hasn't changed.
---
function IModeCommonUnitControl:UpdateInteractablesHighlight(noNew, force)
	-- nothing can be interacted with, when no units are selected
	if not next(Selection) or not self.show_world_ui then
		noNew = true
	end

	local fx_interactable = false
	if not noNew then
		local selectedObj = Selection[1]

		local intensely_highlighted = self:GetInteractableUnderCursor()
		
		-- Dont allow potential target and interactable at the same time.
		if self.potential_target and self.potential_target ~= intensely_highlighted and not GetUIStyleGamepad() then
			local unitOverrideInteractable = false
			
			-- Picked via precise selection
			unitOverrideInteractable = not self.potential_target_via_voxel
			
			-- Objects spawned through combat skills always have priority.
			if IsKindOf(intensely_highlighted, "GameDynamicSpawnObject") then
				unitOverrideInteractable = false
			end

			if unitOverrideInteractable then
				intensely_highlighted = false
			end
		end
		
		if intensely_highlighted and intensely_highlighted ~= self.potential_interactable then
			PlayFX("InteractRollover", "start", selectedObj, intensely_highlighted)
		end
		local action = intensely_highlighted and intensely_highlighted:GetInteractionCombatAction(selectedObj)
		intensely_highlighted = action and intensely_highlighted
		
		self.potential_interactable = intensely_highlighted
		self.potential_interactable_action = action

		if intensely_highlighted then
			fx_interactable = intensely_highlighted
			--hide cursor when the cursor is over an interactable
			if not g_Combat then
				HandleMovementTileContour()
			end
		end
	end

	if fx_interactable ~= self.fx_interactable or force then
		if IsValid(self.fx_interactable) then
			self.fx_interactable:HighlightIntensely(false, "cursor")
		end
		self.fx_interactable = fx_interactable
		if fx_interactable then
			if not fx_interactable.discovered then
				NetSyncEvent("InteractableCursorDiscovered", fx_interactable)
			end
			fx_interactable:HighlightIntensely(true, "cursor")
		end
	end
end

---
--- Marks an interactable object as discovered when the cursor is placed over it.
---
--- @param interactable Interactable
---   The interactable object that was discovered by the cursor.
---
function NetSyncEvents.InteractableCursorDiscovered(interactable)
	if interactable then
		interactable.discovered = true
	end
end

GameVar("interactablesOn", false)

if FirstLoad then
interactableHighlightThread = false
end
local interactableHighlightUpdateInterval = 200
local interactableOnScreenMargin = 500

function OnMsg.ChangeMapDone()
	HighlightAllInteractables(interactablesOn)
end

function OnMsg.CombatEnd()
	--if not GetAccountStorageOptionValue("HighlightOnCombatEnd") then return end
	if not interactablesOn then
		HighlightAllInteractables(true)
	end
end

---
--- Highlights or disables highlighting of custom unit interactions.
---
--- @param disable boolean
---   If true, disables highlighting of all custom unit interactions.
---   If false, highlights custom unit interactions that are visible and have the "Interact_UnitCustomInteraction" action.
---
function HighlightCustomUnitInteractables(disable)
	local UnitHighlightIntensely = Unit.HighlightIntensely
	if disable then
		for i, u in ipairs(g_Units) do
			UnitHighlightIntensely(u, false, "badge-only")
		end
	else
		local highlight_action = Presets.CombatAction.Interactions.Interact_UnitCustomInteraction
		for i, u in ipairs(g_Units) do
			local isCustomUnitInteraction = u.visible and u:GetInteractionInfo() == highlight_action 
			UnitHighlightIntensely(u, isCustomUnitInteraction, "badge-only")
		end
	end
end

---
--- Highlights or disables highlighting of all interactable objects on the map.
---
--- @param setOn boolean
---   If true, highlights all interactable objects that are visible and have the "Interact_UnitCustomInteraction" action.
---   If false, disables highlighting of all interactable objects.
---
function HighlightAllInteractables(setOn)
	if setOn and IsSetpiecePlaying() then return end

	interactablesOn = setOn
	if CurrentMap == "" or IsChangingMap() or not Game then return end
	
	if interactableHighlightThread then
		DeleteThread(interactableHighlightThread)
		interactableHighlightThread = false
	end
	
	UpdateAllBadgesAndModes()
	if not interactablesOn then
		MapForEach("map", "Interactable", function(o)
			o:HighlightIntensely(false, "hotkey")
		end)
		return
	end
	
	TutorialHintsState.HighlightItems = TutorialHintsState.HighlightItemsShown and true
	interactableHighlightThread = CreateMapRealTimeThread(function()
		local interactables = MapGet("map", "Interactable", function(o)
			return not IsKindOf(o, "Door") and not o.spawned_by_explosive_object
		end)

		while true do
			local satDlg = GetDialog("PDADialogSatellite")
			while satDlg do
				WaitMsg(satDlg, 500)
				satDlg = GetDialog("PDADialogSatellite")
			end
		
			local haveSelection = Selection and #Selection > 0 and Selection[1]
			local interaction_enabled = haveSelection and haveSelection:CanBeControlled()
			if interaction_enabled and haveSelection:IsLocalPlayerControlled() and GetDialog("FullscreenGameDialogs") then
				interaction_enabled = false -- dont start interactions when fullscreen ui is up
			end
			
			if CurrentActionCamera then
				interaction_enabled = false
			end
			
			local screenSize_x, screenSize_y = UIL.GetScreenSize():xy()
			local screen_width = screenSize_x + interactableOnScreenMargin
			local screen_height = screenSize_y + interactableOnScreenMargin
			for i, o in ipairs(interactables) do
				local nonALUnit, is_unit
				if IsKindOf(o, "Unit") and not o:IsDead() then
					nonALUnit = not o.ephemeral
					is_unit = true
				end
				if IsValid(o) and (nonALUnit or o.discovered) then 
					local highlight
					if interaction_enabled then
						local front, screen_x, screen_y = GameToScreenXY(o)
						if front and screen_x > 0 and screen_y > 0 and screen_x < screen_width and screen_y < screen_height then
							local action
							highlight, action = haveSelection:CanInteractWith(o, false)
							if highlight and is_unit and action ~= CombatActions.Interact_Talk and not o.ImportantNPC then
								highlight = false
							end
						end
					end
					o:HighlightIntensely(highlight or false, "hotkey")
				end
			end
			Sleep(interactableHighlightUpdateInterval)
		end
	end)
end

if FirstLoad then
	g_MovementFX_Cursor = false
	g_MovementFX_Selection = { }
end

---
--- Applies movement tile contour effects to a selection of units.
---
--- @param obj Unit|table The unit or list of units to apply the effects to.
--- @param pos table|false The position to apply the effects at, or `false` to use the unit's position.
---
function SelectionAddedApplyFX(obj, pos)
	local mode_dlg = GetInGameInterfaceModeDlg()
	if not IsKindOf(mode_dlg, "IModeCommonUnitControl") then return end
	local units = IsKindOf(obj, "Unit") and {obj} or obj
	local action = g_Combat and (mode_dlg.borderline_attack and "CombatAttack" or "CombatMove") or "Exploration"
	HandleMovementTileContour(units, pos or false, action)
end
OnMsg.SelectionAdded = SelectionAddedApplyFX

function OnMsg.SelectionRemoved(obj)
	local mode_dlg = GetInGameInterfaceModeDlg()
	if not IsKindOf(mode_dlg, "IModeCommonUnitControl") and not g_Combat then return end
	HandleMovementTileContour({obj})
end

---
--- Returns the closest object of the specified class under the cursor.
---
--- @param classFilter string|nil The class to filter the objects by. If nil, `priorityList` must be provided.
--- @param priorityList table|nil A table mapping class names to priority values. The object with the highest priority will be returned.
--- @return table|nil The closest object of the specified class under the cursor, or nil if no object is found.
---
function PreciseCursorObjAreaClosestOfType(classFilter, priorityList)
	local objs, distances, _ = GetPreciseCursorObjsArea()
	if not objs then
		return
	end
	distances = distances or empty_table
	assert(#objs == #distances)
	assert(classFilter or priorityList)
	local found, dist, foundPriority
	for i, obj in ipairs(objs) do
		local distanceToObj = distances[i] or 0
		if not found or distanceToObj < dist then
			if priorityList then
				local thisObjPriority = priorityList[obj.class] or -1
				if not foundPriority or thisObjPriority >= foundPriority then
					found = obj
					dist = distanceToObj
					foundPriority = thisObjPriority
				end
			elseif classFilter and IsKindOf(obj, classFilter) then
				found = obj
				dist = distanceToObj
			end
		end
	end
	return found
end

local _closest_unit_under_cursor

---
--- Returns the closest unit object under the cursor.
---
--- If a unit is under the cursor, it will be returned. If not, the function will attempt to find the closest unit within the cursor's voxel. If that fails, it will search for the closest unit within a small area around the cursor, excluding mercenaries.
---
--- If the game is in combat mode, this function will always return nil.
---
--- @param cursorPos table|nil The cursor position, as a table with x, y, z fields. If not provided, the current cursor position will be used.
--- @return table|nil The closest unit object under the cursor, or nil if no unit is found.
---
function IModeCommonUnitControl:GetUnitUnderMouse(cursorPos)
	local unit = PreciseCursorObjAreaClosestOfType("Unit")
	if unit then
		return unit
	end
	if not cursorPos then
		cursorPos = GetCursorPos()
	end
	local unitInVoxel = GetUnitInVoxel(cursorPos)
	if unitInVoxel then
		return unitInVoxel
	end

	if GetUIStyleGamepad() then
		if g_Combat then return end
		local vAround = GetVoxelBBox(cursorPos, 0.5, "with_z", "dont_snap")
		_closest_unit_under_cursor = nil
		MapForEach(vAround, "Unit", const.efVisible, function(obj, cursorPos, vAround)
			if vAround:PointInside(obj) -- We need to recheck bounds as mapget is 2D
				and (not _closest_unit_under_cursor or IsCloser(obj, cursorPos, _closest_unit_under_cursor))
				and not IsMerc(obj)
			then
				_closest_unit_under_cursor = obj
			end
		end, cursorPos, vAround)
		if _closest_unit_under_cursor then
			return _closest_unit_under_cursor
		end
	else
		-- Selection through walls.
		local camera = camera.GetEye()
		local cursor = GetTerrainCursor()
		local closest, closest_hit
		for i, u in ipairs(g_Units) do
			local collided, hit_pos = GetBodyHitArea(camera, cursor, u)
			if collided and (not closest or IsCloser(camera, hit_pos, closest_hit)) then
				closest = u
				closest_hit = hit_pos
			end
		end
		if closest then
			return closest
		end
	end
end

local function lShouldBeHighlightedEnemy(u)
	return SelectedObj and IsKindOf(u, "Unit") and not u:IsDead() and u:IsOnEnemySide(SelectedObj)
end

local _highestPointX, _highestPointY, _highestPointZ
local _lowestPointX, _lowestPointY, _lowestPointZ

local function lGetHigherLowerTunnelPositions(x, y, z)
	if not z then
		z = terrain.GetHeight(x, y)
	end
	if not _highestPointZ or z > _highestPointZ then
		_highestPointX = x
		_highestPointY = y
		_highestPointZ = z
	end
	if not _lowestPointZ or z < _lowestPointZ then
		_lowestPointX = x
		_lowestPointY = y
		_lowestPointZ = z
	end
end

---
--- Handles the logic for updating the floor change tooltip when the cursor position changes.
---
--- @param deleteOnly boolean If true, only deletes the tooltip indicator without updating it.
---
function IModeCommonUnitControl:FloorChangeTooltipLogic(deleteOnly)
	if deleteOnly then
		SetAPIndicator(false, "floor-change", false, "appending", true)
		return
	end
	local lowestPointFloor, highestPointFloor

	local cursor_obj = GetCursorObj()
	if cursor_obj and IsKindOf(cursor_obj, "RoofPlaneSlab") and cursor_obj.room and cursor_obj.room.is_roof_visible then
		lowestPointFloor = -1
	else
		_highestPointX, _highestPointY, _highestPointZ = nil, nil, nil
		_lowestPointX, _lowestPointY, _lowestPointZ = nil, nil, nil

		local px, py, pz = SnapToVoxel(GetCursorPos():xyz())
		ForEachPassSlabStep(px, py, pz, const.TunnelTypeLadder, function(x, y, z, tunnel)
			if not tunnel then return end
			lGetHigherLowerTunnelPositions(tunnel:GetPosXYZ())
			lGetHigherLowerTunnelPositions(tunnel.end_point:xyz())
		end)

		local eye = camera.GetEye()
		local obj = MapGetFirst(eye, point(px, py, pz), guim, "Ladder")
		if obj then
			local x1, y1, z1, x2, y2, z2 = obj:GetTunnelPositions()
			if x1 then
				lGetHigherLowerTunnelPositions(x1, y1, z1)
				lGetHigherLowerTunnelPositions(x2, y2, z2)
			end
		end

		if _highestPointX then
			highestPointFloor = GetFloorOfPos(_highestPointX, _highestPointY, _highestPointZ)
			lowestPointFloor = GetFloorOfPos(_lowestPointX, _lowestPointY, _lowestPointZ)
		end
	end

	local text
	if highestPointFloor ~= lowestPointFloor then
		local floor = cameraTac.GetFloor()
		if lowestPointFloor and lowestPointFloor < floor then
			text = T(509798634721, "(<ShortcutButton('actionCamFloorDown')>) Floor Down")
		elseif highestPointFloor and highestPointFloor > floor then
			text = T(399501620165, "(<ShortcutButton('actionCamFloorUp')>) Floor Up")
		end
	end
	if text then
		SetAPIndicator(0, "floor-change", text, "appending", true)
	else
		SetAPIndicator(false, "floor-change", false, "appending", true)
	end
end

local no_extreme_range_indicator = {
	Overwatch = true,
	ThrowGrenadeA = true,
	ThrowGrenadeB = true,
	ThrowGrenadeC = true,
	ThrowGrenadeD = true,
	DoubleTossA = true,
	DoubleTossB = true,
	DoubleTossC = true,
	DoubleTossD = true,
	MarkTarget = true,
}

---
--- Determines whether the "Mark Target" action should be used for the given attacker and target.
---
--- @param attacker Unit The attacking unit.
--- @param target Unit The target unit.
--- @return boolean Whether the "Mark Target" action should be used.
function ShouldUseMarkTarget(attacker, target)
	if g_Combat or not IsKindOf(attacker, "Unit") or not IsKindOf(target, "Unit") or not attacker:IsOnEnemySide(target) or target:IsDead() then
		return
	end
	if attacker.marked_target_attack_args and attacker.marked_target_attack_args.target == target then
		return
	end
	local weapon = attacker:GetActiveWeapons() or attacker:GetActiveWeapons("UnarmedWeapon")
	if not IsKindOfClasses(weapon, "MeleeWeapon", "UnarmedWeapon") then
		return
	end

	local voxels = GetMeleeRangePositions(attacker)
	local x, y, z = SnapToPassSlabXYZ(target)
	local ppos = x and point_pack(x, y, z) or point_pack(target:GetPosXYZ())
	if not table.find(voxels, ppos) and CombatActions.MarkTarget:GetUIState({attacker}) == "enabled" then
		return true
	end
end

local restore_cam_thread = false

---
--- Updates the target information for the current unit control mode.
---
--- @param pos table|nil The position of the mouse cursor, or nil if the cursor is not over a valid target.
--- @return boolean Whether the potential target is an enemy.
---
function IModeCommonUnitControl:UpdateTarget(pos)
	self.target_pos = false

	if not camera.GetEye():IsValid() then
		local any_unit = SelectedObj or g_Units[1]
		if not restore_cam_thread and any_unit then
			restore_cam_thread = CreateRealTimeThread(function(unit)
				cameraTac.SetFollowTarget(unit)
				WaitNextFrame(2)
				cameraTac.SetFollowTarget(false)
				cameraTac.SetOverview(true)
				WaitNextFrame(2)
				cameraTac.SetOverview(false)
				restore_cam_thread = false
			end, any_unit)
		end
		return
	end

	-- If the cursor is over an object that overrides the voxel selection with the object's position.
	-- If there is a combat object on the voxel selection it must also be considered "targetted"
	-- If the cursor is over a badge (or UI which has highlit a badge), we treat it as if it is over the object.
	local enemy_pos
	local mouse_obj = pos and self:GetUnitUnderMouse(pos)
	local freeAimDlg = IsKindOf(self, "IModeCombatFreeAim")
	local freeAimMode = not self.crosshair and (freeAimDlg or IsKindOf(self, "IModeCombatAreaAim"))
	freeAimMode = freeAimMode or self.crosshair and self.crosshair.context.free_aim
	
	local mouseUIFocus = self.desktop.last_mouse_target
	if mouseUIFocus and not mouse_obj and not GetUIStyleGamepad() then
		local n = self.desktop.last_mouse_target:ResolveId("node")
		if IsKindOf(n, "CombatBadge") then
			mouse_obj = n.context
		end
	end
	
	if not cameraTac.IsActive() then
		mouse_obj = false
	end
	
	if IsKindOf(mouse_obj, "Unit") and mouse_obj.visible and not mouse_obj:IsDead() then
		if not freeAimMode or mouse_obj ~= SelectedObj then
			self.potential_target = mouse_obj
			self.target_pos = mouse_obj:GetPos()
			self.potential_target_is_enemy = lShouldBeHighlightedEnemy(mouse_obj)
			self.potential_target_via_voxel = false
		else
			self.potential_target = false
			self.potential_target_via_voxel = false
		end
	elseif pos then
		local pass_pos = GetPassSlab(pos)
		self.potential_target = false
		self.potential_target_is_enemy = false
		self.potential_target_via_voxel = false
		self.penalty = 0
		if pass_pos then
			self.target_pos = pass_pos
			local unit = GetUnitInVoxel(pass_pos)
			if unit and not unit:IsDead() then
				self.potential_target = unit
				self.potential_target_is_enemy = lShouldBeHighlightedEnemy(unit)
				self.potential_target_via_voxel = true
				
				mouse_obj = self.potential_target
			end
		end
	end
	
	local updatePenalty = (self.potential_target and self.potential_target_is_enemy) or -- In combat mouse-over non-target
								(self.potential_interactable_action and self.potential_interactable_action.id == "Interact_Attack") or --Interactables that can be attacked
								(freeAimMode and self.potential_target ~= SelectedObj) or -- In free aim
								(self.target and not self.potential_target) -- In attack mode
	local freeAttackTarget
	if pos and SelectedObj and updatePenalty then
		local weapon = SelectedObj:GetActiveWeapons()
		if IsKindOf(weapon, "MeleeWeapon") and self.action and self.action.id == "KnifeThrow" then
			self.penalty = 0
			if freeAimMode then
				local target = self.potential_target or self.target or GetUnitInVoxel(GetPassSlab(pos))
				if not IsCloser(SelectedObj, target or pos, CombatActions.KnifeThrow:GetMaxAimRange(SelectedObj, weapon) * const.SlabSizeX + 1) then
					self.penalty = -100
				end
			end
		elseif not weapon or IsKindOf(weapon, "MeleeWeapon") then
			if IsKindOf(self, "IModeCombatFreeAim") then
				local _, target_obj = self:GetFreeAttackTarget(self.potential_target, self.attacker)
				if target_obj and IsValid(target_obj) then
					freeAttackTarget = target_obj
				end
			else
				freeAttackTarget = self.potential_target or self.target or GetUnitInVoxel(GetPassSlab(pos))
			end
			local action = rawget(self, "action") or SelectedObj:GetDefaultAttackAction()
			local action_weapon = action:GetAttackWeapons(SelectedObj) 
			local inRange = SelectedObj:CanAttack(freeAttackTarget or pos, action_weapon, action, 0, nil, nil, freeAimMode)
			if not inRange then
				self.penalty = -100 
			end
		else
			local target_pos
			local target_unit = self.potential_target or self.target
			if not IsValid(target_unit) then
				target_pos = GetPassSlab(pos) or SnapToVoxel(pos)
				target_unit = GetUnitInVoxel(target_pos)
			end
			local distanceToUnit = SelectedObj:GetVisualDist(target_unit or target_pos:IsValidZ() and target_pos or target_pos:SetTerrainZ())
			self.penalty = weapon:GetAccuracy(distanceToUnit) - 100
			if self.action and target_unit and not freeAimMode then
				if self.action_targets then
					self.action_targets = self.action:GetTargets({SelectedObj}) or empty_table
				end
				if not table.find(self.action_targets, target_unit) then
					self.penalty = -200
				end
			end
		end 
		
		local action = rawget(self, "action") or SelectedObj:GetDefaultAttackAction()
		if action.group == "FiringModeMetaAction" then
			action = GetUnitDefaultFiringModeActionFromMetaAction(SelectedObj,action)
		end
		
		-- special case
		if not freeAimMode and ShouldUseMarkTarget(SelectedObj, mouse_obj) then
			action = CombatActions.MarkTarget
		end
		
		if not rawget(self, "disable_mouse_indicator") and (freeAimMode or lShouldBeHighlightedEnemy(mouse_obj)) then
			if freeAimMode then
				local apCost = action:GetAPCost(SelectedObj, { target = mouse_obj })
				if self.action and self.action.id == "Overwatch" then
					SetAPIndicator(apCost > 0 and apCost or false, "attack")
				else
					local freeAimApIndicatorText = T(333335408841, "Free Aim")
					if freeAimDlg then
						if self.current_firing_mode then
							local firingModeText = false
							local shortcuts = GetShortcuts("gamepadActionFreeAimToggle")
							
							-- We need to calculate the gamepad shortcut separately in order 
							-- to scale it to the same size as other AP indicator icons.
							if GetUIStyleGamepad() then
								local gamepadShortcut = shortcuts and shortcuts[3] or ""
								gamepadShortcut = "<" .. gamepadShortcut .. "Small>"
								firingModeText = T{521088736897, "<gamepadShortcut> Mode: <ActionName>",
									gamepadShortcut = T{gamepadShortcut},
									ActionName = self.current_firing_mode.DisplayName
								}
							else
								firingModeText = T{537856925216, "[<ShortcutName('gamepadActionFreeAimToggle')>] Mode: <ActionName>",
									ActionName = self.current_firing_mode.DisplayName
								}
							end
						
							freeAimApIndicatorText = freeAimApIndicatorText .. T(226690869750, "<newline>") .. firingModeText
						end
					end
				
					SetAPIndicator(apCost > 0 and apCost or false, "attack", freeAimApIndicatorText)
					if action.ActionType == "Melee Attack" then
						local invalidBrutalizeTarget = action.id == "Brutalize" and (not IsKindOf(freeAttackTarget, "Unit") or (IsKindOf(freeAttackTarget, "Unit") and freeAttackTarget:IsDead()))
						if not freeAttackTarget then
							SetAPIndicator(1, "attack", T(316692410666, "No Target"), "appending")
							self.penalty = 0
						elseif freeAttackTarget == SelectedObj or invalidBrutalizeTarget then
							SetAPIndicator(1, "attack", T(638642719736, "Invalid Target"), "appending")
							self.penalty = 0
						end
					end
				end
			elseif action.id == "MeleeAttack" and IsKindOf(self, "IModeExploration") then
				local apCost = action:GetAPCost(SelectedObj, { target = mouse_obj })
				local weapon = action:GetAttackWeapons(SelectedObj)
				local can_attack, reason = SelectedObj:CanAttack(mouse_obj, weapon, action)
				if can_attack then
					SetAPIndicator(apCost > 0 and apCost or false, "attack")
				else
					SetAPIndicator(apCost > 0 and apCost or false, "attack")
					SetAPIndicator(1, "attack", reason, "appending")
				end
			elseif action.id == "MarkTarget" then
				SetAPIndicator(1, "attack", T(163504056969, "Prepare Takedown"), "appending")
			elseif not action or action.AimType ~= "melee-charge" then
				local breakdown = {}
				local apCost = action:GetAPCost(SelectedObj, { target = mouse_obj, ap_cost_breakdown = breakdown })
				if breakdown.move_cost and breakdown.attack_cost then
					local free_move_ap_used = Min(breakdown.move_cost or 0, SelectedObj.free_move_ap)
					apCost = apCost - Max(0, free_move_ap_used)
					-- round the cost to match before/after AP readings
					local unitAp = SelectedObj:GetUIActionPoints()
					local before = unitAp / const.Scale.AP
					local after = (unitAp - apCost) / const.Scale.AP -- free move is already accounted for in apCost
					apCost = (before - after) * const.Scale.AP

				end
				SetAPIndicator(apCost > 0 and apCost or false, "attack")
			end
			self.penalty = self.penalty or 0
			if self.penalty <= -200 then
				SetAPIndicator(1, "range", T(853501212617, "NO SIGHT"), "appending") 
			elseif self.penalty <= -100 and not no_extreme_range_indicator[action.id] then 
				SetAPIndicator(1, "range", T(239610127119, "OUT OF RANGE"), "appending")
			else
				SetAPIndicator(false, "range")
			end 
		end
	else
		SetAPIndicator(false, "attack")
		SetAPIndicator(false, "range")
	end
	self:UpdateCursorImage()
	
	local attackMode = IsKindOf(self, "IModeCombatAttackBase")
	if (not mouseUIFocus or not mouseUIFocus:IsWithin(self)) and -- mouse not on top of ui
		(not attackMode or not self.target) and not next(g_ShowTargetBadge) then -- not attacking or showing target
		SetActiveBadgeExclusive(self.potential_target and self.potential_target.ui_badge and self.potential_target)
	end
	
	-- Dont update any effects and stuff when not in control.
	local myTurn = Selection and #Selection > 0 and (not g_Combat or IsNetPlayerTurn())
	self:FloorChangeTooltipLogic(not myTurn)

	-- These two are subtly different. An unit can take up more than one pos (such as when laying down).
	self.target_pos_has_unit = false
	self.target_pos_occupied = false
	
	local selUnit = Selection[1]
	local selUnitTeam = selUnit and selUnit.team
	if self.target_pos and selUnitTeam then
		local unitInVoxel = GetUnitInVoxel(self.target_pos)
		if unitInVoxel and table.find(selUnitTeam.units, unitInVoxel) or HasVisibilityTo(selUnitTeam, unitInVoxel) then
			self.target_pos_has_unit = unitInVoxel
		end
		local unitOccupyingVoxel = GetOccupiedBy(self.target_pos, selUnit)
		if unitOccupyingVoxel ~= selUnit then
			if unitOccupyingVoxel and table.find(selUnitTeam.units, unitOccupyingVoxel) or HasVisibilityTo(selUnitTeam, unitOccupyingVoxel) then
				self.target_pos_occupied = unitOccupyingVoxel
			end
		end
	end
	
	local tx, ty, tz = self:GetEffectsTargetVoxel()
	self.effects_target_pos = myTurn and tx and point(SnapToVoxel(VoxelToWorld(tx, ty, tz)))
	if self.effects_target_pos_last ~= self.effects_target_pos then Msg("EffectsTargetPosUpdated", self, self.effects_target_pos) end
	
	self:UpdateTargetCovers()
	self:UpdateLinesOfFire()
	
	self.effects_target_pos_last = self.effects_target_pos
	return self.potential_target_is_enemy
end

---
--- Clears the `cover_objs` member array, keeping the array itself.
---
function IModeCommonUnitControl:ClearTargetCovers()
	self:ClearMemberObjArray("cover_objs", "keep")
end

---
--- Updates the target covers for the current unit control mode.
---
--- If the `ShowCovers` effect should not be shown, the target covers are cleared.
--- Otherwise, the target covers are updated based on the current effects target position.
--- If the effects target position has not changed since the last update, no update is performed.
---
--- @param force boolean (optional) If true, the target covers are updated regardless of whether the effects target position has changed.
---
function IModeCommonUnitControl:UpdateTargetCovers(force)
	if not self:ShouldShowEffects("ShowCovers") then
		self:ClearTargetCovers()
		return
	end

--[[	if #self.cover_objs == 0 or self.cover_objs[1]:GetPos() ~= self.effects_target_pos then
		force = true
	end]]
	if not force and self.effects_target_pos and self.effects_target_pos == self.effects_target_pos_last then
		return
	end

	self:ClearTargetCovers()
	if self.effects_target_pos then
		self:ShowCoversShields(self.effects_target_pos, self.potential_target_is_enemy and self.potential_target or false)
	end
end

---
--- Gets the appropriate mouse cursor image based on the action and accuracy.
---
--- @param accuracy number The accuracy of the action.
--- @param action table The action being performed.
--- @param willAttack boolean Whether the action will result in an attack.
--- @return string The path to the mouse cursor image.
---
function GetRangeBasedMouseCursor(accuracy, action, willAttack)
	if action and action.ActionType == "Melee Attack" then
		return "UI/Cursors/Attack_melee.tga"
	end
	
	if willAttack then
		local igi = GetInGameInterfaceModeDlg()
		if igi and igi.crosshair then
			local aim = igi.crosshair.aim
			if aim == 0 then
				return "UI/Cursors/Attack.tga"
			elseif aim == igi.crosshair.maxAimPossible then
				return "UI/Cursors/Attack_2.tga"
			else
				return "UI/Cursors/Attack_1.tga"
			end
		end
		return "UI/Cursors/Attack.tga"
	end
	
	if not accuracy or accuracy == 0 or (action and action.id == "Overwatch") then
		return "UI/Cursors/Range.tga"
	elseif accuracy <= -100 then
		return "UI/Cursors/Range_2.tga"
	else
		return "UI/Cursors/Range_1.tga"
	end
	
	-- Fallback
	return "UI/Cursors/Hand.tga"
end

---
--- Updates the mouse cursor image based on the current game state and player actions.
---
--- This function is responsible for setting the appropriate mouse cursor image based on the current game state, such as the player's current action, the potential target, and whether the player is in a combat or exploration mode.
---
--- The function checks various conditions to determine the correct cursor image to display, including:
--- - If the player is in a bandage action, the cursor will be set to a healing cursor.
--- - If the player can interact with an interactable object, the cursor will be set to an interaction cursor.
--- - If the player is targeting an enemy or in a free-aim mode, the cursor will be set to an attack cursor.
--- - If the player is in a movement mode, the cursor will be set to a travel or impassable cursor depending on the target path.
--- - If the player is in an exploration mode and not targeting anything, the cursor will be set to a travel or impassable cursor depending on the current position.
---
--- @param self IModeCommonUnitControl The instance of the IModeCommonUnitControl class.
---
function IModeCommonUnitControl:UpdateCursorImage()
	if GetUIStyleGamepad() then return end

	local movement = IsKindOf(self, "IModeCombatMovement")
	local exploration = IsKindOf(self, "IModeExploration")
	local canInteract = movement or exploration
	local freeAimMode = not self.crosshair and (IsKindOf(self, "IModeCombatFreeAim") or IsKindOf(self, "IModeCombatAreaAim"))
	freeAimMode = freeAimMode or self.crosshair and self.crosshair.context.free_aim
	
	if self.action == CombatActions.Bandage then
		if self.potential_target and CanBandageUI(SelectedObj, { target = self.potential_target }) then
			self.desktop:SetMouseCursor("UI/Cursors/Healing_on.tga")
		else
			self.desktop:SetMouseCursor("UI/Cursors/Healing_off.tga")
		end
	elseif (canInteract and IsKindOf(self.potential_interactable, "Interactable")) then
		local action = self.potential_interactable_action
		if action == CombatActions.Interact_Talk or action == CombatActions.Interact_Banter then
			self.desktop:SetMouseCursor("UI/Cursors/Speaking.tga")
		else
			if action and action.id == "Interact_Attack" then
				local action = self.action or (SelectedObj and SelectedObj:GetDefaultAttackAction())
				local cursor = GetRangeBasedMouseCursor(self.penalty, action)
				self.desktop:SetMouseCursor(cursor)
			else
				self.desktop:SetMouseCursor("UI/Cursors/Interact.tga")
			end
		end
	elseif (self.potential_target and self.potential_target_is_enemy) or freeAimMode then
		local action = self.action or (SelectedObj and SelectedObj:GetDefaultAttackAction())
		local clickWillAttack = self.crosshair and self.crosshair.context.target == self.potential_target
		local cursor = GetRangeBasedMouseCursor(self.penalty, action, clickWillAttack)
		self.desktop:SetMouseCursor(cursor)
	elseif movement and self.movement_mode then
		if self.target_path then
			self.desktop:SetMouseCursor("UI/Cursors/Travel.tga")
		else
			self.desktop:SetMouseCursor("UI/Cursors/Impassable.tga")
		end
	elseif exploration and not GetDialog("SatelliteCabinet") and not self.potential_target then 
		local inBadge = terminal.desktop.last_mouse_target and terminal.desktop.last_mouse_target["xbadge-instance"]
		if inBadge then
			return
		end
		
		if GetCursorPassSlab() then
			self.desktop:SetMouseCursor("UI/Cursors/Travel.tga")
		else
			self.desktop:SetMouseCursor("UI/Cursors/Impassable.tga")
		end
	else
		self.desktop:SetMouseCursor()
	end
end

---
--- Handles the mouse position event for the IModeCommonUnitControl class.
---
--- This function is responsible for determining whether the AP indicator should be shown or hidden based on the current mouse position. It checks if the mouse is over the IModeCommonUnitControl instance itself, over a badge, or if the current combat action is for an ally. If the crosshair is visible, the indicator is always hidden.
---
--- @param pt table The current mouse position as a table with `x` and `y` fields.
---
function IModeCommonUnitControl:OnMousePos(pt)
	-- Hide the AP indicator if the cursor is over some UI of mine, or over a badge (badges are my siblings)
	local meFocused = self:IsWithin(self.desktop.last_mouse_target)
	local overBadge = GetParentOfKind(self.desktop.last_mouse_target, "BadgeHolderDialog")
	local showIndicator = meFocused or overBadge or IsCombatActionForAlly(self.action)
	if self.crosshair then
		showIndicator = false
	end
	
	local apIndicator = self:ResolveId("idApIndicator")
	if apIndicator and showIndicator ~= apIndicator.visible then
		apIndicator:SetVisible(showIndicator)
	end
	self.show_world_ui = showIndicator
end

-- Cover visualization

---
--- Determines whether effects should be shown based on the current game state and user settings.
---
--- This function checks various conditions to determine if effects should be shown, such as whether cheats are enabled, if the current mode is a combat mode, if the selected unit can be controlled, and if a setpiece is playing. It also checks the user's account storage option for the "effects" setting, which can be set to "Always", "Combat", or a boolean value.
---
--- If the effects setting is "Always", the function will return true. If the setting is "Combat", the function will check if the current mode is a combat mode and if the effects target position is valid. If either of these conditions is met, the function will return true.
---
--- The function also checks if the effects should only be shown in movement mode without a target, or if the potential target is a unit. This is to ensure that effects are only shown in the appropriate game states.
---
--- @param setting string The name of the account storage option for the "effects" setting.
--- @return boolean Whether effects should be shown.
---
function IModeCommonUnitControl:ShouldShowEffects(setting)
	if CheatEnabled("IWUIHidden") then return false end
	if IsKindOf(self, "IModeCombatBase") and self.crosshair then return false end
	if not Selection[1] or not Selection[1]:CanBeControlled() then return false end
	if IsSetpiecePlaying() then return false end

	local value = GetAccountStorageOptionValue(setting)
	setting = type(value) == "boolean" and value and "Always" or value
	local show = false
	if setting == "Always" then
		return true
	elseif setting == "Combat" then
		if IsKindOf(self, "IModeCombatBase") and self.effects_target_pos then
			if GetPassSlabXYZ(self.effects_target_pos) then
				show = true  -- target_path should be updated first
			end
		end
	end

	if show then
		-- Effects are only shown in movement mode in combat OR if potential target is a unit
		local movementModeNoTarget = (self.movement_mode and not self.potential_target)
		local unitTarget = IsKindOf(self, "IModeCombatMovement") and IsKindOf(self.potential_target, "Unit")
		show = movementModeNoTarget or unitTarget
	end
	return show
end

---
--- Determines the voxel coordinates of the effects target position.
---
--- This function takes an optional position parameter and returns the voxel coordinates (gx, gy, gz) of the corresponding world position. If no position is provided, it uses the `self.target_pos` property.
---
--- The function first extracts the world coordinates (wx, wy, wz) from the provided position or `self.target_pos`. If the world Z coordinate (wz) is not provided, it is obtained from the terrain height at the given (wx, wy) coordinates.
---
--- The function then iterates upwards from the initial voxel coordinates (gx, gy, gz) obtained from the world coordinates, until the voxel Z coordinate (gz) is greater than or equal to the world Z coordinate (wz). This ensures that the returned voxel coordinates represent the topmost voxel at the given position.
---
--- @param pos table|nil The world position to get the voxel coordinates for. If not provided, `self.target_pos` is used.
--- @return number, number, number The voxel coordinates (gx, gy, gz) of the effects target position.
---
function IModeCommonUnitControl:GetEffectsTargetVoxel(pos)
	pos = pos or self.target_pos
	if not pos then return end

	local wx, wy, wz = pos:xyz()
	wz = wz or terrain.GetHeight(wx, wy)
	local gx, gy, gz = WorldToVoxel(wx, wy, wz)
	while true do
		local x, y, z = VoxelToWorld(gx, gy, gz)
		if z < wz then
			gz = gz + 1
		else
			break
		end
	end
	
	return gx, gy, gz
end

local cover_shields = {
	[const.CoverLow] = "IwCoverHalf",
	[const.CoverHigh] = "IwCoverFull",
}

---
--- Shows cover shields for a given world position, stance, and attack position.
---
--- This function is responsible for displaying cover shield effects based on the covers present at the given world position. It takes into account the unit's stance, attack direction, and whether the potential target is an enemy.
---
--- The function first retrieves the covers at the given world position. It then iterates through the covers, checking if they have a corresponding cover shield class. If a cover shield class is found, it creates a cover shield object and positions it at the appropriate angle and offset from the world position.
---
--- Additionally, the function creates a particle effect to visually represent the cover shield, if the cover shield class is "IwCoverHalf" or "IwCoverFull". The particle effect is positioned relative to the world position and the cover shield angle.
---
--- @param world_pos table The world position to show the cover shields for.
--- @param stance string The stance of the unit.
--- @param attack_pos table The attack position, used to determine the attack direction.
--- @param force_inactive boolean Whether to force the cover shields to be inactive.
---
function IModeCommonUnitControl:ShowCoversShields(world_pos, stance, attack_pos, force_inactive)
	local covers = GetCoversAt(world_pos)
	if not covers then
		return
	end
	stance = stance or self.targeting_blackboard and self.targeting_blackboard.playerToDoStanceAtEnd or Selection[1].stance
	local attack_dir 
	if attack_pos then
		if attack_pos:Dist(world_pos) > 0 then
			attack_dir = SetLen(world_pos - attack_pos, guim)
		else
			attack_dir = Rotate(point(guim, 0, 0), Selection[1]:GetAngle())
		end
	end

	for i = 0, 3 do
		local angle = i * 90 * 60
		local cover = covers[angle]
		local cover_class = cover and cover_shields[cover]
		
		if attack_dir then
			local dir = Rotate(point(guim, 0, 0), angle)
			if Dot2D(dir, attack_dir) < 0 then
				cover_class = false
			end
		end
		
		if cover_class then
			local colormod = const.CoverUIColorModifier
			if force_inactive or (cover == const.CoverLow and stance == "Standing") then
				colormod = const.InactiveCoverUIColorModifier
				cover_class = "IwCoverBroken"
			end
			
			local showAlways = GetAccountStorageOptionValue("ShowCovers") and GetAccountStorageOptionValue("ShowCovers") == "Always"
			if not self.potential_target_is_enemy and (IsKindOf(self, "IModeCombatMovement") or IsKindOf(self, "IModeCombatMovingAttack") or showAlways) then
				local obj = PlaceObject(cover_class)			
				table.insert(self.cover_objs, obj)
				obj:SetEnumFlags(const.efVisible)
				obj:SetAngle(angle)
				obj:SetScale(70)
				obj:SetColorModifier(colormod)
				obj:SetPos(world_pos)
			end
			
			--show new cover shield effect
			if cover_class == "IwCoverHalf" or cover_class == "IwCoverFull" then
				--create the particle effect with delay
				CreateGameTimeThread(function()
					local delayTime = 0
					Sleep(delayTime)
					
					local mov_avatar = self.targeting_blackboard and self.targeting_blackboard.movement_avatar
					if not mov_avatar and not self.potential_target_is_enemy then return end
					local wallParticle = self.potential_target_is_enemy and PlaceParticles("UI_CoverGlow_Idle_Enemy") or PlaceParticles("UI_CoverGlow_Idle")
					table.insert(self.cover_objs,wallParticle)
					wallParticle:SetAngle(angle + 90 * 60)
					local offset
					local offsetNumber = const.SlabSizeX / 2
					if angle == 0 then
						offset = point(- offsetNumber, 0, 0)
					elseif angle == 5400 then
						offset = point(0, - offsetNumber, 0)
					elseif angle == 10800 then
						offset =  point(offsetNumber, 0, 0)
					elseif angle == 16200 then
						offset = point(0, offsetNumber, 0)
					end
					wallParticle:SetPos(world_pos + offset)
				end)
			end
		end
	end
end

---
--- Generates a cover shield bonus effect for a given unit or position.
---
--- @param unit Unit|point The unit or position to generate the effect for.
--- @param stance? string The stance of the unit. Defaults to the unit's current stance.
--- @param side? string The side of the unit. Defaults to the unit's team side.
---
function GetCoverShieldBonusEffect(unit, stance, side)
	local posForEffect
	if IsKindOf(unit, "Unit") then
		posForEffect = unit:GetPos()
	else
		posForEffect = unit
	end

	local covers = GetCoversAt(posForEffect)
	if not covers then
		return
	end
	local unitStance = stance or unit.stance
	local side = side or unit.team.side
	local isEnemy = side == "enemy1" or side == "enemy2" or side == "enemyNeutral"

	for i = 0, 3 do
		local angle = i * 90 * 60
		local cover = covers[angle]
		local cover_class = cover and cover_shields[cover]
		
		if cover_class then
			if cover == const.CoverLow and unitStance == "Standing" then
				cover_class = "IwCoverBroken"
			end
			
			if cover_class == "IwCoverHalf" or cover_class == "IwCoverFull" then
				--create the particle effect with delay
				CreateGameTimeThread(function()
					local delayTime = 0
					Sleep(delayTime)				
					local shieldCoverConfirm = isEnemy and PlaceParticles("UI_CoverGlow_Confirm_Enemy") or PlaceParticles("UI_CoverGlow_Confirm")
					shieldCoverConfirm:SetAngle(angle + 90 * 60)
					local offset
					local offsetNumber = const.SlabSizeX / 2
					if angle == 0 then
						offset = point(- offsetNumber, 0, 0)
					elseif angle == 5400 then
						offset = point(0, - offsetNumber, 0)
					elseif angle == 10800 then
						offset =  point(offsetNumber, 0, 0)
					elseif angle == 16200 then
						offset = point(0, offsetNumber, 0)
					end
					shieldCoverConfirm:SetPos(posForEffect + offset)
				end)
			end
		end
	end
end

function OnMsg.UnitAnyMovementStart(unit, target, toDoStance)
	if unit:IsMerc() then
		GetCoverShieldBonusEffect(target, toDoStance or unit.stance , "player")
	end	
end

--[[function OnMsg.UnitMovementDone(unit)
	local playerTeam = GetPoVTeam()
	if g_Combat and HasVisibilityTo(playerTeam, unit) then GetCoverShieldBonusEffect(unit) end
end

function OnMsg.UnitStanceChanged(unit)
	local playerTeam = GetPoVTeam()
	if g_Combat and HasVisibilityTo(playerTeam, unit) then GetCoverShieldBonusEffect(unit) end
end]]


--- Clears the lines of fire effect for the IModeCommonUnitControl instance.
---
--- This function removes all the particle effects associated with the lines of fire
--- and resets the `fx_lof` field to `false`.
---
--- @function ClearLinesOfFire
--- @return nil
function IModeCommonUnitControl:ClearLinesOfFire()
	for _, o in ipairs(self.fx_lof or empty_table) do
		DoneObject(o)
	end
	self.fx_lof = false
end

DefineClass.CRM_VisionLinePreset = {
	__parents = {"CRMaterial"},
	group = "VisionLinePreset",
	shader_id = "vision_line",
	properties = {
		{ uniform = true, id = "fill_width", editor = "number", default = 200, scale = 1000, min = 0, max = 1000, slider = true, },
		{ uniform = true, id = "fill_color", editor = "color", default = RGB(0, 255, 0) },
		{ uniform = true, id = "glow_color", editor = "color", default = RGB(255, 255, 255) },
		{ uniform = true, id = "anim_speed", editor = "number", scale = 1000, default = 1000, slider = true, min = 0, max = 10000},

		{ uniform = true, id = "glow_density", editor = "number", scale = 1000, default = 1000, slider = true, min = 0, max = 1000},
		{ uniform = true, id = "glow_segment", editor = "number", scale = 1000, default = 1000, slider = true, min = 0, max = 100000000},
		{ uniform = true, id = "end_fade_distance", editor = "number", scale = 1000, default = 1000, slider = true, min = 0, max = 10000000},
		{ uniform = true, id = "end_fade_falloff", editor = "number", scale = 1000, default = 3000, slider = true, min = 0, max = 10000},

		{ uniform = true, id = "length", editor = "number", scale = 1000, default = 1, no_edit = true, },
		{ uniform = true, id = "half_width", editor = "number", scale = 1000, default = 250, help = "Generated geometry width" },
	}
}


--- Updates the lines of fire effect for the IModeCommonUnitControl instance.
---
--- This function calculates and displays the lines of fire between the player's
--- unit and all valid enemy targets. The lines are only shown in certain
--- conditions, such as when the player is in movement mode and the target is
--- a valid attack target.
---
--- The function first checks if the lines of fire should be shown, based on
--- various conditions. If the lines should not be shown, it calls
--- `ClearLinesOfFire()` to remove any existing effects.
---
--- If the lines should be shown, the function calculates the start and end
--- positions of each line, and creates a `Mesh` object to represent the line.
--- The `CRM_VisionLinePreset` material is used to configure the appearance of
--- the lines.
---
--- @function UpdateLinesOfFire
--- @param force boolean Whether to force an update of the lines of fire, even if the target position has not changed.
--- @return nil
function IModeCommonUnitControl:UpdateLinesOfFire(force)
	local show = self:ShouldShowEffects("ShowLOF") and
					not IsKindOf(self, "IModeCombatMovingAttack") and
					not CurrentActionCamera
					
	local displayLinesPotentialTarget = false
	local attacker = Selection[1]
	if attacker then
		displayLinesPotentialTarget = self.potential_target == SelectedObj
	end
	
	-- Dont show lines when on a position that you cannot path to
	if not displayLinesPotentialTarget then
		show = show and self.target_path
	end

	-- Effects are only shown in movement mode, and attack data is calculated for effects pos then only.
	-- Effects are also shown when rolling over the player unit
	show = show and (g_UIAttackCachePredicted or displayLinesPotentialTarget)
	show = show and attacker and attacker:IsIdleCommand()
	
	if not show then
		self:ClearLinesOfFire()
		return
	end
	
	-- The on state changed, force redraw. This can happen due to options or other stuff that
	-- doesn't involve moving the mouse and changing the effects pos
	if show and not self.fx_lof then force = true end
	if self.effects_target_pos == self.effects_target_pos_last and not force then return end
	
	local unitInVoxel = self.target_pos_has_unit
	local sectorOccupied = self.target_pos_occupied
	if (sectorOccupied or unitInVoxel) and not displayLinesPotentialTarget then
		return
	end
	
	self:ClearLinesOfFire()
	self.fx_lof = {}
	
	-- Lines start at the effects passable pos, this is either the unit pos or
	-- predicted movement slab. The early return here is after the clear to support the
	-- option to "Always" show the lines.
	local passableVox = self.effects_target_pos
	if not passableVox then return end
	local passableVoxZ = false
	if not passableVox:IsValidZ() then
		passableVoxZ = terrain.GetHeight(passableVox:x(), passableVox:y())
	else
		passableVoxZ = passableVox:z()
	end
	
	-- Line of fire lines are shown between the mouse pos and all "good attack" targets
	local enemiesGoodAttack = UIGetEnemiesGoodAttack()
	for enemy, isGoodAttack in pairs(enemiesGoodAttack) do
		if isGoodAttack then
			local color = Mesh.ColorFromTextStyle("LineOfFire")
			local x, y, z = enemy:GetPosXYZ()
			z = enemy:IsValidZ() and z or terrain.GetHeight(x, y)
			local dir = point(x - passableVox:x(), y - passableVox:y(), z - passableVoxZ)
			local length = dir:Len()
			local meshPtr = pstr("")

			CRTrail_AppendLineSegment(meshPtr, point(passableVox:x(), passableVox:y(), passableVoxZ), point(x, y, z), false, false, false)
			
			local fx_lof = PlaceObject("Mesh")
			fx_lof:SetMeshFlags(const.mfWorldSpace)
			table.insert(self.fx_lof, fx_lof)
			
			local mat = CRM_VisionLinePreset:GetById("DefaultVision")
			mat = mat:Clone()
			mat.length = length
			fx_lof:SetCRMaterial(mat)
			fx_lof:SetPos(passableVox:SetZ(passableVoxZ + self.fx_lof_offset))
			fx_lof:SetMesh(meshPtr)
		end
	end
end

---
--- Toggles the hide/reveal state of the selected units.
---
--- If the selected units are currently hidden, this function will reveal them.
--- If the selected units are currently visible, this function will hide them.
---
--- @param self IModeCommonUnitControl The instance of the IModeCommonUnitControl object.
function IModeCommonUnitControl:ToggleHide()
	local state = CombatActions.Hide:GetUIState(Selection)
	local action = state == "hidden" and CombatActions.Reveal or CombatActions.Hide
	if action:GetUIState(Selection) == "enabled" then
		action:UIBegin(Selection)
	end
end

---
--- Sets the visibility of the IModeCommonUnitControl object.
---
--- @param self IModeCommonUnitControl The instance of the IModeCommonUnitControl object.
--- @param vis boolean The new visibility state.
--- @param ... any Additional arguments to pass to the parent SetVisible function.
---
function IModeCommonUnitControl:SetVisible(vis, ...)
	GamepadUnitControl.SetVisible(self, vis, ...)
	if vis then
		local combatLogButton = self.idCombatLogButton
		if combatLogButton then
			combatLogButton:InvalidateLayout()
		end
	end
end

---
--- Updates the UI state of the "Take Cover" action button in the IModeCommonUnitControl dialog.
---
--- This function is called in response to the UnitMovementDone and CombatActionEnd messages.
--- It retrieves the IModeCommonUnitControl dialog and updates the context of the "Take Cover" action button.
---
--- @param self IModeCommonUnitControl The instance of the IModeCommonUnitControl object.
---
function UpdateTakeCoverAction()
	local dlg = GetInGameInterfaceModeDlg()
	if not IsKindOf(dlg, "IModeCommonUnitControl") then return end
	
	local btn = dlg:ResolveId("TakeCover")
	if btn then 
		btn:SetContext(btn.context)
	end
end

local function UpdateTakeCoverOnUnitEvent()
	UpdateTakeCoverAction()
end

OnMsg.UnitMovementDone = UpdateTakeCoverOnUnitEvent
OnMsg.CombatActionEnd = UpdateTakeCoverOnUnitEvent

--...

function OnMsg.GatherFXActions(list)
	table.insert(list, "Move")
end

-- Update HUD actions if rebound
function OnMsg.OptionsApply()
	ObjModified(SelectedObj)
	ObjModified("OptionsApply")
end

---
--- Forces an update of the common unit control UI.
---
--- This function is called in response to the CombatStarting message.
--- It retrieves the current in-game interface mode dialog and updates the context of the "idCommonUnitControl" window.
---
--- @param recreate boolean (optional) Whether to recreate the UI elements.
--- @param igiMOverride IModeCommonUnitControl (optional) The in-game interface mode dialog to use instead of the current one.
---
function ForceUpdateCommonUnitControlUI(recreate, igiMOverride)
	local mode = igiMOverride or GetInGameInterfaceModeDlg()
	local context_window = mode and mode:ResolveId("idCommonUnitControl")
	if context_window then
		context_window:OnContextUpdate(nil, recreate)
	end
end

function OnMsg.RepositionStart()
	ObjModified(Selection)
	SetInGameInterfaceMode("IModeCombatMovement")
end

function OnMsg.SetpieceStarting()
	local dlg = GetInGameInterfaceModeDlg();
	if IsKindOf(dlg, "IModeCombatAttackBase") then
		SetInGameInterfaceMode("IModeCombatMovement")
	end
end

function OnMsg.RepositionEnd()
	ObjModified(Selection)
end
OnMsg.CombatStarting = ForceUpdateCommonUnitControlUI

function OnMsg.TurnStart()
	ObjModified(Selection)
end

function OnMsg.CombatActionEnd(unit)
	if unit == SelectedObj then
		ObjModified(Selection)
	end
end

function OnMsg.SelectionChange(sel)
	if not Selection or #Selection == 0 then return end
	local unit = Selection[1]
	if not IsKindOf(unit, "Unit") then return end
	local dlg = GetInGameInterfaceModeDlg()

	if IsKindOf(dlg, "IModeCombatAttackBase") then
		SetInGameInterfaceMode("IModeCombatMovement")
		return
	end

	if IsKindOf(dlg, "IModeCommonUnitControl") then
		dlg:ClosePopup()
	end
end

-- Stealth

DefineClass.StealthVignetteDialog = {
	__parents = { "XImage", "XDialog" },
	Dock = "box",
	ImageFit = "stretch",
	Image = "UI/Vignette",
	ZOrder = -5,
	Visible = false,
	FocusOnOpen = "",

	FadeInTime = 800,
	FadeOutTime = 500
}

local function lUpdateStealthVignette()
	local targetTransparency = 255
	
	-- Show stealth only if all selected units are hidden
	local hidden = false
	local prone = false
	if Selection and #Selection > 0 then
		for i=1, #Selection do
			local u = Selection[i]
			hidden = hidden or (IsKindOf(u, "StatusEffectObject") and u:HasStatusEffect("Hidden"))
			prone = prone or u.stance == "Prone"
		end
	end
	local targetTransparency = 255
	if hidden and prone then
		targetTransparency = 0
	elseif hidden then
		targetTransparency = 100
	elseif IsActivePaused() then
		targetTransparency = 150
	end
	
	local vignetteDialog = GetDialog("StealthVignetteDialog")
	if not vignetteDialog then
		OpenDialog("StealthVignetteDialog", GetInGameInterface())
		vignetteDialog = GetDialog("StealthVignetteDialog")
	end
	local vignetteOn = vignetteDialog:GetTransparency()
	if targetTransparency == vignetteOn then return end
	
	vignetteDialog:SetTransparency(targetTransparency, 400)
end

-- New UI triggers and stuff
if FirstLoad then
UIRebuildSpam = false
end

--- Rebuilds the UI at the specified location.
---
--- This function is used for debugging purposes to trigger a UI rebuild at a specific location in the code.
---
--- @param where string The location where the UI rebuild is triggered.
function DbgUIRebuild(where)
	print("ui rebuild at", where)
end

function OnMsg.ExplorationComputedVisibility()
	ObjModified("combat_bar_enemies")
end

function OnMsg.CombatComputedVisibility()
	if #Selection == 0 then return end
	ObjModified("combat_bar_enemies")
end

function OnMsg.SelectionChange()
	if g_Combat then return end
	EnsureCurrentSquad()
	ObjModified("hud_squads")
	ObjModified("combat_bar_enemies")
end

function OnMsg.SelectedObjChange()
	if not g_Combat then return end
	EnsureCurrentSquad()
	ObjModified("hud_squads")
	ObjModified(Selection)
	ObjModified("combat_bar_enemies")
end

function OnMsg.TeamsUpdated()
	ObjModified("hud_squads")
end

OnMsg.UnitStealthChanged = lUpdateStealthVignette
OnMsg.SelectionChange = lUpdateStealthVignette
OnMsg.UnitStanceChanged = lUpdateStealthVignette
OnMsg.ActivePauseChanged = lUpdateStealthVignette

function OnMsg.GameExitEditor()
	local igi = GetInGameInterfaceModeDlg()
	if igi and igi.crosshair then
		SelectObj(igi.crosshair.context.attacker)
		return
	end
	SelectObj(nil)
end

function OnMsg.UnitDied(unit)
	if unit ~= SelectedObj then return end
	
	if g_Combat then
		-- If AI is currently playing we need to wait for it to
		-- finish before changing the selection :/
		if g_AIExecutionController then
			CreateMapRealTimeThread(function()
				while g_AIExecutionController do
					WaitMsg("ExecutionControllerDeactivate", 500)
				end
				if SelectedObj ~= unit or not g_Combat then return end
				
				g_Combat:NextUnit(nil, "force")
			end)
			return
		end
	
		g_Combat:NextUnit(nil, "force")
	else
		local dlg = GetInGameInterfaceModeDlg()
		if IsKindOf(dlg, "IModeExploration") then
			dlg:NextUnit(nil, true)
		end
	end
end

-- new ui helpers funcs

---
--- Gets the available reload options for a given weapon and unit.
---
--- @param weapon Firearm The weapon to get reload options for.
--- @param unit Unit The unit that the weapon belongs to. If not provided, the first unit in the selection is used.
--- @param skipSubWeapon boolean If true, sub-weapons of the given weapon will be ignored.
--- @return table The available reload options, where each option is a table with `weapon` and `ammo` fields.
--- @return table Any errors encountered for each weapon, where the key is the weapon and the value is the error.
---
function GetReloadOptionsForWeapon(weapon, unit, skipSubWeapon)
	if not unit and #Selection == 0 then return {} end
	unit = unit or Selection[1]
	
	local weapons = {}
	if not skipSubWeapon then
		if IsKindOf(weapon, "Firearm") then
			for slot, item in sorted_pairs(weapon.subweapons) do
				if IsKindOf(item, "Firearm") then
					weapons[#weapons + 1] = item
				end
			end
		end
	end
	weapons[#weapons + 1] = weapon

	local options = {}
	local errors = {}
	for _, wpn in ipairs(weapons) do
		local availableAmmo = unit:GetAvailableAmmos(wpn, nil, "unique")
		local available, err = IsWeaponAvailableForReload(wpn, availableAmmo) 
		if available then
			for i, ammo in ipairs(availableAmmo) do
				options[#options + 1] = { weapon = wpn, ammo = ammo }
			end
		else
			errors[wpn] = err
		end
	end
	
	return options, errors
end

---
--- Gets the weapon and ammo to use for a quick reload action.
---
--- @param parent table The parent UI element that contains the quick reload button.
--- @param weapon Firearm The weapon to get the quick reload options for.
--- @return number|false The index of the weapon to reload, or false if no valid weapon is found.
--- @return table|false The ammo to use for the reload, or false if no valid ammo is found.
---
function GetQuickReloadWeaponAndAmmo(parent, weapon)
	local wep = weapon or parent:ResolveId("node"):ResolveId("node").context
	if not wep then return false end
	local unit = SelectedObj
	if not unit then return false end
	
	local _, __, wl = unit:GetActiveWeapons()
	local idx = table.find(wl, wep)
	
	local ammos = unit:GetAvailableAmmos(wep, nil, "unique")
	local can, err = IsWeaponAvailableForReload(wep, ammos)
	if not can then return false, err end
	if can and err == AttackDisableReasons.FullClipHaveOther then return false, err end

	local currentAmmo = wep.ammo and wep.ammo.class
	if currentAmmo then		
		local haveMoreFromCurrent = table.find(ammos, "class", currentAmmo)
		currentAmmo = haveMoreFromCurrent and ammos[haveMoreFromCurrent] or ammos[1]
	else
		-- Put in first ammo if no ammo loaded
		currentAmmo = ammos[1]
	end

	return idx, currentAmmo
end

---
--- Executes a quick reload action for the specified weapon.
---
--- @param parent table The parent UI element that contains the quick reload button.
--- @param weapon Firearm The weapon to perform the quick reload on.
--- @param delayed_fx boolean Whether to apply a delayed visual effect for the reload.
--- @return boolean True if the quick reload was successful, false otherwise.
---
function QuickReloadButton(parent, weapon, delayed_fx)
	local unit = SelectedObj
	local wepIdx, ammo = GetQuickReloadWeaponAndAmmo(parent, weapon)
	if not wepIdx then return end
	CombatActions.Reload:Execute({unit}, { weapon = wepIdx, target = ammo.class, delayed_fx = delayed_fx, item_id = weapon and weapon.id })
	return true
end

if FirstLoad then
	UICombatBarShown = true
	UICombatBarShowLast = true
	UIHidingThread = false
end

function OnMsg.IGIModeChanging(prev, new)
	-- If going into exploration make the bar visible and start the countdown for hiding.
	UICombatBarShown = true
	ObjModified("UICombatBarShown")
	
	local dlg = GetInGameInterfaceModeDlg()
	local bar = dlg and dlg:ResolveId("idBottomBar")
	if bar then
		ApplyCombatBarHidingAnimation(bar, true, true)
		if new == "IModeExploration" then
			ApplyCombatBarHidingAnimation(bar, false)
		end
	end
end

function OnMsg.GameOptionsChanged()
	local dlg = GetInGameInterfaceModeDlg()
	local bar = dlg and dlg:ResolveId("idBottomBar")
	if bar then
		ApplyCombatBarHidingAnimation(bar, true, true)
	end
end

local lHideCombatBarAfter = 200
ui_CombatBarAnimationDuration = 150
---
--- Applies an animation to hide or show the combat bar in the user interface.
---
--- @param self table The UI element that contains the combat bar.
--- @param show boolean Whether to show or hide the combat bar.
--- @param instantClose boolean Whether to instantly close the combat bar without animation.
--- @return number The duration of the animation in milliseconds, or the time to wait before hiding the combat bar.
---
function ApplyCombatBarHidingAnimation(self, show, instantClose)
	if UICombatBarShowLast == show then return end
	UICombatBarShowLast = show
	if IsValidThread(UIHidingThread) then
		DeleteThread(UIHidingThread) 
		UIHidingThread = false
	end

	-- Outside exploration the bar is always shown
	if LastLoadedOrLoadingIMode ~= "IModeExploration" then
		show = true
	end
	
	if not GetAccountStorageOptionValue("HideActionBar") or (CurrentTutorialPopup and CurrentTutorialPopup.attachedToAB) then
		show = true
	end
	
	-- Dont animate if already where we want it.
	if UICombatBarShown == show then return end
	
	local function lRunFunc(func)
		func()
		return false
	end
	
	ToggleTargetIconsTransparency(self, show)

	local closeTime = instantClose and 0 or lHideCombatBarAfter
	local threadFunc = instantClose and lRunFunc or CreateRealTimeThread
	UIHidingThread = threadFunc(function()
		if not show then Sleep(closeTime) end
		UICombatBarShown = show
		ObjModified("UICombatBarShown")
		if not self or self.window_state == "destroying" then return end
		
		local b = self.box
		local mod = {
			id = "combat_bar_hiding",
			type = const.intRect,
			duration = ui_CombatBarAnimationDuration,
			originalRect = b,
			targetRect = sizebox(b:minx(), UIL.GetScreenSize():y(), b:sizex(), b:sizey()),
		}
		if show then
			mod.flags = const.intfInverse
		end
		self:AddInterpolation(mod)
	end)
	return show and ui_CombatBarAnimationDuration or closeTime
end

---
--- Sets the transparency of the target icons on the given combat bar.
---
--- @param bar table The combat bar to modify the target icons on.
--- @param show boolean Whether to show (true) or hide (false) the target icons.
---
function ToggleTargetIconsTransparency(bar, show)
	if not bar then return end
	local idTargets = bar.parent:ResolveId("idTargets")
	if not idTargets then return end
	if show then
		idTargets:SetTransparency(0)
	else
		idTargets:SetTransparency(50)
	end
end

GameVar("gv_LastPartialSquadSelection", {})

---
--- Toggles the selection of all units in the current squad.
---
--- If the current mode is deployment, selects all units in the current deployment squad.
--- If the current mode is exploration, toggles the selection between the whole squad and the last partially selected squad.
---
--- @param selectAllOnly boolean If true, always selects the whole squad, even if it was partially selected before.
---
function ToggleAllUnitsSelectionInSquad(selectAllOnly)
	local igi = GetInGameInterfaceModeDlg()
	if IsKindOf(igi, "IModeDeployment") and gv_DeploymentStarted then
		local units = GetCurrentDeploymentSquadUnits()
		SelectionSet(units)
		return
	end
	
	if not IsKindOf(igi, "IModeExploration") then return end
	
	-- selection handling; changing from last selected to whole squad;
	local team = GetFilteredCurrentTeam()
	if WholeTeamSelected() and not selectAllOnly then
		if IsValid(gv_LastPartialSquadSelection[1]) and gv_LastPartialSquadSelection[1].Squad == team.units[1].Squad then
			igi:SelectUnits(gv_LastPartialSquadSelection)
		else
			igi:SelectUnits({team.units[1]})
		end
	else
		if PartialSquadSelected() then
			gv_LastPartialSquadSelection = table.copy(Selection)
		else
			gv_LastPartialSquadSelection = {}
		end
		igi:SelectUnits(team.units)
	end
end

---
--- Checks if the current squad selection is partial (i.e. not all units in the squad are selected).
---
--- @return boolean true if the current squad selection is partial, false otherwise
---
function PartialSquadSelected()
	if g_Combat then return true end
	local team = GetFilteredCurrentTeam()
	if #Selection >= #team.units then return false end
	for i, s in ipairs(Selection) do
		if not table.find(team.units, s) then
			return false
		end
	end
	return true
end

---
--- Returns a dynamic text string for the gamepad select toggle button, based on the current selection state.
---
--- If the whole team is currently selected, the string "Select Single Merc" is returned.
--- Otherwise, the string "Select All Mercs" is returned.
---
--- @return string The dynamic text string for the gamepad select toggle button.
---
function TFormat.GamepadSelectToggleDynamicText()
	if WholeTeamSelected() then
		return T(760771207071, "Select Single Merc")
	end
	return T(864206208463, "Select All Mercs")
end

function OnMsg.UnitPropertiesSynced()
	ObjModified("hud_squads") -- Update level up indicator
end

function OnMsg.CreateRolloverWindow()
	ObjModified("RolloverWin")
end

function OnMsg.DestroyRolloverWindow()
	ObjModified("RolloverWin")
end

local lStancesInOrder = {
	"Prone",
	"Crouch",
	"Standing"
}

l_StanceBufferingThreads = false

---
--- Changes the stance of the given unit to the next stance in the order.
---
--- If the unit has a combat action in progress, the stance change will be buffered until the action is complete.
---
--- @param unit Unit The unit to change the stance for.
--- @param nextStance string The name of the next stance to change to.
--- @param wait boolean If true, the function will wait for the unit's current combat action to complete before changing the stance.
---
function lChangeStanceForUnit(unit, nextStance, wait)
	if wait then
		WaitCombatActionsPostAction(unit)
	end
	
	local nextStanceAction = nextStance and CombatActions["Stance" .. nextStance]
	if nextStanceAction and nextStanceAction:GetUIState({unit}) == "enabled" then
		nextStanceAction:UIBegin({unit})
	end
end

---
--- Changes the stance of all selected units to the next stance in the order.
---
--- If a unit has a combat action in progress, the stance change will be buffered until the action is complete.
---
--- @param direction string The direction to change the stance, either "up" or "down".
---
function ChangeStanceExploration(direction)
	if not l_StanceBufferingThreads then l_StanceBufferingThreads = {} end

	for i, unit in ipairs(Selection) do
		local curStance = unit.stance
		
		local bufferData = l_StanceBufferingThreads[unit]
		local bufferedThread = false;
		if bufferData and IsValidThread(bufferData.thread) then
			curStance = bufferData.stance
			bufferedThread = true
		end
		
		local stanceIdx = table.find(lStancesInOrder, curStance)
		local directionMod = direction == "up" and 1 or -1
		local nextStance = lStancesInOrder[stanceIdx + directionMod]
		local nextStanceAction = nextStance and CombatActions["Stance" .. nextStance]
		if not nextStanceAction then goto continue end
		
		-- Check if we need to buffer the stance change. This is done to ensure that multiple selected units
		-- maintain the same stance when switched together regardless of the animation speed of each unit.
		if HasCombatActionInProgress(unit) and CombatActions_RunningState[unit] ~= "PostAction" then
			if bufferedThread then DeleteThread(bufferData.thread) end
			local thread = CreateMapRealTimeThread(lChangeStanceForUnit, unit, nextStance, "wait")
			l_StanceBufferingThreads[unit] = { thread = thread, stance = nextStance }
		else
			lChangeStanceForUnit(unit, nextStance)
		end
		
		::continue::
	end
end

---
--- Gets the MercPortraitWindow for the given unit.
---
--- @param unit Unit The unit to get the MercPortraitWindow for.
--- @return UIWindow|nil The MercPortraitWindow for the given unit, or nil if the unit is not a merc or the window cannot be found.
---
function GetMercPortraitWindow(unit)
	if not IsKindOf(unit, "Unit") or not unit:IsMerc() then return end
	
	local party = GetInGameInterfaceModeDlg():ResolveId("idParty")
	local container = party and party.idPartyContainer
	party = container and container.idParty
	party = party and party[2]
	for idx, win in ipairs(party) do
		if win.context and win.context.session_id == unit.session_id then
			return win
		end
	end
end