local class       = require("libClass2")
local TCPSegment  = require("network.tcp.TCPSegment")
local network     = require("network")
local ipv4Address = require("network.ipv4.address")
local utils       = require("network.utils")
local os          = require("os")


local f = TCPSegment.Flags

---@alias TCPSocketState
--- | "LISTEN"	     Waiting for a connection request from a remote TCP application. This is the state in which you can find the listening socket of a local TCP server.
--- | "SYN-SENT"	 Waiting for an acknowledgment from the remote endpoint after having sent a connection request. Results after step 1 of the three-way TCP handshake.
--- | "SYN-RECEIVED" This endpoint has received a connection request and sent an acknowledgment. This endpoint is waiting for final acknowledgment that the other endpoint did receive this endpoint's acknowledgment of the original connection request. Results after step 2 of the three-way TCP handshake.
--- | "ESTABLISHED"	 Represents a fully established connection; this is the normal state for the data transfer phase of the connection.
--- | "FIN-WAIT-1"	 Waiting for an acknowledgment of the connection termination request or for a simultaneous connection termination request from the remote TCP. This state is normally of short duration.
--- | "FIN-WAIT-2"	 Waiting for a connection termination request from the remote TCP after this endpoint has sent its connection termination request. This state is normally of short duration, but if the remote socket endpoint does not close its socket shortly after it has received information that this socket endpoint closed the connection, then it might last for some time. Excessive FIN-WAIT-2 states can indicate an error in the coding of the remote application.
--- | "CLOSE-WAIT"	 This endpoint has received a close request from the remote endpoint and this TCP is now waiting for a connection termination request from the local application.
--- | "CLOSING"  	 Waiting for a connection termination request acknowledgment from the remote TCP. This state is entered when this endpoint receives a close request from the local application, sends a termination request to the remote endpoint, and receives a termination request before it receives the acknowledgment from the remote endpoint.
--- | "LAST-ACK"	 Waiting for an acknowledgment of the connection termination request previously sent to the remote TCP. This state is entered when this endpoint received a termination request before it sent its termination request.
--- | "TIME-WAIT"	 Waiting for enough time to pass to be sure the remote TCP received the acknowledgment of its connection termination request.
--- | "CLOSED"	     Represents no connection state at all.

---@alias TCPSocketKind
--- | "master"
--- | "client"
--- | "server"

---@alias TCPSocketOption
--- | 'keepalive'   Setting this option to true enables the periodic transmission of messages on a connected socket. Should the connected party fail to respond to these messages, the connection is considered broken and processes using the socket are notified;
--- | 'linger'      Controls the action taken when unsent data are queued on a socket and a close is performed. The value is a table with a boolean entry 'on' and a numeric entry for the time interval 'timeout' in seconds. If the 'on' field is set to true, the system will block the process on the close attempt until it is able to transmit the data or until 'timeout' has passed. If 'on' is false and a close is issued, the system will process the close in a manner that allows the process to continue as quickly as possible. I do not advise you to set this to anything other than zero;
--- | 'reuseaddr'   Setting this option indicates that the rules used in validating addresses supplied in a call to bind should allow reuse of local addresses;
--- | 'tcp-nodelay' Setting this option to true disables the Nagle's algorithm for the connection;

---@class TCPSocket:Object
---@operator call:TCPSocket
---@field private _sockname table
---@field private _peername table
---@field private _buffer Buffer
---@field private _timeout number
---@field private _timeoutMode "b"|"t"
---@field private _kind TCPSocketKind
---@field private _state TCPSocketState
---@field private _backlogLen number size of a LISTEN socket connexion backlog
---@field private _backlog table
---@field private _outBuffer table
---@field private _sndUna number send unacknowledged
---@field private _sndNxt number send next
---@field private _sndWnd number send window
---@field private _sndUp number send urgent pointer
---@field private _sndWl1 number segment sequence number used for last winow update
---@field private _sndWl2 number send acknowledgment number used for last window update
---@field private _IIS number iniital send sequence number
---@field private _rcvNxt number receive next
---@field private _rcvWnd number receive window
---@field private _rcvUp number recive urgent pointer
---@field private _IRS number initial recieve sequence number
---@field private _mss number Maximum Segment Size
---@operator call:TCPSocket
---@overload fun(self):TCPSocket
local TCPSocket = class()

