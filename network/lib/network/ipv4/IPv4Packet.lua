local bit32    = require("bit32")
local ethernet = require("network.ethernet")
local Payload  = require("network.abstract.Payload")
local utils    = require("network.utils")
local class    = require("libClass2")


---@class IPv4Header
---@field version number 4 : ip version
---@field ihl number 5 : internet header lengh
---@field dscp number Differentiated Services Code Point
---@field ecn number Explicit Congestion Notification
---@field len number Datagram lengh
---@field id number Identification
---@field flags number Flags bit 0: Reserved; must be zero. bit 1: Don't Fragment (DF) bit 2: More Fragments (MF)
---@field fragmentOffset number Fragment offset.
---@field ttl number Time to live
---@field protocol ipv4Protocol Protocol
---@field checksum number header checksum
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
            version = 4,
            ihl = 5,
            dscp = 0,
            ecn = 0,
            --totalLengh
            id = 0,
            flags = 0,
            fragmentOffset = 0,
            ttl = 64,
            protocol = 1,
            --checksum = 0,
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

---@return number
function IPv4Packet:version()
    return self._header.version
end

---@return number
function IPv4Packet:ihl()
    return self._header.ihl
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

---@return number
function IPv4Packet:len()
    return string.packsize(IPv4Packet.headerFormat) + #self:payload()
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
function IPv4Packet:checksum(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self._header.checksum or self:calculateChecksum()
    if (value ~= nil) then self._header.checksum = value end
    return oldValue
end

---@return number
function IPv4Packet:calculateChecksum()
    local versionAndIHL = bit32.lshift(self:version(), 4) + self:ihl()
    local dscpAndEcn = bit32.lshift(self:dscp(), 4) + self:ecn()
    local flagsAndFragOffset = bit32.lshift(self:flags(), 13) + self:fragmentOffset()
    local header = string.pack(self.headerFormat, versionAndIHL, dscpAndEcn, self:len(), self:id(), flagsAndFragOffset, self:ttl(), self:protocol(), 0, self:src(), self:dst())
    return utils.checksum(header)
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
    --TODO : currentPos may be != from 1
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
        framgentPacket:fragmentOffset(currentPos - 1)
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

IPv4Packet.headerFormat = ">BBHHHBBHII"
IPv4Packet.payloadFormat = IPv4Packet.headerFormat

function IPv4Packet:pack()
    local versionAndIHL = bit32.lshift(self:version(), 4) + self:ihl()
    local dscpAndEcn = bit32.lshift(self:dscp(), 4) + self:ecn()
    local flagsAndFragOffset = bit32.lshift(self:flags(), 13) + self:fragmentOffset()
    local header = string.pack(self.headerFormat, versionAndIHL, dscpAndEcn, self:len(), self:id(), flagsAndFragOffset, self:ttl(), self:protocol(), self:checksum(), self:src(), self:dst())
    return header .. string.pack('c' .. #self:payload(), self:payload())
end

---@param val string
---@return IPv4Packet
function IPv4Packet.unpack(val)
    checkArg(1, val, 'string')

    local versionAndIHL, dscpAndEcn, len, id, flagsAndFragmentOffset, ttl, protocol, checksum, src, dst, offset = string.unpack(IPv4Packet.payloadFormat, val)
    ---@cast versionAndIHL number
    local version = bit32.extract(versionAndIHL, 4, 4)
    local ihl = bit32.extract(versionAndIHL, 0, 4)
    ---@cast dscpAndEcn number
    local dscp = bit32.extract(dscpAndEcn, 2, 6)
    local ecn = bit32.extract(dscp, 0, 2)
    ---@cast flagsAndFragmentOffset number
    local flags = bit32.extract(flagsAndFragmentOffset, 14, 3)
    local fragmentOffset = bit32.extract(flagsAndFragmentOffset, 0, 13)
    ---@cast len number
    ---@cast id number
    ---@cast ttl number
    ---@cast protocol number
    ---@cast checksum number
    ---@cast src number
    ---@cast dst number
    ---@cast offset number

    local payload = string.unpack('c' .. len - (ihl * 4), val, offset)
    ---@cast payload string

    local packet = IPv4Packet(src, dst, payload, protocol)
    --packet:version(version)
    --packet:ihl(ihl)
    packet:dscp(dscp)
    packet:ecn(ecn)
    --packet:len(len)
    packet:id(id)
    packet:flags(flags)
    packet:fragmentOffset(fragmentOffset)
    packet:ttl(ttl)
    packet:protocol(protocol)
    packet:checksum(checksum)
    packet:src(src)
    packet:dst(dst)

    return packet
end

return IPv4Packet
