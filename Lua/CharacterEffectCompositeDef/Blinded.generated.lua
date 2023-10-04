-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

UndefineClass('Blinded')
DefineClass.Blinded = {
	__parents = { "CharacterEffect" },
	__generated_by_class = "CharacterEffectCompositeDef",


	object_class = "CharacterEffect",
	msg_reactions = {
		PlaceObj('MsgActorReaction', {
			ActorParam = "obj",
			Event = "StatusEffectAdded",
			Handler = function (self, obj, id, stacks)
				
				local function exec(self, obj, id, stacks)
				if IsKindOf(obj, "Unit") then
					obj:SetEffectValue("blinded_start_time", GameTime())
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
					obj:SetEffectValue("blinded_start_time", GameTime())
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
					obj:SetEffectValue("blinded_start_time")
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
					obj:SetEffectValue("blinded_start_time")
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
					EnvEffectTearGasTick(unit, nil, "start turn")
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
					EnvEffectTearGasTick(unit, nil, "start turn")
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
					EnvEffectTearGasTick(unit, nil, "end turn")
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
					EnvEffectTearGasTick(unit, nil, "end turn")
				end
			end,
		}),
		PlaceObj('MsgActorReaction', {
			ActorParam = "attacker",
			Event = "GatherCTHModifications",
			Handler = function (self, attacker, cth_id, action_id, target, weapon1, weapon2, data)
				
				local function exec(self, attacker, cth_id, action_id, target, weapon1, weapon2, data)
				if cth_id == self.id then
					data.mod_add = data.mod_add + self:ResolveValue("cth_effect")
				end
				end
				
				if not IsKindOf(self, "MsgReactionsPreset") then return end
				
				local reaction_def = (self.msg_reactions or empty_table)[5]
				if not reaction_def or reaction_def.Event ~= "GatherCTHModifications" then return end
				
				if not IsKindOf(self, "MsgActorReactionsPreset") then
					exec(self, attacker, cth_id, action_id, target, weapon1, weapon2, data)
				end
				
				if self:VerifyReaction("GatherCTHModifications", reaction_def, attacker, attacker, cth_id, action_id, target, weapon1, weapon2, data) then
					exec(self, attacker, cth_id, action_id, target, weapon1, weapon2, data)
				end
			end,
			HandlerCode = function (self, attacker, cth_id, data)
				if cth_id == self.id then
					data.mod_add = data.mod_add + self:ResolveValue("cth_effect")
				end
			end,
		}),
	},
	DisplayName = T(629298563884, --[[CharacterEffectCompositeDef Blinded DisplayName]] "Blinded"),
	Description = T(595664130748, --[[CharacterEffectCompositeDef Blinded Description]] "Reduced <em>Sight range</em> and <em>Accuracy</em>. Can cause <em>Panic</em>."),
	AddEffectText = T(880622931884, --[[CharacterEffectCompositeDef Blinded AddEffectText]] "<em><DisplayName></em> is blinded"),
	type = "Debuff",
	Icon = "UI/Hud/Status effects/blinded",
	RemoveOnSatViewTravel = true,
	RemoveOnCampaignTimeAdvance = true,
	Shown = true,
	HasFloatingText = true,
}

