DefineClass.IModeExploration = {
	__parents = { "IModeCommonUnitControl" },

	follow_thread = false,

	-- move
	move_units = false,
	move_positions = false,
	move_end_time = false,
	move_thread = false,

	--fx
	fx_unit_rollover = false,

	--multi selection
	drag_start_pos = false,
	drag_selection_obj = false,

	IdleBanterThread = false,

	mouse_pos = false,
	mouse_lbutton_handle = false,
	mouse_rbutton_handle = false,
	cursor_voxel = false,

	last_move_units = false,
	last_move_pos = false,
	suppress_camera_init = false,
	can_start_combat = false
}

---
--- Initializes the IModeExploration class with the provided parent and context.
---
--- @param parent table The parent object.
--- @param context table The context table containing initial values for the class members.
---
function IModeExploration:Init(parent, context)
	if context then
		for k,v in pairs(context) do
			if self:HasMember(k) and not self[k] then
				self[k] = v
			end
		end
	end
end

MapVar("g_VoiceResponseTemporaryDisablingThread", false)
MapVar("InactiveBanterPlayed", false)

---
--- Opens the IModeExploration mode, disabling voice responses temporarily to avoid playing selection VRs after combat ends.
--- It also initializes the move_units and move_positions tables, and starts an idle banter thread that plays random idle voice responses for the player's units.
---
--- @param self IModeExploration The IModeExploration instance.
---
function IModeExploration:Open()
	IModeCommonUnitControl.Open(self)
	
	--Disable VRs temporary to avoid playing Selection VR after the combat ends
	if not IsValidThread(g_VoiceResponseTemporaryDisablingThread) then
		local vrEnabled = g_VoiceResponsesEnabled
		g_VoiceResponsesEnabled = false
		g_VoiceResponseTemporaryDisablingThread = CreateRealTimeThread(function()
			WaitMsg("SelectionChange", 1)
		   g_VoiceResponsesEnabled = vrEnabled
		end)
	end

	self.move_units = {}
	self.move_positions = {}

	self.IdleBanterThread = CreateGameTimeThread(function()
		while not InactiveBanterPlayed do
			local gotMessage = WaitMsg("UserInputMade", 1000 * 60 * 2)
			if gotMessage then goto continue end -- If got message that means that the wait didn't timeout, so input was had.
			
			-- Setpiece or something else going on.
			if WaitPlayerControl() then goto continue end
			
			-- Inventory open
			local inventoryOrOtherDialog = GetDialog("FullscreenGameDialogs")
			if inventoryOrOtherDialog and inventoryOrOtherDialog.window_state == "open" then
				WaitMsg(inventoryOrOtherDialog)
				goto continue
			end
			
			-- PDA open
			local pdaDialog = GetDialog("PDADialogSatellite") or GetDialog("PDADialog")
			if pdaDialog and pdaDialog.window_state == "open" then
				WaitMsg(pdaDialog)
				goto continue
			end
			
			-- Unit isn't idle
			if not Selection[1] or not Selection[1]:IsIdleCommand() then
				goto continue
			end
			
			local povTeam = GetPoVTeam()
			local unitsCount = #povTeam.units
			local unitIdx = povTeam and (AsyncRand(unitsCount) + 1)
			local randomUnit
			if unitIdx then
				randomUnit = povTeam.units[unitIdx]
				local c = (unitIdx) % unitsCount + 1
				while c ~= unitIdx and not randomUnit:IsLocalPlayerControlled() or randomUnit:IsDead() or randomUnit:IsDowned() do
					randomUnit = povTeam.units[c]
					c = c % unitsCount + 1
				end
				randomUnit = randomUnit:IsLocalPlayerControlled() and randomUnit or false
			end
			local played = randomUnit and PlayVoiceResponseInternal(randomUnit, "Idle", true)
			if played then
				InactiveBanterPlayed = true
				break
			end

			::continue::
		end
	end)
end

---
--- Closes the IModeExploration instance, performing cleanup tasks.
---
--- Deletes various threads associated with the mode, including the move thread, idle banter thread, and follow thread.
--- If there is a unit rollover effect, it restores the visibility of the unit's selection contour and removes the rollover effect.
--- Finally, it calls the Close method of the IModeCommonUnitControl base class.
---
function IModeExploration:Close()
	DeleteThread(self.move_thread)
	DeleteThread(self.IdleBanterThread)
	DeleteThread(self.follow_thread)
	if self.fx_unit_rollover then
		local unit = self.fx_unit_rollover:GetParent()
		if g_SelectionContours[unit] then
			g_SelectionContours[unit].contour:SetVisible(true)
		end
		SpawnUnitContour(false, false, self.fx_unit_rollover)

	end
	IModeCommonUnitControl.Close(self)
end

