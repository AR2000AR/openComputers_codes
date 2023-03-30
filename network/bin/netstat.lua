local network     = require("network")
local ipv4Address = require("network.ipv4").address

--=============================================================================

for _, info in pairs(network.udp:getInterface():getOpenPorts()) do
    print(string.format("UDP\t%s:%d\t%s:%d", ipv4Address.tostring(info.loc.address), info.loc.port, ipv4Address.tostring(info.rem.address), info.rem.port))
end
