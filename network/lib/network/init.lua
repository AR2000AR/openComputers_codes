local component       = require("component")
local IPv4Router      = require("network.ipv4.IPv4Router")

---@class InterfaceTypes
---@field ethernet EthernetInterface
---@field ip IPv4Layer

---@class networklib
local networklib      = {}
networklib.internal   = {
    ---@type UDPLayer
    udp = nil,
    ---@type ICMPLayer
    icmp = nil
}
---@type table<string,InterfaceTypes>
networklib.interfaces = {}
---@type IPv4Router
networklib.router     = IPv4Router()

---Get the configured interfaces
---@param filter string
---@return InterfaceTypes
---@overload fun():table<string,InterfaceTypes>
function networklib.getInterface(filter)
    checkArg(1, filter, "string", "nil")
    if (filter) then return {networklib.interfaces[component.get(filter, "modem")] or nil} end
    return networklib.interfaces
end

---Get the primary interface if set
---@return InterfaceTypes
function networklib.getPrimaryInterface()
    return networklib.getInterface(component.getPrimary("modem").address)[1]
end

--=============================================================================
--#region udp

networklib.udp = {}

function networklib.udp.getInterface()
    return networklib.internal.udp
end

--#endregion
--=============================================================================
--#region icmp

networklib.icmp = {}

---@return ICMPLayer
function networklib.icmp.getInterface()
    return networklib.internal.icmp
end

--#endregion

return networklib
