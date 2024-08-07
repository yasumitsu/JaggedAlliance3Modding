if not rawget(_G, "sockProcess") then return end

-- SocketObjs is initialized by luaHGSocket.cpp

DefineClass.BaseSocket = {
	__parents = { "InitDone", "EventLogger" },
	[true] = false,
	
	owner = false,
	socket_type = "BaseSocket",
	stats_group = 0,
	
	host = false,
	port = false,

	msg_size_max = 1 * 1024 * 1024,
	timeout = 60 * 60 * 1000,

	Send = sockSend,
	Listen = sockListen,
	Disconnect = sockDisconnect,
	IsConnected = sockIsConnected,
	SetOption = sockSetOption,
	GetOption = sockGetOption,
	
	SetAESEncryptionKey = sockEncryptionKey,
	
	GenRSAEncryptedKey = sockGenRSAEncryptedKey,
	SetRSAEncryptedKey = sockSetRSAEncryptedKey,
}

--- Initializes a new BaseSocket instance.
---
--- This function is called when a new BaseSocket object is created. It sets up the underlying socket object, configures the socket options, and associates the socket with the BaseSocket instance.
---
--- @param self BaseSocket The BaseSocket instance being initialized.
--- @return none
function BaseSocket:Init()
	local socket = self[true] or sockNew()
	self[true] = socket
	SocketObjs[socket] = self
	self:SetOption("timeout", self.timeout)
	self:SetOption("maxbuffer", self.msg_size_max)
	sockSetGroup(self, self.stats_group)
end

---
--- Finalizes and cleans up a BaseSocket instance.
---
--- This function is called when a BaseSocket instance is being destroyed. It performs the following actions:
--- - Notifies the owner (if any) that the connection is done.
--- - Disconnects the socket if it is still connected.
--- - Deletes the underlying socket object and removes the association with the BaseSocket instance.
---
--- @param self BaseSocket The BaseSocket instance being finalized.
--- @return none
function BaseSocket:Done()
	local owner = self.owner
	if owner then
		owner:OnConnectionDone(self)
	end
	local socket = self[true]
	if SocketObjs[socket] == self then
		if self:IsConnected() then
			self:OnDisconnect("delete")
		end
		sockDelete(socket)
		SocketObjs[socket] = nil
		self[true] = false
	end
end

--- Updates the event source string for the socket.
---
--- The event source string is a formatted string that represents the socket's connection details. It is used for logging and other purposes.
---
--- If the socket is connected, the event source string will be in the format `"<host>:<port>(<socket_id>)"`. If the socket is not connected, the event source string will be in the format `"-(<socket_id>)"`.
---
--- @param self BaseSocket The BaseSocket instance.
--- @return none
function BaseSocket:UpdateEventSource()
	if self.host and self.port then
		self.event_source = string.format("%s:%d(%s)", self.host, self.port, sockStr(self))
	else
		self.event_source = string.format("-(%s)", sockStr(self))
	end
end

---
--- Connects the socket to the specified host and port.
---
--- @param self BaseSocket The BaseSocket instance.
--- @param timeout number The timeout value in milliseconds for the connection attempt.
--- @param host string The host to connect to.
--- @param port number The port to connect to.
--- @return number|nil The error code if the connection failed, or nil if the connection was successful.
function BaseSocket:Connect(timeout, host, port)
	self.host = host
	self.port = port
	self:UpdateEventSource()
	return sockConnect(self, timeout, host, port)
end

---
--- Waits for the socket to connect to the specified host and port.
---
--- @param self BaseSocket The BaseSocket instance.
--- @param timeout number The timeout value in milliseconds for the connection attempt.
--- @param host string The host to connect to.
--- @param port number The port to connect to.
--- @return number|nil The error code if the connection failed, or nil if the connection was successful.
function BaseSocket:WaitConnect(timeout, host, port)
	local err = self:Connect(timeout, host, port)
	if err then return err end
	return select(2, WaitMsg(self))
end

---
--- Accepts a new socket connection and creates a new socket object for it.
---
--- This function is called when a new socket connection is accepted. It creates a new socket object of the same type as the current socket, initializes it with the accepted socket, and calls the `OnConnect` method on the new socket. If the current socket has an owner, the `OnConnectionInit` method is also called on the owner.
---
--- @param self BaseSocket The BaseSocket instance.
--- @param socket userdata The accepted socket.
--- @param host string The host of the accepted connection.
--- @param port number The port of the accepted connection.
--- @return BaseSocket The new socket object.
function BaseSocket:OnAccept(socket, host, port)
	local owner = self.owner
	local sock = g_Classes[self.socket_type]:new{
		[true] = socket,
		owner = owner,
	}
	sock:OnConnect(nil, host, port)
	if owner then
		owner:OnConnectionInit(sock)
	end
	return sock
