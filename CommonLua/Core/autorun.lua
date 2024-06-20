---
--- Disables garbage collection during the loading process for better performance.
--- Sets the locale to "C" to standardize the behavior of upper/lower case functions.
--- This code is executed when the file is first loaded.
---
Loading = true

---
--- Sets the locale to "C" to standardize the behavior of upper/lower case functions.
---
os.setlocale("C") -- Standardize the upper/lower functions

-- no garbage collection during load for better performance
---
--- Disables garbage collection during the loading process for better performance.
---
collectgarbage("stop")

---
--- Initializes global variables and sets up the global table metatable.
---
--- This code is executed when the file is first loaded.
---
--- @field FirstLoad boolean True if this is the first time the file has been loaded.
--- @field ReloadForDlc boolean True if the file needs to be reloaded for a DLC.
--- @field LuaRevision number The current Lua revision.
--- @field OrgLuaRevision number The original Lua revision.
--- @field AssetsRevision number The current assets revision.
--- @field BuildVersion boolean The current build version.
--- @field BuildBranch boolean The current build branch.
--- @field PersistableGlobals table A table of global variables that can be persisted.
--- @field Loading boolean True if the loading process is in progress.
--- @field _ALERT number The alert level.
--- @field editor table The editor table, if it exists.
---
if FirstLoad == nil then
    FirstLoad = true
    ReloadForDlc = false
    LuaRevision = 0
    OrgLuaRevision = 0
    AssetsRevision = 0
    BuildVersion = false
    BuildBranch = false

    -- Set a metatable to the global table that doesn't allow access of undefined globals
    setmetatable(_G, {__index=function(table, key)
        -- allow testing IsKindOf(_G, "something")
        if key == "class" then
            return ""
        end
        if key == "__ancestors" then
            return empty_table
        end
        error("Attempt to use an undefined global '" .. tostring(key) .. "'", 1)
    end, __newindex=function(table, key, value)
        if not Loading and PersistableGlobals[key] == nil then
            error("Attempt to create a new global '" .. tostring(key) .. "'", 1)
        end
        rawset(table, key, value)
    end, __toluacode=function(value, indent)
        return indent and (indent .. "_G") or "_G"
    end, __name="_G"})

    -- _ALERT should not be nil. It's accessed internally from Lua and triggers the '__index' function above
    _ALERT = 0

    -- Package loading
    package.path = "" -- we're not going to search for packages
    -- the first searcher looks for a function in package.preload - this is the only legitimate way to load packages
    package.searchers = {package.searchers[1]}
    -- any used packages must provide a loader function
    -- package.preload["sample"] = function() return dofile("sample.lua", _G) end
    editor = rawget(_G, "editor") or {}
end

--- A table of global variables that can be persisted.
---
--- This table is used to track which global variables should be persisted across sessions or reloads.
---
--- @class table
--- @field [string] any The global variable value.
PersistableGlobals = {}
--- A table that holds pathfinding-related data or functionality.
pathfind = {}
---
--- A global table that holds configuration settings.
---
--- @class table
config = {}
---
--- A table that holds a list of loaded libraries.
---
--- This table is used to track which libraries have been loaded, and provides a way to iterate over them.
---
--- @class table
--- @field [string] any The loaded library function or value.
LibsList = {}

LibsList = {}
---
--- A table that provides a way to manage and access a list of loaded libraries.
---
--- The `Libs` table is a metatable that wraps the `LibsList` table, providing a way to add and remove libraries from the list.
---
--- @class table
--- @field [string] any The loaded library function or value.
Libs = setmetatable({}, {__index=LibsList, __newindex=function(_, lib, load)
    assert(type(lib) == "string")
    if load then
        LibsList[lib] = load
        table.insert_unique(LibsList, lib)
    else
        LibsList[lib] = nil
        table.remove_entry(LibsList, lib)
    end
end})

---
--- Iterates over the list of loaded libraries and calls the provided function for each library.
---
--- @param path string|nil The path to the library file, relative to the "CommonLua/Libs/" directory.
--- @param func fun(lib: string, lib_path: string|nil, ...any): any The function to call for each library.
--- @param ...any Additional arguments to pass to the function.
---
function ForEachLib(path, func, ...)
    for _, lib in ipairs(LibsList) do
        local lib_path = path and string.format("CommonLua/Libs/%s/%s", lib, path)
        if not lib_path or io.exists(lib_path) then
            func(lib, lib_path, ...)
        end
    end
end

