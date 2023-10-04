-- ========== GENERATED BY PopupNotification Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('PopupNotification', {
	Image = "UI/Messages/game_over",
	Text = T(792668407867, --[[PopupNotification GameOverNoMoney Text]] "You have no active merc contracts. All of your mercs are either dead or they returned home after fulfilling their contracts.\n\nTo continue the campaign in Grand Chien you should hire some mercs, but since you are also low on funds, please consider restarting the game or loading an older savegame."),
	Title = T(160503649429, --[[PopupNotification GameOverNoMoney Title]] "No mercs, low on funds"),
	group = "Default",
	id = "GameOverNoMoney",
})

PlaceObj('PopupNotification', {
	Image = "UI/Messages/game_over",
	Text = T(654244966778, --[[PopupNotification GameOverTemp Text]] "You have no active merc contracts. To continue the campaign in Grand Chien you should hire some mercs from the <em>A.I.M. webpage</em> that can be accessed through your browser in the <em>Command</em> menu."),
	Title = T(213300568668, --[[PopupNotification GameOverTemp Title]] "Hire More Mercs"),
	group = "Default",
	id = "GameOverTemp",
})

PlaceObj('PopupNotification', {
	Image = "UI/Messages/game_over",
	Text = T(605309951676, --[[PopupNotification IncapacitatedNoMercs Text]] "Your squad has been defeated and you have no active merc contracts! To continue the campaign in Grand Chien you should hire some mercs from the <em>A.I.M. webpage</em> that can be accessed through your browser in the <em>Command</em> menu."),
	Title = T(724775872680, --[[PopupNotification IncapacitatedNoMercs Title]] "Hire More Mercs"),
	group = "Default",
	id = "IncapacitatedNoMercs",
})

PlaceObj('PopupNotification', {
	Image = "UI/Messages/game_over",
	Text = T(407476221377, --[[PopupNotification IncapacitatedWithMercs Text]] "Your squad has been defeated! You can continue the campaign in Grand Chien with your other mercs or hire some new mercs from the <em>A.I.M. webpage</em> that can be accessed through your browser in the <em>Command</em> menu."),
	Title = T(314524718374, --[[PopupNotification IncapacitatedWithMercs Title]] "Hire More Mercs"),
	group = "Default",
	id = "IncapacitatedWithMercs",
})

PlaceObj('PopupNotification', {
	Image = "UI/Messages/militia_trained",
	Text = T(440775286479, --[[PopupNotification MilitiaTrained Text]] "Militia training in sector <sector_ID> - <sector_name> finished.\n\nMercs: <mercs>"),
	Title = T(537659500834, --[[PopupNotification MilitiaTrained Title]] "Militia Trained Successfully"),
	group = "Default",
	id = "MilitiaTrained",
})

PlaceObj('PopupNotification', {
	Image = "UI/Messages/scouting_outcome",
	Text = T(881752945849, --[[PopupNotification EnemyScuffle Text]] "<base_activity_info>\nOur scouts had a scuffle with an enemy patrol. Every scout received Wounds in the battle."),
	Title = T(289863187874, --[[PopupNotification EnemyScuffle Title]] "Enemy Scuffle"),
	group = "Outcome",
	id = "EnemyScuffle",
})

PlaceObj('PopupNotification', {
	Image = "UI/Messages/scouting_outcome",
	Text = T(984235947439, --[[PopupNotification FoundMeds Text]] "<base_activity_info>\nThe scouts found some Meds.\n"),
	Title = T(245889505999, --[[PopupNotification FoundMeds Title]] "FoundMeds"),
	group = "Outcome",
	id = "FoundMeds",
})

PlaceObj('PopupNotification', {
	Image = "UI/Messages/scouting_outcome",
	Text = T(840989164760, --[[PopupNotification FoundSupplies Text]] "<base_activity_info>\nGained some supplies from the enemy."),
	Title = T(483316368319, --[[PopupNotification FoundSupplies Title]] "Found Supplies"),
	group = "Outcome",
	id = "FoundSupplies",
})

PlaceObj('PopupNotification', {
	Image = "UI/Messages/scouting_outcome",
	Text = T(287082920974, --[[PopupNotification GatherIntelBase Text]] "<base_activity_info>"),
	Title = T(338246116646, --[[PopupNotification GatherIntelBase Title]] "Gather Intel Complete"),
	group = "Outcome",
	id = "GatherIntelBase",
})

PlaceObj('PopupNotification', {
	Image = "UI/Messages/scouting_outcome",
	Text = T(300082102483, --[[PopupNotification Tired Text]] "<base_activity_info>\nThe mission was unexpectedly hard and all Mercs are now Tired."),
	Title = T(172203007150, --[[PopupNotification Tired Title]] "Tired"),
	group = "Outcome",
	id = "Tired",
})

