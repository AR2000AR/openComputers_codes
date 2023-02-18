---@class layersLib
local layers = {}
layers.ipv4 = require("layers.ipv4")
layers.arp = require("layers.arp")
layers.ethernet = require("layers.ethernet")
layers.icmp = require("layers.icmp")

return layers
