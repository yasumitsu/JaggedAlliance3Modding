local MaxSlabMoveTiles = const.MaxSlabMoveTiles
local MaxSlabMoveTilesZ = const.MaxSlabMoveTilesZ
local tilex = const.SlabSizeX
local tiley = const.SlabSizeY
local tilez = const.SlabSizeZ
local sqrt2_10000 = sqrt(2 * 10000 * 10000)
local IsPassable = terrain.IsPassable
local GetTerrainHeight = terrain.GetHeight

TunnelExplorationAdditionalCosts = {
	SlabTunnelDrop1 = "ExplorationActionMovesModifierWeak",
	SlabTunnelDrop2 = "ExplorationActionMovesModifierWeak",
	SlabTunnelDrop3 = "ExplorationActionMovesModifierStrong",
	SlabTunnelDrop4 = "ExplorationActionMovesModifierStrong",
	SlabTunnelClimb1 = "ExplorationActionMovesModifierWeak",
	SlabTunnelClimb2 = "ExplorationActionMovesModifierWeak",
	SlabTunnelClimb3 = "ExplorationActionMovesModifierStrong",
	SlabTunnelClimb4 = "ExplorationActionMovesModifierStrong",
	SlabTunnelJumpOver1 = "ExplorationActionMovesModifierStrong",
	SlabTunnelJumpOver2 = "ExplorationActionMovesModifierStrong",
	SlabTunnelJumpAcross1 = "ExplorationActionMovesModifierWeak",
	SlabTunnelJumpAcross2 = "ExplorationActionMovesModifierWeak",
	SlabTunnelWindow = "ExplorationActionMovesModifierStrong",
}

---
--- Returns the cost of traversing the given tunnel in the provided context.
---
--- @param tunnel TunnelObject The tunnel object to get the cost for.
--- @param context table The context to use for calculating the cost.
--- @return number The cost of traversing the tunnel.
---
function GetTunnelCost(tunnel, context)
	return tunnel:GetCost(context)
end

---
--- Modifies the action point cost for a given action ID.
---
--- @param value number The current action point cost.
--- @param id string The ID of the action.
--- @return number The modified action point cost.
---
function ModifyAPCost(value, id)
	local consts = Presets.ConstDef["Action Point Costs"]
	local data = consts[id]
	if data.scale == "%" then
		value = value + MulDivTrunc(value, data.value, 100)
	else
		value = value + data.value * 1000
	end
	return value
end

---
--- Returns the tunnel object that matches the given position and angle.
---
--- @param pos table The position to search for tunnels.
--- @param angle number The angle to match the tunnel orientation.
--- @param mask number A bitmask to filter the tunnel types.
--- @return TunnelObject|nil The tunnel object that matches the criteria, or nil if not found.
---
function GetTunnelDir(pos, angle, mask)
	local tunnel
	pf.ForEachTunnel(pos, function(obj)
		if obj.tunnel_type & mask == 0 then
			return
		end
		if CalcOrientation(obj:GetEntrance(), obj:GetExit()) ~= angle then
			return
		end
		tunnel = obj
		return true
	end)
	return tunnel
end

DefineClass.TunnelObject = {
	__parents = { "CObject" },
}

---
--- Places the tunnel objects in the game world.
---
function TunnelObject:PlaceTunnels()
end

---
--- Returns the width of the tunnel object, based on the object's size.
---
--- @return number The width of the tunnel object.
---
function TunnelObject:GetWidthForTunnels()
	local width = self:HasMember("width") and self.width or nil
	if not width then
		local bb = self:GetEntityBBox("idle")
		width = (bb:sizey() + const.SlabSizeY / 2) / const.SlabSizeY
	end
	return Max(width, 1)
end

DefineClass.TunnelBlocker = {
	__parents = { "Object" },
	flags = { efVisible = false, efPathExecObstacle = true, cofComponentPath = true, efResting = true },
	owner = false,
	tunnel_end_point = false,
}

--- Returns the tunnel object associated with the TunnelBlocker.
---
--- @return TunnelObject|nil The tunnel object, or nil if not found.
function TunnelBlocker:GetTunnel()
	return pf.GetTunnel(self:GetPos(), self.tunnel_end_point)
end

DefineClass.SlabTunnel = {
	__parents = { "PFTunnel" },
	flags = { efVisible = false },
	end_point = false,
	tunnel_type = 0,
	can_sprint_through = false,
	base_cost = false,
	modifier = 0,
	traverse_params = false,
	exploration_additional_cost = false,
}

---
--- Adds a new path-finding tunnel to the game world.
---
--- @param pos1 table The entrance position of the tunnel.
--- @param pos2 table The exit position of the tunnel.
--- @param exploration_cost number The additional cost for exploring the tunnel.
--- @param tunnel_type number The type of the tunnel.
---
function SlabTunnel:AddPFTunnel()
	local pos1 = self:GetEntrance()
	local pos2 = self:GetExit()
	if not self.exploration_additional_cost then
		self.exploration_additional_cost = GetSpecialMoveAPCost(TunnelExplorationAdditionalCosts[self.class]) or 0
	end
	local exploration_cost = self.base_cost * (100 + self.modifier) / 100 + self.exploration_additional_cost * (GetSpecialMoveAPCost("Walk") or 0)
	pf.AddTunnel(self, pos1, pos2, exploration_cost, self.tunnel_type, -1)
end

---
--- Removes a path-finding tunnel from the game world.
---
--- @param self SlabTunnel The SlabTunnel object.
---
function SlabTunnel:RemovePFTunnel()
	pf.RemoveTunnel(self, self:GetPos(), self.end_point)
end

--- Returns the entrance position of the tunnel.
---
--- @return table The entrance position of the tunnel.
function SlabTunnel:GetEntrance()
	return self:GetPos()
end

--- Returns the exit position of the tunnel.
---
--- @return table The exit position of the tunnel.
function SlabTunnel:GetExit()
	return self.end_point
end

--- Returns whether the tunnel can be sprinted through.
---
--- @return boolean Whether the tunnel can be sprinted through.
function SlabTunnel:CanSprintThrough()
	return self.can_sprint_through
end

---
--- Interacts with the tunnel.
---
--- @param unit table The unit interacting with the tunnel.
--- @param quick_play boolean Whether the interaction is part of a quick play.
--- @return boolean, boolean Whether the interaction was successful, and whether it was a quick play.
---
function SlabTunnel:InteractTunnel(unit, quick_play)
	return true, quick_play
end

---
--- Traverses the tunnel, setting the position of the unit to the exit position.
---
--- @param unit table The unit traversing the tunnel.
--- @param pos1 table The entrance position of the tunnel.
--- @param pos2 table The exit position of the tunnel.
--- @param quick_play boolean Whether the traversal is part of a quick play.
---
function SlabTunnel:TraverseTunnel(unit, pos1, pos2, quick_play)
	self:SetPos(pos2)
end

--- Returns the traverse parameters for the given object.
---
--- @param obj table The object to get the traverse parameters for.
--- @return table The traverse parameters for the given object, or nil if no matching parameters are found.
function SlabTunnel:GetTraverseParam(obj)
	if not obj then return end
	for i, params in ipairs(self.traverse_params) do
		if obj:IsKindOf(params[1]) then
			return params[2]
		end
	end
end

--- Checks if a unit can use a tunnel based on the given tunnel entrance and exit positions, and any tunnel blockers.
---
--- @param tunnel_entrance table The position of the tunnel entrance.
--- @param tunnel_exit table The position of the tunnel exit.
--- @param unit table The unit attempting to use the tunnel.
--- @param ignore_blockers table A list of tunnel blockers to ignore.
--- @return boolean Whether the unit can use the tunnel.
function CanUseTunnel(tunnel_entrance, tunnel_exit, unit)
	local o = MapGetFirst(tunnel_entrance, 0, "TunnelBlocker", function(o, end_pos, ignore_blockers)
		if o.tunnel_end_point ~= tunnel_exit then
			return false
		end
		if ignore_blockers and table.find(ignore_blockers, o) then
			return false
		end
		return true
	end, tunnel_exit, unit and unit.tunnel_blockers)
	if o then
		return false
	end
	return true
end

---
--- Checks if the tunnel is blocked.
---
--- @return boolean Whether the tunnel is blocked.
function SlabTunnel:IsBlocked()
	return false
end

--- Calculates the cost of traversing this tunnel.
---
--- @param context table An optional table containing additional context information that may affect the cost, such as a move modifier.
--- @return number The calculated cost of traversing this tunnel.
function SlabTunnel:GetCost(context)
	return self.base_cost * (100 + self.modifier + (context and context.move_modifier or 0)) / 100
end

--- Returns the action point cost for the given action ID.
---
--- @param id number The ID of the action.
--- @return number The action point cost for the given action ID.
function GetSpecialMoveAPCost(id)
	return id and Presets.ConstDef["Action Point Costs"][id].value
end

---
--- Places a slab tunnel with the given parameters.
---
--- @param classname string The class name of the slab tunnel to place.
--- @param costAP number The action point cost of the slab tunnel.
--- @param luaobj table An optional table of additional properties for the slab tunnel.
--- @param x1 number The x-coordinate of the tunnel entrance.
--- @param y1 number The y-coordinate of the tunnel entrance.
--- @param z1 number The z-coordinate of the tunnel entrance, or `nil` if the terrain height should be used.
--- @param x2 number The x-coordinate of the tunnel exit.
--- @param y2 number The y-coordinate of the tunnel exit.
--- @param z2 number The z-coordinate of the tunnel exit, or `nil` if the terrain height should be used.
--- @return table The placed slab tunnel object.
---
function PlaceSlabTunnel(classname, costAP, luaobj, x1, y1, z1, x2, y2, z2)
	if not costAP then
		return
	end
	if z1 == false then z1 = nil end
	if z2 == false then z2 = nil end
	local tunnel = pf.GetTunnel(x1, y1, z1, x2, y2, z2)
	if tunnel then
		if tunnel.base_cost < costAP then
			return
		end
		tunnel:RemovePFTunnel()
		DoneObject(tunnel)
	end
	luaobj = luaobj or {}
	luaobj.end_point = point(x2, y2, z2)
	luaobj.base_cost = costAP
	local obj = PlaceObject(classname, luaobj)
	obj:SetPos(x1, y1, z1)
	obj:AddPFTunnel()
	return obj
