if FirstLoad then
	Game = false
end
PersistableGlobals.Game = true

if not Platform.ged then
DefineClass.GameClass = {
	__parents = { "CooldownObj", "GameSettings", "LabelContainer" },
}
end

---
--- Starts a new game session.
---
--- @param game table|GameClass The game object to start. If not an instance of `GameClass`, it will be wrapped in a new `GameClass` instance.
--- @return table The started game object.
function NewGame(game)
    DoneGame()
    if not IsKindOf(game, "GameClass") then
        game = GameClass:new(game)
    end
    game.save_id = nil
    Game = game
    InitGameVars()
    Msg("NewGame", game)
    NetGossip("NewGame", game.id, GetGameSettingsTable(game))
    return game
end

---
--- Ends the current game session.
---
--- This function is responsible for cleaning up the game state and resources when a game session is completed.
---
--- @param game table|GameClass The game object to end. If not an instance of `GameClass`, it will be assumed to be the global `Game` object.
function DoneGame(game)
    local game = Game
    if not game then
        return
    end
    NetGossip("DoneGame", GameTime(), game.id)
    DoneGameVars()
    Game = false
    Msg("DoneGame", game)
    game:delete()
end
function DoneGame()
    local game = Game
    if not game then
        return
    end
    NetGossip("DoneGame", GameTime(), game.id)
    DoneGameVars()
    Game = false
    Msg("DoneGame", game)
    game:delete()
end

---
--- Reloads the current map.
---
function DevReloadMap()
    ReloadMap(true)
end

---
--- Restarts the current game session.
---
--- This function is responsible for reloading the original map and creating a new game instance with the same settings as the current game.
---
--- @return nil
function RestartGame()
    CreateRealTimeThread(function()
        LoadingScreenOpen("idLoadingScreen", "RestartGame")
        local map = GetOrigMapName()
        local game2 = CloneObject(Game)
        ChangeMap("")
        NewGame(game2)
        ChangeMap(map)
        LoadingScreenClose("idLoadingScreen", "RestartGame")
    end)
end

---
--- Restarts the current game session from the menu.
---
--- This function is responsible for reloading the original map and creating a new game instance with the same settings as the current game. It first prompts the user to confirm the restart, and then opens a loading screen before restarting the game.
---
--- @param host table The host object for the menu.
--- @param parent table The parent object for the menu.
--- @return nil
function RestartGameFromMenu(host, parent)
    CreateRealTimeThread(function(host, parent)
        if WaitQuestion(parent or host, T(354536203098, "<RestartMapText()>"),
            T(1000852, "Are you sure you want to restart the map? Any unsaved progress will be lost."),
            T(147627288183, "Yes"), T(1139, "No")) == "ok" then
            LoadingScreenOpen("idLoadingScreen", "RestartMap")
            if host.window_state ~= "destroying" then
                host:Close()
            end
            RestartGame()
            LoadingScreenClose("idLoadingScreen", "RestartMap")
        end
    end, host, parent)
end

---
--- Handles the change of the current map.
---
--- This function is called when the current map is changed. It sets the game state to "gameplay" and sets the flag to false, indicating that the game is no longer in the gameplay state.
---
--- @param map string The name of the new map.
--- @param mapdata table The data associated with the new map.
--- @return nil
function OnMsg.ChangeMap(map, mapdata)
    ChangeGameState("gameplay", false)
end

---
--- Returns the default game parameters.
---
--- This function is used to initialize a new game instance with the default game settings.
---
--- @return table The default game parameters.
function GetDefaultGameParams()
end

---
--- Handles the initialization of a new game when a new map is loaded.
---
--- This function is called when a new map is loaded, and it checks if the map has game logic and is not a system map. If these conditions are met, it creates a new game instance using the default game parameters.
---
--- @param map string The name of the new map.
--- @param mapdata table The data associated with the new map.
--- @return nil
function OnMsg.PreNewMap(map, mapdata)
    if map ~= "" and not Game and mapdata.GameLogic and mapdata.MapType ~= "system" then
        NewGame(GetDefaultGameParams())
    end
end

