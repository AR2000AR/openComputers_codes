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

return Payload
