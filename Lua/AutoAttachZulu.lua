--- Destroys the auto-attach objects associated with this object and sets the auto-attach mode to "OFF".
-- This function is called when the object is destroyed to ensure the auto-attach state is properly cleaned up.
function AutoAttachObject:OnDestroy()
	if self:GetAutoAttachMode("OFF") ~= "" then
		self:SetAutoAttachMode("OFF")
	end
end

--- Sets the state of the AutoAttachObject and handles the auto-attach behavior.
-- This function is responsible for destroying any existing auto-attach objects, clearing the attach members,
-- and then calling the original SetState function. It also sets the auto-attach mode based on the new state.
-- @param state The new state to set for the object.
-- @param flags (optional) Flags to pass to the original SetState function.
-- @param crossfade (optional) Crossfade duration to pass to the original SetState function.
-- @param speed (optional) Speed to pass to the original SetState function.
function AutoAttachObject:SetState(state, flags, crossfade, speed)
	self:DestroyAutoAttaches()
	self:ClearAttachMembers()
	
	-- Call original SetState
	if speed == nil and flags == nil and crossfade == nil then
		g_CObjectFuncs.SetState(self, state)
	elseif speed == nil and crossfade == nil then
		g_CObjectFuncs.SetState(self, state, flags)
	elseif crossfade == nil then
		g_CObjectFuncs.SetState(self, state, flags, crossfade)
	else
		g_CObjectFuncs.SetState(self, state, flags, crossfade, speed)
	end
	
	local mode = (state ~= "broken") and self:GetAutoAttachMode() or false
	self:SetAutoAttachMode(mode)
end

---
--- Sets the auto-attach mode for the object.
---
--- This function is responsible for handling the auto-attach behavior when the mode is set to "OFF". It will play a "DecorState" FX if the object is a `DecorStateFXObject`. It will also restore any attached `FloatingDummyCollision` objects and attach the object to a `FloatingDummy` if one exists.
---
--- When the auto-attach mode is set, this function will destroy any existing auto-attach objects, clear the attach members, and then call `AutoAttachObjects()` to re-attach the object.
---
--- @param value The new auto-attach mode to set. Can be "OFF" or any other valid mode.
function AutoAttachObject:SetAutoAttachMode(value)
	if self.auto_attach_mode ~= value and value == "OFF" and self:IsKindOf("DecorStateFXObject") then
		PlayFX("DecorState", "end", self, self:GetStateText())
	end
	
	local parent = self:GetParent()
	local floatingDummy = GetTopmostParent(self)
	
	if not IsKindOf(floatingDummy, "FloatingDummy") then
		floatingDummy = false
	end
	if floatingDummy then
		self:ForEachAttach("FloatingDummyCollision", RestoreFloatingDummyAttach)
		MapForEach(self:GetPos(), guim * 10, "FloatingDummyCollision", function(o)
			if o.clone_of == self then
				RestoreFloatingDummyAttach(o)
			end
		end)
	end
	
	self.auto_attach_mode = value
	self:DestroyAutoAttaches()
	self:ClearAttachMembers()
	self:AutoAttachObjects()
	
	if floatingDummy then
		AttachObjectToFloatingDummy(self, floatingDummy, parent ~= floatingDummy and parent or nil)
	end
end

---
--- Handles the auto-attach mode when certain editor properties are set on the object.
---
--- This function is called when the "AllAttachedLightsToDetailLevel" or "StateText" properties are set on the object. It updates the auto-attach mode of the object and handles any attached lights accordingly.
---
--- If the "AllAttachedLightsToDetailLevel" property is set, this function will call `Stealth_HandleLight()` on each attached light object to update their detail level.
---
--- @param prop_id The ID of the property that was set.
--- @param old_value The previous value of the property.
--- @param ged The GED object associated with the property.
function AutoAttachObject:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "AllAttachedLightsToDetailLevel" or prop_id == "StateText" then
		self:SetAutoAttachMode(self:GetAutoAttachMode())
		if prop_id == "AllAttachedLightsToDetailLevel" then
			self:ForEachAttach(function(attach)
				if IsKindOf(attach, "Light") then
					Stealth_HandleLight(attach)
				end
			end)
		end
	end
	Object.OnEditorSetProperty(self, prop_id, old_value, ged)
end
