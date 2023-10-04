-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('CharacterEffectCompositeDef', {
	'Group', "System",
	'Id', "Smoked",
	'object_class', "StatusEffect",
	'msg_reactions', {
		PlaceObj('MsgActorReaction', {
			ActorParam = "obj",
			Event = "StatusEffectAdded",
			Handler = function (self, obj, id, stacks)
				
				local function exec(self, obj, id, stacks)
				if IsKindOf(obj, "Unit") then
					obj:SetEffectValue("smoked_start_time", GameTime())
					ObjModified(obj)
				
					if obj:IsMerc() then
						PlayVoiceResponse(obj, "GasAreaSelection")
					else
						PlayVoiceResponse(obj, "AIGasAreaSelection")
					end
				end
				end
				
				if not IsKindOf(self, "MsgReactionsPreset") then return end
				
				local reaction_def = (self.msg_reactions or empty_table)[1]
				if not reaction_def or reaction_def.Event ~= "StatusEffectAdded" then return end
				
				if not IsKindOf(self, "MsgActorReactionsPreset") then
					exec(self, obj, id, stacks)
				end
				
				if self:VerifyReaction("StatusEffectAdded", reaction_def, obj, obj, id, stacks) then
					exec(self, obj, id, stacks)
				end
			end,
			HandlerCode = function (self, obj, id, stacks)
				if IsKindOf(obj, "Unit") then
					obj:SetEffectValue("smoked_start_time", GameTime())
					ObjModified(obj)
				
					if obj:IsMerc() then
						PlayVoiceResponse(obj, "GasAreaSelection")
					else
						PlayVoiceResponse(obj, "AIGasAreaSelection")
					end
				end
			end,
		}),
		PlaceObj('MsgActorReaction', {
			ActorParam = "obj",
			Event = "StatusEffectRemoved",
			Handler = function (self, obj, id, stacks, reason)
				
				local function exec(self, obj, id, stacks, reason)
				if IsKindOf(obj, "Unit") then
					obj:SetEffectValue("Smoked_start_time")
					ObjModified(obj)
				end
				end
				
				if not IsKindOf(self, "MsgReactionsPreset") then return end
				
				local reaction_def = (self.msg_reactions or empty_table)[2]
				if not reaction_def or reaction_def.Event ~= "StatusEffectRemoved" then return end
				
				if not IsKindOf(self, "MsgActorReactionsPreset") then
					exec(self, obj, id, stacks, reason)
				end
				
				if self:VerifyReaction("StatusEffectRemoved", reaction_def, obj, obj, id, stacks, reason) then
					exec(self, obj, id, stacks, reason)
				end
			end,
			HandlerCode = function (self, obj, id, stacks, reason)
				if IsKindOf(obj, "Unit") then
					obj:SetEffectValue("Smoked_start_time")
					ObjModified(obj)
				end
			end,
		}),
		PlaceObj('MsgActorReaction', {
			ActorParam = "unit",
			Event = "UnitBeginTurn",
			Handler = function (self, unit)
				
				local function exec(self, unit)
				if not unit:IsDead() then
					EnvEffectSmokeTick(unit, nil, "start turn")
					if unit:IsMerc() then
						PlayVoiceResponse(unit, "GasAreaSelection")
					else
						PlayVoiceResponse(unit, "AIGasAreaSelection")
					end
				end
				end
				
				if not IsKindOf(self, "MsgReactionsPreset") then return end
				
				local reaction_def = (self.msg_reactions or empty_table)[3]
				if not reaction_def or reaction_def.Event ~= "UnitBeginTurn" then return end
				
				if not IsKindOf(self, "MsgActorReactionsPreset") then
					exec(self, unit)
				end
				
				if self:VerifyReaction("UnitBeginTurn", reaction_def, unit, unit) then
					exec(self, unit)
				end
			end,
			HandlerCode = function (self, unit)
				if not unit:IsDead() then
					EnvEffectSmokeTick(unit, nil, "start turn")
					if unit:IsMerc() then
						PlayVoiceResponse(unit, "GasAreaSelection")
					else
						PlayVoiceResponse(unit, "AIGasAreaSelection")
					end
				end
			end,
		}),
		PlaceObj('MsgActorReaction', {
			ActorParam = "unit",
			Event = "UnitEndTurn",
			Handler = function (self, unit)
				
				local function exec(self, unit)
				if not unit:IsDead() then
					EnvEffectSmokeTick(unit, nil, "end turn")
				end
				end
				
				if not IsKindOf(self, "MsgReactionsPreset") then return end
				
				local reaction_def = (self.msg_reactions or empty_table)[4]
				if not reaction_def or reaction_def.Event ~= "UnitEndTurn" then return end
				
				if not IsKindOf(self, "MsgActorReactionsPreset") then
					exec(self, unit)
				end
				
				if self:VerifyReaction("UnitEndTurn", reaction_def, unit, unit) then
					exec(self, unit)
				end
			end,
			HandlerCode = function (self, unit)
				if not unit:IsDead() then
					EnvEffectSmokeTick(unit, nil, "end turn")
				end
			end,
		}),
	},
	'DisplayName', T(191169991129, --[[CharacterEffectCompositeDef Smoked DisplayName]] "In Smoke"),
})

