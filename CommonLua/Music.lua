if FirstLoad or ReloadForDlc then
	Playlists = {
		Default = {},
		[""] = {},
	}
end

DefaultMusicCrossfadeTime = rawget(_G, "DefaultMusicCrossfadeTime") or 1000
DefaultMusicSilenceDuration = rawget(_G, "DefaultMusicSilenceDuration") or 1*60*1000

config.DebugMusicTracks = false

--- Prints a message to the console if the `config.DebugMusicTracks` flag is set to `true`.
---
--- @param ... any The message to print.
function DbgMusicPrint(...)
	if config.DebugMusicTracks then
		print(...)
	end
end

---
--- Adds tracks from a specified folder to a playlist.
---
--- @param playlist table The playlist to add the tracks to.
--- @param folder string The folder to search for tracks.
--- @param mode string (optional) The mode to use when listing files. Defaults to "non recursive".
--- @return table The updated playlist.
function PlaylistAddTracks(playlist, folder, mode)
	local tracks = io.listfiles(folder, "*", mode or "non recursive")
	for i = 1, #tracks do
		local path = string.match(tracks[i], "(.*)%..+")
		if path then 
			table.insert(playlist, { path = path, frequency = 100 })
		end
	end
	return playlist
end

---
--- Creates a new playlist by adding tracks from the specified folder.
---
--- @param folder string The folder to search for tracks.
--- @param mode string (optional) The mode to use when listing files. Defaults to "non recursive".
--- @return table The created playlist.
function PlaylistCreate(folder, mode)
	local playlist = {}
	PlaylistAddTracks(playlist, folder, mode)
	return playlist
end	

