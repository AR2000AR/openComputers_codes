local fs = require "filesystem"
local shell = require "shell"
local crypttool = require "crypttool"
local data = require("component").data
local os = require("os")

local args, opt = shell.parse(...)

if (#args ~= 2) then
    os.exit(1)
end
if (fs.isDirectory(args[1])) then
    local proxy = crypttool.Proxy.new(args[1], data.md5(args[2]))
    fs.umount(args[1])
    fs.mount(proxy, args[1])
end
