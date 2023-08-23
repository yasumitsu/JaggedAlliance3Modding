-- ========== GENERATED BY InventoryItemCompositeDef Editor (Ctrl-Alt-Y) DO NOT EDIT MANUALLY! ==========

UndefineClass('FirstAidKit')
DefineClass.FirstAidKit = {
	__parents = { "Medicine" },
	__generated_by_class = "InventoryItemCompositeDef",


	object_class = "Medicine",
	Repairable = false,
	ScrapParts = 1,
	Icon = "UI/Icons/Items/first_aid_kit",
	DisplayName = T(905136649471, --[[InventoryItemCompositeDef FirstAidKit DisplayName]] "First Aid Kit"),
	DisplayNamePlural = T(941665857371, --[[InventoryItemCompositeDef FirstAidKit DisplayNamePlural]] "First Aid Kits"),
	AdditionalHint = T(735742619435, --[[InventoryItemCompositeDef FirstAidKit AdditionalHint]] "<bullet_point> Restores lost HP and stabilizes dying characters\n<bullet_point> Required to use Bandage\n<bullet_point> Loses Condition after each use but can be refilled with Meds\n<bullet_point> Used automatically from the Inventory"),
	UnitStat = "Medical",
	max_meds_parts = 8,
}

