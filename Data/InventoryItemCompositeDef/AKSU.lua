-- ========== GENERATED BY InventoryItemCompositeDef Editor (Ctrl-Alt-Y) DO NOT EDIT MANUALLY! ==========

PlaceObj('InventoryItemCompositeDef', {
	'Group', "Firearm - SMG",
	'Id', "AKSU",
	'Comment', "tier 4",
	'object_class', "SubmachineGun",
	'ScrapParts', 10,
	'RepairCost', 50,
	'Reliability', 80,
	'Icon', "UI/Icons/Weapons/AKSU",
	'DisplayName', T(128744593633, --[[InventoryItemCompositeDef AKSU DisplayName]] "AK-SU"),
	'DisplayNamePlural', T(897934363658, --[[InventoryItemCompositeDef AKSU DisplayNamePlural]] "AK-SUs"),
	'Description', T(371210514910, --[[InventoryItemCompositeDef AKSU Description]] "Short versions of the AK-74 intended for Spec Ops and vehicle crew personal defense. It needed a custom gas block and muzzle booster to work properly. Americans call it Krinkov but Russians have a more intimate nickname - Ksyukha or sometimes Suchka. And yes, there is a thigh holster for it. "),
	'AdditionalHint', T(293511122593, --[[InventoryItemCompositeDef AKSU AdditionalHint]] "<bullet_point> High damage"),
	'LargeItem', 1,
	'UnitStat', "Marksmanship",
	'Valuable', 1,
	'Cost', 2250,
	'Caliber', "762WP",
	'Damage', 20,
	'CritChanceScaled', 20,
	'MagazineSize', 30,
	'PenetrationClass', 2,
	'PointBlankBonus', 1,
	'OverwatchAngle', 1440,
	'Noise', 15,
	'HandSlot', "TwoHanded",
	'Entity', "Weapon_AKS74U",
	'ComponentSlots', {
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Barrel",
			'Modifiable', false,
			'AvailableComponents', {
				"BarrelNormal",
			},
			'DefaultComponent', "BarrelNormal",
		}),
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Handguard",
			'AvailableComponents', {
				"AKSU_Hanguard_Basic",
				"AKSU_VerticalGrip",
			},
			'DefaultComponent', "AKSU_Hanguard_Basic",
		}),
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Magazine",
			'AvailableComponents', {
				"MagNormal",
				"MagNormalFine",
				"MagLarge",
				"MagQuick",
				"MagLargeFine",
			},
			'DefaultComponent', "MagNormal",
		}),
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Side",
			'CanBeEmpty', true,
			'AvailableComponents', {
				"Flashlight",
				"LaserDot",
				"FlashlightDot",
				"UVDot",
			},
		}),
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Scope",
			'CanBeEmpty', true,
			'AvailableComponents', {
				"LROptics",
				"ReflexSight",
				"ReflexSightAdvanced",
				"ScopeCOG",
				"ScopeCOGQuick",
				"ThermalScope",
			},
		}),
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Muzzle",
			'AvailableComponents', {
				"Compensator",
				"MuzzleBooster",
				"Suppressor",
				"ImprovisedSuppressor",
			},
			'DefaultComponent', "MuzzleBooster",
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

