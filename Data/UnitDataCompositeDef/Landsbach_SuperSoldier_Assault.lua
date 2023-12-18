-- ========== GENERATED BY UnitDataCompositeDef Editor (Ctrl-Alt-M) DO NOT EDIT MANUALLY! ==========

PlaceObj('UnitDataCompositeDef', {
	'Group', "Other Combatants",
	'Id', "Landsbach_SuperSoldier_Assault",
	'object_class', "UnitData",
	'Health', 75,
	'Agility', 75,
	'Dexterity', 75,
	'Strength', 85,
	'Wisdom', 56,
	'Leadership', 50,
	'Marksmanship', 84,
	'Mechanical', 50,
	'Explosives', 39,
	'Medical', 52,
	'Portrait', "UI/EnemiesPortraits/ArmyHeavy",
	'Name', T(242481798231, --[[UnitDataCompositeDef Landsbach_SuperSoldier_Assault Name]] "Siegfried's Guard"),
	'Randomization', true,
	'Affiliation', "SuperSoldiers",
	'StartingLevel', 6,
	'neutral_retaliate', true,
	'AIKeywords', {
		"Control",
	},
	'role', "Soldier",
	'MaxAttacks', 2,
	'PickCustomArchetype', function (self, proto_context)  end,
	'MaxHitPoints', 50,
	'StartingPerks', {
		"AutoWeapons",
		"Berserker",
		"HoldPosition",
		"DieselPerk",
	},
	'AppearancesList', {
		PlaceObj('AppearanceWeight', {
			'Preset', "Landsbach_SuperSoldier_Assault",
		}),
	},
	'Equipment', {
		"Landsbach_SuperSoldier_Assault",
	},
	'AdditionalGroups', {},
	'Tier', "Elite",
	'pollyvoice', "Joey",
	'gender', "Male",
	'VoiceResponseId', "SuperSoldier_Assault",
})

