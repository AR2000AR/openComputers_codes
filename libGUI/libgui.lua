local gpu = require("component").gpu
local event = require("event")
local uuid = require("uuid")
local class = require("libClass")

local libGUI = {widget={}}
libGUI.widget.Widget = require("libGUI/widget/Widget")
libGUI.widget.Rectangle = require("libGUI/widget/Rectangle")
libGUI.widget.Image = require("libGUI/widget/Image")
libGUI.widget.Text = require("libGUI/widget/Text")
libGUI.Screen = require("libGUI/Screen")
libGUI.Image = require("libGUI/Image")

return libGUI
