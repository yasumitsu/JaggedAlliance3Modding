-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('CharacterEffectCompositeDef', {
	'Group', "Quirk",
	'Id', "Ambidextrous",
	'SortKey', 1000,
	'Parameters', {
		PlaceObj('PresetParamNumber', {
			'Name', "PenaltyReduction",
			'Value', 15,
			'Tag', "<PenaltyReduction>",
		}),
	},
	'object_class', "Perk",
	'msg_reactions', {
		PlaceObj('MsgActorReaction', {
			ActorParam = "attacker",
			Event = "GatherCTHModifications",
			Handler = function (self, attacker, cth_id, action_id, target, weapon1, weapon2, data)
				
				local function exec(self, attacker, cth_id, action_id, target, weapon1, weapon2, data)
				if cth_id == "TwoWeaponFire" then
					data.meta_text[#data.meta_text + 1] = T{756119910645, "Perk: <perkName>", perkName = self.DisplayName}
					data.mod_add = self:ResolveValue("PenaltyReduction")
				end
				end
				
				if not IsKindOf(self, "MsgReactionsPreset") then return end
				
				local reaction_def = (self.msg_reactions or empty_table)[1]
				if not reaction_def or reaction_def.Event ~= "GatherCTHModifications" then return end
				
				if not IsKindOf(self, "MsgActorReactionsPreset") then
					exec(self, attacker, cth_id, action_id, target, weapon1, weapon2, data)
				end
				
				if self:VerifyReaction("GatherCTHModifications", reaction_def, attacker, attacker, cth_id, action_id, target, weapon1, weapon2, data) then
					exec(self, attacker, cth_id, action_id, target, weapon1, weapon2, data)
				end
			end,
			HandlerCode = function (self, attacker, cth_id, data)
				if cth_id == "TwoWeaponFire" then
					data.meta_text[#data.meta_text + 1] = T{756119910645, "Perk: <perkName>", perkName = self.DisplayName}
					data.mod_add = self:ResolveValue("PenaltyReduction")
				end
			end,
		}),
	},
	'Modifiers', {},
	'DisplayName', T(572344361258, --[[CharacterEffectCompositeDef Ambidextrous DisplayName]] "Ambidextrous"),
	'Description', T(810486500317, --[[CharacterEffectCompositeDef Ambidextrous Description]] "Reduced <em>Accuracy</em> penalty when <em>Dual-Wielding</em> Firearms."),
	'Icon', "UI/Icons/Perks/Ambidextrous",
	'Tier', "Quirk",
})

