config.SwarmPublicKey = config.SwarmPublicKey or {}

config.SwarmPublicKey["dev"] = RSACreateKeyNoErr(
[[-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAuDWBDpkjqJuJ1kaZGtlf
AJPS2q28oZ3Qk2hPoTDVGRzT93RmiCNGk4kQr4jtBNaoeCnAN7cUHC9A4Npww/m+
S/3LrNOIfn7inS9uBJEAowNaLf90g8YOdkyJ3aaNXJrjHyKrL5z4W/+qLB6jr0Po
yzQqcZDduy1+bAJIslYY58vPoTZkk63w55H5MdkicksnDPQxxf2Bo3WQwvYt4GlN
UrPLBP5xGXtE2DJXqsRhHfIC5gaBewcKl3oXGHDxaYMTA3p5doMpfJUtGHdh9xd/
3dIPb1rx65v7kagCE9T7LfoBWTjfi2ONUcxxsu5tD3PyTtmBHlGZP2AyGKxYHYEl
rwIDAQAB
-----END PUBLIC KEY-----]])

---
--- Returns the Swarm public key for the specified host.
---
--- If a public key is not found for the specified host, the public key for the "dev" host is returned instead.
---
--- @param host string The host to get the public key for.
--- @return string The Swarm public key for the specified host, or the "dev" host if not found.
function GetSwarmPublicKey(host)
	return config.SwarmPublicKey[host] or config.SwarmPublicKey["dev"]
end

if Platform.cmdline then return end

if FirstLoad then
	netSwarmSocket = false
	netDisplayName = false
	netAccountId = false
	netAuthProvider = false
	netSwarmPing = -1
	netInGame = false
	netUniqueId = 1
	netGameSeed = 0
	netGameMaxPlayers = 0
	netGamePlayers = {}
	netGameAddress = false
	netGameInfo = {}
	netServerRealTimeDelta = 0
	netServerGameTimeDelta = 0
	netBufferedEvents = false
	netDesync = false
	netBannedReason, netBannedPeriod = false, 0
	netAllowGossip = false
	netRestrictedAccount = false
	netEnvironment = false
	netConnectThread = false
	netConnectionReasons = {}
	
	--Hashing:
	HashLogSize = rawget(_G, "HashLogSize") or 16 -- in MB
	HashLogPath = rawget(_G, "HashLogPath") or ""
	
	-- Simulate network lag
	netSimulateLagAvg = 0
	netSimulateLagAmp = 0
	netSimulateLagLastTime = 0
end

-------------------------------------------------[ Hash ]------------------------------------------------------

---
--- Returns the current value of the network hash.
---
--- @return number The current value of the network hash.
function NetGetHashValue()
	return GetEngineVar("", "NetHashValue")
end

---
--- Checks if the network hash update is currently enabled.
---
--- @return boolean True if the network hash update is enabled, false otherwise
--- @return table The reasons why the network hash update is enabled or paused
---
function NetIsHashEnabled()
	if GetEngineVar("", "NetEnableUpdateHash") then
		return true, NetHashUpdateReasons
	else
		return false, NetHashPauseReasons
	end
end

---
--- Resets the current value of the network hash.
---
--- @param value number The new value to set the network hash to. If not provided, defaults to 1.
--- @return boolean True if the network hash value was successfully reset, false otherwise.
function NetResetHashValue(value)
	return SetEngineVar("", "NetHashValue", value or 1)
end

---
--- Sets the network hash update state based on the reasons for enabling and pausing the update.
---
--- The function checks the `NetHashUpdateReasons` and `NetHashPauseReasons` tables to determine if the network hash update should be enabled or not.
--- If there are any reasons to enable the update and no reasons to pause it, the update is enabled. Otherwise, it is disabled.
--- The function then sets the `NetEnableUpdateHash` engine variable to the determined state.
---
--- @return nil
function NetSetUpdateHash()
	Msg("NetUpdateHashReasons", NetHashUpdateReasons, NetHashPauseReasons)
	local enable = next(NetHashUpdateReasons) and not next(NetHashPauseReasons) and true or false
	--print("NetApplyHashReasons:", enable, "\n\tENABLE:", table.concat(table.keys(NetHashUpdateReasons), ", "), "\n\tPAUSE:", table.concat(table.keys(NetHashPauseReasons), ", "))
	SetEngineVar("", "NetEnableUpdateHash", enable)
end

function OnMsg.NetUpdateHashReasons(enable_reasons)
	enable_reasons.netInGame = Game and netInGame and true or nil
end

if FirstLoad then
	NetHashUpdateReasons = {}
	NetHashPauseReasons = {}
end

---
--- Pauses the network hash update for the specified reason.
---
--- This function adds the given reason to the `NetHashPauseReasons` table, and then calls `NetSetUpdateHash()` to update the network hash update state.
---
--- @param reason string|boolean The reason for pausing the network hash update. If not provided, `false` is used.
--- @return nil
---
function NetPauseUpdateHash(reason)
	NetHashPauseReasons[reason or false] = true
	NetSetUpdateHash()
end

---
--- Resumes the network hash update for the specified reason.
---
--- This function removes the given reason from the `NetHashPauseReasons` table, and then calls `NetSetUpdateHash()` to update the network hash update state.
---
--- @param reason string|boolean The reason for resuming the network hash update. If not provided, `false` is used.
--- @return nil
---
function NetResumeUpdateHash(reason)
	NetHashPauseReasons[reason or false] = nil
	NetSetUpdateHash()
end

---
--- Adds the given reason to the `NetHashUpdateReasons` table and calls `NetSetUpdateHash()` to update the network hash update state.
---
--- @param reason string|boolean The reason for enabling the network hash update. If not provided, `false` is used.
--- @return nil
function NetSetUpdateHashReason(reason)
	NetHashUpdateReasons[reason or false] = true
	NetSetUpdateHash()
end

---
--- Removes the given reason from the `NetHashUpdateReasons` table, and then calls `NetSetUpdateHash()` to update the network hash update state.
---
--- @param reason string|boolean The reason for disabling the network hash update. If not provided, `false` is used.
--- @return nil
---
function NetClearUpdateHashReason(reason)
	NetHashUpdateReasons[reason or false] = nil
	NetSetUpdateHash()
end

function OnMsg.PersistSave(data)
	data.HashValue = NetGetHashValue()
end

function OnMsg.PersistLoad(data)
	NetResetHashValue(data.HashValue)
end

---
--- Determines whether the hash log should be reset on map change.
---
--- @return boolean true if the hash log should be reset, false otherwise
function ShouldResetHashLogOnMapChange()
	return true
end

-- stop NetUpdateHash during map loading
function OnMsg.ChangeMap()
	if ShouldResetHashLogOnMapChange() then NetResetHashLog(HashLogSize) end
	NetPauseUpdateHash("ChangingMap")
end

function OnMsg.ChangeMapDone()
	NetResumeUpdateHash("ChangingMap")
end

function OnMsg.PreNewMap()
	NetPauseUpdateHash("NewMap")
end

function OnMsg.PostNewMapLoaded()
	if ShouldResetHashLogOnMapChange() then NetResetHashLog(HashLogSize) end
	NetResumeUpdateHash("NewMap")
	NetUpdateHash("NewMapLoaded", CurrentMap, mapdata.NetHash, MapLoadRandom, Game and Game.seed_text)
end

function OnMsg.PreLoadGame()
	NetPauseUpdateHash("LoadGame")
end

function OnMsg.PostLoadGame()
	NetPauseUpdateHash("LoadGame")
end

-- stop NetUpdateHash during loading a saved game
function OnMsg.UnpersistStart()
	NetResetHashLog(HashLogSize)
	NetPauseUpdateHash("LoadGame")
end

function OnMsg.UnpersistEnd()
	NetResetHashLog(HashLogSize)
	NetResumeUpdateHash("LoadGame")
end

function OnMsg.NewGame()
	NetResetHashLog(HashLogSize)
	NetResetHashValue()
	NetSetUpdateHash()
end

function OnMsg.DoneGame(game)
	NetResetHashLog(HashLogSize)
	NetSetUpdateHash()
end

