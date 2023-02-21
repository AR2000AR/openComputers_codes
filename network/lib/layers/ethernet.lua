local computer               = require("computer")
local event                  = require("event")
local component              = require("component")

local UUID_PATERN            = "%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x"

---@class ethernetlib
---@field private internal table
local ethernet               = {}
ethernet.internal            = {}
---@type table<string, EthernetInterface>
ethernet.internal.interfaces = {}
ethernet.MAC_NIL             = "00000000-0000-0000-0000-000000000000"
ethernet.MAC_BROADCAST       = "ffffffff-ffff-ffff-ffff-ffffffffffff"
ethernet.RAW_PORT            = 51
---@enum ethernetType
ethernet.TYPE                = {
    IPv4 = 0x0800,
    ARP  = 0x8006,
    RARP = 0x8035,
    WOL  = 0x0842,
    IPv6 = 0x86DD,
    LLDP = 0x88CC
}

local function checkUUIDformat(str)
    if (str:match("^" .. UUID_PATERN .. "$")) then return true else return false end
end

--=============================================================================
--#region EthernetFrame

---@class EthernetFrame : Payload
---@field private _dst string
---@field private _src string
---@field private _802_1Q number?
---@field private _etype ethernetType
---@field private _payload string
---@operator call:EthernetFrame
---@overload fun(src: string,dst: string,tag802_1Q: number|nil,etype: ethernetType,payload: string):EthernetFrame
local EthernetFrame = {}

setmetatable(EthernetFrame, {
    ---Constructor
    ---@param self EthernetFrame
    ---@param src string
    ---@param dst string
    ---@param tag802_1Q number|nil
    ---@param etype ethernetType
    ---@param payload string
    ---@return EthernetFrame
    __call = function(self, src, dst, tag802_1Q, etype, payload)
        checkArg(1, src, "string")
        checkArg(2, dst, "string")
        checkArg(3, tag802_1Q, "string", "nil")
        checkArg(4, etype, "number")
        checkArg(5, payload, "string")
        if (not checkUUIDformat(src)) then error("#1 : src. Not a valid uuid") end
        if (not checkUUIDformat(dst)) then error("#2 : dst. Not a valid uuid") end
        local o = {
            _dst = dst,
            _src = src,
            _802_1Q = tag802_1Q or nil,
            _etype = etype,
            _payload = payload,
        }
        setmetatable(o, { __index = self })
        return o
    end,
})

---Get the destination mac
---@return string uuid
function EthernetFrame:getDst() return self._dst end

---Set the destination mac
---@param dst string uuid
function EthernetFrame:setDst(dst)
    checkArg(1, dst, "string")
    if (not checkUUIDformat(dst)) then error(string.format("%s is not a vailid MAC address (uuid)", dst, 2)) end
    self._dst = dst
end

---Get the source mac
---@return string uuid
function EthernetFrame:getSrc() return self._src end

---Set the souce mac
---@param src string uuid
function EthernetFrame:setSrc(src)
    if (not checkUUIDformat(src)) then error(string.format("%s is not a vailid MAC address (uuid)", src, 2)) end
    self._src = src
end

---Get the 802_1Q tag
---@return number|nil tag
function EthernetFrame:get802_1Q() return self._802_1Q end

---Set the 802_1Q tag
---@param tag number|nil
function EthernetFrame:set802_1Q(tag)
    self._802_1Q = tag
end

---Get the ethernet frame payload's type
---@return ethernetType
function EthernetFrame:getEthernetType() return self._etype end

---Set the ethernet frame payload's type
---@param type ethernetType
function EthernetFrame:setEthernetType(type)
    checkArg(1, type, "number")
    for k, v in pairs(ethernet.TYPE) do
        if (type == v) then
            self._etype = type
            return
        end
    end
    error(string.format("%x is not a valid ethernet type"))
end

function EthernetFrame:getPayload() return self._payload end

function EthernetFrame:setPayload(payload)
    self._payload = payload
end

---Dump the frame info into multiples return values
---@return number|nil field802_1Q
---@return ethernetType ethernetType
---@return string payload
function EthernetFrame:pack()
    return self:get802_1Q(), self:getEthernetType(), self:getPayload()
end