---
--- A table that holds a list of files that should be excluded from the loading process.
---
--- @class table
--- @field [string] boolean Whether the file should be excluded from loading.
LoadingBlacklist = {}
---
--- Initializes the `GamepadUIStyle` table with a default value of `false` for the first local player.
---
--- This code is executed only on the first load of the script.
---
--- @field [1] boolean Whether the gamepad UI style is enabled for the first local player.
---
if FirstLoad then
    GamepadUIStyle = {[1]=false -- index is for the local player
    }
end

---
--- Determines whether the current platform is in developer mode or not.
---
--- If the platform is not in command-line mode, this code checks if the platform is not in goldmaster mode and if the "developer.lua" file exists. If both conditions are true, the `Platform.developer` field is set to `true`, otherwise it is set to `nil`.
---
--- @field Platform.developer boolean|nil Whether the current platform is in developer mode or not.
if not Platform.cmdline then
	Platform.developer = not Platform.goldmaster and io.exists("developer.lua") or nil
end

---
--- Disables the Lua assert function if the `Platform.asserts` field is falsy.
---
--- This function is used to set the parameters for the `loadfile` function, which is used to load Lua files. If `Platform.asserts` is falsy, the `set_loadfile_params` function is called with `false, false` as arguments, which disables the Lua assert function.
---
--- @field Platform.asserts boolean|nil Whether the Lua assert function is enabled or not.
if not Platform.asserts then
    set_loadfile_params(false, false)
end

---
--- Loads and executes the specified Lua files.
---
--- The `dofile` function is used to load and execute the following Lua files:
---
--- - `"CommonLua/Core/cthreads.lua"`: Provides functionality for working with coroutines.
--- - `"CommonLua/Core/lib.lua"`: A shared library that contains protected `dofile` functionality.
--- - `"CommonLua/Core/types.lua"`: Defines custom Lua types, such as `range`, `set`, and `table` extensions.
--- - `"CommonLua/Core/ToLuaCode.lua"`: Provides functionality for converting data to Lua code.
--- - `"CommonLua/Core/config.lua"`: Loads and manages the application configuration.
---
dofile("CommonLua/Core/cthreads.lua")
dofile("CommonLua/Core/lib.lua") -- Shared library (must be first - contains protected 'dofile')
dofile("CommonLua/Core/types.lua") -- range, set, table, string
dofile("CommonLua/Core/ToLuaCode.lua")
dofile("CommonLua/Core/config.lua")
---
--- Loads and executes various Lua files based on the current platform and configuration.
---
--- This code block is executed when the platform is not in command-line mode. It performs the following actions:
---
--- 1. If the platform is GED, it loads the `CommonLua/Ged/__config.lua` file and the `CommonLua/Core/ProceduralMeshShaders.lua` file.
--- 2. If the platform is not GED, it loads the `CommonLua/Core/Terrain.lua`, `CommonLua/Core/Postprocessing.lua`, and `CommonLua/Core/ProceduralMeshShaders.lua` files, and also loads all files in the `Lua/Config` directory.
--- 3. It sets the build revision using the `LuaRevision` variable.
--- 4. It checks the application command line for various options:
---    - If the `-map` option is present, it sets the `config.Map` variable and disables `config.LoadAlienwareLightFX`.
---    - If the `-cfg` option is present, it loads the specified configuration file.
---    - If the `-run` option is present, it sets the `config.RunCmd` variable.
---    - If the `-save` option is present, it sets the `config.Savegame` variable.
--- 5. It sets the `config.Mods` variable based on the presence of the `-nomods` option in the command line.
--- 6. It sets the `config.ArtTest` variable based on the presence of the `-arttest` option in the command line.
--- 7. It sets the `Platform.developer` engine variable based on the value of the `Platform.developer` field.
---
if not Platform.cmdline then
	if Platform.ged then
		dofile("CommonLua/Ged/__config.lua")
		dofile("CommonLua/Core/ProceduralMeshShaders.lua")
	else
		dofile("CommonLua/Core/Terrain.lua")
		dofile("CommonLua/Core/Postprocessing.lua")
		dofile("CommonLua/Core/ProceduralMeshShaders.lua")
		dofolder_files("Lua/Config")
	end
	SetBuildRevision(LuaRevision)
	local cmd = GetAppCmdLine() or ""
	if not Platform.goldmaster then
		if Platform.developer then
			dofile("developer.lua")
		end
		local cmdline_map = string.match(cmd, "-map%s+(%S+)")
		if cmdline_map then 
			config.Map = cmdline_map
			config.LoadAlienwareLightFX = false
		else
			if Platform.developer and io.exists("user.lua") then dofile("user.lua") end
			local cmdline_config = string.match(cmd, "-cfg%s+(%S+)")
			if cmdline_config then dofile(cmdline_config) end
		end
		config.RunCmd = string.match(cmd, "-run%s+(%S+)")
		local cmdline_save = string.match(cmd, "-save%s+\"(.+%.sav)\"")
		if cmdline_save then
			config.Savegame = cmdline_save
		end
	end
	config.Mods = config.Mods and not string.match(cmd, "-nomods")
	config.ArtTest = string.match(cmd, "-arttest")
	SetEngineVar("", "Platform.developer", Platform.developer or false)
