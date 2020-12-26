local gpu = require("component").gpu
local string = require("string")
local event = require("event")

local Keypad = require("libClass").newClass("Keypad",require("libGUI/widget/Widget"))
Keypad.setWidth = function(self,width) return nil end
Keypad.setHeight = function(self,height) return nil end
Keypad.setSize = function(self,width,height) return nil end
Keypad.private.color = 0
Keypad.getColor = function(self) return self.private.color end
Keypad.setColor = function(self,color) self.private.color =  color or self:getColor() end
Keypad.getWidth = function(self) return 9 end
Keypad.getHeight = function(self) return 11 end
Keypad.getSize = function(self) return self:getWidth(), self:getHeight() end
Keypad.private.event = {screen = -1, keyboard = -1}
Keypad.private.text = ""
function Keypad.getText(self) return self.private.text end
function Keypad.clearText(self) self.private.text = "" end
Keypad.private.hide = false
function Keypad.isTextHidden(self) return self.private.hide end
function Keypad.hideText(self,hide) if(type(hide) == "boolean") then self.private.hide = hide end end
Keypad.private.maxTextLen = -1
function Keypad.getMaxTextLen(self) return self.private.maxTextLen end
function Keypad.setMaxTextLen(self,len) self.private.maxTextLen = len or self.private.maxTextLen end
function Keypad.enable(self,enable)
  self.private.enabled = enable
  if(self.private.event.keyboard ~= -1) then
    event.cancel(self.private.event.keyboard)
    self.private.event.keyboard = -1
  end
  if(enable) then
    self.private.event.keyboard = event.listen("key_down",function(...) self:onKeyboard(...) end)
  end
end
function Keypad.constructor(self,x,y,color,hide,maxTextLen)
  self:setColor(color)
  self:enable(true) --Keypad.enable register the keyboard event listener
  self:hideText(hide)
  self:setMaxTextLen(maxTextLen)
end

Keypad.collide = function(self,x,y)
  local wx1,wy1 = self:getPos()
  local wx2 = self:getX()+self:getWidth()-1
  local wy2 = self:getY()+self:getHeight()-1
  return ((x-wx1)*(wx2-x) >= 0 and (y-wy1)*(wy2-y) >= 0)
end

function Keypad.private.keyboardHandler(self,eventName,keyboardUUID,char,key,playerName)
  if(48<=char and char<=57)then
    self.private.text = self.private.text..string.char(char)
  end
  if(char==8)then
    self.private.text = self:getText():sub(1,#self:getText()-1)
  end
  self.private.text = self.private.text:sub(1,self:getMaxTextLen())
end

function Keypad.onKeyboard(self,...)
  --event.listen("key_up",function(...) keypad:onKeyboard(...) end)
  self.private.keyboardHandler(self,...)
  self:draw()
end

function Keypad.private.screenHandler(self,eventName,ScreenUUID,x,y,button,playerName)
  local keys = {
    {'7','8','9'},
    {'4','5','6'},
    {'1','2','3'},
    {'X','0','V'}
  }
  x = (x - self:getX())/2
  y = (y - self:getY()-1)/2

  if(keys[y][x] == 'X') then
    self.private.text = self:getText():sub(1,#self:getText()-1)
  elseif(keys[y][x] == 'V') then
    --TODO : validate event
  else
    self.private.text = self.private.text..keys[y][x]
  end
  self.private.text = self.private.text:sub(1,self:getMaxTextLen())
end

function Keypad.private.callback(self,...)
  self.private.screenHandler(self,...)
  self:draw()
end

function Keypad.draw(self)
  if(not self:isVisible()) then return nil end
  local oldBgColor = gpu.setBackground(self:getColor()) --change the background color and save the old one to restore it later
  gpu.fill(self:getX(),self:getY(),self:getWidth(),self:getHeight()," ")
  gpu.setBackground(0)
  gpu.fill(self:getX()+1,self:getY()+1,self:getWidth()-2,1," ")

  local displayText = self:getText():sub(-1*(self:getWidth()-2))
  if(self:isTextHidden()) then
    displayText = displayText:gsub('.','*')
  end
  if(#self:getText() > self:getWidth()-2) then
    displayText = "<"..displayText:sub(-1*(self:getWidth()-3))
  end

  gpu.set(self:getX()+1,self:getY()+1,displayText)

  gpu.set(self:getX()+2,self:getY()+3,self:isEnabled() and "7" or " ")
  gpu.set(self:getX()+4,self:getY()+3,self:isEnabled() and "8" or " ")
  gpu.set(self:getX()+6,self:getY()+3,self:isEnabled() and "9" or " ")

  gpu.set(self:getX()+2,self:getY()+5,self:isEnabled() and "4" or " ")
  gpu.set(self:getX()+4,self:getY()+5,self:isEnabled() and "5" or " ")
  gpu.set(self:getX()+6,self:getY()+5,self:isEnabled() and "6" or " ")

  gpu.set(self:getX()+2,self:getY()+7,self:isEnabled() and "1" or " ")
  gpu.set(self:getX()+4,self:getY()+7,self:isEnabled() and "2" or " ")
  gpu.set(self:getX()+6,self:getY()+7,self:isEnabled() and "3" or " ")

  gpu.set(self:getX()+2,self:getY()+9,self:isEnabled() and "X" or " ")
  gpu.set(self:getX()+4,self:getY()+9,self:isEnabled() and "0" or " ")
  gpu.set(self:getX()+6,self:getY()+9,self:isEnabled() and "V" or " ")


  gpu.setBackground(oldBgColor) --restore the background color to the old one
end

return Keypad
