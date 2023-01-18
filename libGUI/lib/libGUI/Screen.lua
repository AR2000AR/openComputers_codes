local libClass = require("libClass")
local Widget = require("libGUI/widget/Widget")
local Rectangle = require("libGUI/widget/Rectangle")
local gpu = require("component").gpu
local os = require "os"

local Screen = libClass.newClass("Screen")
Screen.childs = {}
Screen.addChild = function(self, child)
  if     (not child.class) then
    error("arg #2 is not a class", 2)
  elseif (not libClass.instanceOf(child, Widget) and not libClass.instanceOf(child, Screen)) then
    error("arg #2 is not a Widget", 2)
  else
    table.insert(self.childs, child)
  end
end
Screen.trigger = function(self, ...)
  if (self:isEnabled()) then self.private.clickHandler(self, ...) end
end
Screen.private = {visible = true, enabled = true}
Screen.private.clickHandler = function(self, eventName, uuid, x, y, button, playerName)
  if (eventName == "touch") then --filter only "touch" events
    for _, widget in ipairs(self.childs) do
      if (libClass.instanceOf(widget, Widget)) then
        if (widget:collide(x, y)) then --test colision
          widget:trigger(eventName, uuid, x, y, button, playerName)
        end
      else --widget is a Screen
        widget:trigger(eventName, uuid, x, y, button, playerName)
      end
    end
  end
end
Screen.setVisible = function(self, visible) self.private.visible = visible end
Screen.isVisible = function(self) return self.private.visible end
Screen.enable = function(self, enable) self.private.enabled = enable end
Screen.isEnabled = function(self) return self.private.enabled end
Screen.draw = function(self, useBuffer)
  local drawBuffer = nil
  if (useBuffer == nil) then useBuffer = true end
  if (useBuffer) then
    drawBuffer = gpu.allocateBuffer()
    gpu.setActiveBuffer(drawBuffer)
  end
  for _, widget in ipairs(self.childs) do
    if (widget:isVisible()) then widget:draw(false) end --draw(false) so other screens don't create new buffers
  end
  if (useBuffer) then
    gpu.bitblt(0)
    gpu.setActiveBuffer(0)
    gpu.freeBuffer(drawBuffer)
  end
end

return Screen
