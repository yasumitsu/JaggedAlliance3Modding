DefineClass.UnitStain = {
	__parents = { "InitDone", "SkinDecalData" },
	properties = {
		{ id = "SpotIdx", editor = "number", default = -1 },
		{ id = "Rotation", editor = "number", default = -1 },
		{ id = "initialized", editor = "bool", default = false },
	},
	decal = false,
}

--- Cleans up the UnitStain object by destroying the decal object and setting it to nil.
function UnitStain:Done()
	if self.decal then
		DoneObject(self.decal)
		self.decal = nil
	end
end

--- Returns a unique name for a UnitStain based on the base entity, stain type, and spot.
---
--- @param base_entity string The base entity of the unit.
--- @param stain_type string The type of stain.
--- @param spot string The spot on the unit where the stain is applied.
--- @return string The unique name for the UnitStain.
function UnitStainPresetName(base_entity, stain_type, spot)
	return string.format("%s-%s-%s", spot, stain_type, base_entity)
end

---
--- Copies the properties from one UnitStain object to another.
---
--- @param from UnitStain The UnitStain object to copy properties from.
--- @param to UnitStain The UnitStain object to copy properties to.
---
function CopyUnitStainProperties(from, to)
	local props = from:GetProperties()
	for _, prop in ipairs(props) do
		if to:GetPropertyMetadata(prop.id) then
			to:SetProperty(prop.id, from:GetProperty(prop.id))
		end
	end	
end

---
--- Initializes the parameters for a UnitStain object.
---
--- @param unit Unit The unit to which the stain is being applied.
--- @param params table A table of parameters to apply to the UnitStain object.
--- @return boolean True if the UnitStain object was successfully initialized, false otherwise.
---
function UnitStain:InitParams(unit, params)
	if self.Spot == "" or self.DecType == "" then
		return
	end
	
	local base_entity = GetAnimEntity(unit:GetEntity(), unit:GetState())
	
	-- check for existing preset
	local id = UnitStainPresetName(base_entity, self.DecType, self.Spot)
	local preset = Presets.SkinDecalMetadata.Default and Presets.SkinDecalMetadata.Default[id]
	local base = Presets.SkinDecalType.Default[self.DecType]
	if preset then
		CopyUnitStainProperties(preset, self)
	elseif base then
		self.DecEntity = base.DefaultEntity
		self.DecScale = base.DefaultScale
	else
		print("unknown stain type: ", self.DecType)
	end
	
	local min, max = unit:GetSpotRange(self.Spot)	
	if min < 0 or max < 0 then
		return
	end
	self.SpotIdx = min + AsyncRand(max - min)
	self.Rotation = self.DecAttachAngleRange.from*60 + AsyncRand(self.DecAttachAngleRange.to*60 - self.DecAttachAngleRange.from*60)
	
	for param, value in pairs(params) do
		if self:GetPropertyMetadata(param) then
			self:SetProperty(param, value)
		end
	end
	
	self.initialized = true
	return true
end

---
--- Applies a UnitStain object to a unit.
---
--- @param unit Unit The unit to which the stain is being applied.
--- @param params table A table of parameters to apply to the UnitStain object.
--- @return SkinDecal The SkinDecal object that was created and attached to the unit.
---
function UnitStain:Apply(unit, params)
	if self.Spot == "" or self.DecType == "" then
		return
	end
	if self.decal then
		DoneObject(self.decal)
		self.decal = nil
	end
	
	if self.initialized then
		local min, max = unit:GetSpotRange(self.Spot)
		if self.SpotIdx < min or self.SpotIdx > max then
			self.initialized = false
		end
	end

	if not self.initialized and not self:InitParams(unit, params) then
		return
	end

	local dec = PlaceObject("SkinDecal")
	dec:ChangeEntity(self.DecEntity)
	unit:Attach(dec, self.SpotIdx, true)

	local axis, angle = ComposeRotation(axis_y, self.InvertFacing and -90*60 or 90*60, SkinDecalAttachAxis[self.DecAttachAxis], self.Rotation)

	dec:SetAttachAxis(axis)
	dec:SetAttachAngle(angle)
	dec:SetScale(self.DecScale)
	dec:SetAttachOffset(point(self.DecOffsetX * (self.InvertFacing and -1 or 1), self.DecOffsetY, self.DecOffsetZ))
	dec:SetColorModifier(self.ClrMod)
	self.decal = dec
	return dec
