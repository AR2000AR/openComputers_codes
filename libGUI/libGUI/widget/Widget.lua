local function emptyCallback(self) end

Widget = require("libClass").newClass("Widget")
Widget.type = "Widget"
Widget.private = {x = 1, y = 1, callback = emptyCallback,visible = true,enabled = true}
Widget.setVisible= function(self,visible) self.private.visible = visible end
Widget.isVisible = function(self) return self.private.visible end
Widget.enable = function(self,enable) self.private.enabled = enable end
Widget.isEnabled = function(self) return self.private.enabled end
Widget.setPos = function(self,x,y) self:setX(x) self:setY(y) end
Widget.setX = function(self,x) self.private.x = x or self:getX() end
Widget.setY = function(self,y) self.private.y = y or self:getY() end
Widget.setCallback = function(self,callback) self.private.callback = callback or emptyCallback end
Widget.getX = function(self) return self.private.x end
Widget.getY = function(self) return self.private.y end
Widget.getPos = function(self) return self:getX(), self:getY() end
Widget.getId = function(self) return self.private.id end
Widget.trigger = function(self,...) --call the callback function
  if(self:isEnabled()) then self.private.callback(self,...) end
end
Widget.collide = function(self,x,y)
  return (x == self:getX() and y == self:getY())
end
Widget.constructor = function(self,x,y) self:setPos(x,y) self.private.id = require("uuid").next() end

return Widget
