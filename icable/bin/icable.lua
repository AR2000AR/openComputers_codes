local network     = require("network")
local ipv4address = require("network.ipv4.address")
local icable      = require('icable')
local shell       = require('shell')
local os          = require('os')
local term        = require("term")

if (network.interfaces['tun0']) then
    network.interfaces['tun0'].ethernet --[[@as IcableDataLayer]]:close()
end
local args, opts = shell.parse(...)
if (#args ~= 1 or opts.h) then
    print('icable [--c=][--p=][--u=][--k] CIDR')
    print('\t--c : Server address')
    print('\t--p : Server port')
    print('\t--u : Username')
    print('\t--k : Password')
    print('\tCIDR : Client address (eg : 10.0.0.1/8)')
    os.exit(0)
end
opts.c = opts.c or '127.0.0.1'
opts.p = opts.p or 4222
opts.p = assert(tonumber(opts.p))
if (not opts.u) then
    term.write("Username : ")
    opts.u = term.read({doBreak = false})
    if (opts.u == false or opts.u == "" or opts.u == nil) then
        os.exit(1)
    end
    term.write("\n")
end
if (not opts.k) then
    term.write("Username : ")
    opts.k = term.read({doBreak = false, pwchar = "*"})
    if (opts.k == false or opts.k == "" or opts.k == nil) then
        os.exit(1)
    end
    term.write("\n")
end

local interface, reason = icable.connect(opts.u, opts.k, opts.c, opts.p, ipv4address.fromCIDR(args[1]))
if (not interface) then
    print(reason)
else
    network.interfaces['tun0'] = interface
end