end

---
--- Adds a new UnitStain object to a unit.
---
--- @param stain_type string The type of stain to apply.
--- @param spot string The spot on the unit where the stain should be applied.
--- @param params table A table of parameters to apply to the UnitStain object.
--- @return UnitStain The UnitStain object that was created and added to the unit.
---
function Unit:AddStain(stain_type, spot, params)
	local stain = UnitStain:new()
	stain.DecType = stain_type
	stain.Spot = spot
	
	self.stains = self.stains or {}
	table.insert(self.stains, stain)
		
	stain:Apply(self, params)	
	
	return stain
end

---
--- Removes stains of the specified type from the unit, optionally only from the specified spots.
---
--- @param stain_type string The type of stain to remove.
--- @param ... string The spots to remove the stains from. If no spots are provided, all stains of the specified type will be removed.
---
function Unit:ClearStains(stain_type, ...)
end
function Unit:ClearStains(stain_type, ...) -- spots to clear
	if not self.stains then return end
	local nspots = select("#", ...)
	for i = #self.stains, 1, -1 do
		local stain = self.stains[i]
		if stain.DecType == stain_type then
			local match
			for j = 1, nspots do
				local spot = select(j, ...)
				if spot == stain.Spot then
					match = true
					break
				end
			end
			if nspots == 0 or match then
				DoneObject(stain)
				table.remove(self.stains, i)
			end
		end
	end
end

---
--- Removes stains of the specified type from the unit, optionally only from the specified spots.
---
--- @param ... string The spots to remove the stains from. If no spots are provided, all stains of the specified type will be removed.
---
function Unit:ClearStainsFromSpots(...) -- spots to clear
	if not self.stains then return end	
	local nspots = select("#", ...)
	for i = #self.stains, 1, -1 do
		local stain = self.stains[i]
		local match
		for j = 1, nspots do
			local spot = select(j, ...)
			if spot == stain.Spot then
				match = true
				break
			end
		end
		if nspots == 0 or match then
			DoneObject(stain)
			table.remove(self.stains, i)
		end		
	end
end

---
--- Removes stains from the specified spot on the unit, if the stain type is marked as cleared by water.
---
--- @param spot string The spot to remove stains from. If no spot is provided, all stains cleared by water will be removed.
---
function Unit:WashStainsFromSpot(spot) -- cleared by water, checks ClearedByWater flag from stain type
	if not self.stains then return end	
	for i = #self.stains, 1, -1 do
		local stain = self.stains[i]
		if (not spot or stain.Spot == spot) and SkinDecalTypes[stain.DecType] and SkinDecalTypes[stain.DecType].ClearedByWater then
			DoneObject(stain)
			table.remove(self.stains, i)
		end
	end
end

---
--- Checks if the unit can have a stain of the specified type on the specified spot.
---
--- @param stain_type string The type of stain to check for.
--- @param spot string The spot on the unit to check for the stain.
--- @return boolean true if the unit can have the stain, false otherwise.
---
function Unit:CanStain(stain_type, spot)
	local target_prio = SkinDecalTypes[stain_type] and SkinDecalTypes[stain_type].SortKey or 0
	for _, stain in ipairs(self.stains) do
		if stain.Spot == spot then
			local curr_prio = SkinDecalTypes[stain.DecType] and SkinDecalTypes[stain.DecType].SortKey or 0
			if curr_prio >= target_prio then
				return false
			end
		end
	end
	return true
end

---
--- Checks if the unit has a stain of the specified type.
---
--- @param stain_type string The type of stain to check for.
--- @return boolean true if the unit has a stain of the specified type, false otherwise.
---
function Unit:HasStainType(stain_type)
	for _, stain in ipairs(self.stains) do
		if stain.DecType == stain_type then
			return true
		end
	end
end

local StainSpotGroups = {
	Head = { "Head", "Neck" },
	Torso = { "Ribslowerl", "Ribslowerr", "Ribsupperl", "Ribsupperr", "Torso", "Shoulderl", "Shoulderr" },
	Groin = { "Groin", "Pelvisl", "Pelvisr" },
	Arms = { "Shoulderl", "Shoulderr", "Elbowl", "Elbowr", "Wristl", "Wristr" },
	Legs = { "Kneel", "Kneer", "Anklel", "Ankler" },
	[false] = { "Ribslowerl", "Ribslowerr", "Ribsupperl", "Ribsupperr", "Torso", "Shoulderl", "Shoulderr", "Groin", "Pelvisl", "Pelvisr" },
}

