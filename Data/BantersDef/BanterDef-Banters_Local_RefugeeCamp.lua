-- ========== GENERATED BY BanterDef Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('BanterDef', {
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "civ_Karen",
			'Text', T(132086709276, --[[BanterDef EnoughSightseeing_Karen_01_proximity Text section:Banters_Local_RefugeeCamp/EnoughSightseeing_Karen_01_proximity voice:civ_Karen]] "Hey, you! Are you Americans? Do you speak American? Does anyone here speak American?"),
			'playOnce', true,
		}),
	},
	conditions = {
		PlaceObj('CombatIsActive', {
			Negate = true,
		}),
	},
	disabledInConflict = true,
	group = "Banters_Local_RefugeeCamp",
	id = "EnoughSightseeing_Karen_01_proximity",
})

PlaceObj('BanterDef', {
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "Len",
			'Text', T(780749101076, --[[BanterDef EnoughSightseeing_Karen_02_first Text section:Banters_Local_RefugeeCamp/EnoughSightseeing_Karen_02_first voice:Len]] "How can we help you, ma'am?"),
			'Optional', true,
			'playOnce', true,
		}),
		PlaceObj('BanterLine', {
			'Character', "civ_Karen",
			'Text', T(885001493294, --[[BanterDef EnoughSightseeing_Karen_02_first Text section:Banters_Local_RefugeeCamp/EnoughSightseeing_Karen_02_first voice:civ_Karen]] "Finally, someone who speaks American! I was SUPPOSED to go to Morocco. THIS is not Morocco. THIS is one of those shit-hole countries! "),
			'playOnce', true,
		}),
		PlaceObj('BanterLine', {
			'Character', "Len",
			'Text', T(678910089796, --[[BanterDef EnoughSightseeing_Karen_02_first Text section:Banters_Local_RefugeeCamp/EnoughSightseeing_Karen_02_first voice:Len]] "We're not travel agents, ma'am. "),
			'Optional', true,
			'playOnce', true,
		}),
		PlaceObj('BanterLine', {
			'Character', "civ_Karen",
			'Text', T(620061933555, --[[BanterDef EnoughSightseeing_Karen_02_first Text section:Banters_Local_RefugeeCamp/EnoughSightseeing_Karen_02_first voice:civ_Karen]] "I've been trying to leave, but someone stole my purse! It has my <em>passport</em>, my nail polish, my hand sanitizer... everything! I'm sure one of THOSE people took it. I demand that you help me! Are you the manager of this camp or do I need to speak to your supervisor?"),
			'playOnce', true,
		}),
		PlaceObj('BanterLine', {
			'MultipleTexts', true,
			'Text', "",
			'AnyOfThese', {
				PlaceObj('BanterLineThin', {
					'Character', "Ice",
					'Text', T(651919214905, --[[BanterDef EnoughSightseeing_Karen_02_first Text section:Banters_Local_RefugeeCamp/EnoughSightseeing_Karen_02_first voice:Ice]] 'What you mean "those people"?'),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "Magic",
					'Text', T(871148129056, --[[BanterDef EnoughSightseeing_Karen_02_first Text section:Banters_Local_RefugeeCamp/EnoughSightseeing_Karen_02_first voice:Magic]] "Be cool, mama. We'll get you back to the land of whole milk and white bread."),
				}),
			},
			'Optional', true,
			'playOnce', true,
		}),
	},
	conditions = {
		PlaceObj('QuestIsVariableBool', {
			QuestId = "RefugeeBlues",
			Vars = set({
	KarenKilled = false,
	KarenPassportFound = false,
	KarenPassportGiven = false,
	KarenQuestGiven = false,
}),
			__eval = function ()
				local quest = gv_Quests['RefugeeBlues'] or QuestGetState('RefugeeBlues')
				return not quest.KarenKilled and not quest.KarenPassportFound and not quest.KarenPassportGiven and not quest.KarenQuestGiven
			end,
		}),
	},
	disabledInConflict = true,
	group = "Banters_Local_RefugeeCamp",
	id = "EnoughSightseeing_Karen_02_first",
})

PlaceObj('BanterDef', {
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "civ_Karen",
			'Text', T(239255911231, --[[BanterDef EnoughSightseeing_Karen_03_repeated Text section:Banters_Local_RefugeeCamp/EnoughSightseeing_Karen_03_repeated voice:civ_Karen]] "Haven't you found my <em>passport</em>? How long do I have to wait for a simple service like that?!"),
		}),
	},
	conditions = {
		PlaceObj('QuestIsVariableBool', {
			QuestId = "RefugeeBlues",
			Vars = set({
	KarenKilled = false,
	KarenPassportGiven = false,
	KarenQuestGiven = true,
}),
			__eval = function ()
				local quest = gv_Quests['RefugeeBlues'] or QuestGetState('RefugeeBlues')
				return not quest.KarenKilled and not quest.KarenPassportGiven and quest.KarenQuestGiven
			end,
		}),
	},
	disabledInConflict = true,
	group = "Banters_Local_RefugeeCamp",
	id = "EnoughSightseeing_Karen_03_repeated",
})

