if Platform.ged then return end

-- override in the project, called from a game-time thread
---
--- Called when a setpiece is started.
---
--- @param setpiece table The setpiece that was started.
function OnSetpieceStarted(setpiece)
end

---
--- Called when a setpiece has ended.
---
--- @param setpiece table The setpiece that has ended.
function OnSetpieceEnded(setpiece)
end

-- low level function, starts the setpiece code without  UI & without executing completion effects
---
--- Starts a setpiece with the given ID, optionally in test mode.
---
--- @param id string The ID of the setpiece to start.
--- @param test_mode boolean Whether to start the setpiece in test mode.
--- @param seed number The seed to use for the setpiece.
--- @param ... any Additional arguments to pass to the setpiece.
--- @return table The state of the setpiece.
function StartSetpiece(id, test_mode, seed, ...)
	local setpiece = Setpieces[id]
	assert(setpiece, string.format("Missing setpiece '%s'", id))
	assert(setpiece.Map == "" or setpiece.Map == CurrentMap, string.format("Wrong map for setpiece '%s' - must be '%s'", id, setpiece.Map))
	
	local state = SetpieceState:new{ test_mode = test_mode, setpiece = setpiece }
	CreateGameTimeThread(function(seed, state, ...)
		local ok = sprocall(SetpiecePrgs[id], seed, state, ...)
		if not ok then
			print("Setpiece", id, "crashed!")
			state.commands = {} -- force completion
			Msg(state)
		end
		state:WaitCompletion()
		RegisterSetpieceActors(state.real_actors, false)
		Msg("SetpieceEndExecution", state.setpiece, state)
	end, seed, state, ...)
	return state
end

---
--- Ends a setpiece by executing its completion effects and notifying listeners.
---
--- @param id string The ID of the setpiece to end.
function EndSetpiece(id)
	local setpiece = Setpieces[id]
	ExecuteEffectList(setpiece.Effects, setpiece, "setpiece")
	OnSetpieceEnded(setpiece)
	Msg("SetpieceDialogClosed")
end

---
--- Records a setpiece to a file.
---
--- @param setpiece table The setpiece to record.
--- @param root table The root object of the setpiece.
--- @param prop_id string The ID of the property being recorded.
--- @param ged table The GED object associated with the setpiece.
--- @param btn_param any Additional parameters passed to the button.
---
--- This function creates a new directory for the recording, sets the video settings to the maximum, starts recording when the setpiece starts, and stops recording when the setpiece ends. The recording is saved to the specified file path.
function SetpieceRecord(setpiece, root, prop_id, ged, btn_param)
	local directory = setpiece.RecordDirectory
	if not directory:ends_with("\\") and not directory:ends_with("/") then
		directory = directory .. "/"
	end
	local finalPath = directory .. (setpiece.id or "UnnamedSetpiece") .. "-" .. RealTime() .. "/"
	AsyncCreatePath(finalPath)

	CreateRealTimeThread(function()
		local prev_video_preset = EngineOptions.VideoPreset
		if setpiece.ForceMaxVideoSettings then
			MapForEach(true, CObject.SetForcedLOD, 0)
			ApplyVideoPreset("Ultra")
			WaitNextFrame()
		end
	
		-- Start recording when the Setpiece starts
		Msg("RecordingReady")
		WaitMsg("SetpieceStarted")
		local setpiece = setpiece
		local fname = finalPath .. setpiece.RecordFileName
		CreateRealTimeThread(RecordMovie, fname, 0, setpiece.RecordFPS, nil, setpiece.RecordQuality, setpiece.RecordMotionBlur, function() return setpiece.setpiece_ended end)
		
		WaitMsg("RecordingStarted")
		GedObjectModified(setpiece)
		
		WaitMsg("SetpieceEnding")
		setpiece.setpiece_ended = true
		Sleep(100)
		setpiece.setpiece_ended = false
		
		if setpiece.ForceMaxVideoSettings then
			MapForEach(true, CObject.SetForcedLOD, -1)
			ApplyVideoPreset(prev_video_preset)
			WaitNextFrame()
		end
	end)
	
	-- Play Setpiece
	WaitMsg("RecordingReady")
	setpiece:Test(ged)
	ObjModified(setpiece)
	GedObjectModified(setpiece)
end


----- SetpiecePrg

