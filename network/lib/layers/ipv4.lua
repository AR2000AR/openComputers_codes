local bit32            = require("bit32")
local arp              = require("layers.arp")
local ethernet         = require("layers.ethernet")

---@class ipv4lib
local ipv4lib          = {}
---@enum ipv4Protocol
ipv4lib.PROTOCOLS      = {
    ICMP = 1, --  Internet Control Message Protocol
    TCP  = 6, --  Transmission Control Protocol
    UDP  = 17, -- User Datagram Protocol
    OSPF = 89, -- Open Shortest Path First
}
---@class IPv4Header
---@field dscp number Differentiated Services Code Point
---@field ecn number Explicit Congestion Notification
---@field len number Total Length. In this implementation, indicate the number of framgments
---@field id number Identification
---@field flags number Flags bit 0: Reserved; must be zero. bit 1: Don't Fragment (DF) bit 2: More Fragments (MF)
---@field fragmentOffset number Fragment offset. In this implementation, correspond to the framgments number/place
---@field ttl number Time to live
---@field protocol ipv4Protocol Protocol
---@field src number Source address
---@field dst number Destination address

--=============================================================================

---@class IPv4Payload : Payload
---@field protocol ipv4Protocol

--=============================================================================

--#region IPv4Packet

---@class IPv4Packet : Payload
---@field private _header IPv4Header
---@field private _payload string
---@operator call:IPv4Packet
local IPv4Packet       = {}
IPv4Packet.payloadType = ethernet.TYPE.IPv6


setmetatable(IPv4Packet, {
    ---@param src number
    ---@param dst number
    ---@param payload Payload|string
    ---@param protocole? ipv4Protocol
    ---@return IPv4Packet
    __call = function(self, src, dst, payload, protocole)
        checkArg(1, src, 'number')
        checkArg(2, dst, 'number')
        checkArg(3, payload, 'string', 'table')
        local o = {
            ---@type IPv4Header
            _header = {
                dscp = 0,
                ecn = 0,
                len = 1,
                id = 0,
                flags = 0,
                fragmentOffset = 0,
                ttl = 0,
                protocol = 1,
                src = 0,
                dst = 0,
            },
            _payload = ""
        }

        setmetatable(o, { __index = self })
        ---@cast o IPv4Packet
        o:setSrc(src)
        o:setDst(dst)
        if (type(payload) == "string") then
            checkArg(4, protocole, 'number')
            ---@cast protocole - nil
            o:setProtocol(protocole)
            o:setPayload(payload)
        else
            o:setProtocol(payload.payloadType)
            o:setPayload(payload:pack())
        end

        return o
    end
})

--#region getter/setter

---Get the packet's payload
---@return string
function IPv4Packet:getPayload()
    return self._payload
end

---Set the packet's payload
---@param val string
function IPv4Packet:setPayload(val)
    self._payload = val
end

---Get the header's dscp value
---@return number
function IPv4Packet:getDscp() return self._header.dscp end

---Set the header's dscp value
---@param val number
function IPv4Packet:setDscp(val)
    checkArg(1, val, "number")
    self._header.dscp = val
end

---Get the header's ecn value
---@return number
function IPv4Packet:getEcn() return self._header.ecn end

---Set the header's ecn value
---@param val number
function IPv4Packet:setEcn(val)
    checkArg(1, val, "number")
    self._header.ecn = val
end

---Get the header's len value
---@return number
function IPv4Packet:getLen() return self._header.len end

---Set the header's len value
---@protected
---@param val number
function IPv4Packet:setLen(val)
    checkArg(1, val, "number")
    self._header.len = val
end

---Get the header's id value
---@return number
function IPv4Packet:getId() return self._header.id end

---Set the header's id value
---@protected
---@param val number
function IPv4Packet:setId(val)
    checkArg(1, val, "number")
    self._header.id = val
end

---Get the header's flags value
---@return number
function IPv4Packet:getFlags() return self._header.flags end

---Set the header's flags value
---@param val number
function IPv4Packet:setFlags(val)
    checkArg(1, val, "number")
    self._header.flags = val
end

---Get the header's fragmentOffset value
---@return number
function IPv4Packet:getFragmentOffset() return self._header.fragmentOffset end

---Set the header's fragmentOffset value
---@protected
---@param val number
function IPv4Packet:setFragmentOffset(val)
    checkArg(1, val, "number")
    self._header.fragmentOffset = val
end

---Get the header's ttl value
---@return number
function IPv4Packet:getTtl() return self._header.ttl end

---Set the header's ttl value
---@param val number
function IPv4Packet:setTtl(val)
    checkArg(1, val, "number")
    self._header.ttl = val
end

---Get the header's protocol value
---@return ipv4Protocol
function IPv4Packet:getProtocol() return self._header.protocol end

