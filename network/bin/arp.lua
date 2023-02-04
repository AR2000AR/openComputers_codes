local arp = require("layers.arp")
local ethernetType = require("layers.ethernet")
local ipv4 = require("layers.ipv4")

for k, v in pairs(arp.list(arp.HARDWARE_TYPE.ETHERNET, ethernetType.TYPE.IPv4)) do
    print(ipv4.address.tostring(v[1]), v[2])
end