PlaceObj('BanterDef', {
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "civ_Karen",
			'Text', T(885293379635, --[[BanterDef EnoughSightseeing_Karen_05_passport Text section:Banters_Local_RefugeeCamp/EnoughSightseeing_Karen_05_passport voice:civ_Karen]] "Oh, here it is! It was about time! Why is it so hard to find good service these days? I suppose you want some kind of reward. Typical of you people."),
		}),
		PlaceObj('BanterLine', {
			'Character', "Blood",
			'Text', T(209839556382, --[[BanterDef EnoughSightseeing_Karen_05_passport Text section:Banters_Local_RefugeeCamp/EnoughSightseeing_Karen_05_passport voice:Blood]] "Doing good things for people is its own reward, but for you I'll make an exception!"),
			'Optional', true,
		}),
	},
	conditions = {
		PlaceObj('QuestIsVariableBool', {
			QuestId = "RefugeeBlues",
			Vars = set({
	KarenKilled = false,
	KarenPassportFound = true,
}),
			__eval = function ()
				local quest = gv_Quests['RefugeeBlues'] or QuestGetState('RefugeeBlues')
				return not quest.KarenKilled and quest.KarenPassportFound
			end,
		}),
		PlaceObj('UnitSquadHasItem', {
			ItemId = "US_Passport",
		}),
	},
	disabledInConflict = true,
	group = "Banters_Local_RefugeeCamp",
	id = "EnoughSightseeing_Karen_05_passport",
})

PlaceObj('BanterDef', {
	Comment = "- not hacked, repeating",
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "civ_Pepe",
			'Text', T(169624591443, --[[BanterDef PleasingTheSpirits_Pepe_02_NotHacked Text section:Banters_Local_RefugeeCamp/PleasingTheSpirits_Pepe_02_NotHacked - not hacked, repeating voice:civ_Pepe]] "Can't you fix that encryption? The way it is now, the scrambling makes it look like this man has three legs!"),
		}),
		PlaceObj('BanterLine', {
			'Character', "Fox",
			'Text', T(439233929360, --[[BanterDef PleasingTheSpirits_Pepe_02_NotHacked Text section:Banters_Local_RefugeeCamp/PleasingTheSpirits_Pepe_02_NotHacked - not hacked, repeating voice:Fox]] "Oh, sweetie, that's... that's not a third leg."),
			'Optional', true,
			'playOnce', true,
		}),
	},
	conditions = {
		PlaceObj('QuestIsVariableBool', {
			QuestId = "RefugeeBlues",
			Vars = set({
	SatelliteHacked = false,
}),
			__eval = function ()
				local quest = gv_Quests['RefugeeBlues'] or QuestGetState('RefugeeBlues')
				return not quest.SatelliteHacked
			end,
		}),
	},
	disabledInConflict = true,
	group = "Banters_Local_RefugeeCamp",
	id = "PleasingTheSpirits_Pepe_02_NotHacked",
})

PlaceObj('BanterDef', {
	Comment = "- hacked, repeating",
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "civ_Pepe",
			'Text', T(981979415179, --[[BanterDef PleasingTheSpirits_Pepe_03_Hacked Text section:Banters_Local_RefugeeCamp/PleasingTheSpirits_Pepe_03_Hacked - hacked, repeating voice:civ_Pepe]] "Now that you fixed the encryption, I can finally see what is going on and who is doing who and with what! You have made this camp a much more enjoyable place to stay!"),
		}),
		PlaceObj('BanterLine', {
			'Character', "MD",
			'Text', T(547921236261, --[[BanterDef PleasingTheSpirits_Pepe_03_Hacked Text section:Banters_Local_RefugeeCamp/PleasingTheSpirits_Pepe_03_Hacked - hacked, repeating voice:MD]] "Just remember to take breaks and... um, stay hydrated."),
			'Optional', true,
		}),
	},
	conditions = {
		PlaceObj('QuestIsVariableBool', {
			QuestId = "RefugeeBlues",
			Vars = set( "SatelliteHacked" ),
			__eval = function ()
				local quest = gv_Quests['RefugeeBlues'] or QuestGetState('RefugeeBlues')
				return quest.SatelliteHacked
			end,
		}),
	},
	disabledInConflict = true,
	group = "Banters_Local_RefugeeCamp",
	id = "PleasingTheSpirits_Pepe_03_Hacked",
})

PlaceObj('BanterDef', {
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "CivilianFemale_1",
			'Text', T(220708445090, --[[BanterDef RefugeeCamp_VillagerFemale_01 Text section:Banters_Local_RefugeeCamp/RefugeeCamp_VillagerFemale_01 voice:CivilianFemale_1]] "The smuggler has given me only seven food rations for my mother's gold ring. Bastard."),
		}),
	},
	conditions = {
		PlaceObj('SectorCheckCity', {
			city = "RefugeeCamp",
		}),
		PlaceObj('QuestIsVariableBool', {
			QuestId = "RefugeeBlues",
			Vars = set({
	BastienProBono = false,
}),
			__eval = function ()
				local quest = gv_Quests['RefugeeBlues'] or QuestGetState('RefugeeBlues')
				return not quest.BastienProBono
			end,
		}),
	},
	disabledInConflict = true,
	group = "Banters_Local_RefugeeCamp",
	id = "RefugeeCamp_VillagerFemale_01",
})

