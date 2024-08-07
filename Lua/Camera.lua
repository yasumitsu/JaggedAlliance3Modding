MapVar("g_SnapCameraEnabled", true)

local lCameraCollisionMask = const.cmCameraMask | const.cmTerrain
local lCameraCollisionQueryFlags = const.cqfSingleResult | const.cqfSorted

-- Returns the camera pos and lookat snapped to any collisions and rotated to avoid
-- the original ptCameraLookAt from being offscreen once the camera clamps to the terrain
---
--- Returns the camera position and look-at point snapped to any collisions and rotated to avoid the original `ptCameraLookAt` from being offscreen once the camera clamps to the terrain.
---
--- @param pos table|nil The position to use as the camera look-at point. If not provided, the current camera position and look-at point are used.
--- @param floor boolean|nil Whether to return the floor position under the camera look-at point.
--- @return table, table, boolean The snapped camera position, the snapped camera look-at point, and the floor position (if requested).
---
function GetCameraSnapToObjectParams(pos, floor)
	local ptCamera, ptCameraLookAt = cameraTac.GetPosLookAtEnd()
	if not pos then return ptCamera, ptCameraLookAt end
	pos = not pos:IsValidZ() and pos:SetTerrainZ() or pos
	
	-- Used for restoring when camera messes up.
	ptLastCameraPos, ptLastCameraLookAt = ptCamera, ptCameraLookAt

	local cameraVector = ptCameraLookAt - ptCamera
	ptCamera = pos - cameraVector
	ptCameraLookAt = pos

	-- Snap camera to camera collisions between pos and lookat.
	-- This matters when the collision is low, like in the underground mines.
	local first = true
	collision.Collide(ptCamera, ptCameraLookAt - ptCamera, lCameraCollisionQueryFlags, 0, lCameraCollisionMask,
		function(o, _, hitX, hitY, hitZ)
			if not first then return end
			first = false
			ptCameraLookAt = point(hitX, hitY, hitZ)
			ptCamera = ptCameraLookAt - cameraVector
	end)
	
	return ptCamera, ptCameraLookAt, floor or GetFloorOfPos(pos:xyz())
end

--Similar to GetCameraSnapToObjectParams, but it is only used for determining camera pos/lookat (with zoom taken into account) for DoPointsFitScreen
---
--- Returns the camera position and look-at point snapped to any collisions and rotated to avoid the original `ptCameraLookAt` from being offscreen once the camera clamps to the terrain.
---
--- @param pos table|nil The position to use as the camera look-at point. If not provided, the current camera position and look-at point are used.
--- @return table, table The snapped camera position and the snapped camera look-at point.
---
function GetCameraPosLookAtOnPos(pos)
	local ptCamera, ptCameraLookAt = cameraTac.GetZoomedPosLookAtEnd()
	if not pos then return ptCamera, ptCameraLookAt end
	pos = not pos:IsValidZ() and pos:SetTerrainZ() or pos

	local cameraVector = ptCameraLookAt - ptCamera
	ptCamera = pos - cameraVector
	ptCameraLookAt = pos

	-- Snap camera to camera collisions between pos and lookat.
	-- This matters when the collision is low, like in the underground mines.
	local first = true
	collision.Collide(ptCamera, ptCameraLookAt - ptCamera, lCameraCollisionQueryFlags, 0, lCameraCollisionMask,
		function(o, _, hitX, hitY, hitZ)
			if not first then return end
			first = false
			ptCameraLookAt = point(hitX, hitY, hitZ)
			ptCamera = ptCameraLookAt - cameraVector
	end)
	
	return ptCamera, ptCameraLookAt
end

