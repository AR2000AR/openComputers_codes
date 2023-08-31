local TCPSocket = require("socket.tcp")

return {
    udp = require("socket.udp"),
    ---Creates and returns an TCP master object. A master object can be transformed into a server object with the method listen (after a call to bind) or into a client object with the method connect. The only other method supported by a master object is the close method.
    ---
    ---In case of success, a new master object is returned. In case of error, nil is returned, followed by an error message.
    ---@return TCPSocket
    tcp = function() return TCPSocket() end,
    ---@type socketdns
    dns = select(2, pcall(require, "socket.dns"))
}
