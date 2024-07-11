if FirstLoad then
	SoundBankPresetsPlaying = {}
	SoundEditorGroups = {}
	SoundEditorSampleInfoCache = {}
	SoundFilesCache = {}
	SoundFilesCacheTime = 0
end

config.SoundTypesPath = config.SoundTypesPath or "Lua/Config/__SoundTypes.lua"
config.SoundTypeTest = config.SoundTypeTest or "SoundTest"

local function EditorSoundStoped(sound_group, id)
	local group = SoundEditorGroups[sound_group]
	if group then
		table.remove_value(group, id)
		if #group == 0 then
			SetOptionsGroupVolume(sound_group, group.old_volume)
			SoundEditorGroups[sound_group] = nil
			print("Restoring volume to", group.old_volume, "for group", sound_group)
		end
	end
end

local function EditorSoundStarted(sound_group, id)
	local group = SoundEditorGroups[sound_group] or {}
	table.insert(group, id)
	if #group == 1 then
		group.old_volume = GetOptionsGroupVolume(sound_group)
		SoundEditorGroups[sound_group] = group
		print("Temporarily setting the volume of", sound_group ,"to 1000.")
	end
	SetOptionsGroupVolume(sound_group, 1000)
end

local function PlayStopSoundPreset(id, obj, sound_group, sound_type)
	if SoundBankPresetsPlaying[id] then
		StopSound(SoundBankPresetsPlaying[id])
		SoundBankPresetsPlaying[id] = nil
		EditorSoundStoped(sound_group, id)
		ObjModified(obj)
		return nil
	end
	
	local result, err = PlaySound(id, sound_type)
	if result then
		SoundBankPresetsPlaying[id] = result
		EditorSoundStarted(sound_group, id)
		ObjModified(obj)
		
		local looping, duration = IsSoundLooping(result), GetSoundDuration(result)
		print("Playing sound", id, "looping:", looping, "duration:", duration)
		if not looping and duration then
			CreateRealTimeThread(function() 
				Sleep(duration)
				SoundBankPresetsPlaying[id] = nil
				EditorSoundStoped(sound_group, id)
				ObjModified(obj)
			end)
		end
	else
		print("Failed to play sound", id, ":", err)
	end
end

---
--- Plays or stops a sound preset.
---
--- @param ged table The GED (Graphical Editor) object.
---
function GedPlaySoundPreset(ged)
	local sel_obj = ged:ResolveObj("SelectedObject")
	
	if IsKindOf(sel_obj, "SoundPreset") then
		PlayStopSoundPreset(sel_obj.id, Presets.SoundPreset, SoundTypePresets[sel_obj.type].options_group, config.SoundTypeTest)
	elseif IsKindOf(sel_obj, "SoundFile") then
		local preset = ged:GetParentOfKind("SelectedObject", "SoundPreset")
		if preset then
			PlayStopSoundPreset(sel_obj.file, preset, SoundTypePresets[preset.type].options_group, config.SoundTypeTest or preset.type)
		end
	end
end

DefineClass.SoundPreset = {
	__parents = {"Preset"},
	properties = {
		-- "sound"
		{ id = "type", editor = "preset_id", preset_class = "SoundTypePreset", name = "Sound Type", default = "" },
		{ id = "looping", editor = "bool", default = false, read_only = function (self) return self.periodic end, help = "Looping sounds are played in an endless loop without a gap." },
		{ id = "periodic", editor = "bool", default = false, read_only = function (self) return self.looping end, help = "Periodic sounds are repeated with random pauses between the repetitions; a different sample is chosen randomly each time." },
		{ id = "animsync", name = "Sync with animation", editor = "bool", default = false, read_only = function (self) return self.looping end, help = "Plays at the start of each animation. Anim synced sounds are periodic as well." },
		{ id = "volume", editor = "number", default = 100, min = 0, max = 300, slider = true, help = "Per-sound bank volume attenuation",
			buttons = { { name = "Adjust by %", func = "GedAdjustVolume" } },
		},
		{ id = "loud_distance", editor = "number", default = 0, min = 0, max = MaxSoundLoudDistance, slider = true, scale = "m", help = "No attenuation below that distance (in meters). In case of zero the sound group loud_distance is used." },
		{ id = "silence_frequency", editor = "number", default = 0, min = 0, help = "A random sample is chosen to play each time from this bank, using a weighted random; if this is non-zero, nothing will play with chance corresponding to this weight."},
		{ id = "silence_duration", editor = "number", default = 1000, min = 0, no_edit = function (self) return not self.periodic end, help = "Duration of the silence, if the weighted random picks silence. (Valid only for periodic sounds.)" },
		{ id = "periodic_delay", editor = "number", default = 0, min = 0, no_edit = function (self) return not self.periodic end, help = "Delay between repeating periodic sounds, fixed part."},
		{ id = "random_periodic_delay", editor = "number", default = 1000, min = 0, no_edit = function (self) return not self.periodic end, help = "Delay between repeating periodic sounds, random part."},
		{ id = "loop_start", editor = "number", default = 0, min = 0, no_edit = function (self) return not self.looping end, help = "For looping sounds, specify start of the looping part, in milliseconds." },
		{ id = "loop_end", editor = "number", default = 0, min = 0, no_edit = function (self) return not self.looping end, help = "For looping sounds, specify end of the looping part, in milliseconds."  },
		
		{ id = "unused", editor = "bool", default = false, read_only = true, dont_save = true },
	},
	
	GlobalMap = "SoundPresets",
	ContainerClass = "SoundFile",
	GedEditor = "SoundEditor",
	EditorMenubarName = "Sound Bank Editor",
	EditorMenubar = "Editors.Audio",
	EditorIcon = "CommonAssets/UI/Icons/bell message new notification sign.png",
	PresetIdRegex = "^[%w _+-]*$",
	FilterClass = "SoundPresetFilter",
	
	EditorView = Untranslated("<EditorColor><id> <color 75 105 198><type><color 128 128 128><opt(u(save_in), ' - ', '')><opt(SampleCount, ' <color 128 128 128>', '</color>')><opt(UnusedStr, ' <color 240 0 0>', '</color>')>")
}

if FirstLoad then
	SoundPresetAdjustPercent = false
	SoundPresetAdjustPercentUI = false
end

function OnMsg.GedExecPropButtonStarted()
	SoundPresetAdjustPercentUI = false
end

function OnMsg.GedExecPropButtonCompleted(obj)
	ObjModified(obj)
end

--- Returns a string indicating if the sound preset is marked as "unused".
---
--- @return string The string "unused" if the sound preset is marked as unused, otherwise an empty string.
function SoundPreset:GetUnusedStr()
	return self.unused and "unused" or ""
end

---
--- Adjusts the volume of a sound preset by a specified percentage.
---
--- @param root table The root object of the sound preset.
--- @param prop_id string The ID of the property being adjusted.
--- @param ged table The GED (Graphical Editor) object.
--- @param btn_param any The parameter passed from the button that triggered this function.
--- @param idx number The index of the sound preset in the list.
---
function SoundPreset:GedAdjustVolume(root, prop_id, ged, btn_param, idx)
	if not SoundPresetAdjustPercentUI then
		SoundPresetAdjustPercentUI = true
		SoundPresetAdjustPercent = ged:WaitUserInput("Enter adjust percent")
		if not SoundPresetAdjustPercent then
			ged:ShowMessage("Invalid Value", "Please enter a percentage number.")
			return
		end
	end
	if SoundPresetAdjustPercent then
		self.volume = MulDivRound(self.volume, 100 + SoundPresetAdjustPercent, 100)
		ObjModified(self)
	end
