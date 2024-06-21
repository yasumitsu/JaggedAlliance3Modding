--- Initializes global variables `g_FirstTimeUser` and `g_LocalStorageFile` based on the `FirstLoad` flag.
-- If `FirstLoad` is true, `g_FirstTimeUser` is set to false and `g_LocalStorageFile` is set to either "AppData/LocalStorageGed.lua" or "AppData/LocalStorage.lua" depending on the `Platform.ged` flag.
if FirstLoad then
    g_FirstTimeUser = false
    g_LocalStorageFile = "AppData/" .. (Platform.ged and "LocalStorageGed.lua" or "LocalStorage.lua")
end

-- All Set*Storage functions accept a table, or one of the strings "default" and "invalid"
--- Initializes a storage table with default values.
--
-- If `storage` is "invalid", it is set to `false`.
-- If `storage` is "default", it is set to an empty table.
-- Otherwise, `storage` is assumed to be a table and its values are set to the defaults in `default`.
-- If `default` has a metatable and `storage` does not have the same class, `storage` is converted to an object of the same class as `default`.
--
-- @param storage The storage table to initialize, or the string "default" or "invalid".
-- @param default The default values to use for initializing the storage table.
-- @return The initialized storage table.
local function InitWithDefault(storage, default)
    assert(storage)
    if storage == "invalid" then
        storage = false
    else
        if storage == "default" then
            storage = {}
        end
        assert(type(storage) == "table")
        -- Convert the storage from dumb table to object (if needed)
        if getmetatable(default) and not ObjectClass(storage) and ObjectClass(default) then
            storage = g_Classes[default.class]:new(storage)
        end
        table.set_defaults(storage, default, "deep")
    end
    return storage
end

--- Returns a table with default values for option fixup metadata.
--
-- The returned table has the following fields:
-- - `AppliedOptionFixups`: A table of applied option fixups.
-- - `last_applied_fixup_revision`: The revision of the last applied fixup.
--
-- @return A table with default option fixup metadata.
function GetDefaultOptionFixupMeta()
    return {AppliedOptionFixups={}, last_applied_fixup_revision=0}
end

--- Returns the default account options.
--
-- @return The default account options.
function GetDefaultAccountOptions()
    return DefaultAccountStorage.Options
end

--- Sets the platform-specific default engine options.
--
-- This function overrides the default engine options with platform-specific defaults.
-- The resulting options are stored in the `PlatformDefaultEngineOptions` global variable.
--
-- The platform-specific defaults are defined in the `DefaultEngineOptions` table, with keys
-- corresponding to the different platforms (e.g. "steamdeck", "desktop", "xbox_one", etc.).
-- This function checks the current platform and selects the appropriate platform-specific
-- defaults to overwrite the main default options.
--
-- @function SetPlatformDefaultEngineOptions
-- @return none
function SetPlatformDefaultEngineOptions()
    -- Overwrite default options with platform-specific defaults
    local result_options = table.copy(DefaultEngineOptions["default_options"])
    if Platform.steamdeck then
        table.overwrite(result_options, DefaultEngineOptions["steamdeck"])
    elseif Platform.desktop then
        table.overwrite(result_options, DefaultEngineOptions["desktop"])
    elseif Platform.xbox_one and not Platform.xbox_one_x then
        table.overwrite(result_options, DefaultEngineOptions["xbox_one"])
    elseif Platform.xbox_one and Platform.xbox_one_x then
        table.overwrite(result_options, DefaultEngineOptions["xbox_one_x"])
    elseif Platform.xbox_series and not Platform.xbox_series_x then
        table.overwrite(result_options, DefaultEngineOptions["xbox_series_s"])
    elseif Platform.xbox_series and Platform.xbox_series_x then
        table.overwrite(result_options, DefaultEngineOptions["xbox_series_x"])
    elseif Platform.ps4 and not Platform.ps4_pro then
        table.overwrite(result_options, DefaultEngineOptions["ps4"])
    elseif Platform.ps4 and Platform.ps4_pro then
        table.overwrite(result_options, DefaultEngineOptions["ps4_pro"])
    elseif Platform.ps5 then
        table.overwrite(result_options, DefaultEngineOptions["ps5"])
    elseif Platform.switch then
        table.overwrite(result_options, DefaultEngineOptions["switch"])
    end

    PlatformDefaultEngineOptions = result_options
end

