-- ========== GENERATED BY Conversation Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('Conversation', {
	AssignToGroup = "Faucheux",
	Conditions = {
		PlaceObj('PlayerIsInSectors', {
			Sectors = {
				"E9",
			},
		}),
	},
	DefaultActor = "Faucheux",
	group = "Savanna - Refugee Camp",
	id = "FaucheuxBetrayal",
	PlaceObj('ConversationPhrase', {
		Conditions = {
			PlaceObj('QuestIsVariableBool', {
				QuestId = "04_Betrayal",
				Vars = set({
	FaucheuxMet = false,
}),
				__eval = function ()
					local quest = gv_Quests['04_Betrayal'] or QuestGetState('04_Betrayal')
					return not quest.FaucheuxMet
				end,
			}),
		},
		GoTo = "GreetingRedirect",
		Keyword = "Greeting",
		KeywordT = T(774381032385, --[[Conversation FaucheuxBetrayal KeywordT]] "Greeting"),
		Lines = {
			PlaceObj('ConversationLine', {
				Character = "Faucheux",
				Text = T(131886987153, --[[Conversation FaucheuxBetrayal Text voice:Faucheux section:FaucheuxBetrayal keyword:Greeting]] "My name is Colonel Jules <em>Faucheux</em>."),
			}),
		},
		PlayGoToPhrase = true,
		id = "Greeting",
	}),
	PlaceObj('ConversationPhrase', {
		Conditions = {
			PlaceObj('QuestIsVariableBool', {
				QuestId = "04_Betrayal",
				Vars = set( "FaucheuxMet" ),
				__eval = function ()
					local quest = gv_Quests['04_Betrayal'] or QuestGetState('04_Betrayal')
					return quest.FaucheuxMet
				end,
			}),
		},
		GoTo = "GreetingRedirect",
		Keyword = "Greeting",
		KeywordT = T(774381032385, --[[Conversation FaucheuxBetrayal KeywordT]] "Greeting"),
		Lines = {
			PlaceObj('ConversationLine', {
				Character = "Faucheux",
				Text = T(146244352273, --[[Conversation FaucheuxBetrayal Text voice:Faucheux section:FaucheuxBetrayal keyword:Greeting2]] "Ah! Here are the colorful mercenaires again. It is nice to see that you know how to obey when your master pulls your leash."),
			}),
		},
		PlayGoToPhrase = true,
		id = "Greeting2",
	}),
	PlaceObj('ConversationPhrase', {
		AutoRemove = true,
		Effects = {
			PlaceObj('QuestSetVariableBool', {
				Prop = "FaucheuxMet",
				QuestId = "04_Betrayal",
			}),
		},
		Enabled = false,
		Keyword = "GreetingRedirect",
		KeywordT = T(645696992604, --[[Conversation FaucheuxBetrayal KeywordT]] "GreetingRedirect"),
		Lines = {
			PlaceObj('ConversationLine', {
				Character = "Faucheux",
				Text = T(483493821643, --[[Conversation FaucheuxBetrayal Text voice:Faucheux section:FaucheuxBetrayal keyword:GreetingRedirect]] "As a commander of Grand Chien's military forces in the Adjani region, it is my responsibility to deal with the <em>war atrocities</em> that took place here."),
			}),
		},
		id = "GreetingRedirect",
	}),
	PlaceObj('ConversationPhrase', {
		Effects = {
			PlaceObj('PhraseSetEnabled', {
				Conversation = "FaucheuxBetrayal",
				PhraseId = "WhereisCorazonSantiago",
			}),
		},
		Keyword = "What happened here?",
		KeywordT = T(195887112025, --[[Conversation FaucheuxBetrayal KeywordT]] "What happened here?"),
		Lines = {
			PlaceObj('ConversationLine', {
				Character = "Faucheux",
				Text = T(817053742987, --[[Conversation FaucheuxBetrayal Text voice:Faucheux section:FaucheuxBetrayal keyword:What happened here?]] "Hundreds of innocent refugees and other civilians have been killed by a chemical weapon."),
			}),
			PlaceObj('ConversationInterjectionList', {
				Interjections = {
					PlaceObj('ConversationInterjection', {
						Lines = {
							PlaceObj('ConversationLine', {
								Character = "Len",
								Text = T(860377610315, --[[Conversation FaucheuxBetrayal Text voice:Len section:FaucheuxBetrayal keyword:What happened here?]] "That is a nasty way to go."),
							}),
						},
					}),
					PlaceObj('ConversationInterjection', {
						Lines = {
							PlaceObj('ConversationLine', {
								Character = "Reaper",
								Text = T(392310740162, --[[Conversation FaucheuxBetrayal Text voice:Reaper section:FaucheuxBetrayal keyword:What happened here?]] "The spirits of the underworld had a feast this day."),
							}),
						},
					}),
					PlaceObj('ConversationInterjection', {
						Lines = {
							PlaceObj('ConversationLine', {
								Character = "Thor",
								Text = T(103091092093, --[[Conversation FaucheuxBetrayal Text voice:Thor section:FaucheuxBetrayal keyword:What happened here?]] "Mein Gott... So many bodies..."),
							}),
						},
					}),
				},
			}),
			PlaceObj('ConversationLine', {
				Character = "Faucheux",
				Text = T(334919844255, --[[Conversation FaucheuxBetrayal Text voice:Faucheux section:FaucheuxBetrayal keyword:What happened here?]] "This vile and craven attack on the people of Grand Chien is to be considered a <em>war crime</em> because it was committed by an unsanctioned <em>paramilitary group</em>."),
			}),
			PlaceObj('ConversationInterjectionList', {
				Interjections = {
					PlaceObj('ConversationInterjection', {
						Conditions = {
							PlaceObj('QuestIsVariableBool', {
								QuestId = "04_Betrayal",
								Vars = set({
	ClueChemical = false,
}),
								__eval = function ()
									local quest = gv_Quests['04_Betrayal'] or QuestGetState('04_Betrayal')
									return not quest.ClueChemical
								end,
							}),
						},
						Lines = {
							PlaceObj('ConversationLine', {
								Character = "Raven",
								Text = T(439212692904, --[[Conversation FaucheuxBetrayal Text voice:Raven section:FaucheuxBetrayal keyword:What happened here?]] "The goddamn Legion again!"),
							}),
						},
					}),
					PlaceObj('ConversationInterjection', {
						Conditions = {
							PlaceObj('QuestIsVariableBool', {
								QuestId = "04_Betrayal",
								Vars = set({
	ClueChemical = false,
}),
								__eval = function ()
									local quest = gv_Quests['04_Betrayal'] or QuestGetState('04_Betrayal')
									return not quest.ClueChemical
								end,
							}),
						},
						Lines = {
							PlaceObj('ConversationLine', {
								Character = "Buns",
								Text = T(268480286863, --[[Conversation FaucheuxBetrayal Text voice:Buns section:FaucheuxBetrayal keyword:What happened here?]] "This was surely the work of the Legion."),
							}),
						},
					}),
					PlaceObj('ConversationInterjection', {
						Conditions = {
							PlaceObj('QuestIsVariableBool', {
								QuestId = "04_Betrayal",
								Vars = set({
	ClueChemical = false,
}),
								__eval = function ()
									local quest = gv_Quests['04_Betrayal'] or QuestGetState('04_Betrayal')
									return not quest.ClueChemical
								end,
							}),
						},
						Lines = {
							PlaceObj('ConversationLine', {
								Character = "MD",
								Text = T(591512084676, --[[Conversation FaucheuxBetrayal Text voice:MD section:FaucheuxBetrayal keyword:What happened here?]] "The Legion is certainly callous enough to do something like this, but I wonder how they got their hands on a chemical weapon..."),
							}),
						},
					}),
				},
			}),
		},
		id = "Whathappenedhere",
	}),
	PlaceObj('ConversationPhrase', {
		Conditions = {
			PlaceObj('QuestIsVariableBool', {
				QuestId = "04_Betrayal",
				Vars = set({
	FaucheuxAccusation = false,
}),
				__eval = function ()
					local quest = gv_Quests['04_Betrayal'] or QuestGetState('04_Betrayal')
					return not quest.FaucheuxAccusation
				end,
			}),
		},
		Effects = {
			PlaceObj('QuestSetVariableBool', {
				Prop = "MentionCorazon",
				QuestId = "04_Betrayal",
			}),
		},
		Keyword = "Where is Corazon Santiago?",
		KeywordT = T(329120723740, --[[Conversation FaucheuxBetrayal KeywordT]] "Where is Corazon Santiago?"),
		Lines = {
			PlaceObj('ConversationLine', {
				Character = "Faucheux",
				Text = T(211303143667, --[[Conversation FaucheuxBetrayal Text voice:Faucheux section:FaucheuxBetrayal keyword:Where is Corazon Santiago?]] "She won't be coming, but she sends you her regards."),
			}),
			PlaceObj('ConversationInterjectionList', {
				Interjections = {
					PlaceObj('ConversationInterjection', {
						Lines = {
							PlaceObj('ConversationLine', {
								Character = "Scully",
								Text = T(331762857235, --[[Conversation FaucheuxBetrayal Text voice:Scully section:FaucheuxBetrayal keyword:Where is Corazon Santiago?]] "That's a bit odd, mate. When a woman says she needs to meet me to explain something, she's usually waiting with a baseball bat in one hand and divorce papers in the other."),
							}),
						},
					}),
					PlaceObj('ConversationInterjection', {
						Lines = {
							PlaceObj('ConversationLine', {
								Character = "DrQ",
								Text = T(571250825032, --[[Conversation FaucheuxBetrayal Text voice:DrQ section:FaucheuxBetrayal keyword:Where is Corazon Santiago?]] "That is... very curious."),
							}),
						},
					}),
					PlaceObj('ConversationInterjection', {
						Lines = {
							PlaceObj('ConversationLine', {
								Character = "Gus",
								Text = T(482460686214, --[[Conversation FaucheuxBetrayal Text voice:Gus section:FaucheuxBetrayal keyword:Where is Corazon Santiago?]] "Something smells fishy here, Woody."),
							}),
						},
					}),
				},
			}),
		},
		id = "WhereisCorazonSantiago",
	}),
	PlaceObj('ConversationPhrase', {
		Conditions = {
			PlaceObj('QuestIsVariableBool', {
				QuestId = "04_Betrayal",
				Vars = set( "FaucheuxAccusation" ),
				__eval = function ()
					local quest = gv_Quests['04_Betrayal'] or QuestGetState('04_Betrayal')
					return quest.FaucheuxAccusation
				end,
			}),
		},
		Keyword = "What about your President?",
		KeywordT = T(126970905590, --[[Conversation FaucheuxBetrayal KeywordT]] "What about your President?"),
		Lines = {
			PlaceObj('ConversationLine', {
				Character = "Faucheux",
				Text = T(349767468296, --[[Conversation FaucheuxBetrayal Text voice:Faucheux section:FaucheuxBetrayal keyword:What about your President?]] "LaFontaine is a fool. He thought he could run a government in which the fox and the chicken can work together in harmony. It was only a matter of time before he paid for his childish idealism."),
			}),
			PlaceObj('ConversationInterjectionList', {
				Interjections = {
					PlaceObj('ConversationInterjection', {
						Lines = {
							PlaceObj('ConversationLine', {
								Character = "PierreMerc",
								Text = T(216190732169, --[[Conversation FaucheuxBetrayal Text voice:PierreMerc section:FaucheuxBetrayal keyword:What about your President?]] 'The Major used to say "How does a chicken stop being prey for a fox? ...By killing it." I am guessing the President did not possess such wisdom.'),
							}),
						},
					}),
					PlaceObj('ConversationInterjection', {
						Lines = {
							PlaceObj('ConversationLine', {
								Character = "Flay",
								Text = T(185018722723, --[[Conversation FaucheuxBetrayal Text voice:Flay section:FaucheuxBetrayal keyword:What about your President?]] "C'est vrai. The natural order cannot be changed, Predators hunt. Prey runs... or dies. "),
							}),
						},
					}),
					PlaceObj('ConversationInterjection', {
						Lines = {
							PlaceObj('ConversationLine', {
								Character = "Larry_Clean",
								Text = T(240131126508, --[[Conversation FaucheuxBetrayal Text voice:Larry_Clean section:FaucheuxBetrayal keyword:What about your President?]] "Hey, man, don't blame the victim. That's not cool."),
							}),
						},
					}),
				},
			}),
			PlaceObj('ConversationLine', {
				Character = "Faucheux",
				Text = T(265598538627, --[[Conversation FaucheuxBetrayal Text voice:Faucheux section:FaucheuxBetrayal keyword:What about your President?]] "The <em>Major's</em> little kidnapping actually saved Alphonse's life for a while - but it doesn't really matter. The coup was already in motion. All we needed was some time and money."),
			}),
		},
		id = "TheMajorKidnappedyourPresident",
	}),
	PlaceObj('ConversationPhrase', {
		AutoRemove = true,
		Conditions = {
			PlaceObj('QuestIsVariableBool', {
				QuestId = "04_Betrayal",
				Vars = set( "FaucheuxAccusation", "FaucheuxExposed", "MentionCorazon" ),
				__eval = function ()
					local quest = gv_Quests['04_Betrayal'] or QuestGetState('04_Betrayal')
					return quest.FaucheuxAccusation and quest.FaucheuxExposed and quest.MentionCorazon
				end,
			}),
		},
		Effects = {
			PlaceObj('PhraseSetEnabled', {
				Conversation = "FaucheuxBetrayal",
				Enabled = false,
				PhraseId = "WhereisCorazonSantiago",
			}),
		},
		Keyword = "You’re working for Corazon Santiago!",
		KeywordT = T(165356967240, --[[Conversation FaucheuxBetrayal KeywordT]] "You’re working for Corazon Santiago!"),
		Lines = {
			PlaceObj('ConversationInterjectionList', {
				Interjections = {
					PlaceObj('ConversationInterjection', {
						Lines = {
							PlaceObj('ConversationLine', {
								Character = "Sidney",
								Text = T(314070827469, --[[Conversation FaucheuxBetrayal Text voice:Sidney section:FaucheuxBetrayal keyword:You’re working for Corazon Santiago!]] "It appears Ms. Santiago has been manipulating us from the start. You're working for her, aren't you?"),
							}),
						},
					}),
					PlaceObj('ConversationInterjection', {
						Lines = {
							PlaceObj('ConversationLine', {
								Character = "Shadow",
								Text = T(437603583447, --[[Conversation FaucheuxBetrayal Text voice:Shadow section:FaucheuxBetrayal keyword:You’re working for Corazon Santiago!]] "It looks like our friend Corazon might be a wolf in sheep's clothing. Does she have you working for her, too?"),
							}),
						},
					}),
					PlaceObj('ConversationInterjection', {
						Lines = {
							PlaceObj('ConversationLine', {
								Character = "Grunty",
								Text = T(549727424615, --[[Conversation FaucheuxBetrayal Text voice:Grunty section:FaucheuxBetrayal keyword:You’re working for Corazon Santiago!]] "I am beginning to believe Frau Santiago is up to something naughty. You are working for her, are you not?"),
							}),
						},
					}),
				},
			}),
			PlaceObj('ConversationLine', {
				Character = "Faucheux",
				Text = T(733518478996, --[[Conversation FaucheuxBetrayal Text voice:Faucheux section:FaucheuxBetrayal keyword:You’re working for Corazon Santiago!]] "Not for, but with. She is useful... for now. There is much that can be achieved with my soldiers and her money. "),
			}),
			PlaceObj('ConversationInterjectionList', {
				Interjections = {
					PlaceObj('ConversationInterjection', {
						Lines = {
							PlaceObj('ConversationLine', {
								Character = "Nails",
								Text = T(633503969116, --[[Conversation FaucheuxBetrayal Text voice:Nails section:FaucheuxBetrayal keyword:You’re working for Corazon Santiago!]] "Yeah, like screwing us over, apparently."),
							}),
						},
					}),
					PlaceObj('ConversationInterjection', {
						Lines = {
							PlaceObj('ConversationLine', {
								Character = "Blood",
								Text = T(257187407369, --[[Conversation FaucheuxBetrayal Text voice:Blood section:FaucheuxBetrayal keyword:You’re working for Corazon Santiago!]] "I am certain you are right. I'm also certain none of it will be good."),
							}),
						},
					}),
					PlaceObj('ConversationInterjection', {
						Lines = {
							PlaceObj('ConversationLine', {
								Character = "Vicki",
								Text = T(676080376613, --[[Conversation FaucheuxBetrayal Text voice:Vicki section:FaucheuxBetrayal keyword:You’re working for Corazon Santiago!]] "Not anything good, I wager."),
							}),
						},
					}),
				},
			}),
		},
		StoryBranchIcon = "conversation_action",
		id = "YoureworkingforAdonis",
	}),
	PlaceObj('ConversationPhrase', {
		Align = "right",
		AutoRemove = true,
		Conditions = {
			PlaceObj('QuestIsVariableBool', {
				QuestId = "04_Betrayal",
				Vars = set({
	ClueChemical = false,
	ClueDeadBody = false,
	ClueLegion = false,
	FaucheuxAccusation = false,
}),
				__eval = function ()
					local quest = gv_Quests['04_Betrayal'] or QuestGetState('04_Betrayal')
					return not quest.ClueChemical and not quest.ClueDeadBody and not quest.ClueLegion and not quest.FaucheuxAccusation
				end,
			}),
		},
		GoTo = "Whodidthis",
		Keyword = "Did the Legion kill everyone?",
		KeywordT = T(939464827173, --[[Conversation FaucheuxBetrayal KeywordT]] "Did the Legion kill everyone?"),
		Lines = {
			PlaceObj('ConversationLine', {
				Character = "Faucheux",
				Text = T(706832736491, --[[Conversation FaucheuxBetrayal Text voice:Faucheux section:FaucheuxBetrayal keyword:Did the Legion kill everyone?]] "No, they do not possess that kind of capability. The only chemical weapons in Grand Chien are closely guarded by the Army. However, that is unimportant because I already know that..."),
			}),
		},
		PhraseConditionRolloverText = T(946594835760, --[[Conversation FaucheuxBetrayal PhraseConditionRolloverText]] "Not enough <em>clues</em>"),
		PlayGoToPhrase = true,
		StoryBranchIcon = "conversation_arrow",
		id = "ItmusthavebeentheLegion",
	}),
	PlaceObj('ConversationPhrase', {
		Align = "right",
		AutoRemove = true,
		Conditions = {
			PlaceObj('QuestIsVariableBool', {
				QuestId = "04_Betrayal",
				Vars = set({
	FaucheuxAccusation = false,
}),
				__eval = function ()
					local quest = gv_Quests['04_Betrayal'] or QuestGetState('04_Betrayal')
					return not quest.FaucheuxAccusation
				end,
			}),
			PlaceObj('QuestIsVariableBool', {
				Condition = "or",
				QuestId = "04_Betrayal",
				Vars = set( "ClueDeadBody", "ClueLegion" ),
				__eval = function ()
					local quest = gv_Quests['04_Betrayal'] or QuestGetState('04_Betrayal')
					return quest.ClueDeadBody or quest.ClueLegion
				end,
			}),
			PlaceObj('QuestIsVariableBool', {
				Condition = "or",
				QuestId = "04_Betrayal",
				Vars = set( "ClueChemical" ),
				__eval = function ()
					local quest = gv_Quests['04_Betrayal'] or QuestGetState('04_Betrayal')
					return quest.ClueChemical
				end,
			}),
		},
		GoTo = "Whodidthis",
		Keyword = "Your soldiers killed those civilians!",
		KeywordT = T(212670655251, --[[Conversation FaucheuxBetrayal KeywordT]] "Your soldiers killed those civilians!"),
		Lines = {
			PlaceObj('ConversationInterjectionList', {
				Interjections = {
					PlaceObj('ConversationInterjection', {
						Lines = {
							PlaceObj('ConversationLine', {
								Character = "Fidel",
								Text = T(581252903651, --[[Conversation FaucheuxBetrayal Text voice:Fidel section:FaucheuxBetrayal keyword:Your soldiers killed those civilians!]] "You can't fool uncle Fidel! There is chemical canisters everywhere. This is wrong. You had fun without Fidel!"),
							}),
						},
					}),
					PlaceObj('ConversationInterjection', {
						Lines = {
							PlaceObj('ConversationLine', {
								Character = "Ivan",
								Text = T(995334862762, --[[Conversation FaucheuxBetrayal Text voice:Ivan section:FaucheuxBetrayal keyword:Your soldiers killed those civilians!]] "Бандиты этого не делали. I saw old Soviet chemical canisters on ground."),
							}),
						},
					}),
					PlaceObj('ConversationInterjection', {
						Lines = {
							PlaceObj('ConversationLine', {
								Character = "Barry",
								Text = T(451845399813, --[[Conversation FaucheuxBetrayal Text voice:Barry section:FaucheuxBetrayal keyword:Your soldiers killed those civilians!]] "I have made notice of thermal dissemination chemical canisters utilized by your soldiers. If what I'm thinking is true, you have done a terrible sin."),
							}),
						},
					}),
				},
			}),
			PlaceObj('ConversationLine', {
				Character = "Faucheux",
				Text = T(733198815889, --[[Conversation FaucheuxBetrayal Text voice:Faucheux section:FaucheuxBetrayal keyword:Your soldiers killed those civilians!]] "You are very observant. Unfortunately for you, it doesn't matter because I already know that..."),
			}),
		},
		PhraseConditionRolloverText = T(304865696742, --[[Conversation FaucheuxBetrayal PhraseConditionRolloverText]] "Have enough <em>clues</em>"),
		PlayGoToPhrase = true,
		StoryBranchIcon = "conversation_threaten",
		id = "YourSoldiersDidThis",
	}),
	PlaceObj('ConversationPhrase', {
		Align = "right",
		AutoRemove = true,
		Conditions = {
			PlaceObj('QuestIsVariableBool', {
				QuestId = "04_Betrayal",
				Vars = set({
	FaucheuxAccusation = false,
}),
				__eval = function ()
					local quest = gv_Quests['04_Betrayal'] or QuestGetState('04_Betrayal')
					return not quest.FaucheuxAccusation
				end,
			}),
		},
		Effects = {
			PlaceObj('QuestSetVariableBool', {
				Prop = "FaucheuxAccusation",
				QuestId = "04_Betrayal",
			}),
		},
		Keyword = "Who did this?",
		KeywordT = T(842012835345, --[[Conversation FaucheuxBetrayal KeywordT]] "Who did this?"),
		Lines = {
			PlaceObj('ConversationLine', {
				Character = "Faucheux",
				Text = T(494199132863, --[[Conversation FaucheuxBetrayal Text voice:Faucheux section:FaucheuxBetrayal keyword:Who did this?]] "...<em>You</em> did this. You and your M.E.R.C. friends attacked <em>diamond mines</em> that are the property of the Republic of Grand Chien."),
			}),
			PlaceObj('ConversationInterjectionList', {
				Interjections = {
					PlaceObj('ConversationInterjection', {
						Lines = {
							PlaceObj('ConversationLine', {
								Character = "Scope",
								Text = T(349329409137, --[[Conversation FaucheuxBetrayal Text voice:Scope section:FaucheuxBetrayal keyword:Who did this?]] "Sorry, but I think you may be just a tad misinformed..."),
							}),
						},
					}),
					PlaceObj('ConversationInterjection', {
						Lines = {
							PlaceObj('ConversationLine', {
								Character = "Vicki",
								Text = T(800826018174, --[[Conversation FaucheuxBetrayal Text voice:Vicki section:FaucheuxBetrayal keyword:Who did this?]] "No, no, no, mon, there is some misunderstanding..."),
							}),
						},
					}),
					PlaceObj('ConversationInterjection', {
						Lines = {
							PlaceObj('ConversationLine', {
								Character = "Tex",
								Text = T(266152109143, --[[Conversation FaucheuxBetrayal Text voice:Tex section:FaucheuxBetrayal keyword:Who did this?]] "You got the wrong cowboys, partner!"),
							}),
						},
					}),
				},
			}),
			PlaceObj('ConversationLine', {
				Character = "Faucheux",
				Text = T(389406281449, --[[Conversation FaucheuxBetrayal Text voice:Faucheux section:FaucheuxBetrayal keyword:Who did this?]] "Then you used slave labor to operate them, and when the local population rebelled against you, you killed innocent civilians in a show of force. And now you have the audacity to return to the scene of the crime."),
			}),
			PlaceObj('ConversationInterjectionList', {
				Interjections = {
					PlaceObj('ConversationInterjection', {
						Lines = {
							PlaceObj('ConversationLine', {
								Character = "Len",
								Text = T(975717296980, --[[Conversation FaucheuxBetrayal Text voice:Len section:FaucheuxBetrayal keyword:Who did this?]] "None of that is true!"),
							}),
						},
					}),
					PlaceObj('ConversationInterjection', {
						Lines = {
							PlaceObj('ConversationLine', {
								Character = "Wolf",
								Text = T(791654592082, --[[Conversation FaucheuxBetrayal Text voice:Wolf section:FaucheuxBetrayal keyword:Who did this?]] "I don't know how to tell you this, chief, but not one word of that is true."),
							}),
						},
					}),
					PlaceObj('ConversationInterjection', {
						Lines = {
							PlaceObj('ConversationLine', {
								Character = "Red",
								Text = T(600803548012, --[[Conversation FaucheuxBetrayal Text voice:Red section:FaucheuxBetrayal keyword:Who did this?]] "Are ye daft!? That is a complete and utter fabrication."),
							}),
						},
					}),
				},
			}),
		},
		StoryBranchIcon = "conversation_arrow",
		id = "Whodidthis",
	}),
	PlaceObj('ConversationPhrase', {
		Align = "right",
		Conditions = {
			PlaceObj('QuestIsVariableBool', {
				QuestId = "04_Betrayal",
				Vars = set( "FaucheuxAccusation" ),
				__eval = function ()
					local quest = gv_Quests['04_Betrayal'] or QuestGetState('04_Betrayal')
					return quest.FaucheuxAccusation
				end,
			}),
		},
		Effects = {
			PlaceObj('QuestSetVariableBool', {
				Prop = "MentionCorazon",
				QuestId = "04_Betrayal",
			}),
			PlaceObj('QuestSetVariableBool', {
				Prop = "FaucheuxExposed",
				QuestId = "04_Betrayal",
			}),
		},
		Keyword = "No one will believe you!",
		KeywordT = T(358273815354, --[[Conversation FaucheuxBetrayal KeywordT]] "No one will believe you!"),
		Lines = {
			PlaceObj('ConversationLine', {
				Character = "Faucheux",
				Text = T(328016999033, --[[Conversation FaucheuxBetrayal Text voice:Faucheux section:FaucheuxBetrayal keyword:No one will believe you!]] "You think? Let's examine the facts. You are foreign mercenaires, paid by <em>Adonis</em>, a foreign corporation, to capture our diamond mines. One of those - <em>Diamond Red</em> - was guarded by Grand Chien troops when some of your people attacked it."),
			}),
			PlaceObj('ConversationInterjectionList', {
				Interjections = {
					PlaceObj('ConversationInterjection', {
						Conditions = {
							PlaceObj('CheckOR', {
								Conditions = {
									PlaceObj('QuestIsVariableBool', {
										QuestId = "RescueBiff",
										Vars = set( "MERC_Crimes" ),
										__eval = function ()
											local quest = gv_Quests['RescueBiff'] or QuestGetState('RescueBiff')
											return quest.MERC_Crimes
										end,
									}),
									PlaceObj('QuestIsVariableBool', {
										QuestId = "PantagruelDramas",
										Vars = set( "MentionLie" ),
										__eval = function ()
											local quest = gv_Quests['PantagruelDramas'] or QuestGetState('PantagruelDramas')
											return quest.MentionLie
										end,
									}),
								},
							}),
						},
						Lines = {
							PlaceObj('ConversationLine', {
								Character = "Raider",
								Text = T(781627168688, --[[Conversation FaucheuxBetrayal Text voice:Raider section:FaucheuxBetrayal keyword:No one will believe you!]] "Those were the idiots from M.E.R.C. who attacked it by mistake!"),
							}),
						},
					}),
					PlaceObj('ConversationInterjection', {
						Conditions = {
							PlaceObj('CheckOR', {
								Conditions = {
									PlaceObj('QuestIsVariableBool', {
										QuestId = "RescueBiff",
										Vars = set( "MERC_Crimes" ),
										__eval = function ()
											local quest = gv_Quests['RescueBiff'] or QuestGetState('RescueBiff')
											return quest.MERC_Crimes
										end,
									}),
									PlaceObj('QuestIsVariableBool', {
										QuestId = "PantagruelDramas",
										Vars = set( "MentionLie" ),
										__eval = function ()
											local quest = gv_Quests['PantagruelDramas'] or QuestGetState('PantagruelDramas')
											return quest.MentionLie
										end,
									}),
								},
							}),
						},
						Lines = {
							PlaceObj('ConversationLine', {
								Character = "Meltdown",
								Text = T(539128156480, --[[Conversation FaucheuxBetrayal Text voice:Meltdown section:FaucheuxBetrayal keyword:No one will believe you!]] "Wasn't us, Colonel Fuckshow! It was that moron Biff Apscott and his gang of dumbasses."),
							}),
						},
					}),
					PlaceObj('ConversationInterjection', {
						Conditions = {
							PlaceObj('CheckOR', {
								Conditions = {
									PlaceObj('QuestIsVariableBool', {
										QuestId = "RescueBiff",
										Vars = set( "MERC_Crimes" ),
										__eval = function ()
											local quest = gv_Quests['RescueBiff'] or QuestGetState('RescueBiff')
											return quest.MERC_Crimes
										end,
									}),
									PlaceObj('QuestIsVariableBool', {
										QuestId = "PantagruelDramas",
										Vars = set( "MentionLie" ),
										__eval = function ()
											local quest = gv_Quests['PantagruelDramas'] or QuestGetState('PantagruelDramas')
											return quest.MentionLie
										end,
									}),
								},
							}),
						},
						Lines = {
							PlaceObj('ConversationLine', {
								Character = "Vicki",
								Text = T(806864269973, --[[Conversation FaucheuxBetrayal Text voice:Vicki section:FaucheuxBetrayal keyword:No one will believe you!]] "That was Biff and his crew, mon! Get your facts straight in your head."),
							}),
						},
					}),
					PlaceObj('ConversationInterjection', {
						Lines = {
							PlaceObj('ConversationLine', {
								Character = "Larry_Clean",
								Text = T(667678795112, --[[Conversation FaucheuxBetrayal Text voice:Larry_Clean section:FaucheuxBetrayal keyword:No one will believe you!]] "But Chimurenga told us it was held by the Legion! How could we know?..."),
							}),
						},
					}),
					PlaceObj('ConversationInterjection', {
						Lines = {
							PlaceObj('ConversationLine', {
								Character = "Larry",
								Text = T(108819494948, --[[Conversation FaucheuxBetrayal Text voice:Larry section:FaucheuxBetrayal keyword:No one will believe you!]] "But we had information there was a chemical plant inside that was producing evil laser raptors!"),
							}),
						},
					}),
					PlaceObj('ConversationInterjection', {
						Lines = {
							PlaceObj('ConversationLine', {
								Character = "Smiley",
								Text = T(262302034608, --[[Conversation FaucheuxBetrayal Text voice:Smiley section:FaucheuxBetrayal keyword:No one will believe you!]] "That was the fault of the Maquis! Señor Apscott would never knowingly do such a thing!"),
							}),
						},
					}),
				},
			}),
			PlaceObj('ConversationLine', {
				Character = "Faucheux",
				Text = T(607553495281, --[[Conversation FaucheuxBetrayal Text voice:Faucheux section:FaucheuxBetrayal keyword:No one will believe you!]] "I know perfectly well that it was done by the people from M.E.R.C. but the general public doesn't care about such nuances. You will take the blame for it, as well as this massacre, and I will have the perfect reason to intervene and restore order. "),
			}),
		},
		StoryBranchIcon = "conversation_arrow",
		id = "NoOneWillBelieveYou",
	}),
	PlaceObj('ConversationPhrase', {
		Align = "right",
		Conditions = {
			PlaceObj('QuestIsVariableBool', {
				QuestId = "04_Betrayal",
				Vars = set( "FaucheuxAccusation" ),
				__eval = function ()
					local quest = gv_Quests['04_Betrayal'] or QuestGetState('04_Betrayal')
					return quest.FaucheuxAccusation
				end,
			}),
		},
		Effects = {
			PlaceObj('QuestSetVariableBool', {
				Prop = "FaucheuxExposed",
				QuestId = "04_Betrayal",
			}),
		},
		Keyword = "Your enemy is the Major!",
		KeywordT = T(756578325620, --[[Conversation FaucheuxBetrayal KeywordT]] "Your enemy is the Major!"),
		Lines = {
			PlaceObj('ConversationLine', {
				Character = "Faucheux",
				Text = T(434670453737, --[[Conversation FaucheuxBetrayal Text voice:Faucheux section:FaucheuxBetrayal keyword:Your enemy is the Major!]] "No. His Legion is a collection of criminals, able to terrorize citizens of the Adjani, but not much more. I'm surprised you haven't finished them off by now. Apparently, you're far less capable than I presumed - and I presumed very little. "),
			}),
			PlaceObj('ConversationInterjectionList', {
				Interjections = {
					PlaceObj('ConversationInterjection', {
						Lines = {
							PlaceObj('ConversationLine', {
								Character = "Mouse",
								Text = T(327492200096, --[[Conversation FaucheuxBetrayal Text voice:Mouse section:FaucheuxBetrayal keyword:Your enemy is the Major!]] "I guess you don't care that he's a monster, what with you being one yourself."),
							}),
						},
					}),
					PlaceObj('ConversationInterjection', {
						Lines = {
							PlaceObj('ConversationLine', {
								Character = "Ice",
								Text = T(863067560157, --[[Conversation FaucheuxBetrayal Text voice:Ice section:FaucheuxBetrayal keyword:Your enemy is the Major!]] "Mm-mm. That mouth of yours be writing a hell of a lot of checks!"),
							}),
						},
					}),
					PlaceObj('ConversationInterjection', {
						Lines = {
							PlaceObj('ConversationLine', {
								Character = "Kalyna",
								Text = T(979272597087, --[[Conversation FaucheuxBetrayal Text voice:Kalyna section:FaucheuxBetrayal keyword:Your enemy is the Major!]] "The Major is EVIL! Don't you care about that sort of thing?"),
							}),
						},
					}),
				},
			}),
			PlaceObj('ConversationLine', {
				Character = "Faucheux",
				Text = T(784704660849, --[[Conversation FaucheuxBetrayal Text voice:Faucheux section:FaucheuxBetrayal keyword:Your enemy is the Major!]] "We wanted to use the Major as a scapegoat, but too many people believe his patriotic babble. You, however, a group of corporate-sponsored mercenaires, are the very symbol of foreign oppression. You fit marvelously. "),
			}),
			PlaceObj('ConversationInterjectionList', {
				Interjections = {
					PlaceObj('ConversationInterjection', {
						Lines = {
							PlaceObj('ConversationLine', {
								Character = "PierreMerc",
								Text = T(624679374551, --[[Conversation FaucheuxBetrayal Text voice:PierreMerc section:FaucheuxBetrayal keyword:Your enemy is the Major!]] "I do not know if the Major's patriotism is truly fake, but I DO know yours is."),
							}),
						},
					}),
					PlaceObj('ConversationInterjection', {
						Lines = {
							PlaceObj('ConversationLine', {
								Character = "Shadow",
								Text = T(470701648383, --[[Conversation FaucheuxBetrayal Text voice:Shadow section:FaucheuxBetrayal keyword:Your enemy is the Major!]] "I don't think that's going to work for me. I don't really like how I look in a frame."),
							}),
						},
					}),
					PlaceObj('ConversationInterjection', {
						Lines = {
							PlaceObj('ConversationLine', {
								Character = "Tex",
								Text = T(218415761029, --[[Conversation FaucheuxBetrayal Text voice:Tex section:FaucheuxBetrayal keyword:Your enemy is the Major!]] "You almost good movie villain. Just need to work on being scary. You more like sad, kinda boring villain who talk too much."),
							}),
						},
					}),
				},
			}),
		},
		StoryBranchIcon = "conversation_arrow",
		id = "WhatabouttheMajor",
	}),
	PlaceObj('ConversationPhrase', {
		Align = "right",
		AutoRemove = true,
		Conditions = {
			PlaceObj('QuestIsVariableBool', {
				QuestId = "04_Betrayal",
				Vars = set({
	FaucheuxAccusation = false,
}),
				__eval = function ()
					local quest = gv_Quests['04_Betrayal'] or QuestGetState('04_Betrayal')
					return not quest.FaucheuxAccusation
				end,
			}),
		},
		GoTo = "<root>",
		Keyword = "Goodbye",
		KeywordT = T(557225474228, --[[Conversation FaucheuxBetrayal KeywordT]] "Goodbye"),
		Lines = {
			PlaceObj('ConversationLine', {
				Character = "Faucheux",
				Text = T(905951103945, --[[Conversation FaucheuxBetrayal Text voice:Faucheux section:FaucheuxBetrayal keyword:Goodbye]] "Not so fast, mercenaires. We have something to discuss."),
			}),
		},
		StoryBranchIcon = "conversation_goodbye",
		id = "Goodbye",
	}),
	PlaceObj('ConversationPhrase', {
		Align = "right",
		AutoRemove = true,
		Conditions = {
			PlaceObj('QuestIsVariableBool', {
				QuestId = "04_Betrayal",
				Vars = set( "FaucheuxExposed" ),
				__eval = function ()
					local quest = gv_Quests['04_Betrayal'] or QuestGetState('04_Betrayal')
					return quest.FaucheuxExposed
				end,
			}),
		},
		Effects = {
			PlaceObj('QuestSetVariableBool', {
				Prop = "BetrayalStartCombat",
				QuestId = "04_Betrayal",
			}),
			PlaceObj('PlaySetpiece', {
				setpiece = "FaucheuxLeave",
			}),
		},
		GoTo = "<end conversation>",
		Keyword = "You will pay for this!",
		KeywordT = T(496140871793, --[[Conversation FaucheuxBetrayal KeywordT]] "You will pay for this!"),
		Lines = {
			PlaceObj('ConversationLine', {
				Character = "Faucheux",
				Text = T(960117773906, --[[Conversation FaucheuxBetrayal Text voice:Faucheux section:FaucheuxBetrayal keyword:You will pay for this!]] "Negative. Someone else will pay the bill. As for you - you have been bought and sold already. You have been useful pawns, but like all good pawns, you will be sacrificed."),
			}),
			PlaceObj('ConversationInterjectionList', {
				Interjections = {
					PlaceObj('ConversationInterjection', {
						Lines = {
							PlaceObj('ConversationLine', {
								Character = "Grizzly",
								Text = T(744285059372, --[[Conversation FaucheuxBetrayal Text voice:Grizzly section:FaucheuxBetrayal keyword:You will pay for this!]] "I got a bad feeling about this..."),
							}),
						},
					}),
					PlaceObj('ConversationInterjection', {
						Lines = {
							PlaceObj('ConversationLine', {
								Character = "Igor",
								Text = T(487850794562, --[[Conversation FaucheuxBetrayal Text voice:Igor section:FaucheuxBetrayal keyword:You will pay for this!]] "I do not play chess, but I am thinking his metaphor is maybe bad for us."),
							}),
						},
					}),
					PlaceObj('ConversationInterjection', {
						Lines = {
							PlaceObj('ConversationLine', {
								Character = "Steroid",
								Text = T(903526145612, --[[Conversation FaucheuxBetrayal Text voice:Steroid section:FaucheuxBetrayal keyword:You will pay for this!]] "I am not prawn! I am... I am a shark! No, that's not right, sharks have tiny arms."),
							}),
						},
					}),
					PlaceObj('ConversationInterjection', {
						Lines = {
							PlaceObj('ConversationLine', {
								Character = "Red",
								Text = T(302325745424, --[[Conversation FaucheuxBetrayal Text voice:Red section:FaucheuxBetrayal keyword:You will pay for this!]] "Oh, that's great! Just great. Well, it's been nice knowin' ye."),
							}),
						},
					}),
					PlaceObj('ConversationInterjection', {
						Lines = {
							PlaceObj('ConversationLine', {
								Character = "Livewire",
								Text = T(894981861025, --[[Conversation FaucheuxBetrayal Text voice:Livewire section:FaucheuxBetrayal keyword:You will pay for this!]] "While I choose to believe he did not mean that in a literal way, it may be prudent to start thinking of exit strategies."),
							}),
						},
					}),
				},
			}),
			PlaceObj('ConversationLine', {
				Character = "Faucheux",
				Text = T(222072401930, --[[Conversation FaucheuxBetrayal Text voice:Faucheux section:FaucheuxBetrayal keyword:You will pay for this!]] "Chien soldiers, at attention! Les mercenaires have committed war crimes against our country. I proclaim them to be enemies of the state."),
			}),
		},
		StoryBranchIcon = "conversation_attack",
		id = "Youwillpayforthis",
	}),
})

