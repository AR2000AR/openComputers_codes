local libGUI = require("libGUI")
local event = require("event")
local os = require("os")

local run = true --used in the main loop

--create a screen to put our widgets in
local screen = libGUI.Screen()

--create a rectangle on the screen
--Rectangle(int x,int y, int width, int height,int hexColor)
local rectangle = libGUI.widget.Rectangle(1, 1, 10, 3, 0xff0000)
--add the widget to the screen
screen:addChild(rectangle)
--add some text
--Text(int x,int y, int width, int height,int textHexColor, String text)
local text = libGUI.widget.Text(1, 5, 6, 3, 0xffffff, "Exit")
--set the text background color
text:setBackground(0x006dff)
--give a callback method to the widget to be called when touched / clicked
--the first argument will be the object itself, the next are defined by the touch event
text:setCallback(function(self, eventName, componentAddr, x, y, button, playerName) run = false end)
--add the widget to the screen
screen:addChild(text)

--register the screen's touch event handler
--the callback method of a object is called by screen.trigger if the touch event is on it
local touchEvent = event.listen("touch", function(...) screen:trigger(...) end)

--main loop
while (run) do
    --draw the screen
    --the draw method use a framebuffer, only one screen can be visible at a time
    --the widgets are drawn in the same order they were added to the screen
    screen:draw()
    --sleep so the events can be processed
    ---@diagnostic disable-next-line: undefined-field
    os.sleep()
end
--stop processing touch events
event.cancel(touchEvent)
