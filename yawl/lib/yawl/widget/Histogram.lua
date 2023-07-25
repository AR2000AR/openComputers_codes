local class = require("libClass2")
local Frame = require("yawl.widget.Frame")
local gpu = require("component").gpu

--[[
    Ideally, Histogram will have horizontal scrolling. Though there is some contention about the direction.
]]
---@class Histogram:Frame
---@field parent Frame
---@operator call:Histogram
---@overload fun(parent:Frame,x:number,y:number):Histogram
---@overload fun(parent:Frame,x:number,y:number,maxColumns:number):Histogram
local Histogram = class(Frame)

---Comment
---@return Histogram
---@param parent Frame
---@param x number
---@param y number
---@param maxColumns? number
function Histogram:new(parent, x, y, maxColumns)
    checkArg(1, parent, "table")
    checkArg(1, maxColumns, "number", "nil")
    local o = self.parent(parent, x, y)
    setmetatable(o, {__index = self})
    ---@cast o Histogram
    o._maxColumns = maxColumns
    o._data = {}
    o:fillChar(" ")
    return o
end

--insert at the end
---@param value number
function Histogram:insert(value)
    checkArg(1, value, "number")
    table.insert(self._data, value)
end

--overwride the value
---@param index number
---@param value number
---@return number
function Histogram:set(index, value)
    checkArg(1, index, 'number')
    checkArg(1, value, 'number')
    local oldValue = self._data[index]
    if (value) then self._data[index] = value end
    return oldValue
end

--change existing value
---@param value number
---@param index number
---@return number
function Histogram:adjust(value, index)
    checkArg(1, index, 'number', 'nil')
    checkArg(1, value, 'number')
    index = index or #self._data --if no chosen index, change the last
    local oldValue = self._data[index]
    self._data[index] = oldValue + value
    return oldValue
end

--not the best name, basically used to control the vertical height
---@param value? number
---@return number
function Histogram:maxValue(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self._maxValue
    if (value) then self._maxValue = value end
    return oldValue
end

---Remove all the data
function Histogram:clear()
    self._data = {}
end

---The characted used inside the graph bars
---@param value? string
---@return string
function Histogram:fillChar(value)
    checkArg(1, value, 'string', 'nil')
    local oldValue = self._fill
    if (value) then self._fill = value end
    return oldValue
end

---@param value? any
---@return any
function Histogram:fillForegroundColor(value)
    checkArg(1, value, 'string', 'nil')
    local oldValue = self._fillForegroundColor
    if (value) then self._fillForegroundColor = value end
    return oldValue
end

---@param value? number
---@return number
function Histogram:fillBackgroundColor(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self._fillBackgroundColor
    if (value) then self._fillBackgroundColor = value end
    return oldValue
end

---@param value? number
---@return number
function Histogram:textForegroundColor(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self._textForegroundColor
    if (value) then self._textForegroundColor = value end
    return oldValue
end

---@param value? string
---@return string
function Histogram:headline(value)
    checkArg(1, value, 'function', 'nil')
    local oldValue = self._headlineCallback
    if (value) then self._headlineCallback = value end
    return oldValue
end

---@param name? string
---@return string
function Histogram:label(name)
    checkArg(1, name, 'string', 'nil')
    local oldValue = self._label
    if (name) then self._label = name end
    return oldValue
end

function Histogram:draw()
    if (not self:visible()) then return end
    --need to make an option to display data above or underneath of graph
    local headlineFunc = self._headlineCallback
    local x, y, width, height = self:absX(), self:absY(), self:width(), self:height()
    local xOffset, yOffset, maxValue = x + width - 1, y + height, self:maxValue() or height
    local totalPoints, fillChar = #self._data, self:fillChar()
    local mean, min, max = 0, maxValue, -1
    local fgColor, bgColor, txtFgColor = self:fillForegroundColor(), self:fillBackgroundColor(), self:textForegroundColor() --colors
    local oldFG, oldBG = gpu.getForeground(), gpu.getBackground()
    --draw over area
    if headlineFunc then
        height = height - 2
    end
    if bgColor then gpu.setBackground(bgColor) end
    if fgColor then gpu.setForeground(fgColor) end
    local bars = math.min(width - 1, totalPoints)
    for i = 0, bars do
        local value = math.max(self._data[totalPoints - i] or 0, 0) --math max probably not necessary
        if value > 0 then                                           --temporary debug
            local pixelHeight = math.min(math.floor((value / maxValue) * height), height)
            if value < min then min = value end
            if value > max then max = value end
            gpu.fill(xOffset - i, yOffset - pixelHeight, 1, pixelHeight, fillChar)
            mean = mean + value
        end
    end
    mean = mean / bars
    if headlineFunc then
        if txtFgColor then gpu.setForeground(txtFgColor) end
        local headline, divider = headlineFunc(self:label(), width, min, max, maxValue, mean)
        gpu.set(x, y, headline or "Headline missing!")
        gpu.set(x, y + 1, divider or string.rep("─", width))
    end
    gpu.setBackground(oldBG)
    gpu.setForeground(oldFG)
    return min, max, mean
end

return Histogram
