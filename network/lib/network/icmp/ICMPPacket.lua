local ipv4             = require("network.ipv4")
local Payload          = require("network.abstract.Payload")
local utils            = require("network.utils")
local bit32            = require("bit32")

local class            = require("libClass2")

---@class ICMPPacket:Payload
---@field private _type number
---@field private _code number
---@field private _checksum number
---@field private _param number
---@field private _payload string
---@operator call:ICMPPacket
---@overload fun(type:icmpType,code:number,param:number,paylaod:string):ICMPPacket
---@overload fun(type:icmpType,code:number,param:number):ICMPPacket
---@overload fun(type:icmpType,code:number):ICMPPacket
local ICMPPacket       = class(Payload)
ICMPPacket.payloadType = ipv4.PROTOCOLS.ICMP


---@param type icmpType
---@param code number
---@param param? number
---@param payload? string
---@return ICMPPacket
function ICMPPacket:new(type, code, param, payload)
    local o = {
        _type = type,
        _code = code,
        _param = param or 0,
        _payload = payload or ""
    }
    setmetatable(o, {__index = self})
    return o
end

--#region getter/setter

---@param value? number
---@return number
function ICMPPacket:type(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self._type
    if (value ~= nil) then self._type = value end
    return oldValue
end

---@param value? number
---@return number
function ICMPPacket:code(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self._code
    if (value ~= nil) then self._code = value end
    return oldValue
end

---@param value? number
---@return number
function ICMPPacket:checksum(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self._checksum or self:calculateChecksum()
    if (value ~= nil) then self._checksum = value end
    return oldValue
end

---@return number
function ICMPPacket:calculateChecksum()
    return utils.checksum(string.pack(self.headerFormat, self:type(), self:code(), 0, self:param()) .. string.pack('c' .. #self:payload(), self:payload()))
end

---@param value? number
---@return number
function ICMPPacket:param(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self._param
    if (value ~= nil) then self._param = value end
    return oldValue
end

---@param value? string
---@return string
function ICMPPacket:payload(value)
    checkArg(1, value, 'string', 'nil')
    local oldValue = self._payload
    if (value ~= nil) then self._payload = value end
    return oldValue
end

--#endregion

ICMPPacket.headerFormat = ">BBHI"
ICMPPacket.payloadFormat = ICMPPacket.headerFormat

function ICMPPacket:pack()
    local header = string.pack(self.payloadFormat, self:type(), self:code(), self:checksum(), self:param())
    return header .. string.pack('c' .. #self:payload(), self:payload())
end

---@return ICMPPacket
function ICMPPacket.unpack(val)
    local type, code, checksum, param, offset = string.unpack(ICMPPacket.payloadFormat, val)
    local payload = string.unpack('z', val, offset)
    local icmp = ICMPPacket(type, code, param, payload)
    icmp:checksum(checksum)
    return icmp
end

return ICMPPacket
