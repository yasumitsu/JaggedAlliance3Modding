-- ========== GENERATED BY SetpiecePrg Editor (Ctrl-Alt-S) DO NOT EDIT MANUALLY! ==========

PlaceObj('SetpiecePrg', {
	Effects = {
		PlaceObj('QuestSetVariableBool', {
			Prop = "Given",
			QuestId = "Beast",
		}),
	},
	Map = "D-17 - Ille Morat",
	group = "IlleMorat",
	hidden_actors = false,
	id = "IlleMorat_FirstEnter",
	PlaceObj('SetpieceFadeOut', {
		FadeOutTime = 0,
	}),
	PlaceObj('SetpieceFadeIn', {
		FadeInDelay = 0,
		FadeInTime = 400,
		Wait = false,
	}),
	PlaceObj('SetpieceAssignFromGroup', {
		AssignTo = "Wlad",
		Group = "Wlad",
		Marker = "SP_Wlad",
	}),
	PlaceObj('SetpieceAssignFromGroup', {
		AssignTo = "LegionActor1",
		Group = "LegionActor1",
		Marker = "SP_LegionActor1Spawn",
	}),
	PlaceObj('SetpieceAssignFromGroup', {
		AssignTo = "LegionActor2",
		Group = "LegionActor2",
		Marker = "SP_LegionActor2Spawn",
	}),
	PlaceObj('PrgPlaySetpiece', {
		MainActor = function (self) return Wlad end,
		Prg = "IlleMorat_FE_Wlad",
		PrgClass = "SetpiecePrg",
		Wait = false,
	}),
	PlaceObj('PrgPlaySetpiece', {
		MainActor = function (self) return LegionActor1 end,
		Prg = "IlleMorat_FE_LegionActor1",
		PrgClass = "SetpiecePrg",
		Wait = false,
	}),
	PlaceObj('PrgPlaySetpiece', {
		MainActor = function (self) return LegionActor2 end,
		Prg = "IlleMorat_FE_LegionActor2",
		PrgClass = "SetpiecePrg",
		Wait = false,
	}),
	PlaceObj('PrgPlayEffect', {
		Checkpoint = "BanterDone",
		Effects = {
			PlaceObj('PlayBanterEffect', {
				Banters = {
					"IlleMoratMarauders_approach",
				},
				searchInMap = true,
				searchInMarker = false,
			}),
			PlaceObj('QuestSetVariableBool', {
				Prop = "Given",
				QuestId = "Beast",
			}),
		},
		Wait = false,
	}),
	PlaceObj('SetpieceCamera', {
		CamProps = {
			floor = 0,
		},
		CamType = "Tac",
		Checkpoint = "BanterDone",
		Duration = 8000,
		Easing = 0,
		LookAt1 = point(119573, 133100, 8358),
		LookAt2 = point(119573, 133100, 8358),
		Pos1 = point(107844, 122648, 19358),
		Pos2 = point(107844, 122648, 19358),
		Wait = false,
		Zoom = 1300,
	}),
	PlaceObj('SetpieceWaitCheckpoint', {
		WaitCheckpoint = "BanterDone",
	}),
	PlaceObj('PrgForceStopSetpiece', {}),
})

