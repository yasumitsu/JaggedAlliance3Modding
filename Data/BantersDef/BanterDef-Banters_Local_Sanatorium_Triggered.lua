-- ========== GENERATED BY BanterDef Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('BanterDef', {
	FX = "CheckFail",
	Lines = {
		PlaceObj('BanterLine', {
			'Annotation', "reference to Stephen King's \"Pet Sematary\"",
			'Text', T(550284011111, --[[BanterDef BurialGrounds_SoilSample_failure Text]] "<medical-f> \nThe soil of Grand Chien is stony. A man digs what he can, and sometimes it's just rocks and stones."),
			'Voiced', false,
			'FloatUp', true,
		}),
	},
	group = "Banters_Local_Sanatorium_Triggered",
	id = "BurialGrounds_SoilSample_failure",
})

PlaceObj('BanterDef', {
	FX = "CheckSuccess",
	Lines = {
		PlaceObj('BanterLine', {
			'Annotation', "reference to Stephen King's \"Pet Sematary\"",
			'Text', T(475379123385, --[[BanterDef BurialGrounds_SoilSample_success Text]] "<medical-s>\nThe ground of Grand Chien is sour. Its high acidity and specific chemical properties facilitate some unique mutations."),
			'Voiced', false,
			'FloatUp', true,
		}),
		PlaceObj('BanterLine', {
			'MultipleTexts', true,
			'AnyOfThese', {
				PlaceObj('BanterLineThin', {
					'Character', "MD",
					'Text', T(795995511090, --[[BanterDef BurialGrounds_SoilSample_success Text section:Banters_Local_Sanatorium_Triggered/BurialGrounds_SoilSample_success voice:MD]] "I've never seen anything like this!"),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "DrQ",
					'Text', T(494275096633, --[[BanterDef BurialGrounds_SoilSample_success Text section:Banters_Local_Sanatorium_Triggered/BurialGrounds_SoilSample_success voice:DrQ]] "Very curious."),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "Larry",
					'Text', T(960981412244, --[[BanterDef BurialGrounds_SoilSample_success Text section:Banters_Local_Sanatorium_Triggered/BurialGrounds_SoilSample_success voice:Larry]] "Whoa. Like, acid, man."),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "Larry_Clean",
					'Text', T(734665260116, --[[BanterDef BurialGrounds_SoilSample_success Text section:Banters_Local_Sanatorium_Triggered/BurialGrounds_SoilSample_success voice:Larry_Clean]] "It's, like, acid... Someone else should hold this."),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "Thor",
					'Text', T(205230431947, --[[BanterDef BurialGrounds_SoilSample_success Text section:Banters_Local_Sanatorium_Triggered/BurialGrounds_SoilSample_success voice:Thor]] "There is a lot of bad energy in this ground."),
				}),
			},
			'playOnce', true,
		}),
	},
	group = "Banters_Local_Sanatorium_Triggered",
	id = "BurialGrounds_SoilSample_success",
})

PlaceObj('BanterDef', {
	Comment = "Interact with the shrouded figure on the wheelchair",
	Lines = {
		PlaceObj('BanterLine', {
			'Text', T(532512850731, --[[BanterDef CampHope_Ozzy_01 Text]] "A sheet looks to be wrapped around a motionless body."),
			'Voiced', false,
			'FloatUp', true,
		}),
		PlaceObj('BanterLine', {
			'MultipleTexts', true,
			'AnyOfThese', {
				PlaceObj('BanterLineThin', {
					'Character', "CivilianMale_1",
					'Text', T(509830121073, --[[BanterDef CampHope_Ozzy_01 Text section:Banters_Local_Sanatorium_Triggered/CampHope_Ozzy_01 voice:CivilianMale_1]] "<em>Ozzy</em> is a legend. He was the one who ate the bat in the first place."),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "CivilianMale_1",
					'Text', T(918748067646, --[[BanterDef CampHope_Ozzy_01 Text section:Banters_Local_Sanatorium_Triggered/CampHope_Ozzy_01 voice:CivilianMale_1]] "Spirits bless <em>Ozzy</em>. He taught us how to properly play ball."),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "CivilianFemale_1",
					'Text', T(895908811738, --[[BanterDef CampHope_Ozzy_01 Text section:Banters_Local_Sanatorium_Triggered/CampHope_Ozzy_01 voice:CivilianFemale_1]] "Shush, let <em>Ozzy</em> have some rest. Spirits know he deserves it."),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "CivilianFemale_1",
					'Text', T(235717919907, --[[BanterDef CampHope_Ozzy_01 Text section:Banters_Local_Sanatorium_Triggered/CampHope_Ozzy_01 voice:CivilianFemale_1]] "Don't mind them, <em>Ozzy</em>. They can't understand."),
				}),
			},
		}),
	},
	disabledInConflict = true,
	group = "Banters_Local_Sanatorium_Triggered",
	id = "CampHope_Ozzy_01",
})

