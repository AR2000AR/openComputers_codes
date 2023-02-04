local icmp    = require("layers.icmp")
local network = require("network")
local modem   = require("component").modem.address
local ipv4    = require("layers.ipv4")
local event   = require("event")

local icmpEcho = icmp.ICMPPacket(icmp.TYPE.ECHO_REQUEST, icmp.CODE.ECHO_REQUEST.Echo_request, 0, "hi")
local icmpInterface = network.interfaces[modem].icmp --[[@as ICMPLayer]]
assert(icmpInterface)
icmpInterface:send(ipv4.address.fromString("192.168.1.2"), icmpEcho)
local e = event.pull(2, "ICMP", icmp.TYPE.ECHO_REPLY)
if (e) then print("pong") end
