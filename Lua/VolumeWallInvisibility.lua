local voxelSizeX = const.SlabSizeX or 0
local voxelSizeY = const.SlabSizeY or 0
local voxelSizeZ = const.SlabSizeZ or 0
local halfVoxelSizeX = voxelSizeX / 2
local halfVoxelSizeY = voxelSizeY / 2
local halfVoxelSizeZ = voxelSizeZ / 2
local InvalidZ = const.InvalidZ
local rayOffsetHorizontal = voxelSizeX * 3
local rayOffsetVertical = voxelSizeX * 3
local boxSide = voxelSizeX * 3
local noneWallMat = "none"
local showWallDelay = 350
local hideWallDelay = 500
local hideRoomsBelowCameraFloor = false

local rayOffsetHorizontalV2 = voxelSizeX * 5
local rayOffsetVerticalV2 = voxelSizeX * 5
local CollapseWallRange = voxelSizeX * 8 --this is a v2 var, zero means ignore range, collapse all in touched bld, any other number - walls of bld will only collapse if withing this range from camera lookat 2d
local HideRoofsWhenAboveMaxFloorUpToThisMuch = 0 --how far  above the bld last floor remains open, 0 to disable, its measured against max, so a small value (1) will add 1 floor
local HitFirstFloorWhenBelowItThisMuch = voxelSizeZ * 5 --when lookat is below the first floor of a bld by up to this much, it is still considered hit
local ExtendVerticelPerFloor = voxelSizeX --adds this much to vertical collision triangle len per floor except the first

local gofContourInner = const.gofContourInner

local CMTVisibilityMode_Auto = 0
local CMTVisibilityMode_AlwaysHide = 1
local CMTVisibilityMode_NeverHide = 2

local Defaults = {
	rayOffsetVerticalV2 = rayOffsetVerticalV2,
	rayOffsetHorizontalV2 = rayOffsetHorizontalV2
}

AppendClass.MapDataPreset = { properties = {
	{ category = "Camera", id = "ExtendBuildingTouchRange", name = "Extend building touch range", editor = "bool", default = false, help = "Buildings will hide from further away on this map." },
}}

local function SetBuildingTouchRange(t)
	if t == "default" then
		rayOffsetVerticalV2 = Defaults.rayOffsetVerticalV2
		rayOffsetHorizontalV2 = Defaults.rayOffsetHorizontalV2
	elseif t == "extended" then
		rayOffsetVerticalV2 = Defaults.rayOffsetVerticalV2 * 3
		rayOffsetHorizontalV2 = Defaults.rayOffsetHorizontalV2 * 3
	else
		assert(false) --unexepected hide range
	end
end

local function VisibilityMode_LuaToC(mode)
	if mode == true then
		return CMTVisibilityMode_NeverHide
	elseif mode == false then
		return CMTVisibilityMode_AlwaysHide
	else --"auto"
		return CMTVisibilityMode_Auto
	end
end

if FirstLoad then
	WallInvisibilityThread = false
	WallInvisibilityEnabled = true
	
	const.CMT_TreeTopVisibilityMode = VisibilityMode_LuaToC("auto")
	const.CMT_CanopyTopVisibilityMode = VisibilityMode_LuaToC("auto")
	WallVisibilityMode = "auto"
	
	WallInvisibilityDebug = false
	RoofWallBoxDebug = false
	
	--PlanA config vars below:
	--default -> first pass
	--planA -> plan a
	VT2TouchedBuildings = false
	VT2CollapsedWalls = false --{[room] = {"West", "East", etc.}}
	roomsRoofsToShow = false
	--collapses only the shared part of the wall in xy and the entire wall in z.
	AllowPartialWallsCollapse = true
	
	g_DbgCRObjs = false
	g_DbgCRObjsToKill = false
	
	DbgCombatWallHiding = false
	
	g_WITPauseReasons = {}
end
--set of funcs mimicing DbgAdd funcs, but with code renderables
--- Clears the debug render objects and removes them from the scene.
--- This function is called after a delay to avoid flickering when clearing the debug objects.
function DbgCRReallyClear()
	DoneObjects(g_DbgCRObjsToKill)
	g_DbgCRObjsToKill = false
end

---
--- Clears the debug render objects and removes them from the scene.
--- This function is called after a delay to avoid flickering when clearing the debug objects.
---
function DbgCRClear()
	if not g_DbgCRObjs then return end
	DelayedCall(25, DbgCRReallyClear) --avoid seizure flicker
	g_DbgCRObjsToKill = g_DbgCRObjsToKill or {}
	table.iappend(g_DbgCRObjsToKill, g_DbgCRObjs)
	g_DbgCRObjs = false
end

---
--- Adds a vector debug render object to the scene.
---
--- @param origin vec3 The origin point of the vector.
--- @param dir vec3 The direction vector. If not provided, defaults to the Z axis with a length of 3.
--- @param color vec3 The color of the vector.
---
function DbgCRAddVector(origin, dir, color)
	dir = dir or axis_z * 3
	g_DbgCRObjs = g_DbgCRObjs or {}
	table.insert(g_DbgCRObjs, ShowVector(dir, origin, color))
end

---
--- Adds a box debug render object to the scene.
---
--- @param b table The box to render, in the format { min = vec3, max = vec3 }.
--- @param color vec3 The color of the box.
---
function DbgCRAddBox(b, color)
	g_DbgCRObjs = g_DbgCRObjs or {}
	table.insert(g_DbgCRObjs, PlaceBox(b, color))
end

local dbgTxtObj = false
---
--- Toggles the wall invisibility debug mode.
---
--- When enabled, this function will clear any existing debug render objects and toggle the `WallInvisibilityDebug` flag. If the debug mode is disabled, it will remove any existing debug text object.
---
function CheatToggleWallInvisibilityDebug()
	DbgCRClear()
	WallInvisibilityDebug = not WallInvisibilityDebug
	if not WallInvisibilityDebug then
		if IsValid(dbgTxtObj) then
			DoneObject(dbgTxtObj)
			dbgTxtObj = false
		end
	end
end

---
--- Toggles the wall invisibility debug mode outside of combat.
---
--- When enabled, this function will toggle the `DbgCombatWallHiding` flag, which is used to control the visibility of walls during combat.
---
function CheatToggleWallInvisibilityOutsideOfCombat()
	DbgCombatWallHiding = not DbgCombatWallHiding
end

local rebuildingVolumeBuildings = false
function OnMsg.BuildBuildingsData(VolumeBuildings)
	--bld data about to be rebuilt, our bld ptrs will be invalidated
	rebuildingVolumeBuildings = true
	if WallInvisibilityEnabled and ShouldStartWallInvisibilityThread() and CurrentThread() ~= WallInvisibilityThread then
		StopWallInvisibilityThread()
	end
end


function OnMsg.VolumeBuildingsRebuilt(VolumeBuildings, oldVolumeBuildings)
	rebuildingVolumeBuildings = false
	if WallInvisibilityEnabled and ShouldStartWallInvisibilityThread() and not IsEditorActive() and CurrentThread() ~= WallInvisibilityThread then
		StartWallInvisibilityThread()
	end
end

---
--- Determines whether the wall invisibility thread should be started.
---
--- This function checks if the current map has a valid slab size and map name, which are required for the wall invisibility functionality to work. It is intended to be overridden with project-specific logic.
---
--- @return boolean true if the wall invisibility thread should be started, false otherwise
---
function ShouldStartWallInvisibilityThread()
	--override with project specific stuff
	--gv_CurrentSectorId ~= false for zulu
	return (const.SlabSizeX or 0) ~= 0 and GetMapName() ~= ""
end

---
--- Starts the wall invisibility thread.
---
--- This function creates a new real-time thread that is responsible for managing the visibility of walls in the game. It resets the black plane visibility and clears any pause reasons that may have been set.
---
--- @param reason (optional) string The reason for starting the wall invisibility thread.
---
function StartWallInvisibilityThread(reason)
	g_WITPauseReasons[reason or false] = nil
	if next(g_WITPauseReasons) then return end
	
	if IsValidThread(WallInvisibilityThread) then
		return
	end
	
	WallInvisibilityThread = CreateRealTimeThread(WallInvisibilityThreadMethod)
	ResetBlackPlaneVisibility()
end

