--- Checks if the Msg definition has any parameters that conflict with the "reaction_actor" or "reaction_def" parameter names.
---
--- This function is used to validate the Msg definition before it is used in the game logic.
---
--- @param self MsgDef The Msg definition object.
--- @return string An error message if a conflicting parameter is found, otherwise an empty string.
function MsgDef:GetError()
	local params = string.split(self.Params, ",")
	for _, param in ipairs(params) do
		param = string.trim_spaces(param)
		if param == "reaction_actor" or param == "reaction_def" then 
			-- reaction_actor is used as a parameter name when processing actors obtained via GetReactionActors; 
			-- Having it as a Msg parameter would cause two parameters with the same name to be present in the function, 
			-- effectively causing the msg parameter overwrite the value
			return string.format("Msgs should not have a parameter named '%s'!", param)
		end
	end
end

-- end MsgDef append

-- ActorReaction
local function ReactionActorsComboItems(self)
	local items = { false }
	local msgdef = MsgDefs[self.Event] or empty_table
	if (msgdef.Params or "") ~= "" then
		local params = string.split(msgdef.Params, ",")
		for _, param in ipairs(params) do
			items[#items + 1] = string.trim_spaces(param)
		end
	end
	
	return items
end

DefineClass.ActorReaction = {
	__parents = { "Reaction" },
	properties = {
		{ id = "FlagsDef", name = "Flags", editor = "string_list", default = {}, item_default = "", 
			base_class = "PresetParam", default = false, help = "Create named parameters for numeric values and use them in multiple places.\n\nFor example, if an event checks that an amount of money is present, subtracts this exact amount, and displays it in its text, you can create an Amount parameter and reference it in all three places. When you later adjust this amount, you can do it from a single place.\n\nThis can prevent omissions and errors when numbers are getting tweaked later.",
		},		
		{ id = "ActorParam", editor = "dropdownlist", items = ReactionActorsComboItems, default = false, 
			no_edit = function(self)
				local msgdef = MsgDefs[self.Event] or empty_table
				return not msgdef
			end,
		},
		{ id = "Handler", editor = "func", default = false, lines = 6, max_lines = 60, no_edit = true,
			name = function(self) return self.Event end,
			params = function (self) return self:GetParams() end, },
		{ id = "HandlerCode", editor = "func", default = false, lines = 6, max_lines = 60,
			name = function(self) return self.Event or "Handler" end,
			params = function (self) return self:GetExecParams() end, },
	},
	Flags = false,
}

---
--- Returns the parameters to be used when executing the reaction handler.
---
--- If the reaction has an associated actor, the parameters will be the same as the reaction's parameters.
--- If the reaction does not have an associated actor, the parameters will include the reaction actor in addition to the reaction's parameters.
---
--- @return string The parameters to be used when executing the reaction handler.
function ActorReaction:GetExecParams()
	local def = MsgDefs[self.Event]
	if not def then return "" end
	local actor = self:GetActor()
	if actor then	
		return self:GetParams()
	end
	-- insert "reaction_actor after self
	local params = def.Params or ""
	if params == "" then
		return self.ReactionTarget == "" and "self, reaction_actor" or "self, reaction_actor, target"
	end
	return (self.ReactionTarget == "" and "self, reaction_actor, " or "self, reaction_actor, target, ") .. params
end

---
--- Generates the handler function for an ActorReaction object.
---
--- The generated handler function is responsible for verifying the reaction and executing the associated handler code.
---
--- If the reaction has an associated actor, the handler function will directly call the handler code.
--- If the reaction does not have an associated actor, the handler function will iterate through the reaction actors and call the handler code for each one.
---
--- @param index The index of the reaction in the msg_reactions table.
---
function ActorReaction:__generateHandler(index)
	if type(self.HandlerCode) ~= "function" then return end
	
	local msgdef = MsgDefs[self.Event] or empty_table
	local msgparams = msgdef.Params or ""
	if msgparams == "" then
		msgparams = "nil"
	end
	local code = pstr("", 1024)
	
	local params = self:GetParams()
	local exec_params = self:GetExecParams()

	local h_name, h_params, h_body = GetFuncSource(self.HandlerCode)

	local actor = self:GetActor()
	local handler_call = ""
	if type(h_body) == "string" then
		handler_call = h_body
	elseif type(h_body) == "table" then
		handler_call = table.concat(h_body, "\n")
	end
	
	
	code:appendf("local reaction_def = (self.msg_reactions or empty_table)[%d]", index)
	
	if actor then
		code:appendf("\nif self:VerifyReaction(\"%s\", reaction_def, %s, %s) then", self.Event, actor, msgparams)
		code:appendf("\n\t%s", handler_call)
		code:appendf("\nend")
	else	
		code:appendf("\nlocal actors = self:GetReactionActors(\"%s\", reaction_def, %s)", self.Event, msgparams)
		code:append("\nfor _, reaction_actor in ipairs(actors) do")
			code:appendf("\n\tif self:VerifyReaction(\"%s\", reaction_def, reaction_actor, %s) then", self.Event, msgparams)
			code:appendf("\n\t\t%s", handler_call)
			code:appendf("\n\tend")
		code:append("\nend")		
	end
	
	code = tostring(code)
	self.Handler = CompileFunc("Handler", params, code)
end

--- Returns the actor associated with this reaction.
---
--- @return table|nil The actor associated with this reaction, or nil if there is no actor.
function ActorReaction:GetActor()
	return self.ActorParam
end

--- Checks if the specified flag is set for this ActorReaction.
---
--- @param flag string The flag to check.
--- @return boolean True if the flag is set, false otherwise.
function ActorReaction:HasFlag(flag)
	return self.Flags and self.Flags[flag]
end

---
--- Callback function that is called when a property of the `ActorReaction` object is set in the editor.
---
--- This function updates the `Handler` and `Flags` properties of the `ActorReaction` object when certain properties are changed.
---
--- @param prop_id string The ID of the property that was changed.
--- @param old_value any The previous value of the property.
--- @param ged table The GED (Game Editor) object associated with the `ActorReaction` object.
---
function ActorReaction:OnEditorSetProperty(prop_id, old_value, ged)
	local need_update
	if prop_id == "Event" then
		self.ActorParam = false
		need_update = true
	elseif prop_id == "ActorParam" then
		need_update = true
	end
	
	if need_update then
		self:__generateHandler(1) -- OnPreSave will give the correct index, for now we just need to update the parameters
		-- force reevaluation of the Handler's params when the event changes
		GedSetProperty(ged, self, "Handler", GameToGedValue(self.Handler, self:GetPropertyMetadata("Handler"), self))
	end
	self.Flags = (#(self.FlagsDef or empty_table) > 0) and {} or nil
	for _, flag in ipairs(self.FlagsDef) do
		self.Flags[flag] = true
	end
end
DefineClass("MsgActorReaction", "MsgReaction", "ActorReaction")
-- end ActorReaction

-- ReactionEffects
DefineClass.ActorReactionEffects = {
	__parents = { "ActorReaction" },
	properties = {
		{ id = "Handler", editor = "func", default = false, lines = 6, max_lines = 60, no_edit = true,
			name = function(self) return self.Event end,
			params = function (self) return self:GetParams() end, },
		{ id = "HandlerCode", editor = "func", default = false, lines = 6, max_lines = 60, no_edit =  true, dont_save = true,
			name = function(self) return self.Event or "Handler" end,
			params = function (self) return self:GetParams() end, },			
		{ id = "Effects", editor = "nested_list", default = false, template = true, base_class = "ConditionalEffect", inclusive = true, },
	},
}

---
--- Generates the `Handler` function for an `ActorReactionEffects` object.
---
--- The generated `Handler` function is responsible for executing the reaction effects when the associated event occurs.
---
--- @param index number The index of the reaction in the `msg_reactions` table.
---
function ActorReactionEffects:__generateHandler(index)
	local msgdef = MsgDefs[self.Event] or empty_table
	local actor = self:GetActor()
	local params = self:GetParams()
	local code = string.format("ExecReactionEffects(self, %d, \"%s\", %s, %s)", index, self.Event, actor or "nil", params)
	self.Handler = CompileFunc("Handler", self:GetParams(), code)
end

---
--- Executes the reaction effects for a given event and reaction actor.
---
--- This function is responsible for executing the effects associated with a reaction
--- when the corresponding event occurs. It handles the case where the reaction actor
--- is provided, as well as the case where the reaction actors need to be retrieved
--- from the `MsgActorReactionsPreset`.
---
--- @param self MsgReactionsPreset The preset object containing the reactions.
--- @param index number The index of the reaction in the `msg_reactions` table.
--- @param event string The name of the event that triggered the reaction.
--- @param reaction_actor any The actor associated with the reaction.
--- @param ... any Additional parameters passed to the reaction.
---
function ExecReactionEffects(self, index, event, reaction_actor, ...)
	if not IsKindOf(self, "MsgReactionsPreset") then return end
		
	local reaction_def = (self.msg_reactions or empty_table)[index]
	if not reaction_def or reaction_def.Event ~= event then return end
	
	local context = {}
	local effects = reaction_def.Effects
	context.target_units = {reaction_actor}
	if not IsKindOf(self, "MsgActorReactionsPreset") then
		ExecuteEffectList(effects, reaction_actor, context) -- reaction_actor can be nil
		return
	end
			
	if reaction_actor then
		if self:VerifyReaction(event, reaction_def, reaction_actor, ...) then
			ExecuteEffectList(effects, reaction_actor, context)
		end
	else
		local actors = self:GetReactionActors(event, reaction_def, ...)
		for _, reaction_actor in ipairs(actors) do
			if self:VerifyReaction(event, reaction_def, reaction_actor, ...) then
				context.target_units[1] = reaction_actor
				ExecuteEffectList(effects, reaction_actor, context)
			end
		end
	end
end
DefineClass("MsgActorReactionEffects", "MsgReaction", "ActorReactionEffects")
-- end ReactionEffects

-- MsgActorReactionsPreset
DefineClass.MsgActorReactionsPreset = {
	__parents = { "UnitReactionsPreset" },
}

---
--- Verifies whether a given reaction should be executed for a specific event and actor.
---
--- This function is responsible for determining if a reaction should be executed based on the
--- provided event, reaction definition, and actor. It allows the MsgActorReactionsPreset to
--- control the conditions under which a reaction is triggered.
---
--- @param event string The name of the event that triggered the reaction.
--- @param reaction table The reaction definition.
--- @param actor any The actor associated with the reaction.
--- @param ... any Additional parameters passed to the reaction.
--- @return boolean true if the reaction should be executed, false otherwise.
---
function MsgActorReactionsPreset:VerifyReaction(event, reaction, actor, ...)
	return
end

---
--- Retrieves the reaction actors for a given event and reaction definition.
---
--- This function is responsible for determining the list of actors that should be considered
--- for a given reaction. It allows the MsgActorReactionsPreset to control which actors are
--- eligible to have the reaction executed.
---
--- @param event string The name of the event that triggered the reaction.
--- @param reaction table The reaction definition.
--- @param ... any Additional parameters passed to the reaction.
--- @return table A list of actors that should be considered for the reaction.
---
function MsgActorReactionsPreset:GetReactionActors(event, reaction, ...)
	return
end

---
--- Generates handlers for the `ActorReaction` instances in the `msg_reactions` table.
---
--- This function is called during the pre-save process to ensure that the `ActorReaction`
--- instances have their handlers properly generated. This is necessary for the reactions
--- to function correctly when the game state is loaded.
---
function MsgActorReactionsPreset:OnPreSave()
	for i, reaction in ipairs(self.msg_reactions) do
		if IsKindOf(reaction, "ActorReaction") then
			reaction:__generateHandler(i)
		end
	end
end

-- end MsgActorReactionsPreset

-- misc/utility

---
--- Resolves a unit actor object based on the provided session ID and unit data.
---
--- This function is responsible for determining the appropriate unit actor object to use
--- for a given reaction. It handles cases where the unit may have been despawned or
--- where the satellite view is active.
---
--- @param session_id string The session ID of the unit.
--- @param unit_data table The unit data associated with the session ID.
--- @return any The resolved unit actor object.
---
function ZuluReactionResolveUnitActorObj(session_id, unit_data)
	local obj
	local mapUnit = g_Units[session_id]
	if gv_SatelliteView or (mapUnit and (not IsValid(mapUnit) or mapUnit.is_despawned)) then
		return unit_data or gv_UnitData[session_id]
	end
	return mapUnit or unit_data or gv_UnitData[session_id]
end

---
--- Generates a list of unit actor objects that are eligible to have a reaction executed.
---
--- This function is responsible for determining the appropriate unit actor objects to consider
--- for a given reaction. It handles cases where the satellite view is active or where units
--- have been despawned.
---
--- @param event string The name of the event that triggered the reaction.
--- @param reaction_def table The reaction definition.
--- @param ... any Additional parameters passed to the reaction.
--- @return table A list of unit actor objects that should be considered for the reaction.
---
function ZuluReactionGetReactionActors_Light(event, reaction_def, ...)
	local objs = {}
	if reaction_def:HasFlag("SatView") then
		for session_id, data in pairs(gv_UnitData) do
			local obj = ZuluReactionResolveUnitActorObj(session_id, data)
			if self:VerifyReaction(event, obj, ...) then
				objs[#objs + 1] = obj
			end
		end
	else
		table.iappend(objs, g_Units)
	end
	table.sortby_field(objs, "session_id")
	return objs
end