if FirstLoad then
	Videos = {}
end

DefineClass.XVideo = {
	__parents = { "XControl" },
	[true] = false,
	soundHandle = false,
	properties = { 
		{category = "Video", id = "VideoDefId", editor = "preset_id", default = "", preset_class = "VideoDef" },
		{category = "Video", id = "FileName", editor = "text", default = "", read_only = true },
		{category = "Video", id = "Sound", editor = "text", default = "" },
		{category = "Video", id = "SoundType", editor = "preset_id", default = "Voiceover", preset_class = "SoundTypePreset", }, 
		{category = "Video", id = "Looping", editor = "bool", default = false },
		{category = "Video", id = "AutoPlay", editor = "bool", default = false },
		{category = "Video", id = "Desaturate", editor = "number", min = 0, max = 255,  default = 0 },
		{category = "Video", id = "Gamma", editor = "number", min = 100, max = 10000, default = 1000 }
	},
	
	resolution = false,
	state = "stopped",
}

video_print = CreatePrint{
	"video",
	format = "printf",
	output = DebugPrint,
}


---
--- Sets the video definition ID for this XVideo instance.
---
--- @param value string The ID of the video definition to use.
---
function XVideo:SetVideoDefId(value)
	if not value or value == "" then
		return
	end

	local video_def = VideoDefs[value]
	if not video_def then 
		video_print("Video not found in base or activated DLCs. %s", value)
		return
	end

	local ext
	if Platform.desktop then ext = "desktop" end
	if Platform.xbox_one then ext = "xbox_one" end
	if Platform.xbox_series then ext = "xbox_series" end
	if Platform.ps4 then ext = "ps4" end
	if Platform.ps5 then ext = "ps5" end
	if Platform.switch then ext = "switch" end
	assert(ext)
	if not ext then
		video_print("Video bad ext %s", value)
		return
	end

	local props = video_def:GetPropsForPlatform(ext)
	assert(props.present)
	if not props.present then
		video_print("Video not marked as present. %s", value)
		return
	end

	self.FileName = props.video_game_path or ""
	self.Sound = props.sound_game_path or ""
	self.resolution = props.resolution or point(1920, 1080)

	self.VideoDefId = value
end

---
--- Clears the video and stops any associated sound.
---
function XVideo:Done()
	self:ClearVideo()
end

---
--- Sets whether this XVideo instance should automatically play when loaded.
---
--- @param autoplay boolean Whether the video should automatically play when loaded.
---
function XVideo:SetAutoPlay(autoplay)
	self.AutoPlay = autoplay
	if autoplay then
		self:Play()
	else
		self:Stop()
	end
end

---
--- Starts playing the sound associated with this XVideo instance.
---
--- If the `Sound` property is not an empty string, this function will play the sound
--- using the `PlaySound` function and store the sound handle in the `soundHandle` property.
---
--- @function XVideo:SoundStart
--- @return nil
function XVideo:SoundStart()
	if (self.Sound or "") ~= "" then
		self.soundHandle = PlaySound(self.Sound, self.SoundType)
	end
end

---
--- Stops the sound associated with this XVideo instance.
---
--- This function is a temporary workaround, as pausing the sound channel is not yet implemented.
---
function XVideo:SoundPause()
	print( "pause per sound channel not implemented" )
	self:SoundStop()
end

---
--- Stops the sound associated with this XVideo instance.
---
--- This function stops the sound that was previously started using the `SoundStart()` function.
---
--- @function XVideo:SoundStop
--- @return nil
function XVideo:SoundStop()
	StopSound(self.soundHandle)
end

---
--- Sets the desaturation level of the video.
---
--- @param n number The desaturation level, between 0 (no desaturation) and 1 (full desaturation).
---
function XVideo:SetDesaturate(n)
	if not self[true] or self.Desaturate == n then return end
	self.Desaturate = n
	self:Invalidate()
end

---
--- Sets the gamma level of the video.
---
--- @param n number The gamma level, between 0 and 1.
---
function XVideo:SetGamma(n)
	if not self[true] or self.Gamma == n then return end
	self.Gamma = n
	self:Invalidate()
end

---
--- Called when the video playback has ended.
---
function XVideo:OnEnd()
end

---
--- Waits for a message to be received by the XVideo instance.
---
--- This function blocks the current thread until a message is received by the XVideo instance.
---
--- @function XVideo:Wait
--- @return nil
function XVideo:Wait()
	WaitMsg(self)
end

---
--- Starts the video playback and associated sound.
---
--- This function is called internally to start the video and sound playback. It should not be called directly.
---
--- @function XVideo:_DoStartPlay
--- @return nil
function XVideo:_DoStartPlay()
	UIL.videoPlay(self[true])
	self:SoundStart()
	self:Invalidate()
	self.state = "playing"
end

---
--- Starts the video playback and associated sound.
---
--- This function checks if a loading screen is currently active. If so, it waits for the loading screen to close before starting the video and sound playback. Otherwise, it immediately starts the video and sound playback.
---
--- @function XVideo:Play
--- @return string|nil An error message if the video failed to load, or nil if the playback started successfully.
function XVideo:Play()
	local err = self:LoadVideo()
	if err then return err end
	-- assuming that nobody wants to play videos under/on a loading screen
	-- if this turns out to be false, make it a property of the XVideo class and deal with the consequences
	-- (in our particular case, major hiccups during loading leading to audio dropouts)
	if GetGameBlockingLoadingScreen() then
		CreateRealTimeThread( function()
			WaitLoadingScreenClose()
			if self[true] and self.state ~= "playing" then
				return self:_DoStartPlay()
			end
		end )
		return
	end
	return self:_DoStartPlay()
end

