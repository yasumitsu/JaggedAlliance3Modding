DefineClass.ScaleGizmo = {
	__parents = { "XEditorGizmo" },
	
	HasLocalCSSetting = false,
	HasSnapSetting = false,
	
	Title = "Scale gizmo (R)",
	Description = false,
	ActionSortKey = "3",
	ActionIcon = "CommonAssets/UI/Editor/Tools/ScaleGizmo.tga",
	ActionShortcut = "R",
	UndoOpName = "Scaled %d object(s)",

	side_mesh_a = pstr(""),
	side_mesh_b = pstr(""),
	side_mesh_c = pstr(""),
	
	b_over_a = false,
	b_over_b = false,
	b_over_c = false,
	
	scale = 100,
	thickness = 100,
	opacity = 255,
	sensitivity = 100,
	
	operation_started = false,
	initial_scales = false,
	text = false,
	scale_text = "",
	init_pos = false,
	init_mouse_pos = false,
	group_scale = false,
}

--- Deletes the text associated with the scale gizmo.
--- This function is called when the scale gizmo operation is completed.
function ScaleGizmo:Done()
	self:DeleteText()
end

function ScaleGizmo:DeleteText()
	if self.text then
		self.text:delete()
		self.text = nil
		self.scale_text = ""
	end
end

---
--- Checks if the scale gizmo operation can be started based on the given point.
---
--- @param pt Vector2 The screen position to check.
--- @return boolean True if the scale gizmo operation can be started, false otherwise.
---
function ScaleGizmo:CheckStartOperation(pt)
	return #editor.GetSel() > 0 and self:IntersectRay(camera.GetEye(), ScreenToGame(pt))
end

---
--- Starts the scale gizmo operation.
---
--- @param pt Vector2 The screen position where the operation was started.
---
function ScaleGizmo:StartOperation(pt)
	self.text = XTemplateSpawn("XFloatingText")
	self.text:SetTextStyle("GizmoText")
	self.text:AddDynamicPosModifier({id = "attached_ui", target = self:GetPos()})
	self.text.TextColor = RGB(255, 255, 255)
	self.text.ShadowType = "outline"
	self.text.ShadowSize = 1
	self.text.ShadowColor = RGB(64, 64, 64)
	self.text.Translate = false
	self.init_pos = self:GetPos()
	self.init_mouse_pos = terminal.GetMousePos()
	self.initial_scales = {}
	for _, obj in ipairs(editor.GetSel()) do
		self.initial_scales[obj] = { scale = obj:GetScale(), offset = obj:GetVisualPos() - self.init_pos }
	end
	self.group_scale = terminal.IsKeyPressed(const.vkAlt)
	self.operation_started = true
end

---
--- Performs the scale gizmo operation based on the current mouse position.
---
--- @param pt Vector2 The screen position of the mouse.
---
function ScaleGizmo:PerformOperation(pt)
	local screenHeight = UIL.GetScreenSize():y()
	local mouseY = 4096.0 * (terminal.GetMousePos():y() - screenHeight / 2) / screenHeight
	local initY = 4096.0 * (self.init_mouse_pos:y() - screenHeight / 2) / screenHeight
	local scale
	if mouseY < initY then
		scale = 100 * (mouseY + 4096) / (initY + 4096) + 250  * (initY - mouseY) / (initY + 4096)
	else
		scale = 100 * (4096 - mouseY) / (4096 - initY) + 10  * (mouseY - initY) / (4096 - initY)
	end
	scale = 100 + MulDivRound(scale - 100, self.sensitivity, 100)
	self:SetScaleClamped(scale)
	
	for obj, data in pairs(self.initial_scales) do
		obj:SetScaleClamped(MulDivRound(data.scale, scale, 100))
		if self.group_scale then
			XEditorSetPosAxisAngle(obj, self.init_pos + data.offset * scale / 100)
		end
	end
	
	local objs = table.keys(self.initial_scales)
	self.scale_text = #objs == 1 and
		string.format("%.2f", objs[1]:GetScale() / 100.0) or
		((scale >= 100 and "+" or "-") .. string.format("%d%%", abs(scale - 100)))
	Msg("EditorCallback", "EditorCallbackScale", objs)
end

