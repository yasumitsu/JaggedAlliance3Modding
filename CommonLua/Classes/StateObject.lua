DefineClass.StateObject =
{
	__parents = { "CooldownObj" },
	__hierarchy_cache = true,

	so_state = false,
	so_enabled = false,
	so_action = false,
	so_action_param = false,
	so_target = false,
	so_active_zone = false,
	so_anim_control_thread = false,
	so_movement_thread = false,
	so_state_time_start = 0,
	so_target_trigger = false,
	so_tick_enable = false,
	so_tick_thread = false,
	so_aitick_enable = true,
	so_aitick_thread = false,
	so_context = false,
	so_changestateidx = 0,  -- times state has been changed
	so_prev_different_state_id = false, -- TODO: for debug only, remove this member
	so_next_state_id = false,
	so_trigger_object = false,
	so_trigger_action = false,
	so_trigger_target = false,
	so_trigger_target_pos = false,
	so_cooldown = "",
	so_buffered_trigger = false,
	so_buffered_trigger_object = false,
	so_buffered_trigger_action = false,
	so_buffered_trigger_target = false,
	so_buffered_trigger_target_pos = false,
	so_buffered_trigger_time = false,
	so_buffered_times = false,

	so_debug_triggers = config.StateObjectTraceLog or false,
	so_state_start_time = false,
	so_changestateidx_at_start_time = 0, -- so_changestateidx when first change_state in this tick

	so_states = false,

	so_state_debug = false,
	so_compensate_anim_rotation = {},
	so_compensate_angle = false,
	so_context_sync = false,
	so_state_destructors = false,
	so_step_modifier = 100,
	so_speed_modifier = 100,
	so_state_anim_speed_modifier = 100,
	so_action_start_passed = false,
	so_action_hit_passed = false,
	so_wait_phase_threads = false,
	so_repeat = false,
	so_repeat_thread = false,
	so_net_sync_stateidx = false,
	so_net_nav = false,
	so_net_pos = false,
	so_net_pos_time = false,
	so_net_nav_sent_time = false,
	so_net_target = false,
	so_net_target_sent_time = false,
	so_net_target_thread = false,
}

---
--- Finds the state set for the given class by recursively searching the class hierarchy.
---
--- @param class string The class name to search for.
--- @return table|nil The state set for the given class, or `nil` if not found.

function FindStateSet( class )
	local check_classes = { class }

	while #check_classes > 0 do
		local name = table.remove(check_classes, 1)
		local set = DataInstances.StateSet[name]

		if set then
			return set
		end

		local parents = _G[name].__parents
		for i = 1, #parents do
			table.insert(check_classes, parents[i])
		end
	end
end

---
--- Initializes the StateObject by finding the state set for the class and setting the `so_states` field.
---
--- If the `so_tick_enable` field is false, this function checks that the state set does not contain any "Tick" triggers, and asserts if one is found.
---
--- @param self StateObject The StateObject instance being initialized.
---
function StateObject:Init()
	local set = FindStateSet( self.class )
	if set then
		self.so_states = set.so_states
	end

	--[[
	-- find the state set
	local check_classes = { self.class }
	while #check_classes > 0 do
		local name = table.remove(check_classes, 1)
		local set = DataInstances.StateSet[name]
		if set then
			self.so_states = set.so_states
			break
		end
		local parents = _G[name].__parents
		for i = 1, #parents do
			table.insert(check_classes, parents[i])
		end
	end
	]]
	if Platform.developer then
		if not self.so_tick_enable then
			for state_name, state_data in sorted_pairs(self.so_states) do
				for i_trigger = 1, #state_data do
					local trigger = state_data[i_trigger].trigger
					if trigger == "Tick" then
						assert(false, string.format("\"Tick\" trigger used in state \"%s\" of state object \"%s\" with \"so_tick_enable = false\"", state_name, self.class))
						break
					end
				end
			end
		end
	end
end

---
--- Destroys the StateObject by changing its state to `false`, and logs an error if the StateObject is still in a state after this.
---
--- @param self StateObject The StateObject instance being destroyed.
---
function StateObject:Done()
	if self.so_state then
		self:ChangeState(false)
		if self.so_state then
			printf("ERROR: %s entered state %s on destroy!", self.class, self.so_state.name)
		end
	end
end

---
--- Pushes a state destructor function to the StateObject's list of destructors.
---
--- The destructor function will be called when the StateObject's state changes.
---
--- @param self StateObject The StateObject instance.
--- @param dtor function The destructor function to push.
---
function StateObject:PushStateDestructor(dtor)
	local destructors = self.so_state_destructors
	if destructors then
		local count = destructors[1] + 1
		destructors[1] = count
		destructors[count + 1] = dtor
	else
		self.so_state_destructors = { 1, dtor }
	end
end

---
--- Changes the StateObject's state set to the specified set name.
---
--- @param self StateObject The StateObject instance.
--- @param name string The name of the StateSet to change to.
---
function StateObject:ChangeSet(name)
	local set = DataInstances.StateSet[name]
	if set then
		self.so_states = set.so_states
	end
end

---
--- Changes the StateObject's state to the specified state ID, if the current state is different.
---
--- @param self StateObject The StateObject instance.
--- @param state_id string The ID of the state to change to.
---
function StateObject:ChangeStateIfDifferent(state_id)
	if not self.so_state or self.so_state.name ~= state_id then
		self:ChangeState(state_id)
	end
end

MaxChangeStates = 10
CriticChangeStates = 15