end

DefineClass.SlabTunnelHelper = {
	__parents = {"Object"},
	entity = "SpotHelper",
	tunnel = false
}

function OnMsg.GameExitEditor()
	MapForEach("map", "SlabTunnelHelper", function(helper)
		DoneObject(helper)
	end)
end

---
--- Called when the editor is exited.
---
function SlabTunnelHelper:EditorExit()
end
-- terrain to slab link
DefineClass.SlabTunnelWalk = {
	__parents = { "SlabTunnel" },
	tunnel_type = const.TunnelTypeWalk,
	can_sprint_through = true,
}

--- Initializes the SlabTunnelWalk object.
---
--- This function is called when a SlabTunnelWalk object is created. It asserts that the `base_cost` field is set, which is likely a required parameter for the object.
function SlabTunnelWalk:Init()
	assert(self.base_cost)
end

---
--- Calculates the cost of traversing the SlabTunnelWalk object.
---
--- The cost is based on the `base_cost` property of the object, modified by the `modifier` property and an optional `walk_modifier` provided in the `context` parameter.
---
--- @param context table|nil Optional context information that may contain a `walk_modifier` field to further adjust the cost.
--- @return number The calculated cost of traversing the SlabTunnelWalk object.
function SlabTunnelWalk:GetCost(context)
	return self.base_cost * (100 + self.modifier + (context and context.walk_modifier or 0)) / 100
end

---
--- Moves a unit along a tunnel path between two positions.
---
--- This function handles the visual movement of a unit along a tunnel path, including setting the unit's position, orientation, and animation. It supports both quick and smooth movement, and handles cases where the start or end position is not on valid terrain.
---
--- @param unit table The unit to move along the tunnel path.
--- @param pos1 table The starting position of the tunnel path.
--- @param pos2 table The ending position of the tunnel path.
--- @param quick_play boolean If true, the unit is immediately set to the end position without animation.
--- @param use_stop_anim boolean If true, the unit will use a stop animation when reaching the end position.
---
function TunnelGoto(unit, pos1, pos2, quick_play, use_stop_anim)
	local angle = CalcOrientation(pos1, pos2)
	if quick_play then
		unit:SetPos(pos2)
		unit:SetOrientationAngle(angle)
		return
	end
	-- can't use goto, because it clears unit destlock
	if not pos1:IsValidZ() and pos2:IsValidZ() then
		unit:SetPos(pos1:x(), pos1:y(), terrain.GetHeight(pos1))
	end
	local dest = not pos2:IsValidZ() and pos1:IsValidZ() and pos2:SetTerrainZ() or pos2
	while true do
		if unit:TimeToPosInterpolationEnd() > 0 then
			if unit:IsValidZ() then
				unit:SetPos(unit:GetVisualPosXYZ())
			else
				local x, y, z = unit:GetVisualPosXYZ()
				unit:SetPos(x, y)
			end
		end
		local dist = unit:GetVisualDist2D(pos2)
		if dist == 0 then
			break
		end
		local anim = unit:GetMoveAnim()
		if unit.cur_move_style and (unit:GetAnimPhase() == 0 or unit:IsAnimEnd()) then
			if unit:UpdateMoveAnimFromStyle() then
				anim = unit:GetMoveAnim()
			end
		end
		if unit:GetState() ~= anim then
			unit:SetState(anim)
		end
		local anim_speed = unit:GetMoveSpeed()
		unit:SetAnimSpeed(1, anim_speed)
		local time = dist * 1000 / Max(1, unit:GetSpeed())
		local cur_dest = dest
		if unit.cur_move_style then
			local t = unit:TimeToAnimEnd()
			if t > 0 and t < time then
				local cur_pos = unit:GetVisualPos()
				if unit:IsValidZ() then
					cur_dest = cur_pos + SetLen(dest - cur_pos, dist * t / time)
				else
					cur_dest = cur_pos + SetLen2D(dest - cur_pos, dist * t / time)
				end
				time = t
			end
		end
		unit:SetPos(cur_dest, time)

		local rotate_time = Min(time, MulDivRound(300, 1000, Max(1, anim_speed)))
		if unit.ground_orient then
			local angle_diff = AngleDiff(unit:GetVisualOrientationAngle(), angle)
			local steps = Max(1, rotate_time / 50)
			local speed_change
			for i = 1, steps do
				local t = rotate_time * i / steps - rotate_time * (i - 1) / steps
				local a = angle - angle_diff * (steps - i) / steps
				unit:SetGroundOrientation(a, t)
				speed_change = WaitWakeup(t) or unit:GetMoveSpeed() ~= anim_speed
				if speed_change then
					break
				end
			end
			if not speed_change then
				local move_time = time - rotate_time
				if move_time > 0 then
					local steps = 1 + unit:GetDist2D(unit:GetVisualPosXYZ()) / (const.SlabSizeX / 2)
					for i = 1, steps do
						local t = move_time * i / steps - move_time * (i - 1) / steps
						unit:SetGroundOrientation(angle, t)
						WaitWakeup(t)
					end
				end
			end
		else
			unit:SetAngle(angle, rotate_time)
			if use_stop_anim and unit.move_stop_anim_len > 0 then
				local wait_time = dist > unit.move_stop_anim_len and pf.GetMoveTime(unit, dist - unit.move_stop_anim_len) or 0
				local speed_change
				if wait_time > 0 then
					speed_change = WaitWakeup(wait_time) or unit:GetMoveSpeed() ~= anim_speed
				end
				if not speed_change then
					unit:ChangePathFlags(const.pfDirty)
					unit:GotoStop(pos2)
				end
			else
				WaitWakeup(time)
			end
		end
	end
	unit:SetPos(pos2)
end

---
--- Traverses a tunnel for the given unit.
---
--- @param unit Unit The unit traversing the tunnel.
--- @param pos1 table The starting position of the tunnel.
--- @param pos2 table The ending position of the tunnel.
--- @param quick_play boolean Whether to use quick play mode.
--- @param use_stop_anim boolean Whether to use the stop animation.
---
function SlabTunnelWalk:TraverseTunnel(unit, pos1, pos2, quick_play, use_stop_anim)
	TunnelGoto(unit, pos1, pos2, quick_play, use_stop_anim)
end

-- Move Stairs
DefineClass.SlabTunnelStairs = {
	__parents = { "SlabTunnel" },
	tunnel_type = const.TunnelTypeStairs,
	can_sprint_through = true,
	dbg_tunnel_color = const.clrBlue,
	dbg_tunnel_zoffset = 20 * guic,
}

---
--- Initializes the SlabTunnelStairs class.
---
--- This function is called during the initialization of the SlabTunnelStairs class.
--- It asserts that the `base_cost` field is defined, which is likely a required parameter for the class.
---
function SlabTunnelStairs:Init()
	assert(self.base_cost)
end

---
--- Traverses a tunnel for the given unit.
---
--- @param unit Unit The unit traversing the tunnel.
--- @param pos1 table The starting position of the tunnel.
--- @param pos2 table The ending position of the tunnel.
--- @param quick_play boolean Whether to use quick play mode.
--- @param use_stop_anim boolean Whether to use the stop animation.
---
function SlabTunnelStairs:TraverseTunnel(unit, pos1, pos2, quick_play, use_stop_anim)
	TunnelGoto(unit, pos1, pos2, quick_play, use_stop_anim)
end

---
--- Calculates the cost for traversing a tunnel of stairs.
---
--- @param context table An optional table containing additional context information, such as a `walk_stairs_modifier` field.
--- @return number The calculated cost for traversing the tunnel.
---
function SlabTunnelStairs:GetCost(context)
	return self.base_cost * (100 + self.modifier + (context and context.walk_stairs_modifier or 0)) / 100
end

---
--- Combines a move with the given unit.
---
--- This function is an implementation detail and is not part of the public API.
---
--- @param move table The move to combine.
--- @param unit Unit The unit to combine the move with.
--- @return boolean Always returns false.
---
function SlabTunnelStairs:CombineMove(move, unit)
	return false
end

-- Drop
DefineClass.SlabTunnelDrop = {
	__parents = { "SlabTunnel" },
	traverse_params = {
		{ "RoofSlab", 15*guic },
	},
}
DefineClass.SlabTunnelDrop1 = {
	__parents = { "SlabTunnelDrop" },
	tunnel_type = const.TunnelTypeDrop1,
	tiles = 1,
}
DefineClass.SlabTunnelDrop2 = {
	__parents = { "SlabTunnelDrop" },
	tunnel_type = const.TunnelTypeDrop2,
	tiles = 2,
}
DefineClass.SlabTunnelDrop3 = {
	__parents = { "SlabTunnelDrop" },
	tunnel_type = const.TunnelTypeDrop3,
	tiles = 3,
}
DefineClass.SlabTunnelDrop4 = {
	__parents = { "SlabTunnelDrop" },
	tunnel_type = const.TunnelTypeDrop4,
	tiles = 4,
}

---
--- Calculates the cost for traversing a tunnel by dropping down.
---
--- @param context table An optional table containing additional context information, such as a `drop_down_modifier` field.
--- @return number The calculated cost for traversing the tunnel by dropping down.
---
function SlabTunnelDrop:GetCost(context)
	return self.base_cost * (100 + self.modifier + (context and context.drop_down_modifier or 0)) / 100
end

