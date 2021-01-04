local libCB = require("libCB")
local bank = require("bank_api")
local shell = require("shell")
local sides = require("sides")
local coin = require("libCoin")
local gui = require("libGUI")
local event = require("event")
local os = require("os")
local gpu = require("component").gpu
local transposer = require("component").transposer
local disk_drive = require("component").disk_drive
local proxy = require("component").proxy
local beep = require("component").computer.beep

local STORAGE = 1
local EXTERIOR = -1

local MODE_IDLE = 0
local MODE_PIN = 1
local MODE_MENU = 2
local MODE_WITHDRAW = 3
local MODE_DEPOSIT = 4
local MODE_STATS = 5
local MODE_CLOSING = -1
local mode = MODE_IDLE

local BUTTON_NAME_WITHDRAW = "bw"
local BUTTON_NAME_DEPOSIT = "bd"

local main_screen = nil
local card_wait = nil
local keypad = nil
local error_popup = nil
local success_popup = nil
local main_menu = nil
local sold_text = nil
local bin_text = nil

local event_touch,event_drive,event_eject = 0,0,0

local old_res_x,old_res_y = nil,nil

local drive = nil
local cbData = false
local solde = 0
-- =============================================================================
local function eject()
  disk_drive.eject()
end
local function draw()
  main_screen:draw()
end
local function showMenu()
  mode = MODE_MENU
  card_wait:setVisible(false)
  error_popup:setVisible(false)
  success_popup:setVisible(false)
  main_menu:enable(true)
  keypad:enable(false)
  keypad:setVisible(false)
  local binVal = coin.getValue(coin.getCoin(EXTERIOR))
  bin_text:setText("Bin   : "..binVal)
  local status
  status,solde = bank.getCredit(cbData)
  if(status == 0) then
    sold_text:setText("Solde : "..solde)
  else
    eject()
  end
  draw()
end
local function closeClient(...)
  event.cancel(event_touch)
  event.cancel(event_eject)
  event.cancel(event_drive)
  gpu.setResolution(old_res_x,old_res_y)
  keypad:enable(false)
  keypad:setVisible(false)
  mode = MODE_CLOSING
  return false
end
-- =============================================================================
local function makeTransaction(amount)
  local coinGiven,b,s,g,p = 0,0,0,0,0
  if(mode == MODE_WITHDRAW) then
    if(solde < amount) then
      --TODO : erreur
      amount = 0
    else
      amount = amount * -1
    end
    b,s,g,p = coin.moveCoin(math.abs(amount),STORAGE,EXTERIOR)
  elseif(mode == MODE_DEPOSIT) then
    b,s,g,p = coin.moveCoin(amount,EXTERIOR,STORAGE)
  end
  if(b ~= false) then
    coinGiven = coin.getValue(b,s,g,p)
    if(mode == MODE_WITHDRAW) then coinGiven = coinGiven * -1 end
    bank.editAccount(cbData,coinGiven)
    showMenu()
  else
    --TODO : erreur
    beep()

  end