---
--- Changes the state of the StateObject to the specified state ID, handling all necessary state transitions.
---
--- @param self StateObject The StateObject instance.
--- @param state_id string The ID of the state to change to.
--- @param is_triggered boolean Whether the state change was triggered by an external event.
--- @param trigger_object any The object that triggered the state change.
--- @param trigger_action string The action that triggered the state change.
--- @param trigger_target any The target of the triggering action.
--- @param trigger_target_pos Vec3 The position of the triggering target.
--- @param forced_target any The target to force the state change on.
--- @param forced_target_state string The state to force the target to change to.
---
function StateObject:InternalChangeState(state_id, is_triggered, trigger_object, trigger_action, trigger_target, trigger_target_pos, forced_target, forced_target_state)
	if self.so_debug_triggers then
		self:Trace("[StateObject1]<color 0 255 0>State changed</color> {1} prev {2}\n{3}", state_id, self.so_state, trigger_object, trigger_action, trigger_target, trigger_target_pos, self:GetPos(), self:GetAngle(), GetStack(1))
	end
	self.so_enabled = (state_id or "") ~= ""
	self.so_next_state_id = state_id
	if self.so_state then
		if self.so_cooldown ~= "" then
			self:SetCooldown(self.so_cooldown)
		end
		local destructors = self.so_state_destructors
		local count = destructors and destructors[1] or 0
		while count > 0 do
			local dtor = destructors[count + 1]
			destructors[count + 1] = false
			destructors[1] = count - 1
			dtor(self)
			count = destructors[1]
		end
		if self.so_action_start_passed then
			self.so_action_start_passed = false
			local stateidx = self.so_changestateidx
			self:StateActionMoment("end")
			if stateidx ~= self.so_changestateidx then return end
		end
	end
	if self.so_compensate_angle then
		self:SetAngle(self:GetAngle() + self.so_compensate_angle, 0)
		self.so_compensate_angle = false
	end
	local state = false
	if (state_id or "") ~= "" then
		state = self.so_states[state_id]
		if not state then
			printf('%s invalid state "%s"', self.class, state_id)
			self:InternalChangeState(self.so_states.Error and "Error" or false)
			return
		end
	end
	self.so_changestateidx = self.so_changestateidx + 1
	local stateidx = self.so_changestateidx
	self.so_next_state_id = false
	if is_triggered and self.so_state_start_time == GameTime() then
		local times = self.so_changestateidx - self.so_changestateidx_at_start_time
		if times > MaxChangeStates then
			local error_msg = string.format('%s has too many state changes: "%s" --> "%s" --> "%s"', self.class, tostring(self.so_prev_different_state_id), self.so_state and self.so_state.name or "false", tostring(state_id))
			assert(times ~= MaxChangeStates + 1, error_msg) -- only once
			print(error_msg)
			if self.so_changestateidx - self.so_changestateidx_at_start_time > CriticChangeStates then
				if state_id and state_id ~= "Error" then
					self:InternalChangeState(self.so_states.Error and "Error" or false)
					return
				end
			end
		end
	else
		self.so_state_start_time = GameTime()
		self.so_changestateidx_at_start_time = self.so_changestateidx
	end
	self:WakeupWaitPhaseThreads()

	self:SetMoveSys(false)
	if self.so_anim_control_thread and self.so_anim_control_thread ~= CurrentThread() then
		DeleteThread(self.so_anim_control_thread)
	end
	self.so_anim_control_thread = nil
	self.so_repeat = nil
	self.so_repeat_thread = nil
	self.so_net_target = nil
	self.so_net_target_sent_time = nil
	if self.so_net_target_thread then
		DeleteThread(self.so_net_target_thread)
		self.so_net_target_thread = nil
	end

	Msg(self)

	self.so_target_trigger = false

	if not state then
		-- disable state machine
		self.so_state = nil
		self.so_action = nil
		self.so_action_param = nil
		self.so_target = nil
		self.so_active_zone = nil
		self.so_state_time_start = nil
		self.so_buffered_trigger = nil
		self.so_buffered_trigger_time = nil
		self.so_trigger_object = nil
		self.so_trigger_action = nil
		self.so_trigger_target = nil
		self.so_trigger_target_pos = nil
		self.so_buffered_times = nil
		if CurrentThread() ~= self.so_tick_thread then
			DeleteThread(self.so_tick_thread)
		end
		self.so_tick_thread = nil
		if CurrentThread() ~= self.so_aitick_thread then
			DeleteThread(self.so_aitick_thread)
		end
		self.so_aitick_thread = nil
		self.so_step_modifier = nil
		self.so_state_anim_speed_modifier = nil
		self:SetModifiers("StateAction", nil)
		self:NewStateStarted()
		return
	end
	local same_state = self.so_state == state
	if not same_state then
		self.so_prev_different_state_id = self.so_state and self.so_state.name or false -- TODO: debug, remove this line
		self.so_state = state
	end
	if self.so_state_debug then
		self.so_state_debug:SetText(self.so_state.name)
	end
	self.so_action = self:GetStateAction()
	self.so_action_param = false

	-- Start
	self.so_state_time_start = GameTime()
	self.so_active_zone = "Start"
	self.so_state_time_start = GameTime()
	self.so_action_hit_passed = false

	self:StateChanged()

	-- Target
	local target = forced_target
	if forced_target == nil then
		target = self:FindStateTarget(self.so_state, trigger_object, trigger_action, trigger_target, trigger_target_pos)
		if stateidx ~= self.so_changestateidx then
			return
		end
	end
	self.so_trigger_object = trigger_object
	self.so_trigger_action = trigger_action
	self.so_trigger_target = trigger_target
	self.so_trigger_target_pos = trigger_target_pos
	self:SetStateTarget(target)
	self.so_net_target = self.so_target
	self.so_cooldown = self.so_state:GetInheritProperty(self, "cooldown") or ""

	-- Startup triggers
	self:RaiseTrigger("Start", trigger_object, trigger_action, trigger_target, trigger_target_pos)
	if stateidx ~= self.so_changestateidx then
		return -- this function calls itself recursively and should exit when state is changed
	end
	self:ExecBufferedTriggers()
	if stateidx ~= self.so_changestateidx then
		return -- this function calls itself recursively and should exit when state is changed
	end
	if self.so_tick_enable then
		self:RaiseTrigger("Tick")
		if stateidx ~= self.so_changestateidx then
			return -- this function calls itself recursively and should exit when state is changed
		end
	end
	self:RaiseTrigger("AITick")
	if stateidx ~= self.so_changestateidx then
		return -- this function calls itself recursively and should exit when state is changed
	end

	if forced_target_state then
		target:InternalChangeState(forced_target_state, is_triggered, self, false, false, false, self)
		if stateidx ~= self.so_changestateidx then
			return -- this function calls itself recursively and should exit when state is changed
		end
	else
		local target_trigger = self.so_state:GetInheritProperty(self, "target_trigger")
		if target_trigger and target_trigger ~= "" then
			if self:RaiseTargetTrigger(target_trigger) then
				self.so_target_trigger = target_trigger
			end
			if stateidx ~= self.so_changestateidx then
				return -- this function calls itself recursively and should exit when state is changed
			end
		end
	end
	if self.so_tick_enable and not self.so_tick_thread then
		self.so_tick_thread = CreateGameTimeThread(function(self)
			while self.so_tick_thread == CurrentThread() do
				Sleep(33)
				self:RaiseTrigger("Tick")
			end
		end, self)
		ThreadsSetThreadSource(self.so_tick_thread, "Tick trigger")
	end
	if self.so_aitick_enable and not self.so_aitick_thread then
		self.so_aitick_thread = CreateGameTimeThread(function(self)
			Sleep(BraidRandom(self.handle, 500))
			while self.so_aitick_thread do
				self:RaiseTrigger("AITick")
				Sleep(500)
			end
		end, self)
		ThreadsSetThreadSource(self.so_aitick_thread, "AITick trigger")
	end

	if self.so_state.restore_axis then
		self:SetAxis(axis_z, 100)
	end

	local state_lifetime = self.so_state:GetInheritProperty(self, "state_lifetime")
	if state_lifetime == "" then
		state_lifetime = "animation"
	end
	local anim = self.so_state:GetAnimation(self)
	self.so_compensate_angle = self.so_compensate_anim_rotation[anim] or false
	if anim ~= "" and not self:HasState(anim) then
		printf("Invalid animation %s for %s!", anim, self.class)
		if state_lifetime == "animation" then
			self:NextState()
			return
		end
	end
	if state_lifetime == "animation" and anim == "" then
		state_lifetime = "movement" -- backward compatibility
	end
	self:NewStateStarted()
	self:SetStateAnim(self.so_state, anim)
	local movement = self.so_state:GetInheritProperty(self, "movement")
	self:SetMoveSys(movement, state_lifetime == "movement")
	if stateidx ~= self.so_changestateidx then return end
	if state_lifetime == "animation" then
		self:StartStateAnimControl()
	else
		local state_duration = tonumber(state_lifetime)
		if state_duration then
			self.so_anim_control_thread = CreateGameTimeThread(function(self, stateidx, state_duration)
				Sleep(state_duration)
				if stateidx ~= self.so_changestateidx then return end
				self:NextState()
			end, self, stateidx, state_duration)
		end
	end
	self:SetModifiers("StateAction", self.so_action and self.so_action.modifiers)
	local animation_step = self.so_state:GetInheritProperty(self, "animation_step")
	self.so_step_modifier = tonumber(animation_step)
	local animation_speed = self.so_state:GetInheritProperty(self, "animation_speed")
	if animation_speed == "" then
		animation_speed = 100
	elseif StateAnimationSpeedCorrection[animation_speed] then
		animation_speed = StateAnimationSpeedCorrection[animation_speed](self)
	else
		animation_speed = tonumber(animation_speed)
	end
	self.so_state_anim_speed_modifier = animation_speed
	self:UpdateAnimSpeed()
	self:StateActionMoment("start")
