----- ParamResolver

ParamResolver = {}
--- Resolves a simple parameter.
---
--- This function simply returns the provided parameters as-is, without any additional processing.
---
--- @param ... any The parameters to resolve.
--- @return any The resolved parameters.
function ParamResolver.Simple(...)
	return ...
end

--- Resolves a quest and its state parameter.
---
--- This function retrieves the current state of the specified quest, and returns the quest object and the value of the specified parameter within the quest state.
---
--- @param quest_id number The ID of the quest to retrieve.
--- @param param_id string The ID of the parameter within the quest state to retrieve.
--- @return table, any The quest object and the value of the specified parameter.
function ParamResolver.QuestAndState(quest_id, param_id)
	local quest = QuestGetState(quest_id)
	return quest, quest and quest[param_id]
end

--- Resolves an object and its context.
---
--- This function retrieves the object associated with the provided handle, and returns the object and the provided context.
---
--- @param handle any The handle of the object to retrieve.
--- @param context any The context to return along with the object.
--- @return table, any The object and the provided context.
function ParamResolver.ObjAndContext(handle, context)
	assert(HandleToObject[handle])
	return HandleToObject[handle], context
end

--- Resolves a custom interactable object and its associated units.
---
--- This function retrieves the first unit object from the provided list of unit handles, and returns it along with a table containing the list of units and the interactable object.
---
--- @param unit_handles table The list of unit handles to resolve.
--- @param interactable any The handle of the interactable object to retrieve.
--- @return table, table The first unit object and a table containing the list of units and the interactable object.
function ParamResolver.CustomInteractable(unit_handles, interactable)
	local units = {}
	for i, handle in ipairs(unit_handles) do
		units[i] = HandleToObject[handle]
	end
	return units[1], { target_units = units, interactable = HandleToObject[interactable] }
end

--- Resolves parameters using the specified resolver function.
---
--- This function looks up the specified resolver function in the `ParamResolver` table and calls it with the provided parameters.
---
--- @param func_name string The name of the resolver function to use.
--- @param ... any The parameters to pass to the resolver function.
--- @return any The resolved parameters.
function ResolveParams(func_name, ...)
	if not func_name then return end
	assert(ParamResolver[func_name])
	return ParamResolver[func_name](...)
end


----- Resume Execution functions

