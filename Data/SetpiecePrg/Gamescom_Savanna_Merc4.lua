-- ========== GENERATED BY SetpiecePrg Editor (Ctrl-Alt-S) DO NOT EDIT MANUALLY! ==========

PlaceObj('SetpiecePrg', {
	Map = "Gamescom_Savanna",
	Params = {
		"MainActor",
	},
	StopMercMovement = false,
	TakePlayerControl = false,
	group = "TrailersSubSetPieces",
	id = "Gamescom_Savanna_Merc4",
	PlaceObj('SetpieceSetStance', {
		Actors = "MainActor",
		Weapon = "HiPower",
	}),
	PlaceObj('SetpieceAnimation', {
		Actors = "MainActor",
		AnimSpeed = 950,
		Animation = "hg_Standing_Walk2",
		AssignTo = "SP_Actor1_GoTo",
		Duration = 8450,
		Marker = "SP_Actor4_GoTo",
	}),
	PlaceObj('SetpieceAnimation', {
		Actors = "MainActor",
		Animation = "hg_Standing_IdlePassive3",
	}),
})

