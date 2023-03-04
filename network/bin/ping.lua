local shell        = require("shell")
local event        = require("event")
local computer     = require("computer")
local os           = require("os")
local bit32        = require("bit32")
local network      = require("network")
local ethernetType = require("layers.ethernet").TYPE
local icmp         = require("layers.icmp")
local ipv4         = require("layers.ipv4")
local arp          = require("layers.arp")

local args, opts   = shell.parse(...)

---=============================================================================
if (opts["help"] or opts["h"] or #args == 0) then
    print("ping [-W timeout] ip")
    os.exit()
end
---=============================================================================
opts["W"]      = opts["W"] or 10

local targetIP = ipv4.address.fromString(args[1])
local route    = network.router:getRoute(targetIP)
if (not route) then
    print("No route to destination")
    os.exit(1)
end
local localMac = arp.getLocalHardwareAddress(arp.HARDWARE_TYPE.ETHERNET, ethernetType.IPv4, route.interface:getAddr()) --[[@as string]]
if (not localMac) then
    print("No interface for route")
    os.exit(1)
end


local icmpInterface = network.interfaces[localMac].icmp
assert(icmpInterface)


--=============================================================================
local run = true
local i = 0
local sentICMP = {}
--=============================================================================
local function ping()
    if (not run) then return end
    local param = bit32.lshift(i, 8) + 0
    local icmpEcho = icmp.ICMPPacket(icmp.TYPE.ECHO_REQUEST, icmp.CODE.ECHO_REQUEST.Echo_request, param, "hi")
    local sent, reason = pcall(icmpInterface.send, icmpInterface, targetIP, icmpEcho)
    local t = computer.uptime()
    if (sent) then
        sentICMP[i] = t
    else
        print(reason)
        os.sleep(1)
        ping()
    end
    i = i + 1
end
--local timer = event.timer(2, ping, math.huge)
--=============================================================================

local timeoutTimer = event.timer(0.1, function()
    for seq, v in pairs(sentICMP) do
        if v and computer.uptime() - v > opts["W"] then
            print(string.format("Timeout\ticmp_seq=%d\t(%d s)", seq, opts["W"]))
            sentICMP[seq] = false
            ping()
            break
        end
    end
end,                             math.huge)
--=============================================================================
local icmpListener = event.listen("ICMP", function(eName, from, to, type, code, param, payload)
    local seq = bit32.extract(param, 8, 8)
    if (sentICMP[seq]) then
        print(string.format("From %s\ticmp_seq=%d\t%.2f s", args[1], seq, computer.uptime() - sentICMP[seq]))
        sentICMP[seq] = nil
    end
    ping()
end) --[[@as number]]
--=============================================================================
event.listen("interrupted", function(...)
    --event.cancel(timer)
    event.cancel(timeoutTimer)
    event.cancel(icmpListener)
    run = false
    return false
end)
---Main loop===================================================================
print(string.format("Ping %s from %s", args[1], ipv4.address.tostring(route.interface:getAddr())))
print(string.format("Using route %s", ipv4.address.tostring(route.network)))
ping()
while run do
    os.sleep(0.1)
end
--event.cancel(timer)
event.cancel(timeoutTimer)
event.cancel(icmpListener)
