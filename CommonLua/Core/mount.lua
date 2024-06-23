--- Checks if this is the first time the script has been loaded. If not, the script will return early without executing any further code.
--- This is a common pattern used to ensure a script only runs once, which can be important for initialization or setup logic.
if not FirstLoad then
    return
end
--- Checks if the current platform is PS4 and calls the `OrbisStartFakeSubmitDone()` function if so.
--- This function is likely used to perform some platform-specific initialization or setup for the PS4 platform.
if Platform.ps4 then
    OrbisStartFakeSubmitDone()
end

---
--- Checks if the current script is running in an unpacked environment.
---
--- @return boolean unpacked Whether the script is running in an unpacked environment.
local unpacked = IsFSUnpacked()

-- Data & Lua
---
--- Mounts the 'Data' folder or pack based on whether the script is running in an unpacked environment.
---
--- If the script is running in an unpacked environment, the 'Data' folder is mounted from the 'svnProject/Data/' directory with the 'label:Data' option.
--- If the script is running in a packed environment, the 'Data.hpk' pack is mounted with the 'in_mem,label:Data' options.
---
--- Additionally, the 'LuaPackfile' and 'DataPackfile' variables are set to either 'false' or the respective pack file names based on the environment.
---
if unpacked then
    LuaPackfile = false
    DataPackfile = false
    MountFolder("Data", "svnProject/Data/", "label:Data")
else
    LuaPackfile = "Packs/Lua.hpk"
    DataPackfile = "Packs/Data.hpk"
    MountPack("Data", "Packs/Data.hpk", "in_mem,label:Data")
end

---
--- Mounts the 'ModTools' folder if the 'config.Mods' flag is set.
---
--- This function is likely used to load and initialize any mod-related assets or functionality.
---
--- @param config table The global configuration table, which contains the 'Mods' flag.
---
if config.Mods then
    MountFolder("ModTools/", GetExecDirectory() .. "ModTools/")
end

-- Fonts & UI
---
--- Mounts the 'Fonts' and 'UI' folders based on whether the script is running in an unpacked environment.
---
--- If the script is running in an unpacked environment, the 'Fonts' and 'UI' folders are mounted from the 'svnAssets/Bin/Common/' directory.
--- If the script is running in a packed environment, the 'Fonts.hpk' and 'UI.hpk' packs are mounted.
---
--- This function is likely used to load and initialize font and UI-related assets.
---
--- @param unpacked boolean Whether the script is running in an unpacked environment.
---
if unpacked then
    MountFolder("Fonts", "svnAssets/Bin/Common/Fonts/")
    MountFolder("UI", "svnAssets/Bin/Common/UI/")
else
    MountPack("Fonts", "Packs/Fonts.hpk")
    MountPack("UI", "Packs/UI.hpk")
end

-- Misc
---
--- Mounts the 'Misc' folder or pack based on whether the script is running in an unpacked environment.
---
--- If the script is running in an unpacked environment, the 'Misc' folder is mounted from the 'svnAssets/Source/Misc' directory.
--- If the script is running in a packed environment, the 'Misc.hpk' pack is mounted.
---
--- This function is likely used to load and initialize any miscellaneous assets or functionality.
---
if unpacked then
    MountFolder("Misc", "svnAssets/Source/Misc")
else
    MountPack("Misc", "Packs/Misc.hpk")
end


-- Shader cache mounting must happen on the C side,
-- because it has to happen after the graphics API has been determined,
-- but before various subsystems request their shaders in their Init() methods

---
--- Mounts the 'Shaders' folder or pack based on whether the script is running in an unpacked environment.
---
--- If the script is running in an unpacked environment, the 'Shaders' folder is mounted from the 'svnProject/Shaders/' and 'svnSrc/HR/Shaders/' directories.
--- If the script is running in a packed environment and the platform is desktop, Xbox, or Switch, the 'Shaders.hpk' pack is mounted.
---
--- This function is likely used to load and initialize shader-related assets.
---
--- @param unpacked boolean Whether the script is running in an unpacked environment.
--- @param Platform table The platform-specific configuration table.
if unpacked then
    MountFolder("Shaders", "svnProject/Shaders/", "seethrough")
    MountFolder("Shaders", "svnSrc/HR/Shaders/", "seethrough")
