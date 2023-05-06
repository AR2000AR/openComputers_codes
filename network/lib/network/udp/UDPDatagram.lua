local Payload = require("network.abstract.Payload")
local class = require("libClass2")

---@class UDPDatagram : Payload
---@field private _srcPort number
---@field private _dstPort number
---@field private _payload string
---@operator call:UDPDatagram
---@overload fun(srcPort:number,dstPort:number,payload:string):UDPDatagram
local UDPDatagram = class(Payload)
UDPDatagram.payloadType = require("network.ipv4").PROTOCOLS.UDP

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

local PACK_FORMAT = "I2I2xxxxs"

---Prepare the packet for the next layer
---@return string
function UDPDatagram:pack()
    return string.pack(PACK_FORMAT, self:srcPort(), self:dstPort(), self:payload())
end

---Get a udp packet from the string
---@param value string
---@return UDPDatagram
function UDPDatagram.unpack(value)
    return UDPDatagram(string.unpack(PACK_FORMAT, value))
end

return UDPDatagram
