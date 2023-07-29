local gpu = require("component").gpu
local text = require("text")

--=============================================================================

---@class Text:Widget
---@field private _text string
---@field private _foregroundColor number
---@field private _maxWidth number
---@field private _maxHeight number
---@overload fun(parent:Frame,x:number,y:number,text:string,foregroundColor:number):Text
---@operator call:Text
local Text = require('libClass2')(require("yawl.widget.Widget"))

---@param parent Frame
---@param x number
---@param y number
---@param text string
---@param foregroundColor number
---@return Text
function Text:new(parent, x, y, text, foregroundColor)
    local o = self.parent(parent, x, y)
    checkArg(1, parent, 'table')
    checkArg(2, x, 'number', 'table')
    checkArg(3, y, 'number', 'nil')
    checkArg(4, text, 'string')
    checkArg(5, foregroundColor, 'number')
    if (type(x) == "table") then checkArg(3, y, 'nil') else checkArg(3, y, 'number') end
    setmetatable(o, {__index = self})
    ---@cast o Text
    o:text(text)
    o:foregroundColor(foregroundColor)
    return o
end

---@param value? string
---@return string
function Text:text(value)
    checkArg(1, value, 'string', 'nil')
    local oldValue = self._text
    if (value) then self._text = value end
    return oldValue
end

---@param value? number
---@return number
function Text:maxWidth(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self._maxWidth or math.huge
    if (value and value > self:maxHeight()) then error("maxWidth cannot be smaller than minWidth", 2) end
    if (value) then self._maxWidth = value end
    return oldValue
end

---@param value? number
---@return number
function Text:maxHeight(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self._maxHeight or math.huge
    if (value and value > self:maxHeight()) then error("maxHeight cannot be smaller than minHeight", 2) end
    if (value) then self._maxHeight = value end
    return oldValue
end

---Set the Text's min size.
---@param maxWidth number
---@param maxHeight number
---@return Size
---@overload fun(self:Rectangle,size:Size):Size
---@overload fun(self:Rectangle):Size
function Text:maxSize(maxWidth, maxHeight)
    checkArg(1, maxWidth, 'number', 'table', 'nil')
    checkArg(2, maxHeight, 'number', 'nil')
    local oldPos = {width = self:maxWidth(), height = self:maxHeight()}
    if (type(maxWidth) == 'number') then
        self:maxWidth(maxWidth)
        self:maxHeight(maxHeight)
    elseif (type(maxWidth) == 'table') then
        checkArg(2, maxHeight, 'nil')
        self._size = maxWidth
    end
    return oldPos
end

---@param value? number
---@return number
function Text:minWidth(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self._minWidth or 0
    if (value and value > self:maxWidth()) then error("minWidth cannot be larger than maxWidth", 2) end
    if (value) then self._minWidth = value end
    return oldValue
end

---@param value? number
---@return number
function Text:minHeight(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self._minHeight or 0
    if (value and value > self:maxHeight()) then error("minHeight cannot be larger than maxHeight", 2) end
    if (value) then self._minHeight = value end
    return oldValue
end

---Set the Text's min size.
---@param minWidth number
---@param minHeight number
---@return Size
---@overload fun(self:Rectangle,size:Size):Size
---@overload fun(self:Rectangle):Size
function Text:minSize(minWidth, minHeight)
    checkArg(1, minWidth, 'number', 'table', 'nil')
    checkArg(2, minHeight, 'number', 'nil')
    local oldPos = {width = self:minWidth(), height = self:minHeight()}
    if (type(minWidth) == 'number') then
        self:minWidth(minWidth)
        self:minHeight(minHeight)
    elseif (type(minWidth) == 'table') then
        checkArg(2, minHeight, 'nil')
        self._size = minWidth
    end
    return oldPos
end

---@param value? number
---@return number
function Text:height(value)
    local lines = 0
    for line in text.wrappedLines(self:text(), self:maxWidth(), self:maxWidth()) do
        lines = lines + 1
    end
    if (value ~= nil) then
        self:minHeight(0)
        self:maxHeight(math.huge)
        self:minHeight(value)
        self:maxHeight(value)
    end
    return math.min(math.max(self:minHeight(), lines), self:maxHeight())
end

---@param value? number
---@return number
function Text:width(value)
    local maxTextWidth = -1
    for line in text.wrappedLines(self:text(), self:maxWidth(), self:maxWidth()) do
        if (#line > maxTextWidth) then
            maxTextWidth = #line
        end
    end
    if (value ~= nil) then
        self:minWidth(0)
        self:maxWidth(math.huge)
        self:minWidth(value)
        self:maxWidth(value)
    end
    return math.min(math.max(self:minWidth(), maxTextWidth), self:maxWidth())
end

---@param value? boolean
---@return boolean
function Text:center(value)
    checkArg(1, value, 'boolean', 'nil')
    local oldValue = self._center or false
    if (value ~= nil) then self._center = value end
    return oldValue
end

function Text:draw()
    if (not self:visible()) then return end
    local oldFgColor = gpu.setForeground(self:foregroundColor())
    local oldBgColor = gpu.getBackground()
    if (self:backgroundColor()) then
        gpu.setBackground(self:backgroundColor())
        gpu.fill(self:absX(), self:absY(), self:width(), self:height(), " ")
    end
    local y = self:absY()
    for line in text.wrappedLines(self:text(), self:maxWidth(), self:maxWidth()) do
        ---@cast line string
        if ((y - self:absY()) + 1 <= self:maxHeight()) then
            local x = self:absX()
            if (self:center() and self:minWidth() == self:maxWidth()) then
                x = x + (self:width() - #line) / 2
            end
            for c in line:gmatch(".") do
                local s, _, _, bg = pcall(gpu.get, x, y)
                if (s ~= false) then
                    gpu.setBackground(bg)
                    gpu.set(x, y, c)
                    x = x + 1
                end
            end
        end
        y = y + 1
    end
    gpu.setForeground(oldFgColor)
    gpu.setBackground(oldBgColor)
end

return Text
