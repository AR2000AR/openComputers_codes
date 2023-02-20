local io        = require("io")
local fs        = require("filesystem")
local component = require("component")
local bit32     = require("bit32")
local network   = require("network")
local layers    = require("layers")


--=============================================================================
--CONSTANTES
local CONFIG_DIR = "/etc/network/"
local INTERFACES_FILE = CONFIG_DIR .. "interfaces"
local VALID_PARAM = {
    inet = {
        static = {
            address = true, gateway = true, metric = true, pointopoint = true, scope = true
        }
    }
}
--=============================================================================
--Global
---@class ifconfigLib
local ifconfig = {}
---@alias logLevel
--- | -1 error
--- | 0 msg
--- | 1 verbose
--DEBUG set the 0
---@type logLevel
ifconfig.logLevel = 1
--=============================================================================

---Log a message
---@param msg string
---@param level logLevel
local function log(msg, level)
    if (ifconfig.logLevel < level) then return end
    if (level == -1) then
        io.error():write(msg .. "\n")
    elseif (level == 0) then
        print(msg)
    elseif (level == 1) then
        print(msg)
    end
end
---log formmated text
---@param format string
---@param level logLevel
---@param ... string|number
local function flog(format, level, ...)
    log(string.format(format, ...), level)
end
--=============================================================================

---@class iInfo
---@field iName string
---@field iType string
---@field iMode string
---@field address? string
---@field gateway? string
---@field metric? string
---@field pointopoint? string
---@field scope? string

