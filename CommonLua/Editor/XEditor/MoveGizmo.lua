DefineClass.MoveGizmoTool = {
	__parents = { "Mesh" },
	
	mesh_x = pstr(""),
	mesh_y = pstr(""),
	mesh_z = pstr(""),
	mesh_xy = pstr(""),
	mesh_xz = pstr(""),
	mesh_yz = pstr(""),

	b_over_axis_x = false,
	b_over_axis_y = false,
	b_over_axis_z = false,
	b_over_plane_xy = false,
	b_over_plane_xz = false,
	b_over_plane_yz = false,
	
	v_axis_x = axis_x,
	v_axis_y = axis_y,
	v_axis_z = axis_z,
	
	opacity = 110,
	
	r_color = RGB(192, 0, 0),
	g_color = RGB(0, 192, 0),
	b_color = RGB(0, 0, 192),
	
	-- rotation arrows, clockwise (cw) and counter-clockwise (ccw)
	arrow_xcw = pstr(""),
	arrow_xccw = pstr(""),
	arrow_ycw = pstr(""),
	arrow_yccw = pstr(""),
	arrow_zcw = pstr(""),
	arrow_zccw = pstr(""),
	
	-- settings
	rotation_arrows_on = false,
	rotation_arrows_z_only = false,
}

---
--- Applies the specified opacity to the given color.
---
--- @param color number The color to apply the opacity to.
--- @param opacity number The opacity value to apply, between 0 and 255.
--- @return number The color with the specified opacity applied.
---
function MoveGizmoTool:ApplyOpacity(color, opacity)
	local r, g, b = GetRGB(color)
	return RGBA(r, g, b, self.opacity)
end

---
--- Renders the move gizmo for the editor.
---
--- This function is responsible for rendering the various components of the move gizmo,
--- including the axes, planes, and rotation arrows. It applies the appropriate opacity
--- and colors to each element based on the current state of the gizmo.
---
--- @param self MoveGizmoTool The instance of the MoveGizmoTool class.
--- @return string The rendered gizmo as a string.
---
function MoveGizmoTool:RenderGizmo()
	local vpstr = pstr("")
	
	self.mesh_x = self:RenderAxis(nil, axis_y, self.b_over_axis_x, false)
	self.mesh_y = self:RenderAxis(nil, -axis_x, self.b_over_axis_y, false)
	self.mesh_z = self:RenderAxis(nil, axis_z, self.b_over_axis_z, false)
	self.mesh_xy = self:RenderPlane(nil, axis_z)
	self.mesh_xz = self:RenderPlane(nil, axis_x)
	self.mesh_yz = self:RenderPlane(nil, -axis_y)
	
	local r = self:ApplyOpacity(self.r_color)
	local g = self:ApplyOpacity(self.g_color)
	local b = self:ApplyOpacity(self.b_color)
	
	self.arrow_xcw  = self:RenderRotationArrow(nil,  axis_x, g, false)
	self.arrow_xccw = self:RenderRotationArrow(nil,  axis_x, g, true)
	self.arrow_ycw  = self:RenderRotationArrow(nil, -axis_y, r, false)
	self.arrow_yccw = self:RenderRotationArrow(nil, -axis_y, r, true)
	self.arrow_zcw  = self:RenderRotationArrow(nil,  axis_z, b, false)
	self.arrow_zccw = self:RenderRotationArrow(nil,  axis_z, b, true)
	
	vpstr = self:RenderAxis(vpstr,  axis_y, self.b_over_axis_x, true, r)
	vpstr = self:RenderAxis(vpstr, -axis_x, self.b_over_axis_y, true, g)
	vpstr = self:RenderAxis(vpstr,  axis_z, self.b_over_axis_z, true, b)
	vpstr = self:RenderPlaneOutlines(vpstr)
	
	if self.b_over_plane_xy then vpstr = self:RenderPlane(vpstr,  axis_z) end
	if self.b_over_plane_xz then vpstr = self:RenderPlane(vpstr,  axis_x) end
	if self.b_over_plane_yz then vpstr = self:RenderPlane(vpstr, -axis_y) end
	
	if self.rotation_arrows_on then
		if not self.rotation_arrows_z_only then
			self:RenderRotationArrow(vpstr,  axis_x, g, false)
			self:RenderRotationArrow(vpstr,  axis_x, g, true)
			self:RenderRotationArrow(vpstr, -axis_y, r, false)
			self:RenderRotationArrow(vpstr, -axis_y, r, true)
		end
		self:RenderRotationArrow(vpstr, axis_z, b, false)
		self:RenderRotationArrow(vpstr, axis_z, b, true)
	end
	
	return vpstr
