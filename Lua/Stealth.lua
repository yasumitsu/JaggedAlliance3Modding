function OnMsg.NewMapLoaded()
	ResetVoxelStealthParamsCache()
end

DefineClass.TallGrass = {
	__parents = {"Grass"},
	flags = { efVsGrass = true },
}

PointLight.flags = PointLight.flags or {}
PointLight.flags.efVsPointLight = true
SpotLight.flags = SpotLight.flags or {}
SpotLight.flags.efVsSpotLight = true
SpotLight.flags.efVsPointLight = false

function OnMsg.LightsStateUpdated()
	ResetVoxelStealthParamsCache()
	--[[for _, unit in ipairs(g_Units or empty_table) do
		UpdateUnitStealth(unit)
	end]]
end

---
--- Checks if a target is illuminated based on the current game state and the target's environment factors.
---
--- @param target table|nil The target to check for illumination. Can be nil.
--- @param voxels table|nil The voxels to check for illumination. If not provided, will be generated based on the target.
--- @param sync boolean|nil Whether to sync the illumination check with the network.
--- @param step_pos table|nil The position to use for the voxel checks instead of the target's position.
--- @return boolean|nil True if the target is illuminated, false otherwise. Returns nil if the target is invalid or not in a valid position.
function IsIlluminated(target, voxels, sync, step_pos)
	--if step_pos is present, use it for all pos checks and use the target for all unit checks
	if not IsValid(target) or not target:IsValidPos() then return end
	if not GameState.Night and not GameState.Underground then
		return true
	end
	local env_factors = GetVoxelStealthParams(step_pos or target)
	--if sync then NetUpdateHash("IsIlluminated", target, target:GetPos(), env_factors, table.unpack(voxels)) end
	if env_factors ~= 0 and band(env_factors, const.vsFlagIlluminated) ~= 0 then
		return true
	end
	-- If the weapon ignores dark it also generates light (in theory)
	if IsKindOf(target, "Unit") then
		local _, __, weapons = target:GetActiveWeapons()
		for i, w in ipairs(weapons) do
			if w:HasComponent("IgnoreInTheDark") then
				return true
			end
		end
	end

	if next(g_DistToFire) == nil then
		return
	end

	if not voxels then
		if IsKindOf(target, "Unit") then
			voxels = step_pos and target:GetVisualVoxels(step_pos) or target:GetVisualVoxels()
		else
			local x, y, z = WorldToVoxel(target)
			voxels = {point_pack(x, y, z)}
		end
	end
	return AreVoxelsInFireRange(voxels)
end

function OnMsg.ClassesGenerate(classdefs)
	local classdef = classdefs.Light
	local old_gameinit = classdef.GameInit
	local old_done = classdef.Done
	local old_fade = classdef.Fade
	--todo: clear cache on these probably
	--local old_set_ef = classdef.SetEnumFlags
	--local old_clear_ef = classdef.ClearEnumFlags
	classdef.GameInit = function(self, ...)
		if old_gameinit then
			old_gameinit(self, ...)
		end
		ResetVoxelStealthParamsCache()
	end
	classdef.Done = function(self, ...)
		KillStealthLightForLight(self)
		if old_done then
			old_done(self, ...)
		end
		ResetVoxelStealthParamsCache()
	end
	classdef.Fade = function(self, color, intensity, time)
		old_fade(self, color, intensity, time)
		if self.stealth_light then
			old_fade(self.stealth_light, color, intensity, time)
		end
	end
end

DefineClass.StealthLight = {
	__parents = { "Object" },
	original_light = false,
}

DefineClass.StealthPointLight = {
	__parents = { "PointLight", "StealthLight" },
	flags = {cfLight = false, efVsPointLight = true, gofRealTimeAnim = false},
	entity = "InvisibleObject",
	--entity = "PointLight", -- needed by the editor
}

DefineClass.StealthPointLightFlicker = {
	__parents = { "PointLightFlicker", "StealthLight" },
	flags = {cfLight = false, efVsPointLight = true, gofRealTimeAnim = false},
	entity = "InvisibleObject",
	--entity = "PointLight", -- needed by the editor
}

DefineClass.StealthSpotLightFlicker = {
	__parents = { "SpotLightFlicker", "StealthLight" },
	flags = {cfLight = false, efVsPointLight = false, efVsSpotLight = true, gofRealTimeAnim = false},
	entity = "InvisibleObject",
	--entity = "PointLight", -- needed by the editor
}

