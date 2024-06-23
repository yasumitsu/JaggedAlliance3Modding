
---
--- Gathers and stores permanent objects and functions that can be safely persisted.
--- This function is called during the game save process to gather all the permanent
--- objects and functions that need to be stored in the save file.
---
--- @param permanents table A table that will be used to store the permanent objects and functions.
---
function OnMsg.PersistGatherPermanents(permanents)
    permanents["point.meta"] = getmetatable(point20)
    permanents["box.meta"] = getmetatable(box(0, 0, 0, 0))
    permanents["quaternion.meta"] = getmetatable(quaternion())
    permanents["range.meta"] = getmetatable(range(0, 0))
    permanents["set.meta"] = getmetatable(set())
    permanents["pstr.meta"] = getmetatable(pstr())
    permanents["grid.meta"] = getmetatable(NewGrid(1, 1, 1))
    if rawget(_G, "grid") then
        permanents["XMgrid.meta"] = getmetatable(grid(1))
    end
    -- add some functions as permanents so they can be safely stored in upvalues
    permanents["table.find"] = table.find
    permanents["table.ifind"] = table.ifind
    permanents["table.find_value"] = table.find_value
    permanents["table.findfirst"] = table.findfirst
    permanents["table.insert"] = table.insert
    permanents["table.remove"] = table.remove
    permanents["table.remove_value"] = table.remove_value
    permanents["table.equal_values"] = table.equal_values
    permanents["table.clear"] = table.clear
    permanents["table.move"] = table.move
    permanents["table.icopy"] = table.icopy
    permanents["Min"] = Min
    permanents["Max"] = Max
    permanents["Clamp"] = Clamp
    permanents["MulDivRound"] = MulDivRound
    permanents["AngleDiff"] = AngleDiff
    permanents["IsValid"] = IsValid
    permanents["IsValidPos"] = IsValidPos
    permanents["IsKindOf"] = IsKindOf
    permanents["IsKindOfClasses"] = IsKindOfClasses
end

---
--- A placeholder function that is persisted instead of unpersistable functions.
--- This function is used as a fallback when a function cannot be persisted, and it
--- will assert when called to indicate that an unpersisted function was accessed.
---
--- @function __unpersisted_function__
--- @return nil
function __unpersisted_function__() -- persisted instead of unpersistable functions
    assert(false, "Unpersisted function!") -- assert added to track where is the problem
end

---
--- Generates the data needed to save the game state.
---
--- This function gathers all the permanent objects and functions that need to be stored in the save file, and returns an inverse mapping of those permanents as well as the actual save data.
---
--- @return table inv_permanents The inverse mapping of permanent objects and functions.
--- @return table data The actual save data.
---
function GetLuaSaveGameData()
    local inv_permanents = createtable(0, 32768)
    local t = {}
    setmetatable(t, {__newindex=function(t, key, value)
        assert(not inv_permanents[value] or inv_permanents[value] == key, "A value is stored under two different labels")
        inv_permanents[value] = key
    end})
    t["_G"] = _G
    Msg("PersistGatherPermanents", t, "save")
    local data = createtable(0, 2048)
    Msg("PersistSave", data)
    setmetatable(inv_permanents, {__index=__indexSavePermanents})
    return inv_permanents, data
end

---
--- Loads a missing permanent object or function during game load.
---
--- This function is called by `__indexLoadPermanents` to handle the case where a permanent object or function is missing from the save data. It attempts to recreate the missing permanent using the class information stored in the save data.
---
--- @param permanents table The table of permanent objects and functions.
--- @param id string The identifier of the missing permanent.
--- @return any The recreated permanent object or function, or `false` if it could not be recreated.
---

