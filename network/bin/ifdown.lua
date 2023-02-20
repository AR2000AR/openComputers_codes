local ifconfig = require("ifconfig")
local shell = require("shell")

local args, opts = shell.parse(...)
local lv = ifconfig.logLevel
if (opts.v) then ifconfig.logLevel = ifconfig.logLevel + 1 end
if (opts.q) then ifconfig.logLevel = ifconfig.logLevel - 1 end
if (args[1]) then
    ifconfig.ifdown(args[1])
end
ifconfig.logLevel = lv
