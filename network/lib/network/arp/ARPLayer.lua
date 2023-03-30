local ethernet = require("network.ethernet")
local ARPFrame = require("network.arp.ARPFrame")
local arpConst = require("network.arp.constantes")
local arpAPI   = require("network.arp.api")


---@class ARPLayer : OSINetworkLayer
local ARPLayer = {}
---@type ethernetType
ARPLayer.layerType = ethernet.TYPE.ARP

setmetatable(ARPLayer, {
    ---@param osiLayer OSIDataLayer
    ---@return ARPLayer
    __call = function(self, osiLayer)
        local o = {
            _layer = osiLayer
        }
        setmetatable(o, {__index = self})
        osiLayer:setLayer(o)
        return o
    end
})

function ARPLayer:getAddr()
    return self._layer:getAddr()
end

function ARPLayer:getMTU()
    return 0
end

---Handle the payload from the layer under
---@param from string
---@param to string
---@param payload string
function ARPLayer:payloadHandler(from, to, payload)
    local arpFrame = ARPFrame.unpack(payload)
    if (arpFrame:getOper() == arpConst.OPERATION.REQUEST) then
        local protocolAddress = arpAPI.getLocalAddress(arpFrame:getHtype(), arpFrame:getPtype(), self._layer:getAddr())
        if (protocolAddress == arpFrame:getTpa()) then
            self:send(from, ARPFrame(arpFrame:getHtype(), arpFrame:getPtype(), ARPFrame.OPERATION.REPLY, arpFrame:getSha(), arpFrame:getSpa(), to, arpFrame:getTpa()))
        end
    elseif (arpFrame:getOper() == arpConst.OPERATION.REPLY) then
        arpAPI.addCached(arpFrame:getHtype(), arpFrame:getPtype(), arpFrame:getTha(), arpFrame:getTpa())
    end
end

---Send the arp frame
---@param payload ARPFrame
function ARPLayer:send(dst, payload)
    if (dst == ethernet.MAC_NIL) then dst = ethernet.MAC_BROADCAST end
    local eFrame = ethernet.EthernetFrame(self._layer:getAddr(), dst, nil, self.layerType, payload:pack())
    self._layer:send(dst, eFrame)
end

return ARPLayer
