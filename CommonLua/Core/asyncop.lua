--- Initializes the AsyncOps table if it doesn't already exist.
-- This is executed when the file is first loaded.
-- @local
if FirstLoad then
    AsyncOps = {}
end

--- Wakes up the async operation with the given ID and removes it from the AsyncOps table.
-- @param opid number The ID of the async operation to complete.
-- @param ... any The return values to pass to the async operation's callback.
function AsyncOpDone(opid, ...)
    Wakeup(AsyncOps[opid], ...)
    AsyncOps[opid] = nil
end

--- Wakes up an async operation with the given ID and removes it from the AsyncOps table.
-- If the operation has timed out, it removes the operation from AsyncOps and returns "timeout".
-- If the operation has been cancelled, it removes the operation from AsyncOps and returns "cancelled".
-- Otherwise, it returns the return values of the async operation's callback.
-- @param id number The ID of the async operation to complete.
-- @param ok boolean Whether the operation completed successfully.
-- @param ... any The return values to pass to the async operation's callback.
-- @return string|any Either "timeout", "cancelled", or the return values of the async operation's callback.
local function __wakeup(id, ok, ...)
    if not ok then
        AsyncOps[id] = nil
        AsyncOpStop(id)
        return "timeout"
    end
    if AsyncOps[id] then
        assert(AsyncOps[id] == "cancelled", "Async op thread has been awaken before the computation is finished!")
        AsyncOps[id] = nil
        return "cancelled"
    end
    return ...
end

--- Checks if the current thread can yield.
-- This is a wrapper around the built-in `CanYield` function.
-- @return boolean True if the current thread can yield, false otherwise.
AsyncCanYield = CanYield

--- Wraps an asynchronous function to provide timeout and cancellation support.
-- The wrapped function will wait until the asynchronous operation is complete, fails, times out, or is cancelled.
-- @param func function The asynchronous function to wrap.
-- @return function The wrapped asynchronous function.
local function AsyncOpWrap(func)
    return function(...)
        -- async operations can be executed outside of threads or in real time threads only (cannot be persisted)
        if not IsRealTimeThread() or not AsyncCanYield() then
            -- exec syncronously
            return func(nil, ...)
        end
        local id, res2, res3, res4 = func(true, ...)
        if type(id) ~= "number" then
            return id, res2, res3, res4
        end
        AsyncOps[id] = CurrentThread()
        return __wakeup(id, WaitWakeup())
    end
end

--- Wraps all asynchronous functions in the `async` table with a function that provides timeout and cancellation support.
-- The wrapped functions will wait until the asynchronous operation is complete, fails, times out, or is cancelled.
-- This allows for consistent handling of asynchronous operations throughout the codebase.
for op, func in pairs(async) do
    _G[op] = AsyncOpWrap(func)
end

--- AsyncOp call with timeout and cancel support, the function waits until the async op is complete, fails, timeouts or is cancelled.
-- @cstyle err, ... AsyncOpWait(int nTimeout, table id_ref, string funcname, ...).
-- @param nTimeout int; timeout in milliseconds, can be nil.
-- @param id_ref table; table to store the id of the async operation; can be used to call AsyncOpCancel(id_ref), overwrites member "asyncop_id" - the same table should not be used for concurent AsyncOp calls; can be nil.
-- @param funcname string; name of the async function to be called, actual function is found in async[funcname].
-- @param ...; arguments passed to the async function.
-- @return err, ...; if there is no err, the async op was successful and the rest of the return values are returned by the async op;

function AsyncOpWait(timeout, id_ref, funcname, ...)
	-- async operations can be executed in real time threads only (cannot be persisted)
	assert(IsRealTimeThread())
	local id, res2, res3, res4 = async[funcname](true, ...)
	if type(id) ~= "number" then
		return id, res2, res3, res4
	end
	if id_ref then
		rawset(id_ref, "asyncop_id", id)
	end
	AsyncOps[id] = CurrentThread()
	return __wakeup(id, WaitWakeup(timeout))
end

--- Cancels an AsyncOp started with AsyncOpWait.
-- @cstyle bool AsyncOpCancel(table id_ref).
-- @param id_ref table; a thread or a table passed to AsyncOpWait used to identify the async op call; the same table should not be used for concurent AsyncOp calls.
-- @return bool; true if the operation referenced in id_ref was waiting to complete.

function AsyncOpCancel(id_ref)
	local id, thread
	if type(id_ref) == "thread" then
		for _id, _thread in pairs(AsyncOps) do
			if _thread == id_ref then
				id = _id
				thread = _thread
			end
		end
	elseif type(id_ref) == "table" then
		id = rawget(id_ref, "asyncop_id")
		rawset(id_ref, "asyncop_id", nil)
		thread = id and AsyncOps[id]
	end
	if thread then
		AsyncOps[id] = "cancelled"
		AsyncOpStop(id)
		return Wakeup(thread)
	end
end

-- AsyncOpWait/AsyncOpCancel usage:
-- ...
-- local err, res1, res2, res3 = AsyncOpWait(5000, self, "WebRequest", ...)
-- if not err then ... end
-- if err == "cancelled" then ... end
-- if err == "timeout" then ... end
--
-- in another thread/callback:
-- AsyncOpCancel(self)