--- Returns the default engine options for the current platform.
--
-- If `platform_overwrites_only` is true, this function will return only the platform-specific
-- overrides of the default engine options, instead of the full set of default options.
--
-- The platform-specific overrides are defined in the `DefaultEngineOptions` table, with keys
-- corresponding to the different platforms (e.g. "steamdeck", "desktop", "xbox_one", etc.).
--
-- @param platform_overwrites_only boolean Whether to return only the platform-specific overrides.
-- @return table The default engine options for the current platform.
function GetDefaultEngineOptions(platform_overwrites_only)
    if platform_overwrites_only then
        if Platform.steamdeck then
            return DefaultEngineOptions["steamdeck"]
        elseif Platform.desktop then
            return DefaultEngineOptions["desktop"]
        elseif Platform.xbox_one and not Platform.xbox_one_x then
            return DefaultEngineOptions["xbox_one"]
        elseif Platform.xbox_one and Platform.xbox_one_x then
            return DefaultEngineOptions["xbox_one_x"]
        elseif Platform.xbox_series and not Platform.xbox_series_x then
            return DefaultEngineOptions["xbox_series_s"]
        elseif Platform.xbox_series and Platform.xbox_series_x then
            return DefaultEngineOptions["xbox_series_x"]
        elseif Platform.ps4 and not Platform.ps4_pro then
            return DefaultEngineOptions["ps4"]
        elseif Platform.ps4 and Platform.ps4_pro then
            return DefaultEngineOptions["ps4_pro"]
        elseif Platform.ps5 then
            return DefaultEngineOptions["ps5"]
        elseif Platform.switch then
            return DefaultEngineOptions["switch"]
        end
    end

    return PlatformDefaultEngineOptions
end

--- Returns a table containing the full set of engine options, including both the default options and any
-- user-defined overrides stored in the `EngineOptions` table.
--
-- This function creates a copy of the default engine options using `GetDefaultEngineOptions()`, and then
-- merges any user-defined overrides from the `EngineOptions` table into the copy using `table.overwrite()`.
--
-- @return table The full set of engine options, including both defaults and user overrides.
function GetFullEngineOptions()
    local defaults = table.copy(GetDefaultEngineOptions())
    return table.overwrite(defaults, EngineOptions)
end

--- Returns a table containing the full set of account options, including both the default options and any
-- user-defined overrides stored in the `AccountStorage.Options` table.
--
-- This function creates a copy of the default account options using `GetDefaultAccountOptions()`, and then
-- merges any user-defined overrides from the `AccountStorage.Options` table into the copy using `table.overwrite()`.
--
-- @return table The full set of account options, including both defaults and user overrides.
function GetFullAccountOptions()
    local defaults = table.copy(GetDefaultAccountOptions())
    return table.overwrite(defaults, AccountStorage.Options)
end

--- Sets the default engine options as the metatable for the `EngineOptions` table.
--
-- This allows the `EngineOptions` table to use the default options as a fallback, so that only the
-- options with a different value than the default need to be stored on disk. Any missing options
-- in `EngineOptions` will automatically use the default value from `GetDefaultEngineOptions()`.
--
-- This is used to efficiently store and load the engine options, as the full set of options does
-- not need to be serialized.
function SetDefaultEngineOptionsMetaTable()
    setmetatable(EngineOptions, {__index=GetDefaultEngineOptions()})
end

