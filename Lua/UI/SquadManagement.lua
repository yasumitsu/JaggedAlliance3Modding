DefineClass.SquadManagementDragAndDrop = {
	__parents = { "XDragAndDropControl", },
	dragged_merc = false,
	dragged_merc_squad_wnd = false,
}

---
--- Checks if the player can open the Merc Management dialog.
---
--- @return string "enabled" if the Merc Management dialog can be opened, "disabled" otherwise
---
function CanOpenMercManagement()
	if GetDialog("ConversationDialog") then return "disabled" end
	if GetDialog("CoopMercsManagement") then return "disabled" end
	if GetDialog("ModifyWeaponDlg") then return "disabled" end
	return "enabled"
end

---
--- Gets the selected merc from the squad management UI.
---
--- @param pt table The mouse cursor position.
--- @return boolean, table|nil The selected merc window and the squad window, or nil if no merc is selected.
---
function SquadManagementDragAndDrop:GetSelectedMerc(pt)
	for i, w in ipairs(self.idSquadsList) do
		if w:MouseInWindow(pt) then
			for _, btn in ipairs(w) do
				if btn:IsKindOf("HUDMercClass") and (btn.context == "empty" or IsKindOf(btn.context, "UnitData")) and btn:MouseInWindow(pt) then
					return btn, w.idSquad
				end
			end
		end
	end
	
	local squadsList = self:ResolveId("idSquadsList")
	local newSquad = squadsList:ResolveId("idNewSquad")
	if newSquad:MouseInWindow(pt) then
		local list = squadsList:ResolveId("idNewSquadList")
		for i, b in ipairs(list) do
			if b.context == "empty" then
				return b, list
			end
		end
		return 
	end
end

---
--- Displays a warning message with the mouse cursor.
---
--- @param text string The warning message to display.
--- @param time number The duration in milliseconds to display the warning.
---
function MouseCursorWarning(text, time)
	local txt = XTemplateSpawn("XText", terminal.desktop)
	txt:SetTextStyle("DescriptionTextRedGlow")
	txt:SetTranslate(true)
	txt:SetHandleMouse(false)
	txt:SetText(text)
	txt:SetClip(false)
	txt:SetUseClipBox(false)
	txt:SetMargins(box(50, 0, 0, 0))
	txt:AddDynamicPosModifier({id= "cursor_hint", target = "mouse"})
	txt:Open()
	txt:CreateThread("life", function()
		Sleep(time)
		txt:Close()
	end)
end

---
--- Starts a drag and drop operation for a merc in the squad management UI.
---
--- @param pt table The mouse cursor position.
--- @param button number The mouse button that was pressed.
--- @return table|nil A copy of the dragged merc window, or nil if no merc was selected.
---
function SquadManagementDragAndDrop:OnDragStart(pt, button)
	local wnd_found, squad_wnd = self:GetSelectedMerc(pt)
	if wnd_found and not wnd_found.enabled and wnd_found.context ~= "empty" then
		MouseCursorWarning(T(695903843766, "Can't reassign mercs in conflict."), 1000)
	end
	
	if wnd_found and (wnd_found.context == "empty" or not wnd_found.context) then
		return
	end
	
	if wnd_found and wnd_found.enabled then
		self.dragged_merc = wnd_found.context
		self.dragged_merc_squad_wnd = squad_wnd
		local copy = XTemplateSpawn("HUDMerc", wnd_found.parent, wnd_found.context)
		copy.idBar:SetVisible(false)
		copy.idContent.RolloverTemplate = ""
		copy.dragging = true
		copy:SetClip(false)
		copy:SetUseClipBox(false)
		copy:SetBox(wnd_found.box:minx() + 10, wnd_found.box:miny() + 10, wnd_found.box:sizex(), wnd_found.box:sizey(), true)
		copy:Open()
		copy:OnSetRollover(false)
		return copy
	end
end

---
--- Starts a drag and drop operation for a merc in the squad management UI.
---
--- @param drag_win table The window being dragged.
--- @param pt table The mouse cursor position.
---
function SquadManagementDragAndDrop:StartDrag(drag_win, pt)
	XDragAndDropControl.StartDrag(self, drag_win, pt)
	drag_win:SetParent(GetDialog("PDADialogSatellite") or terminal.desktop)
