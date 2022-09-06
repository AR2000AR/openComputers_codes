local gui = require "libGUI"
local stargate = require("component").stargate
local io = require "io"
local event = require "event"
local os = require "os"
local filesystem = require "filesystem"
local gpu = require("component").gpu
local serialization = require("serialization")

--CONST
local CONFIG_PATH = "/etc/stargate/"
local WHITELIST_FILE = CONFIG_PATH .. "whitelist.csv"
local BLACKLIST_FILE = CONFIG_PATH .. "blacklist.csv"
local CONFIG_FILE = CONFIG_PATH .. "stargate.cfg"
local GATE_LIST = CONFIG_PATH .. "gates.csv"
local IMG_ROOT = "/usr/data/stargate/"
local IRIS_STATE = {IMG_ROOT .. "iris1.pam", IMG_ROOT .. "iris2.pam", IMG_ROOT .. "iris3.pam"}
local VORTEX = IMG_ROOT .. "vortex.pam"
local GATE_STATE = {
    [0] = IMG_ROOT .. "sg00.pam",
    IMG_ROOT .. "sg01.pam",
    IMG_ROOT .. "sg02.pam",
    IMG_ROOT .. "sg03.pam",
    IMG_ROOT .. "sg04.pam",
    IMG_ROOT .. "sg05.pam",
    IMG_ROOT .. "sg06.pam",
    IMG_ROOT .. "sg07.pam",
    IMG_ROOT .. "sg08.pam",
    IMG_ROOT .. "sg09.pam",
    IMG_ROOT .. "sg10.pam"
}

local GATE_IMG_X, GATE_IMG_Y = 48, -1
local LIST_TEXT_X, LIST_TEXT_Y = 2, 3 - 1
local DIALLER_X, DIALLER_Y = 54, 22
local PASSWORD_X, PASSWORD_Y = 50,23

--global event listeners ID
local touchEvent = nil
local sgStargateStateChangeEvent = nil
local sgIrisStateChangeEvent = nil
local sgDialOutEvent = nil
local sgDialInEvent = nil
local sgChevronEngadedEvent = nil
local sgMessageRecivedEvent = nil
local interruptedEvent = nil

-- global vars
local run = true
local config = nil
local dialDirection = false
local dialDim = false
local incomingBlacklist = false
local instantDialed = true
local oldResX, oldResY = gpu.getResolution()
local gates = {}
local waitingForConfirmation = false
local receivedPassword = false
local irisManual = true
local outgoingAuth = false
local outgoingBlacklist = false
local lastPassword = ""

--global widgets
local textRemoteAddr = nil
local mainScreen = nil
local configScreen = nil
local root = nil
local buttonIris = nil
local vortexLayer = nil
local gateLayer = nil
local irisLayer = nil
local gatesListTexts = {}
local nameInput = nil
local buttonWhitelist = nil
local buttonBlacklist = nil
local inputAddr = nil
local passwordField = nil

local function closeApp(...)
    if (touchEvent) then
        event.cancel(touchEvent)
    end
    if (sgStargateStateChangeEvent) then
        event.cancel(sgStargateStateChangeEvent)
    end
    if (sgIrisStateChangeEvent) then
        event.cancel(sgIrisStateChangeEvent)
    end
    if (sgDialOutEvent) then
        event.cancel(sgDialOutEvent)
    end
    if (sgDialInEvent) then
        event.cancel(sgDialInEvent)
    end
    if (sgChevronEngadedEvent) then
        event.cancel(sgChevronEngadedEvent)
    end
    if (sgMessageRecivedEvent) then
        event.cancel(sgMessageRecivedEvent)
    end
    if (interruptedEvent) then
        event.cancel(interruptedEvent)
    end
    if (stargate) then
        stargate.disconnect()
        stargate.closeIris()
    end
    run = false
    gpu.setResolution(oldResX, oldResY)
    require("term").clear()
    os.exit(0)
end

