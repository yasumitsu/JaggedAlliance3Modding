
local sockProcess = sockProcess

---
--- Provides a new LuaSocket object with default settings.
---
--- @param self table The LuaSocket table
--- @param obj table An optional table to use as the new LuaSocket object
--- @return table The new LuaSocket object
function LuaSocket.new(self, obj)
end

--- Handles the connection acceptance event.
---
--- @param self table The LuaSocket table
--- @param socket table The accepted socket
--- @param host string The host of the accepted socket
--- @param port number The port of the accepted socket
function LuaSocket.OnAccept(self, socket, host, port)
end

--- Handles the connection event.
---
--- @param self table The LuaSocket table
--- @param err string The error message, if any
--- @param host string The host of the connected socket
--- @param port number The port of the connected socket
function LuaSocket.OnConnect(self, err, host, port)
end

--- Handles the disconnection event.
---
--- @param self table The LuaSocket table
--- @param reason string The reason for the disconnection
function LuaSocket.OnDisconnect(self, reason)
end

--- Handles the data reception event.
---
--- @param self table The LuaSocket table
--- @param msg string The received message
function LuaSocket.OnReceive(self, msg)
end

--- Logs the traffic (incoming or outgoing) if logging is enabled.
---
--- @param self table The LuaSocket table
--- @param type string The type of traffic ("incoming" or "outgoing")
--- @param str string The traffic data to log
function LuaSocket.traffic_log(self, type, str)
end

--- Connects the LuaSocket object to the specified address and port.
---
--- @param self table The LuaSocket table
--- @param addr string The address to connect to
--- @param port number The port to connect to
--- @param timeout number The connection timeout in milliseconds
function LuaSocket.connect(self, addr, port, timeout)
end

--- Reads the next available packet from the received data.
---
--- @param self table The LuaSocket table
--- @return string The next packet, or nil if no packet is available
function LuaSocket.readpacket(self)
end

--- Waits for and returns the next available packet.
---
--- @param self table The LuaSocket table
--- @return string The next packet
function LuaSocket.waitpacket(self)
end

--- Updates the LuaSocket object, handling connection state and sending/receiving data.
---
--- @param self table The LuaSocket table
function LuaSocket.update(self)
end

--- Checks if the LuaSocket object is disconnected.
---
--- @param self table The LuaSocket table
--- @return boolean true if the LuaSocket object is disconnected, false otherwise
function LuaSocket.isdisconnected(self)
end

--- Checks if the LuaSocket object is connected.
---
--- @param self table The LuaSocket table
--- @return boolean true if the LuaSocket object is connected, false otherwise
function LuaSocket.isconnected(self)
end

--- Checks if the LuaSocket object is connecting.
---
--- @param self table The LuaSocket table
--- @return boolean true if the LuaSocket object is connecting, false otherwise
function LuaSocket.isconnecting(self)
end

--- Flushes the send buffer, waiting for all data to be sent.
---
--- @param self table The LuaSocket table
function LuaSocket.flush(self)
end

--- Closes the LuaSocket connection.
---
--- @param self table The LuaSocket table
function LuaSocket.close(self)
end

--- Sends raw data through the LuaSocket connection.
---
--- @param self table The LuaSocket table
--- @param ... string The data to send
function LuaSocket.send_raw(self, ...)
end

