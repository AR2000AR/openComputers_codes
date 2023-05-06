local ipv4             = require("network.ipv4")
local Payload          = require("network.abstract.Payload")

local class            = require("libClass2")

---@class ICMPPacket:Payload
---@field private _type number
---@field private _code number
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

ICMPPacket.payloadFormat = "I1I1xxI4s"

function ICMPPacket:pack()
    return string.pack(self.payloadFormat, self._type, self._code, self._param, self._payload)
end

---@return ICMPPacket
function ICMPPacket.unpack(val)
    return ICMPPacket(string.unpack(ICMPPacket.payloadFormat, val))
end

return ICMPPacket
