---@meta

---@param idx number
---@param var any
---@vararg 'string' | 'table' | 'number' | 'boolean' | 'userdata' | 'nil' | 'function'
function checkArg(idx, var, ...)
end

component = {
    doc     = function(...)
    end,
    fields  = function(...)
    end,
    invoke  = function(...)
    end,
    list    = function(...)
    end,
    methods = function(...)
    end,
    proxy   = function(...)
    end,
    slot    = function(...)
    end,
    type    = function(...)
    end
}

computer = {}

_VERSION = 5.3

_OSVERSION = "OpenOS 1.7.7"

computer = require("computer")

string = require("string")
math = require("math")
table = require("table")
debug = {
    getinfo    = function(...)
    end,
    traceback  = function(...)
    end,
    getlocal   = function(...)
    end,
    getupvalue = function(...)
    end,
}
coroutine = require("coroutine")
local bit32 = {}

---Returns the number x shifted disp bits to the right. The number disp may be any representable integer. Negative displacements shift to the left.\
---This shift operation is what is called arithmetic shift. Vacant bits on the left are filled with copies of the higher bit of x; vacant bits on the right are filled with zeros. In particular, displacements with absolute values higher than 31 result in zero or 0xFFFFFFFF (all original bits are shifted out).
---@param x number
---@param disp number
---@return number
function bit32.arshift(x, disp)
end

---Returns the bitwise and of its operands.
---@param ... number
---@return number
function bit32.band(...)
end

---Returns the bitwise negation of x. For any integer x, the following identity holds:\
---`assert(bit32.bnot(x) == (-1 - x) % 2^32)`
---@param x number
---@return number
function bit32.bnot(x)
end

---Returns the bitwise or of its operands.
---@param ... number
---@return number
function bit32.bor(...)
end

---Returns a boolean signaling whether the bitwise and of its operands is different from zero.
---@param ... number
---@return boolean
function bit32.btest(...)
end

---Returns the bitwise exclusive or of its operands.
---@param ... number
---@return number
function bit32.bxor(...)
end

---Returns the unsigned number formed by the bits field to field + width - 1 from n. Bits are numbered from 0 (least significant) to 31 (most significant). All accessed bits must be in the range [0, 31].\
---The default for width is 1.
---@param n number
---@param filed number
---@param width? number
---@return number
function bit32.extract(n, filed, width)
end

---Returns the number x rotated disp bits to the left. The number disp may be any representable integer.\
---For any valid displacement, the following identity holds:\
---`assert(bit32.lrotate(x, disp) == bit32.lrotate(x, disp % 32))`\
---In particular, negative displacements rotate to the right.
---@param x number
---@param disp any
---@return number
function bit32.lrotate(x, disp)
end

---Returns the number x shifted disp bits to the left. The number disp may be any representable integer. Negative displacements shift to the right. In any direction, vacant bits are filled with zeros. In particular, displacements with absolute values higher than 31 result in zero (all bits are shifted out).\
---For positive displacements, the following equality holds:\
---`assert(bit32.lshift(b, disp) == (b * 2^disp) % 2^32)`
---@param x number
---@param disp any
---@return number
function bit32.lshift(x, disp)
end

---Returns a copy of n with the bits field to field + width - 1 replaced by the value v. See bit32.extract for details about field and width.
---@param n number
---@param v number
---@param field number
---@param width number
---@return number
function bit32.replace(n, v, field, width)
end

---Returns the number x rotated disp bits to the right. The number disp may be any representable integer.\
---For any valid displacement, the following identity holds:\
---`assert(bit32.rrotate(x, disp) == bit32.rrotate(x, disp % 32))`\
---In particular, negative displacements rotate to the left.
---@param x number
---@param disp any
---@return number
function bit32.rrotate(x, disp)
end

---Returns the number x shifted disp bits to the right. The number disp may be any representable integer. Negative displacements shift to the left. In any direction, vacant bits are filled with zeros. In particular, displacements with absolute values higher than 31 result in zero (all bits are shifted out).\
---For positive displacements, the following equality holds:\
---assert(bit32.rshift(b, disp) == math.floor(b % 2^32 / 2^disp))\
---This shift operation is what is called logical shift.
---@param x number
---@param disp number
---@return number
function bit32.rshift(x, disp)
end

os = {
    clock    = function(...)
    end,
    date     = function(...)
    end,
    difftime = function(...)
    end,
    time     = function(...)
    end,
}

unicode = {
    char = function(...)
    end,
    charWidth = function(...)
    end,
    isWide = function(...)
    end,
    len = function(...)
    end,
    lower = function(...)
    end,
    reverse = function(...)
    end,
    sub = function(...)
    end,
    upper = function(...)
    end,
    wlen = function(...)
    end,
    wtrunc = function(...)
    end,
}

utf8 = {
    char = function(...)
    end,
    charpattern = function(...)
    end,
    codes = function(...)
    end,
    codepoint = function(...)
    end,
    len = function(...)
    end,
    offset = function(...)
    end,
}