else
    if Platform.desktop or Platform.xbox or Platform.switch then
        MountPack("Shaders", "Packs/Shaders.hpk", "seethrough")
    end
end

-- Assets
--- Mounts the necessary asset folders or packs based on whether the script is running in an unpacked or packed environment.
---
--- If the script is running in an unpacked environment, the following folders are mounted:
--- - CommonAssets: From the 'svnSrc/CommonAssets/' directory
--- - BinAssets: From the 'svnAssets/Bin/win32/BinAssets/' directory
--- - Meshes, Skeletons, Entities, Animations, Materials, Mapping, TexturesMeta, Fallbacks: From the 'CommonAssets/Entities/' and 'svnAssets/Bin/Common/' directories
---
--- If the script is running in a packed environment, the following packs are mounted:
--- - Meshes, Skeletons, Animations, Fallbacks: From the 'Packs/' directory
--- - BinAssets: From the 'Packs/BinAssets.hpk' pack
--- - CommonAssets: From the 'Packs/CommonAssets.hpk' pack
---
--- This function is likely used to load and initialize the necessary asset files for the game or application.
if unpacked then
	MountFolder("CommonAssets", "svnSrc/CommonAssets/")
	MountFolder("BinAssets", "svnAssets/Bin/win32/BinAssets/")

	MountFolder("Meshes", "CommonAssets/Entities/Meshes/")
	MountFolder("Skeletons", "CommonAssets/Entities/Skeletons/")
	MountFolder("Entities", "CommonAssets/Entities/Entities/")
	MountFolder("Animations", "CommonAssets/Entities/Animations/")
	MountFolder("Materials", "CommonAssets/Entities/Materials/")
	MountFolder("Mapping", "CommonAssets/Entities/Mapping/")
	MountFolder("TexturesMeta", "CommonAssets/Entities/TexturesMeta/", "seethrough")
	MountFolder("Fallbacks", "CommonAssets/Entities/Fallbacks/")
	
	MountFolder("Meshes", "svnAssets/Bin/Common/Meshes/", "seethrough")
	MountFolder("Skeletons", "svnAssets/Bin/Common/Skeletons/", "seethrough")
	MountFolder("Entities", "svnAssets/Bin/Common/Entities/", "seethrough")
	MountFolder("Animations", "svnAssets/Bin/Common/Animations/", "seethrough")
	MountFolder("Materials", "svnAssets/Bin/Common/Materials/", "seethrough")
	MountFolder("Mapping", "svnAssets/Bin/Common/Mapping/", "seethrough")
	MountFolder("TexturesMeta", "svnAssets/Bin/Common/TexturesMeta/", "seethrough")
	MountFolder("Fallbacks", "svnAssets/Bin/win32/Fallbacks/", "seethrough")
else	
	MountPack("Meshes", "Packs/Meshes.hpk")
	MountPack("Skeletons", "Packs/Skeletons.hpk")
	MountPack("Animations", "Packs/Animations.hpk")
	MountPack("Fallbacks", "Packs/Fallbacks.hpk")
	
	MountPack("BinAssets", "Packs/BinAssets.hpk")
	MountPack("", "Packs/CommonAssets.hpk", "seethrough,label:CommonAssets")
end
	
const.LastBinAssetsBuildRevision = tonumber(dofile("BinAssets/AssetsRevision.lua") or 0) or 0

