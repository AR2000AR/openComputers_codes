local bit32 = require("bit32")

---@class ipv4AdressLib
local ipv4Adress = {}

function ipv4Adress.fromString(val)
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
    local address, mask = cidr:match("^(%d+%.%d+%.%d+%.%d+)/(%d+)$")
    mask = tonumber(mask)
    assert(mask >= 0, "Invalid mask")
    assert(mask <= 32, "Invalid mask")
    return ipv4Adress.fromString(address), bit32.lshift(2 ^ mask - 1, 32 - mask)
end

return ipv4Adress