end

---
--- Updates the drag and drop operation for the squad management UI.
---
--- @param drag_win table The window being dragged.
--- @param pt table The mouse cursor position.
---
function SquadManagementDragAndDrop:UpdateDrag(drag_win, pt)
	XDragAndDropControl.UpdateDrag(self, drag_win, pt)
	
	-- Drag and scroll
	local scrollArea = self:ResolveId("idSquadsList")
	local _, range = ScaleXY(scrollArea.scale, 0, 25)
	local scrollThresholdUp = scrollArea.box:miny() + range
	
	-- Scroll down relative to the last item seen as partial items is false
	local firstChildIn, lastChildIn = false, false
	for i, child in ipairs(scrollArea) do
		if child.outside_parent then -- check for scroll bar child? rn not needed as it is same height as scroll
			if firstChildIn then
				break
			end
		else
			firstChildIn = firstChildIn or child
			lastChildIn = child
		end
	end
	if not lastChildIn then lastChildIn = scrollArea end
	
	local scrollThresholdDown = lastChildIn.box:maxy() - range
	
	if pt:y() <= scrollThresholdUp or pt:y() >= scrollThresholdDown then
		if not self:GetThread("SquadManageScrollThread") then
			self:CreateThread("SquadManageScrollThread", function()
				while pt:y() <= scrollThresholdUp do
					scrollArea:ScrollUp()
					Sleep(250)
				end
				while pt:y() >= scrollThresholdDown do
					scrollArea:ScrollDown()
					Sleep(250)
				end
			end)
		end
	else
		self:DeleteThread("SquadManageScrollThread")
	end
end

---
--- Handles the drag and drop operation for the squad management UI.
---
--- @param target table The target window where the drag and drop operation is occurring.
--- @param drag_win table The window being dragged.
--- @param drop_res table The result of the drop operation.
--- @param pt table The mouse cursor position.
---
function SquadManagementDragAndDrop:OnDragDrop(target, drag_win, drop_res, pt)
	if not self.dragged_merc then return end
	local target_wnd, squad_wnd = self:GetSelectedMerc(pt)
	local merc = target_wnd and target_wnd.context
	if merc then
		local squad_context = squad_wnd.context
		local squad = squad_context.squad

		if not squad.joining_squad then
			local squadFrom = gv_Squads[self.dragged_merc.Squad]
			if squad == "empty" then -- New Squad
				TryAssignUnitToSquad(self.dragged_merc)
			elseif merc == "empty" then
				TryAssignUnitToSquad(self.dragged_merc, squad.UniqueId)
			else
				TrySwapMercs(self.dragged_merc, merc)
			end
		end
	end
	self.dragged_merc = false
	self.dragged_merc_squad_wnd = false
end

---
--- Opens the squad creation dialog for the specified squad.
---
--- @param squad_id number The ID of the squad to create.
---
function OpenSquadCreation(squad_id)
	local dlg = GetDialog("PDASquadManagement")
	local context = gv_Squads[squad_id]
	if dlg and context then
		local squadCreation = XTemplateSpawn("PDASquadCreation", dlg, context)
		squadCreation:Open()
	end
end

function OnMsg.UnitAssignedToSquad(squad_id, unit_id, create_new_squad)
	if create_new_squad and GetDialog("PDASquadManagement") and gv_UnitData[unit_id]:IsLocalPlayerControlled() then
		OpenSquadCreation(squad_id)
	end
end

---
--- Handles the end of a drag and drop operation for the squad management UI.
---
--- @param drag_win table The window being dragged.
--- @param last_target table The last target window where the drag and drop operation occurred.
--- @param drag_res table The result of the drag and drop operation.
---
function SquadManagementDragAndDrop:OnDragEnded(drag_win, last_target, drag_res)
	drag_win:delete()
	self.dragged_merc = false
	self.dragged_merc_squad_wnd = false
end

function OnMsg.UnitJoinedPlayerSquad()
	local dlg = GetDialog("PDASquadManagement")
	if dlg then
		dlg.idContent:SetContext(GetSquadManagementSquads())
	end
