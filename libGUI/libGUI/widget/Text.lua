local text = require("text")
local gpu = require("component").gpu

local function wrap(inStr,maxWidth)
  -- create a table of string. Each string have a max set length
  local tbl = {}
  for str in text.wrappedLines(inStr,maxWidth,maxWidth) do
    table.insert(tbl,str)
  end
  return tbl
end

local Text = require("libClass").newClass("Text",require("libGUI/widget/Rectangle"))
Text.private.text = ""
Text.private.color = {background = -1, foreground = -1 }

function Text.getText(self) return self.private.text end
function Text.setText(self,text) self.private.text = text end

function Text.getForeground(self) return self.private.color.foreground end
function Text.getBackground(self) return self.private.color.background end
function Text.setForeground(self,color) self.private.color.foreground = color or -1 end
function Text.setBackground(self,color) self.private.color.background = color or -1 end
function Text.setColor(self,color) self:setForeground(color) end
function Text.getColor(self) return self:getForeground() end

function Text.draw(self)
  local x,y = self:getPos()
  local bk = gpu.getBackground() --break if nil
  local fg = gpu.getForeground() --break if nil
  if(self:getBackground() ~= -1) then bk = self:getBackground() end
  if(self:getForeground() ~= -1) then fg = self:getForeground() end
  bk = gpu.setBackground(bk)
  fg = gpu.setForeground(fg)

  gpu.fill(self:getX(),self:getY(),self:getWidth(),self:getHeight()," ")

  local displayText = wrap(self:getText(),self:getWidth())
  for i=math.max(1,#displayText-(self:getHeight()-1)), #displayText do
    gpu.set(x,y,text.trim(displayText[i]))
    y=y+1
  end

  gpu.setBackground(bk)
  gpu.setForeground(fg)
end

function Text.constructor(self,x,y,width,height,color,text)
  self:setText(text)
end

return Text
