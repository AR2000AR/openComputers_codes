local shell = require("shell")
local term = require("term")
local fs = require("filesystem")
local libgui = require("libGUI")
local gpu = require("component").gpu

local args, opts = shell.parse(...)

if (fs.exists(args[1]) and not fs.isDirectory(args[1])) then
  local bk = gpu.getBackground()
  local drawMethod = false
  if (args[3] ~= nil and args[3]:lower() == "true") then drawMethod = true end
  gpu.setBackground(tonumber(args[2] or "") or bk)
  term.clear()
  libgui.widget.Image(1, 1, args[1], drawMethod):draw()
  ---@diagnostic disable-next-line: undefined-field
  os.sleep(1)
  require("event").pull("key_down")
  gpu.setBackground(bk)
  term.clear()
else
  print("Not a file")
end