DefineClass.StealthSpotLight = {
	__parents = { "SpotLight", "StealthLight" },
	flags = {cfLight = false, efVsPointLight = false, efVsSpotLight = true, gofRealTimeAnim = false},
	entity = "InvisibleObject",
	--entity = "PointLight", -- needed by the editor
}

MapVar("StealthLights", {})
---
--- Synchronizes the position and orientation of stealth lights across the network.
---
--- This function is called when the "SyncLights" network event is received. It iterates through the
--- provided data, which contains the handle, position, angle, and axis of each stealth light, and
--- updates the corresponding stealth light objects accordingly.
---
--- After updating the stealth lights, it resets the voxel stealth parameters cache and, if the
--- g_Combat object exists, sets its visibility_update_hash to false to trigger a visibility update.
---
--- @param in_data table The data containing the stealth light information to synchronize.
---
function NetSyncEvents.SyncLights(in_data)
	for i, data in ipairs(in_data) do
		local h = data[1]
		local sl = HandleToObject[h]
		if IsValid(sl) then
			sl:SetPos(data[2])
			sl:SetAxisAngle(data[4], data[3])
		end
	end
	ResetVoxelStealthParamsCache()
	if g_Combat then 
		g_Combat.visibility_update_hash = false
	end
end


---
--- Periodically synchronizes the position and orientation of stealth lights across the network.
---
--- This function is called by a repeating game time thread. It iterates through the list of stealth
--- lights, collects their position, angle, and axis data, and sends it to all clients via the
--- "SyncLights" network event. After sending the data, it sleeps for 500 milliseconds before
--- repeating the process.
---
--- If the game is not being hosted locally, the function will halt execution until the game is
--- hosted locally again.
---
--- @function 
MapGameTimeRepeat("StealthLights", -1, function()
	if netInGame and not NetIsHost() then
		Halt()
	end
	while #StealthLights > 0 do
		local data = {}
		for i, sl in ipairs(StealthLights) do
			local ol = sl.original_light
			table.insert(data, {sl.handle, ol:GetVisualPos(), ol:GetVisualAngle(), ol:GetVisualAxis()}) --presumably everything else is sync
		end
		NetSyncEvent("SyncLights", data)
		
		Sleep(500)
	end
	
	WaitWakeup()
end)

---
--- Creates a new stealth light object that mirrors the properties of the given light object.
---
--- The function first checks if a stealth light object already exists for the given light. If not, it creates a new stealth light object of the appropriate class (based on the class of the given light object), copies the properties from the light object to the stealth light object, and sets the original_light property of the stealth light to reference the given light object.
---
--- The function then detaches the stealth light object from the map, makes it synchronous, and adds it to the StealthLights table. Finally, it wakes up the PeriodicRepeatThreads["StealthLights"] thread to trigger a visibility update.
---
--- @param light table The light object to create a stealth light for.
---
function CreateStealthLight(light)
	if IsValid(light.stealth_light) then return end
	local stealth_light_cls = "Stealth" .. light.class
	if g_Classes[stealth_light_cls] then
		local sl = PlaceObject(stealth_light_cls)
		sl:CopyProperties(light)
		sl.original_light = light
		light.stealth_light = sl
		
		--parent light might have be @ diff pos/angle due to realtime / bone anim, lights thread should set them up correctly
		sl:SetAxisAngle(axis_z, 0)
		sl:DetachFromMap()
		sl:MakeSync()
		
		ResetVoxelStealthParamsCache()
		table.insert(StealthLights, sl)
		--DbgAddVector(light:GetPos())
		Wakeup(PeriodicRepeatThreads["StealthLights"])
	end
end

---
--- Checks if the given light object is attached to a player unit.
---
--- @param obj table The light object to check.
--- @param parent table The parent object of the light, if known. If not provided, the function will attempt to find the topmost parent.
--- @return boolean true if the light is attached to a player unit, false otherwise.
---
function IsLightAttachedOnPlayerUnit(obj, parent)
	local parent = parent or obj and GetTopmostParent(obj)
	if IsKindOf(parent, "Unit") then 
		if parent.team and (parent.team.side == "player1" or parent.team.side == "player2") then
			return true
		end
	end
end

---
--- Determines whether a light object should be synchronized based on its parent object.
---
--- @param obj table The light object to check.
--- @param parent table The parent object of the light, if known. If not provided, the function will attempt to find the topmost parent.
--- @return boolean true if the light should be synchronized, false otherwise.
---
function ShouldSyncFXLightLua(obj, parent)
	local parent = parent or obj and GetTopmostParent(obj)
	if not IsValid(parent) then
		--not a case we are handling atm
		return false
	end
	if IsLightAttachedOnPlayerUnit(obj, parent) then
		--this is also flashlight case now
		return false --this is when player throws flare, either sync throwing fx or use this 
	end
	
	return true