--- Mounts the necessary sound and music folders or packs based on whether the script is running in an unpacked or packed environment.
---
--- If the script is running in an unpacked environment, the following folders are mounted:
--- - Sounds: From the 'svnAssets/Source/Sounds/' directory
--- - Music: From the 'svnAssets/Source/Music/' directory
--- - A LRU memory cache is created for the Sounds folder with a size specified by the config.SoundCacheMemorySize setting.
---
--- If the script is running in a packed environment, no additional assets are mounted.
---
--- This function is likely used to load and initialize the necessary sound and music files for the game or application.
if not Platform.ged then
    -- Sounds & Music
    if unpacked then
        MountFolder("Sounds", "svnAssets/Source/Sounds/")
        MountFolder("Music", "svnAssets/Source/Music/")
        CreateLRUMemoryCache("Sounds", config.SoundCacheMemorySize or 0)
    end

    -- Movies
    if unpacked then
        MountFolder("Movies", "svnAssets/Bin/win32/Movies/")
    end
end

--- Mounts a memory screenshot pack if the `config.MemoryScreenshotSize` setting is enabled and this is the first load.
---
--- The memory screenshot pack is mounted with the empty string as the pack name, and the "create" flag is set with the value of `config.MemoryScreenshotSize`.
---
--- This function is likely used to enable capturing and storing memory usage screenshots during the initial load of the application.
if FirstLoad and config.MemoryScreenshotSize then
    MountPack("memoryscreenshot", "", "create", config.MemoryScreenshotSize);
end

g_VoiceVariations = false

---
--- Mounts the necessary language assets based on whether the script is running in an unpacked or packed environment.
---
--- If the script is running in an unpacked environment, the following assets are mounted:
--- - CurrentLanguage folder from the 'svnProject/LocalizationOut/{GetLanguage()}/CurrentLanguage/' directory
--- - Voices folder from the 'svnAssets/Bin/win32/Voices/{GetVoiceLanguage()}/' directory
--- - VoicesTTS folder from the 'svnAssets/Bin/win32/VoicesTTS/{GetVoiceLanguage()}/' directory if config.VoicesTTS is true
---
--- If the script is running in a packed environment, the following assets are mounted:
--- - Language pack from the 'Local/{GetLanguage()}.hpk' file
--- - Voices pack from the 'Local/Voices/{GetVoiceLanguage()}.hpk' file
--- - VoicesTTS pack from the 'Local/VoicesTTS/{GetVoiceLanguage()}.hpk' file if config.VoicesTTS is true
---
--- This function is likely used to load and initialize the necessary language assets for the game or application.
---
--- @function MountLanguage
--- @return nil
function MountLanguage()
    local unpacked = config.UnpackedLocalization or config.UnpackedLocalization == nil and IsFSUnpacked()
    UnmountByLabel("CurrentLanguage")
    g_VoiceVariations = false
    if unpacked then
        MountFolder("CurrentLanguage", "svnProject/LocalizationOut/" .. GetLanguage() .. "/CurrentLanguage/",
            "label:CurrentLanguage")
        local unpacked_voices = "svnAssets/Bin/win32/Voices/" .. GetVoiceLanguage() .. "/"
        if not io.exists(unpacked_voices) then
            SetVoiceLanguage("English")
            unpacked_voices = "svnAssets/Bin/win32/Voices/" .. GetVoiceLanguage() .. "/"
        end
        MountFolder("CurrentLanguage/Voices", "svnAssets/Bin/win32/Voices/" .. GetVoiceLanguage() .. "/",
            "label:CurrentLanguage")
        if config.VoicesTTS then
            MountFolder("CurrentLanguage/VoicesTTS", "svnAssets/Bin/win32/VoicesTTS/" .. GetVoiceLanguage() .. "/",
                "label:CurrentLanguage")
        end
    else
        local err = MountPack("", "Local/" .. GetLanguage() .. ".hpk", "seethrough,label:CurrentLanguage")
        if err then
            SetLanguage("English")
            MountPack("", "Local/" .. GetLanguage() .. ".hpk", "seethrough,label:CurrentLanguage")
        end

        err = MountPack("CurrentLanguage/Voices", "Local/Voices/" .. GetVoiceLanguage() .. ".hpk",
            "label:CurrentLanguage")
        if err then
            SetVoiceLanguage("English")
            MountPack("CurrentLanguage/Voices", "Local/Voices/" .. GetVoiceLanguage() .. ".hpk", "label:CurrentLanguage")
        end
        if config.VoicesTTS then
            MountPack("CurrentLanguage/VoicesTTS", "Local/VoicesTTS/" .. GetVoiceLanguage() .. ".hpk",
                "label:CurrentLanguage")
        end
    end
    if rawget(_G, "DlcDefinitions") then
        DlcMountVoices(DlcDefinitions)
    end

    if config.GedLanguageEnglish then
        if unpacked then
            MountFolder("EnglishLanguage", "svnProject/LocalizationOut/English/")
        else
            MountPack("EnglishLanguage", "Local/English.hpk")
        end
    end

    local voice_variations_path = "CurrentLanguage/Voices/variations.lua"
    if io.exists(voice_variations_path) then
        local ok, vars = pdofile(voice_variations_path)
        if ok then
            g_VoiceVariations = vars
        else
            dbg(DebugPrint(string.format("Error loading voice variations: %s", vars)))
        end
    end
