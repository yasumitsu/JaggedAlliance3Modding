-- Zulu specific destroyable
local voxelSizeX = const.SlabSizeX or 0
local voxelSizeY = const.SlabSizeY or 0
local voxelSizeZ = const.SlabSizeZ or 0
local halfVoxelSizeX = voxelSizeX / 2
local halfVoxelSizeY = voxelSizeY / 2
local halfVoxelSizeZ = voxelSizeZ / 2
local InvalidZ = const.InvalidZ
local halfGuim = guim / 2
local eightGuim = guim / 8

if FirstLoad then
	DbgPropagateSlabDestructionInEditor = false
	
	DbgDestruction_DisableWallAndObjPropagation = false --disable propagation from walls and generic objs
	DbgDestruction_OnlyVerticalPropagation = false --disable horizontal propagation from walls and generic objs
	DbgDestruction_OnlyVerticalPropagationObjsOnly = true --disable horizontal propagation from generic objs
	DbgDestruction_HorizontalObjPropagationOnlyAffectsProps = false --horizontal generic obj propagation only affects prop objs even in first pass, already true for walls
	DbgDestruction_WallAndObjPropatationOnlyAffectsProps = false --obj and wall propagation only propagates towards props
end

MapVar("DestructionInProgressObjs", {}) --cobjs shouldn't keep data in themselves because they can be deleted by gc at any time
MapVar("DestructionInProgressObjsCarryOverData", {})

local function AddCarryOverData(o, ...) --name, val, name, val, ...
	local t = DestructionInProgressObjsCarryOverData[o] or {}
	DestructionInProgressObjsCarryOverData[o] = t
	for i = 1, select('#', ...), 2 do
		t[select(i, ...)] = select(i + 1, ...)
	end
end

DefineClass.CascadeDestroyForbidden = {__parents ={}}
MapVar("TemporarilyInvulnerableObjs", {})
--trumps invulnerable interactables logic which trumps regular logic..
InteractableClassesThatAreDestroyable = { "MachineGunEmplacement", "RangeGrantMarker", "CuttableFence", "Door" }

local nonDestroyableClasses = {"Slab", "Ladder", "Unit", "EditorMarker", "Decal", "InvisibleObjectHelper", "SoundSource", "ParSystem", "Room", "CascadeDestroyForbidden", "TwoPointsAttach", "Debris"}
---
--- Determines whether an object should be destroyed based on various conditions.
---
--- @param obj table The object to check for destruction.
--- @param clsTable table (optional) A table of non-destroyable class names.
--- @return boolean True if the object should be destroyed, false otherwise.
---
function ShouldDestroyObject(obj, clsTable)
	local isAlreadyDestroyed = obj:GetEnumFlags(const.efVisible) == 0 or IsGenericObjDestroyed(obj) or DestructionInProgressObjs[obj]
	if isAlreadyDestroyed then
		return false
	end
	if IsObjVulnerableDueToLDMark(obj) then
		return true
	elseif obj:IsInvulnerable() then
		return false
	end
	
	if TemporarilyInvulnerableObjs[obj] then
		return false
	end
	
	clsTable = clsTable or nonDestroyableClasses
	if obj:GetGameFlags(const.gofPermanent) ~= 0 and
		not obj:GetParent() and 
			not IsKindOfClasses(obj, table.unpack(clsTable)) and
			(not IsKindOf(obj, "DestroyableWallDecoration") or not obj.managed_by_slab) then --these can be nuked if manually marked as props
		return true
	end
	return false
end

local distPen2dDelim = guim / 2
local distPenZDelim = guim
local function GetDistPenalty(dist2d, distZ)
	return dist2d / distPen2dDelim + distZ / distPenZDelim
end

Destroyable.__parents[1] = "GameDynamicDataObject"

---
--- Sets the dynamic data for a Destroyable object.
---
--- @param data table The dynamic data to set for the Destroyable object.
---   @field is_destroyed boolean Whether the Destroyable object is destroyed.
---
function Destroyable:SetDynamicData(data)
	self.is_destroyed = data.is_destroyed or false
	self:SetupFlags()
	if self.is_destroyed then
		KillAssociatedLights(self)
	end
end

---
--- Gets the dynamic data for a Destroyable object.
---
--- @param data table The table to store the dynamic data in.
---   @field is_destroyed boolean Whether the Destroyable object is destroyed.
---
function Destroyable:GetDynamicData(data)
	if self.is_destroyed then
		data.is_destroyed = self.is_destroyed
	end
end

---
--- Sets the dynamic data for a DestroyableSlab object.
---
--- @param data table The dynamic data to set for the DestroyableSlab object.
---   @field destroyed_neighbours integer The number of destroyed neighbouring slabs.
---   @field use_replace_ent_destruction boolean Whether to use replace entity destruction.
---
function DestroyableSlab:SetDynamicData(data)
	self.destroyed_neighbours = data.destroyed_neighbours or 0
	self.use_replace_ent_destruction = data.use_replace_ent_destruction or false
	if self.is_destroyed then
		self:SetDestroyedState(true)
	end
	if self.is_destroyed or self.destroyed_neighbours ~= 0 then
		self:DelayedUpdateEntity()
	end
end

---
--- Gets the dynamic data for a DestroyableSlab object.
---
--- @param data table The table to store the dynamic data in.
---   @field destroyed_neighbours integer The number of destroyed neighbouring slabs.
---   @field use_replace_ent_destruction boolean Whether to use replace entity destruction.
---
function DestroyableSlab:GetDynamicData(data)
	if self.destroyed_neighbours ~= 0 then
		data.destroyed_neighbours = self.destroyed_neighbours
	end
	if self.use_replace_ent_destruction then
		data.use_replace_ent_destruction = true
	end
end

local function CanCanvasEnterBrokenState(o)
	return not IsKindOf(o, "Canvas") or o:IsStaticAnim(GetStateIdx("broken")) == o:IsStaticAnim(GetStateIdx("idle"))
end

local function KillObj(o)
	if IsKindOfClasses(o, "ExplosiveObject", "ExplosiveContainer", "DynamicSpawnLandmine") then
		o:OnDie(g_Combat and g_Combat.active_unit)
	elseif IsKindOf(o, "CombatObject") then 
		DoneCombatObject(o) --this will skip fx but wont provoke another suspendpassedits
	else
		o:Destroy()
	end
end

---
--- Processes objects around destroyed slabs, destroying any objects that are touching the destroyed floor or wall/roof areas.
---
--- @param destroyedFloorBoxes table A table of bounding boxes for the destroyed floor areas.
--- @param destroyedFloorMap table A table mapping voxel positions to a boolean indicating if the voxel is destroyed.
--- @param destroyedWallBoxes table A table of bounding boxes for the destroyed wall areas.
--- @param destroyedRoofBoxes table A table of bounding boxes for the destroyed roof areas.
--- @param destroyedWallBoxesOnTop table A table of booleans indicating if the wall boxes are on top.
---
function ProcessObjectsAroundSlabs(destroyedFloorBoxes, destroyedFloorMap, destroyedWallBoxes, destroyedRoofBoxes, destroyedWallBoxesOnTop)
	if not DbgPropagateSlabDestructionInEditor and IsEditorActive() then
		return
	end
	--destroy objects on floors
	for i = 1, #destroyedFloorBoxes do
		local origb = destroyedFloorBoxes[i]
		local bcx, bcy, bcz = origb:Center():xyz()
		bcz = select(3, SnapToVoxel(bcx, bcy, bcz + const.SlabSizeZ / 2)) --figure out slabs z
		local testTouchingFloorBox = box(origb:min():AddZ(-const.SlabSizeZ), origb:max():AddZ(20))
		local queryb = Offset(origb:grow(voxelSizeX, voxelSizeY, voxelSizeZ * 3), point(0, 0, voxelSizeZ * 3/2)) --grow to catch hanging objects
		
		MapForEach(queryb, "CObject", const.efVisible, function(o)
			if ShouldDestroyObject(o) then
				local ob = o:GetObjectAttachesBBox()
				if ob:Intersect(testTouchingFloorBox) ~= const.irOutside then --it's probably on the floor, or below it
					local obsx, obsy, obsz = ob:size():xyz()
					local shouldDie = false

					--if obj box is 2 small to catch any voxels we check nearby voxels, else we check the ones in the box
					local traverseFunc = (obsx < voxelSizeX or obsy < voxelSizeY) and ForEachVoxelInBox2DExclusive or ForEachVoxelInBox2D
					traverseFunc(ob, function(x, y, z)
						if destroyedFloorMap[EncodeVoxelPos(x, y, z)] then
							--obj has at leas one dead floor below it
							shouldDie = true
							return "break"
						end
					end, bcz)
					
					if shouldDie then
						AddCarryOverData(o, "dist2d", distPen2dDelim)
						KillObj(o)
					end
				end
			end
		end)
	end
	
	local function filterRoof(o, dist2d, distZ, box, oBB)
		if ShouldDestroyObject(o) then
			AddCarryOverData(o, "dist2d", dist2d + distPen2dDelim, "distZ", distZ)
			return true
		end
		return false
	end
	--DbgClear()
	local function filterWall(o, dist2d, distZ, box, oBB, i)
		local kill = false
		if ShouldDestroyObject(o) then
			--DbgAddBox(box)
			--DbgAddBox(oBB)
			local m = o:GetMaterialPreset()
			local nb = IntersectRects(box, oBB)
			if nb == oBB then
				--completely inside a wall box, kill it
				kill = true
				goto destroy
			end
			local nbsz = nb:sizez()
			local bmz = box:maxz()
			if destroyedWallBoxesOnTop[i] then
				bmz = bmz - 200
			end
			local pos = o:GetPos()
			local oz
			if oBB:PointInside(pos) then
				oz = pos:z()
			else
				oz = oBB:Center():z()
			end
			local percFromSelf = MulDivRound(nbsz, 100, Max(oBB:sizez(), 1))
			local percFromVox = MulDivRound(nbsz, 100, voxelSizeZ)
			local isHorizontal = ((percFromVox > 50 or percFromSelf > 20) and (not oz or (bmz - oz) >= eightGuim))
			if isHorizontal and DbgDestruction_OnlyVerticalPropagation then
				return false
			end
			local isProp = m and m.is_prop
			if isHorizontal and not isProp then
				--if mat is not prop, obj instance could be marked as such
				isProp = IsObjPropDueToLDMark(o)
			end
			if DbgDestruction_WallAndObjPropatationOnlyAffectsProps and not isProp then
				return false
			end
			if not isHorizontal or isProp then
				--print(o.class, isHorizontal, percFromSelf, percFromVox)
				kill = true
			end
		end
		::destroy::
		if kill then
			AddCarryOverData(o, "dist2d", dist2d + distPen2dDelim, "distZ", distZ, "step", 1)
		end
		return kill
	end
	--destroy objs near walls that are not walldecs......
	local objsToKill
	if not DbgDestruction_DisableWallAndObjPropagation then
		objsToKill = FindDebrisObjectsToDestroy(destroyedWallBoxes, filterWall)
		for i, o in ipairs(objsToKill or empty_table) do
			KillObj(o)
		end
	end
	--destroy objs near roofs...
	objsToKill = FindDebrisObjectsToDestroy(destroyedRoofBoxes, filterRoof)
	for i, o in ipairs(objsToKill or empty_table) do
		KillObj(o)
	end
end

---------------------------------------------------------------------------
--new system, destroy everything, except units, slabs, markers and invulnerable combat material things
---------------------------------------------------------------------------
MapVar("Destruction_DestroyedObjects", {}) --> [handle] = true, [idx] = handle, ...
MapVar("Destruction_DestroyedCObjects", {}) --> [vis_obj_hash] = true, [idx] = vis_obj_hash, ...
local destroyedMask = const.efVisible | const.efCollision | const.efApplyToGrids
local GetVisualStateHashForDestroyedObj = rawget(_G, "GetVisualStateHashForDestroyedObj")

local function lLoadSavedTable(t1, t2)
	--load t2 into t1
	table.clear(t1)
	for i, v in ipairs(t2) do
		t1[i] = v
		t1[v] = true
	end
end

