-- ========== GENERATED BY SetpiecePrg Editor (Ctrl-Alt-S) DO NOT EDIT MANUALLY! ==========

PlaceObj('SetpiecePrg', {
	Comment = "Main Setpiece",
	Map = "J-11 - Jungle",
	StopMercMovement = false,
	TakePlayerControl = false,
	Visibility = "Player",
	group = "Savanna",
	id = "VoodooChickenMove2",
	PlaceObj('SetpieceAssignFromGroup', {
		AssignTo = "Schliemann",
		Group = "chicken",
	}),
	PlaceObj('SetpieceAssignFromGroup', {
		AssignTo = "LuckyVeinard",
		Group = "Veinard",
	}),
	PlaceObj('PrgPlaySetpiece', {
		Prg = "VoodooChickenMove2_Schliemann",
		PrgClass = "SetpiecePrg",
		Wait = false,
	}),
	PlaceObj('PrgPlaySetpiece', {
		Prg = "VoodooChickenMove2_Veinard",
		PrgClass = "SetpiecePrg",
		Wait = false,
	}),
})

