require("package").loaded.resolv = nil
local resolv                     = require("resolv")
local serialization              = require("serialization")
local shell                      = require("shell")
local dns                        = require("dns")
local ipv4Address                = require("network.ipv4").address

---@overload fun(ressourceRecord:DNSRessourceRecord)
local prettyprint                = {}
setmetatable(prettyprint, {
    ---@param ressourceRecord DNSRessourceRecord
    __call = function(self, ressourceRecord)
        if (self[ressourceRecord:getType()]) then
            self[ressourceRecord:getType()](ressourceRecord)
        else
            print(string.format("%s\t%s", ressourceRecord:getName(), ressourceRecord:getRdata()))
        end
    end
})

---@param ressourceRecord DNSRessourceRecord
prettyprint[dns.TYPE.A] = function(ressourceRecord)
    print(string.format("Name:\t%s", ressourceRecord:getName()))
    print(string.format("Address:\t%s", ipv4Address.tostring(ressourceRecord:getRdata())))
end
prettyprint[dns.TYPE.SOA] = function(ressourceRecord)
    print(ressourceRecord:getName())
    print(string.format("\torigin = %s", ressourceRecord:getRdata()[1]))
    print(string.format("\tmail addr = %s", ressourceRecord:getRdata()[2]))
    print(string.format("\tserial = %s", ressourceRecord:getRdata()[3]))
    print(string.format("\trefresh = %s", ressourceRecord:getRdata()[4]))
    print(string.format("\tretry = %s", ressourceRecord:getRdata()[5]))
    print(string.format("\texpire = %s", ressourceRecord:getRdata()[6]))
    print(string.format("\tminimum = %s", ressourceRecord:getRdata()[7]))
end

local args, opts = shell.parse(...)
opts.class = opts.class or "IN"
opts.type = opts.type or "A"

if (#args >= 1) then
    if (not args[1]:match("%.$")) then
        args[1] = args[1] .. "."
    end
    print(string.format("%s %s %s", args[1], opts.class, opts.type))
    local msg, reason = resolv.resolve(args[1], dns.CLASS[opts.class], dns.TYPE[opts.type])
    if (msg) then
        if (msg.header:getFlags():getRCODE() == dns.RCODE.NOERROR) then
            print(string.format("Answer(s) : %d\t Name server(s) : %d\t Additional : %d", msg.header:getAncount(), msg.header:getNscount(), msg.header:getArcount()))
            if (msg.header:getAncount() > 0) then
                if (msg.header:getFlags():getAA()) then
                    print("Authoritative answer :")
                else
                    print("Non authoritative answer :")
                end
                for _, answer in ipairs(msg.answer) do
                    ---@cast answer DNSRessourceRecord
                    prettyprint(answer)
                end
            end
        elseif (msg.header:getFlags():getRCODE() == dns.RCODE.NXDOMAIN) then
            print(string.format("Server can't find %s NXDOMAIN", args[1]))
        else
            print("ERROR")
            print(msg.header:getFlags():getRCODE())
        end
    else
        print(reason)
    end
end