PlaceObj('BanterDef', {
	Comment = "When you have the quest for virus samples and it is phase 3 of Camp Hope",
	Lines = {
		PlaceObj('BanterLine', {
			'Text', T(429777296757, --[[BanterDef CampHope_Ozzy_02 Text]] "The withered, long dead body of <em>Ozzy</em> provides his last gift to humanity."),
			'Voiced', false,
			'FloatUp', true,
		}),
	},
	disabledInConflict = true,
	group = "Banters_Local_Sanatorium_Triggered",
	id = "CampHope_Ozzy_02",
})

PlaceObj('BanterDef', {
	FX = "CheckFail",
	Lines = {
		PlaceObj('BanterLine', {
			'Text', T(377467729749, --[[BanterDef FactoryRuins_InfectedSample_failure Text]] "<medical-f>\nJust another infected corpse."),
			'Voiced', false,
			'FloatUp', true,
		}),
	},
	group = "Banters_Local_Sanatorium_Triggered",
	id = "FactoryRuins_InfectedSample_failure",
})

PlaceObj('BanterDef', {
	FX = "CheckSuccess",
	Lines = {
		PlaceObj('BanterLine', {
			'Text', T(398323419022, --[[BanterDef FactoryRuins_InfectedSample_success Text]] "<medical-s>\nThe body shows all necessary infection markers according to the notes of Dr. Kronenberg. It can be used as a sample for her research."),
			'Voiced', false,
			'FloatUp', true,
		}),
	},
	group = "Banters_Local_Sanatorium_Triggered",
	id = "FactoryRuins_InfectedSample_success",
})

PlaceObj('BanterDef', {
	FX = "CheckFail",
	Lines = {
		PlaceObj('BanterLine', {
			'Text', T(562665512010, --[[BanterDef FallenPlane_PlaneSample_failure Text]] "<mechanical-f> \nThe metal suitcase survived the crash relatively intact, but it takes a certain amount of engineering skill to release it from the bent and scorched remains of the plane."),
			'Voiced', false,
			'FloatUp', true,
		}),
		PlaceObj('BanterLine', {
			'MultipleTexts', true,
			'AnyOfThese', {
				PlaceObj('BanterLineThin', {
					'Character', "Fidel",
					'Text', T(967137518014, --[[BanterDef FallenPlane_PlaneSample_failure Text section:Banters_Local_Sanatorium_Triggered/FallenPlane_PlaneSample_failure voice:Fidel]] "Stupid box! What if Fidel plants TNT and destroys what remains of plane? "),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "Mouse",
					'Text', T(816763837600, --[[BanterDef FallenPlane_PlaneSample_failure Text section:Banters_Local_Sanatorium_Triggered/FallenPlane_PlaneSample_failure voice:Mouse]] "That's one piece of luggage that is going to stay lost."),
				}),
			},
			'Optional', true,
			'playOnce', true,
		}),
	},
	group = "Banters_Local_Sanatorium_Triggered",
	id = "FallenPlane_PlaneSample_failure",
})

