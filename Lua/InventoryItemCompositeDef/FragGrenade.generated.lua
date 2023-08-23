-- ========== GENERATED BY InventoryItemCompositeDef Editor (Ctrl-Alt-Y) DO NOT EDIT MANUALLY! ==========

UndefineClass('FragGrenade')
DefineClass.FragGrenade = {
	__parents = { "Grenade" },
	__generated_by_class = "InventoryItemCompositeDef",


	object_class = "Grenade",
	Repairable = false,
	Reliability = 100,
	Icon = "UI/Icons/Weapons/Frag Grenade",
	ItemType = "Grenade",
	DisplayName = T(514986878899, --[[InventoryItemCompositeDef FragGrenade DisplayName]] "Stick Grenade"),
	DisplayNamePlural = T(492140816684, --[[InventoryItemCompositeDef FragGrenade DisplayNamePlural]] "Stick Grenades"),
	UnitStat = "Explosives",
	Cost = 1500,
	MinMishapChance = -2,
	MaxMishapChance = 18,
	MaxMishapRange = 6,
	CenterUnitDamageMod = 130,
	CenterObjDamageMod = 500,
	AreaOfEffect = 2,
	AreaObjDamageMod = 500,
	PenetrationClass = 4,
	DeathType = "BlowUp",
	Scatter = 4,
	BaseRange = 7,
	ThrowMaxRange = 17,
	CanBounce = false,
	Entity = "MilitaryCamp_Grenade_01",
	ActionIcon = "UI/Icons/Hud/frag_grenade",
}

