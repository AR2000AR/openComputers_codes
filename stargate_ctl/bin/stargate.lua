local stargate                      = require("component").stargate
local gpu                           = require("component").gpu
local io                            = require "io"
local event                         = require "event"
local os                            = require "os"
local filesystem                    = require "filesystem"
local serialization                 = require("serialization")
local gui                           = require "libGUI"

--CONST
local CONFIG_PATH                   = "/etc/stargate/"
local WHITELIST_FILE                = CONFIG_PATH .. "whitelist.csv"
local BLACKLIST_FILE                = CONFIG_PATH .. "blacklist.csv"
local CONFIG_FILE                   = CONFIG_PATH .. "stargate.cfg"
local GATE_LIST                     = CONFIG_PATH .. "gates.csv"
local IMG_ROOT                      = "/usr/share/stargate/"
local IRIS_STATE                    = {IMG_ROOT .. "iris1.pam", IMG_ROOT .. "iris2.pam", IMG_ROOT .. "iris3.pam"}
local GATE_STATE                    = {[0] = IMG_ROOT .. "sg00.pam", IMG_ROOT .. "sg01.pam", IMG_ROOT .. "sg02.pam", IMG_ROOT .. "sg03.pam", IMG_ROOT .. "sg04.pam", IMG_ROOT .. "sg05.pam", IMG_ROOT .. "sg06.pam", IMG_ROOT .. "sg07.pam", IMG_ROOT .. "sg08.pam", IMG_ROOT .. "sg09.pam", IMG_ROOT .. "sg10.pam"}
local VORTEX                        = IMG_ROOT .. "vortex.pam"

--gidget position
local GATE_IMG_X, GATE_IMG_Y        = 48, -1
local LIST_TEXT_X, LIST_TEXT_Y      = 2, 3 - 1
local DIALLER_X, DIALLER_Y          = GATE_IMG_X + 6, GATE_IMG_Y + 23
local PASSWORD_X, PASSWORD_Y        = GATE_IMG_X + 1, DIALLER_Y + 1

--colors
local THEME                         = {BACKGROUNDS = {}, FOREGROUNDS = {}}
THEME.BACKGROUNDS.BACKGROUND        = 0x7d7d7d
THEME.FOREGROUNDS.LOCAL_ADDRESSE    = 0x00ff00
THEME.BACKGROUNDS.LOCAL_ADDRESSE    = 0x000000
THEME.FOREGROUNDS.REMOTE_ADRESSE    = {IDLE = 0xffffff, DIALLLING = 0xff9200, CONNECTED = 0x0000ff, BLACLISTED = 0xff0000}
THEME.BACKGROUNDS.REMOTE_ADRESSE    = {IDLE = 0x000000, DIALLLING = 0x000000, CONNECTED = 0x000000, BLACLISTED = 0x000000}
THEME.FOREGROUNDS.IRIS_BUTTON       = {OPEN = 0x000000, CLOSED = 0x000000, AUTO = 0x000000, BLACKLIST = 0x000000}
THEME.BACKGROUNDS.IRIS_BUTTON       = {OPEN = 0x00ff00, CLOSED = 0xff0000, AUTO = 0xff9200, BLACKLIST = 0xff0000}
THEME.FOREGROUNDS.DISCONNECT_BUTTON = 0x000000
THEME.BACKGROUNDS.DISCONNECT_BUTTON = 0xff0000
THEME.FOREGROUNDS.CONFIG_BUTTON     = 0x000000
THEME.BACKGROUNDS.CONFIG_BUTTON     = 0x969696
THEME.FOREGROUNDS.DIAL_BUTTON       = 0x000000
THEME.BACKGROUNDS.DIAL_BUTTON       = 0x00ff00
THEME.FOREGROUNDS.ADDRESS_FILED     = {DEFAULT = 0xffffff, DIALLED = 0x00ff00, UNKNOWN = 0xff9200}
THEME.BACKGROUNDS.ADDRESS_FILED     = {DEFAULT = 0x000000, DIALLED = 0x000000, UNKNOWN = 0x000000}
THEME.FOREGROUNDS.PASSWORD_FILED    = {DEFAULT = 0xffffff, OK = 0x00ff00, NOK = 0xff0000}
THEME.BACKGROUNDS.PASSWORD_FILED    = {DEFAULT = 0x000000, OK = 0x000000, NOK = 0x000000}
THEME.FOREGROUNDS.PASSWORD_BUTTON   = 0x000000
THEME.BACKGROUNDS.PASSWORD_BUTTON   = 0x0000ff
THEME.FOREGROUNDS.NAME_FIELD        = 0xffffff
THEME.BACKGROUNDS.NAME_FIELD        = 0x000000
THEME.FOREGROUNDS.GATE_LIST_LABEL   = 0xffffff
THEME.BACKGROUNDS.GATE_LIST_LABEL   = 0x000000
THEME.FOREGROUNDS.GATE_LIST_WL      = 0x000000
THEME.BACKGROUNDS.GATE_LIST_WL      = 0xffffff
THEME.FOREGROUNDS.GATE_LIST_BL      = 0x000000
THEME.BACKGROUNDS.GATE_LIST_BL      = 0xffffff
THEME.FOREGROUNDS.GATE_LIST_DL      = 0x000000
THEME.BACKGROUNDS.GATE_LIST_DL      = 0xff0000
THEME.FOREGROUNDS.CONFIG_TOGGLE     = {ON = 0x000000, OFF = 0x000000}
THEME.BACKGROUNDS.CONFIG_TOGGLE     = {ON = 0x00ff00, OFF = 0xff0000}
THEME.FOREGROUNDS.C_TEXT            = 0x000000
THEME.BACKGROUNDS.C_TEXT            = THEME.BACKGROUNDS.BACKGROUND
THEME.FOREGROUNDS.C_PASSWORD_FILED  = 0xffffff
THEME.BACKGROUNDS.C_PASSWORD_FILED  = 0x000000
THEME.FOREGROUNDS.C_SAVE_BUTTON     = 0x000000
THEME.BACKGROUNDS.C_SAVE_BUTTON     = 0x00ff00
THEME.FOREGROUNDS.C_CANCEL_BUTTON   = 0x000000
THEME.BACKGROUNDS.C_CANCEL_BUTTON   = 0xff0000


