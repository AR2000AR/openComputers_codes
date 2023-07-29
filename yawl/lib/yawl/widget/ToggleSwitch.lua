local gpu = require("component").gpu
local class = require("libClass2")
local Widget = require("yawl.widget.Widget")

---@class ToggleSwitch:Widget
---@field parent Widget
---@field private _speed number
---@field private _slider table
---@operator call:ToggleSwitch
---@overload fun(parent:Frame,x:number,y:number,width:number,height:number,backgroundColor:number|nil,foregroundColor:number|nil):ToggleSwitch
local ToggleSwitch = class(Widget)

---Create a new ToggleSwitch
---@param parent Frame
---@param x number
---@param y number
---@param width number
---@param height number
---@param backgroundColor? number
---@param foregroundColor? number
---@return ToggleSwitch
function ToggleSwitch:new(parent, x, y, width, height, backgroundColor, foregroundColor)
    checkArg(1, parent, 'table')
    checkArg(2, x, 'number')
    checkArg(3, y, 'number')
    checkArg(4, width, 'number')
    checkArg(5, height, 'number')
    checkArg(6, backgroundColor, 'number', 'nil')
    checkArg(6, foregroundColor, 'number', 'nil')
    local o = self.parent(parent, x, y)
    setmetatable(o, {__index = self})
    ---@cast o ToggleSwitch
    o._value = false
    o._slider = {x = 0, width = height, height = height, backgroundColor = foregroundColor}
    o:speed(2)
    ---@cast o ToggleSwitch
    o:size(math.max(2, width), height)
    o:backgroundColor(backgroundColor)
    return o
end

function ToggleSwitch:defaultCallback(_, eventName)
    if (eventName == "touch") then
        self:toggle()
    end
end

---@param value? boolean
---@return boolean
function ToggleSwitch:value(value)
    checkArg(1, value, 'boolean', 'nil')
    local oldValue = self._value
    if (value ~= nil) then self._value = value end
    return oldValue
end

---Speed is between greater that 1
---@param newspeed? number
---@return number
function ToggleSwitch:speed(newspeed)
    checkArg(1, newspeed, 'number', 'nil')
    local oldValue = self._speed
    if (newspeed) then self._speed = math.max(newspeed, 1) end
    return oldValue
end

--size already call :width() and :heigh()
--[[ function ToggleSwitch:size(width, height)
    self._slider.width, self._slider.height = height, height
    return self.parent.size(self, width, height)
end ]]

function ToggleSwitch:switchSize(width, height) --fix later
    self._slider.width, self._slider.height = height, height
    return self.parent.size(self, width, height)
end

function ToggleSwitch:toggle()
    return self:value(not self:value())
end

---The background color when the switch is on
---@param value? number
---@return number
function ToggleSwitch:activeBackgroundColor(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self._activeBackgroundColor
    if (value ~= nil) then self._activeBackgroundColor = value end
    return oldValue
end

function ToggleSwitch:draw()
    if (not self:visible()) then return end
    local x, y = self:absX(), self:absY()
    local sliderX, step = self._slider.x, (self:value() and 1 or -1) * math.max(1, self:width() * self:speed() / 10)
    local boundary = math.max(math.min(self:width() - self._slider.width, sliderX + step), 0)
    local oldBG = gpu.getBackground()
    gpu.setBackground(self:backgroundColor())
    gpu.fill(x, y, self:width(), self:height(), " ")
    gpu.setBackground(self._slider.backgroundColor)
    gpu.fill(x + boundary, y, self._slider.width, self._slider.height, " ")
    if boundary ~= sliderX then
        self._slider.x = boundary
    end
    local activeBG = self:activeBackgroundColor()
    if activeBG and boundary - 1 > 0 then
        gpu.setBackground(activeBG)
        gpu.fill(x, y, boundary, self:height(), " ")
    end
    gpu.setBackground(oldBG)
end

return ToggleSwitch