end

---
--- Allows hooking into the `Autorun` event from `developer.lua` or `user.lua` files.
---
--- This line sets the `Autorun` event to the value of `config.Autorun`, which allows custom code
--- to be executed during the autorun process by modifying the `config.Autorun` variable in
--- `developer.lua` or `user.lua`.
---
--- @field Autorun function|nil The function to be executed during the autorun process.
OnMsg.Autorun = config.Autorun         -- Allow hook in developer/user.lua

SetupVarTable(config, "config.")

---
--- Enables or disables the Haerald debugging tools.
---
--- If `config.EnableHaerald` is true, the following files are loaded:
--- - `CommonLua/Core/luasocket.lua`
--- - `CommonLua/Core/luadebugger.lua`
--- - `CommonLua/Core/luaDebuggerOutput.lua`
--- - `CommonLua/Core/ProjectSync.lua`
---
--- If `Platform.pc` and `Platform.debug` are both true, the `Libs.DebugAdapter` is set to true.
---
--- If `config.EnableHaerald` is false, a no-op `bp()` function is defined.
---
--- @field config.EnableHaerald boolean Whether the Haerald debugging tools are enabled.
--- @field Platform.pc boolean Whether the current platform is PC.
--- @field Platform.debug boolean Whether the current build is a debug build.
--- @field Libs.DebugAdapter boolean Whether the debug adapter is enabled.
if config.EnableHaerald then
    dofile("CommonLua/Core/luasocket.lua")
    dofile("CommonLua/Core/luadebugger.lua")
    dofile("CommonLua/Core/luaDebuggerOutput.lua")
    dofile("CommonLua/Core/ProjectSync.lua")
    if Platform.pc and Platform.debug then
        Libs.DebugAdapter = true
    end
else
    function bp()
    end
end

---
--- Hooks into the update thread to provide debugging functionality.
---
--- This function is used to hook into the update thread and provide debugging capabilities, such as
--- stepping through code, setting breakpoints, and inspecting variables. It is typically used in
--- conjunction with the Haerald debugging tools, which are enabled by setting `config.EnableHaerald`
--- to `true`.
---
--- @function UpdateThreadDebugHook
UpdateThreadDebugHook()

---
--- Loads and initializes various Lua modules and systems.
---
--- The `dofile` calls in the selected code load the following modules:
---
--- - `CommonLua/Core/notify.lua`: Provides a global `notify` function for displaying notifications.
--- - `CommonLua/Core/math.lua`: Defines additional math-related functions and constants.
--- - `CommonLua/Core/classes.lua`: Provides a class system for creating and managing Lua objects.
--- - `CommonLua/Core/grids.lua`: Implements grid-based data structures and related functionality.
---
--- These modules are typically loaded during the autorun process to set up the necessary infrastructure for the application.
---
--- @module CommonLua.Core.autorun
--- @see CommonLua.Core.notify
--- @see CommonLua.Core.math
--- @see CommonLua.Core.classes
--- @see CommonLua.Core.grids
dofile("CommonLua/Core/notify.lua") -- Notify system global function

