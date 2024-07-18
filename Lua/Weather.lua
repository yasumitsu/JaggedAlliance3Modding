--[[

Weather System

Weather
	a map state affecting gameplay, visuals, etc.

Time-of-day, or tod
	a map state affecting gameplay, visuals, etc, derived from the campaign time; tods are Sunrise, Day, Sunset, Night, controlled by constants in const.Satellite

Region
	overall map environment, e.g. Jungle or Savanna; it specified in the mapdata, because it's tightly connected to what is on the map
	regions have either "Dry" or "Wet" weather cycles

Weather Zone
	a set of sectors which change weather together; specified in the sector data
	all sectors with regions of the Dry weather cycle in the same zone are in the same Weather at any moment

Map state algorithm for entering a given sector at a given time:
	- look up sector's weather zone
	- look up sector's map's region
	- calculate weather from (campaign time, weather zone, region wet/dry)
	- calculate time-of-day from campaign time
	- choose a lightmode by matching (region, weather, time-of-day) against LightmodelSelectionRules
	- set region, weather, time-of-day as map states
]]

WeatherCycle = {
	Wet = {
		{ "ClearSky",  100, 24, 72 },
		{ "RainLight", 100, 12, 36 },
		{ "RainHeavy",  50, 12, 36 },
		{ "Fog",        75, 12, 36 },
	},
	Dry = {
		{ "ClearSky",  100, 24, 72 },
		{ "FireStorm",  50, 24, 48 },
		{ "DustStorm",  75, 12, 36 },
		{ "Heat",      100, 24, 48 },
	},
	CursedForest = {		
		{ "RainLight", 100, 12, 36 },
		{ "Fog",        50, 12, 24 },
	},
}

WeatherCycle_UnderTheWeather = {
	Wet = {
		{ "RainLight", 100, 24, 72 },
		{ "RainHeavy",  75, 12, 72 },
		{ "Fog",        75, 12, 72 },
		{ "ClearSky",   50, 12, 36 },
	},
	Dry = {
		{ "FireStorm",  50, 24, 72 },
		{ "DustStorm", 100, 24, 72 },
		{ "Heat",      100, 24, 48 },
		{ "ClearSky",   50, 12, 36 },
	},
	CursedForest = {		
		{ "RainLight", 100, 12, 36 },
		{ "Fog",        50, 12, 24 },
	},
}

--- Returns the current weather cycle based on the active game rule.
---
--- If the "UnderTheWeather" game rule is active, the "WeatherCycle_UnderTheWeather" table is returned.
--- Otherwise, the "WeatherCycle" table is returned.
---
--- @return table The current weather cycle table.
function GetCurrentWeatherCycle()
	if IsGameRuleActive("UnderTheWeather") then
		return WeatherCycle_UnderTheWeather
	else
		return WeatherCycle
	end
end

GameVar("g_vGameStateDefSounds", false)

AppendClass.GameStateDef = {
	properties = {
		{category = "Sound & Custom Effects", id = "GlobalSoundBankActivation", name = "Global Sound on Activation", 
			editor = "preset_id", default = false, preset_class = "SoundPreset"},
		{category = "Sound & Custom Effects", id = "CodeOnActivate", name = "Code on Activation",
			editor = "func", params = "self, ...", no_edit = function(self) return not self.GlobalSoundBankActivation end},
		{category = "Sound & Custom Effects", id = "CodeOnDeactivate", name = "Code on Deactivation",
			editor = "func", params = "self, ...", no_edit = function(self) return not self.GlobalSoundBankActivation end},
		{category = "Sound & Custom Effects", id = "CodeCustom", name = "Custom Code", default = empty_func,
			editor = "func", params = "self, ...", no_edit = function(self) return not self.GlobalSoundBankActivation end},
	},
	
	global_sound_bank = false,
	thread = false
}

