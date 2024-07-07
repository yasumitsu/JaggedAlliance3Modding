DefineClass.AnimChangeHook =
{
	__parents = { "Object", "Movable" },
}

function AnimChangeHook:AnimationChanged(channel, old_anim, flags, crossfade)
end

---
--- Sets the animation state of the object.
---
--- @param anim string The name of the animation to set.
--- @param flags number Flags to control the animation behavior.
--- @param crossfade number The crossfade duration in seconds.
--- @param ... any Additional arguments to pass to the underlying `SetState` function.
--- @return none
---
function AnimChangeHook:SetState(anim, flags, crossfade, ...)
	local old_anim = self:GetStateText()
	if IsValid(self) and self:IsAnimEnd() then
		self:OnAnimMoment("end")
	end
	Object.SetState(self, anim, flags, crossfade, ...)
	self:AnimationChanged(1, old_anim, flags, crossfade)
end

local pfStep = pf.Step
local pfSleep = Sleep
---
--- Advances the object's position by one step and updates the animation state if the object's state has changed.
---
--- @param ... any Additional arguments to pass to the underlying `pf.Step` function.
--- @return boolean, table The status and new path returned by the `pf.Step` function.
---
function AnimChangeHook:Step(...)
	local old_state = self:GetState()
	local status, new_path = pfStep(self, ...)
	if old_state ~= self:GetState() then
		self:AnimationChanged(1, GetStateName(old_state), 0, nil)
	end
	return status, new_path
end

---
--- Sets the animation state of the object.
---
--- @param channel number The animation channel to set.
--- @param anim string The name of the animation to set.
--- @param flags number Flags to control the animation behavior.
--- @param crossfade number The crossfade duration in seconds.
--- @param ... any Additional arguments to pass to the underlying `SetState` function.
--- @return none
---
function AnimChangeHook:SetAnim(channel, anim, flags, crossfade, ...)
	local old_anim = self:GetStateText()
	Object.SetAnim(self, channel, anim, flags, crossfade, ...)
	self:AnimationChanged(channel, old_anim, flags, crossfade)
end

-- AnimMomentHook
DefineClass.AnimMomentHook =
{
	__parents = { "AnimChangeHook" },
	anim_moments_hook = false,				-- list with moments which have registered callback in the class
	anim_moments_single_thread = false,	-- if false every moment will have its own thread launched
	anim_moments_hook_threads = false,
	anim_moment_fx_target = false,
}

---
--- Initializes the AnimMomentHook object and starts the animation moment hook.
---
--- This function is called when the AnimMomentHook object is created. It starts the animation moment hook, which allows the object to track and respond to animation moments.
---
--- @function AnimMomentHook:Init
--- @return none
---
function AnimMomentHook:Init()
	self:StartAnimMomentHook()
end

---
--- Stops the animation moment hook for this object.
---
--- This function is called when the AnimMomentHook object is no longer needed. It stops the animation moment hook, which stops the object from tracking and responding to animation moments.
---
--- @function AnimMomentHook:Done
--- @return none
---
function AnimMomentHook:Done()
	self:StopAnimMomentHook()
end

---
--- Checks if the animation moment hook has been started for this object.
---
--- @return boolean true if the animation moment hook has been started, false otherwise
---
function AnimMomentHook:IsStartedAnimMomentHook()
	return self.anim_moments_hook_threads and true or false
end

---
--- Waits for the specified animation moment to occur.
---
--- This function will block until the specified animation moment is reached. It will repeatedly check the time to the next moment and wait until that time has elapsed, unless the object is woken up by some external event.
---
--- @param moment string The name of the animation moment to wait for
--- @return none
---
function AnimMomentHook:WaitAnimMoment(moment)
	repeat
		local t = self:TimeToMoment(1, moment)
		local index = 1
		while t == 0 do
			index = index + 1
			t = self:TimeToMoment(1, moment, index)
		end
	until not WaitWakeup(t) -- if someone wakes us up we need to measure again
