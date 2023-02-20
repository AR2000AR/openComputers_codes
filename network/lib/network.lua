local component       = require("component")
local routing         = require("routing")

---@class InterfaceTypes
---@field ethernet EthernetInterface
---@field ip IPv4Layer
---@field icmp ICMPLayer
---@field udp UDPLayer

---@class networklib
local networklib      = {}
networklib.internal   = {}
---@type table<string,InterfaceTypes>
networklib.interfaces = {}
---@type IPv4Router
networklib.router     = routing.IPv4Router()

---Get the configured interfaces
---@param filter string
---@return table<string,OSIDataLayer>
---@overload fun():table<string,table<string,OSILayer>>
---@
function networklib.getInterface(filter)
    checkArg(1, filter, "string", "nil")
    if (filter) then return { networklib.interfaces.ethernet[component.get(filter, "modem")] or nil } end
    return networklib.interfaces
end

return networklib
