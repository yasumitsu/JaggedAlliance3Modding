MapVar("g_PlayerToSelect", function() return {} end)
MapVar("g_PlayerToAim", function() return {} end)

local function lPlayerSelectedUnit(playerId, tableOfUnitId)
	if not g_PlayerToSelect then return end
	g_PlayerToSelect[playerId] = tableOfUnitId
	ObjModified("co-op-ui")
	if playerId ~= netUniqueId then
		Msg("CoOpPartnerSelectionChanged", tableOfUnitId)
	end
end

---
--- Sets the player's aim target unit.
---
--- @param playerId number The ID of the player whose aim target is being set.
--- @param unitId number The ID of the unit the player is aiming at.
---
function SetCoOpPlayerAimingAtUnit(playerId, unitId)
	if not g_PlayerToAim then return end
	g_PlayerToAim[playerId] = unitId
	ObjModified("co-op-ui")
end

NetSyncEvents.PlayerSelectedUnit = lPlayerSelectedUnit

---
--- Gets the ID of the other player in the game.
---
--- @return number|false The ID of the other player, or `false` if there is only one player.
---
function GetOtherPlayerId() -- Not sure if we can just swap indices :/
	local myPlayerId = netUniqueId
	local playersInGame = netGamePlayers
	local otherPlayerId = false
	for i, p in ipairs(netGamePlayers) do
		local id = p.id
		if id ~= myPlayerId then
			otherPlayerId = id
			break
		end
	end
	return otherPlayerId
end

---
--- Returns the name of the other player in the game.
---
--- @return string The name of the other player.
---
function TFormat.GetOtherPlayerNameFormat()
	return Untranslated(netGamePlayers[GetOtherPlayerId()].name)
end

---
--- Checks if the other player in a co-op game is acting on the given unit.
---
--- @param unit table The unit to check.
--- @param actionType string The type of action to check for, either "select" or "aim".
--- @return boolean True if the other player is acting on the unit, false otherwise.
---
function IsOtherPlayerActingOnUnit(unit, actionType)
	if not IsCoOpGame() then return false end

	local otherPlayerId = GetOtherPlayerId()
	if not otherPlayerId then return false end
	
	if actionType == "select" then
		local selected = g_PlayerToSelect[otherPlayerId]
		return selected and table.find(selected, unit.session_id)
	elseif actionType == "aim" then
		local aimed = g_PlayerToAim[otherPlayerId]
		return aimed == unit.session_id
	end
end

---
--- Checks if the given unit is part of the primary selection of the other player in a co-op game.
---
--- @param unit table The unit to check.
--- @return boolean True if the unit is part of the other player's primary selection, false otherwise.
---
function IsUnitPrimarySelectionCoOpAware(unit)
	if Selection and Selection[1] == unit then return true end
	if not IsCoOpGame() then return false end
	local otherPlayerId = GetOtherPlayerId()
	local otherPlayerSelectionTable = g_PlayerToSelect[otherPlayerId]
	local unitId = unit.session_id
	return otherPlayerSelectionTable and table.find(otherPlayerSelectionTable, unitId)
end

function OnMsg.NetPlayerLeft(player)
	NetSyncEvents.AdviseConversationChoice(false)

	local playerId = player and player.id
	if not playerId then return end
	lPlayerSelectedUnit(playerId, false)
	SetCoOpPlayerAimingAtUnit(playerId, false)
end

function OnMsg.SelectionChange()
	local units = table.map(Selection, "session_id")
	NetSyncEvent("PlayerSelectedUnit", netUniqueId, units)
end