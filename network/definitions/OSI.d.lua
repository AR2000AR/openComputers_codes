---@meta

--=============================================================================

---@class OSILayer
---@field layerType number
---@field protected _layer OSILayer
---@field protected _layers table<number,OSILayer>
local OSILayer = {}

---Get the payload from the previous layer
---@param from string|number
---@param to string|number
---@param payload string
function OSILayer:payloadHandler(from, to, payload)
end

---Send the payload
---@param to string|number destination.
---@param payload Payload
---@overload fun(payload)
function OSILayer:send(to, payload)
end

---Register higher level OSI layer
---@param OSILayer any
function OSILayer:setLayer(OSILayer)
end

---Return the maximum payload size
---@return number
function OSILayer:getMTU()
end

---@return string|number
function OSILayer:getAddr()
end

--=============================================================================

---@class OSIDataLayer : OSILayer

--=============================================================================

---@class OSINetworkLayer : OSILayer

--=============================================================================

---@class Payload
---@field payloadType number
local Payload = {}

---Prepare the payload for the next layer
---@return any ...
function Payload:pack()
end

---Get a payload object from the argument
---@param ... any
---@return Payload
function Payload.unpack(...)
end
