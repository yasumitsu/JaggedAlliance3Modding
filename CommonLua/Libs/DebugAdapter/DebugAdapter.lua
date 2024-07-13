config.DebugAdapterPort = config.DebugAdapterPort or 8165

-- NOTE: for setExpression request to work:
--		1) provide evaluateName for the editable property
--		2) supportsSetExpression = true
--		3) supportsSetVariable = false/nil
-- The following config variable forces the above three
config.DebugAdapterUseSetExpression = false

config.MaxWatchLenValue = config.MaxWatchLenValue or 512
config.MaxWatchLenKey = config.MaxWatchLenKey or 128

if FirstLoad then
	__tuple_meta = { __name = "tuple" }
end

local function IsTuple(value)
	return type(value) == "table" and getmetatable(value) == __tuple_meta
end

----- DASocket

DASocket = rawget(_G, "DASocket") or { -- simple lua table, since it needs to work before the class resolution
	request = false, -- the current request being processed
	state = false, -- false, "running", "stopped"
	manual_pause = false,
	in_break = false,
	debug_blacklisted = false,
	callstack = false,
	scope_frame = false,
	stack_vars = false,
	breakpoints = false,
	condition_env = false,
	var_ref_idx = false,
	ref_to_var = false,

	Capabilities = {
		supportsConfigurationDoneRequest = true,
		supportsTerminateRequest = true,
		supportTerminateDebuggee = true,
		supportsConditionalBreakpoints = true,
		supportsHitConditionalBreakpoints = true,
		supportsLogPoints = true,
		supportsSetVariable = not config.DebugAdapterUseSetExpression,
		supportsSetExpression = config.DebugAdapterUseSetExpression,
		supportsVariableType = true,
		supportsCompletionsRequest = true,
		completionTriggerCharacters = {".", ":", "}"},
		supportsBreakpointLocationsRequest = true,	-- comes after setBreakpoints request!

		-- NOTE: no idea how to trigger these requests: 
		--supportsEvaluateForHovers = true,		-- only evaluate request with 'watch' context comming(no 'hover')
		--supportsGotoTargetsRequest = true,	-- no official Lua API and hacking the Lua stack seems to crash the engine
		--supportsModulesRequest = true,		-- not received - seems it is implemented for VS but not for VSCode
		--additionalModuleColumns = {{attributeName = "name", label = "label"}},
		--supportsDelayedStackTraceLoading = true,	-- we show the whole stack anyway
		-- NOTE: we may have 5k threads
		--supportsTerminateThreadsRequest = true,
		--supportsSingleThreadExecutionRequests = true,
		--supportsValueFormattingOptions = true,	-- no special formatting options
		--supportsLoadedSourcesRequest = true,
	},
}
setmetatable(DASocket, JSONSocket)
DASocket.__index = DASocket

---
--- Called when the debug adapter connection is lost.
---
--- @param reason string|nil The reason for the disconnection, if available.
function DASocket:OnDisconnect(reason)
	---[[]] self:Logf("OnDisconnect %s", tostring(reason) or "")
	table.remove_value(DAServer.debuggers, self)
	printf("DebugAdapter connection %d %s:%d lost%s", self.connection, self.host, self.port, reason and ("(" .. reason .. ")") or "")
end

---
--- Handles incoming messages from the debug adapter connection.
---
--- @param message table The incoming message from the debug adapter.
--- @param headers table The headers of the incoming message.
---
function DASocket:OnMsgReceived(message, headers)
	local msg_type = message.type
	if msg_type == "event" then
		local func = self["Event_" .. message.event]
		if func then
			return func(self, message.body)
		end
	elseif msg_type == "request" then
		local func = self["Request_" .. message.command]
		if func then
			---[[]]self:Logf("Message: %s", ValueToLuaCode(message))
			self.request = message
			local ok, err, response = pcall(func, self, message.arguments)
			if not ok then
				print("DebugAdapter error:", err)
				return
			end
			assert(self.request or (not err and response == nil)) -- if a response was sent there should be no return values
			if self.request then -- if response not send, send it now
				return self:SendResponse(err, response)
			end
			return
		end
	elseif msg_type == "response" then
		local func = self.result_callbacks and self.result_callbacks[message.request_seq]
		if func then
			return func(self, message)
		end
	end
	return "Unhandled message"
end

---
--- Sends an event message to the debug adapter connection.
---
--- @param event string The name of the event to send.
--- @param body table The body of the event message.
function DASocket:SendEvent(event, body)
	self.seq_id = (self.seq_id or 0) + 1
	return self:Send{
		type = "event",
		event = event,
		body = body,
		seq = self.seq_id,
	}
end

---
--- Sends a response message to the debug adapter connection.
---
--- @param err string|nil The error message, if any.
--- @param response table|nil The response body, if any.
--- @return boolean|string True if the message was sent successfully, or an error message.
function DASocket:SendResponse(err, response)
	local request = self.request
	self.request = nil
	assert(request)
	if not request then return end
	self.seq_id = (self.seq_id or 0) + 1
	return self:Send{
		type = "response",
		request_seq = request.seq,
		success = not err,
		message = err or nil,
		command = request.command,
		body = response or nil,
		seq = self.seq_id,
	}
end

---
--- Sends a request message to the debug adapter connection.
---
--- @param command string The name of the request command to send.
--- @param arguments table|nil The arguments for the request command.
--- @param callback function|nil The callback function to be called when the response is received.
--- @return boolean|string True if the message was sent successfully, or an error message.
function DASocket:SendRequest(command, arguments, callback)
	self.seq_id = (self.seq_id or 0) + 1
	local err = self:Send{
		type = "request",
		command = command,
		arguments = arguments or nil,
		seq = self.seq_id,
	}
	if err then return err end
	CreateRealTimeThread(function(self, seq) -- clear the callback in 60sec
		Sleep(60000)
		self.result_callbacks[seq] = nil
	end, self, self.seq_id)
	self.result_callbacks = self.result_callbacks or {}
	self.result_callbacks[self.seq_id] = callback or nil
end


----- References

local reference_pool_size = 100000000
local modules_start = 1 * reference_pool_size
local threads_start = 2 * reference_pool_size
local variables_start = 3 * reference_pool_size
local reference_types = { "module", "thread", "variables"}
---
--- Returns the reference type for the given reference ID.
---
--- @param id number The reference ID.
--- @return string The reference type.
function DASocket:GetReferenceType(id)
	return reference_types[id / reference_pool_size]
end


----- Events