--- Initializes the default engine options and sets up the metatable for the `EngineOptions` table.
--
-- This code block is executed on the first load of the file. It sets up the default engine options in the
-- `DefaultEngineOptions` table, which includes various video, audio, gameplay, and display settings.
--
-- The `DefaultEngineOptions` table also includes platform-specific overrides for certain settings, such as
-- resolution, fullscreen mode, and graphics API.
--
-- Additionally, this code sets up the metatable for the `EngineOptions` table, which allows the `EngineOptions`
-- table to use the default options as a fallback. This means that only the options with a different value than
-- the default need to be stored on disk, which improves efficiency when storing and loading the engine options.
if FirstLoad then
    --[[ 
	DefaultEngineOptions["default_options"] are the main engine option defaults. They are set 
	as a __index metatable to EngineOptions. This allows only the options with a different value
	than the default to be saved on disk while any missing option fallbacks to the default value.
	See SetDefaultEngineOptionsMetaTable().
	
	Some of the defaults (Display options mainly) are used very early to initialize the engine in
	InitRenderEngine() through LuaVars in the config. It's good to know that at that point only a 
	few lua files have been executed and there are no lua classes or game-specific options yet.
	
	The other keys in DefaultEngineOptions (other than "default_options") specify 
	platform-specific overwrites of the default values.
]]
    DefaultEngineOptions = {default_options={ -- Video
    VideoPreset="High", Antialiasing="TAA", Upscaling="Off", ResolutionPercent="100", Shadows="High", Textures="High",
    Anisotropy="4x", Terrain="High", Effects="High", Lights="High", Postprocess="High", Bloom="On", EyeAdaptation="On",
    Vignette="On", ChromaticAberration="On", SSAO="On", SSR="High", ViewDistance="High", ObjectDetail="High",
    FPSCounter="Off", Sharpness=const.DefaultSharpness or "Low", -- Audio
    MasterVolume=const.MasterDefaultVolume or 500, Music=const.MusicDefaultVolume or 300,
    Voice=const.VoiceDefaultVolume or 1000, Sound=const.SoundDefaultVolume or 650,
    Ambience=const.AmbienceDefaultVolume or 1000, UI=const.UIDefaultVolume or 1000, MuteWhenMinimized=true,
    RadioStation=const.MusicDefaultRadioStation or "", -- Gameplay
    CameraShake="On", -- Display
    FullscreenMode=0, Resolution=point(1920, 1080), Vsync=true, GraphicsApi=GetDefaultGraphicsApi(),
    GraphicsAdapterIndex=0, MaxFps="240", DisplayAreaMargin=0, UIScale=100, Brightness=500,

    -- Engine option fixup metadata
    fixups_meta=GetDefaultOptionFixupMeta()}, -- Platform overwrites
    desktop={Resolution=Platform.developer and point(1920, 1080) or false, FullscreenMode=Platform.developer and 0 or 1},
        xbox_one={Resolution=point(1920, 1080), FullscreenMode=1, Vsync=true, GraphicsApi="d3d12", VideoPreset="XboxOne"},
        xbox_one_x={Resolution=point(2560, 1440), FullscreenMode=1, Vsync=true, GraphicsApi="d3d12",
            VideoPreset="XboxOneX"},
        xbox_series_s={Resolution=point(2560, 1440), FullscreenMode=1, Vsync=true, GraphicsApi="d3d12",
            VideoPreset="XboxSeriesS"},
        xbox_series_x={Resolution=point(3840, 2160), FullscreenMode=1, Vsync=true, GraphicsApi="d3d12",
            VideoPreset="XboxSeriesXQuality"},
        ps4={Resolution=point(1920, 1080), FullscreenMode=1, Vsync=true, GraphicsApi="gnm", VideoPreset="PS4"},
        ps4_pro={Resolution=point(2240, 1260), FullscreenMode=1, Vsync=true, GraphicsApi="gnm", VideoPreset="PS4Pro"},
        ps5={Resolution=point(3840, 2160), FullscreenMode=1, Vsync=true, GraphicsApi="agc", VideoPreset="PS5Quality"},
        switch={Resolution=point(1280, 720), FullscreenMode=1, Vsync=true, FPSCounter="Off", UIScale=100,
            GraphicsApi="NVN", VideoPreset="Switch"},
        steamdeck={Resolution=false, FullscreenMode=1, MaxFps="30", UIScale=const.MaxUserUIScaleHighRes,
            VideoPreset="SteamDeck"}}

    -- Some additional settings are inited in options.lua
    DefaultAccountStorage = {Shortcuts={}, achievements={unlocked={}, progress={}, target={}}, tips={current_tip=0},
        Options={ -- Account
        Gamepad=(Platform.console or Platform.steamdeck) and true or false, -- Gameplay
        -- Subtitles = true,
        -- Colorblind = false,
        Language="Auto", -- Account option fixup metadata
        fixups_meta=GetDefaultOptionFixupMeta()}, LoadMods={}, PlayStationStartedActivities={}}

    DefaultLocalStorage = {id_old_rect={}, dlgBugReport={}, MovieRecord={}, editor={}, FilteredCategories={},
        LockedCategories={}}

    PlatformDefaultEngineOptions = {}
    SetPlatformDefaultEngineOptions()

    EngineOptions = {}
    SetDefaultEngineOptionsMetaTable()
end

---
--- Sets the account storage for the current session.
---
--- @param storage table The account storage to set.
---
function SetAccountStorage(storage)
    storage = InitWithDefault(storage, DefaultAccountStorage)
    AccountStorage = storage
    Msg("AccountStorageChanged")
end

