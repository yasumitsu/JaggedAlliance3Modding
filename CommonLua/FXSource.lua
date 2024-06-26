local Behaviors
local BehaviorsList

MapVar("BehaviorLabels", {})
MapVar("BehaviorLabelsUpdate", {})
MapVar("BehaviorAreaUpdate", sync_set())

----

local function GatherFXSourceTags()
	local tags = {}
	Msg("GatherFXSourceTags", tags)
	ForEachPreset("FXSourcePreset", function(preset, group, tags)
		for tag in pairs(preset.Tags) do
			tags[tag] = true
		end
	end, tags)
	return table.keys(tags, true)
end

----

---
--- Updates the FX source with the current game state.
---
--- @param self FXSource The FX source to update.
--- @param game_state_changed boolean Whether the game state has changed.
--- @param forced_match boolean Whether to force a match of the game state.
--- @param forced_update boolean Whether to force an update of the FX source.
---
function FXSourceUpdate(self, game_state_changed, forced_match, forced_update)
	assert(not DisableSoundFX)
	if not IsValid(self) or not forced_update and self.update_disabled then
		return
	end
	local preset = self:GetPreset() or empty_table
	local fx_event = preset.Event
	if fx_event then
		local match = forced_match
		if match == nil then
			match = MatchGameState(self.game_states)
		end
		if not match then
			fx_event = false
		end
	end
	if fx_event and Behaviors then
		for name, set in pairs(preset.Behaviors) do
			local behavior = Behaviors[name]
			if behavior then
				local enabled = behavior:IsFXEnabled(self, preset)
				if set and not enabled or not set and enabled then
					fx_event = false
					break
				end
			end
		end
	end
	local current_fx = self.current_fx
	if fx_event == current_fx and not forced_update then
		return
	end
	if current_fx then
		PlayFX(current_fx, "end", self)
	end
	if fx_event then
		PlayFX(fx_event, "start", self)
	end
	self.current_fx = fx_event or nil
	if game_state_changed then
		if current_fx and not fx_event and preset.PlayOnce then
			self.update_disabled = true
		end
		self:OnGameStateChanged()
	end
end

----

---
--- Defines a behavior for an FXSource object.
---
--- @class FXSourceBehavior
--- @field id string|false The unique identifier for this behavior.
--- @field CreateLabel boolean|false Whether this behavior creates a label.
--- @field LabelUpdateMsg boolean|false Whether this behavior updates the label.
--- @field LabelUpdateDelay number The delay in milliseconds before updating the label.
--- @field LabelUpdateDelayStep number The step size in milliseconds for the label update delay.
--- @field IsFXEnabled fun(self: FXSourceBehavior, source: FXSource, preset: table):boolean A function that determines whether the FX is enabled for the given source and preset.
DefineClass.FXSourceBehavior = {
	__parents = { "PropertyObject" },
	id = false,
	CreateLabel = false,
	LabelUpdateMsg = false,
	LabelUpdateDelay = 0,
	LabelUpdateDelayStep = 50,
	IsFXEnabled = return_true,
}

---
--- Returns the editor view for this FXSourceBehavior.
---
--- @return string The editor view for this FXSourceBehavior.
function FXSourceBehavior:GetEditorView()
	return Untranslated(self.id or self.class)
end

---
--- Updates the labels for FXSource behaviors.
---
--- This function is responsible for updating the labels associated with FXSource behaviors. It iterates through the list of behaviors that need to be updated, and updates the labels for each behavior based on the specified delay and step settings. If there are any FXSource objects that need to be updated, it suspends pass edits, updates the FXSource objects, and then resumes pass edits.
---
--- @return number|nil The time in milliseconds until the next label update is needed, or nil if no further updates are needed.
function FXSourceUpdateBehaviorLabels()
	local now = GameTime()
	local labels_to_update = BehaviorLabelsUpdate
	local sources_to_update = BehaviorAreaUpdate
	if not next(sources_to_update) then
		sources_to_update = false
	end
	local labels = BehaviorLabels
	local next_time = max_int64
	local pass_edits
	local FXSourceUpdate = FXSourceUpdate
	for _, name in ipairs(labels_to_update) do
		local def = Behaviors[name]
		local label = def and labels[name]
		if label then
			local delay = def.LabelUpdateDelay
			local time = labels_to_update[name]
			if now < time then
				if next_time < time then
					next_time = time
				end
			elseif now <= time + delay then
				if not pass_edits then
					pass_edits = true
					SuspendPassEdits("FXSource")
				end
				if delay == 0 then
					for _, source in ipairs(label) do
						FXSourceUpdate(source)
						if sources_to_update then
							sources_to_update:remove(source)
						end
					end
				else
					local step = def.LabelUpdateDelayStep
					local steps = 1 + delay / step
					local BraidRandom = BraidRandom
					local seed = xxhash(name, MapLoadRandom)
					for i, source in ipairs(label) do
						local delta
						delta, seed = BraidRandom(seed, steps)
						local time_i = time + delta * step
						if now == time_i then
							FXSourceUpdate(source)
							if sources_to_update then
								sources_to_update:remove(source)
							end
						elseif now < time_i and next_time > time_i then
							next_time = time_i
						end
					end
				end
			end
		end
	end
	if pass_edits then
		ResumePassEdits("FXSource")
	end
	return (next_time > now and next_time < max_int) and (next_time - now) or nil