ResumeFuncs = {}
---
--- Resumes the execution of a sequence of effects.
---
--- This function is responsible for executing a sequence of effects, handling the resumption of execution when an effect yields. It iterates through the list of effects, executing each one and handling the result. If the result is "break", the function exits the loop and returns.
---
--- @param stack table The stack of execution state.
--- @param params table The parameters to pass to the effects.
--- @param effects table The list of effects to execute.
--- @param ... any The arguments to pass to the ResumeFuncs functions.
--- @return any The result of the last executed effect.
---
function ResumeFuncs.Effects(stack, params, effects, ...)
	local result = ResumeExecution(stack, params, ...)
	
	local stack_index = #stack + 1
	if result ~= "break" then
		for i, effect in ipairs(effects) do
			stack[stack_index] = i
			local _, result = effect:ExecuteWait(stack, unpack_params(params))
			assert(stack_index == #stack)
			if result == "break" then
				break
			end
		end
	end
	stack[stack_index] = nil
end

---
--- Pauses the execution of the current sequence of effects for the specified time.
---
--- @param stack table The stack of execution state.
--- @param params table The parameters to pass to the effect.
--- @param time number The time in seconds to pause the execution.
---
function ResumeFuncs.Sleep(stack, params, time)
	Sleep(time)
end

---
--- Pauses the execution of the current sequence of effects for the specified time.
---
--- @param stack table The stack of execution state.
--- @param params table The parameters to pass to the effect.
--- @param timer number The timer to wait for.
--- @return any The result of the timer wait.
---
function ResumeFuncs.TimerWait(stack, params, timer)
	return TimerWait(timer)
end

---
--- Starts the deployment process in the current sector.
---
--- If an entrance_zone is provided, it sets the deployment mode to that zone. Then it starts the deployment process and waits for the "DeploymentModeSet" message.
---
--- @param stack table The stack of execution state.
--- @param params table The parameters to pass to the effect.
--- @param entrance_zone string The entrance zone to set the deployment mode to.
---
function ResumeFuncs.StartDeploymentInCurrentSector(stack, params, entrance_zone)
	if entrance_zone then
		SetDeploymentMode(entrance_zone)
	end
	StartDeployment()
	WaitMsg("DeploymentModeSet")
end

---
--- Shows a popup with the specified ID and sends a "ClosePopup" message with the popup ID.
---
--- @param stacks table The stack of execution state.
--- @param params table The parameters to pass to the effect.
--- @param popup_id string The ID of the popup to show.
---
function ResumeFuncs.ShowPopup(stacks, params, popup_id)
	ShowPopup(popup_id)
	Msg("ClosePopup" .. popup_id)
end

---
--- Starts a conversation effect with the specified conversation.
---
--- @param stacks table The stack of execution state.
--- @param params table The parameters to pass to the effect.
--- @param conversation string The conversation to start.
---
function ResumeFuncs.UnitStartConversation(stacks, params, conversation)
	StartConversationEffect(conversation, nil, "wait")
end

---
--- Starts a conversation effect with the specified conversation and radio icon.
---
--- @param stacks table The stack of execution state.
--- @param params table The parameters to pass to the effect.
--- @param conversation string The conversation to start.
--- @param icon string The radio icon to display.
---
function ResumeFuncs.RadioStartConversation(stacks, params, conversation, icon)
	StartConversationEffect(conversation, { radio = true, icon = icon }, "wait")
end

---
--- Resumes the execution of a function from the ResumeFuncs table.
---
--- @param stack table The stack of execution state.
--- @param params table The parameters to pass to the function.
--- @param func_name string The name of the function to execute from the ResumeFuncs table.
--- @param ... any Additional arguments to pass to the function.
---
--- @return any The return value of the executed function.
---
function ResumeExecution(stack, params, func_name, ...)
	if not func_name then return end
	assert(ResumeFuncs[func_name])
	return ResumeFuncs[func_name](stack, params, ...)
end

---
--- Executes a wait effect, passing the stack and unpacked parameters to the effect.
---
--- @param stack table The stack of execution state.
--- @param params table The parameters to pass to the effect.
--- @param obj Effect The effect to execute.
---
function ResumeFuncs.ExecuteWait(stack, params, obj)
	obj:ExecuteWait(stack, unpack_params(params))
end

---
--- Resumes the execution of a WaitNpcIdle effect from a saved state.
---
--- @param stack table The stack of execution state.
--- @param context table The context to execute the effect in.
--- @param resumeData any The saved state data for the WaitNpcIdle effect.
---
function ResumeFuncs.WaitNpcIdle(stack, context, resumeData)
	local newEffect = WaitNpcIdle:new()
	newEffect.TargetUnit = resumeData
	newEffect:__waitexec(context)
end

----- Sequential Effects

---
--- Throws an assertion error indicating that the `Effect` class cannot be saved.
---
--- This function is an implementation detail of the `Effect` class and is not intended to be called directly.
---
function Effect:GetResumeData()
	assert(false, self.class .. " cannot be saved") 
end

---
--- Executes the wait effect for the given object and context.
---
--- @param self Effect The effect instance.
--- @param obj any The object to execute the effect on.
--- @param context any The context to execute the effect in.
--- @param ... any Additional arguments to pass to the effect.
---
--- @return any The return value of the effect execution.
---
function Effect.__waitexec(self, obj, context, ...)
	return self.__exec(self, obj, context, ...)
end

local sprocall = sprocall
---
--- Executes the wait effect for the given object and context.
---
--- @param self Effect The effect instance.
--- @param stack table The stack of execution state.
--- @param ... any Additional arguments to pass to the effect.
---
--- @return any The return value of the effect execution.
---
function Effect:ExecuteWait(stack, ...)
	return sprocall(self.__waitexec, self, ...)
end

local function copy_array(array, skip, first_element)
	if not array then return false end
	local copy = { first_element or nil }
	skip = skip or 0
	local delta = skip - #copy
	for i = skip + 1, #array do
		copy[i - delta] = array[i]
	end
	return copy
end

local function lCopyTableWithoutObjects(t)
	if type(t) ~= "table" or t.class then return t end

	local copy = {}
	for k, v in pairs(t) do
		if type(v) == "table" then
			if v.class then
				copy[k] = v
			else
				copy[k] = table.copy(v)
			end
		else
			copy[k] = v
		end
	end
	return copy
end

---
--- Executes the effects of this EffectsWithCondition instance based on the evaluation of the conditions.
---
--- @param obj any The object to execute the effects on.
--- @param ... any Additional arguments to pass to the effects.
---
--- @return boolean True if the effects were executed, false otherwise.
---
function EffectsWithCondition:__exec(obj, ...)
	if _EvalConditionList(self.Conditions, obj, ...) then
		for _, effect in ipairs(self.Effects) do
			effect:__exec(obj, ...)
		end
		return true
	else
		if count_params(...) == 0 then
			for _, effect in ipairs(self.EffectsElse) do
				effect:__exec(obj)
			end
		else
			_ExecuteEffectList(self.EffectsElse, obj, table.unpack(lCopyTableWithoutObjects{...}))
		end
	end
end

---
--- Executes the effects of this EffectsWithCondition instance based on the evaluation of the conditions.
---
--- @param stack table The stack of effects to execute.
--- @param obj any The object to execute the effects on.
--- @param ... any Additional arguments to pass to the effects.
---
--- @return nil
---
function EffectsWithCondition:ExecuteWait(stack, obj, ...)
	local paramsCaseTrue = {...}
	local paramsCaseFalse = lCopyTableWithoutObjects(paramsCaseTrue)
	
	local eval = EvalConditionList(self.Conditions, obj, table.unpack(paramsCaseTrue))
	local effects = eval and self.Effects or not eval and self.EffectsElse
	local params = eval and paramsCaseTrue or not eval and paramsCaseFalse
	
	if not effects or #effects == 0 then return end
	local stack_index = #stack + 1
	for i, effect in ipairs(effects) do
		stack[stack_index] = eval and i or -i
		effect:ExecuteWait(stack, obj, table.unpack(params))
		assert(stack_index == #stack)
	end
	stack[stack_index] = nil
end

---
--- Retrieves the resume data for the current effect in the sequential effects execution.
---
--- @param thread table The thread executing the sequential effects.
--- @param stack table The stack of effects being executed.
--- @param stack_index number The index of the current effect in the stack.
---
--- @return string, table The type of the next effect to execute, and the resume data for that effect.
---
function EffectsWithCondition:GetResumeData(thread, stack, stack_index)
	local eval = stack[stack_index] > 0
	local effect_index = abs(stack[stack_index])
	local effects = (eval and self.Effects or not eval and self.EffectsElse)
	return "Effects", copy_array(effects, effect_index, 
		ResumeEffect:new(pack_params(effects[effect_index]:GetResumeData(thread, stack, stack_index + 1))))		
end

DefineClass.ResumeEffect = { -- artificial effect used to resume a running effect
	__parents = { "Effect", },
	StoreAsTable = false,
	EditorExcludeAsNested = true,
}

---
--- Executes the resume data for the current effect in the sequential effects execution.
---
--- @param stack table The stack of effects being executed.
--- @param ... any Additional arguments to pass to the effect.
---
--- @return nil
---
function ResumeEffect:ExecuteWait(stack, ...)
	return sprocall(ResumeExecution, stack, {...}, unpack_params(self))
end

---
--- Retrieves the resume data for the current ResumeEffect.
---
--- @return any The resume data for the ResumeEffect.
---
function ResumeEffect:GetResumeData()
	return unpack_params(self)
end


GameVar("RunningSequentialEffects", {})

---
--- Executes a sequence of effects.
---
--- @param effects table A table of effects to execute sequentially.
--- @param ... any Additional arguments to pass to the effects.
---
--- @return table A table containing the end event for the sequential effects execution.
---
function ExecuteSequentialEffects(effects, ...)
	if not effects or not next(effects) then return end
	ValidateRunningEffectsStates()
	local run_state = { false, effects, {}, ... }
	local end_event = {}
	run_state[1] = CreateGameTimeThread(function(run_state, params)
		RunningSequentialEffects[#RunningSequentialEffects + 1] = run_state
		ResumeExecution(run_state[3], params, "Effects", run_state[2])
		table.remove_entry(RunningSequentialEffects, run_state)
		Msg(end_event)
	end, run_state, pack_params(ResolveParams(...)))
	return end_event
end

---
--- Waits for the sequential effects execution to complete and returns the end event.
---
--- @param effects table A table of effects to execute sequentially.
--- @param ... any Additional arguments to pass to the effects.
---
--- @return table The end event for the sequential effects execution.
---
function WaitExecuteSequentialEffects(effects, ...)
	local end_event = ExecuteSequentialEffects(effects, ...)
	WaitMsg(end_event)
end

---
--- Validates the states of all running sequential effects.
---
--- This function checks the validity of the threads associated with each running
--- sequential effect. If a thread is no longer valid, the corresponding effect
--- is removed from the list of running effects.
---
--- @internal
function ValidateRunningEffectsStates()
	local running_effects = RunningSequentialEffects
	for i = #running_effects, 1, -1 do
		local run_state = running_effects[i]
		if not IsValidThread(run_state[1]) then
			table.remove(running_effects, i)
		end
	end
end

function OnMsg.SaveDynamicData(data)
	ValidateRunningEffectsStates()
	local running_effects
	for _, run_state in ipairs(RunningSequentialEffects) do
		local thread, effects, stack = run_state[1], run_state[2], run_state[3]
		local remaining_effects = copy_array(effects, stack[1], 
			stack[1] and ResumeEffect:new(pack_params(effects[stack[1]]:GetResumeData(thread, stack, 2))))
		running_effects = running_effects or {}
		running_effects[#running_effects + 1] = {
			pack_params(unpack_params(run_state, 4)),
			remaining_effects,
		}
	end
	data.RunningSequentialEffects = running_effects
end

function OnMsg.LoadDynamicData(data)
	CreateGameTimeThread(function(running_effects) -- delay param resolution, so all other objects are created and updated
		for _, resume in ipairs(running_effects) do
			local run_state = { false, resume[2], {}, unpack_params(resume[1]) }
			CreateGameTimeThread(function(run_state, resume, params)
				run_state[1] = CurrentThread()
				RunningSequentialEffects[#RunningSequentialEffects + 1] = run_state
				ResumeExecution(run_state[3], params, "Effects", run_state[2], 
					unpack_params(resume[3])) -- !!! backward compatibility: resume[3] is no longer used, impacts ResumeFuncs.Effects
				table.remove_entry(RunningSequentialEffects, run_state)
			end, run_state, resume, pack_params(ResolveParams(unpack_params(resume[1]))))
		end
	end, data.RunningSequentialEffects)
	ValidateRunningEffectsStates()
end

-- compatibility

DefineClass("ConditionalEffect", "EffectsWithCondition")
ConditionalEffect.StoreAsTable = false
