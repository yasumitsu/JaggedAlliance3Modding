MapVar("g_ReverbIndoor", false)
MapVar("g_ReverbOutdoor", false)

---
--- Updates the reverb settings for the current map.
---
--- @param force boolean If true, the reverb settings will be updated regardless of whether they have changed.
---
function ReverbUpdate(force)
	if not config.UseReverb then return end
	
	-- per map is the highest priority
	local reverb_outdoor = mapdata.ReverbOutdoor ~= "default from Region" and mapdata.ReverbOutdoor
	local reverb_indoor = mapdata.ReverbIndoor ~= "default from Region" and mapdata.ReverbIndoor
	
	-- then the region
	local region = Presets.GameStateDef["region"][mapdata.Region]
	if region then
		reverb_indoor = reverb_indoor or region.ReverbIndoor
		reverb_outdoor = reverb_outdoor or region.ReverbOutdoor
	end
	
	if force or g_ReverbIndoor ~= reverb_indoor then
		g_ReverbIndoor = reverb_indoor
		local reverb_props = Presets.ReverbDef.Default[reverb_indoor]
		ApplyReverbPreset(reverb_props, const.Sound.ReverbPresetInterpolationTime, 1)
	end
	if force or g_ReverbOutdoor ~= reverb_outdoor then
		g_ReverbOutdoor = reverb_outdoor
		local reverb_props = Presets.ReverbDef.Default[reverb_outdoor]
		ApplyReverbPreset(reverb_props, const.Sound.ReverbPresetInterpolationTime, 0)
	end
end

OnMsg.NewMapLoaded = FillVolumeReverbs
OnMsg.LoadSector = FillVolumeReverbs

function OnMsg.DestructionPassDone()
	if not GameState.loading_savegame then
		FillVolumeReverbs()
	end
end

MapRealTimeRepeat("Reverb", const.Sound.ReverbPresetUpdateTime, function(time) ReverbUpdate(not "force") end)

function OnMsg.GedClosed(ged_editor)
	if ged_editor and ged_editor.context and ged_editor.context.PresetClass == "ReverbDef" then
		ReverbUpdate("force")
	end
end

if FirstLoad then
	s_DrySoundCache = {}
end

local pos_volume_offset = point(0, 0, const.vsInsideVolumeZOffset)

---
--- Replaces the sound effect of an action FX with a room-specific version if the actor is in a reverberant area.
---
--- @param sound string The ID of the sound effect to be replaced.
--- @param actor Object|Point The actor or position for which the sound effect is being played.
--- @return string The replaced sound effect ID or the original sound effect ID if no replacement was found.
function ActionFXSound:GetProjectReplace(sound, actor)
	local pos = IsValid(actor) and IsKindOf(actor, "Object") and actor:GetPos() or actor
	if not IsPoint(pos) then
		return sound
	end
	
	local cached_sound = s_DrySoundCache[sound]
	if cached_sound then
		return cached_sound
	end
	
	pos = pos + pos_volume_offset
	if GetReverbIndex(pos) == 1 then
		for _, group in ipairs(Presets.SoundPreset) do
			if table.find(group, "id", sound) then
				local room_sound = sound .. "-room"
				if table.find(group, "id", room_sound) then
					s_DrySoundCache[sound] = room_sound
					return room_sound
				end
			end
		end
	end
	
	return sound
end

DefineClass.ReverbSoundTest = {
	__parents = {"SoundSourceBaseImpl"},
	entity = "SpotHelper",
	
	thread = false,
}

---
--- Initializes a game thread that periodically plays a reverb test sound.
---
--- The thread runs indefinitely, sleeping for a random duration between 1 and 2 seconds before playing the reverb test sound again.
---
--- @function ReverbSoundTest:GameInit
--- @return nil
function ReverbSoundTest:GameInit()
	self.thread = CreateGameTimeThread(function()
		while true do
			self:PlaySound()
			Sleep(1000 + self:Random(1000))
		end
	end)
end

---
--- Stops the game thread that periodically plays a reverb test sound.
---
--- This function is called to terminate the reverb test sound thread created in the `ReverbSoundTest:GameInit()` function.
---
--- @function ReverbSoundTest:Done
--- @return nil
function ReverbSoundTest:Done()
	DeleteThread(self.thread)
end

---
--- Plays a reverb test sound.
---
--- This function is called by the `ReverbSoundTest:GameInit()` function to periodically play a reverb test sound. The sound is retrieved from the `Presets.SoundPreset` table using the key "AMBIENT-LIFE" and "ReverbTest". The sound is then played using the `PlaySound()` function, with the sound's ID, type, and loud distance specified.
---
--- @function ReverbSoundTest:PlaySound
--- @return nil
function ReverbSoundTest:PlaySound()
	local sound_bank = Presets.SoundPreset["AMBIENT-LIFE"]["ReverbTest"]
	if sound_bank then
		PlaySound(sound_bank.id, sound_bank.type, nil, nil, nil, self, sound_bank.loud_distance)
	end
end