---
--- Handles mouse button down events for the IModeExploration interface mode.
---
--- This function is called when the user presses a mouse button while the IModeExploration mode is active. It performs the following actions:
---
--- - Calls the `OnMouseButtonDown` method of the `InterfaceModeDialog` base class to handle the event.
--- - If the event is a gamepad click, sets the `mouse_lbutton_handle` flag and the `move_button_down_time`, and starts a FX animation on the world cursor.
--- - If the event is a left mouse button press, checks if the Control key is pressed. If so, it calls the `PlayerPing` function and returns. Otherwise, it sets the `mouse_lbutton_handle` flag, captures the mouse, and creates a thread to lock the camera while the mouse button is held down.
--- - If the event is a right mouse button press, it sets the `mouse_rbutton_handle` flag.
---
--- @param pt table The screen position of the mouse cursor.
--- @param button string The mouse button that was pressed ("L" for left, "R" for right).
--- @param time number The time at which the mouse button was pressed.
--- @return string The result of the event handling, which can be "continue", "break", or nil.
function IModeExploration:OnMouseButtonDown(pt, button, time)
	if type(pt) == "number" then
		assert(false)
	end

	local result = InterfaceModeDialog.OnMouseButtonDown(self, button, pt, time)
	if result and result ~= "continue" then
		return result
	end

	-- Gamepad click
	if not button and GetUIStyleGamepad() then
		self.mouse_lbutton_handle = true
		self.move_button_down_time = RealTime()
		if self.world_cursor then
			PlayFX("GamepadCursorMoveHold", "start", self.world_cursor)
		end
		return "break"
	end

	if button == "L" then
		if terminal.IsKeyPressed(const.vkControl) then
			PlayerPing()
			return "continue"
		end
	
		self.mouse_lbutton_handle = true
		if not self.desktop.last_mouse_target or self:IsWithin(self.desktop.last_mouse_target) then
			self.drag_start_pos = pt
			self.desktop:SetMouseCapture(self)

			self:DeleteThread("lock-camera")
			self:CreateThread("lock-camera", function()
				local cameraPos, eyePos = GetCamera()
				while true do
					Sleep(300)
					local cameraPosNew, eyePosNew = GetCamera()
					if cameraPos == cameraPosNew and eyePos == eyePosNew then
						break
					end
					cameraPos, eyePos = cameraPosNew, eyePosNew
				end

				LockCamera("Multiselection")
			end)
		end
		return "break"
	elseif button == "R" then
		self.mouse_rbutton_handle = true
	end

	return "continue"
end

