---
--- Returns the sector control color and text color for the given side.
---
--- @param side string The side, either "player1", "enemy1", or "neutral".
--- @return table The sector control color and text color.
function GetSectorControlColor(side)
	local color
	local textColor = GameColors.C
	if side == "player1" then
		color = GameColors.Player
	elseif side == "enemy1" then
		color = GameColors.Enemy
	elseif side == "ally" then
		color = GameColors.Player
	else -- neutral
		color = GameColors.LightDarker
		textColor = GameColors.DarkA
	end
	local r, g, b = GetRGB(color)
	local t_r, t_g, t_b = GetRGB(textColor)
	return color, "<color " .. r .. " " .. g .. " " .. b .. ">", textColor, "<color " .. t_r .. " " .. t_g .. " " .. t_b .. ">"
end

---
--- Returns the sector control text and color for the given side.
---
--- @param side string The side, either "player1", "enemy1", or "neutral".
--- @return string The formatted sector control text.
function SectorControlText(side)
	if not side then return end

	local _, controlTextColor = GetSectorControlColor(side)
	local controlText
	if side == "player1" then
		return T{75323493045, "<clr>Player</color> control",clr = controlTextColor}
	elseif side == "enemy1" then
		return T{197389932460, "<clr>Enemy</color> control",clr = controlTextColor}
	else
		return T{324030090771, "<clr>Neutral</color>",clr = controlTextColor}
	end
end

-- sort poi in sector icons
POIDescriptions = {
	{id = "Guardpost", display_name = T(783261626976, "Outpost"), descr = T(349382017874, "Enemy outposts organize attacking squads to take over nearby sectors. They also block water travel near them"), icon = "guard_post"},
	{id = "Mine",      display_name = T(574641095788, "Mine"),      descr = T(694639203124, "Mines provide daily income based on the <em>Loyalty</em> of the nearest settlement"), icon = "mine"},
	{id = "Port",      display_name = T(682491033993, "Port"),      descr = T(301024708154, "You can initiate travel over water sectors from a port under your control. Boat travel usually costs money"), icon = "port"},
	{id = "Hospital",  display_name = T(928160208169, "Hospital"),  descr = T(113589428451, "Hospitals allow fast healing of wounds for money via the Hospital Treatment Operation"), icon = "hospital"},
	{id = "RepairShop",  display_name = T(333237565365, "Repair Shop"),  descr = T(653771367256, "Repair shops allow mercs to craft ammo and explosives via the corresponding operations"), icon = "repair_shop"},
}

---
--- Sets the satellite overlay for the satellite view dialog.
---
--- @param overlay boolean Whether to enable or disable the satellite overlay.
---
function SetSatelliteOverlay(overlay)
	if not gv_SatelliteView then return end
	local diag = GetSatelliteDialog()
	if not diag then return end
	if diag.overlay == overlay then	
		diag.overlay = false
	else
		diag.overlay = overlay
	end
	ObjModified("satellite-overlay")
end

MapVar("g_RevealedSectors", {})
GameVar("gv_RevealedSectorsTemporarily", {})
GameVar("AllSectorsRevealed", false)

---
--- Allows revealing the specified sectors on the map.
---
--- @param array table An array of sector IDs to allow revealing.
---
function AllowRevealSectors(array)
	for i, s in ipairs(array) do
		if gv_Sectors[s] then
			gv_Sectors[s].reveal_allowed = true
		end
	end
	RecalcRevealedSectors()
end

---
--- Reveals all sectors on the map, allowing them to be displayed.
---
--- This function sets the `reveal_allowed` flag to `true` for all sectors,
--- and then calls `RecalcRevealedSectors()` to update the list of revealed
--- sectors. It also sets the `AllSectorsRevealed` global variable to `true`.
---
--- @function RevealAllSectors
--- @return nil
function RevealAllSectors()
	for id, sector in pairs(gv_Sectors) do
		sector.reveal_allowed = true
	end
	RecalcRevealedSectors()
	Msg("AllSectorsRevealed")
	AllSectorsRevealed = true
end

---
--- Fixes up the `AllSectorsRevealed` global variable in the savegame session data.
---
--- This function checks the `reveal_allowed` flag for all sectors in the `gv_Sectors` table.
--- If all sectors have `reveal_allowed` set to `true`, it sets the `AllSectorsRevealed`
--- global variable in the session data to `true`.
---
--- @param session_data table The savegame session data to fix up.
--- @return nil
function SavegameSessionDataFixups.AllSectorsRevealed(session_data)
	local sectors = table.get(session_data, "gvars", "gv_Sectors")
	if not sectors then return end

	local allRevealed = true
	for id, sector in pairs(sectors) do
		if not sector.reveal_allowed then
			allRevealed = false
		end
	end
	if not allRevealed then return end
	session_data.gvars.AllSectorsRevealed = true
end

