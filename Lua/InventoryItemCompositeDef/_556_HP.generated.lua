-- ========== GENERATED BY InventoryItemCompositeDef Editor (Ctrl-Alt-Y) DO NOT EDIT MANUALLY! ==========

UndefineClass('_556_HP')
DefineClass._556_HP = {
	__parents = { "Ammo" },
	__generated_by_class = "InventoryItemCompositeDef",


	object_class = "Ammo",
	Icon = "UI/Icons/Items/556_nato_bullets_hollow_point",
	DisplayName = T(359801302480, --[[InventoryItemCompositeDef _556_HP DisplayName]] "5.56 mm Hollow Point"),
	DisplayNamePlural = T(769486263588, --[[InventoryItemCompositeDef _556_HP DisplayNamePlural]] "5.56 mm Hollow Point"),
	colorStyle = "AmmoHPColor",
	Description = T(271563525530, --[[InventoryItemCompositeDef _556_HP Description]] "5.56 Ammo for Assault Rifles, SMGs, and Machine Guns."),
	AdditionalHint = T(333746477431, --[[InventoryItemCompositeDef _556_HP AdditionalHint]] "<bullet_point> No armor penetration\n<bullet_point> High Crit chance\n<bullet_point> Inflicts <em>Bleeding</em>"),
	MaxStacks = 500,
	Caliber = "556",
	Modifications = {
		PlaceObj('CaliberModification', {
			mod_add = 50,
			target_prop = "CritChance",
		}),
		PlaceObj('CaliberModification', {
			mod_add = -4,
			target_prop = "PenetrationClass",
		}),
	},
	AppliedEffects = {
		"Bleeding",
	},
}

