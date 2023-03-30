local icmpConst  = require("network.icmp.constantes")
local ICMPLayer  = require("network.icmp.ICMPLayer")
local ICMPPacket = require("network.icmp.ICMPPacket")

---@class icmpLib
local icmp       = {
    ICMPLayer = ICMPLayer,
    ICMPPacket = ICMPPacket,
    CODE = icmpConst.CODE,
    TYPE = icmpConst.TYPE
}

return icmp
