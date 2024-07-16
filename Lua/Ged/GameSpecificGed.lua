if Platform.ged then

-- fake prop editor, so that accuracy chart is displayed under Caliber props in InventoryItemTemplate editor
GedPropEditors["accuracy_chart"] = "GedPropAccuracyChart"
DefineClass.GedPropAccuracyChart = {
	__parents = { "GedPropEditor" },
}

---
--- Initializes the GedPropAccuracyChart class.
--- This function is called when an instance of the GedPropAccuracyChart class is created.
--- It spawns an "AccuracyChart" template and attaches it to the current instance.
---
--- @function GedPropAccuracyChart:Init
--- @return nil
function GedPropAccuracyChart:Init()
	XTemplateSpawn("AccuracyChart", self)
end

---
--- Updates the value of the GedPropAccuracyChart class.
--- This function is called to update the accuracy chart based on the selected object's properties.
--- It retrieves the property values from the selected object, and sets the context of the accuracy chart.
---
--- @param self GedPropAccuracyChart The instance of the GedPropAccuracyChart class.
--- @return nil
function GedPropAccuracyChart:UpdateValue()
	local values = self.panel:Obj(self.obj)
	local prop_defs = self.panel:Obj("SelectedObject|props")
	local props_cont = {}
	for i = 1, #prop_defs do
		local id = prop_defs[i].id
		if values[id] ~= nil then
			props_cont[id] = values[id]
		else
			props_cont[id] = prop_defs[i].default
		end
	end
	self.idDrawChart:SetContext(props_cont)
	GedPropEditor.UpdateValue(self)
end


GedPropEditors["directions_set"] = "GedPropDirectionsSet"
DefineClass.GedPropDirectionsSet = {
	__parents = { "GedPropSet" },
	
	items = {
		{text = "N", value = "North"},
		{text = "W", value = "West"},
		{text = "E", value = "East"},
		{text = "S", value = "South"},
	},
}

local h_list_items = {
	["West"] = true,
	["East"] = true,
}

---
--- Updates the value of the GedPropDirectionsSet class.
--- This function is called to update the directions set based on the selected object's properties.
--- It deletes the existing children of the container, sets the layout method to a vertical list, and aligns the container to the left.
--- For each item in the directions set, it creates a button and adds it to the container. If the item value is in the h_list_items table, it creates an additional horizontal list container.
--- Finally, it calls the UpdateValue function of the GedPropEditor class.
---
--- @param self GedPropDirectionsSet The instance of the GedPropDirectionsSet class.
--- @return nil
function GedPropDirectionsSet:UpdateValue()
	self.idContainer:DeleteChildren()
	self.idContainer:SetLayoutMethod("VList")
	self.idContainer:SetHAlign("left")

	for _, item in ipairs(self.items) do
		local h_list = h_list_items[item.value]
		if h_list and not self:HasMember("idHListCont") then
			XWindow:new({
				Id = "idHListCont",
				LayoutMethod = "HList",
				LayoutHSpacing = 10,
			}, self.idContainer)
		end
		local button = self:CreateButton(item, h_list and self.idHListCont)
		button:SetHAlign("center")
	end
	
	GedPropEditor.UpdateValue(self)
end

end --Platform.ged


DefineClass.PropertyDefAccuracyChart = {
	__parents = { "PropertyDef" },
	properties = {
		{ category = "Browse", id = "default", name = "Default value", editor = "text", default = "", },
	},
	editor = "accuracy_chart",
	EditorName = "Accuracy chart",
	EditorSubmenu = "Extras",
}

---
--- Calculates the range accuracy for a given weapon, distance, unit, and action.
---
--- @param props_cont table The properties container for the weapon.
--- @param distance number The distance to the target.
--- @param unit table The unit using the weapon.
--- @param action table The action being performed with the weapon.
--- @return number The calculated range accuracy.
---
function GetRangeAccuracy_Ref(props_cont, distance, unit, action)
	local effective_range_acc = 100
	local point_blank_acc = 100
	
	local weapon_range
	if unit and action then
		weapon_range = action:GetMaxAimRange(unit, props_cont)
	end
	
	if not weapon_range then
		weapon_range = props_cont.WeaponRange or props_cont:GetProperty("WeaponRange")
	end
	distance = (1.0 * distance) / const.SlabSizeX
	
	local y0 = 1.0 * point_blank_acc
	--local xm, ym = 1.0 * props_cont.EffectiveRange, 1.0 * effective_range_acc
	--local xr = 1.0 * props_cont.ExtremeRange
	local xm, ym = 0.5 * weapon_range, 1.0 * effective_range_acc
	local xr = 1.0 * weapon_range
	local a, b, c = 0, 0, 0
	
	--[[if distance >= xr then
		return 0
	end--]]

