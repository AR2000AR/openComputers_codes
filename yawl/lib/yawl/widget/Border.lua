local class = require("libClass2")
local Frame = require("yawl.widget.Frame")

---@class Border:Frame
---@field parent Frame
---@operator call:Border
---@overload fun(parent:Frame,x:number,y:number)
local Border = class(Frame)

---Comment
---@return Border
---@param parent Frame
---@param x number
---@param y number
function Border:new(parent, x, y)
    checkArg(1, parent, "table")
    local o = self.parent(parent, x, y)
    setmetatable(o, {__index = self})
    ---@cast o Border
    return o
end

---@return Widget
function Border:master()
    return self._childs[1]
end

---@param value? number
---@return number
function Border:width(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self:master():width(value) + 2
    if (value ~= nil) then
        for _, w in pairs(self._childs) do
            w:width(math.min(1, self:master():width() - 2))
        end
    end
    return oldValue
end

---@param value? number
---@return number
function Border:height(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self:master():height(value) + 2
    if (value ~= nil) then
        for _, w in pairs(self._childs) do
            w:height(math.min(1, self:master():height() - 2))
        end
    end
    return oldValue
end

function Border:draw()
    if (not self:visible()) then return end
    for _, w in pairs(self._childs) do
        if (w ~= self:master()) then
            w:size(self:master():size())
        end
        w:position(2, 2)
    end
    self.parent.draw(self)
end

return Border
