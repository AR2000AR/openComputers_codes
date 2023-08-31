local IPv4Packet   = require("network.ipv4.IPv4Packet")
local TCPSegment   = require("network.tcp.TCPSegment")
local ipv4Address  = require("network.ipv4.address")
local NetworkLayer = require('network.abstract.NetworkLayer')
local network      = require("network")
local class        = require("libClass2")


---@class TCPLayer:NetworkLayer
---@field private _sockets table<number,table<number,table<number,table<number,TCPSocket>>>>
---@operator call:TCPLayer
---@overload fun(layer:IPv4Layer):TCPLayer
local TCPLayer = class(NetworkLayer)
TCPLayer.layerType = require("network.ipv4").PROTOCOLS.TCP

---@param layer IPv4Layer
---@return TCPLayer
function TCPLayer:new(layer)
    local o = self.parent()
    setmetatable(o, {__index = self})
    ---@cast o TCPLayer
    o._sockets = {}
    o:layer(layer) --tell the IPv4Layer that we exists
    return o
end

function TCPLayer:payloadHandler(from, to, payload)
    local seg = TCPSegment.unpack(payload)
    local socket
    if (seg:flag(TCPSegment.Flags.SYN) and not seg:flag(TCPSegment.Flags.ACK)) then
        --initial sync packet
        socket = self:getSocket(to, seg:dstPort(), 0, 0)
        if (not socket) then
            local rstseg = TCPSegment(seg:dstPort(), seg:srcPort(), "")
            rstseg:flags(TCPSegment.Flags.RST|TCPSegment.Flags.ACK)
            rstseg:seq(seg:flag(TCPSegment.Flags.ACK) and seg:ack() or 0)
            rstseg:ack(seg:seq() + seg:len())
            self:send(to, from, rstseg)
            return
        end
        assert(socket:getState() == "LISTEN")
    else
        socket = self:getSocket(to, seg:dstPort(), from, seg:srcPort())
        if (not socket) then return end
    end
    socket:payloadHandler(from, to, seg)
end

---bind the socket to a local address and port
---@param socket TCPSocket
---@param address number
---@param port number
---@return number? port, string? reason
function TCPLayer:bindSocket(socket, address, port)
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

---@package
---@param socket TCPSocket
function TCPLayer:close(socket)
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
---@param socket TCPSocket
---@return boolean
function TCPLayer:isOpen(socket)
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
---@return TCPSocket?
function TCPLayer:getSocket(localAddress, localPort, remoteAddress, remotePort)
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

---Send a tcp paylaod
---@param from number
---@param to number
---@param payload TCPSegment
function TCPLayer:send(from, to, payload)
    checkArg(1, from, 'number')
    checkArg(2, to, 'number')
    checkArg(3, payload, 'table')
    network.router:send(IPv4Packet(from, to, payload, self.layerType))
end

function TCPLayer:addr() return self:layer():addr() end

function TCPLayer:mtu()
    return self:layer():mtu() - 5 * 4 -- minimum header size is 5*32 bits or 5*4 bytes
end

---@param socket TCPSocket
---@param address number
---@param port number
---@return number? port, string? reason
function TCPLayer:connectSocket(socket, address, port)
    self:close(socket) --delete the socket from the internal data
    local lIPString, lPort = socket:getsockname()
    local lIP
    if (lIPString == "0.0.0.0") then
        local r = network.router:getRoute(address)
        if (r) then lIP = r.interface:addr() end
    else
        lIP = ipv4Address.fromString(lIPString)
    end
    if (lIP ~= 0 and lPort == 0) then
        self._sockets[lIP] = self._sockets[lIP] or {}
        if (lPort == 0) then
            repeat
                lPort = math.random(49152, 65535)
            until not self._sockets[lIP][lPort] or not self._sockets[lIP][lPort][address] or not self._sockets[lIP][lPort][address][port]
        end
        if (not self:addSocket(socket, lIP, lPort, address, port)) then
            return nil, "Port busy"
        end
    else
        if (not self:addSocket(socket, lIP, lPort, address, port)) then
            return nil, "Port busy"
        end
    end
    socket:_setsockname(ipv4Address.tostring(lIP), lPort)
    return 1
end

---add a socket to the internal list. Return false if could not be added (addrress / port already in use)
---@param socket TCPSocket
---@param localAddress number
---@param localPort number
---@param remoteAddress number
---@param remotePort number
---@overload fun(self,socket:TCPSocket)
---@return boolean added
function TCPLayer:addSocket(socket, localAddress, localPort, remoteAddress, remotePort)
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
        local r = network.router:getRoute(remoteAddress ~= 0 and remoteAddress or localAddress)
        if (r) then socket:mss(r.interface:mtu() - 40) end
        return true
    else
        return false
    end
end

---@return table<table>
function TCPLayer:getOpenPorts()
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
            state = socket:getState(),
            loc = {address = lIP, port = lPort},
            rem = {address = peerIP, port = peerPort}
        })
    end

    return r
end

return TCPLayer