end

---
--- Updates the scale of the move gizmo based on the camera distance.
---
--- The scale of the move gizmo is calculated as a function of the camera distance, with a minimum scale of 1/20th of the camera distance.
---
--- @param self MoveGizmoTool The instance of the MoveGizmoTool class.
---
function MoveGizmoTool:ChangeScale()
	local eye = camera.GetEye()
	local dir = self:GetVisualPos()
	local ray = dir - eye
	local cameraDistanceSquared = ray:x() * ray:x() + ray:y() * ray:y() + ray:z() * ray:z()
	local cameraDistance = 0
	if cameraDistanceSquared >= 0 then cameraDistance = sqrt(cameraDistanceSquared) end
	self.scale = cameraDistance / 20 * self.scale / 100
end

---
--- Calculates the intersection point between a ray and the move gizmo.
---
--- The function first checks if the ray intersects with any of the axis meshes or rotation arrow meshes. If an intersection is found, the function returns the intersection point projected onto the corresponding axis or plane.
---
--- If no intersection is found with the axis or rotation arrow meshes, the function checks if the ray intersects with any of the plane meshes. If an intersection is found, the function returns the intersection point projected onto the corresponding plane.
---
--- @param self MoveGizmoTool The instance of the MoveGizmoTool class.
--- @param mouse_pos Vector2 The mouse position in screen space.
--- @return Vector3 The intersection point between the ray and the move gizmo.
---
function MoveGizmoTool:CursorIntersection(mouse_pos)
	local pt1 = camera.GetEye()
	local precision = 128 -- should not lead to overflow for maps up to 20x20 km (with guim == 1000)
	local dir = ScreenToGame(mouse_pos, precision) - pt1 * precision
	local pt2 = pt1 + dir
	local pos = self:GetVisualPos()
	if self.b_over_axis_x or self.b_over_axis_y or self.b_over_axis_z then
		local axis
		if self.b_over_axis_x then
			axis = self.v_axis_x
		elseif self.b_over_axis_y then
			axis = self.v_axis_y
		elseif self.b_over_axis_z then
			axis = self.v_axis_z
		end
		local camDir = Normalize(camera.GetEye() - pos)
		local camX = Normalize(Cross((camDir), axis_z))
		local planeB = pos + camX
		local planeC = pos + Normalize(Cross((camDir), camX))
		local ptA = pos
		local ptB = ptA + axis
		local intersection = IntersectRayPlane(pt1, pt2, pos, planeB, planeC)
		intersection = ProjectPointOnLine(ptA, ptB, intersection)
		return intersection
	elseif self.b_over_plane_xy or self.b_over_plane_xz or self.b_over_plane_yz then
		local normal, planeB, planeC
		if self.b_over_plane_xy then
			normal = self.v_axis_z
			planeB = pos + self.v_axis_x
			planeC = pos + self.v_axis_y
		elseif self.b_over_plane_xz then
			normal = self.v_axis_y
			planeB = pos + self.v_axis_x
			planeC = pos + self.v_axis_z
		elseif self.b_over_plane_yz then
			normal = self.v_axis_x
			planeB = pos + self.v_axis_y
			planeC = pos + self.v_axis_z
		end
		local intersection = IntersectRayPlane(pt1, pt2, pos, planeB, planeC)
		intersection = ProjectPointOnPlane(pos, normal, intersection)
		return intersection
	end
end