---
--- Traverses a tunnel by dropping down.
---
--- This function is an implementation detail and is not part of the public API.
---
--- @param unit Unit The unit that is traversing the tunnel.
--- @param pos1 point The starting position of the tunnel.
--- @param pos2 point The ending position of the tunnel.
--- @param quick_play boolean If true, the unit will be immediately teleported to the end of the tunnel without playing any animations.
---
function SlabTunnelDrop:TraverseTunnel(unit, pos1, pos2, quick_play)
	if quick_play then
		unit:SetPos(pos2)
		unit:SetAxis(axis_z)
		unit:SetAngle(pos1:Equal2D(pos2) and self:GetVisualAngle() or CalcOrientation(pos1, pos2))
		return
	end
	local anim = unit:GetActionRandomAnim("Drop", false, self.tiles)

	local surface_fx_type, surface_pos = GetObjMaterial(pos1)
	PlayFX("MoveDrop", "start", unit, surface_fx_type, surface_pos)

	local hit_thread = CreateGameTimeThread(function(unit, anim, pos)
		local delay = unit:GetAnimMoment(anim, "hit") or unit:GetAnimMoment(anim, "end") or unit:TimeToAnimEnd()
		WaitWakeup(delay)
		local surface_fx_type, surface_pos = GetObjMaterial(pos)
		PlayFX("MoveDrop", "end", unit, surface_fx_type, surface_pos)
	end, unit, anim, pos2)
	unit:PushDestructor(function()
		DeleteThread(hit_thread)
	end)

	local stepz, step_obj = GetVoxelStepZ(pos1)
	local offset_2d = self:GetTraverseParam(step_obj) or 0
	if pos1:x() ~= pos2:x() and pos1:y() ~= pos2:y() then
		offset_2d = offset_2d + 20*guic
	end
	local angle = CalcOrientation(pos1, pos2)
	local stepz1_1 = GetVoxelStepZ(pos1 + Rotate(point(const.SlabSizeX / 4, 30*guic, 0), angle))
	local stepz1_2 = GetVoxelStepZ(pos1 + Rotate(point(const.SlabSizeX / 4, -30*guic, 0), angle))
	local dz1 = 2 * (Max(stepz1_1, stepz1_2) - stepz)
	local start_offset = Rotate(point(offset_2d, 0, dz1), angle)

	unit:MovePlayAnim(anim, pos1, pos2, nil, nil, nil, angle, start_offset, point30)

	if IsValidThread(hit_thread) then
		Wakeup(hit_thread)
		Sleep(0)
	end
	unit:PopAndCallDestructor()
end

-- Climb
DefineClass.SlabTunnelClimb = {
	__parents = { "SlabTunnel" },
	traverse_params = {
		{ "RoofSlab", -15*guic },
	},
}
DefineClass.SlabTunnelClimb1 = {
	__parents = { "SlabTunnelClimb" },
	tunnel_type = const.TunnelTypeClimb1,
	tiles = 1,
}
DefineClass.SlabTunnelClimb2 = {
	__parents = { "SlabTunnelClimb" },
	tunnel_type = const.TunnelTypeClimb2,
	tiles = 2,
}
DefineClass.SlabTunnelClimb3 = {
	__parents = { "SlabTunnelClimb" },
	tunnel_type = const.TunnelTypeClimb3,
	tiles = 3,
}
DefineClass.SlabTunnelClimb4 = {
	__parents = { "SlabTunnelClimb" },
	tunnel_type = const.TunnelTypeClimb4,
	tiles = 4,
}

---
--- Calculates the cost of traversing a slab tunnel climb.
---
--- @param context table|nil Additional context information that may affect the cost.
--- @return number The calculated cost of traversing the slab tunnel climb.
function SlabTunnelClimb:GetCost(context)
	return self.base_cost * (100 + self.modifier + (context and context.climb_up_modifier or 0)) / 100
end

---
--- Traverses a slab tunnel climb.
---
--- @param unit table The unit traversing the slab tunnel.
--- @param pos1 table The starting position of the tunnel.
--- @param pos2 table The ending position of the tunnel.
--- @param quick_play boolean Whether to quickly play the traverse animation.
---
function SlabTunnelClimb:TraverseTunnel(unit, pos1, pos2, quick_play)
	if quick_play then
		unit:SetPos(pos2)
		unit:SetAxis(axis_z)
		unit:SetAngle(pos1:Equal2D(pos2) and self:GetVisualAngle() or CalcOrientation(pos1, pos2))
		return
	end
	local anim = unit:GetActionRandomAnim("Climb", false, self.tiles)
	--local hidden_weapon
	--if climb_tiles > 1 and unit:HideActiveMeleeWeapon() then
	--	hidden_weapon = true
	--	unit:PushDestructor(unit.ShowActiveMeleeWeapon)
	--end

	local surface_fx_type, surface_pos = GetObjMaterial(pos1)
	PlayFX("MoveClimb", "start", unit, surface_fx_type, surface_pos)

	local hit_thread = CreateGameTimeThread(function(unit, anim, pos)
		local delay = unit:GetAnimMoment(anim, "hit") or unit:GetAnimMoment(anim, "end") or unit:TimeToAnimEnd()
		WaitWakeup(delay)
		local surface_fx_type, surface_pos = GetObjMaterial(pos)
		PlayFX("MoveClimb", "end", unit, surface_fx_type, surface_pos)
	end, unit, anim, pos2)
	unit:PushDestructor(function()
		DeleteThread(hit_thread)
	end)

	local stepz2, step_obj2 = GetVoxelStepZ(pos2)
	local offset_2d = self:GetTraverseParam(step_obj2) or 0
	if pos1:x() ~= pos2:x() and pos1:y() ~= pos2:y() then
		offset_2d = offset_2d - 20*guic
	end
	local angle = CalcOrientation(pos1, pos2)
	local stepz2_1 = GetVoxelStepZ(pos2 - Rotate(point(const.SlabSizeX / 4, 30*guic, 0), angle))
	local stepz2_2 = GetVoxelStepZ(pos2 - Rotate(point(const.SlabSizeX / 4, -30*guic, 0), angle))
	local dz2 = 2 * (Max(stepz2_1, stepz2_2) - stepz2)
	local end_offset = Rotate(point(offset_2d, 0, dz2), angle)

	unit:MovePlayAnim(anim, pos1, pos2, nil, nil, nil, nil, point30, end_offset)

	if IsValidThread(hit_thread) then
		Wakeup(hit_thread)
		Sleep(0)
	end
	unit:PopAndCallDestructor()

	--if hidden_weapon then
	--	unit:PopAndCallDestructor()
	--end
end

-- Jump
DefineClass.SlabTunnelJump = {
	__parents = { "SlabTunnel" },
	action = false,
	can_sprint_through = true,
}

--- Traverses a slab tunnel for the given unit.
---
--- @param unit Unit The unit traversing the tunnel.
--- @param pos1 point The starting position of the tunnel.
--- @param pos2 point The ending position of the tunnel.
--- @param quick_play boolean Whether to quickly play the traversal animation.
function SlabTunnelJump:TraverseTunnel(unit, pos1, pos2, quick_play)
	if quick_play then
		unit:SetPos(pos2)
		unit:SetAxis(axis_z)
		unit:SetAngle(pos1:Equal2D(pos2) and self:GetVisualAngle() or CalcOrientation(pos1, pos2))
		return
	end
	local anim = unit:GetActionRandomAnim(self.action, false)

	local surface_fx_type, surface_pos = GetObjMaterial(pos1)
	PlayFX("MoveJump", "start", unit, surface_fx_type, surface_pos)

	local hit_thread = CreateGameTimeThread(function(unit, anim, pos)
		local delay = unit:GetAnimMoment(anim, "hit") or unit:GetAnimMoment(anim, "end") or unit:TimeToAnimEnd()
		WaitWakeup(delay)
		local surface_fx_type, surface_pos = GetObjMaterial(pos)
		PlayFX("MoveJump", "end", unit, surface_fx_type, surface_pos)
	end, unit, anim, pos2)
	unit:PushDestructor(function()
		DeleteThread(hit_thread)
	end)

	unit:MovePlayAnim(anim, pos1, pos2)

	if IsValidThread(hit_thread) then
		Wakeup(hit_thread)
		Sleep(0)
	end
	unit:PopAndCallDestructor()
end

DefineClass.SlabTunnelJumpOver1 = {
	__parents = { "SlabTunnelJump" },
	tunnel_type = const.TunnelTypeJumpOver1,
	action = "JumpOverShort",
}
DefineClass.SlabTunnelJumpOver2 = {
	__parents = { "SlabTunnelJump" },
	tunnel_type = const.TunnelTypeJumpOver2,
	action = "JumpOverLong",
}
DefineClass.SlabTunnelJumpAcross1 = {
	__parents = { "SlabTunnelJump" },
	tunnel_type = const.TunnelTypeJumpAcross1,
	action = "JumpAcross1",
}
DefineClass.SlabTunnelJumpAcross2 = {
	__parents = { "SlabTunnelJump" },
	tunnel_type = const.TunnelTypeJumpAcross2,
	action = "JumpAcross2",
}

local drop_ids = { "Drop1", "Drop2", "Drop3", "Drop4" }
local climb_ids = { "Climb1", "Climb2", "Climb3", "Climb4" }
local query_flags = const.cqfSingleResult  + const.cqfResultIfStartInside + const.cqfFrontAndBack

local function CapsuleCollides(center, half_extent, radius, mask_any, filter)
	mask_any = mask_any or (const.cmObstruction + const.cmTerrain + const.cmPassability)
	
	local collides
	collision.Collide(center, half_extent, radius, point30, query_flags, 0, mask_any, function(obj)
		if not filter or filter(obj) then
			collides = true
			return true
		end
	end)
	
	return collides
end

-- return voxelz, passz, stepz, voxel custom data
local function FindPassVoxelZ(x, y, z1, z2, voxel_pass)
	local terrain_z, terrain_voxel_z
	for voxelz = z1, z2, z1 <= z2 and tilez or -tilez do
		if voxel_pass then
			local vinfo = GetSlabPassDataFromC(point(x, y, voxelz))
			if vinfo then
				local stepz = vinfo.z or voxelz
				return voxelz, stepz, stepz, vinfo
			end
		end
		if IsPassable(x, y, voxelz, 0) then
			local stepz = GetVoxelStepZ(x, y, voxelz)
			return voxelz, stepz, stepz
		end
		if not terrain_z then
			terrain_z = GetTerrainHeight(x, y)
			terrain_voxel_z = SnapToVoxelZ(x, y, terrain_z)
		end
		if voxelz == terrain_voxel_z and IsPassable(x, y) then
			return voxelz, nil, terrain_z
		end
	end
