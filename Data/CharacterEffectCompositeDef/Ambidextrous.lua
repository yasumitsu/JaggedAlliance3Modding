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
		PlaceObj('MsgReaction', {
			Event = "GatherCTHModifications",
			Handler = function (self, attacker, cth_id, data)
				local reaction_idx = table.find(self.msg_reactions or empty_table, "Event", "GatherCTHModifications")
				if not reaction_idx then return end
				
				local function exec(self, attacker, cth_id, data)
				if cth_id == "TwoWeaponFire" then
					data.meta_text[#data.meta_text + 1] = T{756119910645, "Perk: <perkName>", perkName = self.DisplayName}
					data.mod_add = self:ResolveValue("PenaltyReduction")
				end
				end
				local id = GetCharacterEffectId(self)
				
				if id then
					if IsKindOf(attacker, "StatusEffectObject") and attacker:HasStatusEffect(id) then
						exec(self, attacker, cth_id, data)
					end
				else
					exec(self, attacker, cth_id, data)
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