PlaceObj('PopupNotification', {
	Image = "UI/Messages/scouting_outcome",
	Text = T(178863161675, --[[PopupNotification WildAnimals Text]] "<base_activity_info>\nA Merc was severely mauled by wild animals."),
	Title = T(559246009177, --[[PopupNotification WildAnimals Title]] "Wild Animals"),
	group = "Outcome",
	id = "WildAnimals",
})

PlaceObj('PopupNotification', {
	Image = "UI/Messages/erny_fortress",
	OnceOnly = true,
	Text = T(690565146768, --[[PopupNotification H04_TheFortressFirst Text]] "You may find this encounter <em>too difficult</em>.\n\nPlease consider retreating until you find ways to reduce the enemy strength.\nCompleting certain quests and clearing of nearby sectors may weaken the defenses of the Fort."),
	Title = T(457117086004, --[[PopupNotification H04_TheFortressFirst Title]] "Storm The Fort"),
	group = "Sectors",
	id = "H04_TheFortressFirst",
})

PlaceObj('PopupNotification', {
	Image = "UI/Messages/erny_fortress",
	OnceOnly = true,
	Text = T(272789523478, --[[PopupNotification H04_TheFortressFirst_2 Text]] "You may find this encounter <em>challenging</em>, but you have already managed to reduce the enemy strength at the Fort.\n\nRetreating to complete certain quests or to clear nearby sectors may be advisable before you decide to face the Legion in their base."),
	Title = T(844897769099, --[[PopupNotification H04_TheFortressFirst_2 Title]] "Storm The Fort"),
	group = "Sectors",
	id = "H04_TheFortressFirst_2",
})

PlaceObj('PopupNotification', {
	Image = "UI/Messages/Tutorials/tutorial_combat",
	Text = T(749640556980, --[[PopupNotification AttackModifiers Text]] "Every attack attempt is affected by a number of positive and negative modifiers that affect the chance to hit the target. For firearms some of the most important factors are the Marksmanship stat of the shooter, the number of aim actions taken for the shot, the range to the target, the size of the targeted body part and the weapon firing mode.\n\nYou can see an exhaustive list of the modifiers before confirming the attack as well as which modifiers increase or decrease the chance to hit. "),
	Title = T(294406464175, --[[PopupNotification AttackModifiers Title]] "Attack Modifiers"),
	group = "StartingHelp",
	id = "AttackModifiers",
})

PlaceObj('PopupNotification', {
	Image = "UI/Messages/Tutorials/tutorial_combat",
	OnceOnly = true,
	Text = T(968372991006, --[[PopupNotification CombatHeal Text]] "When one of your mercs is hit you can use a First Aid Kit to <em>bandage</em> and recover lost HP. This action may keep you occupied for <em>one or more combat turns</em> depending on <em>Medical</em> skill. Having a wounded merc bandage themselves is usually less effective than having a teammate do it.\n\nSerious wounds will also lower the maximum HP of the wounded merc. Long-term treatment by a doctor can speed up the recovery."),
	Title = T(443169167729, --[[PopupNotification CombatHeal Title]] "Bandage"),
	group = "StartingHelp",
	id = "CombatHeal",
})

PlaceObj('PopupNotification', {
	Image = "UI/Messages/Tutorials/tutorial_combat",
	Text = T(101796987874, --[[PopupNotification FirstCombat Text]] "Combat is turn-based. Your entire team takes a turn, followed by the enemy team. Your characters are allowed to act in any order, but each merc is limited in what they can do on their turn by the number of <em>Action Points (AP)</em> they possess.\n\nEach action consumes a number of Action Points. Action Points will refresh on the next combat turn.\n\nThe amount of Action Points for each merc depends on their stats, morale, experience level and current status effects."),
	Title = T(506467582027, --[[PopupNotification FirstCombat Title]] "Combat and Action Points"),
	group = "StartingHelp",
	id = "FirstCombat",
})

PlaceObj('PopupNotification', {
	GamepadText = T(183802323794, --[[PopupNotification GoToSatelliteView GamepadText]] "When you are done exploring the map, you can quickly travel to another location by using the Sat View by pressing <ShortcutName('actionToggleSatellite')>. Alternatively, you can explore the map to find an exit zone."),
	Image = "UI/Messages/Tutorials/tutorial_satview",
	Text = T(683693192440, --[[PopupNotification GoToSatelliteView Text]] "When you are done exploring the map, you can quickly travel to another location by using the Sat View, accessible from the <em>Command</em> menu located on the bottom left of the HUD. Alternatively, you can explore the map to find an exit zone."),
	Title = T(133627577045, --[[PopupNotification GoToSatelliteView Title]] "Sat View"),
	group = "StartingHelp",
	id = "GoToSatelliteView",
})

