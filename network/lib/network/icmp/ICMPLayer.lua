local network      = require("network")
local ipv4         = require("network.ipv4")
local ICMPPacket   = require("network.icmp.ICMPPacket")
local icmpConst    = require("network.icmp.constantes")
local event        = require("event")
local NetworkLayer = require('network.abstract.NetworkLayer')
local class        = require("libClass2")


---@class ICMPLayer:NetworkLayer
---@operator call:ICMPLayer
---@overload fun(layer:IPv4Layer):ICMPLayer
local ICMPLayer = class(NetworkLayer)
ICMPLayer.layerType = ipv4.PROTOCOLS.ICMP

---@param layer NetworkLayer
---@return ICMPLayer
function ICMPLayer:new(layer)
    local o = self.parent()
    setmetatable(o, {__index = self})
    ---@cast o ICMPLayer
    o:layer(layer)
    return o
end

---@param payload ICMPPacket
function ICMPLayer:send(dst, payload)
    local localIP = network.router:getRoute(dst).interface:addr()
    assert(localIP, "[ICMP] : no local IP. Cannot send packet")
    local ipDatagram = ipv4.IPv4Packet(localIP, dst, payload)
    network.router:send(ipDatagram)
end

---@param payload string
function ICMPLayer:payloadHandler(from, to, payload)
    local icmpPacket = ICMPPacket.unpack(payload)
    if (icmpPacket:type() == icmpConst.TYPE.ECHO_REQUEST) then
        local reply = ICMPPacket(icmpConst.TYPE.ECHO_REPLY, icmpConst.CODE.ECHO_REPLY.ECHO_REPLY, icmpPacket:param(), icmpPacket:payload())
        self:send(from, reply)
    elseif (icmpPacket:type() == icmpConst.TYPE.ECHO_REPLY) then
        event.push("ICMP", from, to, icmpPacket:type(), icmpPacket:code(), icmpPacket:param(), icmpPacket:payload())
    end
end

function ICMPLayer:addr()
    return self:layer():addr()
end

---Send a timeout icmp message
---@param packet IPv4Packet
---@param code number
function ICMPLayer:sendTimeout(packet, code)
    local icmpPacket = ICMPPacket(icmpConst.TYPE.TIME_EXCEEDED, icmpConst.CODE.TIME_EXCEEDED.TTL_expired_in_transit, nil, string.format("%.2x%.2x%.4x%.4x%.2x%.4x%.2x%.2x%.8x%.8x%s",
                                                                                                                                        packet:dscp(), packet:ecn(), packet:len(), packet:id(), packet:flags(),
                                                                                                                                        packet:fragmentOffset(), packet:ttl(), packet:protocol(),
                                                                                                                                        packet:src(), packet:dst(), packet:payload():sub(1, 8)))
    self:send(packet:src(), icmpPacket)
end

return ICMPLayer