--global event listeners ID
local touchEvent                 = nil
local sgStargateStateChangeEvent = nil
local sgIrisStateChangeEvent     = nil
local sgDialOutEvent             = nil
local sgDialInEvent              = nil
local sgChevronEngadedEvent      = nil
local sgMessageRecivedEvent      = nil
local interruptedEvent           = nil

--global vars
local oldResX, oldResY           = gpu.getResolution()
local run                        = true
local config                     = nil
local gates                      = {}
local waitingForConfirmation     = false
local irisManual                 = true
local dialDirection              = ""
local dialDim                    = false
local instantDialed              = true
local outgoingBlacklist          = false
local outgoingAuth               = false
local receivedPassword           = false
local incomingBlacklist          = false
local remoteIris                 = "Offline"

--global widgets
local mainScreen                 = nil
local textRemoteAddr             = nil
local configScreen               = nil
local root                       = nil
local buttonIris                 = nil
local vortexLayer                = nil
local gateLayer                  = nil
local irisLayer                  = nil
local gatesListTexts             = {}
local nameInput                  = nil
local buttonWhitelist            = nil
local buttonBlacklist            = nil
local inputAddr                  = nil
local passwordField              = nil

local function closeApp(...)
    if (touchEvent) then event.cancel(touchEvent) end
    if (sgStargateStateChangeEvent) then event.cancel(sgStargateStateChangeEvent) end
    if (sgIrisStateChangeEvent) then event.cancel(sgIrisStateChangeEvent) end
    if (sgDialOutEvent) then event.cancel(sgDialOutEvent) end
    if (sgDialInEvent) then event.cancel(sgDialInEvent) end
    if (sgChevronEngadedEvent) then event.cancel(sgChevronEngadedEvent) end
    if (sgMessageRecivedEvent) then event.cancel(sgMessageRecivedEvent) end
    if (interruptedEvent) then event.cancel(interruptedEvent) end
    if (stargate) then
        stargate.disconnect();
        stargate.closeIris()
    end
    run = false
    gpu.setResolution(oldResX, oldResY)
    require("term").clear()
    os.exit(0)
end

local function gateAddressEqual(a1, a2)
    --return true if the addresses a1 and a2 point to the same gate
    --remove "-" from the addresses
    a1 = string.gsub(string.upper(a1), "-", "")
    a2 = string.gsub(string.upper(a2), "-", "")
    local a1Coord = string.sub(a1, 0, 7)
    local a2Coord = string.sub(a2, 0, 7)
    local a1Extra = string.sub(a1, 8)
    local a2Extra = string.sub(a2, 8)
    if (a1 == a2) then return true end
    if ("" == a1Extra or "" == a2Extra) then return a1Coord == a2Coord end
    return false
end

