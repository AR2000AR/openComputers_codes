local network     = require("network")
local ipv4address = require("network.ipv4.address")
local icable      = require('icable')
local shell       = require('shell')
local os          = require('os')

if (network.interfaces['tun0']) then
    network.interfaces['tun0'].ethernet --[[@as IcableDataLayer]]:close()
end
local args, opts = shell.parse(...)
if (#args ~= 1 or opts.h) then
    print('icable [-c=][-p=] CIDR')
    print('\t-c : Server address')
    print('\t-p : Server port')
    print('\tCIDR : Client address (eg : 10.0.0.1/8)')
    os.exit(0)
end
if (opts.c == true) then opts.c = nil end
if (opts.p == true) then opts.p = nil end
if (opts.p) then opts.p = tonumber(opts.p) end
local interface, reason = icable.connect('admin', 'admin', opts.c or '127.0.0.1', opts.p, ipv4address.fromCIDR(args[1]))
if (not interface) then
    print(reason)
else
    network.interfaces['tun0'] = interface
end
