local TCPSocket = require("socket.tcp")
local UDPSocket = require("socket.udp")

return {
    udp = UDPSocket,
    tcp = TCPSocket,
    ---@type socketdns
    dns = select(2, pcall(require, "socket.dns"))
}
