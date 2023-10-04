-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('CharacterEffectCompositeDef', {
	'Id', "Inspired",
	'Parameters', {
		PlaceObj('PresetParamNumber', {
			'Name', "bonus",
			'Value', 4,
			'Tag', "<bonus>",
		}),
	},
	'object_class', "CharacterEffect",
	'msg_reactions', {
		PlaceObj('MsgActorReaction', {
			ActorParam = "obj",
			Event = "StatusEffectAdded",
			Handler = function (self, obj, id, stacks)
				
				local function exec(self, obj, id, stacks)
				if g_Teams[g_CurrentTeam] == obj.team then
					obj:SetEffectValue("InspiredEffectApplied", true)
					obj:GainAP(self:ResolveValue("bonus") * const.Scale.AP)
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
				if g_Teams[g_CurrentTeam] == obj.team then
					obj:SetEffectValue("InspiredEffectApplied", true)
					obj:GainAP(self:ResolveValue("bonus") * const.Scale.AP)
				end
			end,
		}),
		PlaceObj('MsgActorReaction', {
			ActorParam = "obj",
			Event = "StatusEffectRemoved",
			Handler = function (self, obj, id, stacks, reason)
				
				local function exec(self, obj, id, stacks, reason)
				obj:SetEffectValue("InspiredEffectApplied", nil)
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
				obj:SetEffectValue("InspiredEffectApplied", nil)
			end,
		}),
		PlaceObj('MsgActorReaction', {
			ActorParam = "unit",
			Event = "UnitBeginTurn",
			Handler = function (self, unit)
				
				local function exec(self, unit)
				if not unit:GetEffectValue("InspiredEffectApplied") then
					unit:GainAP(self:ResolveValue("bonus") * const.Scale.AP)
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
				if not unit:GetEffectValue("InspiredEffectApplied") then
					unit:GainAP(self:ResolveValue("bonus") * const.Scale.AP)
				end
			end,
		}),
	},
	'Conditions', {
		PlaceObj('CheckExpression', {
			Expression = function (self, obj) return g_Combat and IsKindOf(obj, "Unit") end,
		}),
	},
	'DisplayName', T(122953001800, --[[CharacterEffectCompositeDef Inspired DisplayName]] "Inspired"),
	'Description', T(853696490891, --[[CharacterEffectCompositeDef Inspired Description]] "Gain <em><bonus> AP</em>."),
	'AddEffectText', T(811015193839, --[[CharacterEffectCompositeDef Inspired AddEffectText]] "<em><DisplayName></em> is inspired"),
	'type', "Buff",
	'lifetime', "Until End of Turn",
	'Icon', "UI/Hud/Status effects/inspired",
	'RemoveOnEndCombat', true,
	'Shown', true,
	'HasFloatingText', true,
})

