DefineClass.PrefabContainer = {
	__parents = { "InitDone" },
	name = false,
	pos = false,
	angle = 0,
	objs = false
}

--- Initializes the PrefabContainer object by placing the prefab at the specified position and angle.
---
--- @param self PrefabContainer
--- @return boolean, string err, table objs
function PrefabContainer:Init()
	local err, objs = PlacePrefab(self.name, self.pos, self.angle, nil, {
		dont_clamp_objects = true,
		ignore_ground_offset = true
	})
	assert(not err, err)
	self.objs = objs
end

--- Marks the PrefabContainer object as done, cleaning up the objects it contains.
---
--- @param self PrefabContainer
function PrefabContainer:Done()
	DoneObjects(self.objs)
	self.objs = false
end

--- Returns the position of the PrefabContainer object.
---
--- @return table pos The position of the PrefabContainer object.
function PrefabContainer:GetPos()
	return self.pos
end

--- Sets the position of the PrefabContainer object and updates the positions of the objects it contains.
---
--- @param self PrefabContainer
--- @param pos table The new position for the PrefabContainer object.
function PrefabContainer:SetPos(pos)
	if pos == self.pos then
		return
	end
	local dp = pos - self.pos
	for i, o in ipairs(self.objs) do
		o:SetPos(o:GetPos() + dp)
	end
	self.pos = pos
end

--- Sets the position of the PrefabContainer object relative to another object.
---
--- @param self PrefabContainer
--- @param pos table The new position for the PrefabContainer object.
--- @param obj table The object to use as the reference point for the new position.
function PrefabContainer:SetPosRelativeTo(pos, obj)
	local relativePos = obj:GetPos() - self.pos
	self:SetPos(pos - relativePos)
end

--- Returns the angle of the PrefabContainer object.
---
--- @return number angle The angle of the PrefabContainer object.
function PrefabContainer:GetAngle()
	return self.angle
end

--- Sets the angle of the PrefabContainer object and rotates the objects it contains around its center position.
---
--- @param self PrefabContainer
--- @param angle number The new angle for the PrefabContainer object.
function PrefabContainer:SetAngle(angle)
	if AngleDiff(angle, self.angle) == 0 then
		return
	end
	RotateObjectsAroundCenter(self.objs, angle - self.angle, self.pos)
	self.angle = angle
end

--- Returns the first object in the PrefabContainer that is an instance of the specified class.
---
--- @param self PrefabContainer The PrefabContainer instance.
--- @param class table The class to search for.
--- @return table|boolean The first object that is an instance of the specified class, or false if none is found.
function PrefabContainer:GetObjectByType(class)
	for i, o in ipairs(self.objs) do
		if IsKindOf(o, class) then
			return o
		end
	end
	return false
end