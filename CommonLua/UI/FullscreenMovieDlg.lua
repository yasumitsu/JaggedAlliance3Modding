-- Movie-playing dialog
--
-- To use: OpenSubtitledMovieDlg( { filename = "movie", fade_in = 1000, subtitles = subs_table, ... })
--
-- Optional in the place on the ellipsis:
--   text_style = [string], default is UISubtitles
--
-- Subtitle format:
--   subs_table = {
--	    { start_time =  4000, duration = 11000, text = T{"Almighty-sounding text number one"} },
--	    { start_time = 16000, duration = 5000 , text = T{"Even more inspiring text number two"} },
--     ...
--   }
--
-- Default movie subtitles in MovieSubtitles[language][movie] or MovieSubtitles.English[movie]

if FirstLoad then
	MovieSubtitles = { English = {} }
end

--- Gets the movie subtitles for the given movie.
---
--- If a language-specific subtitle table exists for the current voice language, it will be returned.
--- Otherwise, the English subtitle table will be returned.
---
--- @param movie string The name of the movie to get subtitles for.
--- @return table|nil The subtitle table for the given movie, or nil if no subtitles are available.
function GetMovieSubtitles(movie)
	local  lang1 = MovieSubtitles[GetVoiceLanguage() or ""]
	local  lang2 = MovieSubtitles.English
	return lang1 and lang1[movie] or lang2 and lang2[movie]
end

DefineClass.XFullscreenMovieDlg = {
	__parents = { "XDialog" }, 
	
	skippable = true,
	sound_type = "Voiceover",
	fade_in = false,
	fadeout_music = false,
	
	open_time = false,
	movie_path = false, 
	subtitles = false, 
	text_style = false,
}

---
--- Initializes a new XFullscreenMovieDlg instance.
---
--- @param parent table The parent dialog.
--- @param context table The context table containing configuration options for the dialog.
---   @field skippable boolean Whether the dialog is skippable.
---   @field sound_type string The sound type to use for the movie.
---   @field fade_in number The fade-in duration in milliseconds.
---   @field movie_path string The path to the movie file.
---   @field subtitles table The subtitle data for the movie.
---   @field fadeout_music boolean Whether to fade out the music when the movie starts.
---   @field text_style string The text style to use for the subtitles.
---
function XFullscreenMovieDlg:Init(parent, context)
	--assert(type(context) == "table")
	self.skippable = context.skippable or true
	self.sound_type = context.sound_type or "Voiceover"
	self.fade_in = context.fade_in
	
	self.movie_path = context.movie_path
	self.subtitles = context.subtitles
	self.fadeout_music = context.fadeout_music
	self.text_style = context.text_style
end

---
--- Opens a fullscreen movie dialog.
---
--- @param ... any Additional arguments passed to the parent `XDialog:Open()` method.
---
function XFullscreenMovieDlg:Open(...)
	XDialog.Open(self, ...)
	
	self.open_time = RealTime()
	if self.text_style then 
		self.idSubtitles:SetTextStyle(self.text_style)
	end

	if GetUIStyleGamepad(nil, self) then
		self.idSkipHint:SetText(T(576896503712, "<ButtonB> Skip"))
	else
		self.idSkipHint:SetText(T(696052205292, "<style SkipHint>Escape: Skip</style>")) -- no icon for Esc button
	end
	
	assert(self.movie_path)
	local sound_type = self.sound_type
	self.idVideoPlayer.FileName = self.movie_path
	self.idVideoPlayer.Sound = self.movie_path
	self.idVideoPlayer.SoundType = sound_type
	self.idVideoPlayer.Desaturate = const.MovieCorrectionDesaturation
	self.idVideoPlayer.Gamma = const.MovieCorrectionGamma
	self.idVideoPlayer.OnEnd = function()
		self:Close()
	end
	self:PlayMovie()
end

---
--- Stops the currently playing movie and restores the music volume.
---
--- If the `fadeout_music` flag is set, the music volume is faded back in over 300 milliseconds.
--- The subtitle text is cleared and the video player is stopped.
---
function XFullscreenMovieDlg:StopMovie()
	DeleteThread("FadePlayback")
	self.idSubtitles:SetText("")
	self.idVideoPlayer:Stop()
	if Music and self.fadeout_music then
		Music:SetVolume(1000, 300)
	end
