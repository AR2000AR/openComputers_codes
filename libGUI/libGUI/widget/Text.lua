local text = require("text")
local gpu = require("component").gpu

local function wrap(inStr,maxWidth)
  -- create a table of string. Each string have a max set length
  local tbl = {}
  for str in text.wrappedLines(inStr,maxWidth+2,maxWidth+2) do
    table.insert(tbl,str)
  end
  return tbl
end

local Text = require("libClass").newClass("Text",require("libGUI/widget/Rectangle"))
Text.private.txt = ""
Text.private.minWidth = 0
Text.private.minHeight = 0
Text.private.maxWidth = math.huge
Text.private.maxHeight = math.huge
Text.private.width = 0
Text.private.height = 0
Text.private.color = {background = -1, foreground = -1 }

function Text.getMinWidth(self)
  return self.private.minWidth
end
function Text.getMinHeight(self)
  return self.private.minHeight
end
function Text.getMinSize(self)
  return self:getMinWidth(), self:getMinHeight()
end
function Text.getMaxWidth(self)
  return self.private.maxWidth
end
function Text.getMaxHeight(self)
  return self.private.maxHeight
end
function Text.getMaxSize(self)
  return self:getMaxWidth(), self:getMaxHeight()
end
function Text.getWidth(self)
  local tmp = #self:getText() --set the width to the text length
  if(self.private.width == 0) then --if no width is set adapt the widget size
    local strLen = 0
    for _,str in ipairs(wrap(self:getText(),self.private.maxWidth)) do
      strLen = math.max(strLen,#text.trim(str))
    end
    tmp = math.max(self:getMinWidth(),strLen)
    tmp = math.min(tmp,self:getMaxWidth())
  else --use the user defined width
    tmp = self.private.width
  end
  return tmp
end
function Text.getHeight(self)
  if(self.private.height ~= 0) then
    return self.private.height
  end
  local tmp = #wrap(self:getText(),self:getWidth())  --get the number of lines to display
  tmp = math.min(tmp,self:getMaxHeight()) --get the min between the max height and the number of lines
  tmp = math.max(tmp,self:getMinHeight()) --get the max between the previous result and the minimun height
  return tmp
end
function Text.getSize(self)
  return self:getWidth(), self:getHeight()
end

function Text.setMinWidth(self,int)
  self.private.minWidth = int or 0
end
function Text.setMinHeight(self,int)
  self.private.minHeight = int or 0
end
function Text.setMinSize(self,width,height)
  self:setMinWidth(width)
  self:setMinHeight(height)
end
function Text.setMaxWidth(self,int)
  self.private.maxWidth = int or math.math.huge
end
function Text.setMaxHeight(self,int)
  self.private.maxHeight = int or math.huge
end
function Text.setMaxSize(self,width,height)
  self:setMaxWidth(width)
  self:setMaxHeight(height)
end
function Text.setWidth(self,int)
  self.private.Width = int or 0
end
function Text.setHeight(self,int)
  self.private.Width = int or 0
end
function Text.setSize(self,width,height)
  self:setWidth(width)
  self:setHeight(height)
end

function Text.getText(self)
  return self.private.text
end
function Text.setText(self,text)
  self.private.text = text
end

function Text.getForeground(self)
  return self.private.color.foreground
end
function Text.getBackground(self)
  return self.private.color.background
end
function Text.setForeground(self,color)
  self.private.color.foreground = color or -1
end
function Text.setBackground(self,color)
  self.private.color.background = color or -1
end
function Text.setColor(self,color)
  self:setForeground(color)
end

function Text.draw(self)
  local x,y = self:getPos()
  local bk = gpu.getBackground()
  local fg = gpu.getForeground()
  if(self:getBackground() ~= -1) then bk = self:getBackground() end
  if(self:getForeground() ~= -1) then fg = self:getForeground() end
  bk = gpu.setBackground(bk)
  fg = gpu.setForeground(fg)

  gpu.fill(self:getX(),self:getY(),self:getWidth(),self:getHeight()," ")
  for _,str in ipairs(wrap(self:getText(),self:getWidth())) do
    gpu.set(x,y,text.trim(str))
    y = y + 1
  end

  gpu.setBackground(bk)
  gpu.setForeground(fg)
end

function Text.constructor(self,x,y,text,width,height)
  self:setSize(width,height)
  self:setText(text)
end

return Text
