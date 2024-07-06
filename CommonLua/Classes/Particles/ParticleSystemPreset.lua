DefineClass.BehaviorFilter = {
	__parents = { "GedFilter" },
	properties = {
		{ id = "bins", name = "Bins", editor = "set", items = { "A", "B", "C", "D", "E", "F", "G", "H" }, max_items_in_set = 1 },
	},
	bins = set(),
}

---
--- Filters an object based on the bins specified in the `BehaviorFilter` instance.
---
--- @param o table The object to filter.
--- @return boolean True if the object should not be filtered, false otherwise.
---
function BehaviorFilter:FilterObject(o)
	if not self.bins or not IsSet(self.bins) then return false end
	
	for bin, value in pairs(self.bins) do
		if value and o:HasMember("bins") and not o.bins[bin] then
			return false -- filter item
		end
	end

	return true -- don't filter item
end

DefineClass.ParticleSystemSubItem = {
	__parents = { "InitDone" },
	EditorName = "Particle System Element",
	EditorSubmenu = "Other",
}

DefineClass.ParticleSystemPreset = {
	__parents = { "Preset" },
	properties = {
		{ id = "ui", name = "UI Particle System" , editor = "bool", default = false },
		{ id = "simul_fps", name = "Simul FPS", editor = "number", slider = true, min = 1, max = 60, help = "The simulation framerate" },
		{ id = "speed_up", name = "Speed-up", editor = "number", slider = true, min = 10, max = 10000, scale = 1000, help = "How many times the particle simulation is being sped up." }, 
		{ id = "presim_time", name = "Presim time", editor = "number", scale = "sec", help = "How many seconds to presimulate, before showing the system for the first time", min = 0, max = 120000, slider = true },
		{ id = "max_initial_catchup_time", name = "Initial Catchup Time", editor = "number", scale = 1000, help = "How much work should newly created renderobjs do before displaying them. 0 here is equivalent to ignore_game_object_age"},
		{ id = "rand_start_time", name = "Max starting phase time", editor = "number", scale = "sec", help = "Maximum additional presim time used to randomize the starting phase of the particle system.", min = 0, max = 10000, slider = true },
		
		{ id = "distance_bias", name = "Camera distance offset", editor = "number", min = -100000, max = 100000, scale = 1000, help = "How much to offset the particle system relative to the camera. It is used to make the particle system to appear always on top of some other transparent object.", slider = true },
		{ id = "particles_scale_with_object", name = "Particles scale with object", editor = "bool", help = "Particle size scales with the object scale" },
		{ id = "game_time_animated", name = "Game time animated", editor = "bool", help = "Will animate in game time, i.e. will pause when the game is paused or slowed down", read_only = function(self) return self.ui end },
		{ id = "ignore_game_object_age", name = "Ignore GameObject age", editor = "bool", default = false, help = "Long running particles remember when they were created, and try to catch up if they lose their state. Enables/disables this behaviour.", read_only = function(self) return self.ui end },
		{ id = "vanish", name = "Vanish when killed", editor = "bool", help = "Fx will disappear completely when destroyed, without waiting the existing particles to reach their age" },
		{ id = "post_lighting", name = "Post Lighting" , editor = "bool", default = false, help = "Render after lighting related post processing." },
		{ id = "stable_cam_distance", name = "Stable Camera Distance" , editor = "bool", default = false, help = "Render in consistent order while the camera & the particle system are not moving. This has a performance penalty for systems with particles far away from the center." },
		{ id = "testcode", category = "Custom Test Setup", name = "Test code", editor = "func", params = "self, ged, enabled", default = false, no_edit = function(self) return not self.ui end, },
	},
	
	simul_fps = 30,
	speed_up = 1000,
	presim_time = 0,
	max_initial_catchup_time = 2000, -- 0 is a better default, but 2000 is the "old" one, so we don't have to rework parsys
	rand_start_time = 0,
	distance_bias = 0,
	particles_scale_with_object = false,
	game_time_animated = false,
	vanish = false,
	
	
	-- Preset settings
	SingleFile = false,
	Actions = false,
	GlobalMap = "ParticleSystemPresets",
	ContainerClass = "ParticleSystemSubItem", -- can be ParticleBehavior or ParticleParam
	SubItemFilterClass = "BehaviorFilter",
	GedEditor = "GedParticleEditor",
	SingleGedEditorInstance = false,
	EditorMenubarName = false, 
	EditorMenubar = false,
}

if FirstLoad then
	ParticleSystemPreset_FXDetailThreshold = false
end

---
--- Returns a table of texture folder paths used by the ParticleSystemPreset.
---
--- @return table
function ParticleSystemPreset:GetTextureFolders()
	return {
		{"svnAssets/Source/Textures/Particles/"}
	}
end

---
--- Returns the base path for particle system textures.
---
--- @return string The base path for particle system textures.
function ParticleSystemPreset:GetTextureBasePath()
	return "svnAssets/Source/"
end

---
--- Returns the target path for particle system textures.
---
--- @return string The target path for particle system textures.
function ParticleSystemPreset:GetTextureTargetPath()
	return "Textures/Particles/"
end

---
--- Returns the target path for particle system textures.
---
--- @return string The target path for particle system textures.
function ParticleSystemPreset:GetTextureTargetGamePath()
	return "Textures/Particles"
end

---
--- Returns the dynamic parameters for the ParticleSystemPreset.
---
--- @return boolean|table The dynamic parameters for the ParticleSystemPreset, or false if none are defined.
function ParticleSystemPreset:DynamicParams()
	return self:EditorData().dynamic_params or false
end

---
--- Returns the refresh thread for the ParticleSystemPreset.
---
--- @return boolean|table The refresh thread for the ParticleSystemPreset, or false if none is defined.
function ParticleSystemPreset:RefreshThread()
	return self:EditorData().refresh_thread or false
end

---
--- Overrides the emitter functions for the ParticleSystemPreset.
---
--- This function is used to override the default emitter functions for the particle system preset. It allows customizing the behavior of the particle emitters.
---
--- @function ParticleSystemPreset:OverrideEmitterFuncs
--- @return nil
function ParticleSystemPreset:OverrideEmitterFuncs()
end

