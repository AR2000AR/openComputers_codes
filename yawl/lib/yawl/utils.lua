---@class yawlUtils

local utils = {}

---Take a color int (hex) and return it's red green and blue components
---@param hex number
---@return number
---@return number
---@return number
function utils.colorToRGB(hex)
    assert(hex >= 0 and hex <= 0xffffff)
    local r = (hex & 0xff0000) >> 16
    local g = (hex & 0x00ff00) >> 8
    local b = (hex & 0x0000ff)
    return r, g, b
end

---Take a RGB value and convert it to a color value
---@param r number
---@param g number
---@param b number
---@return number
---@overload fun(rgb:table):number
function utils.RGBtoColor(r, g, b)
    assert(r >= 0x00 and r <= 0xff)
    assert(g >= 0x00 and g <= 0xff)
    assert(b >= 0x00 and b <= 0xff)
    if (type(r) == "table") then
        b = r[3]
        g = r[2]
        r = r[1]
    end
    return b + (g << 8) + (r << 16)
end

return utils
