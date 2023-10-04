-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

UndefineClass('LeadFromTheFront')
DefineClass.LeadFromTheFront = {
	__parents = { "Perk" },
	__generated_by_class = "CharacterEffectCompositeDef",


	object_class = "Perk",
	msg_reactions = {
		PlaceObj('MsgActorReaction', {
			ActorParam = "attacker",
			Event = "OnAttack",
			Handler = function (self, attacker, action, target, results, attack_args)
				
				local function exec(self, attacker, action, target, results, attack_args)
				if IsKindOf(target, "Unit") and results.total_damage and results.total_damage >= self:ResolveValue("damageTreshold") then
					if attacker.team:IsPlayerControlled() and not attacker:HasStatusEffect("LeadFromTheFrontFlag") then
						attacker.team:ChangeMorale(self:ResolveValue("moraleBonus"), self.DisplayName)
						attacker:AddStatusEffect("LeadFromTheFrontFlag")
					end
				end
				end
				
				if not IsKindOf(self, "MsgReactionsPreset") then return end
				
				local reaction_def = (self.msg_reactions or empty_table)[1]
				if not reaction_def or reaction_def.Event ~= "OnAttack" then return end
				
				if not IsKindOf(self, "MsgActorReactionsPreset") then
					exec(self, attacker, action, target, results, attack_args)
				end
				
				if self:VerifyReaction("OnAttack", reaction_def, attacker, attacker, action, target, results, attack_args) then
					exec(self, attacker, action, target, results, attack_args)
				end
			end,
			HandlerCode = function (self, attacker, action, target, results, attack_args)
				if IsKindOf(target, "Unit") and results.total_damage and results.total_damage >= self:ResolveValue("damageTreshold") then
					if attacker.team:IsPlayerControlled() and not attacker:HasStatusEffect("LeadFromTheFrontFlag") then
						attacker.team:ChangeMorale(self:ResolveValue("moraleBonus"), self.DisplayName)
						attacker:AddStatusEffect("LeadFromTheFrontFlag")
					end
				end
			end,
		}),
	},
	DisplayName = T(589057792592, --[[CharacterEffectCompositeDef LeadFromTheFront DisplayName]] "Inspiring Strike"),
	Description = T(142399887488, --[[CharacterEffectCompositeDef LeadFromTheFront Description]] "Increase <GameTerm('Morale')> when you deal more than <em><damageTreshold> Damage</em> with a <em>single attack</em>.\n\nOnce per turn."),
	Icon = "UI/Icons/Perks/SquadLeadership",
	Tier = "Silver",
	Stat = "Wisdom",
	StatValue = 80,
}

