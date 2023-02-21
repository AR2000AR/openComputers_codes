local ethernet            = require("layers.ethernet")
local event               = require("event")

---@class arplib
---@field private internal table
local arp                 = {}
arp.internal              = {}
arp.internal.cache        = {}
arp.internal.localAddress = {}

---@enum arpOperation
arp.OPERATION             = {
    REQUEST = 1,
    REPLY = 2
}
---@enum arpHardwareType
arp.HARDWARE_TYPE         = {
    ETHERNET = 1
}
---@enum arpProtocoleType
arp.PROTOCOLE_TYPE        = ethernet.TYPE

---============================================================================
--#region ARPFrame

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
local ARPFrame            = {}
ARPFrame.payloadType      = ethernet.TYPE.ARP
ARPFrame.OPERATION        = {
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

        setmetatable(o, { __index = self })

        return o
    end
})

---@return string
function ARPFrame:pack()
    return string.format("0x%x\0000x%x\0000x%x\0000%s\0%s\0%s\0%s", self:getHtype(), self:getPtype(), self:getOper(), self:getSha(), self:getSpa(), self:getTha(), self:getTpa())
end

---@param arpString string
---@return ARPFrame
function ARPFrame.unpack(arpString)
    local htype, ptype, oper, sha, spa, tha, tpa = arpString:match("^([^\0]+)\0([^\0]+)\0([^\0]+)\0([^\0]+)\0([^\0]+)\0([^\0]+)\0([^\0]+)$")
    htype = tonumber(htype)
    ptype = tonumber(ptype)
    oper = tonumber(oper)
    if (tonumber(sha)) then sha = tonumber(sha) end
    if (tonumber(spa)) then spa = tonumber(spa) end
    if (tonumber(tha)) then tha = tonumber(tha) end
    if (tonumber(tpa)) then tpa = tonumber(tpa) end
    return ARPFrame(htype, ptype, oper, sha, spa, tha, tpa)
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

--#endregion
--#endregion
--=============================================================================
--#region ARPLayer

---@class ARPLayer : OSINetworkLayer
local ARPLayer = {}
---@type ethernetType
ARPLayer.layerType = ethernet.TYPE.ARP

setmetatable(ARPLayer, {
    ---@param osiLayer OSIDataLayer
    ---@return ARPLayer
    __call = function(self, osiLayer)
        local o = {
            _layer = osiLayer
        }
        setmetatable(o, { __index = self })
        osiLayer:setLayer(o)
        return o
    end
})

function ARPLayer:getAddr()
    return self._layer:getAddr()
end

function ARPLayer:getMTU()
    return 0
end

---Handle the payload from the layer under
---@param from string
---@param to string
---@param payload string
function ARPLayer:payloadHandler(from, to, payload)
    local arpFrame = ARPFrame.unpack(payload)
    if (arpFrame:getOper() == arp.OPERATION.REQUEST) then
        local protocolAddress = arp.getLocalAddress(arpFrame:getHtype(), arpFrame:getPtype(), self._layer:getAddr())
        if (protocolAddress == arpFrame:getTpa()) then
            self:send(from, ARPFrame(arpFrame:getHtype(), arpFrame:getPtype(), ARPFrame.OPERATION.REPLY, arpFrame:getSha(), arpFrame:getSpa(), to, arpFrame:getTpa()))
        end
    elseif (arpFrame:getOper() == arp.OPERATION.REPLY) then
        arp.addCached(arpFrame:getHtype(), arpFrame:getPtype(), arpFrame:getTha(), arpFrame:getTpa())
    end
end

---Send the arp frame
---@param payload ARPFrame
function ARPLayer:send(dst, payload)
    if (dst == ethernet.MAC_NIL) then dst = ethernet.MAC_BROADCAST end
    local eFrame = ethernet.EthernetFrame(self._layer:getAddr(), dst, nil, self.layerType, payload:pack())
    self._layer:send(dst, eFrame)
end

--#endregion
--=============================================================================

---Add the address to the cache
---@param htype number
---@param ptype number
---@param ha any
---@param pa any
function arp.addCached(htype, ptype, ha, pa)
    local cache = arp.internal.cache --alias
    if (not cache[ptype]) then cache[ptype] = {} end
    if (not cache[ptype][pa]) then cache[ptype][pa] = {} end
    cache[ptype][pa][htype] = ha
    --push a signal to let other know a new address got cached
    event.push("arp", htype, ptype, ha, pa)
end

---Register the local address to answer ARP request
---@param htype number
---@param ptype number
---@param ha any
---@param pa any
function arp.setLocalAddress(htype, ptype, ha, pa)
    local localAddress = arp.internal.localAddress --alias
    if (not localAddress[htype]) then localAddress[htype] = {} end
    if (not localAddress[htype][ha]) then localAddress[htype][ha] = {} end
    localAddress[htype][ha][ptype] = pa
end

---Resolve local harware address into protocol address
---@param htype number
---@param ptype number
---@param ha any Requested hardware address
---@return string|number?
function arp.getLocalAddress(htype, ptype, ha)
    local localAddress = arp.internal.localAddress --alias
    if (localAddress[htype] and localAddress[htype][ha] and localAddress[htype][ha][ptype]) then
        return localAddress[htype][ha][ptype]
    end
    return nil
end

---Resolve local protocol address into hardware address
---@param htype number
---@param ptype number
---@param pa any Requested protocol address
---@return string|number?
function arp.getLocalHardwareAddress(htype, ptype, pa)
    local localAddress = arp.internal.localAddress --alias
    for ha, v in pairs(localAddress[htype]) do
        if (v[ptype] == pa) then return ha end
    end
end

---Resolve harware address
---@param interface ARPLayer
---@param htype number requested address type
---@param ptype number provided address type
---@param pa any Requested protocol address
---@param spa any Local protocol address
---@return any? tpa target protocol address
function arp.getAddress(interface, htype, ptype, pa, spa)
    local cache = arp.internal.cache --alias
    if (cache[ptype] and cache[ptype][pa] and cache[ptype][pa][htype]) then
        return cache[ptype][pa][htype]
    end
    -- cache miss
    local arpMessage = ARPFrame(htype, ptype, ARPFrame.OPERATION.REQUEST, interface:getAddr(), spa, ethernet.MAC_NIL, pa)
    interface:send(ethernet.MAC_BROADCAST, arpMessage)

    local tpa = select(4, event.pull(1, "arp", htype, ptype, nil, pa))
    return tpa
end

function arp.list(htype, ptype)
    local l = {}
    if (arp.internal.cache[ptype]) then
        for k, v in pairs(arp.internal.cache[ptype]) do
            table.insert(l, { k, v[htype] })
        end
    end
    return l
end

arp.ARPLayer = ARPLayer
arp.ARPFrame = ARPFrame
return arp
