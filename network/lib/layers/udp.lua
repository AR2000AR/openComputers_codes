local IPv4Packet = require("layers.ipv4").IPv4Packet

---@class udpLib
local udp = {}

--#region UDPPacket

---@class UDPPacket : Payload
---@field private _srcPort number
---@field private _dstPort number
---@field private _payload string
---@operator call:UDPPacket
---@overload fun(srcPort:number,dstPort:number,payload:string):UDPPacket
local UDPPacket = {}
UDPPacket.payloadType = require("layers.ipv4").PROTOCOLS.UDP

---@return UDPPacket
setmetatable(UDPPacket, {
    ---@param self UDPPacket
    ---@param srcPort number
    ---@param dstPort number
    ---@param payload string
    ---@return table
    __call = function(self, srcPort, dstPort, payload)
        checkArg(1, srcPort, "number")
        checkArg(2, dstPort, "number")
        checkArg(3, payload, "string")
        local o = {
            _scrPort = 0,
            _dstPort = 0,
            _payload = ""
        }
        setmetatable(o, {__index = self})

        o:setDstPort(dstPort)
        o:setSrcPort(srcPort)
        o:setPayload(payload)

        return o
    end
})

function UDPPacket:getDstPort() return self._dstPort end

function UDPPacket:getSrcPort() return self._srcPort end

function UDPPacket:getPayload() return self._payload end

function UDPPacket:setDstPort(port)
    checkArg(1, port, "number")
    assert(port >= 0 and port <= 2 ^ 16 - 1, "Port outside valid range")
    self._dstPort = port
end

function UDPPacket:setSrcPort(port)
    checkArg(1, port, "number")
    assert(port >= 0 and port <= 2 ^ 16 - 1, "Port outside valid range")
    self._srcPort = port
end

function UDPPacket:setPayload(value)
    checkArg(1, value, "string")
    self._payload = value
end

---Prepare the packet for the next layer
---@return string
function UDPPacket:pack()
    return string.format("%.4x%.4x%s", self:getSrcPort(), self:getDstPort(), self:getPayload())
end

---Get a udp packet from the string
---@param value string
---@return UDPPacket
function UDPPacket.unpack(value)
    local o = "%x%x"
    local src, dst, payload = value:match(string.format("(%s)(%s)(%s)", o:rep(2), o:rep(2), ".*"))
    src = tonumber(src, 16)
    dst = tonumber(dst, 16)
    return UDPPacket(src, dst, payload)
end

--#endregion
--=============================================================================

--#region UDP socket

---@class UDPSocket
---@field package _lPort number
---@field package _rAddresse number
---@field package _rPort number
---@field private _buffer table<UDPPacket>
---@field private _layer UDPLayer
---@operator call:UDPSocket
---@overload fun(layer:UDPLayer,localPort:number):UDPSocket
---@overload fun(layer:UDPLayer,localPort:number,remoteAddress:number,remotePort:number):UDPSocket
local UDPSocket = {}

---@return UDPSocket
setmetatable(UDPSocket, {
    __call = function(self, layer, localPort, remoteAddress, remotePort)
        checkArg(1, layer, "table")
        checkArg(2, localPort, "number")
        checkArg(3, remoteAddress, "number", "nil")
        checkArg(4, remotePort, "number", "nil")
        local o = {
            _lPort = localPort,
            _rAddresse = remoteAddress or 0,
            _rPort = remotePort or 0,
            _buffer = {},
            _layer = layer
        }
        setmetatable(o, {__index = self})
        return o
    end
})

---Recive one packet
---@return UDPPacket?
---@nodiscard
function UDPSocket:recive()
    return table.remove(self._buffer, 1)
end

---Recive one payload
---@return string?
---@nodiscard
function UDPSocket:reciveString()
    local packet = self:recive()
    if (packet) then
        return packet:getPayload()
    end
end

---Send a udpPacket or string.
---A string can only be sent if the socket's remote address and port are set
---@param payload UDPPacket|string
---@return boolean packetSent
function UDPSocket:send(payload)
    if (type(payload) == "string") then
        ---@cast payload  string
        if (self._rAddresse == 0 or self._rPort == 0) then return false end
        self._layer:send(self._rAddresse, UDPPacket(self._lPort, self._rPort, payload))
        return true
    else
        ---@cast payload UDPPacket
        self._layer:send(self._rAddresse, payload)
        return true
    end
end

---Handle the payload recived by UDPLayer
---@package
---@param udpPacket UDPPacket
function UDPSocket:payloadHandler(udpPacket)
    table.insert(self._buffer, udpPacket)
end

---close the socket
function UDPSocket:close()
    self._layer:close(self)
end

---Check if the socket is still open
---@return boolean
function UDPSocket:isOpen()
    return self._layer:isOpen(self)
end

function UDPSocket:getLocalPort()
    return self._lPort
end

function UDPSocket:getRemotePort()
    return self._rPort
end

--#endregion
--=============================================================================

--#region UPD layer

---@class UDPLayer : OSILayer
---@field private _sockets table<number,UDPSocket>
---@field private _layer IPv4Layer
---@operator call:UDPLayer
---@overload fun(layer:IPv4Layer):UDPLayer
local UDPLayer = {}
UDPLayer.layerType = require("layers.ipv4").PROTOCOLS.UDP

---@return UDPLayer
setmetatable(UDPLayer, {
    ---@param layer IPv4Layer
    ---@return UDPLayer
    __call = function(self, layer)
        local o = {
            _sockets = {},
            _layer = layer
        }
        setmetatable(o, {__index = self})
        layer:setLayer(o) --tell the IPv4Layer that we exists
        return o
    end
})

function UDPLayer:payloadHandler(from, to, payload)
    local udpPacket = UDPPacket.unpack(payload)
    if (not self._sockets[udpPacket:getDstPort()]) then return end
    self._sockets[udpPacket:getDstPort()]:payloadHandler(udpPacket)
end

---Open a new UDP socket.
---@param port? number
---@param remoteAd? number
---@param remotePort? number
---@return UDPSocket? socket, string? reason
function UDPLayer:open(port, remoteAd, remotePort)
    --#region checkArg
    checkArg(1, port, "number", "nil")
    if (port) then
        checkArg(2, remoteAd, "number", "nil")
        if (remoteAd) then
            checkArg(3, remotePort, "number")
        else
            checkArg(3, remotePort, "number", "nil")
        end
    else
        checkArg(2, remoteAd, "nil")
        checkArg(3, remotePort, "nil")
    end
    --#endregion
    if (port == nil) then
        repeat
            port = math.random(1025, (2 ^ 16) - 1)
        until not self._sockets[port]
    end
    if (self._sockets[port]) then return nil, "port already used" end
    local socket = UDPSocket(self, port, remoteAd, remotePort)
    self._sockets[port] = socket
    return socket
end

---@package
---@param socket UDPSocket
function UDPLayer:close(socket)
    self._sockets[socket._lPort] = nil
end

---Check if the given socket is open on this layer
---@param socket UDPSocket
---@return boolean
function UDPLayer:isOpen(socket)
    if (self._sockets[socket._lPort]) then return true else return false end
end

---Send a udp paylaod
---@param to number
---@param payload UDPPacket
function UDPLayer:send(to, payload)
    self._layer:send(IPv4Packet(self._layer:getAddr(), to, payload))
end

function UDPLayer:getAddr() return self._layer:getAddr() end

function UDPLayer:getMTU() return self._layer:getMTU() - 8 end

--#endregion

udp.UDPLayer = UDPLayer
udp.UDPPacket = UDPPacket
udp.UDPSocket = UDPSocket
return udp
