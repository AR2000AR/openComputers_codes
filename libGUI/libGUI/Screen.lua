local libClass = require("libClass")
local Widget = require("libGUI/widget/Widget")
local Rectangle = require("libGUI/widget/Rectangle")

local Screen = libClass.newClass("Screen")
Screen.childs = {}
Screen.addChild = function(self,child)
  if(not child.class) then
    error("arg #2 is not a class",2)
  elseif(not libClass.instanceOf(child,Widget)) then
    error("arg #2 is not a Widget",2)
  else
    table.insert(self.childs,child)
  end
end
Screen.trigger = function(self,...) self.private.clickHandler(self,...) end
Screen.private = {}
Screen.private.clickHandler = function(self,eventName,uuid,x,y)
  print(eventName,x,y)
  if(eventName == "touch") then --filter only "touch" events
    print("ok touch")
    for _,widget in ipairs(self.childs) do
      print("collide ",widget:collide(x,y))
      if(widget:collide(x,y)) then --test colision
        widget:trigger(eventName,uuid,x,y)
      end
    end
  end
end
Screen.draw = function(self)
  for _,widget in ipairs(self.childs) do
    widget:draw()
  end
end

return Screen
