-- ========== GENERATED BY InventoryItemCompositeDef Editor (Ctrl-Alt-Y) DO NOT EDIT MANUALLY! ==========

PlaceObj('InventoryItemCompositeDef', {
	'Group', "Ammo",
	'Id', "_12gauge_Flechette",
	'object_class', "Ammo",
	'Icon', "UI/Icons/Items/12_gauge_bullets_flechette",
	'DisplayName', T(812367261617, --[[InventoryItemCompositeDef _12gauge_Flechette DisplayName]] "12-gauge Sabot"),
	'DisplayNamePlural', T(125497062275, --[[InventoryItemCompositeDef _12gauge_Flechette DisplayNamePlural]] "12-gauge Sabot"),
	'colorStyle', "AmmoMatchColor",
	'Description', T(732291740225, --[[InventoryItemCompositeDef _12gauge_Flechette Description]] "12-gauge ammo for Shotguns."),
	'AdditionalHint', T(114102212532, --[[InventoryItemCompositeDef _12gauge_Flechette AdditionalHint]] "<bullet_point> Longer range\n<bullet_point> Narrow attack cone\n<bullet_point> Inflicts <em>Bleeding</em>"),
	'Cost', 100,
	'CanAppearInShop', true,
	'Tier', 3,
	'MaxStock', 5,
	'RestockWeight', 80,
	'ShopStackSize', 12,
	'MaxStacks', 500,
	'Caliber', "12gauge",
	'Modifications', {
		PlaceObj('CaliberModification', {
			mod_mul = 500,
			target_prop = "BuckshotConeAngle",
		}),
		PlaceObj('CaliberModification', {
			mod_mul = 500,
			target_prop = "OverwatchAngle",
		}),
		PlaceObj('CaliberModification', {
			mod_add = 4,
			target_prop = "WeaponRange",
		}),
	},
	'AppliedEffects', {
		"Bleeding",
	},
	'ammo_type_icon', "UI/Icons/Items/ta_subsonic.png",
})