--- Plays a global sound effect when the GameStateDef is activated.
---
--- This function is called when the GameStateDef is activated. It creates a new real-time thread that waits for the loading screen to close, then plays the global sound effect specified by the `GlobalSoundBankActivation` property of the GameStateDef. The sound is played at full volume and will fade out over 3 seconds. The sound handle is stored in the `g_vGameStateDefSounds` table so that it can be stopped later when the GameStateDef is deactivated.
---
--- @return nil
function GameStateDef:PlayGlobalSound()
	if not self.GlobalSoundBankActivation then return end

	DeleteThread(self.thread)
	self.thread = CreateMapRealTimeThread(function()
		WaitLoadingScreenClose()
		local sound = self.GlobalSoundBankActivation
		local handle = PlaySound(sound, nil, 100, 3000)
		if handle then
			local duration = GetSoundDuration(handle)
			g_vGameStateDefSounds = g_vGameStateDefSounds or {}
			g_vGameStateDefSounds[self.id] = g_vGameStateDefSounds[self.id] or {}	
			g_vGameStateDefSounds[self.id][handle] = sound
			DbgMusicPrint(string.format("Playing %s for %dms, Handle: %d", sound, duration, handle))
		end
	end)
end

--- Stops any global sound effects that were played when the GameStateDef was activated.
---
--- This function is called when the GameStateDef is deactivated. It stops any sound handles that were stored in the `g_vGameStateDefSounds` table when the `PlayGlobalSound()` function was called. The sound volume is faded out over 3 seconds before the sound is stopped.
---
--- @return nil
function GameStateDef:StopSounds()
	DeleteThread(self.thread)
	if g_vGameStateDefSounds and g_vGameStateDefSounds[self.id] then
		for handle, sound in pairs(g_vGameStateDefSounds[self.id]) do
			SetSoundVolume(handle, 0, 3000)
			if type(sound) == "boolean" then
				DbgMusicPrint(string.format("Stopping Handle: %d", handle))
			else
				DbgMusicPrint(string.format("Stopping %s, Handle: %d", sound, handle))
			end
		end
		g_vGameStateDefSounds[self.id] = nil
	end
end

--- Plays a global sound effect when the GameStateDef is activated.
---
--- This function is called when the GameStateDef is activated. It creates a new real-time thread that waits for the loading screen to close, then plays the global sound effect specified by the `GlobalSoundBankActivation` property of the GameStateDef. The sound is played at full volume and will fade out over 3 seconds. The sound handle is stored in the `g_vGameStateDefSounds` table so that it can be stopped later when the GameStateDef is deactivated.
---
--- @return nil
function GameStateDef:CodeOnActivate()
	self:PlayGlobalSound()
end

--- Stops any global sound effects that were played when the GameStateDef was activated.
---
--- This function is called when the GameStateDef is deactivated. It stops any sound handles that were stored in the `g_vGameStateDefSounds` table when the `PlayGlobalSound()` function was called. The sound volume is faded out over 3 seconds before the sound is stopped.
---
--- @return nil
function GameStateDef:CodeOnDeactivate()
	self:StopSounds()
end

function OnMsg.GameStateChanged(changed)
	if not GameStateDefs or not next(GameStateDefs) then return end
	
	for state, set in sorted_pairs(changed) do
		if not set then
			local def = GameStateDefs[state]
			if def then
				def:CodeOnDeactivate()
			end
		end
	end
	for state, set in sorted_pairs(changed) do
		if set then
			local def = GameStateDefs[state]
			if def then
				def:CodeOnActivate()
			end
		end
	end
	if changed.Combat and GameState.RainHeavy then
		local rain_heavy = GameStateDefs["RainHeavy"]
		if rain_heavy then
			rain_heavy:CodeCustom()
		end
	end
	if changed.entered_sector == false then
		if GameState["RainHeavy"] then
			GameStateDefs["RainHeavy"]:CodeOnDeactivate()
		end
		if GameState["RainLight"] then
			GameStateDefs["RainLight"]:CodeOnDeactivate()
		end
	end
end