dofile("CommonLua/Core/math.lua")
dofile("CommonLua/Core/classes.lua")
dofile("CommonLua/Core/grids.lua")
---
--- Loads and initializes various Lua modules and systems.
---
--- The `dofile` calls in the selected code load the following modules:
---
--- - `CommonLua/Core/map.lua`: Provides functionality for working with maps and grid-based data structures.
--- - `CommonLua/Core/persist.lua`: Defines helper functions for persisting and loading Lua data.
--- - `CommonLua/Core/terminal.lua`: Handles keyboard and mouse event callbacks for the terminal.
--- - `CommonLua/Core/cameralock.lua`: Provides functionality for locking the camera to a specific target.
--- - `CommonLua/Core/mouse.lua`: Handles mouse-related functionality and events.
---
--- These modules are typically loaded during the autorun process to set up the necessary infrastructure for the application.
---
--- @module CommonLua.Core.autorun
--- @see CommonLua.Core.map
--- @see CommonLua.Core.persist
--- @see CommonLua.Core.terminal
--- @see CommonLua.Core.cameralock
--- @see CommonLua.Core.mouse
if not Platform.cmdline then
    dofile("CommonLua/Core/map.lua")
    dofile("CommonLua/Core/persist.lua") -- Lua persist helper functions
    dofile("CommonLua/Core/terminal.lua") -- Lua callbacks for keyboard/mouse events
    dofile("CommonLua/Core/cameralock.lua")
    dofile("CommonLua/Core/mouse.lua")
end

---
--- Conditionally mounts or disables the LuaPackfile and DataPackfile based on the platform.
---
--- If the platform is a command-line environment, the LuaPackfile and DataPackfile are disabled.
--- Otherwise, the `CommonLua/Core/mount.lua` module is loaded to handle the mounting of these files.
---
--- @module CommonLua.Core.autorun
--- @within CommonLua.Core
if Platform.cmdline then
    LuaPackfile = false
    DataPackfile = false
else
    dofile("CommonLua/Core/mount.lua")
end

---
--- Loads and initializes various Lua modules and systems.
---
--- The `dofile` calls in the selected code load the following modules:
---
--- - `CommonLua/Core/localization.lua`: Provides functionality for handling localization and translation of text.
--- - `CommonLua/Core/usertexts.lua`: Defines helper functions for working with user-facing text.
--- - `CommonLua/Core/ParseCSV.lua`: Implements a function to parse CSV (Comma-Separated Values) data.
--- - `CommonLua/Core/asyncop.lua`: Provides utilities for working with asynchronous operations.
---
--- These modules are typically loaded during the autorun process to set up the necessary infrastructure for the application.
---
--- @module CommonLua.Core.autorun
--- @see CommonLua.Core.localization
--- @see CommonLua.Core.usertexts
--- @see CommonLua.Core.ParseCSV
--- @see CommonLua.Core.asyncop
dofile("CommonLua/Core/localization.lua")
dofile("CommonLua/Core/usertexts.lua")
dofile("CommonLua/Core/ParseCSV.lua")
dofile("CommonLua/Core/asyncop.lua")

---
--- Loads configuration files and sets up platform-specific error handling and translation tables.
---
--- This code block performs the following tasks:
---
--- 1. Loads the main configuration file (`config.lua`) based on the platform:
---    - If running in command-line mode, it loads `config.lua`.
---    - If running on a PlayStation platform (not in goldmaster mode), it loads platform-specific error code tables.
--- 2. Initializes the translation tables and sound metadata on the first load:
---    - If not running in Ged or developer mode, it loads the translation tables.
---    - If not running in Ged mode, it loads the sound metadata.
--- 3. Initializes the Windows IME (Input Method Editor) state.
--- 4. Loads additional Lua files:
---    - `CommonLua/Core/const.lua`: Defines constants in the `const` table.
---    - `CommonLua/Core/ConstDef.lua`: Loads project/DLC/mod constants in the `const` table (only if not in command-line mode).
---    - `CommonLua/Core/error.lua`: Defines error handling utilities.
---    - `CommonLua/Core/locutils.lua`: Provides localization utility functions.
---
--- @module CommonLua.Core.autorun
--- @within CommonLua.Core
LoadConfig("svnProject/config.lua")
if Platform.cmdline then
    LoadConfig("config.lua")
else
    if Platform.playstation and not Platform.goldmaster then
        local ps_errors = {}
        if Platform.ps4 then
            LoadCSV("/host/%SCE_ORBIS_SDK_DIR%/host_tools/debugging/error_code/error_table.csv", ps_errors)
        elseif Platform.ps5 then
            LoadCSV("/host/%SCE_PROSPERO_SDK_DIR%/host_tools/debugging/error_code/error_table.csv", ps_errors)
        else
            assert(not "Unsupported PlayStation platform!")
        end
        SetPlayStationErrorTable(ps_errors)
    end
    if FirstLoad then
        if not Platform.ged or not Platform.developer then
            LoadTranslationTables()
        end
        if not Platform.ged then
            LoadSoundMetadata("BinAssets/sndmeta.dat")
        end
    end
    InitWindowsImeState()