PlaceObj('BanterDef', {
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "CivilianFemale_1",
			'Text', T(142558136341, --[[BanterDef RefugeeCamp_VillagerFemale_02 Text section:Banters_Local_RefugeeCamp/RefugeeCamp_VillagerFemale_02 voice:CivilianFemale_1]] "I really like Pepe, but he needs to find a hobby. I have other things to do besides... him!"),
		}),
	},
	conditions = {
		PlaceObj('SectorCheckCity', {
			city = "RefugeeCamp",
		}),
	},
	disabledInConflict = true,
	group = "Banters_Local_RefugeeCamp",
	id = "RefugeeCamp_VillagerFemale_02",
})

PlaceObj('BanterDef', {
	Comment = "Pepe",
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "CivilianFemale_1",
			'Text', T(301771121273, --[[BanterDef RefugeeCamp_VillagerFemale_03 Text section:Banters_Local_RefugeeCamp/RefugeeCamp_VillagerFemale_03 Pepe voice:CivilianFemale_1]] "Thank you for giving Pepe a distraction. Although, now I worry that he might go blind."),
		}),
		PlaceObj('BanterLine', {
			'Character', "MD",
			'Text', T(250656390351, --[[BanterDef RefugeeCamp_VillagerFemale_03 Text section:Banters_Local_RefugeeCamp/RefugeeCamp_VillagerFemale_03 Pepe voice:MD]] "Just remind him to stay hydrated... and blink every once in a while."),
			'Optional', true,
			'playOnce', true,
		}),
	},
	conditions = {
		PlaceObj('SectorCheckCity', {
			city = "RefugeeCamp",
		}),
		PlaceObj('QuestIsVariableBool', {
			Condition = "or",
			QuestId = "RefugeeBlues",
			Vars = set( "SatelliteHacked", "SatelliteQuest" ),
			__eval = function ()
				local quest = gv_Quests['RefugeeBlues'] or QuestGetState('RefugeeBlues')
				return quest.SatelliteHacked or quest.SatelliteQuest
			end,
		}),
	},
	disabledInConflict = true,
	group = "Banters_Local_RefugeeCamp",
	id = "RefugeeCamp_VillagerFemale_03",
})

PlaceObj('BanterDef', {
	Comment = "Shaman reputation",
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "CivilianFemale_2",
			'Text', T(900477130132, --[[BanterDef RefugeeCamp_VillagerFemale_04 Text section:Banters_Local_RefugeeCamp/RefugeeCamp_VillagerFemale_04 Shaman reputation voice:CivilianFemale_2]] "The <em>Shaman</em> has been fooling us! I thought the spirits were giving him his power, but he needed a <em>doctor</em> to cure his own family!"),
		}),
	},
	conditions = {
		PlaceObj('SectorCheckCity', {
			city = "RefugeeCamp",
		}),
		PlaceObj('QuestIsVariableBool', {
			QuestId = "FaithHealing",
			Vars = set({
	FamilyHealed = true,
	MetavironGiven = false,
}),
			__eval = function ()
				local quest = gv_Quests['FaithHealing'] or QuestGetState('FaithHealing')
				return quest.FamilyHealed and not quest.MetavironGiven
			end,
		}),
	},
	disabledInConflict = true,
	group = "Banters_Local_RefugeeCamp",
	id = "RefugeeCamp_VillagerFemale_04",
})

PlaceObj('BanterDef', {
	Comment = "Shaman reputation",
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "CivilianFemale_2",
			'Text', T(800085485680, --[[BanterDef RefugeeCamp_VillagerFemale_05 Text section:Banters_Local_RefugeeCamp/RefugeeCamp_VillagerFemale_05 Shaman reputation voice:CivilianFemale_2]] "You look in pain. Maybe you have constipated bowels? Go to the <em>Shaman</em> - he has a spell that will help you unleash your inner volcano!"),
		}),
		PlaceObj('BanterLine', {
			'MultipleTexts', true,
			'AnyOfThese', {
				PlaceObj('BanterLineThin', {
					'Character', "Mouse",
					'Text', T(248268012110, --[[BanterDef RefugeeCamp_VillagerFemale_05 Text section:Banters_Local_RefugeeCamp/RefugeeCamp_VillagerFemale_05 voice:Mouse]] "Ew!... No!"),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "Nails",
					'Text', T(985147854526, --[[BanterDef RefugeeCamp_VillagerFemale_05 Text section:Banters_Local_RefugeeCamp/RefugeeCamp_VillagerFemale_05 voice:Nails]] "Yeah, we've got some bullshit to deal with, but this shit ain't part of it."),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "Red",
					'Text', T(542864793317, --[[BanterDef RefugeeCamp_VillagerFemale_05 Text section:Banters_Local_RefugeeCamp/RefugeeCamp_VillagerFemale_05 voice:Red]] "That's just a crock of shite, lassie."),
				}),
			},
		}),
	},
	conditions = {
		PlaceObj('SectorCheckCity', {
			city = "RefugeeCamp",
		}),
		PlaceObj('OR', {
			Conditions = {
				PlaceObj('QuestIsVariableBool', {
					QuestId = "FaithHealing",
					Vars = set({
	FamilyHealed = false,
}),
					__eval = function ()
						local quest = gv_Quests['FaithHealing'] or QuestGetState('FaithHealing')
						return not quest.FamilyHealed
					end,
				}),
				PlaceObj('QuestIsVariableBool', {
					QuestId = "FaithHealing",
					Vars = set( "FamilyHealed", "MetavironGiven" ),
					__eval = function ()
						local quest = gv_Quests['FaithHealing'] or QuestGetState('FaithHealing')
						return quest.FamilyHealed and quest.MetavironGiven
					end,
				}),
			},
		}),
		PlaceObj('WoundedMercs', {
			minWounds = 2,
		}),
	},
	disabledInConflict = true,
	group = "Banters_Local_RefugeeCamp",
	id = "RefugeeCamp_VillagerFemale_05",
})

