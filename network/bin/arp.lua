local arp = require("network.arp")
local ethernetType = require("network.ethernet").TYPE
local ipv4 = require("network.ipv4")

for k, v in pairs(arp.list(arp.HARDWARE_TYPE.ETHERNET, ethernetType.IPv4)) do
    print(ipv4.address.tostring(v[1]), v[2])
end
