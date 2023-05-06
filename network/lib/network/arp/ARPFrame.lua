local ethernet = require("network.ethernet")
local Payload = require("network.abstract.Payload")
local class = require("libClass2")


---@class ARPFrame:Payload
---@field private _htype number
---@field private _ptype number
---@field private _oper arpOperation
---@field private _sha number|string
---@field private _spa number|string
---@field private _tha number|string
---@field private _tpa number|string
---@operator call:ARPFrame
---@overload fun(htype:number,ptype:number,oper:arpOperation,sha:number|string,spa:number|string,tha:number|string,tpa:number|string):ARPFrame
local ARPFrame       = class(Payload)
ARPFrame.payloadType = ethernet.TYPE.ARP
ARPFrame.OPERATION   = {
    REQUEST = 1,
    REPLY = 2
}


---@param htype number
---@param ptype number
---@param oper arpOperation
---@param sha number|string
---@param spa number|string
---@param tha number|string
---@param tpa number|string
---@return ARPFrame
function ARPFrame:new(htype, ptype, oper, sha, spa, tha, tpa)
    checkArg(1, htype, "number")
    checkArg(2, ptype, "number")
    checkArg(3, oper, "number")
    checkArg(4, sha, "string", "number")
    checkArg(5, spa, "string", "number")
    checkArg(6, tha, "string", "number")
    checkArg(7, tpa, "string", "number")

    local o = {
        _htype = htype,
        _ptype = ptype,
        _oper = oper,
        _sha = sha,
        _spa = spa,
        _tha = tha,
        _tpa = tpa,
    }

    setmetatable(o, {__index = self})

    return o
end

ARPFrame.payloadFormat = "I2I2xxI2sI4sI4"

---@return string
function ARPFrame:pack()
    return string.pack(self.payloadFormat, self:htype(), self:ptype(), self:oper(), self:sha(), self:spa(), self:tha(), self:tpa())
end

---@param arpString string
---@return ARPFrame
function ARPFrame.unpack(arpString)
    return ARPFrame(string.unpack(ARPFrame.payloadFormat, arpString))
end

--#region getter/setter

---@param value? number
---@return number
function ARPFrame:htype(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self._htype
    if (value ~= nil) then self._htype = value end
    return oldValue
end

---@param value? number
---@return number
function ARPFrame:ptype(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self._ptype
    if (value ~= nil) then self._ptype = value end
    return oldValue
end

---@param value? number
---@return number
function ARPFrame:oper(value)
    checkArg(1, value, 'number', 'nil')
    local oldValue = self._oper
    if (value ~= nil) then self._oper = value end
    return oldValue
end

---@param value? number|string
---@return number|string
function ARPFrame:sha(value)
    checkArg(1, value, 'number', 'string', 'nil')
    local oldValue = self._sha
    if (value ~= nil) then self._sha = value end
    return oldValue
end

---@param value? number|string
---@return number|string
function ARPFrame:spa(value)
    checkArg(1, value, 'number', 'string', 'nil')
    local oldValue = self._spa
    if (value ~= nil) then self._spa = value end
    return oldValue
end

---@param value? number|string
---@return number|string
function ARPFrame:tha(value)
    checkArg(1, value, 'number', 'string', 'nil')
    local oldValue = self._tha
    if (value ~= nil) then self._tha = value end
    return oldValue
end

---@param value? number|string
---@return number|string
function ARPFrame:tpa(value)
    checkArg(1, value, 'number', 'string', 'nil')
    local oldValue = self._tpa
    if (value ~= nil) then self._tpa = value end
    return oldValue
end

return ARPFrame
