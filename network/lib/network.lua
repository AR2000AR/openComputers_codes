local component       = require("component")
local ethernet        = require("layers.ethernet")
local arp             = require("layers.arp")
local ipv4            = require("layers.ipv4")
local icmp            = require("layers.icmp")
local routing         = require("routing")
local bit32           = require("bit32")

---@class InterfaceTypes
---@field ethernet EthernetInterface
---@field ip IPv4Layer
---@field icmp ICMPLayer

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
    --router
    networklib.router:setLayer(networklib.interfaces[addr].ip)
    networklib.router:addRoute({ network = 0, mask = 0, gateway = networklib.interfaces[addr].ip:getAddr(), metric = 100 })
    networklib.router:addRoute({ network = bit32.band(networklib.interfaces[addr].ip:getAddr(), networklib.interfaces[addr].ip:getMask()), mask = networklib.interfaces[addr].ip:getMask(), gateway = networklib.interfaces[addr].ip:getAddr(), metric = 0 })
    return true
end

function networklib.forgetInterface(addr)
    assert(addr, string.format("%s is not a known interface", addr))
    if (networklib.interfaces[addr]) then
        networklib.interfaces[addr].ethernet --[[@as EthernetInterface]]:close()
    end
    networklib.interfaces[addr] = nil
    arp.setLocalAddress(arp.HARDWARE_TYPE.ETHERNET, arp.PROTOCOLE_TYPE.IPv4, addr, nil)
end

return networklib