---
--- Stops all hiding of walls and resets the black plane visibility.
---
--- This function sets a pause reason, shows all rooms and walls that were previously hidden, stops the wall invisibility thread, and resets the black plane visibility.
---
--- @param reason string The reason for stopping the wall invisibility thread.
--- @param delay number (optional) The delay in seconds before showing all rooms and walls.
--- @param time number (optional) The duration in seconds for the show animation.
---
function StopAllHiding(reason, delay, time)
	CMT_SetPause(true, reason)
	C_CCMT_ShowAllAndReset(delay, time)
	StopWallInvisibilityThread(reason) --calls ResetBlackPlaneVisibility which will try to hide stuff, so after C_CCMT_ShowAllAndReset which will show everything
	blackPlanesLastVisibleFloor = false
end

---
--- Resumes all hiding of walls and starts the wall invisibility thread with checks.
---
--- This function sets the pause flag to false, removes the pause reason, and starts the wall invisibility thread with checks. It is used to resume the wall invisibility functionality after it has been paused.
---
--- @param reason string The reason for resuming the wall invisibility thread.
---
function ResumeAllHiding(reason)
	CMT_SetPause(false, reason)
	StartWallInvisibilityThreadWithChecks(reason)
end

local function ShouldProcessRoom(room)
	if room.being_placed or room.ignore_zulu_invisible_wall_logic or room.outside_border then return false end
	
	return true
end

---
--- Stops the wall invisibility thread and resets the black plane visibility.
---
--- This function sets a pause reason, shows all rooms and walls that were previously hidden, stops the wall invisibility thread, and resets the black plane visibility.
---
--- @param reason string The reason for stopping the wall invisibility thread.
---
function StopWallInvisibilityThread(reason)
	g_WITPauseReasons[reason or false] = true
	
	if VT2TouchedBuildings then
		for bld, floor in pairs(VT2TouchedBuildings) do
			local meta = VolumeBuildingsMeta[bld]
			local to = meta.maxFloor
			for f = floor + 1, to do
				ShowRoomsOnFloor(bld, f)
			end
			
			--rooms that are same floor but acutally roofs need to be processed since they are kind of on the next floor..
			local floorT = bld[floor]
			for i = 1, #(floorT or "") do
				local room = floorT[i]
				if room:IsRoofOnly() and ShouldProcessRoom(room) then
					ShowRoom(room)
				end
			end
		end
		
		for r, sides in pairs(VT2CollapsedWalls) do
			for side, some_val in pairs(sides) do
				ShowWall(r, side)
			end
		end
		
		VT2CollapsedWalls = false
		VT2TouchedBuildings = false
		CollectionsToHideProcessDelayedHides()
		CollectionsToHideProcessDelayedShows()
	end
	
	if IsValidThread(WallInvisibilityThread) then
		DeleteThread(WallInvisibilityThread)
		WallInvisibilityThread = false
	end
	
	ResetBlackPlaneVisibility()
end

---
--- Resets the wall invisibility thread by toggling the wall invisibility enabled state.
---
--- This function toggles the wall invisibility enabled state off and then back on, which effectively resets the wall invisibility thread.
---
--- @function ResetWallInvisibilityThread
--- @return nil
function ResetWallInvisibilityThread()
	ToggleWallInvisibilityEnabled()
	ToggleWallInvisibilityEnabled()
end

---
--- Toggles the wall invisibility enabled state.
---
--- When wall invisibility is enabled, this function will disable it and stop the wall invisibility thread.
--- When wall invisibility is disabled, this function will enable it and start the wall invisibility thread.
---
--- @function ToggleWallInvisibilityEnabled
--- @return nil
function ToggleWallInvisibilityEnabled()
	if WallInvisibilityEnabled then
		WallInvisibilityEnabled = false
		StopWallInvisibilityThread()
	else
		WallInvisibilityEnabled = true
		StartWallInvisibilityThread()
	end
end

function OnMsg.ChangeMap()
	StopWallInvisibilityThread()
end

function OnMsg.SetObjectDetail(stage, params)
	if stage == "init" then
		params.wall_thread = not not WallInvisibilityThread
		if params.wall_thread then
			StopWallInvisibilityThread()
		end
	elseif stage == "done" then
		if params.wall_thread then
			StartWallInvisibilityThread()
		end
	end
end

---
--- Starts the wall invisibility thread if it is enabled and the conditions to start it are met.
---
--- This function checks if the wall invisibility is enabled and if the conditions to start the wall invisibility thread are met. If both conditions are true, it calls the `StartWallInvisibilityThread` function to start the thread.
---
--- @param reason string (optional) The reason for starting the wall invisibility thread.
--- @return nil
function StartWallInvisibilityThreadWithChecks(reason)
	if WallInvisibilityEnabled and ShouldStartWallInvisibilityThread() then
		StartWallInvisibilityThread(reason)
	end
end

function OnMsg.NewMapLoaded()
	StartWallInvisibilityThreadWithChecks()
end

function OnMsg.GameEnteringEditor()
	StopWallInvisibilityThread()
end

function OnMsg.GameExitEditor()
	if WallInvisibilityEnabled and ShouldStartWallInvisibilityThread() and not rebuildingVolumeBuildings then
		StartWallInvisibilityThread()
	end
end

---
--- Gets the floor of a unit at the given position.
---
--- If the position is on a walkable slab, the floor of that slab is returned. Otherwise, the camera floor is calculated and returned.
---
--- @param posx number The x coordinate of the position.
--- @param posy number The y coordinate of the position.
--- @param posz number The z coordinate of the position.
--- @return number The floor of the unit at the given position.
function GetUnitFloor(posx, posy, posz)
	local tile, z = WalkableSlabByPoint(posx, posy, posz)
	return IsKindOf(tile, "Slab") and tile.room and tile.floor or WallInvisibilityGetCamFloor(posx, posy, posz, z)
end

---
--- Gets the floor of a slab.
---
--- If the slab is a valid slab with a room and floor, the slab's floor is returned. Otherwise, the camera floor is calculated and returned.
---
--- @param slab Slab The slab to get the floor of.
--- @return number The floor of the slab.
function C_GetSlabFloor(slab)
	return IsKindOf(slab, "Slab") and slab.room and slab.floor or WallInvisibilityGetCamFloor(slab:GetPosXYZ())
end

---
--- Gets the camera floor at the given position.
---
--- The camera floor is calculated by subtracting the terrain height from the position's z-coordinate, and then dividing the result by the camera tactical floor height. The result is rounded up to the nearest integer.
---
--- @param posx number The x coordinate of the position.
--- @param posy number The y coordinate of the position.
--- @param posz number The z coordinate of the position.
--- @param terrainZ number (optional) The terrain height at the given position.
--- @return number The camera floor at the given position.
function WallInvisibilityGetCamFloor(posx, posy, posz, terrainZ)
	local h = posz and posz - (terrainZ or terrain.GetHeight(posx, posy)) or 0
	return h > 0 and h / hr.CameraTacFloorHeight + 1 or 1
end

---
--- Gets the camera floor at the given position, rounded to the nearest integer.
---
--- The camera floor is calculated by subtracting the terrain height from the position's z-coordinate, and then dividing the result by the camera tactical floor height. The result is rounded up to the nearest integer.
---
--- @param posx number The x coordinate of the position.
--- @param posy number The y coordinate of the position.
--- @param posz number The z coordinate of the position.
--- @param terrainZ number (optional) The terrain height at the given position.
--- @return number The camera floor at the given position, rounded to the nearest integer.
function WallInvisibilityGetCamFloorRounded(posx, posy, posz, terrainZ)
	local h = posz and posz - (terrainZ or terrain.GetHeight(posx, posy)) or 0
	return h > 0 and DivRound(h, hr.CameraTacFloorHeight) + 1 or 1
end

---
--- Gets the floor of an object or position.
---
--- If the input is a position, the floor is calculated using `GetFloorOfPos`. If the input is an object, the floor is calculated using the object's visual position.
---
--- @param obj_or_pos Object|Point The object or position to get the floor of.
--- @return number The floor of the object or position.
function GetStepFloor(obj_or_pos)
	if not obj_or_pos then
		return 0
	end
	local x, y, z = SnapToPassSlabXYZ(obj_or_pos)
	if x then
		return GetFloorOfPos(x, y, z)
	end
	if IsPoint(obj_or_pos) then
		return GetFloorOfPos(obj_or_pos:xyz()) or 0
	end
	return GetFloorOfPos(obj_or_pos:GetVisualPosXYZ())
end