function LoadMissingPermanent(permanents, id) -- called by __indexLoadPermanents for better performance instead of replacing __indexLoadPermanents
	local permanent
	if type(id) == "string" then
		local colon = type(id) == "string" and id:find(":", 2, true)
		if colon then
			local baseclass = g_Classes[id:sub(1, colon - 1)] or UnpersistedMissingClass
			local func = baseclass.UnpersistMissingClass
			permanent = func and func(baseclass, id, permanents) or UnpersistedMissingClass
		end
	end
	permanents[id] = permanent or false
	GameTestsError("Unpersist missing permanent:", id, "| Fallback permanent:", permanent and permanent.class or false)
	return permanent
end

---
--- Generates the table of permanent objects and functions that need to be loaded during game load.
---
--- This function gathers all the permanent objects and functions that need to be loaded from the save data, and returns an inverse mapping of those permanents.
---
--- @return table permanents The inverse mapping of permanent objects and functions.
---
function GetLuaLoadGamePermanents()
    local permanents = createtable(0, 32768)
    local t = {}
    setmetatable(t, {__newindex=function(t, key, value)
        assert(not permanents[key] or permanents[key] == value, "A label references two different values")
        permanents[key] = value
    end})
    t["_G"] = _G
    Msg("PersistGatherPermanents", t, "load")
    Msg("PersistPreLoad")
    setmetatable(permanents, {__index=__indexLoadPermanents})
    return permanents
end

---
--- Loads the game data from the provided data table.
---
--- This function is called during game load to restore the state of the game from the saved data. It triggers the `PersistLoad` and `PersistPostLoad` messages, which allow other systems to load their own data from the saved data.
---
--- @param data table The table of saved game data.
---
function LuaLoadGameData(data)
    Msg("PersistLoad", data)
    Msg("PersistPostLoad", data)
end

-- easy syntax for persist (save/load) of global variables
-- PersistableGlobals.<var_name> = true

---
--- Saves the values of persistable global variables to the provided data table.
---
--- This function is called during game save to store the current state of persistable global variables in the saved game data. It iterates through the `PersistableGlobals` table and copies the values of the marked global variables to the `data` table. It also ensures that any realtime threads associated with the persistable global variables have the appropriate persistence flag set.
---
--- @param data table The table to store the saved game data in.
---
function OnMsg.PersistSave(data)
    local threadFlagPersist = 2 ^ 20
    for k, v in pairs(PersistableGlobals) do
        if v then
            data[k] = _G[k]
            -- only certain realtime threads can be persisted
            assert(not IsValidThread(_G[k]) or ThreadHasFlags(_G[k], threadFlagPersist),
                "Persistable global var '" .. k .. "' has value a non-persistable realtime thread")
        end
    end
end

---
--- Loads the values of persistable global variables from the provided data table.
---
--- This function is called during game load to restore the state of persistable global variables from the saved game data. It iterates through the `PersistableGlobals` table and copies the values from the `data` table back to the global variables, if the variable exists in the saved data.
---
--- @param data table The table of saved game data.
---
function OnMsg.PersistLoad(data)
    for k, v in pairs(PersistableGlobals) do
        if v and data[k] ~= nil then
            _G[k] = data[k]
        end
    end
end

---
--- Gathers persistable global variables and classes during game save/load.
---
--- This function is called during game save and load to gather the persistable global variables and classes that need to be saved or loaded. It populates the `permanents` table with references to these variables and classes, which are then used by the persistence system to save and load the game state.
---
--- @param permanents table The table to store the persistable global variables and classes in.
--- @param direction string The direction of the persistence operation, either "save" or "load".
---
function OnMsg.PersistGatherPermanents(permanents, direction)
    permanents["__pairs_aux__"] = pairs {}
    permanents["__ipairs_aux__"] = ipairs {}
    permanents["__ripairs_aux__"] = ripairs {}
    permanents["__pairs"] = pairs
    permanents["__ipairs"] = ipairs
    permanents["__ripairs"] = ripairs
    permanents["__procall"] = procall
    permanents["__sprocall"] = sprocall
    permanents["__finish_sprocall"] = __finish_sprocall
    permanents["__procall_errorhandler"] = __procall_errorhandler
    permanents["g_Classes"] = g_Classes
    permanents["IsKindOf"] = IsKindOf
    permanents["IsKindOfClasses"] = IsKindOfClasses
    permanents["IsValid"] = IsValid
    local concat = string.concat
    for name, class in pairs(g_Classes) do
        local baseclass = class.persist_baseclass or "class"
        permanents[concat(":", baseclass, name)] = class
        if direction == "load" and baseclass ~= "class" then -- !!! backwards compatibility
            permanents["class:" .. name] = class
        end
    end
