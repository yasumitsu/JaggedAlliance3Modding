if FirstLoad then
	CCMT = true
	C_CCMT = true
	C_CMT_Async = false
end
MapVar("CMT_trigger_target_pairs", false)

---
--- Sets the CCMT flag and reloads the trigger target pairs.
---
--- @param val boolean The new value for the CCMT flag.
function SetCCMT(val)
	if CCMT == val then
		return
	end
	
	if val then
		CMT_trigger_target_pairs = false
	end
	
	SetC_CCMT(val)
	CCMT = val
	ReloadTriggerTargetPairs()
end

function OnMsg.GameEnterEditor()
	StopAllHiding("Editor")
end

function OnMsg.GameExitEditor()
	ResumeAllHiding("Editor")
end

---
--- Sets the shadow-only state of the object.
---
--- @param bSet boolean Whether to set the object as shadow-only.
function CObject:SetShadowOnly(bSet)
	if g_CMTPaused then return end
	CMT(self, bSet)
end

---
--- Sets the shadow-only state of the object and its opacity.
---
--- @param bSet boolean Whether to set the object as shadow-only.
function CObject:SetShadowOnlyImmediate(bSet)
	if bSet then
		self:SetHierarchyGameFlags(const.gofSolidShadow)
	else
		self:ClearHierarchyGameFlags(const.gofSolidShadow)
	end
	self:SetOpacity(bSet and 0 or 100)
end

---
--- Sets the shadow-only state of the object and its opacity.
---
--- @param bSet boolean Whether to set the object as shadow-only.
function Decal:SetShadowOnlyImmediate(bSet)
	if bSet then
		self:SetHierarchyGameFlags(const.gofSolidShadow)
	else
		self:ClearHierarchyGameFlags(const.gofSolidShadow)
	end
end

function OnMsg.ChangeMap()
	CMT_SetPause(true, "ChangeMap")
	C_CMT_Reset()
end

function OnMsg.ChangeMapDone()
	ReloadTriggerTargetPairs()
	CMT_SetPause(false, "ChangeMap")
end

function OnMsg.GameExitEditor()
	ReloadTriggerTargetPairs()
end

---
--- Reloads the trigger-target pairs for the current map.
---
--- This function is responsible for updating the `CMT_trigger_target_pairs` table, which maps
--- collections or individual HideTop objects to the objects they should hide from the camera.
--- The function checks the current map and game settings to determine the appropriate
--- collision detection method to use (distance check or full collision check).
---
--- If the current map is empty, the function returns without doing anything.
---
--- @return nil
function ReloadTriggerTargetPairs()
	if GetMap() == "" then
		return
	end
	if CCMT then
		--CCMTMode
		--0 dist check (UseDistCheckForNonTops)
		--1 collision check (UseCollisionForNonTops)
		ReloadCMTTargets((EngineOptions.ObjectDetail == "Low") and 0 or 1)
	else
		local border = GetBorderAreaLimits()
		CMT_trigger_target_pairs = {}
		for _, col in pairs(CollectionsByName) do
			if not IsCollectionLinkedToRooms(col) then
				local objs = MapGet("map", "collection", col.Index, true)
				if col.HideFromCamera then
					CMT_trigger_target_pairs[col] = objs
				elseif not col.DontHideFromCamera then
					local ht
					for _, o in ipairs(objs) do
						if IsKindOf(o, "HideTop") and o:GetGameFlags(const.gofOnRoof) == 0 and (not border or border:Point2DInside(o)) then
							ht = ht or {}
							table.insert(ht, o)
						end
					end
					if ht then
						CMT_trigger_target_pairs[col] = ht
					end
				end
			elseif col.HideFromCamera then
				print("Collection " .. col.Name .. " with index " .. tostring(col.Index) .. " is marked as HideFromCamera but is also linked to rooms, HideFromCamera is ignored!")
			end
		end
		MapForEach("map", "HideTop", function(o)
			local col = o:GetCollection()
			if col or o:GetGameFlags(const.gofOnRoof) ~= 0 then
				return
			end
			if not o.Top then return end
			CMT_trigger_target_pairs[o] = true
		end)
	end
