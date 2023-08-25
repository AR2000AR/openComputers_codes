return {
    udp = require("socket.udp"),
    tcp = require("socket.tcp"),
    ---@type socketdns
    dns = select(2, pcall(require, "socket.dns"))
}