---Set the header's protocol value
---@param val ipv4Protocol
function IPv4Packet:setProtocol(val)
    checkArg(1, val, "number")
    self._header.protocol = val
end

---Get the header's src value
---@return number
function IPv4Packet:getSrc() return self._header.src end

---Set the header's src value
---@param val number
function IPv4Packet:setSrc(val)
    checkArg(1, val, "number")
    self._header.src = val
end

---Get the header's dst value
---@return number
function IPv4Packet:getDst() return self._header.dst end

---Set the header's dst value
---@param val number
function IPv4Packet:setDst(val)
    checkArg(1, val, "number")
    self._header.dst = val
end

--#endregion

---Framgent the packet
---@param maxFragmentSize number
---@return table<IPv4Packet>
function IPv4Packet:getFragments(maxFragmentSize)
    --TODO : check if framgmentation is allowed
    local framgments = {}
    local framgmentID = 1;
    local framentTotal = math.ceil(#self:getPayload() / maxFragmentSize)
    local currentPos = 1
    maxFragmentSize = math.max(1, maxFragmentSize - 1)
    local currentFragment = self:getPayload():sub(currentPos, currentPos + maxFragmentSize)
    while currentFragment ~= "" do
        local framgentPacket = IPv4Packet(self:getSrc(), self:getDst(), currentFragment, self:getProtocol())
        table.insert(framgments, framgentPacket)
        framgentPacket:setId(self:getId())
        framgentPacket:setFragmentOffset(#framgments)
        framgentPacket:setLen(framentTotal)
        framgmentID = framgmentID + 1
        currentPos = currentPos + maxFragmentSize + 1
        currentFragment = self:getPayload():sub(currentPos, currentPos + maxFragmentSize)
    end
    return framgments
end

function IPv4Packet:pack()
    return string.format("%.2x%.2x%.4x%.4x%.2x%.4x%.2x%.2x%.8x%.8x%s",
                         self:getDscp(), self:getEcn(), self:getLen(), self:getId(), self:getFlags(),
                         self:getFragmentOffset(), self:getTtl(), self:getProtocol(),
                         self:getSrc(), self:getDst(), self:getPayload())
end

---@param val string
---@return IPv4Packet
function IPv4Packet.unpack(val)
    local o = "%x%x"
    local patern = string.format("(%s)(%s)(%s)(%s)(%s)(%s)(%s)(%s)(%s)(%s)(%s)",
                                 o, --dscp
                                 o, --ecn
                                 o:rep(2), --len
                                 o:rep(2), --id
                                 o, --flags
                                 o:rep(2), --fragmentOffset
                                 o, --ttl
                                 o, --protocol
                                 o:rep(4), --src
                                 o:rep(4), --dst
                                 ".*" --payload
    )
    local dscp, ecn, len, id, flags, fragmentOffset, ttl, protocol, src, dst, payload = val:match(patern)

    dscp = tonumber(dscp, 16)
    ecn = tonumber(ecn, 16)
    len = tonumber(len, 16)
    id = tonumber(id, 16)
    flags = tonumber(flags, 16)
    fragmentOffset = tonumber(fragmentOffset, 16)
    ttl = tonumber(ttl, 16)
    protocol = tonumber(protocol, 16)
    src = tonumber(src, 16)
    dst = tonumber(dst, 16)

    assert(type(dscp) == "number");
    assert(type(ecn) == "number");
    assert(type(len) == "number");
    assert(type(id) == "number");
    assert(type(flags) == "number");
    assert(type(fragmentOffset) == "number");
    assert(type(ttl) == "number");
    assert(type(protocol) == "number");
    assert(type(src) == "number");
    assert(type(dst) == "number")

    local packet = IPv4Packet(src, dst, payload, protocol)
    packet:setDscp(dscp)
    packet:setEcn(ecn)
    packet:setLen(len)
    packet:setId(id)
    packet:setFlags(flags)
    packet:setFragmentOffset(fragmentOffset)
    packet:setTtl(ttl)
    packet:setProtocol(protocol)
    packet:setSrc(src)
    packet:setDst(dst)

    return packet
end

--#endregion
--=============================================================================

--#region IPv4Layer

---@class IPv4Layer : OSINetworkLayer
---@field private _addr number
---@field private _mask number
---@field private _router IPv4Router
---@field package _layer OSIDataLayer
---@field package _layers table<ipv4Protocol,OSINetworkLayer>
---@field package _arp ARPLayer
---@operator call:IPv4Layer
local IPv4Layer = {}

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
            _layers = {},
            _arp = nil,
            _router = router,
        }
        setmetatable(o, { __index = self })
        o:setAddr(addr)
        o:setMask(mask)
        dataLayer:setLayer(o)
        --arp
        o._arp = arp.ARPLayer(dataLayer)
        arp.setLocalAddress(arp.HARDWARE_TYPE.ETHERNET, arp.PROTOCOLE_TYPE.IPv4, dataLayer:getAddr(), o:getAddr())
        --route
        o._router:setLayer(o)
        o._router:addRoute({ network = bit32.band(o:getAddr(), o:getMask()), mask = o:getMask(), gateway = o:getAddr(), metric = 0 })
        return o
    end,
})