end

---
--- Called when the socket has connected.
---
--- @param self BaseSocket The BaseSocket instance.
--- @param err number|nil The error code if the connection failed, or nil if the connection was successful.
--- @param host string The host that the socket connected to.
--- @param port number The port that the socket connected to.
--- @return BaseSocket The BaseSocket instance.
function BaseSocket:OnConnect(err, host, port)
	Msg(self, err)
	self.host = not err and host or nil
	self.port = not err and port or nil
	self:UpdateEventSource()
	--self:Log("OnConnect")
	return self
end

--- Called when the socket is disconnected.
---
--- @param self BaseSocket The BaseSocket instance.
--- @param reason string The reason for the disconnection.
function BaseSocket:OnDisconnect(reason)
end

---
--- Called when data is received on the socket.
---
--- @param self BaseSocket The BaseSocket instance.
--- @param ... any Any additional arguments passed to the function.
function BaseSocket:OnReceive(...)
end


----- MessageSocket

DefineClass.MessageSocket = {
	__parents = { "BaseSocket" },
	
	socket_type = "MessageSocket",
	
	--__hierarchy_cache = true,
	call_waiting_threads = false,
	call_timeout = 30000,
	
	msg_size_max = 16*1024,

	-- default strings table, do not modify
	serialize_strings = {
		"rfnCall",
		"rfnResult",
		"rfnStrings",
	},
	-- autogenerated:
	serialize_strings_pack = false,
	[1] = false, -- idx_to_string
	[2] = false, -- string_to_idx
}


local weak_values = { __mode = "v" }

--- Initializes a new MessageSocket instance.
---
--- This function sets up the `call_waiting_threads` table with weak values, and sets the "message" option on the socket.
---
--- @param self MessageSocket The MessageSocket instance to initialize.
function MessageSocket:Init()
	self.call_waiting_threads = {}
	setmetatable(self.call_waiting_threads, weak_values)
	
	self:SetOption("message", true)
end

---
--- Called when the socket is disconnected.
---
--- This function cleans up any waiting threads that were registered for remote function calls. It also clears the serialization-related fields on the `MessageSocket` instance.
---
--- @param self MessageSocket The `MessageSocket` instance.
--- @param reason string The reason for the disconnection.
function MessageSocket:OnDisconnect(reason)
	local call_waiting_threads = self.call_waiting_threads
	if next(call_waiting_threads) then
		for id, thread in pairs(call_waiting_threads) do
			Wakeup(thread, "disconnected")
			call_waiting_threads[id] = nil
		end
	end
	self.serialize_strings = nil
	self[1] = nil
	self[2] = nil
end

--Temporary?
--- Serializes the given arguments using the serialization table stored in `self[2]`.
---
--- @param self MessageSocket The `MessageSocket` instance.
--- @param ... any The arguments to serialize.
--- @return string The serialized data.
function MessageSocket:Serialize(...)
	return SerializeStr(self[2], ...)
end

--- Deserializes the given arguments using the deserialization table stored in `self[1]`.
---
--- @param self MessageSocket The `MessageSocket` instance.
--- @param ... any The arguments to deserialize.
--- @return any The deserialized data.
function MessageSocket:Unserialize(...)
	return UnserializeStr(self[1], ...)
end