---
--- Checks if the specified spots are valid for the currently selected object.
--- This function iterates through the StainSpotGroups table and checks if the
--- currently selected object has all the spots defined in each group. If a spot
--- is not found, a warning message is printed.
---
--- @param none
--- @return none
---
function CheckStainSpotGroups()
	if not SelectedObj then return end
	for group, list in pairs(StainSpotGroups) do
		for _, spot in ipairs(list) do
			if not SelectedObj:HasSpot(spot) then
				printf("Invalid spot %s in group %s", spot, group)
			end
		end
	end
end

---
--- Gets a random stain spot from the specified spot group.
---
--- @param spot_group string|nil The spot group to get a random spot from. If nil, the "false" spot group is used.
--- @return string The random stain spot.
---
function GetRandomStainSpot(spot_group)
	local spot_group = StainSpotGroups[spot_group or false] or StainSpotGroups[false]
	local spot = table.rand(spot_group) -- cut off the returned index
	return spot
end

---
--- Calculates the parameters for applying a stain on a target unit based on a shot.
---
--- @param target Unit The target unit to apply the stain on.
--- @param attacker Unit The unit that fired the shot.
--- @param hit table The hit information, including the shot direction and impact force.
--- @return string The name of the nearest spot to apply the stain on.
--- @return table The parameters for applying the stain, including the offset, orientation, and scale.
---
function CalcStainParamsFromShot(target, attacker, hit)
	-- find the nearest spot to the hit position, calculate the offset/orientation/facing to match it from that spot
	local spots_data = GetEntitySpots(target:GetEntity())
	local nearest_spot, nearest_dist, nearest_idx
	local hit_pos = hit.pos or target:GetSpotLocPos(target:GetSpotBeginIndex("Torso"))
	local attack_dir = SetLen(hit.shot_dir or (hit_pos - attacker:GetPos()), guim)
	for spot, spot_indices in pairs(spots_data) do
		for _, spot_idx in ipairs(spot_indices) do
			local pos, angle, axis, scale = target:GetSpotLoc(spot_idx)
			local dist = pos:Dist(hit_pos)
			if not nearest_dist or dist < nearest_dist then
				nearest_spot, nearest_dist, nearest_idx = spot, dist, spot_idx
			end
		end
	end
	--printf("nearest spot: %s (%d)", tostring(nearest_spot), nearest_idx or -1)
	if nearest_idx then
		local pos, angle, axis, scale = target:GetSpotLoc(nearest_idx)
		local spot_x = RotateAxis(point(guim, 0, 0), axis, angle)
		local spot_y = RotateAxis(point(0, guim, 0), axis, angle)
		local spot_z = RotateAxis(point(0, 0, guim), axis, angle)
		local invert_facing = false
		if Dot2D(spot_x, attack_dir) > 0 then
			invert_facing = true
		end

		local v = hit_pos - pos
		local ox = Dot(spot_x, v) / guim
		local oy = Dot(spot_y, v) / guim
		local oz = Dot(spot_z, v) / guim
		
		return nearest_spot, {
			InvertFacing = invert_facing,
			DecOffsetX = ox,
			DecOffsetY = oy,
			DecOffsetZ = oz,
			DecScale = (hit.impact_force or 0) > 0 and 100 or 60,
		}
	end
end

local StainApplyInterval = 3000 -- minimum time before rechecking if we should apply a stain on the same spot
local StainChanceStanding = 10
local StainChanceCrouch = 80
local StainChanceProne = 100
local StainClearChance = 90 -- when moving in water/shallowwater

local function check_stain_update_timer(stain_update_times, spot, time)
	local update_time = stain_update_times[spot] or time
	if time >= update_time then
		stain_update_times[spot] = time + StainApplyInterval -- timestamp the update
		return true
	end
end