function OnMsg.SlabsDoneLoading()
	CreateVfxControllersForAllRoomsOnMap()
end

---
--- Calculates the weather for a given sector based on the weather cycle and time since the campaign started.
---
--- @param weather_cycle string The name of the weather cycle to use
--- @param weather_zone string The name of the weather zone for the sector
--- @param time number The time since the campaign started, in hours
--- @return string The current weather for the sector
---
function CalculateWeatherForSector(weather_cycle, weather_zone, time)
	local hours = time / const.Scale.h -- since campaign start
	local cycle = GetCurrentWeatherCycle()[weather_cycle]
	local wrand = BraidRandomCreate(Game.id, weather_zone)
	local h = 0
	while true do
		for i, w in ipairs(cycle) do 
			if wrand(100) < w[2] then
				h = h + wrand(w[3], w[4])
				if hours < h then return w[1] end
			end
		end
	end
end

if FirstLoad then
	g_WeatherZones = false
end

---
--- Retrieves a list of weather zones for a given campaign.
---
--- If the weather zones for the campaign have already been calculated and stored, this function will return the stored list.
--- Otherwise, it will calculate the weather zones by iterating through all campaign presets and extracting the weather zones used by the sectors in each preset.
---
--- @param campaign table The campaign object for which to retrieve the weather zones.
--- @return table A table of weather zone names used in the campaign.
---
function WeatherZoneCombo(campaign)
	if g_WeatherZones and g_WeatherZones[campaign.id] then return g_WeatherZones[campaign.id] end
	
	g_WeatherZones = {}
	ForEachPreset("CampaignPreset", function(campaignPreset)
		if not g_WeatherZones[campaignPreset.id] then
			g_WeatherZones[campaignPreset.id] = {}
		end
		table.insert_unique(g_WeatherZones[campaignPreset.id], "Default")
		for _, sector in ipairs(campaignPreset.Sectors) do
			table.insert_unique(g_WeatherZones[campaignPreset.id], sector.WeatherZone)
		end
	end)
	return g_WeatherZones[campaign.id]
end

---
--- Retrieves the current weather for the specified sector.
---
--- If the `g_TestCombat.Weather` variable is set to a non-default value, that value is returned.
--- Otherwise, the weather is calculated based on the sector's weather zone and the time since the campaign started.
---
--- @param sector_id string|nil The ID of the sector to get the weather for. If not provided, the current sector ID is used.
--- @return string The current weather for the sector.
---
function GetCurrentSectorWeather(sector_id)
	if g_TestCombat and g_TestCombat.Weather ~= "Default" then
		return g_TestCombat.Weather
	end
	
	local sector = gv_Sectors[sector_id or gv_CurrentSectorId]
	local mapData = sector and MapData[sector.Map]
	if not sector or not mapData then
		return "ClearSky"
	end
	
	local region = mapData.Region
	local weather_cycle = GameStateDefs[region] and GameStateDefs[region].WeatherCycle
	if not weather_cycle then
		return 
	end
	local time_since_start = 0
	if Game and Game.Campaign and Game.CampaignTime and Game.CampaignTimeStart then
		time_since_start = Game.CampaignTime - Game.CampaignTimeStart
	end
	return CalculateWeatherForSector(weather_cycle, sector.WeatherZone, time_since_start)
end

---
--- Calculates the current time of day based on the given time.
---
--- @param time number The current time, in seconds since the start of the campaign.
--- @return string The current time of day, one of "Night", "Sunrise", "Sunset", or "Day".
---
function CalculateTimeOfDay(time)
	local hour_in_day = (time % const.Scale.day) / const.Scale.h
	local cs = const.Satellite
	if hour_in_day < cs.SunriseStartHour or hour_in_day >= cs.NightStartHour then
		return "Night"
	elseif hour_in_day >= cs.SunriseStartHour and hour_in_day < cs.DayStartHour then
		return "Sunrise"
	elseif hour_in_day >= cs.SunsetStartHour and hour_in_day < cs.NightStartHour then
		return "Sunset"
	else
		return "Day"
	end