---
--- Handles the completion of a map change.
---
--- This function is called when a map change has completed. It checks if the new map has game logic, and if so, sets the game state to "gameplay" and sets the flag to true, indicating that the game is now in the gameplay state.
---
--- @param map string The name of the new map.
--- @param mapdata table The data associated with the new map.
--- @return nil
function OnMsg.ChangeMapDone(map, mapdata)
end
function OnMsg.ChangeMapDone(map)
    if map ~= "" and mapdata.GameLogic then
        ChangeGameState("gameplay", true)
    end
end

---
--- Handles the loading of a saved game.
---
--- This function is called when a saved game is loaded. It checks if a map is currently loaded, and if so, it changes the game state to "gameplay" and sets the flag to true, indicating that the game is now in the gameplay state. It then retrieves the saved game settings and sends a network message to notify other clients of the loaded game.
---
--- @return nil
function OnMsg.LoadGame()
    assert(GetMap() ~= "")
    ChangeGameState("gameplay", true)
    if not Game then
        return
    end
    Game.loaded_from_id = Game.save_id
    NetGossip("LoadGame", Game.id, Game.loaded_from_id, GetGameSettingsTable(Game))
end

---
--- Handles the start of saving a game.
---
--- This function is called when the game is about to be saved. It generates a unique save ID for the current game and sends a network message to notify other clients of the save.
---
--- @return nil
function OnMsg.SaveGameStart()
    if not Game then
        return
    end
    Game.save_id = random_encode64(48)
    NetGossip("SaveGame", GameTime(), Game.id, Game.save_id)
end

---
--- Returns a table containing the game settings for the specified game object.
---
--- @param game GameSettings The game settings object to retrieve the settings from.
--- @return table The table of game settings.
function GetGameSettingsTable(game)
    local settings = {}
    assert(IsKindOf(game, "GameSettings"))
    for _, prop_meta in ipairs(GameSettings:GetProperties()) do
        settings[prop_meta.id] = game:GetProperty(prop_meta.id)
    end
    return settings
end

---
--- Sends a network message when a new map is loaded.
---
--- This function is called when a new map is loaded. It sends a network message to notify other clients of the new map name and the random seed used to load the map.
---
--- @return nil
function OnMsg.NewMap()
    NetGossip("map", GetMapName(), MapLoadRandom)
end

---
--- Sends a network message when the map changes.
---
--- This function is called when the map changes. It sends a network message to notify other clients of the new map name.
---
--- @param map string The name of the new map.
--- @return nil
function OnMsg.ChangeMap(map)
    if map == "" then
        NetGossip("map", "")
    end
end

---
--- Sends a network message when a new player connects to the game.
---
--- This function is called when a new player connects to the game. It sends a network message to notify other clients of the current game state, including the game time, game ID, loaded game ID, map name, map random seed, and game settings.
---
--- @return nil
function OnMsg.NetConnect()
    if Game then
        NetGossip("GameInProgress", GameTime(), Game.id, Game.loaded_from_id, GetMapName(), MapLoadRandom,
            GetGameSettingsTable(Game))
    end
end

---
--- Prints the game settings table when a bug report is started.
---
--- This function is called when a bug report is started. It retrieves the game settings table using the `GetGameSettingsTable` function and prints it to the bug report output.
---
--- @param print_func function The function to use for printing the game settings.
--- @return nil
function OnMsg.BugReportStart(print_func)
    if Game then
        print_func("\nGameSettings:", TableToLuaCode(GetGameSettingsTable(Game), " "), "\n")
    end
end


-- GameVars (persistable, reset on new game)

GameVars = {}
GameVarValues = {}

