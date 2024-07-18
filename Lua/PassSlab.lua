const.PassModifierStairs = 0

StancesList = { [0] = "", "Standing", "Crouch", "Prone" }
for idx, stance in ipairs(StancesList) do StancesList[stance] = idx end

local mask_all = 0
local mask_any = 2^32 - 1
local flags_enum = const.efVisible + const.efCollision
local flags_game_ignore = const.gofSolidShadow
local flags_collision_mask = const.cmDefaultObject
local flags_walkable = const.efPathSlab + const.efApplyToGrids

DefineClass.CursorPosIgnoreObject = {
	__parents = { "PropertyObject" }
}

--- Filters the cursor position to exclude objects of type "CursorPosIgnoreObject".
---
--- This function is used as a filter callback for the `GetClosestRayObj` function, which
--- is used to determine the closest object and position under the cursor. By excluding
--- "CursorPosIgnoreObject" objects, this filter ensures that the cursor position is not
--- snapped to those types of objects.
---
--- @param o any The object to filter.
--- @return boolean True if the object should be included, false if it should be excluded.
CursorPosFilter = function(o)
	return not IsKindOf(o, "CursorPosIgnoreObject")
end

MapVar("LastCursorPos", false)
MapVar("LastCursorObj", false)
MapVar("CursorPosFrameNo", false)
MapVar("LastWalkableCursorPos", false)
MapVar("LastWalkableCursorObj", false)
MapVar("WalkableCursorPosFrameNo", false)

--- Gets the current cursor position, updating the last cursor position if necessary.
---
--- This function returns the last known cursor position, either the walkable cursor position
--- or the regular cursor position, depending on the `walkable` parameter.
---
--- @param walkable boolean If true, returns the last known walkable cursor position. If false, returns the last known regular cursor position.
--- @return table|boolean The last known cursor position as a table with `x`, `y`, and `z` fields, or `false` if the position is unknown.
function GetCursorPos(walkable)
	UpdateLastCursor(walkable)
	if walkable then
		return LastWalkableCursorPos
	end
	return LastCursorPos
end

--- Gets the current cursor object, updating the last cursor object if necessary.
---
--- This function returns the last known cursor object. It calls `UpdateLastCursor()` to ensure
--- the last cursor position and object are up-to-date before returning the last cursor object.
---
--- @return any The last known cursor object, or `false` if the object is unknown.
function GetCursorObj()
	UpdateLastCursor()
	return LastCursorObj
end

---
--- Updates the last known cursor position and object.
---
--- This function is used to ensure the last cursor position and object are up-to-date.
--- It checks the current render frame number to avoid unnecessary updates, and then
--- uses `GetClosestRayObj` to determine the closest object and position under the cursor.
--- The results are stored in the `LastCursorPos`, `LastCursorObj`, `LastWalkableCursorPos`,
--- `LastWalkableCursorObj`, `CursorPosFrameNo`, and `WalkableCursorPosFrameNo` variables.
---
--- @param walkable boolean If true, updates the last known walkable cursor position. If false, updates the last known regular cursor position.
function UpdateLastCursor(walkable)
	local n = GetRenderFrame()
	if walkable then
		if n == WalkableCursorPosFrameNo then
			return
		end
	else
		if n == CursorPosFrameNo then
			return
		end
	end
	local src = camera.GetEye()
	local dest = (GetUIStyleGamepad() or not g_MouseConnected) and GetTerrainGamepadCursor() or GetTerrainCursor()
	local closest_obj, closest_pos
	if src and dest then
		closest_obj, closest_pos = GetClosestRayObj(src, dest, walkable and flags_walkable or flags_enum, flags_game_ignore, CursorPosFilter, mask_all, flags_collision_mask)
	end
	local pos = (closest_pos and not IsKindOf(closest_obj, "TerrainCollision")) and closest_pos or dest
	if walkable then
		LastWalkableCursorPos = pos or false
		LastWalkableCursorObj = closest_obj or false
		WalkableCursorPosFrameNo = n
	else
		LastCursorPos = pos or false
		LastCursorObj = closest_obj or false
		CursorPosFrameNo = n
	end