---
--- This class represents a setpiece program, which is a skippable cutscene that can be triggered during gameplay.
--- Setpieces are composed of commands that are started simultaneously and executed in parallel, unless their 'Wait completion' property is turned on.
--- Most commands require named Actors and Markers to be created beforehand. The setpiece is associated with a specific game map, and Markers created on that map are used to designate locations on the map, as well as spawn setpiece actors or particle effects.
---
--- @class SetpiecePrg
--- @field Map string The map associated with this setpiece.
--- @field TakePlayerControl boolean Whether to take player control during the setpiece.
--- @field RestoreCamera boolean Whether to restore the camera to its previous position after the setpiece finishes.
--- @field Effects table<number, Effect> The completion effects to play when the setpiece finishes.
--- @field FastForward number The time in seconds to fast forward to for testing purposes.
--- @field TestSpeed number The speed at which to test the setpiece, as a percentage of normal speed.
--- @field ForceMaxVideoSettings boolean Whether to force the video settings to the maximum during recording.
--- @field RecordFPS number The frames per second to use when recording the setpiece.
--- @field RecordDirectory string The directory to save the recorded setpiece to.
--- @field RecordFileName string The file name to use for the recorded setpiece.
--- @field RecordQuality number The quality of the recorded setpiece, from 1 (fastest) to 64 (highest).
--- @field RecordMotionBlur number The amount of motion blur to apply to the recorded setpiece, from 0 (no blur) to 100 (maximum blur).
DefineClass.SetpiecePrg = {
	__parents = { "PrgPreset" },
	
	properties = {
		{ category = "Map", id = "NotOnMap", editor = "help", default = "",
			buttons = { { name = "Switch map", func = "SwitchMap" } },
			help = "Can't display markers - the setpiece map isn't loaded.",
			no_edit = function(self) return self.Map == "" or self.Map == CurrentMap or IsChangingMap() end,
		},
		{ category = "Map", id = "Map", editor = "choice", default = "", items = function() return table.keys2(MapData, true, "") end, },
		{ category = "Map", id = "PlaceMarkers", editor = "buttons", default = "",
			buttons = function() return table.map(ClassLeafDescendantsList("SetpieceMarker"), function(class)
				return { name = "Place " .. g_Classes[class].DisplayName, func = SetpieceMarkerPlaceButton, param = class }
			end) end,
			no_edit = function(self) return self.Map ~= "" and self.Map ~= CurrentMap end,
		},
		{ category = "Misc", id = "TakePlayerControl", name = "Take player control", editor = "bool", default = true, },
		{ category = "Misc", id = "RestoreCamera", name = "Restore camera", editor = "bool", default = false, help = "Restore the camera to where it was after the setpiece finishes.", },
		{ category = "Misc", id = "Effects", name = "Completion effects", editor = "nested_list", default = false, base_class = "Effect", all_descendants = true },
		{ category = "Testing", id = "FastForward", name = "Fast forward to", editor = "number", default = 0, scale = "sec", 
			help = "Allows 'skipping' a part of the setpiece for testing purposes by playing a part of it on very high speed.",
			dont_save = true,
		},
		{ category = "Testing", id = "TestSpeed", name = "Test speed", editor = "number", slider = true, min = 5, max = 200, step = 5, default = 100,
			buttons = { { name = "Test", func = function(self, root, prop_id, ged) self:Test(ged) end } },
			dont_save = true,
		},
		{ category = "Recording", id = "ForceMaxVideoSettings", name = "Force max video settings", editor = "bool", default = true },
		{ category = "Recording", id = "RecordFPS", name = "FPS", editor = "number", default = 30, },
		{ category = "Recording", id = "RecordDirectory", name = "Directory", editor = "text", default = "AppData/Recordings/", },
		{ category = "Recording", id = "RecordFileName", name = "File name", editor = "text", default = "setPieceRecording.png", },
		{ category = "Recording", id = "RecordQuality", name = "Quality", editor = "choice", default = 64,
			items = {{name = "Fastest", value = 1}, {name = "Fast", value = 4}, {name = "High", value = 64}}
		},
		{ category = "Recording", id = "RecordMotionBlur", name = "Motion Blur", editor = "choice", default = 50,
			items = {{name = "No motion blur", value = 0}, {name = "Standard motion blur", value = 50}, {name = "Extra motion blur", value = 100}}
		},
		{ category = "Recording", id = "RecordButtons", editor = "buttons", default = "",
			buttons = {
				{ name = "Record", func = SetpieceRecord, is_hidden = function(self) return IsSetpiecePlaying() or IsEditorActive() or #self == 0 or IsRecording() end }, 
				{ 
					name = "Stop", 
					func = function(self) 
						CreateRealTimeThread(function() 
							self.setpiece_ended = true
							Sleep(100)
							SkipAnySetpieces() 
						end)
					end, 
					is_hidden = function(self) return not IsRecording() end
				}
			},
		},
	},
	
	EditorCustomActions = {
		{ Toolbar = "main", Name = "Test (Ctrl-T)", FuncName = "Test", Icon = "CommonAssets/UI/Ged/play.tga", Shortcut = "Ctrl-T", },
		{ Toolbar = "main", Name = "Toggle black strips (Alt-T)", FuncName = "GedPrgPresetToggleStrips", Icon = "CommonAssets/UI/Ged/explorer.tga", Shortcut = "Alt-T", IsToggledFuncName = "GedPrgPresetBlackStripsVisible" },
	},
	
	EditorMenubarName = "Setpieces",
	EditorMenubar = "Scripting",
	EditorShortcut = "Ctrl-Alt-S",
	EditorMenubarSortKey = "3050",
	EditorIcon = "CommonAssets/UI/Icons/film.png",
	Documentation = "Creates a skippable cutscene that can be triggered during gameplay.\n\nSet-pieces are composed of commands, that are <style GedHighlight>started simultaneously</style> and are executed in parallel, unless their 'Wait completion' property is turned on.\n\nMost commands require named <style GedHighlight>Actors and Markers</style> to be created beforehand.\n\nThe setpiece is associated with a specific game map, and Markers created on that map are used to designate locations on the map, as well as spawn setpiece actors or particle effects.",
	
	Params = { "TriggerUnits" },
	StatementTags = { "Basics", "Setpiece" },
	FuncTable = "SetpiecePrgs",
	GlobalMap = "Setpieces",
}

--- Returns a string representation of the parameters for this SetpiecePrg object.
---
--- The string will be in the format "state, param1, param2, ...", where "state" is always included,
--- and the remaining parameters are the values in the `Params` table, if any.
---
--- @return string The parameter string representation.
function SetpiecePrg:GetParamString()
	return next(self.Params) and "state, " .. table.concat(self.Params, ", ") or "state"
end

--- Sets the Map property of the SetpiecePrg object to the current map.
---
--- This function is called when a new SetpiecePrg object is created in the editor.
--- It sets the Map property of the object to the name of the current map, so that the
--- setpiece is associated with the correct map.
function SetpiecePrg:OnEditorNew()
	self.Map = CurrentMap
end

if FirstLoad then
	g_LastSelectedSetpiece = false
end

--- Called when the SetpiecePrg object is selected in the editor.
---
--- This function sets the `g_LastSelectedSetpiece` global variable to the currently selected SetpiecePrg object.
---
--- @param selected boolean Whether the SetpiecePrg object is currently selected.
--- @param ged table The Ged editor object.
function SetpiecePrg:OnEditorSelect(selected, ged)
	g_LastSelectedSetpiece = selected and self or g_LastSelectedSetpiece
end

--- Called when the map has finished changing.
---
--- This function is called when the map has finished changing. It checks if there is a
--- last selected setpiece, and if so, it clears the property cache for that setpiece
--- and marks the setpiece as modified. This ensures that the list of markers displayed
--- in the editor is updated to reflect the new map.
function OnMsg.ChangeMapDone()
	if g_LastSelectedSetpiece then
		g_LastSelectedSetpiece:EditorData().prop_cache = nil
		ObjModified(g_LastSelectedSetpiece) -- update list of markers displayed via virtual properties
	end
end

--- Switches the map associated with the SetpiecePrg object.
---
--- This function is called when the user wants to switch the map associated with the
--- SetpiecePrg object. It first checks if the map specified in the `Map` property
--- exists, and if not, it displays an error message. If the map exists, it changes
--- the map and clears the property cache for the SetpiecePrg object, then marks
--- the object as modified to update the list of markers displayed in the editor.
---
--- @param selected boolean Whether the SetpiecePrg object is currently selected.
--- @param prop_id string The ID of the property that was changed.
--- @param ged table The Ged editor object.
function SetpiecePrg:SwitchMap(selected, prop_id, ged)
	if not MapData[self.Map] then
		ged:ShowMessage("Error", string.format("Can't find map '%s'", self.Map))
		return
	end
	CreateRealTimeThread(function()
		ChangeMap(self.Map)
		self:EditorData().prop_cache = nil
		ObjModified(self)
	end)
end

--- Retrieves the properties of the SetpiecePrg object, including any referenced markers.
---
--- This function first checks if the property cache has already been populated. If not, it
--- creates a copy of the base properties, then gathers all the markers that are referenced
--- by the statements in the SetpiecePrg object. It then adds these marker properties to the
--- list of properties, sorted by the marker name. The resulting list of properties is cached
--- in the `prop_cache` field of the SetpiecePrg object's editor data.
---
--- @return table The list of properties for the SetpiecePrg object, including any referenced markers.
function SetpiecePrg:GetProperties()
	local props = self:EditorData().prop_cache
	if not props then
		props = table.copy(PropertyObject.GetProperties(self), "deep")
		local markers
		local referenced_markers_map = {}	
		
		-- Gather all markers referenced in this setpiece
		for idx, statement in ipairs(self) do
			if statement.Marker then
				referenced_markers_map[statement.Marker] = true
			elseif statement.Waypoints then
				for _, pos_marker in ipairs(statement.Waypoints) do
					if pos_marker then
						referenced_markers_map[pos_marker] = true
					end
				end
			end
		end

		if GetMap() ~= "" then
			-- Get all markers that have a name and are referenced by this setpiece
			markers = MapGet("map", "SetpieceMarker", function(obj)
				return obj.Name and referenced_markers_map[obj.Name]
			end)
		end

		if markers then
			local marker_props = {}
			for _, marker in ipairs(markers) do
				table.insert(marker_props, {
					id = marker.Name ~= "" and marker.Name or "[Unnamed]",
					editor = "text",
					category = "Map",
					default = marker.DisplayName,
					read_only = true,
					dont_save = true,
					buttons = {{ name = "View", func = function(...) return SetpieceViewMarker(...) end, param = marker.Name }}
				})
			end
			table.sortby_field(marker_props, "id")
			local start_idx = table.find(props, "id", "NotOnMap")
			for i = 1, #marker_props do
				table.insert(props, i + start_idx - 1, marker_props[i])
			end
		end
		
		self:EditorData().prop_cache = props
	end
	return props
end

--- Called before the setpiece is saved.
---
--- This function is called just before the setpiece is saved. It sends a message to notify other systems that the setpiece execution is ending.
---
--- @param user_requested boolean Whether the save was requested by the user.
function SetpiecePrg:OnPreSave(user_requested)
	Msg("SetpieceEndExecution", self)
end

---
--- Saves the current setpiece program and all its associated presets.
---
--- This function is called when the user requests to save the setpiece program. It first checks if the editor is currently saving the map, and if so, waits for the save to complete. If the map is dirty, it triggers a save of the map.
---
--- It then suspends file system change notifications, saves all the presets associated with the setpiece program, and reloads the relevant generated files. Finally, it resumes the file system change notifications.
---
--- @param ... Any additional arguments passed to the Preset.SaveAll function.
--- @return table A table of saved presets and their file paths.
function SetpiecePrg:SaveAll(...)
	if IsEditorSaving() then
		WaitMsg("SaveMapDone")
	elseif EditorMapDirty then
		XEditorSaveMap()
	end
	
	-- do not trigger Lua reload, we will reload only the relevant generated files
	SuspendFileSystemChanged("save_setpiece")
	local saved_presets = Preset.SaveAll(self, ...)
	for preset, path in pairs(saved_presets) do
		dofile(preset:GetCompanionFilesList(path)[true])
	end
	Sleep(250) -- give time to the file changed notification to arrive
	FileSystemChangedFiles = false
	ResumeFileSystemChanged("save_setpiece")
end

---
--- Returns whether the movie black bars dialog is currently visible.
---
--- @return boolean True if the movie black bars dialog is visible, false otherwise.
function GedPrgPresetBlackStripsVisible()
	return not not GetDialog("XMovieBlackBars")
end

---
--- Toggles the visibility of the movie black bars dialog.
---
--- If the movie black bars dialog is currently visible, this function will close it. Otherwise, it will open the dialog.
---
--- @param ged table The GED object associated with the setpiece program.
---
function GedPrgPresetToggleStrips(ged)
	if GedPrgPresetBlackStripsVisible() then
		CloseDialog("XMovieBlackBars")
	else
		OpenDialog("XMovieBlackBars")
	end
end

---
--- Handles the closing of a GED window associated with a SetpiecePrg object.
---
--- When a GED window associated with a SetpiecePrg object is closed, this function will close the "XMovieBlackBars" dialog if it is currently open.
---
--- @param ged_id string The ID of the GED window that is being closed.
---
function OnMsg.GedClosing(ged_id)
	local app = GedConnections[ged_id]
	if app and app.context and app.context.PresetClass == "SetpiecePrg" then
		CloseDialog("XMovieBlackBars")
	end
end

---
--- Changes the map to the map specified in the SetpiecePrg object, if it is different from the current map.
---
--- If the map needs to be changed, this function will prompt the user to confirm the change before proceeding.
---
--- @param ged table The GED object associated with the setpiece program.
--- @return boolean True if the map was changed or the user confirmed not to change the map, false otherwise.
---
function SetpiecePrg:ChangeMap(ged)
	if self.Map ~= "" and self.Map ~= CurrentMap then
		local result
		if ged then
			result = ged:WaitQuestion("Change Map", "This setpiece is set on another map.\n\nChange the map and continue?", "Yes", "No")
		else
			result = WaitQuestion(terminal.desktop, T(946126153891, "Change Map"), T(354774024588, "This setpiece is set on another map.\n\nChange the map and continue?"), T(1138, "Yes"), T(1139, "No"))
		end
		if result ~= "ok" then
			return false
		end
		ChangeMap(self.Map)
	end
	return true
end

---
--- Runs a test for the SetpiecePrg object.
---
--- This function performs the following steps:
--- - Checks if the setpiece has any commands. If not, it displays a warning message.
--- - Checks if the map needs to be changed and prompts the user to confirm the change.
--- - Checks if there are any unsaved changes and prompts the user to save them.
--- - Saves the setpiece if necessary, and reloads the Lua files if in the mod editor.
--- - Deactivates the editor if active, and starts a new game if necessary.
--- - Sets the game speed and fast-forwards time if specified in the setpiece.
--- - Toggles the movie black bars dialog if it is currently visible.
--- - Runs the setpiece in test mode, either by opening the setpiece dialog or by directly invoking the setpiece.
--- - Restores the editor camera position if the editor was active.
--- - Cleans up the test actors and registers the real actors.
--- - Reactivates the editor if it was previously active.
---
--- @param ged table The GED object associated with the setpiece program.
---
function SetpiecePrg:Test(ged)
	local in_mod_editor = ged and ged.app_template == "ModEditor"
	
	if #self == 0 then
		ged:ShowMessage("Warning", "The setpiece has no commands.")
		return
	end
	
	if IsEditorSaving() then
		WaitMsg("SaveMapDone")
	end
	
	if not self:ChangeMap(ged) then
		return
	end
	
	local dirty
	ForEachPreset("SetpiecePrg", function(preset)
		dirty = dirty or preset:IsDirty()
		if dirty then
			return "break"
		end
	end)
	if dirty then
		local result
		if ged then
			result = ged:WaitQuestion("Changes Not Saved", "Changes need to be saved for testing.\n\nSave and continue?", "Yes", "No")
		else
			result = WaitQuestion(terminal.desktop, T(610687239101, "Changes Not Saved"), T(565937963985, "Changes need to be saved for testing.\n\nSave and continue?"), T(1138, "Yes"), T(1139, "No"))
		end
		if result ~= "ok" then
			return false
		end
		if in_mod_editor then
			self:PostSave()
			if self.mod:UpdateCode() then
				ReloadLua()
			end
		else
			self:SaveAll() -- will reload the generated Lua files
		end
	elseif EditorMapDirty then
		XEditorSaveMap()
	end
	
	local in_editor = IsEditorActive()
	if in_editor then
		-- keep the editor camera position when testing
		local pos, lookat = GetCamera()
		if in_mod_editor then
			editor.StopModdingEditor()
		else
			EditorDeactivate()
		end
		local _, _, camtype = GetCamera()
		_G["camera"..camtype].SetCamera(pos, lookat)
	end
	if not Game then
		NewGame()
	end
	Resume()
	
	-- setup game speed
	local speed = GetTimeFactor()
	local fast_forward_time = self.FastForward
	local test_factor = MulDivRound(speed, self.TestSpeed, 100)
	local time_thread = CreateGameTimeThread(function()
		WaitMsg("SetpieceStarted")
		if fast_forward_time > 0 then
			SetTimeFactor(const.MaxTimeFactor)
			Sleep(fast_forward_time)
		end
		SetTimeFactor(test_factor)
	end)
	
	if GedPrgPresetBlackStripsVisible() then
		GedPrgPresetToggleStrips()
	end
	
	DiagnosticMessageSuspended = true
	local state
	if self.TakePlayerControl then
		local dlg = OpenDialog("XSetpieceDlg", false, { setpiece = self.id, testMode = true, })
		WaitMsg(dlg)
		state = dlg.setpieceInstance
	else -- invoke the same messages as the dialog, used for Setpiece recording
		Msg("SetpieceStarted", self)
		state = StartSetpiece(self.id, true, AsyncRand())
		WaitMsg("SetpieceEndExecution")
		Msg("SetpieceEnding", self)
		Msg("SetpieceEnded", self)
	end
	DiagnosticMessageSuspended = false
	
	DeleteThread(time_thread)
	SetTimeFactor(speed)
	
	for _, actor in ipairs(state.real_actors or empty_table) do
		if IsValid(actor) then actor:SetVisible(true) end
	end
	for _, actor in ipairs(state.test_actors or empty_table) do
		if IsValid(actor) then actor:delete() end
	end
	RegisterSetpieceActors(state.test_actors, false)
	
	if in_editor and not in_mod_editor then
		EditorActivate()
	end
end


----- Markers

--- Defines a SetpieceMarker class that inherits from EditorMarker, StripCObjectProperties, and StripComponentAttachProperties.
---
--- The SetpieceMarker class has the following properties:
---
--- - `Setpiece`: a preset_id property that is read-only and references a SetpiecePrg object.
--- - `Name`: a text property that represents the name of the marker.
--- - `Angle`: a number property that represents the angle of the marker, and is not editable.
--- - `Axis`: a point property that represents the axis of the marker, and is not editable.
---
--- The `editor_text_offset` property sets the offset of the editor text to (0, 0, 320*guic).
--- The `editor_text_member` property sets the member of the object that the editor text should be displayed for to "Name".
DefineClass.SetpieceMarker = {
	__parents = { "EditorMarker", "StripCObjectProperties", "StripComponentAttachProperties", },
	properties = {
		{ id = "Setpiece", editor = "preset_id", default = "", preset_class = "SetpiecePrg", read_only = true, },
		{ id = "Name", editor = "text", default = "", },
		
		-- save angle and axis in map
		{ id = "Angle", editor = "number", default = 0, no_edit = true, },
		{ id = "Axis", editor = "point", default = axis_z, no_edit = true, },
	},
	editor_text_offset = point(0, 0, 320*guic),
	editor_text_member = "Name",
}

---
--- Handles changes to the `Name` property of a `SetpieceMarker` object.
---
--- When the `Name` property is changed, this function generates a unique name for the marker, updates the name, forces the object to be updated in the editor, and marks the object as modified. It also updates the list of setpieces that reference this marker.
---
--- @param old_name string The previous name of the marker.
--- @param ged table The editor data associated with the marker.
---
function SetpieceMarker:OnNameChanged(old_name, ged)
end
function SetpieceMarker:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "Name" then
		self:OnNameChanged(old_value, ged)
	end
end

---
--- Handles changes to the `Name` property of a `SetpieceMarker` object.
---
--- When the `Name` property is changed, this function generates a unique name for the marker, updates the name, forces the object to be updated in the editor, and marks the object as modified. It also updates the list of setpieces that reference this marker.
---
--- @param old_name string The previous name of the marker.
--- @param ged table The editor data associated with the marker.
---
function SetpieceMarker:OnNameChanged(old_name, ged)
	local new_name = self:GenerateUniqueName(self.Name)
	if self.Name ~= new_name then
		self.Name = new_name
		GedForceUpdateObject(self)
		ObjModified(self)
	end
	self:EditorTextUpdate(true)

	self:UpdateSetpieceMarkersList("rename", old_name, ged)
end

-- If reason is "delete" - the user has deleted the marker
-- If old_name is passed - the marker has been renamed and old_name is the previous name
-- ged is passed only on rename
---
--- Updates the list of setpieces that reference a `SetpieceMarker` object.
---
--- When a `SetpieceMarker` object is renamed or deleted, this function updates the list of setpieces that reference the marker. If the marker was renamed, it asks the user if they want to rename the marker in all referencing setpieces. If the marker was deleted, it warns the user that the marker is referenced in setpieces and deleting it will create errors.
---
--- @param reason string The reason for the update, either "rename" or "delete".
--- @param old_name string The previous name of the marker (only for "rename" reason).
--- @param ged table The editor data associated with the marker (only for "rename" reason).
---
function SetpieceMarker:UpdateSetpieceMarkersList(reason, old_name, ged)
	-- The marker could have been renamed
	local marker_name = old_name and old_name or self.Name
	local referencing_setpieces = {}
	local setpieces_str

	-- Invalidate the cache of all setpieces that reference this marker
	for name, setpiece in pairs(Setpieces) do
		for statement_idx, statement in ipairs(setpiece) do
			if statement.Marker and statement.Marker == marker_name then
				setpiece:EditorData().prop_cache = nil
				ObjModified(setpiece)
				
				referencing_setpieces[setpiece.id] = statement_idx
				setpieces_str = setpieces_str and (setpieces_str .. ", " .. setpiece.id) or setpiece.id
			elseif statement.Waypoints then
				for idx, pos_marker in ipairs(statement.Waypoints) do
					if pos_marker and pos_marker == marker_name then
						setpiece:EditorData().prop_cache = nil
						ObjModified(setpiece)
						
						referencing_setpieces[setpiece.id] = statement_idx
						setpieces_str = setpieces_str and (setpieces_str .. ", " .. setpiece.id) or setpiece.id
					end
				end
			end
		end
	end
	
	if reason == "delete" or reason == "rename" then
		-- otherwise, it is editor undo or applying a map patch
		
		-- If the marker was renamed, ask the user if we should renamed it in all referencing setpieces
		if old_name and setpieces_str then
			CreateRealTimeThread(function ()
				local message = string.format("Rename marker '%s' in all referencing setpieces: %s? \nYou have to save them manually.", marker_name, setpieces_str)
				if ged and ged:WaitQuestion("Warning", message) == "ok" then

					for setpiece_id, statement_idx in pairs(referencing_setpieces) do
						local setpiece = Setpieces[setpiece_id]
						local statement = setpiece[statement_idx]
						
						if statement.Marker and statement.Marker == marker_name then
							-- Rename
							statement.Marker = self.Name
							
							setpiece:EditorData().prop_cache = nil
							ObjModified(setpiece)
							
						elseif statement.Waypoints then
							for idx, pos_marker in ipairs(statement.Waypoints) do
								if pos_marker and pos_marker == marker_name then
									-- Rename
									statement.Waypoints[idx] = self.Name
									
									setpiece:EditorData().prop_cache = nil
									ObjModified(setpiece)
								end
							end
						end
					end
					
				end
			end)
		elseif reason == "delete" and setpieces_str then
			CreateRealTimeThread(function ()
				local message = string.format("Marker '%s' is referenced in setpieces: %s.\nDeleting it will create errors in those setpieces.", marker_name, setpieces_str)
				WaitMessage(terminal.desktop, Untranslated("Warning"), Untranslated(message))
			end)
		end
	end
end

SetpieceMarker.EditorCallbackPlace = SetpieceMarker.OnNameChanged
SetpieceMarker.EditorCallbackClone = SetpieceMarker.OnNameChanged

---
--- Callback function called when a SetpieceMarker is deleted or renamed in the editor.
--- This function updates the list of SetpieceMarkers and handles any necessary actions, such as renaming the marker in referencing setpieces.
---
--- @param reason string The reason for the name change, either "delete" or "rename".
function SetpieceMarker:EditorCallbackDelete(reason)
	self:UpdateSetpieceMarkersList(reason or "delete")
end

---
--- Generates a unique name for a SetpieceMarker object by checking for existing names in the map.
---
--- @param name string The base name to use for generating the unique name.
--- @return string The generated unique name.
---
function SetpieceMarker:GenerateUniqueName(name)
	local used_names = {}
	MapForEach("map", "SetpieceMarker", function(obj)
		if obj ~= self then used_names[obj.Name] = true end
	end)
	if not used_names[self.Name] then
		return self.Name
	end

	local new
	local n = 0
	local id1, n1 = name:match("(.*)_(%d+)$")
	if id1 and n1 then
		name, n = id1, tonumber(n1)
	end
	repeat
		n = n + 1
		new = string.format("%s_%02d", name, n)
	until not used_names[new]
	return new
end

---
--- Sets the position and orientation of a group of actors relative to a SetpieceMarker.
---
--- @param actors table A table of actors to be positioned and oriented.
--- @param duration number (optional) The duration in seconds for the animation to complete.
--- @param speed_change number (optional) The change in speed for the animation.
--- @param set_orient boolean (optional) Whether to set the orientation of the actors.
---
function SetpieceMarker:SetActorsPosOrient(actors, duration, speed_change, set_orient)
	local ptCenter = GetWeightPos(actors)
	if not ptCenter:IsValidZ() then
		ptCenter = ptCenter:SetTerrainZ()
	end
	local base_angle = #actors > 0 and actors[1]:GetAngle()
	for _, actor in ipairs(actors) do
		local pos = actor:GetVisualPos()
		local offset = Rotate(pos - ptCenter, self:GetAngle() - base_angle)
		local dest = self:GetPos() + offset
		local anim_duration = duration or actor:GetAnimDuration()
		if not speed_change or speed_change == 0 then
			actor:SetAcceleration(0)
		else
			local speed = MulDivRound(pos:Dist(dest), 1000, anim_duration)
			local acc = actor:GetAccelerationAndFinalSpeed(dest, Max(0, speed - speed_change / 2), anim_duration)
			actor:SetAcceleration(acc)
		end
		actor:SetPos(dest, anim_duration)
		if set_orient then
			actor:SetAxisAngle(self:GetAxis(), self:GetAngle() + actor:GetAngle() - base_angle, anim_duration)
		end
	end
end

---
--- Gets the locations of a group of actors relative to a SetpieceMarker.
---
--- @param actors table A table of actors to get the locations for.
--- @return table An array of positions for the actors relative to the SetpieceMarker.
---
function SetpieceMarker:GetActorLocations(actors)
	local pts = {}
	local pos = self:GetPos()
	local count = #actors
	if count == 1 then
		pts[1] = pos
	elseif count > 1 then
		local ptCenter = GetWeightPos(actors)
		local angle = self:GetAngle() - actors[1]:GetAngle()
		for i = 1, count do
			pts[i] = pos + Rotate(actors[i]:GetVisualPos() - ptCenter, angle):SetZ(0)
		end
	end
	return pts
end

--- Validates the game object properties for all SetpieceMarker instances in the map.
---
--- This function is called when the map is validated, and ensures that all SetpieceMarker
--- instances have valid properties.
OnMsg.ValidateMap = ValidateGameObjectProperties("SetpieceMarker")

---
--- Defines a SetpiecePosMarker class that inherits from SetpieceMarker.
---
--- The SetpiecePosMarker class represents a marker in the game world that is used to position objects
--- as part of a setpiece. It inherits from the base SetpieceMarker class and has the display name "Pos".
---
DefineClass.SetpiecePosMarker = {
	__parents = { "SetpieceMarker" },
	DisplayName = "Pos",
}

---
--- Defines a base class for SetpieceMarker objects that represent markers in the game world used for positioning objects as part of a setpiece.
---
--- The SetpieceSpawnMarkerBase class inherits from the SetpieceMarker class and provides a base implementation for spawn marker objects. It has the display name "Pos".
---
--- @class SetpieceSpawnMarkerBase
--- @field DisplayName string The display name of the spawn marker object.
--- @field __parents table The parent classes that this class inherits from.
DefineClass.SetpieceSpawnMarkerBase = {
	__parents = { "SetpieceMarker" },
	DisplayName = "Pos",
}

---
--- Defines a class for a SetpieceParticleSpawnMarker, which is a type of SetpieceSpawnMarkerBase.
---
--- The SetpieceParticleSpawnMarker class has the following properties:
---
--- - `Particles`: A combo box that allows the user to select the particles to be spawned.
--- - `PartScale`: A number slider that allows the user to set the scale of the spawned particles, with a range of 50 to 200.
---
--- The class also has a `DisplayName` property set to "Particles".
---
--- The class has a `SpawnObjects()` function that places the particles specified by the `Particles` property and sets their scale to the value of the `PartScale` property.
---
--- The `TestParticles()` function is a helper function that spawns the particles specified by the `Particles` property, attaches them to the marker, changes the marker's entity to an "InvisibleObject", sets the particle scale, and then after 1.5 seconds, stops the particles and destroys the object, and changes the marker's entity back to the SetpieceParticleSpawnMarker entity.
---
DefineClass.SetpieceParticleSpawnMarker = {
	__parents = { "SetpieceSpawnMarkerBase" },
	properties = {
		{ id = "Particles", category = "Particles", default = "", editor = "combo", items = ParticlesComboItems, buttons = {{name = "Test", func = "TestParticles"}, {name = "Edit", func = "ActionEditParticles"}}},
		{ id = "PartScale", category = "Particles", default = 100, editor = "number", slider = true, min = 50, max = 200, name = "Scale" },
	},
	DisplayName = "Particles",
}

---
--- Spawns the particles specified by the `Particles` property and sets their scale to the value of the `PartScale` property.
---
--- @return table The spawned particle objects.
function SetpieceParticleSpawnMarker:SpawnObjects()
	local obj = PlaceParticles(self.Particles)
	obj:SetScale(self.PartScale)
	return { obj }
end

---
--- Spawns the particles specified by the `Particles` property, attaches them to the marker, changes the marker's entity to an "InvisibleObject", sets the particle scale, and then after 1.5 seconds, stops the particles and destroys the object, and changes the marker's entity back to the SetpieceParticleSpawnMarker entity.
---
--- @param ged table The game editor object.
--- @param marker SetpieceParticleSpawnMarker The spawn marker object.
--- @param prop_id string The property ID.
---
function TestParticles(ged, marker, prop_id)
	local obj = PlaceParticles(marker.Particles)
	if not obj then
		return
	end
	
	marker:Attach(obj)
	marker:ChangeEntity("InvisibleObject")
	obj:SetScale(marker.PartScale)
		
	CreateRealTimeThread(function(obj)
		Sleep(1500)
		if IsValid(obj) then
			StopParticles(obj, true)
			DoneObject(obj)
		end
		if IsValid(marker) then
			marker:ChangeEntity(SetpieceParticleSpawnMarker.entity)
		end
	end, obj)
end

-- you may redefine the class for your project; it needs to inherit "SetpieceSpawnMarkerBase", requires DisplayName and SpawnObjects()
---
--- Defines a class `SetpieceSpawnMarker` that inherits from `SetpieceSpawnMarkerBase`. This class represents a spawn marker for a setpiece object.
---
--- The class has the following properties:
---
--- - `SpawnClass`: The class of the object to be spawned when this marker is used.
--- - `_`: A help property that provides information about the spawned object properties.
---
--- The class also has the following methods:
---
--- - `GetProperties()`: Returns the properties of the class, including any properties inherited from the `SpawnClass`.
--- - `SetSpawnClass(class)`: Sets the `SpawnClass` property and updates the entity of the marker accordingly.
--- - `SpawnObjects()`: Returns a table containing the spawned object.
---
--- The `SetpieceMarkersCombo()` function is a utility function that returns a function that can be used to populate a combo box with the names of all `SetpieceSpawnMarker` objects in the current map.
DefineClass.SetpieceSpawnMarker = {
	__parents = { "SetpieceSpawnMarkerBase" },
	properties = {
		{ id = "SpawnClass", name = "Spawn class", editor = "choice", default = "",
			items = ClassDescendantsCombo("CObject", false, function(name, class) return IsValidEntity(class:GetEntity()) end), },
		{ id = "_", editor = "help", default = false, help = "Spawned object properties:", },
	},
	DisplayName = "Spawn",
	prop_cache = false,
}

---
--- Returns the properties of the `SetpieceSpawnMarker` class, including any properties inherited from the `SpawnClass`.
---
--- If the `prop_cache` property is not set, this function will create a copy of the properties from the `PropertyObject` class, and then append any additional properties from the `SpawnClass`. If the `SpawnClass` has any properties that match the properties of the `SetpieceSpawnMarker` class, the properties from the `SetpieceSpawnMarker` class will be removed.
---
--- The resulting properties table is cached in the `prop_cache` property to improve performance on subsequent calls.
---
--- @return table The properties of the `SetpieceSpawnMarker` class, including any properties inherited from the `SpawnClass`.
function SetpieceSpawnMarker:GetProperties()
	local props = self.prop_cache
	if not props then
		props = table.copy(PropertyObject.GetProperties(self), "deep")
		local class = g_Classes[self.SpawnClass]
		if class then
			local spawned_props = table.copy(class:GetProperties(), "deep")
			for _, prop in ipairs(spawned_props) do
				local idx = table.find(props, "id", prop.id)
				if idx then table.remove(props, idx) end
			end
			table.iappend(props, spawned_props)
		end
		if self ~= SetpieceSpawnMarker then
			self.prop_cache = props
		end
	end
	return props
end

---
--- Sets the `SpawnClass` property of the `SetpieceSpawnMarker` and updates the entity of the marker accordingly.
---
--- This function performs the following steps:
---
--- 1. Sets the `SpawnClass` property to the provided `class` value.
--- 2. Clears the `prop_cache` property, which will force the `GetProperties()` function to rebuild the cached properties.
--- 3. Retrieves the `g_Classes[class]` or falls back to the `SetpieceSpawnMarker` class if the provided `class` is not found.
--- 4. Changes the entity of the marker to the entity of the retrieved class.
--- 5. Updates the `editor_text_offset` property to position the editor text above the entity's bounding box.
--- 6. Destroys the previous editor text object and updates the editor text.
---
--- @param class string The class to set as the `SpawnClass` property.
function SetpieceSpawnMarker:SetSpawnClass(class)
	self.SpawnClass = class
	self.prop_cache = nil
	
	class = g_Classes[class] or SetpieceSpawnMarker
	self:ChangeEntity(class:GetEntity())
	
	self.editor_text_offset = point(0, 0, self:GetEntityBBox():maxz() + guim / 2)
	DoneObject(self.editor_text_obj)
	self:EditorTextUpdate(true)
end

--- Spawns a new object by cloning the object specified by the `SpawnClass` property.
---
--- @return table An array containing the newly spawned object.
function SetpieceSpawnMarker:SpawnObjects()
	return { self:Clone(self.SpawnClass) }
end


----- Utilities for marker properties, including a set of Place/View buttons

---
--- Returns a function that generates a list of marker names for a given class.
---
--- The returned function takes a single argument `self`, which is expected to be a
--- `SetpiecePrg` object. It then retrieves all `SetpieceMarker` objects in the current
--- map and collects their names into a table, which is then sorted and returned.
---
--- If the current map is empty, the table will contain a single empty string.
---
--- @param class string The class of the markers to search for.
--- @return function A function that generates a list of marker names.
---
function SetpieceMarkersCombo(class)
	return function(self)
		local setpiece = GetParentTableOfKind(self, "SetpiecePrg")
		local markers = {""}
		if GetMap() ~= "" then
			MapForEach("map", class, function(obj, setpiece_id, markers)
				if obj.Name then
					markers[#markers + 1] = obj.Name
				end
			end, setpiece.id, markers)
		end
		table.sort(markers)
		return markers
	end
end

---
--- Retrieves a `SetpieceMarker` object from the current map by its name.
---
--- If the marker is not found and the `check` parameter is true, a message box is displayed
--- indicating that the marker is missing.
---
--- @param name string The name of the marker to retrieve.
--- @param check boolean If true, a message box will be displayed if the marker is not found.
--- @return table|boolean The `SetpieceMarker` object if found, or false if not found.
---
function SetpieceMarkerByName(name, check)
	if not name or name == "" then return false end
	local marker = MapGetFirst("map", "SetpieceMarker", function(obj) return obj.Name == name end)
	if (AreModdingToolsActive() or Platform.developer) and check and not marker then
		CreateMessageBox(nil, Untranslated("Error"), Untranslated(string.format("Spawn marker '%s' is missing", name)))
	end
	return marker
end

local function find_previous_prop_meta(obj, prop_id)
	local prev
	for _, prop_meta in ipairs(obj:GetProperties()) do
		if prop_meta.id == prop_id then break end
		prev = prop_meta
	end
	return prev
end

---
--- Handles the placement of a SetpieceMarker object on the current map.
---
--- If the object has an "AssignTo" member, its value is used as the marker name.
--- Otherwise, the user is prompted to enter a name for the marker.
---
--- The marker is placed using the XEditorStartPlaceObject function, and its name is set.
--- If the object is not a SetpiecePrg, the marker name is added to the appropriate property (either a string_list or a single string).
---
--- @param obj table The object that triggered the button click.
--- @param root table The root object of the UI hierarchy.
--- @param prop_id string The ID of the property that triggered the button click.
--- @param ged table The GED (Game Editor) object.
--- @param btn_param string The parameter passed to the button.
---
function SetpieceMarkerPlaceButton(obj, root, prop_id, ged, btn_param)
	-- handle adding a waypoint to the 'string_list' Waypoints prop from the buttons prop below Waypoints
	local prop_meta = obj:GetPropertyMetadata(prop_id)
	if prop_meta.editor == "buttons" then
		prop_meta = find_previous_prop_meta(obj, prop_id)
		prop_id = prop_meta.id
	end

	local setpiece = GetParentTableOfKind(obj, "SetpiecePrg") or obj
	if not setpiece:ChangeMap(ged) then
		return
	end

	local name = obj:HasMember("AssignTo") and obj.AssignTo or ""
	if name == "" then
		name = ged:WaitUserInput("Enter marker name")
		if not name then return end
		if obj:HasMember("AssignTo") and obj.AssignTo == "" then
			obj.AssignTo = name
		end
	end

	local in_mod_editor = ged and ged.app_template == "ModEditor"
	if in_mod_editor then
		editor.StartModdingEditor(obj, obj.Map)
	else
		EditorActivate()
	end
	local editor_cursor_obj = XEditorStartPlaceObject(btn_param)
	editor_cursor_obj.Name = name
	editor_cursor_obj:OnNameChanged(false, ged)
	
	if not obj:IsKindOf("SetpiecePrg") then
		if prop_meta.editor == "string_list" then
			obj[prop_id] = obj[prop_id] or {}
			table.insert(obj[prop_id], editor_cursor_obj.Name)
		else
			obj[prop_id] = editor_cursor_obj.Name
		end
	end
	ObjModified(obj)
end

---
--- Handles the viewing of a marker in the SetpiecePrg module.
---
--- @param obj table The object that triggered the button click.
--- @param root table The root object of the UI hierarchy.
--- @param prop_id string The ID of the property that triggered the button click.
--- @param ged table The GED (Game Editor) object.
--- @param btn_param string The parameter passed to the button.
---
function SetpieceViewMarker(obj, root, prop_id, ged, btn_param)
	-- handle viewing a waypoints in the 'string_list' Waypoints prop
	local marker_name = btn_param or obj[prop_id]
	local prop_meta = obj:GetPropertyMetadata(prop_id)
	if prop_meta.editor == "buttons" then
		local waypoints_list = obj[find_previous_prop_meta(obj, prop_id).id]
		marker_name = waypoints_list and waypoints_list[1]
	end
	
	local setpiece = GetParentTableOfKind(obj, "SetpiecePrg") or obj
	if not setpiece:ChangeMap(ged) then
		return
	end
	
	local marker = SetpieceMarkerByName(marker_name)
	if marker then
		local in_mod_editor = ged and ged.app_template == "ModEditor"
		if in_mod_editor then
			editor.StartModdingEditor(obj, obj.Map)
		else
			EditorActivate()
		end
		EditorActivate()
		ViewObject(marker)
		editor.AddToSel{marker}
	else
		ged:ShowMessage("Error", "Marker not found.")
	end
end

---
--- Generates a table of buttons for a SetpieceMarker property.
---
--- @param marker_class string The class name of the SetpieceMarker.
--- @return table A table of button definitions for the SetpieceMarker property.
---
function SetpieceMarkerPropButtons(marker_class)
	return { {
		name = "Place",
		func = SetpieceMarkerPlaceButton,
		param = marker_class,
		is_hidden = function(obj, prop_meta) return obj:IsKindOf("GedMultiSelectAdapter") or prop_meta.editor ~= "buttons" and obj[prop_meta.id] ~= "" end,
	},
	{
		name = "View",
		func = SetpieceViewMarker,
	} }
end

---
--- Checks if the current map is different from the map of the given SetpiecePrg object.
---
--- @param obj SetpiecePrg The SetpiecePrg object to check the map for.
--- @return boolean True if the map is changing or the object's map is different from the current map, false otherwise.
---
function SetpieceCheckMap(obj)
	return IsChangingMap() or GetParentTableOfKind(obj, "SetpiecePrg").Map ~= CurrentMap
end
