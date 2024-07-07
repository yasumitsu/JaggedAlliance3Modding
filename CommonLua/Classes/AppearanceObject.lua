DefineClass.AppearanceObjectPart = {
	__parents = { "CObject", "ComponentAnim", "ComponentAttach", "ComponentCustomData" },
	flags = { gofSyncState = true, cofComponentColorizationMaterial = true },
}

--- Returns a list of valid animation names for the given character.
---
--- The function filters the list of all animation names to only include those that do not end with a '*' character.
---
--- @param character CObject The character object to get the valid animation names for.
--- @return table A table of valid animation names.
function ValidAnimationsCombo(character)
	local all_anims = character:GetStatesTextTable()
	
	local valid_anims = {}
	for _, anim in ipairs(all_anims) do
		if anim:sub(-1, -1) ~= "*" then
			table.insert(valid_anims, anim)
		end
	end
	
	return valid_anims
end

DefineClass.AppearanceObject = {
	__parents = { "Shapeshifter", "StripComponentAttachProperties", "ComponentAnim"},
	flags = { gofSyncState = true, cofComponentColorizationMaterial = true },

	properties =
	{
		{ category = "Animation", id = "Appearance", name = "Appearance", editor = "preset_id", preset_class = "AppearancePreset", default = "" },
		{ category = "Animation", id = "anim", name = "Animation", editor = "dropdownlist", items = ValidAnimationsCombo, default = "idle" },
		{ category = "Animation Blending", id = "animWeight", name = "Animation Weight", editor = "number", slider = true, min = 0, max = 100, default = 100, help = "100 means only Animation is played, 0 means only Animation 2 is played, 50 means both animations are blended equally" },
		{ category = "Animation Blending", id = "animBlendTime", name = "Animation Blend Time", editor = "number", min = 0, default = 0 },
		{ category = "Animation Blending", id = "anim2", name = "Animation 2", editor = "dropdownlist", items = function(character) local list = character:GetStatesTextTable() table.insert(list, 1, "") return list end, default = "" },
		{ category = "Animation Blending", id = "anim2BlendTime", name = "Animation 2 Blend Time", editor = "number", min = 0, default = 0 },
	},
	
	fallback_body = config.DefaultAppearanceBody,
	parts = false,

	animFlags  = 0,
	animCrossfade = 0,
	anim2Flags = 0,
	anim2Crossfade = 0,

	attached_parts = { "Head", "Pants", "Shirt", "Armor", "Hat", "Hat2", "Hair", "Chest", "Hip" },
	animated_parts = { "Head", "Pants", "Shirt", "Armor" },
	appearance_applied = false,

	anim_speed = 1000,
}

--- Called after the object is loaded from a save file.
--- Applies the appearance settings to the object.
function AppearanceObject:PostLoad()
	self:ApplyAppearance()
end

--- Called when a property of the AppearanceObject is set in the editor.
---
--- If the "Appearance" property is set, this function applies the appearance settings to the object.
---
--- @param prop_id string The ID of the property that was set.
function AppearanceObject:OnEditorSetProperty(prop_id)
	if prop_id == "Appearance" then
		self:ApplyAppearance()
	end
end

--- Sets the animation for the AppearanceObject.
---
--- @param anim string The name of the animation to set.
function AppearanceObject:Setanim(anim)
	self.anim = anim
	self:SetAnimHighLevel()
end

--- Sets the secondary animation for the AppearanceObject.
---
--- @param anim string The name of the secondary animation to set.
function AppearanceObject:Setanim2(anim)
	self.anim2 = anim
	self:SetAnimHighLevel()
end

--- Sets the animation flags for the AppearanceObject.
---
--- @param anim_flags number The animation flags to set.
function AppearanceObject:SetanimFlags(anim_flags)
	self.animFlags = anim_flags
end

--- Sets the crossfade duration for the primary animation of the AppearanceObject.
---
--- @param crossfade number The crossfade duration in milliseconds.
function AppearanceObject:SetanimCrossfade(crossfade)
	self.animCrossfade = crossfade
end

--- Sets the animation flags for the secondary animation of the AppearanceObject.
---
--- @param anim_flags number The animation flags to set for the secondary animation.
function AppearanceObject:Setanim2Flags(anim_flags)
	self.anim2Flags = anim_flags
end

--- Sets the crossfade duration for the secondary animation of the AppearanceObject.
---
--- @param crossfade number The crossfade duration in milliseconds.
function AppearanceObject:Setanim2Crossfade(crossfade)
	self.anim2Crossfade = crossfade
end

--- Sets the animation weight for the AppearanceObject.
---
--- @param weight number The animation weight to set, between 0 and 100.
function AppearanceObject:SetanimWeight(weight)
	self.animWeight = weight
	self:SetAnimHighLevel()
end

