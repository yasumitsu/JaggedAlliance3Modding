--- Defines the global namespace for options-related functions.
Options = {}

--- Defines the configuration data for options, including per-project options and video presets.
OptionsData = {
    --- The options configuration per-project.
    Options = {}
}

--- Stores the video presets data.
OptionsData.VideoPresetsData = {}

--- Initializes options-related data structures on first load.
if FirstLoad then
    --- Stores the preset video options.
    PresetVideoOptions = {}

    --- Namespace for engine option fixups.
    EngineOptionFixups = {}

    --- Namespace for account option fixups.
    AccountOptionFixups = {}
end


---
--- Returns a list of available graphics APIs.
---
--- If `config.OfficialPCGraphicsApis` is set and the current platform is PC, and not in developer mode, and not inside HG, the returned list will be filtered to only include the official PC graphics APIs.
---
--- @return table The list of available graphics APIs.
---
local function GetAvailableGraphicsApis()
	local available = GetSupportedGraphicsApis()
	if config.OfficialPCGraphicsApis and Platform.pc and not Platform.developer and not insideHG() then
		available = table.intersection(available, config.OfficialPCGraphicsApis)
	end
	return available
end

---
--- Returns the valid video mode for the given display index and resolution.
---
--- If valid video modes are available for the given display index and resolution, the function will return the width and height of the best mode (sorted by height, then width).
--- If no valid video modes are available, the function will return the current display mode's width and height.
---
--- @param displayIndex The index of the display to get the video modes for.
--- @param width The desired width of the video mode.
--- @param height The desired height of the video mode.
--- @return number The valid width of the video mode.
--- @return number The valid height of the video mode.
---
function GetValidVideoMode(displayIndex, width, height)
	local modes = GetVideoModes(displayIndex, width, height)
	if #modes > 0 then
		table.sort(modes, function(a, b)
			if a.Height ~= b.Height then
				return a.Height < b.Height
			end
			return a.Width < b.Width
		end)
		local best = modes[1]
		return best.Width, best.Height
	end
	local current = GetDisplayMode(displayIndex)
	return current.displayWidth, current.displayHeight
end

---
--- Initializes the engine options and sets up the graphics API and adapter.
---
--- This function is called during startup to initialize the engine options. It performs the following tasks:
---
--- 1. Sets the display index if it hasn't been set already.
--- 2. Checks if the requested graphics API is supported, and if not, uses the default graphics API.
--- 3. Selects the appropriate graphics adapter based on the chosen graphics API.
--- 4. Autodetects the engine display options if the graphics adapter has changed.
--- 5. Applies any developer-specified display options (fullscreen mode, resolution, etc.).
--- 6. Updates the config with the final display options.
---
--- @return nil
---
function Options.Startup()
	if config.DisableOptions then return end

	local options = EngineOptions
	if not options.DisplayIndex then
		options.DisplayIndex = config.DisplayIndex
	end

	if config.GraphicsApi ~= "" and not table.find(GetSupportedGraphicsApis(), config.GraphicsApi) then
		config.GraphicsApi = "" -- Requested API is not supported, use options' value or default.
	end
	if config.GraphicsApi == "" then -- Do not override, if manually picked.
		local availableGraphicsApis = GetAvailableGraphicsApis()
		config.GraphicsApi = type(options.GraphicsApi) == "string" and options.GraphicsApi or ""
		if not config.GraphicsApi or not table.find(availableGraphicsApis, config.GraphicsApi) then
			config.GraphicsApi = GetDefaultGraphicsApi()
		end
		if not table.find(availableGraphicsApis, config.GraphicsApi) and #availableGraphicsApis > 0 then
			config.GraphicsApi = availableGraphicsApis[1]
		end
	end
	options.GraphicsApi = config.GraphicsApi
	 
	local prevAdapter = options.GraphicsAdapter or { vendorId = 0, deviceId = 0 }
	config.GraphicsAdapterIndex = GetRenderDeviceAdapterIndex(config.GraphicsApi, prevAdapter)
	options.GraphicsAdapter = GetRenderDeviceAdapterData(config.GraphicsApi, config.GraphicsAdapterIndex)
	options.GraphicsAdapterIndex = config.GraphicsAdapterIndex
	if not options.GraphicsAdapter or prevAdapter.vendorId ~= options.GraphicsAdapter.vendorId or prevAdapter.deviceId ~= options.GraphicsAdapter.deviceId then
		Options.Autodetect(options)		
		if Platform.developer and config.Width ~= 0 then
			-- Set engine display options using the values in the config
			options.FullscreenMode = config.FullscreenMode
			options.DisplayIndex = config.DisplayIndex
			
			-- Don't override Resolution if it was already set in DefaultEngineOptions
			if not IsPoint(options.Resolution) then
				options.Resolution = point(config.Width, config.Height)
			end
		end
		SaveEngineOptions()
	end
	
	if options.GraphicsAdapter then
		local gpu = string.lower(options.GraphicsAdapter.name)
		if Platform.pc and (options.GraphicsAdapter.vendorId == const.VendorIds.AMD or string.find(gpu, "amd") or string.find(gpu, "radeon")) then
			hr.D3D12PresentWaitOnAcquire = 1
			hr.SwapchainBuffers = 3
			hr.SSRFullTile8x8 = 1
		end
	end

	-- Update the config display options using the engine options values
	config.DisplayIndex = options.DisplayIndex
	config.FullscreenMode = options.FullscreenMode or 0
	
	if IsPoint(options.Resolution) then
		if options.FullscreenMode and not Platform.console then
			options.Resolution = point(GetValidVideoMode(options.DisplayIndex, options.Resolution:xy()))
		end
		config.Width, config.Height = options.Resolution:xy()
	elseif not config.Width or not config.Height then
		config.Width, config.Height = 0, 0
	end
	
	if options.Vsync ~= nil then
		config.Vsync = options.Vsync
	else
		config.Vsync = true
	end
end

--[[
Option Fixups 

Option fixups can be used to force change option values for all users. They work similarly to 
savegame fixups but hey are separated into two namespaces: EngineOptionFixups and 
AccountOptionFixups. As the names suggest one is for EngineOptions options and the other is 
for AccountOptions.

The fixup function will receive the corresponding table with options as the first parameter.
This is EngineOptions for engine option fixups or AccountStorage.Options for account option 
fixups. The second parameter is the last lua revision where a fixup was applied.

Fixup examples:

function EngineOptionFixups.SMAAAntialiasing(engine_options, last_applied_fixup_revision)
	engine_options.Antialiasing = "SMAA"
end

function AccountOptionFixups.Autosave(account_options, last_applied_fixup_revision)
	account_options.Autosave = true
end
--]]