SnapCameraToObjInterpolationTimeDefault = 1000
---
--- Snaps the camera to the specified object or position, optionally with a floor and interpolation time.
---
--- @param obj table|point The object or position to snap the camera to.
--- @param force boolean|string Whether to force the camera snap, or use "player-input" to avoid snapping if the player is already moving the camera.
--- @param floor table|nil The floor to snap the camera to, if not provided it will be calculated.
--- @param time number|nil The interpolation time in milliseconds, defaults to SnapCameraToObjInterpolationTimeDefault.
--- @param easingType string|nil The easing type to use for the interpolation, defaults to hr.CameraTacPosEasing.
--- @return number, table, table The actual interpolation time used, the snapped camera position, and the snapped camera look-at point.
---
function SnapCameraToObj(obj, force, floor, time, easingType)
	if not g_SnapCameraEnabled then return end
	if not cameraTac.IsActive() then return end
	
	-- Dont snap the camera if requested by player input, and
	-- other player input is already moving the camera. (217661)
	if force == "player-input" then
		force = false
		if cameraTac.IsInputMovingCamera() then
			return
		end
	end
	
	local pos = IsValid(obj) and obj:GetPos() or obj
	if IsPoint(pos) and ((not IsCameraLocked() and not gv_Deployment) or force) then
		assert(not CurrentActionCamera)
		local ptCamera, ptCameraLookAt, floor = GetCameraSnapToObjectParams(pos, floor)
		local easing
		if easingType and easingType ~= "none" then
			easing = GetEasingIndex(easingType)
		else
			easing = hr.CameraTacPosEasing
		end
		time = time or SnapCameraToObjInterpolationTimeDefault
		cameraTac.SetPosLookAtAndFloor(ptCamera, ptCameraLookAt, floor, time, easing)
		return time, ptCamera, ptCameraLookAt
	end
	return 0
end

---
--- Snaps the camera to the specified object's floor, optionally forcing the snap.
---
--- @param obj table The object to snap the camera to.
--- @param force boolean Whether to force the camera snap.
---
function SnapCameraToObjFloor(obj, force)
	if not g_SnapCameraEnabled or cameraTac.GetIsInOverview() then return end
	if not cameraTac.IsActive() then return end
	if IsValid(obj) and (not IsCameraLocked() or force) then 
		local floor = GetFloorOfPos(obj:GetPosXYZ())
		cameraTac.SetFloor(floor, hr.CameraTacInterpolatedMovementTime * 10, hr.CameraTacInterpolatedVerticalMovementTime * 10)
	end
end

---
--- Checks if the given target is within the screen bounds, accounting for a padding around the screen edges.
---
--- @param self table The object instance calling this function.
--- @param target table|vec3 The target object or position to check.
--- @return boolean True if the target is within the screen bounds with padding, false otherwise.
---
function DoesTargetFitOnScreen(self, target)
	if GetUIStyleGamepad() then return false end
	
	local paddingX, paddingY = const.Camera.CrosshairPaddingX, const.Camera.CrosshairPaddingY
	
	local _, sx, sy = GameToScreenXY(target)
	local crosshair_dimX, crosshair_dimY = ScaleXY(self.scale, paddingX, paddingY)
	if sx - crosshair_dimX/2 < 0 or sy - crosshair_dimY/2 < 0 then
		return false
	end
	local screen_size = UIL.GetScreenSize()
	if sx + crosshair_dimX/2 >= screen_size:x() or sy + crosshair_dimY/2 >= screen_size:y() then
		return false
	end
	return true
end

---
--- Checks if the given target is within the screen bounds.
---
--- @param target table|vec3 The target object or position to check.
--- @return boolean True if the target is within the screen bounds, false otherwise.
---
function IsOnScreen(target)
	local screen_width, screen_height = UIL.GetScreenSize():xy()
	local front, screen_x, screen_y = GameToScreenXY(target)
	return front and screen_x > 0 and screen_y > 0 and screen_x < screen_width and screen_y < screen_height
end

---
--- Sets the camera position and orientation to match the specified unit's entrance marker.
---
--- @param unit table The unit to set the camera to.
--- @param time number (optional) The time in seconds to interpolate the camera movement.
---
function CameraPositionFromUnitOrientation(unit, time)
	local ptCamera, ptCameraLookAt = GetCamera()
	local cameraVector = ptCameraLookAt - ptCamera
	if unit.entrance_marker then
		local pos = unit.entrance_marker:GetPos()
		if not pos:IsValidZ() then
			pos = pos:SetTerrainZ()
		end
		local axis, marker_orient = unit.entrance_marker:GetOrientation()
		local cam_orient = CalcOrientation(ptCamera, ptCameraLookAt)
		local cameraVector = RotateAxis(cameraVector, axis, marker_orient - cam_orient)
		ptCamera = pos - cameraVector
		ptCameraLookAt = pos
		local floor = GetFloorOfPos(pos:xyz())
		cameraTac.SetPosLookAtAndFloor(ptCamera, ptCameraLookAt, floor, time or 1)
	elseif time then -- use interpolation
		local ptCamera, ptCameraLookAt = GetCamera()
		if not ptCamera then
			return
		end
		local pos = unit:GetPos()
		if not pos:IsValidZ() then
			pos = pos:SetTerrainZ()
		end
		ptCamera = pos - cameraVector
		ptCameraLookAt = pos
		local floor = GetFloorOfPos(ptCameraLookAt:xyz())
		cameraTac.SetPosLookAtAndFloor(ptCamera, ptCameraLookAt, floor, time or 1)
	else
		ViewPos(unit:GetPos())
		cameraTac.Rotate(-mapdata.MapOrientation * 60)
	end
