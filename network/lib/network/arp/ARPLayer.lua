local ethernet = require("network.ethernet")
local ARPFrame = require("network.arp.ARPFrame")
local arpConst = require("network.arp.constantes")
local arpAPI   = require("network.arp.api")
local NetworkLayer = require('network.abstract.NetworkLayer')
local class    = require("libClass2")


---@class ARPLayer : NetworkLayer
local ARPLayer = class(NetworkLayer)
---@type ethernetType
ARPLayer.layerType = ethernet.TYPE.ARP

---@param osiLayer NetworkLayer
---@return ARPLayer
function ARPLayer:new(osiLayer)
    local o = self.parent()
    setmetatable(o, {__index = self})
    ---@cast o ARPLayer
    o:layer(osiLayer)
    return o
end

function ARPLayer:addr()
    return self:layer():addr()
end

function ARPLayer:mtu()
    return 0
end

---Handle the payload from the layer under
---@param from string
---@param to string
---@param payload string
function ARPLayer:payloadHandler(from, to, payload)
    local arpFrame = ARPFrame.unpack(payload)
    if (arpFrame:oper() == arpConst.OPERATION.REQUEST) then
        local protocolAddress = arpAPI.getLocalAddress(arpFrame:htype(), arpFrame:ptype(), self:layer():addr())
        if (protocolAddress == arpFrame:tpa()) then
            self:send(from, ARPFrame(arpFrame:htype(), arpFrame:ptype(), ARPFrame.OPERATION.REPLY, arpFrame:sha(), arpFrame:spa(), to, arpFrame:tpa()))
        end
    elseif (arpFrame:oper() == arpConst.OPERATION.REPLY) then
        arpAPI.addCached(arpFrame:htype(), arpFrame:ptype(), arpFrame:tha(), arpFrame:tpa())
    end
end

---Send the arp frame
---@param payload ARPFrame
function ARPLayer:send(dst, payload)
    if (dst == ethernet.MAC_NIL) then dst = ethernet.MAC_BROADCAST end
    local eFrame = ethernet.EthernetFrame(self:layer():addr(), dst, nil, self.layerType, payload:pack())
    self:layer():send(dst, eFrame)
end

return ARPLayer
