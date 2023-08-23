-- ========== GENERATED BY SetpiecePrg Editor (Ctrl-Alt-S) DO NOT EDIT MANUALLY! ==========

PlaceObj('SetpiecePrg', {
	CameraMode = "Show all",
	Map = "_Cinematic_Intro",
	RecordFPS = 60,
	group = "Cinematic",
	hidden_actors = false,
	id = "Cinematic_Intro_Bake",
	PlaceObj('SetpieceCamera', {
		CamType = "Tac",
		DOFFar = 10000,
		DOFFarSpread = 1000,
		DOFNear = 4000,
		DOFNearSpread = 200,
		DOFStrengthFar = 100,
		DOFStrengthNear = 100,
		Duration = 0,
		FovX = 5000,
		LookAt1 = point(154871, 163825, 9736),
		Pos1 = point(156653, 161761, 10985),
		Wait = false,
		Zoom = 1000,
	}),
	PlaceObj('SetpieceFadeIn', {
		FadeInDelay = 0,
		FadeInTime = 1,
		Wait = false,
	}),
	PlaceObj('SetpieceCamera', {
		DOFFar = 10000,
		DOFFarSpread = 1000,
		DOFNear = 4000,
		DOFNearSpread = 20,
		DOFStrengthFar = 100,
		DOFStrengthNear = 100,
		Duration = 9000,
		Easing = 0,
		FovX = 5000,
		LookAt1 = point(155224, 164129, 9736),
		LookAt2 = point(155383, 164267, 9736),
		Movement = "decelerated",
		Pos1 = point(157006, 162065, 10985),
		Pos2 = point(157165, 162203, 10985),
		Zoom = 1000,
	}),
	PlaceObj('SetpieceFadeOut', {
		FadeOutTime = 600,
	}),
	PlaceObj('SetpieceFadeIn', {
		FadeInDelay = 0,
		FadeInTime = 400,
		Wait = false,
	}),
	PlaceObj('SetpieceCamera', {
		DOFNear = 3000,
		DOFNearSpread = 200,
		DOFStrengthNear = 100,
		Duration = 13000,
		LookAt1 = point(156038, 167908, 8547),
		LookAt2 = point(155486, 167934, 8458),
		Movement = "decelerated",
		Pos1 = point(158999, 167771, 9019),
		Pos2 = point(158447, 167797, 8930),
	}),
	PlaceObj('SetpieceVoice', {
		Actor = "narrator",
		Disable = true,
		Text = T(657833848133, --[[SetpiecePrg Cinematic_Intro_Bake Text voice:narrator]] "This is <em>Emma LaFontaine</em>. Thank you for agreeing to help me find my father. I don't have much time to talk. I've been told it's no longer safe for me here, so I'm preparing to leave."),
		TimeAdd = 1000,
		TimeBefore = 2000,
	}),
	PlaceObj('SetpieceFadeOut', {
		FadeOutTime = 400,
	}),
	PlaceObj('SetpieceFadeIn', {
		FadeInDelay = 0,
		FadeInTime = 100,
		Wait = false,
	}),
	PlaceObj('SetpieceCamera', {
		DOFFar = 4000,
		DOFFarSpread = 200,
		DOFStrengthFar = 70,
		Duration = 14000,
		FovX = 3200,
		LookAt1 = point(150604, 168278, 7558),
		LookAt2 = point(150583, 168035, 7558),
		Movement = "linear",
		Pos1 = point(153515, 168044, 8250),
		Pos2 = point(153495, 167804, 8250),
	}),
	PlaceObj('SetpieceVoice', {
		Actor = "narrator",
		Disable = true,
		Text = T(843574394357, --[[SetpiecePrg Cinematic_Intro_Bake Text voice:narrator]] "I can't believe a city that only a few months ago was filled with joy and hope is now a place of fear and suspicion, but perhaps that tells you just how important <em>my father</em> is to this country."),
		TimeAdd = 1000,
	}),
	PlaceObj('SetpieceFadeOut', {
		FadeOutTime = 300,
	}),
	PlaceObj('SetpieceFadeIn', {
		FadeInDelay = 0,
		FadeInTime = 100,
		Wait = false,
	}),
	PlaceObj('SetpieceCamera', {
		DOFFar = 760,
		DOFFarSpread = 200,
		DOFNear = 700,
		DOFNearSpread = 100,
		DOFStrengthFar = 100,
		DOFStrengthNear = 70,
		Duration = 16000,
		FovX = 3200,
		LookAt1 = point(150839, 168776, 5826),
		LookAt2 = point(150764, 168796, 5879),
		Movement = "linear",
		Pos1 = point(152478, 168348, 8304),
		Pos2 = point(152403, 168368, 8357),
	}),
	PlaceObj('SetpieceVoice', {
		Actor = "narrator",
		Disable = true,
		Text = T(273524094323, --[[SetpiecePrg Cinematic_Intro_Bake Text voice:narrator]] "You see, <em>Alphonse LaFontaine</em> is much more than just the <em>president</em> - he is the symbol of my people's faith in a brighter future for Grand Chien. Since his abduction, that faith has been shaken. "),
	}),
	PlaceObj('SetpieceFadeOut', {
		FadeOutTime = 300,
	}),
	PlaceObj('SetpieceFadeIn', {
		FadeInDelay = 0,
		FadeInTime = 100,
		Wait = false,
	}),
	PlaceObj('SetpieceCamera', {
		DOFFar = 800,
		DOFFarSpread = 200,
		DOFNear = 600,
		DOFNearSpread = 200,
		DOFStrengthFar = 100,
		DOFStrengthNear = 100,
		Duration = 19000,
		FovX = 3200,
		LookAt1 = point(150518, 168473, 6335),
		LookAt2 = point(150686, 168338, 6326),
		Movement = "linear",
		Pos1 = point(152353, 166993, 8191),
		Pos2 = point(152521, 166858, 8182),
	}),
	PlaceObj('SetpieceVoice', {
		Actor = "narrator",
		Disable = true,
		Text = T(882784467984, --[[SetpiecePrg Cinematic_Intro_Bake Text voice:narrator]] "Things like law and justice are fragile concepts here and the political enemies my father made are already calling for emergency powers to be invoked. I don't know if they are behind the kidnapping, but I am sure they are planning to take advantage of it. "),
	}),
	PlaceObj('SetpieceFadeOut', {
		FadeOutTime = 300,
	}),
	PlaceObj('SetpieceFadeIn', {
		FadeInDelay = 0,
		FadeInTime = 100,
		Wait = false,
	}),
	PlaceObj('SetpieceCamera', {
		DOFFar = 700,
		DOFFarSpread = 300,
		DOFNear = 600,
		DOFNearSpread = 1000,
		DOFStrengthFar = 80,
		DOFStrengthNear = 60,
		Duration = 16000,
		FovX = 3200,
		LookAt1 = point(150693, 166729, 6044),
		LookAt2 = point(150775, 166645, 6044),
		Movement = "linear",
		Pos1 = point(152135, 168136, 8266),
		Pos2 = point(152217, 168052, 8266),
	}),
	PlaceObj('SetpieceVoice', {
		Actor = "narrator",
		Disable = true,
		Text = T(980617204308, --[[SetpiecePrg Cinematic_Intro_Bake Text voice:narrator]] 'The person who took my father calls himself "<em>the Major</em>." I haven\'t been able to find out who he really is, but everyone knows what he wants. He has demanded the entire Adjani River Valley be given to him.'),
		TimeAdd = 1000,
	}),
	PlaceObj('SetpieceFadeOut', {
		FadeOutTime = 300,
	}),
	PlaceObj('SetpieceFadeIn', {
		FadeInDelay = 0,
		FadeInTime = 100,
		Wait = false,
	}),
	PlaceObj('SetpieceCamera', {
		DOFFar = 1340,
		DOFFarSpread = 100,
		DOFNear = 1200,
		DOFNearSpread = 100,
		DOFStrengthFar = 80,
		DOFStrengthNear = 20,
		Duration = 12000,
		FovX = 2200,
		LookAt1 = point(151082, 167006, 6394),
		LookAt2 = point(150948, 166931, 6218),
		Movement = "linear",
		Pos1 = point(152805, 167971, 8654),
		Pos2 = point(152671, 167896, 8478),
	}),
	PlaceObj('SetpieceVoice', {
		Actor = "narrator",
		Disable = true,
		Text = T(170466064841, --[[SetpiecePrg Cinematic_Intro_Bake Text voice:narrator]] "His followers, who call themselves the <em>Legion</em>, have already seized most of it, but he has vowed to execute my father should the government attempt to intervene."),
		TimeAdd = 1000,
	}),
	PlaceObj('SetpieceFadeOut', {
		FadeOutTime = 300,
	}),
	PlaceObj('SetpieceFadeIn', {
		FadeInDelay = 0,
		FadeInTime = 100,
		Wait = false,
	}),
	PlaceObj('SetpieceCamera', {
		DOFFar = 1400,
		DOFFarSpread = 60,
		DOFNear = 1200,
		DOFNearSpread = 800,
		DOFStrengthFar = 80,
		DOFStrengthNear = 60,
		Duration = 20000,
		FovX = 2200,
		LookAt1 = point(150468, 168715, 6591),
		LookAt2 = point(150534, 168864, 6591),
		Movement = "linear",
		Pos1 = point(152411, 167844, 8707),
		Pos2 = point(152477, 167993, 8707),
	}),
	PlaceObj('SetpieceVoice', {
		Actor = "narrator",
		Disable = true,
		Text = T(243290865030, --[[SetpiecePrg Cinematic_Intro_Bake Text voice:narrator]] "I've wired the money you requested. Please, assemble your team and come meet me on <em>Ernie Island</em> at <em>Corazon Santiago's</em> villa. She is the <em>Adonis</em> representative I told you about in my email - her diamond mining operations can help with additional funding should you need it."),
	}),
	PlaceObj('SetpieceFadeOut', {
		FadeOutTime = 300,
	}),
	PlaceObj('SetpieceFadeIn', {
		FadeInDelay = 0,
		FadeInTime = 100,
		Wait = false,
	}),
	PlaceObj('SetpieceCamera', {
		DOFFar = 870,
		DOFFarSpread = 200,
		DOFStrengthFar = 100,
		DOFStrengthNear = 30,
		Duration = 0,
		FovX = 3200,
		LookAt1 = point(151239, 167997, 5798),
		LookAt2 = point(151273, 167996, 5508),
		Pos1 = point(152417, 167997, 8557),
		Pos2 = point(152275, 167996, 8337),
	}),
	PlaceObj('SetpieceVoice', {
		Actor = "narrator",
		Disable = true,
		Text = T(707093581147, --[[SetpiecePrg Cinematic_Intro_Bake Text voice:narrator]] "My car is here. I have to go.\nI'll have more details for you when we meet."),
		TimeAdd = 1000,
		Wait = false,
	}),
	PlaceObj('SetpieceCamera', {
		DOFFar = 870,
		DOFFarSpread = 200,
		DOFStrengthFar = 100,
		DOFStrengthNear = 30,
		Duration = 7000,
		FovX = 3200,
		LookAt1 = point(151239, 167997, 5798),
		LookAt2 = point(151211, 167997, 5733),
		Movement = "linear",
		Pos1 = point(152417, 167997, 8557),
		Pos2 = point(152389, 167997, 8492),
	}),
	PlaceObj('SetpieceCamera', {
		DOFFar = 870,
		DOFFarSpread = 200,
		DOFStrengthFar = 100,
		DOFStrengthNear = 30,
		Duration = 2000,
		FovX = 3200,
		LookAt1 = point(150425, 167997, 3893),
		LookAt2 = point(151273, 167996, 5508),
		Movement = "accelerated",
		Pos1 = point(152389, 167997, 8492),
		Pos2 = point(152275, 167996, 8337),
		Wait = false,
	}),
	PlaceObj('SetpieceFadeOut', {
		FadeOutTime = 2000,
	}),
})

