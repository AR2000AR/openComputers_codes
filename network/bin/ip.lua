local networklib = require("network")
local ethernet = require("layers.ethernet")
local ipv4 = require("layers.ipv4")

local interfaces = networklib.getInterface()

for mac, itf in pairs(interfaces) do
    itf = itf.ethernet --[[@as EthernetInterface]]
    print(mac:match("(%x+)"))
    print(string.format("\tMAC : %s MTU : %d", itf:getAddr(), itf:getMTU()))
    local ipLayer = itf:getLayer(ethernet.TYPE.IPv4) --[[@as IPv4Layer]]
    print(string.format("\tIP : %s Mask : %s", ipv4.address.tostring(ipLayer:getAddr()), ipv4.address.tostring(ipLayer:getMask())))
end
