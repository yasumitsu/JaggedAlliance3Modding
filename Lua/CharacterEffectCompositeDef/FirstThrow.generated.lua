-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

UndefineClass('FirstThrow')
DefineClass.FirstThrow = {
	__parents = { "StatusEffect" },
	__generated_by_class = "CharacterEffectCompositeDef",


	object_class = "StatusEffect",
	unit_reactions = {
		PlaceObj('UnitReaction', {
			Event = "OnCalcAPCost",
			Handler = function (self, target, current_ap, action, weapon, aim)
				if IsKindOfClasses(weapon, "MeleeWeapon", "Grenade") and action.ActionType == "Ranged Attack" then
					local costReduction = CharacterEffectDefs.Throwing:ResolveValue("FirstThrowCostReduction") * const.Scale.AP
					return Max(1 * const.Scale.AP, current_ap - costReduction)
				end
			end,
		}),
	},
	DisplayName = T(140998054787, --[[CharacterEffectCompositeDef FirstThrow DisplayName]] "First Throw"),
	Description = T(547228026943, --[[CharacterEffectCompositeDef FirstThrow Description]] "Reduced cost of the first throw."),
}