end

--- Called when the state of the StateObject has changed.
-- This function is called whenever the state of the StateObject changes, such as when a new state is started or the current state is ended.
-- This function can be overridden in derived classes to implement custom behavior when the state changes.
function StateObject:StateChanged()
end

--- Called when a new state is started.
-- This function is called whenever a new state is started for the StateObject.
-- This function clears the path of the StateObject.
function StateObject:NewStateStarted()
	self:ClearPath()
end

---
--- Starts the animation control for the current state of the StateObject.
--- This function creates a new game time thread that controls the animation phases of the current state.
--- The thread will wait for the "Start" phase, then trigger the "action" state action moment, wait for the "Hit" phase, trigger the "hit" state action moment, wait for the "End" phase, trigger the "post-action" state action moment, and finally wait for the last phase before moving to the next state.
--- If the state changes during the animation control, the thread will exit early to avoid conflicting with the new state.
---
--- @param obj StateObject The StateObject to control the animation for. If not provided, the current StateObject is used.
---
function StateObject:StartStateAnimControl(obj)
	local stateidx = self.so_changestateidx
	self.so_anim_control_thread = CreateGameTimeThread(function(self, obj, stateidx)
		obj = obj or self
		-- PreAction
		obj:WaitPhase(obj:GetStateAnimPhase("Start"))
		-- Action
		self:StateActionMoment("action")
		if stateidx ~= self.so_changestateidx then return end
		obj:WaitPhase(obj:GetStateAnimPhase("Hit"))
		-- Hit
		self:StateActionMoment("hit")
		if stateidx ~= self.so_changestateidx then return end
		obj:WaitPhase(obj:GetStateAnimPhase("End"))
		-- PostAction
		self:StateActionMoment("post-action")
		if stateidx ~= self.so_changestateidx then return end
		obj:WaitPhase(obj:GetLastPhase())
		-- End state
		if stateidx ~= self.so_changestateidx then return end
		self:NextState()
	end, self, obj, stateidx)
	ThreadsSetThreadSource(self.so_anim_control_thread, "Animation control")
end

---
--- Sets the animation for the current state of the StateObject.
---
--- @param state StateObject The state object to set the animation for.
--- @param anim string The name of the animation to set.
--- @param flags number Flags to pass to the SetAnim function.
--- @param crossfade number The crossfade duration to use when transitioning to the new animation.
--- @param animation_phase string The animation phase to start the animation at.
---
--- This function sets the animation for the current state of the StateObject. It checks if the new animation is the same as the current animation, and if so, it may keep the same animation phase depending on the `animation_phase` parameter. If the animations are different, it sets the new animation with the specified flags and crossfade duration. It also handles updating the selection editor spots if the mesh file for the new animation is different from the old animation.
---
--- The `animation_phase` parameter can be one of the following values:
--- - `"KeepSameAnimPhase"`: Keep the same animation phase as the current animation.
--- - `"KeepSameAnimPhaseBeforeHit"`: Keep the same animation phase as the current animation, but only if the current phase is before the "Hit" phase.
--- - `""`: Start the animation at the default phase.
--- - Any other value: Start the animation at the phase specified by the `GetStateAnimPhase` function for the given animation and state.
---
function StateObject:SetStateAnim(state, anim, flags, crossfade, animation_phase)
	anim = anim or state:GetAnimation(self)
	if anim == "" then return end
	animation_phase = animation_phase or state:GetInheritProperty(self, "animation_phase")
	local old_anim = self:GetAnim(1)
	local same_anim = old_anim == EntityStates[anim]
	if same_anim and (animation_phase == "KeepSameAnimPhase" or animation_phase == "KeepSameAnimPhaseBeforeHit" and self:GetAnimPhase(1) < self:GetStateAnimPhase("Hit", anim, state)) then
		return
	end
	if not flags then
		flags = 0
	end
	if not crossfade then
		if same_anim and self:IsAnimLooping(1) then
			crossfade = -1
		else
			local animation_blending = state:GetInheritProperty(self, "animation_blending")
			local dontCrossfade = self.so_compensate_anim_rotation[anim] or animation_blending == "no"
			crossfade = dontCrossfade and 0 or -1
		end
	end
	self:SetAnim(1, anim, flags, crossfade)
	
	if Platform.developer and not same_anim and SelectionEditorShownSpots[self] and self:GetEntity() then
		if GetStateMeshFile(self:GetEntity(), old_anim) ~= GetStateMeshFile(self:GetEntity(), EntityStates[anim]) then
			local window, window_id = PropEditor_GetFirstWindow("SelectionEditor")
			if window then
				local selection_editor = window.main_obj
				if selection_editor:IsKindOf("SelectionEditor") and selection_editor[1] == self then
					selection_editor:ToggleSpots()
					selection_editor:ToggleSpots()
				end
			end
		end
	end
	
	local start_phase
	if animation_phase ~= "" and not (same_anim and animation_phase == "Random") then
		start_phase = self:GetStateAnimPhase(animation_phase, anim, state)
	end
	if start_phase and start_phase > 0 then
		self:SetAnimPhase(1, start_phase)
	end