end
dofile("CommonLua/Core/const.lua") -- Constants in the 'const' table
if not Platform.cmdline then
    dofile("CommonLua/Core/ConstDef.lua") -- load project/dlc/mod constants in the 'const' table
end
dofile("CommonLua/Core/error.lua")
dofile("CommonLua/Core/locutils.lua")

-- Platform.asserts is set in all debug builds (see C macros DBG_ASSERT_ENABLED).
-- All debug builds have the Dev lib packed (see env.variant_set.debug).
if not Platform.cmdline then
	if Platform.developer then
		Libs.Debug = true
	elseif Platform.asserts then
		Libs.Debug = io.exists("CommonLua/Libs/Debug") 
	end
end

---
--- Loads additional Lua files based on the platform and development environment.
--- If the application is running in command-line mode, it loads the `config.lua` file.
--- Otherwise, it sets up the PlayStation error table, loads translation tables and sound metadata, and initializes the Windows IME state.
--- It then loads various Lua files from the `CommonLua/Core` directory, including `const.lua`, `ConstDef.lua`, `error.lua`, and `locutils.lua`.
--- If the application is running in a debug build, it sets the `Libs.Debug` flag based on the development environment.
--- Finally, it loads additional Lua files and folders based on the platform and configuration.
---
--- @module CommonLua.Core.autorun
--- @within CommonLua.Core
if Platform.cmdline then
    if GetEngineVar("", "config.RunUnpacked") then
        LuaRevision = GetUnpackedLuaRevision(nil, nil, config.FallbackLuaRevision)
    else
        pdofile("_LuaRevision.lua") -- will read BuildVersion as well
    end
    dofolder("CommonLua/HGL")
    dofile("CommonLua/Classes/Socket.lua")
    dofile("CommonLua/PropertyObject.lua")
    dofile("CommonLua/PropertyObjectContainers.lua")
    dofile("CommonLua/Classes/CommandObject.lua")
    dofile("CommonLua/EventLog.lua")
    dofile("CommonLua/console.lua")
    dofile("CommonLua/Classes/TupleStorage.lua")
    dofile("CommonLua/GedEditedObject.lua")
    dofile("CommonLua/Preset.lua")
    dofile("CommonLua/Reactions.lua")
    dofile("CommonLua/Classes/ModItem.lua")
    dofile("CommonLua/TableParentCache.lua")
    dofile("CommonLua/Classes/ClassDefs/ClassDef-Config.generated.lua")
    DefineClass("GedFilter") -- stub a class used as parent in HGTestFilter
    dofile("CommonLua/Classes/ClassDefs/ClassDef-Internal.generated.lua")
else
    dofile("CommonLua/Core/GlobalStorageTables.lua")
    if GetEngineVar("", "config.RunUnpacked") then
        LuaRevision = GetUnpackedLuaRevision(nil, nil, config.FallbackLuaRevision)
    else
        pdofile("_LuaRevision.lua") -- will read BuildVersion as well
    end

    if Platform.developer and Platform.pc then
        InitSourceController()
    end
    SetupVarTable(hr, "hr.")
    SetVarTableLock(hr, true)
    dofile("CommonLua/Core/options.lua")

    dofile("CommonLua/Ged/stubs.lua")

    if FirstLoad then
        --[[	
		local major, minor, build = GetOSVersion()
		if major < config.OSVersionMajorReq or
			(major == config.OSVersionMajorReq and minor < config.OSVersionMinorReq) then
			SystemMessageBox( _InternalTranslate(T{1000484, "Error"}), 
				_InternalTranslate( T{1000485, "This game requires a newer OS version (<major>.<minor>).", major = config.OSVersionMajorReq, minor = config.OSVersionMinorReq} ) )
			quit(-1)
		end
]]
        Options.Startup()
        Options.FixupEngineOptions()

        -- text messages used by the C side
        config.CriticalErrorTitle = _InternalTranslate(T(768699500779, "Critical Error"))
        config.CriticalErrorText = _InternalTranslate(T(676315741793,
            "Unspecified error occurred (code %s1). The game will now close."))
        config.VideoDriverError = _InternalTranslate(T(622236701127,
            "You need a supported DX11-compatible video card with updated drivers to play this game."))
        config.VideoModeError = _InternalTranslate(T(838205552015, "Failed to initialize video mode."))

        local err = InitRenderEngine()
        if err then
            local caption = _InternalTranslate(T(634182240966, "Error"))
            if config.GraphicsApi == "d3d11" or config.GraphicsApi == "d3d12" then
                SystemMessageBox(caption, _InternalTranslate(T(224174170996,
                    "You need DirectX 11/12 and a DirectX 11/12-compatible graphics card to run this game.")))
            elseif config.GraphicsApi == "opengl" or Platform.linux then
                SystemMessageBox(caption, _InternalTranslate(
                    T(564352332891, "You need an OpenGL 4.5-capable graphics card to run this game.")))
            else
                SystemMessageBox(caption,
                    _InternalTranslate(T(595831467700, "Failed to initialize graphics subsystem.")))
            end
            quit(-1)
        end
        Options.Startup()
    end

    dofolder_files("CommonLua")
    dofolder("CommonLua/Classes")
    dofolder("CommonLua/UI")
    dofolder("CommonLua/X")

    if FirstLoad and not Platform.ged then
        CreateRealTimeThread(function()
            LoadingScreenOpen("idLoadingScreen", "autorun")
        end)
    end

    dofolder("CommonLua/Ged")

    if Platform.editor then
        dofolder("CommonLua/Editor")
    end