---
--- Recalculates the list of revealed sectors on the map.
---
--- This function updates the `g_RevealedSectors` table to reflect the current state of revealed sectors.
--- It checks the following conditions to determine which sectors should be revealed:
---
--- 1. Player squads make adjacent sectors visible (guardpost grants vision within 2 sectors of it).
--- 2. Sectors with a guardpost on the player's side are revealed within a 2-sector radius.
--- 3. Sectors with the `reveal_allowed` flag set to `false` are not revealed.
--- 4. Sectors that are temporarily revealed (stored in `gv_RevealedSectorsTemporarily`) are also included in the revealed sectors.
---
--- After updating the `g_RevealedSectors` table, this function calls `Msg("RevealedSectorsUpdate")` to notify other parts of the game that the revealed sectors have changed.
---
--- @return nil
function RecalcRevealedSectors()
	g_RevealedSectors = {}
	
	-- player squads make adjacent sectors visible (guardpost grants vision within 2 sectors of it)
	for _, squad in ipairs(GetPlayerMercSquads("include_militia")) do
		local sector_id = squad.CurrentSector
		
		-- On shortcuts squads have visibility to a predefined set of sectors
		if squad.traversing_shortcut_start_sId then
			local nextSectorId = squad.route[1][1]
			local shortcut = GetShortcutByStartEnd(squad.traversing_shortcut_start_sId, nextSectorId)
			if shortcut then
				for _, s in ipairs(shortcut:GetShortcutVisibilitySectors()) do
					RevealSectorsAround(s, 0)
				end
			end
			RevealSectorsAround(sector_id, 0)
		elseif sector_id then
			RevealSectorsAround(sector_id, 1)
		end
	end
	
	for sector_id, sector in sorted_pairs(gv_Sectors) do
		if sector.Guardpost and (sector.Side == "player1" or sector.Side == "player2") then
			RevealSectorsAround(sector_id, 2)
		end
		if not sector.reveal_allowed then -- Force revealed is more like "allow to be revealed".
			g_RevealedSectors[sector_id] = false
		end
	end
	
	for sector_id, val in pairs(gv_RevealedSectorsTemporarily) do
		g_RevealedSectors[sector_id] = g_RevealedSectors[sector_id] and (not not val)
	end
	
	DelayedCall(0, Msg, "RevealedSectorsUpdate")
end

---
--- Iterates over the sectors that are adjacent to the given sector in the cardinal directions (up, down, left, right).
---
--- @param sector_id string The ID of the sector to iterate around.
--- @param fn function The function to call for each adjacent sector. The function should take the sector ID as its first argument.
--- @param ... any Additional arguments to pass to the function.
---
--- @return nil
function ForEachSectorCardinal(sector_id, fn, ...)
	local campaign = GetCurrentCampaignPreset()
	local rows, columns = campaign.sector_rows, campaign.sector_columns
	local row, col = sector_unpack(sector_id)
	if row + 1 <= rows then -- Down
		if fn(sector_pack(row + 1, col), ...) == "break" then return end
	end
	if row - 1 >= campaign.sector_rowsstart then -- Up
		if fn(sector_pack(row - 1, col), ...) == "break" then return end
	end
	if col + 1 <= columns then -- Right
		if fn(sector_pack(row, col + 1), ...) == "break" then return end
	end
	if col - 1 >= 1 then -- Left
		if fn(sector_pack(row, col - 1), ...) == "break" then return end
	end
end

---
--- Iterates over the sectors that are adjacent to the given sector within the specified radius.
---
--- @param center_sector_id string The ID of the sector at the center of the iteration.
--- @param radius number The radius around the center sector to iterate over.
--- @param fn function The function to call for each sector within the radius. The function should take the sector ID as its first argument.
--- @param ... any Additional arguments to pass to the function.
---
--- @return nil
function ForEachSectorAround(center_sector_id, radius, fn, ... )
	local campaign = GetCurrentCampaignPreset()
	local rows, columns = campaign.sector_rows, campaign.sector_columns
	local row, col = sector_unpack(center_sector_id)
	for r = Max(campaign.sector_rowsstart, row-radius), Min(rows, row+radius) do
		for c = Max(1, col-radius), Min(columns, col+radius) do
			if fn(sector_pack(r, c),...) == "break" then return end
		end
	end	
end

---
--- Reveals all sectors within the specified radius around the given center sector.
---
--- @param center_sector_id string The ID of the sector at the center of the area to reveal.
--- @param radius number The radius around the center sector to reveal.
---
--- @return nil
function RevealSectorsAround(center_sector_id, radius)
	local centerIsUnderground = IsSectorUnderground(center_sector_id)
	ForEachSectorAround(center_sector_id, radius, function(sector_id)
		if centerIsUnderground then
			sector_id = sector_id .. "_Underground"
		end
	
		g_RevealedSectors[sector_id] = true
	end)
end

function OnMsg.SatelliteTick(tick, ticks_per_day)
	local change = false
	for sector_id, val in pairs(gv_RevealedSectorsTemporarily) do
		if Game.CampaignTime > gv_RevealedSectorsTemporarily[sector_id] then
			gv_RevealedSectorsTemporarily[sector_id] = nil
			change = true
		end
	end
	if change then 
		RecalcRevealedSectors()
	end
