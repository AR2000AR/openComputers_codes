local bit32 = require("bit32")

---@class ipv4AdressLib
local ipv4Adress = {}

function ipv4Adress.fromString(val)
    checkArg(1, val, 'string')
    local a, b, c, d = val:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
    if (not a or not b or not c or not d) then error("Not a IPv4", 2) end
    a = assert(tonumber(a))
    b = assert(tonumber(b))
    c = assert(tonumber(c))
    d = assert(tonumber(d))
    if (not (0 <= a and a <= 255)) then error("#1 Not a valid IPv4", 2) end
    if (not (0 <= b and b <= 255)) then error("#1 Not a valid IPv4", 2) end
    if (not (0 <= c and c <= 255)) then error("#1 Not a valid IPv4", 2) end
    if (not (0 <= d and d <= 255)) then error("#1 Not a valid IPv4", 2) end
    return bit32.lshift(a, 8 * 3) + bit32.lshift(b, 8 * 2) + bit32.lshift(c, 8 * 1) + d
end

function ipv4Adress.tostring(val)
    checkArg(1, val, 'number')
    local a = bit32.extract(val, 24, 8)
    local b = bit32.extract(val, 16, 8)
    local c = bit32.extract(val, 8, 8)
    local d = bit32.extract(val, 0, 8)
    return string.format("%d.%d.%d.%d", a, b, c, d)
end

---Get the address and mask from the CIDR notation
---@param cidr string
---@return number address, number mask
function ipv4Adress.fromCIDR(cidr)
    checkArg(1, cidr, 'string')
    local address, mask = cidr:match("^(%d+%.%d+%.%d+%.%d+)/(%d+)$")
    mask = assert(tonumber(mask))
    return ipv4Adress.fromString(address), ipv4Adress.maskLenToMask(mask)
end

---Get the mask length (eg 24) and return the network mask
---@param maskLen number
---@return number mask
function ipv4Adress.maskLenToMask(maskLen)
    checkArg(1, maskLen, 'number')
    assert(maskLen >= 0, "Invalid mask")
    assert(maskLen <= 32, "Invalid mask")
    return bit32.lshift(2 ^ maskLen - 1, 32 - maskLen)
end

---@param mask number
---@return number maskLength
function ipv4Adress.maskToMaskLen(mask)
    local len = 32
    mask = ~mask & 0xffffffff
    while mask & 1 == 1 do
        len = len - 1
        mask = mask >> 1
    end
    return len
end

return ipv4Adress