--- Sets the animation channel for the AppearanceObject.
---
--- @param channel number The animation channel to set.
--- @param anim string The name of the animation to set.
--- @param anim_flags number The animation flags to set.
--- @param crossfade number The crossfade duration in milliseconds.
--- @param weight number The animation weight to set, between 0 and 100.
--- @param blend_time number The blend time in milliseconds.
--- @return number The duration of the animation in milliseconds.
function AppearanceObject:SetAnimChannel(channel, anim, anim_flags, crossfade, weight, blend_time)
	if not self:HasState(anim) then
		if self:GetEntity() ~= "" then
			StoreErrorSource(self, "Missing object state " .. self:GetEntity() .. "." .. anim)
		end
		return
	end
	Shapeshifter.SetAnim(self, channel, anim, anim_flags, crossfade)
	Shapeshifter.SetAnimWeight(self, channel, 100)
	Shapeshifter.SetAnimWeight(self, channel, weight, blend_time)
	self:SetAnimSpeed(channel, self.anim_speed)
	local parts = self.parts
	if parts then
		for _, part_name in ipairs(self.animated_parts) do
			local part = parts[part_name]
			if part then
				part:SetAnim(channel, anim, anim_flags, crossfade)
				part:SetAnimWeight(channel, 100)
				part:SetAnimWeight(channel, weight, blend_time)
				part:SetAnimSpeed(channel, self.anim_speed)
			end
		end
	end
	return GetAnimDuration(self:GetEntity(), self:GetAnim(channel))
end

--- Sets the animation channels for the AppearanceObject.
---
--- This function applies the appearance of the AppearanceObject and sets the animation channels. It sets the primary animation channel with the specified animation, crossfade, weight, and blend time. If a secondary animation is specified, it sets the secondary animation channel with the specified animation, crossfade, weight, and blend time. The function returns the maximum duration of the animations.
---
--- @param self AppearanceObject The AppearanceObject instance.
--- @return number The maximum duration of the animations in milliseconds.
function AppearanceObject:SetAnimLowLevel()
	self:ApplyAppearance()
	local time = self:SetAnimChannel(1, self.anim, self.animFlags, self.animCrossfade, self.animWeight, self.animBlendTime)
	if self.anim2 ~= "" then
		local time2, duration2 = self:SetAnimChannel(2, self.anim2, self.anim2Flags, self.anim2Crossfade, 100 - self.animWeight, self.anim2BlendTime)
		time = Max(time, time2)
	end
	return time
end

--- Sets the animation channels for the AppearanceObject at a high level.
---
--- This function calls the `SetAnimLowLevel()` function to apply the appearance of the AppearanceObject and set the animation channels.
---
--- @param self AppearanceObject The AppearanceObject instance.
--- @return number The maximum duration of the animations in milliseconds.
function AppearanceObject:SetAnimHighLevel()
	self:SetAnimLowLevel()
end

--- Sets the entity for the AppearanceObject.
---
--- This function sets the entity for the AppearanceObject. It is likely used to associate the AppearanceObject with a specific game entity.
---
--- @param self AppearanceObject The AppearanceObject instance.
function AppearanceObject:SetEntity()
end

local function get_part_offset_angle(appearance, prop_name)
	local x = appearance[prop_name .. "AttachOffsetX"] or 0
	local y = appearance[prop_name .. "AttachOffsetY"] or 0
	local z = appearance[prop_name .. "AttachOffsetZ"] or 0
	local angle = appearance[prop_name .. "AttachOffsetAngle"] or 0
	if x ~= 0 or y ~= 0 or z ~= 0 or angle ~= 0 then
		return point(x, y, z), angle
	end
end

-- overload this in project
config.DefaultAppearanceBody = "ErrorAnimatedMesh"

--- Colorizes a specific part of the AppearanceObject.
---
--- This function applies the color settings for a specific part of the AppearanceObject. It retrieves the color information from the appearance preset and sets the coloration palette and material properties for the part.
---
--- @param self AppearanceObject The AppearanceObject instance.
--- @param part_name string The name of the part to colorize.
function AppearanceObject:ColorizePart(part_name)
	local appearance = AppearancePresets[self.Appearance]
	local prop_color_name = string.format("%sColor", part_name)
	if not appearance:HasMember(prop_color_name) then return end
	
	local part = self.parts[part_name]
	local color_member = appearance[prop_color_name]
	if not color_member then 
		print("once", string.format("[WARNING] No color specified for %s in %s", part_name, self.Appearance))
		return 
	end
	local palette = color_member["ColorizationPalette"]
	part:SetColorizationPalette(palette)
	for i = 1, const.MaxColorizationMaterials do
		if string.match(part_name, "Hair") then
			local custom = {}
			for i = 1, 4 do
				custom[i] = appearance["HairParam" .. i]
			end
			part:SetHairCustomParams(custom)
		end
		local color = color_member[string.format("EditableColor%d", i)]
		local roughness = color_member[string.format("EditableRoughness%d", i)]
		local metallic = color_member[string.format("EditableMetallic%d", i)]
		part:SetColorizationMaterial(i, color, roughness, metallic)
	end