if Platform.developer then
---
--- Recursively compares two values and generates a table of differences.
---
--- @param data1 any The first value to compare.
--- @param data2 any The second value to compare.
--- @param diff table A table to store the differences.
--- @param depth number The current depth of the recursive comparison.
---
--- @return nil
function GetDeepDiff(data1, data2, diff, depth)
	depth = depth or 1
	assert(depth < 20)
	if depth >= 20 then return end
	local function add(d)
		for i=1,#diff do
			if compare(diff[i], d) then --> don't add the same diff twice
				return
			end
		end
		diff[ #diff + 1 ] = d
	end
	if data1 == data2 then return end
	local type1 = type(data1)
	local type2 = type(data2)
	if type1 ~= type2 then
		add(format_value(data1))
	elseif type1 == "table" then
		for k, v1 in pairs(data1) do
			local v2 = data2[k]
			if v1 ~= v2 then
				if v2 == nil then
					add{[k] = format_value(v1)}
				else
					GetDeepDiff(v1, v2, diff, depth + 1)
				end
			end
		end
	else
		add(data1)
	end
end

---
--- Sends data over the socket, ensuring that the serialized and unserialized data match.
---
--- @param self MessageSocket The `MessageSocket` instance.
--- @param ... any The data to send.
---
--- @return string|nil An error message if the send failed, or `nil` on success.
function MessageSocket:Send(...)
	local original_data = {...}
	local unserialized_data = {UnserializeStr(self[1], SerializeStr(self[2], ...))}
	if not compare(original_data, unserialized_data, nil, true) then
		rawset(_G, "__a", original_data)
		rawset(_G, "__b", unserialized_data)
		rawset(_G, "__diff", {})
		GetDeepDiff(original_data, unserialized_data, __diff)
		assert(false)
	end
	return sockSend(self, ...)
end
end

--------- rfn ------------

---
--- Decompresses and evaluates the remote serialize_strings, storing the result in the `serialize_strings` and `[1]` and `[2]` fields of the `MessageSocket` instance.
---
--- @param self MessageSocket The `MessageSocket` instance.
--- @param serialize_strings_pack string The compressed serialized strings.
---

function MessageSocket:rfnStrings( serialize_strings_pack )
	-- decompress and evaluate the remote serialize_strings
	local loader = load( "return " .. Decompress( serialize_strings_pack ))
	local idx_to_string = loader and loader()
	if type( idx_to_string ) ~= "table" then
		assert( false, "Failed to unserialize the string serialization table!" )
		self:Disconnect()
		return
	end
	self.serialize_strings = idx_to_string
	self[1] = idx_to_string
	self[2] = table.invert(idx_to_string)
end

if FirstLoad then
	rcallID = 0
end

local function passResults(ok, ...)
	if ok then return ... end
	return "timeout"
end

local hasRfnPrefix = hasRfnPrefix
local launchRealTimeThread = LaunchRealTimeThread
---
--- Calls a remote function on the server and waits for the result.
---
--- @param func string The name of the remote function to call.
--- @param ... any Arguments to pass to the remote function.
--- @return string|nil An error message if the call failed, or the result of the remote function call.
function MessageSocket:Call(func, ...)
	assert(hasRfnPrefix(func))
	local id = rcallID
	rcallID = id + 1
	local err = self.Send(self, "rfnCall", id, func, ...)
	if err then return err end
	if not CanYield() then
		self:ErrorLog("Call cannot sleep", func, TupleToLuaCode(...), GetStack(2))
		return "not in thread"
	end
	self.call_waiting_threads[id] = CurrentThread()
	return passResults(WaitWakeup(self.call_timeout))
end

local function __f(id, func, self, ...)
	local err = self.Send(self, "rfnResult", id, func(self, ...))
	if err and err ~= "disconnected" and err ~= "no socket" then
		self:ErrorLog("Result send failed", err)
	end
	return err
end
---
--- Handles a remote function call from the server.
---
--- @param id number The unique identifier for the remote function call.
--- @param name string The name of the remote function to call.
--- @param ... any Arguments to pass to the remote function.
--- @return string|nil An error message if the call failed, or the result of the remote function call.
function MessageSocket:rfnCall(id, name, ...)
	if hasRfnPrefix(name) then
		local func = self[name]
		if func then
			return launchRealTimeThread(__f, id, func, self, ...)
		end
	end
	self:ErrorLog("Call name", name)
	self:Disconnect()
end

---
--- Handles the result of a remote function call from the server.
---
--- @param id number The unique identifier for the remote function call.
--- @param ... any The result of the remote function call.
function MessageSocket:rfnResult(id, ...)
	local thread = self.call_waiting_threads[id]
	self.call_waiting_threads[id] = nil
	Wakeup(thread, ...)
end

function OnMsg.ClassesPreprocess(classdefs)
	for name, classdef in pairs(classdefs) do
		local serialize_strings = rawget(classdef, "serialize_strings")
		if serialize_strings then
			classdef.serialize_strings_pack = Compress( TableToLuaCode( serialize_strings ) )
			classdef[1] = serialize_strings
			classdef[2] = table.invert(serialize_strings)
		end
	end
end