end

---
--- Gets the pass slab at the current cursor position.
---
--- @return table|nil The pass slab at the current cursor position, or `nil` if no pass slab is found.
function GetCursorPassSlab()
	return GetPassSlab(GetCursorPos())
end

---
--- Gets the packed position and stance of a unit.
---
--- This function is used to get the packed position and stance of a unit. It first checks if the unit is sitting, and if so, it gets the pass slab position of the unit's last visit. If the unit is not sitting, it gets the pass slab position of the unit's target dummy or the unit itself. If neither of these are available, it returns the packed position and stance of the unit.
---
--- @param unit table The unit to get the packed position and stance for.
--- @param stance string The stance of the unit.
--- @return string The packed position and stance of the unit.
function GetPackedPosAndStance(unit, stance)
	if IsValid(unit) then
		stance = stance or unit.stance
		local stance_idx = StancesList[stance]
		if IsSittingUnit(unit) then
			local x, y, z = GetPassSlabXYZ(unit.last_visit)
			if x then
				return stance_pos_pack(x, y, z, stance_idx)
			end
		end
		local x, y, z = GetPassSlabXYZ(unit.target_dummy or unit)
		if x then
			return stance_pos_pack(x, y, z, stance_idx)
		end
		return stance_pos_pack(unit, stance_idx)
	end
end

-- Slab spots can be 3 tiles aside from the object Origin
const.FloorSlabMaxRadius = 1 + sqrt(
	(3 * const.SlabSizeX + const.SlabSizeX / 2 + const.PassTileSize / 2) ^ 2 +
	(0 * const.SlabSizeX + const.SlabSizeX / 2 + const.PassTileSize / 2) ^ 2)

---
--- Snaps a 3D position to the nearest voxel grid position, adjusting the Z coordinate to be at the center of the slab.
---
--- @param x number The X coordinate of the position to snap.
--- @param y number The Y coordinate of the position to snap.
--- @param z number The Z coordinate of the position to snap.
--- @return number The snapped Z coordinate.
function SnapToVoxelZ(x, y, z)
	return select(3, SnapToVoxel(x, y, (z or terrain.GetHeight(x, y)) + const.SlabSizeZ / 2))
end

---
--- Finds the position where an object or position should fall down to.
---
--- This function is used to determine the position where an object or position should fall down to. It first checks if the object has the `efApplyToGrids` flag set, in which case it returns without finding a fall down position. It then gets the pass slab position for the object or position, and if the Z coordinate matches, it returns the pass slab position. If the Z coordinate does not match, it checks if the difference between the current Z and the pass slab Z is less than 50 units, and if so, it returns the pass slab position. If the pass slab position is not suitable, it uses the `WalkableSlabByPoint` function to find the nearest walkable slab position, and adjusts the Z coordinate accordingly.
---
--- @param obj_or_pos table|point The object or position to find the fall down position for.
--- @return number|nil The X coordinate of the fall down position, or `nil` if no suitable position is found.
--- @return number|nil The Y coordinate of the fall down position, or `nil` if no suitable position is found.
--- @return number|nil The Z coordinate of the fall down position, or `nil` if no suitable position is found.
function FindFallDownPos(obj_or_pos)
	local x, y, z
	if IsValid(obj_or_pos) then
		if obj_or_pos:GetEnumFlags(const.efApplyToGrids) ~= 0 then
			return -- these object will change the passability grid and would hang
		end
		x, y, z = obj_or_pos:GetPosXYZ()
	else
		x, y, z = obj_or_pos:xyz()
	end
	local pass_x, pass_y, pass_z = GetPassSlabXYZ(x, y, z)
	if x == pass_x and y == pass_y and z == pass_z then
		return
	end
	if pass_x then
		if z == pass_z then
			return pass_x, pass_y, pass_z
		end
		local stepz
		if x == pass_x and y == pass_y then
			stepz = pass_z or terrain.GetHeight(pass_x, pass_y)
		else
			stepz = GetVoxelStepZ(x, y)
		end
		local posz = z or terrain.GetHeight(x, y)
		if abs(posz - stepz) < 50*guic then
			return pass_x, pass_y, pass_z
		end
	end
	local slab, step_z = WalkableSlabByPoint(x, y, z, "downward only")
	pass_x, pass_y, pass_z = GetPassSlabXYZ(x, y, step_z)
	if not pass_x then
		pass_x, pass_y, pass_z = GetPassSlabXYZ(terrain.FindPassable(x, y, step_z, 0,  -1, -1, const.pfmVoxelAligned, true)) -- adjust Z
	end
	return pass_x, pass_y, pass_z