---Load the interfaces settings
---@param file? string the file to parse
---@return table<string,iInfo>,table<string,boolean>
function ifconfig.loadInterfaces(file)
    --#region functions definitions

    ---skip the current interface paragraph
    ---@param fileHandler file*
    local function skipInterface(fileHandler)
        local line
        repeat
            line = fileHandler:read("l")
        until line:match("^%w")
        fileHandler:seek("cur", #line + 1)
    end
    --#endregion

    --#region var init
    local readInterfaces = {}
    local autoInterface = {}
    --#endregion

    file = file or INTERFACES_FILE

    if (not fs.exists(file) or fs.isDirectory(file)) then
        flog("File %q does not exists", -1, file)
        return {}, {}
    end
    local fileHandler = io.open(file, "r")
    assert(fileHandler, "File " .. file .. " does not exists")


    local line = fileHandler:read("l")
    repeat
        if (line:match("^source")) then --SOURCE
            local extraFileName = line:match("^source (.*)$")
            --TODO : Handle glob pattern
            log("Including " .. extraFileName, 1)
            if (fs.exists(extraFileName) and not fs.isDirectory(extraFileName)) then
                for k, v in pairs(ifconfig.loadInterfaces(extraFileName)) do readInterfaces[k] = v end
            end
            line = fileHandler:read("l") --read the next line
        elseif (line:match("^auto")) then
            local iName = line:match("^auto%s+(%w+)")
            autoInterface[iName] = true
            line = fileHandler:read("l")
        elseif line:match("^iface") then --iface
            --read the iterface "title"
            local iName, iType, iMode = line:match("^iface (%w+) (%w+) (%w+)$")
            if (iName and iType and iMode) then --check valid interface
                flog("Found interface : %s", 1, iName)
                autoInterface[iName] = false or autoInterface[iName]
                line = fileHandler:read("l") --read next line
                if (not line) then break end -- reached eof
                while line and line:match("^%s+") do --while in the interface paragraph
                    local opt, arg = line:match("^%s+(%w+)%s+([%d%.]+/%d+)$") --get the option name and argument
                    flog("%s\t%s\t%s", 1, line, opt, arg)
                    if (VALID_PARAM[iType] ~= nil) then --known iType
                        if (VALID_PARAM[iType][iMode] ~= nil) then --known iMode
                            readInterfaces[iName] = readInterfaces[iName] or { iName = iName, iType = iType, iMode = iMode }
                            if (VALID_PARAM[iType][iMode][opt] == true) then
                                flog("Found option %q with argument %q", 1, opt, arg)
                                readInterfaces[iName][opt] = arg
                            else
                                flog("Invalid option : %s for %s %s %s", -1, opt, iName, iType, iMode)
                            end
                        else
                            flog("Invalid interface mode : %q", -1, iMode)
                            skipInterface(fileHandler)
                        end
                    else
                        flog("Invalid interface type : %q", -1, iType)
                        skipInterface(fileHandler)
                    end
                    line = fileHandler:read("l")
                end
            end
        end
    until not line

    fileHandler:close()
    return readInterfaces, autoInterface
end

--=============================================================================
---Find a interface in the config
---@param iName string
---@return iInfo|boolean
function ifconfig.findInterface(iName)
    local interfaces = ifconfig.loadInterfaces(INTERFACES_FILE)
    if (interfaces[iName]) then return interfaces[iName] end

    ---@diagnostic disable-next-line: cast-local-type
    iName = component.get(iName, "modem")
    if (not iName) then return false end
    ---@cast iName - nil
    for k, v in pairs(interfaces) do
        if (component.get(k, "modem") == iName) then
            return v
        end
    end

    return false
end

--=============================================================================
---@param iName string
function ifconfig.ifup(iName)
    local interface = ifconfig.findInterface(iName)
    if (not interface) then
        flog("No such interface : %s", -1, iName)
        return false
    end
    ---@cast interface - boolean

    --setup the interface
    if (interface.iType == "inet") then --ipv4
        if (interface.iMode == "static") then
            if (network.interfaces[iName]) then
                flog("Interface %q is already up", -1, iName)
                return false
            end
            flog("Setting up %s", 1, interface.iName)
            ---@diagnostic disable-next-line: cast-local-type
            iName = component.get(iName, "modem")
            if (not iName) then
                flog("Cannot find a modem component for %q", -1, iName)
                return false
            end
            ---@cast iName - nil
            network.interfaces[iName] = {}
            --ethernet
            network.interfaces[iName].ethernet = layers.ethernet.EthernetInterface(component.proxy(iName))
            --ip
            local address, mask = layers.ipv4.address.fromCIDR(interface.address)
            network.interfaces[iName].ip = layers.ipv4.IPv4Layer(network.interfaces[iName].ethernet, address, mask)
            --icmp
            network.interfaces[iName].icmp = layers.icmp.ICMPLayer(network.interfaces[iName].ip)
            --udp
            network.interfaces[iName].udp = layers.udp.UDPLayer(network.interfaces[iName].ip)
            --router
            network.router:setLayer(network.interfaces[iName].ip)
            network.router:addRoute({ network = 0, mask = 0, gateway = network.interfaces[iName].ip:getAddr(), metric = tonumber(interface.metric) or 100 })
            network.router:addRoute({ network = bit32.band(network.interfaces[iName].ip:getAddr(), network.interfaces[iName].ip:getMask()), mask = network.interfaces[iName].ip:getMask(), gateway = network.interfaces[iName].ip:getAddr(), metric = 0 })

            return true
        else
            flog("Unknown interface mode %s for type %s", -1, interface.iMode, interface.iType)
        end
    else
        flog("Unknown interface type %s", -1, interface.iType)
    end
end

--=============================================================================
function ifconfig.autoIfup(iName)
    local _, auto = ifconfig.loadInterfaces(INTERFACES_FILE)
    local interface = ifconfig.findInterface(iName)
    if (not interface) then return false end
    iName = interface.iName
    if (auto[iName] or auto[component.get(iName, "modem")]) then
        return ifconfig.ifup(iName)
    end
end

--=============================================================================
---@param iName string
function ifconfig.ifdown(iName)
    local interface = ifconfig.findInterface(iName)
    if (not interface) then
        flog("No such interface : %s", -1, iName)
        return false
    end
    ---@cast interface - boolean

    local name = iName
    ---@diagnostic disable-next-line: cast-local-type
    iName = component.get(iName, "modem")

    if (network.interfaces[iName]) then
        error("NOT YET IMPLEMENTED", 2)
        --TODO remove routes
    else
        flog("Interface %q is not up", 0, name)
    end
end

--=============================================================================
return ifconfig
