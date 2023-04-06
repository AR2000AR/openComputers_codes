local ipv4 = require("network.ipv4")


---@class ICMPPacket:Payload
---@field private _type number
---@field private _code number
---@field private _param number
---@field private _payload string
---@operator call:ICMPPacket
---@overload fun(type:icmpType,code:number,param:number,paylaod:string):ICMPPacket
---@overload fun(type:icmpType,code:number,param:number):ICMPPacket
---@overload fun(type:icmpType,code:number):ICMPPacket
local ICMPPacket = {}
ICMPPacket.payloadType = ipv4.PROTOCOLS.ICMP

setmetatable(ICMPPacket, {
    ---@param type icmpType
    ---@param code number
    ---@param param? number
    ---@param payload? string
    ---@return ICMPPacket
    __call = function(self, type, code, param, payload)
        local o = {
            _type = type,
            _code = code,
            _param = param or 0,
            _payload = payload or ""
        }
        setmetatable(o, {__index = self})
        return o
    end
})

--#region getter/setter

---@return number
function ICMPPacket:getType() return self._type end

---@param val number
function ICMPPacket:setType(val)
    checkArg(1, val, "number")
    self._type = val
end

---@return number
function ICMPPacket:getCode() return self._code end

---@param val number
function ICMPPacket:setCode(val)
    checkArg(1, val, "number")
    self._code = val
end

---@return number
function ICMPPacket:getParam() return self._param end

---@param val number
function ICMPPacket:setParam(val)
    checkArg(1, val, "number")
    self._param = val
end

---@return string
function ICMPPacket:getPayload() return self._payload end

---@param val string
function ICMPPacket:setPayload(val)
    checkArg(1, val, "string")
    self._payload = val
end

--#endregion

local PACK_FORMAT = "I1I1xxI4s"

function ICMPPacket:pack()
    return string.pack(PACK_FORMAT, self._type, self._code, self._param, self._payload)
end

---@return ICMPPacket
function ICMPPacket.unpack(val)
    return ICMPPacket(string.unpack(PACK_FORMAT, val))
end

return ICMPPacket
