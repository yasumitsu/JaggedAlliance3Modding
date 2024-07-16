-- ========== GENERATED BY ExtrasGen Editor (Ctrl-Alt-G) DO NOT EDIT MANUALLY! ==========

rawset(_G, 'ExtrasGenPrgs', rawget(_G, 'ExtrasGenPrgs') or {})
---
--- Generates vegetation objects along guides in the current selection.
---
--- @param seed number|nil The random seed to use for generating the vegetation. If not provided, a random seed will be used.
--- @param initial_selection table|nil The initial selection to use for generating the vegetation. If not provided, the current editor selection will be used.
---
--- @return nil
---
ExtrasGenPrgs.LayVegetation = function(seed, initial_selection)
	local li = { id = "LayVegetation" }
	initial_selection = initial_selection or editor.GetSel()
	local rand = BraidRandomCreate(seed or AsyncRand())
	prgdbg(li, 1, 1) sprocall(LayObjectsAlongGuides.Exec, LayObjectsAlongGuides, rand, initial_selection, nil, 0, 350, 5400, 0, true, {PlaceObj('PlaceObjectData', {EditorClass = "BunkerInterior_AmmoBox_02",}),}, {PlaceObj('PlaceObjectData', {EditorClass = "TropicalPlant_06_Tree_01",}),}, {PlaceObj('PlaceObjectData', {EditorClass = "TreeAttach_02",}),}, {PlaceObj('PlaceObjectData', {EditorClass = "BunkerInterior_AmmoBox_02",}),})
end