if FirstLoad then
	SkinDecalEditor = false
	SkinDecalEditorMode = false
	SkinDecals = false
end

SkinDecalAttachAxis = {
	["+X"] = point( 4096, 0, 0),
	["-X"] = point(-4096, 0, 0),
	["+Y"] = point(0,  4096, 0),
	["-Y"] = point(0, -4096, 0),
	["+Z"] = point(0, 0,  4096),
	["-Z"] = point(0, 0, -4096),
}

--- Returns a list of entity spots for the given object.
---
--- @param obj Object The object to get the entity spots for.
--- @return table The list of entity spots.
function EntitySpotsCombo(obj)
	local spots_data = IsKindOf(obj, "Object") and GetEntitySpots(obj:GetEntity())
	local spots = { "" }
	for spot, _ in sorted_pairs(spots_data) do
		spots[#spots + 1] = spot
	end
	return spots
end

DefineClass("SkinDecal", "Decal")

-- this class is only for the Skin Decal Editor purposes
DefineClass.BaseObjectSDE = {
	__parents = { "Object", "SkinDecalData" },

	properties = {
		{ category = "Stains", id = "DecType", editor = "dropdownlist", items = PresetsCombo("SkinDecalType", "Default", ""), default = "", read_only = function(self) return self.edit_mode end },
		{ category = "Stains", id = "Spot", editor = "dropdownlist", items = function() return EntitySpotsCombo end, default = "", read_only = function(self) return self.edit_mode end },
		{ category = "Stains", id = "stains_buttons", editor = "buttons", default = false, dont_save = true, read_only = true, 
			no_edit = function(self) return self.edit_mode or self.DecType == "" or self.Spot == "" end,
			buttons = {
				{name = "Add Stain", func = function(self, ...)
					Unit.AddStain(self, self.DecType, self.Spot)
				end},
				{name = "Remove All", func = function(self, ...)
					Unit.ClearStainsFromSpots(self)
				end, no_edit = function(self) return not self.stains end,},
				{name = "Remove Type", func = function(self, ...)
					Unit.ClearStains(self, self.DecType)
				end},
				{name = "Clear Spot", func = function(self, ...)
					Unit.ClearStainsFromSpots(self, self.Spot)
				end},
			},
		},
		{ category = "Stains", id = "edit_buttons", editor = "buttons", default = false, dont_save = true, read_only = true, 
			no_edit = function(self) return self.DecType == "" or self.Spot == "" end,
			buttons = {
				{name = "Toggle Edit", func = function(self, ...)
					self:ToggleEditMode()
				end},
			},
		},
		{ category = "Appearance", id = "DecEntity", name = "Decal Entity", 
			editor = "choice", default = "", items = function (self) return ClassDescendantsCombo("SkinDecal") end, 
			no_edit = function(self) return not self.edit_mode end },
		{ category = "Appearance", id = "DecOffsetX", name = "Offset X (red axis)", 
			editor = "number", default = 0, scale = "cm", slider = true, min = -500, max = 500, 
			no_edit = function(self) return not self.edit_mode end},
		{ category = "Appearance", id = "DecOffsetY", name = "Offset Y (green axis)", 
			editor = "number", default = 0, scale = "cm", slider = true, min = -500, max = 500, 
			no_edit = function(self) return not self.edit_mode end},
		{ category = "Appearance", id = "DecOffsetZ", name = "Offset Z (blue axis)", 
			editor = "number", default = 0, scale = "cm", slider = true, min = -500, max = 500, 
			no_edit = function(self) return not self.edit_mode end},
		{ category = "Appearance", id = "InvertFacing", name = "Invert Facing (along red axis)", 
			editor = "bool", default = false, no_edit = function(self) return not self.edit_mode end},
		{ category = "Appearance", id = "DecAttachAxis", name = "Rotation Axis", 
			editor = "choice", default = "+X", items = function (self) return table.keys(SkinDecalAttachAxis, "sorted") end, 
			no_edit = function(self) return not self.edit_mode end},
		{ category = "Appearance", id = "DecAttachAngleRange", name = "Rotation Range", 
			editor = "range", default = range(0, 360), 
			slider = true, min = 0, max = 360, no_edit = function(self) return not self.edit_mode end},
		{ category = "Appearance", id = "DecScale", name = "Scale", 
			editor = "number", default = 100, slider = true, min = 1, max = 500, 
			no_edit = function(self) return not self.edit_mode end},
		{ category = "Appearance", id = "ClrMod", name = "Color Modifier", 
			editor = "color", default = RGB(100, 100, 100), no_edit = function(self) return not self.edit_mode end},
		{ category = "Appearance", id = "ShowSpot", editor = "bool", default = false , no_edit = function(self) return not self.edit_mode end},
		{ category = "Appearance", id = "ShowDecalBBox", editor = "bool", default = false , no_edit = function(self) return not self.edit_mode end},
		{ category = "Appearance", id = "appearance_buttons", editor = "buttons", default = false, dont_save = true, read_only = true, 
			no_edit = function(self) return not self.edit_mode end,
			buttons = {
				{name = "Reapply", func = function(self, ...)
					if self.curr_stain then
						self.curr_stain.Rotation = -1
						self.curr_stain.initialized = false
					end
					self:UpdateCurrStain()					
				end},
				{name = "Save", func = function(self, ...)
					self:TransferToPreset()
				end},
				{name = "Revert", func = function(self, ...)
					self:RevertChanges()
				end},
			},
		},
				
		{ id = "DontHideWithRoom" },
	},

	Frame = 0,
	anim_thread = false,
	anim_duration = 0,
	loop_anim = true,
	preview_speed = 100,
	stains = false,
	edit_mode = false,
	curr_stain = false, -- stain being edited
	suspend_update = false,
}

--- Called when the editor is closed.
function BaseObjectSDE:Done()
	self:OnEditorClose()
end

---
--- Toggles the edit mode of the BaseObjectSDE object.
---
--- When edit mode is enabled:
--- - The current stain being edited is found or created.
--- - The edit visuals are updated to show the current stain.
--- - The properties of the current stain are copied to the BaseObjectSDE object.
---
--- When edit mode is disabled:
--- - The edit visuals are updated to hide the current stain.
--- - The current stain is set to false.
---
--- @function BaseObjectSDE:ToggleEditMode
--- @return nil
function BaseObjectSDE:ToggleEditMode()
	self.edit_mode = not self.edit_mode
	
	if self.edit_mode then
		-- find or create the edited stain
		for _, stain in ipairs(self.stains) do
			if stain.DecType == self.DecType and stain.Spot == self.Spot then
				self.curr_stain = stain
				break
			end
		end
		
		self.curr_stain = self.curr_stain or Unit.AddStain(self, self.DecType, self.Spot)		
		assert(self.curr_stain, "no stain was found or created, something is wrong")
		self:UpdateEditVisuals()
		self.suspend_update = true
		CopyUnitStainProperties(self.curr_stain, self)
		self.suspend_update = false
	else
		self:UpdateEditVisuals()
		self.curr_stain = false
	end
	
	ObjModified(self)
end

---
--- Updates the current stain being edited.
---
--- If the current stain has a decal, it is first destroyed. Then, the properties of the current stain are copied from the BaseObjectSDE object. The stain is then applied to the object, and the edit visuals are updated.
---
--- This function is called when the DecEntity, DecOffsetX, DecOffsetY, or DecOffsetZ properties of the BaseObjectSDE object are changed.
---
--- @function BaseObjectSDE:UpdateCurrStain
--- @return nil
function BaseObjectSDE:UpdateCurrStain()
	if not self.curr_stain or self.suspend_update then return end
	
	if self.curr_stain.decal then
		DoneObject(self.curr_stain.decal)		
	end
	
	CopyUnitStainProperties(self, self.curr_stain)
	
	self.curr_stain:Apply(self)
	self:UpdateEditVisuals()
end

---
--- Reverts the changes made to the current stain.
---
--- This function removes the current stain from the list of stains, destroys the current stain, and creates a new stain with the original properties of the BaseObjectSDE object. The new stain is then added to the list of stains.
---
--- @function BaseObjectSDE:RevertChanges
--- @return nil
function BaseObjectSDE:RevertChanges()
	table.remove_value(self.stains, self.curr_stain)
	DoneObject(self.curr_stain)
	self.curr_stain = Unit.AddStain(self, self.DecType, self.Spot)
	self.suspend_update = true
	CopyUnitStainProperties(self.curr_stain, self)
	self.suspend_update = false
	ObjModified(self)
end

---
--- Updates the visual editing elements for the current stain.
---
--- This function performs the following actions:
--- - Hides any spots on the object
--- - If the edit mode is enabled and the ShowSpot flag is true, it shows the spots at the current stain's location
--- - If there is a current stain with a decal, it removes any attached meshes
--- - If the edit mode is enabled and the ShowDecalBBox flag is true, it creates a white bounding box mesh and attaches it to the current stain's decal
---
--- @function BaseObjectSDE:UpdateEditVisuals
--- @return nil
function BaseObjectSDE:UpdateEditVisuals()
	self:HideSpots()
	if self.edit_mode and self.ShowSpot then
		self:ShowSpots(self.Spot)
	end
	if self.curr_stain and self.curr_stain.decal then
		self.curr_stain.decal:ForEachAttach("Mesh", DoneObject)
		if self.edit_mode and self.ShowDecalBBox then
			local bbox = GetEntityBBox(self.curr_stain.DecEntity)
			local mesh = PlaceBox(bbox, const.clrWhite, nil, false)
			mesh:ClearMeshFlags(const.mfWorldSpace)
			self.curr_stain.decal:Attach(mesh)
		end
	end
end

---
--- Sets whether the spots on the object should be shown during the editing process.
---
--- @param value boolean Whether to show the spots or not.
--- @return nil
function BaseObjectSDE:SetShowSpot(value)
	self.ShowSpot = value
	self:UpdateEditVisuals()
end
---
--- Sets whether the bounding box of the current decal should be shown during the editing process.
---
--- @param value boolean Whether to show the decal bounding box or not.
--- @return nil
function BaseObjectSDE:SetShowDecalBBox(value)
	self.ShowDecalBBox = value
	self:UpdateEditVisuals()
end
---
--- Sets the DecEntity property of the BaseObjectSDE object.
---
--- @param value any The new value for the DecEntity property.
--- @return nil
function BaseObjectSDE:SetDecEntity(value)
	self.DecEntity = value
	self:UpdateCurrStain()
end
---
--- Sets the DecOffsetX property of the BaseObjectSDE object.
---
--- @param value number The new value for the DecOffsetX property.
--- @return nil
function BaseObjectSDE:SetDecOffsetX(value)
	self.DecOffsetX = value
	self:UpdateCurrStain()
end
---
--- Sets the DecOffsetY property of the BaseObjectSDE object.
---
--- @param value number The new value for the DecOffsetY property.
--- @return nil
function BaseObjectSDE:SetDecOffsetY(value)
	self.DecOffsetY = value
	self:UpdateCurrStain()
end
---
--- Sets the DecOffsetZ property of the BaseObjectSDE object.
---
--- @param value number The new value for the DecOffsetZ property.
--- @return nil
function BaseObjectSDE:SetDecOffsetZ(value)
	self.DecOffsetZ = value
	self:UpdateCurrStain()
end
---
--- Sets whether the decal should be inverted in its facing direction.
---
--- @param value boolean Whether to invert the decal's facing direction.
--- @return nil
function BaseObjectSDE:SetInvertFacing(value)
	self.InvertFacing = value
	self:UpdateCurrStain()
end
---
--- Sets the DecAttachAxis property of the BaseObjectSDE object.
---
--- @param value any The new value for the DecAttachAxis property.
--- @return nil
function BaseObjectSDE:SetDecAttachAxis(value)
	self.DecAttachAxis = value
	self:UpdateCurrStain()
end
---
--- Sets the DecAttachAngleRange property of the BaseObjectSDE object.
---
--- @param value number The new value for the DecAttachAngleRange property.
--- @return nil
function BaseObjectSDE:SetDecAttachAngleRange(value)
	self.DecAttachAngleRange = value
	if self.curr_stain then
		self.curr_stain.Rotation = -1
	end
	self:UpdateCurrStain()
end
---
--- Sets the DecScale property of the BaseObjectSDE object.
---
--- @param value number The new value for the DecScale property.
--- @return nil
function BaseObjectSDE:SetDecScale(value)
	self.DecScale = value
	self:UpdateCurrStain()
end
---
--- Sets the color modulation of the current decal stain.
---
--- @param value table The new color modulation value.
--- @return nil
function BaseObjectSDE:SetClrMod(value)
	self.ClrMod = value
	self:UpdateCurrStain()
end

---
--- Deletes the animation thread associated with the BaseObjectSDE object when the editor is closed.
---
--- @return nil
function BaseObjectSDE:OnEditorClose()
	DeleteThread(self.anim_thread)
end

---
--- Updates the AnimRevision property of the BaseObjectSDE object with the animation revision for the specified animation.
---
--- @param anim string The name of the animation to get the revision for.
--- @return nil
function BaseObjectSDE:UpdateAnimRevision(anim)
	local anim_rev = EntitySpec:GetAnimRevision(self:GetEntity(), anim)
	if anim_rev then
		self:SetProperty("AnimRevision", anim_rev)
	end
end

---
--- Sets the animation for the BaseObjectSDE object and updates the animation revision and timeline.
---
--- @param anim string The name of the animation to set.
--- @return nil
function BaseObjectSDE:Setanim(anim)
	local old_frame, old_abs_duration = self.Frame, self:GetAbsoluteTime(self.anim_duration)
	local timeline = GetDialog("AnimMetadataEditorTimeline")
	if timeline then
		timeline:CreateMomentControls()
	end
	self:UpdateAnimRevision(anim)
	if self.anim_speed == 0 then
		if old_abs_duration == 0 then
			self:SetFrame(old_frame)
		else
			local new_abs_duration = self:GetAbsoluteTime(self.anim_duration)
			self:SetFrame(MulDivTrunc(new_abs_duration, old_frame, old_abs_duration))
		end
	end
	AnimationMomentsEditorBindObjects(self)
end

--- Gets the inherited entity for the specified animation.
---
--- @param anim string The name of the animation to get the inherited entity for. If not provided, the current animation is used.
--- @return Entity The inherited entity for the specified animation.
function BaseObjectSDE:GetInheritedEntity(anim)
	return GetAnimEntity(self:GetEntity(), GetStateIdx(anim or self:GetProperty("anim")))
end

---
--- Gets the animation speed modifier for the specified animation on the inherited entity.
---
--- @param anim string The name of the animation to get the speed modifier for. If not provided, the current animation is used.
--- @return number The animation speed modifier for the specified animation.
function BaseObjectSDE:GetEntityAnimSpeed(anim)
	anim = anim or self:GetProperty("anim")

	local entity = self:GetInheritedEntity()
	local state_speed = entity and GetStateSpeedModifier(entity, GetStateIdx(anim)) or const.AnimSpeedScale
	return state_speed
end

---
--- Converts an absolute animation time to a modified time based on the entity's animation speed modifier.
---
--- @param absolute_time number The absolute animation time to convert.
--- @return number The modified animation time.
function BaseObjectSDE:GetModifiedTime(absolute_time)
	return MulDivTrunc(absolute_time, const.AnimSpeedScale, self:GetEntityAnimSpeed())
end

---
--- Converts a modified animation time to the absolute animation time based on the entity's animation speed modifier.
---
--- @param modified_time number The modified animation time to convert.
--- @return number The absolute animation time.
function BaseObjectSDE:GetAbsoluteTime(modified_time)
	return MulDivTrunc(modified_time, self:GetEntityAnimSpeed(), const.AnimSpeedScale)
end

---
--- Sets the animation frame for the object.
---
--- @param frame number The new animation frame to set.
--- @param delayed_moments_binding boolean If true, delays the binding of animation moments until after the frame is set.
function BaseObjectSDE:SetFrame(frame, delayed_moments_binding)
	self.Frame = frame
	self.anim_speed = 0
	self:SetAnimHighLevel()
	UpdateTimeline()
	if delayed_moments_binding then
		DelayedBindMoments(self)
	end
end

---
--- Gets the current animation frame for the object.
---
--- If the animation speed is 0, the modified time of the current frame is returned.
--- Otherwise, the remaining time until the end of the animation is returned.
---
--- @return number The current animation frame.
function BaseObjectSDE:GetFrame()
	if self.anim_speed == 0 then
		return self:GetModifiedTime(self.Frame) 
	else
		return self.anim_duration - self:TimeToAnimEnd()
	end
end

---
--- Sets the animation channel for the object.
---
--- @param channel number The animation channel to set.
--- @param anim string The animation to set.
--- @param flags number The animation flags to set.
--- @param crossfade number The crossfade time to set.
--- @param weight number The animation weight to set.
--- @param blend_time number The animation blend time to set.
--- @param resume boolean If true, resumes the animation.
--- @return number, number The current animation time and duration.
function BaseObjectSDE:SetAnimLowLevel(resume)
	local anim = self:GetProperty("anim")
	local time, duration = self:SetAnimChannel(1, anim, self.animFlags, self.animCrossfade, self.animWeight, self.animBlendTime, resume)
	if self.anim2 ~= "" then
		local time2, duration2 = self:SetAnimChannel(2, self.anim2, self.anim2Flags, self.anim2Crossfade, 100 - self.animWeight, self.anim2BlendTime, resume)
		time = Max(time, time2)
		duration = Max(duration, duration2)
	end
	
	return time, duration
end

---
--- Adjusts the position of the animation for the object.
---
--- This function is called during the animation update loop to adjust the position of the object based on the current animation frame.
---
--- @param time number The current animation time.
---
function BaseObjectSDE:AnimAdjustPos()
end

---
--- Sets the animation for the object at a high level.
---
--- This function is called to set the animation for the object. It sets the animation at a low level using `SetAnimLowLevel()`, updates the animation duration, and creates a real-time thread to handle animation adjustments and moments.
---
--- @param resume boolean If true, resumes the animation.
--- @return number, number The current animation time and duration.
function BaseObjectSDE:SetAnimHighLevel(resume)
	local time, duration = self:SetAnimLowLevel(resume)
	time = Max(time, 1)
	self.anim_duration = duration
	UpdateTimelineDuration(duration)
	local dlg = GetDialog("AnimMetadataEditorTimeline")
	if dlg then
		dlg.idAnimationName:SetText(self.anim)
	end
	if IsValidThread(self.anim_thread) then
		DeleteThread(self.anim_thread)
		self.anim_thread = nil
	end
	self.anim_thread = CreateRealTimeThread(function()
		local moments = self:GetAnimMoments()
		while IsValid(self) and IsValidEntity(self:GetEntity()) do
			self:AnimAdjustPos(time)
			local dt, moment_index = 0, 1
			local moment, time_to_moment, moment_descr = self:TimeToNextMoment(1, moment_index)
			while IsValid(self) and dt < time do
				Sleep(1)
				UpdateTimeline()
				dt = dt + 1
				if time_to_moment then
					time_to_moment = time_to_moment - 1
					if time_to_moment <= 0 then
						PlayFX(moment_descr.FX, moment, moment_descr.Actor or self)
						moment_index = moment_index + 1
						moment, time_to_moment, moment_descr = self:TimeToNextMoment(1, moment_index)
					end
				end
			end
			if not IsValid(self) then return end
			if not self.loop_anim then
				-- if not looped anim - freeze at the last frame
				if self.anim_speed > 0 then
					self.Frame = self.anim_duration - 1
					self.anim_speed = 0
					self:SetAnimLowLevel()
				end
				while IsValid(self) and not self.loop_anim do
					Sleep(20)
				end
				if not IsValid(self) then return end
			end
			time, self.anim_duration = self:SetAnimLowLevel()
			time = Max(time, 1)
			UpdateTimelineDuration(self.anim_duration)
		end
	end)
end

---
--- Returns the animation preset for the current object.
---
--- @return table The animation preset for the current object.
function BaseObjectSDE:GetAnimPreset()
	local anim = self:GetProperty("anim")
	local entity = self:GetInheritedEntity(anim)
	local preset_group = Presets.AnimMetadata[entity] or empty_table
	return preset_group[anim] or empty_table
end

---
--- Returns the animation moments for the current object.
---
--- @return table The animation moments for the current object.
function BaseObjectSDE:GetAnimMoments()
	local preset_anim = self:GetAnimPreset()
	
	return preset_anim.Moments or empty_table
end

---
--- Returns the step compensation vector for the current object.
---
--- If `DisableCompensation` is true, returns a point30 vector. Otherwise, returns the step vector calculated by `GetStepVector()`.
---
--- @return table The step compensation vector.
function BaseObjectSDE:GetStepCompensation()
	return self.DisableCompensation and point30 or self:GetStepVector()
end

---
--- Called when the animation of the object is changed.
---
--- @param anim string The new animation.
--- @param old_anim string The previous animation.
---
function BaseObjectSDE:OnAnimChanged(anim, old_anim)
end

---
--- Changes the animation of the object.
---
--- If the animation speed is 0, the function sets the animation frame based on the duration of the old animation. Otherwise, it sets the animation to the new animation.
---
--- @param anim string The new animation to set.
--- @param old_anim string The previous animation.
---
function BaseObjectSDE:ChangeAnim(anim, old_anim)
	if self.anim_speed == 0 then
		local old_duration = Max(GetAnimDuration(self:GetEntity(), old_anim), 1)
		if not self.loop_anim and self.Frame == old_duration - 1 then
			self.anim_speed = 1000
			self:Setanim(anim)
		else
			self:SetFrame(self.anim_duration * self.Frame / old_duration)
		end
	end	
	self:OnAnimChanged(anim, old_anim)
end

---
--- Transfers the properties of the current object to a preset.
---
--- If a preset with the same ID as the current object's ID does not exist, a new preset is created and registered.
--- The properties of the current object are then copied to the preset, and the preset is saved.
---
--- @return table The preset that the properties were transferred to.
---
function BaseObjectSDE:TransferToPreset()
	local base_entity = GetAnimEntity(self:GetEntity(), self:GetState())
	local id = UnitStainPresetName(base_entity, self.DecType, self.Spot)
	
	local preset_group = Presets.SkinDecalMetadata.Default	
	local preset = preset_group and preset_group[id]
	if not preset then 
		preset = SkinDecalMetadata:new{id = id}
		preset:Register()
	end
	CopyUnitStainProperties(self, preset)	
	preset:Save(true)
	ObjModified(preset)
		
	return preset
end

---
--- Handles changes to the editor properties of the `BaseObjectSDE` class.
---
--- When the `anim` property is changed, this function updates the animation of the object and saves the last used animation in the local storage.
--- When the `Appearance` property is changed, this function saves the last used appearance in the local storage.
---
--- @param prop_id string The ID of the property that was changed.
--- @param old_value any The previous value of the property.
--- @param ged table The GED (Graphical Editor) instance.
---
function BaseObjectSDE:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "anim" then
		local anim = self:GetProperty("anim")
		self:ChangeAnim(anim, old_value)
		LocalStorage.AME_LastAnim = anim
		SaveLocalStorage()
	elseif prop_id == "Appearance" then
		LocalStorage.AME_LastAppearance = self:GetProperty("Appearance")
		SaveLocalStorage()
	end
end

-- this class is only for the Skin Decal Editor purposes
DefineClass.AppearanceObjectSDE = {
	__parents = { "AppearanceObject", "StripObjectProperties", "BaseObjectSDE" },
	flags = { gofRealTimeAnim = true },
	
	properties = {
		{ category = "Animation", id = "Appearance", name = "Entity/Appearance", editor = "dropdownlist",
		  items = AllAppearancesComboItems, default = GetAllAnimatedEntities()[1],
		  read_only = function(self) return self.edit_mode end,
		  buttons = {{name = "Edit", func = function(self, root, prop_id, ged)
				local appearance = self.Appearance
				local preset = AppearancePresets[appearance] or EntitySpecPresets[appearance]
				if preset then
					preset:OpenEditor()
				end
		  end}},
		},
		{ category = "Animation", id = "anim", name = "Animation", editor = "dropdownlist", items = ValidAnimationsCombo, default = "idle",
			read_only = function(self) return self.edit_mode end,
		},

		{ id = "animWeight" },
		{ id = "animBlendTime" },
		{ id = "anim2" },
		{ id = "anim2BlendTime" },
		
		{ id = "DetailClass" },
	},
	
	init_pos = false,
}

--- Sets the animation for the AppearanceObjectSDE.
---
--- @param anim string The animation to set. If the animation ends with a "*", it is ignored.
function AppearanceObjectSDE:Setanim(anim)
	if anim:sub(-1, -1) == "*" then return end
	
	anim = IsValidAnim(self, anim) and anim or "idle"
	AppearanceObject.Setanim(self, anim)
	BaseObjectAME.Setanim(self, anim)
end

--- Sets the animation for the AppearanceObjectSDE using the low-level animation system.
---
--- @param ... any Arguments to pass to the BaseObjectAME.SetAnimLowLevel method.
--- @return any Returns the result of calling BaseObjectAME.SetAnimLowLevel with the provided arguments.
function AppearanceObjectSDE:SetAnimHighLevel(...)
	return BaseObjectAME.SetAnimHighLevel(self, ...)
end

--- Sets the animation for the AppearanceObjectSDE using the low-level animation system.
---
--- @param ... any Arguments to pass to the BaseObjectAME.SetAnimLowLevel method.
--- @return any Returns the result of calling BaseObjectAME.SetAnimLowLevel with the provided arguments.
function AppearanceObjectSDE:SetAnimLowLevel(...)
	return BaseObjectAME.SetAnimLowLevel(self, ...)
end

--- Gets the animation moments for the AppearanceObjectSDE.
---
--- @param ... any Arguments to pass to the BaseObjectAME.GetAnimMoments method.
--- @return any Returns the result of calling BaseObjectAME.GetAnimMoments with the provided arguments.
function AppearanceObjectSDE:GetAnimMoments(...)
	return BaseObjectAME.GetAnimMoments(self, ...)
end

--- Applies the specified appearance to the AppearanceObjectSDE.
---
--- @param appearance string|Appearance The appearance to apply. If not provided, the last used appearance from LocalStorage.AME_LastAppearance or the current Appearance will be used.
function AppearanceObjectSDE:ApplyAppearance(appearance)
	appearance = appearance or LocalStorage.AME_LastAppearance or self.Appearance
	
	local preset_appearance = AppearancePresets[appearance]
	if preset_appearance then
		local copy =  preset_appearance:Clone("Appearance")
		copy.id = preset_appearance.id
		AppearanceObject.ApplyAppearance(self, copy)
	else
		appearance = IsValidEntity(appearance) and appearance or GetAllAnimatedEntities()[1]
		local entity_appearance = Appearance:new{id = appearance, Body = appearance}
		AppearanceObject.ApplyAppearance(self, entity_appearance)
	end
	--self:SetSpot(self.Spot)
	ObjModified(self)
end

--- Adjusts the position of the AppearanceObjectSDE based on the current animation.
---
--- If the animation speed is greater than 0, the position is set to the initial position plus the step compensation. The position is then clamped to the terrain.
---
--- If the animation speed is 0, the position is set to the initial position plus the step vector for the current frame of the animation.
---
--- @param time number The time to set the position at.
function AppearanceObjectSDE:AnimAdjustPos(time)
	if self.anim_speed > 0 then
		local step = self:GetStepCompensation()
		self:SetPos(self.init_pos)
		local pos = terrain.ClampPoint(self.init_pos + step)
		self:SetPos(pos, time)
	else
		local frame_step = self:GetStepVector(self:GetAnim(), self:GetAngle(), 0, self.Frame)
		self:SetPos(self.init_pos + frame_step)
	end
end

---
--- Sets the animation channel for the AppearanceObjectSDE.
---
--- @param channel number The animation channel to set.
--- @param anim string The animation to play on the channel.
--- @param anim_flags table The flags to apply to the animation.
--- @param crossfade boolean Whether to crossfade the animation.
--- @param weight number The weight of the animation.
--- @param blend_time number The blend time for the animation.
--- @param resume boolean Whether to resume the animation from the current frame.
--- @return number, number The remaining time and total duration of the animation.
---
function AppearanceObjectSDE:SetAnimChannel(channel, anim, anim_flags, crossfade, weight, blend_time, resume)
	AppearanceObject.SetAnimChannel(self, channel, anim, anim_flags, crossfade, weight, blend_time)
	
	local frame = self.Frame
	if resume then
		self:SetAnimPhase(channel, frame)
		for _, part_name in ipairs(self.animated_parts) do
			local part = self.parts[part_name]
			if part then
				if resume then
					part:SetAnimPhase(channel, frame)
				end
			end
		end
		self.Frame = 0
	end
	
	if self.anim_speed == 0 then
		self:SetAnimPhase(channel, frame)
		for _, part_name in ipairs(self.animated_parts) do
			local part = self.parts[part_name]
			if part then
				part:SetAnimPhase(channel, frame)
			end
		end
	end
	
	local duration = GetAnimDuration(self:GetEntity(), self:GetAnim(channel))
	
	return duration - (resume and frame or 0), duration
end

---
--- Returns the bounding box of the AppearanceObjectSDE, including the bounding boxes of any attached parts.
---
--- @return table The bounding box of the AppearanceObjectSDE.
---
function AppearanceObjectSDE:GetSize()
	local bbox = self:GetEntityBBox()
	if self.parts then
		for _, part_name in ipairs(self.attached_parts) do
			local part = self.parts[part_name]
			if part then
				local part_bbox = part:GetEntityBBox()
				bbox = Extend(bbox, part_bbox:min())
				bbox = Extend(bbox, part_bbox:max())
			end
		end
	end
	return bbox
end

---
--- Handles changes to the properties of the AppearanceObjectSDE in the editor.
---
--- @param prop_id string The ID of the property that was changed.
--- @param old_value any The previous value of the property.
--- @param ged table The GED (Graphical Editor) object associated with the property change.
---
function AppearanceObjectSDE:OnEditorSetProperty(prop_id, old_value, ged)
	BaseObjectAME.OnEditorSetProperty(self, prop_id, old_value, ged)
	if prop_id == "Appearance" then
		self:ApplyAppearance()
	else
		AppearanceObject.OnEditorSetProperty(self, prop_id, old_value, ged)
	end
end

---
--- Called when the AppearanceObjectSDE editor is opened.
---
--- @param editor table The editor object associated with the AppearanceObjectSDE.
---
function AppearanceObjectSDE:OnEditorOpen(editor)
	BaseObjectAME.OnEditorOpen(self, editor)
	GedOpCharacterCamThreeQuarters(editor, self)
	local last_anim = LocalStorage.AME_LastAnim
	self:SetProperty("anim", last_anim and IsValidAnim(self, last_anim) and last_anim or "idle")
end

---
--- Called when the AppearanceObjectSDE editor is closed.
---
--- This function is called when the AppearanceObjectSDE editor is closed. It restores the camera to the tactical view if the camera was in the maximum view.
---
--- @param self AppearanceObjectSDE The AppearanceObjectSDE instance.
---
function AppearanceObjectSDE:OnEditorClose()
	BaseObjectAME.OnEditorClose(self)
	if cameraMax.IsActive() then
		cameraTac.Activate(1)
	end
end

----

DefineClass.SelectionObjectSDE = {
	__parents = { "BaseObjectSDE", "StripObjectProperties" },
	
	properties = {
		{ id = "animWeight" },
		{ id = "animBlendTime" },
		{ id = "anim2" },
		{ id = "anim2BlendTime" },
	},
	obj = false,
	animFlags  = 0,
	animCrossfade = 0,
	anim2Flags = 0,
	anim2Crossfade = 0,
	anim_speed = 1000,
}

---
--- Returns the animation state text of the associated object.
---
--- @return string The animation state text of the associated object, or an empty string if the object is not valid.
---
function SelectionObjectSDE:Getanim()
	return IsValid(self.obj) and self.obj:GetStateText() or ""
end

---
--- Returns the step vector of the associated object.
---
--- @param self SelectionObjectSDE The SelectionObjectSDE instance.
--- @param ... Any additional arguments to pass to the `GetStepVector` method of the associated object.
--- @return Vector3 The step vector of the associated object, or a default vector if the object is not valid.
---
function SelectionObjectSDE:GetStepVector(...)
	return IsValid(self.obj) and self.obj:GetStepVector(...) or point30
end

---
--- Returns whether the associated object's animation is looping.
---
--- @param self SelectionObjectSDE The SelectionObjectSDE instance.
--- @return boolean Whether the associated object's animation is looping, or false if the object is not valid.
---
function SelectionObjectSDE:GetLooping()
	return IsValid(self.obj) and self.obj:IsAnimLooping() or false
end

---
--- Returns the duration of the animation associated with the object.
---
--- @param self SelectionObjectSDE The SelectionObjectSDE instance.
--- @return number The duration of the animation associated with the object, or a default value if the object is not valid.
---
function SelectionObjectSDE:GetAnimDuration()
	return IsValid(self.obj) and self.obj:GetAnimDuration() or point30
end

---
--- Sets the animation state of the associated object.
---
--- @param self SelectionObjectSDE The SelectionObjectSDE instance.
--- @param anim string The new animation state to set.
---
function SelectionObjectSDE:Setanim(anim)
	if IsValid(self.obj) then
		self.obj:SetStateText(anim)
		BaseObjectAME.Setanim(self, anim)
	end
end

--- Returns the associated entity object.
---
--- @param self SelectionObjectSDE The SelectionObjectSDE instance.
--- @return Entity The associated entity object, or an empty string if the object is not valid.
---
function SelectionObjectSDE:GetEntity()
	return IsValid(self.obj) and self.obj:GetEntity() or ""
end

---
--- Called when the editor is opened.
---
--- @param self SelectionObjectSDE The SelectionObjectSDE instance.
--- @param editor table The editor instance.
---
function SelectionObjectSDE:OnEditorOpen(editor)
	BaseObjectAME.OnEditorOpen(self, editor)
	self:UpdateSelectedObj()
end

---
--- Sets the selected object for the SelectionObjectSDE instance.
---
--- @param self SelectionObjectSDE The SelectionObjectSDE instance.
--- @param obj Entity The new object to set as the selected object.
---
function SelectionObjectSDE:SetSelectedObj(obj)
	local prev_obj = self.obj
	if IsValid(prev_obj) then
		prev_obj:ClearGameFlags(const.gofRealTimeAnim)
		self:Detach()
	end
	self.obj = obj
	if obj then
		obj:Attach(self)
		obj:SetGameFlags(const.gofRealTimeAnim)
	end
end

---
--- Updates the selected object for the SelectionObjectSDE instance.
---
--- This function is responsible for updating the selected object for the SelectionObjectSDE instance. It retrieves the current animation state of the selected object, sets the animation state of the SelectionObjectSDE instance, and sets the current animation phase of the SelectionObjectSDE instance.
---
--- @param self SelectionObjectSDE The SelectionObjectSDE instance.
---
function SelectionObjectSDE:UpdateSelectedObj()
	local obj = self.obj
	if not IsValid(obj) then
		return
	end
	local anim = obj:GetStateText()
	BaseObjectAME.Setanim(self, anim)
	self.Frame = obj:GetAnimPhase(1)
end

---
--- Called when the editor is closed.
---
--- This function is responsible for cleaning up the SelectionObjectSDE instance when the editor is closed. It calls the `BaseObjectAME.OnEditorClose()` function to perform any base class cleanup, and then sets the selected object to `false`.
---
--- @param self SelectionObjectSDE The SelectionObjectSDE instance.
---
function SelectionObjectSDE:OnEditorClose()
	BaseObjectAME.OnEditorClose(self)
	self:SetSelectedObj(false)
end

---
--- Sets the animation channel for the selected object.
---
--- @param self SelectionObjectSDE The SelectionObjectSDE instance.
--- @param channel number The animation channel to set.
--- @param anim string The animation to set for the channel.
--- @param anim_flags number The animation flags to set for the channel.
--- @param crossfade boolean Whether to crossfade the animation.
--- @param weight number The weight of the animation.
--- @param blend_time number The blend time for the animation.
--- @param resume boolean Whether to resume the animation from the current frame.
--- @return number, number The remaining animation duration and the total animation duration.
---
function SelectionObjectSDE:SetAnimChannel(channel, anim, anim_flags, crossfade, weight, blend_time, resume)
	local obj = self.obj
	if not IsValid(obj) then
		return 0, 0
	end
	
	obj:SetAnim(channel, anim, anim_flags, crossfade)
	obj:SetAnimWeight(channel, 100)
	obj:SetAnimWeight(channel, weight, blend_time)
	obj:SetAnimSpeed(channel, self.anim_speed)
	
	local frame = self.Frame
	if resume then
		obj:SetAnimPhase(channel, frame)
		self.Frame = 0
	end
	if self.anim_speed == 0 then
		obj:SetAnimPhase(channel, frame)
	end
	
	local duration = GetAnimDuration(obj:GetEntity(), obj:GetAnim(channel))
	return duration - (resume and frame or 0), duration
end

---
--- Gets the size of the object.
---
--- @param self SelectionObjectSDE The SelectionObjectSDE instance.
--- @return box The bounding box of the object.
---
function SelectionObjectSDE:GetSize()
	return IsValid(self.obj) and ObjectHierarchyBBox(self.obj) or box()
end

---
--- Gets the current animation phase of the selected object.
---
--- @param self SelectionObjectSDE The SelectionObjectSDE instance.
--- @return number The current animation phase of the selected object, or 0 if the object is not valid.
---
function SelectionObjectSDE:GetAnimPhase(...)
	return IsValid(self.obj) and self.obj:GetAnimPhase(...) or 0
end

---
--- Gets the states text table of the selected object.
---
--- @param self SelectionObjectSDE The SelectionObjectSDE instance.
--- @return table The states text table of the selected object, or an empty table if the object is not valid.
---
function SelectionObjectSDE:GetStatesTextTable(...)
	return IsValid(self.obj) and self.obj:GetStatesTextTable(...) or {}
end

---
--- Gets the time remaining until the animation on the selected object ends.
---
--- @param self SelectionObjectSDE The SelectionObjectSDE instance.
--- @return number The time remaining until the animation on the selected object ends, or 0 if the object is not valid.
---
function SelectionObjectSDE:TimeToAnimEnd(...)
	return IsValid(self.obj) and self.obj:TimeToAnimEnd(...) or 0
end

----

---
--- Gets the current SkinDecalEditor object.
---
--- @return SelectionObjectSDE|nil The current SkinDecalEditor object, or nil if it does not exist.
---
function GetSkinDecalEditorObject()
	return SkinDecalEditor and SkinDecalEditor.bound_objects["root"]
end

---
--- Opens the Skin Decal Editor with the specified target object or appearance.
---
--- @param target table|nil The target object to edit, or nil to open the editor in appearance mode.
--- @param animation string|nil The animation to apply to the target object, or nil to use the default "idle" animation.
--- @return boolean true if the Skin Decal Editor was opened successfully, false otherwise.
---
function OpenSkinDecalEditor(target, animation)
	local mode = IsValid(target) and "selection" or "appearance"
	
	if mode == "appearance" and animation then
		target = AppearanceLocateByAnimation(animation, target)
		if not target then return end
	end
	
	CreateRealTimeThread(function()
		SkinDecalEditorMode = mode
		local obj
		if mode == "appearance" then
			local pos, dir = camera.GetEye(), camera.GetDirection()
			local pos = terrain.IntersectRay(pos, pos + dir) or pos:SetTerrainZ()
			obj = AppearanceObjectSDE:new{init_pos = pos}
			obj:ApplyAppearance(target)
			obj:SetPos(pos)
			obj:SetGameFlags(const.gofRealTimeAnim)
		else
			obj = SelectionObjectSDE:new()
			obj:SetSelectedObj(target)
		end
		if not SkinDecalEditor then
			SkinDecalEditor = OpenGedApp("SkinDecalEditor", obj, { PresetClass = "SkinDecalMetadata" }) or false			
		else
			local old = GetSkinDecalEditorObject()
			SkinDecalEditor:BindObj("root", obj)
			DoneObject(old)
		end
		SkinDecalEditor:BindObj("SkinDecals", Presets.SkinDecalMetadata)

		obj:OnEditorOpen(SkinDecalEditor)
		if mode == "appearance" or animation then
			obj:Setanim(animation or "idle")
		end
	end)
	return true
end

---
--- Opens the Skin Decal Editor with the specified character's appearance.
---
--- @param socket table The socket object that triggered the function.
--- @param character table The character object to open the Skin Decal Editor for.
--- @return boolean true if the Skin Decal Editor was opened successfully, false otherwise.
---
function GedOpOpenSkinDecalEditor(socket, character)
	OpenSkinDecalEditor(character.Appearance)
end

---
--- Closes the Skin Decal Editor.
---
--- This function is responsible for closing the Skin Decal Editor when it is open. It checks if the Skin Decal Editor is currently open, and if so, sends a "rfnApp" message to the editor to exit. It also cleans up any associated objects or state.
---
--- @return nil
---
function CloseSkinDecalEditor()
	if SkinDecalEditor then
		SkinDecalEditor:Send("rfnApp", "Exit")
	end
end

function OnMsg.GedClosing(ged_id)
	if SkinDecalEditor and SkinDecalEditor.ged_id == ged_id then
		local character = GetSkinDecalEditorObject()
		if IsValid(character) then
			DoneObject(character)
		end
		SkinDecalEditorMode = false
		SkinDecalEditor = false
	end	
end

local function EditorSelectionChanged()
	if SkinDecalEditor and SkinDecalEditorMode == "selection" then
		local sel_obj = editor.GetSel()[1]
		local character = GetSkinDecalEditorObject()
		if not IsValid(sel_obj) or not character then
			CloseSkinDecalEditor()
		else
			character:SetSelectedObj(sel_obj)
			character:UpdateSelectedObj()
		end
	end
end

function OnMsg.EditorSelectionChanged(objects)
	if SkinDecalEditor and SkinDecalEditorMode == "selection" then
		DelayedCall(0, EditorSelectionChanged)
	end
end

OnMsg.ChangeMapDone = CloseSkinDecalEditor

---
--- Reloads the skin decals from the game's preset data.
---
--- This function iterates through all the "SkinDecalMetadata" presets and populates the `SkinDecals` table with the skin decal data. The data is organized by entity group, decal type, and spot on the entity.
---
--- @return nil
---
function ReloadSkinDecals()
	SkinDecals = {}
	ForEachPreset("SkinDecalMetadata", function(preset, group)
		local by_entity = SkinDecals[preset.group] or {}
		SkinDecals[preset.group] = by_entity
		local by_type = by_entity[preset.DecType] or {}
		by_entity[preset.DecType] = by_type
		by_type[preset.Spot] = preset
	end)
end
OnMsg.DataLoaded = ReloadSkinDecals