end

---
--- Loads and runs additional development-related Lua files when the game is running in developer mode with command line arguments.
---
--- The files loaded are:
--- - `CommonLua/Libs/Dev/FileSystemChanged.lua`: Provides functionality for monitoring file system changes.
--- - `CommonLua/Libs/Dev/dump.lua`: Provides a `dump()` function for printing the contents of Lua tables.
--- - `CommonLua/Libs/Dev/GenerateDocs.lua`: Provides functionality for generating documentation for Lua code.
---
--- This code is only executed when the game is running in developer mode with command line arguments, as indicated by the `Platform.developer` and `Platform.cmdline` flags.
---
if Platform.developer and Platform.cmdline then
    dofile("CommonLua/Libs/Dev/FileSystemChanged.lua")
    dofile("CommonLua/Libs/Dev/dump.lua")
    dofile("CommonLua/Libs/Dev/GenerateDocs.lua")
end

-- load Lib stubs
---
--- Loads and runs additional Lua library files from the `CommonLua/Libs/` directory.
---
--- This code searches for all Lua files in the `CommonLua/Libs/` directory that start with `__` and loads them. The files are sorted alphabetically before being loaded.
---
--- This is used to load additional utility libraries that are not part of the main codebase.
---
--- @param files string[] The list of Lua files found in the `CommonLua/Libs/` directory that start with `__`.
--- @param lib string The name of the library, extracted from the file name.
local files = io.listfiles("CommonLua/Libs/", "__*.lua", "non recursive")
table.sort(files, CmpLower)
for _, file in ipairs(files) do
    local lib = file:sub(18, -5)
    if lib and not Libs[lib] then
        dofile(file)
    end
end

-- load Libs
---
--- Loads and runs additional Lua library files from the `CommonLua/Libs/` directory.
---
--- This code searches for all Lua files in the `CommonLua/Libs/` directory that start with `__` and loads them. The files are sorted alphabetically before being loaded.
---
--- This is used to load additional utility libraries that are not part of the main codebase.
---
--- @param files string[] The list of Lua files found in the `CommonLua/Libs/` directory that start with `__`.
--- @param lib string The name of the library, extracted from the file name.
for _, lib in ipairs(LibsList) do
	local lib_path = "CommonLua/Libs/" .. lib
	local lib_file = lib_path .. ".lua"
	local exists
	if io.exists(lib_file) then
		dofile(lib_file)
		exists = true
	end
	if io.exists(lib_path) then
		dofolder(lib_path)
		exists = true
	end
	if not exists then
		assert(exists, string.format("Library %s has no corresponding file or folder", lib))
	end
end

---
--- Prevents loading additional libraries after the initial library load step.
---
--- This metatable hook ensures that no new libraries can be added to the `Libs` table after the initial library load step. This helps maintain a consistent state of the available libraries.
---
--- @param _ table The `Libs` table.
--- @param lib string The name of the library to be loaded.
--- @param load boolean Whether to load the library or not.
---
getmetatable(Libs).__newindex = function(_, lib, load)
    assert(not load or Libs[lib], "Cannot load libs after lib load step.")
end

---
--- Loads additional source folders specified in the config.AdditionalSources table.
---
--- This code iterates over the config.AdditionalSources table and loads the contents of each folder using the dofolder function. This allows the game to load additional source code from custom locations.
---
--- @param config table The global configuration table.
--- @param src_folder string The path to the additional source folder to load.
---
for _, src_folder in ipairs(config.AdditionalSources) do
    dofolder(src_folder)
