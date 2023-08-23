-- ========== GENERATED BY QuestsDef Editor (Ctrl-Alt-Q) DO NOT EDIT MANUALLY! ==========

PlaceObj('QuestsDef', {
	DisplayName = T(388846886811, --[[QuestsDef ChienSauvage DisplayName]] "Petta and the hyenas"),
	KillTCEsConditions = {
		PlaceObj('QuestIsVariableBool', {
			Condition = "or",
			QuestId = "ChienSauvage",
			Vars = set( "Completed", "Failed" ),
			__eval = function ()
				local quest = gv_Quests['ChienSauvage'] or QuestGetState('ChienSauvage')
				return quest.Completed or quest.Failed
			end,
		}),
	},
	NoteDefs = {
		LastNoteIdx = 6,
		PlaceObj('QuestNote', {
			Badges = {
				PlaceObj('QuestBadgePlacement', {
					BadgeUnit = "Peta",
					Sector = "E16",
				}),
			},
			CompletionConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "ChienSauvage",
					Vars = set( "Completed", "Failed", "PetaLetsHyenasOut" ),
					__eval = function ()
						local quest = gv_Quests['ChienSauvage'] or QuestGetState('ChienSauvage')
						return quest.Completed or quest.Failed or quest.PetaLetsHyenasOut
					end,
				}),
			},
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "ChienSauvage",
					Vars = set( "Given" ),
					__eval = function ()
						local quest = gv_Quests['ChienSauvage'] or QuestGetState('ChienSauvage')
						return quest.Given
					end,
				}),
			},
			Text = T(253960439295, --[[QuestsDef ChienSauvage Text]] "There is an eco activist imprisoned at <em><SectorName('E16')></em> whom the Legion means to throw into the hyena fighting pit"),
		}),
		PlaceObj('QuestNote', {
			CompletionConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "ChienSauvage",
					Vars = set( "Completed", "Failed", "HyenasDead" ),
					__eval = function ()
						local quest = gv_Quests['ChienSauvage'] or QuestGetState('ChienSauvage')
						return quest.Completed or quest.Failed or quest.HyenasDead
					end,
				}),
			},
			Idx = 2,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "ChienSauvage",
					Vars = set( "PetaLetsHyenasOut" ),
					__eval = function ()
						local quest = gv_Quests['ChienSauvage'] or QuestGetState('ChienSauvage')
						return quest.PetaLetsHyenasOut
					end,
				}),
			},
			Text = T(835836274183, --[[QuestsDef ChienSauvage Text]] "Petta let the <em>hyenas</em> out"),
		}),
		PlaceObj('QuestNote', {
			CompletionConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "ChienSauvage",
					Vars = set( "HyenasDead" ),
					__eval = function ()
						local quest = gv_Quests['ChienSauvage'] or QuestGetState('ChienSauvage')
						return quest.HyenasDead
					end,
				}),
			},
			Idx = 5,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					Condition = "or",
					QuestId = "ChienSauvage",
					Vars = set( "HyenasDead" ),
					__eval = function ()
						local quest = gv_Quests['ChienSauvage'] or QuestGetState('ChienSauvage')
						return quest.HyenasDead
					end,
				}),
			},
			Text = T(919210831059, --[[QuestsDef ChienSauvage Text]] "The <em>hyenas</em> in Camp Chien Sauvage had to die"),
		}),
		PlaceObj('QuestNote', {
			AddInHistory = true,
			CompletionConditions = {
				PlaceObj('CheckIsPersistentUnitDead', {
					per_ses_id = "NPC_Peta",
				}),
			},
			Idx = 4,
			ShowConditions = {
				PlaceObj('CheckIsPersistentUnitDead', {
					per_ses_id = "NPC_Peta",
				}),
			},
			Text = T(901208772433, --[[QuestsDef ChienSauvage Text]] "<em>Outcome:</em> <em>Petta</em> couldn't be saved"),
		}),
		PlaceObj('QuestNote', {
			AddInHistory = true,
			CompletionConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "ChienSauvage",
					Vars = set( "PetaLeft" ),
					__eval = function ()
						local quest = gv_Quests['ChienSauvage'] or QuestGetState('ChienSauvage')
						return quest.PetaLeft
					end,
				}),
				PlaceObj('CheckIsPersistentUnitDead', {
					Negate = true,
					per_ses_id = "NPC_Peta",
				}),
			},
			Idx = 6,
			ShowConditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "ChienSauvage",
					Vars = set( "PetaLeft" ),
					__eval = function ()
						local quest = gv_Quests['ChienSauvage'] or QuestGetState('ChienSauvage')
						return quest.PetaLeft
					end,
				}),
				PlaceObj('CheckIsPersistentUnitDead', {
					Negate = true,
					per_ses_id = "NPC_Peta",
				}),
			},
			Text = T(350423453238, --[[QuestsDef ChienSauvage Text]] "<em>Outcome:</em> <em>Petta</em> was saved"),
		}),
	},
	QuestGroup = "Jungle",
	TCEs = {
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('UnitIsAroundOtherUnit', {
					DisableContextModification = true,
					Distance = 8,
					SecondTargetUnit = "Peta",
					TargetUnit = "any merc",
				}),
				PlaceObj('CheckIsPersistentUnitDead', {
					Negate = true,
					per_ses_id = "NPC_Peta",
				}),
			},
			Effects = {
				PlaceObj('ConditionalEffect', {
					'Conditions', {
						PlaceObj('QuestIsVariableBool', {
							QuestId = "ChienSauvage",
							Vars = set({
	HyenasDead = false,
}),
							__eval = function ()
								local quest = gv_Quests['ChienSauvage'] or QuestGetState('ChienSauvage')
								return not quest.HyenasDead
							end,
						}),
					},
					'Effects', {
						PlaceObj('PlayBanterEffect', {
							Banters = {
								"ChienSauvage_Peta01_ApproachCell_1",
							},
							searchInMap = true,
							searchInMarker = false,
						}),
						PlaceObj('PlayBanterEffect', {
							Banters = {
								"ChienSauvage_Peta01_ApproachCell_2",
							},
							searchInMap = true,
							searchInMarker = false,
						}),
					},
					'EffectsElse', {
						PlaceObj('PlayBanterEffect', {
							Banters = {
								"ChienSauvage_Peta01_ApproachCell_3",
							},
							searchInMap = true,
							searchInMarker = false,
						}),
					},
				}),
			},
			Once = true,
			ParamId = "TCE_PetaApproachBanters",
			QuestId = "ChienSauvage",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('PlayerIsInSectors', {
					Sectors = {
						"E16",
					},
				}),
			},
			Effects = {
				PlaceObj('ExecuteCode', {
					FuncCode = 'local enemyUnits = MapGet("map", "Unit", function(o)\n	return table.find(o.Groups, "EnemySquad")\nend)\nfor _, unit in ipairs(enemyUnits) do\n	table.insert_unique(unit.Groups, "LegionChienSauvage")\nend',
				}),
			},
			Once = true,
			ParamId = "TCE_LegionSetGroup",
			QuestId = "ChienSauvage",
			requiredSectors = {
				"E16",
			},
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('PlayerIsInSectors', {
					Sectors = {
						"E16",
					},
				}),
				PlaceObj('QuestIsVariableBool', {
					QuestId = "ChienSauvage",
					Vars = set( "PetaLeftToDie" ),
					__eval = function ()
						local quest = gv_Quests['ChienSauvage'] or QuestGetState('ChienSauvage')
						return quest.PetaLeftToDie
					end,
				}),
			},
			Effects = {
				PlaceObj('UnitDie', {
					TargetGroup = "Peta",
					skipAnim = true,
				}),
			},
			Once = true,
			ParamId = "TCE_PetaLeftToDie",
			QuestId = "ChienSauvage",
			requiredSectors = {
				"E16",
			},
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('SatelliteGameplayRunning', {}),
				PlaceObj('QuestIsVariableBool', {
					QuestId = "ChienSauvage",
					Vars = set( "Given" ),
					__eval = function ()
						local quest = gv_Quests['ChienSauvage'] or QuestGetState('ChienSauvage')
						return quest.Given
					end,
				}),
			},
			Effects = {
				PlaceObj('QuestSetVariableBool', {
					Prop = "PlayerLeft",
					QuestId = "ChienSauvage",
				}),
				PlaceObj('ConditionalEffect', {
					'Conditions', {
						PlaceObj('QuestIsVariableBool', {
							Condition = "or",
							QuestId = "ChienSauvage",
							Vars = set({
	HyenasDead = false,
	LegionKilled = false,
}),
							__eval = function ()
								local quest = gv_Quests['ChienSauvage'] or QuestGetState('ChienSauvage')
								return not quest.HyenasDead or not quest.LegionKilled
							end,
						}),
					},
					'Effects', {
						PlaceObj('QuestSetVariableBool', {
							Prop = "PetaLeftToDie",
							QuestId = "ChienSauvage",
						}),
					},
				}),
			},
			Once = true,
			ParamId = "TCE_PlayerLeft",
			QuestId = "ChienSauvage",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('BanterHasPlayed', {
					Banters = {
						"ChienSauvage_Peta01_ApproachCell_1",
						"Shared_Conversation_Legion_18_ChienSauvage",
					},
					WaitOver = true,
				}),
			},
			Effects = {
				PlaceObj('QuestSetVariableBool', {
					Prop = "Given",
					QuestId = "ChienSauvage",
				}),
			},
			Once = true,
			ParamId = "TCE_Give",
			QuestId = "ChienSauvage",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('UnitCanGoToPos', {
					PositionMarker = "MainHyenasDoor",
					TargetUnit = "Peta",
				}),
			},
			Effects = {
				PlaceObj('ConditionalEffect', {
					'Conditions', {
						PlaceObj('QuestIsVariableBool', {
							QuestId = "ChienSauvage",
							Vars = set({
	HyenasDead = false,
}),
							__eval = function ()
								local quest = gv_Quests['ChienSauvage'] or QuestGetState('ChienSauvage')
								return not quest.HyenasDead
							end,
						}),
					},
					'Effects', {
						PlaceObj('PlayBanterEffect', {
							Banters = {
								"ChienSauvage_Peta02_OpenCell_HyenasAlive",
							},
							searchInMap = true,
							searchInMarker = false,
						}),
						PlaceObj('GroupSetBehaviorAdvanceTo', {
							MarkerGroup = "MainHyenasDoor",
							Running = true,
							TargetUnit = "Peta",
						}),
					},
				}),
				PlaceObj('QuestSetVariableBool', {
					Prop = "PetaReleased",
					QuestId = "ChienSauvage",
				}),
			},
			Once = true,
			ParamId = "TCE_PetaReleased",
			QuestId = "ChienSauvage",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "ChienSauvage",
					Vars = set( "PetaReleased" ),
					__eval = function ()
						local quest = gv_Quests['ChienSauvage'] or QuestGetState('ChienSauvage')
						return quest.PetaReleased
					end,
				}),
				PlaceObj('UnitIsAroundMarkerOfGroup', {
					MarkerGroup = "MainHyenasDoor",
					TargetUnit = "Peta",
				}),
			},
			Effects = {
				PlaceObj('ExecuteCode', {
					FuncCode = 'local door = MapGetFirst("map", "Door", function(o)\n	return table.find(o.Groups, "MainHyenasDoor")\nend)\nif door then\n	door:SetLockpickState("open")\nend',
				}),
				PlaceObj('QuestSetVariableBool', {
					Prop = "PetaLetsHyenasOut",
					QuestId = "ChienSauvage",
				}),
				PlaceObj('GroupSetSide', {
					Side = "enemy2",
					TargetUnit = "MainHyenas",
				}),
				PlaceObj('GroupAlert', {
					TargetUnit = "LegionChienSauvage",
				}),
				PlaceObj('GroupAlert', {
					TargetUnit = "MainHyenas",
				}),
			},
			Once = true,
			ParamId = "TCE_PetaLetHyenasOut",
			QuestId = "ChienSauvage",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('UnitCanGoToPos', {
					PositionMarker = "HyenasFreeRoamZone",
					TargetUnit = "MainHyenas",
				}),
			},
			Effects = {
				PlaceObj('GroupSetSide', {
					Side = "enemy2",
					TargetUnit = "MainHyenas",
				}),
				PlaceObj('GroupSetRoutine', {
					Routine = "Ambient",
					RoutineArea = "HyenasFreeRoamZone",
					TargetUnit = "MainHyenas",
				}),
			},
			Once = true,
			ParamId = "TCE_MainHyenasAggressive",
			QuestId = "ChienSauvage",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('GroupIsDead', {
					Group = "LegionChienSauvage",
				}),
			},
			Effects = {
				PlaceObj('QuestSetVariableBool', {
					Prop = "LegionKilled",
					QuestId = "ChienSauvage",
				}),
			},
			Once = true,
			ParamId = "TCE_ClearLegion",
			QuestId = "ChienSauvage",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('GroupIsDead', {
					Group = "MainHyenas",
				}),
			},
			Effects = {
				PlaceObj('QuestSetVariableBool', {
					Prop = "HyenasDead",
					QuestId = "ChienSauvage",
				}),
			},
			Once = true,
			ParamId = "TCE_HyenasDead",
			QuestId = "ChienSauvage",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('UnitIsAroundOtherUnit', {
					Distance = 12,
					SecondTargetUnit = "Peta",
					TargetUnit = "any merc",
				}),
				PlaceObj('QuestIsVariableBool', {
					QuestId = "ChienSauvage",
					Vars = set( "HyenasDead", "PetaReleased" ),
					__eval = function ()
						local quest = gv_Quests['ChienSauvage'] or QuestGetState('ChienSauvage')
						return quest.HyenasDead and quest.PetaReleased
					end,
				}),
			},
			Effects = {
				PlaceObj('PlayBanterEffect', {
					Banters = {
						"ChienSauvage_Peta03_OpenCell_HyenasDead",
					},
					searchInMap = true,
					searchInMarker = false,
				}),
				PlaceObj('QuestSetVariableBool', {
					Prop = "PetaLeft",
					QuestId = "ChienSauvage",
				}),
				PlaceObj('GroupSetBehaviorExit', {
					MarkerGroup = "North",
					Running = true,
					TargetUnit = "Peta",
				}),
			},
			Once = true,
			ParamId = "TCE_PetaLeave",
			QuestId = "ChienSauvage",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('CheckIsPersistentUnitDead', {
					Negate = true,
					per_ses_id = "NPC_Peta",
				}),
				PlaceObj('QuestIsVariableBool', {
					QuestId = "ChienSauvage",
					Vars = set( "PetaLeft" ),
					__eval = function ()
						local quest = gv_Quests['ChienSauvage'] or QuestGetState('ChienSauvage')
						return quest.PetaLeft
					end,
				}),
				PlaceObj('SectorCheckOwner', {
					sector_id = "E16",
				}),
			},
			Effects = {
				PlaceObj('QuestSetVariableBool', {
					Prop = "Completed",
					QuestId = "ChienSauvage",
				}),
				PlaceObj('GrantExperienceSector', {
					logImportant = true,
				}),
				PlaceObj('PlayerGrantMoney', {
					Amount = 2500,
				}),
				PlaceObj('SectorGrantIntel', {
					sector_id = "D15",
				}),
			},
			Once = true,
			ParamId = "TCE_Complete",
			QuestId = "ChienSauvage",
		}),
		PlaceObj('TriggeredConditionalEvent', {
			Conditions = {
				PlaceObj('CheckIsPersistentUnitDead', {
					per_ses_id = "NPC_Peta",
				}),
			},
			Effects = {
				PlaceObj('QuestSetVariableBool', {
					Prop = "Failed",
					QuestId = "ChienSauvage",
				}),
				PlaceObj('GrantExperienceSector', {}),
			},
			Once = true,
			ParamId = "TCE_Fail",
			QuestId = "ChienSauvage",
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
			Name = "PetaReleased",
		}),
		PlaceObj('QuestVarBool', {
			Name = "PetaLetsHyenasOut",
		}),
		PlaceObj('QuestVarBool', {
			Name = "HyenasDead",
		}),
		PlaceObj('QuestVarBool', {
			Name = "LegionKilled",
		}),
		PlaceObj('QuestVarBool', {
			Name = "PetaLeft",
		}),
		PlaceObj('QuestVarBool', {
			Name = "PlayerLeft",
		}),
		PlaceObj('QuestVarBool', {
			Name = "PetaLeftToDie",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_PetaApproachBanters",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_LegionSetGroup",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_Give",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_PetaLetHyenasOut",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_MainHyenasAggressive",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_ClearLegion",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_HyenasDead",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_PetaReleased",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_PlayerLeft",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_PetaLeftToDie",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_PetaLeave",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_Complete",
		}),
		PlaceObj('QuestVarTCEState', {
			Name = "TCE_Fail",
		}),
	},
	group = "CursedForest",
	id = "ChienSauvage",
})