end

---
--- Handles a light object in the context of stealth mechanics.
---
--- @param obj table The light object to handle.
--- @param force_sl boolean (optional) If true, forces the creation of a stealth light object.
--- @return boolean true if the light was handled successfully, false otherwise.
---
function Stealth_HandleLight(obj, force_sl)
	if not IsLightSetupToAffectStealth(obj) then return end
	if IsLightAttachedOnPlayerUnit(obj) then return end --flashlights/flares being thrown
	
	obj:ClearGameFlags(const.gofRealTimeAnim)
	if not force_sl and not obj.stealth_light and not obj:IsAttachedToBone() then
		--lights that are sync and move are async because of the stealth cache being reset asynchroniously
		obj:MakeSync()
		ResetVoxelStealthParamsCache()
		return true
	else
		CreateStealthLight(obj)
	end
end

---
--- Creates stealth lights for the current map.
---
--- This function is called when the map is changed or when the light model is changed. It iterates through all lights in the map and handles them in the context of stealth mechanics.
---
--- @return nil
---
function CreateStealthLights()
	if GetMapName() == "" then return end
	ResetVoxelStealthParamsCache()
	CreateGameTimeThread(function()
		MapForEach("map", "Light", Stealth_HandleLight)
		ResetVoxelStealthParamsCache()
	end)
end

OnMsg.ChangeMapDone = CreateStealthLights

---
--- Handles the event when the light model is changed.
---
--- This function is called when the light model is changed. It triggers the creation of stealth lights for the current map.
---
--- @return nil
---
function NetSyncEvents.OnLightModelChanged()
	CreateStealthLights()
end

OnMsg.LightmodelChange = function()
	if IsChangingMap() then return end --changemapdone should handle this
	NetSyncEvent("OnLightModelChanged")
end

function OnMsg.EditorCallback(id, objects, ...)
	if id == "EditorCallbackPlace" then
		for _, obj in ipairs(objects) do
			if IsKindOf(obj, "Light") and IsLightSetupToAffectStealth(obj) then
				Stealth_HandleLight(obj)
			end
		end
	end
end
if FirstLoad then
	lights_on_save = false
end

function OnMsg.PreSaveMap()
	lights_on_save = {}
	MapForEach("map", "Light", nil, nil, const.gofPermanent, function(o)
		--make all lights placed on map itself sync so we can track em and filter them into stealth
		o:MakeNotSync()
		table.insert(lights_on_save, o)
	end)
end

function OnMsg.SaveMapDone()
	for i = 1, #lights_on_save do
		lights_on_save[i]:MakeSync()
	end
	lights_on_save = false
end

---
--- Makes the light a sync object.
---
--- This function sets the light as a sync object, which means its properties will be synchronized across the network.
--- It also stores the current handle of the light in the `old_handle` field, so that the handle can be restored when the light is made non-sync.
---
--- @return nil
---
function Light:MakeSync()
	if self:IsSyncObject() then return end
	local h = self.handle
	if not IsHandleSync(h) then
		self.old_handle = h --this is so we produce no diffs when saving map so we demote lights to non sync and keep handles the same if possible
	end
	Object.MakeSync(self)
	self:NetUpdateHash("LightMakeSync", self:GetIntensity(), self:GetAttenuationShape(), const.vsConstantLightIntensity)
end

---
--- Makes the light a non-sync object.
---
--- This function sets the light as a non-sync object, which means its properties will no longer be synchronized across the network.
--- It restores the previous handle of the light from the `old_handle` field, so that the handle remains the same when the light is made non-sync.
---
--- @return nil
---
function Light:MakeNotSync()
	if not self:IsSyncObject() then return end
	local oh = self.old_handle
	self:ClearGameFlags(const.gofSyncObject)
	local obj = oh and HandleToObject[oh]
	oh = (obj == self or not obj) and oh or false
	self:SetHandle(oh or self:GenerateHandle())
end

---
--- Handles the behavior of a light when its "DetailClass" property is set.
---
--- This function is called when the "DetailClass" property of a light is set. It performs the following actions:
---
--- 1. Destroys the render object of the light.
--- 2. If the light is set up to affect stealth, it calls the `Stealth_HandleLight` function to handle the light's stealth-related behavior.
---
--- @param prop_id string The ID of the property that was set.
--- @return nil
---
function Light:OnEditorSetProperty(prop_id)
	if prop_id == "DetailClass" then
		self:DestroyRenderObj()
		if IsLightSetupToAffectStealth(self) then
			Stealth_HandleLight(self)
		end
	end
