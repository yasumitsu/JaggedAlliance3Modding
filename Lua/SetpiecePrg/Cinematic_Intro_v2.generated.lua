-- ========== GENERATED BY SetpiecePrg Editor (Ctrl-Alt-S) DO NOT EDIT MANUALLY! ==========

rawset(_G, 'SetpiecePrgs', rawget(_G, 'SetpiecePrgs') or {})
SetpiecePrgs.Cinematic_Intro_v2 = function(seed, state, TriggerUnits)
	local li = { id = "Cinematic_Intro_v2" }
	local rand = BraidRandomCreate(seed or AsyncRand())
	prgdbg(li, 1, 1) sprocall(SetpieceCamera.Exec, SetpieceCamera, state, rand, false, "", "Tac", "", "", "linear", 0, false, false, point(152459, 165629, 8146), point(157365, 164926, 8810), false, false, 4200, 1000, false, 0, 0, 0, 0, 0, 0, "Default", 100)
	prgdbg(li, 1, 2) sprocall(SetpieceFadeIn.Exec, SetpieceFadeIn, state, rand, false, "", 0, 5000)
	prgdbg(li, 1, 3) sprocall(SetpieceCamera.Exec, SetpieceCamera, state, rand, true, "", "Max", "", "decelerated", "linear", 5000, false, false, point(152459, 165629, 8146), point(157365, 164926, 8810), point(154800, 166405, 8314), point(157365, 164926, 8810), 4200, 2000, false, 0, 0, 0, 0, 0, 0, "Default", 100)
	prgdbg(li, 1, 4) sprocall(SetpieceCamera.Exec, SetpieceCamera, state, rand, true, "", "Max", "", "decelerated", "linear", 12000, false, false, point(153093, 167389, 7984), point(157365, 164926, 8810), point(150791, 168591, 7278), point(153084, 167193, 8615), 4200, 2000, false, 0, 0, 0, 0, 0, 0, "Default", 100)
	prgdbg(li, 1, 5) sprocall(SetpieceCamera.Exec, SetpieceCamera, state, rand, true, "", "Max", "", "decelerated", "linear", 3000, false, false, point(149262, 169523, 6386), point(153084, 167193, 8615), point(150745, 168074, 6365), point(152703, 168031, 8637), 4200, 2000, false, 0, 0, 0, 0, 0, 0, "Default", 100)
	prgdbg(li, 1, 6) sprocall(SetpieceCameraFloat.Exec, SetpieceCameraFloat, state, rand, false, "", 0, 90000, "random", 5000, 30, false)
	prgdbg(li, 1, 11) sprocall(SetpieceVoice.Exec, SetpieceVoice, state, rand, true, "", "narrator", T(657833848133, --[[SetpiecePrg Cinematic_Intro_v2 Text voice:narrator]] "This is <em>Emma LaFontaine</em>. Thank you for agreeing to help me find my father. I don't have much time to talk. I've been told it's no longer safe for me here, so I'm preparing to leave."), 0, 0, 0, 1000, "Always")
	prgdbg(li, 1, 12) sprocall(SetpieceVoice.Exec, SetpieceVoice, state, rand, true, "", "narrator", T(843574394357, --[[SetpiecePrg Cinematic_Intro_v2 Text voice:narrator]] "I can't believe a city that only a few months ago was filled with joy and hope is now a place of fear and suspicion, but perhaps that tells you just how important <em>my father</em> is to this country."), 0, 0, 0, 1000, "Always")
	prgdbg(li, 1, 13) sprocall(SetpieceVoice.Exec, SetpieceVoice, state, rand, true, "", "narrator", T(273524094323, --[[SetpiecePrg Cinematic_Intro_v2 Text voice:narrator]] "You see, <em>Alphonse LaFontaine</em> is much more than just the <em>president</em> - he is the symbol of my people's faith in a brighter future for Grand Chien. Since his abduction, that faith has been shaken. "), 0, 0, 0, 1000, "Always")
	prgdbg(li, 1, 14) sprocall(SetpieceVoice.Exec, SetpieceVoice, state, rand, true, "", "narrator", T(882784467984, --[[SetpiecePrg Cinematic_Intro_v2 Text voice:narrator]] "Things like law and justice are fragile concepts here and the political enemies my father made are already calling for emergency powers to be invoked. I don't know if they are behind the kidnapping, but I am sure they are planning to take advantage of it. "), 0, 0, 0, 1000, "Always")
	prgdbg(li, 1, 15) sprocall(SetpieceVoice.Exec, SetpieceVoice, state, rand, true, "", "narrator", T(980617204308, --[[SetpiecePrg Cinematic_Intro_v2 Text voice:narrator]] 'The person who took my father calls himself "<em>the Major</em>." I haven\'t been able to find out who he really is, but everyone knows what he wants. He has demanded the entire Adjani River Valley be given to him.'), 0, 0, 0, 1000, "Always")
	prgdbg(li, 1, 16) sprocall(SetpieceVoice.Exec, SetpieceVoice, state, rand, true, "", "narrator", T(170466064841, --[[SetpiecePrg Cinematic_Intro_v2 Text voice:narrator]] "His followers, who call themselves the <em>Legion</em>, have already seized most of it, but he has vowed to execute my father should the government attempt to intervene."), 0, 0, 0, 1000, "Always")
	prgdbg(li, 1, 17) sprocall(SetpieceVoice.Exec, SetpieceVoice, state, rand, true, "", "narrator", T(243290865030, --[[SetpiecePrg Cinematic_Intro_v2 Text voice:narrator]] "I've wired the money you requested. Please, assemble your team and come meet me on <em>Ernie Island</em> at <em>Corazon Santiago's</em> villa. She is the <em>Adonis</em> representative I told you about in my email - her diamond mining operations can help with additional funding should you need it."), 0, 0, 0, 1000, "Always")
	prgdbg(li, 1, 18) sprocall(SetpieceVoice.Exec, SetpieceVoice, state, rand, true, "", "narrator", T(707093581147, --[[SetpiecePrg Cinematic_Intro_v2 Text voice:narrator]] "My car is here. I have to go.\nI'll have more details for you when we meet."), 0, 0, 0, 1000, "Always")
	prgdbg(li, 1, 19) sprocall(SetpieceCamera.Exec, SetpieceCamera, state, rand, true, "", "Max", "", "decelerated", "linear", 3000, false, false, point(149439, 168102, 4849), point(152703, 168031, 8637), point(151539, 168006, 5398), point(152184, 168006, 8330), 4200, 2000, false, 0, 0, 0, 0, 0, 0, "Default", 100)
	prgdbg(li, 1, 21) sprocall(SetpieceSleep.Exec, SetpieceSleep, state, rand, false, "", 2000)
	prgdbg(li, 1, 22) sprocall(SetpieceFadeOut.Exec, SetpieceFadeOut, state, rand, true, "", 1500)
end