end
-- =============================================================================
local function keypadPinCallback(kp)
  if(#kp:getInput() == 4) then
    cbData=libCB.getCB(drive,kp:getInput())
    kp:clearInput()
    if(cbData ~= false) then
      kp:enable(false)
      kp:setVisible(false)
      draw()
      local status,credit = bank.getCredit(cbData)
      draw()
      if(status == 0) then
        showMenu()
        local status = bank.editAccount(cbData,0) --check that the atm can do it's job
        if(status ~= 0) then
          eject()
          closeClient()
        end
        draw()
      end
    end
  end
  draw()
end
local function keypadAmountCallback(kp)
  if(#kp:getInput() ~= 0) then
    local amount = tonumber(kp:getInput())
    kp:clearInput()
    kp:enable(false)
    kp:setVisible(false)
    draw()
    makeTransaction(amount)
  end
end
-- =============================================================================
local function showPinKeypad()
  keypad:clearInput()
  keypad:setMaxInputLen(4)
  keypad:setVisible(true)
  keypad:enable(true)
  keypad:hideInput(true)
  keypad:setValidateCallback(keypadPinCallback)
  draw()
end
local function showNumericalKeypad()
  keypad:clearInput()
  keypad:setMaxInputLen(-1)
  keypad:setVisible(true)
  keypad:enable(true)
  keypad:hideInput(false)
  keypad:setValidateCallback(keypadAmountCallback)
  draw()
end
-- =============================================================================
local function buttonEventHandler(buttonName)
  if(mode == MODE_MENU) then
    if(buttonName == BUTTON_NAME_EJECT) then
      eject()
    elseif(buttonName == BUTTON_NAME_DEPOSIT) then
      mode = MODE_DEPOSIT
      showNumericalKeypad()
    elseif(buttonName == BUTTON_NAME_WITHDRAW) then
      mode = MODE_WITHDRAW
      showNumericalKeypad()
    end
  end
  draw()
end
local function componentAddedHandler(eventName,address,component_type)
  if(component_type == "drive") then
    drive = proxy(address)
    showPinKeypad()
  end
end
local function driveEjectedHandler(eventName,component_type)
  if(component_type == "drive") then
    mode = MODE_IDLE
    card_wait:setVisible(true)
    error_popup:setVisible(false)
    success_popup:setVisible(false)
    main_menu:enable(false)
    keypad:enable(false)
    keypad:setVisible(false)
    cbData = nil
    solde = 0
    sold_text:setText("Solde : 0")
    draw()
  end
end
-- =============================================================================
local function init()
  --look for the input chest
  while(transposer.getInventoryName(STORAGE) == nil) do
    STORAGE = STORAGE + 1
    if(STORAGE == 1) then
      print("Need 2 chest")
      os.exit()
    end
    if(STORAGE == 6)then
      form = 0
    end
  end
  --look for the output chest
  repeat
    EXTERIOR = EXTERIOR + 1
    if(EXTERIOR==STORAGE)then EXTERIOR=EXTERIOR+1 end
    if(EXTERIOR > 5) then
      print("Need 2 chest")
      os.exit()
    end
  until transposer.getInventoryName(EXTERIOR) ~= nil

  old_res_x,old_res_y = gpu.getResolution()
  gpu.setResolution(26,13)

  main_screen = gui.Screen()
  main_screen:addChild(gui.widget.Rectangle(1,1,26,13,0))
  event_touch = event.listen("touch",function(...) main_screen:trigger(...) end)

  main_menu = gui.Screen()

  sold_text = gui.widget.Text(1,2,0,0,0xffffff,"Solde : 0")
  sold_text:setBackground(0)
  main_menu:addChild(sold_text)

  bin_text = gui.widget.Text(1,3,0,0,0xffffff,"Bin   : 0")
  bin_text:setBackground(0)
  main_menu:addChild(bin_text)

  local button_withdraw = gui.widget.Rectangle(1,5,3,2,0xffffff)
  button_withdraw:setCallback(function(...) buttonEventHandler(BUTTON_NAME_WITHDRAW) end)
  main_menu:addChild(button_withdraw)
  local label_withdraw = gui.widget.Text(4,6,0,0,0xffffff,"RETIRER")
  label_withdraw:setBackground(0)
  main_menu:addChild(label_withdraw)

  local button_deposit = gui.widget.Rectangle(1,8,3,2,0xffffff)
  button_deposit:setCallback(function(...) buttonEventHandler(BUTTON_NAME_DEPOSIT) end)
  main_menu:addChild(button_deposit)
  local label_deposit = gui.widget.Text(4,9,0,0,0xffffff,"DEPOSER")
  label_deposit:setBackground(0)
  main_menu:addChild(label_deposit)

  local button_eject = gui.widget.Rectangle(1,11,3,2,0xffffff)
  button_eject:setCallback(function(...) buttonEventHandler(BUTTON_NAME_EJECT) end)
  main_menu:addChild(button_eject)
  local label_eject = gui.widget.Text(4,12,0,0,0xffffff,"QUITER")
  label_eject:setBackground(0)
  main_menu:addChild(label_eject)

  main_menu:enable(false)
  main_screen:addChild(main_menu)

  card_wait = gui.Screen()
  card_wait:addChild(gui.widget.Rectangle(1,1,26,13,0xffffff))
  card_wait:addChild(gui.widget.Image(9,4,"/var/bank/img/floppy8x8.pam"))
  main_screen:addChild(card_wait)

  keypad = gui.widget.Keypad(10,2,0xc3c3c3,true,4)
  keypad:enable(false)
  keypad:setVisible(false)
  main_screen:addChild(keypad)

  error_popup = gui.Screen()
  success_popup = gui.Screen()

  event_drive = event.listen("component_added",componentAddedHandler)
  event_eject = event.listen("component_unavailable",driveEjectedHandler)
  event.listen("interrupted",closeClient)

  draw()
end
-- =============================================================================
init()
while(mode ~= MODE_CLOSING) do
  os.sleep()
end
closeClient()