end

---
--- Loads the CommonLua/MapGen folder if the config.RandomMap flag is set or the Platform.editor flag is set.
---
--- This code checks if the config.RandomMap flag is set or if the Platform.editor flag is set. If either of these conditions is true, it loads the contents of the CommonLua/MapGen folder.
---
--- This is likely used to load additional map generation code when a random map is requested or when the game is running in an editor environment.
---
--- @param config table The global configuration table.
--- @param Platform table The global Platform table.
if config.RandomMap or Platform.editor then
    dofolder("CommonLua/MapGen")
end

-- load platform code
---
--- Loads platform-specific code from the CommonLua/Platforms folder.
---
--- This code iterates over the list of platform folders in the CommonLua/Platforms directory and loads the contents of each folder that corresponds to a platform that is currently active (i.e. `Platform[platform]` is true).
---
--- This allows the game to load platform-specific code and functionality based on the current platform the game is running on.
---
--- @param platform_folders table A table of platform folder names in the CommonLua/Platforms directory.
---
local err, platform_folders = AsyncListFiles("CommonLua/Platforms/", "*", "relative,folders")
table.sort(platform_folders)
for _, platform in ipairs(platform_folders) do
    if Platform[platform] then
        dofolder("CommonLua/Platforms/" .. platform)
    end
end

---
--- Loads the Lua folder and initializes DLCs and mods if the game is not running in command-line mode and not in the GED editor.
---
--- This code block is executed when the game is first loaded. It performs the following tasks:
---
--- 1. Loads the contents of the Lua folder using the `dofolder` function.
--- 2. Initializes any installed DLCs by calling the `DlcsLoadCode` function.
--- 3. Initializes any installed mods by calling the `ModsLoadCode` function.
---
--- If the `FirstLoad` flag is set, it also performs the following additional tasks:
---
--- 1. Sets the default mouse cursor for desktop, PS4, and Xbox platforms.
--- 2. Checks if the game is running in developer mode or with a specific command-line argument, and if so, loads the last saved game or the specified map.
--- 3. If not in developer mode, it plays the initial movies and initializes the platform-specific sign-in process (Windows Store, Epic, Xbox).
--- 4. Opens the pre-game main menu.
--- 5. Sets the XShortcuts mode to "Game".
--- 6. Sends the "EngineStarted" message.
---
--- @param Platform table The global Platform table.
--- @param config table The global configuration table.
--- @param LocalStorage table The global LocalStorage table.
--- @param FirstLoad boolean Whether this is the first time the game is loaded.
if not Platform.cmdline and not Platform.ged then
    dofolder("Lua")
    DlcsLoadCode()
    ModsLoadCode()

    if FirstLoad then
        CreateRealTimeThread(function()
            if Platform.desktop or Platform.ps4 or Platform.xbox then
                SetAppMouseCursor(const.DefaultMouseCursor)
            end
            local pgo_train = Platform.pgo_train and GetAppCmdLine():match("-PGOTrain")
            -- Quick start
            if (Platform.developer and ((config.Map or "") ~= "" or (config.Savegame or "") ~= "") and not Platform.xbox)
                or pgo_train then
                LoadingScreenOpen("idLoadingScreen", "quickstart")
                Msg("PlatformInitalization")
                WaitLoadAccountStorage()
                LoadDlcs()
                ModsLoadLocTables()
                local save_as_last = true
                local savegame = config.Savegame or ""
                if savegame == "last" then
                    savegame = LocalStorage.last_save or ""
                    save_as_last = false
                end
                if savegame ~= "" then
                    DebugPrint("Loading last save:", savegame, "\n")
                    local err = LoadGame(savegame, {save_as_last=save_as_last})
                    if err then
                        print("Failed to load", savegame, err)
                    end
                else
                    local map = config.Map
                    local map_variation
                    if map == "last" then
                        map = LocalStorage.last_map or config.LastMapDefault or ""
                        map_variation = LocalStorage.last_map_variation
                    end
                    if map ~= "" and map ~= "none" then
                        ChangeMap(map, map_variation)
                    end
                end
                LoadingScreenClose("idLoadingScreen", "quickstart")
                if config.RunCmd then
                    dostring(config.RunCmd)
                end
                if pgo_train then
                    RunPGOTrain()
                end
            else -- "Official" start on Main menu
                if rawget(_G, "PlayInitialMovies") and not Platform.developer and not Platform.publisher
                    and not const.PlayStationSkipNoticeScreen then
                    PlayInitialMovies()
                end
                if Platform.windows_store then
                    LoadingScreenOpen("idSignInLoadingScreen", "main menu")
                    WindowsStore.InitXal()
                    WindowsStoreSignInUser(true)
                end

                if Platform.epic then
                    LoadingScreenOpen("idSignInLoadingScreen", "main menu")
                    WaitStartEpic()
                end

                if Platform.xbox then
                    LoadingScreenOpen("idAutorunLoadingScreen", "main menu")
                    InitalizeXboxState()
                    ResetTitleState()
                    Msg("PlatformInitalization")
                    if config.AllowInvites then
                        Msg("StartAcceptingInvites")
                    end
                    LoadingScreenClose("idAutorunLoadingScreen", "main menu")
                else
                    LoadingScreenOpen("idAutorunLoadingScreen", "main menu")
                    Msg("PlatformInitalization")
                    WaitLoadAccountStorage()
                    LoadDlcs()
                    ModsLoadLocTables()
                    OpenPreGameMainMenu()
                    if config.AllowInvites then
                        Msg("StartAcceptingInvites")
                    end
                    LoadingScreenClose("idAutorunLoadingScreen", "main menu")
                end

                if Platform.windows_store or Platform.epic then
                    -- close here so that we don't reopen the loading screen
                    LoadingScreenClose("idSignInLoadingScreen", "main menu")
                end

                if Platform.switch then
                    CreateRealTimeThread(function()
                        GetActiveSwitchController()
                    end)
                end
            end
            XShortcutsSetMode("Game")
            Msg("EngineStarted")
            MsgClear("EngineStarted")
        end)
    end
