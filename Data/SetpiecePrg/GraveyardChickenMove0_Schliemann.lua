-- ========== GENERATED BY SetpiecePrg Editor (Ctrl-Alt-S) DO NOT EDIT MANUALLY! ==========

PlaceObj('SetpiecePrg', {
	Map = "C-3 - Savanna",
	StopMercMovement = false,
	TakePlayerControl = false,
	group = "Savanna",
	id = "GraveyardChickenMove0_Schliemann",
	PlaceObj('SetpieceAssignFromGroup', {
		AssignTo = "Schliemann",
		Group = "chicken",
	}),
	PlaceObj('SetpieceSleep', {
		Time = 2000,
	}),
	PlaceObj('SetpieceGotoPosition', {
		Actors = "Schliemann",
		AssignTo = "chicken0",
		Marker = "chicken0",
		RandomizePhase = true,
		Wait = false,
	}),
})

