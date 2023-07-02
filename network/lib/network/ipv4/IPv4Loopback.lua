local ethernet     = require("network.ethernet")
local arp          = require("network.arp")
local ipv4Address  = require("network.ipv4.address")
local IPv4Packet   = require("network.ipv4.IPv4Packet")
local ipv4Consts   = require("network.ipv4.constantes")
local IPv4Router   = require('network.ipv4.IPv4Router')
local NetworkLayer = require('network.abstract.NetworkLayer')
local bit32        = require("bit32")
local class        = require("libClass2")
local IPv4Layer    = require("network.ipv4.IPv4Layer")


---@class IPv4Loopback : IPv4Layer
local IPv4Loopback = class(IPv4Layer)

---@param value? string|number
---@return number
function IPv4Loopback:addr(value)
    checkArg(1, value, 'string', 'number', 'nil')
    return 2130706433
end

---@param value? number
---@return number
function IPv4Loopback:mask(value)
    checkArg(1, value, 'number', 'nil')
    return 0xff000000
end

---@param value? IPv4Router
---@return IPv4Router
function IPv4Loopback:router(value)
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
---@param self IPv4Loopback
---@param to number
---@param payload IPv4Packet
---@overload fun(self:IPv4Loopback,payload:IPv4Packet)
function IPv4Loopback:send(to, payload)
    if (not payload) then
        ---@diagnostic disable-next-line: cast-local-type
        payload = to
        to = payload:dst()
    end
    ---@cast payload IPv4Packet
    if ((to & self:mask()) == (self:addr() & self:mask())) then --sent to self
        local l = self:layer() --[[@as EthernetInterface]]
        self:payloadHandler(l:addr() --[[@as string]], l:addr() --[[@as string]], payload:pack())
    end
end

---@param from? string
---@param to? string
---@param payload string
function IPv4Loopback:payloadHandler(from, to, payload)
    checkArg(1, from, 'string', 'nil')
    checkArg(2, to, 'string', 'nil')
    checkArg(3, payload, 'string')
    local pl = IPv4Packet.unpack(payload)
    if ((pl:dst() & self:mask()) == (self:addr() & self:mask())) then
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

return IPv4Loopback
