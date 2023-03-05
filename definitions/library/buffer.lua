---@meta

---@class bufferLib
local buffer = {}

---Creates a new buffered `stream`, wrapping stream with read-write `mode`.\
---`mode` can be readonly (r or `nil`), read-write (rw), or write-only (w).
---@param mode readmode
---@param stream table
---@return buffer
function buffer.new(mode, stream)
end

---@class buffer
local buffer = {}

function buffer:flush()
end

function buffer:close()
end

function buffer:setvbuf(mode, size)
end

function buffer:write(...)
end

function buffer:lines(line_format)
end

function buffer:read(...)
end

function buffer:getTimeout()
end

function buffer:setTimeout(timeout)
end

function buffer:seek(whence, offset)
end