---
--- Registers a new game variable with the specified name, initial value, and optional metadata.
---
--- Game variables are global variables that persist across game sessions. They can be used to store game state that needs to be preserved between sessions.
---
--- If the initial value is a table, it will be copied and the copy will be assigned to the game variable. This ensures that modifications to the table do not affect the original value.
---
--- If the game variable does not already exist, it will be initialized to `false`.
---
--- @param name string The name of the game variable.
--- @param value any The initial value of the game variable.
--- @param meta table (optional) The metatable to apply to the game variable if it is a table.
--- @return nil
function GameVar(name, value, meta)
    if type(value) == "table" then
        local org_value = value
        value = function()
            local v = table.copy(org_value, false)
            setmetatable(v, getmetatable(org_value) or meta)
            return v
        end
    end
    if FirstLoad or rawget(_G, name) == nil then
        rawset(_G, name, false)
    end
    GameVars[#GameVars + 1] = name
    GameVarValues[name] = value or false
    PersistableGlobals[name] = true
end

---
--- Initializes all registered game variables with their initial values.
---
--- This function iterates through the list of registered game variables (`GameVars`) and sets each variable in the global namespace (`_G`) to its initial value. If the initial value is a function, it is called to get the actual value to be assigned.
---
--- This function is typically called during game initialization or when a new game is started.
---
--- @function InitGameVars
--- @return nil
function InitGameVars()
    for _, name in ipairs(GameVars) do
        local value = GameVarValues[name]
        if type(value) == "function" then
            value = value()
        end
        _G[name] = value or false
    end
end

---
--- Resets all registered game variables to their initial values.
---
--- This function iterates through the list of registered game variables (`GameVars`) and sets each variable in the global namespace (`_G`) to `false`. This effectively resets all game variables to their default state.
---
--- This function is typically called when the game is done, such as when the player exits the game or a game session ends.
---
--- @function DoneGameVars
--- @return nil
function DoneGameVars()
    for _, name in ipairs(GameVars) do
        _G[name] = false
    end
end

---
--- Handles the persistence of game variables after a game is loaded.
---
--- This function is called when a game is loaded, and it ensures that any missing game variables are created and initialized with their default values. This is necessary to handle cases where new game variables have been added since the last save, or where a save file was created before certain game variables were introduced.
---
--- The function iterates through the list of registered game variables (`GameVars`) and checks if the corresponding value is present in the loaded game data (`data`). If the value is missing, it retrieves the default value from the `GameVarValues` table and assigns it to the global namespace (`_G`).
---
--- This function is typically called as a response to the `OnMsg.PersistPostLoad` event, which is triggered after a game has been loaded.
---
--- @function OnMsg.PersistPostLoad
--- @param data table The loaded game data
--- @return nil
function OnMsg.PersistPostLoad(data)
    -- create missing game vars (unexisting at the time of the save)
    for _, name in ipairs(GameVars) do
        if data[name] == nil then
            local value = GameVarValues[name]
            if type(value) == "function" then
                value = value()
            end
            _G[name] = value or false
        end
    end
end

---
--- Returns a table containing the current values of all registered game variables.
---
--- This function iterates through the list of registered game variables (`GameVars`) and creates a table containing the current value of each variable in the global namespace (`_G`). The resulting table is returned.
---
--- This function is typically used to save the current state of the game variables, for example when saving the game.
---
--- @function GetCurrentGameVarValues
--- @return table A table containing the current values of all registered game variables
function GetCurrentGameVarValues()
    local gvars = {}
    for _, name in ipairs(GameVars) do
        gvars[name] = _G[name]
    end
    return gvars
end

---
--- Returns a table containing the current values of all registered game variables that are marked as persistable.
---
--- This function iterates through the list of registered game variables (`GameVars`) and creates a table containing the current value of each variable in the global namespace (`_G`) that is marked as persistable in the `PersistableGlobals` table. The resulting table is returned.
---
--- This function is typically used to save the current state of the persistable game variables, for example when saving the game.
---
--- @function GetPersistableGameVarValues
--- @return table A table containing the current values of all registered persistable game variables
function GetPersistableGameVarValues()
    local gvars = {}
    for _, name in ipairs(GameVars) do
        if PersistableGlobals[name] then
            gvars[name] = _G[name]
        end
    end
    return gvars
end

----

GameVar("LastPlaytime", 0)
---
--- Resets the `PlaytimeCheckpoint` global variable to `false` when the game is first loaded.
---
--- This code is executed when the game is first loaded, either through a new game or loading a saved game. It sets the `PlaytimeCheckpoint` global variable to `false`, which will cause the `GetCurrentPlaytime()` function to return `0` until the `OnMsg.SaveGameStart()` function is called and updates the `PlaytimeCheckpoint` variable.
---
--- This is typically used to reset the playtime tracking when a new game is started or a saved game is loaded.
---
if FirstLoad then
    PlaytimeCheckpoint = false
end
---
--- Saves the current playtime and sets a checkpoint for calculating future playtime.
---
--- This function is called when the game is about to be saved. It records the current playtime by calling `GetCurrentPlaytime()` and stores the result in the `LastPlaytime` global variable. It also sets the `PlaytimeCheckpoint` global variable to the current precise tick count, which will be used to calculate future playtime.
---
--- This function is typically called in response to the `OnMsg.SaveGameStart` message.
---
function OnMsg.SaveGameStart()
    LastPlaytime = GetCurrentPlaytime()
    PlaytimeCheckpoint = GetPreciseTicks()
end
---
--- Resets the `PlaytimeCheckpoint` global variable when the game is loaded.
---
--- This function is called when the game is loaded, either through a new game or loading a saved game. It sets the `PlaytimeCheckpoint` global variable to the current precise tick count, which will be used to calculate future playtime.
---
--- This is typically used to reset the playtime tracking when a new game is started or a saved game is loaded.
---
function OnMsg.LoadGame()
    PlaytimeCheckpoint = GetPreciseTicks()
end
---
--- Resets the `PlaytimeCheckpoint` global variable when a new game is started.
---
--- This function is called when a new game is started. It sets the `PlaytimeCheckpoint` global variable to the current precise tick count, which will be used to calculate future playtime.
---
--- This is typically used to reset the playtime tracking when a new game is started.
---
function OnMsg.NewGame()
    PlaytimeCheckpoint = GetPreciseTicks() -- also called on LoadGame
end
---
--- Resets the `PlaytimeCheckpoint` global variable to `false` when the game is finished.
---
--- This function is called in response to the `OnMsg.DoneGame` message, which is triggered when the game is finished. It sets the `PlaytimeCheckpoint` global variable to `false`, which will cause the `GetCurrentPlaytime()` function to return `0` until the `OnMsg.SaveGameStart()` function is called and updates the `PlaytimeCheckpoint` variable.
---
--- This is typically used to reset the playtime tracking when the game is finished.
---
function OnMsg.DoneGame()
    PlaytimeCheckpoint = false
end
---
--- Returns the current playtime since the last checkpoint.
---
--- The `PlaytimeCheckpoint` global variable is used to track the start time of the current playtime period. The `LastPlaytime` global variable is used to track the total playtime up to the last checkpoint.
---
--- This function calculates the current playtime by adding the time elapsed since the last checkpoint to the total playtime up to the last checkpoint.
---
--- @return number The current playtime in milliseconds.
---
function GetCurrentPlaytime()
    return PlaytimeCheckpoint and (LastPlaytime + (GetPreciseTicks() - PlaytimeCheckpoint)) or 0
end
---
--- Formats the given time in milliseconds into a string representation using the specified format.
---
--- The format string can contain the following characters:
--- - 'd': days
--- - 'h': hours
--- - 'm': minutes
--- - 's': seconds
---
--- If no format is specified, the default format is "dhms".
---
--- @param time number The time in milliseconds to format.
--- @param format string The format string to use.
--- @return number... The formatted time components (days, hours, minutes, seconds).
---
function FormatElapsedTime(time, format)
    format = format or "dhms"
    local sec = 1000
    local min = 60 * sec
    local hour = 60 * min
    local day = 24 * hour

    local res = {}
    if format:find_lower("d") then
        res[#res + 1] = time / day
        time = time % day
    end
    if format:find_lower("h") then
        res[#res + 1] = time / hour
        time = time % hour
    end
    if format:find_lower("m") then
        res[#res + 1] = time / min
        time = time % min
    end
    if format:find_lower("s") then
        res[#res + 1] = time / sec
        time = time % sec
    end
    res[#res + 1] = time

    return table.unpack(res)
end

if Platform.asserts then

    ---
    --- Called when a new map is loaded.
    --- Saves the current game state as the last game state.
    ---
    --- This function iterates through all the properties marked as `remember_as_last` in the `GameSettings`, and compares their current values to the last saved values. If any values have changed, it updates the `last_game` table in `LocalStorage` and saves it.
    ---
    --- @function OnMsg.NewMapLoaded
    --- @return nil
    function OnMsg.NewMapLoaded()
        if not Game then
            return
        end
        local last_game = LocalStorage.last_game
        local count = 0
        for _, prop_meta in ipairs(GameSettings:GetProperties()) do
            if prop_meta.remember_as_last then
                local value = Game[prop_meta.id]
                last_game = last_game or {}
                if value ~= last_game[prop_meta.id] then
                    last_game[prop_meta.id] = value
                    count = count + 1
                end
            end
        end
        if count == 0 then
            return
        end
        LocalStorage.last_game = last_game
        SaveLocalStorageDelayed()
    end

end -- Platform.asserts

