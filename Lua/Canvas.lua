-- Swaying of all canvas objects depends on the wind slot they lie in. Each slot has wind direction and strength.
-- Wind strength can be strong or weak depending on const.StrongWindThreshold which is % of the const.WindMaxStrength
-- absolute value. Canvasses have different sway animation for weak and for strong wind. They also have 2 two different
-- animations depending on whether they are placed "Next to Wall" or "Freely Sway"("Sway Type" property). 
-- This makes for total of 4 animations. There is also "Never Sway" option for that property which just places the object in
-- "idle" state. The animations have these strange names depending on wind strength/sway type:
--
--    - Strong Wind:
--			* "Next to Wall"		- idle_Wind
--			* "Freely Sway" 		- idle_Wind_No_Wall
--    - Weak Wind:
--			* "Next to Wall" 	- idle_Wall
--			* "Freely Sway" 		- idle_No_Wall
--
-- In case the Canvas object is SlabWallWindow it can be also either broken or intact. For its broken version the above
-- animations are using "broken_" as prefix instead of "idle_".
--
-- Changing light model or weather(via GameState) forces updating of the wind animations of Canvas objects. If the object is
-- not "Never Sway" its animation is choosen using the table above. For windows there is additional chance of not swaying
-- even when "Sway Type" is not set to "Never Sway". This chance is different for weak and strong wind and is defined by
-- const.WindStrongSwayChance and const.WindWeakSwayChance. Anyway the canvasses can sway only if they lie on the grid
-- with some positive wind in their slot.
--
-- In the case of weak wind the corresponding canvas animation is blended with the idle/broken base animation using
-- wind strength as animation weight factor. In case of strong wind no blending is executed. Blending can be disabled
-- per entity from Entity Spec Editor using the "Disable Canvas Wind Blending" property.

-- If during the update the animation is changed its phase is randomized so the objects are not synced. 
--
-- FX-es are fired upon changing animations, e.g.:
--		WindWeak-start/end-Window0_1-Wall
--		WindStrong-end-MilitaryFlag_01-No Wall
--
--
-- NOTE: currently const.StrongWindThreshold is 100%.

DefineClass.Canvas = {
	__parents = {"WindAffected", "Object", "PropertyObject"},
	flags = {gofRealTimeAnim = true},
	
	properties = {
		{category = "Canvas", id = "SwayType", name = "Sway Type", editor = "dropdownlist",
			items = {"Never Sway", "Next To Wall", "Freely Sway"}, default = "Freely Sway"},
		{category = "Canvas", id = "StateText", editor = "combo", default = "idle",
			items       = function(obj) return obj:GetStatesTextTable(obj.StateCategory) end,
			OnStartEdit = function(obj) obj:SetRealtimeAnim(true) end,
			OnStopEdit  = function(obj) obj:SetRealtimeAnim(false) end, 
			buttons = {{name = "Play once", func = "BtnTestOnce"}, {name = "Loop", func = "BtnTestLoop"}, {name = "Test", func = "BtnTestState"}},			dont_save = true,
			no_edit = true, dont_save = true,
		},
	},
	
	fx_actor_class = "Canvas",
}

--- Returns the base wind state for the Canvas object.
---
--- If the Canvas object is a SlabWallWindow, the base state is determined based on whether the window is broken or destroyed. If the window is broken, the base state is "broken", otherwise it is "idle".
---
--- If the Canvas object does not have the determined base state animation, the base state is set to "idle" and a warning is logged.
---
--- @return string The base wind state for the Canvas object.
function Canvas:GetBaseWindState()
	local base_state = "idle"
	if IsKindOf(self, "SlabWallWindow") then
		if self.is_destroyed then
			local _
			_, base_state = self:GetDestroyedEntityAndState()
		else
			base_state = self:IsBroken() and "broken" or base_state
		end
	end
	
	if not IsValidAnim(self, base_state) then
		StoreErrorSource(self, string.format("Canvas window does not have '%s' animation, falling back to 'idle'", base_state))
		base_state = "idle"
	end
	
	return base_state
end

---
--- Randomizes the animation phase of the Canvas object on the specified channel(s).
---
--- @param second_channel boolean (optional) If true, the phase will also be set on the second animation channel.
---
function Canvas:RandomizePhase(second_channel)
	local duration = GetAnimDuration(self:GetEntity(), self:GetState())
	local phase = self:Random(duration)
	self:SetAnimPhase(1, phase)
	if second_channel then
		self:SetAnimPhase(2, phase)
	end
end

---
--- Returns the appropriate wind animation for the Canvas object based on the base state and wind state.
---
--- If the requested wind animation does not exist, a warning is logged and the base state is returned instead.
---
--- @param wind_state string The wind state to use in the animation name.
--- @param base_state string The base state to use in the animation name.
--- @return string The name of the wind animation.
function Canvas:GetWindAnim(wind_state, base_state)
	local anim = string.format(wind_state, base_state)
	if not IsValidAnim(self, anim) then
		StoreWarningSource(self, string.format("Canvas object without wind animation '%s', falling back to '%s'", anim, base_state))
		return base_state
	end
	
	return anim