---
--- Opens the particle editor for the given ParticleSystemPreset object.
---
--- @param ged table The GED (Graphical Editor) object.
--- @param obj ParticleSystemPreset The ParticleSystemPreset object to open the editor for.
--- @param locked boolean Whether the preset should be locked in the editor.
---
--- @function GedOpOpenParticleEditor
--- @return nil
function GedOpOpenParticleEditor(ged, obj, locked)
	obj:OpenEditor(locked)
end

---
--- Opens the particle editor for the given ParticleSystemPreset object.
---
--- @param lock_preset boolean Whether the preset should be locked in the editor.
---
--- @function ParticleSystemPreset:OpenEditor
--- @return nil
function ParticleSystemPreset:OpenEditor(lock_preset)
	if not IsRealTimeThread() then
		CreateRealTimeThread(ParticleSystemPreset.OpenEditor, self, lock_preset)
		return
	end
	lock_preset = not not lock_preset

	local context = ParticleSystemPreset:EditorContext()
	context.lock_preset = lock_preset
	local ged = OpenPresetEditor("ParticleSystemPreset", context)
	ged:SetSelection("root", PresetGetPath(self))
end

---
--- Lists the particle system behaviors for the given ParticleSystemPreset object.
---
--- @param obj ParticleSystemPreset The ParticleSystemPreset object to list the behaviors for.
--- @param filter table A table of filters to apply to the behaviors.
--- @param format table A table of formatting options for the behavior names.
--- @param restrict_class string An optional class name to restrict the behaviors to.
---
--- @return table The list of particle system behaviors for the given ParticleSystemPreset object.
function GedListParticleSystemBehaviors(obj, filter, format, restrict_class)
	if not IsKindOf(obj, "ParticleSystemPreset") then
		return {}
	end
	
	local format = T{format}
	local objects, ids = {}, {}
	for i = 1, #obj do
		local item = obj[i]
		objects[#objects + 1] = type(item) == "string" and item or _InternalTranslate(format, item, false)
		ids[#ids + 1] = tostring(item)
	end
	
	-- Do filtering
	local filtered = {}
	if filter then
		for i = 1, #obj do
			local item = obj[i]
			-- filter by bins
			for bin, value in pairs(filter.bins) do
				if value and item:HasMember("bins") and not item.bins[bin] then
					filtered[i] = true
				end
			end
		end
	end
	objects.filtered = filtered
	objects.ids = ids
	return objects
end

if FirstLoad then
	l_streams_to_update = false
	g_ParticleLuaDefsLoaded = false
end

local load_lua_defs = Platform.developer and Platform.pc and IsFSUnpacked()

local particle_editors = {}
function OnMsg.GedOpened(ged_id)
	local gedApp = GedConnections[ged_id]
	if gedApp and gedApp.app_template == "GedParticleEditor" then
		hr.TrackParticleTimes = 1
		ParticleSystemPreset_FXDetailThreshold = hr.FXDetailThreshold
		
		if load_lua_defs and not g_ParticleLuaDefsLoaded then
			LoadLuaParticleSystemPresets()
			
			if Platform.developer then
				ParticleSystemPreset.TryUpdateKnownInvalidStreams(l_streams_to_update)
			end
		end
		
		particle_editors[ged_id] = true
	end
end

function OnMsg.GedClosing(ged_id)
	if particle_editors[ged_id] then
		hr.FXDetailThreshold = ParticleSystemPreset_FXDetailThreshold
		particle_editors[ged_id] = nil
	end
end

if FirstLoad then
	UIParticlesTestControl = false
	UIParticlesTestId = false
end

local function UpdateGedStatus()
	GedSetUiStatus("select_xcontrol", "Select UI control to attach this particle to.")
end

---
--- Spawns a UI particle effect on a selected UI control.
---
--- @param ged table The GED application object.
--- @param enabled boolean Whether to enable or disable the particle effect.
---
function GedTestUIParticle(ged, enabled)
	if UIParticlesTestControl and UIParticlesTestControl.window_state == "open" and UIParticlesTestControl:HasParticle(UIParticlesTestId) then
		UIParticlesTestControl:KillParSystem(UIParticlesTestId)
		UIParticlesTestControl = false
		UIParticlesTestId = false
		return
	end
	UIParticlesTestControl = false
	UIParticlesTestId = false

	local particle_sys = ged:ResolveObj("SelectedPreset")
	if not particle_sys then
		XRolloverMode(false)
		return
	end
	
	if particle_sys.testcode then
		particle_sys.testcode(particle_sys, ged, enabled)
		return
	end

	if not enabled then
		XRolloverMode(false)
		return
	end

	if not particle_sys.ui then
		ged:ShowMessage("Invalid selection", "Select a UI particle first!")
		XRolloverMode(false)
		return
	end

	GedSetUiStatus("select_xcontrol", "Select UI control to attach this particle to.")
	XRolloverMode(true, function(window, status)
		if window and window:IsKindOf("XControl") then
			XFlashWindow(window)
			if status == "done" then
				-- spawn particles
				UIParticlesTestControl = window
				UIParticlesTestId = window:AddParSystem(UIParticlesTestId, particle_sys.id, UIParticleInstance:new({
					lifetime = -1,
				}))
			end
		end
		if status == "done" or status == "cancel" then
			GedSetUiStatus("select_xcontrol")
		end
	end)
end

---
--- Sets the particle detail level and updates the particle system preview.
---
--- @param ged table The GED object.
--- @param detail_name string The name of the particle detail level to set.
---
function GedSetParticleEmitDetail(ged, detail_name)
	local levels = OptionsData.Options.Effects
	local idx = table.find(levels, "value", detail_name)
	assert(idx)

	EngineOptions.Effects = levels[idx].value
	Options.ApplyEngineOptions(EngineOptions)

	local selected_preset = ged:ResolveObj("SelectedPreset")
	if selected_preset and selected_preset:IsKindOf("ParticleSystemPreset") then
		if selected_preset.ui then
			if UIParticlesTestControl and UIParticlesTestControl:HasParticle(UIParticlesTestId) then
				UIParticlesTestControl:KillParSystem(UIParticlesTestId)
			end
		else
			selected_preset:ResetParSystemInstances()
		end
	end
	print(string.format("Particle detail level '%s' preview set.", levels[idx].value))

	local detail_level_names = {"Low", "Medium", "High", "Ultra"}
	for i = 1, 4 do
		ged:Send("rfnApp", "SetActionToggled", "Preview" .. detail_level_names[i], detail_level_names[i] == levels[idx].value)
	end
end

if FirstLoad then
	ParticleSystemPresetCommitThread = false
end
---
--- Commits the particle system preset by building the particle textures and fallbacks, and then opening the commit dialog in TortoiseProc.
---
--- This function is called to commit changes to the particle system preset. It performs the following steps:
---
--- 1. Builds the particle textures by executing the "Build TexturesParticles-win32" command in the project path.
--- 2. Builds the particle fallbacks by executing the "Build ParticlesSeparateFallbacks" command in the project path.
--- 3. Opens the commit dialog in TortoiseProc for the assets path.
---
--- If any of the steps fail, the function will assert an error message.
---
--- @return nil
function GedParticleSystemPresetCommit()
	ParticleSystemPresetCommitThread = IsValidThread(ParticleSystemPresetCommitThread) or CreateRealTimeThread(function()
		local assets_path = ConvertToOSPath("svnAssets/")
		local project_path = ConvertToOSPath("svnProject/")
		local err, exit_code = AsyncExec(string.format("cmd /c %s/Build TexturesParticles-win32", project_path))
		if err then 
			assert("Failed to build particle textures" and false)
			return
		end
		local err, exit_code = AsyncExec("cmd /c Build ParticlesSeparateFallbacks", project_path, true, true)
		if not err and exit_code == 0 then
			print("Fallbacks updated.")
		else
			print("Fallbacks failed to update", err, exit_code)
			assert("Failed to build particle fallbacks" and false)
			return
		end
		err, exit_code = AsyncExec(string.format("cmd /c TortoiseProc /command:commit /path:%s", assets_path))
		if err then assert("Failed to open commit dialog" and false) end
	end)
end

---
--- Returns a status text indicating whether particle system compression tasks are in progress.
---
--- If there is a valid thread for either the `UpdateTexturesListThread` or `ParticleSystemPresetCommitThread`, this function will return "Compress tasks in progress...". Otherwise, it will return an empty string.
---
--- @return string The status text indicating whether particle system compression tasks are in progress.
function ParticleSystemPreset:GetPresetStatusText()
	if IsValidThread(UpdateTexturesListThread) or IsValidThread(ParticleSystemPresetCommitThread) then
		return "Compress tasks in progress..."
	end
	return ""
end

---
--- Toggles a property on the given object and marks the object as modified.
---
--- @param obj table The object to toggle the property on.
--- @param prop string The name of the property to toggle.
--- @param id number The ID of the dynamic parameter to use for the toggle.
---
function ParticleSystemPreset:SwitchParam(obj, prop, id)
	obj:ToggleProperty(prop, self:DynamicParams())
	ObjModified(obj)
end

---
--- Binds a parameter to a dynamic parameter index.
---
--- @param idx number The index of the parameter to bind.
--- @param userdata number The index of the dynamic parameter to use.
--- @return number The size of the dynamic parameter.
function ParticleSystemPreset:BindParam(idx, userdata)
	local param = self[idx]
	local dp = { index = userdata, type = param.type, default_value = param.default_value }
		
	if param.type == "number" then
		dp.size = 1
	elseif param.type == "color" then
		dp.size = 1
	elseif param.type == "point" then
		dp.size = 3
	elseif param.type == "bool" then
		dp.size = 1
	end
	
	self:DynamicParams()[param.label] = dp
	
	return dp.size
end

---
--- Binds the particle parameters to dynamic parameters.
---
--- This function iterates through the particle system preset and binds each `ParticleParam` object to a dynamic parameter index.
--- The dynamic parameter index is used to access the corresponding value in the particle system's custom data.
--- If the number of parameters exceeds the available custom data values, a warning is printed.
---
--- @function ParticleSystemPreset:BindParams
--- @return nil
function ParticleSystemPreset:BindParams()
	local idx = 1 -- start at 1 because custom data [0] is the particle system creation time
	self:EditorData().dynamic_params = {}
	for i = 1, #self do
		if IsKindOf(self[i], "ParticleParam") then
			idx = idx + self:BindParam(i, idx)
			if idx > const.CustomDataCount - 1 then
				print(string.format("warning: parameter %s exceeded the available userdata values!", self[i].label))
			end
		end
	end
end

---
--- Enables dynamic toggles for all `ParticleBehavior` objects in the `ParticleSystemPreset`.
---
--- This function iterates through the particle system preset and enables the dynamic toggle for each `ParticleBehavior` object, passing the `DynamicParams` table as an argument.
---
--- @function ParticleSystemPreset:EnableDynamicToggles
--- @return nil
function ParticleSystemPreset:EnableDynamicToggles()
	for i = 1, #self do
		if self[i]:IsKindOf("ParticleBehavior") then
			self[i]:EnableDynamicToggle(self:DynamicParams())
		end
	end
end

---
--- Binds the particle parameters to dynamic parameters and enables dynamic toggles for all `ParticleBehavior` objects in the `ParticleSystemPreset`.
---
--- This function first calls `ParticleSystemPreset:BindParams()` to bind each `ParticleParam` object to a dynamic parameter index. It then calls `ParticleSystemPreset:EnableDynamicToggles()` to enable the dynamic toggle for each `ParticleBehavior` object, passing the `DynamicParams` table as an argument.
---
--- @function ParticleSystemPreset:BindParamsAndUpdateProperties
--- @return nil
function ParticleSystemPreset:BindParamsAndUpdateProperties()
	self:BindParams()
	self:EnableDynamicToggles()
end

function OnMsg.DataLoading()
	for _, folder in ipairs(ParticleDirectories()) do
		LoadingBlacklist[folder] = true
	end
end

---
--- Loads Lua-defined particle system presets.
---
--- This function loads particle system presets defined in Lua files located in the particle directories. It first clears the `LoadingBlacklist` for the particle directories, then loads the presets from each directory. After loading, it calls the `PostLoad()` function on each preset, and then reloads the particle systems in the engine, logging any errors. Finally, it sets the `g_ParticleLuaDefsLoaded` flag to indicate that the Lua particle system presets have been loaded.
---
--- @return boolean true if the Lua particle system presets were loaded successfully, false otherwise
function LoadLuaParticleSystemPresets()
	if g_ParticleLuaDefsLoaded then
		return g_ParticleLuaDefsLoaded
	end
	
	local start_time = GetPreciseTicks()

	for _, folder in ipairs(ParticleDirectories()) do
		LoadingBlacklist[folder] = false
		LoadPresetFolder(folder)
	end

	local old_load_lua_defs = load_lua_defs
	load_lua_defs = false
	local count = 0
	ForEachPreset("ParticleSystemPreset", function(preset)
		preset:PostLoad()
		count = count + 1
	end)
	load_lua_defs = old_load_lua_defs

	if Platform.developer then
		--print("Loaded", count, "particle lua defs in", GetPreciseTicks() - start_time, "ms");
	end

	ObjModified(Presets.ParticleSystemPreset)


	-- Replace bins with lua defs in the engine. Log which happened to be different (outdated bins) and in case we want to resave them later
	local streams_to_update = ParticlesReload(false, false)
	l_streams_to_update = l_streams_to_update or {}
	for _, parsys in ipairs(streams_to_update) do
		local err = ParticleSystemPresets[parsys]:TestStream()
		if err then
			GameTestsError("ParSys", parsys, "error: ", err)
			table.insert(l_streams_to_update, parsys)
		end
	end

	g_ParticleLuaDefsLoaded = true
	return g_ParticleLuaDefsLoaded
end

function OnMsg.DataLoaded()
	local failed_to_load = {}
	for _, folder in ipairs(ParticleDirectories()) do
		LoadStreamParticlesFromDir(folder, failed_to_load)
	end
	l_streams_to_update = failed_to_load


	if load_lua_defs then
		LoadLuaParticleSystemPresets()
	end
end

--- Called when a new ParticleSystemPreset is created in the editor.
---
--- If `load_lua_defs` is true, this will reload the particle system presets.
--- It also clears the last save path for the preset and updates the object palette in the editor.
---
--- @param parent table The parent object of the new preset.
--- @param ged table The game editor instance.
--- @param is_paste boolean Whether the preset was pasted from another location.
function ParticleSystemPreset:OnEditorNew(parent, ged, is_paste)
	if load_lua_defs then
		ParticlesReload(self.id)
	end
	g_PresetLastSavePaths[self] = nil
	if Platform.editor then
		XEditorUpdateObjectPalette()
	end
end

---
--- Called when the ParticleSystemPreset is selected in the editor.
---
--- If the preset is now selected, it refreshes the behavior usage indicators, binds the parameters and updates the properties, and sets the UI particle flag in the editor.
--- If the preset is no longer selected, it resets the particle system instances.
---
--- @param now_selected boolean Whether the preset is now selected.
--- @param ged table The game editor instance.
function ParticleSystemPreset:OnEditorSelect(now_selected, ged)
	if now_selected then
		self:RefreshBehaviorUsageIndicators()
		self:BindParamsAndUpdateProperties()
		ged:Send("rfnApp", "SetIsUIParticle", self.ui)
	else
		self:ResetParSystemInstances()
	end
end

---
--- Updates the binary streams for invalid particle systems.
---
--- This function is responsible for updating the binary streams for particle systems that have become invalid, such as when particle system assets are modified or removed. It ensures that the particle system data is properly updated and saved.
---
--- @function BinAssetsUpdateInvalidParticleStreams
--- @return nil
function BinAssetsUpdateInvalidParticleStreams()
	ParticleUpdateBinaryStreams()
end


---
--- Attempts to update known invalid particle system binary streams.
---
--- This function is responsible for updating the binary streams for particle systems that have become invalid, such as when particle system assets are modified or removed. It ensures that the particle system data is properly updated and saved.
---
--- @param l_streams_to_update table A table of particle system binary streams that need to be updated.
--- @return nil
function ParticleSystemPreset.TryUpdateKnownInvalidStreams(l_streams_to_update)
	if not l_streams_to_update or #l_streams_to_update == 0 then
		return
	end
	local streams_to_update = table.copy(l_streams_to_update)
	table.clear(l_streams_to_update)
	CreateRealTimeThread(function()
		local changed_outlines = ParticleUpdateOutlines()
		if #changed_outlines > 0 then
			print("Saving", #changed_outlines, "particles with modified outlines")
			for i=1,#changed_outlines do
				SaveParticleSystem(changed_outlines[i])
			end
			QueueCompressParticleTextures()
		end
		if #streams_to_update > 0 then
			ParticleNameListSaveToStream(streams_to_update)
		end
		ParticleUpdateBinaryStreams("create_missing_only")
	end)
end

---
--- Refreshes the behavior usage indicators for the particle system.
---
--- This function is responsible for updating the visual indicators that show which particle behaviors are active or disabled based on the enabled particle emitters. It iterates through the particle behaviors and checks which emitters are using them, updating the `active` flag and generating a formatted label string to display the status.
---
--- @param do_now boolean (optional) If true, the refresh is performed immediately instead of being scheduled in a separate thread.
--- @return nil
function ParticleSystemPreset:RefreshBehaviorUsageIndicators(do_now)
	local editor_data = self:EditorData()
	local refresh_func = function(self)
		-- Search the behaviors to identify those with disabled emitters.
		-- Scheduled in a thread to avoid executing simultaneous refresh requests.
		for i = 1, #self do
			local behavior = self[i]
			if behavior:IsKindOf("ParticleBehavior") and not behavior:IsKindOf("ParticleEmitter") then
				local behavior_bins = behavior.bins
				local active_emitters = 0
				for j = 1, #self do
					local emitter = self[j]
					if emitter:IsKindOf("ParticleEmitter") and emitter.enabled then
						local emitter_bins = emitter.bins
						for bin, value in pairs(emitter_bins) do
							if value and behavior_bins[bin] then
								active_emitters = active_emitters + 1
							end
						end
					end
				end
				local new_active = active_emitters > 0
				if new_active ~= behavior.active then
					behavior.active = new_active
					ObjModified(self)
				end
				
				local flags = ParticlesGetBehaviorFlags(self.id, i - 1)
				if flags then
					local str = ""
					flags["emitter"] = nil
					for name, active in sorted_pairs(flags) do
						if GetDarkModeSetting() then active = not active end
						local color = active and RGB(74, 74, 74) or RGB(192, 192, 192)
						local r,g,b = GetRGB(color)
						str = string.format("%s<color %s %s %s>%s</color>", str, r,g,b, string.sub(name, 1, 1))
					end
					behavior.flags_label = str
				end
			end
		end
		editor_data.refresh_thread = nil
	end
	
	local refresh_thread = self:RefreshThread()
	if do_now and not refresh_thread then
		refresh_func(self)
	else
		editor_data.refresh_thread = refresh_thread or CreateRealTimeThread(refresh_func, self)
	end
end

---
--- Called after the ParticleSystemPreset object is loaded.
--- Performs the following actions:
--- - Calls the `Preset.PostLoad()` function
--- - If in developer mode, checks the integrity of the particle system
--- - Binds the parameters of the particle system
--- - If `load_lua_defs` is true, reloads the particle system
---
--- @param self ParticleSystemPreset The ParticleSystemPreset object
---
function ParticleSystemPreset:PostLoad()
	Preset.PostLoad(self)
	
	if Platform.developer then self:CheckIntegrity() end
	self:BindParams()
	if load_lua_defs then ParticlesReload(self.id) end
end

---
--- Checks the integrity of the particle system by iterating through the table and removing any `nil` elements.
--- If a `nil` element is found, an assertion is raised with the name of the particle system and the index of the `nil` element.
---
--- @param self ParticleSystemPreset The ParticleSystemPreset object
---
function ParticleSystemPreset:CheckIntegrity()
	local count = table.maxn(self)
	for i = count, 1, -1 do
		if not rawget(self, i) then
			assert(false, "Particle system '" .. self.name .. "' initialization failed at: " .. tostring(i))
			self[i] = false
			table.remove(self, i)
		end
	end
end

local function KillParticlesWithName(name)
	if UIParticlesTestControl and UIParticlesTestControl:GetParticleName(UIParticlesTestId) == name then
		UIParticlesTestControl = false
		UIParticlesTestId = false
	end

	local xcontrols = GetChildrenOfKind(terminal.desktop, "XControl")
	for _, control in ipairs(xcontrols) do
		control:KillParticlesWithName(name)
	end
end

function OnMsg.GedPropertyEdited(ged_id, object, prop_id, old_value)
	if not GedConnections[ged_id] then return end

	local parent = GetParentTableOfKindNoCheck(object, "ParticleSystemPreset")
	if object:IsKindOf("ParticleParam") and parent then
		parent:BindParamsAndUpdateProperties()
		g_DynamicParamsDefs = {} -- invalidate the cached params
		ParticlesReload(parent:GetId())
	end
	if object:IsKindOf("ParticleSystemPreset") and prop_id == "Id" then
		KillParticlesWithName(old_value)
		ParticlesReload()
		ObjModified(GedConnections[ged_id]:ResolveObj("root"))
		if Platform.editor then
			XEditorUpdateObjectPalette()
		end
	elseif (object:IsKindOf("ParticleBehavior") or object:IsKindOf("ParticleSystemPreset")) and parent then
		parent:RefreshBehaviorUsageIndicators()
		if object:IsKindOf("ParticleEmitter") and object:IsOutlineProp(prop_id) then
			object:GenerateOutlines("forced")
		end
		ParticlesReload(parent:GetId())
		g_DynamicParamsDefs = {} -- invalidate the cached params
	end
end

---
--- Handles editor property changes for a ParticleSystemPreset object.
---
--- @param prop_id string The ID of the property that was edited.
--- @param old_value any The previous value of the property.
--- @param ged table The Ged (Graphical Editor) object associated with the property change.
---
function ParticleSystemPreset:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "ui" then
		for _, behaviour in ipairs(self) do
			if IsKindOf(behaviour, "ParticleEmitter") then
				behaviour:Setui(self.ui)
			end
		end
	end
	ParticlesReload(self:GetId())
	self:RefreshBehaviorUsageIndicators()
	
	if prop_id == "NewBehavior" then
		ParticleSystemPreset.ActionAddBehavior(ged:ResolveObj("root"), self, prop_id, ged)
	end

	Preset.OnEditorSetProperty(self, prop_id, old_value, ged)
end

---
--- Resets all ParSystem instances that are using this ParticleSystemPreset.
---
--- This function iterates through all ParSystem objects in the "map" and checks if their
--- ParticlesName matches the ID of this ParticleSystemPreset. If so, it resets the time
--- and flags of the ParSystem and destroys its render object.
---
--- @param self ParticleSystemPreset The ParticleSystemPreset instance.
---
function ParticleSystemPreset:ResetParSystemInstances()
	MapForEach("map", "ParSystem",
		function(x)
			if x:GetParticlesName() == self.id then
				x:SetParticlesName(self.id) -- resets time and flags in GO
				x:DestroyRenderObj()
			end
		end)
end
---
--- Resets all ParSystem instances in the "map" by setting their ParticlesName and destroying their render objects.
---
--- This function iterates through all ParSystem objects in the "map" and resets the time and flags of each ParSystem
--- by setting its ParticlesName. It then destroys the render object of each ParSystem.
---
--- @param self any The calling object (not used).
---
function GedResetAllParticleSystemInstances()
end

function GedResetAllParticleSystemInstances()
	MapForEach("map", "ParSystem", function(obj)
		obj:SetParticlesName(obj:GetParticlesName())
		obj:DestroyRenderObj()
	end)
end

---
--- Saves the ParticleSystemPreset to a binary stream file.
---
--- This function saves the ParticleSystemPreset to a binary stream file with the specified name. If no name is provided, it uses the default binary file name based on the ParticleSystemPreset's ID.
---
--- The function first reloads the ParticleSystemPreset, then saves it to the binary stream file. If an error occurs during the save process, the error message is stored in the ParticleSystemPreset's editor data. The function returns the binary file name on success, or false and the error message on failure.
---
--- If the `skip_adding_to_svn` parameter is false (the default), the function also adds the binary file to the SVN repository.
---
--- @param self ParticleSystemPreset The ParticleSystemPreset instance.
--- @param bin_name string The name of the binary stream file to save to. If not provided, the default binary file name is used.
--- @param skip_adding_to_svn boolean If true, the binary file is not added to the SVN repository.
--- @return string|boolean The binary file name on success, or false and the error message on failure.
---
function ParticleSystemPreset:SaveToStream(bin_name, skip_adding_to_svn)
	bin_name = bin_name or self:GetBinFileName()
	local id = self:GetId()
	if bin_name ~= "" then
		ParticlesReload(self:GetId(), false)
		local count, err = ParticlesSaveToStream(bin_name, id, true)
		self:EditorData().stream_error = err
		if err then
			printf("\"%s\" while trying to persist \"%s\" in \"%s\"", err, id, bin_name)
			return false, err
		end
		if not skip_adding_to_svn then
			SVNAddFile(bin_name)
		end
	end
	return bin_name
end

---
--- Deletes the binary stream file associated with the ParticleSystemPreset.
---
--- This function deletes the binary stream file associated with the ParticleSystemPreset. If no file name is provided, it uses the default binary file name based on the ParticleSystemPreset's ID.
---
--- @param self ParticleSystemPreset The ParticleSystemPreset instance.
--- @param bin_name string The name of the binary stream file to delete. If not provided, the default binary file name is used.
---
function ParticleSystemPreset:DeleteStream(bin_name)
	bin_name = bin_name or self:GetBinFileName()
	if bin_name ~= "" then
		SVNDeleteFile(bin_name)
	end
end

---
--- Gets the binary file name for the ParticleSystemPreset.
---
--- This function returns the binary file name for the ParticleSystemPreset. The binary file name is generated by taking the save path of the ParticleSystemPreset and replacing the ".lua" extension with ".bin".
---
--- @param self ParticleSystemPreset The ParticleSystemPreset instance.
--- @param id string The ID of the ParticleSystemPreset (optional).
--- @return string The binary file name.
---
function ParticleSystemPreset:GetBinFileName(id)
	local path = self:GetSavePath()
	if not path or path == "" then return "" end
	return path:gsub(".lua$", ".bin")
end

---
--- Tests the binary stream file associated with the ParticleSystemPreset.
---
--- This function tests the binary stream file associated with the ParticleSystemPreset. It retrieves the binary file name from the ParticleSystemPreset and passes it to the `ParticlesTestStream` function along with the ParticleSystemPreset's ID. The result of the test is stored in the ParticleSystemPreset's editor data.
---
--- @param self ParticleSystemPreset The ParticleSystemPreset instance.
--- @return string|nil The error message if the test failed, or nil if the test succeeded.
---
function ParticleSystemPreset:TestStream()
	local binPath = self:GetBinFileName()
	if binPath then
		local id = self.id
		local err = ParticlesTestStream(binPath, id)
		self:EditorData().stream_error = err
		if err then
			return err
		end
	end
end

---
--- Gets the error message for the ParticleSystemPreset.
---
--- This function checks the ParticleSystemPreset for various errors and returns an appropriate error message. It checks for the following errors:
--- - Too many particle behaviors (more than 55)
--- - No particle behaviors
--- - Particle emitters with softness > 0 in UI particles
--- - Persist error from the binary stream file
---
--- @param self ParticleSystemPreset The ParticleSystemPreset instance.
--- @return string|nil The error message if an error is found, or nil if no errors are found.
---
function ParticleSystemPreset:GetError()
	if #self > 55 then
		return "Too many particle behaviors."
	elseif #self < 1 then
		return "There are no particle behaviors. Please add some."
	end
	if self.ui then
		-- TODO: Figure out how this code can go in the ParticleEmitter
		for _, behavior in ipairs(self) do
			if IsKindOf(behavior, "ParticleEmitter") then
				if behavior.softness ~= 0 and behavior.enabled then
					return "A particle emitter with softness > 0 found. They are not supported in UI particles."
				end
			end
		end
	end
	local editor_data = self:EditorData()
	if editor_data.stream_error then
		return "Persist error:" .. editor_data.stream_error
	end
end
 
ParticleSystemPreset.ReloadWaitThread = false 


---
--- Adds the source textures used by the particle emitters in the ParticleSystemPreset to the SVN.
---
--- This function iterates through the particle behaviors in the ParticleSystemPreset and collects the
--- texture and normal map file paths used by the ParticleEmitter behaviors. It then adds these
--- files to the SVN using the SVNAddFile function.
---
--- @param self ParticleSystemPreset The ParticleSystemPreset instance.
---
function ParticleSystemPreset:AddSourceTexturesToSVN()
	local textures = {}
	for i = 1, #self do
		local behavior = self[i]
		if IsKindOf(behavior, "ParticleEmitter") then
			if behavior.texture ~= "" then textures[#textures + 1] = "svnAssets/Source/" .. behavior.texture end
			if behavior.normalmap ~= "" then textures[#textures + 1] = "svnAssets/Source/" .. behavior.normalmap end
		end
	end
	if #textures > 0 then
		SVNAddFile(textures)
	end
end

---
--- Called before the ParticleSystemPreset is saved.
---
--- This function performs the following tasks:
--- - Generates outlines for any ParticleEmitter behaviors in the preset.
--- - Binds parameters and updates properties for the preset.
--- - Removes any no longer used binary stream files.
--- - Queues compression of particle textures.
--- - Adds any source textures used by the preset to the SVN.
--- - Saves the preset to a stream.
--- - Prints the number of particle behaviors saved and marks the preset as modified.
---
--- @param self ParticleSystemPreset The ParticleSystemPreset instance.
--- @param user_requested boolean Whether the save was user-requested.
---
function ParticleSystemPreset:OnPreSave(user_requested)
	local file_exists = io.exists(self:GetBinFileName())
	local last_save_path = g_PresetLastSavePaths[self]
	
	for i = 1, #self do
		local behavior = self[i]
		if IsKindOf(behavior, "ParticleEmitter") then
			behavior:GenerateOutlines()
		end
	end

	self:BindParamsAndUpdateProperties() -- generates the "fake" properties for dynamic params
	
	-- remove no longer used bin files.
	if last_save_path and last_save_path ~= self:GetSavePath() then
		local old_bin_path = (last_save_path or ""):gsub(".lua", ".bin")
		if old_bin_path ~= "" then
			self:DeleteStream(old_bin_path)
		end
	end

	QueueCompressParticleTextures()
	self:AddSourceTexturesToSVN()
	self:SaveToStream(false, not "dont_add_to_svn")
	
	print(#self, "particle behaviors in", self:GetId(), "saved")
	ObjModified(self)
end 

---
--- Called when the ParticleSystemPreset is deleted from the editor.
---
--- This function deletes the binary stream file associated with the ParticleSystemPreset.
---
--- @param self ParticleSystemPreset The ParticleSystemPreset instance.
--- @param ... Any additional arguments passed to the delete function.
---
function ParticleSystemPreset:OnEditorDelete(...)
	self:DeleteStream()
end

---
--- Returns a combo box list of all available particle behavior types.
---
--- The list is sorted alphabetically by the editor name of each particle behavior type.
--- The first item in the list is an empty entry.
---
--- @return table A table of combo box entries, where each entry is a table with `value` and `text` fields.
---
function GetParticleBehaviorsCombo()
	local list = {}
	ClassDescendants("ParticleBehavior", function(name, class_def, list)
		if rawget(class_def, "EditorName") then
			list[#list + 1] = {value = name, text = class_def.EditorName}
		end
	end, list)
	table.sortby_field(list, "text")
	table.insert(list, 1, {value = "", text = ""})
	return list
end

---
--- Generates outlines for all particle emitters in the particle system list.
---
--- This function clears the outlines cache, then iterates through all particle systems and their behaviors.
--- For each particle emitter behavior, it calls `GenerateOutlines()` to generate the outlines.
--- The function returns a sorted list of particle system IDs that had their outlines updated.
---
--- @return table A sorted list of particle system IDs that had their outlines updated.
---
function ParticleUpdateOutlines()
	local updated = {}
	ClearOutlinesCache()
	local list = GetParticleSystemList()
	for i = 1,#list do
		local parsys = list[i]
		for j = 1, #parsys do
			local behavior = parsys[j]
			if IsKindOf(behavior, "ParticleEmitter") then
				local success, generated = behavior:GenerateOutlines("update")
				if success then
					updated[parsys] = true
				end
				if generated and CanYield() then
					Sleep(10)
				end
			end
		end
	end
	updated = table.keys(updated)
	table.sort(updated, function(a, b) return CmpLower(a.id, b.id) end)
	return updated
end

---
--- Updates the binary streams for particle systems.
---
--- This function checks the existing binary streams in the particle directories, and compares them to the
--- particle systems in the game. It creates any missing binary streams, and deletes any binary streams
--- that are no longer needed.
---
--- If `create_missing_only` is true, the function will only create binary streams for particle systems
--- that don't have an existing binary stream. If false, it will create binary streams for all particle
--- systems.
---
--- @param create_missing_only boolean If true, only create missing binary streams, otherwise create streams for all particle systems.
--- @return nil
---
function ParticleUpdateBinaryStreams(create_missing_only)
	if not g_ParticleLuaDefsLoaded then
		print("ParticleUpdateBinaryStreams: Particle defs not loaded.")
		return
	end

	local existing = {}
	
	for _, folder in ipairs(ParticleDirectories()) do
		local err, files = AsyncListFiles(folder, "*.bin")
		if err then
			print("Particle files listing failed:", err)
		else
			for i = 1, #files do
				existing[files[i]] = true
			end
		end
	end
	
	local particle_systems = GetParticleSystemList()
	
	local streams = {}
	local to_create = {}
	for i = 1, #particle_systems do
		local parsys = particle_systems[i]
		local stream = parsys:GetBinFileName()
		streams[stream] = true
		if not create_missing_only or not existing[stream] then
			to_create[#to_create + 1] = parsys
		end
	end
	
	if #to_create > 0 then
		local created = {}
		print("Creating", #to_create, "particle streams...")
		for i = 1, #to_create do
			local parsys = to_create[i]
			local stream = parsys:GetBinFileName()
			local success, err = parsys:SaveToStream(stream, "skip adding to svn")
			if success then
				created[#created + 1] = stream
			end
		end
		SVNAddFile(created)
		print("Created", #created, "/", #to_create, "particle streams.")
	end
	--[[
	if #updated > 0 then
		print(#updated, "particle stream(s) saved:")
		for i=1,#updated do
			print("\t", i, updated[i])
		end
	end
	--]]
	
	local to_delete = {}
	for stream in pairs(existing) do
		if not streams[stream] then
			to_delete[#to_delete + 1] = stream
		end
	end
	if #to_delete > 0 then
		print("Deleting", #to_delete, "particle streams...")
		local result, err = SVNDeleteFile(to_delete)
		if not result then
			err = err or ""
			printf("Failed to delete binary streams! %s", tostring(err))
		end 
	end
end

--- Returns the name of the ParticleSystemPreset.
---
--- @return string The name of the ParticleSystemPreset.
function ParticleSystemPreset:GetName()
	return self.id
end


--- Loads particle systems from a directory of binary files.
---
--- @param dir string The directory containing the particle system binary files.
--- @param failed_to_load table A table to store the names of particle systems that failed to load.
function LoadStreamParticlesFromDir(dir, failed_to_load)
	local err, files = AsyncListFiles(dir, "*.bin")
	if err then
		print("Particle files listing failed:", err, " directory ", dir)
	else
		local start = GetPreciseTicks()
		local success = 0
		local failed_due_to_ver = 0
		for i = 1, #files do
			local err, count = ParticlesLoadFromStream(files[i])
			if not err and count ~= 0 then
				success = success + 1
			elseif err == "persist_version" then
				failed_due_to_ver = failed_due_to_ver + 1

				local _, parsys, __ = SplitPath(files[i])
				table.insert(failed_to_load, parsys)
			else
				print("Particles", files[i], "loading failed!", err)
				local _, parsys, __ = SplitPath(files[i])
				table.insert(failed_to_load, parsys)
			end
		end
		DebugPrint(print_format(success, "/", #files, "particle streams loaded in", GetPreciseTicks() - start, "ms.\n"))
		if failed_due_to_ver > 0 then
			print("Particle streams could not be loaded. Using", failed_due_to_ver, "lua descriptions instead. Reason: Persist version mismatch.")
		end
	end
end

--- Saves a list of particle system presets to a stream.
---
--- @param streams_to_update table A table of particle system preset IDs to update.
function ParticleNameListSaveToStream(streams_to_update)
	local updated = {}
	print("Updating", #streams_to_update, "particle streams...")
	for i = 1, #streams_to_update do
		local parsys = GetParticleSystem(streams_to_update[i])
		if parsys then
			local success, err = parsys:SaveToStream()
			if success then
				updated[#updated + 1] = parsys
			end
		end
	end
	print("Updated", #updated, "/", #streams_to_update, "particle streams.")
end

--- Checks the particle textures used in the game and returns information about them.
---
--- @return table The table of particle texture references, with the texture name as the key and the particle system ID as the value.
--- @return table The table of particle textures that are not referenced by any particle system.
--- @return table The table of particle textures that have the wrong casing (e.g. "Texture.png" instead of "texture.png").
--- @return table The table of particle textures that are missing from the packed textures directory.
function CheckParticleTextures()
	local source_path = "svnAssets/Source/Textures/Particles/"
	local packed_path = "Textures/Particles/"
	if not io.exists(source_path) then
		print("You need to checkout source textures for particles.")
		return {}
	end
	local err, rel_paths = AsyncListFiles(source_path, "*", "relative, recursive")
	local packed_paths = {}
	table.map(rel_paths, function(rel_path) packed_paths[#packed_paths+1] = packed_path .. rel_path end)
	
	local refs = {}
	local refs_lower = {}
	local instances = GetParticleSystemList()
	for i=1, #instances do
		local parsystem = instances[i]
		for b=1, #parsystem do
			local behavior = parsystem[b]
			if IsKindOf(behavior, "ParticleEmitter") then
				refs[behavior.texture] = parsystem:GetId()
				refs[behavior.normalmap] = parsystem:GetId()
				refs_lower[string.lower(behavior.texture)] = parsystem:GetId()
				refs_lower[string.lower(behavior.normalmap)] = parsystem:GetId()
			end
		end
	end	
	refs[""] = nil
	
	local unref = {}
	local present = {}
	local present_lower = {}
	local missing = {}
	local wrong_casing = {}
	
	for i=1, #packed_paths do
		local texture = packed_paths[i]
		local texture_lower = string.lower(texture)
		present[texture] = true
		present_lower[texture_lower] = true
		if not refs[texture] then
			if refs_lower[texture_lower] then
				wrong_casing[#wrong_casing+1] = texture
			else
				unref[#unref+1] = texture
			end
		end
	end
	for texture, parsys in pairs(refs) do
		if not present_lower[string.lower(texture)] then
			missing[texture] = parsys
		end
	end
	return refs, unref, wrong_casing, missing
end

if FirstLoad then
	UpdateTexturesListThread = false
end
---
--- Queues the compression of particle textures in the game.
---
--- This function is responsible for the following tasks:
--- - Checks the particle textures used in the game and identifies any missing or incorrectly cased textures.
--- - Updates a file named "Textures.txt" with the correct paths for the particle textures.
--- - Compresses the particle textures using the "Build TexturesParticles" command.
--- - Updates the particle fallbacks using the "Build ParticlesSeparateFallbacks" command.
---
--- The function is executed in a real-time thread, which allows it to run asynchronously without blocking the main game loop.
---
--- @function QueueCompressParticleTextures
--- @return nil
function QueueCompressParticleTextures()
	if Platform.ged then return end
	if UpdateTexturesListThread then
		DeleteThread(UpdateTexturesListThread)
		UpdateTexturesListThread = false
	end
	UpdateTexturesListThread = CreateRealTimeThread(function()
		Sleep(300)
		local filepath = "svnProject/Data/ParticleSystemPreset/Textures.txt"
		local refs, _, wrong_casing, missing = CheckParticleTextures()
		local idx = {}
		local full_os_path = ConvertToOSPath("svnAssets/Source/"):gsub("\\", "/")
		local os_path = string.match(full_os_path, "/([^/]+/Source/)$")
		for texture, _ in sorted_pairs(refs) do
			if not missing[texture] and not table.find(wrong_casing, texture) then
				idx[#idx+1] = texture .. "=" .. os_path .. texture
			end
		end	
		AsyncStringToFile(filepath, table.concat(idx, "\r\n"))
		print("Textures.txt updated")

		local dir = ConvertToOSPath("svnProject/")
		local err, exit_code, other = AsyncExec("cmd /c Build TexturesParticles", dir, true, true)
		if err or exit_code ~= 0 then
			print("Particles failed to compress", err, exit_code, other)
		end

		local err, exit_code = AsyncExec("cmd /c Build ParticlesSeparateFallbacks", dir, true, true)
		if not err and exit_code == 0 then
			print("Fallbacks updated.")
		else
			print("Fallbacks failed to update", err, exit_code)
		end

		UpdateTexturesListThread = false
	end)
end



DefineClass.ParticleSystem = {
	__parents = {"PropertyObject"},
	StoreAsTable = false,
	properties = {{id = 'name', editor = 'text', default = '', },},
	
	simul_fps = 30,
	speed_up = 1000,
	presim_time = 0,
	max_initial_catchup_time = 2000,
	rand_start_time = 0,
	distance_bias = 0,
	particles_scale_with_object = false,
	game_time_animated = false,
	vanish = false,
}

function OnMsg.ClassesGenerate()
	table.iappend(ParticleSystem.properties, ParticleSystemPreset.properties)
end

---
--- Constructs a new `ParticleSystem` object from a Lua table.
---
--- @param ... any Arguments passed to the `PropertyObject.__fromluacode` function.
--- @return ParticleSystem A new `ParticleSystem` object.
function ParticleSystem:__fromluacode(...)
	local obj = PropertyObject.__fromluacode(self, ...)
	local converted = ParticleSystemPreset:new(obj)
	converted:SetId(obj.name)
	converted:SetGroup("Default")
	return converted
end