local max_vol = const.MaxVolume

--- Represents a voice system for playing audio and displaying subtitles.
---
--- @class Voice
--- @field sound_handle boolean The handle of the currently playing sound.
--- @field text boolean The text of the currently playing voice sample.
--- @field voice_type boolean The type of the currently playing voice.
--- @field volume number The volume of the voice, capped at `const.MaxVolume`.
--- @field thread boolean The thread that is currently playing the voice.
---
--- @field fade_volume number The volume reduction factor when fading out the voice.
--- @field fade_time number The time it takes to fade out the voice.
---
--- @field context boolean The current context of the voice system.
--- @field skipped_context table A table of skipped contexts.
---
--- @field priority_voices_only boolean Whether to only play priority voices.
--- @field priority_handle boolean The handle of the currently playing priority voice.
--- @field priority_thread boolean The thread that is currently playing the priority voice.
DefineClass.Voice =
{
	__parents = { "InitDone" },

	sound_handle = false,
	text = false,
	voice_type = false,
	volume = max_vol,
	thread = false,

	fade_volume = config.SoundVoiceReduceVolume,
	fade_time = config.SoundVoiceReduceTime,

	context = false,
	skipped_context = false,

	priority_voices_only = false,
	priority_handle = false,
	priority_thread = false,
}

--- Initializes the `skipped_context` table for the `Voice` class.
---
--- This function is called during the initialization of the `Voice` class to set up the `skipped_context` table, which is used to keep track of contexts that have been skipped during voice playback.
function Voice:Init()
	self.skipped_context = {}
end

---
--- Plays a single voice sample and displays subtitles if necessary.
---
--- @param text string The text to be played as voice.
--- @param actor string The name of the actor speaking the voice.
--- @param voice_type string The type of the voice, e.g. "Voiceover".
--- @param subtitles boolean Whether to display subtitles for the voice.
--- @param duration number The duration of the voice sample in milliseconds. If 0, the duration will be determined automatically.
--- @param actor string The name of the actor speaking the voice (duplicate of the previous parameter).
--- @param finish_callback function An optional callback function to be called when the voice playback is finished.
---
function Voice:_PlaySingle(text, actor, voice_type, subtitles, duration, actor)
	if not text then
		return
	end

	local sample = VoiceSampleByText(text, actor)
	local chatText = text
	if actor then
		text = T{928778304372, "<actor>: <text>", actor = actor, text = text}
	end

	local handle
	if sample then
		handle = PlaySound(sample, voice_type or "Voiceover", self.priority_voices_only and 0 or self.volume)
		if handle then
			self.sound_handle = handle
			self.text = sample
			self.voice_type = voice_type or "Voiceover"
		end
	end
	Sleep(100)
	if duration == 0 then
		duration = GetSoundDuration(handle)
		subtitles = subtitles and (GetAccountStorageOptionValue("Subtitles") or not duration)
		if not duration then
			duration = 2000 + #_InternalTranslate(text) * 50 -- approximation if we are missing the voice sample
		end
	end
	
	if actor and subtitles then --subtitles == true, when it's banther, subtitles == false when it's npc dialog
		--show in chat
		NetEvents.Chat(actor, chatText, true)
	end
	
	if subtitles then
		ShowSubtitles(text, duration, subtitles)
	else
		HideSubtitles()
	end
	duration = duration or GetSoundDuration(handle) or 10000
	
	-- +100, because of this Sleep(100) above
	-- +1, to allow finish_callback() (in Voice:Play()) to play another sound before we end the context
	DelayedCall(duration + 101, Voice.EndContext, self, self)
	
	Sleep(duration)
end

--- Plays a voice line with the given parameters.
---
--- @param text string The text to be spoken.
--- @param actor string The name of the actor speaking the text.
--- @param voice_type string The type of voice to use for the playback.
--- @param subtitles boolean Whether to display subtitles for the voice line.
--- @param duration number The duration of the voice line in milliseconds.
--- @param finish_callback function An optional callback function to be called when the voice playback is finished.
function Voice:Play(text, actor, voice_type, subtitles, duration, actor, finish_callback)
	assert((text or "") ~= "")
	self:BeginContext(self, true, text)
	self.thread = CreateRealTimeThread(function(self, text, actor, voice_type, subtitles, duration, actor, finish_callback)
		self:_PlaySingle(text, actor, voice_type, subtitles, duration, actor)
		self:_OnThreadDone()
		if finish_callback then
			finish_callback()
		end
	end, self, text, actor, voice_type, subtitles, duration, actor, finish_callback)
end

