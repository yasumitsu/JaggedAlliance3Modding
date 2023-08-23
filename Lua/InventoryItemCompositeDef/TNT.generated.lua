-- ========== GENERATED BY InventoryItemCompositeDef Editor (Ctrl-Alt-Y) DO NOT EDIT MANUALLY! ==========

UndefineClass('TNT')
DefineClass.TNT = {
	__parents = { "ExplosiveSubstance" },
	__generated_by_class = "InventoryItemCompositeDef",


	object_class = "ExplosiveSubstance",
	Repairable = false,
	Icon = "UI/Icons/Items/tnt",
	DisplayName = T(617720797508, --[[InventoryItemCompositeDef TNT DisplayName]] "TNT"),
	DisplayNamePlural = T(598565600988, --[[InventoryItemCompositeDef TNT DisplayNamePlural]] "TNT"),
	Description = T(822428525866, --[[InventoryItemCompositeDef TNT Description]] "The go-to tool of railroad builders and Wild West moustache villains, the TNT is easy to find, use and abuse."),
	AdditionalHint = T(489366347733, --[[InventoryItemCompositeDef TNT AdditionalHint]] "<bullet_point> Combine with a Detonator type to create an Explosive\n<bullet_point> Larger blast area"),
	UnitStat = "Explosives",
	CenterUnitDamageMod = 130,
	CenterObjDamageMod = 300,
	AreaOfEffect = 5,
	AreaObjDamageMod = 300,
	PenetrationClass = 4,
	DeathType = "BlowUp",
	BaseDamage = 35,
	Noise = 30,
}