--[[	if distance <= 0 then
		return point_blank_acc
	--elseif distance >= xr then
--		return 0
	elseif distance == xm then
		return effective_range_acc
	elseif distance < xm then
		-- first parabola
		a = -(ym - y0) / (xm*xm)
		b = 2 * (ym - y0) / xm
		c = y0	--]]
	if distance <= xm then
		return effective_range_acc
	else
		-- second parabola
		a = -ym / ((xm-xr)*(xm-xr))
		b = -2 * a * xm
		c = -a*xr*xr - b*xr
	end
	
	--return Max(0, round(a * distance * distance + b * distance + c, 1))
	return round(a * distance * distance + b * distance + c, 1)
end

---
--- Calculates the range accuracy for a weapon based on the distance from the target.
---
--- @param weapon table The weapon object.
--- @param distance number The distance to the target.
--- @param unit table The unit using the weapon.
--- @param action table The action being performed with the weapon.
--- @return number The calculated range accuracy.
function GetRangeAccuracy(weapon, distance, unit, action)
	local effective_range_acc = 100
	local point_blank_acc = 100
	
	local weapon_range
	if unit and action then
		weapon_range = action:GetMaxAimRange(unit, weapon)
	end
	
	if not weapon_range then
		weapon_range = weapon.WeaponRange or weapon:GetProperty("WeaponRange")
	end
	
	if IsKindOf(unit, "UnitBase") then
		weapon_range = unit:CallReactions_Modify("OnUnitGetWeaponRange", weapon_range, weapon, action)
	end

	local y0 = point_blank_acc
	local xm, ym = weapon_range / 2, effective_range_acc
	local xr = weapon_range
	local a, b, c = 0, 0, 0
	
	if distance / const.SlabSizeX <= xm then
		return effective_range_acc
	else
		-- second parabola
		a = MulDivRound(-ym, const.SlabSizeX, (xm-xr)*(xm-xr))
		b = MulDivRound(-2 * a, xm, const.SlabSizeX)
		c = MulDivRound(-a, xr*xr, const.SlabSizeX) - b*xr
	end
	
	local part = MulDivRound(MulDivRound(a, distance, const.SlabSizeX), distance, const.SlabSizeX*const.SlabSizeX)
	return part + MulDivRound(b, distance, const.SlabSizeX) + c
end

if FirstLoad then
	GedSatSectorSaveModsInProgress = false
end

---
--- Saves any dirty mods associated with satellite sector presets in the campaign.
---
--- This function is called in a real-time thread to avoid blocking the main game loop.
--- It iterates through all campaign presets, finds any that are dirty, and then saves
--- the associated mods if they can be saved. A UI status message is set while the
--- mods are being saved.
---
--- @return nil
function GedSatSectorSaveMods()
	if not IsValidThread(GedSatSectorSaveModsInProgress) then
		local thread = CanYield() and CurrentThread()
		GedSatSectorSaveModsInProgress = CreateRealTimeThread(function()
			local mods = {}
			ForEachPresetExtended("CampaignPreset", function(preset, group)
				if preset:IsDirty() then
					for _, satSectorPreset in ipairs(preset.Sectors) do
						local mod_id = satSectorPreset.modId
						if mod_id then
							mods[mod_id] = Mods[mod_id]
						end
					end
				end
			end)
			
			local can_save = true
			for _, mod in pairs(mods) do
				if not mod:CanSaveMod(ged) then
					can_save = false
					break
				end
			end
			if can_save then
				GedSetUiStatus("mod_save", "Saving mods...")
				for _, mod in pairs(mods) do
					mod:SaveWholeMod()
				end
				GedSetUiStatus("mod_save")
			end
			
			GedSatSectorSaveModsInProgress = false
			Wakeup(thread)
		end)
		if thread then WaitWakeup(30000) end
	end
