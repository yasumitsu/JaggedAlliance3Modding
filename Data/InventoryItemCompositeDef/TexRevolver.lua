-- ========== GENERATED BY InventoryItemCompositeDef Editor (Ctrl-Alt-Y) DO NOT EDIT MANUALLY! ==========

PlaceObj('InventoryItemCompositeDef', {
	'Group', "Firearm - Handgun",
	'Id', "TexRevolver",
	'Comment', "tier 5, unique",
	'object_class', "Revolver",
	'ScrapParts', 8,
	'RepairCost', 50,
	'Reliability', 95,
	'Icon', "UI/Icons/Weapons/TexRevolver",
	'DisplayName', T(520238058822, --[[InventoryItemCompositeDef TexRevolver DisplayName]] "Custom Six-Shooter"),
	'DisplayNamePlural', T(463004632034, --[[InventoryItemCompositeDef TexRevolver DisplayNamePlural]] "Custom Six-Shooters"),
	'Description', T(349928663403, --[[InventoryItemCompositeDef TexRevolver Description]] "A custom-built revolver with a 10-inch barrel and ivory handle featuring TEX engraved in a 14K gold."),
	'AdditionalHint', T(838916530388, --[[InventoryItemCompositeDef TexRevolver AdditionalHint]] "<bullet_point> High Crit chance\n<bullet_point> Increased bonus from Aiming\n<bullet_point> Slower Condition loss"),
	'UnitStat', "Marksmanship",
	'Cost', 2000,
	'locked', true,
	'Caliber', "44CAL",
	'Damage', 17,
	'AimAccuracy', 5,
	'CritChanceScaled', 30,
	'MagazineSize', 6,
	'PointBlankBonus', 1,
	'OverwatchAngle', 2160,
	'Entity', "Weapon_Colt",
	'ComponentSlots', {
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Barrel",
			'Modifiable', false,
			'AvailableComponents', {
				"BarrelNormal",
			},
			'DefaultComponent', "BarrelNormal",
		}),
	},
	'HolsterSlot', "Leg",
	'AvailableAttacks', {
		"SingleShot",
		"DualShot",
		"CancelShot",
		"MobileShot",
	},
	'ShootAP', 5000,
	'ReloadAP', 3000,
})