---
--- Initializes the local storage for the application.
---
--- If the local storage file does not exist, it creates a new local storage table using the `DefaultLocalStorage` table.
--- If the local storage file exists, it reads the contents of the file and initializes the local storage table.
--- If the local storage table is empty or corrupted, it creates a new local storage table using the `DefaultLocalStorage` table.
--- If the local storage table contains developer settings, it moves them to a separate `Developer` table.
--- If the local storage table's `LuaRevision` is 0 and the platform is not in developer mode, it creates a new local storage table using the `DefaultLocalStorage` table.
---
--- @return table The initialized local storage table.
---
function InitLocalStorage()
end
local function InitLocalStorage()
    if not io.exists(g_LocalStorageFile) then
        return InitWithDefault("default", DefaultLocalStorage)
    end
    local fenv = LuaValueEnv()
    local t = dofile(g_LocalStorageFile, fenv)
    assert(not t or type(t) == "table")
    if not t then
        g_FirstTimeUser = true
    end
    t = InitWithDefault(t or "default", DefaultLocalStorage)
    -- move developer settings outside of options
    if t.Options and not t.Developer then
        t.Developer = {General=t.Options.General, EditorHiddenTextOptions=t.Options.EditorHiddenTextOptions,
            MapStartup=t.Options.MapStartup}
        t.Options.General = nil
        t.Options.EditorHiddenTextOptions = nil
        t.Options.MapStartup = nil
    end
    t.LuaRevision = t.LuaRevision or 0
    if not Platform.developer and t.LuaRevision == 0 then
        t = InitWithDefault("default", DefaultLocalStorage)
    end
    return t
end

---
--- Sets the account storage to `false` on first load.
---
--- This is likely used to initialize the account storage to a default value on the first run of the application.
---
if FirstLoad then
    AccountStorage = false
end

---
--- Saves the current engine options to the local storage file.
---
--- This function is responsible for persisting the current engine options to the local storage file. It first updates the `LuaRevision` field in the `LocalStorage` table, then generates a Lua code string representing the `LocalStorage` table and writes it to the local storage file asynchronously.
---
--- If the write operation fails, this function will print an error message and return `false` along with the error message. Otherwise, it will return `true`.
---
--- @return boolean, string? True if the save operation was successful, false and an error message if it failed.
---
function SaveEngineOptions()
    Msg("EngineOptionsSaved")
    return SaveLocalStorage()
end

---
--- Initializes the local storage for the application on first load.
---
--- This code block is executed when the application is loaded for the first time. It performs the following actions:
---
--- 1. Checks if the local storage file exists. If not, it initializes the local storage with the default values.
--- 2. Loads the local storage from the file and initializes it with the default values if necessary.
--- 3. Moves the developer settings outside of the options table.
--- 4. Sets the `LuaRevision` field in the local storage table.
--- 5. If the `LuaRevision` is 0 and the application is not in developer mode, it resets the local storage to the default values.
--- 6. Assigns the initialized local storage table to the `LocalStorage` global variable.
--- 7. Sets the `EngineOptions` global variable to the `Options` field of the `LocalStorage` table.
--- 8. Calls the `SetDefaultEngineOptionsMetaTable()` function to set the default metadata for the `EngineOptions` table.
---
if FirstLoad then
    DefaultLocalStorage.Options = EngineOptions
    LocalStorage = InitLocalStorage()
    EngineOptions = LocalStorage.Options
    SetDefaultEngineOptionsMetaTable()
end

---
--- Saves the current local storage table to the local storage file.
---
--- This function is responsible for persisting the current local storage table to the local storage file. It first updates the `LuaRevision` field in the `LocalStorage` table, then generates a Lua code string representing the `LocalStorage` table and writes it to the local storage file asynchronously.
---
--- If the write operation fails, this function will print an error message and return `false` along with the error message. Otherwise, it will return `true`.
---
--- @return boolean, string? True if the save operation was successful, false and an error message if it failed.
---
function SaveLocalStorage()
    LocalStorage.LuaRevision = LuaRevision

    local code = pstr("return ", 1024)
    TableToLuaCode(LocalStorage, nil, code)
    ThreadLockKey(g_LocalStorageFile)
    local err = AsyncStringToFile(g_LocalStorageFile, code, -2, 0)
    ThreadUnlockKey(g_LocalStorageFile)
    if err then
        print("once", "Failed to save a storage table to", g_LocalStorageFile, ":", err)
        return false, err
    end
    return true
end

---
--- Saves the local storage after a short delay.
---
--- This function is used to delay the saving of the local storage to avoid potential performance issues. It calls the `SaveLocalStorage()` function after a short delay of 0 seconds.
---
--- @return boolean, string? True if the save operation was successful, false and an error message if it failed.
---
function SaveLocalStorageDelayed()
    DelayedCall(0, SaveLocalStorage)
end
