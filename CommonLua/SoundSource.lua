MaxSoundOffset = 60 * 1000
MaxSoundLoudDistance = 200 * guim
DefaultSoundLoudDistance = 10 * guim

--- Defines a class for a one-shot sound emitter object.
---
--- This class represents an object that can emit a single sound once. It has the following properties:
--- - `__parents`: The parent classes that this class inherits from, in this case `"Object"`.
--- - `flags`: A table of flags that define the behavior of the object, in this case `{ efVisible = false, efAudible = true }`.
---
--- This class is likely used to represent objects in the game that emit a single sound, such as a gunshot or an explosion, without the need for continuous sound playback.
DefineClass.OneShotSoundEmitter = {
	__parents = { "Object" },
	flags = { efVisible = false, efAudible = true },
}

MapVar("AmbientSoundsEnabled", true)

--- Defines a class for a sound source object that can play a single sound.
---
--- This class represents an object that can play a single sound. It has the following properties:
--- - `Sound`: The sound preset to play.
--- - `GameStatesFilter`: A set of game states that determine when the sound can be played.
---
--- This class is likely used to represent objects in the game that can play a single sound, such as a gunshot or an explosion, based on the current game state.
DefineClass.SoundSourceSound = {
	__parents = { "ResolveByCopy" },
	properties = {
		{ id = "Sound", editor = "preset_id", default = "", preset_class = "SoundPreset" },
		{ id = "GameStatesFilter", name= "GameState", editor = "set", default = set(),
			three_state = true, items = function() return GetGameStateFilter() end,
			buttons = {{name = "Check Game States", func = "PropertyDefGameStatefSetCheck"}},
		},
	},
	EditorView = Untranslated("<Sound>"),
}

--- Called after a new SoundSourceSound object is created in the editor.
---
--- This function is called when a new SoundSourceSound object is created in the editor. It copies the ActivationRequiredStates property from the selected object in the editor to the GameStatesFilter property of the new SoundSourceSound object.
---
--- @param parent table The parent object of the SoundSourceSound object.
--- @param ged table The editor object associated with the SoundSourceSound object.
--- @param is_paste boolean Whether the object was pasted from the clipboard.
function SoundSourceSound:OnAfterEditorNew(parent, ged, is_paste)
	local sound_obj = ged.selected_object
	if sound_obj then
		local states = table.copy(sound_obj.ActivationRequiredStates or empty_table)
		self:SetProperty("GameStatesFilter", states)
	end
end

--- Defines a base class for a sound source object that can play multiple sounds.
---
--- This class represents an object that can play multiple sounds. It has the following properties:
--- - `Sounds`: A list of `SoundSourceSound` objects that define the sounds that can be played.
--- - `FadeTime`: The time in seconds for the sound to fade in and out.
--- - `LoudDistance`: The distance in meters at which the sound will be at maximum volume. If this is 0, the sound bank's loud distance will be used.
---
--- This class is likely used as a base class for other sound source objects in the game, providing common functionality for playing multiple sounds based on the current game state.
DefineClass.SoundSourceBase = {
	__parents = { "Object", "ComponentSound" },
	
	flags = { gofOnSurface = true, },
	
	properties = {
		{ category = "Sound", id = "Sounds", editor = "nested_list", default = false, base_class = "SoundSourceSound", inclusive = true, },
		{ category = "Sound", id = "FadeTime", editor = "number", default = 0 },
		{ category = "Sound", id = "LoudDistance", editor = "number", default = 0, min = 0, max = MaxSoundLoudDistance, slider = true, scale = "m", help = "No attenuation below that distance (in meters). In case of zero the sound bank loud distance is used." },
	},
	
	current_sound = false,
}

