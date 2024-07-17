DefineClass("Tree", "EntityClass")

DefineClass.BaseFlag = {
	__parents = { "Object" },
}

--- Initializes the animation phase for the object.
---
--- This function sets the initial animation phase for the object, using a random value within the duration of the animation.
---
--- @param self BaseFlag The object instance.
function BaseFlag:Init()
	-- commented variants do not produce good results (half of the placed objects have animations phase very close to each other)
	--local phase = BraidRandom(EncodeVoxelPos(self) % max_int, duration)
	--local phase = BraidRandom(point_pack(self:GetPosXYZ()) % max_int, duration)

	local duration = GetAnimDuration(self:GetEntity(), self:GetAnim())
	local phase = AsyncRand(duration)
	self:SetAnimPhase(1, phase)
end

function OnMsg.ClassesGenerate()
	table.iappend(Light.properties, {
		{category = "Visuals", id = "NightOnly", name = "Night Only", editor = "bool", default = false},
	})
end

--- Gets the stored night-only intensity 0 for this object.
---
--- @param self BaseFlag The object instance.
--- @return number The stored night-only intensity 0.
function GetStoredNightOnlyIntensity0(self)
	return self._nightonly_intensity0
end

--- Sets the stored night-only intensity 0 for this object.
---
--- @param self BaseFlag The object instance.
--- @param intensity number The new night-only intensity 0 to set.
function SetStoredNightOnlyIntensity0(self, intensity)
	self._nightonly_intensity0 = intensity
end

--- Gets the stored night-only intensity 1 for this object.
---
--- @param self BaseFlag The object instance.
--- @return number The stored night-only intensity 1.
function GetStoredNightOnlyIntensity1(self)
	return self._nightonly_intensity1
end

--- Sets the stored night-only intensity 1 for this object.
---
--- @param self BaseFlag The object instance.
--- @param intensity number The new night-only intensity 1 to set.
function SetStoredNightOnlyIntensity1(self, intensity)
	self._nightonly_intensity1 = intensity
end

---
--- Applies night-only settings to lights in the map.
---
--- @param night boolean Whether it is night or not.
function ApplyNightOnly(night)
	MapForEach("map", "Light", function(light)
		if light.NightOnly then
			if night then
				if rawget(light, "_nightonly_intensity0") then
					light.SetIntensity0, light.GetIntensity0 = nil, nil
					light.SetIntensity1, light.GetIntensity1 = nil, nil
					light:SetIntensity0(light._nightonly_intensity0)
					light:SetIntensity1(light._nightonly_intensity1)
					light._nightonly_intensity0 = false
					light._nightonly_intensity1 = false
				end
			else
				if not rawget(light, "_nightonly_intensity0") then
					light._nightonly_intensity0 = light:GetIntensity0()
					light._nightonly_intensity1 = light:GetIntensity1()
					light:SetIntensity0(0)
					light:SetIntensity1(0)
					light.GetIntensity0, light.SetIntensity0 = GetStoredNightOnlyIntensity0, SetStoredNightOnlyIntensity0
					light.GetIntensity1, light.SetIntensity1 = GetStoredNightOnlyIntensity1, SetStoredNightOnlyIntensity1
				end
			end
		end
	end)
end

function OnMsg.GameEnterEditor()
	ApplyNightOnly(true)
end

function OnMsg.GameExitEditor()
	ApplyNightOnly(GameState.Night)
end

function OnMsg.GameStateChanged(changed)
	if changed.Night then
		ApplyNightOnly(true)
	elseif changed.Day or changed.Sunrise or changed.Sunset then
		ApplyNightOnly(false)
	end
end

function OnMsg.NewMapLoaded()
	if GameState.Night then
		ApplyNightOnly(true)
	elseif GameState.Day or GameState.Sunrise or GameState.Sunset then
		ApplyNightOnly(false)
	end
end

--[[
	To create objects which play sound depending on which state they are placed on the map:
	- manually create a class for them inheriting DecorStateFXObject, or set DecorStateFXObject as parent class for them in the ArtSpec
	- in the FX editor, create a new ActionFXSound for each of the states you want to associate with sounds, with the following properties
		- Action: DecorState
		- Moment: start
		- Actor: choose the class of the object
		- Target: type the name of the state
		- Sound: choose the sound bank from the list
		- AttachToObj: check
	- if you want the sound to stop when the object switches to another state:	
		- in EndRules: click "Add", then in EndMoment add "end"
]]

