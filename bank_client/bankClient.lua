local gui = require("libGUI")
local event = require("event")
local bank_api = require("bank_api")
local libCB = require("libCB")
local os = require("os")
local gpu = require("component").gpu
local proxy = require("component").proxy

local MODE_CLOSING = -1
local MODE_IDLE = 0
local MODE_VIEW_ACCOUNT = 1
local MODE_CREATE_ACCOUNT = 2
local MODE_REQUEST_CB = 3
local B_NAME_VIEW_ACCOUNT = "bva"
local B_NAME_CREATE_ACCOUNT = "ca"
local B_NAME_POPUP_CLOSE = "pc"
local B_NAME_C = "c"
local mode = MODE_IDLE

local touchListenerId = nil
local driveListenerId = nil
local intListenerId = nil

local resX,resY = nil,nil

local screen = gui.Screen()
local backgroundScreen = gui.Screen()
local mainInterfaceScreen = gui.Screen()
local newAccountScreen = gui.Screen()
local viewAccountScreen = gui.Screen()
local diskWaitPopup = gui.Screen()
local keypad = nil
local statusBar = nil
local acUUIDText = nil
local soldeText = nil
local pinText = nil

local function closeClient(...)
  event.cancel(touchListenerId)
  event.cancel(driveListenerId)
  event.cancel(intListenerId)
  gpu.setResolution(resX,resY)
  mode = MODE_CLOSING
end

local function creerCompte(drive)
  statusBar:setText("demmande du compte")
  screen:draw()
  local status,acUUID = bank_api.createAccount() --TODO add secret
  statusBar:setText("creation de compte : "..status)
  screen:draw()
  if(status == 0) then
    local status,pin,rawCBdata = bank_api.requestNewCBdata(acUUID,drive.address) --TODO add secret
    libCB.writeCB(rawCBdata,drive)
    diskWaitPopup:setVisible(false)
    diskWaitPopup:enable(false)
    acUUIDText:setText("uuid : "..acUUID)
    pinText:setText("pin : "..pin)
    newAccountScreen:setVisible(true)
    screen:draw()
  end
end

local function voirCompte(cbData)
  statusBar:setText("demmande des info")
  screen:draw()
  local status,solde = bank_api.getCredit(cbData)
  statusBar:setText("demmande des info : "..status)
  screen:draw()
  if(status == 0) then
    acUUIDText:setText("uuid : "..cbData.uuid)
    soldeText:setText("Solde : "..solde)
    viewAccountScreen:setVisible(true)
    screen:draw()
  end
end

local function buttonEventHandler(buttonName)
  --statusBar:setText("event")
  if(buttonName == B_NAME_POPUP_CLOSE) then
    diskWaitPopup:setVisible(false)
    diskWaitPopup:enable(false)
    statusBar:setText("cancel")
    screen:draw()
    mode = MODE_IDLE
  end
  if(mode == MODE_IDLE) then
    if(buttonName == B_NAME_VIEW_ACCOUNT) then
      mode = MODE_VIEW_ACCOUNT
      statusBar:setText("entering view account mode")
      diskWaitPopup:setVisible(true)
      diskWaitPopup:enable(true)
      screen:draw()
    elseif(buttonName == B_NAME_CREATE_ACCOUNT) then
      mode = MODE_CREATE_ACCOUNT
      statusBar:setText("mode création de compte")
      diskWaitPopup:setVisible(true)
      diskWaitPopup:enable(true)
      screen:draw()
    end
  else
    if(buttonName == B_NAME_C) then
      newAccountScreen:setVisible(false)
      viewAccountScreen:setVisible(false)
      statusBar:setText("idle")
      screen:draw()
      mode = MODE_IDLE
    end
  end
end

