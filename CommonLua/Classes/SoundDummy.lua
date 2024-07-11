-- this class is used for creating sound dummy objects that only play sounds

DefineClass.SoundDummy = {
	__parents = { "ComponentAttach", "ComponentSound", "FXObject" },
	flags = { efVisible = false, efWalkable = false, efCollision = false, efApplyToGrids = false },
	entity = ""
}

DefineClass.SoundDummyOwner = {
	__parents = { "Object", "ComponentAttach" },
	snd_dummy = false,
}

---
--- Plays a sound using a SoundDummy object attached to the owner.
---
--- @param id string The sound ID to play.
--- @param fade_time number The fade-in time for the sound in seconds.
---
function SoundDummyOwner:PlayDummySound(id, fade_time)
	if not self.snd_dummy then
		self.snd_dummy = PlaceObject("SoundDummy")
		self:Attach(self.snd_dummy, self:GetSpotBeginIndex("Origin"))
	end
	self.snd_dummy:SetSound(id, 1000, fade_time)
end

---
--- Stops the sound played by the SoundDummy object attached to the owner.
---
--- @param fade_time number The fade-out time for the sound in seconds.
---
function SoundDummyOwner:StopDummySound(fade_time)
	if IsValid(self.snd_dummy) then
		self.snd_dummy:StopSound(fade_time)
	end
end