end

---
--- Returns the last phase of the animation on the specified channel.
---
--- @param channel number The animation channel to get the last phase for.
--- @return number The last phase of the animation.
function StateObject:GetLastPhase(channel)
	local duration = GetAnimDuration(self:GetEntity(), self:GetAnim(channel or 1))
	return duration-1
end

---
--- Waits for the specified animation phase on the first animation channel.
---
--- @param phase number The animation phase to wait for.
--- @return boolean True if the wait was not interrupted, false otherwise.
function StateObject:WaitPhase(phase)
	local cur_phase = self:GetAnimPhase(1)
	local last_phase = self:GetLastPhase(1)
	phase = Min(phase, last_phase)
	
	local t = self:TimeToPhase(1, phase) or 0
	if t == 0 then
		return true
	end
	self.so_wait_phase_threads = self.so_wait_phase_threads or {}
	table.insert(self.so_wait_phase_threads, CurrentThread())
	local stateidx = self.so_changestateidx
	local interrupted
	while true do
		WaitWakeup(t)
		if not IsValid(self) or stateidx ~= self.so_changestateidx then
			interrupted = true
			break
		end
		t = self:TimeToPhase(1, phase) or 0
		if t == 0 then
			break
		end
		if self:IsAnimLooping(1) then
			local prev_phase = cur_phase
			cur_phase = self:GetAnimPhase(1)
			if cur_phase >= prev_phase then
				if phase >= prev_phase and phase <= cur_phase then
					break
				end
			elseif phase <= cur_phase or phase >= prev_phase then
				break
			end
		end
	end
	table.remove_value(self.so_wait_phase_threads, CurrentThread())
	return not interrupted
end

---
--- Updates the animation speed of the StateObject.
---
--- @param mod number The speed modifier to apply to the animation.
---
function StateObject:UpdateAnimSpeed(mod)
	mod = mod or self.so_state_anim_speed_modifier
	self.so_speed_modifier = mod
	self:SetAnimSpeed(1, mod * 10)
	self:SetAnimSpeed(2, mod * 10)
	self:SetAnimSpeed(3, mod * 10)
	self:WakeupWaitPhaseThreads()
	if self:IsKindOf("AnimMomentHook") then
		self:AnimMomentHookUpdate()
	end
end

---
--- Wakes up all threads that are waiting for the StateObject to reach a certain animation phase.
---
--- This function is called after the animation speed of the StateObject has been updated, to ensure
--- that any threads waiting for the animation to reach a certain phase are woken up.
---
--- @param self StateObject The StateObject instance.
---
function StateObject:WakeupWaitPhaseThreads()
	local wait_phase_threads = self.so_wait_phase_threads
	if not wait_phase_threads then return end
	for i = #wait_phase_threads, 1, -1 do
		if not Wakeup(wait_phase_threads[i]) then
			table.remove(wait_phase_threads, i)
		end
	end
end

---
--- Changes the state of the StateObject.
---
--- @param ... any Arguments to pass to the InternalChangeState function.
--- @return boolean Whether the state change was successful.
---
function StateObject:ChangeState(...)
	return self:InternalChangeState(...)
end

---
--- Synchronizes the state of the StateObject over the network.
---
--- This function is called when the state of the StateObject changes, in order to update the
--- state information on the network. It sends the necessary data to other clients to ensure
--- that the StateObject's state is properly synchronized.
---
--- @param trigger_id string The ID of the trigger that caused the state change.
--- @param trigger table The trigger object that caused the state change.
---
function StateObject:NetSyncState(trigger_id, trigger)
	if not netInGame or not self.so_state or self.so_net_sync_stateidx == self.so_changestateidx then
		return
	end
	local net_nav, trigger_target_pos, channeling_stopped, split_time, torso_angle
	if NetIsLocal(self) then
		if not (trigger and trigger.net_sync) and trigger_id and not State.net_triggers[trigger_id] then
			return
		end
		net_nav = self:GetStateContext("navigation_vector")
		self.so_net_nav_sent_time = GameTime()
		trigger_target_pos = IsPoint(self.so_trigger_target_pos) and self.so_trigger_target_pos
		if self:IsKindOf("Hero") then
			channeling_stopped = self:IsChannelingStopped()
			split_time = self.split_time
			if self.torso_control then
				torso_angle = self.torso_obj:GetAngle()
			end
		end
	elseif IsKindOf(self, "Monster") then
		if not (trigger and trigger.net_sync) then
			if not self.so_action or not self.so_action:IsMonsterNetSyncAction(self) or not NetIsLocal(self.monster_target) then
				return
			end
		end
	else
		return
	end
	self.so_net_sync_stateidx = self.so_changestateidx
	self.so_net_pos = self:IsValidPos() and self:GetVisualPos()
	self.so_net_pos_time = GameTime()
	--printf("Net sync state: %s, %s, pos=%s", self.class, (self.so_state and self.so_state.name or "false"), tostring(self.so_net_pos))
	local step_time = self:TimeToPosInterpolationEnd()
	if step_time == 0 then step_time = nil end
	local step = step_time and self:GetPos() - self:GetVisualPos()
	local angle, attack_angle = self:GetAngle(), self:GetAttackAngle()
	local target = self.so_target and (IsPoint(self.so_target) and self.so_target or NetValidate(self.so_target)) or false
	local state_handle = self.so_state and StateHandles[self.so_state.name]

	NetEventOwner("ChangeState",
		self, state_handle, target, trigger_target_pos,
		self.so_net_pos or nil, step, step_time, angle, attack_angle,
		net_nav, channeling_stopped, split_time, torso_angle
	)
end

---
--- Raises a trigger on the target object of the current StateObject.
---
--- @param trigger_id string The ID of the trigger to raise on the target object.
--- @return boolean Whether the trigger was successfully processed by the target object.
---
function StateObject:RaiseTargetTrigger(trigger_id)
	if trigger_id and trigger_id ~= "" then
		local target = self.so_target
		if IsValid(target) and target:IsKindOf("StateObject") then
			local trigger_processed = target:RaiseTrigger(trigger_id, self)
			if trigger_processed then
				return true
			end
		end
	end
	--printf("Target trigger failed: %s / %s -> %s -> %s / %s / %s", self.class, self.so_state.name, trigger_id, target and target.class or "no target", target and target.so_state and target.so_state.name or "no state", not target and "" or tostring(target.so_active_zone))