---
--- Handles a desync event in the game.
---
--- When a desync occurs, this function logs the hash log data and optionally saves it to a file.
--- The desync event is then broadcast to the game using the "GameDesynced" message.
---
--- @param game_id string The ID of the game that desynced.
--- @param ... any Additional arguments related to the desync event.
---
function NetSyncEvents.Desync(game_id, ...)
	print("Desync: " .. game_id, ...)
	netDesync = true
	local data = GetHashLog()
	NetSend("rfnLog", "desync", game_id, "txt", CompressPstr(data))
	local path
	if config.DesyncPath then
		path = config.DesyncPath
		if not string.ends_with(path, "\\") then
			path = path .. "\\"
		end
		local username = (Platform.ps4 and netDisplayName or "") or GetUsername()
		path = path .. game_id .. "-" .. username .. "-" .. netUniqueId .. ".desync.log"
		print("Desync log saved at:", path)
		CreateRealTimeThread(function()
			local err = AsyncStringToFile(path, data)
			if err then print("DumpHashLog", err) end
		end)
	end
	
	Msg("GameDesynced", path, data)
end

local function InvokeObjCheat(selection, method, ...)
	local objs = IsValid(selection) and { selection } or selection
	for _, obj in ipairs(objs) do
		if IsValid(obj) and PropObjHasMember(obj, method) then
			LogCheatUsed(method, obj)
			obj[method](obj, ...)
		end
	end
end

---
--- Handles an object cheat event in the game.
---
--- When a cheat is used on an object, this function logs the cheat usage and invokes the corresponding cheat method on the object.
---
--- @param selection table|userdata The object or list of objects to apply the cheat to.
--- @param method string The name of the cheat method to invoke.
--- @param ... any Additional arguments to pass to the cheat method.
---
function NetSyncEvents.ObjCheat(selection, method, ...)
	if not AreCheatsEnabled() then return end
	print("ObjCheat", method)
	assert(string.starts_with(method, "Cheat"))
	if string.starts_with(method, "Cheat") then
		Msg("ObjCheatStart", method)
		procall(InvokeObjCheat, selection, method, ...)
		Msg("ObjCheatEnd", method)
	end
end

---
--- Handles a cheat event in the game.
---
--- When a cheat is used, this function logs the cheat usage and invokes the corresponding cheat method.
---
--- @param method string The name of the cheat method to invoke.
--- @param ... any Additional arguments to pass to the cheat method.
---
function NetSyncEvents.Cheat(method, ...)
	if not AreCheatsEnabled() then return end
	print("Cheat", method)
	assert(string.starts_with(method, "Cheat"))
	if string.starts_with(method, "Cheat") then
		LogCheatUsed(method)
		_G[method](...)
	end
end

