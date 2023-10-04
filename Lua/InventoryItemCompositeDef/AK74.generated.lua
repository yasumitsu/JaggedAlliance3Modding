-- ========== GENERATED BY InventoryItemCompositeDef Editor (Ctrl-Alt-Y) DO NOT EDIT MANUALLY! ==========

UndefineClass('AK74')
DefineClass.AK74 = {
	__parents = { "AssaultRifle" },
	__generated_by_class = "InventoryItemCompositeDef",


	object_class = "AssaultRifle",
	ScrapParts = 10,
	RepairCost = 20,
	Reliability = 95,
	Icon = "UI/Icons/Weapons/AK74",
	DisplayName = T(666934296336, --[[InventoryItemCompositeDef AK74 DisplayName]] "AK-74"),
	DisplayNamePlural = T(604670724884, --[[InventoryItemCompositeDef AK74 DisplayNamePlural]] "AK-74s"),
	Description = T(790591991065, --[[InventoryItemCompositeDef AK74 Description]] "The Soviets revisited their emblematic design around 1974 and this beauty was born. It has sprouted many variations but keeps the long stroke gas piston system of the original design."),
	AdditionalHint = T(193194644504, --[[InventoryItemCompositeDef AK74 AdditionalHint]] "<bullet_point> High damage\n<bullet_point> Improved armor penetration\n<bullet_point> Slower Condition loss"),
	LargeItem = 1,
	UnitStat = "Marksmanship",
	Valuable = 1,
	Cost = 4000,
	Caliber = "762WP",
	Damage = 30,
	MagazineSize = 30,
	PenetrationClass = 3,
	WeaponRange = 24,
	OverwatchAngle = 1440,
	HandSlot = "TwoHanded",
	Entity = "Weapon_AK74",
	ComponentSlots = {
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Stock",
			'AvailableComponents', {
				"StockHeavy",
				"StockLight",
			},
			'DefaultComponent', "StockHeavy",
		}),
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Magazine",
			'AvailableComponents', {
				"MagNormalFine",
				"MagLarge",
				"MagLargeFine",
				"MagQuick",
			},
			'DefaultComponent', "MagNormalFine",
		}),
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Scope",
			'CanBeEmpty', true,
			'AvailableComponents', {
				"LROptics",
				"LROpticsAdvanced",
				"ReflexSight",
				"ReflexSightAdvanced",
				"ScopeCOG",
				"ScopeCOGQuick",
				"ThermalScope",
			},
		}),
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Muzzle",
			'CanBeEmpty', true,
			'AvailableComponents', {
				"Compensator",
				"MuzzleBooster",
				"ImprovisedSuppressor",
				"Suppressor",
			},
		}),
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Under",
			'CanBeEmpty', true,
			'AvailableComponents', {
				"GrenadeLauncher",
				"Bipod_Under",
			},
		}),
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Side",
			'CanBeEmpty', true,
			'AvailableComponents', {
				"Flashlight",
				"FlashlightDot",
				"LaserDot",
			},
		}),
	},
	HolsterSlot = "Shoulder",
	AvailableAttacks = {
		"BurstFire",
		"AutoFire",
		"SingleShot",
		"CancelShot",
	},
	ShootAP = 6000,
	ReloadAP = 3000,
}

