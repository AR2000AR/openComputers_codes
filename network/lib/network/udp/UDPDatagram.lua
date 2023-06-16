local Payload = require("network.abstract.Payload")
local class = require("libClass2")
local utils = require('network.utils')
local ipv4Consts = require("network.ipv4.constantes")

---@class UDPDatagram : Payload
---@field private _srcPort number
---@field private _dstPort number
---@field private _payload string
---@operator call:UDPDatagram
---@overload fun(srcPort:number,dstPort:number,payload:string):UDPDatagram
local UDPDatagram = class(Payload)
UDPDatagram.payloadType = ipv4Consts.PROTOCOLS.UDP

---@param self UDPDatagram
---@param srcPort number
---@param dstPort number
---@param payload string
---@return UDPDatagram
function UDPDatagram:new(srcPort, dstPort, payload)
    checkArg(1, srcPort, "number")
    checkArg(2, dstPort, "number")
    checkArg(3, payload, "string")
    local o = self.parent()
    setmetatable(o, {__index = self})

    o:dstPort(dstPort)
    o:srcPort(srcPort)
    o:payload(payload)

    return o
end

---@param value? number
---@return number
function UDPDatagram:dstPort(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self._dstPort
    if (value ~= nil) then
        assert(value >= 0 and value <= 2 ^ 16 - 1, "Port outside valid range")
        self._dstPort = value
    end
    return oldValue
end

---@param value? number
---@return number
function UDPDatagram:srcPort(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self._srcPort
    if (value ~= nil) then
        assert(value >= 0 and value <= 2 ^ 16 - 1, "Port outside valid range")
        self._srcPort = value
    end
    return oldValue
end

---@param value? string
---@return string
function UDPDatagram:payload(value)
    checkArg(1, value, 'string', 'nil')
    local oldValue = self._payload
    if (value ~= nil) then self._payload = value end
    return oldValue
end

---@param value? number
---@return number
function UDPDatagram:checksum(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self._checksum or 0
    if (value ~= nil) then self._checksum = value end
    return oldValue
end

---@return number
function UDPDatagram:length()
    return 8 + #self:payload()
end

UDPDatagram.payloadFormat = ">HHHH"

function UDPDatagram:calculateChecksum(src, dst)
    local packed = string.pack('>IIxBH' .. self.payloadFormat, src, dst, 17, self:length(), self:srcPort(), self:dstPort(), self:length(), 0)
    packed = packed .. string.pack('>c' .. #self:payload(), self:payload())
    return utils.checksum(packed)
end

---Prepare the packet for the next layer
---@return string
function UDPDatagram:pack()
    local packed = string.pack(self.payloadFormat, self:srcPort(), self:dstPort(), self:length(), self:checksum())
    packed = packed .. string.pack('>c' .. #self:payload(), self:payload())
    return packed
end

---Get a udp packet from the string
---@param value string
---@return UDPDatagram
function UDPDatagram.unpack(value)
    local src, dst, len, chk, offset = string.unpack(UDPDatagram.payloadFormat, value)
    local payload = string.unpack('>c' .. len - offset, value, offset)
    return UDPDatagram(src, dst, payload)
end

return UDPDatagram
