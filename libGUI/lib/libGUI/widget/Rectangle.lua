local gpu = require("component").gpu

local Rectangle = require("libClass").newClass("Rectangle", require("libGUI/widget/Widget"))
Rectangle.private.width = 1
Rectangle.private.height = 1
Rectangle.private.color = 0
Rectangle.setWidth = function(self, width) self.private.width = math.max(width or self:getWidth(), 1) end
Rectangle.setHeight = function(self, height) self.private.height = math.max(height or self:getHeight(), 1) end
Rectangle.setSize = function(self, width, height)
  self:setWidth(width)
  self:setHeight(height)
end
Rectangle.setColor = function(self, color) self.private.color = color or self:getColor() end
Rectangle.getWidth = function(self) return self.private.width end
Rectangle.getHeight = function(self) return self.private.height end
Rectangle.getSize = function(self) return self:getWidth(), self:getHeight() end
Rectangle.getColor = function(self) return self.private.color end
Rectangle.constructor = function(self, x, y, width, height, color)
  self:setSize(width, height)
  self:setColor(color)
end
Rectangle.collide = function(self, x, y)
  local wx1, wy1 = self:getPos()
  local wx2 = self:getX() + self:getWidth() - 1
  local wy2 = self:getY() + self:getHeight() - 1
  return ((x - wx1) * (wx2 - x) >= 0 and (y - wy1) * (wy2 - y) >= 0)
end
Rectangle.draw = function(self)
  local bk = gpu.setBackground(self:getColor())
  gpu.fill(self:getX(), self:getY(), self:getWidth(), self:getHeight(), " ")
  gpu.setBackground(bk)
end

return Rectangle
