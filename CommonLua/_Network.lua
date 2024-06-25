--- Stores a table of network event handlers.
-- This table maps event names to their corresponding handler functions.
-- The handlers are called when the corresponding network event is triggered.
NetEvents = {}
--- Stores a table of network event handlers.
-- This table maps event names to their corresponding handler functions.
-- The handlers are called when the corresponding network event is triggered.
NetSyncEvents = {}
--- Stores a table of functions that revert local effects when a network sync event is triggered.
-- The keys in this table are the names of the network sync events, and the values are the corresponding
-- functions that revert the local effects of that event.
NetSyncLocalEffects = {}
--- Stores a table of functions that revert local effects when a network sync event is triggered.
-- The keys in this table are the names of the network sync events, and the values are the corresponding
-- functions that revert the local effects of that event.
NetSyncRevertLocalEffects = {}

netInGame = false

--- Sends a network gossip event.
-- This function is used to trigger a network gossip event, which can be handled by other systems.
-- It does not take any parameters and simply calls the corresponding network event handler.
function NetGossip()
end

--- Sends a temporary network object.
-- This function is used to send a temporary network object over the network.
-- @param o The temporary network object to send.
function NetTempObject(o)
end

--- Handles the assignment of a network handle.
-- @param handle The network handle that was assigned.
function OnHandleAssigned(handle)
end


--- Returns whether the current code is running asynchronously.
-- @return true if the code is running asynchronously, false otherwise.
function IsAsyncCode()
    return true
end


--- Executes a network sync event.
-- This function is called when a network sync event is triggered. It first checks if there are any local effects that need to be reverted, and calls the corresponding revert function if so. It then logs the event and its parameters using the `Msg` function, and finally calls the event handler function registered in the `NetSyncEvents` table.
-- @param event The name of the network sync event.
-- @param ... The parameters to pass to the event handler function.
local function ExecEvent(event, ...)
    if NetSyncRevertLocalEffects[event] then
        NetSyncRevertLocalEffects[event](...)
    end
    Msg("SyncEvent", event, ...)
    NetSyncEvents[event](...)
end

--- Sends a network sync event.
-- This function is used to trigger a network sync event, which can be handled by other systems.
-- It serializes the provided parameters, calls the corresponding event handler function registered in the `NetSyncEvents` table, and if there are any local effects that need to be reverted, it calls the corresponding revert function registered in the `NetSyncRevertLocalEffects` table.
-- @param event The name of the network sync event.
-- @param ... The parameters to pass to the event handler function.
function NetSyncEvent(event, ...)
    assert(NetSyncEvents[event])
    if NetSyncLocalEffects[event] then
        NetSyncLocalEffects[event](...)
    end
    local params, err = Serialize(...)
    assert(params, err)
    procall(ExecEvent, event, Unserialize(params))
end