end

---
--- Returns a table of all sound files in the "Sounds" directory.
---
--- The table is cached for 1 second to improve performance. If the cache has expired, it will be rebuilt.
---
--- @return table A table of all sound file paths in the "Sounds" directory.
---
function SoundPreset:GetSoundFiles()
	if GetPreciseTicks() < 0 and SoundFilesCacheTime >= 0 or GetPreciseTicks() > SoundFilesCacheTime + 1000 then
		SoundFilesCache = {}
		local files = io.listfiles("Sounds", "*", "recursive")
		for _, name in ipairs(files) do
			SoundFilesCache[name] = true
		end
		SoundFilesCacheTime = GetPreciseTicks()
	end
	return SoundFilesCache
end

---
--- Checks for errors in a sound preset and returns a table with error messages and indexes of the problematic samples.
---
--- The function performs the following checks:
--- - Checks if the sound type is valid. If not, returns an error message.
--- - Checks if positional sounds are mono. If not, returns an error message and the indexes of the non-mono samples.
--- - Checks for invalid characters in the sample file names. If found, returns an error message and the indexes of the problematic samples.
--- - Checks if the sample files are missing or empty. If found, returns an error message and the indexes of the missing/empty samples.
--- - Checks for duplicate sample files. If found, returns an error message and the indexes of the duplicate samples.
---
--- @return table|string A table with error messages and indexes of problematic samples, or a single error message string if no errors are found.
function SoundPreset:GetError()
	local stype = SoundTypePresets[self.type]
	if not stype then
		return "Please set a valid sound type."
	end
	
	local err_table = { "", "error" } -- indexes of subobjects to be underlined are inserted in this table
	
	-- Positional sounds should be mono
	if stype.positional then
		for idx, sample in ipairs(self) do
			local data = sample:GetSampleData()
			if data and data.channels > 1 then
				err_table[1] = "The underlined positional sounds should be mono only."
				table.insert(err_table, idx)
			end
		end
	end
	if #err_table > 2 then
		return err_table
	end
	
	-- Invalid characters in file name
	for idx, sample in ipairs(self) do
		local file = sample.file
		for i = 1, #file do
			if file:byte(i) > 127 then
				err_table[1] = "Invalid character(s) are found in the underlined sample file names."
				table.insert(err_table, idx)
				break
			end
		end
	end
	if #err_table > 2 then
		return err_table
	end
	
	-- File missing
	local filenames = self:GetSoundFiles()
	for idx, sample in ipairs(self) do
		if not filenames[sample:Getpath()] then
			err_table[1] = "The underlined sound files are missing or empty."
			table.insert(err_table, idx)
		end
	end
	if #err_table > 2 then
		return err_table
	end
	
	-- Duplicate files
	local file_set = {}
	for idx, sample in ipairs(self) do
		local file = sample.file
		if file_set[file] then
			err_table[1] = "Duplicate sample files."
			table.insert(err_table, idx)
			table.insert(err_table, file_set[file])
		end
		file_set[file] = idx
	end
	if #err_table > 2 then
		return err_table
	end
end

---
--- Returns the editor color for the SoundPreset object.
---
--- If the SoundPreset is currently playing, it returns a green color.
--- Otherwise, it returns an alpha-blended color if the SoundPreset has no samples, or an empty string if it has samples.
---
--- @return string The editor color for the SoundPreset object.
function SoundPreset:EditorColor()
	if SoundBankPresetsPlaying[self.id] then
		return "<color 0 128 0>"
	end
	return #self == 0 and "<alpha 128>" or ""
end

---
--- Returns the number of samples in the SoundPreset object.
---
--- If the SoundPreset has no samples, this function returns an empty string.
--- Otherwise, it returns the number of samples in the SoundPreset.
---
--- @return string|number The number of samples in the SoundPreset object.
function SoundPreset:GetSampleCount()
	return #self == 0 and "" or #self
end

---
--- Loads the sound bank for the SoundPreset object.
---
--- This function is called when a new SoundPreset object is created in the editor.
---
function SoundPreset:OnEditorNew()
	LoadSoundBank(self)
end

---
--- Overrides the sample functions for the SoundPreset object.
---
--- This function is used to override the default behavior of the SoundPreset object's sample functions.
---
--- @function SoundPreset:OverrideSampleFuncs
--- @return nil
function SoundPreset:OverrideSampleFuncs()
end

---
--- Sets the looping state of the SoundPreset object.
---
--- If `val` is a number, the looping state is set to `true` if `val` is 1, and `false` otherwise.
--- If `val` is not a number, the looping state is set to `true` if `val` is truthy, and `false` otherwise.
---
--- @param val boolean|number The new looping state for the SoundPreset object.
--- @return nil
function SoundPreset:Setlooping(val)
	if type(val) == "number" then
		self.looping = (val == 1)
	else
		self.looping = not not val
	end
end 

---
--- Returns the looping state of the SoundPreset object.
---
--- If the `looping` property is a number, this function returns `true` if the number is non-zero, and `false` otherwise.
--- If the `looping` property is not a number, this function returns the boolean value of the `looping` property.
---
--- @return boolean The looping state of the SoundPreset object.
function SoundPreset:Getlooping(val)
	if type(self.looping) == "number" then
		return self.looping ~= 0
	end
	return self.looping and true or false
end

local bool_filter_items = { { text = "true", value = true }, { text = "false", value = false }, { text = "any", value = "any" } }
DefineClass.SoundPresetFilter = {
	__parents = { "GedFilter" },
	
	properties = {
		{ id = "SoundType", name = "Sound type", editor = "choice", default = "", items = PresetsCombo("SoundTypePreset", false, "") },
		{ id = "Looping", editor = "choice", default = "any", items = bool_filter_items },
		{ id = "Periodic", editor = "choice", default = "any", items = bool_filter_items },
		{ id = "AnimSync", name = "Sync with animation", editor = "choice", default = "any", items = bool_filter_items },
		{ id = "Unused", name = "Unused", editor = "choice", default = "any", items = bool_filter_items },
	},
}

---
--- Filters a SoundPreset object based on the specified filter criteria.
---
--- @param o SoundPreset The SoundPreset object to filter.
--- @return boolean True if the SoundPreset object matches the filter criteria, false otherwise.
function SoundPresetFilter:FilterObject(o)
	if self.SoundType ~= ""    and o.type     ~= self.SoundType then return false end
	if self.Looping   ~= "any" and o.looping  ~= self.Looping   then return false end
	if self.Periodic  ~= "any" and o.periodic ~= self.Periodic  then return false end
	if self.AnimSync  ~= "any" and o.animsync ~= self.AnimSync  then return false end
	if self.Unused  ~= "any"   and o.unused   ~= self.Unused    then return false end
	return true
end


