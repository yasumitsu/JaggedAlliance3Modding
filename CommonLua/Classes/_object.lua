--[[@@@
@class Object
Object are CObject that have also allocated Lua memory and thus can participate in more sophisticated game logic instead of just being vizualized.
--]]
DefineClass.Object =
{
	__parents = { "CObject", "InitDone" },
	__hierarchy_cache = true,
	flags = { cfLuaObject = true, },
	spawned_by_template = false,
	handle = false,
	reserved_handles = 0,
	NetOwner = false,
	GameInit = empty_func,
	
	properties = {
		{ id = "Handle", editor = "number", default = "", read_only = true, dont_save = true },
		{ id = "spawned_by_template", name = "Spawned by template", editor = "object", read_only = true, dont_save = true },
	},
}

RecursiveCallMethods.GameInit = "procall"

--[[@@@
Called after the object's creation has been completed and the game is running. The method isn't overriden by child classes, but instead all implementations are called starting from the topmost parent.
@function void Object:GameInit()
--]]
--[[@@@
Called in the beginning of the object's creation. The method isn't overriden by child classes, but instead all implementations are called starting from the topmost parent.
@function void Object:Init()
--]]
--[[@@@
Called when the object is being destroyed. The method isn't overriden by child classes, but instead all implementations are called starting from the last child class.
@function void Object:Done()
--]]

-- HandleToObject allows each Object to be uniquely identified and prevents it from being garbage collected
-- An object's handle is a number. Permanent objects store their handle in the map.
-- When an object is created if it does not have a handle it gets an automatically generated one.
-- The handle can be used as object specific pseudo random seed or to order a list of objects.
-- An object may request a pool of handles instead of just one. The size of the pool is const.PerObjectHandlePool (project specific).

-- Below is a map of the object handle space:
--    negative - reserved for application use
--    0 .. 1,000,000 - reserved for application use
--    1,000,000 - 1,000,000,000 - autogenerated handles for objects with handle pools
--    1,000,000,000 - 1,900,000,000 - autogenerated handles for objects without handle pools
--    1,900,000,000 - 2,000,000,000 - autogenerated handles for objects created during map loading
--    2,000,000,000 - 2,147,483,646 - autogenerated sync handles (no handle pool)

local HandlesAutoPoolStart = const.HandlesAutoPoolStart or 1000000
local HandlesAutoPoolSize = (const.HandlesAutoPoolSize or 999000000) - (const.PerObjectHandlePool or 1024)
local HandlesAutoStart = const.HandlesAutoStart or 1000000000
local HandlesAutoSize = const.HandlesAutoSize or 900000000
local HandlesMapLoadingStart = HandlesAutoStart + HandlesAutoSize
local HandlesMapLoadingSize = 100000000
local HandlePoolMask = bnot((const.PerObjectHandlePool or 1024) - 1)
-- PerObjectHandlePool should be a power of two
assert(band(bnot(HandlePoolMask), const.PerObjectHandlePool or 1024) == 0)

---
--- Checks if the given handle is within the range reserved for objects created during map loading.
---
--- @param h number The handle to check
--- @return boolean true if the handle is within the map loading range, false otherwise
function IsLoadingHandle(h)
    return h and h >= HandlesMapLoadingStart and h <= (HandlesMapLoadingStart + HandlesMapLoadingSize)
end

---
--- Returns the start and size of the range of automatically generated object handles.
---
--- @return number start The start of the range of automatically generated object handles.
--- @return number size The size of the range of automatically generated object handles.
function GetHandlesAutoLimits()
    return HandlesAutoStart, HandlesAutoSize
end

---
--- Returns the start and size of the range of automatically generated object handles, as well as the size of the handle pool.
---
--- @return number start The start of the range of automatically generated object handles.
--- @return number size The size of the range of automatically generated object handles.
--- @return number poolSize The size of the handle pool.
function GetHandlesAutoPoolLimits()
    return HandlesAutoPoolStart, HandlesAutoPoolSize, const.PerObjectHandlePool or 1024
end

---
--- Defines global variables to store object handles, game init threads, and game init objects.
---
--- @global HandleToObject table A table that maps object handles to their corresponding objects.
--- @global GameInitThreads table A table that stores the game init threads for each object.
--- @global GameInitAfterLoading table A table that stores the objects that need to have their GameInit() method called after the game has finished loading.
MapVar("HandleToObject", {})
MapVar("GameInitThreads", {})
MapVar("GameInitAfterLoading", {})

