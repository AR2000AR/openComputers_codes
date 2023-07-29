local gpu = require("component").gpu
local Widget = require("yawl.widget.Widget")

---@class SliderBar:Widget
---@overload fun(parent:Frame,x:number,y:number,width:number,height:number,min:number|nil,max:number|nil,backgroundColor:number|nil,foregroundColor:number|nil):SliderBar
local SliderBar = require("libClass2")(Widget)

---@param parent Frame
---@param x number
---@param y number
---@param width number
---@param height number
---@param min? number
---@param max? number
---@param backgroundColor? number
---@param foregroundColor? number
---@return SliderBar
function SliderBar:new(parent, x, y, width, height, min, max, backgroundColor, foregroundColor)
    checkArg(1, parent, 'table')
    checkArg(2, x, 'number')
    checkArg(3, y, 'number')
    checkArg(4, width, 'number')
    checkArg(5, height, 'number')
    checkArg(4, min, 'number', 'nil')
    checkArg(5, max, 'number', 'nil')
    checkArg(6, backgroundColor, 'number', 'nil')
    checkArg(6, foregroundColor, 'number', 'nil')
    local o = self.parent(parent, x, y)
    setmetatable(o, {__index = self})
    o._size = {width = 1, height = 1}
    ---@cast o SliderBar
    o:size(width, height)
    o:range(min, max)
    if min and max then
        o:value(min)
    end
    o:backgroundColor(backgroundColor)
    o:foregroundColor(foregroundColor)
    return o
end

---@param value? number
---@return number
function SliderBar:value(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self._value
    if (value ~= nil) then self._value = math.max(math.min(self:max(), value), self:min()) end
    return oldValue
end

---@param value? number
---@return number
function SliderBar:min(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self._min
    if (value ~= nil) then self._min = value end
    return oldValue
end

---@param value? number
---@return number
function SliderBar:max(value) --need to make sure it is higher than the minimum
    checkArg(1, value, 'number', 'nil')
    local oldValue = self._max
    if (value ~= nil) then self._max = value end
    return oldValue
end

---@param min? number
---@param max? number
---@return number,number
function SliderBar:range(min, max)
    checkArg(1, min, 'number', 'nil')
    checkArg(1, max, 'number', 'nil')
    return self:min(min), self:max(max)
end

---Increment or decrement the value
---@param value? number
---@return number
function SliderBar:adjust(value)
    checkArg(1, value, 'number')
    return self:value(self:value() + value)
end

function SliderBar:draw()
    if (not self:visible()) then return end
    local x, y, width, height = self:absX(), self:absY(), self:width(), self:height()
    local value = self:value()
    local oldBG, oldFG = gpu.getBackground(), gpu.getForeground()
    local newBG, newFG = self:backgroundColor(), self:foregroundColor()
    if newBG then
        gpu.setBackground(newBG)
    end
    gpu.fill(x, y, width, height, " ") --overwrite the background
    if newFG then gpu.setForeground(newFG) end
    gpu.fill(x, y + math.ceil(height / 2) - 1, width, 1, "━")
    --gpu.setBackground(self._slider.backgroundColor) --maybe
    --TODO : slider width
    if value then
        local percent = math.floor(((width - 1) * (value / (self:max() - self:min()))))
        if newFG then gpu.setBackground(newFG) end
        gpu.fill(x + percent, y, 1, height, " ") --might make funny tall slider
    end
    gpu.setBackground(oldBG)
    gpu.setForeground(oldFG)
end

return SliderBar