local sample_base_folder = "Sounds"
local function folder_fn(obj) return obj:GetFolder() end
local function filter_fn(obj) return obj:GetFileFilter() end
DefineClass.SoundFile = {
	__parents = {"PropertyObject"},
	properties = {
		{ id = "file", editor = "browse", no_edit = true, default = "" },
		{ id = "path", dont_save = true, name = "Path", editor = "browse", default = "", folder = folder_fn, filter = filter_fn, mod_dst = function() return GetModAssetDestFolder("Sound") end},
		{ id = "frequency", editor = "number", min = 0},
	},
	frequency = 100,
	EditorView = Untranslated("<GedColor><file><if(not(file))>[No name]</if> <color 0 128 0><frequency></color> <SampleInformation>"),
	EditorName = "Sample",
	StoreAsTable = true,
}

DefineClass.Sample = {
	__parents = {"SoundFile"},
	StoreAsTable = false,
}

---
--- Returns the base folder for sound files.
---
--- @return string The base folder for sound files.
function SoundFile:GetFolder()
	return sample_base_folder
end

---
--- Returns a file filter string for the current sound file extension.
---
--- @return string The file filter string.
function SoundFile:GetFileFilter()
	local file_ext = self:GetFileExt()
	return string.format("Sample File(*.%s)|*.%s", file_ext, file_ext)
end

---
--- Returns the file extension for sound files.
---
--- @return string The file extension for sound files.
function SoundFile:GetFileExt()
	return "wav"
end

---
--- Returns a regular expression pattern to strip the file extension from a file path.
---
--- @param self SoundFile The SoundFile instance.
--- @return string The regular expression pattern to strip the file extension.
function SoundFile:GetStripPattern()
	local file_ext = self:GetFileExt()
	return "(.*)." .. file_ext .. "%s*$"
end

---
--- Returns the sample data for the sound file.
---
--- @return table The sample data for the sound file, including information about the number of channels, bits per sample, and duration.
function SoundFile:GetSampleData()
	local info = SoundEditorSampleInfoCache[self:Getpath()]
	if not info then
		info = GetSoundInformation(self:Getpath())
		SoundEditorSampleInfoCache[self:Getpath()] = info
	end
	return info
end

---
--- Returns a string with information about the sound sample, including the number of channels, bits per sample, and duration.
---
--- @return string The sample information string.
function SoundFile:SampleInformation()
	local info = self:GetSampleData()
	if not info then return "" end
	local channels = info.channels > 1 and "stereo" or "mono"
	local bits = info.bits_per_sample
	local duration = info.duration or 0
	return string.format("<color 240 0 0>%s</color> <color 75 105 198>%s</color> %0.3fs", channels, bits, duration / 1000.0)
end

---
--- Returns the bits per sample for the sound file.
---
--- @return number The bits per sample for the sound file.
function SoundFile:GetBitsPerSample()
	local info = SoundEditorSampleInfoCache[self:Getpath()]
	if not info then
		info = GetSoundInformation(self:Getpath())
		SoundEditorSampleInfoCache[self:Getpath()] = info
	end
	return info.bits_per_sample
end

---
--- Returns the color to display for the SoundFile based on its state.
---
--- If the sound file does not exist, the color will be red.
--- If the sound file is currently playing, the color will be green.
--- Otherwise, the color will be an empty string (no color).
---
--- @param self SoundFile The SoundFile instance.
--- @return string The color to display for the SoundFile.
function SoundFile:GedColor()
	if not io.exists(self:Getpath()) then return "<color 240 0 0>" end
	
	if SoundBankPresetsPlaying[self.file] then
		return "<color 0 128 0>"
	end
	return ""
end

---
--- Called when a property of the SoundFile is set in the editor.
---
--- This function is responsible for loading the sound bank associated with the
--- SoundPreset that the SoundFile belongs to. It also marks the root object and
--- the SoundPreset as modified to ensure the changes are saved.
---
--- @param self SoundFile The SoundFile instance.
--- @param prop_id string The ID of the property that was set.
--- @param old_value any The previous value of the property.
--- @param ged table The GED (Game Editor) instance.
function SoundFile:OnEditorSetProperty(prop_id, old_value, ged)
	if rawget(_G, "SoundStatsInstance") then
		local sound = ged:GetParentOfKind("SelectedObject", "SoundPreset")
		LoadSoundBank(sound)
		ObjModified(ged:ResolveObj("root"))
		ObjModified(sound)
	end
end

