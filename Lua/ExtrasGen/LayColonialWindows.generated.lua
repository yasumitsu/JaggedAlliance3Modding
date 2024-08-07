-- ========== GENERATED BY ExtrasGen Editor (Ctrl-Alt-G) DO NOT EDIT MANUALLY! ==========

rawset(_G, 'ExtrasGenPrgs', rawget(_G, 'ExtrasGenPrgs') or {})
---
--- Generates a colonial window layout based on the provided seed and initial selection.
---
--- @param seed number|nil The seed to use for the random number generator. If not provided, a random seed will be used.
--- @param initial_selection table|nil The initial selection to use as the starting point for the layout. If not provided, the current editor selection will be used.
---
ExtrasGenPrgs.LayColonialWindows = function(seed, initial_selection)
	local li = { id = "LayColonialWindows" }
	initial_selection = initial_selection or editor.GetSel()
	local rand = BraidRandomCreate(seed or AsyncRand())
	prgdbg(li, 1, 1) sprocall(LaySlabsAlongGuides.Exec, LaySlabsAlongGuides, rand, initial_selection, nil, true, true, true, 1, true, 1, 1, 1, true, true, {PlaceObj('PlaceObjectData', {EditorClass = "WindowBig_Colonial_Single_01",}),}, false, {PlaceObj('PlaceObjectData', {EditorClass = "WindowBig_Colonial_Double_01",}),}, {PlaceObj('PlaceObjectData', {EditorClass = "WindowBig_Colonial_Single_01",}),}, false, false, false, false, false, 0, 0, false, false)
	prgdbg(li, 1, 2) sprocall(MoveSizeGuides.Exec, MoveSizeGuides, initial_selection, 700, 1400, "m", 0, "m", 0, false)
	prgdbg(li, 1, 3) sprocall(LaySlabsAlongGuides.Exec, LaySlabsAlongGuides, rand, initial_selection, nil, true, true, true, 0, true, 1, 0, 0, true, false, {PlaceObj('PlaceObjectData', {EditorClass = "WallDec_Colonial_Frieze_Corner_01",}),}, false, {PlaceObj('PlaceObjectData', {EditorClass = "WallDec_Colonial_Frieze_Body_01",}),}, false, false, true, true, false, false, 0, 0, false, false)
	prgdbg(li, 1, 4) sprocall(MoveSizeGuides.Exec, MoveSizeGuides, initial_selection, 700, -1400, "m", 0, "m", 0, false)
end