---
--- Pauses the video playback and associated sound.
---
--- This function is called to pause the video and sound playback. It should not be called directly.
---
--- @function XVideo:Pause
--- @return nil
function XVideo:Pause()
	UIL.videoPause(self[true])
	self.state = "paused"
end

---
--- Stops the video playback and associated sound.
---
--- This function is called to stop the video and sound playback. It should not be called directly.
---
--- @function XVideo:Stop
--- @return nil
function XVideo:Stop()
	UIL.videoStop(self[true])
	self:SoundStop()
	self.state = "stopped"
end

---
--- Clears the video and stops any associated sound.
---
--- This function is used to clean up the video and sound resources associated with an XVideo instance. It destroys the video object, removes it from the global Videos table, and stops any associated sound.
---
--- @function XVideo:ClearVideo
--- @return nil
function XVideo:ClearVideo()
	local video = self[true]
	if video then
		UIL.videoDestroy(video)
		Videos[video] = nil
		self[true] = nil
		self.state = nil
		self:Invalidate()
	end
	self:SoundStop()
end

---
--- Loads a video file and initializes the video object.
---
--- This function is used to load a video file and create a new video object. It checks if the video file exists and creates a new video object using the UIL.videoNew function. The video object is then stored in the self[true] field and added to the global Videos table. If the video file cannot be loaded, an error message is returned.
---
--- @function XVideo:LoadVideo
--- @return string|nil error message if the video file cannot be loaded
function XVideo:LoadVideo()
	if self.FileName ~= "" and not self[true] then
		local movie_path = self.FileName
		if Platform.playstation then
			movie_path = GetPreloadedFile(movie_path)
		end
		if Platform.developer and not io.exists(movie_path) then
			print("Missing movie", movie_path)
		end
		local video, err
		if self.resolution then
			video, err = UIL.videoNew(movie_path, self.resolution:xy())
		else
			video, err = UIL.videoNew(movie_path)
		end
		if video then
			self[true] = video
			self:SetDesaturate(const.MovieCorrectionDesaturation)
			self:SetGamma(const.MovieCorrectionGamma)
			Videos[video] = self
			self:Invalidate()
		else
			return err 
		end
	end
end

--- Returns the size of the video object.
---
--- @function XVideo:GetVideoSize
--- @return number, number width and height of the video
function XVideo:GetVideoSize()
	return UIL.videoGetSize(self[true])
end

---
--- Returns the current frame index of the video.
---
--- @function XVideo:GetCurrentFrame
--- @return number the current frame index of the video
function XVideo:GetCurrentFrame()
	return UIL.videoGetCurrentFrame(self[true])
end

--- Returns the duration of the video in seconds.
---
--- @function XVideo:GetDuration
--- @return number the duration of the video in seconds
function XVideo:GetDuration()
	return UIL.videoGetDuration(self[true])
end

--- Returns the number of frames in the video.
---
--- @function XVideo:GetFrameCount
--- @return number the number of frames in the video
function XVideo:GetFrameCount()
	return UIL.videoGetFrameCount(self[true])
end

--- Measures the preferred size of the XVideo control.
---
--- @param preferred_width number the preferred width of the control
--- @param preferred_height number the preferred height of the control
--- @return number, number the measured width and height of the control
function XVideo:Measure(preferred_width, preferred_height)
	local width, height = 1920, 1080
	if width * preferred_height >= preferred_width * height then
		width, height = preferred_width, MulDivRound(height, preferred_width, width)
	end	
	local cwidth, cheight = XControl.Measure(self, preferred_width, preferred_height)
	return Max(width, cwidth), Max(height, cheight)
end

--- Draws the content of the XVideo control.
---
--- This function is responsible for rendering the video content within the control's content box. It uses the `UIL.videoDraw` function to draw the video, applying any desaturation or gamma adjustments specified in the control's properties.
---
--- @param self XVideo The XVideo control instance.
function XVideo:DrawContent()
	UIL.videoDraw(self[true], self.content_box, self.Desaturate, self.Gamma)
end

---
--- Handles the end of a video playback.
---
--- This function is called when a video has finished playing. It checks if the video object is still valid, and if so, it performs the following actions:
---
--- - Stops the video sound
--- - If the video is set to loop, it stops and then restarts the video playback, and starts the sound again
--- - If the video is not set to loop, it sets the video object's state to "stopped"
--- - Sends a message to the video object
--- - Calls the video object's `OnEnd` function
---
--- @param video string The name of the video that has ended
function videoOnEnd(video)
	local videoObj = Videos[video]
	if videoObj then
		videoObj:SoundStop()
		if videoObj.Looping then
			UIL.videoStop(video)
			UIL.videoPlay(video)
			videoObj:SoundStart()
		else
			videoObj.state = "stopped"
		end
		Msg(videoObj)
		videoObj:OnEnd()
	end
end

-- Playing video during bin assets loading is not supported!
--- Stops video playback when a global function is called.
---
--- This function wraps a global function and stops any video playback before calling the original function. After the original function returns, it resumes the video playback.
---
--- @param global_name string The name of the global function to wrap.
function StopVideoBracket(global_name)
	assert(type(global_name) == "string")
	local old_func = _G[global_name]
	assert(type(old_func) == "function")
	
	_G[global_name] = function(...)
		local videos_playing
		for _, window in pairs(Videos) do
			window:ClearVideo()
			videos_playing = videos_playing or {}
			videos_playing[#videos_playing + 1] = window
		end
		
		local results = pack_params(old_func(...))

		if videos_playing then
			CreateRealTimeThread(function(videos_playing)
				for _, window in ipairs(videos_playing) do
					if window.window_state == "open" then
						window:Play()
					end
				end
			end, videos_playing)
		end
		return unpack_params(results)
	end
end

StopVideoBracket("LoadMetadataCallback")
StopVideoBracket("ChangeMap")
