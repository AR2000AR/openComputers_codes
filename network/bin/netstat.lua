local network     = require("network")
local ipv4Address = require("network.ipv4").address

--=============================================================================

for _, info in pairs(network.udp:getInterface():getOpenPorts()) do
    print(string.format("UDP\t%s:%s\t%s:%s", ipv4Address.tostring(info.loc.address):gsub("0.0.0.0", "*"), info.loc.port ~= 0 and info.loc.port or "*", ipv4Address.tostring(info.rem.address):gsub("0.0.0.0", "*"), info.rem.port ~= 0 and info.rem.port or "*"))
end
for _, info in pairs(network.tcp:getInterface():getOpenPorts()) do
    print(string.format("TCP\t%s:%s\t%s:%s\t%s", ipv4Address.tostring(info.loc.address):gsub("0.0.0.0", "*"), info.loc.port ~= 0 and info.loc.port or "*", ipv4Address.tostring(info.rem.address):gsub("0.0.0.0", "*"), info.rem.port ~= 0 and info.rem.port or "*", info.state))
end