end

local function AddTunnelPoints(points, x1, y1, x2, y2, voxelz, minz, vinfo)
	local voxelz1, z1, stepz1 = FindPassVoxelZ(x1, y1, voxelz, minz, vinfo)
	local voxelz2, z2, stepz2 = FindPassVoxelZ(x2, y2, voxelz, minz, vinfo)
	if voxelz1 and voxelz2 then
		local ztiles = (abs(stepz1 - stepz2) + tilez/2) / tilez
		if voxelz - voxelz1 <= tilez and (ztiles < 2 or CheckHeroPassLine(x2, y2, stepz1, x2, y2, stepz2 + tilez)) then
			local idx = #points
			points[idx+1] = x1
			points[idx+2] = y1
			points[idx+3] = z1 or false
			points[idx+4] = x2
			points[idx+5] = y2
			points[idx+6] = z2 or false
		end
		if voxelz - voxelz2 <= tilez and (ztiles < 2 or CheckHeroPassLine(x1, y1, stepz2, x1, y1, stepz1 + tilez)) then
			local idx = #points
			points[idx+1] = x2
			points[idx+2] = y2
			points[idx+3] = z2 or false
			points[idx+4] = x1
			points[idx+5] = y1
			points[idx+6] = z1 or false
		end
	end
end

local function GetMovePassThroughObjSpots(obj, vinfo, max_drop_tiles)
	max_drop_tiles = max_drop_tiles or 0
	local voxelz = select(3, SnapToVoxel(0, 0, select(3, obj:GetVisualPosXYZ()) + tilez / 2))
	local minz = voxelz - tilez - max_drop_tiles * tilez
	local points = {}

	-- spots replace the default placement
	if obj:HasSpot("Tunnel") then
		local dx, dy = RotateRadius(tilex / 2, obj:GetOrientationAngle(), 0, true)
		local first_spot, last_spot = obj:GetSpotRange("Tunnel")
		for spot = first_spot, last_spot do
			local x, y, z = obj:GetSpotPosXYZ(spot)
			local x1, y1, z1 = SnapToVoxel(x + dx, y + dy, z)
			local x2, y2, z2 = SnapToVoxel(x - dx, y - dy, z)
			if x1 == x2 and abs(y1 - y2) == tiley or y1 == y2 and abs(x1 - x2) == tilex then
				AddTunnelPoints(points, x1, y1, x2, y2, voxelz, minz, vinfo)
			end
		end
		return points
	end

	local width = Max(1, obj:GetWidthForTunnels())

	--account for art being offset for some objs and not others.
	local minx, miny, maxx, maxy = obj:GetEntityBBox("idle"):xyxy()
	local _x1 = (minx + maxx) / 2 - tilex / 2
	local _y1 = (miny + maxy) / 2 - tiley * (width - 1) / 2
	local x1, y1, z1 = SnapToVoxel(obj:GetRelativePointXYZ(_x1, _y1, 0))
	local x2, y2, z2 = SnapToVoxel(obj:GetRelativePointXYZ(_x1 + tilex, _y1, 0))
	if not (x1 == x2 and abs(y1 - y2) == tiley or y1 == y2 and abs(x1 - x2) == tilex) then
		return
	end

	local stepx, stepy = 0, 0
	if width > 1 then
		local posx, posy, posz = obj:GetPosXYZ()
		local rx, ry = obj:GetRelativePointXYZ(0, tiley, 0)
		if abs(rx - posx) >= abs(ry - posy) then
			stepx = rx > posx and tilex or -tilex
		else
			stepy = ry > posy and tiley or -tiley
		end
	end
	for w = 0, width - 1 do
		AddTunnelPoints(points, x1 + w * stepx, y1 + w * stepy, x2 + w * stepx, y2 + w * stepy, voxelz, minz, vinfo)
	end
	return points
end

DefineClass.Door = {
	__parents = { "CombatObject", "Interactable", "Lockpickable", "BoobyTrappable",
		"AutoAttachObject", "TunnelObject", "AttachLightPropertyObject"
	},
	entity = "Door_Planks_Single_01", 
	properties = {
		{ id = "HitPoints", name = "Hit Points", editor = "number", default = 30, no_edit = true, min = -1, max = 100 },
		{ category = "Interactable", id = "BadgePosition", name = "Badge Position", editor = "choice", items = { "self", "average" }, default = "self" },
		{ id = "impassable", name = "Impassable", editor = "bool", default = false, help = "If true, will not place passability tunnels and not allow for interact." },
	},
	flags = { efCollision = true, efApplyToGrids = true, },
	tunnel_class = "SlabTunnelDoor",
	pass_through_state = "closed", -- "open", "locked", "blocked"
	thread = false,
	interacting_unit = false,
	highlight_collection = false,
	interact_positions = false,
	decorations = false,
}