end

---
--- Loads all Lua files in the "Lua/Ged" directory if the platform is not command-line and is GED.
---
--- This function is likely an implementation detail within the larger `autorun.lua` file, and is not intended to be
--- called directly from outside the file.
---
--- @param Platform table The platform-specific configuration table.
---
if not Platform.cmdline and Platform.ged then
    dofolder_files("Lua/Ged")
end

---
--- Handles the autorun functionality for the application.
---
--- This function is called when the application is first loaded, and performs various initialization and cleanup tasks.
---
--- @param FirstLoad boolean Whether this is the first time the application has been loaded.
--- @param config table The application configuration table.
--- @param Platform table The platform-specific configuration table.
---
function OnMsg.Autorun()
    if FirstLoad and config.EnableHaerald then
        if Platform.cmdline then
            StartDebugger()
        elseif string.match(GetAppCmdLine() or "", "-debug") then
            StartDebugger()
        end
    end

    MsgClear("Autorun")
    collectgarbage("restart")
    collectgarbage("setpause", 100)
    Loading = false
    if FirstLoad then
        FirstLoad = false
        Msg("Start")
    end
    MsgClear("Start")
end

---
--- Handles the command-line execution of the application.
---
--- This block of code is executed when the application is run from the command-line. It checks if the platform is iOS, and if so, returns. Otherwise, it checks if the "autorun.lua" file exists and executes it if it does.
---
--- If no command-line arguments are provided, it will execute the "help" command. Otherwise, it will execute the command specified by the first command-line argument, passing the remaining arguments to the command function.
---
--- If an error occurs during the execution of the command, it will print the error message and set the exit code to 1.
---
--- @param FirstLoad boolean Whether this is the first time the application has been loaded.
--- @param Platform table The platform-specific configuration table.
--- @param arg table The command-line arguments.
--- @param CmdLineCommands table The table of available command-line commands.
---
if FirstLoad then
    if Platform.cmdline then
        if Platform.ios then
            return true
        end
        if io.exists("autorun.lua") then
            dofile("autorun.lua")
        end

        -- Handle command
        local func = CmdLineCommands[arg[1]] or function(arg)
            if arg[1] and io.exists(arg[1]) then
                SetExitCode(tonumber(dofile(arg[1]) or 0))
            else
                CmdLineCommands["help"] {}
            end
        end
        local err = func(arg)
        if err then
            print("Error:", err)
            SetExitCode(1)
        end
    else
        DebugPrint("\nPlatform: " .. table.concat(table.keys(Platform, true), ", ") .. "\n\n")

        if not Platform.ged then
            CreateRealTimeThread(function()
                LoadingScreenClose("idLoadingScreen", "autorun")
            end)
        end
    end
end
