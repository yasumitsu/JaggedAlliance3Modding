-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

UndefineClass('Deadeye')
DefineClass.Deadeye = {
	__parents = { "Perk" },
	__generated_by_class = "CharacterEffectCompositeDef",


	object_class = "Perk",
	msg_reactions = {
		PlaceObj('MsgActorReaction', {
			ActorParam = "attacker",
			Event = "GatherCritChanceModifications",
			Handler = function (self, attacker, target, action_id, weapon, data)
				
				local function exec(self, attacker, target, action_id, weapon, data)
				data.crit_per_aim = data.crit_per_aim + self:ResolveValue("crit_per_aim")
				end
				
				if not IsKindOf(self, "MsgReactionsPreset") then return end
				
				local reaction_def = (self.msg_reactions or empty_table)[1]
				if not reaction_def or reaction_def.Event ~= "GatherCritChanceModifications" then return end
				
				if not IsKindOf(self, "MsgActorReactionsPreset") then
					exec(self, attacker, target, action_id, weapon, data)
				end
				
				if self:VerifyReaction("GatherCritChanceModifications", reaction_def, attacker, attacker, target, action_id, weapon, data) then
					exec(self, attacker, target, action_id, weapon, data)
				end
			end,
			HandlerCode = function (self, attacker, target, data)
				data.crit_per_aim = data.crit_per_aim + self:ResolveValue("crit_per_aim")
			end,
		}),
	},
	DisplayName = T(333539797050, --[[CharacterEffectCompositeDef Deadeye DisplayName]] "Deadeye"),
	Description = T(923228420877, --[[CharacterEffectCompositeDef Deadeye Description]] "Gain <em><percent(crit_per_aim)></em> extra <GameTerm('Crit')> chance per <GameTerm('Aim')>."),
	Icon = "UI/Icons/Perks/Deadeye",
	Tier = "Bronze",
	Stat = "Dexterity",
	StatValue = 70,
}