end

---
--- Shows or hides the satellite display UI.
---
--- @param show boolean Whether to show or hide the satellite display UI.
---
function ShowSatelliteDisplayUI(show)
	local dlg = GetSatelliteViewInterface()
	if dlg then
		dlg:SetVisible(show)
	end
	local pda = GetDialog("PDADialog")
	if pda then
		pda.idToolBar:SetVisible(show)
	end
end

---
--- Generates a table of statistics for the given merc.
---
--- @param merc table The merc to generate statistics for.
--- @return table A table of statistics for the given merc.
---
function MercStatsItems(merc)
	if not merc then return end
	local mercProperties = UnitPropertiesStats:GetProperties()
	local stats = {}
	for p, i in ipairs(mercProperties) do
		if i.category == "Stats" then
			stats[#stats + 1] = { id = i.id, name = i.name, help = i.help, value = merc[i.id] }
		end
	end
	return stats
end

---
--- Generates a table of squad information for the player's mercenary squads.
---
--- @return table A table of squad information, where each item is a table with the following fields:
---   - squad: the squad object
---   - [1..const.Satellite.MercSquadMaxPeople]: the unit IDs in the squad, or "empty" if the slot is empty
---
function GetSquadManagementSquads()
	local squads = GetPlayerMercSquads()
	local items = {}
	for _, squad in ipairs(squads) do
		if squad.CurrentSector then
			local item = {squad = squad}
			for i = 1, const.Satellite.MercSquadMaxPeople do
				item[#item + 1] = squad.units[i] or "empty"
			end
			items[#items + 1] = item
		end
	end
	
	table.sort(items, function (a, b)
		return a.squad.UniqueId < b.squad.UniqueId
	end)
	
	return items
end

---
--- Generates a table of squad information for the player's mercenary squads.
---
--- @return table A table of squad information, where each item is a table with the following fields:
---   - squad: the squad object
---   - [1..const.Satellite.MercSquadMaxPeople]: the unit IDs in the squad, or "empty" if the slot is empty
---
function GetSquadCoopManagementSquads()
	local squads = GetGroupedSquads()
	local items = {}
	for _, squad in ipairs(squads) do
		local item = {squad = squad}
		for i = 1, const.Satellite.MercSquadMaxPeople do
			item[#item + 1] = squad.units[i] or "empty"
		end
		items[#items + 1] = item
	end
	
	table.sort(items, function (a, b)
		return a.squad.UniqueId < b.squad.UniqueId
	end)
	
	return items
end

---
--- Counts the number of cooperative units that match the given control mask.
---
--- @param mask integer The control mask to match against.
--- @return integer The number of cooperative units that match the given control mask.
---
function CountCoopUnits(mask)
	local squads = GetGroupedSquads()
	local count = 0
	for _, squad in ipairs(squads) do		
		for _, unit_id in ipairs(squad.units) do
			local side = gv_UnitData[unit_id].ControlledBy
			count = count + (side==mask and 1 or 0) 
		end
	end
	
	return count
end

local function ChangeUnitControlUIUpdate(unit, control)
	local dlg = GetDialog("CoopMercsManagement")
	if dlg then		
		dlg:OnContextUpdate(unit.session_id)
		if NetIsHost() then
			dlg.idActionBar:OnUpdateActions()		
		end	
	end
end

function OnMsg.UnitControlChanged(unit, control)    ChangeUnitControlUIUpdate(unit, control) end
function OnMsg.UnitDataControlChanged(unit, control)ChangeUnitControlUIUpdate(unit, control) end

---
--- Gets the list of squad logos available for the player.
---
--- @return table The list of squad logos.
---
function GetPlayerSquadLogos()
	local err, files = AsyncListFiles("UI/Icons/SquadLogo", "*")
	if err then return end
	
	local logos = {}
	for i, file in ipairs(files) do
		local logo = string.gsub(file, ".dds", "")
		if not string.ends_with(logo, "_s") then
			logos[#logos+1] = logo
		end
	end
	return logos
end

if FirstLoad then
	g_SquadLogos = GetPlayerSquadLogos()
end
