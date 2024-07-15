DefineClass.AmbientLife = {
	__parents = { "XPrg" },
	GlobalMap = "XPrgAmbientLife",
	GedEditor = "PrgEditor",
	EditorName = "Ambient Life",
	EditorMenubarName = "Ambient Life" ,
	EditorMenubar = "Editors.Art",
	EditorIcon = "CommonAssets/UI/Icons/conversation discussion language.png",
	PrgGlobalMap = "PrgAmbientLife",
}

if FirstLoad or ReloadForDlc then
	PrgAmbientLife = {}
end

------ XPrgAmbientLife specific commands  ---------

local PrgSlotFlagsUser = 24
local PrgSlotFlags = { "Occupied (bit 1)", "Present (bit 2)" }
local PrgSlotFlagOccupied = 2^0
local PrgSlotFlagPresent = 2^1
local PrgSlotFlagBlocked = 2^31

DefineClass.XPrgAmbientLifeCommand = {
	__parents =  { "XPrgCommand" },
}

-- Visit spot
DefineClass.XPrgPlaySpotPrg = {
	__parents = { "XPrgAmbientLifeCommand" },
	properties = {
		{ id = "unit", name = "Unit", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end  },
		{ id = "bld", name = "Building", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ id = "obj", name = "Object", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ id = "spot", name = "Spot", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ id = "slot_data", name = "Slot desc", editor = "text", default = "", validate = validate_var},
		{ id = "slotname", name = "Slot name", editor = "text", default = "", validate = validate_var},
		{ id = "slot", name = "Slot", editor = "combo", default = "" , items = function(self) return self:UpdateLocalVarCombo() end  },
	},
	Menubar = "Slot",
	MenubarSection = "",
	TreeView = T(569417031596, "Play <spot> prg <color 0 128 0><comment>"), 
}

---
--- Generates the code for an XPrgPlaySpotPrg command.
---
--- @param prgdata table The program data.
--- @param level number The current level of the program.
--- @return nil
function XPrgPlaySpotPrg:GenCode(prgdata, level)
	local name = self.slotname
	local slot_data = self.slot_data ~= "" and self.slot_data or nil
	local slot = self.slot ~= "" and self.slot or nil
	local slotname = self.slotname ~= "" and self.slotname or nil
	if self.unit == prgdata.params[1].name then
		self:GenCodeCommandCallPrg(prgdata, level, name, self.unit, self.bld, self.obj, self.spot, slot_data, slot, slotname)
	else
		self:GenCodeCallPrg(prgdata, level, name, self.unit, self.bld, self.obj, self.spot)
	end
end
local spot_proximity_dist = 50*guic

