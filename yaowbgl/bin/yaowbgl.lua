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
io.error("/dev/socket"):setvbuf("line")

term.clear()

MSG = "123456789 123456789 123456789 123456789 abcdefghijklmnopqrstuvwxyz "

local superRoot = yaowbgl.widget.Frame()
superRoot:backgroundColor(0x0000ff)

local rootFrame = yaowbgl.widget.Frame(superRoot, 5, 5)
--rootFrame:backgroundColor(0xffff00)
rootFrame:size(20, 10)

local rectangle = yaowbgl.widget.Rectangle(rootFrame, 1, 1, 10, 3, 0xffffff)
rectangle:callback(
    function(self, _, eventName, ...)
        if (not (eventName == "touch")) then return end
        print(eventName)
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

local function animate()
    superRoot:draw()
    if (#text:text() == #MSG) then
        return false
    end
    text:text(MSG:sub(1, #text:text() + 1))
    textBg:size(text:size())
    os.sleep(5 / #MSG)
    return true
end
while animate() do
end
local e = nil
repeat
    e = require('event').pull(0.1)
    os.sleep()
until e == "key_down"
term.clear()
superRoot:closeListeners()
