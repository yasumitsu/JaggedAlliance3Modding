--- Initializes the global state for map data and management.
-- This code is executed on the first load of the map module.
-- It sets up the initial state for map data, the current map,
-- and other related variables.
--
-- @field MapData table containing map data for all maps
-- @field mapdata false by default, replaced with MapData[map] when a map is loaded
-- @field ChangingMap false by default, set to true when the application is quitting and a map is changing
-- @field CurrentMap the name of the currently loaded map
-- @field CurrentMapFolder the folder path of the currently loaded map
-- @field CurrentMapVariation false by default, set to the MapVariationPreset if a map variation is loaded
-- @field MapPatchesApplied false by default, set to true if map patch(es) have been applied
-- @field MapPackfile table containing the contents of the map packfile
if FirstLoad then
    MapData = {} -- contains mapdata for all maps
    mapdata = false -- replaced with MapData[map] when map is loaded
    ChangingMap = false
    CurrentMap = ""
    CurrentMapFolder = ""
    CurrentMapVariation = false -- if a map variation is loaded, its MapVariationPreset (see MapData.lua)
    MapPatchesApplied = false -- if true, map patch(es) have been applied (map variation or ModItemMapPatch)
    MapPackfile = {}
end
--- Persists the current map name, map folder, and map data to the global state.
-- These values are used to track the currently loaded map and its associated data.
-- @field CurrentMap the name of the currently loaded map
-- @field CurrentMapFolder the folder path of the currently loaded map
-- @field mapdata the map data for the currently loaded map
PersistableGlobals.CurrentMap = true
PersistableGlobals.CurrentMapFolder = true
PersistableGlobals.mapdata = true

