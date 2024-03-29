local consts = require("network.ipv4.constantes")

---@class ipv4lib
local ipv4lib = {
    IPv4Layer    = require("network.ipv4.IPv4Layer"),
    IPv4Packet   = require("network.ipv4.IPv4Packet"),
    IPv4Router   = require("network.ipv4.IPv4Router"),
    IPv4Loopback = require("network.ipv4.IPv4Loopback"),
    address      = require("network.ipv4.address"),
    PROTOCOLS    = consts.PROTOCOLS
}


--=============================================================================

return ipv4lib
