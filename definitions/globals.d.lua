---@meta

---@param idx number
---@param var any
---@vararg 'string' | 'table' | 'number' | 'boolean' | 'userdata' | 'nil'
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

---@return number
function bit32.arshift(...)
end

---@return number
function bit32.band(...)
end

---@return number
function bit32.bnot(...)
end

---@return number
function bit32.bor(...)
end

---@return number
function bit32.btest(...)
end

---@return number
function bit32.bxor(...)
end

---@return number
function bit32.extract(...)
end

---@return number
function bit32.lrotate(...)
end

---@return number
function bit32.lshift(...)
end

---@return number
function bit32.replace(...)
end

---@return number
function bit32.rrotate(...)
end

---@return number
function bit32.rshift(...)
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