local function GetParticlesType(pattern)
	local items = {}
	for name in pairs(ParticleSystemPresets) do
		if string.match(name, pattern) then
			table.insert(items, name)
		end
	end
	table.insert(items, "")
	table.sort(items)
	return items
end

DefineClass.DecorGameStatesFilter = {
	__parents = {"Object", "EditorTextObject"},

	properties = {
		{ category = "DecorStateFXObject", id = "ActivationRequiredStates", name = "Map States", 
			editor = "set", three_state = true, default = false,
			items = function() return GetGameStateFilter() end,
			buttons = {{name = "Check Game States", func = "PropertyDefGameStatefSetCheck"}},
			help = "Click once for the states required to be enabled(green), twice for the states required to be disabled(red). All other states are don't care.",
		},
	},
	
	editor_text_offset = point(0, 0, 150 * guic),

	old_map_states = false,	-- objects's map states we are interested in during the last GameState
	activated = false,
}

---
--- Initializes the `DecorGameStatesFilter` object by setting up the `old_map_states` table with the current game state values.
--- This function is called when the object is first created or loaded.
---
--- @function DecorGameStatesFilter:GameInit
--- @return nil
function DecorGameStatesFilter:GameInit()
	self.old_map_states = {}
	for state in pairs(self.ActivationRequiredStates) do
		self.old_map_states[state] = not not GameState[state]
	end
	self:UpdateGameState()
end

---
--- Updates the game state of the `DecorGameStatesFilter` object.
--- This function is called when the game state changes to update the object's activation state.
---
--- @function DecorGameStatesFilter:UpdateGameState
--- @return nil
function DecorGameStatesFilter:UpdateGameState()
	if not self.old_map_states then return end

	local is_destroyed = IsGenericObjDestroyed(self)
	local should_be_active = not is_destroyed
	if should_be_active then
		for state, required_value in pairs(self.ActivationRequiredStates) do
			local game_state_value = not not GameState[state]
			should_be_active = should_be_active and (required_value == game_state_value)
			if game_state_value ~= self.old_map_states[state] then
				self.old_map_states[state] = game_state_value
				PlayFX(state, game_state_value and "start" or "end", self, self:GetStateText())
			end
		end
	end
	self.activated = should_be_active
	self:OnGameStateUpdated()
	self:EditorTextUpdate()
end

local efVisible = const.efVisible
local efVisibleNot = bnot(efVisible)

---
--- Sets the enum flags for the object.
--- If the `efVisible` flag is set, and the object is a "ParticleSoundPlaceholder" and the editor is not active, the `efVisible` flag is cleared.
--- The object's enum flags are then set using the provided `flags` value.
---
--- @param flags number The enum flags to set for the object.
--- @return nil
function DecorGameStatesFilter:SetEnumFlags(flags)
	if band(flags, efVisible) ~= 0 then
		if not IsEditorActive() and self:GetEntity() == "ParticleSoundPlaceholder" then
			flags = band(flags , efVisibleNot)
		end
	end
	Object.SetEnumFlags(self, flags)
end

---
--- Callback function that is called when the game state of the `DecorGameStatesFilter` object is updated.
---
--- If the object has no activation states defined (`GetNumStates() == 0`), then:
--- - If the object is currently activated and the editor is active, the `efVisible` enum flag is set.
--- - If the object is not activated or the editor is not active, the `efVisible` enum flag is cleared.
---
--- @function DecorGameStatesFilter:OnGameStateUpdated
--- @return nil
function DecorGameStatesFilter:OnGameStateUpdated()
	if self:GetNumStates() == 0 then
		if self.activated and IsEditorActive() then
			self:SetEnumFlags(efVisible)
		else
			self:ClearEnumFlags(efVisible)
		end
	end
end

---
--- Callback function that is called when the `DecorGameStatesFilter` object enters the editor.
---
--- If the object has no activation states defined (`GetNumStates() == 0`), the `efVisible` enum flag is set.
---
--- @function DecorGameStatesFilter:EditorEnter
--- @return nil
function DecorGameStatesFilter:EditorEnter()
	EditorTextObject.EditorEnter(self)
	if self:GetNumStates() == 0 then
		self:SetEnumFlags(efVisible)	
	end
