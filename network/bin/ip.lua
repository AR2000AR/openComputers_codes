local networklib = require("network")
local ipv4       = require("network.ipv4")
local shell      = require("shell")

local args, opts = shell.parse(...)


if (args[1] == "a") then
    local interfaces = networklib.getInterface()
    for interfaceName, itf in pairs(interfaces) do
        print(interfaceName:match("(%w+)"))
        if (itf.ethernet) then
            ---@type number|string
            local mtu = itf.ethernet:mtu()
            if (mtu == math.huge) then mtu = 'math.huge' else mtu = string.format("%d", mtu) end
            print(string.format("\tMAC : %s MTU : %s", itf.ethernet:addr(), mtu))
        end
        if (itf.ip and itf.ip:addr()) then
            print(string.format("\tIP : %s Mask : %s", ipv4.address.tostring(itf.ip:addr()), ipv4.address.tostring(itf.ip:mask())))
        end
    end
elseif (args[1] == "r") then
    if (args[2] == nil or args[2] == 'list') then
        local routes = networklib.router:listRoutes()
        for i, v in ipairs(routes) do
            ---@cast v Route
            print(string.format("%d : %-15s\t%-15s\t%-15s\tvia %s\t%d", i, ipv4.address.tostring(v.network), ipv4.address.tostring(v.mask), ipv4.address.tostring(v.gateway), ipv4.address.tostring(v.interface:addr()), v.metric or 0))
        end
    elseif (args[2] == 'add') then
        if (not args[3]) then
            print('Missing network name'); os.exit(1)
        end
        if (not args[4]) then
            print('Missing network mask'); os.exit(1)
        end
        if (not args[5]) then
            print('Missing network gateway'); os.exit(1)
        end
        if (not args[6]) then
            print('Missing network interface'); os.exit(1)
        end
        local nname = ipv4.address.fromString(args[3])
        local nmask = ipv4.address.fromString(args[4])
        local gateway = ipv4.address.fromString(args[5])
        local interface = ipv4.address.fromString(args[6])
        local ipInterface = networklib.router:getRoute(interface).interface
        networklib.router:addRoute({network = nname, mask = nmask, gateway = gateway, metric = 0, interface = ipInterface})
    end
end
