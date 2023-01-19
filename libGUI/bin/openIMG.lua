local shell = require("shell")
local term = require("term")
local fs = require("filesystem")
local libgui = require("libGUI")
local gpu = require("component").gpu

local oldX, oldY = gpu.getResolution()

local args, opts = shell.parse(...)
args[1] = shell.resolve(args[1])

if (fs.exists(args[1]) and not fs.isDirectory(args[1])) then
  local bk = gpu.getBackground()
  local drawMethod = true
  if (args[3] ~= nil and args[3]:lower() == "true") then drawMethod = true end
  if (args[3] ~= nil and args[3]:lower() == "false") then drawMethod = false end
  gpu.setBackground(tonumber(args[2] or "") or bk)
  term.clear()
  local screen = libgui.Screen()
  local img = libgui.widget.Image(1, 1, args[1], drawMethod)
  gpu.setResolution(img:getWidth(), img:getHeight())
  screen:addChild(img)
  screen:draw()
  ---@diagnostic disable-next-line: undefined-field
  os.sleep(1)
  require("event").pull("key_down")
  gpu.setBackground(bk)
  gpu.setResolution(oldX, oldY)
  term.clear()
else
  print("Not a file")
end
