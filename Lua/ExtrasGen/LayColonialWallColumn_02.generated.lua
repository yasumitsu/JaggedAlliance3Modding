-- ========== GENERATED BY ExtrasGen Editor (Ctrl-Alt-G) DO NOT EDIT MANUALLY! ==========

rawset(_G, 'ExtrasGenPrgs', rawget(_G, 'ExtrasGenPrgs') or {})
---
--- Generates a colonial wall column with a bottom, body, and top section.
---
--- @param seed number|nil The random seed to use for generating the column.
--- @param initial_selection table|nil The initial selection to use for the column placement.
---
ExtrasGenPrgs.LayColonialWallColumn_02 = function(seed, initial_selection)
	local li = { id = "LayColonialWallColumn_02" }
	initial_selection = initial_selection or editor.GetSel()
	local rand = BraidRandomCreate(seed or AsyncRand())
	prgdbg(li, 1, 1) sprocall(LaySlabsAlongGuides.Exec, LaySlabsAlongGuides, rand, initial_selection, nil, false, true, true, 0, true, 1, 0, 0, true, true, {PlaceObj('PlaceObjectData', {EditorClass = "WallDec_Colonial_Column_Bottom_02",}),}, false, {PlaceObj('PlaceObjectData', {EditorClass = "WallDec_Colonial_Column_Body_02",}),}, {PlaceObj('PlaceObjectData', {EditorClass = "WallDec_Colonial_Column_Top_02",}),}, false, false, false, true, true, 0, 0, false, false)
end