DefineClass.RotateGizmo = {
	__parents = { "XEditorGizmo" },
	
	HasLocalCSSetting = true,
	HasSnapSetting = false,
	
	Title = "Rotate gizmo (E)",
	Description = false,
	ActionSortKey = "2",
	ActionIcon = "CommonAssets/UI/Editor/Tools/RotateGizmo.tga",
	ActionShortcut = "E",
	UndoOpName = "Rotated %d object(s)",

	mesh_x = pstr(""),
	mesh_y = pstr(""),
	mesh_z = pstr(""),
	mesh_big = pstr(""),
	mesh_sphere = pstr(""),
	
	b_over_x = false,
	b_over_y = false,
	b_over_z = false,
	b_over_big = false,
	b_over_sphere = false,
	
	v_axis_x = axis_x,
	v_axis_y = axis_y,
	v_axis_z = axis_z,
	
	scale = 100,
	thickness = 100,
	opacity = 255,
	sensitivity = 100,
	
	operation_started = false,
	
	tangent_vector = false,
	tangent_offset = false,
	tangent_axis = false,
	tangent_angle = false,
	
	initial_orientations = false,
	init_intersect = false,
	init_pos = false,
	rotation_center = false,
	rotation_axis = false,
	rotation_angle = 0,
	rotation_snap = false,
	
	text = false,
}

--- Deletes the text associated with the rotate gizmo.
---
--- This function is called when the rotate gizmo operation is completed, to clean up any temporary text elements that were created during the operation.
function RotateGizmo:Done()
	self:DeleteText()
end

--- Deletes the text associated with the rotate gizmo.
---
--- This function is called when the rotate gizmo operation is completed, to clean up any temporary text elements that were created during the operation.
function RotateGizmo:DeleteText()
	if self.text then
		self.text:delete()
		self.text = nil
	end
end

---
--- Checks if the rotate gizmo operation can be started based on the current selection and cursor position.
---
--- @param pt Vector2 The current cursor position.
--- @return boolean True if the rotate gizmo operation can be started, false otherwise.
function RotateGizmo:CheckStartOperation(pt)
	return #editor.GetSel() > 0 and self:IntersectRay(camera.GetEye(), ScreenToGame(pt))
end

---
--- Starts the rotate gizmo operation.
---
--- This function is called when the rotate gizmo is activated and the user starts a rotation operation. It initializes the necessary state for the rotation operation, such as the rotation center, initial object orientations, and cursor intersection point.
---
--- @param pt Vector2 The current cursor position.
---
function RotateGizmo:StartOperation(pt)
	if not self.b_over_sphere then
		self.text = XTemplateSpawn("XFloatingText")
		self.text:SetTextStyle("GizmoText")
		self.text:AddDynamicPosModifier({id = "attached_ui", target = self:GetPos()})
		self.text.TextColor = RGB(255, 255, 255)
		self.text.ShadowType = "outline"
		self.text.ShadowSize = 1
		self.text.ShadowColor = RGB(64, 64, 64)
		self.text.Translate = false
	end
	
	-- with Slabs in the selection, rotate around a half-grid aligned point (if rotating around the Z axis)
	-- to ensure Slab positions are aligned after the rotation
	local center = self:GetPos()
	local objs = editor.GetSel()
	self:CursorIntersection(pt) -- initialize rotation_axis
	if not self.b_over_sphere and self.rotation_axis == axis_z and HasAlignedObjs(objs) then
		local snap = const.SlabSizeX
		center = point(center:x() / snap * snap, center:y() / snap * snap, center:z()) or center
	end
	
	self.init_intersect = self:CursorIntersection(pt)
	self.init_pos = self:GetPos()
	self.rotation_center = center
	self.initial_orientations = {}
	for i, obj in ipairs(objs) do
		self.initial_orientations[obj] = { axis = obj:GetVisualAxis(), angle = obj:GetVisualAngle(), offset = obj:GetVisualPos() - center }
	end
	self.operation_started = true
end