end

---
--- Calculates the time of day based on the given time of day string.
---
--- @param timeOfDay string The time of day, one of "Night", "Sunrise", "Sunset", "Day", or "Any".
--- @return number The time of day in seconds since the start of the day.
---
function CalculateTimeFromTimeOfDay(timeOfDay)
	local cs = const.Satellite
	local halfHour = 1 * const.Scale.h / 2
	if timeOfDay == "Night" then
		return cs.NightStartHour * const.Scale.h + halfHour
	elseif timeOfDay == "Sunrise" then
		return cs.SunriseStartHour * const.Scale.h + halfHour
	elseif timeOfDay == "Sunset" then
		return cs.SunsetStartHour * const.Scale.h + halfHour
	elseif timeOfDay == "Day" then
		return cs.DayStartHour * const.Scale.h + halfHour
	elseif timeOfDay == "Any" then
		return InteractionRand(const.Scale.day, "Satellite")
	end
end

GameVar("gv_ForceWeatherTodRegion", false)

---
--- Chooses the appropriate lightmodel based on the current time of day, weather, and region.
---
--- @param self MapDataPreset The map data preset object.
--- @return string The selected lightmodel.
---
function MapDataPreset:ChooseLightmodel()
	local tod = self.Tod
	if tod == "none" then
		if Game and Game.Campaign and Game.CampaignTime then
			tod = CalculateTimeOfDay(Game.CampaignTime)
		else
			tod = "Day"
		end
	end
	
	local region = self.Region
	local weather = self.Weather
	if weather == "none" then
		if	gv_Sectors and 
			gv_CurrentSectorId and 
			gv_Sectors[gv_CurrentSectorId] and 
			gv_Sectors[gv_CurrentSectorId].Map == self.id 
		then
			weather = GetCurrentSectorWeather()
		else
			weather = "ClearSky"
		end
	end
	
	if weather == "Heat" and tod == "Night" then
		weather = "ClearSky"
	end
	
	if gv_ForceWeatherTodRegion then
		tod = gv_ForceWeatherTodRegion.tod ~= "any" and gv_ForceWeatherTodRegion.tod or tod
		weather = gv_ForceWeatherTodRegion.weather ~= "any" and gv_ForceWeatherTodRegion.weather or weather
		region = gv_ForceWeatherTodRegion.region ~= "any" and gv_ForceWeatherTodRegion.region or region
	end
	
	if weather then
		ChangeGameState{ [weather] = true, [tod] = true, [region] = true }
	else
		ChangeGameState{ [tod] = true, [region] = true }
	end
	return self.Lightmodel or SelectLightmodel(region, weather, tod)
end

---
--- Fixes up the campaign time start in the savegame data.
---
--- @param data table The savegame data.
--- @param metadata table The savegame metadata.
--- @param lua_revision number The Lua revision.
---
function SavegameSessionDataFixups.CampaignTimeStart(data, metadata, lua_revision)
	if not data.game.CampaignTimeStart then
		local campaign = CampaignPresets[data.game.Campaign]
		data.game.CampaignTimeStart = campaign.starting_timestamp
	end
end