end

---
--- Checks if a unit should fall down to a new position.
---
--- This function is used to determine if a unit should fall down to a new position. It first checks if the unit's current command is not "FallDown". It then calls the `FindFallDownPos` function to get the position where the unit should fall down to. If the new position is different from the unit's current position, it checks the height difference between the current position and the new position. If the height difference is greater than or equal to 35 units, it sets the unit's command to "FallDown" with the new position.
---
--- @param unit table The unit to check for falling down.
---
function FallDownCheck(unit)
	if unit.command == "FallDown" then return end
	local x, y, z = FindFallDownPos(unit)
	if not x or unit:IsEqualPos(x, y, z) then
		return
	end
	local ux, uy, uz = unit:GetPosXYZ()
	local _, fall_z = WalkableSlabByPoint(x, y, z, "downward only")
	local _, unit_z = WalkableSlabByPoint(ux, uy, uz, "downward only")
	local current_z = uz or unit_z
	if fall_z ~= current_z then
		if current_z and (not fall_z or current_z - fall_z >= 35 * guic) then
			unit:SetCommand("FallDown", point(x, y, z), unit.command == "Cower")
		end
	end
end

---
--- Iterates through all units and checks if they should fall down to a new position.
---
--- This function is called when the passability of the map has changed. It iterates through all units and checks if they should fall down to a new position. It first waits for all other threads to complete, then checks each unit to see if it should fall down. If the unit's current command is not "FallDown", it checks if the unit is within the specified clip area (if provided), and if the unit is not a perpetual marker and is not parented to another object. If these conditions are met, it interrupts the unit and calls the `FallDownCheck` function to determine if the unit should fall down.
---
--- The function also checks all `ItemDropContainer` objects in the specified clip area (or the entire map if no clip area is provided) and calls the `GravityFall` function to make them fall down to a new position.
---
--- @param clip table|nil The clip area to check for units and item drop containers. If `nil`, the entire map is checked.
---
function UnitsFallDown(clip)
	WaitAllOtherThreads()
	for _, unit in ipairs(g_Units) do
		if IsValid(unit)
			and (not clip or clip:Point2DInside(unit))
			and unit.command ~= "FallDown"
			and not unit.perpetual_marker
			and not unit:GetParent()		-- e.g. Hanging Luc
		then
			unit:Interrupt(FallDownCheck)
		end
	end
	MapGet(clip or "map", "ItemDropContainer", function(obj)
		local x, y, z = FindFallDownPos(obj)
		if not x then return end
		CreateGameTimeThread(GravityFall, obj, point(x, y, z))
	end)
end