end

---
--- Callback function that is called when the `DecorGameStatesFilter` object exits the editor.
---
--- This function calls the `EditorExit` function of the `EditorTextObject` class, and then updates the game state of the object.
---
--- @function DecorGameStatesFilter:EditorExit
--- @return nil
function DecorGameStatesFilter:EditorExit()
	EditorTextObject.EditorExit(self)
	self:UpdateGameState()
end

---
--- Generates a text string that describes the current game state of the `DecorGameStatesFilter` object.
---
--- If the object's `ActivationRequiredStates` do not match the current game state, the text will include a list of the mismatched states.
---
--- @function DecorGameStatesFilter:EditorGetText
--- @return string The text describing the current game state
function DecorGameStatesFilter:EditorGetText()
	local text = ""
	
	if not MatchGameState(self.ActivationRequiredStates) then
		local mismatch_states = {"Mismatch States:"}
		for state, active in pairs(self.ActivationRequiredStates) do
			local game_state_active = not not GameState[state]
			if active ~= game_state_active then
				table.insert(mismatch_states, state) 
			end
		end
		text = string.format("%s\n%s", text, table.concat(mismatch_states, " "))
	end
	
	return text
end

---
--- Gets the text color for the editor display of the `DecorGameStatesFilter` object.
---
--- If the object's `ActivationRequiredStates` match the current game state, the text color is the same as the `EditorTextObject` class. Otherwise, the text color is set to red.
---
--- @return string The text color for the editor display
function DecorGameStatesFilter:EditorGetTextColor()
	return MatchGameState(self.ActivationRequiredStates) and EditorTextObject.EditorGetTextColor(self) or const.clrRed
end

DefineClass.DecorStateFXObject = {
	__parents = { "Object", "FXObject", "DecorGameStatesFilter" },
	
	properties = {
		{ id = "Pos",  name = "Pos",    editor = "point",  default = InvalidPos(),     help = "in meters", scale = "m" },
		{ id = "Angle", editor = "number", default = 0, min = 0, max = 360*60 - 1, slider = true, scale = "deg"},
		{ category = "DecorStateFXObject", id = "Preset", editor = "dropdownlist", default = "",
			items = function(self) return GetParticlesType(self.particles_pattern) end,
		},
	},
	
	place_category = false,
	place_name = false,
	
	particles_pattern = "",
	entity_scale = 100,
	
	particles = false,
}

---
--- Initializes the `DecorStateFXObject` by setting its scale to `entity_scale`.
---
--- This function is called during the initialization of the `DecorStateFXObject` to set its scale to the specified `entity_scale` value.
---
--- @function DecorStateFXObject:Init
function DecorStateFXObject:Init()
	self:SetScale(self.entity_scale)
end

---
--- Initializes the `DecorStateFXObject` by setting its state, handling attached lights, resetting the voxel stealth parameters cache, and placing particles.
---
--- This function is called during the initialization of the `DecorStateFXObject` to perform various setup tasks. It sets the object's state, handles any attached lights, resets the voxel stealth parameters cache, and places the particles associated with the object.
---
--- @function DecorStateFXObject:GameInit
function DecorStateFXObject:GameInit()
	CreateGameTimeThread(function()
		Sleep(1) -- workaround for sound FX being disabled during map load, pending investigation
		if IsValid(self) then
			self:SetState(self:GetState())
			self:ForEachAttach("Light", Stealth_HandleLight)
			ResetVoxelStealthParamsCache()
		end
	end)
	self:PlaceParticles()
end

---
--- Destroys the particles associated with the `DecorStateFXObject`.
---
--- This function is called to clean up the particles when the `DecorStateFXObject` is being destroyed. It calls the `DestroyParticles` function to remove the particles from the scene.
---
--- @function DecorStateFXObject:Done
function DecorStateFXObject:Done()
	self:DestroyParticles()
end