end

local cached_empty_table
---
--- Raises a trigger on the current StateObject.
---
--- @param trigger_id string The ID of the trigger to raise.
--- @param trigger_object any The object that triggered the event.
--- @param trigger_action string The action that triggered the event.
--- @param trigger_target any The target of the trigger.
--- @param trigger_target_pos table The position of the trigger target.
--- @param time_passed number The time passed since the trigger was raised.
--- @param level number The recursion level of the trigger (default is 0).
--- @return boolean Whether the trigger was successfully processed.
---
function StateObject:RaiseTrigger(trigger_id, trigger_object, trigger_action, trigger_target, trigger_target_pos, time_passed, level)
	level = level or 0
	assert(level < 128)
	if level >= 130 then
		return
	end
	local state = self.so_state
	if not state or not self.so_enabled then
		return -- state machine disabled
	end
	if not trigger_id or trigger_id == "" then
		return
	end
	time_passed = time_passed or 0
	if self.so_debug_triggers then
		if trigger_id == "AITick" or trigger_id == "Tick" or trigger_id == "Start" or trigger_id == "Action" or trigger_id == "Hit" or trigger_id == "End" or trigger_id == "PostAction" then
			self:Trace("[StateObject2]<color 128 128 255>RaiseTrigger {1} current state {2} trigger object {3}</color>", trigger_id, state, trigger_object, trigger_action, trigger_target, trigger_target_pos)
		else
			self:Trace("[StateObject1]<color 128 128 255>RaiseTrigger {1} current state {2} trigger object {3}</color>", trigger_id, state, trigger_object, trigger_action, trigger_target, trigger_target_pos)
		end
	end

	-- combo buffer could be kept, and various combo length combinations finishing with trigger_id could be tested
	local matched_triggers = cached_empty_table or {}
	cached_empty_table = nil
	local trigger = state:ResolveTrigger(self, trigger_id, trigger_object, trigger_action, trigger_target, trigger_target_pos, time_passed, false, matched_triggers)
	if #matched_triggers == 0 then
		cached_empty_table = matched_triggers
	end
	local state_id = trigger and trigger.state
	if trigger_id == "Start" and state.name == state_id then
		return
	end
	local consumed = false
	local buffer_trigger  = State.buffered_triggers[trigger_id]
	if buffer_trigger then
		self.so_buffered_trigger = false
	end

	-- run functions of matched triggers (including "copy_triggers")
	for i = 1, #matched_triggers do
		local trig = matched_triggers[i]
		if trig.cooldown_to_set ~= "" then
			consumed = true
			self:SetCooldown(trig.cooldown_to_set)
		end
		if trig.next_state ~= "" then
			consumed = true
			self.so_next_state_id = trig.next_state
		end
		if trig.func ~= "" then
			if trig.state ~= "continue" then
				consumed = true
			end
			local f = TriggerFunctions[trig.func]
			if f then
				local stateidx = self.so_changestateidx
				local ret = f(trig, self, trigger_id, trigger_object, trigger_action, trigger_target, trigger_target_pos, time_passed)
				if stateidx ~= self.so_changestateidx then
					self:NetSyncState(trigger_id, trig)
					return true -- the function could decide to change state
				elseif ret and ret == "break" then
					return true --the function asked us to terminate this trigger chain
				end
			else
				print("Unknown trigger function " .. trig.func)
			end
		end
		if trig.raise_trigger ~= "" then
			local stateidx = self.so_changestateidx
			self:RaiseTrigger(trig.raise_trigger, trigger_object, trigger_action, trigger_target, trigger_target_pos, time_passed, level + 1)
			if stateidx ~= self.so_changestateidx then
				return true
			end
		end
	end

	if state_id and state_id ~= "" and state_id ~= "break" and state_id ~= "continue" and (state_id ~= state.name or self.so_active_zone ~= "Start" or self.so_target ~= self:FindStateTarget(self.so_state, trigger_object, trigger_action, trigger_target, trigger_target_pos)) then
		if state_id ~= "consume_trigger" then
			self:ChangeState(state_id, true, trigger_object, trigger_action, trigger_target, trigger_target_pos)
			local inherit_trigger_id = trigger and trigger.trigger
			if inherit_trigger_id ~= trigger_id then
				-- recast the original trigger to allow base trigger processing and dispath
				-- the object should be in Start zone to check for dispatch
				if self.so_debug_triggers then
					self:Trace("[StateObject2]Inherited trigger " .. inherit_trigger_id)
				end
				local old_zones = self.so_active_zone
				self.so_active_zone = "Start"
				local trigger_processed = self:RaiseTrigger(trigger_id, trigger_object, trigger_action, trigger_target, trigger_target_pos, time_passed, level+1)
				if not trigger_processed then
					self.so_active_zone = old_zones
				end
			end
			self:NetSyncState(trigger_id, trigger)
		end
		return true
	end
	if consumed then
		return true
	end
	if buffer_trigger then
		self:BufferTrigger(trigger_id, trigger_object, trigger_action, trigger_target, trigger_target_pos)
	end
end

---
--- Applies a matched trigger to the StateObject.
---
--- @param handle string The handle of the trigger to apply.
--- @param trigger_id string The ID of the trigger.
--- @param trigger_object any The object that triggered the trigger.
--- @param trigger_action string The action that triggered the trigger.
--- @param trigger_target any The target of the trigger.
--- @param trigger_target_pos table The position of the trigger target.
--- @param time_passed number The amount of time that has passed since the trigger was triggered.
---
function StateObject:ApplyMatchedTrigger(handle, trigger_id, trigger_object, trigger_action, trigger_target, trigger_target_pos, time_passed)
	if not TriggerHandles then
		assert(false, "Trigger handles not defined!")
		return
	end
	local trig = TriggerHandles[handle]
	if not trig then
		assert(false, "Error resolving trigger from handle")
		return
	end
	local function_id = trig.func
	local cooldown_to_set = trig.cooldown_to_set
	if cooldown_to_set ~= "" then
		self:SetCooldown(cooldown_to_set)
	end
	if function_id and function_id ~= "" then
		local f = TriggerFunctions[function_id]
		if f then
			f(trig, self, trigger_id, trigger_object, trigger_action, trigger_target, trigger_target_pos, time_passed)
		else
			print("Unknown trigger function " .. function_id)
		end
	end
	if trig.next_state ~= "" then
		self.so_next_state_id = trig.next_state
	end
end

---
--- Checks if the current state change is allowed.
---
--- @return boolean true if the state change is allowed, false otherwise
---
function StateObject:IsStateChangeAllowed()
	return true
end