--- Initializes the global state for the published assets revisions.
-- This function is called when the game loads the constants.
-- It sorts the published assets revisions and sets the last published revision.
-- The published assets revisions are stored in the `const.PublishedAssetsRevisions` table.
-- The last published revision is stored in the `const.LastPublishedAssetsRevision` variable.
function OnMsg.LoadConsts()
    local published_revisions = const.PublishedAssetsRevisions or {}
    const.PublishedAssetsRevisions = published_revisions -- written like this to suppress the const modification code
    table.sort(published_revisions)
    const.LastPublishedAssetsRevision = published_revisions[#published_revisions] or 0
end

--- Checks if the game is currently changing maps.
-- @return boolean true if the game is changing maps, false otherwise
function IsChangingMap()
    return not not ChangingMap
end

--- Called when the application is quitting. If a map is currently loaded, sets the `ChangingMap` flag to true.
function OnMsg.ApplicationQuit()
    if GetMap() ~= "" then
        ChangingMap = true
    end
end

---
--- Returns a table of all map names.
---
--- @return table<string, boolean> A table of map names, with boolean values.
function ListMaps()
    return table.keys2(MapData, true)
end

--- Returns the map name from the given map folder path.
-- If no folder is provided, returns the currently loaded map name.
-- @param folder (string) the map folder path
-- @return (string) the map name
function GetMapName(folder)
    if not folder then
        return CurrentMap
    end
    local ret = folder:gsub("[mM]aps/", ""):gsub("/", "")
    return ret
end

--- Returns the map folder path for the given map name.
-- If no map name is provided, returns the currently loaded map folder path.
-- @param map (string) the map name
-- @return (string) the map folder path
function GetMapFolder(map)
    if not map then
        return CurrentMapFolder
    end
    if map == "" then
        return ""
    end
    local mapDataPreset = MapData[map]
    return mapDataPreset and MapDataPreset.GetSaveFolder(mapDataPreset) or string.format("Maps/%s/", map)
end

---
--- Waits for binary assets to be loaded for the specified map folder.
---
--- If mods are enabled, it first registers delayed load entities for mods, then loads the binary assets for the map folder.
--- It then waits for the binary assets to finish loading before signaling that the binary assets have been loaded.
---
--- @param map_folder string The map folder to load binary assets for.
---
function WaitLoadBinAssets(map_folder)
    if config.Mods then
        RegisterModDelayedLoadEntities(ModsLoaded)
    end
    LoadBinAssets(map_folder)
    while AreBinAssetsLoading() do
        Sleep(1)
    end
    if config.Mods then
        WaitDelayedLoadEntities()
    end
    Msg("BinAssetsLoaded")
end

---
--- Called when binary assets have finished loading.
--- Sends the "EntitiesLoaded" message.
---
function OnMsg.BinAssetsLoaded()
    Msg("EntitiesLoaded")
end

-- Note that the timeout will not be followed exactly, as we're waiting for frames
---
--- Waits for the resource manager to complete all pending requests, up to a specified timeout.
---
--- This function will wait for a specified number of frames, then check if the resource manager has any
--- outstanding requests. If there are requests, it will continue waiting until there are no requests for
--- a period of 300 milliseconds. This helps ensure that all resources have been fully loaded before
--- continuing.
---
--- @param timeout number (optional) The maximum time in milliseconds to wait for requests to complete. Defaults to 3000 (3 seconds).
--- @param frames number (optional) The number of frames to wait before checking for outstanding requests. Defaults to 3.
--- @return number The total time in seconds that the function waited for requests to complete.
---
function WaitResourceManagerRequests(timeout, frames)
    timeout = timeout or 3000
    frames = frames or 3
    local start = RealTime()
    WaitNextFrame(frames)
    local last_time_with_reads = start
    while RealTime() - start < timeout do
        WaitNextFrame()
        if not ResourceManager.HasRunningRequests() then
            if RealTime() - last_time_with_reads > 300 then
                break
            end
        else
            last_time_with_reads = RealTime()
        end
    end
    return RealTime() - start
end

---
--- Called when the current map has been unloaded.
--- Sends the "DoneMap" and "PostDoneMap" messages, unmounts the current map folder, and collects garbage.
---
function DoneMap()
    if CurrentMap ~= "" then
        Msg("DoneMap")
        Msg("PostDoneMap")
    end
    if CurrentMapFolder ~= "" then
        UnmountByPath(CurrentMapFolder)
    end
    collectgarbage("collect")
end

---
--- Preloads a map by mounting the map folder and waiting for bin assets to load.
---
--- @param map string The name of the map to preload.
--- @param folder string (optional) The folder path of the map. If not provided, it will be determined using `GetMapFolder`.
--- @return string|nil An error message if there was a problem mounting the map, or nil if the preload was successful.
---
function PreloadMap(map, folder)
    folder = folder or GetMapFolder(map)
    if map and map ~= "" then
        local err = MountMap(map, folder)
        if err then
            return err
        end
        WaitLoadBinAssets(folder)
    end
end

---
--- Mounts a map by either mounting the map pack file or the map folder.
---
--- @param map string The name of the map to mount.
--- @param folder string (optional) The folder path of the map. If not provided, it will be determined using `GetMapFolder`.
--- @return string|nil An error message if there was a problem mounting the map, or nil if the mount was successful.
---
function MountMap(map, folder)
    folder = folder or GetMapFolder(map)
    if not IsFSUnpacked() then
        local map_pack = MapPackfile[map] or string.format("Packs/Maps/%s.hpk", map)
        local err = AsyncMountPack(folder, map_pack, "seethrough")
        if map == "EmptyMap" then
            print(folder, map_pack)
        end
        assert(not err, "Map data is missing!")
        if err then
            return err
        end
    elseif not io.exists(folder) then
        assert(false, "Map folder is missing!")
        return "Path Not Found"
    end
end

---
--- Opens the map loading screen.
---
--- @param map string The name of the map to display the loading screen for.
---
function OpenMapLoadingScreen(map)
    LoadingScreenOpen("idLoadingScreen", "ChangeMap")
end

---
--- Closes the map loading screen.
---
--- @param map string The name of the map to close the loading screen for.
---
function CloseMapLoadingScreen(map)
    if map ~= "" then
        WaitResourceManagerRequests(2000)
    end
    LoadingScreenClose("idLoadingScreen", "ChangeMap")
end

---
--- Changes the current map.
---
--- @param map string The name of the map to change to.
--- @param map_variation string (optional) The variation of the map to load.
--- @param mapdata table (optional) Additional data about the map.
--- @param silent boolean (optional) If true, the map loading screen will not be shown.
--- @return string|nil An error message if there was a problem changing the map, or nil if the change was successful.
---
function DoChangeMap(map, map_variation, mapdata, silent)
    PauseGame(4)
    OpenMapLoadingScreen(map)
    WaitRenderMode("ui")

    WaitInitialDlcLoad()

    DoneMap()

    SetAllVolumesReason("ChangeMap", 0, 300)

    local folder = GetMapFolder(map)
    local err = PreloadMap(map, folder)
    Msg("MapFolderMounted", map, mapdata)
    if not err then
        CurrentMap = map
        CurrentMapFolder = folder
        _G.mapdata = mapdata

        config.NoPassability = mapdata.NoTerrain and 1 or (mapdata.DisablePassability and 1 or 0)
        hr.RenderTerrain = mapdata.NoTerrain and 0 or 1

        EngineChangeMap(CurrentMapFolder, mapdata)

        if map ~= "" then
            LoadMap(map, map_variation, mapdata, silent)
            WaitRenderMode("scene")
            PrepareMinimap()
        end
    end

    CloseMapLoadingScreen(map)
    ResumeGame(4)

    SetAllVolumesReason("ChangeMap", nil, 300)

    return err
end

---
--- Changes the current map.
---
--- @param map string The name of the map to change to.
--- @param map_variation string (optional) The variation of the map to load.
--- @param mapdata table (optional) Additional data about the map.
--- @param silent boolean (optional) If true, the map loading screen will not be shown.
--- @return string|nil An error message if there was a problem changing the map, or nil if the change was successful.
---
function ChangeMap(map, map_variation, mapdata, silent)
    assert(IsRealTimeThread())
    if not IsRealTimeThread() then
        return
    end
    local success, err = sprocall(_ChangeMap, map, map_variation, mapdata, silent)
    assert(ChangingMap == false, "ChangingMap hanged after change map done!")
    ChangingMap = false

    if not success or err then
        return err
    end

    if rawget(_G, "PlaceAndInitPromotedCObjects") then
        for obj, _ in pairs(PlaceAndInitPromotedCObjects) do
            obj:RegenerateHandle()
        end
        print("CObjects promoted to Objects had their handles regenerated, map should be re-saved.")

        PlaceAndInitPromotedCObjects = nil
    end
end

---
--- Stores the last loaded map in local storage.
---
--- This function is used to keep track of the last map that was loaded. It will not store a mod map as the last loaded map.
---
--- @return nil
---
function StoreLastLoadedMap()
    -- do not store mod map as last
    local mapPreset = MapData[CurrentMap]
    if mapPreset and mapPreset.ModMapPath then
        return
    end
    LocalStorage.last_map = CurrentMap
    LocalStorage.last_map_variation = CurrentMapVariation and CurrentMapVariation.id or nil
    SaveLocalStorage()
end

---
--- Remaps the given map name to a different name if a remapping is defined.
---
--- @param map string The map name to remap.
--- @return string The remapped map name, or the original map name if no remapping is defined.
---
function RemapMapName(map)
    local remapping = const.MapNameRemapping or empty_table
    while remapping[map] do
        map = remapping[map]
    end
    return map
end

---
--- Changes the current map to the specified map and map variation.
---
--- This function is responsible for the entire process of changing the map, including waiting for any ongoing map changes to complete, remapping the map name, firing messages, and performing the actual map change.
---
--- @param map string The name of the map to change to.
--- @param map_variation string The name of the map variation to change to.
--- @param mapdata table The map data for the new map.
--- @param silent boolean If true, the function will not print any debug messages.
--- @return string|nil The error message if the map change failed, or nil if it succeeded.
---
function _ChangeMap(map, map_variation, mapdata, silent)
    local start_time = GetPreciseTicks()

    WaitChangeMapDone()
    WaitSaveGameDone()

    map = RemapMapName(map)

    map = map or ""
    if map == "" and CurrentMap == "" then
        return
    end
    assert(not string.match(map, "aps/"))

    -- printf("Changing map to \"%s\"", tostring(map))
    mapdata = mapdata or MapData[map] or MapDataPreset:new{}
    if mapdata.MapType == "system" then
        mapdata.GameLogic = false
    end

    -- ChangingMap - used from mod tools for a message that asks the user to save the edited map
    local changing_map_handlers = {}
    Msg("ChangingMap", map, mapdata, changing_map_handlers)
    for _, handler in ipairs(changing_map_handlers) do
        handler(map, mapdata)
    end

    ChangingMap = map

    -- @@@msg ChangeMap - message fired when a new map loading begins
    Msg("ChangeMap", map, mapdata)

    local err = DoChangeMap(map, map_variation, mapdata, silent)

    ChangingMap = false
    Msg("ChangeMapDone", map, err)

    if map ~= "" then
        if err then
            DebugPrint(string.format("Map \"%s\" failed to load: %s\n", tostring(map), tostring(err)))
        else
            DebugPrint(string.format("Map changed to \"%s\" in %d ms.\n", tostring(map), GetPreciseTicks() - start_time))
        end
    end

    return err
end

--- Waits until the map change process is complete.
---
--- This function blocks until the `ChangingMap` flag is set to `false`, indicating that the map change process has finished.
--- It does this by waiting for the `"ChangeMapDone"` message to be received.
function WaitChangeMapDone()
    while ChangingMap do
        WaitMsg("ChangeMapDone")
    end
end

MapVar("GameTimeStarted", false)
---
--- Waits until the game time has started.
---
--- This function blocks until the `GameTimeStarted` flag is set to `true`, indicating that the game time has started.
--- It does this by waiting for the `"GameTimeStart"` message to be received.
---
function WaitGameTimeStart()
    if not GameTimeStarted then
        WaitMsg("GameTimeStart")
    end
end

MapVar("MapPassable", false)
---
--- Waits until the map is passable.
---
--- This function blocks until the `MapPassable` flag is set to `true`, indicating that the map is passable.
--- It does this by waiting for the `"NewMapPassable"` message to be received.
---
function WaitMapPassable()
    if not MapPassable then
        WaitMsg("NewMapPassable")
    end
end

MapVar("GameTimeAdvanced", false)

---
--- Loads a new map and performs various initialization tasks.
---
--- This function is responsible for loading a new map, including loading objects, applying map variations, and performing other initialization tasks.
---
--- @param map string The name of the map to load.
--- @param map_variation string The name of the map variation to apply.
--- @param mapdata table Additional map data.
--- @param silent boolean If true, suppresses some output messages.
---
--- @return string|nil An error message if the map failed to load, or nil if the load was successful.
---
function LoadMap(map, map_variation, mapdata, silent)
    PauseInfiniteLoopDetection("LoadMap")
    Msg("PreNewMap", map, mapdata)
    CreateGameTimeThread(function()
        PauseInfiniteLoopDetection("GameTimeStart")
        GameTimeStarted = true
        Msg("GameTimeStart")
        ResumeInfiniteLoopDetection("GameTimeStart")
        Sleep(1)
        GameTimeAdvanced = true
    end)
    Msg("NewMap", map, mapdata)

    -- load objects
    InterruptAdvance()
    InterruptAdvance()

    collectgarbage("stop")

    config.PartialPassEdits = false
    SuspendPassEdits("LoadMap", true)

    if io.exists(GetMap() .. "objects.lua") then
        LoadObjects(GetMap() .. "objects.lua")
        InterruptAdvance()
    end

    InterruptAdvance()

    if io.exists(GetMap() .. "autorun.lua") then
        dofile(GetMap() .. "autorun.lua")
    end

    MapForEach("map", "Template", function(o)
        if o.autospawn then
            o:Spawn()
        end
    end)

    -- @@@msg NewMapLoadAdditionalObjects - fired after objects.lua and GetMap()..autorun.lua 
    -- have been executed to allow loading of additional objects before firing NewMapLoaded.
    -- Used by map variations, and by ModItemMapPatch to load map patches
    MapPatchesApplied = false -- will be set if a patch is applied below
    ApplyMapVariation(map_variation)
    Msg("NewMapLoadAdditionalObjects", map)

    -- @@@msg NewMapLoaded - fired after a new map has been loaded
    Msg("NewMapLoaded")
    -- free NewMapLoaded temp memory
    collectgarbage("collect")
    collectgarbage("restart")

    ResumePassEdits("LoadMap")
    config.PartialPassEdits = true

    MapPassable = true
    Msg("NewMapPassable")

    SuspendPassEdits("GameInit")
    AdvanceGameTime(0) -- run GameInit methods
    ResumePassEdits("GameInit")

    Msg("PostNewMapLoaded", silent)

    ResumeInfiniteLoopDetection("LoadMap")
    ResumeAnim()
end

---
--- Loads objects from the specified Lua file.
---
--- This function is responsible for loading objects from a Lua file and performing additional processing on them.
---
--- @param filename string The path to the Lua file containing the object definitions.
---
function LoadObjects(filename)
    assert(IsRealTimeThread())
    local postload = {}
    local gofPermanent = const.gofPermanent
    local origPersistFlagState = config.PersistLuaFlagsLoaded
    local SetGameFlags = CObject.SetGameFlags
    local fenv = LuaValueEnv({SetNextSyncHandle=function(h)
        NextSyncHandle = h
    end, PlaceObj=function(class, props, arr, handle)
        local obj = PlaceObj(class, props, arr, handle)
        local ancestors = obj and obj.__ancestors
        if ancestors and ancestors.CObject then
            SetGameFlags(obj, gofPermanent)
            if ancestors.Object then
                postload[1 + #postload] = obj
            end
        end
        return obj
    end, o=ResolveHandle, PlaceAndInit4=PlaceAndInit4, PlaceAndInit_v2=PlaceAndInit_v2, PlaceAndInit_v3=PlaceAndInit_v3,
        PlaceAndInit_v4=PlaceAndInit_v4, PlaceAndInit_v5=PlaceAndInit_v5, LoadPersistFlagTables=LoadPersistFlagTables,
        LoadGrid16=function(str)
            return LoadGrid(Decode16(str))
        end, -- backward compatibility
        LoadGrid=function(str)
            return LoadGrid(str)
        end, GridReadStr=GridReadStr, T=T, DisablePersistFlagOverrides=function()
            config.PersistLuaFlagsLoaded = false
        end, RestorePersistFlagOverrides=function()
            config.PersistLuaFlagsLoaded = origPersistFlagState
        end})
    local func, err = loadfile(filename, nil, fenv)
    assert(func, err)
    if func then
        func()
        for i = 1, #postload do
            postload[i]:PostLoad()
        end
    end
end

if FirstLoad then
	s_SuspendPassEditsReasons = {}
	engineSuspendPassEdits = SuspendPassEdits
	engineResumePassEdits = ResumePassEdits
end

---
--- Suspends pass edits for the specified reason. If `bSurfaces` is true, all pass edits are suspended. Otherwise, only the pass edits for the specified reason are suspended.
---
--- @param reason string|table The reason for suspending pass edits. Can be a string or a table with a `class` field.
--- @param bSurfaces boolean If true, all pass edits are suspended. Otherwise, only the pass edits for the specified reason are suspended.
--- @param ignore_errors boolean If true, any errors during the suspension are ignored.
---
function SuspendPassEdits(reason, bSurfaces, ignore_errors)
    assert(reason ~= nil)
    if next(s_SuspendPassEditsReasons) == nil or bSurfaces then
        engineSuspendPassEdits(bSurfaces)
        Msg("SuspendPassEdits", ignore_errors)
    end
    assert(ignore_errors or not s_SuspendPassEditsReasons[reason]) -- a present reason could lead to preliminary resuming later or to indicate that the resume has never happenned
    s_SuspendPassEditsReasons[reason] = GameTime()
end

---
--- Clears the table of reasons for suspending pass edits.
---
--- This function is called in response to the `ChangeMap` message, which is likely triggered when the game map is changed.
---
--- By clearing the `s_SuspendPassEditsReasons` table, this function ensures that any previously suspended pass edits are reset when the map is changed, allowing the new map to be properly rendered.
---
function OnMsg.ChangeMap()
    s_SuspendPassEditsReasons = {}
end

---
--- Resumes pass edits that were previously suspended for the specified reason.
---
--- If the specified reason is not found in the `s_SuspendPassEditsReasons` table, this function does nothing.
---
--- If the `ignore_errors` parameter is true, any errors that occur during the resume process will be ignored.
---
--- @param reason string|table The reason for which pass edits were suspended. Can be a string or a table with a `class` field.
--- @param ignore_errors boolean If true, any errors during the resume process are ignored.
---
function ResumePassEdits(reason, ignore_errors)
    assert(reason ~= nil)
    if not s_SuspendPassEditsReasons[reason] then
        return
    end
    -- any suspend/resume should be completed within the millisecond
    assert(GameTime() == 0 or s_SuspendPassEditsReasons[reason] == GameTime() or ignore_errors)
    s_SuspendPassEditsReasons[reason] = nil
    if next(s_SuspendPassEditsReasons) == nil then
        engineResumePassEdits()
        Msg("ResumePassEdits", ignore_errors)
    end
end

-- apply any suspended pass edits, without resuming
---
--- Applies any previously suspended pass edits.
---
--- If no reason is provided, all suspended pass edits are resumed and then suspended again.
--- If a reason is provided, the pass edits suspended for that reason are resumed and then suspended again.
---
--- @param reason string|table The reason for which pass edits were suspended. Can be a string or a table with a `class` field.
---
function ApplyPassEdits(reason)
    local suspended, surfaces = IsPassEditSuspended()
    if not suspended then
        return
    end
    if reason == nil then
        engineResumePassEdits()
        engineSuspendPassEdits(surfaces)
    elseif s_SuspendPassEditsReasons[reason] then
        ResumePassEdits(reason)
        SuspendPassEdits(reason, surfaces)
    end
end

---
--- Waits for pass edits to be resumed if they are currently suspended.
---
--- This function will block until the `ResumePassEdits` function is called, at which point it will return.
---
function WaitResumePassEdits()
    if IsPassEditSuspended() then
        WaitMsg("ResumePassEdits")
    end
end

---
--- Prints the reasons for which pass edits have been suspended.
---
--- @param print_func function The function to use for printing the reasons. Defaults to `print`.
---
function _PrintSuspendPassEditsReasons(print_func)
    print_func = print_func or print
    for reason in pairs(s_SuspendPassEditsReasons) do
        if type(reason) == "table" then
            print_func("\t" .. (reason.class or ValueToLuaCode(reason)))
        else
            print_func("\t" .. tostring(reason))
        end
    end
end

---
--- Prints the reasons for which pass edits have been suspended when a bug report is started.
---
--- This function is called when a bug report is started. It checks if there are any active reasons for suspending pass edits, and if so, it prints those reasons using the provided print function.
---
--- @param print_func function The function to use for printing the reasons. Defaults to `print`.
---
function OnMsg.BugReportStart(print_func)
    if next(s_SuspendPassEditsReasons) ~= nil then
        print_func("Active suspend pass edits reasons:")
        _PrintSuspendPassEditsReasons(print_func)
        print_func("")
    end
end

---
--- Checks if pass edits are currently suspended.
---
--- @return boolean true if pass edits are not suspended, false otherwise
--- @return string|nil The reason why pass edits are suspended, if any
---
function CheckPassEditsNotSuspended()
    if not IsPassEditSuspended() then
        return true
    end
    local reason = next(s_SuspendPassEditsReasons)
    reason = ObjectClass(reason) and reason.class or tostring(reason)
    return false, "Pass edits suspended: " .. reason
end

if FirstLoad then
	MapReloadInProgress = false
end

---
--- Reloads the current map, optionally restoring the camera position.
---
--- @param restore_camera boolean If true, the camera position will be restored after the map is reloaded.
---
function ReloadMap(restore_camera)
    local camera = restore_camera and {GetCamera()}
    local ineditor = Platform.editor and IsEditorActive()
    XShortcutsSetMode("Game") -- will exit editor mode
    if ineditor then
        Pause("ReloadMap")
    end
    LoadingScreenOpen("idLoadingScreen", "reload map")
    MapReloadInProgress = true
    ChangeMap(CurrentMap, CurrentMapVariation and CurrentMapVariation.id)
    MapReloadInProgress = false
    if ineditor then
        EditorActivate()
        Resume("ReloadMap")
    end
    if camera then
        SetCamera(table.unpack(camera))
    end
    LoadingScreenClose("idLoadingScreen", "reload map")
end

-- returns a list of (parts * parts) boxes covering the whole map, can be shuffled if given a random value
---
--- Returns a list of (parts * parts) boxes covering the whole map.
---
--- @param parts integer The number of parts to divide the map into.
--- @param rand function|nil A random function to shuffle the boxes.
--- @return table A list of boxes covering the map.
---
function GetMapBoxesCover(parts, rand)
    local width, height = terrain.GetMapSize()
    local slice_width = (width + parts - 1) / parts
    local slice_height = (height + parts - 1) / parts
    local boxes = {}
    for y = 1, parts do
        for x = 1, parts do
            boxes[#boxes + 1] = box((x - 1) * slice_width, (y - 1) * slice_height, x * slice_width, y * slice_height)
        end
    end
    if rand then
        table.shuffle(boxes, rand)
    end
    return boxes
end

---
--- Filters the list of game maps based on certain criteria.
---
--- @param id string The ID of the map.
--- @param map_data table The map data for the given ID.
--- @return boolean Whether the map should be included in the list of game maps.
---
function GameMapFilter(id, map_data)
    if IsTestMap(id) or IsModEditorMap(id) then
        return
    end
    map_data = map_data or MapData[id]
    return map_data.GameLogic
end

---
--- Returns a list of all game maps that pass the `GameMapFilter` function.
---
--- @return table A list of game map IDs.
---
function GetAllGameMaps()
    local maps = {}
    for id, map_data in pairs(MapData) do
        if GameMapFilter(id, map_data) then
            maps[#maps + 1] = id
        end
    end
    table.sort(maps)
    return maps
end

----

---
--- Checks if the given map name is a test map.
---
--- @param map_name string The name of the map to check.
--- @return boolean True if the map is a test map, false otherwise.
---
function IsTestMap(map_name)
    return map_name:starts_with("__")
end

---
--- Checks if the given map name is an old map.
---
--- @param map_name string The name of the map to check.
--- @return boolean True if the map is an old map, false otherwise.
---
function IsOldMap(map_name)
    return map_name:find("_old", 1, true)
end

--- Checks if the given map is a prefab map.
---
--- @param map_name string The name of the map to check.
--- @param map_data table The map data for the given map name.
--- @return boolean Whether the map is a prefab map.
function IsPrefabMap(map_name, map_data)
    map_data = map_data or MapData[map_name]
    return map_data and map_data.IsPrefabMap
end

---
--- Returns the original map name, removing any "_old" suffix.
---
--- @param map_name string The map name to get the original name for.
--- @return string The original map name without any "_old" suffix.
---
function GetOrigMapName(map_name)
    map_name = map_name or GetMapName()
    local idx = IsOldMap(map_name)
    return not idx and map_name or string.sub(map_name, 1, idx - 1)
end

---
--- Returns the path to the mapdata.lua file for the given map.
---
--- @param map string The name of the map.
--- @return string The path to the mapdata.lua file.
---
function GetMapdataPath(map)
    return GetMapFolder(map) .. "mapdata.lua"
end

---
--- Returns the revision of the map data for the given map.
---
--- @param map string The name of the map.
--- @return number The revision of the map data.
---
function QueryMapRevision(map)
    local _, svn_info = GetSvnInfo(GetMapdataPath(map))
    return svn_info and svn_info.last_revision or 0
end


if Platform.asserts then

    ---
    --- Gathers game metadata, including the hash of the terrain passability.
    ---
    --- @param metadata table The metadata table to populate.
    ---
    function OnMsg.GatherGameMetadata(metadata)
        metadata.pass_hash = terrain.HashPassability()
    end

    ---
    --- Handles the event when game metadata is loaded.
    ---
    --- This function checks if the passability hash from the savegame matches the current passability hash. If there is a mismatch, it prints a warning message.
    ---
    --- @param meta table The game metadata table.
    ---
    function OnMsg.GameMetadataLoaded(meta)
        if meta.lua_revision == LuaRevision and meta.assets_revision == AssetsRevision and meta.pass_hash
            and meta.pass_hash ~= terrain.HashPassability() then
            print("Savegame passability hash mismatch!")
        end
    end

end -- Platform.asserts