---
--- Sets the position of the `DecorStateFXObject` and its associated particles.
---
--- This function is called to update the position of the `DecorStateFXObject` and any attached particles. It first sets the position of the object using the `Object.SetPos` function, and then updates the position of the particles if they exist.
---
--- @param pos The new position to set for the object and its particles.
--- @param ... Additional arguments to pass to the `Object.SetPos` function.
---
function DecorStateFXObject:SetPos(pos, ...)
	Object.SetPos(self, pos, ...)
	if self.particles then
		self.particles:SetPos(pos, ...)
	end
end

---
--- Sets the angle of the `DecorStateFXObject` and its associated particles.
---
--- This function is called to update the angle of the `DecorStateFXObject` and any attached particles. It first sets the angle of the object using the `Object.SetAngle` function, and then updates the angle of the particles if they exist.
---
--- @param angle The new angle to set for the object and its particles.
--- @param ... Additional arguments to pass to the `Object.SetAngle` function.
---
function DecorStateFXObject:SetAngle(angle, ...)
	Object.SetAngle(self, angle, ...)
	if self.particles then
		self.particles:SetAngle(angle, ...)
	end
end

---
--- Destroys the particles associated with the `DecorStateFXObject`.
---
--- This function is called to clean up the particles when the `DecorStateFXObject` is being destroyed. It calls the `DestroyParticles` function to remove the particles from the scene.
---
function DecorStateFXObject:DestroyParticles()
	if not self.particles then return end
	
	DoneObject(self.particles)
	self.particles = false
end

---
--- Places the particles associated with the `DecorStateFXObject` based on the configured preset.
---
--- This function is called to create and position the particles for the `DecorStateFXObject`. It first checks if a particle system preset is configured for the object. If so, it places the particles using the `PlaceParticles` function, sets the `HelperEntity` property to `false`, and positions the particles at the same position and angle as the `DecorStateFXObject`.
---
--- @function DecorStateFXObject:PlaceParticles
function DecorStateFXObject:PlaceParticles()
	if not ParticleSystemPresets[self.Preset] then return end
	
	self.particles = PlaceParticles(self.Preset)
	self.particles.HelperEntity = false
	self.particles:SetPos(self:GetPos())	
	self.particles:SetAngle(self:GetAngle())
end

---
--- Handles updating the particle system when the `Preset` property of the `DecorStateFXObject` is changed.
---
--- This function is called when the `Preset` property of the `DecorStateFXObject` is updated. It first destroys the existing particle system associated with the object, and then creates a new particle system based on the updated preset.
---
function DecorStateFXObject:OnEditorSetProperty(prop_id)
	if prop_id == "Preset" then
		self:DestroyParticles()
		self:PlaceParticles()
	end
end

---
--- Sets the state of the `DecorStateFXObject` and plays the appropriate FX.
---
--- This function is called to update the state of the `DecorStateFXObject`. It first plays the "end" FX for the previous state, then calls the `Object.SetState` function to update the state. If the object is visible, it then plays the "start" FX for the new state, unless the object is an `AutoAttachObject` and its `AutoAttachMode` is set to "OFF".
---
--- @param ... Additional arguments to pass to the `Object.SetState` function.
---
function DecorStateFXObject:SetState(...)
	PlayFX("DecorState", "end", self, self:GetStateText())
	Object.SetState(self, ...)
	if self:GetEnumFlags(efVisible) ~= 0 then
		if not self:IsKindOf("AutoAttachObject") or self:GetAutoAttachMode() ~= "OFF" then
			-- NOTE: some lights are playng their sounds on their single "idle" anim despite beiing turner OFF
			PlayFX("DecorState", "start", self, self:GetStateText())
		end
	end
end

---
--- Handles updating the visibility of the particle system associated with the `DecorStateFXObject` when the game state is updated.
---
--- This function is called when the game state of the `DecorStateFXObject` is updated. It first checks if the object has a particle system associated with it. If so, it sets the visibility of the particle system based on the `activated` property of the object. If the object is activated, the particle system is made visible, otherwise it is hidden.
---
--- @function DecorStateFXObject:OnGameStateUpdated
function DecorStateFXObject:OnGameStateUpdated()
	DecorGameStatesFilter.OnGameStateUpdated(self)
	if self.particles then	
		if self.activated then
			self.particles:SetEnumFlags(efVisible)
		else
			self.particles:ClearEnumFlags(efVisible)
		end
	end
end

