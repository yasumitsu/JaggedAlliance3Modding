-- ========== GENERATED BY InventoryItemCompositeDef Editor (Ctrl-Alt-Y) DO NOT EDIT MANUALLY! ==========

PlaceObj('InventoryItemCompositeDef', {
	'Group', "Quest - Weapons",
	'Id', "LionRoar",
	'Comment', "quest loot",
	'object_class', "SubmachineGun",
	'ScrapParts', 10,
	'Reliability', 80,
	'Icon', "UI/Icons/Weapons/LionRoar",
	'DisplayName', T(755592839679, --[[InventoryItemCompositeDef LionRoar DisplayName]] "The Lion's Roar"),
	'DisplayNamePlural', T(357764743328, --[[InventoryItemCompositeDef LionRoar DisplayNamePlural]] "The Lion's Roar"),
	'Description', T(216467415261, --[[InventoryItemCompositeDef LionRoar Description]] "Imperialists cower before its voice!"),
	'AdditionalHint', T(251066241512, --[[InventoryItemCompositeDef LionRoar AdditionalHint]] "<bullet_point> OUR weapon\n<bullet_point> Shorter range\n<bullet_point> High Damage\n<bullet_point> Limited ammo capacity\n<bullet_point> Increased bonus from Aiming\n<bullet_point> Very noisy"),
	'Valuable', 1,
	'Cost', 3000,
	'Caliber', "9mm",
	'Damage', 22,
	'AimAccuracy', 8,
	'MagazineSize', 20,
	'PenetrationClass', 2,
	'WeaponRange', 16,
	'PointBlankBonus', 1,
	'OverwatchAngle', 1440,
	'Entity', "Weapon_Uzi_LionsRoar",
	'ComponentSlots', {
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Muzzle",
			'Modifiable', false,
			'AvailableComponents', {
				"Compensator_cosmetic",
			},
			'DefaultComponent', "Compensator_cosmetic",
		}),
	},
	'HolsterSlot', "Shoulder",
	'AvailableAttacks', {
		"BurstFire",
		"AutoFire",
		"SingleShot",
		"RunAndGun",
		"DualShot",
	},
	'ShootAP', 5000,
	'ReloadAP', 3000,
})

