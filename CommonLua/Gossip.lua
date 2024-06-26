-- NetGossip works only when the player is online
-- NetRecord should be used for important events that we don't want to miss

---
--- Reports a shader compilation event to the NetGossip system.
---
--- @param shader string The name of the shader that was compiled.
---
function ReportShaderCompilation(shader)
	if not Platform.developer then
		local eye, look, type, zoom
		if GetMap() ~= "" then
			eye, look, type, zoom = GetCamera()
		end
		NetGossip("shader", shader, eye, look, type, zoom)
	end
end

---
--- Reports a double update event to the NetGossip system.
---
--- @param info string The information about the double update event.
---
function ReportAnimDoubleUpdate(info)
	if not Platform.developer then
		local eye, look, type, zoom
		if GetMap() ~= "" then
			eye, look, type, zoom = GetCamera()
		end
		NetGossip("DoubleUpdate", info, eye, look, type, zoom)
	end
end

function OnMsg.NetGameJoined(game_id, unique_id)
	NetGossip("NetGameJoined", netGameAddress)
end

function OnMsg.NetGameLeft(reason)
	NetGossip("NetGameLeft", netGameAddress, reason)
end

function OnMsg.GameDesynced()
	NetGossip("Desync", netGameAddress)
end

function OnMsg.AchievementUnlocked(achievement)
	NetGossip("AchievementUnlocked", achievement)
end