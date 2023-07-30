local Rectangle = require("yawl.widget.Rectangle")
local gpu = require("component").gpu
local computer = require("computer")

---@class Button
---@overload fun(parent:Frame,x:number,y:number,width:number,height:number,backgroundColor:number)
local Button = require('libClass2')(Rectangle)

function Button:defaultCallback(_, eventName, uuid, x, y, button, playerName)
    if (not (eventName == "touch")) then return end
    if self:shouldReset() then self:activate(true) else self:activate(not self:activate()) end
end

function Button:draw()
    if (not self:visible()) then return end
    local isActive = self:activate()
    if isActive and self:shouldReset() and computer.uptime() - self._pressed > self:resetTime() then
        self:activate(false)
    end
    local newBG = isActive and (self:foregroundColor() or 0xffffff-self:backgroundColor()) or self:backgroundColor()
    local oldBG = gpu.setBackground(newBG)
    gpu.fill(self:absX(), self:absY(), self:width(), self:height(), " ")
    gpu.setBackground(oldBG)
end

function Button:activate(state)
    checkArg(1, state, 'boolean', 'nil')
    local oldValue = self._active or false
    if (state ~= nil) then 
        self._active = state 
        if state then 
            self._pressed = computer.uptime()
        end
    end
    return oldValue
end

function Button:resetTime(time)
    checkArg(1, time, 'number', 'nil')
    local oldValue = self._resettime or 0
    if (time ~= nil) then self._resettime = time end
    return oldValue
end

function Button:shouldReset(should)
    checkArg(1, should, 'boolean', 'nil')
    local oldValue 
    if self._shouldReset == nil then oldValue = true else oldValue = self._shouldReset end
    if (should ~= nil) then self._shouldReset = should end
    return oldValue
end

return Button