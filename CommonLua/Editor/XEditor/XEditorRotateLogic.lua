DefineClass.XEditorRotateLogic = {
	__parents = { "PropertyObject" },
	init_rotate_center = false,
	init_rotate_data = false,
	init_angle = false,
	last_angle = false,
}

-- with Slabs in the selection, rotate around a half-grid aligned point
-- to ensure Slab positions are aligned after the rotation
---
--- Gets the rotation center for the given objects, snapping to a half-grid aligned point if the objects contain slabs.
---
--- @param center table The center point to use for the rotation.
--- @param has_slabs boolean Whether the objects being rotated contain slabs.
--- @return table The snapped rotation center point.
---
function XEditorRotateLogic:GetRotateCenter(center, has_slabs)
	local snap = has_slabs and const.SlabSizeX or 1
	return point(center:x() / snap * snap, center:y() / snap * snap, center:z())
end

---
--- Gets the rotation angle for the current rotation operation.
---
--- This function must be implemented in a subclass of `XEditorRotateLogic`.
---
--- @return number The current rotation angle.
---
function XEditorRotateLogic:GetRotateAngle()
	assert(false, "Please implement GetRotateAngle in the subclass.")
end

---
--- Initializes the rotation data for the given objects.
---
--- This function is called before a rotation operation is performed. It calculates the initial rotation center and angle, and stores the necessary data for each object to be rotated.
---
--- @param objs table The objects to be rotated.
--- @param center table The initial rotation center point. If not provided, the center of masses of the objects is used.
--- @param initial_angle number The initial rotation angle. If not provided, the result of `self:GetRotateAngle()` is used.
---
function XEditorRotateLogic:InitRotation(objs, center, initial_angle)
	assert(not self.init_rotate_data)
	local has_slabs = HasAlignedObjs(objs)
	self.init_rotate_center = self:GetRotateCenter(center or CenterOfMasses(objs), has_slabs)
	self.init_angle = initial_angle or self:GetRotateAngle()
	self.last_angle = 0
	self.init_rotate_data = {}
	for i, obj in ipairs(objs) do
		if obj:IsValidPos() then
			self.init_rotate_data[i] = {
				axis = obj:GetVisualAxis(),
				angle = obj:GetVisualAngle(),
				offset = obj:GetVisualPos() - self.init_rotate_center,
				valid_z = obj:IsValidZ(),
				last_angle = 0,
			}
		end
	end
end

---
--- Rotates the given objects around the specified center and axis by the given angle.
---
--- If the `init_rotate_data` is not set, it will be initialized by calling `self:InitRotation()`.
---
--- @param objs table The objects to be rotated.
--- @param group_rotation boolean Whether to rotate the objects as a group around the center, or individually around their own positions.
--- @param center table The rotation center point. If not provided, the center of masses of the objects is used.
--- @param axis table The rotation axis. Defaults to the Z axis.
--- @param angle number The rotation angle in radians. Defaults to the result of `self:GetRotateAngle()`.
---
function XEditorRotateLogic:Rotate(objs, group_rotation, center, axis, angle)
	if not self.init_rotate_data then
		self:InitRotation(objs, center)
	end
	
	axis = axis or axis_z
	angle = angle or self:GetRotateAngle()
	
	local has_slabs = HasAlignedObjs(objs)
	local center = self.init_rotate_center
	local angle = XEditorSettings:AngleSnap(angle - self.init_angle, has_slabs)
	for i, obj in ipairs(objs) do
		if obj:HasMember("EditorRotate") then
			obj:EditorRotate(group_rotation and center or obj:GetPos(), axis, angle, self.last_angle)
		elseif obj:IsValidPos() then
			local data = self.init_rotate_data[i]
			local newPos = obj:GetPos()
			if group_rotation then
				newPos = center + RotateAxis(data.offset, axis, angle)
				if not data.valid_z then
					newPos = newPos:SetInvalidZ()
				end
			end
			XEditorSetPosAxisAngle(obj, newPos, ComposeRotation(data.axis, data.angle, axis, angle))
		end
	end
	Msg("EditorCallback", "EditorCallbackRotate", objs)
	self.last_angle = angle
end

---
--- Cleans up the rotation data used by the `XEditorRotateLogic` class.
--- This function sets the `init_rotate_data`, `init_rotate_center`, `init_angle`, and `last_angle` fields to `nil`.
---
function XEditorRotateLogic:CleanupRotation()
	self.init_rotate_data = nil
	self.init_rotate_center = nil
	self.init_angle = nil
	self.last_angle = nil
end
