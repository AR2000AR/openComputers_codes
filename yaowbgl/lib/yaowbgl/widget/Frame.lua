local gpu = require("component").gpu
local Widget = require("yaowbgl.widget.Widget")
local event = require("event")

--=============================================================================

---@class Frame:Widget
---@field parent Widget
---@field private _parentFrame? Frame Inherited from Widget, but made optional
---@field private _childs table<number,Widget|Frame>
---@field private _listeners table
---@operator call:Frame
---@overload fun(parent:Frame,x:number,y:number):Frame
---@overload fun():Frame
---@overload fun(parent:Frame):Frame
---@overload fun(parent:Frame,position:Position):Frame
local Frame = require("libClass2")(Widget)

---@param parentFrame Frame
---@param x number
---@param y number
---@return Frame
---@overload fun(self:Frame):Frame
---@overload fun(self:Frame,parentFrame:Frame):Frame
---@overload fun(self:Frame,parentFrame:Frame,position:Position):Frame
function Frame:new(parentFrame, x, y)
    checkArg(1, parentFrame, 'table', 'nil')
    checkArg(2, x, 'number', 'nil')
    checkArg(3, y, 'number', 'nil')
    if (not x) then
        checkArg(3, y, 'nil')
        x = 1
        y = 1
    end
    local o = self.parent(parentFrame, x, y)
    setmetatable(o, {__index = self})
    ---@cast o Frame
    o._childs = {}
    o._listeners = {}
    local w, h = gpu.getViewport()
    o:size(w - o:x() + 1, h - o:y() + 1)
    if (not parentFrame) then
        table.insert(o._listeners, event.listen("touch", function(...) o:propagateEvent(...) end))
        table.insert(o._listeners, event.listen("drag", function(...) o:propagateEvent(...) end))
        table.insert(o._listeners, event.listen("drop", function(...) o:propagateEvent(...) end))
        table.insert(o._listeners, event.listen("scroll", function(...) o:propagateEvent(...) end))
        table.insert(o._listeners, event.listen("walk", function(...) o:propagateEvent(...) end))
    end
    return o
end

function Frame:closeListeners()
    for _, id in pairs(self._listeners) do
        if (type(id) == 'number') then event.cancel(id) end
    end
end

---Add a widget container to the container
---@param containerChild Widget|Frame
function Frame:addChild(containerChild)
    table.insert(self._childs, containerChild)
end

---Remove a child from the container. Return the removed child on sucess
---@generic T : Widget|Frame
---@param child T
---@return T? child
function Frame:removeChild(child)
    local childId = 0
    for i, v in pairs(self._childs) do
        if (v == child) then childId = i end
    end
    if (childId > 0) then
        table.remove(self._childs, childId)
        return child
    end
end

---@param value? number|boolean
---@return number|false
function Frame:backgroundColor(value)
    checkArg(1, value, 'number', 'boolean', 'nil')
    local oldValue = self._backgroundColor or false
    if (value ~= nil) then self._backgroundColor = value end
    return oldValue
end

function Frame:propagateEvent(eName, screenAddress, x, y, ...)
    for _, w in pairs(self._childs) do
        if (w:checkCollision(x, y)) then
            if (w:instanceOf(Frame)) then
                ---@cast w Frame
                w:propagateEvent(eName, screenAddress, x, y, ...)
            else
                w:invokeCallback(eName, screenAddress, x, y, ...)
            end
        end
    end
end

---Draw the widgets in the container
function Frame:draw()
    if (not self:visible()) then return end
    --init frame buffer
    local defaultBuffer = gpu.getActiveBuffer()
    local sucess, newBuffer = pcall(gpu.allocateBuffer, gpu.getResolution())
    if (sucess ~= false) then
        gpu.setActiveBuffer(newBuffer)
    end
    if (newBuffer and newBuffer ~= defaultBuffer) then
        gpu.bitblt(newBuffer, self:x(), self:y(), self:width(), self:height(), defaultBuffer, self:x(), self:y())
    end

    --clean background
    if (self:backgroundColor()) then
        local oldBG = gpu.getBackground()
        gpu.setBackground(self:backgroundColor() --[[@as number]])
        gpu.fill(self:absX(), self:absY(), self:width(), self:height(), " ")
        gpu.setBackground(oldBG)
    end
    --draw widgets
    table.sort(self._childs, function(a, b) return a:z() < b:z() end)
    for _, element in pairs(self._childs) do
        element:draw()
    end
    --restore buffer
    if (newBuffer and newBuffer ~= defaultBuffer) then
        gpu.bitblt(defaultBuffer, self:x(), self:y(), self:width(), self:height(), newBuffer, self:x(), self:y())
        gpu.setActiveBuffer(defaultBuffer)
        gpu.freeBuffer(newBuffer)
    end
end

return Frame
