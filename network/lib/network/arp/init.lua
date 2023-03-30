local arpAPI = require("network.arp.api")
local arpConst = require("network.arp.constantes")

---@class libARP
local arp = {
    ARPFrame = require("network.arp.ARPFrame"),
    ARPLayer = require("network.arp.ARPLayer"),
    addCached = arpAPI.addCached,
    getAddress = arpAPI.getAddress,
    getLocalAddress = arpAPI.getLocalAddress,
    getLocalHardwareAddress = arpAPI.getLocalHardwareAddress,
    list = arpAPI.list,
    setLocalAddress = arpAPI.setLocalAddress,
    HARDWARE_TYPE = arpConst.HARDWARE_TYPE,
    OPERATION = arpConst.OPERATION,
    PROTOCOLE_TYPE = arpConst.PROTOCOLE_TYPE
}

return arp
