-- ========== GENERATED BY ExtrasGen Editor (Ctrl-Alt-G) DO NOT EDIT MANUALLY! ==========

rawset(_G, 'ExtrasGenPrgs', rawget(_G, 'ExtrasGenPrgs') or {})
---
--- Generates a colonial light pattern in the editor.
---
--- @param seed number|nil The seed to use for the random number generator. If not provided, a random seed will be used.
--- @param initial_selection table|nil The initial selection to use as a starting point. If not provided, the current selection will be used.
---
--- This function generates a colonial light pattern in the editor by calling various helper functions to create the pattern. It uses a random number generator seeded with the provided seed (or a random seed if none is provided) to generate the pattern. The initial selection can also be provided to use as a starting point for the pattern.
ExtrasGenPrgs.ColonialLight = function(seed, initial_selection)
	local li = { id = "ColonialLight" }
	initial_selection = initial_selection or editor.GetSel()
	local rand = BraidRandomCreate(seed or AsyncRand())
	prgdbg(li, 1, 1) sprocall(ExtrasGenPrgs.BottomOutwards, rand(), nil)
	prgdbg(li, 1, 2) sprocall(ExtrasGenPrgs.LayColonialFrieze, rand(), nil)
	prgdbg(li, 1, 3) sprocall(ExtrasGenPrgs.MoveUp, rand(), nil)
	prgdbg(li, 1, 4) sprocall(ExtrasGenPrgs.MoveUp, rand(), nil)
	prgdbg(li, 1, 5) sprocall(ExtrasGenPrgs.MoveUp, rand(), nil)
	prgdbg(li, 1, 6) sprocall(ExtrasGenPrgs.MoveUp, rand(), nil)
	prgdbg(li, 1, 7) sprocall(ExtrasGenPrgs.LayColonialFrieze, rand(), nil)
	prgdbg(li, 1, 8) sprocall(ExtrasGenPrgs.MoveUp, rand(), nil)
	prgdbg(li, 1, 9) sprocall(ExtrasGenPrgs.LayColonialFrieze, rand(), nil)
	prgdbg(li, 1, 10) sprocall(ExtrasGenPrgs.WallEdges, rand(), initial_selection)
	prgdbg(li, 1, 11) sprocall(ExtrasGenPrgs.LayColonialEdge_04_Light, rand(), nil)
	prgdbg(li, 1, 12) local guides = editor.GetSel()
	prgdbg(li, 1, 13) sprocall(MoveSizeGuides.Exec, MoveSizeGuides, guides, "m", 0, "m", 500, "m", 0, false)
	prgdbg(li, 1, 14) sprocall(ExtrasGenPrgs.LayColonialWallColumn_03, rand(), nil)
	prgdbg(li, 1, 15) sprocall(ExtrasGenPrgs.WallEdgesRightToLeft, rand(), initial_selection)
	prgdbg(li, 1, 16) guides = editor.GetSel()
	prgdbg(li, 1, 17) sprocall(MoveSizeGuides.Exec, MoveSizeGuides, guides, "m", 0, "m", 500, "m", 0, false)
	prgdbg(li, 1, 18) sprocall(ExtrasGenPrgs.LayColonialWallColumn_03, rand(), nil)
	prgdbg(li, 1, 19) sprocall(ExtrasGenPrgs.DeleteGuides, rand(), initial_selection)
end