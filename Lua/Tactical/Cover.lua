DefineClass.CoverObj = {
	__parents = { "Object", "ComponentAttach" },
	entity = false,
	dbg_mesh = false,
}

--- Called when the object is initialized.
--- If the object is not aligned, it will be deleted.
function CoverObj:GameInit()
	local parent = self:GetParent()
	if not self:IsAligned() then
		self:Notify("delete")
		return
	end
end

--- Checks if the cover object is aligned.
---
--- @return boolean true if the cover object is aligned, false otherwise
function CoverObj:IsAligned()
end

--- Shows the cover object.
function CoverObj:Show()
end

--- Hides the cover object by destroying the debug mesh associated with it.
function CoverObj:Hide()
	if IsValid(self.dbg_mesh) then
		DoneObject(self.dbg_mesh)
		self.dbg_mesh = nil
	end
end


DefineClass.CoverWall = {
	__parents = { "CoverObj" },
}

--- Shows the cover object by creating a debug mesh for it.
---
--- The debug mesh is created with the following dimensions:
--- - Width: 3 * const.SlabSizeX / 10 / 2
--- - Height: const.SlabSizeY / 2
--- - Depth: const.SlabSizeZ
---
--- The mesh is colored with RGB(120, 20, 180) and attached to the cover object.
function CoverWall:Show()
	if not IsValid(self.dbg_mesh) then
		self.dbg_mesh = PlaceObject("Mesh")		
		self.dbg_mesh:SetDepthTest(true)

		local width = 3 * const.SlabSizeX / 10
		local height = const.SlabSizeY
		local depth = const.SlabSizeZ

		width = width / 2
		height = height / 2
		--depth = -depth
		local p_pstr = pstr("")
		local function AddPoint(x,y,z) 
			p_pstr:AppendVertex(point(x*width, y*height, z*depth), RGB(120, 20, 180))
		end
		
		-- -x
		AddPoint(-1, -1, 0) AddPoint(-1,  1, 0) AddPoint(-1,  1, 1)		
		AddPoint(-1,  1, 1) AddPoint(-1, -1, 1) AddPoint(-1, -1, 0)		
		-- +x
		AddPoint( 1, -1, 0) AddPoint( 1,  1, 0) AddPoint( 1,  1, 1)		
		AddPoint( 1,  1, 1) AddPoint( 1, -1, 1) AddPoint( 1, -1, 0)
		-- -y
		AddPoint(-1, -1, 0) AddPoint( 1, -1, 0) AddPoint( 1, -1, 1)
		AddPoint( 1, -1, 1) AddPoint(-1, -1, 1) AddPoint(-1, -1, 0)		
		-- +y
		AddPoint(-1,  1, 0) AddPoint( 1,  1, 0) AddPoint( 1,  1, 1)
		AddPoint( 1,  1, 1) AddPoint(-1,  1, 1) AddPoint(-1,  1, 0)		
		-- z0
		AddPoint(-1, -1, 0) AddPoint(-1,  1, 0) AddPoint( 1,  1, 0)
		AddPoint( 1,  1, 0) AddPoint( 1, -1, 0) AddPoint(-1, -1, 0)
		-- +z
		AddPoint(-1, -1, 1) AddPoint(-1,  1, 1) AddPoint( 1,  1, 1)
		AddPoint( 1,  1, 1) AddPoint( 1, -1, 1) AddPoint(-1, -1, 1)
		
		self.dbg_mesh:SetMesh(p_pstr)
		
		self:Attach(self.dbg_mesh)
	end
end

---
--- Checks if the cover wall is aligned with the voxel grid.
---
--- @return boolean true if the cover wall is aligned with the voxel grid, false otherwise
function CoverWall:IsAligned()
	local x, y, z = self:GetPosXYZ()
	local angle = self:GetAngle()
	local tx, ty, tz = WallVoxelToWorld(WallWorldToVoxel(x, y, z, angle))
	return x == tx and y == ty and z == tz
end

-- cover shields angle!
local cover_dir_angle = {
	["up"] = 90 * 60,
	["right"] = 2 * 90 * 60,
	["down"] = 3 * 90 * 60,
	["left"] = 0,
}
---
--- Returns the angle for the given cover direction.
---
--- @param dir string The cover direction ("up", "right", "down", "left")
--- @return integer The angle for the given cover direction
function GetCoverDirAngle(dir)
	return cover_dir_angle[dir]
end

local coverHigh = const.CoverHigh
local coverLow = const.CoverLow

