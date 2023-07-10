--force unload the lib
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
local io = require("io")

--io.output("/dev/socket"):setvbuf("line")
--io.error("/dev/socket"):setvbuf("line")

term.clear()

MSG = "123456789 123456789 123456789 123456789 abcdefghijklmnopqrstuvwxyz "

local superRoot = yawl.widget.Frame()
superRoot:backgroundColor(0x0000ff)

local rootFrame = yawl.widget.Frame(superRoot, 5, 5)
rootFrame:backgroundColor(0xffff00)
rootFrame:size(20, 10)

local rectangle = yawl.widget.Rectangle(rootFrame, 1, 1, 10, 3, 0xffffff)
rectangle:callback(
    function(self, _, eventName, ...)
        if (not (eventName == "touch")) then return end
        if (self:backgroundColor() == 0xffffff) then
            self:backgroundColor(0)
        else
            self:backgroundColor(0xffffff)
        end
        self:draw()
    end)


local text = yawl.widget.Text(rootFrame, 1, 4, "", 0x00ff00)
text:maxWidth(rootFrame:width() - (text:x() - 1))
--text:maxHeight(2)
text:backgroundColor(0x7f7f7f)

--[[ local imgFrame = yawl.widget.Frame(superRoot, 49, 5)
local img = yawl.widget.Image(imgFrame, 1, 1, "/home/vortex.pam")
local img2 = yawl.widget.Image(imgFrame, 1, 1, "/home/sg00.pam")
img2:z(img:z() + 1)
imgFrame:size(img:size())
imgFrame:backgroundColor(0xffffff)]]
local input = yawl.widget.TextInput(superRoot, 3, 20, "", 0xffffff)
input:minSize(30, 1)
input:multilines(true)
input:backgroundColor(0)
local r2 = yawl.widget.Rectangle(superRoot, input:x(), input:y(), input:width(), input:height(), 0)
r2:z(input:z() - 1)


local list = yawl.widget.WidgetList(superRoot, 30, 3)
list:size(20, 6)
list:backgroundColor(0xffffff)
local t1 = yawl.widget.Text(list, 0, 0, "test1", 0)
t1:size(20, 1)
t1:center(true)
local t2 = yawl.widget.Text(list, 0, 0, "test2", 0)
t2:size(20, 1)
t2:center(true)
local t3 = yawl.widget.Text(list, 0, 0, "test3", 0)
t3:size(20, 1)
t3:center(true)
local t4 = yawl.widget.Text(list, 0, 0, "test4", 0)
t4:size(20, 1)
t4:center(true)
local t5 = yawl.widget.Text(list, 0, 0, "test5", 0)
t5:size(20, 1)
t5:center(true)

local function animate()
    superRoot:draw()
    text:text(MSG:sub(1, #(text:text()) + 1))
    if (#(text:text()) == #MSG) then
        return false
    end
    os.sleep(3 / #MSG)
    return true
end
while animate() do
end
local run = true
require("event").listen("interrupted", function()
    run = false;
    return false
end)
superRoot:draw()
---img:visible(false)
while run do
    os.sleep(0.1)
    superRoot:draw()
end
term.clear()
superRoot:closeListeners()