--- Adds a new sound entry to the SoundSourceBase object.
---
--- This function creates a new SoundSourceSound object and adds it to the Sounds table of the SoundSourceBase object. The new SoundSourceSound object is initialized with the provided sound and game state filter.
---
--- @param sound string The sound to be added.
--- @param remove_state string (optional) The game state to be removed from the filter.
--- @param states_to_set table (optional) The game states to be set as the filter.
function SoundSourceBase:AddSoundsEntry(sound, remove_state, states_to_set)
	local sounds = self.Sounds or {}
	self.Sounds = sounds
	local entry = SoundSourceSound:new{ Sound = sound }
	table.insert(sounds, entry)
	local states = table.copy(states_to_set or entry.GameStatesFilter)
	if remove_state then
		states[remove_state] = nil
	end
	entry:SetProperty("GameStatesFilter", states)
end

--- Checks if there are any sounds available for the SoundSourceBase object that match the current game state.
---
--- This function iterates through the Sounds table of the SoundSourceBase object and checks if any of the SoundSourceSound objects have a GameStatesFilter that matches the current game state. If a matching sound is found, the function returns true.
---
--- @return boolean true if there are any sounds available that match the current game state, false otherwise
function SoundSourceBase:MatchingSoundsAvailable()
	for _, sound in ipairs(self.Sounds or empty_table) do
		if MatchGameState(sound.GameStatesFilter) then
			return true
		end
	end
end

--- Checks if the specified sound is available for the SoundSourceBase object based on the current game state.
---
--- @param sound string The sound to check for availability.
--- @param is_editor boolean (optional) Whether to check for availability in the editor context.
--- @return boolean true if the sound is available, false otherwise.
function SoundSourceBase:IsSoundAvailable(sound, is_editor)
	for _, sound_source in ipairs(self.Sounds) do
		if sound_source.Sound == sound and (not is_editor or MatchGameState(sound_source.GameStatesFilter)) then
			return true
		end
	end
end

--- Gets the list of available sounds for the SoundSourceBase object based on the current game state.
---
--- This function iterates through the Sounds table of the SoundSourceBase object and checks if any of the SoundSourceSound objects have a GameStatesFilter that matches the current game state. If a matching sound is found, it is added to the list of available sounds. The function returns the list of available sounds.
---
--- @param ignore_editor boolean (optional) Whether to ignore the editor context when checking for available sounds.
--- @return table|string The list of available sounds, or a single sound if only one is available.
function SoundSourceBase:GetAvailableSounds(ignore_editor)
	local sounds
	for _, sound in ipairs(self.Sounds or empty_table) do
		if (ignore_editor or not IsEditorActive()) and MatchGameState(sound.GameStatesFilter) then
			if not sounds then
				sounds = sound.Sound
			elseif type(sounds) == "table" then
				table.insert_unique(sounds, sound.Sound)
			elseif sounds ~= sound.Sound then
				sounds = { sounds, sound.Sound }
			end
		end
	end
	return sounds
end

--- Gets the list of available sounds for the SoundSourceBase object based on the current game state.
---
--- This function iterates through the Sounds table of the SoundSourceBase object and checks if any of the SoundSourceSound objects have a GameStatesFilter that matches the current game state. If a matching sound is found, it is added to the list of available sounds. The function returns the list of available sounds.
---
--- @param ignore_editor boolean (optional) Whether to ignore the editor context when checking for available sounds.
--- @return table|string The list of available sounds, or a single sound if only one is available.
function SoundSourceBase:GetAvailableSoundsList(ignore_editor)
	local sounds = self:GetAvailableSounds(ignore_editor)
	if not sounds then
		return empty_table
	end
	if type(sounds) ~= "table" then
		return { sounds }
	end
	return sounds
end

