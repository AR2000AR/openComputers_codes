local gui       = require("libGUI")
local event     = require("event")
local bank_api  = require("bank_api")
local libCB     = require("libCB")
local os        = require("os")
local component = require("component")
local gpu       = require("component").gpu

local MODE_CLOSING          = -1
local MODE_IDLE             = 0
local MODE_VIEW_ACCOUNT     = 1
local MODE_CREATE_ACCOUNT_1 = 2
local MODE_CREATE_ACCOUNT_2 = 3
local B_NAME_VIEW_ACCOUNT   = "bva"
local B_NAME_CREATE_ACCOUNT = "ca"
local B_NAME_POPUP_CLOSE    = "pc"
local B_NAME_C              = "c"
local B_NAME_FLOPPY         = "fp"
local B_NAME_MAGCARD        = "mg"
local IMG_PATH              = "/usr/data/bank_client/"
local mode                  = MODE_IDLE

local touchListenerId   = nil
local driveListenerId   = nil
local intListenerId     = nil
local magDataListenerId = nil

local resX, resY = nil, nil

local screen              = gui.Screen()
local backgroundScreen    = gui.Screen()
local mainInterfaceScreen = gui.Screen()
local newAccountScreen    = gui.Screen()
local viewAccountScreen   = gui.Screen()
local diskWaitPopup       = gui.Screen()
local cardSupportPopup    = gui.Screen()
local keypad              = nil
local statusBar           = nil
local acUUIDText          = nil
local soldeText           = nil
local pinText             = nil

local function closeClient(...)
  event.cancel(touchListenerId)
  event.cancel(driveListenerId)
  event.cancel(intListenerId)
  event.cancel(magDataListenerId)
  gpu.setResolution(resX, resY)
  mode = MODE_CLOSING
end

local function printStatus(msg)
  statusBar:setText(msg)
  screen:draw()
end

local function openPopup(popup)
  popup:setVisible(true)
  popup:enable(true)
  screen:draw()
end

local function closePopup(popup)
  popup:setVisible(false)
  popup:enable(false)
  screen:draw()
end

local function creerCompte(drive)
  printStatus("demmande du compte")
  local status, acUUID = bank_api.createAccount()
  printStatus("creation de compte : " .. status)
  if (status == 0) then
    local pin, rawCBdata
    if (drive.type == "drive") then
      status, pin, rawCBdata = bank_api.requestNewCBdata(acUUID, drive.address)
    else
      status, pin, rawCBdata = bank_api.requestNewCBdata(acUUID)
    end
    if (drive.type == "os_cardwriter") then
      printStatus("Insert magnetic card in the writer...")
    end
    ---@diagnostic disable-next-line: undefined-field
    while (not libCB.writeCB(rawCBdata, drive)) do os.sleep(0.1) end
    closePopup(diskWaitPopup)
    acUUIDText:setText("uuid : " .. acUUID)
    pinText:setText("pin : " .. pin)
    newAccountScreen:setVisible(true)
    printStatus("Card created.")
  end
end

