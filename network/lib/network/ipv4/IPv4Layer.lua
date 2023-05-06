local ethernet     = require("network.ethernet")
local arp          = require("network.arp")
local ipv4Address  = require("network.ipv4.address")
local IPv4Packet   = require("network.ipv4.IPv4Packet")
local ipv4Consts   = require("network.ipv4.constantes")
local IPv4Router   = require('network.ipv4.IPv4Router')
local NetworkLayer = require('network.abstract.NetworkLayer')
local bit32        = require("bit32")
local class        = require("libClass2")


---@class IPv4Layer : NetworkLayer
---@field private _addr number
---@field private _mask number
---@field private _router IPv4Router
---@field package _layer NetworkLayer
---@field package _arp ARPLayer
---@field private _buffer table<number,table<number,table<number,IPv4Packet>>>
---@operator call:IPv4Layer
---@overload fun(dataLayer:NetworkLayer,router:IPv4Router,addr:number|string,mask:number|string):IPv4Layer
local IPv4Layer     = class(NetworkLayer)
IPv4Layer.layerType = ethernet.TYPE.IPv4


---@param dataLayer NetworkLayer
---@param router IPv4Router
---@param addr number|string
---@param mask number
---@return IPv4Layer
function IPv4Layer:new(dataLayer, router, addr, mask)
    checkArg(1, dataLayer, "table")
    checkArg(2, addr, "number", "string")
    checkArg(3, mask, "number", "string")
    local o = self.parent()
    setmetatable(o, {__index = self})
    ---@cast o IPv4Layer
    o._layer = dataLayer
    o._arp = nil
    o._buffer = {}

    o:layer(dataLayer)
    o:addr(addr)
    o:mask(mask)
    o:router(router)
    --arp
    o:arp(arp.ARPLayer(dataLayer))
    arp.setLocalAddress(arp.HARDWARE_TYPE.ETHERNET, arp.PROTOCOLE_TYPE.IPv4, dataLayer:addr(), o:addr())
    return o
end

---@param value? ARPLayer
---@return ARPLayer
function IPv4Layer:arp(value)
    checkArg(1, value, 'table', 'nil')
    local oldValue = self._arp
    if (value ~= nil) then
        assert(value:instanceOf(arp.ARPLayer))
        self._arp = value
    end
    return oldValue
end

---@param value? string|number
---@return number
function IPv4Layer:addr(value)
    checkArg(1, value, 'string', 'number', 'nil')
    local oldValue = self._addr
    if (value ~= nil) then
        if (type(value) == "number" and value > 0 and value < 0xffffffff) then
            self._addr = value
        else
            self._addr = ipv4Address.fromString(value)
        end
    end
    return oldValue
end

---@param value? number
---@return number
function IPv4Layer:mask(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self._mask
    if (value ~= nil) then
        if (not (value >= 0 and value <= 0xffffffff)) then error("Invalid mask", 2) end
        local found0 = false
        for i = 31, 0, -1 do
            if (not found0) then
                found0 = (0 == bit32.extract(value, i))
            else
                if (bit32.extract(value, i) == 1) then
                    error("Invalid mask", 2)
                end
            end
        end
        self._mask = value
    end
    return oldValue
end

function IPv4Layer:mtu() return self:layer():mtu() - 38 end

---@param value? IPv4Router
---@return IPv4Router
function IPv4Layer:router(value)
    checkArg(1, value, 'table', 'nil')
    local oldValue = self._router
    if (value ~= nil) then
        assert(value:instanceOf(IPv4Router))
        self._router = value
        self._router:higherLayer(self.layerType, self)
        self._router:addRoute({network = bit32.band(self:addr(), self:mask()), mask = self:mask(), gateway = self:addr(), metric = 0, interface = self})
    end
    return oldValue
end

---Send a IPv4Packet
---@param self IPv4Layer
---@param to number
---@param payload IPv4Packet
---@overload fun(self:IPv4Layer,payload:IPv4Packet)
function IPv4Layer:send(to, payload)
    if (not payload) then
        ---@diagnostic disable-next-line: cast-local-type
        payload = to
        to = payload:dst()
    end
    ---@cast payload IPv4Packet
    if (to == self:addr()) then --sent to self
        local l = self:layer() --[[@as EthernetInterface]]
        self:payloadHandler(l:addr() --[[@as string]], l:addr() --[[@as string]], payload:pack())
    else
        local dst = arp.getAddress(self._arp, arp.HARDWARE_TYPE.ETHERNET, self.layerType, to, self:addr())
        if (not dst) then error("Cannot resolve IP", 2) end
        for _, payloadFragment in pairs(payload:getFragments(self:mtu())) do
            local eFrame = ethernet.EthernetFrame(self:layer():addr(), dst, nil, self.layerType, payloadFragment:pack())
            self:layer():send(dst, eFrame)
        end
    end
end

---@param from string
---@param to string
---@param payload string
function IPv4Layer:payloadHandler(from, to, payload)
    checkArg(1, from, 'string')
    checkArg(2, to, 'string')
    checkArg(3, payload, 'string')
    local pl = IPv4Packet.unpack(payload)
    if (pl:dst() == self:addr()) then
        if (pl:len() > 1) then --merge framents
            local bufferID = string.format("%d%d%d%d", from, to, pl:protocol(), pl:id())
            self._buffer[bufferID] = self._buffer[bufferID] or {}

            --place the packet in a buffer
            table.insert(self._buffer[bufferID], math.max(#self._buffer[bufferID], pl:fragmentOffset()), pl)

            --if the buffer hold all the packets merge them
            if (#self._buffer[bufferID] == pl:len()) then
                local fullPayload, proto = {}, pl:protocol()
                for i, fragment in ipairs(self._buffer[pl:protocol()][pl:src()]) do
                    table.insert(fullPayload, math.max(#fullPayload, fragment:fragmentOffset()), fragment:payload())
                end
                pl = IPv4Packet(pl:src(), pl:dst(), table.concat(fullPayload), pl:protocol())
                pl:protocol(proto)
                self._buffer[pl:protocol()][pl:src()] = nil
            end
            --TODO : handle merge timeout
        end
        if (pl:len() == 1) then
            --if the packet is complete, send it to the router to be handed to the destination program
            self._router:payloadHandler(pl:src(), pl:dst(), pl:pack())
        end
    else
        --TODO : check if routing is enabled
        self._router:send(pl)
    end
end

return IPv4Layer
