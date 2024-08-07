-- ========== GENERATED BY ExtrasGen Editor (Ctrl-Alt-G) DO NOT EDIT MANUALLY! ==========

rawset(_G, 'ExtrasGenPrgs', rawget(_G, 'ExtrasGenPrgs') or {})
---
--- Generates a random seed and executes the `MoveSizeGuides.Exec` function with the given initial selection.
---
--- @param seed number|nil The seed to use for the random number generator. If not provided, a random seed will be used.
--- @param initial_selection table|nil The initial selection to pass to `MoveSizeGuides.Exec`. If not provided, the current editor selection will be used.
---
ExtrasGenPrgs.LengthUp = function(seed, initial_selection)
	local li = { id = "LengthUp" }
	initial_selection = initial_selection or editor.GetSel()
	local rand = BraidRandomCreate(seed or AsyncRand())
	prgdbg(li, 1, 1) sprocall(MoveSizeGuides.Exec, MoveSizeGuides, initial_selection, "m", 0, "m", 0, 1, 1, true)
end