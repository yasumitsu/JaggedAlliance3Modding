-- ========== GENERATED BY ExtrasGen Editor (Ctrl-Alt-G) DO NOT EDIT MANUALLY! ==========

rawset(_G, 'ExtrasGenPrgs', rawget(_G, 'ExtrasGenPrgs') or {})
---
--- Moves the current selection down by 700 pixels.
---
--- @param seed number|nil The seed to use for the random number generator. If not provided, a random seed will be used.
--- @param initial_selection table|nil The initial selection to use. If not provided, the current editor selection will be used.
---
ExtrasGenPrgs.MoveDown = function(seed, initial_selection)
	local li = { id = "MoveDown" }
	initial_selection = initial_selection or editor.GetSel()
	local rand = BraidRandomCreate(seed or AsyncRand())
	prgdbg(li, 1, 1) sprocall(MoveSizeGuides.Exec, MoveSizeGuides, initial_selection, 700, -700, "m", 0, "m", 0, true)
end