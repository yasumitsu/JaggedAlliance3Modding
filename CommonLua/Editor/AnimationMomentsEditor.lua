local function WipeDeleted()
	local to_delete = {}
	ForEachPreset("AnimMetadata", function(preset)
		local entity, anim = preset.group, preset.id
		if not (IsValidEntity(entity) and HasState(entity, anim)) then
			to_delete[#to_delete + 1] = preset
		end
	end)
	for _, preset in ipairs(to_delete) do
		preset:delete()
	end
end

DefineClass.AnimMoment = {
	__parents = { "PropertyObject" },
	properties = {
		{ id = "Type", name = "Type", editor = "choice", default = "Moment", items = ActionMomentNamesCombo },
		{ id = "Time", name = "Time (ms)", editor = "number", default = 0 },
		{ id = "FX", name = "FX", editor = "choice", default = false, items = ActionFXClassCombo },
		{ id = "Actor", name = "Actor", editor = "choice", default = false, items = ActorFXClassCombo },
		{ id = "AnimRevision", name = "Animation Revision", editor = "number", default = 0, read_only = true },
		{ id = "Reconfirm", editor = "buttons", default = false,
			no_edit = function(obj) return not (obj:GetWarning() or obj:GetError()) end,
			buttons = { { name = "Reconfirm", func = function(self, root, prop_id, ged)
				self.AnimRevision = GetAnimationMomentsEditorObject().AnimRevision
				ObjModified(self)
				ObjModified(ged:ResolveObj("AnimationMetadata"))
				ObjModified(ged:ResolveObj("Animations"))
			end,
		} } },
	},
}

--- Returns the editor view for the AnimMoment object.
---
--- If the parent AnimMetadata object has a non-100% speed modifier, the view will include the modified time.
--- Otherwise, the view will just show the type and time of the moment.
---
--- @param self AnimMoment
--- @return string The editor view for the AnimMoment
function AnimMoment:GetEditorView()
	if GetParentTableOfKind(self, "AnimMetadata").SpeedModifier ~= 100 then
		local character = GetAnimationMomentsEditorObject()
		return T{Untranslated("<Type> at <Time>ms(mod <ModTime>ms)"),
			Type = self.Type, Time = self.Time, ModTime = character:GetModifiedTime(self.Time)}
	else
		return Untranslated("<Type> at <Time>ms", self)
	end
end

---
--- Returns an error message if the AnimMoment object has any issues.
---
--- If the animation revision of the parent AnimMetadata object has changed since the AnimMoment was created, an error message is returned indicating that the moment needs to be readjusted or reconfirmed.
---
--- If the time of the AnimMoment is beyond the duration of the animation, an error message is returned.
---
--- @param self AnimMoment
--- @return string|nil The error message, or nil if there are no errors
function AnimMoment:GetError()
	local parent = GetParentTableOfKind(self, "AnimMetadata")
--	local anim_revision = EntitySpec:GetAnimRevision(parent.group, parent.id)
--	if anim_revision and self.AnimRevision < anim_revision thenbash
--		return string.format("The animation changed in revision %d, but the moment was set back in revision %d.\nReadjust or click the button below to reconfirm.", anim_revision, self.AnimRevision)
--	end
	
	if self.Time > GetAnimDuration(parent.group, parent.id) then
		return "Action moment's time is beyond the animation duration."
	end
end

---
--- Called after a new AnimMoment object is created in the editor.
--- Sets the AnimRevision property of the AnimMoment to the current animation revision of its parent AnimMetadata object.
---
--- @param self AnimMoment The AnimMoment object that was just created.
---
function AnimMoment:OnAfterEditorNew()
	local parent = GetParentTableOfKind(self, "AnimMetadata")
	self.AnimRevision = EntitySpec:GetAnimRevision(parent.group, parent.id)
end

---
--- Returns a list of all animated entities in the game, excluding the "ErrorAnimatedMesh" entity and any entities specified in the `exclude` parameter.
---
--- @param exclude string|nil The class name of entities to exclude from the list.
--- @return table A table of all animated entity names.
---
function GetAllAnimatedEntities(exclude)
	local entities = GetAllEntities()
	local animated_entities = {}
	for entity in pairs(entities) do
		if CObject.IsAnimated(entity) then
			table.insert(animated_entities, entity)
		end
	end
	table.remove_value(animated_entities, "ErrorAnimatedMesh")
	if exclude then
		animated_entities = table.subtraction(animated_entities, ClassLeafDescendantsList(exclude))
	end
	table.sort(animated_entities)

	return animated_entities
end

---
--- Returns a list of all appearance preset names and all animated entity names.
---
--- The list starts with the following items:
--- - "Appearance Presets:"
--- - "------------------"
--- - ""
--- - "Animated Entities:"
--- - "------------------"
---
--- The list then includes all appearance preset names, followed by all animated entity names (excluding "CharacterEntity").
---
--- @return table A list of appearance preset names and animated entity names.
---
function AllAppearancesComboItems()
	local list = PresetsCombo("AppearancePreset")()
	table.insert(list, 1, "Appearance Presets:")
	table.insert(list, 2, "------------------")
	
	table.insert(list, "")
	table.insert(list, "Animated Entities:")
	table.insert(list, "------------------")
	
	table.iappend(list, GetAllAnimatedEntities("CharacterEntity"))
	
	return list
end

MapVar("s_DelayedBindMomentsThread", false)

---
--- Delays the binding of animation moments objects to the animation moments editor.
---
--- This function creates a real-time thread that waits for 500 milliseconds before calling `AnimationMomentsEditorBindObjects` with the provided `obj` parameter.
---
--- The previous delayed bind moments thread, if any, is deleted before creating the new one.
---
--- @param obj table The object to bind to the animation moments editor.
---
function DelayedBindMoments(obj)
	DeleteThread(s_DelayedBindMomentsThread)
	s_DelayedBindMomentsThread = CreateMapRealTimeThread(function()
		Sleep(500)
		AnimationMomentsEditorBindObjects(obj)
		s_DelayedBindMomentsThread = false
	end)
end

-- this class is only for the Anim Metadata Editor purposes
DefineClass.BaseObjectAME = {
	__parents = { "Object" },

	properties = {
		{ category = "Animation", id = "AnimRevision", name = "Animation Revision", editor = "number", default = 0, read_only = true },
		{ category = "Animation", id = "SpeedModifier", name = "Speed Modifier", editor = "number" , slider = true , min = 10, max = 1000, default = 100},
		{ category = "Animation", id = "StepModifier", name = "Step Modifier", editor = "number" , slider = true , min = 10, max = 1000, default = 100},
		{ category = "Animation", id = "StepDelta", name = "Step Delta", editor = "point" , default = point30, read_only = true},
		{ category = "Animation", id = "DisableCompensation", name = "Disable Compensation", editor = "bool" , default = false, dont_save = true},
		{ category = "Animation", id = "VariationWeight", name = "Variation Weight", editor = "number" , default = 100},
		{ category = "Animation", id = "button1", editor = "buttons" , default = false, dont_save = true, read_only = true, sort_order = 2,
		  buttons = {
			{
				name = "Save", func = function(self, root, prop_id, ged)
					local preset = self:TransferToPreset()
					if preset then
						preset:Save("user request")
					end
				end,
				is_hidden = function(self, prop_meta) return self:GetAnimPreset() == empty_table end,
			}, {
				name = "New", func = function(self, root, prop_id, ged)
					if self:GetAnimPreset() ~= empty_table then
						return
					end
					WipeDeleted()
					local character = GetAnimationMomentsEditorObject()
					local _, _, preset = GetOrCreateAnimMetadata(character)
					preset:Save()
					AnimationMomentsEditorBindObjects(character)
					ged:SetSelection("Animations", PresetGetPath(preset))
				end,
				is_hidden = function(self, prop_meta) return self:GetAnimPreset() ~= empty_table end,
			}, {
				name = "Delete", func = function(self, root, prop_id, ged)
					local character = GetAnimationMomentsEditorObject()
					local _, _, preset = GetOrCreateAnimMetadata(character)
					preset:delete()
					WipeDeleted()
					AnimationMomentsEditorBindObjects(character)
					ObjModified(Presets.AnimMetadata)
				end,
				is_hidden = function(self, prop_meta) return self:GetAnimPreset() == empty_table end,
			}, {
				name = "Reconfirm", func = function(self, root, prop_id, ged)
					SuspendObjModified("ReconfirmMoments")
					local character = GetAnimationMomentsEditorObject()
					local _, _, preset = GetOrCreateAnimMetadata(character)
					preset:ReconfirmMoments(root, prop_id, ged)
					ResumeObjModified("ReconfirmMoments")
				end,
				is_hidden = function(self, prop_meta) return self:GetAnimPreset() == empty_table end,
			}, {
				name = "Reconfirm All", func = function(self, root, prop_id, ged)
					SuspendObjModified("ReconfirmMoments")
					local character = GetAnimationMomentsEditorObject()
					local entity = character:GetInheritedEntity()
					for _, preset in ipairs(Presets.AnimMetadata[entity]) do
						local anim = preset.id
						local revision = EntitySpec:GetAnimRevision(entity, anim)
						for _, moment in ipairs(preset.Moments or empty_table) do
							if moment.AnimRevision ~= revision then
								moment.AnimRevision = revision
								ObjModified(moment)
							end
						end
						ObjModified(preset)
						ObjModified(ged:ResolveObj("Animations"))
					end
					ResumeObjModified("ReconfirmMoments")
				end
			}, {
				name = "Wipe Out Deleted", func = function(self, root, prop_id, ged)
					SuspendObjModified("ReconfirmMoments")
					WipeDeleted()
					AnimMetadata:SaveAll("save all", "user request")
					ResumeObjModified("ReconfirmMoments")
				end},
			},
		},
		{ category = "FX", id = "FXInherits", name = "FX Inherits", editor = "string_list" , 
			default = empty_table, items = function(self)
				return ValidAnimationsCombo(self)
			end,
		},
	},

	Frame = 0,
	anim_thread = false,
	anim_duration = 0,
	loop_anim = true,
	preview_speed = 100,
}

--- Closes the Animation Moments Editor.
-- This function is called when the editor is closed. It performs cleanup tasks such as deleting the animation thread and reverting the preview speed.
function BaseObjectAME:Done()
	self:OnEditorClose()
end

---
--- Called when the Animation Moments Editor is opened.
--- This function is called when the Animation Moments Editor is opened. It can be used to perform any necessary initialization or setup tasks.
---
--- @param editor table The editor object that was opened.
---
function BaseObjectAME:OnEditorOpen(editor)
end

---
--- Closes the Animation Moments Editor.
--- This function is called when the editor is closed. It performs cleanup tasks such as deleting the animation thread and reverting the preview speed.
---
function BaseObjectAME:OnEditorClose()
	DeleteThread(self.anim_thread)
	--self:RevertPreviewSpeed(nil, "from preset")
	--AnimMetadataEditorTimelineSelectedControl = false
end

---
--- Updates the animation revision for the specified animation.
---
--- @param anim string The name of the animation to update the revision for.
---
function BaseObjectAME:UpdateAnimRevision(anim)
	local anim_rev = EntitySpec:GetAnimRevision(self:GetEntity(), anim)
	if anim_rev then
		self:SetProperty("AnimRevision", anim_rev)
	end
end

---
--- Sets the animation for the BaseObjectAME object.
---
--- This function updates the animation revision, sets the frame based on the previous animation's duration, and binds the animation moments to the objects.
---
--- @param anim string The name of the animation to set.
---
function BaseObjectAME:Setanim(anim)
	local old_frame, old_duration = self.Frame, self.anim_duration
	local timeline = GetDialog("AnimMetadataEditorTimeline")
	if timeline then
		timeline:CreateMomentControls()
	end
	self:UpdateAnimRevision(anim)
	if self.anim_speed == 0 then
		if old_duration == 0 then
			self:SetFrame(old_frame)
		else
			self:SetFrame(MulDivTrunc(self.anim_duration, old_frame, old_duration))
		end
	end
	AnimationMomentsEditorBindObjects(self)
end

---
--- Gets the inherited entity for the specified animation.
---
--- @param anim string The name of the animation to get the inherited entity for. If not provided, the current animation is used.
--- @return Entity The inherited entity for the specified animation.
---
function BaseObjectAME:GetInheritedEntity(anim)
	return GetAnimEntity(self:GetEntity(), GetStateIdx(anim or self:GetProperty("anim")))
end

---
--- Gets the animation speed modifier for the specified animation on the entity.
---
--- @param anim string The name of the animation to get the speed modifier for. If not provided, the current animation is used.
--- @return number The animation speed modifier for the specified animation.
---
function BaseObjectAME:GetEntityAnimSpeed(anim)
	anim = anim or self:GetProperty("anim")

	local entity = self:GetInheritedEntity()
	local state_speed = entity and GetStateSpeedModifier(entity, GetStateIdx(anim)) or const.AnimSpeedScale
	return state_speed
end

---
--- Converts an absolute animation time to a modified time based on the entity's animation speed.
---
--- @param absolute_time number The absolute animation time to convert.
--- @return number The modified animation time.
---
function BaseObjectAME:GetModifiedTime(absolute_time)
	return MulDivTrunc(absolute_time, const.AnimSpeedScale, self:GetEntityAnimSpeed())
end

---
--- Converts a modified time to an absolute animation time based on the entity's animation speed.
---
--- @param modified_time number The modified animation time to convert.
--- @return number The absolute animation time.
---

function BaseObjectAME:GetAbsoluteTime(modified_time)
	return MulDivTrunc(modified_time, self:GetEntityAnimSpeed(), const.AnimSpeedScale)
end

---
--- Sets the current animation frame and updates the animation state.
---
--- @param frame number The new animation frame to set.
--- @param delayed_moments_binding boolean If true, delays the binding of animation moments until after the animation state is updated.
---
function BaseObjectAME:SetFrame(frame, delayed_moments_binding)
	self.Frame = frame
	self.anim_speed = 0
	self:SetAnimHighLevel()
	UpdateTimeline()
	if delayed_moments_binding then
		DelayedBindMoments(self)
	end
end

---
--- Returns the current animation frame.
---
--- @return number The current animation frame.
---

function BaseObjectAME:GetFrame()
	if self.anim_speed == 0 then
		return self.Frame
	else
		return self.anim_duration - self:TimeToAnimEnd()
	end
end

---
--- Sets the animation channel for the entity.
---
--- @param channel number The animation channel to set.
--- @param anim string The animation to play.
--- @param flags number The animation flags.
--- @param crossfade number The crossfade duration.
--- @param weight number The animation weight.
--- @param blendTime number The blend time.
--- @param resume boolean Whether to resume the animation.
--- @return number, number The time and duration of the animation.
---
function BaseObjectAME:SetAnimLowLevel(resume)
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
--- Adjusts the position of the animation.
---
function BaseObjectAME:AnimAdjustPos()
end

---
--- Sets the animation for the entity at a high level.
---
--- @param resume boolean Whether to resume the animation.
--- @return number, number The time and duration of the animation.
---
function BaseObjectAME:SetAnimHighLevel(resume)
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
		local metadata = self:GetAnimPreset()
		while IsValid(self) and IsValidEntity(self:GetEntity()) do
			self:AnimAdjustPos(time)
			local dt, last_moment_time = 0, 0
			local anim_obj = rawget(self, "obj") or self
			local moment, time_to_moment = anim_obj:TimeToNextMoment(1, 1)
			while IsValid(self) and dt < time do
				Sleep(1)
				UpdateTimeline()
				dt = dt + 1
				if time_to_moment and self:GetAnimPhase(1) > last_moment_time + time_to_moment then
					local action, actor, target = GetProperty(metadata, "Action"), GetProperty(metadata, "Actor"), GetProperty(metadata, "Target")
					anim_obj.fx_actor_class = actor
					PlayFX(action or FXAnimToAction(metadata.id), moment, anim_obj, target)
					moment, time_to_moment = anim_obj:TimeToNextMoment(1, 1)
					last_moment_time = self:GetAnimPhase(1)
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
function BaseObjectAME:GetAnimPreset()
	local anim = self:GetProperty("anim")
	local entity = self:GetInheritedEntity(anim)
	local preset_group = Presets.AnimMetadata[entity] or empty_table
	return preset_group[anim] or empty_table
end

---
--- Returns the animation moments for the current object.
---
--- @return table The animation moments for the current object.
function BaseObjectAME:GetAnimMoments()
	local preset_anim = self:GetAnimPreset()
	
	return preset_anim.Moments or empty_table
end

---
--- Updates the animation metadata selection in the editor.
---
--- This function is used to update the selection of animation metadata in the editor.
--- It finds the group and item index of the current animation in the `Presets.AnimMetadata` table,
--- and sets the selection in the `AnimationMomentsEditor` accordingly.
---
--- @return nil
function BaseObjectAME:UpdateAnimMetadataSelection()
	local anim = self:GetProperty("anim")
	local inherited_entity = self:GetInheritedEntity(anim)
	local group = Presets.AnimMetadata or {}
	local group_idx = table.find(group, group[inherited_entity])
	local item_idx = group_idx and table.find(group[group_idx], "id", anim)
	if group_idx and item_idx then
		AnimationMomentsEditor:SetSelection("Animations", {group_idx, item_idx})
	end
end

---
--- Sets the preview speed for the animation.
---
--- This function sets the preview speed for the animation by modifying the speed modifier of the
--- current animation state. It calculates the new speed modifier based on the current speed
--- modifier, the preview speed, and the global animation speed scale constant.
---
--- @param speed number The new preview speed to set.
--- @return nil
function BaseObjectAME:SetPreviewSpeed(speed)
	self.preview_speed = speed
	local anim = self:GetProperty("anim")
	local modifier = MulDivTrunc(self.SpeedModifier * self.preview_speed, const.AnimSpeedScale, 100 * 100)
	SetStateSpeedModifier(self:GetEntity(), GetStateIdx(anim), modifier)
	self:SetAnimHighLevel()
end

---
--- Reverts the preview speed of the animation to its original state.
---
--- This function is used to restore the original speed modifier of the animation
--- after the preview speed has been set. It calculates the original speed modifier
--- based on the animation preset or the current state speed modifier, and applies
--- it back to the animation state.
---
--- @param anim string The name of the animation to revert the preview speed for.
--- @param from_preset boolean Whether the revert is being done from an animation preset.
--- @return nil
function BaseObjectAME:RevertPreviewSpeed(anim, from_preset)
	anim = anim or self:GetProperty("anim")
	
	local entity = self:GetInheritedEntity()
	local old_anim_speed_modifier
	if from_preset then
		local preset = self:GetAnimPreset()
		old_anim_speed_modifier = MulDivTrunc(1000, preset.SpeedModifier or 100, 100)
	else
		old_anim_speed_modifier = GetStateSpeedModifier(entity, GetStateIdx(anim))
		old_anim_speed_modifier = MulDivTrunc(old_anim_speed_modifier, 100, self.preview_speed)
	end
	SetStateSpeedModifier(entity, GetStateIdx(anim), old_anim_speed_modifier)
end

---
--- Applies the preview speed to the current animation.
---
--- This function is used to update the speed modifier and step modifier of the current animation
--- based on the preview speed set for the animation. It retrieves the current state speed modifier
--- and step modifier from the inherited entity, and applies the preview speed to calculate the new
--- speed modifier. It then calls the `SetPreviewSpeed` function to update the animation state with
--- the new speed modifier.
---
--- @param anim string The name of the animation to apply the preview speed to.
--- @return nil
function BaseObjectAME:ApplyPreviewSpeed(anim)
	local anim1 = self:GetProperty("anim")
	anim = anim or anim1
	
	local entity = self:GetInheritedEntity()
	local state_speed = GetStateSpeedModifier(entity, GetStateIdx(anim))
	self.SpeedModifier = MulDivTrunc(state_speed, 100, const.AnimSpeedScale)
	self.StepModifier = GetStateStepModifier(entity, GetStateIdx(anim1))
	self:SetPreviewSpeed(self.preview_speed)
end

---
--- Returns the step compensation vector for the current animation.
---
--- If `DisableCompensation` is true, this function returns a fixed point30 vector.
--- Otherwise, it returns the step vector calculated from the current animation state.
---
--- @return point30 The step compensation vector.
function BaseObjectAME:GetStepCompensation()
	return self.DisableCompensation and point30 or self:GetStepVector()
end

---
--- Handles changes to the current animation.
---
--- This function is called when the current animation is changed. It performs the following actions:
---
--- 1. Reverts the preview speed of the old animation using `RevertPreviewSpeed`.
--- 2. Applies the preview speed to the new animation using `ApplyPreviewSpeed`.
--- 3. Sets the `StepDelta` property to the step compensation vector obtained from `GetStepCompensation`.
--- 4. Retrieves the current animation preset and sets the `FXInherits` property to the value from the preset.
---
--- @param anim string The name of the new animation.
--- @param old_anim string The name of the old animation.
--- @return nil
function BaseObjectAME:OnAnimChanged(anim, old_anim)
	self:RevertPreviewSpeed(old_anim)
	self:ApplyPreviewSpeed(anim)
	self:SetProperty("StepDelta", self:GetStepVector())
	local preset = self:GetAnimPreset()
	self:SetProperty("FXInherits", preset.FXInherits)
end

---
--- Changes the current animation of the object.
---
--- If the animation speed is 0, this function performs the following actions:
--- - If the current animation is not looping and the frame is at the last frame, it sets the animation speed to 1000 and sets the new animation.
--- - Otherwise, it sets the frame to the corresponding frame in the new animation based on the current frame in the old animation.
---
--- After changing the animation, it calls the `OnAnimChanged` function to handle any additional changes.
---
--- @param anim string The name of the new animation to set.
--- @param old_anim string The name of the old animation.
--- @return nil
function BaseObjectAME:ChangeAnim(anim, old_anim)
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
	self:UpdateAnimMetadataSelection()
end

---
--- Transfers the current animation preset's properties to the Animation Moments Editor object.
---
--- If no animation preset is set, a message is displayed to the user prompting them to create a new animation metadata.
---
--- This function performs the following actions:
---
--- 1. Checks if an animation preset is set. If not, it displays a message to the user and returns.
--- 2. Calls `WipeDeleted()` to remove any deleted objects from the editor.
--- 3. Copies the `SpeedModifier`, `StepModifier`, `VariationWeight`, and `FXInherits` properties from the Animation Moments Editor object to the animation preset.
--- 4. Marks the animation preset as modified using `ObjModified()`.
--- 5. Returns the modified animation preset.
---
--- @return table The modified animation preset
function BaseObjectAME:TransferToPreset()
	local preset = self:GetAnimPreset()
	if preset == empty_table then
		if not IsRealTimeThread() then
			CreateRealTimeThread(function()
				WaitMessage(terminal.desktop,
					T(313839116468, "No Anim Metata"),
					T(857146618172, "Use 'New Animation Metadata' button first"),
					T(1000136, "OK")
				)
			end)
		end
		return
	end
	WipeDeleted()
	
	local character = GetAnimationMomentsEditorObject()
	preset.SpeedModifier = character.SpeedModifier
	preset.StepModifier = character.StepModifier
	preset.VariationWeight = character.VariationWeight
	preset.FXInherits = character.FXInherits
	ObjModified(preset)
	
	return preset
end

---
--- Handles changes to properties of the Animation Moments Editor object.
---
--- This function is called when a property of the Animation Moments Editor object is changed. It performs the following actions:
---
--- - If the "anim" property is changed, it calls `ChangeAnim()` to update the animation, saves the last used animation to local storage, and saves the local storage.
--- - If the "Appearance" property is changed, it saves the last used appearance to local storage and saves the local storage.
--- - If the "SpeedModifier" property is changed, it calls `TransferToPreset()` to update the animation preset and `SetPreviewSpeed()` to update the preview speed.
--- - If the "StepModifier" property is changed, it calls `TransferToPreset()` to update the animation preset and `SetStateStepModifier()` to update the step modifier for the current animation state.
--- - If the "Time", "Type", or "VariationWeight" property is changed, it updates the `AnimRevision` property and calls `AnimationMomentsEditorBindObjects()` to bind the objects in the Animation Moments Editor.
---
--- @param prop_id string The ID of the property that was changed
--- @param old_value any The previous value of the property
--- @param ged table The Graphical Editor Dialog object
function BaseObjectAME:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "anim" then
		local anim = self:GetProperty("anim")
		self:ChangeAnim(anim, old_value)
		LocalStorage.AME_LastAnim = anim
		SaveLocalStorage()
	elseif prop_id == "Appearance" then
		LocalStorage.AME_LastAppearance = self:GetProperty("Appearance")
		SaveLocalStorage()
	elseif prop_id == "SpeedModifier" then
		self:TransferToPreset()
		self:SetPreviewSpeed(self.preview_speed)
	elseif prop_id == "StepModifier" then
		self:TransferToPreset()
		SetStateStepModifier(self:GetEntity(), GetStateIdx(self:GetProperty("anim")), self.StepModifier)
	elseif prop_id == "Time" or prop_id == "Type" or prop_id == "VariationWeight" then
		local character = GetAnimationMomentsEditorObject()
		self.AnimRevision = character.AnimRevision
		AnimationMomentsEditorBindObjects(character)
	end
end

---
--- Formats a timeline frame value as a string with the specified precision.
---
--- @param frame number The frame value to format
--- @param precision number (optional) The number of decimal places to include in the formatted string (default is 1)
--- @return string The formatted timeline string
---
function FormatTimeline(frame, precision)
	local character = GetAnimationMomentsEditorObject()
	local absolute_frame = MulDivTrunc(frame, character.preview_speed, 100)
	precision = precision or 1
	if precision == 1 then
		return string.format("%.1fs", absolute_frame / 1000.0)
	elseif precision == 2 then
		return string.format("%.2fs", absolute_frame / 1000.0)
	else
		return string.format("%.3fs", absolute_frame / 1000.0)
	end
end

---
--- Updates the timeline in the Animation Metadata Editor.
---
--- This function is called to invalidate the timeline in the Animation Metadata Editor, causing it to be redrawn.
---
--- @function UpdateTimeline
--- @return nil
function UpdateTimeline()
	local timeline = GetDialog("AnimMetadataEditorTimeline")
	if timeline then
		timeline:Invalidate()
	end
end

---
--- Updates the duration display in the Animation Metadata Editor timeline.
---
--- This function is called to update the duration display in the Animation Metadata Editor timeline, showing the total duration of the animation.
---
--- @param time number The total duration of the animation in frames
--- @return nil
function UpdateTimelineDuration(time)
	local timeline = GetDialog("AnimMetadataEditorTimeline")
	if timeline then
		timeline.idDuration:SetText(FormatTimeline(time, 3))
	end
end

----

-- this class is only for the Anim Metadata Editor purposes
DefineClass.AppearanceObjectAME = {
	__parents = { "AppearanceObject", "StripObjectProperties", "BaseObjectAME" },
	flags = { gofRealTimeAnim = true, },
	
	properties = {
		{ category = "Animation", id = "Appearance", name = "Entity/Appearance", editor = "dropdownlist",
		  items = AllAppearancesComboItems, default = GetAllAnimatedEntities()[1],
		  buttons = {{name = "Edit", func = function(self, root, prop_id, ged)
				local appearance = self.Appearance
				local preset = AppearancePresets[appearance] or EntitySpecPresets[appearance]
				if preset then
					preset:OpenEditor()
				end
		  end}},
		},
		{ id = "DetailClass" },
	},
	
	init_pos = false,
}

---
--- Sets the animation for the AppearanceObjectAME object.
---
--- If the animation name ends with a "*", the function will return without setting the animation.
--- Otherwise, the function will set the animation to the specified name, or to "idle" if the specified animation is not valid.
---
--- @param anim string The name of the animation to set
--- @return nil
function AppearanceObjectAME:Setanim(anim)
	if anim:sub(-1, -1) == "*" then return end
	
	anim = IsValidAnim(self, anim) and anim or "idle"
	AppearanceObject.Setanim(self, anim)
	BaseObjectAME.Setanim(self, anim)
end

---
--- Sets the animation for the AppearanceObjectAME object using a low-level approach.
---
--- This function is a wrapper around the `BaseObjectAME.SetAnimLowLevel` function, which allows setting the animation
--- using a low-level approach. This can be useful for advanced animation control or when the animation needs to be
--- set in a specific way.
---
--- @param ... any Arguments to pass to the `BaseObjectAME.SetAnimLowLevel` function
--- @return any Return values from the `BaseObjectAME.SetAnimLowLevel` function
function AppearanceObjectAME:SetAnimLowLevel(...)
	return BaseObjectAME.SetAnimLowLevel(self, ...)
end
---
--- Sets the animation for the AppearanceObjectAME object using a high-level approach.
---
--- This function is a wrapper around the `BaseObjectAME.SetAnimHighLevel` function, which allows setting the animation
--- using a high-level approach. This can be useful for advanced animation control or when the animation needs to be
--- set in a specific way.
---
--- @param ... any Arguments to pass to the `BaseObjectAME.SetAnimHighLevel` function
--- @return any Return values from the `BaseObjectAME.SetAnimHighLevel` function
function AppearanceObjectAME:SetAnimHighLevel(...)
	return BaseObjectAME.SetAnimHighLevel(self, ...)
end



---
--- Gets the animation moments for the AppearanceObjectAME object.
---
--- This function is a wrapper around the `BaseObjectAME.GetAnimMoments` function, which allows retrieving the animation
--- moments for the object. This can be useful for advanced animation control or when the animation needs to be
--- analyzed in a specific way.
---
--- @param ... any Arguments to pass to the `BaseObjectAME.GetAnimMoments` function
--- @return any Return values from the `BaseObjectAME.GetAnimMoments` function
function AppearanceObjectAME:GetAnimMoments(...)
	return BaseObjectAME.GetAnimMoments(self, ...)
end

---
--- Applies the specified appearance to the AppearanceObjectAME object.
---
--- If the `appearance` parameter is not provided, it will use the last appearance set in the `LocalStorage.AME_LastAppearance` variable, or the `Appearance` property of the object.
---
--- If the `appearance` parameter is a valid preset appearance, it will create a clone of the preset and apply it to the object.
---
--- If the `appearance` parameter is not a valid preset, it will attempt to use the first animated entity in the `GetAllAnimatedEntities()` function as the appearance.
---
--- @param appearance string|Appearance The appearance to apply to the object
--- @return nil
function AppearanceObjectAME:ApplyAppearance(appearance)
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
end

---
--- Adjusts the position of the AppearanceObjectAME object based on the current animation speed and frame.
---
--- If the animation speed is greater than 0, the function calculates the step compensation and sets the position of the object to the initial position plus the step compensation, clamped to the terrain.
---
--- If the animation speed is 0 or less, the function calculates the step vector based on the current animation, angle, and absolute time, and sets the position of the object to the initial position plus the step vector.
---
--- @param time number The time to set the position at
--- @return nil
function AppearanceObjectAME:AnimAdjustPos(time)
	if self.anim_speed > 0 then
		local step = self:GetStepCompensation()
		self:SetPos(self.init_pos)
		local pos = terrain.ClampPoint(self.init_pos + step)
		self:SetPos(pos, time)
	else
		local frame_step = self:GetStepVector(self:GetAnim(), self:GetAngle(), 0, self:GetAbsoluteTime(self.Frame))
		self:SetPos(self.init_pos + frame_step)
	end
end

---
--- Sets the animation channel for the AppearanceObjectAME object.
---
--- This function sets the animation channel for the object, including the animation, animation flags, crossfade, weight, and blend time. It also sets the animation phase for the object and any attached parts, and returns the remaining duration of the animation.
---
--- @param channel string The animation channel to set
--- @param anim string The animation to set for the channel
--- @param anim_flags table The animation flags to set for the channel
--- @param crossfade boolean Whether to crossfade the animation
--- @param weight number The weight of the animation
--- @param blend_time number The blend time for the animation
--- @param resume boolean Whether to resume the animation from the current frame
--- @return number, number The remaining duration of the animation, and the total duration of the animation
function AppearanceObjectAME:SetAnimChannel(channel, anim, anim_flags, crossfade, weight, blend_time, resume)
	AppearanceObject.SetAnimChannel(self, channel, anim, anim_flags, crossfade, weight, blend_time)
	
	local frame = self.Frame
	if resume or self.anim_speed == 0 then
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
--- Gets the size of the AppearanceObjectAME object, including the size of any attached parts.
---
--- This function calculates the bounding box of the AppearanceObjectAME object, including the bounding boxes of any attached parts. It returns the minimum and maximum coordinates of the overall bounding box.
---
--- @return table The minimum and maximum coordinates of the bounding box
function AppearanceObjectAME:GetSize()
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
--- This function is called when a property of the AppearanceObjectAME object is set in the editor.
---
--- It first calls the base class's `OnEditorSetProperty` function, then checks if the property being set is the "Appearance" property. If so, it reverts the preview speed, applies the appearance, and then applies the preview speed again.
---
--- If the property being set is not the "Appearance" property, it calls the `AppearanceObject.OnEditorSetProperty` function instead.
---
--- @param prop_id string The ID of the property being set
--- @param old_value any The previous value of the property
--- @param ged table The GED (Graphical Editor) object associated with the property
function AppearanceObjectAME:OnEditorSetProperty(prop_id, old_value, ged)
	BaseObjectAME.OnEditorSetProperty(self, prop_id, old_value, ged)
	if prop_id == "Appearance" then
		self:RevertPreviewSpeed()
		self:ApplyAppearance()
		self:ApplyPreviewSpeed()
	else
		AppearanceObject.OnEditorSetProperty(self, prop_id, old_value, ged)
	end
end

---
--- Handles the selection of an AnimMetadata object in the editor.
---
--- When an AnimMetadata object is selected in the editor, this function is called to update the appearance of the associated AppearanceObjectAME object. If the selected AnimMetadata object has a different entity than the current one, the appearance is updated. The current animation is also updated to match the selected AnimMetadata object.
---
--- @param obj AnimMetadata The selected AnimMetadata object
function AppearanceObjectAME:OnAnimMetadataSelect(obj)
	local entity, anim = obj.group, obj.id
	if obj.group ~= self:GetInheritedEntity(anim) then
		self:ApplyAppearance(entity)
	end
	local old_anim = self:GetProperty("anim")
	self:SetProperty("anim", anim)
	self:OnAnimChanged(anim, old_anim)
end

if FirstLoad then
	AnimationMetadataEditorsStoredCamera = false
end

---
--- Called when the AppearanceObjectAME editor is opened.
---
--- This function performs the following actions:
--- - Stores the current camera settings in the `AnimationMetadataEditorsStoredCamera` global variable.
--- - Calls the `OnEditorOpen` function of the base class (`BaseObjectAME`).
--- - Sets the camera to a three-quarters view using the `GedOpCharacterCamThreeQuarters` function.
--- - Retrieves the last used animation from the `LocalStorage.AME_LastAnim` variable and sets it as the current animation, or defaults to "idle" if the last animation is not valid.
---
--- @param editor table The editor object associated with the AppearanceObjectAME instance.
function AppearanceObjectAME:OnEditorOpen(editor)
	AnimationMetadataEditorsStoredCamera = {GetCamera()}
	BaseObjectAME.OnEditorOpen(self, editor)
	GedOpCharacterCamThreeQuarters(editor, self)
	local last_anim = LocalStorage.AME_LastAnim
	self:SetProperty("anim", last_anim and IsValidAnim(self, last_anim) and last_anim or "idle")
end

---
--- Called when the AppearanceObjectAME editor is closed.
---
--- This function performs the following actions:
--- - Calls the `OnEditorClose` function of the base class (`BaseObjectAME`).
--- - Restores the camera settings that were stored in the `AnimationMetadataEditorsStoredCamera` global variable when the editor was opened.
---
--- @param self AppearanceObjectAME The AppearanceObjectAME instance.
function AppearanceObjectAME:OnEditorClose()
	BaseObjectAME.OnEditorClose(self)
	SetCamera(unpack_params(AnimationMetadataEditorsStoredCamera))
end

---
--- Gets or creates an AnimMetadata object for the given object.
---
--- If an AnimMetadata object already exists for the given entity and animation, it is returned. Otherwise, a new AnimMetadata object is created and returned.
---
--- @param obj table The object to get or create the AnimMetadata for.
--- @return string The entity of the AnimMetadata.
--- @return string The animation of the AnimMetadata.
--- @return table The AnimMetadata object.
--- @return table The group of AnimMetadata objects for the entity.
function GetOrCreateAnimMetadata(obj)
	local entity = obj:GetInheritedEntity()
	local anim = obj:GetProperty("anim")
	
	local group = Presets.AnimMetadata[entity]
	local preset = group and group[anim]
	if not preset then
		preset = AnimMetadata:new{ group = entity, id = anim }
		preset:OnEditorNew(Presets.AnimMetadata, AnimationMomentsEditor)
	end
	return entity, anim, preset, group
end

----

DefineClass.SelectionObjectAME = {
	__parents = { "BaseObjectAME", "StripObjectProperties" },
	
	properties = {
		{ category = "Animation", id = "InheritedEntity", name = "Anim Entity", editor = "text", default = "", read_only = true },
		{ category = "Animation", id = "anim", name = "Animation", editor = "dropdownlist", items = ValidAnimationsCombo, default = "idle" },
		{ category = "Animation", id = "animWeight", name = "Animation Weight", editor = "number", slider = true, min = 0, max = 100, default = 100, help = "100 means only Animation is played, 0 means only Animation 2 is played, 50 means both animations are blended equally" },
		{ category = "Animation", id = "animBlendTime", name = "Animation Blend Time", editor = "number", min = 0, default = 0 },
		{ category = "Animation", id = "anim2", name = "Animation 2", editor = "dropdownlist", items = function(character) local list = character:GetStatesTextTable() table.insert(list, 1, "") return list end, default = "" },
		{ category = "Animation", id = "anim2BlendTime", name = "Animation 2 Blend Time", editor = "number", min = 0, default = 0 },
		{ category = "Animation", id = "AnimDuration", name = "Anim Duration", editor = "number", default = 0, read_only = true },
		{ category = "Animation", id = "StepVector", name = "Step Vector", editor = "point", default = point30, read_only = true },
		{ category = "Animation", id = "StepAngle", name = "Step Angle (deg)", editor = "number", default = 0, scale = 60, read_only = true },
		{ category = "Animation", id = "Looping", name = "Looping", editor = "bool", default = false, read_only = true },
		{ category = "Animation", id = "Compensate", name = "Compensate", editor = "text", default = "None", read_only = true },
	},
	obj = false,
	animFlags = 0,
	animCrossfade = 0,
	anim2Flags = 0,
	anim2Crossfade = 0,
	anim_speed = 1000,
}

---
--- Gets the animation state text of the associated object.
---
--- @return string The animation state text of the associated object, or an empty string if the object is not valid.
function SelectionObjectAME:Getanim()
	return IsValid(self.obj) and self.obj:GetStateText() or ""
end

---
--- Gets the animation weight of the associated object.
---
--- @return number The animation weight of the associated object, or 0 if the object is not valid.

function SelectionObjectAME:GetStepVector(...)
	return IsValid(self.obj) and self.obj:GetStepVector(...) or point30
end

---
--- Gets the step angle of the associated object.
---
--- @param ... Additional parameters to pass to the underlying GetStepAngle method.
--- @return number The step angle of the associated object in degrees, or 0 if the object is not valid.
function SelectionObjectAME:GetStepAngle(...)
	return IsValid(self.obj) and self.obj:GetStepAngle(...) or 0
end

---
--- Gets whether the associated object's animation is looping.
---
--- @return boolean True if the associated object's animation is looping, false otherwise.
function SelectionObjectAME:GetLooping()
	return IsValid(self.obj) and self.obj:IsAnimLooping() or false
end

---
--- Gets the animation compensation of the associated object.
---
--- @return string The animation compensation of the associated object, or "None" if the object is not valid.
function SelectionObjectAME:GetCompensate()
	return IsValid(self.obj) and self.obj:GetAnimCompensate() or "None"
end

---
--- Gets the duration of the animation associated with the object.
---
--- @return number The duration of the animation associated with the object, or 0 if the object is not valid.
function SelectionObjectAME:GetAnimDuration()
	return IsValid(self.obj) and self.obj:GetAnimDuration() or point30
end

---
--- Sets the animation state text of the associated object.
---
--- @param anim string The new animation state text to set.
function SelectionObjectAME:Setanim(anim)
	if IsValid(self.obj) then
		self.obj:SetStateText(anim)
		BaseObjectAME.Setanim(self, anim)
	end
end

---
--- Gets the entity associated with the selection object.
---
--- @return string The entity associated with the selection object, or an empty string if the object is not valid.
function SelectionObjectAME:GetEntity()
	return IsValid(self.obj) and self.obj:GetEntity() or ""
end

---
--- Called when the editor is opened.
---
--- @param editor table The editor instance.
function SelectionObjectAME:OnEditorOpen(editor)
	BaseObjectAME.OnEditorOpen(self, editor)
	self:UpdateSelectedObj()
end

---
--- Sets the selected object for the editor.
---
--- @param obj table The new object to be selected.
function SelectionObjectAME:SetSelectedObj(obj)
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
--- Updates the selected object in the editor.
---
--- This function is called to update the selected object in the editor. It retrieves the current animation state of the selected object, sets the animation state in the base object, gets the current animation phase, and applies the preview speed.
---
--- @param self SelectionObjectAME The selection object instance.
function SelectionObjectAME:UpdateSelectedObj()
	local obj = self.obj
	if not IsValid(obj) then
		return
	end
	local anim = obj:GetStateText()
	BaseObjectAME.Setanim(self, anim)
	self.Frame = obj:GetAnimPhase(1)
	self:ApplyPreviewSpeed(anim)
end

---
--- Called when the editor is closed.
---
--- This function is called when the animation moments editor is closed. It calls the base class's `OnEditorClose` function, sets the `fx_actor_class` property of the selected object to `nil`, and sets the selected object to `false`.
---
--- @param self SelectionObjectAME The selection object instance.
function SelectionObjectAME:OnEditorClose()
	BaseObjectAME.OnEditorClose(self)
	self.obj.fx_actor_class = nil
	self:SetSelectedObj(false)
end

---
--- Sets the animation channel for the selected object.
---
--- This function sets the animation channel for the selected object. It sets the animation, animation flags, crossfade, weight, blend time, and animation speed for the specified channel. If the `resume` parameter is true or the animation speed is 0, it also sets the animation phase to the current frame.
---
--- @param self SelectionObjectAME The selection object instance.
--- @param channel number The animation channel to set.
--- @param anim string The animation to set.
--- @param anim_flags number The animation flags to set.
--- @param crossfade boolean Whether to crossfade the animation.
--- @param weight number The weight of the animation.
--- @param blend_time number The blend time for the animation.
--- @param resume boolean Whether to resume the animation from the current frame.
--- @return number, number The remaining time and total duration of the animation.
function SelectionObjectAME:SetAnimChannel(channel, anim, anim_flags, crossfade, weight, blend_time, resume)
	local obj = self.obj
	if not IsValid(obj) then
		return 0, 0
	end
	
	obj:SetAnim(channel, anim, anim_flags, crossfade)
	obj:SetAnimWeight(channel, 100)
	obj:SetAnimWeight(channel, weight, blend_time)
	obj:SetAnimSpeed(channel, self.anim_speed)
	
	local frame = self.Frame
	if resume or self.anim_speed == 0 then
		obj:SetAnimPhase(channel, frame)
	end
	
	local duration = GetAnimDuration(obj:GetEntity(), obj:GetAnim(channel))
	return duration - (resume and frame or 0), duration
end

---
--- Gets the size of the selection object.
---
--- This function returns the bounding box of the selection object, or an empty box if the object is not valid.
---
--- @param self SelectionObjectAME The selection object instance.
--- @return box The bounding box of the selection object.
function SelectionObjectAME:GetSize()
	return IsValid(self.obj) and ObjectHierarchyBBox(self.obj) or box()
end

---
--- Gets the animation phase of the selected object.
---
--- This function returns the current animation phase of the selected object. If the object is not valid, it returns 0.
---
--- @param self SelectionObjectAME The selection object instance.
--- @return number The current animation phase of the selected object.
function SelectionObjectAME:GetAnimPhase(...)
	return IsValid(self.obj) and self.obj:GetAnimPhase(...) or 0
end

---
--- Gets the states text table of the selected object.
---
--- This function returns the states text table of the selected object, or an empty table if the object is not valid.
---
--- @param self SelectionObjectAME The selection object instance.
--- @return table The states text table of the selected object.
function SelectionObjectAME:GetStatesTextTable(...)
	return IsValid(self.obj) and self.obj:GetStatesTextTable(...) or {}
end

---
--- Gets the time remaining until the animation on the selected object ends.
---
--- This function returns the time remaining until the animation on the selected object ends, or 0 if the object is not valid.
---
--- @param self SelectionObjectAME The selection object instance.
--- @return number The time remaining until the animation ends.
function SelectionObjectAME:TimeToAnimEnd(...)
	return IsValid(self.obj) and self.obj:TimeToAnimEnd(...) or 0
end

---
--- Handles the selection of an animation metadata object.
---
--- This function is called when an animation metadata object is selected in the editor. It updates the selected object's animation property to the selected animation, and calls the `OnAnimChanged` function to notify any listeners of the animation change.
---
--- @param self SelectionObjectAME The selection object instance.
--- @param anim_meta table The selected animation metadata object.
function SelectionObjectAME:OnAnimMetadataSelect(anim_meta)
	local obj = self.obj
	if not IsValid(obj) then
		return
	end
	local anim = anim_meta.id
	if not self.obj:HasState(anim) then
		return
	end
	local old_anim = self:GetProperty("anim")
	self:SetProperty("anim", anim)
	self:OnAnimChanged(anim, old_anim)
end

----

---
--- Sets the camera to a three-quarters view of the given character.
---
--- This function creates a real-time thread that adjusts the camera to a three-quarters view of the given character. It first saves the current `hr.MaxCameraUpdateInactive` setting, then sets the camera to a position above and behind the character. It then adjusts the camera scale to fit the character's height within 3/4 of the screen height, and restores the original `hr.MaxCameraUpdateInactive` setting.
---
--- @param socket table The socket object (unused).
--- @param character table The character object to center the camera on.
function GedOpCharacterCamThreeQuarters(socket, character)
	CreateRealTimeThread(function()
		local old_update_inactive = hr.MaxCameraUpdateInactive
		hr.MaxCameraUpdateInactive = true

		local center, radius = character:GetBSphere()
		cameraMax.Activate(1)
		cameraMax.SetCamera(center + character:GetFaceDir(radius), center)
		local size = character:GetSize()
		local height = size:sizez()
		local desired_height = UIL.GetScreenSize():y() * 3 / 4
		local lo, hi = 20, 100
		while hi - lo > 1 do
			local scale = (lo + hi) / 2
			cameraMax.SetCameraViewAt(center, radius * scale / 10)
			WaitNextFrame()
			local _, feet_height = GameToScreen(character:GetPos())
			local _, head_height = GameToScreen(character:GetPos() + point(0, 0, height))
			local screen_height = feet_height:y() - head_height:y()
			if screen_height < desired_height then
				hi = scale
			else
				lo = scale
			end
		end
		
		hr.MaxCameraUpdateInactive = old_update_inactive
	end)
end

---
--- Sets the camera to a closest view of the given character.
---
--- This function sets the camera to a position directly in front of the given character, with the camera facing the character's direction. It first activates the `cameraMax` camera and sets its position and target to the character's bounding sphere. It then activates the `cameraTac` camera, sets its position and target to the character's bounding sphere, but with the camera facing the opposite direction of the character's facing direction. Finally, it normalizes the `cameraTac` camera, sets its look-at angle, and sets its floor to 0.
---
--- @param socket table The socket object (unused).
--- @param character table The character object to center the camera on.
function GedOpCharacterCamClosest(socket, character)
	local center, radius = character:GetBSphere()
	cameraMax.Activate(1)
	cameraMax.SetCamera(center + character:GetFaceDir(radius), center)
	cameraTac.Activate(1)
	cameraTac.SetCamera(center - character:GetFaceDir(radius), center)
	cameraTac.Normalize()
	cameraTac.SetLookAtAngle(hr.CameraTacLookAtAngle)
	cameraTac.SetFloor(0)
end

---
--- Resumes the animation of the given character.
---
--- This function sets the animation speed of the character to 1000, and if the character is not in a loop animation and the current frame is the last frame of the animation, it resets the frame to 0. It then sets the animation to the "resume" state, and if there is a "NewMoment" control in the "AnimMetadataEditorTimeline" dialog, it deletes that control.
---
--- @param socket table The socket object (unused).
--- @param character table The character object to resume the animation for.
function GedOpAnimMetadataEditorPlay(socket, character)
	character.anim_speed = 1000
	if not character.loop_anim and character.Frame == character.anim_duration - 1 then
		character.Frame = 0
	end
	character:SetAnimHighLevel("resume")
	local control = GetDialog("AnimMetadataEditorTimeline"):ResolveId("idMoment-NewMoment")
	if control then
		control:delete()
	end
end

---
--- Stops the animation of the given character.
---
--- This function sets the current frame of the character's animation to the first frame, sets the animation speed to 0, and sets the animation to the default state. It then creates a new "NewMoment" control in the "AnimMetadataEditorTimeline" dialog.
---
--- @param socket table The socket object (unused).
--- @param character table The character object to stop the animation for.
function GedOpAnimMetadataEditorStop(socket, character)
	character.Frame = character:GetAnimPhase(1)
	character.anim_speed = 0
	character:SetAnimHighLevel()
	GetDialog("AnimMetadataEditorTimeline"):CreateNewMomentControl()
end

---
--- Toggles the loop animation state of the given character.
---
--- This function sets the `loop_anim` flag of the given character to the opposite of its current value. If the character is now in a loop animation and the current frame is the last frame of the animation, it sets the animation speed to 1000 and resets the animation to the beginning.
---
--- @param socket table The socket object (unused).
--- @param character table The character object to toggle the loop animation for.
function GedOpAnimationMomentsEditorToggleLoop(socket, character)
	character.loop_anim = not character.loop_anim
	if character.loop_anim and character.Frame == character.anim_duration - 1 then
		character.anim_speed = 1000
		character:Setanim(character.anim or character:Getanim())
	end
end

---
--- Sets the preview speed of the animation for the current character in the Animation Moments Editor.
---
--- @param socket table The socket object (unused).
--- @param speed number The new preview speed for the animation.
function GedOpAnimationMomentsEditorToggleSpeed(socket, speed)
	local character = GetAnimationMomentsEditorObject()
	character:SetPreviewSpeed(speed)
	GedObjectModified(character)
end

---
--- Opens the Appearance Editor for the given character.
---
--- @param socket table The socket object (unused).
--- @param character table The character object to open the Appearance Editor for.
function GedOpOpenAppearanceEditor(socket, character)
	OpenAppearanceEditor(character.Appearance)
end

---
--- Saves all animation metadata.
---
--- This function wipes any deleted animation metadata, then saves all animation metadata to disk.
---
function GedOpSaveAnimMetadata()
	WipeDeleted()
	AnimMetadata:SaveAll("save all", "user request")
end

if FirstLoad then
	AnimationMomentsEditor = false
	AnimationMomentsEditorMode = false
	AnimMetadataEditorTimelineDragging = false        -- indicates dragging over the timeline bar
	AnimMetadataEditorTimelineSelectedControl = false -- selected/dragged moment control
end

---
--- Returns the root object of the Animation Moments Editor.
---
--- @return table|nil The root object of the Animation Moments Editor, or `nil` if the Animation Moments Editor is not active.
function GetAnimationMomentsEditorObject()
	return AnimationMomentsEditor and AnimationMomentsEditor.bound_objects["root"]
end

---
--- Binds the objects required for the Animation Moments Editor.
---
--- This function is responsible for setting up the necessary objects and filters for the Animation Moments Editor.
--- It binds the "Animations" object to the editor, and if the editor is in "selection" mode, it sets up a filter
--- to only show animations that belong to the selected entity. It also binds the "AnimationMetadata" object to the
--- editor, which contains the metadata for the currently selected animation.
---
--- @param character table The character object whose animation metadata should be bound to the editor.
function AnimationMomentsEditorBindObjects(character)
	if not AnimationMomentsEditor then return end
	
	local anim = character:GetProperty("anim")
	local entity = character:GetInheritedEntity(anim)
	
	AnimationMomentsEditor:BindObj("Animations", Presets.AnimMetadata)
	if AnimationMomentsEditorMode == "selection" then
		AnimationMomentsEditor:rfnBindFilterObj("Animations|tree", "AnimationsFilter",
			GedFilter:new{ FilterObject = function(self, obj) return obj.group == entity end })
	end
	
	local group = Presets.AnimMetadata[entity] or empty_table
	local preset = group[anim]
	if not preset then return end
	AnimationMomentsEditor:BindObj("AnimationMetadata", preset)
	
	GedObjectModified(character)
	GedObjectModified(Presets.AnimMetadata)
	GedObjectModified(preset)
	if preset.Moments then
		GedObjectModified(preset.Moments)
		for _, moment in ipairs(preset.Moments) do
			GedObjectModified(moment)
		end
	end
end

---
--- Checks if the given appearance has the specified animation.
---
--- @param appearance table The appearance object to check.
--- @param animation string The animation to check for.
--- @return boolean true if the appearance has the specified animation, false otherwise.
function AppearanceHasAnimation(appearance, animation)
	return appearance and appearance.Body and table.find(GetStates(appearance.Body), animation)
end

---
--- Locates an appearance preset by the specified animation.
---
--- If the default appearance preset has the specified animation, it is returned. Otherwise, this function
--- searches through all appearance presets to find one that has the specified animation, and returns that
--- preset's ID. If no preset is found with the specified animation, this function returns `nil`.
---
--- @param animation string The animation to search for.
--- @param default string The default appearance preset to check first.
--- @return string|nil The ID of the appearance preset that has the specified animation, or `nil` if none is found.
function AppearanceLocateByAnimation(animation, default)
	local appearance = default or LocalStorage.AME_LastAppearance
	if not AppearanceHasAnimation(AppearancePresets[appearance], animation) then
		local found
		ForEachPreset("AppearancePreset", function(preset)
			if AppearanceHasAnimation(preset, animation) then
				appearance = preset.id
				found = true
				return "break"
			end
		end)
		if not found then
			return
		end
	end
	return appearance
end

---
--- Opens the Animation Moments Editor for the specified target object and animation.
---
--- @param target table The target object to open the editor for. This can be an appearance preset or a character object.
--- @param animation string The animation to open the editor for. If this is provided and the target is an appearance preset, the function will locate the appropriate preset that has the specified animation.
--- @return boolean true if the editor was successfully opened, false otherwise.
function OpenAnimationMomentsEditor(target, animation)
	local mode = IsValid(target) and "selection" or "appearance"
	
	if mode == "appearance" and animation then
		target = AppearanceLocateByAnimation(animation, target)
		if not target then return end
	end
	
	PopulateParentTableCache(Presets.AnimMetadata)
	
	CreateRealTimeThread(function()
		AnimationMomentsEditorMode = mode
		local obj
		if mode == "appearance" then
			local pos, dir = camera.GetEye(), camera.GetDirection()
			local pos = terrain.IntersectRay(pos, pos + dir) or pos:SetTerrainZ()
			obj = AppearanceObjectAME:new{init_pos = pos}
			obj:ApplyAppearance(target)
			obj:SetPos(pos)
			obj:SetGameFlags(const.gofRealTimeAnim)
		else
			obj = SelectionObjectAME:new()
			obj:SetSelectedObj(target)
		end
		if not AnimationMomentsEditor then
			AnimationMomentsEditor = OpenGedApp("AnimMetadataEditor", obj, { PresetClass = "AnimMetadata", WarningsUpdateRoot = "Animations" }) or false
			OpenDialog("AnimMetadataEditorTimeline", GetDevUIViewport())
		else
			local old = GetAnimationMomentsEditorObject()
			AnimationMomentsEditor:BindObj("root", obj)
			DoneObject(old)
		end
		obj:OnEditorOpen(AnimationMomentsEditor)
		if mode == "appearance" or animation then
			obj:Setanim(animation or "idle")
		end
		obj:UpdateAnimMetadataSelection()
		InitializeWarningsForGedEditor(AnimationMomentsEditor, "initial")
	end)
	return true
end

---
--- Closes the Animation Moments Editor.
---
--- @param wait boolean If true, the function will wait until the Animation Moments Editor is fully closed before returning.
---
function CloseAnimationMomentsEditor(wait)
	if AnimationMomentsEditor then
		AnimationMomentsEditor:Send("rfnApp", "Exit")
	end
	if wait then
		while AnimationMomentsEditor do
			Sleep(10)
		end
	end
end

function OnMsg.GedClosing(ged_id)
	if AnimationMomentsEditor and AnimationMomentsEditor.ged_id == ged_id then
		CloseDialog("AnimMetadataEditorTimeline")
		local character = GetAnimationMomentsEditorObject()
		if IsValid(character) then
			DoneObject(character)
		end
		AnimationMomentsEditorMode = false
		AnimationMomentsEditor = false
	end	
end

function OnMsg.GedOnEditorSelect(obj, selected, ged_editor)
	if selected and ged_editor == AnimationMomentsEditor then
		if IsKindOf(obj, "AnimMetadata") then
			SuspendObjModified("GedOnEditorSelect")
			local character = GetAnimationMomentsEditorObject()
			character:OnAnimMetadataSelect(obj)
			GedObjectModified(character)
			ResumeObjModified("GedOnEditorSelect")
		end
	end
end


local function EditorSelectionChanged()
	if AnimationMomentsEditor and AnimationMomentsEditorMode == "selection" then
		local sel_obj = editor.GetSel()[1]
		local character = GetAnimationMomentsEditorObject()
		if not IsValid(sel_obj) or not character then
			CloseAnimationMomentsEditor()
		else
			character:SetSelectedObj(sel_obj)
			character:UpdateSelectedObj()
		end
	end
end

function OnMsg.EditorSelectionChanged(objects)
	if AnimationMomentsEditor and AnimationMomentsEditorMode == "selection" then
		DelayedCall(0, EditorSelectionChanged)
	end
end


function OnMsg.ChangingMap(map, mapdata, handler_fns)
	table.insert(handler_fns, CloseAnimationMomentsEditor)
end