function OnMsg.AfterLightmodelChange(view, lightmodel, time, prev_lm, from_override)
	if from_override then return end
	if prev_lm and prev_lm.id == lightmodel.id then return end
	if FindGedApp("PresetEditor", "LightmodelSelectionRule") then return end
	
	local force_map_states = (LightmodelOverride and FindGedApp("LightmodelEditor")) or IsCameraEditorOpened()
	local in_editor = IsEditorActive()
	if force_map_states or (not in_editor) or (in_editor and lightmodel.id == mapdata.EditorLightmodel) then
		local map_states = { 
			Night = false, Sunrise = false, Day = false, Sunset = false, Rain = false,
			ClearSky = false, DustStorm = false, FireStorm = false,
			Fog = false, Heat = false, RainHeavy = false, RainLight = false,
		}
		local lightmodel_id = lightmodel.id:lower()
		if lightmodel_id:find("sunrise") then
			map_states.Sunrise = true
		elseif lightmodel_id:find("sunset") then
			map_states.Sunset = true
		elseif lightmodel.night then
			map_states.Night = true
		else
			map_states.Day = true
		end
		if lightmodel_id:find("rainstorm") then
			map_states.RainHeavy = true
		elseif lightmodel_id:find("rain") then
			map_states.RainLight = true
		elseif lightmodel_id:find("duststorm") then
			map_states.DustStorm = true
		elseif lightmodel_id:find("firestorm") then
			map_states.FireStorm = true
		elseif lightmodel_id:find("fog") or lightmodel_id:find("mist") then
			map_states.Fog = true
		elseif lightmodel_id:find("heat") then
			map_states.Heat = true
		else
			map_states.ClearSky = true
		end
		
		ChangeGameState(map_states)
		CreateGameTimeThread( function()
			C_CCMT_Reset()
			SuspendPassEdits("rebuild autoattaches")
			PauseInfiniteLoopDetection("rebuild autoattaches")
			MapForEach("map", "AutoAttachObject", function(o) 
				o:SetAutoAttachMode(o.auto_attach_mode) 
			end) 
			ResumeInfiniteLoopDetection("rebuild autoattaches")
			ResumePassEdits("rebuild autoattaches")
		end)
	end
end

---
--- Returns the region for the current lightmodel.
---
--- If the lightmodel is found in the `LightmodelSelectionRules` table, the corresponding region is returned.
--- Otherwise, it returns the `mapdata.Region` or the `CurrentLightmodel[1].group` if the region is not found.
---
--- @return string The region for the current lightmodel
function GetLightModelRegion()
	local region
	for _, data in pairs(LightmodelSelectionRules) do 
		if data.lightmodel==CurrentLightmodel[1].id then 
			region = data.region
			break
		end 
	end
	return region or mapdata.Region or CurrentLightmodel[1].group
end

---
--- Returns a table of weather and time of day combinations for the current region.
---
--- The weather and time of day combinations are retrieved from the `GameStateDefs` table for the current region's `WeatherCycle`. Each combination is represented as a table with `weather` and `tod` fields.
---
--- @return table A table of weather and time of day combinations
function GetCheatsWeatherTOD()
	local weather_cycle = GameStateDefs[mapdata.Region] and GameStateDefs[mapdata.Region].WeatherCycle or "Dry"
	local weathers = GetCurrentWeatherCycle()[weather_cycle]
	local tods = Presets.GameStateDef["time of day"]
	local weather_tods = {}
	for _, weather in ipairs(weathers) do
		for _, tod in ipairs(tods) do
			table.insert(weather_tods, {weather = weather[1], tod = tod.id})
		end
	end
	
	return weather_tods
end

---
--- Triggers a heavy rain weather state.
---
--- This function is used to change the game state to a heavy rain weather condition.
---
--- @function NetSyncEvents.TestRainHeavy
--- @return nil
function NetSyncEvents.TestRainHeavy()
	ChangeGameState{["RainHeavy"] = true}
end

---
--- Triggers a change in the game state to a specific weather and time of day combination.
---
--- This function is used to change the game state to a specific weather and time of day combination. It selects the appropriate lightmodel for the given region, weather, and time of day, and then updates the game state accordingly.
---
--- @param weather_tod table A table with `weather` and `tod` fields, representing the desired weather and time of day combination.
--- @return nil
function NetSyncEvents.CheatWeatherTOD(weather_tod)
	local region, weather, tod = mapdata.Region, weather_tod.weather, weather_tod.tod
	local lightmodel = SelectLightmodel(region, weather, tod)
	ChangeGameState{[weather] = true, [tod] = true, [region] = true}
	SetLightmodel(1, lightmodel, 0)
end