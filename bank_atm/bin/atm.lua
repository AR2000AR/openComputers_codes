---@diagnostic disable: cast-local-type
local libCB      = require("libCB")
local bank       = require("bank_api")
local shell      = require("shell")
local sides      = require("sides")
local coin       = require("libCoin")
local gui        = require("libGUI")
local event      = require("event")
local os         = require("os")
local gpu        = require("component").gpu
local transposer = require("component").transposer
local disk_drive = require("component").disk_drive
local proxy      = require("component").proxy
local beep       = require("component").computer.beep

local STORAGE  = 0
local EXTERIOR = 0

local MODE_IDLE     = 0
local MODE_PIN      = 1
local MODE_MENU     = 2
local MODE_WITHDRAW = 3
local MODE_DEPOSIT  = 4
local MODE_STATS    = 5
local MODE_CLOSING  = -1
local mode          = MODE_IDLE

local BUTTON_NAME_WITHDRAW = "bw"
local BUTTON_NAME_DEPOSIT  = "bd"
local BUTTON_NAME_EJECT    = "be"

local main_screen   = nil
local card_wait     = nil
local keypad        = nil
local error_popup   = nil
local success_popup = nil
local main_menu     = nil
local sold_text     = nil
local bin_text      = nil

local event_touch, event_drive, event_eject, event_magData = nil, nil, nil, nil

local old_res_x, old_res_y = nil, nil

local drive         = nil
local cbData        = false
local encryptedData = nil
local solde         = 0
-- =============================================================================
local eject         = disk_drive.eject

local function endSession()
  mode = MODE_IDLE
  card_wait:setVisible(true)
  error_popup:setVisible(false)
  success_popup:setVisible(false)
  main_menu:enable(false)
  keypad:enable(false)
  keypad:setVisible(false)
  cbData = nil
  encryptedData = nil
  solde = 0
  sold_text:setText("Solde : 0")
  eject()
end

local function showMenu()
  mode = MODE_MENU
  card_wait:setVisible(false)
  error_popup:hide()
  success_popup:hide()
  main_menu:enable(true)
  keypad:enable(false)
  keypad:setVisible(false)
  success_popup:hide()
  error_popup:hide()
  local binVal = coin.getValue(coin.getCoin(EXTERIOR))
  bin_text:setText("Bin   : " .. binVal)
  local status
  status, solde = bank.getCredit(cbData)
  if (status == 0) then
    sold_text:setText("Solde : " .. solde)
  else
    endSession()
  end
end

local function closeClient(...)
  if (event_touch) then event.cancel(event_touch) end
  if (event_eject) then event.cancel(event_eject) end
  if (event_drive) then event.cancel(event_drive) end
  if (event_magData) then event.cancel(event_magData) end
  gpu.setResolution(old_res_x, old_res_y)
  main_screen:setVisible(false)
  main_screen:enable(false)
  mode = MODE_CLOSING
  require("component").gpu.setActiveBuffer(0)
  return false
end

-- =============================================================================
local function makeTransaction(amount)
  local status = nil
  status, solde = bank.getCredit(cbData)
  if (status ~= 0) then
    error_popup:show("Serveur non disponible", true)
    endSession()
  else
    local coinGiven, b, s, g, p = 0, 0, 0, 0, 0
    if     (mode == MODE_WITHDRAW) then
      if (solde < amount) then
        error_popup:show("Solde insufisant", true)
        amount = 0
      else
        amount = amount * -1
      end
      b, s, g, p = coin.moveCoin(math.abs(amount), STORAGE, EXTERIOR)
    elseif (mode == MODE_DEPOSIT) then
      b, s, g, p = coin.moveCoin(amount, EXTERIOR, STORAGE)
    end
    if (b ~= false) then
      coinGiven = coin.getValue(b, s, g, p)
      if (mode == MODE_WITHDRAW) then coinGiven = coinGiven * -1 end
      bank.editAccount(cbData, coinGiven)
      if (amount ~= coinGiven) then
        error_popup:show("Coffre de sortie plein\nPrévenez un admin", true)
      end
      showMenu()
    else
      error_popup:show("Imposible de distibuer les pièces", true)
      showMenu()
    end
  end
end

