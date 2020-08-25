local shell = require("shell")
local term = require("term")
local fs = require("filesystem")
local libgui = require("libgui")
local gpu = require("component").gpu

local args,opts = shell.parse(...)

if(fs.exists(args[1]) and not fs.isDirectory(args[1])) then
  local bk = gpu.getBackground()
  gpu.setBackground(tonumber(args[2]or bk,16))
  term.clear()
  libgui.widget.Image(1,1,args[1]):draw()
  os.sleep(1)
  require("event").pull("key_down")
  gpu.setBackground(bk)
  term.clear()
else
  print("Not a file")
end