PlaceObj('BanterDef', {
	Comment = "BastienShare >> Guilty",
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "CivilianFemale_2",
			'Text', T(165396090116, --[[BanterDef RefugeeCamp_VillagerFemale_06 Text section:Banters_Local_RefugeeCamp/RefugeeCamp_VillagerFemale_06 BastienShare >> Guilty voice:CivilianFemale_2]] "We hoped you would talk some sense into that smuggler who has been extorting us, and what did you do? You joined him! Shame on you!"),
		}),
	},
	conditions = {
		PlaceObj('SectorCheckCity', {
			city = "RefugeeCamp",
		}),
		PlaceObj('QuestIsVariableBool', {
			QuestId = "RefugeeBlues",
			Vars = set( "BastienShare" ),
			__eval = function ()
				local quest = gv_Quests['RefugeeBlues'] or QuestGetState('RefugeeBlues')
				return quest.BastienShare
			end,
		}),
	},
	disabledInConflict = true,
	group = "Banters_Local_RefugeeCamp",
	id = "RefugeeCamp_VillagerFemale_06",
})

PlaceObj('BanterDef', {
	Comment = ">> Proud",
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "CivilianFemale_1",
			'Text', T(845742755543, --[[BanterDef RefugeeCamp_VillagerFemale_07_Loyalty Text section:Banters_Local_RefugeeCamp/RefugeeCamp_VillagerFemale_07_Loyalty >> Proud voice:CivilianFemale_1]] "I got a letter from my husband! I thought he was dead, but you saved him and gave him a job! We will be together again. May the spirits bless you!"),
		}),
	},
	Once = true,
	conditions = {
		PlaceObj('SectorCheckCity', {
			city = "RefugeeCamp",
		}),
		PlaceObj('CityHasLoyalty', {
			Amount = 50,
			City = "RefugeeCamp",
			Condition = ">=",
		}),
		PlaceObj('PlayerControlSectors', {
			Amount = 2,
			Condition = ">=",
			POIs = "Mine",
		}),
	},
	disabledInConflict = true,
	group = "Banters_Local_RefugeeCamp",
	id = "RefugeeCamp_VillagerFemale_07_Loyalty",
})

PlaceObj('BanterDef', {
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "CivilianMale_1",
			'Text', T(479200707791, --[[BanterDef RefugeeCamp_VillagerMale_01 Text section:Banters_Local_RefugeeCamp/RefugeeCamp_VillagerMale_01 voice:CivilianMale_1]] "The lady on the TV said the new government is negotiating with the separatists! Maybe we'll be able to return home soon."),
		}),
	},
	conditions = {
		PlaceObj('SectorCheckCity', {
			city = "RefugeeCamp",
		}),
	},
	disabledInConflict = true,
	group = "Banters_Local_RefugeeCamp",
	id = "RefugeeCamp_VillagerMale_01",
})

PlaceObj('BanterDef', {
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "CivilianMale_2",
			'Text', T(789258775850, --[[BanterDef RefugeeCamp_VillagerMale_02 Text section:Banters_Local_RefugeeCamp/RefugeeCamp_VillagerMale_02 voice:CivilianMale_2]] "Do you like my tent? Cozy, isn't it? I moved in after the Legion took the people who lived there."),
		}),
	},
	conditions = {
		PlaceObj('SectorCheckCity', {
			city = "RefugeeCamp",
		}),
	},
	disabledInConflict = true,
	group = "Banters_Local_RefugeeCamp",
	id = "RefugeeCamp_VillagerMale_02",
})