---
--- Gets the floor of a position.
---
--- The floor is calculated by finding the nearest walkable slab at the given position, and then using the floor value of that slab. If the slab is a RoofPlaneSlab, the floor value is returned as-is. If the slab is a regular Slab, the floor value is decremented by 1 to match the camera floor convention. If no slab is found, the floor is calculated using the WallInvisibilityGetCamFloor function.
---
--- @param posx number The x coordinate of the position.
--- @param posy number The y coordinate of the position.
--- @param posz number The z coordinate of the position.
--- @return number The floor of the position.
function GetFloorOfPos(posx, posy, posz)
	if not posz then
		return 0
	end
	local tile, step_z = WalkableSlabByPoint(posx, posy, posz, true)
	--camera floor is zero based and tile floor is not, thats why there is -1 everywhere;
	if tile then
		if IsKindOf(tile, "RoofPlaneSlab") and tile.floor then
			local room = tile.room
			if room and room.ignore_zulu_invisible_wall_logic and not room:IsRoofOnly() then
				return Max(0, tile.floor - 1) --this is a hack for 0172933
			end
			return tile.floor --roof floor should be +1 because cam needs to be above roof floor in order for it to be visible;
		end
		if IsKindOf(tile, "Slab") and tile.floor then
			local room = tile.room
			if room then
				if room:IsRoofOnly() then
					return Max(0, tile.floor) --if its the floor tile of a roof room treat as roof;
				else
					return Max(0, tile.floor - 1)
				end
			end
			-- If not inside a room, check for terrain level
			local terrainZ = terrain.GetHeight(posx, posy)
			if abs(terrainZ - step_z) > guim then --if tile is very close to ground lvl assume its ground floor (0)
				return Max(0, tile.floor - 1)
			end
			return 0
		end
	end
	-- assume its a walkable obj without floor member, measure floor from ground
	local floor = WallInvisibilityGetCamFloor(posx, posy, posz)
	return Max(0, floor - 1)
end

DefineClass.HideTop = {
	__parents = {"CObject"},
	Top = false,
}

---
--- Sets the shadow only flag for the HideTop object or its Top component.
---
--- If the HideTop object has the `gofOnRoof` game flag set, the `SetShadowOnly` method of the `CObject` class is called directly on the HideTop object.
---
--- If the HideTop object has a `Top` component, the `SetShadowOnly` method is called on the `Top` component instead.
---
--- @param bSet boolean Whether to set the shadow only flag or not.
---
function HideTop:SetShadowOnly(bSet)
	if self:GetGameFlags(const.gofOnRoof) ~= 0 then
		CObject.SetShadowOnly(self, bSet)
	else
		local top = self.Top
		if top then
			top:SetShadowOnly(bSet)
		end
	end
end

---
--- Returns the height of the top component of the HideTop object.
---
--- The height is calculated by getting the position of the HideTop object, using the terrain height if the z-coordinate is not set, and then adding the maximum z-coordinate of the Top component's bounding box.
---
--- @return number The height of the top component of the HideTop object.
---
function HideTop:GetTopHeight()
	local x, y, z = self:GetPosXYZ()
	z = z or terrain.GetHeight(self)
	return z + self.Top:GetEntityBBox():maxz()
end

local const_gofOnRoof = const.gofOnRoof

---
--- Determines whether the top component of the HideTop object should be hidden based on the camera position, look-at point, and hiding point.
---
--- If the `Top` component of the HideTop object is not set, this function returns immediately.
---
--- If the `camera_pos` and `lookAt` parameters are not provided, they are obtained from the `cameraTac.GetZoomedPosLookAt()` function, and the `hiding_pt` parameter is calculated as the midpoint between the camera position and look-at point.
---
--- The function checks whether the distance between the hiding point and the HideTop object is less than the `hide_radius` property, and whether the difference between the camera position's z-coordinate and the top component's height is less than the `hide_height` property. If both conditions are true, the function returns `true`, indicating that the top component should be hidden.
---
--- @param camera_pos vec3 The position of the camera
--- @param lookAt vec3 The point the camera is looking at
--- @param hiding_pt vec3 The point used to determine if the top component should be hidden
--- @return boolean Whether the top component should be hidden
---
function HideTop:TopHidingCondition(camera_pos, lookAt, hiding_pt)
	if not self.Top then return end
	if not camera_pos then
		camera_pos, lookAt = cameraTac.GetZoomedPosLookAt()
		hiding_pt = camera_pos + (lookAt - camera_pos)/2
	end
	return (self:GetDist2D(hiding_pt) < self.hide_radius) and 
		(camera_pos:z() - self:GetTopHeight() < self.hide_height)
end

---
--- Handles the CMT (Camera Managed Terrain) trigger for the HideTop object.
---
--- This function sets the shadow-only property of the HideTop object based on the result of the TopHidingCondition function. If the top component of the HideTop object should be hidden, the shadow-only property is set to true, otherwise it is set to false.
---
--- @param camera_pos vec3 The position of the camera
--- @param lookAt vec3 The point the camera is looking at
--- @param hiding_pt vec3 The point used to determine if the top component should be hidden
---
function HideTop:HandleCMTTrigger(camera_pos, lookAt, hiding_pt)
	self:SetShadowOnly(self:TopHidingCondition(camera_pos, lookAt, hiding_pt))
end

DefineClass.HideTopTree = {
	__parents = {"HideTop", "TreeTop"},

	hide_height = const.CMT_HideTreesCameraZDiff,
	hide_radius = const.CMT_HideTreeTopsCameraLookAt2DRadius,
}

---
--- Determines whether the top component of the HideTopTree object should be hidden based on the camera position, look-at point, and hiding point.
---
--- If the `CMT_TreeTopVisibilityMode` constant is set to `CMTVisibilityMode_NeverHide`, this function always returns `false`, indicating that the top component should never be hidden.
---
--- If the `CMT_TreeTopVisibilityMode` constant is set to `CMTVisibilityMode_AlwaysHide`, this function always returns `true`, indicating that the top component should always be hidden.
---
--- Otherwise, this function calls the `TopHidingCondition` function of the parent `HideTop` class to determine whether the top component should be hidden based on the camera position, look-at point, and hiding point.
---
--- @param camera_pos vec3 The position of the camera
--- @param lookAt vec3 The point the camera is looking at
--- @param hiding_pt vec3 The point used to determine if the top component should be hidden
--- @return boolean Whether the top component should be hidden
---
function HideTopTree:TopHidingCondition(...)
	if const.CMT_TreeTopVisibilityMode == CMTVisibilityMode_NeverHide then
		return false
	end
	if const.CMT_TreeTopVisibilityMode == CMTVisibilityMode_AlwaysHide then
		return true
	end
	return HideTop.TopHidingCondition(self, ...)
end

DefineClass.HideTopCanopy = {
	__parents = {"HideTop"},
	hide_height = const.CMT_HideCanopiesCameraZDiff,
	hide_radius = const.CMT_HideCanopyTopsCameraLookAt2DRadius,
}

---
--- Determines whether the top component of the HideTopCanopy object should be hidden based on the camera position, look-at point, and hiding point.
---
--- If the `CMT_CanopyTopVisibilityMode` constant is set to `CMTVisibilityMode_NeverHide`, this function always returns `false`, indicating that the top component should never be hidden.
---
--- If the `CMT_CanopyTopVisibilityMode` constant is set to `CMTVisibilityMode_AlwaysHide`, this function always returns `true`, indicating that the top component should always be hidden.
---
--- Otherwise, this function checks if the selected object is within a certain distance of the canopy top, and if so, returns `true` to hide the canopy top. Otherwise, it calls the `TopHidingCondition` function of the parent `HideTop` class to determine whether the top component should be hidden based on the camera position, look-at point, and hiding point.
---
--- @param camera_pos vec3 The position of the camera
--- @param lookAt vec3 The point the camera is looking at
--- @param hiding_pt vec3 The point used to determine if the top component should be hidden
--- @return boolean Whether the top component should be hidden
---
function HideTopCanopy:TopHidingCondition(camera_pos, lookAt, hiding_pt)
	if not self.Top then return end
	if not camera_pos then
		camera_pos, lookAt = cameraTac.GetZoomedPosLookAt()
		hiding_pt = camera_pos + (lookAt - camera_pos)/2
	end
	if const.CMT_CanopyTopVisibilityMode == CMTVisibilityMode_NeverHide then
		return false
	end
	if const.CMT_CanopyTopVisibilityMode == CMTVisibilityMode_AlwaysHide then
		return true
	end
	if SelectedObj then
		local selo_pos = ValidateZ(SelectedObj:GetPos())
		local canopy_pos = self:GetPos():SetZ(self:GetTopHeight())
		local dist = DistSegmentToPt(selo_pos, camera_pos, canopy_pos)
		if dist < const.CMT_CanopyCamFocusObjDist and dist <= (selo_pos - canopy_pos):Len() then
			return true
		end
	end
	return HideTop.TopHidingCondition(self, camera_pos, lookAt, hiding_pt)
end

