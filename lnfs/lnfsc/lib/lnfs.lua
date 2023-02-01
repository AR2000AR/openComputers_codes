local component     = require("component")
local uuid          = require("uuid")
local serialization = require("serialization")
local event         = require("event")
local filesystem    = require("filesystem")

if (not component.isAvailable("modem")) then
    error("No modem component available. Cannot load library", 0)
end
local modem = component.modem

local lnfs = {}

local TIMEOUT = 5
local MTU = math.floor(tonumber(require("computer").getDeviceInfo()[modem.address].capacity) * 0.9)

---return the path of the directory the file is in
---@param path string file path
---@return string path directory path
local function dirName(path)
    local dir = filesystem.segments(path)
    table.remove(dir, #dir)
    return filesystem.concat(table.unpack(dir))
end

---split a string into smaller chunks
---@param text string
---@param chunkSize number
---@return table chunkedText
local function splitByChunk(text, chunkSize)
    local s = {}
    for i = 1, #text, chunkSize do
        table.insert(s, text:sub(i, i + chunkSize - 1))
    end
    return s
end

---@class LnfsFilesystemProxy : ComponentFilesystem

lnfs.LnfsProxy = {}

---Create a new lnfs filesystem proxy
---@param remoteAddr string
---@param remotePort? number
---@param readOnly? boolean
---@return LnfsFilesystemProxy|nil proxy, string|nil reason Explaination of the proxy creation failure
function lnfs.LnfsProxy.new(remoteAddr, remotePort, readOnly)
    checkArg(1, remoteAddr, "string")
    checkArg(2, remotePort, "number", "nil")
    checkArg(3, readOnly, "boolean", "nil")
    local self          = {type = "filesystem", address = uuid.next()}
    remotePort          = remotePort or 21
    readOnly            = readOnly or false
    local label         = nil
    local filePropCache = {isDirectory = {}, size = {}, lastModified = {}, list = {}}

    local function sendRequest(cmd, ...)
        local port
        repeat
            port = math.floor(math.random(49152, 65535))
        until (not modem.isOpen(port))
        modem.open(port)
        modem.send(remoteAddr, remotePort, port, cmd, serialization.serialize(table.pack(...)))
        local eventName, _, _, _, _, _, _, data = event.pull(TIMEOUT, "modem_message", nil, remoteAddr, port, nil, nil, cmd)
        modem.close(port)
        if (eventName) then
            return table.unpack(serialization.unserialize(data))
        else
            return nil, "timeout"
        end
    end

    local function sendCacheRequest(cmd, path)
        event.timer(0.5 + math.random(1, 20) / 5, function()
            local port
            repeat
                port = math.floor(math.random(49152, 65535))
            until (not modem.isOpen(port))
            modem.open(port)
            modem.send(remoteAddr, remotePort, port, cmd, serialization.serialize(table.pack(path)))
            event.listen("modem_message", function(e, t, f, p, d, a, c, data)
                if (p == port and c == cmd) then
                    filePropCache[cmd][path] = table.unpack(serialization.unserialize(data))
                    modem.close(port)
                end
            end)
        end)
    end

    function self.spaceUsed()
        return sendRequest("spaceUsed")
    end

    function self.open(path, mode)
        checkArg(1, path, "string")
        checkArg(2, mode, "string", "nil")
        if (self.isReadOnly() and mode ~= "r") then return nil, "Is read only" end
        if (mode ~= 'r') then
            filePropCache.list[dirName(path)] = nil
            filePropCache.size[path]          = nil
        end
        filePropCache.lastModified[path] = nil
        return sendRequest("open", path, mode)
    end

    function self.seek(handle, whence, offset)
        checkArg(1, handle, "number")
        checkArg(2, whence, "string")
        checkArg(3, offset, "number")
        return sendRequest("seek", handle, whence, offset)
    end

    function self.makeDirectory(path)
        checkArg(1, path, "string")
        if (self.isReadOnly()) then return nil, "Is read only" end
        filePropCache.list[dirName(path)] = nil
        return sendRequest("makeDirectory", path)
    end

    function self.exists(path)
        checkArg(1, path, "string")
        return sendRequest("exists", path)
    end

    function self.isReadOnly()
        readOnly = readOnly or sendRequest("isReadOnly")
        return readOnly
    end

    function self.write(handle, value)
        checkArg(1, handle, "number")
        checkArg(2, value, "string")
        if (self.isReadOnly()) then return nil, "Is read only" end
        local written = 0
        local st, reason, lastreason
        value = splitByChunk(value, MTU)
        for _, v in ipairs(value) do
            st, reason = sendRequest("write", handle, v)
            if (st) then
                written = written + 1
            end
            if (reason) then
                lastreason = reason
            end
        end
        return written == #value, lastreason
    end

    function self.spaceTotal()
        return sendRequest("spaceTotal")
    end

    function self.isDirectory(path)
        checkArg(1, path, "string")
        if (filePropCache.isDirectory[path] == nil) then
            --print("Cache miss", path, "isDirectory")
            filePropCache.isDirectory[path] = sendRequest("isDirectory", path)
        end
        return filePropCache.isDirectory[path] or false
    end

    function self.rename(from, to)
        checkArg(1, from, "string")
        checkArg(2, to, "string")
        if (self.isReadOnly()) then return nil, "Is read only" end
        filePropCache.isDirectory[from]   = nil
        filePropCache.size[from]          = nil
        filePropCache.lastModified[from]  = nil
        filePropCache.list[dirName(from)] = nil
        filePropCache.list[dirName(to)]   = nil
        return sendRequest("rename", from, to)
    end

    function self.list(path)
        checkArg(1, path, "string")
        if (filePropCache.list[path] == nil) then
            --print("Cache miss", path, "list")
            filePropCache.list[path] = sendRequest("list", path)
        end
        for i, v in ipairs(filePropCache.list[path]) do
            sendCacheRequest("size", v)
            sendCacheRequest("isDirectory", v)
            sendCacheRequest("lastModified", v)
        end
        sendCacheRequest("list", path) --keep a up to date cache
        return filePropCache.list[path] or {}
    end

    function self.lastModified(path)
        checkArg(1, path, "string")
        if (filePropCache.lastModified[path] == nil) then
            --print("Cache miss", path, "lastModified")
            filePropCache.lastModified[path] = sendRequest("lastModified", path)
        end
        return filePropCache.lastModified[path] or 0
    end

    function self.getLabel()
        if (not label) then
            return sendRequest("getLabel")
        end
        return label
    end

    function self.remove(path)
        checkArg(1, path, "string")
        if (self.isReadOnly()) then return nil, "Is read only" end
        filePropCache.isDirectory[path]   = nil
        filePropCache.size[path]          = nil
        filePropCache.lastModified[path]  = nil
        filePropCache.list[dirName(path)] = nil
        return sendRequest("remove", path) or false
    end

    function self.close(handle)
        checkArg(1, handle, "number")
        return sendRequest("close", handle)
    end

    function self.size(path)
        checkArg(1, path, "string")
        if (filePropCache.size[path] == nil) then
            --print("Cache miss", path, "size")
            filePropCache.size[path] = sendRequest("size", path)
        end
        return filePropCache.size[path] or 0
    end

    function self.read(handle, count)
        checkArg(1, handle, "number")
        checkArg(2, count, "number")
        local d, r, data, reason
        repeat
            d, r = sendRequest("read", handle, math.min(count, MTU))
            count = count - MTU
            if (d) then
                if (data) then
                    data = data .. d
                else
                    data = d
                end
            end
            if (reason) then reason = reason .. r else reason = r end
        until count <= 0
        return data, reason
    end

    function self.setLabel(value)
        checkArg(1, value, "string", "nil")
        label = value
        return self.getLabel()
    end

    local l, reason = self.getLabel()
    if (not l) then
        return nil, reason
    else
        l, reason = nil, nil
        return self, nil
    end
end

return lnfs