---
--- Handles the mouse button up event for the IModeExploration interface mode.
---
--- This function is responsible for processing various mouse button up events, such as left-click, right-click, and gamepad click. It handles actions like unit selection, unit movement, and interaction with interactable objects.
---
--- @param pt Vector3 The position of the mouse cursor when the button was released.
--- @param button string The mouse button that was released ("L" for left, "R" for right).
--- @param time number The time when the button was released.
--- @return string The result of the mouse button up event handling ("continue" or "break").
---
function IModeExploration:OnMouseButtonUp(pt, button, time)
	local result = InterfaceModeDialog.OnMouseButtonUp(self, button, pt, time)
	if result and result ~= "continue" then
		return result
	end
	
	if self.starting_combat then
		return "break"
	end
	
	local drag_start_pos = self.drag_start_pos
	-- do not handle lbutton up events if we didn't handle the lbutton down before that
	local left = button == "L" and self.mouse_lbutton_handle
	local right = button == "R" and self.mouse_rbutton_handle
	if left then
		self.mouse_lbutton_handle = false
	elseif right then
		self.mouse_rbutton_handle = false
	end
	
	local gamepadClick = false
	if not button and GetUIStyleGamepad() and self.mouse_lbutton_handle then
		gamepadClick = true
		self.mouse_lbutton_handle = false
	end

	if left or right or gamepadClick then	
		-- Since OnMousePos isn't called every frame we need to make sure the click will land on the right spot.
		IModeCommonUnitControl.UpdateTarget(self, GetCursorPos())
		
		-- Drag select
		if pt and drag_start_pos and left then
			local breakInput = false
			if drag_start_pos:Dist2D(pt) > 10 then
				local start_pos = drag_start_pos
				local max_step = 12 * guim --PATH_EXEC_STEP
				local all_objects = GatherObjectsInScreenRect(start_pos, pt, "Unit", max_step)
				self:HandleUnitSelection(all_objects)
				breakInput = true
			end
			self:CancelMultiselection()
			if breakInput then return "break" end
		end
		
		-- if clicking on a visible (unaware) enemy, start combat directly
		local target_unit = IsKindOf(self.potential_target, "Unit") and self.potential_target
		
		if (gamepadClick or left) and target_unit and #Selection > 0 then
			local team = g_CurrentTeam and g_Teams[g_CurrentTeam]
			if team and target_unit.team:IsEnemySide(team) and not target_unit:IsDead() then
				local action = Selection[1]:GetDefaultAttackAction(nil, nil, nil, nil, nil, nil, "ui")
				-- special case
				if ShouldUseMarkTarget(Selection[1], target_unit) then
					action = CombatActions.MarkTarget
				end
				
				if action.AimType == "melee" then
					for _, attacker in ipairs(Selection) do
						if attacker.marked_target_attack_args and attacker.marked_target_attack_args.target == target_unit then
							return "break"
						end
					end
					
					local targets = action:GetTargets({Selection[1]})					
					if not table.find(targets, target_unit) then
						--CreateFloatingText(target_unit:GetPos(), T(373021717779, "Approach to attack"), "FloatingTextMiss")
						return "break"
					end
				end
				action:UIBegin(Selection, { target = target_unit })
				return "break"
			end
		end
		
		-- Select
		if (gamepadClick or left) and self.potential_target and self:HandleUnitSelection({self.potential_target}) then
			return "break"
		end
		
		local moveWithLeft = GetAccountStorageOptionValue("LeftClickMoveExploration")

		-- Interact
		local interactButton = false
		if moveWithLeft then interactButton = right else interactButton = left end
		if next(Selection) and (interactButton or gamepadClick) then
			local interactable, unit, follow
			
			if IsValid(self.potential_interactable) then
				interactable = self.potential_interactable
				unit, follow = UIFindInteractWith(interactable, false)
			end

			if not unit then
				interactable, unit = self:GetInteractableUnderCursor()
			end

			if unit then
				UIInteractWith(unit, interactable)
				
				-- Handle MultiSelectBehavior == "all"
				if follow then
					local followers = Selection
					for _, u in ipairs(followers) do
						if u ~= unit then
							local pos = u:GetInteractionPosWith(interactable)
							if pos then
								CombatActions.Move:Execute({ u }, { goto_pos = pos })
							end
						end
					end
				end
				
				return "break"
			end
		end

		-- Move
		if left and not moveWithLeft then return "break" end
		if right and moveWithLeft then return "break" end
		
		-- In gamepad mode holding the button will direct all units in the squad
		local passPos = GetPassSlab(GetCursorPos("walkable"))
		if gamepadClick then
			local moveUnits = Selection
			local timeHeld = self.move_button_down_time and RealTime() - self.move_button_down_time or 0
			if timeHeld > const.GamePadButtonHoldTime then
				local team = GetFilteredCurrentTeam()
				moveUnits = team and team.units or moveUnits
			end
			self:InitiateUnitMovement(passPos, moveUnits, GetCursorPos())
			
			if self.world_cursor then
				PlayFX("GamepadCursorMoveHold", "end", self.world_cursor)
			end
		else
			local shift = terminal.IsKeyPressed(const.vkShift)
			local ctrl = terminal.IsKeyPressed(const.vkControl)
			
			local walkInsteadOfRun = shift and ctrl
			local moveUnits = Selection
			if shift and not walkInsteadOfRun then
				local team = GetFilteredCurrentTeam()
				moveUnits = team and team.units or moveUnits
			end
		
			local move_type = walkInsteadOfRun and "Walk"
			self:InitiateUnitMovement(passPos, moveUnits, nil, move_type)
		end

		return "break"
	end
	
	return "continue"
end

---
--- Initiates unit movement to the specified position.
---
--- @param pos table|nil The position to move the units to.
--- @param unitPool table|nil The pool of units to move. Defaults to the current selection.
--- @param fx_pos table|nil The position to play the movement effect at. Defaults to the move position.
--- @param move_type string|nil The type of movement to use. Can be "Walk" or nil for default.
---
function IModeExploration:InitiateUnitMovement(pos, unitPool, fx_pos, move_type)
	if pos then
		unitPool = unitPool or Selection
		local units = {}
		for i, unit in ipairs(unitPool) do
			if unit:CanBeControlled() then
				table.insert(units, unit)
			end
		end
		if #units == 0 then
			return
		end

		local voice_response_unit = table.rand(units)
		local is_hidden	 = voice_response_unit:HasStatusEffect("Hidden")
		local line = "Order"
		if voice_response_unit:HasStatusEffect("Hidden") then
			line = "CombatMovementStealth"
		elseif #units > 1 then
			line = "GroupOrder"
		end
		if line then PlayVoiceResponse(voice_response_unit, line) end
		self:MoveUnitsTo(units, pos, "ui_triggered", fx_pos or pos, move_type)
		PlayFX("MercMoveCommand_OutOfCombat", "start")
	else
		PlayFX("Unreachable", "start")
	end
end