function OnMsg.LoadDynamicData(data)
	lLoadSavedTable(Destruction_DestroyedObjects, data.Destruction_DestroyedObjects)
	lLoadSavedTable(Destruction_DestroyedCObjects, data.Destruction_DestroyedCObjects)
	
	LoadSavedDestroyedObjects()
end

local function lCreateSaveTable(t)
	local tt
	if #t > 0 then
		tt = {}
		for i, h in ipairs(t) do
			tt[i] = h
		end
	end
	
	return tt
end

function OnMsg.SaveDynamicData(data)
	data.Destruction_DestroyedObjects = lCreateSaveTable(Destruction_DestroyedObjects)
	data.Destruction_DestroyedCObjects = lCreateSaveTable(Destruction_DestroyedCObjects)
end

---
--- Appends a destroyed object to the `DestroyedObjectsThisTick` table and wakes up the destruction post-processing.
---
--- This function is used to track objects that have been destroyed, but are not CombatObjects or Slabs. It is likely an implementation detail for the destruction system.
---
--- @param obj table The object that has been destroyed.
---
function AppendDestroyedObject(obj) --for generic objs that are not CombatObjects or Slabs
	table.insert(DestroyedObjectsThisTick, obj)
	WakeUpDestructionPP()
end

local xyGrowth = 50
---
--- Calculates the bounding box to use for a destroy query for the given object.
---
--- The bounding box is calculated based on the object's attached bounding box, with some additional growth and offset adjustments.
---
--- @param obj table The object to calculate the destroy query bounding box for.
--- @return table, table The calculated destroy query bounding box, and the original attached bounding box.
---
function GetDestroyQueryBoxForObj(obj)
	local bbox = obj:GetObjectAttachesBBox()
	local isLarge = Max(bbox:sizex(), bbox:sizey()) / voxelSizeX > 0
	local x, y, z = bbox:sizexyz()
	local growth = isLarge and string.find(obj:GetEntity(), "Dec") and 0 or xyGrowth
	return Offset(Resize(bbox, MulDivRound(x, 100 + growth, 100), MulDivRound(y, 100 + growth, 100), MulDivRound(z, 100,  85)),
							-MulDivRound(x, growth / 2, 100), -MulDivRound(y, growth / 2, 100), 25), bbox
end

---
--- Calculates the bounding box to use for a destroy query for the given object, with a specific adjustment for "hanging" objects.
---
--- The bounding box is calculated based on the object's attached bounding box, with some additional growth and offset adjustments. This version of the function applies a different adjustment for objects that may be "hanging" from the ceiling.
---
--- @param obj table The object to calculate the destroy query bounding box for.
--- @return table, table The calculated destroy query bounding box, and the original attached bounding box.
---
function GetDestroyQueryBoxForObj_HangingTest(obj)
	local bbox = obj:GetObjectAttachesBBox()
	local x, y, z = bbox:sizexyz()
	return Offset(bbox:grow(x / 2, y / 2, z / 2), 0, 0, z / 2 + 25), bbox
end

local particleTimeout = 33
MapVar("DestructionParticleGrid", false)
---
--- Determines whether destruction FX should be played for the given object.
---
--- This function checks a cache to see if destruction FX have been played for the given object's entity and material combination within the last `particleTimeout` milliseconds. If the FX have not been played recently, it updates the cache and returns `true` to indicate that the FX should be played.
---
--- @param obj table The object to check for destruction FX.
--- @return boolean `true` if destruction FX should be played for the given object, `false` otherwise.
---
function ShouldPlayDestructionFX(obj)
	local e = obj:GetEntity()
	local size = s_EntitySizeCache[e]
	local mat = GetObjMaterialFXTarget(obj)
	local tId = xxhash(size, mat)
	DestructionParticleGrid = DestructionParticleGrid or {}
	local t = DestructionParticleGrid[tId] or {}
	DestructionParticleGrid[tId] = t
	local voxId = xxhash(WorldToVoxel(obj:GetPos()))
	local ts = t[voxId] or -particleTimeout
	local now = GameTime()
	if now - ts >= particleTimeout then
		t[voxId] = now
		return true
	end
	return false
end

CObject.OnDestroy = empty_func

---
--- Destroys the object and performs associated cleanup tasks.
---
--- This function is called when an object is destroyed. It performs the following steps:
--- - Checks if the object is already invisible and has a parent. If so, it returns without further processing, assuming the parent object has already destroyed this object.
--- - Asserts that the object is visible and not already destroyed.
--- - Marks the object as being in the process of destruction.
--- - Appends the object to the list of destroyed objects.
--- - If destruction FX should be played for the object, it plays the destruction FX.
--- - Sets the object's hit points to 0 if it has the "HitPoints" member.
--- - Calls the object's "OnDestroy" function.
--- - Kills any associated lights.
--- - If the object has a "command" member, it sets the command to false, which will halt any command thread the object is running.
---
--- @param self CObject The object being destroyed.
---
function CObject:Destroy()
	if self:GetEnumFlags(const.efVisible) == 0 and self:GetParent() then
		return --presumably parrent got killed and nuked us, but we are a combat object and got hit as well
	end
	assert(self:GetEnumFlags(const.efVisible) ~= 0, "Invisible obj destroyed [" .. self.class .. "] is already destroyed [" .. tostring(IsGenericObjDestroyed(self)) .. "] is destruction in progress [" .. tostring(DestructionInProgressObjs[self] or false) .. "]")
	assert(not IsGenericObjDestroyed(self), "Object destroyed twice " .. self.class)
	DestructionInProgressObjs[self] = true
	AppendDestroyedObject(self)
	
	if ShouldPlayDestructionFX(self) then
		--TODO: time goes here 1
		self:PlayDestructionFX()
	end
	if self:HasMember("HitPoints") then
		self.HitPoints = 0
	end
	self:OnDestroy()
	KillAssociatedLights(self)
	if rawget(self, "command") then
		self:SetCommand(false) --this will halt if we are in command thread, so better be last, although no guarantees for caller
	end
end

---
--- Spreads debris from the object.
---
--- This function is a stub and does not currently have any implementation. It is likely intended to be overridden by derived classes to provide the actual debris spreading functionality.
---
--- @param self CObject The object that is spreading debris.
---
function CObject:SpreadDebris()
	--stub
end

--variable broken states
--http://mantis.haemimontgames.com/view.php?id=197033
--states are: broken, broken1, broken2, etc. with no clearly defined max; <- what it says in the bug; lets call this v1;
--states are: broken, broken2, broken3, etc.; <- reality; v2;
local brokenStateMax = 9
local brokenStateCache = {} --ent -> max

---
--- Clears the cache of maximum broken states for game objects.
--- This function should be called when the game data is reloaded, to ensure the cache is up-to-date.
---
function ClearBrokenStateCache()
	brokenStateCache = {}
end

function OnMsg.DataReloadDone()
	ClearBrokenStateCache()
end

---
--- Gets the maximum broken state for the given game object.
---
--- This function checks the cached maximum broken state for the given object. If the cache is empty, it iterates through the possible broken states and finds the highest one that the object has. The maximum broken state is then cached for future lookups.
---
--- @param obj CObject The game object to get the maximum broken state for.
--- @return integer The maximum broken state for the given object.
---
function GetMaxBrokenState(obj)
	local ent = obj:GetEntity()
	local max = brokenStateCache[ent]
	if not max then
		for i = brokenStateMax, 1, -1 do
			if obj:HasState(string.format("broken%d", i)) then
				max = i
				break
			end
		end
		assert(not max or not obj:HasState("broken1")) --state wont ever be hit
		max = max or 0
		--print(ent, max)
		brokenStateCache[ent] = max
	end
	return max
end

---
--- Gets the name of a broken state for an object.
---
--- @param num integer The number of the broken state, from 1 to `brokenStateMax`.
--- @return string The name of the broken state.
---
function GetBrokenStateName(num)
	assert(num >= 1 and num <= brokenStateMax)
	if num <= 1 then
		return "broken"
	else
		return string.format("broken%d", num)
	end
end

---
--- Computes the broken state for the given game object.
---
--- This function first gets the maximum broken state for the given object using `GetMaxBrokenState()`. It then generates a random broken state number between 1 and the maximum broken state, using the object's position as the seed. The function then constructs the name of the broken state using `GetBrokenStateName()` and asserts that the object has that broken state.
---
--- @param obj CObject The game object to compute the broken state for.
--- @return string The name of the computed broken state.
---
function ComputeBrokenStateForObj(obj)
	local max = GetMaxBrokenState(obj)
	local num = BraidRandom(xxhash(obj:GetPos()), max) + 1 --presumably it wont move anymore so use pos as seed; v2 range is [1 .. max];
	local state = GetBrokenStateName(num)
	assert(obj:HasState(state))
	--print(obj.class, state)
	return state
end

---
--- Checks if the given game object is on the ground.
---
--- This function first checks if the object's Z coordinate is invalid or zero, which indicates that the object is on the ground. If not, it retrieves the object's bounding box and checks if the terrain height at the object's X and Y coordinates is greater than or equal to the minimum Z coordinate of the bounding box, or if the difference between the terrain height and the minimum Z coordinate is less than a small threshold. If either of these conditions is true, the function returns `true`, indicating that the object is on the ground.
---
--- @param obj CObject The game object to check.
--- @return boolean `true` if the object is on the ground, `false` otherwise.
---
function IsOnGround(obj)
	local isOnGround
	local x, y, z = obj:GetPosXYZ()
	isOnGround = not z or z == const.InvalidZ
	if not isOnGround then
		local b = obj:GetObjectBBox()
		local th = terrain.GetHeight(x, y)
		if th >= b:minz() or abs(th - b:minz()) < guim / 10 then
			isOnGround = true
		end
	end
	return isOnGround
end

function OnMsg.DestructionPassDone()
	if g_Combat then 
		g_Combat.visibility_update_hash = false
	end
end

---
--- Checks if the given game object should be checked for network updates.
---
--- This function checks if the given game object has the "Essential" detail class. Objects with the "Essential" detail class are considered important for the game state and should be checked for network updates.
---
--- @param obj CObject The game object to check.
--- @return boolean `true` if the object should be checked for network updates, `false` otherwise.
---
function ShouldNetCheckObj(obj)
	--assert(obj:GetDetailClass() == "Essential" or (obj:GetEnumFlags(const.efApplyToGrids) == 0)) --non essential obj affecting passability
	return obj:GetDetailClass() == "Essential"
end

---
--- Sets up the destroyed state for the given game object.
---
--- This function is responsible for handling the destruction of a game object. It performs the following tasks:
---
--- 1. If the object is being destroyed, it checks if the object is on the ground and sets its state to a "broken" state using the `ComputeBrokenStateForObj` function.
--- 2. If the object is an explosive object, it creates a game time thread that waits 200 milliseconds before setting the object's state to the "broken" state.
--- 3. If the object is not on the ground, it kills any debris objects that are on top of the object's bounding box.
--- 4. It clears the object's destroyed mask and sets its collision mask to 0, effectively disabling the object's collision.
--- 5. It recursively applies the same changes to any attached objects.
--- 6. If the object is not being destroyed, it sets the object's destroyed mask and sets its state to "idle" if it was previously in the "broken" state.
---
--- @param destroyed boolean Whether the object is being destroyed or not.
--- @param spread_debris boolean Whether to spread debris when the object is destroyed.
--- @param dont_update_hash boolean Whether to skip updating the network hash for the object.
---
function CObject:SetupDestroyedState(destroyed, spread_debris, dont_update_hash)
	if destroyed then
		--[[if not dont_update_hash then
			dont_update_hash = not ShouldNetCheckObj(self)
		end]]
		
		if spread_debris then
			self:SpreadDebris()
		end
		--local oldState = self:GetStateText()
		local isOnGround
		local isExplosiveObject = IsKindOf(self, "ExplosiveObject")
	
		if self:GetEntity() ~= "" and (axis_z == self:GetAxis() or isExplosiveObject) 
			and self:HasState("broken") and CanCanvasEnterBrokenState(self) then
			--0164904
			isOnGround = IsOnGround(self)
			if isOnGround then
				local function setup(self)
					local s = ComputeBrokenStateForObj(self)
					self:SetState(s)
					--[[if not dont_update_hash then
						NetUpdateHash("Object:SetupDestroyedState_SetState", self:IsSyncObject() and self or self.class, self:GetPos(), self:GetAngle(), self:GetAxis(),
							oldState, s, self:GetStateText())
					end]]
				end
				if isExplosiveObject then
					CreateGameTimeThread(function()
						Sleep(200)
						if IsValid(self) then
							setup(self)
						end
					end)
					return
				end
				setup(self)
				return
			end
		end
		
		--kill debris on top of us
		local b = self:GetObjectBBox():grow(200, 200, 50) --debris that remain floating are generally to the side propped up on the extreme edge
		MapForEach(b, "Debris", 
			function(o)
				if o:IsFadingAway() then --done falling
					DoneObject(o)
				end
			end)
		
		self:ClearEnumFlags(destroyedMask)
		collision.SetAllowedMask(self, 0)
		self:ForEachAttach(function(attach)
			attach:ClearEnumFlags(destroyedMask)
			collision.SetAllowedMask(attach, 0)
		end)
		
		--[[if not dont_update_hash then
			NetUpdateHash("Object:SetupDestroyedState", self:IsSyncObject() and self or self.class, self:GetPos(), self:GetAngle(), self:GetAxis(),
							oldState, self:GetStateText())
		end]]
	else
		self:SetEnumFlags(destroyedMask)
		if self:GetStateText() == "broken" then
			self:SetState("idle")
		end
	end