local function diskEventHandler(eventName,componentAdd,componentName)
  if(componentName ~= "drive") then return end --on ne traite que les composent de type drive
  local drive = proxy(componentAdd)
  if(mode == MODE_VIEW_ACCOUNT) then
    diskWaitPopup:setVisible(false)
    diskWaitPopup:enable(false)
    keypad:clearInput()
    keypad:enable(true)
    keypad:setVisible(true)
    keypad:setValidateCallback(function(kp)
      if(#kp:getInput() == 4) then
        local cbData=libCB.getCB(drive,kp:getInput())
        kp:clearInput()
        if(cbDate ~= false) then
          kp:enable(false)
          kp:setVisible(false)
          screen:draw()
          voirCompte(cbData)
        end
      end
    end)
    screen:draw()
  elseif(mode == MODE_CREATE_ACCOUNT) then
      diskWaitPopup:setVisible(false)
      diskWaitPopup:enable(false)
      screen:draw()
      creerCompte(drive)
  end
end

local function init()

  resX,resY = gpu.getResolution()
  gpu.setResolution(80,25)

  local background = gui.widget.Rectangle(1,1,80,25,0xd2d2d2)
  backgroundScreen:addChild(background)

  statusBar = gui.widget.Text(1,25,80,1,0xffffff,"idle")
  statusBar:setBackground(0x000000)
  mainInterfaceScreen:addChild(statusBar)

  local bagImg = gui.widget.Image(28,4,"/var/bank/img/moneybag20x17.pam")
  local arcImg = gui.widget.Image(21,2,"/var/bank/img/goldArc.pam")
  backgroundScreen:addChild(bagImg)
  backgroundScreen:addChild(arcImg)

  local buttonCreateAccountShape0 = gui.widget.Rectangle(3,3,17,3,0x878787)
  local buttonCreateAccountShape1 = gui.widget.Rectangle(3,4,17,1,0xd2d2d2)
  local buttonCreateAccountLabel  = gui.widget.Text(4,4,15,1,0x000000,"creer un compte")
  buttonCreateAccountLabel:setBackground(0xd2d2d2)
  buttonCreateAccountShape0:setCallback(function() buttonEventHandler(B_NAME_CREATE_ACCOUNT) end)
  mainInterfaceScreen:addChild(buttonCreateAccountShape0)
  mainInterfaceScreen:addChild(buttonCreateAccountShape1)
  mainInterfaceScreen:addChild(buttonCreateAccountLabel)

  -- local buttonCreateCBShape0 = gui.widget.Rectangle(3,11,17,3,0x878787)
  -- local buttonCreateCBShape1 = gui.widget.Rectangle(3,12,17,1,0xd2d2d2)
  -- local buttonCreateCBLabel = gui.widget.Text(5,12,13,1,0x000000,"creer une CB")
  -- buttonCreateCBLabel:setBackground(0xd2d2d2)
  -- buttonCreateCBShape0:setCallback(function() buttonEventHandler("nil") end)
  -- mainInterfaceScreen:addChild(buttonCreateCBShape0)
  -- mainInterfaceScreen:addChild(buttonCreateCBShape1)
  -- mainInterfaceScreen:addChild(buttonCreateCBLabel)

  local buttonViewAccountShape0 = gui.widget.Rectangle(3,19,17,3,0x878787)
  local buttonViewAccountShape1 = gui.widget.Rectangle(3,20,17,1,0xd2d2d2)
  local buttonViewAccountLabel = gui.widget.Text(5,20,15,1,0x000000,"voir un compte")
  buttonViewAccountLabel:setBackground(0xd2d2d2)
  buttonViewAccountShape0:setCallback(function() buttonEventHandler(B_NAME_VIEW_ACCOUNT) end)
  mainInterfaceScreen:addChild(buttonViewAccountShape0)
  mainInterfaceScreen:addChild(buttonViewAccountShape1)
  mainInterfaceScreen:addChild(buttonViewAccountLabel)

  local boardShape1 = gui.widget.Rectangle(50,1,29,24,0x660000)
  local boardShape2 = gui.widget.Rectangle(51,2,27,17,0x0092ff)
  local boardShape3 = gui.widget.Rectangle(51,20,27,4,0xd2d2d2)
  local boardShape4 = gui.widget.Rectangle(51,20,8,2,0x660000)
  local bottomLine  = gui.widget.Rectangle(1,24,80,1,0x660000)
  backgroundScreen:addChild(boardShape1)
  backgroundScreen:addChild(boardShape2)
  backgroundScreen:addChild(boardShape3)
  backgroundScreen:addChild(boardShape4)
  backgroundScreen:addChild(bottomLine)

  acUUIDText = gui.widget.Text(52,3,0,0,0xffffff,"uuid : ")
  pinText    = gui.widget.Text(52,8,0,0,0xffffff,"pin : ")
  acUUIDText:setBackground(0)
  pinText:setBackground(0)
  acUUIDText:setMaxWidth(25)
  newAccountScreen:addChild(acUUIDText)
  newAccountScreen:addChild(pinText)

  soldeText = gui.widget.Text(52,5,0,0,0xffffff,"pin : ")
  soldeText:setBackground(0)
  viewAccountScreen:addChild(acUUIDText)
  viewAccountScreen:addChild(soldeText)

  local b1 = gui.widget.Text(51,20,1,1,0x000000," ")
  local b2 = gui.widget.Text(53,20,1,1,0x000000," ")
  local b3 = gui.widget.Text(55,20,1,1,0x000000," ")
  local b4 = gui.widget.Text(57,20,1,1,0x000000,"C")
  b4:setCallback(function() buttonEventHandler(B_NAME_C) end)
  b1:setBackground(0xd2d2d2)
  b2:setBackground(0xd2d2d2)
  b3:setBackground(0xd2d2d2)
  b4:setBackground(0xd2d2d2)
  mainInterfaceScreen:addChild(b1)
  mainInterfaceScreen:addChild(b2)
  mainInterfaceScreen:addChild(b3)
  mainInterfaceScreen:addChild(b4)

  diskWaitPopup:addChild(gui.widget.Rectangle(20,5,40,12,0x878787))
  diskWaitPopup:addChild(gui.widget.Image(22,7,"/var/bank/img/floppy8x8.pam"))
  local txt = gui.widget.Text(32,9,0,0,0,"Inserer une CB")
  txt:setBackground(0x878787)
  diskWaitPopup:addChild(txt)
  local closeBtn = gui.widget.Text(59,5,0,0,0,"X")
  closeBtn:setBackground(0xff0000)
  closeBtn:setCallback(function() buttonEventHandler(B_NAME_POPUP_CLOSE) end)
  diskWaitPopup:addChild(closeBtn)

  keypad = gui.widget.Keypad(35,10,0xc3c3c3,true,4)

  viewAccountScreen:setVisible(false)
  newAccountScreen:setVisible(false)
  diskWaitPopup:setVisible(false)
  keypad:setVisible(false)
  viewAccountScreen:enable(false)
  newAccountScreen:enable(false)
  diskWaitPopup:enable(false)
  keypad:enable(false)

  screen:addChild(backgroundScreen)
  screen:addChild(mainInterfaceScreen)
  screen:addChild(newAccountScreen)
  screen:addChild(viewAccountScreen)
  screen:addChild(diskWaitPopup)
  screen:addChild(keypad)

  intListenerId = event.listen("interrupted",closeClient)
  touchListenerId = event.listen("touch",function(...) screen:trigger(...) end)
  driveListenerId = event.listen("component_added",diskEventHandler)

  screen:draw()
end

init()
while(mode ~= MODE_CLOSING) do
  os.sleep()
  --screen:draw()
end
closeClient()
require("term").clear()
