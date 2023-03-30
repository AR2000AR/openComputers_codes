local ethernet               = require("network.ethernet")
local event                  = require("event")
local ARPFrame               = require("network.arp.ARPFrame")

---@class arplib
---@field private internal table
local arpAPI                 = {}
arpAPI.internal              = {}
arpAPI.internal.cache        = {}
arpAPI.internal.localAddress = {}


---Add the address to the cache
---@param htype number
---@param ptype number
---@param ha any
---@param pa any
function arpAPI.addCached(htype, ptype, ha, pa)
    local cache = arpAPI.internal.cache --alias
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
function arpAPI.setLocalAddress(htype, ptype, ha, pa)
    local localAddress = arpAPI.internal.localAddress --alias
    if (not localAddress[htype]) then localAddress[htype] = {} end
    if (not localAddress[htype][ha]) then localAddress[htype][ha] = {} end
    localAddress[htype][ha][ptype] = pa
end

---Resolve local harware address into protocol address
---@param htype number
---@param ptype number
---@param ha any Requested hardware address
---@return string|number?
function arpAPI.getLocalAddress(htype, ptype, ha)
    local localAddress = arpAPI.internal.localAddress --alias
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
function arpAPI.getLocalHardwareAddress(htype, ptype, pa)
    local localAddress = arpAPI.internal.localAddress --alias
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
function arpAPI.getAddress(interface, htype, ptype, pa, spa)
    local cache = arpAPI.internal.cache --alias
    if (cache[ptype] and cache[ptype][pa] and cache[ptype][pa][htype]) then
        return cache[ptype][pa][htype]
    end
    -- cache miss
    local arpMessage = ARPFrame(htype, ptype, ARPFrame.OPERATION.REQUEST, interface:getAddr(), spa, ethernet.MAC_NIL, pa)
    interface:send(ethernet.MAC_BROADCAST, arpMessage)

    local tpa = select(4, event.pull(1, "arp", htype, ptype, nil, pa))
    return tpa
end

function arpAPI.list(htype, ptype)
    local l = {}
    if (arpAPI.internal.cache[ptype]) then
        for k, v in pairs(arpAPI.internal.cache[ptype]) do
            table.insert(l, {k, v[htype]})
        end
    end
    return l
end

return arpAPI