---
--- Sets the visibility mode for all collections that are hidden from the camera.
---
--- @param mode string The visibility mode, one of "NeverHide", "AlwaysHide", or "HideWhenCameraFar".
---
function ShowAllHideFromCameraCollections(mode)
	const.CMT_CollectionVisibilityMode = VisibilityMode_LuaToC(mode)
end

---
--- Sets the visibility mode for all tree tops that are hidden from the camera.
---
--- @param mode string The visibility mode, one of "NeverHide", "AlwaysHide", or "HideWhenCameraFar".
---
function ShowAllTreeTops(mode)
	const.CMT_TreeTopVisibilityMode = VisibilityMode_LuaToC(mode)
end

---
--- Sets the visibility mode for all tree tops that are hidden from the camera.
---
--- @param mode string The visibility mode, one of "NeverHide", "AlwaysHide", or "HideWhenCameraFar".
---
function ShowAllCanopyTops(mode)
	const.CMT_CanopyTopVisibilityMode = VisibilityMode_LuaToC(mode)
end

---
--- Clears the specified keys from a table.
---
--- @param t table The table to clear keys from.
--- @param ... string The keys to clear from the table.
---
function table.kv_clear(t, ...)
	local count = select('#', ...)
	for i = count, 1, -1 do
		local idxed = false
		for j = 1, i - 1 do
			idxed = (idxed or t)[select(j, ...)]
		end
		if i == 1 then
			idxed = t
		end
		if not idxed then
			return
		end
		
		local k = select(i, ...)
		if i == count then
			idxed[k] = nil
		else
			if not next(idxed[k]) then
				idxed[k] = nil
			end
		end
	end
end

local function RefreshCombatPath()
	--recalc soldier path when stuff gets shown in front of the mouse
	if not SelectedObj then return end
	local d = GetDialog("IModeCombatMovement")
	if d then
		d:OnMousePos(terminal.GetMousePos())
	end
end

local cornerSideToWallSides = {
	East = { "East", "North" },
	South = { "East", "South" },
	West = { "West", "South" },
	North = { "West", "North" },
}

local function visibleWallTest(o)
	return o.isVisible or o.wall_obj
end

local function ProcessCorners(corners, hide, shouldProcess, clear_countour, ...)
	local last
	clear_countour = hide and clear_countour
	local edit = IsEditorActive()
	for i = 1, #corners do
		local c = corners[i]
		if IsValid(c) then
			--this refreshes state of visible corners on top of invisible corners when adjacent wall that is not from the same room gets a visibility update, but its corners are not the top ones
			c = not c.isVisible and MapGetFirst(c, 0, "RoomCorner", function(o, c) return o.isPlug == c.isPlug and o.isVisible end, c) or c
			if c and c.isVisible then
				local process = not shouldProcess or shouldProcess(c, ...)
				if process == "break" then
					return
				elseif process then
					if c.isPlug and last then	
						local lv = CMT_IsObjVisible(last)
						c:SetShadowOnly(not lv)
						if clear_countour then
							c:ClearHierarchyGameFlags(gofContourInner)
						end
					elseif c.isPlug then
						c:SetShadowOnly(hide)
						if clear_countour then
							c:ClearHierarchyGameFlags(gofContourInner)
						end
					else			
						local x, y, z = c:GetPosXYZ()
						local a = c:GetAngle() / 60
						local w1, w2
						if not edit then
							w1 = rawget(c, "nbr1") --10-20ms faster with caching
							w2 = rawget(c, "nbr2")
							w1 = IsValid(w1) and IsValid(w2) and w1 or nil --reget them if they dead
						else
							rawset(c, "nbr1", nil)
							rawset(c, "nbr2", nil)
						end
						
						if w1 == nil then
							if a == 0 then
								w1 = MapGetFirst(x, y - halfVoxelSizeY, z, 0, "WallSlab", visibleWallTest)
								w2 = MapGetFirst(x - halfVoxelSizeX, y, z, 0, "WallSlab", visibleWallTest)
							elseif a == 90 then
								w1 = MapGetFirst(x, y - halfVoxelSizeY, z, 0, "WallSlab", visibleWallTest)
								w2 = MapGetFirst(x + halfVoxelSizeX, y, z, 0, "WallSlab", visibleWallTest)
							elseif a == 180 then
								w1 = MapGetFirst(x, y + halfVoxelSizeY, z, 0, "WallSlab", visibleWallTest)
								w2 = MapGetFirst(x + halfVoxelSizeX, y, z, 0, "WallSlab", visibleWallTest)
							elseif a == 270 then
								w1 = MapGetFirst(x, y + halfVoxelSizeY, z, 0, "WallSlab", visibleWallTest)
								w2 = MapGetFirst(x - halfVoxelSizeX, y, z, 0, "WallSlab", visibleWallTest)
							end
							w1 = w1 and (w1.isVisible and w1 or IsValid(w1.wall_obj) and w1.wall_obj)
							w2 = w2 and (w2.isVisible and w2 or IsValid(w2.wall_obj) and w2.wall_obj)
							
							if not edit then
								rawset(c, "nbr1", w1)
								rawset(c, "nbr2", w2)
							end
						end
						
						if w1 and w2 then
							local w1v = CMT_IsObjVisible(w1)
							local w2v = CMT_IsObjVisible(w2)
							if hide and (not w1v or not w2v) then --hide when at least one adjacent wall is gone
								c:SetShadowOnly(hide)
								if clear_countour then
									c:ClearHierarchyGameFlags(gofContourInner)
								end
							elseif not hide and w1v and w2v then --show when both adjacent walls are visible
								c:SetShadowOnly(hide)
							end
						end
					end
				end
				last = c
			end
		end
	end
end

local ShouldHideObj = C_ShouldHideObj
--[[
local function ShouldHideObj(obj)
	if obj:GetGameFlags(const.gofDontHideWithRoom) ~= 0 or obj:GetParent() then return false end
	if obj:GetEntity() == "InvisibleObject" then return false end
	if IsKindOfClasses(obj, "Slab", "Decal", "Ladder", "Text", "Room", "CodeRenderableObject", "RoofFXController") then return false end
	if IsKindOf(obj, "Unit") and not obj:IsDead() then return false end
	if IsKindOf(obj, "HideTop") and obj:GetGameFlags(const.gofOnRoof) == 0 then return false end
	
	
	return true
end
]]
local function isInBoxesHelper(boxes, obj)
	local inBoxes = true
	if boxes then
		inBoxes = false
		local x, y, z = obj:GetPosXYZ()
		for j = 1, #(boxes or "") do
			local b = boxes[j]
			local process = false
			
			if b:sizex() > 0 then
				process = b:minx() <= x and x <= b:maxx()
			elseif b:sizey() > 0 then
				process = b:miny() <= y and y <= b:maxy()
			else
				print("Zero sized box in partial wall hiding!")
			end
			
			if process then
				inBoxes = true
				break
			end
		end
	end
	
	return inBoxes
end

local bases = {
	NorthBase = "North",
	SouthBase = "South",
	EastBase = "East",
	WestBase = "West",
}

local function HideShowDoorsAndWindows(hide, room, side, check_prop, boxes, clear_countour)
	local doors = room.spawned_doors and room.spawned_doors[side]
	for i = 1, #(doors or empty_table) do
		local door = doors[i]
		if (check_prop == nil or 
				true or    -- hacked off to test wall contours
				door.hide_with_wall == check_prop) and 
			isInBoxesHelper(boxes, door) then
			door:SetShadowOnly(hide)
			if hide and clear_countour then
				door:ClearHierarchyGameFlags(gofContourInner)
			end
		end
	end
	local windows = room.spawned_windows and room.spawned_windows[side]
	for i = 1, #(windows or empty_table) do
		local window = windows[i]
		if (check_prop == nil or 
				true or    -- hacked off to test wall contours
				window.hide_with_wall == check_prop) and
			isInBoxesHelper(boxes, window) then
			if not IsKindOf(window.main_wall, "RoofWallSlab") then --let roof handle those
				window:SetShadowOnly(hide)
				if hide and clear_countour then
					window:ClearHierarchyGameFlags(gofContourInner)
				end
			end
		end
	end
end