PlaceObj('PopupNotification', {
	GamepadText = T(174120512701, --[[PopupNotification IntelTutorial GamepadText]] "You can acquire <em>Intel</em> for the sectors you explore. Intel may reveal enemy positions, loot caches or advantageous terrain features. You can inspect the information in the overview camera or during deployment mode.\n\nWhen you have acquired <em>Intel</em> for a sector press <ShortcutName('actionCamOverview')> to activate Overview camera and examine the information from the Intel."),
	Image = "UI/Messages/scouting_outcome",
	OnceOnly = true,
	Text = T(881934699559, --[[PopupNotification IntelTutorial Text]] "You can acquire <em>Intel</em> for the sectors you explore. Intel may reveal enemy positions, loot caches or advantageous terrain features. You can inspect the information in the overview camera or during deployment mode.\n\nWhen you have acquired <em>Intel</em> for a sector press the <em><ShortcutName('actionCamOverview')></em> key to activate Overview camera and examine the information from the Intel."),
	Title = T(273400164344, --[[PopupNotification IntelTutorial Title]] "Intel"),
	group = "StartingHelp",
	id = "IntelTutorial",
})

PlaceObj('PopupNotification', {
	Image = "UI/Messages/Tutorials/tutorial_combat",
	Text = T(295984798064, --[[PopupNotification MercStats Text]] "Stats represent the physical attributes and trained skills of each character. Each stat is shown as a number between 0 and 100.\n\n<image UI/Icons/st_health 1070> <em>Health</em> - Represents both the physical well-being of a merc and the amount of damage they can take before becoming downed.\n\n<image UI/Icons/st_agility 1070> <em>Agility</em> - Measures how well a merc reacts physically to a new situation. Affects the total amount of AP, free movement at start of turn, and how stealthy the merc is.\n\n<image UI/Icons/st_dexterity 1070> <em>Dexterity</em> - Measures a merc's ability to perform delicate or precise movements correctly. Affects bonus from aiming and Stealth Kill chance.\n\n<image UI/Icons/st_strength 1070> <em>Strength</em> - Represents muscle and brawn. It's particularly important in Melee combat, affects throwing range and the size of the personal inventory of the character.\n\n<image UI/Icons/st_wisdom 1070> <em>Wisdom</em> - Affects a merc's ability to learn from experience and training. Affects wilderness survival and the chance to notice hidden items and enemies.\n\n<image UI/Icons/st_leadership 1070> <em>Leadership</em> - Measures charm, respect and presence. Affects the rate for training militia and other mercs. Affects the chance for getting positive and negative Morale events.\n\n<image UI/Icons/st_marksmanship 1070> <em>Marksmanship</em> - Reflects a merc's ability to shoot accurately at any given target with a firearm.\n\n<image UI/Icons/st_mechanical 1070> <em>Mechanical</em> - Rates a merc's ability to repair damaged, worn-out or broken items and equipment. Important for lockpicking, machine handling and hacking electronic devices. Used for detecting and disarming non-explosive traps.\n\n<image UI/Icons/st_explosives 1070> <em>Explosives</em> - Determines a merc's ability to use grenades and other explosives and affects damage and mishap chance when using thrown items. Used for detecting and disarming explosive traps.\n\n<image UI/Icons/st_medical 1070> <em>Medical</em> - Represents a merc's medical knowledge and ability to heal the wounded."),
	Title = T(711333421189, --[[PopupNotification MercStats Title]] "Merc Stats"),
	group = "StartingHelp",
	id = "MercStats",
})

PlaceObj('PopupNotification', {
	Image = "UI/Messages/Tutorials/tutorial_combat_2",
	Text = T(848286344110, --[[PopupNotification Morale Text]] "The icon at the top left of the HUD <image UI/Hud/morale_high.tga 2000> indicates the current Team Morale level for your team. Each merc has an individual Morale value, based on Team Morale and various personal factors.\n\nMorale <em>modifies AP</em> and can trigger various positive and negative effects based on the <em>highest Leadership</em> stat among the mercs. Killing enemies sometimes boosts Team Morale, while taking heavy damage or suffering casualties lowers it."),
	Title = T(735552564733, --[[PopupNotification Morale Title]] "Morale"),
	group = "StartingHelp",
	id = "Morale",
})