---
--- Buffers a trigger for later execution.
---
--- @param trigger_id string The ID of the trigger to buffer.
--- @param trigger_object any The object that triggered the trigger.
--- @param trigger_action string The action that triggered the trigger.
--- @param trigger_target any The target of the trigger.
--- @param trigger_target_pos table The position of the trigger target.
---
function StateObject:BufferTrigger(trigger_id, trigger_object, trigger_action, trigger_target, trigger_target_pos)
	self.so_buffered_trigger = trigger_id
	self.so_buffered_trigger_object = trigger_object
	self.so_buffered_trigger_action = trigger_action
	self.so_buffered_trigger_target = trigger_target
	self.so_buffered_trigger_target_pos = trigger_target_pos
	self.so_buffered_trigger_time = GameTime()
	self.so_buffered_times = self.so_buffered_times or {}
	self.so_buffered_times[trigger_id] = self.so_buffered_trigger_time
end

---
--- Executes any buffered triggers for this StateObject.
---
--- Buffered triggers are stored when a trigger is raised but not immediately processed, usually due to a cooldown or other delay. This function checks if any buffered triggers are ready to be executed, and processes them if so.
---
--- @return nil
function StateObject:ExecBufferedTriggers()
	local trigger_id = self.so_buffered_trigger
	if not trigger_id then
		return
	end
	self.so_buffered_trigger = false
	local trigger_time = self.so_buffered_trigger_time
	local time_passed = GameTime() - trigger_time
	if time_passed > State.triggers_buffered_time then
		return -- expired
	end
	if self:RaiseTrigger(trigger_id, self.so_buffered_trigger_object, self.so_buffered_trigger_action, self.so_buffered_trigger_target, self.so_buffered_trigger_target_pos, time_passed) then
		-- trigger consumed
	else
		-- restore the buffered trigger when not processed
		self.so_buffered_trigger_time = trigger_time
	end
end

---
--- Checks if a trigger has been resolved.
---
--- This function checks if a trigger has been resolved, meaning that the trigger has been processed and any associated actions have been executed. It does this by resolving the trigger using the current state's `ResolveTrigger` function, and checking if the trigger has a valid state or function associated with it.
---
--- @param trigger_id string The ID of the trigger to check.
--- @param trigger_object any The object that triggered the trigger.
--- @param trigger_action string The action that triggered the trigger.
--- @param trigger_target any The target of the trigger.
--- @param trigger_target_pos table The position of the trigger target.
--- @return boolean true if the trigger has been resolved, false otherwise.
---
function StateObject:IsTriggerResolved(trigger_id, trigger_object, trigger_action, trigger_target, trigger_target_pos)
	local state = self.so_state
	local trigger = state and state:ResolveTrigger(self, trigger_id, trigger_object, trigger_action, trigger_target, trigger_target_pos)
	if trigger then
		local state_id, function_id = trigger.state, trigger.func
		if function_id and function_id ~= "" or state_id and state_id ~= "" and state_id ~= "break" and state_id ~= "continue" then
			return true
		end
	end
	return false
end

---
--- Finds the target for the current state.
---
--- This function is used to determine the target for the current state. It looks up the target group specified in the state's properties, and calls the corresponding StateTargets function to get the target.
---
--- @param state table The current state.
--- @param trigger_object any The object that triggered the current state.
--- @param trigger_action string The action that triggered the current state.
--- @param trigger_target any The target of the current state.
--- @param trigger_target_pos table The position of the trigger target.
--- @param debug_level number The debug level for the current state.
--- @return any The target for the current state, or false if no target was found.
---
function StateObject:FindStateTarget(state, trigger_object, trigger_action, trigger_target, trigger_target_pos, debug_level)
	local target
	local target_group = state:GetInheritProperty(self, "target")
	if target_group ~= "" then
		target = StateTargets[target_group](self, state, trigger_object, trigger_action, trigger_target, trigger_target_pos, debug_level)
	end
	return target or false
end

---
--- Sets the state target for the StateObject.
---
--- This function sets the target for the current state of the StateObject. If the debug_triggers flag is set, it will log a message with the target and current state.
---
--- @param target any The target to set for the current state.
---
function StateObject:SetStateTarget(target)
	if self.so_debug_triggers then
		self:Trace("[StateObject1]<color 0 255 0>Target {1} for state {2}</color>", target, self.so_state)
	end
	self.so_target = target
end

---
--- Changes the target for the current state of the StateObject.
---
--- If the current target is the same as the new target, this function does nothing.
--- If the current target is not a point, it calls the `StateActionMoment("target_lost")` function.
--- It then sets the new target using the `SetStateTarget()` function.
--- If the new target is not a point, it calls the `StateActionMoment("new_target")` function.
---
--- @param target any The new target to set for the current state.
---
function StateObject:ChangeStateTarget(target)
	if self.so_target == (target or false) then
		return
	end
	if self.so_target and not IsPoint(self.so_target) then
		self:StateActionMoment("target_lost")
	end
	self:SetStateTarget(target)
	if self.so_target and not IsPoint(self.so_target) then
		self:StateActionMoment("new_target")
	end
end

---
--- Advances the state of the StateObject to the next state.
---
--- If the next state ID is the same as the current state and the elapsed time since the current state started is 0, a warning message is printed and the execution is paused for 1 second.
---
--- If the elapsed time since the current state started is 0 or the `so_context_sync` flag is not set, the state is changed immediately using `InternalChangeState()`.
---
--- If the elapsed time since the current state started is not 0, the state is changed using `ChangeState()`.
---
--- @param self StateObject The StateObject instance.
---
function StateObject:NextState()
	local next_state_id = self.so_next_state_id or self.so_state:GetInheritProperty(self, "next_state")
	local elapsed_time = GameTime() - self.so_state_time_start
	if elapsed_time == 0 or not self.so_context_sync then
		if next_state_id == self.so_state.name and elapsed_time == 0 then
			printf('%s hangs in state "%s"', self.class, next_state_id)
			Sleep(1000)
		end
		self:InternalChangeState(next_state_id, true)
	else
		self:ChangeState(next_state_id)
	end
end

