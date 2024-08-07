MapTypesCombo = { "game", "system",  "satellite" }

--- Returns the current campaign preset.
---
--- If a campaign is currently active, this will return the corresponding `CampaignPresets` entry.
--- Otherwise, it will return the `CampaignPresets` entry for the `DefaultCampaign`.
---
--- @return table The current campaign preset
function GetCurrentCampaignPreset()
	if Game and Game.Campaign then return CampaignPresets[Game.Campaign] end
	return CampaignPresets[DefaultCampaign]
end

--- Loads the initial map for the given campaign.
---
--- If a campaign is provided, this function will check if the initial sector for that campaign has a different map than the current one, and if so, it will change the map to the one specified in the initial sector.
---
--- If no campaign is provided, the function will use the current campaign preset to determine the initial map.
---
--- @param campaign table The campaign preset to use. If not provided, the current campaign preset will be used.
function LoadCampaignInitialMap(campaign)
	campaign = campaign or GetCurrentCampaignPreset()
	local sector = table.find_value(campaign.Sectors, "Id", campaign.InitialSector)
	if sector and sector.Map and sector.Map ~= GetMapName() then
		ChangeMap(sector.Map)
	end
end

--- Creates a list of satellite sectors for the current campaign.
---
--- This function creates a list of `SatelliteSector` objects based on the sector dimensions
--- specified in the current campaign preset. The sectors are assigned unique IDs using the
--- `sector_pack` function.
---
--- @return table The list of created satellite sectors
function CreateSatelliteSectors()
	local campaign = GetCurrentCampaignPreset()
	if not campaign then
		assert(false, "Current map does not correspond to any campaign")
		return
	end
	local sectors = {}
	for col = campaign.sector_rowsstart, campaign.sector_columns do
		for row = 1, campaign.sector_rows do
			local sector = PlaceObject("SatelliteSector")
			sector:SetId(sector_pack(row, col))
			sectors[#sectors + 1] = sector
		end
	end
	return sectors
end

--- Returns a list of satellite sectors for the current campaign.
---
--- If the `bCreate` parameter is true and the campaign does not have any sectors defined, this function will create a new list of `SatelliteSector` objects based on the sector dimensions specified in the current campaign preset.
---
--- @param bCreate boolean If true, create new satellite sectors if the campaign has none defined.
--- @param campaign_preset table The campaign preset to use. If not provided, the current campaign preset will be used.
--- @return table The list of satellite sectors for the current campaign.
function GetSatelliteSectors(bCreate, campaign_preset)
	local campaign = campaign_preset or GetCurrentCampaignPreset()
	if not campaign then
		assert(false, "Current map does not correspond to any campaign")
		return
	end
	local sectors = campaign.Sectors or {}
	if not next(sectors) and bCreate then
		sectors = CreateSatelliteSectors() or {}
		table.sort(sectors, function(a, b) return a.Id < b.Id end)
	end
	campaign.Sectors = sectors
	return sectors
end

--- Returns a list of campaign sectors that match the provided filter function.
---
--- If the `default` parameter is provided, it will be included in the returned list.
---
--- @param default string The default value to include in the list.
--- @param filter function A function that takes a `SatelliteSector` object and returns a boolean indicating whether it should be included in the list.
--- @return table A list of `{value = id, text = name}` tables representing the campaign sectors.
function GetCampaignSectorsCombo(default, filter)
	local campaign = GetCurrentCampaignPreset()
	if not campaign then
		assert(false, "Current map does not correspond to any campaign")
		return
	end
	
	local items = default and {{ value = default, text = default}} or {}
	for _, sector in ipairs(campaign.Sectors or empty_table) do
		if not filter or filter(sector) then
			local id = sector.Id
			items[#items + 1] = {value = id, text = sector.name}
		end
	end
	
	return items
end

--- Returns a list of campaign sectors that have a Guardpost.
---
--- If the `default` parameter is provided, it will be included in the returned list.
---
--- @param default string The default value to include in the list.
--- @return table A list of `{value = id, text = name}` tables representing the campaign sectors with a Guardpost.
function GetGuardpostCampaignSectorsCombo(default)
	return GetCampaignSectorsCombo(default, function(s) return s.Guardpost end)
end

---
--- Returns the number of enabled operations in the current satellite sector.
---
--- @param context table The context object, which may contain information about the current satellite sector.
--- @return string A formatted string representing the number of enabled operations.
---
TFormat.ActionName_ActivitiesCount = function(context)
	if context then return T(520902754959, "Operations") end -- Hack to not get dynamic text portion in the options menu

	local squad, sector_id = GetSatelliteContextMenuValidSquad()
	local operationsInSector = GetOperationsInSector(sector_id)
	local available = table.count(operationsInSector, "enabled", true)
	return T{989240901383, "Operations[<count>]",count = available}	
end

---
--- Returns a formatted string representing the list of enabled operations in the current satellite sector.
---
--- @param context table The context object, which may contain information about the current satellite sector.
--- @return string A formatted string representing the list of enabled operations.
---
TFormat.ActionName_OperationsList = function(context)
	local operationsInSector = GetOperationsInSector(context.Id)
	local names = {}
	for _, operation in ipairs(operationsInSector) do
		if operation.enabled then
			names[#names+1] = operation.operation.display_name
		end
	end
	if #names>0 then
		table.insert(names, 1, Untranslated("\n"))
	end
	return table.concat(names, "\n")
end

---
--- Returns the global satellite UI object.
---
--- @return table The global satellite UI object.
---
function GetSatelliteViewInterface()
	return g_SatelliteUI
end

local openiningSatView
---
--- Opens the satellite view.
---
--- @param campaign table The campaign object.
--- @param context table The context object, which may contain information about the current satellite sector.
--- @param loading_screen boolean Whether to show a loading screen.
--- @param wait boolean Whether to wait for the satellite view to open.
---
function OpenSatelliteView(campaign, context, loading_screen, wait)
	if g_FirstNetStart then return end
	if openiningSatView then return end
	--print("----------------OpenSatelliteView", GetStack())
	openiningSatView = true
	if netInGame and not netGameInfo.started then
		_OpenSatelliteView(campaign, context, loading_screen)
	elseif GetMap() == "" or not mapdata.GameLogic then
		--if not on map, we can't sync anything..
		if not netInGame or NetIsHost() then
			NetEchoEvent("OpenSatelliteViewAsync", campaign, context, loading_screen)
		end
	else
		FireNetSyncEventOnHost("OpenSatelliteView", campaign, context, loading_screen)
	end
	if wait then
		WaitMsg("OpenSatelliteView", 1000)
	end
end

---
--- Asynchronously opens the satellite view.
---
--- @param ... any Arguments to pass to the _OpenSatelliteView function.
---
function NetEvents.OpenSatelliteViewAsync(...)
	CreateGameTimeThread(_OpenSatelliteView, ...)
end

---
--- Asynchronously opens the satellite view.
---
--- @param ... any Arguments to pass to the _OpenSatelliteView function.
---
function NetSyncEvents.OpenSatelliteView(...)
	CreateGameTimeThread(_OpenSatelliteView, ...)
end

---
--- Synchronizes the opening of the PDA satellite dialog on the host.
---
--- @param context table The context object, which may contain information about the current satellite sector.
---
function NetSyncEvents.OpenPDASatellite(context)
	CreateGameTimeThread(function()
		local dlg = GetDialog("PDADialogSatellite")
		if not dlg then
			OpenDialog("PDADialogSatellite", GetInGameInterface(), context)
		end
	end)
end

if FirstLoad then
	g_OpenSatelliteViewThread = false
end

---
--- Asynchronously opens the satellite view.
---
--- @param campaign table The campaign object, which may contain information about the current satellite sector.
--- @param context table The context object, which may contain information about the current satellite sector.
--- @param loading_screen boolean Whether to show a loading screen while opening the satellite view.
---
function _OpenSatelliteView(campaign, context, loading_screen)
	--this part is sync cuz coming from sync ev
	if g_Combat then
		if g_Combat:ShouldEndCombat() then
			g_Combat:EndCombatCheck()
			while g_Combat do
				WaitMsg("CombatEnd", 20)
			end
		end
	end

	-- Cancel any aiming mode etc.
	CreateRealTimeThread(RestoreDefaultModeSimple)
	
	if not CanYield() or IsRealTimeThread() then
		CreateGameTimeThread(SkipNonBlockingSetpieces)
	else
		SkipNonBlockingSetpieces() --waking up setpieces' threads from rtt is async;
	end
	assert(not IsValidThread(g_OpenSatelliteViewThread))
	g_OpenSatelliteViewThread = CreateRealTimeThread(function()
		--still probably sync
		sprocall(function()
			if not HasGameSession() then
				NewGameSession()
			end
			Msg("PreOpenSatelliteView")

			if context then CloseSatelliteView(true) end
			local load_map = GetMap() == "" or not mapdata.GameLogic
			loading_screen = loading_screen or load_map
			if loading_screen then
				LoadingScreenOpen("idSatelliteView", "satellite") --this is not sync
			end
			if load_map then
				--this happens when launching new game or when loading a game where player has not entered a sector yet
				LoadCampaignInitialMap(campaign) --dunno if this is sync or not
				if not AnyPlayerSquads() then
					local campaign = campaign or CampaignPresets[Game.Campaign]
					campaign:FirstRunInterface()
				end
			end
			ShowInGameInterface(true)
			
			FireNetSyncEventOnHost("OpenPDASatellite", context) --since there is non sync code up to here, only way to guarantee this is through ev
			
			while HasGameSession() and (not gv_SatelliteView or not GetDialog("PDADialogSatellite")) do --sometimes, when game loads super slowly, this is already true
				--gv_SatelliteView is sometimes bogus because it is a game var and it could be persisted true without the ui being up
				WaitMsg("InitSatelliteView", 2000)
			end
			
			local dlg = GetDialog("PDADialog")
			if dlg then
				dlg:SetVisible(true)
			end
		end)
		if loading_screen then
			LoadingScreenClose("idSatelliteView", "satellite")
		end
		openiningSatView = nil
		g_OpenSatelliteViewThread = false
	end)
end

---
--- Closes the satellite view.
---
--- @param force boolean If true, the satellite view is closed immediately without any cleanup.
---
function CloseSatelliteView(force)
	if not gv_SatelliteView then return end
	FireNetSyncEventOnHost("CloseSatelliteView", force)
end

---
--- Closes the satellite view.
---
--- @param force boolean If true, the satellite view is closed immediately without any cleanup.
---
function NetSyncEvents.CloseSatelliteView(force)
	local pda = GetDialog("PDADialogSatellite")
	if not pda then return end
	pda:Close(force)
end

---
--- Determines if the satellite view can be closed.
---
--- @return boolean true if the satellite view can be closed, false otherwise
---
function CanCloseSatelliteView()
	local squads = GetSectorSquadsFromSide(gv_CurrentSectorId, "player1")
	if #squads > 0 then
		local anyNonTravelling = false
		for i, squad in ipairs(squads) do
			local travelling = IsSquadTravelling(squad) and not gv_Sectors[squad.CurrentSector].conflict
			if not travelling then
				anyNonTravelling = true
			end
		end
		if not anyNonTravelling then squads = false end
	else
		squads = false
	end

	return gv_SatelliteView and squads and not ForceReloadSectorMap
end

GameVar("gv_SatelliteOpenTime", 0)
GameVar("gv_SatelliteOpenWeather", false)

function OnMsg.StartSatelliteGameplay()
	gv_SatelliteOpenTime = Game.CampaignTime
	gv_SatelliteOpenWeather = GetCurrentSectorWeather() or false
end

function OnMsg.SatelliteTick()
	if ForceReloadSectorMap then
		return
	end
	if (Game.CampaignTime - gv_SatelliteOpenTime >= const.Satellite.ReloadMapAfterSatelliteTime) or -- a lot of time passed in satellite
		(gv_SatelliteOpenWeather ~= GetCurrentSectorWeather()) or -- weather changed
		(CalculateTimeOfDay(Game.CampaignTime) ~= CalculateTimeOfDay(gv_SatelliteOpenTime)) -- time of day changed
	then
		ForceReloadSectorMap = true
	end
end

if FirstLoad then
	g_SatelliteThread = false
	PrevSectorOnMouse = false
	g_Cabinet = false
	g_CitySectors = false
	time_thread_waiting_resume = false
end
total_pause_delta = 0
function OnMsg.CampaignSpeedChanged()
	if IsValidThread(g_SatelliteThread) and time_thread_waiting_resume then
		Wakeup(g_SatelliteThread)
		time_thread_waiting_resume = false
	end
end

local div = 1000
local ticks_batch = 5 --reduce number of msgs getting pumped over the net;
dbgCampaignFactor = false
---
--- The `SatelliteTimeThread` function is responsible for managing the campaign time advancement in the satellite view of the game. It runs in a separate thread and is responsible for:
---
--- - Checking if the campaign is paused or if the game is entering a new sector, and only running if those conditions are false.
--- - Calculating the time delta since the last update and advancing the campaign time accordingly.
--- - Synchronizing the campaign time advancement with other clients in a multiplayer game.
--- - Handling campaign time factor changes and adjusting the time advancement accordingly.
--- - Sleeping for the appropriate amount of time to maintain the desired campaign time advancement rate.
---
--- This function is called when the "StartSatelliteGameplay" message is received, and it runs continuously until the game is paused or the player leaves the satellite view.
---

function OnMsg.StartSatelliteGameplay()
	DeleteThread(g_SatelliteThread)
	if netInGame and not NetIsHost() then return end
	g_SatelliteThread = CreateMapRealTimeThread(SatelliteTimeThread)
end

local ticks_in_day = 24 * 60 * const.Scale.min / const.Satellite.SectorsTick
local function lFireCampaignTimeSyncMessages(time, old_time)
	local tick = time / const.Satellite.Tick
	local sectors_tick = time / const.Satellite.SectorsTick
	if tick ~= old_time / const.Satellite.Tick then
		Msg("SatelliteTick", tick)
		local list = GetUnitDataList()
		ListCallReactions(list, "OnSatelliteTick")
		if time % const.Scale.h <= 0 then
			ListCallReactions(list, "OnNewHour")
		end
		if time % const.Scale.day < const.Scale.min then
			ListCallReactions(list, "OnNewDay")
		end		
	end
	if sectors_tick ~= old_time / const.Satellite.SectorsTick then
		Msg("SectorsTick", sectors_tick % ticks_in_day, ticks_in_day)
	end
	if time % const.Scale.h <= 0 then
		Msg("NewHour")
	end
	if time % const.Scale.day < const.Scale.min then
		Msg("NewDay")
	end
end

--[[function OnMsg.NewHour()
	local hash = NetGetHashValue()
	NetUpdateHash("NetHashSatelliteUpdate", hash, GetCampHumanTime())
	NetResetHashValue()
end
]]
---
--- Returns the current campaign time in human-readable format.
---
--- @return number, string Campaign time in hours and minutes
---
function GetCampHumanTime()
	return (Game.CampaignTime % const.Scale.day) / const.Scale.h, ":",
		(Game.CampaignTime % const.Scale.day) % const.Scale.h / const.Scale.min
end

if FirstLoad then
	g_TimeAdvanceThread = false
end

---
--- Advances the campaign time in the satellite view.
---
--- This function is called when the satellite campaign time needs to be advanced. It creates a new thread that will advance the campaign time in small increments, waiting for other threads to complete before each increment. This ensures that the campaign time is advanced in a synchronized manner.
---
--- @param time number The new campaign time to advance to.
--- @param old_time number The previous campaign time.
--- @param step number The time step to advance by.
---
function NetSyncEvents.SatelliteCampaignTimeAdvance(time, old_time, step)
	if IsCampaignPaused() then
		return
	end
	DeleteThread(g_TimeAdvanceThread)
	g_TimeAdvanceThread = CreateMapRealTimeThread(function()
		local lastGameTime = GameTime()
	
		WaitAllOtherThreads()
		
		assert(Game)
		if not Game then return end
		
		while Game.CampaignTime < time and not IsCampaignPaused() do
			local ot = Game.CampaignTime
			Game.CampaignTime = Game.CampaignTime + const.Scale.min
			SetUILCustomTime(Game.CampaignTime)
			Game.DailyIncome = GetDailyIncome()
			lFireCampaignTimeSyncMessages(Game.CampaignTime, ot)
			ObjModified(Game)
			Msg("CampaignTimeAdvanced", Game.CampaignTime, ot)
			WaitAllOtherThreads() --wait for threads woken up by this thread to exec
			
			-- Detection for a bug
			local gameTimeNow = GameTime()
			if lastGameTime ~= gameTimeNow then
				assert(not "Game time is running in the satellite view :O")
			end
			lastGameTime = gameTimeNow
		end
		g_TimeAdvanceThread = false
	end)
end

function OnMsg.OpenSatelliteView()
	SetUILCustomTime(Game.CampaignTime)
end

---
--- Calculates the amount per tick for a given total amount and number of ticks.
---
--- @param amount number The total amount to be distributed over the ticks.
--- @param tick number The current tick index (0-based).
--- @param ticks number The total number of ticks.
--- @return number The amount for the current tick.
---
function GetAmountPerTick(amount, tick, ticks)
	return amount * (tick + 1) / ticks - amount * tick / ticks
end

-- mines

---
--- Enables or disables the mine for the specified sector.
---
--- @param sector_id number The ID of the sector to enable/disable the mine for.
--- @param enabled boolean True to enable the mine, false to disable it.
---
function MineEnable(sector_id, enabled)
	gv_Sectors[sector_id].mine_enabled = enabled
end

---
--- Calculates the depletion time for the specified sector.
---
--- @param sector table The sector for which to calculate the depletion time.
--- @return number The depletion time for the specified sector.
---
function GetSectorDepletionTime(sector)
	local baseVal = sector.DepletionTime
	local percentAccum = 100
	for i, m in ipairs(sector.depletion_mods) do
		percentAccum = percentAccum + (m - 100)
	end
	return MulDivRound(baseVal, percentAccum, 100)
end

---
--- Calculates the daily income for the specified sector.
---
--- @param sector table The sector for which to calculate the daily income.
--- @return number The daily income for the specified sector.
---
function GetSectorDailyIncome(sector)
	local baseVal = sector.DailyIncome
	local baseValDiffPerc = PercentModifyByDifficulty(GameDifficulties[Game.game_difficulty]:ResolveValue("sectorDailyIncomeBonus"))
	baseVal = MulDivRound(baseVal, baseValDiffPerc, 100)
	
	local percentAccum = 100
	for i, m in ipairs(sector.income_mods) do
		percentAccum = percentAccum + (m - 100)
	end
	return MulDivRound(baseVal, percentAccum, 100)
end

---
--- Returns the percentage of income that a depleted mine will generate.
---
--- @return number The percentage of income that a depleted mine will generate.
---
function TFormat.MinePercentAtDepleted()
	local difficultyPreset = GameDifficulties[GetGameDifficulty()]
	local difficultyPercent = difficultyPreset and difficultyPreset:ResolveValue("DepletedMineIncomePerc")
	return difficultyPercent or 0
end

--- Returns the income generated by the mine in the specified sector.
---
--- @param sector_id number The ID of the sector to get the mine income for.
--- @param showEvenIfUnowned boolean If true, the function will return the mine income even if the sector is not owned by the player.
--- @return number|nil The mine income for the specified sector, or nil if the sector has no mine or the mine is disabled.
function GetMineIncome(sector_id, showEvenIfUnowned)
	local sector = gv_Sectors[sector_id]

	-- No income for this sector
	if not sector.Mine or not sector.mine_enabled then
		return
	end
	
	local city_loyalty = GetCityLoyalty(sector.City) or 100
	if sector.Side ~= "player1" then
		if showEvenIfUnowned then
			city_loyalty = 50
		else
			return
		end
	end
	
	local sectorDepletionTime = GetSectorDepletionTime(sector)
	local perc = 100
	if sector.Depletion and sector.mine_work_days and sector.mine_work_days > sectorDepletionTime then
		local daysSinceStartedDepleting = sector.mine_work_days - sectorDepletionTime
		perc = Lerp(100, 0, daysSinceStartedDepleting, const.Satellite.MineDepletingDays)
		perc = Max(0, perc)
	end
	
	local difficultyPreset = GameDifficulties[GetGameDifficulty()]
	local difficultyPercent = difficultyPreset and difficultyPreset:ResolveValue("DepletedMineIncomePerc")
	local incomeAtDepletion = difficultyPercent or 0
	perc = Max(perc, incomeAtDepletion)
	
	if perc == 0 then
		return
	end
	
	local income = GetSectorDailyIncome(sector)
	income = perc * income / 100
	return income * (50 + city_loyalty / 2 ) / 100
end

--- Returns the number of days left until the mine in the specified sector starts depleting, and a boolean indicating whether the mine has already started depleting.
---
--- @param sector table The sector to get the mine depletion days left for.
--- @return number, boolean The number of days left until the mine starts depleting, and a boolean indicating whether the mine has already started depleting.
function GetMineDepletionDaysLeft(sector)
	if not sector.Mine then return end

	local daysMineWorked = sector.mine_work_days or 0
	local daysStartDepleting = GetSectorDepletionTime(sector)
	local depletionDays = const.Satellite.MineDepletingDays
	return (daysStartDepleting + depletionDays) - daysMineWorked, daysMineWorked > daysStartDepleting
end

--- Returns the number of days left until the mine in the specified sector starts depleting.
---
--- @param sector table The sector to get the mine depletion days left for.
--- @return number The number of days left until the mine starts depleting.
function GetDaysLeftUntilDepletionStarts(sector)
	if not sector.Mine then return end

	local daysMineWorked = sector.mine_work_days or 0
	local daysStartDepleting = GetSectorDepletionTime(sector)
	return daysStartDepleting - daysMineWorked
end

function OnMsg.SectorsTick(tick, ticks_per_day)
	for id, sector in sorted_pairs(gv_Sectors) do
		local income = GetMineIncome(id)
		if income then
			income = GetAmountPerTick(income, tick, ticks_per_day)
			AddMoney(income, "income", "noCombatLog")
			if tick + 1 == ticks_per_day then
				sector.mine_work_days = (sector.mine_work_days or 0) + 1
				
				local sectorDepletionTime = GetSectorDepletionTime(sector)
				if not sector.mine_depleted and sector.Depletion and sector.mine_work_days >= sectorDepletionTime + const.Satellite.MineDepletingDays then
					sector.mine_depleted = true
					CombatLog("important", T{268514931670, "<SectorName(sector)> is depleted.", sector = sector})
					if g_SatelliteUI then g_SatelliteUI:UpdateSectorVisuals(id) end
				end
			end
		end
		
		-- If an enemy had a waiting conflict for this sector that it needs to stop waiting due
		-- to the squad dying or whatever else
		local conflict = sector and sector.conflict
		if conflict and conflict.waiting and not conflict.player_attacking and not EnemyWantsToWait(id) then
			EnterConflict(sector)
		end
		
		ExecuteSectorEvents("SE_OnTick", id)
	end
end

-- loyalty
---
--- Modifies the loyalty of a city by the specified amount.
---
--- @param city_id number The ID of the city to modify the loyalty for.
--- @param add number The amount to add or subtract from the city's loyalty. Positive values increase loyalty, negative values decrease it.
--- @param msg_reason string (optional) A reason message to include in the combat log.
--- @return string "gain" if loyalty was increased, "loss" if loyalty was decreased.
---
function CityModifyLoyalty(city_id, add, msg_reason)
	local city = gv_Cities[city_id]
	if not city or add == 0 then return end
	city.Loyalty = Clamp(city.Loyalty + add, 0, 100)
	Msg("LoyaltyChanged", city_id, add)
	local msg = false
	if add > 0 then
		msg = T{562269812751, "Gained <em><num> Loyalty</em> with <em><city></em> ", city = city.DisplayName, num = add}
	else
		msg = T{837740133104, "Lost <em><num> Loyalty</em> with <em><city></em> ", city = city.DisplayName, num = abs(add)}
	end
	if msg_reason and msg_reason~="" then 
		CombatLog("important", T{833235545397, "<msg>(<reason>)", msg = msg, reason =  msg_reason} )
	else
		CombatLog("short", msg)
	end
	
	ObjModified(city)
	return add > 0 and "gain" or "loss"
end

---
--- Synchronizes a city's loyalty change over the network.
---
--- @param city_id number The ID of the city to modify the loyalty for.
--- @param add number The amount to add or subtract from the city's loyalty. Positive values increase loyalty, negative values decrease it.
--- @param msg_reason string (optional) A reason message to include in the combat log.
---
function NetSyncEvents.CheatCityModifyLoyalty(city_id, add, msg_reason)	
	CityModifyLoyalty(city_id, add, msg_reason)
end

---
--- Returns the loyalty of the specified city.
---
--- @param city_id number The ID of the city to get the loyalty for.
--- @return number The loyalty value of the city, between 0 and 100.
---
function GetCityLoyalty(city_id)
	local city = gv_Cities and gv_Cities[city_id]
	if not city then return 100 end
	return city.Loyalty
end

---
--- Returns the loyalty of the specified city.
---
--- @param context_obj any The context object for the function call.
--- @param city_id number The ID of the city to get the loyalty for.
--- @return number The loyalty value of the city, between 0 and 100.
---
TFormat.GetCityLoyalty = function(context_obj, city_id)
	return GetCityLoyalty(city_id)
end

-- Returns the number of cities controlled by the player.
-- if countSectors is true sectors containing cities are counted instead.
---
--- Returns the number of cities controlled by the player.
---
--- @param countSectors boolean If true, sectors containing cities are counted instead.
--- @return number The number of cities controlled by the player.
---
function GetPlayerCityCount(countSectors)
	local cityCount = 0
	
	if countSectors then
		for cityName, sectorCount in pairs(gv_PlayerCityCounts and gv_PlayerCityCounts.cities) do
			cityCount = cityCount + sectorCount
		end
	else
		cityCount = gv_PlayerCityCounts and gv_PlayerCityCounts.count or 0
	end
	
	return cityCount
end

--militia
---
--- Returns the number of militia units in the specified sector.
---
--- @param sector_id number The ID of the sector to get the militia count for.
--- @return number The number of militia units in the specified sector.
---
function GetSectorMilitiaCount(sector_id)
	local squad_id = gv_Sectors[sector_id] and gv_Sectors[sector_id].militia_squad_id
	return squad_id and gv_Squads[squad_id] and #(gv_Squads[squad_id].units or "") or 0
end

---
--- Creates a new militia unit data object and adds it to the specified militia squad.
---
--- @param class string The class of the militia unit to create.
--- @param sector table The sector where the militia unit will be created.
--- @param militia_squad table The militia squad to add the new unit to.
---
function CreateMilitiaUnitData(class, sector, militia_squad)
	local session_id = GenerateUniqueUnitDataId("Militia", sector.Id, class)
	local unit_data = CreateUnitData(class, session_id, InteractionRand(nil, "Satellite"))
	unit_data.militia = true
	unit_data.Squad = militia_squad.UniqueId
	militia_squad.units = militia_squad.units or {}
	table.insert(militia_squad.units, session_id)
end

---
--- Deletes a militia unit data object and removes it from the specified militia squad.
---
--- @param id string The unique ID of the militia unit data to delete.
--- @param militia_squad table The militia squad to remove the unit from.
---
function DeleteMilitiaUnitData(id, militia_squad)
	gv_UnitData[id] = nil
	if g_Units[id] then
		DoneObject(g_Units[id])
		g_Units[id] = nil
	end
	table.remove_entry(militia_squad.units, id)
end

MilitiaUpgradePath = {
	"MilitiaRookie",
	"MilitiaVeteran",
	"MilitiaElite",
}

MilitiaIcons = {
	false,
	"UI/PDA/MercPortrait/T_ClassIcon_Veteran_Small",
	"UI/PDA/MercPortrait/T_ClassIcon_Elite_Small",
}

---
--- Returns the militia unit with the least experience from the specified list of units.
---
--- @param units table A table of militia unit IDs.
--- @return table|false The militia unit data with the least experience, or false if no units were found.
---
function GetLeastExpMilitia(units)
	local leastExperienced = false
	local leastExperiencedIdx = false
	for _, u in ipairs(units) do
		local ud = gv_UnitData[u]
		local class = ud.class
		local idx = table.find(MilitiaUpgradePath, class)
		if not leastExperiencedIdx or idx < leastExperiencedIdx then
			leastExperienced = ud
			leastExperiencedIdx = idx
		end
	end
	return leastExperienced
end

---
--- Spawns a militia squad with the specified number of units in the given sector.
---
--- @param trainAmount integer The number of militia units to train.
--- @param sector table The sector in which to spawn the militia squad.
--- @param bFromOperation boolean Whether the militia training is being done as part of an operation.
--- @return table, integer The militia squad and the number of militia units trained.
---
function SpawnMilitia(trainAmount, sector, bFromOperation)
	assert(MilitiaUpgradePath and #MilitiaUpgradePath > 0)

	local militia_squad_id = sector.militia_squad_id or
		CreateNewSatelliteSquad({
			Side = "ally",
			CurrentSector = sector.Id,
			militia = true,
			Name = T(121560205347, "MILITIA")
		})
	sector.militia_squad_id = militia_squad_id
	
	local militia_squad = gv_Squads[militia_squad_id]

	local count = {MilitiaRookie = 0,MilitiaVeteran = 0}
	for i,unit_id in ipairs(militia_squad and militia_squad.units) do
		local class = gv_UnitData[unit_id].class
		if class == "MilitiaRookie" then count.MilitiaRookie = count.MilitiaRookie + 1 end
		if class == "MilitiaVeteran" then count.MilitiaVeteran = count.MilitiaVeteran + 1 end
	end
	local count_trained = 0
	for i = 1, trainAmount do
		local squadUnits = militia_squad.units or empty_table
		local leastExpMember = GetLeastExpMilitia(militia_squad.units)
	
		if #squadUnits < sector.MaxMilitia then
			CreateMilitiaUnitData(MilitiaUpgradePath[1], sector, militia_squad)
			count_trained = count_trained + 1
		elseif leastExpMember then -- level up
			if bFromOperation and count.MilitiaRookie<=0 then
				break
			end

			local leastExperiencedTemplate = bFromOperation and "MilitiaRookie" or leastExpMember.class
			local leastExpIdx = table.find(MilitiaUpgradePath, leastExperiencedTemplate)
			if not leastExpIdx then leastExpIdx = 0 end
			leastExpIdx = leastExpIdx + 1
			local upgradedClass = MilitiaUpgradePath[leastExpIdx]
			
			-- Cannot be upgraded further
			if leastExpIdx > #MilitiaUpgradePath or not upgradedClass then
				break
			end

			DeleteMilitiaUnitData(leastExpMember.session_id, militia_squad)
			CreateMilitiaUnitData(upgradedClass, sector, militia_squad)
			count_trained = count_trained + 1
			count.MilitiaRookie =  count.MilitiaRookie - 1
			count.MilitiaVeteran =  count.MilitiaVeteran + 1
		end
	end
	
	return militia_squad, count_trained
end

if FirstLoad then
	g_MilitiaTrainingCompleteCounter = 0
	g_MilitiaTrainingCompletePopups = {}
end

function OnMsg.EnterSector()
	g_MilitiaTrainingCompleteCounter = 0
	assert(not next(g_MilitiaTrainingCompletePopups))
end

---
--- Completes the current militia training operation in the specified sector.
---
--- @param sector table The sector where the militia training is taking place.
--- @param mercs table The mercenaries participating in the militia training.
---
function CompleteCurrentMilitiaTraining(sector, mercs)
	NetUpdateHash("CompleteCurrentMilitiaTraining")
	local eventId = g_MilitiaTrainingCompleteCounter
	g_MilitiaTrainingCompleteCounter = g_MilitiaTrainingCompleteCounter + 1
	local start_time = Game.CampaignTime
	CreateMapRealTimeThread(function()
		local militia_squad, count_trained = SpawnMilitia(const.Satellite.MilitiaUnitsPerTraining, sector, "operation")
		sector.militia_training = false
		
		local militia_types ={MilitiaRookie = 0, MilitiaElite=0, MilitiaVeteran=0}
		for _, unit_id in ipairs(militia_squad.units) do
			local unit = gv_UnitData[unit_id]
			militia_types[unit.class] = militia_types[unit.class] + 1
		end
		
		local popupHost = GetDialog("PDADialogSatellite")
		popupHost = popupHost and popupHost:ResolveId("idDisplayPopupHost")
		
		if militia_types.MilitiaVeteran >= (sector.MaxMilitia - militia_types.MilitiaElite) then
			--max trainig reached 
			local dlg = CreateMessageBox(
				popupHost,
				T(295710973806, "Militia Training"),
				T{522643975325, "Militia training is finished - trained <militia_trained> defenders.<newline><GameColorD>(<sectorName>)</GameColorD>",
					sectorName = GetSectorName(sector),
					militia_trained = count_trained}.."\n\n"..T(306458255966, "Militia can’t be trained further. Victories in combat can advance militia soldiers to Elite levels.")				
				)
				dlg:Wait()
		else
			-- train one more time
			local cost, costTexts, names, errors = GetOperationCosts(mercs, "MilitiaTraining", "Trainer","refund")
			local buyAgainText = T(460261217340, "Do you want to train militia again?")
			local costText = table.concat(costTexts, ", ")	
			local dlg = CreateQuestionBox(
				popupHost,
				T(295710973806, "Militia Training"),
				T{522643975325, "Militia training is finished - trained <militia_trained> defenders.<newline><GameColorD>(<sectorName>)</GameColorD>",
					sectorName = GetSectorName(sector),
					militia_trained = count_trained},
				T(689884995409, "Yes"),
				T(782927325160, "No"),
				{ sector = sector, mercs = mercs, textLower = buyAgainText, costText = costText }, 
				function() return not next(errors) and (militia_types.MilitiaVeteran < (sector.MaxMilitia - militia_types.MilitiaElite)) and "enabled" or "disabled" end,
				nil,
				"ZuluChoiceDialog_MilitiaTraining")
			
			assert(g_MilitiaTrainingCompletePopups[eventId] == nil)
			g_MilitiaTrainingCompletePopups[eventId] = dlg
			NetSyncEvent("ProcessMilitiaTrainingPopupResults", dlg:Wait(), eventId, sector.Id, UnitDataToSessionIds(mercs), cost, start_time)
			g_MilitiaTrainingCompletePopups[eventId] = nil
		end
	end)
end

---
--- Converts an array of unit data objects to an array of their corresponding session IDs.
---
--- @param arr table An array of unit data objects.
--- @return table An array of session IDs corresponding to the input unit data objects.
---
function UnitDataToSessionIds(arr)
	local ret = {}
	for i, m in ipairs(arr) do
		ret[i] = m.session_id
	end
	return ret
end

---
--- Converts an array of session IDs to an array of their corresponding unit data objects.
---
--- @param arr table An array of session IDs.
--- @return table An array of unit data objects corresponding to the input session IDs.
---
function SessionIdsArrToUnitData(arr)
	local unit_data = gv_UnitData
	local ret = {}
	for i, id in ipairs(arr) do
		ret[i] = unit_data[id]
	end
	return ret
end

---
--- Processes the results of a militia training popup dialog.
---
--- @param result string The result of the popup dialog ("ok" or "cancel").
--- @param event_id number The ID of the militia training event.
--- @param sector_id number The ID of the sector where the militia training took place.
--- @param mercs table An array of session IDs for the mercenaries involved in the militia training.
--- @param cost number The cost of the militia training.
--- @param start_time number The start time of the militia training.
---
function NetSyncEvents.ProcessMilitiaTrainingPopupResults(result, event_id, sector_id, mercs, cost, start_time)
	if result == "ok" then
		local sector = gv_Sectors[sector_id]
		if sector.started_operations["MilitiaTraining"] ~= start_time then --other player already started it
			for i, session_id in ipairs(mercs) do
				NetSyncEvents.MercSetOperation(session_id, "MilitiaTraining", "Trainer", i == 1 and cost, i,  false)
			end
			NetSyncEvents.LogOperationStart("MilitiaTraining", sector.Id, "log")
			NetSyncEvents.StartOperation(sector.Id, "MilitiaTraining", start_time, sector.training_stat)
		end
	end
	if g_MilitiaTrainingCompletePopups[event_id] then
		g_MilitiaTrainingCompletePopups[event_id]:Close()
		g_MilitiaTrainingCompletePopups[event_id] = nil
	end
end

---
--- Fixes up the militia unit data in a savegame.
---
--- This function is called during savegame loading to update the class and name of militia units in the savegame data.
---
--- @param data table The savegame data.
--- @param metadata table The savegame metadata.
--- @param lua_revision number The Lua revision of the savegame.
---
function SavegameSessionDataFixups.MilitiaChangeData(data, metadata, lua_revision)
	if lua_revision<283940 then
		local l_gv_unit_data = GetGameVarFromSession(data, "gv_UnitData")
	-- units	
		for k, unit in pairs(l_gv_unit_data) do
			if unit.class == "MilitiaVeteran" then
				unit.class = "MilitiaElite"
				unit.Name = T(486398616031, "Militia Elite")
			elseif unit.class == "MilitiaRegular" then
				unit.class = "MilitiaVeteran"
				unit.Name = T(237861181220, "Militia Veteran")
			end
		end
	end
end

---
--- Fixes up the militia unit data in a savegame.
---
--- This function is called during savegame loading to update the class and name of militia units in the savegame data.
---
--- @param sector_data table The savegame data for a specific sector.
--- @param lua_revision number The Lua revision of the savegame.
---
function SavegameSectorDataFixups.MilitiaChangeData(sector_data, lua_revision)
	-- units	
	if lua_revision<283940 then
		-- load dynamic data
		local dynamic_data = sector_data.dynamic_data
		if dynamic_data and #dynamic_data > 0 then
			for _, ddata_table in ipairs(dynamic_data) do
				local ddata = ddata_table[2]
				if rawget(ddata, "class") then
					if ddata.class == "MilitiaVeteran" then
						ddata.class = "MilitiaElite"
					elseif ddata.class == "MilitiaRegular" then
						ddata.class = "MilitiaVeteran"
					end
				end
			end
		end
	end
end

-- fixup of savegames with conflict with no mercs due to changes to mercs squads available for conflict (traveling squads are filtered from UI) 
function OnMsg.ZuluGameLoaded(filename, lua_revision)
	if lua_revision and lua_revision>346296 then return end
	for id, sector_id in pairs(g_ConflictSectors) do
		local playersqs = GetSquadsInSector(sector_id, "excludeTravelling", "includeMilitia", "excludeArriving", "excludeRetreating")
		if not next(playersqs) then
			ResolveConflict(gv_Sectors[sector_id], "no voice")			
		end
	end
end


-- Prior to this version arrival squads weren't saved as such.
-- Try to guess based on their name.
---
--- Fixes up the arrival squads in a savegame.
---
--- This function is called during savegame loading to identify and mark the arrival squads in the savegame data.
---
--- @param data table The savegame data.
--- @param meta table The savegame metadata.
---
function SavegameSessionDataFixups.ArrivalSquads(data, meta)
	if meta and meta.lua_revision > 289560 then return end
	local arrivingSquadName = _InternalTranslate(T(546629671844, "ARRIVING"))
	for id, squad in pairs(data.gvars.gv_Squads) do
		if IsT(squad.Name) and _InternalTranslate(squad.Name) == arrivingSquadName then
			squad.arrival_squad = true
		end
	end
end

---
--- Fixes up the squad names in a savegame to ensure they match the translated squad name presets.
---
--- This function is called during savegame loading to ensure the squad names are properly translated and match the expected squad name presets.
---
--- @param data table The savegame data.
--- @param meta table The savegame metadata.
---
function SavegameSessionDataFixups.EnforceSquadNameTranslations(data, meta)
	local function TryToMatchSquadName(squad_name)
		local result
		ForEachPreset("SquadName", function(preset, ...)
			if preset.group == "Player_Arriving" or preset.group == "Player" then return end
			if squad_name == TDevModeGetEnglishText(preset.Name, not "deep", "no_assert") then result = preset.Name return end
		end)
		
		return result
	end

	local playerCounter = 1
	for i,v in pairs(data.gvars.gv_Squads) do
		if v.Side == "player1" or v.Side == "player2" then
			if v.arrival_squad then
				v.Name = Presets.SquadName.Default.Arriving.Name
			else
				v.Name = Presets.SquadName.Player[playerCounter].Name
				playerCounter = playerCounter + 1
			end
		elseif type(v.Name) == "string" then
			v.Name = TryToMatchSquadName(v.Name) or Presets.SquadName.Default.Squad.Name
		elseif v.militia then
			-- do nothing
		else
			assert(false, "Can't identify squad type to fix up save game.")
		end
	end
end

---
--- Fixes the `created` variable in the `g_ImpTest.final` table of the savegame data.
---
--- This function is called during savegame loading to ensure the `created` variable is properly set for the mercenary unit.
---
--- @param data table The savegame data.
--- @param meta table The savegame metadata.
---
function SavegameSessionDataFixups.FixMercCreatedVariable(data, meta)
	if not (data.gvars.g_ImpTest and data.gvars.g_ImpTest.final) then return end
	if data.gvars.g_ImpTest.final.created then return end
	
	local merc_id = data.gvars.g_ImpTest.final.merc_template.id
	for _, squad in pairs(data.gvars.gv_Squads) do
		if squad.Side == "player1" or squad.Side == "player2" then
			for _, unit_id in ipairs(squad.units) do
				if unit_id == merc_id then
					data.gvars.g_ImpTest.final.created = true 
					return 
				end
			end
		end
	end
end

---
--- Fixes the squad names for arriving squads in the savegame data.
---
--- This function is called during savegame loading to ensure the squad names for arriving squads are properly set.
---
--- @param data table The savegame data.
--- @param meta table The savegame metadata.
---
function SavegameSessionDataFixups.testoo(data, meta)
	if meta and meta.lua_revision > 302378 then return end
	local arrivingSquadName = _InternalTranslate(T(546629671844, "ARRIVING"))
	for id, squad in pairs(data.gvars.gv_Squads) do
		if IsT(squad.Name) and _InternalTranslate(squad.Name) == arrivingSquadName then
			squad.Name = arrivingSquadName
		end
	end
end

-- Assign militia banters
function OnMsg.EnterSector()
	for i, u in ipairs(g_Units) do
		if not u.militia then goto continue end
	
		local class = u.unitdatadef_id
		local banterTag = false
		if class == "MilitiaRookie" then
			banterTag = "Rookie"
		elseif class == "MilitiaElite" then
			banterTag = "Elite"
		elseif class == "MilitiaVeteran" then
			banterTag = "Veteran"
		else
			banterTag = ""
			assert(false, "Unknown militia class - " .. class)
		end
		
		local list = {}
		for i, b in ipairs(Presets.BanterDef.Banters_Militia) do
			if string.match(b.id, banterTag) then
				list[#list + 1] = b.id
			end
		end
		u.banters = list
		
		if banterTag ~= "" and #list == 0 then
			assert(false, "didn't find any militia banters for militia unit of class " .. class)
		end
		
		::continue::
	end
end

-- sides
---
--- Returns a table of the different POI (Point of Interest) types that can be tracked on the satellite view.
---
--- @return table The table of POI types.
---
function GetSectorPOITypes()
	return { "all", "Mine", "Guardpost", "Port" }
end

-- maintain counts of player-side sectors with POIs or belonging to cities, to avoid iterating when querying these numbers in quest conditions
GameVar("gv_PlayerSectorCounts", { all = 0, Mine = 0, Guardpost = 0, Port = 0 })
GameVar("gv_PlayerCityCounts", function() return { count = 0, cities = {} } end) -- cities is [city name] = <number of sectors of that city owned by the player>

---
--- Sets the side of a sector on the satellite view.
---
--- @param sector_id string The ID of the sector to set the side for.
--- @param side string The new side for the sector. Can be "player1", "player2", "neutral", or "ally".
--- @param force boolean If true, the side will be set even if the sector has a "sticky" side.
---
--- @return boolean True if the side was successfully changed, false otherwise.
---
function SatelliteSectorSetSide(sector_id, side, force)
	local sector = gv_Sectors[sector_id]
	if not force and sector.StickySide or sector.Side == side then return end
	
	local old_side = sector.Side
	sector.Side = side
	
	local sector_buildings = {}
	
	for _, poi in ipairs(POIDescriptions) do
		if sector[poi.id] then			
			sector_buildings[#sector_buildings + 1] =  poi.display_name
		end
	end
	
	local sector_building_text
	if sector_buildings and #sector_buildings > 0 then
		sector_building_text = table.concat(sector_buildings, ", ")
	end
	
	
	if side == "player1" then
		if sector.City ~= "none" then
			if sector_building_text then
				CombatLog("important", T{156954263652, "Established control over <em><SectorName(sector)> (<sector_building>)</em> in <em><SettlementName></em>", sector = sector,  SettlementName = gv_Cities[sector.City].DisplayName,sector_building = sector_building_text})
			else
				CombatLog("important", T{695564592147, "Established control over <em><SectorName(sector)></em> in <em><SettlementName></em>", sector = sector,  SettlementName = gv_Cities[sector.City].DisplayName})
			end
		else
			if sector_building_text then
				CombatLog("important", T{927281946743, "Established control over <em><SectorName(sector)> (<sector_building>)</em>", sector = sector,sector_building = sector_building_text})
			else
				CombatLog("important", T{656688610359, "Established control over <em><SectorName(sector)></em>", sector = sector})
			end
		end
		gv_LastSectorTakenByPlayer = sector_id
	elseif old_side == "player1" and side ~= "neutral" and side ~= "ally" then
		if sector.City ~= "none" then
			if sector_building_text then
				CombatLog("important", T{258379206579, "Lost control of <em><SectorName(sector)> (<sector_building>)</em> in <em><SettlementName></em>", sector = sector, SettlementName = gv_Cities[sector.City].DisplayName,sector_building = sector_building_text})
			else
				CombatLog("important", T{418999371512, "Lost control of <em><SectorName(sector)></em> in <em><SettlementName></em>", sector = sector, SettlementName = gv_Cities[sector.City].DisplayName})
			end
		else
			if sector_building_text then
				CombatLog("important", T{440720361823, "Lost control of <em><SectorName(sector)> (<sector_building>)</em>", sector = sector, sector_building = sector_building_text})
			else
				CombatLog("important", T{371968542080, "Lost control of <em><SectorName(sector)></em>", sector = sector})
			end
		end
	end
	
	ExecuteSectorEvents("SE_OnSideChange", sector_id)
	if side == "player1" or side == "player2" then
		if old_side ~= "player1" and old_side ~= "player2" then
			gv_PlayerSectorCounts.all = gv_PlayerSectorCounts.all + 1
			for _, poi in ipairs(GetSectorPOITypes()) do 
				if sector[poi] then
					gv_PlayerSectorCounts[poi] = (gv_PlayerSectorCounts[poi] or 0) + 1
				end
			end
			local sector_city = sector.City
			if sector_city and sector_city ~= "none" then
				gv_PlayerCityCounts.cities[sector_city] = (gv_PlayerCityCounts.cities[sector_city] or 0) + 1
				gv_PlayerCityCounts.count = table.count(gv_PlayerCityCounts.cities)
			end
		end
		ExecuteSectorEvents("SE_PlayerControl", sector_id)
	elseif old_side == "player1" or old_side == "player2" then
		assert(gv_PlayerSectorCounts.all)
		gv_PlayerSectorCounts.all = gv_PlayerSectorCounts.all - 1
		for _, poi in ipairs(GetSectorPOITypes()) do 
			if sector[poi] then
				assert(gv_PlayerSectorCounts[poi] and gv_PlayerSectorCounts[poi] > 0)
				gv_PlayerSectorCounts[poi] = gv_PlayerSectorCounts[poi] - 1
			end
		end
		local sector_city = sector.City
		if sector_city and sector_city ~= "none" then
			assert(gv_PlayerCityCounts.cities[sector_city] > 0)
			gv_PlayerCityCounts.cities[sector_city] = gv_PlayerCityCounts.cities[sector_city] - 1
			if gv_PlayerCityCounts.cities[sector_city] == 0 then
				gv_PlayerCityCounts.cities[sector_city] = nil
				gv_PlayerCityCounts.count = table.count(gv_PlayerCityCounts.cities)
			end
		end
	end
	
	if old_side ~= "player1" and side == "player1" then
		sector.last_own_campaign_time = Game.CampaignTime
	end
	
	ObjModified(sector)
	Msg("SectorSideChanged", sector_id, old_side, side)
	return true
end

---
--- Fixes up the player sector counts in the savegame session data.
---
--- This function is called during savegame loading to ensure the
--- `gv_PlayerSectorCounts` and `gv_PlayerCityCounts` global variables
--- are properly initialized based on the sector data in the savegame.
---
--- @param data table The savegame session data.
---
function SavegameSessionDataFixups.PlayerSectorCounts(data)
	if not data.gvars.gv_PlayerSectorCounts then
		local counts = { all = 0 }
		local city_counts = { count = 0, cities = {} }
		local pois = GetSectorPOITypes()
		for _, sector in pairs(data.gvars.gv_Sectors) do
			if sector.Side == "player1" or sector.Side == "player2" then
				counts.all = counts.all + 1
				for _, poi in ipairs(pois) do
					if sector[poi] then
						counts[poi] = (counts[poi] or 0) + 1
					end
				end
				if sector.City and sector.City ~= "none" then
					city_counts.cities[sector.City] = (city_counts.cities[sector.City] or 0) + 1
				end
			end
		end
		data.gvars.gv_PlayerSectorCounts = counts
		city_counts.count = table.count(city_counts.cities)
		data.gvars.gv_PlayerCityCounts = city_counts
	end
end

---
--- Fixes up any leftover water travel data in squad data during savegame loading.
---
--- This function is called during savegame loading to ensure that any squads
--- that were previously traveling by water but are no longer in a water sector
--- have their `water_route` flag cleared.
---
--- @param data table The savegame session data.
---
function SavegameSessionDataFixups.WaterTravelLeftover(data)
	local l_gv_squads = GetGameVarFromSession(data, "gv_Squads")
	local l_gv_sectors = GetGameVarFromSession(data, "gv_Sectors")
	for k, squad in pairs(l_gv_squads) do
		local sectorId = squad.CurrentSector
		local isWater = l_gv_sectors[sectorId]
		isWater = isWater and isWater.Passability == "Water"
		if squad.water_route and not isWater then
			squad.water_route = false
		end
	end
end

---
--- Replaces any sector references in quest employment history with their IDs.
---
--- This function is called during savegame loading to ensure that any sector
--- references in quest employment history are stored as IDs instead of tables.
--- This is necessary to ensure that the savegame can be properly loaded and
--- deserialized.
---
--- @param data table The savegame session data.
---
function SavegameSessionDataFixups.ReplaceSectorsWithIDs(data)
	local quests = GetGameVarFromSession(data, "gv_Quests")
	for merc_id, merc_data in pairs(quests.MercStateTracker) do
		if type(merc_data) == "table" then
			for _, entry in ipairs(merc_data.EmploymentHistory or empty_table) do
				if entry.context and type(entry.context.sector) == "table" then
					entry.context.sector = entry.context.sector.Id
				end
			end
		end
	end
end

---
--- Sets the sticky side flag for the specified sector.
---
--- @param sector_id number The ID of the sector to set the sticky side flag for.
--- @param sticky boolean The new value for the sticky side flag.
---
function SectorSetStickySide(sector_id, sticky)
	gv_Sectors[sector_id].StickySide = sticky
end

-- general

function OnMsg.PreLoadNetGame()
	CloseSatelliteView(true)
	CloseDialog("ModifyWeaponDlg", true)
end

function OnMsg.ChangeMap()
	CloseSatelliteView(true)
	CloseDialog("ModifyWeaponDlg", true)
end

function OnMsg.NewGameSessionStart()
	CloseSatelliteView(true)
end

if Platform.developer then

local function ShowSectorMapVMEs()
	local map = GetMapName()
	local map_sectors = {}
	local entrance_marker_err_sector_ids = {}
	local entrance_marker_dirs = {}
	local neighbors_with_map = {}
	for c_id, c in pairs(CampaignPresets) do
		for s_id, s in pairs(c.Sectors or empty_table) do
			if s.Map == map and not s.GroundSector then
				map_sectors[c_id] = map_sectors[c_id] or {}
				table.insert(map_sectors[c_id], s)
				neighbors_with_map[s] = {}
				for _, dir in ipairs(const.WorldDirections) do
					local n_id = GetNeighborSector(s.Id, dir, c)
					local idx = table.find(c.Sectors, "Id", n_id)
					local n = c.Sectors[idx]
					if n and n.Map then
						neighbors_with_map[s][dir] = true
					end
				end
			end
		end
	end
	if next(map_sectors) then
		for c_id, sectors in pairs(map_sectors) do
			for _, sector in ipairs(sectors) do
				-- check entrance markers
--[[				for _, dir in ipairs(const.WorldDirections) do
					if sector.Passability ~= "Blocked" and (not sector.BlockTravel or not sector.BlockTravel[dir]) then
						if #MapGetMarkers("Entrance", dir) == 0 and neighbors_with_map[sector][dir] then
							entrance_marker_err_sector_ids[c_id] = entrance_marker_err_sector_ids[c_id] or {}
							table.insert_unique(entrance_marker_err_sector_ids[c_id], sector.Id)
							table.insert(entrance_marker_dirs, dir)
						end
					end
				end]]
				--check intel
				if mapdata.ScriptingStatus == "Ready" then
					local intel_marker = MapGetFirst("map", "IntelMarker")
					if not intel_marker and sector.Intel then
						StoreErrorSource(point30, "No intel markers on a sector with intel - " .. sector.Id)
					end
					if intel_marker and not sector.Intel then
						StoreErrorSource(intel_marker, "Intel marker(s) on a sector without intel - " .. sector.Id)
					end
				end
				
				--check defender markers with both allowed and forbidden entries in ArchetypesTriState
				local def_markers = MapGetMarkers("DefenderPriority", false, function(m) return m.ArchetypesTriState end)
				if def_markers then
					for _, def_marker in ipairs(def_markers) do
						local errorMsg = def_marker:GetError()
						if errorMsg then
							StoreErrorSource(def_marker, errorMsg)
						end
					end
				end
			end
		end
	end
--[[	if next(entrance_marker_err_sector_ids) then
		local lines = {}
		for c_id, sectors in pairs(entrance_marker_err_sector_ids) do
			lines[#lines + 1] = string.format("%s: %s", c_id, table.concat(sectors, ", "))
		end
		StoreWarningSource(point(terrain.GetMapSize()/2, terrain.GetMapSize()/2), string.format("This map corresponds to sectors: %s. Missing Entrance markers on map: %s",
			table.concat(lines, "; "), table.concat(entrance_marker_dirs, ", ")))
	end]]
end

OnMsg.PostSaveMap = ShowSectorMapVMEs
OnMsg.NewMapLoaded = ShowSectorMapVMEs

end --Platform.developer 

-- satellite <-> sector transition
---
--- Spawns units for a squad at the given positions, with optional defender and entrance markers.
---
--- @param session_ids table List of session IDs for the units to spawn
--- @param positions table List of positions to spawn the units at
--- @param marker_angle number|table Angle to spawn the units at, or a table of angles for each unit
--- @param defender_marker GridMarker|table The defender marker to use, or a table of defender markers for each unit
--- @param entrance_marker GridMarker The entrance marker to use
---
function SpawnSquadUnits(session_ids, positions, marker_angle, defender_marker, entrance_marker)
	assert(#session_ids == #positions, "Not enough spawn positions were found")
	for i, session_id in ipairs(session_ids) do
		local unit_data = gv_UnitData[session_id]
		unit_data.already_spawned_on_map = true
		local angle = type(marker_angle) == "table" and marker_angle[i] or marker_angle
		local groups, routine, routine_area, name
		local marker = IsValid(defender_marker) and defender_marker or type(defender_marker) == "table" and defender_marker[i]
		local isEnemy = false
		if IsEnemySquad(unit_data.Squad) then -- add enemy squad units to EnemySquad group and to their defender marker groups
			isEnemy = true
			groups = {"EnemySquad"}
			if marker and marker.Groups then
				table.iappend(groups, marker.Groups)
			end
		end
		if IsGridMarkerWithDefenderRole(marker) then
			routine = marker.Routine
			routine_area = marker.RoutineArea
			name = marker.Name
		end
		if positions[i] then
			local class = unit_data.class
			local unit = SpawnUnit(class, session_id, positions[i], angle, groups, nil, entrance_marker)
			if routine ~= nil then unit.routine = routine end
			if routine_area~= nil then unit.routine_area = routine_area end
			if isEnemy and name and name ~= "" then unit.Name = name end
			unit.routine_spawner = marker
		end
	end
end

local function InsertMarkerInfo(markers_info, marker_type, key, session_id)
	markers_info[marker_type][key] = markers_info[marker_type][key] or {}
	table.insert(markers_info[marker_type][key], session_id)
end

---
--- Fills marker information for a set of squads to be spawned.
---
--- @param markers_info table A table to store the marker information.
--- @param squads_to_spawn table A table of squad IDs and their associated session IDs to spawn.
---
function FillMarkerInfoExplore(markers_info, squads_to_spawn)
	for squad_id, session_ids in sorted_pairs(squads_to_spawn) do
		local squad = gv_Squads[squad_id]
		assert(squad.Side == "player1" or squad.Side == "player2" or squad.Side == "ally",
			string.format("Trying to explore a sector with a non-player squad in it (where should it be placed). Squad: %s, Side: %s", squad.Name, squad.Side))
		for _, session_id in ipairs(session_ids) do
			local unit_data = gv_UnitData[session_id]
			if squad.Side == "ally" and squad.militia then
				InsertMarkerInfo(markers_info, "defend_priority", squad_id, session_id)
			elseif not unit_data.arrival_dir then
				InsertMarkerInfo(markers_info, "defend", squad_id, session_id)
			else
				InsertMarkerInfo(markers_info, "entrance", unit_data.arrival_dir, session_id)
			end
		end
	end
end

-- Each defender priority marker can house up to one unit.
---
--- Spawns units on defender priority marker positions.
---
--- @param session_ids table A table of session IDs for the units to be spawned.
--- @return table The remaining session IDs that could not be spawned on defender priority markers.
---
function SpawnOnDefenderPriorityMarkerPositions(session_ids)
	if #session_ids <= 0 then
		return session_ids
	end

	local def_markers = MapGetMarkers("DefenderPriority", false, function(m)
		if not m:IsMarkerEnabled() then
			return false
		end
		local passSlab = SnapToPassSlab(m)
		if not passSlab or IsOccupiedExploration(nil, passSlab:xyz()) then
			return false
		end
		return true
	end)

	local remaining_sids = table.copy(session_ids)
	local unitToMarker = {}
	local occupied_priority_markers = {}
	
	-- Try to match units to markers which prefer those units in particular.
	for _, marker in ipairs(def_markers) do
		if not marker.UnitDef then goto continue end
		
		for _, sid in ipairs(remaining_sids) do
			local unitData = gv_UnitData[sid]
			if unitData.class == marker.UnitDef then
				unitToMarker[sid] = marker
				occupied_priority_markers[marker] = true
				table.remove_value(remaining_sids, sid)
				break
			end
		end
		
		::continue::
	end
	
	-- Find eligible markers for each enemy role.
	local roleToMarker = {}
	local enemyRoles = Presets.EnemyRole.Default
	for i, rolePreset in ipairs(enemyRoles) do
		local role = rolePreset.id
		
		local thisRoleMarkers = {}
		for _, def_marker in ipairs(def_markers) do
			local overwriteBeastOnMarker = false
			local shouldSpawn = false
			if def_marker.Archetypes and next(def_marker.Archetypes) then -- Old property overrides new one.
				shouldSpawn = not not table.find(def_marker.Archetypes, role)
				overwriteBeastOnMarker = shouldSpawn
			elseif def_marker.ArchetypesTriState then
				local onlyDisabledOthers = def_marker.ArchetypesTriState[role] == nil and table.values(def_marker.ArchetypesTriState)[1] == false
				local enabledMe = def_marker.ArchetypesTriState[role]
				shouldSpawn = onlyDisabledOthers or enabledMe
				overwriteBeastOnMarker = enabledMe
			end
			
			-- Dont spawn beasts on high up markers unless they are specifically set.
			if role == "Beast" and not overwriteBeastOnMarker then
				local floor = GetFloorOfPos(def_marker:GetPosXYZ())
				if floor >= 1 then -- zero indexed
					shouldSpawn = false
				end
			end
			
			if shouldSpawn then
				table.insert(thisRoleMarkers, def_marker)
			end
		end

		roleToMarker[role] = thisRoleMarkers
	end
	
	-- Try to match units to markers which prefer these units' roles.
	for sIdx, sid in ipairs(remaining_sids) do
		local ud = gv_UnitData[sid]
		local unitRole = ud.role
		if not unitRole then goto continue end
		
		local markers = roleToMarker[unitRole]
		if #markers == 0 then goto continue end
		
		for i, m in ipairs(markers) do
			if not occupied_priority_markers[m] then
				unitToMarker[sid] = m
				occupied_priority_markers[m] = true
				remaining_sids[sIdx] = nil
				break
			end
		end
		
		::continue::
	end
	table.compact(remaining_sids)
	
	-- Fill the rest of the markers with the rest of the units.
	for _, marker in ipairs(def_markers) do
		for _, sid in ipairs(remaining_sids) do
			if not occupied_priority_markers[marker] then
				unitToMarker[sid] = marker
				occupied_priority_markers[marker] = true
				table.remove_value(remaining_sids, sid)
				break
			end
		end
	end
	
--[[	print("Units Had To Deploy:", #session_ids)
	print("Markers Available:", #def_markers)
	print("Left for Defender Markers:", #remaining_sids)]]
	
	local result_sids, spawn_positions, spawn_angles, spawn_markers = {}, {}, {}, {}
	for _, sid in ipairs(session_ids) do
		local marker = unitToMarker[sid]
		if marker then
			result_sids[#result_sids + 1] = sid
			spawn_positions[#spawn_positions + 1] = SnapToPassSlab(marker)
			spawn_angles[#spawn_angles + 1] = marker:GetAngle()
			spawn_markers[#spawn_markers + 1] = marker
		end
	end
	SpawnSquadUnits(result_sids, spawn_positions, spawn_angles, spawn_markers)
	return remaining_sids
end

---
--- Fills the defender marker positions with the given count, and stores the spawn positions, angles, and markers in the provided tables.
---
--- @param count number The number of defender marker positions to fill.
--- @param spawn_positions table A table to store the spawn positions.
--- @param spawn_angles table A table to store the spawn angles.
--- @param spawn_markers table A table to store the spawn markers.
---
function FillDefenderMarkerPositions(count, spawn_positions, spawn_angles, spawn_markers)
	if count <= 0 then return end
	local markers = MapGetMarkers("Defender", false, function(m)return m:IsMarkerEnabled() end)
	if not markers or #markers == 0 then
		StoreErrorSource(false, "No enabled Defender markers found on map")
		markers = MapGetMarkers("Entrance")
	end
	
	local _, positions, _, meta = GetRandomSpreadSpawnMarkerPositions(markers, count)
	for i, pos in ipairs(positions) do
		local positionMeta = meta[i]
	
		spawn_positions[#spawn_positions+1] = pos
		spawn_angles[#spawn_angles+1] = positionMeta[2]
		spawn_markers[#spawn_markers+1] = positionMeta[3]
	end
end

MapVar("g_GroupedSquadUnits", {})

local cardinalToAngle = {
	["North"] = 0,
	["East"] = 90,
	["South"] = 180,
	["West"] = 270
}

DefineClass.AutoGeneratedEntranceMarker = {
	__parents = { "GameDynamicSpawnObject", "SyncObject", "GridMarker" },
	exit_zone_interactable = false,
	underground = false
}

-- load
---
--- Sets the dynamic data for the AutoGeneratedEntranceMarker object.
---
--- If the marker has an associated exit zone interactable, this function will generate either an underground or surface entrance marker based on the data provided.
---
--- @param data table The dynamic data for the marker, containing the exit zone handle and a flag indicating if the marker is underground.
---
function AutoGeneratedEntranceMarker:SetDynamicData(data)
	if data.exit_zone_handle then
		local handle = data.exit_zone_handle
		local exitZone = HandleToObject[handle]
		if IsKindOf(exitZone, "ExitZoneInteractable") then
			local underground = data.underground
			if underground then
				GenerateUndergroundMarker(exitZone, self)
			else
				GenerateEntranceMarker(exitZone, self)
			end
		end
	end
end

-- save
---
--- Gets the dynamic data for the AutoGeneratedEntranceMarker object.
---
--- If the marker has an associated exit zone interactable, this function will retrieve the handle of the exit zone and a flag indicating if the marker is underground.
---
--- @param data table The table to store the dynamic data for the marker.
---
function AutoGeneratedEntranceMarker:GetDynamicData(data)
	if self.exit_zone_interactable then
		data.exit_zone_handle = self.exit_zone_interactable:GetHandle()
		data.underground = self.underground
	end
end

---
--- Generates an underground entrance marker for the given exit zone interactable.
---
--- If there are already entrance markers in the same direction as the exit zone, this function will not generate a new marker.
---
--- @param exitZoneInteractable ExitZoneInteractable The exit zone interactable to generate the underground entrance marker for.
--- @param placedMarker AutoGeneratedEntranceMarker The marker that has already been placed, if any.
---
function GenerateUndergroundMarker(exitZoneInteractable, placedMarker)
	local direction = exitZoneInteractable.Groups[1]
	local markersInThisDirection = MapGetMarkers("Entrance", direction, function(marker) return marker ~= placedMarker end)
	if markersInThisDirection and #markersInThisDirection > 0 then
		return
	end

	local fakeMarker = placedMarker or PlaceObject("AutoGeneratedEntranceMarker")
	fakeMarker:ClearGameFlags(const.gofPermanent) -- place object spawns non-perma, but this is to clarify intention
	fakeMarker:SetType("Entrance")
	fakeMarker:SetGroups(exitZoneInteractable.Groups)
	fakeMarker:SetPos(SnapToVoxel(exitZoneInteractable:GetPos()))
	fakeMarker:SetAngle(exitZoneInteractable:GetAngle() - 90 * 60)
	fakeMarker:SetAreaWidth(5)
	fakeMarker:SetAreaHeight(5)
	fakeMarker.GroundVisuals = true
	fakeMarker.IsMarkerEnabled = function()
		return exitZoneInteractable:IsMarkerEnabled()
	end
	fakeMarker.underground = true
	fakeMarker.exit_zone_interactable = exitZoneInteractable
	table.insert(g_InteractableAreaMarkers, fakeMarker)
end

local lDeployAlongMapSize = 5
---
--- Generates an entrance marker for the given exit zone interactable.
---
--- If there are already entrance markers in the same direction as the exit zone, this function will not generate a new marker.
---
--- @param exitZoneInteractable ExitZoneInteractable The exit zone interactable to generate the entrance marker for.
--- @param placedMarker AutoGeneratedEntranceMarker The marker that has already been placed, if any.
---
function GenerateEntranceMarker(exitZoneInteractable, placedMarker)
	local direction = exitZoneInteractable.Groups[1]
	local entranceMarkerPos = exitZoneInteractable:GetPos()

	local markersInThisDirection = MapGetMarkers("Entrance", direction, function(marker) return marker ~= placedMarker end)
	if markersInThisDirection and #markersInThisDirection > 0 then
		return
	end

	local fakeMarker = placedMarker or PlaceObject("AutoGeneratedEntranceMarker")
	fakeMarker:ClearGameFlags(const.gofPermanent) -- place object spawns non-perma, but this is to clarify intention
	fakeMarker:SetType("Entrance")
	fakeMarker:SetGroups({ direction })
	fakeMarker.GroundVisuals = true
	fakeMarker.underground = false
	fakeMarker.exit_zone_interactable = exitZoneInteractable
	table.insert(g_InteractableAreaMarkers, fakeMarker)
	
	local mapDir = mapdata.MapOrientation - cardinalToAngle[direction]
	local mapCenter = point(terrain.GetMapSize()) / 2
	local bam = GetBorderAreaMarker()
	local mapDirectionSide = (GetMapPositionAlongOrientation(mapDir) - mapCenter + bam:GetPos()):SetInvalidZ()
	local borderBox = GetBorderAreaLimits()
	local bamCenter = borderBox:Center()
	mapDirectionSide = ClampPoint(mapDirectionSide, borderBox)

	local sizex, sizey = borderBox:sizexyz()
	if direction == "East" or direction == "West" then
		local offset = sign(entranceMarkerPos:x() - mapDirectionSide:x()) * const.SlabSizeX * lDeployAlongMapSize/2
		mapDirectionSide = point(mapDirectionSide:x() + offset, mapDirectionSide:y())
		mapDirectionSide = SnapToVoxel(mapDirectionSide)
		
		if not GetPassSlab(mapDirectionSide) then
			mapDirectionSide = entranceMarkerPos
		end
		
		fakeMarker:SetPos(mapDirectionSide)
		fakeMarker:SetAreaWidth(lDeployAlongMapSize)
		
		local offsetFromCenter = abs(entranceMarkerPos:y() - bamCenter:y())
		sizey = sizey + (offsetFromCenter * 2)
		sizey = DivCeil(sizey, const.SlabSizeY)
		if sizey % 2 == 0 then sizey = sizey + 1 end
		fakeMarker:SetAreaHeight(sizey)
		
		mapDir = (mapDir - 90) % 360
		fakeMarker:SetAngle(mapDir * 60)
	elseif direction == "North" or direction == "South" then
		local offset = sign(entranceMarkerPos:y() - mapDirectionSide:y()) * const.SlabSizeY * lDeployAlongMapSize/2
		mapDirectionSide = point(mapDirectionSide:x(), mapDirectionSide:y() + offset)
		mapDirectionSide = SnapToVoxel(mapDirectionSide)
	
		if not GetPassSlab(mapDirectionSide) then
			mapDirectionSide = entranceMarkerPos
		end
	
		fakeMarker:SetPos(mapDirectionSide)
		fakeMarker:SetAreaHeight(lDeployAlongMapSize)
		
		local offsetFromCenter = abs(entranceMarkerPos:x() - bamCenter:x())
		sizex = sizex + (offsetFromCenter * 2)
		sizex = DivCeil(sizex, const.SlabSizeX)
		if sizex % 2 == 0 then sizex = sizex + 1 end
		fakeMarker:SetAreaWidth(sizex)
		
		mapDir = (mapDir + 90) % 360
		fakeMarker:SetAngle(mapDir * 60)
	end
end

---
--- Spawns squads of units on the map based on the provided parameters.
---
--- @param squad_ids table List of squad IDs to spawn
--- @param spawn_mode string The spawn mode, can be "explore", "defend", or "attack"
--- @param spawn_markers table Optional table of spawn marker information for each squad
--- @param force_test_map boolean If true, forces the map to be in "attack" mode
--- @param enter_sector boolean If true, indicates that the player is entering a new sector
---
function SpawnSquads(squad_ids, spawn_mode, spawn_markers, force_test_map, enter_sector)
	local remove_dead = not not enter_sector

	g_GroupedSquadUnits = {}
	local squads_to_spawn = {}
	local map_combat_units = MapGet("map", "Unit") or empty_table
	
	-- remove map objs for mercs which are no longer with the squad saved on the sector, also all dead bodies on map reenter
	for i = #map_combat_units, 1, -1 do
		local obj = map_combat_units[i]
		local session_id = obj.session_id
		local delete_obj
		if not obj.spawner or obj.Squad then -- don't remove spawner units, except those who joined a squad
			-- unit was on this map once and either died here (which why they have no squad), or their squad isnt here anymore.
			local squad = gv_Squads[obj.Squad]
			local squad_units = table.find(squad_ids, obj.Squad) and squad and squad.units or empty_table
			local missing = (remove_dead or not obj:IsDead()) and not table.find(squad_units, session_id)
			
			-- unit was on this map once and has returned after having been somewhere else, it needs to be respawned (lUpdateSquadCurrentSector)
			local should_respawn = gv_UnitData[session_id] and not gv_UnitData[session_id].already_spawned_on_map
			
			-- Enemies will always redeploy (211594) to simulate time passing,
			-- if they are part of a squad.
			if enter_sector and squad and squad.Side == "enemy1" then
				should_respawn = true
			end
			
			delete_obj = missing or should_respawn
		elseif remove_dead and obj.spawner and obj:IsDead() and not obj:IsPersistentDead() then
			if obj:HasPassedTimeAfterDeath(const.Satellite.RemoveDeadBodiesAfter) then
				delete_obj = true
			end
		end
		if delete_obj then
			-- drop loot here
			if obj:IsDead() then
				-- Unit:DropLoot() should have been already called at this point from somewhere else.
				local sector = gv_Sectors[gv_CurrentSectorId]
				local diedHere = next(sector.dead_units) and table.find(sector.dead_units, session_id)
				if diedHere then
					table.remove_value(sector.dead_units, obj.session_id)
					obj:DropAllItemsInAContainer()
				end
				obj:Despawn()-- also remove UnitData and do not save it in savegame
			else
				DoneObject(obj)
			end
			table.remove(map_combat_units, i)
		end
	end
	
	-- add map objs for mercs which were not with the squad saved on the sector
	for _, squad_id in ipairs(squad_ids) do
		local squad = gv_Squads[squad_id]
		assert(squad) -- false when squad exists in SquadArray but not in gv_Squads
		for _, session_id in ipairs(squad and squad.units) do
			if not table.find_value(map_combat_units, "session_id", session_id) and not gv_UnitData[session_id].retreat_to_sector then
				squads_to_spawn[squad_id] = squads_to_spawn[squad_id] or {}
				table.insert(squads_to_spawn[squad_id], session_id)
			end
		end
	end
	
	if spawn_mode then
		local markers_info = {defend_priority = {}, defend = {}, entrance = {}}
		local sorted_group_on_markers = {}
		if spawn_mode == "explore" then
			FillMarkerInfoExplore(markers_info, squads_to_spawn)
		else
			for squad_id, session_ids in sorted_pairs(squads_to_spawn) do
				local squad = gv_Squads[squad_id]
								
				if spawn_markers and spawn_markers[squad_id] then -- if spawn_markers is specified for this squad, use that instead of the standard logic
					local marker_type, marker_group = table.unpack(spawn_markers[squad_id])
					local markers = MapGetMarkers(marker_type, marker_group, function(m) return m:IsMarkerEnabled() end)
					local _, positions, marker_angle = GetRandomSpawnMarkerPositions(markers, #session_ids)
					SpawnSquadUnits(session_ids, positions, marker_angle)
				elseif (squad.Side == "enemy1" or squad.Side == "enemy2") and spawn_mode == "defend" then -- enemies attacking, group them in small batches of 2-4 units
					local markers = GetAvailableEntranceMarkers(gv_UnitData[session_ids[1]].arrival_dir)
					local idx = 0
					while idx < #session_ids do
						local marker = table.interaction_rand(markers, "SpawnEnemies")
						local count = Min(InteractionRandRange(2, 4), #session_ids - idx)
						if idx + count == #session_ids - 1 then -- don't leave one unit alone for the last group
							count = count + 1
						end
						local group_on_marker = {marker}
						table.insert(sorted_group_on_markers, group_on_marker)
						for i = idx + 1, idx + count do
							InsertMarkerInfo(markers_info, "entrance", #sorted_group_on_markers, session_ids[i])
							idx = idx + 1
						end
					end
				else
					for _, session_id in ipairs(session_ids) do
						local unit_data = gv_UnitData[session_id]
						if force_test_map then
							unit_data.arrival_dir = "North"
						end
						-- militia and enemy mercs use priority defender markers first, villain have special defender priority markers
						if (spawn_mode == "defend" and (squad.Side == "player1" or squad.Side == "ally") and squad.militia) or (spawn_mode == "attack" and squad.Side ~= "player1") then
							InsertMarkerInfo(markers_info, "defend_priority", squad_id, session_id)
						elseif spawn_mode == "defend" and squad.Side == "player1" then
							InsertMarkerInfo(markers_info, "defend", squad_id, session_id)
						else
							InsertMarkerInfo(markers_info, "entrance", unit_data.arrival_dir, session_id)
						end
					end
				end
			end
		end
		
		local occupied_priority_markers = {}
		for squad_id, session_ids in sorted_pairs(markers_info.defend_priority) do
			local spawn_positions, spawn_angles, spawn_markers = {}, {}, {}
			local remaining = SpawnOnDefenderPriorityMarkerPositions(session_ids)
			
			-- Add remaning units to the normal defender marker deploy
			if #remaining > 0 then
				local squadUnits = markers_info.defend[squad_id]
				if not squadUnits then
					markers_info.defend[squad_id] = remaining
				else
					local list = markers_info.defend[squad_id]
					for i, session_id in ipairs(remaining) do
						list[#list + 1] = session_id
					end
				end
			end
		end
		
		-- Deploy all enemies together as a single squad to better spread them out.
		local allSquadsFlattened = {}
		for squad_id, session_ids in sorted_pairs(markers_info.defend) do
			table.iappend(allSquadsFlattened, session_ids)
		end
		
		if true then
			local spawn_positions, spawn_angles, spawn_markers = {}, {}, {}
			FillDefenderMarkerPositions(#allSquadsFlattened, spawn_positions, spawn_angles, spawn_markers)
			SpawnSquadUnits(allSquadsFlattened, spawn_positions, spawn_angles, spawn_markers)
		end
		
--[[		for squad_id, session_ids in sorted_pairs(markers_info.defend) do
			local spawn_positions, spawn_angles, spawn_markers = {}, {}, {}
			FillDefenderMarkerPositions(#session_ids, spawn_positions, spawn_angles, spawn_markers)
			SpawnSquadUnits(session_ids, spawn_positions, spawn_angles, spawn_markers)
		end]]
		
		local positions_per_marker = {}
		for key, session_ids in sorted_pairs(markers_info.entrance) do
			local markers
			local marker, positions, marker_angle
			if type(key) == "string" then
				markers = MapGetMarkers("Entrance", key, function(marker) return SnapToPassSlab(marker) end)
				if not markers or #markers == 0 then
					StoreErrorSource(session_ids, string.format("No enabled Entrance markers found on map '%s' with key '%s' - trying random entrance marker instead!", GetMapName(), key))
					markers = MapGetMarkers("Entrance")
					if not markers or #markers == 0 then
						StoreErrorSource(session_ids, string.format("No enabled Entrance markers found on map '%s'!", GetMapName()))
						return
					end
				end
				--temp 0210007
				NetUpdateHash("GetRandomSpawnMarkerPositions1", #session_ids, table.unpack(markers))
				marker, positions, marker_angle = GetRandomSpawnMarkerPositions(markers, #session_ids, "around_center")
				NetUpdateHash("GetRandomSpawnMarkerPositions2", table.unpack(positions))
			elseif type(key) == "number" or type(key) == "boolean" then
				if not key then
					markers = MapGetMarkers("Entrance")
				else
					markers = sorted_group_on_markers[key]
				end
				if not markers or #markers == 0 then
					StoreErrorSource(session_ids, string.format("No enabled Entrance markers found on map '%s'!", GetMapName()))
					markers = MapGetMarkers("Entrance")
				end
				
				marker, positions, marker_angle = GetRandomPositionsFromSpawnMarkersMaxDistApart(markers, #session_ids, positions_per_marker)
				-- add grouped units in global var
				g_GroupedSquadUnits[#g_GroupedSquadUnits + 1] = session_ids
			else
				assert(false, "sorted_pairs with weirdo key types is an async op!")
			end
			SpawnSquadUnits(session_ids, positions, marker_angle, nil, marker)
		end
	elseif spawn_markers then
		for squad_id, session_ids in sorted_pairs(squads_to_spawn) do
			local marker_type, marker_group = table.unpack(spawn_markers[squad_id] or empty_table)
			local markers = MapGetMarkers(marker_type, marker_group, function(m) return m:IsMarkerEnabled() end)
			local _, positions, marker_angle = GetRandomSpawnMarkerPositions(markers, #session_ids)
			SpawnSquadUnits(session_ids, positions, marker_angle)
		end
	end
end

MapVar("g_GoingAboveground", false)

local function shouldSpawnSquad(squad, sector, ignore_travel)
	return squad.CurrentSector == sector.Id and (not IsSquadTravelling(squad) or ignore_travel) and not squad.arrival_squad
end

LoadSectorThread = false
local enterSectorThread = false
local doneEnterSector = false
---
--- Enters a new sector, handling various tasks such as loading the sector, spawning squads, and updating the game state.
---
--- @param sector_id string The ID of the sector to enter.
--- @param spawn_mode string|nil The spawn mode to use when spawning squads.
--- @param spawn_markers table|nil The spawn markers to use when spawning squads.
--- @param save_sector boolean|nil Whether to save the current sector before entering the new one.
--- @param force_test_map boolean|nil Whether to force the use of the test map.
--- @param game_start boolean|nil Whether this is the start of the game.
---
function EnterSector(sector_id, spawn_mode, spawn_markers, save_sector, force_test_map, game_start)
	if IsValidThread(enterSectorThread) then
		assert(false) --two concurrent enter sector threads!
		return
	end
	enterSectorThread = CurrentThread()
	doneEnterSector = false
	NetGossip("EnterSector", sector_id, spawn_mode, GetCurrentPlaytime(), game_start)

	if netInGame and GetMapName() ~= "" and not GetGamePause() and not IsGameReplayRunning() then
		--entering_sector is treated as sync, so try to make it such when possible
		FireNetSyncEventOnHost("EnteringSectorSync")
		local state = {entering_sector = true}
		local timeout = 5000
		local start_ts = GetPreciseTicks()
		while not MatchGameState(state) and GetPreciseTicks() - start_ts < timeout do
			WaitMsg("GameStateChanged", timeout)
		end
	end
	ChangeGameState { entering_sector = true }
	
	-- If there is a conflict auto save running, wait for it to finish cuz crashes can occur otherwise.
	while IsAutosaveScheduled() do
		Sleep(1)
	end
	
	spawn_mode = force_test_map and "attack" or spawn_mode
	local load_game = not spawn_mode and not spawn_markers
	
	if not load_game and not force_test_map and gv_Sectors[sector_id] then
		ExecuteSectorEvents("SE_PreChangeMap", sector_id, "wait")
	end
	
	local sat_view_loading_screen = GameState.loading_savegame and gv_SatelliteView
	local id = sat_view_loading_screen and "idSatelliteView" or "idEnterSector"
	SectorLoadingScreenOpen(id, "enter sector", not sat_view_loading_screen and sector_id)	
	
	local sector = gv_Sectors[sector_id]
	local ambient_timeouted
	if sector and not GameState.loading_savegame then
		ambient_timeouted = sector.last_enter_campaign_time and 
			(Game.CampaignTime - sector.last_enter_campaign_time >  const.AmbientLife.SatelliteTimeout)
		sector.last_enter_campaign_time = Game.CampaignTime

		-- When entering a sector you can no longer wait.
		if sector.conflict then
			sector.conflict.waiting = false
			SetCampaignSpeed(0, "SatelliteConflict")
		end
		
		CheckSectorRadioStations(sector)
	end
	
	SkipAnySetpieces()
	ChangeGameState("setpiece_playing", false)  --we've tried skipping setpieces gracefully, but if a setpiece hadn't started yet it may leave this on once change map kills its threads
	
	-- Wait for net sync events to end since the map change will delete them.
	NetSyncEventFence("EnterSector")
	NetGameSend("rfnClearHash") --this clears passed caches stored server side so new hashes @ the same gametime doesn't cause desyncs
	NetStartBufferEvents("EnterSector")

	-- Leaving the map? Delete ephemeral units and fast forward commands
	if not GameState.loading_savegame then
		--deleting sync objs in rtt, awesome.
		--it's kind of sort of sync after the fence, but not really
		local units = table.copy(g_Units)
		for i, u in ipairs(units) do
			if u.ephemeral then
				u:Despawn()
			elseif not IsMerc(u) then
				u:FastForwardCommand()
			end
		end
	end
	
	if save_sector then
		GatherSectorDynamicData() -- create sector_data for the previous sector
	end

	NetSyncEvents.CloseSatelliteView(true) --this is presumably sync enough after fence
	OnSatViewClosed()
	gv_CurrentSectorId = sector_id
	
	g_GoingAboveground = false
	for _, squad in ipairs(g_SquadsArray) do
		if shouldSpawnSquad(squad, sector) and IsSectorUnderground(squad.PreviousSector) and not IsSectorUnderground(sector.Id) then
			g_GoingAboveground = true
			break
		end
	end
	
	-- Try to find sync handle generation during map init.
	-- These can break saves if they take the handle of an object that will be
	-- spawned by dynamic data.
	if Platform.developer then
		local postMapLoaded = false
		CreateRealTimeThread(function()
			WaitMsg("PostNewMapLoaded")
			postMapLoaded = true
		end)
	
		local genSyncHandleOld = GenerateSyncHandle
		GenerateSyncHandle = function(...)
			if postMapLoaded then
				GenerateSyncHandle = genSyncHandleOld
			else
				assert(false) -- Generating sync handle before map has loaded!
			end
			return genSyncHandleOld(...)
		end
	end
	
	ChangeGameState{loading_savegame = true}
	ChangeMap(
		force_test_map or 
		sector.Map or 
		(Platform.goldmaster and "EmptyMap" or "__CombatTest")
	)
	ChangeGameState{loading_savegame = false, entered_sector = true}

	-- Load saved data
	local luaRevisionLoaded = ApplyDynamicData()

	-- Auto create entrance markers for directions in which entrances are not placed.
	for _, direction in sorted_pairs(const.WorldDirections) do
		local exitZoneInt = MapGetMarkers("ExitZoneInteractable", direction)
		exitZoneInt = exitZoneInt and exitZoneInt[1]
		local neighbour = exitZoneInt and GetNeighborSector(sector_id, direction)
		local validDirection = neighbour and not SectorTravelBlocked(neighbour, sector_id, false, "land_water_river")
		
		if force_test_map or validDirection then
			GenerateEntranceMarker(exitZoneInt)
		end
	end
	
	-- Auto create any above/underground entrances from exit zone interactables.
	local underground = MapGetMarkers("ExitZoneInteractable", false, ExitZoneInteractable.IsUndergroundExit)
	for i, exitZoneInt in ipairs(underground) do
		GenerateUndergroundMarker(exitZoneInt)
	end
	
	-- Reset retreating status of mercs if re-entering sector.
	if not load_game then
		local udHere = GetPlayerMercsInSector()
		for i, uId in ipairs(udHere) do
			local ud = gv_UnitData[uId]
			if ud and ud.retreat_to_sector then
				CancelUnitRetreat(ud)
			end
		end
	end

	if not load_game then -- do not clear var if savegame was made during deployment
		gv_Deployment = false
	end
	local deployment = not force_test_map and not SkipDeployment(spawn_mode)
	if deployment then
		SetDeploymentMode(spawn_mode or gv_Deployment)
	end

	if not load_game then
		local squad_ids = {}
		if force_test_map then
			table.insert(squad_ids, 1)
		else
			for _, squad in ipairs(g_SquadsArray) do
				if shouldSpawnSquad(squad, sector) then
					table.insert(squad_ids, squad.UniqueId)
				end
			end
		end
		if #squad_ids == 0 and IsSectorUnderground(sector_id) then
			for _, squad in ipairs(g_SquadsArray) do
				if shouldSpawnSquad(squad, sector, "ignore travel") then
					table.insert(squad_ids, squad.UniqueId)
				end
			end			
		end
		UpdateSpawnersLocal()
		SpawnSquads(squad_ids, spawn_mode, spawn_markers, force_test_map, "enter_sector")
	end
	
	SetupTeamsFromMap()
	UpdateSpawnersLocal()
	Msg("EnterSector", game_start, load_game, luaRevisionLoaded)
	ListCallReactions(g_Units, "OnEnterSector", game_start, load_game)
	
	if not load_game or ambient_timeouted then
		Msg("AmbientLifeSpawn")
	end
	
	if not load_game and gv_CurrentSectorId and gv_Sectors[gv_CurrentSectorId] and gv_Sectors[gv_CurrentSectorId].Map == GetMapName() then
		ExecuteSectorEvents("SE_OnEnterMap", gv_CurrentSectorId, "wait")
	end
	
	if netInGame then
		if load_game then
			local rez = NetWaitGameStart()
			if rez == "timeout" then
				if NetIsHost() then
					NetEvent("RemoveClient", 2, "timeout")
				else
					NetLeaveGame("timeout")
				end
			end
		
			assert(AdvanceToGameTimeLimit == GameTime())
			AdvanceToGameTimeLimit = GameTime()
		end
		Resume("net")
	end
	--apparently, this needs to be before netstopbuffer, idk why, otherwise we get the same events but with messed up thread order
	SectorLoadingScreenClose(id, "enter sector", not sat_view_loading_screen and sector_id)
	NetStopBufferEvents("EnterSector")
	
	if not load_game and gv_CurrentSectorId and gv_Sectors[gv_CurrentSectorId] and gv_Sectors[gv_CurrentSectorId].Map == GetMapName() then
		ExecuteSectorEvents("SE_OnEnterMapVisual", gv_CurrentSectorId, true)
		CreateOnEnterMapVisualMsg()
	end
	
	NetSyncEventFence() --make sure auto save happens after buffered events are executed in case they do something to the state that needs saving
	enterSectorThread = false --deployment test never actually leaves deployment before changing to next sector
	SetupDeployOrExploreUI(load_game)
	-- do not auto-save if deployment is delayed
	if not load_game and (not deployment or gv_DeploymentStarted) then
		RequestAutosave{ autosave_id = "sectorEnter", save_state = "SectorEnter", display_name = T{841930548612, "<u(Id)>_SectorEnter", gv_Sectors[gv_CurrentSectorId]}, mode = "delayed" }
	end
	NetSyncEvent("DoneEnterSector", netUniqueId)
	assert(not IsEditorActive() and cameraTac.IsActive(), "Map has non-tac camera activated")
end

--- Synchronizes the loading of the game by skipping any setpieces that are currently playing.
---
--- This function is called as a NetSyncEvent and is responsible for ensuring that any setpieces
--- that are currently playing are skipped before the game can continue loading. It first checks
--- if there is a valid LoadSectorThread and if the game state indicates that setpieces are
--- currently playing. If so, it deletes the LoadSectorThread and then creates a new game time
--- thread to call the SkipAnySetpieces function.
---
--- @function NetSyncEvents.LoadGame_SkipAnySetpieces
--- @return nil
function NetSyncEvents.LoadGame_SkipAnySetpieces()
	if IsValidThread(LoadSectorThread) and GameState.setpiece_playing then
		DeleteThread(LoadSectorThread)
	end

	CreateGameTimeThread(SkipAnySetpieces)
end

--- Synchronizes the loading of the game by skipping any setpieces that are currently playing.
---
--- This function is called as a NetSyncEvent and is responsible for ensuring that any setpieces
--- that are currently playing are skipped before the game can continue loading. It first checks
--- if there is a valid LoadSectorThread and if the game state indicates that setpieces are
--- currently playing. If so, it deletes the LoadSectorThread and then creates a new game time
--- thread to call the SkipAnySetpieces function.
---
--- @function NetSyncEvents.LoadGame_SkipAnySetpieces
--- @return nil
function LoadGame_SkipAnySetpieces()
	NetSyncEvent("LoadGame_SkipAnySetpieces")
	while GameState.setpiece_playing do
		WaitMsg("SetpieceEnded", 100)
	end
end

--- Synchronizes the state of the game when entering a new sector.
---
--- This function is called as a NetSyncEvent and is responsible for setting the game state to indicate that the player is currently entering a new sector. This is used to coordinate certain actions, such as skipping any setpieces that are currently playing, before the game can continue loading.
---
--- @function NetSyncEvents.EnteringSectorSync
--- @return nil
function NetSyncEvents.EnteringSectorSync()
	ChangeGameState { entering_sector = true }
end

--- Marks that a player has finished entering a new sector.
---
--- This function is called as a NetSyncEvent and is responsible for updating the game state to indicate that a player has finished entering a new sector. It keeps track of which players have finished entering the sector, and when all players have finished, it changes the game state to indicate that the sector entry process is complete.
---
--- @function NetSyncEvents.DoneEnterSector
--- @param id? number The unique ID of the player who has finished entering the sector
--- @return nil
function NetSyncEvents.DoneEnterSector(id)
	doneEnterSector = doneEnterSector or {}
	if id then
		doneEnterSector[id] = true
	end
	if not netInGame or table.count(doneEnterSector) >= table.count(netGamePlayers) then
		ChangeGameState { entering_sector = false }
	end
	Msg("DoneEnterSector")
end

function OnMsg.NetPlayerLeft(player, reason)
	if GameState.entering_sector and doneEnterSector and not doneEnterSector[player.id] then
		NetSyncEvents.DoneEnterSector()
	end
end

--- Loads a sector and enters it.
---
--- This function is responsible for loading a sector and entering it. It first checks if there is an existing `enterSectorThread` and asserts if there is, as it should not be possible to enter a sector more than once. It then checks if the game is in multiplayer mode and pauses the "net" context if so.
---
--- The function then creates a new real-time thread called `LoadSectorThread` that calls the `LocalLoadSector` function with the provided `sector_id` and `spawn_mode` parameters. If the game is in multiplayer mode, it asserts that `netInGame` is true.
---
--- @param sector_id number The ID of the sector to load and enter.
--- @param spawn_mode string The spawn mode to use when entering the sector.
--- @return nil
function LoadSector(sector_id, spawn_mode)
	--NetUpdateHash("LoadSector", sector_id, spawn_mode) --this is not sync code, it hasn't desynced till now cuz it gets dropped due to changemap
	if IsValidThread(enterSectorThread) then
		assert(false) --trying to enter sector more than once!
		return
	end
	local multiplayer = IsCoOpGame()
	if multiplayer then
		Pause("net")
	end
	
	LoadSectorThread = CreateRealTimeThread(function(multiplayer, sector_id, spawn_mode)
		if multiplayer then
			assert(netInGame)
		end
		
		LocalLoadSector(sector_id, spawn_mode, nil, "saveSector")
	end, multiplayer, sector_id, spawn_mode)
end

--- Loads a sector and enters it.
---
--- This function is responsible for loading a sector and entering it. It first checks if the game is in the initial sector and if so, sets the `thisIsFirstSector` flag. It then checks if there are any conflicts in the sector and sets the `initial_sector` flag on the conflict if this is the first sector.
---
--- The function then creates the spawn markers for any player mercenary squads in the current sector and calls `EnterSector` to load and enter the sector.
---
--- @param sector_id number The ID of the sector to load and enter.
--- @param spawn_mode string The spawn mode to use when entering the sector.
--- @param spawn_markers table A table of spawn markers for player mercenary squads.
--- @param save_sector boolean Whether to save the sector after loading.
--- @param force_test_map boolean Whether to force the test map to be loaded.
--- @param game_start boolean Whether this is the start of the game.
--- @return nil
function LocalLoadSector(sector_id, spawn_mode, spawn_markers, save_sector, force_test_map, game_start)
	assert(CanYield())
	if not EnterFirstSector(sector_id) then
		EnterSector(sector_id, spawn_mode, spawn_markers, save_sector, force_test_map, game_start)
	end
end

--- Checks if the current sector is the initial sector and sets up the game state accordingly.
---
--- This function is responsible for determining if the current sector is the initial sector for the game. It first gets the current campaign preset and the initial sector ID. It then checks if the current sector ID matches the initial sector ID, and if so, it sets the `thisIsFirstSector` flag based on whether the game state has already entered a sector.
---
--- If the current sector is the initial sector, the function checks if there is a conflict in the sector and sets the `initial_sector` flag on the conflict if this is the first time entering the sector. It then creates spawn markers for any player mercenary squads in the current sector and calls `EnterSector` to load and enter the sector.
---
--- @param sector_id number The ID of the sector to check.
--- @param force boolean Whether to force the sector to be treated as the initial sector.
--- @return boolean True if the current sector is the initial sector, false otherwise.
function EnterFirstSector(sector_id, force)
	local campaignPreset = GetCurrentCampaignPreset()
	local init_sector = campaignPreset.InitialSector
	
	local thisIsFirstSector = force
	
	if not thisIsFirstSector and sector_id == init_sector then
		thisIsFirstSector = not GameState.entered_sector
		
		-- We are in the initial sector but we've been in a sector before.
		-- Check if this is the initial_sector conflict, in which case it
		-- means we've game overed here.
		if not thisIsFirstSector then
			local conflictHere = gv_Sectors[sector_id]
			conflictHere = conflictHere and conflictHere.conflict
			thisIsFirstSector = conflictHere and conflictHere.initial_sector
		end
	end

	if thisIsFirstSector then
		local conflict = gv_Sectors[sector_id]
		conflict = conflict and conflict.conflict
		if conflict then
			conflict.initial_sector = true
		end
	
		local spawn_markers = {}
		local markers = {"Defender", "GameIntro"}
		for i, s in ipairs(GetPlayerMercSquads()) do
			if s.CurrentSector == sector_id then
				spawn_markers[s.UniqueId] = markers
			end
		end
		EnterSector(sector_id, nil, spawn_markers, true, nil, "game_start")
		return true
	end
end

function OnMsg.StartSatelliteGameplay()
	-- Open the satellite conflict screen when the satellite is opened for the first time.
	if not GameState.entered_sector then
		local initialSector = GetCurrentCampaignPreset().InitialSector
		if IsConflictMode(initialSector) then
			OpenSatelliteConflictDlg(gv_Sectors[initialSector])
		end
	end
end

function OnMsg.ChangeMap()
	ChangeGameState{entered_sector = false}
end

function OnMsg.NewGameSessionStart()
	ChangeGameState{entered_sector = false}
end

function OnMsg.DoneGame()
	ChangeGameState{entered_sector = false, entering_sector = false}
	DeleteThread(enterSectorThread)
	DeleteThread(doneEnterSector)
	DeleteThread(LoadSectorThread)
end

--- Checks if the given sector ID represents an underground sector.
---
--- @param id number The sector ID to check.
--- @return boolean True if the sector is underground, false otherwise.
function IsSectorUnderground(id)
	return not not (gv_Sectors[id] and gv_Sectors[id].GroundSector)
end

DefineConstInt("Satellite", "CoOpCountdownSeconds", 3, false, "The length of the countdown to enter satellite view in co-op.")

local function lCloseSatelliteCountdowns()
	for d, _ in pairs(g_OpenMessageBoxes) do
		if d and d.window_state == "open" and d.context.obj == "satellite-countdown" then
			d:Close()
		end
	end
end

---
--- Starts a countdown dialog and performs the appropriate action when the countdown completes.
---
--- @param mode string The mode of the countdown, can be "open", "close", or another mode-specific value.
--- @param mode_param table|nil Additional parameters for the mode, such as the sector to enter when closing the satellite view.
---
function NetSyncEvents.StartSatelliteCountdown(mode, mode_param)
	if not CanYield() then
		CreateRealTimeThread(NetSyncEvents.StartSatelliteCountdown, mode, mode_param)
		return
	end
	
	lCloseSatelliteCountdowns()
	
	local dialog = CreateMessageBox(terminal.desktop, "", "", T(739643427177, "Cancel"),  "satellite-countdown")
	local reason = "satellite-countdown"
	Pause(reason)
	PauseCampaignTime(reason)
	dialog.OnDelete = function()
		Resume(reason)
		ResumeCampaignTime(reason)
	end

	local countdown_seconds = const.Satellite.CoOpCountdownSeconds
	dialog:CreateThread("countdown", function()
		local idText = dialog.idMain.idText
		local currentCountdown = countdown_seconds
		for i = 1, countdown_seconds do
			if idText.window_state == "open" then
				if mode == "open" then
					idText:SetText(T{766863202626, "<center>Entering Sat View in <u(currentCountdown)>", currentCountdown = currentCountdown})
				elseif GameState.entered_sector then
					idText:SetText(T{628266992810, "<center>Closing Sat View in <u(currentCountdown)>", currentCountdown = currentCountdown})
				else
					idText:SetText(T{552141784654, "<center>Starting game in <u(currentCountdown)>", currentCountdown = currentCountdown})
				end
			else
				break
			end
				
			Sleep(1000)
			currentCountdown = currentCountdown - 1
			ObjModified(currentCountdown)
			if currentCountdown <= 1 then
				CloseBlockingDialogs()
			end
		end
		
		dialog:Close()

		if mode == "open" then
			OpenSatelliteView()
		elseif mode == "close" and mode_param then
			UIEnterSectorInternal(table.unpack(mode_param))
		elseif mode == "close" then
			CloseDialog("PDADialogSatellite")
		else
			local pda = GetDialog("PDADialogSatellite")
			if pda then pda:SetMode(mode, mode_param, "skip_can_close") end
		end
	end)
	
	local res = dialog:Wait()
	if res == "ok" then
		NetSyncEvent("CancelSatelliteCountdown", mode, netUniqueId)
	end
end

---
--- Cancels the satellite countdown when a player cancels the transition to or from the satellite view.
---
--- @param mode string The mode of the satellite view transition, either "open" or "close".
--- @param player_id string The unique identifier of the player who cancelled the transition.
---
function NetSyncEvents.CancelSatelliteCountdown(mode, player_id)
	lCloseSatelliteCountdowns()
	if mode == "open" then
		if player_id == netUniqueId then
			CombatLog("debug", T(Untranslated("Cancelled the transition to Sat View.")))
		else
			CombatLog("debug", T(Untranslated("<OtherPlayerName()> cancelled the transition to Sat View.")))
		end
	else
		if player_id == netUniqueId then
			CombatLog("debug", T(Untranslated("Cancelled the transition from Sat View.")))
		else
			CombatLog("debug", T(Untranslated("<OtherPlayerName()> cancelled the transition from Sat View.")))
		end
	end
end

---
--- Returns a list of sector IDs that belong to the specified city.
---
--- @param city string The name of the city.
--- @return table A table of sector IDs that belong to the specified city.
---
function GetCitySectors(city)
	if not g_CitySectors then
		g_CitySectors = {}
		for id, sector in pairs(gv_Sectors) do
			local c = sector.City
			if c and c ~= "none" then
				g_CitySectors[c] = g_CitySectors[c] or {}
				table.insert(g_CitySectors[c], id)
			end
		end
	end
	return g_CitySectors[city]
end

if false then

---
--- Runs a test for the Satellite View functionality.
---
--- This test creates a new campaign, forces a conflict in the current sector, opens the Satellite View, creates a new satellite squad, sets routes for the squads, saves and loads the game, and then closes the Satellite View.
---
--- @function GameTests.SatelliteView
--- @return nil
function GameTests.SatelliteView()
	CreateRealTimeThread(function()
		QuickStartCampaign()
		gv_Sectors[gv_CurrentSectorId].ForceConflict = true
		ResolveConflict()
		
		Game.CampaignTimeFactor = 20
		Game.Campaign = DefaultCampaign
		OpenSatelliteView()
	end)
	WaitMsg("InitSatelliteView")
	
	CreateNewSatelliteSquad({Side = "player1", CurrentSector = "H11", Name = SquadName:GetNewSquadName("player1")}, { "Caesar", "Cass", "Cliff" }, 7)
	
	for _, s in ipairs(g_SquadsArray) do
		local route = GenerateRouteDijkstra(s.CurrentSector, "H10", s.route, s.units, nil, nil, squad.Side)
		if route then
			SetSatelliteSquadRoute(s, { route })
		end
	end
	
	Sleep(const.Scale.h/4)
	
	TestSaveLoadGame()
	
	for _, s in ipairs(g_SquadsArray) do
		local route = GenerateRouteDijkstra(s.CurrentSector, "J15", s.route, s.units, nil, nil, squad.Side)
		if route then
			SetSatelliteSquadRoute(s, { route })
		end
	end
	
	Sleep(const.Scale.h/4)
	CloseSatelliteView(true)
	CloseDialog("InGameInterface")
	DoneGame()
end

end

function OnMsg.NewDay()
	CreateMapRealTimeThread(function()
		RequestAutosave{ autosave_id = "newDay", save_state = "NewDay", display_name = T{829706997018, "Day_<day>_<month()>", day = TFormat.day()}, mode = "delayed" }
	end)
	
	local mercs = CountPlayerMercsInSquads(false, "include_imp")
	CombatLog("important", T{102190343056, "The date is <day()> <month()> - You have <mercs_amount> Merc(s) and <money(money_value)>",mercs_amount = mercs, money_value = Game.Money})
	ObjModified("day_display")
end

function OnMsg.LoadSessionData()
	if gv_SatelliteView and not IsCampaignPaused() then
		PauseCampaignTime("UI")
	end
end

----

---
--- Checks if the given sector has any allied squads or militia.
---
--- @param sector table The sector to check.
--- @return boolean True if the sector has any allied squads or militia, false otherwise.
---
function SectorPanelShowAlliedSection(sector)
	if not IsSectorRevealed(sector) then return false end
	local al, en = GetSquadsInSector(sector.Id, false, false)
	local anyAllies = next(al)
	local militiaSector = sector.Militia and (sector.Side=="player1" or sector.Side=="player2" or sector.Side=="ally")
	return anyAllies or militiaSector
end

---
--- Checks if the given sector has any enemy squads.
---
--- @param sector table The sector to check.
--- @return boolean True if the sector has any enemy squads, false otherwise.
---
function SectorPanelShowEnemySection(sector)
	if not IsSectorRevealed(sector) then return false end
	local al, en = GetSquadsInSector(sector.Id, false, true)
	return next(en)
end

---
--- Fixes sectors where the mine is tagged as depleted but the depletion time has not been reached.
---
--- This function is part of the `SavegameSessionDataFixups` module, which is responsible for fixing up
--- data in saved games when the game is loaded. It specifically targets sectors where the `mine_depleted`
--- flag is set, but the actual depletion time has not been reached.
---
--- @param sector_data table The sector data to be fixed up.
--- @param lua_revision number The current Lua revision of the game.
---
function SavegameSessionDataFixups.FixMinesTaggedAsDepleted(sector_data, lua_revision)
	local gvars = sector_data.gvars
	local sectors = gvars and gvars.gv_Sectors
	
	for id, sector in pairs(sectors) do
		if sector.Mine and sector.mine_depleted and sector.Depletion then
			local sectorDepletionTime = GetSectorDepletionTime(sector)
			if sector.mine_work_days < sectorDepletionTime + const.Satellite.MineDepletingDays then
				sector.mine_depleted = false
			end
		end
	end
end

function OnMsg.BobbyRayShopShipmentArrived(shipment)
	CombatLog("important", T{389474969879, "<em>Bobby Ray's</em> shipment arrived in the sector stash of <em><SectorName(sector_id)></em>, accessible through the Sat View.", order_id = Untranslated(shipment.order_id), sector_id = shipment.sector_id})
end