---
--- Hides the base wall of a room on the specified side.
---
--- @param room table The room object.
--- @param side string The side of the room to hide the wall on.
--- @param clear_countour boolean Whether to clear the contour inner flag on the wall slabs.
--- @param batch boolean Whether this is part of a batch operation.
---
function HideBaseWall(room, side, clear_countour, batch)
	local wall = room.spawned_walls and room.spawned_walls[side]
	local height = room.size:z()
	if height > 0 then
		local count = #(wall or empty_table)
		local cols = count / height
		for c = 0, cols - 1 do
			local idx = c * height + 1
			local slab = wall[idx]
			
			if IsValid(slab) then
				if slab.isVisible then
					slab:SetShadowOnly(true)
					if clear_countour then
						slab:ClearHierarchyGameFlags(gofContourInner)
					end
				else
					--could be invisible due to wall obj suppression, notify wall obj to flip its slabs 
					slab:SetWallObjShadowOnly(true, clear_countour)
				end
			end
		end
	end
	if height <= 1 and room:HasWallOnSide(side) then
		--new system
		CollectionsToHideHideCollections(room, side)
	end
	
	HideShowDoorsAndWindows("hide", room, side, nil, nil, clear_countour)
	if not batch then --hidewall will deal with corners when hiding the entire wall
		ShowHideCorners(true, room, side, true, clear_countour)
	end
end

---
--- Shows the base wall of a room on the specified side.
---
--- @param room table The room object.
--- @param side string The side of the room to show the wall on.
--- @param batch boolean Whether this is part of a batch operation.
---
function ShowBaseWall(room, side, batch)
	local wall = room.spawned_walls and room.spawned_walls[side]
	local height = room.size:z()
	for i = 1, #(wall or empty_table) do
		if IsValid(wall[i]) and ((i - 1) % height == 0) then
			if wall[i].isVisible then
				wall[i]:SetShadowOnly(false)
			else
				wall[i]:SetWallObjShadowOnly(false)
			end
		end
	end
	
	if height <= 1 and room:HasWallOnSide(side) then
		--new system
		CollectionsToHideShowCollections(room, side)
	end
	
	HideShowDoorsAndWindows(not "hide", room, side, false) --show all that have hide_with_wall == false
	if not batch then
		ShowHideCorners(false, room, side, true)
	end
end

--[[
local efVisible = const.efVisible
local function HideShowObjects(enum_area, minz, maxz, bSetShadowFlag, inEditor, fnHide)
	local traversed_collections = {}
	
	local SetVisibleHelper = fnHide and fnHide or 
										not inEditor and function(o, bSetShadowFlag) o:SetShadowOnly(bSetShadowFlag) end or 
										function(o, bSetShadowFlag) o:SetShadowOnlyImmediate(bSetShadowFlag) end
	
	--shouldHideTime = 0
	
	MapForEach(enum_area, efVisible, function(o, minz, maxz, inEditor, SetVisibleHelper)
		if not ShouldHideObj(o) then return end

		if inEditor and not bSetShadowFlag then
			--don't show objs that are filtered by editor
			if XEditorFilters:GetObjectMode(o) == "invisible" then
				return
			end
		end

		local x, y, z = o:GetPosXYZ()
		z = z or terrain.GetHeight(x, y)
		if (minz <= z and maxz > z) then
			local col = o:GetRootCollection()
			if not col or not IsCollectionLinkedToRooms(col) then --else collection managed by another system right meow
				if col then
					if not traversed_collections[col] then
						traversed_collections[col] = true
					end
				else
					SetVisibleHelper(o, bSetShadowFlag)
				end
			end
		end
	end, minz, maxz, inEditor, SetVisibleHelper)
	
	local colQBox = enum_area:grow(voxelSizeX * 4, voxelSizeY * 4, voxelSizeZ * 4)

	MapForEach(colQBox, "collected", true, efVisible, function(o)
		if traversed_collections[o:GetRootCollection()] then
			SetVisibleHelper(o, bSetShadowFlag)
		end
	end)
end]]

---
--- Hides or shows objects in a room based on their position relative to the room's bounding box.
---
--- @param room table The room object to hide/show objects in.
--- @param bSetShadowFlag boolean Whether to set the shadow flag on the objects.
--- @param inEditor boolean Whether the operation is being performed in the editor.
--- @param fnHide function An optional function to call to hide the objects.
---
function HideShowRoomObjects(room, bSetShadowFlag, inEditor, fnHide)
	local b = room.box
	local minz = b:minz() - guic * 10 --extend the bottom just a bit so we catch things in the floorboards but not things on the bottom floor
	local maxz = b:maxz()
	local meta = VolumeBuildingsMeta[room.building]
	if meta and meta.maxFloor > room.floor then
		maxz = maxz - guic * 10 --avoid catching things on nxt floor
	end
	--local sts = GetPreciseTicks()
	
	--HideShowObjects(b, minz, maxz, bSetShadowFlag, inEditor, fnHide)
	
	local SetVisibleHelper = fnHide and fnHide or 
										not inEditor and function(o, bSetShadowFlag)
											o:SetShadowOnly(bSetShadowFlag) 
										end or 
										function(o, bSetShadowFlag) 
											o:SetShadowOnlyImmediate(bSetShadowFlag) 
										end
	
	
	C_HideShowObjects(b, minz, maxz, bSetShadowFlag, not not inEditor, SetVisibleHelper, 
								function(cid) return IsCollectionLinkedToRooms(Collections[cid]) end,
								function(o) return XEditorFilters:GetObjectMode(o) == "invisible" end)
	
	--print("HideShowObjects", bSetShadowFlag, GetPreciseTicks() - sts)
end

local function HideObjects(room)
	HideShowRoomObjects(room, true)
end

local function ShowObjects(room)
	HideShowRoomObjects(room, false)
end

---
--- Sets the visibility mode for all walls.
---
--- @param mode string The new visibility mode for all walls.
---
function ShowAllWalls(mode)
	WallVisibilityMode = mode
end

AppendClass.Slab = {
	__parents = { "CSlab" },
	properties = {
		category = "Slabs",
		{ id = "hide_despite_material", name = "Hide Despite Material", editor = "bool", default = false, help = "You know how fat concrete walls don't hide? This overrides this behavior for this slab."},
	},
}

---
--- Hides the walls of a room on the specified side.
---
--- @param room table The room object.
--- @param side string The side of the room to hide the walls on. Can be "Roof", "Floor", "Objects", or a wall side.
--- @param boxes table (optional) A table of bounding boxes to use for hiding the walls.
--- @param clear_countour boolean (optional) Whether to clear the contour flags on the hidden walls.
--- @param batch boolean (optional) Whether to perform the hiding in a batch operation.
---
function HideWall(room, side, boxes, clear_countour, batch)
	if side == "Roof" then
		if RoofWallBoxDebug and room.roof_box then
			DbgAddBox(room.roof_box, RGB(255, 0, 0))
		end
		room:SetRoofVisibility(false)
		return
	end
	
	local base = bases[side]
	if base then
		HideBaseWall(room, base)
		return
	end
	
	if side == "Objects" then
		HideObjects(room)
		return
	end
	
	local isFloor = side == "Floor"
	local wall = isFloor and room.spawned_floors or (room.spawned_walls and room.spawned_walls[side])
	local height = room.size:z()
	local shouldNotHide = not clear_countour and not isFloor and room:GetWallMatHelperSide(side) == "Concrete"
	if isFloor then
		for i = 1, #(wall or empty_table) do
			local slab = wall[i]
			if IsValid(slab) then
				if slab.isVisible then
					slab:SetShadowOnly(true)
					if clear_countour then
						slab:ClearHierarchyGameFlags(gofContourInner)
					end
				end
			end
		end
	elseif height > 0 and room:HasWallOnSide(side) then
		local count = #(wall or empty_table)
		local cols = count / height
		for c = 0, cols - 1 do
			for h = 2, height do
				local idx = c * height + h
				local slab = wall[idx]
				if IsValid(slab) then
					local inBoxes = isInBoxesHelper(boxes, slab)
					if inBoxes then
						if slab.isVisible then
							if not shouldNotHide or slab.variant == "IndoorIndoor" or slab.hide_despite_material then
								slab:SetShadowOnly(true)
								if clear_countour then
									slab:ClearHierarchyGameFlags(gofContourInner)
								end
							end
						else
							slab:SetWallObjShadowOnly(true, clear_countour) --tell window above we are hiding
						end
					end
				end
			end
		end
	end

	if isFloor then
		return
	end
	
	if height > 1 then
		--new system
		if not boxes then
			CollectionsToHideHideCollections(room, side)
		end
	end
	
	ShowHideCorners(true, room, side, false, clear_countour, batch)
end

