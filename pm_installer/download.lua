local shell = require("shell")
local filesystem = require("filesystem")
local os = require("os")
local floppy = ''
local baseURL = 'https://github.com/AR2000AR/openComputers_codes/raw/master/'

local function wget(...)
    shell.execute(table.concat({"wget -f", ...}, " "))
end
local function mkdir(...)
    shell.execute(table.concat({"mkdir", ...}, " "))
end
local f = string.format
local function concatPath(...) return table.concat({...}, '/') end

local args, opts = shell.parse(...)
if (not filesystem.exists(args[1]) or not filesystem.isDirectory(args[1])) then
    print("No target for the installation disk creation")
    os.exit(1)
end
floppy = args[1]

mkdir(concatPath(floppy, 'bin'))
mkdir(concatPath(floppy, 'lib'))
local files = {
    ['pm_get/bin/pm-get.lua'] = 'bin/pm-get.lua',
    ['pm/bin/pm.lua'] = 'bin/pm.lua',
    ['pm/lib/pm.lua'] = 'lib/pm.lua',
    ['tar/lib/tar.lua'] = 'lib/tar.lua',
    ['pm_installer/floppy/.install'] = '.install',
    ['pm_installer/floppy/.prop'] = '.prop',
    ['packages/pm.tar'] = 'pm.tar',
    ['packages/pm_get.tar'] = 'pm_get.tar',
    ['packages/libtar.tar'] = 'libtar.tar',
}
for src, dst in pairs(files) do
    wget(concatPath(baseURL, src), concatPath(floppy, dst))
end