end

local sleep_time = CMT_OpacitySleep*4
---
--- Runs a repeating thread that handles collision detection and hiding of objects in the game world.
---
--- The thread runs at a fixed interval determined by `sleep_time`, which is calculated as 4 times the value of `CMT_OpacitySleep`.
---
--- If the game is paused (`g_CMTPaused` is true), the thread will return without doing anything.
---
--- The thread first gets the current camera position and look-at point, and calculates a midpoint between them as the `hiding_pt`.
---
--- If `CCMT` is true, the thread will call either `AsyncC_CMT_Thread_Func` or `async.AsyncC_CMT_Thread_Func` with the `SelectedObj` parameter.
---
--- If `CCMT` is false, the thread will call `CMT_GetCollectionsToHide` to get a list of collections that should be hidden from the camera. It then iterates through the `CMT_trigger_target_pairs` table and calls the `HandleCMTTrigger` method on each trigger, passing the camera position, look-at point, hiding point, objects to hide, and hide collections.
---
MapRealTimeRepeat("CMT_Trigger_Thread", 0, function()
	assert(sleep_time % CMT_OpacitySleep == 0)
	Sleep(sleep_time)
	-- local startTs = GetPreciseTicks(1000)
	if g_CMTPaused then 
		return 
	end
	local camera_pos, lookAt = cameraTac.GetZoomedPosLookAt()
	local hiding_pt = camera_pos + (lookAt - camera_pos)/2

	if CCMT then
		if C_CMT_Async then
			AsyncC_CMT_Thread_Func(SelectedObj)
		else
			async.AsyncC_CMT_Thread_Func(nil, SelectedObj)
		end
	else
		local hide_collections = CMT_GetCollectionsToHide()
		for trigger, objs in next, CMT_trigger_target_pairs do
			trigger:HandleCMTTrigger(camera_pos, lookAt, hiding_pt, objs, hide_collections)
		end
	end
	-- print("CCMT", CCMT, "CMT_Trigger_Thread time", GetPreciseTicks(1000) - startTs)
end)

local col_mask_any = 2^32-1
local col_mask_all = 0
local cam_pos, lookat
---
--- Retrieves a table of collections that should be hidden from the camera.
---
--- The function first checks if `CMTCollisionDbg` is true, and if so, it stores the current camera position and look-at point in `cam_pos` and `lookat` variables. It then checks if the camera position or look-at point has changed since the last check, and updates the `cam_pos` and `lookat` variables accordingly.
---
--- The function then creates an empty `collections` table and a bounding box `bbox` around the camera position. It uses the `collision.Collide` function to check for collisions between the bounding box and the game objects in the scene. For each object that collides with the bounding box, the function checks if the object is a `HideTop` object, and if not, it retrieves the root collection of the object. If the collection has the `HideFromCamera` flag set, and the collection is not already in the `collections` table, the function adds the collection to the `collections` table.
---
--- If `CMTCollisionDbg` is true, the function also sets the `gofEditorSelection` game flag on the colliding objects and stores them in the `CMTCollisionDbgShown` table. It then checks the `CMTCollisionDbgShown` table for any objects that are no longer colliding, and clears their `gofEditorSelection` game flag.
---
--- Finally, the function returns the `collections` table, which contains the indices of the collections that should be hidden from the camera.
---
function CMT_GetCollectionsToHide()
	local collided = CMTCollisionDbg and {}
	if CMTCollisionDbg then
		local c, l = GetCamera()
		cam_pos = cam_pos or c
		lookat = lookat or l
		if c ~= cam_pos or l ~= lookat then
			cam_pos = c
			lookat = l
		end
	end
	
	local collections = {}
	local ptCamera, ptCameraLookAt = GetCamera()
	local bbox = box(-2000, -2000, -2000, 2000, 2000, 2000)
	collision.Collide(bbox + ptCamera, ptCameraLookAt - ptCamera, 0, col_mask_all, col_mask_any,
	function(o)
		if not IsValid(o) then return end --happens when editing rooms in editor
		if IsKindOf(o, "HideTop") then return end
		local col = o:GetRootCollection()
		if not col or not col.HideFromCamera or collections[col.Index] then
			return
		end
		
		if CMTCollisionDbg then
			o:SetHierarchyGameFlags(const.gofEditorSelection)
			CMTCollisionDbgShown[o] = true
			collided[o] = true
		end
		
		collections[col.Index] = true
	end)
	
	if CMTCollisionDbg then
		for o, _ in pairs(CMTCollisionDbgShown) do
			if not collided[o] then
				o:ClearHierarchyGameFlags(const.gofEditorSelection)
				CMTCollisionDbgShown[o] = nil
			end
		end
	end
	return collections
