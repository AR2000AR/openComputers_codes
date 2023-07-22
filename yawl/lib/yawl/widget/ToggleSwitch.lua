local gpu = require("component").gpu
local class = require("libClass2")
local Frame = require("yawl.widget.Frame")
local Text = require("yawl.widget.Text")
local Rectangle = require("yawl.widget.Rectangle")

---@class ToggleSwitch:Widget
---@field private _size Size
---@operator call:ToggleSwitch
---@overload fun(parent:Frame,x:number,y:number,width:number,height:number,backgroundColor:number)
local ToggleSwitch = class(Frame)

---Create a new ToggleSwitch
---@param parent Frame
---@param x number
---@param y number
---@param width number
---@param height number
---@param backgroundColor number
---@return ToggleSwitch
function ToggleSwitch:new(parent, x, y, width, height, backgroundColor, foregroundColor)
    checkArg(1, parent, 'table')
    checkArg(2, x, 'number')
    checkArg(3, y, 'number')
    checkArg(4, width, 'number')
    checkArg(5, height, 'number')
    checkArg(6, backgroundColor, 'number','nil')
    checkArg(6, foregroundColor, 'number','nil')
    local o = self.parent(parent, x, y)
    setmetatable(o, {__index = self})
    o._value = false
    o._visual = Rectangle(o, 1, 1, math.min(width, height), height, foregroundColor or 0)
    o:speed(2)
    ---@cast o ToggleSwitch
    o:size(math.max(2, width), height)
    o:backgroundColor(backgroundColor or 0xffffff) --testing defaults
    return o
end

function ToggleSwitch:set(value)
    checkArg(1, value, 'boolean', 'nil')
    local oldValue = self._value
    if (value~=nil) then self._value = value end
    return oldValue
end

function ToggleSwitch:speed(newspeed)
    checkArg(1, newspeed, 'number', 'nil')
    local oldValue = self._speed
    if (newspeed) then self._speed = math.max(newspeed, 1) / 10 end
    return oldValue
end

function ToggleSwitch:size(width, height)
    self._visual:size(height, height)
    return self.parent.size(self, width, height)
end

function ToggleSwitch:toggle()
    return self:set(not self._value)
end

function ToggleSwitch:draw()
    if (not self:visible()) then return end
    local visual = self._visual
    local x, step = visual:x(), (self._value and 1 or -1) * math.max(1, self._size.width * self._speed)
    local boundary = math.max(math.min(self:width()-visual:width()+1, x+step), 1)
    if boundary~=x then --
        visual:position(boundary, 1)
    end
    self.parent.draw(self)
end

return ToggleSwitch