local function gateAddressEqual(a1, a2)
    --remove "-" from the addresses
    a1 = string.gsub(string.upper(a1), "-", "")
    a2 = string.gsub(string.upper(a2), "-", "")
    a1Coord = string.sub(a1, 0, 7)
    a2Coord = string.sub(a2, 0, 7)
    a1Dim = string.sub(a1, 8)
    a2Dim = string.sub(a2, 8)
    if (a1 == a2) then
        return true
    end
    if ("" == a1Dim or "" == a2Dim) then
        return a1Coord == a2Coord
    end
    return false
end

local function formatAddress(add)
    add = string.gsub(string.upper(add), "-", "")
    fAdd = string.format("%s-%s", string.sub(add, 0, 4), string.sub(add, 5, 7))
    if (string.sub(add, 8) ~= "") then
        fAdd = string.format("%s-%s", fAdd, string.sub(add, 8))
    end
    return fAdd
end

local function isGateInList(list, add)
    for i, listAdd in ipairs(list) do
        if (gateAddressEqual(add, listAdd)) then
            return true, i
        end
    end
    return false
end

local function findGate(addr,name)
    local ignoreName = not name
    local id = nil
    for i, gate in ipairs(gates) do
        if (gateAddressEqual(gate.addr, addr) and (gate.name == name or ignoreName)) then
            return i
        end
    end
    return false
end

local function setIrisButton()
    buttonIris:setText(stargate.irisState())
    if(not irisManual) then
        buttonIris:setBackground(0xff9200)
        if(not (stargate.irisState() == "Open" or stargate.irisState() == "Opening") and outgoingBlacklist and not outgoingAuth) then
            buttonIris:setText("BLACKLIST")
            buttonIris:setBackground(0xff0000)
        end
    elseif (stargate.irisState() == "Open" or stargate.irisState() == "Opening") then
        buttonIris:setBackground(0x00ff00)
    else
        buttonIris:setBackground(0xff0000)
    end
end

local function toogleFromList(list, addr)
    local inList, i = isGateInList(list, addr)
    if (inList) then
        table.remove(list, i)
    else
        table.insert(list, addr)
    end
end

local function saveGatesAdd()
    local gFile = io.open(GATE_LIST, "w")
    for i, gate in ipairs(gates) do
        gFile:write(string.format("%s,%s,%s\n", gate.name, gate.addr,gate.password))
    end
    gFile:close()
end

local function saveConfig()
    local cFile = io.open(CONFIG_FILE, "w")
    local tconf = {}
    for key, val in pairs(config) do
        if (key ~= "blacklist" and key ~= "whitelist") then
            tconf[key] = val
        end
    end
    cFile:write(serialization.serialize(tconf))
    cFile:close()
end

local function saveBlacklist()
    local bFile = io.open(BLACKLIST_FILE, "w")
    for i, g in ipairs(config.blacklist) do
        bFile:write(string.format("%s\n", g))
    end
    bFile:close()
end

local function saveWhitelist()
    local wFile = io.open(WHITELIST_FILE, "w")
    for i, g in ipairs(config.whitelist) do
        wFile:write(string.format("%s\n", g))
    end
    wFile:close()
end

local function gateButtonTouchHandler(widget, eventName, uuid, x, y, button, playerName)
    if (button == 0) then --left click
        if(inputAddr:getValue() == formatAddress(widget.addr)) then
            stargate.dial(widget.addr)
        end
        inputAddr:setText(formatAddress(widget.addr))
        passwordField:setText(widget.password)
    else --rightclick
        if (waitingForConfirmation) then
            return
        end
        local bg = widget:getBackground()
        local fg = widget:getForeground()
        widget:setBackground(fg)
        widget:setForeground(bg)
        root:draw()
        waitingForConfirmation = true
        local e, uuid, xx, yy, button, playerName = event.pull("touch")
        waitingForConfirmation = false
        widget:setBackground(bg)
        widget:setForeground(fg)
        if (not widget:collide(xx, yy)) then
            return
        end
        if (nameInput:getValue() == "") then
            return
        end
        gates[findGate(widget.addr,widget:getText())].name = nameInput:getValue()
        widget:setText(nameInput:getValue())
        saveGatesAdd()
    end