end

--- Handles the CMT (Camera Masking Trigger) for a collection.
---
--- @param camera_pos table The current camera position.
--- @param lookAt table The current camera look-at position.
--- @param hiding_pt table The point where the camera is hiding.
--- @param objs_to_hide table The objects that should be hidden.
--- @param hide_collections table The collections that should be hidden.
function Collection:HandleCMTTrigger(camera_pos, lookAt, hiding_pt, objs_to_hide, hide_collections)
	local hide
	if hide_collections[self.Index] then
		hide = true
	else
		for _, obj in ipairs(objs_to_hide) do
			if IsKindOf(obj, "HideTop") and obj:TopHidingCondition(camera_pos, lookAt, hiding_pt) then
				hide = true
				break
			end
		end
	end
	for _, obj in ipairs(objs_to_hide) do
		obj:SetShadowOnly(hide)
	end
end

if FirstLoad then
	CMTCollisionDbg = false
end

MapVar("CMTCollisionDbgShown", {})

--- Toggles the CMT (Camera Masking Trigger) collision debug mode.
---
--- When the debug mode is enabled, objects that are part of the CMT collision
--- detection are highlighted with the editor selection flag. When the debug mode
--- is disabled, the editor selection flag is cleared from those objects.
---
--- This function is used for debugging purposes to visualize the objects that
--- are considered for the CMT collision detection.
function ToggleCMTCollisionDbg()
	for o, _ in pairs(CMTCollisionDbgShown) do
		o:ClearHierarchyGameFlags(const.gofEditorSelection)
		CMTCollisionDbgShown[o] = nil
	end
	CMTCollisionDbg = not CMTCollisionDbg
end

local visualized_cube_count = 3
--- Visualizes a set of cubes along the camera's look-at direction.
---
--- This function is used for debugging purposes to visualize the camera masking
--- trigger (CMT) collision detection. It adds a set of red boxes along the
--- camera's look-at direction, starting from the camera position.
---
--- @param none
--- @return none
function VisualizeCMTCube()
	local ptCamera, ptCameraLookAt = GetCamera()
	local bbox = box(-2000, -2000, -2000, 2000, 2000, 2000)
	for i = 1, visualized_cube_count do
		DbgAddBox(bbox + (ptCamera + (ptCameraLookAt - ptCamera)*i/visualized_cube_count), const.clrRed)
	end
end

