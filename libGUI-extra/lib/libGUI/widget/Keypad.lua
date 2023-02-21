local gpu = require("component").gpu
local string = require("string")
local event = require("event")

local Keypad = require("libClass").newClass("Keypad", require("libGUI/widget/Widget"))
--Rectangle is not used because of it's constructor. Keypad have fixed height and width

function Keypad.setWidth(self, width) return nil end

function Keypad.setHeight(self, height) return nil end

function Keypad.setSize(self, width, height) return nil end

function Keypad.getWidth(self) return 9 end --fixed

function Keypad.getHeight(self) return 11 end --fixed

function Keypad.getSize(self) return self:getWidth(), self:getHeight() end

Keypad.private.color = 0 --background color
function Keypad.getColor(self) return self.private.color end

function Keypad.setColor(self, color) self.private.color = color or self:getColor() end

Keypad.private.event = -1 --event listener id

Keypad.private.input = ""
function Keypad.getInput(self) return self.private.input end

function Keypad.clearInput(self) self.private.input = "" end

Keypad.private.hide = false --should the input be replaced with '*'
function Keypad.isInputHidden(self) return self.private.hide end

function Keypad.hideInput(self, hide) if (type(hide) == "boolean") then self.private.hide = hide end end

Keypad.private.maxInputLen = -1 --maximum input length
function Keypad.getMaxInputLen(self) return self.private.maxInputLen end

function Keypad.setMaxInputLen(self, len) self.private.maxInputLen = len or self.private.maxInputLen end

function Keypad.private.validateCallback(self)
end

function Keypad.setValidateCallback(self, fct) if (type(fct) == "function") then self.private.validateCallback = fct end end

function Keypad.enable(self, enable)
  self.private.enabled = enable
  if (self.private.event ~= -1) then --if a event listener is present
    event.cancel(self.private.event) --cancel the event listener
    self.private.event = -1 --set event to -1 (no listener)
  end
  if (enable) then
    self.private.event = event.listen("key_down", function(...) self:onKeyboard(...) end) --register a new event listerner
  end
end

function Keypad.constructor(self, x, y, color, hide, maxInputLen)
  self:setColor(color) --background color
  self:enable(true) --Keypad.enable register the keyboard event listener
  self:hideInput(hide) --should the input be replaced with '*'
  self:setMaxInputLen(maxInputLen) --max input length
end

function Keypad.collide(self, x, y)
  local wx1, wy1 = self:getPos()
  local wx2 = self:getX() + self:getWidth() - 1
  local wy2 = self:getY() + self:getHeight() - 1
  return ((x - wx1) * (wx2 - x) >= 0 and (y - wy1) * (wy2 - y) >= 0)
end

function Keypad.private.keyboardHandler(self, eventName, keyboardUUID, char, key, playerName)
  if (48 <= char and char <= 57) then
    self.private.input = self.private.input .. string.char(char)
  elseif (char == 8) then
    self.private.input = self:getInput():sub(1, #self:getInput() - 1)
  elseif (char == 13) then --\n
    self.private.validateCallback(self)
  end
  self.private.input = self.private.input:sub(1, self:getMaxInputLen())
end

function Keypad.onKeyboard(self, ...)
  --event.listen("key_up",function(...) keypad:onKeyboard(...) end)
  self.private.keyboardHandler(self, ...)
  self.private.drawInput(self) --redraw the text field
end

function Keypad.private.screenHandler(self, eventName, ScreenUUID, x, y, button, playerName)
  local keys = {
    {'7', '8', '9'},
    {'4', '5', '6'},
    {'1', '2', '3'},
    {'X', '0', 'V'}
  } --keyboard layout
  --convert the screen coordinates to coord in the keys array
  x = (x - self:getX()) / 2
  y = (y - self:getY() - 1) / 2

  if (x >= 1 and x <= 3 and y >= 1 and y <= 4) then --keys[y][x] might be null if the event is not on  a key
    if (keys[y][x] == 'X') then --if X got pressed
      self.private.input = self:getInput():sub(1, #self:getInput() - 1) --remove the last char from the input
    elseif (keys[y][x] == 'V') then --if V got pressed
      self.private.validateCallback(self)
    else --a number got pressed
      self.private.input = self.private.input .. (keys[y][x])
    end
  end
  self.private.input = self.private.input:sub(1, self:getMaxInputLen()) --cut the string to the max input length
end

function Keypad.private.callback(self, ...) --could have been named onKeyboard
  self.private.screenHandler(self, ...)
  self.private.drawInput(self) --redraw the text field
end

function Keypad.private.drawInput(self)
  if (not self:isVisible()) then return nil end --do nothing if the widget is not visible
  local oldBgColor = gpu.setBackground(0) --change the background color and save the old one to restore it later
  local oldFgColor = gpu.setForeground(0xffffff) --change the foreground color and save the old one to restore it later

  --draw the text field
  gpu.setBackground(0)
  gpu.fill(self:getX() + 1, self:getY() + 1, self:getWidth() - 2, 1, " ")

  --fill the text field
  local displayText = self:getInput():sub( -1 * (self:getWidth() - 2))
  if (self:isInputHidden()) then
    displayText = displayText:gsub('.', '*') --replace each char with '*'
  end
  if (#self:getInput() > self:getWidth() - 2) then --if the input if longer than the text field
    displayText = "<" .. displayText:sub( -1 * (self:getWidth() - 3)) --replace the first character of the displayed text with "<" to indicate a trucated string
  end

  gpu.set(self:getX() + 1, self:getY() + 1, displayText)

  gpu.setBackground(oldBgColor) --restore the background color to the old one
  gpu.setForeground(oldFgColor) --restore the foreground color to the old one
end

function Keypad.draw(self)
  if (not self:isVisible()) then return nil end --do nothing if the widget is not visible

  local oldBgColor = gpu.setBackground(self:getColor()) --change the background color and save the old one to restore it later
  local oldFgColor = gpu.setForeground(0xffffff) --change the foreground color and save the old one to restore it later
  gpu.fill(self:getX(), self:getY(), self:getWidth(), self:getHeight(), " ") --draw background

  --draw the text field
  self.private.drawInput(self)

  --add the buttons
  gpu.setBackground(0)

  gpu.set(self:getX() + 2, self:getY() + 3, self:isEnabled() and "7" or " ")
  gpu.set(self:getX() + 4, self:getY() + 3, self:isEnabled() and "8" or " ")
  gpu.set(self:getX() + 6, self:getY() + 3, self:isEnabled() and "9" or " ")

  gpu.set(self:getX() + 2, self:getY() + 5, self:isEnabled() and "4" or " ")
  gpu.set(self:getX() + 4, self:getY() + 5, self:isEnabled() and "5" or " ")
  gpu.set(self:getX() + 6, self:getY() + 5, self:isEnabled() and "6" or " ")

  gpu.set(self:getX() + 2, self:getY() + 7, self:isEnabled() and "1" or " ")
  gpu.set(self:getX() + 4, self:getY() + 7, self:isEnabled() and "2" or " ")
  gpu.set(self:getX() + 6, self:getY() + 7, self:isEnabled() and "3" or " ")

  gpu.set(self:getX() + 2, self:getY() + 9, self:isEnabled() and "X" or " ")
  gpu.set(self:getX() + 4, self:getY() + 9, self:isEnabled() and "0" or " ")
  gpu.set(self:getX() + 6, self:getY() + 9, self:isEnabled() and "V" or " ")

  gpu.setBackground(oldBgColor) --restore the background color to the old one
  gpu.setForeground(oldFgColor) --restore the foreground color to the old one
end

return Keypad
