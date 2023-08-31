local class = require("libClass2")
local Payload = require("network.abstract.Payload")
local ipv4Consts = require("network.ipv4.constantes")
local utils = require("network.utils")

---@class TCPSegment:Payload
---@operator call:TCPSegment
---@field private _src number
---@field private _dst number
---@field private _seq number
---@field private _ack number
---@field private _offset number
---@field private _flags number
---@field private _windowSize number
---@field private _checksum number
---@field private _urgentPtr number
---@field private _options string
---@field private _payload string
---@overload fun(srcPort:number,dstPort:number,payload:string):TCPSegment
local TCPSegment = class(Payload)

TCPSegment.payloadType = ipv4Consts.PROTOCOLS.TCP

---Comment
---@param srcPort number
---@param dstPort number
---@param payload string
---@return TCPSegment
function TCPSegment:new(srcPort, dstPort, payload)
    checkArg(1, srcPort, "number")
    checkArg(2, dstPort, "number")
    checkArg(3, payload, "string")
    local o = self.parent()
    setmetatable(o, {__index = self})
    ---@cast o TCPSegment
    o:dstPort(dstPort)
    o:srcPort(srcPort)
    o:payload(payload)

    return o
end

---@param value? number
---@return number
function TCPSegment:srcPort(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self._scr or 0
    if (value ~= nil) then self._scr = value end
    return oldValue
end

---@param value? number
---@return number
function TCPSegment:dstPort(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self._dst or 0
    if (value ~= nil) then self._dst = value end
    return oldValue
end

---@param value? number
---@return number
function TCPSegment:seq(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self._seq or 0
    if (value ~= nil) then
        assert(value >= 0 and value <= 0xffffffff)
        self._seq = value
    end
    return oldValue
end

---@param value? number
---@return number
function TCPSegment:ack(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self._ack or 0
    if (value ~= nil) then
        assert(value >= 0 and value <= 0xffffffff)
        self._ack = value
    end
    return oldValue
end

---@return number
function TCPSegment:offset()
    return 5 + math.ceil(#self:options() / 4)
end

---@param value? number
---@return number
function TCPSegment:flags(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self._flags or 0
    if (value ~= nil) then self._flags = value end
    return oldValue
end

---@enum TCPFlags
TCPSegment.Flags = {
    CWR = 1 << 7,
    ECE = 1 << 6,
    URG = 1 << 5,
    ACK = 1 << 4,
    PSH = 1 << 3,
    RST = 1 << 2,
    SYN = 1 << 1,
    FIN = 1 << 0
}

---@param flag TCPFlags
---@param value? boolean
---@return boolean
function TCPSegment:flag(flag, value)
    checkArg(1, flag, "number")
    checkArg(2, value, "boolean", "nil")
    local oldFlag = self:flags()
    local oldValue = (oldFlag & flag) == flag
    if (value ~= nil) then
        if (value) then
            self:flags(oldFlag | flag)
        else
            self:flags(oldFlag & (~flag & 0xff))
        end
    end
    return oldValue
end

---@param value? number
---@return number
function TCPSegment:windowSize(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self._windowSize or 8000
    if (value ~= nil) then self._windowSize = value end
    return oldValue
end

--TODO checksum calc
---@param value? number
---@return number
function TCPSegment:checksum(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self._checksum or 0
    if (value ~= nil) then self._checksum = value end
    return oldValue
end

function TCPSegment:calculateChecksum(src, dst)
    local packed = self:pack(true)
    packed = string.pack('>IIxBH', src, dst, 6, #packed) .. packed
    return utils.checksum(packed)
end

---@param value? number
---@return number
function TCPSegment:urgentPtr(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self._urgentPtr or 0
    if (value ~= nil) then self._urgentPtr = value end
    return oldValue
end

---@param value? string
---@return string
function TCPSegment:options(value)
    checkArg(1, value, 'string', 'nil')
    local oldValue = self._option or ""
    if (value ~= nil) then self._option = value end
    return oldValue
end

---@param value? string
---@return string
function TCPSegment:payload(value)
    checkArg(1, value, 'string', 'nil')
    local oldValue = self._payload or ""
    if (value ~= nil) then self._payload = value end
    return oldValue
end

function TCPSegment:len()
    local len = #(self:payload())
    len = len + (self:flag(TCPSegment.Flags.FIN) and 1 or 0)
    len = len + (self:flag(TCPSegment.Flags.SYN) and 1 or 0)
    return len
end

TCPSegment.payloadFormat = ">HHIIBBHHH"

---@param skipCheksum? boolean
---@return string
function TCPSegment:pack(skipCheksum)
    local chk = self:checksum()
    if (skipCheksum) then chk = 0 end
    local offsetAndReserved = self:offset() << 4
    local header = string.pack(TCPSegment.payloadFormat,
                               self:srcPort(), self:dstPort(),
                               self:seq(), self:ack(),
                               offsetAndReserved, self:flags(),
                               self:windowSize(), chk,
                               self:urgentPtr())
    header = header .. string.pack(">c" .. #(self:options()), self:options())
    header = header .. string.pack(">c" .. #(self:payload()), self:payload())
    return header
end

function TCPSegment.unpack(data)
    local src, dst, seq, ack, offsetAndReserved, flags, windowSize, checksum, urgentPtr, offset = string.unpack(TCPSegment.payloadFormat, data)
    ---@cast src number
    ---@cast dst number
    ---@cast seq number
    ---@cast ack number
    ---@cast offsetAndReserved number
    ---@cast flags number
    ---@cast windowSize number
    ---@cast checksum number
    ---@cast urgentPtr number
    ---@cast offset number
    local dataOffset = offsetAndReserved >> 4
    local options = ""
    if (dataOffset > 5) then
        options, offset = string.unpack("c" .. (dataOffset - 5) * 4, data, offset)
    end
    local payload = string.sub(data, offset)
    local seg = TCPSegment(src, dst, payload)
    seg:seq(seq)
    seg:ack(ack)
    seg:flags(flags)
    seg:windowSize(windowSize)
    seg:checksum(checksum)
    seg:urgentPtr(urgentPtr)
    seg:options(options)
    return seg
end

return TCPSegment
