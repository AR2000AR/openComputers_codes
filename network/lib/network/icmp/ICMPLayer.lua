local network    = require("network")
local ipv4       = require("network.ipv4")
local ICMPPacket = require("network.icmp.ICMPPacket")
local icmpConst  = require("network.icmp.constantes")
local event      = require("event")


---@class ICMPLayer:OSINetworkLayer
---@field private _layer OSINetworkLayer
---@operator call:ICMPLayer
---@overload fun(layer:IPv4Layer):ICMPLayer
local ICMPLayer = {}
ICMPLayer.layerType = ipv4.PROTOCOLS.ICMP

setmetatable(ICMPLayer, {
    ---@param layer OSINetworkLayer
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
    local localIP = network.router:getRoute(dst).interface:getAddr()
    assert(localIP, "[ICMP] : no local IP. Cannot send packet")
    local ipDatagram = ipv4.IPv4Packet(localIP, dst, payload)
    network.router:send(ipDatagram)
end

---@param payload string
function ICMPLayer:payloadHandler(from, to, payload)
    local icmpPacket = ICMPPacket.unpack(payload)
    if (icmpPacket:getType() == icmpConst.TYPE.ECHO_REQUEST) then
        local reply = ICMPPacket(icmpConst.TYPE.ECHO_REPLY, icmpConst.CODE.ECHO_REPLY.ECHO_REPLY, icmpPacket:getParam(), icmpPacket:getPayload())
        self:send(from, reply)
    elseif (icmpPacket:getType() == icmpConst.TYPE.ECHO_REPLY) then
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
    local icmpPacket = ICMPPacket(icmpConst.TYPE.TIME_EXCEEDED, icmpConst.CODE.TIME_EXCEEDED.TTL_expired_in_transit, nil, string.format("%.2x%.2x%.4x%.4x%.2x%.4x%.2x%.2x%.8x%.8x%s",
                                                                                                                                        packet:getDscp(), packet:getEcn(), packet:getLen(), packet:getId(), packet:getFlags(),
                                                                                                                                        packet:getFragmentOffset(), packet:getTtl(), packet:getProtocol(),
                                                                                                                                        packet:getSrc(), packet:getDst(), packet:getPayload():sub(1, 8)))
    self:send(packet:getSrc(), icmpPacket)
end

return ICMPLayer
