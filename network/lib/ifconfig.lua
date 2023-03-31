local io        = require("io")
local fs        = require("filesystem")
local component = require("component")
local computer  = require("computer")
local network   = require("network")
local icmp      = require("network.icmp")
local ipv4      = require("network.ipv4")
local udp       = require("network.udp")
local ethernet  = require("network.ethernet")


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
--- | 2 debug
---@type logLevel
ifconfig.logLevel = 0
--avoid cluttering the sdtout
ifconfig.err = "/tmp/ifconfig.out"
ifconfig.out = ifconfig.err
--=============================================================================

---Log a message
---@param msg string
---@param level logLevel
local function log(msg, level)
    msg = string.format("[%.2f] %s", computer.uptime(), msg)
    if (ifconfig.logLevel < level) then return end
    if (level == -1) then
        io.open(ifconfig.err, "a"):write(msg .. "\n"):close()
    else
        io.open(ifconfig.out, "a"):write(msg .. "\n"):close()
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
--init the interfaces during first import. Since the lib is imported in /boot/30_network.lua, it is done during system boot
if (not network.internal.icmp) then
    network.internal.icmp = icmp.ICMPLayer(network.router)
    network.router:setProtocol(network.internal.icmp)
end
if (not network.interfaces.udp) then
    network.internal.udp = udp.UDPLayer(network.router)
    network.router:setProtocol(network.internal.udp)
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
---@param file? string the file to parse Default to /etc/network/interfaces
---@return table<string,iInfo> interfaces,table<string,boolean> autoInterface
function ifconfig.loadInterfaces(file)
    --#region functions definitions

    ---read the next line, removing any comments
    ---@param fileHandler file*
    ---@return string?
    local function readNextLine(fileHandler)
        local line = fileHandler:read("l")
        if (line) then
            return line:match("^[^#]*")
        else
            return line
        end
    end

    ---skip the current interface paragraph
    ---@param fileHandler file*
    local function skipInterface(fileHandler)
        local line
        repeat
            line = fileHandler:read("l")
        until line:match("^%w") or not line
        if (line) then
            fileHandler:seek("cur", #line + 1)
        end
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

    local line = readNextLine(fileHandler)
    if (not line) then
        fileHandler:close()
        return {}, {}
    end
    repeat
        if (line:match("^source")) then --SOURCE
            local extraFileName = line:match("^source (.*)$")
            flog("Found source %s", 1, extraFileName)
            extraFileName = extraFileName:gsub("*", ".*")
            extraFileName = extraFileName:gsub("?", ".")
            if (extraFileName:match("%*")) then
                local path = fs.path(extraFileName)
                local name = fs.name(extraFileName)
                flog("Listing sources in %s", 1, path)
                for fileName in fs.list(path) do
                    flog("Found file %s", 1, fileName)
                    if (fileName:match(name)) then
                        if (fs.exists(path .. fileName) and not fs.isDirectory(path .. fileName)) then
                            log("Including " .. path .. fileName, 1)
                            local itf, auto = ifconfig.loadInterfaces(path .. fileName)
                            for k, v in pairs(itf) do readInterfaces[k] = v end
                            for k, v in pairs(auto) do autoInterface[k] = v end
                        end
                    end
                end
            else
                if (fs.exists(extraFileName) and not fs.isDirectory(extraFileName)) then
                    log("Including " .. extraFileName, 1)
                    for k, v in pairs(ifconfig.loadInterfaces(extraFileName)) do readInterfaces[k] = v end
                end
            end
            line = readNextLine(fileHandler) --read the next line
        elseif (line:match("^auto")) then
            local iName = line:match("^auto%s+(%w+)")
            autoInterface[iName] = true
            line = readNextLine(fileHandler)
        elseif line:match("^iface") then --iface
            --read the iterface "title"
            local iName, iType, iMode = line:match("^iface (%w+) (%w+) (%w+)$")
            if (iName and iType and iMode) then --check valid interface
                flog("Found interface : %s", 1, iName)
                autoInterface[iName] = false or autoInterface[iName]
                line = readNextLine(fileHandler)                      --read next line
                if (not line) then break end                          -- reached eof
                while line and line:match("^%s+") do                  --while in the interface paragraph
                    flog("\tCurrent line : %q", 2, line)
                    local opt, arg = line:match("^%s+(%w+)%s+(%g+)$") --get the option name and argument
                    if (VALID_PARAM[iType] ~= nil) then               --known iType
                        if (VALID_PARAM[iType][iMode] ~= nil) then    --known iMode
                            readInterfaces[iName] = readInterfaces[iName] or {iName = iName, iType = iType, iMode = iMode}
                            if (VALID_PARAM[iType][iMode][opt] == true) then
                                flog("\tFound option %q with argument %q", 1, opt, arg)
                                readInterfaces[iName][opt] = arg
                            else
                                flog("\tInvalid option : %s for %s %s %s", -1, opt, iName, iType, iMode)
                            end
                        else
                            flog("Invalid interface mode : %q", -1, iMode)
                            skipInterface(fileHandler)
                        end
                    else
                        flog("Invalid interface type : %q", -1, iType)
                        skipInterface(fileHandler)
                    end
                    line = readNextLine(fileHandler)
                end
            end
        else
            line = readNextLine(fileHandler)
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
    iName = component.get(iName, "modem") or iName
    if (not iName) then return false end
    ---@cast iName - nil
    for k, v in pairs(interfaces) do
        if (iName:match("^" .. k)) then
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

            --#region find component from interface name
            local modem
            if (iName:match("^eth%d$")) then
                local compId = tonumber(iName:match("%d"))
                for modemCard in component.list("modem") do
                    local proxy = component.proxy(modemCard)
                    if proxy.slot == tonumber(compId) then
                        modem = proxy
                    end
                end
                if (not modem) then
                    flog("Cannot find a modem component for %q", -1, iName)
                    return false
                end
            else
                ---@diagnostic disable-next-line: cast-local-type
                iName = component.get(iName, "modem")
                if (not iName) then
                    flog("Cannot find a modem component for %q", -1, iName)
                    return false
                end
                modem = component.proxy(iName)
            end
            --#endregion

            ---@cast iName - nil
            network.interfaces[iName] = {}
            --ethernet
            network.interfaces[iName].ethernet = ethernet.EthernetInterface(modem)
            --ip
            local address, mask = ipv4.address.fromCIDR(interface.address)
            network.interfaces[iName].ip = ipv4.IPv4Layer(network.interfaces[iName].ethernet, network.router, address, mask)
            --router
            if (interface.gateway) then
                network.router:addRoute({interface = network.interfaces[iName].ip, network = 0, mask = 0, gateway = ipv4.address.fromString(interface.gateway), metric = tonumber(interface.metric) or 100})
            end

            return true
        else
            flog("Unknown interface mode %s for type %s", -1, interface.iMode, interface.iType)
        end
    else
        flog("Unknown interface type %s", -1, interface.iType)
    end
end

--=============================================================================

---Auto raise interface.
---@param iName string
---@return boolean
function ifconfig.autoIfup(iName)
    local _, auto = ifconfig.loadInterfaces(INTERFACES_FILE)
    local interface = ifconfig.findInterface(iName)
    if (not interface) then
        interface = ifconfig.findInterface(string.format("eth%d", component.proxy(iName).slot))
    end
    iName = interface.iName
    if (auto[iName] or auto[component.get(iName, "modem")]) then
        return ifconfig.ifup(iName)
    else
        return false
    end
end

--=============================================================================

---@param iName string
function ifconfig.ifdown(iName)
    ---@diagnostic disable-next-line: cast-local-type
    local address = component.get(iName, "modem")

    local relatedInterfaces = {}
    for interfaceName, interface in pairs(network.interfaces) do
        if (interfaceName == iName or interfaceName == address or interface.ethernet:getAddr() == iName) then
            table.insert(relatedInterfaces, interfaceName)
        end
    end

    for _, name in pairs(relatedInterfaces) do
        if (network.interfaces[name]) then
            network.router:removeByInterface(network.interfaces[name].ip)
            network.interfaces[name] = nil
        else
            flog("Interface %q is not up", 0, name)
        end
    end
end

--=============================================================================
return ifconfig
