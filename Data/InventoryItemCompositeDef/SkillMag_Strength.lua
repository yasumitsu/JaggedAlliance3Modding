-- ========== GENERATED BY InventoryItemCompositeDef Editor (Ctrl-Alt-Y) DO NOT EDIT MANUALLY! ==========

PlaceObj('InventoryItemCompositeDef', {
	'Group', "Magazines",
	'Id', "SkillMag_Strength",
	'object_class', "MiscItem",
	'Repairable', false,
	'Icon', "UI/Icons/Items/mag_flex_em",
	'DisplayName', T(949216271403, --[[InventoryItemCompositeDef SkillMag_Strength DisplayName]] "Flex 'em!"),
	'DisplayNamePlural', T(246425010309, --[[InventoryItemCompositeDef SkillMag_Strength DisplayNamePlural]] "Flex 'em!"),
	'Description', T(817037902641, --[[InventoryItemCompositeDef SkillMag_Strength Description]] "For bros who even lift."),
	'AdditionalHint', T(595702309304, --[[InventoryItemCompositeDef SkillMag_Strength AdditionalHint]] "<bullet_point> Used through the Item Menu\n<bullet_point> Single use\n<bullet_point> Increases Strength"),
	'UnitStat', "Strength",
	'Valuable', 1,
	'effect_moment', "on_use",
	'Effects', {
		PlaceObj('UnitStatBoost', {
			Amount = 1,
			Stat = "Strength",
		}),
	},
	'action_name', T(919614237926, --[[InventoryItemCompositeDef SkillMag_Strength action_name]] "READ"),
	'destroy_item', true,
})