end

moment_hooks = {}

---
--- Handles animation moments for the object.
---
--- This function is called when an animation moment is reached. It plays any associated FX for the moment, and also calls any registered hook functions for the moment.
---
--- @param moment string The name of the animation moment that was reached
--- @param anim string (optional) The name of the animation that the moment occurred in
---
function AnimMomentHook:OnAnimMoment(moment, anim)
	anim = anim or GetStateName(self)
	PlayFX(FXAnimToAction(anim), moment, self, self.anim_moment_fx_target or nil)
	local anim_moments_hook = self.anim_moments_hook
	if type(anim_moments_hook) == "table" and anim_moments_hook[moment] then
		local method = moment_hooks[moment]
		return self[method](self, anim)
	end
end

---
--- Waits for and tracks animation moments for the given object.
---
--- This function runs in a loop, continuously checking the object's animation state and waiting for the next animation moment to occur. When a moment is reached, it calls the provided callback function with the moment name and other relevant information.
---
--- @param obj table The object to track animation moments for
--- @param callback function (optional) The callback function to call when an animation moment is reached. If not provided, the object's `OnAnimMoment` method will be used.
--- @param ... any Additional arguments to pass to the callback function
---
function WaitTrackMoments(obj, callback, ...)
	callback = callback or obj.OnAnimMoment
	local last_state, last_phase, state_name, time, moment
	while true do
		local state, phase = obj:GetState(), obj:GetAnimPhase()
		if state ~= last_state then
			state_name = GetStateName(state)
			if phase == 0 then
				callback(obj, "start", state_name, ...)
			end
			time = nil
		end
		last_state, last_phase = state, phase
		if not time then
			moment, time = obj:TimeToNextMoment(1, 1)
		end
		if time then
			local time_to_end = obj:TimeToAnimEnd()
			if time_to_end <= time then
				if not WaitWakeup(time_to_end) then
					assert(IsValid(obj))
					callback(obj, "end", state_name, ...)
					if obj:IsAnimLooping(1) then
						callback(obj, "start", state_name, ...)
					end
					time = time - time_to_end
				else
					time = false
				end
			end
			-- if someone wakes us we need to query for a new moment
			if time then
				if time > 0 and WaitWakeup(time) then
					time = nil
				else
					assert(IsValid(obj))
					local index = 1
					repeat
						callback(obj, moment, state_name, ...)
						index = index + 1
						moment, time = obj:TimeToNextMoment(1, index)
					until time ~= 0
					if not time then
						WaitWakeup()
					end
				end
			end
		else
			WaitWakeup()
		end
	end
end

local gofRealTimeAnim = const.gofRealTimeAnim

---
--- Starts the animation moment hook for the current entity.
--- The animation moment hook is used to track specific animation moments and call corresponding methods on the entity.
--- This function creates one or more threads to monitor the animation moments and call the appropriate methods.
---
--- @param self AnimMomentHook The instance of the AnimMomentHook class.
---
function AnimMomentHook:StartAnimMomentHook()
	local moments = self.anim_moments_hook
	if not moments or self.anim_moments_hook_threads then
		return
	end
	if not IsValidEntity(self:GetEntity()) then 
		return 
	end
	local create_thread = self:GetGameFlags(gofRealTimeAnim) ~= 0 and CreateMapRealTimeThread or CreateGameTimeThread
	local threads
	if self.anim_moments_single_thread then
		threads = { create_thread(WaitTrackMoments, self) }
		ThreadsSetThreadSource(threads[1], "AnimMoment")
	else
		threads = { table.unpack(moments) }
		for _, moment in ipairs(moments) do
			threads[i] = create_thread(function(self, moment)
				local method = moment_hooks[moment]
				while true do
					self:WaitAnimMoment(moment)
					assert(IsValid(self))
					self[method](self)
				end
			end, self, moment)
			ThreadsSetThreadSource(threads[i], "AnimMoment")
		end
	end
	self.anim_moments_hook_threads = threads
