if const.maxCollidersPerObject == 0 then
	return -- TODO: Remove this check when Bacon is deprecated. All new projects should use the new collisions.
end

DefineClass.XStickToCollisionHelper = {
	__parents = { "XObjectPlacementHelper" },
	
	InXSelectObjectsTool = true,
	
	Title = "Stick to terrain/collision (F)",
	Description = false,
	ActionSortKey = "5",
	ActionIcon = "CommonAssets/UI/Editor/Tools/StickToTerrain.tga",
	ActionShortcut = "F",
	UndoOpName = "Stuck %d object(s) to collision",
	
	init_drag_position = false,
	init_move_positions = false,
}
---
--- Moves the given objects to the terrain/collision closest to the current cursor position.
--- The objects are moved and rotated to align with the collision normal at the closest point.
---
--- @param mouse_pos table The current mouse cursor position.
--- @param objects table The objects to move and align.
---
function XStickToCollisionHelper:MoveObjects(mouse_pos, objects)
end

function XStickToCollisionHelper:MoveObjects(mouse_pos, objects)
	local vMove = GetTerrainCursor() - self.init_drag_position:SetZ(0)
	for i, obj in ipairs(objects) do
		local pos = (self.init_move_positions[i] + vMove):SetZ(0)
		local offset = (self.init_move_positions[i] - self.init_move_positions[1]):SetZ(0)
		local eye, cursor = camera.GetEye(), GetTerrainCursor()
		local o, closest, normal = IntersectSegmentWithClosestObj(eye + offset, cursor + offset)
		if closest and normal and o ~= obj then
			obj:SetPos(closest + normal / 4096)
			local rotAxis, rotAngle = GetAxisAngle(normal, self.init_orientations[i][1])
			rotAxis = Normalize(rotAxis)
			obj:SetAxisAngle(ComposeRotation(self.init_orientations[i][1], self.init_orientations[i][2], rotAxis, rotAngle))
		else
			CollisionAdjustObject(obj, pos, self.init_orientations[i][2])
		end
	end
	Msg("EditorCallback", "EditorCallbackMove", objects)
end