PlaceObj('BanterDef', {
	FX = "CheckSuccess",
	Lines = {
		PlaceObj('BanterLine', {
			'Text', T(173034390067, --[[BanterDef FallenPlane_PlaneSample_success Text]] "<mechanical-s>\nIt takes a certain amount of engineering skill to release the suitcase from the bent and scorched remains of the plane.\nIt is full of broken vials that leaked out.\nOne is still intact."),
			'Voiced', false,
			'FloatUp', true,
		}),
		PlaceObj('BanterLine', {
			'MultipleTexts', true,
			'AnyOfThese', {
				PlaceObj('BanterLineThin', {
					'Character', "Nails",
					'Text', T(842610091013, --[[BanterDef FallenPlane_PlaneSample_success Text section:Banters_Local_Sanatorium_Triggered/FallenPlane_PlaneSample_success voice:Nails]] "That's some shit I wouldn't try to smoke, Scooter."),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "Gus",
					'Text', T(622200287966, --[[BanterDef FallenPlane_PlaneSample_success Text section:Banters_Local_Sanatorium_Triggered/FallenPlane_PlaneSample_success voice:Gus]] "Aaah, I'm not touching that thing, Woodinger."),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "Vicki",
					'Text', T(583845733717, --[[BanterDef FallenPlane_PlaneSample_success Text section:Banters_Local_Sanatorium_Triggered/FallenPlane_PlaneSample_success voice:Vicki]] "Next time, you be retrieving your own luggage, mon!"),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "Kalyna",
					'Text', T(247484519663, --[[BanterDef FallenPlane_PlaneSample_success Text section:Banters_Local_Sanatorium_Triggered/FallenPlane_PlaneSample_success voice:Kalyna]] "A magical potion! Just kidding. Yeah, this looks dangerous."),
				}),
			},
			'Optional', true,
			'playOnce', true,
		}),
	},
	group = "Banters_Local_Sanatorium_Triggered",
	id = "FallenPlane_PlaneSample_success",
})

PlaceObj('BanterDef', {
	FX = "CheckFail",
	Lines = {
		PlaceObj('BanterLine', {
			'Text', T(676247856120, --[[BanterDef SanatoriumAG_BodiesIncinerator_failure Text]] "<medical-f> \nSome of the bodies are prepared for incineration, which is perhaps a perfectly normal practice in Grand Chien."),
			'Voiced', false,
			'FloatUp', true,
		}),
		PlaceObj('BanterLine', {
			'MultipleTexts', true,
			'Text', "",
			'AnyOfThese', {
				PlaceObj('BanterLineThin', {
					'Character', "Reaper",
					'Text', T(204888688032, --[[BanterDef SanatoriumAG_BodiesIncinerator_failure Text section:Banters_Local_Sanatorium_Triggered/SanatoriumAG_BodiesIncinerator_failure voice:Reaper]] "Food for the flames."),
				}),
			},
			'Optional', true,
			'playOnce', true,
		}),
	},
	group = "Banters_Local_Sanatorium_Triggered",
	id = "SanatoriumAG_BodiesIncinerator_failure",
})

PlaceObj('BanterDef', {
	Comment = "high Medical >> gain clue",
	FX = "CheckSuccess",
	Lines = {
		PlaceObj('BanterLine', {
			'Text', T(108202039729, --[[BanterDef SanatoriumAG_BodiesIncinerator_success Text]] "<medical-s>\nSome of the bodies are prepared for incineration. They seem to have been recently infected and then euthanized."),
			'Voiced', false,
			'FloatUp', true,
		}),
		PlaceObj('BanterLine', {
			'MultipleTexts', true,
			'Text', "",
			'AnyOfThese', {
				PlaceObj('BanterLineThin', {
					'Character', "MD",
					'Text', T(828134345538, --[[BanterDef SanatoriumAG_BodiesIncinerator_success Text section:Banters_Local_Sanatorium_Triggered/SanatoriumAG_BodiesIncinerator_success voice:MD]] "These people have been euthanized before the infection progressed. They shouldn't be any more dangerous than those outside - just the opposite."),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "DrQ",
					'Text', T(298192269395, --[[BanterDef SanatoriumAG_BodiesIncinerator_success Text section:Banters_Local_Sanatorium_Triggered/SanatoriumAG_BodiesIncinerator_success voice:DrQ]] "Needle marks... It looks as if they have been infected and then killed before the disease was allowed to progress."),
				}),
			},
			'Optional', true,
			'playOnce', true,
		}),
		PlaceObj('BanterLine', {
			'Character', "Raven",
			'Text', T(266624487566, --[[BanterDef SanatoriumAG_BodiesIncinerator_success Text section:Banters_Local_Sanatorium_Triggered/SanatoriumAG_BodiesIncinerator_success high Medical >> gain clue voice:Raven]] "It looks like someone is trying to get rid of evidence."),
			'Optional', true,
			'playOnce', true,
		}),
	},
	group = "Banters_Local_Sanatorium_Triggered",
	id = "SanatoriumAG_BodiesIncinerator_success",
})