PlaceObj('BanterDef', {
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "CivilianMale_1",
			'Text', T(543847019172, --[[BanterDef RefugeeCamp_VillagerMale_03 Text section:Banters_Local_RefugeeCamp/RefugeeCamp_VillagerMale_03 voice:CivilianMale_1]] "No fish in the river - too much garbage. But you can get food rations for some of it! Amazing what people throw away."),
			'playOnce', true,
		}),
		PlaceObj('BanterLine', {
			'Character', "Buns",
			'Text', T(268745341030, --[[BanterDef RefugeeCamp_VillagerMale_03 Text section:Banters_Local_RefugeeCamp/RefugeeCamp_VillagerMale_03 voice:Buns]] "You are fishing... garbage?!"),
			'Optional', true,
			'playOnce', true,
		}),
		PlaceObj('BanterLine', {
			'Character', "CivilianMale_1",
			'Text', T(833241279599, --[[BanterDef RefugeeCamp_VillagerMale_03 Text section:Banters_Local_RefugeeCamp/RefugeeCamp_VillagerMale_03 voice:CivilianMale_1]] "My best catch so far was a dead man with nice clothes and a shiny gold earring!"),
		}),
		PlaceObj('BanterLine', {
			'Character', "Buns",
			'Text', T(513294917314, --[[BanterDef RefugeeCamp_VillagerMale_03 Text section:Banters_Local_RefugeeCamp/RefugeeCamp_VillagerMale_03 voice:Buns]] "Well, how... um... nice for you."),
			'Optional', true,
			'playOnce', true,
		}),
	},
	conditions = {
		PlaceObj('OR', {
			Conditions = {
				PlaceObj('SectorCheckCity', {
					city = "RefugeeCamp",
				}),
				PlaceObj('PlayerIsInSectors', {
					Sectors = {
						"H9",
					},
				}),
			},
		}),
	},
	disabledInConflict = true,
	group = "Banters_Local_RefugeeCamp",
	id = "RefugeeCamp_VillagerMale_03",
})

PlaceObj('BanterDef', {
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "CivilianMale_3",
			'Text', T(526512667589, --[[BanterDef RefugeeCamp_VillagerMale_04 Text section:Banters_Local_RefugeeCamp/RefugeeCamp_VillagerMale_04 voice:CivilianMale_3]] 'I watched "Much Dust, Many Bullets" yesterday on the TV.'),
		}),
		PlaceObj('BanterLine', {
			'Character', "Tex",
			'Text', T(464505289639, --[[BanterDef RefugeeCamp_VillagerMale_04 Text section:Banters_Local_RefugeeCamp/RefugeeCamp_VillagerMale_04 voice:Tex]] "Oh, if you want autograph with movie star, I can arrange that!"),
			'Optional', true,
			'playOnce', true,
		}),
		PlaceObj('BanterLine', {
			'Character', "CivilianMale_3",
			'Text', T(516034752860, --[[BanterDef RefugeeCamp_VillagerMale_04 Text section:Banters_Local_RefugeeCamp/RefugeeCamp_VillagerMale_04 voice:CivilianMale_3]] "It's crap. The plot is dumb, the costumes are stupid, and my dog is a better actor than the lead. They should make movies with you guys instead!"),
		}),
		PlaceObj('BanterLine', {
			'Character', "Tex",
			'Text', T(431503182524, --[[BanterDef RefugeeCamp_VillagerMale_04 Text section:Banters_Local_RefugeeCamp/RefugeeCamp_VillagerMale_04 voice:Tex]] "Uh... Thanks?"),
			'Optional', true,
			'playOnce', true,
		}),
	},
	Once = true,
	conditions = {
		PlaceObj('SectorCheckCity', {
			city = "RefugeeCamp",
		}),
		PlaceObj('UnitSquadHasMerc', {
			Name = "Tex",
		}),
	},
	disabledInConflict = true,
	group = "Banters_Local_RefugeeCamp",
	id = "RefugeeCamp_VillagerMale_04",
})

PlaceObj('BanterDef', {
	Comment = "Karen",
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "CivilianMale_3",
			'Text', T(738343917104, --[[BanterDef RefugeeCamp_VillagerMale_05 Text section:Banters_Local_RefugeeCamp/RefugeeCamp_VillagerMale_05 Karen voice:CivilianMale_3]] "Thank you for lifting the curse over this camp!"),
		}),
		PlaceObj('BanterLine', {
			'MultipleTexts', true,
			'AnyOfThese', {
				PlaceObj('BanterLineThin', {
					'Character', "Tex",
					'Text', T(925197024168, --[[BanterDef RefugeeCamp_VillagerMale_05 Text section:Banters_Local_RefugeeCamp/RefugeeCamp_VillagerMale_05 voice:Tex]] "You are welcome, friend! Those Legion desperados will trouble you no more."),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "Steroid",
					'Text', T(562216984955, --[[BanterDef RefugeeCamp_VillagerMale_05 Text section:Banters_Local_RefugeeCamp/RefugeeCamp_VillagerMale_05 voice:Steroid]] "Ha! I lift so much, I didn't even notice! How much did this curse weigh?"),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "Kalyna",
					'Text', T(519104339435, --[[BanterDef RefugeeCamp_VillagerMale_05 Text section:Banters_Local_RefugeeCamp/RefugeeCamp_VillagerMale_05 voice:Kalyna]] "We lifted a curse? Did we kill an evil wizard and I missed it?"),
				}),
			},
		}),
		PlaceObj('BanterLine', {
			'Character', "CivilianMale_3",
			'Text', T(440296305809, --[[BanterDef RefugeeCamp_VillagerMale_05 Text section:Banters_Local_RefugeeCamp/RefugeeCamp_VillagerMale_05 Karen voice:CivilianMale_3]] "I mean, that American woman... Karen. She was a curse! Everywhere she went, she made people feel bad!"),
		}),
	},
	conditions = {
		PlaceObj('SectorCheckCity', {
			city = "RefugeeCamp",
		}),
		PlaceObj('QuestIsVariableBool', {
			Condition = "or",
			QuestId = "RefugeeBlues",
			Vars = set( "KarenKilled", "KarenPassportGiven" ),
			__eval = function ()
				local quest = gv_Quests['RefugeeBlues'] or QuestGetState('RefugeeBlues')
				return quest.KarenKilled or quest.KarenPassportGiven
			end,
		}),
	},
	disabledInConflict = true,
	group = "Banters_Local_RefugeeCamp",
	id = "RefugeeCamp_VillagerMale_05",
})