PlaceObj('PopupNotification', {
	Image = "UI/Messages/Tutorials/tutorial_satview",
	Text = T(817910715011, --[[PopupNotification SatTimeAndTravel Text]] "You can open the Sat View at any time. From this screen you can analyze the strategic situation in Grand Chien, issue travel orders, manage squads, and conduct special operations.\n\nTime in the Sat View is currently <em>paused</em>. Giving a travel order will <em>unpause the time flow</em> and your merc squad will start traveling towards their destination. You can also unpause the time for other reasons but be aware that your merc contracts are of limited duration and will expire eventually."),
	Title = T(506550734355, --[[PopupNotification SatTimeAndTravel Title]] "Sat View: Time and Travel"),
	group = "StartingHelp",
	id = "SatTimeAndTravel",
})

PlaceObj('PopupNotification', {
	Image = "UI/Messages/Tutorials/tutorial_satview",
	Text = T(652104799515, --[[PopupNotification SatelliteOperations Text]] "Mercs in the Sat View can be assigned to perform different Operations that take time and might require additional resources in the Sector. Only a single operation can be active in any Sector.\n\n<image UI/SectorOperations/T_Icon_Activity_Healing_Doctor 1070> <em>Hospital Treatment</em> - Pay for medical treatment in the local hospital. High Loyalty in this sector decreases the cost of this Operation. Only available in certain Sectors.\n\n<image UI/SectorOperations/T_Icon_Activity_TrainingMilitia 1070> <em>Militia Training</em> - Whip the civilian population into shape, turning them into a local Militia able to defend against hostile troops. Picking a Trainer with high Leadership and a high Loyalty of the local population both contribute to faster training. Only available in certain Sectors.\n\n<image UI/SectorOperations/T_Icon_Activity_R_R 1070> <em>R&R</em> - Spend some time for active rest and entertainment. HP are restored faster, Wounds naturally heal faster, and all exhaustion effects are removed. Only available in certain Sectors.\n\n<image UI/SectorOperations/T_Icon_Activity_Repair 1070> <em>Repair Items</em> - Use mechanical Parts to repair damaged equipment. Assigning mercs with high Mechanical stat increases the repair speed.\n\n<image UI/SectorOperations/T_Icon_Activity_Scouting 1070> <em>Scout Area</em> - Scout the area within two sectors range and contact the locals to gather Intel about nearby sectors. Assigning mercs with high Wisdom increases the speed of the Operation.\n\n<image UI/SectorOperations/T_Icon_Activity_TrainingMercs_Student 1070> <em>Train Mercs</em> - Assign a Trainer to improve the stats of the other mercs. The trainer must have a higher stat than the trained mercs.\n\n<image UI/SectorOperations/T_Icon_Activity_Healing 1070> <em>Treat Wounds</em> - Mercs with high Medical skill can treat the wounds of other mercs and themselves at the cost of Meds.\n\n<image UI/SectorOperations/T_Icon_Activity_Craft_Ammo 1070> <em>Craft Ammo</em> - Use mechanical Parts and other components to craft different types of ammo. High Explosives stat will increase crafting speed. Only available in certain Sectors.\n\n<image UI/SectorOperations/T_Icon_Activity_Craft_Explosives 1070> <em>Craft Explosives</em> - Use mechanical Parts and other components to craft different types of explosives. High Explosives stat will increase crafting speed. Only available in certain Sectors.\n\nMercs not assigned to any Operations will automatically Rest and recover from Tired and Exhausted status effects."),
	Title = T(738545116063, --[[PopupNotification SatelliteOperations Title]] "Sat View: Operations"),
	group = "StartingHelp",
	id = "SatelliteOperations",
})

PlaceObj('PopupNotification', {
	GamepadText = T(988835057660, --[[PopupNotification SatteliteWounded GamepadText]] "Sometimes your merc will become <em>wounded</em> in battle. Wounds will heal naturally as time passes in the Sat View, however this process is very slow. For faster healing you can use the <em>Treat Wounds</em> Operation.\n\nTo start any Operation, select a sector and press <ShortcutName('idOperations')>. Choose Treat Wounds and assign at least one <em>doctor</em> and up to 3 <em>patients</em> per doctor.\n\nYou will need to spend <em>Meds</em> to treat the wounds of your mercs. Meds can be found as loot while exploring or after battle."),
	Image = "UI/Messages/Tutorials/tutorial_satview",
	OnceOnly = true,
	Text = T(339378095991, --[[PopupNotification SatteliteWounded Text]] "Sometimes your merc will become <em>wounded</em> in battle. Wounds will heal naturally as time passes in the Sat View, however this process is very slow. For faster healing you can use the <em>Treat Wounds</em> Operation.\n\nTo start any Operation, select a sector and click the <em>Operation</em> button in the sector info panel. Choose Treat Wounds and assign at least one <em>doctor</em> and up to 3 <em>patients</em> per doctor.\n\nYou will need to spend <em>Meds</em> to treat the wounds of your mercs. Meds can be found as loot while exploring or after battle."),
	Title = T(233799961543, --[[PopupNotification SatteliteWounded Title]] "Sat View: Healing Wounds"),
	group = "StartingHelp",
	id = "SatteliteWounded",
})