end

local function gateWlButtonTouchHandler(widget, eventName, uuid, x, y, button, playerName)
    toogleFromList(config.whitelist, widget.addr)
    saveWhitelist()
    if (isGateInList(config.whitelist, widget.addr)) then
        widget:setText(string.upper(widget:getText()))
    else
        widget:setText(string.lower(widget:getText()))
    end
end

local function gateBlButtonTouchHandler(widget, eventName, uuid, x, y, button, playerName)
    toogleFromList(config.blacklist, widget.addr)
    saveBlacklist()
    if (isGateInList(config.blacklist, widget.addr)) then
        widget:setText(string.upper(widget:getText()))
    else
        widget:setText(string.lower(widget:getText()))
    end
end

local function gateDlButtonTouchHandler(widget, eventName, uuid, x, y, button, playerName)
    local fg = widget:getForeground()
    if (waitingForConfirmation) then
        return
    end
    local bg = widget:getBackground()
    local fg = widget:getForeground()
    widget:setBackground(fg)
    widget:setForeground(bg)
    root:draw()
    waitingForConfirmation = true
    local e, uuid, xx, yy, button, playerName = event.pull("touch")
    waitingForConfirmation = false
    widget:setBackground(bg)
    widget:setForeground(fg)
    if (not widget:collide(xx, yy)) then
        return
    end
    local id = findGate(widget.addr,widget.linked[1]:getText())
    if (not id) then
        return
    end
    table.remove(gates, id)
    widget:setVisible(false)
    widget:enable(false)
    widget.linked[1]:setVisible(false)
    widget.linked[1]:enable(false)
    widget.linked[2]:setVisible(false)
    widget.linked[2]:enable(false)
    widget.linked[3]:setVisible(false)
    widget.linked[3]:enable(false)
    saveGatesAdd()
end