end

---
--- Stops the animation moment hook for the current entity.
--- This function stops all the threads that were created to monitor the animation moments and call the corresponding methods.
---
--- @param self AnimMomentHook The instance of the AnimMomentHook class.
---
function AnimMomentHook:StopAnimMomentHook()
	local thread_list = self.anim_moments_hook_threads or ""
	for i = 1, #thread_list do
		DeleteThread(thread_list[i])
	end
	self.anim_moments_hook_threads = nil
end

--- Wakes up all the animation moment hook threads associated with the current entity.
--- This function is called when the animation state of the entity has changed, to ensure that the animation moment hooks are updated accordingly.
---
--- @param self AnimMomentHook The instance of the AnimMomentHook class.
function AnimMomentHook:AnimMomentHookUpdate()
	for i, thread in ipairs(self.anim_moments_hook_threads) do
		Wakeup(thread)
	end
end

AnimMomentHook.AnimationChanged = AnimMomentHook.AnimMomentHookUpdate

function OnMsg.ClassesPostprocess()
	local str_to_moment_list = {} -- optimized to have one copy of each unique moment list

	ClassDescendants("AnimMomentHook", function(class_name, class, remove_prefix, str_to_moment_list)
		local moment_list
		for name, func in pairs(class) do
			local moment = remove_prefix(name, "OnMoment")
			if type(func) == "function" and moment and moment ~= "" then
				moment_list = moment_list or {}
				moment_list[#moment_list + 1] = moment
			end
		end
		for name, func in pairs(getmetatable(class)) do
			local moment = remove_prefix(name, "OnMoment")
			if type(func) == "function" and moment and moment ~= "" then
				moment_list = moment_list or {}
				moment_list[#moment_list + 1] = moment
			end
		end
		if moment_list then
			table.sort(moment_list)
			for _, moment in ipairs(moment_list) do
				moment_list[moment] = true
				moment_hooks[moment] = moment_hooks[moment] or ("OnMoment" .. moment)
			end
			local str = table.concat(moment_list, " ")
			moment_list = str_to_moment_list[str] or moment_list
			str_to_moment_list[str] = moment_list
			rawset(class, "anim_moments_hook", moment_list)
		end
	end, remove_prefix, str_to_moment_list)
end

---
DefineClass.StepObjectBase =
{
	__parents = { "AnimMomentHook" },
}

function StepObjectBase:StopAnimMomentHook()
	AnimMomentHook.StopAnimMomentHook(self)
end

if not Platform.ged then
	function OnMsg.ClassesGenerate()
		AppendClass.EntitySpecProperties = {
			properties = {
				{ id = "FXTargetOverride", name = "FX target override", category = "Misc", default = false,
					editor = "combo", items = function(fx) return ActionFXClassCombo(fx) end, entitydata = true,
				},
				{ id = "FXTargetSecondary", name = "FX target secondary", category = "Misc", default = false,
					editor = "combo", items = function(fx) return ActionFXClassCombo(fx) end, entitydata = true,
				},
			},
		}
	end
end

---
--- Gets the material type and FX target override for the given object.
---
--- @param obj table The object to get the material and FX target from.
--- @return string The FX target override.
--- @return string The secondary FX target override.
function GetObjMaterialFXTarget(obj)
	local entity_data = obj and EntityData[obj:GetEntity()]
	entity_data = entity_data and entity_data.entity
	if entity_data and entity_data.FXTargetOverride then
		return entity_data.FXTargetOverride, entity_data.FXTargetSecondary
	end

	local mat_type = obj and obj:GetMaterialType()
	local material_preset = mat_type and (Presets.ObjMaterial.Default or empty_table)[mat_type]
	local fx_target = (material_preset and material_preset.FXTarget ~= "") and material_preset.FXTarget or mat_type
	
	return fx_target, entity_data and entity_data.FXTargetSecondary
end

local surface_fx_types = {}
local enum_decal_water_radius = const.AnimMomentHookEnumDecalWaterRadius

---
--- Gets the material type and FX target override for the given object.
---
--- @param pos Vector3 The position to get the material and FX target from.
--- @param obj table The object to get the material and FX target from.
--- @param surfaceType string The surface type, if already known.
--- @param fx_target_secondary string The secondary FX target override, if already known.
--- @return string The FX target.
--- @return Vector3 The surface position.
--- @return boolean Whether to propagate above.
--- @return string The secondary FX target.
function GetObjMaterial(pos, obj, surfaceType, fx_target_secondary)
	local surfacePos = pos
	if not surfaceType and obj then
		surfaceType, fx_target_secondary = GetObjMaterialFXTarget(obj)
	end

	local propagate_above
	if pos and not surfaceType then
		propagate_above = true
		if terrain.IsWater(pos) then
			local water_z = terrain.GetWaterHeight(pos)
			local dz = (pos:z() or terrain.GetHeight(pos)) - water_z
			if dz >= const.FXWaterMinOffsetZ and dz <= const.FXWaterMaxOffsetZ then
				if const.FXShallowWaterOffsetZ > 0 and dz > -const.FXShallowWaterOffsetZ then
					surfaceType = "ShallowWater"
				else
					surfaceType = "Water"
				end
				surfacePos = pos:SetZ(water_z)
			end
		end
		if not surfaceType and enum_decal_water_radius then
			local decal = MapFindNearest(pos, pos, enum_decal_water_radius, "TerrainDecal", function (obj, pos)
				if pos:InBox2D(obj) then
					local dz = (pos:z() or terrain.GetHeight(pos)) - select(3, obj:GetVisualPosXYZ())
					if dz <= const.FXDecalMaxOffsetZ and dz >= const.FXDecalMinOffsetZ then
						return true
					end
				end
			end, pos)
			if decal then
				surfaceType = decal:GetMaterialType()
				if surfaceType then
					surfacePos = pos:SetZ(select(3, decal:GetVisualPosXYZ()))
				end
			end
		end
		if not surfaceType then
			-- get the surface type
			local walkable_slab = const.SlabSizeX and WalkableSlabByPoint(pos) or GetWalkableObject(pos)
			if walkable_slab then
				surfaceType = walkable_slab:GetMaterialType()
				if surfaceType then
					surfacePos = pos:SetZ(select(3, walkable_slab:GetVisualPosXYZ()))
				end
			else
				local terrain_preset = TerrainTextures[terrain.GetTerrainType(pos)]
				surfaceType = terrain_preset and terrain_preset.type
				if surfaceType then
					surfacePos = pos:SetTerrainZ()
				end
			end
		end
	end
	
	local fx_type
	if surfaceType then
		fx_type = surface_fx_types[surfaceType]
		if not fx_type then			-- cache it for later use
			fx_type = "Surface:" .. surfaceType
			surface_fx_types[surfaceType] = fx_type
		end
	end
	local fx_type_secondary
	if fx_target_secondary then
		fx_type_secondary = surface_fx_types[fx_target_secondary]
		if not fx_type_secondary then			-- cache it for later use
			fx_type_secondary = "Surface:" .. fx_target_secondary
			surface_fx_types[fx_target_secondary] = fx_type_secondary
		end
	end

	return fx_type, surfacePos, propagate_above, fx_type_secondary
end


local enum_bush_radius = const.AnimMomentHookTraverseVegetationRadius

---
--- Plays step surface FX for the given foot and spot name.
---
--- @param foot string The foot name, either "FootLeft" or "FootRight".
--- @param spot_name string The spot name to get the random spot from.
--- @return nil
function StepObjectBase:PlayStepSurfaceFX(foot, spot_name)
	local spot = self:GetRandomSpot(spot_name)
	local pos = self:GetSpotLocPos(spot)
	local surface_fx_type, surface_pos, propagate_above = GetObjMaterial(pos)

	if surface_fx_type then
		local angle, axis = self:GetSpotVisualRotation(spot)
		local dir = RotateAxis(axis_x, axis, angle)
		local actionFX = self:GetStepActionFX()
		PlayFX(actionFX, foot, self, surface_fx_type, surface_pos, dir)
	end

	if propagate_above and enum_bush_radius then
		local bushes = MapGet(pos, enum_bush_radius, "TraverseVegetation", function(obj, pos) return pos:InBox(obj) end, pos)
		if bushes and bushes[1] then
			local veg_event = PlaceObject("VegetationTraverseEvent")
			veg_event:SetPos(pos)
			veg_event:SetActors(self, bushes)
		end
	end
end

---
--- Returns the step action FX name.
---
--- @return string The step action FX name.
function StepObjectBase:GetStepActionFX()
	return "Step"
end

DefineClass.StepObject = {
	__parents = { "StepObjectBase" },
}

---
--- Plays step surface FX for the given left foot and spot name.
---
--- @param self StepObject The StepObject instance.
--- @param spot_name string The spot name to get the random spot from.
--- @return nil
function StepObject:OnMomentFootLeft()
	self:PlayStepSurfaceFX("FootLeft", "Leftfoot")
end

---
--- Plays step surface FX for the given right foot and spot name.
---
--- @param self StepObject The StepObject instance.
--- @param spot_name string The spot name to get the random spot from.
--- @return nil
function StepObject:OnMomentFootRight()
	self:PlayStepSurfaceFX("FootRight", "Rightfoot")
end

function OnMsg.GatherFXActions(list)
	list[#list+1] = "Step"
end

function OnMsg.GatherFXTargets(list)
	local added = {}
	ForEachPreset("TerrainObj", function(terrain_preset)
		local type = terrain_preset.type
		if type ~= "" and not added[type] then
			list[#list+1] = "Surface:" .. type
			added[type] = true
		end
	end)
	local material_types = PresetsCombo("ObjMaterial")()
	for i = 2, #material_types do
		local type = material_types[i]
		if not added[type] then
			list[#list+1] = "Surface:" .. type
			added[type] = true
		end
	end
end

DefineClass.AutoAttachAnimMomentHookObject = {
	__parents = {"AutoAttachObject", "AnimMomentHook"},
	
	anim_moments_single_thread = true,
	anim_moments_hook = true,
}

---
--- Sets the state of the AutoAttachAnimMomentHookObject.
---
--- This function calls the `SetState` functions of both the `AutoAttachObject` and `AnimMomentHook` classes, allowing the object to update its state accordingly.
---
--- @param self AutoAttachAnimMomentHookObject The AutoAttachAnimMomentHookObject instance.
--- @param ... any Additional arguments to pass to the `SetState` functions.
--- @return nil
function AutoAttachAnimMomentHookObject:SetState(...)
	AutoAttachObject.SetState(self, ...)
	AnimMomentHook.SetState(self, ...)
end

--- Calls the `OnAnimMoment` function of the `AnimMomentHook` class with the provided `moment` and `anim` arguments.
---
--- This function is part of the `AutoAttachAnimMomentHookObject` class, which inherits from both `AutoAttachObject` and `AnimMomentHook`. It allows the object to handle animation moments by delegating the logic to the `AnimMomentHook` class.
---
--- @param self AutoAttachAnimMomentHookObject The `AutoAttachAnimMomentHookObject` instance.
--- @param moment string The animation moment to handle.
--- @param anim string The animation that triggered the moment.
--- @return any The result of calling `AnimMomentHook.OnAnimMoment(self, moment, anim)`.
function AutoAttachAnimMomentHookObject:OnAnimMoment(moment, anim)
	return AnimMomentHook.OnAnimMoment(self, moment, anim)
end