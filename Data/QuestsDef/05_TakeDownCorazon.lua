-- ========== GENERATED BY QuestsDef Editor (Ctrl-Alt-Q) DO NOT EDIT MANUALLY! ==========

PlaceObj('QuestsDef', {
	Author = "Boyan",
	Chapter = "Act2",
	DevNotes = "",
	DisplayName = T(645091362908, --[[QuestsDef 05_TakeDownCorazon DisplayName]] "Taking down Corazon"),
	Main = true,
	NoteDefs = {
		LastNoteIdx = 23,
		PlaceObj('QuestNote', {
			CompletionConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "05_TakeDownCorazon",
					Vars = set( "Conv_CorazonKilled", "Conv_CorazonLeft", "Conv_CorazonStay" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
						return quest.Conv_CorazonKilled or quest.Conv_CorazonLeft or quest.Conv_CorazonStay
					end,
				}),
			},
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "05_TakeDownCorazon",
					Vars = set( "Given" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
						return quest.Given
					end,
				}),
			},
			Text = T(476733409490, --[[QuestsDef 05_TakeDownCorazon Text]] "<em>Corazon Santiago</em> must be defeated in order to clear A.I.M. of the accusations of <em>war crimes</em>"),
		}),
		PlaceObj('QuestNote', {
			Badges = {
				PlaceObj('QuestBadgePlacement', {
					Sector = "H4",
				}),
			},
			HideConditions = {
				PlaceObj('CheckOR', {
					Conditions = {
						PlaceObj('PlayerIsInSectors', {
							Sectors = {
								"H4",
							},
						}),
						PlaceObj('QuestIsVariableBool', {
							Condition = "or",
							QuestId = "05_TakeDownCorazon",
							Vars = set( "CorazonLocation" ),
							__eval = function ()
								local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
								return quest.CorazonLocation
							end,
						}),
					},
				}),
			},
			Idx = 17,
			Scouting = true,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "05_TakeDownCorazon",
					Vars = set({
	CorazonLocation = false,
	Given = true,
}),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
						return not quest.CorazonLocation and quest.Given
					end,
				}),
			},
			Text = T(515186126291, --[[QuestsDef 05_TakeDownCorazon Text]] "Corazon has established her base of operations at <em><SectorName('H4')></em>"),
		}),
		PlaceObj('QuestNote', {
			Badges = {
				PlaceObj('QuestBadgePlacement', {
					Sector = "H4",
				}),
			},
			HideConditions = {
				PlaceObj('CheckOR', {
					Conditions = {
						PlaceObj('SectorCheckOwner', {
							sector_id = "H4",
						}),
						PlaceObj('QuestIsVariableBool', {
							Condition = "or",
							QuestId = "05_TakeDownCorazon",
							Vars = set( "Conv_CorazonKilled", "Conv_CorazonLeft" ),
							__eval = function ()
								local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
								return quest.Conv_CorazonKilled or quest.Conv_CorazonLeft
							end,
						}),
					},
				}),
			},
			Idx = 16,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "05_TakeDownCorazon",
					Vars = set( "Given" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
						return quest.Given
					end,
				}),
				PlaceObj('CheckOR', {
					Conditions = {
						PlaceObj('PlayerIsInSectors', {
							Sectors = {
								"H4",
							},
						}),
						PlaceObj('QuestIsVariableBool', {
							QuestId = "05_TakeDownCorazon",
							Vars = set( "CorazonLocation" ),
							__eval = function ()
								local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
								return quest.CorazonLocation
							end,
						}),
					},
				}),
			},
			Text = T(771484775659, --[[QuestsDef 05_TakeDownCorazon Text]] "Corazon has established her base of operations at <em><SectorName('H4')></em>"),
		}),
		PlaceObj('QuestNote', {
			Badges = {
				PlaceObj('QuestBadgePlacement', {
					BadgeUnit = "Pierre",
					Sector = "H4",
				}),
			},
			HideConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "ErnieSideQuests_WorldFlip",
					Vars = set( "FortAttackStarted" ),
					__eval = function ()
						local quest = gv_Quests['ErnieSideQuests_WorldFlip'] or QuestGetState('ErnieSideQuests_WorldFlip')
						return quest.FortAttackStarted
					end,
				}),
			},
			Idx = 18,
			ShowConditions = {
				PlaceObj('BanterHasPlayed', {
					Banters = {
						"ErnieWorldFlip04_FortEntered",
					},
				}),
			},
			Text = T(466894558923, --[[QuestsDef 05_TakeDownCorazon Text]] "<em>Pierre</em> and his Ernie Rangers are waiting for a sign to attack"),
		}),
		PlaceObj('QuestNote', {
			Badges = {
				PlaceObj('QuestBadgePlacement', {
					Sector = "H4_Underground",
				}),
				PlaceObj('QuestBadgePlacement', {
					BadgeUnit = "Underground",
					Sector = "H4",
				}),
			},
			HideConditions = {
				PlaceObj('CheckOR', {
					Conditions = {
						PlaceObj('PlayerIsInSectors', {
							Sectors = {
								"H4_Underground",
							},
						}),
						PlaceObj('SectorCheckOwner', {
							sector_id = "H4_Underground",
						}),
						PlaceObj('QuestIsVariableBool', {
							Condition = "or",
							QuestId = "05_TakeDownCorazon",
							Vars = set( "Conv_CorazonKilled", "Conv_CorazonLeft" ),
							__eval = function ()
								local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
								return quest.Conv_CorazonKilled or quest.Conv_CorazonLeft
							end,
						}),
					},
				}),
			},
			Idx = 14,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "05_TakeDownCorazon",
					Vars = set( "Given" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
						return quest.Given
					end,
				}),
				PlaceObj('PlayerIsInSectors', {
					Sectors = {
						"H4",
					},
				}),
				PlaceObj('SectorCheckOwner', {
					sector_id = "H4",
				}),
			},
			Text = T(772623904539, --[[QuestsDef 05_TakeDownCorazon Text]] "There is no sign of <em>Corazon</em> at the Fort - she must be hiding <em>underground</em> in <em><SectorName('H4')></em>"),
		}),
		PlaceObj('QuestNote', {
			Badges = {
				PlaceObj('QuestBadgePlacement', {
					BadgeUnit = "CorazonSantiago",
					Sector = "H4",
				}),
			},
			HideConditions = {
				PlaceObj('CheckOR', {
					Conditions = {
						PlaceObj('SectorCheckOwner', {
							sector_id = "H4_Underground",
						}),
						PlaceObj('QuestIsVariableBool', {
							Condition = "or",
							QuestId = "05_TakeDownCorazon",
							Vars = set( "Conv_CorazonKilled", "Conv_CorazonLeft" ),
							__eval = function ()
								local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
								return quest.Conv_CorazonKilled or quest.Conv_CorazonLeft
							end,
						}),
					},
				}),
			},
			Idx = 23,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "05_TakeDownCorazon",
					Vars = set( "Given" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
						return quest.Given
					end,
				}),
				PlaceObj('PlayerIsInSectors', {
					Sectors = {
						"H4_Underground",
					},
				}),
			},
			Text = T(550082683771, --[[QuestsDef 05_TakeDownCorazon Text]] "<em>Corazon</em> has retreated to <em><SectorName('H4_Underground')></em>"),
		}),
		PlaceObj('QuestNote', {
			Badges = {
				PlaceObj('QuestBadgePlacement', {
					BadgeUnit = "CorazonSantiago",
					Sector = "H4_Underground",
				}),
			},
			HideConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "05_TakeDownCorazon",
					Vars = set( "Conv_CorazonKilled", "Conv_CorazonLeft", "Conv_CorazonStay" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
						return quest.Conv_CorazonKilled or quest.Conv_CorazonLeft or quest.Conv_CorazonStay
					end,
				}),
			},
			Idx = 15,
			ShowConditions = {
				PlaceObj('SectorCheckOwner', {
					sector_id = "H4_Underground",
				}),
			},
			Text = T(595319900155, --[[QuestsDef 05_TakeDownCorazon Text]] "Time to have a word with <em>Corazon Santiago</em>"),
		}),
		PlaceObj('QuestNote', {
			AddInHistory = true,
			CompletionConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "05_TakeDownCorazon",
					Vars = set( "Conv_CorazonLeft" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
						return quest.Conv_CorazonLeft
					end,
				}),
			},
			Idx = 21,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "05_TakeDownCorazon",
					Vars = set( "Conv_CorazonLeft" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
						return quest.Conv_CorazonLeft
					end,
				}),
			},
			Text = T(783320423918, --[[QuestsDef 05_TakeDownCorazon Text]] "<em>Outcome:</em> <em>Corazon Santiago</em> was defeated and will answer in court"),
		}),
		PlaceObj('QuestNote', {
			AddInHistory = true,
			CompletionConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "05_TakeDownCorazon",
					Vars = set( "Conv_CorazonKilled" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
						return quest.Conv_CorazonKilled
					end,
				}),
			},
			Idx = 22,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "05_TakeDownCorazon",
					Vars = set( "Conv_CorazonKilled" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
						return quest.Conv_CorazonKilled
					end,
				}),
			},
			Text = T(212379528791, --[[QuestsDef 05_TakeDownCorazon Text]] "<em>Outcome:</em> Executed <em>Corazon Santiago</em>"),
		}),
	},
	QuestGroup = "The Fate Of Grand Chien",
	TCEs = {
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "05_TakeDownCorazon",
					Vars = set( "Given" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
						return quest.Given
					end,
				}),
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "05_TakeDownCorazon",
					Vars = set( "Conv_CorazonKilled", "Conv_CorazonLeft", "Conv_CorazonStay" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
						return quest.Conv_CorazonKilled or quest.Conv_CorazonLeft or quest.Conv_CorazonStay
					end,
				}),
			},
			Effects = {
				PlaceObj('ConditionalEffect', {
					'Conditions', {
						PlaceObj('QuestIsVariableBool', {
							QuestId = "05_TakeDownMajor",
							Vars = set({
	Completed = false,
}),
							__eval = function ()
								local quest = gv_Quests['05_TakeDownMajor'] or QuestGetState('05_TakeDownMajor')
								return not quest.Completed
							end,
						}),
					},
					'Effects', {
						PlaceObj('QuestSetVariableBool', {
							Prop = "PresidentStillMissing",
							QuestId = "05_TakeDownCorazon",
						}),
					},
				}),
				PlaceObj('ConditionalEffect', {
					'Conditions', {
						PlaceObj('QuestIsVariableBool', {
							Condition = "or",
							QuestId = "05_TakeDownCorazon",
							Vars = set( "Conv_BribeIntel" ),
							__eval = function ()
								local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
								return quest.Conv_BribeIntel
							end,
						}),
						PlaceObj('CheckIsPersistentUnitDead', {
							Negate = true,
							per_ses_id = "NPC_Corazon",
						}),
					},
					'Effects', {
						PlaceObj('SectorGrantIntel', {
							sector_id = "H16",
						}),
						PlaceObj('SectorGrantIntel', {
							sector_id = "K16",
						}),
					},
				}),
				PlaceObj('ConditionalEffect', {
					'Conditions', {
						PlaceObj('QuestIsVariableBool', {
							Condition = "or",
							QuestId = "05_TakeDownCorazon",
							Vars = set( "Conv_BribeMoney" ),
							__eval = function ()
								local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
								return quest.Conv_BribeMoney
							end,
						}),
						PlaceObj('CheckIsPersistentUnitDead', {
							Negate = true,
							per_ses_id = "NPC_Corazon",
						}),
					},
					'Effects', {
						PlaceObj('PlayerGrantMoney', {
							Amount = 30000,
						}),
					},
				}),
				PlaceObj('QuestSetVariableBool', {
					Prop = "Completed",
					QuestId = "05_TakeDownCorazon",
				}),
				PlaceObj('GrantExperienceSector', {
					Amount = "XPQuestReward_Large",
					logImportant = true,
				}),
			},
			Once = true,
			ParamId = "TCE_CorazoneDone",
			QuestId = "05_TakeDownCorazon",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "05_TakeDownCorazon",
					Vars = set( "CorazonEvidence_Hermit" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
						return quest.CorazonEvidence_Hermit
					end,
				}),
			},
			Effects = {
				PlaceObj('QuestSetVariableNum', {
					Amount = 1,
					Prop = "Evidence",
					QuestId = "05_TakeDownCorazon",
				}),
				PlaceObj('LogMessageAdd', {
					message = T(182731734961, --[[QuestsDef 05_TakeDownCorazon message]] "gained a piece of <em>evidence</em> against Corazon"),
				}),
			},
			Once = true,
			ParamId = "TCE_GainEvidence_Hermit",
			QuestId = "05_TakeDownCorazon",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "05_TakeDownCorazon",
					Vars = set( "CorazonEvidence_Biff" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
						return quest.CorazonEvidence_Biff
					end,
				}),
			},
			Effects = {
				PlaceObj('QuestSetVariableNum', {
					Amount = 1,
					Prop = "Evidence",
					QuestId = "05_TakeDownCorazon",
				}),
				PlaceObj('LogMessageAdd', {
					message = T(182731734961, --[[QuestsDef 05_TakeDownCorazon message]] "gained a piece of <em>evidence</em> against Corazon"),
				}),
			},
			Once = true,
			ParamId = "TCE_GainEvidence_Biff",
			QuestId = "05_TakeDownCorazon",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "05_TakeDownCorazon",
					Vars = set( "CorazonEvidence_RefugeeCamp" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
						return quest.CorazonEvidence_RefugeeCamp
					end,
				}),
			},
			Effects = {
				PlaceObj('QuestSetVariableNum', {
					Amount = 1,
					Prop = "Evidence",
					QuestId = "05_TakeDownCorazon",
				}),
				PlaceObj('LogMessageAdd', {
					message = T(182731734961, --[[QuestsDef 05_TakeDownCorazon message]] "gained a piece of <em>evidence</em> against Corazon"),
				}),
			},
			Once = true,
			ParamId = "TCE_GainEvidence_RefugeeCamp",
			QuestId = "05_TakeDownCorazon",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "05_TakeDownCorazon",
					Vars = set( "CorazonEvidence_Major" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
						return quest.CorazonEvidence_Major
					end,
				}),
			},
			Effects = {
				PlaceObj('QuestSetVariableNum', {
					Amount = 1,
					Prop = "Evidence",
					QuestId = "05_TakeDownCorazon",
				}),
				PlaceObj('LogMessageAdd', {
					message = T(182731734961, --[[QuestsDef 05_TakeDownCorazon message]] "gained a piece of <em>evidence</em> against Corazon"),
				}),
			},
			Once = true,
			ParamId = "TCE_GainEvidence_Major",
			QuestId = "05_TakeDownCorazon",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "05_TakeDownCorazon",
					Vars = set( "CorazonEvidence_FortBrigand" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
						return quest.CorazonEvidence_FortBrigand
					end,
				}),
			},
			Effects = {
				PlaceObj('QuestSetVariableNum', {
					Amount = 1,
					Prop = "Evidence",
					QuestId = "05_TakeDownCorazon",
				}),
				PlaceObj('LogMessageAdd', {
					message = T(182731734961, --[[QuestsDef 05_TakeDownCorazon message]] "gained a piece of <em>evidence</em> against Corazon"),
				}),
			},
			Once = true,
			ParamId = "TCE_GainEvidence_FortBrigand",
			QuestId = "05_TakeDownCorazon",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "05_TakeDownCorazon",
					Vars = set( "CorazonEvidence_ErnieFort" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
						return quest.CorazonEvidence_ErnieFort
					end,
				}),
			},
			Effects = {
				PlaceObj('QuestSetVariableNum', {
					Amount = 1,
					Prop = "Evidence",
					QuestId = "05_TakeDownCorazon",
				}),
				PlaceObj('LogMessageAdd', {
					message = T(182731734961, --[[QuestsDef 05_TakeDownCorazon message]] "gained a piece of <em>evidence</em> against Corazon"),
				}),
			},
			Once = true,
			ParamId = "TCE_GainEvidence_ErnieFort",
			QuestId = "05_TakeDownCorazon",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('QuestIsVariableNum', {
					AgainstVar = true,
					Amount = 4,
					Condition = ">",
					Prop = "Evidence",
					Prop2 = "EvidenceRequired",
					QuestId = "05_TakeDownCorazon",
					QuestId2 = "05_TakeDownCorazon",
				}),
			},
			Effects = {
				PlaceObj('QuestSetVariableBool', {
					Prop = "Completed",
					QuestId = "Evidence",
				}),
			},
			Once = true,
			ParamId = "TCE_CompleteEvidence",
			QuestId = "05_TakeDownCorazon",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "05_TakeDownCorazon",
					Vars = set( "Given" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
						return quest.Given
					end,
				}),
				PlaceObj('PlayerIsInSectors', {
					Sectors = {
						"H4",
					},
				}),
			},
			Effects = {
				PlaceObj('PlayBanterEffect', {
					Banters = {
						"FortCorazon01_radio",
					},
					FallbackToMerc = true,
					searchInMarker = false,
				}),
			},
			Once = true,
			ParamId = "TCE_CorazonBanterOnEnter",
			QuestId = "05_TakeDownCorazon",
			requiredSectors = {
				"H4",
			},
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "05_TakeDownCorazon",
					Vars = set( "Given" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
						return quest.Given
					end,
				}),
				PlaceObj('PlayerIsInSectors', {
					Sectors = {
						"H4",
					},
				}),
				PlaceObj('SectorIsInConflict', {
					Negate = true,
					sector_id = "H4",
				}),
			},
			Effects = {
				PlaceObj('PlayBanterEffect', {
					Banters = {
						"FortCorazon02_radio",
					},
					FallbackToMerc = true,
					searchInMarker = false,
				}),
			},
			Once = true,
			ParamId = "TCE_CorazonBanterOnFortCaptured",
			QuestId = "05_TakeDownCorazon",
			requiredSectors = {
				"H4",
			},
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('PlayerIsInSectors', {
					Sectors = {
						"H4_Underground",
					},
				}),
				PlaceObj('CombatIsActive', {}),
				PlaceObj('BanterHasPlayed', {
					Banters = {
						"FortCorazon04_setpiece",
					},
					WaitOver = true,
				}),
			},
			Effects = {
				PlaceObj('PlayBanterEffect', {
					Banters = {
						"FortCorazon04a_reactions",
					},
					banterSequentialWaitFor = "BanterStart",
					searchInMap = true,
					searchInMarker = false,
				}),
			},
			Once = true,
			ParamId = "TCE_MercCommentsOnDeploy",
			QuestId = "05_TakeDownCorazon",
			requiredSectors = {
				"H4_Underground",
			},
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('UnitIsAroundMarkerOfGroup', {
					DisableContextModification = true,
					MarkerGroup = "Room1_Left",
					TargetUnit = "any merc",
				}),
			},
			Effects = {
				PlaceObj('PlayBanterEffect', {
					Banters = {
						"FortCorazonSoldiers02_dining",
					},
					banterSequentialWaitFor = "BanterStart",
					searchInMap = true,
					searchInMarker = false,
				}),
			},
			Once = true,
			ParamId = "TCE_GuardsOnEnterDiningRoom",
			QuestId = "05_TakeDownCorazon",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "05_TakeDownCorazon",
					Vars = set( "Given" ),
					__eval = function ()
						local quest = gv_Quests['05_TakeDownCorazon'] or QuestGetState('05_TakeDownCorazon')
						return quest.Given
					end,
				}),
				PlaceObj('PlayerIsInSectors', {
					Sectors = {
						"H4_Underground",
					},
				}),
				PlaceObj('VillainIsDefeated', {
					Group = "CorazonSantiagoEnemy",
					Negate = true,
				}),
				PlaceObj('UnitIsAroundMarkerOfGroup', {
					MarkerGroup = "FinalRoom_Corazon",
					TargetUnit = "CorazonSantiagoEnemy",
				}),
				PlaceObj('UnitIsAroundMarkerOfGroup', {
					MarkerGroup = "FinalRoom_Corazon",
					TargetUnit = "any merc",
				}),
			},
			Effects = {
				PlaceObj('PlayBanterEffect', {
					Banters = {
						"FortCorazon05_command",
					},
					FallbackToMerc = true,
					searchInMarker = false,
				}),
			},
			Once = true,
			ParamId = "TCE_CorazonBanterOnEnterCommandRoom",
			QuestId = "05_TakeDownCorazon",
			requiredSectors = {
				"H4_Underground",
			},
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('PlayerIsInSectors', {
					Sectors = {
						"H4_Underground",
					},
				}),
				PlaceObj('CheckExpression', {
					Expression = function (self, obj) return IsKindOf(g_Encounter, "BossfightCorazon") and g_Encounter.right_gas_trigger end,
				}),
			},
			Effects = {
				PlaceObj('ConditionalEffect', {
					'Conditions', {
						PlaceObj('CombatIsActive', {}),
						PlaceObj('BanterHasPlayed', {
							Banters = {
								"FortCorazonSoldiers01_gas",
							},
							Negate = true,
						}),
					},
					'Effects', {
						PlaceObj('PlayBanterEffect', {
							Banters = {
								"FortCorazonSoldiers01_gas",
							},
							banterSequentialWaitFor = "BanterStart",
							searchInMap = true,
							searchInMarker = false,
						}),
					},
				}),
				PlaceObj('Explosion', {
					Damage = 0,
					ExplosionType = "ToxicGasGrenade",
					LocationGroup = "Gas_2",
				}),
				PlaceObj('Explosion', {
					Damage = 0,
					ExplosionType = "ToxicGasGrenade",
					LocationGroup = "Gas_1",
				}),
			},
			Once = true,
			ParamId = "TCE_FightGasTrigger_Right",
			QuestId = "05_TakeDownCorazon",
			requiredSectors = {
				"H4_Underground",
			},
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('PlayerIsInSectors', {
					Sectors = {
						"H4_Underground",
					},
				}),
				PlaceObj('CheckExpression', {
					Expression = function (self, obj) return IsKindOf(g_Encounter, "BossfightCorazon") and g_Encounter.hallway_smoke_trigger end,
				}),
			},
			Effects = {
				PlaceObj('ConditionalEffect', {
					'Conditions', {
						PlaceObj('CombatIsActive', {}),
					},
				}),
				PlaceObj('Explosion', {
					Damage = 0,
					ExplosionType = "SmokeGrenade",
					LocationGroup = "Smoke_1",
					aoeType = "smoke",
				}),
				PlaceObj('Explosion', {
					Damage = 0,
					ExplosionType = "SmokeGrenade",
					LocationGroup = "Smoke_2",
					aoeType = "smoke",
				}),
				PlaceObj('Explosion', {
					Damage = 0,
					ExplosionType = "SmokeGrenade",
					LocationGroup = "Smoke_3",
					aoeType = "smoke",
				}),
				PlaceObj('Explosion', {
					Damage = 0,
					ExplosionType = "SmokeGrenade",
					LocationGroup = "Smoke_4",
					aoeType = "smoke",
				}),
				PlaceObj('Explosion', {
					Damage = 0,
					ExplosionType = "SmokeGrenade",
					LocationGroup = "Smoke_5",
					aoeType = "smoke",
				}),
				PlaceObj('Explosion', {
					Damage = 0,
					ExplosionType = "SmokeGrenade",
					LocationGroup = "Smoke_6",
					aoeType = "smoke",
				}),
			},
			Once = true,
			ParamId = "TCE_FightSmokeTrigger_Hallway",
			QuestId = "05_TakeDownCorazon",
			requiredSectors = {
				"H4_Underground",
			},
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
			Name = "CorazonLeave",
		}),
		PlaceObj('QuestVarBool', {
			Name = "CorazonLocation",
		}),
		PlaceObj('QuestVarNum', {
			Name = "Evidence",
		}),
		PlaceObj('QuestVarNum', {
			Name = "EvidenceRequired",
			Value = 4,
		}),
		PlaceObj('QuestVarBool', {
			Name = "CorazonEvidence_Hermit",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_GainEvidence_Hermit",
		}),
		PlaceObj('QuestVarBool', {
			Name = "CorazonEvidence_Biff",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_GainEvidence_Biff",
		}),
		PlaceObj('QuestVarBool', {
			Name = "CorazonEvidence_RefugeeCamp",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_GainEvidence_RefugeeCamp",
		}),
		PlaceObj('QuestVarBool', {
			Name = "CorazonEvidence_Major",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_GainEvidence_Major",
		}),
		PlaceObj('QuestVarBool', {
			Name = "CorazonEvidence_FortBrigand",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_GainEvidence_FortBrigand",
		}),
		PlaceObj('QuestVarBool', {
			Name = "CorazonEvidence_ErnieFort",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_GainEvidence_ErnieFort",
		}),
		PlaceObj('QuestVarBool', {
			Name = "PresidentStillMissing",
		}),
		PlaceObj('QuestVarBool', {
			Name = "Conv_Progress",
		}),
		PlaceObj('QuestVarBool', {
			Name = "Conv_Cornered",
		}),
		PlaceObj('QuestVarBool', {
			Name = "Conv_BribeMoney",
		}),
		PlaceObj('QuestVarBool', {
			Name = "Conv_BribeIntel",
		}),
		PlaceObj('QuestVarBool', {
			Name = "Conv_CorazonKilled",
		}),
		PlaceObj('QuestVarBool', {
			Name = "Conv_CorazonLeft",
		}),
		PlaceObj('QuestVarBool', {
			Name = "Conv_CorazonStay",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_CorazoneDone",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_CorazonBanterOnEnter",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_CorazonBanterOnFortCaptured",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_MercCommentsOnDeploy",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_GuardsOnEnterDiningRoom",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_CorazonBanterOnEnterCommandRoom",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_CompleteEvidence",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_FightGasTrigger_Right",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_FightSmokeTrigger_Hallway",
		}),
	},
	group = "Main",
	id = "05_TakeDownCorazon",
})

