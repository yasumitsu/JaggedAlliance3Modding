-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('CharacterEffectCompositeDef', {
	'Group', "Perk-Personal",
	'Id', "KillingWind",
	'Parameters', {
		PlaceObj('PresetParamNumber', {
			'Name', "gritPerEnemyHit",
			'Value', 8,
			'Tag', "<gritPerEnemyHit>",
		}),
	},
	'Comment', "Fauda - Machine gun bonuses; Grit when multiple enemies hit",
	'object_class', "Perk",
	'msg_reactions', {
		PlaceObj('MsgActorReaction', {
			ActorParam = "attacker",
			Event = "OnAttack",
			Handler = function (self, attacker, action, target, results, attack_args)
				
				local function exec(self, attacker, action, target, results, attack_args)
				local enemiesHit = 0
				if results and results.hit_objs then
					for _, obj in ipairs(results.hit_objs) do
						if IsKindOf(obj, "Unit") and obj:IsOnEnemySide(attacker) then
							enemiesHit = enemiesHit + 1
						end
					end
				end
				
				if enemiesHit >= 2 then
					local grit = self:ResolveValue("gritPerEnemyHit") * enemiesHit
					attacker:ApplyTempHitPoints(grit)
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
				local enemiesHit = 0
				if results and results.hit_objs then
					for _, obj in ipairs(results.hit_objs) do
						if IsKindOf(obj, "Unit") and obj:IsOnEnemySide(attacker) then
							enemiesHit = enemiesHit + 1
						end
					end
				end
				
				if enemiesHit >= 2 then
					local grit = self:ResolveValue("gritPerEnemyHit") * enemiesHit
					attacker:ApplyTempHitPoints(grit)
				end
			end,
		}),
	},
	'DisplayName', T(219730505411, --[[CharacterEffectCompositeDef KillingWind DisplayName]] "Heavy Duty"),
	'Description', T(958058532892, --[[CharacterEffectCompositeDef KillingWind Description]] "Gains <em><gritPerEnemyHit></em> <GameTerm('Grit')> per enemy when hitting multiple enemies at once.\n\nImproves the effect of the <em>Ironclad</em> perk to full <GameTerm('FreeMove')> with cumbersome gear and after <GameTerm('PackingUp')> a <em>Machine Gun</em>.\n"),
	'Icon', "UI/Icons/Perks/KillingWind",
	'Tier', "Personal",
})

