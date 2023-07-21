local Frame = require("yawl.widget.Frame")

---@class WidgetList:Frame
---@operator call:WidgetList
---@overload fun():WidgetList
---@overload fun(parent:WidgetList):WidgetList
---@overload fun(parent:WidgetList,x:number,y:number):WidgetList
local WidgetList = require('libClass2')(Frame)

function WidgetList:draw()
    if (self:visible() == false) then return end
    local y = 1
    for _, w in ipairs(self._childs) do
        if (y > self:height()) then
            w:visible(false)
            w:enabled(false)
        else
            w:visible(true)
            w:enabled(true)
            w:position(1, y)
            y = y + w:height()
        end
    end
    self.parent.draw(self)
end

return WidgetList
