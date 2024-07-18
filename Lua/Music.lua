if FirstLoad then
	g_PlaylistMood = false
end

---
--- Sets a music override for the specified sector and mood.
---
--- @param sector string The ID of the sector to set the override for.
--- @param mood string The mood to set the override for, such as "MusicCombat", "MusicConflict", or "MusicExploration".
--- @param playlist table|nil The playlist to use for the override, or nil to clear the override.
---
function SetSectorMusicOverride(sector, mood, playlist)
	g_PlaylistMood = g_PlaylistMood or {}
	g_PlaylistMood[sector] = g_PlaylistMood[sector] or {}
	g_PlaylistMood[sector][mood] = playlist or nil
end

---
--- Gets the music override for the specified mood in the current sector.
---
--- @param mood string The mood to get the override for, such as "MusicCombat", "MusicConflict", or "MusicExploration".
--- @return table|nil The playlist to use for the override, or nil if no override is set.
---
function GetSectorMusicOverride(mood)
	return g_PlaylistMood and g_PlaylistMood[gv_CurrentSectorId] and g_PlaylistMood[gv_CurrentSectorId][mood]
end

---
--- Gets the music playlist for the specified mood in the current sector.
---
--- @param mood string The mood to get the music playlist for, such as "MusicCombat", "MusicConflict", or "MusicExploration".
--- @return table|nil The music playlist for the specified mood, or nil if no playlist is set.
---
function GetSectorMusic(mood)
	return gv_Sectors and gv_Sectors[gv_CurrentSectorId] and gv_Sectors[gv_CurrentSectorId][mood]
end

---
--- Gets the music playlist for the "MusicCombat" mood in the current sector.
---
--- @return table|nil The music playlist for the "MusicCombat" mood, or nil if no playlist is set.
---
function GetSectorCombatStation()
	return GetSectorMusicOverride("MusicCombat") or GetSectorMusic("MusicCombat")
end

---
--- Gets the music override for the specified "MusicConflict" mood in the current sector.
---
--- @return table|nil The playlist to use for the "MusicConflict" override, or nil if no override is set.
---
function GetSectorConflictStation()
	return GetSectorMusicOverride("MusicConflict") or GetSectorMusic("MusicConflict")
end

---
--- Gets the music playlist for the "MusicExploration" mood in the current sector.
---
--- @return table|nil The music playlist for the "MusicExploration" mood, or nil if no playlist is set.
---
function GetSectorExplorationStation()
	return GetSectorMusicOverride("MusicExploration") or GetSectorMusic("MusicExploration")
end

---
--- Gets the appropriate radio station for the current game state.
---
--- @return table|nil The music playlist for the current game state, or nil if no playlist is set.
---
function GetSectorStation()
	if GameState.Combat then
		return GetSectorCombatStation()
	elseif GameState.Conflict then
		return GetSectorConflictStation()
	elseif GameState.Exploration then
		return GetSectorExplorationStation()
	end	
end

---
--- Resets the current sector's radio station based on the current game state.
---
--- If the game is in a combat state, the combat radio station is started.
--- If the game is in a conflict state, the conflict radio station is started.
--- If the game is in an exploration state, the exploration radio station is started.
---
--- @return boolean True if a radio station was successfully started, false otherwise.
---
function ResetSectorStation()
	if GameState.Combat then
		return StartRadioStation(GetSectorCombatStation(), nil, "force")
	elseif GameState.Conflict then
		return StartRadioStation(GetSectorConflictStation(), nil, "force")
	elseif GameState.Exploration then
		return StartRadioStation(GetSectorExplorationStation(), nil, "force")
	end	
end

---
--- Checks if the required radio station playlists are defined for the given sector.
---
--- This function checks if the "MusicCombat", "MusicConflict", and "MusicExploration" playlists
--- are defined for the given sector. If any of these playlists are missing, an error source
--- is stored for the sector.
---
--- @param sector table The sector to check for missing radio station playlists.
---
function CheckSectorRadioStations(sector)
	if not sector.MusicCombat then
		StoreErrorSource(sector, "Sector Radio Station playlist for Combat is missing")
	end
	if not sector.MusicConflict then
		StoreErrorSource(sector, "Sector Radio Station playlist for Conflict is missing")
	end
	if not sector.MusicCombat then
		StoreErrorSource(sector, "Sector Radio Station playlist for Exploration is missing")
	end