---
--- Sets the movement system for the StateObject and optionally advances to the next state when the movement is finished.
---
--- If the current thread is not the movement thread, the previous movement thread is deleted.
--- If a movement system is provided, it is either a function or a string that references a movement system in the `StateMoveSystems` table.
--- If no movement system is provided, the movement thread is set to `nil` and the next state is advanced if `next_state_on_finish` is `true`.
--- Otherwise, a new game time thread is created that runs the movement system and advances to the next state if `next_state_on_finish` is `true`.
---
--- @param movement function|string The movement system to use, or `nil` to clear the movement.
--- @param next_state_on_finish boolean If `true`, the next state is advanced when the movement is finished.
---
function StateObject:SetMoveSys(movement, next_state_on_finish)
	if CurrentThread() ~= self.so_movement_thread then
		DeleteThread(self.so_movement_thread)
	end
	local move_sys = movement and (type(movement) == "function" and movement or StateMoveSystems[movement])
	if not move_sys then
		self.so_movement_thread = nil
		if next_state_on_finish then
			self:NextState()
		end
		return
	end
	local stateidx = self.so_changestateidx
	self.so_movement_thread = CreateGameTimeThread(function(self, stateidx, next_state_on_finish, move_sys)
		if stateidx == self.so_changestateidx then
			move_sys(self)
		end
		if next_state_on_finish and stateidx == self.so_changestateidx then
			self:NextState()
		end
	end, self, stateidx, next_state_on_finish, move_sys)
	ThreadsSetThreadSource(self.so_movement_thread, "Movement system")
end

---
--- Modifies the state context value for the given ID.
---
--- If the state context for the given ID does not exist, it is initialized to 0 before the modification.
---
--- @param id string The ID of the state context to modify.
--- @param value number The value to add to the existing state context value.
---
function StateObject:ModifyStateContext(id, value)
	self:SetStateContext(id, (self:GetStateContext(id) or 0) + value)
end

---
--- Sets the value of the specified state context for this StateObject.
---
--- If the state context for the given ID does not exist, it is initialized to 0 before the value is set.
---
--- @param id string The ID of the state context to set.
--- @param value number The new value to set for the state context.
--- @return number|nil The previous value of the state context, or nil if it did not exist.
---
function StateObject:SetStateContext(id, value)
	local so_context = self.so_context
	local old_value
	if not so_context then
		so_context = {}
		self.so_context = so_context
	else
		old_value = so_context[id]
	end
	so_context[id] = value
	return old_value
end

---
--- Gets the value of the specified state context for this StateObject.
---
--- If the state context for the given ID does not exist, this function will return `nil`.
---
--- @param id string The ID of the state context to get.
--- @return number|nil The value of the state context, or `nil` if it does not exist.
---
function StateObject:GetStateContext(id)
	local so_context = self.so_context
	if so_context then
		return so_context[id]
	end
end

---
--- Checks if the StateObject has an active cooldown with the given cooldown ID.
---
--- @param cooldown_id string The ID of the cooldown to check.
--- @return boolean True if the StateObject has an active cooldown with the given ID, false otherwise.
---
function StateObject:HasCooldown(cooldown_id)
	if (cooldown_id or "") == "" then
		return false
	end
	if self.so_cooldown == cooldown_id then
		return true
	end
	return CooldownObj.HasCooldown(self, cooldown_id)
end

---
--- Gets the StateAction associated with the specified state ID.
---
--- If no state ID is provided, the current state's action is returned.
---
--- @param state_id string|nil The ID of the state to get the action for. If nil, the current state's action is returned.
--- @return table|nil The StateAction associated with the specified state, or nil if no action is defined.
---
function StateObject:GetStateAction(state_id)
	local state
	if state_id then
		state = self.so_states[state_id]
	else
		state = self.so_state
	end
	local classname = state and state:GetInheritProperty(self, "action")
	return classname and classname ~= "" and g_Classes[classname]
end

---
--- Handles the different moments of a StateAction, such as the start, action, hit, post-action, and end.
---
--- This function is responsible for triggering the appropriate events and updating the state of the StateObject based on the current moment.
---
--- @param moment string The moment to handle, can be "start", "action", "hit", "post-action", or "end".
--- @param ... any Additional arguments to pass to the StateAction's Moment function.
---
function StateObject:StateActionMoment(moment, ...)
	local stateidx = self.so_changestateidx
	local trigger, buffered_triggers, ai_tick
	if moment == "start" then
		-- the triggers are raised earlier on state change
		self.so_action_start_passed = true
	elseif moment == "action" then
		self.so_active_zone = "Action"
		trigger = "Action"
		ai_tick = true
	elseif moment == "hit" then
		self.so_active_zone = "Action"
		self.so_action_hit_passed = true
		trigger = "Hit"
	elseif moment == "post-action" then
		if not self.so_action_hit_passed then
			self:StateActionMoment("hit")
		end
		self.so_active_zone = "PostAction"
		trigger = "PostAction"
		buffered_triggers = true
		ai_tick = true
	elseif moment == "end" then
		if not self.so_action_hit_passed then
			self:StateActionMoment("interrupted")
		end
		if self.so_target then
			self:StateActionMoment("target_lost")
		end
		trigger = "End"
	end
	local action = self.so_action
	if action then
		action:Moment(moment, self, ...)
		if stateidx ~= self.so_changestateidx then return end
	end
	if buffered_triggers then
		self:ExecBufferedTriggers()
		if stateidx ~= self.so_changestateidx then return end
	end
	if trigger then
		self:RaiseTrigger(trigger)
		if stateidx ~= self.so_changestateidx then return end
	end
	if ai_tick then
		self:RaiseTrigger("AITick")
		if stateidx ~= self.so_changestateidx then return end
	end
	if moment == "start" then
		if IsValid(self.so_target) then
			self:StateActionMoment("new_target")
			if stateidx ~= self.so_changestateidx then return end
		end
		self.so_active_zone = "PreAction"
	end
end

---
--- Gets the animation phase for a specific moment in the state object's animation.
---
--- @param id string The identifier for the animation moment to get the phase for. Can be "Hit", "Start", "End", "LastPhase", "Random", or a number.
--- @param anim string (optional) The name of the animation to use. If not provided, the animation from the current state will be used.
--- @param state StateObject (optional) The state object to use. If not provided, the current state object will be used.
--- @return number The phase of the animation moment.
function StateObject:GetStateAnimPhase(id, anim, state)
	if id == "" then return 0 end
	state = state == nil and self.so_state or state
	anim = anim or state and state:GetAnimation(self)
	anim = anim ~= "" and anim or self:GetStateText()
	local phase
	if id == "Hit" then
		if state and state:GetInheritProperty(self, "override_moments") == "yes" then
			local prop = state:GetInheritProperty(self, "animation_hit")
			phase = tonumber(prop)
		end
		if not phase or phase < 0 then
			phase = self:GetAnimMoment(anim, id) or 0
		end
	elseif id == "Start" then
		if state and state:GetInheritProperty(self, "override_moments") == "yes" then
			local prop = state:GetInheritProperty(self, "animation_start")
			phase = tonumber(prop)
		end
		if not phase or phase < 0 then
			phase = self:GetAnimMoment(anim, id) or 0
		end
	elseif id == "End" then
		if state and state:GetInheritProperty(self, "override_moments") == "yes" then
			local prop = state:GetInheritProperty(self, "animation_end")
			phase = tonumber(prop)
		end
		if not phase or phase < 0 then
			phase = self:GetAnimMoment(anim, id) or GetAnimDuration(self:GetEntity(), anim) - 1
		end
	elseif id == "LastPhase" then
		phase = GetAnimDuration(self:GetEntity(), anim) - 1
	elseif id == "Random" then
		phase = self:StateRandom(GetAnimDuration(self:GetEntity(), anim))
	elseif type(id) == "number" then
		phase = id
	elseif id == "TargetHit" then
		if IsValid(self.so_target) then
			phase = self.so_target:GetStateAnimPhase("Hit")
		end
	else
		phase = self:GetAnimMoment(anim, id)
	end
	return phase or 0
