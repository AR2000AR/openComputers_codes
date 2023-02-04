--build the network stack

local network   = require("network")
local event     = require("event")
local component = require("component")

local function onComponentAdded(eName, address, cType)
    if (cType ~= "modem") then return end
    network.registerInterface(address)
end

local function onComponentRemoved(eName, address, cType)
    if (cType ~= "modem") then return end
    network.forgetInterface(address)
end

event.listen("component_added", onComponentAdded)
event.listen("component_removed", onComponentRemoved)