PlaceObj('BanterDef', {
	Comment = "Shaman reputation",
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "CivilianMale_2",
			'Text', T(467898808127, --[[BanterDef RefugeeCamp_VillagerMale_06 Text section:Banters_Local_RefugeeCamp/RefugeeCamp_VillagerMale_06 Shaman reputation voice:CivilianMale_2]] "I paid twelve eggs to get a healing ritual for my family, and now that HIS family is sick, <em>Sangoma</em> calls a <em>doctor</em>?! I want my eggs back."),
		}),
	},
	conditions = {
		PlaceObj('SectorCheckCity', {
			city = "RefugeeCamp",
		}),
		PlaceObj('QuestIsVariableBool', {
			QuestId = "FaithHealing",
			Vars = set({
	FamilyHealed = true,
	MetavironGiven = false,
}),
			__eval = function ()
				local quest = gv_Quests['FaithHealing'] or QuestGetState('FaithHealing')
				return quest.FamilyHealed and not quest.MetavironGiven
			end,
		}),
	},
	disabledInConflict = true,
	group = "Banters_Local_RefugeeCamp",
	id = "RefugeeCamp_VillagerMale_06",
})

PlaceObj('BanterDef', {
	Comment = ">> give quest (bool CludetteLead)",
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "civ_Antoine",
			'Text', T(695712897869, --[[BanterDef SavingClaudette_Antoine_00_approach Text section:Banters_Local_RefugeeCamp/SavingClaudette_Antoine_00_approach >> give quest (bool CludetteLead) voice:civ_Antoine]] "Excusez-moi... You come from outside the camp, right? Have you seen my sister, <em>Claudette</em>? The Legion, they took her somewhere <em>North</em> of here..."),
		}),
	},
	conditions = {
		PlaceObj('QuestIsVariableBool', {
			QuestId = "RefugeeBlues",
			Vars = set({
	ClaudetteLead = false,
	ClaudetteSaved = false,
	ClaudetteTimerStart = false,
}),
			__eval = function ()
				local quest = gv_Quests['RefugeeBlues'] or QuestGetState('RefugeeBlues')
				return not quest.ClaudetteLead and not quest.ClaudetteSaved and not quest.ClaudetteTimerStart
			end,
		}),
		PlaceObj('CheckIsPersistentUnitDead', {
			Negate = true,
			per_ses_id = "NPC_Claudette",
		}),
	},
	disabledInConflict = true,
	group = "Banters_Local_RefugeeCamp",
	id = "SavingClaudette_Antoine_00_approach",
})

PlaceObj('BanterDef', {
	Comment = "Claudette not saved yet",
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "Blood",
			'Text', T(425876755743, --[[BanterDef SavingClaudette_Antoine_01 Text section:Banters_Local_RefugeeCamp/SavingClaudette_Antoine_01 Claudette not saved yet voice:Blood]] "If they took your sister, why are you still here talking about it?"),
			'Optional', true,
		}),
		PlaceObj('BanterLine', {
			'Character', "civ_Antoine",
			'Text', T(980136772222, --[[BanterDef SavingClaudette_Antoine_01 Text section:Banters_Local_RefugeeCamp/SavingClaudette_Antoine_01 Claudette not saved yet voice:civ_Antoine]] "The <em>Legion</em> marauders came into the camp, rounded up whoever they wanted at gun point and took them away. What could I do? I have no weapons and no one will help me! "),
		}),
		PlaceObj('BanterLine', {
			'Character', "Raven",
			'Text', T(231945093406, --[[BanterDef SavingClaudette_Antoine_01 Text section:Banters_Local_RefugeeCamp/SavingClaudette_Antoine_01 Claudette not saved yet voice:Raven]] "Great. Kidnappers. I hate kidnappers. The order of lowlifes goes criminals, then pond scum, then kidnappers."),
			'Optional', true,
		}),
	},
	conditions = {
		PlaceObj('QuestIsVariableBool', {
			QuestId = "RefugeeBlues",
			Vars = set({
	ClaudetteLead = true,
	ClaudetteSaved = false,
	ClaudetteTimerStart = false,
}),
			__eval = function ()
				local quest = gv_Quests['RefugeeBlues'] or QuestGetState('RefugeeBlues')
				return quest.ClaudetteLead and not quest.ClaudetteSaved and not quest.ClaudetteTimerStart
			end,
		}),
		PlaceObj('CheckIsPersistentUnitDead', {
			Negate = true,
			per_ses_id = "NPC_Claudette",
		}),
	},
	disabledInConflict = true,
	group = "Banters_Local_RefugeeCamp",
	id = "SavingClaudette_Antoine_01",
})

