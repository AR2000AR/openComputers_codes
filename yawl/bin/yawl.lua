--unload the library if loaded. Usueful during developpenent of yawl
local pkg = {}
for pkgn, _ in pairs(require("package").loaded) do
    if (pkgn:match("^yawl")) then
        table.insert(pkg, pkgn)
    end
end
for _, pkgn in pairs(pkg) do
    require("package").loaded[pkgn] = nil
end

local yawl = require("yawl")
local term = require("term")
local os = require("os")


local root = yawl.widget.Frame()             --Create a root frame.
root:backgroundColor(0x0000ff)               --Set the frame's background to blue. If no color is set, the screen is not cleared (transparent Frame)

local frame1 = yawl.widget.Frame(root, 2, 2) --Create a second Frame
frame1:backgroundColor(0xffff00)             --Set this second frame's background to yellow
frame1:size(20, 11)                          --Set the Fame size. By default it take the rest of the screen


yawl.widget.Text(frame1, 1, 1, "Rectangle button :", 0)                --A simple text
local rectangle = yawl.widget.Rectangle(frame1, 1, 2, 10, 3, 0xffffff) --A white rectangle
--define a function that's called whne a `touch` `walk` `drag` `scroll` or `drop` or the custom `double_touch` event is triggered
rectangle:callback(
    function(self, _, eventName, ...)
        if (eventName == "touch") then
            if (self:backgroundColor() == 0xffffff) then
                self:backgroundColor(0)
            else
                self:backgroundColor(0xffffff)
            end
        elseif (eventName == "double_touch") then
            self:backgroundColor(0x00ff00)
        end
        --self:draw()
    end)

local textLabel = yawl.widget.Text(frame1, 1, 5, "Text :", 0)                                          --A simple text
local text = yawl.widget.Text(frame1, 1, textLabel:y() + 1, "", 0x00ff00)                              --A other text. This one will be animated later
text:maxWidth(frame1:width() - (text:x() - 1))                                                         --define the text's max width. Used to demonstrate the word wrapping functionality
text:backgroundColor(0x7f7f7f)                                                                         --set the background color

local input = yawl.widget.TextInput(root, 2, frame1:y() + frame1:height() + 2, "Text input", 0xffffff) --A subclass of Text for user input
input:minSize(30, 1)                                                                                   --set the input minimum size. It will grow as needed
input:multilines(true)                                                                                 --set the input to accept multiples lines of text
input:backgroundColor(0)                                                                               --black background

local frameList = yawl.widget.WidgetList(root, 30, 2)                                                  --WidgetList is a subclass of Frame that orders the widgets inside
yawl.widget.Text(frameList, 1, 1, "WidgetList :", 0)                                                   --Label
local list = yawl.widget.WidgetList(frameList, 1, 1)                                                   --A second WidgetList inside the firt one
list:size(20, 6)                                                                                       --set the container's size
frameList:size(list:width(), list:height() + 1)                                                        --set the first container's size
list:backgroundColor(0xffffff)                                                                         --set the container's background color
for i = 1, 5 do                                                                                        --create 5 Text. One of them will be out of view
    local text = string.format("Text %d", i)
    local bk = nil
    if (i % 2 == 0) then
        text = text .. "\n second line"
        bk = 0xcecece
    end
    local t = yawl.widget.Text(list, 0, 0, text, 0)
    t:center(true)
    t:width(list:width())
    t:backgroundColor(bk)
end

local b = yawl.widget.Border(root, 52, 2)
local bText = yawl.widget.Text(b, 1, 1, "Bordered text", 0xffffff)
bText:backgroundColor(0)
b:backgroundColor(0xff0000)

local function animate() --animate the text widget. Add one char with each loop
    local MSG = "123456789 123456789 123456789 123456789 abcdefghijklmnopqrstuvwxyz "
    root:draw()
    text:text(MSG:sub(1, #(text:text()) + 1))
    if (#(text:text()) == #MSG) then
        return false
    end
    os.sleep(3 / #MSG)
    return true
end
while animate() do
end
local exitText = yawl.widget.Text(root, 1, root:height(), " Press CTRL+C to exit", 0xffffff)
exitText:width(root:width())
exitText:backgroundColor(0)
local run = true
require("event").listen("interrupted", function()
    run = false;
    root:closeListeners()
    return false
end)
root:draw()
while run do
    os.sleep(0.1)
    root:draw()
end
term.clear()
root:closeListeners() --always call that on all Frame without a parent. This is used to unregister the event listeners for screen related events