---@return TCPSocket
function TCPSocket:new()
    local o = self.parent()
    setmetatable(o, {__index = self})
    ---@cast o TCPSocket
    o._sockname    = {"0.0.0.0", 0}
    o._peername    = {"0.0.0.0", 0}
    o._backlog     = {}
    o._backlogLen  = 0
    o._buffer      = utils.Buffer()
    o._outBuffer   = {}
    o._timeout     = -1
    o._timeoutMode = "b"
    o._kind        = "master"
    o._state       = "CLOSED"
    --TODO : https://datatracker.ietf.org/doc/html/rfc9293#section-3.4.1
    o._ISS         = math.random(0xffffffff)
    o._sndNxt      = o._ISS
    o._sndUna      = o._ISS
    o._rcvNxt      = -1
    o._rcvUp       = -1
    o._rcvWnd      = -1
    o._sndWnd      = 8000
    o._mss         = 536
    return o
end

---@package
---@param value? number
---@return number
function TCPSocket:mss(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self._mss
    if (value ~= nil) then self._mss = value end
    return oldValue
end

---@protected
function TCPSocket:_makeSegment()
    local _, srcPort = self:getsockname()
    local _, dstPort = self:getpeername()
    local seg = TCPSegment(srcPort, dstPort, "")
    seg:seq(self._sndNxt)
    seg:windowSize(self:mss())
    if (self._state == "ESTABLISHED") then
        seg:ack(self._rcvNxt)
        seg:flag(f.ACK, true)
    end
    return seg
end

---@protected
---@param data string
---@return TCPSegment
function TCPSocket:_makeDataSegment(data)
    local seg = self:_makeSegment()
    seg:payload(data)
    seg:flag(f.PSH, true)
    seg:seq(self._sndNxt)
    seg:ack(self._rcvNxt)
    return seg
end

---@protected
---@param seg TCPSegment
---@param received TCPSegment
function TCPSocket:_setAck(seg, received)
    seg:ack(received:seq() + math.max(1, #(received:payload())))
    self._rcvNxt = seg:ack()
    seg:flag(f.ACK, true)
    return seg
end

---@protected
---@param received TCPSegment
---@return TCPSegment
function TCPSocket:_makeAck(received)
    return self:_setAck(self:_makeSegment(), received)
end

---Waits for a remote connection on the server object and returns a client object representing that connection.\
---If a connection is successfully initiated, a client object is returned. If a timeout condition is met, the method returns nil followed by the error string 'timeout'. Other errors are reported by nil followed by a message describing the error.
---@return TCPSocket|nil client
---@return string|nil reason
function TCPSocket:accept()
    if (not self._kind == "server") then return nil, "not a server socket" end
    if (not self._state == "LISTEN") then return nil, "not a listening socket" end
    local t1 = os.time() --[[@as number]]
    while (#(self._backlog) == 0) and not self:_hasTimedOut(t1) do os.sleep() end
    if (#(self._backlog) == 0) then return nil, 'timeout' end
    local client = TCPSocket()
    local from, to, seg = table.unpack(table.remove(self._backlog, 1))
    client:_doAccept(from, {ipv4Address.tostring(to), seg:dstPort()}, seg)
    while client:getState() == "SYN-RECEIVED" and not self:_hasTimedOut(t1) do os.sleep() end
    if (client:getState() == "ESTABLISHED") then
        return client
    else
        return nil, "timeout"
    end
end

---@package
---@param from number
---@param to table
---@param seg TCPSegment
function TCPSocket:_doAccept(from, to, seg)
    self._peername = {ipv4Address.tostring(from), seg:srcPort()}
    self._sockname = to
    self._state = "SYN-RECEIVED"
    self._kind = "client"
    self._remoteWindowSize = seg:windowSize()
    self._IRS = seg:seq()
    local ackseg = self:_makeAck(seg)
    ackseg:flag(f.SYN, true)
    self:sendRaw(ackseg)
    network.tcp.getInterface():addSocket(self)
end

---@package
---@param address string
---@param port number
function TCPSocket:_setsockname(address, port)
    self._sockname = {address, port}
end

function TCPSocket:getState()
    return self._state
end

---Binds a master object to address and port on the local host.\
---Address can be an IP address or a host name. Port must be an integer number in the range [0..64K). If address is '*', the system binds to all local interfaces using the INADDR_ANY constant or IN6ADDR_ANY_INIT, according to the family. If port is 0, the system automatically chooses an ephemeral port.\
---In case of success, the method returns 1. In case of error, the method returns nil followed by an error message.
---@param address string
---@param port number
---@return number|nil success, string|nil reason
function TCPSocket:bind(address, port)
    checkArg(1, address, "string")
    checkArg(2, port, "number")
    assert(port <= 0xffff and port >= 0)
    if (not self._kind == "master") then return nil, "Not a master socket" end
    if (address == '*') then address = "0.0.0.0" end
    local s, r = network.tcp.getInterface():bindSocket(self, ipv4Address.fromString(address), port)
    if (s) then
        self._sockname = {address, s}
        return 1
    else
        return s, r
    end
end

function TCPSocket:close()
    if (self._kind == "client") then
        local seg = self:_makeSegment()
        seg:flag(f.FIN, true)
        seg:flag(f.ACK, true)
        self:sendRaw(seg)
        self._state = "FIN-WAIT-1"
    else
        self._state = "CLOSED"
        network.tcp.getInterface():close(self)
    end
end

---@param address string
---@param port number
function TCPSocket:connect(address, port)
    checkArg(1, address, "string")
    checkArg(2, port, "number")
    if (not self._kind == "master") then return nil, "not a master socket" end

    self._kind = "client"

    local addressNum = ipv4Address.fromString(address)
    local s, r = network.tcp.getInterface():connectSocket(self, addressNum, port)
    if (s == nil) then return nil, r end
    self._peername = {address, port}

    local seg = self:_makeSegment()
    seg:flags(f.SYN)
    self:sendRaw(seg)
    self._state = "SYN-SENT"
    local t1 = os.time() --[[@as number]]
    while self._state == "SYN-SENT" and not self:_hasTimedOut(t1) do
        os.sleep()
    end
    if (self._state == "ESTABLISHED") then return 1 else return nil, "Connection failed" end
end

function TCPSocket:dirty()
    return self._buffer:len() > 0
end

function TCPSocket:getfd()
    error("NOT IMPLEMENTED", 2)
end

function TCPSocket:getoption()
    error("NOT IMPLEMENTED", 2)
end

---Returns information about the remote side of a connected client object.\
---Returns a string with the IP address of the peer, the port number that peer is using for the connection, and a string with the family ("inet" or "inet6"). In case of error, the method returns nil.\
---Note: It makes no sense to call this method on server objects.
---@return string address,number port
function TCPSocket:getpeername()
    return table.unpack(self._peername)
end

---Returns the local address information associated to the object.\
---The method returns a string with local IP address, a number with the local port, and a string with the family ("inet" or "inet6"). In case of error, the method returns nil.
---@return string address,number port
function TCPSocket:getsockname()
    return table.unpack(self._sockname)
end

function TCPSocket:getstats()
    error("NOT IMPLEMENTED", 2)
end

function TCPSocket:gettimeout()
    return self._timeout
end

---@param backlog number
---@return number? status, string? reason
function TCPSocket:listen(backlog)
    checkArg(1, backlog, "number")
    if (not self._kind == "master") then return nil, "Not a master socket" end
    --TODO make sure socket is bound
    self._kind = "server"
    self._state = "LISTEN"
    self._backlogLen = backlog
    return 1
end

---Reads data from a client object, according to the specified read pattern. Patterns follow the Lua file I/O format, and the difference in performance between all patterns is negligible.\
---
---Pattern can be any of the following:
---- '*a': reads from the socket until the connection is closed. No end-of-line translation is performed;
---- '*l': reads a line of text from the socket. The line is terminated by a LF character (ASCII 10), optionally preceded by a CR character (ASCII 13). The CR and LF characters are not included in the returned line. In fact, all CR characters are ignored by the pattern. This is the default pattern;
---- number: causes the method to read a specified number of bytes from the socket.
---
---Prefix is an optional string to be concatenated to the beginning of any received data before return.\
---
---If successful, the method returns the received pattern. In case of error, the method returns nil followed by an error message, followed by a (possibly empty) string containing the partial that was received. The error message can be the string 'closed' in case the connection was closed before the transmission was completed or the string 'timeout' in case there was a timeout during the operation.
---@param pattern? string
---@param prefix? string
---@return string? data, string?reason
function TCPSocket:receive(pattern, prefix)
    checkArg(1, pattern, "string", 'number', "nil")
    if (not pattern) then pattern = "*a" end
    checkArg(2, prefix, "string", "nil")
    local t1 = os.time() --[[@as number]]
    local data
    repeat
        data = self._buffer:read(pattern)
    until data ~= nil or self:_hasTimedOut(t1)
    if (not data) then
        return nil, self:_hasTimedOut(t1) and "timeout" or ""
    end
    return (prefix or "") .. data
end

---@param data string
function TCPSocket:send(data)
    --TODO : https://datatracker.ietf.org/doc/html/rfc896
    self:sendRaw(self:_makeDataSegment(data))
end

---@protected
---@param seg TCPSegment
function TCPSocket:sendRaw(seg)
    --TODO buffer outgoing
    local from = ipv4Address.fromString(self:getsockname())
    local to = ipv4Address.fromString(self:getpeername())
    self._outBuffer[seg:seq()] = seg
    network.tcp.getInterface():send(from, to, seg)
    self._sndNxt = self._sndNxt + seg:len()
end

function TCPSocket:setoption()
    --TODO write body for setop
    error("NOT IMPLEMENTED", 2)
end

function TCPSocket:setstats()
    error("NOT IMPLEMENTED", 2)
end

---@param time number
---@return boolean
function TCPSocket:_hasTimedOut(time)
    checkArg(1, time, "number")
    if (self._timeout and self._timeout < 0) then return false end
    return os.time() - time > self._timeout
end

---Changes the timeout values for the object. By default, all I/O operations are blocking. That is, any call to the methods receive, and accept will block indefinitely, until the operation completes. The settimeout method defines a limit on the amount of time the I/O methods can block. When a timeout is set and the specified amount of time has elapsed, the affected methods give up and fail with an error code.
---
---The amount of time to wait is specified as the value parameter, in seconds. There are two timeout modes and both can be used together for fine tuning:
---- 'b': block timeout. Specifies the upper limit on the amount of time LuaSocket can be blocked by the operating system while waiting for completion of any single I/O operation. This is the default mode;
---- 't': total timeout. Specifies the upper limit on the amount of time LuaSocket can block a Lua script before returning from a call.
---
---The nil timeout value allows operations to block indefinitely. Negative timeout values have the same effect.
---@param value number seconds
---@param mode "b"|"t"
function TCPSocket:settimeout(value, mode)
    checkArg(1, value, 'number')
    self._timeout = value * 100
end

---@param mode "both"
function TCPSocket:shutdown(mode)
    if (mode ~= "both") then error("Only shutdown both is supported", 2) end
    self:close()
    return 1
end

---Handle the payload recived by UDPLayer
---@package
---@param from number
---@param to number
---@param tcpSegment TCPSegment
function TCPSocket:payloadHandler(from, to, tcpSegment)
    --TODO : https://datatracker.ietf.org/doc/html/rfc9293#name-reset-generation
    if (tcpSegment:flag(f.RST) and self._state ~= "LISTEN") then
        if (self._state == "SYN-SENT") then
            if (self._sndUna == tcpSegment:ack()) then
                self._state = "CLOSED"
                network.tcp.getInterface():close(self)
                return
            end
        else
            --TODO check seq in window
            self._state = "CLOSED"
            network.tcp.getInterface():close(self)
            return
        end
    end
    self._rcvWnd = tcpSegment:windowSize()
    if (self._state == "ESTABLISHED" or self._state == "FIN-WAIT-1" or self._state == "FIN-WAIT-2" or self._state == "CLOSE-WAIT" or self._state == "CLOSING" or self._state == "TIME-WAIT") then
        --must process URG
        if (tcpSegment:len() > 0 and tcpSegment:flag(f.URG) == false) then
            if (self._rcvWnd == 0) then
                require("event").onError("0 window")
                return
            end
            if (self._rcvWnd > 0) then
                local c1 = (self._rcvNxt <= tcpSegment:seq()) and (tcpSegment:seq() < (self._rcvNxt + self._rcvWnd))
                local c2 = (self._rcvNxt <= (tcpSegment:seq() + tcpSegment:len() - 1)) and ((tcpSegment:seq() + tcpSegment:len() - 1) < (self._rcvNxt + self._rcvWnd))
                if (not (c1 or c2)) then
                    require("event").onError("window error")
                    return
                end
            end
        end
    end
    if (tcpSegment:flag(f.ACK)) then
        if (self._sndUna < tcpSegment:ack() and tcpSegment:ack() <= self._sndNxt) then
            self._sndUna = tcpSegment:ack()
            local acked = {}
            local ack = tcpSegment:ack()
            for i, s in pairs(self._outBuffer) do if (s:seq() + s:len() <= ack) then table.insert(acked, i) end end
            for _, i in pairs(acked) do self._outBuffer[i] = nil end
        else
            require("event").onError("Invalid ack")
            --TODO log error
        end
    end
    if (tcpSegment:offset() > 5) then
        self:handleOptions(tcpSegment)
    end
    if (self._state == "LISTEN") then
        if (tcpSegment:flag(f.SYN)) then
            if (#(self._backlog) < self._backlogLen) then
                table.insert(self._backlog, {from, to, tcpSegment})
            else
                local _, port = self:getsockname()
                local seg = self:_makeAck(tcpSegment)
                seg:flag(f.RST|f.ACK)
                network.tcp.getInterface():send(to, from, seg)
                return
            end
        end
    elseif (self._state == "SYN-SENT") then
        if (tcpSegment:flag(f.RST)) then
            --TODO error
            self._state = "CLOSED"
        elseif (tcpSegment:flag(f.SYN) and tcpSegment:flag(f.ACK)) then
            local seg = self:_makeAck(tcpSegment)
            self:sendRaw(seg)
            self._state = "ESTABLISHED"
        end
    elseif (self._state == "SYN-RECEIVED") then
        if (tcpSegment:flag(f.ACK)) then
            self._state = "ESTABLISHED"
        end
    elseif (self._state == "FIN-WAIT-1") then
        if (tcpSegment:flag(f.ACK)) then
            self._state = "FIN-WAIT-2"
        end
    elseif (self._state == "FIN-WAIT-2") then
        if (tcpSegment:flag(f.FIN)) then
            self._state = "TIME-WAIT"
            self:sendRaw(self:_makeAck(tcpSegment))
            --TODO delay then closed
        end
    elseif (self._state == "LAST-ACK") then
        if (tcpSegment:flag(f.ACK)) then
            self._state = "CLOSED"
            network.tcp.getInterface():close(self)
        end
    elseif (self._state == "ESTABLISHED") then
        if (tcpSegment:flag(f.FIN)) then
            self._state = "CLOSE-WAIT"
            local seg = self:_makeAck(tcpSegment)
            self:sendRaw(seg)
            self._state = "LAST-ACK"
            seg = self:_makeSegment()
            seg:flag(f.FIN, true)
            seg:flag(f.ACK, true)
            self:sendRaw(seg)
            return
        end
        if (tcpSegment:len() > 0) then
            --TODO check ordering and duplication
            self._buffer:insert(tcpSegment:payload())
            self:sendRaw(self:_makeAck(tcpSegment))
        end
    end
end

---@param seg TCPSegment
function TCPSocket:handleOptions(seg)
    --TODO : move parsing to TCPSegment
    local optionRaw = seg:options()
    local offset = 0
    local kind, data
    while true do
        kind, offset = string.unpack(">B", optionRaw, offset)
        if (kind == 0) then
            break               --End of Option List
        elseif (kind == 1) then --NO-operation
        elseif (kind == 2) then -- Maximum segment size
            data, offset = string.unpack(">xI", optionRaw, offset)
            self:mss(math.min(self:mss(), data))
        end
    end
end

return TCPSocket
