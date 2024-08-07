-- ========== GENERATED BY ExtrasGen Editor (Ctrl-Alt-G) DO NOT EDIT MANUALLY! ==========

rawset(_G, 'ExtrasGenPrgs', rawget(_G, 'ExtrasGenPrgs') or {})
---
--- Generates wall edge guides for a room based on a seed value and an initial selection.
---
--- @param seed number|nil The seed value to use for the random number generator. If not provided, a random seed will be used.
--- @param initial_selection table|nil The initial selection to use for the room guides. If not provided, the current editor selection will be used.
--- @return table The generated wall edge guides.
---
ExtrasGenPrgs.WallEdges = function(seed, initial_selection)
	local li = { id = "WallEdges" }
	initial_selection = initial_selection or editor.GetSel()
	local rand = BraidRandomCreate(seed or AsyncRand())
	local _, guides
	prgdbg(li, 1, 1) _, guides = sprocall(PlaceRoomGuides.Exec, PlaceRoomGuides, initial_selection, guides, "Wall exterior", true, true, true, true, true, false, "Left", 1, 0, 0, "Inwards (wall)")
	prgdbg(li, 1, 2) sprocall(SelectInEditor.Exec, SelectInEditor, guides, true, true)
end