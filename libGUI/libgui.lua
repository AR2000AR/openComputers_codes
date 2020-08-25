local gpu = require("component").gpu
local event = require("event")
local uuid = require("uuid")
local class = require("libClass")

local libGUI = {widgets={}}
libGUI.widgets.Widget = require("libGUI/widget/Widget")
libGUI.widgets.Rectangle = require("libGUI/widget/Rectangle")
libGUI.widgets.Image = require("libGUI/widget/Image")
libGUI.Image = require("libGUI/Image")

return libGUI
