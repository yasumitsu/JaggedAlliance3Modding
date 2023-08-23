-- ========== GENERATED BY InventoryItemCompositeDef Editor (Ctrl-Alt-Y) DO NOT EDIT MANUALLY! ==========

UndefineClass('SkillMag_Agility')
DefineClass.SkillMag_Agility = {
	__parents = { "MiscItem" },
	__generated_by_class = "InventoryItemCompositeDef",


	object_class = "MiscItem",
	Repairable = false,
	Icon = "UI/Icons/Items/mag_parkour",
	DisplayName = T(429725650602, --[[InventoryItemCompositeDef SkillMag_Agility DisplayName]] "Parkour!"),
	DisplayNamePlural = T(183969949257, --[[InventoryItemCompositeDef SkillMag_Agility DisplayNamePlural]] "Parkour!"),
	Description = T(372542479188, --[[InventoryItemCompositeDef SkillMag_Agility Description]] '"I\'m almost certain one does not shout <em>Parkour<em>."'),
	AdditionalHint = T(643572633528, --[[InventoryItemCompositeDef SkillMag_Agility AdditionalHint]] "<bullet_point> Used through the Item Menu\n<bullet_point> Single use\n<bullet_point> Increases Agility"),
	UnitStat = "Agility",
	is_valuable = true,
	effect_moment = "on_use",
	Effects = {
		PlaceObj('UnitStatBoost', {
			Amount = 1,
			Stat = "Agility",
		}),
	},
	action_name = T(966696056779, --[[InventoryItemCompositeDef SkillMag_Agility action_name]] "READ"),
	destroy_item = true,
}

