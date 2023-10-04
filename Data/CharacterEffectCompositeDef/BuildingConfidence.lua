-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('CharacterEffectCompositeDef', {
	'Group', "Perk-Personal",
	'Id', "BuildingConfidence",
	'Parameters', {
		PlaceObj('PresetParamNumber', {
			'Name', "turnToProc",
			'Value', 2,
			'Tag', "<turnToProc>",
		}),
		PlaceObj('PresetParamPercent', {
			'Name', "chanceToProc",
			'Value', 50,
			'Tag', "<chanceToProc>%",
		}),
	},
	'Comment', "MD - Inspired and + Morale after multiple turns",
	'object_class', "Perk",
	'msg_reactions', {
		PlaceObj('MsgActorReaction', {
			ActorParam = "attacker",
			Event = "OnAttack",
			Handler = function (self, attacker, action, target, results, attack_args)
				
				local function exec(self, attacker, action, target, results, attack_args)
				attacker:SetEffectValue("attackedThisCombat", true)
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
				attacker:SetEffectValue("attackedThisCombat", true)
			end,
		}),
		PlaceObj('MsgActorReaction', {
			Event = "CombatEnd",
			Handler = function (self, test_combat, combat, anyEnemies)
				
				local function exec(self, reaction_actor, test_combat, combat, anyEnemies)
				local unit = g_Units.MD
				if unit then
					unit:SetEffectValue("attackedThisCombat", false)
				end
				end
				
				if not IsKindOf(self, "MsgReactionsPreset") then return end
				
				local reaction_def = (self.msg_reactions or empty_table)[2]
				if not reaction_def or reaction_def.Event ~= "CombatEnd" then return end
				
				if not IsKindOf(self, "MsgActorReactionsPreset") then
					local reaction_actor
					exec(self, reaction_actor, test_combat, combat, anyEnemies)
				end
				
				
				local actors = self:GetReactionActors("CombatEnd", reaction_def, test_combat, combat, anyEnemies)
				for _, reaction_actor in ipairs(actors) do
					if self:VerifyReaction("CombatEnd", reaction_def, reaction_actor, test_combat, combat, anyEnemies) then
						exec(self, reaction_actor, test_combat, combat, anyEnemies)
					end
				end
			end,
			HandlerCode = function (self, reaction_actor, test_combat, combat, anyEnemies)
				local unit = g_Units.MD
				if unit then
					unit:SetEffectValue("attackedThisCombat", false)
				end
			end,
		}),
		PlaceObj('MsgActorReaction', {
			ActorParam = "unit",
			Event = "UnitBeginTurn",
			Handler = function (self, unit)
				
				local function exec(self, unit)
				if g_Combat then
					if g_Combat.current_turn >= self:ResolveValue("turnToProc") and unit:GetEffectValue("attackedThisCombat") and not unit:HasStatusEffect("ConfidenceBuilt") then
						local chance = self:ResolveValue("chanceToProc")
						local roll = InteractionRand(100, "BuildingConfidence")
						if roll < chance then
							unit:AddStatusEffect("Inspired")
							unit.team:ChangeMorale(1, self.DisplayName)
							unit:AddStatusEffect("ConfidenceBuilt") 
						end
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
				if g_Combat then
					if g_Combat.current_turn >= self:ResolveValue("turnToProc") and unit:GetEffectValue("attackedThisCombat") and not unit:HasStatusEffect("ConfidenceBuilt") then
						local chance = self:ResolveValue("chanceToProc")
						local roll = InteractionRand(100, "BuildingConfidence")
						if roll < chance then
							unit:AddStatusEffect("Inspired")
							unit.team:ChangeMorale(1, self.DisplayName)
							unit:AddStatusEffect("ConfidenceBuilt") 
						end
					end
				end
			end,
		}),
	},
	'DisplayName', T(110292118081, --[[CharacterEffectCompositeDef BuildingConfidence DisplayName]] "Find My Feet"),
	'Description', T(969057307540, --[[CharacterEffectCompositeDef BuildingConfidence Description]] "Can become <GameTerm('Inspired')> and increase the team's <GameTerm('Morale')> during combat."),
	'Icon', "UI/Icons/Perks/BuildingConfidence",
	'Tier', "Personal",
})