PlaceObj('BanterDef', {
	FX = "CheckFail",
	Lines = {
		PlaceObj('BanterLine', {
			'Text', T(171509721534, --[[BanterDef SanatoriumAG_BodiesTruck_failure Text]] "<wisdom-f>\nDead bodies loaded on a truck. Export or import, who can tell?"),
			'Voiced', false,
			'FloatUp', true,
		}),
		PlaceObj('BanterLine', {
			'MultipleTexts', true,
			'Text', "",
			'AnyOfThese', {
				PlaceObj('BanterLineThin', {
					'Character', "Igor",
					'Text', T(688616431861, --[[BanterDef SanatoriumAG_BodiesTruck_failure Text section:Banters_Local_Sanatorium_Triggered/SanatoriumAG_BodiesTruck_failure voice:Igor]] "I need a drink."),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "Vicki",
					'Text', T(135511433771, --[[BanterDef SanatoriumAG_BodiesTruck_failure Text section:Banters_Local_Sanatorium_Triggered/SanatoriumAG_BodiesTruck_failure voice:Vicki]] "Yuck! People should no be toting around dead bodies in a truck like this!"),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "Tex",
					'Text', T(427570276888, --[[BanterDef SanatoriumAG_BodiesTruck_failure Text section:Banters_Local_Sanatorium_Triggered/SanatoriumAG_BodiesTruck_failure voice:Tex]] "Bad scene, partner."),
				}),
			},
			'Optional', true,
			'playOnce', true,
		}),
	},
	group = "Banters_Local_Sanatorium_Triggered",
	id = "SanatoriumAG_BodiesTruck_failure",
})

PlaceObj('BanterDef', {
	Comment = "low Wisdom >> gain clue",
	FX = "CheckSuccess",
	Lines = {
		PlaceObj('BanterLine', {
			'Text', T(425475798856, --[[BanterDef SanatoriumAG_BodiesTruck_success Text]] "<wisdom-s>\nAll bodies have been carefully bound and secured. One might think the staff was taking precautions against the dead rising."),
			'Voiced', false,
			'FloatUp', true,
		}),
		PlaceObj('BanterLine', {
			'MultipleTexts', true,
			'Text', "",
			'AnyOfThese', {
				PlaceObj('BanterLineThin', {
					'Character', "Buns",
					'Text', T(354224422802, --[[BanterDef SanatoriumAG_BodiesTruck_success Text section:Banters_Local_Sanatorium_Triggered/SanatoriumAG_BodiesTruck_success voice:Buns]] "I wonder where they dump all these bodies."),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "Gus",
					'Text', T(174159224129, --[[BanterDef SanatoriumAG_BodiesTruck_success Text section:Banters_Local_Sanatorium_Triggered/SanatoriumAG_BodiesTruck_success voice:Gus]] "I'm damn sure of one thing, Woodman - I don't want to go to the sector east of here."),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "Thor",
					'Text', T(337465202531, --[[BanterDef SanatoriumAG_BodiesTruck_success Text section:Banters_Local_Sanatorium_Triggered/SanatoriumAG_BodiesTruck_success voice:Thor]] "There are many tire tracks that head off to the east."),
				}),
			},
			'Optional', true,
			'playOnce', true,
		}),
	},
	group = "Banters_Local_Sanatorium_Triggered",
	id = "SanatoriumAG_BodiesTruck_success",
})