local function formatAddress(add)
    --format the addresse in a pretty format AAAA-AAA-AA
    add = string.gsub(string.upper(add), "-", "")
    local fAdd = string.format("%s-%s", string.sub(add, 0, 4), string.sub(add, 5, 7))
    if (#add > 7) then fAdd = string.format("%s-%s", fAdd, string.sub(add, 8)) end
    return fAdd
end

local function isGateInList(list, add)
    --look for a gate addresse in a table
    for i, listAdd in ipairs(list) do
        if (gateAddressEqual(add, listAdd)) then return true, i end
    end
    return false
end

local function findGate(addr, name)
    --find a gate in the global gates table
    local ignoreName = not name --if no name is provided we ignore it
    for i, gate in ipairs(gates) do
        if (gateAddressEqual(gate.addr, addr) and (gate.name == name or ignoreName)) then return i end
    end
    return false
end

local function setIrisButton()
    --change the iris button widgets property depending on the current context
    local irisState = stargate.irisState()
    buttonIris:enable(irisState == remoteIris or remoteIris == "Offline")
    if (not remoteIris == "Offline") then
        if (irisState == "Open" and remoteIris == "Opening") then
            irisState = remoteIris
        elseif (irisState == "Closed" and remoteIris == "Closing") then
            irisState = remoteIris
        end
    end
    buttonIris:setText(irisState)
    if (not irisManual) then
        buttonIris:setBackground(THEME.BACKGROUNDS.IRIS_BUTTON.AUTO)
        if (not (irisState == "Open" or irisState == "Opening") and outgoingBlacklist and not outgoingAuth) then
            buttonIris:setText("BLACKLIST")
            buttonIris:setBackground(THEME.BACKGROUNDS.IRIS_BUTTON.BLACKLIST)
        end
    elseif (irisState == "Open" or irisState == "Opening") then
        buttonIris:setBackground(THEME.BACKGROUNDS.IRIS_BUTTON.OPEN)
    else
        buttonIris:setBackground(THEME.BACKGROUNDS.IRIS_BUTTON.CLOSED)
    end
end

local function toogleFromList(list, addr)
    --add the addr in the list if it is not already in it, else remove it
    --used for the blacklist and whitelist
    local inList, i = isGateInList(list, addr)
    if (inList) then
        table.remove(list, i)
    else
        table.insert(list, addr)
    end
end

local function saveGatesAdd()
    --save the gates table to a csv file
    local gFile = io.open(GATE_LIST, "w")
    if (not gFile) then return end
    for i, gate in ipairs(gates) do
        gFile:write(string.format("%s,%s,%s\n", gate.name, gate.addr, gate.password or ""))
    end
    gFile:close()
end

local function saveConfig()
    --save the config table to a file
    local cFile = io.open(CONFIG_FILE, "w")
    if (not cFile) then return end
    local tconf = {}
    for key, val in pairs(config) do
        --we want to ignore the blacklist and whitelist as they are saved in differents files
        if (key ~= "blacklist" and key ~= "whitelist") then tconf[key] = val end
    end
    cFile:write(serialization.serialize(tconf))
    cFile:close()
end

local function saveList(list, fileName)
    --save table in a file. One entry per line
    local wFile = io.open(fileName, "w")
    if (not wFile) then return end
    for i, g in ipairs(list) do
        wFile:write(string.format("%s\n", g))
    end
    wFile:close()
end

local function saveBlacklist()
    saveList(config.blacklist, BLACKLIST_FILE)
end

local function saveWhitelist()
    saveList(config.whitelist, WHITELIST_FILE)
end

local function gateButtonTouchHandler(widget, eventName, uuid, x, y, button, playerName)
    if (button == 0) then --left click
        if (inputAddr:getValue() == formatAddress(widget.addr)) then stargate.dial(widget.addr) end
        inputAddr:setText(formatAddress(widget.addr))
        passwordField:setText(widget.password)
    else --rightclick
        if (waitingForConfirmation) then return end --do nothing if a other widget is wating for a confirmation click
        --inverse the colors
        local bg = widget:getBackground()
        local fg = widget:getForeground()
        widget:setBackground(fg)
        widget:setForeground(bg)
        root:draw() --force a screen refresh
        waitingForConfirmation = true
        local _, _, xx, yy = event.pull("touch") --listen for touch everywhere
        waitingForConfirmation = false
        --restore the colors
        widget:setBackground(bg)
        widget:setForeground(fg)
        if (not widget:collide(xx, yy)) then return end --if not on this widget the abord
        if (nameInput:getValue() == "") then return end --if no name is in the Input widget abord
        gates[findGate(widget.addr, widget:getText())].name = nameInput:getValue() --update the gate data
        widget:setText(nameInput:getValue()) --update the widget text
        saveGatesAdd() --save the new data
    end
end

local function gateWlButtonTouchHandler(widget, eventName, uuid, x, y, button, playerName)
    --whitelist button handler
    toogleFromList(config.whitelist, widget.addr)
    saveWhitelist()
    if (isGateInList(config.whitelist, widget.addr)) then
        widget:setText(string.upper(widget:getText()))
    else
        widget:setText(string.lower(widget:getText()))
    end
end

local function gateBlButtonTouchHandler(widget, eventName, uuid, x, y, button, playerName)
    --blacklist button handler
    toogleFromList(config.blacklist, widget.addr)
    saveBlacklist()
    if (isGateInList(config.blacklist, widget.addr)) then
        widget:setText(string.upper(widget:getText()))
    else
        widget:setText(string.lower(widget:getText()))
    end
end

local function gateDlButtonTouchHandler(widget, eventName, uuid, x, y, button, playerName)
    if (waitingForConfirmation) then return end
    --inverse colors
    local bg = widget:getBackground()
    local fg = widget:getForeground()
    widget:setBackground(fg)
    widget:setForeground(bg)
    root:draw()
    waitingForConfirmation = true
    local _, _, xx, yy = event.pull("touch") --listen for touch everywhere
    waitingForConfirmation = false
    --restor colors
    widget:setBackground(bg)
    widget:setForeground(fg)
    if (not widget:collide(xx, yy)) then return end --if touch elsewhere abord
    local id = findGate(widget.addr, widget.linked[1]:getText())
    if (not id) then return end
    --remove the gate from the list
    table.remove(gates, id)
    --hide the related widgets
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
    if (#gatesListTexts > 19) then return end --screen only have space for 19 gates
    --gate label
    local gateListText = gui.widget.Text(LIST_TEXT_X, LIST_TEXT_Y + (#gatesListTexts + 1), 38, 1, THEME.FOREGROUNDS.GATE_LIST_LABEL, gate.name)
    gateListText.addr = gate.addr
    gateListText.password = gate.password
    gateListText:setCallback(gateButtonTouchHandler)
    gateListText:setBackground(THEME.BACKGROUNDS.GATE_LIST_LABEL) --need to be set for the color swap effect when renaming
    mainScreen:addChild(gateListText)
    --whitelist button
    local gateWlButton = gui.widget.Text(LIST_TEXT_X + 38, LIST_TEXT_Y + (#gatesListTexts + 1), 1, 1, THEME.FOREGROUNDS.GATE_LIST_WL, "w")
    gateWlButton.addr = gateListText.addr
    gateWlButton:setBackground(THEME.BACKGROUNDS.GATE_LIST_WL)
    gateWlButton:setCallback(gateWlButtonTouchHandler)
    mainScreen:addChild(gateWlButton)
    if (isGateInList(config.whitelist, gate.addr)) then gateWlButton:setText(string.upper(gateWlButton:getText())) end
    --blacklist button
    local gateBlButton = gui.widget.Text(LIST_TEXT_X + 39, LIST_TEXT_Y + (#gatesListTexts + 1), 1, 1, THEME.FOREGROUNDS.GATE_LIST_BL, "b")
    gateBlButton.addr = gateListText.addr
    gateBlButton:setBackground(THEME.BACKGROUNDS.GATE_LIST_BL)
    gateBlButton:setCallback(gateBlButtonTouchHandler)
    mainScreen:addChild(gateBlButton)
    if (isGateInList(config.blacklist, gate.addr)) then gateBlButton:setText(string.upper(gateBlButton:getText())) end
    --delete button
    local gateDlButton = gui.widget.Text(LIST_TEXT_X + 40, LIST_TEXT_Y + (#gatesListTexts + 1), 1, 1, THEME.FOREGROUNDS.GATE_LIST_DL, "X")
    gateDlButton.addr = gateListText.addr
    gateDlButton.linked = {gateListText, gateBlButton, gateWlButton}
    gateDlButton:setBackground(THEME.BACKGROUNDS.GATE_LIST_DL)
    gateDlButton:setCallback(gateDlButtonTouchHandler)
    mainScreen:addChild(gateDlButton)
    table.insert(gatesListTexts, gateListText)
end

local function checkNewAddr()
    --check the current remote address against the known gates list for new gates
    local remoteAddress = stargate.remoteAddress()
    if (not (remoteAddress ~= "" and config.saveNewGate)) then return end
    if (not findGate(remoteAddress)) then
        table.insert(gates, {addr = remoteAddress, name = formatAddress(remoteAddress)})
        saveGatesAdd()
        addGateToList(gates[#gates]) --add the gate to the screen
    end
end

local function getGateName(addr)
    --get the name of a gate form her addresse
    --if no gate is found, return the formated addresse
    for _, gate in ipairs(gates) do
        if (gateAddressEqual(gate.addr, addr)) then return gate.name end
    end
    return formatAddress(addr)
end

--event handlers===============================================================
local function onStargateStateChange(eventName, componentAddress, toState, fromState)
    --sgStargateStateChange addr to from
    --  Idle -> Dialling -> Opening -> Connected -> Closing -> Idle
    if (fromState == "Idle") then
        --take control of the iris
        irisManual = false
        --if the connxion is outgoing, assume the recived password is correct to allow local iris control
        if (dialDirection == "O") then receivedPassword = true end
        stargate.closeIris() --close the iris to protect from the event horizon
        textRemoteAddr:setText(" " .. getGateName(stargate.remoteAddress()))
        textRemoteAddr:setForeground(THEME.FOREGROUNDS.REMOTE_ADRESSE.DIALLLING)
        inputAddr:setText(formatAddress(stargate.remoteAddress()))
        if (incomingBlacklist or outgoingBlacklist) then textRemoteAddr:setForeground(THEME.FOREGROUNDS.REMOTE_ADRESSE.BLACLISTED) end
    end
    if (toState == "Opening") then
        if (instantDialed) then
            --if the gate was "instant dialled" no sgChevronEngadedEvent where recived
            --in this case, we need to set the chevron img here
            if (dialDim) then
                gateLayer.imageData = gui.Image(GATE_STATE[10])
            else
                gateLayer.imageData = gui.Image(GATE_STATE[7])
            end
        end
    end
    if (toState == "Connected") then
        textRemoteAddr:setForeground(THEME.FOREGROUNDS.REMOTE_ADRESSE.CONNECTED)
        inputAddr:setForeground(THEME.FOREGROUNDS.ADDRESS_FILED.UNKNOWN)
        vortexLayer:setVisible(true)
        if (incomingBlacklist) then
            --warn the other side that it is blacklisted
            stargate.sendMessage("info", "blacklist")
        end
        if (incomingBlacklist or outgoingBlacklist) then
            textRemoteAddr:setForeground(THEME.FOREGROUNDS.REMOTE_ADRESSE.BLACLISTED)
        end
        if (dialDirection == "O" and not outgoingBlacklist) then
            --if there is no blacklist, open the iris
            stargate.openIris()
        end
        --stargate.sendMessage("irisState", stargate.irisState())
    end
    if (fromState == "Connected") then vortexLayer:setVisible(false) end
    if (toState == "Idle") then
        --reset gobal variables
        dialDirection     = ""
        incomingBlacklist = false
        instantDialed     = true
        receivedPassword  = false
        irisManual        = true
        outgoingAuth      = false
        outgoingBlacklist = false
        remoteIris        = "Offline"
        --open the iris
        stargate.openIris()
        --reset widgets colors and text
        setIrisButton()
        textRemoteAddr:setForeground(THEME.FOREGROUNDS.REMOTE_ADRESSE.IDLE)
        passwordField:setForeground(THEME.FOREGROUNDS.PASSWORD_FILED.DEFAULT)
        textRemoteAddr:setText("Idle")
        inputAddr:setForeground(THEME.FOREGROUNDS.ADDRESS_FILED.DEFAULT)
        --reset gate img to the first state
        gateLayer.imageData = gui.Image(GATE_STATE[0])
    end
end

local function onIrisStateChange(eventName, componentAddress, toState, fromState)
    --sgIrisStateChange addr to from
    --  Open -> Closing -> Closed -> Opening -> Open
    irisLayer:setVisible(true)
    --restor iris to auto if was forced close by the remote gate
    if ((toState == "Closing" or toState == "Closed") and (outgoingBlacklist and not outgoingAuth)) then irisManual = false end
    setIrisButton()
    --update the iris img
    if (toState == "Opening" or toState == "Closing") then irisLayer.imageData = gui.Image(IRIS_STATE[2]) end
    if (toState == "Open") then irisLayer.imageData = gui.Image(IRIS_STATE[1]) end
    if (toState == "Closed") then irisLayer.imageData = gui.Image(IRIS_STATE[3]) end
    --send irisState to remote gate
    stargate.sendMessage("irisState", stargate.irisState())
end

local function onDialOut(eventName, componentAddress, remoteGateAddress)
    --sgDialOut addr remoteGateAddr
    dialDirection = "O"
    checkNewAddr()
end

local function onDialIn(eventName, componentAddress, remoteGateAddress)
    --sgDialIn addr remoteGateAddr
    dialDirection = "I"
    --the event only return the correct number of chevron
    --we save this info in case the gate was instant dialled to be able to lit the correct number of chevron
    dialDim = #remoteGateAddress == 9
    --set text to dialling color
    textRemoteAddr:setForeground(THEME.FOREGROUNDS.REMOTE_ADRESSE.DIALLLING)
    incomingBlacklist = (
        (config.useBlacklist and isGateInList(config.blacklist, stargate.remoteAddress()))
        or
        (config.useWhitelist and not isGateInList(config.whitelist, stargate.remoteAddress()))
        )
    if (incomingBlacklist) then
        textRemoteAddr:setForeground(THEME.FOREGROUNDS.REMOTE_ADRESSE.BLACLISTED)
        if (config.dropBlacklistedConnexions) then stargate.disconnect() end
    end
    --if gate is not blacklisted, there is no need for the password
    receivedPassword = not incomingBlacklist
    checkNewAddr()
end

local function onChevronEngaded(eventName, componentAddress, chevronID, chevronChar)
    --sgChevronEngaded addr number chevronChar
    instantDialed = false
    if (chevronID > 7) then chevronID = chevronID + 1 end --chevron 8 and 9 are used
    gateLayer.imageData = gui.Image(GATE_STATE[chevronID])
    --if the gate is still dialling, skip the img 7 (fully dialled 7 chevron)
    if (chevronID == 7 and stargate.stargateState() == "Dialling") then gateLayer.imageData = gui.Image(GATE_STATE[chevronID + 1]) end
end

local function onMessageReceived(eventName, componentAddress, ...)
    --sgMessageRecived addr ...
    local arg = table.pack(...)
    inputAddr:setForeground(THEME.FOREGROUNDS.ADDRESS_FILED.DIALLED)
    --error(arg[1])
    if (arg[1] == "password") then --received a password from the other gate
        receivedPassword = arg[2] == config.password
        stargate.sendMessage("auth", receivedPassword)
        if (receivedPassword and not irisManual) then stargate.openIris() end
    end
    if (arg[1] == "info") then --info sent by the other gate
        if (arg[2] == "blacklist") then
            outgoingBlacklist = true
            textRemoteAddr:setColor(THEME.FOREGROUNDS.REMOTE_ADRESSE.BLACLISTED)
            --try to send the password
            stargate.sendMessage("password", passwordField:getValue())
            setIrisButton() --iris button need to be updated
        end
    end
    if (arg[1] == "auth") then
        if (arg[2]) then
            outgoingAuth = true
            passwordField:setForeground(THEME.FOREGROUNDS.PASSWORD_FILED.OK)
            textRemoteAddr:setColor(THEME.FOREGROUNDS.REMOTE_ADRESSE.CONNECTED)
            setIrisButton()
            --save the correct password
            if (config.savePassword) then
                local id = findGate(stargate.remoteAddress())
                if (gates[id].password ~= passwordField:getValue()) then
                    gates[id].password = passwordField:getValue()
                    saveGatesAdd()
                end
            end
        else
            outgoingAuth = false
            passwordField:setForeground(THEME.FOREGROUNDS.PASSWORD_FILED.NOK)
            setIrisButton()
        end
    end
    if (arg[1] == "openIris") then
        if (not irisManual and receivedPassword) then
            --if iris is in automatic mod and the password is correct (defaut to true when not blacklisted)
            stargate.openIris()
        else
            --else send the iris state to the other side so it is still in sync
            stargate.sendMessage("irisState", stargate.irisState())
        end
    elseif (arg[1] == "closeIris") then
        stargate.closeIris()
    elseif (arg[1] == "getIrisState") then
        stargate.sendMessage("irisState", stargate.irisState())
    elseif (arg[1] == "irisState") then
        remoteIris = arg[2]
        if (arg[2] == "Closing" or arg[2] == "Closed") then
            stargate.closeIris()
            if (outgoingBlacklist and not outgoingAuth) then irisManual = false end
        elseif (not irisManual and receivedPassword or dialDirection == "O") then
            stargate.openIris()
        else
            --send iris state if we refused to open
            stargate.sendMessage("irisState", stargate.irisState())
        end
        setIrisButton()
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
if (not filesystem.isDirectory(CONFIG_PATH)) then filesystem.makeDirectory(CONFIG_PATH) end
--load the config
if (filesystem.exists(CONFIG_FILE) and not filesystem.isDirectory(CONFIG_FILE)) then
    local cFile = io.open(CONFIG_FILE, "r")
    if (cFile) then
        local tconf = serialization.unserialize(cFile:read("*a")) or {}
        cFile:close()
        for key, val in pairs(tconf) do
            config[key] = val
        end
    end
end
if (config.useBlacklist and config.useWhitelist) then config.useBlacklist = false end
--load the knonw gates list
if (filesystem.exists(GATE_LIST) and not filesystem.isDirectory(GATE_LIST)) then
    local gFile = io.open(GATE_LIST, "r")
    if (gFile) then
        for line in gFile:lines() do
            if (line ~= "" and line ~= "\n") then
                local gateInfo = {}
                for v in string.gmatch(line, "([^,]+)") do
                    table.insert(gateInfo, v)
                end
                table.insert(gates, {addr = gateInfo[2], name = gateInfo[1], password = gateInfo[3]})
            end
        end
        gFile:close()
    end
end
--load the blacklsit
if (filesystem.exists(BLACKLIST_FILE) and not filesystem.isDirectory(BLACKLIST_FILE)) then
    local blFile = io.open(BLACKLIST_FILE, "r")
    if (blFile) then
        for line in blFile:lines() do
            table.insert(config.blacklist, line)
        end
        blFile:close()
    end
end
--load the whitelist
if (filesystem.exists(WHITELIST_FILE) and not filesystem.isDirectory(WHITELIST_FILE)) then
    local blFile = io.open(WHITELIST_FILE, "r")
    if (blFile) then
        for line in blFile:lines() do
            table.insert(config.whitelist, line)
        end
        blFile:close()
    end
end

--Init screens=================================================================
--root screen
root = gui.Screen()
touchEvent = event.listen("touch", function(...) root:trigger(...) end)
--config screen
configScreen = gui.Screen()
root:addChild(configScreen)
configScreen:setVisible(false) --start hidden
configScreen:enable(false)
--main screen
mainScreen = gui.Screen()
root:addChild(mainScreen)

--background
local backgroundColor = gui.widget.Rectangle(1, 1, 80, 25, THEME.BACKGROUNDS.BACKGROUND)
mainScreen:addChild(backgroundColor)
configScreen:addChild(backgroundColor)

--MAIN SCREEN==================================================================
--local addr
local textLocalAddr = gui.widget.Text(1, 1, 14, 1, THEME.FOREGROUNDS.LOCAL_ADDRESSE, " " .. formatAddress(stargate.localAddress()))
mainScreen:addChild(textLocalAddr)
--remote addr
textRemoteAddr = gui.widget.Text(16, 1, 14, 1, THEME.FOREGROUNDS.REMOTE_ADRESSE.IDLE, "Idle")
mainScreen:addChild(textRemoteAddr)
--disconnect
local buttonDisconnect = gui.widget.Text(1, 25, 12, 1, THEME.FOREGROUNDS.DISCONNECT_BUTTON, "Disconnect")
buttonDisconnect:setBackground(THEME.BACKGROUNDS.DISCONNECT_BUTTON)
mainScreen:addChild(buttonDisconnect)
buttonDisconnect:setCallback(function(...) stargate.disconnect() end)
--iris
buttonIris = gui.widget.Text(14, 25, 12, 1, THEME.FOREGROUNDS.IRIS_BUTTON.CLOSED, "Closed")
setIrisButton()
buttonIris:setCallback(function(...)
    irisManual = true
    if (stargate.irisState() == "Open" or stargate.irisState() == "Opening") then
        stargate.closeIris()
    elseif (not outgoingBlacklist or outgoingAuth) then
        stargate.openIris()
    end
end)
mainScreen:addChild(buttonIris)
--config
local buttonConfig = gui.widget.Text(27, 25, 12, 1, THEME.FOREGROUNDS.CONFIG_BUTTON, "Config")
buttonConfig:setBackground(THEME.BACKGROUNDS.CONFIG_BUTTON)
buttonConfig:setCallback(function(...)
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
end)
mainScreen:addChild(buttonConfig)
--manual dial
inputAddr = gui.widget.Input(DIALLER_X, DIALLER_Y, 11, 1, THEME.FOREGROUNDS.ADDRESS_FILED.DEFAULT, "AAAA-AAA-AA")
inputAddr:setBackground(THEME.BACKGROUNDS.ADDRESS_FILED.DEFAULT)
mainScreen:addChild(inputAddr)
local dialRect = gui.widget.Rectangle(DIALLER_X + 11, DIALLER_Y, 6, 1, THEME.BACKGROUNDS.DIAL_BUTTON)
mainScreen:addChild(dialRect)
dialRect:setCallback(function(widget, ...)
    stargate.disconnect()
    stargate.dial(inputAddr:getValue())
end)
local dialText = gui.widget.Input(DIALLER_X + 12, DIALLER_Y, 4, 1, THEME.FOREGROUNDS.DIAL_BUTTON, "DIAL")
dialText:setBackground(THEME.BACKGROUNDS.DIAL_BUTTON)
dialText.val = inputAddr
mainScreen:addChild(dialText)
--password field
passwordField = gui.widget.Input(PASSWORD_X, PASSWORD_Y, 21, 1, THEME.FOREGROUNDS.PASSWORD_FILED.DEFAULT, "", "*")
mainScreen:addChild(passwordField)
local passwordText = gui.widget.Text(PASSWORD_X + 22, PASSWORD_Y, 4, 1, THEME.FOREGROUNDS.PASSWORD_BUTTON, "SEND")
passwordText:setBackground(THEME.BACKGROUNDS.PASSWORD_BUTTON)
local passwordRect = gui.widget.Rectangle(PASSWORD_X + 21, PASSWORD_Y, 6, 1, THEME.BACKGROUNDS.PASSWORD_BUTTON)
passwordRect.val = passwordField
passwordRect:setCallback(function(widget, ...) if (not outgoingAuth) then stargate.sendMessage("password", widget.val:getValue()) end end)
mainScreen:addChild(passwordRect)
mainScreen:addChild(passwordText)
--Gate list----------------------------
for i, gate in ipairs(gates) do
    if (i > 19) then break end --can only show 19 gates
    addGateToList(gate)
end
nameInput = gui.widget.Input(2, 23, 40, 1, THEME.FOREGROUNDS.NAME_FIELD, "New gate name")
mainScreen:addChild(nameInput)
--Gate img---------------------------------------------------------------------
vortexLayer = gui.widget.Image(GATE_IMG_X + 1, GATE_IMG_Y + 3, VORTEX)
mainScreen:addChild(vortexLayer)
if (not (stargate.stargateState() == "Connected")) then vortexLayer:setVisible(false) end
irisLayer = gui.widget.Image(GATE_IMG_X + 1, GATE_IMG_Y + 3, IRIS_STATE[1])
if (stargate.irisState() == "Offline") then irisLayer:setVisible(false) end
mainScreen:addChild(irisLayer)
gateLayer = gui.widget.Image(GATE_IMG_X, GATE_IMG_Y, GATE_STATE[0])
mainScreen:addChild(gateLayer)

--CONFIG SCREEN================================================================
--Whitelist
buttonWhitelist = gui.widget.Text(2, 2, 18, 1, THEME.FOREGROUNDS.CONFIG_TOGGLE.ON, "Whitelist")
buttonWhitelist:setCallback(function(widget, ...)
    config.useWhitelist = not config.useWhitelist
    if (config.useWhitelist) then
        widget:setBackground(THEME.BACKGROUNDS.CONFIG_TOGGLE.ON)
    else
        widget:setBackground(THEME.BACKGROUNDS.CONFIG_TOGGLE.OFF)
    end
    buttonBlacklist:enable(not config.useWhitelist)
end)
if (config.useWhitelist) then
    buttonWhitelist:setBackground(THEME.BACKGROUNDS.CONFIG_TOGGLE.ON)
else
    buttonWhitelist:setBackground(THEME.BACKGROUNDS.CONFIG_TOGGLE.OFF)
end
buttonWhitelist:enable(not config.useBlacklist)
configScreen:addChild(buttonWhitelist)
--Blacklist
buttonBlacklist = gui.widget.Text(2, 4, 18, 1, THEME.FOREGROUNDS.CONFIG_TOGGLE.ON, "Blacklist")
buttonBlacklist:setCallback(function(widget, ...)
    config.useBlacklist = not config.useBlacklist
    if (config.useBlacklist) then
        widget:setBackground(THEME.BACKGROUNDS.CONFIG_TOGGLE.ON)
    else
        widget:setBackground(THEME.BACKGROUNDS.CONFIG_TOGGLE.OFF)
    end
    buttonWhitelist:enable(not config.useBlacklist)
end)
if (config.useBlacklist) then
    buttonBlacklist:setBackground(THEME.BACKGROUNDS.CONFIG_TOGGLE.ON)
else
    buttonBlacklist:setBackground(THEME.BACKGROUNDS.CONFIG_TOGGLE.OFF)
end
buttonBlacklist:enable(not config.useWhitelist)
configScreen:addChild(buttonBlacklist)
--blacklist drop
local buttonDropBlacklistConnexion = gui.widget.Text(2, 6, 18, 1, THEME.FOREGROUNDS.CONFIG_TOGGLE.ON, "Drop if blacklist")
buttonDropBlacklistConnexion:setCallback(function(widget, ...)
    config.dropBlacklistedConnexions = not config.dropBlacklistedConnexions
    if (config.dropBlacklistedConnexions) then
        widget:setBackground(THEME.BACKGROUNDS.CONFIG_TOGGLE.ON)
    else
        widget:setBackground(THEME.BACKGROUNDS.CONFIG_TOGGLE.OFF)
    end
end)
if (config.dropBlacklistedConnexions) then
    buttonDropBlacklistConnexion:setBackground(THEME.BACKGROUNDS.CONFIG_TOGGLE.ON)
else
    buttonDropBlacklistConnexion:setBackground(THEME.BACKGROUNDS.CONFIG_TOGGLE.OFF)
end
configScreen:addChild(buttonDropBlacklistConnexion)
--autoLearn
local buttonLearnNewGates = gui.widget.Text(2, 8, 18, 1, THEME.FOREGROUNDS.CONFIG_TOGGLE.ON, "Learn new gates")
buttonLearnNewGates:setCallback(function(widget, ...)
    config.saveNewGate = not config.saveNewGate
    if (config.saveNewGate) then
        widget:setBackground(THEME.BACKGROUNDS.CONFIG_TOGGLE.ON)
    else
        widget:setBackground(THEME.BACKGROUNDS.CONFIG_TOGGLE.OFF)
    end
end)
if (config.saveNewGate) then
    buttonLearnNewGates:setBackground(THEME.BACKGROUNDS.CONFIG_TOGGLE.ON)
else
    buttonLearnNewGates:setBackground(THEME.BACKGROUNDS.CONFIG_TOGGLE.OFF)
end
configScreen:addChild(buttonLearnNewGates)
--savePassword
local buttonSavePassword = gui.widget.Text(2, 10, 18, 1, THEME.FOREGROUNDS.CONFIG_TOGGLE.ON, "Save password")
buttonSavePassword:setCallback(function(widget, ...)
    config.savePassword = not config.savePassword
    if (config.savePassword) then
        widget:setBackground(THEME.BACKGROUNDS.CONFIG_TOGGLE.ON)
    else
        widget:setBackground(THEME.BACKGROUNDS.CONFIG_TOGGLE.OFF)
    end
end)
if (config.savePassword) then
    buttonSavePassword:setBackground(THEME.BACKGROUNDS.CONFIG_TOGGLE.ON)
else
    buttonSavePassword:setBackground(THEME.BACKGROUNDS.CONFIG_TOGGLE.OFF)
end
configScreen:addChild(buttonSavePassword)
--password
local passwordLabel = gui.widget.Text(2, 12, 15, 1, THEME.FOREGROUNDS.C_TEXT, "Iris password :")
passwordLabel:setBackground(THEME.BACKGROUNDS.C_TEXT)
configScreen:addChild(passwordLabel)
local passwordConfigField = gui.widget.Input(passwordLabel:getX() + passwordLabel:getWidth() + 1, passwordLabel:getY(), 20, 1, THEME.FOREGROUNDS.C_PASSWORD_FILED, config.password, "*")
configScreen:addChild(passwordConfigField)
--save
local buttonSave = gui.widget.Text(1, 25, 12, 1, THEME.FOREGROUNDS.C_SAVE_BUTTON, "Save")
buttonSave:setBackground(THEME.BACKGROUNDS.C_SAVE_BUTTON)
buttonSave:setCallback(function(...)
    config.password = passwordConfigField:getValue()
    --wait a little so no event get processed in the main screen
    event.timer(0.1, function(...) mainScreen:enable(true) end)
    mainScreen:setVisible(true)
    configScreen:setVisible(false)
    configScreen:enable(false)
    saveConfig()
end)
configScreen:addChild(buttonSave)
--cancel
local buttonCancel = gui.widget.Text(14, 25, 12, 1, THEME.FOREGROUNDS.C_CANCEL_BUTTON, "Cancel")
buttonCancel:setBackground(THEME.BACKGROUNDS.C_CANCEL_BUTTON)
buttonCancel:setCallback(function(...)
    --wait a little so no event get processed in the main screen
    event.timer(0.1, function(...) mainScreen:enable(true) end)
    mainScreen:setVisible(true)
    configScreen:setVisible(false)
    configScreen:enable(false)
end)
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