GameVar("CheatsUsed", false)
---
--- Logs the usage of a cheat in the game.
---
--- This function is called when a cheat is used on an object or in the game. It records the time, the name of the cheat method, the class of the object (if applicable), and the handle of the object (if applicable) in the `CheatsUsed` table.
---
--- @param method string The name of the cheat method that was used.
--- @param obj table|userdata The object that the cheat was used on, if applicable.
--- @param ... any Additional arguments passed to the cheat method.
---
function LogCheatUsed(method, obj, ...)
	CheatsUsed = CheatsUsed or {}
	CheatsUsed[#CheatsUsed + 1] = { GameTime(), method, obj and obj.class or nil, obj and rawget(obj, "handle") or nil }
end

---
--- Checks if any cheats have been used in the game.
---
--- @return boolean true if any cheats have been used, false otherwise
---
function AreCheatsUsed()
	return CheatsUsed and #CheatsUsed > 0
end

function OnMsg.UnableToUnlockAchievementReasons(reasons, achievement)
	if not Platform.asserts and AreCheatsUsed() then
		reasons["cheats used"] = true
	end
end

---
--- Generates a string representation of the cheats used in the game.
---
--- This function iterates through the `CheatsUsed` table and formats the information about each cheat usage into a string. The string includes the game time when the cheat was used, the name of the cheat method, and the class and handle of the object the cheat was used on (if applicable).
---
--- @return string A string representation of the cheats used in the game.
---
function _GetCheatsUsedStr()
	local tbl = { "Cheats used:" }
	for _, entry in ipairs(CheatsUsed) do
		local time, method, class, handle = table.unpack(entry)
		local obj_str = ""
		if class and handle then
			obj_str = string.format("%s(%d)", class, handle)
		elseif class then
			obj_str = class
		end
		tbl[#tbl + 1] = string.format("%10d %30s %s", time, method, obj_str)
	end
	return table.concat(tbl, "\n\t")
end

function OnMsg.BugReportStart(print_func)
	if CheatsUsed then
		print_func(_GetCheatsUsedStr())
	end
end

if Platform.console and not Platform.developer then
	function LogHash() end
end

---
--- Generates a string representation of the game state for debugging purposes.
---
--- This function collects information about the current game state, including:
--- - The map name and hash
--- - The Lua and Assets revisions
--- - The platform, provider, and variant information
--- - The hash of the terrain passability grids
--- - The reasons for suspending passability edits
--- - Information about the local player (if in developer mode)
--- - A list of all synchronized and asynchronous game objects, sorted by various criteria
--- - A list of all pathfinding tunnels, with their properties
--- - The contents of the system log file
---
--- The resulting string is then logged using the `Msg` function with the "Desync" tag.
---
--- @return string A string representation of the current game state
---
function GetHashLog()
	local res = pstr("", 2 * HashLogSize * 1024 * 1024)
	
	NetGetHashLog(res)

	res:append("\n\n\n\nMap: ", GetMap())
	res:append("\nMap hash: ", tostring(mapdata.NetHash))
	res:append("\nLuaRevision: ", LuaRevision)
	res:append("\nAssetsRevision: ", AssetsRevision)
	res:append("\nPlatform: ", PlatformName())
	res:append("\nProvider: ", ProviderName())
	res:append("\nVariant: ", VariantName())
	res:append("\nPass grids hash: ", terrain.HashPassability())
	res:append("\nPass tunnels hash: ", terrain.HashPassabilityTunnels())
	res:append("\nSuspendPassEditsReasons: ", TableToLuaCode(s_SuspendPassEditsReasons))
	if Platform.developer then
		res:append("\nDisplayName: ", netDisplayName or "???")
		res:append("\nIPs: ", LocalIPs())
		res:append("\nExecutable folder: ", GetExecDirectory())
	end

	Msg("Desync", res)

	res:append("\n\nObjects:")
	local sync_objs, async_objs, tunnel_objs = {}, {}, {}
	MapForEach(true, "Object", function (obj, ignore_classes)
		if obj.handle and (not ignore_classes or not obj:IsKindOfClasses(ignore_classes)) then
			if obj:IsKindOf("PFTunnel") then
				table.insert(tunnel_objs, obj)
			elseif obj:IsSyncObject() then
				table.insert(sync_objs, obj)
			else
				table.insert(async_objs, obj)
			end
		end
	end, config.NetDesyncIgnoreClasses)

	local function HashLogCmp(obj1, obj2)
		if obj1.class ~= obj2.class then return obj1.class < obj2.class end
		local x1, y1, z1 = obj1:GetPosXYZ()
		local x2, y2, z2 = obj2:GetPosXYZ()
		if x1 ~= x2 then return x1 < x2 end
		if y1 ~= y2 then return y1 < y2 end
		if z1 ~= z2 then return (z1 or const.InvalidZ) < (z2 or const.InvalidZ) end
		local a1 = obj1:GetAngle()
		local a2 = obj2:GetAngle()
		if a1 ~= a2 then return a1 < a2 end
		local anim1 = obj1:GetStateText()
		local anim2 = obj2:GetStateText()
		if anim1 ~= anim2 then return anim1 < anim2 end
		if obj1:IsKindOf("Collection") then
			if obj1.Index ~= obj2.Index then return obj1.Index < obj2.Index end
		end
		return obj1.handle < obj2.handle
	end
	table.sort(sync_objs, HashLogCmp)
	table.sort(async_objs, HashLogCmp)

	local function HashLogCmpTunnel(obj1, obj2)
		local type1 = pf.GetTunnelType(obj1)
		local type2 = pf.GetTunnelType(obj2)
		if type1 ~= type2 then return type1 < type2 end
		if obj1.class ~= obj2.class then return obj1.class < obj2.class end
		local entrance1 = pf.GetTunnelEntrance(obj1)
		local entrance2 = pf.GetTunnelEntrance(obj2)
		if entrance1 ~= entrance2 then return entrance1 < entrance2 end
		local exit1 = pf.GetTunnelExit(obj1)
		local exit2 = pf.GetTunnelExit(obj2)
		if exit1 ~= exit2 then return exit1 < exit2 end
		local flags1 = pf.GetTunnelFlags(obj1)
		local flags2 = pf.GetTunnelFlags(obj2)
		if flags1 ~= flags2 then return flags1 < flags2 end
		local param1 = pf.GetTunnelParam(obj1)
		local param2 = pf.GetTunnelParam(obj2)
		if param1 ~= param2 then return param1 < param2 end
		return obj1.handle < obj2.handle
	end
	table.sort(tunnel_objs, HashLogCmpTunnel)

	res:append("\n\nDestlocks:")
	MapForEach(true, "Destlock", function (obj)
		local x, y, z = obj:GetPosXYZ()
		if z then
			res:appendf("\nDestlock: pos=(%d,%d,%d), radius=%d", x, y, z, obj:GetRadius())
		else
			res:appendf("\nDestlock: pos=(%d,%d), radius=%d", x, y, obj:GetRadius())
		end
	end)

	res:append("\n\nTunnels:")
	for i, obj in ipairs(tunnel_objs) do
		res:appendf("\nSH: %9d, %s, type=%d", obj.handle, obj.class, pf.GetTunnelType(obj))
		local entrance = pf.GetTunnelEntrance(obj)
		if entrance:IsValidZ() then
			res:appendf(", (%d,%d,%d)", entrance:xyz())
		else
			res:appendf(", (%d,%d)", entrance:xyz())
		end
		local exit = pf.GetTunnelExit(obj)
		if exit:IsValidZ() then
			res:appendf("->(%d,%d,%d)", exit:xyz())
		else
			res:appendf("->(%d,%d)", exit:xyz())
		end
		res:appendf(", weight=%d", pf.GetTunnelWeight(obj))
		local flags = pf.GetTunnelFlags(obj)
		if flags ~= 4294967295 then
			res:appendf(", flags=%d", flags)
		end
		local param = pf.GetTunnelParam(obj)
		if param ~= 0 then
			res:appendf(", param=%d", param)
		end
	end

	local efResting = const.efResting
	local efPathExecObstacle = const.efPathExecObstacle
	local apply_slab_flags = const.efPathSlab + const.efApplyToGrids + const.efVisible

	local function GetObjHashLog(res, obj)
		res:appendf("\nSH: %9d, %s", obj.handle, obj.class)
		if obj:IsKindOf("Collection") then
			res:appendf(", %d, %s", obj.Index, obj.Name)
		end
		if obj:IsValidPos() then
			if obj:IsValidZ() then
				res:appendf(", pos=(%d,%d,%d)", obj:GetPosXYZ())
			else
				res:appendf(", pos=(%d,%d)", obj:GetPosXYZ())
			end
			local angle = obj:GetAngle()
			if angle ~= 0 then
				res:appendf(", angle=%d", angle)
				local axisx, axisy, axisz = obj:GetAxisXYZ()
				if axisx ~= 0 or axisy ~= 0 then
					res:appendf(", axis=(%d,%d,%d)", axisx, axisy, axisz)
				end
			end
			if obj:GetCollision() then
				res:appendf(", Collision")
			end
			if obj:GetApplyToGrids() then
				res:appendf(", ApplyToGrids")
				if obj:GetEnumFlags(apply_slab_flags) == apply_slab_flags then
					res:appendf(", ApplyPFLevelPass")
				end
			end
			if obj:GetEnumFlags(efResting) ~= 0 then
				res:appendf(", efResting, destlock_radius=%d", pf.GetDestlockRadius(obj))
			end
			if obj:GetEnumFlags(efPathExecObstacle) ~= 0 then
				local r = pf.GetCollisionRadius(obj)
				if r and r > 0 then
					res:appendf(", efPathExecObstacle radius=%d", r)
				end
			end
			local destlock = obj:GetDestlock()
			if destlock and destlock:IsValidPos() then
				local x, y, z = destlock:GetPosXYZ()
				if z then
					res:appendf(", destlock_pos=(%d,%d,%d), destlock_radius=%d", x, y, z, destlock:GetRadius())
				else
					res:appendf(", destlock_pos=(%d,%d), destlock_radius=%d", x, y, destlock:GetRadius())
				end
			end
		end
		local state = obj:GetState()
		if state ~= 0 then
			res:appendf(", state=%s(%d)", GetStateName(state), state)
		end
		local command = rawget(obj, "command")
		if command then
			if type(command) == "function" then
				res:appendf(", cmd=(func)")
			else
				res:appendf(", cmd=%s", command)
			end
		end
	end

	res:append("\n\nSync Objects:")
	for i, obj in ipairs(sync_objs) do
		GetObjHashLog(res, obj)
	end
	res:append("\n\nAsync Objects:")
	for i, obj in ipairs(async_objs) do
		GetObjHashLog(res, obj)
	end

	res:append("\n\nSystem Log:")
	local err, log_file = AsyncFileToString(GetLogFile(), false, false, "lines")
	if err then
		res:append(err, "\n")
	else
		for _, line in ipairs(log_file) do
			res:append(line, "\n")
		end
	end
	return res
end


---------------------------------------------------[ Global functions ]-------------------------------------------------------

---
--- Validates an object to ensure it is a valid game object.
---
--- @param obj table The object to validate.
--- @return table|nil The validated object, or `nil` if the object is not valid.
---
function NetValidate(obj)
	return IsValid(obj) and obj.__ancestors.Object and obj.handle and obj or nil
end

---
--- Checks if the given object is a local game object.
---
--- @param obj table The object to check.
--- @return boolean True if the object is a local game object, false otherwise.
---
function NetIsLocal(obj)
	return IsValid(obj) and obj:NetState() == "local"
end

---
--- Checks if the given object is a remote game object.
---
--- @param obj table The object to check.
--- @return boolean True if the object is a remote game object, false otherwise.
---
function NetIsRemote(obj)
	return IsValid(obj) and obj:NetState() == "remote"
end

---
--- Checks if the given object is in a neutral state.
---
--- @param obj table The object to check.
--- @return boolean True if the object is in a neutral state, false otherwise.
---
function NetIsNeutral(obj)
	return IsValid(obj) and not obj:NetState()
end

---
--- Determines the interaction state between two game objects.
---
--- @param actor table The actor object.
--- @param target table The target object.
--- @return string The interaction state, which can be "local", "remote", or nil if the state cannot be determined.
---
function NetInteractionState(actor, target)
	local actor_state = IsValid(actor) and actor:NetState()
	local target_state = IsValid(target) and target:NetState()
	
	if not actor_state and not target_state and IsValid(actor) and IsValid(target) then
		-- resolve neutral interactions based on monster target (which is synced)
		actor_state = rawget(actor, "monster_target") and actor.monster_target:NetState()
		target_state = rawget(target, "monster_target") and target.monster_target:NetState()
	end
	
	if actor_state == "local" or (not actor_state and target_state == "local") then return "local" end
	if actor_state == "remote" or (not actor_state and target_state == "remote") then return "remote" end
end

---
--- Serializes the given arguments using the appropriate serialization method.
---
--- @param ... any The arguments to serialize.
--- @return string The serialized data.
---
function NetSerialize(...)
	if netSwarmSocket then
		return netSwarmSocket:Serialize(...)
	else
		return Serialize(...)
	end
end

---
--- Deserializes the given serialized data using the appropriate deserialization method.
---
--- @param ... any The serialized data to deserialize.
--- @return any The deserialized data.
---
function NetUnserialize(...)
	if netSwarmSocket then
		return netSwarmSocket:Unserialize(...)
	else
		return Unserialize(...)
	end
end

-------------------------------------------------[ Connection ]------------------------------------------------------
-- function VariantName() return "local server" end --> Uncomment to enable working with a local server on Xbox

---
--- Gets the login information for the platform's authentication provider.
---
--- @param official_connection boolean Whether this is an official connection or not.
--- @return string|nil, string|nil, table|nil, string|nil, boolean|nil The error message (if any), the authentication provider, the authentication provider data, the display name, and whether the user is a developer.
---
function PlatformGetProviderLogin(official_connection) end

---
--- Gets the login information for the platform's authentication provider.
---
--- @param official_connection boolean Whether this is an official connection or not.
--- @return string|nil, string|nil, table|nil, string|nil, boolean|nil The error message (if any), the authentication provider, the authentication provider data, the display name, and whether the user is a developer.
---
function NetGetProviderLogin(official_connection)	
	local err, auth_provider, auth_provider_data, display_name = PlatformGetProviderLogin(official_connection)
	if err then return err end
	
	local developer = false
	if not auth_provider and Platform.test and insideHG() then -- Internal testing
		display_name = tostring(sockGetHostName() or "unknown") .. "-" .. (10000 + AsyncRand(90000))
		auth_provider = "auto"
		auth_provider_data = display_name
		developer = true
	end
	return err or not auth_provider and "no account", auth_provider, auth_provider_data, display_name, developer
end

---
--- Gets the login information for the platform's authentication provider in an automatic way.
---
--- @return string|nil, string|nil, string|nil, boolean|nil The error message (if any), the authentication provider, the authentication provider data, and whether the user is a developer.
---
function NetGetAutoLogin()
	if Platform.desktop then
		return nil, "auto", GetInstallationId(), false
	end
	return "no account"
end

---
--- Gets the login information for the platform's authentication provider.
---
--- @param user string The user name.
--- @param pass string The password.
--- @return string|nil, string, table, string The error message (if any), the authentication provider, the authentication provider data, and the display name.
---
function NetGetPasswordLogin(user, pass)
	if not user or not pass then
		return "no account"
	end
	return nil, "pass", {user, pass}, user
end

---
--- Changes the password for the current user.
---
--- @param old_pass string The old password.
--- @param new_pass string The new password.
--- @param email string The email address associated with the account.
--- @return string|nil The error message, if any.
---
function NetChangePassword(old_pass, new_pass, email)
	if not netSwarmSocket then
		return "disconnected"
	end
	local err = netSwarmSocket:Call("rfnChangePassword", old_pass, new_pass, email)
	if not err then
		Msg("PasswordChanged", old_pass, new_pass, email)
	end
	return err
end

-- possble errors:
--  "version" - client is too old (LuaRevision)
--  "not ready" - server is there but not accepting connections (starting, etc.)
--  "maintenance" - server is there but in maintenance and not accepting connections
--  "redirect", host, port - redirect to the proper server for this user name (handled internally)
--  "failed" - no such user or wrong password
--  "banned" - the account is banned; optionally the global var 'netBannedReason' is (exploit|abuse|pirate|bot), optional netBannedPeriod is seconds until ban is lifted (otherwise forever)
--  other - cannot establish connection
local checksum, timestamp
---
--- Logs in to the game server using the provided authentication information.
---
--- @param socket NetCloudSocket The socket to use for the connection.
--- @param host string The host address of the game server.
--- @param port number The port of the game server.
--- @param auth_provider string The authentication provider to use.
--- @param auth_provider_data table The authentication provider data.
--- @return string|nil, string, boolean, string The error message (if any), the account ID, whether the account is restricted, and the environment.
---
function NetLogin(socket, host, port, auth_provider, auth_provider_data)
	local err, signed_key, aes_key, aes_iv, token
	local dlcs = GetAvailableDlcList()
	local id = GetInstallationId()
	if not checksum and rawget(_G, "ExeChecksumAndTimestamp") then
		checksum, timestamp = ExeChecksumAndTimestamp()
	end

	-- see if the last connection was to the same place and if it was redirected somewhere else
	err = "disconnected"
	socket:Disconnect()
	if rawget(_G, "AccountStorage") and AccountStorage.NetLastHost == host and 
		AccountStorage.NetLastPort == port and 
		AccountStorage.NetRedirectedHost and 
		AccountStorage.NetRedirectedPort
	then
		err = socket:WaitConnect(10000, AccountStorage.NetRedirectedHost, AccountStorage.NetRedirectedPort)
		if err then
			AccountStorage.NetRedirectedHost = nil
			AccountStorage.NetRedirectedPort = nil
		end
	end
	if err then
		err = socket:WaitConnect(10000, host, port)
	end
	if err then return err end

	if not signed_key then
		err, aes_key, aes_iv, signed_key = socket:GenRSAEncryptedKey(GetSwarmPublicKey(host), 0)
		if err then return "sign" end
	end
	err, token = socket:Call("rfnConn", LuaRevision, signed_key, auth_provider, config.SwarmWorld, PlatformName(), ProviderName(), VariantName())
	if err then return err end
	socket:SetAESEncryptionKey(aes_key, aes_iv)
	socket:SetOption("encrypt", true)
	local err, r2, r3, r4, r5 = socket:Call("rfnAuth", token, auth_provider_data, id, GetLanguage(), os.time(), dlcs, checksum, timestamp)
	if err == "redirect" and r2 and r3 then
		socket:Disconnect()
		err = socket:WaitConnect(10000, r2, r3)
		if not err and rawget(_G, "AccountStorage") then
			AccountStorage.NetLastHost = host
			AccountStorage.NetLastPort = port
			AccountStorage.NetRedirectedHost = r2
			AccountStorage.NetRedirectedPort = r3
			SaveAccountStorage(3000)
		end
		if not err then
			err, token = socket:Call("rfnConn", LuaRevision, signed_key, auth_provider, config.SwarmWorld, PlatformName(), ProviderName(), VariantName())
			if err then return err end
			socket:SetAESEncryptionKey(aes_key, aes_iv)
			socket:SetOption("encrypt", true)
			err, r2, r3, r4, r5 = socket:Call("rfnAuth", token, auth_provider_data, id, GetLanguage(), os.time(), dlcs, checksum, timestamp)
			assert(err ~= "redirect") -- we should not be redirected twice
		end
	end
	if err == "banned" then
		netBannedReason = r2 or false
		netBannedPeriod = r3 or false
	end
	return err, r2, r3, r4, r5
end

local checksum, timestamp
---
--- Connects to the Swarm network and performs authentication.
---
--- @param host string The host to connect to.
--- @param port number The port to connect to.
--- @param auth_provider string The authentication provider to use.
--- @param auth_provider_data any The authentication provider data.
--- @param display_name string The display name to use.
--- @param check_updates boolean Whether to check for updates.
--- @param reason any The reason for the connection.
--- @return string|nil The error message, or nil on success.
function NetConnect(host, port, auth_provider, auth_provider_data, display_name, check_updates, reason)
	netConnectionReasons[reason or true] = true
	if netSwarmSocket then return end
	netConnectThread = netConnectThread or CreateRealTimeThread(function()
		local socket = NetCloudSocket:new()
		local err, account_id, restricted_account, environment = NetLogin(socket, host, port, auth_provider, auth_provider_data)
		if netConnectThread ~= CurrentThread() then err = "cancelled" end
		if err then
			socket:delete()
		else
			assert(not netSwarmSocket, "Finished connecting while already connected!")
			netSwarmSocket = socket
			netDisplayName = display_name or false
			netAuthProvider = auth_provider or false
			netAccountId = account_id or false
			netInGame = false
			netAllowGossip = config.NetGossip or false
			netRestrictedAccount = restricted_account or false
			netEnvironment = environment or false

			local update_def, description
			err, update_def, description = socket:Call("rfnUpdate", check_updates)
			Msg("NetConnect")
			if update_def then
				Msg("ContentUpdate", update_def, description)
			end
		end
		if netConnectThread == CurrentThread() then
			netConnectThread = false
		else
			err = "cancelled"
		end
		Msg(CurrentThread(), err)
	end)
	local ok, err = WaitMsg(netConnectThread)
	if err and err ~= "cancelled" then
		NetDisconnect(reason)
	end
	return err
end

--- Checks if the network connection is currently active.
---
--- @return boolean true if the network connection is active, false otherwise
function NetIsConnected()
	return netSwarmSocket and netSwarmSocket:IsConnected()
end

--- Disconnects the network connection if there are no more active reasons for the connection.
---
--- @param reason any The reason for the disconnection.
--- @param msg string An optional message to include with the disconnection.
function NetDisconnect(reason, msg)
	reason = reason or true
	if netConnectionReasons[reason] then
		netConnectionReasons[reason] = nil
		if next(netConnectionReasons) == nil then
			NetForceDisconnect(msg)
		end
	end
end

--- Forces a network disconnection, clearing all connection reasons and leaving any active game.
---
--- @param msg string An optional message to include with the disconnection.
function NetForceDisconnect(msg)
	netConnectionReasons = {}
	netConnectThread = false
	local socket = netSwarmSocket
	if not socket then
		return "disconnected"
	end
	
	local currGame = netInGame
	NetLeaveGame(msg)
	
	netSwarmSocket = false
	netDisplayName = false
	netAuthProvider = false
	
	socket:delete()
	Msg("NetDisconnect", msg, currGame)
end


----- Game

function NetCreateGame(game_type, browser, name, visible_to, info, max_players)
	local err, game_id = NetCall("rfnCreateGame", game_type, browser, name, visible_to, info, max_players)
	if err then return err end	
	return err, game_id
end

--- Joins a network game.
---
--- @param game_type string The type of the game to join.
--- @param game_id number|string The ID or name of the game to join.
--- @param predef_unique_id number An optional predefined unique ID for the player.
--- @return string|false An error message if an error occurred, or false if the join was successful.
--- @return number The unique ID of the player in the game.
function NetJoinGame(game_type, game_id, predef_unique_id)
	if not netSwarmSocket then
		return "disconnected"
	end
	NetLeaveGame("NetJoinGame")
	Msg("NetJoinGameStart", game_type, game_id, predef_unique_id)
	local err, unique_id, seed, game_address, game_info, player_info, max_players
	if not game_type and type(game_id) == "number" then -- game_id is game_address
		err, unique_id, seed, game_address, game_info, player_info, max_players = netSwarmSocket:Call("rfnJoinGame", game_id, predef_unique_id)
	else
		err, unique_id, seed, game_address, game_info, player_info, max_players = netSwarmSocket:Call("rfnJoinGameByName", game_type, game_id, predef_unique_id)
	end
	if err then return err end
	netInGame = true
	netUniqueId = unique_id
	netGameSeed = seed
	netDesync = false
	netGameAddress = game_address
	netGameInfo = game_info or {}
	netGamePlayers = player_info
	netGameMaxPlayers = max_players or netGameMaxPlayers
	Msg("NetGameJoined", game_id, unique_id)
	return false, unique_id
end

---
--- Leaves the current network game.
---
--- @param reason string The reason for leaving the game.
---
function NetLeaveGame(reason)
	if netInGame then
		netInGame = false
		Msg("NetGameLeft", reason, netGameInfo)
		NetSend("rfnLeaveGame", reason)
	end	
	netBufferedEvents = false
	netUniqueId = 1
	netGameSeed = 0
	netGamePlayers = {}
	netGameAddress = false
	netGameInfo = {}
end

---
--- Checks if the current player is the host of the network game.
---
--- @param id number|nil The player ID to check. If not provided, the current player's ID is used.
--- @return boolean True if the current player is the host, false otherwise.
---
function NetIsHost(id) -- in a network game and being with index 1
	return netInGame and (id or netUniqueId) == 1
end

---
--- Updates the game information in the current network game.
---
--- @param info table The updated game information.
---
function NetCloudSocket:rfnGameInfo(info)
	for k, v in pairs(info) do
		netGameInfo[k] = v
	end
	Msg("NetGameInfo", info)
end

---
--- Updates the game information in the current network game.
---
--- @param info table The updated game information.
---
function NetChangeGameInfo(info)
	return NetGameSend("rfnGameInfo", info)
end

function OnMsg.NetDisconnect()
	NetLeaveGame("disconnect")
end

---
--- Searches for available network games.
---
--- @param browser string The game browser to use for the search.
--- @param name string The name to search for.
--- @param friend_games boolean Whether to search for friend games only.
--- @param func function A callback function to be called for each game found.
--- @param ... any Additional arguments to pass to the callback function.
--- @return string|nil An error message if an error occurred, or nil if the search was successful.
--- @return table A table of game information, where each entry is a table with the following fields:
---   - address: string The address of the game.
---   - name: string The name of the game.
---   - visibility: string The visibility of the game.
---   - players: number The number of players in the game.
---   - max_players: number The maximum number of players in the game.
---   - info: table Additional game information.
---
function NetSearchGames(browser, name, friend_games, func, ...)
	local err, games = NetCall("rfnSearchGames", browser, name, friend_games, func, ...)
	if err then return err end
	-- convert to a more friendly format
	for i, game in ipairs(games) do
		games[i] = {
			address = game[1],
			name = game[2],
			visibility = game[3],
			players = game[4],
			max_players = game[5],
			info = game[6],
		}
	end
	return nil, games
end


----- Content

---
--- Creates a content definition for a file.
---
--- @param filename string The filename of the content.
--- @param chunk_size number The size of each chunk of the content.
--- @return string|nil An error message if an error occurred, or nil if the content definition was created successfully.
--- @return table The content definition, with the following fields:
---   - name: string The name of the content.
---   - chunk_size: number The size of each chunk of the content.
---   - size: number The total size of the content.
---   - timestamp: number The timestamp of the content.
---   - [1..n]: string The hash of each chunk of the content.
---
function CreateContentDef(filename, chunk_size)
	if not filename then return "params" end
	local def = {}
	local dir, file, ext = SplitPath(filename)
	local name = file .. ext
	def.name = ext == ".bin" and file or name
	chunk_size = chunk_size or config.OnlineContentChunkSize or 512*1024
	def.chunk_size = chunk_size
	local err, size = AsyncGetFileAttribute(filename, "size")
	if err then return err end
	local err, timestamp = AsyncGetFileAttribute(filename, "timestamp")
	if err then return err end
	def.size = size
	def.timestamp = timestamp
	for offset = 0, size, chunk_size do
		local err, hash = AsyncFileToString(filename, Min(chunk_size, size - offset), offset, "hash32", "raw")
		if err then return err end
		def[#def + 1] = hash
	end
	return nil, def
end

---
--- Handles the receipt of a content chunk from the network.
---
--- @param name string The name of the content being downloaded.
--- @param i number The index of the chunk being received.
--- @param chunk string The data of the chunk.
---
function NetCloudSocket:rfnContentChunk(name, i, chunk)
	Msg(string.format("ContentChunk-%s-%d", name, i), chunk)
end

---
--- Downloads content from the network and saves it to a local file.
---
--- @param filename string The filename to save the content to.
--- @param def table|string The content definition, or the name of the content definition to retrieve from the network.
--- @param progress function|nil A callback function to receive progress updates. The callback will be called with three arguments: the current offset, the total size, and the name of the content.
--- @param local_def table|nil The local content definition, if it is already known.
--- @return string|nil An error message if an error occurred, or nil if the download was successful.
function NetDownloadContent(filename, def, progress, local_def)
	if not NetIsConnected() then return "disconnected" end
	local err
	if type(def) == "string" then
		err, def = NetCall("rfnGetContentDef", def)
		if err then return err end
	end
	if not local_def then
		err, local_def = CreateContentDef(filename, def.chunk_size)
		local_def = local_def or { size = 0 }
	end
	if local_def.size > def.size then
		AsyncFileDelete(filename) -- we cannot truncate the file so we delete it
	end
	for offset = 0, def.size, def.chunk_size do
		local i = 1 + offset / def.chunk_size
		if progress then progress(offset, def.size, def.name) end
		if local_def[i] ~= def[i] then
			err = NetSend("rfnGetContentChunk", def.name, i)
			if err then return err end
			local ok, chunk = WaitMsg(string.format("ContentChunk-%s-%d", def.name, i), 30000)
			if not ok then return "timeout" end
			if chunk then
				err = AsyncStringToFile(filename, chunk, offset, def.timestamp)
				chunk:free()
				if err then return err end
			end
		end
	end
	if progress then progress(def.size, def.size, def.name) end
	return err
end

-----------------------------------------------[ Registration, etc. ]------------------------------------------

local function LoginSystemAccount(timeout, host, port)
	local conn = MessageSocket:new()
	local err = NetLogin(conn, host, port, "*register", "public")
	if err then conn:delete() end
	return err, conn
end

---
--- Registers a new user account with the given username, password, serial number, and email.
---
--- @param timeout number The maximum time to wait for the registration to complete, in milliseconds.
--- @param host string The hostname or IP address of the server to connect to.
--- @param port number The port number of the server to connect to.
--- @param username string The username for the new account.
--- @param password string The password for the new account.
--- @param serial string The serial number for the new account.
--- @param email string The email address for the new account.
--- @return string|nil An error message if an error occurred, or nil if the registration was successful.
function WaitRegister(timeout, host, port, username, password, serial, email)
	if not username or not password then return "bad param" end
	local err, sys_account = LoginSystemAccount(timeout, host, port)
	if err then return err end
	err = sys_account:Call("rfnRegister", username, password, serial, email)
	sys_account:Disconnect()
	return err
end

-- this works only if the serial number used to create the account is provided
---
--- Changes the password for the given user account.
---
--- @param timeout number The maximum time to wait for the password change to complete, in milliseconds.
--- @param host string The hostname or IP address of the server to connect to.
--- @param port number The port number of the server to connect to.
--- @param username string The username for the account.
--- @param password string The new password for the account.
--- @param serial string The serial number for the account.
--- @param email string The email address for the account.
--- @return string|nil An error message if an error occurred, or nil if the password change was successful.
function WaitChangePassword(timeout, host, port, username, password, serial, email)
	if not username or not password or not serial then return "bad param" end
	local err, sys_account = LoginSystemAccount(timeout, host, port)
	if err then return err end
	err = sys_account:Call("rfnChangePassword", username, password, serial, email)
	sys_account:Disconnect()
	return err
end

---
--- Checks if the given serial number is valid.
---
--- @param timeout number The maximum time to wait for the check to complete, in milliseconds.
--- @param host string The hostname or IP address of the server to connect to.
--- @param port number The port number of the server to connect to.
--- @param serial string The serial number to check.
--- @return string|nil An error message if an error occurred, or nil if the serial number is valid.
function WaitCheckSerial(timeout, host, port, serial)
	if not serial then return "bad param" end
	local err, sys_account = LoginSystemAccount(timeout, host, port)
	if err then return err end
	err = sys_account:Call("rfnCheckSerial", serial)
	sys_account:Disconnect()
	return err
end

-------------------------------------------------[ NetSend/NetCall ]---------------------------------------------

---
--- Sends a message over the network.
---
--- @param ... any The arguments to send over the network.
--- @return string|nil An error message if an error occurred, or nil if the message was sent successfully.
function NetSend(...)
	if not netSwarmSocket then return "disconnected" end
	return netSwarmSocket:Send(...)
end

---
--- Calls a remote function over the network.
---
--- @param ... any The arguments to pass to the remote function.
--- @return any The return value(s) of the remote function, or an error message if an error occurred.
function NetCall(...)
	if not netSwarmSocket then return "disconnected" end
	return netSwarmSocket:Call(...)
end 

---
--- Sends a game-related message over the network.
---
--- @param ... any The arguments to send over the network.
--- @return string|nil An error message if an error occurred, or nil if the message was sent successfully.
function NetGameSend(...)
	if not netSwarmSocket then return "disconnected" end
	if not netInGame then return "not in game" end
	return netSwarmSocket:Send("rfnGameSend", ...)
end

---
--- Calls a remote game-related function over the network.
---
--- @param ... any The arguments to pass to the remote function.
--- @return any The return value(s) of the remote function, or an error message if an error occurred.
function NetGameCall(...)
	if not netSwarmSocket then return "disconnected" end
	if not netInGame then return "not in game" end
	return netSwarmSocket:Call("rfnGameCall", ...)
end

---
--- Broadcasts a game-related message over the network to all connected clients.
---
--- @param ... any The arguments to send over the network.
--- @return string|nil An error message if an error occurred, or nil if the message was sent successfully.
function NetGameBroadcast(...)
	if not netSwarmSocket then return "disconnected" end
	if not netInGame then return "not in game" end
	return netSwarmSocket:Send("rfnGameSend", "rfnBroadcast", ...)
end

---
--- Sends a compressed log message over the network.
---
--- @param class string The class or category of the log message.
--- @param filename string The name of the file where the log message originated.
--- @param ext string The file extension of the file where the log message originated.
--- @param data any The data to be logged, which will be compressed before sending.
--- @return string|nil An error message if an error occurred, or nil if the message was sent successfully.
function NetLogFile(class, filename, ext, data)
	if data then
		local compressed_data = CompressPstr(data)
		local err = NetCall("rfnLog", class, filename, ext, compressed_data)
		compressed_data:free()
		return err
	end
end

-------------------------------------------------[ Events ]------------------------------------------------------

if FirstLoad then
	NetStats = {
		events_received = 0,
		events_sent = 0,
		events_received_ps = 0,
		events_sent_ps = 0,
	}
end

---
--- Calculates the delay for sending a network event based on the configured lag simulation settings.
---
--- @return number The delay in seconds to wait before sending the network event.
function GetLagEventDelay()
	if netSimulateLagAvg == 0 then
		return 0
	end
	local real_time = RealTime()
	local send_time = Max(netSimulateLagLastTime, real_time + netSimulateLagAvg + AsyncRand(2 * netSimulateLagAmp) - netSimulateLagAmp)
	return send_time - real_time
end

---
--- Sends a network event with the given type and parameters.
---
--- @param type string The type of the network event to send.
--- @param event string The name of the network event to send.
--- @param ... any The parameters to send with the network event.
--- @return string|nil An error message if an error occurred, or nil if the event was sent successfully.
function SendEvent(type, event, ...)
	local params, err = SerializePstr(...)
	
	if not params then
		assert(false, "Network serialization error: " .. tostring(err))
		return err
	end
	
	local compressed = CompressPstr(params)
	if #params > #compressed + 1 then
		-- string.char(255) is unused by the serialization, so it is safe to use as marker
		params:clear()
		params:append(string.char(255), compressed)
	end
	
	if netSimulateLagAvg > 0 then
		local socket = netSwarmSocket
		local lag_delay = GetLagEventDelay()
		CreateRealTimeThread(function()
			Sleep(lag_delay)
			socket:Send("rfnGameSend", type, event, params)
		end)
		return
	end
	
	return netSwarmSocket:Send("rfnGameSend", type, event, params)
end

---
--- Sends a network event with the given type and parameters.
---
--- @param event string The name of the network event to send.
--- @param ... any The parameters to send with the network event.
--- @return nil
function NetEvent(event, ...)
	assert(NetEvents[event])
	NetStats.events_sent = NetStats.events_sent + 1
	if netInGame then
		return SendEvent("rfnEvent", event, ...)
	end
end

---
--- Sends a network event with the given type and parameters, but only if the game is currently in progress.
---
--- @param event string The name of the network event to send.
--- @param ... any The parameters to send with the network event.
--- @return nil
function NetEchoEvent(event, ...)
	assert(NetEvents[event])
	if netInGame then
		return SendEvent("rfnEchoEvent", event, ...)
	else
		if netBufferedEvents then
			local params, err = SerializePstr(...)
			
			if not params then
				assert(false, "Network serialization error: " .. tostring(err))
				return err
			end
			
			netBufferedEvents[#netBufferedEvents + 1] = pack_params(event, params)
			return
		end
		local handler = NetEvents[event]
		if handler then
			handler(...)
		end
	end
end

---
--- Broadcasts a network event with the given type and parameters, but only if the game is currently in progress.
---
--- @param event string The name of the network event to broadcast.
--- @param ... any The parameters to send with the network event.
--- @return nil
function NetBroadcastEvent(event, ...)
	if netInGame then
		return SendEvent("rfnBroadcast", event, ...)
	end
end

---
--- Processes any missing handles that may have occurred during the execution of a network event.
---
--- @param event string The name of the network event that was received.
--- @param params any The parameters that were received with the network event.
---
function ProcessMissingHandles(event, params)
end


---
--- Handles the receipt of a network event from the cloud socket.
---
--- @param event string The name of the network event received.
--- @param params string The serialized parameters of the network event.
---
function NetCloudSocket:rfnEvent(event, params)
	if params:byte(1) == 255 then
		params = DecompressPstr(params, 2)
	end
	if netBufferedEvents then
		netBufferedEvents[#netBufferedEvents + 1] = pack_params(event, params)
		return
	end
	NetStats.events_received = NetStats.events_received + 1
	local handler = NetEvents[event]
	if handler then
		handler(Unserialize(params))
		ProcessMissingHandles(event, params)
	end
end

---
--- Starts buffering network events to be processed later.
---
--- This function initializes an empty table to store buffered network events.
---
--- @function NetStartBufferEvents
--- @return nil
function NetStartBufferEvents()
	netBufferedEvents = {}
end

---
--- Stops buffering network events and processes any buffered events.
---
--- This function first checks if there are any buffered events. If so, it sets `netBufferedEvents` to `false` to indicate that buffering has stopped.
--- It then iterates through the buffered events and processes them by calling the appropriate `rfnEvent` function on either `netSwarmSocket` or `NetCloudSocket`.
---
--- @function NetStopBufferEvents
--- @return nil
function NetStopBufferEvents()
	local events = netBufferedEvents
	if events then
		netBufferedEvents = false
		if netSwarmSocket then
			for i=1,#events do
				procall(netSwarmSocket.rfnEvent, netSwarmSocket, unpack_params(events[i]))
			end
		else
			for i=1,#events do
				procall(NetCloudSocket.rfnEvent, nil, unpack_params(events[i]))
			end
		end
	end
end

function OnMsg.NetConnect()
	CreateRealTimeThread(function()
		local lastSent, lastReceived = NetStats.events_sent, NetStats.events_received
		while netSwarmSocket do
			Sleep(1000)
			NetStats.events_sent_ps = NetStats.events_sent - lastSent
			lastSent = NetStats.events_sent
			NetStats.events_received_ps = NetStats.events_received - lastReceived
			lastReceived = NetStats.events_received
			Msg("NetStats")
		end
	end)
end

-------------------------------------------------[ Players ]------------------------------------------------------

---
--- Updates the player's information in the current online game.
---
--- This function checks if the player is currently in an online game. If so, it compares the provided `info` table with the player's current information in `netGamePlayers`. Any keys in `info` that have the same value as the player's current information are removed from `info`. If `info` is not empty after this process, the function calls `NetGameCall("rfnPlayerInfo", info)` to update the player's information on the server.
---
--- @param info table The updated player information to be sent to the server.
--- @return string|nil Returns "not in game" if the player is not currently in an online game, otherwise returns the result of `NetGameCall("rfnPlayerInfo", info)`.
---
function NetChangePlayerInfo(info)
	if not netInGame then return "not in game" end
	local player_info = netGamePlayers[netUniqueId]
	for k, v in pairs(info) do
		if player_info[k] == v then
			info[k] = nil
		end
	end
	if next(info) == nil then return end
	return NetGameCall("rfnPlayerInfo", info)
end

---
--- Updates the player's information in the current online game.
---
--- This function is called when the server sends updated player information. It updates the local `netGamePlayers` table with the new information provided in the `info` table. The function first checks if the player is known (exists in `netGamePlayers`), and if so, it updates the player's information by copying the keys and values from `info` to the player's entry in `netGamePlayers`. Finally, it sends a "NetPlayerInfo" message with the updated player information.
---
--- @param unique_id string The unique identifier of the player whose information is being updated.
--- @param info table The updated player information to be applied.
---
function NetCloudSocket:rfnPlayerInfo(unique_id, info)
	local player = netGamePlayers[unique_id]
	assert(player, "rfnPlayerInfo for unknown player " .. tostring(unique_id) .. " (did he just leave?)")
	if not player then return end
	for k, v in pairs(info) do
		player[k] = v
	end
	Msg("NetPlayerInfo", player, info)
end

---
--- Handles a player joining the current online game.
---
--- This function is called when the server notifies the client that a new player has joined the game. It updates the `netGamePlayers` table with the new player's information, and sends a "NetPlayerJoin" message with the updated player information.
---
--- @param info table The player information for the new player who has joined the game.
---
function NetCloudSocket:rfnPlayerJoin(info)
	if not netInGame then return end -- this is us joining the game which we receive before the join completes
	netGamePlayers[info.id] = info
	Msg("NetPlayerJoin", info)
end

---
--- Handles a player leaving the current online game.
---
--- This function is called when the server notifies the client that a player has left the game. It removes the player's information from the `netGamePlayers` table, and if the player who left is the local player, it calls `NetLeaveGame` with the provided `reason`. If the player who left is not the local player, it sends a "NetPlayerLeft" message with the player's information and the reason for leaving.
---
--- @param unique_id string The unique identifier of the player who has left the game.
--- @param reason string The reason for the player leaving the game.
---
function NetCloudSocket:rfnPlayerLeft(unique_id, reason)
	unique_id = unique_id or netUniqueId
	local player = netGamePlayers[unique_id]
	netGamePlayers[unique_id] = nil
	if unique_id == netUniqueId then
		NetLeaveGame(reason)
	else
		if player then
			Msg("NetPlayerLeft", player, reason)
		end
	end
end

---
--- Checks if a player with the given account ID is currently in the online game.
---
--- @param account_id string The account ID of the player to check.
--- @return boolean true if the player is in the game, false otherwise.
---
function IsInOnlineGame(account_id)
	for k, v in pairs(netGamePlayers) do
		if v.account_id == account_id then
			return true
		end
	end
end

-------------------------------------------------[ Keep Alive ]------------------------------------------------------

if FirstLoad then
	netKeepAliveThread = false
end

function OnMsg.NetConnect()
	assert(not netKeepAliveThread)
	-- this thread keeps the OnlineGame object alive (besides measuring ping)
	netKeepAliveThread = CreateRealTimeThread(function()
		local keep_alive_time = config.SwarmKeepAliveTime or 10 * 1000
		while true do
			local time = RealTime()
			local err = NetCall("rfnPing")
			time = RealTime() - time
			netSwarmPing = time
			Msg("NetPing", time)
			if err then
				NetForceDisconnect(true)
				break
			end
			Sleep(keep_alive_time)
		end
	end)
end

function OnMsg.NetDisconnect()
	if netKeepAliveThread ~= CurrentThread() then
		DeleteThread(netKeepAliveThread)
	end
	netKeepAliveThread = false
end


----

---
--- Checks if the current code is running in an asynchronous context.
---
--- @return boolean true if the code is running asynchronously, false otherwise.
---
function IsAsyncCode()
	return Libs.Network ~= "sync" or not IsGameTimeThread()
end

if FirstLoad then
	PauseDesyncErrorsReasons = {}
end

---
--- Suspends error reporting for desync errors with the given reason.
---
--- @param reason string The reason for suspending desync error reporting.
---
function SuspendDesyncErrors(reason)
	PauseDesyncErrorsReasons[reason] = true
end

---
--- Resumes error reporting for desync errors with the given reason.
---
--- @param reason string The reason for resuming desync error reporting.
---
function ResumeDesyncErrors(reason)
	PauseDesyncErrorsReasons[reason] = nil
end

---
--- Checks if desync error reporting is currently ignored.
---
--- @return boolean true if desync error reporting is ignored, false otherwise.
---
function IsDesyncIgnored()
	return next(PauseDesyncErrorsReasons)
end

-------------------------------------------------[ Gossip ]------------------------------------------------------

---
--- Sends a gossip message over the network.
---
--- @param gossip table The gossip message to send.
--- @param ... any Additional arguments to pass to the gossip message.
---
--- @return boolean|string True if the gossip message was sent successfully, or an error message if it failed.
---
function NetGossip(gossip, ...)
	if gossip and netAllowGossip then
		--LogGossip(TupleToLuaCodePStr(gossip, ...))
		return NetSend("rfnGossip", gossip, ...)
	end
end

-------------------------------------------------[ Tickets ]------------------------------------------------------

---
--- Uses a ticket to perform some network operation.
---
--- @param ticket string The ticket to use.
--- @return string|nil An error message if the operation failed, or nil if it succeeded. If successful, the decompressed data is returned as the second return value.
---
function NetUseTicket(ticket)
	if not utf8.IsStrMoniker(ticket, 3, 60) then
		return "not found"
	end
	local err, data = NetCall("rfnUseTicket", ticket)
	if err then return err, data end
	if type(ticket) == "string" then
		g_UsedTickets[#g_UsedTickets + 1] = string.upper(ticket)
	end
	return nil, Decompress(data)
end

-------------------------------------------------[ Net map utilities ]------------------------------------------------------

---
--- Creates a temporary network object.
---
--- @param o table The object to make temporary.
---
function NetTempObject(o)
end

---
--- Handles the assignment of a network handle.
---
--- @param handle string The network handle that was assigned.
---
function OnHandleAssigned(handle)
end


----------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------[ Debug ]------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------

---
--- Finds and reports any errors in the serialization process.
---
function FindSerializeError()
end

---
--- Decompresses, verifies the signature, and executes a function from the provided data.
---
--- @param data string The compressed data to decompress and execute.
--- @param signature string The signature to verify the data with.
--- @return string|nil An error message if the operation failed, or nil if it succeeded. If successful, the result of executing the function is returned as the second return value.
---
function NetCloudSocket:rfnPatch(data, signature)
	data = Decompress(data)
	if not data then return "bad data" end
	
	local err = CheckSignature(data, signature, config.PatchPublicKey)
	if err then return err end
	
	local func, err = load(data)
	if not func then
		return "bad func"
	end
	return func(self)
end

function OnMsg.BugReportStart(print_func)
	if not netSwarmSocket or not netInGame then
		return
	end
	print_func("Multiplayer:")
	print_func("\tGame Name:", netInGame)
	print_func("\tPlayer Name:", netDisplayName)
	print_func("\tUnique Id:", netUniqueId)
	print_func("\tPlayers Count:", table.count(netGamePlayers))
	print_func("\tNetwork Ping:", netSwarmPing)
	print_func("\tDesync:", netDesync)
	print_func("")
end

if Platform.developer then
	function StartInGameServer(swarm_port)
		if not config.InGameServer then
			print("Local server disabled")
			return
		end
		local server_props = {
			ip = nil,
			port = swarm_port or 1000,
			storage_dir = config.InGameServerStorage or false,
			swarm = "locahost",
			swarm_port = swarm_port or 1000,
		}
		StopLocalServer()
		local err = StartLocalServer(server_props, 10000)
		if err then
			print("Failed to start a local server:", err)
			return err
		end
		WaitLocalServer()
	end
end

--------- Voice chat

-- mute/unmute player
---
--- Mutes or unmutes a player in the current game session.
---
--- @param player_account_id string The account ID of the player to mute or unmute.
--- @param value boolean|nil If provided, sets the mute state of the player. If not provided, removes the mute state.
--- @return string|nil Returns "not in game" if the player is not in a game session, otherwise returns the result of `NetChangePlayerInfo`.
---
function NetVoiceSetPlayerMute(player_account_id, value)
	if not netInGame then return "not in game" end
	local player_info = netGamePlayers[netUniqueId]
	local mute = player_info and player_info.mute and table.copy(player_info.mute) or {}
	mute[player_account_id] = value or nil
	return NetChangePlayerInfo({mute = mute})
end

---
--- Gets the mute state of a player in the current game session.
---
--- @param player_account_id string The account ID of the player to check the mute state for.
--- @return boolean|nil Returns true if the player is muted, nil if the player is not in the game session.
---
function NetVoiceGetPlayerMute(player_account_id)
	if not netInGame then return end
	local player_info = netGamePlayers[netUniqueId]
	local mute = player_info and player_info.mute or {}
	return mute and mute[player_account_id] and true
end

-- Join a voice channel
-- Typically the channel is the platform name: NetVoiceSetChannel(PlatformName())
-- Set the voice channel to false to stop sending data and participate in chat
---
--- Sets the voice chat channel for the current player.
---
--- @param channel string|false The voice chat channel to set, or false to stop sending voice data.
--- @return string|nil Returns the result of `NetChangePlayerInfo`.
---
function NetVoiceSetChannel(channel)
	return NetChangePlayerInfo({voice = channel or false})
end

---
--- Updates the voice chat state for the current player in the game session.
---
--- This function checks the current game session and player state to determine if voice chat should be enabled or disabled for the player.
--- If the player is in a game session, voice chat is enabled, and the player's voice channel is set, the function checks if there are any other players in the same voice channel that are not muted. If so, it sets `config.ProcessSendVoice` to true, indicating that the player should start sending voice data.
--- If the conditions for sending voice data are not met, `config.ProcessSendVoice` is set to false.
---
--- @param options table|nil Optional table of options, including a `SteamVoiceChat` field to override the default Steam voice chat setting.
---
function NetVoiceUpdate(options)
	local steam_option
	if Platform.steam then
		if options then
			steam_option = options.SteamVoiceChat
		else
			steam_option = GetAccountStorageOptionValue("SteamVoiceChat")
		end
	end
	if netInGame and config.EnableVoiceChat and (not Platform.steam or steam_option) then
		local player_info = netGamePlayers and netGamePlayers[netUniqueId or false]
		local voice_channel = player_info and player_info.voice
		local account_id = player_info and player_info.account_id
		if voice_channel then
			for _, info in pairs(netGamePlayers) do
				if player_info ~= info and info.voice == voice_channel and (not info.mute or not info.mute[account_id]) then
					config.ProcessSendVoice = true
					return
				end
			end
		end
	end
	config.ProcessSendVoice = false
end

function OnMsg.NetPlayerInfo(player, info)
	NetVoiceUpdate()
end

function OnMsg.NetGameLeft()
	NetVoiceUpdate()
end

function OnMsg.NetGameJoined(game_id, unique_id)
	CreateRealTimeThread(function()
		local channel = Platform.steam and "steam" or Platform.ps4 and "ps4"
		if channel then
			NetVoiceSetChannel(channel)
			NetVoiceUpdate()
		end
	end)
end

---
--- Sends a voice packet over the network.
---
--- @param data table The voice data to send.
--- @param ... any Additional arguments to pass to the `rfnVoicePacket` function.
--- @return boolean True if the voice packet was sent successfully, false otherwise.
---
function NetVoicePacket(data, ...)
	return NetGameSend("rfnVoicePacket", data, PlatformName(), ...)
end

---
--- Handles the receipt of a voice packet over the network.
---
--- @param player_id number The ID of the player who sent the voice packet.
--- @param data table The voice data received.
--- @param ... any Additional arguments passed to the function.
---
function NetCloudSocket:rfnVoicePacket(player_id, data, platform, ...)
	if platform == PlatformName() then
		ProcessReceivedVoice(player_id, data, ...)
	end
end

if Platform.developer then

function OnMsg.NetPlayerJoin(player)
	printf("Player %s join (%d)", Literal(tostring(player.name)), player.id)
end

function OnMsg.NetPlayerLeft(player, reason)
	printf("Player %s left (%s)", Literal(tostring(player.name)), Literal(tostring(reason)))
end

function OnMsg.NetPlayerInfo(player, info)
	printf("Player %s info '%s'", Literal(tostring(player.name)), Literal(print_format(info)))
end


if FirstLoad then
	__a, __b, __diff = false,false,false
end

---
--- Finds any serialization errors by comparing the original data with the unserialized data.
---
--- @param serialized_data string The serialized data to check, or nil to serialize the provided data.
--- @param ... any The data to serialize and compare.
--- @return number The number of differences found between the original and unserialized data, or nil if there were no differences.
---
function FindSerializeError(serialized_data, ...)
	serialized_data = serialized_data or NetSerialize(...)
	local original_data = {...}
	local unserialized_data = {NetUnserialize(serialized_data)}
	if not compare(original_data, unserialized_data, nil, true) then
		__a = original_data
		__b = unserialized_data
		__diff = {}
		GetDeepDiff(original_data, unserialized_data, __diff)
		return #__diff
	end
end

MapVar("__net_event_counters", {})
MapVar("__net_event_counter_thread", false)
	
---
--- Monitors the net event counters and prints the total count at a given interval.
---
--- @param interval number The interval in milliseconds at which to print the net event counters.
---
function MonitorNetSync(interval)
	interval = interval and interval > 0 and interval or 1000

	if __net_event_counter_thread then
		DeleteThread(__net_event_counter_thread)
		__net_event_counter_thread = false
	else
		__net_event_counter_thread = CreateGameTimeThread(function()
			while true do
				print(__net_event_counters)
				local total = 0
				for event, count in pairs(__net_event_counters) do
					total = total + __net_event_counters[event]
					__net_event_counters[event] = nil
				end
				print("total:", total)
				Sleep(interval)
			end
		end)
	end
end

------------------------------------------------

---
--- Calls a net function and prints the result.
---
--- @param ... any The arguments to pass to the net function.
---
function NetPrintCall(...)
	local params = pack_params(...)
	CreateRealTimeThread(function()
		local function pr(err, ...)
			if err then
				print("Error:", err)
			else
				if pack_params(...) then
					print(...)
				end
			end
		end
		pr(NetCall(unpack_params(params)))
	end)
end

function OnMsg.Chat(name, account_id, message)
	printf("%s: %s", name and Literal(name) or "unknown", Literal(message))
end

function OnMsg.Whisper(name, id, message)
	printf("%s whispers: %s", name and Literal(name) or "unknown", Literal(message))
end

function OnMsg.SysChat(message, ...)
	print("Server message:", message, Literal(print_format(...)))
end

function OnMsg.Autorun()
	local test = {
		nil,
		true,
		false, 
		"integers",
		{
			0, 1, -1, 2, -2, 10, -10, 15, -15, 127, 128, -127, -128, 32767, 32768, -32767, -32768,
			50000, -50000, 65535, 65536, -65535, -65536, 100000, -100000, 10000000, -1000000, 16777215,
			16777216, -16777215, -16777216, 1000000000, -1000000000, 1000000000000000, -1000000000000000
		},
		"tables",
		{ "1","22","333","4444","55555", obj = "obj", int = 5, table = {}, nested_tables = {{{{"deep"}}}} },
		"long string 0123456789012345678901234567890123456789012345678901234567890123456789",
		point(5, 6, 7),
		point(-50, -60),
		point(50000, 60000, 70000),
		point(-50000, -60000),
		box(5,6,900000,1000),
		LightUserData(2000),
		LightUserData(5000000000000),
	}
	local test2 = { Unserialize(Serialize(unpack_params(test))) }
	assert(compare(test, test2), "Serialize fail")
end

end -- Platform.developer