---
--- Draws decoration contours for impassable doors on the same floor as the camera.
--- Finds all decorations that are linked to the room of the impassable door and adds them to the door's `decorations` table.
---
--- @param obj Door|WindowTunnelObject The door or window tunnel object to draw the decoration contours for.
--- @param objFloor number The floor that the object is on.
--- @param isOnSameFloor boolean Whether the object is on the same floor as the camera.
--- @param decorations table A table to store the decorations linked to the object's room.
--- @param allDecorations table A table of all decorations in the area around the object.
--- @param collections table A table of collections that the decorations belong to.
--- @param data table The room data for the collections.
--- @param room table The room that the decoration is in.
--- @param sides table The sides of the room that the decoration is linked to.
---
function DrawDecorationsContours()
	MapForEach("map", "Door", "WindowTunnelObject", function(obj)  
		local objFloor = obj.floor or (obj.room and obj.room.floor)
		local isOnSameFloor = objFloor == cameraTac.GetFloor() + 1
		if obj.impassable and isOnSameFloor then
			local decorations = {}
			local objFloor = obj.floor
			local allDecorations = MapGet(GrowBox(obj:GetObjectBBox(), const.SlabSizeX / 100))
			for _, decoration in ipairs(allDecorations) do
				local collections = ExtractCollectionsFromObjs({decoration})
				for col, _ in pairs(collections) do
					local data = GetRoomDataForCollection(col)
					local isLinked = not not data
					if isLinked then
						for room, sides in pairs(data or empty_table) do
							if room.floor == objFloor then
								decorations[#decorations + 1] = decoration
								decoration.floor = decoration.floor or obj.floor
								break
							end
						end
					end
				end
			end
			obj.decorations = decorations
		end
	end)
end

function OnMsg.NewMapLoaded()
	DrawDecorationsContours()
end

---
--- Initializes the game state for a door object.
---
--- This function is called during the game initialization process for a door object.
--- It sets the pass-through state of the door based on the saved state from the level designer.
--- If the door is impassable, it sets the lockpick state and difficulty.
--- For open doors, the discovered state is set to true to avoid running interactable discovery.
---
--- @param self Door The door object instance.
---
function Door:GameInit()
	local state = self.pass_through_state
	if self:GetStateText() == "open" then		
		state = "open"	-- level designer saved state overrides the class default state
	end
	self.pass_through_state = false
	self:SetDoorState(state)
	if self.impassable then
		self.lockpickState = "blocked"
		self.lockpickDifficulty = "Impossible"
	end
	
	-- Dont run interactable discovery for open doors
	if state == "open" then
		self.discovered = true
	end
end
Door.ShouldAttach = return_true

local maxColliders = const.maxCollidersPerObject or 4
local cmPassability = const.cmPassability

local function HasCollider(obj)
	for i = 0, maxColliders - 1 do
		if (collision.GetCollisionMask(obj, i) & cmPassability) ~= 0 then
			return true
		end
	end
	
	return false
end

local function lGetInteractionSpotsFromTunnelPoints(objAngle, points)
	local count = points and #points or 0
	local interact_positions = {}
	for i = 1, count, 6 do
		local x, y, z = table.unpack(points, i, i + 2)
		table.insert(interact_positions, point(x, y, z or nil))
	end
	local angle = objAngle + 90*60
	for i = 1, #interact_positions do
		local p = interact_positions[i]
		local p1 = GetPassSlab(RotateRadius(tilex, angle, p))
		local p2 = GetPassSlab(RotateRadius(-tilex, angle, p))
		if p1 and not table.find(interact_positions, p1) and IsPassSlabStep(p, p1, const.TunnelMaskWalk) then
			table.insert(interact_positions, p1)
		end
		if p2 and not table.find(interact_positions, p2) and IsPassSlabStep(p, p2, const.TunnelMaskWalk) then
			table.insert(interact_positions, p2)
		end
	end
	return interact_positions
end

---
--- Places tunnels for a door object based on its passability.
---
--- @param slab_pass table The slab passability data.
---
function Door:PlaceTunnels(slab_pass)
	self.interact_positions = false
	if self.impassable then return end
	if not self:HasState("open") or self:GetEntity() == "InvisibleObject" then
		-- this door can never be openned, so presumably it doesn't need tunnels
		return
	end
	local points = GetMovePassThroughObjSpots(self, slab_pass)
	local count = points and #points or 0
	if count == 0 then
		return -- there is no passability
	end

	-- add interaction spots
	local t = lGetInteractionSpotsFromTunnelPoints(self:GetAngle(), points)
	if t and #t > 0 then
		self.interact_positions = t
	end

	-- opened doors do not place tunnels
	local isOpen = self.pass_through_state == "open"
	-- Dont path through locked doors that we know are locked
	local isBlocked = IsBlockingLockpickState(self.pass_through_state)
	local isKnownLocked = isBlocked and self.discovered_lock
	
	if not isOpen and not isKnownLocked then
		local tunnel_class = self.tunnel_class
		if isBlocked then
			tunnel_class = "SlabTunnelDoorBlocked"
		end
		local isDiscoveredTrapped = self.boobyTrapType ~= const.BoobyTrapNone and not self.done and self.discovered_trap
		local exploration_additional_cost = isDiscoveredTrapped and GetSpecialMoveAPCost("ExplorationActionMovesModifierStrong")
		for i = 1, count, 6 do
			local cost, interact_cost, move_cost = self:GetTunnelCost(table.unpack(points, i, i + 5))
			if cost then
				local luaobj = {
					pass_through_obj = self,
					base_interact_cost = interact_cost,
					base_move_cost = move_cost,
					exploration_additional_cost = exploration_additional_cost,
				}
				PlaceSlabTunnel(tunnel_class, cost, luaobj, table.unpack(points, i, i + 5))
			end
		end
	end
end

function OnMsg.TrapDiscovered(trap)
	if IsKindOfClasses(trap, "Door") then
		DelayedCall(0, RebuildSlabTunnels, trap:GetObjectBBox())
	end
end

function OnMsg.TrapDisarm(trap)
	if IsKindOf(trap, "Door") then
		DelayedCall(0, RebuildSlabTunnels, trap:GetObjectBBox())
	end
end

--- Returns the position of the door.
---
--- @return table The position of the door.
function Door:GetPassPos()
	return self:GetPos()
end

--- Interacts with a door, playing animations and triggering any associated effects.
---
--- @param unit table The unit interacting with the door.
--- @param door_state string The desired state of the door ("open" or "closed").
--- @return string The result of the interaction ("failed" if the door cannot be opened).
function Door:InteractDoor(unit, door_state)
	assert(not self.impassable)
	local stance = unit.stance == "Prone" and "Standing" or unit.stance
	local base_anim = unit:GetActionBaseAnim("Open_Door")
	local anim = unit:GetStateText()
	if IsAnimVariant(anim, base_anim) and (unit:GetAnimPhase(1) == 0 or unit:TimeToMoment(1, "hit")) then
		-- already in a open door animation
	else
		anim = unit:GetNearbyUniqueRandomAnim(base_anim)
		if anim and unit:HasState(anim) then
			if unit.stance ~= stance then
				unit:PlayTransitionAnims(unit:GetIdleBaseAnim(stance))
			end
			unit:SetState(anim)
		else
			anim = false
		end
	end
	if anim then
		repeat
			unit:SetAnimSpeed(1, unit:CalcMoveSpeedModifier())
			local time_to_hit = unit:TimeToMoment(1, "hit") or 0
			local t = Min(MulDivRound(200, 1000, Max(1, unit:GetMoveSpeed())), time_to_hit)
		until not WaitWakeup(t)
	else
		StoreErrorSource(unit, "Unit does not have an open door animation ", anim)
		unit:SetState(unit:GetIdleBaseAnim(stance))
		unit:SetAnimSpeed(1, unit:CalcMoveSpeedModifier())
		unit:SetAnimPhase(1, Max(0, GetAnimDuration(unit:GetEntity(), unit:GetStateText()) - 1000))
		unit:Face(self)
	end

	local self_pos = self:GetVisualPos()
	local fx_target, _, _, fx_target_secondary = GetObjMaterial(self_pos, self)
	local fx_action
	if door_state == "open" then
		fx_action = "OpenDoor"
	elseif door_state == "closed" then
		fx_action = "CloseDoor"
	end
	local cant_open = self:CannotOpen()
	if fx_action and not cant_open then
		PlayFX(fx_action, "start", unit, fx_target, self_pos)
		if fx_target_secondary then
			PlayFX(fx_action, "start", unit, fx_target_secondary, self_pos)
		end
	end
	self:TriggerTrap(unit)
	if not IsValid(self) then
		return -- a trap may have destroyed the door
	end
	if cant_open then
		self:PlayCannotOpenFX(unit)
		unit:ClearPath()
		DelayedCall(0, RebuildSlabTunnels, self:GetObjectBBox())
		Sleep(unit:TimeToAnimEnd() + 1)
		return "failed"
	end
	self:SetDoorState(door_state, true)
	if fx_action then
		PlayFX(fx_action, "hit", unit, fx_target, self_pos)
		if fx_target_secondary then
			PlayFX(fx_action, "start", unit, fx_target_secondary, self_pos)
		end
	end
	repeat
		unit:SetAnimSpeed(1, unit:CalcMoveSpeedModifier())
	until not WaitWakeup(unit:TimeToAnimEnd())
	if fx_action then
		PlayFX(fx_action, "end", unit, fx_target, self_pos)
		if fx_target_secondary then
			PlayFX(fx_action, "start", unit, fx_target_secondary, self_pos)
		end
	end
	if IsValid(self) and self.thread then
		WaitMsg(self, self:TimeToAnimEnd() + 1) -- wait the door to set the proper state (passability update, VisibilityUpdate)
	end
end

---
--- Sets the door state to the specified state, and updates the pass-through state accordingly.
---
--- @param state string The new door state, can be "open", "closed", or "cut".
--- @param animated boolean Whether the door state change should be animated.
---
function Door:SetDoorState(state, animated)
	if self.pass_through_state == state then return end
	if self:CannotOpen() then
		if state == "open" then return end -- Dont allow setting open state.
	else
		self.lockpickState = state
	end
	if self.is_destroyed then return end
	
	self.pass_through_state = state
	local isOpening = state == "open"
	DeleteThread(self.thread)
	self.thread = nil
	self:PlayLockpickableFX(isOpening and "open" or "close")

	if animated then
		self:SetState(isOpening and "opening" or "closing")
		self.thread = CreateGameTimeThread(function(self, isOpening)
			if IsValid(self) then
				Sleep(self:TimeToAnimEnd())
			end
			self.thread = nil
			if IsValid(self) then
				self:SetState(isOpening and "open" or "idle")
				Msg("CoversChanged", self:GetObjectBBox())
			end
			Msg(self)
		end, self, isOpening)
	elseif state == "cut" then
		self:SetState("cut")
		Msg("CoversChanged", self:GetObjectBBox())
	else
		local newState = isOpening and "open" or "idle"
		if self:HasState(newState) then
			self:SetState(newState)
		end
		Msg("CoversChanged", self:GetObjectBBox())
	end
	Msg("DoorStateChanged")
end

-- Map lockpickable state to pass_through_state
---
--- Handles changes to the lockpick state of a door.
---
--- If the door cannot be opened, the door state is set to "closed" and the pass-through state is set to "locked".
--- If the door is cut, the door state is set to "cut" and the pass-through state is set to "open".
--- Otherwise, the door state and pass-through state are set directly to the new lockpick state.
---
--- After updating the state, the surfaces are invalidated if not changing maps.
---
--- @param status string The new lockpick state of the door.
---
function Door:LockpickStateChanged(status)
	if self:CannotOpen() then -- Treat all cannot-open states as "locked"
		self:SetDoorState("closed", false)
		self.pass_through_state = "locked"
	elseif status == "cut" then -- Cut means the door is open and cannot be closed
		self:SetDoorState(status, false)
		self.pass_through_state = "open"
	else -- open and close map directly
		self:SetDoorState(status, false)
		self.pass_through_state = status
	end
	if not IsChangingMap() then
		self:InvalidateSurfaces()
	end
end

---
--- Sets the lockpick state of the door.
---
--- If the lockpick state changes in a way that affects whether the door is blocking or not, the slab tunnels are rebuilt after a short delay.
---
--- @param val string The new lockpick state of the door.
---
function Door:SetLockpickState(val)
	local oldState = self.lockpickState
	Lockpickable.SetLockpickState(self, val)
	if IsBlockingLockpickState(oldState) ~= IsBlockingLockpickState(val) then
		DelayedCall(0, RebuildSlabTunnels, self:GetObjectBBox())
	end
end

---
--- Gets the AP cost for opening the door.
---
--- If the door is already in the "open" pass-through state, the AP cost is 0.
--- Otherwise, the AP cost is retrieved from the door's interaction combat action.
---
--- @return number The AP cost for opening the door.
---
function Door:GetOpenAPCost()
	if self.pass_through_state == "open" then
		return 0
	end
	local combat_action = self:GetInteractionCombatAction()
	return combat_action and combat_action:GetAPCost() or 0
end

-- tunnel general cost
---
--- Gets the total AP cost for opening the door.
---
--- The total AP cost is the sum of the AP cost for interacting with the door and the AP cost for moving to the door.
---
--- @return number The total AP cost for opening the door
--- @return number The AP cost for interacting with the door
--- @return number The AP cost for moving to the door
---
function Door:GetTunnelCost()
	local interactAP = self:GetOpenAPCost()
	local moveAP = GetSpecialMoveAPCost("Walk")
	return interactAP + moveAP, interactAP, moveAP
end

---
--- Determines if the door's interaction is enabled.
---
--- The door's interaction is enabled if:
--- - The door's lockpick state is not "cut"
--- - The door is not impassable
--- - The door is valid and has positive hit points
--- - The door is animated
---
--- @return boolean True if the door's interaction is enabled, false otherwise.
---
function Door:InteractionEnabled()
	if self.lockpickState == "cut" or self.impassable then return false end
	return IsValid(self) and (self.HitPoints > 0) and self:IsAnimated()
end

---
--- Determines if a unit and a door are on the same level.
---
--- This function checks if the vertical distance between the unit and the door is within the tile height.
---
--- @param unit The unit to check.
--- @param door The door to check.
--- @return boolean True if the unit and door are on the same level, false otherwise.
---
function DoorOnSameLevel(unit, door)
	local ux, uy, uz = unit:GetPosXYZ()
	local dx, dy, dz = door:GetPosXYZ()
	if not uz then
		ux, uy, uz = SnapToVoxel(ux, uy, terrain.GetHeight(ux, uy) + tilez / 2)
	end
	if not dz then
		dx, dy, dz = SnapToVoxel(dx, dy, terrain.GetHeight(dx, dy) + tilez / 2)
	end
	if abs(uz - dz) > tilez then
		return false
	end
	return true
end

-- Returns the default interaction for the object.
-- These actions should handle the animations and visuals (banters etc)
-- for when attempting to interact with the object when its locked/blocked etc
---
--- Determines the appropriate interaction action for an object.
---
--- If the object is a Door, the action is "Interact_DoorOpen".
--- If the object is a SlabWallWindow, the action is "Interact_WindowBreak".
---
--- @param obj The object to get the interaction action for.
--- @return string The appropriate interaction action for the object.
---
function GetOpenAction(obj)
	if IsKindOf(obj, "Door") then
		return "Interact_DoorOpen"
	elseif IsKindOf(obj, "SlabWallWindow") then
		return "Interact_WindowBreak"
	end
end

---
--- Determines if the door is dead.
---
--- This function checks if the door is dead by calling the `IsDead()` function of the `CombatObject` class.
---
--- @return boolean True if the door is dead, false otherwise.
---
function Door:IsDead()
	return CombatObject.IsDead(self)
end

---
--- Determines the appropriate interaction combat action for a door object.
---
--- If the door is not interaction enabled, no action is returned.
--- If the door is boobytrapable, the boobytrap interaction action is returned.
--- If the door cannot be opened, the lockpick interaction action is returned.
--- If the door is not open, the "Interact_DoorOpen" action is returned.
--- If the door is open, the "Interact_DoorClose" action is returned.
---
--- @param unit The unit interacting with the door.
--- @return string|nil The appropriate interaction combat action for the door, or nil if no action is available.
---
function Door:GetInteractionCombatAction(unit)
	if not self:InteractionEnabled() then
		return
	end
	
	local trapAction, icon = BoobyTrappable.GetInteractionCombatAction(self, unit)
	if trapAction then
		return trapAction, icon
	end
	
	if self:CannotOpen() then
		local baseAction = Lockpickable.GetInteractionCombatAction(self, unit)
		if baseAction then return baseAction end 
	end
	
	if self.pass_through_state ~= "open" then
		return Presets.CombatAction.Interactions.Interact_DoorOpen
	else
		return Presets.CombatAction.Interactions.Interact_DoorClose
	end
end

---
--- Returns the interaction positions for the door.
---
--- @return table The interaction positions for the door.
---
function Door:GetInteractionPos()
	return self.interact_positions
end

---
--- Registers the unit that is currently interacting with the door.
---
--- @param unit The unit interacting with the door.
---
function Door:RegisterInteractingUnit(unit)
	self.interacting_unit = unit
end

---
--- Unregisters the unit that is currently interacting with the door.
---
--- @param unit The unit that was interacting with the door.
---
function Door:UnregisterInteractingUnit(unit)
	self.interacting_unit = false
end

---
--- Checks if the door is currently being interacted with.
---
--- @return boolean True if the door is being interacted with, false otherwise.
---
function Door:IsInteracting()
	return not not self.interacting_unit
end

---
--- Checks if the door is blocked and cannot be opened.
---
--- @return boolean True if the door is blocked and cannot be opened, false otherwise.
---
function Door:IsBlocked()
	return self:CannotOpen()
end

Door.GetSide = WallSlab.GetSide

---
--- Checks if the SlabWallObject is blocked due to the room it is in.
---
--- @return boolean True if the object is blocked due to the room, false otherwise.
---
function SlabWallObject:IsBlockedDueToRoom()
	return self.room and self.room.doors_windows_blocked
end

UndefineClass("SlabWallDoor")
DefineClass.SlabWallDoor = {
	__parents = { "SlabWallDoorDecor", "Door" },
	properties = {
		{ id = "HitPoints", name = "Hit Points", editor = "number", default = 30, no_edit = true, min = -1, max = 100 },
	},
	entity = "Door_Planks_Single_01", 
	IsBlockedDueToRoom = SlabWallObject.IsBlockedDueToRoom,
}

---
--- Gets the lockpick difficulty for the SlabWallDoor.
---
--- If the door is blocked due to the room it is in, the lockpick difficulty is -1, indicating it cannot be lockpicked.
--- Otherwise, the lockpick difficulty is retrieved using the Lockpickable.GetlockpickDifficulty function.
---
--- @return number The lockpick difficulty for the door, or -1 if the door is blocked due to the room.
---
function SlabWallDoor:GetlockpickDifficulty()
	return self:IsBlockedDueToRoom() and -1 or Lockpickable.GetlockpickDifficulty(self)
end

---
--- Checks if the SlabWallDoor is blocked and cannot be opened.
---
--- The door is considered blocked if either the base Door:IsBlocked() function returns true, or the door is blocked due to the room it is in (SlabWallObject:IsBlockedDueToRoom() returns true).
---
--- @return boolean True if the door is blocked and cannot be opened, false otherwise.
---
function SlabWallDoor:IsBlocked()
	return Door.IsBlocked(self) or self:IsBlockedDueToRoom()
end

---
--- Refreshes the entity state of the SlabWallDoor.
---
--- This function sets the `pass_through_state` to `nil` and updates the lockpick state of the door.
---
function SlabWallDoor:RefreshEntityState()
	self.pass_through_state = nil
	self:SetLockpickState(self.lockpickState)
end

SlabWallDoor.GetSide = WallSlab.GetSide

---
--- Called when the SlabWallDoor object dies.
---
--- This function first calls the `CombatObject.OnDie` function, which handles the death logic for the object.
--- It then triggers the trap associated with the door, passing `false` to indicate that the trap was not triggered by the player.
---
--- @param ... Any additional arguments passed to the `OnDie` function.
---
function SlabWallDoor:OnDie(...)
	CombatObject.OnDie(self, ...)
	self:TriggerTrap(false)
end

DefineClass.SlabWallUnopenableDoor = {
	__parents = { "SlabWallObject" },
}

---
--- Indicates that the SlabWallUnopenableDoor is a door.
---
--- @return boolean Always returns true, indicating that the object is a door.
---
function SlabWallUnopenableDoor:IsDoor()
	return true
end

DefineClass.SlabTunnelPassThroughObj = {
	__parents = { "SlabTunnel" },
	pass_through_obj = false,
}

DefineClass.SlabTunnelDoorBlocked = {
	__parents = { "SlabTunnelDoor" },
	tunnel_type = const.TunnelTypeDoorBlocked,
}

---
--- Indicates that the SlabTunnelDoorBlocked object is always blocked.
---
--- @param u The unit attempting to interact with the tunnel.
--- @return boolean Always returns true, indicating that the tunnel is blocked.
---
function SlabTunnelDoorBlocked:IsBlocked(u)
	return true
end

DefineClass.SlabTunnelDoor = {
	__parents = { "SlabTunnelPassThroughObj" },
	tunnel_type = const.TunnelTypeDoor,
}

---
--- Indicates whether the SlabTunnelDoor object can be sprinted through.
---
--- @return boolean True if the pass_through_obj of the SlabTunnelDoor is in the "open" state, false otherwise.
---
function SlabTunnelDoor:CanSprintThrough()
	return self.pass_through_obj.pass_through_state == "open"
end

---
--- Checks if the SlabTunnelDoor object is blocked.
---
--- @param u The unit attempting to interact with the tunnel.
--- @return boolean True if the tunnel is blocked, false otherwise.
---
function SlabTunnelDoor:IsBlocked(u)
	local passThroughObj = self.pass_through_obj
	local passThroughObjBlocked = passThroughObj and passThroughObj:IsBlocked()
	local passThroughState = passThroughObj and passThroughObj.pass_through_state
	return passThroughObjBlocked or SlabTunnelPassThroughObj.IsBlocked(self, u) or (passThroughState and passThroughState ~= "closed" and passThroughState ~= "open")
end

---
--- Interacts with the tunnel object and opens it if it is not already open or broken.
---
--- @param unit The unit attempting to interact with the tunnel.
--- @param quick_play Boolean indicating whether the interaction should be performed quickly.
--- @return boolean True if the interaction was successful, false otherwise.
--- @return boolean The updated quick_play value.
---
function SlabTunnelDoor:InteractTunnel(unit, quick_play)
	local obj = self.pass_through_obj
	if obj.pass_through_state ~= "open" and obj.pass_through_state ~= "broken" then
		if obj:InteractionEnabled() then
			obj:InteractDoor(unit, "open")
		end
		if (obj.pass_through_state ~= "open" and obj.pass_through_state ~= "broken") or unit:IsDead() then
			return false, quick_play
		end
		if quick_play then
			Sleep(0) -- wait visibility update
			quick_play = unit:CanQuickPlayInCombat() -- the unit may have been detected when opened the door
		end
	end
	return true, quick_play
end

---
--- Traverses the tunnel between the given positions.
---
--- @param unit The unit traversing the tunnel.
--- @param pos1 The starting position of the tunnel.
--- @param pos2 The ending position of the tunnel.
--- @param quick_play Boolean indicating whether the traversal should be performed quickly.
--- @param use_stop_anim Boolean indicating whether to use a stop animation during the traversal.
---
function SlabTunnelDoor:TraverseTunnel(unit, pos1, pos2, quick_play, use_stop_anim)
	TunnelGoto(unit, pos1, pos2, quick_play, use_stop_anim)
end

---
--- Calculates the cost for a unit to interact with the SlabTunnelDoor object.
---
--- @param context The context of the interaction, which may include information about the player and their abilities.
--- @return number The cost for the unit to interact with the SlabTunnelDoor object, or -1 if the AI player cannot use the locked door.
---
function SlabTunnelDoor:GetCost(context)
	if not (context and context.player_controlled) and self.pass_through_obj:CannotOpen() then
		return -1 -- AI players can't use locked doors
	end
	
	local obj = self.pass_through_obj
	local interact_cost = obj:GetOpenAPCost()

	local move_cost = self.base_move_cost * (100 + (context and context.walk_modifier or 0)) / 100
	
	return interact_cost + move_cost
end

local function lWindowSpecialImpassable(window)
	return window.invulnerable and window.room and window.room.ignore_zulu_invisible_wall_logic
end

DefineClass.WindowTunnelObject = {
	__parents = {"AutoAttachObject", "TunnelObject", "AttachLightPropertyObject"},
	properties = {
		{ id = "impassable",
			name = "Impassable",
			editor = "bool",
			default = false,
			help = "If true, will not place passability tunnels.",
			no_edit = lWindowSpecialImpassable
		},
		{ id = "impassable_room", -- This property is to visualize lWindowSpecialImpassable state for level designers
			name = "Impassable",
			editor = "bool",
			default = true,
			help = "This window is impassable due to being invulnerable and in an 'Ignore Visibility Logic' room.",
			read_only = true,
			dont_save = true,
			no_edit = function(self) return not lWindowSpecialImpassable(self) end
		},
	},
	tunnel_class = "SlabTunnelWindow",
	base_interact_cost = 0,
	base_move_cost = 0,
	base_drop_cost = 0,
	decorations = false,
}

WindowTunnelObject.ShouldAttach = return_true

---
--- Checks if the WindowTunnelObject is blocked due to its room.
---
--- @return boolean true if the WindowTunnelObject is blocked due to its room, false otherwise.
---
function WindowTunnelObject:IsBlocked()
	return self:IsBlockedDueToRoom()
end

---
--- Places passability tunnels for a WindowTunnelObject.
---
--- @param slab_pass table The slab passability table.
--- @return table|nil The points used to place the tunnels, or nil if no tunnels were placed.
---
function WindowTunnelObject:PlaceTunnels(slab_pass)
	if self.impassable or self.height < 2 or self:GetEntity() == "InvisibleObject" then
		return
	end
	if IsKindOf(self, "SlabWallWindow") and not self:HasBrokenOrOpenState() then
		--windows with no such states are presumed always open and use generic jump over/pass tunnels and don't need to place any
		return
	end
	if self:IsBlockedDueToRoom() then
		--rooms can specify that their windows are not breakable
		return
	end
	if lWindowSpecialImpassable(self) then
		-- another dirty hack for rooms with "Ignore Zulu.." check for which "Make Slabs Invulnerable" button was pressed 
		return	
	end
	local grounded = self:IsKindOf("SlabWallWindowGrounded")
	if grounded and self.pass_through_state ~= "intact" then
		return
	end
	local points = GetMovePassThroughObjSpots(self, slab_pass, MaxSlabMoveTilesZ)
	local count = points and #points or 0
	for i = 1, count, 6 do
		local x1, y1, z1, x2, y2, z2 = table.unpack(points, i, i + 5)
		local centerX = (x1 + x2) / 2
		local centerY = (y1 + y2) / 2
		local centerZ = Max(z1 or terrain.GetHeight(x1, y1), z2 or terrain.GetHeight(x2, y2)) + tilez + tilez / 2
		local halfExtentX = (x2 - x1) / 2
		local halfExtentY = (y2 - y1) / 2
		local halfExtentZ = 0
		local radius = tilez / 4
		if CheckPassCapsule(centerX, centerY, centerZ, halfExtentX, halfExtentY, halfExtentZ, radius, self) then
			local cost, interact_cost, move_cost, drop_cost = self:GetTunnelCost(table.unpack(points, i, i + 5))
			if cost then
				local luaobj = {
					pass_through_obj = self,
					base_interact_cost = interact_cost,
					base_move_cost = move_cost,
					base_drop_cost = drop_cost,
				}
				PlaceSlabTunnel(self.tunnel_class, cost, luaobj, table.unpack(points, i, i + 5))
			end
		end
	end
	return points
end

--- Calculates the cost of passing through a tunnel for the given coordinates.
---
--- @param x1 number The x-coordinate of the first point.
--- @param y1 number The y-coordinate of the first point.
--- @param z1 number The z-coordinate of the first point.
--- @param x2 number The x-coordinate of the second point.
--- @param y2 number The y-coordinate of the second point.
--- @param z2 number The z-coordinate of the second point.
--- @return number, number, number, number The total cost, interaction cost, movement cost, and drop cost for passing through the tunnel.
function WindowTunnelObject:GetTunnelCost(x1, y1, z1, x2, y2, z2)
	local interactAP = 0
	local moveAP = GetSpecialMoveAPCost("Walk")
	local dropAP = 0
	if z1 ~= z2 then
		local stepz1 = z1 or terrain.GetHeight(x1, y1)
		local stepz2 = z2 or terrain.GetHeight(x2, y2)
		local ztiles = (abs(stepz1 - stepz2) + tilez/2) / tilez
		if ztiles > 0 then
			if stepz1 < stepz2 then
				return
			end
			local drop_mod = drop_ids[Clamp(ztiles, 1, #drop_ids)]
			dropAP = GetSpecialMoveAPCost(drop_mod) or 0
		end
	end
	return interactAP + moveAP + dropAP, interactAP, moveAP, dropAP
end

UndefineClass("SlabWallWindowBroken")
DefineClass.SlabWallWindowBroken = {
	__parents = {"SlabWallObject", "WindowTunnelObject"},
	entity = "WindowBig_Colonial_Single_01",
	flags = { efCollision = true, efApplyToGrids = true, },
	pass_through_state = "broken"
}

--- Indicates that the `SlabWallWindowBroken` class is not breakable.
---
--- This function overrides the default behavior of the `SlabWallObject` class, which
--- may allow the object to be broken under certain conditions. By returning `false`
--- from this function, the `SlabWallWindowBroken` object is marked as unbreakable.
function SlabWallWindowBroken:IsBreakable()
	return false
end

UndefineClass("SlabWallWindowGrounded")
DefineClass.SlabWallWindowGrounded = {
	__parents = {"SlabWallWindow"},
	entity = "TallWindow_City_Single_01",
	flags = { efCollision = true, efApplyToGrids = true, },
	pass_through_state = "intact",
}

UndefineClass("SlabWallWindowGroundedOpen")
DefineClass.SlabWallWindowGroundedOpen = {
	__parents = {"SlabWallWindowGrounded"},
	pass_through_state = "open",
}

UndefineClass("ImpassableWindowTunnelObject")
DefineClass.ImpassableWindowTunnelObject = {
	__parents = {"SlabWallWindow"},
	properties = {
		{ id = "impassable", name = "Impassable", editor = "bool", default = true, help = "If true, will not place passability tunnels." },
	},
	entity = "TallWindow_City_Single_01",
	flags = { efCollision = true, efApplyToGrids = true, },
}

UndefineClass("SlabWallWindowOpen")
DefineClass.SlabWallWindowOpen = {
	__parents = {"SlabWallWindow"},
	pass_through_state = "open",
}

UndefineClass("SlabWallWindow")
DefineClass.SlabWallWindow = {
	__parents = {"SlabWallObject", "WindowTunnelObject"},
	entity = "WindowBig_Colonial_Single_01",
	flags = { efCollision = true, efApplyToGrids = true, },
	pass_through_state = "intact",		-- intact, broken
	IsBlockedDueToRoom = SlabWallObject.IsBlockedDueToRoom
}

local slab_z_offset = point(0, 0, tilez)

---
--- Sets the dynamic data for the SlabWallWindow object.
---
--- @param data table The dynamic data to set for the window.
---   - pass_through_state (string): The new pass-through state for the window, or "intact" if not provided.
---
function SlabWallWindow:SetDynamicData(data)
	self:SetWindowState(data.pass_through_state or "intact", "no_fx")
end

---
--- Gets the dynamic data for the SlabWallWindow object.
---
--- @param data table The dynamic data to get for the window.
---   - pass_through_state (string): The current pass-through state for the window, which will be "broken" if the window is broken.
---
function SlabWallWindow:GetDynamicData(data)
	if self:IsBroken() then
		data.pass_through_state = self.pass_through_state
	end
end

---
--- Checks if the SlabWallWindow object has either the "broken" or "open" state.
---
--- @return boolean true if the window has the "broken" or "open" state, false otherwise
---
function SlabWallWindow:HasBrokenOrOpenState()
	return self:HasState("broken") or self:HasState("open")
end


---
--- Gets the position of the SlabWallWindow object, adjusted for the slab z-offset.
---
--- @return table The position of the SlabWallWindow object, adjusted for the slab z-offset.
---
function SlabWallWindow:GetPassPos()
	return self:GetPos() - slab_z_offset
end

---
--- Checks if the SlabWallWindow object is in a broken state.
---
--- @return boolean true if the window is in a broken state, false otherwise
---
function SlabWallWindow:IsBreakable()
	return self:HasState("broken")
end

---
--- Checks if the SlabWallWindow object is in a broken state.
---
--- @return boolean true if the window is in a broken state, false otherwise
---
function SlabWallWindow:IsBroken()
	return self.pass_through_state == "broken"
end

---
--- Checks if the SlabWallWindow object is dead.
---
--- @return boolean true if the SlabWallWindow object is dead, false otherwise
---
function SlabWallWindow:IsDead()
	return CombatObject.IsDead(self)
end

---
--- Gets the AP cost for interacting with the SlabWallWindow object to break it.
---
--- @return number The AP cost for interacting with the SlabWallWindow object to break it.
---
function SlabWallWindow:GetOpenAPCost()
	local combat_action = Presets.CombatAction.Interactions.Interact_WindowBreak
	return combat_action and combat_action:GetAPCost() or 0
end

---
--- Gets the tunnel cost for the SlabWallWindow object.
---
--- @param ... Additional parameters to pass to the WindowTunnelObject.GetTunnelCost function.
--- @return number The total tunnel cost.
--- @return number The interaction cost.
--- @return number The move cost.
--- @return number The drop cost.
---
function SlabWallWindow:GetTunnelCost(...)
	local cost, interact_cost, move_cost, drop_cost = WindowTunnelObject.GetTunnelCost(self, ...)
	if not cost then
		return
	end
	local openAP = self:GetOpenAPCost() or 0
	if openAP > 0 then
		cost = cost + openAP
		interact_cost = interact_cost + openAP
	end
	return cost, interact_cost, move_cost, drop_cost
end

---
--- Sets the window state of the SlabWallWindow object.
---
--- @param window_state string The new window state, either "intact" or "broken".
--- @param no_fx boolean (optional) If true, no visual effects will be played.
---
function SlabWallWindow:SetWindowState(window_state, no_fx)
	if self.pass_through_state == "intact" and window_state == "broken" then
		if not (self.is_destroyed and self:GetEntity() == "InvisibleObject") then
			if self:HasState("broken") then
				self:SetState("broken")
			else
				StoreErrorSource(self, string.format("Window with entity '%s' does not have 'broken' state on map '%s'", self:GetEntity(), GetMapName()))
			end
		end
		if not no_fx then
			PlayFX("WindowBreak", "start", self)
		end
		if IsKindOf(self, "SlabWallWindowGrounded") then
			DelayedCall(0, RebuildSlabTunnels, self:GetObjectBBox())
			if rawget(_G, "debug_pass_vectors") then
				DelayedCall(0, DbgDrawTunnels, "show")
			end
		end
	end
	self.pass_through_state = window_state
end

---
--- Interacts with a window object, breaking it if the unit is military and the window is in a broken or open state.
---
--- @param unit Unit The unit interacting with the window.
---
function SlabWallWindow:InteractWindow(unit)
	if not self:HasBrokenOrOpenState() then
		return
	end
	if self.pass_through_state ~= "intact" then
		return
	end
	if unit:GetPfClass() == CalcPFClass("neutral") then
		StoreErrorSource(unit, "Non-military unit tries to break a window")
		StoreErrorSource(self, "Windows tried to be broken by non-military unit")
	end
	local anim = unit:GetActionRandomAnim("BreakWindow")
	local stance = unit.stance == "Prone" and "Standing" or unit.stance
	if anim and unit:HasState(anim) then
		if unit.stance ~= stance then
			unit:PlayTransitionAnims(unit:GetIdleBaseAnim(stance))
		end
		unit:SetState(anim)
		repeat
			unit:SetAnimSpeed(1, unit:CalcMoveSpeedModifier())
			local time_to_hit = unit:TimeToMoment(1, "hit") or 0
			local t = Min(MulDivRound(200, 1000, Max(1, unit:GetMoveSpeed())), time_to_hit)
		until not WaitWakeup(t)
	else
		StoreErrorSource(unit, "Unit does not have break window animation ", anim)
		unit:SetState(unit:GetIdleBaseAnim(stance))
		unit:SetAnimPhase(1, Max(0, GetAnimDuration(unit:GetEntity(), unit:GetStateText()) - 1000))
		unit:Face(self)
	end
	if not IsValid(self) then
		return -- a trap may have destroyed the window
	end
	self:SetWindowState("broken")
	repeat
		unit:SetAnimSpeed(1, unit:CalcMoveSpeedModifier())
	until not WaitWakeup(unit:TimeToAnimEnd())
	Msg("WindowInteraction")
end

DefineClass.SlabTunnelWindow = {
	__parents = { "SlabTunnelPassThroughObj" },
	tunnel_type = const.TunnelTypeWindow,
	dbg_tunnel_color = const.clrMagenta,
	dbg_tunnel_zoffset = 30 * guic,
	action = "JumpOverShort",
	base_interact_cost = 0,
	base_move_cost = 0,
	base_drop_cost = 0,
}

---
--- Checks if the tunnel can be sprinted through.
---
--- @return boolean true if the tunnel's pass-through object is in the "open" state, false otherwise
function SlabTunnelWindow:CanSprintThrough()
	return self.pass_through_obj.pass_through_state == "open"
end

---
--- Interacts with a tunnel window object.
---
--- @param unit table The unit interacting with the tunnel window.
--- @param quick_play boolean Whether to quickly play the interaction animation.
--- @return boolean, boolean Whether the interaction was successful, and whether the quick play was used.
---
function SlabTunnelWindow:InteractTunnel(unit, quick_play)
	local obj = self.pass_through_obj
	local pass_through_state = IsKindOf(obj, "SlabWallWindowOpen") and "open" or obj.pass_through_state
	if not (pass_through_state == "open" or pass_through_state == "broken") then
		obj:InteractWindow(unit)
		-- check for blocked window or a trap may have killed the unit
		if (obj.pass_through_state ~= "open" and obj.pass_through_state ~= "broken") or unit:IsDead() then
			unit:Interrupt()
			return false, quick_play
		end
		if quick_play then
			Sleep(0) -- wait possible visibility update
			quick_play = unit:CanQuickPlayInCombat() -- the unit may have been detected while interacting the window
		end
	end
	return true, quick_play
end

---
--- Traverses a tunnel window by playing an animation and applying visual effects.
---
--- @param unit table The unit traversing the tunnel window.
--- @param pos1 table The starting position of the tunnel window.
--- @param pos2 table The ending position of the tunnel window.
--- @param quick_play boolean Whether to quickly play the traversal animation.
---
function SlabTunnelWindow:TraverseTunnel(unit, pos1, pos2, quick_play)
	assert(not self.invulnerable, "Why invulnerable windows are traversed?!?")
	if quick_play then
		unit:SetPos(pos2)
		unit:SetAxis(axis_z)
		unit:SetAngle(pos1:Equal2D(pos2) and self:GetVisualAngle() or CalcOrientation(pos1, pos2))
		return
	end
	local anim = unit:GetActionRandomAnim(self.action, false)

	local surface_fx_type, surface_pos = GetObjMaterial(pos1)
	PlayFX("MoveJumpWindow", "start", unit, surface_fx_type, surface_pos)

	local hit_thread = CreateGameTimeThread(function(unit, anim, pos)
		local delay = unit:GetAnimMoment(anim, "hit") or unit:GetAnimMoment(anim, "end") or unit:TimeToAnimEnd()
		WaitWakeup(delay)
		local surface_fx_type, surface_pos = GetObjMaterial(pos)
		PlayFX("MoveJumpWindow", "end", unit, surface_fx_type, surface_pos)
	end, unit, anim, pos2)
	unit:PushDestructor(function()
		DeleteThread(hit_thread)
	end)

	-- Todo: window jump through break cinematic moment
	local duration = GetAnimDuration(unit:GetEntity(), anim)
	if g_Combat and unit:IsLocalPlayerTeam() then
		SetAutoRemoveActionCamera(unit, unit, duration, nil, nil, nil, "no_wait")
	end

	unit:MovePlayAnim(anim, pos1, pos2)

	if IsValidThread(hit_thread) then
		Wakeup(hit_thread)
		Sleep(0)
	end
	unit:PopAndCallDestructor()
end

---
--- Checks if the tunnel window is blocked for the given unit.
---
--- @param u table The unit to check for blocking.
--- @return boolean True if the tunnel window is blocked, false otherwise.
---
function SlabTunnelWindow:IsBlocked(u)
	return self.pass_through_obj:IsBlocked()
end

---
--- Calculates the cost for a unit to traverse the slab tunnel window.
---
--- @param context table An optional table containing information about the context of the traversal, such as whether the player is controlling the unit and any modifiers to the walk or drop down cost.
--- @return number The total cost for the unit to traverse the slab tunnel window.
---
function SlabTunnelWindow:GetCost(context)
	if context and not context.player_controlled and self.pass_through_obj:IsBlocked(context.unit) then
		return -1 -- AI players can not use blocked windows
	end
	
	local interact_cost = self.base_interact_cost
	local move_cost = self.base_move_cost * (100 + (context and context.walk_modifier or 0)) / 100
	local drop_cost = self.base_drop_cost * (100 + (context and context.drop_down_modifier or 0)) / 100
	
	return interact_cost + move_cost + drop_cost
end

function OnMsg.GatherFXActions(list)
	table.insert(list, "OpenDoor")
	table.insert(list, "CloseDoor")
end

function OnMsg.GatherFXTargets(list)
	table.insert(list, "SlabWallDoor")
	table.insert(list, "Door")
end

-- C Interop

---
--- Returns the maximum length of the tunnel build queue.
---
--- @return number The maximum length of the tunnel build queue.
---
function GetTunnelBuildQueueLength()
	return 16000
end

---
--- Places a slab tunnel object at the specified location.
---
--- @param classname string The class name of the slab tunnel object to place.
--- @param pt1 table The starting point of the slab tunnel.
--- @param pt2 table The ending point of the slab tunnel.
--- @param base_cost number The base cost for traversing the slab tunnel.
--- @param modifier number A modifier to apply to the base cost.
---
function PlaceSlabTunnelFromC(classname, pt1, pt2, base_cost, modifier)
	local obj = PlaceObject(classname, {
		end_point = pt2,
		base_cost = base_cost,
		modifier = modifier,
	})
	obj:SetPos(pt1)
	obj:AddPFTunnel()
end

---
--- Adds tunnel object passability to the specified extended clip.
---
--- @param extendedClip table The extended clip to add tunnel object passability to.
---
function AddTunnelObjectPassability(extendedClip)
	MapForEach(extendedClip, "TunnelObject", function(obj)
		if IsObjectDestroyed(obj) then
			return
		end
		obj:PlaceTunnels("FromC")
	end)
end

---
--- Returns the slab passability data for the given point.
---
--- @param point table The point to get the slab passability data for.
--- @return boolean, number, table Whether slab passability data was found, the slab passability value, and the floor object.
---
function GetSlabPassDataFromC(point)
	local z, obj = GetSlabPassC(point)
	if not z then return false end
	return { z = z, floor_obj = obj, floor_type = "stairs" }
end

---
--- Prints the name of each map in the game.
---
--- This function creates a real-time thread that iterates through all the maps in the game and prints the name of each map to the console.
---
function DBG_CheckTunnelsOnAllMaps()
	CreateRealTimeThread(function()
		ForEachMap(ListMaps(), function()
			print(CurrentMap)
		end)
	end)
end