---
--- Checks if a ray intersects with the move gizmo's axis or plane meshes.
--- 
--- @param pt1 Vector3 The starting point of the ray.
--- @param pt2 Vector3 The ending point of the ray.
--- @return boolean Whether the ray intersected with any of the move gizmo's meshes.
---
function MoveGizmoTool:IntersectRay(pt1, pt2)
	self.b_over_plane_xy = false	
	self.b_over_plane_xz = false
	self.b_over_plane_yz = false
	
	self.b_over_axis_x = IntersectRayMesh(self, pt1, pt2, self.mesh_x)
	self.b_over_axis_y = IntersectRayMesh(self, pt1, pt2, self.mesh_y)
	self.b_over_axis_z = IntersectRayMesh(self, pt1, pt2, self.mesh_z)
	
	local hit, axis, ccw
	if     IntersectRayMesh(self, pt1, pt2, self.arrow_xcw ) then hit, axis, ccw = true,  axis_x, false
	elseif IntersectRayMesh(self, pt1, pt2, self.arrow_xccw) then hit, axis, ccw = true,  axis_x, true
	elseif IntersectRayMesh(self, pt1, pt2, self.arrow_ycw ) then hit, axis, ccw = true, -axis_y, false
	elseif IntersectRayMesh(self, pt1, pt2, self.arrow_yccw) then hit, axis, ccw = true, -axis_y, true
	elseif IntersectRayMesh(self, pt1, pt2, self.arrow_zcw ) then hit, axis, ccw = true,  axis_z, false
	elseif IntersectRayMesh(self, pt1, pt2, self.arrow_zccw) then hit, axis, ccw = true,  axis_z, true end
	self.b_over_rotation_arrow = hit
	self.arrow_axis = axis
	self.arrow_ccw = ccw
	
	if self.b_over_axis_x then
		self.b_over_axis_y = false
		self.b_over_axis_z = false
		return true
	elseif self.b_over_axis_y then
		self.b_over_axis_x = false
		self.b_over_axis_z = false
		return true
	elseif self.b_over_axis_z then
		self.b_over_axis_x = false
		self.b_over_axis_y = false
		return true
	else
		local overPlaneXY, lenXY = IntersectRayMesh(self, pt1, pt2, self.mesh_xy)
		local overPlaneXZ, lenXZ = IntersectRayMesh(self, pt1, pt2, self.mesh_xz)
		local overPlaneYZ, lenYZ = IntersectRayMesh(self, pt1, pt2, self.mesh_yz)
		
		if not (overPlaneXY or overPlaneXZ or overPlaneYZ) then return end
		
		if overPlaneXY then 
			self.b_over_plane_xy = true 
			return true
		elseif lenXZ and lenYZ then
			if lenXZ < lenYZ then 
				self.b_over_plane_xz = overPlaneXZ
				return overPlaneXZ
			else 
				self.b_over_plane_yz = overPlaneYZ 
				return overPlaneYZ
			end
		elseif overPlaneXZ then 
			self.b_over_plane_xz = true
			return true
		elseif overPlaneYZ then 
			self.b_over_plane_yz = true 
			return true
		end
	end
end

---
--- Renders a 3D axis gizmo for the move tool.
---
--- @param vpstr string The vertex buffer to append the axis gizmo to.
--- @param axis Vector The axis to render the gizmo for.
--- @param selected boolean Whether the axis is currently selected.
--- @param visual boolean Whether to render the axis in visual mode.
--- @param color Color The color to render the axis in.
--- @return string The updated vertex buffer with the axis gizmo rendered.
---
function MoveGizmoTool:RenderAxis(vpstr, axis, selected, visual, color)
	vpstr = vpstr or pstr("")
	local cylinderRadius = visual and 0.1 * self.scale * self.thickness / 100 or 0.1 * self.scale
	local cylinderHeight = 4.0 * self.scale
	local coneRadius = visual and 0.45 * self.scale * self.thickness / 100 or 0.45 * self.scale
	local coneHeight = 1.0 * self.scale
	color = selected and RGBA(255, 255, 0, self.opacity) or color
	
	vpstr = AppendConeVertices(vpstr, nil, point(0, 0, cylinderHeight), cylinderRadius, cylinderRadius, axis, 90, color)
	vpstr = AppendConeVertices(vpstr, point(0, 0, cylinderHeight), point(0, 0, coneHeight), coneRadius, 0, axis, 90, color)
	return vpstr
end

---
--- Renders the plane outlines for the move gizmo tool.
---
--- @param vpstr string The vertex buffer to append the plane outlines to.
--- @return string The updated vertex buffer with the plane outlines rendered.
---
function MoveGizmoTool:RenderPlaneOutlines(vpstr)
	local height = 2.5 * self.scale
	local radius = 0.05 * self.scale * self.thickness / 100
	local r = self:ApplyOpacity(self.r_color)
	local g = self:ApplyOpacity(self.g_color)
	local b = self:ApplyOpacity(self.b_color)
	
	vpstr = AppendConeVertices(vpstr, nil, point(0, 0, height), radius, radius,  axis_z, 90, r, point(height, 0, 0))
	vpstr = AppendConeVertices(vpstr, nil, point(0, 0, height), radius, radius, -axis_x, 90, r, point(height, 0, 0))
	vpstr = AppendConeVertices(vpstr, nil, point(0, 0, height), radius, radius,  axis_z, 90, g, point(0, height, 0))
	vpstr = AppendConeVertices(vpstr, nil, point(0, 0, height), radius, radius,  axis_y, 90, g, point(0, height, 0))
	vpstr = AppendConeVertices(vpstr, nil, point(0, 0, height), radius, radius,  axis_y, 90, b, point(0, 0, height))
	vpstr = AppendConeVertices(vpstr, nil, point(0, 0, height), radius, radius, -axis_x, 90, b, point(0, 0, height))
	return vpstr
