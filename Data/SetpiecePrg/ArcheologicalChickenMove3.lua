-- ========== GENERATED BY SetpiecePrg Editor (Ctrl-Alt-S) DO NOT EDIT MANUALLY! ==========

PlaceObj('SetpiecePrg', {
	Comment = "Main Setpiece",
	Map = "E-14 - Archeological site",
	StopMercMovement = false,
	TakePlayerControl = false,
	Visibility = "Player",
	group = "Savanna",
	id = "ArcheologicalChickenMove3",
	PlaceObj('SetpieceAssignFromGroup', {
		AssignTo = "Schliemann",
		Group = "chicken",
	}),
	PlaceObj('SetpieceAssignFromGroup', {
		AssignTo = "LuckyVeinard",
		Group = "Veinard",
	}),
	PlaceObj('PrgPlaySetpiece', {
		Prg = "ArcheologicalChickenMove3_Schliemann",
		PrgClass = "SetpiecePrg",
		Wait = false,
	}),
	PlaceObj('PrgPlaySetpiece', {
		Prg = "ArcheologicalChickenMove3_Veinard",
		PrgClass = "SetpiecePrg",
		Wait = false,
	}),
})