---
--- Updates the stains on a unit's body based on the surface material and the unit's stance.
---
--- This function is called when a unit takes a step, either with the left or right foot.
--- It checks the surface material and the unit's stance to determine the appropriate stain type and location.
--- If the surface is water or shallow water, it clears any existing stains. Otherwise, it adds new stains based on the surface material and the unit's stance.
---
--- @param foot string The foot that the unit stepped with, either "left" or "right".
function Unit:WalkUpdateStains(foot)
	-- ATTN: FX code, keep it async
	local surf_fx_type = GetObjMaterial(self:GetVisualPos())
	local time = GameTime()
	local stain_update_times = self.stain_update_times

	if surf_fx_type == "Surface:Water" or surf_fx_type == "Surface:ShallowWater" then -- clearing stains instead of adding
		-- feet spots (any stance)
		local spot = (foot == "left") and "Leftfoot" or "Rightfoot"
		if check_stain_update_timer(stain_update_times, spot, time) and AsyncRand(100) < StainClearChance then
			self:WashStainsFromSpot(spot)
		end		
		-- knee spots (Prone/Crouch)
		if self.stance ~= "Standing" then
			local spot = (foot == "left") and "Kneel" or "Kneer"
			if check_stain_update_timer(stain_update_times, spot, time) and AsyncRand(100) < StainClearChance then
				self:WashStainsFromSpot(spot)
			end
		end
		-- shoulder spots (Prone only)
		if self.stance == "Prone" then
			local spot = (foot == "left") and "Shoulderl" or "Shoulderr" -- maybe reverse the shoulders?
			if check_stain_update_timer(stain_update_times, spot, time) and AsyncRand(100) < StainClearChance then
				self:WashStainsFromSpot(spot)
			end
		end
		return
	end
		
	-- adding mud/dirt
	local stain_type
	if surf_fx_type == "Surface:Mud" then
		stain_type = "Mud"
	elseif surf_fx_type == "Surface:Dirt" or surf_fx_type == "Surface:Sand" then
		stain_type = "Dirt"
	end	
	if not stain_type then return end
	
	local stain_chance = StainChanceStanding
	if self.stance == "Crouch" then
		stain_chance = StainChanceCrouch
	elseif self.stance == "Prone" then
		stain_chance = StainChanceProne
	end
	
	-- feet spots (any stance)
	local spot = (foot == "left") and "Leftfoot" or "Rightfoot"
	if check_stain_update_timer(stain_update_times, spot, time) and AsyncRand(100) < stain_chance and self:CanStain(stain_type, spot) then
		self:ClearStainsFromSpots(spot)
		self:AddStain(stain_type, spot)
	end
	
	-- knee spots (Prone/Crouch)
	if self.stance ~= "Standing" then
		local spot = (foot == "left") and "Kneel" or "Kneer"
		if check_stain_update_timer(stain_update_times, spot, time) and AsyncRand(100) < stain_chance and self:CanStain(stain_type, spot) then
			self:ClearStainsFromSpots(spot)
			self:AddStain(stain_type, spot)
		end
	end
	
	-- shoulder spots (Prone only)
	if self.stance == "Prone" then
		local spot = (foot == "left") and "Shoulderl" or "Shoulderr" -- maybe reverse the shoulders?
		if check_stain_update_timer(stain_update_times, spot, time) and AsyncRand(100) < stain_chance and self:CanStain(stain_type, spot) then
			self:ClearStainsFromSpots(spot)
			self:AddStain(stain_type, spot)
		end
	end
end

--- Handles the logic for updating unit stains when the left foot steps.
---
--- If the unit's team is not neutral, this function calls `self:WalkUpdateStains("left")` to update the unit's stains.
--- It then calls the parent `StepObject.OnMomentFootLeft(self)` function to handle the default step logic.
---
--- @param self Unit The unit object.
--- @return any The return value of the parent `StepObject.OnMomentFootLeft(self)` function.
function Unit:OnMomentFootLeft()
	if self.team and self.team.side ~= "neutral" then 
		self:WalkUpdateStains("left")	
	end
	return StepObject.OnMomentFootLeft(self)
end

--- Handles the logic for updating unit stains when the right foot steps.
---
--- If the unit's team is not neutral, this function calls `self:WalkUpdateStains("right")` to update the unit's stains.
--- It then calls the parent `StepObject.OnMomentFootRight(self)` function to handle the default step logic.
---
--- @param self Unit The unit object.
--- @return any The return value of the parent `StepObject.OnMomentFootRight(self)` function.
function Unit:OnMomentFootRight()
	if self.team and self.team.side ~= "neutral" then 
		self:WalkUpdateStains("right")
	end
	return StepObject.OnMomentFootRight(self)
end

function OnMsg.EnterSector()
	for _, unit in ipairs(g_Units) do
		if not unit:IsDead() and not unit:HasStatusEffect("Wounded") then
			unit:ClearStains("Blood")
		end
	end
end