---
--- Performs the rotate gizmo operation based on the current cursor position.
---
--- This function is called during the rotation operation to update the rotation of the selected objects. It calculates the new rotation angle and axis based on the cursor movement, and then applies the rotation to the selected objects.
---
--- @param pt Vector2 The current cursor position.
---
function RotateGizmo:PerformOperation(pt)
	local intersection = self:CursorIntersection(pt)
	if not intersection then return end
	
	self.rotation_angle = 0
	
	local axis, angle
	local offset = MulDivRound(intersection - self.init_intersect, 9 * self.sensitivity, self.scale) -- 9 is the magic number that gives +/-45 degree range
	if self.b_over_sphere then
		local normal = Normalize(self:GetVisualPos() - camera.GetEye())
		local axisX = Normalize(Cross(normal, axis_z))
		local axisY = Normalize(Cross(normal, axisX))
		local angleX = Dot(offset, axisY) / 4096
		local angleY = -Dot(offset, axisX) / 4096
		axis, angle = ComposeRotation(axisX, angleX, axisY, angleY)
	else
		axis, angle = self.rotation_axis, Dot(offset, self.tangent_vector) / 4096
		if XEditorSettings:GetGizmoRotateSnapping() then
			local new_angle = self:SnapAngle(angle)
			angle, self.rotation_snap = new_angle, new_angle ~= angle
		end
		self.rotation_angle = angle / 60.0
	end
	
	local center = self.rotation_center
	for obj, data in pairs(self.initial_orientations) do
		local newPos = center + RotateAxis(data.offset, axis, angle)
		if not obj:IsValidZ() then
			newPos = newPos:SetInvalidZ()
		end
		XEditorSetPosAxisAngle(obj, newPos, ComposeRotation(data.axis, data.angle, axis, angle))
	end
	Msg("EditorCallback", "EditorCallbackRotate", table.keys(self.initial_orientations))
end

---
--- Ends the rotate gizmo operation, resetting the internal state.
---
--- This function is called when the rotate gizmo operation is completed. It resets the various internal state variables used during the rotation operation, such as the tangent vector, rotation axis, and initial orientations of the selected objects.
---
--- After calling this function, the rotate gizmo is ready to start a new operation.
---
function RotateGizmo:EndOperation()
	self.tangent_vector = false
	self.tangent_offset = false
	self.tangent_axis = false
	self.tangent_angle = false
	self.rotation_axis = false
	self.initial_orientations = false
	self.init_intersect = false
	self.init_pos = false
	self.operation_started = false
	self:DeleteText()
end

---
--- Snaps the given angle to the nearest multiple of 15 degrees, with a tolerance of 2 degrees.
---
--- This function is used to snap the rotation angle of the rotate gizmo to a multiple of 15 degrees, with a small tolerance to allow for fine adjustments. The snapping is only applied if the absolute value of the angle is greater than 2 degrees, to avoid snapping at the 0 degree rotation.
---
--- @param angle number The angle to be snapped.
--- @return number The snapped angle.
---
function RotateGizmo:SnapAngle(angle)
	local snapAngle = 15 * 60
	local snapAngleTollerance = 120
	if abs(angle) > snapAngleTollerance then -- don't snap at the 0 degree rotation, allowing for small adjustments
		if abs(angle % snapAngle) < snapAngleTollerance or abs(angle % snapAngle) > (snapAngle - snapAngleTollerance) then
			angle = (angle + snapAngleTollerance) / snapAngle * snapAngle
		end
	end
	return angle
end

---
--- Renders the rotate gizmo for the currently selected object.
---
--- This function is responsible for rendering the visual representation of the rotate gizmo, which is used to manipulate the orientation of the selected object in the editor. It calculates the necessary parameters for rendering the gizmo, such as the axis vectors, rotation angle, and scale, and then calls the appropriate rendering functions to draw the gizmo.
---
--- If there is no selected object, the function sets the mesh to an empty string, effectively hiding the gizmo.
---
--- @param self RotateGizmo The rotate gizmo object.
---
function RotateGizmo:Render()
	local obj = not XEditorIsContextMenuOpen() and selo()
	if obj then
		if self.local_cs then
			self.v_axis_x, self.v_axis_y, self.v_axis_z = GetAxisVectors(obj)
		else
			self.v_axis_x = axis_x
			self.v_axis_y = axis_y
			self.v_axis_z = axis_z
			self:SetOrientation(axis_z, 0)
		end
		self:SetPos(self.init_pos or CenterOfMasses(editor.GetSel()))
		self:CalculateScale()
		self:SetMesh(self:RenderGizmo())
	else self:SetMesh(pstr("")) end
end

