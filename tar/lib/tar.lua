local filesystem = require("filesystem")
local shell = require("shell")
local io = require("io")

---@class tarHeader
---@field name any
---@field mode any
---@field uid any
---@field gid any
---@field size any
---@field mtime any
---@field chksum any
---@field typeflag any
---@field linkname any
---@field magic any
---@field version any
---@field uname any
---@field gname any
---@field devmajor any
---@field devminor any
---@field prefix any

---https://github.com/luarocks/luarocks/blob/master/src/luarocks/core/dir.lua
local function unquote(c)
    local first, last = c:sub(1, 1), c:sub(-1)
    if (first == '"' and last == '"') or
        (first == "'" and last == "'") then
        return c:sub(2, -2)
    end
    return c
end
local dir = {}
function dir.path(...)
    local t = {...}
    while t[1] == "" do
        table.remove(t, 1)
    end
    for i, c in ipairs(t) do
        t[i] = unquote(c)
    end
    return (table.concat(t, "/"):gsub("([^:])/+", "%1/"):gsub("^/+", "/"):gsub("/*$", ""))
end

---https://github.com/luarocks/luarocks/blob/master/src/luarocks/tools/tar.lua#L56
--- A pure-Lua implementation of untar (unpacking .tar archives)
local tar = {}

local blocksize = 512

local function get_typeflag(flag)
    if flag == "0" or flag == "\0" then
        return "file"
    elseif flag == "1" then
        return "link"
    elseif flag == "2" then
        return "symlink" -- "reserved" in POSIX, "symlink" in GNU
    elseif flag == "3" then
        return "character"
    elseif flag == "4" then
        return "block"
    elseif flag == "5" then
        return "directory"
    elseif flag == "6" then
        return "fifo"
    elseif flag == "7" then
        return "contiguous" -- "reserved" in POSIX, "contiguous" in GNU
    elseif flag == "x" then
        return "next file"
    elseif flag == "g" then
        return "global extended header"
    elseif flag == "L" then
        return "long name"
    elseif flag == "K" then
        return "long link name"
    end
    return "unknown"
end

local function octal_to_number(octal)
    local exp = 0
    local number = 0
    octal = octal:gsub("%s", "")
    for i = #octal, 1, -1 do
        local digit = tonumber(octal:sub(i, i))
        if not digit then
            break
        end
        number = number + (digit * 8 ^ exp)
        exp = exp + 1
    end
    return number
end

local function checksum_header(block)
    local sum = 256
    for i = 1, 148 do
        local b = block:byte(i) or 0
        sum = sum + b
    end
    for i = 157, 500 do
        local b = block:byte(i) or 0
        sum = sum + b
    end
    return sum
end

local function nullterm(s)
    return s:match("^[^%z]*")
end

local function read_header_block(block)
    local header = {}
    header.name = nullterm(block:sub(1, 100))
    header.mode = nullterm(block:sub(101, 108)):gsub(" ", "")
    header.uid = octal_to_number(nullterm(block:sub(109, 116)))
    header.gid = octal_to_number(nullterm(block:sub(117, 124)))
    header.size = octal_to_number(nullterm(block:sub(125, 136)))
    header.mtime = octal_to_number(nullterm(block:sub(137, 148)))
    header.chksum = octal_to_number(nullterm(block:sub(149, 156)))
    header.typeflag = get_typeflag(block:sub(157, 157))
    header.linkname = nullterm(block:sub(158, 257))
    header.magic = block:sub(258, 263)
    header.version = block:sub(264, 265)
    header.uname = nullterm(block:sub(266, 297))
    header.gname = nullterm(block:sub(298, 329))
    header.devmajor = octal_to_number(nullterm(block:sub(330, 337)))
    header.devminor = octal_to_number(nullterm(block:sub(338, 345)))
    header.prefix = block:sub(346, 500)
    if checksum_header(block) ~= header.chksum then
        return false, "Failed header checksum"
    end
    return header
end


function tar.untar(filename, destdir)
    checkArg(1, filename, "string")
    checkArg(2, destdir, "string")

    local tar_handle = io.open(filename, "rb")
    if not tar_handle then return nil, "Error opening file " .. filename end

    local long_name, long_link_name
    local ok, err
    local make_dir = filesystem.makeDirectory
    while true do
        local block
        repeat
            block = tar_handle:read(blocksize)
        until (not block) or checksum_header(block) > 256
        if not block then break end
        if #block < blocksize then
            ok, err = nil, "Invalid block size -- corrupted file?"
            break
        end
        local header
        header, err = read_header_block(block)
        if not header then
            ok = false
            break
        end

        local file_data = tar_handle:read(math.ceil(header.size / blocksize) * blocksize):sub(1, header.size)

        if header.typeflag == "long name" then
            long_name = nullterm(file_data)
        elseif header.typeflag == "long link name" then
            long_link_name = nullterm(file_data)
        else
            if long_name then
                header.name = long_name
                long_name = nil
            end
            if long_link_name then
                header.name = long_link_name
                long_link_name = nil
            end
        end
        local pathname = dir.path(destdir, header.name)
        pathname = filesystem.canonical(pathname)
        if header.typeflag == "directory" then
            make_dir(pathname)
        elseif header.typeflag == "file" then
            local dirname = filesystem.path(pathname)
            if dirname ~= "" then
                make_dir(dirname)
            end
            local file_handle
            file_handle, err = io.open(pathname, "wb")
            if not file_handle then
                ok = nil
                require("event").onError("[tar]" .. err)
                break
            end
            file_handle:write(file_data):close()
        end
    end
    tar_handle:close()
    return ok, err
