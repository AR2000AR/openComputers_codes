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

---Text wrap
---@param s string string to wrap
---@param max number maximum line length
---@return string
function utils.wrap(s, max)
    local result = {}
    for line in s:gmatch('[^\n]*') do
        local paragraph = ""
        local spaceLeft = max
        for word, space in line:gmatch("(%S*)(%s*)") do
            if (#word > max) then
                while #word > 0 do
                    local chunk = ""
                    chunk, word = word:sub(1, spaceLeft), word:sub(spaceLeft + 1)
                    paragraph = paragraph .. chunk
                    spaceLeft = spaceLeft - #chunk
                    if (spaceLeft == 0) then
                        paragraph = paragraph .. '\n'
                        spaceLeft = max
                    end
                end
            elseif (#word == max and spaceLeft == max) then
                paragraph = paragraph .. word
                spaceLeft = 0
            elseif (#word == max and spaceLeft ~= max) then
                paragraph = paragraph .. '\n' .. word
                spaceLeft = 0
            elseif (spaceLeft - #word >= 0) then
                paragraph = paragraph .. word
                spaceLeft = spaceLeft - #word
            else
                paragraph = paragraph .. '\n' .. word
                spaceLeft = max - #word
            end
            space = space:sub(1, spaceLeft - #space)
            paragraph = paragraph .. space
            spaceLeft = spaceLeft - #space
            if (spaceLeft <= 0) then
                paragraph = paragraph .. '\n'
                spaceLeft = max
            end
        end
        table.insert(result, paragraph)
    end
    return table.concat(result, '\n')
end

return utils
