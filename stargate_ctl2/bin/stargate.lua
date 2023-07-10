local component      = require "component"
local event          = require "event"
local os             = require "os"
local filesystem     = require "filesystem"
local serialization  = require "serialization"
local class          = require "libClass2"
local yawl           = require "yawl"

local gpu            = component.gpu
local stargate       = component.stargate

--#region consts
local CONFIG_DIR     = "/etc/stargate/"
local CONFIG_FILE    = CONFIG_DIR .. "stargate.cfg"
local GATE_LIST_FILE = CONFIG_DIR .. "gates.csv"
local IMG_ROOT       = "/usr/share/stargate/"
local IRIS_STATE     = {IMG_ROOT .. "iris1.pam", IMG_ROOT .. "iris2.pam", IMG_ROOT .. "iris3.pam"}
local GATE_STATE     = {[0] = IMG_ROOT .. "sg00.pam", IMG_ROOT .. "sg01.pam", IMG_ROOT .. "sg02.pam", IMG_ROOT .. "sg03.pam", IMG_ROOT .. "sg04.pam", IMG_ROOT .. "sg05.pam", IMG_ROOT .. "sg06.pam", IMG_ROOT .. "sg07.pam", IMG_ROOT .. "sg08.pam", IMG_ROOT .. "sg09.pam", IMG_ROOT .. "sg10.pam"}
local VORTEX         = IMG_ROOT .. "vortex.pam"
--#region color theme
local THEME          = {}
THEME.BACKGROUND     = {
    MAIN = 0x787878,
    LOCAL_ADDRESSE = 0x000000,
    REMOTE_ADRESSE = {
        OFFLINE = 0x000000,
        BLOCKED = 0x000000,
        ALLOWED = 0x000000
    },
    ADDRESS_INPUT = 0x000000,
    PASSWORD_INPUT = {
        DEFAULT = 0x000000,
        OK = 0x000000,
        ERROR = 0x000000
    },
    ADDRESS_INPUT_LABEL = 0x0000FF,
    PASSWORD_INPUT_LABEL = 0x0000FF,
    DIAL_BUTTON = {
        DEFAULT = 0x00FF00,
        CONNECTED = 0xFF0000,
    },
    IRIS_BUTTON = {
        OPEN = 0x00FF00,
        CLOSE = 0xFF0000,
        MOVING = 0x4B4B4B
    },
    GATE_LIST_NAME = 0x000000,
    WHITELIST_BUTTON = {
        ON = 0xFFFFFF,
        OFF = 0xFFFFFF
    },
    BLACKLIST_BUTTON = {
        ON = 0xFFFFFF,
        OFF = 0xFFFFFF
    },
    DELETE_BUTTON = 0xFF0000,
    RENAME_INPUT = 0x000000,
    CONFIG_FRAME = 0x4B4B4B,
    TOGGLE = {
        ON = 0x00FF00,
        OFF = 0xFF0000
    },
    PASSWORD_CONFIG_LABEL = 0x4B4B4B,
    PASSWORD_CONFIG_INPUT = 0x000000,
    FRAME_CLOSE_BUTTON = 0xFFFFFF,
    CONFIG_BUTTON = 0xFFFF00,
}
THEME.FOREGROUND     = {
    MAIN = 0,
    LOCAL_ADDRESSE = 0x0000FF,
    REMOTE_ADRESSE = {
        OFFLINE = 0xFFFFFF,
        BLOCKED = 0xFF0000,
        ALLOWED = 0x00FF00
    },
    ADDRESS_INPUT = 0xFFFFFF,
    PASSWORD_INPUT = {
        DEFAULT = 0xFFFFFF,
        OK = 0x00FF00,
        ERROR = 0xFF0000
    },
    ADDRESS_INPUT_LABEL = 0x000000,
    PASSWORD_INPUT_LABEL = 0x000000,
    DIAL_BUTTON = {
        DEFAULT = 0x000000,
        CONNECTED = 0x000000,
    },
    IRIS_BUTTON = {
        OPEN = 0x000000,
        CLOSE = 0x000000,
        MOVING = 0xFFFFFF
    },
    GATE_LIST_NAME = 0xFFFFFF,
    WHITELIST_BUTTON = {
        ON = 0x00FF00,
        OFF = 0x000000
    },
    BLACKLIST_BUTTON = {
        ON = 0xFF0000,
        OFF = 0x000000
    },
    DELETE_BUTTON = 0x000000,
    RENAME_INPUT = 0xFFFFFF,
    TOGGLE = {
        ON = 0x000000,
        OFF = 0x000000
    },
    PASSWORD_CONFIG_LABEL = 0x000000,
    PASSWORD_CONFIG_INPUT = 0xFFFFFF,
    FRAME_CLOSE_BUTTON = 0xFF0000,
    CONFIG_BUTTON = 0x000000
}
--#endregion
--#endregion

--#region global
local eventHandlers  = {}
local oldRes         = table.pack(gpu.getResolution())
local rootFrame ---@type Frame
local uiWidgets      = {}
local gatesData      = {}
local run            = true
local config         = {
    password = nil,
    whitelist = false,
    blacklist = false,
    dropNotAllowed = false
}
local smartRemote    = false
local irisStateGoal  = 'Offline' ---@type irisState
--#endregion

--#region pre init check

if (not stargate) then
    print("No stargate available")
    os.exit(1)
end

--#endregion

--#region utils

local function closeApp()
    run = false
    return false
