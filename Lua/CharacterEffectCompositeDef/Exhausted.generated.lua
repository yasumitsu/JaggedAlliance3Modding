-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

UndefineClass('Exhausted')
DefineClass.Exhausted = {
	__parents = { "StatusEffect" },
	__generated_by_class = "CharacterEffectCompositeDef",


	object_class = "StatusEffect",
	msg_reactions = {
		PlaceObj('MsgActorReaction', {
			ActorParam = "obj",
			Event = "StatusEffectAdded",
			Handler = function (self, obj, id, stacks)
				
				local function exec(self, obj, id, stacks)
				obj:AddStatusEffectImmunity("FreeMove", id)
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
				obj:AddStatusEffectImmunity("FreeMove", id)
			end,
		}),
		PlaceObj('MsgActorReaction', {
			ActorParam = "obj",
			Event = "StatusEffectRemoved",
			Handler = function (self, obj, id, stacks, reason)
				
				local function exec(self, obj, id, stacks, reason)
				obj:RemoveStatusEffectImmunity("FreeMove", id)
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
				obj:RemoveStatusEffectImmunity("FreeMove", id)
			end,
		}),
		PlaceObj('MsgActorReaction', {
			ActorParam = "unit",
			Event = "UnitBeginTurn",
			Handler = function (self, unit)
				
				local function exec(self, unit)
				unit:ConsumeAP(-self:ResolveValue("ap_loss") * const.Scale.AP)
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
				unit:ConsumeAP(-self:ResolveValue("ap_loss") * const.Scale.AP)
			end,
		}),
	},
	DisplayName = T(707410221892, --[[CharacterEffectCompositeDef Exhausted DisplayName]] "Exhausted"),
	Description = T(787484805512, --[[CharacterEffectCompositeDef Exhausted Description]] "Penalty of <em><ap_loss> is applied to your maximum AP</em>. Cannot gain <em>Free Move</em>. Recover by being idle for <duration> hours in Sat View."),
	AddEffectText = T(264384902433, --[[CharacterEffectCompositeDef Exhausted AddEffectText]] "<em><DisplayName></em> is exhausted"),
	RemoveEffectText = T(377164938786, --[[CharacterEffectCompositeDef Exhausted RemoveEffectText]] "<em><DisplayName></em> is no longer exhausted"),
	type = "Debuff",
	Icon = "UI/Hud/Status effects/exhausted",
	Shown = true,
	ShownSatelliteView = true,
	HasFloatingText = true,
}

