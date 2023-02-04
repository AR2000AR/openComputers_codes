local component = require("component")
local ethernet  = require("layers.ethernet")
local arp       = require("layers.arp")
local ipv4      = require("layers.ipv4")
local icmp      = require("layers.icmp")


---@class networklib
local networklib = {}
networklib.internal = {}
---@type table<string,table<string,OSILayer>>
networklib.interfaces = {}

---Get the configured interfaces
---@param filter string
---@return table<string,OSIDataLayer>
---@overload fun():table<string,table<string,OSILayer>>
function networklib.getInterface(filter)
    checkArg(1, filter, "string", "nil")
    if (filter) then return {networklib.interfaces.ethernet[component.get(filter, "modem")] or nil} end
    return networklib.interfaces
end

function networklib.registerInterface(addr)
    if (networklib.interfaces[addr]) then return false end
    addr = component.get(addr, "modem")
    assert(addr, string.format("%s is not a known interface", addr))
    networklib.interfaces[addr] = {}
    --ethernet
    networklib.interfaces[addr].ethernet = ethernet.EthernetInterface(component.proxy(addr))
    --ip
    networklib.interfaces[addr].ip = ipv4.IPv4Layer(networklib.interfaces[addr].ethernet, "192.168.1.1", "255.255.255.0")
    --icmp
    networklib.interfaces[addr].icmp = icmp.ICMPLayer(networklib.interfaces[addr].ip)
    return true
end

function networklib.forgetInterface(addr)
    assert(addr, string.format("%s is not a known interface", addr))
    if (networklib.interfaces[addr]) then
        networklib.interfaces[addr].ethernet--[[@as EthernetInterface]] :close()
    end
    networklib.interfaces[addr] = nil
    arp.setLocalAddress(arp.HARDWARE_TYPE.ETHERNET, arp.PROTOCOLE_TYPE.IPv4, addr, nil)
end

return networklib
