local bit32    = require("bit32")
local ethernet = require("network.ethernet")
local Payload  = require("network.abstract.Payload")
local class    = require("libClass2")


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

---@class IPv4Packet : Payload
---@field private _header IPv4Header
---@field private _payload string
---@operator call:IPv4Packet
---@overload fun(src:number,dst:number,paylaod:Payload):IPv4Packet
---@overload fun(src:number,dst:number,paylaod:string,protocol:ipv4Protocol):IPv4Packet
local IPv4Packet       = class(Payload)
IPv4Packet.payloadType = ethernet.TYPE.IPv6

---@param src number
---@param dst number
---@param payload Payload|string
---@param protocole? ipv4Protocol
---@return IPv4Packet
function IPv4Packet:new(src, dst, payload, protocole)
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
            ttl = 64,
            protocol = 1,
            src = 0,
            dst = 0,
        },
        _payload = ""
    }

    setmetatable(o, {__index = self})
    ---@cast o IPv4Packet
    o:src(src)
    o:dst(dst)
    if (type(payload) == "string") then
        checkArg(4, protocole, 'number')
        ---@cast protocole - nil
        o:protocol(protocole)
        o:payload(payload)
    else
        o:protocol(payload.payloadType)
        o:payload(payload:pack())
    end

    return o
end

--#region getter/setter

---@param value? string
---@return string
function IPv4Packet:payload(value)
    checkArg(1, value, 'string', 'nil')
    local oldValue = self._payload
    if (value ~= nil) then self._payload = value end
    return oldValue
end

---@param value? number
---@return number
function IPv4Packet:dscp(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self._header.dscp
    if (value ~= nil) then self._header.dscp = value end
    return oldValue
end

---@param value? number
---@return number
function IPv4Packet:ecn(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self._header.ecn
    if (value ~= nil) then self._header.ecn = value end
    return oldValue
end

---@param value? number
---@return number
function IPv4Packet:len(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self._header.len
    if (value ~= nil) then self._header.len = value end
    return oldValue
end

---@param value? number
---@return number
function IPv4Packet:id(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self._header.id
    if (value ~= nil) then self._header.id = value end
    return oldValue
end

---@param value? number
---@return number
function IPv4Packet:flags(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self._header.flags
    if (value ~= nil) then self._header.flags = value end
    return oldValue
end

---@param value? number
---@return number
function IPv4Packet:fragmentOffset(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self._header.fragmentOffset
    if (value ~= nil) then self._header.fragmentOffset = value end
    return oldValue
end

---@param value? number
---@return number
function IPv4Packet:ttl(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self._header.ttl
    if (value ~= nil) then self._header.ttl = value end
    return oldValue
end

---@param value? number
---@return number
function IPv4Packet:protocol(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self._header.protocol
    if (value ~= nil) then self._header.protocol = value end
    return oldValue
end

---@param value? number
---@return number
function IPv4Packet:src(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self._header.src
    if (value ~= nil) then self._header.src = value end
    return oldValue
end

---@param value? number
---@return number
function IPv4Packet:dst(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self._header.dst
    if (value ~= nil) then self._header.dst = value end
    return oldValue
end

--#endregion

---Framgent the packet
---@param maxFragmentSize number
---@return table<IPv4Packet>
function IPv4Packet:getFragments(maxFragmentSize)
    local fragments = {}
    local fragmentID = 1;
    local fragmentTotal = math.ceil(#self:payload() / maxFragmentSize)
    local currentPos = 1
    if (fragmentTotal > 1) then
        if (bit32.btest(self:flags(), 2)) then
            error("Packet may not be fragmented", 2)
        end
    end
    maxFragmentSize = math.max(1, maxFragmentSize - 1)
    local currentFragment = self:payload():sub(currentPos, currentPos + maxFragmentSize)
    while currentFragment ~= "" do
        local framgentPacket = IPv4Packet(self:src(), self:dst(), currentFragment, self:protocol())
        table.insert(fragments, framgentPacket)
        framgentPacket:id(self:id())
        framgentPacket:fragmentOffset(#fragments)
        framgentPacket:len(fragmentTotal)
        fragmentID = fragmentID + 1
        currentPos = currentPos + maxFragmentSize + 1
        if (fragmentID < fragmentTotal) then
            --Set the MF (more fragment flag)
            framgentPacket:flags(bit32.bor(framgentPacket:flags(), 4))
        end
        currentFragment = self:payload():sub(currentPos, currentPos + maxFragmentSize)
    end
    return fragments
end

IPv4Packet.payloadFormat = "xI1I1I2I1I1I2I1I1xxI4I4s"

function IPv4Packet:pack()
    return string.pack(self.payloadFormat, self:dscp(), self:ecn(), self:len(), self:id(), self:flags(), self:fragmentOffset(), self:ttl(), self:protocol(), self:src(), self:dst(), self:payload())
end

---@param val string
---@return IPv4Packet
function IPv4Packet.unpack(val)
    checkArg(1, val, 'string')

    local dscp, ecn, len, id, flags, fragmentOffset, ttl, protocol, src, dst, payload = string.unpack(IPv4Packet.payloadFormat, val)
    ---@cast dscp number
    ---@cast ecn number
    ---@cast len number
    ---@cast id number
    ---@cast flags number
    ---@cast fragmentOffset number
    ---@cast ttl number
    ---@cast protocol number
    ---@cast src number
    ---@cast dst number
    ---@cast payload string

    local packet = IPv4Packet(src, dst, payload, protocol)
    packet:dscp(dscp)
    packet:ecn(ecn)
    packet:len(len)
    packet:id(id)
    packet:flags(flags)
    packet:fragmentOffset(fragmentOffset)
    packet:ttl(ttl)

    return packet
end

return IPv4Packet
