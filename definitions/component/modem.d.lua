---@meta

---@alias ModemSafeType string | number | number | boolean
---@class ComponentModem : Component
local modem = {}

---@return boolean
function modem.isWireless()
end

---@deprecated
---@return number
function modem.maxPacketSize()
end

---@param port number
---@return boolean
function modem.isOpen(port)
end

---@param port number
function modem.open(port)
end

---@param port number?
---@return boolean
function modem.close(port)
end

---@param address string
---@param port number
---@varargs ModemSafeType
function modem.send(address, port, ...)
end

---@param port number
---@varargs ModemSafeType
function modem.broadcast(port, ...)
end

---@return number
function modem.getStrength()
end

---@param message string
---@param fuzzy boolean?
function modem.setWakeMessage(message, fuzzy)
end
