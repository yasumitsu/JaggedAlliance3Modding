-- ========== GENERATED BY QuestsDef Editor (Ctrl-Alt-Q) DO NOT EDIT MANUALLY! ==========

PlaceObj('QuestsDef', {
	Author = "Boyan",
	DevNotes = "",
	DisplayName = T(833402939143, --[[QuestsDef AyeMom DisplayName]] "Headshot Hue"),
	NoteDefs = {
		LastNoteIdx = 15,
		PlaceObj('QuestNote', {
			Badges = {
				PlaceObj('QuestBadgePlacement', {
					BadgeUnit = "HeadshotHue",
					Sector = "K9",
				}),
			},
			HideConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "AyeMom",
					Vars = set( "Failed", "HeadshotHueStartSetPiece", "WigFound" ),
					__eval = function ()
						local quest = gv_Quests['AyeMom'] or QuestGetState('AyeMom')
						return quest.Failed or quest.HeadshotHueStartSetPiece or quest.WigFound
					end,
				}),
			},
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "AyeMom",
					Vars = set( "Given" ),
					__eval = function ()
						local quest = gv_Quests['AyeMom'] or QuestGetState('AyeMom')
						return quest.Given
					end,
				}),
			},
			Text = T(256072571955, --[[QuestsDef AyeMom Text]] "<em>Headshot Hue</em> at the <em><SectorName('K9')></em> needs a <em>red wig</em> to play a prank on the bartender <em>Lurch</em>"),
		}),
		PlaceObj('QuestNote', {
			Badges = {
				PlaceObj('QuestBadgePlacement', {
					BadgeUnit = "HeadshotHue",
					Sector = "K9",
				}),
			},
			HideConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "AyeMom",
					Vars = set( "Failed", "HeadshotHueStartSetPiece" ),
					__eval = function ()
						local quest = gv_Quests['AyeMom'] or QuestGetState('AyeMom')
						return quest.Failed or quest.HeadshotHueStartSetPiece
					end,
				}),
			},
			Idx = 3,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "AyeMom",
					Vars = set( "Given", "WigFound" ),
					__eval = function ()
						local quest = gv_Quests['AyeMom'] or QuestGetState('AyeMom')
						return quest.Given and quest.WigFound
					end,
				}),
			},
			Text = T(838695999745, --[[QuestsDef AyeMom Text]] "<em>Headshot Hue</em> at the <em><SectorName('K9')></em> needs the <em>wig</em> to dress like Lurch's mom in order to convince him to give up the <em>shotgun</em>"),
		}),
		PlaceObj('QuestNote', {
			Badges = {
				PlaceObj('QuestBadgePlacement', {
					BadgeUnit = "HeadshotHue",
					Sector = "K9",
				}),
			},
			CompletionConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "AyeMom",
					Vars = set( "HeadshotHueStartSetPiece" ),
					__eval = function ()
						local quest = gv_Quests['AyeMom'] or QuestGetState('AyeMom')
						return quest.HeadshotHueStartSetPiece
					end,
				}),
			},
			HideConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "AyeMom",
					Vars = set( "Failed", "Given", "HeadshotHueStartSetPiece" ),
					__eval = function ()
						local quest = gv_Quests['AyeMom'] or QuestGetState('AyeMom')
						return quest.Failed or quest.Given or quest.HeadshotHueStartSetPiece
					end,
				}),
			},
			Idx = 13,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "AyeMom",
					Vars = set({
	Given = false,
	WigFound = true,
}),
					__eval = function ()
						local quest = gv_Quests['AyeMom'] or QuestGetState('AyeMom')
						return not quest.Given and quest.WigFound
					end,
				}),
			},
			Text = T(990544601933, --[[QuestsDef AyeMom Text]] "Found a totally inconspicuous <em>Red curly wig</em>"),
		}),
		PlaceObj('QuestNote', {
			Badges = {
				PlaceObj('QuestBadgePlacement', {
					Sector = "L8",
				}),
				PlaceObj('QuestBadgePlacement', {
					Sector = "L9",
				}),
			},
			CompletionConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "AyeMom",
					Vars = set( "WigFound" ),
					__eval = function ()
						local quest = gv_Quests['AyeMom'] or QuestGetState('AyeMom')
						return quest.WigFound
					end,
				}),
			},
			HideConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "AyeMom",
					Vars = set( "Failed", "WigFound" ),
					__eval = function ()
						local quest = gv_Quests['AyeMom'] or QuestGetState('AyeMom')
						return quest.Failed or quest.WigFound
					end,
				}),
			},
			Idx = 2,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "AyeMom",
					Vars = set( "WigClue" ),
					__eval = function ()
						local quest = gv_Quests['AyeMom'] or QuestGetState('AyeMom')
						return quest.WigClue
					end,
				}),
			},
			Text = T(602065882929, --[[QuestsDef AyeMom Text]] "A suitable <em>wig</em> can be found at the <em>junk dealer's shop</em> in <em><SectorName('L8')></em> and on the head of the <em>Baroness</em> of <em><SectorName('L9')></em>"),
		}),
		PlaceObj('QuestNote', {
			Badges = {
				PlaceObj('QuestBadgePlacement', {
					BadgeUnit = "HeadshotHue",
					Sector = "K9",
				}),
			},
			HideConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "AyeMom",
					Vars = set( "Completed", "Failed", "GunTaken" ),
					__eval = function ()
						local quest = gv_Quests['AyeMom'] or QuestGetState('AyeMom')
						return quest.Completed or quest.Failed or quest.GunTaken
					end,
				}),
			},
			Idx = 4,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "AyeMom",
					Vars = set( "HeadshotHueStartSetPiece" ),
					__eval = function ()
						local quest = gv_Quests['AyeMom'] or QuestGetState('AyeMom')
						return quest.HeadshotHueStartSetPiece
					end,
				}),
			},
			Text = T(819072389284, --[[QuestsDef AyeMom Text]] "<em>Ma Baxter's Shotgun</em> is in the hands of <em>Headshot Hue</em> at the <em><SectorName('K9')></em>"),
		}),
		PlaceObj('QuestNote', {
			Badges = {
				PlaceObj('QuestBadgePlacement', {
					BadgeUnit = "Granny",
					Sector = "K9",
				}),
			},
			HideConditions = {
				PlaceObj('OR', {
					Conditions = {
						PlaceObj('QuestIsVariableBool', {
							Condition = "or",
							QuestId = "AyeMom",
							Vars = set( "ShotgunDonatedToGran", "ShotgunKept", "ShotgunSoldToGran" ),
							__eval = function ()
								local quest = gv_Quests['AyeMom'] or QuestGetState('AyeMom')
								return quest.ShotgunDonatedToGran or quest.ShotgunKept or quest.ShotgunSoldToGran
							end,
						}),
						PlaceObj('CheckIsPersistentUnitDead', {
							per_ses_id = "NPC_Granny",
						}),
					},
				}),
			},
			Idx = 7,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "AyeMom",
					Vars = set( "ShotgunShownGran" ),
					__eval = function ()
						local quest = gv_Quests['AyeMom'] or QuestGetState('AyeMom')
						return quest.ShotgunShownGran
					end,
				}),
			},
			Text = T(469879477271, --[[QuestsDef AyeMom Text]] "<em>Granny Cohani</em> at the <em><SectorName('K9')></em> is ready to give an arm and a leg for <em>Ma Baxter's Shotgun</em>"),
		}),
		PlaceObj('QuestNote', {
			AddInHistory = true,
			CompletionConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "AyeMom",
					Vars = set( "GunTaken" ),
					__eval = function ()
						local quest = gv_Quests['AyeMom'] or QuestGetState('AyeMom')
						return quest.GunTaken
					end,
				}),
			},
			Idx = 5,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "AyeMom",
					Vars = set( "GunTaken" ),
					__eval = function ()
						local quest = gv_Quests['AyeMom'] or QuestGetState('AyeMom')
						return quest.GunTaken
					end,
				}),
			},
			Text = T(222176542382, --[[QuestsDef AyeMom Text]] "<em>Outcome:</em> Took possession of <em>Ma Baxter's Shotgun</em>"),
		}),
		PlaceObj('QuestNote', {
			AddInHistory = true,
			CompletionConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "AyeMom",
					Vars = set( "HeadshotHueSetPieceDone" ),
					__eval = function ()
						local quest = gv_Quests['AyeMom'] or QuestGetState('AyeMom')
						return quest.HeadshotHueSetPieceDone
					end,
				}),
			},
			Idx = 14,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "AyeMom",
					Vars = set( "HeadshotHueSetPieceDone" ),
					__eval = function ()
						local quest = gv_Quests['AyeMom'] or QuestGetState('AyeMom')
						return quest.HeadshotHueSetPieceDone
					end,
				}),
			},
			Text = T(582913065634, --[[QuestsDef AyeMom Text]] "<em>Outcome:</em> Staged the performance of the century at the <em>Aye Bar</em>"),
		}),
		PlaceObj('QuestNote', {
			CompletionConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "AyeMom",
					Vars = set( "ShotgunSoldToGran" ),
					__eval = function ()
						local quest = gv_Quests['AyeMom'] or QuestGetState('AyeMom')
						return quest.ShotgunSoldToGran
					end,
				}),
			},
			Idx = 8,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "AyeMom",
					Vars = set( "ShotgunSoldToGran" ),
					__eval = function ()
						local quest = gv_Quests['AyeMom'] or QuestGetState('AyeMom')
						return quest.ShotgunSoldToGran
					end,
				}),
			},
			Text = T(206388939913, --[[QuestsDef AyeMom Text]] "<em>Outcome:</em> Sold <em>Ma Baxter's Shotgun</em> to <em>Granny Cohani</em>"),
		}),
		PlaceObj('QuestNote', {
			CompletionConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "AyeMom",
					Vars = set( "ShotgunDonatedToGran" ),
					__eval = function ()
						local quest = gv_Quests['AyeMom'] or QuestGetState('AyeMom')
						return quest.ShotgunDonatedToGran
					end,
				}),
			},
			Idx = 15,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "AyeMom",
					Vars = set( "ShotgunDonatedToGran" ),
					__eval = function ()
						local quest = gv_Quests['AyeMom'] or QuestGetState('AyeMom')
						return quest.ShotgunDonatedToGran
					end,
				}),
			},
			Text = T(892646583566, --[[QuestsDef AyeMom Text]] "<em>Outcome:</em> Donated <em>Ma Baxter's Shotgun</em> to <em>Granny Cohani</em>"),
		}),
		PlaceObj('QuestNote', {
			CompletionConditions = {
				PlaceObj('CheckIsPersistentUnitDead', {
					per_ses_id = "NPC_HeadshotHue",
				}),
			},
			Idx = 9,
			ShowConditions = {
				PlaceObj('CheckIsPersistentUnitDead', {
					per_ses_id = "NPC_HeadshotHue",
				}),
			},
			Text = T(170224960967, --[[QuestsDef AyeMom Text]] "<em>Outcome:</em> <em>Headshot Hue</em> is dead"),
		}),
		PlaceObj('QuestNote', {
			CompletionConditions = {
				PlaceObj('CheckIsPersistentUnitDead', {
					per_ses_id = "NPC_Lurch",
				}),
			},
			Idx = 10,
			ShowConditions = {
				PlaceObj('CheckIsPersistentUnitDead', {
					per_ses_id = "NPC_Lurch",
				}),
			},
			Text = T(269165786167, --[[QuestsDef AyeMom Text]] "<em>Outcome:</em> <em>Lurch</em> is dead"),
		}),
	},
	QuestGroup = "Port Cacao",
	TCEs = {
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('UnitSquadHasItem', {
					ItemId = "Wig",
				}),
			},
			Effects = {
				PlaceObj('QuestSetVariableBool', {
					Prop = "WigFound",
					QuestId = "AyeMom",
				}),
			},
			Once = true,
			ParamId = "TCE_WigFound",
			QuestId = "AyeMom",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('PlayerIsInSectors', {
					Sectors = {
						"K9",
					},
				}),
				PlaceObj('QuestIsVariableBool', {
					QuestId = "AyeMom",
					Vars = set( "HeadshotHueStartSetPiece" ),
					__eval = function ()
						local quest = gv_Quests['AyeMom'] or QuestGetState('AyeMom')
						return quest.HeadshotHueStartSetPiece
					end,
				}),
			},
			Effects = {
				PlaceObj('PlaySetpiece', {
					setpiece = "LurchsMom",
				}),
				PlaceObj('QuestSetVariableBool', {
					Prop = "HeadshotHueSetPieceDone",
					QuestId = "AyeMom",
				}),
				PlaceObj('CityGrantLoyalty', {
					Amount = 5,
					City = "PortDiancie",
					SpecialConversationMessage = T(413825026305, --[[QuestsDef AyeMom SpecialConversationMessage]] "helped <em>Headshot Hue</em> play a prank on Lurch"),
				}),
				PlaceObj('GrantExperienceSector', {
					Amount = "XPQuestReward_Minor",
					logImportant = true,
				}),
			},
			Once = true,
			ParamId = "TCE_SetPieceStart",
			QuestId = "AyeMom",
			requiredSectors = {
				"K9",
			},
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('PlayerIsInSectors', {
					Sectors = {
						"K9",
					},
				}),
				PlaceObj('UnitSquadHasItem', {
					ItemId = "Auto5_quest",
				}),
			},
			Effects = {
				PlaceObj('QuestSetVariableBool', {
					Prop = "GunTaken",
					QuestId = "AyeMom",
				}),
			},
			Once = true,
			ParamId = "TCE_GunTaken",
			QuestId = "AyeMom",
			requiredSectors = {
				"K9",
			},
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('PlayerIsInSectors', {
					Sectors = {
						"K9",
					},
				}),
				PlaceObj('QuestIsVariableBool', {
					QuestId = "AyeMom",
					Vars = set({
	Completed = false,
}),
					__eval = function ()
						local quest = gv_Quests['AyeMom'] or QuestGetState('AyeMom')
						return not quest.Completed
					end,
				}),
				PlaceObj('QuestIsVariableBool', {
					QuestId = "_GroupsAttacked",
					Vars = set({
	Lurch = false,
}),
					__eval = function ()
						local quest = gv_Quests['_GroupsAttacked'] or QuestGetState('_GroupsAttacked')
						return not quest.Lurch
					end,
				}),
				PlaceObj('UnitSquadHasItem', {
					ItemId = "Auto5_quest",
				}),
			},
			Effects = {
				PlaceObj('GrantExperienceSector', {
					Amount = "XPQuestReward_Medium",
					logImportant = true,
				}),
				PlaceObj('QuestSetVariableBool', {
					Prop = "Completed",
					QuestId = "AyeMom",
				}),
			},
			Once = true,
			ParamId = "TCE_Completed",
			QuestId = "AyeMom",
			requiredSectors = {
				"K9",
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
			Name = "AllowGunContainer",
		}),
		PlaceObj('QuestVarBool', {
			Name = "GunTaken",
		}),
		PlaceObj('QuestVarBool', {
			Name = "HeadshotHueBet",
		}),
		PlaceObj('QuestVarBool', {
			Name = "HeadshotHueDice",
		}),
		PlaceObj('QuestVarBool', {
			Name = "HeadshotHueStartSetPiece",
		}),
		PlaceObj('QuestVarBool', {
			Name = "HeadshotHueSetPieceDone",
		}),
		PlaceObj('QuestVarBool', {
			Name = "HeadshotHueHeadhunters",
		}),
		PlaceObj('QuestVarBool', {
			Name = "HeadshotHuePranks",
		}),
		PlaceObj('QuestVarBool', {
			Name = "WigClue",
		}),
		PlaceObj('QuestVarBool', {
			Name = "WigFound",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_SetPieceStart",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_WigFound",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_GunTaken",
		}),
		PlaceObj('QuestVarBool', {
			Name = "ShotgunShownGran",
		}),
		PlaceObj('QuestVarBool', {
			Name = "ShotgunSoldToGran",
		}),
		PlaceObj('QuestVarBool', {
			Name = "ShotgunDonatedToGran",
		}),
		PlaceObj('QuestVarBool', {
			Name = "ShotgunKept",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_Completed",
		}),
	},
	group = "PortCacao",
	id = "AyeMom",
})

