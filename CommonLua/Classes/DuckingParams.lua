DefineClass.DuckingParam = {
	__parents = { "Preset" },
	GlobalMap = "DuckingParams",

	properties = { 
		{ id = "Name",		name = "Name",					editor = "text",	default = ""	,																help = "The name with which this ducking tier will appear in the sound type editor." },
		{ id = "Tier",		name = "Tier",					editor = "number", default = 0,		min = -1, max = 100,  								   help = "Which tiers will be affected by this one - lower tiers affect higher ones." },
		{ id = "Strength",	name = "Strength",				editor = "number",	default = 100,	min = 0,  max = 1000, scale = 1, slider = true, help = "How much will this tier duck the ones below it." },
		{ id = "Attack",	name = "Attack Duration",		editor = "number",	default = 100,  min = 0,  max = 1000, scale = 1, slider = true, help = "How long will this tier take to go from no effect to full ducking in ms." },
		{ id = "Release",	name = "Release Duration",	editor = "number",	default = 100,	min = 0,  max = 1000, scale = 1, slider = true, help = "How long will this tier take to go from full ducking to no effect in ms." },
		{ id = "Hold",		name = "Hold Duration",		editor = "number", default = 100, 	min = 0,  max = 5000, scale = 1, slider = true,	help = "How long will this tier take, before starting to decay the ducking strength, after the sound strength decreases." },
		{ id = "Envelope",	name = "Use side chain",		editor = "bool",	default = true,																help = "Should the sounds in this preset modify the other sounds based on the current strength of their sound, or apply a constant static effect." },
	},
	
	OnEditorSetProperty = function(properties)
		ReloadDucking()
	end,

	Apply = function(self)
		ReloadDucking()
	end,
	
	EditorMenubarName = "Ducking Editor",
	EditorMenubar = "Editors.Audio",
	EditorIcon = "CommonAssets/UI/Icons/church.png",
}

---
--- Reloads the ducking parameters for the game.
--- This function is called when the ducking parameters are updated, and it updates the internal data structures used for ducking.
--- It reads the current ducking parameters from the `DuckingParams` table, and then calls the `LoadDuckingParams` function to update the game's ducking system.
--- After updating the ducking parameters, it also calls `ReloadSoundTypes` to ensure the sound types are updated to reflect the new ducking settings.
---
--- @return nil
function ReloadDucking()
	local names = {}
	local tiers = {}
	local strengths = {}
	local attacks = {}
	local releases = {}
	local hold = {}
	local envelopes = {}
	local i = 1
	for _, p in pairs(DuckingParams) do
		names[i] = p.id
		tiers[i] = p.Tier
		strengths[i] = p.Strength
		attacks[i] = p.Attack
		releases[i] = p.Release
		hold[i] = p.Hold
		envelopes[i] = p.Envelope and 1 or 0
		i = i + 1
	end
	LoadDuckingParams(names, tiers, strengths, attacks, releases, hold, envelopes)
	ReloadSoundTypes()
end

---
--- Changes the ducking preset for the specified ID.
---
--- @param id string The ID of the ducking preset to change.
--- @param tier number The new tier for the ducking preset.
--- @param str number The new strength for the ducking preset.
--- @param attack number The new attack duration for the ducking preset.
--- @param release number The new release duration for the ducking preset.
--- @param hold number The new hold duration for the ducking preset.
---
--- @return nil
function ChangeDuckingPreset(id, tier, str, attack, release, hold)
	if tier then
		DuckingParams[id].Tier = tier
	end
	if str then
		DuckingParams[id].Strength = str
	end
	if attack then
		DuckingParams[id].Attack = attack
	end
	if release then
		DuckingParams[id].Release = release
	end
	if hold then
		DuckingParams[id].Hold = hold
	end
	ReloadDucking()
end

OnMsg.DataLoaded = ReloadDucking