PlaceObj('PopupNotification', {
	GamepadText = T(255057134902, --[[PopupNotification SelectionAndMovement GamepadText]] "Select any of your mercs with <ShortcutName('GamepadPrevUnit')> or <ShortcutName('GamepadNextUnit')>. You can use <ShortcutName('ExplorationSelectionToggle')> to select all your mercs or just a single one.\n\nOrder the currently selected mercs to move by pressing <GamepadShortcutName('ButtonA')> on the desired destination.\n\nInteraction with items and talking to NPC characters are initiated with <GamepadShortcutName('ButtonA')>."),
	Image = "UI/Messages/Tutorials/tutorial_general_2",
	Text = T(236073339960, --[[PopupNotification SelectionAndMovement Text]] "Select any of your mercs with <em>left-click</em> or use <em>drag selection</em> to select a group.\n\nOrder the currently selected mercs to move by <em>right-clicking</em> on the desired destination.\n\nInteraction with items and talking to NPC characters are initiated with <em>left-click</em>.\n\nPlease note that some of these default controls can be changed from the Options menu."),
	Title = T(532384069417, --[[PopupNotification SelectionAndMovement Title]] "Basic Controls"),
	group = "StartingHelp",
	id = "SelectionAndMovement",
})

PlaceObj('PopupNotification', {
	Image = "UI/Messages/Tutorials/tutorial_combat",
	OnceOnly = true,
	Text = T(150220168049, --[[PopupNotification Stealth Text]] "Mercs might start sneaking before the enemies take notice of them. Sneaking mercs are harder to detect and can attempt to deliver devastating Stealth Kills. Mercs with high Agility and Dexterity scores are particularly adept at stealth. Sneaking requires a crouched or prone stance.\n\nKeep an eye on the <em>heat bar below the mercs</em> to see how close the nearby enemies are to detecting them. Approaching the enemy from <em>behind</em>, from <em>tall grass</em> or from a <em>dark area</em> will buy you some more time, however enemies will detect you eventually.\n\nKeep in mind that even excellent stealth skills can only take you so far - an attack with a noisy weapon is bound to attract unwanted attention."),
	Title = T(136715343775, --[[PopupNotification Stealth Title]] "Sneaking and stealth"),
	group = "StartingHelp",
	id = "Stealth",
})

PlaceObj('PopupNotification', {
	Image = "UI/Messages/Tutorials/tutorial_combat",
	Text = T(803592916892, --[[PopupNotification WeatherEffects Text]] "Environmental effects, like darkness and weather can affect combat in various ways:\n\n<image UI/Hud/Weather/Night 1070>/<image UI/Hud/Weather/Underground 1070> <em>Night / Underground</em> - Enemies in darkness are harder to notice. Ranged attacks against them suffer a low visibility penalty, except at point blank range.\n\n<image UI/Hud/Weather/DustStorm 1070> <em>Dust Storm</em> - Movement costs are increased. Cover is more effective. Enemies become concealed at certain distance. Ranged attacks against concealed foes may become grazing hits.\n\n<image UI/Hud/Weather/FireStorm 1070> <em>Fire Storm</em> - Visual range is reduced. Characters may lose Energy and eventually collapse when standing close to a fire in combat.\n\n<image UI/Hud/Weather/Fog 1070> <em>Fog</em> - Visual range is reduced and enemies become concealed at certain distance. Ranged attacks against concealed foes may become grazing hits.\n\n<image UI/Hud/Weather/Heat 1070> <em>Heat</em> - When receiving Wounds characters may lose Energy and eventually collapse.\n\n<image UI/Hud/Weather/HeavyRainOrThunderstorm 1070> <em>Heavy Rain</em> - Aiming costs are increased. Hearing is impaired. Weapons lose condition and jam more often. Throwable items tend to mishap.\n\n<image UI/Hud/Weather/LightRain 1070> <em>Rain</em> - Hearing is impaired. Weapons lose condition and jam more often."),
	Title = T(901547101176, --[[PopupNotification WeatherEffects Title]] "Environmental and Weather Effects"),
	group = "StartingHelp",
	id = "WeatherEffects",
})

