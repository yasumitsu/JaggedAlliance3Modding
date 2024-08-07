if FirstLoad then
	RoofVisualsEnabled = true
	GableRoofDirections = { "North-South", "East-West" }
end

local voxelSizeX = const.SlabSizeX or 0
local voxelSizeY = const.SlabSizeY or 0
local voxelSizeZ = const.SlabSizeZ or 0
local halfVoxelSizeX = voxelSizeX / 2
local halfVoxelSizeY = voxelSizeY / 2
local halfVoxelSizeZ = voxelSizeZ / 2
local InvalidZ = const.InvalidZ
local noneWallMat = const.SlabNoMaterial

CardinalDirectionNames = { "East", "South", "West", "North" }
local cardinal_direction_names = CardinalDirectionNames
local cardinal_directions = {
	0 * 60, 90 * 60, 180 * 60, 270 * 60,
	East = 0 * 60,
	South = 90 * 60,
	West = 180 * 60,
	North = 270 * 60,
}
local cardinal_steps = {point(voxelSizeX, 0, 0), point(0, voxelSizeY, 0), point(-voxelSizeX, 0, 0), point(0, -voxelSizeY, 0)}
local cardinal_offsets = {{voxelSizeX, 0, 0}, {0, voxelSizeY, 90 * 60}, {-voxelSizeX, 0, 180 * 60}, {0, -voxelSizeY, 270 * 60}}

function GetCardinalOffsets()
	return cardinal_offsets
end

DefineClass.SkewAlign = {
	__parents = { "CObject" },
	flags = { cfSkewAlign = true, },
}

DefineClass.RoomRoof = {
	__parents = { "PropertyObject" },
	properties = {
		{ category = "Roof", id = "roof_type", name = "Roof Type", editor = "preset_id", default = "", preset_class = "RoofTypes" },
		{ category = "Roof", id = "roof_mat", name = "Roof Material", editor = "preset_id", preset_class = "SlabPreset", preset_group = "RoofSlabMaterials", default = "" },
		{ category = "Roof", id = "roof_parapet", name = "Roof Parapet", editor = "bool", default = false },
		{ category = "Roof", id = "roof_direction", name = "Roof Direction", editor = "dropdownlist",
			items = function(obj) return obj:IsAnyOfRoofTypes("Gable") and GableRoofDirections or cardinal_direction_names end, default = "North",
			no_edit = function(obj) return not obj:IsAnyOfRoofTypes("Shed", "Gable") end },
		{ category = "Roof", id = "roof_inclination", name = "Roof Inclination", editor = "number", scale = "deg", default = 20 * 60, min = 0*60, max = 45*60, slider = true,
			no_edit = function(obj) return not obj:IsAnyOfRoofTypes("Shed", "Gable") end },
		{ category = "Roof", id = "roof_additional_height", name = "Additional Height", editor = "number", scale = "m", default = 0, min = 0, max = const.SlabSizeZ, slider = true },
		{ category = "Roof", name = "Has Ceiling", id = "build_ceiling", editor = "bool", default = true, },
		{ category = "Roof", name = "Ceiling Material", id = "ceiling_mat", editor = "preset_id", preset_class = "SlabPreset", preset_group = "FloorSlabMaterials", extra_item = noneWallMat, default = noneWallMat, },
		{ category = "Roof", id = "roof_colors", name = "Roof Color Modifier", editor = "nested_obj", base_class = "ColorizationPropSet", inclusive = true, default = false, },
		
		{ category = "Not Room Specific", id = "roofVisualsEnabled",  name = "Toggle Roof Visuals", default = true, editor = "bool", dont_save = true },
		
		{ id = "roof_objs", no_edit = true, editor = "objects", default = false, },
		{ category = "Debug", id = "is_roof_visible", editor = "bool", default = true, dont_save = true, read_only = true },
		
		{ id = "RoofInclinationIP", name = T(770322265919, "Roof Inclination"), editor = "number", default = 0, no_edit = true, dont_save = true, min = 0*60, max = 45*60 },
		
		{ category = "Roof", id = "keep_roof_passable", name = "Keep Roof Passable", editor = "bool", default = false, },
		{ category = "Roof", id = "roof_buttons", name = "Buttons", editor = "buttons", default = false, dont_save = true, read_only = true,
			buttons = {
				{name = "Make Roof Passable", func = "MakeRoofPassable"},
			},
		},
		
		{ id = "vfx_roof_surface_controllers", editor = "objects", default = false, dont_save = true, no_edit = true},
		{ id = "vfx_eaves_controllers", editor = "objects", default = false, dont_save = true, no_edit = true},
	},
	
	roof_box = false,
	
	prop_map = false,
	box_at_last_roof_edit = false,
	rr_recursing = false,
}

---
--- Returns the roof inclination in IP (internal presentation) units.
---
--- @return number roof_inclination The roof inclination in IP units.
---
function RoomRoof:GetRoofInclinationIP()
	return self.roof_inclination
end

---
--- Rebuilds chimneys in a 2D box.
---
--- This function is a stub and does not currently have any implementation.
---
function RebuildChimneysInBox2D()
	--print("stub")
end

---
--- Sets the roof inclination in IP (internal presentation) units.
---
--- @param roof_inclination number The new roof inclination in IP units.
---
function RoomRoof:SetRoofInclinationIP(roof_inclination)
	if self.roof_inclination ~= roof_inclination then
		NetSyncEvent("ObjFunc", self, "rfnSetRoofInclination", roof_inclination)
	end
end

---
--- Sets the roof inclination in IP (internal presentation) units.
---
--- @param roof_inclination number The new roof inclination in IP units.
---
function RoomRoof:rfnSetRoofInclination(roof_inclination)
	if self.roof_inclination ~= roof_inclination then
		self.roof_inclination = roof_inclination
		self:RecreateRoof()
		ObjModified(self)
	end
end

---
--- Returns the size of the roof.
---
--- @return table size The size of the roof.
---
function RoomRoof:GetRoofSize()
	return self.size
end

--- Returns the roof type.
---
--- @return string roof_type The type of the roof.
---
function RoomRoof:GetRoofType()
	return self.roof_type
end

---
--- Returns the entity set for the roof material.
---
--- @return string|nil The entity set for the roof material, or nil if no roof material is set.
---
function RoomRoof:GetRoofEntitySet()
	local roof_mat = self.roof_mat or ""
	if roof_mat == "" then return end
	local preset = Presets.SlabPreset.RoofSlabMaterials[roof_mat]
	return preset and preset.EntitySet or ""
end

---
--- Returns the roof inclination.
---
--- If the roof type is "Flat", this will return 0. Otherwise, it will return the roof_inclination value.
---
--- @return number The roof inclination.
---
function RoomRoof:GetRoofInclination()
	if self:GetRoofType() == "Flat" then
		return 0
	end
	
	return self.roof_inclination
end

---
--- Checks if the roof is set.
---
--- @return boolean True if the roof material and type are set, false otherwise.
---
function RoomRoof:HasRoofSet()
	return self.roof_mat ~= "" and self.roof_type ~= ""
end

--- Checks if there is a room above the current room.
---
--- @return boolean True if there is a room above the current room, false otherwise.
function RoomRoof:HasRoomAbove()
	local bbox = self.box:grow(const.SlabSizeX, const.SlabSizeY, const.SlabSizeZ)
	local volumes = EnumVolumes(bbox, function(volume)
		if volume.floor == self.floor + 1 then
			return true
		end
	end)
	
	return volumes and #volumes > 0
end

---
--- Checks if the room has a roof and if the room is the biggest encompassing room with a roof.
---
--- @param scan_rooms_above boolean Whether to check for a room above the current room.
--- @return boolean True if the room has a roof and is the biggest encompassing room with a roof, false otherwise.
---
function RoomRoof:HasRoof(scan_rooms_above)
	if self:HasRoofSet() then
		if self:IsRoofOnly() then
			return true
		end
		local mrz = select(3, self:GetPosXYZ()) + self.size:z() * voxelSizeZ
		local biggestRoom = self:GetBiggestEncompassingRoom(function(o, mrz)
			local rz = select(3, o:GetPosXYZ()) + o.size:z() * voxelSizeZ
			if rz < mrz then
				return false
			elseif not o:HasRoof() then
				return false
			end
			return true
		end, mrz)
		if biggestRoom ~= self then
			return scan_rooms_above and self:HasRoomAbove()
		end

		local adjacent_rooms = self.adjacent_rooms
		local sizex, sizey = self.box:sizexyz()
		local boxes
		local totalFace = 0
		local myFace = sizex * sizey

		for _, room in ipairs(adjacent_rooms) do
			if not room.being_placed then
				local data = adjacent_rooms[room]
				local ib = data[1]
				if ib:sizez() == 0 and table.find(data[2], "Roof") then --he is above us
					local szx, szy = ib:sizexyz()
					local hisFace = szx * szy
					boxes = boxes or {}
					for i = 1, #boxes do
						local dx, dy = IntersectSize(ib, boxes[i])
						if dx > 0 and dy > 0 then
							hisFace = hisFace - dx * dy
						end
					end
					table.insert(boxes, ib)
					totalFace = totalFace + hisFace
				end
			end
		end
		if myFace - totalFace <= 0 then
			return scan_rooms_above and self:HasRoomAbove() --completely covered by upper nbrs
		end

		return true
	end
	
	return scan_rooms_above and self:HasRoomAbove()
end

--- Checks if the room's roof type matches any of the provided roof types.
---
--- @param ... string The roof types to check against.
--- @return boolean True if the room's roof type matches any of the provided types, false otherwise.
function RoomRoof:IsAnyOfRoofTypes(...)
	local roof_type = self:GetRoofType()
	for i=1,select("#", ...) do
		if roof_type == select(i, ...) then
			return true
		end
	end
end

--- Returns the thickness of the room's roof.
---
--- @return number The thickness of the room's roof.
function RoomRoof:GetRoofThickness()
	local entity_set = self:GetRoofEntitySet()
	if entity_set == "" then return 0 end
	
	local entity_name = string.format("Roof_%s_Plane_01", entity_set)
	if not IsValidEntity(entity_name) then return 0 end
	
	local bbox = GetEntityBoundingBox(entity_name)
	return bbox:sizez()
end