---
--- Called when the DecorStateFXObject enters the editor.
---
--- This function is called when the DecorStateFXObject enters the editor. It first calls the `DecorGameStatesFilter.EditorEnter` function, and then sets the `efVisible` enum flag on the `particles` object associated with the DecorStateFXObject, making it visible in the editor.
---
function DecorStateFXObject:EditorEnter()
	DecorGameStatesFilter.EditorEnter(self)
	if self.particles then
		self.particles:SetEnumFlags(efVisible)
	end
end

---
--- Handles updating the visibility of the particle system associated with the `DecorStateFXObject` when the object's visibility is changed.
---
--- This function is called when the visibility of the `DecorStateFXObject` is updated. It first checks if the object has a particle system associated with it. If so, it sets the visibility of the particle system based on the `visible` parameter. If `visible` is true, the particle system is made visible, otherwise it is hidden.
---
--- @param visible boolean Whether the `DecorStateFXObject` is visible or not.
---
function DecorStateFXObject:OnXFilterSetVisible(visible)
	if self.particles then
		if visible then
			self.particles:SetEnumFlags(efVisible)
		else
			self.particles:ClearEnumFlags(efVisible)
		end
	end
end

function OnMsg.GatherPlaceCategories(list)
	ClassDescendants("DecorStateFXObject", function(class_name, class)
		if class.place_category or class.place_name then
			local place_name = class.place_name or class_name
			local category = class.place_category or "Effects"
			table.insert(list, {class_name, place_name, "Common", category})
		end
	end)
end

DefineClass.DecorStateFXObjectNoSound = {
	__parents = {"DecorStateFXObject", "EditorVisibleObject", "EditorTextObject", "StripCObjectProperties"},
	entity = "ParticleSoundPlaceholder",
	entity_scale = 10,
	color_modifier = RGB(100, 100, 0),
}

---
--- Initializes the `DecorStateFXObjectNoSound` object by setting its color modifier.
---
--- This function is called during the initialization of the `DecorStateFXObjectNoSound` object. It sets the color modifier of the object to the value specified in the `color_modifier` property.
---
--- @param self DecorStateFXObjectNoSound The `DecorStateFXObjectNoSound` object being initialized.
---
function DecorStateFXObjectNoSound:Init()
	self:SetColorModifier(self.color_modifier)
end

DefineClass.DecorStateFXObjectWithSound = {
	__parents = {"DecorStateFXObject", "SoundSource"},
	
	properties = {
		-- Required for map saving purposes only.
		{ id = "CollectionIndex", name = "Collection Index", editor = "number", default = 0, read_only = true },
		{ id = "CollectionName", name = "Collection Name", editor = "choice",
			items = GetCollectionNames, default = "", dont_save = true,
			buttons = {{ name = "Collection Editor", func = function(self)
				if self:GetRootCollection() then
					OpenCollectionEditorAndSelectCollection(self)
				end
			end }},
		},
	},
	
	entity = "ParticleSoundPlaceholder",
	entity_scale = 10,
	sounds_pattern = "",
	editor_text_offset = point(0, 0, 150 * guic),
}

---
--- Returns the editor text for the `DecorStateFXObjectWithSound` object.
---
--- This function is called to get the text that should be displayed in the editor for the `DecorStateFXObjectWithSound` object. It combines the text from the `DecorGameStatesFilter.EditorGetText` function and the `SoundSource.EditorGetText` function.
---
--- @param self DecorStateFXObjectWithSound The `DecorStateFXObjectWithSound` object.
--- @return string The editor text for the `DecorStateFXObjectWithSound` object.
---
function DecorStateFXObjectWithSound:EditorGetText()
	return string.format("%s\n%s", DecorGameStatesFilter.EditorGetText(self), SoundSource.EditorGetText(self))
end


---
--- Returns the editor text color for the `DecorStateFXObjectWithSound` object.
---
--- This function is called to get the color that should be used to display the text for the `DecorStateFXObjectWithSound` object in the editor. It checks if the object's `ActivationRequiredStates` property matches the current game state, and returns the color specified by `DecorStateFXObject.EditorGetTextColor` if so, or `const.clrRed` if not.
---
--- @param self DecorStateFXObjectWithSound The `DecorStateFXObjectWithSound` object.
--- @return color The editor text color for the `DecorStateFXObjectWithSound` object.
---
function DecorStateFXObjectWithSound:EditorGetTextColor()
	return MatchGameState(self.ActivationRequiredStates) and DecorStateFXObject.EditorGetTextColor(self) or const.clrRed
