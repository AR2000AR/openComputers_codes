---@diagnostic disable: undefined-global
local serial = require "serialization"
local unicode = require "unicode"
local fs = require "filesystem"
local event = require "event"

local tArgs = {...}
local ipackages = {} -- installed packages
local rpath = tArgs[1] or install.from
local tpath = tArgs[2] or install.to
if tpath == "//" then
    tpath = "/usr/"
end

tpath, rpath = fs.canonical(tpath), fs.canonical(rpath)

local fobj = io.open(rpath .. "/master/programs.cfg", "rb") -- read packages list from floppy
if not fobj then
    error("installer disk not properly configured")
end
local packages = serial.unserialize(fobj:read("*a"))
fobj:close()

local function ripackages()
    local fobj = io.open("/etc/opdata.svd", "rb") -- attempt to read installed packages
    if fobj then
        ipackages = serial.unserialize(fobj:read("*a"))
        fobj:close()
    end
end

ripackages()

local function wipackages()
    local fobj = io.open("/etc/opdata.svd", "wb") -- attempt to read installed packages
    if fobj then
        fobj:write(serial.serialize(ipackages))
        fobj:close()
    end
end

local pkgmap = {} -- alphabetically sorted list of package names
for k, v in pairs(packages) do
    pkgmap[#pkgmap+1] = k
end
table.sort(pkgmap)

local function clear()
    io.write("\27[2J\27[H")
end

local function info(pkg) -- shows info for pkg
    clear()
    local fh = io.popen("less", "w")
    assert(fh, "could not start less")
    local function print(str)
        fh:write(str .. "\n")
    end

    print(string.format("%s - %s", pkg, packages[pkg].name))
    print(packages[pkg].description)
    if packages[pkg].files then
        print("\nFiles:")
        for k, v in pairs(packages[pkg].files) do
            print(string.format("%s -> %s", k, v))
        end
    end
    if packages[pkg].dependencies then
        print("\nDependencies")
        for k, v in pairs(packages[pkg].dependencies) do
            print(" - " .. k)
        end
    end
    fh:close()
end

local preamble = false
local fobj = io.open(rpath .. "/.info", "rb") -- read the pre-inst screen
if fobj then
    preamble = fobj:read("*a")
    fobj:close()
end

if preamble then -- display pre-inst screen
    clear()
    if install.label then
        print(install.label .. " installer")
    end
    print(preamble)
    print("Press any key to continue.")
    event.pull("key_down")
end

local mx, my = require("term").getViewport()
local selected, start = 1, 1

local function drawmenu() -- draw the menu display - nothing but text and VT100 escape codes
    local infostring = string.format("[%s][%s]%s", unicode.char(0x2191), unicode.char(0x2193), " Move [Space] (De)select [i] More Info [q] Quit [Enter] Confirm")
    clear()
    io.write(string.format("\27[%d;1H%s\27[H", my, infostring))
    local workingSpace = my - math.ceil(infostring:len() / mx) - 1
    if install.label then
        print(install.label .. " installer")
        workingSpace = workingSpace - 1
    end
    if  selected > start + workingSpace - 3 then
        start = math.min(start + 3, #pkgmap - workingSpace)
    elseif selected < start + 3 then
        start = math.max(start - 3, 1)
    end
    for k = start, math.min(#pkgmap, start + workingSpace) do
        local v = pkgmap[k]
        if k == selected then
            io.write("\27[30;47m")
        end
        if packages[v].selected then
            io.write(" " .. unicode.char(0x25A0) .. " ")
        else
            io.write(" " .. unicode.char(0x25A1) .. " ")
        end
        io.write(v)
        print("\27[0m")
    end
end

--[[
Key codes:
0 208 down
0 200 up
13 28 enter
32 57 space
105 23 i
113 16 q
121 21 y
]] --

local run, install = true, true
while run do -- menu loop
    drawmenu()
    local _, _, ch, co = event.pull("key_down")
    if  ch == 13 and co == 28 then
        run = false
    elseif ch == 113 and co == 16 then
        run = false
        install = false
    elseif ch == 105 and co == 23 then
        info(pkgmap[selected])
    elseif ch == 0 and co == 208 then
        selected = selected + 1
        if selected > #pkgmap then
            selected = #pkgmap
        end
    elseif ch == 0 and co == 200 then
        selected = selected - 1
        if selected < 1 then
            selected = 1
        end
    elseif ch == 32 and co == 57 then
        packages[pkgmap[selected]].selected = not packages[pkgmap[selected]].selected
    end
end

clear()

if not install then -- pressed q
    print("Aborted.")
    return
end

local toinstall, postinstall = {}, {} -- table of commands to run after installation

print("Resolving dependencies...") -- build a table of what to install
for k, v in pairs(packages) do
    if v.selected then
        toinstall[k] = true
        if v.dependencies then
            for l, m in pairs(v.dependencies) do -- including dependencies
                if not toinstall[l] then
                    print("Package " .. k .. " depends on " .. l)
                    toinstall[l] = m
                end
            end
        end
    end
end

print("You have selected to install the following packages to " .. tpath .. ":")
for k, v in pairs(toinstall) do
    print(" - " .. k)
end
print("Continue? [y/N] ")
local _, _, _, co = event.pull("key_down")
if co ~= 21 then -- confirm they want the packages installed
    print("Aborted.")
    return
end

local function install(pkg, where) -- installs a package, pkg, to where
    where = where or tpath
    if type(where) ~= string then where = tpath end
    print("Installing " .. pkg .. "...")
    if packages[pkg] then
        ipackages[pkg] = {}
        print("Copying files...")
        for l, m in pairs(packages[pkg].files) do
            local lseg = fs.segments(l)
            local op = ""
            if     (l:sub(1, 1) == ":") then
                l = l:sub(2)
                op = "-r "
                m = m .. "/"
                l = l .. "/*"
            elseif (l:sub(1, 1) == "?") then
                l = l:sub(2)
                op = "-n "
            end
            if m:sub(1, 2) ~= "//" then
                if not fs.exists(fs.canonical(where .. "/" .. m)) then
                    os.execute("mkdir " .. fs.canonical(where .. "/" .. m))
                end
                if l:sub(1, 4) == "http" then
                    os.execute("cp -v " .. op .. rpath .. "/external/" .. l:match(".+/(.+)") .. " " .. fs.canonical(where .. "/" .. m))
                else
                    os.execute("cp -v " .. op .. rpath .. "/" .. l .. " " .. fs.canonical(where .. "/" .. m))
                end
                ipackages[pkg][l] = fs.canonical(where .. "/" .. m) .. "/" .. lseg[#lseg]
            else
                if not fs.exists(fs.canonical(m:sub(2))) then
                    os.execute("mkdir " .. fs.canonical(m:sub(2)))
                end
                if l:sub(1, 4) == "http" then
                    os.execute("cp -v " .. op .. rpath .. "/external/" .. l:match(".+/(.+)") .. " " .. fs.canonical(m))
                else
                    os.execute("cp -v " .. op .. rpath .. "/" .. l .. " " .. fs.canonical(m))
                end
                ipackages[pkg][l] = fs.canonical(m:sub(2)) .. "/" .. lseg[#lseg]
            end
        end
        if packages[pkg].postinstall then
            for k, v in pairs(packages[pkg].postinstall) do
                postinstall[#postinstall+1] = v
            end
        end
    else
        print("Package not on disk. Attempting to install via oppm.")
        print("oppm install " .. pkg .. " " .. where)
        wipackages()
        os.execute("oppm install " .. pkg .. " " .. where)
        ripackages()
    end
    wipackages()
end

for k, v in pairs(toinstall) do
    install(k, v)
end

if #postinstall > 0 then
    print("Running post-install commands...")
    for k, v in pairs(postinstall) do
        print(v)
        os.execute(v)
    end
end