end

--- Returns the time until the start animation moment of the current state.
---
--- @return number The time until the start animation moment.
function StateObject:TimeToStartMoment()
	local phase = self:GetStateAnimPhase("Start")
	local time = self:TimeToPhase(1, phase)
	return time
end

--- Returns the time until the end animation moment of the current state.
---
--- @return number The time until the end animation moment.
function StateObject:TimeToEndMoment()
	local phase = self:GetStateAnimPhase("End")
	local time = self:TimeToPhase(1, phase)
	return time
end

--- Returns the time until the "Hit" animation moment of the current state.
---
--- @return number The time until the "Hit" animation moment.
function StateObject:TimeToHitMoment()
	local phase = self:GetStateAnimPhase("Hit")
	local time = self:TimeToPhase(1, phase)
	return time
end

--- Waits until the end animation moment of the current state is reached.
---
--- @return boolean True if the end animation moment was reached, false otherwise.
function StateObject:WaitEndMoment()
	local phase = self:GetStateAnimPhase("End")
	local result = self:WaitPhase(phase)
	return result
end

--- Waits until the "Hit" animation moment of the current state is reached.
---
--- @return boolean True if the "Hit" animation moment was reached, false otherwise.
function StateObject:WaitHitMoment()
	local phase = self:GetStateAnimPhase("Hit")
	local result = self:WaitPhase(phase)
	return result
end

--- Waits until the current state of the StateObject has changed.
---
--- This function will block until a message is received indicating that the
--- current state of the StateObject has changed. This can be used to wait for
--- the state to transition to a new state.
---
--- @return nil
function StateObject:WaitStateChanged()
	WaitMsg(self)
end

--- Waits until the current state of the StateObject has exited the specified state.
---
--- This function will block until a message is received indicating that the
--- current state of the StateObject has changed from the specified state.
---
--- @param state string The name of the state to wait for exiting.
--- @return nil
function StateObject:WaitStateExit(state)
	while self.so_state and self.so_state.name == state do
		WaitMsg(self)
	end
end

--- Toggles the display of a debug text overlay for the current state of the StateObject.
---
--- If `show` is true, a new Text object is created and attached to the StateObject
--- to display the name of the current state. If `show` is false, the debug Text
--- object is deleted.
---
--- @param show boolean Whether to show or hide the debug text overlay.
--- @return nil
function StateObject:StateDebug(show)
	if self.so_state_debug and not show then
		self.so_state_debug:delete()
		self.so_state_debug = false
	elseif not self.so_state_debug and show then
		self.so_state_debug = Text:new()
		self:Attach(self.so_state_debug)
		self.so_state_debug:SetText(self.so_state.name)
	end
end

--- Generates a random number within the specified range, using a seed value.
---
--- The seed value is derived from the current state of the StateObject, or a
--- provided seed value. The seed is hashed using xxhash to ensure a unique
--- sequence of random numbers.
---
--- @param range number The range of the random number to generate.
--- @param seed number (optional) A seed value to use for the random number generation.
--- @return number A random number within the specified range.
function StateObject:StateRandom(range, seed)
	seed = seed or self.so_state and self.so_state.seed or 0
	seed = xxhash(seed, MapLoadRandom, self.handle)
	return (BraidRandom(seed, range))
end

--- Schedules a repeating task to be executed at the specified interval.
---
--- This function creates a new game time thread that will execute the provided
--- function at the specified interval. The function will continue to be executed
--- until the StateObject is destroyed or the state is changed.
---
--- @param interval number The interval in seconds at which to execute the function.
--- @param func function The function to execute.
--- @param ... any Arguments to pass to the function.
--- @return nil
function StateObject:StateRepeat(interval, func, ...)
	self.so_repeat = self.so_repeat or {}
	table.insert(self.so_repeat, { GameTime(), interval, func, ...})
	if IsValidThread(self.so_repeat_thread) then
		Wakeup(self.so_repeat_thread)
		return
	end
	self.so_repeat_thread = CreateGameTimeThread(function(self)
		while self.so_repeat_thread == CurrentThread() do
			local next_update
			local game_time = GameTime()
			local list = self.so_repeat
			local i = 1
			while i <= #list do
				local rep = list[i]
				local dt = rep[1] - game_time
				if dt == 0 then
					dt = rep[3](self.so_action, self, unpack_params(rep, 4))
					if self.so_repeat_thread ~= CurrentThread() then
						return -- the state is finished
					end
					if dt == nil then dt = rep[2] end
					if dt and dt >= 0 then
						rep[1] = game_time + dt
					else
						dt = false
						table.remove(list, i)
						i = i - 1
					end
				end
				if dt and (not next_update or next_update > dt) then
					next_update = dt
				end
				i = i + 1
			end
			if not next_update then
				return
			end
			WaitWakeup(next_update)
		end
	end, self)
end

-- MULTIPLAYER SYNCHRONIZATION:
---
--- Retrieves the dynamic data associated with the StateObject.
---
--- @param data table A table to store the dynamic data.
--- @return nil
function StateObject:GetDynamicData(data)
	local state_id = self.so_state and StateHandles[self.so_state.name]
	if state_id then
		data.state_id = state_id
		data.target = self.so_target and (IsPoint(self.so_target) and self.so_target or NetValidate(self.so_target)) or nil
		if self.so_context and next(self.so_context) ~= nil then
			data.context = self.so_context
		end
		data.so_next_state_id = self.so_next_state_id and StateHandles[self.so_next_state_id] or nil
		data.trigger_target_pos = self.so_trigger_target_pos or nil
	end
end

---
--- Sets the dynamic data associated with the StateObject.
---
--- @param data table A table containing the dynamic data to set.
--- @return nil
function StateObject:SetDynamicData(data)
	local state_id = data.state_id and StateHandles[data.state_id]
	if state_id then
		self:InternalChangeState(state_id, false,
			false,
			false,
			false,
			data.trigger_target_pos or false,
			data.target or false)
		self.so_next_state_id = data.so_next_state_id and StateHandles[data.so_next_state_id]
	end
end
