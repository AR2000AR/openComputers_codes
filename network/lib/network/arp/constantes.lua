local ethernet = require("network.ethernet")

---@class arpConstantes
local arpConstantes = {
    ---@enum arpOperation
    OPERATION      = {
        REQUEST = 1,
        REPLY = 2
    },
    ---@enum arpHardwareType
    HARDWARE_TYPE  = {
        ETHERNET = 1
    },
    ---@enum arpProtocoleType
    PROTOCOLE_TYPE = ethernet.TYPE
}

return arpConstantes