-- =============================================================================
local function keypadPinCallback(kp)
  if (#kp:getInput() == 4) then
    cbData = libCB.getCB(encryptedData, kp:getInput())
    kp:clearInput()
    if (cbData ~= false) then
      kp:enable(false)
      kp:setVisible(false)
      local status, credit = bank.getCredit(cbData)
      if (status == 0) then
        showMenu()
        status = bank.editAccount(cbData, 0) --check that the atm can do it's job
        if (status ~= 0) then
          endSession()
          closeClient()
        end
      end
    end
  end
end

local function keypadNumericalCallback(kp)
  if (#kp:getInput() ~= 0) then
    local amount = tonumber(kp:getInput())
    kp:clearInput()
    kp:enable(false)
    kp:setVisible(false)
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
end

local function showNumericalKeypad()
  keypad:clearInput()
  keypad:setMaxInputLen(-1)
  keypad:setVisible(true)
  keypad:enable(true)
  keypad:hideInput(false)
  keypad:setValidateCallback(keypadNumericalCallback)
end

-- =============================================================================
local function buttonEventHandler(buttonName)
  if (mode == MODE_MENU) then
    if     (buttonName == BUTTON_NAME_EJECT) then
      endSession()
    elseif (buttonName == BUTTON_NAME_DEPOSIT) then
      mode = MODE_DEPOSIT
      showNumericalKeypad()
    elseif (buttonName == BUTTON_NAME_WITHDRAW) then
      mode = MODE_WITHDRAW
      showNumericalKeypad()
    end
  end
end

local function componentAddedHandler(eventName, address, component_type)
  if (component_type == "drive") then
    drive = proxy(address)
    encryptedData = libCB.loadCB(drive)
    showPinKeypad()
  end
end

local function magDataHandler(eventName, address, ...)
  encryptedData = libCB.loadCB(proxy(address))
  showPinKeypad()
end

local function driveEjectedHandler(eventName, component_type)
  if (component_type == "drive") then
    endSession()
  end
end

-- =============================================================================
local function init()
  --look for the input chest
  while (transposer.getInventoryName(STORAGE) == nil) do
    STORAGE = STORAGE + 1
    if (STORAGE == 6) then
      print("Need 2 chest")
      os.exit()
    end
  end
  --look for the output chest
  if (STORAGE == EXTERIOR) then EXTERIOR = EXTERIOR + 1 end
  while (transposer.getInventoryName(EXTERIOR) == nil) do
    EXTERIOR = EXTERIOR + 1
    if (EXTERIOR == STORAGE) then EXTERIOR = EXTERIOR + 1 end
    if (EXTERIOR == 6) then
      print("Need 2 chest")
      os.exit()
    end
  end

  old_res_x, old_res_y = gpu.getResolution()
  gpu.setResolution(26, 13)

  main_screen = gui.Screen()
  main_screen:addChild(gui.widget.Rectangle(1, 1, 26, 13, 0))
  event_touch = event.listen("touch", function(...) main_screen:trigger(...) end)

  main_menu = gui.Screen()

  sold_text = gui.widget.Text(1, 2, 26, 1, 0xffffff, "Solde : 0")
  sold_text:setBackground(0)
  main_menu:addChild(sold_text)

  bin_text = gui.widget.Text(1, 3, 26, 1, 0xffffff, "Bin   : 0")
  bin_text:setBackground(0)
  main_menu:addChild(bin_text)

  local button_withdraw = gui.widget.Rectangle(1, 5, 3, 2, 0xffffff)
  button_withdraw:setCallback(function(...) buttonEventHandler(BUTTON_NAME_WITHDRAW) end)
  main_menu:addChild(button_withdraw)
  local label_withdraw = gui.widget.Text(4, 6, 8, 1, 0xffffff, "WITHDRAW")
  label_withdraw:setBackground(0)
  main_menu:addChild(label_withdraw)

  local button_deposit = gui.widget.Rectangle(1, 8, 3, 2, 0xffffff)
  button_deposit:setCallback(function(...) buttonEventHandler(BUTTON_NAME_DEPOSIT) end)
  main_menu:addChild(button_deposit)
  local label_deposit = gui.widget.Text(4, 9, 7, 1, 0xffffff, "DEPOSIT")
  label_deposit:setBackground(0)
  main_menu:addChild(label_deposit)

  local button_eject = gui.widget.Rectangle(1, 11, 3, 2, 0xffffff)
  button_eject:setCallback(function(...) buttonEventHandler(BUTTON_NAME_EJECT) end)
  main_menu:addChild(button_eject)
  local label_eject = gui.widget.Text(4, 12, 8, 1, 0xffffff, "EXIT")
  label_eject:setBackground(0)
  main_menu:addChild(label_eject)

  main_menu:enable(false)
  main_screen:addChild(main_menu)

  card_wait = gui.Screen()
  card_wait:addChild(gui.widget.Rectangle(1, 1, 26, 13, 0xffffff))
  card_wait:addChild(gui.widget.Image(9, 4, "/usr/share/bank_atm/floppy8x8.pam"))
  main_screen:addChild(card_wait)

  keypad = gui.widget.Keypad(10, 2, 0xc3c3c3, true, 4)
  keypad:enable(false)
  keypad:setVisible(false)
  main_screen:addChild(keypad)

  local function show(self, text, blocking)
    self.text:setText(text)
    self:setVisible(true)
    self:enable(true)
    if (blocking) then
      while (self:isVisible()) do
        main_screen:draw()
        ---@diagnostic disable-next-line: undefined-field
        os.sleep()
      end
    end
  end

  local function hide(self, ...)
    success_popup:setVisible(false)
    success_popup:enable(false)
    error_popup:setVisible(false)
    error_popup:enable(false)
  end

  error_popup = gui.Screen()
  success_popup = gui.Screen()
  error_popup.show = show
  success_popup.show = show
  error_popup.hide = hide
  success_popup.hide = hide
  local popup_bg = gui.widget.Rectangle(2, 5, 24, 5, 0xc3c3c3)
  popup_bg:setCallback(hide)
  error_popup:addChild(popup_bg)
  success_popup:addChild(popup_bg)
  error_popup.text = gui.widget.Text(3, 6, 22, 2, 0, "???")
  error_popup.text:setBackground(popup_bg:getColor())
  error_popup:addChild(error_popup.text)
  success_popup.text = error_popup.text
  success_popup:addChild(success_popup.text)
  success_popup:addChild(gui.widget.Rectangle(2, 5, 24, 1, 0x00ff00))
  error_popup:addChild(gui.widget.Rectangle(2, 5, 24, 1, 0xff0000))
  main_screen:addChild(success_popup)
  main_screen:addChild(error_popup)
  success_popup:hide()
  error_popup:hide()

  event_drive = event.listen("component_added", componentAddedHandler)
  event_eject = event.listen("component_unavailable", driveEjectedHandler)
  event_magData = event.listen("magData", magDataHandler)
  event.listen("interrupted", closeClient)
end

-- =============================================================================
init()
while (mode ~= MODE_CLOSING) do
  main_screen:draw()
  ---@diagnostic disable-next-line: undefined-field
  os.sleep()
end
closeClient()