---Set the interfaces's address
---@param val string|number
function IPv4Layer:setAddr(val)
    if (type(val) == "number" and val > 0 and val < 0xffffffff) then
        self._addr = val
    else
        self._addr = ipv4lib.address.fromString(val)
    end
end

---Get the local IPv4
---@return number
function IPv4Layer:getAddr() return self._addr end

---Set the interfaces's address mask
---@param val string|number
function IPv4Layer:setMask(val)
    --TODO : check valid mask
    if (type(val) == "number" and val > 0 and val < 0xffffffff) then
        self._mask = val
    else
        self._mask = ipv4lib.address.fromString(val)
    end
end

---Get the local mask
---@return number
function IPv4Layer:getMask() return self._mask end

function IPv4Layer:getMTU() return self._layer:getMTU() - 20 end

---@param layer OSINetworkLayer
function IPv4Layer:setLayer(layer)
    self._layers[layer.layerType] = layer
end

---Send a IPv4Packet
---@param to number
---@param payload IPv4Packet
---@overload fun(payload:IPv4Packet)
function IPv4Layer:send(to, payload)
    if (not payload) then
        ---@diagnostic disable-next-line: cast-local-type
        payload = to
        to = payload:getDst()
    end
    local dst = arp.getAddress(self._arp, arp.HARDWARE_TYPE.ETHERNET, self.layerType, payload:getDst(), self:getAddr())
    if (not dst) then error("Cannot resolve IP", 2) end
    for _, payloadFragment in pairs(payload:getFragments(self:getMTU())) do
        local eFrame = ethernet.EthernetFrame(self._layer:getAddr(), dst, nil, self.layerType, payloadFragment:pack())
        self._layer:send(dst, eFrame)
    end
end

function IPv4Layer:payloadHandler(from, to, payload)
    local pl = IPv4Packet.unpack(payload)
    if (pl:getDst()) == self:getAddr() then
        if (self._layers[pl:getProtocol()]) then
            self._layers[pl:getProtocol()]:payloadHandler(pl:getSrc(), pl:getDst(), pl:getPayload())
        end
    elseif (self._router) then
        --reduce ttl
        pl:setTtl(pl:getTtl() - 1)
        if (pl:getTtl() >= 1) then
            self._router:send(pl)
        else
            if (self._layers[ipv4lib.PROTOCOLS.ICMP]) then
                self._layers[ipv4lib.PROTOCOLS.ICMP] --[[@as ICMPLayer]]:sendTimeout(pl, 1)
            end
        end
    end
end

--#endregion
--=============================================================================

ipv4lib.address = {}

function ipv4lib.address.fromString(val)
    local a, b, c, d = val:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
    a = tonumber(a)
    b = tonumber(b)
    c = tonumber(c)
    d = tonumber(d)
    if (not (0 <= a and a <= 255)) then error("#1 Not a valid IPv4", 2) end
    if (not (0 <= b and b <= 255)) then error("#1 Not a valid IPv4", 2) end
    if (not (0 <= c and c <= 255)) then error("#1 Not a valid IPv4", 2) end
    if (not (0 <= d and d <= 255)) then error("#1 Not a valid IPv4", 2) end
    return bit32.lshift(a, 8 * 3) + bit32.lshift(b, 8 * 2) + bit32.lshift(c, 8 * 1) + d
end

function ipv4lib.address.tostring(val)
    local a = bit32.extract(val, 24, 8)
    local b = bit32.extract(val, 16, 8)
    local c = bit32.extract(val, 8, 8)
    local d = bit32.extract(val, 0, 8)
    return string.format("%d.%d.%d.%d", a, b, c, d)
end

---Get the address and mask from the CIDR notation
---@param cidr string
---@return number address, number mask
function ipv4lib.address.fromCIDR(cidr)
    local address, mask = cidr:match("^(%d+%.%d+%.%d+%.%d+)/(%d+)$")
    mask = tonumber(mask)
    assert(mask >= 0, "Invalid mask")
    assert(mask <= 32, "Invalid mask")
    return ipv4lib.address.fromString(address), bit32.lshift(2 ^ mask - 1, 32 - mask)
end

--=============================================================================

ipv4lib.IPv4Layer = IPv4Layer
ipv4lib.IPv4Packet = IPv4Packet
return ipv4lib