---
--- Leads a unit to a specific building position, following a path of waypoints.
---
--- @param unit table The unit to lead to the position.
--- @param bld table The building that contains the path information.
--- @param path_obj table The path object that contains the waypoint information.
--- @param pos table The position to lead the unit to.
--- @param custom_waypoints table (optional) Custom waypoints to follow instead of the default "Path" waypoints.
--- @param slot_data table (optional) Slot data that contains information about the unit's outside visuals.
--- @return nil
function PrgLeadToBldPos(unit, bld, path_obj, pos, custom_waypoints, slot_data)
	local outside
	if slot_data then
		outside = slot_data.outside or false
	end

	-- return back from the last visit spot
	if unit:IsValidPos() then
		if pos and unit:GetDist(pos) < spot_proximity_dist then
			if outside ~= nil then unit:SetOutsideVisuals(outside) end
			return
		end
		local unit_wp = custom_waypoints and path_obj:FindWaypointsInRange(custom_waypoints, spot_proximity_dist, unit)
		if unit_wp then
			FollowWaypointPath(unit, wp, 1, #wp)
			if unit.visit_restart then return end
			if pos and unit:GetDist(pos) < spot_proximity_dist then
				if outside ~= nil then unit:SetOutsideVisuals(outside) end
				return
			end
		end
		local unit_path = path_obj:FindWaypointsInRange("Path", spot_proximity_dist, unit)
		if unit_path then
			FollowWaypointPath(unit, unit_path, 1, #unit_path)
			if unit.visit_restart then return end
			if pos and unit:GetDist(pos) < spot_proximity_dist then
				if outside ~= nil then unit:SetOutsideVisuals(outside) end
				return
			end
		end
	end

	local path, floordoor
	if pos then
		if unit:IsValidPos() then
			path = path_obj:FindWaypointsInRange("Path", spot_proximity_dist, pos, "Nearest", unit)
		else
			path = path_obj:FindWaypointsInRange("Path", spot_proximity_dist, pos)
		end
		floordoor = path_obj:FindWaypointsInRange("Floordoor", nil, nil, spot_proximity_dist, path and path[#path] or pos)
	end

	-- continue returning back, following the nearest floordoor chain (to hide somewhere)
	if unit:IsValidPos() then
		if floordoor and unit:GetDist(floordoor[#floordoor]) <= spot_proximity_dist then
			floordoor = nil
		else
			local unit_floordoor = path_obj:FindWaypointsInRange("Floordoor", nil, nil, spot_proximity_dist, unit)
			if unit_floordoor then
				-- outside. enter inside
				FollowWaypointPath(unit, unit_floordoor, #unit_floordoor, 1)
				if unit.visit_restart then return end
				local anim_idx = unit:GetWaitAnim()
				if anim_idx >= 0 then
					unit:SetState(anim_idx)
				else
					unit:SetStateText("idle")
				end
				Sleep(500) -- wait the door to close
				if unit.visit_restart then return end
				if not pos and bld then
					unit:DetachFromMap()
					unit:SetOutside(false)
				end
			end
		end
	end

	-- appoach pos chains
	if slot_data and slot_data.move_start == "Pathfind" and unit:IsValidPos() then
		if floordoor then
			unit:Goto(floordoor[1])
		elseif path then
			unit:Goto(path[#path])
		end
		if unit.visit_restart then return end
	end

	-- follow pos chains
	if outside ~= nil then
		unit:SetOutsideVisuals(outside)
	end
	if floordoor then
		unit:SetPos(floordoor[1])
		unit:Face(floordoor[2], 0)
		FollowWaypointPath(unit, floordoor, 1, #floordoor)
		if unit.visit_restart then return end
	end
	if path then
		if not unit:IsValidPos() then
			unit:SetPos(path[#path])
			unit:Face(path[#path - 1], 0)
		end
		FollowWaypointPath(unit, path, #path, 1)
		if unit.visit_restart then return end
	end
end

---
--- Leads a unit to a specific spot on a building, following a waypoint path if necessary.
---
--- @param unit table The unit to lead to the spot.
--- @param bld table The building that contains the spot.
--- @param spot_obj table The object that contains the spot information.
--- @param spot string The name of the spot to lead the unit to.
--- @param orient_to_spot boolean Whether the unit should orient itself to face the spot.
--- @param slot_data table Optional data about the spot, such as the spot state or whether to adjust the Z position.
---
function PrgFollowPathWaypoints(unit, bld, spot_obj, spot, orient_to_spot, slot_data)
	local spot_pos, spot_angle
	local spot_state = slot_data and slot_data.spot_state or ""
	if spot_state ~= "" then
		spot_pos = spot_obj:GetSpotLocPos(spot_state, 0, spot)
		spot_angle = spot_obj:GetSpotAngle2D(spot_state, 0, spot)
	else
		spot_pos = spot_obj:GetSpotLocPos(spot)
		spot_angle = spot_obj:GetSpotAngle2D(spot)
	end
	if unit:IsValidPos() and unit:GetDist(spot_pos) > spot_proximity_dist then
		local wp = bld:FindWaypointsInRange("Path", spot_proximity_dist, spot_pos, spot_proximity_dist, unit)
		if wp then
			FollowWaypointPath(unit, wp, #wp, 1)
		else
			wp = bld:FindWaypointsInRange("Path", spot_proximity_dist, unit, spot_proximity_dist, spot_pos)
			if wp then
				FollowWaypointPath(unit, wp, 1, #wp)
			end
		end
		if unit.visit_restart then return end
	end
	if slot_data then
		unit:SetOutsideVisuals(slot_data.outside)
		if slot_data.adjust_z then
			local passable_z = terrain.FindPassableZ(spot_pos, unit.pfclass, guim, guim)
			if passable_z then
				spot_pos = spot_pos:SetZ(passable_z)
			end
		end
	end
	if not unit:IsValidPos() or unit:GetDist(spot_pos) > spot_proximity_dist then
		unit:SetPos(spot_pos)
		unit:SetAngle(spot_angle)
	elseif orient_to_spot then
		local snap_angle_time = 200 * abs(AngleDiff(spot_angle, unit:GetAngle())) / (180 * 60)
		unit:SetAngle(spot_angle, snap_angle_time)
		local snap_pos_time = Min(200, unit:GetDist(spot_pos) * 1000 / Max(1, unit:GetSpeed()) or 0)
		unit:SetPos(spot_pos, snap_pos_time)
		Sleep(snap_pos_time)
	end
end

--- Leads a unit to a specific spot within a building.
---
--- @param unit table The unit to lead to the spot.
--- @param bld table The building that contains the spot.
--- @param spot_obj table The object that contains the spot information.
--- @param spot string The name of the spot to lead the unit to.
--- @param orient_to_spot boolean Whether the unit should orient itself to face the spot.
--- @param custom_waypoints table Optional custom waypoints to use for the path.
--- @param slot_data table Optional data about the spot, such as the spot state or whether to adjust the Z position.
function PrgLeadToSpot(unit, bld, spot_obj, spot, orient_to_spot, custom_waypoints, slot_data)
	if not IsValid(spot_obj) then
		return
	end
	local spot_pos, spot_angle
	local spot_state = slot_data and slot_data.spot_state or ""
	if spot_state ~= "" then
		spot_pos = spot_obj:GetSpotLocPos(spot_state, 0, spot)
		spot_angle = spot_obj:GetSpotAngle2D(spot_state, 0, spot)
	else
		spot_pos = spot_obj:GetSpotLocPos(spot)
		spot_angle = spot_obj:GetSpotAngle2D(spot)
	end
	if slot_data and slot_data.adjust_z then
		local passable_z = terrain.FindPassableZ(spot_pos, unit.pfclass, guim, guim)
		if passable_z then
			spot_pos = spot_pos:SetZ(passable_z)
		end
	end
	if unit:IsValidPos() and unit:GetDist(spot_pos) > spot_proximity_dist then
		local unit_wp = custom_waypoints and bld:FindWaypointsInRange(custom_waypoints, spot_proximity_dist, unit)
		if unit_wp then
			FollowWaypointPath(unit, unit_wp, 1, #unit_wp)
			if unit.visit_restart then return end
		end
	end
	if not unit:IsValidPos() or unit:GetDist(spot_pos) > spot_proximity_dist then
		local spot_wp = custom_waypoints and bld:FindWaypointsInRange(custom_waypoints, spot_proximity_dist, spot_pos)
		if spot_wp then
			PrgLeadToBldPos(unit, bld, bld, spot_wp[#spot_wp], nil, slot_data)
			if unit.visit_restart then return end
			FollowWaypointPath(unit, spot_wp, #spot_wp, 1)
			if unit.visit_restart then return end
		else
			PrgLeadToBldPos(unit, bld, bld, spot_pos, nil, slot_data)
			if unit.visit_restart then return end
		end
	end
	if not unit:IsValidPos() or unit:GetDist(spot_pos) > spot_proximity_dist then
		unit:SetPos(spot_pos)
		unit:SetAngle(spot_angle)
	elseif orient_to_spot then
		local snap_angle_time = 200 * abs(AngleDiff(spot_angle, unit:GetAngle())) / (180 * 60)
		unit:SetAngle(spot_angle, snap_angle_time)
		local snap_pos_time = Min(200, unit:GetDist(spot_pos) * 1000 / Max(1, unit:GetSpeed()) or 0)
		unit:SetPos(spot_pos, snap_pos_time)
		Sleep(snap_pos_time)
	end
end

---
--- Leads a unit to the "Exit" spot of a building, preferring passable spots if possible.
---
--- @param unit table The unit to lead to the exit spot.
--- @param bld table The building containing the exit spot.
--- @param custom_waypoints table|nil Custom waypoints to use instead of the building's default waypoints.
--- @param slot_data table|nil Additional data related to the spot.
--- @param prefer_passable boolean|nil If true, the function will try to find a passable exit spot.
---
--- @return nil
function PrgLeadToExit(unit, bld, custom_waypoints, slot_data, prefer_passable)
	local spotname = "Exit"
	if bld:HasSpot(spotname) then
		local spot
		if prefer_passable then
			if unit:IsValidPos() then
				spot = bld:NearestPassableSpot(spotname, unit)
			else
				spot = bld:RandomPassableSpot(spotname, unit)
			end
			if not spot then
				printf("once", '%s (handle=%d) "Exit" spots are on impassable!', bld:GetEntity(), bld.handle)
			end
		end
		if not spot then
			spot = bld:GetRandomSpot(spotname)
		end
		PrgLeadToSpot(unit, bld, bld, spot, false, custom_waypoints, slot_data)
	else
		PrgLeadToBldPos(unit, bld, bld, nil, custom_waypoints, slot_data)
	end
	if unit.visit_restart then return end
end

--[===[
Not finished functions

function PrgChainStep(unit, path, path_idx, forward, status)
	while path_idx do
		local id = path[path_idx]
		local param = path[path_idx + 1]
		path_idx = path_idx + (forward and 2 or -2)
		if path_idx <= 0 or path_idx > #path then path_idx = nil end
		if id == "DetachFromMap" then
			unit:DetachFromMap()
			unit:SetOutsideVisuals(false)
			return path_idx
		elseif id == "Teleport" then
			if param then
				unit:SetPos(IsPoint(param) and param or param[path_forward and #param or 1])
				return path_idx, "teleported"
			end
			status = "teleport"
		elseif param then
			if IsPoint(param) then
				if status == "teleport" or not unit:IsValidPos() then
					unit:SetPos(param)
					return path_idx, "teleported"
				elseif id == "Pathfind" then
					unit:Goto(param)
					return path_idx
				end
			else
				local forward = path_forward
				if id == "Waypoints_Backward" then
					forward = not forward
				end
				local start_idx = forward and 1 or #param
				local last_idx = forward and #param or 1
				if status == "teleport" or not unit:IsValidPos() then
					unit:SetPos(param[start_idx])
					start_idx = start_idx == 1 and 2 or start_idx - 1
					unit:Face(param[start_idx], 0)
				elseif status == "teleported" then
					if unit:GetDist2D(param[start_idx]) == 0 then
						start_idx = start_idx == 1 and 2 or start_idx - 1
					end
					unit:Face(param[start_idx], 0)
				end
				if id == "Pathfind" then
					for i = start_idx, last_idx, forward and 1 or -1 do
						unit:Goto(param[i])
					end
				else
					FollowWaypointPath(unit, param, start_idx, last_idx)
				end
				return path_idx
			end
		end
	end
end

function PRGChainFollow(unit, bld, chain, idx1, idx2)
	local idx = idx1 or 1
	idx2 = idx2 or #path
	local status
	if idx <= idx2 then
		while idx and idx <= idx2 do
			idx, status = PrgChainStep(unit, path, idx, true, status)
		end
	else
		while idx and idx >= idx2 do
			idx, status = PrgChainStep(unit, path, idx, false, status)
		end
	end
end

function PrgResolveChain(bld, dest_pos, chain, resolved)
	resolved = resolved or {}
	local last_pos = dest_pos
	for i = 1, #chain, 2 do
		local id = chain[i]
		local param = chain[i+1]
		local value = param
		
		if id == "Pathfind" or id == "Teleport" then
			if param and type(param) == "string" and bld:HasSpot(param) then
				local spot = bld:GetNearestSpot(param, last_pos)
				last_pos = bld:GetSpotPos(spot)
				value = last_pos
			else
				value = false
			end
		elseif id == "Waypoints" or id == "Waypoints_Backward" then
			local wp = bld:NearestWaypoints(last_pos, nil, name, 1)
			value = wp
			if wp then
				last_pos = wp[#wp]
			end
		end
		if value ~= nil then
			resolved[#resolved + 1] = id
			resolved[#resolved + 1] = value
		end
	end
	return resolved
end

local function PRGChainFindUnitIdx(unit, chain, forward)
	local on_valid_pos = unit:IsValidPos()
	local count = #chain
	for i = 1, count, 2 do
		local id = chain[i]
		local wp = chain[i+1]
		if id == "SetHolder" then
			if not on_valid_pos then
				return i + (forward and 1 or - 1)
			end
		elseif on_valid_pos then
			if IsPoint(wp) then
				if unit:GetDist(wp) <= spot_proximity_dist then
					return i + (forward and 1 or - 1)
				end
			elseif type(wp) == "table" and (id == "Waypoints_Backward" or id == "Waypoints" or "Pathfind" or "Teleport") then
				if forward then
					if i == 1 and unit:GetDist(wp[1]) <= spot_proximity_dist then
						return i - 1
					end
					if unit:GetDist(wp[#wp]) <= spot_proximity_dist then
						return i + 1
					end
				else
					if i == count and unit:GetDist(wp[#wp]) <= spot_proximity_dist then
						return i + 1
					end
					if unit:GetDist(wp[1]) <= spot_proximity_dist then
						return i
					end
				end
			end
		end
	end
	return true
end

function PrgChainLead(unit, bld, pos, chain, prev_chain)
	--local resolved = PrgResolveChain(chain, bld, pos)
	local idx = PRGChainFindUnitIdx(unit, chain, false)
	local prev_idx = not idx and prev_chain and PRGChainFindUnitIdx(unit, prev_chain, true)
	local status
	while not idx and prev_idx do
		prev_idx = PrgChainStep(unit, prev_chain, prev_idx, false, status)
		idx = PRGChainFindUnitIdx(unit, chain, false)
	end
	PRGChainFollow(unit, bld, chain, idx, 1, status)
end

--]===]

---
--- Leads a unit to a specific location on a building.
---
--- @param unit table The unit to lead.
--- @param bld table The building to lead the unit to.
--- @param path_obj table The object to use for the path.
--- @param slot_data table Optional data about the slot the unit is being led to.
---
function PrgLeadToHolder(unit, bld, path_obj, slot_data)
	path_obj = path_obj or bld
	if not unit:IsValidPos() then
		return
	end
	local goto_spot = slot_data and slot_data.goto_spot or ""
	if goto_spot ~= "Teleport" then
		PrgLeadToBldPos(unit, bld, path_obj, nil, nil, slot_data)
		if unit.visit_restart then return end
	end
	unit:DetachFromMap()
	unit:SetOutsideVisuals(slot_data and slot_data.outside or false)
end

DefineClass.XPrgLeadTo = {
	__parents = { "XPrgAmbientLifeCommand" },
	properties = {
		{ id = "loc", name = "Location", editor = "dropdownlist", default = "Spot", items = { "Spot", "Exit", "PassableExit" } },
		{ id = "unit", name = "Unit", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ id = "spot_obj", name = "Spot object", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ id = "spot", name = "Spot var", editor = "text", default = "", no_edit = function(self) return self.loc ~= "Spot" end },
		{ id = "orient_to_spot", name = "Orient to spot", editor = "bool", default = false },
		{ id = "waypoints", name = "Custom Waypoints", editor = "text", default = "" },
	},
	Menubar = "Move",
	MenubarSection = "",
	TreeView = T{601947096634, "Lead <unit> to <spot_obj> <txt> <color 0 128 0><comment>",
		txt = function(obj)
			local loc = obj.loc == "Spot" and T(725779511260, "<spot>") or T(691129973441, "<loc>")
			if obj.waypoints ~= "" then
				return T{558667157664, "<loc><newline>   (custom waypoints <waypoints>)", loc = loc}
			end
			return loc
		end },
}

---
--- Generates the code to lead a unit to a specific location on a building.
---
--- @param prgdata table The program data to add the code to.
--- @param level number The level of indentation for the generated code.
---
function XPrgLeadTo:GenCode(prgdata, level)
	local waypoints = self.waypoints ~= "" and self.waypoints or nil
	local orient_to_spot = self.orient_to_spot and "true" or "false"
	if self.loc == "Spot" and self.spot ~= "" then
		local params = {
			self.unit,
			string.format('PrgResolvePathObj(%s)', self.spot_obj),
			self.spot_obj,
			self.spot,
			orient_to_spot
		}
		if waypoints then
			table.insert(params, waypoints)
		end
		PrgAddExecLine(prgdata, level, string.format('PrgLeadToSpot(%s)', table.concat(params, ', ')))
		PrgAddExecLine(prgdata, 0, "VISIT_RESTART")
	elseif self.loc == "Exit" or self.loc == "PassableExit" then
		local params = {
			self.unit,
			self.spot_obj
		}
		if waypoints or self.loc == "PassableExit" then
			table.insert(params, waypoints or "nil")
		end
		if self.loc == "PassableExit" then
			table.insert(params, "nil")
			table.insert(params, "true")
		end
		PrgAddExecLine(prgdata, level, string.format('PrgLeadToExit(%s)', table.concat(params, ', ')))
		PrgAddExecLine(prgdata, 0, "VISIT_RESTART")
	end
end

-- move waypoints
DefineClass.XPrgFollowWaypoints = {
	__parents = { "XPrgAmbientLifeCommand" },
	properties = {
		{ id = "unit", name = "Unit", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ id = "dir", name = "Direction", editor = "dropdownlist", default = "Forward", items = { "Forward", "Backward" } },
		{ id = "waypoints_var", name = "Waypoints Var", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ id = "anim", name = "Anim", editor = "text", default = "", },
	},
	Menubar = "Move",
	MenubarSection = "",
	TreeView = T(986340233264, "Follow waypoints <waypoints_var> <dir> <color 0 128 0>"),
}

---
--- Generates code to make a unit follow a set of waypoints.
---
--- @param prgdata table The program data to add the code to.
--- @param level number The level of indentation for the generated code.
---
function XPrgFollowWaypoints:GenCode(prgdata, level)
	local resolved_wp = self.waypoints_var
	if self.anim ~= "" then
		PrgAddExecLine(prgdata, level, string.format('%s:SetMoveAnim("%s")', self.unit, self.anim))
	end
	local first, last
	if self.dir == "Forward" then
		first = 1
		last = "nil"
	else
		first = "nil"
		last = 1
	end
	local comment = string.format('	-- move [%s .. %s]', first or "last-index", last or "last-index")
	PrgAddExecLine(prgdata, level, string.format('FollowWaypointPath(%s, %s, %s, %s)%s', self.unit, resolved_wp, first, last, comment))
end

-- select spot
MapVar("PRG_BldSlotData", {}, weak_keys_meta)

local function ChangeSlotFlags(bld, attach, spot_type, slot, flags_add, flags_clear)
	if not slot then
		return
	end
	local bld_slots = PRG_BldSlotData[bld]
	if not bld_slots then
		bld_slots = {}
		PRG_BldSlotData[bld] = bld_slots
	end
	local obj_slots
	if not attach or attach == bld then
		obj_slots = bld_slots
	else
		obj_slots = bld_slots[attach]
		if not obj_slots then
			obj_slots = {}
			bld_slots[attach] = obj_slots
		end
	end
	local slots = obj_slots[spot_type]
	if not slots then
		slots = {}
		obj_slots[spot_type] = slots
	end
	local prev_flags = slots[slot] or 0
	local flags = FlagClear(bor(prev_flags, flags_add or 0), flags_clear or 0)
	if flags ~= prev_flags then
		slots[slot] = flags
	end
	return flags
end

local function ClearAllSlotFlags(bld, attach, flags_clear)
	local bld_slots = PRG_BldSlotData[bld]
	if not bld_slots then
		return
	end
	local obj_slots
	if not attach or attach == bld then
		obj_slots = bld_slots
	else
		obj_slots = bld_slots[attach]
		if not obj_slots then
			return
		end
	end
	for spot_type, slots in pairs(obj_slots) do
		local cnt = table.maxn(slots)
		for slot = 1, cnt do
			local prev_flags = slots[slot] or 0
			if prev_flags ~= 0 then
				local flags = FlagClear(prev_flags, flags_clear)
				if flags ~= prev_flags then
					slots[slot] = flags
				end
			end
		end
	end
end

local function ForEachSlot(func, slot_data, bld, obj, spot_type, spot_first, max_slots, flags_required, flags_missing)
	local slots = PRG_BldSlotData[bld]
	if obj ~= bld then
		slots = slots and slots[obj]
	end
	slots = slots and slots[spot_type]
	local cnt = Min(max_slots, slots and table.maxn(slots) or 0)
	local flags_all = bor(bor(flags_required, flags_missing), PrgSlotFlagBlocked)
	for slot = 1, cnt do
		if band(slots[slot], flags_all) == flags_required then
			func(spot_first + slot - 1, obj, slot_data, slot, spot_type)
		end
	end
	if flags_required == 0 then
		for slot = cnt + 1, max_slots do
			func(spot_first + slot - 1, obj, slot_data, slot, spot_type)
		end
	end
end

local function ForEachObjSpot(func, bld, attach, slot_data)
	local obj = attach or bld
	local spots = slot_data.spots
	if spots then
		local flags_required = slot_data.flags_required or 0
		local flags_missing = slot_data.flags_missing or 0
		local spot_state = slot_data.spot_state or ""
		for i = 1, #spots do
			local spot_type = spots[i]
			local first, last
			if spot_state ~= "" then
				first, last = obj:GetSpotRange(spot_state, spot_type)
			else
				first, last = obj:GetSpotRange(spot_type)
			end
			local max_slots = 1 + last - first
			ForEachSlot(func, slot_data, bld, obj, spot_type, first, max_slots, flags_required, flags_missing)
		end
	else -- holder
		func("", obj, slot_data, 1, "")
	end
end

local function ForEachSpotInMultipleObjects(func, bld, slot_data, attach_attach, attach1, attach2, ...)
	if attach_attach then
		ForEachSpotInMultipleObjects(func, bld, slot_data, nil, attach1:GetAttach(attach_attach))
	elseif attach1 then
		ForEachObjSpot(func, bld, attach1, slot_data)
	end
	if attach2 then
		return ForEachSpotInMultipleObjects(func, bld, slot_data, attach_attach, attach2, ...)
	end
end

---
--- Checks if the given slot data matches the specified building and unit.
---
--- @param data table The slot data to check.
--- @param bld table The building object.
--- @param unit table The unit object.
--- @return boolean true if the slot data matches, false otherwise.
---
function PrgMatchSlotData(data, bld, unit)
	return true
end

---
--- Iterates over all the slots in the specified group for the given building and unit.
---
--- @param func function The function to call for each slot.
--- @param bld table The building object.
--- @param attach table The attached object.
--- @param group string The group of slots to iterate over.
--- @param slots_list table The list of slot data.
--- @param unit table The unit object.
---
function PrgForEachObjSlotFromGroup(func, bld, attach, group, slots_list, unit)
	if not bld or not slots_list then
		return
	end
	for j = 1, #slots_list do
		local data = slots_list[j]
		if data.groups[group] and PrgMatchSlotData(data, bld, unit) then
			if attach then
				ForEachSpotInMultipleObjects(func, bld, data, data.attach_attach, attach)
			elseif data.attach then
				ForEachSpotInMultipleObjects(func, bld, data, data.attach_attach, bld:GetAttach(data.attach))
			else
				ForEachObjSpot(func, bld, nil, data)
			end
		end
	end
end

local _GatherSlotsList
local function AddSlot(spot, spot_obj, slot_data, slot, slot_name)
	local t = _GatherSlotsList
	local i = #t
	t[i + 1] = spot
	t[i + 2] = spot_obj
	t[i + 3] = slot_data
	t[i + 4] = slot
	t[i + 5] = slot_name
end

-- for every slot: spot, spot_obj, slot_data, slot, slot_name
local function GatherAvailableSlots(bld, attach, group, slots_list, unit)
	_GatherSlotsList = _GatherSlotsList or {}
	PrgForEachObjSlotFromGroup(AddSlot, bld, attach, group, slots_list, unit)
	if #_GatherSlotsList == 0 then
		return
	end
	local list = _GatherSlotsList
	_GatherSlotsList = nil
	return list
end

---
--- Retrieves a random available slot from the specified group for the given building and unit.
---
--- @param bld table The building object.
--- @param attach table The attached object.
--- @param group string The group of slots to select from.
--- @param slots_list table The list of slot data.
--- @param unit table The unit object.
---
--- @return table The spot, spot object, slot data, slot, and slot name for a randomly selected available slot.
---
function PrgGetObjRandomSpotFromGroup(bld, attach, group, slots_list, unit)
	local list = GatherAvailableSlots(bld, attach, group, slots_list, unit)
	local size = list and #list or 0
	if size == 0 then
		return
	end
	local idx = 1 + 5 * bld:Random(size/5)
	return table.unpack(list, idx, idx + 4)
end

---
--- Retrieves the nearest available slot from the specified group for the given building and unit.
---
--- @param bld table The building object.
--- @param attach table The attached object.
--- @param group string The group of slots to select from.
--- @param slots_list table The list of slot data.
--- @param unit table The unit object.
---
--- @return table The spot, spot object, slot data, slot, and slot name for the nearest available slot.
---
function PrgGetObjNearestSpotFromGroup(bld, attach, group, slots_list, unit)
	local list = GatherAvailableSlots(bld, attach, group, slots_list, unit)
	local size = list and #list or 0
	if size == 0 then
		return
	elseif size < 5 then
		return table.unpack(list)
	end
	local pt = unit:GetPos()
	local best_idx, best_dist, dist
	for idx = 1, size, 5 do
		local spot, spot_obj = list[idx], list[idx + 1]
		if spot == "" then
			dist = pt:Dist(spot_obj:GetPosXYZ())
		else
			dist = pt:Dist(spot_obj:GetSpotPosXYZ(spot))
		end
		if idx == 1 or dist < best_dist then
			best_idx, best_dist = idx, dist
		end
	end
	return table.unpack(list, best_idx, best_idx + 4)
end

---
--- Visits a holder object for a specified duration.
---
--- @param unit table The unit object.
--- @param bld table The building object.
--- @param path_obj table The path object.
--- @param time number The duration to visit the holder, in seconds.
--- @param slot_data table The slot data.
---
--- This function leads the unit to the holder, waits for the specified duration, and then returns. If a duration is provided, the function sets a visit end time on the unit and pushes a destructor to reset that time when the function returns. The function will wait for the visit to end before returning.
---
function PrgVisitHolder(unit, bld, path_obj, time, slot_data)
	if time then
		unit.visit_spot_end_time = GameTime() + time
		unit:PushDestructor(function(unit)
			unit.visit_spot_end_time = false
		end)
	end
	if unit:IsValidPos() then
		PrgLeadToHolder(unit, bld, path_obj, slot_data)
	end
	unit:WaitVisitEnd()
	if time then
		unit:PopAndCallDestructor()
	end
end

---
--- Resolves the path object for the given attachment.
---
--- @param attach table The attachment object.
--- @return table|nil The path object, or nil if not found.
---
--- This function recursively searches the parent hierarchy of the given attachment object to find the first object that is a `WaypointsObj`. If no such object is found, it returns `nil`.
---
function PrgResolvePathObj(attach)
	if not IsValid(attach) then
		return
	end
	while attach and not attach:IsKindOf("WaypointsObj") do
		attach = attach:GetParent()
	end
	return attach
end

---
--- Leads a unit to a specified spot on a building or object.
---
--- @param unit table The unit object.
--- @param bld table The building object.
--- @param spot_obj table The spot object.
--- @param spot string The name of the spot to go to.
--- @param slot_data table The slot data.
---
--- This function handles the logic for leading a unit to a specific spot on a building or object. It checks the move_start setting in the slot_data and will either lead the unit to the exit spot or lead them to the holder object. If the spot is empty, it will just lead the unit to the holder object. Otherwise, it will use the goto_spot setting to determine how to lead the unit to the specified spot, either by pathfinding, following path waypoints, or setting the position and angle directly.
---
function PrgGotoSpot(unit, bld, spot_obj, spot, slot_data)
	spot = spot or ""
	if unit:IsValidPos() then
		if slot_data and slot_data.move_start == "GoToExitSpot" then
			unit:Goto(spot_obj:GetSpotLocPos(spot_obj:GetRandomSpot("Exit")))
			if unit.visit_restart then return end
		end
	end
	if spot == "" then
		if unit:IsValidPos() then
			local path_obj = PrgResolvePathObj(spot_obj) or bld
			PrgLeadToHolder(unit, bld, path_obj, slot_data)
		end
		return
	end
	local goto_spot = slot_data.goto_spot or ""
	if goto_spot == "LeadToSpot" then
		local path_obj = PrgResolvePathObj(spot_obj) or bld
		PrgLeadToSpot(unit, path_obj, spot_obj, spot, true, slot_data.custom_waypoints, slot_data)
	elseif goto_spot == "FollowPathWaypoints" then
		local path_obj = PrgResolvePathObj(spot_obj) or bld
		PrgFollowPathWaypoints(unit, path_obj, spot_obj, spot, true, slot_data)
	elseif goto_spot ~= "" then
		local spot_pos, spot_angle
		local spot_state = slot_data and slot_data.spot_state or ""
		if spot_state ~= "" then
			spot_pos = spot_obj:GetSpotLocPos(spot_state, 0, spot)
			spot_angle = spot_obj:GetSpotAngle2D(spot_state, 0, spot)
		else
			spot_pos = spot_obj:GetSpotLocPos(spot)
			spot_angle = spot_obj:GetSpotAngle2D(spot)
		end
		local adjusted_pos
		if slot_data then
			unit:SetOutsideVisuals(slot_data.outside)
			if slot_data.adjust_z then
				local passable_z = terrain.FindPassableZ(spot_pos, unit.pfclass, guim, guim)
				if passable_z then
					adjusted_pos = spot_pos:SetZ(passable_z)
				end
			end
		end
		if not unit:IsValidPos() then
			unit:SetPos(adjusted_pos)
			unit:SetAngle(spot_angle)
		else
			if goto_spot == "Pathfind" then
				unit:Goto(spot_pos)
				if unit.visit_restart then return end
			end
			if goto_spot == "Pathfind" or goto_spot == "StraightLine" then
				unit:Goto(spot_pos, "sl")
				if unit.visit_restart then return end
				local snap_angle_time = 200 * abs(AngleDiff(spot_angle, unit:GetAngle())) / (180 * 60)
				unit:SetAngle(spot_angle, snap_angle_time)
			else
				unit:SetPos(adjusted_pos)
				unit:SetAngle(spot_angle)
			end
		end
	end
end

---
--- Returns a unit to its starting position after visiting a spot.
---
--- @param unit table The unit that is returning from the spot.
--- @param bld table The building that the spot is associated with.
--- @param spot_obj table The spot object that the unit visited.
--- @param spot string The name of the spot that the unit visited.
--- @param slot_data table The data associated with the slot that the unit visited.
function PrgReturnFromSpot(unit, bld, spot_obj, spot, slot_data)
	local move_end = slot_data and slot_data.move_end or ""
	if move_end == "" then
		return
	end
	if not unit:IsValidPos() and spot_obj and not IsValid(spot_obj) and bld then
		spot_obj = bld
		local attaches = slot_data and (slot_data.attach or "") ~= "" and spot_obj:GetAttaches(slot_data.attach)
		if attaches then
			spot_obj = unit:TableRand(attaches)
			attaches = (slot_data.attach_attach or "") ~= "" and spot_obj:GetAttaches(slot_data.attach_attach)
			if attaches then
				spot_obj = unit:TableRand(attaches)
			end
		end
	end
	local path_obj = PrgResolvePathObj(spot_obj) or bld
	if move_end == "LeadToExit" then
		PrgLeadToExit(unit, path_obj, slot_data.custom_waypoints, slot_data)
	elseif move_end == "TeleportToExit" then
		if path_obj:HasSpot("Exit") then
			local x, y, z, angle = path_obj:GetSpotLocXYZ(path_obj:GetRandomSpot("Exit"))
			unit:SetPos(x, y, z)
			unit:SetAngle(angle)
		else
			unit:DetachFromMap()
		end
	end
end

---
--- Visits a slot on a building and performs any associated ambient life actions.
---
--- @param unit table The unit that is visiting the slot.
--- @param bld table The building that the slot is associated with.
--- @param spot_obj table The spot object that the slot is associated with.
--- @param spot string The name of the spot that the slot is associated with.
--- @param slot_data table The data associated with the slot.
--- @param slot number The index of the slot being visited.
--- @param slot_name string The name of the slot being visited.
--- @param time number The amount of time the unit should spend in the slot.
--- @param visits_count number The number of times the ambient life program should be executed for the slot.
--- @param ... any Additional arguments to pass to the ambient life program.
---
function PrgVisitSlot(unit, bld, spot_obj, spot, slot_data, slot, slot_name, time, visits_count, ...)
	spot = spot or ""
	if not slot_name and spot ~= "" then
		if slot then
			slot_name = IsValid(spot_obj) and spot_obj:GetSpotName(spot)
		else
			slot, slot_name = PrgGetSlotBySpot(spot_obj, spot, slot_data)
		end
	end
	local prg = slot_name and PrgAmbientLife[slot_name]
	local dtor
	if prg and IsFlagSet(slot_data.flags_missing or 0, PrgSlotFlagOccupied) then
		dtor = true
		unit:PushDestructor(function(unit)
			ChangeSlotFlags(bld, spot_obj, slot_name, slot, 0, PrgSlotFlagOccupied)
		end)
		ChangeSlotFlags(bld, spot_obj, slot_name, slot, PrgSlotFlagOccupied, 0)
	end
	PrgGotoSpot(unit, bld, spot_obj, spot, slot_data)
	if not unit.visit_restart then
		unit.visit_spot_end_time = time and GameTime() + time or false
		if prg then
			for i = 1, (visits_count or 1) do
				prg(unit, bld, spot_obj, spot, slot_data, slot, slot_name, ...)
				if unit.visit_restart then break end
			end
		elseif spot == "" then
			unit:WaitVisitEnd()
		end
		unit.visit_spot_end_time = false
	end
	PrgReturnFromSpot(unit, bld, spot_obj, spot, slot_data)
	if dtor then
		unit:PopAndCallDestructor()
	end
end

---
--- Blocks a spot on a building.
---
--- @param bld table The building that the spot is associated with.
--- @param obj table The object that the spot is associated with.
--- @param spot string The name of the spot to block.
---
function PrgBlockSpot(bld, obj, spot)
	PrgChangeSpotFlags(bld, obj, spot, PrgSlotFlagBlocked)
end

---
--- Clears the blocked flag on all spots associated with the given building and object.
---
--- @param bld table The building that the spots are associated with.
--- @param obj table The object that the spots are associated with.
---
function PrgUnblockAllSpots(bld, obj)
	ClearAllSlotFlags(bld, obj, PrgSlotFlagBlocked)
end

---
--- Changes the flags of a spot on a building.
---
--- @param bld table The building that the spot is associated with.
--- @param obj table The object that the spot is associated with.
--- @param spot string The name of the spot to change the flags for.
--- @param flags_add number The flags to add to the spot.
--- @param flags_clear number The flags to clear from the spot.
--- @param spot_type string The type of the spot.
--- @param slot number The slot index of the spot.
--- @return number The result of the flag change operation.
---
function PrgChangeSpotFlags(bld, obj, spot, flags_add, flags_clear, spot_type, slot)
	if not spot then
		return 0
	end
	if not spot_type then
		spot_type = spot and IsValid(obj) and obj:GetSpotName(spot) or ""
	end
	if spot_type ~= "" then
		if not slot and spot then
			slot = spot - obj:GetSpotBeginIndex(spot_type) + 1
		end
		return ChangeSlotFlags(bld, obj, spot_type, slot, flags_add, flags_clear)
	end
	return 0
end

---
--- Gets the slot index and type for the given spot on an object.
---
--- @param obj table The object that the spot is associated with.
--- @param spot string The name of the spot to get the slot for.
--- @param slot_data table Optional table containing spot state information.
--- @return number|nil The slot index for the spot, or nil if the spot is not found.
--- @return string|nil The spot type for the spot, or nil if the spot is not found.
---
function PrgGetSlotBySpot(obj, spot, slot_data)
	local spot_type = spot and spot ~= "" and IsValid(obj) and obj:GetSpotName(spot) or ""
	if spot_type == "" then
		return
	end
	local first, last
	local spot_state = slot_data and slot_data.spot_state or ""
	if spot_state == "" then
		first, last = obj:GetSpotRange(spot_type)
	else
		first, last = GetSpotRange(obj:GetEntity(), spot_state, spot_type)
	end
	assert(spot >= first and spot <= last)
	return spot - first + 1, spot_type
end

---
--- Gets a random spot from an object that matches the given flags.
---
--- @param obj table The object to get the random spot from.
--- @param attach_class string The class of the object to attach the spot to.
--- @param slot_data table Optional table containing spot state information.
--- @param spot_type1 string The type of the spot to get.
--- @param ... Additional spot types to check.
--- @return string|nil The name of the random spot that matches the flags, or nil if no spot is found.
---
function GetObjRandomSpotByFlags(obj, attach_class, slot_data, spot_type1, ...)
end
---
--- Gets a random spot from an object that matches the given list of spot types.
---
--- @param obj table The object to get the random spot from.
--- @param list table A list of spot types to check.
--- @param slot_data table Optional table containing spot state information.
--- @return string|nil The name of the random spot that matches the list, or nil if no spot is found.
---
function GetObjRandomSpotByFlagsFromList(obj, list, slot_data)
end

DefineClass.XPrgChangeSlotFlags = {
	__parents = { "XPrgAmbientLifeCommand" },
	properties = {
		{ category = "Flags", id = "bld", name = "Building", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Flags", id = "obj", name = "Object", editor = "combo", default = "" , items = function(self) return self:UpdateLocalVarCombo() end  },
		{ category = "Flags", id = "spot", name = "Spot", editor = "combo", default = "" , items = function(self) return self:UpdateLocalVarCombo() end  },
		{ category = "Flags", id = "slotname", name = "Slot name", editor = "text", default = "", validate = validate_var},
		{ category = "Flags", id = "slot", name = "Slot", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Flags", id = "flags_add", name = "Flags add", editor = "flags", size = PrgSlotFlagsUser, default = 0, items = PrgSlotFlags },
		{ category = "Flags", id = "flags_clear", name = "Flags clear", editor = "flags", size = PrgSlotFlagsUser, default = 0, items = PrgSlotFlags },
		{ category = "PRG End", id = "dtor_flags_add", name = "Dtor flags add", editor = "flags", size = PrgSlotFlagsUser, default = 0, items = PrgSlotFlags },
		{ category = "PRG End", id = "dtor_flags_clear", name = "Dtor flags clear", editor = "flags", size = PrgSlotFlagsUser, default = 0, items = PrgSlotFlags },
	},
	Menubar = "Slot",
	MenubarSection = "",
	TreeView = T{221014920931, "<txt>",
		txt = function(obj)
			local list = {}
			if obj.comment ~= "" then
				table.insert(list, Untranslated("<color 0 128 0><comment></color>"))
			end
			if obj.flags_add ~= 0 then
				table.insert(list, Untranslated("Set <obj> <spot> flags <flags_add>"))
			end
			if obj.flags_clear ~= 0 then
				table.insert(list, Untranslated("Clear <obj> <spot> flags <flags_clear>"))
			end
			if obj.dtor_flags_add ~= 0 then
				table.insert(list, Untranslated("Dtor set <obj> <spot> flags <dtor_flags_add>"))
			end
			if obj.dtor_flags_clear ~= 0 then
				table.insert(list, Untranslated("Dtor clear <obj> <spot> flags <dtor_flags_clear>"))
			end
			if #list == 0 then
				return Untranslated("Set <obj> <spot> flags <flags_add>")
			end
			return table.concat(list, "\n")
	end,}
}

---
--- Generates the code to change the flags of a spot on an object.
---
--- @param prgdata table The program data object.
--- @param level number The indentation level for the generated code.
---
--- This function generates the code to add or clear flags on a spot of an object. It first determines the spot type and slot variables, then generates the code to change the flags. It also generates code to change the flags during the destructor.
---
--- If the `flags_add`, `flags_clear`, `dtor_flags_add`, or `dtor_flags_clear` properties are all 0, then no code is generated.
---
--- The generated code uses the `PrgGetSlotBySpot`, `PrgChangeSpotFlags`, and `PrgAddDtorLine` functions to perform the flag changes.
---
function XPrgChangeSlotFlags:GenCode(prgdata, level)
	if self.flags_add == 0 and self.flags_clear == 0 and self.dtor_flags_add == 0 and self.dtor_flags_clear == 0 then
		return
	end
	local g_spot_type
	local g_slot = self.slot
	if g_slot == "" then
		g_spot_type = PrgGetFreeVarName(prgdata, "_spot_type")
		PrgNewVar(g_spot_type, prgdata.exec_scope, prgdata)
		g_slot = PrgGetFreeVarName(prgdata, "_slot")
		PrgNewVar(g_slot, prgdata.exec_scope, prgdata)
		PrgAddExecLine(prgdata, level, string.format('%s, %s = PrgGetSlotBySpot(%s, %s)', g_slot, g_spot_type, self.obj, self.spot))
	else
		g_spot_type = self.slotname
		if g_spot_type == "" then
			PrgNewVar(g_spot_type, prgdata.exec_scope, prgdata)
			PrgAddExecLine(prgdata, level, string.format('%s = %s and IsValid(%s) and obj:GetSpotName(%s) or ""', g_spot_type, self.spot, self.obj, self.spot))
		end
	end
	if self.flags_add ~= 0 or self.flags_clear ~= 0 then
		PrgAddExecLine(prgdata, level, string.format('PrgChangeSpotFlags(%s, %s, %s, %s, %s, %s, %s)',
			self.bld, self.obj, self.spot, self.flags_add, self.flags_clear, g_spot_type, g_slot))
	end
	if self.dtor_flags_add ~= 0 or self.dtor_flags_clear ~= 0 then
		PrgAddDtorLine(prgdata, 2, string.format('PrgChangeSpotFlags(%s, %s, %s, %s, %s, %s, %s)', 
			self.bld, self.obj, self.spot, self.dtor_flags_add, self.dtor_flags_clear, g_spot_type, g_slot))
	end
end

DefineClass.XPrgHasVisitTime = {
	__parents = { "XPrgCondition" , "XPrgAmbientLifeCommand" },
	properties = {
		{ id = "unit", name = "Unit", default = "unit", editor = "combo", items = function(self) return self:UpdateLocalVarCombo() end },
	},
	Menubar = "Condition",
	MenubarSection = "",
}

---
--- Generates the condition code to check if a unit has visit time.
---
--- @param self XPrgHasVisitTime The instance of the XPrgHasVisitTime class.
---
--- If the `Not` property is true, the function returns a condition that checks if the unit has no visit time left. Otherwise, it returns a condition that checks if the unit has visit time remaining.
---
function XPrgHasVisitTime:GenConditionTreeView()
	if self.Not then
		return T(614538479407, "<unit> has no visit time")
	end
	return T(805860218823, "<unit> has visit time")
end

---
--- Generates the condition code to check if a unit has visit time.
---
--- @param self XPrgHasVisitTime The instance of the XPrgHasVisitTime class.
---
--- If the `Not` property is true, the function returns a condition that checks if the unit has no visit time left. Otherwise, it returns a condition that checks if the unit has visit time remaining.
---
function XPrgHasVisitTime:GenConditionCode(prgdata)
	if self.Not then
		return string.format('%s:VisitTimeLeft() == 0', self.unit)
	end
	return string.format('%s:VisitTimeLeft() > 0', self.unit)
end

DefineClass.XPrgCheckSpotFlags = {
	__parents = { "XPrgCondition", "XPrgAmbientLifeCommand" },
	properties = {
		{ id = "bld", name = "Building", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ id = "obj", name = "Object", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ id = "spot", name = "Spot", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ id = "slotname", name = "Slot name", editor = "text", default = "", validate = validate_var},
		{ id = "slot", name = "Slot", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ id = "flags_required", name = "Flags required", editor = "flags", size = PrgSlotFlagsUser, default = 0, items = PrgSlotFlags },
		{ id = "flags_missing", name = "Flags missing", editor = "flags", size = PrgSlotFlagsUser, default = 0, items = PrgSlotFlags },
	},
	Menubar = "Condition",
	MenubarSection = "",
}

---
--- Generates the condition code to check if a spot has the required and/or missing flags.
---
--- @param self XPrgCheckSpotFlags The instance of the XPrgCheckSpotFlags class.
---
--- If the `Not` property is true, the function returns a condition that checks if the spot does not have the required flags or has the missing flags. Otherwise, it returns a condition that checks if the spot has the required flags and does not have the missing flags.
---
--- @return string The condition code to check the spot flags.
---
function XPrgCheckSpotFlags:GenConditionTreeView()
	local not_text = self.Not and T(555910511517, "not") or ""
	if self.flags_required ~= 0 or self.flags_missing ~= 0 then
		return T{203979122439, "<not_text> <obj> <spot> required <flags_required>, missing <flags_missing>", not_text = not_text}
	elseif self.flags_required ~= 0 then
		return T{401424619805, "<not_text> <obj> <spot> required <flags_required>", not_text = not_text}
	elseif self.flags_missing ~= 0 then
		return T{638353608159, "<not_text> <obj> <spot> missing <flags_missing>", not_text = not_text}
	elseif self.Not then
		return T(622500851793, "false")
	else
		return T(728621261810, "true")
	end
end

---
--- Generates the condition code to check if a spot has the required and/or missing flags.
---
--- @param self XPrgCheckSpotFlags The instance of the XPrgCheckSpotFlags class.
--- @param prgdata table The program data.
--- @param level number The execution level.
---
--- If the `Not` property is true, the function returns a condition that checks if the spot does not have the required flags or has the missing flags. Otherwise, it returns a condition that checks if the spot has the required flags and does not have the missing flags.
---
--- @return string The condition code to check the spot flags.
---
function XPrgCheckSpotFlags:GenConditionCode(prgdata, level)
	local g_spot_type = self.slotname
	if g_spot_type == "" then
		local g_spot_type = PrgGetFreeVarName(prgdata, "_spot_type")
		PrgNewVar(g_spot_type, prgdata.exec_scope, prgdata)
		PrgAddExecLine(prgdata, level, string.format('%s = %s and IsValid(%s) and obj:GetSpotName(%s) or ""', g_spot_type, self.spot, self.obj, self.spot))
	end
	local slot = self.slot ~= "" and self.slot or "nil"
	local flags = string.format('PrgChangeSpotFlags(%s, %s, %s, %d, %d, %s, %s)', self.bld, self.obj, self.spot, 0, 0, g_spot_type, slot)
	local condition
	local cmp = self.Not and "~=" or "=="
	if self.flags_required ~= 0 and self.flags_missing ~= 0 then
		condition = string.format('band(%s, bor(%s, %s)) %s %s', flags, self.flags_required, self.flags_missing, cmp, self.flags_required)
	elseif self.flags_required ~= 0 then
		condition = string.format('band(%s, %s) %s %s', flags, self.flags_required, cmp, self.flags_required)
	elseif self.flags_missing ~= 0 then
		condition = string.format('band(%s, %s) %s 0', flags, self.flags_missing, cmp)
	elseif self.Not then
		condition = "false"
	else
		condition = "true"
	end
	return condition
end

-- GetSpotName
DefineClass.XPrgGetSpotName = {
	__parents = { "XPrgAmbientLifeCommand" },
	properties = {
		{ category = "Select", id = "obj", name = "Object", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Select", id = "spot", name = "Spot var", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Variables", id = "var_slotname", name = "Slot Name", editor = "text", default = "", validate = validate_var},
	},
	Menubar = "Object",
	MenubarSection = "Select",
	TreeView = T(256648612496, "<var_slotname> = Name of <obj> <spot>"),
}

---
--- Generates the code to get the name of a spot for an object.
---
--- @param prgdata table The program data.
--- @param level number The execution level.
---
--- This function generates the code to get the name of a spot for an object. It first checks if the `var_slotname` property is empty, and if so, generates a new variable name using `PrgGetFreeVarName`. It then adds an execution line to the program data that assigns the spot name to the `var_slotname` variable.
---
--- @return void
---
function XPrgGetSpotName:GenCode(prgdata, level)
	PrgAddExecLine(prgdata, level, string.format('%s = %s and IsValid(%s) and obj:GetSpotName(%s) or ""', self.var_slotname, self.spot, self.obj, self.spot))
end

-- XPrgGetSlotFromSpot
DefineClass.XPrgGetSlotFromSpot = {
	__parents = { "XPrgAmbientLifeCommand" },
	properties = {
		{ category = "Select", id = "obj", name = "Object", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Select", id = "spot", name = "Spot var", editor = "combo", default = "" , items = function(self) return self:UpdateLocalVarCombo() end  },
		{ category = "Select", id = "slot_data", name = "Slot desc", editor = "text", default = "", validate = validate_var},
		{ category = "Variables", id = "var_slotname", name = "Slot Name", editor = "text", default = "", validate = validate_var},
		{ category = "Variables", id = "var_slot", name = "Slot", editor = "text", default = "", validate = validate_var},
	},
	Menubar = "Object",
	MenubarSection = "Select",
	TreeView = T(224239931056, "<var_slotname>, <var_slot> = Slot of <obj> <spot>"),
}

---
--- Generates the code to get the slot and slot name for an object's spot.
---
--- @param prgdata table The program data.
--- @param level number The execution level.
---
--- This function generates the code to get the slot and slot name for an object's spot. It first checks if the `var_slotname` property is empty, and if so, generates a new variable name using `PrgGetFreeVarName`. It then adds an execution line to the program data that assigns the slot name to the `var_slotname` variable.
---
--- If the `var_slot` property is not empty, it generates a new variable for the slot and adds an execution line to the program data that assigns the slot and slot name using `PrgGetSlotBySpot`.
---
--- @return void
---
function XPrgGetSlotFromSpot:GenCode(prgdata, level)
	local slotname = self.var_slotname
	if slotname == "" then
		slotname = PrgGetFreeVarName(prgdata, "_slotname")
	end
	PrgNewVar(slotname, prgdata.exec_scope, prgdata)
	local slot = self.var_slot
	if slot == "" then
		PrgAddExecLine(prgdata, level, string.format('%s = %s and IsValid(%s) and obj:GetSpotName(%s) or ""', slotname, self.spot, self.obj, self.spot))
		return
	end
	PrgNewVar(slot, prgdata.exec_scope, prgdata)
	if self.slot_data ~= "" then
		PrgAddExecLine(prgdata, level, string.format('%s, %s = PrgGetSlotBySpot(%s, %s, %s)', slot, slotname, self.obj, self.spot, self.slot_data))
	else
		PrgAddExecLine(prgdata, level, string.format('%s, %s = PrgGetSlotBySpot(%s, %s)', slot, slotname, self.obj, self.spot))
	end
end

-- GetSpotPos
DefineClass.XPrgGetSpotPos = {
	__parents = { "XPrgAmbientLifeCommand" },
	properties = {
		{ category = "Select", id = "obj", name = "Object", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Select", id = "spot_var", name = "Spot var", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Variables", id = "var_pos", name = "Pos", editor = "text", default = "", validate = validate_var},
	},
	Menubar = "Object",
	MenubarSection = "Select",
	TreeView = T(474325559146, "<var_pos> = Position of <obj> <spot_var>"),
}

---
--- Generates the code to get the position of an object's spot.
---
--- @param prgdata table The program data.
--- @param level number The execution level.
---
--- This function generates the code to get the position of an object's spot. It first constructs a string that retrieves the spot location position using the `GetSpotLocPos` method of the object and the `spot_var` property.
---
--- If the `var_pos` property is not empty, it generates a new variable for the position and adds an execution line to the program data that assigns the resolved position to the `var_pos` variable.
---
--- @return void
---
function XPrgGetSpotPos:GenCode(prgdata, level)
	local resolved_pos = string.format('%s:GetSpotLocPos(%s)', self.obj, self.spot_var)
	local var_pos = self.var_pos ~= "" and self.var_pos
	if var_pos then
		PrgNewVar(var_pos, prgdata.exec_scope, prgdata)
		PrgAddExecLine(prgdata, level, string.format('%s = %s', var_pos, resolved_pos))
	end
end

-- GetWaypointsPos
DefineClass.XPrgGetWaypointsPos = {
	__parents = { "XPrgAmbientLifeCommand" },
	properties = {
		{ category = "Select", id = "obj", name = "Obj", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Select", id = "waypoints_var", name = "Waypoints var", editor = "text", default = "" },
		{ category = "Select", id = "waypoints_idx", name = "Waypoints index", editor = "text", default = "" },
		{ category = "Select", id = "fallback_pos", name = "Fallback pos", editor = "text", default = "" },
		{ category = "Variables", id = "var_pos", name = "Pos", editor = "text", default = "", validate = validate_var},
	},
	Menubar = "Object",
	MenubarSection = "Select",
	TreeView = T{406734142728, "<var_pos> = Position of <obj> <waypoints_var>[<idx>]",
		idx = function(obj)
			return obj.waypoints_idx ~= "" and T(198459076916, "<waypoints_idx>") or T(438475026383, "last")
		end,
	},
}

---
--- Generates the code to get the position of an object's waypoints.
---
--- @param prgdata table The program data.
--- @param level number The execution level.
---
--- This function generates the code to get the position of an object's waypoints. It first constructs a string that retrieves the waypoint location position using the `waypoints_var` property.
---
--- If the `waypoints_idx` property is not empty, it generates a conditional expression to retrieve the waypoint at the specified index, or the last waypoint if the index is not valid.
---
--- If the `var_pos` property is not empty, it generates a new variable for the position and adds an execution line to the program data that assigns the resolved position to the `var_pos` variable. If the `fallback_pos` property is not empty, it includes that as a fallback position in the assignment.
---
--- @return void
---
function XPrgGetWaypointsPos:GenCode(prgdata, level)
	local resolved_pos
	if self.waypoints_idx == "" then
		resolved_pos = string.format('%s[#%s]', self.waypoints_var, self.waypoints_var)
	elseif self.waypoints_idx == "1" then
		resolved_pos = string.format('%s[1]', self.waypoints_var)
	else
		resolved_pos = string.format('(%s[%s] or %s[#%s])', self.waypoints_var, self.waypoints_idx, self.waypoints_var, self.waypoints_var)
	end
	local var_pos = self.var_pos
	if var_pos ~= "" then
		PrgNewVar(var_pos, prgdata.exec_scope, prgdata)
		local txt = string.format('%s = %s and %s', var_pos, self.waypoints_var, resolved_pos)
		if self.fallback_pos ~= "" then
			txt = string.format('%s or %s', txt, self.fallback_pos)
		end
		PrgAddExecLine(prgdata, level, txt)
	end
end

-- NearestSpot
DefineClass.XPrgNearestSpot = {
	__parents = { "XPrgAmbientLifeCommand" },
	properties = {
		{ category = "Select", id = "obj", name = "Object", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Select", id = "spot_type", name = "Object spot", editor = "text", default = "" },
		{ category = "Select", id = "target", name = "Target", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Variables", id = "var_spot", name = "Spot", editor = "text", default = "", validate = validate_var},
		{ category = "Variables", id = "var_pos", name = "Pos", editor = "text", default = "", validate = validate_var},
	},
	Menubar = "Object",
	MenubarSection = "Select",
	TreeView = T(337758260894, "<var_spot> <var_pos> = Nearest spot <spot_type> to <target>"),
}

---
--- Generates the code to get the nearest spot of a specified type for a given target object.
---
--- @param prgdata table The program data.
--- @param level number The execution level.
---
--- This function generates the code to get the nearest spot of a specified type for a given target object. It first constructs a string that retrieves the nearest spot using the `GetNearestSpot` method of the `obj` object, passing the `spot_type` and `target` as arguments.
---
--- If the `var_spot` property is not empty, it generates a new variable for the spot and adds an execution line to the program data that assigns the resolved spot to the `var_spot` variable.
---
--- If the `var_pos` property is not empty, it generates a new variable for the position and adds an execution line to the program data that assigns the position of the spot to the `var_pos` variable.
---
--- @return void
---
function XPrgNearestSpot:GenCode(prgdata, level)
	local resolved_spot = string.format('%s:GetNearestSpot("%s", %s)', self.obj, self.spot_type, self.target)
	local var_spot = self.var_spot ~= "" and self.var_spot
	local var_pos = self.var_pos ~= "" and self.var_pos
	if var_spot or var_pos then
		var_spot = var_spot or "_spot"
		PrgNewVar(var_spot, prgdata.exec_scope, prgdata)
		PrgAddExecLine(prgdata, level, string.format('%s = %s', var_spot, resolved_spot))
	end
	if var_pos then
		PrgNewVar(var_pos, prgdata.exec_scope, prgdata)
		PrgAddExecLine(prgdata, level, string.format('%s = %s:GetSpotLocPos(%s)', var_pos, self.obj, var_spot))
	end
end

-- RandomSpot
DefineClass.XPrgRandomSpot = {
	__parents = { "XPrgAmbientLifeCommand" },
	properties = {
		{ category = "Select", id = "obj", name = "Object", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Select", id = "spot_type", name = "Object spot", editor = "text", default = "" },
		{ category = "Variables", id = "var_spot", name = "Spot", editor = "text", default = "", validate = validate_var},
		{ category = "Variables", id = "var_pos", name = "Pos", editor = "text", default = "", validate = validate_var},
	},
	Menubar = "Object",
	MenubarSection = "Select",
	TreeView = T(505114548882, "<var_spot> <var_pos> = Random spot <spot_type>"),
}

---
--- Generates the code to get a random spot of a specified type for a given object.
---
--- @param prgdata table The program data.
--- @param level number The execution level.
---
--- This function generates the code to get a random spot of a specified type for a given object. It first constructs a string that retrieves a random spot using the `GetRandomSpot` method of the `obj` object, passing the `spot_type` as an argument.
---
--- If the `var_spot` property is not empty, it generates a new variable for the spot and adds an execution line to the program data that assigns the resolved spot to the `var_spot` variable.
---
--- If the `var_pos` property is not empty, it generates a new variable for the position and adds an execution line to the program data that assigns the position of the spot to the `var_pos` variable.
---
--- @return void
---
function XPrgRandomSpot:GenCode(prgdata, level)
	local resolved_spot = string.format('%s:GetRandomSpot("%s")', self.obj, self.spot_type)
	local var_spot = self.var_spot ~= "" and self.var_spot
	local var_pos = self.var_pos ~= "" and self.var_pos
	if var_spot or var_pos then
		var_spot = var_spot or "_spot"
		PrgNewVar(var_spot, prgdata.exec_scope, prgdata)
		PrgAddExecLine(prgdata, level, string.format('%s = %s', var_spot, resolved_spot))
	end
	if var_pos then
		PrgNewVar(var_pos, prgdata.exec_scope, prgdata)
		PrgAddExecLine(prgdata, level, string.format('%s = %s:GetSpotLocPos(%s)', var_pos, self.obj, var_spot))
	end
end

-- SelectWaypoints
DefineClass.XPrgSelectWaypoints = {
	__parents = { "XPrgAmbientLifeCommand" },
	properties = {
		{ category = "Select", id = "obj", name = "Obj", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Select", id = "waypoints", name = "Waypoints name", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Select", id = "first_target", name = "Waypoints start", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Select", id = "first_target_range", name = "Waypoints start range", editor = "combo", default = tostring(spot_proximity_dist), items = {tostring(spot_proximity_dist), "Nearest"} },
		{ category = "Select", id = "last_target", name = "Waypoints end", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Select", id = "last_target_range", name = "Waypoints end range", editor = "combo", default = tostring(spot_proximity_dist), items = {tostring(spot_proximity_dist), "Nearest"}},
		{ category = "Variables", id = "var_waypoints", name = "Waypoints", editor = "text", default = "", validate = validate_var },
	},
	Menubar = "Object",
	MenubarSection = "Select",
	TreeView = T(449306746296, "<var_waypoints> = Find <waypoints>(start:<first_target>, end:<last_target>)"),
}

---
--- Generates the code to find a set of waypoints within a specified range for a given object.
---
--- @param prgdata table The program data.
--- @param level number The execution level.
---
--- This function generates the code to find a set of waypoints within a specified range for a given object. It first constructs a string that retrieves the waypoints using the `FindWaypointsInRange` method of the `obj` object, passing the `waypoints` name, the `first_target` and `first_target_range` for the start of the range, and the `last_target` and `last_target_range` for the end of the range.
---
--- If the `var_waypoints` property is not empty, it generates a new variable for the waypoints and adds an execution line to the program data that assigns the resolved waypoints to the `var_waypoints` variable.
---
--- @return void
---
function XPrgSelectWaypoints:GenCode(prgdata, level)
	local target1 = self.first_target == "" and "nil" or self.first_target
	local target2 = self.last_target == "" and "nil" or self.last_target
	local first_range = self.first_target_range == "Nearest" and '"Nearest"' or self.first_target_range
	local last_range = self.last_target_range == "Nearest" and '"Nearest"' or self.last_target_range
	local resolved_wp = string.format('%s:FindWaypointsInRange("%s", %s, %s, %s, %s)', self.obj, self.waypoints, first_range, target1, last_range, target2)
	local wp_var = self.var_waypoints == "" and "_path" or self.var_waypoints
	if wp_var then
		PrgNewVar(wp_var, prgdata.exec_scope, prgdata)
		PrgAddExecLine(prgdata, level, string.format('%s = %s', wp_var, resolved_wp))
	end
end

-- NearestAttach
DefineClass.XPrgNearestAttach = {
	__parents = { "XPrgAmbientLifeCommand" },
	properties = {
		{ category = "Select", id = "bld", name = "Building", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Select", id = "classname", name = "Classname", editor = "text", default = "" },
		{ category = "Select", id = "spot_type", name = "Spot name", editor = "text", default = "" },
		{ category = "Select", id = "target", name = "Target", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Select", id = "eval", name = "Eval", editor = "dropdownlist", default = "Nearest", items = { "Nearest", "Nearest2D" } },
		{ category = "Variables", id = "var_obj", name = "Object", editor = "text", default = "", validate = validate_var },
	},
	Menubar = "Object",
	MenubarSection = "",
	TreeView = T(753077944149, "<var_obj> = Nearest <classname> to <target>"),
}

---
--- Generates the code to find the nearest object of a given class attached to a target object.
---
--- @param prgdata table The program data.
--- @param level number The execution level.
---
--- This function generates the code to find the nearest object of a given class that is attached to a target object. It first constructs a string that calls the `PrgGetNearestAttach` function, passing the appropriate evaluation method (`Nearest` or `Nearest2D`), the spot type, the target object, the building object, and the class name of the object to find.
---
--- If the `var_obj` property is not empty, it generates a new variable for the object and adds an execution line to the program data that assigns the resolved object to the `var_obj` variable.
---
--- @return void
---
function XPrgNearestAttach:GenCode(prgdata, level)
	local eval = self.eval == "Nearest2D" and "IsCloser2D" or "IsCloser"
	local resolved_obj = string.format('PrgGetNearestAttach(%s, "%s", %s, %s, "%s")', eval, self.spot_type, self.target, self.bld, self.classname)
	local var_obj = self.var_obj ~= "" and self.var_obj or "_obj"
	PrgNewVar(var_obj, prgdata.exec_scope, prgdata)
	PrgAddExecLine(prgdata, level, string.format('%s = %s', var_obj, resolved_obj))
end


---
--- Finds the nearest object of a given class that is attached to a target object.
---
--- @param eval string The evaluation method to use, either "IsCloser" or "IsCloser2D".
--- @param spot_type string The name of the spot type to use for the attachment.
--- @param target table The target object to find the nearest attached object for.
--- @param bld table The building object that the attached object is attached to.
--- @param attach_classname string The class name of the object to find.
--- @return table The nearest attached object, or nil if none found.
---
function PrgGetNearestAttach(eval, spot_type, target, bld, attach_classname)
	if not IsValid(bld) then
		return
	end
	return PrgGetNearestObject(eval, spot_type, target, bld:GetAttach(attach_classname))
end

---
--- Finds the nearest object from a list of objects attached to a target object.
---
--- @param eval function The evaluation function to use, either `IsCloser` or `IsCloser2D`.
--- @param spot_type string The name of the spot type to use for the attachment.
--- @param target table The target object to find the nearest attached object for.
--- @param best_obj table The current best object found.
--- @param attach2 table The second object to check for attachment.
--- @param attach3 table The third object to check for attachment.
--- @param ... table Any additional objects to check for attachment.
--- @return table The nearest attached object, or the current `best_obj` if no better object is found.
---
function PrgGetNearestObject(eval, spot_type, target, best_obj, attach2, attach3, ...)
	if attach2 then
		if spot_type and spot_type ~= "" and spot_type ~= "Origin" then
			if eval(target, attach2:GetSpotLocPos(attach2:GetSpotBeginIndex(spot_type)), best_obj:GetSpotLocPos(best_obj:GetSpotBeginIndex(spot_type))) then
				best_obj = attach2
			end
		elseif eval(target, attach2, best_obj) then
			best_obj = attach2
		end
		if attach3 then
			best_obj = PrgGetNearestObject(eval, spot_type, target, best_obj, attach3, ...)
		end
	end
	return best_obj
end

-- Use object
local UseObjectCombo = { "", "Use", "Open", "Open2", "Close" }

DefineClass.XPrgUseObject = {
	__parents = { "XPrgAmbientLifeCommand" },
	properties = {
		{ id = "obj", name = "Object", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ id = "action", name = "Action", editor = "combo", default = "Use", items = UseObjectCombo },
		{ id = "action_var", name = "Action Var", editor = "text", default = "" },
		{ id = "param1", name = "Param 1", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ id = "param2", name = "Param 2", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ id = "dtor_action", name = "Dtor action", editor = "combo", default = "", items = UseObjectCombo },
	},
	Menubar = "Game",
	MenubarSection = "",
	TreeView = T{221014920931, "<txt>",
		txt = function(obj)
			local params = obj:GetParams()
			if params ~= "" then
				params = T{229548576744, "<params>", params = Untranslated(params) }
			end
			local text1
			if obj.action ~= "" then
				text1 = T{709667218989, "<action> <obj> <params>", params = params }
			elseif obj.action_var ~= "" then
				text1 = T{988466378489, "<obj> action: <action_var> <params>", params = params }
			end
			local text2 = obj.dtor_action ~= "" and T{319120764798, "( Dtor <dtor_action> <obj> <params>)", params = params }
			return text1 and text2 and text1 .. "\n" .. text2 or text1 or text2 or ""
		end
	},
}

---
--- Returns the parameters for the XPrgUseObject command.
---
--- The parameters are constructed by concatenating the `param1` and `param2` properties of the XPrgUseObject instance.
---
--- @return string The parameters for the XPrgUseObject command.
function XPrgUseObject:GetParams()
	local params = ""
	if self.param2 ~= "" then params = params ~= "" and self.param2 .. ", " .. params or self.param2 end
	if self.param1 ~= "" then params = params ~= "" and self.param1 .. ", " .. params or self.param1 end
	return params
end

---
--- Generates the code for the XPrgUseObject command.
---
--- The function first checks if the `action` property is set. If it is, it generates a line of code that calls the `action` method on the `obj` object, passing in the `params` as arguments. It then adds a `VISIT_RESTART` line to the program data.
---
--- If the `action_var` property is set instead, it generates a line of code that calls the method specified by `action_var` on the `obj` object, passing in the `obj` object and the `params` as arguments. It then also adds a `VISIT_RESTART` line to the program data.
---
--- If the `dtor_action` property is set, it generates additional lines of code that will be executed when the object is destroyed. It first checks if the `action` property was set, and if so, it creates a new variable `_objaction` to store the `obj` object. It then adds a line to the destructor that calls the `dtor_action` method on the `obj` object, passing in the `params` as arguments.
---
--- @param prgdata table The program data to add the generated code to.
--- @param level number The level of the code block to add the generated code to.
function XPrgUseObject:GenCode(prgdata, level)
	local params = self:GetParams()
	if self.action ~= "" then
		PrgAddExecLine(prgdata, level, string.format('%s:%s(%s)', self.obj, self.action, params))
		PrgAddExecLine(prgdata, 0, "VISIT_RESTART")
	elseif self.action_var ~= "" then
		PrgAddExecLine(prgdata, level, string.format('%s[%s](%s%s)', self.obj, self.action_var, self.obj, params ~= "" and ", " .. params or ""))
		PrgAddExecLine(prgdata, 0, "VISIT_RESTART")
	end
	if self.dtor_action ~= "" then
		local g_obj = self.obj
		if self.action ~= "" then
			g_obj = PrgGetFreeVarName(prgdata, "_objaction")
			PrgNewVar(g_obj, prgdata.exec_scope, prgdata)
			PrgAddExecLine(prgdata, level, string.format('%s = %s', g_obj, self.obj))
		end
		PrgAddDtorLine(prgdata, 2, string.format('if IsValid(%s) then', g_obj))
		PrgAddDtorLine(prgdata, 3, string.format('%s:%s(%s)', g_obj, self.dtor_action, params))
		PrgAddDtorLine(prgdata, 2, string.format('end'))
	end
end

-- EnterInside
DefineClass.XPrgEnterInside = {
	__parents = { "XPrgAmbientLifeCommand" },
	properties = {
		{ category = "Select", id = "unit", name = "Unit", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
	},
	Menubar = "Game",
	MenubarSection = "",
	TreeView = T(643070862836, "Set <unit> inside"),
}

---
--- Sets the unit to be inside visually.
---
--- This function is called when the XPrgEnterInside command is executed. It sets the `outside` visual state of the specified `unit` to `false`, effectively making the unit appear inside.
---
--- @param prgdata table The program data to add the generated code to.
--- @param level number The level of the code block to add the generated code to.
function XPrgEnterInside:GenCode(prgdata, level)
	PrgAddExecLine(prgdata, level, string.format('%s:SetOutsideVisuals(false)', self.unit))
end

-- ExitOutside
DefineClass.XPrgExitOutside = {
	__parents = { "XPrgAmbientLifeCommand" },
	properties = {
		{ category = "Select", id = "unit", name = "Unit", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
	},
	Menubar = "Game",
	MenubarSection = "",
	TreeView = T(558482318624, "Set <unit> outside"),
}

---
--- Sets the unit to be outside visually.
---
--- This function is called when the XPrgExitOutside command is executed. It sets the `outside` visual state of the specified `unit` to `true`, effectively making the unit appear outside.
---
--- @param prgdata table The program data to add the generated code to.
--- @param level number The level of the code block to add the generated code to.
function XPrgExitOutside:GenCode(prgdata, level)
	PrgAddExecLine(prgdata, level, string.format('%s:SetOutsideVisuals(true)', self.unit))
end

-- SnapToSpot
DefineClass.XPrgSnapToSpot = {
	__parents = { "XPrgAmbientLifeCommand" },
	properties = {
		{ id = "actor", name = "Actor", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ id = "obj", name = "Object", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ id = "spot", name = "Spot var", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ id = "spot_type", name = "Spot name", editor = "text", default = "" },
		{ id = "attach", name = "Attach", editor = "bool", default = false },
		{ id = "offset", name = "Offset", editor = "point", default = point30, scale = "m" },
		{ id = "time", name = "Time", editor = "number", default = "200" },
	},
	Menubar = "Object",
	MenubarSection = "Orient",
	TreeView = T(700136323216, "Snap <actor> to <obj> <spot><color 0 128 0><comment>"),
}

---
--- Generates the code to snap an actor to a specified object and spot.
---
--- This function is called when the XPrgSnapToSpot command is executed. It generates the code to snap the specified `actor` to the specified `obj` and `spot`. If the `attach` property is false, it calls `GenCodeSetPos` to set the position of the actor. It then calls `GenCodeOrient` to orient the actor to the specified spot.
---
--- @param prgdata table The program data to add the generated code to.
--- @param level number The level of the code block to add the generated code to.
function XPrgSnapToSpot:GenCode(prgdata, level)
	if not self.attach then
		self:GenCodeSetPos(prgdata, level, self.actor, self.obj, self.spot, self.spot_type, self.offset, self.time)
	end
	self:GenCodeOrient(prgdata, level, self.actor, 1, self.obj, self.spot, self.spot_type, "SpotX 2D", self.attach, self.offset, self.time, true, false)
end


-- Define slot
DefineClass.XPrgDefineSlot = {
	__parents = { "XPrgAmbientLifeCommand" },
	properties = {
		{ category = "Slot", id = "groups", name = "Groups", editor = "text", default = "" },
		{ category = "Slot", id = "spot_type", name = "Spot name", editor = "text", default = "" },
		{ category = "Slot", id = "spot_state", name = "Spot state", editor = "combo", default = "", items = { "", "idle" } },
		{ category = "Slot", id = "attach", name = "Attach", editor = "text", default = "" },
		{ category = "Slot", id = "attach_attach", name = "Attach attach", editor = "text", default = "", no_edit = function(self) return self.attach == "" end },
		{ category = "Slot", id = "outside", name = "Slot Outside", editor = "bool", default = false },
		{ category = "Path", id = "move_start", name = "Move start", editor = "dropdownlist", default = "", items = { "", "Pathfind", "GoToExitSpot" }},
		{ category = "Path", id = "goto_spot", name = "Goto to slot", editor = "dropdownlist", default = "", items = { "", "LeadToSpot", "StraightLine", "Pathfind", "Teleport", "FollowPathWaypoints" }},
		{ category = "Path", id = "move_end", name = "Move end", editor = "dropdownlist", default = "", items = { "", "LeadToExit", "TeleportToExit" }},
		{ category = "Path", id = "custom_waypoints", name = "Custom waypoints", editor = "text", default = "" },
		{ category = "Path", id = "adjust_z", name = "Require passable Z", editor = "bool", default = false, help = "Prevent the actor from clipping into terrain by adjusting the z coordinate" },
		{ category = "Visit Flags", id = "flags_required", name = "Flags required", editor = "flags", size = PrgSlotFlagsUser, default = 0 , items = PrgSlotFlags },
		{ category = "Visit Flags", id = "flags_missing", name = "Flags missing", editor = "flags", size = PrgSlotFlagsUser, default = 0, items = PrgSlotFlags },

		{ id = "comment" },
	},
	Menubar = "Slot",
	MenubarSection = "",
	TreeView = T{180913368574, "Define slot <groups> <spots><color 0 128 0><comment>",
		spots = function(obj)
			return obj.spot_type ~= "" and T(333975580910, "(<spot_type>) ") or ""
		end,
	},
}

---
--- Generates the code to define a slot in the ambient life system.
---
--- This function is called when the XPrgDefineSlot command is executed. It generates the code to define a slot with the specified properties, such as groups, spot type, spot state, attach information, and path-related properties. The generated slot information is stored in the `_slots` external variable.
---
--- @param prgdata table The program data to add the generated code to.
--- @param level number The level of the code block to add the generated code to.
function XPrgDefineSlot:GenCode(prgdata, level)
	local t = {}
	local var = PrgNewVar("_slots", prgdata.external_vars, prgdata)
	var.value = var.value or {}
	table.insert(var.value, t)

	t.groups = t.groups or {}
	local list = PrgSplitStr(self.groups, ",")
	for i = 1, #list do
		t.groups[ list[i] ] = true
	end
	if self.spot_type ~= "" then
		t.spots = PrgSplitStr(self.spot_type, ",")
	end
	if self.spot_state ~= "" then
		t.spot_state = self.spot_state
	end
	if self.attach ~= "" then
		t.attach = self.attach
	end
	if self.attach_attach ~= "" then
		t.attach_attach = self.attach_attach
	end
	if self.outside then
		t.outside = self.outside
	end
	t.goto_spot = self.goto_spot
	if self.move_start ~= "" then
		t.move_start = self.move_start
	end
	if self.move_end ~= "" then
		t.move_end = self.move_end
	end
	if self.custom_waypoints ~= "" then
		t.custom_waypoints = self.custom_waypoints
	end
	if self.adjust_z ~= "" then
		t.adjust_z = self.adjust_z
	end
	if self.flags_required ~= 0 then
		t.flags_required = self.flags_required
	end
	if self.flags_missing ~= 0 then
		t.flags_missing = self.flags_missing
	end
	self:GenCustomProperties(t)
end

--- Generates custom properties for the slot.
---
--- @param t table The table to add the custom properties to.
function XPrgDefineSlot:GenCustomProperties(t)
end

-- Select slot
DefineClass.XPrgSelectSlot = {
	__parents = { "XPrgAmbientLifeCommand" },
	properties = {
		{ category = "Slot", id = "unit", name = "Unit", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end  },
		{ category = "Slot", id = "bld", name = "Building", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Slot", id = "group", name = "Group", editor = "text", default = "" },
		{ category = "Slot", id = "attach_var", name = "Attach Var", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Eval", id = "eval", name = "Eval", editor = "dropdownlist", default = "Random", items = { "Random", "Nearest" } },
		{ category = "Variables", id = "var_obj", name = "Object", editor = "text", default = "", validate = validate_var },
		{ category = "Variables", id = "var_spot", name = "Spot", editor = "text", default = "", validate = validate_var},
		{ category = "Variables", id = "var_slot_desc", name = "Slot desc", editor = "text", default = "", validate = validate_var},
		{ category = "Variables", id = "var_slot", name = "Slot", editor = "text", default = "", validate = validate_var},
		{ category = "Variables", id = "var_slotname", name = "Slot Name", editor = "text", default = "", validate = validate_var},
		{ category = "Variables", id = "var_pos", name = "Spot pos", editor = "text", default = "", validate = validate_var},
	},
	Menubar = "Slot",
	MenubarSection = "",
	TreeView = T{485397093579, "<vars> = Select slot <group>",
		vars = function(obj)
			local t
			if obj.var_obj ~= "" then t = (t and t .. ", " or "") .. obj.var_obj end
			if obj.var_spot ~= "" then t = (t and t .. ", " or "") .. obj.var_spot end
			if obj.var_slot_desc ~= "" then t = (t and t .. ", " or "") .. obj.var_slot_desc end
			if obj.var_pos ~= "" then t = (t and t .. ", " or "") .. obj.var_pos end
			return Untranslated(t or "_")
		end,
	},
}

--- Generates the code for selecting a slot.
---
--- @param prgdata table The program data.
--- @param level number The code level.
--- @param eval string The evaluation method ("Random" or "Nearest").
--- @param group string The group name.
--- @param attach_var string The attach variable.
--- @param bld string The building variable.
--- @param unit string The unit variable.
--- @param var_spot string The spot variable.
--- @param var_obj string The object variable.
--- @param var_pos string The position variable.
--- @param var_slot_desc string The slot description variable.
--- @param var_slot string The slot variable.
--- @param var_slotname string The slot name variable.
function XPrgSelectSlot:GenCode(prgdata, level)
	self:GenCodeSelectSlot(prgdata, level, self.eval, self.group, self.attach_var, self.bld, self.unit, self.var_spot, self.var_obj, self.var_pos, self.var_slot_desc, self.var_slot, self.var_slotname)
end

-- Visit selected slot
DefineClass.XPrgVisitSelectedSlot = {
	__parents = { "XPrgAmbientLifeCommand" },
	properties = {
		{ category = "Slot", id = "unit", name = "Unit", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Slot", id = "bld", name = "Building", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Slot", id = "obj", name = "Object", editor = "combo", default = "", validate = validate_var, items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Slot", id = "spot", name = "Spot", editor = "combo", default = "", validate = validate_var, items = function(self) return self:UpdateLocalVarCombo() end  },
		{ category = "Slot", id = "slot_desc", name = "Slot desc", editor = "text", default = "", validate = validate_var},
		{ category = "Slot", id = "slot", name = "Slot", editor = "combo", default = "", validate = validate_var, items = function(self) return self:UpdateLocalVarCombo() end  },
		{ category = "Slot", id = "slotname", name = "Slot Name", editor = "text", default = "", validate = validate_var},
		{ category = "Slot", id = "time", name = "Time", editor = "text", default = "" },
		{ category = "Slot", id = "visits_count", name = "Visits Count", editor = "text", default = "" },
	},
	Menubar = "Slot",
	MenubarSection = "",
	TreeView = T(656943101894, "Visit selected <obj> <spot>"),
}

--- Generates the code for visiting a selected slot.
---
--- @param prgdata table The program data.
--- @param level number The code level.
--- @param unit string The unit variable.
--- @param bld string The building variable.
--- @param obj string The object variable.
--- @param spot string The spot variable.
--- @param slot_desc string The slot description variable.
--- @param slot string The slot variable.
--- @param slotname string The slot name variable.
--- @param time string The time variable.
--- @param visits_count string The visits count variable.
function XPrgVisitSelectedSlot:GenCode(prgdata, level)
	local slot = self.slot ~= "" and self.slot or "nil"
	local slotname = self.slotname ~= "" and self.slotname or "nil"
	local visit_time = self.time == "" and "nil" or self.time
	local visits_count = (self.visits_count == "" or self.visits_count == "1") and "nil" or self.visits_count
	local visit_params = { self.unit, self.bld, self.obj, self.spot, self.slot_desc, slot, slotname, visit_time, visits_count }
	--[[while visit_params[#visit_params] == "nil" do
		visit_params[#visit_params] = nil
	end]]
	local params = prgdata.params
	local prg_params = ""
	-- skip params 1 and 2, because they are self.unit and self.bld
	if params[3] and (params[3].name or "") ~= "" then
		prg_params = {""}
		for i = 3, #params do
			local name = params[i].name
			if (name or "") ~= "" then
				prg_params[i-1] = name
			end
		end
		prg_params = table.concat(prg_params, ", ")
	end
	PrgAddExecLine(prgdata, level, string.format('PrgVisitSlot(%s%s)', table.concat(visit_params, ", "), prg_params))
	PrgAddExecLine(prgdata, 0, "VISIT_RESTART")
end

-- Visit slot
DefineClass.XPrgVisitSlot = {
	__parents = { "XPrgAmbientLifeCommand" },
	properties = {
		{ category = "Slot", id = "unit", name = "Unit", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Slot", id = "bld", name = "Building", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Slot", id = "group", name = "Group", editor = "text", default = "" },
		{ category = "Slot", id = "group_fallback", name = "Alt Group", editor = "text", default = "" },
		{ category = "Slot", id = "time", name = "Time", editor = "text", default = "" },
		{ category = "Slot", id = "visits_count", name = "Visits Count", editor = "text", default = "" },
		{ category = "Slot", id = "attach_var", name = "Attach Var", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Eval", id = "eval", name = "Eval", editor = "dropdownlist", default = "Random", items = { "Random", "Nearest" } },
		{ category = "Variables", id = "var_obj", name = "Object", editor = "text", default = "", validate = validate_var },
		{ category = "Variables", id = "var_spot", name = "Spot", editor = "text", default = "", validate = validate_var},
		{ category = "Variables", id = "var_slot", name = "Slot", editor = "text", default = "", validate = validate_var},
		{ category = "Variables", id = "var_slotname", name = "Slot Name", editor = "text", default = "", validate = validate_var},
	},
	Menubar = "Slot",
	MenubarSection = "",
	TreeView = T{818935413042, "Visit slot <group><fallback>",
		fallback = function(obj)
			return obj.group_fallback ~= "" and T(142787057654, " (fallback: <group_fallback>)") or ""
		end},
}

---
--- Generates the code for visiting a slot in the ambient life system.
---
--- @param prgdata table The program data object.
--- @param level number The current code generation level.
---
function XPrgVisitSlot:GenCode(prgdata, level)
	local slots_var = PrgNewVar("_slots", prgdata.external_vars, prgdata)
	slots_var.value = slots_var.value or {}
	local slots = slots_var.value

	local attach_var = self.attach_var ~= "" and self.attach_var or nil
	local groups = { self.group, self.group_fallback }
	local cur_level = level
	for i = 1, #groups do
		local group = groups[i]
		local group_present
		for j = 1, #slots do
			if slots[j].groups[group] then
				group_present = true
				break
			end
		end
		if group_present then
			local var_obj = self.var_obj ~= "" and self.var_obj or "_obj"
			local var_spot = self.var_spot ~= "" and self.var_spot or "_spot"
			local var_slot = self.var_slot ~= "" and self.var_slot or "_slot"
			local var_slotname = self.var_slotname ~= "" and self.var_slotname or "_slotname"
			local var_slot_desc = "_slot_desc"
			local visit_time = self.time == "" and "nil" or self.time
			local visits_count = (self.visits_count == "" or self.visits_count == "1") and "nil" or self.visits_count
			if cur_level > level then
				PrgAddExecLine(prgdata, cur_level - 1, 'else')
			end
			self:GenCodeSelectSlot(prgdata, cur_level, self.eval, group, attach_var, self.bld, self.unit, var_spot, var_obj, nil, var_slot_desc, var_slot, var_slotname)
			PrgAddExecLine(prgdata, cur_level, string.format('if %s then', var_spot))
			local visit_params = { self.unit, self.bld, var_obj, var_spot, var_slot_desc, var_slot, var_slotname, visit_time, visits_count }
			--[[while visit_params[#visit_params] == "nil" do
				visit_params[#visit_params] = nil
			end]]
			local params = prgdata.params
			local prg_params = ""
			-- skip params 1 and 2, because they are self.unit and self.bld
			if params[3] and (params[3].name or "") ~= "" then
				prg_params = {""}
				for i = 3, #params do
					local name = params[i].name
					if (name or "") ~= "" then
						prg_params[i-1] = name
					end
				end
				prg_params = table.concat(prg_params, ", ")
			end
			PrgAddExecLine(prgdata, cur_level + 1, string.format('PrgVisitSlot(%s%s)', table.concat(visit_params, ", "), prg_params))
			PrgAddExecLine(prgdata, 0, "VISIT_RESTART")
			cur_level = cur_level + 1
		elseif group == "Holder" then
			if cur_level > level then
				PrgAddExecLine(prgdata, cur_level - 1, 'else')
			end
			if self.time ~= "" then
				PrgAddExecLine(prgdata, cur_level, string.format('PrgVisitHolder(%s, %s, %s, %s)', self.unit, self.bld, self.bld, self.time))
			elseif attach_var then
				PrgAddExecLine(prgdata, cur_level, string.format('PrgVisitHolder(%s, %s, %s)', self.unit, self.bld, self.bld))
			else
				PrgAddExecLine(prgdata, cur_level, string.format('PrgVisitHolder(%s, %s)', self.unit, self.bld))
			end
			PrgAddExecLine(prgdata, 0, "VISIT_RESTART")
			break
		elseif group == "Exit" then
			if cur_level > level then
				PrgAddExecLine(prgdata, cur_level - 1, 'else')
			end
			PrgAddExecLine(prgdata, cur_level, string.format('if %s:IsValidPos() then', self.unit))
			PrgAddExecLine(prgdata, cur_level + 1, string.format('PrgLeadToBldPos(%s, %s, %s)', self.unit, self.bld, self.bld))
			PrgAddExecLine(prgdata, 0, "VISIT_RESTART")
			PrgAddExecLine(prgdata, cur_level, 'end')
			break
		end
	end
	for l = cur_level-1, level, -1 do
		PrgAddExecLine(prgdata, l, 'end')
	end
end

-- Attach body part
DefineClass.XPrgAttachBodyPart = {
	__parents = { "XPrgAmbientLifeCommand" },
	properties = {
		{ id = "obj",       name = "Object",    editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end, },
		{ id = "detach",    name = "Detach",    editor = "bool", default = false, },
		{ id = "reason",    name = "Reason",    editor = "text", default = "", },
		{ id = "classname", name = "Classname", editor = "text", default = "", no_edit = function(obj) return obj.detach end },
	},
	Menubar = "Object",
	MenubarSection = "",
	ActionName = "Attach Body Part",
	TreeView = T{718900601620, "<action> body part <classname> <color 0 128 0><comment>", action = function(obj) return obj.detach and T(229010438406, "Detach") or T(414612643342, "Attach") end, },
}

---
--- Attaches or detaches an additional body part to the specified object.
---
--- @param prgdata table The program data to add the code to.
--- @param level number The current level of the program.
---
function XPrgAttachBodyPart:GenCode(prgdata, level)
	if self.classname == "" then return end
	if self.detach then
		PrgAddExecLine(prgdata, level, string.format('%s:RemoveAdditionalBodyPart("%s")', self.obj, self.reason))
	else
		PrgAddExecLine(prgdata, level, string.format('%s:AddAdditionalBodyPart("%s", "%s")', self.obj, self.reason, self.classname))
	end
end