---
--- Sets the path of the SoundFile.
---
--- If the path is valid (i.e. in the project's Sounds/ folder), the file name is extracted and stored in the `file` field.
--- If the path is invalid, a warning message is printed.
---
--- @param self SoundFile The SoundFile instance.
--- @param path string The path to set for the SoundFile.
function SoundFile:Setpath(path)
	local normalized = string.match(path, self:GetStripPattern())
	if normalized then
		self.file = normalized
	else
		print("Invalid sound path - must be in project's Sounds/ folder")
	end
end

---
--- Gets the full path of the SoundFile, including the file extension.
---
--- @param self SoundFile The SoundFile instance.
--- @return string The full path of the SoundFile.
function SoundFile:Getpath()
	return self.file .. "." .. self:GetFileExt()
end

---
--- Called when a new SoundFile is created in the editor.
---
--- This function is responsible for handling the creation of a new SoundFile in the editor.
--- It allows the user to browse for a sound file and adds it to the SoundPreset.
--- If the SoundFile is not part of a mod item, it creates a new SoundFile instance and adds it to the SoundPreset.
---
--- @param self SoundFile The SoundFile instance.
--- @param preset SoundPreset The SoundPreset that the SoundFile belongs to.
--- @param ged table The GED (Game Editor) instance.
--- @param is_paste boolean Whether the SoundFile was pasted from another location.
function SoundFile:OnEditorNew(preset, ged, is_paste)
	preset:OverrideSampleFuncs(self)
	local is_mod_item = TryGetModDefFromObj(preset)
	if not is_paste and not is_mod_item then
		CreateRealTimeThread(function()
			local os_path = self:GetFolder()
			if type(os_path) == "table" then
				os_path = os_path[1][1]
			end
			os_path = ConvertToOSPath(os_path .. "/")
			local path_list = ged:WaitBrowseDialog(os_path, self:GetFileFilter(), false, true)
			if path_list and #path_list > 0 then
				local current_index = (table.find(preset, self) or -1) + 1
				for i = #path_list, 2, -1 do
					local path = path_list[i]
					local next_sample = SoundFile:new({})
					next_sample:Setpath(ConvertFromOSPath(path, "Sounds/"))
					table.insert(preset, current_index, next_sample)
				end
				self:Setpath(ConvertFromOSPath(path_list[1], "Sounds/"))
				SuspendObjModified("NewSample")
				ObjModified(self)
				ObjModified(preset)
				ged:OnParentsModified("SelectedObject")
				ResumeObjModified("NewSample")
			end
		end)
	end
end

---
--- Loads the sound banks for all sound presets.
---
--- This function iterates through all the sound preset groups and loads the sound banks for each preset in those groups.
---
--- @function LoadSoundPresetSoundBanks
function LoadSoundPresetSoundBanks()
	ForEachPresetGroup(SoundPreset, function(group)
		local preset_list = Presets.SoundPreset[group]
		LoadSoundBanks(preset_list)
	end)
end

if FirstLoad then
	l_test_counter_1 = 0
	l_test_counter_2 = 0
end

---
--- Checks if the Sound Type Editor is currently opened.
---
--- @return boolean true if the Sound Type Editor is opened, false otherwise
---
function IsSoundEditorOpened()
	if not rawget(_G, "GedConnections") then return false end
	for key, conn in pairs(GedConnections) do
		if conn.app_template == SoundPreset.GedEditor then
			return true
		end
	end
	return false
end

---
--- Checks if the Sound Type Editor is currently opened.
---
--- @return boolean true if the Sound Type Editor is opened, false otherwise
---
function IsSoundTypeEditorOpened()
	if not rawget(_G, "GedConnections") then return false end
	for key, conn in pairs(GedConnections) do
		if conn.app_template == SoundTypePreset.GedEditor then
			return true
		end
	end
	return false
end

----

if FirstLoad then
	SoundMuteReasons = {}
	SoundUnmuteReasons = {}
end

---
--- Updates the mute state of sounds based on the mute and unmute reasons.
---
--- The mute and unmute reasons are stored in the `SoundMuteReasons` and `SoundUnmuteReasons` tables, respectively.
--- The mute state is set to the maximum force of all mute reasons, unless there is a higher force unmute reason.
---
--- @function UpdateMuteSound
--- @return nil
function UpdateMuteSound()
	local mute_force, unmute_force = 0, 0
	for reason, force in pairs(SoundMuteReasons) do
		mute_force = Max(mute_force, force)
		--print("Mute", ValueToStr(reason), force)
	end
	for reason, force in pairs(SoundUnmuteReasons) do
		unmute_force = Max(unmute_force, force)
		--print("Unmute", ValueToStr(reason), force)
	end
	--print("Mute:", mute_force, "Unmute:", unmute_force)
	SetMute(mute_force > unmute_force)
end

local function DoSetMuteSoundReason(reasons, reason, force)
	reason = reason or false
	force = force or 0
	reasons[reason] = force > 0 and force or nil
	UpdateMuteSound()
end
---
--- Sets a mute reason for sounds with the specified force.
---
--- The mute reason and force are stored in the `SoundMuteReasons` table.
--- The mute state of sounds is updated by calling `UpdateMuteSound()`.
---
--- @param reason string The mute reason.
--- @param force number The force of the mute reason. A higher force takes precedence.
--- @return nil
function SetMuteSoundReason(reason, force)
	return DoSetMuteSoundReason(SoundMuteReasons, reason, force or 1)
end
---
--- Clears a mute reason for sounds.
---
--- The mute reason is removed from the `SoundMuteReasons` table.
--- The mute state of sounds is updated by calling `UpdateMuteSound()`.
---
--- @param reason string The mute reason to clear.
--- @return nil
function ClearMuteSoundReason(reason)
	return DoSetMuteSoundReason(SoundMuteReasons, reason, false)
end

---
--- Sets an unmute reason for sounds with the specified force.
---
--- The unmute reason and force are stored in the `SoundUnmuteReasons` table.
--- The mute state of sounds is updated by calling `UpdateMuteSound()`.
---
--- @param reason string The unmute reason.
--- @param force number The force of the unmute reason. A higher force takes precedence.
--- @return nil
function SetUnmuteSoundReason(reason, force)
	return DoSetMuteSoundReason(SoundUnmuteReasons, reason, force or 1)
end
---
--- Clears a mute reason for sounds.
---
--- The mute reason is removed from the `SoundMuteReasons` table.
--- The mute state of sounds is updated by calling `UpdateMuteSound()`.
---
--- @param reason string The mute reason to clear.
--- @return nil
function ClearUnmuteSoundReason(reason)
	return DoSetMuteSoundReason(SoundUnmuteReasons, reason, false)
end

------------------- Editor -----------------

function OnMsg.GedOpened(ged_id)
	local conn = GedConnections[ged_id]
	if not conn then return end
	if conn.app_template == SoundPreset.GedEditor then
		SoundStatsInstance = SoundStatsInstance or SoundStats:new()
		conn:BindObj("stats", SoundStatsInstance)
		SoundStatsInstance:Refresh()
		SetUnmuteSoundReason("SoundEditor", 1000)
	end
	if conn.app_template == SoundTypePreset.GedEditor then
		ActiveSoundsInstance = ActiveSoundsInstance or ActiveSoundStats:new()
		conn:BindObj("active_sounds", ActiveSoundsInstance)
		ActiveSoundsInstance.ged_conn = conn
		ActiveSoundsInstance:RescanAction()
		SetUnmuteSoundReason("SoundTypeEditor", 1000)
	end
end

function OnMsg.GedClosing(ged_id)
	local conn = GedConnections[ged_id]
	if not conn then return end
	if conn.app_template == SoundPreset.GedEditor then
		ClearUnmuteSoundReason("SoundEditor")
	end
	if conn.app_template == SoundTypePreset.GedEditor then
		ClearUnmuteSoundReason("SoundTypeEditor")
	end
end

---
--- Saves all the properties of the SoundPreset object and loads the sound banks.
---
--- This function overrides the `Preset.SaveAll` function and adds the additional step of loading the sound banks after saving the preset.
---
--- @param self SoundPreset The SoundPreset object to save.
--- @param ... any Additional arguments passed to the `Preset.SaveAll` function.
--- @return nil
function SoundPreset:SaveAll(...)
	Preset.SaveAll(self, ...)
	LoadSoundPresetSoundBanks()
end

----------------- Stats ------------------
if FirstLoad then
	SoundStatsInstance = false
	ActiveSoundsInstance = false
end

local sound_flags = {"Playing", "Looping", "NoReverb", "Positional", "Disable", "Replace", "Pause", "Periodic", "AnimSync", "DeleteSample", "Stream", "Restricted"}
local volume_scale = const.VolumeScale
local function FlagsToStr(flags)
	return flags and table.concat(table.keys(flags, true), " | ") or ""
end
	
DefineClass.SoundInfo = {
	__parents = { "PropertyObject" },
	properties = {
		-- Stats
		{ id = "sample",  editor = "text", default = "" },
		{ id = "sound_bank",  editor = "preset_id", default = "", preset_class = "SoundPreset" },
		{ id = "sound_type",  editor = "preset_id", default = "", preset_class = "SoundTypePreset" },
		{ id = "format",  editor = "text", default = "" },
		{ id = "channels",  editor = "number", default = 1 },
		{ id = "duration",  editor = "number", default = 0, scale = "sec" },
		{ id = "state",  editor = "text", default = "" },
		{ id = "sound_flags",  editor = "prop_table", default = false, items = sound_flags, no_edit = true },
		{ id = "type_flags",  editor = "prop_table", default = false, items = sound_flags, no_edit = true },
		{ id = "SoundFlags",  editor = "text", default = "" },
		{ id = "TypeFlags",  editor = "text", default = "" },
		{ id = "obj",  editor = "object", default = false, no_edit = true }, -- "text" because "object" doesn't work for CObject
		{ id = "ObjText", name = "obj", editor = "text", default = false, buttons = { {name = "Show", func = "ShowObj" }} }, -- "text" because "object" doesn't work for CObject
		{ id = "current_pos",  editor = "point", default = false, buttons = { {name = "Show", func = "ShowCurrentPos" }} },
		{ id = "Attached", editor = "bool", default = false, help = "Is the sound attached to the object. An object can have a single attached sound to play" },
		{ id = "sound_handle", editor = "number", default = 0, no_edit = true },
		{ id = "SoundHandleHex", name = "sound_handle", editor = "text", default = "" },
		{ id = "play_idx", editor = "number", default = -1, help = "Index in the list of actively playing sounds" },
		{ id = "volume", editor = "number", default = 0, scale = volume_scale },
		{ id = "final_volume", editor = "number", default = 0, scale = volume_scale, help = "The final volume formed by the sound's volume and the type's final volume" },
		{ id = "loud_distance", editor = "number", default = 0, scale = "m" },
		{ id = "time_fade", editor = "number", default = 0 },
		{ id = "loop_start", editor = "number", default = 0, scale = "sec" },
		{ id = "loop_end", editor = "number", default = 0, scale = "sec" },
	},
	
	GetSoundFlags = function(self)
		return FlagsToStr(self.sound_flags)
	end,
	GetTypeFlags = function(self)
		return FlagsToStr(self.type_flags)
	end,
	GetAttached = function(self)
		local obj = self.obj
		if not IsValid(obj) then
			return false
		end
		local sample, sbank, stype, shandle = obj:GetSound()
		return shandle == self.sound_handle
	end,
	GetObjText = function(self)
		local obj = self.obj
		return IsValid(obj) and obj.class or ""
	end,
	GetSoundHandleHex = function(self)
		return string.format("%d (0x%X)", self.sound_handle, self.sound_handle)
	end,
	ShowCurrentPos = function(self)
		local pos = self.current_pos
		if IsValidPos(self.current_pos) then
			ShowMesh(3000, function()
				return {
					PlaceSphere(pos, guim/2),
					PlaceCircle(pos, self.loud_distance)
				}
			end)
			local eye = pos + point(0, 2*self.loud_distance, 3*self.loud_distance)
			SetCamera(eye, pos, nil, nil, nil, nil, 300)
		end
	end,
	ShowObj = function(self)
		local obj = self.obj
		if IsValid(obj) then
			local pos = obj:GetVisualPos()
			local eye = pos + point(0, self.loud_distance, 2*self.loud_distance)
			SetCamera(eye, pos, nil, nil, nil, nil, 300)
			if obj:GetRadius() == 0 then
				return
			end
			CreateRealTimeThread(function(obj)
				local highlight
				SetContourReason(obj, 1, "ShowObj")
				for i=1,20 do
					if not IsValid(obj) then
						break
					end
					highlight = not highlight
					DbgSetColor(obj, highlight and 0xffffffff or 0xff000000)
					Sleep(100)
				end
				ClearContourReason(obj, 1, "ShowObj")
				DbgSetColor(obj)
			end, obj)
		end
	end,
	GetEditorView = function(self)
		if self.sound_bank then
			return string.format("%s.%s", self.sound_type, self.sound_bank)
		end
		local text = self.sample
		if string.starts_with(text, "Sounds/", true) then
			text = text:sub(8)
		end
		return text
	end,
}

DefineClass.ActiveSoundStats = {
	__parents = { "InitDone" },
	properties = {
		-- Stats
		{ id = "AutoUpdate", name = "Auto Update (ms)", editor = "number", default = 0, category = "Stats" },
		{ id = "HideMuted", name = "Hide Muted", editor = "bool", default = false, category = "Stats" },
		{ id = "active_sounds", name = "Active Sounds", editor = "nested_list", base_class = "SoundInfo", default = false, category = "Stats", read_only = true, buttons = {{name = "Rescan", func = "RescanAction" }} },
	},
	sound_hash = false,
	ged_conn = false,
	auto_update = 0,
	auto_update_thread = false,
}

---
--- Stops the auto-update thread for the ActiveSoundStats object.
---
--- This function is called when the ActiveSoundStats object is being destroyed or no longer needed.
--- It ensures that the auto-update thread, which periodically rescans the active sounds, is terminated.
---
--- @function ActiveSoundStats:Done
--- @return nil
function ActiveSoundStats:Done()
	DeleteThread(self.auto_update_thread)
end

---
--- Sets whether muted sounds should be hidden in the active sounds list.
---
--- When `value` is `true`, muted sounds will be hidden from the active sounds list.
--- When `value` is `false`, muted sounds will be shown in the active sounds list.
---
--- After setting the `HideMuted` property, the `RescanAction` function is called to update the active sounds list.
---
--- @param value boolean
---   `true` to hide muted sounds, `false` to show muted sounds
--- @return nil
function ActiveSoundStats:SetHideMuted(value)
	self.HideMuted = value
	self:RescanAction()
end

---
--- Checks if the ActiveSoundStats object is currently shown.
---
--- This function returns `true` if the ActiveSoundStats object is connected to the GUI and its `active_sounds` property is set to the current instance. Otherwise, it returns `false`.
---
--- @return boolean
---   `true` if the ActiveSoundStats object is shown, `false` otherwise
function ActiveSoundStats:IsShown()
	local ged_conn = self.ged_conn
	local active_sounds = table.get(ged_conn, "bound_objects", "active_sounds")
	return active_sounds == self and ged_conn:IsConnected()
end

---
--- Sets the auto-update interval for the ActiveSoundStats object.
---
--- When `auto_update` is set to a positive value, the ActiveSoundStats object will periodically rescan the active sounds and update its internal state. The rescan is performed every `auto_update` seconds.
---
--- If `auto_update` is set to 0 or a negative value, the auto-update thread is terminated and no further rescans will be performed.
---
--- @param auto_update number
---   The interval in seconds for the auto-update thread, or 0 to disable auto-update
--- @return nil
function ActiveSoundStats:SetAutoUpdate(auto_update)
	self.auto_update = auto_update
	DeleteThread(self.auto_update_thread)
	if auto_update <= 0 then
		return
	end
	self.auto_update_thread = CreateRealTimeThread(function()
		while true do
			Sleep(auto_update)
			if self:IsShown() then
				self:RescanAction()
			end
		end
	end)
end

---
--- Gets the auto-update interval for the ActiveSoundStats object.
---
--- When `auto_update` is set to a positive value, the ActiveSoundStats object will periodically rescan the active sounds and update its internal state. The rescan is performed every `auto_update` seconds.
---
--- If `auto_update` is set to 0 or a negative value, the auto-update thread is terminated and no further rescans will be performed.
---
--- @return number
---   The interval in seconds for the auto-update thread, or 0 if auto-update is disabled
function ActiveSoundStats:GetAutoUpdate()
	return self.auto_update
end

---
--- Rescans the active sounds and updates the internal state of the `ActiveSoundStats` object.
---
--- This function retrieves the list of active sounds, sorts them, and updates the `active_sounds` and `sound_hash` properties of the `ActiveSoundStats` object. It also handles hiding muted sounds if the `HideMuted` property is set.
---
--- @return nil
function ActiveSoundStats:RescanAction()
	local list = GetActiveSounds()
	table.sort(list, function(s1, s2)
		return s1.sample < s2.sample or s1.sample == s2.sample and s1.sound_handle < s2.sound_handle
	end)
	local active_sounds = self.active_sounds or {}
	self.active_sounds = active_sounds
	local sound_hash = self.sound_hash or {}
	self.sound_hash = sound_hash
	local hide_muted = self.HideMuted
	local k = 1
	for i, info in ipairs(list) do
		if not hide_muted or info.final_volume > 0 then
			local hash = table.hash(info, nil, 1)
			if not active_sounds[k] or sound_hash[k] ~= hash then
				active_sounds[k] = SoundInfo:new(info)
				sound_hash[k] = hash
				k = k + 1
			end
		end
	end
	if #active_sounds ~= k then
		table.iclear(active_sounds, k + 1)
	end
	ObjModified(self)
end

DefineClass.SoundStats = {
	__parents = { "PropertyObject" },
	properties = {
		-- Stats
		{ id = "total_sounds", name = "Sounds", editor = "number", default = 0, category = "Stats", read_only = true},
		{ id = "total_samples", name = "Samples", editor = "number", default = 0, category = "Stats", read_only = true},
		{ id = "total_size", name = "Total MBs", editor = "number", default = 0, scale=1024*1024, category = "Stats", read_only = true},
		{ id = "compressed_total_size", name = "Total compressed MBs", editor = "number", default = 0, scale=1024*1024, category = "Stats", read_only = true},
		{ id = "unused_samples", name = "Unused samples", editor = "number", default = 0, scale=1, category = "Stats", read_only = true, buttons = {{name = "List", func = "PrintUnused" }, {name = "Refresh", func = "RefreshAction" }}},
		{ id = "unused_total_size", name = "Total unused MBs", editor = "number", default = 0, scale=1024*1024, category = "Stats", read_only = true},
		{ id = "compressed_unused_total_size", name = "Total unused compressed MBs", editor = "number", default = 0, scale=1024*1024, category = "Stats", read_only = true},
		{ id = "unused_count", name = "Unused Banks Count", editor = "number", default = 0, buttons = {{name = "Search", func = "SearchUnusedBanks" }}, category = "Stats", read_only = true},
	},
	refresh_thread = false,
	walked_files = false,
	unused_samples_list = false,
}

---
--- Searches for unused sound banks in the game's presets and updates the `unused_count` property of the `SoundStats` object.
---
--- This function iterates through all the game's presets, excluding the `SoundPreset` class, and collects all the string values used in the presets. It then checks each `SoundPreset` to see if it is not referenced by any of the collected strings, and marks those presets as "unused". The number of unused presets is stored in the `unused_count` property.
---
--- @param root table The root object, likely the `SoundStats` instance.
--- @param name string The name of the function, likely "SearchUnusedBanks".
--- @param ged table The GUI editor object, likely used for displaying a message.
--- @return nil
function SoundStats:SearchUnusedBanks(root, name, ged)
	local st = GetPreciseTicks()
	local data_strings = {}
	for class, groups in sorted_pairs(Presets) do
		if class ~= "SoundPreset" then
			for _, group in ipairs(groups) do
				for _, preset in ipairs(group) do
					for key, value in pairs(preset) do
						if type(value) == "string" then
							data_strings[value] = true
						end
					end
				end
			end
		end
	end
	local count = 0
	local unused = {}
	for name, sound in pairs(SoundPresets) do
		sound.unused = nil
		if #sound > 0 and not data_strings[name] then
			unused[#unused + 1] = sound
		end
	end
	-- TODO: search the unused in the code, then in the maps
	self.unused_count = #unused
	for _, sound in ipairs(unused) do
		sound.unused = true
	end
	print(#unused, "unused sounds found in", GetPreciseTicks() - st, "ms")
end

---
--- Prints a list of unused sound samples to a message dialog.
---
--- This function iterates through the `unused_samples_list` property of the `SoundStats` object and generates a string containing the paths of all unused sound samples. This string is then displayed in a message dialog using the provided `ged` (GUI editor) object.
---
--- @param root table The root object, likely the `SoundStats` instance.
--- @param name string The name of the function, likely "PrintUnused".
--- @param ged table The GUI editor object, used for displaying the message dialog.
---
function SoundStats:PrintUnused(root, name, ged)
	local txt = ""
	for _, sample in ipairs(self.unused_samples_list) do
		txt = txt .. sample .. "\n"
	end
	ged:ShowMessage("List", txt)
end

---
--- Returns the number of unused sound samples.
---
--- This function returns the length of the `unused_samples_list` property of the `SoundStats` object, which represents the number of unused sound samples.
---
--- @return number The number of unused sound samples.
---
function SoundStats:GetUnused_samples()
	return #(self.unused_samples_list or "")
end


---
--- Refreshes the sound statistics for the SoundStats object.
---
--- This function is called to update the sound statistics, including the total number of sounds, total number of samples, total size, and compressed total size. It also identifies any unused sound samples and stores their paths in the `unused_samples_list` property.
---
--- @param root table The root object, likely the `SoundStats` instance.
---
function SoundStats:RefreshAction(root)
	self:Refresh()
end

---
--- Refreshes the sound statistics for the SoundStats object.
---
--- This function is called to update the sound statistics, including the total number of sounds, total number of samples, total size, and compressed total size. It also identifies any unused sound samples and stores their paths in the `unused_samples_list` property.
---
--- @param root table The root object, likely the `SoundStats` instance.
---
function SoundStats:Refresh()
	self.refresh_thread = self.refresh_thread or CreateRealTimeThread(function()
		SoundEditorSampleInfoCache = {}

		local total_sounds, total_samples, total_size, compressed_total_size = 0, 0, 0, 0
		local walked_files = {}
		local original_sizes, compressed_sizes = {}, {}
		self.unused_samples_list = {}
		self.total_sounds = 0
		self.total_samples = 0
		self.total_size = 0
		self.compressed_total_size = 0
		self.unused_total_size = 0
		self.compressed_unused_total_size = 0
		ObjModified(self) -- hide all values

		local function compressed_sample_path(path)
			local dir, name = SplitPath(path)
			return "svnAssets/Bin/win32/" .. dir .. name .. ".opus"
		end

		ForEachPreset(SoundPreset, function(sound)
			total_sounds = total_sounds + 1
			total_samples = total_samples + #sound
			for i, sample in ipairs(sound) do
				local path = sample:Getpath()
				if not walked_files[path] then
					walked_files[path] = true
					
					local original_size = io.getsize(path) or 0
					original_sizes[path] = original_size
					if original_size > 0 then
						total_size = total_size + original_size
					end

					local compressed_path = compressed_sample_path(path)
					local compressed_size = io.getsize(compressed_path) or 0
					compressed_sizes[path] = compressed_size
					if compressed_size > 0 then
						compressed_total_size = compressed_total_size + compressed_size
					end
				end
			end
		end)
        
		self.total_sounds = total_sounds
		self.total_samples = total_samples
		self.total_size = total_size
		self.compressed_total_size = compressed_total_size
		self.walked_files = walked_files
		self.unused_samples_list = self:CalcUnusedSamples()
		local unused_total_size, compressed_unused_total_size = 0, 0
		for i, file in ipairs(self.unused_samples_list) do
			unused_total_size = unused_total_size + io.getsize(file)
			local compressed_file = compressed_sample_path(file)
			compressed_unused_total_size = compressed_unused_total_size + io.getsize(compressed_file)
		end
		self.unused_total_size = unused_total_size
		self.compressed_unused_total_size = compressed_unused_total_size
		
		local active_sounds = GetActiveSounds()
		for i, info in ipairs(active_sounds) do
			active_sounds[i] = SoundInfo:new(info)
		end
		self.active_sounds = active_sounds
		
		ObjModified(self)
		ObjModified(Presets.SoundPreset)
		self.refresh_thread = false
    end)
end


local function ListSamples(dir, type)
	dir = dir or "Sounds"
	local sample_file_ext = Platform.developer and "wav" or "opus"
	type = type or ("*." .. sample_file_ext)
	local samples = io.listfiles(dir, type, "recursive")
	local normalized = {}
	local rem_ext_pattern = "(.*)." .. sample_file_ext
	for i=1,#samples do
		local str = samples[i]
		if str then
			normalized[#normalized + 1] = str
		end
	end
	return normalized
end

---
--- Calculates the list of unused sound sample files in the "Sounds" directory.
---
--- @return table The list of unused sound sample files.
function SoundStats:CalcUnusedSamples()
	local files = ListSamples("Sounds")
	local unused = {}
	local used = self.walked_files
	
	for i, file in ipairs(files) do
		if not used[file] then
			table.insert(unused, file)
		end
	end
	table.sort(unused)
	return unused
end

--- When a property of the SoundPreset is edited in the editor, this function is called.
---
--- It performs the following actions:
--- - Loads the sound bank associated with the SoundPreset
--- - If the SoundStatsInstance exists, it refreshes the sound statistics
--- - Calls the OnEditorSetProperty function of the base Preset class
---
--- @param prop_id The ID of the property that was edited
--- @param old_value The previous value of the property
--- @param ged The editor GUI element associated with the property
function SoundPreset:OnEditorSetProperty(prop_id, old_value, ged)
	LoadSoundBank(self)
	if SoundStatsInstance then
		SoundStatsInstance:Refresh()
	end
	Preset.OnEditorSetProperty(self, prop_id, old_value, ged)
end

local function ApplySoundBlacklist(replace)
	ForEachPreset(SoundPreset, function(sound)
		for j = #sound, 1, -1 do
			local sample = sound[j]
			sample.file = replace[sample.file] or sample.file
		end
	end)
end

function OnMsg.DataLoaded()
	if config.ReplaceSound and rawget(_G, "ReplaceSound") then
		ApplySoundBlacklist(ReplaceSound)
	end
	rawset(_G, "ReplaceSound", nil)
	LoadSoundPresetSoundBanks()
end

function OnMsg.DoneMap()
	PauseSounds(2)
end

function OnMsg.GameTimeStart()
	ResumeSounds(2)
end

function OnMsg.PersistPostLoad()
	ResumeSounds(2)
end

local function RegisterTestType()
	if not config.SoundTypeTest or SoundTypePresets[config.SoundTypeTest] then return end
	local preset = SoundTypePreset:new{
		options_group = "",
		positional = false,
		pause = false,
		Comment = "Used when playing sounds from the sound editor"
	}
	preset:SetGroup("Test")
	preset:SetId(config.SoundTypeTest)
	preset:PostLoad()
	g_PresetLastSavePaths[preset] = false
end

---
--- Returns a table of sound group names, with an empty string as the first item.
---
--- The sound group names are defined in the `config.SoundGroups` table.
---
--- @return table Sound group names
function SoundGroupsCombo()
	local items = table.icopy(config.SoundGroups)
	table.insert(items, 1, "")
	return items
end

local debug_levels = {
	{ value = 1, text = "simple", help = "listener circle + vector to playing objects" },
	{ value = 2, text = "normal", help = "simple + loud distance circle + volume visualization" },
	{ value = 3, text = "verbose", help = "normal + sound texts for all map sound" },
}

DefineClass.SoundTypePreset = {
	__parents = {"Preset"},
	properties = {
		{ id = "SaveIn", editor = false },
		{ id = "options_group", editor = "choice", items = SoundGroupsCombo, name = "Options Group", default = Platform.ged and "" or config.SoundGroups[1] },
		{ id = "channels", editor = "number", default = 1, min = 1 },
		{ id = "importance", editor = "number", default = 0, min = -128, max = 127, slider = true, help = "Used when trying to replace a playing sound with different sound type." },
		{ id = "volume", editor = "number", default = 100, min = 0, max = 300, slider = true}, -- TODO: write "help" items
		{ id = "ducking_preset", editor = "preset_id", name = "Ducking Preset", default = "NoDucking", preset_class = "DuckingParam", help = "Objects with lower ducking tier will reduce the volume of objects with higher ducking tier, when they are active. -1 tier is excluded from ducking" },
		{ id = "GroupVolume", editor = "number", name = "Group Volume", default = const.MaxVolume, scale = const.MaxVolume / 100, read_only = true, dont_save = true },
		{ id = "OptionsVolume", editor = "number", name = "Option Volume", default = const.MaxVolume, scale = const.MaxVolume / 100, read_only = true, dont_save = true },
		{ id = "FinalVolume", editor = "number", name = "Final Volume", default = const.MaxVolume, scale = const.MaxVolume / 100, read_only = true, dont_save = true },
		{ id = "fade_in", editor = "number", name = "Min Fade In (ms)", default = 0, help = "Min time to fade in the sound when it starts playing" },
		{ id = "replace", editor = "bool", default = true, help = "Replace a playing sound if no free channels are available" },
		{ id = "positional", editor = "bool", default = true, help = "Enable 3D (only for mono sounds)" },
		{ id = "reverb", editor = "bool", default = false, help = "Enable reverb effects for these sounds" },
		{ id = "enable", editor = "bool", default = true, help = "Disable all sounds from this type" },
		--{ id = "exclusive", editor = "bool", default = true, help = "Disable all other, non exclusive sounds" },
		{ id = "pause", editor = "bool", default = true, help = "Can be paused" },
		{ id = "restricted", editor = "bool", default = false, help = "Can be broadcast" },
		{ id = "loud_distance", editor = "number", default = DefaultSoundLoudDistance, min = 0, max = MaxSoundLoudDistance, slider = true, scale = "m", help = "No attenuation below that distance (in meters). In case of zero the sound group loud_distance is used." },
		{ id = "dbg_color", name = "Color", category = "Debug", editor = "color", default = 0, developer = true, help = "Used for sound debug using visuals", alpha = false },
		{ id = "DbgLevel", name = "Debug Level", category = "Debug", editor = "set", default = set(), max_items_in_set = 1, items = debug_levels, developer = true, dont_save = true, help = "Change the sound debug level." },
		{ id = "DbgFilter", name = "Use As Filter", category = "Debug", editor = "bool", default = false, developer = true, dont_save = true, help = "Set to sound debug filter." },
	},

	GlobalMap = "SoundTypePresets",
	GedEditor = "SoundTypeEditor",
	EditorMenubarName = "Sound Type Editor",
	EditorMenubar = "Editors.Audio",
	EditorIcon = "CommonAssets/UI/Icons/headphones.png",
}

---
--- Returns whether the sound type preset is currently set as the debug filter.
---
--- @return boolean
--- @see SoundTypePreset:SetDbgFilter
function SoundTypePreset:GetDbgFilter()
	return listener.DebugType == self.id
end

---
--- Sets or clears the sound type preset as the debug filter.
---
--- When the sound type preset is set as the debug filter, the sound debug level is
--- automatically set to 1 if it was previously 0. When the sound type preset is
--- cleared as the debug filter, the sound debug level is automatically set to 0
--- if it was previously 1.
---
--- @param value boolean
---   If true, sets the sound type preset as the debug filter.
---   If false, clears the sound type preset as the debug filter.
---
function SoundTypePreset:SetDbgFilter(value)
	if value then
		listener.DebugType = self.id
		if listener.Debug == 0 then
			listener.Debug = 1
		end
	elseif listener.DebugType == self.id then
		listener.DebugType = ""
		if listener.Debug == 1 then
			listener.Debug = 0
		end
	end
end

---
--- Returns the current sound debug level.
---
--- If the sound debug level is 0, this function returns an empty set.
--- If the sound debug level is non-zero, this function returns a set containing the current debug level.
---
--- @return table
---   A set containing the current sound debug level, or an empty set if the debug level is 0.
function SoundTypePreset:GetDbgLevel()
	if listener.Debug == 0 then
		return set()
	end
	return set(listener.Debug)
end

---
--- Sets the sound debug level.
---
--- When the sound debug level is set, it will be used to filter which sound types are
--- displayed in the debug output. Only sound types with a debug level that matches
--- the current debug level will be displayed.
---
--- @param value table
---   A set containing the desired sound debug level. If the set is empty, the debug
---   level will be set to 0 (no debug output).
function SoundTypePreset:SetDbgLevel(value)
	listener.Debug = next(value) or 0
end

---
--- Returns the editor view for the sound type preset.
---
--- The editor view is a string that displays the ID, group, and options group of the sound type preset.
--- If the preset has a debug color set, the editor view will also include a vertical bar with the color.
---
--- @return string
---   The editor view for the sound type preset.
---
function SoundTypePreset:GetEditorView()
	local txt = "<GetId>  <color 128 128 128><group>/<options_group></color>"
	if self.dbg_color ~= 0 then
		local r, g, b = GetRGB(self.dbg_color)
		txt = txt .. string.format(" <color %d %d %d>|</color>", r, g, b)
	end
	return Untranslated(txt)
end

---
--- Returns the final volume for the sound type preset.
---
--- The final volume is calculated based on the group volume and options group volume.
---
--- @return number
---   The final volume for the sound type preset.
function SoundTypePreset:GetFinalVolume()
	local _, final = GetTypeVolume(self.id)
	return final
end

---
--- Returns the volume of the sound type preset's group.
---
--- @return number
---   The volume of the sound type preset's group.
function SoundTypePreset:GetGroupVolume()
	return GetGroupVolume(self.group)
end

---
--- Returns the volume of the sound type preset's options group.
---
--- @return number
---   The volume of the sound type preset's options group.
function SoundTypePreset:GetOptionsVolume()
	return GetOptionsGroupVolume(self.options_group)
end

---
--- Returns a table of preset save locations.
---
--- The table contains a single entry with the text "Common" and an empty value.
---
--- @return table
---   A table of preset save locations.
---
function SoundTypePreset:GetPresetSaveLocations()
	return {{ text = "Common", value = "" }}
end

---
--- Returns the path where sound type presets are saved.
---
--- @return string
---   The path where sound type presets are saved.
function SoundTypePreset:GetSavePath()
	return config.SoundTypesPath
end

function OnMsg.ClassesBuilt()
	ReloadSoundTypes(true)
end

---
--- Sets the stereo property of the sound type preset.
---
--- If the stereo property is set to true, the positional and reverb properties will be set to false.
---
--- @param value boolean
---   The new value for the stereo property.
function SoundTypePreset:Setstereo(value)
	self.stereo = value
	if value then
		self.positional = false
		self.reverb = false
	end
end

---
--- Sets the reverb property of the sound type preset.
---
--- If the reverb property is set to true, the stereo property will be set to false.
---
--- @param value boolean
---   The new value for the reverb property.
function SoundTypePreset:Setreverb(value)
	self.reverb = value
	if value then
		self.stereo = false
	end
end

---
--- Sets the positional property of the sound type preset.
---
--- If the positional property is set to true, the stereo property will be set to false.
---
--- @param value boolean
---   The new value for the positional property.
function SoundTypePreset:Setpositional(value)
	self.positional = value
	if value then
		self.stereo = false
	end
end

---
--- Reloads the sound type presets.
---
--- If `reload` is true, all existing sound type presets will be destroyed and reloaded from the preset file.
--- Otherwise, the existing presets will be updated with any changes.
---
--- @param reload boolean
---   If true, all existing sound type presets will be destroyed and reloaded.
function ReloadSoundTypes(reload)
	if reload then
		for id, sound in pairs(SoundTypePresets) do
			DoneObject(sound)
		end
		assert(not next(SoundTypePresets))
		LoadPresets(SoundTypePreset:GetSavePath()) -- sound types come from a single file
	end
	RegisterTestType()
	ForEachPresetGroup(SoundTypePreset, function(group)
		LoadSoundTypes(Presets.SoundTypePreset[group])
	end)
	ApplySoundOptions(EngineOptions)
	ObjModified(Presets.SoundTypePreset)
end

------------------- Editor -----------------


function OnMsg.GedOpened(ged_id)
	local conn = GedConnections[ged_id]
	if conn and conn.app_template == SoundTypePreset.GedEditor then
		SoundTypeStatsInstance = SoundTypeStatsInstance or SoundTypeStats:new()
		conn:BindObj("stats", SoundTypeStatsInstance)
		SoundTypeStatsInstance:Refresh()
	end
end

function OnMsg.GedClosing(ged_id)
    local conn = GedConnections[ged_id]
	if conn.app_template == SoundTypePreset.GedEditor then
		ReloadSoundTypes(true)
	end
end

---
--- Callback function that is called when a property of the `SoundTypePreset` object is set in the editor.
---
--- This function updates the `SoundTypeStatsInstance` object to refresh the total number of channels used by all sound type presets.
---
--- @param prop_id string
---   The ID of the property that was set.
--- @param old_value any
---   The previous value of the property.
--- @param ged table
---   The GED (Graphical Editor) object associated with the property change.
---
function SoundTypePreset:OnEditorSetProperty(prop_id, old_value, ged)
	if SoundTypeStatsInstance then
		SoundTypeStatsInstance:Refresh()
	end
	Preset.OnEditorSetProperty(self, prop_id, old_value, ged)
end

----------------- Stats ------------------
if FirstLoad then
	SoundTypeStatsInstance = false
end

DefineClass.SoundTypeStats = {
	__parents = { "PropertyObject" },
	properties = {
		-- Stats
		{ id = "total_channels", name = "Channels", editor = "number", default = 0, category = "Stats", read_only = true},
	},
}

---
--- Refreshes the total number of channels used by all sound type presets.
---
--- This function iterates through all the `SoundTypePreset` objects and sums up the `channels` property of each one. It then updates the `total_channels` property of the `SoundTypeStats` object to reflect the new total.
---
--- @function SoundTypeStats:Refresh
--- @return nil
function SoundTypeStats:Refresh()
	
	local total_channels = 0
	ForEachPreset(SoundTypePreset, function(sound_type) 
		total_channels = total_channels + sound_type.channels
	end)
	self.total_channels = total_channels
	ObjModified(self)
end

---
--- Callback function that is called when a property of the `SoundTypePreset` object is set in the editor.
---
--- This function updates the `SoundTypeStatsInstance` object to refresh the total number of channels used by all sound type presets.
---
--- @param prop_id string
---   The ID of the property that was set.
--- @param old_value any
---   The previous value of the property.
--- @param ged table
---   The GED (Graphical Editor) object associated with the property change.
---
function SoundTypePreset:OnEditorSetProperty(obj, prop_id, old_value)
	if SoundTypeStatsInstance then
		SoundTypeStatsInstance:Refresh()
	end
end