--- Plays a voice line with the highest priority, stopping any previously playing priority voice.
---
--- @param text string The text to be spoken.
--- @param actor string The name of the actor speaking the text.
function Voice:PlayPriorityVoice(text, actor)
	self:StopPriorityVoice()
	self.priority_thread = text and CreateRealTimeThread(function(self, text, actor)
		local sample = VoiceSampleByText(text, actor)
		if sample then
			local handle = PlaySound(sample, "Voiceover", self.volume)
			if handle then
				self.priority_handle = handle
				local duration = GetSoundDuration(handle) or 10000
				Sleep(duration)
				self.priority_handle = false
			end
		end
		self.priority_thread = false
	end, self, text, actor)
end

--- Stops the currently playing priority voice, optionally with a fade-out time.
---
--- @param fade_time number (optional) The fade-out time in milliseconds for the priority voice.
function Voice:StopPriorityVoice(fade_time)
	if self.priority_thread then
		DeleteThread(self.priority_thread)
		self.priority_thread = false
	end
	if self.priority_handle then
		SetSoundVolume(self.priority_handle, -1, fade_time or self.fade_time)
		self.priority_handle = false
	end
end

if FirstLoad then
	GroupVolumes = false
end

---
--- Sets the volume of all sound groups, except for the specified groups, to the given volume.
---
--- @param reason string The reason for setting the volume.
--- @param vol number The volume to set, between 0 and 1.
--- @param time number (optional) The time in milliseconds for the volume change to fade.
--- @param except table (optional) A table of group names to exclude from the volume change.
---
function SetAllVolumesReason(reason, vol, time, except)
	for _, group in ipairs(PresetGroupNames("SoundTypePreset")) do
		if not except or not except[group] then
			SetGroupVolumeReason(reason, group, vol, time)
		end
	end
end