end

--TwoPointsAttachParent optimization - grab children in member, so we dont have to mapget the entire map every time;
function OnMsg.ChangeMapDone()
	if GetMapName() == "" then return end
	if not mapdata.GameLogic then return end
	MapForEach("map", "TwoPointsAttach", function(obj)
		if IsValid(obj.obj1) then
			obj.obj1.children = obj.obj1.children or {}
			table.insert(obj.obj1.children, obj)
		end
		if IsValid(obj.obj2) then
			obj.obj2.children = obj.obj2.children or {}
			table.insert(obj.obj2.children, obj)
		end
	end)
end

AppendClass.TwoPointsAttachParent = {
	children = false
}

--- Removes the `children` table from the `TwoPointsAttachParent` object.
--- This function is called when the `TwoPointsAttachParent` object is destroyed.
--- The `children` table is used to keep track of the child `TwoPointsAttach` objects that are attached to this parent.
--- By setting the `children` table to `nil`, the object can be properly garbage collected.
function TwoPointsAttachParent:Done()
	self.children = nil
end

---
--- Sets the destroyed state of the `TwoPointsAttachParent` object and its child `TwoPointsAttach` objects.
---
--- @param destroyed boolean Whether the object is destroyed or not.
---
function TwoPointsAttachParent:SetupDestroyedState(destroyed)
	CObject.SetupDestroyedState(self, destroyed)
	if self.children then
		for i, c in ipairs(self.children) do
			c:SetupDestroyedState(destroyed)
		end
	else
		--vry time consuming, for destruction during map load when cache doesn't exist
		MapForEach("map", "TwoPointsAttach", function(obj, destroyed) 
			if obj.obj1 == self or obj.obj2 == self then
				obj:SetupDestroyedState(destroyed)
			end
		end, destroyed)
	end
end

--TwoPointsAttachParent editor filter hides wires impl.
---
--- Updates the visibility state of the child `TwoPointsAttach` objects based on the solid shadow state of their parent `TwoPointsAttachParent` object.
---
--- This function is called when the solid shadow state of the parent object changes, either due to the editor hiding or showing the object.
---
--- If the parent object has the solid shadow flag set, the function will hide any child `TwoPointsAttach` objects where either the first or second object is not valid or also has the solid shadow flag set.
---
--- If the parent object does not have the solid shadow flag set, the function will show all child `TwoPointsAttach` objects.
---
--- @param flags number The game object flags of the parent `TwoPointsAttachParent` object.
---
function TwoPointsAttachParent:UpdateChildrenStateFromSolidShadow(flags)
	if IsEditorActive() then
		if band(const.gofSolidShadow, flags) ~= 0 then
			--editor is hiding or showing us
			for i, c in ipairs(self.children) do
				if (not IsValid(c.obj1) or c.obj1:GetGameFlags(const.gofSolidShadow) ~= 0) or
					(not IsValid(c.obj2) or c.obj2:GetGameFlags(const.gofSolidShadow) ~= 0) then
					c:SetVisible(false)
				else
					c:SetVisible(true)
				end
			end
		end
	end
end

---
--- Clears the game object flags of the `TwoPointsAttachParent` object and its child `TwoPointsAttach` objects.
---
--- This function is called when the game object flags of the `TwoPointsAttachParent` object need to be cleared, such as when the object is being destroyed or hidden.
---
--- The function first calls the `ClearHierarchyGameFlags` function of the `CObject` class to clear the game object flags of the `TwoPointsAttachParent` object itself. It then calls the `UpdateChildrenStateFromSolidShadow` function to update the visibility state of the child `TwoPointsAttach` objects based on the new game object flags of the parent object.
---
--- @param flags number The game object flags to be cleared.
---
function TwoPointsAttachParent:ClearHierarchyGameFlags(flags)
	CObject.ClearHierarchyGameFlags(self, flags)
	self:UpdateChildrenStateFromSolidShadow(flags)
end

---
--- Updates the game object flags of the `TwoPointsAttachParent` object and its child `TwoPointsAttach` objects.
---
--- This function is called when the game object flags of the `TwoPointsAttachParent` object need to be updated, such as when the object is being shown or hidden.
---
--- The function first calls the `SetHierarchyGameFlags` function of the `CObject` class to update the game object flags of the `TwoPointsAttachParent` object itself. It then calls the `UpdateChildrenStateFromSolidShadow` function to update the visibility state of the child `TwoPointsAttach` objects based on the new game object flags of the parent object.
---
--- @param flags number The new game object flags to be set.
---
function TwoPointsAttachParent:SetHierarchyGameFlags(flags)
	CObject.SetHierarchyGameFlags(self, flags)
	self:UpdateChildrenStateFromSolidShadow(flags)
end

--TwoPointsAttachParent hides wires in game when parent gets hidden, also pops up wires when turning off hiding;
---
--- Sets the shadow-only state of the `TwoPointsAttachParent` object and its child `TwoPointsAttach` objects.
---
--- If the `g_CMTPaused` global variable is true, this function will return without doing anything.
---
--- The function first calls the `SetShadowOnly` function of the `CObject` class to set the shadow-only state of the `TwoPointsAttachParent` object itself. It then iterates over the child `TwoPointsAttach` objects and sets their visibility based on the visibility of their attached objects (`obj1` and `obj2`). If either of the attached objects is not valid or not visible, the child `TwoPointsAttach` object is set to be invisible. Otherwise, it is set to be visible.
---
--- @param bSet boolean Whether to set the shadow-only state to true or false.
---
function TwoPointsAttachParent:SetShadowOnly(bSet)
	if g_CMTPaused then return end
	CObject.SetShadowOnly(self, bSet)
		
	for i, c in ipairs(self.children) do
		if (not IsValid(c.obj1) or not CMT_IsObjVisible(c.obj1)) or 
			(not IsValid(c.obj2) or not CMT_IsObjVisible(c.obj2)) then
			c:SetVisible(false)
		else
			c:SetVisible(true)
		end
	end
end

TwoPointsAttachParent.SetShadowOnlyImmediate = TwoPointsAttachParent.SetShadowOnly

---
--- Sets the visibility of the `TwoPointsAttach` object based on whether it is in a destroyed state.
---
--- @param destroyed boolean Whether the `TwoPointsAttach` object is in a destroyed state.
---
function TwoPointsAttach:SetupDestroyedState(destroyed)
	self:SetVisible(not destroyed)
end

---
--- Checks if the game object is invulnerable.
---
--- The function first checks if the object is vulnerable due to an LD mark. If it is, the function returns `false`.
---
--- If the object is temporarily invulnerable, the function returns `true`.
---
--- If the object has a material preset and the preset indicates that the object is invulnerable, the function returns `true`.
---
--- Otherwise, the function checks if the object is invulnerable due to an LD mark and returns the result.
---
--- @return boolean true if the object is invulnerable, false otherwise
---
function CObject:IsInvulnerable()
	if IsObjVulnerableDueToLDMark(self) then
		return false
	end
	if TemporarilyInvulnerableObjs[self] then
		return true
	end
	local p = self:GetMaterialPreset()
	if p and p.invulnerable then
		return true
	end
	return IsObjInvulnerableDueToLDMark(self)
end

local materials = table.get(Presets, "ObjMaterial", "Default")

---
--- Gets the material preset for the current object.
---
--- If the material type ID is set on the object, the function returns the corresponding material preset from the `Presets.ObjMaterial` table. If the material type ID is not set, the function returns `false`.
---
--- @return table|false The material preset for the current object, or `false` if the material type ID is not set.
---
function CObject:GetMaterialPreset()
	materials = materials or table.get(Presets, "ObjMaterial", "Default")
	local id = self:GetMaterialType()
	if id then
		return materials and materials[id]
	end
	
	return false
end

---
--- Checks if the current object has a material preset that indicates it is a prop.
---
--- @return boolean true if the object has a material preset and the preset indicates it is a prop, false otherwise
---
function CObject:IsPropMaterial()
	local preset = self:GetMaterialPreset()
	return preset and preset.is_prop or false
end

---
--- Gets the destruction propagation properties for the current object.
---
--- @return number, boolean, boolean The destruction propagation strength, whether the object is invulnerable, and whether the object is a prop.
---
function CObject:GetDestructionPorpagationProps()
	local preset = self:GetMaterialPreset()
	return preset and preset.destruction_propagation_strength or 0, 
				preset and preset.invulnerable or false, preset and preset.is_prop or false
end

---
--- Displays a debug box representing the destroy query box for the object returned by the `selo()` function.
---
--- This function is likely used for debugging purposes, to visually inspect the destroy query box for a specific object.
---
--- @function DbgShowMeSeloDestroyQBox
--- @return nil
function DbgShowMeSeloDestroyQBox()
	local dqb, bb = GetDestroyQueryBoxForObj(selo())
	DbgAddBox(dqb)
end

---
--- Displays a debug box representing the destroy query box for the object returned by the `selo()` function.
---
--- This function is likely used for debugging purposes, to visually inspect the destroy query box for a specific object.
---
--- @function DbgShowMeSeloDestroyQBox_H
--- @return nil
function DbgShowMeSeloDestroyQBox_H()
	local dqb, bb = GetDestroyQueryBoxForObj_HangingTest(selo())
	DbgAddBox(dqb)
end

---
--- Processes destroyed generic objects for the current tick.
---
--- This function is responsible for handling the cleanup and cascading destruction of objects that have been destroyed in the current tick.
---
--- It iterates through the list of destroyed objects, marking them as destroyed in the appropriate data structures, and then checks if the object should trigger any cascading destruction effects.
---
--- If the object is marked as "Essential" and cascading destruction is not disabled, the function will call `GetCascadeDestroyObjects` to find and destroy any additional objects that should be affected by the destruction of the original object.
---
--- @function ProcessDestroyedGenericObjectsThisTick
--- @return nil
function ProcessDestroyedGenericObjectsThisTick()
	if #DestroyedObjectsThisTick <= 0 then
		return
	end
	local pos_cache = {}
	while #DestroyedObjectsThisTick > 0 do
		local t = DestroyedObjectsThisTick
		DestroyedObjectsThisTick = {}
		for i, obj in ipairs(t) do
			local h = rawget(obj, "handle")
			if h then
				Destruction_DestroyedObjects[h] = true
				table.insert(Destruction_DestroyedObjects, h)
			else
				h = GetVisualStateHashForDestroyedObj(obj)
				Destruction_DestroyedCObjects[h] = true
				table.insert(Destruction_DestroyedCObjects, h)
			end
			local cascadeDestruction = not DbgDestruction_DisableWallAndObjPropagation and not obj:IsGrassOrShrub() and obj:GetDetailClass() == "Essential"
			local dqb, bb
			if cascadeDestruction then
				dqb, bb = GetDestroyQueryBoxForObj(obj) --if we switch ent states on brake, this box will be different.
			end
			obj:SetupDestroyedState(true, "spread_debris")
			DestructionInProgressObjs[obj] = nil
			if cascadeDestruction then --no cascade from grass n shrub
				local cascadeDestroyed
					cascadeDestroyed = GetCascadeDestroyObjects(obj, pos_cache, dqb, bb)
					--cascadeDestroyed = C_GetCascadeDestroyObjects(obj, dqb, bb)
				for j, cascadeObj in ipairs(cascadeDestroyed or empty_table) do
					KillObj(cascadeObj)
				end
			end
			DestructionInProgressObjsCarryOverData[obj] = nil
		end
	end
