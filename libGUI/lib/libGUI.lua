local gpu = require("component").gpu
local event = require("event")
local uuid = require("uuid")
local class = require("libClass")
local fs = require("filesystem")

local libGUI = {widget = {}}
for widgetFileName in fs.list("/usr/lib/libGUI/widget") do
  libGUI.widget[widgetFileName:sub(1, #widgetFileName - 4)] = require("libGUI/widget/" .. widgetFileName:sub(1, #widgetFileName - 4))
end
libGUI.Screen = require("libGUI/Screen")
libGUI.Image = require("libGUI/ImageFile")

return libGUI
