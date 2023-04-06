local bit32    = require("bit32")
local ethernet = require("network.ethernet")


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
---@overload fun(src:number,dst:number,paylaod:Payload):IPv4Packet
---@overload fun(src:number,dst:number,paylaod:string,protocol:ipv4Protocol):IPv4Packet
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
                ttl = 64,
                protocol = 1,
                src = 0,
                dst = 0,
            },
            _payload = ""
        }

        setmetatable(o, {__index = self})
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
    local fragments = {}
    local fragmentID = 1;
    local fragmentTotal = math.ceil(#self:getPayload() / maxFragmentSize)
    local currentPos = 1
    if (fragmentTotal > 1) then
        if (bit32.btest(self:getFlags(), 2)) then
            error("Packet may not be fragmented", 2)
        end
    end
    maxFragmentSize = math.max(1, maxFragmentSize - 1)
    local currentFragment = self:getPayload():sub(currentPos, currentPos + maxFragmentSize)
    while currentFragment ~= "" do
        local framgentPacket = IPv4Packet(self:getSrc(), self:getDst(), currentFragment, self:getProtocol())
        table.insert(fragments, framgentPacket)
        framgentPacket:setId(self:getId())
        framgentPacket:setFragmentOffset(#fragments)
        framgentPacket:setLen(fragmentTotal)
        fragmentID = fragmentID + 1
        currentPos = currentPos + maxFragmentSize + 1
        if (fragmentID < fragmentTotal) then
            --Set the MF (more fragment flag)
            framgentPacket:setFlags(bit32.bor(framgentPacket:getFlags(), 4))
        end
        currentFragment = self:getPayload():sub(currentPos, currentPos + maxFragmentSize)
    end
    return fragments
end

local PACK_FORMAT = "xI1I1I2I1I1I2I1I1xxI4I4s"

function IPv4Packet:pack()
    return string.pack(PACK_FORMAT, self:getDscp(), self:getEcn(), self:getLen(), self:getId(), self:getFlags(), self:getFragmentOffset(), self:getTtl(), self:getProtocol(), self:getSrc(), self:getDst(), self:getPayload())
end

---@param val string
---@return IPv4Packet
function IPv4Packet.unpack(val)
    checkArg(1, val, 'string')

    local dscp, ecn, len, id, flags, fragmentOffset, ttl, protocol, src, dst, payload = string.unpack(PACK_FORMAT, val)
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

return IPv4Packet