end

local bbox_ignore_classes = {"Light", "AutoAttachSIModulator"}

---
--- Finds and returns a list of objects that should be destroyed as a result of the destruction of the given object.
---
--- This function first checks if cascading destruction is disabled. If so, it returns without doing anything.
---
--- It then calculates the bounding box and position of the given object, and uses that information to find other objects that are within the destruction propagation range of the given object. It checks various conditions to determine if an object should be destroyed, such as its destruction propagation properties, its position relative to the given object, and whether it is a prop object.
---
--- The function returns a list of objects that should be destroyed as a result of the destruction of the given object.
---
--- @param obj The object whose destruction should trigger the destruction of other objects.
--- @param pos_cache A cache of object positions and bounding boxes.
--- @param dqb The destruction query box for the given object.
--- @param bb The bounding box of the given object.
--- @return A list of objects that should be destroyed as a result of the destruction of the given object.
---
function GetCascadeDestroyObjects(obj, pos_cache, dqb, bb)
	if DbgDestruction_DisableWallAndObjPropagation then
		return
	end
	pos_cache = pos_cache or {}
	local function getPosFromCache(obj, box)
		local b = pos_cache[obj]
		if not b then
			box = box or obj:GetObjectAttachesBBox(bbox_ignore_classes)
			pos_cache[obj] = box
			b = box
		end
		return b:Center(), b
	end

	if not dqb then
		dqb, bb = GetDestroyQueryBoxForObj(obj) --if we switch ent states on brake, this box will be different.
	end
	--find more objs to destroy
	local ds = obj:GetDestructionPorpagationProps()
	local cod = DestructionInProgressObjsCarryOverData[obj]
	local dist2d = 0
	local distZ = 0
	local step = 0
	if cod then
		dist2d = cod.dist2d or 0
		distZ = cod.distZ or 0
		step = cod.step or 0
	end

	local distPenalty = GetDistPenalty(dist2d, distZ)
	local dsp = ds - distPenalty
	local myPos = getPosFromCache(obj, bb)

	local objects = FindDebrisObjectsToDestroy(dqb, function(o, toHim2d, toHimZ, box, oBB) --these are measured from dqb center
		if o == obj or not ShouldDestroyObject(o) then
			return false
		end

		local hisDs, invulnerable, is_prop = o:GetDestructionPorpagationProps()
		if not is_prop then
			--if mat is not prop, obj instance could be marked as such
			is_prop = IsObjPropDueToLDMark(o)
		end
		local hisPos, hisBox = getPosFromCache(o)
		local toHim = hisPos - myPos
		local toHimZOrigins = toHim:z()
		local toHimZOriginsAbs = abs(toHimZOrigins)
		local toHimLen2D = toHim:Len2D()
		local myBMinZ = bb:minz()
		local myBMaxZ = bb:maxz()
		local hisBMaxZ = hisBox:maxz()
		local hisBMinZ = hisBox:minz()
		local myZ = myPos:z()
		local hisZ = hisPos:z()
		local isHorizontalPropagation = (toHimZOriginsAbs < eightGuim or (toHimLen2D > halfGuim / 2 and 
																										(hisBMaxZ > myZ and hisBMinZ < myZ or
																										myBMaxZ > hisZ and myBMinZ < hisZ)))

		if isHorizontalPropagation then
			if bb:Intersect2D(oBB) == const.irInside then
				isHorizontalPropagation = false --if completely inside, consider it vertical and kill it;
			elseif (o:GetPos() - obj:GetPos()):Len2() < 27225 then
				isHorizontalPropagation = false --hack. consider objs whos origin is very close to one another as vertical for more killing;
			end
		end

		if isHorizontalPropagation and (step > 0 or not is_prop) then
			return false
		end
		
		if not isHorizontalPropagation then
			if not is_prop and toHimZOrigins < 0 and hisBMinZ < myBMinZ then
				--obj is 2 far below me (baskets killing adjacent tables that are slightly taller than the table the baskets are on)
				return false
			end
		end
		
		if isHorizontalPropagation and DbgDestruction_OnlyVerticalPropagationObjsOnly then
			return false
		end
		
		if isHorizontalPropagation and DbgDestruction_OnlyVerticalPropagation then
			return false
		end
		
		if DbgDestruction_WallAndObjPropatationOnlyAffectsProps and not is_prop then
			return false
		end

		local myDs = dsp

		if ds > 0 then
			if (toHimLen2D <= halfGuim or (not isHorizontalPropagation and bb:Point2DInsideInclusive(hisPos))) then
				myDs = ds --no penalty when directly above and mat str > 0
			end
		end

		if myDs >= hisDs then
			AddCarryOverData(o, "dist2d", toHim2d + dist2d, "distZ", toHimZ + distZ, "step", step + (isHorizontalPropagation and 1 or 0))
			return true
		end
		return false
	end)
	return objects
end

---
--- Iterates through all CObject instances in the "map" and checks for collisions in the visual state hash.
--- This function is likely used for debugging purposes to identify any potential hash collisions.
---
--- @param none
--- @return none
---
function testHashing()
	local data = {}
	MapForEach("map", "CObject", function(o)
		if not IsKindOf(o, "Object") then
			local h = GetVisualStateHashForDestroyedObj(o)
			if data[h] then
				print("collision", o.class, data[h].class)
			end
			data[h] = o
		end
	end)
end

---
--- Checks if the given object is destroyed.
---
--- @param obj CObject|Object The object to check
--- @return boolean True if the object is destroyed, false otherwise
---
function IsGenericObjDestroyed(obj)
	local h = rawget(obj, "handle")
	return h and Destruction_DestroyedObjects[h] or 
				not h and Destruction_DestroyedCObjects[GetVisualStateHashForDestroyedObj(obj)]
end

---
--- Checks if the given object is destroyed.
---
--- @param obj CObject|Object The object to check
--- @return boolean True if the object is destroyed, false otherwise
---
function IsObjectDestroyed(obj)
	return obj.is_destroyed or IsGenericObjDestroyed(obj)
end

local function RemoveInvalidDestroyedObjects(objects)
	for i = #objects, 1, -1 do
		local handle = objects[i]
		if not HandleToObject[handle] then
			objects[handle] = nil
			table.remove(objects, i)
		end
	end
end

---
--- Loads and restores any saved destroyed objects in the game.
---
--- This function is responsible for iterating through all the CObjects in the map and
--- setting up the destroyed state for any objects that were previously destroyed.
--- It also kills any associated lights for the destroyed objects.
---
--- The function first checks if there are any destroyed objects in the
--- `Destruction_DestroyedCObjects` and `Destruction_DestroyedObjects` tables. If not,
--- it returns early.
---
--- It then iterates through all the CObjects in the map, checking if each object is
--- destroyed using the `IsGenericObjDestroyed` function. If the object is destroyed,
--- it calls the `SetupDestroyedState` method on the object to set it up in the
--- destroyed state, and also calls the `KillAssociatedLights` function to kill any
--- associated lights.
---
--- The function keeps track of the total number of destroyed objects and the current
--- count, and breaks out of the loop once the count reaches the total.
---
--- Finally, the function calls the `RemoveInvalidDestroyedObjects` function to
--- remove any invalid destroyed objects from the `Destruction_DestroyedObjects`
--- table.
---
--- @return none
---
function LoadSavedDestroyedObjects()
	if not next(Destruction_DestroyedCObjects) and not next(Destruction_DestroyedObjects) then
		return
	end
	local total = #Destruction_DestroyedObjects + #Destruction_DestroyedCObjects
	local count = 0
	MapForEach("map", "CObject", const.efVisible, function(o, IsGenericObjDestroyed, total)
		if IsGenericObjDestroyed(o) then
			o:SetupDestroyedState(true)
			KillAssociatedLights(o)
			count = count + 1

			if count >= total then
				return "break"
			end
		end
	end, IsGenericObjDestroyed, total)
	--print(count, total)
	RemoveInvalidDestroyedObjects(Destruction_DestroyedObjects)
	--RemoveInvalidDestroyedObjects(Destruction_DestroyedCObjects)
end

function OnMsg.GameExitEditor()
	SuspendPassEdits("GameExitEditor_HideDestroyedObjs")
	MapForEach("map", "CObject", function(o)
		if IsGenericObjDestroyed(o) then
			o:SetupDestroyedState(true, nil, "dont_update_hash")
		end
	end)
	ResumePassEdits("GameExitEditor_HideDestroyedObjs")
end

function OnMsg.GameEnterEditor()
	SuspendPassEdits("GameEnterEditor_ShowDestroyedObjs")
	MapForEach("map", "CObject", function(o)
		if IsGenericObjDestroyed(o) then
			o:SetupDestroyedState(false, nil, "dont_update_hash")
		end
	end)
	ResumePassEdits("GameEnterEditor_ShowDestroyedObjs")
end

function OnMsg.SetObjectDetail(action, params)
	if action == "done" then
		local editor = IsEditorActive()
		MapForEach("map", "CObject", const.efVisible, function(obj, IsGenericObjDestroyed, editor)
			if IsGenericObjDestroyed(obj) then
				obj:SetupDestroyedState(not editor, nil, "dont_update_hash")
			end
		end, IsGenericObjDestroyed, editor)
	end
end
---------------------------------------------------------------------------
--editor stuff
---------------------------------------------------------------------------
--TODO: diag ents..
--1 how to manipulate them
if FirstLoad then
	DestroyedAttachSelectionEnabled = false
end
MapVar("SelectedDestroyedAttaches", false)

local function RestoreDestroyedAttach(o)
	if o then
		if not o.parent then
			print("<color 255 0 0>SelectedDestroyedAttach has no parent!</color>")
			return
		end
		o.parent:Attach(o)
		o:SetAttachOffset(o.offset)
		o:SetAttachAngle(o.angle)
		o:SetMirrored(o.mirror)
		o.offset = nil
		o.angle = nil
		o.parent = nil
		o.mirror = nil
	end
end

local function RestoreDestroyedAttaches()
	if SelectedDestroyedAttaches then
		SuspendPassEdits("RestoreDestroyedAttaches")
		for _, att in ipairs(SelectedDestroyedAttaches) do
			RestoreDestroyedAttach(att)
		end
		SelectedDestroyedAttaches = false
		ResumePassEdits("RestoreDestroyedAttaches")
	end
end

local function SetSelectedDestroyedAttach(attach)
	local slab = attach:GetParent()
	if not slab then
		assert(attach.parent)
		return
	end
	attach.parent = slab
	attach.offset = attach:GetAttachOffset()
	attach.angle = attach:GetAttachAngle()
	attach.mirror = attach:GetMirrored()
	local pos = attach:GetVisualPos()
	local angle = attach:GetAngle()
	local mirror = slab:GetMirrored() and attach.angle > 0 or not slab:GetMirrored() and attach.mirror
	attach:Detach()
	attach:SetPosAngle(pos, angle)
	attach:SetMirrored(mirror)
end

---
--- Toggles the destroyed attach selection mode.
---
--- When the selection mode is enabled, the user can select destroyed attachments in the editor.
--- When the selection mode is disabled, any selected destroyed attachments are restored to their original position.
---
--- The current state of the selection mode is printed to the console.
---
function ToggleDestroyedAttachSelectionMode()
	if DestroyedAttachSelectionEnabled then
		RestoreDestroyedAttaches()
	end
	DestroyedAttachSelectionEnabled = not DestroyedAttachSelectionEnabled
	print("Destroyed Attach Selection is " .. (DestroyedAttachSelectionEnabled and "ON" or "OFF"))
end

