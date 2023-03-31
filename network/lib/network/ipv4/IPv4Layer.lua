local ethernet    = require("network.ethernet")
local arp         = require("network.arp")
local ipv4Address = require("network.ipv4.address")
local IPv4Packet  = require("network.ipv4.IPv4Packet")
local ipv4Consts  = require("network.ipv4.constantes")
local bit32       = require("bit32")


---@class IPv4Layer : OSINetworkLayer
---@field private _addr number
---@field private _mask number
---@field private _router IPv4Router
---@field package _layer OSIDataLayer
---@field package _arp ARPLayer
---@field private _buffer table<number,table<number,table<number,IPv4Packet>>>
---@operator call:IPv4Layer
---@overload fun(dataLayer:OSIDataLayer,router:IPv4Router,addr:number|string,mask:number|string):IPv4Layer
local IPv4Layer     = {}
IPv4Layer.layerType = ethernet.TYPE.IPv4


setmetatable(IPv4Layer, {
    ---@param dataLayer OSIDataLayer
    ---@param router IPv4Router
    ---@param addr number|string
    ---@param mask number|string
    ---@return IPv4Layer
    __call = function(self, dataLayer, router, addr, mask)
        checkArg(1, dataLayer, "table")
        checkArg(2, addr, "number", "string")
        checkArg(3, mask, "number", "string")
        local o = {
            _addr = 0,
            _mask = 0,
            _layer = dataLayer,
            _arp = nil,
            _router = nil,
            _buffer = {}
        }
        setmetatable(o, {__index = self})
        o:setAddr(addr)
        o:setMask(mask)
        dataLayer:setLayer(o)
        o:setRouter(router)
        --arp
        o._arp = arp.ARPLayer(dataLayer)
        arp.setLocalAddress(arp.HARDWARE_TYPE.ETHERNET, arp.PROTOCOLE_TYPE.IPv4, dataLayer:getAddr(), o:getAddr())
        return o
    end,
})

---Set the interfaces's address
---@param val string|number
function IPv4Layer:setAddr(val)
    if (type(val) == "number" and val > 0 and val < 0xffffffff) then
        self._addr = val
    else
        self._addr = ipv4Address.fromString(val)
    end
end

---Get the local IPv4
---@return number
function IPv4Layer:getAddr() return self._addr end

---Set the interfaces's address mask
---@param val number
function IPv4Layer:setMask(val)
    checkArg(1, val, "number")
    local found0 = false
    for i = 31, 0, -1 do
        if (not found0) then
            found0 = 0 == bit32.extract(val, i)
        else
            if (bit32.extract(val, i) == 1) then
                error("Invalid mask", 2)
            end
        end
    end
    if (type(val) == "number" and val > 0 and val < 0xffffffff) then
        self._mask = val
    else
        self._mask = ipv4Address.fromString(val)
    end
end

---Get the local mask
---@return number
function IPv4Layer:getMask() return self._mask end

function IPv4Layer:getMTU() return self._layer:getMTU() - 38 end

---@param layer OSILayer
function IPv4Layer:setLayer(layer)
    self._router:setProtocol(layer)
end

---Set the layer's router. Used for rerouting packets
---@param router IPv4Router
function IPv4Layer:setRouter(router)
    self._router = router
    self._router:setLayer(self)
    self._router:addRoute({network = bit32.band(self:getAddr(), self:getMask()), mask = self:getMask(), gateway = self:getAddr(), metric = 0, interface = self})
end

---Get the router.
---@return IPv4Router
function IPv4Layer:getRouter()
    return self._router
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
        to = payload:getDst()
    end
    ---@cast payload IPv4Packet
    if (to == self:getAddr()) then --sent to self
        local l = self._layer --[[@as EthernetInterface]]
        self:payloadHandler(l:getAddr(), l:getAddr(), payload:pack())
    else
        local dst = arp.getAddress(self._arp, arp.HARDWARE_TYPE.ETHERNET, self.layerType, to, self:getAddr())
        if (not dst) then error("Cannot resolve IP", 2) end
        for _, payloadFragment in pairs(payload:getFragments(self:getMTU())) do
            local eFrame = ethernet.EthernetFrame(self._layer:getAddr(), dst, nil, self.layerType, payloadFragment:pack())
            self._layer:send(dst, eFrame)
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
    if (pl:getDst() == self:getAddr()) then
        if (pl:getLen() > 1) then --merge framents
            local bufferID = string.format("%d%d%d%d", from, to, pl:getProtocol(), pl:getId())
            self._buffer[bufferID] = self._buffer[bufferID] or {}

            --place the packet in a buffer
            table.insert(self._buffer[bufferID], math.max(#self._buffer[bufferID], pl:getFragmentOffset()), pl)

            --if the buffer hold all the packets merge them
            if (#self._buffer[bufferID] == pl:getLen()) then
                local fullPayload, proto = {}, pl:getProtocol()
                for i, fragment in ipairs(self._buffer[pl:getProtocol()][pl:getSrc()]) do
                    table.insert(fullPayload, math.max(#fullPayload, fragment:getFragmentOffset()), fragment:getPayload())
                end
                pl = IPv4Packet(pl:getSrc(), pl:getDst(), table.concat(fullPayload), pl:getProtocol())
                pl:setProtocol(proto)
                self._buffer[pl:getProtocol()][pl:getSrc()] = nil
            end
            --TODO : handle merge timeout
        end
        if (pl:getLen() == 1) then
            --if the packet is complete, send it to the router to be handed to the destination program
            self._router:payloadHandler(pl:getSrc(), pl:getDst(), pl:pack())
        end
    else
        --TODO : check if routing is enabled
        self._router:send(pl)
    end
end

return IPv4Layer