function EthernetFrame.unpack(src, dst, tag802_1Q, etype, payload)
    return EthernetFrame(src, dst, tag802_1Q, etype, payload)
end

--#endregion
--=============================================================================
--#region EthernetInterface

---@class EthernetInterface : OSIDataLayer
---@operator call:EthernetInterface
---@field private _modem ComponentModem
---@field private _port number
---@field private _layers table<ethernetType,table>
---@field private _listener number
---@overload fun(modem:ComponentModem):EthernetInterface
local EthernetInterface = {}


setmetatable(EthernetInterface, {
    ---Create a EthernetInterface
    ---@param modem ComponentModem
    ---@return EthernetInterface
    __call = function(self, modem)
        checkArg(1, modem, "table")
        if (type(modem) == "table") then
            if (not modem.type == "modem") then error("#1 is not a modem component", 2) end
        end

        local o = {
            _modem = modem,
            _port = ethernet.RAW_PORT,
            _layers = {},
            _listener = 0
        }

        o._modem.open(o._port)

        setmetatable(o, { __index = self })

        o._listener = event.listen("modem_message", function(...) o:modemMessageHandler(...) end)

        return o
    end
})

function EthernetInterface:close()
    self._modem.close(self._port)
    event.cancel(self._listener)
end

---Handle modem messages
---@param eName string
---@param localMac string
---@param remoteMac string
---@param port number
---@param distance number
---@param tag802_1Q number
---@param etype ethernetType
---@param payload string
function EthernetInterface:modemMessageHandler(eName, localMac, remoteMac, port, distance, tag802_1Q, etype, payload)
    if (localMac ~= self:getAddr()) then return end
    if (port ~= self._port) then return false end
    local handler = self:getLayer(etype)
    if (handler) then
        handler:payloadHandler(remoteMac, localMac, payload)
    else
        event.onError(string.format("[ethernet] Unknown etype : %x. Frame dropped", etype))
    end
end

---Get the maximum size a ethernet frame can have
---@return number mtu
function EthernetInterface:getMTU() return computer.getDeviceInfo()[self._modem.address].capacity - 2 end

---Get the interface's mac address
---@return string uuid
function EthernetInterface:getAddr()
    return self._modem.address
end

---Send a ethernet frame
---@param eFrame EthernetFrame
function EthernetInterface:send(dst, eFrame)
    checkArg(2, eFrame, "table")
    if (eFrame:getDst() == ethernet.MAC_BROADCAST) then
        self._modem.broadcast(self._port, eFrame:pack())
    else
        self._modem.send(eFrame:getDst(), self._port, eFrame:pack())
    end
end

---Get the registed layer handler object
---@param etype ethernetType
---@return OSINetworkLayer?
function EthernetInterface:getLayer(etype)
    if self._layers[etype] then
        return self._layers[etype]
    end
    return nil
end

---Set the layer handler object
---@param layerHandler OSINetworkLayer
function EthernetInterface:setLayer(layerHandler)
    checkArg(1, layerHandler, "table")
    if (not type(layerHandler.payloadHandler) == "function") then error("#1 : not a OSINetwork") end
    self._layers[layerHandler.layerType] = layerHandler
end

--#endregion
--=============================================================================

---Get the EthernetInterface from the modem component or mac/uuid
---@param mac? string|ComponentModem
---@return EthernetInterface
function ethernet.getInterface(mac)
    if (not mac) then mac = component.getPrimary("modem").address end
    checkArg(1, mac, "string", "table")
    if (type(mac) == "table") then
        if (mac.type and mac.type == "modem") then mac = mac.address end
    end
    ---@cast mac string
    if (not checkUUIDformat(mac)) then error("#1 : not a uuid/mac", 2) end
    if (ethernet.internal.interfaces[mac]) then return ethernet.internal.interfaces[mac] end
    local modem = component.proxy(mac)
    if (not modem or not modem.type == "modem") then error("#1 : no such modem component", 2) end
    ethernet.internal.interfaces[modem.address] = EthernetInterface(modem)
    return ethernet.internal.interfaces[modem.address]
end

ethernet.EthernetFrame = EthernetFrame
ethernet.EthernetInterface = EthernetInterface
return ethernet
