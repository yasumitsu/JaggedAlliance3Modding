-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('CharacterEffectCompositeDef', {
	'Id', "Mobile",
	'Parameters', {
		PlaceObj('PresetParamNumber', {
			'Name', "move_ap_modifier",
			'Value', 50,
			'Tag', "<move_ap_modifier>",
		}),
	},
	'object_class', "StatusEffect",
	'msg_reactions', {
		PlaceObj('MsgActorReaction', {
			ActorParam = "obj",
			Event = "StatusEffectAdded",
			Handler = function (self, obj, id, stacks)
				
				local function exec(self, obj, id, stacks)
				Msg("UnitAPChanged", obj)
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
				Msg("UnitAPChanged", obj)
			end,
		}),
		PlaceObj('MsgActorReaction', {
			ActorParam = "obj",
			Event = "StatusEffectRemoved",
			Handler = function (self, obj, id, stacks, reason)
				
				local function exec(self, obj, id, stacks, reason)
				Msg("UnitAPChanged", obj)
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
				Msg("UnitAPChanged", obj)
			end,
		}),
	},
	'DisplayName', T(756256221127, --[[CharacterEffectCompositeDef Mobile DisplayName]] "Mobile"),
	'Description', T(320614422830, --[[CharacterEffectCompositeDef Mobile Description]] "<em><percent(move_ap_modifier)></em> lower <em>Movement cost</em>"),
	'type', "Buff",
	'lifetime', "Until End of Next Turn",
	'Icon', "UI/Hud/Status effects/mobility",
	'RemoveOnEndCombat', true,
	'Shown', true,
	'HasFloatingText', true,
})