--- Picks a random available sound from the SoundSourceBase object.
---
--- This function first retrieves the list of available sounds using the `GetAvailableSounds()` function. If the list contains only one sound, that sound is returned. If the list contains multiple sounds, a random sound is selected and returned.
---
--- @return string The selected sound, or an empty string if no sounds are available.
function SoundSourceBase:PickSound()
	local sounds = self:GetAvailableSounds()
	if type(sounds) ~= "table" then
		return sounds
	elseif #sounds < 2 then
		return sounds[1]
	end
	return sounds[AsyncRand(#sounds) + 1]
end

--- Replays the sound associated with the SoundSourceBase object.
---
--- This function first checks if ambient sounds are enabled and if the SoundSourceBase object is valid. If either of these conditions is not met, the function returns without doing anything.
---
--- The function then retrieves a random available sound using the `PickSound()` function. If no sounds are available, an empty string is returned.
---
--- The function then sets the sound using the `SetSound()` function, passing the selected sound, a volume of 1000, the provided fade time (or 0 if not provided), and the LoudDistance property of the SoundSourceBase object (or -1 if LoudDistance is 0).
---
--- @param fade_time number (optional) The fade time for the sound, in milliseconds.
function SoundSourceBase:ReplaySound(fade_time)
	if not AmbientSoundsEnabled or not IsValid(self) then
		return
	end
	local sound = self:PickSound() or ""
	-- negative values in SetSound will lead to the SoundBank's loud_distance being used
	local loud_distance = self.LoudDistance ~= 0 and self.LoudDistance or -1
	self:SetSound(sound, 1000, fade_time or 0, loud_distance)
end

--- Sets the sound for the SoundSourceBase object.
---
--- If the provided `sound` parameter is an empty string or `nil`, the current sound is cleared and the sound is stopped after a 3000 millisecond fade.
---
--- Otherwise, the current sound is set to the provided `sound` parameter, and the sound is played using the `Object.SetSound()` function with the remaining parameters.
---
--- @param sound string|nil The sound to set, or `nil` to clear the current sound.
--- @param ... any Additional parameters to pass to `Object.SetSound()`.
--- @return any The result of calling `Object.SetSound()`.
function SoundSourceBase:SetSound(sound, ...)
	if (sound or "") == "" then
		sound = nil
	end
	self.current_sound = sound
	if not sound then
		self:StopSound(3000)
		return
	end
	return Object.SetSound(self, sound, ...)
end

--- Interrupts the current sound being played by the SoundSourceBase object.
---
--- This function sets the `current_sound` property of the SoundSourceBase object to `false`, indicating that there is no current sound playing. It then calls the `StopSound()` function, passing the `fade_time` parameter (or the `FadeTime` property of the object if `fade_time` is not provided). This will stop the current sound after the specified fade time.
---
--- @param fade_time number (optional) The fade time for stopping the sound, in milliseconds.
function SoundSourceBase:InterruptSound(fade_time)
	self.current_sound = false
	fade_time = fade_time or self.FadeTime
	self:StopSound(fade_time)
end

--- Interrupts the current sound being played and replays a new sound with the specified fade time.
---
--- This function first calls `InterruptSound()` to stop the current sound being played. It then calls `ReplaySound()` to select a new random sound and play it, using the `FadeTime` property of the `SoundSourceBase` object as the fade time.
---
--- @param self SoundSourceBase The `SoundSourceBase` object to set up the sound for.
function SoundSourceBase:SetupSound()
	self:InterruptSound()
	self:ReplaySound(self.FadeTime)
end

--- Returns the editor label for the SoundSourceBase object.
---
--- The label is composed of the class name of the object. If the object has any sounds defined in the `Sounds` property, the label will also include a comma-separated list of the sound IDs, truncated to 40 characters if necessary.
---
--- @return string The editor label for the SoundSourceBase object.
function SoundSourceBase:GetEditorLabel()
	local label = self.class
	if self.Sounds and #self.Sounds > 0 then
		local sound_ids = table.map(self.Sounds, "Sound")
		label = label .. " (" .. string.trim(table.concat(sound_ids, ", "), 40, "...") .. ")"
	end
	return label
end

--- Provides functionality for automatically resolving sound sources.
---
--- The `SoundSourceAutoResolve` class is used to automatically resolve sound sources based on various conditions, such as game state and other factors. It is typically used as a parent class for other sound-related classes to inherit its functionality.
---
--- This class is not intended to be used directly, but rather as a base class for other sound-related classes.
DefineClass("SoundSourceAutoResolve")

--- Defines a class `SoundSourceBaseImpl` that inherits from `EditorTextObject`, `SoundSourceBase`, `StripCObjectProperties`, and `SoundSourceAutoResolve`.
---
--- This class represents a sound source object in the game editor. It has the following properties:
---
--- - `flags`: A table of flags that define the object's behavior, such as being permanent and a marker.
--- - `editor_text_spot`: A boolean indicating whether the object has an editor text spot.
--- - `editor_text_offset`: The offset of the editor text from the object's position.
--- - `editor_text_style`: The style of the editor text.
--- - `entity`: The entity type of the object.
--- - `color_modifier`: The color modifier for the object.
--- - `mesh_max_loud`: A boolean indicating whether the object has a maximum loudness mesh.
--- - `mesh_min_loud`: A boolean indicating whether the object has a minimum loudness mesh.
--- - `entity_scale`: The scale of the object's entity.
--- - `prefab_no_fade_clamp`: A boolean indicating whether the object's prefab has no fade clamp.
--- - `editor_interrupted`: A boolean indicating whether the object's editor has been interrupted.
DefineClass.SoundSourceBaseImpl = 
{
	__parents = {"EditorTextObject", "SoundSourceBase", "StripCObjectProperties", "SoundSourceAutoResolve"},
	flags = { gofPermanent = true, efMarker = true },
	editor_text_spot = false,
	editor_text_offset = point(0, 0, 50*guic),
	editor_text_style = "SoundSourceText",
	entity = "SpotHelper",
	color_modifier = RGB(100, 100, 0),
	mesh_max_loud = false,
	mesh_min_loud = false,
	entity_scale = 250,
	prefab_no_fade_clamp = true,
	editor_interrupted = false,
}

--- Returns the color to use for the editor text of the SoundSourceBaseImpl object.
---
--- If there are any available sounds for the object, the color will be white. Otherwise, the color will be red.
---
--- @return color The color to use for the editor text.
function SoundSourceBaseImpl:EditorGetTextColor()
	return self:MatchingSoundsAvailable() and const.clrWhite or const.clrRed
end

--- Returns the editor text for the SoundSourceBaseImpl object.
---
--- If there are no available sounds for the object, the editor text will list the class name and any mismatching game state filters for the object's sounds. Otherwise, the editor text will be a slash-separated list of the available sounds.
---
--- @return string The editor text for the SoundSourceBaseImpl object.
function SoundSourceBaseImpl:EditorGetText()
	local sounds = self:GetAvailableSoundsList("ignore editor")
	if not next(sounds) then
		local mismatching = {self.class}
		for _, sound_descr in ipairs(self.Sounds) do
			local row = {}
			for name, state in pairs(sound_descr.GameStatesFilter) do
				if state ~= GameState[name] then
					table.insert(row, string.format("%s%s", state and "" or "NOT ", name))
				end
			end
			if #row > 0 then
				table.insert(mismatching, string.format("%s: %s", sound_descr.Sound, table.concat(row, ", ")))
			end
		end
		
		return table.concat(mismatching, "\n")
	else
		return table.concat(sounds, "/")
	end
end

--- Initializes the SoundSourceBaseImpl object.
---
--- Sets the scale and color modifier of the object.
function SoundSourceBaseImpl:Init()
	self:SetScale(self.entity_scale)
	self:SetColorModifier(self.color_modifier)
end

--- Initializes the SoundSourceBaseImpl object by setting up the sound.
function SoundSourceBaseImpl:GameInit()
	self:SetupSound()
end

--- Called when a property of the SoundSourceBaseImpl object is set in the editor.
---
--- Updates the sound setup and mesh visualization for the object.
---
--- @param prop_id The ID of the property that was set.
--- @param old_value The previous value of the property.
--- @param ged The editor GUI element that triggered the property change.
function SoundSourceBaseImpl:OnEditorSetProperty(prop_id, old_value, ged)
	self:SetupSound()
	self:UpdateMesh()
end

--- Resolves the loud distance for the SoundSourceBaseImpl object.
---
--- If the LoudDistance property is set to 0, this function will determine the maximum loud distance
--- of all the available sounds for the object by checking the loud_distance property of the sound presets.
---
--- @return number The resolved loud distance for the SoundSourceBaseImpl object.
function SoundSourceBaseImpl:ResolveLoudDistance()
	local radius = self.LoudDistance
	if radius == 0 then
		local sounds = SoundPresets
		for _, sound in ipairs(self:GetAvailableSoundsList("ignore editor")) do
			local preset = sounds[sound]
			if preset then
				radius = Max(radius, preset.loud_distance)
			end
		end
	end
	return radius
end

--- Generates a hash value for the list of available sounds for the SoundSourceBaseImpl object.
---
--- The hash is generated using the xxhash algorithm and the list of available sounds, excluding any sounds marked as "ignore editor".
---
--- @return number The hash value for the list of available sounds.
function SoundSourceBaseImpl:GetSoundHash()
	return xxhash(table.unpack(self:GetAvailableSoundsList("ignore editor")))
end

---
--- Updates the mesh visualization for the SoundSourceBaseImpl object.
---
--- This function is responsible for updating the mesh visualization for the SoundSourceBaseImpl object. It determines the visibility of the mesh based on whether the object is selected in the editor or if the debug mode is enabled. It then sets the scale and color of the mesh elements based on the resolved loud distance and mute threshold.
---
--- If the object is selected in the editor or the debug mode is enabled, the function will:
--- - Set the visibility of the max loud mesh to be visible
--- - Set the scale of the max loud mesh to the resolved loud distance
--- - Set the color of the max loud mesh to white if selected, or orange if not
--- - Set the visibility of the min loud mesh to be visible
--- - Set the scale of the min loud mesh to the mute threshold
--- - Set the color of the min loud mesh to magenta if selected, or red if not
---
--- If the object is not visible, the function will clear the visibility of both the max loud and min loud meshes.
---
--- If the editor is active, the function will interrupt the sound playback and mark the object as editor interrupted. If the object is selected, the function will replay the sound with the fade time.
---
--- @return nil
function SoundSourceBaseImpl:UpdateMesh()
	local debug = listener and listener.Debug or 0
	local editor_selected = editor.IsSelected(self)
	local visible = editor_selected or debug > 0
	if visible then
		local radius = self:ResolveLoudDistance()
		if IsValid(self.mesh_max_loud) then
			self.mesh_max_loud:SetEnumFlags(const.efVisible)
			self.mesh_max_loud:SetScale(MulDivRound(radius, 100, MulDivRound(100*guim, self:GetScale(), 100)))
			self.mesh_max_loud:SetColorModifier( editor_selected and const.clrWhite or const.clrOrange )
		end
		if IsValid(self.mesh_min_loud) then
			self.mesh_min_loud:SetEnumFlags(const.efVisible)
			local mute_threshold = tonumber(listener.PlayThreshold) * radius
			self.mesh_min_loud:SetScale(MulDivRound(mute_threshold, 100, MulDivRound(100*guim, self:GetScale(), 100)))
			self.mesh_min_loud:SetColorModifier( editor_selected and const.clrMagenta or const.clrRed )
		end
	else
		if IsValid(self.mesh_max_loud) then
			self.mesh_max_loud:ClearEnumFlags(const.efVisible)
		end
		if IsValid(self.mesh_min_loud) then
			self.mesh_min_loud:ClearEnumFlags(const.efVisible)
		end
	end
	if IsEditorActive() then
		self:InterruptSound()
		self.editor_interrupted = true
		if editor_selected then
			self.editor_interrupted = false
			self:ReplaySound(self.FadeTime)
		end
	end
end

--- Checks if the SoundSourceBaseImpl object is currently underground.
---
--- @return boolean true if the object is underground, false otherwise
function SoundSourceBaseImpl:IsUnderground()
	local pos = self:GetPos()
	local z_offset = self:GetObjectBBox():sizez()
	return pos:IsValidZ() and (pos:z() + z_offset < terrain.GetHeight(pos))
end

--- The `SoundSource` class is a subclass of `EditorVisibleObject` and `SoundSourceBaseImpl`. It represents a sound source object in the game.
DefineClass.SoundSource = 
{
	__parents = {"EditorVisibleObject", "SoundSourceBaseImpl"},
}

--- Called when the SoundSource object enters the editor.
---
--- This function sets the SoundSource object as visible, creates two circle meshes to represent the maximum and minimum loudness radii, attaches them to the SoundSource object, and calls the `UpdateMesh()` function to update the visual representation of the sound source.
---
--- @param ... any additional arguments passed to the function
function SoundSource:EditorEnter(...)
	self:SetEnumFlags(const.efVisible)
	self.mesh_max_loud = CreateCircleMesh(100*guim, const.clrWhite, point30)
	self.mesh_min_loud = CreateCircleMesh(100*guim, const.clrWhite, point30)
	self:Attach(self.mesh_max_loud)
	self:Attach(self.mesh_min_loud)
	self:UpdateMesh()
end

--- Called when the SoundSource object exits the editor.
---
--- This function destroys the two circle meshes that were created to represent the maximum and minimum loudness radii, and sets the mesh references to `nil`.
---
--- @param ... any additional arguments passed to the function
function SoundSource:EditorExit(...)
	DoneObject(self.mesh_max_loud)
	DoneObject(self.mesh_min_loud)
	self.mesh_max_loud = nil
	self.mesh_min_loud = nil
end

--- Called when the editor selection changes.
---
--- This function updates the mesh of all `SoundSource` objects in the map to reflect the current editor selection.
function OnMsg:EditorSelectionChanged()
	MapForEach("map", "SoundSource", SoundSource.UpdateMesh)
end

--- Updates the sound source object.
---
--- This function checks if the sound for the current sound source object is available. If the sound is not available, it calls the `SetupSound()` function to set up the sound.
---
--- @param obj SoundSource The sound source object to update.
--- @param is_editor boolean Whether the game is in editor mode or not.
function UpdateSoundSource(obj, is_editor)
	if not obj:IsSoundAvailable(obj.current_sound, is_editor) then
		obj:SetupSound()
	end
end

MapVar("UpdateSoundSourcesThread", false)
MapVar("MapSoundBoxesCover", false)
PersistableGlobals.MapSoundBoxesCover = false

---
--- Updates all SoundSource objects in the map after a delay.
---
--- This function creates a persistent thread that iterates through the map's sound boxes and updates each SoundSource object within those boxes. The updates are performed with a delay to avoid overwhelming the system.
---
--- @param delay number The delay in milliseconds between updates of each sound source.
function UpdateSoundSourcesDelayed(delay)
	DeleteThread(UpdateSoundSourcesThread)
	MapSoundBoxesCover = MapSoundBoxesCover or GetMapBoxesCover(config.MapSoundBoxesCoverParts or 8, "MapSoundBoxesCover")
	UpdateSoundSourcesThread = CreateMapRealTimeThread(function(delay)
		local count = #MapSoundBoxesCover
		for i, box in ipairs(MapSoundBoxesCover) do
			MapForEach(box, "SoundSource", UpdateSoundSource, IsEditorActive())
			Sleep((i + 1) * delay / count - i * delay / count)
		end
		UpdateSoundSourcesThread = false
	end, delay or config.MapSoundUpdateDelay or 1000)
	MakeThreadPersistable(UpdateSoundSourcesThread)
end

---
--- Updates all SoundSource objects in the map instantly.
---
--- This function iterates through all SoundSource objects in the map and calls the `UpdateSoundSource()` function on each one, passing the `IsEditorActive()` flag to indicate whether the game is in editor mode or not.
---
--- This function is called in response to the `PostNewMapLoaded` message, ensuring that all sound sources are updated when a new map is loaded.
---
--- @param is_editor boolean Whether the game is in editor mode or not.
function UpdateSoundSourcesInstant()
	MapForEach("map", "SoundSource", UpdateSoundSource, IsEditorActive())
end

OnMsg.PostNewMapLoaded = UpdateSoundSourcesInstant

--- Listens for the `GameStateChanged` message and updates all `SoundSource` objects in the map when a relevant game state is changed.
---
--- This function is called whenever the game state changes. It checks if the map has been changed or if the current map is empty. If neither of these conditions is true, it iterates through the changed game states and checks if any of them are defined in the `GameStateDefs` table. If a relevant game state is found, the `UpdateSoundSourcesDelayed()` function is called to update all `SoundSource` objects in the map.
---
--- @param changed table A table of game state IDs that have changed.
function OnMsg.GameStateChanged(changed)
	if ChangingMap or GetMap() == "" then return end
	local GameStateDefs = GameStateDefs
	for id, v in sorted_pairs(changed) do
		if GameStateDefs[id] then -- if a game state is changed, update sound sources
			UpdateSoundSourcesDelayed()
			break
		end
	end
end

---
--- Checks for errors in a SoundSource object.
---
--- This function checks if the SoundSource object is underground, and if any of the sound banks referenced by the Sounds property are invalid. It returns a string containing a newline-separated list of any errors found.
---
--- @return string|nil A string containing a newline-separated list of errors, or nil if no errors were found.
function SoundSourceAutoResolve:GetError()
	local errors = {}
	if self:IsUnderground() then
		table.insert(errors, "SoundSource underground - move it manually up!")
	end
	
	local invalid_sound_banks = {}
	for _, sound in ipairs(self.Sounds) do
		local prop_meta = sound:GetPropertyMetadata("Sound")
		local extra = prop_meta.extra_item
		local bank = sound.Sound
		if bank and bank ~= "" and bank ~= extra and not PresetIdPropFindInstance(sound, prop_meta, bank) then
			table.insert(invalid_sound_banks, bank)
		end
	end
	if #invalid_sound_banks > 0 then
		table.insert(errors, "Invalid sound banks: " .. table.concat(invalid_sound_banks, " "))
	end
	
	if #errors > 0 then
		return table.concat(errors, "\n")
	end
end

--- Restarts all ambient sounds in the map by calling the `SetupSound()` method on each `SoundSource` object.
---
--- This function is called when the game is loaded or saved to ensure that all ambient sounds are properly set up and playing. It iterates through all `SoundSource` objects in the map and calls the `SetupSound()` method on each one, which ensures that the sound is properly configured and playing.
---
--- @function SavegameFixups.RestartAmbientSounds
--- @return nil
function SavegameFixups.RestartAmbientSounds()
	MapForEach("map", "SoundSource", function(obj)
		obj:SetupSound()
	end)
end

if Platform.developer then

-- TODO Remove when GetError starts getting called on map save and load.
---
--- Checks the map for errors in SoundSource objects.
---
--- This function iterates through all SoundSource objects in the map and calls the `GetError()` method on each one. If any errors are found, it stores them using the `StoreErrorSource()` function.
---
--- @function CheckMapForErrors
--- @return nil
local function CheckMapForErrors()
	MapForEach("map", "SoundSource", function(ss)
		local err = ss:GetError()
		if err then
			StoreErrorSource(ss, err)
		end
	end)
end

OnMsg.SaveMap = CheckMapForErrors
OnMsg.NewMapLoaded = CheckMapForErrors

end
