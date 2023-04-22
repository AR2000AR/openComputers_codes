---@meta

---@class libtext
local text = {}

text.syntax = {"^%d?>>?&%d+", "^%d?>>?", ">>?", "<%&%d+", "<", ";", "&&", "||?"}

---trim whitespace
---@param value string
---@return string
function text.trim(value)
end

--- used by lib/sh
---Escape magic char like %s
---@param txt string
---@return string string, number count
function text.escapeMagic(txt)
end

---undo escaped char
---@param txt string
---@return string string, number count
function text.removeEscapes(txt)
end

---separate string value into an array of words delimited by whitespace\
---groups by quotes\
---options is a table used for internal undocumented purposes
---@param value string
---@param options table
---@return table
function text.tokenize(value, options)
end

-------------------------------------------------------------------------------
---like tokenize, but does not drop any text such as whitespace
---splits input into an array for sub strings delimited by delimiters
---delimiters are included in the result if not dropDelims
---@param input string
---@param delimiters string
---@param dropDelims? boolean
---@param di? number
---@return table
function text.split(input, delimiters, dropDelims, di)
end

-----------------------------------------------------------------------------

---replace tabs `\t` with spaces
---@param value string
---@param tabWidth? number default 8
---@return string
function text.detab(value, tabWidth)
end

---add spaces to the left to fit specified length
---@param value? string
---@param length number
---@return string
function text.padLeft(value, length)
end

---add spaces to the right to fit specified length
---@param value? string
---@param length number
---@return string
function text.padRight(value, length)
end

---Wrap the string over multipes line of prefered widht and maxWidth
---@param value string
---@param width number
---@param maxWidth number
---@return string line,string value, boolean end
function text.wrap(value, width, maxWidth)
end

---Iterator over the wrapped lines
---@param value string
---@param width number
---@param maxWidth number
---@return function
function text.wrappedLines(value, width, maxWidth)
    local line
    return function()
        if value then
            line, value = text.wrap(value, width, maxWidth)
            return line
        end
    end
end

return text
