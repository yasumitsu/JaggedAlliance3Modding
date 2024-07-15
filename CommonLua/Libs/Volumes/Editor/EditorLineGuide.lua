-- ExtrasGen based editor tools place fences, decals, etc. alongside these line guide helper objects
--
-- The line guide is aligned to the object's X axis, and the line normal direction - to the Z axis.
-- The line guide length is determined by the object's Scale; it is StandardLength long at normal scale.

DefineClass.EditorLineGuide = {
	__parents = { "Mesh", "CollideLuaObject", "EditorVisibleObject", "EditorCallbackObject" },
	
	StandardLength = 10 * guim, -- length at 100% scale
	NormalColor = RGB(240, 240, 240),
	HighlightColor = RGB(240, 230, 150),
	SelectedColor = RGB(240, 230, 40),
	
	collide_mesh = false,
	color = RGB(240, 240, 240),
}

-- rotates the object so that axis1 before the rotation matches axis2 after the rotation
local function rotate_to_match(obj, axis1, axis2)
	axis1, axis2 = SetLen(axis1, 4096), SetLen(axis2, 4096)
	local axis = Cross(axis1, axis2)
	if axis ~= point30 then
		obj:Rotate(axis, GetAngle(axis1, axis2))
	end
end

---
--- Sets the position, orientation, and scale of the EditorLineGuide object based on the provided parameters.
---
--- @param pos1 table The first position point.
--- @param pos2 table The second position point.
--- @param normal table The normal vector.
function EditorLineGuide:Set(pos1, pos2, normal)
	local pos = (pos1 + pos2) / 2
	self:SetPos(pos)
	self:SetOrientation(normal, 0)
	self:SetScale(MulDivRound((pos1 - pos2):Len(), 100, self.StandardLength))
	
	local axis1 = self:GetRelativePoint(axis_y) - self:GetPos()
	local axis2 = pos1 - self:GetPos()
	rotate_to_match(self, axis1, axis2)
	
	self:SetGameFlags(const.gofPermanent)
	self:UpdateVisuals()
end

---
--- Returns the length of the EditorLineGuide object.
---
--- @return number The length of the EditorLineGuide object.
function EditorLineGuide:GetLength()
	return MulDivRound(self.StandardLength, self:GetScale(), 100)
end

---
--- Sets the length of the EditorLineGuide object.
---
--- @param length number The new length of the EditorLineGuide object.
function EditorLineGuide:SetLength(length)
	self:SetScale(MulDivRound(length, 100, self.StandardLength))
	self:UpdateVisuals()
end

---
--- Returns the first position point of the EditorLineGuide object.
---
--- @return table The first position point.
function EditorLineGuide:GetPos1()
	return self:GetRelativePoint(SetLen(axis_y, self.StandardLength / 2))
end

---
--- Returns the second position point of the EditorLineGuide object.
---
--- @return table The second position point.
function EditorLineGuide:GetPos2()
	return self:GetRelativePoint(-SetLen(axis_y, self.StandardLength / 2))
end

---
--- Returns the normal vector of the EditorLineGuide object.
---
--- @return table The normal vector.
function EditorLineGuide:GetNormal()
	return self:GetRelativePoint(axis_z) - self:GetVisualPos()
end

---
--- Returns whether the EditorLineGuide object is horizontal.
---
--- @return boolean True if the EditorLineGuide object is horizontal, false otherwise.
function EditorLineGuide:IsHorizontal()
	local tangent = self:GetRelativePoint(axis_y) - self:GetPos()
	local angle = GetAngle(tangent, axis_z) / 60
	return abs(angle) > 85
end

--- Returns whether the EditorLineGuide object is vertical.
---
--- @return boolean True if the EditorLineGuide object is vertical, false otherwise.
function EditorLineGuide:IsVertical()
	local tangent = self:GetRelativePoint(axis_y) - self:GetPos()
	local angle = GetAngle(tangent, axis_z) / 60
	return angle < 5 or angle > 175
end