---
--- Renders the visual representation of the rotate gizmo for the currently selected object.
---
--- This function is responsible for rendering the visual elements of the rotate gizmo, which is used to manipulate the orientation of the selected object in the editor. It calculates the necessary parameters for rendering the gizmo, such as the axis vectors, rotation angle, and scale, and then calls the appropriate rendering functions to draw the gizmo.
---
--- If there is no selected object, the function sets the mesh to an empty string, effectively hiding the gizmo.
---
--- @param self RotateGizmo The rotate gizmo object.
--- @return string The rendered gizmo as a string.
---
function RotateGizmo:RenderGizmo()
	local vpstr = pstr("")
	local center = point(0, 0, 0)
	local pos = selo() and selo():GetVisualPos() or GetTerrainCursor()
	local normal = pos - camera.GetEye()
	normal = Normalize(normal)
	local bigTorusAxis, bigTorusAngle = GetAxisAngle(axis_z, normal)
	bigTorusAxis = Normalize(camera.GetEye() - self:GetPos())
	bigTorusAngle = bigTorusAngle / 60
	
	self.mesh_big = self:RenderBigTorus(nil, bigTorusAxis)
	self.mesh_sphere = self:RenderCircle(nil, bigTorusAxis, bigTorusAngle)
	self.mesh_x = self:RenderTorusAndAxis(nil, self.v_axis_x, self.b_over_x, normal)
	self.mesh_y = self:RenderTorusAndAxis(nil, self.v_axis_y, self.b_over_y, normal)
	self.mesh_z = self:RenderTorusAndAxis(nil, self.v_axis_z, self.b_over_z, normal)
	
	if self.text then
		self.text:SetText((self.rotation_snap and "<color 255 235 64>" or "") .. string.format("%.2f°", self.rotation_angle))
	end
	
	vpstr = self:RenderBigTorus(vpstr, bigTorusAxis, self.b_over_big, true)
	vpstr = self:RenderOutlineTorus(vpstr, bigTorusAxis)
	vpstr = self:RenderCircle(vpstr, bigTorusAxis, bigTorusAngle, self.b_over_sphere)
	vpstr = self:RenderTorusAndAxis(vpstr, self.v_axis_x, self.b_over_x, normal, RGBA(192, 0, 0, self.opacity), true)
	vpstr = self:RenderTorusAndAxis(vpstr, self.v_axis_y, self.b_over_y, normal, RGBA(0, 192, 0, self.opacity), true)
	vpstr = self:RenderTorusAndAxis(vpstr, self.v_axis_z, self.b_over_z, normal, RGBA(0, 0, 192, self.opacity), true)
	return self:RenderTangent(vpstr)
end

---
--- Calculates the scale of the rotate gizmo based on the camera distance.
---
--- This function is responsible for calculating the scale of the rotate gizmo, which is used to ensure that the gizmo remains a consistent size relative to the camera distance. It calculates the distance between the camera and the gizmo, and then sets the scale of the gizmo based on this distance.
---
--- @param self RotateGizmo The rotate gizmo object.
---
function RotateGizmo:CalculateScale()
	local eye = camera.GetEye()
	local dir = self:GetVisualPos()
	local ray = dir - eye
	local cameraDistanceSquared = ray:x() * ray:x() + ray:y() * ray:y() + ray:z() * ray:z()
	local cameraDistance = 0
	if cameraDistanceSquared >= 0 then cameraDistance = sqrt(cameraDistanceSquared) end
	self.scale = cameraDistance / 20 * self.scale / 100
end

---
--- Checks if the ray intersects with any of the gizmo's meshes.
---
--- This function is responsible for determining if a ray, defined by the two points `pt1` and `pt2`, intersects with any of the gizmo's meshes. It sets various boolean flags (`b_over_x`, `b_over_y`, `b_over_z`, `b_over_big`, `b_over_sphere`) to indicate which mesh the ray intersected with.
---
--- @param self RotateGizmo The rotate gizmo object.
--- @param pt1 point The first point of the ray.
--- @param pt2 point The second point of the ray.
--- @return boolean True if the ray intersects with any of the gizmo's meshes, false otherwise.
---
function RotateGizmo:IntersectRay(pt1, pt2)
	self.b_over_z = IntersectRayMesh(self, pt1, pt2, self.mesh_z)
	self.b_over_x = IntersectRayMesh(self, pt1, pt2, self.mesh_x)	
	self.b_over_y = IntersectRayMesh(self, pt1, pt2, self.mesh_y)
	self.b_over_big = IntersectRayMesh(self, pt1, pt2, self.mesh_big)
	
	self.b_over_sphere = false
	if self.b_over_z then
		self.b_over_x = false
		self.b_over_y = false
		return true
	elseif self.b_over_x then
		self.b_over_y = false
		self.b_over_z = false
		return true
	elseif self.b_over_y then
		self.b_over_z = false
		self.b_over_x = false
		return true
	elseif self.b_over_big then
		return true
	end
	
	self.b_over_sphere = IntersectRayMesh(self, pt1, pt2, self.mesh_sphere)
	return self.b_over_sphere
