if FirstLoad then
	g_logStorage = false
	g_logScreen = true
	LogBacklog = {}
	LogBacklogIndex = 0
	LogBacklogSize = 10
	LogEventsCount = 0
	LogErrorsCount = 0
	LogSecurityCount = 0
	LocalTSStart = GetPreciseTicks()
end

local string_format = string.format

-- returns UTC timestamp string formatted "%d %b %Y %H:%M:%S"
local ts_func = GetPreciseTicks
local ts_valid = ts_func() - 1000
local ts_last = os.date("!%d %b %Y %H:%M:%S")
---
--- Returns the current UTC timestamp as a string in the format "%d %b %Y %H:%M:%S".
--- The timestamp is updated every 900 milliseconds to ensure it remains accurate.
---
--- @return string The current UTC timestamp
---
function timestamp()
    local time = ts_func() - ts_valid
    if time > 900 or time < 0 then
        ts_valid = ts_func()
        ts_last = os.date("!%d %b %Y %H:%M:%S")
    end
    return ts_last
end

local localts_time = GetPreciseTicks
local localts_start = LocalTSStart or localts_time()
local localts_valid
local localts_last_timestamp = ""
---
--- Returns the current local timestamp as a string in the format "%d %02d:%02d:%02d.%03d".
--- The timestamp is updated every time the function is called to ensure it remains accurate.
---
--- @return string The current local timestamp
---
function local_timestamp()
    local time = localts_time()
    if time ~= localts_valid then
        localts_valid = time
        time = time - localts_start
        localts_last_timestamp = string_format("%d %02d:%02d:%02d.%03d", time / 24 / 3600000, time / 3600000 % 24,
            time / 60000 % 60, time / 1000 % 60, time % 1000)
    end
    return localts_last_timestamp
end

local log_timestamp = local_timestamp

local function log(screen_format, backlog, event_type, event_source, event, ...)
	local time, screen_text
	if g_logScreen then
		time = time or log_timestamp()
		screen_text = screen_text or print_format(string_format(screen_format, time, event_source or ""), event, ...)
		print(screen_text)
	end

	if backlog then
		time = time or log_timestamp()
		screen_text = screen_text or print_format(string_format(screen_format, time, event_source or ""), event, ...)
		local i = 1 + LogBacklogIndex % LogBacklogSize
		LogBacklogIndex = i
		backlog[i] = screen_text
	end

	local logstorage = g_logStorage
	if logstorage then
		time = time or log_timestamp()
		event = event or string_format(event_text, ...)
		if event_type == "event" then
			logstorage:WriteTuple(timestamp(), time, event_source or "", event, ...)
		else
			logstorage:WriteTuple(timestamp(), time, event_type, event_source or "", event, ...)
		end
	end
end

---
--- Logs an event with the given text and optional arguments.
---
--- @param event_text string The text of the event to log.
--- @param ... any Additional arguments to be included in the log message.
---
function EventLog(event_text, ...)
    if event_text then
        LogEventsCount = LogEventsCount + 1
        return log("%s", nil, "event", "", event_text, ...)
    end
end

---
--- Logs an event with the given event source and event text.
---
--- @param event_source string The source of the event to log.
--- @param event_text string The text of the event to log.
--- @param ... any Additional arguments to be included in the log message.
---
function EventLogSrc(event_source, event_text, ...)
    if event_text then
        LogEventsCount = LogEventsCount + 1
        return log("%s %s ->", nil, "event", event_source, event_text, ...)
    end
end

---
--- Logs an error with the given text and optional arguments.
---
--- @param event_text string The text of the error to log.
--- @param ... any Additional arguments to be included in the log message.
---
function ErrorLog(event_text, ...)
    if event_text then
        LogErrorsCount = LogErrorsCount + 1
        return log("[color=magenta]%s error:", LogBacklog, "error", "", event_text, ...)
    end
end