--- Sets the visibility of the room's roof objects.
---
--- @param visible boolean True to make the roof objects visible, false to hide them.
function RoomRoof:SetRoofVisibility(visible)
	local objs = self.roof_objs
	if not objs or #objs <= 0 then return end
	if self.is_roof_visible == visible then return end
	
	self.is_roof_visible = visible
	local hide = not visible
	
	for i=1,#objs do
		local o = objs[i]
		if IsValid(o) then
			o:SetShadowOnly(hide)
		end
	end
	local wire_supporters = {}
	assert(self.roof_box, string.format("Room %s with .roof_objs (count:%d), but no roof_box!", self.name, #objs))
	if g_Classes.WireSupporter and self.roof_box then --this does not exist in bacon, apparently the old code never found any objs on roofs in bacon so it never asserted.
		local query_box = self.roof_box:grow(1)
		local min_z = query_box:minz()
	
		MapForEach(query_box, "WireSupporter", function(o, min_z, wire_supporters)
			local x, y, z = o:GetVisualPosXYZ()
			local is_on_roof = o:GetGameFlags(const.gofOnRoof) ~= 0
			if z >= min_z and is_on_roof then
				table.insert(wire_supporters, o)
			end
		end, min_z, wire_supporters)
	end
	
	ForEachConnectedWire(wire_supporters, function(wire)
		wire:SetVisible(visible)
	end)
	
	for side, t in sorted_pairs(self.spawned_windows or empty_table) do
		for i = 1, #(t or "") do
			local w = t[i]
			if w.hide_with_wall and IsKindOf(w.main_wall, "RoofWallSlab") then
				w:SetShadowOnly(hide)
			end
		end
	end
	
	if hide then
		(rawget(_G, "CollectionsToHideHideCollections") or empty_func)(self, "Roof")
	else
		(rawget(_G, "CollectionsToHideShowCollections") or empty_func)(self, "Roof")
	end
	
	self:SetVfxControllersVisibility(visible)
end

--- Deletes all roof objects associated with this RoomRoof instance.
---
--- This function iterates through the `roof_objs` table and calls `DoneObject` on each valid object to remove it from the game. It then sets the `roof_objs` table to `nil`.
---
--- @function RoomRoof:DeleteRoofObjs
--- @return nil
function RoomRoof:DeleteRoofObjs()
	for _, roof in ipairs(self.roof_objs) do
		if IsValid(roof) then
			DoneObject(roof)
		end
	end
	self.roof_objs = nil
end

--- Processes a plane slab in the room roof.
---
--- This function sets the appropriate enum flags on the slab based on whether it is a flat slab or an inclined slab. If the slab is flat, it clears the `efInclinedSlab` flag and sets the `efApplyToGrids` flag. If the slab is inclined and the roof inclination is less than or equal to `const.MaxPassableTerrainSlope`, it sets both the `efApplyToGrids` and `efInclinedSlab` flags. Otherwise, it clears both flags.
---
--- @param slab RoofWallSlab The slab to process
--- @param is_flat boolean Whether the slab is flat or inclined
--- @return nil
function RoomRoof:PostProcessPlaneSlab(slab, is_flat)
	if is_flat then
		slab:ClearEnumFlags(const.efInclinedSlab)
		slab:SetEnumFlags(const.efApplyToGrids)
	elseif self:GetRoofInclination() <= const.MaxPassableTerrainSlope then
		slab:SetEnumFlags(const.efApplyToGrids | const.efInclinedSlab)
	else
		slab:ClearEnumFlags(const.efApplyToGrids | const.efInclinedSlab)
	end
end

local function IsRoofTile(o) --roof tile or part of walls
	return not IsKindOfClasses(o, "RoofWallSlab", "RoofCornerWallSlab", "CeilingSlab", "DestroyableWallDecoration")
end

local slabPoint = point(voxelSizeX, voxelSizeY, voxelSizeZ)
local function GetElHashId(o, pivots)
	pivots = pivots or o.room:GetPivots()
	
	if not IsRoofTile(o) then
		local s = o.side
		local dp = (o:GetPos() - pivots[s])
		local x, y, z = abs(dp:x()) / voxelSizeX, abs(dp:y()) / voxelSizeY, abs(dp:z()) / voxelSizeZ
		--print(pivots[s], o:GetPos(), dp, s, o.class, x, y, z, o.room:GetRoofZAndDir(o.room.box:min()))
		return xxhash(s, x, y, z, IsKindOf(o, "RoomCorner") or false)
	else
		local dp = (o:GetPos() - pivots[false])
		--print(pivots[false], o:GetPos(), dp, false, o.class, 0, 0, 0, o.room:GetRoofZAndDir(o.room.box:min()))
		return xxhash(dp:x(), dp:y(), o:GetAngle(), o.class, rawget(o, "dir") or false)
	end
end

--- Gets the wall begin position for the specified side of the room's bounding box.
---
--- @param side string The cardinal direction of the wall (North, South, West, East)
--- @param box? BoundingBox The bounding box to use, or the room's bounding box if not provided
--- @return point The position of the wall's beginning
function RoomRoof:GetWallBeginPos(side, box)
	local b = box or self.box
	if side == "North" then
		return point(b:minx(), b:miny(), b:maxz())
	elseif side == "South" then
		return point(b:maxx(), b:maxy(), b:maxz())
	elseif side == "West" then
		return point(b:minx(), b:maxy(), b:maxz())
	else --east
		return point(b:maxx(), b:miny(), b:maxz())
	end
end

--- Gets the pivots for the room's bounding box.
---
--- @param box? BoundingBox The bounding box to use, or the room's bounding box if not provided
--- @return table The pivots for each cardinal direction, with the pivot for roof tiles stored under the `false` key
function RoomRoof:GetPivots(box)
	box = box or self.box
	local pivots = {}
	for _, side in ipairs(cardinal_direction_names) do
		pivots[side] = self:GetWallBeginPos(side, box)
	end

	pivots[false] = pivots.North --pivot for roof tiles	
	return pivots
end

--- Cleans up the property map for the room roof.
---
--- The property map is used to store properties of roof objects. This function
--- sets the `prop_map` field to `false`, effectively clearing the property map.
function RoomRoof:CleanupPropMap()
	self.prop_map = false
end

--- Applies properties from a property map to the specified object.
---
--- @param o table The object to apply the properties to
--- @param prop_map? table The property map to use, or the room's property map if not provided
--- @param pivots? table The pivots to use for calculating the property map ID, or the room's pivots if not provided
function RoomRoof:ApplyPropsFromPropObj(o, prop_map, pivots)
	prop_map = prop_map or self.prop_map
	pivots = pivots or self:GetPivots()
	if prop_map then
		local id = GetElHashId(o, pivots)
		local po = prop_map[id]
		if po then
			o:CopyProperties(po, po:GetProperties())
		--else
			--print("not found!", id)
		end
	end
end

--- Populates the property map for the room roof.
---
--- The property map is used to store properties of roof objects. This function
--- iterates through the roof objects, creates a property holder for each object,
--- and stores it in the property map. It also stores the maximum Z coordinate
--- of the room's bounding box in the property map under the "minz" key.
---
--- @param self RoomRoof The RoomRoof instance
function RoomRoof:PopulatePropMap()
	self:CleanupPropMap()
	self.prop_map = {}
	
	local pivots = self:GetPivots(self.box_at_last_roof_edit or self.box)
	
	for i = 1, #(self.roof_objs or "") do
		local o = self.roof_objs[i]
		if IsValid(o) and not IsKindOfClasses(o, "CeilingSlab") then
			local id = GetElHashId(o, pivots)
			--assert(self.prop_map[id] == nil) --in rooms of size 1 tile we cannot guarantee unique ids for all elements
			local propO = SlabPropHolder:new()
			propO:CopyProperties(o)
			self.prop_map[id] = propO
		end
	end
	self.prop_map["minz"] = self.box_at_last_roof_edit and self.box_at_last_roof_edit:maxz() or self.box:maxz() --"minz" is used as roof box minz, which is box:maxz
	self.box_at_last_roof_edit = self.box
end

local visibilityStateForNewRoofPieces = true
--- Recreates the room's roof.
---
--- This function is responsible for recreating the room's roof. It first suspends pass edits, then populates the property map and deletes any existing roof objects. If the room has a roof set and the force parameter is true or the room actually has a roof, the function proceeds to create the roof based on the room's roof type. It also creates a ceiling if the build_ceiling flag is set. After creating the roof, the function snaps the objects, updates the roof slab visibility, and handles the visibility state for new roof pieces. Finally, it rebuilds the chimneys in the room's bounding box and, if the keep_roof_passable flag is set, makes the roof passable.
---
--- @param self RoomRoof The RoomRoof instance
--- @param force? boolean If true, the roof will be recreated even if it hasn't changed
function RoomRoof:RecreateRoof(force)
	SuspendPassEdits("RoomRoof")
	self:PopulatePropMap()
	self:DeleteRoofObjs()

	if self:HasRoofSet() and (force or self:HasRoof()) then
		visibilityStateForNewRoofPieces = self.is_roof_visible and RoofVisualsEnabled and (not IsEditorActive() or LocalStorage.FilteredCategories["Roofs"])
		local roof_type = self:GetRoofType()
		local method_name = string.format("Create%sRoof", roof_type)
		local method = self[method_name]
		self.roof_objs, self.roof_box = method(self)
		if self.build_ceiling then
			self:CreateCeiling(self.roof_objs)
		end
		self:SnapObjects()
	end
	
	visibilityStateForNewRoofPieces = true
	
	self:UpdateRoofSlabVisibility()
	if not self.is_roof_visible then
		self.is_roof_visible = true --force setter
		self:SetRoofVisibility(false)
	end
	
	if not RoofVisualsEnabled then
		self:SetroofVisualsEnabledForRoom(false)
	end
	
	RebuildChimneysInBox2D(self.box)
	
	if self.keep_roof_passable and not self.rr_recursing then
		--sub optimal, dobule recreate, should be fine for f3 only.
		self.rr_recursing = true
		self:MakeRoofPassable()
		self.rr_recursing = false
	end
	
	ResumePassEdits("RoomRoof")
end

local up = point(0, 0, 4096)
local ptx = point(4096, 0, 0)
local pty = point(0, 4096, 0)
---
--- Snaps an object to the roof position and aligns it with the roof's orientation.
---
--- This function is responsible for snapping an object to the roof position and aligning it with the roof's orientation. It first sets the game flags for the object to indicate that it is on the roof. It then calculates the target position for the object based on the roof's z-coordinate and thickness. If the object is not a decal, the target position is adjusted to account for the roof thickness.
---
--- The function then calculates the roof's forward vector and the target up vector for the object. If the object is skewed, the target up vector is set to the global up vector. Otherwise, the target up vector is calculated based on the roof's orientation.
---
--- The function then rotates the object to align it with the target up vector. If the object's up vector is different from the target up vector, the function calculates the axis and angle of rotation and applies it to the object.
---
--- If the object is skewed, the function calculates the skew values based on the roof's forward vector and the object's local forward and right vectors. It then applies the skew values to the object.
---
--- Finally, the function returns the target position and up vector for the object.
---
--- @param self RoomRoof The RoomRoof instance
--- @param obj CObject The object to be snapped to the roof
--- @return point, point The target position and up vector for the object
function RoomRoof:SnapObject(obj)
	obj:SetGameFlags(const.gofOnRoof)
	local skew = obj:GetClassFlags(const.cfSkewAlign) ~= 0
	
	--snap to roof pos
	local pos = obj:GetVisualPos()
	local roof_z, roof_dir = self:GetRoofZAndDir(pos)
	if not IsKindOf(obj, "Decal") then
		local thickness = self:GetRoofThickness()
		roof_z = roof_z + thickness
	end
	local target_pos = pos:SetZ(roof_z)
	obj:SetPos(target_pos)
	
	--roof forward vector
	local roof_fwd_y, roof_fwd_x = sincos(roof_dir)
	local roof_fwd_z = sin(self:GetRoofInclination())
	local roof_forward = SetLen(point(roof_fwd_x, roof_fwd_y, roof_fwd_z), 4096)
	
	--object target up vector
	local target_up
	if skew then
		target_up = up
	else
		local roof_right = SetLen(point(-roof_fwd_y, roof_fwd_x, 0), 4096)
		local roof_up = Cross(roof_forward, roof_right) / 4096
		target_up = roof_up
	end
	
	--rotate object (align with target up)
	local obj_axis = obj:GetAxis()
	local obj_angle = obj:GetAngle()
	local obj_up = RotateAxis(point(0, 0, 4096), obj_axis, obj_angle)
	
	if obj_up ~= target_up then
		local axis, angle = GetAxisAngle(obj_up, target_up)
		local axis, angle = ComposeRotation(obj_axis, obj_angle, axis, angle)
		obj:SetAxisAngle(axis, angle)
	end
	
	--skew object
	if skew then
		--determine roof 2D forward vector
		local roof_forward_2d = SetLen(roof_forward:SetZ(0), 4096)
		
		--determine object-local forward/right vectors
		local obj_axis = obj:GetAxis()
		local obj_angle = obj:GetAngle()
		local obj_x = RotateAxis(ptx, obj_axis, obj_angle)
		local obj_y = RotateAxis(pty, obj_axis, obj_angle)
		
		--calculate skew
		local dot_x = Dot(roof_forward_2d, obj_x) / 4096
		local dot_y = Dot(roof_forward_2d, obj_y) / 4096
		
		local skew_x = MulDivRound(roof_fwd_z, dot_x*guim, 4096*4096)
		local skew_y = MulDivRound(roof_fwd_z, dot_y*guim, 4096*4096)
		obj:SetSkew(skew_x, skew_y)
	else
		obj:SetSkew(0, 0)
	end
	
	return target_pos, target_up
end

---
--- Calculates the skew values for an object based on the roof's coordinate system at the given position.
---
--- @param pos table The position to calculate the skew values for.
--- @return number skew_x The x-axis skew value.
--- @return number skew_y The y-axis skew value.
function RoomRoof:GetSkewAtPos(pos)
	local ox,oy,oz, fx,fy,fz,fs, rx,ry,rz,rs = self:GetRoofCoordSystem(pos)
	local skew_x, skew_y = MulDivRound(-fz, guim, abs(fx + rx)), 0
	
	return skew_x, skew_y
end

---
--- Snaps objects within the room's roof volume to the minimum height of the roof.
---
--- This function iterates through all CObject instances that are on the roof (have the `const.gofOnRoof` flag set) and checks if they are below the minimum height of the roof. If an object is below the minimum height and not inside any rooms above the roof, the object is snapped to the minimum height of the roof.
---
--- @param self RoomRoof The RoomRoof instance.
function RoomRoof:SnapObjects()
	if not self:HasRoof() then return end
	
	local above_rooms = MapGet(self:GetPos(), roomQueryRadius, "Room", function(room, my_maxz)
		return room.box and room.box:maxz() > my_maxz
	end, self.box:maxz())
	local min_z = self.prop_map and self.prop_map["minz"] or self.roof_box:minz()
	
	MapForEach(
		self.roof_box, --area
		"CObject", --class
		false, --enum flags (all)
		false, --enum flags (any)
		false, --game flags (all)
		const.gofOnRoof, --game flags (any)
		false, --class flags (all)
		false, --class flags (any)
		function(obj, above_rooms, min_z) --action
			local x, y, z = obj:GetVisualPosXYZ()
			if z < min_z then return end
			for _, room in ipairs(above_rooms) do
				if IsPointInVolume2D(room, obj) then
					return
				end
			end
			self:SnapObject(obj)
		end,
		above_rooms, min_z)
end

---
--- Recalculates the roof based on the current roof type.
---
--- This function is responsible for recalculating the roof geometry based on the current roof type. It calls the appropriate recalculation method for the specific roof type.
---
--- @param self RoomRoof The RoomRoof instance.
function RoomRoof:RecalcRoof()
	if not self.roof_objs then return end
	
	local roof_type = self:GetRoofType()
	local method_name = string.format("Recalc%sRoof", roof_type)
	local method = self[method_name]
	method(self)
end

---
--- Gets the coordinate system for the roof based on the current roof type.
---
--- This function determines the appropriate coordinate system for the roof based on the current roof type. It calls the corresponding `Get<RoofType>RoofCoordSystem` method to retrieve the coordinate system parameters.
---
--- @param self RoomRoof The RoomRoof instance.
--- @param pt point The point to get the coordinate system for.
--- @return number, number, number, number, number, number, number, number, number, number The origin x, y, z, forward x, y, z, forward scale, right x, y, z, right scale.
---
function RoomRoof:GetRoofCoordSystem(pt)
	if not self:HasRoof() then return end
	
	local roof_type = self:GetRoofType()
	local method_name = string.format("Get%sRoofCoordSystem", roof_type)
	local method = self[method_name]
	return method(self, pt)
end

---
--- Gets the clipping plane for the roof based on the current roof type.
---
--- This function calculates the clipping plane for the roof based on the current roof type. It uses the `GetRoofCoordSystem` function to retrieve the coordinate system parameters for the roof, and then constructs the clipping plane from three points in that coordinate system.
---
--- @param self RoomRoof The RoomRoof instance.
--- @param pt point The point to get the clipping plane for.
--- @return plane The clipping plane for the roof.
---
function RoomRoof:GetRoofClippingPlane(pt)
	local ox,oy,oz, fx,fy,fz,fs, rx,ry,rz,rs = self:GetRoofCoordSystem(pt)
	local p1, p2, p3 = point(ox, oy, oz),
		point(ox + rx*rs, oy + ry*rs, oz + rz*rs),
		point(ox + fx*fs, oy + fy*fs, oz + fz*fs)
	return PlaneFromPoints(p1, p2, p3)
end

local eastPt, southPt, westPt, northPt = point(4096,0,0), point(0,4096,0), point(-4096,0,0), point(0,-4096,0)
---
--- Gets the roof Z coordinate and direction at the given point.
---
--- This function calculates the Z coordinate of the roof at the given point, as well as the direction of the roof. It uses the `GetRoofCoordSystem` function to retrieve the coordinate system parameters for the roof, and then calculates the Z coordinate using the `CalcRoofZAt` function. It also determines the cardinal direction of the roof based on the forward vector.
---
--- @param self RoomRoof The RoomRoof instance.
--- @param pt point The point to get the roof Z and direction for.
--- @return number, number The Z coordinate of the roof and the cardinal direction of the roof.
---
function RoomRoof:GetRoofZAndDir(pt)
	if not self:HasRoof() then
		return InvalidPos():z(), 0
	end
	
	local ox,oy,oz, fx,fy,fz,fs, rx,ry,rz,rs = self:GetRoofCoordSystem(pt)
	local z = CalcRoofZAt(ox,oy,oz, fx,fy,fz, rx,ry,rz, pt:xy())
	
	local dir = cardinal_directions[self.roof_direction]
	if not dir then
		--non-standard roof direction
		--estimate using dot products
		local fwd = point(fx, fy, fz)
		local dots = { Dot(fwd, eastPt), Dot(fwd, southPt), Dot(fwd, westPt), Dot(fwd, northPt) }
		local max = Max(table.unpack(dots))
		local idx = table.find(dots, max)
		dir = cardinal_directions[idx]
	end
	
	return z, dir
end

---- roof creation

--- Updates the visibility of the roof slab.
---
--- This function is responsible for computing the visibility of the roof slab. It checks if the `roof_box` property is set and if the game object has the `const.gofPermanent` flag set. If both conditions are true, it calls the `ComputeSlabVisibilityInBox` function to compute the visibility of the slab within the `roof_box`.
---
--- @param self RoomRoof The RoomRoof instance.
function RoomRoof:UpdateRoofSlabVisibility()
	if self.roof_box and self:GetGameFlags(const.gofPermanent) ~= 0 then
		--DbgAddBox(self.roof_box)
		ComputeSlabVisibilityInBox(self.roof_box)
	end
end

-- +--+
-- |  |
---
--- Gets the parameters for a flat roof.
---
--- This function calculates the parameters for a flat roof based on the position and size of the game object. It converts the position to voxel coordinates and creates a voxel box that represents the size of the roof.
---
--- @param self RoomRoof The RoomRoof instance.
--- @return number, number, number, number, number, number, box The x, y, z coordinates of the roof, the x, y, z size of the roof, and the voxel box representing the roof.
---
function RoomRoof:GetFlatRoofParams()
	local px, py, pz = WorldToVoxel(self.position)
	local sx, sy, sz = self.size:xyz()
	local voxel_box = box(px, py, pz, px + sx, py + sy, pz + sz)
	
	return
		px, py, pz,
		sx, sy, sz,
		voxel_box
end

--- Gets the coordinate system for a flat roof.
---
--- This function calculates the coordinate system for a flat roof based on the position, size, and orientation of the game object. It uses the `GetFlatRoofParams` function to get the parameters of the flat roof, and then calls the `SolveRoofCoordSystem` function to compute the coordinate system.
---
--- @param self RoomRoof The RoomRoof instance.
--- @param pt table The point to transform into the roof coordinate system.
--- @return table The point transformed into the roof coordinate system.
function RoomRoof:GetFlatRoofCoordSystem(pt)
	local
		px, py, pz,
		sx, sy, sz,
		voxel_box = self:GetFlatRoofParams()
	return SolveRoofCoordSystem(voxel_box, self.roof_additional_height, self.roof_direction, self:GetRoofInclination())
end

--- Creates a flat roof.
---
--- This function calculates the parameters for a flat roof based on the position and size of the game object, and then calls the `CreateRoof` function to create the roof.
---
--- @param self RoomRoof The RoomRoof instance.
--- @return table The created roof.
function RoomRoof:CreateFlatRoof()
	local
		px, py, pz,
		sx, sy, sz,
		voxel_box = self:GetFlatRoofParams()
	return self:CreateRoof("Flat", voxel_box, self.roof_direction, self.roof_parapet)
end

--- Recalculates the parameters for a flat roof.
---
--- This function recalculates the parameters for a flat roof based on the position and size of the game object. It calls the `GetFlatRoofParams` function to get the parameters of the flat roof, and then calls the `RecalcRoof_Generic` function to recalculate the roof box.
---
--- @param self RoomRoof The RoomRoof instance.
function RoomRoof:RecalcFlatRoof()
	local
		px, py, pz,
		sx, sy, sz,
		voxel_box = self:GetFlatRoofParams()
	self.roof_box = self:RecalcRoof_Generic("Flat", voxel_box, self.roof_direction, self.roof_parapet)
end

--  /|
-- / |
--- Gets the parameters for a shed roof.
---
--- This function calculates the parameters for a shed roof based on the position and size of the game object. It uses the `WorldToVoxel` function to convert the position to voxel coordinates, and then creates a voxel box that represents the size of the shed roof.
---
--- @param self RoomRoof The RoomRoof instance.
--- @return number, number, number, number, number, number, table The position (x, y, z), size (x, y, z), and voxel box of the shed roof.
function RoomRoof:GetShedRoofParams()
	local px, py, pz = WorldToVoxel(self.position)
	local sx, sy, sz = self.size:xyz()
	local voxel_box = box(px, py, pz, px + sx, py + sy, pz + sz)
	
	return
		px, py, pz,
		sx, sy, sz,
		voxel_box
end

--- Gets the coordinate system for a shed roof.
---
--- This function calculates the coordinate system for a shed roof based on the position, size, and other parameters of the RoomRoof instance. It calls the `SolveRoofCoordSystem` function to get the coordinate system for the shed roof.
---
--- @param self RoomRoof The RoomRoof instance.
--- @param pt table The point to transform into the shed roof coordinate system.
--- @return table The transformed point in the shed roof coordinate system.
function RoomRoof:GetShedRoofCoordSystem(pt)
	local
		px, py, pz,
		sx, sy, sz,
		voxel_box = self:GetShedRoofParams()
	return SolveRoofCoordSystem(voxel_box, self.roof_additional_height, self.roof_direction, self:GetRoofInclination())
end

--- Creates a shed roof for the RoomRoof instance.
---
--- This function calculates the parameters for a shed roof based on the position and size of the game object, and then calls the `CreateRoof` function to create the shed roof.
---
--- @param self RoomRoof The RoomRoof instance.
--- @return table The created roof.
function RoomRoof:CreateShedRoof()
	local
		px, py, pz,
		sx, sy, sz,
		voxel_box = self:GetShedRoofParams()
	return self:CreateRoof("Shed", voxel_box, self.roof_direction, self.roof_parapet)
end

--- Recalculates the parameters for a shed roof.
---
--- This function calculates the parameters for a shed roof based on the position and size of the game object, and then calls the `RecalcRoof_Generic` function to recalculate the roof.
---
--- @param self RoomRoof The RoomRoof instance.
function RoomRoof:RecalcShedRoof()
	local
		px, py, pz,
		sx, sy, sz,
		voxel_box = self:GetShedRoofParams()
	self.roof_box = self:RecalcRoof_Generic("Shed", voxel_box, self.roof_direction, self.roof_parapet)
end

--  /\
-- /  \
--- Gets the boxes and directions for a gable roof.
---
--- This function calculates the boxes and directions for a gable roof based on the position and size of the RoomRoof instance. It returns the two boxes that make up the gable roof, the directions for each box, and a flag indicating if the roof is odd (has an extra voxel in the middle).
---
--- @param self RoomRoof The RoomRoof instance.
--- @return string, string, table, table, boolean The first direction, the second direction, the first box, the second box, and a flag indicating if the roof is odd.
function RoomRoof:GetGableRoofBoxes()
	local px, py, pz = WorldToVoxel(self.position)
	local sx, sy, sz = self.size:xyz()
	
	local dir1, dir2
	local box1, box2
	local odd
	
	if self.roof_direction == "East-West" or self.roof_direction == "East" or self.roof_direction == "West" then
		dir1 = "South"
		dir2 = "North"
		box1 = box(px, py,        pz, px + sx, py + sy/2, pz + sz)
		box2 = box(px, py + sy/2, pz, px + sx, py + sy,   pz + sz)
		odd = (sy % 2) == 1
		if odd then
			box1 = box1:grow(0, 0, 0, 1)
		end
	else -- North-South
		dir1 = "East"
		dir2 = "West"
		box1 = box(px,        py, pz, px + sx/2, py + sy, pz + sz)
		box2 = box(px + sx/2, py, pz, px + sx,   py + sy, pz + sz)
		odd = (sx % 2) == 1
		if odd then
			box1 = box1:grow(0, 0, 1, 0)
		end
	end
	
	return
		dir1, dir2,
		box1, box2,
		odd
end

---
--- Gets the coordinate system for a gable roof.
---
--- This function calculates the coordinate system for a gable roof based on the position and size of the RoomRoof instance. It returns the origin, forward, and right vectors for the coordinate system.
---
--- @param self RoomRoof The RoomRoof instance.
--- @param pt Vector3 The point to check for which box it is in.
--- @return number, number, number, number, number, number, number, number, number The origin x, y, z, forward x, y, z, size, right x, y, z, size.
---
function RoomRoof:GetGableRoofCoordSystem(pt)
	local dir1, dir2, box1, box2, odd = self:GetGableRoofBoxes()
	local bx, by, bz = box1:size():xyz()
	local sx, sy, sz = self.size:xyz()
	local dx, dy = 0, 0
	--when gable roof is odd, box1 and box2 are 1/2 voxel larger in the direction of inclination
	--in other words, the topmost voxel is shared by both boxes and there are two clipped tiles on top of each other
	--it is technically correct, however in that voxel we would always snap as if we are in box1, whereas we should
	--snap as if in box2 when in the second half of said voxel
	if bx < sx and bx * 2 > sx then
		--even x, the box should be half a voxel smaller on the x side
		dx = voxelSizeX / 2
	end
	if by < sy and by * 2 > sy then
		--even y
		dy = voxelSizeY / 2
	end
	
	local minx, miny, minz, maxx, maxy, maxz = BoxVoxelToWorld(box1)
	minx, miny, minz, maxx, maxy, maxz = minx - 1, miny - 1, minz - 1, maxx + 1 - dx, maxy + 1 - dy, maxz + 1
	local world_box1 = box(minx, miny, minz, maxx, maxy, maxz)
	local in_box1 = pt:InBox2D(world_box1)
	local box = in_box1 and box1 or box2
	local dir = in_box1 and dir1 or dir2
	
	return SolveRoofCoordSystem(box, self.roof_additional_height, dir, self:GetRoofInclination())
end

---
--- Creates a gable roof for the RoomRoof instance.
---
--- This function calculates the boxes and coordinate system for a gable roof based on the position and size of the RoomRoof instance. It then creates the roof geometry and returns the objects and the bounding box of the roof.
---
--- @param self RoomRoof The RoomRoof instance.
--- @return table, box The created roof objects and the bounding box of the roof.
---
function RoomRoof:CreateGableRoof()
	local dir1, dir2, box1, box2, odd = self:GetGableRoofBoxes()
	
	local objs1, box1 = self:CreateRoof("Gable", box1, dir1, self.roof_parapet, odd and "odd_gable_short")
	local objs2, box2 = self:CreateRoof("Gable", box2, dir2, self.roof_parapet, odd and "odd_gable_long")
	
	local px, py, pz = WorldToVoxel(self.position)
	local sx, sy, sz = self.size:xyz()
	local full_box = box(px, py, pz, px + sx, py + sy, pz + sz) --in voxels
	local objs3 = self:CreateRoof_GableCaps(full_box, dir1, self.roof_parapet)
	
	local objs = { }
	table.iappend(objs, objs1 or empty_table)
	table.iappend(objs, objs2 or empty_table)
	table.iappend(objs, objs3 or empty_table)
	
	local box = AddRects(box1, box2)
	return objs, box
end

---
--- Recalculates the gable roof for the RoomRoof instance.
---
--- This function recalculates the boxes and coordinate system for a gable roof based on the position and size of the RoomRoof instance. It then updates the roof geometry and the bounding box of the roof.
---
--- @param self RoomRoof The RoomRoof instance.
---
function RoomRoof:RecalcGableRoof()
	local dir1, dir2, box1, box2, odd = self:GetGableRoofBoxes()
	
	local roof_box1 = self:RecalcRoof_Generic("Gable", box1, dir1, self.roof_parapet, odd and "odd_gable_short")
	local roof_box2 = self:RecalcRoof_Generic("Gable", box2, dir2, self.roof_parapet, odd and "odd_gable_long")
	self.roof_box = AddRects(roof_box1, roof_box2)
end

---- generic roof creation

---
--- Converts a voxel box from voxel coordinates to world coordinates.
---
--- @param voxel_box box The voxel box to convert.
--- @return number, number, number, number, number, number The minimum and maximum world coordinates of the voxel box.
---
function BoxVoxelToWorld(voxel_box)
	local minx, miny, minz, maxx, maxy, maxz = voxel_box:xyzxyz()
	
	minx, miny, minz = VoxelToWorld(minx, miny, minz)
	minx, miny, minz = minx - halfVoxelSizeX, miny - halfVoxelSizeY, minz
	
	maxx, maxy, maxz = VoxelToWorld(maxx, maxy, maxz)
	maxx, maxy, maxz = maxx - halfVoxelSizeX, maxy - halfVoxelSizeY, maxz
	
	return minx, miny, minz, maxx, maxy, maxz
end

--calculates vector for roof local coordinate system
---
--- Calculates the coordinate system for a roof based on the provided voxel box, z-offset, direction, and inclination.
---
--- @param voxel_box box The voxel box representing the roof.
--- @param z_offset number The z-offset to apply to the roof.
--- @param direction string The direction of the roof slope.
--- @param inclination number The inclination of the roof.
--- @return number, number, number, number, number, number, number, number, number, number The origin x, y, z, forward x, y, z, forward size, right x, y, z, and right size of the roof coordinate system.
---
function SolveRoofCoordSystem(voxel_box, z_offset, direction, inclination)
	local ox, oy, oz --origin x, y, z
	local fx, fy, fz, fs --forward x, y, z, size
	local rx, ry, rz, rs --right x, y, z, size
	
	--center (in 2D world space)
	local minx, miny, minz, maxx, maxy, maxz = BoxVoxelToWorld(voxel_box)
	local cx, cy, cz =
		(minx + maxx) / 2,
		(miny + maxy) / 2,
		maxz + z_offset
	
	--DbgAddBox(box(minx,miny,minz,maxx,maxy,maxz))
	
	local angle = cardinal_directions[direction] --roof slope direction
	local sin, cos = sincos(angle)
	sin, cos = sin / 4096, cos / 4096
	
	--rotate from world space to local space
	local function rotate_vector(x, y, z)
		return x * cos - y * sin, x * sin + y * cos, z
	end
	
	--forward/right sizes + inclination
	local inclination_size
	if direction == "North" or direction == "South" then
		rs, fs = voxel_box:sizexyz()
		inclination_size = const.SlabSizeX
	else
		fs, rs = voxel_box:sizexyz()
		inclination_size = const.SlabSizeY
	end
	
	--forward inclination per 1 voxel
	local incl_sin, incl_cos = sincos(inclination)
	local incl_tan = MulDivRound(incl_sin, 4096, incl_cos)
	local voxel_incline = MulDivRound(inclination_size, incl_tan, 4096)
	
	--forward/right vectors
	local fx, fy, fz = rotate_vector(const.SlabSizeX, 0, voxel_incline)
	local rx, ry, rz = rotate_vector(0, const.SlabSizeY, 0)
	
	--origin
	ox, oy, oz = 
		cx - MulDivRound(fs, fx, 2) - MulDivRound(rs, rx, 2),
		cy - MulDivRound(fs, fy, 2) - MulDivRound(rs, ry, 2),
		cz
	
	--DbgAddVector(point(ox, oy, oz), point(0, 0, const.SlabSizeZ), const.clrGreen)
	--DbgAddVector(point(ox, oy, oz), point(fx, fy, fz), const.clrBlue)
	--DbgAddVector(point(ox, oy, oz), point(rx, ry, rz), const.clrRed)
	
	return
		ox, oy, oz, --origin x, y, z
		fx, fy, fz, fs, --forward x, y, z, size
		rx, ry, rz, rs --right x, y, z, size
end

local function RoofCoordSystemBBox(ox,oy,oz, fx,fy,fz,fs, rx,ry,rz,rs, additional_height)
	local minx, miny, minz =
		ox,
		oy,
		oz - additional_height
		
	local maxx, maxy, maxz =
		ox + fs*fx + rs*rx + 1,
		oy + fs*fy + rs*ry + 1,
		oz + fs*fz + rs*rz + 1
	
	minx, maxx = Min(minx, maxx), Max(minx, maxx)
	miny, maxy = Min(miny, maxy), Max(miny, maxy)
	minz, maxz = Min(minz, maxz), Max(minz, maxz)
	
	return box(
		minx, miny, minz,
		maxx, maxy, maxz)
end

--calculates position (x, y, z) of roof corner
local function SolveRoofCornerPosition(ox,oy,oz, fx,fy,fz,fs, rx,ry,rz,rs, side)
	if side == "Front" then
		return
			ox + fx*fs,
			oy + fy*fs,
			oz + fz*fs
	elseif side == "Right" then
		return
			ox + fx*fs + rx*rs,
			oy + fy*fs + ry*rs,
			oz + fz*fs + rz*rs
	elseif side == "Back" then
		return
			ox + rx*rs,
			oy + ry*rs,
			oz + rz*rs
	elseif side == "Left" then
		return ox, oy, oz
	else
		assert(false, "Invalid side of roof corner")
		return ox, oy, oz
	end
end

--calculates vectors for roof edge coordinate system
local function SolveRoofEdgeCoordSystem(ox,oy,oz, fx,fy,fz,fs, rx,ry,rz,rs, side)
	local front_or_back = (side == "Front" or side == "Back")
	
	local dx, dy, dz --delta
	if front_or_back then
		dx, dy, dz = rx, ry, rz
	else
		dx, dy, dz = fx, fy, fz
	end
	
	local ds = front_or_back and rs or fs --delta size
	
	--base x, y, z
	local bx, by, bz
	if side == "Left" then
		bx, by, bz = ox, oy, oz
	elseif side == "Front" then
		bx, by, bz = ox + fx*fs, oy + fy*fs, oz + fz*fs
	elseif side == "Right" then
		bx, by, bz = ox + rx*rs, oy + ry*rs, oz + rz*rs
	elseif side == "Back" then
		bx, by, bz = ox, oy, oz
	end
	
	return
		bx, by, bz, --base x, y, z
		dx, dy, dz, ds --delta x, y, z, size
end

local function GetGableClipPlane(ox,oy,oz, fx,fy,fz,fs, rx,ry,rz,rs)
	local p1, p2 =
	    point(ox + (fs-1)*fx + fx/2,
	          oy + (fs-1)*fy + fy/2,
	          oz + (fs-1)*fz + fz/2),
	    point(ox + (fs-1)*fx + rs*rx + fx/2,
	          oy + (fs-1)*fy + rs*ry + fy/2,
	          oz + (fs-1)*fz + rs*rz + fz/2)
	local p3 = p2:AddZ(const.SlabSizeZ)
	--DbgAddPoly({p1, p2, p3, p1:AddZ(const.SlabSizeZ)})
	return PlaneFromPoints(p1, p3, p2)
end

---
--- Calculates the Z coordinate of a point on a roof surface given the origin and direction vectors.
---
--- @param ox number The X coordinate of the roof origin.
--- @param oy number The Y coordinate of the roof origin.
--- @param oz number The Z coordinate of the roof origin.
--- @param fx number The X component of the forward direction vector.
--- @param fy number The Y component of the forward direction vector.
--- @param fz number The Z component of the forward direction vector.
--- @param rx number The X component of the right direction vector.
--- @param ry number The Y component of the right direction vector.
--- @param rz number The Z component of the right direction vector.
--- @param px number The X coordinate of the point on the roof.
--- @param py number The Y coordinate of the point on the roof.
--- @return number The Z coordinate of the point on the roof.
---
function CalcRoofZAt(ox,oy,oz, fx,fy,fz, rx,ry,rz, px,py)
	local ppx = MulDivRound(px - ox, guim, fx + rx)
	local ppy = MulDivRound(py - oy, guim, fy + ry)
	
	if abs(fx) > abs(fy) then
		return (ppx*fz + ppy*rz) / guim + oz
	else
		return (ppx*rz + ppy*fz) / guim + oz
	end
end

local function SideNames(direction)
	local first_dir_i = table.find(cardinal_direction_names, direction)
	local sides = { }
	for i=1,4 do
		local dir_i = (((first_dir_i - 1) + (i - 1)) % 4) + 1
		sides[i] = cardinal_direction_names[dir_i]
	end
	local side_front, side_right, side_back, side_left = table.unpack(sides)
	return side_front, side_right, side_back, side_left
end

local side_to_i = {
	["Front"] = 0,
	["Right"] = 1,
	["Back"] = 2,
	["Left"] = 3,
}

---
--- Creates a new slab object of the specified class with the given parameters.
---
--- @param slab_class string The class name of the slab to create.
--- @param params table A table of parameters to pass to the slab constructor.
--- @return table The new slab object.
---
function RoomRoof:CreateSlab(slab_class, params)
	local slab_classdef = g_Classes[slab_class]
	return slab_classdef:new(params)
end

---
--- Creates roof plane slabs for the specified roof parameters.
---
--- @param objs table A table to store the created slab objects.
--- @param ox number The X coordinate of the roof origin.
--- @param oy number The Y coordinate of the roof origin.
--- @param oz number The Z coordinate of the roof origin.
--- @param fx number The X component of the forward direction vector.
--- @param fy number The Y component of the forward direction vector.
--- @param fz number The Z component of the forward direction vector.
--- @param fs number The number of slabs in the forward direction.
--- @param rx number The X component of the right direction vector.
--- @param ry number The Y component of the right direction vector.
--- @param rz number The Z component of the right direction vector.
--- @param rs number The number of slabs in the right direction.
--- @param direction string The cardinal direction of the roof.
--- @param special string A special case identifier for the roof, such as "odd_gable_long" or "odd_gable_short".
---
function RoomRoof:CreateRoofComponents_RoofPlane(objs, ox,oy,oz, fx,fy,fz,fs, rx,ry,rz,rs, direction, special)
	--determine roof skew
	local skew_x, skew_y = MulDivRound(-fz, guim, abs(fx + rx)), 0
	
	--determine angle
	local angle = cardinal_directions[direction] + 180*60
	
	--handle odd length gable roof top slabs
	local clip_plane
	local odd_gable = (special == "odd_gable_long") or (special == "odd_gable_short")
	if odd_gable then
		clip_plane = GetGableClipPlane(ox,oy,oz, fx,fy,fz,fs, rx,ry,rz,rs)
	end
	local is_flat = self:GetRoofType() == "Flat"
	
	for fi=1,fs do
		local gable_clip = odd_gable and (fi == fs)
		
		for ri=1,rs do
			local x = ox + (fi-1)*fx + (ri-1)*rx + (fx+rx)/2
			local y = oy + (fi-1)*fy + (ri-1)*ry + (fy+ry)/2
			local z = oz + (fi-1)*fz + (ri-1)*rz + (fz+rz)/2
			--DbgAddVector(point(x, y, z), point(0, 0, const.SlabSizeZ), const.clrBlue)
			
			local slab = self:CreateSlab("RoofPlaneSlab", {
				floor = self.floor,
				room = self,
				dir = direction,
				material = self.roof_mat,
			})
			
			self:SetupNewObj(slab, x, y, z, angle, self.roof_colors, nil, objs, gable_clip and clip_plane or nil, nil, skew_x, skew_y)
			self:PostProcessPlaneSlab(slab, is_flat)
		end
	end
end

RoomRoof.ShouldPlaceRoofEdge = return_true
---
--- Creates the roof edge components for a room roof.
---
--- @param objs table A table to store the created objects in.
--- @param ox number The X coordinate of the roof origin.
--- @param oy number The Y coordinate of the roof origin.
--- @param oz number The Z coordinate of the roof origin.
--- @param fx number The X component of the forward direction vector.
--- @param fy number The Y component of the forward direction vector.
--- @param fz number The Z component of the forward direction vector.
--- @param fs number The number of slabs in the forward direction.
--- @param rx number The X component of the right direction vector.
--- @param ry number The Y component of the right direction vector.
--- @param rz number The Z component of the right direction vector.
--- @param rs number The number of slabs in the right direction.
--- @param direction string The cardinal direction of the roof.
--- @param side string The side of the roof (Front, Back, Left, Right).
--- @param special string A special case identifier for the roof, such as "odd_gable_long" or "odd_gable_short".
---
function RoomRoof:CreateRoofComponents_RoofEdge(objs, ox,oy,oz, fx,fy,fz,fs, rx,ry,rz,rs, direction, side, special)
	if not self:ShouldPlaceRoofEdge(direction, side) then return end
	
	local front_or_back = (side == "Front" or side == "Back")
	
	--determine entity
	local edge_type = (side == "Front" and "Ridge") or (side == "Back" and "Eave") or "Rake"
	
	--local coord system
	local bx, by, bz,
		dx, dy, dz, ds = SolveRoofEdgeCoordSystem(ox,oy,oz, fx,fy,fz,fs, rx,ry,rz,rs, side)
	--adjust for voxel edges
	bx, by, bz = bx + dx/2, by + dy/2, bz + dz/2
	
	--determine how the edge will be skewed
	local skew_x, skew_y
	if side == "Front" then
		skew_x, skew_y = MulDivRound(fz, guim, abs(fx + rx)), 0
	elseif side == "Back" then
		skew_x, skew_y = MulDivRound(-fz, guim, abs(fx + rx)), 0
	else
		skew_x, skew_y = 0, MulDivRound(fz, guim, abs(fy + ry))
	end
	
	--rakes (left and right side) are mirrored only on the right side
	local mirror = (side == "Right")
	
	--determine object angle
	local direction_i = table.find(cardinal_direction_names, direction)
	local direction_i = (((direction_i-1) + side_to_i[side]) % 4) + 1
	local angle = cardinal_directions[direction_i]
	
	--handle odd length gable roof top slabs
	local clip_plane
	local odd_gable = (special == "odd_gable_long") or (special == "odd_gable_short")
	if odd_gable then
		clip_plane = GetGableClipPlane(ox,oy,oz, fx,fy,fz,fs, rx,ry,rz,rs)
	end

	for di=1,ds do
		local x = bx + (di-1)*dx
		local y = by + (di-1)*dy
		local z = bz + (di-1)*dz
		--DbgAddVector(point(x, y, z), point(0, 0, const.SlabSizeZ), const.clrMagenta)
		
		local slab = self:CreateSlab("RoofEdgeSlab", {
			floor = self.floor,
			room = self,
			dir = direction,
			roof_comp = edge_type,
			material = self.roof_mat,
		})
		
		self:SetupNewObj(slab, x, y, z, angle, self.roof_colors, nil, objs, odd_gable and di == ds and clip_plane or nil, mirror, skew_x, skew_y)
	end
end

RoomRoof.ShouldCreateRoofCorner = return_true
---
--- Creates a roof corner component.
---
--- @param objs table A table to store the created objects in.
--- @param ox number The x-coordinate of the origin.
--- @param oy number The y-coordinate of the origin.
--- @param oz number The z-coordinate of the origin.
--- @param fx number The x-coordinate of the front point.
--- @param fy number The y-coordinate of the front point.
--- @param fz number The z-coordinate of the front point.
--- @param fs number The scale of the front point.
--- @param rx number The x-coordinate of the right point.
--- @param ry number The y-coordinate of the right point.
--- @param rz number The z-coordinate of the right point.
--- @param rs number The scale of the right point.
--- @param direction string The direction of the roof.
--- @param side string The side of the roof.
function RoomRoof:CreateRoofComponents_RoofCorner(objs, ox, oy, oz, fx, fy, fz, fs, rx, ry, rz, rs, direction, side)
end
function RoomRoof:CreateRoofComponents_RoofCorner(objs, ox,oy,oz, fx,fy,fz,fs, rx,ry,rz,rs, direction, side)
	if not self:ShouldCreateRoofCorner(direction, side) then return end
	
	local mirror, angle
	local x, y, z
	
	--determine angle
	angle = cardinal_directions[direction]		
	if side == "Left" or side == "Back" then
		angle = cardinal_directions[direction] + 180*60
	end
	
	--determine if component should be mirrored
	local mirror = (side == "Front" or side == "Back")
	
	--determine position
	local x, y, z = SolveRoofCornerPosition(ox,oy,oz, fx,fy,fz,fs, rx,ry,rz,rs, side)
	
	--determine entity
	local corner_type = (side == "Front" or side == "Right") and "RakeRidge" or "RakeEave"
	
	--determine skew
	local skew = (side == "Front" or side == "Right") and fz or -fz
	local skew_x, skew_y = MulDivRound(skew, guim, abs(fx + rx)), 0
	
	--DbgAddVector(point(x, y, z), point(0, 0, const.SlabSizeZ), const.clrOrange)
	
	local slab = self:CreateSlab("RoofCorner", {
		floor = self.floor,
		room = self,
		dir = direction,
		roof_comp = corner_type,
		material = self.roof_mat,
	})
	
	self:SetupNewObj(slab, x, y, z, angle, self.roof_colors, nil, objs, nil, mirror, skew_x, skew_y)
end

RoomRoof.ShouldCreateRoofWallEdge = return_true
--- Creates the wall edge components for a room roof.
---
--- @param objs table A table to store the created objects.
--- @param ox number The x-coordinate of the origin point.
--- @param oy number The y-coordinate of the origin point.
--- @param oz number The z-coordinate of the origin point.
--- @param fx number The x-coordinate of the front point.
--- @param fy number The y-coordinate of the front point.
--- @param fz number The z-coordinate of the front point.
--- @param fs number The scale of the front point.
--- @param rx number The x-coordinate of the right point.
--- @param ry number The y-coordinate of the right point.
--- @param rz number The z-coordinate of the right point.
--- @param rs number The scale of the right point.
--- @param direction string The direction of the roof.
--- @param side string The side of the roof.
--- @param clip_plane boolean Whether to use a clip plane.
--- @param special string A special case for gable roofs with odd lengths.
function RoomRoof:CreateRoofComponents_WallEdge(objs, ox, oy, oz, fx, fy, fz, fs, rx, ry, rz, rs, direction, side, clip_plane, special)
end
function RoomRoof:CreateRoofComponents_WallEdge(objs, ox,oy,oz, fx,fy,fz,fs, rx,ry,rz,rs, direction, side, clip_plane, special)
	if not self:ShouldCreateRoofWallEdge(direction, side) then return end
	
	--local coord system
	local bx, by, bz,
		dx, dy, dz, ds = SolveRoofEdgeCoordSystem(ox,oy,oz, fx,fy,fz,fs, rx,ry,rz,rs, side)
	--adjust for walls & voxel edges
	dz = 0
	bx, by = bx + dx/2, by + dy/2
	bz = oz - self.roof_additional_height

	--determine object angle	
	local front_or_back = (side == "Front" or side == "Back")
	local dir_i = table.find(cardinal_direction_names, direction)
	local side_i = side_to_i[side]
	local wall_side = cardinal_direction_names[(((dir_i-1) + side_i) % 4) + 1]
	local angle = cardinal_directions[wall_side]
	local oc = self.outer_colors
	local ic = self.inner_colors
	local dbg_outwards_vec = (side == "Left" or side == "Front") and point(dy, -dx, dz) or point(-dy, dx, dz)
	dbg_outwards_vec = SetLen(dbg_outwards_vec, guim)
	
	--handle middle column of gable roofs with odd length
	local odd_gable_long_half = (special == "odd_gable_long")
	local odd_gable_short_half = (special == "odd_gable_short")
	local odd_gable = odd_gable_long_half or odd_gable_short_half
	local max_height = max_int
	if odd_gable and not front_or_back then
		local size = ds
		if odd_gable_short_half then size = size + 1 end
		local x, y = (bx + (size-1)*dx), (by + (size-1)*dy)
		
		local roof_z1, roof_z2 =
			CalcRoofZAt(ox,oy,oz, fx,fy,fz, rx,ry,rz, x + dx/2, y + dy/2),
			CalcRoofZAt(ox,oy,oz, fx,fy,fz, rx,ry,rz, x - dx/2, y - dy/2)
		
		local min_roof_z = Min(roof_z1, roof_z2) - bz
		max_height = min_roof_z / const.SlabSizeZ
	end
	
	local is_flat = self:GetRoofType() == "Flat"
	
	for di=1,ds do
		local x = bx + (di-1)*dx
		local y = by + (di-1)*dy
		
		--determine wall column height
		--note: when creating parapet this fn is called without clipping plane
		local roof_z
		if clip_plane then
			local roof_z1, roof_z2 =
				CalcRoofZAt(ox,oy,oz, fx,fy,fz, rx,ry,rz, x + dx/2, y + dy/2),
				CalcRoofZAt(ox,oy,oz, fx,fy,fz, rx,ry,rz, x - dx/2, y - dy/2)
			--DbgAddVector(point(x + dx/2, y + dy/2, roof_z1), dbg_outwards_vec, const.clrRed)
			--DbgAddVector(point(x - dx/2, y - dy/2, roof_z2), dbg_outwards_vec, const.clrRed)
			roof_z = Max(roof_z1, roof_z2) - bz
		else
			roof_z = Max(fz*fs, const.SlabSizeZ) + self.roof_additional_height
		end
		
		local height = DivCeil(roof_z, const.SlabSizeZ)
		height = Min(height, max_height)
		local mat = self:GetWallMatHelperSide(wall_side)
		
		for j=1,height do
			local z = bz + (di-1)*dz + (j-1)*const.SlabSizeZ
			--DbgAddVector(point(x, y, z), dbg_outwards_vec, const.clrYellow)
			
			local variant = self.inner_wall_mat ~= noneWallMat and "OutdoorIndoor" or "Outdoor"
			local wall = self:CreateSlab("RoofWallSlab", { --left
				floor = self.floor,
				material = mat,
				room = self,
				side = wall_side,
				variant = variant,
				indoor_material_1 = self.inner_wall_mat,
			})
			
			self:SetupNewObj(wall, x, y, z, angle, oc, ic, objs, clip_plane)
		end
		
		if not clip_plane and self.roof_parapet and is_flat then
			--only for flat parapet roofs
			local extra_dec_e = "WallDec_material_FenceTop_Body_01"
			extra_dec_e = extra_dec_e:gsub("material", mat)
			if IsValidEntity(extra_dec_e) then
				--ent exists
				local z = bz + (di-1)*dz + (height-1)*const.SlabSizeZ
				local o = PlaceObject(extra_dec_e, {side = wall_side})
				o:SetGameFlags(const.gofPermanent)
				self:SetupNewObj(o, x, y, z, angle, oc or o:GetDefaultColorizationSet(), ic, objs, clip_plane)
			end
		end
	end
	
	--now place the half of middle column of gable roofs with odd length
	
	if odd_gable and not front_or_back then
		local size = ds
		if odd_gable_long_half then size = size - 1 end

		local di_from = (fz > 0) and ((max_height*const.SlabSizeZ - self.roof_additional_height)/fz) or 0
		for di=di_from,size do
			local x = bx + (di-1)*dx + dx/2
			local y = by + (di-1)*dy + dy/2
			
			--determine wall column height
			--note: when creating parapet this fn is called without clipping plane
			local roof_z
			if clip_plane then
				local roof_z1, roof_z2 =
					CalcRoofZAt(ox,oy,oz, fx,fy,fz, rx,ry,rz, x + dx/2, y + dy/2),
					CalcRoofZAt(ox,oy,oz, fx,fy,fz, rx,ry,rz, x - dx/2, y - dy/2)
				--DbgAddVector(point(x + dx/2, y + dy/2, roof_z1), dbg_outwards_vec, const.clrRed)
				--DbgAddVector(point(x - dx/2, y - dy/2, roof_z2), dbg_outwards_vec, const.clrRed)
				roof_z = Max(roof_z1, roof_z2) - bz
			else
				roof_z = Max(fz*fs, const.SlabSizeZ) + self.roof_additional_height
			end
			
			local height = DivCeil(roof_z, const.SlabSizeZ)
		
			for i=max_height+1,height do
				local z = bz + (size-1)*dz + (i-1)*const.SlabSizeZ
				--DbgAddVector(point(x, y, z), dbg_outwards_vec, const.clrYellow)
				
				local mat = self:GetWallMatHelperSide(wall_side)
				local variant = self.inner_wall_mat ~= noneWallMat and "OutdoorIndoor" or "Outdoor"
				local wall = self:CreateSlab("GableRoofWallSlab", { --left
					floor = self.floor,
					material = mat,
					room = self,
					side = wall_side,
					variant = variant,
					indoor_material_1 = self.inner_wall_mat,
				})
				
				self:SetupNewObj(wall, x, y, z, angle, oc, ic, objs, clip_plane)
			end
		end
	end
end

---
--- Sets up a new object in the scene with the given properties.
---
--- @param obj table The object to set up.
--- @param x number The x-coordinate of the object's position.
--- @param y number The y-coordinate of the object's position.
--- @param z number The z-coordinate of the object's position.
--- @param a number The angle of the object's rotation.
--- @param colors table The colors to apply to the object.
--- @param inner_colors table The interior colors to apply to the object.
--- @param container table The container to add the object to.
--- @param clip_plane table The clip plane to apply to the object.
--- @param mirror boolean Whether to mirror the object.
--- @param skew_x number The x-coordinate of the object's skew.
--- @param skew_y number The y-coordinate of the object's skew.
---
function RoomRoof:SetupNewObj(obj, x, y, z, a, colors, inner_colors, container, clip_plane, mirror, skew_x, skew_y)
	obj:SetPosAngle(x, y, z, a)
	obj:AlignObj()
	if colors then
		obj:Setcolors(colors)
	end
	if inner_colors then
		obj:Setinterior_attach_colors(inner_colors)
	end
	if clip_plane then
		obj:SetClipPlane(clip_plane)
	end
	obj:UpdateEntity()
	obj:UpdateVariantEntities()
	
	obj:SetMirrored(mirror or false)
	if skew_x and skew_y then
		obj:SetSkew(skew_x, skew_y)
	end
	self:ApplyPropsFromPropObj(obj)
	if container then
		table.insert(container, obj)
	end
	if not visibilityStateForNewRoofPieces then
		obj:SetHierarchyGameFlags(const.gofSolidShadow)
		obj:SetOpacity(0)
	end
end

---
--- Creates the wall corner components for the roof.
---
--- @param objs table The table to add the created objects to.
--- @param ox number The x-coordinate of the origin.
--- @param oy number The y-coordinate of the origin.
--- @param oz number The z-coordinate of the origin.
--- @param fx number The x-coordinate of the forward vector.
--- @param fy number The y-coordinate of the forward vector.
--- @param fz number The z-coordinate of the forward vector.
--- @param fs number The scale of the forward vector.
--- @param rx number The x-coordinate of the right vector.
--- @param ry number The y-coordinate of the right vector.
--- @param rz number The z-coordinate of the right vector.
--- @param rs number The scale of the right vector.
--- @param direction string The direction of the wall.
--- @param side string The side of the wall ("Front", "Right", "Back", "Left").
--- @param clip_plane table The clip plane to apply to the objects.
--- @param has_plug boolean Whether to create a plug object.
---
function RoomRoof:CreateRoofComponents_WallCorner(objs, ox,oy,oz, fx,fy,fz,fs, rx,ry,rz,rs, direction, side, clip_plane, has_plug)
	--determine angle
	local angle = cardinal_directions[direction]		
	if side == "Left" or side == "Back" then
		angle = cardinal_directions[direction] + 180*60
	end
	
	--determine position
	local bx, by = SolveRoofCornerPosition(ox,oy,oz, fx,fy,fz,fs, rx,ry,rz,rs, side)
	local bz = oz - self.roof_additional_height
	
	--determine skew
	local skew = (side == "Front" or side == "Right") and fz or -fz
	local skew_x, skew_y = MulDivRound(skew, guim, abs(fx + rx)), 0
	
	--determine corner column height
	--note: when creating parapet this fn is called without clipping plane
	local roof_z
	if clip_plane then
		roof_z = CalcRoofZAt(ox,oy,oz, fx,fy,fz, rx,ry,rz, bx, by) - bz
	else
		roof_z = Max(fz*fs, const.SlabSizeZ)+ self.roof_additional_height
	end
	local height = DivCeil(roof_z, const.SlabSizeZ)
	
	local dir_i = table.find(cardinal_direction_names, direction)
	local side_i = side_to_i[side]
	local corner_side = cardinal_direction_names[(((dir_i-1) + side_i) % 4) + 1]
	local mat = self:GetWallMatHelperSide(corner_side)
	
	for i=1,height do
		local z = bz + (i-1)*const.SlabSizeZ
		
		--DbgAddVector(point(bx, by, z), point(0, 0, const.SlabSizeZ), const.clrYellow)
		
		local corner = self:CreateSlab("RoofCornerWallSlab", {
			room = self,
			material = mat,
			side = corner_side,
			isPlug = false,
			floor = self.floor,
		})
		
		self:SetupNewObj(corner, bx, by, z, angle, self.outer_colors, nil, objs, clip_plane)
	end
	
	if has_plug then
		local z = bz + (height-1)*const.SlabSizeZ
	
		local corner = self:CreateSlab("RoofCornerWallSlab", {
			room = self,
			material = mat,
			side = corner_side,
			isPlug = true,
			floor = self.floor,
		})
		
		self:SetupNewObj(corner, bx, by, z, angle, self.outer_colors, nil, objs, clip_plane)
	end
	
	local is_flat = self:GetRoofType() == "Flat"
	if not clip_plane and self.roof_parapet and is_flat then
		local extra_dec_e = "WallDec_material_FenceTop_Corner_01"
		extra_dec_e = extra_dec_e:gsub("material", mat)
		if IsValidEntity(extra_dec_e) then
			--ent exists
			local z = bz + (height-1)*const.SlabSizeZ
			local o = PlaceObject(extra_dec_e, {side = corner_side})
			o:SetGameFlags(const.gofPermanent)
			local a = cardinal_directions[corner_side] - 90 * 60 --corners probably self align, since angle is bogus
			self:SetupNewObj(o, bx, by, z, a, self.outer_colors or o:GetDefaultColorizationSet(), nil, objs, clip_plane)
		end
	end
end

local gable_cap_30_degree = -100
local gable_cap_max_adjustment = 120
---
--- Adjusts the Z coordinate of gable caps based on the roof inclination angle.
---
--- @param z number The initial Z coordinate of the gable cap.
--- @return number The adjusted Z coordinate of the gable cap.
function RoomRoof:AdjustGableCapZ(z)
	--adjust the caps depending on roof inclination angle
	local inclination = self:GetRoofInclination()
	inclination = 30*60 - Clamp(inclination, 0, 30*60)
	return (z + gable_cap_30_degree) + MulDivRound(inclination, gable_cap_max_adjustment, 30*60)
end

---
--- Creates gable caps for a roof.
---
--- @param voxel_box table The 2D box, in voxels, which the roof should cover.
--- @param direction string The roof direction ("East", "South", "West", "North").
--- @param parapet boolean Whether the roof should have a parapet.
--- @return table The created objects.
function RoomRoof:CreateRoof_GableCaps(voxel_box, direction, parapet)
	local objs = { }
	
	--local coordinate system (origin, forward, right)
	local ox, oy, oz,
	      fx, fy, fz, fs,
	      rx, ry, rz, rs = SolveRoofCoordSystem(voxel_box, self.roof_additional_height, direction, self:GetRoofInclination())
	
	--base x, y, z (where the caps begin)
	local bx, by, bz =
		ox + MulDivRound(fx, fs, 2),
		oy + MulDivRound(fy, fs, 2),
		oz + (fz*fs) / 2
	
	bz = self:AdjustGableCapZ(bz)
	
	--determine angle for componnets
	local angle = cardinal_directions[direction] + 180*60
	local angle_rake, angle_gable = angle + 90*60, angle
	
	--determine classes for the two types of components
	local class_rake, class_gable
	if (fs % 2) == 0 then
		class_rake, class_gable = "GableCapRoofCorner",   "GableCapRoofEdgeSlab"
	else
		class_rake, class_gable = "GableCapRoofEdgeSlab", "GableCapRoofPlaneSlab"
	end
	
	--create rake components
	if not parapet then
		--left rake
		local slab = self:CreateSlab(class_rake, {
			floor = self.floor,
			room = self,
			material = self.roof_mat,
			roof_comp = "RakeGable",
		})
		self:SetupNewObj(slab, bx, by, bz, angle_rake, self.roof_colors, nil, objs)
		--right rake
		local slab = self:CreateSlab(class_rake, {
			floor = self.floor,
			room = self,
			material = self.roof_mat,
			roof_comp = "RakeGable",
		})
		self:SetupNewObj(slab, bx + rx*rs, by + ry*rs, bz + rz*rs, angle_rake + 180*60, self.roof_colors, nil, objs, nil, true)
	end
	
	--adjust the base x, y, z for the gable components
	bx, by, bz = bx + rx/2, by + ry/2, bz + rz/2
	
	--create gable components
	for i=1,rs do
		local x, y, z =
			bx + (i-1)*rx,
			by + (i-1)*ry,
			bz + (i-1)*rz
		
		--DbgAddVector(point(x, y, z), point(0, 0, const.SlabSizeZ), const.clrCyan)
		
		local slab = self:CreateSlab(class_gable, {
			floor = self.floor,
			room = self,
			material = self.roof_mat,
			roof_comp = "Gable",
		})
		self:SetupNewObj(slab, x, y, z, angle_gable, self.roof_colors, nil, objs)
	end
	
	return objs
end

--[[@@@
Create a roof plane. Can be called multiple times to create a more complex roof.
@function objects RoomRoof@CreateRoof(box voxel_box, string direction, bool parapet, string special)
@param string roof_type - Type of roof ("Flat", "Shed", "Gable").
@param box voxel_box - 2D box, in voxels, which the roof should cover.
@param string direction - Roof direction ("East", "South", "West", "North").
@param bool parapet - If the roof should have a parapet.
@param string special - Special behaviour for some circumstances ("odd_gable_long", "odd_gable_short").
@result array objects - Created objects.
]]
---
--- Recalculates the roof geometry for a generic roof type.
---
--- @param roof_type string The type of roof (e.g. "Flat", "Gable")
--- @param voxel_box table The voxel box defining the roof dimensions
--- @param direction string The cardinal direction the roof is facing (e.g. "North", "East")
--- @param parapet boolean Whether the roof has parapets
--- @param special string Any special roof configuration (e.g. "odd_gable_long", "odd_gable_short")
--- @return table, table The updated roof objects and the bounding box of the roof
function RoomRoof:CreateRoof(roof_type, voxel_box, direction, parapet, special)
	local objs = { }
	
	local odd_gable = (special == "odd_gable_long" or special == "odd_gable_short")
	local odd_gable_long_half = (special == "odd_gable_long")
	
	--local coordinate system (origin, forward, right)
	local inclination = self:GetRoofInclination()
	local ox, oy, oz,
	      fx, fy, fz, fs,
	      rx, ry, rz, rs = SolveRoofCoordSystem(voxel_box, self.roof_additional_height, direction, inclination)
		  
	--geometric plane
	local p1, p2, p3 =
		point(ox, oy, oz),
		point(ox + rx*rs, oy + ry*rs, oz + rz*rs),
		point(ox + fx*fs, oy + fy*fs, oz + fz*fs)
	local clip_plane = PlaneFromPoints(p1, p2, p3)
	
	--DbgAddVector(p1, p2 - p1, const.clrWhite)
	--DbgAddVector(p1, p3 - p1, const.clrWhite)
	--DbgAddVector(p3, p2 - p1, const.clrWhite)
	--DbgAddVector(p2, p3 - p1, const.clrWhite)
	
	--create flat inner roof planes
	self:CreateRoofComponents_RoofPlane(objs, ox,oy,oz, fx,fy,fz,fs, rx,ry,rz,rs, direction, special)
	
	--create roof edges
	if (roof_type ~= "Flat" or not parapet) and roof_type ~= "Gable" then
		self:CreateRoofComponents_RoofEdge(objs, ox,oy,oz, fx,fy,fz,fs, rx,ry,rz,rs, direction, "Front", special)
	end
	if not parapet then
		self:CreateRoofComponents_RoofEdge(objs, ox,oy,oz, fx,fy,fz,fs, rx,ry,rz,rs, direction, "Right", special)
	end
	if (roof_type ~= "Flat" or not parapet) then
		self:CreateRoofComponents_RoofEdge(objs, ox,oy,oz, fx,fy,fz,fs, rx,ry,rz,rs, direction, "Back", special)
	end
	if not parapet then
		self:CreateRoofComponents_RoofEdge(objs, ox,oy,oz, fx,fy,fz,fs, rx,ry,rz,rs, direction, "Left", special)
	end
	
	--create roof corners
	if not parapet then
		if roof_type ~= "Gable" then
			self:CreateRoofComponents_RoofCorner(objs, ox,oy,oz, fx,fy,fz,fs, rx,ry,rz,rs, direction, "Front")
			self:CreateRoofComponents_RoofCorner(objs, ox,oy,oz, fx,fy,fz,fs, rx,ry,rz,rs, direction, "Right")
		end
		
		self:CreateRoofComponents_RoofCorner(objs, ox,oy,oz, fx,fy,fz,fs, rx,ry,rz,rs, direction, "Back")
		self:CreateRoofComponents_RoofCorner(objs, ox,oy,oz, fx,fy,fz,fs, rx,ry,rz,rs, direction, "Left")
	end
	
	--prepare clipping planes for walls (fpn=front-(clipping)plane-normal;fpd=front-(clipping)plane-distance;...)
	local fp, rp, bp, lp = clip_plane, clip_plane, clip_plane, clip_plane
	if parapet then
		--when creating a parapets we don't provide clipping planes
		if roof_type == "Flat"	then
			--parapets on all sides
			fp, rp, bp, lp = false, false, false, false
		else
			--parapets on left and right sides only
			rp, lp = false, false
		end
	end
	
	local wfs = fs --side walls forward size (left and right walls)
	if odd_gable and not odd_gable_long_half then
		wfs = wfs - 1
	end
	
	--create walls
	if roof_type ~= "Gable" then
		self:CreateRoofComponents_WallEdge(objs, ox,oy,oz, fx,fy,fz,fs, rx,ry,rz,rs, direction, "Front", fp, special)
	end
	self:CreateRoofComponents_WallEdge(objs, ox,oy,oz, fx,fy,fz,wfs, rx,ry,rz,rs, direction, "Right", rp, special)
	self:CreateRoofComponents_WallEdge(objs, ox,oy,oz, fx,fy,fz,fs,  rx,ry,rz,rs, direction, "Back", bp, special)
	self:CreateRoofComponents_WallEdge(objs, ox,oy,oz, fx,fy,fz,wfs, rx,ry,rz,rs, direction, "Left", lp, special)
	
	--preapre clipping planes for wall corners (fcpn=front-corner-(clipping)plane-normal;...)
	--where there are two adjacent parapets - there is a corner without a clipping plane
	local fcp, rcp, bcp, lcp = clip_plane, clip_plane, clip_plane, clip_plane
	if not lp and not fp then fcp = false end
	if not fp and not rp then rcp = false end
	if not rp and not bp then bcp = false end
	if not bp and not lp then lcp = false end
	
	--prepare wall corner plugs/caps
	--if the corners aren't clipped, they should have a plug at the top
	local f_plug, r_plug, b_plug, l_plug = not fcp, not rcp, not bcp, not lcp
	
	--create wall corners
	if roof_type ~= "Gable" then
		self:CreateRoofComponents_WallCorner(objs, ox,oy,oz, fx,fy,fz,fs, rx,ry,rz,rs, direction, "Front", fcp, f_plug)
		self:CreateRoofComponents_WallCorner(objs, ox,oy,oz, fx,fy,fz,fs, rx,ry,rz,rs, direction, "Right", rcp, r_plug)
	end
	self:CreateRoofComponents_WallCorner(objs, ox,oy,oz, fx,fy,fz,fs, rx,ry,rz,rs, direction, "Back", bcp, b_plug)
	self:CreateRoofComponents_WallCorner(objs, ox,oy,oz, fx,fy,fz,fs, rx,ry,rz,rs, direction, "Left", lcp, l_plug)
	
	local roof_box = RoofCoordSystemBBox(ox,oy,oz, fx,fy,fz,fs, rx,ry,rz,rs, self.roof_additional_height)
	return objs, roof_box
end

---
--- Recalculates the roof geometry for a generic roof type.
---
--- @param roof_type string The type of roof (e.g. "Flat", "Gable")
--- @param voxel_box table The voxel box defining the roof dimensions
--- @param direction string The cardinal direction the roof is facing (e.g. "North", "East")
--- @param parapet boolean Whether the roof has parapets
--- @param special string Any special roof configuration (e.g. "odd_gable_long", "odd_gable_short")
--- @return table, table The updated roof objects and the bounding box of the roof
function RoomRoof:RecalcRoof_Generic(roof_type, voxel_box, direction, parapet, special)
	local objs = self.roof_objs
	if not objs or not next(objs) then return end
	
	--recalc common properties
	for i=1,#objs do
		local obj = objs[i]
		if IsValid(obj) then
			obj.room = self
			obj.floor = self.floor
			if IsRoofTile(obj) then
				SetSlabColorHelper(obj, obj.colors or self.roof_colors)
			else
				SetSlabColorHelper(obj, obj.colors or self.outer_colors)
			end
		end
	end
	
	--prepare for gable roofs
	local odd_gable = (special == "odd_gable_long" or special == "odd_gable_short")
	local odd_gable_long_half = (special == "odd_gable_long")
	
	--local coordinate system (origin, forward, right)
	local inclination = self:GetRoofInclination()
	local ox, oy, oz,
	      fx, fy, fz, fs,
	      rx, ry, rz, rs = SolveRoofCoordSystem(voxel_box, self.roof_additional_height, direction, inclination)

	--geometric plane
	local clip_plane = PlaneFromPoints(
		ox, oy, oz,
		ox + rx*rs, oy + ry*rs, oz + rz*rs,
		ox + fx*fs, oy + fy*fs, oz + fz*fs)

	--find side cardinal directions and their angles
	local side_front, side_right, side_back, side_left = SideNames(direction)
	local angle_front = cardinal_directions[side_front]
	local angle_right = cardinal_directions[side_right]
	local angle_back = cardinal_directions[side_back]
	local angle_left = cardinal_directions[side_left]
	
	--filter objects depending on their role in the roof
	local roof_box = box(BoxVoxelToWorld(voxel_box)):grow(1)
	local walls_box = roof_box
	
	--gable roofs of odd length use a different box for their walls
	if odd_gable then
		local dminx, dminy, dmaxx, dmaxy = 0, 0, 0, 0
		if direction == "West" then dminx = 1 end
		if direction == "North" then dminy = 1 end
		if direction == "East" then dmaxx = 1 end
		if direction == "South" then dmaxy = 1 end
		
		if odd_gable_long_half then
			walls_box = walls_box:grow(
				MulDivRound(dminx, const.SlabSizeX, 2),
				MulDivRound(dminy, const.SlabSizeY, 2),
				MulDivRound(dmaxx, const.SlabSizeX, 2),
				MulDivRound(dmaxy, const.SlabSizeY, 2))
		else
			local walls_voxel_box = voxel_box:grow(-dminx, -dminy, -dmaxx, -dmaxy)
			walls_box = box(BoxVoxelToWorld(walls_voxel_box)):grow(1)
		end
	end
	
	--DbgAddBox(roof_box, const.clrWhite)
	--DbgAddBox(walls_box:grow(10,10,10), const.clrRed)
	
	--filter objects into categories and recover some properties
	local wall_objs, wall_corner_objs, roof_objs = {}, {}, {}
	--also assign entities
	local class_gable, class_rake
	if odd_gable then
		class_rake, class_gable = "RoofEdgeSlab", "RoofPlaneSlab"
	else
		class_rake, class_gable = "RoofCorner", "RoofEdgeSlab"
	end
	
	local is_flat = self:GetRoofType() == "Flat"
	local center = point(
		ox + fx*fs/2 + rx*rs/2,
		oy + fy*fs/2 + ry*rs/2,
		oz + fz*fs/2 + rz*rs/2)
	local right = point(rx, ry, rz)
	local north_x, north_y, south_x, south_y = self.box:xyxy()
	local east_x, east_y = south_x, north_y
	local epsilon = voxelSizeX / 10

	for i, obj in ipairs(objs) do
		if obj then
			if IsKindOf(obj, "RoofCornerWallSlab") and walls_box:Point2DInside(obj) then
				table.insert(wall_corner_objs, obj)

				if IsCloser2D(obj, north_x, north_y, epsilon) then
					obj.side = "North"
				elseif IsCloser2D(obj, south_x, south_y, epsilon) then
					obj.side = "South"
				elseif IsCloser2D(obj, east_x, east_y, epsilon) then
					obj.side = "East"
				else
					obj.side = "West"
				end
			elseif IsKindOf(obj, "RoofWallSlab") and walls_box:Point2DInside(obj) then
				table.insert(wall_objs, obj)
				obj.side = slabAngleToDir[obj:GetAngle()]
			elseif IsKindOf(obj, "RoofSlab") and roof_box:Point2DInside(obj) and (not obj.dir or obj.dir == direction) then
				local angle = obj:GetAngle()
				if (not IsKindOf(obj, "RoofPlaneSlab") or angle == angle_back) and obj.dir then
					table.insert(roof_objs, obj)
				end
				
				obj.side = direction
				
				if not obj.dir then
					if IsKindOf(obj, class_gable) then
						obj.roof_comp = "Gable"
					elseif IsKindOf(obj, class_rake) then
						obj.roof_comp = "RakeGable"
					end
				elseif IsKindOf(obj, "RoofEdgeSlab") then
					if angle == angle_front then
						obj.roof_comp = "Ridge"
					elseif angle == angle_back then
						obj.roof_comp = "Eave"
					else
						obj.roof_comp = "Rake"
						if angle == angle_right then
							obj:SetMirrored(true)
						end
					end
				elseif IsKindOf(obj, "RoofCorner") then
					obj.roof_comp = (angle == angle_front or angle == angle_right) and "RakeRidge" or "RakeEave"
					if (angle == angle_front) == (Dot(right, obj:GetPos() - center) < 0) then
						obj:SetMirrored(true)
					end
				elseif IsKindOf(obj, "RoofPlaneSlab") then
					obj.roof_comp = "Plane"
					self:PostProcessPlaneSlab(obj, is_flat)
				end
			
			end
			
			obj:DelayedUpdateEntity()
		end
	end
	
	--roofs without inclination don't have skewed slabs
	if inclination > 0 then
		
		local sx = MulDivRound(fz, guim, const.SlabSizeX)
		local sy = MulDivRound(fz, guim, const.SlabSizeY)
		for i,slab in ipairs(roof_objs) do
			local skew_x, skew_y
			local angle = slab:GetAngle()
			if angle == angle_front then
				skew_x, skew_y = sx, 0
			elseif angle == angle_right or angle == angle_left then
				skew_x, skew_y = 0, sy
			elseif angle == angle_back then
				skew_x, skew_y = -sx, 0
			end
			
			if skew_x and skew_y then
				slab:SetSkew(skew_x, skew_y)
			end
		end
		
	end
	
	--clip top parts of a gable roof
	if odd_gable then
		
		local gable_clip_plane = GetGableClipPlane(ox,oy,oz, fx,fy,fz,fs, rx,ry,rz,rs)
		for i,slab in ipairs(roof_objs) do
			slab:SetClipPlane(gable_clip_plane)
		end
		
	end
	
	--prepare clipping planes for walls (fpn=front-(clipping)plane-normal;fpd=front-(clipping)plane-distance;...)
	local fp, rp, bp, lp = clip_plane, clip_plane, clip_plane, clip_plane
	if parapet then
		--when creating a parapets we don't provide clipping planes
		if roof_type == "Flat"	then
			--parapets on all sides
			fp, rp, bp, lp = false, false, false, false
		else
			--parapets on left and right sides only
			rp, lp = false, false
		end
	end
	
	--clip walls
	for i,wall in ipairs(wall_objs) do
		local clip_plane
		local angle = wall:GetAngle()
		if angle == angle_front then clip_plane = fp end
		if angle == angle_right then clip_plane = rp end
		if angle == angle_back then clip_plane = bp end
		if angle == angle_left then clip_plane = lp end
		
		if clip_plane then
			wall:SetClipPlane(clip_plane)
		end
	end
	
	--preapre clipping planes for wall corners (fcpn=front-corner-(clipping)plane-normal;...)
	--where there are two adjacent parapets - there is a corner without a clipping plane
	local fcp, rcp, bcp, lcp = clip_plane, clip_plane, clip_plane, clip_plane
	if not lp and not fp then fcp = false end
	if not fp and not rp then rcp = false end
	if not rp and not bp then bcp = false end
	if not bp and not lp then lcp = false end
	
	--clip wall corners
	for i,corner in ipairs(wall_corner_objs) do
		local clip_plane
		local angle = corner:GetAngle()
		if angle == angle_front then clip_plane = fcp end
		if angle == angle_right then clip_plane = rcp end
		if angle == angle_back then clip_plane = bcp end
		if angle == angle_left then clip_plane = lcp end
		
		if clip_plane then
			corner:SetClipPlane(clip_plane)
		end
	end
	
	return RoofCoordSystemBBox(ox,oy,oz, fx,fy,fz,fs, rx,ry,rz,rs, self.roof_additional_height)
end

---
--- Sets whether the roof should be kept passable.
---
--- If `val` is `true`, the roof will be made passable by adjusting the `roof_additional_height` property.
---
--- @param val boolean Whether to keep the roof passable.
function RoomRoof:Setkeep_roof_passable(val)
	self.keep_roof_passable = val
	if val then
		self:MakeRoofPassable()
	end
end

--moves roof so it becomes passable
---
--- Makes the roof passable by adjusting the `roof_additional_height` property.
---
--- This function calculates the new `roof_additional_height` value that will make the roof passable, and then calls `OnSetroof_additional_height` to update the roof.
---
--- @return nil
function RoomRoof:MakeRoofPassable()
	local nrah, rah = self:GetPassableRoofAdditionalHeight()
	if nrah then
		self:OnSetroof_additional_height(nrah, rah)
	end
end

---
--- Calculates the new `roof_additional_height` value that will make the roof passable.
---
--- This function checks if the room has a roof, and if the roof type is "Flat". It then finds the first `RoofPlaneSlab` object in the `roof_objs` list that has a "Slab" spot. It uses the position of this slab to calculate the minimum height required for the roof to be passable, and returns the new `roof_additional_height` value that would achieve this.
---
--- @return number|nil new_roof_additional_height, old_roof_additional_height The new `roof_additional_height` value that would make the roof passable, and the old `roof_additional_height` value.
function RoomRoof:GetPassableRoofAdditionalHeight()
	if not self:HasRoof() then
		return
	end
	if self:GetRoofType() ~= "Flat" then
		--only flat roof may be passable
		return
	end
	
	local objs = self.roof_objs
	local rs
	for i = 1, #(objs or "") do
		local o = objs[i]
		if IsKindOf(o, "RoofPlaneSlab") and o:HasSpot("Slab") then
			rs = o
			break
		end
	end
	
	if not rs then
		return
	end
	
	local rah = self.roof_additional_height
	local si = rs:GetSpotBeginIndex("Slab")
	local p = rs:GetPos()
	local sp = rs:GetSpotPos(si)
	local offs = sp - p
	
	local minHeight = sp:z() - rah
	local vx, vy, vz = SnapToVoxel(sp:xyz())
	if vz < minHeight then
		vz = vz + voxelSizeZ
	end
	
	local np = point(vx, vy, vz) - offs
	local d = np:z() - p:z()
	local nrah = rah + d
	assert(nrah >= 0 and nrah <= voxelSizeZ)
	return nrah, rah
end

---- roof getters and setters

---
--- Returns whether roof visuals are enabled.
---
--- @return boolean RoofVisualsEnabled Whether roof visuals are enabled.
function RoomRoof:GetroofVisualsEnabled()
	return RoofVisualsEnabled
end

---
--- Sets the roof visuals enabled state for a room.
---
--- @param v boolean Whether to enable or disable roof visuals.
---
function RoomRoof:SetroofVisualsEnabledForRoom(v)
	local roof_objs = self.roof_objs
	if roof_objs then
		for j=1,#roof_objs do
			local roof_obj = roof_objs[j]
			if IsValid(roof_obj) then
				local opacity
				if v then
					roof_obj:ClearHierarchyGameFlags(const.gofSolidShadow)
					opacity = 100
				else
					roof_obj:SetHierarchyGameFlags(const.gofSolidShadow)
					opacity = 0
				end
				if not IsKindOf(roof_obj, "Decal") then
					roof_obj:SetOpacity(opacity)
				end
			end
		end
		MapForEach(self.roof_box, "CObject", function(o)
			if o:GetGameFlags(const.gofOnRoof)~=0 then
				local opacity
				if v then
					o:ClearHierarchyGameFlags(const.gofSolidShadow)
					opacity = 100
				else
					o:SetHierarchyGameFlags(const.gofSolidShadow)
					opacity = 0
				end
				if not IsKindOf(o, "Decal") then
					o:SetOpacity(opacity)
				end
			end
		end)
	end
end

---
--- Sets the roof visuals enabled state for all rooms.
---
--- @param v boolean Whether to enable or disable roof visuals.
---
function RoomRoof:SetroofVisualsEnabled(v)
	RoofVisualsEnabled = v
	
	MapForEach("map", "Room", function(roof)
		roof:SetroofVisualsEnabledForRoom(v)
	end)
end

---
--- Handles changes to the roof type of a room.
---
--- When the roof type is changed, this function updates the roof direction based on the new roof type. If the new roof type is "Gable", it sets the roof direction to the first direction in the `GableRoofDirections` table. Otherwise, if the current roof direction is in the `GableRoofDirections` table, it sets the roof direction to the first cardinal direction.
---
--- After updating the roof direction, this function calls `self:RecreateRoof()` to recreate the roof with the new settings.
---
--- @param new_type string The new roof type.
--- @param old_type string The previous roof type.
---
function RoomRoof:OnSetroof_type(new_type, old_type)
	if old_type == new_type then return end
	self.roof_type = new_type
	if new_type == "Gable" and not table.find(GableRoofDirections, self.roof_direction) then
		self.roof_direction = GableRoofDirections[1]
	elseif table.find(GableRoofDirections, self.roof_direction) then
		self.roof_direction = cardinal_direction_names[1]
	end
	self:RecreateRoof()
end

---
--- Handles changes to the roof material of a room.
---
--- When the roof material is changed, this function updates the roof material and then calls `self:UnlockRoof()` and `self:RecreateRoof()` to unlock the roof and recreate it with the new material.
---
--- @param new_mat string The new roof material.
--- @param old_mat string The previous roof material.
---
function RoomRoof:OnSetroof_mat(new_mat, old_mat)
	if old_mat == new_mat then return end
	self.roof_mat = new_mat
	self:UnlockRoof()
	self:RecreateRoof()
end

---
--- Handles changes to the roof direction of a room.
---
--- When the roof direction is changed, this function updates the roof direction and then calls `self:RecreateRoof()` to recreate the roof with the new direction.
---
--- @param new_dir string The new roof direction.
--- @param old_dir string The previous roof direction.
---
function RoomRoof:OnSetroof_direction(new_dir, old_dir)
	if old_dir == new_dir then return end
	self.roof_direction = new_dir
	self:RecreateRoof()
end

---
--- Handles changes to the roof inclination of a room.
---
--- When the roof inclination is changed, this function updates the roof inclination and then calls `self:RecreateRoof()` to recreate the roof with the new inclination.
---
--- @param new_incl number The new roof inclination.
--- @param old_incl number The previous roof inclination.
---
function RoomRoof:OnSetroof_inclination(new_incl, old_incl)
	if old_incl == new_incl then return end
	self.roof_inclination = new_incl
	self:RecreateRoof()
end

---
--- Handles changes to the roof parapet of a room.
---
--- When the roof parapet is changed, this function updates the roof parapet and then calls `self:RecreateRoof()` to recreate the roof with the new parapet.
---
--- @param new_parapet boolean The new roof parapet.
--- @param old_parapet boolean The previous roof parapet.
---
function RoomRoof:OnSetroof_parapet(new_parapet, old_parapet)
	if old_parapet == new_parapet then return end
	self.roof_parapet = new_parapet
	self:RecreateRoof()
end

---
--- Handles changes to the additional height of the roof.
---
--- When the additional height of the roof is changed, this function updates the `roof_additional_height` property and then calls `self:RecreateRoof()` to recreate the roof with the new additional height.
---
--- @param new_height number The new additional height of the roof.
--- @param old_height number The previous additional height of the roof.
---
function RoomRoof:OnSetroof_additional_height(new_height, old_height)
	if old_height == new_height then return end
	self.roof_additional_height = new_height
	self:RecreateRoof()
end

---
--- Handles changes to the build_ceiling property of the RoomRoof object.
---
--- When the build_ceiling property is changed, this function updates the `build_ceiling` property and then calls `self:RecreateRoof()` to recreate the roof with the new build_ceiling setting.
---
--- @param val boolean The new value for the build_ceiling property.
---
function RoomRoof:OnSetbuild_ceiling(val)
	self.build_ceiling = val
	self:RecreateRoof()
end

---
--- Handles changes to the ceiling material of the RoomRoof object.
---
--- When the ceiling material is changed, this function updates the ceiling material of any CeilingSlab objects that are part of the roof, and then calls `self:SetCeilingMatToCeilingSlabs()` to update the ceiling material.
---
--- @param mat string The new ceiling material.
--- @param oldmat string The previous ceiling material.
---
function RoomRoof:OnSetceiling_mat(mat, oldmat)
	if oldmat == mat then return end
	if not self.build_ceiling then return end
	Notify(self, "SetCeilingMatToCeilingSlabs")
end

---
--- Updates the ceiling material of all CeilingSlab objects that are part of the roof.
---
--- This function is called when the `ceiling_mat` property of the RoomRoof object is changed. It iterates through the `roof_objs` array and updates the `material` property of each CeilingSlab object to the new `ceiling_mat` value. It then calls `UpdateEntity()` on each CeilingSlab to update the entity in the game world.
---
--- If the `build_ceiling` property is false, this function does nothing.
---
--- After updating the CeilingSlab objects, this function calls `ComputeSlabVisibilityInBox()` to recompute the visibility of the slabs in the bounding box of the updated CeilingSlab objects.
---
--- @param self RoomRoof The RoomRoof object.
function RoomRoof:SetCeilingMatToCeilingSlabs()
	if not self.build_ceiling then return end
	
	local objs = self.roof_objs
	local mat = self.ceiling_mat
	local bb = box()
	for i = #(objs or ""), 1, -1 do
		local o = objs[i]
		if not IsKindOf(o, "CeilingSlab") then
			break
		end
		o.material = mat
		o:UpdateEntity()
		bb = Extend(bb, o:GetPos())
	end
	if bb:IsValid() and not bb:IsEmpty() then
		ComputeSlabVisibilityInBox(bb)
	end
end

---
--- Creates a ceiling for the RoomRoof object.
---
--- This function creates a grid of CeilingSlab objects that cover the area of the RoomRoof. The CeilingSlab objects are positioned based on the size and position of the RoomRoof, and are given the material specified by the `ceiling_mat` property of the RoomRoof.
---
--- @param self RoomRoof The RoomRoof object.
--- @param objs table A table to store the created CeilingSlab objects in.
---
function RoomRoof:CreateCeiling(objs)
	local mat = self.ceiling_mat
	local sx, sy = self.position:x(), self.position:y()
	local sizeX, sizeY, sizeZ = self.size:xyz()
	sx = sx + halfVoxelSizeX
	sy = sy + halfVoxelSizeY
	local gz = self:CalcZ() + sizeZ * voxelSizeZ
	
	SuspendPassEdits("Room:CreateCeiling")
	for xOffset = 0, sizeX - 1 do
		for yOffset = 0, sizeY - 1 do
			local x = sx + xOffset * voxelSizeX
			local y = sy + yOffset * voxelSizeY
			
			local ceil = self:CreateSlab("CeilingSlab", {
				floor = self.floor, 
				material = mat, 
				side = false, 
				room = self
			})
			self:SetupNewObj(ceil, x, y, gz, 0, nil, nil, objs)
		end
	end
	ResumePassEdits("Room:CreateCeiling")
end

---
--- Updates the colors of all roof tiles in the RoomRoof object when the `roof_colors` property is changed.
---
--- This function is called whenever the `roof_colors` property of the RoomRoof object is changed. It iterates through all the roof objects (`self.roof_objs`) and sets the `colors` property of each object that is a RoofTile.
---
--- @param self RoomRoof The RoomRoof object.
--- @param val table The new value of the `roof_colors` property.
--- @param oldVal table The previous value of the `roof_colors` property.
---
function RoomRoof:OnSetroof_colors(val, oldVal)
	for i = 1, #(self.roof_objs or "") do
		local o = self.roof_objs[i]
		if o and IsRoofTile(o) then
			o:Setcolors(val)
		end
	end
end

---- roof slabs

--[[@@@
@class RoofSlab
All slabs that build up the roof (exist in room.roof_objs) derive from this class.
]]
DefineClass.RoofSlab = {
	__parents = { "Slab", "Mirrorable" },
	
	properties = {
		{ category = "Slabs", id = "material", name = "Material", editor = "preset_id", preset_class = "SlabPreset", preset_group = "RoofSlabMaterials", extra_item = noneWallMat, default = "none", },
		{ category = "Slabs", id = "forceInvulnerableBecauseOfGameRules", name = "Invulnerable", editor = "bool", default = false, help = "In context of destruction."},
		{ id = "dir", name = "Direction", editor = "choice", default = false, items = cardinal_direction_names },
		{ id = "SkewX" },
		{ id = "SkewY" },
		{ id = "Mirrored", editor = "bool", default = false, dont_save = true },
	},
	
	roof_comp = false,
	colors_room_member = "roof_colors",
	entity_base_name = "Roof",
	room_container_name = "roof_objs",
	invulnerable = false,
}

---
--- Composes the base entity name for a RoofSlab object.
---
--- The base entity name is composed using the material set, the roof component type, and the entity base name.
---
--- @param self RoofSlab The RoofSlab object.
--- @return string The base entity name for the RoofSlab object.
---
function RoofSlab:GetBaseEntityName()
	local material_list = Presets.SlabPreset[self.MaterialListClass] or Presets.SlabPreset.RoofSlabMaterials
	local svd = material_list[self.material]
	
	return string.format("%s_%s_%s", self.entity_base_name, svd.EntitySet, self.roof_comp)
end

local roofCompToSubvariantArr = {
	Plane = "subvariants",
	Eave = "eave_subvariants",
	Rake = "rake_subvariants",
	Ridge = "ridge_subvariants",
	Gable = "gable_subvariants",
	RakeGable = "rake_gable_subvariants",
	RakeRidge = "rake_ridge_subvariants",
	RakeEave = "rake_eave_subvariants",
	GableCrest = "crest_subvariants",
	RakeGableCrestTop = "crest_top_subvariants",
	RakeGableCrestBot = "crest_bot_subvariants",
	GableSlope = "slope_subvariants",
	RakeGableSlopeTop = "slope_top_subvariants",
	RakeGableSlopeBot = "slope_bot_subvariants",
}

---
--- Composes the entity name for a RoofSlab object based on its material, roof component type, and subvariant.
---
--- The entity name is composed using the following format:
--- - If a subvariant is selected: `Roof_{EntitySet}_{RoofComp}_{SubvariantDigit}`
--- - If no subvariant is selected: a random subvariant is chosen and the name is composed using the subvariant suffix: `Roof_{EntitySet}_{RoofComp}_{SubvariantSuffix}`
--- - If no subvariants are available: the name is composed using the material and roof component: `Roof_{Material}_{RoofComp}_01`
---
--- @param self RoofSlab The RoofSlab object.
--- @return string The composed entity name for the RoofSlab object.
---
function RoofSlab:ComposeEntityName()
	local material_list = Presets.SlabPreset[self.MaterialListClass] or Presets.SlabPreset.RoofSlabMaterials
	local svd = material_list[self.material]
	local sm = roofCompToSubvariantArr[self.roof_comp]
	local subvariants = svd and svd[sm]
	if subvariants and #subvariants > 0 then
		if self.subvariant ~= -1 then --user selected subvar
			local digit = ((self.subvariant - 1) % #subvariants) + 1 --assumes "01, 02, etc. suffixes
			local digitStr = digit < 10 and "0" .. tostring(digit) or tostring(digit)
			return string.format("Roof_%s_%s_%s", svd.EntitySet, self.roof_comp, digitStr)
		else
			local subvariant, i = table.weighted_rand(subvariants, "chance", self:GetSeed())
			while subvariant do
				local name = string.format("Roof_%s_%s_%s", svd.EntitySet, self.roof_comp, subvariant.suffix)
				if IsValidEntity(name) then
					return name
				end
				i = i - 1
				subvariant = subvariants[i]
			end
		end
	end
	return string.format("Roof_%s_%s_01", self.material or noneWallMat, self.roof_comp)
end

---
--- Mirrors the RoofSlab object from the room it is contained in.
---
--- This function is currently empty and does not perform any mirroring logic.
---
--- @param self RoofSlab The RoofSlab object.
---
function RoofSlab:MirroringFromRoom()
end

---
--- Clones the RoofSlab object and recreates the roof in the room it is contained in.
---
--- This function is called when the RoofSlab object is cloned in the editor. It ensures that the roof is properly recreated in the room after the clone operation.
---
--- @param self RoofSlab The RoofSlab object being cloned.
--- @param source RoofSlab The source RoofSlab object being cloned.
---
function RoofSlab:EditorCallbackClone(source)
	Slab.EditorCallbackClone(self, source)
	if source.room then
		source.room:RecreateRoof()
	end
end

DefineClass.RoofPlaneSlab = {
	__parents = { "RoofSlab", "HFloorAlignedObj" },
	flags = { efPathSlab = true },
	properties = {
		{ category = "Slabs", id = "material", name = "Material", editor = "preset_id", preset_class = "SlabPreset", preset_group = "RoofSlabMaterials", extra_item = noneWallMat, default = "none", },
	},
	MaterialListClass = "RoofSlabMaterials",
	roof_comp = "Plane",
}

DefineClass.RoofEdgeSlab = {
	__parents = { "RoofSlab", "HWallAlignedObj" },
	
	MaterialListClass = "RoofSlabMaterials",
	roof_comp = "Rake",
}

DefineClass.RoofCorner = {
	__parents = { "RoofSlab", "HCornerAlignedObj" },
	
	MaterialListClass = "RoofSlabMaterials",
	roof_comp = "RakeRidge",
}

--[[@@@
@class BaseRoofWallSlab
All walls and wall corners that build up the roof derive from this class.
They will behave exactly like their normal wall counterparts, but are identifiable as part of the roof by this class.
]]
DefineClass.BaseRoofWallSlab = {
	__parents = { "CObject" },
	properties = {
		{ category = "Slabs", id = "forceInvulnerableBecauseOfGameRules", name = "Invulnerable", editor = "bool", default = false, help = "In context of destruction."},
	},
	room_container_name = "roof_objs",
	invulnerable = false,
}

DefineClass.RoofWallSlab = {
	__parents = { "BaseRoofWallSlab", "WallSlab" },
	room_container_name = "roof_objs",
	forceInvulnerableBecauseOfGameRules = false,
	invulnerable = false,
}

--[[@@@
@class GableRoofWallSlab
This is a workaround class for gable roofs of odd length require walls that are aligned on voxel corners, instead of their edges.
This type of walls is needed, because we cannot clip a single object with multiple planes.
]]
DefineClass.GableRoofWallSlab = {
	__parents = { "RoofWallSlab", "CornerAlignedObj" },
}

---
--- Aligns the GableRoofWallSlab object to the specified position and angle.
---
--- @param pos table|nil The position to align the object to. If nil, the object's current position is used.
--- @param angle number|nil The angle to align the object to. If nil, the object's current angle is used.
---
function GableRoofWallSlab:AlignObj(pos, angle)
	CornerAlignedObj.AlignObj(self, pos, angle)
end

DefineClass("GableCapRoofPlaneSlab", "RoofPlaneSlab")
DefineClass("GableCapRoofEdgeSlab",  "RoofEdgeSlab")
DefineClass("GableCapRoofCorner",    "RoofCorner")

DefineClass.RoofCornerWallSlab = {
	__parents = { "BaseRoofWallSlab", "RoomCorner" },
	room_container_name = "roof_objs",
	forceInvulnerableBecauseOfGameRules = false,
	invulnerable = false,
}

---- horizontally aligned objects (can move freely on the Z axis)

DefineClass.HWallAlignedObj = {
	__parents = { "WallAlignedObj" },
}

---
--- Aligns the HWallAlignedObj object to the specified position and angle, taking into account the object's attachment to a parent object.
---
--- @param self HWallAlignedObj The object to align.
---
function HWallAlignedObj:AlignObjAttached()
	local p = self:GetParent()
	assert(p)
	local ap = self:GetPos() + self:GetAttachOffset()
	local x, y, z, angle = WallWorldToVoxel(ap:x(), ap:y(), ap:z(), self:GetAngle())
	x, y, z = WallVoxelToWorld(x, y, z, angle)
	local my_x, my_y, my_z = self:GetPosXYZ()
	my_z = my_z or InvalidZ
	px, py, pz = p:GetPosXYZ()
	self:SetAttachOffset(x - px, y - py, my_z - pz)
	self:SetAngle(angle) --havn't tested with parents with angle ~= 0, might not work
end

---
--- Aligns the HWallAlignedObj object to the specified position and angle, taking into account the object's attachment to a parent object.
---
--- @param pos table|nil The position to align the object to. If nil, the object's current position is used.
--- @param angle number|nil The angle to align the object to. If nil, the object's current angle is used.
---
function HWallAlignedObj:AlignObj(pos, angle)
	local x, y, z
	if pos then
		x, y, z = pos:xyz()
		x, y, z, angle = WallWorldToVoxel(x, y, z or terrain.GetHeight(x, y), angle or self:GetAngle())
	else
		x, y, z, angle = WallWorldToVoxel(self)
	end
	local my_x, my_y, my_z = self:GetPosXYZ()
	my_z = my_z or InvalidZ
	x, y, z = WallVoxelToWorld(x, y, z, angle)
	self:SetPosAngle(x, y, my_z, angle)
end

DefineClass.HFloorAlignedObj = {
	__parents = { "FloorAlignedObj" },
}

---
--- Aligns the HFloorAlignedObj object to the specified position and angle, taking into account the object's attachment to a parent object.
---
--- @param pos table|nil The position to align the object to. If nil, the object's current position is used.
--- @param angle number|nil The angle to align the object to. If nil, the object's current angle is used.
---
function HFloorAlignedObj:AlignObj(pos, angle)
	local x, y, z
	if pos then
		x, y, z, angle = WorldToVoxel(pos, angle or self:GetAngle())
	else
		x, y, z, angle = WorldToVoxel(self)
	end
	local my_x, my_y, my_z = self:GetPosXYZ()
	my_z = my_z or InvalidZ
	x, y, z = VoxelToWorld(x, y, z)
	self:SetPosAngle(x, y, my_z, angle)
end

DefineClass.HCornerAlignedObj = {
	__parents = { "CornerAlignedObj" },
}

---
--- Aligns the HCornerAlignedObj object to the specified position and angle, taking into account the object's attachment to a parent object.
---
--- @param pos table|nil The position to align the object to. If nil, the object's current position is used.
--- @param angle number|nil The angle to align the object to. If nil, the object's current angle is used.
---
function HCornerAlignedObj:AlignObj(pos, angle)
	local x, y, z 
	if pos then
		x, y, z, angle = CornerWorldToVoxel(pos, angle or self:GetAngle())
	else
		x, y, z, angle = CornerWorldToVoxel(self)
	end
	local my_x, my_y, my_z = self:GetPosXYZ()
	my_z = my_z or InvalidZ
	x, y, z = CornerVoxelToWorld(x, y, z, angle)
	self:SetPosAngle(x, y, my_z, angle)
end

---------------------------------------------------
--vfx controllers
---------------------------------------------------
local function IsOutsideVolumes(obj)
	local inside = false
	local mr = obj.room
	local mp = obj:GetPos()
	MapForEach(obj:GetObjectBBox():grow(voxelSizeX * 30, voxelSizeY * 30, 0), "Room", function(v, mp, mr)
		if v ~= mr then
			if not v:IsRoofOnly() and v.box:PointInsideInclusive(mp) and mp:z() < v.box:maxz() then --horizontally inclusive only!
				inside = "volume"
				--DbgAddBox(v.box)
				return "break"
			end
			if v.roof_box and v.roof_box:PointInsideInclusive(mp) then
				inside = "roof"
				--DbgAddBox(v.roof_box)
				return "break"
			end
		end
	end, mp, mr)
	
	return not inside, inside
end

---
--- Determines whether a roof edge should have an eaves segment.
---
--- @param roof_edge table The roof edge object to check.
--- @return boolean True if the roof edge should have an eaves segment, false otherwise.
---
function ShouldHaveRoofEavesSegment(roof_edge)
	if not roof_edge.isVisible or roof_edge.is_destroyed then return false end
	local room = roof_edge.room
	if roof_edge.roof_comp == "Eave" or (room and room.roof_type == "Flat") then
		if IsOutsideVolumes(roof_edge) then
			return true
		end
	end
	
	return false
end

---
--- Called when the roof edge tiles are destroyed.
--- This function updates the roof VFX controllers to reflect the changes.
---
function RoomRoof:OnRoofEdgeTilesDestroyed()
	self:UpdateRoofVfxControllers()
end

---
--- Called when the roof plane tiles are destroyed.
--- This function is a placeholder for any logic that should be executed when the roof plane tiles are destroyed.
---
function RoomRoof:OnRoofPlaneTilesDestroyed()
	--TODO: something should happen
end

---
--- Sets the visibility of the VFX controllers for the roof surface and eaves.
---
--- @param val boolean The visibility state to set for the VFX controllers.
---
function RoomRoof:SetVfxControllersVisibility(val)
	for i = 1, #(self.vfx_roof_surface_controllers or "") do
		self.vfx_roof_surface_controllers[i]:SetVisibility(val)
	end
	for i = 1, #(self.vfx_eaves_controllers or "") do
		self.vfx_eaves_controllers[i]:SetVisibility(val)
	end
end

---
--- Updates the VFX controllers for the roof surface and eaves based on the current state of the RoomRoof object.
---
--- This function is responsible for creating, updating, and destroying the VFX controllers that render the roof surface and eaves. It determines the appropriate configuration of the VFX controllers based on the roof type and the presence of roof edge slabs that require eaves segments.
---
--- @param self RoomRoof The RoomRoof object to update the VFX controllers for.
---
function RoomRoof:UpdateRoofVfxControllers()
	local b = self.roof_box
	if not self:HasRoof() or not b then 
		DoneObjects(self.vfx_roof_surface_controllers)
		DoneObjects(self.vfx_eaves_controllers)
		self.vfx_roof_surface_controllers = false
		self.vfx_eaves_controllers = false
		return 
	end
	
	--surfaces
	local controllers = self.vfx_roof_surface_controllers
	
	if self.roof_type == "Gable" then
		controllers = controllers or {}
		
		local vc1 = IsValid(controllers[1]) and controllers[1] or PlaceObject("RoofSurface")
		local vc2 = IsValid(controllers[2]) and controllers[2] or PlaceObject("RoofSurface")
		local v11, v12, v13, v21, v22, v23
		v11 = b:min()
		if self.roof_direction == "East-West" then
			v12 = v11 + point(b:sizex(), 0, 0)
			v13 = v11 + point(0, b:sizey() / 2, 0)
			v21 = v13
			v22 = v21 + point(b:sizex(), 0, 0)
			v23 = v21 + point(0, b:sizey() / 2, 0)
		else
			v12 = v11 + point(b:sizex() / 2, 0, 0)
			v13 = v11 + point(0, b:sizey(), 0)
			v21 = v12
			v22 = v21 + point(b:sizex() / 2, 0, 0)
			v23 = v21 + point(0, b:sizey(), 0)
		end
		
		vc1:InitFromParent(self)
		vc2:InitFromParent(self)
		vc1:SetVertexes(v11, v12, v13)
		local _, angle = self:GetRoofZAndDir(v11)
		vc1.angle = angle + 180 * 60
		vc2:SetVertexes(v21, v22, v23)
		vc2.angle = angle
		
		controllers[1] = vc1
		controllers[2] = vc2
	elseif self.roof_type == "Shed" or self.roof_type == "Flat" then
		controllers = controllers or {}
		
		local vc = IsValid(controllers[1]) and controllers[1] or PlaceObject("RoofSurface")
		local v1 = b:min()
		local v2 = v1 + point(b:sizex(), 0, 0)
		local v3 = v1 + point(0, b:sizey(), 0)
		
		vc:InitFromParent(self)
		vc:SetVertexes(v1, v2, v3)
		local _, angle = self:GetRoofZAndDir(v1)
		vc.angle = angle + 180 * 60
		
		controllers[1] = vc
		if IsValid(controllers[2]) then
			DoneObject(controllers[2])
		end
		controllers[2] = nil
	else
		for i = #(controllers or ""), 1, -1 do
			DoneObject(controllers[i])
		end
		controllers = false
	end
	
	self.vfx_roof_surface_controllers = controllers
	
	local map = {}
	MapForEach(b:grow(10, 10, 10), "RoofEdgeSlab", function(o, self, map)
		if o.room == self then
			if ShouldHaveRoofEavesSegment(o) then
				local s = slabAngleToDir[o:GetAngle()]
				map[s] = map[s] or {}
				local x, y, z = WorldToVoxel(o)
				local sigcoord
				if s == "East" or s == "West" then
					sigcoord = y
				else
					sigcoord = x
				end
				
				map[s][sigcoord] = o
				map[s].min = not map[s].min and sigcoord or Min(map[s].min, sigcoord)
				map[s].max = not map[s].max and sigcoord or Max(map[s].max, sigcoord)
			end
		end
	end, self, map)
	
	
	local function DetermineVertex(o, side, last)
		local curb = o:GetObjectBBox()
		local dir = (o:GetRelativePoint(axis_x) - o:GetPos())
		local sx, sy, sz = curb:sizexyz()
		
		if side == "East" or side == "West" then
			local p = curb:Center() + MulDivRound(dir, sx / 2, 4096)
			local x, y, z = p:xyz()
			return point(x, y + halfVoxelSizeY * (not last and -1 or 1), z)
		else
			local p = curb:Center() + MulDivRound(dir, sy / 2, 4096)
			local x, y, z = p:xyz()
			return point(x + halfVoxelSizeX * (not last and -1 or 1), y, z)
		end
	end
	
	local controllers = self.vfx_eaves_controllers
	local cidx = 1
	for side, t in pairs(map) do
		local last
		local v1, v2
		
		for i = t.min, t.max + 1 do
			local cur = t[i]
			if cur then
				if not last then
					v1 = DetermineVertex(cur, side, false)
				end
			else
				if last then
					v2 = DetermineVertex(last, side, true)
					
					controllers = controllers or {}
					local vc = IsValid(controllers[cidx]) and controllers[cidx] or PlaceObject("RoofEavesSegment")
					controllers[cidx] = vc
					cidx = cidx + 1
					
					vc:InitFromParent(self)
					
					if side == "South" or side == "West" then
						vc.vertex1 = v2
						vc.vertex2 = v1
					else
						vc.vertex1 = v1
						vc.vertex2 = v2
					end
					
					vc.angle = last:GetAngle()
					
					--[[DbgAddVector(v1)
					DbgAddVector(v2)
					DbgAddVector(v1, v2 - v1)]]
					if vc.playing then
						vc:Stop()
						vc:Play()
					end
					
					v1 = nil
					v2 = nil
				end
			end
			
			last = cur
		end
	end
	
	for i = #(controllers or ""), cidx, -1 do
		if IsValid(controllers[i]) then
			DoneObject(controllers[i])
		end
		controllers[i] = nil
	end
	
	if #(controllers or "") <= 0 then
		controllers = false
	end
	
	self.vfx_eaves_controllers = controllers
end

DefineClass.RoofFXController = {
	__parents = { "Object" },
	entity = "InvisibleObject",
	
	properties = {
		{id = "material", editor = "text", default = false },
		{id = "parent_obj", editor = "object", default = false },
		{id = "disabled", editor = "bool", default = false },
	},
	
	particles = false,
	playing = false,
}

--- Stops the RoofFXController and cleans up any associated resources.
function RoofFXController:Done()
	self:Stop()
end

--- Sets the visibility of the particles associated with this RoofFXController.
---
--- If the controller is currently playing, this function will set the visibility
--- of each particle in the `particles` table. If `val` is true, the particles
--- will be set to visible, otherwise they will be set to not visible.
---
--- @param val boolean Whether the particles should be visible or not.
function RoofFXController:SetVisibility(val)
	if self.playing then
		for i = 1, #(self.particles or "") do
			if val then
				self.particles[i]:SetEnumFlags(const.efVisible)
			else
				self.particles[i]:ClearEnumFlags(const.efVisible)
			end
		end
	end
end

--- Sets the disabled state of the RoofFXController.
---
--- If the controller is disabled, it will be stopped and no longer play any particles.
---
--- @param val boolean Whether the controller should be disabled or not.
function RoofFXController:SetDisabled(val)
	if val then
		self:Stop()
	end
	self.disabled = val
end

--- Initializes the RoofFXController from the given parent object.
---
--- This function sets the position and angle of the RoofFXController to match the
--- parent object, and also stores a reference to the parent object and the
--- material of the parent object's roof.
---
--- @param parent_obj Object The parent object to initialize the RoofFXController from.
function RoofFXController:InitFromParent(parent_obj)
	self:SetPos(parent_obj:GetPos())
	self:SetAngle(parent_obj:GetAngle())
	self.parent_obj = parent_obj
	self.material = parent_obj.roof_mat
end

--- Starts the RoofFXController and plays the associated particles.
---
--- This function checks if the RoofFXController is disabled or already playing. If not, it stops the "ClearSky" particle effect and starts the "RainHeavy" particle effect. It then sets the `playing` flag to true.
---
--- @function RoofFXController:Play
--- @return nil
function RoofFXController:Play()
	if self.disabled then return end
	if self.playing then return end
	PlayFX("ClearSky", "end", self, self.material)
	PlayFX("RainHeavy", "start", self, self.material)
	self.playing = true
end

--- Stops the RoofFXController and cleans up any associated particles.
---
--- This function checks if the RoofFXController is currently playing. If so, it stops the "RainHeavy" particle effect, starts the "ClearSky" particle effect, destroys any existing particles, and sets the `playing` flag to false.
---
--- @function RoofFXController:Stop
--- @return nil
function RoofFXController:Stop()
	if not self.playing then return end
	PlayFX("RainHeavy", "end", self, self.material)
	PlayFX("ClearSky", "start", self, self.material)
	
	DoneObjects(self.particles)
	self.particles = false
	self.playing = false
end

DefineClass.RoofEavesSegment = {
	__parents = { "RoofFXController" },
	properties = {
		{id = "vertex1", editor = "point", default = false },
		{id = "vertex2", editor = "point", default = false },
		{id = "angle", editor = "number", default = false },
	},
}

--- Debugging function for the RoofEavesSegment class.
---
--- This function is used for debugging purposes. It adds three debug vectors to the scene:
--- 1. The vertex1 position
--- 2. The vertex2 position
--- 3. A vector representing the distance between vertex1 and vertex2
---
--- @function RoofEavesSegment:Dbg
--- @return nil
function RoofEavesSegment:Dbg()
	local v1 = self.vertex1
	local v2 = self.vertex2
	
	DbgAddVector(v1)
	DbgAddVector(v2)
	DbgAddVector(v1, v2 - v1)
end

--- Starts the RoofEavesSegment particle effect.
---
--- This function checks if the RoofEavesSegment is currently disabled or playing. If not, it calls the `Play()` function of the parent `RoofFXController` class. It then calculates the distance between the `vertex1` and `vertex2` properties, and the angle between the `vertex2` - `vertex1` vector and the `point(4096, 0, 0)` vector. If the angle is negative, it adds 360 * 60 to it. Finally, it places a "Rain_Pouring_Dyn" particle effect at the `vertex1` position, sets its angle to the calculated angle, and sets the "width" parameter of the particle to the distance between `vertex1` and `vertex2`. The particle is added to the `self.particles` table.
function RoofEavesSegment:Play()
	if self.disabled then return end
	if self.playing then return end
	RoofFXController.Play(self)
	
	local d = self.vertex1:Dist2D(self.vertex2)
	local angle = CalcSignedAngleBetween2D(point(4096, 0, 0), self.vertex2 - self.vertex1)
	if angle < 0 then
		angle = 360 * 60 + angle
	end
	
	local par = PlaceParticles("Rain_Pouring_Dyn")
	par:SetPos(self.vertex1)
	par:SetAngle(angle)
	par:SetParam("width", d)

	self.particles = self.particles or {}
	table.insert(self.particles, par)
end

DefineClass.RoofSurface = {
	__parents = { "RoofFXController" },
	properties = {
		{id = "vertex1", editor = "point", default = false },
		{id = "vertex2", editor = "point", default = false },
		{id = "vertex3", editor = "point", default = false },
		{id = "angle", editor = "number", default = false },
	},
}

function RoofSurface:GetOffset()
	if self.material == "Tin" then
		return 74 --boxmaxz - originz
	elseif self.material == "Tiles" then
		return 129 
	elseif self.material == "Concrete" then
		return 190
	end
	return 0
end

--- Sets the vertex positions for the RoofSurface object.
---
--- This function takes three points (v1, v2, v3) that define the vertices of the roof surface. It calculates the minimum and maximum x and y coordinates of these vertices, and then adjusts the z-coordinate of each vertex based on the roof height offset for the material type. The adjusted vertex positions are then stored in the `vertex1`, `vertex2`, and `vertex3` properties of the RoofSurface object.
---
--- @param v1 point The first vertex position.
--- @param v2 point The second vertex position.
--- @param v3 point The third vertex position.
function RoofSurface:SetVertexes(v1, v2, v3)
	local parent_obj = self.parent_obj
	assert(parent_obj)
	
	--different material pieces have different heights
	local hoff = self:GetOffset()
	--GetRoofZAndDir doesn't always work on the extreme edges..
	local minx = Min(v1:x(), v2:x(), v3:x()) + 1
	local maxx = Max(v1:x(), v2:x(), v3:x()) - 1
	local miny = Min(v1:y(), v2:y(), v3:y()) + 1
	local maxy = Max(v1:y(), v2:y(), v3:y()) - 1

	v1 = point(minx, maxy, 0)
	v2 = point(maxx, maxy, 0)
	v3 = point(minx, miny, 0)
	
	v1 = v1:SetZ(parent_obj:GetRoofZAndDir(v1) + hoff)
	v2 = v2:SetZ(parent_obj:GetRoofZAndDir(v2) + hoff)
	v3 = v3:SetZ(parent_obj:GetRoofZAndDir(v3) + hoff)

	self.vertex1 = v1
	self.vertex2 = v2
	self.vertex3 = v3

	--[[DbgAddVector(self.vertex1)
	DbgAddVector(self.vertex2)
	DbgAddVector(self.vertex3)]]
end


--- Plays the roof effect for the RoofSurface object.
---
--- This function creates a particle effect for the roof surface, placing it at the first vertex position (`vertex1`) and orienting it based on the angle between the first and second vertices (`vertex1` and `vertex2`). The particle effect is scaled based on the size of the roof surface.
---
--- @param self RoofSurface The RoofSurface object to play the effect for.
function RoofSurface:Play()
	RoofFXController.Play(self)
	
	local v1 = self.vertex1
	local v2 = self.vertex2
	local v3 = self.vertex3
	
	local xmax = v2:Dist(v1)
	local ymax = v3:Dist(v1)
	assert(ymax < 1000000 and ymax > 0)
	local angle = CalcSignedAngleBetween2D(point(4096, 0, 0), v2 - v1)
	if angle < 0 then
		angle = 360 * 60 + angle
	end

	local par = PlaceParticles("Splashes_Raindrop_Dyn")
	par:SetPos(v1)
	par:SetAngle(angle)
	par:SetParam("area", MulDivRound(xmax, ymax, 1000))
	par:SetParam("width", xmax)
	par:SetParam("height", ymax)
	self.parent_obj:SnapObject(par)
	
	self.particles = self.particles or {}
	table.insert(self.particles, par)
end

--- Creates VFX controllers for all rooms on the map.
---
--- This function iterates over all "RoofFXController" objects on the map and calls the `DoneObject` function on them, likely to clean up or remove any existing controllers. It then iterates over all "Room" objects on the map and calls the `UpdateRoofVfxControllers` function on each one, which is likely responsible for creating new VFX controllers for the room's roof.
---
--- This function is likely called when the map is loaded or when some event triggers the need to update the roof VFX controllers for all rooms on the map.
function CreateVfxControllersForAllRoomsOnMap()
	MapForEach("map", "RoofFXController", DoneObject) --in case of old version ones existing
	MapForEach("map", "Room", RoomRoof.UpdateRoofVfxControllers)
end

--- Plays the roof effect for all RoofFXController objects on the map.
---
--- This function iterates over all "RoofFXController" objects on the map and calls the `Play()` function on each one, likely to start or resume the roof effect for each controller.
---
--- This function is likely called when the map is loaded or when some event triggers the need to start the roof effects for all rooms on the map.
function PlayRoofFX()
	MapForEach("map", "RoofFXController", function(o)
		o:Play()
	end)
end

--- Stops the roof effects for all RoofFXController objects on the map.
---
--- This function iterates over all "RoofFXController" objects on the map and calls the `Stop()` function on each one, likely to stop the roof effect for each controller.
---
--- This function is likely called when the map is unloaded or when some event triggers the need to stop the roof effects for all rooms on the map.
function StopRoofFX()
	MapForEach("map", "RoofFXController", function(o)
		o:Stop()
	end)
end