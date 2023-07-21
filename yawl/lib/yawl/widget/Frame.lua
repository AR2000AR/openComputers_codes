local gpu = require("component").gpu
local Widget = require("yawl.widget.Widget")
local event = require("event")
local computer = require("computer")

--=============================================================================
--test bitblt bug
local bitBltFix = false
local testBuffer1 = gpu.allocateBuffer(2, 2)
local testBuffer2 = gpu.allocateBuffer(2, 2)
gpu.setActiveBuffer(testBuffer1)
gpu.set(1, 2, 'X')
gpu.bitblt(testBuffer2, 1, 2, 1, 1, testBuffer1, 1, 2)
gpu.setActiveBuffer(testBuffer2)
if (gpu.get(1, 2) == 'X') then
    bitBltFix = false
else
    bitBltFix = true
end
gpu.setActiveBuffer(0)
gpu.freeBuffer(testBuffer1)
gpu.freeBuffer(testBuffer2)

--=============================================================================

---@class Frame:Widget
---@field parent Widget
---@field private _parentFrame? Frame Inherited from Widget, but made optional
---@field protected _childs table<number,Widget|Frame>
---@field private _listeners table
---@field private _lastTouch table
---@field private _doubleTouchDelay number
---@operator call:Frame
---@overload fun():Frame
---@overload fun(parent:Frame):Frame
---@overload fun(parent:Frame,x:number,y:number):Frame
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
    o._lastTouch = {x = 0, y = 0, t = 0}
    if (not parentFrame) then
        table.insert(o._listeners, event.listen("touch", function(...) o:_touchHandler(...) end))
        table.insert(o._listeners, event.listen("drag", function(...) o:propagateEvent(...) end))
        table.insert(o._listeners, event.listen("drop", function(...) o:propagateEvent(...) end))
        table.insert(o._listeners, event.listen("scroll", function(...) o:propagateEvent(...) end))
        table.insert(o._listeners, event.listen("walk", function(...) o:propagateEvent(...) end))
    end
    return o
end

---@package
function Frame:_touchHandler(eName, screenAddress, x, y, ...)
    local cTime = computer.uptime()
    self:propagateEvent(eName, screenAddress, x, y, ...)
    if (x == self._lastTouch.x and y == self._lastTouch.y) then
        if ((cTime - self._lastTouch.t) < self:doubleTouchDelay()) then
            self:propagateEvent("double_touch", screenAddress, x, y, ...)
        end
    end
    self._lastTouch = {x = x, y = y, t = cTime}
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
    if (not self:enabled()) then return end
    for _, w in pairs(self._childs) do
        --TODO : find a new yeilding methods
        --os.sleep()
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

---@param value? number
---@return number
function Frame:doubleTouchDelay(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self._doubleTouchDelay or 0.5
    if (value ~= nil) then self._doubleTouchDelay = value end
    return oldValue
end

---Draw the widgets in the container
function Frame:draw()
    if (not self:visible()) then return end
    --init frame buffer
    local defaultBuffer = gpu.getActiveBuffer()
    local sucess, newBuffer = pcall(gpu.allocateBuffer, gpu.getResolution())
    --local sucess, newBuffer = nil, nil
    if (sucess ~= false) then
        defaultBuffer = gpu.setActiveBuffer(newBuffer)
    end

    if (newBuffer and newBuffer ~= defaultBuffer) then
        --copy the old buffer in the new buffer for transparancy effect
        if (bitBltFix) then
            gpu.bitblt(newBuffer, self:absX(), self:absY(), self:width(), self:height(), defaultBuffer, self:absY(), self:absX())
        else
            gpu.bitblt(newBuffer, self:absX(), self:absY(), self:width(), self:height(), defaultBuffer, self:absX(), self:absY())
        end
    end

    --clean background
    if (self:backgroundColor()) then
        local oldBG = gpu.getBackground()
        gpu.setBackground(self:backgroundColor() --[[@as number]])
        gpu.fill(self:absX(), self:absY(), self:width(), self:height(), " ")
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
        if (bitBltFix) then
            gpu.bitblt(defaultBuffer, self:absX(), self:absY(), self:width(), self:height(), newBuffer, self:absY(), self:absX())
        else
            gpu.bitblt(defaultBuffer, self:absX(), self:absY(), self:width(), self:height(), newBuffer, self:absX(), self:absY())
        end
        gpu.setActiveBuffer(defaultBuffer)
        gpu.freeBuffer(newBuffer)
    end
end

return Frame