-- Engine option fixups
-- Executed after the first call to Options.Startup() and before InitRenderEngine()
---
--- Applies any pending engine option fixups to the EngineOptions table.
---
--- Engine option fixups can be used to force changes to engine option values for all users.
--- They work similarly to savegame fixups, but are separated into two namespaces:
--- EngineOptionFixups and AccountOptionFixups.
---
--- This function iterates through the EngineOptionFixups table, calling any functions
--- that have not yet been applied. It then saves the updated EngineOptions and prints
--- a debug message indicating which fixups were applied.
---
--- @return number The number of fixups that were applied.
function Options.FixupEngineOptions()
	EngineOptions.fixups_meta = EngineOptions.fixups_meta or GetDefaultOptionFixupMeta()
	local meta = EngineOptions.fixups_meta
	meta.AppliedOptionFixups = meta.AppliedOptionFixups or {}
	local count, applied = 0, {}

	for fixup, func in sorted_pairs(EngineOptionFixups) do
		if not meta.AppliedOptionFixups[fixup] and type(func) == "function" then
			procall(func, EngineOptions, meta.last_applied_fixup_revision)
			count = count + 1
			applied[#applied + 1] = fixup
			meta.AppliedOptionFixups[fixup] = true
			meta.last_applied_fixup_revision = LuaRevision
		end
	end
	
	if count > 0 then
		SaveEngineOptions()
		DebugPrint(string.format("Applied %d engine option fixup(s): %s\n", count, table.concat(applied, ", ")))
	end
	
	return count
end

-- Account option fixups
-- Executed after a new AccountStorage is loaded
---
--- Applies any pending account option fixups to the AccountStorage.Options table.
---
--- Account option fixups can be used to force changes to account option values for all users.
--- They work similarly to savegame fixups, but are separated into two namespaces:
--- EngineOptionFixups and AccountOptionFixups.
---
--- This function iterates through the AccountOptionFixups table, calling any functions
--- that have not yet been applied. It then saves the updated AccountStorage.Options and prints
--- a debug message indicating which fixups were applied.
---
--- @return number The number of fixups that were applied.
function Options.FixupAccountOptions()
	AccountStorage.Options = AccountStorage.Options or {}
	local opt = AccountStorage.Options
	opt.fixups_meta = opt.fixups_meta or GetDefaultOptionFixupMeta()
	local meta = opt.fixups_meta
	meta.AppliedOptionFixups = meta.AppliedOptionFixups or {}
	local count, applied = 0, {}
	
	for fixup, func in sorted_pairs(AccountOptionFixups) do
		if not meta.AppliedOptionFixups[fixup] and type(func) == "function" then
			procall(func, AccountStorage.Options, meta.last_applied_fixup_revision)
			count = count + 1
			applied[#applied + 1] = fixup
			meta.AppliedOptionFixups[fixup] = true
			meta.last_applied_fixup_revision = LuaRevision
		end
	end
	
	if count > 0 then
		SaveAccountStorage()
		DebugPrint(string.format("Applied %d account option fixup(s): %s\n", count, table.concat(applied, ", ")))
	end
	
	return count
end

local option_groups = config.SoundOptionGroups or {}
config.SoundOptionGroups = option_groups
local option_sound_groups = {}
for option, groups in pairs(option_groups) do
	for _, group in ipairs(groups) do
		option_sound_groups[group] = true
	end
end
if config.SoundGroups then
	for _, group in ipairs(config.SoundGroups) do
		if not option_sound_groups[group] then
			option_groups[group] = option_groups[group] or {group}
		end
	end
else
	config.SoundGroups = table.keys(option_sound_groups, true)
end

if not config.DisableOptions then

---
--- Handles the autorun logic for options, including:
--- - Configuring the TAA option based on the graphics adapter and available temporal AA techniques
--- - Overriding option values from the `ProjectOptions` table
--- - Sorting the options in the `OptionsData.Options` table
--- - Applying the video preset and saving the `EngineOptions`
--- - Reloading account options when Lua is reloaded
---
--- @return nil
function OnMsg.Autorun()
	local taa_option = table.find_value(OptionsData.Options.Antialiasing, "value", "TAA")
	if Platform.pc then
		local graphics_adapter = GetRenderDeviceAdapterData(config.GraphicsApi, config.GraphicsAdapterIndex)
		local gpu_name = string.lower(graphics_adapter.name)
		local is_intel =
			graphics_adapter.vendorId == const.VendorIds.Intel or
			string.find(gpu_name, "intel") or
			string.find(gpu_name, "arc")

		local dlss = hr.TemporalIsTypeSupported("dlss")
		local fsr2 = hr.TemporalIsTypeSupported("fsr2")
		local xess = hr.TemporalIsTypeSupported("xess")

		if dlss then
			taa_option.hr = table.find_value(OptionsData.Options.Antialiasing, "value", "DLSS").hr
		elseif (is_intel or not fsr2) and xess then
			taa_option.hr = table.find_value(OptionsData.Options.Antialiasing, "value", "XESS").hr
		elseif fsr2 then
			taa_option.hr = table.find_value(OptionsData.Options.Antialiasing, "value", "FSR2").hr
		end
	end

	if taa_option.hr == empty_table then
		 -- if for some reason TAA is selected while not_selectable, naming the option "Off" will inform the user of the current situation.
		taa_option.text = T(392695272733, --[[options:Antialiasing is turned off]] "Off")
	end

	local OverrideOptionValues = function(baseValues, overrideValues, skipKeys)
		for overrideKey,overrideValue in pairs(overrideValues) do
			if not table.find(skipKeys, overrideKey) then
				if type(overrideValue) == "table" then
					for key, value in pairs(overrideValue) do
						baseValues[overrideKey][key] = value
					end
				else
					baseValues[overrideKey] = overrideValue
				end
			end
		end
	end

	for option,projectOptionValues in pairs(rawget(_G, "ProjectOptions") or empty_table) do
		if OptionsData.Options[option] then
			for _,projectOptionValue in ipairs(projectOptionValues) do
				local options = OptionsData.Options[option]
				local baseOptionValue = table.find_value(options, "value", projectOptionValue.value)
				if baseOptionValue then
					OverrideOptionValues(baseOptionValue, projectOptionValue, { "value", "text" })
				else
					options[#options + 1] = projectOptionValue
				end
			end
		else
			OptionsData.Options[option] = projectOptionValues
		end
	end

	for option,optionValues in pairs(OptionsData.Options) do
		table.stable_sort(optionValues, function(a, b)
			if a.SortKey and b.SortKey then
				return a.SortKey < b.SortKey
			else
				return a.SortKey
			end
		end)
	end

	if EngineOptions then
		-- Apply video options and save EngineOptions
		local preset = EngineOptions.VideoPreset
		ApplyVideoPreset(preset)
		SaveEngineOptions()
		
		-- Reload account options when reloading Lua
		ApplyAccountOptions()
	end
	Options.InitGraphicsApiCombo()
end

--reload account options when we get new account storage, something that happens on the xbox
---
--- Handles changes to the account storage, reloading shortcuts and applying the language option.
---
--- This function is called when the account storage changes, such as when the user logs in or out.
--- It first checks if there are any shortcuts in the account storage, and if so, calls `ReloadShortcuts` after a short delay.
--- It then calls `ApplyLanguageOption` after a short delay to apply any changes to the language settings.
---
--- @function OnMsg.AccountStorageChanged
--- @return nil
function OnMsg.AccountStorageChanged()
	if AccountStorage and next(AccountStorage.Shortcuts) then
		DelayedCall(0, ReloadShortcuts)
	end
	DelayedCall(0, ApplyLanguageOption)
end

---
--- Handles changes to the local storage, reapplying engine options and updating the system size.
---
--- This function is called when the local storage changes, such as when the user logs in or out.
--- It first calls `Options.ApplyEngineOptions` to reapply any changes to the engine options.
--- It then calls `terminal.desktop:OnSystemSize` to update the system size, which may be necessary if the display settings have changed.
---
--- @function OnMsg.LocalStorageChanged
--- @return nil
function OnMsg.LocalStorageChanged()
	Options.ApplyEngineOptions(EngineOptions)
	terminal.desktop:OnSystemSize(UIL.GetScreenSize())
end

---
--- Handles changes to the system size, updating the engine options and UI.
---
--- This function is called when the system size changes, such as when the window is resized or the display mode changes.
--- It updates the `EngineOptions.Resolution` and `EngineOptions.DisplayIndex` properties to reflect the new system size, and then calls `Options.UpdateVideoModesCombo` to update the video mode options UI.
--- If an `OptionsObj` is available, it also updates the `Resolution` property of that object and marks it as modified.
---
--- @function OnMsg.SystemSize
--- @param pt point The new system size
--- @return nil
function OnMsg.SystemSize(pt)
	EngineOptions.Resolution = pt
	EngineOptions.DisplayIndex = GetMainWindowDisplayIndex()
	Options.UpdateVideoModesCombo()
	if OptionsObj then
		OptionsObj:SetProperty("Resolution", pt)
		ObjModified(OptionsObj)
	end
end

if Platform.desktop then

---
--- Handles the application quit event by saving the current display index if it has changed.
---
--- This function is called when the application is about to quit. It checks if the current display index
--- is different from the one stored in `EngineOptions.DisplayIndex`. If so, it updates the
--- `EngineOptions.DisplayIndex` property and saves the engine options.
---
--- @function OnMsg.ApplicationQuit
--- @return nil
function OnMsg.ApplicationQuit()
	local display_index =  GetMainWindowDisplayIndex()
	if EngineOptions.DisplayIndex ~= display_index then
		EngineOptions.DisplayIndex = display_index
		SaveEngineOptions()
	end
end

end -- if Platform.pc

end -- if not config.DisableOptions then

---
--- Picks the appropriate video preset based on the given GPU name.
---
--- This function takes a table of preset regexes and a GPU name, and returns the video preset that matches the GPU name. If no match is found, it tries to determine the preset based on the platform (Xbox One, PS4, etc.).
---
--- @param preset_regexes table A table of preset regexes, where each entry is a table with two elements: a list of regexes and the corresponding preset name.
--- @param gpu string The name of the GPU.
--- @return string The video preset that matches the GPU name, or a default preset if no match is found.
---
function Options.PickVideoPreset(preset_regexes, gpu)
	for _, v in ipairs(preset_regexes) do
		for _, re in ipairs(v[1]) do
			if gpu:match(re) then
				return v.preset
			end
		end
	end
	
	
	if Platform.xbox_one then
		preset = Platform.xbox_one_x and "xbox_one_x" or "xbox_one"
	elseif Platform.xbox_series then
		preset = Platform.xbox_series_x and "xbox_series_x" or "xbox_series_s"
	elseif Platform.ps4 then
		preset = Platform.xbox_ps4_pro and "ps4_pro" or "ps4"
	elseif Platform.ps5 then
		preset = "ps5"
	end
	if preset then
		return DefaultEngineOptions[preset].VideoPreset
	end
	
	return "High"
end

-- this uses data coming from config table, as ProjectOptions and its data isn't yet loaded
---
--- Automatically detects and sets the appropriate video options based on the user's hardware.
---
--- This function checks the user's display resolution and graphics adapter, and sets the appropriate video preset and texture quality based on the detected hardware.
---
--- @param options table The table of engine options to be updated.
--- @return nil
---
function Options.Autodetect(options)
	if Platform.pc or Platform.steamdeck then
		if not IsPoint(options.Resolution) then
			local currentMode = GetDisplayMode(options.DisplayIndex)
			options.Resolution = point(currentMode.displayWidth, currentMode.displayHeight)
		end
	end

	if not options.GraphicsAdapter then
		options.VideoPreset = "Low"
		return
	end
	
	options.VideoPreset = Options.PickVideoPreset(config.VideoPresetAutodetect or empty_table, string.lower(options.GraphicsAdapter.name))
	
	options.Textures = "High"
	for _,v in ipairs(config.TextureMemoryThresholds or empty_table) do
		if options.GraphicsAdapter.videoRam < v.threshold * 1024 * 1024 then
			options.Textures = v.value
			break
		end
	end
end

---
--- Applies the engine options to the local options.
---
--- This function takes the local options and applies them to the engine options defaults. It also handles any HR (high resolution) overrides that may be defined in the options data.
---
--- @param local_options table The local options to be applied.
--- @return nil
---
function Options.ApplyEngineOptions(local_options)
	local engine_options_defaults = GetTableWithStorageDefaults("local")
	local options_data = OptionsData.Options
	local hr_override

	for k,v in pairs(engine_options_defaults) do
		-- Keys from the defaults
		-- Values from the local EngineOptions
		v = local_options[k]

		local value = table.find_value(options_data[k], "value", v)
		local hr = options_data[k] and options_data[k].hr or value and value.hr
		for hrk, hrv in pairs(hr or empty_table) do
			if type(hrv) == "function" then
				hrv = hrv(v, hrk)
			end
			if hrv ~= nil then
				hr_override = hr_override or {}
				if hr_override[hrk] then
					printf("once", "OptionsData.Options.%s sets hr.%s which was already set by another table", k, hrk)
				end
				hr_override[hrk] = hrv
			end
		end
	end

	if hr_override then
		hr.TR_ReloadSuspended = hr.TR_ReloadSuspended | 1
		table.change_base(hr, hr_override)
		hr.TR_ReloadSuspended = hr.TR_ReloadSuspended & ~1
	end
	
	ApplySoundOptions(local_options)
end

---
--- Sets the volume for a specific sound option.
---
--- @param option string The name of the sound option to set the volume for.
--- @param volume number The volume to set, between 0 and 1000.
---
function SetOptionVolume(option, volume)
	for _, group in ipairs(config.SoundOptionGroups[option]) do
		SetOptionsGroupVolume(group, volume)
	end
end

---
--- Applies the sound options specified in the given local_options table.
---
--- @param local_options table The local options to be applied.
---
function ApplySoundOptions(local_options)
	local master_volume = local_options.MasterVolume or 1000
	for option in pairs(config.SoundOptionGroups) do
		SetOptionVolume(option, master_volume * (local_options[option] or 1000)/ 1000)
	end
	config.DontMuteWhenInactive = local_options.MuteWhenMinimized ~= nil and not local_options.MuteWhenMinimized or false
end

---
--- Initializes the video modes combo box in the options menu.
---
--- This function populates the `OptionsData.Options.Resolution` table with the available video modes,
--- sorted by resolution. It also adds a custom resolution option if the current resolution is not
--- in the list of available modes.
---
--- @function Options.InitVideoModesCombo
--- @return nil
function Options.InitVideoModesCombo()
	local modes = {}
	for i, mode in ipairs(GetVideoModes(EngineOptions.DisplayIndex, 1024, 720)) do
		local resolution = point(mode.Width, mode.Height)
		local key = tostring(resolution)
		modes[key] = resolution
	end
	if Platform.developer then
		local ultrawide = point(120*21, 120*9)
		modes[tostring(ultrawide)] = ultrawide
	end
	local sorted_modes = table.values(modes)
	table.sort(sorted_modes, function(a, b) return a:x() * a:y() < b:x() * b:y() end)
	OptionsData.Options.Resolution = {}
	for i, v in ipairs(sorted_modes) do
		OptionsData.Options.Resolution[i] = { value = v, text = T{664014484626, "<FormatResolution(pt)>", pt = v}}
	end
	--add custom option if needed
	Options.UpdateVideoModesCombo()
end

---
--- Initializes the graphics API combo box in the options menu.
---
--- This function populates the `OptionsData.Options.GraphicsApi` table with the available graphics APIs,
--- including DirectX 11 (deprecated) and DirectX 12. If only one graphics API is available, the option
--- is marked as not editable and not saved.
---
--- @function Options.InitGraphicsApiCombo
--- @return nil
function Options.InitGraphicsApiCombo()
	local available = GetAvailableGraphicsApis()	
	OptionsData.Options.GraphicsApi = {
		{ value = "d3d11", text = Untranslated("DirectX 11 (deprecated)"), not_selectable = not table.find(available, "d3d11") },
		{ value = "d3d12", text = Untranslated("DirectX 12"), not_selectable = not table.find(available, "d3d12") },
	}

	if table.count(OptionsData.Options.GraphicsApi, "not_selectable", false) <= 1 then
		local graphicsApiOption = table.find_value(OptionsObject.properties, "id", "GraphicsApi")
		graphicsApiOption.dont_save = true
		graphicsApiOption.no_edit = true
	end
end

--- Initializes the graphics adapter combo box in the options menu.
---
--- This function populates the `OptionsData.Options.GraphicsAdapterIndex` table with the available graphics adapters,
--- including their index and name. The graphics adapter index is used to select the appropriate adapter when
--- initializing the graphics API.
---
--- @function Options.InitGraphicsAdapterCombo
--- @param graphicsApi string The graphics API to use for enumerating the available adapters.
--- @return nil
function Options.InitGraphicsAdapterCombo(graphicsApi)
	local adapters = {}
	for i = 0,GetNumRenderDeviceAdapters(graphicsApi)-1 do
		local adapterData = GetRenderDeviceAdapterData(graphicsApi, i)
		adapters[i+1] = { value = i, text = Untranslated(adapterData.name) }
	end
	OptionsData.Options.GraphicsAdapterIndex = adapters
end

---
--- Updates the video modes combo box in the options menu.
---
--- This function checks the current resolution and ensures it is present in the `OptionsData.Options.Resolution` table. If the current resolution is not found, it is added to the table in the correct sorted position.
---
--- If a custom resolution entry already exists in the table, it is removed before adding the new entry.
---
--- @function Options.UpdateVideoModesCombo
--- @return nil
function Options.UpdateVideoModesCombo()
	local v = point(GetResolution())
	--remove any custom items
	local custom_idx = table.find(OptionsData.Options.Resolution, "custom", true)
	local idx = table.find(OptionsData.Options.Resolution, "value", v)
	if custom_idx and custom_idx ~= idx then
		table.remove(OptionsData.Options.Resolution, custom_idx)
	end
	if not idx then
		--insert current value in correct position
		local entry = { value = v, text = T{664014484626, "<FormatResolution(pt)>", pt = v}, custom = true}
		table.insert_sorted(OptionsData.Options.Resolution, entry, "value")
	end
end

---
--- Defines the available video presets for the game options.
---
--- The `OptionsData.Options.VideoPreset` table contains a list of video preset options that can be selected in the game's options menu. Each preset has a `value` field that represents the internal identifier for the preset, a `text` field that contains the display name for the preset, and a `not_selectable` field that determines whether the preset should be hidden from the user interface based on the current platform.
---
--- The available presets include:
--- - `Low`: A low-quality video preset.
--- - `Medium`: A medium-quality video preset.
--- - `High`: A high-quality video preset.
--- - `Ultra`: An ultra-high-quality video preset.
--- - `XboxOne`: A preset for the Xbox One console.
--- - `XboxOneX`: A preset for the Xbox One X console.
--- - `XboxSeriesS`: A preset for the Xbox Series S console.
--- - `XboxSeriesXQuality`: A quality-focused preset for the Xbox Series X console.
--- - `XboxSeriesXPerformance`: A performance-focused preset for the Xbox Series X console.
--- - `PS4`: A preset for the PlayStation 4 console.
--- - `PS4Pro`: A preset for the PlayStation 4 Pro console.
--- - `PS5Quality`: A quality-focused preset for the PlayStation 5 console.
--- - `PS5Performance`: A performance-focused preset for the PlayStation 5 console.
--- - `Switch`: A preset for the Nintendo Switch console.
--- - `SteamDeck`: A preset for the Steam Deck handheld console.
--- - `Custom`: A custom video preset that allows the user to configure the settings manually.
---
OptionsData.Options.VideoPreset = {
	{ value = "Low", text = T(644, "Low"), not_selectable = Platform.console },
	{ value = "Medium", text = T(645, "Medium"), not_selectable = Platform.console },
	{ value = "High", text = T(7375, "High"), not_selectable = Platform.console },
	{ value = "Ultra", text = T(3551, "Ultra"), not_selectable = Platform.console },
	{ value = "XboxOne", text = Untranslated("*XboxOne"), not_selectable = not Platform.developer },
	{ value = "XboxOneX", text = Untranslated("*XboxOneX"), not_selectable = not (Platform.xbox_one_x or Platform.developer) },
	{ value = "XboxSeriesS", text = Untranslated("*XboxSeriesS"), not_selectable = not (Platform.xbox_series_s or Platform.developer) },
	{ value = "XboxSeriesXQuality", text = Platform.developer and Untranslated("*XboxSeriesXQuality") or T(709029849246, "Quality"), not_selectable = not (Platform.xbox_series_x or Platform.developer) },
	{ value = "XboxSeriesXPerformance", text = Platform.developer and Untranslated("*XboxSeriesXPerformance") or T(731233321844, "Performance"), not_selectable = not (Platform.xbox_series_x or Platform.developer) },
	{ value = "PS4", text = Untranslated("*PS4"), not_selectable = not Platform.developer },
	{ value = "PS4Pro", text = Untranslated("*PS4Pro"), not_selectable = not Platform.developer },
	{ value = "PS5Quality", text = Platform.developer and Untranslated("*PS5Quality") or T(709029849246, "Quality"), not_selectable = not (Platform.ps5 or Platform.developer) },
	{ value = "PS5Performance", text = Platform.developer and Untranslated("*PS5Performance") or T(731233321844, "Performance"), not_selectable = not (Platform.ps5 or Platform.developer) },
	{ value = "Switch", text = Untranslated("*Switch"), not_selectable = not Platform.developer },
	{ value = "SteamDeck", text = Untranslated("Steam Deck"), not_selectable = not (Platform.steamdeck or Platform.developer) },
	{ value = "Custom", text = T(6843, "*Custom"), not_selectable = Platform.console },
}

---
--- Defines the available fullscreen mode options for the game.
---
--- The `OptionsData.Options.FullscreenMode` table contains a list of fullscreen mode options that can be selected in the game's options menu. Each option has a `value` field that represents the internal identifier for the mode, and a `text` field that contains the display name for the mode.
---
--- The available modes include:
--- - `0`: Windowed mode
--- - `1`: Fullscreen mode
---
OptionsData.Options.FullscreenMode = {
	{ value = 0, text = T(443238066363, --[[Options dialog fullscreen mode]] "Windowed"), },
	{ value = 1, text = T(873558273070, --[[Options dialog fullscreen mode]] "Fullscreen"), },
}

---
--- Defines the available maximum FPS options for the game.
---
--- The `OptionsData.Options.MaxFps` table contains a list of maximum FPS options that can be selected in the game's options menu. Each option has a `value` field that represents the internal identifier for the FPS limit, and a `text` field that contains the display name for the FPS limit.
---
--- The available FPS limits include:
--- - `30`: Limits the game to 30 FPS.
--- - `60`: Limits the game to 60 FPS.
--- - `120`: Limits the game to 120 FPS.
--- - `144`: Limits the game to 144 FPS.
--- - `240`: Limits the game to 240 FPS.
--- - `Unlimited`: Removes the FPS limit, allowing the game to run at the maximum possible frame rate.
---
OptionsData.Options.MaxFps = {
	{ value = "30", text = Untranslated("30 ") .. T(206424973826, --[[options: frame limit]] "FPS"), hr = { MaxFps = 30 } },
	{ value = "60", text = Untranslated("60 ") .. T(206424973826, --[[options: frame limit]] "FPS"), hr = { MaxFps = 60 } },
	{ value = "120", text = Untranslated("120 ") .. T(206424973826, --[[options: frame limit]] "FPS"), hr = { MaxFps = 120 } },
	{ value = "144", text = Untranslated("144 ") .. T(206424973826, --[[options: frame limit]] "FPS"), hr = { MaxFps = 144 } },
	{ value = "240", text = Untranslated("240 ") .. T(206424973826, --[[options: frame limit]] "FPS"), hr = { MaxFps = 240 } },
	{ value = "Unlimited", text = T(715166204973, --[[options: frame limit]] "Unlimited"), hr = { MaxFps = 0 } },
}
---
--- Defines the available options for Screen Space Ambient Occlusion (SSAO) in the game.
---
--- The `OptionsData.Options.SSAO` table contains a list of SSAO options that can be selected in the game's options menu. Each option has a `value` field that represents the internal identifier for the SSAO mode, and a `text` field that contains the display name for the SSAO mode.
---
--- The available SSAO modes include:
--- - `Off`: Disables SSAO.
--- - `On`: Enables SSAO.
---
--- The `hr` field for each option contains a table of settings that will be applied when the corresponding option is selected. In this case, the `EnableScreenSpaceAmbientObscurance` setting is used to control whether SSAO is enabled or disabled.
---
OptionsData.Options.SSAO = {
	{ value = "Off", text = T(549548241533, "Off"), hr = { EnableScreenSpaceAmbientObscurance = 0 } },
	{ value = "On", text = T(336462699824, "On"), hr = { EnableScreenSpaceAmbientObscurance = 1 } },}

---
--- Defines the available options for Screen Space Reflections (SSR) in the game.
---
--- The `OptionsData.Options.SSR` table contains a list of SSR options that can be selected in the game's options menu. Each option has a `value` field that represents the internal identifier for the SSR mode, and a `text` field that contains the display name for the SSR mode.
---
--- The available SSR modes include:
--- - `Off`: Disables SSR.
--- - `Low`: Enables SSR with low quality settings.
--- - `Medium`: Enables SSR with medium quality settings.
--- - `High`: Enables SSR with high quality settings.
--- - `Ultra`: Enables SSR with ultra quality settings.
---
--- The `hr` field for each option contains a table of settings that will be applied when the corresponding option is selected. These settings control various parameters of the SSR implementation, such as the downsampling coefficient, the number of pixels to skip, the number of pixels to pass behind, and the threshold for parent distance.
---
OptionsData.Options.SSR = {
	{ value = "Off", text = T(347421390938, --[[options:SSR is off]] "Off"), hr = { EnableScreenSpaceReflections = 0 } },
	{ value = "Low", text = T(967597583816, --[[options:SSR is turned to low]] "Low"), hr = { EnableScreenSpaceReflections = 1, SSRDownsampleCoef = 4, SSRSkipPixels = 2, SSRPassBehindPixels = -32, SSRThresholdParentDistance = 0 } },
	{ value = "Medium", text = T(711881918198, --[[options:SSR is turned to Medium]] "Medium"), hr = { EnableScreenSpaceReflections = 1, SSRDownsampleCoef = 2, SSRSkipPixels = 1, SSRPassBehindPixels = -96, SSRThresholdParentDistance = config.SSRThresholdParentDistance } },
	{ value = "High", text = T(350030693801, --[[options:SSR is turned to high]] "High"), hr = { EnableScreenSpaceReflections = 1, SSRDownsampleCoef = 1, SSRPassBehindPixels = -192, SSRThresholdParentDistance = config.SSRThresholdParentDistance } },
	{ value = "Ultra", text = T(363062651990, --[[options:SSR is turned to Ultra]] "Ultra"), hr = { EnableScreenSpaceReflections = 1, SSRDownsampleCoef = 1, SSRPassBehindPixels = -192, SSRThresholdParentDistance = 0 } },
}

---
--- Defines the available options for Bloom post-processing effect in the game.
---
--- The `OptionsData.Options.Bloom` table contains a list of Bloom options that can be selected in the game's options menu. Each option has a `value` field that represents the internal identifier for the Bloom mode, and a `text` field that contains the display name for the Bloom mode.
---
--- The available Bloom modes include:
--- - `Off`: Disables the Bloom effect.
--- - `On`: Enables the Bloom effect.
---
--- The `hr` field for each option contains a table of settings that will be applied when the corresponding option is selected. In this case, the `EnablePostProcBloom` setting is used to control whether the Bloom effect is enabled or disabled.
---
OptionsData.Options.Bloom = {
	{ value = "Off", text = T(897923163870, --[[options:Bloom is off]] "Off"), hr = { EnablePostProcBloom = 0 } },
	{ value = "On", text = T(962119091084, --[[options:Bloom is on]] "On"), hr = { EnablePostProcBloom = 1 } },
}

---
--- Defines the available options for Eye Adaptation post-processing effect in the game.
---
--- The `OptionsData.Options.EyeAdaptation` table contains a list of Eye Adaptation options that can be selected in the game's options menu. Each option has a `value` field that represents the internal identifier for the Eye Adaptation mode, and a `text` field that contains the display name for the Eye Adaptation mode.
---
--- The available Eye Adaptation modes include:
--- - `Off`: Disables the Eye Adaptation effect.
--- - `On`: Enables the Eye Adaptation effect.
---
--- The `hr` field for each option contains a table of settings that will be applied when the corresponding option is selected. In this case, the `AutoExposureMode` setting is used to control whether the Eye Adaptation effect is enabled or disabled.
---
OptionsData.Options.EyeAdaptation = {
	{ value = "Off", text = T(764902318645, --[[options:Eye Adaptation is off]] "Off"), hr = { AutoExposureMode = 0 } },
	{ value = "On", text = T(310678453010, --[[options:Eye Adaptation is on]] "On"), hr = { AutoExposureMode = 1 } },
}

---
--- Defines the available options for the Vignette post-processing effect in the game.
---
--- The `OptionsData.Options.Vignette` table contains a list of Vignette options that can be selected in the game's options menu. Each option has a `value` field that represents the internal identifier for the Vignette mode, and a `text` field that contains the display name for the Vignette mode.
---
--- The available Vignette modes include:
--- - `Off`: Disables the Vignette effect.
--- - `On`: Enables the Vignette effect.
---
--- The `hr` field for each option contains a table of settings that will be applied when the corresponding option is selected. In this case, the `EnablePostProcVignette` setting is used to control whether the Vignette effect is enabled or disabled.
OptionsData.Options.Vignette = {
	{ value = "Off", text = T(173515508906, --[[options:Vignette is off]] "Off"), hr = { EnablePostProcVignette = 0 } },
	{ value = "On", text = T(724497759523, --[[options:Vignette is on]] "On"), hr = { EnablePostProcVignette = 1} },
}

---
--- Defines the available options for the Chromatic Aberration post-processing effect in the game.
---
--- The `OptionsData.Options.ChromaticAberration` table contains a list of Chromatic Aberration options that can be selected in the game's options menu. Each option has a `value` field that represents the internal identifier for the Chromatic Aberration mode, and a `text` field that contains the display name for the Chromatic Aberration mode.
---
--- The available Chromatic Aberration modes include:
--- - `Off`: Disables the Chromatic Aberration effect.
--- - `On`: Enables the Chromatic Aberration effect.
---
--- The `hr` field for each option contains a table of settings that will be applied when the corresponding option is selected. In this case, the `PostProcChromaticAberration` setting is used to control whether the Chromatic Aberration effect is enabled or disabled.
OptionsData.Options.ChromaticAberration = {
	{ value = "Off", text = T(535014732326, --[[options:Chromatic Aberration is off]] "Off"), hr = { PostProcChromaticAberration = 0 } },
	{ value = "On", text = T(945084644408, --[[options:Chromatic Aberration is on]] "On"), hr = { PostProcChromaticAberration = 100 } },
}

---
--- Defines the available options for the FPS counter in the game.
---
--- The `OptionsData.Options.FPSCounter` table contains a list of FPS counter options that can be selected in the game's options menu. Each option has a `value` field that represents the internal identifier for the FPS counter mode, and a `text` field that contains the display name for the FPS counter mode.
---
--- The available FPS counter modes include:
--- - `Off`: Disables the FPS counter.
--- - `Fps`: Displays the current frames per second.
--- - `Ms`: Displays the current frame time in milliseconds.
---
--- The `hr` field for each option contains a table of settings that will be applied when the corresponding option is selected. In this case, the `FpsCounter` setting is used to control the FPS counter mode.
OptionsData.Options.FPSCounter = {
	{ value = "Off", text = T(290121664929, --[[options:FPS counter is off]] "Off"), hr = { FpsCounter = 0 } },
	{ value = "Fps", text = T(783476822556, --[[options:FPS counter shows frames per second]] "FPS"), hr = { FpsCounter = 1 } },
	{ value = "Ms", text = T(271886807258, --[[options:FPS counter shows miliseconds]] "ms"), hr = { FpsCounter = 2 } },
}

---
--- Defines the available options for the Texture quality setting in the game.
---
--- The `OptionsData.Options.Textures` table contains a list of Texture quality options that can be selected in the game's options menu. Each option has a `value` field that represents the internal identifier for the Texture quality mode, and a `text` field that contains the display name for the Texture quality mode.
---
--- The available Texture quality modes include:
--- - `Low`: Reduces the texture quality and streaming video memory usage.
--- - `Low (Consoles)`: Reduces the texture quality and streaming video memory usage for console platforms.
--- - `Medium (Consoles)`: Sets the texture quality and streaming video memory usage to a medium level for console platforms.
--- - `Medium`: Sets the texture quality and streaming video memory usage to a medium level.
--- - `High`: Increases the texture quality and streaming video memory usage.
--- - `Ultra`: Sets the texture quality and streaming video memory usage to the highest level.
---
--- The `hr` field for each option contains a table of settings that will be applied when the corresponding option is selected. These settings control the `StreamingVideoMemory` and `BillboardMaterialQualityReductionLevel` parameters, which affect the texture quality and memory usage.
---
--- The `not_selectable` field is used to mark certain options as not selectable, such as the "Low (Consoles)" and "Medium (Consoles)" options, which are only available on console platforms.
OptionsData.Options.Textures = {
	{ value = "Low", text = T(812680094837, --[[options:Texture quality is set to Low]] "Low"), hr = { StreamingVideoMemory = 384, BillboardMaterialQualityReductionLevel = 1 } },
	{ value = "Low (Consoles)", text = Untranslated("Low (Consoles)"), hr = { StreamingVideoMemory = 512, BillboardMaterialQualityReductionLevel = 1 }, not_selectable = Platform.pc and not Platform.developer },
	{ value = "Medium (Consoles)", text = Untranslated("Medium (Consoles)"), hr = { StreamingVideoMemory = 1024, BillboardMaterialQualityReductionLevel = 1 }, not_selectable = Platform.pc and not Platform.developer },
	{ value = "Medium", text = T(645, --[[options:Texture quality is set to Medium]] "Medium"), hr = { StreamingVideoMemory = 1024, BillboardMaterialQualityReductionLevel = 0 } },
	{ value = "High", text = T(396237728087, --[[options:Texture quality is set to High]] "High"), hr = { StreamingVideoMemory = 2048, BillboardMaterialQualityReductionLevel = 0 } },
	{ value = "Ultra", text =  T(324283091069, --[[options:Texture quality is set to Ultra]] "Ultra"), hr = { StreamingVideoMemory = 4096, BillboardMaterialQualityReductionLevel = 0 } },
}

---
--- Defines the available options for the Terrain detail setting in the game.
---
--- The `OptionsData.Options.Terrain` table contains a list of Terrain detail options that can be selected in the game's options menu. Each option has a `value` field that represents the internal identifier for the Terrain detail mode, and a `text` field that contains the display name for the Terrain detail mode.
---
--- The available Terrain detail modes include:
--- - `Low (Switch)`: Reduces the terrain detail and chunk size for the Nintendo Switch platform.
--- - `Low`: Reduces the terrain detail and chunk size.
--- - `Medium`: Sets the terrain detail and chunk size to a medium level.
--- - `High`: Increases the terrain detail and chunk size.
--- - `Ultra`: Sets the terrain detail and chunk size to the highest level.
---
--- The `hr` field for each option contains a table of settings that will be applied when the corresponding option is selected. These settings control the `TR_ChunkSize`, `TR_MaxChunks`, `TR_MaxChunksPerFrame`, `TR_MaterialQualityReductionLevel`, and `TR_UseQualityCompression` parameters, which affect the terrain detail and performance.
---
--- The `not_selectable` field is used to mark certain options as not selectable, such as the "Low (Switch)" option, which is only available on the Nintendo Switch platform.
OptionsData.Options.Terrain = {
	{ value = "Low (Switch)", text = Untranslated("*Low (Switch)"), hr = { TR_ChunkSize = 256, TR_MaxChunks = 64, TR_MaxChunksPerFrame = 1, TR_MaterialQualityReductionLevel = 2, TR_UseQualityCompression = 0 }, not_selectable = not Platform.developer },
	{ value = "Low", text = T(619416576830, --[[options:Terrain detail is set to Low]] "Low"), hr = { TR_ChunkSize = 256, TR_MaxChunks = 64, TR_MaxChunksPerFrame = 1, TR_MaterialQualityReductionLevel = 2 } },
	{ value = "Medium", text = T(482982848821, --[[options:Terrain detail is set to Medium]] "Medium"), hr = { TR_ChunkSize = 256, TR_MaxChunks = 128, TR_MaxChunksPerFrame = 2, TR_MaterialQualityReductionLevel = 1 } },
	{ value = "High", text = T(424607201144, --[[options:Terrain detail is set to High]] "High"), hr = { TR_ChunkSize = 512, TR_MaxChunks = 128, TR_MaxChunksPerFrame = 2, TR_MaterialQualityReductionLevel = 0 } },
	{ value = "Ultra", text = T(340208038771, --[[options:Terrain detail is set to Ultra]] "Ultra"), hr = { TR_ChunkSize = 512, TR_MaxChunks = 128, TR_MaxChunksPerFrame = 5, TR_MaterialQualityReductionLevel = 0 } },
}

---
--- Defines the available options for the Effects detail setting in the game.
---
--- The `OptionsData.Options.Effects` table contains a list of Effects detail options that can be selected in the game's options menu. Each option has a `value` field that represents the internal identifier for the Effects detail mode, and a `text` field that contains the display name for the Effects detail mode.
---
--- The available Effects detail modes include:
--- - `Low (Switch)`: Reduces the effects detail for the Nintendo Switch platform.
--- - `Low`: Reduces the effects detail.
--- - `Medium`: Sets the effects detail to a medium level.
--- - `High`: Increases the effects detail.
--- - `Ultra`: Sets the effects detail to the highest level.
---
--- The `hr` field for each option contains a table of settings that will be applied when the corresponding option is selected. These settings control the `FXDetailThreshold`, `RainQuality`, `RainStreaksCount`, `MaxParticles`, `TargetParticles`, and `MaxParticlesWithCollision` parameters, which affect the effects detail and performance.
---
--- The `not_selectable` field is used to mark certain options as not selectable, such as the "Low (Switch)" option, which is only available on the Nintendo Switch platform.
OptionsData.Options.Effects = {
	{ value = "Low (Switch)", text = Untranslated("*Low (Switch)"), hr = { FXDetailThreshold = 70, RainQuality = const.RainQualityVeryLow, RainStreaksCount = 16 * 1024, MaxParticles = 6000, TargetParticles = 5000, MaxParticlesWithCollision = 0, }, not_selectable = Platform.pc and not Platform.developer },
	{ value = "Low", text = T(921959811873, --[[options:Effects detail is set to Low]] "Low"), hr = { FXDetailThreshold = 70, RainQuality = const.RainQualityLow, MaxParticles = 6000, TargetParticles = 5000, MaxParticlesWithCollision = 50,  } },
	{ value = "Medium", text = T(177066169751, --[[options:Effects detail is set to Medium]] "Medium"), hr = { FXDetailThreshold = 50, RainQuality = const.RainQualityMedium, MaxParticles = 7500, TargetParticles = 6500, MaxParticlesWithCollision = 150,} },
	{ value = "High", text = T(354778733499, --[[options:Effects detail is set to High]] "High"), hr = { FXDetailThreshold = 0, RainQuality = const.RainQualityHigh, MaxParticles = 30000, TargetParticles = 29000, MaxParticlesWithCollision = 300, } },
	{ value = "Ultra", text = T(107890243019, --[[options:Effects detail is set to Ultra]] "Ultra"), hr = { FXDetailThreshold = 0, RainQuality = const.RainQualityUltra, MaxParticles = 100000, TargetParticles = 95000, MaxParticlesWithCollision = 500,  } },
}

---
--- Defines the available options for the View Distance setting in the game.
---
--- The `OptionsData.Options.ViewDistance` table contains a list of View Distance options that can be selected in the game's options menu. Each option has a `value` field that represents the internal identifier for the View Distance mode, and a `text` field that contains the display name for the View Distance mode.
---
--- The available View Distance modes include:
--- - `Low (Switch)`: Reduces the view distance for the Nintendo Switch platform.
--- - `Low`: Reduces the view distance.
--- - `Medium`: Sets the view distance to a medium level.
--- - `High`: Increases the view distance.
--- - `Ultra`: Sets the view distance to the highest level.
---
--- The `hr` field for each option contains a table of settings that will be applied when the corresponding option is selected. These settings control the `LODDistanceModifier`, `BillboardDistanceModifier`, and `DistanceModifier` parameters, which affect the view distance and performance.
---
--- The `not_selectable` field is used to mark certain options as not selectable, such as the "Low (Switch)" option, which is only available on the Nintendo Switch platform.
OptionsData.Options.ViewDistance = {
	{ value = "Low (Switch)", text = Untranslated("*Low (Switch)"), hr = { LODDistanceModifier = 10, BillboardDistanceModifier = 25, DistanceModifier = 30 }, not_selectable = Platform.pc and not Platform.developer },
	{ value = "Low", text = T(157135452050, --[[options:View distance is set to Low]] "Low"), hr = { LODDistanceModifier = 50, BillboardDistanceModifier = 30, DistanceModifier = 54 } },
	{ value = "Medium", text = T(108271291689, --[[options:View distance is set to Medium]] "Medium"), hr = { LODDistanceModifier = 75, BillboardDistanceModifier = 40, DistanceModifier = 72 } },
	{ value = "High", text = T(215175247095, --[[options:View distance is set to High]] "High"), hr = { LODDistanceModifier = 100, BillboardDistanceModifier = 50, DistanceModifier = 100 } },
	{ value = "Ultra", text = T(239271893639, --[[options:View distance is set to Ultra]] "Ultra"), hr = { LODDistanceModifier = 120, BillboardDistanceModifier = 50, DistanceModifier = 150 } },
}

---
--- Defines the available options for the Shadows setting in the game.
---
--- The `OptionsData.Options.Shadows` table contains a list of Shadows options that can be selected in the game's options menu. Each option has a `value` field that represents the internal identifier for the Shadows mode, and a `text` field that contains the display name for the Shadows mode.
---
--- The available Shadows modes include:
--- - `Off`: Disables shadows.
--- - `Low`: Sets the shadows to a low quality level.
--- - `Medium (PS4,XboxOne)`: Sets the shadows to a medium quality level, optimized for PS4 and Xbox One platforms.
--- - `Medium`: Sets the shadows to a medium quality level.
--- - `High`: Sets the shadows to a high quality level.
--- - `High (PS4Pro)`: Sets the shadows to a high quality level, optimized for PS4 Pro platform.
--- - `Ultra`: Sets the shadows to the highest quality level.
---
--- The `hr` field for each option contains a table of settings that will be applied when the corresponding option is selected. These settings control various shadow-related parameters, such as `Shadowmap`, `ShadowmapSize`, `ShadowPCFSize`, `ShadowCSMProjectionFit`, `ShadowCSMResolutionPercent`, `ShadowReceiversRatio`, `ShadowSDSMEnable`, `ShadowCSMUpdateFrequency`, `LightShadows`, `LightShadowsSize`, `LightShadowsHighQuality`, and `LightShadowsLowQuality`.
---
--- The `not_selectable` field is used to mark certain options as not selectable, such as the "Medium (PS4,XboxOne)" option, which is only available on the PS4 and Xbox One platforms.
OptionsData.Options.Shadows = {
	{ value = "Off", text = T(642008481801, --[[options:Shadows are turned off]] "Off"), hr = { Shadowmap = 0, ShadowmapSize = 0, LightShadows = 0 } },
	{ value = "Low", text = T(770274668602, --[[options:Shadows quality is set to Low]] "Low"), hr = {
		Shadowmap = 1,
		ShadowmapSize = 1536,
		ShadowPCFSize = 1,
		ShadowCSMProjectionFit = 1,
		ShadowCSMResolutionPercent = -65,
		ShadowReceiversRatio = 1,
		ShadowSDSMEnable = 1,
		ShadowCSMUpdateFrequency = "0",
		LightShadows = 1,
		LightShadowsSize = 1024,
		LightShadowsHighQuality = 2,
		LightShadowsLowQuality = 32 }},
	{ value = "Medium (PS4,XboxOne)", text = Untranslated("*Medium (PS4,XboxOne)"), hr = {
		Shadowmap = 1,
		ShadowmapSize = 2048,
		ShadowPCFSize = 2,
		ShadowCSMProjectionFit = 2,
		ShadowCSMResolutionPercent = -50,
		ShadowReceiversRatio = 1,
		ShadowSDSMEnable = 1,
		ShadowCSMUpdateFrequency = "0",
		LightShadows = 0,
		LightShadowsSize = 0 }, not_selectable = Platform.pc and not Platform.developer },
	{ value = "Medium", text = T(955331005438, --[[options:Shadows quality is set to Medium]] "Medium"), hr = {
		Shadowmap = 1,
		ShadowmapSize = 2048,
		ShadowPCFSize = 2,
		ShadowCSMProjectionFit = 2,
		ShadowCSMResolutionPercent = -50,
		ShadowReceiversRatio = 1,
		ShadowSDSMEnable = 1,
		ShadowCSMUpdateFrequency = "0",
		LightShadows = 1,
		LightShadowsSize = 2048,
		LightShadowsHighQuality = 8,
		LightShadowsLowQuality = 32 }},
	{ value = "High", text = T(875151214288, --[[options:Shadows quality is set to High]] "High"), hr = {
		Shadowmap = 1,
		ShadowmapSize = 4096,
		ShadowPCFSize = 3,
		ShadowCSMProjectionFit = 2,
		ShadowCSMResolutionPercent = 0,
		ShadowReceiversRatio = 100,
		ShadowSDSMEnable = 1,
		ShadowCSMUpdateFrequency = "0",
		LightShadows = 1,
		LightShadowsSize = 4096,
		LightShadowsHighQuality = 8,
		LightShadowsLowQuality = 128 }},
	{ value = "High (PS4Pro)", text = Untranslated("*High (PS4Pro)"), hr = {
		Shadowmap = 1,
		ShadowmapSize = 4096,
		ShadowPCFSize = 3,
		ShadowCSMProjectionFit = 2,
		ShadowCSMResolutionPercent = -50,
		ShadowReceiversRatio = 1,
		ShadowSDSMEnable = 1,
		ShadowCSMUpdateFrequency = "0",
		LightShadows = 0,
		LightShadowsSize = 0 }, not_selectable = Platform.pc and not Platform.developer },
	{ value = "Ultra", text = T(3551, --[[options:Shadows quality is set to Ultra]] "Ultra"), hr = {
		Shadowmap = 1,
		ShadowmapSize = 6144,
		ShadowPCFSize = 3,
		ShadowCSMProjectionFit = 2,
		ShadowCSMResolutionPercent=0,
		ShadowReceiversRatio = 100,
		ShadowSDSMEnable = 1,
		ShadowCSMUpdateFrequency = "0",
		LightShadows = 1,
		LightShadowsSize = 8192,
		LightShadowsHighQuality = 8,
		LightShadowsLowQuality = 128 }},
}

---
--- Resolves the appropriate anti-aliasing option based on the provided `antialiasing` value.
---
--- If the `antialiasing` value is "TAA" (Temporal Anti-Aliasing), this function will find the next best anti-aliasing option that uses the same resolution upscale method as TAA.
---
--- @param antialiasing string The anti-aliasing value to resolve.
--- @return string The resolved anti-aliasing option.
---
function ResolveAntialiasingOption(antialiasing)
	-- Implementation details
end
local function ResolveAntialiasingOption(antialiasing)
	if antialiasing == "TAA" then
		local antialiasing_option = table.find_value(OptionsData.Options.Antialiasing, "value", antialiasing)
		local antialiasing_index = table.findfirst(OptionsData.Options.Antialiasing, function(idx, item)
			return item.value ~= antialiasing_option.value and item.hr.ResolutionUpscale == antialiasing_option.hr.ResolutionUpscale
		end)
		return OptionsData.Options.Antialiasing[antialiasing_index].value
	end
	return antialiasing
end

---
--- Determines if the provided `antialiasing_value` is a temporal anti-aliasing option.
---
--- This function is used to check if the current anti-aliasing option uses a temporal resolution upscale method, such as DLSS, FSR2, or XESS.
---
--- @param antialiasing_value string The anti-aliasing value to check.
--- @return boolean True if the anti-aliasing option uses a temporal resolution upscale method, false otherwise.
---
function NotSelectableTemporalUpscalingOption(self, options_obj)
	return ResolveAntialiasingOption(options_obj.Antialiasing) ~= self.value
end
local function NotSelectableTemporalUpscalingOption(self, options_obj)
	return ResolveAntialiasingOption(options_obj.Antialiasing) ~= self.value
end

---
--- Determines if the provided `antialiasing_value` is a temporal anti-aliasing option.
---
--- This function is used to check if the current anti-aliasing option uses a temporal resolution upscale method, such as DLSS, FSR2, or XESS.
---
--- @param antialiasing_value string The anti-aliasing value to check.
--- @return boolean True if the anti-aliasing option uses a temporal resolution upscale method, false otherwise.
---
function IsTemporalAntialiasingOption(antialiasing_value)
	local antialiasing_option = table.find_value(OptionsData.Options.Antialiasing, "value", antialiasing_value)
	local method = antialiasing_option.hr.ResolutionUpscale
	return method and hr.IsTemporalResolutionUpscale(method)
end

---
--- Defines the available upscaling options for the game.
---
--- The `Upscaling` table contains a list of upscaling options that can be used to improve the game's resolution and image quality. Each option has a `value`, `text`, `hr`, and `not_selectable` field.
---
--- The `value` field is the unique identifier for the upscaling option.
--- The `text` field is the display name for the upscaling option.
--- The `hr` field contains hardware-related settings for the upscaling option.
--- The `not_selectable` field is a function that determines if the upscaling option should be selectable based on the current anti-aliasing option.
---
--- The available upscaling options are:
--- - "Off": Turns off upscaling.
--- - "DLSS": NVIDIA DLSS 2, a temporal upscaling technique.
--- - "FSR2": AMD FidelityFX Super Resolution 2, a temporal upscaling technique.
--- - "XESS": Intel XeSS, a temporal upscaling technique.
--- - "FSR": AMD FidelityFX Super Resolution 1.0, a spatial upscaling technique.
--- - "Bilinear": A simple bilinear upscaling filter.
---
--- The `NotSelectableTemporalUpscalingOption` function is used to determine if a temporal upscaling option should be selectable based on the current anti-aliasing option.
---
--- The `IsTemporalAntialiasingOption` function is used to determine if the current anti-aliasing option uses a temporal resolution upscale method.
---
OptionsData.Options.Upscaling = {
	{ value = "Off", text = T(392695272733, --[[options:Upscaling is turned off]] "Off"), hr = { ResolutionUpscale = "none" }, not_selectable = true },
	{ value = "DLSS", text = Untranslated("NVIDIA DLSS 2"), not_selectable = NotSelectableTemporalUpscalingOption,
		help_text = T(727329502546, "This option is forced based on the current anti-aliasing option.") },
	{ value = "FSR2", text = Untranslated("AMD FSR 2"), not_selectable = NotSelectableTemporalUpscalingOption,
		help_text = T(727329502546, "This option is forced based on the current anti-aliasing option.") },
	{ value = "XESS", text = Untranslated("Intel XeSS"), not_selectable = NotSelectableTemporalUpscalingOption,
		help_text = T(727329502546, "This option is forced based on the current anti-aliasing option.") },
	{ value = "FSR", text = Untranslated("AMD FSR 1.0"), hr = { ResolutionUpscale = "fsr" },
		not_selectable = function(self, options_obj) return IsTemporalAntialiasingOption(options_obj.Antialiasing) end,
		help_text = T(237540095950, "AMD FidelityFX Super Resolution 1.0 is a cutting edge super-optimized spatial upscaling technology that produces impressive image quality at fast framerates.") },
	{ value = "Bilinear", text = T(663907815524, --[[options:Bilinear upscaling method]] "Bilinear"), hr = { ResolutionUpscale = "none", },
		not_selectable = function(self, options_obj) return IsTemporalAntialiasingOption(options_obj.Antialiasing) end,
		help_text = T(168111358410, "The final image is upscaled using a quick bilinear filter.") },
}

---
--- Defines the available resolution percentage options for the game.
---
--- The `ResolutionPercent` table contains a list of resolution percentage options that can be used to adjust the game's resolution. Each option has a `value`, `text`, `hr`, and `not_selectable` field.
---
--- The `value` field is the unique identifier for the resolution percentage option.
--- The `text` field is the display name for the resolution percentage option.
--- The `hr` field contains hardware-related settings for the resolution percentage option.
--- The `not_selectable` field is a function that determines if the resolution percentage option should be selectable based on the current anti-aliasing option.
---
--- The available resolution percentage options are:
--- - "100": Native resolution (100%)
--- - "77": Ultra Quality (77%)
--- - "67": Quality (67%)
--- - "59": Balanced (59%)
--- - "50": Performance (50%)
--- - "33": Ultra Performance (33%)
---
--- The `not_selectable` function is used to determine if a resolution percentage option should be selectable based on the current anti-aliasing option. For example, the "33%" option is not selectable if the current anti-aliasing option is not a temporal upscaling method, or if the anti-aliasing option is "XESS".
---
OptionsData.Options.ResolutionPercent = {
	{ value = "100", text = T(372575555234, --[[options:Resolution percent 100%]] "Native (<percent(100)>)"), hr = { ResolutionPercent = 100, },
		not_selectable = function(self, options_obj) return options_obj.Antialiasing == "XESS" end, },
	{ value = "77", text = T(908658168865, --[[options:Resolution percent 77%]] "Ultra Quality (<percent(77)>)"), hr = { ResolutionPercent = 77, }, },
	{ value = "67", text = T(924914589055, --[[options:Resolution percent 67%]] "Quality (<percent(67)>)"), hr = { ResolutionPercent = 67, }, },
	{ value = "59", text = T(359371270894, --[[options:Resolution percent 59%]] "Balanced (<percent(59)>)"), hr = { ResolutionPercent = 59, }, },
	{ value = "50", text = T(326717026030, --[[options:Resolution percent 50%]] "Performance (<percent(50)>)"), hr = { ResolutionPercent = 50, }, },
	{ value = "33", text = T(243189993265, --[[options:Resolution percent 33%]] "Ultra Performance (<percent(33)>)"), hr = { ResolutionPercent = 33, },
		not_selectable = function(self, options_obj) return not IsTemporalAntialiasingOption(options_obj.Antialiasing) or options_obj.Antialiasing == "XESS" end, },
}

---
--- Defines the available anti-aliasing options for the game.
---
--- The `Antialiasing` table contains a list of anti-aliasing options that can be used to improve the visual quality of the game. Each option has a `value`, `text`, `hr`, `not_selectable`, and `help_text` field.
---
--- The `value` field is the unique identifier for the anti-aliasing option.
--- The `text` field is the display name for the anti-aliasing option.
--- The `hr` field contains hardware-related settings for the anti-aliasing option.
--- The `not_selectable` field is a function that determines if the anti-aliasing option should be selectable based on the current resolution percentage option.
--- The `help_text` field provides a description of the anti-aliasing option.
---
--- The available anti-aliasing options are:
--- - "Off": Disables anti-aliasing.
--- - "FXAA": Fast Approximate Anti-Aliasing, a high-performance and high-quality screen-space software approximation to anti-aliasing.
--- - "SMAA": Enhanced Subpixel Morphological Anti-Aliasing, an image-based, post-processing anti-aliasing technique.
--- - "TAA": Automatically picks a temporal anti-aliasing technique based on the machine's GPU.
--- - "DLSS": NVIDIA DLSS uses AI Super Resolution to provide the highest possible frame rates at maximum graphics settings. DLSS requires an NVIDIA RTX graphics card.
--- - "FSR2": AMD FidelityFX Super Resolution 2, a cutting-edge temporal upscaling algorithm that produces high resolution frames from lower resolution inputs.
--- - "XESS": Intel Xe Super Sampling (XeSS) technology uses machine learning to deliver higher performance with exceptional image quality.
---
OptionsData.Options.Antialiasing = {
	{ value = "Off", text = T(392695272733, --[[options:Antialiasing is turned off]] "Off"), hr = { EnablePostProcAA = 0, } },
	{ value = "FXAA", text = Untranslated("FXAA"), hr = { EnablePostProcAA = 1 },
		help_text = T(261152948496, "Fast Approximate Anti-Aliasing (FXAA) is a high performance and high quality screen-space software approximation to anti-aliasing.") },
	{ value = "SMAA", text = Untranslated("SMAA"), hr = { EnablePostProcAA = 2 },
		help_text = T(941529887409, "Enhanced Subpixel Morphological Anti-Aliasing (SMAA) is an image-based, post-processing anti-aliasing technique.") },
	{ value = "TAA",
		text = Untranslated("TAA"), hr = empty_table,
		not_selectable = function(self) return self.hr == empty_table end,
		help_text = T(872180326804, "Automatically picks a temporal anti-aliasing technique based on the machine's GPU.") },
	{ value = "DLSS",
		text = T{629765447024, "<name>", name = function() return Untranslated(OptionsObj and OptionsObj.ResolutionPercent == "100" and "NVIDIA DLAA 2" or "NVIDIA DLSS 2") end},
		hr = { ResolutionUpscale = "dlss" },
		not_selectable = function(self) return not hr.TemporalIsTypeSupported(self.hr.ResolutionUpscale) end,
		help_text = T(931850450677, "NVIDIA DLSS uses AI Super Resolution to provide the highest possible frame rates at maximum graphics settings. DLSS requires an NVIDIA RTX graphics card.") },
	{ value = "FSR2",
		text = Untranslated("AMD FSR 2"),
		hr = { ResolutionUpscale = "fsr2" },
		not_selectable = function(self) return not hr.TemporalIsTypeSupported(self.hr.ResolutionUpscale) end,
		help_text = T(266757012718, "AMD FidelityFX Super Resolution 2 is a cutting-edge temporal upscaling algorithm that produces high resolution frames from lower resolution inputs.") },
	{ value = "XESS",
		text = Untranslated("Intel XeSS"),
		hr = { ResolutionUpscale = "xess" },
		not_selectable = function(self) return not hr.TemporalIsTypeSupported(self.hr.ResolutionUpscale) end,
		help_text = T(825363827167, "Intel Xe Super Sampling (XeSS) technology uses machine learning to deliver higher performance with exceptional image quality.") },
}

---
--- Defines the available anisotropic filtering options for the game.
---
--- The `Anisotropy` table contains a list of anisotropic filtering options that can be used to improve the visual quality of textures. Each option has a `value`, `text`, and `hr` field.
---
--- The `value` field is the unique identifier for the anisotropic filtering option.
--- The `text` field is the display name for the anisotropic filtering option.
--- The `hr` field contains hardware-related settings for the anisotropic filtering option.
---
--- The available anisotropic filtering options are:
--- - "Off": Disables anisotropic filtering.
--- - "2x": Enables 2x anisotropic filtering.
--- - "4x": Enables 4x anisotropic filtering.
--- - "8x": Enables 8x anisotropic filtering.
--- - "16x": Enables 16x anisotropic filtering.
---
OptionsData.Options.Anisotropy = {
	{ value = "Off", text = T(692210423102, --[[options:Anisotropy is turned off]] "Off"), hr = { Anisotropy = 0 } },
	{ value = "2x", text = Untranslated("2x"), hr = { Anisotropy = 1 } },
	{ value = "4x", text = Untranslated("4x"), hr = { Anisotropy = 2 } },
	{ value = "8x", text = Untranslated("8x"), hr = { Anisotropy = 3 } },
	{ value = "16x", text = Untranslated("16x"), hr = { Anisotropy = 4 } },
}

---
--- Defines the available lighting options for the game.
---
--- The `Lights` table contains a list of lighting options that can be used to adjust the visual quality and performance of lights in the game. Each option has a `value`, `text`, and `hr` field.
---
--- The `value` field is the unique identifier for the lighting option.
--- The `text` field is the display name for the lighting option.
--- The `hr` field contains hardware-related settings for the lighting option.
---
--- The available lighting options are:
--- - "Low": Reduces the radius of lights by 90%.
--- - "Medium": Reduces the radius of lights by 95%.
--- - "High": Uses the full radius of lights.
---
OptionsData.Options.Lights = {
	{ value = "Low", text = T(709410953049, --[[options:Lights are turned to Low]] "Low"), hr = { LightsRadiusModifier = 90 } },
	{ value = "Medium", text = T(943866004028, --[[options:Lights are turned to Medium]] "Medium"), hr = { LightsRadiusModifier = 95} },
	{ value = "High", text = T(364201072641, --[[options:Lights are turned to High]] "High"), hr = { LightsRadiusModifier = 100 } },
}

---
--- Defines the available object detail options for the game.
---
--- The `ObjectDetail` table contains a list of object detail options that can be used to adjust the visual quality and performance of objects in the game. Each option has a `value`, `SortKey`, `text`, and `hr` field.
---
--- The `value` field is the unique identifier for the object detail option.
--- The `SortKey` field is used to sort the options in the UI.
--- The `text` field is the display name for the object detail option.
--- The `hr` field contains hardware-related settings for the object detail option.
---
--- The available object detail options are:
--- - "Very Low": Reduces object LOD, optionals, and eye candies to a minimum.
--- - "Low": Reduces object LOD, optionals, and eye candies moderately.
--- - "Medium": Reduces object LOD, optionals, and eye candies less aggressively.
--- - "High": Uses the full object LOD, optionals, and eye candies.
---
OptionsData.Options.ObjectDetail = {
	{ value = "Very Low", SortKey = 1000, text = T(717573023955, --[[options:Object detail is turned to Very Low]] "Very Low"),
		ObjectLODPercents = 50, Optionals = 50, EyeCandies = 0,
		hr = { ObjectLODCapMin = 1, LightShadowsDetailLevel = 0, LightShadowsMinContribDistance = 0, ClutterDetail = 0.0, UpdatedInstancesBudget = -1, BillboardDirectionsMaxDistance = 0,
			AnimUpdateF_Dist0 = 150000, AnimUpdateF_Dist1 = 600000, },
	},
	{ value = "Low", SortKey = 2000, text = T(215633457448, --[[options:Object detail is turned to Low]] "Low"),
		ObjectLODPercents = 50, Optionals = 50, EyeCandies = 33,
		hr = { ObjectLODCapMin = 0, LightShadowsDetailLevel = 1, LightShadowsMinContribDistance = 40, ClutterDetail = 0.25, UpdatedInstancesBudget = -1, BillboardDirectionsMaxDistance = 400,
			AnimUpdateF_Dist0 = 200000, AnimUpdateF_Dist1 = 800000, },
	},
	{ value = "Medium", SortKey = 3000, text = T(679289081998, --[[options:Object detail is turned to Medium]] "Medium"),
		ObjectLODPercents = 75, Optionals = 75, EyeCandies = 66,
		hr = { ObjectLODCapMin = 0, LightShadowsDetailLevel = 2, LightShadowsMinContribDistance = 60, ClutterDetail = 0.50, UpdatedInstancesBudget = -1, BillboardDirectionsMaxDistance = 600,
			AnimUpdateF_Dist0 = 300000, AnimUpdateF_Dist1 = 900000, },
	},
	{ value = "High", SortKey = 4000, text = T(564085803851, --[[options:Object detail is turned to High]] "High"),
		ObjectLODPercents = 100,  Optionals = 100, EyeCandies = 100,
		hr = { ObjectLODCapMin = 0, LightShadowsDetailLevel = 3, LightShadowsMinContribDistance = 100, ClutterDetail = 1.0, UpdatedInstancesBudget = -1, BillboardDirectionsMaxDistance = 750,
			AnimUpdateF_Dist0 = 500000, AnimUpdateF_Dist1 = 2000000, },
	},
}

---
--- Defines the available postprocessing options for the game.
---
--- The `Postprocess` table contains a list of postprocessing options that can be used to adjust the visual quality and performance of postprocessing effects in the game. Each option has a `value`, `text`, and `hr` field.
---
--- The `value` field is the unique identifier for the postprocessing option.
--- The `text` field is the display name for the postprocessing option.
--- The `hr` field contains hardware-related settings for the postprocessing option.
---
--- The available postprocessing options are:
--- - "Low": Reduces the quality of postprocessing effects.
--- - "Medium": Uses a medium quality level for postprocessing effects.
--- - "High": Uses a high quality level for postprocessing effects.
--- - "Ultra": Uses the highest quality level for postprocessing effects.
---
OptionsData.Options.Postprocess = {
	{ value = "Low", text = T(432248124587, --[[options:Postprocessing is turned to Low]] "Low"), hr = { SAOQuality = 0, SAOMipBase = 2 } },
	{ value = "Medium", text = T(550662244805, --[[options:Postprocessing is turned to Medium]] "Medium"), hr = { SAOQuality = 0, SAOMipBase = 1, } },
	{ value = "High", text = T(157332897114, --[[options:Postprocessing is turned to High]] "High"), hr = { SAOQuality = 1, SAOMipBase = 1, } },
	{ value = "Ultra", text = T(591239139006, --[[options:Postprocessing is turned to Ultra]] "Ultra"), hr = { SAOQuality = 2, SAOMipBase = 0, } },
}

---
--- Defines the available sharpness options for the game.
---
--- The `Sharpness` table contains a list of sharpness options that can be used to adjust the visual quality and performance of the sharpness effect in the game. Each option has a `value`, `text`, and `hr` field.
---
--- The `value` field is the unique identifier for the sharpness option.
--- The `text` field is the display name for the sharpness option.
--- The `hr` field contains hardware-related settings for the sharpness option.
---
--- The available sharpness options are:
--- - "Off": Disables the sharpness effect.
--- - "Low": Applies a low level of sharpness.
--- - "Medium": Applies a medium level of sharpness.
--- - "High": Applies a high level of sharpness.
---
OptionsData.Options.Sharpness = {
	{ value = "Off", text = T(571191621995, --[[options:Sharpness is turned Off]] "Off"), hr = { Sharpness = 0 } },
	{ value = "Low", text = T(291279322471, --[[options:Sharpness is turned to Low]] "Low"), hr = { Sharpness = 0.2 } },
	{ value = "Medium", text = T(548203462360, --[[options:Sharpness is turned to Medium]] "Medium"), hr = { Sharpness = 0.5 } },
	{ value = "High", text = T(213880173168, --[[options:Sharpness is turned to High]] "High"), hr = { Sharpness = 0.8 } },
}

---
--- Defines the available options categories for the game.
---
--- The `OptionsCategories` table contains a list of options categories that can be used to group and organize the various options available in the game. Each category has an `id`, `display_name`, `caps_name`, and optional `no_edit` and `run` fields.
---
--- The `id` field is the unique identifier for the options category.
--- The `display_name` field is the display name for the options category.
--- The `caps_name` field is the capitalized display name for the options category.
--- The `no_edit` field is an optional function that returns a boolean indicating whether the options category should be hidden from the user interface.
--- The `run` field is an optional function that is called when the options category is selected.
---
--- The available options categories are:
--- - "Display": Adjusts display-related settings.
--- - "Video": Adjusts video-related settings.
--- - "Audio": Adjusts audio-related settings.
--- - "Controls": Adjusts control-related settings.
--- - "Gameplay": Adjusts gameplay-related settings.
--- - "Keybindings": Adjusts keybinding-related settings.
--- - "ModOptions": Adjusts mod-related settings.
--- - "ChangeUser": Allows the user to change their profile.
--- - "Credits": Displays the game's credits.
---
OptionsCategories = {
	{id = "Display",     display_name = T(412409389789, "Display"),        caps_name = T(517337015408, "DISPLAY"), no_edit = Platform.console and Platform.goldmaster, },
	{id = "Video",       display_name = T(255390845026, "Video"),          caps_name = T(325469437176, "VIDEO")},
	{id = "Audio",       display_name = T(973319776875, "Audio"),          caps_name = T(278460229053, "AUDIO")},
	{id = "Controls",    display_name = T(437489721989, "Controls"),       caps_name = T(431903983139, "CONTROLS")},
	{id = "Gameplay",    display_name = T(350787334289, "Gameplay"),       caps_name = T(858632259775, "GAMEPLAY")},
	{id = "Keybindings", display_name = T(867036363190, "Key Bindings"),   caps_name = T(852769320242, "KEY BINDINGS"), 
		no_edit = function() return Platform.console end, },
	{id = "ModOptions",  display_name = T(454731851212, "Mod Options"),             caps_name = T(655539268008, "MOD OPTIONS"), 
		no_edit = function() return not config.Mods or not HasModsWithOptions() end },
	{id = "ChangeUser",  display_name = T(173037664401, "Change Profile"), caps_name = T(584707216514, "CHANGE PROFILE"), 
		no_edit = function() return HideChangeUserCategory() or not (Platform.xbox or Platform.windows_store) or GameState.gameplay end, 
		run = function() CreateRealTimeThread(function() if Platform.xbox then XboxChangeProfile() else WindowsStoreSignInUser() end end) end, },
	{id = "Credits",     display_name = T(283802894796, "Credits"),           caps_name = T(465539577876, "CREDITS"),
		no_edit = function() return GameState.gameplay or HideCreditsInOptions() end,},
}

---
--- Determines whether the "Change Profile" options category should be hidden.
---
--- @return boolean
---   Returns `true` if the "Change Profile" options category should be hidden, `false` otherwise.
function HideChangeUserCategory()
	return false
end

---
--- Determines whether the credits should be hidden in the options menu.
---
--- @return boolean
---   Returns `true` if the credits should be hidden in the options menu, `false` otherwise.
function HideCreditsInOptions()
	return false
end

---
--- Applies the user's account options.
---
--- This function calls `ApplyProjectAccountOptions()` to apply any project-specific account options.
---
--- @function ApplyAccountOptions
--- @return nil
function ApplyAccountOptions()
	Msg("ApplyAccountOptions")
	ApplyProjectAccountOptions()
end

---
--- Applies any project-specific account options.
---
--- This function is a placeholder that must be overridden in the project-specific `ProjectOptions.lua` file.
---
function ApplyProjectAccountOptions()
end

---
--- Applies map-specific engine settings.
---
--- This function is a placeholder that must be overridden in the project-specific code to tweak engine options per map.
---
function ApplyMapEngineSettings(map)
end


---
--- Applies the user's account options and regenerates the clutter.
---
--- This function is called when the options are applied. It calls `ApplyAccountOptions()` to apply the user's account options, and then calls `clutter.Regenerate()` to regenerate the clutter.
---
--- @function OnMsg.OptionsApply
--- @return nil
function OnMsg.OptionsApply()
	ApplyAccountOptions()
	clutter.Regenerate()
end

OnMsg.AccountStorageChanged = ApplyAccountOptions

---
--- Returns the name of the current object detail setting.
---
--- @return string
---   The name of the current object detail setting.
function GetObjectDetailsName()
	OptionsObj = OptionsObj or OptionsCreateAndLoad()
	return OptionsObj.ObjectDetail
end

---
--- Sets the object detail level for the current map.
---
--- This function is used to set the object detail level for the current map. It updates the `hr` table with the appropriate values for the specified detail level, and hides objects based on the optional and eye candy settings for that detail level.
---
--- @param details string
---   The name of the object detail level to set.
--- @param all_hrs boolean
---   If true, all high-resolution values are set. If false, only the light shadows detail level is set.
--- @param dont_apply_filters boolean
---   If true, the editor filters are not applied after setting the object detail.
--- @return number, number
---   The percentage of optional objects and eye candy objects that are hidden, respectively.
function SetObjectDetail(details, all_hrs, dont_apply_filters)
	local on_map = (GetMap() ~= "")
	
	if on_map then
		SuspendPassEdits("SetObjectDetail")
	end
	
	local params = {}
	Msg("SetObjectDetail", "init", params)
	
	local entry = table.find_value(OptionsData.Options.ObjectDetail, "value", details)
	if all_hrs then
		for hr_name, hr_value in pairs(entry.hr) do
			hr[hr_name] = hr_value
		end
	else
		hr.LightShadowsDetailLevel = entry.hr.LightShadowsDetailLevel
	end
	
	if on_map then
		HideObjectsByDetailClass(entry.Optionals, 100, entry.EyeCandies)

		if not dont_apply_filters and IsEditorActive() then
			XEditorFiltersApply()
		end
	end
	
	Msg("SetObjectDetail", "done", params)	
	
	if on_map then
		ResumePassEdits("SetObjectDetail")
	end
	
	return entry.Optionals, entry.EyeCandies
end

---
--- Sets the object detail level for the current map.
---
--- This function is used to set the object detail level for the current map. It updates the `EngineOptions.ObjectDetail` table with the appropriate values for the specified detail level, saves the engine options, saves the account storage, and hides objects based on the optional and eye candy settings for that detail level. It also prints information about the object details, optionals, eye candies, and lights.
---
--- @param details string
---   The name of the object detail level to set.
--- @param dont_apply_filters boolean
---   If true, the editor filters are not applied after setting the object detail.
function EngineSetObjectDetail(details, dont_apply_filters)
	if EngineOptions.ObjectDetail == details then return end
	
	EngineOptions.ObjectDetail = details
	SaveEngineOptions()
	SaveAccountStorage(5000)
	local optionals, eye_candies = SetObjectDetail(EngineOptions.ObjectDetail, "all hrs", dont_apply_filters)
	Msg("GameOptionsChanged", "Video")
	print(string.format("Object details: %s, Optionals: %d%%, Eye candies: %d%%, Lights: %d",
		EngineOptions.ObjectDetail, optionals, eye_candies, #GetLights()
	))
	XEditorUpdateStatusText()
end

local s_PreSaveMapDetails = false

---
--- Saves the current object detail level and sets the detail level to "High" before saving the map.
---
--- This function is called before the map is saved. It checks the current object detail level and if it is not "High", it saves the current detail level in `s_PreSaveMapDetails` and sets the detail level to "High" with the `"dont_apply_filters"` option. This ensures that the map is saved with the highest object detail level, regardless of the current setting.
---
--- After the map is saved, the `OnMsg.PostSaveMap()` function is called, which restores the original object detail level from `s_PreSaveMapDetails`.
---
--- @function OnMsg.PreSaveMap
--- @return nil
function OnMsg.PreSaveMap()
	local current_details = GetObjectDetailsName()
	if current_details ~= "High" then
		s_PreSaveMapDetails = current_details
		SetObjectDetail("High", nil, "dont_apply_filters")
	end
end

---
--- Restores the original object detail level after the map is saved.
---
--- This function is called after the map is saved. It checks if the `s_PreSaveMapDetails` variable is set, which indicates that the object detail level was changed before saving the map. If so, it restores the original object detail level using the `SetObjectDetail` function with the `"dont_apply_filters"` option.
---
--- @function OnMsg.PostSaveMap
--- @return nil
function OnMsg.PostSaveMap()
	if s_PreSaveMapDetails then
		SetObjectDetail(s_PreSaveMapDetails, nil, "dont_apply_filters")
		s_PreSaveMapDetails = false
	end
end

---
--- Called after a new map is loaded. This function sets the object detail level to the current setting.
---
--- This function is called as a game time thread, which ensures that it runs after the map has finished loading. It sets the object detail level to the current setting using the `SetObjectDetail` function.
---
--- @function OnMsg.PostNewMapLoaded
--- @return nil
function OnMsg.PostNewMapLoaded()
	CreateGameTimeThread(function()
		SetObjectDetail(GetObjectDetailsName(), "all hrs")
	end)
end

---
--- Changes the game language based on the user's account settings.
---
--- This function checks if the platform is a console, and if so, returns without doing anything. Otherwise, it retrieves the user's selected language from the account storage, sets the language using `SetLanguage()`, saves the language option permanently in the registry, mounts the language, loads the translation tables, and initializes the Windows IME state.
---
--- @function ApplyLanguageOption
--- @return nil
function ApplyLanguageOption()
	--cannot change language on consoles
	if Platform.console then
		return
	end
	local new_lang = GetAccountStorageOptionValue("Language")
	if SetLanguage(new_lang) then --set global variable
		SaveLanguageOption(GetLanguage()) --save permanently the result in the registry (e.g. "Auto" would be resolved into a specific lang)
		MountLanguage()
		LoadTranslationTables() --reload loc table
		InitWindowsImeState()
	end
end

---
--- Applies the specified brightness value to the display.
---
--- This function sets the display gamma value based on the provided brightness value. If no brightness value is provided, it uses the value from the `EngineOptions.Brightness` setting.
---
--- @param val number|nil The brightness value to apply, or `nil` to use the value from `EngineOptions.Brightness`.
--- @return nil
function ApplyBrightness(val)
	val = val or EngineOptions.Brightness
	if val then
		hr.DisplayGamma = 1500 - val
	end
end

---
--- Updates the UI style based on whether a gamepad is connected.
---
--- This function checks if a gamepad is connected and updates the UI style accordingly. If a gamepad is connected or the platform is a console, the UI style is set to gamepad mode. Otherwise, the UI style is set to non-gamepad mode.
---
--- @param gamepad boolean|nil Whether a gamepad is connected. If not provided, the function will automatically detect if a gamepad is connected.
--- @return nil
function UpdateUIStyleGamepad(gamepad)
	gamepad = gamepad and (Platform.console or IsXInputControllerConnected())
	ChangeGamepadUIStyle({ [1] = gamepad })
end

---
--- Applies the user's account options related to the UI style and gamepad usage.
---
--- This function checks if the user's account storage is available, and if so, it retrieves the user's gamepad setting and updates the UI style accordingly using `UpdateUIStyleGamepad()`. If the account storage is not available, it defaults to using the platform's console setting to determine the UI style.
---
--- @function OnMsg.ApplyAccountOptions
--- @return nil
function OnMsg.ApplyAccountOptions()
	if AccountStorage then
		UpdateUIStyleGamepad(GetAccountStorageOptionValue("Gamepad"))
	else
		UpdateUIStyleGamepad(not not Platform.console)
	end
end

---
--- Gets the display area margin based on the platform.
---
--- On PlayStation platforms, this function calculates the display area margin based on the safe area and screen size. On other platforms, it returns the value from the `EngineOptions.DisplayAreaMargin` setting, or 0 if the setting is not available.
---
--- @return number The display area margin
function GetDisplayAreaMargin()
	if Platform.playstation then
		local safe_w, safe_h = UIL.GetSafeArea()
		
		local screen_size = UIL.GetScreenSize()
		local screen_w, screen_h = screen_size:xy()
		local margin = MulDivRound(safe_w, 100, screen_w)
		
		return margin
	else
		return EngineOptions and EngineOptions.DisplayAreaMargin or 0
	end
end