local function voirCompte(pin, rawData)
  closePopup(diskWaitPopup)
  if (not pin) then
    printStatus("Asking for pin")
    keypad:clearInput()
    keypad:enable(true)
    keypad:setVisible(true)
    keypad:setValidateCallback(function(kp)
      if (#keypad:getInput() == 4) then
        voirCompte(keypad:getInput(), rawData)
        keypad:clearInput()
      end
    end)
  else
    printStatus("Reading card")
    local cbData = libCB.getCB(rawData, pin)
    if (cbData) then
      keypad:clearInput()
      keypad:enable(false)
      keypad:setVisible(false)
      printStatus("demmande des info")
      local status, solde = bank_api.getCredit(cbData)
      printStatus("demmande des info : " .. status)
      if (status == 0) then
        acUUIDText:setText("uuid : " .. cbData.uuid)
        soldeText:setText("Solde : " .. solde)
        viewAccountScreen:setVisible(true)
      end
    else voirCompte(nil, rawData) end
  end
end

local function buttonEventHandler(buttonName)
  if (buttonName == B_NAME_POPUP_CLOSE) then
    closePopup(diskWaitPopup)
    closePopup(cardSupportPopup)
    printStatus("cancel")
    mode = MODE_IDLE
  end
  if  (mode == MODE_IDLE) then
    if     (buttonName == B_NAME_VIEW_ACCOUNT) then
      mode = MODE_VIEW_ACCOUNT
      printStatus("entering view account mode")
      openPopup(diskWaitPopup)
      if (component.isAvailable("drive")) then voirCompte(nil, libCB.loadCB(component.drive)) end
    elseif (buttonName == B_NAME_CREATE_ACCOUNT) then
      mode = MODE_CREATE_ACCOUNT_1
      printStatus("mode création de compte")
      openPopup(cardSupportPopup)
    end
  elseif (mode == MODE_CREATE_ACCOUNT_1) then
    if  (buttonName == B_NAME_FLOPPY) then
      mode = MODE_CREATE_ACCOUNT_2
      closePopup(cardSupportPopup)
      screen:draw()
    elseif (buttonName == B_NAME_MAGCARD) then
      closePopup(cardSupportPopup)
      screen:draw()
      creerCompte(component.os_cardwriter)
    end
  else
    if (buttonName == B_NAME_C) then
      newAccountScreen:setVisible(false)
      viewAccountScreen:setVisible(false)
      printStatus("idle")
      keypad:clearInput()
      keypad:enable(false)
      keypad:setVisible(false)
      mode = MODE_IDLE
    end
  end
end

local function diskEventHandler(eName, eAddr, ...)
  if     (mode == MODE_VIEW_ACCOUNT) then
    printStatus("Card inserted")
    voirCompte(nil, component.proxy(eAddr))
  elseif (mode == MODE_CREATE_ACCOUNT_2) then
    closePopup(diskWaitPopup)
    creerCompte(component.drive)
  end
end

local function magDataEventHandler(eName, eAddr)
  if (mode == MODE_VIEW_ACCOUNT) then
    printStatus("Card read")
    voirCompte(nil, libCB.loadCB(component.proxy(eAddr)))
  end
end

local function init()

  resX, resY = gpu.getResolution()
  gpu.setResolution(80, 25)

  local background = gui.widget.Rectangle(1, 1, 80, 25, 0xd2d2d2)
  backgroundScreen:addChild(background)

  statusBar = gui.widget.Text(1, 25, 80, 1, 0xffffff, "idle")
  statusBar:setBackground(0x000000)
  mainInterfaceScreen:addChild(statusBar)

  local bagImg = gui.widget.Image(28, 4, IMG_PATH .. "moneybag20x17.pam")
  local arcImg = gui.widget.Image(21, 2, IMG_PATH .. "goldArc.pam")
  backgroundScreen:addChild(bagImg)
  backgroundScreen:addChild(arcImg)

  local buttonCreateAccountShape0 = gui.widget.Rectangle(3, 3, 17, 3, 0x878787)
  local buttonCreateAccountShape1 = gui.widget.Rectangle(3, 4, 17, 1, 0xd2d2d2)
  local buttonCreateAccountLabel  = gui.widget.Text(6, 4, 11, 1, 0x000000, "New account")
  buttonCreateAccountLabel:setBackground(0xd2d2d2)
  buttonCreateAccountShape0:setCallback(function() buttonEventHandler(B_NAME_CREATE_ACCOUNT) end)
  mainInterfaceScreen:addChild(buttonCreateAccountShape0)
  mainInterfaceScreen:addChild(buttonCreateAccountShape1)
  mainInterfaceScreen:addChild(buttonCreateAccountLabel)

  local buttonViewAccountShape0 = gui.widget.Rectangle(3, 19, 17, 3, 0x878787)
  local buttonViewAccountShape1 = gui.widget.Rectangle(3, 20, 17, 1, 0xd2d2d2)
  local buttonViewAccountLabel = gui.widget.Text(6, 20, 12, 1, 0x000000, "View account")
  buttonViewAccountLabel:setBackground(0xd2d2d2)
  buttonViewAccountShape0:setCallback(function() buttonEventHandler(B_NAME_VIEW_ACCOUNT) end)
  mainInterfaceScreen:addChild(buttonViewAccountShape0)
  mainInterfaceScreen:addChild(buttonViewAccountShape1)
  mainInterfaceScreen:addChild(buttonViewAccountLabel)

  local boardShape1 = gui.widget.Rectangle(50, 1, 29, 24, 0x660000)
  local boardShape2 = gui.widget.Rectangle(51, 2, 27, 17, 0x0092ff)
  local boardShape3 = gui.widget.Rectangle(51, 20, 27, 4, 0xd2d2d2)
  local boardShape4 = gui.widget.Rectangle(51, 20, 8, 2, 0x660000)
  local bottomLine  = gui.widget.Rectangle(1, 24, 80, 1, 0x660000)
  backgroundScreen:addChild(boardShape1)
  backgroundScreen:addChild(boardShape2)
  backgroundScreen:addChild(boardShape3)
  backgroundScreen:addChild(boardShape4)
  backgroundScreen:addChild(bottomLine)

  acUUIDText = gui.widget.Text(52, 3, 25, 2, 0xffffff, "uuid : ")
  pinText    = gui.widget.Text(52, 6, 6, 1, 0xffffff, "pin : ")
  acUUIDText:setBackground(0)
  pinText:setBackground(0)
  newAccountScreen:addChild(acUUIDText)
  newAccountScreen:addChild(pinText)

  soldeText = gui.widget.Text(52, 6, 25, 1, 0xffffff, "pin : ")
  soldeText:setBackground(0)
  viewAccountScreen:addChild(acUUIDText)
  viewAccountScreen:addChild(soldeText)

  local b1 = gui.widget.Text(51, 20, 1, 1, 0x000000, " ")
  local b2 = gui.widget.Text(53, 20, 1, 1, 0x000000, " ")
  local b3 = gui.widget.Text(55, 20, 1, 1, 0x000000, " ")
  local b4 = gui.widget.Text(57, 20, 1, 1, 0x000000, "C")
  b4:setCallback(function() buttonEventHandler(B_NAME_C) end)
  b1:setBackground(0xd2d2d2)
  b2:setBackground(0xd2d2d2)
  b3:setBackground(0xd2d2d2)
  b4:setBackground(0xd2d2d2)
  mainInterfaceScreen:addChild(b1)
  mainInterfaceScreen:addChild(b2)
  mainInterfaceScreen:addChild(b3)
  mainInterfaceScreen:addChild(b4)

  diskWaitPopup:addChild(gui.widget.Rectangle(20, 5, 40, 12, 0x878787))
  diskWaitPopup:addChild(gui.widget.Image(22, 7, IMG_PATH .. "floppy8x8.pam"))
  local txt = gui.widget.Text(32, 9, 16, 1, 0, "Insert a debit card")
  txt:setBackground(0x878787)
  diskWaitPopup:addChild(txt)
  local closeBtn = gui.widget.Text(59, 5, 1, 1, 0, "X")
  closeBtn:setBackground(0xff0000)
  closeBtn:setCallback(function() buttonEventHandler(B_NAME_POPUP_CLOSE) end)
  diskWaitPopup:addChild(closeBtn)

  cardSupportPopup:addChild(gui.widget.Rectangle(20, 5, 40, 12, 0x878787))
  local bFloppy = gui.widget.Text(25, 9, 9, 1, 0x000000, "Floppy")
  bFloppy:setBackground(0x878787)
  local bMagCard = gui.widget.Text(35, 9, 9, 1, 0x000000, "magCard")
  bMagCard:setBackground(0x878787)
  bFloppy:setCallback(function() buttonEventHandler(B_NAME_FLOPPY) end)
  bMagCard:setCallback(function() buttonEventHandler(B_NAME_MAGCARD) end)
  cardSupportPopup:addChild(bFloppy)
  cardSupportPopup:addChild(bMagCard)
  cardSupportPopup:addChild(closeBtn)

  keypad = gui.widget.Keypad(35, 10, 0xc3c3c3, true, 4)

  viewAccountScreen:setVisible(false)
  newAccountScreen:setVisible(false)
  diskWaitPopup:setVisible(false)
  cardSupportPopup:setVisible(false)
  keypad:setVisible(false)
  viewAccountScreen:enable(false)
  newAccountScreen:enable(false)
  diskWaitPopup:enable(false)
  cardSupportPopup:enable(false)
  keypad:enable(false)

  screen:addChild(backgroundScreen)
  screen:addChild(mainInterfaceScreen)
  screen:addChild(newAccountScreen)
  screen:addChild(viewAccountScreen)
  screen:addChild(diskWaitPopup)
  screen:addChild(cardSupportPopup)
  screen:addChild(keypad)

  intListenerId = event.listen("interrupted", closeClient)
  touchListenerId = event.listen("touch", function(...) screen:trigger(...) end)
  driveListenerId = event.listen("component_added", diskEventHandler, nil, "drive")
  magDataListenerId = event.listen("magData", magDataEventHandler)
end

init()
while (mode ~= MODE_CLOSING) do
  ---@diagnostic disable-next-line: undefined-field
  os.sleep()
  screen:draw()
end
closeClient()
require("term").clear()