end

---
--- Defines a class that is not persisted during game save/load.
---
--- The `UnpersistedMissingClass` class is a special class that is not persisted during game save and load operations. It is a subclass of `ComponentAttach` and is used to represent objects that should be deleted when the game is loaded.
---
--- @class UnpersistedMissingClass
--- @field __parents table The parent classes of this class.
DefineClass.UnpersistedMissingClass = {__parents={"ComponentAttach"}}

---
--- Initializes the `ObjsToDeleteOnLoadGame` table, which is used to track objects that should be deleted during the next game load.
---
--- This function maps the `ObjsToDeleteOnLoadGame` global variable to an empty table, initializing it for use in the persistence system.
---
--- @global ObjsToDeleteOnLoadGame table The table used to track objects that should be deleted during the next game load.
MapVar("ObjsToDeleteOnLoadGame", {})

---
--- Cleans up objects that were marked for deletion during the previous game load.
---
--- This function is called after a game has been loaded. It iterates through the `ObjsToDeleteOnLoadGame` table and deletes each object in that table using the `DoneObject` function. After all objects have been deleted, the `ObjsToDeleteOnLoadGame` table is cleared.
---
--- This function is registered to be called in response to the `OnMsg.StartSaveGame` message, which is triggered when the game is about to be saved.
---
--- @function OnMsg.PersistPostLoad
--- @return nil
function OnMsg.PersistPostLoad()
    for obj in pairs(ObjsToDeleteOnLoadGame or empty_table) do
        DoneObject(obj)
    end
    table.clear(ObjsToDeleteOnLoadGame)
end

---
--- Marks an object for deletion during the next game load.
---
--- This function adds the specified object to the `ObjsToDeleteOnLoadGame` table, which is used to delete objects during the next game load. This is useful for cleaning up objects that are no longer needed after a game load.
---
--- @param obj table The object to be deleted during the next game load.
---
function DeleteOnLoadGame(obj)
    if not IsValid(obj) then
        return
    end
    ObjsToDeleteOnLoadGame[obj] = true
end

---
--- Removes an object from the `ObjsToDeleteOnLoadGame` table, preventing it from being deleted during the next game load.
---
--- This function takes an object as input and removes it from the `ObjsToDeleteOnLoadGame` table, effectively canceling the request to delete that object during the next game load.
---
--- @param obj table The object to be removed from the `ObjsToDeleteOnLoadGame` table.
---
function CancelDeleteOnLoadGame(obj)
    if not obj then
        return
    end
    ObjsToDeleteOnLoadGame[obj] = nil
end

---
--- Validates the `ObjsToDeleteOnLoadGame` table, ensuring that all objects in the table are valid.
---
--- This function is called in response to the `OnMsg.StartSaveGame` message, which is triggered when the game is about to be saved. It iterates through the `ObjsToDeleteOnLoadGame` table and removes any invalid objects from the table.
---
--- @function ValidateDeleteOnLoadGame
--- @return nil
function ValidateDeleteOnLoadGame()
    table.validate_map(ObjsToDeleteOnLoadGame)
end

--- Validates the `ObjsToDeleteOnLoadGame` table, ensuring that all objects in the table are valid.
---
--- This function is registered to be called in response to the `OnMsg.StartSaveGame` message, which is triggered when the game is about to be saved. It iterates through the `ObjsToDeleteOnLoadGame` table and removes any invalid objects from the table.
---
--- @function OnMsg.StartSaveGame
--- @return nil
OnMsg.StartSaveGame = ValidateDeleteOnLoadGame