---
--- Rebuilds the area specified by the `clip` parameter. This function is called when the passability of the map has changed, or when the game exits the editor.
---
--- The function first checks if the `GameLogic` module is available. If not, it returns without doing anything.
---
--- It then rebuilds the slab tunnels and covers in the specified clip area. If the editor is active, it returns without doing anything further.
---
--- Next, it rebuilds the area interactables and creates a game time thread to handle units falling down in the specified clip area.
---
--- It then iterates through all units in the clip area and removes the "Protected" status effect from any units that cannot take cover.
---
--- Finally, it updates the passability hash and notifies the network of the passability change.
---
--- @param clip table|nil The clip area to rebuild. If `nil`, the entire map is rebuilt.
---
function RebuildArea(clip)
	if not mapdata.GameLogic then return end
	clip = IsBox(clip) and clip or nil
	--local t0 = GetPreciseTicks(1000)
	RebuildSlabTunnels(clip)
	RebuildCovers(clip)

	if IsEditorActive() then
		return
	end

	RebuildAreaInteractables(clip)
	CreateGameTimeThread(UnitsFallDown, clip)

	MapGet(clip or "map", "Unit", function(obj)
		if obj:GetStatusEffect("Protected") then
			if not obj:CanTakeCover() then
				obj:RemoveStatusEffect("Protected")
			end
		end
	end)
	UpdateTakeCoverAction()

	local pass_grid_hash = terrain.HashPassability()
	local tunnel_hash = terrain.HashPassabilityTunnels()
	NetUpdateHash("PassabilityChanged", pass_grid_hash, tunnel_hash)

	--local t = GetPreciseTicks() - t0
	--printf("Rebuild voxel pass: %dms", t)
end

OnMsg.OnPassabilityChanged = RebuildArea
function OnMsg.GameExitEditor()
	RebuildArea()
end

local formations =
{	-- looking up
	[1] = {
		{0, 0, 0},
		{0, 1, 0},
		{0, 0, 0}},
	[2] = {
		{0, 0, 0},
		{1, 0, 1},
		{0, 0, 0}},
	[3] = {
		{0, 0, 0},
		{1, 0, 1},
		{0, 1, 0}},
	[4] = {
		{0, 0, 0},
		{1, 0, 1},
		{1, 0, 1}},
	[5] = {
		{1, 0, 1},
		{0, 1, 0},
		{1, 0, 1}},
	[6] = {
		{1, 0, 1},
		{1, 0, 1},
		{1, 0, 1}},
}

local KeepFormOrientaionDist = 2

