local gpu = require("component").gpu
local Widget = require("yawl.widget.Widget")

---@class Rectangle:Widget
---@field private _size Size
---@operator call:Rectangle
---@overload fun(parent:Frame,x:number,y:number,width:number,height:number,backgroundColor:number)
local Rectangle = require("libClass2")(Widget)

---Create a new rectangle
---@param parent Frame
---@param x number
---@param y number
---@param width number
---@param height number
---@param backgroundColor number
---@return Rectangle
function Rectangle:new(parent, x, y, width, height, backgroundColor)
    checkArg(1, parent, 'table')
    checkArg(2, x, 'number')
    checkArg(3, y, 'number')
    checkArg(4, width, 'number')
    checkArg(5, height, 'number')
    checkArg(6, backgroundColor, 'number')
    local o = self.parent(parent, x, y)
    setmetatable(o, {__index = self})
    o._size = {width = 1, height = 1}
    ---@cast o Rectangle
    o:size(width, height)
    o:backgroundColor(backgroundColor or 0)
    return o
end

---Set the backgroundColor. Return the old backgroundColor or the current one if none is provided
---@param backgroundColor? number
---@return number
function Rectangle:backgroundColor(backgroundColor)
    checkArg(1, backgroundColor, 'number', 'nil')
    local oldValue = self._backgroundColor
    if (backgroundColor) then self._backgroundColor = backgroundColor end
    return oldValue
end

---Draw the Rectangle on screen
function Rectangle:draw()
    if (not self:visible()) then return end
    local bk = gpu.setBackground(self:backgroundColor())
    gpu.fill(self:absX(), self:absY(), self:width(), self:height(), " ")
    gpu.setBackground(bk)
end

return Rectangle