---
--- Returns a table of covers at the given position or object.
---
--- @param pos_or_obj table|object The position or object to get covers for
--- @return table|nil A table of covers, or nil if no covers are found
function GetCoversAt(pos_or_obj)
	local up, right, down, left = GetCover(pos_or_obj)
	if not up then
		return
	end
	
	local covers = {
		[cover_dir_angle.up] = (up == coverHigh or up == coverLow) and up or nil,
		[cover_dir_angle.right] = (right == coverHigh or right == coverLow) and right or nil,
		[cover_dir_angle.down] = (down == coverHigh or down == coverLow) and down or nil,
		[cover_dir_angle.left] = (left == coverHigh or left == coverLow) and left or nil,
	}
	
	return next(covers) and covers or nil
end

local cover_offsets = {
	point(0, -const.SlabSizeY / 2, 0), -- up
	point(const.SlabSizeX / 2, 0, 0), -- "right"
	point(0, const.SlabSizeY / 2, 0), -- "down"
	point(-const.SlabSizeX / 2, 0, 0), -- "left"
}

---
--- Returns the cover offset for the given angle.
---
--- @param angle integer The angle to get the cover offset for
--- @return table The cover offset as a point
function GetCoverOffset(angle)
	local idx = 1 + (1 + CardinalDirection(angle) / (90*60)) % 4
	return cover_offsets[idx]
end

---
--- Returns the cover at the given position and angle.
---
--- @param pos table The position to get the cover for
--- @param angle integer The angle to get the cover for
--- @return integer The cover type at the given position and angle
function GetAngleCover(pos, angle)
	local idx = 1 + (1 + CardinalDirection(angle) / (90*60)) % 4
	local cover = select(idx, GetCover(pos))
	return cover
end

---
--- Returns the highest cover type at the given position or object.
---
--- @param pos_or_obj table|object The position or object to get the highest cover for
--- @return integer The highest cover type, or nil if no cover is found
function GetHighestCoverUI(pos_or_obj)
	if not IsPoint(pos_or_obj) and pos_or_obj.return_pos then
		pos_or_obj = pos_or_obj.return_pos
	end
	
	return GetHighestCover(pos_or_obj)
end

---
--- Returns the highest and lowest cover types at the given position or object.
---
--- @param pos_or_obj table|object The position or object to get the cover types for
--- @return boolean, boolean The highest and lowest cover types, or nil if no cover is found
function GetCoverTypes(pos_or_obj)
	local up, right, down, left = GetCover(pos_or_obj)
	if not up then
		return
	end

	local cover_low = up == coverLow or right == coverLow or down == coverLow or left == coverLow
	local cover_high = up == coverHigh or right == coverHigh or down == coverHigh or left == coverHigh
	
	return cover_high, cover_low
end

---
--- Returns the highest cover type at the given position or object.
---
--- @param pos_or_obj table|object The position or object to get the highest cover for
--- @return integer The highest cover type, or nil if no cover is found
function GetHighestCover(pos_or_obj)
	local high, low = GetCoverTypes(pos_or_obj)
	if high then
		return coverHigh
	end
	if low then
		return coverLow
	end
end

---
--- Determines the best orientation for a unit to face high cover at the given position and angle.
---
--- @param pos table The position to check for high cover
--- @param angle number The current angle of the unit
--- @return number The best angle for the unit to face the high cover
function GetUnitOrientationToHighCover(pos, angle)
	local up, right, down, left = GetCover(pos)
	if not up then
		return
	end
	if up ~= coverHigh and right ~= coverHigh and down ~= coverHigh and left ~= coverHigh then
		return
	end
	
	local max_diff = 90*60
	local best_angle, best_diff
	-- rotations against the cover
	local a1 = cover_dir_angle.up + 180*60
	local a2 = cover_dir_angle.right + 180*60
	local a3 = cover_dir_angle.down + 180*60
	local a4 = cover_dir_angle.left + 180*60

	local diff1 = abs(AngleDiff(angle, a1))
	local diff2 = abs(AngleDiff(angle, a2))
	local diff3 = abs(AngleDiff(angle, a3))
	local diff4 = abs(AngleDiff(angle, a4))

	-- avoid facing another high cover
	-- up / down
	if right == coverHigh and diff2 < max_diff or left == coverHigh and diff4 < max_diff then
		if up ~= coverHigh   and (not best_diff or diff1 < best_diff) then best_angle, best_diff = a1, diff1 end
		if down ~= coverHigh and (not best_diff or diff3 < best_diff) then best_angle, best_diff = a3, diff3 end
	end
	-- left / right
	if up == coverHigh and diff1 < max_diff or down == coverHigh and diff3 < max_diff then
		if left ~= coverHigh and (not best_diff or diff4 < best_diff) then best_angle, best_diff = a4, diff4 end
		if right ~= coverHigh and (not best_diff or diff2 < best_diff) then best_angle, best_diff = a2, diff2 end
	end

	-- fallback (can face another high cover)
	if not best_angle then
		-- up / down
		if right == coverHigh and diff2 < max_diff or left == coverHigh and diff4 < max_diff then
			if not best_diff or diff1 < best_diff then best_angle, best_diff = a1, diff1 end
			if not best_diff or diff3 < best_diff then best_angle, best_diff = a3, diff3 end
		end
		-- left / right
		if up == coverHigh and diff1 < max_diff or down == coverHigh and diff3 < max_diff then
			if not best_diff or diff4 < best_diff then best_angle, best_diff = a4, diff4 end
			if not best_diff or diff2 < best_diff then best_angle, best_diff = a2, diff2 end
		end
	end

	return best_angle