---
--- Shows the wall for the given room and side.
---
--- @param room table The room to show the wall for.
--- @param side string The side of the room to show the wall for.
--- @param batch boolean Whether this is part of a batch operation.
---
function ShowWall(room, side, batch)
	if not IsValid(room) then return end
	
	if side == "Roof" then
		room:SetRoofVisibility(true)
		return
	end
	
	local base = bases[side]
	if base then
		ShowBaseWall(room, base)
		return
	end
	
	if side == "Objects" then
		ShowObjects(room)
		return
	end
	
	local isFloor = side == "Floor"
	local wall = isFloor and room.spawned_floors or (room.spawned_walls and room.spawned_walls[side])
	local height = room.size:z()
	if isFloor or room:HasWallOnSide(side) then
		for i = 1, #(wall or empty_table) do
			local slab = wall[i]
			if IsValid(slab) then
				if slab.isVisible then
					slab:SetShadowOnly(false)
				elseif not isFloor and (i - 1) % height ~= 0 then
					slab:SetWallObjShadowOnly(false)
				end
			end
		end
	end
	
	if side == "Floor" then return end
	
	if height > 1 then
		--new system
		CollectionsToHideShowCollections(room, side)
	end
	
	ShowHideCorners(false, room, side, false, nil, batch)
end

---
--- Shows or hides the corners of a room based on the specified parameters.
---
--- @param hide boolean Whether to hide the corners or show them.
--- @param room table The room to process.
--- @param side string The side of the room to process.
--- @param baseOnly boolean Whether to only process the base of the corners.
--- @param clear_contour boolean Whether to clear the contour of the corners.
--- @param batch boolean Whether this is part of a batch operation.
---
function ShowHideCorners(hide, room, side, baseOnly, clear_countour, batch)
	local sides = sideToCornerSides[side]
	local height = room.size:z()
	local rz = room:CalcZ()
	local filter
	if not batch then --working on the entire corner batch
		filter = function(c, rz, baseOnly)
			if baseOnly then
				return c:GetPos():z() <= rz or "break"
			else
				return c:GetPos():z() > rz
			end
		end
	end
	
	for i = 1, #sides do
		local cs = sides[i]
		local show = false
		local adjWalls = cornerToWallSides[cs]
		local wallToCheck = adjWalls[1] == side and adjWalls[2] or adjWalls[1]
		show = room:GetWallMatHelperSide(wallToCheck) == noneWallMat
		if not show then
			local ws = cornerSideToWallSides[cs]
			show = not room.visible_walls or (room.visible_walls[ws[1]] or room.visible_walls[ws[2]])
		end
		
		if show then
			local corners = room.spawned_corners and room.spawned_corners[cs]
			ProcessCorners(corners, hide, filter, clear_countour, rz, baseOnly)
		end
	end
	
	local mb = room.box
	local ars = room.adjacent_rooms_per_side and room.adjacent_rooms_per_side[side]
	local oside = GetOppositeSide(side)
	for i = 1, #(ars or "") do
		local ar = ars[i]
		sides = sideToCornerSides[oside]
		for i = 1, #sides do
			local cs = sides[i]
			local corners = ar.spawned_corners and ar.spawned_corners[cs]
			
			if corners and IsValid(corners[1]) and mb:Point2DInsideInclusive(corners[1]:GetPos()) then
				ProcessCorners(corners, hide, filter, clear_countour, rz, baseOnly)
			end
		end
	end
end

---
--- Intersects a line segment with the buildings in the game world.
---
--- @param p1 Vector2 The start point of the line segment.
--- @param p2 Vector2 The end point of the line segment.
--- @param touchedBldsThisPass table A table to keep track of the buildings that have been touched in this pass.
---
function IntersectSegmentWithBuildings(p1, p2, touchedBldsThisPass)
	if WallInvisibilityDebug then
		DbgCRAddVector(p1, p2 - p1)
	end
	
	ForEachVolumeOnSegment(p1, p2, function(room, box, p1, p2)
		if not ShouldProcessRoom(room) then return end
		
		local bld = room.building
		if bld then --rebuild data?
			touchedBldsThisPass[bld] = true
		end
	end)
end

---
--- Intersects a 2D box with the buildings in the game world.
---
--- @param box table The 2D box to intersect with the buildings.
--- @param touchedBldsThisPass table A table to keep track of the buildings that have been touched in this pass.
---
function IntersectBox2DWithBuildings(box, touchedBldsThisPass)
	if WallInvisibilityDebug then
		DbgCRAddBox(box)
	end
	
	EnumVolumes(box, function(room, roomPartsToHide)
		if not ShouldProcessRoom(room) then return end
		
		local bld = room.building
		if bld then --rebuild data?
			touchedBldsThisPass[bld] = true
		end
	end, touchedBldsThisPass)
end

---
--- Intersects a triangle with the buildings in the game world.
---
--- @param p1 Vector2 The first point of the triangle.
--- @param p2 Vector2 The second point of the triangle.
--- @param p3 Vector3 The third point of the triangle.
--- @param touchedBldsThisPass table A table to keep track of the buildings that have been touched in this pass.
---
function IntersectTriangle2DWithBuildings(p1, p2, p3, touchedBldsThisPass)
	if WallInvisibilityDebug then
		p1 = p1:SetZ(terrain.GetHeight(p1) + 100)
		p2 = p2:SetZ(terrain.GetHeight(p2) + 100)
		p3 = p3:SetZ(terrain.GetHeight(p3) + 100)
		DbgCRAddVector(p1, p2 - p1)
		DbgCRAddVector(p2, p3 - p2)
		DbgCRAddVector(p1, p3 - p1)
	end
	
	EnumVolumes(p1, p2, p3, function(room, roomPartsToHide)
		if not ShouldProcessRoom(room) then return end
		
		local bld = room.building
		if bld then --rebuild data?
			touchedBldsThisPass[bld] = true
		end
		
		if WallInvisibilityDebug then
			DbgCRAddVector(room:GetPos())
			DbgCRAddBox(room.box, RGB(255, 0, 0))
		end
	end, touchedBldsThisPass)
end

AppendClass.Room = {
	hidden = false,
}

---
--- Shows a room that was previously hidden.
---
--- @param room Room The room to show.
--- @param force boolean If true, the room will be shown even if it was not previously hidden.
---
function ShowRoom(room, force)
	--show all parts of a room
	if not room.hidden and not force then return end
	room.hidden = false
	ShowWall(room, "Floor")
	ShowBaseWall(room, "North", "batch")
	ShowBaseWall(room, "South", "batch")
	ShowBaseWall(room, "West", "batch")
	ShowBaseWall(room, "East", "batch")
	ShowWall(room, "North", "batch")
	ShowWall(room, "West", "batch")
	ShowWall(room, "South", "batch")
	ShowWall(room, "East", "batch")
	ShowObjects(room)
	
	if WallInvisibilityThread == CurrentThread() then
		roomsRoofsToShow[room] = true
	else
		room:SetRoofVisibility(true)
	end
end

---
--- Hides all parts of a room, including the floor, base walls, walls, and objects.
---
--- @param room Room The room to hide.
---
function HideRoom(room)
	--hide all parts of a room
	if room.hidden then return end
	room.hidden = true
	HideWall(room, "Floor")
	HideBaseWall(room, "North", "clear_countour", "batch")
	HideBaseWall(room, "South", "clear_countour", "batch")
	HideBaseWall(room, "West", "clear_countour", "batch")
	HideBaseWall(room, "East", "clear_countour", "batch")
	HideWall(room, "North", nil, "clear_countour", "batch")
	HideWall(room, "West", nil, "clear_countour", "batch")
	HideWall(room, "South", nil, "clear_countour", "batch")
	HideWall(room, "East", nil, "clear_countour", "batch")
	HideObjects(room)
	room:SetRoofVisibility(false)
end

---
--- Hides all rooms on the specified floor of the given building.
---
--- @param bld table The building containing the rooms to hide.
--- @param f integer The floor index of the rooms to hide.
---
function HideRoomsOnFloor(bld, f)
	local floorT = bld[f]
	for i = 1, #(floorT or "") do
		local room = floorT[i]
		if ShouldProcessRoom(room) then
			HideRoom(room)
		end
	end
end

---
--- Shows all rooms on the specified floor of the given building.
---
--- @param bld table The building containing the rooms to show.
--- @param f integer The floor index of the rooms to show.
--- @param force boolean (optional) If true, force the rooms to be shown even if they are already visible.
---
function ShowRoomsOnFloor(bld, f, force)
	local floorT = bld[f]
	for i = 1, #(floorT or "") do
		local room = floorT[i]
		if ShouldProcessRoom(room) then
			ShowRoom(room, force)
		end
	end
end

local function checkWallRange(lookAt, r, side)
	if CollapseWallRange <= 0 then return true end
	
	local b = r:GetWallBox(side)
	local d2 = PointToBoxDist2D2(lookAt, b)
	
	return d2 <= CollapseWallRange * CollapseWallRange
end