end

---
--- Checks if the cursor is intersecting with any of the gizmo's meshes and calculates the rotation axis and tangent vector based on the intersection.
---
--- This function is responsible for determining if the cursor, defined by the two points `pt1` and `pt2`, intersects with any of the gizmo's meshes. It sets various boolean flags (`b_over_x`, `b_over_y`, `b_over_z`, `b_over_big`, `b_over_sphere`) to indicate which mesh the cursor intersected with. Based on the intersection, it calculates the rotation axis and tangent vector that will be used for the rotation operation.
---
--- @param self RotateGizmo The rotate gizmo object.
--- @param mouse_pos point The position of the cursor on the screen.
--- @return point The intersection point of the cursor with the gizmo's meshes.
---
function RotateGizmo:CursorIntersection(mouse_pos)
	local pt1 = camera.GetEye()
	local pt2 = ScreenToGame(mouse_pos)
	local pos = self:GetVisualPos()
	local pt_intersection = self.b_over_x or self.b_over_y or self.b_over_z or self.b_over_big
	if pt_intersection then
		if not self.operation_started then
			self.rotation_axis =
				self.b_over_x and self.v_axis_x or
				self.b_over_y and self.v_axis_y or
				self.b_over_z and self.v_axis_z or
				self.b_over_big and (camera.GetEye() - pos)
			self.rotation_axis = Normalize(self.rotation_axis)
			self.tangent_offset = pt_intersection - pos
			self.tangent_vector = Cross(self.rotation_axis, Normalize(self.tangent_offset))
			self.tangent_vector = Normalize(self.tangent_vector)
			self.tangent_axis, self.tangent_angle = GetAxisAngle(axis_z, self.tangent_vector)
			self.tangent_axis, self.tangent_angle = Normalize(self.tangent_axis), self.tangent_angle / 60
		end
		
		local axis
		if self.b_over_x then
			axis = self.v_axis_x
		elseif self.b_over_y then
			axis = self.v_axis_y
		elseif self.b_over_z then
			axis = self.v_axis_z
		elseif self.b_over_big then
			axis = camera.GetEye() - pos
		end
		local camDir = Normalize(camera.GetEye() - pos)
		local camX = Normalize(Cross((camDir), axis_z))
		local planeB = pos + camX
		local planeC = pos + Normalize(Cross((camDir), camX))
		local ptA = pos + self.tangent_offset
		local ptB = ptA + self.tangent_vector
		local intersection = IntersectRayPlane(pt1, pt2, pos, planeB, planeC)
		return ProjectPointOnLine(ptA, ptB, intersection)
	elseif self.b_over_sphere then
		local axis = Normalize(camera.GetEye() - pos)
		local screenX = Cross(axis, axis_z)
		local screenY = Cross(axis, axis_x)
		local planeB = pos + screenX
		local planeC = pos + screenY
		return IntersectRayPlane(pt1, pt2, pos, planeB, planeC)
	end
end

--- Renders a tangent vector visualization for the rotate gizmo.
---
--- @param vpstr string The vertex buffer to append the tangent visualization to.
--- @return string The updated vertex buffer.
function RotateGizmo:RenderTangent(vpstr)
	if self.tangent_vector then
		local radius = 0.1 * self.scale * self.thickness / 100
		local length = 2.5 * self.scale
		local coneHeight = 0.50 * self.scale
		local coneRadius = 0.30 * self.scale * self.thickness / 100
		local color = RGBA(255, 0, 255, self.opacity)
		vpstr = AppendConeVertices(vpstr, point(0, 0, -length), point(0, 0, length * 2), radius, radius, self.tangent_axis, self.tangent_angle, color, self.tangent_offset)
		vpstr = AppendConeVertices(vpstr, point(0, 0, -length), point(0, 0, -coneHeight), coneRadius, 0, self.tangent_axis, self.tangent_angle, color, self.tangent_offset)
		vpstr = AppendConeVertices(vpstr, point(0, 0, length), point(0, 0, coneHeight), coneRadius, 0, self.tangent_axis, self.tangent_angle, color, self.tangent_offset)
	end
	return vpstr
