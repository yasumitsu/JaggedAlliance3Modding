-- ========== GENERATED BY QuestsDef Editor (Ctrl-Alt-Q) DO NOT EDIT MANUALLY! ==========

PlaceObj('QuestsDef', {
	DevNotes = "When Beast is completed, she will have 75% chance to spawn in key Cursed Forest and Bien Chien sectors.\nRandomizer is randomized each time upon conflict, before battle.",
	DisplayName = T(414959957372, --[[QuestsDef CursedForestSideQuests DisplayName]] "Cursed Forest"),
	NoteDefs = {
		LastNoteIdx = 6,
		PlaceObj('QuestNote', {
			CompletionConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "Beast",
					Vars = set( "BeastEffigies", "BeastEffigyOn" ),
					__eval = function ()
						local quest = gv_Quests['Beast'] or QuestGetState('Beast')
						return quest.BeastEffigies or quest.BeastEffigyOn
					end,
				}),
			},
			Idx = 5,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "Beast",
					Vars = set( "BeastEffigies", "BeastEffigyOn" ),
					__eval = function ()
						local quest = gv_Quests['Beast'] or QuestGetState('Beast')
						return quest.BeastEffigies or quest.BeastEffigyOn
					end,
				}),
			},
			Text = T(147932979860, --[[QuestsDef CursedForestSideQuests Text]] "There are horrible <em>effigies</em> in the Cursed Forest that scare the Legion"),
		}),
		PlaceObj('QuestNote', {
			Badges = {
				PlaceObj('QuestBadgePlacement', {
					BadgeUnit = "BrokenEffigy",
					Sector = "D18",
				}),
				PlaceObj('QuestBadgePlacement', {
					BadgeUnit = "BrokenEffigy",
					Sector = "E15",
				}),
				PlaceObj('QuestBadgePlacement', {
					BadgeUnit = "BrokenEffigy",
					Sector = "D13",
				}),
				PlaceObj('QuestBadgePlacement', {
					BadgeUnit = "BrokenEffigy",
					Sector = "E13",
				}),
				PlaceObj('QuestBadgePlacement', {
					BadgeUnit = "BrokenEffigy",
					Sector = "D14",
				}),
				PlaceObj('QuestBadgePlacement', {
					BadgeUnit = "BrokenEffigy",
					Sector = "D15",
				}),
				PlaceObj('QuestBadgePlacement', {
					BadgeUnit = "BrokenEffigy",
					Sector = "C16",
				}),
			},
			CompletionConditions = {
				PlaceObj('QuestIsVariableNum', {
					AgainstVar = true,
					Prop = "EffigiesRepaired",
					Prop2 = "EffigiesRepairedMax",
					QuestId = "Beast",
					QuestId2 = "Beast",
				}),
			},
			Idx = 6,
			ShowConditions = {
				PlaceObj('QuestIsVariableNum', {
					Amount = 1,
					Prop = "EffigiesRepaired",
					QuestId = "Beast",
				}),
			},
			Text = T(330642926974, --[[QuestsDef CursedForestSideQuests Text]] "The Legion destroyed some <em>effigies</em> in the Cursed Forest that can be repaired"),
		}),
	},
	QuestGroup = "Jungle",
	TCEs = {
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('BanterHasPlayed', {
					Banters = {
						"IlleMoratOutskirts_02_FrancisInitial",
					},
					WaitOver = true,
				}),
			},
			Effects = {
				PlaceObj('QuestSetVariableBool', {
					Prop = "GraveGiven",
					QuestId = "CursedForestSideQuests",
				}),
			},
			Once = true,
			ParamId = "TCE_GraveGive",
			QuestId = "CursedForestSideQuests",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('BanterHasPlayed', {
					Banters = {
						"IlleMoratOutskirts_03_GraveFound",
					},
				}),
			},
			Effects = {
				PlaceObj('QuestSetVariableBool', {
					Prop = "GraveFound",
					QuestId = "CursedForestSideQuests",
				}),
				PlaceObj('GrantExperienceSector', {
					Amount = "XPQuestReward_Minor",
					logImportant = true,
				}),
			},
			Once = true,
			ParamId = "TCE_GraveFind",
			QuestId = "CursedForestSideQuests",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('BanterHasPlayed', {
					Banters = {
						"IlleMoratOutskirts_04_FrancisGraveFound",
					},
					WaitOver = true,
				}),
			},
			Effects = {
				PlaceObj('QuestSetVariableBool', {
					Prop = "GraveReported",
					QuestId = "CursedForestSideQuests",
				}),
				PlaceObj('CityGrantLoyalty', {
					Amount = 5,
					City = "IlleMorat",
					SpecialConversationMessage = T(936046287637, --[[QuestsDef CursedForestSideQuests SpecialConversationMessage]] "helped <em>Francis</em> find his father's grave"),
				}),
				PlaceObj('GrantExperienceSector', {
					Amount = "XPQuestReward_Minor",
					logImportant = true,
				}),
			},
			Once = true,
			ParamId = "TCE_GraveReport",
			QuestId = "CursedForestSideQuests",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "CursedForestSideQuests",
					Vars = set( "GraveReported" ),
					__eval = function ()
						local quest = gv_Quests['CursedForestSideQuests'] or QuestGetState('CursedForestSideQuests')
						return quest.GraveReported
					end,
				}),
				PlaceObj('PlayerIsInSectors', {
					Negate = true,
					Sectors = {
						"D16",
					},
				}),
			},
			Effects = {
				PlaceObj('QuestSetVariableBool', {
					Prop = "GraveDone",
					QuestId = "CursedForestSideQuests",
				}),
				PlaceObj('QuestSetVariableBool', {
					Prop = "Completed",
					QuestId = "ForgottenGrave",
				}),
			},
			Once = true,
			ParamId = "TCE_GraveDone",
			QuestId = "CursedForestSideQuests",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('GroupIsDead', {
					Group = "GloomyVillager",
				}),
				PlaceObj('QuestIsVariableBool', {
					QuestId = "ForgottenGrave",
					Vars = set({
	Completed = false,
}),
					__eval = function ()
						local quest = gv_Quests['ForgottenGrave'] or QuestGetState('ForgottenGrave')
						return not quest.Completed
					end,
				}),
			},
			Effects = {
				PlaceObj('QuestSetVariableBool', {
					Prop = "Failed",
					QuestId = "ForgottenGrave",
				}),
			},
			Once = true,
			ParamId = "TCE_GraveFail",
			QuestId = "CursedForestSideQuests",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('BanterHasPlayed', {
					Banters = {
						"IlleMoratOutskirts_05_GravePayRespect",
					},
					WaitOver = true,
				}),
			},
			Effects = {
				PlaceObj('ApplyGuiltyOrRighteous', {}),
			},
			Once = true,
			ParamId = "TCE_GravePayRespect",
			QuestId = "CursedForestSideQuests",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('UnitIsAroundOtherUnit', {
					Distance = 14,
					SecondTargetUnit = "LegionMale_TeaParty",
					TargetUnit = "any merc",
				}),
			},
			Effects = {
				PlaceObj('PlayBanterEffect', {
					Banters = {
						"CursedForest_TeaParty_Legion01",
					},
					searchInMap = true,
					searchInMarker = false,
				}),
				PlaceObj('QuestSetVariableBool', {
					Prop = "Given",
					QuestId = "Beast",
				}),
				PlaceObj('GroupSetSide', {
					Side = "enemy1",
					TargetUnit = "LegionMale_TeaParty",
				}),
				PlaceObj('GroupAlert', {
					TargetUnit = "LegionMale_TeaParty",
				}),
			},
			Once = true,
			ParamId = "TCE_TeaPartySurvivor",
			QuestId = "CursedForestSideQuests",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('GroupIsDead', {
					Group = "LegionMale_TeaParty",
				}),
			},
			Effects = {
				PlaceObj('CityGrantLoyalty', {
					Amount = 5,
					City = "IlleMorat",
					SpecialConversationMessage = T(518014170206, --[[QuestsDef CursedForestSideQuests SpecialConversationMessage]] "finished off the tea party survivor"),
				}),
			},
			Once = true,
			ParamId = "TCE_TeaPartyDone",
			QuestId = "CursedForestSideQuests",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "Beast",
					Vars = set({
	BeastDead = false,
	BeastRecruited = true,
}),
					__eval = function ()
						local quest = gv_Quests['Beast'] or QuestGetState('Beast')
						return not quest.BeastDead and quest.BeastRecruited
					end,
				}),
				PlaceObj('SectorIsInConflict', {}),
				PlaceObj('CombatIsActive', {
					Negate = true,
				}),
				PlaceObj('OR', {
					Conditions = {
						PlaceObj('CheckGameState', {
							GameState = "Marshlands",
						}),
						PlaceObj('CheckGameState', {
							GameState = "CursedForest",
						}),
					},
				}),
			},
			Effects = {
				PlaceObj('QuestSetVariableNum', {
					Operation = "set",
					Prop = "Randomizer",
					QuestId = "Beast",
					RandomRangeMax = 3,
				}),
			},
			ParamId = "TCE_BeastRandomizeSpawn",
			QuestId = "CursedForestSideQuests",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "Beast",
					Vars = set({
	BeastDead = false,
}),
					__eval = function ()
						local quest = gv_Quests['Beast'] or QuestGetState('Beast')
						return not quest.BeastDead
					end,
				}),
				PlaceObj('QuestIsVariableBool', {
					QuestId = "_GroupsAttacked",
					Vars = set({
	TheBeast = false,
}),
					__eval = function ()
						local quest = gv_Quests['_GroupsAttacked'] or QuestGetState('_GroupsAttacked')
						return not quest.TheBeast
					end,
				}),
				PlaceObj('QuestIsVariableBool', {
					QuestId = "CursedForestSideQuests",
					Vars = set({
	PlayerAttackedBeast = false,
}),
					__eval = function ()
						local quest = gv_Quests['CursedForestSideQuests'] or QuestGetState('CursedForestSideQuests')
						return not quest.PlayerAttackedBeast
					end,
				}),
				PlaceObj('CombatIsActive', {}),
				PlaceObj('UnitIsOnMap', {
					TargetUnit = "TheBeast",
				}),
				PlaceObj('PlayerIsInSectors', {
					Sectors = {
						"C14",
					},
				}),
			},
			Effects = {
				PlaceObj('GroupSetSide', {
					Side = "ally",
					TargetUnit = "TheBeast",
				}),
			},
			ParamId = "TCE_BeastCabinCombat",
			QuestId = "CursedForestSideQuests",
			requiredSectors = {
				"C14",
			},
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "Beast",
					Vars = set({
	BeastDead = false,
}),
					__eval = function ()
						local quest = gv_Quests['Beast'] or QuestGetState('Beast')
						return not quest.BeastDead
					end,
				}),
				PlaceObj('SectorIsInConflict', {
					Negate = true,
				}),
				PlaceObj('UnitIsOnMap', {
					TargetUnit = "TheBeast",
				}),
				PlaceObj('PlayerIsInSectors', {
					Sectors = {
						"D17",
					},
				}),
			},
			Effects = {
				PlaceObj('GroupSetRoutine', {
					Routine = "AdvanceTo",
					RoutineArea = "BeastMoveToVlad",
					TargetUnit = "TheBeast",
				}),
			},
			ParamId = "TCE_BeastPostCombatMove",
			QuestId = "CursedForestSideQuests",
			requiredSectors = {
				"D17",
			},
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "Beast",
					Vars = set({
	BeastDead = false,
}),
					__eval = function ()
						local quest = gv_Quests['Beast'] or QuestGetState('Beast')
						return not quest.BeastDead
					end,
				}),
				PlaceObj('QuestIsVariableBool', {
					QuestId = "CursedForestSideQuests",
					Vars = set({
	PlayerAttackedBeast = false,
}),
					__eval = function ()
						local quest = gv_Quests['CursedForestSideQuests'] or QuestGetState('CursedForestSideQuests')
						return not quest.PlayerAttackedBeast
					end,
				}),
				PlaceObj('SectorIsInConflict', {
					Negate = true,
				}),
				PlaceObj('UnitIsOnMap', {
					TargetUnit = "TheBeast",
				}),
				PlaceObj('PlayerIsInSectors', {
					Sectors = {
						"C14",
					},
				}),
				PlaceObj('QuestIsVariableBool', {
					QuestId = "Beast",
					Vars = set({
	BeastRecruited = false,
}),
					__eval = function ()
						local quest = gv_Quests['Beast'] or QuestGetState('Beast')
						return not quest.BeastRecruited
					end,
				}),
			},
			Effects = {
				PlaceObj('GroupSetSide', {
					Side = "neutral",
					TargetUnit = "TheBeast",
				}),
			},
			ParamId = "TCE_BeastPostCombatHut",
			QuestId = "CursedForestSideQuests",
			requiredSectors = {
				"C14",
			},
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "Beast",
					Vars = set({
	BeastDead = false,
}),
					__eval = function ()
						local quest = gv_Quests['Beast'] or QuestGetState('Beast')
						return not quest.BeastDead
					end,
				}),
				PlaceObj('SectorIsInConflict', {
					Negate = true,
				}),
				PlaceObj('UnitIsOnMap', {
					TargetUnit = "TheBeast",
				}),
				PlaceObj('PlayerIsInSectors', {
					Negate = true,
					Sectors = {
						"C14",
					},
				}),
				PlaceObj('PlayerIsInSectors', {
					Negate = true,
					Sectors = {
						"D17",
					},
				}),
			},
			Effects = {
				PlaceObj('GroupSetBehaviorExit', {
					TargetUnit = "TheBeast",
					UseWeapons = true,
					closest = true,
				}),
			},
			ParamId = "TCE_BeastPostCombatLeave",
			QuestId = "CursedForestSideQuests",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "Beast",
					Vars = set( "Effigy_BelleEau" ),
					__eval = function ()
						local quest = gv_Quests['Beast'] or QuestGetState('Beast')
						return quest.Effigy_BelleEau
					end,
				}),
			},
			Effects = {
				PlaceObj('HideQuestBadge', {
					LogLine = 6,
					Quest = "CursedForestSideQuests",
				}),
			},
			Once = true,
			ParamId = "TCE_EffigyDone_D18",
			QuestId = "CursedForestSideQuests",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "ReduceRiverCampStrength",
					Vars = set( "EffigyConstructed" ),
					__eval = function ()
						local quest = gv_Quests['ReduceRiverCampStrength'] or QuestGetState('ReduceRiverCampStrength')
						return quest.EffigyConstructed
					end,
				}),
				PlaceObj('PlayerIsInSectors', {
					Sectors = {
						"E15",
					},
				}),
			},
			Effects = {
				PlaceObj('HideQuestBadge', {
					BadgeIdx = 2,
					LogLine = 6,
					Quest = "CursedForestSideQuests",
				}),
				PlaceObj('SectorEnterConflict', {
					disable_travel = true,
					sector_id = "E15",
				}),
			},
			Once = true,
			ParamId = "TCE_EffigyDone_E15",
			QuestId = "CursedForestSideQuests",
			requiredSectors = {
				"E15",
			},
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "Beast",
					Vars = set( "Effigy_D13" ),
					__eval = function ()
						local quest = gv_Quests['Beast'] or QuestGetState('Beast')
						return quest.Effigy_D13
					end,
				}),
			},
			Effects = {
				PlaceObj('HideQuestBadge', {
					BadgeIdx = 3,
					LogLine = 6,
					Quest = "CursedForestSideQuests",
				}),
			},
			Once = true,
			ParamId = "TCE_EffigyDone_D13",
			QuestId = "CursedForestSideQuests",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "Beast",
					Vars = set( "Effigy_E13" ),
					__eval = function ()
						local quest = gv_Quests['Beast'] or QuestGetState('Beast')
						return quest.Effigy_E13
					end,
				}),
			},
			Effects = {
				PlaceObj('HideQuestBadge', {
					BadgeIdx = 4,
					LogLine = 6,
					Quest = "CursedForestSideQuests",
				}),
			},
			Once = true,
			ParamId = "TCE_EffigyDone_E13",
			QuestId = "CursedForestSideQuests",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "Beast",
					Vars = set( "Effigy_D14" ),
					__eval = function ()
						local quest = gv_Quests['Beast'] or QuestGetState('Beast')
						return quest.Effigy_D14
					end,
				}),
			},
			Effects = {
				PlaceObj('HideQuestBadge', {
					BadgeIdx = 5,
					LogLine = 6,
					Quest = "CursedForestSideQuests",
				}),
			},
			Once = true,
			ParamId = "TCE_EffigyDone_D14",
			QuestId = "CursedForestSideQuests",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "Beast",
					Vars = set( "Effigy_D15" ),
					__eval = function ()
						local quest = gv_Quests['Beast'] or QuestGetState('Beast')
						return quest.Effigy_D15
					end,
				}),
			},
			Effects = {
				PlaceObj('HideQuestBadge', {
					BadgeIdx = 6,
					LogLine = 6,
					Quest = "CursedForestSideQuests",
				}),
			},
			Once = true,
			ParamId = "TCE_EffigyDone_D15",
			QuestId = "CursedForestSideQuests",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "Beast",
					Vars = set( "Effigy_C16" ),
					__eval = function ()
						local quest = gv_Quests['Beast'] or QuestGetState('Beast')
						return quest.Effigy_C16
					end,
				}),
			},
			Effects = {
				PlaceObj('HideQuestBadge', {
					BadgeIdx = 7,
					LogLine = 6,
					Quest = "CursedForestSideQuests",
				}),
			},
			Once = true,
			ParamId = "TCE_EffigyDone_C16",
			QuestId = "CursedForestSideQuests",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "Beast",
					Vars = set( "Effigy_BelleEau", "Effigy_C16", "Effigy_D13", "Effigy_D14", "Effigy_D15", "Effigy_E13" ),
					__eval = function ()
						local quest = gv_Quests['Beast'] or QuestGetState('Beast')
						return quest.Effigy_BelleEau and quest.Effigy_C16 and quest.Effigy_D13 and quest.Effigy_D14 and quest.Effigy_D15 and quest.Effigy_E13
					end,
				}),
			},
			Effects = {
				PlaceObj('QuestSetVariableBool', {
					Prop = "Completed",
					QuestId = "CursedForestSideQuests",
				}),
			},
			Once = true,
			ParamId = "TCE_CompleteQuest",
			QuestId = "CursedForestSideQuests",
		}),
	},
	Variables = {
		PlaceObj('QuestVarBool', {
			Name = "Completed",
		}),
		PlaceObj('QuestVarBool', {
			Name = "Given",
		}),
		PlaceObj('QuestVarBool', {
			Name = "Failed",
		}),
		PlaceObj('QuestVarBool', {
			Name = "NotStarted",
			Value = true,
		}),
		PlaceObj('QuestVarBool', {
			Name = "IlleMorat_JacuzziDone",
		}),
		PlaceObj('QuestVarBool', {
			Name = "IlleMorat_DrawingboardDone",
		}),
		PlaceObj('QuestVarBool', {
			Name = "IlleMorat_TrapDoorDone",
		}),
		PlaceObj('QuestVarNum', {
			Name = "GraveRandom",
			RandomRangeMax = 4,
			Value = 1,
		}),
		PlaceObj('QuestVarBool', {
			Name = "GraveGiven",
		}),
		PlaceObj('QuestVarBool', {
			Name = "GraveBushesCut",
		}),
		PlaceObj('QuestVarBool', {
			Name = "GraveFound",
		}),
		PlaceObj('QuestVarBool', {
			Name = "GraveReported",
		}),
		PlaceObj('QuestVarBool', {
			Name = "GraveDone",
		}),
		PlaceObj('QuestVarBool', {
			Name = "BonfireLit",
		}),
		PlaceObj('QuestVarBool', {
			Name = "MetaviraSapCollected",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_GraveGive",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_GraveFind",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_GraveReport",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_GraveDone",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_GravePayRespect",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_GraveFail",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_TeaPartySurvivor",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_TeaPartyDone",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_BeastRandomizeSpawn",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_BeastPostCombatLeave",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_BeastPostCombatMove",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_BeastPostCombatHut",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_BeastCabinCombat",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_EffigyDone_D18",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_EffigyDone_E15",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_EffigyDone_D13",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_EffigyDone_E13",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_EffigyDone_D14",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_EffigyDone_D15",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_EffigyDone_C16",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_CompleteQuest",
		}),
		PlaceObj('QuestVarBool', {
			Name = "PlayerAttackedBeast",
		}),
	},
	group = "CursedForest",
	id = "CursedForestSideQuests",
})

