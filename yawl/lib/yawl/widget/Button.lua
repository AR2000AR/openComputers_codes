local Rectangle = require("yawl.widget.Rectangle")
local gpu = require("component").gpu
local computer = require("computer")

---@class Button:Rectangle
---@overload fun(parent:Frame,x:number,y:number,width:number,height:number,backgroundColor:number):Button
local Button = require('libClass2')(Rectangle)

function Button:defaultCallback(_, eventName, uuid, x, y, button, playerName)
    if (not (eventName == "touch")) then return end
    self:state(not self:state())
end

function Button:draw()
    if (not self:visible()) then return end
    if self:resetTime() > 0 and self:state() and (computer.uptime() - self._pressed) > self:resetTime() then
        self:state(false)
    end
    local newBG = self:state() and (self:foregroundColor() or 0xffffff - self:backgroundColor()) or self:backgroundColor()
    local oldBG = gpu.setBackground(newBG)
    gpu.fill(self:absX(), self:absY(), self:width(), self:height(), " ")
    gpu.setBackground(oldBG)
end

---Change or get the button's state
---@param state? boolean
---@return boolean
function Button:state(state)
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

---Setter and getter for the reset time.
---Set to 0 to disable
---@param time? number
---@return number
function Button:resetTime(time)
    checkArg(1, time, 'number', 'nil')
    local oldValue = self._resettime or 0
    if (time ~= nil) then self._resettime = time end
    return oldValue
end

return Button