---
--- Sets the volume of a sound group for a specific reason.
---
--- @param reason string The reason for setting the volume.
--- @param id string The ID of the sound group.
--- @param vol number The volume to set, between 0 and 1.
--- @param time number (optional) The time in milliseconds for the volume change to fade.
---
function SetGroupVolumeReason(reason, id, vol, time)
	reason = reason or false
	GroupVolumes = GroupVolumes or {}
	local reasons = GroupVolumes[id]
	if not vol then
		if not reasons or not reasons[reason] then
			return
		end
		reasons[reason] = nil
		local idx = table.remove_entry(reasons, reason)
		if idx <= #reasons then
			return
		end
		reason = reasons[#reasons]
		vol = reason and reasons[reason] or reasons.orig_vol
		if not reason then
			GroupVolumes[id] = nil
		end
	else
		vol = Clamp(vol, 0, max_vol)
		reasons = reasons or { orig_vol = GetGroupTargetVolume(id) }
		local prev_vol = reasons[reason]
		if prev_vol == vol then
			return
		end
		if not prev_vol then
			reasons[#reasons + 1] = reason
		end
		reasons[reason] = vol
		GroupVolumes[id] = reasons
	end
	SetGroupVolume(id, vol, time)
end

---
--- Clears all volume reasons for all sound groups, resetting the volume to the maximum.
---
function ClearAllGroupVolumeReasons()
	for id, reasons in pairs(GroupVolumes or empty_table) do
		SetGroupVolume(id, max_vol, 0)
	end
	GroupVolumes = false
end

---
--- Fades the volume of other sound groups when voice audio is playing.
---
--- @param fade boolean Whether to fade the other sound groups or not.
--- @param volume number (optional) The volume to set the other sound groups to, between 0 and 1. Defaults to `config.SoundVoiceReduceVolume`.
--- @param time number (optional) The time in milliseconds for the volume change to fade. Defaults to `config.SoundVoiceReduceTime`.
---
function FadeSoundsForVoiceover(fade, volume, time)
	if fade and GetOptionsGroupVolume("Voice") == 0 then return end
	volume = fade and (volume or config.SoundVoiceReduceVolume)
	local groups = config.SoundVoiceReduce or {"Music", "Sound", "Ambience"}
	for _, group in ipairs(groups) do
		SetGroupVolumeReason("FadeOtherSounds", group, volume, time or config.SoundVoiceReduceTime)
	end
end

---
--- Fades the volume of other sound groups when voice audio is playing.
---
--- @param fade boolean Whether to fade the other sound groups or not.
--- @param volume number (optional) The volume to set the other sound groups to, between 0 and 1. Defaults to `config.SoundVoiceReduceVolume`.
--- @param time number (optional) The time in milliseconds for the volume change to fade. Defaults to `config.SoundVoiceReduceTime`.
---
function Voice:FadeOtherSounds(fade)
	FadeSoundsForVoiceover(fade, self.fade_volume, self.fade_time)
end

-- Don't let the fade state linger after the sequence that started it
function OnMsg.SequenceStop(player, seq_name)
	local context = table.find_value(player.seq_list, "name", seq_name)
	if not context then return end
	
	g_Voice.skipped_context[context] = nil
	if g_Voice.context == context then
		--assert(false, "Sequence ended before the End Voice sequence action -- " .. seq_name)
		g_Voice:EndContext(context)
	end 
end

---
--- Resets the voice context, fading out any other sounds that were reduced for voice playback.
---
function Voice:_ResetContext()
	if self.context then
		self:FadeOtherSounds(false)
	end
	self.context = false
	self.skipped_context = {}
end

-- Don't let the fade state linger after the map that started it
function OnMsg.DoneMap()
	g_Voice:_ResetContext()
end
function OnMsg.LoadGame()
	g_Voice:_ResetContext()
end

---
--- Called when the voice thread is done playing.
--- Resets the voice state to indicate that no voice is currently playing.
---
function Voice:_OnThreadDone()
	self.voice = false
	self.voice_type = false
	self.sound_handle = false
	Msg(self)
	self.thread = false
end

---
--- Stops the currently playing voice and fades out any other sounds that were reduced for voice playback.
---
--- @param fadeout_time number (optional) The time in milliseconds for the volume change to fade. Defaults to 300.
---
function Voice:Stop(fadeout_time)
	SetSoundVolume(self.sound_handle, -1, fadeout_time or 300)
	self:FadeOtherSounds(false)
	if self.thread then
		DeleteThread(self.thread)
		self:_OnThreadDone()
	end
	HideSubtitles()
end

---
--- Waits for the currently playing voice thread to complete.
---
function Voice:Wait()
	if self.thread then
		WaitMsg(self)
	end
end

---
--- Checks if a voice is currently playing.
---
--- @return boolean True if a voice is currently playing, false otherwise.
---
function Voice:IsPlaying()
	return IsSoundPlaying(self.sound_handle)
end

---
--- Returns the type of the currently playing voice.
---
--- @return string|boolean The type of the currently playing voice, or `false` if no voice is playing.
---
function Voice:GetPlayingVoiceType()
	return self.voice_type
end

---
--- Sets the volume of the currently playing voice.
---
--- @param volume number The new volume level, between 0 and 1.
--- @param time number (optional) The time in milliseconds for the volume change to fade. Defaults to 0 (no fade).
---
function Voice:SetVolume(volume, time)
	self.volume = volume
	if self.sound_handle and not self.priority_voices_only then
		SetSoundVolume(self.sound_handle, volume, time)
	end
	if self.priority_handle then
		SetSoundVolume(self.priority_handle, volume, time)
	end
end

---
--- Returns the current volume level of the voice.
---
--- @return number The current volume level, between 0 and 1.
---
function Voice:GetVolume()
	return self.volume
end

---
--- Sets whether priority voices should be played exclusively.
---
--- @param value boolean Whether to play only priority voices.
--- @param fade number (optional) The time in milliseconds for the volume change to fade. Defaults to the `fade_time` property.
---
function Voice:SetPriorityVoices(value, fade)
	self.priority_voices_only = value
	local fade_time = fade and self.fade_time or 0
	self:StopPriorityVoice(fade_time)
	if self.sound_handle then
		if self.priority_voices_only then
			SetSoundVolume(self.sound_handle, self.fade_volume, fade_time)
		else
			SetSoundVolume(self.sound_handle, self.volume, fade_time)
		end
	end
end

---
--- Begins a new context for the voice playback.
---
--- @param context string The new context to begin.
--- @param fadeout_music boolean Whether to fade out any currently playing music.
--- @param text string The text associated with the new context.
---
function Voice:BeginContext(context, fadeout_music, text)
	if self.context then
		self.skipped_context[self.context] = true
	end
	self:Stop()
	self.context = context
	self.text = text
	self:FadeOtherSounds(fadeout_music)
end

---
--- Ends the current context for the voice playback.
---
--- @param context string The context to end.
---
function Voice:EndContext(context)
	if self.context == context then
		self.context = false
		self:Stop()
	end
	self.skipped_context[context] = nil
end

---
--- Checks if the specified context has been skipped.
---
--- @param context string The context to check.
--- @return boolean Whether the context has been skipped.
---
function Voice:IsContextSkipped(context)
	return self.skipped_context[context]
end

if FirstLoad then
	g_Voice = false
end

function OnMsg.Start()
	g_Voice = Voice:new{}
end

function OnMsg.ChangeMap()
	if g_Voice then
		g_Voice:Stop(0)
		g_Voice:StopPriorityVoice(0)
	end
end