end

local strong_chance = const.WindStrongSwayChance
local weak_chance = const.WindWeakSwayChance

---
--- Determines whether the Canvas object should sway based on its sway type and the current wind strength.
---
--- @return boolean Whether the Canvas object should sway.
function Canvas:ShouldSway()
	local should_sway = self.SwayType ~= "Never Sway" and self.SwayType ~= "Never Sway Broken"
	
	return should_sway and self:GetWindStrength() > 0
end

---
--- Updates the wind animation state of the Canvas object based on its sway type and the current wind strength.
---
--- If the Canvas object should not sway, it will be set to the base wind state. Otherwise, the appropriate wind animation will be played based on the sway type and wind strength.
---
--- @param sync boolean (optional) If true, the wind animation will be synchronized with other interactions.
---
function Canvas:UpdateWind(sync)
	local base_state = self:GetBaseWindState()
	if not self:ShouldSway(sync) then
		if base_state == "idle" then
			if self:HasState("idle_Static") then
				self:ClearAnim(2)
				self:SetState("idle_Static")
			else
				--StoreWarningSource(self, string.format("Canvas window does not have idle_Static animation, falling back to 'idle'"))
				self:SetState(base_state)
			end
		else
			self:SetState(base_state)
		end
		return
	end
	
	local entity_data = EntityData[self.class] and EntityData[self.class].entity
	local wind_blending_disabled = entity_data.DisableCanvasWindBlending or self:IsStaticAnim(GetStateIdx(base_state))
	local state = self:GetStateText()
	if self:IsStrongWind() then
		wind_blending_disabled = true
		if self.SwayType == "Next To Wall" or self.SwayType == "Next To Wall Broken" then
			local anim = self:GetWindAnim("%s_Wind", base_state)
			if state ~= anim then
				PlayFX("WindWeak", "end", self, "Wall")
				self:SetState(anim)
				self:RandomizePhase()
				PlayFX("WindStrong", "start", self, "Wall")
			end
		elseif self.SwayType == "Freely Sway" then
			local anim = self:GetWindAnim("%s_Wind_No_Wall", base_state)
			if state ~= anim then
				PlayFX("WindWeak", "end", self, "No Wall")
				self:SetState(anim)
				self:RandomizePhase()
				PlayFX("WindStrong", "start", self, "No Wall")
			end
		end
	else
		if self.SwayType == "Next To Wall" or self.SwayType == "Next To Wall Broken" then
			local anim = self:GetWindAnim("%s_Wall", base_state)
			if state ~= anim then
				PlayFX("WindStrong", "end", self, "Wall")
				self:SetAnim(1, anim)
				self:SetAnim(2, base_state)
				self:RandomizePhase(true)
				PlayFX("Blend WindWeak", "start", self, "Wall")
			end
		elseif self.SwayType == "Freely Sway" then
			local anim = self:GetWindAnim("%s_No_Wall", base_state)
			if state ~= anim then
				PlayFX("WindStrong", "end", self, "No Wall")
				self:SetAnim(1, anim)
				self:SetAnim(2, base_state)
				self:RandomizePhase(true)
				PlayFX("WindWeak", "start", self, "No Wall")
			end
		end
		-- change the weighting
		if wind_blending_disabled then
			if not self:IsStaticAnim(self:GetState()) then
				self:SetAnimWeight(1, 100)
				self:SetAnimWeight(2, 0)
			end
		else
			local strong_wind_threshold = GetStrongWindThreshold()
			local wind_strength = self:GetWindStrength()
			assert(wind_strength <= strong_wind_threshold)
			local wind_anim_weight = Max(MulDivTrunc(wind_strength, 100, strong_wind_threshold), 1)
			self:SetAnimWeight(1, wind_anim_weight)
			self:SetAnimWeight(2, 100 - wind_anim_weight)
		end
		self:RandomizePhase(self:GetAnim(2) > 0)
	end
end

---
--- Callback function that is called when the `SwayType` property of the `Canvas` object is set.
--- This function updates the wind behavior of the canvas object based on the new `SwayType` value.
---
--- @param self Canvas The canvas object instance.
--- @param prop_id string The ID of the property that was set.
---
function Canvas:OnEditorSetProperty(prop_id)
	if prop_id == "SwayType" then
		self:UpdateWind()
	end
end

DefineClass.CanvasNextToWallOnly = {
	__parents = {"Canvas"},
	
	properties = {
		{category = "Canvas", id = "SwayType", name = "Sway Type", editor = "dropdownlist", read_only = true,
			items = {"Never Sway", "Never Sway Broken", "Next To Wall"}, default = "Next To Wall"},
	},
}

DefineClass.CanvasWindow = {
	__parents = {"CanvasNextToWallOnly", "SlabWallWindow", "AutoAttachCallback"},
	properties = {
		{category = "Canvas", id = "SwayType", name = "Sway Type", editor = "dropdownlist", default = "Next To Wall",
			items = {"Never Sway", "Never Sway Broken", "Next To Wall", "Next To Wall Broken"}
		},
	},
}