local function addGateToList(gate)
    local gateListText = gui.widget.Text(LIST_TEXT_X, LIST_TEXT_Y + (#gatesListTexts + 1), 38, 1, 0xffffff, gate.name)
    gateListText.addr = gate.addr
    gateListText.password = gate.password
    gateListText:setCallback(gateButtonTouchHandler)
    gateListText:setBackground(0) --need to be set fo the negativ effect to rename
    mainScreen:addChild(gateListText)
    local gateWlButton = gui.widget.Text(LIST_TEXT_X + 38, LIST_TEXT_Y + (#gatesListTexts + 1), 1, 1, 0, "w")
    gateWlButton.addr = gateListText.addr
    gateWlButton:setBackground(0xffffff)
    gateWlButton:setCallback(gateWlButtonTouchHandler)
    mainScreen:addChild(gateWlButton)
    if (isGateInList(config.whitelist, gate.addr)) then
        gateWlButton:setText(string.upper(gateWlButton:getText()))
    end
    local gateBlButton = gui.widget.Text(LIST_TEXT_X + 39, LIST_TEXT_Y + (#gatesListTexts + 1), 1, 1, 0, "b")
    gateBlButton.addr = gateListText.addr
    gateBlButton:setBackground(0xffffff)
    gateBlButton:setCallback(gateBlButtonTouchHandler)
    mainScreen:addChild(gateBlButton)
    if (isGateInList(config.blacklist, gate.addr)) then
        gateBlButton:setText(string.upper(gateBlButton:getText()))
    end
    local gateDlButton = gui.widget.Text(LIST_TEXT_X + 40, LIST_TEXT_Y + (#gatesListTexts + 1), 1, 1, 0, "X")
    gateDlButton.addr = gateListText.addr
    gateDlButton.linked = {gateListText, gateBlButton, gateWlButton}
    gateDlButton:setBackground(0xff0000)
    gateDlButton:setCallback(gateDlButtonTouchHandler)
    mainScreen:addChild(gateDlButton)
    table.insert(gatesListTexts, gateListText)
end

local function checkNewAddr()
    local remoteAddress = stargate.remoteAddress()
    if (config.saveNewGate) then
        local knonw = false
        for i, gate in ipairs(gates) do
            if (gateAddressEqual(gate.addr, remoteAddress)) then
                knonw = true
                break
            end
        end
        if (not knonw) then
            table.insert(gates, {addr = remoteAddress, name = formatAddress(remoteAddress)})
            saveGatesAdd()
            addGateToList(gates[#gates])
        end
    end
end

local function getGateName(addr)
    for i, gate in ipairs(gates) do
        if (gateAddressEqual(gate.addr, addr)) then
            return gate.name
        end
    end
    return formatAddress(addr)
end

--event handlers===============================================================
local function onStargateStateChange(eventName, componentAddress, toState, fromState)
    --sgStargateStateChange addr to from
    --  Idle -> Dialling -> Opening -> Connected -> Closing -> Idle
    if (fromState == "Idle") then
        irisManual = false
        if(dialDirection == "O") then
            receivedPassword = true
        end
        stargate.closeIris()
        textRemoteAddr:setText(" "..getGateName(stargate.remoteAddress()))
        textRemoteAddr:setForeground(0xff9200)
        if (incomingBlacklist or outgoingBlacklist) then
            textRemoteAddr:setForeground(0xff0000)
        end
    end
    if (toState == "Opening") then
        if (instantDialed) then
            if (dialDim) then
                gateLayer.imageData = gui.Image(GATE_STATE[10])
            else
                gateLayer.imageData = gui.Image(GATE_STATE[7])
            end
        end
    end
    if (toState == "Connected") then
        vortexLayer:setVisible(true)
        if (not incomingBlacklist and not outgoingBlacklist) then
            stargate.openIris()
            textRemoteAddr:setForeground(0x0000ff)
        elseif(not outgoingBlacklist) then
            textRemoteAddr:setForeground(0xff0000)
            stargate.sendMessage("info","blacklist")
        end
        --send irisState to remote gate
        stargate.sendMessage("irisState",stargate.irisState())
    end
    if (fromState == "Connected") then
        vortexLayer:setVisible(false)
    end
    if (toState == "Idle") then
        dialDirection = false
        incomingBlacklist = false
        instantDialed = true
        receivedPassword = false
        irisManual = true
        outgoingAuth = false
        outgoingBlacklist = false
        setIrisButton()
        stargate.openIris()
        textRemoteAddr:setForeground(0xff0000)
        passwordField:setForeground(0xffffff)
        textRemoteAddr:setText(" Idle")
        gateLayer.imageData = gui.Image(GATE_STATE[0])
    end
end
local function onIrisStateChange(eventName, componentAddress, toState, fromState)
    --sgIrisStateChange addr to from
    --  Open -> Closing -> Closed -> Opening -> Open
    --send irisState to remote gate
    irisLayer:setVisible(true)
    if ((toState == "Closing" or toState == "Closed") and (outgoingBlacklist and not outgoingAuth)) then
        irisManual = false
    end
    setIrisButton()
    if (toState == "Opening" or toState == "Closing") then
        irisLayer.imageData = gui.Image(IRIS_STATE[2])
    end
    if (toState == "Open") then
        irisLayer.imageData = gui.Image(IRIS_STATE[1])
    end
    if (toState == "Closed") then
        irisLayer.imageData = gui.Image(IRIS_STATE[3])
    end
    stargate.sendMessage("irisState",stargate.irisState())
end
local function onDialOut(eventName, componentAddress, remoteGateAddress)
    --sgDialOut addr remoteGateAddr
    dialDirection = "O"
    checkNewAddr()
end
local function onDialIn(eventName, componentAddress, remoteGateAddress)
    --sgDialIn addr remoteGateAddr
    dialDirection = "I"
    dialDim = #remoteGateAddress == 9
    if (config.useBlacklist) then
        if (isGateInList(config.blacklist, stargate.remoteAddress())) then
            --stargate.closeIris()
            incomingBlacklist = true
            textRemoteAddr:setForeground(0xff0000)
            if (config.dropBlacklistedConnexions) then
                stargate.disconnect()
            end
        end
    end
    if (config.useWhitelist) then
        incomingBlacklist = (not isGateInList(config.whitelist, stargate.remoteAddress()))
        if (incomingBlacklist) then
            textRemoteAddr:setForeground(0xff0000)
        else
            textRemoteAddr:setForeground(0xff9200)
        end
        if (incomingBlacklist and config.dropBlacklistedConnexions) then
            stargate.disconnect()
        end
    end
    checkNewAddr()
end
local function onChevronEngaded(eventName, componentAddress, chevronID, chevronChar)
    --sgChevronEngaded addr number chevronChar
    instantDialed = false
    if (chevronID > 7) then
        chevronID = chevronID + 1
    end
    gateLayer.imageData = gui.Image(GATE_STATE[chevronID])
    if (chevronID == 7 and stargate.stargateState() == "Dialling") then
        gateLayer.imageData = gui.Image(GATE_STATE[chevronID + 1])
    end
end
local function onMessageReceived(eventName,componentAddress,...)
    --sgMessageRecived addr ...
    local arg=table.pack(...)
    --error(arg[1])
    if(arg[1] == "password") then
        receivedPassword = arg[2] == config.password
        lastPassword = arg[2]
        stargate.sendMessage("auth",receivedPassword)
        if(receivedPassword and not irisManual) then
            stargate.openIris()
        end
    end
    if(arg[1] == "info") then
        if(arg[2] == "blacklist") then
            outgoingBlacklist = true
            textRemoteAddr:setColor(0xff0000)
            stargate.sendMessage("password",passwordField:getValue())
            setIrisButton()
            if(config.savePassword) then
                local id = findGate(stargate.remoteAddress())
                if(gates[id].password ~= passwordField:getValue()) then
                    gates[id].password = passwordField:getValue()
                    saveGatesAdd()
                end
            end
        end
    end
    if(arg[1] == "auth")then
        if(arg[2]) then
            outgoingAuth = true
            passwordField:setForeground(0x00ff00)
            textRemoteAddr:setColor(0x0000ff)
            setIrisButton()
        else
            outgoingAuth = false
            passwordField:setForeground(0xff0000)
            setIrisButton()
        end
    end
    if(arg[1] == "openIris") then 
        if(not irisManual and receivedPassword) then
            stargate.openIris()
        else
            stargate.sendMessage("irisState",stargate.irisState())
        end
    elseif(arg[1] == "closeIris") then
            stargate.closeIris()
    elseif(arg[1] == "getIrisState") then
        stargate.sendMessage("irisState",stargate.irisState())
    elseif(arg[1] == "irisState") then
        if(arg[2] == "Closing" or arg[2] == "Closed") then
            stargate.closeIris()
            if(outgoingBlacklist and not outgoingAuth) then
                irisManual = false
            end
        elseif(not irisManual and receivedPassword or dialDirection == "O") then
            stargate.openIris()
        else
            stargate.sendMessage("irisState",stargate.irisState())
        end
    end
end
--register events
interruptedEvent = event.listen("interrupted", closeApp)
sgStargateStateChangeEvent = event.listen("sgStargateStateChange", onStargateStateChange)
sgIrisStateChangeEvent = event.listen("sgIrisStateChange", onIrisStateChange)
sgDialOutEvent = event.listen("sgDialOut", onDialOut)
sgDialInEvent = event.listen("sgDialIn", onDialIn)
sgChevronEngadedEvent = event.listen("sgChevronEngaged", onChevronEngaded)
sgMessageRecivedEvent = event.listen("sgMessageReceived", onMessageReceived)


--INIT CONFIG==================================================================
--inti config with default values
config = {
    blacklist = {},
    whitelist = {},
    dropBlacklistedConnexions = false,
    useBlacklist = false,
    useWhitelist = false,
    saveNewGate = true,
    savePassword = true,
    password = ""
}
--create the config dir if it doesn't exists already
if (not filesystem.isDirectory(CONFIG_PATH)) then
    filesystem.makeDirectory(CONFIG_PATH)
end
--load the config
if (filesystem.exists(CONFIG_FILE) and not filesystem.isDirectory(GATE_LIST)) then
    local cFile = io.open(CONFIG_FILE, "r")
    local tconf = serialization.unserialize(cFile:read("*a")) or {}
    cFile:close()
    for key, val in pairs(tconf) do
        config[key] = val
    end
end
--load the knonw gates list
if (filesystem.exists(GATE_LIST) and not filesystem.isDirectory(GATE_LIST)) then
    local gFile = io.open(GATE_LIST, "r")
    for line in gFile:lines() do
        if (line ~= "" and line ~= "\n") then
            local gateInfo = {}
            for v in string.gmatch(line, "([^,]+)") do
                table.insert(gateInfo, v)
            end
            table.insert(gates, {addr = gateInfo[2], name = gateInfo[1], password = gateInfo[3]})
        end
    end
end
--load the blacklsit
if (filesystem.exists(BLACKLIST_FILE) and not filesystem.isDirectory(BLACKLIST_FILE)) then
    local blFile = io.open(BLACKLIST_FILE, "r")
    for line in blFile:lines() do
        table.insert(config.blacklist, line)
    end
    blFile:close()
end
--load the whitelist
if (filesystem.exists(WHITELIST_FILE) and not filesystem.isDirectory(WHITELIST_FILE)) then
    local blFile = io.open(WHITELIST_FILE, "r")
    for line in blFile:lines() do
        table.insert(config.whitelist, line)
    end
    blFile:close()
end

--Init screens=================================================================
root = gui.Screen()
touchEvent =
    event.listen(
    "touch",
    function(...)
        root:trigger(...)
    end
)
configScreen = gui.Screen()
root:addChild(configScreen)
configScreen:setVisible(false)
configScreen:enable(false)
mainScreen = gui.Screen()
root:addChild(mainScreen)

local backgroundColor = gui.widget.Rectangle(1, 1, 80, 25, 0x7d7d7d)
mainScreen:addChild(backgroundColor)
configScreen:addChild(backgroundColor)

--MAIN SCREEN==================================================================
--local addr
local textLocalAddr = gui.widget.Text(1, 1, 14, 1, 0x00ff00, " "..formatAddress(stargate.localAddress()))
mainScreen:addChild(textLocalAddr)
--remote addr
textRemoteAddr = gui.widget.Text(16, 1, 14, 1, 0xff0000, "Idle")
mainScreen:addChild(textRemoteAddr)
--disconnect
local buttonDisconnect = gui.widget.Text(1, 25, 12, 1, 0, "Disconnect")
buttonDisconnect:setBackground(0xff0000)
mainScreen:addChild(buttonDisconnect)
buttonDisconnect:setCallback(
    function(...)
        stargate.disconnect()
    end
)
--iris
buttonIris = gui.widget.Text(14, 25, 12, 1, 0, "Close")
setIrisButton()
buttonIris:setCallback(
    function(...)
        irisManual = true
        if (stargate.irisState() == "Open" or stargate.irisState() == "Opening") then
            stargate.closeIris()
        elseif(not outgoingBlacklist or outgoingAuth) then
            stargate.openIris()
        end
    end
)
mainScreen:addChild(buttonIris)
--config
local buttonConfig = gui.widget.Text(27, 25, 12, 1, 0, "Config")
buttonConfig:setBackground(0x969696)
buttonConfig:setCallback(
    function(...)
        mainScreen:setVisible(false)
        mainScreen:enable(false)
        configScreen:setVisible(true)
        --wait a little so no event get processed in the config screen
        event.timer(
            0.1,
            function(...)
                configScreen:enable(true)
            end
        )
        --configScreen:enable(true)
    end
)
mainScreen:addChild(buttonConfig)
--manual dial
inputAddr = gui.widget.Input(DIALLER_X, DIALLER_Y, 11, 1, 0xffffff, "AAAA-AAA-AA")
inputAddr:setBackground(0x000000)
mainScreen:addChild(inputAddr)
local dialRect = gui.widget.Rectangle(DIALLER_X + 11, DIALLER_Y, 6, 1, 0x00ff00)
mainScreen:addChild(dialRect)
dialRect:setCallback(
    function(widget, ...)
        stargate.disconnect()
        stargate.dial(inputAddr:getValue())
    end
)
local dialText = gui.widget.Input(DIALLER_X + 12, DIALLER_Y, 4, 1, 0x000000, "DIAL")
dialText:setBackground(0x00ff00)
dialText.val = inputAddr
mainScreen:addChild(dialText)
--password field
passwordField = gui.widget.Input(PASSWORD_X,PASSWORD_Y,21,1,0xffffff,"")
passwordField:setPlaceholder("*")
mainScreen:addChild(passwordField)
local passwordText = gui.widget.Text(PASSWORD_X+22,PASSWORD_Y,4,1,0,"SEND")
passwordText:setBackground(0x0000ff)
local passwordRect = gui.widget.Rectangle(PASSWORD_X+21,PASSWORD_Y,6,1,0x0000ff)
passwordRect.val = passwordField
passwordRect:setCallback(function(widget,...)
    if(not outgoingAuth) then stargate.sendMessage("password",widget.val:getValue()) end
end)
mainScreen:addChild(passwordRect)
mainScreen:addChild(passwordText)
--Gate list----------------------------
for i, gate in ipairs(gates) do
    if (i > 19) then
        break
    end
    addGateToList(gate)
end
nameInput = gui.widget.Input(2, 23, 40, 1, 0xffffff, "New gate name")
mainScreen:addChild(nameInput)
--Gate img---------------------------------------------------------------------
vortexLayer = gui.widget.Image(GATE_IMG_X + 1, GATE_IMG_Y + 3, VORTEX)
mainScreen:addChild(vortexLayer)
if (not (stargate.stargateState() == "Connected")) then
    vortexLayer:setVisible(false)
end
irisLayer = gui.widget.Image(GATE_IMG_X + 1, GATE_IMG_Y + 3, IRIS_STATE[1])
if (stargate.irisState() == "Offline") then
    irisLayer:setVisible(false)
end
mainScreen:addChild(irisLayer)
gateLayer = gui.widget.Image(GATE_IMG_X, GATE_IMG_Y, GATE_STATE[0])
mainScreen:addChild(gateLayer)

--CONFIG SCREEN================================================================
--Whitelist
buttonWhitelist = gui.widget.Text(2, 2, 18, 1, 0, "Whitelist")
buttonWhitelist:setCallback(
    function(widget, ...)
        config.useWhitelist = not config.useWhitelist
        if (config.useWhitelist) then
            widget:setBackground(0x00ff00)
        else
            widget:setBackground(0xff0000)
        end
    end
)
if (config.useWhitelist) then
    buttonWhitelist:setBackground(0x00ff00)
else
    buttonWhitelist:setBackground(0xff0000)
end
configScreen:addChild(buttonWhitelist)
--Blacklist
buttonBlacklist = gui.widget.Text(2, 4, 18, 1, 0, "Blacklist")
buttonBlacklist:setCallback(
    function(widget, ...)
        config.useBlacklist = not config.useBlacklist
        if (config.useBlacklist) then
            widget:setBackground(0x00ff00)
        else
            widget:setBackground(0xff0000)
        end
    end
)
if (config.useBlacklist) then
    buttonBlacklist:setBackground(0x00ff00)
else
    buttonBlacklist:setBackground(0xff0000)
end
configScreen:addChild(buttonBlacklist)
--blacklist drop
local buttonDropBlacklistConnexion = gui.widget.Text(2, 6, 18, 1, 0, "Drop if blacklist")
buttonDropBlacklistConnexion:setCallback(
    function(widget, ...)
        config.dropBlacklistedConnexions = not config.dropBlacklistedConnexions
        if (config.dropBlacklistedConnexions) then
            widget:setBackground(0x00ff00)
        else
            widget:setBackground(0xff0000)
        end
    end
)
if (config.dropBlacklistedConnexions) then
    buttonDropBlacklistConnexion:setBackground(0x00ff00)
else
    buttonDropBlacklistConnexion:setBackground(0xff0000)
end
configScreen:addChild(buttonDropBlacklistConnexion)
--autoLearn
local buttonLearnNewGates = gui.widget.Text(2, 8, 18, 1, 0, "Learn new gates")
buttonLearnNewGates:setCallback(
    function(widget, ...)
        config.saveNewGate = not config.saveNewGate
        if (config.saveNewGate) then
            widget:setBackground(0x00ff00)
        else
            widget:setBackground(0xff0000)
        end
    end
)
if (config.saveNewGate) then
    buttonLearnNewGates:setBackground(0x00ff00)
else
    buttonLearnNewGates:setBackground(0xff0000)
end
configScreen:addChild(buttonLearnNewGates)
--savePassword
local buttonSavePassword = gui.widget.Text(2,10,18,1,0,"Save password")
buttonSavePassword:setCallback(
    function(widget, ...)
        config.savePassword = not config.savePassword
        if (config.savePassword) then
            widget:setBackground(0x00ff00)
        else
            widget:setBackground(0xff0000)
        end
    end
)
if (config.savePassword) then
    buttonSavePassword:setBackground(0x00ff00)
else
    buttonSavePassword:setBackground(0xff0000)
end
configScreen:addChild(buttonSavePassword)
--password
local passwordLabel = gui.widget.Text(2,12,15,1,0x000000,"Iris password :")
passwordLabel:setBackground(0x7d7d7d)
configScreen:addChild(passwordLabel)
local passwordConfigField = gui.widget.Input(passwordLabel:getX()+passwordLabel:getWidth()+1,passwordLabel:getY(),20,1,0xffffff,"")
passwordConfigField:setPlaceholder("*")
configScreen:addChild(passwordConfigField)
--save
local buttonSave = gui.widget.Text(1, 25, 12, 1, 0, "Save")
buttonSave:setBackground(0x00ff00)
buttonSave:setCallback(
    function(...)
        config.password = passwordConfigField:getValue()
        --wait a little so no event get processed in the main screen
        event.timer(
            0.1,
            function(...)
                mainScreen:enable(true)
            end
        )
        mainScreen:setVisible(true)
        configScreen:setVisible(false)
        configScreen:enable(false)
        saveConfig()
    end
)
configScreen:addChild(buttonSave)
--cancel
local buttonCancel = gui.widget.Text(14, 25, 12, 1, 0, "Cancel")
buttonCancel:setBackground(0xff0000)
buttonCancel:setCallback(
    function(...)
        --wait a little so no event get processed in the main screen
        event.timer(
            0.1,
            function(...)
                mainScreen:enable(true)
            end
        )
        mainScreen:setVisible(true)
        configScreen:setVisible(false)
        configScreen:enable(false)
    end
)
configScreen:addChild(buttonCancel)
--END GUI======================================================================
--Init screen
gpu.setResolution(80, 25)
--disconnect the gate as a safety
if (stargate.stargateState() ~= "Idle") then
    stargate.disconnect()
else
    stargate.openIris()
end
--main loop
while (run) do
    root:draw()
    os.sleep() --sleep to handle events
end
closeApp()
