--local UDPSocket   = require("network.udp.UDPSocket")
local UDPDatagram = require("network.udp.UDPDatagram")
local IPv4Packet  = require("network.ipv4.IPv4Packet")
local ipv4Address = require("network.ipv4.address")
local network     = require("network")


---@class UDPLayer : OSITransportLayer
---@field private _sockets table<number,table<number,table<number,table<number,UDPSocket>>>>
---@field private _layer OSINetworkLayer
---@operator call:UDPLayer
---@overload fun(layer:IPv4Layer):UDPLayer
local UDPLayer = {}
UDPLayer.layerType = require("network.ipv4").PROTOCOLS.UDP

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
    local udpPacket = UDPDatagram.unpack(payload)
    local socket = self:getSocket(to, udpPacket:getDstPort(), from, udpPacket:getSrcPort())
    if (not socket) then
        return
    end
    assert(socket)
    socket:payloadHandler(from, to, udpPacket)
end

--#region
-- ---Open a new UDP socket.
-- ---@param address number
-- ---@param port number
-- ---@param remoteAddress number
-- ---@param remotePort number
-- ---@overload fun(self:UDPLayer):UDPSocket
-- ---@overload fun(self:UDPLayer,address:number):UDPSocket
-- ---@overload fun(self:UDPLayer,address:nil,port:number):UDPSocket?, string?
-- ---@overload fun(self:UDPLayer,address:number,port:number):UDPSocket?, string?
-- ---@overload fun(self:UDPLayer,address:nil,port:nil,remoteAddress:number,remotePort:number):UDPSocket
-- ---@overload fun(self:UDPLayer,address:number,port:nil,remoteAddress:number,remotePort:number):UDPSocket
-- ---@return UDPSocket? socket, string? reason
-- function UDPLayer:open(address, port, remoteAddress, remotePort)
--     --#region checkArg
--     if (remoteAddress) then
--         checkArg(3, remoteAddress, 'number')
--         checkArg(4, remotePort, 'number')
--     else
--         checkArg(3, remoteAddress, 'nil')
--         checkArg(4, remotePort, 'nil')
--     end
--     --[[Truth table
--     address         0   1    1    0    1    0    1   0
--     port            0   1    0    1    1    0    0   1
--     remoteAddres    0   1    0    0    0    1    1   1
--     remotePort        0   1    0    0    0    1    1   1
--                     0   15    1    2    3    12    13   14
--                     ]]
--     local validTypes = {[0] = true,[15] = true,[1] = true,[2] = true,[3] = true,[12] = true,[13] = true,[14] = true}
--     local currentTypes = 0
--     if (address) then currentTypes = currentTypes + 1 end
--     if (port) then currentTypes = currentTypes + 2 end
--     if (remoteAddress) then currentTypes = currentTypes + 4 end
--     if (remotePort) then currentTypes = currentTypes + 8 end
--     if (not validTypes[currentTypes]) then
--         error("Invalid arguments types. Found : " .. currentTypes .. ". Please check that all required arguments are present", 2)
--     end
--     --#endregion

--     --TODO : default to default route interface address
--     if (not address) then address = 0 end

--     if (port == nil or port == 0) then
--         repeat
--             port = math.random(1025, (2 ^ 16) - 1)
--         until not self:getSocket(address, port, remoteAddress, remotePort)
--     end
--     local socket = UDPSocket(self, address, port, remoteAddress, remotePort)
--     if (self:addSocket(socket)) then
--         return socket
--     else
--         return nil, "Could not create socket"
--     end
-- end
--#endregion

---comment
---@param socket UDPSocket
---@param address number
---@param port number
---@return number? port, string? reason
function UDPLayer:bindSocket(socket, address, port)
    self:close(socket) --delete the socket from the internal data
    local rIPString, rPort = socket:getpeername()
    local rIP = ipv4Address.fromString(rIPString)
    self._sockets[address] = self._sockets[address] or {}
    if (port == 0) then
        repeat
            repeat
                port = math.random(49152, 65535)
            until not self._sockets[address][port]
        until not (self._sockets[address][port] and self._sockets[address][port][rIP] and self._sockets[address][port][rIP][rPort])
    end
    if (not self:addSocket(socket, address, port, rIP, rPort)) then
        return nil, "Port busy"
    end
    return port
end

---@param socket UDPSocket
---@param address number
---@param port number
---@return number? port, string? reason
function UDPLayer:connectSocket(socket, address, port)
    self:close(socket) --delete the socket from the internal data
    local lIPString, lPort = socket:getsockname()
    local lIP = ipv4Address.fromString(lIPString)
    if (lIPString ~= 0 and lPort == 0) then
        self._sockets[lIP] = self._sockets[lIP] or {}
        if (port == 0) then
            repeat
                repeat
                    port = math.random(49152, 65535)
                until not self._sockets[lIP][lPort]
            until not (self._sockets[lIP][lPort][address] and self._sockets[lIP][lPort][address][port])
        end
        if (not self:addSocket(socket, lIP, lPort, address, port)) then
            return nil, "Port busy"
        end
    else
        if (not self:addSocket(socket, lIP, lPort, address, port)) then
            return nil, "Port busy"
        end
    end
    return 1
end

