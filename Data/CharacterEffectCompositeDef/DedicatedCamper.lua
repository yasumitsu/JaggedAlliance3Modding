-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('CharacterEffectCompositeDef', {
	'Group', "Perk-Personal",
	'Id', "DedicatedCamper",
	'Comment', "Hitman - Bonus damage and grit when standing still",
	'object_class', "Perk",
	'msg_reactions', {
		PlaceObj('MsgActorReaction', {
			ActorParam = "unit",
			Event = "UnitBeginTurn",
			Handler = function (self, unit)
				
				local function exec(self, unit)
				unit:AddStatusEffect("Focused")
				end
				
				if not IsKindOf(self, "MsgReactionsPreset") then return end
				
				local reaction_def = (self.msg_reactions or empty_table)[1]
				if not reaction_def or reaction_def.Event ~= "UnitBeginTurn" then return end
				
				if not IsKindOf(self, "MsgActorReactionsPreset") then
					exec(self, unit)
				end
				
				if self:VerifyReaction("UnitBeginTurn", reaction_def, unit, unit) then
					exec(self, unit)
				end
			end,
			HandlerCode = function (self, unit)
				unit:AddStatusEffect("Focused")
			end,
		}),
	},
	'DisplayName', T(768808311402, --[[CharacterEffectCompositeDef DedicatedCamper DisplayName]] "Smarter, Not Harder"),
	'Description', T(153311106914, --[[CharacterEffectCompositeDef DedicatedCamper Description]] "Gains <GameTerm('Focused')> each turn. <AdditionalTerm('Grit')>"),
	'Icon', "UI/Icons/Perks/DedicatedCamper",
	'Tier', "Personal",
})