PlaceObj('BanterDef', {
	Comment = "Claudette not saved yet",
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "civ_Antoine",
			'Text', T(242086310968, --[[BanterDef SavingClaudette_Antoine_02 Text section:Banters_Local_RefugeeCamp/SavingClaudette_Antoine_02 Claudette not saved yet voice:civ_Antoine]] "I fear they will make <em>Claudette</em> a slave, or... worse."),
		}),
		PlaceObj('BanterLine', {
			'MultipleTexts', true,
			'AnyOfThese', {
				PlaceObj('BanterLineThin', {
					'Character', "Meltdown",
					'Text', T(678115673770, --[[BanterDef SavingClaudette_Antoine_02 Text section:Banters_Local_RefugeeCamp/SavingClaudette_Antoine_02 voice:Meltdown]] "Not on MY watch, kid!"),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "Vicki",
					'Text', T(522998967577, --[[BanterDef SavingClaudette_Antoine_02 Text section:Banters_Local_RefugeeCamp/SavingClaudette_Antoine_02 voice:Vicki]] "Don't worry yourself, mon. We not gonna let that happen."),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "Smiley",
					'Text', T(659666877650, --[[BanterDef SavingClaudette_Antoine_02 Text section:Banters_Local_RefugeeCamp/SavingClaudette_Antoine_02 voice:Smiley]] "Have no fear, muchacho. Whenever a woman will be used as a slave, Alejandro Diaz will come."),
				}),
			},
			'Optional', true,
			'playOnce', true,
		}),
	},
	conditions = {
		PlaceObj('QuestIsVariableBool', {
			QuestId = "RefugeeBlues",
			Vars = set({
	ClaudetteLead = true,
	ClaudetteSaved = false,
	ClaudetteTimerStart = false,
}),
			__eval = function ()
				local quest = gv_Quests['RefugeeBlues'] or QuestGetState('RefugeeBlues')
				return quest.ClaudetteLead and not quest.ClaudetteSaved and not quest.ClaudetteTimerStart
			end,
		}),
		PlaceObj('CheckIsPersistentUnitDead', {
			Negate = true,
			per_ses_id = "NPC_Claudette",
		}),
	},
	disabledInConflict = true,
	group = "Banters_Local_RefugeeCamp",
	id = "SavingClaudette_Antoine_02",
})

PlaceObj('BanterDef', {
	Comment = "Claudette dead",
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "civ_Antoine",
			'Text', T(234640814859, --[[BanterDef SavingClaudette_Antoine_03_approach Text section:Banters_Local_RefugeeCamp/SavingClaudette_Antoine_03_approach Claudette dead voice:civ_Antoine]] "My sister... They found her dead. She fought the Legion with a stolen knife!... But they shot her anyway."),
		}),
	},
	Once = true,
	conditions = {
		PlaceObj('CheckIsPersistentUnitDead', {
			per_ses_id = "NPC_Claudette",
		}),
		PlaceObj('QuestIsVariableBool', {
			QuestId = "_GroupsAttacked",
			Vars = set({
	civ_Claudette_Killed = false,
}),
			__eval = function ()
				local quest = gv_Quests['_GroupsAttacked'] or QuestGetState('_GroupsAttacked')
				return not quest.civ_Claudette_Killed
			end,
		}),
		PlaceObj('QuestIsVariableBool', {
			QuestId = "RefugeeBlues",
			Vars = set({
	ClaudetteSaved = false,
}),
			__eval = function ()
				local quest = gv_Quests['RefugeeBlues'] or QuestGetState('RefugeeBlues')
				return not quest.ClaudetteSaved
			end,
		}),
	},
	disabledInConflict = true,
	group = "Banters_Local_RefugeeCamp",
	id = "SavingClaudette_Antoine_03_approach",
})

PlaceObj('BanterDef', {
	Comment = "Claudette dead",
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "civ_Antoine",
			'Text', T(934280313952, --[[BanterDef SavingClaudette_Antoine_04 Text section:Banters_Local_RefugeeCamp/SavingClaudette_Antoine_04 Claudette dead voice:civ_Antoine]] "I was planning to leave this camp with <em>Claudette</em>, but now... I don't care what happens to me."),
		}),
	},
	conditions = {
		PlaceObj('CheckIsPersistentUnitDead', {
			per_ses_id = "NPC_Claudette",
		}),
	},
	disabledInConflict = true,
	group = "Banters_Local_RefugeeCamp",
	id = "SavingClaudette_Antoine_04",
})

PlaceObj('BanterDef', {
	Comment = "Claudette dead",
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "civ_Antoine",
			'Text', T(555624827533, --[[BanterDef SavingClaudette_Antoine_05 Text section:Banters_Local_RefugeeCamp/SavingClaudette_Antoine_05 Claudette dead voice:civ_Antoine]] "I know you were there and tried to save my sister... At least that counts for something."),
		}),
	},
	conditions = {
		PlaceObj('CheckIsPersistentUnitDead', {
			per_ses_id = "NPC_Claudette",
		}),
		PlaceObj('QuestIsVariableBool', {
			QuestId = "RefugeeBlues",
			Vars = set({
	ClaudetteSaved = false,
}),
			__eval = function ()
				local quest = gv_Quests['RefugeeBlues'] or QuestGetState('RefugeeBlues')
				return not quest.ClaudetteSaved
			end,
		}),
		PlaceObj('QuestIsVariableBool', {
			Condition = "or",
			QuestId = "RefugeeBlues",
			Vars = set( "ClaudetteTimerStart", "TCE_RaidersClaudetteInitial" ),
			__eval = function ()
				local quest = gv_Quests['RefugeeBlues'] or QuestGetState('RefugeeBlues')
				return quest.ClaudetteTimerStart or quest.TCE_RaidersClaudetteInitial
			end,
		}),
	},
	disabledInConflict = true,
	group = "Banters_Local_RefugeeCamp",
	id = "SavingClaudette_Antoine_05",
})