end

---
--- Checks if the given sector is revealed.
---
--- @param sector table The sector to check.
--- @return boolean true if the sector is revealed, false otherwise.
function IsSectorRevealed(sector)
	if GedSatelliteSectorEditor then return true end
	if sector then
		return sector and g_RevealedSectors[sector.Id] and sector.discovered
	end
end

DefineClass.SatelliteConflictClass = {
	__parents = {"ZuluModalDialog"},
	playerPower = 0,
	enemyPower = 0
}

---
--- Opens the satellite conflict UI.
---
--- @param self SatelliteConflictClass The instance of the SatelliteConflictClass.
--- @return nil
function SatelliteConflictClass:Open()
	local context = self:GetContext()
	
	if context.autoResolve then
		self.playerPower = context.allySquads.power or 0
		self.enemyPower = context.enemySquads.power or 0
		self.playerMod = context.allySquads.playerMod or 0
	else
		self:UpdatePowers()
		self.playerPower = context.conflict.player_power or 0
		self.enemyPower = context.conflict.enemy_power or 0
	end
	
	if GetUIStyleGamepad() then
		HideCombatLog()
	end
	
	SetCampaignSpeed(0, GetUICampaignPauseReason("ConflictUI"))
	ZuluModalDialog.Open(self)
end

---
--- Cleans up the satellite conflict UI when it is deleted.
---
--- Sets the campaign speed back to normal and removes the pause reason for the conflict UI.
---
--- @return string "break" to indicate that the deletion should continue.
function SatelliteConflictClass:OnDelete()
	SetCampaignSpeed(nil, GetUICampaignPauseReason("ConflictUI"))
	return "break"
end

---
--- Updates the player and enemy power values for the satellite conflict UI.
---
--- If the conflict is not being auto-resolved, this function calculates the player and enemy power values
--- using the `GetAutoResolveOutcome` function. The calculated values are then stored in the context object
--- and the `playerPower`, `enemyPower`, and `playerMod` properties of the `SatelliteConflictClass` instance.
---
--- If the conflict is being auto-resolved, the power values are already set in the context object, and this
--- function does not need to calculate them.
---
--- @param self SatelliteConflictClass The instance of the SatelliteConflictClass.
--- @return nil
function SatelliteConflictClass:UpdatePowers()	
	if not self.context.autoResolve then
		local outcome, playerPower, enemyPower, playerMod = GetAutoResolveOutcome(self.context, "disableRandomMod")
		self.context.predicted_outcome = outcome
		if self.context.conflict then
			self.context.conflict.player_power = playerPower
			self.context.conflict.enemy_power = enemyPower
			self.context.conflict.player_mod = playerMod
		end
		self.playerPower = playerPower
		self.enemyPower = enemyPower
		self.playerMod = playerMod
		ObjModified("sidePower")
	end
end

---
--- Formats a sector's name and background color for display in the Satellite View UI.
---
--- @param context table The context object containing sector information.
--- @param sector_id string The ID of the sector to format.
--- @return string The formatted sector name with background color.
---
function TFormat.Sector(context, sector_id)
	local clr = RGB(255,255,255)
	local name = ""
	local sector = gv_Sectors[sector_id]
	if sector then
		clr = GetSectorControlColor(sector.Side)
		name = sector.name
	end
	local r, g, b = GetRGB(clr)
	local colorTag = string.format("<background %i %i %i>", r, g, b)
	local endColorTag = "</background>"
	return T{996915765683, "<colorTag><sectorName></color>", colorTag = colorTag, sectorName = name, ["/color"] = endColorTag}
end


---
--- Gets the ID of the underground or overground sector for the given sector ID.
---
--- If the given sector has a ground sector, the ground sector ID is returned. Otherwise, the ID of the underground sector is returned.
---
--- @param id string The ID of the sector.
--- @return string The ID of the underground or overground sector.
---
function GetUnderOrOvergroundId(id)
	local sector = gv_Sectors[id]
	local otherSectorId = sector.GroundSector and sector.GroundSector or id .. "_Underground"
	otherSectorId = otherSectorId and gv_Sectors[otherSectorId] and otherSectorId
	return otherSectorId
end

---
--- Gets the icon to display for the underground button in the Satellite View UI.
---
--- The icon displayed depends on whether there is a conflict in the underground sector, and whether there are any squads in the underground sector.
---
--- @param id string The ID of the sector.
--- @return string The path to the icon to display for the underground button.
---
function GetUndergroundButtonIcon(id)
	local otherSectorSquads = GetSquadsInSector(id, nil, "includeMilitia")
	local otherSectorConflict = IsConflictMode(id)
	local img = "UI/Icons/SateliteView/underground"
	if otherSectorConflict then
		img = "UI/Icons/SateliteView/underground_conflict"
	elseif #otherSectorSquads > 0 and gv_Sectors[id].GroundSector then
		img = "UI/Icons/SateliteView/underground_squad"
	end
	return img
end