end

--END OF luarocks original code

---Retrun the headers
---@param filename string
---@return table<number,tarHeader>?, string? reason
function tar.list(filename)
    checkArg(1, filename, 'string')
    local tar_handle = io.open(filename, "rb")
    if not tar_handle then return nil, "Error opening file " .. filename end
    local ok, err
    local long_name, long_link_name
    local files = {}
    while true do
        local block
        repeat
            block = tar_handle:read(blocksize)
        until (not block) or checksum_header(block) > 256
        if not block then break end
        if #block < blocksize then
            ok, err = nil, "Invalid block size -- corrupted file?"
            break
        end
        local header
        header, err = read_header_block(block)
        if not header then
            ok = false
            break
        end
        local file_data = tar_handle:read(math.ceil(header.size / blocksize) * blocksize):sub(1, header.size)
        if header.typeflag == "long name" then
            long_name = nullterm(file_data)
        elseif header.typeflag == "long link name" then
            long_link_name = nullterm(file_data)
        else
            if long_name then
                header.name = long_name
                long_name = nil
            end
            if long_link_name then
                header.name = long_link_name
                long_link_name = nil
            end
        end
        if (header.typeflag == "file" or header.typeflag == "directory") then
            table.insert(files, header)
        end
    end
    tar_handle:close()
    return files, err
end

---Extract files that match filename `fineNameInArchive:match("^"..filename)
---@param tarname string
---@param filename? string|table
---@param overwrite boolean overwrite existing files.
---@param ignore? string|table
---@param destdir string
---@param newRoot? string
function tar.extract(tarname, destdir, overwrite, filename, ignore, newRoot)
    checkArg(1, tarname, "string")
    checkArg(2, destdir, "string")
    checkArg(3, overwrite, "boolean")
    checkArg(4, filename, "string", "table", 'nil')
    checkArg(5, ignore, "string", "table", 'nil')
    checkArg(6, destdir, "string")
    checkArg(7, newRoot, "string", "nil")

    ---@param name string
    ---@return boolean
    local function shouldExtractFile(name)
        local ok = true
        if (filename and type(filename) == "string") then
            if (not name:match("^" .. filename)) then ok = false end
        end
        if (filename and type(filename) == "table") then
            for _, fname in pairs(filename) do
                if (not name:match("^" .. fname)) then ok = false end
            end
        end
        if (ignore and type(ignore) == "string") then
            if (name:match("^" .. ignore)) then ok = false end
        end
        if (ignore and type(ignore) == "table") then
            for _, fname in pairs(ignore) do
                if (name:match("^" .. fname)) then ok = false end
            end
        end
        return ok
    end

    local tar_handle = io.open(tarname, "rb")
    if not tar_handle then return nil, "Error opening file " .. tarname end

    local long_name, long_link_name
    ---@type boolean?, string?
    local ok, err = true, nil
    local make_dir = filesystem.makeDirectory
    while true do
        local block
        repeat
            block = tar_handle:read(blocksize)
        until (not block) or checksum_header(block) > 256
        if not block then break end
        if #block < blocksize then
            ok, err = nil, "Invalid block size -- corrupted file?"
            break
        end
        local header
        header, err = read_header_block(block)
        if not header then
            ok = false
            break
        end

        local file_data = tar_handle:read(math.ceil(header.size / blocksize) * blocksize):sub(1, header.size)

        if header.typeflag == "long name" then
            long_name = nullterm(file_data)
        elseif header.typeflag == "long link name" then
            long_link_name = nullterm(file_data)
        else
            if long_name then
                header.name = long_name
                long_name = nil
            end
            if long_link_name then
                header.name = long_link_name
                long_link_name = nil
            end
        end


        if (shouldExtractFile(header.name)) then
            local pathname = dir.path(destdir, header.name)
            if (newRoot) then --change the archive root
                pathname = pathname:gsub(newRoot, "")
            end
            pathname = filesystem.canonical(pathname)

            if header.typeflag == "directory" then
                make_dir(pathname)
            elseif header.typeflag == "file" then
                local dirname = filesystem.path(pathname)
                if dirname ~= "" then
                    make_dir(dirname)
                end
                if (overwrite or not (filesystem.exists(pathname) and not filesystem.isDirectory(pathname))) then
                    local file_handle
                    file_handle, err = io.open(pathname, "wb")
                    if not file_handle then
                        ok = nil
                        require("event").onError("[tar]" .. err)
                        break
                    end
                    file_handle:write(file_data):close()
                end
            end
        end
    end
    tar_handle:close()
    return ok, err
end

return tar
