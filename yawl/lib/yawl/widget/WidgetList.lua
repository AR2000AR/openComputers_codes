local Frame = require("yawl.widget.Frame")

---@class WidgetList:Frame
---@operator call:WidgetList
---@overload fun():WidgetList
---@overload fun(parent:WidgetList):WidgetList
---@overload fun(parent:WidgetList,x:number,y:number):WidgetList
local WidgetList = require('libClass2')(Frame)

function WidgetList:draw()
    local y = 1
    for _, w in ipairs(self._childs) do
        w:position(1, y)
        y = y + w:height()
        if (y >= self:height()) then break end
    end
    self.parent.draw(self)
end

return WidgetList