---
--- Handles mouse position updates for the exploration mode.
---
--- @param pt table The current mouse position.
--- @param button string The current mouse button state.
---
function IModeExploration:OnMousePos(pt, button)
	self.mouse_pos = pt
	local cursorPos = GetCursorPos()
	self:UpdateTarget(cursorPos)

	if cursorPos then
		local vx, vy, vz = WorldToVoxel(cursorPos)
		local voxel = point_pack(vx, vy, vz)
		if voxel ~= self.cursor_voxel then
			self.cursor_voxel = voxel
		end
		if self.drag_start_pos and pt then
			self:MultiselectionUpdateRect(pt, voxel ~= self.cursor_voxel)
		end
	end

	local combatActionsChoiceActive = self.combatActionsPopup and self.combatActionsPopup.window_state ~= "destroying"
	local tutorialPopupContext = CurrentTutorialPopup and CurrentTutorialPopup:IsVisible() and CurrentTutorialPopup:ResolveId("idText"):GetContext()
	local isRelatedPopup = tutorialPopupContext and (tutorialPopupContext.id == "Bandage" or tutorialPopupContext.id == "SneakMode")
	if not GetUIStyleGamepad() and not terminal.desktop.inactive and not combatActionsChoiceActive then
		local bottom = self.idBottomBar
		ApplyCombatBarHidingAnimation(self.idBottomBar, isRelatedPopup or pt:y() > self.idBottom.box:miny() - self.idBottom.box:sizey())
	end

	IModeCommonUnitControl.OnMousePos(self, pt)
end


---
--- Updates the target unit for the exploration mode.
---
--- @param ... any Arguments passed to the base class implementation.
---
function IModeExploration:UpdateTarget(...)
	IModeCommonUnitControl.UpdateTarget(self, ...)
	local potential_target = self:CanSelectObj(self.potential_target) and self.potential_target
	if IsValid(self.fx_unit_rollover) and self.fx_unit_rollover:GetParent() then
		local unit = self.fx_unit_rollover:GetParent()
		local selection_contour = g_SelectionContours[unit]
		if selection_contour then
			if not IsKindOf(unit.traverse_tunnel, "SlabTunnelLadder") then
				selection_contour.contour:SetVisible(true)
			end
		end
	end

	local unit = potential_target
	if IsKindOf(unit, "Unit") and IsKindOf(unit.traverse_tunnel, "SlabTunnelLadder") then
		unit = nil
	end
	self.fx_unit_rollover = SpawnUnitContour(unit, "ExplorationSelect", self.fx_unit_rollover)
	
	if self.fx_unit_rollover then
		local unit = potential_target
		local selection_contour = g_SelectionContours[unit]
		if selection_contour then
			selection_contour.contour:SetVisible(false)
		end
	end
end

--- Selection

---
--- Updates the multiselection rectangle on the screen based on the current mouse position.
---
--- @param pt Vector2i The current mouse position.
--- @param update_selection boolean Whether to update the selection based on the new rectangle.
---
function IModeExploration:MultiselectionUpdateRect(pt, update_selection)
	local UIScale = GetUIScale()
	local start_x, start_y = MulDivRound(self.drag_start_pos, 1000, UIScale):xy()

	local pt_x, pt_y = pt:xy()
	pt_x = MulDivRound(pt_x, 1000, UIScale)
	pt_y = MulDivRound(pt_y, 1000, UIScale)

	local aspectRatioConstraint = GetAspectRatioConstraintAmount()
	start_x = start_x - aspectRatioConstraint
	pt_x = pt_x - aspectRatioConstraint

	local left =   Min(start_x, pt_x)
	local right =  Max(start_x, pt_x)
	local top =    Min(start_y, pt_y)
	local bottom = Max(start_y, pt_y)
	
	local rect_element = self.idSelection
	rect_element:SetVisible(true)
	rect_element:SetMargins(box(left, top, 0, 0))
	rect_element:SetMinWidth(right - left)
	rect_element:SetMinHeight(bottom - top)
	
	if update_selection then
		local start_pos = self.drag_start_pos
		local max_step = 12 * guim --PATH_EXEC_STEP
		local temp_objects = GatherObjectsInScreenRect(start_pos, pt, "Unit", max_step)
		if next(temp_objects) and self:CanSelectObj(temp_objects[1]) then
			local first_obj = temp_objects[1]
			self.drag_selection_obj = first_obj
		else
			self.drag_selection_obj = false
		end	
	end
end

---
--- Cancels the current multiselection operation.
---
--- This function is called when the mode loses focus, such as when the user switches to a different mode.
--- It hides the multiselection rectangle, clears the drag start position and selected object, and unlocks the camera.
---
function IModeExploration:OnKillFocus()
	self:CancelMultiselection()
end

---
--- Cancels the current multiselection operation.
---
--- This function is called when the mode loses focus, such as when the user switches to a different mode.
--- It hides the multiselection rectangle, clears the drag start position and selected object, and unlocks the camera.
---
function IModeExploration:OnDelete()
	self:CancelMultiselection()
end

---
--- Cancels the current multiselection operation.
---
--- This function is called when the mode loses focus, such as when the user switches to a different mode.
--- It hides the multiselection rectangle, clears the drag start position and selected object, and unlocks the camera.
---
function IModeExploration:CancelMultiselection()
	if self.desktop.mouse_capture == self then
		self.desktop:SetMouseCapture(false)
	end

	if self.drag_start_pos then
		self.idSelection:SetVisible(false)
		self.drag_start_pos = false
		self.drag_selection_obj = false
		
		self:DeleteThread("lock-camera")
		UnlockCamera("Multiselection")
	end