end

local max_trans_len = 15*guim
---
--- Handles the camera target when it is fixed.
---
--- @param src table|vec3 The source object or position.
--- @param tar table|vec3 The target object or position.
---
function HandleCameraTargetFixed(src, tar)
	if not cameraTac.GetForceMaxZoom() or src == tar then return end
	local t_pos = IsPoint(tar) and tar or tar:GetPos()
	t_pos = not t_pos:IsValidZ() and t_pos:SetTerrainZ() or t_pos
	local front, t_pos_sc = GameToScreen(t_pos)
	local shrink = 300
	local box = g_DesktopBox:grow(shrink, shrink, -shrink, -shrink)
	if t_pos_sc:InBox(box) then return end
	local ptCamera, ptCameraLookAt = GetCamera()
	local s_pos = src:GetPos()
	local trans_vector_tar = t_pos:SetZ(0) - s_pos:SetZ(0)
	local len = s_pos:Dist2D(t_pos)/2
	len = len > max_trans_len and max_trans_len or len
	trans_vector_tar = SetLen(trans_vector_tar, len)
	local trans_vector_src = s_pos:SetZ(0) - ptCameraLookAt:SetZ(0)
	local trans_vector = trans_vector_src + trans_vector_tar
	cameraTac.SetCamera(ptCamera + trans_vector , ptCameraLookAt + trans_vector, 500, "Sin out")
end

---
--- Resets the tactical camera to its default state.
---
--- This function rotates the camera to match the map orientation, and sets the camera position and look-at point based on the selected object's position. If no object is selected, it simply rotates the camera to match the map orientation.
---
--- @param none
--- @return none
---
function ResetTacticalCamera()
	local mapOrient = (mapdata.MapOrientation - 90) * 60
	local ptCamera, ptCameraLookAt = GetCamera()
	local cameraVector = ptCameraLookAt - ptCamera
	local cam_orient = CalcOrientation(ptCamera, ptCameraLookAt)
	if SelectedObj then
		local pos = SelectedObj:GetPos():SetTerrainZ()
		local cameraVector = RotateAxis(cameraVector, axis_z, mapOrient - cam_orient)
		ptCamera = pos - cameraVector
		ptCameraLookAt = pos
		cameraTac.SetCamera(ptCamera, ptCameraLookAt)
	else
		cameraTac.Rotate(cam_orient - mapOrient)
	end
	cameraTac.SetFloor(0)
end

----
-- Camera changing floor when unit does
----

MapVar("floorFollowData", false)

local function lClearFollowRecord()
	floorFollowData = false
end

OnMsg.ChangeMapDone = lClearFollowRecord
OnMsg.SelectedObjChange = lClearFollowRecord
OnMsg.TacCamFloorChanged = lClearFollowRecord

local function lFloorFollowRecord(unit)
	if not table.find(Selection, unit) then return end
	local currentFloor = cameraTac.GetFloor()
	local movementStartFloor = GetFloorOfPos(unit:GetPosXYZ())
	if movementStartFloor ~= currentFloor then return end
	floorFollowData = {
		unit = unit
	}
end

OnMsg.UnitMovementStart = lFloorFollowRecord -- combat
OnMsg.UnitGoToStart = lFloorFollowRecord -- exploration

local function lFloorFollowCheckAndApply(unit)
	if not floorFollowData then return end
	if floorFollowData.unit ~= unit then return end
	SnapCameraToObjFloor(unit)
	lClearFollowRecord()
end

OnMsg.UnitMovementDone = lFloorFollowCheckAndApply
OnMsg.UnitGoTo = lFloorFollowCheckAndApply

--overwrite func to do SetAutoFovX
---
--- Sets the camera's field of view (FOV) to the specified value.
---
--- @param fovX number The new horizontal field of view angle in degrees.
---
function SetCameraFov(fovX)
	SetAutoFovX()
end