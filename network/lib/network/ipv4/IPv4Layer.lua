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
---@field protected _layer NetworkLayer
---@field protected _arp ARPLayer
---@field protected _buffer table<number,table<number,table<number,IPv4Packet>>>
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

function IPv4Layer:mtu() return self:layer():mtu() - string.packsize(IPv4Packet.headerFormat) end

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
            ---@diagnostic disable-next-line: param-type-mismatch
            local eFrame = ethernet.EthernetFrame(self:layer():addr(), dst, nil, self.layerType, payloadFragment:pack())
            self:layer():send(dst, eFrame)
        end
    end
end

---@param from? string
---@param to? string
---@param payload string
function IPv4Layer:payloadHandler(from, to, payload)
    checkArg(1, from, 'string', 'nil')
    checkArg(2, to, 'string', 'nil')
    checkArg(3, payload, 'string')
    local pl = IPv4Packet.unpack(payload)
    if (pl:dst() == self:addr()) then
        if (bit32.btest(pl:flags(), ipv4Consts.FLAGS.MF --[[MF]]) or pl:fragmentOffset() > 0) then
            --fragmented packet
            local bufferID = string.pack('>IIH', pl:src(), pl:dst(), pl:id())
            --Store the fragments
            self._buffer[bufferID] = self._buffer[bufferID] or {}
            self._buffer[bufferID][pl:fragmentOffset()] = pl
            --Check if we have a full packet
            if (not bit32.btest(pl:flags(), ipv4Consts.FLAGS.MF)) then
                local newPayload = ''
                local reassembled = true
                for k, v in pairs(self._buffer[bufferID]) do
                    ---@cast v IPv4Packet
                    if (k ~= #newPayload) then
                        --missing a fragment
                        --TODO : send reassembly error
                        reassembled = false
                        break
                    end
                    newPayload = newPayload .. v:payload()
                end
                if (reassembled) then
                    pl:payload(newPayload)
                    pl:flags(bit32.band(pl:flags(), bit32.bnot(ipv4Consts.FLAGS.MF)))
                    pl:fragmentOffset(0)
                end
            end
        end
        if (not (bit32.btest(pl:flags(), ipv4Consts.FLAGS.MF --[[MF]])) and pl:fragmentOffset() == 0) then
            --if the packet is complete, send it to the router to be handed to the destination program
            self._router:payloadHandler(pl:src(), pl:dst(), pl:pack())
        end
    else
        --TODO : check if routing is enabled
        --TODO : may need extra fragmenting
        self._router:send(pl)
    end
end

return IPv4Layer
