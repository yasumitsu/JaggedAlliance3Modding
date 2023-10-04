-- ========== GENERATED BY InventoryItemCompositeDef Editor (Ctrl-Alt-Y) DO NOT EDIT MANUALLY! ==========

UndefineClass('FlakVest_CeramicPlates')
DefineClass.FlakVest_CeramicPlates = {
	__parents = { "TransmutedArmor" },
	__generated_by_class = "InventoryItemCompositeDef",


	object_class = "TransmutedArmor",
	ScrapParts = 4,
	Degradation = 6,
	Icon = "UI/Icons/Items/flak_vest",
	SubIcon = "UI/Icons/Items/plates",
	DisplayName = T(204904790371, --[[InventoryItemCompositeDef FlakVest_CeramicPlates DisplayName]] "Flak Vest"),
	DisplayNamePlural = T(915485818265, --[[InventoryItemCompositeDef FlakVest_CeramicPlates DisplayNamePlural]] "Flak Vests"),
	AdditionalHint = T(512514284052, --[[InventoryItemCompositeDef FlakVest_CeramicPlates AdditionalHint]] "<bullet_point> Damage reduction improved by Ceramic Plates\n<bullet_point> The ceramic plates will break after taking <GameColorG><RevertConditionCounter></GameColorG> hits"),
	PenetrationClass = 2,
	DamageReduction = 40,
	AdditionalReduction = 20,
	ProtectedBodyParts = set( "Torso" ),
}

