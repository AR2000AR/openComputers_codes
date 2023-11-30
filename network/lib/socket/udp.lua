local ipv4Address = require("network.ipv4.address")
local UDPDatagram = require("network.udp.UDPDatagram")
local network     = require("network")
local class       = require("libClass2")

---@alias UDPSocketKind
--- | "unconnected"
--- | "connected"

---@class UDPSocket:Object
---@field public kind UDPSocketKind
---@field private _sockname table
---@field private _peername table
---@field private _buffer table
---@field private _timeout number
---@operator call:UDPSocket
---@overload fun(self):UDPSocket
local UDPSocket   = class()

---Comment
---@return UDPSocket
function UDPSocket:new()
    local o = self.parent()
    setmetatable(o, {__index = self})
    ---@cast o UDPSocket
    o._sockname = {"0.0.0.0", 0}
    o._peername = {"0.0.0.0", 0}
    o.kind = "unconnected"
    o._buffer = {}
    o._timeout = 0
    return o
end

function UDPSocket:close()
    network.udp.getInterface():close(self)
end

---Retrieves information about the peer associated with a connected UDP object.\
---Returns the IP address and port number of the peer.\
---Note: It makes no sense to call this method on unconnected objects.
---@return string address,number port
function UDPSocket:getpeername()
    return table.unpack(self._peername)
end

---Returns the local address information associated to the object.\
---The method returns a string with local IP address and a number with the port. In case of error, the method returns nil.\
---Note: UDP sockets are not bound to any address until the setsockname or the sendto method is called for the first time (in which case it is bound to an ephemeral port and the wild-card address).
---@return string address,number port
function UDPSocket:getsockname()
    return table.unpack(self._sockname)
end

---@param size? number
---@return string?
function UDPSocket:recieve(size)
    local datagram = self:receivefrom(size)
    return datagram
end

---@return string? datagram, string? fromAddress, number? fromPort
function UDPSocket:receivefrom(size)
    --TODO : use the size
    if (select(2, self:getsockname()) == 0) then
        error("Reciving object before binding to a address/port", 2)
    end
    local t1 = os.time()
    repeat
        os.sleep()
    until #self._buffer > 0 or (self._timeout > 0 and os.time() - t1 > self._timeout)
    if (#self._buffer > 0) then
        return table.unpack(table.remove(self._buffer, 1))
    end
end

---Sends a datagram to the UDP peer of a connected object.\
---Datagram is a string with the datagram contents. The maximum datagram size for UDP is 64K minus IP layer overhead. However datagrams larger than the link layer packet size will be fragmented, which may deteriorate performance and/or reliability.\
---If successful, the method returns 1. In case of error, the method returns nil followed by an error message.\
---Note: In UDP, the send method never blocks and the only way it can fail is if the underlying transport layer refuses to send a message to the specified address (i.e. no interface accepts the address).
---@param datagram string
---@return number?,string? reason
function UDPSocket:send(datagram)
    if (self.kind == "unconnected") then return nil, "Not a connected udp socket" end
    return self:sendto(datagram, self:getpeername())
end

---comment
---@param datagram string
---@param ip string
---@param port number
---@return number?,string? reason
function UDPSocket:sendto(datagram, ip, port)
    if (select(2, self:getsockname()) == 0) then
        self:setsockname('*', 0)
    end
    local lIP, srcPort = self:getsockname()
    local dstIP = ipv4Address.fromString(ip)
    local srcIP = ipv4Address.fromString(lIP)
    local datagramObject = UDPDatagram(srcPort, port, datagram)
    network.udp.getInterface():send(srcIP, dstIP, datagramObject)
    return 1
end

---@param address string
---@param port number
---@overload fun(self,address:string)
---@return number? success, string? reason
function UDPSocket:setpeername(address, port)
    checkArg(1, address, 'string')
    if (self.kind == "connected") then
        if (address ~= '*') then
            error("Address must be '*'", 2)
        end
        network.udp.getInterface():connectSocket(self, 0, 0)
        self._peername = {"0.0.0.0", 0}
        self.kind = "unconnected"
        return 1
    else
        checkArg(2, port, 'number')
        local success, reason = network.udp.getInterface():connectSocket(self, ipv4Address.fromString(address), port)
        if (success) then
            self._peername = {address, port}
            self.kind = "connected"
            return 1
        else
            return nil, reason
        end
    end
end

---@param address string
---@param port number
---@return number? success, string? reason
function UDPSocket:setsockname(address, port)
    checkArg(1, address, 'string')
    checkArg(2, port, 'number')
    local reason
    if (not self.kind == "unconnected") then return nil, "Not a unconnected udp socket" end
    if (address == '*') then address = "0.0.0.0" end
    local _, sockP = self:getsockname()
    if (sockP == 0) then
        ---@diagnostic disable-next-line: cast-local-type
        port, reason = network.udp.getInterface():bindSocket(self, ipv4Address.fromString(address), port)
        if (port) then
            self._sockname = {address, port}
        end
        return 1, reason
    else
        return nil, "Socket already bound"
    end
end

---Sets options for the UDP object. Options are only needed by low-level or time-critical applications. You should only modify an option if you are sure you need it.
---@param option 'dontroute'|'broadcast'
---@param value? boolean
function UDPSocket:setoption(option, value)
    error("NOT IMPLEMENTED", 2)
end

---Set the socket's timeout in second
---@param value number seconds
function UDPSocket:settimeout(value)
    checkArg(1, value, 'number')
    self._timeout = value * 100
end

---Handle the payload recived by UDPLayer
---@package
---@param from number
---@param to number
---@param udpPacket UDPDatagram
function UDPSocket:payloadHandler(from, to, udpPacket)
    table.insert(self._buffer, {udpPacket:payload(), ipv4Address.tostring(from), udpPacket:srcPort()})
end

return UDPSocket
