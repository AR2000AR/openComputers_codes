local class        = require("libClass2")
local NetworkLayer = require('network.abstract.NetworkLayer')


---@class DummyEthernet : NetworkLayer
---@operator call:DummyEthernet
local DummyEthernet = class(NetworkLayer)

function DummyEthernet:close() end

---Get the maximum size a ethernet frame can have
---@return number mtu
function DummyEthernet:mtu() return math.huge end

---Get the interface's mac address
---@return string uuid
function DummyEthernet:addr()
    return '00000000-0000-0000-0000-000000000000'
end

---Send a ethernet frame
---@param dst string
---@param eFrame EthernetFrame
function DummyEthernet:send(dst, eFrame)
end

return DummyEthernet