end

---
--- Initializes the `DecorStateFXObjectWithSound` object by setting up its sound entries.
---
--- This function is called during the initialization of the `DecorStateFXObjectWithSound` object. It checks if the `Sounds` property is already set, and if not, it populates the `sounds` table with sound IDs that match the `sounds_pattern` property of the object. It then adds the first randomly selected sound entry from the `sounds` table to the object using the `AddSoundsEntry` function.
---
--- @param self DecorStateFXObjectWithSound The `DecorStateFXObjectWithSound` object.
---
function DecorStateFXObjectWithSound:Init()
	local sounds = self:GetProperty("Sounds")
	if sounds then return end
	
	local sounds = {}
	for _, entry in ipairs(Presets.SoundPreset.ENVIRONMENT) do
		if string.match(entry.id, self.sounds_pattern) then
			table.insert(sounds, entry.id)
		end
	end
	self:AddSoundsEntry(sounds[1 + self:Random(#sounds)], nil, self.ActivationRequiredStates)
end

---
--- Returns the available sounds for the `DecorStateFXObjectWithSound` object.
---
--- This function is called to get the list of available sounds for the `DecorStateFXObjectWithSound` object. If the object is not activated, it returns an empty list. Otherwise, it delegates to the `SoundSourceBase.GetAvailableSounds` function to get the available sounds.
---
--- @param self DecorStateFXObjectWithSound The `DecorStateFXObjectWithSound` object.
--- @param ignore_editor boolean Whether to ignore the editor state when getting the available sounds.
--- @return table The list of available sounds for the `DecorStateFXObjectWithSound` object.
---
function DecorStateFXObjectWithSound:GetAvailableSounds(ignore_editor)
	if not self.activated then
		return
	end
	return SoundSourceBase.GetAvailableSounds(self, ignore_editor)
end

function OnMsg.GameStateChanged(changed)
	if CurrentMap == "" or ChangingMap then return end
	
	MapForEach("map", "DecorGameStatesFilter", function(decor)
		decor:UpdateGameState()
	end)
end

function OnMsg.GatherFXActions(list)
	list[#list+1] = "DecorState"
end

DefineClass.DecorStateFXAutoAttachObject = {
	__parents = {"DecorStateFXObject", "AutoAttachObject"},
}

---
--- Sets the state of the `DecorStateFXAutoAttachObject`.
---
--- This function overrides the `SetState` function of the `DecorStateFXObject` and `AutoAttachObject` classes. It first calls the `SetState` function of the `DecorStateFXObject` class, which is expected to have the old animation. Then, it calls the `SetState` function of the `AutoAttachObject` class.
---
--- @param self DecorStateFXAutoAttachObject The `DecorStateFXAutoAttachObject` object.
--- @param ... any Arguments to pass to the `SetState` functions of the parent classes.
---
function DecorStateFXAutoAttachObject:SetState(...)
	-- NOTE: DecorStateFXObject expects GetStateText() to have the old anim so it needs to be called first
	DecorStateFXObject.SetState(self, ...)
	AutoAttachObject.SetState(self, ...)
end


DefineClass.ShadowOnlyObject = {
	__parents = {"EditorObject", "Object"},
}

---
--- Initializes the `ShadowOnlyObject` by hiding it.
---
--- This function is called during the initialization of the `ShadowOnlyObject`. It sets the game flags to `const.gofSolidShadow` and sets the opacity to 0, effectively hiding the object.
---
--- @param self ShadowOnlyObject The `ShadowOnlyObject` instance.
---
function ShadowOnlyObject:Init()
	self:Hide()
end

---
--- Hides the `ShadowOnlyObject` by setting the game flags to `const.gofSolidShadow` and setting the opacity to 0.
---
--- This function is used to hide the `ShadowOnlyObject` instance, effectively making it invisible in the game.
---
--- @param self ShadowOnlyObject The `ShadowOnlyObject` instance.
---
function ShadowOnlyObject:Hide()
	self:SetGameFlags(const.gofSolidShadow)
	self:SetOpacity(0)
end

---
--- Shows the `ShadowOnlyObject` by clearing the `const.gofSolidShadow` game flag and setting the opacity to 100%.
---
--- This function is used to make the `ShadowOnlyObject` visible in the game. It is typically called when the object needs to be displayed, such as when entering the editor.
---
--- @param self ShadowOnlyObject The `ShadowOnlyObject` instance.
---
function ShadowOnlyObject:Show()
	self:ClearGameFlags(const.gofSolidShadow)
	self:SetOpacity(100)
end

---
--- Shows the `ShadowOnlyObject` by clearing the `const.gofSolidShadow` game flag and setting the opacity to 100%.
---
--- This function is called when the `ShadowOnlyObject` enters the editor, making it visible in the game.
---
--- @param self ShadowOnlyObject The `ShadowOnlyObject` instance.
---
function ShadowOnlyObject:EditorEnter()
	self:Show()
end

---
--- Hides the `ShadowOnlyObject` when it exits the editor.
---
--- This function is called when the `ShadowOnlyObject` instance is about to exit the editor. It sets the game flags to `const.gofSolidShadow` and sets the opacity to 0, effectively hiding the object.
---
--- @param self ShadowOnlyObject The `ShadowOnlyObject` instance.
---
function ShadowOnlyObject:EditorExit()
	self:Hide()
end

-- use CreateShadowOnlyVersion as parent in ArtSpec to create ShadowOnly version using the same entity
DefineClass.CreateShadowOnlyVersion = {}

function OnMsg.ClassesGenerate(classdefs)
	for class_name, classdef in pairs(classdefs) do
		local idx = table.find(classdef.__parents, "CreateShadowOnlyVersion")
		if idx then
			local parents = table.copy(classdef.__parents)
			parents[idx] = "ShadowOnlyObject"
			local new_class_def = DefineClass(class_name .. "_ShadowOnly", table.unpack(parents))
			new_class_def.entity = classdef.entity or class_name
		end
	end
end

-------------- specific objects --------------

DefineClass.Laptop = {
	__parents = { "DecorStateFXObject" },
	entity = "Corp_Laptop_01",
}

DefineClass.WW2_Flag = {
	__parents = { "DecorStateFXObject" },
	fx_actor_class = "WW2_Flag",
}

DefineClass("WW2_FlagHill_France", "WW2_Flag")
DefineClass("WW2_FlagHill_Legion", "WW2_Flag")

DefineClass.Shanty_WindTower = {
	__parents = {"GroundAlignedObj", "Canvas", "DecorStateFXObject", "AnimMomentHook"},
	fx_actor_class = "Shanty_WindTower",
	anim_moments_hook = true,
	anim_moments_single_thread = true,
}

---
--- Sets the state of the Shanty_WindTower object.
---
--- This function overrides the `SetState` function of the `DecorStateFXObject` and `AnimMomentHook` classes. It is used to update the state of the Shanty_WindTower object, including its visual effects and animation moments.
---
--- @param self Shanty_WindTower The Shanty_WindTower object instance.
--- @param ... any Additional arguments to pass to the parent `SetState` functions.
---
function Shanty_WindTower:SetState(...)
	DecorStateFXObject.SetState(self, ...)
	AnimMomentHook.SetState(self, ...)
end

---
--- Sets the material type for a class definition.
---
--- This function is used to set the `material_type` field of a class definition based on the `entity` field in the `EntityData` table.
---
--- @param cls string The name of the class to set the material type for.
---
local function SetMaterialTypeToClassDef(cls)
	local def = g_Classes[cls]
	if def then
		def.material_type = table.get(EntityData, cls, "entity", "material_type")
	end
end

function OnMsg.EntitiesLoaded()
	local lst = ClassDescendantsList("WW2_Flag")
	for _, cls in ipairs(lst or empty_table) do
		SetMaterialTypeToClassDef(cls)
	end
end

DefineClass("SatelliteViewWater", "WaterObj")

DefineClass.WalkableEntity = {
	__parents = { "CObject" },
	flags = {efPathSlab = true},
}

DefineClass.Vehicle = {
	__parents = { "CombatObject", "AutoAttachObject" },
}

DefineClass.HorizonObject = {
	__parents = { "CObject" },
	max_allowed_radius = 200 * guim,
	flags = { efSelectable = false, cofComponentCollider = false },
}