local function addWallsToCollapseHelper(collapsedWallsThisPass, r, vw, side, lookAt)
	if not checkWallRange(lookAt, r, side) then
		return
	end
	
	--if not vw or vw[side] then --this makes invisible walls not fire events.
		collapsedWallsThisPass[r][side] = "full"
	--end
	
	if AllowPartialWallsCollapse then
		local ars = r.adjacent_rooms
		local arps = r.adjacent_rooms_per_side and r.adjacent_rooms_per_side[side]
		local oside = GetOppositeSide(side)
		local oarps = r.adjacent_rooms_per_side and r.adjacent_rooms_per_side[oside] or empty_table
		for i = 1, #(arps or "") do
			local ar = arps[i]
			local arars = ar.adjacent_rooms_per_side[oside]
			if (not ar.visible_walls or ar.visible_walls[oside]) 
				and not table.find(oarps, ar) --if adjacent on both sides, then it's inside!
				and table.find(arars, r) --adjacent room is not adjacent to us on the opposite side, then it's inside!
				and not ar.ignore_zulu_invisible_wall_logic then --0165001
				local data = r.adjacent_rooms[ar]
				local box = data[1]
				collapsedWallsThisPass[ar] = collapsedWallsThisPass[ar] or {}

				if collapsedWallsThisPass[ar][oside] ~= "full" then
					collapsedWallsThisPass[ar][oside] = collapsedWallsThisPass[ar][oside] or {}
					table.insert(collapsedWallsThisPass[ar][oside], box)
				end
			end
		end
	end
end

--true -- all walls are hidden, false - walls hide using default behavior, but outside of combat - in range and facing the cam
local HideAllHidesAllWalls = true 

---
--- Handles the logic for wall invisibility in the game. This function is responsible for determining which walls should be visible or hidden based on the camera position, combat state, and other factors.
---
--- @function WallInvisibilityThreadMethod_V2_PlanA
--- @return nil
function WallInvisibilityThreadMethod_V2_PlanA()
	if IsRealTimeThread() and IsChangingMap() then
		WaitMsg("ChangeMapDone", 100000)
	end
	
	SetBuildingTouchRange(mapdata.ExtendBuildingTouchRange and "extended" or "default")
	BuildBuildingsData()
	VT2TouchedBuildings = {}
	VT2CollapsedWalls = {}
	roomsRoofsToShow = {}
	local up = point(0, 0, voxelSizeZ)
	local lastCamPos, lastLookAt, lastHideAll, lastIsInOverview, lastIsInCombat, lastFloor, lastVisibilityMode
	local last_update_time
	local update_min_interval = 200
	
	while true do
		if last_update_time then
			WaitFramesOrSleepAtLeast(1, Max(0, last_update_time + update_min_interval - now()))
		else
			WaitNextFrame()
		end
		if WallInvisibilityThread ~= CurrentThread() then 
			return
		end		
		if last_update_time and (now() < last_update_time + 500) then
			goto continue
		end
		
		local camPos, lookAt = cameraTac.GetZoomedPosLookAt()
		local camFloor = cameraTac.GetFloor() + 1--WallInvisibilityGetCamFloor(lookAt:xyz())
		local camRoundedFloor = WallInvisibilityGetCamFloorRounded(lookAt:xyz())
		local hideAll = terminal.IsShortcutPressed("actionHideAll") or not WallVisibilityMode
		if hideAll then
			local focus = terminal.desktop.keyboard_focus
			if focus and IsKindOf(focus, "XEdit") then
				hideAll = false
			end
		end
		local showAll = type(WallVisibilityMode) == "boolean" and WallVisibilityMode == true
		local mapWideTouch = WallVisibilityMode == "mapwide" or WallVisibilityMode == "mapwide+walls"
		local isInOverview = cameraTac.GetIsInOverview() and not gv_DeploymentStarted
		local isInCombat = true--g_Combat or DbgCombatWallHiding
		
		if (lastCamPos == camPos and lastLookAt == lookAt and hideAll == lastHideAll and lastIsInOverview == isInOverview and
			camFloor == lastFloor and lastIsInCombat == isInCombat and lastVisibilityMode == WallVisibilityMode) then
			goto continue
		end

		lastCamPos = camPos
		lastLookAt = lookAt
		lastHideAll = hideAll
		lastIsInOverview = isInOverview
		lastIsInCombat = isInCombat
		lastFloor = camFloor
		lastVisibilityMode = WallVisibilityMode

		local touchedBldsThisPass = {}
		local collapsedWallsThisPass = {}
		
		if WallInvisibilityDebug then
			DbgCRClear()
		end
		
		local dirV = lookAt - camPos
		dirV = dirV:SetZ(0)
		if dirV == point30 then goto continue end

		if not showAll then -- If showing all, then just consider the camera as not touching any buildings.
			if hideAll or mapWideTouch then -- In these cases all buildings need to be processed.
				for i = 1, #VolumeBuildings do
					touchedBldsThisPass[VolumeBuildings[i]] = true
				end
			else
				dirV = SetLen(dirV, rayOffsetVerticalV2 + (ExtendVerticelPerFloor * Max(camRoundedFloor - 1, 0)))
				local dirH = SetLen(Rotate(dirV, 90 * 60), rayOffsetHorizontalV2)
				local center = lookAt + SetLen((camPos - lookAt):SetZ(0), voxelSizeX * 3 + halfVoxelSizeX)
				local topLeft = center + dirV + dirH + up
				local topRight = center + dirV - dirH + up
				
				IntersectTriangle2DWithBuildings(camPos, topRight, topLeft, touchedBldsThisPass)
			end
		end

		-- Process touched blds and create new state data
		local camZ = lookAt:z()
		camZ = ((camZ + voxelSizeZ - 1) / voxelSizeZ) * voxelSizeZ --turns out terrain is consistently ~5 cm below rooms, ceil to next tile
		for bld, _ in pairs(touchedBldsThisPass) do
			local meta = VolumeBuildingsMeta[bld]
			local from = meta.minFloor
			local to = meta.maxFloor
			local newFloor
			
			if hideAll then
				newFloor = from
				touchedBldsThisPass[bld] = from
			else
				local camFloorIsRoof = camFloor == to and meta.maxFloorIsRoof -- Dont break open roof on same floor as it.
				if meta[camFloor] and not camFloorIsRoof then
					newFloor = camFloor
					touchedBldsThisPass[bld] = camFloor
				end

				-- The code below implements hiding based on the camera Z level, instead of camera floor.