end

-- Localization
MountLanguage()

---
--- Mounts the texture assets for the game.
---
--- If the game is running in unpacked mode, the textures are mounted from the `CommonAssets/Entities/Textures/` and `svnAssets/Bin/win32/Textures/` folders, with the billboards mounted from the `svnAssets/Bin/win32/Textures/Billboards/` folder. On OSX, the cubemaps are also mounted from the `svnAssets/Bin/osx/Textures/Cubemaps/` folder.
---
--- If the game is running in packed mode, the textures are mounted from the `Packs/Textures.hpk` and `Packs/Textures[0-9].hpk` packs, with the priority and seethrough flags set.
---
--- @param unpacked boolean Whether the game is running in unpacked mode.
function MountTextures(unpacked)
end
local function MountTextures(unpacked)
    if unpacked then
        MountFolder("Textures", "CommonAssets/Entities/Textures/", "priority:high")
        MountFolder("Textures", "svnAssets/Bin/win32/Textures/", "priority:high,seethrough")

        local billboardFolders = io.listfiles("svnAssets/Bin/win32/Textures/Billboards/", "*", "folders")
        for _, folder in pairs(billboardFolders) do
            MountFolder("Textures/Billboards", folder .. "/", "priority:high,seethrough")
        end

        if Platform.osx then
            MountFolder("Textures/Cubemaps", "svnAssets/Bin/osx/Textures/Cubemaps/", "priority:high")
        end
    else
        if Platform.desktop or Platform.xbox or Platform.switch then
            MountPack("Textures", "Packs/Textures.hpk", "priority:high,seethrough")
            for i = 0, 9 do
                MountPack("", "Packs/Textures" .. tostring(i) .. ".hpk", "priority:high,seethrough")
            end
        else
            MountPack("Textures", "Packs/Textures.hpk", "priority:high,seethrough")
        end
    end
end

-- Documentation

---
--- Mounts the documentation folders based on whether the game is running in unpacked or packed mode.
---
--- In unpacked mode, the documentation is mounted from the following folders:
--- - `svnSrc/Docs/`
--- - `svnProject/Docs/` (with `seethrough` flag)
--- - `svnProject/Docs/ModTools/` (with `seethrough` flag)
---
--- In packed mode, the documentation is mounted from the `ModTools/Docs/` folder.
---
--- @param unpacked boolean Whether the game is running in unpacked mode.
if unpacked then
    UnmountByPath("Docs")
    MountFolder("Docs", "svnSrc/Docs/")
    MountFolder("Docs", "svnProject/Docs/", "seethrough")
    MountFolder("Docs", "svnProject/Docs/ModTools/", "seethrough")
else
    MountFolder("Docs", "ModTools/Docs/")
end

