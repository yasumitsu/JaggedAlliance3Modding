-- ========== GENERATED BY SetpiecePrg Editor (Ctrl-Alt-S) DO NOT EDIT MANUALLY! ==========

rawset(_G, 'SetpiecePrgs', rawget(_G, 'SetpiecePrgs') or {})
SetpiecePrgs.GraveyardChickenMove2_Schliemann = function(seed, state, TriggerUnits)
	local li = { id = "GraveyardChickenMove2_Schliemann" }
	local rand = BraidRandomCreate(seed or AsyncRand())
	local _, Schliemann
	prgdbg(li, 1, 1) _, Schliemann = sprocall(SetpieceAssignFromGroup.Exec, SetpieceAssignFromGroup, state, rand, Schliemann, "", "chicken", "Object", false)
	prgdbg(li, 1, 2) sprocall(SetpieceSleep.Exec, SetpieceSleep, state, rand, true, "", 500)
	prgdbg(li, 1, 3) sprocall(SetpieceGotoPosition.Exec, SetpieceGotoPosition, state, rand, false, "", Schliemann, "chicken2", true, true, false, "", false, true, "", 1000)
end