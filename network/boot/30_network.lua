--build the network stack

local ifconfig = require("ifconfig")
local event    = require("event")

local function onComponentAdded(eName, address, cType)
    if (cType ~= "modem") then return end
    ifconfig.autoIfup(address)
end

local function onComponentRemoved(eName, address, cType)
    if (cType ~= "modem") then return end
    ifconfig.ifdown(address)
end

event.listen("component_added", onComponentAdded)
event.listen("component_removed", onComponentRemoved)
