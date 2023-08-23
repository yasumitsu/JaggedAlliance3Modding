-- ========== GENERATED BY InventoryItemCompositeDef Editor (Ctrl-Alt-Y) DO NOT EDIT MANUALLY! ==========

UndefineClass('SkillMag_Explosives')
DefineClass.SkillMag_Explosives = {
	__parents = { "MiscItem" },
	__generated_by_class = "InventoryItemCompositeDef",


	object_class = "MiscItem",
	Repairable = false,
	Icon = "UI/Icons/Items/mag_the_red_wire",
	DisplayName = T(200077030182, --[[InventoryItemCompositeDef SkillMag_Explosives DisplayName]] "The Red Wire"),
	DisplayNamePlural = T(698234423645, --[[InventoryItemCompositeDef SkillMag_Explosives DisplayNamePlural]] "The Red Wire"),
	Description = T(267053043531, --[[InventoryItemCompositeDef SkillMag_Explosives Description]] "Recently blew up after several issues."),
	AdditionalHint = T(633118403037, --[[InventoryItemCompositeDef SkillMag_Explosives AdditionalHint]] "<bullet_point> Used through the Item Menu\n<bullet_point> Single use\n<bullet_point> Increases Explosives"),
	UnitStat = "Explosives",
	is_valuable = true,
	effect_moment = "on_use",
	Effects = {
		PlaceObj('UnitStatBoost', {
			Amount = 1,
			Stat = "Explosives",
		}),
	},
	action_name = T(259798743067, --[[InventoryItemCompositeDef SkillMag_Explosives action_name]] "READ"),
	destroy_item = true,
}

