-- ========== GENERATED BY ExtrasGen Editor (Ctrl-Alt-G) DO NOT EDIT MANUALLY! ==========

rawset(_G, 'ExtrasGenPrgs', rawget(_G, 'ExtrasGenPrgs') or {})
---
--- Generates a set of room guides that are placed inwards from the walls of the initial selection.
---
--- @param seed number|nil The seed to use for the random number generator. If not provided, a random seed will be used.
--- @param initial_selection table|nil The initial selection to use as the starting point for the room guides. If not provided, the current editor selection will be used.
--- @return table The generated room guides.
---
ExtrasGenPrgs.TopInwards = function(seed, initial_selection)
	local li = { id = "TopInwards" }
	initial_selection = initial_selection or editor.GetSel()
	local rand = BraidRandomCreate(seed or AsyncRand())
	local _, guides
	prgdbg(li, 1, 1) _, guides = sprocall(PlaceRoomGuides.Exec, PlaceRoomGuides, initial_selection, guides, "Wall interior", true, true, true, true, true, true, "Top", 1, 0, 0, "Inwards (room)")
	prgdbg(li, 1, 2) sprocall(SelectInEditor.Exec, SelectInEditor, guides, true, true)
end