PlaceObj('BanterDef', {
	Comment = ">> gain clue, combat",
	Lines = {
		PlaceObj('BanterLine', {
			'Text', T(435955500496, --[[BanterDef SanatoriumAG_BodyWall Text]] "There is movement inside!"),
			'Voiced', false,
			'FloatUp', true,
		}),
		PlaceObj('BanterLine', {
			'MultipleTexts', true,
			'Text', "",
			'AnyOfThese', {
				PlaceObj('BanterLineThin', {
					'Character', "Steroid",
					'Text', T(910437221947, --[[BanterDef SanatoriumAG_BodyWall Text section:Banters_Local_Sanatorium_Triggered/SanatoriumAG_BodyWall voice:Steroid]] "The corpus is moving!"),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "Ice",
					'Text', T(181502828501, --[[BanterDef SanatoriumAG_BodyWall Text section:Banters_Local_Sanatorium_Triggered/SanatoriumAG_BodyWall voice:Ice]] "Oh, HELL no..."),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "Grizzly",
					'Text', T(921097115544, --[[BanterDef SanatoriumAG_BodyWall Text section:Banters_Local_Sanatorium_Triggered/SanatoriumAG_BodyWall voice:Grizzly]] "Get behind me! Get behind me!"),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "Wolf",
					'Text', T(268249958593, --[[BanterDef SanatoriumAG_BodyWall Text section:Banters_Local_Sanatorium_Triggered/SanatoriumAG_BodyWall voice:Wolf]] "We're about to have company!"),
				}),
			},
			'Optional', true,
			'playOnce', true,
		}),
	},
	group = "Banters_Local_Sanatorium_Triggered",
	id = "SanatoriumAG_BodyWall",
})

PlaceObj('BanterDef', {
	FX = "CheckFail",
	Lines = {
		PlaceObj('BanterLine', {
			'Text', T(458010902109, --[[BanterDef SanatoriumAG_ClinicRadio_failure Text]] "<mechanical-f>\nClassical music playing."),
			'Voiced', false,
			'FloatUp', true,
		}),
	},
	group = "Banters_Local_Sanatorium_Triggered",
	id = "SanatoriumAG_ClinicRadio_failure",
})

PlaceObj('BanterDef', {
	Comment = "average Mechanical >> gain clue",
	FX = "CheckSuccess",
	Lines = {
		PlaceObj('BanterLine', {
			'Text', T(787312486294, --[[BanterDef SanatoriumAG_ClinicRadio_success Text]] '<mechanical-s>\nIt takes some time to find the right frequency.\n"I repeat, what are the Doctor\'s orders? Should I hire more healthy subjects, or is the last batch enough for now?"'),
			'Voiced', false,
			'FloatUp', true,
		}),
		PlaceObj('BanterLine', {
			'MultipleTexts', true,
			'Text', "",
			'AnyOfThese', {
				PlaceObj('BanterLineThin', {
					'Character', "Raven",
					'Text', T(774502765499, --[[BanterDef SanatoriumAG_ClinicRadio_success Text section:Banters_Local_Sanatorium_Triggered/SanatoriumAG_ClinicRadio_success voice:Raven]] "Why would a Sanatorium need healthy patients?!"),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "Gus",
					'Text', T(473969272049, --[[BanterDef SanatoriumAG_ClinicRadio_success Text section:Banters_Local_Sanatorium_Triggered/SanatoriumAG_ClinicRadio_success voice:Gus]] "What the hell is going on here, Woody?"),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "Magic",
					'Text', T(926220195594, --[[BanterDef SanatoriumAG_ClinicRadio_success Text section:Banters_Local_Sanatorium_Triggered/SanatoriumAG_ClinicRadio_success voice:Magic]] "This right here is why you don't see me signing up for clinical trials. Uh-uh. Not ever."),
				}),
			},
			'Optional', true,
			'playOnce', true,
		}),
	},
	group = "Banters_Local_Sanatorium_Triggered",
	id = "SanatoriumAG_ClinicRadio_success",
})

PlaceObj('BanterDef', {
	Lines = {
		PlaceObj('BanterLine', {
			'Text', T(462455881956, --[[BanterDef SanatoriumDoor_Canine Text]] '"Canine Test Subjects"'),
			'Voiced', false,
			'FloatUp', true,
		}),
	},
	group = "Banters_Local_Sanatorium_Triggered",
	id = "SanatoriumDoor_Canine",
})

