-- ========== GENERATED BY InventoryItemCompositeDef Editor (Ctrl-Alt-Y) DO NOT EDIT MANUALLY! ==========

UndefineClass('_50BMG_SLAP')
DefineClass._50BMG_SLAP = {
	__parents = { "Ammo" },
	__generated_by_class = "InventoryItemCompositeDef",


	object_class = "Ammo",
	Icon = "UI/Icons/Items/50bmg_slap",
	DisplayName = T(328537436087, --[[InventoryItemCompositeDef _50BMG_SLAP DisplayName]] ".50 SLAP"),
	DisplayNamePlural = T(152196917983, --[[InventoryItemCompositeDef _50BMG_SLAP DisplayNamePlural]] ".50 SLAP"),
	colorStyle = "AmmoAPColor",
	Description = T(189786149121, --[[InventoryItemCompositeDef _50BMG_SLAP Description]] ".50 Ammo for Machine Guns, Snipers and Handguns."),
	AdditionalHint = T(424614747022, --[[InventoryItemCompositeDef _50BMG_SLAP AdditionalHint]] "<bullet_point> Improved armor penetration\n<bullet_point> Slightly higher Crit chance"),
	Cost = 500,
	CanAppearInShop = true,
	Tier = 2,
	MaxStock = 5,
	RestockWeight = 25,
	CategoryPair = "50BMG",
	ShopStackSize = 10,
	MaxStacks = 500,
	Caliber = "50BMG",
	Modifications = {
		PlaceObj('CaliberModification', {
			mod_add = 1,
			target_prop = "PenetrationClass",
		}),
		PlaceObj('CaliberModification', {
			mod_add = 15,
			target_prop = "CritChance",
		}),
	},
	ammo_type_icon = "UI/Icons/Items/ta_hp.png",
}