end

---
--- Renders a circle visualization for the rotate gizmo.
---
--- @param vpstr string The vertex buffer to append the circle visualization to.
--- @param axis point The axis around which the circle is rotated.
--- @param angle number The angle of rotation around the axis.
--- @param selected boolean Whether the circle is selected.
--- @return string The updated vertex buffer.
function RotateGizmo:RenderCircle(vpstr, axis, angle, selected)
	vpstr = vpstr or pstr("")
	local HSeg = 32
	local center = point(0, 0, 0)
	local rad = Cross(axis, axis_z)
	local radius = 2.3 * self.scale
	local color = selected and RGBA(255, 255, 0, 70 * self.opacity / 255) or RGBA(0, 0, 0, 0)
	rad = Normalize(rad)
	rad = MulDivRound(rad, radius, 4096)
	for i = 1, HSeg do
		local pt = Rotate(rad, MulDivRound(360 * 60, i, HSeg))
		pt = RotateAxis(pt, rad, angle * 60)
		local nextPt = Rotate(rad, MulDivRound(360 * 60, i + 1, HSeg))
		nextPt = RotateAxis(nextPt, rad, angle * 60)
		vpstr:AppendVertex(center, color)
		vpstr:AppendVertex(pt)
		vpstr:AppendVertex(nextPt)
	end
	return vpstr
end

---
--- Renders a big torus visualization for the rotate gizmo.
---
--- @param vpstr string The vertex buffer to append the torus visualization to.
--- @param axis point The axis around which the torus is rotated.
--- @param selected boolean Whether the torus is selected.
--- @param visual boolean Whether to render the torus with a visual thickness.
--- @return string The updated vertex buffer.
function RotateGizmo:RenderBigTorus(vpstr, axis, selected, visual)
	local radius1 = 3.5 * self.scale
	local radius2 = visual and 0.15 * self.scale * self.thickness / 100 or 0.15 * self.scale
	local color = selected and RGBA(255, 255, 0, self.opacity) or RGBA(0, 192, 192, self.opacity)
	return AppendTorusVertices(vpstr, radius1, radius2, axis, color)
end

---
--- Renders a torus and axis visualization for the rotate gizmo.
---
--- @param vpstr string The vertex buffer to append the torus and axis visualization to.
--- @param axis point The axis around which the torus is rotated.
--- @param selected boolean Whether the torus is selected.
--- @param normal point The normal vector for the torus.
--- @param color RGBA The color of the torus.
--- @param visual boolean Whether to render the torus with a visual thickness.
--- @return string The updated vertex buffer.
function RotateGizmo:RenderTorusAndAxis(vpstr, axis, selected, normal, color, visual)
	local radius1 = 2.3 * self.scale
	local radius2 = visual and 0.15 * self.scale * self.thickness / 100 or 0.15 * self.scale
	color = selected and RGBA(255, 255, 0, self.opacity) or color
	
	local height = 1.5 * self.scale
	local radius = 0.05 * self.scale
	vpstr = AppendTorusVertices(vpstr, radius1, radius2, axis, color, normal)
	local axis, angle = GetAxisAngle(axis_z, axis)
	axis = Normalize(axis)
	angle = angle / 60
	return AppendConeVertices(vpstr, nil, point(0, 0, height), radius, radius, axis, angle, color)
end

---
--- Renders an outline torus visualization for the rotate gizmo.
---
--- @param vpstr string The vertex buffer to append the torus visualization to.
--- @param axis point The axis around which the torus is rotated.
--- @return string The updated vertex buffer.
function RotateGizmo:RenderOutlineTorus(vpstr, axis)
	local radius1 = 2.3 * self.scale
	local radius2 = 0.15 * self.scale * self.thickness / 100
	local color = RGBA(128, 128, 128, 192 * self.opacity / 255)
	return AppendTorusVertices(vpstr, radius1, radius2, axis, color)
end