---
--- Callback function that is called after the `CanvasWindow` object is loaded.
--- This function sets the proper state of the canvas window based on its `SwayType` property.
---
--- @param self CanvasWindow The canvas window object instance.
---
function CanvasWindow:PostLoad()
	self:SetProperState()
end

---
--- Determines whether the canvas window should sway based on the current wind conditions.
---
--- @param self CanvasWindow The canvas window object instance.
--- @param sync boolean Whether the sway calculation should be synchronized with other interactions.
--- @return boolean True if the canvas window should sway, false otherwise.
---
function CanvasWindow:ShouldSway(sync)
	if not Canvas.ShouldSway(self, sync) then
		return false
	end
	local rand = sync and InteractionRand(100) or AsyncRand(100)
	return rand < (self:IsStrongWind() and strong_chance or weak_chance)
end

---
--- Attaches the CanvasWindow object to its parent and sets the proper state of the canvas window based on its `SwayType` property.
---
--- @param self CanvasWindow The canvas window object instance.
--- @param parent any The parent object to which the canvas window is being attached.
--- @param spot any The attachment spot on the parent object.
---
function CanvasWindow:OnAttachToParent(parent, spot)
	self:SetProperty("SwayType", "Never Sway")
	self:SetProperState()
end

---
--- Sets the state of the canvas window based on the provided window_state.
---
--- If the pass_through_state is "intact" and the window_state is "broken", the state is set to "idle" and a "WindowBreak" FX is played.
--- The pass_through_state is then set to the provided window_state.
--- Finally, the wind is updated.
---
--- @param self CanvasWindow The canvas window object instance.
--- @param window_state string The new window state, either "intact" or "broken".
--- @param no_fx boolean Whether to skip playing the "WindowBreak" FX.
---
function CanvasWindow:SetWindowState(window_state, no_fx)
	if self.pass_through_state == "intact" and window_state == "broken" then
		self:SetState("idle")
		if not no_fx then
			PlayFX("WindowBreak", "start", self)
		end
	end
	self.pass_through_state = window_state
	self:UpdateWind()
end

---
--- Sets the proper state of the canvas window based on its `SwayType` property.
---
--- If the `SwayType` is "Next To Wall Broken" or "Never Sway Broken", the state is set to "broken". Otherwise, the state is set to "idle".
--- The wind state is set to "Wind" if the window is in strong wind, or "Wall" if it is not.
--- The `pass_through_state` is set to "broken" if the state is "broken", or "intact" otherwise. If the `pass_through_state` is "intact" and the window is a `SlabWallWindowOpen`, the `pass_through_state` is set to "open".
--- The final state is set to the appropriate animation based on the state and wind conditions, or to the state if the animation is not valid.
---
--- @param self CanvasWindow The canvas window object instance.
---
function CanvasWindow:SetProperState()
	local broken = self.SwayType == "Next To Wall Broken" or self.SwayType == "Never Sway Broken"
	local state = broken and "broken" or "idle"
	local wind = self:IsStrongWind() and "Wind" or "Wall"
	local anim = string.format("%s_%s", state, wind)
	self.pass_through_state = broken and "broken" or "intact"
	if self.pass_through_state == "intact" and IsKindOf(self, "SlabWallWindowOpen") then
		self.pass_through_state = "open"
	end
	self:SetState(IsValidAnim(self, anim) and anim or state)
end

---
--- Called when a property of the CanvasWindow is set in the editor.
---
--- If the "SwayType" property is set, this function updates the proper state of the canvas window and the wind.
---
--- @param self CanvasWindow The canvas window object instance.
--- @param prop_id string The ID of the property that was set.
---
function CanvasWindow:OnEditorSetProperty(prop_id)
	if prop_id == "SwayType" then
		self:SetProperState()
		self:UpdateWind()
	end
end

DefineClass.CanvasWindowWindStateFallback = {
	__parents = {"CanvasWindow"},
}

---
--- Gets the appropriate wind animation for the given wind state and base state.
---
--- If the wind animation is not valid for the given wind state and base state, the base state is returned instead.
---
--- @param wind_state string The current wind state.
--- @param base_state string The base state.
--- @return string The appropriate wind animation.
---
function CanvasWindowWindStateFallback:GetWindAnim(wind_state, base_state)
	local anim = string.format(wind_state, base_state)
	if not IsValidAnim(self, anim) then
		return base_state
	end
	
	return anim
end

DefineClass.MilitaryCamp_LegionFlag_Short = {
	__parents = {"Canvas"}
}

local offset = point(3 * guim, 0, 0)

---
--- Gets the wind sample position for the MilitaryCamp_LegionFlag_Short object.
---
--- @return point The wind sample position.
---
function MilitaryCamp_LegionFlag_Short:GetWindSamplePos()
	return self:GetPos() + Rotate(offset, self:GetAngle())
end