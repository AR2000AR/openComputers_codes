local class = require("libClass2")
local TCPSegment = require("network.tcp.TCPSegment")
local network = require("network")
local ipv4Address = require("network.ipv4.address")
local os = require("os")

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
---@field private _buffer table<string>
---@field private _timeout number
---@field private _kind TCPSocketKind
---@field private _state TCPSocketState
---@field private _backlogLen number size of a LISTEN socket connexion backlog
---@field private _backlog table
---@field private _seq number current seq number
---@field private _ack number last ack value
---@operator call:TCPSocket
---@overload fun(self):TCPSocket
local TCPSocket = class()

---@return TCPSocket
function TCPSocket:new()
    local o = self.parent()
    setmetatable(o, {__index = self})
    ---@cast o TCPSocket
    o._sockname   = {"0.0.0.0", 0}
    o._peername   = {"0.0.0.0", 0}
    o._backlog    = {}
    o._backlogLen = 0
    o._buffer     = {}
    o._timeout    = 0
    o._kind       = "master"
    o._state      = "CLOSED"
    o._seq        = math.random(0x7fff)
    return o
end

---@protected
function TCPSocket:_makeSegment()
    local _, srcPort = self:getsockname()
    local _, dstPort = self:getpeername()
    local seg = TCPSegment(srcPort, dstPort, "")
    seg:seq(self._seq)
    seg:ack(self._ack)
    return seg
end

---@protected
---@param data string
---@return TCPSegment
function TCPSocket:_makeDataSegment(data)
    local seg = self:_makeSegment()
    seg:payload(data)
    seg:flag(f.PSH, true)
    seg:seq(self._seq)
    return seg
end

---@protected
---@param seg TCPSegment
---@param received TCPSegment
function TCPSocket:_setAck(seg, received)
    seg:ack(received:seq() + 1)
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
    --TODO handle timeout
    while (#self._backlog == 0) do os.sleep() end
    local waitingClient = table.remove(self._backlog, 1)
    local client = TCPSocket()
    client._sockname = self._sockname
    client._peername = {ipv4Address.tostring(waitingClient[1]), waitingClient[3]:srcPort()}
    client._state = "SYN-RECEIVED"
    client._kind = "client"
    local seg = client:_makeAck(waitingClient[3])
    seg:flag(f.SYN, true)
    client:sendRaw(seg)
    client._seq = client._seq + 1
    network.tcp.getInterface():addSocket(client)
    return client
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
    --TODO : convert hostname
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
        self._seq = self._seq + 1
        self._state = "FIN-WAIT-1"
    else
        self._state = "CLOSED"
        network.tcp.getInterface():close(self)
    end
end

function TCPSocket:connect(address, port)
    checkArg(1, address, "string")
    checkArg(2, port, "number")
    if (not self._kind == "master") then return nil, "not a master socket" end
    self._kind = "client"
    self:bind("*", 0)
    network.tcp.getInterface():close(self) --hack to delete the socket before we change it's peername
    --TODO resolve address
    self._peername = {address, port}
    network.tcp.getInterface():addSocket(self)
    address = ipv4Address.fromString(address)
    local seg = self:_makeSegment()
    seg:flags(f.SYN)
    self:sendRaw(seg)
    self._state = "SYN-SENT"
    --TODO timeout
    while self._state == "SYN-SENT" do
        os.sleep()
    end
    if (self._state == "ESTABLISHED") then return 1 else return nil, "Connection failed" end
end

function TCPSocket:dirty()
    return #self._buffer > 0
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

function TCPSocket:receive()
    --TODO write body for recei
end

---@param data string
function TCPSocket:send(data)
    self:sendRaw(self:_makeDataSegment(data))
end

---@protected
---@param seg TCPSegment
function TCPSocket:sendRaw(seg)
    --TODO buffer outgoing
    local from = ipv4Address.fromString(self:getsockname())
    local to = ipv4Address.fromString(self:getpeername())
    --seg:windowSize(math.max(seg:windowSize(), network.tcp.getInterface():mtu()))
    network.tcp.getInterface():send(from, to, seg)
    self._seq = self._seq + #(seg:payload())
end

function TCPSocket:setfd()
    error("NOT IMPLEMENTED", 2)
end

function TCPSocket:setoption()
    --TODO write body for setop
    error("NOT IMPLEMENTED", 2)
end

function TCPSocket:setstats()
    error("NOT IMPLEMENTED", 2)
end

---Set the socket's timeout in second
---@param value number seconds
function TCPSocket:settimeout(value)
    checkArg(1, value, 'number')
    self._timeout = value * 100
end

function TCPSocket:shutdown()
    --TODO write body for shutd
end

---Handle the payload recived by UDPLayer
---@package
---@param from number
---@param to number
---@param tcpSegment TCPSegment
function TCPSocket:payloadHandler(from, to, tcpSegment)
    --TODO send ack
    if (tcpSegment:flag(f.RST)) then
        self._state = "CLOSED"
        network.tcp.getInterface():close(self)
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
            self._seq = self._seq + 1
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
            self._seq = self._seq + 1
        end
        --TODO send ack
        --TODO push event on PSH
        table.insert(self._buffer, tcpSegment:payload())
    end
end

---Create and return a new unconnected TCP socket
local function tcp()
    return TCPSocket()
end

return tcp