end

function OnMsg.PreGameMenuOpen()
	StartRadioStation("PreGameMenu", nil, "force")
end

function OnMsg.NewMapLoaded()
	if GetDialog("Intro") then
		SetMusicPlaylist()
	else
		SetMusicPlaylist("Radio")
	end
end

---
--- Starts the exploration radio station after a short delay.
---
--- This function is called when the game state transitions out of a combat state,
--- and the exploration radio station should be started after a short delay.
---
--- @return boolean True if the radio station was successfully started, false otherwise.
---
function StartExplorationRadioDelayed()
	StartRadioStation(GetSectorExplorationStation(), const.Radio.StartNewStationDelay)
end

function OnMsg.ConflictStart()
	if not (g_Combat or g_StartingCombat) then
		StartRadioStation(GetSectorConflictStation())
	end
end

OnMsg.ConflictEnd = StartExplorationRadioDelayed

function OnMsg.CombatStart()
	StartRadioStation(GetSectorCombatStation())
end

function OnMsg.CombatEnd()
	if GameState.Conflict then
		StartRadioStation(GetSectorConflictStation())
	else
		StartExplorationRadioDelayed()
	end
end

function OnMsg.EnterSector(game_start)
	StartRadioStation(GetSectorStation(), not game_start and const.Radio.StartNewStationDelay)
end

function OnMsg.OpenSatelliteView()
	if not GetDialog("Intro") then
		StartRadioStation("SatelliteRadio", const.Radio.StartNewStationDelay)
	end
end

function OnMsg.ClosePDA()
	StartRadioStation(GetSectorStation())
end

function OnMsg.IntroClosed()
	SetMusicPlaylist("Radio")
	StartRadioStation("SatelliteRadio")
end

function OnMsg.GameStateChanged(changed)
	local required_station = GetSectorStation() or false
	if required_station and ActiveRadioStation ~= required_station then
		StartRadioStation(required_station)
	end
end

---
--- Generates a playlist of radio tracks for the given radio station.
---
--- @param radio string The name of the radio station to generate the playlist for.
--- @return table, table The list of track paths, and the full playlist object.
---
function RadioPlaylistCombo(radio)
	local station = Presets.RadioStationPreset["Default"][radio]
	if not station then return end
	
	local playlist = PlaylistCreate(station.Folder)
	
	local tracks = {}
	for _, track in ipairs(playlist) do
		table.insert(tracks, track.path)
	end
	
	return tracks, playlist
end

AppendClass.RadioStationPreset = {
	properties = {
		{ category = "Zulu Specific", id = "Files", name = "Files", editor = "nested_list",
			default = false, base_class = "RadioPlaylistTrack",
		},
	},
}

---
--- Generates a playlist for a radio station based on the preset configuration.
---
--- @param self RadioStationPreset The radio station preset object.
--- @return table The generated playlist.
---
function RadioStationPreset:GetPlaylist()
	local playlist = PlaylistCreate(self.Folder)
	for _, entry in ipairs(self.Files) do
		table.insert(playlist, {
			path = entry.Track,
			frequency = entry.Frequency,
			empty = entry.EmptyTrack or nil,
			duration = entry.EmptyTrack and entry.Duration or nil,
		})
	end
	
	playlist.SilenceDuration = self.SilenceDuration
	playlist.Volume = self.Volume
	playlist.FadeOutTime = self.FadeOutTime
	playlist.FadeOutVolume = self.FadeOutVolume
	playlist.mode = self.Mode
	
	return playlist
end

---
--- Gathers music tracks used by a radio station preset.
---
--- @param radio string The ID of the radio station preset.
--- @param used_music table A table to store the used music tracks.
---
function GatherMusic(radio, used_music)
	local preset = FindPreset("RadioStationPreset", radio)
	for _, entry in ipairs(preset.Files) do
		used_music[entry.Track] = true
	end
end

function OnMsg.GatherMusic(used_music)
	for _, group in ipairs(Presets.CampaignPreset or empty_table) do
		for _, campaign in ipairs(group or empty_table) do
			for _, sector in ipairs(campaign.Sectors or empty_table) do
				if IsDemoSector(sector.id) then
					GatherMusic(sector.MusicExploration, used_music)
					GatherMusic(sector.MusicCombat, used_music)
					GatherMusic(sector.MusicConflict, used_music)
				end
			end
		end
	end
end