---@package
---@param socket UDPSocket
function UDPLayer:close(socket)
    local function tableEmpty(tbl)
        for _, _ in pairs(tbl) do
            return false
        end
        return true
    end
    if (not self:isOpen(socket)) then return end
    local lIPString, lPort = socket:getsockname()
    local lIP = ipv4Address.fromString(lIPString)
    local peerIPString, peerPort = socket:getpeername()
    local peerIP = ipv4Address.fromString(peerIPString)

    self._sockets[lIP][lPort][peerIP][peerPort] = nil

    if (tableEmpty(self._sockets[lIP][lPort][peerIP])) then
        self._sockets[lIP][lPort][peerIP] = nil
    end
    if (tableEmpty(self._sockets[lIP][lPort])) then
        self._sockets[lIP][lPort] = nil
    end
    if (tableEmpty(self._sockets[lIP])) then
        self._sockets[lIP] = nil
    end
end

---Check if the given socket is open on this layer
---@param socket UDPSocket
---@return boolean
function UDPLayer:isOpen(socket)
    local lIPString, lPort = socket:getsockname()
    local lIP = ipv4Address.fromString(lIPString)
    local peerIPString, peerPort = socket:getpeername()
    local peerIP = ipv4Address.fromString(peerIPString)

    if (self:getSocket(lIP, lPort, peerIP, peerPort)) then
        return true
    else
        return false
    end
end

---Get the matching open socket
---@private
---@param localAddress? number
---@param localPort number
---@param remoteAddress? number
---@param remotePort? number
---@return UDPSocket?
function UDPLayer:getSocket(localAddress, localPort, remoteAddress, remotePort)
    checkArg(1, localAddress, 'nil', 'number')
    localAddress = localAddress or 0
    checkArg(2, localPort, 'number')
    checkArg(3, remoteAddress, 'nil', 'number')
    remoteAddress = remoteAddress or 0
    checkArg(4, remotePort, 'nil', 'number')
    remotePort = remotePort or 0
    if (not self._sockets[localAddress]) then
        if (self._sockets[0]) then
            localAddress = 0
        else
            return
        end
    end
    local tmp = self._sockets[localAddress]

    if (not tmp[localPort]) then return end
    tmp = tmp[localPort]

    if (not tmp[remoteAddress]) then
        if (tmp[0]) then
            remoteAddress = 0
        else
            return
        end
    end
    tmp = tmp[remoteAddress]

    if (not tmp[remotePort]) then
        if (tmp[0]) then
            remotePort = 0
        else
            return
        end
    end
    return tmp[remotePort]
end

---Send a udp paylaod
---@param from number
---@param to number
---@param payload UDPDatagram
function UDPLayer:send(from, to, payload)
    checkArg(1, from, 'number')
    checkArg(2, to, 'number')
    checkArg(3, payload, 'table')
    network.router:send(IPv4Packet(from, to, payload, self.layerType))
end

function UDPLayer:getAddr() return self._layer:getAddr() end

function UDPLayer:getMTU() return self._layer:getMTU() - 8 end

---add a socket to the internal list. Return false if could not be added (addrress / port already in use)
---@private
---@param socket UDPSocket
---@param localAddress number
---@param localPort number
---@param remoteAddress number
---@param remotePort number
---@overload fun(self,socket:UDPSocket)
---@return boolean added
function UDPLayer:addSocket(socket, localAddress, localPort, remoteAddress, remotePort)
    checkArg(1, socket, 'table')
    if (localAddress ~= nil) then
        checkArg(2, localAddress, 'number')
        checkArg(3, localPort, 'number')
        checkArg(4, remoteAddress, 'number')
        checkArg(5, remotePort, 'number')
    else
        local lIPString, peerIPString
        lIPString, localPort = socket:getsockname()
        localAddress = ipv4Address.fromString(lIPString)
        peerIPString, remotePort = socket:getpeername()
        remoteAddress = ipv4Address.fromString(peerIPString)
    end

    self._sockets[localAddress] = self._sockets[localAddress] or {}
    local tmp = self._sockets[localAddress]
    tmp[localPort] = tmp[localPort] or {}
    tmp = tmp[localPort]
    tmp[remoteAddress] = tmp[remoteAddress] or {}
    tmp = tmp[remoteAddress]

    if (not tmp[remotePort]) then
        tmp[remotePort] = socket
        return true
    else
        return false
    end
end

---@return table<table>
function UDPLayer:getOpenPorts()
    local r = {}
    local function getTreeBottomValues(tree)
        local vals = {}
        for _, v1 in pairs(tree) do
            for _, v2 in pairs(v1) do
                for _, v3 in pairs(v2) do
                    for _, socket in pairs(v3) do
                        table.insert(vals, socket)
                    end
                end
            end
        end
        return vals
    end

    for _, socket in pairs(getTreeBottomValues(self._sockets)) do
        local lIPString, lPort = socket:getsockname()
        local lIP = ipv4Address.fromString(lIPString)
        local peerIPString, peerPort = socket:getpeername()
        local peerIP = ipv4Address.fromString(peerIPString)
        table.insert(r, {
            loc = {address = lIP, port = lPort},
            rem = {address = peerIP, port = peerPort}
        })
    end

    return r
end

return UDPLayer
