local class = require('libClass2')

---@class NetworkLayer:Object
---@field protected _layer NetworkLayer lower layer
---@field protected _higherLayer table<number,NetworkLayer> highers layers
local NetworkLayer = class()
NetworkLayer.layerType = 0

---Comment
---@return NetworkLayer
function NetworkLayer:new()
    local o = self.parent()
    setmetatable(o, {__index = self})
    ---@cast o NetworkLayer
    o._higherLayer = {}
    return o
end

---Get the payload from the previous layer
---@param from string|number
---@param to string|number
---@param payload string
function NetworkLayer:payloadHandler(from, to, payload)
    error("Abstract methods", 2)
end

---Send the payload
---@param to string|number destination.
---@param payload Payload
---@overload fun(payload)
function NetworkLayer:send(to, payload)
    error("Abstract methods", 2)
end

---Return the maximum payload size
---@return number
function NetworkLayer:mtu()
    error("Abstract methods", 2)
end

---@return string|number
function NetworkLayer:addr()
    error("Abstract methods", 2)
end

---set or get the lower layer handler
---@protected
---@param value? NetworkLayer
---@return NetworkLayer
function NetworkLayer:layer(value)
    checkArg(1, value, 'table', 'nil')
    local oldValue = self._layer
    if (value ~= nil) then
        assert(value:instanceOf(NetworkLayer))
        value:higherLayer(self.layerType, self)
        self._layer = value
    end
    return oldValue
end

---@param layerType number
---@param value? NetworkLayer
---@return NetworkLayer
function NetworkLayer:higherLayer(layerType, value)
    checkArg(1, value, 'table', 'nil')
    local oldValue = self._higherLayer[layerType]
    if (value ~= nil) then self._higherLayer[layerType] = value end
    return oldValue
end

return NetworkLayer
