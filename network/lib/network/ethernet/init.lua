local computer               = require("computer")
local event                  = require("event")
local Payload                = require("network.abstract.Payload")
local NetworkLayer           = require('network.abstract.NetworkLayer')
local class                  = require("libClass2")

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
local EthernetFrame = class(Payload)

---Constructor
---@param self EthernetFrame
---@param src string
---@param dst string
---@param tag802_1Q number|nil
---@param etype ethernetType
---@param payload string
---@return EthernetFrame
function EthernetFrame:new(src, dst, tag802_1Q, etype, payload)
    checkArg(1, src, "string")
    checkArg(2, dst, "string")
    checkArg(3, tag802_1Q, "string", "nil")
    checkArg(4, etype, "number")
    checkArg(5, payload, "string")
    if (not checkUUIDformat(src)) then error("#1 : src. Not a valid uuid") end
    if (not checkUUIDformat(dst)) then error("#2 : dst. Not a valid uuid") end
    local o = self.parent()
    setmetatable(o, {__index = self})
    o:dst(dst)
    o:src(src)
    o:f802_1Q(tag802_1Q)
    o:etype(etype)
    o:payload(payload)
    return o
end

---@param value? string
---@return string
function EthernetFrame:dst(value)
    checkArg(1, value, 'string', 'nil')
    local oldValue = self._dst
    if (value ~= nil) then
        if (not checkUUIDformat(value)) then error(string.format("%s is not a vailid MAC address (uuid)", value, 2)) end
        self._dst = value
    end
    return oldValue
end

---@param value? string
---@return string
function EthernetFrame:src(value)
    checkArg(1, value, 'string', 'nil')
    local oldValue = self._src
    if (value ~= nil) then
        if (not checkUUIDformat(value)) then error(string.format("%s is not a vailid MAC address (uuid)", value, 2)) end
        self._src = value
    end
    return oldValue
end

---@param value? number
---@return number
function EthernetFrame:f802_1Q(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self._802_1Q or 0
    if (value ~= nil) then self._802_1Q = value end
    return oldValue
end

---@param value? ethernetType
---@return ethernetType
function EthernetFrame:etype(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self._etype
    if (value ~= nil) then self._etype = value end
    return oldValue
end

---@param value? string
---@return string
function EthernetFrame:payload(value)
    checkArg(1, value, 'string', 'nil')
    local oldValue = self._payload or ""
    if (value ~= nil) then self._payload = value end
    return oldValue
end

---Dump the frame info into multiples return values
---@return number|nil field802_1Q
---@return ethernetType ethernetType
---@return string payload
function EthernetFrame:pack()
    return self:f802_1Q(), self:etype(), self:payload()
end

function EthernetFrame.unpack(src, dst, tag802_1Q, etype, payload)
    return EthernetFrame(src, dst, tag802_1Q, etype, payload)
end

--#endregion
--=============================================================================
--#region EthernetInterface

---@class EthernetInterface : NetworkLayer
---@operator call:EthernetInterface
---@field private _modem ComponentModem
---@field private _port number
---@field private _layers table<ethernetType,table>
---@field private _listener number
---@field private _mtu number
---@overload fun(modem:ComponentModem):EthernetInterface
local EthernetInterface = class(NetworkLayer)


---Create a EthernetInterface
---@param modem ComponentModem
---@return EthernetInterface
function EthernetInterface:new(modem)
    checkArg(1, modem, "table")
    if (type(modem) == "table") then
        if (not modem.type == "modem") then error("#1 is not a modem component", 2) end
    end

    local o = self.parent()
    setmetatable(o, {__index = self})
    o._modem = modem
    o._mtu = computer.getDeviceInfo()[modem.address].capacity - 72
    o._modem.open(ethernet.RAW_PORT)
    o._listener = event.listen("modem_message", function(...) o:modemMessageHandler(...) end)

    return o
end

function EthernetInterface:close()
    self._modem.close(ethernet.RAW_PORT)
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
    if (localMac ~= self:addr()) then return end
    if (port ~= ethernet.RAW_PORT) then return false end
    local handler = self:higherLayer(etype)
    if (handler) then
        handler:payloadHandler(remoteMac, localMac, payload)
    else
        event.onError(string.format("[ethernet] Unknown etype : %x. Frame dropped", etype))
    end
end

---Get the maximum size a ethernet frame can have
---@return number mtu
function EthernetInterface:mtu() return self._mtu end

---Get the interface's mac address
---@return string uuid
function EthernetInterface:addr()
    return self._modem.address
end

---Send a ethernet frame
---@param dst string
---@param eFrame EthernetFrame
function EthernetInterface:send(dst, eFrame)
    checkArg(1, dst, "string", "nil")
    dst = dst or eFrame:dst()
    checkArg(2, eFrame, "table")
    if (dst == ethernet.MAC_BROADCAST) then
        self._modem.broadcast(ethernet.RAW_PORT, eFrame:pack())
    else
        self._modem.send(dst, ethernet.RAW_PORT, eFrame:pack())
    end
end

--#endregion
--=============================================================================

ethernet.EthernetFrame = EthernetFrame
ethernet.EthernetInterface = EthernetInterface
return ethernet
