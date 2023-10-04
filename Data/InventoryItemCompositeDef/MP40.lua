-- ========== GENERATED BY InventoryItemCompositeDef Editor (Ctrl-Alt-Y) DO NOT EDIT MANUALLY! ==========

PlaceObj('InventoryItemCompositeDef', {
	'Group', "Firearm - SMG",
	'Id', "MP40",
	'Comment', "tier 1",
	'object_class', "SubmachineGun",
	'ScrapParts', 6,
	'Reliability', 70,
	'Icon', "UI/Icons/Weapons/MP40",
	'DisplayName', T(623210280984, --[[InventoryItemCompositeDef MP40 DisplayName]] "MP40"),
	'DisplayNamePlural', T(925856619983, --[[InventoryItemCompositeDef MP40 DisplayNamePlural]] "MP40s"),
	'Description', T(107317552821, --[[InventoryItemCompositeDef MP40 Description]] "Initially designed for vehicle crews and paratroopers, It really became widely used when the brutal urban combat of the Eastern front showed the value of a reliable submachine gun. "),
	'AdditionalHint', T(396615593162, --[[InventoryItemCompositeDef MP40 AdditionalHint]] "<bullet_point> Decreased bonus from Aiming"),
	'LargeItem', 1,
	'UnitStat', "Marksmanship",
	'Cost', 800,
	'Caliber', "9mm",
	'Damage', 14,
	'MagazineSize', 40,
	'PointBlankBonus', 1,
	'OverwatchAngle', 1440,
	'Noise', 15,
	'HandSlot', "TwoHanded",
	'Entity', "Weapon_MP40",
	'ComponentSlots', {
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Magazine",
			'AvailableComponents', {
				"MagNormal",
				"MagLarge",
			},
			'DefaultComponent', "MagNormal",
		}),
	},
	'HolsterSlot', "Shoulder",
	'AvailableAttacks', {
		"BurstFire",
		"AutoFire",
		"SingleShot",
		"RunAndGun",
		"CancelShot",
	},
	'ShootAP', 5000,
	'ReloadAP', 3000,
})