local function GetFormPositions(count, goto_pos, angle)
	local result = {}
	local form = formations[Clamp(count, 1, #formations)]
	local fcenter_x = 2
	local fcenter_y = 2
	local a = (AngleDiff(angle or 0, -90*60) + 45*60) / (90*60) * (90*60)
	local sina = sin(a) / 4096
	local cosa = cos(a) / 4096
	local x0, y0 = goto_pos:xyz()
	local tilesize = const.SlabSizeX
	for fy, row in ipairs(form) do
		for fx, value in ipairs(row) do
			if value ~= 0 then
				local x = x0 + ((fx - fcenter_x) * cosa - (fy - fcenter_y) * sina) * tilesize
				local y = y0 + ((fx - fcenter_x) * sina + (fy - fcenter_y) * cosa) * tilesize
				table.insert(result, point_pack(x, y))
			end
		end
	end
	return result
end

local function GetValidGotoDest(units, goto_pos)
	-- find reachable positions from goto_pos
	local pts = {}
	local function add(x, y, z, tunnel, pts, prev_idx)
		local pt = point_pack(SnapToVoxel(x, y, z))
		if pts[pt] then
			return
		end
		if (prev_idx or 0) > 1 then
			local x0, y0 = point_unpack(pts[1])
			if Max(abs(x - x0), abs(y - y0)) > 2 * const.SlabSizeX then
				return
			end
			local prev_x, prev_y = point_unpack(pts[prev_idx])
			if (x - prev_x) * (prev_x - x0) < 0 or (y - prev_y) * (prev_y - y0) < 0 then
				return
			end
		end
		pts[#pts + 1] = pt
		pts[pt] = pt
		if z then
			pts[point_pack(SnapToVoxel(x, y))] = pt
		end
	end
	local x, y, z = GetPassSlabXYZ(goto_pos)
	if x then
		add(x, y, z, nil, pts)
	end
	local i = 0
	while i < #pts do
		i = i + 1
		x, y, z = GetPassSlabXYZ(point_unpack(pts[i]))
		ForEachPassSlabStep(x, y, z, const.TunnelMaskWalk, add, pts, i)
	end

	-- remove other units destlocked positions
	local own_destlocks = {}
	for i, unit in ipairs(units) do
		if unit:GetEnumFlags(const.efResting) ~= 0 and unit:IsValidPos() then
			own_destlocks[point_pack(SnapToVoxel(unit:GetPosXYZ()))] = true
		end
		local o = unit:GetDestlock()
		if o and o:IsValidPos() then
			own_destlocks[point_pack(SnapToVoxel(o:GetPosXYZ()))] = true
		end
	end
	local r = const.SlabSizeX / 2
	local fCheckDestlock = function(obj, z)
		local oz = select(3, obj:GetPosXYZ()) or terrain.GetHeight(obj)
		if abs(oz - z) < guim then
			return true
		end
	end
	for i = #pts, 1, -1 do
		local id = pts[i]
		if not own_destlocks[id] then
			local pt = GetPassSlab(point_unpack(id))
			local z = pt:z() or terrain.GetHeight(pt)
			local o =
				MapGetFirst(pt, pt, r, nil, const.efResting, fCheckDestlock, z) or
				MapGetFirst(pt, pt, r, "Destlock", fCheckDestlock, z)
			if o then
				table.remove(pts, i)
				pts[id] = nil
			end
		end
	end
	return pts
end

local function AssignUnitsToFormPos(units, pts)
	local t = table.icopy(units)
	while #pts > 0 do
		local farthest_pt, farthest_dist, closest_unit
		for k, p in ipairs(pts) do
			local bestu, besti, bestx, besty
			local px, py = point_unpack(p)
			for i, u in ipairs(t) do
				local ux, uy = u:GetPosXYZ()
				if not besti or IsCloser2D(px, py, ux, uy, bestx, besty) then
					bestu, besti, bestx, besty = u, i, ux, uy
				end
			end
			local closest_dist = point(bestx, besty):Dist2D(px, py)
			if not farthest_dist or farthest_dist < closest_dist then
				farthest_pt = k
				farthest_dist = closest_dist
				closest_unit = besti
			end
		end
		local unit = t[closest_unit]
		local p = pts[farthest_pt]
		t[unit] = p
		table.remove(t, closest_unit)
		table.remove(pts, farthest_pt)
	end
	for i, u in ipairs(units) do
		pts[i] = t[u] or false
	end
	return pts
end

---
--- Calculates the destination positions for a group of units to move to a given position, while maintaining a formation.
---
--- @param units table The list of units to assign destinations to.
--- @param goto_pos point The position the units should move towards.
--- @return table The assigned destination positions for each unit.
--- @return number The calculated orientation angle for the formation.
---
function GetUnitsDestinations(units, goto_pos)
	goto_pos = SnapToVoxel(goto_pos)
	local angle = 0
	if #units > 1 then
		local count, x, y = 0, 0, 0
		for i, u in ipairs(units) do
			if u:IsValidPos() then
				local posx, posy = u:GetPosXYZ()
				local vx, vy = WorldToVoxel(posx, posy, 0)
				x = x + vx
				y = y + vy
				count = count + 1
			end
		end
		local center = count > 0 and point(VoxelToWorld((x + count/2) / count, (y + count/2) / count)) or goto_pos
		if not IsCloser2D(center, goto_pos, KeepFormOrientaionDist * const.SlabSizeX + 1) then
			angle = CalcOrientation(center, goto_pos)
		else
			-- guess angle
			local best_dist, best_angle
			for i = 1, 4 do
				local a = (i-1)*90*60
				local form_pts = GetFormPositions(#units, center, a)
				local assigned_pts = AssignUnitsToFormPos(units, form_pts)
				local d = 0
				for i, unit in ipairs(units) do
					if unit:IsValidPos() and assigned_pts[i] then
						d = d + unit:GetDist2D(point_unpack(assigned_pts[i]))
					end
				end
				if not best_dist or d < best_dist then
					best_dist = d
					best_angle = a
				end
			end
			angle = AngleNormalize(best_angle)
		end
	end

	local form_pts = GetFormPositions(#units, goto_pos, angle)
	local valid_pos = GetValidGotoDest(units, goto_pos)
	local destinations = {}

	for i = #form_pts, 1, -1 do
		local p = form_pts[i]
		local pos = valid_pos[p]
		if pos then
			table.insert(destinations, pos)
			valid_pos[p] = nil
			table.remove_value(valid_pos, pos)
			table.remove(form_pts, i)
		end
	end
	-- find alternative positions 
	while #valid_pos > 0 and #destinations < #units do
		local form_x, form_y
		if #form_pts > 0 then
			form_x, form_y = point_unpack(form_pts[#form_pts])
		else
			form_x, form_y = goto_pos:xy()
		end
		local d = const.SlabSizeX / 2
		local spotx = form_x + Clamp(goto_pos:x() - form_x, -d, d)
		local spoty = form_y + Clamp(goto_pos:y() - form_y, -d, d)
		local besti = 1
		local bestx, besty = point_unpack(valid_pos[besti])
		for i = 2, #valid_pos do
			local ix, iy = point_unpack(valid_pos[i])
			if IsCloser2D(spotx, spoty, ix, iy, bestx, besty) then
				besti, bestx, besty = i, ix, iy
			end
		end
		local p = valid_pos[besti]
		table.insert(destinations, p)
		valid_pos[p] = nil
		table.remove(valid_pos, besti)
		table.remove(form_pts, #form_pts)
	end
	local assigned_dest = AssignUnitsToFormPos(units, destinations)
	return assigned_dest, angle
end

-- IsOccupied depends on target dummies, which are not present outside combat.
---
--- Checks if a position is occupied during exploration mode.
---
--- @param unit table|nil The unit performing the exploration
--- @param x number The x-coordinate of the position to check
--- @param y number The y-coordinate of the position to check
--- @param z number|nil The z-coordinate of the position to check
--- @return boolean Whether the position is occupied
---
function IsOccupiedExploration(unit, x, y, z)
	if g_Combat then
		return IsOccupied(x, y, z)
	elseif unit then
		return not CanDestlock(unit, x, y, z)
	end
	return not CanDestlock(x, y, z or const.InvalidZ, Unit.radius)
end

---
--- Checks for detail objects that can affect passability and stores error sources for them.
---
--- This function iterates through all objects in the map, and for each object that is not marked as "Essential":
--- - If the object is not essential, it is added to the `offending_objs` table.
--- - If the object is managed by a floating dummy, it is removed from the `offending_objs` table.
--- - For each remaining object in `offending_objs`, an error source is stored indicating that the object will provoke a pass grid rebuild on object details change.
---
--- @param none
--- @return none
---
function CheckForDetailObjsAffectingPassability()
	local dummy_collections = {}
	local offending_objs = {}
	
	local function process(o)
		--acknowledge dummies
		if IsKindOf(o, "FloatingDummy") then
			dummy_collections[o:GetCollectionIndex()] = o
		end
		
		--any parent that is non essential can hide/show this obj
		local parent = o:GetParent()
		local dc = o:GetDetailClass()
		while dc == "Essential" and parent do
			dc = parent:GetDetailClass()
			parent = parent:GetParent()
		end
		
		if dc ~= "Essential" then
			if not o:ObjEssentialCheck() then
				table.insert(offending_objs, o)
			end
		end
	end
	MapForEach("map", "CObject", process)
	
	for i = #offending_objs, 1, -1 do
		local o = offending_objs[i]
		local topParent = GetTopmostParent(o)
		if dummy_collections[topParent:GetCollectionIndex() or 0] then
			table.remove(offending_objs, i) --managed by floating dummy presumably
		end
	end
	
	for i, o in ipairs(offending_objs) do
		StoreErrorSource(o, "Object will provoke pass grid rebuild on object details change!")
	end
end

function OnMsg.PreSaveMap()
	CheckForDetailObjsAffectingPassability()
end