PlaceObj('BanterDef', {
	Lines = {
		PlaceObj('BanterLine', {
			'Text', T(175237229353, --[[BanterDef SanatoriumDoor_Croc Text]] '"Beware of the Leopard!"'),
			'Voiced', false,
			'FloatUp', true,
		}),
	},
	group = "Banters_Local_Sanatorium_Triggered",
	id = "SanatoriumDoor_Croc",
})

PlaceObj('BanterDef', {
	Lines = {
		PlaceObj('BanterLine', {
			'Text', T(102918275776, --[[BanterDef SanatoriumDoor_DrMangel Text]] '"Director"'),
			'Voiced', false,
			'FloatUp', true,
		}),
	},
	group = "Banters_Local_Sanatorium_Triggered",
	id = "SanatoriumDoor_DrMangel",
})

PlaceObj('BanterDef', {
	Lines = {
		PlaceObj('BanterLine', {
			'Text', T(169836933090, --[[BanterDef SanatoriumDoor_Human Text]] '"Human Test Subjects"'),
			'Voiced', false,
			'FloatUp', true,
		}),
	},
	group = "Banters_Local_Sanatorium_Triggered",
	id = "SanatoriumDoor_Human",
})

PlaceObj('BanterDef', {
	Lines = {
		PlaceObj('BanterLine', {
			'Text', T(333332397374, --[[BanterDef SanatoriumDoor_Lab Text]] '"Lab"'),
			'Voiced', false,
			'FloatUp', true,
		}),
	},
	group = "Banters_Local_Sanatorium_Triggered",
	id = "SanatoriumDoor_Lab",
})

PlaceObj('BanterDef', {
	Lines = {
		PlaceObj('BanterLine', {
			'Text', T(654125436511, --[[BanterDef SanatoriumDoor_Morgue Text]] '"Morgue"'),
			'Voiced', false,
			'FloatUp', true,
		}),
	},
	group = "Banters_Local_Sanatorium_Triggered",
	id = "SanatoriumDoor_Morgue",
})

PlaceObj('BanterDef', {
	Lines = {
		PlaceObj('BanterLine', {
			'Text', T(334849572153, --[[BanterDef SanatoriumDoor_Storage Text]] '"Storage"'),
			'Voiced', false,
			'FloatUp', true,
		}),
	},
	group = "Banters_Local_Sanatorium_Triggered",
	id = "SanatoriumDoor_Storage",
})

PlaceObj('BanterDef', {
	Lines = {
		PlaceObj('BanterLine', {
			'Annotation', "Sanatorium guard - outbreak starts",
			'Character', "QueueDoctor",
			'Text', T(548589159079, --[[BanterDef SanatoriumNPC_event_GuardInitial Text section:Banters_Local_Sanatorium_Triggered/SanatoriumNPC_event_GuardInitial Sanatorium guard - outbreak starts voice:QueueDoctor]] "Get back in line! Sir, please have patience and get back in line. Sir! What the hell..."),
		}),
	},
	group = "Banters_Local_Sanatorium_Triggered",
	id = "SanatoriumNPC_event_GuardInitial",
})

PlaceObj('BanterDef', {
	Lines = {
		PlaceObj('BanterLine', {
			'Annotation', "Sanatorium guard - outbreak handled",
			'Character', "QueueDoctor2",
			'Text', T(226266788323, --[[BanterDef SanatoriumNPC_event_GuardOutbreakEnd Text section:Banters_Local_Sanatorium_Triggered/SanatoriumNPC_event_GuardOutbreakEnd Sanatorium guard - outbreak handled voice:QueueDoctor2]] "Thank you for your help. Now we have to clean this mess... I'm sorry I can't let you in, but the facility is closed by order of <em>Dr. Kronenberg</em>."),
		}),
	},
	group = "Banters_Local_Sanatorium_Triggered",
	id = "SanatoriumNPC_event_GuardOutbreakEnd",
})