---
--- Checks if the given object is a contour object based on its class and entity.
---
--- This function is used by the CCMT (Camera Collision Masking Trigger) system to
--- determine if an object should be considered for contour detection.
---
--- @param obj CObject The object to check
--- @return boolean True if the object is a contour object, false otherwise
---
function IsContourObjectClassAndEntityCheck(obj)
	--used by CCMT
	if IsKindOf(obj, "Slab") then
		if obj.room then
			if obj.room:IsRoofOnly() then 
				return false 
			end
		end
		
		if IsKindOf(obj, "SlabWallObject") then
			if next(obj.decorations) then
				for _, plank in ipairs(obj.decorations) do
					plank:SetHierarchyGameFlags(const.gofContourInner)
				end
			end
			local s = obj.main_wall
			if IsKindOf(s, "RoofWallSlab") then
				return false --no contours for windows on roofs
			end
		end
		
		local entity = obj:GetEntity()
		return (not IsKindOfClasses(obj, "RoofSlab", "RoofWallSlab", "FloorSlab", "CeilingSlab", "RoofCornerWallSlab") and not entity:find("ence"))
	end
	
	return false
end

---
--- Checks if the given object is a contour object based on its class, entity, and floor level.
---
--- This function is used by the CCMT (Camera Collision Masking Trigger) system to
--- determine if an object should be considered for contour detection.
---
--- @param obj CObject The object to check
--- @return boolean True if the object is a contour object, false otherwise
---
function IsContourObject(obj)
	if IsContourObjectClassAndEntityCheck(obj) then
		local flr = cameraTac.GetFloor() + 1
		if obj.floor > flr then return false end
		
		return true
	end
	if g_AdditionalContourObjects[obj] then 
		return true
	end
	
	return false
end

------------------------------------------------------------------------------------
--CMTPlane
------------------------------------------------------------------------------------
local mask = const.CMTPlaneFlags
DefineClass.CMTPlane = {
	__parents = { "CObject", "EditorVisibleObject" },
	entity = "CMTPlane",
}

---
--- Sets up the collections for CMTPlane objects in the current map.
---
--- This function is called when the game exits the editor or when the map changes.
--- It iterates through all CMTPlane objects in the map, groups them by their collection
--- index, and sets the collision mask for the corresponding CObject instances.
---
--- @param map string The name of the current map.
---
function SetupCMTPlaneCollections(map)
	if map == "" then return end
	local cols = {}
	local collectionlessPlanes = {}
	local allPlanes = {}
	MapForEach("map", "CMTPlane", function(o, cols, allPlanes, collectionlessPlanes)
		allPlanes[o] = true
		local id = o:GetCollectionIndex()
		if id and id ~= 0 then
			cols[id] = true
		else
			table.insert(collectionlessPlanes, o)
		end
	end, cols, allPlanes, collectionlessPlanes)
	
	if next(cols) then
		MapForEach("map", "CObject", function(o, cols, allPlanes)
			if allPlanes[o] then
				collision.SetAllowedMask(o, const.cmSeenByCMT)
				return 
			end
			
			local id = o:GetCollectionIndex()
			if cols[id] then
				local m = collision.GetAllowedMask(o)
				m = m & ~mask
				collision.SetAllowedMask(o, m)
			end
		end, cols, allPlanes)
	end
	
	if #collectionlessPlanes > 0 then
		print("Found " .. #collectionlessPlanes .. " CMTPlane(s) without collections!")
		--should probably kill those?
	end
end

OnMsg.GameExitEditor = SetupCMTPlaneCollections
OnMsg.ChangeMapDone = SetupCMTPlaneCollections

---
--- Toggles the visibility systems for the CMT (Collision Mesh Terrain) in the game.
---
--- This function is responsible for pausing/unpausing the CMT, showing/hiding all CMT objects,
--- and starting/stopping the wall invisibility thread.
---
--- @param reason string (optional) The reason for toggling the visibility systems.
---
function ToggleVisibilitySystems(reason)
	local turnOn = g_CMTPaused
	if not turnOn then
		StopWallInvisibilityThread()
	end
	CMT_SetPause(not turnOn, reason or "BecauseReasons")
	C_CCMT_ShowAllAndReset()
	if turnOn then
		StartWallInvisibilityThreadWithChecks()
	end
end