PlaceObj('PopupNotification', {
	GamepadText = T(591199783398, --[[PopupNotification Aiming GamepadText]] "Aiming can improve the accuracy of your attacks at the cost of spending additional Action Points. It can be very useful when the enemies are far away or behind cover.\n\nUse <ShortcutName('actionAttackAimGamepadReverse')>/<ShortcutName('actionAttackAim')> to cycle between different aim levels before executing an attack."),
	Image = "UI/Messages/Tutorials/tutorial_combat_2",
	Text = T(906069343771, --[[PopupNotification Aiming Text]] "Aiming can improve the accuracy of your attacks at the cost of spending additional Action Points. It can be very useful when the enemies are far away or behind cover.\n\n<em>Right-click</em> to cycle between different aim levels before executing an attack."),
	Title = T(257864012366, --[[PopupNotification Aiming Title]] "Aiming"),
	group = "Tutorial",
	id = "Aiming",
})

PlaceObj('PopupNotification', {
	GamepadText = T(406662672964, --[[PopupNotification BoatTravel GamepadText]] "Now you can travel across water sectors in the region.\n\nWhenever you pick a location which can be reached only by boat, a <em>naval route</em> will be shown on the map, starting from the nearest <em>port</em> in a sector you <em>control</em>. You need to pay a <em>fee</em> for each water sector you travel across. The <em>village of Ernie</em> is a port sector.\n\nSquads will combine water and land travel as necessary, optimizing travel time. "),
	Image = "UI/Messages/Tutorials/tutorial_satview",
	OnceOnly = true,
	Text = T(108784614198, --[[PopupNotification BoatTravel Text]] "Now you can travel across water sectors in the region.\n\nWhenever you pick a location which can be reached only by boat, a <em>naval route</em> will be shown on the map, starting from the nearest <em>port</em> in a sector you <em>control</em>. You need to pay a <em>fee</em> for each water sector you travel across. The <em>village of Ernie</em> is a port sector.\n\nSquads will combine water and land travel as necessary, optimizing travel time. If you want them to take a specific path, use <em>shift-click</em> to set way points."),
	Title = T(802759807976, --[[PopupNotification BoatTravel Title]] "Sat View: Boat Travel"),
	group = "Tutorial",
	id = "BoatTravel",
})

PlaceObj('PopupNotification', {
	GamepadText = T(549653228856, --[[PopupNotification DeploymentTutorial GamepadText]] "You can freely <em>Deploy</em> your mercs within the deployment areas. Examine the map, check for <em>Intel</em> and choose your approach for the upcoming conflict.\n\nPosition all mercs and press <ShortcutName('DeploymentStartExploration')> to proceed."),
	Image = "UI/Messages/Tutorials/tutorial_deployment",
	OnceOnly = true,
	Text = T(952294642312, --[[PopupNotification DeploymentTutorial Text]] "You can freely <em>Deploy</em> your mercs within the deployment areas. Examine the map, check for <em>Intel</em> and choose your approach for the upcoming conflict.\n\nPosition all mercs and press <em>Deploy</em> to proceed."),
	Title = T(529631848899, --[[PopupNotification DeploymentTutorial Title]] "Deployment"),
	group = "Tutorial",
	id = "DeploymentTutorial",
})

PlaceObj('PopupNotification', {
	Image = "UI/Messages/Tutorials/tutorial_downed",
	Text = T(464534937385, --[[PopupNotification DownedTutorial Text]] "One of your mercs has been Downed! Luckily they didn't die this time, but they have to be <em>bandaged</em> by an ally soon. Downed characters can die if they take significant damage while Downed.\n\nBandaging effects depend on Medical skill and will <em>keep the ally occupied</em> for a while.\n\nDon't rely on the Downed state to protect you from death! Mercs can die without becoming Downed if they take massive damage."),
	Title = T(912608989394, --[[PopupNotification DownedTutorial Title]] "Downed State"),
	group = "Tutorial",
	id = "DownedTutorial",
})

PlaceObj('PopupNotification', {
	Image = "UI/Messages/Tutorials/tutorial_overwatch",
	Text = T(578204170002, --[[PopupNotification EnemyOverwatchTutorial Text]] "An enemy just used <em>Overwatch</em>, focusing their attention on an area of the battlefield. The symbol <image UI/Hud/attack_of_opportunity 1400> warns you that your movement or other actions will be interrupted by an enemy opportunity attack.\n\nCertain special attacks can <em>cancel</em> enemy Overwatch."),
	Title = T(613076507304, --[[PopupNotification EnemyOverwatchTutorial Title]] "Overwatch"),
	group = "Tutorial",
	id = "EnemyOverwatchTutorial",
})