end

--ErrorOnMultiCall("FXSourceUpdate")

---
--- Periodically updates the behavior labels for FXSource objects.
--- This function is called by a repeating thread that is started in the `OnMsg.ClassesBuilt()` function.
--- It iterates through the `BehaviorLabelsUpdate` table, which contains a list of FXSource IDs that need to be updated.
--- For each ID in the table, it updates the corresponding FXSource object and removes it from the table.
--- The function returns the time until the next update is needed, or `nil` if there are no more updates pending.
---
--- @return number|nil time until next update, or `nil` if no more updates
function FXSourceUpdateBehaviorLabels()
end
MapGameTimeRepeat("FXSourceUpdateBehaviorLabels", nil, function()
	local sleep = FXSourceUpdateBehaviorLabels()
	WaitWakeup(sleep)
end)

---
--- Marks an FXSource object as needing an update to its behavior labels.
--- This function is called when the `LabelUpdateMsg` event is triggered for an `FXSourceBehavior` class.
--- It adds the ID of the FXSource object to the `BehaviorLabelsUpdate` table, which is used by the `FXSourceUpdateBehaviorLabels` function to update the labels.
---
--- @param id number the ID of the FXSource object to update
---
function FXSourceUpdateBehaviorLabel(id)
	if not BehaviorLabels[id] then
		return
	end
	local list = BehaviorLabelsUpdate
	if not list[id] then
		list[#list + 1] = id
	end
	list[id] = GameTime()
	WakeupPeriodicRepeatThread("FXSourceUpdateBehaviorLabels")
end

---
--- Periodically updates the FXSource objects that need their behavior labels updated.
--- This function is called by a repeating thread that is started in the `OnMsg.ClassesBuilt()` function.
--- It iterates through the `BehaviorAreaUpdate` table, which contains a list of FXSource IDs that need to be updated.
--- For each ID in the table, it updates the corresponding FXSource object and removes it from the table.
--- The function returns when there are no more updates pending.
---
function FXSourceUpdateBehaviorArea()
	local sources_to_update = BehaviorAreaUpdate
	if not next(sources_to_update) then return end
	SuspendPassEdits("FXSource")
	local FXSourceUpdate = FXSourceUpdate
	for _, source in ipairs(sources_to_update) do
		FXSourceUpdate(source)
	end
	table.clear(sources_to_update, true)
	ResumePassEdits("FXSource")
end

---
--- Updates the behavior labels for FXSource objects within a given radius around a position.
---
--- This function is called when the `BehaviorAreaUpdate` table is updated, indicating that some FXSource objects need their behavior labels updated.
---
--- It iterates through all FXSource objects within the given radius and updates the behavior labels for those that have a corresponding entry in the `BehaviorLabels` table.
---
--- @param id number the ID of the FXSource behavior that needs updating
--- @param pos table the position around which to update FXSource objects
--- @param radius number the radius around the position to consider
---
function FXSourceUpdateBehaviorAround(id, pos, radius)
	local def = Behaviors[id]
	local label = def and BehaviorLabels[id]
	if not label then
		return
	end
	local list = BehaviorAreaUpdate
	MapForEach(pos, radius, "FXSource", function(source, label, list)
		if label[source] then
			list:insert(source)
		end
	end, label, list)
	if not next(list) then
		return
	end
	WakeupPeriodicRepeatThread("FXSourceUpdateBehaviorArea")
end

---
--- Periodically updates the FXSource objects that need their behavior labels updated.
--- This function is called by a repeating thread that is started in the `OnMsg.ClassesBuilt()` function.
--- It iterates through the `BehaviorAreaUpdate` table, which contains a list of FXSource IDs that need to be updated.
--- For each ID in the table, it updates the corresponding FXSource object and removes it from the table.
--- The function returns when there are no more updates pending.
---
MapGameTimeRepeat("FXSourceUpdateBehaviorArea", nil, function()
	FXSourceUpdateBehaviorArea()
	WaitWakeup()
end)

---
--- Registers behavior classes for FXSource objects and sets up event handlers for updating behavior labels.
---
--- This function is called when the game classes are built, typically during initialization.
---
--- It iterates through all `FXSourceBehavior` classes and registers their behavior IDs in the `Behaviors` table.
--- If a behavior class has a `CreateLabel` property set to `true` and a `LabelUpdateMsg` property, it sets up an event handler for that message to update the behavior labels.
---
--- The `BehaviorsList` table is also populated with the keys from the `Behaviors` table.
---
function OnMsg.ClassesBuilt()
	ClassDescendants("FXSourceBehavior", function(class, def)
		local id = def.id
		if id then
			Behaviors = table.create_set(Behaviors, id, def)
			assert(not def.LabelUpdateMsg or def.CreateLabel)
			if def.CreateLabel and def.LabelUpdateMsg then
				OnMsg[def.LabelUpdateMsg] = function()
					FXSourceUpdateBehaviorLabel(id)
				end
			end
		end
	end)
	BehaviorsList = Behaviors and table.keys(Behaviors, true)
end

local function RegisterBehaviors(source, labels, preset)
	if not Behaviors then
		return
	end
	preset = preset or source:GetPreset()
	if not preset or not preset.Event then
		return
	end
	for name, set in pairs(preset.Behaviors) do
		local behavior = Behaviors[name]
		if behavior and behavior.CreateLabel then
			labels = labels or BehaviorLabels
			local label = labels[name]
			if not label then
				labels[name] = {source, [source] = true}
			elseif not label[source] then
				label[#label + 1] = source
				label[source] = true
			end
		end
	end
end

---
--- Rebuilds the labels for FXSource behaviors.
---
--- This function iterates through all FXSource objects in the map and registers their behaviors in the `BehaviorLabels` table.
--- If a behavior has a `CreateLabel` property set to `true`, it adds the FXSource object to the label for that behavior.
--- The `BehaviorLabelsUpdate` table is also updated with the behaviors that have a `LabelUpdateMsg` property set, so that their labels can be updated when that message is received.
---
--- @function FXSourceRebuildLabels
--- @return nil
function FXSourceRebuildLabels()
	BehaviorLabels = {}
	BehaviorLabelsUpdate = BehaviorLabelsUpdate or {}
	MapForEach("map", "FXSource", const.efMarker, RegisterBehaviors, BehaviorLabels)
end

local function UnregisterBehaviors(source, labels)
	for name, label in pairs(labels or BehaviorLabels) do
		if label[source] then
			table.remove_value(label, source)
			label[source] = nil
		end
	end
end

----

---
--- Defines a behavior for an FXSource that controls the chance of the FX being enabled.
---
--- The `FXBehaviorChance` class is a behavior that can be attached to an FXSource. It controls the chance of the FX being enabled, with a configurable chance percentage and change interval. The chance can be based on either game time or real time.
---
--- Properties:
--- - `EnableChance`: The chance (0-100%) of the FX being enabled.
--- - `ChangeInterval`: The time interval (in seconds) for the chance to change. A value of 0 means the chance never changes.
--- - `IntervalScale`: The time scale to use for the change interval (e.g. "s" for seconds, "m" for minutes).
--- - `IsGameTime`: If true, the change interval is based on game time, otherwise it's based on real time.
---
--- @class FXBehaviorChance
--- @field EnableChance number The chance (0-100%) of the FX being enabled.
--- @field ChangeInterval number The time interval (in seconds) for the chance to change.
--- @field IntervalScale string The time scale to use for the change interval.
--- @field IsGameTime boolean If true, the change interval is based on game time, otherwise it's based on real time.
DefineClass.FXBehaviorChance = {
	__parents = { "FXSourceBehavior" },
	id = "Chance",
	CreateLabel = true,
	properties = {
		{ category = "FX: Chance", id = "EnableChance",   name = "Chance",          editor = "number", default = 100, min = 0, max = 100, scale = "%", slider = true },
		{ category = "FX: Chance", id = "ChangeInterval", name = "Change Interval", editor = "number", default = 0, min = 0, scale = function(self) return self.IntervalScale end, help = "Time needed to change the chance result." },
		{ category = "FX: Chance", id = "IntervalScale",  name = "Interval Scale",  editor = "choice", default = false, items = function() return table.keys(const.Scale, true) end },
		{ category = "FX: Chance", id = "IsGameTime",     name = "Game Time",       editor = "bool",   default = false, help = "Change interval time type. Game Time is needed for events messing with the game logic." },
	},
}

---
--- Determines if an FX should be enabled based on a configurable chance percentage.
---
--- The `IsFXEnabled` function checks if an FX should be enabled for a given FXSource and preset. It calculates the chance of the FX being enabled based on the `EnableChance` property of the preset. If the chance is 100%, the FX is always enabled. Otherwise, the function uses a random seed based on the source handle, current time, and map load random value to determine if the FX should be enabled.
---
--- @param source table The FXSource object.
--- @param preset table The FXSourcePreset object.
--- @return boolean True if the FX should be enabled, false otherwise.
function FXBehaviorChance:IsFXEnabled(source, preset)
	local chance = preset and preset.EnableChance or 100
	if chance >= 100 then return true end
	local time = (preset.IsGameTime and GameTime() or RealTime()) / Max(1, preset.ChangeInterval or 0)
	local seed = xxhash(source.handle, time, MapLoadRandom)
	return (seed % 100) < chance
end

----

---
--- Defines a preset for an FXSource, which includes properties for configuring the behavior and appearance of the FX.
---
--- The `FXSourcePreset` class is used to define presets for FXSources, which are objects that control the playback of visual effects (FX) in the game. The preset includes properties for configuring the FX event, game states, playback behavior, editor settings, and other parameters.
---
--- Properties:
--- - `Event`: The FX event to be played.
--- - `GameStates`: The game states in which the FX should be played.
--- - `PlayOnce`: If true, the FX will be killed if it is no longer matched after a game state change.
--- - `EditorPlay`: Determines the behavior of the FX in the editor (no change, force play, or force stop).
--- - `Entity`: The editor entity associated with the FX.
--- - `Tags`: Tags associated with the FX source, which can be used to find the source if needed.
--- - `Behaviors`: Behaviors attached to the FX source, which can modify its behavior.
--- - `ConditionText`: A read-only text field that displays the condition for the FX to be enabled, based on the attached behaviors.
--- - `Actor`: The FX actor to be used.
--- - `Scale`: The scale of the FX.
--- - `Color`: The color of the FX.
--- - `FXButtons`: Buttons in the editor for performing actions related to the FX source.
---
--- @class FXSourcePreset
--- @field Event string The FX event to be played.
--- @field GameStates table The game states in which the FX should be played.
--- @field PlayOnce boolean If true, the FX will be killed if it is no longer matched after a game state change.
--- @field EditorPlay string Determines the behavior of the FX in the editor (no change, force play, or force stop).
--- @field Entity string The editor entity associated with the FX.
--- @field Tags table Tags associated with the FX source.
--- @field Behaviors table Behaviors attached to the FX source.
--- @field ConditionText string A read-only text field that displays the condition for the FX to be enabled.
--- @field Actor string The FX actor to be used.
--- @field Scale number The scale of the FX.
--- @field Color table The color of the FX.
--- @field FXButtons table Buttons in the editor for performing actions related to the FX source.
DefineClass.FXSourcePreset = {
	__parents = { "Preset" },
	properties = {
		{ category = "FX", id = "Event",          name = "FX Event",       editor = "combo",       default = false, items = function(fx) return ActionFXClassCombo(fx) end },
		{ category = "FX", id = "GameStates",     name = "Game State",     editor = "set",         default = set(), three_state = true, items = function() return GetGameStateFilter() end },
		{ category = "FX", id = "PlayOnce",       name = "Play Once",      editor = "bool",        default = false, help = "Kill the object if the FX is no more matched after changing game state", },
		{ category = "FX", id = "EditorPlay",     name = "Editor Play",    editor = "choice",      default = "force play", items = {"no change", "force play", "force stop"}, developer = true },
		{ category = "FX", id = "Entity",         name = "Editor Entity",  editor = "combo",       default = false, items = function() return GetAllEntitiesCombo() end },
		{ category = "FX", id = "Tags",           name = "Tags",           editor = "set",         default = set(), items = GatherFXSourceTags, help = "Help the game logic find this source if needed", },
		{ category = "FX", id = "Behaviors",      name = "Behaviors",      editor = "set",         default = set(), items = function() return BehaviorsList end, three_state = true,  },
		{ category = "FX", id = "ConditionText",  name = "Condition",      editor = "text",        default = "", read_only = true, no_edit = function(self) return not next(self.Behaviors) end  },
		{ category = "FX", id = "Actor",          name = "FX Actor",       editor = "combo",       default = false, items = function(fx) return ActorFXClassCombo(fx) end},
		{ category = "FX", id = "Scale",          name = "Scale",          editor = "number",      default = false },
		{ category = "FX", id = "Color",          name = "Color",          editor = "color",       default = false },
		{ category = "FX", id = "FXButtons",                               editor = "buttons",     default = false, buttons = {{ name = "Map Select", func = "ActionSelect" }} },
	},
	GlobalMap = "FXSourcePresets",
	EditorMenubarName = "FX Sources",
	EditorMenubar = "Editors.Art",
	EditorIcon = "CommonAssets/UI/Icons/atoms electron physic.png",
}

---
--- Generates a condition text string based on the enabled and disabled behaviors attached to the `FXSourcePreset`.
---
--- @return string The condition text string.
---
function FXSourcePreset:GetConditionText()
	local texts = {}
	for name, set in pairs(self.Behaviors) do
		if set then
			texts[#texts + 1] = name
		else
			texts[#texts + 1] = "not " .. name
		end
	end
	return table.concat(texts, " and ")
end

---
--- Selects all FXSource objects in the current map that have the same FxPreset as the current FXSourcePreset.
---
--- This function is called when the "Map Select" button is clicked in the FXSourcePreset editor.
---
--- @return nil
---
function FXSourcePreset:ActionSelect()
	if GetMap() == "" then
		return
	end
	editor.ClearSel()
	editor.AddToSel(MapGet("map", "FXSource", const.efMarker, function(obj, id)
		return obj.FxPreset == id
	end, self.id))
end

---
--- Updates all FXSource objects in the current map that have the same FxPreset as the current FXSourcePreset.
---
--- This function is called when an editor property of the FXSourcePreset is changed.
---
--- @param prop_id string The ID of the property that was changed.
--- @return nil
---
function FXSourcePreset:OnEditorSetProperty(prop_id)
	if GetMap() == "" then
		return
	end
	local prop = self:GetPropertyMetadata(prop_id)
	if not prop or prop.category ~= "FX" then
		return
	end
	MapForEach("map", "FXSource", const.efMarker, function(obj, self)
		if obj.FxPreset == self.id then
			obj:SetPreset(self)
		end
	end, self)
end

---
--- Gets the properties of the FXSourcePreset, including any properties defined by its Behaviors.
---
--- @return table The properties of the FXSourcePreset, including any properties defined by its Behaviors.
---
function FXSourcePreset:GetProperties()
	local orig_props = Preset.GetProperties(self)
	local props = orig_props
	if Behaviors then
		for name, set in pairs(self.Behaviors) do
			local classdef = Behaviors[name]
			local propsi = classdef and classdef.properties
			if propsi and #propsi > 0 then
				if props == orig_props then
					props = table.icopy(props)
				end
				props = table.iappend(props, propsi)
			end
		end
	end
	return props
end

---
--- Defines a class named "FXSourceAutoResolve".
---
--- This class is likely used to provide automatic resolution functionality for FXSource objects.
--- The specific purpose and behavior of this class is not clear from the provided context.
---
DefineClass("FXSourceAutoResolve")

---
--- Defines the `FXSource` class, which is a type of `Object`, `FXObject`, `EditorEntityObject`, `EditorCallbackObject`, `EditorTextObject`, and `FXSourceAutoResolve`.
---
--- The `FXSource` class represents a source of visual effects (FX) in the game. It has various properties that control the behavior and appearance of the FX, such as the FX preset, whether the FX is currently playing, and various editor-related properties.
---
--- The class has the following properties:
---
--- - `FxPreset`: The ID of the FX preset to use for this source.
--- - `Playing`: A read-only boolean indicating whether the FX is currently playing.
---
--- The class also has the following methods:
---
--- - `GetPlaying()`: Returns whether the FX is currently playing.
--- - `EditorGetText()`: Returns the text to display for this FX source in the editor.
--- - `GetEditorLabel()`: Returns the label to display for this FX source in the editor.
--- - `GetError()`: Returns an error message if the FX source has no FX preset assigned.
--- - `GameInit()`: Initializes the FX source when the game is started.
---
--- The `FXSourceAutoResolve` class is also defined, which likely provides automatic resolution functionality for FXSource objects.
---
DefineClass.FXSource = {
	__parents = { "Object", "FXObject", "EditorEntityObject", "EditorCallbackObject", "EditorTextObject", "FXSourceAutoResolve" },
	flags = { efMarker = true, efWalkable = false, efCollision = false, efApplyToGrids = false },
	editor_text_offset = point(0, 0, -guim),
	editor_text_style = "FXSourceText",
	editor_entity = "ParticlePlaceholder",
	entity = "InvisibleObject",
	
	properties = {
		{ category = "FX Source", id = "FxPreset", name = "FX Preset", editor = "preset_id", default = false, preset_class = "FXSourcePreset", buttons = {{ name = "Start", func = "ActionStart" }, { name = "End", func = "ActionEnd" }} },
		{ category = "FX Source", id = "Playing",  name = "Playing",   editor = "bool",      default = false, dont_save = true, read_only = true },
	},
	
	current_fx = false,
	update_disabled = false,
	game_states = false,
	
	prefab_no_fade_clamp = true,
}

---
--- Returns whether the FX is currently playing.
---
--- @return boolean
--- @within FXSource
function FXSource:GetPlaying()
	return not not self.current_fx
end

---
--- Returns the text to display for this FX source in the editor.
---
--- @return string The text to display for this FX source in the editor.
--- @within FXSource
function FXSource:EditorGetText()
	return (self.FxPreset or "") ~= "" and self.FxPreset or self.class
end

---
--- Returns the label to display for this FX source in the editor.
---
--- @return string The label to display for this FX source in the editor.
function FXSource:GetEditorLabel()
	local label = self.class
	if (self.FxPreset or "") ~= "" then
		label = label .. " (" .. self.FxPreset .. ")"
	end
	return label
end	

---
--- Returns an error message if the FX source has no FX preset assigned.
---
--- @return string|nil The error message, or nil if the FX source has an FX preset assigned.
--- @within FXSource
function FXSource:GetError()
	if not self.FxPreset then
		return "FX source has no FX preset assigned."
	end
end

---
--- Initializes the FXSource when the game starts.
---
--- This function is called when the game is initialized. It checks if the map is changing, and if not, it calls `FXSourceUpdate` to update the FX source.
---
--- @within FXSource
function FXSource:GameInit()
	if ChangingMap then
		return -- sound FX are disabled during map changing
	end
	FXSourceUpdate(self)
end

---
--- Assigns the `FXSourceUpdate` function to the `EditorExit` property of `FXSourceAutoResolve`.
---
--- This allows the `FXSourceUpdate` function to be called when the editor exits, which is likely used to update the state of the FX source when the editor is closed.
---
--- @within FXSourceAutoResolve
FXSourceAutoResolve.EditorExit = FXSourceUpdate

---
--- Enters the editor mode for the `FXSourceAutoResolve` object.
---
--- This function is called when the editor is entered. It creates a real-time thread that waits for the map to finish changing, and then checks the current map and the editor's play state. Based on the editor's play state, it calls `FXSourceUpdate` with the appropriate parameters.
---
--- @param self FXSourceAutoResolve The `FXSourceAutoResolve` object.
--- @within FXSourceAutoResolve
function FXSourceAutoResolve:EditorEnter()
	CreateRealTimeThread(function()
		WaitChangeMapDone()
		if GetMap() == "" then
			return
		end
		local match
		if IsEditorActive() then
			local preset = self:GetPreset() or empty_table
			local editor_play = preset.EditorPlay
			if editor_play == "force play" then
				match = true
			elseif editor_play == "force stop" then
				match = false
			end
		end
		FXSourceUpdate(self, nil, match)
	end)
end

---
--- Called when a property of the `FXSourceAutoResolve` object is set in the editor.
---
--- If the `FxPreset` property is set, this function calls `FXSourceUpdate` with the current object, `nil`, the playing state, and `true` to indicate that the update is due to a property change.
--- It then calls `EditorTextUpdate` to update the editor's text display.
---
--- @param self FXSourceAutoResolve The `FXSourceAutoResolve` object.
--- @param prop_id string The ID of the property that was set.
--- @within FXSourceAutoResolve
function FXSourceAutoResolve:OnEditorSetProperty(prop_id)
	if prop_id == "FxPreset" then
		FXSourceUpdate(self, nil, self:GetPlaying(), true)
		self:EditorTextUpdate()
	end
end

MapVar("FXSourceStates", false)
MapVar("FXSourceUpdateThread", false)

---
--- Sets the game states for the `FXSource` object.
---
--- This function updates the game states for the `FXSource` object. It keeps track of the number of times each state is set, and only removes the state when the count reaches 0.
---
--- @param self FXSource The `FXSource` object.
--- @param states table A table of game states to set.
--- @within FXSource
function FXSource:SetGameStates(states)
	states = states or false
	local prev_states = self.game_states
	if prev_states == states then
		return
	end
	local counters = FXSourceStates or {}
	FXSourceStates = counters
	for state in pairs(states) do
		counters[state] = (counters[state] or 0) + 1
	end
	for state in pairs(prev_states) do
		local count = counters[state] or 0
		assert(count > 0)
		if count > 1 then
			counters[state] = count - 1
		else
			counters[state] = nil
		end
	end
	self.game_states = states or nil
end

---
--- Called when the game state of the `FXSource` object changes.
---
--- This function is called whenever the game state of the `FXSource` object changes. It can be used to perform any necessary actions or updates in response to the state change.
---
--- @param self FXSource The `FXSource` object.
--- @within FXSource
function FXSource:OnGameStateChanged()
end

---
--- Sets the FX preset for the `FXSource` object.
---
--- This function sets the FX preset for the `FXSource` object. If the `id` parameter is empty or `nil`, the preset is cleared and the `FXSource` object is reset to its default state. Otherwise, the preset with the specified `id` is loaded and applied to the `FXSource` object.
---
--- @param self FXSource The `FXSource` object.
--- @param id string The ID of the FX preset to set.
--- @within FXSource
function FXSource:SetFxPreset(id)
	if (id or "") == "" then
		self.FxPreset = nil
		self:SetPreset()
		return
	end
	self.FxPreset = id
	self:SetPreset(FXSourcePresets[id])
end

---
--- Sets the preset for the `FXSource` object.
---
--- This function sets the preset for the `FXSource` object. If the `preset` parameter is `nil`, the `FXSource` object is reset to its default state. Otherwise, the preset is applied to the `FXSource` object, including its game states, entity, actor class, state, scale, and color modifier.
---
--- @param self FXSource The `FXSource` object.
--- @param preset table The preset to apply to the `FXSource` object.
--- @within FXSource
function FXSource:SetPreset(preset)
	UnregisterBehaviors(self)
	
	if not preset then
		self:SetGameStates(false)
		self:ChangeEntity(FXSource.entity)
		self.fx_actor_class = nil
		self:SetState("idle")
		self:SetScale(100)
		self:SetColorModifier(const.clrNoModifier)
		FXSourceUpdate(self, nil, false)
		return
	end
	
	RegisterBehaviors(self, nil, preset)
	self:SetGameStates(preset.GameStates)
	if preset.Entity then
		self.editor_entity = preset.Entity
		if IsEditorActive() then
			self:ChangeEntity(preset.Entity)
		end
	end
	if preset.Actor then
		self.fx_actor_class = preset.Actor
	end
	if preset.State then
		self:SetState(preset.State)
	end
	if preset.Scale then
		self:SetScale(preset.Scale)
	end
	if preset.Color then
		self:SetColorModifier(preset.Color)
	end
	if self.current_fx then
		FXSourceUpdate(self, nil, true)
	end
end

---
--- Gets the preset for the `FXSource` object.
---
--- This function returns the preset associated with the `FxPreset` field of the `FXSource` object.
---
--- @param self FXSource The `FXSource` object.
--- @return table The preset associated with the `FxPreset` field of the `FXSource` object.
--- @within FXSource
function FXSource:GetPreset()
	return FXSourcePresets[self.FxPreset]
end

---
--- Finalizes the `FXSource` object by unregistering it from the `FXSourceStates` and updating its state.
---
--- This function is called when the `FXSource` object is no longer needed. It performs the following actions:
---
--- - Unregisters the `FXSource` object from the `FXSourceStates` by calling `self:SetGameStates(false)`.
--- - Updates the state of the `FXSource` object by calling `FXSourceUpdate(self, nil, false)`.
--- - Unregisters any behaviors associated with the `FXSource` object by calling `UnregisterBehaviors(self)`.
---
--- @param self FXSource The `FXSource` object to be finalized.
--- @within FXSource
function FXSource:Done()
	self:SetGameStates(false) -- unregister from FXSourceStates
	FXSourceUpdate(self, nil, false)
	UnregisterBehaviors(self)
end



---
--- Starts the action for the `FXSource` object.
---
--- This function is called when the action for the `FXSource` object starts. It performs the following actions:
---
--- - Updates the `FXSource` object by calling `FXSourceUpdate(self, nil, true, true)`.
--- - Marks the `FXSource` object as modified by calling `ObjModified(self)`.
---
--- @param self FXSource The `FXSource` object.
--- @within FXSource
function FXSource:ActionStart()
	FXSourceUpdate(self, nil, true, true)
	ObjModified(self)
end

---
--- Ends the action for the `FXSource` object.
---
--- This function is called when the action for the `FXSource` object ends. It performs the following actions:
---
--- - Updates the `FXSource` object by calling `FXSourceUpdate(self, nil, false, true)`.
--- - Marks the `FXSource` object as modified by calling `ObjModified(self)`.
---
--- @param self FXSource The `FXSource` object.
--- @within FXSource
function FXSource:ActionEnd()
	FXSourceUpdate(self, nil, false, true)
	ObjModified(self)
end

local function FXSourceUpdateAll(area, ...)
	SuspendPassEdits("FXSource")
	MapForEach(area, "FXSource", const.efMarker, FXSourceUpdate, ...)
	ResumePassEdits("FXSource")
end

---
--- Updates all `FXSource` objects in the specified area when the game state changes.
---
--- This function is called when the game state changes, and it updates all `FXSource` objects in the specified area. It does this by suspending pass edits, mapping over all `FXSource` objects in the area, and calling `FXSourceUpdate` on each one. The function then resumes pass edits.
---
--- If the current map is empty, the function returns without doing anything.
---
--- The function can be called with an optional `delay` parameter, which specifies the delay in milliseconds before the update is performed. If `delay` is not provided, the function uses the value of `config.MapSoundUpdateDelay` or 1000 if that is not set.
---
--- @param delay number The delay in milliseconds before the update is performed.
--- @within FXSource
function FXSourceUpdateOnGameStateChange(delay)
	if GetMap() == "" then
		return
	end
	delay = delay or GameTime() == 0 and 0 or config.MapSoundUpdateDelay or 1000
	DeleteThread(FXSourceUpdateThread)
	FXSourceUpdateThread = CreateGameTimeThread(function(delay)
		if delay <= 0 then
			FXSourceUpdateAll("map", "game_state_changed")
		else
			local boxes = GetMapBoxesCover(config.MapSoundBoxesCoverParts or 8, "MapSoundBoxesCover")
			local count = #boxes
			for i, box in ipairs(boxes) do
				FXSourceUpdateAll(box, "game_state_changed")
				Sleep((i + 1) * delay / count - i * delay / count)
			end
		end
		FXSourceUpdateThread = false
	end, delay)
end

---
--- Called when the map has finished changing. This function updates all `FXSource` objects in the current map to reflect the new game state.
---
--- This function is called as a message handler for the `OnMsg.ChangeMapDone` event. It calls the `FXSourceUpdateOnGameStateChange` function to update all `FXSource` objects in the current map.
---
--- @within FXSource
function OnMsg.ChangeMapDone()
	FXSourceUpdateOnGameStateChange()
end

---
--- Called when the game state changes. This function updates all `FXSource` objects in the current map to reflect the new game state.
---
--- This function is called as a message handler for the `OnMsg.GameStateChanged` event. It checks if the game state has changed for any of the game state definitions that affect `FXSource` objects. If so, it calls the `FXSourceUpdateOnGameStateChange` function to update all `FXSource` objects in the current map.
---
--- @param changed table A table of game state IDs that have changed.
--- @within FXSource
function OnMsg.GameStateChanged(changed)
	if ChangingMap or GetMap() == "" then return end
	local GameStateDefs, FXSourceStates = GameStateDefs, FXSourceStates
	if not FXSourceStates then return end
	for id in sorted_pairs(changed) do
		if GameStateDefs[id] and (FXSourceStates[id] or 0) > 0 then -- if a game state is changed, update sound sources
			FXSourceUpdateOnGameStateChange()
			break
		end
	end
end

if Platform.developer then

local function ReplaceWithSources(objs, fx_src_preset)
	if #(objs or "") == 0 then
		return 0
	end
	XEditorUndo:BeginOp{ objects = objs, name = "ReplaceWithFXSource" }
	editor.ClearSel()
	local sources = {}
	for _, obj in ipairs(objs) do
		local pos, axis, angle, scale, coll = obj:GetPos(), obj:GetAxis(), obj:GetAngle(), obj:GetScale(), obj:GetCollectionIndex()
		DoneObject(obj)
		local src = PlaceObject("FXSource")
		src:SetGameFlags(const.gofPermanent)
		src:SetAxisAngle(axis, angle)
		src:SetScale(scale)
		src:SetPos(pos)
		src:SetCollectionIndex(coll)
		src:SetFxPreset(fx_src_preset)
		sources[#sources + 1] = src
	end
	Msg("EditorCallback", "EditorCallbackPlace", sources)
	editor.AddToSel(sources)
	XEditorUndo:EndOp(sources)
	return #sources
end

---
--- Replaces all SoundSource objects in the current map that have a specific sound name with FXSource objects.
---
--- This function is used to replace all SoundSource objects in the current map that have a specific sound name with FXSource objects. It uses the `ReplaceWithSources` function to perform the replacement.
---
--- @param snd_name string The name of the sound to replace.
--- @param fx_src_preset string The FX preset to use for the new FXSource objects.
--- @return number The number of sounds that were replaced and selected.
function ReplaceMapSounds(snd_name, fx_src_preset)
	local objs = MapGet("map", "SoundSource", function(obj)
		for _, entry in ipairs(obj.Sounds) do
			if entry.Sound == snd_name then
				return true
			end
		end
	end)
	local count = ReplaceWithSources(objs, fx_src_preset)
	print(count, "sounds replaced and selected")
end

---
--- Replaces all ParSystem objects in the current map that have a specific particle name with FXSource objects.
---
--- This function is used to replace all ParSystem objects in the current map that have a specific particle name with FXSource objects. It uses the `ReplaceWithSources` function to perform the replacement.
---
--- @param prtcl_name string The name of the particle to replace.
--- @param fx_src_preset string The FX preset to use for the new FXSource objects.
--- @return number The number of particles that were replaced and selected.
function ReplaceMapParticles(prtcl_name, fx_src_preset)
	local objs = MapGet("map", "ParSystem", function(obj)
		return obj:GetParticlesName() == prtcl_name
	end)
	local count = ReplaceWithSources(objs, fx_src_preset)
	print(count, "particles replaced and selected")
end

end