end

DefineClass.BaseObjectWithCover = {
	__parents = { "AutoAttachObject" },
	covers = false,
}

---
--- Initializes the `BaseObjectWithCover` class, handling the attachment and detachment of cover objects.
---
--- This method is called during the game initialization process for objects of the `BaseObjectWithCover` class.
--- It retrieves all attached `CoverObj` objects and either detaches them if the object has a parent, or sets their position if they don't have a parent.
--- If the object has a parent, the `covers` table is set to an empty table.
---
--- @function BaseObjectWithCover:GameInit
--- @return nil
function BaseObjectWithCover:GameInit()
	self.covers = self:GetAttaches("CoverObj")
	for _, cover in ipairs(self.covers or empty_table) do
		if self:GetParent() then
			DoneObject(cover)
		else
			local pos = cover:GetPos() + cover:GetAttachOffset()
			cover:Detach()
			cover:SetPos(pos)
		end
	end
	if self:GetParent() then
		self.covers = {}
	end
end

---
--- Finalizes the `BaseObjectWithCover` class by detaching and destroying all attached `CoverObj` objects.
---
--- This method is called when the `BaseObjectWithCover` object is being destroyed. It iterates through the `covers` table, which contains all the attached `CoverObj` objects, and destroys each one using the `DoneObject` function. Finally, it sets the `covers` table to `nil`.
---
--- @function BaseObjectWithCover:Done
--- @return nil
function BaseObjectWithCover:Done()
	for _, obj in ipairs(self.covers) do
		DoneObject(obj)
	end
	self.covers = nil
end

DefineClass.BaseCliff = {
	__parents = { "FloorAlignedObj", "Deposition" },
	flags = {efPathSlab = true},
}

DefineClass.BaseTrench = {
	__parents = { "FloorAlignedObj", "Deposition" },
	flags = {efPathSlab = true},
}

local halfVoxelSizeX = const.SlabSizeX / 2
local halfVoxelSizeY = const.SlabSizeY / 2
local VoxelSizeZ = const.SlabSizeZ
local clrInvisible = RGBA(0, 0, 0, 0)
local slabx, slaby, slabz = const.SlabSizeX, const.SlabSizeY, const.SlabSizeZ

---
--- Gets the bounding box of the voxels around a given world position, taking into account any objects in the area.
---
--- @param padding number The padding to add around the bounding box, in voxels.
--- @param world_pos point The world position to get the bounding box for. If not provided, the current cursor position is used.
--- @return box The bounding box of the voxels around the given world position.
function GetVoxelBox(padding, world_pos)
	padding = padding or 1
	world_pos = world_pos or GetCursorPos()
	
	local surface = terrain.GetHeight(world_pos)
	world_pos = (surface and surface > world_pos:z()) and world_pos:SetZ(surface) or world_pos
	local x, y, z = VoxelToWorld(WorldToVoxel(world_pos))
	local pt2d = point(x, y)
	local offset = point(padding * slabx + slabx / 2, padding * slaby + slaby / 2)
	local bbox = box(pt2d - offset, pt2d + offset)
	local minz, maxz = z, z
	MapForEach(bbox, function(obj)
		local obj_bbox = obj:GetEntityBBox()
		local obj_z = obj:GetPos():z()
		if obj_z then
			local obj_minz, obj_maxz = obj_z + obj_bbox:minz(), obj_z + obj_bbox:maxz()
			minz = (obj_minz < minz) and obj_minz or minz
			maxz = (obj_maxz > maxz) and obj_maxz or maxz
		end
	end)
	minz = minz - slabz / 2 - padding * slabz
	maxz = maxz + slabz / 2 + padding * slabz
	
	return box(bbox:min():SetZ(minz), bbox:max():SetZ(maxz))
end

---
--- Gets the cover percentage for a given stand position and attack position, taking into account the target stance.
---
--- @param stand_pos point The position the character is standing at.
--- @param attack_pos point The position the attack is coming from.
--- @param target_stance string The stance of the target.
--- @return boolean, boolean, number The cover type, whether any cover was found, and the coverage percentage.
---
function GetCoverPercentage(stand_pos, attack_pos, target_stance)
	local cover, any, coverage = PosGetCoverPercentageFrom(stand_pos, attack_pos)
	if cover == coverLow and target_stance == "Standing" then
		cover, coverage = false, 0
	end
	return cover, any, coverage or 0
end
