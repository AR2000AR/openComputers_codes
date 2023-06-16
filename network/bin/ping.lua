local shell       = require("shell")
local event       = require("event")
local computer    = require("computer")
local os          = require("os")
local bit32       = require("bit32")
local network     = require("network")
local icmp        = require("network.icmp")
local ipv4Address = require("network.ipv4.address")
local dns         = require("socket.dns")

local args, opts  = shell.parse(...)

---=============================================================================
if (opts["help"] or opts["h"] or #args == 0) then
    print("ping [-W timeout] [-s packetsize] [-p padding] ip")
    os.exit()
end
---=============================================================================
for k, v in pairs(opts) do print(k, v) end
opts.W      = tonumber(opts.W) or 5
opts.s      = tonumber(opts.s) or 56
opts.p      = opts.p or "A"

--in case dns_common is not installed
local rawIP = args[1]
if (dns) then
    rawIP = assert(dns.toip(args[1]))
end

local targetIP = ipv4Address.fromString(assert(rawIP))
local route    = network.router:getRoute(targetIP)
if (not route) then
    print("No route to destination")
    os.exit(1)
end

local icmpInterface = network.icmp.getInterface()
assert(icmpInterface)


--=============================================================================
local run = true
local i = 0
local sentICMP = {}
--=============================================================================
local function ping()
    if (not run) then return end
    local param = string.unpack('>I', string.pack('>HH', 0, i))
    local icmpEcho = icmp.ICMPPacket(icmp.TYPE.ECHO_REQUEST, icmp.CODE.ECHO_REQUEST.Echo_request, param, string.rep(opts.p, math.floor(opts.s / #opts.p)))
    local sent, reason = pcall(icmpInterface.send, icmpInterface, targetIP, icmpEcho)
    local t = computer.uptime()
    if (sent) then
        sentICMP[param] = t
    else
        io.stderr:write(reason .. "\n")
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
                                 end, math.huge)
--=============================================================================
local icmpListener = event.listen("ICMP", function(eName, from, to, type, code, param, payload)
    local seq = bit32.extract(param, 8, 8)
    if (sentICMP[param]) then
        print(string.format("From %s\ticmp_seq=%d\t%.2f s", args[1], param, computer.uptime() - sentICMP[param]))
        sentICMP[param] = nil
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
--Main loop====================================================================
print(string.format("Ping %s (%s) from %s with %d bytes of data.", args[1], ipv4Address.tostring(targetIP), ipv4Address.tostring(route.interface:addr()), opts.s))
ping()
while run do
    os.sleep(0.1)
end
--event.cancel(timer)
event.cancel(timeoutTimer)
event.cancel(icmpListener)
