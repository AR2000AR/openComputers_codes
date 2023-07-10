local class = require("libClass2")
local Frame = require("yawl.widget.Frame")

---@class LinkedWidget:Frame
---@field parent Frame
---@operator call:LinkedWidget
---@overload fun(parent:Frame,x:number,y:number)
local LinkedWidget = class(Frame)

---Comment
---@return LinkedWidget
---@param parent Frame
---@param x number
---@param y number
function LinkedWidget:new(parent, x, y)
    checkArg(1, parent, "table")
    local o = self.parent(parent, x, y)
    setmetatable(o, {__index = self})
    ---@cast o LinkedWidget
    return o
end

---@return Widget
function LinkedWidget:master()
    return self._childs[1]
end

---@param value? number
---@return number
function LinkedWidget:width(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self:master():width(value)
    if (value ~= nil) then
        for _, w in pairs(self._childs) do
            w:width(self:master():width())
        end
    end
    return oldValue
end

---@param value? number
---@return number
function LinkedWidget:height(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self:master():height(value)
    if (value ~= nil) then
        for _, w in pairs(self._childs) do
            w:height(self:master():height())
        end
    end
    return oldValue
end

function LinkedWidget:draw()
    if (not self:visible()) then return end
    for _, w in pairs(self._childs) do
        w:size(self:master():size())
        w:position(1, 1)
    end
    self.parent.draw(self)
end

return LinkedWidget
