local Frame = require("yawl.widget.Frame")

---@class WidgetList:Frame
---@operator call:WidgetList
---@overload fun():WidgetList
---@overload fun(parent:WidgetList):WidgetList
---@overload fun(parent:WidgetList,x:number,y:number):WidgetList
local WidgetList = require('libClass2')(Frame)

function WidgetList:draw()
    for i, w in ipairs(self._childs) do
        w:position(1, i)
    end
    self.parent.draw(self)
end

return WidgetList
