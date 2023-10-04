-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('CharacterEffectCompositeDef', {
	'Group', "Perk-Personal",
	'Id', "TagTeam",
	'Parameters', {
		PlaceObj('PresetParamPercent', {
			'Name', "accuracyBonus",
			'Value', 15,
			'Tag', "<accuracyBonus>%",
		}),
	},
	'Comment', "Raider - Bonus against enemies in Overwatch cone of ally",
	'object_class', "Perk",
	'msg_reactions', {
		PlaceObj('MsgActorReaction', {
			ActorParam = "attacker",
			Event = "GatherCTHModifications",
			Handler = function (self, attacker, cth_id, action_id, target, weapon1, weapon2, data)
				
				local function exec(self, attacker, cth_id, action_id, target, weapon1, weapon2, data)
				if cth_id == self.id and IsKindOf(data.target, "Unit") and data.target:IsThreatened(GetAllEnemyUnits(data.target), "overwatch") then
					data.mod_add = data.mod_add + self:ResolveValue("accuracyBonus")
					data.display_name = T{776394275735, "Perk: <name>", name = self.DisplayName}
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
				if cth_id == self.id and IsKindOf(data.target, "Unit") and data.target:IsThreatened(GetAllEnemyUnits(data.target), "overwatch") then
					data.mod_add = data.mod_add + self:ResolveValue("accuracyBonus")
					data.display_name = T{776394275735, "Perk: <name>", name = self.DisplayName}
				end
			end,
		}),
	},
	'DisplayName', T(786595073425, --[[CharacterEffectCompositeDef TagTeam DisplayName]] "Tag Team"),
	'Description', T(804189996555, --[[CharacterEffectCompositeDef TagTeam Description]] "Bonus <em>Accuracy</em> against enemies within the <GameTerm('Overwatch')> area of an ally."),
	'Icon', "UI/Icons/Perks/TagTeam",
	'Tier', "Personal",
})

