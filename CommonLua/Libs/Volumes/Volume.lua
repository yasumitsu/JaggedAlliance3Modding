NSEW_pairs = sorted_pairs -- todo: make an iterator that explicitly visits them in a predefined order
-- EnumVolumes([class, ] { box, | obj, | point, | x, y | x, y, z, }) - returns an array of the volumes interesecting the box/point
-- EnumVolumes(..., "smallest") - returns the smallest volume (by surface) interesecting the box/point
-- EnumVolumes(..., filter, ...) - returns an array with all volumes interesecting the box/point for which filter(volume, ...) returned true
local gofPermanent = const.gofPermanent

if FirstLoad then
	GedRoomEditor = false
	GedRoomEditorObjList = false
	g_RoomCornerTaskList = {}
	SelectedVolume = false
	VolumeCollisonEnabled = false
	HideFloorsAboveThisOne = false
	--moves wall slabs on load to their expected pos
	--it seems that lvl designers commonly misplace wall slabs which causes weird glitches, this should fix that
	RepositionWallSlabsOnLoad = Platform.developer or false
end

---
--- Returns a sorted list of all unique volume structures in the game.
---
--- @return table A table containing all unique volume structures.
function VolumeStructuresList()
	local list = {""}
	EnumVolumes(function (volume, list, find)
		if not find(list, volume.structure) then
			list[#list + 1] = volume.structure
		end
	end, list, table.find)
	table.sort(list)
	return list
end

-- the map is considered in bottom-right quadrant, which means that (0, 0) is north, west
local noneWallMat = const.SlabNoMaterial
local defaultWallMat = "default"

DefineClass.Volume = {
	__parents = { "RoomRoof", "StripObjectProperties", "AlignedObj", "ComponentAttach", "EditorVisibleObject" },
	flags = { gofPermanent = true, cofComponentVolume = true, efVisible = true },
	
	properties = {
		{ category = "Not Room Specific", id = "volumeCollisionEnabled",  name = "Toggle Global Volume Collision", default = true, editor = "bool", dont_save = true },
		{ category = "Not Room Specific", id = "buttons3", name = "Buttons", editor = "buttons", default = false, dont_save = true, read_only = true,
			buttons = {
				{name = "Recreate All Walls", func = "RecreateAllWallsOnMap"},
				{name = "Recreate All Roofs", func = "RecreateAllRoofsOnMap"},
				{name = "Recreate All Floors", func = "RecreateAllFloorsOnMap"},
			},
		},
		{ category = "General", id = "buttons2", name = "Buttons", editor = "buttons", default = false, dont_save = true, read_only = true,
			buttons = {
				{name = "Recreate Walls", func = "RecreateWalls"},
				{name = "Recreate Floor", func = "RecreateFloor"},
				{name = "Recreate Roof", func = "RecreateRoofBtn"},
				{name = "Re Randomize", func = "ReRandomize"},
				{name = "Copy Above", func = "CopyAbove"},
				{name = "Copy Below", func = "CopyBelow"},
			},
		},
		{ category = "General", id = "buttons2row2", name = "Buttons", editor = "buttons", default = false, dont_save = true, read_only = true,
			buttons = {
				{name = "Lock Subvariants", func = "LockAllSlabsToCurrentSubvariants"},
				{name = "Unlock Subvariants", func = "UnlockAllSlabs"},
				{name = "Make Slabs Vulnerable", func = "MakeOwnedSlabsVulnerable"},
				{name = "Make Slabs Invulnerable", func = "MakeOwnedSlabsInvulnerable"},
			},
		},
		
		{ category = "General", id = "box", name = "Box", editor = "box", default = false, no_edit = true },
		{ category = "General", id = "locked_slabs_count", name = "Locked Slabs Count", editor = "text", default = "", read_only = true, dont_save = true},
		{ category = "General", id = "wireframe_visible", name = "Wireframe Visible", editor = "bool", default = false,},
		{ category = "General", id = "wall_text_markers_visible", name = "Wall Text ID Visible", editor = "bool", default = false, dont_save = true},
		{ category = "General", id = "dont_use_interior_lighting", name = "No Interior Lighting", editor = "bool", default = false, },
		{ category = "General", id = "seed", name = "Random Seed", editor = "number", default = false},
		{ category = "General", id = "floor", name = "Floor", editor = "number", default = 1, min = -9, max = 99 },
		--bottom left corner of room in world coords
		{ category = "General", id = "position", name = "Position", editor = "point", default = false, no_edit = true, },
		{ category = "General", id = "size", name = "Size", editor = "point", default = point30, no_edit = true, },
		
		{ category = "General", id = "override_terrain_z", editor = "number", default = false, no_edit = true },
		{ category = "General", id = "structure", name = "Structure", editor = "combo", default = "", items = VolumeStructuresList },
		
		{ category = "Roof", id = "room_is_roof", name = "Room is Roof", editor = "bool", default = false, help = "Mark room as roof, roofs are hidden entirely (all walls, floors, etc.) when their floor is touched. Rooms that have zero height are considered roofs by default."},
	},
	
	wireframeColor = RGB(100, 100, 100),
	lines = false,
	
	adjacent_rooms = false, --{ ? }
	
	text_markers = false,
	
	last_wall_recreate_seed = false,
	building = false, --{ [floor] = {room, room, room} }
	
	being_placed = false,
	enable_collision = true, --with other rooms
	
	EditorView = Untranslated("<opt(u(structure),'',' - ')><u(name)>"),
	
	light_vol_obj = false,
	entity = "InvisibleObject",
	editor_force_excluded = true, -- exclude from Map editor palette (causes crash)
}

local voxelSizeX = const.SlabSizeX or 0
local voxelSizeY = const.SlabSizeY or 0
local voxelSizeZ = const.SlabSizeZ or 0
local halfVoxelSizeX = voxelSizeX / 2
local halfVoxelSizeY = voxelSizeY / 2
local halfVoxelSizeZ = voxelSizeZ / 2
local InvalidZ = const.InvalidZ
maxRoomVoxelSizeX = const.MaxRoomVoxelSizeX or 40
maxRoomVoxelSizeY = const.MaxRoomVoxelSizeY or 40
maxRoomVoxelSizeZ = const.MaxRoomVoxelSizeZ or 40
roomQueryRadius = Max((maxRoomVoxelSizeX + 1) * voxelSizeX, (maxRoomVoxelSizeY + 1) * voxelSizeY, (maxRoomVoxelSizeZ + 1) * voxelSizeZ)
defaultVolumeVoxelHeight = 4

local halfVoxelPtZeroZ = point(halfVoxelSizeX, halfVoxelSizeY, 0)
local halfVoxelPt = point(halfVoxelSizeX, halfVoxelSizeY, halfVoxelSizeZ)
---
--- Snaps a 3D position to the nearest voxel grid position, subtracting half a voxel size from the result.
---
--- @param pos table The 3D position to snap.
--- @return table The snapped 3D position.
function SnapVolumePos(pos)
	return SnapToVoxel(pos) - halfVoxelPtZeroZ
end

---
--- Rounds a 3D position to the nearest voxel grid position, adding half a voxel size to the result.
---
--- @param z number The Z coordinate to round.
--- @return number The rounded Z coordinate.
function snapZRound(z)
	z = (z + halfVoxelSizeZ) / voxelSizeZ
	return z * voxelSizeZ
end

---
--- Rounds a 3D position to the nearest voxel grid position, rounding up the Z coordinate.
---
--- @param z number The Z coordinate to round up.
--- @return number The rounded up Z coordinate.
function snapZCeil(z)
	z = DivCeil(z, voxelSizeZ)
	return z * voxelSizeZ
end

---
--- Rounds a 3D position to the nearest voxel grid position.
---
--- @param z number The Z coordinate to round.
--- @return number The rounded Z coordinate.
function snapZ(z)
	z = z / voxelSizeZ
	return z * voxelSizeZ
end

---
--- Returns "N/A" as the locked slabs count.
---
--- @return string The locked slabs count, which is "N/A".
function Volume:Getlocked_slabs_count()
	return "N/A"
end

---
--- Returns the current state of the volume collision enabled flag.
---
--- @return boolean Whether volume collision is enabled.
function Volume:GetvolumeCollisionEnabled()
	return VolumeCollisonEnabled
end

---
--- Sets whether the volume represents a roof-only room.
---
--- @param val boolean Whether the volume represents a roof-only room.
function Volume:Setroom_is_roof(val)
	if self.room_is_roof == val then return end
	self.room_is_roof = val
	ComputeSlabVisibilityInBox(self.box)
end

---
--- Checks if the volume represents a roof-only room.
---
--- @return boolean True if the volume represents a roof-only room, false otherwise.
function Volume:IsRoofOnly()
	return self.room_is_roof or self.size:z() == 0
end

---
--- Sets whether volume collision is enabled.
---
--- @param v boolean Whether volume collision is enabled.
function Volume:SetvolumeCollisionEnabled(v)
	VolumeCollisonEnabled = v
end

---
--- Initializes the volume object, including setting up text markers for the cardinal directions.
---
--- The text markers are placed as game objects and configured with the following properties:
--- - `hide_in_editor = false`: The text markers are visible in the editor.
--- - `SetText(k)`: The text is set to the key of the text marker (North, South, West, East).
--- - `SetColor(RGB(255, 0, 0))`: The text color is set to red.
--- - `SetGameFlags(const.gofDetailClass1)`: The text markers are set as detail class 1 objects.
--- - `ClearGameFlags(const.gofDetailClass0)`: The text markers are cleared from detail class 0.
---
--- The function also sets the visibility of the wall text markers based on the `wall_text_markers_visible` flag, copies the volume box to the CCD, and initializes the entity.
---
--- @function Volume:Init
function Volume:Init()
	--todo: if platform.somethingorother,
	self.text_markers = {
		North = PlaceObject("Text"),
		South = PlaceObject("Text"),
		West = PlaceObject("Text"),
		East = PlaceObject("Text"),
	}
	
	for k, v in pairs(self.text_markers) do
		v.hide_in_editor = false
		v:SetText(k)
		v:SetColor(RGB(255, 0, 0))
		v:SetGameFlags(const.gofDetailClass1)
		v:ClearGameFlags(const.gofDetailClass0)
	end
	
	self:SetPosMarkersVisible(self.wall_text_markers_visible)
	self:CopyBoxToCCD()
	self:InitEntity()
end

---
--- Initializes the entity associated with the volume.
---
--- If the editor is active, the entity is changed to a "RoomHelper" entity.
---
--- @function Volume:InitEntity
function Volume:InitEntity()
	if IsEditorActive() then
		self:ChangeEntity("RoomHelper")
	end
end

---
--- Called when the volume enters the editor.
--- This function changes the entity associated with the volume to a "RoomHelper" entity.
---
--- @function Volume:EditorEnter
function Volume:EditorEnter()
	--dont mess with visibility flags
	self:ChangeEntity("RoomHelper")
end

---
--- Called when the volume exits the editor.
--- This function changes the entity associated with the volume to an "InvisibleObject" entity.
---
--- @function Volume:EditorExit
function Volume:EditorExit()
	--dont mess with visibility flags
	self:ChangeEntity("InvisibleObject")
end

---
--- Sets whether the volume should use interior lighting.
---
--- If `val` is `true`, the volume will not use interior lighting.
--- If `val` is `false`, the volume will use interior lighting.
---
--- This function updates the interior lighting for the volume.
---
--- @param val boolean Whether to use interior lighting or not.
--- @function Volume:SetDontUseInteriorLighting
function Volume:Setdont_use_interior_lighting(val)
	self.dont_use_interior_lighting = val
	self:UpdateInteriorLighting()
end

---
--- Copies the volume's bounding box to the CCD (Collision Checking and Detection) system and updates the interior lighting.
---
--- This function is used to synchronize the volume's bounding box with the CCD system and ensure that the interior lighting is properly updated.
---
--- @function Volume:CopyBoxToCCD
function Volume:CopyBoxToCCD()
	local box = self.box
	if not box then return end
	SetVolumeBox(self, box)
	self:UpdateInteriorLighting()
end

---
--- Updates the interior lighting for the volume.
---
--- This function is responsible for managing the light volume object associated with the volume. It checks if the volume should use interior lighting, and if so, it creates or updates the light volume object to match the volume's bounding box. If the volume should not use interior lighting, the function removes the light volume object.
---
--- @function Volume:UpdateInteriorLighting
--- @return nil
function Volume:UpdateInteriorLighting()
	local box = self.box
	if not box then
		return
	end
	
	if self.dont_use_interior_lighting then
		DoneObject(self.light_vol_obj)
		self.light_vol_obj = nil
		return
	end
	
	local lo = self.light_vol_obj
	if not IsValid(lo) then
		lo = PlaceObject("ComponentLight")
		lo:SetLightType(const.eLightTypeClusterVolume)
		self.light_vol_obj = lo
	end
	
	if not self.dont_use_interior_lighting and self.floor_mat == noneWallMat and self.floor == 1 then
		lo:SetClusterVolumeBox(box:minx(), box:miny(), box:minz() - 100, box:maxx(), box:maxy(), box:maxz()) --this is here so vfx can properly catch ground below rooms
	else
		lo:SetClusterVolumeBox(box:minx(), box:miny(), box:minz(), box:maxx(), box:maxy(), box:maxz())
	end
	lo:SetVolumeId(self.handle)
	lo:SetPos(self:GetPos())
end

---
--- Calculates the Z coordinate of the volume based on its position, floor, and terrain.
---
--- If the volume is being placed, the Z coordinate is calculated based on the terrain height at the volume's position, snapped to the nearest voxel.
---
--- If the volume's Z coordinate is not set, it is calculated based on the terrain height, the volume's floor, and any Z offset.
---
--- @function Volume:CalcZ
--- @return number The calculated Z coordinate of the volume.
function Volume:CalcZ()
	local posZ = self.position:z()
	
	if self.being_placed then
		local z = self.override_terrain_z or terrain.GetHeight(self.position)
		posZ = snapZ(z + voxelSizeZ / 2)
		self.position = self.position:SetZ(posZ)
	end
	
	if posZ == nil then
		--save compat
		local z = self.override_terrain_z or terrain.GetHeight(self.position)
		z = snapZ(z + voxelSizeZ / 2)
		posZ = (rawget(self, "z_offset") or 0) * voxelSizeZ + z + (self.floor - 1) * self.size:z() * voxelSizeZ
		self.position = self.position:SetZ(posZ)
	end

	return posZ
end

---
--- Locks the volume's Z coordinate to the current terrain height at the volume's position.
---
--- This function can be used to ensure that the volume's Z coordinate is aligned with the terrain, which is useful when the volume is being placed or moved.
---
--- @function Volume:LockToCurrentTerrainZ
--- @return number The current terrain height at the volume's position.
function Volume:LockToCurrentTerrainZ()
	self.override_terrain_z = terrain.GetHeight(self.position)
	return self.override_terrain_z
end

---
--- Calculates the snapped Z coordinate of the volume based on its position, floor, and terrain.
---
--- The calculated Z coordinate is snapped to the nearest voxel.
---
--- @function Volume:CalcSnappedZ
--- @return number The snapped Z coordinate of the volume.
function Volume:CalcSnappedZ()
	local z = self:CalcZ()
	z = z / voxelSizeZ
	z = z * voxelSizeZ
	return z
end

---
--- Calculates the floor number from the given Z coordinate, room height, and ground level.
---
--- @param z number The Z coordinate to calculate the floor number from.
--- @param roomHeight number The height of each floor.
--- @param ground_level number The ground level.
--- @return number The floor number.
function FloorFromZ(z, roomHeight, ground_level)
	return (z - ground_level) / (roomHeight * voxelSizeZ) + 1
end

---
--- Calculates the Z coordinate of a volume based on its floor number, room height, and ground level.
---
--- This function makes assumptions about the floor size and is essentially a helper for `Volume:CalcZ()`.
---
--- @param f number The floor number.
--- @param roomHeight number The height of each floor.
--- @param ground_level number The ground level.
--- @return number The calculated Z coordinate of the volume.
function ZFromFloor(f, roomHeight, ground_level) --essentialy calcz but makes assumptions about floor size
	return ground_level + (f - 1) * (roomHeight * voxelSizeZ)
end

---
--- Moves the volume to the specified position.
---
--- The bottom left corner of the voxel at the specified position will be the new position of the volume.
---
--- @param pos point The new position to move the volume to.
function Volume:Move(pos)
	--bottom left corner of the voxel at pos will be the new positon
	self.position = SnapVolumePos(pos)
	self:AlignObj()
end

---
--- Changes the floor number of the volume.
---
--- If the new floor number is the same as the current floor number, this function does nothing.
---
--- @param newFloor number The new floor number to set for the volume.
function Volume:ChangeFloor(newFloor)
	if self.floor == newFloor then
		return
	end
	
	self.floor = newFloor
	self:AlignObj()
end

---
--- Sets the size of the volume.
---
--- If the new size is the same as the current size, this function does nothing.
---
--- @param newSize point The new size to set for the volume.
function Volume:SetSize(newSize)
	if self.size == newSize then
		return
	end
	
	self.size = newSize
	self:AlignObj()
end

---
--- Aligns the volume to the specified position and angle.
---
--- If a position is provided, the volume will be moved to that position. The bottom left corner of the voxel at the specified position will be the new position of the volume.
---
--- @param pos point The new position to move the volume to.
--- @param angle number The new angle to rotate the volume to.
function Volume:AlignObj(pos, angle)
	if pos then
		local v = pos - self:GetPos()
		self.position = SnapVolumePos(self.position + v)
	end
	self:InternalAlignObj()
end

---
--- Aligns the volume to the specified position and angle.
---
--- This function is an internal implementation detail and should not be called directly.
---
--- @param test boolean (optional) If true, this function will not perform any actual alignment, but will only return the new position.
--- @return point The new position of the volume after alignment.
---
function Volume:InternalAlignObj(test)
	local w, h, d = self.size:x() * voxelSizeX, self.size:y() * voxelSizeY, self.size:z() * voxelSizeZ
	local cx, cy = w / 2, h / 2
	local z = self:CalcZ()
	local pos = point(self.position:x() + cx, self.position:y() + cy, z)
	local p = self.position
	local newBox = box(p:x(), p:y(), z, p:x() + w, p:y() + h, z + d)
	if not test and self:GetPos() == pos and self.box == newBox then return p end --nothing to align
	self:SetPos(pos)
	self:SetAngle(0)
	self.box = newBox
	if not test then
		self:FinishAlign()
	end
	return p
end

---
--- Returns the opposite side of the given side.
---
--- @param side string The side to get the opposite of. Can be "North", "South", "West", or "East".
--- @return string The opposite side.
---
function GetOppositeSide(side)
	if side == "North" then return "South"
	elseif side == "South" then return "North"
	elseif side == "West" then return "East"
	elseif side == "East" then return "West" 
	end
end

local function GetOppositeCorner(c)
	if c == "NW" then return "SE"
	elseif c == "NE" then return "SW"
	elseif c == "SW" then return "NE"
	elseif c == "SE" then return "NW"
	end
end

local function SetAdjacentRoom(adjacent_rooms, room, data)
	if not adjacent_rooms then
		return
	end
	if data then
		if not adjacent_rooms[room] then
			adjacent_rooms[#adjacent_rooms + 1] = room
		end
		adjacent_rooms[room] = data
		return data
	end
	data = adjacent_rooms[room]
	if data then
		adjacent_rooms[room] = nil
		table.remove_value(adjacent_rooms, room)
		return data
	end
end

---
--- Clears the adjacency data for the current volume.
---
--- This function removes the current volume from the adjacent_rooms tables of any volumes it was previously adjacent to.
--- It also notifies those adjacent volumes that the adjacency has changed, so they can update their own data accordingly.
---
--- @param self The current volume object.
---
function Volume:ClearAdjacencyData()
	local adjacent_rooms = self.adjacent_rooms
	self.adjacent_rooms = nil
	
	for _, room in ipairs(adjacent_rooms or empty_table) do
		local hisData = SetAdjacentRoom(room.adjacent_rooms, self, false)
		if hisData then
			local hisAW = hisData[2]
			for i = 1, #(hisAW or empty_table) do
				room:OnAdjacencyChanged(hisAW[i])
			end
		end
	end
end


local AdjacencyEvents = {}
---
--- Rebuilds the adjacency data for the current volume.
---
--- This function is responsible for determining which volumes are adjacent to the current volume, and updating the adjacency data accordingly.
--- It does this by iterating through all permanent volumes in the vicinity of the current volume, and checking for intersections between the volumes' bounding boxes.
--- When an intersection is found, the function determines the type of adjacency (e.g. north, south, east, west, floor, roof) and updates the adjacency data for both the current volume and the adjacent volume.
---
--- The function also handles the case where an adjacency is removed, by removing the current volume from the adjacent_rooms table of the previously adjacent volume.
---
--- The function is designed to be called within an undo operation, to ensure that any changes to the adjacency data are properly captured by the undo system.
---
--- @param self The current volume object.
---
function Volume:RebuildAdjacencyData()
	-- must be called inside an undo op, otherwise delayed updating may cause changes not captured by undo
	assert(XEditorUndo:AssertOpCapture())
	
	local adjacent_rooms = self.adjacent_rooms
	local new_adjacent_rooms = {}
	local mb = self.box
	local events = {}
	--DbgAddBox(mb)
	local is_permanent = self:GetGameFlags(gofPermanent) ~= 0
	local gameFlags = is_permanent and gofPermanent or nil
	MapForEach(self, roomQueryRadius, self.class, nil, nil, gameFlags, function(o, mb, is_permanent)
		if o == self or not is_permanent and o:GetGameFlags(gofPermanent) ~= 0 then
			return
		end
		
		--TODO: use +roof box for sides, -roof box for ceiling/floor
		local hb = o.box
		--DbgAddBox(hb, RGB(0, 255, 0))
		local ib = IntersectRects(hb, mb)
		--DbgAddBox(ib, RGB(255, 0, 0))
		if not ib:IsValid() then
			return
		end
		local myData = adjacent_rooms and adjacent_rooms[o]
		local oldIb = myData and myData[1]
		
		local myNewData = {}
		local hisData = o.adjacent_rooms and o.adjacent_rooms[self]
		local hisNewData = {}
		
		--restore previously affected walls
		local myaw = myData and myData[2]
		local hisaw = hisData and hisData[2]
		for i = 1, #(myaw or empty_table) do
			table.insert(events, {self, myaw[i]})
		end
		for i = 1, #(hisaw or empty_table) do
			table.insert(events, {o, hisaw[i]})
		end
		
		hisNewData[1] = ib
		myNewData[1] = ib
		hisNewData[2] = {}
		myNewData[2] = {}
		
		if ib:sizez() > 0 then
			if ib:minx() == ib:maxx() and ib:miny() == ib:maxy() then
				--corner adj, rebuild corner
				local p = ib:min()
				if p:x() == mb:minx() then --west
					if p:y() == mb:miny() then --north
						table.insert(events, {self, "NW"})
						table.insert(hisNewData[2], "SE")
						table.insert(myNewData[2], "NW")
					else
						table.insert(events, {self, "SW"})
						table.insert(hisNewData[2], "NE")
						table.insert(myNewData[2], "SW")
					end
				else --east
					if p:y() == mb:miny() then
						table.insert(events, {self, "NE"})
						table.insert(hisNewData[2], "SW")
						table.insert(myNewData[2], "NE")
					else
						table.insert(events, {self, "SE"})
						table.insert(hisNewData[2], "NW")
						table.insert(myNewData[2], "SE")
					end
				end
			elseif ib:minx() == ib:maxx()
					and ib:miny() ~= ib:maxy() then
				--east/west adjacency
				if mb:maxx() == ib:maxx() then
					--my east, his west
					table.insert(events, {self, "East"})
					table.insert(events, {o, "West"})
					table.insert(hisNewData[2], "West")
					table.insert(myNewData[2], "East")
				else
					--my west, his east
					table.insert(events, {self, "West"})
					table.insert(events, {o, "East"})
					table.insert(hisNewData[2], "East")
					table.insert(myNewData[2], "West")
				end
			elseif ib:minx() ~= ib:maxx()
					and ib:miny() == ib:maxy() then
				--nort/south adjacency
				if mb:maxy() == ib:maxy() then
					--my north, his south
					table.insert(events, {self, "South"})
					table.insert(events, {o, "North"})
					table.insert(hisNewData[2], "North")
					table.insert(myNewData[2], "South")
				else
					--my south, his north
					table.insert(events, {self, "North"})
					table.insert(events, {o, "South"})
					table.insert(hisNewData[2], "South")
					table.insert(myNewData[2], "North")
				end
			else
				--rooms intersect
				if (ib:maxx() == mb:maxx() or ib:minx() == mb:maxx())
						and mb:maxx() == hb:maxx() then
					--east
					table.insert(events, {self, "East"})
					table.insert(myNewData[2], "East")
					table.insert(hisNewData[2], "East")
				end
				
				if (ib:minx() == mb:minx() or ib:maxx() == mb:minx())
					and mb:minx() == hb:minx() then
					--west
					table.insert(events, {self, "West"})
					table.insert(myNewData[2], "West")
					table.insert(hisNewData[2], "West")
				end
				
				if (ib:maxy() == mb:maxy() or ib:miny() == mb:maxy())
					and mb:maxy() == hb:maxy() then
					--south
					table.insert(events, {self, "South"})
					table.insert(myNewData[2], "South")
					table.insert(hisNewData[2], "South")
				end
				
				if ib:maxy() == mb:miny() or ib:miny() == mb:miny() 
					and mb:miny() == hb:miny() then
					--north
					table.insert(events, {self, "North"})
					table.insert(myNewData[2], "North")
					table.insert(hisNewData[2], "North")
				end
			end
		end
		
		
		if ib:sizex() > 0 and ib:sizey() > 0 then
			if (mb:minz() >= ib:minz() and  mb:minz() <= ib:maxz()) or
				(hb:maxz() >= ib:minz() and hb:maxz() <= ib:maxz()) then
				--floor
				table.insert(events, {self, "Floor"})
				table.insert(myNewData[2], "Floor")
				table.insert(hisNewData[2], "Roof")
			end
			
			if (mb:maxz() <= ib:maxz() and mb:maxz() >= ib:minz()) or
				(hb:minz() <= ib:maxz() and hb:minz() >= ib:minz()) then
				--roof
				table.insert(events, {self, "Roof"})
				table.insert(myNewData[2], "Roof")
				table.insert(hisNewData[2], "Floor")
			end
		end
		
		SetAdjacentRoom(o.adjacent_rooms, self, #hisNewData[2] > 0 and hisNewData)
		SetAdjacentRoom(new_adjacent_rooms, o, #myNewData[2] > 0 and myNewData)
	end, mb, is_permanent)
	
	for _, room in ipairs(adjacent_rooms or empty_table) do
		if not new_adjacent_rooms[room] then
			--adjacency removed
			local data = adjacent_rooms[room]
			local myaw = data[2]
			local hisData = SetAdjacentRoom(room.adjacent_rooms, self, false)
			local hisaw = hisData and hisData[2]
			for i = 1, #(myaw or empty_table) do
				table.insert(events, {self, myaw[i]})
			end
			for i = 1, #(hisaw or empty_table) do
				table.insert(events, {room, hisaw[i]})
			end
		end
	end
	
	self.adjacent_rooms = new_adjacent_rooms
	
	if IsChangingMap() or XEditorUndo.undoredo_in_progress then
		return
	end
	
	if #(events or empty_table) > 0 then
		table.insert(AdjacencyEvents, events)
		Wakeup(PeriodicRepeatThreads["AdjacencyEvents"])
	end
end

---
--- Processes volume adjacency events.
--- This function is responsible for handling changes in the adjacency of volumes in the game world.
--- It iterates through a list of adjacency events, and for each event, it calls the `OnAdjacencyChanged` method on the affected volume object.
--- The function ensures that each event is only processed once, even if the same volume is affected by multiple events.
---
--- @param none
--- @return none
---
function ProcessVolumeAdjacencyEvents()
	local passed = {}
	for i = 1, #AdjacencyEvents do
		local events = AdjacencyEvents[i]
		for i = 1, #(events or empty_table) do
			local ev = events[i]
			local o = ev[1]
			local s = ev[2]
			if IsValid(o) and (not passed[o] or (passed[o] and not passed[o][s])) then
				passed[o] = passed[o] or {}
				passed[o][s] = true
				--print(o.name, s)
				o:OnAdjacencyChanged(s)
			end
		end
	end
	table.clear(AdjacencyEvents)
end

-- make sure all changes to rooms are completed before we finish capturing undo data
OnMsg.EditorObjectOperationEnding = ProcessVolumeAdjacencyEvents

MapGameTimeRepeat("AdjacencyEvents", -1, function(sleep)
	PauseInfiniteLoopDetection("AdjacencyEvents")
	ProcessVolumeAdjacencyEvents()
	ResumeInfiniteLoopDetection("AdjacencyEvents")
	WaitWakeup()
end)

local dirToWallMatMember = {
	North = "north_wall_mat",
	South = "south_wall_mat",
	West = "west_wall_mat",
	East = "east_wall_mat",
	Floor = "floor_mat",
}

local sideToFuncName = {
	NW = "RecreateNWCornerBeam",
	NE = "RecreateNECornerBeam",
	SW = "RecreateSWCornerBeam",
	SE = "RecreateSECornerBeam",
}

--- Checks the sizes of the spawned walls for the volume.
---
--- This function is an implementation detail and is not part of the public API.
--- It is only executed when the game is in developer mode.
---
--- The function asserts that the number of west and east walls are equal, and
--- that the number of north and south walls are equal. This is a sanity check
--- to ensure the volume's wall configuration is consistent.
---
--- @param self Volume The volume object.
function Volume:CheckWallSizes()
	if not Platform.developer then return end
	local t = self.spawned_walls
	assert(#t.West == #t.East)
	assert(#t.North == #t.South)
end

--- Handles changes in the adjacency of the volume.
---
--- This function is called when the adjacency of the volume changes, such as when a wall or floor is added or removed. It updates the volume's appearance and geometry accordingly.
---
--- @param self Volume The volume object.
--- @param side string The side of the volume that changed, such as "North", "South", "West", "East", "Floor", or "Roof".
function Volume:OnAdjacencyChanged(side)
	if #side == 2 then
		self[sideToFuncName[side]](self)
	elseif side == "Floor" then
		self:CreateFloor(self.floor_mat)
	elseif side == "Roof" then
		if not self.being_placed then
			self:UpdateRoofSlabVisibility()
		end
	else
		self:CreateWalls(side, self[dirToWallMatMember[side]])
		self:CheckWallSizes()
	end
	
	self:DelayedRecalcRoof()
end

if FirstLoad then
	SelectedRooms = false
	RoomSelectionMode = false
end

--- Sets the room selection mode.
---
--- When room selection mode is enabled, clicking on a slab will select the room that slab belongs to.
---
--- @param bVal boolean True to enable room selection mode, false to disable.
function SetRoomSelectionMode(bVal)
	RoomSelectionMode = bVal
	print(string.format("RoomSelectionMode is %s", RoomSelectionMode and "ON" or "OFF"))
end

--- Toggles the room selection mode.
---
--- When room selection mode is enabled, clicking on a slab will select the room that slab belongs to.
function ToggleRoomSelectionMode()
	SetRoomSelectionMode(not RoomSelectionMode)
end

if FirstLoad then
	roomsToDeselect = false
end

local function selectRoomHelper(r, t)
	t = t or SelectedRooms
	t = t or {}
	r:SetPosMarkersVisible(true)
	table.insert(t, r)
	if roomsToDeselect then
		table.remove_entry(roomsToDeselect, r)
	end
end

local function deselectRoomHelper(r)
	if IsValid(r) then
		r:SetPosMarkersVisible(false)
		r:ClearSelectedWall()
	end
end

local function deselectRooms()
	for i = 1, #(roomsToDeselect or "") do
		deselectRoomHelper(roomsToDeselect[i])
	end
	roomsToDeselect = false
end

function OnMsg.EditorSelectionChanged(objects)
	--room selection
	if RoomSelectionMode then
		--if 1 slab is selected?
		local o = #objects == 1 and objects[1]
		if o and IsKindOf(o, "Slab") and IsValid(o.room) then
			editor.ClearSel()
			editor.AddToSel({o.room})
			return --don't do further analysis this pass
		end
	end
	--selected rooms
	local newSelectedRooms = {}
	
	for i = 1, #objects do
		local o = objects[i]
		if IsKindOf(o, "Slab") then
			local r = o.room
			if IsValid(r) then
				selectRoomHelper(r, newSelectedRooms)
			end
		elseif IsKindOf(o, "Room") then
			selectRoomHelper(o, newSelectedRooms)
		end
	end
	
	for i = 1, #(SelectedRooms or "") do
		local r = SelectedRooms[i]
		if not table.find(newSelectedRooms, r) then
			--deselect
			roomsToDeselect = roomsToDeselect or {}
			table.insert(roomsToDeselect, r)
			DelayedCall(0, deselectRooms)
		end
	end
	
	SelectedRooms = #newSelectedRooms > 0 and newSelectedRooms or false
end

--- Toggles the visibility of the position markers for the Volume object.
---
--- This function checks the current visibility state of the North position marker,
--- and then sets the visibility of all position markers (North, South, West, East)
--- to the opposite state. This allows the user to easily show or hide all the
--- position markers for the Volume.
---
--- @param self Volume The Volume object instance.
function Volume:TogglePosMarkersVisible()
	local el = self.text_markers.North
	self:SetPosMarkersVisible(el:GetEnumFlags(const.efVisible) == 0)
end

--- Sets the visibility of the position markers for the Volume object.
---
--- This function sets the visibility of all position markers (North, South, West, East)
--- for the Volume object to the specified value. If `val` is `false`, the position
--- markers will be hidden. If `val` is `true`, the position markers will be shown.
---
--- @param self Volume The Volume object instance.
--- @param val boolean The new visibility state for the position markers.
function Volume:SetPosMarkersVisible(val)
	for k, v in pairs(self.text_markers) do
		if not val then
			v:ClearEnumFlags(const.efVisible)
		else
			v:SetEnumFlags(const.efVisible)
		end
	end
end

--- Positions the text markers for the walls of the Volume object.
---
--- This function calculates the positions of the North, South, West, and East
--- text markers based on the size and position of the Volume object. The text
--- markers are then set to the calculated positions.
---
--- @param self Volume The Volume object instance.
function Volume:PositionWallTextMarkers()
	local t = self.text_markers
	local gz = self:CalcZ() + self.size:z() * voxelSizeZ / 2
	local p = self.position + point(self.size:x() * voxelSizeX / 2, 0)
	p = p:SetZ(gz)
	t.North:SetPos(p)
	p = self.position + point(self.size:x() * voxelSizeX / 2, self.size:y() * voxelSizeY)
	p = p:SetZ(gz)
	t.South:SetPos(p)
	p = self.position + point(0, self.size:y() * voxelSizeY / 2)
	p = p:SetZ(gz)
	t.West:SetPos(p)
	p = self.position + point(self.size:x() * voxelSizeX, self.size:y() * voxelSizeY / 2)
	p = p:SetZ(gz)
	t.East:SetPos(p)
end

--- Finishes the alignment process for a Volume object.
---
--- This function is called after a Volume object has been aligned. It performs the following tasks:
---
--- 1. If the `seed` property is not set, it generates a new seed value using the `EncodeVoxelPos` function.
--- 2. Copies the Volume's box to the CCD (Continuous Collision Detection) system.
--- 3. Rebuilds the adjacency data for the Volume.
--- 4. If the `wireframe_visible` property is true, it generates the Volume's geometry. Otherwise, it cleans up the lines.
--- 5. Positions the wall text markers for the Volume.
--- 6. Updates the `box_at_last_roof_edit` property with the current box.
--- 7. If the map is not currently being changed, it refreshes the floor combat status.
--- 8. Sends a "RoomAligned" message for the Volume.
---
--- @param self Volume The Volume object instance.
function Volume:FinishAlign()
	if not self.seed then
		self.seed = EncodeVoxelPos(self)
	end
	
	self:CopyBoxToCCD()
	self:RebuildAdjacencyData()
	if self.wireframe_visible then
		self:GenerateGeometry()
	else
		self:DoneLines()
	end
	self:PositionWallTextMarkers()
	self.box_at_last_roof_edit = self.box
	
	if not IsChangingMap() then
		self:RefreshFloorCombatStatus()
	end
	
	Msg("RoomAligned", self)
end

--- Refreshes the floor combat status for the Volume object.
---
--- This function is called to update the combat status of the floor associated with the Volume object. It is typically used to ensure the floor combat status is up-to-date after changes have been made to the Volume.
---
--- @param self Volume The Volume object instance.
function Volume:RefreshFloorCombatStatus()
end

--- Sets the floor associated with the Volume object.
---
--- This function is used to set the floor property of the Volume object. It also calls the `RefreshFloorCombatStatus()` function to update the combat status of the floor.
---
--- @param self Volume The Volume object instance.
--- @param v any The new floor value to set.
function Volume:Setfloor(v)
	self.floor = v
	self:RefreshFloorCombatStatus()
end

--- Destroys the Volume object and cleans up its associated resources.
---
--- This function is responsible for cleaning up the Volume object and its associated resources when the Volume is no longer needed. It performs the following tasks:
--- - Calls the `DoneLines()` function to clean up any lines associated with the Volume.
--- - Calls the `DoneObject()` function to destroy the `light_vol_obj` object.
--- - Calls the `DoneObjects()` function to destroy the `light_vol_objs` objects.
--- - Sets the `light_vol_obj` and `light_vol_objs` properties to `nil`.
--- - Iterates through the `text_markers` table and calls the `DoneObject()` function to destroy each text marker object.
--- - Sets the `VolumeDestructor` function to an empty function to prevent further destruction.
---
--- @param self Volume The Volume object instance.
function Volume:VolumeDestructor()
	self:DoneLines()
	DoneObject(self.light_vol_obj)
	DoneObjects(self.light_vol_objs)
	self.light_vol_obj = nil
	self.light_vol_objs = nil
	for k, v in pairs(self.text_markers) do
		DoneObject(v)
	end
	self["VolumeDestructor"] = empty_func
end

--- Destroys the Volume object and cleans up its associated resources.
---
--- This function is responsible for cleaning up the Volume object and its associated resources when the Volume is no longer needed. It calls the `VolumeDestructor()` function to perform the necessary cleanup tasks.
function Volume:Done()
	self:VolumeDestructor()
end

--- Toggles the global `VolumeCollisonEnabled` flag, which controls whether volume collision detection is enabled.
---
--- This function is typically called from an external source to enable or disable volume collision detection. When `VolumeCollisonEnabled` is `true`, the `Volume:CheckCollision()` function will perform collision checks. When `VolumeCollisonEnabled` is `false`, the `Volume:CheckCollision()` function will always return `false`.
---
--- @param _ any Unused parameter, as this function is typically called as a callback.
--- @param self Volume The Volume object instance, which is also unused in this function.
function Volume.ToggleVolumeCollision(_, self)
	VolumeCollisonEnabled = not VolumeCollisonEnabled
end

---
--- Checks for collisions between the current Volume object and other Volume objects in the map.
---
--- This function checks if the current Volume object is colliding with any other Volume objects in the map. It first checks if volume collision detection is enabled (`VolumeCollisonEnabled`) and if the current Volume object has collision enabled (`enable_collision`). If either of these conditions is false, the function returns `false`.
---
--- The function then iterates through all other Volume objects in the map within a certain radius (`roomQueryRadius`) of the current Volume object's position. For each Volume object, it checks if the bounding boxes (`box`) of the two Volume objects intersect. If an intersection is found, the function returns `true` to indicate a collision.
---
--- @param self Volume The Volume object instance.
--- @param cls string The class of the Volume objects to check for collision.
--- @param box table The bounding box to use for collision detection.
--- @return boolean True if the Volume object is colliding with another Volume object, false otherwise.
function Volume:CheckCollision(cls, box)
	if not VolumeCollisonEnabled then return false end
	if not self.enable_collision then return false end
	cls = cls or self.class
	local ret = false
	box = box or self.box
	MapForEach(self:GetPos(), roomQueryRadius, cls, function(o)
		if o ~= self and o.enable_collision then
			if box:Intersect(o.box) ~= 0 then
				ret = true
				return "break"
			end
		end
	end, box)
	
	return ret
end

local dontCopyTheeseProps = {
	name = true,
	floor = true,
	adjacent_rooms = true,
	box = true,
	position = true,
	roof_objs = true,
	spawned_doors = true,
	spawned_windows = true,
	spawned_decals = true,
	spawned_walls = true,
	spawned_corners = true,
	spawned_floors = true,
	text_markers = true,
}

---
--- Recreates the walls for all Volume objects on the map.
---
--- This function iterates through all Volume objects on the map and calls the `RecreateWalls()` function on each one. This effectively recreates the walls for all Volume objects in the map.
---
--- @param self Volume The Volume object instance.
function Volume:RecreateAllWallsOnMap()
	MapForEach("map", "Volume", Volume.RecreateWalls)
end

---
--- Recreates the roofs for all Volume objects on the map.
---
--- This function iterates through all Volume objects on the map, sorted by their floor value, and calls the `RecreateRoof()` function on each one. This effectively recreates the roofs for all Volume objects in the map.
---
--- @param self Volume The Volume object instance.
function Volume:RecreateAllRoofsOnMap()
	local all_volumes = MapGet("map", "Volume")
	table.sortby_field(all_volumes, "floor")
	for i,volume in ipairs(all_volumes) do
		volume:RecreateRoof()
	end
end

---
--- Recreates the floors for all Volume objects on the map.
---
--- This function iterates through all Volume objects on the map and calls the `RecreateFloor()` function on each one. This effectively recreates the floors for all Volume objects in the map.
---
--- @param self Volume The Volume object instance.
function Volume:RecreateAllFloorsOnMap()
	MapForEach("map", "Volume", Volume.RecreateFloor)
end

---
--- Recreates the walls for the Volume object.
---
--- This function deletes all existing wall and corner objects, then recreates them. It also updates the outer and inner colors of the walls.
---
--- @param self Volume The Volume object instance.
function Volume:RecreateWalls()
	SuspendPassEdits("Volume:RecreateWalls")
	self:DeleteAllWallObjs()
	self:DeleteAllCornerObjs()
	self:CreateAllWalls()
	self:CreateAllCorners()
	self:OnSetouter_colors(self.outer_colors)
	self:OnSetinner_colors(self.inner_colors)
	ResumePassEdits("Volume:RecreateWalls")
end

---
--- Recreates the floors for the Volume object.
---
--- This function deletes all existing floor objects, then recreates them. It also updates the floor colors.
---
--- @param self Volume The Volume object instance.
function Volume:RecreateFloor()
	SuspendPassEdits("Volume:RecreateFloor")
	self:DeleteAllFloors()
	self:CreateFloor()
	self:OnSetfloor_colors(self.floor_colors)
	ResumePassEdits("Volume:RecreateFloor")
end

---
--- Recreates the roof for the Volume object.
---
--- This function is a wrapper around the `RecreateRoof()` function, which is responsible for recreating the roof for the Volume object.
---
--- @param self Volume The Volume object instance.
function Volume:RecreateRoofBtn()
	self:RecreateRoof()
end

---
--- Re-randomizes the seed used for generating the walls of the Volume object.
---
--- This function updates the `seed` property of the Volume object with a new random value generated using `BraidRandom()`. It then calls `CreateAllWalls()` to recreate the walls using the new seed, and updates the `last_wall_recreate_seed` property to the new seed value. Finally, it marks the Volume object as modified using `ObjModified()`.
---
--- @param self Volume The Volume object instance.
function Volume:ReRandomize()
	self.last_wall_recreate_seed = self.seed
	self.seed = BraidRandom(self.seed)
	self:CreateAllWalls()
	self.last_wall_recreate_seed = self.seed
	ObjModified(self)
end

---
--- Copies the Volume object and places it above the current Volume.
---
--- This function creates a new Volume object that is a copy of the current Volume, and places it one floor above the current Volume. It uses the `Copy()` function to create the new Volume, passing in a floor offset of 1 to place it above the current Volume. The new Volume is then set as the selected Volume using `SetSelectedVolume()`.
---
--- @param self Volume The Volume object instance.
function Volume:CopyAbove()
	XEditorUndo:BeginOp()
	local nv = self:Copy(1)
	SetSelectedVolume(nv)
	XEditorUndo:EndOp{ nv }
end

---
--- Copies the Volume object and places it below the current Volume.
---
--- This function creates a new Volume object that is a copy of the current Volume, and places it one floor below the current Volume. It uses the `Copy()` function to create the new Volume, passing in a floor offset of -1 to place it below the current Volume. The new Volume is then set as the selected Volume using `SetSelectedVolume()`.
---
--- @param self Volume The Volume object instance.
function Volume:CopyBelow()
	XEditorUndo:BeginOp()
	local nv = self:Copy(-1)
	SetSelectedVolume(nv)
	XEditorUndo:EndOp{ nv }
end

---
--- Checks for collisions between the Volume object and other Volume objects on the next floor.
---
--- This function checks if the Volume object would collide with any other Volume objects on the next floor, based on the provided `floorOffset` parameter. It first checks if volume collision is enabled and if the Volume object has collision enabled. It then calculates the bounding box of the Volume object on the next floor and checks for intersections with other Volume objects. If a collision is detected, the function returns `true`, otherwise it returns `false`.
---
--- @param self Volume The Volume object instance.
--- @param floorOffset number The floor offset to check for collisions.
--- @return boolean Whether a collision was detected.
function Volume:CollisionCheckNextFloor(floorOffset)
	if not VolumeCollisonEnabled then return false end
	if not self.enable_collision then return false end
	local b = self.box
	local offset = point(0, 0, voxelSizeZ * self.size:z() * floorOffset)
	b = Offset(b, offset)
	local collision = false	
	MapForEach(self:GetPos(), roomQueryRadius, self.class, function(o)
		if o ~= self and o.enable_collision then
			if b:Intersect(o.box) ~= 0 then
				collision = true
				return "break"
			end
		end
	end)
	return collision
end

---
--- Creates a copy of the current Volume object and places it at the specified floor offset.
---
--- This function creates a new Volume object that is a copy of the current Volume, and places it at the specified floor offset. It uses the `PlaceObject()` function to create the new Volume, and copies the properties from the current Volume to the new one. The new Volume is then returned.
---
--- @param self Volume The Volume object instance.
--- @param floorOffset number The floor offset to place the new Volume at.
--- @param inputObj table (optional) A table of properties to override in the new Volume.
--- @param skipCollisionTest boolean (optional) Whether to skip the collision check.
--- @return Volume The new Volume object.
function Volume:Copy(floorOffset, inputObj, skipCollisionTest)
	local offset = point(0, 0, voxelSizeZ * self.size:z() * floorOffset)
	local collision = false
	if not skipCollisionTest then
		collision = self:CollisionCheckNextFloor(floorOffset)
	end
	
	if skipCollisionTest or not collision then
		inputObj = inputObj or {}
		inputObj.floor = inputObj.floor or self.floor + floorOffset
		inputObj.position = inputObj.position or self.position + offset
		inputObj.size = inputObj.size or self.size
		inputObj.name = inputObj.name or self.name .. " Copy"
		local doNotCopyTheseEither = table.copy(inputObj)
		
		local cpy = PlaceObject(self.class, inputObj)
		local prps = self:GetProperties()
		for i = 1, #prps do
			local prop = prps[i]
			if not dontCopyTheeseProps[prop.id] and not doNotCopyTheseEither[prop.id] then
				cpy:SetProperty(prop.id, self:GetProperty(prop.id))
			end
		end
		cpy:OnCopied(self, offset)
		DelayedCall(500, BuildBuildingsData)
		return cpy
	end
end

---
--- Aligns the copied Volume object to the original.
---
--- This function is called when a Volume object is copied using the `Volume:Copy()` function. It aligns the copied Volume object to the original Volume object, ensuring that the copied object is properly positioned and oriented.
---
--- @param self Volume The Volume object instance.
--- @param from Volume The original Volume object that was copied.
---
function Volume:OnCopied(from)
	self:AlignObj()
end

---
--- Toggles the visibility of the geometry associated with the Volume object.
---
--- This function is used to toggle the visibility of the geometry (lines) that represent the Volume object. If the geometry has not been generated yet, this function will call `Volume:GenerateGeometry()` to create it. If the geometry already exists, this function will toggle the visibility of the lines, making them visible or invisible.
---
--- @param self Volume The Volume object instance.
---
function Volume:ToggleGeometryVisible()
	if self.lines == false then
		self:GenerateGeometry()
		return
	end
	if self.lines and self.lines[1] then
		local visible = self.lines[1]:GetEnumFlags(const.efVisible) == 0
		for i = 1, #(self.lines or empty_table) do
			if visible then
				self.lines[i]:SetEnumFlags(const.efVisible)
			else
				self.lines[i]:ClearEnumFlags(const.efVisible)
			end
		end
	end
end

---
--- Cleans up the lines associated with the Volume object.
---
--- This function is used to clean up the lines that represent the geometry of the Volume object. It calls `DoneObjects()` to dispose of the lines, and then sets the `lines` property to `false` to indicate that the geometry has been cleared.
---
--- @param self Volume The Volume object instance.
---
function Volume:DoneLines()
	DoneObjects(self.lines)
	self.lines = false
end

---
--- Gets the wall box for the specified side of a room box.
---
--- This function returns a box that represents the wall for the specified side of a room box. The room box can be provided as an argument, or the Volume object's own box will be used if no room box is provided.
---
--- @param self Volume The Volume object instance.
--- @param side string The side of the room box to get the wall box for. Can be "North", "South", "East", or "West".
--- @param roomBox box The room box to use. If not provided, the Volume object's own box will be used.
--- @return box The wall box for the specified side.
function Volume:GetWallBox(side, roomBox)
	local ret = false
	local b = roomBox or self.box
	if side == "North" then
		ret = box(b:minx(), b:miny(), b:minz(), b:maxx(), b:miny() + 1, b:maxz())
	elseif side == "South" then
		ret = box(b:minx(), b:maxy() - 1, b:minz(), b:maxx(), b:maxy(), b:maxz())
	elseif side == "East" then
		ret = box(b:maxx() - 1, b:miny(), b:minz(), b:maxx(), b:maxy(), b:maxz())
	elseif side == "West" then
		ret = box(b:minx(), b:miny(), b:minz(), b:minx() + 1, b:maxy(), b:maxz())
	end
	
	return ret
end

local function SetLineMesh(line, line_pstr)
	if not line_pstr or line_pstr:size() == 0 then return end
	line:SetMesh(line_pstr)
	return line
end

local offsetFromVoxelEdge = 20
---
--- Generates the geometry for the Volume object.
---
--- This function is responsible for generating the geometry that represents the Volume object. It creates a series of polylines that form the wireframe of the Volume, and attaches them to the Volume object. The geometry is generated based on the size and position of the Volume, and can be made visible or invisible as needed.
---
--- @param self Volume The Volume object instance.
function Volume:GenerateGeometry()
	self:DoneLines()
	
	local lines = {}
	local xPoints = {}
	local xPointsRoof = {}
	local yPoints = {}
	local yPointsRoof = {}
	
	local zOrigin = self:CalcSnappedZ()
	local p = self.position
	local x, y = p:xyz()
	local sx = abs(self.size:x())
	local sy = abs(self.size:y())
	local sz = abs(self.size:z())
	
	for inX = 0, sx - 1 do
		for inY = 0, sy - 1 do
			xPoints[inY] = xPoints[inY] or pstr("")
			yPoints[inX] = yPoints[inX] or pstr("")
			
			xPointsRoof[inY] = xPointsRoof[inY] or pstr("")
			yPointsRoof[inX] = yPointsRoof[inX] or pstr("")
			
			local xx, yy, zz, ox, oy, oz
			
			xx = x + inX * voxelSizeX + halfVoxelSizeX
			if inX == 0 then
				ox = xx - halfVoxelSizeX + offsetFromVoxelEdge
			elseif inX == sx - 1 then
				ox = xx + halfVoxelSizeX - offsetFromVoxelEdge
			else
				ox = xx
			end
			
			yy = y + inY * voxelSizeY + halfVoxelSizeY
			if inY == 0 then
				oy = yy - halfVoxelSizeY + offsetFromVoxelEdge
			elseif inY == sy - 1 then
				oy = yy + halfVoxelSizeY - offsetFromVoxelEdge
			else
				oy = yy
			end
			
			zz = zOrigin + offsetFromVoxelEdge
			oz = zz + sz * voxelSizeZ - offsetFromVoxelEdge*2
			
			if inX == 0 then
				--wall
				xPoints[inY]:AppendVertex(ox, yy, oz, self.wireframeColor)
			end
			xPoints[inY]:AppendVertex(ox, yy, zz, self.wireframeColor)
			if sx == 1 then
				xPointsRoof[inY]:AppendVertex(ox, yy, oz, self.wireframeColor)
				ox = xx + halfVoxelSizeX - offsetFromVoxelEdge
				xPoints[inY]:AppendVertex(ox, yy, zz, self.wireframeColor)
			end
			if inX == sx - 1 then
				--wall
				xPoints[inY]:AppendVertex(ox, yy, oz, self.wireframeColor)
			end
			
			if inY == 0 then
				--wall
				yPoints[inX]:AppendVertex(xx, oy, oz, self.wireframeColor)
			end
			yPoints[inX]:AppendVertex(xx, oy, zz, self.wireframeColor)
			if sy == 1 then
				yPointsRoof[inX]:AppendVertex(xx, oy, oz, self.wireframeColor)
				oy = yy + halfVoxelSizeY - offsetFromVoxelEdge
				yPoints[inX]:AppendVertex(xx, oy, zz, self.wireframeColor)
			end
			if inY == sy - 1 then
				--wall
				yPoints[inX]:AppendVertex(xx, oy, oz, self.wireframeColor)
			end
			
			xPointsRoof[inY]:AppendVertex(ox, yy, oz, self.wireframeColor)
			yPointsRoof[inX]:AppendVertex(xx, oy, oz, self.wireframeColor)
		end
	end
	
	local visible = self.wireframe_visible
	local function SetVisibilityHelper(line)
		if not visible then
			line:ClearEnumFlags(const.efVisible)
		end
	end
	
	for inX = 0, sx - 1 do
		local line = PlaceObject("Polyline")
		SetVisibilityHelper(line)
		line:SetPos(p)
		SetLineMesh(line, yPoints[inX])
		table.insert(lines, line)
		self:Attach(line)
		line = PlaceObject("Polyline")
		SetVisibilityHelper(line)
		line:SetPos(p)
		SetLineMesh(line, yPointsRoof[inX])
		table.insert(lines, line)
		self:Attach(line)
	end
	
	for inY = 0, sy - 1 do
		local line = PlaceObject("Polyline")
		SetVisibilityHelper(line)
		line:SetPos(p)
		SetLineMesh(line, xPoints[inY])
		table.insert(lines, line)
		self:Attach(line)
		line = PlaceObject("Polyline")
		SetVisibilityHelper(line)
		line:SetPos(p)
		SetLineMesh(line, xPointsRoof[inY])
		table.insert(lines, line)
		self:Attach(line)
	end
	
	self.lines = lines
end

---
--- Returns the biggest encompassing room within the volume.
---
--- This function presumes that there are no wall crossings between rooms.
---
--- @param func function (optional) A function to filter the rooms. The function should return true if the room should be considered.
--- @param ... any Arguments to pass to the filter function.
--- @return table The biggest encompassing room.
function Volume:GetBiggestEncompassingRoom(func, ...)
	--this presumes no wall crossing
	local biggestRoom = self
	if self.box then
		local sizex, sizey = self.box:sizexyz()
		local biggestRoomSize = sizex + sizey
		EnumVolumes(self.box, function(o, ...)
			local szx, szy = o.box:sizexyz()
			local size = szx + szy
			if size > biggestRoomSize then
				if not func or func(o, ...) then
					biggestRoom = o
					biggestRoomSize = size
				end
			end
		end, ...)
	end
	return biggestRoom
end

local function MakeSlabInvulnerable(o, val)
	o.forceInvulnerableBecauseOfGameRules = val
	o.invulnerable = val
	SetupObjInvulnerabilityColorMarkingOnValueChanged(o)
end

---
--- Makes all owned slabs of the volume invulnerable.
---
--- This function iterates through all spawned objects in the volume and makes them invulnerable. If the object is a `SlabWallObject`, it also makes all of its owned slabs invulnerable.
---
--- @param self Volume The volume instance.
function Volume:MakeOwnedSlabsInvulnerable()
	self:ForEachSpawnedObj(function(o)
		MakeSlabInvulnerable(o, true)
		if IsKindOf(o, "SlabWallObject") then
			local os = o.owned_slabs
			if os then
				for _, oo in ipairs(os) do
					MakeSlabInvulnerable(oo, true)
				end
			end
		end
	end)
end

---
--- Makes all owned slabs of the volume vulnerable.
---
--- This function iterates through all spawned objects in the volume and makes them vulnerable. If the object is a `SlabWallObject`, it also makes all of its owned slabs vulnerable.
---
--- @param self Volume The volume instance.
function Volume:MakeOwnedSlabsVulnerable()
	local floorsInvul = self.floor == 1
	self:ForEachSpawnedObj(function(o)
		if not floorsInvul or not IsKindOf(o, "FloorSlab") then
			MakeSlabInvulnerable(o, false)
			if IsKindOf(o, "SlabWallObject") then
				local os = o.owned_slabs
				if os then
					for _, oo in ipairs(os) do
						MakeSlabInvulnerable(oo, false)
					end
				end
			end
		end
	end)
end

---
--- Prevents the volume from being destroyed when the user presses Shift+D in the F3 menu.
---
function Volume:Destroy()
	--so shift + d in f3 doesn't kill these
end

---
--- Shows or hides volumes on the map based on the specified criteria.
---
--- @param bShow boolean Whether to show or hide the volumes.
--- @param volume_class string The class of volumes to show or hide.
--- @param max_floor number The maximum floor level to show volumes for.
--- @param fn function An optional function to call for each visible volume.
---
function ShowVolumes(bShow, volume_class, max_floor, fn)
	MapClearEnumFlags(const.efVisible, "map", "Volume")
	if not bShow or not volume_class then return end
	MapSetEnumFlags(const.efVisible, "map", volume_class, function(volume, max_floor, fn)
		if volume.floor <= max_floor then
			fn(volume)
			return true
		end
	end, max_floor or max_int, fn or empty_func)
end

---
--- Selects a volume on the map based on the given screen coordinates.
---
--- This function takes a screen coordinate point, converts it to a game coordinate, and then uses that to find the closest visible volume on the map. It takes into account the current camera position and floor, as well as any floors that should be hidden.
---
--- @param pt Vector2 The screen coordinate point to select a volume from.
--- @return Volume|false The selected volume, or false if no volume was found.
--- @return Vector3 The game coordinate point where the volume was selected.
--- @return Vector3 The end point of the ray used to select the volume.
function SelectVolume(pt) -- in screen coordinates, terminal.GetMousePos()
	-- enumerate all visible volumes on the map and select the one under the mouse point pt
	local start = ScreenToGame(pt)
	local pos = cameraRTS.GetPos()
	local dir = start - pos
	dir = dir * 1000
	local dir2 = start + dir
	local camFloor = cameraTac.GetFloor() + 1

	--DbgAddCircle(start, 100)
	--DbgAddVector(start, pos - start)  
	--DbgAddVector(start, dir*1000, RGB(0, 255, 0))

	return MapFindMin("map", "Volume", nil, nil, nil, nil, nil, nil, function(volume, dir2, camFloor)
		if HideFloorsAboveThisOne then
			if volume.floor > HideFloorsAboveThisOne then
				return false
			end
		end
		--return distance to intersection between the camera ray and volume box
		local p1, p2 = ClipSegmentWithBox3D(start, dir2, volume.box)
		if p1 then
			--DbgAddCircle(p1, 100)
			--DbgAddCircle(p2, 100, RGB(0, 0, 255))
			return p1:Dist2(start)
		end
		
		return false
	end, start, dir2, camFloor) or false, start, dir2
end

local lastSelectedVolume = false
local function SetSelectedVolumeAndFireEvents(vol)
	if vol ~= SelectedVolume then
		local oldVolume = SelectedVolume
		SelectedVolume = vol
		if oldVolume then
			lastSelectedVolume = oldVolume
			if IsValid(oldVolume) then
				oldVolume.wall_text_markers_visible = false
				oldVolume:SetPosMarkersVisible(false)
			end
			Msg("VolumeDeselected", oldVolume)
		end
		if SelectedVolume then
			if SelectedVolume ~= lastSelectedVolume then --only deselect wall if another vol is selected
				SelectedVolume.selected_wall = false
				ObjModified(SelectedVolume)
			end
			
			SelectedVolume.wall_text_markers_visible = true
			SelectedVolume:SetPosMarkersVisible(true)
			editor.ClearSel()
		end
		Msg("VolumeSelected", SelectedVolume)
	end
end

---
--- Sets the currently selected volume and fires relevant events.
---
--- @param vol table The volume to set as the selected volume.
---
function SetSelectedVolume(vol)
	SetSelectedVolumeAndFireEvents(vol)
	if GedRoomEditor then
		GedRoomEditorObjList = GedRoomEditor:ResolveObj("root")
		CreateRealTimeThread(function()
			GedRoomEditor:SetSelection("root", table.find(GedRoomEditorObjList, SelectedVolume))
		end)
	end
end

local doorId = "Door"
local windowId = "Window"
local doorTemplate = "%s_%s"
local Doors_WidthNames = { "Single", "Double" }
local Windows_WidthNames = { "Single", "Double", "Triple" }

---
--- Generates a dropdown list of door options based on the configured door widths.
---
--- @return table A table of dropdown options, where each option is a table with `name` and `id` fields.
---
function DoorsDropdown()
	return function()
		local ret = { {name = "", id = ""} }
		
		for j = 1, #Doors_WidthNames do
			local name = string.format(doorTemplate, doorId, Doors_WidthNames[j])
			local data = {mat = false, width = j, height = 3}
			table.insert(ret, {name = name, id = data})
		end
		
		return ret
	end
end

---
--- Generates a dropdown list of window options based on the configured window widths.
---
--- @return table A table of dropdown options, where each option is a table with `name` and `id` fields.
---
function WindowsDropdown()
	return function()
		local ret = { {name = "", id = ""} }
		
		for j = 1, #Windows_WidthNames do
			local name = string.format(doorTemplate, windowId, Windows_WidthNames[j])
			local data = {mat = false, width = j, height = 2}
			table.insert(ret, {name = name, id = data})
		end
		
		return ret
	end
end

---
--- Returns the default room decal preset data.
---
--- @return table The default room decal preset data.
---
function GetDecalPresetData()
	return Presets.RoomDecalData.Default
end

---
--- Generates a dropdown list of decal options based on the default room decal preset data.
---
--- @return table A table of dropdown options, where each option is a table with `name` and `id` fields.
---
function DecalsDropdown()
	return function()
		local ret = { {name = "", id = ""} }
		local presetData = GetDecalPresetData()
		for _, entry in ipairs(presetData) do
			local data = { entity = entry.id, }
			table.insert(ret, {name = entry.id, id = data})
		end
		return ret
	end
end

local function GetAllWindowEntitiesForMaterial(obj)
	local material = type(obj) == "string" and obj or obj.linked_obj and obj.linked_obj.material or obj.material
	local ret = { false }
	for w = 0, 3 do
		for h = 1, 3 do
			for v = 1, 10 do
				local e = SlabWallObjectName(material, h, w, v, false)
				if IsValidEntity(e) then
					ret[#ret + 1] = { name = e, value = {entity = e, height = h, width = w, subvariant = v, material = material} }
				end
			end
		end
	end
	
	return ret
end

local function GetAllDoorEntitiesForMaterial(obj)
	local material = type(obj) == "string" and obj or obj.linked_obj and obj.linked_obj.material or obj.material
	local ret = { false }
	for w = 1, 3 do
		for h = 3, 4 do
			for v = 1, 10 do
				local e = SlabWallObjectName(material, h, w, v, true)
				if IsValidEntity(e) then
					ret[#ret + 1] = { name = e, value = {entity = e, height = h, width = w, subvariant = v, material = material} }
				end
				
				if v == 1 then
					e = SlabWallObjectName(material, h, w, nil, true)
					if IsValidEntity(e) then
						ret[#ret + 1] = { name = e, value = {entity = e, height = h, width = w, subvariant = v, material = material} }
					end
				end
			end
		end
	end
	
	return ret
end

local function SelectedWallNoEdit(self)
	return self.selected_wall == false
end

slabDirToAngle = {
	North = 270 * 60,
	South = 90 * 60,
	West = 180 * 60,
	East = 0,
}

slabAngleToDir = {
	[270 * 60] = "North",
	[90 * 60] = "South",
	[180 * 60] = "West",
	[0] = "East",
}

slabCornerAngleToDir = {
	[270 * 60] = "East",
	[90 * 60] = "West",
	[180 * 60] = "North",
	[0] = "South",
}

--- Calls the `RoomVisibilityCategoryNoEdit()` function and returns its result.
---
--- This function is likely an implementation detail or helper function, and is not part of the public API.
function _RoomVisibilityCategoryNoEdit()
	return RoomVisibilityCategoryNoEdit()
end

--- Calls the `RoomVisibilityCategoryNoEdit()` function and returns its result.
---
--- This function is likely an implementation detail or helper function, and is not part of the public API.
function RoomVisibilityCategoryNoEdit()
	return true
end

local VisibilityStateItems = {
	"Closed",
	"Hidden",
	"Open"
}

--- Returns a combo box list of slab materials, including a "None" option.
---
--- This function is likely an implementation detail or helper function, and is not part of the public API.
function SlabMaterialComboItemsWithNone()
	return PresetGroupCombo("SlabPreset", "SlabMaterials", nil, noneWallMat)
end

--- Returns a combo box list of slab materials, excluding the "None" option.
---
--- This function is likely an implementation detail or helper function, and is not part of the public API.
function SlabMaterialComboItemsOnly()
	return function()
		local f1 = SlabMaterialComboItemsWithNone()
		local ret = f1()
		table.remove(ret, 1)
		return ret
	end
end

--- Returns a combo box list of slab materials, including the default wall material.
---
--- This function is likely an implementation detail or helper function, and is not part of the public API.
function SlabMaterialComboItemsWithDefault()
	return function() 
		local f1 = SlabMaterialComboItemsWithNone()
		local ret = f1()
		table.insert(ret, 2, defaultWallMat)
		return ret
	end
end

DefineClass.Room = {
	__parents = { "Volume", "EditorSubVariantObject" },
	flags = { gofWarped = true },
	
	properties = {
		{ category = "General", name = "Doors And Windows Are Blocked", id = "doors_windows_blocked", editor = "bool", default = false, },
		{ category = "General", id = "name", name = "Name", editor = "text", default = false, help = "Default 'Room <handle>', renameable." },
		
		{ category = "General", id = "size_z", name = "Height (z)", editor = "number", default = defaultVolumeVoxelHeight, min = 0, max = maxRoomVoxelSizeZ, dont_save = true},
		{ category = "General", id = "size_x", name = "Width (x)", editor = "number", default = 1, min = 1, max = maxRoomVoxelSizeX, dont_save = true},
		{ category = "General", id = "size_y", name = "Depth (y)", editor = "number", default = 1, min = 1, max = maxRoomVoxelSizeY, dont_save = true},
		{ category = "General", id = "move_x", name = "Move EW (x)", editor = "number", default = 0, dont_save = true},
		{ category = "General", id = "move_y", name = "Move NS (y)", editor = "number", default = 0, dont_save = true},
		{ category = "General", id = "move_z", name = "Move UD (z)", editor = "number", default = 0, dont_save = true},
		--materials
		{ category = "Materials", id = "wall_mat", name = "Wall Material", editor = "preset_id", preset_class = "SlabPreset", preset_group = "SlabMaterials", extra_item = noneWallMat, default = "Planks",
			buttons = {
				{name = "Reset", func = "ResetWallMaterials"}, 
			},
		},
		{ category = "Materials", id = "outer_colors", name = "Outer Color Modifier", editor = "nested_obj", base_class = "ColorizationPropSet", inclusive = true, default = false, },
		{ category = "Materials", id = "inner_wall_mat", name = "Inner Wall Material", editor = "preset_id", preset_class = "SlabIndoorMaterials", extra_item = noneWallMat, default = "Planks", },
		
		{ category = "Materials", id = "inner_colors", name = "Inner Color Modifier", editor = "nested_obj", base_class = "ColorizationPropSet", inclusive = true, default = false, },
		{ category = "Materials", id = "north_wall_mat", name = "North Wall Material", editor = "dropdownlist", items = SlabMaterialComboItemsWithDefault, default = defaultWallMat,
			buttons = { 
				{name = "Select", func = "ViewNorthWallFromOutside"},
			}
		},		
		{ category = "Materials", id = "south_wall_mat", name = "South Wall Material", editor = "dropdownlist", items = SlabMaterialComboItemsWithDefault, default = defaultWallMat, 
			buttons = { 
				{name =  "Select", func = "ViewSouthWallFromOutside"},
			} 
		},
		{ category = "Materials", id = "east_wall_mat", name = "East Wall Material", editor = "dropdownlist", items = SlabMaterialComboItemsWithDefault, default = defaultWallMat, 
			buttons = { 
				{name =  "Select", func = "ViewEastWallFromOutside"},
			}
		},
		{ category = "Materials", id = "west_wall_mat", name = "West Wall Material", editor = "dropdownlist", items = SlabMaterialComboItemsWithDefault, default = defaultWallMat,
			buttons = { 
				{name =  "Select", func = "ViewWestWallFromOutside"},
			}
		},
		{ category = "Materials", id = "floor_mat", name = "Floor Material", editor = "preset_id", preset_class = "SlabPreset", preset_group = "FloorSlabMaterials", extra_item = noneWallMat, default = "Planks", },
		{ category = "Materials", id = "floor_colors", name = "Floor Color Modifier", editor = "nested_obj", base_class = "ColorizationPropSet", inclusive = true, default = false, },
		{ category = "Materials", id = "Warped", name = "Warped", editor = "bool", default = true },
		
		{ category = "Materials", id = "selected_wall_buttons", name = "selected wall buttons", editor = "buttons", default = false, dont_save = true, read_only = true,
			no_edit = SelectedWallNoEdit,
			buttons = {
				{name = "Clear Wall Selection", func = "ClearSelectedWall"},
				{name = "Delete Doors", func = "UIDeleteDoors"},
				{name = "Delete Windows", func = "UIDeleteWindows"},
			},
		},
		
		{ category = "Materials", id = "place_decal", name = "Place Decal", editor = "choice", items = DecalsDropdown, default = "", no_edit = SelectedWallNoEdit,},
		
		{ category = "General", id = "spawned_doors", editor = "objects", no_edit = true,},
		{ category = "General", id = "spawned_windows", editor = "objects", no_edit = true,},
		{ category = "General", id = "spawned_decals", editor = "objects", no_edit = true,}, --todo: kill
		
		{ category = "General", id = "spawned_floors", editor = "objects", no_edit = true},
		{ category = "General", id = "spawned_walls", editor = "objects", no_edit = true,},
		{ category = "General", id = "spawned_corners", editor = "objects", no_edit = true,},
		
		{ category = "Not Room Specific", id = "hide_floors_editor", editor = "number", default = 100, name = "Hide Floors Above", dont_save = true},
		
		--bacon specific?
		{ category = "Visibility", name = "Visibility State", id = "visibility_state", editor = "choice", items = VisibilityStateItems, dont_save = true, no_edit = _RoomVisibilityCategoryNoEdit },
		{ category = "Visibility", name = "Focused", id = "is_focused", editor = "bool", default = false, dont_save = true, no_edit = _RoomVisibilityCategoryNoEdit },
		
		{ category = "Ignore None Material", name = "Wall", id = "none_wall_mat_does_not_affect_nbrs", editor = "bool", default = false, help = "By default, setting a wall material to none will hide overlapping walls, tick this for it to stop happening. Affects all walls of a room." },
		{ category = "Ignore None Material", name = "Roof Wall", id = "none_roof_wall_mat_does_not_affect_nbrs", editor = "bool", default = false, help = "Same as walls (see above), but for walls that are part of the roof - roof walls." },
		{ category = "Ignore None Material", name = "Floor", id = "none_floor_mat_does_not_affect_nbrs", editor = "bool", default = false, help = "By default, setting a floor material to none will hide overlapping floors, tick this for it to stop happening. Affects all floors of a room." },
	},
	
	auto_add_in_editor = true, -- for Room editor
	
	spawned_walls = false, -- {["North"] = {}, etc.}
	spawned_corners = false,
	spawned_floors = false,
	spawned_doors = false,
	spawned_windows = false,
	spawned_decals = false,
	
	selected_wall = false, -- false, "North", "South", etc.
	
	next_visibility_state = false,
	visibility_state = false, -- when defined purely as a prop, something strips it.
	open_state_collapsed_walls = false,
	outside_border = false,
	nametag = false,
}

local function moveHelper(self, key, old_v, x, y, z, ignore_collision)
	if IsChangingMap() then return end
	self:InternalAlignObj(true) -- this moves box
	if not ignore_collision and self:CheckCollision() then
		self[key] = old_v
		self:InternalAlignObj(true)
		print("Could not move room due to collision with other room!")
		return false
	else
		self:MoveAllSpawnedObjs(x, y, z)
		Volume.FinishAlign(self)
		Msg("RoomMoved", self, x, y, z) -- x, y, z - move delta in voxels
		return true
	end
end

--- Returns the sign of a number.
---
--- If the number is positive, this function returns 1. If the number is negative, this function returns -1. If the number is 0, this function returns 0.
---
--- @param v number The number to get the sign of.
--- @return number The sign of the number.
function sign(v)
	return v ~= 0 and abs(v) / v or 0
end

--- Moves a room by the given delta vector, ensuring that the move does not cause a collision with other rooms.
---
--- @param r Room The room to move.
--- @param delta Vector The delta vector to move the room by.
--- @return boolean True if the room was successfully moved, false otherwise.
function moveHelperHelper(r, delta)
	local old = r.position
	delta = delta + halfVoxelPt
	r.position = SnapVolumePos(old + delta)
	return moveHelper(r, "position", old, delta:x() / voxelSizeX, delta:y() / voxelSizeY, delta:z() / voxelSizeZ)
end

--- Called when the editor is exited. Hides the nametag of the room if it is valid.
function Room:EditorExit()
	if IsValid(self.nametag) then
		self.nametag:ClearEnumFlags(const.efVisible)
	end
end

--- Called when the editor is entered. Sets the nametag of the room to be visible if the room is visible.
function Room:EditorEnter()
	if IsValid(self.nametag) and self:GetEnumFlags(const.efVisible) ~= 0 then
		self.nametag:SetEnumFlags(const.efVisible)
	end
end

--- Sets the name of the room and updates the nametag associated with the room.
---
--- If the room does not have a nametag yet, a new `TextEditor` object is created and attached to the room. The nametag is positioned above the room and its text is set to the room's name.
---
--- If the room is not visible in the editor or the editor is not active, the nametag is hidden.
---
--- @param n string The new name for the room.
function Room:SetName(n)
	-- implementation details
end
function Room:Setname(n)
	self.name = n
	if not IsValid(self.nametag) then
		self.nametag = PlaceObject("TextEditor")
		self:Attach(self.nametag)
		self.nametag:SetAttachOffset((axis_z * 3 * voxelSizeZ) / 4096)
		
		if not IsEditorActive() or self:GetEnumFlags(const.efVisible) == 0 then
			self.nametag:ClearEnumFlags(const.efVisible)
		end
	end
	self.nametag:SetText(self.name)
end

local movedRooms = false
--- Recalculates the roofs of all rooms that have been moved.
---
--- This function is called when an editor operation is ending, to ensure that all roof recalculations are completed before the undo data is captured.
---
--- It iterates through the `movedRooms` table, which contains a list of rooms that have been moved. For each valid room in the table, it calls the `RecalcRoof()` and `UpdateRoofVfxControllers()` methods to update the room's roof.
---
--- After processing all the moved rooms, the `movedRooms` table is reset to `false`.
function Room_RecalcRoofsOfMovedRooms()
	if not movedRooms then return end
	for i = 1, #movedRooms do
		local room = movedRooms[i]
		if IsValid(room) then
			room:RecalcRoof()
			room:UpdateRoofVfxControllers()
		end
	end
	movedRooms = false
end

--- Schedules a delayed recalculation of the roof for the current room.
---
--- This function is called when the room has been moved, to ensure that the roof is properly recalculated after the move is complete.
---
--- If the "Roofs" category is filtered in the editor, and an undo/redo operation is not in progress, this function will schedule a call to `Room_RecalcRoofsOfMovedRooms()` after a 200 millisecond delay.
---
--- The room is added to the `movedRooms` table, which is used by `Room_RecalcRoofsOfMovedRooms()` to identify which rooms need their roofs recalculated.
---
--- @param self Room The room object for which the roof should be recalculated.
function Room:DelayedRecalcRoof()
	movedRooms = table.create_add_unique(movedRooms, self)
	if LocalStorage.FilteredCategories["Roofs"] and not XEditorUndo.undoredo_in_progress then
		DelayedCall(200, Room_RecalcRoofsOfMovedRooms)
	end
end

-- make sure all changes to roofs are completed before we finish capturing undo data
OnMsg.EditorObjectOperationEnding = Room_RecalcRoofsOfMovedRooms

--- Aligns an object (the room) to a given position and angle.
---
--- If a position is provided, the function checks if the room needs to be moved to align with the given position. If the room needs to be moved, it updates the room's position, marks the room as modified, and schedules a delayed recalculation of the room's roof.
---
--- If no position is provided, the function calls the `InternalAlignObj()` method to align the object.
---
--- @param self Room The room object to align.
--- @param pos Vector The position to align the room to.
--- @param angle number The angle to align the room to.
function Room:AlignObj(pos, angle)
	if pos then
		assert(IsEditorActive())
		local offset = pos - self:GetPos()
		local box = self.box
		local didMove = false
		if abs(offset:x()) / voxelSizeX > 0 or abs(offset:y()) / voxelSizeY > 0 or abs(offset:z()) / voxelSizeZ > 0 then
			didMove = moveHelperHelper(self, offset)
		end
		if didMove then
			ObjModified(self)
			assert(self:GetGameFlags(const.gofPermanent) ~= 0)
			box = AddRects(box, self.box)
			ComputeSlabVisibilityInBox(box)
			DelayedCall(500, BuildBuildingsData)
			self:DelayedRecalcRoof()
		end
	else
		self:InternalAlignObj()
	end
end

--- Returns the editor label for the room.
---
--- The editor label is either the room's name or its class, depending on which is available.
---
--- @param self Room The room object to get the editor label for.
--- @return string The editor label for the room.
function Room:GetEditorLabel()
	return self.name or self.class
end

--- Inserts material properties into the Room.properties table.
---
--- @param name string The name of the material property.
--- @param count integer The number of material properties to insert, between 1 and 4.
function InsertMaterialProperties(name, count)
	assert(count >= 1 and count <= 4)
	for i = 1, count do
		table.insert(Room.properties, {
			id = name .. "color" .. count,
			editor = "color",
			alpha = false,
		})
		table.insert(Room.properties, {
			id = name .. "metallic" .. count,
			editor = "number",
		})
	end
end


local room_NSWE_lists = {
	"spawned_walls",
	"spawned_corners",
	"spawned_doors",
	"spawned_windows",
	"spawned_decals",
}

local room_NSWE_lists_no_DoorsWindows = {
	"spawned_walls",
	"spawned_corners",
}

local room_regular_lists = {
	"spawned_floors",
	"roof_objs",
}

local room_regular_list_sides = {
	"Floor",
	false -- see RoomRoof:GetPivots
}

--- Iterates over the elements of a table and calls a function for each valid element.
---
--- @param t table The table to iterate over.
--- @param f function The function to call for each valid element.
--- @param ... any Additional arguments to pass to the function.
function ForEachInTable(t, f, ...)
	for i = 1, #(t or "") do
		local o = t[i]
		if IsValid(o) then
			f(o, ...)
		end
	end
end

---
--- Unlocks all slabs in the room, including the floor, walls, and roof.
---
function Room:UnlockAllSlabs()
	self:UnlockFloor()
	self:UnlockAllWalls()
	self:UnlockRoof()
end

---
--- Unlocks the floor of the room.
---
function Room:UnlockFloor()
	ForEachInTable(self.spawned_floors, Slab.UnlockSubvariant)
end

---
--- Unlocks all walls, corners, and non-roof objects in the room.
---
--- This function iterates over the `spawned_walls`, `spawned_corners`, and `roof_objs` tables
--- and calls the `UnlockSubvariant()` method on each valid object. This effectively unlocks
--- all wall, corner, and non-roof objects in the room.
---
--- @param self Room The room object.
function Room:UnlockAllWalls()
	for side, t in pairs(self.spawned_walls or empty_table) do
		ForEachInTable(t, Slab.UnlockSubvariant)
	end
	for side, t in pairs(self.spawned_corners or empty_table) do
		ForEachInTable(t, Slab.UnlockSubvariant)
	end
	ForEachInTable(self.roof_objs, function(o)
		if not IsKindOf(o, "RoofSlab") then
			o:UnlockSubvariant()
		end
	end)
end

---
--- Unlocks all roof slabs in the room.
---
--- This function iterates over the `roof_objs` table and calls the `UnlockSubvariant()` method
--- on each valid `RoofSlab` object. This effectively unlocks all roof slabs in the room.
---
--- @param self Room The room object.
function Room:UnlockRoof()
	ForEachInTable(self.roof_objs, function(o)
		if IsKindOf(o, "RoofSlab") then
			o:UnlockSubvariant()
		end
	end)
end

sideToCornerSides = {
	East = { "East", "South" },
	South = { "West", "South" },
	West = { "West", "North" },
	North = { "East", "North" },
}

---
--- Unlocks the wall, corner, and non-roof objects on the specified side of the room.
---
--- This function iterates over the `spawned_walls`, `spawned_corners`, and `roof_objs` tables
--- and calls the `UnlockSubvariant()` method on each valid object on the specified side. This
--- effectively unlocks all wall, corner, and non-roof objects on the specified side of the room.
---
--- @param self Room The room object.
--- @param side string The side of the room to unlock (e.g. "East", "South", "West", "North").
function Room:UnlockWallSide(side) --both walls and corners + roof walls n corners in one
	ForEachInTable(self.spawned_walls and self.spawned_walls[side], Slab.UnlockSubvariant)
	local css = sideToCornerSides[side]
	for _, cs in ipairs(css) do
		ForEachInTable(self.spawned_corners and self.spawned_corners[cs], Slab.UnlockSubvariant)
	end
	
	ForEachInTable(self.roof_objs, function(o, side)
		if o.side == side and not IsKindOf(o, "RoofSlab") then
			o:UnlockSubvariant()
		end
	end ,side)
end

---
--- Iterates over all spawned objects in the room, excluding doors and windows.
---
--- This function calls the provided `func` for each valid spawned object in the room,
--- excluding any objects that are doors or windows.
---
--- @param self Room The room object.
--- @param func function The function to call for each spawned object.
--- @param ... any Additional arguments to pass to the `func`.
--- @return any The return value of the last call to `func`.
function Room:ForEachSpawnedObjNoDoorsWindows(func, ...)
	return self:_ForEachSpawnedObj(room_NSWE_lists_no_DoorsWindows, room_regular_lists, func, ...)
end

---
--- Iterates over all spawned objects in the room, calling the provided function for each one.
---
--- This function calls the provided `func` for each valid spawned object in the room,
--- including objects that are doors or windows.
---
--- @param self Room The room object.
--- @param func function The function to call for each spawned object.
--- @param ... any Additional arguments to pass to the `func`.
--- @return any The return value of the last call to `func`.
function Room:ForEachSpawnedObj(func, ...)
	return self:_ForEachSpawnedObj(room_NSWE_lists, room_regular_lists, func, ...)
end

---
--- Iterates over all spawned objects in the room, calling the provided function for each one.
---
--- This function calls the provided `func` for each valid spawned object in the room,
--- including or excluding objects that are doors or windows based on the provided `NSWE_lists`
--- and `regular_lists` parameters.
---
--- @param self Room The room object.
--- @param NSWE_lists table A table of lists of objects to iterate over, indexed by cardinal direction.
--- @param regular_lists table A table of lists of objects to iterate over that are not indexed by direction.
--- @param func function The function to call for each spawned object.
--- @param ... any Additional arguments to pass to the `func`.
--- @return any The return value of the last call to `func`.
function Room:_ForEachSpawnedObj(NSWE_lists, regular_lists, func, ...)
	for i = 1, #NSWE_lists do
		for side, objs in NSEW_pairs(self[NSWE_lists[i]] or empty_table) do
			for j = 1, #objs do
				if IsValid(objs[j]) then func(objs[j], ...) end
			end
		end
	end
	
	for i = 1, #regular_lists do
		local lst = self[regular_lists[i]] or ""
		for j = 1, #lst do
			if IsValid(lst[j]) then func(lst[j], ...) end
		end
	end
end

---
--- Gathers all editor-related objects associated with the room.
---
--- This function collects all objects that are considered "editor-related" for the room,
--- including any objects that have "owned_objs" or "owned_slabs" members. The returned
--- table contains all of these objects.
---
--- @param self Room The room object.
--- @return table A table containing all editor-related objects for the room.
function Room:GetEditorRelatedObjects()
	local ret = {}
	for i = 1, #room_NSWE_lists do
		for side, objs in NSEW_pairs(self[room_NSWE_lists[i]] or empty_table) do
			for _, obj in ipairs(objs) do
				if obj then
					ret[#ret + 1] = obj
					if obj:HasMember("owned_objs") and obj.owned_objs then
						table.iappend(ret, obj.owned_objs)
					end
					if obj:HasMember("owned_slabs") and obj.owned_slabs then
						table.iappend(ret, obj.owned_slabs)
					end
				end
			end
		end
	end
	for i = 1, #room_regular_lists do
		table.iappend(ret, self[room_regular_lists[i]] or empty_table)
	end
	Msg("GatherRoomRelatedObjects", self, ret)
	return ret
end

---
--- Sets whether the room is warped, and optionally forces the change.
---
--- If the room is warped, this will also set all spawned objects in the room to be warped.
---
--- @param self Room The room object.
--- @param warped boolean Whether the room should be warped.
--- @param force boolean (optional) If true, the warped state will be set even if the map is currently changing.
---
function Room:SetWarped(warped, force)
	CObject.SetWarped(self, warped)
	if force or not IsChangingMap() then
		self:ForEachSpawnedObj(function(obj)
			obj:SetWarped(warped)
		end)
	end
end

local function copyWallObjs(t, offset, room)
	local ret = {}
	for side, objs in NSEW_pairs(t or empty_table) do
		ret[side] = {}
		for i = 1, #objs do
			local o = objs[i]
			local no = PlaceObject(o.class)
			no.floor = room.floor
			no.width = o.width
			no.height = o.height
			no.material = o.material
			no:SetPos(o:GetPos() + offset)
			no:SetAngle(o:GetAngle())
			table.insert(ret[side], no)
			no:UpdateEntity()
		end
	end
	
	return ret
end

local function copyDecals(t, offset, room)
	local ret = {}
	for side, objs in NSEW_pairs(t or empty_table) do
		ret[side] = {}
		for i = 1, #objs do
			local o = objs[i]
			local no = PlaceObject(o.class)
			no.floor = room.floor
			no:SetPos(o:GetPos() + offset)
			no:SetAngle(o:GetAngle())
			no.restriction_box = Offset(o.restriction_box, offset)
			table.insert(ret[side], no)
		end
	end
	
	return ret
end

---
--- Sets the lockpick state of all spawned wall objects (doors and windows) based on the `doors_windows_blocked` property.
---
--- @param self Room
function Room:OnSetdoors_windows_blocked()
	self:ForEachSpawnedWallObj(function(o, val)
		o:SetlockpickState(val and "blocked" or "closed")
	end, self.doors_windows_blocked)
end

---
--- Recomputes the room visibility after the `none_roof_wall_mat_does_not_affect_nbrs` property is set.
---
--- @param self Room
function Room:OnSetnone_roof_wall_mat_does_not_affect_nbrs()
	self:ComputeRoomVisibility()
end

---
--- Recomputes the room visibility after the `none_roof_wall_mat_does_not_affect_nbrs` property is set.
---
--- @param self Room
function Room:OnSetnone_wall_mat_does_not_affect_nbrs()
	self:ComputeRoomVisibility()
end

---
--- Copies the room's spawned wall objects (doors and windows) and decals from another room.
---
--- @param self Room The room instance.
--- @param from Room The source room to copy from.
--- @param offset Vector The offset to apply to the copied objects.
---
function Room:OnCopied(from, offset)
	Volume.OnCopied(self, from, offset)
	self:CreateAllSlabs()
	
	self.spawned_doors = copyWallObjs(from.spawned_doors, offset, self)
	self.spawned_windows = copyWallObjs(from.spawned_windows, offset, self)
	self.spawned_decals = copyDecals(from.spawned_decals, offset, self)
end

---
--- Called after a new Room instance is created in the editor.
--- Aligns the Room object and creates all slabs.
---
--- @param self Room The Room instance.
--- @param parent Room The parent Room instance.
--- @param ged EditorGeometry The EditorGeometry instance.
--- @param is_paste boolean Whether the Room was pasted from another location.
---
function Room:OnAfterEditorNew(parent, ged, is_paste)
	--undo deletion from ged
	self.adjacent_rooms = nil
	self:AlignObj()
	self:CreateAllSlabs()
end

---
--- Called when an editor property is set on the Room instance.
--- This function calls the appropriate `OnSet` handler for the changed property.
---
--- @param self Room The Room instance.
--- @param prop_id string The ID of the property that was changed.
--- @param old_value any The previous value of the property.
--- @param ged EditorGeometry The EditorGeometry instance.
---
function Room:OnEditorSetProperty(prop_id, old_value, ged)
	if not IsValid(self) then return end --undo on deleted obj
	local f = rawget(Room, string.format("OnSet%s", prop_id))
	if f then
		f(self, self[prop_id], old_value)
		DelayedCall(500, BuildBuildingsData)
	end
end

---
--- Toggles whether floors above the current room should be hidden in the editor.
---
--- @param self Room The Room instance.
---
function Room:OnSethide_floors_editor()
	assert(IsEditorActive())
	HideFloorsAboveThisOne = rawget(self, "hide_floors_editor")
	HideFloorsAbove(HideFloorsAboveThisOne)
end

---
--- Returns whether floors above the current room should be hidden in the editor.
---
--- @return boolean Whether floors above the current room should be hidden.
---
function Room:Gethide_floors_editor()
	return HideFloorsAboveThisOne
end

---
--- Toggles the visibility of the room's wireframe geometry in the editor.
---
--- @param self Room The Room instance.
---
function Room:OnSetwireframe_visible()
	self:ToggleGeometryVisible()
end

---
--- Toggles the visibility of the room's position markers in the editor.
---
--- @param self Room The Room instance.
---
function Room:OnSetwall_text_markers_visible()
	self:TogglePosMarkersVisible()
end

---
--- Sets the inner wall material for the room.
---
--- If the new material is an empty string, it is set to `noneWallMat`. If the new material or the old material is `noneWallMat`, and they are different, all walls are unlocked.
---
--- The inner material is then set on the slabs for each cardinal direction, as well as any roof objects.
---
--- @param self Room The Room instance.
--- @param val string The new inner wall material.
--- @param oldVal string The previous inner wall material.
---
function Room:OnSetinner_wall_mat(val, oldVal)
	if val == "" then
		val = noneWallMat
		self.inner_wall_mat = val
	end
	if (val == noneWallMat or oldVal == noneWallMat) and val ~= oldVal then
		self:UnlockAllWalls()
	end
	self:SetInnerMaterialToSlabs("North")
	self:SetInnerMaterialToSlabs("South")
	self:SetInnerMaterialToSlabs("West")
	self:SetInnerMaterialToSlabs("East")
	self:SetInnerMaterialToRoofObjs()
end

---
--- Sets the inner wall material for the room.
---
--- The inner material is set on the slabs for each cardinal direction, as well as any roof objects.
---
--- @param self Room The Room instance.
--- @param val string The new inner wall material.
--- @param oldVal string The previous inner wall material.
---
function Room:OnSetinner_colors(val, oldVal)
	self:SetInnerMaterialToSlabs("North")
	self:SetInnerMaterialToSlabs("South")
	self:SetInnerMaterialToSlabs("West")
	self:SetInnerMaterialToSlabs("East")
	self:SetInnerMaterialToRoofObjs()
end

---
--- Sets the outer wall colors for the room.
---
--- This function iterates through the spawned walls, corners, windows, and doors in the room, and sets their colors to the new outer color value. It also updates the colors of any roof objects that are not RoofSlab objects.
---
--- @param self Room The Room instance.
--- @param val string The new outer wall color.
--- @param oldVal string The previous outer wall color.
---
function Room:OnSetouter_colors(val, oldVal)
	local function iterateNSEWTableAndSetColor(t)
		if not t then return end
		for side, list in NSEW_pairs(t) do
			for i = 1, #list do
				local o = list[i]
				if IsValid(o) then --wall piece might be deleted by lvl designer
					o:Setcolors(val)
				end
			end
		end
	end
	iterateNSEWTableAndSetColor(self.spawned_walls)
	
	for side, list in NSEW_pairs(self.spawned_corners) do
		for i = 1, #list do
			local o = list[i]
			if IsValid(o) then
				o:SetColorFromRoom()
			end
		end
	end
	
	for side, list in NSEW_pairs(self.spawned_windows or empty_table) do
		for i = 1, #list do
			list[i]:UpdateManagedSlabs()
			list[i]:RefreshColors()
		end
	end
	
	for side, list in NSEW_pairs(self.spawned_doors or empty_table) do
		for i = 1, #list do
			list[i]:RefreshColors()
		end
	end
	
	if self.roof_objs then
		for i=1,#self.roof_objs do
			local o = self.roof_objs[i]
			if IsValid(o) and not IsKindOf(o, "RoofSlab") then
				o:Setcolors(val)
			end
		end
	end
end

--- Updates the colors of all spawned floor objects in the room.
---
--- @param self Room The Room instance.
--- @param val string The new floor color.
--- @param oldVal string The previous floor color.
function Room:OnSetfloor_colors(val, oldVal)
	for i = 1, #(self.spawned_floors or "") do
		local o = self.spawned_floors[i]
		if IsValid(o) then
			o:Setcolors(val)
		end
	end
end

--- Updates the floor material of the room.
---
--- @param self Room The Room instance.
--- @param val string The new floor material.
function Room:OnSetfloor_mat(val)
	self:UnlockFloor()
	self:CreateFloor()
end

--- Resets the wall materials of the room to the default wall material.
---
--- This function is used to reset the wall materials of the room to the default wall material. It checks if any of the wall materials have changed from the default, and if so, it unlocks all walls, creates all walls with the new materials, and recreates the roof.
---
--- @param self Room The Room instance.
function Room:ResetWallMaterials()
	local wm = defaultWallMat
	local change = self.north_wall_mat ~= wm
	self.north_wall_mat = wm
	change = change or self.south_wall_mat ~= wm
	self.south_wall_mat = wm
	change = change or self.west_wall_mat ~= wm
	self.west_wall_mat = wm
	change = change or self.east_wall_mat ~= wm
	self.east_wall_mat = wm
	--todo: wall added/removed msgs
	if change then
		ObjModified(self)
		self:UnlockAllWalls()
		self:CreateAllWalls()
		self:RecreateRoof()
	end
end

local function FireWallChangedEventsHelper(self, side, val, oldVal)
	local wasWall = oldVal ~= noneWallMat and (oldVal ~= defaultWallMat or self.wall_mat ~= noneWallMat)
	local isWall = val ~= noneWallMat and (val ~= defaultWallMat or self.wall_mat ~= noneWallMat)
	if not wasWall and isWall then
		Msg("RoomAddedWall", self, side)
	elseif wasWall and not isWall then
		Msg("RoomRemovedWall", self, side)
	end
end

--- Updates the north wall material of the room.
---
--- This function is called when the north wall material of the room is set. It unlocks the north wall, creates the new walls with the specified material, recreates the northeast and northwest corner beams, recreates the roof, and fires wall changed events.
---
--- @param self Room The Room instance.
--- @param val string The new north wall material.
--- @param oldVal string The previous north wall material.
function Room:OnSetnorth_wall_mat(val, oldVal)
	self:UnlockWallSide("North")
	self:CreateWalls("North", val)
	self:RecreateNECornerBeam()
	self:RecreateNWCornerBeam()
	self:RecreateRoof()
	FireWallChangedEventsHelper(self, "North", val, oldVal)
	self:CheckWallSizes()
end

---
--- Updates the south wall material of the room.
---
--- This function is called when the south wall material of the room is set. It unlocks the south wall, creates the new walls with the specified material, recreates the southeast and southwest corner beams, recreates the roof, and fires wall changed events.
---
--- @param self Room The Room instance.
--- @param val string The new south wall material.
--- @param oldVal string The previous south wall material.
function Room:OnSetsouth_wall_mat(val, oldVal)
	self:UnlockWallSide("South")
	self:CreateWalls("South", val)
	self:RecreateSECornerBeam()
	self:RecreateSWCornerBeam()
	self:RecreateRoof()
	FireWallChangedEventsHelper(self, "South", val, oldVal)
	self:CheckWallSizes()
end

--- Updates the west wall material of the room.
---
--- This function is called when the west wall material of the room is set. It unlocks the west wall, creates the new walls with the specified material, recreates the southwest and northwest corner beams, recreates the roof, and fires wall changed events.
---
--- @param self Room The Room instance.
--- @param val string The new west wall material.
--- @param oldVal string The previous west wall material.
function Room:OnSetwest_wall_mat(val, oldVal)
	self:UnlockWallSide("West")
	self:CreateWalls("West", val)
	self:RecreateSWCornerBeam()
	self:RecreateNWCornerBeam()
	self:RecreateRoof()
	FireWallChangedEventsHelper(self, "West", val, oldVal)
	self:CheckWallSizes()
end

---
--- Updates the east wall material of the room.
---
--- This function is called when the east wall material of the room is set. It unlocks the east wall, creates the new walls with the specified material, recreates the southeast and northeast corner beams, recreates the roof, and fires wall changed events.
---
--- @param self Room The Room instance.
--- @param val string The new east wall material.
--- @param oldVal string The previous east wall material.
function Room:OnSeteast_wall_mat(val, oldVal)
	self:UnlockWallSide("East")
	self:CreateWalls("East", val)
	self:RecreateSECornerBeam()
	self:RecreateNECornerBeam()
	self:RecreateRoof()
	FireWallChangedEventsHelper(self, "East", val, oldVal)
	self:CheckWallSizes()
end

--- Sets the wall material of the room.
---
--- This function is called when the wall material of the room is set. It unlocks all walls, creates new walls with the specified material, recreates the roof, and fires wall changed events.
---
--- @param self Room The Room instance.
--- @param val string The new wall material.
--- @param oldVal string The previous wall material.
function Room:SetWallMaterial(val)
	local ov = self.wall_mat
	self.wall_mat = val
	if IsChangingMap() then return end
	self:OnSetwall_mat(val, ov)
end

--- Updates the wall material of the room.
---
--- This function is called when the wall material of the room is set. It unlocks all walls, creates new walls with the specified material, recreates the roof, and fires wall changed events.
---
--- @param self Room The Room instance.
--- @param val string The new wall material.
--- @param oldVal string The previous wall material.
function Room:OnSetwall_mat(val, oldVal)
	if val == "" then
		val = noneWallMat
		self.wall_mat = val
	end
	self:UnlockAllWalls()
	self:CreateAllWalls()
	self:RecreateRoof()
	
	local wasWall = oldVal ~= noneWallMat
	local isWall = val ~= noneWallMat
	local ev = false
	if wasWall and not isWall then
		ev = "RoomRemovedWall"
	elseif not wasWall and isWall then
		ev = "RoomAddedWall"
	end
	
	if ev then
		if self.south_wall_mat == defaultWallMat then
			Msg(ev, self, "South")
		end
		if self.north_wall_mat == defaultWallMat then
			Msg(ev, self, "North")
		end
		if self.west_wall_mat == defaultWallMat then
			Msg(ev, self, "West")
		end
		if self.east_wall_mat == defaultWallMat then
			Msg(ev, self, "East")
		end
	end
end

--- Helper function for updating the size of a Room object.
---
--- This function is called when the size of a Room object is updated. It checks for collisions with the new size, and if there are no collisions, it resizes the Room and sends a "RoomResized" message.
---
--- @param self Room The Room instance.
--- @param old_v point The previous size of the Room.
--- @return boolean True if the resize was successful, false otherwise.
function SizeSetterHelper(self, old_v)
	if IsChangingMap() then return end
	local oldBox = self.box
	self:InternalAlignObj(true)
	if self:CheckCollision() then
		self.size = old_v
		self:InternalAlignObj(true)
		return false
	else
		self:Resize(old_v, self.size, oldBox)
		Volume.FinishAlign(self)
		Msg("RoomResized", self, old_v) --old_v == old self.size
		return true
	end
end

--- Updates the x-dimension size of a Room object.
---
--- This function is called when the x-dimension size of a Room object is updated. It stores the old size, updates the size, and then calls the `SizeSetterHelper` function to handle the resize operation.
---
--- @param self Room The Room instance.
--- @param val number The new x-dimension size.
function Room:OnSetsize_x(val)
	local old_v = self.size
	self.size = point(val, self.size:y(), self.size:z())
	SizeSetterHelper(self, old_v)
end

--- Updates the y-dimension size of a Room object.
---
--- This function is called when the y-dimension size of a Room object is updated. It stores the old size, updates the size, and then calls the `SizeSetterHelper` function to handle the resize operation.
---
--- @param self Room The Room instance.
--- @param val number The new y-dimension size.
function Room:OnSetsize_y(val)
	local old_v = self.size
	self.size = point(self.size:x(), val, self.size:z())
	SizeSetterHelper(self, old_v)
end

--- Updates the z-dimension size of a Room object.
---
--- This function is called when the z-dimension size of a Room object is updated. It stores the old size, updates the size, and then calls the `SizeSetterHelper` function to handle the resize operation. If the new size is 0, it also deletes all wall objects, floors, and corner objects from the Room.
---
--- @param self Room The Room instance.
--- @param val number The new z-dimension size.
function Room:OnSetsize_z(val)
	local old_v = self.size
	self.size = point(self.size:x(), self.size:y(), val)
	SizeSetterHelper(self, old_v)
	if val == 0 then
		self:DeleteAllWallObjs()
		self:DeleteAllFloors()
		self:DeleteAllCornerObjs()
	end
end

--- Returns the x-dimension size of the Room object.
---
--- @param self Room The Room instance.
--- @return number The x-dimension size of the Room.
function Room:Getsize_x()
	return self.size:x()
end

--- Returns the y-dimension size of the Room object.
---
--- @param self Room The Room instance.
--- @return number The y-dimension size of the Room.
function Room:Getsize_y()
	return self.size:y()
end

--- Returns the z-dimension size of the Room object.
---
--- @param self Room The Room instance.
--- @return number The z-dimension size of the Room.
function Room:Getsize_z()
	return self.size:z()
end

--- Returns the x-dimension position of the Room object.
---
--- @param self Room The Room instance.
--- @return number The x-dimension position of the Room.
function Room:Getmove_x()
	local x = WorldToVoxel(self.position)
	return x
end

--- Returns the y-dimension position of the Room object.
---
--- @param self Room The Room instance.
--- @return number The y-dimension position of the Room.
function Room:Getmove_y()
	local _, y = WorldToVoxel(self.position)
	return y
end

--- Returns the z-dimension position of the Room object.
---
--- @param self Room The Room instance.
--- @return number The z-dimension position of the Room.
function Room:Getmove_z()
	local x, y, z = WorldToVoxel(self.position)
	return z
end

--- Sets the z-offset of the Room object.
---
--- @param self Room The Room instance.
--- @param val number The new z-offset value.
--- @param old_v number The previous z-offset value.
function Room:OnSetz_offset(val, old_v)
	moveHelper(self, "z_offset", old_v, 0, 0, val - old_v)
end

--- Sets the x-dimension position of the Room object.
---
--- @param self Room The Room instance.
--- @param val number The new x-dimension position value.
function Room:OnSetmove_x(val)
	local old_v = self.position
	local x, y, z = WorldToVoxel(self.position)
	self.position = SnapVolumePos(VoxelToWorld(val, y, z, true))
	moveHelper(self, "position", old_v, val - x, 0, 0)
end

--- Sets the y-dimension position of the Room object.
---
--- @param self Room The Room instance.
--- @param val number The new y-dimension position value.
function Room:OnSetmove_y(val)
	local old_v = self.position
	local x, y, z = WorldToVoxel(self.position)
	self.position = SnapVolumePos(VoxelToWorld(x, val, z, true))
	moveHelper(self, "position", old_v, 0, val - y, 0)
end

--- Sets the z-dimension position of the Room object.
---
--- @param self Room The Room instance.
--- @param val number The new z-dimension position value.
function Room:OnSetmove_z(val)
	local old_v = self.position
	local x, y, z = WorldToVoxel(self.position)
	self.position = SnapVolumePos(VoxelToWorld(x, y, val, true))
	moveHelper(self, "position", old_v, 0, 0, val - z)
end

--left to right sort on selected wall
local dirToComparitor = {
	South = function(o1, o2)
		local x1, _, _ = o1:GetPosXYZ()
		local x2, _, _ = o2:GetPosXYZ()
		return x1 < x2
	end,
	
	North = function(o1, o2)
		local x1, _, _ = o1:GetPosXYZ()
		local x2, _, _ = o2:GetPosXYZ()
		return x2 < x1
	end,
	
	West = function(o1, o2)
		local _, y1, _ = o1:GetPosXYZ()
		local _, y2, _ = o2:GetPosXYZ()
		return y1 < y2
	end,
	
	East = function(o1, o2)
		local _, y1, _ = o1:GetPosXYZ()
		local _, y2, _ = o2:GetPosXYZ()
		return y2 < y1
	end,
}

--- Sorts a table of wall objects based on their position along the specified direction.
---
--- @param self Room The Room instance.
--- @param objs table A table of wall objects to sort.
--- @param dir string The direction to sort the wall objects by. Can be "North", "South", "East", or "West".
function Room:SortWallObjs(objs, dir)
	table.sort(objs, dirToComparitor[dir])
end

--for doors/windows
--- Calculates the restriction box for a wall object based on its position, size, and height.
---
--- @param self Room The Room instance.
--- @param dir string The direction of the wall, can be "North", "South", "East", or "West".
--- @param wallPos Vector3 The position of the wall.
--- @param wallSize number The size of the wall.
--- @param height number The height of the wall.
--- @param width number The width of the wall.
--- @return Box The restriction box for the wall object.
function Room:CalculateRestrictionBox(dir, wallPos, wallSize, height, width)
	local xofs, nxofs = 0, 0
	local yofs, nyofs = 0, 0
	width = Max(width, 1)
	
	if dir == "North" or dir == "South" then
		xofs = (wallSize / 2 - width * voxelSizeX / 2)
		nxofs = xofs
		if width % 2 == 0 then
			local m = (dir == "South" and -1 or 1)
			xofs = xofs + m * voxelSizeX / 2
			nxofs = nxofs - m * voxelSizeX / 2
		end
	else
		yofs = (wallSize / 2 - width * voxelSizeY / 2)
		nyofs = yofs
		if width % 2 == 0 then
			local m = (dir == "West" and -1 or 1)
			yofs = yofs + m * voxelSizeX / 2
			nyofs = nyofs - m * voxelSizeX / 2
		end
	end
	
	local maxZ = wallPos:z() + (self.size:z() * voxelSizeZ - height * voxelSizeZ)
	return box(wallPos:x() - nxofs, wallPos:y() - nyofs, wallPos:z(), wallPos:x() + xofs, wallPos:y() + yofs, maxZ)
end

---
--- Finds a free position to place a slab wall object of the given width and height.
---
--- @param dir string The direction of the wall, can be "North", "South", "East", or "West".
--- @param width number The width of the slab wall object.
--- @param height number The height of the slab wall object.
--- @return boolean|point The free position to place the slab wall object, or false if no free position is found.
function Room:FindSlabObjPos(dir, width, height)
	local sizeX, sizeY = self.size:x(), self.size:y()
	if dir == "North" or dir == "South" then
		if width > sizeX then
			print("Obj is too big")
			return false
		end
	else
		if width > sizeY then
			print("Obj is too big")
			return false
		end
	end
	
	local z = self:CalcZ() + (3 - height) * voxelSizeZ
	local angle = 0
	local sx, sy = self.position:x(), self.position:y()
	local offsx = 0
	local offsy = 0
	local max = 0
	
	if dir == "North" then
		angle = 270 * 60
		offsx = voxelSizeX
		sx = sx + halfVoxelSizeX
		max = sizeX
	elseif dir == "East" then
		angle = 0
		offsy = voxelSizeY
		sx = sx + sizeX * voxelSizeX
		sy = sy + halfVoxelSizeY
		max = sizeY
	elseif dir == "South" then
		angle = 90 * 60
		offsx = voxelSizeX
		sy = sy + sizeY * voxelSizeY
		sx = sx + halfVoxelSizeX
		max = sizeX
	elseif dir == "West" then
		angle = 180 * 60
		offsy = voxelSizeY
		sy = sy + halfVoxelSizeY
		max = sizeY
	end
	
	local iStart = width == 3 and 1 or 0
	
	for i = iStart, max - 1 do
		local x = sx + offsx * i
		local y = sy + offsy * i
		
		local newPos = point(x, y, z)
		local canPlace = not IntersectWallObjs(nil, newPos, width, height, angle)
		
		if canPlace then
			return newPos
		end
	end
	
	return false
end

---
--- Creates a new SlabWallObject instance with the provided object properties.
---
--- @param obj table The object properties to initialize the SlabWallObject with.
--- @param class? table The class to use for creating the new SlabWallObject instance. Defaults to SlabWallObject.
--- @return SlabWallObject The new SlabWallObject instance.
---
function Room:NewSlabWallObj(obj, class)
	class = class or SlabWallObject
	return class:new(obj)
end

---
--- Iterates over all spawned window objects in the room and calls the provided function for each one.
---
--- @param func function The function to call for each spawned window object.
--- @param ... any Additional arguments to pass to the function.
---
function Room:ForEachSpawnedWindow(func, ...)
	for _, t in sorted_pairs(self.spawned_windows or empty_table) do
		for i = #t, 1, -1 do
			func(t[i], ...)
		end
	end
end

---
--- Iterates over all spawned door objects in the room and calls the provided function for each one.
---
--- @param func function The function to call for each spawned door object.
--- @param ... any Additional arguments to pass to the function.
---
function Room:ForEachSpawnedDoor(func, ...)
	for _, t in sorted_pairs(self.spawned_doors or empty_table) do
		for i = #t, 1, -1 do --functor may del
			func(t[i], ...)
		end
	end
end

---
--- Iterates over all spawned window and door objects in the room and calls the provided function for each one.
---
--- @param func function The function to call for each spawned window and door object.
--- @param ... any Additional arguments to pass to the function.
---
function Room:ForEachSpawnedWallObj(func, ...) --doors and windows
	self:ForEachSpawnedDoor(func, ...)
	self:ForEachSpawnedWindow(func, ...)
end

---
--- Places a wall object (door or window) in the room at the specified position and orientation.
---
--- @param val table The properties of the wall object to place, including its material, dimensions, and other metadata.
--- @param side? string The side of the room to place the wall object on. Defaults to the currently selected wall.
--- @param class? table The class to use for creating the new wall object instance. Defaults to SlabWallObject.
--- @return SlabWallObject The new wall object instance that was placed in the room.
---
function Room:PlaceWallObj(val, side, class)
	local dir = side or self.selected_wall
	assert(dir)
	if not dir then return end
	--check for collision, pick pos
	local freePos = self:FindSlabObjPos(dir, val.width, val.height)
	
	if not freePos then
		print("No free pos found!")
		return
	end
	local wallPos, wallSize, center = self:GetWallPos(dir)
	local obj = self:NewSlabWallObj({
			entity = false, room = self, material = val.mat or "Planks",
			building_class = val.building_class or nil, building_template = val.building_template or nil,
			side = dir
		},
		class.class)
	local a = slabDirToAngle[dir]
	local zPosOffset = (3 - val.height) * voxelSizeZ
	local vx, vy, vz, va = WallWorldToVoxel(freePos:x(), freePos:y(), wallPos:z() + zPosOffset, a)
	local pos = point(WallVoxelToWorld(vx, vy, vz, va))
	obj.room = self
	obj.floor = self.floor
	obj.subvariant = 1
	obj:SetPos(pos)
	obj:SetAngle(a)
	obj:SetProperty("width", val.width)
	obj:SetProperty("height", val.height)
	obj:AlignObj()
	obj:UpdateEntity()
	
	local container, nestedList
	if val.is_door or obj:IsDoor() then --door
		self.spawned_doors = self.spawned_doors or {}
		self.spawned_doors[dir] = self.spawned_doors[dir] or {}
		container = self.spawned_doors
	else --window
		self.spawned_windows = self.spawned_windows or {}
		self.spawned_windows[dir] = self.spawned_windows[dir] or {}
		container = self.spawned_windows
	end
	
	if container then
		table.insert(container[dir], obj)
	end
	
	if Platform.editor and IsEditorActive() then
		editor.ClearSel()
		editor.AddToSel({obj})
	end
	
	return obj
end


---
--- Calculates the restriction box for a decal based on the given wall position and size.
---
--- @param dir string The direction of the wall (North, South, East, West)
--- @param wallPos point The position of the wall
--- @param wallSize number The size of the wall
--- @return box The restriction box for the decal
---
function Room:CalculateDecalRestrictionBox(dir, wallPos, wallSize)
	local xofs, nxofs = 0, 0
	local yofs, nyofs = 0, 0
	if dir == "North" or dir == "South" then
		xofs = wallSize / 2
		nxofs = xofs
		
		wallPos = wallPos:SetY(wallPos:y() + 100 * (dir == "North" and -1 or 1))
	else
		yofs = wallSize / 2
		nyofs = yofs
		
		wallPos = wallPos:SetX(wallPos:x() + 100 * (dir == "West" and -1 or 1))
	end
	local maxZ = wallPos:z() + (self.size:z() * voxelSizeZ) + 1
	return box(wallPos:x() - nxofs, wallPos:y() - nyofs, wallPos:z(), wallPos:x() + xofs, wallPos:y() + yofs, maxZ)
end

DefineClass.RoomDecal = {
	__parents = { "AlignedObj", "Decal", "Shapeshifter", "Restrictor", "HideOnFloorChange" },
	properties = {
		{ category = "General", id = "entity", editor = "text", default = false, no_edit = true },
	},
	flags = { cfAlignObj = true, cfDecal = true, efCollision = false, gofPermanent = true, },
}

---
--- Aligns the RoomDecal object to the specified position and angle.
---
--- @param pos point The position to align the object to. If not provided, the current position is used.
--- @param angle number The angle to align the object to. If not provided, the current angle is used.
--- @param axis string The axis to align the object to. If not provided, the current axis is used.
---
function RoomDecal:AlignObj(pos, angle, axis)
	pos = pos or self:GetPos()
	local x, y, z = self:RestrictXYZ(pos:xyz())
	
	self:SetPos(x, y, z)
	self:SetAxisAngle(axis or self:GetAxis(), angle or self:GetAngle())
end

---
--- Changes the entity of the RoomDecal object.
---
--- @param val string The new entity to set for the RoomDecal object.
---
function RoomDecal:ChangeEntity(val)
	Shapeshifter.ChangeEntity(self, val)
	self.entity = val
end

---
--- Initializes the RoomDecal object when the game starts.
---
--- If the map is changing and the RoomDecal has an entity, the entity is changed using the Shapeshifter.ChangeEntity function.
---
function RoomDecal:GameInit()
	if IsChangingMap() and self.entity then
		Shapeshifter.ChangeEntity(self, self.entity)
	end
end

---
--- Removes the RoomDecal object from the spawned_decals table of the associated Room object.
---
--- This function is called when the RoomDecal object is being deleted. It searches for the RoomDecal object in the spawned_decals table of the associated Room objects, and removes it if found.
---
--- If the RoomDecal object does not have a reference to the associated Room object, it will search for the Room object by checking the restriction_box of the RoomDecal object.
---
--- If the RoomDecal object is not found in any Room object's spawned_decals table, an assertion error is raised.
---
function RoomDecal:Done()
	local safe = rawget(self, "safe_deletion")
	if not safe then
		--decals dont have ref to the room they belong to, so the check is all weird
		local box = self.restriction_box
		if box then
			local passed = {}
			MapForEach(box:grow(100, 100, 0), "WallSlab", function(s)
				local side = s.side
				local room = s.room
				if room then
					local id = xxhash(room.handle, side)
					if not passed[id] then
						passed[id] = true
						local t = room.spawned_decals[side]
						local t_idx = table.find(t, self)
						if t_idx then
							table.remove(t, t_idx)
							ObjModified(room)
							return "break"
						end
					end
				end
			end)
		else
			local b = self:GetObjectBBox()
			local success = false
			b = b:grow(guim, guim, guim)
			EnumVolumes(b, function(r)
				local t = r.spawned_decals
				for side, tt in pairs(t or empty_table) do
					local t_idx = table.find(tt, self)
					if t_idx then
						table.remove(tt, t_idx)
						ObjModified(r)
						success = true
						return "break"
					end
				end
			end)
			
			if not success then
				assert(false, "RoomDecal not safely deleted, ref in room remains!")
			end
		end
	end
end

---
--- Adds a new RoomDecal object to the specified wall of the Room.
---
--- @param val table The table containing the entity information for the RoomDecal.
--- @return void
function Room:Setplace_decal(val)
	local dir = self.selected_wall
	if not dir then return end
	
	local wallPos, wallSize, center = self:GetWallPos(dir)
	local a = slabDirToAngle[dir]
	
	local obj = RoomDecal:new()
	obj.floor = self.floor
	obj:ChangeEntity(val.entity)
	obj:SetAngle(a)
	local xOffs = 0
	local yOffs = 0
	if dir == "East" then
		obj:SetAxis(axis_y)
		obj:SetAngle(90 * 60)
		xOffs = 100
	elseif dir == "West" then
		obj:SetAxis(axis_y)
		obj:SetAngle(-90 * 60)
		xOffs = -100
	elseif dir == "North" then
		obj:SetAxis(axis_x)
		obj:SetAngle(90 * 60)
		yOffs = -100
	elseif dir == "South" then
		obj:SetAxis(axis_x)
		obj:SetAngle(-90 * 60)
		yOffs = 100
	end
	obj:SetPos(wallPos + point(xOffs, yOffs, voxelSizeZ * self.size:z() / 2))
	obj.restriction_box = self:CalculateDecalRestrictionBox(dir, wallPos, wallSize)
	--DbgAddBox(obj.restriction_box, RGB(255, 0, 0))
	
	self.spawned_decals = self.spawned_decals or {}
	self.spawned_decals[dir] = self.spawned_decals[dir] or {}
	table.insert(self.spawned_decals[dir], obj)
	
	editor.ClearSel()
	editor.AddToSel({obj})
	
	self.place_decal = "temp"
	ObjModified(self)
	self.place_decal = ""
	ObjModified(self)
end

--- Deletes a wall object and restores any affected slabs.
---
--- @param d table The wall object to delete.
function Room:DeleteWallObjHelper(d)
	d:RestoreAffectedSlabs()
	DoneObject(d)
	ObjModified(self)
end

---
--- Deletes all wall objects in the specified direction, or all wall objects if no direction is specified.
---
--- If a container is provided, the wall objects will be deleted from that container. Otherwise, the wall objects will be deleted from the Room's internal lists.
---
--- If no direction is specified, all wall objects, floors, and corner objects will be deleted.
---
--- @param container table|nil The container holding the wall objects to delete.
--- @param dir string|nil The direction of the wall objects to delete. Can be "North", "South", "East", or "West".
function Room:DeleteWallObjs(container, dir)
	if not dir then
		self:DeleteWallObjs("North", container)
		self:DeleteWallObjs("South", container)
		self:DeleteWallObjs("East", container)
		self:DeleteWallObjs("West", container)
		self:DeleteAllFloors()
		self:DeleteAllCornerObjs()
	else
		local t = container and container[dir]
		for i = #(t or empty_table), 1, -1 do
			if IsValid(t[i]) then --can be killed from editor
				self:DeleteWallObjHelper(t[i])
			end
			t[i] = nil
		end
		ObjModified(self)
	end
end

---
--- Rebuilds all slabs in the room.
---
--- This function first deletes all existing slabs in the room using `DeleteAllSlabs()`, then creates new slabs using `CreateAllSlabs()`, and finally recreates the roof using `RecreateRoof("force")`.
---
--- @param self Room The room object.
function Room:RebuildAllSlabs()
	self:DeleteAllSlabs()
	self:CreateAllSlabs()
	self:RecreateRoof("force")
end

---
--- Deletes all objects in a table of NSEW-indexed tables.
---
--- This function is used to clean up lists of spawned objects, such as doors, windows, and decals. It iterates through each NSEW-indexed table and deletes all objects in that table, handling the case where objects may have already removed themselves from the table.
---
--- @param t table The table of NSEW-indexed tables containing the objects to delete.
function Room:DoneObjectsInNWESTable(t)
	for k, v in NSEW_pairs(t or empty_table) do
		--windows and doors are so clever that they remove themselves from these lists when deleted, which causes DoneObjects to sometimes fail
		while #v > 0 do
			local idx = #v
			DoneObject(v[idx])
			v[idx] = nil
		end
	end
end

---
--- Deletes all slabs in the room.
---
--- This function first suspends pass edits, then deletes all wall objects, corner objects, floors, and roof objects. Finally, it resumes pass edits.
---
--- @param self Room The room object.
function Room:DeleteAllSlabs()
	SuspendPassEdits("Room:DeleteAllSpawnedObjs")
	self:DeleteAllWallObjs()
	self:DeleteAllCornerObjs()
	self:DeleteAllFloors()
	self:DeleteRoofObjs()
	ResumePassEdits("Room:DeleteAllSpawnedObjs")
end

---
--- Deletes all spawned objects in the room, including walls, corners, floors, roof, doors, windows, and decals.
---
--- This function first suspends pass edits, then deletes all wall objects, corner objects, floors, and roof objects. It then deletes all spawned doors, windows, and decals using the `DoneObjectsInNWESTable()` function. Finally, it resumes pass edits.
---
--- @param self Room The room object.
function Room:DeleteAllSpawnedObjs()
	SuspendPassEdits("Room:DeleteAllSpawnedObjs")
	self:DeleteAllWallObjs()
	self:DeleteAllCornerObjs()
	self:DeleteAllFloors()
	self:DeleteRoofObjs()
	self:DoneObjectsInNWESTable(self.spawned_doors)
	self:DoneObjectsInNWESTable(self.spawned_windows)
	self:DoneObjectsInNWESTable(self.spawned_decals)
	ResumePassEdits("Room:DeleteAllSpawnedObjs")
end

---
--- Deletes all floor objects in the room.
---
--- This function first suspends pass edits, then deletes all floor objects using the `DoneObjects()` function. Finally, it resumes pass edits and sends a "RoomDestroyedFloor" message.
---
--- @param self Room The room object.
function Room:DeleteAllFloors()
	SuspendPassEdits("Room:DeleteAllFloors")
	DoneObjects(self.spawned_floors, "clear")
	ResumePassEdits("Room:DeleteAllFloors")
	Msg("RoomDestroyedFloor", self)
end

---
--- Deletes all corner objects in the room.
---
--- This function suspends pass edits, then deletes all corner objects using the `DoneObjects()` function. Finally, it resumes pass edits.
---
--- @param self Room The room object.
function Room:DeleteAllCornerObjs()
	for k, v in NSEW_pairs(self.spawned_corners or empty_table) do
		DoneObjects(v, "clear")
	end
end

---
--- Deletes all wall objects in the room.
---
--- This function first suspends pass edits, then deletes all wall objects using the `DoneObjects()` function. Finally, it resumes pass edits.
---
--- @param self Room The room object.
function Room:DeleteAllWallObjs()
	SuspendPassEdits("Room:DeleteAllWallObjs")
	for k, v in NSEW_pairs(self.spawned_walls or empty_table) do
		DoneObjects(v, "clear")
	end
	ResumePassEdits("Room:DeleteAllWallObjs")
end

---
--- Checks if the given wall material is a valid wall material.
---
--- A wall material is considered valid if it is not the `noneWallMat` value, or if it is the `defaultWallMat` value and the room's `wall_mat` is not `noneWallMat`.
---
--- @param self Room The room object.
--- @param mat string The wall material to check.
--- @return boolean True if the wall material is valid, false otherwise.
function Room:HasWall(mat)
	return mat ~= noneWallMat and (mat ~= defaultWallMat or self.wall_mat ~= noneWallMat)
end

---
--- Checks if the room has a wall on the specified side.
---
--- @param self Room The room object.
--- @param side string The cardinal direction of the wall to check.
--- @return boolean True if the room has a wall on the specified side, false otherwise.
function Room:HasWallOnSide(side)
	return self:GetWallMatHelperSide(side) ~= noneWallMat
end

---
--- Checks if the room has walls on all four cardinal directions.
---
--- @param self Room The room object.
--- @return boolean True if the room has walls on all four cardinal directions, false otherwise.
function Room:HasAllWalls()
	for _, side in ipairs(CardinalDirectionNames) do
		if not self:HasWallOnSide(side) then
			return false
		end
	end
	
	return true
end

---
--- Recreates the northwest corner beam of the room.
---
--- This function first checks the material of the north wall. If the north wall material is `noneWallMat`, it uses the material of the west wall instead. It then calls the `CreateCornerBeam` function with the determined material and the "North" direction to create the northwest corner beam.
---
--- @param self Room The room object.
function Room:RecreateNWCornerBeam()
	local mat = self.north_wall_mat
	if mat == noneWallMat then
		mat = self.west_wall_mat
	end
	self:CreateCornerBeam("North", mat) --nw
end

---
--- Recreates the southwest corner beam of the room.
---
--- This function first checks the material of the west wall. If the west wall material is `noneWallMat`, it uses the material of the south wall instead. It then calls the `CreateCornerBeam` function with the determined material and the "West" direction to create the southwest corner beam.
---
--- @param self Room The room object.
function Room:RecreateSWCornerBeam()
	local mat = self.west_wall_mat
	if mat == noneWallMat then
		mat = self.south_wall_mat
	end
	self:CreateCornerBeam("West", mat) --sw
end

---
--- Recreates the northeast corner beam of the room.
---
--- This function first checks the material of the east wall. If the east wall material is `noneWallMat`, it uses the material of the north wall instead. It then calls the `CreateCornerBeam` function with the determined material and the "East" direction to create the northeast corner beam.
---
--- @param self Room The room object.
function Room:RecreateNECornerBeam()
	local mat = self.east_wall_mat
	if mat == noneWallMat then
		mat = self.north_wall_mat
	end
	self:CreateCornerBeam("East", mat) --ne
end

---
--- Recreates the southeast corner beam of the room.
---
--- This function first checks the material of the south wall. If the south wall material is `noneWallMat`, it uses the material of the east wall instead. It then calls the `CreateCornerBeam` function with the determined material and the "South" direction to create the southeast corner beam.
---
--- @param self Room The room object.
function Room:RecreateSECornerBeam()
	local mat = self.south_wall_mat
	if mat == noneWallMat then
		mat = self.east_wall_mat
	end
	self:CreateCornerBeam("South", mat) --se
end

---
--- Creates all walls for the room.
---
--- This function suspends pass edits, creates the walls for each direction (North, South, West, East) using the corresponding wall material, checks the wall sizes, and then resumes pass edits.
---
--- @param self Room The room object.
function Room:CreateAllWalls()
	SuspendPassEdits("Room:CreateAllWalls")
	self:CreateWalls("North", self.north_wall_mat)
	self:CreateWalls("South", self.south_wall_mat)
	self:CreateWalls("West", self.west_wall_mat)
	self:CreateWalls("East", self.east_wall_mat)
	self:CheckWallSizes()
	ResumePassEdits("Room:CreateAllWalls")
end

---
--- Creates all slabs (walls, floor, and corners) for the room.
---
--- This function first suspends pass edits, then creates all walls, the floor, and all corners. If the room is not being placed, it also recreates the roof. Finally, it sets the warped state of the room and resumes pass edits.
---
--- @param self Room The room object.
function Room:CreateAllSlabs()
	SuspendPassEdits("Room:CreateAllSlabs")
	self:CreateAllWalls()
	self:CreateFloor()
	self:CreateAllCorners()
	if not self.being_placed then
		self:RecreateRoof()
	end
	self:SetWarped(self:GetWarped(), true)
	ResumePassEdits("Room:CreateAllSlabs")
end

---
--- Refreshes the combat status of all floor slabs in the room.
---
--- This function checks if the floor slabs are combat objects. If so, it sets the `impenetrable`, `invulnerable`, and `forceInvulnerableBecauseOfGameRules` properties of each floor slab based on whether the room is roof-only and the current floor level.
---
--- @param self Room The room object.
function Room:RefreshFloorCombatStatus()
	local floorsAreCO = g_Classes.CombatObject and IsKindOf(FloorSlab, "CombatObject")
	if not floorsAreCO then return end
	
	local flr = self.floor
	local val = not self:IsRoofOnly() and flr == 1
	for i = 1, #(self.spawned_floors or "") do
		local f = self.spawned_floors[i]
		if IsValid(f) then
			f.impenetrable = val
			f.invulnerable = val
			f.forceInvulnerableBecauseOfGameRules = val
		end
	end
end

---
--- Creates the floor for the room.
---
--- This function first calculates the starting position and size of the floor based on the room's position and size. It then creates or updates the floor slabs, setting their position, material, and combat properties. If the room has a zero height, the function deletes all the floor slabs and prints a message.
---
--- @param self Room The room object.
--- @param mat string The material to use for the floor slabs.
--- @param startI number The starting x-index for the floor slabs.
--- @param startJ number The starting y-index for the floor slabs.
function Room:CreateFloor(mat, startI, startJ)
	mat = mat or self.floor_mat
	self.spawned_floors = self.spawned_floors or {}
	local objs = self.spawned_floors
	
	local gz = self:CalcZ()
	local sx, sy = self.position:x(), self.position:y()
	local sizeX, sizeY, sizeZ = self.size:xyz()
	
	if sizeZ <= 0 then
		self:DeleteAllFloors()
		print("<color 0 255 38>Removed floor because it is a zero height room. </color>")
		return
	end
	
	sx = sx + halfVoxelSizeX
	sy = sy + halfVoxelSizeY
	startI = startI or 0
	startJ = startJ or 0
	
	if self:GetGameFlags(const.gofPermanent) ~= 0 then
		local floorBBox = box(sx, sy, gz, sx + voxelSizeX * (sizeX - 1), sy + voxelSizeY * (sizeY - 1), gz + 1)
		ComputeSlabVisibilityInBox(floorBBox)
	end
	
	SuspendPassEdits("Room:CreateFloor")
	local insertElements = startJ ~= 0 and #objs < sizeX * sizeY
	local floorsAreCO = g_Classes.CombatObject and IsKindOf(FloorSlab, "CombatObject")
	local floorsAreInvulnerable = floorsAreCO and not self:IsRoofOnly() and self.floor == 1
	for xOffset = startI, sizeX - 1 do
		for yOffset = xOffset == startI and startJ or 0, sizeY - 1 do
			local x = sx + xOffset * voxelSizeX
			local y = sy + yOffset * voxelSizeY
			local idx = xOffset * sizeY + yOffset + 1
			
			if insertElements then
				if #objs < idx then
					objs[idx] = false
				else
					table.insert(objs, idx, false)
				end
				
				insertElements = insertElements and #objs < sizeX * sizeY
			end
			
			local floor = objs[idx]
			if not IsValid(floor) then
				floor = FloorSlab:new{floor = self.floor, material = mat, side = "Floor", room = self}
				floor:SetPos(x, y, gz)
				floor:AlignObj()
				floor:UpdateEntity()
				floor:Setcolors(self.floor_colors)
				objs[idx] = floor
			else
				floor:SetPos(x, y, gz)
				if floor.material ~= mat then
					floor.material = mat
					floor:UpdateEntity()
				else
					floor:UpdateSimMaterialId()
				end
				
			end
			
			floor.floor = self.floor
			if floorsAreCO then --zulu specific
				floor.impenetrable = floorsAreInvulnerable
				floor.invulnerable = floorsAreInvulnerable
				floor.forceInvulnerableBecauseOfGameRules = floorsAreInvulnerable
			end
		end
	end
	ResumePassEdits("Room:CreateFloor")
	Msg("RoomCreatedFloor", self, mat)
end

---
--- Creates a corner beam for the specified direction and material.
---
--- @param dir string The direction of the corner beam, one of "North", "South", "West", or "East".
--- @param mat string The material to use for the corner beam.
---
function Room:CreateCornerBeam(dir, mat) --corner is next clockwise corner from dir
	self.spawned_corners = self.spawned_corners or {North = {}, South = {}, West = {}, East = {}}	
	local objs = self.spawned_corners[dir]
	
	if mat == defaultWallMat then
		mat = self.wall_mat
	end
	
	local gz = self:CalcSnappedZ()
	local sx, sy = self.position:x(), self.position:y()
	local sizeX, sizeY = self.size:x(), self.size:y()
	if dir == "South" or dir == "West" then
		sy = sy + sizeY * voxelSizeY
	end
	
	if dir == "South" or dir == "East" then
		sx = sx + sizeX * voxelSizeX
	end
	
	local count = self.size:z() + 1
	if count < #objs then
		for i = #objs, count + 1, -1 do
			DoneObject(objs[i])
			objs[i] = nil
		end
	end
	
	local isPermanent = self:GetGameFlags(const.gofPermanent) ~= 0
	local sz = self.size:z()

	if sz > 0 then
		for j = 0, sz do
			local z = gz + voxelSizeZ * Min(j, self.size:z() - 1)
			local pt = point(sx, sy, z)

			local obj = objs[j + 1]
			if not IsValid(obj) then
				obj = PlaceObject("RoomCorner", {room = self, side = dir, floor = self.floor, material = mat})
				objs[j + 1] = obj
			end
			obj.isPlug = j == self.size:z()
			obj:SetPos(pt)
			obj.material = mat
			obj.invulnerable = false
			obj.forceInvulnerableBecauseOfGameRules = false
			if not isPermanent then
				obj:UpdateEntity() --corners rely on ComputeSlabVisibilityInBox to update their ents
			end
		end
	end
	
	if isPermanent then
		local box = box(sx, sy, gz, sx, sy, gz + voxelSizeZ * (self.size:z() - 1))
		ComputeSlabVisibilityInBox(box)
	end
end

---
--- Returns the wall material for the specified side of the room.
---
--- @param side string The side of the room, one of "North", "South", "East", "West".
--- @return string|nil The wall material for the specified side, or `nil` if the side is invalid.
function Room:GetWallMatHelperSide(side)
	local m = dirToWallMatMember[side]
	return m and self:GetWallMatHelper(self[m]) or nil
end

---
--- Returns the wall material for the specified side of the room.
---
--- @param mat string The wall material to check.
--- @return string The wall material, using the default wall material if the provided material is nil.
function Room:GetWallMatHelper(mat)
	return mat == defaultWallMat and self.wall_mat or mat
end

---
--- Recalculates the restriction boxes for all decals, windows, and doors in the specified containers for the given wall direction.
---
--- @param dir string The wall direction, one of "North", "South", "East", "West".
--- @param containers table|nil A table of containers to process. If nil, an empty table is used.
---
function Room:RecalcAllRestrictionBoxes(dir, containers)
	local wallPos, wallSize, center = self:GetWallPos(dir)
	for j = 1, #(containers or empty_table) do
		local container = containers[j]
		local t = container and container[dir]
		
		--save fixup, idk how, sometimes decal lists have false entries
		for i = #(t or ""), 1, -1 do
			if type(t[i]) == "boolean" then
				table.remove(t, i)
				print("once", "Found badly saved decals/windows/doors!")
			end
		end
		
		if t and IsKindOf(t[1], "RoomDecal") then
			for i = 1, #(t or empty_table) do
				local o = t[i]
				if o then
					o.restriction_box = self:CalculateDecalRestrictionBox(dir, wallPos, wallSize)
					o:AlignObj()
				end
			end
		end
	end
end

---
--- Resizes the room by adjusting the position and size of all objects within it.
---
--- @param oldSize table The previous size of the room.
--- @param newSize table The new size of the room.
--- @param oldBox table The previous bounding box of the room.
---
function Room:Resize(oldSize, newSize, oldBox)
	if oldSize == newSize then
		return
	end
	
	SuspendPassEdits("Room:Resize")
	local delta = newSize - oldSize
	
	local offsetY = delta:y() * voxelSizeY
	local offsetX = delta:x() * voxelSizeX
	local offsetZ = delta:z() * voxelSizeZ
	local sx, sy = self.position:x(), self.position:y()
	sx = sx + halfVoxelSizeX
	sy = sy + halfVoxelSizeY
	local sizeX, sizeY = newSize:x(), newSize:y()
	
	local function moveObjs(objs)
		if not objs then return end
		for i = 1, #objs do
			local o = objs[i]
			if IsValid(o) then
				local x, y, z = o:GetPosXYZ()
				o:SetPos(x + offsetX, y + offsetY, z + offsetZ)
			end
		end
	end
	
	local function moveObjX(o)
		local x, y, z = o:GetPosXYZ()
		o:SetPos(x + offsetX, y, z)
		if IsKindOf(o, "SlabWallObject") then
			o:UpdateManagedObj()
		end
	end
	
	local function moveObjsX(objs)
		if not objs then return end
		for i = 1, #objs do
			local o = objs[i]
			if IsValid(o) then
				moveObjX(o)
			end
		end
	end
	
	local function moveObjY(o)
		local x, y, z = o:GetPosXYZ()
		o:SetPos(x, y + offsetY, z)
		if IsKindOf(o, "SlabWallObject") then
			o:UpdateManagedObj()
		end
	end
	
	local function moveObjsY(objs)
		if not objs then return end
		for i = 1, #objs do
			local o = objs[i]
			if IsValid(o) then
				moveObjY(o)
			end
		end
	end
	
	local function moveObjsZ(objs)
		if not objs then return end
		for i = 1, #objs do
			local o = objs[i]
			if IsValid(o) then
				local x, y, z = o:GetPosXYZ()
				o:SetPos(x, y, z + offsetZ)
			end
		end
	end
	
	if delta:y() ~= 0 then
		--south wall moves
		moveObjsY(self.spawned_walls and self.spawned_walls.South)
		moveObjsY(self.spawned_doors and self.spawned_doors.South)
		moveObjsY(self.spawned_windows and self.spawned_windows.South)
		if self.spawned_corners then
			moveObjsY(self.spawned_corners.South)
			moveObjsY(self.spawned_corners.West)
		end
		local containers = {self.spawned_doors, self.spawned_windows, self.spawned_decals}
		self:RecalcAllRestrictionBoxes("East", containers)
		self:RecalcAllRestrictionBoxes("West", containers)
		self:RecalcAllRestrictionBoxes("South", containers)
	end
	if delta:x() ~= 0 then
		--east wall moves
		moveObjsX(self.spawned_walls and self.spawned_walls.East)
		moveObjsX(self.spawned_doors and self.spawned_doors.East)
		moveObjsX(self.spawned_windows and self.spawned_windows.East)
		if self.spawned_corners then
			moveObjsX(self.spawned_corners.South)
			moveObjsX(self.spawned_corners.East)
		end
		local containers = {self.spawned_doors, self.spawned_windows, self.spawned_decals}
		self:RecalcAllRestrictionBoxes("North", containers)
		self:RecalcAllRestrictionBoxes("East", containers)
		self:RecalcAllRestrictionBoxes("South", containers)
	end
	
	if delta:z() ~= 0 then
		if delta:z() > 0 then
			local move = delta:x() ~= 0 or delta:y() ~= 0 --needs to reorder slabs so let it go through the entire wall
			self:CreateWalls("South", self.south_wall_mat, nil, not move and oldSize:z(), nil, nil, move)
			self:CreateWalls("North", self.north_wall_mat, nil, not move and oldSize:z(), nil, nil, move)
			self:CreateWalls("East", self.east_wall_mat, nil, not move and oldSize:z(), nil, nil, move)
			self:CreateWalls("West", self.west_wall_mat, nil, not move and oldSize:z(), nil, nil, move)
		else
			self:DestroyWalls("East", nil, oldSize, nil, newSize:z())
			self:DestroyWalls("West", nil, oldSize, nil, newSize:z())
			self:DestroyWalls("North", nil, oldSize, nil, newSize:z())
			self:DestroyWalls("South", nil, oldSize, nil, newSize:z())
		end
	end
	
	if delta:y() ~= 0 then
		if delta:y() < 0 then
			local count = abs(delta:y())
			self:DestroyWalls("East", count, oldSize:SetZ(newSize:z()))
			self:DestroyWalls("West", count, oldSize:SetZ(newSize:z()))
			
			
			local floors = self.spawned_floors
			for i = oldSize:x() - 1, 0, -1 do
				for j = oldSize:y() - 1, newSize:y(), -1 do
					local idx = (i * oldSize:y()) + j + 1
					local o = floors[idx]
					if o then
						DoneObject(o)
						table.remove(floors, idx)
					end
				end
			end			
		else
			if self.spawned_walls then
				local ew = self.spawned_walls.East
				local ww = self.spawned_walls.West
				if ew then
					self:CreateWalls("East", self.east_wall_mat, newSize:y() - delta:y())
				end
				if ww then
					self:CreateWalls("West", self.west_wall_mat, newSize:y() - delta:y())
				end
			end
			
			self:CreateFloor(self.floor_mat, 0, oldSize:y())
		end
	end
	
	if delta:x() ~= 0 then
		if delta:x() < 0 then
			local count = abs(delta:x())
			self:DestroyWalls("South", count, oldSize:SetZ(newSize:z()))
			self:DestroyWalls("North", count, oldSize:SetZ(newSize:z()))
						
			local floors = self.spawned_floors
			local nc = newSize:x() * newSize:y()
			local lc = #floors - nc
			for i = 1, lc do
				local idx = #floors
				local f = floors[idx]
				DoneObject(f)
				floors[idx] = nil
			end
		else
			if self.spawned_walls then
				local sw = self.spawned_walls.South
				local nw = self.spawned_walls.North
				if sw then
					self:CreateWalls("South", self.south_wall_mat, newSize:x() - delta:x())
				end
				if nw then
					self:CreateWalls("North", self.north_wall_mat, newSize:x() - delta:x())
				end
			end
			
			self:CreateFloor(self.floor_mat, oldSize:x())
		end
	end
	
	if oldSize:z() > 0 and newSize:z() <= 0 then
		self:DeleteAllFloors()
		self:DestroyCorners()
	elseif oldSize:z() <= 0 and newSize:z() > 0 then
		self:CreateFloor(self.floor_mat)
	end
	
	self:RecreateNECornerBeam()
	self:RecreateSECornerBeam()
	self:RecreateNWCornerBeam()
	self:RecreateSWCornerBeam()
	
	if not self.being_placed then
		self:RecreateRoof()
	end
	
	ResumePassEdits("Room:Resize")
	self:CheckWallSizes()
end

---
--- Destroys all corner objects associated with the room.
---
--- This function iterates through the `self.spawned_corners` table, which contains
--- lists of corner objects for each cardinal direction (North, South, East, West).
--- It then calls `DoneObjects()` on each list to destroy the objects, and sets the
--- corresponding table entries to empty tables.
---
--- @function Room:DestroyCorners
--- @return nil
function Room:DestroyCorners()
	for side, t in NSEW_pairs(self.spawned_corners or empty_table) do
		DoneObjects(t)
		self.spawned_corners[side] = {}
	end
end

---
--- Moves all spawned objects associated with the room by the specified offsets.
---
--- This function iterates through the various tables of spawned objects (floors, walls,
--- corners, doors, windows, decals) and moves each object by the specified offsets.
--- It also recalculates the restriction boxes for the doors, windows, and decals after
--- moving them.
---
--- @param dvx Number The x-axis offset to move the objects by.
--- @param dvy Number The y-axis offset to move the objects by.
--- @param dvz Number The z-axis offset to move the objects by.
--- @return nil
function Room:MoveAllSpawnedObjs(dvx, dvy, dvz)
	local offsetX = dvx * voxelSizeX
	local offsetY = dvy * voxelSizeY
	local offsetZ = dvz * voxelSizeZ

	if offsetX == 0 and offsetY == 0 and offsetZ == 0 then
		return
	end
	
	SuspendPassEdits("Room:MoveAllSpawnedObjs")
	local function move(o)
		if not IsValid(o) then return end
		local x, y, z = o:GetPosXYZ()
		o:SetPos(x + offsetX, y + offsetY, z + offsetZ)
		--align should not be required, omitted for performance
	end
	
	local function move_window(o)
		if not IsValid(o) then return end
		local x, y, z = o:GetPosXYZ()
		o:SetPos(x + offsetX, y + offsetY, z + offsetZ)
		o:AlignObj() --specifically so small windows realign managed slabs, t.t
	end
	
	local function iterateNSWETable(t, m)
		m = m or move
		for _, st in NSEW_pairs(t or empty_table) do
			for i = 1, #st do
				local o = st[i]
				m(o)
			end
		end
	end
	
	for i = 1, #(self.spawned_floors or empty_table) do
		move(self.spawned_floors[i])
	end
	
	iterateNSWETable(self.spawned_walls)
	iterateNSWETable(self.spawned_corners)
	for i = 1, #(self.roof_objs or empty_table) do
		move(self.roof_objs[i])
	end
	-- move doors & windows after roof_objs, otherwise doors & windows won't find their "main_wall"
	iterateNSWETable(self.spawned_doors)
	iterateNSWETable(self.spawned_windows, move_window)
	iterateNSWETable(self.spawned_decals)
	
	local containers = {self.spawned_doors, self.spawned_windows, self.spawned_decals}
	self:RecalcAllRestrictionBoxes("East", containers)
	self:RecalcAllRestrictionBoxes("West", containers)
	self:RecalcAllRestrictionBoxes("South", containers)
	self:RecalcAllRestrictionBoxes("North", containers)

	ResumePassEdits("Room:MoveAllSpawnedObjs")
end

---
--- Destroys walls in the specified direction of the room.
---
--- @param dir string The direction of the walls to destroy ("North", "East", "South", "West")
--- @param count? number The number of walls to destroy (default is the full length of the wall)
--- @param size? Vector3 The size of the room (default is the room's size)
--- @param startJ? number The starting index of the wall slabs to destroy (default is the full height of the wall)
--- @param endJ? number The ending index of the wall slabs to destroy (default is 0)
function Room:DestroyWalls(dir, count, size, startJ, endJ)
	local objs = self.spawned_walls and self.spawned_walls[dir]
	local wnd = self.spawned_windows and self.spawned_windows[dir]
	local doors = self.spawned_doors and self.spawned_doors[dir]
	local len = 0
	local offsX = 0
	local flatOffsX = 0
	local offsY = 0
	local flatOffsY = 0
	local sx, sy = self.position:x(), self.position:y()
	local mat
	sx = sx + halfVoxelSizeX
	sy = sy + halfVoxelSizeY
	size = size or self.size
	
	if dir == "North" then
		len = size:x()
		mat = self:GetWallMatHelper(self.north_wall_mat)
		offsX = voxelSizeX
		flatOffsY = -voxelSizeY / 2
	elseif dir == "East" then
		len = size:y()
		mat = self:GetWallMatHelper(self.east_wall_mat)
		flatOffsX = voxelSizeX / 2
		offsY = voxelSizeY
		sx = sx + (size:x() - 1) * voxelSizeX
	elseif dir == "South" then
		len = size:x()
		mat = self:GetWallMatHelper(self.south_wall_mat)
		offsX = voxelSizeX
		flatOffsY = voxelSizeY / 2
		sy = sy + (size:y() - 1) * voxelSizeY
	elseif dir == "West" then
		len = size:y()
		mat = self:GetWallMatHelper(self.west_wall_mat)
		flatOffsX = -voxelSizeX / 2
		offsY = voxelSizeY
	end
	startJ = startJ or size:z()
	endJ = endJ or 0
	count = count or len
	local gz = self:CalcZ()
	
	SuspendPassEdits("Room:DestroyWalls")
	
	self:SortWallObjs(doors or empty_table, dir)
	self:SortWallObjs(wnd or empty_table, dir)
	
	for i = len - 1, len - count, -1 do
		for j = startJ - 1, endJ, -1 do
			if endJ == 0 then
				--clear wind/door
				local px = sx + i * offsX + flatOffsX
				local py = sy + i * offsY + flatOffsY
				local pz = gz + j * voxelSizeZ
				local p = point(px, py, pz)
			end
			
			if objs and #objs > 0 then
				local idx = i * size:z() + j + 1
				local o = objs[idx]
				DoneObject(o)
				if #objs >= idx then
					table.remove(objs, idx)
				end
			end
		end
	end
	
	local containers = {self.spawned_decals}
	self:RecalcAllRestrictionBoxes(dir, containers)
	self:TouchWallsAndWindows(dir)
	ResumePassEdits("Room:DestroyWalls")
	Msg("RoomDestroyedWall", self, dir)
end

--- Gets the position of a wall slab for the given direction and index.
---
--- @param dir string The direction of the wall, one of "North", "South", "West", or "East".
--- @param idx number The index of the wall slab, starting from 1.
--- @return number, number, number The x, y, and z coordinates of the wall slab position.
function Room:GetWallSlabPos(dir, idx)
	local x, y, z = self.position:xyz()
	local sizeX, sizeY, sizeZ = self.size:xyz()
	
	assert(voxelSizeX == voxelSizeY)
	local offs = ((idx - 1) / sizeZ) * voxelSizeX + halfVoxelSizeX
	z = z + ((idx - 1) % sizeZ) * voxelSizeZ
	
	if dir == "North" then
		x = x + offs
	elseif dir == "South" then
		x = x + offs
		y = y + sizeY * voxelSizeY
	elseif dir == "West" then
		y = y + offs
	else --dir == "East"
		y = y + offs
		x = x + sizeX * voxelSizeX
	end
	
	return x, y, z
end

--- Calls the `TestWallPositions` function for each of the four cardinal directions: "North", "South", "West", and "East".
---
--- This function is used to test the positions of all the walls in the room.
function Room:TestAllWallPositions()
	self:TestWallPositions("North")
	self:TestWallPositions("South")
	self:TestWallPositions("West")
	self:TestWallPositions("East")
end

--- Tests the positions of all the walls in the room for the given direction.
---
--- This function is used to check the positions of all the wall slabs in the specified direction to ensure they are correctly placed.
---
--- @param dir string The direction of the walls to test, one of "North", "South", "West", or "East".
function Room:TestWallPositions(dir)
	self.spawned_walls = self.spawned_walls or {North = {}, South = {}, East = {}, West = {}}
	dir = dir or "North"
	local objs = self.spawned_walls[dir]
	
	local gz = self:CalcZ()
	local angle = 0
	local sx, sy = self.position:x(), self.position:y()
	--local size = oldSize or self.size
	local size = self.size
	local sizeX, sizeY, sizeZ = size:x(), size:y(), size:z()
	local offsx = 0
	local offsy = 0
	
	local endI = (dir == "North" or dir == "South") and sizeX or sizeY
	local endJ = sizeZ
	local startI = 0
	local startJ = 0
	
	if dir == "North" then
		angle = 270 * 60
		offsx = voxelSizeX
		sx = sx + halfVoxelSizeX
	elseif dir == "East" then
		angle = 0
		offsy = voxelSizeY
		sx = sx + sizeX * voxelSizeX
		sy = sy + halfVoxelSizeY
	elseif dir == "South" then
		angle = 90 * 60
		offsx = voxelSizeX
		sy = sy + sizeY * voxelSizeY
		sx = sx + halfVoxelSizeX
	elseif dir == "West" then
		angle = 180 * 60
		offsy = voxelSizeY
		sy = sy + halfVoxelSizeY
	end
	
	local insertElements = startJ ~= 0 and #objs < ((dir == "North" or dir == "South") and sizeX or sizeY) * sizeZ
	
	for i = startI, endI - 1 do
		for j = startJ, endJ - 1 do
			local px = sx + i * offsx
			local py = sy + i * offsy
			local z = gz + j * voxelSizeZ
			local idx = i * sizeZ + j + 1
			
			local s = objs[idx]
			if not s or s:GetPos() ~= point(px, py, z) then
				print(dir, idx)
			end
		end
	end
end

---
--- Creates walls for a room in the specified direction.
---
--- @param dir string The direction of the walls to create ("North", "South", "East", "West")
--- @param mat string The material to use for the walls (default is "Planks")
--- @param startI number The starting index in the X or Y dimension (default is 0)
--- @param startJ number The starting index in the Z dimension (default is 0)
--- @param endI number The ending index in the X or Y dimension (default is the size of the room in that dimension)
--- @param endJ number The ending index in the Z dimension (default is the size of the room in the Z dimension)
--- @param move boolean Whether to move the existing wall objects to their new positions (default is false)
--- @return void
---
function Room:CreateWalls(dir, mat, startI, startJ, endI, endJ, move)
	self.spawned_walls = self.spawned_walls or {North = {}, South = {}, East = {}, West = {}}
	mat = mat or "Planks"
	dir = dir or "North"
	local objs = self.spawned_walls[dir]
	
	if mat == defaultWallMat then
		mat = self.wall_mat
	end
	
	local oppositeDir = nil
	local gz = self:CalcZ()
	local angle = 0
	local sx, sy = self.position:x(), self.position:y()
	local size = self.size
	local sizeX, sizeY, sizeZ = size:x(), size:y(), size:z()
	local offsx = 0
	local offsy = 0
	
	endI = endI or (dir == "North" or dir == "South") and sizeX or sizeY
	endJ = endJ or sizeZ
	startI = startI or 0
	startJ = startJ or 0
	
	if dir == "North" then
		angle = 270 * 60
		offsx = voxelSizeX
		sx = sx + halfVoxelSizeX
		oppositeDir = "South"
	elseif dir == "East" then
		angle = 0
		offsy = voxelSizeY
		sx = sx + sizeX * voxelSizeX
		sy = sy + halfVoxelSizeY
		oppositeDir = "West"
	elseif dir == "South" then
		angle = 90 * 60
		offsx = voxelSizeX
		sy = sy + sizeY * voxelSizeY
		sx = sx + halfVoxelSizeX
		oppositeDir = "North"
	elseif dir == "West" then
		angle = 180 * 60
		offsy = voxelSizeY
		sy = sy + halfVoxelSizeY
		oppositeDir = "East"
	end
	
	if self:GetGameFlags(const.gofPermanent) ~= 0 then
		local wallBBox = self:GetWallBox(dir)
		ComputeSlabVisibilityInBox(wallBBox)
	end
	
	SuspendPassEdits("Room:CreateWalls")
	local insertElements = startJ ~= 0 and #objs < ((dir == "North" or dir == "South") and sizeX or sizeY) * sizeZ
	local forceUpdate = self.last_wall_recreate_seed ~= self.seed
	local isLoadingMap = IsChangingMap()
	local affectedRooms = {}
	
	for i = startI, endI - 1 do
		for j = startJ, endJ - 1 do
			local px = sx + i * offsx
			local py = sy + i * offsy
			local z = gz + j * voxelSizeZ
			local idx = i * sizeZ + j + 1
			local m = mat
			
			if insertElements then
				if idx > #objs then
					objs[idx] = false --Happens when resizing in (x or y) ~= 0 and z ~= 0 in the same time. Fill it in, second pass will fill in the missing ones without breaking integrity, probably..
				else
					table.insert(objs, idx, false)
				end
			end
			
			local wall = objs[idx]
			if not IsValid(wall) then
				wall = WallSlab:new{floor = self.floor, material = m, room = self, side = dir, 
										variant = self.inner_wall_mat ~= noneWallMat and "OutdoorIndoor" or "Outdoor", indoor_material_1 = self.inner_wall_mat}
				wall:SetAngle(angle)
				wall:SetPos(px, py, z)
				wall:AlignObj()
				wall:UpdateEntity()
				wall:UpdateVariantEntities()
				
				wall:Setcolors(self.outer_colors)
				wall:Setinterior_attach_colors(self.inner_colors)
				wall.invulnerable = false
				wall.forceInvulnerableBecauseOfGameRules = false
				objs[idx] = wall
			else
				if move then
					--sometimes if we change both z and x or y sizing at the same time we end up with the same number of slabs per wall but they need to be re-arranged.
					wall:SetAngle(angle)
					local op = wall:GetPos()
					wall:SetPos(px, py, z)
					if op ~= wall:GetPos() and wall.wall_obj then
						local o = wall.wall_obj
						o:RestoreAffectedSlabs()
					end
					wall:AlignObj()
				end
				wall:UpdateSimMaterialId()
			end
			
			if not isLoadingMap then
				if forceUpdate or wall.material ~= m or wall.indoor_material_1 ~= self.inner_wall_mat then
					wall.material = m
					wall.indoor_material_1 = self.inner_wall_mat
					wall:UpdateEntity()
					wall:UpdateVariantEntities()
				end
			end
		end
	end
	
	affectedRooms[self] = nil
	for room, isMySide in pairs(affectedRooms) do
		if IsValid(room) then
			local d = isMySide and dir or oppositeDir
			room:TouchWallsAndWindows(d)
			room:TouchCorners(d)
		end
	end
	
	self:TouchWallsAndWindows(dir)
	self:TouchCorners(dir)
	ResumePassEdits("Room:CreateWalls")
	Msg("RoomCreatedWall", self, dir, mat)
end

local postComputeBatch = false
---
--- Sets the inner material and colors of the roof objects in the room.
---
--- This function iterates through the `roof_objs` table and updates the `indoor_material_1` and `interior_attach_colors` properties of each valid `WallSlab` object. It also keeps track of any `wall_obj` instances that need to be processed after the `ComputeSlabVisibilityInBox` call.
---
--- @param self Room The room instance.
function Room:SetInnerMaterialToRoofObjs()
	local objs = self.roof_objs
	if not objs or #objs <= 0 then return end
	
	local passedSWO = {}
	local col = self.inner_colors
	for i = 1, #objs do
		local o = objs[i]
		if IsValid(o) and IsKindOf(o, "WallSlab") then
			if o.indoor_material_1 ~= self.inner_wall_mat then
				o.indoor_material_1 = self.inner_wall_mat
				o:UpdateVariantEntities()
			end
			o:Setinterior_attach_colors(col)
			
			local swo = o.wall_obj
			if swo and not passedSWO[swo] then
				passedSWO[swo] = true
			end
		end
	end
	
	if next(passedSWO) then
		--in some cases slabs need to recalibrate in computeslabvisibility, we need to pass after that
		postComputeBatch = postComputeBatch or {}
		postComputeBatch[#postComputeBatch + 1] = passedSWO
	end
	
	ComputeSlabVisibilityInBox(self.roof_box)
end

---
--- Sets the inner material and colors of the wall and corner objects in the room.
---
--- This function iterates through the `spawned_walls` and `spawned_corners` tables for the given `dir` and updates the `indoor_material_1` and `interior_attach_colors` properties of each valid `WallSlab` object. It also keeps track of any `wall_obj` instances that need to be processed after the `ComputeSlabVisibilityInBox` call.
---
--- @param self Room The room instance.
--- @param dir string The direction of the walls and corners to update.
function Room:SetInnerMaterialToSlabs(dir)
	local objs = self.spawned_walls and self.spawned_walls[dir]
	local gz = self:CalcZ()
	local sizeX, sizeY = self.size:x(), self.size:y()
	local endI = (dir == "North" or dir == "South") and sizeX or sizeY
	local passedSWO = {}
	local wallBBox = box()
	local col = self.inner_colors
	if objs then
		for i = 0, endI - 1 do
			for j = 0, self.size:z() - 1 do
				local idx = i * self.size:z() + j + 1
				local o = objs[idx]
				if IsValid(o) then
					wallBBox = Extend(wallBBox, o:GetPos())
					if o.indoor_material_1 ~= self.inner_wall_mat then
						o.indoor_material_1 = self.inner_wall_mat
						o:UpdateVariantEntities()
					end
					o:Setinterior_attach_colors(col)
					
					local swo = o.wall_obj
					if swo and not passedSWO[swo] then
						passedSWO[swo] = true
					end
				end
			end
		end
	end
	
	objs = self.spawned_corners[dir]
	for i = 1, #(objs or "") do
		if IsValid(objs[i]) then --can be gone
			objs[i]:SetColorFromRoom()
		end
	end
	
	if next(passedSWO) then
		--in some cases slabs need to recalibrate in computeslabvisibility, we need to pass after that
		postComputeBatch = postComputeBatch or {}
		postComputeBatch[#postComputeBatch + 1] = passedSWO
	end
	
	if self:GetGameFlags(const.gofPermanent) ~= 0 then
		ComputeSlabVisibilityInBox(wallBBox)
	end
	self:CreateAllCorners()
end

function OnMsg.SlabVisibilityComputeDone()
	if not postComputeBatch then return end
	
	local allPassed = {}
	for i, batch in ipairs(postComputeBatch) do
		for swo, _ in pairs(batch) do
			if not allPassed[swo] then
				allPassed[swo] = true
				swo:UpdateManagedSlabs()
				swo:UpdateManagedObj()
				swo:RefreshColors()
			end
		end
	end
	postComputeBatch = false
end

---
--- Aligns and updates the specified objects.
---
--- @param objs table|nil A table of objects to process.
---
function TouchWallsAndWindowsHelper(objs)
	if not objs then return end
	table.validate(objs)
	for i = #(objs or empty_table), 1, -1 do
		local o = objs[i]
		o:AlignObj()
		if o.room == false then
			DoneObject(o)
		else
			o:UpdateSimMaterialId()
		end
	end
end

---
--- Aligns and updates the specified objects.
---
--- @param side string The side of the room to touch walls and windows for.
---
function Room:TouchWallsAndWindows(side)
	TouchWallsAndWindowsHelper(self.spawned_doors and self.spawned_doors[side])
	TouchWallsAndWindowsHelper(self.spawned_windows and self.spawned_windows[side])
end

---
--- Touches the corners of a room based on the specified side.
---
--- @param side string The side of the room to touch the corners for.
---
function Room:TouchCorners(side)
	if side == "North" then
		self:RecreateNECornerBeam()
		self:RecreateNWCornerBeam()
	elseif side == "South" then
		self:RecreateSECornerBeam()
		self:RecreateSWCornerBeam()
	elseif side == "East" then
		self:RecreateSECornerBeam()
		self:RecreateNECornerBeam()
	elseif side == "West" then
		self:RecreateSWCornerBeam()
		self:RecreateNWCornerBeam()
	end
end

---
--- Centers the camera on the specified room object.
---
--- @param socket table|nil The socket object (unused).
--- @param obj Room The room object to center the camera on.
---
function GedOpViewRoom(socket, obj)
	if IsValid(obj) then
		Room.CenterCameraOnMe(nil, obj)
	else
		print("No room selected.")
	end
end

---
--- Prints a message indicating that the GedOpNewVolume function is no longer supported, and that the user should use the f3 -> map -> new room or ctrl+shift+n methods instead.
---
--- @param socket table|nil The socket object (unused).
--- @param obj table The object for which the new volume is being created (unused).
---
function GedOpNewVolume(socket, obj)
	print("Use f3 -> map -> new room or ctrl+shift+n instead. This method is no longer supported.")
end

---
--- Selects the specified wall of the room.
---
--- @param side string The side of the room to select the wall for. Can be "North", "South", "East", or "West".
---
function Room:SelectWall(side)
	self:ClearBoldedMarker()
	self.selected_wall = side
	local m = self.text_markers[side]
	m:SetTextStyle("EditorTextBold")
	m:SetColor(RGB(0, 255, 0))
	ObjModified(self)
end

---
--- Centers the camera on the specified room object.
---
--- @param self Room The room object to center the camera on.
---
function Room:ViewNorthWallFromOutside()
	self:SelectWall("North")
	self:ViewWall("North")
	ObjModified(self)
end

---
--- Centers the camera on the south wall of the specified room object.
---
--- @param self Room The room object to center the camera on the south wall.
---
function Room:ViewSouthWallFromOutside()
	self:SelectWall("South")
	self:ViewWall("South")
	ObjModified(self)
end

---
--- Centers the camera on the west wall of the specified room object.
---
--- @param self Room The room object to center the camera on the west wall.
---
function Room:ViewWestWallFromOutside()
	self:SelectWall("West")
	self:ViewWall("West")
	ObjModified(self)
end

---
--- Centers the camera on the east wall of the specified room object.
---
--- @param self Room The room object to center the camera on the east wall.
---
function Room:ViewEastWallFromOutside()
	self:SelectWall("East")
	self:ViewWall("East")
	ObjModified(self)
end

---
--- Clears the bolded marker for the currently selected wall.
---
--- If a wall is currently selected, this function will set the text style of the
--- corresponding text marker to "EditorText" and the color to red (RGB(255, 0, 0)).
---
function Room:ClearBoldedMarker()
	if self.selected_wall then
		local m = self.text_markers[self.selected_wall]
		m:SetTextStyle("EditorText")
		m:SetColor(RGB(255, 0, 0))
	end
end

---
--- Clears the currently selected wall for the room object.
---
--- This function will:
--- - Clear the bolded marker for the currently selected wall
--- - Set the `selected_wall` field of the room object to `false`
--- - Call `ObjModified(self)` to notify the system that the room object has been modified
---
--- @param self Room The room object to clear the selected wall for.
---
function Room:ClearSelectedWall()
	self:ClearBoldedMarker()
	self.selected_wall = false
	ObjModified(self)
end

---
--- Gets the currently selected room.
---
--- If there are any rooms selected, this function will return the first selected room.
--- Otherwise, it will return the currently selected volume.
---
--- @return Room|nil The currently selected room, or nil if no room is selected.
---
function GetSelectedRoom()
	--find a selected room..
	return SelectedRooms and SelectedRooms[1] or SelectedVolume
end

---
--- Clears the currently selected wall for the room object.
---
--- This function will:
--- - Clear the bolded marker for the currently selected wall
--- - Set the `selected_wall` field of the room object to `false`
--- - Call `ObjModified(self)` to notify the system that the room object has been modified
---
--- @param self Room The room object to clear the selected wall for.
---
function SelectedRoomClearSelectedWall()
	local r = GetSelectedRoom()
	if IsValid(r) then
		r:ClearSelectedWall()
		print("Cleared selected wall")
	else
		print("No selected room found!")
	end
end

---
--- Selects the specified wall for the currently selected room.
---
--- This function will:
--- - Set the `selected_wall` field of the room object to the specified `side`
--- - Call `ObjModified(self)` to notify the system that the room object has been modified
---
--- @param self Room The room object to select the wall for.
--- @param side string The side of the wall to select. Can be one of "Front", "Back", "Left", or "Right".
---
function SelectedRoomSelectWall(side)
	local r = GetSelectedRoom()
	if IsValid(r) then
		r:SelectWall(side)
		print(string.format("Selected wall %s of room %s", side, r.name))
	else
		print("No selected room found!")
	end
end

---
--- Resets the wall materials for the currently selected room.
---
--- If a wall is currently selected, this function will reset the material for that wall to the default wall material.
--- If no wall is selected, this function will reset all wall materials for the room to the default wall material.
---
--- This function will:
--- - Get the currently selected room using `GetSelectedRoom()`
--- - If a wall is selected, get the material member name for that wall side and reset the material to the default
--- - If no wall is selected, call `ResetWallMaterials()` on the room to reset all wall materials
--- - Call `ObjModified(self)` to notify the system that the room object has been modified
---
--- @param self Room The room object to reset the wall materials for.
---
function SelectedRoomResetWallMaterials()
	local r = GetSelectedRoom()
	if IsValid(r) then
		if r.selected_wall then
			local side = r.selected_wall
			local matMember = string.format("%s_wall_mat", string.lower(side))
			local curMat = r[matMember]
			if curMat ~= defaultWallMat then
				r[matMember] = defaultWallMat
				local matPostSetter = string.format("OnSet%s", matMember)
				r[matPostSetter](r, defaultWallMat, curMat)
			end
		else
			r:ResetWallMaterials()
			print(string.format("Reset wall materials."))
		end
	else
		print("No selected room found!")
	end
end

---
--- Cycles the wall material for the currently selected room.
---
--- If a wall is currently selected, this function will cycle the material for that wall.
--- If no wall is selected, this function will cycle the material for all walls in the room.
---
--- This function will:
--- - Get the currently selected room using `GetSelectedRoom()`
--- - Determine the appropriate material member name based on whether a wall is selected
--- - Get the current material for the wall(s)
--- - Cycle to the next material in the list of available materials
--- - Set the new material on the room object and call the appropriate post-setter function
--- - Print a message indicating the new material that was set
---
--- @param self Room The room object to cycle the wall material for.
--- @param delta number The direction to cycle the material (1 for next, -1 for previous).
--- @param side string The side of the wall to cycle the material for (optional).
---
function Room:CycleWallMaterial(delta, side)
	local mats
	local matMember = "wall_mat"
	if side then
		mats = SlabMaterialComboItemsWithDefault()()
		matMember = string.format("%s_wall_mat", string.lower(side))
	else
		mats = SlabMaterialComboItemsWithNone()()
	end
	local matPostSetter = string.format("OnSet%s", matMember)
	local curMat = self[matMember]
	local idx = table.find(mats, curMat) or 1
	local newIdx = idx + delta
	if newIdx > #mats then
		newIdx = 1
	elseif newIdx <= 0 then
		newIdx = #mats
	end
	local newMat = mats[newIdx]
	self[matMember] = newMat
	self[matPostSetter](self, newMat, curMat)
	print(string.format("Changed wall material of room %s side %s new material %s", self.name, side or "all", newMat))
end

---
--- Cycles the wall material for the currently selected room.
---
--- If a wall is currently selected, this function will cycle the material for that wall.
--- If no wall is selected, this function will cycle the material for all walls in the room.
---
--- @param self Room The room object to cycle the wall material for.
--- @param delta number The direction to cycle the material (1 for next, -1 for previous).
---
function Room:CycleEntity(delta)
	local sw = self.selected_wall
	if not sw then
		self:CycleWallMaterial(delta)
		return
	end
	self:CycleWallMaterial(delta, sw)
end

--- Deletes all the doors that have been spawned in the room.
---
--- This function will remove all the door objects that have been spawned in the room, using the list of spawned doors stored in the `spawned_doors` table. If a specific wall is selected, it will only delete the doors associated with that wall.
---
--- @param self Room The room object to delete the doors from.
function Room:UIDeleteDoors()
	self:DeleteWallObjs(self.spawned_doors, self.selected_wall)
end

---
--- Deletes all the windows that have been spawned in the room.
---
--- This function will remove all the window objects that have been spawned in the room, using the list of spawned windows stored in the `spawned_windows` table. If a specific wall is selected, it will only delete the windows associated with that wall.
---
--- @param self Room The room object to delete the windows from.
function Room:UIDeleteWindows()
	self:DeleteWallObjs(self.spawned_windows, self.selected_wall)
end

local decalIdPrefix = "decal_lst_"
---
--- Deletes a decal from the room.
---
--- This function removes a decal from the room's `spawned_decals` table for the currently selected wall. It finds the decal by its handle, removes it from the table, and marks it for safe deletion.
---
--- @param self Room The room object to delete the decal from.
--- @param gedRoot table The GED root object.
--- @param prop_id string The ID of the decal to delete.
---
function Room:UIDeleteDecal(gedRoot, prop_id)
	local sh = string.gsub(prop_id, decalIdPrefix, "")
	local h = tonumber(sh)
	
	local t = self.spawned_decals[self.selected_wall]
	local idx = table.find(t, "handle", h)
	if idx then
		local d = t[idx]
		table.remove(t, idx)
		rawset(d, "safe_deletion", true)
		DoneObject(d)
		ObjModified(self)
	end
end

---
--- Selects a decal in the room.
---
--- This function finds the decal in the `spawned_decals` table for the currently selected wall, based on the provided `prop_id`. If the decal is found, it is added to the editor's selection.
---
--- @param self Room The room object containing the decal.
--- @param gedRoot table The GED root object.
--- @param prop_id string The ID of the decal to select.
---
function Room:UISelectDecal(gedRoot, prop_id)
	local sh = string.gsub(prop_id, decalIdPrefix, "")
	local h = tonumber(sh)
	
	local t = self.spawned_decals[self.selected_wall]
	local idx = table.find(t, "handle", h)
	if idx then
		local d = t[idx]
		if d then
			editor.ClearSel()
			editor.AddToSel({d})
		end
	end
end

---
--- Gets the position and size of a wall in the room.
---
--- This function calculates the position and size of a wall in the room based on the provided direction and optional z-offset.
---
--- @param self Room The room object.
--- @param dir string The direction of the wall ("North", "South", "West", "East").
--- @param zOffset number (optional) The z-offset to apply to the wall position.
--- @return point, number, point The wall position, wall size, and room position.
---
function Room:GetWallPos(dir, zOffset)
	local wallSize, wallPos
	local wsx = self.size:x() * voxelSizeX
	local wsy = self.size:y() * voxelSizeY
	local pos = self:GetPos()
	if zOffset then
		pos = pos:SetZ(pos:z() + zOffset)
	end
	
	if dir == "North" then
		wallPos = point(pos:x(), pos:y() - wsy / 2, pos:z())
		wallSize = wsx
	elseif dir == "South" then
		wallPos = point(pos:x(), pos:y() + wsy / 2, pos:z())
		wallSize = wsx
	elseif dir == "West" then
		wallPos = point(pos:x() - wsx / 2, pos:y(), pos:z())
		wallSize = wsy
	elseif dir == "East" then
		wallPos = point(pos:x() + wsx / 2, pos:y(), pos:z())
		wallSize = wsy
	end
	
	return wallPos, wallSize, pos
end

---
--- Views a wall in the room from a specified direction.
---
--- This function calculates the position and size of a wall in the room based on the provided direction and optional z-offset, and sets the camera to view the wall.
---
--- @param self Room The room object.
--- @param dir string The direction of the wall ("North", "South", "West", "East").
--- @param inside boolean (optional) Whether to view the wall from the inside or outside of the room.
---
function Room:ViewWall(dir, inside)
	dir = dir or "North"
	local wallPos, wallSize, pos = self:GetWallPos(dir, self.size:z() * voxelSizeZ / 2)
	
	--fit wall to screen
	local fovX = camera.GetFovX()
	local a = (180 * 60 - fovX) / 2
	local wallWidth = wallSize
	local s = MulDivRound(wallWidth, sin(a), sin(fovX))
	local x = wallWidth / 2
	local dist = sqrt(s * s - x * x)
	
	local fovY = camera.GetFovY()
	a = (180 * 60 - fovY) / 2
	local wallHeight = self.size:z() * voxelSizeZ
	s = MulDivRound(wallHeight, sin(a), sin(fovY))
	x = wallHeight / 2
	dist = Max(sqrt(s * s - x * x), dist)
	
	local offset
	if inside then
		offset = pos - wallPos
	else
		offset = wallPos - pos
	end
	
	dist = dist + 3 * guim --some x margin so wall edge is not stuck to the screen edge
	offset = SetLen(offset, dist)
	offset = offset:SetZ(offset:z() + self.size:z() * voxelSizeZ * 3) --move eye up a little bit
	
	local cPos, cLookAt, cType = GetCamera()
	local cam = _G[string.format("camera%s", cType)]
	cam.SetCamera(wallPos + offset, wallPos, 1000, "Cubic out")
	
	if rawget(terminal, "BringToTop") then
		return terminal.BringToTop()
	end
end

---
--- Centers the camera on the room object.
---
--- This function calculates the camera position and orientation to center the camera on the room object. The camera is positioned at a distance from the room that is proportional to the room's size, and the camera looks at the center of the room.
---
--- @param self Room The room object.
---
function Room.CenterCameraOnMe(_, self)
	local cPos, cLookAt, cType = GetCamera()
	local cOffs = cPos - cLookAt
	local mPos = self:GetPos()
	local cam = _G[string.format("camera%s", cType)]
	if cType == "Max" then
		local len = 20*guim * ((Max(self.size:x(), self.size:y()) / 10) + 1)
		cOffs = SetLen(cOffs, len)
	end
	cam.SetCamera(mPos + cOffs, mPos, 1000, "Cubic out")
	
	if rawget(terminal, "BringToTop") then
		return terminal.BringToTop()
	end
end

local defaultDecalProp = { category = "Materials", id = decalIdPrefix, name = "Decal ", editor = "text", default = "", read_only = true,
										buttons = {
											{name = "Delete", func = "UIDeleteDecal"},
											{name = "Select", func = "UISelectDecal"},
										},}

local function AddDecalPropsFromContainerHelper(self, props, container, idx, defaultProp)
	for i = 1, #container do
		local np = table.copy(defaultProp)
		local obj = container[i]
		np.id = string.format("%s%s", np.id, obj.handle)
		np.name = string.format("%s%s", np.name, obj:GetEntity())
		
		table.insert(props, idx + i, np)
	end
end

---
--- Returns the properties of the room, including any decals attached to the selected wall.
---
--- If there are any decals attached to the selected wall, the function will create a copy of the room's properties and add the decal properties to the copy. Otherwise, it will simply return the room's properties.
---
--- @param self Room The room object.
--- @return table The properties of the room, including any decal properties.
---
function Room:GetProperties()
	local decals = self.spawned_decals and self.spawned_decals[self.selected_wall]
	
	if #(decals or empty_table) > 0 then
		local p = table.copy(self.properties)
		
		if decals then
			local idx = table.find(p, "id", "place_decal")
			AddDecalPropsFromContainerHelper(self, p, decals, idx, defaultDecalProp)
		end
		
		return p
	else
		return self.properties
	end
end

---
--- Generates a unique name for a room object.
---
--- The name is generated in the format "Room %d%s", where %d is the handle of the room object, and %s is either an empty string or " - Roof only" if the room is a roof-only room.
---
--- @param self Room The room object.
--- @return string The generated name for the room.
---
function Room:GenerateName()
	return string.format("Room %d%s", self.handle, self:IsRoofOnly() and " - Roof only" or "")
end

---
--- Initializes a Room object.
---
--- This function sets the name of the Room object, and if the `auto_add_in_editor` flag is set, it adds the Room object to the editor.
---
--- @param self Room The Room object to initialize.
---
function Room:Init()
	self.name = self.name or self:GenerateName()
	
	if self.auto_add_in_editor then
		self:AddInEditor()
	end
end

---
--- Computes the visibility of nearby shelters.
---
--- This function is a stub and does not currently implement any functionality.
---
--- @param box table The bounding box of the room.
---
function ComputeVisibilityOfNearbyShelters()
	--stub
end

---
--- Clears the room adjacency data.
---
--- This function calls `ClearAdjacencyData()` on the room object to clear any adjacency data associated with the room.
---
--- @param self Room The room object.
---
function Room:ClearRoomAdjacencyData()
	self:ClearAdjacencyData()
end

---
--- Destroys a Room object and performs cleanup tasks.
---
--- This function is called when a Room object is being destroyed. It performs the following tasks:
--- - Sends a "RoomDone" message
--- - Clears the "gofPermanent" game flag on the Room object
--- - Deletes all spawned objects associated with the Room
--- - Clears the room adjacency data
--- - Removes the Room object from the GedRoomEditorObjList if it exists
--- - If the Room object was the selected volume, it clears the selected volume and unbinds the objects from the GedRoomEditor
--- - If the Room object was previously permanent, it computes the slab visibility in the room's bounding box and the visibility of nearby shelters
---
--- @param self Room The Room object being destroyed.
---
function Room:RoomDestructor()
	Msg("RoomDone", self)
	local wasPermanent = self:GetGameFlags(const.gofPermanent) ~= 0
	self:ClearGameFlags(const.gofPermanent) --this is to dodge this assert -> assert(false, "Passability rebuild provoked from destructor! Obj class: " .. (obj.class or "N/A"))
	self:DeleteAllSpawnedObjs()
	self:ClearRoomAdjacencyData()
	
	if GedRoomEditor then
		table.remove_entry(GedRoomEditorObjList, self)
		ObjModified(GedRoomEditorObjList)
		if SelectedVolume == self then
			SetSelectedVolumeAndFireEvents(false)
			--todo: this does not work to clear the props pane
			GedRoomEditor:UnbindObjs("SelectedObject")
			ObjModified(GedRoomEditorObjList)
		end
	end
	
	if wasPermanent then
		ComputeSlabVisibilityInBox(self.box) --since we are no longer gofPermanent, call directly
		ComputeVisibilityOfNearbyShelters(self.box)
	end
	self["RoomDestructor"] = empty_func
end

---
--- Computes the visibility of the room.
---
--- If the room is marked as permanent, this function computes the slab visibility in the room's bounding box.
---
--- @param self Room The room object.
---
function Room:ComputeRoomVisibility()
	if self:GetGameFlags(const.gofPermanent) ~= 0 then
		ComputeSlabVisibilityInBox(self.box)
	end
end

---
--- Called when the Room object is being deleted from the editor.
--- Performs the following tasks:
--- - Calls the VolumeDestructor function to clean up the volume
--- - Calls the RoomDestructor function to clean up the room
---
--- @param self Room The Room object being deleted.
---
function Room:OnEditorDelete()
	self:VolumeDestructor()
	self:RoomDestructor()
end

---
--- Called when the Room object is being destroyed.
--- Performs the following tasks:
--- - Calls the RoomDestructor function to clean up the room
--- - Clears the references to the spawned objects in the room
---
--- @param self Room The Room object being destroyed.
---
function Room:Done()
	self:RoomDestructor()
	self.spawned_walls = nil
	self.spawned_corners = nil
	self.spawned_floors = nil
	self.spawned_doors = nil
	self.spawned_windows = nil
	self.spawned_decals = nil
end

---
--- Adds the Room object to the GedRoomEditorObjList if the GedRoomEditor is present.
---
--- This function is called when the Room object is added to the editor.
---
--- @param self Room The Room object being added to the editor.
---
function Room:AddInEditor()
	if GedRoomEditor then
		table.insert_unique(GedRoomEditorObjList, self)
		ObjModified(GedRoomEditorObjList)
	end
end

---
--- Creates a new nested list entry for a wall object.
---
--- @param d table The wall object to create the nested list entry for.
--- @param cls string (optional) The class name of the nested list entry to create. Defaults to "DoorNestedListEntry".
--- @return table The new nested list entry.
---
function WallObjToNestedListEntry(d, cls)
	cls = cls or "DoorNestedListEntry"
	local entry = PlaceObject(cls)
	entry.linked_obj = d
	entry.width = d.width
	entry.material = d.material
	entry.subvariant = d.subvariant or 1
	return entry
end

---
--- Checks the validity of the room's spawned corner objects.
---
--- This function iterates through the `spawned_corners` table and prints the key and value for any invalid corner objects.
---
--- @param self Room The Room object.
---
function Room:TestCorners()
	for k, v in NSEW_pairs(self.spawned_corners or empty_table) do
		for i = 1, #v do
			if not IsValid(v[i]) then
				print(k, v[i])
			end
		end
	end
end

---
--- Assigns various property values to the slabs in the room.
---
--- This function iterates through the different lists of room objects (walls, floors, windows, etc.)
--- and sets various properties on each object, such as the room reference, the side, the floor, and
--- whether the object is invulnerable. It also performs some additional processing for specific
--- object types, such as updating the entity for walls and corners, and randomizing the entity for
--- floors.
---
--- @param self Room The Room object.
---
function Room:AssignPropValuesToMySlabs()
	-- assign prop values that are convenient to have per slab but are not saved per slab
	local reposition = RepositionWallSlabsOnLoad
	for i = 1, #room_NSWE_lists do
		for side, objs in NSEW_pairs(self[room_NSWE_lists[i]] or empty_table) do
			local isDecals = "spawned_decals" == room_NSWE_lists[i]
			local isCorners = "spawned_corners" == room_NSWE_lists[i]
			local isWalls = "spawned_walls" == room_NSWE_lists[i]
			local isFloors = "spawned_floors" == room_NSWE_lists[i]
			local isWindows = "spawned_windows" == room_NSWE_lists[i]
			local isDoors = "spawned_doors" == room_NSWE_lists[i]
			for j = 1, #objs do
				local obj = objs[j]
				if obj then
					obj.room = self
					obj.side = side
					obj.floor = self.floor
					
					if not isDecals then -- could be a decal from spawned_decals
						obj.invulnerable = obj.forceInvulnerableBecauseOfGameRules
					end
					
					if isCorners and j == #objs then
						obj.isPlug = true -- last one is always a plug
					end
					if isWalls or isCorners then
						obj:DelayedUpdateEntity() -- call this after room is set for the correct seed
					end
					if isWalls then
						obj:DelayedUpdateVariantEntities() -- default colors are not available 'till .room gets assigned, this will reapply them to attaches
					end
					
					if reposition and isWalls then
						obj:SetPos(self:GetWallSlabPos(side, j))
					end
				end
			end
		end
	end
	
	local floorsAreCO = g_Classes.CombatObject and IsKindOf(FloorSlab, "CombatObject")
	for i = 1, #room_regular_lists do
		local isFloors = room_regular_lists[i] == "spawned_floors"
		local t = self[room_regular_lists[i]] or empty_table
		local side = room_regular_list_sides[i]
		for j = #t, 1, -1 do
			local o = t[j]
			if o then
				o.room = self
				o.side = side
				o.floor = self.floor
				o.invulnerable = o.forceInvulnerableBecauseOfGameRules
				
				if isFloors then
					o:DelayedUpdateEntity() -- these now have random ents as well, so rerandomize after seed is setup
				end
			end
		end
	end
end

---
--- Creates all four corner beams for the room.
---
--- This function is responsible for creating the corner beams that define the shape of the room.
--- It calls the individual functions to create each of the four corner beams.
---
--- @function Room:CreateAllCorners
--- @return nil
function Room:CreateAllCorners()
	self:RecreateNECornerBeam()
	self:RecreateNWCornerBeam()
	self:RecreateSWCornerBeam()
	self:RecreateSECornerBeam()
end

-- used manually when resaving maps from old schema to new shcema
---
--- Recreates all room corners and updates the colors of all rooms.
---
--- This function is responsible for recreating all room corners and updating the colors of all rooms in the map.
--- It first removes all existing room corners, then iterates through all rooms and calls their individual functions to recreate the walls, floor, and roof, as well as update the outer and inner colors of the room.
---
--- @function RecreateAllCornersAndColors
--- @return nil
function RecreateAllCornersAndColors()
	MapForEach("map", "RoomCorner", DoneObject)
	MapForEach("map", "Room", function(room)
		room:RecreateWalls()
		room:RecreateFloor()
		room:RecreateRoof()
		room:OnSetouter_colors(room.outer_colors)
		room:OnSetinner_colors(room.inner_colors)
	end)
end

---
--- Refreshes the outer and inner colors of all rooms in the map.
---
--- This function iterates through all rooms in the map and calls their `OnSetouter_colors` and `OnSetinner_colors` functions to update the outer and inner colors of each room.
---
--- @function RefreshAllRoomColors
--- @return nil
function RefreshAllRoomColors()
	MapForEach("map", "Room", function(room)
		room:OnSetouter_colors(room.outer_colors)
		room:OnSetinner_colors(room.inner_colors)
	end)
end

---
--- Saves any necessary fixups for the room's ceiling.
---
--- This function checks if the room has a ceiling, and if so, removes any existing ceiling slabs. This is necessary to avoid touching the roof during load, as the ceiling should remain unchanged.
---
--- @function Room:SaveFixups
--- @return nil
function Room:SaveFixups()
	local hasCeiling = type(self.roof_objs) == "table" and IsKindOf(self.roof_objs[#self.roof_objs], "CeilingSlab") or false
	if not self.build_ceiling and hasCeiling then
		-- tweaked this default value, so now there are blds with disabled ceiling who have ceilings
		-- because we avoid touching roofs during load they remain
		while IsKindOf(self.roof_objs[#self.roof_objs], "CeilingSlab") do
			local o = self.roof_objs[#self.roof_objs]
			self.roof_objs[#self.roof_objs] = nil
			DoneObject(o)
		end
	end
end

---
--- Gets the count of locked and total slabs in the room.
---
--- This function iterates through all the spawned walls, corners, floors, and roof objects in the room, and counts the number of locked and total slabs. It returns a string with the counts for each type of slab.
---
--- @function Room:Getlocked_slabs_count
--- @return string The counts of locked and total slabs in the room.
function Room:Getlocked_slabs_count()
	local total, locked = 0, 0
	
	local function iterateAndCount(t)
		for i = 1, #(t or "") do
			local slab = t[i]
			if IsValid(slab) and slab.isVisible then
				total = total + 1
				locked = locked + (slab.subvariant ~= -1 and 1 or 0)
			end
		end
	end
	
	local function iterateAndCountNSEW(objs)
		for side, t in NSEW_pairs(objs or empty_table) do
			iterateAndCount(t)
		end
	end
	
	iterateAndCountNSEW(self.spawned_walls)
	local ws = string.format("%d/%d walls", locked, total)
	locked, total = 0, 0
	iterateAndCountNSEW(self.spawned_corners)
	local cs = string.format("%d/%d corners", locked, total)
	locked, total = 0, 0
	iterateAndCount(self.spawned_floors)
	local fs = string.format("%d/%d floors", locked, total)
	locked, total = 0, 0
	iterateAndCount(self.roof_objs)
	local rs = string.format("%d/%d roof objs", locked, total)
	
	return string.format("%s; %s; %s; %s;", ws, cs, fs, rs)
end

---
--- Locks all slabs in the room to their current subvariant.
---
--- This function iterates through all the spawned walls, corners, floors, and roof objects in the room, and locks the subvariant of each slab to its current value. This ensures that the slabs will retain their current appearance even if the random generator changes.
---
--- @function Room:LockAllSlabsToCurrentSubvariants
function Room:LockAllSlabsToCurrentSubvariants()
	-- goes through all slabs and switches -1 subvariant val to their current subvariant.
	-- this will lock those variants in case of random generator changes
	
	local function iterateAndSet(t)
		for i = 1, #(t or "") do
			local slab = t[i]
			if IsValid(slab) and slab.isVisible then
				slab:LockSubvariantToCurrentEntSubvariant()
			end
		end
	end
	
	local function iterateAndSetNSEW(objs)
		for side, t in NSEW_pairs(objs or empty_table) do
			iterateAndSet(t)
		end
	end
	
	iterateAndSetNSEW(self.spawned_walls)
	iterateAndSetNSEW(self.spawned_corners)
	iterateAndSet(self.spawned_floors)
	iterateAndSet(self.roof_objs)
	ObjModified(self)
end

local function extractCpyId(str)
	local r = string.gmatch(str, "copy%d+")()
	return r and tonumber(string.gmatch(r, "%d+")()) or 0
end

---
--- Generates a name for a room with a copy tag.
---
--- This function generates a name for a room that includes a copy tag, which is used to indicate that the room is a copy of another room. The function first extracts the copy ID from the current room name, and then searches for the highest copy ID of all rooms with the same base name. It then generates a new copy tag based on the highest copy ID, and appends it to the room name.
---
--- @function Room:GenerateNameWithCpyTag
--- @return string The generated name for the room with the copy tag.
function Room:GenerateNameWithCpyTag()
	local n = self.name
	local pid = extractCpyId(n)
	local topId = pid
	EnumVolumes(function(v, n, find, sub)
		local hn = v.name
		local mn = n
		if #hn < #mn then
			mn = string.sub(mn, 1, #hn)
		elseif #hn > #mn then
			hn = string.sub(hn, 1, #mn)
		end
		
		if hn == mn then
			local hpid = extractCpyId(v.name)
			if hpid > topId then
				topId = hpid
			end
		end
	end, string.gsub(n, " copy%d+", ""), string.find, string.sub)
	
	local tag = string.format("copy%d", tonumber(topId) + 1)
	if pid == 0 then
		return string.format("%s %s", self.name, tag)
	else
		return string.gsub(self.name, "copy%d+", tag)
	end
end

---
--- Called after a room is loaded, to perform post-load operations.
---
--- This function is called after a room is loaded, to perform various post-load operations. It is called with a `reason` parameter that indicates why the room was loaded (e.g. "paste" when the room was pasted).
---
--- The function performs the following operations:
--- - If the reason is "paste", it sets the room's name using the `GenerateNameWithCpyTag()` function to generate a unique name with a copy tag.
--- - It suspends pass edits, saves fixups, aligns internal objects, sets the room's warped state, assigns property values to the room's slabs, recalculates the room's roof, and computes the room's visibility.
--- - Finally, it resumes pass edits.
---
--- @function Room:PostLoad
--- @param reason string The reason the room was loaded (e.g. "paste")
--- @return nil
function Room:PostLoad(reason)
	if reason == "paste" then
		self:Setname(self:GenerateNameWithCpyTag())
	end
	
	SuspendPassEdits("Room:PostLoad")
	
	self:SaveFixups()
	self:InternalAlignObj()
	self:SetWarped(self:GetWarped(), true)
	self:AssignPropValuesToMySlabs() -- sets slab properties that are not saved - .room, .side, etc.
	
	self:RecalcRoof()
	self:ComputeRoomVisibility()
	
	ResumePassEdits("Room:PostLoad")
end

---
--- Called when a wall object is deleted outside of the GED room editor.
---
--- This function is called when a wall object (door or window) is deleted outside of the GED room editor. It removes the deleted object from the appropriate lists and containers in the room.
---
--- If the deleted object is a door, it is removed from the `placed_doors_nl_*` list and the `spawned_doors` container. If the deleted object is a window, it is removed from the `placed_windows_nl_*` list and the `spawned_windows` container.
---
--- If the deleted object is not found in any of the room's containers, a warning is printed to the console with information about the missing object.
---
--- @function Room:OnWallObjDeletedOutsideOfGedRoomEditor
--- @param obj WallObject The wall object that was deleted
--- @return nil
function Room:OnWallObjDeletedOutsideOfGedRoomEditor(obj)
	local dir = slabAngleToDir[obj:GetAngle()]
	local t = self[obj:IsDoor() and string.format("placed_doors_nl_%s", string.lower(dir)) or string.format("placed_windows_nl_%s", string.lower(dir))]
	local container = obj:IsDoor() and self.spawned_doors or self.spawned_windows
	if container then
		for i = 1, #(t or empty_table) do
			if t[i].linked_obj == obj then
				DoneObject(t[i])
				table.remove(t, i)
				table.remove_entry(container[dir], obj)
				return
			end
		end
	elseif Platform.developer then
		local cs = obj:IsDoor() and "spawned_doors" or "spawned_windows"
		local dirFound
		local r = MapGetFirst("map", "Room", function(o, cs, obj, et)
			for side, t in sorted_pairs(o[cs] or et) do
				if table.find(t or et, obj) then
					dirFound = side
					return true
				end
			end
		end, cs, obj, empty_table)
		
		if r then
			print(string.format("Wall obj was found in room %s, side %s container", r.name, dirFound))
		else
			print("Wall obj was not found in any room container")
		end
		
		assert(false, string.format("Room %s had no contaier initialized for wall obj with entity %s, deduced side %s, member side %s", self.name, obj.entity, dir, obj.side))
	end
end

local dirs = { "North", "East", "South", "West" }
---
--- Rotates a direction based on the given angle.
---
--- @param direction string The direction to rotate.
--- @param angle number The angle to rotate the direction by, in 90-degree increments.
--- @return string The rotated direction.
function rotate_direction(direction, angle)
	local idx = table.find(dirs, direction)
	if not idx then return direction end
	idx = idx + angle / (90 * 60)
	if idx > 4 then idx = idx - 4 end
	return dirs[idx]
end

---
--- Rotates a room and its contents by the specified angle around the given center point and axis.
---
--- @param center point The center point to rotate around.
--- @param axis vector The axis to rotate around.
--- @param angle number The angle to rotate by, in 90-degree increments.
--- @param last_angle number The previous angle.
---
function Room:EditorRotate(center, axis, angle, last_angle)
	angle = angle - last_angle
	if axis:z() < 0 then angle = -angle end
	angle = (angle + 360 * 60 + 45 * 60 ) / (90 * 60) * (90 * 60)
	while angle >= 360 * 60 do angle = angle - 360 * 60 end
	if axis:z() == 0 or angle == 0 then return end

	-- rotate room properties
	local a = center + Rotate(self.box:min() - center, angle)
	local b = center + Rotate(self.box:max() - center, angle)
	self.box = boxdiag(a, b)
	self.position = self.box:min()
	local x, y, z = self.box:size():xyz()
	self.size = point(x / voxelSizeX, y / voxelSizeY, z / voxelSizeZ)
	
	-- rotate roof properties
	if self:GetRoofType() == "Gable" then
		if angle == 90 * 60 or angle == 270 * 60 then
			self.roof_direction = self.roof_direction == GableRoofDirections[1] and GableRoofDirections[2] or GableRoofDirections[1]
		end
	elseif self:GetRoofType() == "Shed" then
		self.roof_direction = rotate_direction(self.roof_direction, angle)
	end
	
	-- rotate slabs
	self:ForEachSpawnedObj(function(obj, center, angle)
		local new_angle = 0
		if not IsKindOf(obj, "FloorAlignedObj") then
			new_angle = obj:GetAngle() + angle
		end
		obj:SetPosAngle(center + Rotate(obj:GetPos() - center, angle), new_angle)
		obj.side = rotate_direction(obj.side, angle)
		if obj:IsKindOf("SlabWallObject") then obj:UpdateManagedObj() end
	end, center, angle)
	
	-- assign slabs to the proper lists after rotation
	local d = table.copy(dirs)
	while angle >= 90 * 60 do
		d[1], d[2], d[3], d[4] = d[2], d[3], d[4], d[1]
		angle = angle - 90 * 60
	end
	for i = 1, #room_NSWE_lists do
		local lists = self[room_NSWE_lists[i]]
		if lists then
			lists[d[1]], lists[d[2]], lists[d[3]], lists[d[4]] = lists.North, lists.East, lists.South, lists.West
		end
	end
	self:InternalAlignObj()
	self:RecreateRoof()
end

function OnMsg.GedClosing(ged_id)
	if GedRoomEditor and GedRoomEditor.ged_id == ged_id then
		GedRoomEditor = false
		GedRoomEditorObjList = false
	end
end

function OnMsg.GedOnEditorSelect(obj, selected, editor)
	if editor == GedRoomEditor then
		SetSelectedVolumeAndFireEvents(selected and obj or false)
	end
end

---
--- Opens the GED room editor.
---
--- This function creates a real-time thread that checks if the GED room editor is valid. If not, it retrieves a list of all rooms in the map, sorts them by name and structure, and then opens the GED room editor with the sorted list.
---
--- @function OpenGedRoomEditor
--- @return nil
function OpenGedRoomEditor()
	CreateRealTimeThread(function()
		if not IsValid(GedRoomEditor) then
			GedRoomEditorObjList = MapGet("map", "Room") or {}
			table.sortby_field(GedRoomEditorObjList, "name")
			table.sortby_field(GedRoomEditorObjList, "structure")
			GedRoomEditor = OpenGedApp("GedRoomEditor", GedRoomEditorObjList) or false
		end
	end)
end

function OnMsg.ChangeMap()
	if GedRoomEditor then
		GedRoomEditor:Send("rfnClose")
		GedRoomEditor = false
	end
end
--------------------------------------------------------------------------
--------------------------------------------------------------------------
--------------------------------------------------------------------------
DefineClass.SlabPreset = {
	__parents = { "Preset", },
	properties = {
		{ id = "Group", no_edit = false, },
	},
	HasSortKey = false,
	PresetClass = "SlabPreset",
	NoInstances = true,
	EditorMenubarName = "Slab Presets",
	EditorMenubar = "Editors.Art",
}

DefineClass.SlabMaterialSubvariant = {
	__parents = {"PropertyObject"},
	properties = {
		{ id = "suffix", name = "Suffix", editor = "text", default = "01" },
		{ id = "chance", name = "Chance", editor = "number", default = 100 },
	},
}

--------------------------------------------------------------------------
--------------------------------------------------------------------------
--------------------------------------------------------------------------
---
--- Touches all the corners of each room in the map.
---
--- This function iterates through all the rooms in the map and calls the `TouchCorners` method on each room, passing in the cardinal directions ("North", "South", "West", "East") to touch all the corners of the room.
---
--- @function TouchAllRoomCorners
--- @return nil
function TouchAllRoomCorners()
	MapForEach("map", "Room", function(o)
		o:TouchCorners("North")
		o:TouchCorners("South")
		o:TouchCorners("West")
		o:TouchCorners("East")
	end)
end

DefineClass.HideOnFloorChange = {
	__parents = { "Object" },
	properties = {
		{ id = "floor", name = "Floor", editor = "number", min = -10, max = 100, default = 1, dont_save = function (obj) return obj.room end },
	},
	room = false,
	invisible_reasons = false,
}

---
--- Returns the floor of the room associated with this object, or the floor property of the object if no room is associated.
---
--- @return number The floor of the associated room, or the floor property of the object.
function HideOnFloorChange:Getfloor()
	local room = self.room
	return room and room.floor or self.floor
end

HideSlab = false -- used only if defined

---
--- Hides all floors above the specified floor.
---
--- This function suspends pass edits, calls `HideFloorsAboveC` to hide the floors above the specified floor, sends a message about the floors being hidden, and then resumes pass edits.
---
--- @param floor number The floor to hide all floors above.
--- @param fnHide function|nil The function to use for hiding the floors. If not provided, `HideSlab` is used.
--- @return nil
function HideFloorsAbove(floor, fnHide)
	SuspendPassEdits("HideFloorsAbove")
	HideFloorsAboveC(floor, fnHide or HideSlab or nil)
	Msg("FloorsHiddenAbove", floor, fnHide)
	ResumePassEdits("HideFloorsAbove")
end

---
--- Counts the total number of slabs in all rooms in the map.
---
--- This function iterates through all the rooms in the map and calculates the total number of slabs in each room by multiplying the room's size in the x and y dimensions by 2 and then multiplying that by the room's size in the z dimension. The total number of slabs across all rooms is returned.
---
--- @function CountRoomSlabs
--- @return number The total number of slabs in all rooms in the map.
function CountRoomSlabs()
	local t = 0
	MapForEach("map", "Room", function(o)
		t = t + (o.size:x() + o.size:y()) * 2 * o.size:z()
	end)
	
	return t
end

---
--- Counts the number of mirrored and non-mirrored wall slabs in the map.
---
--- This function iterates through all the wall slabs in the map and counts the number of slabs that can be mirrored and are visible. It returns the count of non-mirrored slabs and the count of mirrored slabs.
---
--- @return number The count of non-mirrored wall slabs
--- @return number The count of mirrored wall slabs
function CountMirroredSlabs()
	local t, tm = 0, 0
	
	MapForEach("map", "WallSlab", function(o)
		if o:CanMirror() and o:GetEnumFlags(const.efVisible) ~= 0 then
			if o:GetGameFlags(const.gofMirrored) ~= 0 then
				tm = tm + 1
			else
				t = t + 1
			end
		end
	end)
	
	return t, tm
end

---
--- Builds the buildings data.
---
--- This function is responsible for building the data related to buildings in the game. It likely performs tasks such as initializing data structures, loading building definitions, or calculating derived properties about buildings.
---
--- @function BuildBuildingsData
--- @return nil
function BuildBuildingsData()
end

---
--- Prints the position of each SlabWallObject in the map, and the vector from the object to its room's position if the object has a room.
---
--- This function is likely used for debugging purposes, to visually inspect the positioning of wall objects in the game world.
---
--- @function DbgWindowDoorOwnership
--- @return nil
function DbgWindowDoorOwnership()
	MapForEach("map", "SlabWallObject", function(o)
		if o.room then
			DbgAddVector(o:GetPos(), o.room:GetPos() - o:GetPos())
		else
			DbgAddVector(o:GetPos())
		end
	end)
end
