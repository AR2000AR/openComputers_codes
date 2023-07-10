local event = require("event")
local text = require("text")
local class = require("libClass2")
local Text = require("yawl.widget.Text")
local gpu = require("component").gpu

---@class TextInput:Text
---@field private _keyDownEvent number
---@field private _touchEvent number
---@field private _placeHolderChar string
---@operator call:TextInput
---@overload fun(parent:Frame,x:number,y:number,text:string,foregroundColor:number):TextInput
local TextInput = require('libClass2')(Text)

---@param value? string
---@return string
function TextInput:placeholder(value)
    checkArg(1, value, 'string', 'nil')
    local oldValue = self._placeholder
    if (value) then self._placeholder = value end
    return oldValue
end

function TextInput:_onKeyDown(eventName, component, char, key, player)
    if (eventName ~= "key_down") then return end
    if (char == 8) then                                --backspace
        self:text(string.sub(self:text(), 0, -2))
    elseif (char == 13 and not self:multilines()) then --return
        event.cancel(self._keyDownEvent)
        self._keyDownEvent = nil
        event.cancel(self._touchEvent)
        self._touchEvent = nil
    elseif (char ~= 0) then
        self:text(self:text() .. string.char(char))
    end
end

function TextInput:callback(callback, ...)
    checkArg(1, callback, 'nil')
    return TextInput.defaultCallback
end

function TextInput:defaultCallback(_, eventName, uuid, x, y, button, playerName)
    if (eventName ~= "touch") then return end
    if (not self._keyDownEvent) then
        self._keyDownEvent = event.listen("key_down", function(...) self:_onKeyDown(...) end) --[[@as number]]
        self._touchEvent = event.listen("touch", function(eventName, uuid, x, y, button, playerName)
            if (not self:checkCollision(x, y)) then
                if (self._keyDownEvent) then event.cancel(self._keyDownEvent --[[@as number]]) end
                self._keyDownEvent = nil
                if (self._touchEvent) then event.cancel(self._touchEvent --[[@as number]]) end
                self._touchEvent = nil
            end
        end) --[[@as number]]
    end
end

---@param value? boolean
---@return boolean
function TextInput:multilines(value)
    checkArg(1, value, 'boolean', 'nil')
    local oldValue = self._multilines or false
    if (value ~= nil) then self._multilines = value end
    return oldValue
end

function TextInput:cursorPos()
    local y = self:absY()
    for line in text.wrappedLines(self:text(), self:maxWidth(), self:maxWidth()) do
        ---@cast line string
        if ((y - self:absY()) + 1 <= self:maxHeight()) then
            local x = self:absX() + #line
        end
        y = y + 1
    end
end

function TextInput:draw()
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
                    gpu.set(x, y, self:placeholder() or c)
                    x = x + 1
                end
            end
        end
        y = y + 1
    end
    gpu.setForeground(oldFgColor)
    gpu.setBackground(oldBgColor)
end

return TextInput