---
--- Ends the scale gizmo operation, resetting the state.
---
--- This function is called when the scale gizmo operation is completed. It cleans up the state of the scale gizmo, including deleting the text, resetting the scale, and clearing the initial position, mouse position, scales, group scale, and operation started flag.
---
--- @function ScaleGizmo:EndOperation
--- @return nil
function ScaleGizmo:EndOperation()
	self:DeleteText()
	self:SetScale(100)
	self.init_pos = false
	self.init_mouse_pos = false
	self.initial_scales = false
	self.group_scale = false
	self.operation_started = false
end

---
--- Renders the scale gizmo mesh.
---
--- This function is responsible for rendering the visual representation of the scale gizmo. It calculates the positions of the various components of the gizmo (floor planes, upper point, and cylinders) based on the current scale, and then renders them using the `RenderPlane` and `RenderCylinder` functions. It also updates the text display to show the current scale.
---
--- @return string The rendered gizmo mesh as a string.
function ScaleGizmo:RenderGizmo()
	local FloorPtA = MulDivRound(point(0, 4096, 0), self.scale * 25, 40960)
	local FloorPtB = MulDivRound(point(-3547, -2048, 0), self.scale * 25, 40960)
	local FloorPtC = MulDivRound(point(3547, -2048, 0), self.scale * 25, 40960)
	local UpperPt = MulDivRound(point(0, 0, 5900), self.scale * 25, 40960)
	local PyramidSize = FloorPtA:Dist(FloorPtB)
	
	self.side_mesh_a = self:RenderPlane(nil, UpperPt, FloorPtB, FloorPtC)
	self.side_mesh_b = self:RenderPlane(nil, FloorPtA, UpperPt, FloorPtC)
	self.side_mesh_c = self:RenderPlane(nil, FloorPtA, UpperPt, FloorPtB)
	
	if self.text then
		self.text:SetText(self.scale_text)
	end
	
	local vpstr = pstr("")
	vpstr = self:RenderCylinder(vpstr, PyramidSize, FloorPtA, 90, FloorPtB)
	vpstr = self:RenderCylinder(vpstr, PyramidSize, FloorPtB, 90, FloorPtC)
	vpstr = self:RenderCylinder(vpstr, PyramidSize, FloorPtC, 90, FloorPtA)
	vpstr = self:RenderCylinder(vpstr, PyramidSize, Cross(FloorPtA, axis_z), 35, FloorPtA)
	vpstr = self:RenderCylinder(vpstr, PyramidSize, Cross(FloorPtB, axis_z), 35, FloorPtB)
	vpstr = self:RenderCylinder(vpstr, PyramidSize, Cross(FloorPtC, axis_z), 35, FloorPtC)
	
	if self.b_over_a then vpstr = self:RenderPlane(vpstr, UpperPt, FloorPtB, FloorPtC)
	elseif self.b_over_b then vpstr = self:RenderPlane(vpstr, FloorPtA, UpperPt, FloorPtC)
	elseif self.b_over_c then vpstr = self:RenderPlane(vpstr, FloorPtA, UpperPt, FloorPtB) end
	return vpstr
end

---
--- Updates the scale of the scale gizmo based on the camera distance.
---
--- This function calculates the distance between the camera and the visual position of the scale gizmo, and then updates the scale of the gizmo accordingly. The scale is set to be proportional to the camera distance, with a factor of 1/20 to keep the gizmo at a reasonable size.
---
--- @function ScaleGizmo:ChangeScale
--- @return nil
function ScaleGizmo:ChangeScale()
	local eye = camera.GetEye()
	local dir = self:GetVisualPos()
	local ray = dir - eye
	local cameraDistanceSquared = ray:x() * ray:x() + ray:y() * ray:y() + ray:z() * ray:z()
	local cameraDistance = 0
	if cameraDistanceSquared >= 0 then cameraDistance = sqrt(cameraDistanceSquared) end
	self.scale = cameraDistance / 20 * self.scale / 100
end

---
--- Renders the scale gizmo mesh.
---
--- This function is responsible for rendering the visual representation of the scale gizmo. It first checks if the context menu is open and if there is a selected object. If so, it sets the position of the gizmo to the center of masses of the selected object, updates the scale of the gizmo, and sets the mesh of the gizmo to the result of the `RenderGizmo()` function. If there is no selected object, it sets the mesh of the gizmo to an empty string.
---
--- @return nil
function ScaleGizmo:Render()
	local obj = not XEditorIsContextMenuOpen() and selo()
	if obj then
		self:SetPos(CenterOfMasses(editor.GetSel()))
		self:ChangeScale()
		self:SetMesh(self:RenderGizmo())
	else self:SetMesh(pstr("")) end