--- Sends data through the LuaSocket connection with a length prefix.
---
--- @param self table The LuaSocket table
--- @param ... string The data to send
function LuaSocket.send(self, ...)
end
LuaSocket = {new=function(self, obj)
    obj = obj or {}
    setmetatable(obj, self)
    self.__index = self
    obj[true] = false
    obj.state = "noconnection"
    obj.send_buffer = {}
    obj.send_buffer_i = 1
    obj.connect_init_time = 0
    obj.deadline = 0
    obj.timeout = 0
    obj.packets = {}
    obj.queue = {}
    obj.receive_buffer = ""
    obj.received_data = ""
    obj.transactions = {}
    obj.log_enabled = false
    obj.maxbuffer = 0
    return obj
end, OnAccept=function(self, socket, host, port)
end, OnConnect=function(self, err, host, port)
    if err then
        self.state = "UnableToConnect"
    else
        self:__Connected()
    end
    Msg(self, err)
end, OnDisconnect=function(self, reason)
    self.state = "noconnection"
end, OnReceive=function(self, msg)
    local start_size = string.len(self.receive_buffer)
    self:traffic_log("incoming", msg)
    self.receive_buffer = self.receive_buffer .. msg
    if string.len(self.receive_buffer) > start_size then
        while true do
            while string.starts_with(self.receive_buffer, "#") do
                if string.len(self.receive_buffer) > 1 then
                    self.receive_buffer = string.sub(self.receive_buffer, 2) -- ping
                else
                    self.receive_buffer = ""
                end
            end
            local count = string.match(self.receive_buffer, "^(%d+) ")
            if count and string.len(self.receive_buffer) >= tonumber(count) + string.len(count) + 1 then -- whole packet received
                local packet_start = string.len(count) + 2 -- first byte of packet
                local packet_end = packet_start + count - 1 -- last byte of packet

                local packet = string.sub(self.receive_buffer, packet_start, packet_end)
                table.insert(self.packets, packet)
                if string.len(self.receive_buffer) > packet_end then
                    self.receive_buffer = string.sub(self.receive_buffer, packet_end + 1)
                else
                    self.receive_buffer = ""
                end
            else
                assert(self.receive_buffer == "" or string.match(self.receive_buffer, "^%d")
                           or string.starts_with(self.receive_buffer, "#"))
                break
            end
        end
    end
end, traffic_log=function(self, type, str)
    if self.log_enabled then
        local filename = type
        local f, error = io.open(filename .. ".log", "a")
        if f then
            f:write(str)
            f:close()
        else
            OutputDebugString(error)
        end
    end
end, connect=function(self, addr, port, timeout)
    if self[true] then
        self:__CloseConnection()
    else
        self[true] = sockNew()
        SocketObjs[self[true]] = self
    end
    self.timeout = timeout or 5000
    sockSetOption(self, "timeout", 600000)
    self.maxbuffer = sockGetOption(self, "maxbuffer")
    self.state = "waitconnect"
    local err = sockConnect(self, timeout, addr, port)
    self.addr = addr
    self.port = port
    self.deadline = self.timeout + RealTime()
    if not err then
        sockProcess(0)
        if self.state == "UnableToConnect" and RealTime() - self.deadline > 0 then
            self:__CloseConnection()
        end
    else
        if self.state == "UnableToConnect" then
            if RealTime() - self.deadline > 0 then
                self:__CloseConnection()
            end
        else
            self:__CloseConnection()
        end
    end
end, readpacket=function(self)
    local packet = table.remove(self.packets, 1)
    return packet
end, waitpacket=function(self)
    while not self:isdisconnected() do
        local packet = self:readpacket()
        if packet then
            return packet
        end
        self:update()
        os.sleep(10)
    end
end, update=function(self)
    if not self[true] then
        return
    end

    sockProcess(0)

    if self.state == "UnableToConnect" then
        if RealTime() - self.deadline > 0 then
            self:__CloseConnection()
            return
        else
            LuaSocket.connect(self, self.addr, self.port, self.deadline - RealTime())
        end
    end

    if self.state == "connected" then
        local send_buffer_i = self.send_buffer_i
        local send_buffer = self.send_buffer or {}

        while send_buffer[1] and send_buffer == self.send_buffer do
            if send_buffer_i == 1 then
                while #send_buffer > 1 and #send_buffer[1] + #send_buffer[2] < 2048 do -- concatinate some buffers to form larger piece to minimize the "send" operations
                    local buff = send_buffer[1] .. send_buffer[2]
                    assert(buff)
                    send_buffer[1] = buff
                    table.remove(send_buffer, 2)
                end
            end

            local err, last_i
            if #send_buffer[1] < self.maxbuffer then
                err = sockSend(self, send_buffer[1])
                last_i = #send_buffer[1]
            else
                local bytes = #send_buffer[1] - (send_buffer_i - 1)
                if bytes > self.maxbuffer then
                    bytes = self.maxbuffer
                end
                err = sockSend(self, string.sub(send_buffer[1], send_buffer_i, ((send_buffer_i - 1) + bytes)))
                last_i = (send_buffer_i - 1) + bytes
            end
            if err and err ~= "no data" then
                self:__CloseConnection()
                return
            end
            if last_i then
                self:traffic_log("outgoing", string.sub(send_buffer[1], send_buffer_i, last_i))
                send_buffer_i = last_i + 1
                if send_buffer_i > #send_buffer[1] then
                    send_buffer_i = 1
                    table.remove(send_buffer, 1)
                end
                self.send_buffer_i = send_buffer_i
            end
        end
        -- Old Recv was here
    end
end, isdisconnected=function(self)
    return self.state == "noconnection"
end, isconnected=function(self)
    return self.state == "connected"
end, isconnecting=function(self)
    return self.state == "waitconnect"
end, flush=function(self)
    if not self[true] then
        return
    end
    self:update()
    while not self:isdisconnected() and #self.send_buffer > 0 do
        os.sleep(10)
        self:update()
    end
end, close=function(self)
    self:__CloseConnection()
end, __CloseConnection=function(self)
    self.state = "noconnection"

    self.send_buffer_i = 1
    self.send_buffer = {}
    self.receive_buffer = ""
    self.received_data = ""

    if self[true] then
        sockDisconnect(self)
    end
end, __Connected=function(self)
    self.state = "connected"
    if self.log_enabled then
        local f, error = io.open("outgoing.log", "w+")
        if f then
            f:close()
        else
            OutputDebugString(error)
        end
        local f, error = io.open("incoming.log", "w+")
        if f then
            f:close()
        else
            OutputDebugString(error)
        end
        local f, error = io.open("input.log", "w+")
        if f then
            f:close()
        else
            OutputDebugString(error)
        end
    end
end, send_raw=function(self, ...)
    local args = {...}
    for i = 1, #args do
        table.insert(self.send_buffer, args[i])
        self:traffic_log("input", args[i])
    end
end, send=function(self, ...)
    local len = 0
    local args = {...}
    for i = 1, #args do
        len = len + #args[i]
    end
    table.insert(self.send_buffer, "$" .. len .. "&")
    self:send_raw(...)
end}