---
--- Stops the DebugAdapter server.
---
--- This function is called when another debugee requests the DebugAdapter server to stop so it can be debugged.
---
function DASocket:Event_StopDAServer()
	-- this comes form another debugee requesting us to stop the DAServer so it can be debugged
	self:Logf("DebugAdapter stopped listening")
	if DAServer.listen_socket then
		sockDisconnect(DAServer.listen_socket)
		DAServer.listen_socket:delete()
		DAServer.listen_socket = nil
	end
end


----- Requests

---
--- Initializes the DebugAdapter server.
---
--- This function is called when the DebugAdapter server is first started. It sets up the initial state of the server, including the client name, line and column numbering, and the client capabilities. It also initializes the debugger and clears any existing breakpoints.
---
--- @param arguments table The arguments passed to the initialize request.
--- @param arguments.clientName string The name of the client that is connecting to the DebugAdapter server.
--- @param arguments.linesStartAt1 boolean Whether line numbers start at 1 (true) or 0 (false).
--- @param arguments.columnsStartAt1 boolean Whether column numbers start at 1 (true) or 0 (false).
--- @param arguments.client table The client capabilities.
function DASocket:Request_initialize(arguments)
	if arguments.clientName then
		self.event_source = arguments.clientName .. " "
	end
	self.linesStartAt1 = arguments.linesStartAt1
	self.columnsStartAt1 = arguments.columnsStartAt1
	self.client = arguments
	self:SendResponse(nil, self.Capabilities)
	DebuggerInit()
	DebuggerClearBreakpoints()
	self.condition_env = {}
	setmetatable(self.condition_env, {
		__index = DebuggerIndex
	})
	self:SendEvent("initialized")
end

---
--- Marks the end of initialization for the DebugAdapter server.
---
--- This function is called after the DebugAdapter server has been initialized. It signals that the initialization process is complete and the server can continue normal operation.
---
function DASocket:Request_configurationDone(arguments)
	-- marks the end of initialization
	self:Continue()
end

---
--- Attaches the DebugAdapter to a running process.
---
--- This function is called when the DebugAdapter client requests to attach to a running process. It sends a response back to the client to indicate that the attach operation was successful.
---
--- @param arguments table The arguments passed to the attach request.
function DASocket:Request_attach(arguments)
	self:SendResponse()
end

---
--- Disconnects the DebugAdapter from the running process.
---
--- This function is called when the DebugAdapter client requests to disconnect from the running process. It sets the state of the DebugAdapter to false, sends a response back to the client, and then either restarts the application or terminates the debuggee, depending on the arguments passed to the request.
---
--- @param arguments table The arguments passed to the disconnect request.
--- @param arguments.restart boolean If true, the application will be restarted.
--- @param arguments.terminateDebuggee boolean If true, the debuggee will be terminated.
function DASocket:Request_disconnect(arguments)
	self.state = false
	self:SendResponse()
	if arguments.restart then
		CreateRealTimeThread(restart, GetAppCmdLine())
	elseif arguments.terminateDebuggee then
		CreateRealTimeThread(quit)
	end
end

---
--- Returns a list of threads in the debuggee.
---
--- This function is called when the DebugAdapter client requests information about the threads in the debuggee. It returns a table of thread information, where each thread is represented by a table with an `id` and `name` field.
---
--- @param arguments table The arguments passed to the threads request.
--- @return nil, table The response to the threads request, containing a `threads` field with a table of thread information.
function DASocket:Request_threads(arguments)
	local threads = {
		{ id = threads_start + 1, name = "Global" }
	}
	return nil, { threads = threads }
end


-- returns table of lines with all the comments removed
local function GetCleanSourceCode(filename)
	-- capitalize the drive letter to avoid casing mismatches
	filename = string.upper(filename:sub(1, 1)) .. filename:sub(2)
	local err, source = AsyncFileToString(filename, nil, nil, "lines")
	if err then return err end

	local clean_source = {}
	local in_multi_line_comment = false
	for line_number, line in ipairs(source) do
		if in_multi_line_comment then
			local multi_line_end = line:find("%]%]")
			if multi_line_end then
				in_multi_line_comment = false
				line = line:sub(multi_line_end + 2, -1)
			end
		end
		if in_multi_line_comment then
			clean_source[line_number] = ""
		else
			-- remove multiline comments on a single line(which can be several)
			local clean_line
			local string_pos = 1
			repeat
				local multi_line_start = line:find("%-%-%[%[", string_pos)
				local multi_line_end = multi_line_start and line:find("%]%]", multi_line_start + 4)
				if multi_line_end then
					clean_line = clean_line or {}
					table.insert(clean_line, line:sub(string_pos, multi_line_start - 1))
					string_pos = multi_line_end + 2
				end
			until not multi_line_end
			if clean_line then
				line = table.concat(clean_line, "")
			end
			
			local multi_line_start = line:find("%-%-%[%[")
			if multi_line_start then
				in_multi_line_comment = true
				clean_source[line_number] = line:sub(1, multi_line_start - 1)
			else
				line = line:gsub("%-%-.*", "")				-- remove comments till the end of the line
				clean_source[line_number] = line
			end
		end
	end

	return clean_source
end

---
--- Requests the locations of breakpoints in the specified source code.
---
--- @param arguments table The arguments for the request, containing the source code path or source reference.
--- @return nil, table The response, containing a table of breakpoint locations. If the line at the specified line number contains non-whitespace characters, the response will contain a single breakpoint at column 1 of that line. Otherwise, the response will contain an empty table of breakpoints.
---
function DASocket:Request_breakpointLocations(arguments)
	local breakpoints_locations = {}
	local source = GetCleanSourceCode(arguments.source.path or arguments.source.sourceReference)
	if source[arguments.line]:match("%S") then
		return nil, {breakpoints = {line = arguments.line, column = 1}}
	else
		return nil, {breakpoints = {}}
	end
end

local function get_cond_expr(cond)
	local cond_expr = (cond == "") and "return true" or cond
	if not string.match(cond_expr, "^%s*return%s") then
		cond_expr = "return " .. cond_expr
	end
	
	return cond_expr
end

local is_running_packed = not IsFSUnpacked()
DASocket.UnpackedLuaSources = {
	"ModTools/Src/",
}
DASocket.PackedLuaMapping = {
	["CommonLua/"] = "ModTools/Src/CommonLua/",
	["Lua/"] = "ModTools/Src/Lua/",
	["Data/"] = "ModTools/Src/Data/",
}
for i, dlc in pairs(rawget(_G, "DlcDefinitions")) do
	local dlc_path = SlashTerminate(dlc.folder)
	DASocket.PackedLuaMapping[dlc_path] = string.format("ModTools/Src/DLC/%s/", dlc.name)
end

