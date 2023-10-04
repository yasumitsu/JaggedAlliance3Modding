-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('CharacterEffectCompositeDef', {
	'Group', "Perk-Personal",
	'Id', "VengefulTemperament",
	'Comment', "Meltdown - last enemy that attacks her has Vengeance",
	'object_class', "Perk",
	'msg_reactions', {
		PlaceObj('MsgActorReaction', {
			ActorParam = "attacker",
			Event = "OnAttack",
			Handler = function (self, attacker, action, target, results, attack_args)
				
				local function exec(self, attacker, action, target, results, attack_args)
				-- proc
				if target and IsKindOf(target, "Unit") and target:HasStatusEffect("VengeanceTarget" ) then
					attacker:AddStatusEffect("Inspired")
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
				-- proc
				if target and IsKindOf(target, "Unit") and target:HasStatusEffect("VengeanceTarget" ) then
					attacker:AddStatusEffect("Inspired")
				end
			end,
		}),
		PlaceObj('MsgActorReaction', {
			ActorParam = "target",
			Event = "OnAttack",
			Handler = function (self, attacker, action, target, results, attack_args)
				
				local function exec(self, attacker, action, target, results, attack_args)
				-- apply debuff
				if not results.miss and not IsMerc(attacker) then
					for _, unit in ipairs(g_Units) do 
						unit:RemoveStatusEffect("VengeanceTarget")
					end
					attacker:AddStatusEffect("VengeanceTarget")
				end
				end
				
				if not IsKindOf(self, "MsgReactionsPreset") then return end
				
				local reaction_def = (self.msg_reactions or empty_table)[2]
				if not reaction_def or reaction_def.Event ~= "OnAttack" then return end
				
				if not IsKindOf(self, "MsgActorReactionsPreset") then
					exec(self, attacker, action, target, results, attack_args)
				end
				
				if self:VerifyReaction("OnAttack", reaction_def, target, attacker, action, target, results, attack_args) then
					exec(self, attacker, action, target, results, attack_args)
				end
			end,
			HandlerCode = function (self, attacker, action, target, results, attack_args)
				-- apply debuff
				if not results.miss and not IsMerc(attacker) then
					for _, unit in ipairs(g_Units) do 
						unit:RemoveStatusEffect("VengeanceTarget")
					end
					attacker:AddStatusEffect("VengeanceTarget")
				end
			end,
			helpActor = "target",
		}),
	},
	'DisplayName', T(562100828460, --[[CharacterEffectCompositeDef VengefulTemperament DisplayName]] "Hard Feelings"),
	'Description', T(391944412961, --[[CharacterEffectCompositeDef VengefulTemperament Description]] "The last enemy to attack Meltdown is marked by <GameTerm('Vengeance')><AdditionalTerm('Inspired')>."),
	'Icon', "UI/Icons/Perks/VengefulTemperament",
	'Tier', "Personal",
})