PlaceObj('BanterDef', {
	Comment = "Claudette saved",
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "civ_Antoine",
			'Text', T(827168167365, --[[BanterDef SavingClaudette_Antoine_06_approach Text section:Banters_Local_RefugeeCamp/SavingClaudette_Antoine_06_approach Claudette saved voice:civ_Antoine]] "Thank you for saving my sister! When I heard she actually fought the marauders with a knife, my heart sank... But luckily you were there to tip the scales in her favor."),
		}),
		PlaceObj('BanterLine', {
			'MultipleTexts', true,
			'Text', "",
			'AnyOfThese', {
				PlaceObj('BanterLineThin', {
					'Character', "Nails",
					'Text', T(713195407567, --[[BanterDef SavingClaudette_Antoine_06_approach Text section:Banters_Local_RefugeeCamp/SavingClaudette_Antoine_06_approach voice:Nails]] "Yeah, your sister has bigger balls than you, that's for sure."),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "Smiley",
					'Text', T(498164120778, --[[BanterDef SavingClaudette_Antoine_06_approach Text section:Banters_Local_RefugeeCamp/SavingClaudette_Antoine_06_approach voice:Smiley]] "Your sister is one brave chica! You should have seen the way she moved!"),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "Flay",
					'Text', T(643745078727, --[[BanterDef SavingClaudette_Antoine_06_approach Text section:Banters_Local_RefugeeCamp/SavingClaudette_Antoine_06_approach voice:Flay]] "Next time, we will make you tip your own scales... useless buckhead."),
				}),
			},
			'Optional', true,
			'playOnce', true,
		}),
		PlaceObj('BanterLine', {
			'Character', "civ_Claudette",
			'Text', T(738205289083, --[[BanterDef SavingClaudette_Antoine_06_approach Text section:Banters_Local_RefugeeCamp/SavingClaudette_Antoine_06_approach Claudette saved voice:civ_Claudette]] "Thank you once again. I had no chance without you!"),
		}),
		PlaceObj('BanterLine', {
			'MultipleTexts', true,
			'Text', "",
			'AnyOfThese', {
				PlaceObj('BanterLineThin', {
					'Character', "Ivan",
					'Text', T(263542383391, --[[BanterDef SavingClaudette_Antoine_06_approach Text section:Banters_Local_RefugeeCamp/SavingClaudette_Antoine_06_approach voice:Ivan]] "You are the real hero, девочка. Браво!"),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "Meltdown",
					'Text', T(219543321085, --[[BanterDef SavingClaudette_Antoine_06_approach Text section:Banters_Local_RefugeeCamp/SavingClaudette_Antoine_06_approach voice:Meltdown]] "You keep that knife. The next asshole who tries to grab you is gonna lose a finger... and maybe some other pieces. "),
				}),
				PlaceObj('BanterLineThin', {
					'Character', "Blood",
					'Text', T(565215345557, --[[BanterDef SavingClaudette_Antoine_06_approach Text section:Banters_Local_RefugeeCamp/SavingClaudette_Antoine_06_approach voice:Blood]] "Keep practicing with your knife. That way, you can protect yourself... and your brother."),
				}),
			},
			'Optional', true,
		}),
		PlaceObj('BanterLine', {
			'Character', "civ_Antoine",
			'Text', T(874401420109, --[[BanterDef SavingClaudette_Antoine_06_approach Text section:Banters_Local_RefugeeCamp/SavingClaudette_Antoine_06_approach Claudette saved voice:civ_Antoine]] "Now that we are together, we can leave this hell hole and start a new life somewhere."),
		}),
		PlaceObj('BanterLine', {
			'Character', "civ_Claudette",
			'Text', T(114795568288, --[[BanterDef SavingClaudette_Antoine_06_approach Text section:Banters_Local_RefugeeCamp/SavingClaudette_Antoine_06_approach Claudette saved voice:civ_Claudette]] "Yes! I've been thinking I could join the Militia. I hope we'll see each other again! Farewell."),
		}),
	},
	conditions = {
		PlaceObj('QuestIsVariableBool', {
			QuestId = "RefugeeBlues",
			Vars = set({
	AntoineAndClaudetteLeft = false,
	ClaudetteSaved = true,
}),
			__eval = function ()
				local quest = gv_Quests['RefugeeBlues'] or QuestGetState('RefugeeBlues')
				return not quest.AntoineAndClaudetteLeft and quest.ClaudetteSaved
			end,
		}),
		PlaceObj('CheckIsPersistentUnitDead', {
			Negate = true,
			per_ses_id = "NPC_Claudette",
		}),
	},
	disabledInConflict = true,
	group = "Banters_Local_RefugeeCamp",
	id = "SavingClaudette_Antoine_06_approach",
})

