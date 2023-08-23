-- ========== GENERATED BY SetpiecePrg Editor (Ctrl-Alt-S) DO NOT EDIT MANUALLY! ==========

rawset(_G, 'SetpiecePrgs', rawget(_G, 'SetpiecePrgs') or {})
SetpiecePrgs.SanatoriumOutbreak = function(seed, state, TriggerUnits)
	local li = { id = "SanatoriumOutbreak" }
	local rand = BraidRandomCreate(seed or AsyncRand())
	prgdbg(li, 1, 1) sprocall(SetpieceFadeOut.Exec, SetpieceFadeOut, state, rand, true, "", 0)
	prgdbg(li, 1, 2) sprocall(PrgPlayEffect.Exec, PrgPlayEffect, state, rand, true, "", {PlaceObj('MusicSetTrack', {Playlist = "Scripted",Track = "Music/It's Too Quiet",}),})
	prgdbg(li, 1, 3) sprocall(SetpieceSleep.Exec, SetpieceSleep, state, rand, true, "", 100)
	local _, InitialInfected
	prgdbg(li, 1, 4) _, InitialInfected = sprocall(SetpieceAssignFromGroup.Exec, SetpieceAssignFromGroup, state, rand, InitialInfected, "", "InitialInfected", "Unit", false)
	local _, QueueDoctor
	prgdbg(li, 1, 5) _, QueueDoctor = sprocall(SetpieceAssignFromGroup.Exec, SetpieceAssignFromGroup, state, rand, QueueDoctor, "", "QueueDoctor", "Unit", false)
	local _, InfectedQueue_01
	prgdbg(li, 1, 6) _, InfectedQueue_01 = sprocall(SetpieceAssignFromGroup.Exec, SetpieceAssignFromGroup, state, rand, InfectedQueue_01, "", "InfectedQueue_01", "Unit", false)
	local _, InfectedQueue_02
	prgdbg(li, 1, 7) _, InfectedQueue_02 = sprocall(SetpieceAssignFromGroup.Exec, SetpieceAssignFromGroup, state, rand, InfectedQueue_02, "", "InfectedQueue_02", "Unit", false)
	local _, InfectedQueue_03
	prgdbg(li, 1, 8) _, InfectedQueue_03 = sprocall(SetpieceAssignFromGroup.Exec, SetpieceAssignFromGroup, state, rand, InfectedQueue_03, "", "InfectedQueue_03", "Unit", false)
	local _, InfectedQueue_04
	prgdbg(li, 1, 9) _, InfectedQueue_04 = sprocall(SetpieceAssignFromGroup.Exec, SetpieceAssignFromGroup, state, rand, InfectedQueue_04, "", "InfectedQueue_04", "Unit", false)
	local _, QueueGuard
	prgdbg(li, 1, 10) _, QueueGuard = sprocall(SetpieceAssignFromGroup.Exec, SetpieceAssignFromGroup, state, rand, QueueGuard, "", "QueueGuard", "Unit", false)
	local _, ShiveringNurse
	prgdbg(li, 1, 11) _, ShiveringNurse = sprocall(SetpieceSpawn.Exec, SetpieceSpawn, state, rand, ShiveringNurse, "ShiveringNurse")
	local _, QueueNurse
	prgdbg(li, 1, 12) _, QueueNurse = sprocall(SetpieceSpawn.Exec, SetpieceSpawn, state, rand, QueueNurse, "QueueNurse")
	local _, QueueCiv_01
	prgdbg(li, 1, 13) _, QueueCiv_01 = sprocall(SetpieceSpawn.Exec, SetpieceSpawn, state, rand, QueueCiv_01, "QueueCiv_01")
	local _, QueueCiv_02
	prgdbg(li, 1, 14) _, QueueCiv_02 = sprocall(SetpieceSpawn.Exec, SetpieceSpawn, state, rand, QueueCiv_02, "QueueCiv_02")
	local _, QueueCiv_03
	prgdbg(li, 1, 15) _, QueueCiv_03 = sprocall(SetpieceSpawn.Exec, SetpieceSpawn, state, rand, QueueCiv_03, "QueueCiv_03")
	local _, QueueCiv_04
	prgdbg(li, 1, 16) _, QueueCiv_04 = sprocall(SetpieceSpawn.Exec, SetpieceSpawn, state, rand, QueueCiv_04, "QueueCiv_04")
	local _, QueueCiv_05
	prgdbg(li, 1, 17) _, QueueCiv_05 = sprocall(SetpieceSpawn.Exec, SetpieceSpawn, state, rand, QueueCiv_05, "QueueCiv_05")
	local _, QueueCiv_06
	prgdbg(li, 1, 18) _, QueueCiv_06 = sprocall(SetpieceSpawn.Exec, SetpieceSpawn, state, rand, QueueCiv_06, "QueueCiv_06")
	local _, QueueCiv_07
	prgdbg(li, 1, 19) _, QueueCiv_07 = sprocall(SetpieceSpawn.Exec, SetpieceSpawn, state, rand, QueueCiv_07, "QueueCiv_07")
	local _, QueueCiv_08
	prgdbg(li, 1, 20) _, QueueCiv_08 = sprocall(SetpieceSpawn.Exec, SetpieceSpawn, state, rand, QueueCiv_08, "QueueCiv_08")
	local _
	prgdbg(li, 1, 21) _, ShiveringNurse = sprocall(SetpieceAssignFromGroup.Exec, SetpieceAssignFromGroup, state, rand, ShiveringNurse, "ShiveringNurse", "ShiveringNurse", "Object", false)
	local _
	prgdbg(li, 1, 22) _, QueueNurse = sprocall(SetpieceAssignFromGroup.Exec, SetpieceAssignFromGroup, state, rand, QueueNurse, "QueueNurse", "QueueNurse", "Object", false)
	local _
	prgdbg(li, 1, 23) _, QueueCiv_01 = sprocall(SetpieceAssignFromGroup.Exec, SetpieceAssignFromGroup, state, rand, QueueCiv_01, "QueueCiv_01", "QueueCiv_01", "Object", false)
	local _
	prgdbg(li, 1, 24) _, QueueCiv_02 = sprocall(SetpieceAssignFromGroup.Exec, SetpieceAssignFromGroup, state, rand, QueueCiv_02, "QueueCiv_02", "QueueCiv_02", "Object", false)
	local _
	prgdbg(li, 1, 25) _, QueueCiv_03 = sprocall(SetpieceAssignFromGroup.Exec, SetpieceAssignFromGroup, state, rand, QueueCiv_03, "QueueCiv_03", "QueueCiv_03", "Object", false)
	local _
	prgdbg(li, 1, 26) _, QueueCiv_04 = sprocall(SetpieceAssignFromGroup.Exec, SetpieceAssignFromGroup, state, rand, QueueCiv_04, "QueueCiv_04", "QueueCiv_04", "Object", false)
	local _
	prgdbg(li, 1, 27) _, QueueCiv_05 = sprocall(SetpieceAssignFromGroup.Exec, SetpieceAssignFromGroup, state, rand, QueueCiv_05, "QueueCiv_05", "QueueCiv_05", "Object", false)
	local _
	prgdbg(li, 1, 28) _, QueueCiv_06 = sprocall(SetpieceAssignFromGroup.Exec, SetpieceAssignFromGroup, state, rand, QueueCiv_06, "QueueCiv_06", "QueueCiv_06", "Object", false)
	local _
	prgdbg(li, 1, 29) _, QueueCiv_07 = sprocall(SetpieceAssignFromGroup.Exec, SetpieceAssignFromGroup, state, rand, QueueCiv_07, "QueueCiv_07", "QueueCiv_07", "Object", false)
	local _
	prgdbg(li, 1, 30) _, QueueCiv_08 = sprocall(SetpieceAssignFromGroup.Exec, SetpieceAssignFromGroup, state, rand, QueueCiv_08, "QueueCiv_08", "QueueCiv_08", "Object", false)
	prgdbg(li, 1, 37) sprocall(SetpieceAnimation.Exec, SetpieceAnimation, state, rand, false, "", QueueDoctor, "", true, "civ_Talk_HandsOnHips7", 1000, 0, range(1, 1), 0, false, false, false, "civ_Talk_HandsOnHips6")
	prgdbg(li, 1, 38) sprocall(SetpieceAnimation.Exec, SetpieceAnimation, state, rand, false, "", QueueGuard, "", true, "hg_Standing_IdlePassive", 1000, 0, range(1, 1), 0, false, true, false, "")
	prgdbg(li, 1, 39) sprocall(SetpieceAnimation.Exec, SetpieceAnimation, state, rand, false, "", QueueNurse, "", true, "civ_Talking2", 1000, 0, range(1, 1), 0, false, true, false, "")
	prgdbg(li, 1, 40) sprocall(SetpieceAnimation.Exec, SetpieceAnimation, state, rand, false, "", ShiveringNurse, "", true, "civ_Fear_Cover", 1000, 0, range(1, 1), 0, false, true, false, "")
	prgdbg(li, 1, 41) sprocall(SetpieceAnimation.Exec, SetpieceAnimation, state, rand, false, "", QueueCiv_01, "", true, "civ_Ambient_Angry", 1000, 0, range(1, 1), 0, false, true, false, "")
	prgdbg(li, 1, 42) sprocall(SetpieceAnimation.Exec, SetpieceAnimation, state, rand, false, "", QueueCiv_02, "", true, "civ_Ambient_SadCrying", 1000, 0, range(1, 1), 0, false, true, false, "")
	prgdbg(li, 1, 43) sprocall(SetpieceAnimation.Exec, SetpieceAnimation, state, rand, false, "", QueueCiv_03, "", true, "civ_Standing_Idle2", 1000, 0, range(1, 1), 0, false, true, false, "")
	prgdbg(li, 1, 44) sprocall(SetpieceAnimation.Exec, SetpieceAnimation, state, rand, false, "", QueueCiv_04, "", true, "civ_Standing_IdlePassive2", 1000, 0, range(1, 1), 0, false, true, false, "")
	prgdbg(li, 1, 45) sprocall(SetpieceAnimation.Exec, SetpieceAnimation, state, rand, false, "", QueueCiv_05, "", true, "civ_Standing_IdlePassive3", 1000, 0, range(1, 1), 0, false, true, false, "")
	prgdbg(li, 1, 46) sprocall(SetpieceAnimation.Exec, SetpieceAnimation, state, rand, false, "", QueueCiv_06, "", true, "civ_Standing_Idle2", 1000, 0, range(1, 1), 0, true, true, false, "")
	prgdbg(li, 1, 47) sprocall(SetpieceAnimation.Exec, SetpieceAnimation, state, rand, false, "", QueueCiv_07, "", true, "civ_Standing_Idle2", 1000, 0, range(1, 1), 0, false, true, false, "")
	prgdbg(li, 1, 48) sprocall(SetpieceAnimation.Exec, SetpieceAnimation, state, rand, false, "", QueueCiv_08, "", true, "civ_Standing_IdlePassive3", 1000, 0, range(1, 1), 0, false, true, false, "")
	prgdbg(li, 1, 49) sprocall(SetpieceAnimation.Exec, SetpieceAnimation, state, rand, false, "", InfectedQueue_01, "", true, "civ_Talking2", 1000, 0, range(1, 1), 0, false, true, false, "")
	prgdbg(li, 1, 50) sprocall(SetpieceAnimation.Exec, SetpieceAnimation, state, rand, false, "", InfectedQueue_02, "", true, "civ_Ambient_SadCrying", 1000, 0, range(1, 1), 0, true, true, false, "")
	prgdbg(li, 1, 51) sprocall(SetpieceAnimation.Exec, SetpieceAnimation, state, rand, false, "", InfectedQueue_03, "", true, "civ_Ambient_Angry", 1000, 0, range(1, 1), 0, true, true, false, "")
	prgdbg(li, 1, 52) sprocall(SetpieceAnimation.Exec, SetpieceAnimation, state, rand, false, "", InfectedQueue_04, "", true, "inf_Standing_IdlePassive", 1000, 0, range(1, 1), 0, true, true, false, "")
	prgdbg(li, 1, 53) sprocall(SetpieceCamera.Exec, SetpieceCamera, state, rand, false, "Establishing Shot", "Max", "", "decelerated", "linear", 5500, false, false, point(125816, 156599, 10826), point(123253, 160872, 11241), point(124486, 154411, 13103), point(121926, 158686, 13513), 4400, 2000, false, 0, 60, 0, 35000, 0, 500, "Default", 100)
	prgdbg(li, 1, 60) sprocall(SetpieceFadeIn.Exec, SetpieceFadeIn, state, rand, false, "", 400, 800)
	prgdbg(li, 1, 61) sprocall(SetpieceGotoPosition.Exec, SetpieceGotoPosition, state, rand, false, "Establishing Shot", InitialInfected, "InitialInfectedGoToFinal", true, false, false, "", false, false, "")
	prgdbg(li, 1, 62) sprocall(SetpieceWaitCheckpoint.Exec, SetpieceWaitCheckpoint, state, rand, "Establishing Shot")
	prgdbg(li, 1, 63) sprocall(SetpieceFadeOut.Exec, SetpieceFadeOut, state, rand, true, "", 700)
	prgdbg(li, 1, 64) sprocall(SetpieceCamera.Exec, SetpieceCamera, state, rand, false, "Second Shot", "Max", "", "", "linear", 5000, false, false, point(121813, 144627, 11689), point(117519, 147111, 12319), false, false, 4700, 2000, false, 40, 60, 6000, 35000, 500, 500, "Default", 100)
	prgdbg(li, 1, 65) sprocall(SetpieceFadeIn.Exec, SetpieceFadeIn, state, rand, false, "", 400, 800)
	prgdbg(li, 1, 66) sprocall(SetpieceAnimation.Exec, SetpieceAnimation, state, rand, false, "Second Shot", QueueNurse, "", true, "civ_Talking2", 1000, 2000, range(1, 1), 0, false, true, false, "")
	prgdbg(li, 1, 67) sprocall(SetpieceAnimation.Exec, SetpieceAnimation, state, rand, false, "Second Shot", InitialInfected, "", false, "civ_Ambient_SadCrying", 1000, 2000, range(1, 1), 0, false, true, true, "")
	prgdbg(li, 1, 68) sprocall(SetpieceWaitCheckpoint.Exec, SetpieceWaitCheckpoint, state, rand, "Second Shot")
	prgdbg(li, 1, 69) sprocall(PrgPlayEffect.Exec, PrgPlayEffect, state, rand, false, "", {PlaceObj('PlayBanterEffect', {Banters = {"SanatoriumNPC_event_GuardInitial",},searchInMap = true,searchInMarker = false,}),})
	prgdbg(li, 1, 70) sprocall(SetpieceCamera.Exec, SetpieceCamera, state, rand, true, "", "Max", "", "", "linear", 3000, false, false, point(127644, 146029, 10733), point(122653, 146058, 10445), false, false, 4700, 2000, false, 50, 50, 6000, 25000, 0, 500, "Default", 100)
	prgdbg(li, 1, 71) sprocall(SetpieceAnimation.Exec, SetpieceAnimation, state, rand, true, "", InitialInfected, "", false, "inf_Standing_CombatBegin", 1000, 0, range(1, 1), 0, false, true, false, "inf_Standing_Attack2")
	prgdbg(li, 1, 72) sprocall(SetpieceSleep.Exec, SetpieceSleep, state, rand, true, "", 650)
	prgdbg(li, 1, 73) sprocall(SetpieceFadeOut.Exec, SetpieceFadeOut, state, rand, true, "Fade", 400)
	prgdbg(li, 1, 74) sprocall(PrgPlayEffect.Exec, PrgPlayEffect, state, rand, false, "", {PlaceObj('PlayBanterEffect', {Banters = {"SanatoriumNPC_event_GuardOutbreakStart",},searchInMap = true,searchInMarker = false,}),})
	prgdbg(li, 1, 75) sprocall(SetpieceCamera.Exec, SetpieceCamera, state, rand, false, "", "Max", "", "decelerated", "linear", 20000, false, false, point(136960, 142842, 11604), point(141215, 140515, 12820), point(151661, 134810, 15819), point(155917, 132485, 17036), 4200, 2000, false, 40, 60, 10000, 80000, 500, 500, "Default", 100)
	prgdbg(li, 1, 76) sprocall(SetpieceFadeIn.Exec, SetpieceFadeIn, state, rand, false, "", 0, 500)
	local _, AttackPointLegion1
	prgdbg(li, 1, 77) _, AttackPointLegion1 = sprocall(SetpieceShoot.Exec, SetpieceShoot, state, rand, false, "", QueueGuard, "Unit", InitialInfected, "Torso", "ChurchFight_GrenedierRun", 3, 0, 300, 100, 0, 3)
	prgdbg(li, 1, 78) sprocall(SetpieceGotoPosition.Exec, SetpieceGotoPosition, state, rand, false, "", InfectedQueue_03, "CivQ_07_RunSpot", true, true, false, "Standing", false, false, "")
	prgdbg(li, 1, 79) sprocall(SetpieceDeath.Exec, SetpieceDeath, state, rand, false, "In. Infected Dies", InitialInfected, false)
	prgdbg(li, 1, 81) sprocall(SetpieceAnimation.Exec, SetpieceAnimation, state, rand, false, "", QueueNurse, "", true, "civ_Fear_Standing2", 1000, 0, range(1, 1), 0, false, true, false, "")
	prgdbg(li, 1, 82) sprocall(SetpieceAnimation.Exec, SetpieceAnimation, state, rand, false, "", QueueCiv_01, "", true, "civ_Fear_Cover", 1000, 0, range(1, 1), 0, true, true, false, "")
	prgdbg(li, 1, 83) sprocall(SetpieceGotoPosition.Exec, SetpieceGotoPosition, state, rand, false, "", QueueCiv_01, "Civ06_RunSpot", false, true, false, "Standing", false, false, "Run_RainHeavy")
	prgdbg(li, 1, 84) sprocall(SetpieceGotoPosition.Exec, SetpieceGotoPosition, state, rand, false, "", QueueCiv_02, "CivQ_02_RunSpot", false, true, false, "Standing", false, false, "")
	prgdbg(li, 1, 85) sprocall(SetpieceGotoPosition.Exec, SetpieceGotoPosition, state, rand, false, "", QueueCiv_03, "CivQ_03_RunSpot", false, true, false, "Standing", false, false, "")
	prgdbg(li, 1, 86) sprocall(SetpieceAnimation.Exec, SetpieceAnimation, state, rand, false, "", QueueCiv_04, "", true, "civ_Fear_Standing", 1000, 0, range(1, 1), 0, true, true, false, "")
	prgdbg(li, 1, 87) sprocall(SetpieceAnimation.Exec, SetpieceAnimation, state, rand, false, "", QueueCiv_05, "", true, "civ_Fear_Cover", 1000, 0, range(1, 1), 0, true, true, false, "")
	prgdbg(li, 1, 88) sprocall(SetpieceAnimation.Exec, SetpieceAnimation, state, rand, false, "", QueueCiv_06, "", true, "civ_Fear_Standing", 1000, 0, range(1, 1), 0, true, true, false, "")
	prgdbg(li, 1, 89) sprocall(SetpieceGotoPosition.Exec, SetpieceGotoPosition, state, rand, false, "", QueueCiv_07, "CivQ_07_RunSpot", false, true, false, "Standing", false, false, "")
	prgdbg(li, 1, 90) sprocall(SetpieceAnimation.Exec, SetpieceAnimation, state, rand, false, "", QueueCiv_08, "", true, "civ_Fear_Standing", 1000, 0, range(1, 1), 0, true, true, false, "civ_Fear_Standing2")
	prgdbg(li, 1, 91) sprocall(SetpieceAnimation.Exec, SetpieceAnimation, state, rand, false, "", InfectedQueue_01, "", false, "inf_Standing_CombatBegin", 1000, 1500, range(1, 1), 0, true, true, false, "")
	prgdbg(li, 1, 92) sprocall(SetpieceAnimation.Exec, SetpieceAnimation, state, rand, false, "Hurt Doctor", QueueDoctor, "", true, "hg_Standing_Downed", 1000, 0, range(1, 1), 0, false, true, false, "hg_Downed_Idle")
	prgdbg(li, 1, 93) sprocall(SetpieceAnimation.Exec, SetpieceAnimation, state, rand, false, "", InfectedQueue_01, "", true, "inf_Standing_CombatBegin", 1000, 1500, range(1, 1), 0, false, true, false, "")
	prgdbg(li, 1, 94) sprocall(SetpieceGotoPosition.Exec, SetpieceGotoPosition, state, rand, false, "", QueueCiv_04, "Civ04_RunSpot", false, true, false, "Standing", false, false, "Run_RainHeavy")
	prgdbg(li, 1, 95) sprocall(SetpieceAnimation.Exec, SetpieceAnimation, state, rand, false, "", InfectedQueue_02, "", false, "inf_Standing_CombatBegin", 1000, 1500, range(1, 1), 0, true, true, false, "inf_Standing_Attack")
	prgdbg(li, 1, 96) sprocall(SetpieceAnimation.Exec, SetpieceAnimation, state, rand, false, "", InfectedQueue_04, "", true, "inf_Standing_CombatBegin", 1000, 0, range(1, 1), 0, true, true, false, "")
	prgdbg(li, 1, 97) sprocall(SetpieceGotoPosition.Exec, SetpieceGotoPosition, state, rand, false, "AttackingGuard", InfectedQueue_04, "Infected_04HitGuard", true, false, false, "Standing", false, false, "")
	local _
	prgdbg(li, 1, 98) _, AttackPointLegion1 = sprocall(SetpieceShoot.Exec, SetpieceShoot, state, rand, false, "AttackingGuard", QueueGuard, "Unit", InfectedQueue_01, "Torso", "ChurchFight_GrenedierRun", 3, 0, 1000, 100, 0, 3)
	prgdbg(li, 1, 99) sprocall(SetpieceWaitCheckpoint.Exec, SetpieceWaitCheckpoint, state, rand, "AttackingGuard")
	prgdbg(li, 1, 100) sprocall(SetpieceAnimation.Exec, SetpieceAnimation, state, rand, false, "", InfectedQueue_02, "", false, "inf_Standing_Attack", 1000, 0, range(1, 1), 0, false, true, false, "")
	prgdbg(li, 1, 101) sprocall(SetpieceAnimation.Exec, SetpieceAnimation, state, rand, false, "", QueueCiv_05, "", true, "hg_Standing_Downed", 10000, 5000, range(1, 1), 0, false, true, false, "hg_Downed_Death")
	prgdbg(li, 1, 102) sprocall(SetpieceGotoPosition.Exec, SetpieceGotoPosition, state, rand, false, "", InfectedQueue_01, "CivQ_07_RunSpot", false, false, false, "Standing", false, false, "")
	prgdbg(li, 1, 103) sprocall(SetpieceGotoPosition.Exec, SetpieceGotoPosition, state, rand, false, "", InfectedQueue_02, "InfQ_02chase_CivQ06", true, false, false, "Standing", true, false, "")
	prgdbg(li, 1, 104) sprocall(SetpieceAnimation.Exec, SetpieceAnimation, state, rand, false, "", InfectedQueue_04, "", true, "inf_Standing_Attack", 1000, 0, range(1, 1), 0, false, true, false, "")
	prgdbg(li, 1, 105) sprocall(SetpieceSleep.Exec, SetpieceSleep, state, rand, true, "", 1000)
	prgdbg(li, 1, 106) sprocall(SetpieceGotoPosition.Exec, SetpieceGotoPosition, state, rand, false, "", InfectedQueue_04, "InfQ04_chase_CivQ08", true, false, false, "Standing", false, false, "")
	prgdbg(li, 1, 107) sprocall(SetpieceDeath.Exec, SetpieceDeath, state, rand, false, "Doctor Dies", QueueDoctor, "civ_Downed_Death")
	prgdbg(li, 1, 108) sprocall(SetpieceAnimation.Exec, SetpieceAnimation, state, rand, false, "Guard Dies", QueueGuard, "", true, "hg_Standing_Downed", 1000, 0, range(1, 1), 0, false, true, false, "hg_Downed_Death")
	prgdbg(li, 1, 109) sprocall(SetpieceSleep.Exec, SetpieceSleep, state, rand, true, "", 100)
	prgdbg(li, 1, 110) sprocall(SetpieceGotoPosition.Exec, SetpieceGotoPosition, state, rand, false, "", QueueCiv_06, "CivQ_03_RunSpot", false, true, false, "Standing", false, false, "")
	prgdbg(li, 1, 111) sprocall(SetpieceGotoPosition.Exec, SetpieceGotoPosition, state, rand, false, "", InfectedQueue_02, "CivQ_03_RunSpot", true, false, false, "Standing", true, false, "")
	prgdbg(li, 1, 112) sprocall(SetpieceSleep.Exec, SetpieceSleep, state, rand, true, "", 4000)
	prgdbg(li, 1, 113) sprocall(SetpieceGotoPosition.Exec, SetpieceGotoPosition, state, rand, false, "", QueueCiv_08, "Civ08_RunSpot", false, true, false, "Standing", false, false, "")
	prgdbg(li, 1, 114) sprocall(SetpieceGotoPosition.Exec, SetpieceGotoPosition, state, rand, false, "", InfectedQueue_04, "Civ08_RunSpot", true, true, false, "Standing", false, false, "")
	prgdbg(li, 1, 115) sprocall(SetpieceSleep.Exec, SetpieceSleep, state, rand, true, "", 7000)
	prgdbg(li, 1, 116) sprocall(SetpieceGotoPosition.Exec, SetpieceGotoPosition, state, rand, false, "", InfectedQueue_01, "Civ06_RunSpot", false, true, false, "Standing", false, false, "")
	prgdbg(li, 1, 117) sprocall(SetpieceGotoPosition.Exec, SetpieceGotoPosition, state, rand, false, "", QueueCiv_04, "CivQ_02_RunSpot", false, true, false, "Standing", false, false, "")
	prgdbg(li, 1, 118) sprocall(SetpieceSleep.Exec, SetpieceSleep, state, rand, true, "", 5000)
	prgdbg(li, 1, 119) sprocall(PrgPlayEffect.Exec, PrgPlayEffect, state, rand, false, "Fade", {PlaceObj('QuestSetVariableBool', {Prop = "ClinicCombat",QuestId = "Sanatorium",}),})
	prgdbg(li, 1, 120) sprocall(SetpieceFadeOut.Exec, SetpieceFadeOut, state, rand, true, "Fade", 700)
	prgdbg(li, 1, 121) sprocall(SetpieceDespawn.Exec, SetpieceDespawn, QueueCiv_01)
	prgdbg(li, 1, 122) sprocall(SetpieceDespawn.Exec, SetpieceDespawn, QueueCiv_02)
	prgdbg(li, 1, 123) sprocall(SetpieceDespawn.Exec, SetpieceDespawn, QueueCiv_03)
	prgdbg(li, 1, 124) sprocall(SetpieceDespawn.Exec, SetpieceDespawn, QueueCiv_04)
	prgdbg(li, 1, 125) sprocall(SetpieceDespawn.Exec, SetpieceDespawn, QueueCiv_05)
	prgdbg(li, 1, 126) sprocall(SetpieceDespawn.Exec, SetpieceDespawn, QueueCiv_06)
	prgdbg(li, 1, 127) sprocall(SetpieceDespawn.Exec, SetpieceDespawn, QueueCiv_07)
	prgdbg(li, 1, 128) sprocall(SetpieceDespawn.Exec, SetpieceDespawn, QueueCiv_08)
	prgdbg(li, 1, 129) sprocall(SetpieceDespawn.Exec, SetpieceDespawn, ShiveringNurse)
	prgdbg(li, 1, 130) sprocall(SetpieceDespawn.Exec, SetpieceDespawn, QueueNurse)
	prgdbg(li, 1, 131) sprocall(SetpieceDespawn.Exec, SetpieceDespawn, InfectedQueue_02)
	prgdbg(li, 1, 132) sprocall(SetpieceDeath.Exec, SetpieceDeath, state, rand, false, "Guard Dies", QueueGuard, false)
	prgdbg(li, 1, 133) sprocall(PrgForceStopSetpiece.Exec, PrgForceStopSetpiece, state, rand, "")
end