end

---
--- Determines if the given object can be selected.
---
--- @param obj any The object to check for selection.
--- @return boolean True if the object can be selected, false otherwise.
---
function IModeExploration:CanSelectObj(obj)
	return IsKindOf(obj, "Unit") and obj:CanBeControlled()
end

---
--- Selects the given units, filtering out any units that cannot be selected.
---
--- @param units table An array of units to select.
--- @return boolean Whether the selection was changed.
---
function IModeExploration:SelectUnits(units)
	--filter only selectable units
	local filtered = { }
	local n = 0
	for i,unit in ipairs(units) do
		if self:CanSelectObj(unit) then
			n = n + 1
			filtered[n] = unit
		end
	end
	
	if n == 0 then return end

	local changed = false
	for i = #Selection, 1, -1 do
		local u = Selection[i]
		if not table.find(filtered, u) then
			SelectionRemove(u)
			changed = true
		end
	end
	for _, u in ipairs(filtered) do
		if not table.find(Selection, u) then
			SelectionAdd(u)
			changed = true
		end
	end
	
	return changed
end

---
--- Handles the selection of units, allowing the user to add or remove units from the selection using the Shift key.
---
--- @param units table An array of units to select.
--- @return boolean Whether the selection was changed.
---
function IModeExploration:HandleUnitSelection(units)
	local shift = GetCameraVKCodeFromShortcut("Shift")
	if terminal.IsKeyPressed(shift) and #units ~= 0 then
		for _, unit in ipairs(Selection) do
			if table.find(units, unit) then
				table.remove_entry(units, unit)
			else
				table.insert(units, unit)
			end
		end
	end
	return self:SelectUnits(units)
end

--- Unit commands

---
--- Updates the visual effects for the interactable area markers.
---
--- This function is called to update the visual effects for the interactable area markers, such as highlighting the area when the cursor is inside it.
---
--- @function UpdateMarkerAreaEffects
--- @return nil
function UpdateMarkerAreaEffects()
	if not gv_CurrentSectorId then return end
	UpdateInteractableAreaMarkersEffects()
end

---
--- Updates the visibility of the border area marker based on the cursor position.
---
--- This function is responsible for updating the visibility of the border area marker on the screen. It checks if the cursor position is within a certain range of the marker's area, and updates the marker's visibility accordingly.
---
--- @param cursor_pos table The current position of the cursor.
--- @return nil
---
function UpdateBorderAreaMarkerVisibility(cursor_pos)
	local m = GetBorderAreaMarker()
	if not m then
		return
	end
	local voxel_cursor_x, voxel_cursor_y = WorldToVoxel(cursor_pos)
	local mw_x, mw_y = WorldToVoxel(m)
	local left = mw_x - m.AreaWidth/2
	local right = left + m.AreaWidth
	local up = mw_y - m.AreaHeight/2
	local down = up + m.AreaHeight
	local voxel_range = 12
	if not m.contour_polyline then
		if voxel_cursor_x - voxel_range <= left or
			voxel_cursor_x + voxel_range >= right or
			voxel_cursor_y - voxel_range <= up or
			voxel_cursor_y + voxel_range >= down
		then
			m:UpdateHideReason("area_visiblity", false)
		end
	else
		local is_inside =
			voxel_cursor_x >= left and
			voxel_cursor_x < right and
			voxel_cursor_y >= up and
			voxel_cursor_y < down
		local material = m.contour_polyline[1].CRMaterial
		material:SetIsInside(is_inside, "notimereset")
		material.dirty = true
		material.ZOffset = 0 --cameraTac.GetFloor() * hr.CameraTacFloorHeight -- markerPos:z()
		for key, value in ipairs(m.contour_polyline) do
			value:SetCRMaterial(material)
		end
		if voxel_cursor_x - voxel_range > left and
			voxel_cursor_x + voxel_range < right and
			voxel_cursor_y - voxel_range > up and
			voxel_cursor_y + voxel_range < down
		then
			m:UpdateHideReason("area_visiblity", true)
		end
	end
end

---
--- Updates the visibility and effects of interactable area markers on the screen.
---
--- This function is responsible for updating the visibility and effects of interactable area markers based on the cursor position. It checks if the cursor is inside any of the interactable area markers, and updates the marker's state accordingly, including showing a floating text rollover if the marker is hovered over.
---
--- @param none
--- @return nil
---
function UpdateInteractableAreaMarkersEffects()
	for _, marker in ipairs(g_InteractableAreaMarkers) do
		if IsValid(marker.area_ground_mesh) then
			if marker:IsInsideArea(GetCursorPos()) then
				marker.area_ground_mesh.hover = true
				marker.area_ground_mesh:UpdateState()
				if not marker.area_effect then
					marker.area_effect = true
				end
				local text = GetInteractableAreaMarkerRollover(marker)
				if marker.fl_text then
					if not text or _InternalTranslate(text) ~= _InternalTranslate(marker.fl_text:GetText()) then
						marker:RemoveFloatTxt()
						if text then
							marker.fl_text = ShowFloatingTextNoExpire(marker, text, "BadgeNameActive")
						end
					end
				elseif text then
					marker.fl_text = ShowFloatingTextNoExpire(marker, text, "BadgeNameActive")
				end
				return
			end
			if marker.area_effect then
				marker.area_effect = false
				marker:RemoveFloatTxt()
			end
			marker.area_ground_mesh.hover = false
			marker.area_ground_mesh:UpdateState()
		end
	end
