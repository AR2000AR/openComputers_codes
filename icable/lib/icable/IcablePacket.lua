local class        = require("libClass2")
local Payload      = require("network.abstract.Payload")
local icableConsts = require("icable.constantes")
local ipv4address  = require("network.ipv4.address")

---@class IcablePacket:Payload
---@field private _kind IcablePacketKind
---@operator call:IcablePacket
---@overload fun(kind:IcablePacketKind,paylaod:string):IcablePacket
local IcablePacket = require('libClass2')(Payload)

---Comment
---@return IcablePacket
function IcablePacket:new(kind, payload)
    local o = self.parent()
    setmetatable(o, {__index = self})
    ---@cast o IcablePacket
    o:kind(kind)
    o:payload(payload)
    return o
end

---@param value? IcablePacketKind
---@return IcablePacketKind
function IcablePacket:kind(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self._kind
    if (value ~= nil) then self._kind = value end
    return oldValue
end

---@return number
function IcablePacket:len()
    if (self:payload()) then
        return #self:payload()
    else
        return 0
    end
end

---@param value? string
---@return string
function IcablePacket:payload(value)
    checkArg(1, value, 'string', 'nil')
    local oldValue = self._payload
    if (value ~= nil) then self._payload = value end
    return oldValue
end

IcablePacket.payloadFormat = ">c4BHx"

function IcablePacket:pack()
    local header = string.pack(self.payloadFormat, "ICAB", self:kind(), self:len())
    if (self:len() > 0) then
        header = header .. string.pack('c' .. self:len(), self:payload())
    end
    return header
end

function IcablePacket.unpack(val)
    local magic, kind, len, offset = string.unpack(IcablePacket.payloadFormat, val)
    local payload
    ---@cast magic string
    ---@cast kind IcablePacketKind
    ---@cast len number
    ---@cast offset number
    if (magic ~= "ICAB") then error('Not a icable packet', 2) end
    if len > 0 then
        payload = string.unpack('c' .. len, val, offset)
    end
    return IcablePacket(kind, payload)
end

---@return number? lenght,string? reason
function IcablePacket.getLenFromHeaderData(val)
    local magic, len, offset = string.unpack('>c4xHx', val)
    if (magic ~= "ICAB") then return nil, 'Not a icable packet' end
    return len
end

---@return CLIENT_NETCONF_KIND|SERVER_NETCONF_KIND kind,number? ipv4,number? mask
function IcablePacket:getNetConf()
    if (not (self:kind() == icableConsts.KIND.CLIENT_NETCONF or self:kind() == icableConsts.KIND.SERVER_NETCONF)) then error('Not a netconf packet', 2) end
    local netconfKind = string.unpack('>B', self:payload())
    local ipv4, netmask
    if (self:kind() == icableConsts.KIND.CLIENT_NETCONF and netconfKind == icableConsts.CLIENT_NETCONF_KIND.MANUAL_IPv4) then
        ipv4, netmask = string.unpack('>xI4B', self:payload())
    elseif (self:kind() == icableConsts.KIND.SERVER_NETCONF and netconfKind == icableConsts.SERVER_NETCONF_KIND.IPv4) then
        ipv4, netmask = string.unpack('>xI4B', self:payload())
    end
    return netconfKind, ipv4, ipv4address.maskLenToMask(netmask)
end

return IcablePacket