---
--- Logs an error with the given event source and error text.
---
--- @param event_source string The source of the error to log.
--- @param event_text string The text of the error to log.
--- @param ... any Additional arguments to be included in the log message.
---
function ErrorLogSrc(event_source, event_text, ...)
    if event_text then
        LogErrorsCount = LogErrorsCount + 1
        return log("[color=magenta]%s error: %s ->", LogBacklog, "error", event_source, event_text, ...)
    end
end

---
--- Logs a security event with the given text and optional arguments.
---
--- @param event_text string The text of the security event to log.
--- @param ... any Additional arguments to be included in the log message.
---
function SecurityLog(event_text, ...)
    if event_text then
        LogSecurityCount = LogSecurityCount + 1
        return log("[color=cyan]%s security:", LogBacklog, "security", "", event_text, ...)
    end
end

-------------

---
--- Defines a class for an event logger.
---
--- The `EventLogger` class provides methods for logging events, errors, and security events.
---
--- @class EventLogger
--- @field event_source string The source of the events being logged.
DefineClass.EventLogger = {__parents={}, event_source=""}

---
--- Logs an event with the given text and optional arguments.
---
--- @param event_text string The text of the event to log.
--- @param ... any Additional arguments to be included in the log message.
---
function EventLogger:Log(event_text, ...)
    if event_text then
        LogEventsCount = LogEventsCount + 1
        local src = self.event_source or ""
        if src ~= "" then
            return log("%s %s ->", nil, "event", src, event_text, ...)
        else
            return log("%s", nil, "event", "", event_text, ...)
        end
    end
end

---
--- Logs an error with the given text and optional arguments.
---
--- @param event_text string The text of the error to log.
--- @param ... any Additional arguments to be included in the log message.
---
function EventLogger:ErrorLog(event_text, ...)
    if event_text then
        LogErrorsCount = LogErrorsCount + 1
        local src = self.event_source or ""
        if src ~= "" then
            return log("[color=magenta]%s error: %s ->", LogBacklog, "error", src, event_text, ...)
        else
            return log("[color=magenta]%s error:", LogBacklog, "error", "", event_text, ...)
        end
    end
end

---
--- Logs a security event with the given text and optional arguments.
---
--- @param event_text string The text of the security event to log.
--- @param ... any Additional arguments to be included in the log message.
---
function EventLogger:SecurityLog(event_text, ...)
    if event_text then
        LogSecurityCount = LogSecurityCount + 1
        local src = self.event_source or ""
        if src ~= "" then
            return log("[color=cyan]%s security: %s ->", LogBacklog, "security", src, event_text, ...)
        else
            return log("[color=cyan]%s security:", LogBacklog, "security", "", event_text, ...)
        end
    end
end

-------------

---
--- Prints the last `count` entries from the event log backlog.
---
--- @param count number The number of entries to print from the backlog. If not provided, prints all entries.
---
function LogPrint(count)
    local logsize = LogBacklogSize
    local backlog = LogBacklog
    count = Min(count or logsize, logsize)
    for i = LogBacklogIndex - count + 1, LogBacklogIndex do
        local event = backlog[i < 1 and i + logsize or i]
        if event then
            print(event)
        end
    end
end

---
--- Converts the last `count` entries of the event log backlog to a string.
---
--- @param count number The number of entries to convert to a string. If not provided, converts all entries.
--- @return string The string representation of the last `count` entries of the event log backlog.
---
-- gives the last 'count' entries of the backlog as a string
function LogToString(count)
	local logsize = LogBacklogSize
	local backlog = LogBacklog
	local server_backlog = false
	
	count = Min(count or logsize, logsize)
	for i = LogBacklogIndex - count + 1, LogBacklogIndex do
		local event = backlog[i < 1 and i + logsize or i]
		if event then
			server_backlog = string.format("%s%s\n", server_backlog or "\n", event)
		end
	end

	return server_backlog
end