end

---
--- Creates an X-Bug report dialog with customized parameters.
---
--- @param summary string The summary of the bug report.
--- @param descr string The description of the bug report.
--- @param files table A table of file paths to attach to the bug report.
--- @param params table An optional table of parameters to customize the bug report dialog.
--- @return table The created X-Bug report dialog.
---
function GedCreateXBugReportDlg(summary, descr, files, params)
	local endUserVersion = not not Platform.goldmaster
	if Platform.steam and endUserVersion then
		local steam_beta, steam_branch = g_GedApp:Call("GedGetSteamBetaName")
		endUserVersion = not steam_beta or steam_branch == ""
	end
	
	local minimalVersion = not insideHG() and endUserVersion
	
	params = params or {}
	params.no_priority = not insideHG()
	params.no_platform_tags = not insideHG()
	params.force_save_check = "save as extra_info"
	
	if minimalVersion then
		table.set(params, "no_platform_tags", true)
		table.set(params, "no_game_tags", true)
		table.set(params, "no_header_combos", true)
		table.set(params, "no_attach_auto_save", true)
		table.set(params, "no_api_token",true)
	end
	
	local mod = g_GedApp:Call("GedGetLastEditedMod")
	local modRelated = g_GedApp:Call("GedAreModdingToolsActive")

	table.set(params, "mod", mod)
	table.set(params, "mod_related", modRelated)
	
	return CreateXBugReportDlg(summary, descr, files, params)
end

function OnMsg.GatherModItemDockedActions(obj, actions)
	if IsKindOf(obj, "Preset") or IsKindOf(obj, "ModItemSector") then
		local preset_class = g_Classes[obj.ModdedPresetClass]
		local class = preset_class and (preset_class.PresetClass or preset_class.class)
		local name = IsKindOf(obj, "ModItemSector") and "Satellite sectors editor" or
			preset_class.EditorMenubarName ~= "" and preset_class.EditorMenubarName or (class .. " editor")
			
		actions["PresetEditor"] = {
			name = "Open in " .. name,
			rolloverText = "Open the dedicated editor for this item,\nalongside the rest of the game content.",
			op = "GedOpOpenModItemPresetEditor",
		}
	end
end

--- @param socket table The socket object associated with the operation.
--- @param obj table The object that triggered the operation.
--- @param selection table The current selection of objects.
--- @param a any Additional parameter 1.
--- @param b any Additional parameter 2.
--- @param c any Additional parameter 3.
---
--- Opens the dedicated editor for the specified object. If the object is a ModItemSector, it opens the Satellite Sectors Editor. If the object has a ModdedPresetClass, it opens the editor for that class.
function GedOpOpenModItemPresetEditor(socket, obj, selection, a, b, c)
	if IsKindOf(obj, "ModItemSector") then
		obj:POpenGedSatelliteSectorEditor(socket)
	elseif obj and obj.ModdedPresetClass then
		obj:OpenEditor()
	end
end

if Platform.editor then
	function XSelectObjectsTool:PreDeleteConfirmation()
		-- Only in modding mod and when the map is not replaced with a ModItemSector
		if editor.IsModdingEditor() and not mapdata.ModMapPath then
			local display_warn = false
			local sel = editor.GetSel()
			for _, obj in ipairs(sel) do
				if IsKindOf(obj, "GridMarker") or IsKindOf(obj, "Room") or IsKindOf(obj, "TacticalCameraCollider") then
					display_warn = true
					break
				end
			end
			-- Display a warning message to modders that are deleting important game objects from the map
			if display_warn then
				local title = "Warning"
				local question = "You are about to delete objects that are an integral part of the original Jagged Alliance 3 campaign.\nDo you want to proceed?"
				local game_question = StdMessageDialog:new({}, terminal.desktop, { question = true, title = title, text = question, ok_text = "Yes", cancel_text = "No" })
				game_question:Open()
				if game_question:Wait() == "ok" then
					return true -- approve the deletion
				end
				return false
			end
		end
		
		return true
	end
end