PlaceObj('PopupNotification', {
	Image = "UI/Messages/Tutorials/tutorial_pindown",
	Text = T(963378110046, --[[PopupNotification EnemyPinDownTutorial Text]] "An enemy just used <em>Pin Down</em>, focusing their attention on one of your characters. That character will take extra damage from enemy attacks and will suffer an attack at the enemy's next turn. The attack can be prevented if they get out of the enemy's line of fire or the enemy Pin Down is somehow canceled, for example by killing the enemy.\n\nCertain special attacks can <em>cancel</em> enemy Pin Down."),
	Title = T(436399399003, --[[PopupNotification EnemyPinDownTutorial Title]] "Pin Down"),
	group = "Tutorial",
	id = "EnemyPinDownTutorial",
})

PlaceObj('PopupNotification', {
	Comment = "text needs to be written instead of placeholder",
	Image = "UI/Messages/Tutorials/tutorial_repair",
	Text = T(829533366876, --[[PopupNotification JammingandCondition Text]] "A weapon has <em>Jammed</em> because of its bad condition. The merc needs to spend an action to Unjam it, however depending on their <em>Mechanical</em> skill the condition of the weapon may deteriorate further.\n\nOutside of combat you can use the <em>Repair Items</em> operation in the Sat View to improve the condition of your weapons."),
	Title = T(390724077322, --[[PopupNotification JammingandCondition Title]] "Jamming and Condition"),
	group = "Tutorial",
	id = "JammingandCondition",
})

PlaceObj('PopupNotification', {
	GamepadText = T(839768881141, --[[PopupNotification LevelUp GamepadText]] "Some of your mercs accumulated enough experience to level up! Higher-level mercs perform better and can select different perks that give them new capabilities during battle.\n\nTo level up a merc select them and open the <em>Merc Info</em> with <ShortcutName('actionOpenCharacter')>."),
	Image = "UI/Messages/Tutorials/tutorial_general_2",
	Text = T(511223543169, --[[PopupNotification LevelUp Text]] "Some of your mercs accumulated enough experience to level up! Levelled up mercs perform better and can select different perks that give them new options during battle.\n\nTo level up a merc <em>press the button on the character's portrait</em>."),
	Title = T(695458016273, --[[PopupNotification LevelUp Title]] "Level Up"),
	group = "Tutorial",
	id = "LevelUp",
})

PlaceObj('PopupNotification', {
	Image = "UI/Messages/Tutorials/tutorial_line_of_fire",
	Text = T(217824429715, --[[PopupNotification LineOfFire Text]] "The lines displayed when selecting a movement destination indicate line of fire to nearby enemies.\n\nIf there is no line, you will be unable to attack this enemy from the chosen destination. Keep in mind that more powerful firearms and special ammo pierce some obstacles."),
	Title = T(934242202781, --[[PopupNotification LineOfFire Title]] "Line of Fire"),
	group = "Tutorial",
	id = "LineOfFire",
})

PlaceObj('PopupNotification', {
	GamepadText = T(445673061476, --[[PopupNotification MilitiaTutorial GamepadText]] "Sometimes enemy squads will try to attack a sector you've already liberated. Your mercs may repel the attack or intercept the enemy squad while they are on their way.\n\nTrained <em>Militia</em> will defend the village from attacks even when your mercs are not there.\n\nUse the <ShortcutName('idOperations')> button in Sat View to initiate the Train Militia Operation (you must have mercs in the village of Ernie sector). Mercs with high Leadership are most suitable for this task."),
	Image = "UI/Messages/militia_trained",
	OnceOnly = true,
	Text = T(203227587021, --[[PopupNotification MilitiaTutorial Text]] "Sometimes enemy squads will try to attack a sector you've already liberated. Your mercs may repel the attack or intercept the enemy squad while they are on their way.\n\nTrained <em>Militia</em> will defend the village from attacks even when your mercs are not there.\n\nUse the <em>Operation</em> button in Sat View to initiate the Train Militia Operation (you must have mercs in the village of Ernie sector). Mercs with high Leadership are most suitable for this task."),
	Title = T(686924329279, --[[PopupNotification MilitiaTutorial Title]] "Guard Posts & Militia"),
	group = "Tutorial",
	id = "MilitiaTutorial",
})

PlaceObj('PopupNotification', {
	Image = "UI/Messages/Tutorials/tutorial_general_2",
	Text = T(811642757048, --[[PopupNotification MineIncome Text]] "Congratulations, you've just liberated a diamond mine! The Legion is bound to try to capture it again, so <em>training militia</em> to defend it should be a top priority.\n\nMines provide steady income, based on the <em>Loyalty</em> of the nearest settlement. Winning battles against the Legion in this area and helping the locals in other ways will increase their Loyalty and bring even higher profits to you."),
	Title = T(912211682684, --[[PopupNotification MineIncome Title]] "Mine Income"),
	group = "Tutorial",
	id = "MineIncome",
})

