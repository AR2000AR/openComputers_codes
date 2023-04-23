--force unload the lib
local pkg = {}
for pkgn, _ in pairs(require("package").loaded) do
    if (pkgn:match("^yaowbgl")) then
        table.insert(pkg, pkgn)
    end
end
for _, pkgn in pairs(pkg) do
    require("package").loaded[pkgn] = nil
end

local yaowbgl = require("yaowbgl")
local term = require("term")
local os = require("os")
local io = require("io")

io.output("/dev/socket"):setvbuf("line")
--io.error("/dev/socket"):setvbuf("line")

term.clear()

MSG = "123456789 123456789 123456789 123456789 abcdefghijklmnopqrstuvwxyz "

local superRoot = yaowbgl.widget.Frame()
superRoot:backgroundColor(0x0000ff)

local rootFrame = yaowbgl.widget.Frame(superRoot, 5, 5)
rootFrame:backgroundColor(0xffff00)
rootFrame:size(20, 10)

local rectangle = yaowbgl.widget.Rectangle(rootFrame, 1, 1, 10, 3, 0xffffff)
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
local text = yaowbgl.widget.Text(rootFrame, 3, 5, "", 0x00ff00)
text:maxWidth(rootFrame:width() - (text:x() - 1))
--text:maxHeight(2)

local textBg = yaowbgl.widget.Rectangle(rootFrame, 0, 0, 0, 0, 0x7f7f7f)
textBg:position(text:position())
textBg:size(text:size())
textBg:z(text:z() - 1)

local img = yaowbgl.widget.Image(superRoot, 15, 5, "/home/vortex.pam")
local input = yaowbgl.widget.TextInput(superRoot, 3, 20, "", 0xffffff)
input:minSize(30, 1)
local r2 = yaowbgl.widget.Rectangle(superRoot, input:x(), input:y(), input:width(), input:height(), 0)
r2:z(input:z() - 1)

local function refreshSize()
    text:text(MSG:sub(1, #text:text() + 1))
    textBg:size(text:size())
    r2:size(input:size())
end

local function animate()
    superRoot:draw()
    if (#text:text() == #MSG) then
        return false
    end
    refreshSize()
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
while run do
    os.sleep()
    refreshSize()
    superRoot:draw()
end
term.clear()
superRoot:closeListeners()