end

---
--- Calculates the intersection point between the cursor ray and the scale gizmo.
---
--- This function first checks if the cursor is over any of the three planes of the scale gizmo. If so, it calculates the intersection point between the cursor ray and the plane defined by the gizmo's visual position and the two axis vectors. The function then projects this intersection point onto the line defined by the gizmo's visual position and the z-axis vector, and returns the result.
---
--- @param mouse_pos Vector2 The screen position of the mouse cursor.
--- @return Vector3 The intersection point between the cursor ray and the scale gizmo.
function ScaleGizmo:CursorIntersection(mouse_pos)
	if self.b_over_a or self.b_over_b or self.b_over_c then
		local pos = self:GetVisualPos()
		local planeB = pos + axis_z
		local planeC = pos + axis_x
		local pt1 = camera.GetEye()
		local pt2 = ScreenToGame(mouse_pos)
		local intersection = IntersectRayPlane(pt1, pt2, pos, planeB, planeC)
		return ProjectPointOnLine(pos, pos + axis_z, intersection)
	end
end

---
--- Checks if the cursor ray intersects with any of the three planes of the scale gizmo.
---
--- This function first checks if the cursor ray intersects with the mesh of each of the three planes of the scale gizmo. It stores the result of these checks in the `b_over_a`, `b_over_b`, and `b_over_c` flags. If any of the planes are intersected, the function returns `true`, indicating that the cursor is over the scale gizmo. Otherwise, it returns `false`.
---
--- @param pt1 Vector3 The starting point of the cursor ray
--- @param pt2 Vector3 The ending point of the cursor ray
--- @return boolean True if the cursor ray intersects with any of the scale gizmo planes, false otherwise
function ScaleGizmo:IntersectRay(pt1, pt2)
	self.b_over_a = false
	self.b_over_b = false
	self.b_over_c = false
	
	local overA, lenA = IntersectRayMesh(self, pt1, pt2, self.side_mesh_a)
	local overB, lenB = IntersectRayMesh(self, pt1, pt2, self.side_mesh_b)
	local overC, lenC = IntersectRayMesh(self, pt1, pt2, self.side_mesh_c)
	
	if not (overA or overB or overC) then return end
	
	if lenA and lenB then
		if lenA < lenB then self.b_over_a = overA
		else self.b_over_b = overB end
	elseif lenA and lenC then
		if lenA < lenC then self.b_over_a = overA
		else self.b_over_c = overC end
	elseif lenB and lenC then
		if lenB < lenC then self.b_over_b = overB
		else self.b_over_c = overC end
	elseif lenA then self.b_over_a = overA
	elseif lenB then self.b_over_b = overB
	elseif lenC then self.b_over_c = overC end
	
	return self.b_over_a or self.b_over_b or self.b_over_c
end

---
--- Renders a plane using the provided vertex positions.
---
--- @param vpstr string The vertex position string to append the plane vertices to.
--- @param ptA Vector3 The first vertex position of the plane.
--- @param ptB Vector3 The second vertex position of the plane.
--- @param ptC Vector3 The third vertex position of the plane.
--- @return string The updated vertex position string.
function ScaleGizmo:RenderPlane(vpstr, ptA, ptB, ptC)
	vpstr = vpstr or pstr("")
	vpstr:AppendVertex(ptA, RGBA(255, 255, 0, MulDivRound(200, self.opacity, 255)))
	vpstr:AppendVertex(ptB)
	vpstr:AppendVertex(ptC)
	return vpstr
end

---
--- Renders a cylinder using the provided vertex positions, height, axis, angle, and offset.
---
--- @param vpstr string The vertex position string to append the cylinder vertices to.
--- @param height number The height of the cylinder.
--- @param axis Vector3 The axis of the cylinder.
--- @param angle number The angle of the cylinder.
--- @param offset Vector3 The offset of the cylinder.
--- @return string The updated vertex position string.
function ScaleGizmo:RenderCylinder(vpstr, height, axis, angle, offset)
	vpstr = vpstr or pstr("")
	local center = point(0, 0, 0)
	local radius = 0.10 * self.scale * self.thickness / 100
	local color = RGBA(0, 192, 192, self.opacity)
	return AppendConeVertices(vpstr, center, point(0, 0, height), radius, radius, axis, angle, color, offset)
end