-- ========== GENERATED BY ExtrasGen Editor (Ctrl-Alt-G) DO NOT EDIT MANUALLY! ==========

rawset(_G, 'ExtrasGenPrgs', rawget(_G, 'ExtrasGenPrgs') or {})
ExtrasGenPrgs.TopDownInterior = function(seed, initial_selection)
	local li = { id = "TopDownInterior" }
	initial_selection = initial_selection or editor.GetSel()
	local rand = BraidRandomCreate(seed or AsyncRand())
	local _, guides
	prgdbg(li, 1, 1) _, guides = sprocall(PlaceRoomGuides.Exec, PlaceRoomGuides, initial_selection, guides, "Wall interior", true, true, true, true, true, true, "Top", 1, 0, 0, "Inwards (wall)")
	prgdbg(li, 1, 2) sprocall(SelectInEditor.Exec, SelectInEditor, guides, true, true)
end