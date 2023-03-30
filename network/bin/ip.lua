local networklib = require("network")
local ethernet   = require("network.ethernet")
local ipv4       = require("network.ipv4")
local shell      = require("shell")

local args, opts = shell.parse(...)


if (args[1] == "a") then
    local interfaces = networklib.getInterface()
    for mac, itf in pairs(interfaces) do
        print(mac:match("(%x+)"))
        print(string.format("\tMAC : %s MTU : %d", itf.ethernet:getAddr(), itf.ethernet:getMTU()))
        local ipLayer = itf.ethernet:getLayer(ethernet.TYPE.IPv4) --[[@as IPv4Layer]]
        print(string.format("\tIP : %s Mask : %s", ipv4.address.tostring(ipLayer:getAddr()), ipv4.address.tostring(ipLayer:getMask())))
    end
elseif (args[1] == "r") then
    local routes = networklib.router:listRoutes()
    for i, v in ipairs(routes) do
        ---@cast v Route
        print(string.format("%d : %-15s\t%-15s\t%-15s\tvia %s\t%d", i, ipv4.address.tostring(v.network), ipv4.address.tostring(v.mask), ipv4.address.tostring(v.gateway), ipv4.address.tostring(v.interface:getAddr()), v.metric or 0))
    end
end
