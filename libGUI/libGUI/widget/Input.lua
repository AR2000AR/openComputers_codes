local event = require("event")

local Input = require("libClass").newClass("Text",require("libGUI/widget/Text"))

Input.private.keyDownEvent = nil
Input.private.touchEvent = nil
function Input.private.onKeyDown(self,eventName,component,char,key,player)
    if(not eventName == "key_down") then return end
    if(char == 8) then --backspace
        self:setText(string.sub(self:getText(),0,-2))
    elseif(char == 13) then --return
        event.cancel(self.private.keyDownEvent)
        self.private.keyDownEvent = nil
        event.cancel(self.private.touchEvent)
        self.private.touchEvent = nil
    else
        self:setText(string.format("%s%s",self:getText(),string.char(char)))
    end
end
function Input.private.callback(self,eventName,uuid,x,y,button,playerName)
    if(not self.private.keyDownEvent) then
        self.private.keyDownEvent = event.listen("key_down",function(...) self.private.onKeyDown(self,...) end)
        self.private.touchEvent = event.listen("touch", function(eventName,uuid,x,y,button,playerName)
            if(not self:collide(x,y)) then
                event.cancel(self.private.keyDownEvent)
                self.private.keyDownEvent = nil
                event.cancel(self.private.touchEvent)
                self.private.touchEvent = nil
            end
        end)
    end
end

return Input