end

---
--- Transforms a set of points to be aligned with the specified axis.
---
--- @param axis Vector The axis to align the points to.
--- @param ... Vector The points to transform.
--- @return table The transformed points.
---
function MoveGizmoTool:TransformPointsToAxisPlane(axis, ...)
	local angle = (axis == -axis_y or axis == axis_x) and 90 * 60 or 0
	local pts = table.pack(...)
	for i, pt in ipairs(pts) do
		pts[i] = RotateAxis(pt, axis, angle)
	end
	return pts
end

---
--- Renders a plane outline for the move gizmo tool.
---
--- @param vpstr string The vertex buffer to append the plane outline to.
--- @param axis Vector The axis to align the plane to.
--- @return string The updated vertex buffer with the plane outline rendered.
---
function MoveGizmoTool:RenderPlane(vpstr, axis)
	vpstr = vpstr or pstr("")
	local color = RGBA(255, 255, 0, self.opacity * 200 / 255)
	local dist = 2.5 * self.scale
	local pts = self:TransformPointsToAxisPlane(axis, point30, point(dist, 0, 0), point(dist, dist, 0), point(0, dist, 0))
 	vpstr:AppendVertex(pts[1], color)
	vpstr:AppendVertex(pts[2])
	vpstr:AppendVertex(pts[4])
	vpstr:AppendVertex(pts[3])
	vpstr:AppendVertex(pts[2])
	vpstr:AppendVertex(pts[4])
	return vpstr
end

---
--- Renders a rotation arrow for the move gizmo tool.
---
--- @param vpstr string The vertex buffer to append the rotation arrow to.
--- @param axis Vector The axis to align the rotation arrow to.
--- @param color RGBA The color of the rotation arrow.
--- @param ccw boolean Whether the rotation arrow should be drawn counter-clockwise.
--- @return string The updated vertex buffer with the rotation arrow rendered.
---
function MoveGizmoTool:RenderRotationArrow(vpstr, axis, color, ccw)
	local size = 0.7 * self.scale
	local dist = 2.1 * self.scale
	local offs = 0.1 * self.scale
	local corner = point(dist, dist, 0)
	local offset = point(offs, offs, 0)
	local a1, a2, a3 = point(size, 0, 0), point(0, size, 0), point(size, size, 0)
	a1 = Rotate(a1 + offset, (ccw and 45 or -45) * 60) + corner
	a2 = Rotate(a2 + offset, (ccw and 45 or -45) * 60) + corner
	a3 = Rotate(a3 + offset, (ccw and 45 or -45) * 60) + corner
	
	if self.b_over_rotation_arrow and axis == self.arrow_axis and self.arrow_ccw == ccw then
		color = RGBA(255, 255, 0, self.opacity * 200 / 255)
	end
	
	vpstr = vpstr or pstr("")
	local pts = self:TransformPointsToAxisPlane(axis, a1, a2, a3)
 	vpstr:AppendVertex(pts[1], color)
	vpstr:AppendVertex(pts[2])
	vpstr:AppendVertex(pts[3])
	return vpstr
end

DefineClass.MoveGizmo = {
	__parents = { "XEditorGizmo", "MoveGizmoTool" },
	
	HasLocalCSSetting = true,
	HasSnapSetting = true,
	
	Title = "Move gizmo (W)",
	Description = false,
	ActionSortKey = "1",
	ActionIcon = "CommonAssets/UI/Editor/Tools/MoveGizmo.tga",
	ActionShortcut = "W",
	UndoOpName = "Moved %d object(s)",
	
	rotation_arrows_on = true,
	
	operation_started = false,
	initial_positions = false,
	initial_pos = false,
	initial_gizmo_pos = false,
	move_by_slabs = false,
}