--[[				for f = to, from, -1 do
					if meta[f] then
						local fb = meta[f].box
						if camZ >= fb:minz() and camZ < fb:maxz() then
							newFloor = f
							touchedBldsThisPass[bld] = f
							break
						end
						
						if f == from and camZ < fb:minz() and fb:minz() - camZ <= HitFirstFloorWhenBelowItThisMuch then
							--if we are just below first floor, accept it, fixes flicker because of small terrain elevations
							newFloor = f
							touchedBldsThisPass[bld] = f
							break
						end
					end
				end
				if not newFloor and not isInOverview then
					local m1 = meta[to]
					local m2 = meta[to - 1]
					local z = Max(m1 and m1.box:maxz() or 0, m2 and m2.box:maxz() or 0)
					if z > 0 then
						if camZ - z <= HideRoofsWhenAboveMaxFloorUpToThisMuch then
							newFloor = to
							touchedBldsThisPass[bld] = newFloor
						end
					end
				end]]
			end
			
			if not newFloor then
				touchedBldsThisPass[bld] = nil -- no floor z hit, ignore
			else
				--compare with old state
				local oldFloor = VT2TouchedBuildings[bld]
				if not oldFloor then
					--new, hide everything up from the floor hit
					for f = to, touchedBldsThisPass[bld] + 1, -1 do
						HideRoomsOnFloor(bld, f)
					end
				elseif oldFloor ~= newFloor then
					--old
					if newFloor < oldFloor then
						--hide 
						for f = oldFloor, newFloor + 1, -1 do
							HideRoomsOnFloor(bld, f)
						end
					else --newFloor > oldFloor
						--show
						for f = oldFloor, newFloor do
							ShowRoomsOnFloor(bld, f)
						end
					end
				end
				
				-- Build collapsed walls state for the new floor
				local floorT = bld[newFloor] or {}
				for i = 1, #floorT do
					local r = floorT[i]
					if not ShouldProcessRoom(r) then goto continue end

					roomsRoofsToShow[r] = nil
					if r:IsRoofOnly() then
						HideRoom(r)
						goto continue
					end

					collapsedWallsThisPass[r] = collapsedWallsThisPass[r] or {}
					collapsedWallsThisPass[r]["Roof"] = true -- All roofs fall always
					
					-- "mapwide+walls" will only cause the walls on the camera floor (newFloor) to be hidden
					-- while hideall will set the newFloor to min, hiding everything.
					if (hideAll and HideAllHidesAllWalls) or (WallVisibilityMode == "mapwide+walls") then
						collapsedWallsThisPass[r]["West"] = "full"
						collapsedWallsThisPass[r]["East"] = "full"
						collapsedWallsThisPass[r]["North"] = "full"
						collapsedWallsThisPass[r]["South"] = "full"
						goto continue
					end
					
					if (isInCombat and not isInOverview) or hideAll then
						local vw = r.visible_walls
						if vw and vw.total <= 0 then goto continue end
					
						local s = r.size
						if s:z() <= 1 then goto continue end -- Nothing to hide for room tall 1, also no adjacency events

						local p = r.position
						collapsedWallsThisPass[r] = collapsedWallsThisPass[r] or {}
						if camPos:x() < p:x() then
							addWallsToCollapseHelper(collapsedWallsThisPass, r, vw, "West", lookAt)
						end
						if camPos:y() < p:y() then
							addWallsToCollapseHelper(collapsedWallsThisPass, r, vw, "North", lookAt)
						end
						if camPos:y() > (p:y() + s:y() * voxelSizeY) then
							addWallsToCollapseHelper(collapsedWallsThisPass, r, vw, "South", lookAt)
						end
						if camPos:x() > (p:x() + s:x() * voxelSizeX) then
							addWallsToCollapseHelper(collapsedWallsThisPass, r, vw, "East", lookAt)
						end
					end

					::continue::
				end
			end
		end
		
		if WallInvisibilityDebug then
			if not IsValid(dbgTxtObj) then
				dbgTxtObj = PlaceObject("Text")
				dbgTxtObj:SetTextStyle("BugReportScreenshot")
				dbgTxtObj:SetColor(RGB(0, 255, 0))
			end
			dbgTxtObj:SetPos(lookAt:AddZ(guim * 5))
			local str = string.format("Cam z is at %d;\n", camZ)
			local c = 0
			for bld, f in pairs(touchedBldsThisPass) do
				local meta = VolumeBuildingsMeta[bld]
				local b = meta[f].box
				DbgCRAddBox(b:grow(100, 100, 0), RGB(0, 255, 0)) --grow a bit so not to overlap
				c = c + 1
				str = string.format("%sFloor box hit with minz %d and maxz %d and first room %s\n", str, b:minz(), b:maxz(), bld[f][1].name)
			end
			str = string.format("%s%d building floors were hit;\n", str, c)
			str = string.format("%s\nLegend:\nGreen boxes - building floor bounding boxes hit;\nRed boxes with line in the middle - rooms touched by the collision body;\nYellow boxes - objects within room volumes that have triggered their whole collection to hide;", str)
			dbgTxtObj:SetText(str)
			
			for o, _ in pairs(dbgVolumeTriggerObjects or empty_table) do
				DbgCRAddBox(o:GetObjectBBox():grow(100, 100, 0), RGB(255, 255, 0))
			end
		end
		
		--show blds no longer hit
		for bld, floor in pairs(VT2TouchedBuildings) do
			if not touchedBldsThisPass[bld] then
				local meta = VolumeBuildingsMeta[bld]
				local from = meta.minFloor
				local to = meta.maxFloor
				for f = floor, to do
					--ShowRoomsOnFloor(bld, f, "roofs") -- Z based hiding code
					ShowRoomsOnFloor(bld, f)
				end
			end
		end
		
		--compare collapsedWalls states
		local wallsToShow = {} --show and hide in batches to avoid hiding something for it to just be shown later in the same pass
		local wallsToHide = {}
		local partialBoxes = {}
		
		for r, new in pairs(collapsedWallsThisPass) do
			local old = VT2CollapsedWalls[r]
			local bld = r.building
			local visibleFloor = touchedBldsThisPass[bld]
			
			if not visibleFloor or r.floor <= visibleFloor then --dont show anything from rooms that are above visible floor
				for side, old_data in pairs(old or empty_table) do
					local new_data = new[side]
					if not new_data or (old_data == "full" and new_data ~= "full") then
						wallsToShow[r] = wallsToShow[r] or {}
						table.insert_unique(wallsToShow[r], side)
					end
				end
			end
			
			for side, new_data in pairs(new or empty_table) do
				local old_data = old and old[side]
				if not old or not old_data or 
						(old_data ~= new_data and
							(type(old_data) ~= type(old_data) or type(old_data) ~= "table" or not table.iequal(old_data, new_data))) then
					
					wallsToHide[r] = wallsToHide[r] or {}
					table.insert_unique(wallsToHide[r], side)
					if type(new_data) == "table" then
						partialBoxes[r] = partialBoxes[r] or {}
						partialBoxes[r][side] = new_data
					end
				end
			end
		end
		
		for r, old in pairs(VT2CollapsedWalls) do
			--switching floors may glitch out when rooms of different floors are adjacent to each other horizontally
			local new = collapsedWallsThisPass[r]
			if not new then
				local bld = r.building
				local f = touchedBldsThisPass[bld]
				if not f or r.floor <= f then
					for side, old_data in pairs(old or empty_table) do
						wallsToShow[r] = wallsToShow[r] or {}
						table.insert_unique(wallsToShow[r], side)
					end
				end
			end
		end
		
		for r, t in pairs(wallsToShow) do
			for i = 1, #t do
				ShowWall(r, t[i])
			end
		end
		
		for r, t in pairs(wallsToHide) do
			for i = 1, #t do
				HideWall(r, t[i], partialBoxes[r] and partialBoxes[r][t[i]])
			end
		end
		
		for r, _ in pairs(roomsRoofsToShow) do
			r:SetRoofVisibility(true)
			roomsRoofsToShow[r] = nil
		end
		
		--flush
		local dbgLastTouchedBldsState = touchedBldsThisPass
		local dbgLastColapseWallsState = collapsedWallsThisPass
		VT2TouchedBuildings = touchedBldsThisPass
		VT2CollapsedWalls = collapsedWallsThisPass
		
		if (next(wallsToShow) ~= nil) or (next(wallsToHide) ~= nil) or (next(roomsRoofsToShow) ~= nil) then
			Msg("WallVisibilityChanged")
			last_update_time = now()
		end
		
		CollectionsToHideProcessDelayedHides()
		CollectionsToHideProcessDelayedShows()
		
		::continue::
	end
end

---
--- Calculates the squared 2D distance between a point and a box.
---
--- @param p Vector3 The point to measure the distance to.
--- @param b Box The box to measure the distance to.
--- @return number The squared 2D distance between the point and the box.
function PointToBoxDist2D2(p, b)
	local bx, by, _ = b:Center():xyz()
	local x, y, _ = p:xyz()
	local dx = Max(abs(x - bx) - b:sizex() / 2, 0)
	local dy = Max(abs(y - by) - b:sizey() / 2, 0)
	return dx * dx + dy * dy
end

DefineClass.NonWallHidable = {}

WallInvisibilityThreadMethod = WallInvisibilityThreadMethod_V2_PlanA

if Platform.developer then

---
--- Processes volumes above the maximum camera floor and stores error sources.
---
--- This function is called when the map is loaded or when the volume buildings are rebuilt.
--- It iterates through all volume buildings and checks if any rooms are above the maximum camera floor.
--- If a room is found above the maximum floor, an error source is stored for that room.
---
--- @param skip_rebuild boolean (optional) If true, the function will not call BuildingsPostProcess().
---
function VolumesAboveMaxFloorVME(skip_rebuild)
	if not VolumeBuildings then return end
	if not skip_rebuild then BuildingsPostProcess() end
	for bld, meta in pairs(VolumeBuildingsMeta) do
		if meta.maxFloor > hr.CameraTacMaxFloor + 1 then
			for floor, volumes in pairs(bld) do
				for i = 1, #volumes do
					local room = volumes[i]
					if IsValid(room) and room.floor == meta.maxFloor then
						StoreErrorSource(room, "Room floor is above maximum camera floor (" .. tostring(room.floor) .. ">" .. tostring(hr.CameraTacMaxFloor) .. ")")
						break
					end
				end
			end
		end
	end
end

OnMsg.PostSaveMap = VolumesAboveMaxFloorVME
OnMsg.NewMapLoadedCameraSettingsSet = VolumesAboveMaxFloorVME
function OnMsg.VolumeBuildingsRebuilt()
	VolumesAboveMaxFloorVME(true)
end

end

function OnMsg.CameraTacOverview(set)
	if set then
		ShowAllWalls("mapwide")
	else
		ShowAllWalls("auto")
	end
end