---
--- Represents a music player class that manages a playlist, blacklist, and playback of music tracks.
---
--- @class MusicClass
--- @field sound_handle boolean The handle of the currently playing sound.
--- @field sound_duration number The duration of the currently playing sound.
--- @field sound_start_time number The start time of the currently playing sound.
--- @field MusicThread boolean The thread that updates the music playback.
--- @field Playlist string The current playlist.
--- @field Blacklist table The blacklist of tracks that should not be played.
--- @field Track boolean The currently playing track.
--- @field Volume number The volume of the music playback.
--- @field TracksPlayed number The number of tracks that have been played.
--- @field fadeout_thread boolean The thread that handles the volume fadeout.
---
--- @function Init
---   Initializes the music player by creating a real-time thread that continuously updates the music playback.
---
--- @function SetPlaylist
---   Sets the current playlist and optionally plays a new track.
---   @param playlist table The playlist to set.
---   @param fade boolean Whether to fade the new track in.
---   @param force boolean Whether to force a new track to be played.
---
--- @function SetBlacklist
---   Sets the blacklist of tracks that should not be played.
---   @param blacklist table The blacklist of tracks.
---
--- @function UpdateMusic
---   Updates the music playback by checking if the current track has ended and playing a new track if necessary.
---
--- @function ChooseTrack
---   Chooses a random track from the current playlist, excluding the specified track and any tracks in the blacklist.
---   @param list table The playlist to choose a track from.
---   @param ignore table The track to exclude from the selection.
---   @return table The chosen track.
---
--- @function ChooseNextTrack
---   Chooses the next track in the current playlist, excluding any tracks in the blacklist.
---   @param list table The playlist to choose a track from.
---   @return table The chosen track.
---
--- @function PlayNextTrack
---   Plays the next track in the current playlist.
---
--- @function IsTrackRestricted
---   Checks if the specified track is restricted.
---   @param track table The track to check.
---   @return boolean Whether the track is restricted.
---
--- @function PlayTrack
---   Plays the specified track, optionally fading it in.
---   @param track table The track to play.
---   @param fade boolean Whether to fade the track in.
---   @param time_offset number The time offset to start the track at.
---
--- @function RemainingTrackTime
---   Gets the remaining time of the currently playing track.
---   @return number The remaining time of the currently playing track.
---
--- @function StopTrack
---   Stops the currently playing track, optionally fading it out.
---   @param fade boolean Whether to fade the track out.
---
--- @function SetVolume
---   Sets the volume of the music playback.
---   @param volume number The new volume.
---   @param time number The time to fade the volume change in.
---
--- @function GetVolume
---   Gets the current volume of the music playback.
---   @return number The current volume.
---
--- @function FadeOutVolume
---   Fades out the volume of the music playback.
---   @param fadeout_volume number The volume to fade out to.
---   @param fadeout_time number The time to fade out the volume.
---
DefineClass.MusicClass =
{
	__parents = { "InitDone" },

	sound_handle = false,
	sound_duration = -1,
	sound_start_time = -1,
	MusicThread = false,
	Playlist = "",
	Blacklist = empty_table,
	Track = false,
	Volume = 1000,
	TracksPlayed = 0,
	fadeout_thread = false,
	
	Init = function(self)
		self.MusicThread = CreateRealTimeThread(function()
			while true do
				self:UpdateMusic()
			end
		end)
	end,
	
	SetPlaylist = function(self, playlist, fade, force)
		local old = self.Playlist
		self.Playlist = playlist or nil
		if force or old ~= self.Playlist then
			self:PlayTrack(self:ChooseTrack(self.Playlist, self.Track), fade)
			ObjModified(self)
		end
	end,
	
	SetBlacklist = function(self, blacklist)
		local map = {}
		for i=1,#(blacklist or "") do
			map[blacklist[i]] = true
		end
		self.Blacklist = map
	end,

	UpdateMusic = function(self)
		Sleep(1000)
		
		if IsSoundPlaying(self.sound_handle) or (self.Track and self.Track.empty and self:RemainingTrackTime() > 0) then
			return
		end
		
		local oldTracksPlayed = self.TracksPlayed 
		local track = self.Track
		if track then
			local playlist = Playlists[self.Playlist]
			local duration = track.SilenceDuration or (playlist and playlist.SilenceDuration) or DefaultMusicSilenceDuration
			Msg("MusicTrackEnded", self.Playlist, self.Track)
			if oldTracksPlayed == self.TracksPlayed then
				WaitWakeup(duration)
			end
		end
		
		if oldTracksPlayed == self.TracksPlayed then
			self:PlayTrack(self:ChooseTrack(self.Playlist, track), true)
		end
	end,

	ChooseTrack = function(self, list, ignore)
		list = list and Playlists[list] or Playlists[self.Playlist]
		if type(list) ~= "table" then
			return
		end
		if list.mode == "list" then
			return self:ChooseNextTrack(list)
		end
		local total = 0
		for i = 1, #list do
			local track = list[i]
			if track ~= ignore and not self.Blacklist[track.path] then
				total = total + track.frequency
			end
		end
		if total == 0 then return list[1] end
		local rand = AsyncRand(total)
		for i = 1, #list do
			local track = list[i]
			if track ~= ignore and not self.Blacklist[track.path] then
				rand = rand - track.frequency
				if rand < 0 then
					return list[i] 
				end
			end
		end
	end,
	
	ChooseNextTrack = function(self, list)
		assert(#list > 0)
		if #list == 0 then
			return
		end
		local start_idx = table.find(list, "path", self.Track and self.Track.path) or #list
		local idx = start_idx
		while true do
			idx = idx + 1
			if idx > #list then
				idx = 1
			end
			if idx == start_idx then
				return
			end
			local track = list[idx]
			assert(track)
			if track and not self.Blacklist[track.path] then
				return track
			end
		end
	end,

	PlayNextTrack = function(self)
		local list = Playlists[self.Playlist]
		if type(list) ~= "table" then
			return
		end
		local track = self:ChooseNextTrack(list)
		if track then
			self:PlayTrack(track, true)
		end
	end,

	IsTrackRestricted = function(self, track)
		return track.restricted
	end,

	PlayTrack = function(self, track, fade, time_offset)
		if fade == true or fade == nil then
			fade = track and track.crossfade or DefaultMusicCrossfadeTime
		end
		self:StopTrack(fade)
		self.Track = nil
		Wakeup(self.MusicThread)
		if track then
			assert(not self.Blacklist[track.path])
			if track.empty then
				self.Track = track
				self.sound_handle = false
				self.sound_duration = track.duration
				self.sound_start_time = RealTime() - (time_offset or 0)
				self.TracksPlayed = self.TracksPlayed + 1
				DbgMusicPrint(string.format("playing silince for %dms from %s",  track.duration, self.Playlist))
			else
				local sound_type = self:IsTrackRestricted(track) and SoundTypePresets.MusicRestricted and "MusicRestricted" or "Music"
				local playlist = Playlists[self.Playlist]
				local volume = playlist and playlist.Volume or self.Volume
				local looping, loop_start, loop_end = track.looping, track.loop_start, track.loop_end
				local point_or_object, loud_distance
				local handle, err = PlaySound(
					track.path, sound_type, volume, fade or 0,
					looping, point_or_object, loud_distance,
					time_offset, loop_start, loop_end)
				if handle then
					self.Track = track
					DbgMusicPrint("playing", track, "from", self.Playlist, "Handle:", handle)
					self.sound_handle = handle
					self.sound_duration = GetSoundDuration(handle) or -1
					self.sound_start_time = RealTime() - (time_offset or 0)
					self.TracksPlayed = self.TracksPlayed + 1
					if playlist and playlist.FadeOutVolume then
						self:FadeOutVolume(playlist.FadeOutVolume, playlist.FadeOutTime)
					end
				end
			end
		end
	end,
	
	RemainingTrackTime = function(self)
		if self.Track.empty then
			return Max(self.sound_duration - (RealTime() - self.sound_start_time), 0)
		end
	
		if not self.sound_handle or self.sound_duration <= -1 or self.sound_start_time == -1 then
			return 0
		end
		local elapsed_time = RealTime() - self.sound_start_time
		assert(elapsed_time >= 0)
		return self.sound_duration - elapsed_time % self.sound_duration
	end,

	StopTrack = function(self, fade)
		if fade == true or fade == nil then
			fade = self.Track and self.Track.crossfade or DefaultMusicCrossfadeTime
		end
		if self.sound_handle then
			SetSoundVolume(self.sound_handle, -1, fade or 0)
		end
		self.sound_handle = false
		self.sound_duration = -1
		self.sound_start_time = -1
	end,

	SetVolume = function(self, volume, time)
		self.Volume = volume
		SetSoundVolume(self.sound_handle, volume, time)
	end,
	
	GetVolume = function(self)
		return self.Volume
	end,
	
	FadeOutVolume = function(self, fadeout_volume, fadeout_time)
		DeleteThread(self.fadeout_thread)
		self.fadeout_thread = CreateRealTimeThread(function(fadeout_volume, fadeout_time)
			Sleep(fadeout_time)
			SetSoundVolume(self.sound_handle, fadeout_volume, self.Track.crossfade or DefaultMusicCrossfadeTime)
			self.fadeout_thread = false
		end, fadeout_volume, fadeout_time)
	end,
}

if FirstLoad then
	Music = false
end
---
--- Sets the music playlist for the game.
---
--- @param playlist table The playlist to set. This should be a table of track paths.
--- @param fade boolean|nil Whether to fade the current track out when changing playlists. Defaults to true.
--- @param force boolean|nil Whether to force the playlist to change even if it's the same as the current one.
---

function SetMusicPlaylist(playlist, fade, force)
	Music = Music or MusicClass:new()
	Music:SetPlaylist(playlist, fade ~= false, force)
end

---
--- Sets the music blacklist for the game.
---
--- @param blacklist table The blacklist to set. This should be a table of track paths to exclude from the playlist.
---
function SetMusicBlacklist(blacklist)
	Music = Music or MusicClass:new()
	Music:SetBlacklist(blacklist)
end

---
--- Returns the current music playlist.
---
--- @return table|nil The current music playlist, or nil if no playlist is set.
---
function GetMusicPlaylist()
	return Music and Music.Playlist
end

---
--- Plays a music track with an optional fade effect.
---
--- @param track string The path of the music track to play.
--- @param fade boolean|nil Whether to fade the current track out when playing the new track. Defaults to true.
---
function MusicPlayTrack(track, fade)
	Music = Music or MusicClass:new()
	Music:PlayTrack(track, fade)
end

---
--- Returns a sorted list of the names of all playlists defined in the `Playlists` table.
---
--- @return table A sorted table of playlist names.
---
function PlaylistComboItems()
	local items = {}
	for name, v in pairs(Playlists) do
		if type(v) == "table" then
			items[#items + 1] = name
		end
	end
	table.sort(items)
	return items
end

---
--- Returns a sorted list of all unique track paths in the given playlists.
---
--- @param playlist table|nil The playlist(s) to get the track paths from. If nil, all playlists in the `Playlists` table will be used.
--- @return table A sorted table of unique track paths.
---
function PlaylistTracksCombo(playlist)
	playlist = playlist and {playlist} or Playlists
	
	local tracks = {}
	for name, list in pairs(playlist) do
		if type(list) == "table" then
			for i=1,#list do
				tracks[list[i].path] = true
			end
		end
	end
	return table.keys(tracks, true)
end