---
--- Updates the visuals of the EditorLineGuide object.
---
--- If the scale of the EditorLineGuide is 0, the mesh is set to an empty string and the function returns.
---
--- Otherwise, the function calculates the offset, arrow length, normal, and along vectors to construct the mesh for the EditorLineGuide. The mesh is then set using the calculated vertices and the EditorLineGuide's color.
---
--- If the editor is active, the EditorLineGuide's visibility flag is set.
---
--- @param self EditorLineGuide The EditorLineGuide object to update.
function EditorLineGuide:UpdateVisuals()
	if self:GetScale() == 0 then
		self:SetMesh(pstr(""))
		return
	end

	local offset = SetLen(axis_y, self.StandardLength / 2)
	local arrowlen = MulDivRound(guim / 2, 100, self:GetScale())
	local normal = SetLen(axis_z, arrowlen)
	local along = SetLen(offset, arrowlen / 2)

	local str = pstr("")
	str:AppendVertex(offset, self.color)
	str:AppendVertex(-offset)
	str:AppendVertex(-along)
	str:AppendVertex(normal)
	str:AppendVertex(normal)
	str:AppendVertex(along)
	self:SetShader(ProceduralMeshShaders.mesh_linelist)
	self:SetMesh(str)
	
	if IsEditorActive() then
		self:SetEnumFlags(const.efVisible)
	end
end

EditorLineGuide.EditorCallbackPlaceCursor = EditorLineGuide.UpdateVisuals
EditorLineGuide.EditorCallbackPlace       = EditorLineGuide.UpdateVisuals
EditorLineGuide.EditorCallbackScale       = EditorLineGuide.UpdateVisuals
EditorLineGuide.EditorEnter               = EditorLineGuide.UpdateVisuals

--- Returns the bounding box of the EditorLineGuide object.
---
--- The bounding box is calculated by growing the box that spans the length of the line guide by a small amount in each dimension to account for the thickness of the line.
---
--- @return table The bounding box of the EditorLineGuide object.
function EditorLineGuide:GetBBox()
	local grow = guim / 4
	local length = self:GetLength()
	return GrowBox(box(0, -length / 2, 0, 0, length / 2, 0), grow, grow, grow)
end

--- Tests if a ray intersects with the EditorLineGuide object.
---
--- This function is a placeholder for future implementation. It currently always returns true, indicating that the ray intersects with the EditorLineGuide.
---
--- @param self EditorLineGuide The EditorLineGuide object.
--- @param pos table The starting position of the ray.
--- @param dir table The direction of the ray.
--- @return boolean True if the ray intersects with the EditorLineGuide, false otherwise.
function EditorLineGuide:TestRay(pos, dir)
	-- TODO: Refactor C++ code to expect intersection point to be returned
	return true
end


----- Selection and highlighting on hover

if FirstLoad then
	SelectedLineGuides = {}
end

--- Sets the highlight state of the EditorLineGuide object.
---
--- @param self EditorLineGuide The EditorLineGuide object.
--- @param highlight boolean Whether the EditorLineGuide should be highlighted or not.
function EditorLineGuide:SetHighlighted(highlight)
	local selected = table.find(SelectedLineGuides, self)
	self.color = selected  and self.SelectedColor  or
	             highlight and self.HighlightColor or self.NormalColor
	self:UpdateVisuals()
end

function OnMsg.EditorSelectionChanged(objects)
	local lines = table.ifilter(objects, function(idx, obj) return IsKindOf(obj, "EditorLineGuide") end )
	if #lines > 0 then
		for _, line in ipairs(table.subtraction(lines, SelectedLineGuides)) do
			line.color = line.SelectedColor
			line:UpdateVisuals()
		end
	end
	if #SelectedLineGuides > 0 then
		for _, line in ipairs(table.subtraction(SelectedLineGuides, lines)) do
			if IsValid(line) then
				line.color = nil
				line:UpdateVisuals()
			end
		end
	end
	SelectedLineGuides = lines
end
