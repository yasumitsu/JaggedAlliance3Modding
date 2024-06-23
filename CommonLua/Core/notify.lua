-- Notifications provide easy way to make lazy updates after certain changes are complete.
-- Multiple notifications within the same millisecond are treated as one.
--- Maintains a mapping of delayed call objects and their corresponding threads.
--- `DelayedCallObjects` is a table that stores the objects to be called when a delayed call is triggered.
--- `DelayedCallThreads` is a table that stores the game time threads that will execute the delayed calls.
--- `NotifyLastTimeCalled` is a variable that stores the last time a notification was triggered.
MapVar("DelayedCallObjects", {})
MapVar("DelayedCallThreads", {})
MapVar("NotifyLastTimeCalled", 0)

---
--- Executes the delayed notifications for the specified method.
--- This function is called by the game time thread created in the `Notify` function.
--- It iterates through the list of objects associated with the method and calls the corresponding method or function on each valid object.
--- After all notifications have been executed, the `DelayedCallObjects` and `DelayedCallThreads` tables are cleared for the method.
---
--- @param method string|function The method or function to be called for the delayed notifications.
--- @return function The function that will be executed by the game time thread.
---
local function DoNotify(method)
    return function()
        Sleep(0)
        Sleep(0)
        local objs = DelayedCallObjects[method]
        if objs then
            local i = 1
            if type(method) == "function" then
                while true do
                    local obj = objs[i]
                    -- This check is purposedly not re-phrased to "if not obj",
                    -- because obj may well be "false" in a valid situation(when a notification has been cancelled).
                    if obj == nil then
                        break
                    end
                    if IsValid(obj) then
                        procall(method, obj)
                    end
                    i = i + 1
                end
            else
                while true do
                    local obj = objs[i]
                    -- This check is purposedly not re-phrased to "if not obj". Please, don't change.
                    if obj == nil then
                        break
                    end
                    if IsValid(obj) then
                        procall(obj[method], obj)
                    end
                    i = i + 1
                end
            end
        else
            assert(false, "Missing notify list for method " .. tostring(method))
        end
        DelayedCallObjects[method] = nil
        DelayedCallThreads[method] = nil
    end
end

---
--- Recreates the `DelayedCallThreads` table by iterating through the `DelayedCallObjects` table and creating a new game time thread for each method that has associated objects.
--- This function is called when the `NotifyLastTimeCalled` variable is updated, indicating that a new frame has started.
---
--- @internal
function RecreateNotifyStructures()
    assert(not next(DelayedCallThreads))
    for k, v in pairs(DelayedCallThreads) do
        DelayedCallThreads[k] = DelayedCallObjects[k] and CreateGameTimeThread(DoNotify(k)) or nil
    end
end

-- calls the func or the obj method when the current thread completes (but within the same millisecond)
-- multiple calls with the same obj/method pair result in one call only
---
--- Notifies the specified object using the given method.
---
--- If the `NotifyLastTimeCalled` variable indicates that a new frame has started, the `RecreateNotifyStructures()` function is called to recreate the `DelayedCallThreads` table.
---
--- If a thread for the given method does not exist, a new game time thread is created using the `DoNotify(method)` function and stored in the `DelayedCallThreads` table. The object is also added to the `DelayedCallObjects` table.
---
--- If a thread for the given method already exists, the object is added to the `DelayedCallObjects` table.
---
--- @param obj table The object to notify
--- @param method string|function The method to call on the object, or a function to call with the object as the argument
---
function Notify(obj, method)
    if not obj then
        return
    end

    local now = GameTime()
    if NotifyLastTimeCalled ~= now then
        RecreateNotifyStructures()
        NotifyLastTimeCalled = now
    end

    local thread = DelayedCallThreads[method]
    if not thread then
        thread = CreateGameTimeThread(DoNotify(method))
        DelayedCallThreads[method] = thread
        DelayedCallObjects[method] = {obj, [obj]=true}
    else
        local objs = DelayedCallObjects[method]
        if not objs[obj] then
            objs[#objs + 1] = obj
            objs[obj] = true
        end
    end
end

--- notifies all objects in <objlist>
---
--- Notifies all objects in the given list using the specified method.
---
--- If the `NotifyLastTimeCalled` variable indicates that a new frame has started, the `RecreateNotifyStructures()` function is called to recreate the `DelayedCallThreads` table.
---
--- For each object in the list, if a thread for the given method does not exist, a new game time thread is created using the `DoNotify(method)` function and stored in the `DelayedCallThreads` table. The object is also added to the `DelayedCallObjects` table.
---
--- If a thread for the given method already exists, the object is added to the `DelayedCallObjects` table.
---
--- @param objects_to_call table The list of objects to notify
--- @param method string|function The method to call on the objects, or a function to call with each object as the argument
---
function ListNotify(objects_to_call, method)
    if #objects_to_call < 1 then
        return
    end
    Notify(objects_to_call[1], method)
    local objs = DelayedCallObjects[method]
    assert(objs)
    for i = 2, #objects_to_call do
        local obj = objects_to_call[i]
        if not objs[obj] then
            objs[#objs + 1] = obj
            objs[obj] = true
        end
    end
end

--- Cancels a notification for the given object and method.
---
--- If the object is registered to receive notifications for the given method, this function removes the object from the list of objects to notify.
---
--- @param obj table The object to cancel the notification for
--- @param method string|function The method to cancel the notification for
function CancelNotify(obj, method)
    local objs = DelayedCallObjects[method]
    if objs[obj] then
        objs[obj] = nil
        for i = 1, #objs do
            if objs[i] == obj then
                objs[i] = false
                return
            end
        end
    end
end