---
--- Runs automatically when the game starts up. Loads precache metadata for all .meta files in the BinAssets folder.
---
--- The precache metadata is loaded based on the `metaCheck` value, which is determined by the current platform:
--- - On non-test platforms, `const.PrecacheDontCheck` is used, which means the metadata is loaded without checking if it's up-to-date.
--- - On test platforms, `const.PrecacheCheckUpToDate` is used for PC, which means the metadata is only loaded if it's up-to-date.
--- - On test platforms, `const.PrecacheCheckExists` is used for other platforms, which means the metadata is only loaded if it exists.
---
--- @function OnMsg.Autorun
--- @return nil
function OnMsg.Autorun()
    local metaCheck = const.PrecacheDontCheck
    if Platform.test then
        metaCheck = Platform.pc and const.PrecacheCheckUpToDate or const.PrecacheCheckExists
    end
    local files = io.listfiles("BinAssets", "*.meta")
    for i = 1, #files do
        ResourceManager.LoadPrecacheMetadata(files[i], metaCheck)
    end
end

---
--- Mounts various game assets based on whether the game is running in unpacked or packed mode.
---
--- In unpacked mode:
--- - Mounts textures using `MountTextures(unpacked)`
--- - Mounts folders for maps and prefabs
---
--- In packed mode:
--- - Mounts music, sounds, and textures packs
--- - Creates a sound cache
--- - Mounts additional texture packs
--- - Mounts the prefabs pack
---
--- On the GED platform, it only mounts textures based on the `unpacked` flag.
---
--- @param unpacked boolean Whether the game is running in unpacked mode.
if not Platform.ged then
    -- Textures, Maps and Prefabs
    if unpacked then
        MountTextures(unpacked)
        MountFolder("Maps", "svnAssets/Source/Maps/", "create")
        MountFolder("Prefabs", "svnAssets/Source/Prefabs/", "create")
    else
        MountPack("Music", "Packs/Music.hpk")
        MountPack("Sounds", "Packs/Sounds.hpk", "seethrough,priority:high")
        CreateLRUMemoryCache("Sounds", config.SoundCacheMemorySize or 0)
        MountTextures(unpacked)
        MountPack("Textures/Cubemaps", "Packs/Cubemaps.hpk", "priority:high")
        MountPack("", "Packs/AdditionalTextures.hpk", "priority:high,seethrough,label:AdditionalTextures")
        MountPack("", "Packs/AdditionalNETextures.hpk", "priority:high,seethrough,label:AdditionalNETextures")
        MountPack("Prefabs", "Packs/Prefabs.hpk")
    end
elseif Platform.developer then -- ged
    MountTextures(unpacked)
end

---
--- Creates a real-time thread that sets the Lua and Assets revisions, and prints debug information about the build.
---
--- This function is called during the game's startup to initialize the build information.
---
--- @return nil
CreateRealTimeThread(function()
    if unpacked then
        LuaRevision = GetUnpackedLuaRevision(nil, nil, config.FallbackLuaRevision) or LuaRevision
        AssetsRevision = GetUnpackedLuaRevision(false, "svnAssets/.", config.FallbackAssetsRevision) or AssetsRevision
    else
        AssetsRevision = const.LastBinAssetsBuildRevision ~= 0 and const.LastBinAssetsBuildRevision or AssetsRevision
    end
    DebugPrint("Lua revision: " .. LuaRevision .. "\n")
    SetBuildRevision(LuaRevision)
    DebugPrint("Assets revision: " .. AssetsRevision .. "\n")
    if Platform.steam then
        DebugPrint("Steam AppID: " .. (SteamGetAppId() or "<unknown>") .. "\n")
    end
    if (BuildVersion or "") ~= "" then
        DebugPrint("Build version: " .. BuildVersion .. "\n")
    end
    if (BuildBranch or "") ~= "" then
        DebugPrint("Build branch: " .. BuildBranch .. "\n")
    end
end)

if Platform.ps4 then
	OrbisStopFakeSubmitDone()
end