local function PackedToUnpackedLuaPath(virtual_path)
	for packed, unpacked in pairs(DASocket.PackedLuaMapping) do
		if string.starts_with(virtual_path, packed) then
			local result, err = ConvertToOSPath(unpacked .. string.sub(virtual_path, #packed + 1))
			if not err and io.exists(result) then
				return result
			end
		end
	end
	return virtual_path
end

local function UnpackedToPackedLuaPath(virtual_path)
	for packed, unpacked in pairs(DASocket.PackedLuaMapping) do
		if string.starts_with(virtual_path, unpacked) then
			return packed .. string.sub(virtual_path, #unpacked + 1)
		end
	end
	return virtual_path
end

local function FindMountedLuaPath(os_path)
	local lua_mount_points = {
		"CommonLua/",
		"Lua/",
		"Data/",
	}
	if config.Mods then
		if is_running_packed then
			table.iappend(lua_mount_points, DASocket.UnpackedLuaSources)
		end
		for i, mod in ipairs(ModsLoaded) do
			table.insert(lua_mount_points, mod.content_path)
		end
		for i, dlc in pairs(rawget(_G, "DlcDefinitions")) do
			table.insert(lua_mount_points, dlc.folder)
		end
	end
	local os_path_lower = os_path:lower()
	for i, src_virtual in ipairs(lua_mount_points) do
		local src_os_path, err = ConvertToOSPath(src_virtual)
		if not err and io.exists(src_os_path) then
			local src_os_path = string.lower(src_os_path)
			if string.starts_with(os_path_lower, src_os_path) then
				return src_virtual .. string.gsub(string.sub(os_path, #src_os_path + 1), "\\", "/")
			end
		end
	end
end

---
--- Handles setting breakpoints in the debugger.
---
--- @param arguments table The arguments for the request, containing the breakpoints to set.
--- @return string|nil, table The error message if there was an issue, or a table containing the set breakpoints.
function DASocket:Request_setBreakpoints(arguments)
	if not arguments.breakpoints then return end
	
	local bp_path = arguments.source.path or arguments.source.sourceReference
	local source = GetCleanSourceCode(bp_path)
	local filename = FindMountedLuaPath(bp_path)
	if not filename then
		return "This file is not a part of the game and cannot be debugged."
	end
	if is_running_packed then
		filename = UnpackedToPackedLuaPath(filename)
	end
	bp_path = bp_path:lower()
	self.breakpoints = self.breakpoints or {}
	for line, bp in pairs(self.breakpoints[bp_path]) do
		DebuggerRemoveBreakpoint(filename, line)
	end
	self.breakpoints[bp_path] = {}
	local response = {}
	for bp_idx, bp in ipairs(arguments.breakpoints) do
		local bp_set = table.copy(arguments.source)
		bp_set.id = bp_idx
		bp_set.line = bp.line
		local condition, hitCondition
		if bp.condition ~= nil then
			bp_set.condition = bp.condition
			local cond_expr = get_cond_expr(bp.condition)
			local eval, err = load(cond_expr, nil, nil, self.condition_env)
			if eval then
				condition = eval
			else
				bp_set.message = err
			end
			if bp.hitCondition ~= nil then
				bp_set.hitCondition = bp.hitCondition
				local hit_cond_expr = get_cond_expr(bp.hitCondition)
				local eval, err = load(hit_cond_expr, nil, nil, self.condition_env)
				if eval then
					hitCondition = eval
				else
					bp_set.message = table.concat({bp_set.message or "", err}, "\r\n")
				end
			end
		end
		bp_set.verified = source[bp.line]:match("%S")
		if bp_set.verified then
			if bp.logMessage then
				DebuggerAddBreakpoint(filename, bp.line, bp.logMessage, condition, hitCondition)
			else
				DebuggerAddBreakpoint(filename, bp.line, condition, hitCondition)
			end
		end
		self.breakpoints[bp_path][bp.line] = bp_set
		table.insert(response, bp_set)
	end
	
	return nil, {breakpoints = response}
end

---
--- Pauses the debugger execution and marks the current source as blacklisted for debugging.
--- This function is called when the client requests a pause in the debugger.
---
--- @param arguments table The arguments passed with the pause request.
---
function DASocket:Request_pause(arguments)
	self:SendResponse() -- first send the response
	self.manual_pause = true
	self.debug_blacklisted = config.DebugBlacklistedSource or false
	config.DebugBlacklistedSource = true
	DebuggerBreakExecution()
end

-- NOTE: When "Smooth Scroll" enabled - if BP/exception occurs and VSCode is already in the file it does not jump to the line
---
--- Retrieves the current call stack and initializes variables for tracking variable references.
---
--- @param arguments table The arguments passed with the stack trace request.
--- @return nil, table The call stack information.
---
function DASocket:Request_stackTrace(arguments)
	self.var_ref_idx = variables_start
	self.ref_to_var = {}
	
	return nil, self.callstack
end

---
--- Resumes the debugger execution and clears the debug blacklist.
--- This function is called when the client requests to continue the debugger.
---
--- @param arguments table The arguments passed with the continue request.
---
function DASocket:Request_continue(arguments)
	self:SendResponse()
	self:Continue()
	self.manual_pause = false
	config.DebugBlacklistedSource = self.debug_blacklisted
	self.debug_blacklisted = false
end

---
--- Executes a step in the debugger.
--- This function is called when the client requests a step operation.
---
--- @param arguments table The arguments passed with the step request.
---
function DASocket:Request_step(arguments)
end

---
--- Executes a step into the debugger.
--- This function is called when the client requests a step into operation.
---
--- @param arguments table The arguments passed with the step into request.
---
function DASocket:Request_stepIn(arguments)
	self:SendResponse()
	DebuggerStep("step into", self.coroutine)
	self:Continue()
end

---
--- Executes a step out of the debugger.
--- This function is called when the client requests a step out operation.
---
--- @param arguments table The arguments passed with the step out request.
---
function DASocket:Request_stepOut(arguments)
	self:SendResponse()
	DebuggerStep("step out", self.coroutine)
	self:Continue()
end

---
--- Executes a step over operation in the debugger.
--- This function is called when the client requests a step over operation.
---
--- @param arguments table The arguments passed with the step over request.
---
function DASocket:Request_next(arguments)
	self:SendResponse()
	DebuggerStep("step over", self.coroutine)	-- this will send "stopped" event with reason "step" via hookBreakLuaDebugger
	self:Continue()
end

local function IsSimpleValue(value)
	local vtype = type(value)

	return vtype == "number" or vtype == "string" or vtype == "boolean" or vtype == "nil"
end

local function ValueType(value)
	local vtype = type(value)
	if vtype == "boolean" or vtype == "string" or vtype == "number" then
		return vtype
	elseif vtype == "nil" then
		return "boolean"
	else
		return "value"
	end
end

local function HandleExpressionResults(ok, result, ...)
	if not ok then
		return result
	end
	if select("#", ...) ~= 0 then
		result = setmetatable({result, ...}, __tuple_meta)
	end
	return false, result
end

local function GetRawG()
	local env = { }
	local env_meta = {}
	env_meta.__index = function(env, key)
		return rawget(_G, key)
	end
	env_meta.__newindex = function(env, key, value)
		rawset(_G, key, value)
	end
	env._G = env
	setmetatable(env, env_meta)
	return env
end

---
--- Evaluates the given expression in the context of the specified frame ID.
---
--- @param expression string The expression to evaluate.
--- @param frameId number The ID of the frame to use as the evaluation context.
--- @return boolean, any The result of the expression evaluation. If there was an error, the first return value will be false and the second return value will be the error message.
---
function DASocket:EvaluateExpression(expression, frameId)
	local expr, err = load("return " .. expression, nil, nil, frameId and self.stack_vars[frameId] or GetRawG())
	if err then
		return err
	end
	return HandleExpressionResults(pcall(expr))
end

local func_info = {}
local class_to_name
local has_CObject = false

---
--- Resolves the metatable of the given value.
---
--- @param value any The value to resolve the metatable for.
--- @return table|nil The metatable of the value, or nil if the value has no metatable or is a light userdata.
---
function Debug_ResolveMeta(value)
	local meta = getmetatable(value)
	if meta and LightUserDataValue(value) and not IsT(value) then
		return -- because LightUserDataSetMetatable(TMeta)
	end
	return meta
end

---
--- Resolves the object ID of the given object.
---
--- @param obj any The object to resolve the ID for.
--- @return string|nil The ID of the object, or nil if the ID could not be resolved.
---
function Debug_ResolveObjId(obj)
	local id = rawget(obj, "id") or rawget(obj, "Id") or PropObjHasMember(obj, "GetId") and obj:GetId() or ""
	if id ~= "" and type(id) == "string" then
		return id
	end
end

---
--- Converts the given value to a string representation.
---
--- @param value any The value to convert to a string.
--- @param max_len number (optional) The maximum length of the string representation. If the string is longer, it will be truncated with an ellipsis.
--- @return string The string representation of the value.
---
function Debugger_ToString(value, max_len)
	local vtype = type(value)
	local meta = Debug_ResolveMeta(value)
	local str
	if vtype == "string" then
		str = value
	elseif vtype == "thread" then
		local str_value = tostring(value)
		if IsRealTimeThread(value) then
			str_value = "real " .. str_value
		elseif IsGameTimeThread(value) then
			str_value = "game " .. str_value
		end
		if not IsValidThread(value) then
			str_value = "dead " .. str_value
		elseif CurrentThread() == value then
			str_value = "current " .. str_value
		end
		return str_value
	elseif vtype == "function" then
		if IsCFunction(value) then
			return "C " .. tostring(value)
		end
		return "Lua " .. tostring(value)
	elseif IsT(value) then
		str = TDevModeGetEnglishText(value, "deep", "no_assert")
		if str == "Missing text" then
			str = TTranslate(value, nil, false)
		end
	elseif vtype == "table" then
		if rawequal(value, _G) then
			return "_G"
		end
		local class = meta and value.class or ""
		str = tostring(value)
		if class ~= "" and type(class) == "string" then
			local id = Debug_ResolveObjId(value) or ""
			if id ~= "" then
				id = ' "' .. id .. '"'
			end
			local suffix, num = string.gsub(str, "^table", "")
			if num == 0 then
				suffix = ""
			end
			str = class .. id .. suffix
			if not class_to_name then
				class_to_name = table.invert(g_Classes)
				has_CObject = not not g_Classes.CObject
			end
			if class_to_name[value] then
				return "class " .. str
			elseif not IsValid(value) and has_CObject and IsKindOf(value, "CObject") then
				return "invalid object " .. str
			else
				return "object " .. str
			end
		else
			local name = rawget(value, "__name")
			if type(name) == "string" then
				return name
			end
			local count = table.count(value)
			if count > 0 then
				local len = #value
				if len > 0 then
					str = str .. " #" .. len
				end
				if len ~= count then
					str = str .. " [" .. count .. "]"
				end
			end
		end
	elseif vtype == "userdata" then
		if __cobjectToCObject and __cobjectToCObject[value] then
			return "GameObject " .. tostring(value)
		end
	end
	if meta then
		if rawget(meta, "__tostring") ~= nil then
			local ok, result = pcall(meta.__tostring, value)
			if ok then
				str = result
			end
		elseif IsGrid(value) then
			local pid = GridGetPID(value)
			local w, h = value:size()
			return "grid " .. pid .. ' ' .. w .. 'x' .. h
		elseif meta == __tuple_meta then
			return "tuple #" .. table.count(value) .. ""
		end
	end
	str = str or tostring(value)
	max_len = max_len or config.MaxWatchLenValue
	if #str > max_len then
		str = string.sub(str, 1, max_len) .. "..."
	end
	return str
end

---
--- Evaluates an expression in the context of the current debug frame.
---
--- @param arguments table The arguments for the evaluation request.
--- @param arguments.context string The context of the evaluation, either "watch" or "repl".
--- @param arguments.expression string The expression to evaluate.
--- @param arguments.frameId number The ID of the debug frame to evaluate the expression in.
--- @return table|nil, string|nil The result of the evaluation, or an error message if the evaluation failed.
---
function DASocket:Request_evaluate(arguments)
	local context = arguments.context
	if context == "watch" then
	if not self.ref_to_var then return end

		local err, result = self:EvaluateExpression(arguments.expression, arguments.frameId)
		if err then return err end
		local simple_value = IsSimpleValue(result)
		if not simple_value then
			self.var_ref_idx = self.var_ref_idx + 1
			self.ref_to_var[self.var_ref_idx] = result
		end
		local var_ref = simple_value and 0 or self.var_ref_idx

		return nil, {result = Debugger_ToString(result), variablesReference = var_ref, type = ValueType(result)}
	elseif context == "repl" then
		local err, result = self:EvaluateExpression(arguments.expression, arguments.frameId)
		if err then return err end
		local vtype = ValueType(result)
		if IsTuple(result) then
			local str = {}
			for i, val in ipairs(result) do
				str[i] = Debugger_ToString(val)
			end
			result = table.concat(str, ", ")
		else
			local str = Debugger_ToString(result)
			local entries = Debugger_GetWatchEntries(result)
			if #entries > 0 then
				local concat = {str, " {"}
				for i, entry in ipairs(entries) do
					concat[#concat + 1] = "\n\t"
					concat[#concat + 1] = Debugger_ToString(entry[1])
					concat[#concat + 1] = " = "
					concat[#concat + 1] = Debugger_ToString(entry[2])
				end
				concat[#concat + 1] = "\n}"
				str = table.concat(concat)
			end
			result = str
		end
		return nil, {result = result, type = vtype}
	end
end

--- Requests the scopes for the current debug frame.
---
--- @param arguments table The arguments for the request.
--- @param arguments.frameId number The ID of the debug frame to get the scopes for.
--- @return table|nil, table|nil The scopes, or an error message if the request failed.
function DASocket:Request_scopes(arguments)
	if not self.ref_to_var then return end

	local frame = arguments.frameId
	self.scope_frame = frame
	self.eval_env = self.stack_vars[frame]
	self.ref_to_var[variables_start] = self.eval_env

	return nil, {scopes = {
		{
			name = "Autos",
			variablesReference = variables_start,
		},
	}}
end

---
--- Retrieves the watch entries for the given variable.
---
--- @param var any The variable to get the watch entries for.
--- @return table The watch entries for the variable.
function Debugger_GetWatchEntries(var)
	local meta = Debug_ResolveMeta(var)
	local vtype = type(var)
	local values
	if vtype == "thread" then
		local current = CurrentThread() == var
		local callstack = GetStack(var) or ""
		callstack = string.tokenize(callstack, "\n")
		local last_dbg_idx
		for i, line in ipairs(callstack) do
			if line:find_lower("CommonLua/Libs/DebugAdapter") then
				last_dbg_idx = i
			end
		end
		if last_dbg_idx then
			local clean_stack = {}
			for i=last_dbg_idx + 1,#callstack do
				clean_stack[#clean_stack + 1] = callstack[i]
			end
			callstack = clean_stack
		end
		values = {
			type = IsRealTimeThread(var) and "real" or IsGameTimeThread(var) and "game" or "",
			current = current,
			status = GetThreadStatus(var) or "dead",
			callstack = callstack,
		}
	elseif vtype == "function" then
		if not IsCFunction(var) then
			local info = func_info[var]
			if not info then
				info = debug.getinfo(var) or empty_table
				func_info[var] = info
			end
			if info.short_src and info.linedefined and info.linedefined ~= -1 then
				values = {
					source = string.format("%s(%d)", info.short_src, info.linedefined),
				}
			end
		end
	elseif vtype == "userdata" then
		if __cobjectToCObject and __cobjectToCObject[var] then
			return
		end
		if meta and meta.__debugview then
			local ok, result = pcall(meta.__debugview, var)
			if ok then
				values = result
			end
		end
	elseif vtype == "table" then
		values = var
	end
	
	local entries = {}
	if meta then
		table.insert(entries, {"metatable", meta})
	end
	local biggest_number, number_keys_entries, other_keys_entries = 0
	for key, value in pairs(values) do
		if type(key) == "number" then
			number_keys_entries = table.create_add(number_keys_entries, { key, value })
			biggest_number = Max(biggest_number, key)
		else
			local key_str = Debugger_ToString(key, const.MaxWatchLenKey)
			other_keys_entries = table.create_add(other_keys_entries, { key_str, value })
		end
	end
	if number_keys_entries then
		table.sortby_field(number_keys_entries, 1)
		local max_len = #tostring(biggest_number)
		for _, entry in ipairs(number_keys_entries) do
			local key, value = entry[1], entry[2]
			local key_str = tostring(key)
			key_str = string.rep(" ", max_len - #key_str) .. key_str
			table.insert(entries, { key_str, value })
		end
	end
	if other_keys_entries then
		table.sort(other_keys_entries, function(e1, e2) return CmpLower(e1[1], e2[1]) end)
		table.iappend(entries, other_keys_entries)
	end
	
	return entries
end

---
--- Handles a request to retrieve the variables associated with a specific variables reference.
---
--- @param arguments table The arguments for the request, containing the variables reference.
--- @return nil, table|nil The variables associated with the specified reference, or nil if there are no variables.
---
function DASocket:Request_variables(arguments)
	if not self.var_ref_idx then return end
	if not arguments then return end
	
	local var_ref = arguments.variablesReference
	if not var_ref then return end
	
	
	local entries = Debugger_GetWatchEntries(self.ref_to_var[var_ref])
	if #entries == 0 then return end
	
	local variables = {}
	for i, entry in ipairs(entries) do
		variables[i] = self:CreateVar(entry[1], entry[2])
	end
	return nil, { variables = variables }
end

---
--- Sets the value of a variable in the current scope.
---
--- @param var_name string The name of the variable to set.
--- @param new_value any The new value to assign to the variable.
--- @return any The new value of the variable.
---
function DASocket:SetVariableValue(var_name, new_value)
	local vars = self.stack_vars[self.scope_frame]
	local var_index, up_value_func = vars:__get_value_index(var_name)
	rawset(vars, var_name, new_value)
	local result
	-- local variales are shadowing the upvalues with the same name
	if up_value_func then
		result = debug.setupvalue(up_value_func, var_index, new_value)
	else
		result = debug.setlocal(self.scope_frame + 8, var_index, new_value)
	end
	
	return vars[result]
end

---
--- Sets the value of a variable in the current scope.
---
--- @param arguments table The arguments for the request, containing the name and new value of the variable to set.
--- @return nil, table The new value of the variable, and its type.
---
function DASocket:Request_setVariable(arguments)
	if not self.ref_to_var then return end

	local new_value = self:SetVariableValue(arguments.name, arguments.value)

	return nil, {value = new_value, type = ValueType(new_value)}
end

---
--- Sets the value of a variable in the current scope.
---
--- @param arguments table The arguments for the request, containing the name and new value of the variable to set.
--- @return nil, table The new value of the variable, and its type.
---
function DASocket:Request_setExpression(arguments)
	if not self.ref_to_var then return end

	local var_name = arguments.expression
	local err, eval = self:EvaluateExpression(var_name, arguments.frameId)
	if err then return err end

	local result = self:SetVariableValue(var_name, arguments.value)

	return nil, {value = result, type = ValueType(result)}
end

---
--- Handles the 'loadedSources' request from the debug adapter client.
--- This request is used to retrieve the list of loaded source files.
---
--- @param arguments table The arguments for the request, containing the start and count of modules to retrieve.
--- @return nil, table The list of loaded source files and the total number of modules.
---
function DASocket:Request_loadedSources(arguments)
end

---
--- Handles the 'source' request from the debug adapter client.
--- This request is used to retrieve the source code for a specific source file.
---
--- @param arguments table The arguments for the request, containing the source file to retrieve.
--- @return nil, table The source code for the requested file.
---
function DASocket:Request_source(arguments)
end

---
--- Terminates the debug adapter session.
---
--- @param arguments table The arguments for the request, containing any necessary information to terminate the session.
---
function DASocket:Request_terminate(arguments)
	CreateRealTimeThread(quit, 1)
end

---
--- Handles the 'modules' request from the debug adapter client.
--- This request is used to retrieve the list of loaded modules (Libs, DLCs and Mods).
---
--- @param arguments table The arguments for the request, containing the start and count of modules to retrieve.
--- @return nil, table The list of loaded modules and the total number of modules.
---
function DASocket:Request_modules(arguments)
	-- list Libs, DLCs and Mods as modules
	local startModule = arguments.startModule or 0
	local moduleCount = arguments.moduleCount or 0
	local modules = {}
	for _, mod in ipairs(ModsLoaded) do
		table.insert(modules, {id = mod.id, name = mod.name})
	end

	return nil, {modules = modules, totalModules = #modules}
end

local function GetTextLine(text, line)
	local line_number = 1
	for text_line in string.gmatch(text, "[\r\n]+") do
		if line_number == line then
			return text_line
		end
	end

	return text
end

local completion_type_remap = {
	["value"] = "value",
	["f"] = "function",
}

local function GetCompletionsList(line, column, frameId)
	local completions = GetAutoCompletionList(line, column)

	for _, completion in ipairs(completions) do
		completion.type = completion_type_remap[completion.kind]
		completion.kind = nil
		completion.label = completion.value
		completion.value = nil
	end

	return completions
end

---
--- Handles the 'completions' request from the debug adapter client.
--- This request is used to retrieve the list of available code completions for a given line and column.
---
--- @param arguments table The arguments for the request, containing the text, line, and column for which to retrieve completions.
--- @return nil, table The list of available code completions.
---
function DASocket:Request_completions(arguments)
	local line = GetTextLine(arguments.text, arguments.line)
	if line then
		return nil, {targets = GetCompletionsList(line, arguments.column)}
	end
end

local stop_reasons_map = {
	step = "step",
	breakpoint = "breakpoint",
	pause = "pause",
	exception = "exception",
}
local stop_descriptions_map = { -- shown in UI
	step = "Step",
	breakpoint = "Breakpoint",
	pause = "Pause",
	exception = "Exception",
}

---
--- Handles the 'stopped' event from the debug adapter client.
--- This event is used to notify the client that the debugged program has stopped execution.
---
--- @param reason string The reason the program stopped, such as "step", "breakpoint", "pause", or "exception".
--- @param bp_id number The ID of the breakpoint that was hit, if applicable.
---
function DASocket:OnStopped(reason, bp_id)
	if self.state then
		self.state = "stopped"
		self:SendEvent("stopped", {
			reason = stop_reasons_map[reason] or "pause",
			description = stop_descriptions_map[reason],
			allThreadsStopped = true,
			threadId = threads_start + 1,
			hitBreakpointIds = bp_id and {bp_id} or nil,
		})
	end
end

---
--- Sends an output event to the debug adapter client when the debugged program produces output.
---
--- @param text string The output text to send to the client.
--- @param output_type string (optional) The category of the output, such as "console".
---
function DASocket:OnOutput(text, output_type)
	if self.state == "running" then
		self:SendEvent("output", {
			output = text,
			category = output_type or "console",
		})
	end
end

---
--- Calls the specified method on each debugger in the DAServer.debuggers table, passing the additional arguments.
---
--- @param method string The name of the method to call on each debugger.
--- @param ... any Additional arguments to pass to the method.
---
function ForEachDebugger(method, ...)
	for _, debugger in ipairs(DAServer.debuggers) do
		debugger[method](debugger, ...)
	end
end

function OnMsg.ConsoleLine(text, bNewLine)
	ForEachDebugger("OnOutput", bNewLine and ("\r\n" .. text) or text)
end

---
--- Handles the exit event for the debug adapter client.
--- This event is used to notify the client that the debugged program has exited.
---
--- @param self DASocket The instance of the DASocket class.
--- @return nil
---
function DASocket:OnExit()
	if self.state then
		self:SendEvent("exited", {
			exitCode = GetExitCode(),
		})
	end
end

---
--- Updates the DASocket instance, processing socket events while the manual_pause flag is set.
---
--- @param self DASocket The instance of the DASocket class.
---
function DASocket:Update()
	while self.manual_pause do
		sockProcess(1)
	end
end

local function CaptureVars(co, level)
	local vars = {}
	
	local info
	if co then
		info = debug.getinfo(co, level, "fu")
	else
		info = debug.getinfo(level + 1, "fu")
	end
	local func = info and info.func or nil
	if not func then return vars end
	
	local i = 1
	local local_nils = {}
	local upvalue_nils = {}
	local local_var_index = {}
	local upvalue_var_index = {}
	
	local function capture(var_index, index, nils, name, value)
		if name then
			if rawequal(value, nil) then
				nils[name] = true
			else
				vars[name] = value
			end
			var_index[name] = index
			
			return name
		end
	end
	
	-- upvalues first
	for i = 1, info.nups do
		capture(upvalue_var_index, i, upvalue_nils, debug.getupvalue(func, i))
	end

	-- local vars can shadow upvalues and if available and edited - they should change(not shadowed upvalue)
	if co then
		while capture(local_var_index, i, local_nils, debug.getlocal(co, level, i)) do
			i = i + 1
		end
	else
		while capture(local_var_index, i, local_nils, debug.getlocal(level + 1, i)) do
			i = i + 1
		end
	end
	
	vars.__get_value_index = function(t, key)
		if local_var_index[key] then
			return local_var_index[key]
		else
			return upvalue_var_index[key], func
		end
	end

	return setmetatable(vars, {
		__index = function (t, key)
			if local_var_index[key] then
				if local_nils[key] then
					return nil
				end
			else
				if upvalue_nils[key] then
					return nil
				end
			end

			return rawget(_G, key)
		end,
	})
end

local function GetStackFrames(startColumn, arguments)
	arguments = arguments or empty_table
	
	local co = arguments.co
	local level = arguments.level or 0
	local max_levels = arguments.max_levels
	
	local stack_frames = {}
	local stack_vars = {}

	repeat
		local info
		if arguments.co then
			info = debug.getinfo(co, level, "nSl")
		else
			info = debug.getinfo(level, "nSl")
		end
		if not info then break end
		
		local vars = CaptureVars(co, level)
		local path = string.sub(info.source, string.match(info.source, "^@") and 2 or 1, -1)
		local visible = config.DebugBlacklistedSource or not string.match(path, "/DebugAdapter.lua$")
		local skip_frame = visible and #stack_frames == 0 and (info.name == "assert" or info.name == "error" or info.short_src == "[C]")
		if visible and not skip_frame then
			local os_path = is_running_packed and ConvertToOSPath(PackedToUnpackedLuaPath(path)) or ConvertToOSPath(path)
			local known_source = info.short_src ~= "[C]" and not string.starts_with(info.short_src, "[string")
			local default_name = known_source and "?" or info.short_src
			local stackFrame = {}
			stackFrame.id = #stack_frames + 1
			stackFrame.name = string.format("%s (%s%s)", info.name or default_name, info.what, (info.namewhat or "") ~= "" and ("-" .. info.namewhat) or "")
			if known_source then
				stackFrame.source = {
					name = info.short_src,
					path = os_path,
				}
				stackFrame.line = info.currentline
			else
				stackFrame.line = 0
			end
			stackFrame.column = 0
			table.insert(stack_frames, stackFrame)
			table.insert(stack_vars, vars)
		end
		level = level + 1
	until (level > 100) or (max_levels and #stack_frames >= max_levels)
	
	return {stackFrames = stack_frames, totalFrames = #stack_frames}, stack_vars
end

---
--- Updates the stack frames for the current debug session.
---
--- @param arguments table An optional table of arguments to pass to `GetStackFrames`.
---                     Supported keys:
---                     - `co`: the coroutine to get the stack frames for
---                     - `level`: the starting stack frame level
---                     - `max_levels`: the maximum number of stack frames to retrieve
function DASocket:UpdateStackFrames(arguments)
	self.callstack, self.stack_vars = GetStackFrames(self.columnsStartAt1 and 1 or 0, arguments)
end

---
--- Creates a variable object for the debug adapter protocol.
---
--- @param var_name string The name of the variable.
--- @param var_value any The value of the variable.
--- @return table The variable object with the following fields:
---               - `name`: the name of the variable
---               - `value`: the string representation of the variable value
---               - `type`: the type of the variable value
---               - `variablesReference`: a reference to the child variables, or 0 if the value is simple
---               - `evaluateName`: the expression to evaluate the variable, or `nil` if not supported
function DASocket:CreateVar(var_name, var_value)
	local simple_value = IsSimpleValue(var_value)
	if not simple_value then
		self.var_ref_idx = self.var_ref_idx + 1
		self.ref_to_var[self.var_ref_idx] = var_value
	end
	local var = {
		name = var_name,
		value = Debugger_ToString(var_value),
		type = ValueType(var_value),
		variablesReference = simple_value and 0 or self.var_ref_idx,
		evaluateName = config.DebugAdapterUseSetExpression and var_name or nil,
	}
	return var
end

---
--- Continues the current debug session.
---
--- This function resets the call stack, scope frame, stack variables, variable reference index,
--- reference to variables, and coroutine. It also sets the state of the debug adapter to "running".
---
--- This function is typically called after a breakpoint or pause in the debug session to resume
--- execution of the program.
---
function DASocket:Continue()
	self.callstack = false
	self.scope_frame = false
	self.stack_vars = false
	self.var_ref_idx = false
	self.ref_to_var = false
	self.coroutine = false
	self.state = "running"
end

---
--- Breaks the current debug session and enters a stopped state.
---
--- This function is called when a breakpoint is hit or the debugger is paused.
--- It updates the call stack, scope frame, and stack variables, and then enters a stopped state.
--- The function will block until the debugger is manually resumed or a timeout occurs.
---
--- @param reason string The reason for the break, either "breakpoint" or "pause".
--- @param co table The coroutine that was paused.
--- @param break_offset number The offset of the break point.
--- @param level number The level of the call stack to start from.
---
function DASocket:Break(reason, co, break_offset, level)
	self.coroutine = co
	self:UpdateStackFrames({level = level, co = co, break_offset = break_offset})
	local bp_id
	if reason == "breakpoint" then
		for _, stack_frame in ipairs(self.callstack.stackFrames) do
			if stack_frame.source then
				local stack_path = stack_frame.source.path:lower()
				local stack_breakpoints = self.breakpoints and self.breakpoints[stack_path]
				local bp = stack_breakpoints and stack_breakpoints[stack_frame.line]
				if bp and bp.verified then
					bp_id = bp.id
					break
				end
			end
		end
	end
	if self.state ~= "stopped" then
		self:OnStopped(reason, bp_id)
	end
	if not self.in_break then
		self.in_break = true
		while not self.manual_pause and self.state == "stopped" do
			sockProcess(1)
		end
		self.in_break = false
	end
end

----- DAServer

DAServer = rawget(_G, "DAServer") or { -- simple lua table, since it needs to work before the class resolution
	host = "127.0.0.1",
	port = 8165,
	debuggers = {},
}

---
--- Starts the DebugAdapter server and waits for a connection if requested.
---
--- This function sets up the DebugAdapter server to listen for incoming connections.
--- If `replace_previous` is true and there is an existing DebugAdapter server running,
--- it will attempt to connect to it and shut it down before starting a new server.
--- If `wait_debugger_time` is provided, the function will block until a connection is
--- established or the timeout is reached.
---
--- @param replace_previous boolean If true, will attempt to replace an existing DebugAdapter server.
--- @param wait_debugger_time number The maximum time in milliseconds to wait for a connection.
--- @param host string The host address to listen on.
--- @param port number The port to listen on.
--- @return boolean True if a connection was established, false otherwise.
---
function DAServer:Start(replace_previous, wait_debugger_time, host, port)
	if not self.listen_socket then
		self.host = host or self.host
		self.port = port or self.port
		self.listen_socket = DASocket:new{
			OnAccept = function (self, ...) return DAServer:OnAccept(...) end,
		}
		local err = sockListen(self.listen_socket, self.host, self.port)
		if replace_previous and err == "address in use" then
			print("Replacing existing DebugAdapter")
			local timeout = GetPreciseTicks() + 2000
			-- there is another debugee running, connect to it and shut it down
			local conn = DASocket:new()
			local conn_err = sockConnect(conn, timeout, self.host, self.port)
			if not conn_err then
				while GetPreciseTicks() - timeout < 0 and sockIsConnecting(conn) do
					sockProcess(1)
				end	
			end
			if conn:IsConnected() then
				conn:SendEvent("StopDAServer")
				sockProcess(200)
				conn:delete()
				-- try again
				err = sockListen(self.listen_socket, self.host, self.port)
			end
		end
		if err then
			print("DebugAdapter listen error: ", err)
			self.listen_socket:delete()
			self.listen_socket = nil
		else
			--[[]]printf("DebugAdapter started at %s:%d", self.host, self.port)
		end
	end
	if self.listen_socket and wait_debugger_time then -- wait for connection
		local timeout = GetPreciseTicks() + wait_debugger_time
		while GetPreciseTicks() - timeout < 0 and #self.debuggers == 0 do
			sockProcess(1)
		end
	end
	return #self.debuggers > 0
end

--- Stops the DebugAdapter server.
---
--- This function stops the DebugAdapter server by:
--- - Calling `OnExit()` on each connected debugger
--- - Deleting the listen socket and setting it to `nil`
---
--- This function should be called when the DebugAdapter server is no longer needed, such as when the application is shutting down.
function DAServer:Stop()
	for _, da in ipairs(self.debuggers) do
		da:OnExit()
	end
	if self.listen_socket then
		self.listen_socket:delete()
		self.listen_socket = nil
	end
end

---
--- Handles the acceptance of a new connection to the DebugAdapter server.
---
--- This function is called when a new connection is accepted by the DebugAdapter server. It creates a new `DASocket` object to represent the connection, adds it to the list of debuggers, and starts a real-time thread to process the connection.
---
--- @param socket table The socket object representing the new connection.
--- @param host string The host address of the new connection.
--- @param port number The port of the new connection.
--- @return table The `DASocket` object representing the new connection.
function DAServer:OnAccept(socket, host, port)
	self.connections = (self.connections or 0) + 1
	local sock_obj = DASocket:new{
		[true] = socket,
		host = host,
		port = port,
		event_source = string.format("DASocket#%d ", self.connections),
		connection = self.connections,
	}
	self.debuggers[#self.debuggers + 1] = sock_obj
	DAServer.thread = IsValidThread(DAServer.thread) or CreateRealTimeThread(function()
		while #DAServer.debuggers > 0 do
			sockProcess(0)
			ForEachDebugger("Update")
			WaitWakeup(50)
		end
		DAServer.thread = nil
	end)
	printf("DebugAdapter connection %d %s:%d", sock_obj.connection, host, port)
	return sock_obj
end

---
--- Starts the DebugAdapter server.
---
--- This function starts the DebugAdapter server by:
--- - Calling `DAServer:Start()` to start the server
--- - Updating the thread debug hook to the actual hook
--- - Enabling the debugger hook
---
--- This function should be called to start the DebugAdapter server, which allows debuggers to connect and debug the application.
---
--- @param replace_previous boolean Whether to replace a previously active debugger
--- @param wait_debugger_time number The amount of time to wait for a debugger to connect
--- @param host string The host address for the DebugAdapter server
--- @param port number The port for the DebugAdapter server
function Debug(replace_previous, wait_debugger_time, host, port)
	if DAServer.listen_socket then return end -- debugger already active
	DAServer:Start(
		replace_previous, 
		wait_debugger_time,
		host,
		port or config.DebugAdapterPort) -- start without waiting for connection
	UpdateThreadDebugHook()				-- change to the actual hook
	DebuggerEnableHook(true)
end

----- globals

function OnMsg.Autodone()
	DAServer:Stop()
end

---
--- Checks if the DebugAdapter server is currently listening for connections.
---
--- @return boolean true if the DebugAdapter server is listening, false otherwise
function IsDAServerListening()
	return not not (rawget(_G, "DAServer") and DAServer.listen_socket)
end

if not Platform.ged then
	Debug(true)
end

---
--- Called from C to pass the self param, this function notifies all registered debuggers that a break has occurred.
---
--- @param reason string The reason for the break, e.g. "exception"
function hookBreakLuaDebugger(reason)
	ForEachDebugger("Break", reason, nil, nil, 5)
	if config.EnableHaerald and rawget(_G, "g_LuaDebugger") then
		g_LuaDebugger:Break()
	end
end


---
--- Replaces placeholders in a log message with the evaluated values of the expressions in the placeholders.
---
--- @param log_msg string The log message with placeholders to be replaced.
--- @return string The log message with the placeholders replaced by their evaluated values.
function hookLogPointLuaDebugger(log_msg)
	log_msg = string.gsub(log_msg, "{.-}", function(expression) 
		expression = string.sub(expression, 2, -2)
		local vars = CaptureVars(nil, 7)
		local expr, err = load("return " .. expression, nil, nil, vars)
		if err then
			return err
		else
			local ok, result = pcall(expr)
			return result
		end
	end)
	printf("LogPoint: %s", log_msg)
	ForEachDebugger("OnOutput", log_msg)
end

local oldStartDebugger = rawget(_G, "StartDebugger") or empty_func

---
--- Starts the debugger, enabling the Haerald debugger if it is configured to be enabled.
---
--- If the Haerald debugger is enabled, this function will call the original `StartDebugger()` function.
---
--- @return nil
function StartDebugger()
	Debug(true)
	
	if config.EnableHaerald then
		return oldStartDebugger()
	end
end

---
--- Starts the debugger and breaks execution at the specified coroutine and offset.
---
--- If the DebugAdapter server is listening, this function will enable the debugger hook and notify all registered debuggers of the break.
---
--- If the Haerald debugger is enabled, this function will also call the Haerald debugger's `Break()` method.
---
--- @param co table|nil The coroutine to break at, or `nil` to break at the current coroutine.
--- @param break_offset number The offset in the coroutine where the break should occur.
--- @return nil
function _G.startdebugger(co, break_offset)
	Debug(true)
	UpdateThreadDebugHook()	-- change to the actual hook
	StartDebugger()
	if IsDAServerListening() then
		DebuggerEnableHook(true)
		ForEachDebugger("Break", "exception", co, break_offset, co and 0 or 1)
	end
	if rawget(_G, "g_LuaDebugger") and config.EnableHaerald then
		DebuggerEnableHook(true)
		g_LuaDebugger:Break(co, break_offset)
	end
end

---
--- Breaks execution at the current coroutine or a specified coroutine and offset.
---
--- If the DebugAdapter server is listening, this function will enable the debugger hook and notify all registered debuggers of the break.
---
--- If the Haerald debugger is enabled, this function will also call the Haerald debugger's `Break()` method.
---
--- @param ... Either no arguments, or a single number specifying the offset in the coroutine where the break should occur.
--- @return nil
function _G.bp(...)
	if not (select("#", ...) == 0 or select(1, ...)) then return end
	
	Debug(true)
	UpdateThreadDebugHook()	-- change to the actual hook
	StartDebugger()
	DebuggerEnableHook(true)
	local break_offset = select(2, ...)
	if IsDAServerListening() then
		ForEachDebugger("Break", "breakpoint", nil, break_offset, 5)
	end
	if rawget(_G, "g_LuaDebugger") and config.EnableHaerald then
		g_LuaDebugger:Break(nil, break_offset)
	end
end