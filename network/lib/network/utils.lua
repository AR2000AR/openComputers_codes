local utils = {}

function utils.checksum(data)
    local sum = 0;
    local count = #data
    local val, offset
    while count > 1 do
        val, offset = string.unpack('>H', data, offset)
        sum = sum + val
        count = count - 2;
    end

    --Add left-over byte, if any
    if (count > 0) then
        sum = sum + (string.unpack('>B', data, offset) << 8)
    end

    --Fold 32-bit sum to 16 bits
    while (sum >> 16 ~= 0) do
        sum = (sum & 0xffff) + (sum >> 16);
    end

    return ~sum & 0xffff
end

local class = require("libClass2")

---@class Buffer:Object
---@field private _data string
---@operator call:Buffer
local Buffer = require('libClass2')()

---Comment
---@return Buffer
function Buffer:new()
    local o = self.parent()
    setmetatable(o, {__index = self})
    ---@cast o Buffer
    o._data = ""
    return o
end

function Buffer:insert(value)
    checkArg(1, value, "string")
    self._data = (self._data or "") .. value
end

---Read from the buffer
---@param pattern "*a"|"*l"|number
---@return string
function Buffer:read(pattern)
    if (pattern == "*a") then
        local res = self._data
        self._data = nil
        return res
    elseif (pattern == "*l") then
        local res
        res, self._data = self._data:match("([^\n]*)\n?(.*)")
        return res
    elseif (type(pattern) == "number") then
        local res = self._data:sub(1, pattern)
        self._data = self._data:sub(pattern + 1)
        return res
    end
    error("Invalid pattern", 2)
end

---@return number
function Buffer:len()
    return #self._data
end

utils.Buffer = Buffer

return utils