local fiddlingWithSelection = false
function OnMsg.EditorSelectionChanged(objects)
	if not DestroyedAttachSelectionEnabled then return end
	if fiddlingWithSelection then return end
	
	local attaches = false
	local attach = false
	if objects then
		for i = 1, #objects do
			local obj = objects[i]
			if IsKindOf(obj, "DestroyableSlab") and obj.is_destroyed then
				local cp = GetCursorPos()
				local ptCamera, ptCameraLookAt = GetCamera()
				attach = GetNextObjectAtScreenPos(function(o) return IsKindOf(o, "DestroyedSlabAttach") end)
				if not attach then
					local atts = objects[1]:GetAttaches("DestroyedSlabAttach")
					
					for i = 1, #(atts or "") do
						if not attach then
							attach = atts[i]
						else
							local b1 = attach:GetObjectBBox()
							local b2 = atts[i]:GetObjectBBox()
							local c1, c2 = b1:Center(), b2:Center()
							if IsCloser(cp, c2, c1) then
								attach = atts[i]
							end
						end
					end
				end
			elseif IsKindOf(obj, "DestroyedSlabAttach") then
				attach = obj
			end
			
			if attach then
				attaches = attaches or {}
				table.insert(attaches, attach)
			end
		end
	end
	
	if not SelectedDestroyedAttaches and not attaches then return end
	
	SuspendPassEdits("DestroyedAttachSelectionEnabled")
	for _, att in ipairs(SelectedDestroyedAttaches or empty_table) do
		if not attaches or not table.find(attaches, att) then
			RestoreDestroyedAttach(att)
		end
	end
	
	if attaches then
		fiddlingWithSelection = true
		editor.ClearSel()
		for i = #attaches, 1, -1 do
			if not SelectedDestroyedAttaches or not table.find(SelectedDestroyedAttaches, attaches[i]) then
				SetSelectedDestroyedAttach(attaches[i])
			end
		end
		editor.SetSel(attaches)
		fiddlingWithSelection = false
		SelectedDestroyedAttaches = attaches
	else
		SelectedDestroyedAttaches = false
	end
	
	ResumePassEdits("DestroyedAttachSelectionEnabled")
end

---
--- Gets the neighboring wall slab for a destroyed attach.
---
--- @param o DestroyedSlabAttach The destroyed attach object.
--- @return WallSlab|nil The neighboring wall slab, or nil if not found.
---
function SelectedDestroyedAttach_GetNeighbourWallSlab(o)
	local p = o.parent
	local s = o:GetSide()
	
	if IsKindOfClasses(p, "DestroyableFloorSlab", "RoofPlaneSlab") then
		return p:GetNeighbour(s)
	else
		local pos = p:GetRelativePoint(o.offset)
		local dir = slabAngleToDir[p:GetAngle()]
	
		if SlabNeighbourMask.Left == s then
			local offs = wallSidewaysOffsets[dir]
			pos = pos + point(offs.x * voxelSizeX, offs.y * voxelSizeY, 0)
		elseif SlabNeighbourMask.Right == s then
			local offs = wallSidewaysOffsets[dir]
			pos = pos - point(offs.x * voxelSizeX, offs.y * voxelSizeY, 0)
		elseif SlabNeighbourMask.Top == s then
			pos = pos + point(0, 0, voxelSizeZ)
		else -- bot
			pos = pos - point(0, 0, voxelSizeZ)
		end
		
		return MapGet(pos, 0, "WallSlab", nil, const.efVisible)
	end
end

---
--- Handles the deletion of a destroyed attach object.
---
--- @param o DestroyedSlabAttach The destroyed attach object that was deleted.
--- @return boolean True if the deleted attach was part of the selected destroyed attaches, false otherwise.
---
function OnDestroyedAttachDeleted(o)
	if SelectedDestroyedAttaches and table.find(SelectedDestroyedAttaches, o) then
		SuspendPassEdits("OnDestroyedAttachDeleted")
		local nbrs = SelectedDestroyedAttach_GetNeighbourWallSlab(o)
		local id = o:GetId()
		local p = o.parent
		local sideFlag = o:GetSide()
		if nbrs then
			nbrs = IsValid(nbrs) and {nbrs} or nbrs
			for _, nbr in ipairs(nbrs) do
				if nbr and not nbr.is_destroyed then
					nbr:Repair()
					nbr.force_destroyed_entity = GetNeigbhourSideFlagTowardMe(sideFlag, nbr, p)
					nbr.force_no_destroyed_entity = false
					nbr:UpdateDestroyedState()
				end
			end
		end
		
		p.da_subvariants = p.da_subvariants or {}
		p.da_subvariants[id] = 0
		
		table.remove_entry(SelectedDestroyedAttaches, o)
		if #SelectedDestroyedAttaches <= 0 then
			SelectedDestroyedAttaches = false
		end
		
		if IsKindOf(p, "RoofWallSlab") then
			--check for stacked slabs and fix their attaches as well
			local lst = MapGet(p, 0, "RoofWallSlab")
			for _, slab in ipairs(lst) do
				if slab ~= p then
					local da = slab.destroyed_attaches
					local sf = ((sideFlag & 12) == 0) or p:GetAngle() == slab:GetAngle() and sideFlag or maskToOppositeMask[sideFlag]
					local att = da[maskToString[sf] ]
					if att then
						slab:DestroyDestroyedAttach(sf)
						slab.da_subvariants = slab.da_subvariants or {}
						slab.da_subvariants[att:GetId()] = 0
					end
				end
			end
		end
		ResumePassEdits("OnDestroyedAttachDeleted")
		return true
	end
	return false
end

function OnMsg.EditorCallback(id, objs)
	if not SelectedDestroyedAttaches then return end
	if id == "EditorCallbackDelete" then
		for i = 1, #objs do
			local o = objs[i]
			if OnDestroyedAttachDeleted(o) then
				return
			end
		end
	end
end

local preSaveAttach = false
function OnMsg.PreSaveMap()
	if not SelectedDestroyedAttaches then return end
	preSaveAttach = SelectedDestroyedAttaches
	RestoreDestroyedAttaches()
	SelectedDestroyedAttaches = false
end

function OnMsg.PostSaveMap()
	if preSaveAttach then
		for _, att in ipairs(preSaveAttach) do
			SetSelectedDestroyedAttach(att)
		end
		SelectedDestroyedAttaches = preSaveAttach
		editor.SetSel({SelectedDestroyedAttaches})
		preSaveAttach = false
	end
end

if Platform.developer then
DefineClass.DestroyedSlabMarker = {
	__parents = { "EditorVisibleObject" },
	flags = { gofPermanent = false },
	entity = "DestroyedSlab",
	slab = false,
}