---
--- Called when the game time starts. Processes any objects that need to have their GameInit() method called after the game has finished loading.
---
function OnMsg.GameTimeStart()
    local list = GameInitAfterLoading
    local i = 1
    while i <= #list do
        local obj = list[i]
        if IsValid(obj) then
            obj:GameInit()
        end
        i = i + 1
    end
    GameInitAfterLoading = false
end

---
--- Cancels the GameInit() method call for the specified object.
---
--- If the object has a pending GameInit() call in a game time thread, the thread is deleted.
--- If the object is in the GameInitAfterLoading table, it is removed from the table.
---
--- @param obj table The object to cancel the GameInit() call for.
--- @param bCanDeleteCurrentThread boolean If true, the current thread can be deleted. If false, the current thread will not be deleted.
---
function CancelGameInit(obj, bCanDeleteCurrentThread)
    local thread = GameInitThreads[obj]
    if thread then
        DeleteThread(thread, bCanDeleteCurrentThread)
        GameInitThreads[obj] = nil
        return
    end
    local list = GameInitAfterLoading
    if list then
        for i = #list, 1, -1 do
            if list[i] == obj then
                list[i] = false
                return
            end
        end
    end
end

---
--- Creates a new object instance of the specified class.
---
--- This function is responsible for generating a unique handle for the new object, and associating it with the object in the `HandleToObject` table.
---
--- If the object has a `GameInit` method, it will be called either immediately in a new game time thread, or added to the `GameInitAfterLoading` table to be called later after the game has finished loading.
---
--- @param class table The class definition of the object to create.
--- @param luaobj table The Lua object to associate with the new C object.
--- @param components table An optional table of component objects to associate with the new object.
--- @param ... any Additional arguments to pass to the object's `Init` method.
--- @return table The new object instance.
function Object.new(class, luaobj, components, ...)
    local self = CObject.new(class, luaobj, components)

    local h = self.handle
    if h then
        local prev_obj = HandleToObject[h]
        if prev_obj and prev_obj ~= self then
            assert(false, string.format("Duplicate handle %d: new '%s', prev '%s'", h, class.class, prev_obj.class))
            h = false
        end
    end
    if not h then
        h = self:GenerateHandle()
        self.handle = h
    end
    HandleToObject[h] = self

    OnHandleAssigned(h)

    if self.GameInit ~= empty_func then
        local loading = GameInitAfterLoading
        if loading then
            loading[#loading + 1] = self
        else
            GameInitThreads[self] = CreateGameTimeThread(function(self)
                if IsValid(self) then
                    self:GameInit()
                end
                GameInitThreads[self] = nil
            end, self)
        end
    end
    self:NetUpdateHash("Init")
    self:Init(...)
    return self
end

---
--- Deletes the object instance.
---
--- This function is responsible for removing the object from the `HandleToObject` table, marking it as deleted in the `DeletedCObjects` table, and calling the `Done()` method on the object.
---
--- If the object has a handle, it asserts that the handle is associated with the object in the `HandleToObject` table. It then removes the handle from the `HandleToObject` table and marks the object as deleted in the `DeletedCObjects` table.
---
--- Finally, it calls the `Done()` method on the object and deletes the C object using the `CObject.delete()` function.
---
--- @param fromC boolean If true, the delete was initiated from C code.
function Object:delete(fromC)
    if not self[true] then
        return
    end

    dbg(self:Trace("Object:delete", GetStack(2)))

    local h = self.handle
    assert(not h or HandleToObject[h] == self, "Object is already destroyed", 1)
    assert(not DeletedCObjects[self], "Object is already destroyed", 1)
    HandleToObject[h] = nil
    DeletedCObjects[self] = true
    self:Done()
    CObject.delete(self, fromC)
end

-- called while loading map after object is placed and its properties are set
-- use to compute members from other properties
---
--- Sets the `PostLoad` function to an empty function.
---
--- The `PostLoad` function is called after an object's properties have been set, and is used to compute members from other properties.
---
--- By setting `PostLoad` to an empty function, this disables the default behavior of the `PostLoad` function.
---
--- @field AutoResolveMethods.PostLoad boolean If true, the `PostLoad` function will be called after an object's properties have been set.
--- @field Object.PostLoad function An empty function that does nothing. This is used to disable the default behavior of the `PostLoad` function.
AutoResolveMethods.PostLoad = true
Object.PostLoad = empty_func

---
--- Copies the properties from the specified object to this object.
---
--- This function uses the `PropertyObject.CopyProperties()` function to copy the specified properties from the source object to this object.
---
--- After the properties have been copied, the `PostLoad()` function is called on this object. This allows the object to perform any additional processing or initialization that is required after the properties have been set.
---
--- @param obj table The object to copy properties from.
--- @param properties table (optional) A table of property names to copy. If not provided, all properties will be copied.
function Object:CopyProperties(obj, properties)
    PropertyObject.CopyProperties(self, obj, properties)
    self:PostLoad()
end

-- C side invoke
---
--- Copies the properties from the specified source object to the destination object.
---
--- This function uses the `Object:CopyProperties()` method to copy the properties from the source object to the destination object.
---
--- After the properties have been copied, the function returns the destination object. This is necessary because the game object could be changed during the `CopyProperties()` call, so the new object needs to be returned.
---
--- @param dest table The destination object to copy properties to.
--- @param source table The source object to copy properties from.
--- @return table The destination object, which may have been modified during the `CopyProperties()` call.
function CCopyProperties(dest, source)
    dest:CopyProperties(source)
    return dest -- the game object could be changed during this call, need to return the new one
end

---
--- Changes the class metatable of the specified object to the class definition for the given class name.
---
--- This function is used to change the class of an object at runtime. It sets the metatable of the object to the class definition for the specified class name.
---
--- @param obj table The object to change the class of.
--- @param classname string The name of the class to set the object's class to.
function ChangeClassMeta(obj, classname)
    local classdef = g_Classes[classname]
    assert(classdef)
    if not classdef then
        return
    end
    setmetatable(obj, classdef)
end
-- C side invoke
function ChangeClassMeta(obj, classname)
    local classdef = g_Classes[classname]
    assert(classdef)
    if not classdef then
        return
    end
    setmetatable(obj, classdef)
end

---
--- Generates a random number using the AsyncRand function.
---
--- @return number A random number generated using AsyncRand.
HandleRand = AsyncRand

---
--- Generates a unique handle for an object.
---
--- This function is used to generate a unique handle for an object. The handle is used to identify the object and ensure that it is unique within the game world.
---
--- If the object is a sync object, the function calls `GenerateSyncHandle()` to generate the handle. Otherwise, it generates a random handle within a specified range.
---
--- If the object has a reserved handle range, the function generates a handle within that range. Otherwise, it generates a handle within the global handle pool.
---
--- @return number The generated handle for the object.
function Object:GenerateHandle()
    if self:IsSyncObject() then
        return GenerateSyncHandle(self)
    end
    local range = self.reserved_handles
    local h
    if range == 0 then
        local start, size = HandlesAutoStart, HandlesAutoSize
        if ChangingMap then
            start, size = HandlesMapLoadingStart, HandlesMapLoadingSize
        end
        repeat
            h = start + HandleRand(size)
        until not HandleToObject[h]
    else
        assert(band(range, HandlePoolMask) == 0) -- the reserved pool is large enough
        repeat
            h = band(HandlesAutoPoolStart + HandleRand(HandlesAutoPoolSize), HandlePoolMask)
        until not HandleToObject[h]
    end
    return h
end

---
--- Returns the handle of the object.
---
--- @return number The handle of the object.
function Object:GetHandle()
    return self.handle
end

---
--- Sets the handle of the object.
---
--- This function is used to set the handle of the object. It performs the following steps:
---
--- 1. Converts the input handle to a number or uses the input handle as is.
--- 2. Asserts that the current handle is not set or that the object is the one associated with the current handle.
--- 3. If the handle is the same as the current handle, returns the handle.
--- 4. If the handle is set and another object is associated with it, asserts an error and generates a new handle.
--- 5. Removes the association between the current handle and the object.
--- 6. Associates the new handle with the object.
--- 7. Sets the handle of the object.
--- 8. Calls the `OnHandleAssigned` function with the new handle.
---
--- @param h number The new handle for the object.
--- @return number The new handle for the object.
function Object:SetHandle(h)
    h = tonumber(h) or h or false
    assert(not self.handle or HandleToObject[self.handle] == self)
    if self.handle == h then
        return h
    end
    if h and HandleToObject[h] then
        assert(false, string.format("Duplicate handle %d: new '%s', prev '%s'", h, self.class, HandleToObject[h].class))
        h = self:GenerateHandle()
    end
    HandleToObject[self.handle] = nil
    if h then
        HandleToObject[h] = self
    end
    self.handle = h

    OnHandleAssigned(h)

    return h
end

---
--- Regenerates the handle of the object.
---
--- This function is used to generate a new handle for the object and set it using the `SetHandle` function.
---
--- @function Object:RegenerateHandle
--- @return number The new handle for the object.
function Object:RegenerateHandle()
    self:SetHandle(self:GenerateHandle())
end

-- A pseudorandom that is stable for the lifetime of the object and avoids clustering artefacts
---
--- Generates a pseudorandom number based on the object's handle and a provided key.
---
--- This function uses the xxhash algorithm to generate a pseudorandom number based on the object's handle and a provided key. The resulting number is then modulated by the given range to produce a value within that range.
---
--- @param range number The range of the resulting pseudorandom number.
--- @param key any The key to use for the pseudorandom number generation.
--- @param ... any Additional arguments to pass to the xxhash function.
--- @return number A pseudorandom number within the given range.
function Object:LifetimeRandom(range, key, ...)
    assert(range and key)
    return abs(xxhash(self.handle, key, ...)) % range
end

---
--- Resets the spawn state of the object and any objects that have reserved handles.
---
--- This function is used to reset the spawn state of the object and any objects that have reserved handles. It iterates through the reserved handles and recursively calls the `ResetSpawn` function on any objects that have a reserved handle. It also calls the `DoneObject` function on any objects that are found.
---
--- @function Object:ResetSpawn
--- @return nil
function Object:ResetSpawn()
    if self.reserved_handles == 0 then
        return
    end
    local handle = self.handle + 1
    local max_handle = self.handle + self.reserved_handles
    while handle < max_handle do
        local obj = HandleToObject[handle]
        if obj then
            handle = handle + 1 + obj.reserved_handles
            obj:ResetSpawn()
            DoneObject(obj)
        else
            handle = handle + 1
        end
    end
end

-- returns false, "local" or "remote"
---
--- Returns the network state of the object's owner.
---
--- If the object has a valid net owner, this function returns the net state of the net owner. Otherwise, it returns `false`.
---
--- @function Object:NetState
--- @return boolean|string The net state of the object's owner, or `false` if the object has no net owner.
function Object:NetState()
    if IsValid(self.NetOwner) then
        return self.NetOwner:NetState()
    end
    return false
end

RecursiveCallMethods.GetDynamicData = "call"
RecursiveCallMethods.SetDynamicData = "call"

---
--- Retrieves the dynamic data of the object.
---
--- This function retrieves various dynamic properties of the object, such as the net owner, visual position, visual angle, and gravity. The retrieved data is stored in the provided `data` table.
---
--- @function Object:GetDynamicData
--- @param data table A table to store the retrieved dynamic data.
--- @return nil
function Object:GetDynamicData(data)
    if IsValid(self.NetOwner) then
        data.NetOwner = self.NetOwner
    end
    if self:IsValidPos() and not self:GetParent() then
        local vpos_time = self:TimeToPosInterpolationEnd()
        if vpos_time ~= 0 then
            data.vpos = self:GetVisualPos()
            data.vpos_time = vpos_time
        end
    end
    local vangle_time = self:TimeToAngleInterpolationEnd()
    if vangle_time ~= 0 then
        data.vangle = self:GetVisualAngle()
        data.vangle_time = vangle_time
    end
    local gravity = self:GetGravity()
    if gravity ~= 0 then
        data.gravity = gravity
    end
end

---
--- Sets the dynamic data of the object.
---
--- This function sets various dynamic properties of the object, such as the net owner, gravity, visual position, and visual angle. The dynamic data is provided in the `data` table.
---
--- @function Object:SetDynamicData
--- @param data table A table containing the dynamic data to set.
--- @return nil
function Object:SetDynamicData(data)
	self.NetOwner = data.NetOwner
	if data.gravity then
		self:SetGravity(data.gravity)
	end
	
	if data.pos then
		self:SetPos(data.pos)
	end
	if data.angle then
		self:SetAngle(data.angle or 0)
	end
	if data.vpos then
		local pos = self:GetPos()
		self:SetPos(data.vpos)
		self:SetPos(pos, data.vpos_time)
	end
	if data.vangle then
		local angle = self:GetAngle()
		self:SetAngle(data.vangle)
		self:SetAngle(angle, data.vangle_time)
	end
end

local ResolveHandle = ResolveHandle
local SetObjPropertyList = SetObjPropertyList
local SetArray = SetArray
---
--- Constructs a new object from Lua code.
---
--- This function is used to construct a new object from Lua code. It takes the object properties, array, and handle as input, and creates a new object with the given data.
---
--- @function Object:__fromluacode
--- @param props table The object properties to set.
--- @param arr table The array data to set.
--- @param handle number The handle of the object.
--- @return Object The newly constructed object.
function Object:__fromluacode(props, arr, handle)
	local obj = ResolveHandle(handle)
	
	if obj and obj[true] then
		StoreErrorSource(obj, "Duplicate handle", handle)
		assert(false, string.format("Duplicate handle %d: new '%s', prev '%s'", handle, self.class, obj.class))
		obj = nil
	end
	
	obj = self:new(obj)
	SetObjPropertyList(obj, props)
	SetArray(obj, arr)
	return obj
end

---
--- Converts the object to Lua code.
---
--- This function is used to convert an object to Lua code. It takes the object properties, array, and handle as input, and generates a Lua code string that can be used to recreate the object.
---
--- @function Object:__toluacode
--- @param indent string The indentation to use for the generated Lua code.
--- @param pstr string (optional) A string buffer to append the Lua code to.
--- @param GetPropFunc function (optional) A function to get the property value for the object.
--- @return string The generated Lua code for the object.
function Object:__toluacode(indent, pstr, GetPropFunc)
	if not pstr then
		local props = ObjPropertyListToLuaCode(self, indent, GetPropFunc)
		local arr = ArrayToLuaCode(self, indent)
		return string.format("PlaceObj('%s', %s, %s, %s)", self.class, props or "nil", arr or "nil", tostring(self.handle or "nil"))
	else
		pstr:appendf("PlaceObj('%s', ", self.class)
		if not ObjPropertyListToLuaCode(self, indent, GetPropFunc, pstr) then
			pstr:append("nil")
		end
		pstr:append(", ")
		if not ArrayToLuaCode(self, indent, pstr) then
			pstr:append("nil")
		end
		return pstr:append(", ", self.handle or "nil", ")")
	end
end

----- Sync Objects

--- @class SyncObject
--- A class that represents a synchronized object in the game.
--- The `SyncObject` class inherits from the `Object` class and has the `gofSyncObject` flag set to `true`.
--- Synchronized objects are used to represent game objects that need to be synchronized across the network, such as player characters or other game entities.
--- The `SyncObject` class provides functionality for generating and managing the handles of synchronized objects.
DefineClass.SyncObject = {__parents={"Object"}, flags={gofSyncObject=true}}
---
--- Converts a regular object into a synchronized object.
---
--- This function sets the `gofSyncObject` flag on the object, indicating that it is a synchronized object.
--- It also generates a new handle for the object using the `GenerateHandle()` function, and updates the object's position, angle, entity, and state text over the network.
---
--- @function Object:MakeSync
--- @return nil

function Object:MakeSync()
	if self:IsSyncObject() then return end
	self:SetGameFlags(const.gofSyncObject)
	self:SetHandle(self:GenerateHandle())
	self:NetUpdateHash("MakeSync", self:GetPos(), self:GetAngle(), self:GetEntity(), self:GetStateText())
end
--- Selects a random element from the given table.
---
--- This function selects a random element from the given table `tbl`. If the table has less than 2 elements, it returns the first element and its index. Otherwise, it generates a random index using the `Random()` function and returns the corresponding element and its index.
---
--- @param tbl table The table to select a random element from.
--- @param key string (optional) A key to use for the random seed.
--- @return any, number The randomly selected element and its index.
function Object:TableRand(tbl, key)
end

function Object:TableRand(tbl, key)
	if not tbl then return elseif #tbl < 2 then return tbl[1], 1 end
	local idx = self:Random(#tbl, key)
	idx = idx + 1
	return tbl[idx], idx
end
---
--- Selects a random element from the given table, with weighted probabilities.
---
--- This function selects a random element from the given table `tbl`, with the probabilities of each element determined by the `calc_weight` function. The `calc_weight` function should take an element from the table and return a number representing the weight of that element.
---
--- The function uses the `table.weighted_rand()` function to perform the weighted random selection, and the `self:Random()` function to generate a random seed based on the provided `key`.
---
--- @param tbl table The table to select a random element from.
--- @param calc_weight function A function that takes an element from the table and returns a number representing its weight.
--- @param key string (optional) A key to use for the random seed.
--- @return any, number The randomly selected element and its index.
function Object:TableWeightedRand(tbl, calc_weight, key)
end

function Object:TableWeightedRand(tbl, calc_weight, key)
	if not tbl then return elseif #tbl < 2 then return tbl[1], 1 end
	
	local seed = self:Random(max_int, key)
	return table.weighted_rand(tbl, calc_weight, seed)
end
--- Generates a random number within a specified range.
---
--- This function generates a random number between `min` and `max` (inclusive) using the `self:Random()` function.
---
--- @param min number The minimum value of the range.
--- @param max number The maximum value of the range.
--- @param ... any Additional arguments to pass to `self:Random()`.
--- @return number A random number within the specified range.
function Object:RandRange(min, max, ...)
end

function Object:RandRange(min, max, ...)
    return min + self:Random(max - min + 1, ...)
end

---
--- Generates a random seed based on the provided `key`.
---
--- This function generates a random seed using the `self:Random()` function and the provided `key`. The seed is generated within the range of `max_int`.
---
--- @param key string A key to use for the random seed.
--- @return number The generated random seed.
function Object:RandSeed(key)
    return self:Random(max_int, key)
end

---
--- Defines the range of handles used for synchronization between the client and server.
---
--- `HandlesSyncStart` is the starting handle value for synchronized objects.
--- `HandlesSyncSize` is the total number of handles available for synchronization.
--- `HandlesSyncEnd` is the ending handle value for synchronized objects.
---
--- These values are used to manage the allocation and tracking of handles for objects that need to be synchronized between the client and server.
local HandlesSyncStart = const.HandlesSyncStart or 2000000000
local HandlesSyncSize = const.HandlesSyncSize or 147483647
local HandlesSyncEnd = HandlesSyncStart + HandlesSyncSize - 1

---
--- Initializes a table to store custom sync handles and sets the initial value for the next sync handle.
---
--- The `CustomSyncHandles` table is used to store any custom sync handles that are not part of the standard range defined by `HandlesSyncStart` and `HandlesSyncEnd`.
--- The `NextSyncHandle` variable is set to the starting value of the standard sync handle range, `HandlesSyncStart`.
---
--- @tparam table CustomSyncHandles A table to store custom sync handles.
--- @tparam number NextSyncHandle The initial value for the next sync handle.
MapVar("CustomSyncHandles", {})
MapVar("NextSyncHandle", HandlesSyncStart)

---
--- Checks if the given handle is within the range of synchronized handles.
---
--- This function checks if the provided `handle` is within the range of handles used for synchronization between the client and server. It also checks if the handle is a custom sync handle stored in the `CustomSyncHandles` table.
---
--- @param handle number The handle to check.
--- @return boolean `true` if the handle is a synchronized handle, `false` otherwise.
function IsHandleSync(handle)
    return handle >= HandlesSyncStart and handle <= HandlesSyncEnd or CustomSyncHandles[handle]
end

---
--- Generates a new synchronization handle for an object.
---
--- This function generates a new synchronization handle for an object that needs to be synchronized between the client and server. It ensures that the generated handle is unique and within the range of reserved handles for synchronization.
---
--- @return number The generated synchronization handle.
function GenerateSyncHandle()
    local h = NextSyncHandle
    while HandleToObject[h] do
        h = (h + 1 <= HandlesSyncEnd) and (h + 1) or HandlesSyncStart
        if h == NextSyncHandle then
            assert(false, "All reserved handles are used!")
            break
        end
    end
    NextSyncHandle = (h + 1 <= HandlesSyncEnd) and (h + 1) or HandlesSyncStart
    NetUpdateHash("GenerateSyncHandle", h)
    return h
end

---
--- Defines a class `StripObjectProperties` that inherits from `StripCObjectProperties` and `Object`.
--- This class has the following properties:
---
--- - `Entity`: The entity associated with the object.
--- - `Pos`: The position of the object.
--- - `Angle`: The angle of the object.
--- - `ForcedLOD`: The forced level of detail for the object.
--- - `Groups`: The groups the object belongs to.
--- - `CollectionIndex`: The index of the object in a collection.
--- - `CollectionName`: The name of the collection the object belongs to.
--- - `spawned_by_template`: Whether the object was spawned by a template.
--- - `Handle`: The handle of the object.
---
DefineClass.StripObjectProperties = {__parents={"StripCObjectProperties", "Object"},
    properties={{id="Entity"}, {id="Pos"}, {id="Angle"}, {id="ForcedLOD"}, {id="Groups"}, {id="CollectionIndex"},
        {id="CollectionName"}, {id="spawned_by_template"}, {id="Handle"}}}
