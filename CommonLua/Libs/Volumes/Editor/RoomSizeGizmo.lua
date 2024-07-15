local voxelSizeX = const.SlabSizeX or 0
local voxelSizeY = const.SlabSizeY or 0
local voxelSizeZ = const.SlabSizeZ or 0
local halfVoxelSizeX = voxelSizeX / 2
local halfVoxelSizeY = voxelSizeY / 2
local halfVoxelSizeZ = voxelSizeZ / 2
local InvalidZ = const.InvalidZ

DefineClass.RoomSizeGizmo = {
	__parents = { "XEditorGizmo", "MoveGizmoTool" },
	
	HasLocalCSSetting = false,
	HasSnapSetting = false,
	
	Title = "Room size gizmo (Ctrl+\\)",
	Description = false,
	ActionSortKey = "9",
	ActionIcon = "CommonAssets/UI/Editor/Tools/RoomResize.tga",
	ActionShortcut = "Ctrl-\\",
	UndoOpName = "Resized room(s)",
	
	r_color = RGB(255, 200, 0),
	g_color = RGB(0, 255, 200),
	b_color = RGB(200, 0, 255),
	
	room = false,
	sw = false,
}

local saveMapBlock = false
function OnMsg.PreSaveMap()
	saveMapBlock = true
end

function OnMsg.PostSaveMap()
	saveMapBlock = false
end

---
--- Checks if the room size gizmo can start an operation based on the given cursor position.
---
--- @param pt point The cursor position.
--- @return boolean True if the room size gizmo can start an operation, false otherwise.
---
function RoomSizeGizmo:CheckStartOperation(pt)
	return GetSelectedRoom() and self:IntersectRay(camera.GetEye(), ScreenToGame(pt))
end

---
--- Gets the position of a room's box edge based on the specified side.
---
--- @param r table The room object.
--- @param side string The side of the room box to get the position for ("South", "North", "West", "East").
--- @return point The position of the specified room box edge.
---
function RoomSizeGizmo:PosFromSide(r, side)
	local b = r.box
	if side == "South" then
		return b:max()
	elseif side == "North" then
		return b:min():SetZ(b:max():z())
	elseif side == "West" then
		return b:max() - point(b:sizex(), 0, 0)
	else --east
		return b:max() - point(0, b:sizey(), 0)
	end
end

---
--- Renders the room size gizmo.
---
--- If the map is being saved, the gizmo will not be rendered.
---
--- If a room is selected, the gizmo will be positioned and oriented based on the selected room's dimensions and the selected wall.
---
--- If no room is selected, the gizmo will not be rendered.
---
--- @return nil
---
function RoomSizeGizmo:Render()
	if saveMapBlock then return end
	
	local obj = not XEditorIsContextMenuOpen() and GetSelectedRoom()
	if obj then		
		self.v_axis_x = axis_x
		self.v_axis_y = axis_y
		self.v_axis_z = axis_z
		self:SetOrientation(axis_z, 0)
		
		if not self.operation_started then
			local sw = obj.selected_wall or "South"
			self:SetPos(self:PosFromSide(obj, sw))
		end
		
		self:ChangeScale()
		self:SetMesh(self:RenderGizmo())
	else 
		self:SetMesh(pstr("")) 
	end
end

---
--- Starts the room size gizmo operation.
---
--- This function is called when the user starts interacting with the room size gizmo.
--- It initializes the necessary state for the gizmo operation, such as the initial cursor position,
--- the initial gizmo position, the selected room, and the selected wall.
---
--- @param pt point The initial cursor position.
--- @return nil
---
function RoomSizeGizmo:StartOperation(pt)
	if saveMapBlock then return end
	
	self.initial_positions = {}
	self.initial_pos = self:CursorIntersection(pt)
	self.initial_gizmo_pos = self:GetVisualPos()
	self.room = GetSelectedRoom()
	self.sw = self.room.selected_wall or "South"
	self.operation_started = true
end

---
--- Performs the room size gizmo operation.
---
--- This function is called when the user interacts with the room size gizmo. It calculates the new room size based on the cursor intersection and updates the room's size accordingly, taking into account any collisions with other rooms.
---
--- @param pt point The current cursor position.
--- @return nil
---
function RoomSizeGizmo:PerformOperation(pt)
	local intersection = self:CursorIntersection(pt)
	if intersection then
		local vMove = intersection - self.initial_pos
		local newPos = self.initial_gizmo_pos + vMove
		local room = self.room
		local sw = self.sw
		self:SetPos(newPos)
		local boxEdge = self:PosFromSide(room, sw)
		local delta = newPos - boxEdge
		local x, y, z = delta:xyz()
		--this resizes when gizmo hits voxel cell mid
		--delta = point((x + halfVoxelSizeX) / voxelSizeX, (y + halfVoxelSizeY) / voxelSizeY, (z + halfVoxelSizeZ) / voxelSizeZ)
		--this resizes when gizmo hits voxel cell edge
		delta = point(sign(x) * (abs(x) / voxelSizeX), sign(y) * (abs(y) / voxelSizeY), sign(z) * (abs(z) / voxelSizeZ))
		if delta ~= point30 then
			x, y, z = delta:xyz()
			local move
			if sw == "East" then
				move = point(0, y * voxelSizeY, 0)
				delta = point(x, y * -1, z)
			elseif sw == "West" then
				move = point(x * voxelSizeX, 0, 0)
				delta = point(x * -1, y, z)
			elseif sw == "North" then
				move = point(x * voxelSizeX, y * voxelSizeY, 0)
				delta = point(x * -1, y * -1, z)
			else --south
				move = point30
			end
			local oldSize = room.size
			local newSize = oldSize + delta

			if newSize:x() > 0 and newSize:y() > 0 and newSize:z() >= 0 then --else unhandled behaviour
				if VolumeCollisonEnabled and room.enable_collision then
					local b = room.box
					local mix, miy, miz = b:min():xyz()
					local max, may, maz = b:max():xyz()
					local mvx, mvy, mvz = move:xyz()
					local dx, dy, dz = delta:xyz()
					
					local testBox = box(mix + mvx, miy + mvy, miz, max + dx * voxelSizeX + mvx, may + dy * voxelSizeY + mvy, maz + dz * voxelSizeZ)
					if room:CheckCollision(nil, testBox) then
						print("Failed to resize room due to collision with other room!")
						return
					end
				end
				
				local c = room.enable_collision
				room.enable_collision = false --skip col checks, we already did them
				if move ~= point30 then
					moveHelperHelper(room, move)
				end
				room.size = oldSize + delta
				SizeSetterHelper(room, oldSize)
				room.enable_collision = c
			else
				print("Room can't shrink below x:1, y:1, z:0 size!")
			end
		end
	end
end

---
--- Ends the operation of the RoomSizeGizmo.
--- Calls the `EndOperation` method of the `MoveGizmo` class.
--- Sets the `room` and `sw` properties of the RoomSizeGizmo to `false`.
---
function RoomSizeGizmo:EndOperation()
	MoveGizmo.EndOperation(self)
	self.room = false
	self.sw = false
end