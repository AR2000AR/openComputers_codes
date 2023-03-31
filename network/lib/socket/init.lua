return {
    udp = require("socket.udp"),
    ---@type socketdns
    dns = select(2, pcall(require, "socket.dns"))
}