PlaceObj('BanterDef', {
	Lines = {
		PlaceObj('BanterLine', {
			'Annotation', "Sanatorium guard - infected attacking the guards",
			'Character', "QueueGuard",
			'Text', T(929841538704, --[[BanterDef SanatoriumNPC_event_GuardOutbreakStart Text section:Banters_Local_Sanatorium_Triggered/SanatoriumNPC_event_GuardOutbreakStart Sanatorium guard - infected attacking the guards voice:QueueGuard]] "Shoot! Shoot to kill! It is an outbreak of les cadavérés!"),
		}),
	},
	group = "Banters_Local_Sanatorium_Triggered",
	id = "SanatoriumNPC_event_GuardOutbreakStart",
})

PlaceObj('BanterDef', {
	FX = "CheckFail",
	Lines = {
		PlaceObj('BanterLine', {
			'Text', T(270944886853, --[[BanterDef SanatoriumUG_DeadBodiesRoom_failure Text]] "<medical-f>\nLots of dead bodies."),
			'Voiced', false,
			'FloatUp', true,
		}),
		PlaceObj('BanterLine', {
			'MultipleTexts', true,
			'Text', "",
			'AnyOfThese', {
				PlaceObj('BanterLineThin', {
					'Character', "Fidel",
					'Text', T(361302571539, --[[BanterDef SanatoriumUG_DeadBodiesRoom_failure Text section:Banters_Local_Sanatorium_Triggered/SanatoriumUG_DeadBodiesRoom_failure voice:Fidel]] "Time for body parts puzzle!"),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "Mouse",
					'Text', T(864662245107, --[[BanterDef SanatoriumUG_DeadBodiesRoom_failure Text section:Banters_Local_Sanatorium_Triggered/SanatoriumUG_DeadBodiesRoom_failure voice:Mouse]] "Rest in peace... please?"),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "Reaper",
					'Text', T(761407729958, --[[BanterDef SanatoriumUG_DeadBodiesRoom_failure Text section:Banters_Local_Sanatorium_Triggered/SanatoriumUG_DeadBodiesRoom_failure voice:Reaper]] "Behold, the Dance Macabre."),
				}),
			},
			'Optional', true,
			'playOnce', true,
		}),
	},
	group = "Banters_Local_Sanatorium_Triggered",
	id = "SanatoriumUG_DeadBodiesRoom_failure",
})

PlaceObj('BanterDef', {
	Comment = "average Medical >> gain clue",
	FX = "CheckSuccess",
	Lines = {
		PlaceObj('BanterLine', {
			'Text', T(272970498922, --[[BanterDef SanatoriumUG_DeadBodiesRoom_success Text]] "<medical-s>\nThe bodies seem to have been euthanized with cyanide before the infection progressed."),
			'Voiced', false,
			'FloatUp', true,
		}),
		PlaceObj('BanterLine', {
			'MultipleTexts', true,
			'Text', "",
			'AnyOfThese', {
				PlaceObj('BanterLineThin', {
					'Character', "MD",
					'Text', T(875510872829, --[[BanterDef SanatoriumUG_DeadBodiesRoom_success Text section:Banters_Local_Sanatorium_Triggered/SanatoriumUG_DeadBodiesRoom_success voice:MD]] "If it wasn't an outrageous idea, I would think they infected these people on purpose and left them to die."),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "Thor",
					'Text', T(719008867295, --[[BanterDef SanatoriumUG_DeadBodiesRoom_success Text section:Banters_Local_Sanatorium_Triggered/SanatoriumUG_DeadBodiesRoom_success voice:Thor]] "These were test subjects. This is horrific!"),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "Fox",
					'Text', T(802908546265, --[[BanterDef SanatoriumUG_DeadBodiesRoom_success Text section:Banters_Local_Sanatorium_Triggered/SanatoriumUG_DeadBodiesRoom_success voice:Fox]] "I'm thinking that maybe this place isn't really a hospital at all."),
				}),
			},
			'Optional', true,
			'playOnce', true,
		}),
	},
	group = "Banters_Local_Sanatorium_Triggered",
	id = "SanatoriumUG_DeadBodiesRoom_success",
})

PlaceObj('BanterDef', {
	FX = "CheckFail",
	Lines = {
		PlaceObj('BanterLine', {
			'Text', T(132627705163, --[[BanterDef SanatoriumUG_DissectionTable_failure Text]] "<medical-f>\nDead body on the dissection table."),
			'Voiced', false,
			'FloatUp', true,
		}),
	},
	group = "Banters_Local_Sanatorium_Triggered",
	id = "SanatoriumUG_DissectionTable_failure",
})

