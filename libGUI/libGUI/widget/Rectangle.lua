local gpu = require("component").gpu

local Rectangle = require("libClass").newClass("Rectangle",require("libGUI/widget/Widget"))
Rectangle.private.width = 1
Rectangle.private.height = 1
Rectangle.private.color = 0
Rectangle.setWidth = function(self,width) self.private.width = width or self:getWidth() end
Rectangle.setHeight = function(self,height) self.private.height = height or self:getHeight() end
Rectangle.setSize = function(self,width,height) self:setWidth(width) self:setHeight(height) end
Rectangle.setColor = function(self,color) self.private.color =  color or self:getColor() end
Rectangle.getWidth = function(self) return self.private.width end
Rectangle.getHeight = function(self) return self.private.height end
Rectangle.getSize = function(self) return self:getWidth(), self:getHeight() end
Rectangle.getColor = function(self) return self.private.color end
Rectangle.constructor = function(self,x,y,width,height,color) self:setWidth(width) self:setHeight(height) self:setColor(color) end
Rectangle.draw = function(self)
  local bk = gpu.setBackground(self:getColor())
  gpu.fill(self:getX(),self:getY(),self:getWidth(),self:getHeight()," ")
  gpu.setBackground(bk)
end

return Rectangle
