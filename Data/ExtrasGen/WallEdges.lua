-- ========== GENERATED BY ExtrasGen Editor (Ctrl-Alt-G) DO NOT EDIT MANUALLY! ==========

PlaceObj('ExtrasGen', {
	RequiresClass = "Room",
	ToolbarSection = "Place Guides",
	group = "CreateGuides",
	id = "WallEdges",
	PlaceObj('PlaceRoomGuides', {
		AssignTo = "guides",
		Horizontal = false,
		RoomsVar = "initial_selection",
		StartFrom = "Left",
		UseParams = true,
	}),
	PlaceObj('SelectInEditor', {
		ObjectsVar = "guides",
	}),
})