PlaceObj('PopupNotification', {
	Image = "UI/Messages/Tutorials/tutorial_combat",
	OnceOnly = true,
	Text = T(875641511650, --[[PopupNotification Overwhelmed Text]] "The enemies have significant numerical advantage in this battle. While A.I.M. mercs are famous for often pulling off the seemingly impossible, remember that a tactical <em>retreat</em> is a viable option in such situations.\n\nA retreat can be ordered from an <em>exit area</em> on the edge of the map. If you retreat all your mercs from a conflict you will lose some Loyalty with nearby settlements, but this is a small price to pay for living to fight another day."),
	Title = T(605307528698, --[[PopupNotification Overwhelmed Title]] "Overwhelmed"),
	group = "Tutorial",
	id = "Overwhelmed",
})

PlaceObj('PopupNotification', {
	Image = "UI/Messages/Tutorials/tutorial_general_2",
	Text = T(309233632926, --[[PopupNotification PerksMenu Text]] "Mercs will gain a new <em>perk</em> each time they level up. High <em>stats</em> such as Health or Strength will determine which perks are available to each character.\n\nBetter perks will become available as you invest in perks associated with a particular <em>Stat</em>."),
	Title = T(236845784408, --[[PopupNotification PerksMenu Title]] "Perks"),
	group = "Tutorial",
	id = "PerksMenu",
})

PlaceObj('PopupNotification', {
	Image = "UI/Messages/Tutorials/tutorial_satview",
	Text = T(188800632985, --[[PopupNotification SatMoneyAndContracts Text]] "The <em>contract</em> of one or more of your mercs is <em>expiring</em> soon. You can negotiate a contract extension from the <em>A.I.M. database page</em>, accessible through the Command Menu. You don't need to do so right away, you will have another opportunity when the contract expires.\n\nYou need to secure funds to pay your mercs. The <em>diamond mines</em> in Grand Chien are an excellent source of income, especially when there is high Loyalty in the surrounding settlements."),
	Title = T(141160300528, --[[PopupNotification SatMoneyAndContracts Title]] "Sat View: Money and Contracts"),
	group = "Tutorial",
	id = "SatMoneyAndContracts",
})

PlaceObj('PopupNotification', {
	Image = "UI/Messages/Tutorials/tutorial_resting",
	Text = T(402101147852, --[[PopupNotification SatViewRestingHint Text]] "Some of your mercs are <em>tired</em> and need to rest. Tired mercs will have less AP in combat and will eventually become <em>exhausted</em> if they continue to exert themselves.\n\nIdle mercs rest automatically as time passes in the Sat View so the easiest way to initiate a rest is to <em>stop traveling and wait</em> until your tired and exhausted mercs recover.\n\nIf you are in a friendly city and have some funds to spare, you can initiate an <em>R&R operation</em> for some active rest and entertainment - your mercs will perform even better in battle afterwards."),
	Title = T(151057851122, --[[PopupNotification SatViewRestingHint Title]] "Sat View: Resting"),
	group = "Tutorial",
	id = "SatViewRestingHint",
})

PlaceObj('PopupNotification', {
	Image = "UI/Messages/Tutorials/tutorial_general",
	OnceOnly = true,
	Text = T(869705558541, --[[PopupNotification StartingTeam Text]] "Welcome to the web page for the Association of International Mercenaries, or <em>A.I.M.</em> for short.\n\nHere you can browse and hire different mercs. Pick your starting team. It's recommended that you hire at least three mercs for this operation but do keep a watch on your funds.\n\nYou will be able to hire additional mercs as your mission progresses, as long as you can secure the funding for them."),
	Title = T(936638701977, --[[PopupNotification StartingTeam Title]] "The Starting Team"),
	group = "Tutorial",
	id = "StartingTeam",
})

PlaceObj('PopupNotification', {
	Image = "UI/Messages/Tutorials/tutorial_repair",
	Text = T(666684327644, --[[PopupNotification WeaponMods Text]] "Weapons can be customized and tailored to your taste with various mods. Weapon mods always require parts that can be obtained by salvaging useless equipment. Advanced mods often require certain rare components like microchips and optical lenses.\n\nWeapon mods are always installed by the merc with the highest Mechanic stat. Failure to create the mod may damage the weapon, lowering its condition, while a critical success will refund some of the used resources.\n\nThe number of slots and possible upgrades will greatly vary per weapon."),
	Title = T(565891862658, --[[PopupNotification WeaponMods Title]] "Weapon Mods"),
	group = "Tutorial",
	id = "WeaponMods",
})

