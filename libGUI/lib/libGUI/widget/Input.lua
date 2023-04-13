local event = require("event")

local Input = require("libClass").newClass("Text", require("libGUI/widget/Text"))

Input.private.keyDownEvent = nil
Input.private.touchEvent = nil
Input.private.placeHolderChar = nil
Input.private.value = ""
function Input.setPlaceholder(self, char)
    if (char and #char == 1) then
        self.private.placeHolderChar = char
    else
        self.private.placeHolderChar = nil
    end
end

function Input.getPlaceholder(self) return self.private.placeHolderChar end

function Input.setText(self, text)
    text = text or ""
    self.private.value = text
    if (self:getPlaceholder()) then
        self.private.text = string.rep(self:getPlaceholder(), #self:getValue())
    else
        self.private.text = text
    end
end

function Input.getValue(self) return self.private.value end

function Input.setValue(self, text) self:setText(text) end

function Input.private.onKeyDown(self, eventName, component, char, key, player)
    if (not eventName == "key_down") then return end
    if (char == 8) then      --backspace
        self:setText(string.sub(self:getValue(), 0, -2))
    elseif (char == 13) then --return
        event.cancel(self.private.keyDownEvent)
        self.private.keyDownEvent = nil
        event.cancel(self.private.touchEvent)
        self.private.touchEvent = nil
    elseif (char ~= 0) then
        self:setText(string.format("%s%s", self:getValue(), string.char(char)))
    end
end

function Input.private.callback(self, eventName, uuid, x, y, button, playerName)
    if (not self.private.keyDownEvent) then
        self.private.keyDownEvent = event.listen("key_down", function(...) self.private.onKeyDown(self, ...) end)
        self.private.touchEvent = event.listen("touch", function(eventName, uuid, x, y, button, playerName)
            if (not self:collide(x, y)) then
                if (self.private.keyDownEvent) then event.cancel(self.private.keyDownEvent --[[@as number]]) end
                self.private.keyDownEvent = nil
                if (self.private.touchEvent) then event.cancel(self.private.touchEvent --[[@as number]]) end
                self.private.touchEvent = nil
            end
        end)
    end
end

function Input.constructor(self, x, y, width, height, color, text, placeHolderChar)
    self:setPlaceholder(placeHolderChar)
    self:setText(text) --need to be called after setting the placeholder char
end

return Input