--- Checks if the move operation can be started based on the current selection and cursor position.
---
--- @param pt Vector The cursor position.
--- @param btn_pressed boolean Whether a button was pressed.
--- @return string|nil The result of the operation, or nil if the operation cannot be started.
function MoveGizmo:CheckStartOperation(pt, btn_pressed)
	local objs = editor.GetSel()
	if #objs == 0 then return end
	
	-- check move operations first
	local ret = self:IntersectRay(camera.GetEye(), ScreenToGame(pt))
	if ret then return ret end
	
	if self.b_over_rotation_arrow and btn_pressed then
		XEditorUndo:BeginOp{ objects = objs, name = string.format("Rotated %d objects", #objs) }
		
		local center = self:GetVisualPos()
		local axis = self.arrow_axis
		if axis ~= axis_z then
			axis = SetLen(Cross(self.arrow_axis, axis_z), 4096)
		end
		local angle = self.arrow_ccw and 90*60 or -90*60
		if self.local_cs then
			axis = self:GetRelativePoint(axis) - self:GetVisualPos()
		end
		
		local rotate_logic = XEditorRotateLogic:new()
		SuspendPassEditsForEditOp()
		rotate_logic:InitRotation(objs, center, 0)
		rotate_logic:Rotate(objs, "group_rotation", center, axis, angle)
		ResumePassEditsForEditOp()
		
		XEditorUndo:EndOp(objs)
		return "break"
	end
end

function MoveGizmo:StartOperation(pt)
	self.initial_positions = {}
	
	local has_aligned, move_by_z = false, self.b_over_axis_z or self.b_over_plane_xz or self.b_over_plane_yz
	for _, obj in ipairs(editor.GetSel()) do
		local pos = obj:GetVisualPos()
		if obj:IsKindOf("AlignedObj") then
			pos = move_by_z and pos:AddZ((const.SlabSizeZ or 0) / 2) or obj:GetPos()
			has_aligned = true
		end
		self.initial_positions[obj] = pos
	end
	
	self.move_by_slabs = has_aligned
	self.initial_pos = self:CursorIntersection(pt)
	self.initial_gizmo_pos = self:GetVisualPos()
	self.operation_started = true
end

---
--- Performs the move operation for the selected objects based on the cursor intersection point.
---
--- @param pt Vector3 The current cursor position.
--- @return string|nil Returns "break" to indicate the operation is complete, or nil to continue processing.
function MoveGizmo:PerformOperation(pt)
	local intersection = self:CursorIntersection(pt)
	if intersection then
		local objs = {}
		local vMove = intersection - self.initial_pos
		for obj, pos in pairs(self.initial_positions) do
			XEditorSnapPos(obj, pos, vMove, self.move_by_slabs)
			objs[#objs + 1] = obj
		end
		self:SetPos(self.initial_gizmo_pos + vMove)
		Msg("EditorCallback", "EditorCallbackMove", objs)
	end
end

---
--- Ends the move operation for the selected objects.
---
--- This function resets the state of the move gizmo, clearing the initial positions, cursor intersection point, and operation started flag.
---
--- @return nil
function MoveGizmo:EndOperation()
	self.initial_positions = false
	self.initial_pos = false
	self.operation_started = false
	self.initial_gizmo_pos = false
end

local saneBox = box(-const.SanePosMaxXY, -const.SanePosMaxXY, const.SanePosMaxXY - 1, const.SanePosMaxXY - 1)
local saneZ = const.SanePosMaxZ

---
--- Renders the move gizmo for the selected objects in the editor.
---
--- This function sets the axis and orientation of the move gizmo based on the selected object, and positions the gizmo at the center of the selected objects. If the move operation has already started, it maintains the gizmo's position relative to the initial position. The function also changes the scale of the gizmo and sets the mesh to be rendered.
---
--- @param self MoveGizmo The move gizmo object.
--- @return nil
function MoveGizmo:Render()
	local obj = not XEditorIsContextMenuOpen() and selo()
	if obj then
		if self.local_cs then
			self.v_axis_x, self.v_axis_y, self.v_axis_z = GetAxisVectors(obj)
			self:SetAxisAngle(obj:GetAxis(), obj:GetAngle())
		else
			self.v_axis_x = axis_x
			self.v_axis_y = axis_y
			self.v_axis_z = axis_z
			self:SetOrientation(axis_z, 0)
		end
		if not self.operation_started then
			local pos = CenterOfMasses(editor.GetSel())
			local clamped_pos = ClampPoint(pos, saneBox):SetZ(Clamp(pos:z(), -saneZ, saneZ - 1))
			self:SetPos(clamped_pos, 0)
		end
		self:ChangeScale()
		self:SetMesh(self:RenderGizmo())
	else 
		self:SetMesh(pstr("")) 
	end
end