end

local function allowedGate(address)
    if (config.blacklist) then
        if (gatesData[address].blacklist) then return false end
    end
    if (config.whitelist) then
        if (not gatesData[address].whitelist) then return false end
    end
    return true
end

local function formatAddress(add)
    --format the addresse in a pretty format AAAA-AAA-AA
    add = string.gsub(string.upper(add), "-", "")
    local fAdd = string.format("%s-%s", string.sub(add, 0, 4), string.sub(add, 5, 7))
    if (#add > 7) then fAdd = string.format("%s-%s", fAdd, string.sub(add, 8)) end
    return fAdd
end

---Read the gate list
local function loadGateList()
    if (not filesystem.exists(GATE_LIST_FILE)) then return {} end
    local file = assert(io.open(GATE_LIST_FILE, 'r'))
    local gates = {}
    for line in file:lines() do
        local address, name, password, extraList = line:match("^(.+);(.*);(.*);([wWbB]?[wWbB]?)$")
        local wl, bl = false, false
        if (extraList:match("[bB]")) then bl = true end
        if (extraList:match("[wW]")) then wl = true end
        gatesData[address] = {name = name, password = password, whitelist = wl, blacklist = bl}
    end
end

local function saveGateList()
    local file = assert(io.open(GATE_LIST_FILE, 'w'))
    for addr, gate in pairs(gatesData) do
        local extra = ""
        if gate.whitelist then extra = extra .. "W" end
        if gate.blacklist then extra = extra .. "B" end
        file:write(string.format("%s;%s;%s;%s\n", addr, gate.name or "", gate.password or "", extra))
    end
    file:close()
end

local function loadConfig()
    if (filesystem.exists(CONFIG_FILE)) then
        local file = assert(io.open(CONFIG_FILE))
        local loadedConfig = serialization.unserialize(file:read("*a"))
        file:close()
        for k, v in pairs(loadedConfig) do
            config[k] = v
        end
    end
    if (config.whitelist and config.blacklist) then
        config.whitelist = true
        config.blacklist = false
    end
end

local function saveConfig()
    local file = assert(io.open(CONFIG_FILE, 'w'))
    file:write(serialization.serialize(config))
    file:close()
end

local function updatePassword(password)
    if (password) then
        uiWidgets.passwordInput:foregroundColor(THEME.FOREGROUND.PASSWORD_INPUT.OK)
        uiWidgets.passwordInput:backgroundColor(THEME.BACKGROUND.PASSWORD_INPUT.OK)
    else
        uiWidgets.passwordInput:foregroundColor(THEME.FOREGROUND.PASSWORD_INPUT.ERROR)
        uiWidgets.passwordInput:backgroundColor(THEME.BACKGROUND.PASSWORD_INPUT.ERROR)
    end
    if (uiWidgets.passwordInput:text() ~= gatesData[stargate.remoteAddress()].password) then
        gatesData[stargate.remoteAddress()].password = uiWidgets.passwordInput:text()
        saveGateList()
    end
end

local function openIris()
    local sucess, reason = stargate.openIris()
    if (sucess) then irisStateGoal = 'Open' end
    return sucess, reason
end

local function closeIris()
    local sucess, reason = stargate.closeIris()
    if (sucess) then irisStateGoal = 'Closed' end
    return sucess, reason
end

--#endregion

--#region remoteGate

---@class RemoteGate:Object
local RemoteGate = {}

function RemoteGate.closeIris()
    stargate.sendMessage("SGCONTROLLER", "IRIS", uiWidgets.passwordInput:text(), false)
    local eventName, gateComponentAddress, protocol, command, password, msg, reason = event.pull(3, "sgMessageReceived", nil, "SGCONTROLLER", "IRIS_A")
    updatePassword(password)
    if (not eventName) then return nil, "Timeout" end
    if (password == false) then return nil, "Invalid Password" end
    return msg, reason
end

function RemoteGate.openIris()
    stargate.sendMessage("SGCONTROLLER", "IRIS", uiWidgets.passwordInput:text(), true)
    local eventName, gateComponentAddress, protocol, command, password, msg, reason = event.pull(3, "sgMessageReceived", nil, "SGCONTROLLER", "IRIS_A")
    updatePassword(password)
    if (not eventName) then return nil, "Timeout" end
    if (password == false) then return nil, "Invalid Password" end
    if (reason == 'missingIris') then msg = true end
    return msg, reason
end

function RemoteGate.irisState()
    stargate.sendMessage("SGCONTROLLER", "IRIS", uiWidgets.passwordInput:text())
    local eventName, gateComponentAddress, protocol, command, password, msg, reason = event.pull(3, "sgMessageReceived", nil, "SGCONTROLLER", "IRIS_A")
    updatePassword(password)
    if (not eventName) then return nil, "Timeout" end
    if (password == false) then return nil, "Invalid Password" end
    return msg, reason
end

---@return boolean, boolean? password ok
function RemoteGate.ping()
    stargate.sendMessage("SGCONTROLLER", "PING", uiWidgets.passwordInput:text() or "", "ping")
    local eventName, gateComponentAddress, protocol, command, password, msg, reason = event.pull(3, "sgMessageReceived", nil, "SGCONTROLLER", "PING", nil, "pong")
    updatePassword()
    if (not eventName or msg ~= 'pong') then return false end
    return true, password
end

---@param password? string
---@return boolean
function RemoteGate.authorized(password)
    local _, _, direction = stargate.stargateState()
    if (direction == "Outgoing") then
        local _, authorized = RemoteGate.ping()
        return authorized --[[@as boolean]]
    else
        local gate = gatesData[stargate.remoteAddress()]
        if ((config.whitelist and not gate.whitelist) or (config.blacklist and gate.blacklist)) then
            if (not config.password or config.password == "") then
                return false
            elseif (config.password == password) then
                return true
            else
                return false
            end
        else
            return true
        end
    end
end

--#endregion

--#region buttons handlers
--#region main screen buttons

---@param self Text
---@param args any
---@param eventName string
---@param componentAddress string
---@param x number
---@param y number
---@param button number
---@param player string
local function irisButtonHandler(self, args, eventName, componentAddress, x, y, button, player)
    if (eventName ~= 'touch') then return end
    if (stargate.stargateState() == "Dialling" or stargate.stargateState() == "Opening") then
        closeIris()
        return
    end
    if (button ~= 0) then return end
    local currentIrisState = stargate.irisState()
    if (currentIrisState == "Offline") then return end
    if (currentIrisState == "Closed" or currentIrisState == "Closing") then
        if (smartRemote) then
            if (RemoteGate.openIris()) then
                openIris()
                uiWidgets.infoText:text("Iris : remote allowed it")
            else
                uiWidgets.infoText:text("Iris error : other side doesn't allow it")
            end
        else
            openIris()
        end
    else
        if (smartRemote) then
            if (RemoteGate.closeIris()) then
                closeIris()
                uiWidgets.infoText:text("Iris : remote allowed it")
            else
                uiWidgets.infoText:text("Iris error : other side doesn't allow it")
            end
        else
            closeIris()
        end
    end
end

---@param self Text
---@param args any
---@param eventName string
---@param componentAddress string
---@param x number
---@param y number
---@param button number
---@param player string
local function dialButtonHandler(self, args, eventName, componentAddress, x, y, button, player)
    if (eventName ~= 'touch') then return end
    if (button ~= 0) then return end
    local currentGateState = stargate.stargateState()
    if (currentGateState ~= "Idle") then
        stargate.disconnect()
    else
        local s, reason = stargate.dial(uiWidgets.addressInput:text())
        if (reason) then
            uiWidgets.infoText:text("Dialling error : " .. reason)
        end
        uiWidgets.addressInput:text(formatAddress(uiWidgets.addressInput:text()))
    end
end

---@param self Text
---@param args any
---@param eventName string
---@param componentAddress string
---@param x number
---@param y number
---@param button number
---@param player string
local function gateNameButtonHandler(self, args, eventName, componentAddress, x, y, button, player)
    if (eventName ~= "touch") then return end
    if (button == 0) then
        uiWidgets.addressInput:text(formatAddress(args.addr))
        uiWidgets.passwordInput:text(gatesData[args.addr].password or "")
    elseif (button == 1) then
        if (self:foregroundColor() == THEME.FOREGROUND.GATE_LIST_NAME) then
            self:foregroundColor(THEME.BACKGROUND.GATE_LIST_NAME)
            self:backgroundColor(THEME.FOREGROUND.GATE_LIST_NAME)
            self:draw()
            local _, _, xx, yy = event.pull("touch") --listen for touch everywhere
            --restore the colors
            self:foregroundColor(THEME.FOREGROUND.GATE_LIST_NAME)
            self:backgroundColor(THEME.BACKGROUND.GATE_LIST_NAME)
            if (not self:checkCollision(xx, yy)) then return end      --if not on this widget then do nothing
            if (uiWidgets.renameInput:text() == "") then return end   --if no name is in the Input widget do nothing
            gatesData[args.addr].name = uiWidgets.renameInput:text()  --update the gate data
            self:text(uiWidgets.renameInput:text())                   --update the widget text
            uiWidgets.renameInput:text("Right click twice to rename") --reset input
            saveGateList()                                            --save the new data
        end
    end
end

---@param self Text
---@param args any
---@param eventName string
---@param componentAddress string
---@param x number
---@param y number
---@param button number
---@param player string
local function deleteButtonHandler(self, args, eventName, componentAddress, x, y, button, player)
    if (eventName ~= 'touch') then return end
    if (self:foregroundColor() == THEME.FOREGROUND.DELETE_BUTTON) then
        self:foregroundColor(THEME.BACKGROUND.DELETE_BUTTON)
        self:backgroundColor(THEME.FOREGROUND.DELETE_BUTTON)
        self:draw()
        local _, _, xx, yy = event.pull("touch") --listen for touch everywhere
        --restore the colors
        self:foregroundColor(THEME.FOREGROUND.DELETE_BUTTON)
        self:backgroundColor(THEME.BACKGROUND.DELETE_BUTTON)
        if (not self:checkCollision(xx, yy)) then return end    --if not on this widget then do nothing
        if (uiWidgets.renameInput:text() == "") then return end --if no name is in the Input widget do nothing
        uiWidgets.gateList:removeChild(args.container)          --remove the gate from the list on screen
        gatesData[args.addr] = nil                              --remove the gate from the data
        saveGateList()                                          --save the new data
    end
end

---@param self Text
---@param args any
---@param eventName string
---@param ... any
local function configButtonHandler(self, args, eventName, ...)
    if (eventName ~= 'touch') then return end
    uiWidgets.mainFrame:enabled(false)
    uiWidgets.configFrame:enabled(true)
    uiWidgets.configFrame:visible(true)
end

---@param self Text
---@param args any
---@param eventName string
---@param ... any
local function whiteListButtonHandler(self, args, eventName, ...)
    if (eventName ~= 'touch') then return end
    --uiWidgets.infoText:text("list : " .. args)
    gatesData[args].whitelist = not gatesData[args].whitelist
    if (gatesData[args].whitelist) then
        self:foregroundColor(THEME.FOREGROUND.WHITELIST_BUTTON.ON)
        self:backgroundColor(THEME.BACKGROUND.WHITELIST_BUTTON.ON)
    else
        self:foregroundColor(THEME.FOREGROUND.WHITELIST_BUTTON.OFF)
        self:backgroundColor(THEME.BACKGROUND.WHITELIST_BUTTON.OFF)
    end
    saveGateList()
end

---@param self Text
---@param args any
---@param eventName string
---@param ... any
local function blacklistButtonHandler(self, args, eventName, ...)
    if (eventName ~= 'touch') then return end
    --uiWidgets.infoText:text("list : " .. args)
    gatesData[args].blacklist = not gatesData[args].blacklist
    if (gatesData[args].blacklist) then
        self:foregroundColor(THEME.FOREGROUND.BLACKLIST_BUTTON.ON)
        self:backgroundColor(THEME.BACKGROUND.BLACKLIST_BUTTON.ON)
    else
        self:foregroundColor(THEME.FOREGROUND.BLACKLIST_BUTTON.OFF)
        self:backgroundColor(THEME.BACKGROUND.BLACKLIST_BUTTON.OFF)
    end
    saveGateList()
end
--#endregion

--#region config screen buttons

---@param self Widget
---@param args nil
---@param eventName string
---@param ... any
local function closeConfigFrame(self, args, eventName, ...)
    if (eventName ~= 'touch') then return end
    uiWidgets.configFrame:visible(false)
    uiWidgets.configFrame:enabled(false)
    uiWidgets.mainFrame:visible(true)
    uiWidgets.mainFrame:enabled(true)
    config.password = uiWidgets.passwordConfigInput:text()
    saveConfig()
end

---@param self Text
---@param args any
---@param eventName string
---@param ... any
local function toogleConfigWhitelist(self, args, eventName, ...)
    if (eventName ~= 'touch') then return end
    config.whitelist = not config.whitelist
    if (config.whitelist) then
        config.blacklist = false
        uiWidgets.blacklistToggle:backgroundColor(THEME.BACKGROUND.TOGGLE.OFF)
        uiWidgets.blacklistToggle:foregroundColor(THEME.FOREGROUND.TOGGLE.OFF)
        self:backgroundColor(THEME.BACKGROUND.TOGGLE.ON)
        self:foregroundColor(THEME.FOREGROUND.TOGGLE.ON)
    else
        self:backgroundColor(THEME.BACKGROUND.TOGGLE.OFF)
        self:foregroundColor(THEME.FOREGROUND.TOGGLE.OFF)
    end
    saveConfig()
end

---@param self Text
---@param args any
---@param eventName string
---@param ... any
local function toogleConfigBlacklist(self, args, eventName, ...)
    if (eventName ~= 'touch') then return end
    config.blacklist = not config.blacklist
    if (config.blacklist) then
        config.whitelist = false
        uiWidgets.whitelistToggle:backgroundColor(THEME.BACKGROUND.TOGGLE.OFF)
        uiWidgets.whitelistToggle:foregroundColor(THEME.FOREGROUND.TOGGLE.OFF)
        self:backgroundColor(THEME.BACKGROUND.TOGGLE.ON)
        self:foregroundColor(THEME.FOREGROUND.TOGGLE.ON)
    else
        self:backgroundColor(THEME.BACKGROUND.TOGGLE.OFF)
        self:foregroundColor(THEME.FOREGROUND.TOGGLE.OFF)
    end
    saveConfig()
end

---@param self Text
---@param args any
---@param eventName string
---@param ... any
local function toogleAutoDrop(self, args, eventName, ...)
    if (eventName ~= 'touch') then return end
    config.dropNotAllowed = not config.dropNotAllowed
    if (config.dropNotAllowed) then
        self:backgroundColor(THEME.BACKGROUND.TOGGLE.ON)
        self:foregroundColor(THEME.FOREGROUND.TOGGLE.ON)
    else
        self:backgroundColor(THEME.BACKGROUND.TOGGLE.OFF)
        self:foregroundColor(THEME.FOREGROUND.TOGGLE.OFF)
    end
    saveConfig()
end
--#endregion
--#endregion

--#region more utils

---Add a gate to the gate list
---@param gateAddress string
---@param gateName? string
local function addGateToList(gateAddress, gateName)
    if (not gateName or gateName == "") then gateName = formatAddress(gateAddress) end
    local gateButtonFrame = yawl.widget.Frame(uiWidgets.gateList, 1, 1)
    gateButtonFrame:size(uiWidgets.gateList:width(), 1)

    local gateNameText = yawl.widget.Text(gateButtonFrame, 1, 1, gateName, THEME.FOREGROUND.GATE_LIST_NAME)
    gateNameText:backgroundColor(THEME.BACKGROUND.GATE_LIST_NAME)
    gateNameText:size(gateButtonFrame:width() - 3, gateButtonFrame:height())
    gateNameText:callback(gateNameButtonHandler, {addr = gateAddress})

    local whiteListButton = yawl.widget.Text(gateButtonFrame, gateButtonFrame:width() - 2, 1, "W", 0)
    whiteListButton:size(1, 1)
    whiteListButton:callback(whiteListButtonHandler, gateAddress)
    if (gatesData[gateAddress].whitelist) then
        whiteListButton:foregroundColor(THEME.FOREGROUND.WHITELIST_BUTTON.ON)
        whiteListButton:backgroundColor(THEME.BACKGROUND.WHITELIST_BUTTON.ON)
    else
        whiteListButton:foregroundColor(THEME.FOREGROUND.WHITELIST_BUTTON.OFF)
        whiteListButton:backgroundColor(THEME.BACKGROUND.WHITELIST_BUTTON.OFF)
    end

    local blackListButton = yawl.widget.Text(gateButtonFrame, gateButtonFrame:width() - 1, 1, "B", 0)
    blackListButton:size(1, 1)
    blackListButton:callback(blacklistButtonHandler, gateAddress)
    if (gatesData[gateAddress].blacklist) then
        blackListButton:foregroundColor(THEME.FOREGROUND.BLACKLIST_BUTTON.ON)
        blackListButton:backgroundColor(THEME.BACKGROUND.BLACKLIST_BUTTON.ON)
    else
        blackListButton:foregroundColor(THEME.FOREGROUND.BLACKLIST_BUTTON.OFF)
        blackListButton:backgroundColor(THEME.BACKGROUND.BLACKLIST_BUTTON.OFF)
    end

    local deleteListButton = yawl.widget.Text(gateButtonFrame, gateButtonFrame:width(), 1, "X", THEME.FOREGROUND.DELETE_BUTTON)
    deleteListButton:size(1, 1)
    deleteListButton:backgroundColor(THEME.BACKGROUND.DELETE_BUTTON)
    deleteListButton:callback(deleteButtonHandler, {container = gateButtonFrame, addr = gateAddress})
end
--#endregion

--#region eventHandlers

---@param eventName string
---@param componentAddress string
---@param toState stargateState
---@param fromState stargateState
local function onStargateStateChange(eventName, componentAddress, toState, fromState)
    if (fromState == "Idle") then
        closeIris()
        uiWidgets.dialButton:foregroundColor(THEME.FOREGROUND.DIAL_BUTTON.CONNECTED)
        uiWidgets.dialButton:backgroundColor(THEME.BACKGROUND.DIAL_BUTTON.CONNECTED)
        uiWidgets.dialButton:text("DISCONNECT")
        uiWidgets.remoteAddress:text(" " .. formatAddress(stargate.remoteAddress()))
        if (not gatesData[stargate.remoteAddress()]) then
            addGateToList(stargate.remoteAddress())
            gatesData[stargate.remoteAddress()] = {}
            saveGateList()
        end
        uiWidgets.remoteAddress:foregroundColor(THEME.FOREGROUND.REMOTE_ADRESSE.ALLOWED)
        uiWidgets.remoteAddress:backgroundColor(THEME.BACKGROUND.REMOTE_ADRESSE.ALLOWED)
        if (config.blacklist) then
            if (gatesData[stargate.remoteAddress()].blacklist) then
                if (config.dropNotAllowed) then
                    stargate.disconnect()
                else
                    uiWidgets.remoteAddress:foregroundColor(THEME.FOREGROUND.REMOTE_ADRESSE.BLOCKED)
                    uiWidgets.remoteAddress:backgroundColor(THEME.BACKGROUND.REMOTE_ADRESSE.BLOCKED)
                end
            end
        end
        if (config.whitelist) then
            if (not gatesData[stargate.remoteAddress()].whitelist) then
                if (config.dropNotAllowed) then
                    stargate.disconnect()
                else
                    uiWidgets.remoteAddress:foregroundColor(THEME.FOREGROUND.REMOTE_ADRESSE.BLOCKED)
                    uiWidgets.remoteAddress:backgroundColor(THEME.BACKGROUND.REMOTE_ADRESSE.BLOCKED)
                end
            end
        end
        smartRemote = false
    end
    if (toState == "Connected") then
        uiWidgets.vortexLayer:visible(true)
        smartRemote = RemoteGate.ping()
        if (smartRemote) then
            uiWidgets.infoText:text("Communication established with other side")
        else
            uiWidgets.infoText:text("Warning : cannot get info about remote gate")
        end
        local _, _, direction = stargate.stargateState()
        if (direction == 'Outgoing') then
            if (allowedGate(stargate.remoteAddress())) then
                if (not smartRemote) then
                    openIris()
                elseif (RemoteGate.openIris()) then
                    openIris()
                end
            end
        elseif (direction == 'Incoming' and not smartRemote) then
            --open iris for dumb connections
            if (allowedGate(stargate.remoteAddress())) then openIris() end
        end
    elseif (toState == "Idle") then
        uiWidgets.dialButton:foregroundColor(THEME.FOREGROUND.DIAL_BUTTON.DEFAULT)
        uiWidgets.dialButton:backgroundColor(THEME.BACKGROUND.DIAL_BUTTON.DEFAULT)
        uiWidgets.dialButton:text("DIAL")
        uiWidgets.remoteAddress:foregroundColor(THEME.FOREGROUND.REMOTE_ADRESSE.OFFLINE)
        uiWidgets.remoteAddress:backgroundColor(THEME.BACKGROUND.REMOTE_ADRESSE.OFFLINE)
        uiWidgets.remoteAddress:text("OFFLINE")
        uiWidgets.passwordInput:foregroundColor(THEME.FOREGROUND.PASSWORD_INPUT.DEFAULT)
        uiWidgets.passwordInput:backgroundColor(THEME.BACKGROUND.PASSWORD_INPUT.DEFAULT)
        uiWidgets.gateLayer:imageData(yawl.ImageFile(GATE_STATE[0]))
        openIris()
        uiWidgets.vortexLayer:visible(false)
        smartRemote = false
        uiWidgets.infoText:text("Idle")
    end
end

---@param eventName string
---@param componentAddress string
---@param toState irisState
---@param fromState irisState
local function onIrisStateChange(eventName, componentAddress, toState, fromState)
    uiWidgets.irisLayer:visible(true)
    if (toState == "Closed") then
        if (irisStateGoal ~= 'Closed') then
            openIris()
            return
        end
        uiWidgets.irisLayer:imageData(yawl.ImageFile(IRIS_STATE[3]))
        uiWidgets.irisButton:foregroundColor(THEME.FOREGROUND.IRIS_BUTTON.CLOSE)
        uiWidgets.irisButton:backgroundColor(THEME.BACKGROUND.IRIS_BUTTON.CLOSE)
    elseif (toState == "Opening") then
        if (irisStateGoal ~= 'Open') then
            closeIris()
            return
        end
        uiWidgets.irisLayer:imageData(yawl.ImageFile(IRIS_STATE[2]))
        uiWidgets.irisButton:foregroundColor(THEME.FOREGROUND.IRIS_BUTTON.MOVING)
        uiWidgets.irisButton:backgroundColor(THEME.BACKGROUND.IRIS_BUTTON.MOVING)
    elseif (toState == "Open") then
        if (irisStateGoal ~= 'Open') then
            closeIris()
            return
        end
        uiWidgets.irisLayer:imageData(yawl.ImageFile(IRIS_STATE[1]))
        uiWidgets.irisButton:foregroundColor(THEME.FOREGROUND.IRIS_BUTTON.OPEN)
        uiWidgets.irisButton:backgroundColor(THEME.BACKGROUND.IRIS_BUTTON.OPEN)
    elseif (toState == "Closing") then
        if (irisStateGoal ~= 'Closed') then
            openIris()
            return
        end
        uiWidgets.irisLayer:imageData(yawl.ImageFile(IRIS_STATE[2]))
        uiWidgets.irisButton:foregroundColor(THEME.FOREGROUND.IRIS_BUTTON.MOVING)
        uiWidgets.irisButton:backgroundColor(THEME.BACKGROUND.IRIS_BUTTON.MOVING)
    elseif (toState == "Offline") then
        uiWidgets.irisLayer:visible(false)
    end
end

local function onChevronEngaded(eventName, componentAddress, chevronID, chevronChar)
    --sgChevronEngaded addr number chevronChar
    if (chevronID > 7) then chevronID = chevronID + 1 end --chevron 8 and 9 are used
    uiWidgets.gateLayer:imageData(yawl.ImageFile(GATE_STATE[chevronID]))
    --if the gate is still dialling, skip the img 7 (fully dialled 7 chevron)
    if (chevronID == 7 and stargate.stargateState() == "Dialling") then uiWidgets.gateLayer:imageData(yawl.ImageFile(GATE_STATE[chevronID + 1])) end
end

local function onMessageReceived(eventName, componentAddress, protocol, command, password, arg, reason)
    if (not protocol == "SGCONTROLLER") then return end
    if (command == "IRIS") then
        if (arg == nil) then
            stargate.sendMessage("SGCONTROLLER", "IRIS", true, stargate.irisState())
        elseif (RemoteGate.authorized(password) or arg == false) then
            --TODO : add lockdown
            if (arg == true) then
                stargate.sendMessage("SGCONTROLLER", "IRIS_A", true, openIris())
            else
                stargate.sendMessage("SGCONTROLLER", "IRIS_A", true, closeIris())
            end
        else
            stargate.sendMessage("SGCONTROLLER", "IRIS_A", false, false, 'invalid password')
        end
    elseif (command == "PING" and arg == "ping") then
        local psOk = true
        if (config.password and config.password ~= password) then psOk = false end
        stargate.sendMessage("SGCONTROLLER", "PING", psOk, "pong")
    end
end
--#endregion

--#region gui
rootFrame = yawl.widget.Frame()
rootFrame:backgroundColor(THEME.BACKGROUND.MAIN)
--#region main screen
local mainFrame = yawl.widget.Frame(rootFrame)
uiWidgets.mainFrame = mainFrame
--#region Infos
local localAddressText = yawl.widget.Text(mainFrame, 1, 1, " " .. formatAddress(stargate.localAddress()) .. " ", THEME.FOREGROUND.LOCAL_ADDRESSE)
localAddressText:center(true)
localAddressText:backgroundColor(THEME.BACKGROUND.LOCAL_ADDRESSE)
local remoteAddress = yawl.widget.Text(mainFrame, localAddressText:x() + localAddressText:width() + 1, 1, "OFFLINE", THEME.FOREGROUND.REMOTE_ADRESSE.OFFLINE)
remoteAddress:center(true)
remoteAddress:size(localAddressText:size())
remoteAddress:backgroundColor(THEME.BACKGROUND.REMOTE_ADRESSE.OFFLINE)
uiWidgets.remoteAddress = remoteAddress
local configButton = yawl.widget.Text(mainFrame, remoteAddress:x() + remoteAddress:width() + 1, 1, "CONFIG", THEME.FOREGROUND.CONFIG_BUTTON)
configButton:backgroundColor(THEME.BACKGROUND.CONFIG_BUTTON)
configButton:center(true)
configButton:size(11)
configButton:callback(configButtonHandler)
local infoText = yawl.widget.Text(mainFrame, 1, 25, "Welcome", 0xFFFFFF)
infoText:size(80, 1)
infoText:backgroundColor(0)
uiWidgets.infoText = infoText
--#endregion
--#region known gates list
local gateList = yawl.widget.WidgetList(mainFrame, 2, 3)
gateList:size(38, 20)
gateList:backgroundColor(0xffffff)
uiWidgets.gateList = gateList
--#endregion
--#region gate img
local gateImgFrame = yawl.widget.Frame(mainFrame, 47, 4)
local vortexLayer  = yawl.widget.Image(gateImgFrame, 1, 1, VORTEX)
vortexLayer:z(0)
uiWidgets.vortexLayer = vortexLayer
local irisLayer = yawl.widget.Image(gateImgFrame, 1, 1, IRIS_STATE[1])
irisLayer:z(vortexLayer:z() + 1)
irisLayer:callback(irisButtonHandler)
if (stargate.irisState() == "Closed") then
    irisLayer:imageData(yawl.ImageFile(IRIS_STATE[3]))
elseif (stargate.irisState() == "Opening") then
    irisLayer:imageData(yawl.ImageFile(IRIS_STATE[2]))
elseif (stargate.irisState() == "Open") then
    irisLayer:imageData(yawl.ImageFile(IRIS_STATE[1]))
elseif (stargate.irisState() == "Closing") then
    irisLayer:imageData(yawl.ImageFile(IRIS_STATE[2]))
elseif (stargate.irisState() == "Offline") then
    irisLayer:visible(false)
end
uiWidgets.irisLayer = irisLayer
local gateLayer = yawl.widget.Image(gateImgFrame, 1, 1, GATE_STATE[0])
gateLayer:z(irisLayer:z() + 1)
uiWidgets.gateLayer = gateLayer
gateImgFrame:size(gateLayer:size())
--#endregion
--#region buttons
local dialButton = yawl.widget.Text(mainFrame, 47, gateImgFrame:y() + gateImgFrame:height() + 1, "DIAL", 0)
dialButton:center(true)
dialButton:size(12, 1)
dialButton:callback(dialButtonHandler)
uiWidgets.dialButton = dialButton
if (stargate.stargateState() == "Connected") then
    dialButton:foregroundColor(THEME.FOREGROUND.DIAL_BUTTON.CONNECTED)
    dialButton:backgroundColor(THEME.BACKGROUND.DIAL_BUTTON.CONNECTED)
    dialButton:text("DISCONNECT")
else
    dialButton:foregroundColor(THEME.FOREGROUND.DIAL_BUTTON.DEFAULT)
    dialButton:backgroundColor(THEME.BACKGROUND.DIAL_BUTTON.DEFAULT)
    dialButton:text("DIAL")
end
local irisButton = yawl.widget.Text(mainFrame, gateImgFrame:x() + gateImgFrame:width() - dialButton:width(), dialButton:y(), "IRIS", 0)
irisButton:center(true)
irisButton:size(dialButton:size())
irisButton:callback(irisButtonHandler)
uiWidgets.irisButton = irisButton
if (stargate.irisState() == "Open") then
    irisButton:foregroundColor(THEME.FOREGROUND.IRIS_BUTTON.OPEN)
    irisButton:backgroundColor(THEME.BACKGROUND.IRIS_BUTTON.OPEN)
elseif (stargate.irisState() == "Closed") then
    irisButton:foregroundColor(THEME.FOREGROUND.IRIS_BUTTON.CLOSE)
    irisButton:backgroundColor(THEME.BACKGROUND.IRIS_BUTTON.CLOSE)
else
    irisButton:foregroundColor(THEME.FOREGROUND.IRIS_BUTTON.MOVING)
    irisButton:backgroundColor(THEME.BACKGROUND.IRIS_BUTTON.MOVING)
end
--#endregion
--#region inputs
local addressInputLabel = yawl.widget.Text(mainFrame, gateImgFrame:x(), gateImgFrame:y() + gateImgFrame:height() + 2, "Address :", THEME.FOREGROUND.ADDRESS_INPUT_LABEL)
addressInputLabel:backgroundColor(THEME.BACKGROUND.ADDRESS_INPUT_LABEL)
local addressInput = yawl.widget.TextInput(mainFrame, addressInputLabel:x() + addressInputLabel:width(), addressInputLabel:y(), "", THEME.FOREGROUND.ADDRESS_INPUT)
addressInput:center(true)
addressInput:size(18, 1)
addressInput:backgroundColor(THEME.BACKGROUND.ADDRESS_INPUT)
uiWidgets.addressInput = addressInput
local passwordInputLabel = yawl.widget.Text(mainFrame, addressInputLabel:x(), addressInputLabel:y() + 1, "Password :", THEME.FOREGROUND.PASSWORD_INPUT_LABEL)
passwordInputLabel:backgroundColor(THEME.BACKGROUND.PASSWORD_INPUT_LABEL)
local passwordInput = yawl.widget.TextInput(mainFrame, passwordInputLabel:x() + passwordInputLabel:width(), passwordInputLabel:y(), "", THEME.FOREGROUND.PASSWORD_INPUT.DEFAULT)
passwordInput:center(true)
passwordInput:placeholder("*")
passwordInput:size(17, 1)
passwordInput:backgroundColor(THEME.BACKGROUND.PASSWORD_INPUT.DEFAULT)
uiWidgets.passwordInput = passwordInput
local renameInput = yawl.widget.TextInput(mainFrame, gateList:x(), gateList:y() + gateList:height(), "Right click twice to rename", THEME.FOREGROUND.RENAME_INPUT)
renameInput:size(gateList:width(), 1)
renameInput:backgroundColor(THEME.BACKGROUND.RENAME_INPUT)
uiWidgets.renameInput = renameInput
--#endregion
--#endregion
--#region config screen
loadConfig()
local configFrame = yawl.widget.Frame(rootFrame, 10, 2)
configFrame:size(60, 21)
configFrame:backgroundColor(THEME.BACKGROUND.CONFIG_FRAME)
configFrame:enabled(false)
configFrame:visible(false)
uiWidgets.configFrame = configFrame

local whitelistToggle = yawl.widget.Text(configFrame, 2, 2, "Use whitelist", THEME.FOREGROUND.TOGGLE.OFF)
whitelistToggle:backgroundColor(THEME.BACKGROUND.TOGGLE.OFF)
whitelistToggle:callback(toogleConfigWhitelist)
if (config.whitelist) then
    whitelistToggle:foregroundColor(THEME.FOREGROUND.TOGGLE.ON)
    whitelistToggle:backgroundColor(THEME.BACKGROUND.TOGGLE.ON)
end
uiWidgets.whitelistToggle = whitelistToggle
local blacklistToggle = yawl.widget.Text(configFrame, 2, 4, "Use blacklist", THEME.FOREGROUND.TOGGLE.OFF)
blacklistToggle:backgroundColor(THEME.BACKGROUND.TOGGLE.OFF)
blacklistToggle:callback(toogleConfigBlacklist)
if (config.blacklist) then
    blacklistToggle:foregroundColor(THEME.FOREGROUND.TOGGLE.ON)
    blacklistToggle:backgroundColor(THEME.BACKGROUND.TOGGLE.ON)
end
uiWidgets.blacklistToggle = blacklistToggle
local dropNotAllowedToogle = yawl.widget.Text(configFrame, 2, 6, "Drop not allowed connections", THEME.FOREGROUND.TOGGLE.OFF)
dropNotAllowedToogle:backgroundColor(THEME.BACKGROUND.TOGGLE.OFF)
dropNotAllowedToogle:callback(toogleAutoDrop)
if (config.dropNotAllowed) then
    dropNotAllowedToogle:foregroundColor(THEME.FOREGROUND.TOGGLE.ON)
    dropNotAllowedToogle:backgroundColor(THEME.BACKGROUND.TOGGLE.ON)
end
local passwordConfigLabel = yawl.widget.Text(configFrame, 2, 8, "Password :", THEME.FOREGROUND.PASSWORD_CONFIG_LABEL)
passwordConfigLabel:backgroundColor(THEME.BACKGROUND.PASSWORD_CONFIG_LABEL)
local passwordConfigInput = yawl.widget.TextInput(configFrame, passwordConfigLabel:x() + passwordConfigLabel:width(), passwordConfigLabel:y(), config.password or "", THEME.FOREGROUND.PASSWORD_CONFIG_INPUT)
passwordConfigInput:placeholder("*")
passwordConfigInput:size(15, 1)
passwordConfigInput:backgroundColor(THEME.BACKGROUND.PASSWORD_CONFIG_INPUT)
uiWidgets.passwordConfigInput = passwordConfigInput

local configCloseButton = yawl.widget.Text(configFrame, configFrame:width(), 1, "X", THEME.FOREGROUND.FRAME_CLOSE_BUTTON)
configCloseButton:backgroundColor(THEME.BACKGROUND.FRAME_CLOSE_BUTTON)
configCloseButton:callback(closeConfigFrame)

--#endregion
--#endregion

--#region MAIN
stargate.disconnect()
openIris()
table.insert(eventHandlers, event.listen("interrupted", closeApp))
table.insert(eventHandlers, event.listen("sgStargateStateChange", onStargateStateChange))
table.insert(eventHandlers, event.listen("sgIrisStateChange", onIrisStateChange))
table.insert(eventHandlers, event.listen("sgChevronEngaged", onChevronEngaded))
table.insert(eventHandlers, event.listen("sgMessageReceived", onMessageReceived))
event.listen("interrupted", closeApp)
vortexLayer:visible(stargate.stargateState() == "Connected")
gpu.setResolution(80, 25)

pcall(filesystem.makeDirectory, CONFIG_DIR)
loadGateList()
for addr, gate in pairs(gatesData) do
    addGateToList(addr, gate.name)
end
local t1 = os.time()
while run do
    os.sleep()
    if (os.time() - t1 > (100 / 5)) then
        rootFrame:draw()
        t1 = os.time()
    end
end
--exit
stargate.disconnect()
openIris()
rootFrame:closeListeners()
gpu.setResolution(table.unpack(oldRes))
for _, listenerId in pairs(eventHandlers) do
    if (type(listenerId) == 'number') then
        event.cancel(listenerId)
    end
end
component.gpu.freeAllBuffers()
require("term").clear()
--#endregion