PlaceObj('BanterDef', {
	Comment = "low Medical >> gain clue",
	FX = "CheckSuccess",
	Lines = {
		PlaceObj('BanterLine', {
			'Text', T(663265358426, --[[BanterDef SanatoriumUG_DissectionTable_success Text]] "<medical-s>\nThe fatal injury seems to have been inflicted after the autopsy started."),
			'Voiced', false,
			'FloatUp', true,
		}),
		PlaceObj('BanterLine', {
			'MultipleTexts', true,
			'Text', "",
			'AnyOfThese', {
				PlaceObj('BanterLineThin', {
					'Character', "Buns",
					'Text', T(890994970956, --[[BanterDef SanatoriumUG_DissectionTable_success Text section:Banters_Local_Sanatorium_Triggered/SanatoriumUG_DissectionTable_success voice:Buns]] "It seems the autopsy wasn't finished because the subject raised some objections to it. "),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "Thor",
					'Text', T(715215801263, --[[BanterDef SanatoriumUG_DissectionTable_success Text section:Banters_Local_Sanatorium_Triggered/SanatoriumUG_DissectionTable_success voice:Thor]] "Looks like the autopsy was never finished, because the body wasn't dead enough at the time."),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "DrQ",
					'Text', T(171133159994, --[[BanterDef SanatoriumUG_DissectionTable_success Text section:Banters_Local_Sanatorium_Triggered/SanatoriumUG_DissectionTable_success voice:DrQ]] "Perhaps this person decided to try to come back from the spirit world. "),
				}),
			},
			'Optional', true,
			'playOnce', true,
		}),
	},
	group = "Banters_Local_Sanatorium_Triggered",
	id = "SanatoriumUG_DissectionTable_success",
})

PlaceObj('BanterDef', {
	FX = "CheckFail",
	Lines = {
		PlaceObj('BanterLine', {
			'Text', T(781059588735, --[[BanterDef SanatoriumUG_LabCabinet_failure Text]] "<wisdom-f>\nLots of medical supplies with complicated names written in long dead tongues."),
			'Voiced', false,
			'FloatUp', true,
		}),
	},
	group = "Banters_Local_Sanatorium_Triggered",
	id = "SanatoriumUG_LabCabinet_failure",
})

PlaceObj('BanterDef', {
	Comment = "low Wisdom >> gain clue",
	FX = "CheckSuccess",
	Lines = {
		PlaceObj('BanterLine', {
			'Text', T(152239403012, --[[BanterDef SanatoriumUG_LabCabinet_success Text]] "<wisdom-s>\nThe cabinet is loaded with a startling amount of cyanide, but there are some medical supplies as well."),
			'Voiced', false,
			'FloatUp', true,
		}),
		PlaceObj('BanterLine', {
			'MultipleTexts', true,
			'AnyOfThese', {
				PlaceObj('BanterLineThin', {
					'Character', "Thor",
					'Text', T(960111163981, --[[BanterDef SanatoriumUG_LabCabinet_success Text section:Banters_Local_Sanatorium_Triggered/SanatoriumUG_LabCabinet_success voice:Thor]] "This is why I distrust modern pharmaceuticals. They are all like this."),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "Livewire",
					'Text', T(564419477004, --[[BanterDef SanatoriumUG_LabCabinet_success Text section:Banters_Local_Sanatorium_Triggered/SanatoriumUG_LabCabinet_success voice:Livewire]] "I am no doctor, but I really don't think having this much cyanide around is healthy."),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "Barry",
					'Text', T(681686804778, --[[BanterDef SanatoriumUG_LabCabinet_success Text section:Banters_Local_Sanatorium_Triggered/SanatoriumUG_LabCabinet_success voice:Barry]] "So many death chemicals. It is a thing of worry."),
				}),
			},
			'playOnce', true,
		}),
	},
	group = "Banters_Local_Sanatorium_Triggered",
	id = "SanatoriumUG_LabCabinet_success",
})