local ignoreSelectionChangedMsg = false
function OnMsg.EditorSelectionChanged(objects)
	if ignoreSelectionChangedMsg then return end
	local markers = false
	local slabs = false
	for i = 1, #(objects or "") do 
		local o = objects[i]
		if IsKindOf(o, "DestroyedSlabMarker") then
			markers = markers or {}
			slabs = slabs or {}
			table.insert(markers, o)
			if IsValid(o.slab) then
				table.insert(slabs, o.slab)
				--update pos/angle, this is the only update hook for this, could be kinda wooden when destroyed slabs are moved, which they shouldn't be.
				o:SetPosAngle(o.slab:GetPos(), o.slab:GetAngle())
			end
		end
	end
	ignoreSelectionChangedMsg = true
	--print("selected markers ", #(markers or ""), "slabs to sel ", #(slabs or ""))
	if markers then
		editor.RemoveFromSel(markers)
	end
	if slabs then
		editor.AddToSel(slabs)
	end
	ignoreSelectionChangedMsg = false
end

function OnMsg.ChangeMapDone(map)
	if map == "" then return end
	MapForEach("map", "DestroyableSlab", const.efVisible, function(s)
		if s.is_destroyed then
			s:ManageSelectionMarker(true)
		end
	end)
end

--- Removes the selection marker associated with this DestroyableSlab object.
---
--- This function is called when the DestroyableSlab is being destroyed or removed from the game.
--- It ensures that any selection marker created for this slab is also removed.
function DestroyableSlab:Done()
	self:ManageSelectionMarker(false)
end

---
--- Manages the selection marker associated with this DestroyableSlab object.
---
--- This function is responsible for creating or removing the selection marker for a DestroyableSlab object.
---
--- @param create boolean Whether to create or remove the selection marker.
---
function DestroyableSlab:ManageSelectionMarker(create)
	if create then
		local m = PlaceObject("DestroyedSlabMarker", {slab = self})
		self.selection_marker = m
		m:SetPosAngle(self:GetPos(), self:GetAngle())
		XEditorFilters:UpdateObject(m)
		if IsEditorActive() and not XEditorFilters:IsObjectHidden(m) then
			m:SetEnumFlags(const.efVisible)
		else
			m:ClearEnumFlags(const.efVisible)
		end
	else
		if IsValid(self.selection_marker) then
			DoneObject(self.selection_marker)
		end
		self.selection_marker = false
	end
end

-----------------------------------------------
--more editor stuff, color code invulnerability
-----------------------------------------------
local InvulnerableSlabOwned = RGBA(0, 0, 255, 0)
local InvulnerableSlabUnowned = RGBA(255, 0, 255, 0)
local InvulnerableObjDueToMaterial = RGBA(255, 0, 0, 0)
local InvulnerableObjDueToLDMark = RGBA(70, 0, 255, 0)
local InvulnerableObjDueToInteractables = RGBA(175, 0, 255, 0)

local MaterialStrengthRanges = {
	[1] = 10,
	[2] = 15,
	[3] = 30,
	[4] = 9999,
}

local MaterialStrengthColors = {
	[1] = RGBA(0, 255, 0, 0),
	[2] = RGBA(255, 255, 0, 0),
	[3] = RGBA(255, 150, 0, 0),
	[4] = RGBA(255, 70, 0, 0),
}

---
--- Prints a legend for the various colors used to indicate the invulnerability and material strength of destroyable objects in the editor.
---
--- The legend includes the following colors and their meanings:
--- - InvulnerableSlabOwned: Invulnerable slab that is part of a room
--- - InvulnerableSlabUnowned: Invulnerable slab that is not part of a room
--- - InvulnerableObjDueToMaterial: Invulnerable object due to its material
--- - InvulnerableObjDueToLDMark: Invulnerable object due to an LD mark
--- - InvulnerableObjDueToInteractables: Invulnerable object due to interactables
--- - Vulnerable non slab objects: Material strength ranges from 0 to the maximum value
---
function PrintDestroyableOverlayLegend()
	local function helper(color, name)
		local r, g, b = GetRGB(color)
		return string.format("<color %d %d %d>%s\n</color>", r, g, b, name)
	end
	local s = ""
	s = s .. helper(InvulnerableSlabOwned, "InvulnerableSlabOwned (part of room)")
	s = s .. helper(InvulnerableSlabUnowned, "InvulnerableSlabUnowned (not part of room)")
	s = s .. helper(InvulnerableObjDueToMaterial, "InvulnerableObjDueToMaterial")
	s = s .. helper(InvulnerableObjDueToLDMark, "InvulnerableObjDueToLDMark")
	s = s .. helper(InvulnerableObjDueToInteractables, "InvulnerableObjDueToInteractables")
	local str = 0
	for i = 1, #MaterialStrengthRanges do
		s = s .. helper(MaterialStrengthColors[i], "Vulnerable non slab objects; Material Strength: " .. tostring(str) .. "-" .. tostring(MaterialStrengthRanges[i]))
		str = MaterialStrengthRanges[i] + 1
	end
	print(s)
end

local function StrengthToColor(str)
	for i = 1, #MaterialStrengthRanges do
		if str <= MaterialStrengthRanges[i] then
			return MaterialStrengthColors[i]
		end
	end
end

MapVar("InvulnerabilityPainted", false)
MapVar("MarkInvulnerableObjectsData", false)

function OnMsg.EditorPreSerialize()
	ClearInvulnerableMarking("keep_data")
end

function OnMsg.EditorPostSerialize()
	if InvulnerabilityPainted then
		local old_colors = table.copy(MarkInvulnerableObjectsData)
		MarkInvulnerableObjectsData = {}
		for obj, col in pairs(old_colors) do
			if IsValid(obj) then
				MarkInvulnerableObject(obj, col)
			end
		end
	end
end

function OnMsg.EditorCallback(callback, objects)
	if InvulnerabilityPainted and callback == "EditorCallbackPlace" then
		for _, obj in ipairs(objects) do
			SetupObjInvulnerabilityColorMarking(obj)
		end
	end
end

---
--- Marks an object as invulnerable by setting its color modifier to the specified color.
---
--- @param o table The object to mark as invulnerable.
--- @param col table The color modifier to apply to the object.
---
function MarkInvulnerableObject(o, col)
	if not MarkInvulnerableObjectsData[o] then
		MarkInvulnerableObjectsData[o] = o:GetColorModifier()
	end
	
	o:SetColorModifier(col)
end

---
--- Updates the invulnerability color marking for an object when its invulnerability state changes.
---
--- This function is called when an object's invulnerability state changes, and it updates the object's color modifier to reflect its invulnerability status.
---
--- If the object is marked as invulnerable, it will be given a color modifier based on its invulnerability type (e.g. due to material, LD mark, etc.). If the object is no longer invulnerable, its original color modifier will be restored.
---
--- @param o table The object to update the invulnerability color marking for.
---
function SetupObjInvulnerabilityColorMarkingOnValueChanged(o)
	if not InvulnerabilityPainted then return end
	if not SetupObjInvulnerabilityColorMarking(o) then
		local c = MarkInvulnerableObjectsData[o]
		if c then
			o:SetColorModifier(c)
			MarkInvulnerableObjectsData[o] = nil
		end
	end
end

---
--- Updates the invulnerability color marking for an object when its invulnerability state changes.
---
--- This function is called when an object's invulnerability state changes, and it updates the object's color modifier to reflect its invulnerability status.
---
--- If the object is marked as invulnerable, it will be given a color modifier based on its invulnerability type (e.g. due to material, LD mark, etc.). If the object is no longer invulnerable, its original color modifier will be restored.
---
--- @param o table The object to update the invulnerability color marking for.
---
function SetupObjInvulnerabilityColorMarking(o)
	if IsKindOf(o, "Slab") then
		if o:IsInvulnerable() then
			--small window owned slabs dont have any data to tell us that they are such except always_visible
			MarkInvulnerableObject(o, (o.room or o.always_visible) and InvulnerableSlabOwned or InvulnerableSlabUnowned)
			return true
		end
	else
		local m = o:GetMaterialPreset()
		local inv = false
		local str = 0
		if m then
			inv = m.invulnerable
			str = m.destruction_propagation_strength
		end
		
		if not IsObjVulnerableDueToLDMark(o) and inv then
			MarkInvulnerableObject(o, InvulnerableObjDueToMaterial)
			return true
		elseif IsObjInvulnerableDueToLDMark(o) then
			MarkInvulnerableObject(o, InvulnerableObjDueToLDMark)
			return true
		elseif ShouldDestroyObject(o) then
			local c = StrengthToColor(str)
			MarkInvulnerableObject(o, c)
			return true
		elseif TemporarilyInvulnerableObjs[o] then
			MarkInvulnerableObject(o, InvulnerableObjDueToInteractables)
			return true
		end
	end
	return false
end

---
--- Marks all objects in the map as invulnerable, and stores their original color modifiers.
---
--- This function iterates over all objects in the map and calls `SetupObjInvulnerabilityColorMarking` on each object. It then stores the original color modifiers of the invulnerable objects in the `MarkInvulnerableObjectsData` table.
---
--- After marking all invulnerable objects, this function sets the `InvulnerabilityPainted` flag to `true` and calls `PrintDestroyableOverlayLegend` to display a legend for the invulnerability markings.
---
--- @function MarkInvulnerableObjects
--- @return nil
function MarkInvulnerableObjects()
	MarkInvulnerableObjectsData = MarkInvulnerableObjectsData or {}
	MapForEach("map", SetupObjInvulnerabilityColorMarking)
	InvulnerabilityPainted = true
	PrintDestroyableOverlayLegend()
end

---
--- Clears the invulnerability markings on all objects in the map.
---
--- This function iterates over all objects that were previously marked as invulnerable and restores their original color modifiers. If `keep_data` is `false`, it also clears the `MarkInvulnerableObjectsData` table and sets the `InvulnerabilityPainted` flag to `false`.
---
--- @param keep_data boolean (optional) If `true`, the `MarkInvulnerableObjectsData` table will not be cleared.
--- @return nil
function ClearInvulnerableMarking(keep_data)
	if not InvulnerabilityPainted then return end
	
	for obj, col in pairs(MarkInvulnerableObjectsData or empty_table) do
		if IsValid(obj) then
			MarkInvulnerableObjectsData[obj] = obj:GetColorModifier()
			obj:SetColorModifier(col)
		end
	end
	
	if not keep_data then
		MarkInvulnerableObjectsData = false
		InvulnerabilityPainted = false
	end
end

---
--- Toggles the invulnerability markings on all objects in the map.
---
--- If the invulnerability markings are currently painted, this function will clear them. Otherwise, it will mark all objects in the map as invulnerable and store their original color modifiers.
---
--- @function ToggleInvulnerabilityMarkings
--- @return nil
function ToggleInvulnerabilityMarkings()
	if InvulnerabilityPainted then
		ClearInvulnerableMarking()
	else
		MarkInvulnerableObjects()
	end
end

function OnMsg.ReloadLua()
	if not InvulnerabilityPainted then return end
	DelayedCall(1, ClearInvulnerableMarking)
	DelayedCall(2, MarkInvulnerableObjects)
end

local wasMarked = false
function OnMsg.PreSaveMap()
	if InvulnerabilityPainted then
		wasMarked = true
		ClearInvulnerableMarking()
	end
end

function OnMsg.PostSaveMap()
	if wasMarked then
		MarkInvulnerableObjects()
		wasMarked = false
	end
end

end --Platform.developer

--------------------------------------------------
--ld mark cobjs as invulnerable feature
--------------------------------------------------
MapVar("InvObjsContainerInstance", false)
local InvulnerableObjsContainer_Version = 2
local invulnerable_state = "inv"
local vulnerable_state = "vul"
local prop_state = "prp"

DefineClass.InvulnerableObjsContainer = {
	__parents = { "Object" },
	entity = "InvisibleObject",
	flags = { gofPermanent = true, efCollision = false, efApplyToGrids = false, efSelectable = false, efWalkable = false, efVisible = false},
	properties = {
		--todo: rem
		{ id = "dataCobjs", editor = "prop_table", default = false, read_only = true }, --v1: {[id] = true, ... v2: empty
		{ id = "dataVCobjs", editor = "prop_table", default = false, read_only = true }, --v1: {[id] = true, ... v2: empty
		{ id = "dataObjs", editor = "prop_table", default = false, read_only = true }, 
		{ id = "dataVObjs", editor = "prop_table", default = false, read_only = true },
		--v2
		{ id = "data", editor = "prop_table", default = false, read_only = true }, --v2: {[id] = "inv"/"vul", ...
		{ id = "version", editor = "number", default = 1, read_only = true },
	},
}

--- Initializes the InvulnerableObjsContainer instance.
-- This function is called when the InvulnerableObjsContainer class is instantiated.
-- It asserts that the global variable `InvObjsContainerInstance` is set to `false`,
-- which ensures that only one instance of the InvulnerableObjsContainer class exists.
function InvulnerableObjsContainer:Init()
	assert(InvObjsContainerInstance == false)
end

--- Loads the InvulnerableObjsContainer instance and performs version-specific patches.
-- This function is called after the InvulnerableObjsContainer instance is loaded.
-- If the version is 1, it calls the `PatchV1ToV2()` function to update the data structure.
-- If the version is 2, it calls the `PatchV2ToV3()` function to update the data structure.
function InvulnerableObjsContainer:PostLoad()
	if self.version == 1 then
		self:PatchV1ToV2()
	end
	if self.version == 2 then
		self:PatchV2ToV3()
	end
end

--- Patches the InvulnerableObjsContainer instance from version 1 to version 2.
-- This function is called when the InvulnerableObjsContainer instance is loaded and its version is 1.
-- It migrates the data from the old data structures (`dataCobjs`, `dataVCobjs`, `dataObjs`, `dataVObjs`) to the new `data` structure,
-- which maps object IDs to their state (`invulnerable_state`, `vulnerable_state`).
-- If the `data` structure is empty after the migration, it is set to `false`.
-- Finally, the version is updated to 2.
function InvulnerableObjsContainer:PatchV1ToV2()
	assert(self.version == 1)
	print("InvulnerableObjsContainer:PatchV1ToV2")
	self.data = {}
	for id, _ in pairs(self.dataCobjs or empty_table) do
		self.data[id] = invulnerable_state
	end
	self.dataCobjs = false
	for id, _ in pairs(self.dataVCobjs or empty_table) do
		self.data[id] = vulnerable_state
	end
	self.dataVCobjs = false
	for id, _ in pairs(self.dataObjs or empty_table) do
		self.data[id] = invulnerable_state
	end
	self.dataObjs = false
	for id, _ in pairs(self.dataVObjs or empty_table) do
		self.data[id] = vulnerable_state
	end
	self.dataVObjs = false
	
	if not next(self.data) then
		self.data = false
	end
	
	self.version = 2
end

--- Tests the InvulnerableObjsContainer's data structure after the V3 patch.
-- This function iterates through all the CObjects in the "map" and checks that the
-- state of each object (prop, vulnerable, or invulnerable) matches the corresponding
-- value in the `data` structure. If any mismatches are found, an assertion is triggered.
-- @function InvulnerableObjsContainer:TestV3
-- @return nil
function InvulnerableObjsContainer:TestV3()
	local data = self.data
	if not data then return end
	MapForEach("map", "CObject", function(obj)
		local id = self:GetIdForObj(obj)
		if data[id] then
			local val = data[id]
			if val == prop_state then
				assert(obj:IsProp())
			elseif val == vulnerable_state then
				assert(obj:IsForcedVulnerable())
			elseif val == invulnerable_state then
				assert(obj:IsForcedInvulnerable())
			end
		end
	end)
end

--- Patches the `InvulnerableObjsContainer` from version 2 to version 3.
-- This function iterates through all the `CObject`s in the "map" and updates their state
-- (prop, vulnerable, or invulnerable) based on the values stored in the `data` structure.
-- If any objects are missing from the `data` structure, they are removed.
-- @function InvulnerableObjsContainer:PatchV2ToV3
-- @return boolean success - true if the patch was successful, false otherwise
function InvulnerableObjsContainer:PatchV2ToV3()
	assert(self.version == 2)
	print("InvulnerableObjsContainer:PatchV2ToV3")
	
	local data = self.data
	local success = true
	if data then
		local passed = {}
		MapForEach("map", "CObject", function(obj)
			local id = self:GetIdForObj(obj)
			if data[id] then
				passed[id] = true
				local val = data[id]
				if val == prop_state then
					obj:SetIsProp(true)
				elseif val == vulnerable_state then
					obj:SetIsForcedVulnerable(true)
				elseif val == invulnerable_state then
					obj:SetIsForcedInvulnerable(true)
				end
			end
		end)
		
		local missing = 0
		
		for id, _ in pairs(data) do
			if not passed[id] then
				data[id] = nil
				missing = missing + 1
			end
		end
		
		if missing > 0 then
			print("Missing objects!!!!!!!!!!", missing)
			success = false
			assert(false)
		end
	end
	print("Done!")
	self.version = 3
	if success then
		--DoneObject(self)
		Msg("DoneV3")
	end
end

---
--- Resaves all maps and verifies that the `InvObjsContainerInstance` has been updated to version 3.
---
--- This function is used to ensure that the `InvulnerableObjsContainer` has been properly updated to the latest version.
---
--- @function ResaveForV3
--- @return string "no save" if `InvObjsContainerInstance` is not set, otherwise nothing
function ResaveForV3()
	CreateRealTimeThread(function()
		local maps = {}
		ResaveAllMaps(nil,
			function()
				if not InvObjsContainerInstance then
					return "no save"
				end
				maps[GetMapName()] = true
				assert(InvObjsContainerInstance.version == 3)
			end)
	end)	
end

---
--- Resaves all maps and verifies that the `InvObjsContainerInstance` has been updated to version 3.
---
--- This function is used to ensure that the `InvulnerableObjsContainer` has been properly updated to the latest version.
---
--- @function TestResaveForV3
--- @return string "no save" if `InvObjsContainerInstance` is not set, otherwise nothing
function TestResaveForV3()
	ResaveAllMaps(
			nil, 
			function()
				if not InvObjsContainerInstance then
					return "no save"
				end
				assert(InvObjsContainerInstance.version == 3)
				InvObjsContainerInstance:TestV3()
				DoneObject(InvObjsContainerInstance)
			end)
end

---
--- Initializes the `InvulnerableObjsContainer` instance and sets it as the global `InvObjsContainerInstance`.
---
--- This function is called during the game initialization process to ensure that the `InvulnerableObjsContainer` is properly set up and accessible throughout the game.
---
--- @function InvulnerableObjsContainer:GameInit
function InvulnerableObjsContainer:GameInit()
	assert(InvObjsContainerInstance == false or InvObjsContainerInstance == self)
	InvObjsContainerInstance = self
end

---
--- Marks the `InvulnerableObjsContainer` instance as no longer the global `InvObjsContainerInstance`.
---
--- This function is called when the `InvulnerableObjsContainer` instance is no longer needed, to ensure that the global reference is cleared.
---
--- @function InvulnerableObjsContainer:Done
function InvulnerableObjsContainer:Done()
	assert(InvObjsContainerInstance == self)
	InvObjsContainerInstance = false
end

---
--- Gets the unique identifier for the given object.
---
--- If the object has a `handle` property, that is used as the identifier.
--- Otherwise, the identifier is generated using `GetVisualStateHashForDestroyedObj`.
---
--- @param obj any The object to get the identifier for.
--- @return string The unique identifier for the object.
function InvulnerableObjsContainer:GetIdForObj(obj)
	local h = rawget(obj, "handle")
	return h and h or GetVisualStateHashForDestroyedObj(obj)
end

---
--- Gets the state of the given object in the `InvulnerableObjsContainer`.
---
--- If the object has an entry in the `data` table, the corresponding state value is returned.
--- Otherwise, `nil` is returned.
---
--- @param obj any The object to get the state for.
--- @return string|nil The state of the object, or `nil` if the object is not in the container.
function InvulnerableObjsContainer:GetStateForObj(obj)
	local data = self.data
	if not data then return nil end
	return data[self:GetIdForObj(obj)]
end

---
--- Checks if the given object is a prop in the `InvulnerableObjsContainer`.
---
--- @param obj any The object to check.
--- @return boolean `true` if the object is a prop, `false` otherwise.
function InvulnerableObjsContainer:IsProp(obj)
	return self:GetStateForObj(obj) == prop_state
end

---
--- Checks if the given object is vulnerable in the `InvulnerableObjsContainer`.
---
--- An object is considered vulnerable if its state is either `vulnerable_state` or `prop_state`.
---
--- @param obj any The object to check.
--- @return boolean `true` if the object is vulnerable, `false` otherwise.
function InvulnerableObjsContainer:IsVulnerable(obj)
	local state = self:GetStateForObj(obj)
	return state == vulnerable_state or state == prop_state
end

---
--- Checks if the given object is invulnerable in the `InvulnerableObjsContainer`.
---
--- @param obj any The object to check.
--- @return boolean `true` if the object is invulnerable, `false` otherwise.
function InvulnerableObjsContainer:IsInvulnerable(obj)
	return self:GetStateForObj(obj) == invulnerable_state
end

--- Gets the data table for the `InvulnerableObjsContainer`.
---
--- If the `data` table does not exist and `create` is `true`, a new empty table is created and assigned to `self.data`.
---
--- @param create boolean If `true`, create a new `data` table if it doesn't exist.
--- @return table The `data` table for the `InvulnerableObjsContainer`.
function InvulnerableObjsContainer:GetData(create)
	if not self.data and create then
		self.data = {}
	end
	return self.data
end

---
--- Marks an object in the `InvulnerableObjsContainer` with the specified state.
---
--- @param obj any The object to mark.
--- @param val boolean Whether to mark the object or remove the mark.
--- @param mark string The state to mark the object with.
function InvulnerableObjsContainer:_MarkObj(obj, val, mark)
	local data = self:GetData(val)
	if not data then return	end
	data[self:GetIdForObj(obj)] = val and mark or nil
	if not val then
		Notify(self, "CheckIfEmptyAndDel")
	end
end

---
--- Marks an object in the `InvulnerableObjsContainer` as vulnerable.
---
--- @param obj any The object to mark as vulnerable.
--- @param val boolean Whether to mark the object as vulnerable or remove the vulnerable mark.
function InvulnerableObjsContainer:MarkObjVulnerable(obj, val)
	self:_MarkObj(obj, val, vulnerable_state)
end

---
--- Marks an object in the `InvulnerableObjsContainer` as invulnerable.
---
--- @param obj any The object to mark as invulnerable.
--- @param val boolean Whether to mark the object as invulnerable or remove the invulnerable mark.
function InvulnerableObjsContainer:MarkObjInvulnerable(obj, val)
	self:_MarkObj(obj, val, invulnerable_state)
end

---
--- Marks an object in the `InvulnerableObjsContainer` as a prop.
---
--- @param obj any The object to mark as a prop.
--- @param val boolean Whether to mark the object as a prop or remove the prop mark.
function InvulnerableObjsContainer:MarkObjProp(obj, val)
	self:_MarkObj(obj, val, prop_state)
end

---
--- Checks if the `InvulnerableObjsContainer` is empty and deletes it if so.
---
--- This function checks if the `data` table of the `InvulnerableObjsContainer` is empty. If it is, the `data` table is set to `false` and the `InvulnerableObjsContainer` is deleted using the `DoneObject` function.
---
--- @param self InvulnerableObjsContainer The `InvulnerableObjsContainer` instance.
function InvulnerableObjsContainer:CheckIfEmptyAndDel()
	if self.data and not next(self.data) then
		self.data = false
	end
	
	if not self.data then
		DoneObject(self)
	end
end

---
--- Performs cleanup on the `InvulnerableObjsContainer` by removing any references to CObjects that no longer exist.
---
--- This function iterates through the `data` table of the `InvulnerableObjsContainer` and checks if each CObject referenced in the table still exists in the game world. If a CObject no longer exists, its entry is removed from the `data` table. If any entries were removed, an error message is logged and the `CheckIfEmptyAndDel` function is called to potentially delete the `InvulnerableObjsContainer` if it is now empty.
---
--- @param self InvulnerableObjsContainer The `InvulnerableObjsContainer` instance.
function InvulnerableObjsContainer:DataCleanup()
	--if cobj gets its visual hash changed the hook will be lost
	local data = self.data
	if not data then return end
	local passed = {}
	MapForEach("map", "CObject", function(o)
		local id = self:GetIdForObj(o)
		if data[id] then
			passed[id] = true
		end
	end)
	
	local missing = 0
	
	for id, _ in pairs(data) do
		if not passed[id] then
			data[id] = nil
			missing = missing + 1
		end
	end
	
	if missing > 0 then
		StoreErrorSource(false, string.format("InvulnerableObjsContainer found %d missing hooks. If invulnerable/vulnerable CObjs were moved/rotated/scaled they are no longer invulnerable!", missing))
		self:CheckIfEmptyAndDel()
	end
end

table.insert(CObject.properties, 
{ category = "Destruction", id = "MarkInvulnerable", name = "Force Invulnerable", editor = "bool", default = false, dont_save = true })
table.insert(CObject.properties, 
{ category = "Destruction", id = "MarkVulnerable", name = "Force Vulnerable", editor = "bool", default = false, dont_save = true })
table.insert(CObject.properties, 
{ category = "Destruction", id = "MarkProp", name = "Force Prop", editor = "bool", default = false, dont_save = true, read_only = function(self) return self:IsPropMaterial() end, help = "Disabled when obj has a prop material already set." })
--table.insert(CObject.properties, 
--{ category = "Destruction", id = "DestrLight", name = "Ass Light", editor = "object", default = false, })
table.insert(StripCObjectProperties.properties,
{ id = "MarkInvulnerable" } )
table.insert(StripCObjectProperties.properties,
{ id = "MarkVulnerable" } )
table.insert(StripCObjectProperties.properties,
{ id = "MarkProp" } )
table.insert(Slab.properties,
{ id = "MarkInvulnerable" } )
table.insert(Slab.properties,
{ id = "MarkVulnerable" } )
table.insert(Slab.properties,
{ id = "MarkProp" } )

---
--- Returns whether the CObject is marked as a prop.
---
--- @param self CObject The CObject instance.
--- @return boolean Whether the CObject is marked as a prop.
function CObject:GetMarkProp(val)
	return IsObjPropDueToLDMark(self)
end

---
--- Sets whether the CObject is marked as a prop.
---
--- @param self CObject The CObject instance.
--- @param val boolean Whether the CObject should be marked as a prop.
function CObject:SetMarkProp(val)
	self:SetIsProp(val)
	SetupObjInvulnerabilityColorMarkingOnValueChanged(self)
end

---
--- Sets whether the CObject is marked as vulnerable.
---
--- @param self CObject The CObject instance.
--- @param val boolean Whether the CObject should be marked as vulnerable.
function CObject:SetMarkVulnerable(val)
	self:SetIsForcedVulnerable(val)
	SetupObjInvulnerabilityColorMarkingOnValueChanged(self)
end

---
--- Sets whether the CObject is marked as invulnerable.
---
--- @param self CObject The CObject instance.
--- @param val boolean Whether the CObject should be marked as invulnerable.
function CObject:SetMarkInvulnerable(val)
	self:SetIsForcedInvulnerable(val)
	SetupObjInvulnerabilityColorMarkingOnValueChanged(self)
end

---
--- Returns whether the CObject is marked as vulnerable.
---
--- @param self CObject The CObject instance.
--- @return boolean Whether the CObject is marked as vulnerable.
function CObject:GetMarkVulnerable()
	return IsObjVulnerableDueToLDMark(self)
end

---
--- Returns whether the CObject is marked as invulnerable.
---
--- @param self CObject The CObject instance.
--- @return boolean Whether the CObject is marked as invulnerable.
function CObject:GetMarkInvulnerable()
	return IsObjInvulnerableDueToLDMark(self)
end

--[[function OnMsg.EditorCallback(id, objs)
	local inst = InvObjsContainerInstance
	if not inst then return end
	if id == "EditorCallbackDelete" then
		for i = 1, #objs do
			local o = objs[i]
			inst:MarkObjInvulnerable(o, false)
		end
	end
end]]

--[[function OnMsg.PreSaveMap()
	if InvObjsContainerInstance then
		InvObjsContainerInstance:DataCleanup()
	end
end]]

---
--- Returns the singleton instance of the `InvulnerableObjsContainer` object.
---
--- If the instance does not exist, it is created and returned.
---
--- @return InvulnerableObjsContainer The singleton instance of the `InvulnerableObjsContainer` object.
function GetInvObjsContainerInstance()
	if not InvObjsContainerInstance then
		assert(false) --depricated
		InvObjsContainerInstance = PlaceObject("InvulnerableObjsContainer", {version = InvulnerableObjsContainer_Version}) --gameinit should hook it up, so mapget seems redundant
	end
	return InvObjsContainerInstance
end

---
--- Returns whether the CObject is marked as invulnerable.
---
--- @param obj CObject The CObject instance.
--- @return boolean Whether the CObject is marked as invulnerable.
function IsObjInvulnerableDueToLDMark(obj)
	return obj:IsForcedInvulnerable()
end

---
--- Returns whether the CObject is marked as vulnerable.
---
--- @param obj CObject The CObject instance.
--- @return boolean Whether the CObject is marked as vulnerable.
function IsObjVulnerableDueToLDMark(obj)
	return obj:IsForcedVulnerable()
end

---
--- Returns whether the CObject is marked as a prop.
---
--- @param obj CObject The CObject instance.
--- @return boolean Whether the CObject is marked as a prop.
function IsObjPropDueToLDMark(obj)
	return obj:IsProp()
end

---
--- Marks the selected objects as invulnerable.
---
--- @param val boolean Whether to mark the selected objects as invulnerable or not.
function EditorMarkSelectedObjsAsInvulnerable(val)
	local sel = editor.GetSel()
	for i, o in ipairs(sel) do
		o:SetIsForcedInvulnerable(val)
		SetupObjInvulnerabilityColorMarkingOnValueChanged(o)
	end
end

---
--- Marks the selected objects as vulnerable.
---
--- @param val boolean Whether to mark the selected objects as vulnerable or not.
function EditorMarkSelectedObjsAsVulnerable(val)
	local sel = editor.GetSel()
	for i, o in ipairs(sel) do
		o:SetIsForcedVulnerable(val)
		SetupObjInvulnerabilityColorMarkingOnValueChanged(o)
	end
end


---version3
local default = 0
local vulnerable = 1
local prop = 2
local invulnerable = 3
local flag1 = const.gofGameSpecific2
local flag2 = const.gofGameSpecific3

local function GetObjMask(obj, f1, f2)
	f1 = f1 or obj:GetGameFlags(flag1)
	f2 = f2 or obj:GetGameFlags(flag2)
	return bor(f1 ~= 0 and 1 or 0, shift(f2 ~= 0 and 1 or 0, 1))
end

local function SetObjMask(obj, mask)
	if (mask & 1) ~= 0 then
		obj:SetGameFlags(flag1)
	else
		obj:ClearGameFlags(flag1)
	end
	if (mask & 2) ~= 0 then
		obj:SetGameFlags(flag2)
	else
		obj:ClearGameFlags(flag2)
	end
end

AppendClass.CObject = {
	properties = {
		{ id = "DestructionOverrideMask", editor = "number", default = function (obj)
																local cls = obj.class
																return GetObjMask(obj, GetClassGameFlags(cls, flag1), GetClassGameFlags(cls, flag2))
															end 
		},
	},
}

---
--- Returns the destruction override mask for the object.
---
--- @return number The destruction override mask for the object.
function CObject:GetDestructionOverrideMask()
	return GetObjMask(self)
end

---
--- Sets the destruction override mask for the object.
---
--- @param val number The new destruction override mask for the object.
function CObject:SetDestructionOverrideMask(val)
	SetObjMask(self, val)
end

---
--- Sets whether the object is a prop or not.
---
--- @param val boolean Whether the object should be a prop or not.
function CObject:SetIsProp(val)
	SetObjMask(self, val and prop or default)
end

---
--- Returns whether the object is a prop or not.
---
--- @return boolean Whether the object is a prop or not.
function CObject:IsProp()
	local v = GetObjMask(self)
	return v == prop
end

---
--- Sets whether the object is forced to be vulnerable or not.
---
--- @param val boolean Whether the object should be forced vulnerable or not.
function CObject:SetIsForcedVulnerable(val)
	SetObjMask(self, val and vulnerable or default)
end

---
--- Returns whether the object is forced to be vulnerable or not.
---
--- @return boolean Whether the object is forced to be vulnerable or not.
function CObject:IsForcedVulnerable() --forced, as in set dynamically by a human as such
	local v = GetObjMask(self)
	return v == vulnerable or v == prop
end

---
--- Sets whether the object is forced to be invulnerable or not.
---
--- @param val boolean Whether the object should be forced invulnerable or not.
function CObject:SetIsForcedInvulnerable(val)
	SetObjMask(self, val and invulnerable or default)
end

---
--- Returns whether the object is forced to be invulnerable or not.
---
--- @return boolean Whether the object is forced to be invulnerable or not.
function CObject:IsForcedInvulnerable()
	local v = GetObjMask(self)
	return v == invulnerable
end

--dbg method, doesn't work at 100%, but good enough to avoid map reload
---
--- Repairs all destroyable objects in the current map.
---
--- This function suspends pass edits, iterates through all "Destroyable" objects in the map,
--- and calls the `Repair()` method on each one. It then iterates through all "CObject"
--- objects that have been destroyed, and removes them from the `Destruction_DestroyedObjects`
--- and `Destruction_DestroyedCObjects` tables. Finally, it sets up the destroyed state of
--- each object to be false, and resumes pass edits.
---
--- @return nil
function RepairAll()
	SuspendPassEdits("RepairAll")
	MapForEach("map", "Destroyable", function(o)
		o:Repair()
	end)
	
	
	if not next(Destruction_DestroyedCObjects) and not next(Destruction_DestroyedObjects) then
		return
	end
	local total = #Destruction_DestroyedObjects + #Destruction_DestroyedCObjects
	local count = 0
	MapForEach("map", "CObject", function(o, IsGenericObjDestroyed, total)
		if IsGenericObjDestroyed(o) then
			local h = rawget(o, "handle")
			if h then
				Destruction_DestroyedObjects[h] = nil
				table.remove_entry(Destruction_DestroyedObjects, h)
			else
				h = GetVisualStateHashForDestroyedObj(o)
				Destruction_DestroyedCObjects[h] = nil
				table.remove_entry(Destruction_DestroyedCObjects, h)
			end
			
			o:SetupDestroyedState(false)
			count = count + 1
			
			if count >= total then
				return "break"
			end
		end
	end, IsGenericObjDestroyed, total)
	
	ResumePassEdits("RepairAll")
end

--zulu specific implementation, building concept is zulu only
---
--- Determines whether the current DestroyableSlab should use the "replace entity" destruction method.
---
--- The destruction method is determined based on the material preset of the DestroyableSlab. If the material preset has the "use_damaged" flag set, this function will return true. If the material preset has the "use_damaged_first_floor" flag set, this function will return true if the DestroyableSlab is on the first floor of the building.
---
--- @return boolean
function DestroyableSlab:ShouldUseReplaceEntDestruction()
	--figure out destruction type, i.e. use_replace_ent_destruction = ?
	if not IsEditorActive() or dbgForceUseDamaged then
		local svd = self:GetMaterialPreset()
		if svd.use_damaged then
			return true
		elseif svd.use_damaged_first_floor then
			local r = self.room
			if not r then 
				return self.floor == 1
			else
				local meta = VolumeBuildingsMeta
				return meta and self.floor == meta[r.building].firstFloorWithFloor
			end
		end
	end
end


--set wood scaff to vulnerable
---
--- Sets all wood scaffolding on the current map to be vulnerable.
---
--- This function iterates through all FloorSlab objects on the current map and sets the `forceInvulnerableBecauseOfGameRules` and `invulnerable` properties to `true` for any FloorSlab objects with a material of "WoodScaff" and that are not already forced to be invulnerable.
---
--- @return boolean true if any wood scaffolding was set to be vulnerable, false otherwise
function dbgSetWoodScaffVulnerable()
	local didWork = false
	MapForEach("map", "FloorSlab", function(o)
		if not o.room and o.material == "WoodScaff" and not o.forceInvulnerableBecauseOfGameRules then
			didWork = true
			o.forceInvulnerableBecauseOfGameRules = true
			o.invulnerable = true
		end
	end)
	
	return didWork
end

---
--- Sets all wood scaffolding on all maps to be vulnerable.
---
--- This function creates a real-time thread that iterates through all maps and calls `dbgSetWoodScaffVulnerable()` on each map. If any wood scaffolding was set to be vulnerable, the map is saved with the name "no backup".
---
--- @return nil
function dbgSetWoodScaffVulnerableAllMaps()
	CreateRealTimeThread(function()
		ForEachMap(ListMaps(), function()
			if dbgSetWoodScaffVulnerable() then
				SaveMap("no backup")
				print("saved", GetMapName())
			end
		end)
	end)
end

-----------------------------------------------------------------
--DestroyableWallDecoration special handling. use this file's system to kill only those that wont be seen by slabs.
-----------------------------------------------------------------
---
--- Sets up the `managed_by_slab` property for all `DestroyableWallDecoration` objects on the current map.
---
--- This function first iterates through all `DestroyableWallDecoration` objects on the current map and sets their `managed_by_slab` property to `false`.
---
--- It then iterates through all `WallSlab`, `SlabWallObject`, and `RoomCorner` objects on the current map that are visible. For each of these objects, it checks if the entity is not an `InvisibleObject`, and then gets the list of decorations attached to the object. For each decoration, if it is a `DestroyableWallDecoration`, its `managed_by_slab` property is set to `true`.
---
--- This function ensures that all `DestroyableWallDecoration` objects that are associated with a `WallSlab`, `SlabWallObject`, or `RoomCorner` object are marked as being managed by the slab, while all other `DestroyableWallDecoration` objects are marked as not being managed by the slab.
---
--- @return nil
function SetupDestroyableWallDecorationManagedBySlab()
	MapForEach("map", "DestroyableWallDecoration", function(o)
		o.managed_by_slab = false
	end)
	MapForEach("map", "WallSlab", "SlabWallObject", "RoomCorner", const.efVisible, function(o)
		if o:GetEntity() == "InvisibleObject" then
			return
		end
		local decs = o:GetDecorations()
		for i = 1, #(decs or "") do
			local dec = decs[i]
			
			if IsKindOf(dec, "DestroyableWallDecoration") then
				dec.managed_by_slab = true
			end
		end
	end)
end

function OnMsg.PreSaveMap()
	SetupDestroyableWallDecorationManagedBySlab()
end

--- Destroys the `DestroyableWallDecoration` object.
---
--- If the `managed_by_slab` property is `true`, the object will not be destroyed.
--- If the `is_destroyed` property is `true`, the object has already been destroyed and this function will return.
--- Otherwise, this function calls the `Destroy()` method of the `Destroyable` class and the `Destroy()` method of the `CObject` class to fully destroy the object.
---
--- @return nil
function DestroyableWallDecoration:Destroy()
	if self.managed_by_slab then return end
	if self.is_destroyed then return end
	Destroyable.Destroy(self)
	CObject.Destroy(self)
end

----------------------------------------------------------------------
--associate lights with obj to kill light with said obj
----------------------------------------------------------------------
AutoResolveMethods.OnDestroy = "call"

AppendClass.Object = {
	properties = {
		{ id = "AssociatedLights", editor = "objects", default = false,
			name = "Associated Lights", help = "Objects in this list will get destroyed when this object is destroyed.",
			category = "Destruction",
		},
	},
}

--- Called when the Destroyable object is destroyed.
---
--- This function calls `KillAssociatedLights()` to destroy any lights associated with the Destroyable object.
---
--- @return nil
function Destroyable:OnDestroy()
	KillAssociatedLights(self)
end

--- Destroys any lights associated with the given object.
---
--- This function checks if the given object has an `AssociatedLights` property. If so, it iterates through the associated lights and calls `KillObj()` on each one that should be destroyed.
---
--- @param o Object The object whose associated lights should be destroyed.
--- @return nil
function KillAssociatedLights(o)
	local t = o:HasMember("AssociatedLights") and o.AssociatedLights or false
	for i, l in ipairs(t or empty_table) do
		if ShouldDestroyObject(l) then
			KillObj(l)
		end
	end
end

--- Associates lights with the selected objects.
---
--- This function first iterates through the selected objects in the editor, separating them into lights and non-light objects. It then associates the lights with the non-light objects by setting the `AssociatedLights` property of the non-light objects to the list of lights.
---
--- If there are no lights in the selection, the `AssociatedLights` property is set to `false`.
---
--- @return nil
function AssociateLights()
	local sel = editor.GetSel()
	local objs = {}
	local lights = {}
	for i, o in ipairs(sel or empty_table) do
		if IsKindOf(o, "Light") then
			table.insert(lights, o)
		else
			table.insert(objs, o)
		end
	end
	
	if #lights <= 0 then
		lights = false
	end
	
	for i, o in ipairs(objs) do
		--o.AssociatedLights = o.AssociatedLights or {}
		--table.iappend(o.AssociatedLights, lights)
		o.AssociatedLights = lights --overwrite, user can remove association this way
	end
	printf("%d lights associated with %d objects.", #(lights or ""), #objs)
end

function OnMsg.PreSaveMap()
	--validate AssociatedLights
	MapForEach("map", "Object", function(o)
		local t = o.AssociatedLights
		if t then
			for i = #t, 1, -1 do
				if not IsValid(t[i]) then
					table.remove(t, i)
				end
			end
			
			if #t <= 0 then
				o.AssociatedLights = false
			end
		end
	end)
end

ShouldShowAssociateLightsShortcut = return_true