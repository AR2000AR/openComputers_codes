local class = require("libClass2")

---@class Payload:Object
---@field payloadType number
---@field protected payloadFormat string
local Payload = class()
Payload.payloadFormat = "s"
Payload.payloadType = 0

---Prepare the payload for the next layer
---@return any ...
function Payload:pack()
    error("Abstract methods", 2)
end

---Get a payload object from the argument
---@param ... any
---@return Payload
function Payload.unpack(...)
    error("Abstract methods", 2)
end

--[[ ---@param value? string
---@return string
function Payload:data(value)
    checkArg(1, value, 'string', 'nil')
    local oldValue = self._data
    if (value ~= nil) then self._data = value end
    return oldValue
end ]]
return Payload
