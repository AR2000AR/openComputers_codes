local class = require("libClass2")
local Frame = require("yawl.widget.Frame")
local gpu = require("component").gpu

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
function Border:new(parent, x, y, borderset) --borderset can be string too
    checkArg(1, parent, "table")
    checkArg(1, borderset, "string", nil)
    local o = self.parent(parent, x, y)
    setmetatable(o, {__index = self})
    o._borderSet = borderset
    ---@cast o Border
    return o
end

---@return Widget
function Border:master()
    return self._childs[1]
end

function Border:foregroundColor(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self._foregroundColor
    if (value) then self._foregroundColor = value end
    return oldValue
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
    local x, y, width, height = self:absX(), self:absY(), self:width(), self:height()
    local defaultBuffer = gpu.getActiveBuffer()
    local success, newBuffer = pcall(gpu.allocateBuffer, gpu.getResolution())
    --local success, newBuffer = nil, nil
    if (success ~= false) then
        defaultBuffer = gpu.setActiveBuffer(newBuffer)
    end

    if (newBuffer and newBuffer ~= defaultBuffer) then
        --copy the old buffer in the new buffer for transparancy effect
        gpu.bitblt(defaultBuffer, x, y, width, height, newBuffer, self._bitBltFix and y or x, self._bitBltFix and x or y)
    end

    --clean background
    if (self:backgroundColor()) then
        local oldBG = gpu.getBackground()
        gpu.setBackground(self:backgroundColor() --[[@as number]])
        gpu.fill(x, y, width, height, " ")
        local borderSet = self._borderSet
        if borderSet then
            local oldFG = self._foregroundColor and gpu.getForeground()
            if oldFG then gpu.setForeground(self._foregroundColor) end
            local unicode = require("unicode")
            local setLength = unicode.len(borderSet)
            if setLength > 3 then 
                gpu.set(x, y, unicode.sub(borderSet, 1,1)) --topleft
                gpu.set(x+width-1, y, unicode.sub(borderSet, 2,2)) --topright
                gpu.set(x, y+height-1, unicode.sub(borderSet, 3,3)) --bottomleft
                gpu.set(x+width-1, y+height-1, unicode.sub(borderSet, 4,4)) --bottomright
                if setLength > 4 then
                    gpu.fill(x+1, y, width-2, 1, unicode.sub(borderSet, 5,5)) --top
                    if setLength == 6 then
                        gpu.fill(x+1, y+height-1, width-2, 1, unicode.sub(borderSet, 5,5)) --bottom
                        gpu.fill(x, y+1, 1, height-2, unicode.sub(borderSet, 6,6)) --left
                        gpu.fill(x+width-1, y+1, 1, height-2, unicode.sub(borderSet, 6,6)) -- right
                    elseif setLength == 8 then
                        gpu.fill(x+1, y+height-1, width-2, 1, unicode.sub(borderSet, 6,6)) --bottom
                        gpu.fill(x, y+1, 1, height-2, unicode.sub(borderSet, 7,7)) --left
                        gpu.fill(x+width-1, y+1, 1, height-2, unicode.sub(borderSet, 8,8)) -- right
                    end
                end
            end
            if oldFG then gpu.setForeground(oldFG) end
        end
        gpu.setBackground(oldBG)
    end

    --sort widgets by z
    local unsorted = false
    for i, w in pairs(self._childs) do
        if (i > 1) then
            if (self._childs[i - 1]:z() > w:z()) then
                unsorted = true
                break
            end
        end
    end
    if (unsorted) then table.sort(self._childs, function(a, b) return a:z() < b:z() end) end

    --draw widgets
    for _, element in pairs(self._childs) do
        element:draw()
    end
    --restore buffer
    if (newBuffer and newBuffer ~= defaultBuffer) then
        gpu.bitblt(defaultBuffer, x, y, width, height, newBuffer, self._bitBltFix and y or x, self._bitBltFix and x or y)
        gpu.setActiveBuffer(defaultBuffer)
        gpu.freeBuffer(newBuffer)
    end
end

return Border