local ethernet = require("network.ethernet")


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
local ARPFrame       = {}
ARPFrame.payloadType = ethernet.TYPE.ARP
ARPFrame.OPERATION   = {
    REQUEST = 1,
    REPLY = 2
}


setmetatable(ARPFrame, {
    ---@param htype number
    ---@param ptype number
    ---@param oper arpOperation
    ---@param sha number|string
    ---@param spa number|string
    ---@param tha number|string
    ---@param tpa number|string
    ---@return ARPFrame
    __call = function(self, htype, ptype, oper, sha, spa, tha, tpa)
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
})

local PACK_FORMAT = "I2I2xxI2sI4sI4"

---@return string
function ARPFrame:pack()
    return string.pack(PACK_FORMAT, self:getHtype(), self:getPtype(), self:getOper(), self:getSha(), self:getSpa(), self:getTha(), self:getTpa())
end

---@param arpString string
---@return ARPFrame
function ARPFrame.unpack(arpString)
    return ARPFrame(string.unpack(PACK_FORMAT, arpString))
end

--#region getter/setter

---Get htype
---@return number
function ARPFrame:getHtype() return self._htype end

---@param val number
function ARPFrame:setHtype(val)
    checkArg(1, val, "number")
    self._htype = val
end

---Get ptype
---@return number
function ARPFrame:getPtype() return self._ptype end

---@param val number
function ARPFrame:setPtype(val)
    checkArg(1, val, "number")
    self._ptype = val
end

---Get oper
---@return number
function ARPFrame:getOper() return self._oper end

---@param val number
function ARPFrame:setOper(val)
    checkArg(1, val, "number")
    self._oper = val
end

---Get sha
---@return number|string
function ARPFrame:getSha() return self._sha end

---@param val number|string
function ARPFrame:setSha(val)
    checkArg(1, val, 'string', 'number')
    self._sha = val
end

---Get spa
---@return number|string
function ARPFrame:getSpa() return self._spa end

---@param val number|string
function ARPFrame:setSpa(val)
    checkArg(1, val, 'string', 'number')
    self._spa = val
end

---Get tha
---@return number|string
function ARPFrame:getTha() return self._tha end

---@param val number|string
function ARPFrame:setTha(val)
    checkArg(1, val, 'string', 'number')
    self._tha = val
end

---Get tpa
---@return number|string
function ARPFrame:getTpa() return self._tpa end

---@param val number|string
function ARPFrame:setTpa(val)
    checkArg(1, val, 'string', 'number')
    self._tpa = val
end

return ARPFrame
