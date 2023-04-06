---@class UDPDatagram : Payload
---@field private _srcPort number
---@field private _dstPort number
---@field private _payload string
---@operator call:UDPDatagram
---@overload fun(srcPort:number,dstPort:number,payload:string):UDPDatagram
local UDPDatagram = {}
UDPDatagram.payloadType = require("network.ipv4").PROTOCOLS.UDP

---@return UDPDatagram
setmetatable(UDPDatagram, {
    ---@param self UDPDatagram
    ---@param srcPort number
    ---@param dstPort number
    ---@param payload string
    ---@return table
    __call = function(self, srcPort, dstPort, payload)
        checkArg(1, srcPort, "number")
        checkArg(2, dstPort, "number")
        checkArg(3, payload, "string")
        local o = {
            _scrPort = 0,
            _dstPort = 0,
            _payload = ""
        }
        setmetatable(o, {__index = self})

        o:setDstPort(dstPort)
        o:setSrcPort(srcPort)
        o:setPayload(payload)

        return o
    end
})

function UDPDatagram:getDstPort() return self._dstPort end

function UDPDatagram:getSrcPort() return self._srcPort end

function UDPDatagram:getPayload() return self._payload end

function UDPDatagram:setDstPort(port)
    checkArg(1, port, "number")
    assert(port >= 0 and port <= 2 ^ 16 - 1, "Port outside valid range")
    self._dstPort = port
end

function UDPDatagram:setSrcPort(port)
    checkArg(1, port, "number")
    assert(port >= 0 and port <= 2 ^ 16 - 1, "Port outside valid range")
    self._srcPort = port
end

function UDPDatagram:setPayload(value)
    checkArg(1, value, "string")
    self._payload = value
end

local PACK_FORMAT = "I2I2xxxxs"

---Prepare the packet for the next layer
---@return string
function UDPDatagram:pack()
    return string.pack(PACK_FORMAT, self:getSrcPort(), self:getDstPort(), self:getPayload())
end

---Get a udp packet from the string
---@param value string
---@return UDPDatagram
function UDPDatagram.unpack(value)
    return UDPDatagram(string.unpack(PACK_FORMAT, value))
end

return UDPDatagram
