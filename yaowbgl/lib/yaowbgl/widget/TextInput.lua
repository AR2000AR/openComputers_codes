local event = require("event")
local class = require("libClass2")
local Text = require("yaowbgl.widget.Text")

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
    print("key", eventName, string.char(char))
    if (eventName ~= "key_down") then return end
    if (char == 8) then      --backspace
        self:text(string.sub(self:text(), 0, -2))
    elseif (char == 13) then --return
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
    --DEBUG
    if (eventName ~= "touch") then return end
    if (not self._keyDownEvent) then
        print("reg")
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

return TextInput