end

---
--- Plays a fullscreen movie with optional subtitles.
---
--- If the `fadeout_music` flag is set, the music volume is faded out over 300 milliseconds before the movie starts playing.
--- The movie will start playing after the `fade_in` delay (if set).
--- If the `subtitles` table is provided, the subtitles will be displayed during the movie playback.
---
--- @param self XFullscreenMovieDlg The instance of the `XFullscreenMovieDlg` class.
function XFullscreenMovieDlg:PlayMovie()
	if self.fadeout_music and Music then
		Music:SetVolume(0, 300)
	end
	self:CreateThread("FadePlayback", function()
		if self.fade_in then
			Sleep(self.fade_in)
		end

		self.idVideoPlayer:Play();
		if self.subtitles then --and GetAccountStorageOptionValue("Subtitles") then
			local time_start = now() 
			for i = 1,#self.subtitles do
				local sub  = self.subtitles[i]
				local wait = time_start + sub.start_time - now()
				Sleep(wait)
				self.idSubtitles:SetText(sub.text)
				Sleep(sub.duration)
				self.idSubtitles:SetText("")
			end
		end
	end)
end

---
--- Handles keyboard shortcuts for the fullscreen movie dialog.
---
--- If the dialog has just been opened or the terminal has just been activated, the shortcut is ignored for 250 milliseconds to prevent accidental skipping.
---
--- If the dialog is skippable, the skip hint is shown when a shortcut is pressed. If the "Escape" or "ButtonB" shortcut is pressed, the dialog is closed.
---
--- @param self XFullscreenMovieDlg The instance of the `XFullscreenMovieDlg` class.
--- @param shortcut string The name of the shortcut that was pressed.
--- @param source string The source of the shortcut (e.g. "keyboard", "gamepad").
--- @param ... any Additional arguments passed with the shortcut.
--- @return string "break" to indicate that the shortcut has been handled and should not be processed further.
function XFullscreenMovieDlg:OnShortcut(shortcut, source, ...)
	if RealTime() - self.open_time < 250 then return "break" end
	if RealTime() - terminal.activate_time < 250 then return "break" end
	
	if self.skippable then
		if not self.idSkipHint:GetVisible() then
			self.idSkipHint:SetVisible(true)
		elseif shortcut == "Escape" or shortcut == "ButtonB" then
			self:Close()
		end
		return "break"
	end
end

---
--- Closes the fullscreen movie dialog.
---
--- This function stops the currently playing movie, resets the global `g_FullscreenMovieDlg` variable, and then calls the `Close()` function of the `XDialog` class to close the dialog.
---
--- @param self XFullscreenMovieDlg The instance of the `XFullscreenMovieDlg` class.
function XFullscreenMovieDlg:Close()
	self:StopMovie()
	g_FullscreenMovieDlg = false
	
	XDialog.Close(self)
end

MapVar("g_FullscreenMovieDlg", false)
---
--- Opens a fullscreen movie dialog with optional subtitles.
---
--- This function creates a new `XFullscreenMovieDlg` instance and sets its properties based on the provided `content` table. If `g_FullscreenMovieDlg` is already set, the function simply returns the existing instance.
---
--- @param content table An optional table containing the following properties:
---   - `movie_path` (string): The path to the movie file to be played.
---   - `skippable` (boolean): Whether the movie can be skipped by the user.
---   - `fade_in` (number): The duration of the fade-in effect in milliseconds.
---   - `subtitles` (table): A table of subtitle entries, where each entry has a `start_time`, `duration`, and `text` property.
---   - `fadeout_music` (boolean): Whether to fade out the music when the movie is played.
--- @return XFullscreenMovieDlg The instance of the `XFullscreenMovieDlg` class.
function OpenSubtitledMovieDlg(content)
	if not content then 
		content = {
			movie_path = "Movies/Haemimont", 
			skippable = true,
			fade_in = 250,
			subtitles = MovieSubtitles.English,
			fadeout_music = false,
	} end
	
	if not g_FullscreenMovieDlg then 
		g_FullscreenMovieDlg = OpenDialog("XFullscreenMovieDlg", terminal.desktop, content);
	end
	return g_FullscreenMovieDlg
end