end

AppendClass.Light = {
	stealth_light = false,
	old_handle = false,
}

AppendClass.ActionFXLight = {
	properties = {
		{ category = "Light",     id = "Sync",      editor = "bool",         default = false,   },
	},
}

---
--- Handles the behavior of an ActionFXLight when it is placed in the game world.
---
--- This function is called when an ActionFXLight is placed in the game world. It performs the following actions:
---
--- 1. Checks if the light is a sync object. If not, it returns without doing anything.
--- 2. Checks if the light is valid and is of the "Light" class. If not, it returns without doing anything.
--- 3. Checks if the light was created asynchronously. If so, it prints a warning message and returns without doing anything, as lights that affect stealth must be created in the game time thread.
--- 4. Calls the `Stealth_HandleLight` function to handle the light's stealth-related behavior, passing the "force_sl" parameter to indicate that the light should be handled as a stealth light.
---
--- @param fx The ActionFXLight object that was placed in the game world.
--- @param actor The actor associated with the ActionFXLight.
--- @param target The target associated with the ActionFXLight.
--- @param obj The object associated with the ActionFXLight.
--- @param spot The spot associated with the ActionFXLight.
--- @param posx The x-coordinate of the light's position.
--- @param posy The y-coordinate of the light's position.
--- @param posz The z-coordinate of the light's position.
--- @param angle The angle of the light.
--- @param axisx The x-component of the light's axis.
--- @param axisy The y-component of the light's axis.
--- @param axisz The z-component of the light's axis.
--- @param action_pos The position of the action.
--- @param action_dir The direction of the action.
--- @return nil
---
function ActionFXLight:OnLightPlaced(fx, actor, target, obj, spot, posx, posy, posz, angle, axisx, axisy, axisz, action_pos, action_dir)
	if not self.Sync then return end
	if not IsValid(fx) or not IsKindOf(fx, "Light") then return end
	if not IsGameTimeThread() then 
		if Platform.developer then
			print("Async light created from fx! This light won't affect stealth.")
			print("In order to affect stealth, use GameTime and do not attach it to an animated spot.")
		end
		--lights affect stealth, so we exepct them to come from gtt. if they dont we cant sync them
		return 
	end
	
	--all fx lights are handled by making a sync light and syncing hosts lights params to it periodically
	Stealth_HandleLight(fx, "force_sl")
end

---
--- Removes the stealth light associated with the given light object.
---
--- This function is used to clean up the stealth light object associated with a light object. It first checks if the light has a `stealth_light` property, which is a reference to the associated stealth light object. If the `stealth_light` property is not `nil`, it removes the stealth light object from the `StealthLights` table and then destroys the stealth light object using the `DoneObject` function. Finally, it sets the `stealth_light` property of the light object to `nil`.
---
--- @param light The light object to remove the associated stealth light from.
---
function KillStealthLightForLight(light)
	local o = light.stealth_light
	if o then
		table.remove_entry(StealthLights, o)
		DoneObject(o)
		light.stealth_light = nil
	end
end

---
--- Removes the stealth light associated with the given light object.
---
--- This function is used to clean up the stealth light object associated with a light object. It first checks if the light has a `stealth_light` property, which is a reference to the associated stealth light object. If the `stealth_light` property is not `nil`, it removes the stealth light object from the `StealthLights` table and then destroys the stealth light object using the `DoneObject` function. Finally, it sets the `stealth_light` property of the light object to `nil`.
---
--- @param light The light object to remove the associated stealth light from.
---
function ActionFXLight:OnLightDone(fx)
	KillStealthLightForLight(fx)
end

---
--- Attempts to retrieve the light object attached to the given visual object.
---
--- This function checks if the given visual object has a "Light" attachment, and if so, returns that light object. If not, it checks if the object has a "SpawnFXObject" attachment, and if so, it retrieves the "Light" attachment from that object.
---
--- @param obj The visual object to retrieve the light from.
--- @return The light object attached to the visual object, or `false` if no light is found.
---
function GetFXLightFromVisualObj(obj)
	--since users can use fx to put the light wherever, we need to guess where it is.
	local light = obj:GetAttach("Light") --glowstick, flare gun
	if light then
		return light
	end
	
	light = obj:GetAttach("SpawnFXObject") --flare
	light = light and light:GetAttach("Light") or false
	return light
end