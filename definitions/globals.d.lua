---@meta

---@param idx number
---@param var any
---@vararg 'string' | 'table' | 'number' | 'boolean' | 'userdata' | 'nil'
function checkArg(idx, var, ...) end

component = {
    doc     = function(...) end,
    fields  = function(...) end,
    invoke  = function(...) end,
    list    = function(...) end,
    methods = function(...) end,
    proxy   = function(...) end,
    slot    = function(...) end,
    type    = function(...) end
}

computer = {}

_VERSION = 5.3

_OSVERSION = "OpenOS 1.7.7"

computer = require("computer")

string = require("string")
math = require("math")
table = require("table")
debug = {
    getinfo    = function(...) end,
    traceback  = function(...) end,
    getlocal   = function(...) end,
    getupvalue = function(...) end,
}
coroutine = require("coroutine")
bit32 = {
    arshift = function(...) end,
    band    = function(...) end,
    bnot    = function(...) end,
    bor     = function(...) end,
    btest   = function(...) end,
    bxor    = function(...) end,
    extract = function(...) end,
    lrotate = function(...) end,
    lshift  = function(...) end,
    replace = function(...) end,
    rrotate = function(...) end,
    rshift  = function(...) end,
}

os = {
    clock    = function(...) end,
    date     = function(...) end,
    difftime = function(...) end,
    time     = function(...) end,
}

unicode = {
    char = function(...) end,
    charWidth = function(...) end,
    isWide = function(...) end,
    len = function(...) end,
    lower = function(...) end,
    reverse = function(...) end,
    sub = function(...) end,
    upper = function(...) end,
    wlen = function(...) end,
    wtrunc = function(...) end,
}

utf8 = {
    char = function(...) end,
    charpattern = function(...) end,
    codes = function(...) end,
    codepoint = function(...) end,
    len = function(...) end,
    offset = function(...) end,
}
