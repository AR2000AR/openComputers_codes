local ipv4  = require("layers.ipv4")
local event = require("event")
--=============================================================================


---@class icmplib
local icmp = {}
---@enum icmpType
icmp.TYPE = {
    ECHO_REPLY                      = 0,
    DESTINATION_UNREACHABLE         = 3,
    REDIRECT_MESSAGE                = 5,
    ECHO_REQUEST                    = 8,
    ROUTER_ADVERTISEMENT            = 9,
    ROUTER_SOLICITATION             = 10,
    TIME_EXCEEDED                   = 11,
    PARAMETER_PROBELM_BAD_IP_HEADER = 12,
    TIMESTAMP                       = 13,
    TIMESTAMP_REPLY                 = 14,
    EXTENDED_ECHO_REQUEST           = 42,
    EXTENDED_ECHO_REPLY             = 43
}
icmp.CODE = {
    ECHO_REPLY = {
        ECHO_REPLY = 0
    },
    DESTINATION_UNREACHABLE = {
        DESTINATION_NETWORK_UNREACHABLE = 0,
        DESTINATION_HOST_UNREACHABLE = 1,
        DESTINATION_PROTOCOL_UNREACHABLE = 2,
        DESTINATION_PORT_UNREACHABLE = 3,
        FRAGMENTATION_REQUIRED_AND_DF_FLAG_SET = 4,
        SOURCE_ROUTE_FAILED = 5,
        DESTINATION_NETWORK_UNKNOWN = 6,
        DESTINATION_HOST_UNKNOWN = 7,
        SOURCE_HOST_ISOLATED = 8,
        NETWORK_ADMINISTRATIVELY_PROHIBITED = 9,
        HOST_ADMINISTRATIVELY_PROHIBITED = 10,
        NETWORK_UNREACHABLE_FOR_TOS = 11,
        HOST_UNREACHABLE_FOR_TOS = 12,
        COMMUNICATION_ADMINISTRATIVELY_PROHIBITED = 13,
        HOST_PRECEDENCE_VIOLATION = 14,
        PRECEDENCE_CUTOFF_IN_EFFECT = 15,
    },
    REDIRECT_MESSAGE = {
        REDIRECT_DATAGRAM_FOR_THE_NETWORK = 0,
        REDIRECT_DATAGRAM_FOR_THE_HOST = 1,
        REDIRECT_DATAGRAM_FOR_THE_TOS_NETWORK = 2,
        REDIRECT_DATAGRAM_FOR_THE_TOS_HOST = 3,
    },
    ECHO_REQUEST = {
        Echo_request = 0,
    },
    ROUTER_ADVERTISEMENT = {
        ROUTER_ADVERTISEMENt = 0,
    },
    ROUTER_SOLICITATION = {
        Router_discovery_selection_solicitation = 0,
    },
    TIME_EXCEEDED = {
        TTL_expired_in_transit = 0,
        Fragment_reassembly_time_exceeded = 1,
    },
    PARAMETER_PROBELM_BAD_IP_HEADER = {
        Pointer_indicates_the_error = 0,
        Missing_a_required_option = 1,
        Bad_length = 2,
    },
    TIMESTAMP = {
        Timestamp = 0,
    },
    TIMESTAMP_REPLY = {
        Timestamp_reply = 0,
    },
    EXTENDED_ECHO_REQUEST = {
        Request_Extended_Echo = 0,
    },
    EXTENDED_ECHO_REPLY = {
        No_Error = 0,
        Malformed_Query = 1,
        No_Such_Interface = 2,
        No_Such_Table_Entry = 3,
        Multiple_Interfaces_Satisfy_Query = 4,
    }
}

--=============================================================================
--#region ICMPPacket

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

function ICMPPacket:pack()
    return string.format("%.2x%.2x%.8x%s", self._type, self._code, self._param, self._payload)
end

---@return ICMPPacket
function ICMPPacket.unpack(val)
    local o = "%x%x"
    local patern = string.format("(%s)(%s)(%s)(%s)", o, o, o:rep(4), ".*")
    local a, b, c, d = val:match(patern)
    a = tonumber(a, 16);
    assert(a)
    b = tonumber(b, 16);
    assert(b)
    c = tonumber(c, 16);
    assert(c)
    return ICMPPacket(a, b, c, d)
end

--#endregion
---=============================================================================
--#region ICMPLayer

---@class ICMPLayer:OSINetworkLayer
---@field private _layer IPv4Layer
---@operator call:ICMPLayer
---@overload fun(layer:IPv4Layer):ICMPLayer
local ICMPLayer = {}
ICMPLayer.layerType = ipv4.PROTOCOLS.ICMP

setmetatable(ICMPLayer, {
    ---@param layer IPv4Layer
    ---@return ICMPLayer
    __call = function(self, layer)
        local o = {
            _layer = layer
        }
        setmetatable(o, {__index = self})
        layer:setLayer(o)
        return o
    end,
})

---@param payload ICMPPacket
function ICMPLayer:send(dst, payload)
    local ipDatagram = ipv4.IPv4Packet(self._layer:getAddr(), dst, payload)
    self._layer:getRouter():send(ipDatagram)
end

---@param payload string
function ICMPLayer:payloadHandler(from, to, payload)
    local icmpPacket = ICMPPacket.unpack(payload)
    if (icmpPacket:getType() == icmp.TYPE.ECHO_REQUEST) then
        local reply = ICMPPacket(icmp.TYPE.ECHO_REPLY, icmp.CODE.ECHO_REPLY.ECHO_REPLY, icmpPacket:getParam(), icmpPacket:getPayload())
        self:send(from, reply)
    elseif (icmpPacket:getType() == icmp.TYPE.ECHO_REPLY) then
        event.push("ICMP", from, to, icmpPacket:getType(), icmpPacket:getCode(), icmpPacket:getParam(), icmpPacket:getPayload())
    end
end

function ICMPLayer:getAddr()
    return self._layer:getAddr()
end

---Send a timeout icmp message
---@param packet IPv4Packet
---@param code number
function ICMPLayer:sendTimeout(packet, code)
    local icmpPacket = ICMPPacket(icmp.TYPE.TIME_EXCEEDED, icmp.CODE.TIME_EXCEEDED.TTL_expired_in_transit, nil, string.format("%.2x%.2x%.4x%.4x%.2x%.4x%.2x%.2x%.8x%.8x%s",
                                                                                                                              packet:getDscp(), packet:getEcn(), packet:getLen(), packet:getId(), packet:getFlags(),
                                                                                                                              packet:getFragmentOffset(), packet:getTtl(), packet:getProtocol(),
                                                                                                                              packet:getSrc(), packet:getDst(), packet:getPayload():sub(1, 8)))
    self:send(packet:getSrc(), icmpPacket)
end

--#endregion
--=============================================================================

--=============================================================================
icmp.ICMPPacket = ICMPPacket
icmp.ICMPLayer = ICMPLayer
return icmp