end

---
--- Starts a follow thread that moves a group of units to a specified position.
---
--- The follow thread continuously moves the units to the last known position, while
--- also tracking any units that have become invalid or are too far away from the
--- movement position. The thread will continue to run until the units list is empty.
---
--- @param units table The list of units to move.
--- @param pos point The position to move the units to.
--- @return nil
---
function IModeExploration:StartFollow(units, pos)
	self.last_move_units = units
	self.last_move_pos = pos
	if IsValidThread(self.follow_thread) then
		return
	end
	self.follow_thread = CreateGameTimeThread(function(self)
		local vr_move_pos = false
		while true do
			Sleep(const.ExplorationFollowDelay)
			local units = self.last_move_units
			if not units or #units == 0 then return end
			
			-- Cleanup invalid units
			for i = #units, 1, -1 do
				local u = units[i]
				if not IsValid(u) or not u:CanBeControlled() then
					table.remove(units, i)
				end
			end

			-- Units who will follow are ones in the same squad(s) as the moving unit(s)
			-- who are further than max_dist2D of the ordered movement position
			-- and can be controlled by the local player.
			local followers
			local max_dist2D = 4 * const.SlabSizeX
			local pos = self.last_move_pos
			local z = pos:IsValidZ() and pos:z() or terrain.GetHeight(pos)
			for _, unit in ipairs(units) do
				local unitsInSquad = GetMapUnitsInSquad(unit.Squad)
				for _, u in ipairs(unitsInSquad) do
					if not table.find(followers, u) and not table.find(units, u) and u:CanBeControlled() then
						if	not IsCloser2D(u, pos, max_dist2D)
							or abs(select(3, u:GetVisualPosXYZ()) - z) > const.SlabSizeZ
						then
							followers = followers or {}
							followers[#followers + 1] = u
						end
					end
				end
			end
			if not followers then return end

			-- Play vr only when a new movement order is made.
			if vr_move_pos ~= self.last_move_pos then
				local vr_units = {}
				for i, f in ipairs(followers) do
					vr_units[#vr_units + 1] = f
				end
				for i, u in ipairs(units) do
					vr_units[#vr_units + 1] = u
				end

				local voice_response_unit = table.rand(vr_units)
				PlayVoiceResponse(voice_response_unit, "GroupOrder")
				vr_move_pos = self.last_move_pos
			end

			self:MoveUnitsTo(followers, pos)
		end
	end, self)
end


---
--- Stops the follow and move threads for this IModeExploration instance.
--- Deletes the follow_thread and move_thread, and sets them to false.
---
function IModeExploration:StopFollow()
	DeleteThread(self.follow_thread)
	DeleteThread(self.move_thread)
	self.follow_thread = false
	self.move_thread = false
end

local function ShowQueuedMovementTargets()
	if not IsActivePaused() then return end
	for _, unit in ipairs(Selection) do
		if unit.queued_action_pos then
			local fx = unit:HasStatusEffect("Hidden") and "MoveCommandHidden" or "MoveCommand"
			PlayFX(fx, "start", "Unit", false, unit.queued_action_pos)
		end
	end
end

MapRealTimeRepeat("QueuedPosVisuals", 1500, ShowQueuedMovementTargets)

---
--- Moves a group of units to the specified position.
---
--- @param units table<Unit> The units to move.
--- @param pos point The destination position.
--- @param ui_triggered boolean Whether the move was triggered by the user interface.
--- @param cursor_pos point The cursor position, if available.
--- @param move_type string The type of move (e.g. "walk", "run").
---
function IModeExploration:MoveUnitsTo(units, pos, ui_triggered, cursor_pos, move_type)
	if not IsValidThread(self.move_thread) then 
		self.move_units = {}
		self.move_positions = {}
	end
	
	local move_units = self.move_units
	local move_positions = self.move_positions

	local dest = GetUnitsDestinations(units, pos)

	if ui_triggered then
		--local fxpos
		--cursor_pos = cursor_pos or GetCursorPos()
		--local pass_cursor = GetPassSlab(cursor_pos)
		-- if pass_cursor then
		-- 	-- display fx where is clicked if passable, otherwise show goto pos
		-- 	fxpos = pass_cursor:IsValidZ() and cursor_pos:SetZ(pass_cursor:z()) or cursor_pos:SetInvalidZ()
		-- 	if not terrain.IsPassable(fxpos) then
		-- 		fxpos = pass_cursor
		-- 	end
		-- else
		-- 	fxpos = dest[1] and point(point_unpack(dest[1])) or pos
		-- end
		
		-- Place fx for all units that will move.
		for i = 1, #dest do
			local pos = dest[i] and (GetPassSlab(point_unpack(dest[i])) or point(point_unpack(dest[i]))) or pos
			if cursor_pos and i == 1 and #units == 1 then
				pos = cursor_pos
			end
			
			if IsActivePaused() and units[i] then
				units[i].queued_action_pos = pos
				local fx = units[i]:HasStatusEffect("Hidden") and "MoveCommandHidden" or "MoveCommand"
				PlayFX(fx, "start", "Unit", false, pos)
			else
				if GetUIStyleGamepad() then
					local worldCursor = self.world_cursor
					if worldCursor then
						PlayFX("GamepadCursorMoveCommand", "start", worldCursor, false, pos)
					end
				else
					PlaceShrinkingObj(
						self.movement_decal,
						self.movement_decal_shrink_time,
						pos,
						self.movement_decal_scale,
						self.movement_decal_color,
						units[i] and units[i]:HasStatusEffect("Hidden") and "MoveCommandHidden"
					)
				end
			end
		end
	end

	local prev_count = #move_units
	local packed_pos
	for i, unit in ipairs(units) do
		if not move_positions[unit] then
			table.insert(move_units, unit)
		end
		if dest[i] then
			move_positions[unit] = dest[i]
		else
			packed_pos = packed_pos or point_pack(pos)
			move_positions[unit] = packed_pos
		end
	end

	if prev_count == #move_units then
		return
	end

	-- shuffle the new units
	for j = #move_units, prev_count + 2, -1 do
		local k = prev_count + 1 + AsyncRand(j - prev_count)
		move_units[j], move_units[k] = move_units[k], move_units[j]
	end
	self.move_end_time = GameTime() + 200
	
	if IsValidThread(self.follow_thread) and self.follow_thread ~= CurrentThread() then
		DeleteThread(self.follow_thread)
		self.follow_thread = false
	end
	if IsValidThread(self.move_thread) then return end
	
	self.move_thread = CreateGameTimeThread(function(self)
		while #(self.move_units or empty_table) > 0 do
			local unit = self.move_units[1]
			table.remove(self.move_units, 1)
			local packed_pos = self.move_positions[unit]
			self.move_positions[unit] = nil
			local units = {unit}
			if IsValid(unit) and unit:IsValidPos() and unit:CanBeControlled() then
				local uistate = CombatActions.Move:GetUIState(units)
				if uistate == "enabled" then
					local pos = GetPassSlab(point_unpack(packed_pos)) or point(point_unpack(packed_pos))
					CombatActions.Move:Execute(units, {goto_pos = pos, move_type = move_type})
				end
			end
			if #self.move_units > 0 and not IsActivePaused() then
				local total = self.move_end_time - now()
				local average = total / #self.move_units
				local delay = average > 0 and (average/2 + AsyncRand(average/2)) or 0
				self.move_end_time = self.move_end_time - (average - delay)
				if delay > 0 then
					Sleep(delay)
				end
			end
		end
		self.move_thread = false
	end, self)
end

------------------

function OnMsg.UnitControlChanged(unit, control)
	ForceUpdateCommonUnitControlUI()

	local myControlNow = unit:IsLocalPlayerControlled()
	if myControlNow and not SelectedObj then
		SelectObj(unit)
		SnapCameraToObj(unit)
		return
	end

	if not myControlNow and SelectedObj == unit then
		if g_Combat then
			g_Combat:NextUnit(false, true)
		else
			local dlg = GetInGameInterfaceModeDlg()
			if IsKindOf(dlg, "IModeExploration") then
				dlg:NextUnit()
			end
		end
	end
	local lsdlg = GetLoadingScreenDialog() 
	if lsdlg then
		lsdlg:SetFocus()
	end
	
end

-- Follow logic

function OnMsg.NetSentInterrupt()
	local dlg = GetDialog("IModeExploration")
	if dlg then
		dlg:StopFollow()
	end
end

function OnMsg.SetpieceStarted()
	local dlg = GetInGameInterfaceModeDlg()
	if IsKindOf(dlg, "IModeCommonUnitControl") then
		dlg:UpdateTarget()
	end

	if interactablesOn then HighlightAllInteractables(false) end

	for i, u in ipairs(Selection) do
		HandleMovementTileContour({u})
	end
	
	for _, marker in ipairs(g_InteractableAreaMarkers) do
		if marker.area_ground_mesh then
			marker.area_ground_mesh:SetVisible(false)
		end
	end
end

function OnMsg.SetpieceEnded()
	for i, u in ipairs(Selection) do
		SelectionAddedApplyFX(u)
	end
	local dlg = GetInGameInterfaceModeDlg()
	if IsKindOf(dlg, "IModeCommonUnitControl") then
		dlg:UpdateTarget()
	end
	for _, marker in ipairs(g_InteractableAreaMarkers) do
		if marker.area_ground_mesh then
			marker.area_ground_mesh:SetVisible(true)
		end
	end
end

GameVar("gv_TacFloor", false)
GameVar("gv_ActivePause", false)
GameVar("gv_UnitsBlockingPause", {})

function OnMsg.GatherSessionData()
	gv_TacFloor = cameraTac:GetFloor()
end
function OnMsg.LoadSessionData()
	if gv_TacFloor then
		cameraTac.SetFloor(gv_TacFloor)
	end
	SetActivePause(gv_ActivePause)
	g_TestExploration = false --reset flag on load of save to prevent blocking of save option if the cheat has been used at least once before
end

function OnMsg.EnterSector(game_start, load_game)
	if not load_game then
		gv_UnitsBlockingPause = {}
		HideTacticalNotification("ongoingAttack")
		if PauseReasons.ActivePause then
			SetActivePause()
		end
	end
end

---
--- Marks a unit as blocking the active pause functionality.
--- This function should be called when a unit starts an exclusive action that should prevent the active pause from being triggered.
---
--- @param unit table The unit that is starting an exclusive action.
---
function ExplorationStartExclusiveAction(unit)
	gv_UnitsBlockingPause[unit.handle] = true
	ShowTacticalNotification("ongoingAttack", true)
end

---
--- Clears the exclusive action flag for the given unit, and hides the "ongoingAttack" tactical notification if there are no more units blocking the active pause.
---
--- @param unit table The unit that is finishing an exclusive action.
---
function ExplorationClearExclusiveAction(unit)
	gv_UnitsBlockingPause[unit.handle] = nil
	if next(gv_UnitsBlockingPause) == nil then
		HideTacticalNotification("ongoingAttack")
	end
end

-- active pause
---
--- Checks if the active pause functionality is currently available.
---
--- @return boolean true if the active pause is available, false otherwise
---
function IsActivePauseAvailable()
	return IsGameRuleActive("ActivePause") 
		and (not gv_UnitsBlockingPause or (next(gv_UnitsBlockingPause) == nil)) and 
		not g_Combat and 
		not g_StartingCombat and
		not GetDialog("ConversationDialog") and
		not GetDialog("PhotoMode") and
		(gv_ActivePause or not IsSetpiecePlaying())
end

---
--- Sets the active pause state for the game.
---
--- @param enable boolean|nil If true, enables the active pause. If false, disables the active pause. If nil, toggles the active pause state.
--- @param player_id number|nil The player ID of the player who initiated the active pause. Used for displaying a notification message.
---
--- This function checks if the active pause is available, and if so, sets the active pause state accordingly. It will pause or resume the game as needed, and display a notification message if the active pause is enabled.
---
--- If the active pause is enabled, the function will show a tactical notification with the name of the player who initiated the active pause. If the active pause is disabled, the function will hide the tactical notification and clear any queued action visuals for units.
---
function SetActivePause(enable, player_id)
	if enable and not IsActivePauseAvailable() then return end
	gv_ActivePause = not not enable
	local paused = not not (IsPaused() and PauseReasons.ActivePause)
	if paused ~= gv_ActivePause then
		if PauseReasons["ActivePause"] then
			Resume("ActivePause")
		else
			Pause("ActivePause")
		end
		Msg("ActivePauseChanged")
	end
	if gv_ActivePause then
		local text
		if player_id then
			local player_info = netGamePlayers[player_id]
			text = player_info and T{718571504784, "PAUSED BY <player>", player = Untranslated(player_info.name)} or nil
		end
		ShowTacticalNotification("activePause", "keep", text)
	else
		HideTacticalNotification("activePause", "instant")
		for _, unit in ipairs(g_Units) do
			if IsValid(unit.queued_action_visual) then
				DoneObject(unit.queued_action_visual)
				unit.queued_action_visual = false
			end
		end
	end
end

---
--- Returns whether the active pause is currently enabled.
---
--- @return boolean True if the active pause is enabled, false otherwise.
---
function IsActivePaused()
	return gv_ActivePause
end

OnMsg.CombatActionEnd = ExplorationClearExclusiveAction

OnMsg.SetpieceStarted = SetActivePause
OnMsg.CombatStarting = SetActivePause

---
--- Handles the network synchronization of the active pause state.
---
--- @param enable boolean Whether to enable or disable the active pause.
--- @param player_id number|nil The player ID of the player who initiated the active pause.
---
--- This function is called when the active pause state is changed on the network. It creates a new game thread to call the `SetActivePause` function with the provided `enable` and `player_id` parameters.
---
function NetSyncEvents.ActivePause(enable, player_id)
	CreateGameTimeThread(SetActivePause, enable, player_id)
end

---
--- Adds the "ActivePause" game rule to the savegame session data.
---
--- @param data table The savegame session data to be updated.
---
function SavegameSessionDataFixups.ActivePauseOption(data)
	data.game:AddGameRule("ActivePause")
end