end

---
--- Attaches a part to the AppearanceObject and applies any necessary offsets or angles.
---
--- @param self AppearanceObject The AppearanceObject instance.
--- @param part_name string The name of the part to attach.
function AppearanceObject:ApplyPartSpotAttachments(part_name)
	local appearance = AppearancePresets[self.Appearance]
	local part = self.parts[part_name]
	local spot_prop = part_name .. "Spot"
	local prop_spot = appearance:HasMember(spot_prop) and appearance[spot_prop]
	local spot_name = prop_spot or "Origin"
	self:Attach(part, self:GetSpotBeginIndex(spot_name))
	if part_name == "Hat" or part_name == "Hat2" then
		local offset, angle = get_part_offset_angle(appearance, part_name)
		if offset and angle then
			part:SetAttachOffset(offset)
			part:SetAttachAngle(angle)
		end
	end
end

---
--- Applies the specified appearance to the AppearanceObject.
---
--- @param appearance string|table The appearance to apply. Can be a string ID or a table of appearance data.
--- @param force boolean If true, the appearance will be applied even if it's the same as the current appearance.
---
function AppearanceObject:ApplyAppearance(appearance, force)
	appearance = appearance or self.Appearance
	
	if not appearance then return end
	if not force and self.appearance_applied == appearance then return end
	
	self.appearance_applied = appearance
	if type(appearance) == "string" then
		self.Appearance = appearance
		appearance = AppearancePresets[appearance]
	else
		self.Appearance = appearance.id
	end
	if not appearance then
		local prop_meta = AppearanceObject:GetPropertyMetadata("Appearance")
		appearance = AppearancePresets[prop_meta.default]
		if not appearance then
			StoreErrorSource(self, "Default Appearance can't be invalid!")
		end
		appearance = AppearancePresets[self.Appearance]
		if not appearance then
			StoreErrorSource(self, string.format("Invalid appearance '%s'", self.Appearance))
			return 
		end
	end
	for _, part in pairs(self.parts) do
		DoneObject(part)
	end
	self:ChangeEntity(appearance.Body or self.fallback_body or config.DefaultAppearanceBody)
	if not IsValidEntity(self:GetEntity()) then
		StoreErrorSource(self, string.format("Invalid entity '%s'(%s) for Appearance '%s'", self:GetEntity(), appearance.Body, appearance.id))
		printf("Invalid entity '%s'(%s) for Appearance '%s'", self:GetEntity(), appearance.Body, appearance.id)
	end
	if appearance:HasMember("BodyColor") and appearance.BodyColor then
		self:SetColorization(appearance.BodyColor, true)
	end
	self.parts = {}
	local real_time_animated = self:GetGameFlags(const.gofRealTimeAnim) ~= 0
	for _, part_name in ipairs(self.attached_parts) do
		if IsValidEntity(appearance[part_name]) then
			local part = PlaceObject("AppearanceObjectPart")
			if real_time_animated then
				part:SetGameFlags(const.gofRealTimeAnim)
			end
			part:ChangeEntity(appearance[part_name])
			if not IsValidEntity(part:GetEntity()) then
				StoreErrorSource(part, string.format("Invalid entity part '%s'(%s) for Appearance '%s'", part:GetEntity(), appearance[part_name], appearance.id))
				printf("Invalid entity part '%s'(%s) for Appearance '%s'", part:GetEntity(), appearance[part_name], appearance.id)
			end
			self.parts[part_name] = part
			self:ColorizePart(part_name)
			self:ApplyPartSpotAttachments(part_name)
		end
	end
	self:Setanim(self.anim)
end

--- Plays an animation on the AppearanceObject.
---
--- @param anim string The name of the animation to play.
function AppearanceObject:PlayAnim(anim)
	self:Setanim(anim)
	local vec = self:GetStepVector()
	local time = self:GetAnimDuration()
	if vec:Len() > 0 then
		self:SetPos(self:GetPos() + vec, time)
	end
	Sleep(time)
end

---
--- Sets the animation phase of the AppearanceObject and all its attached parts.
---
--- @param phase number The animation phase to set, typically between 0 and 1.
---
function AppearanceObject:SetPhaseHighLevel(phase)
	self:SetAnimPhase(1, phase)
	local parts = self.parts
	if parts then
		for _, part_name in ipairs(self.attached_parts) do
			local part = parts[part_name]
			if part then
				part:SetAnimPhase(1, phase)
			end
		end
	end
end

---
--- Sets the animation and animation phase of the AppearanceObject and all its attached parts.
---
--- @param anim string The name of the animation to set.
--- @param phase number The animation phase to set, typically between 0 and 1.
---
function AppearanceObject:SetAnimPose(anim, phase)
	self:Setanim(anim)
	self.anim_speed = 0
	self:SetPhaseHighLevel(phase)
end

