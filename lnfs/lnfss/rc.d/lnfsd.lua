local event = require("event")
local filesystem = require("filesystem")
local component = require("component")
local serialization = require("serialization")

local modem = component.modem

local ROOT = "/home/"
local PORT = nil
local RO = nil
local NAME = nil

local function buildPath(root, path)
    local rootSegments = filesystem.segments(root)
    local pathSegments = filesystem.segments(filesystem.concat(root, path))
    --rootSegments can't be longer than pathSegments
    if (#rootSegments > #pathSegments) then return root end
    for i, segment in ipairs(rootSegments) do
        if (not segment == pathSegments[i]) then return root end
    end
    return filesystem.concat(root, path)
end

local handler = {fd = {lastFd = 0}}

function handler.spaceUsed()
    local path = ROOT
    local fs = filesystem.get(path)
    return fs.spaceUsed()
end

function handler.open(path, mode)
    path = buildPath(ROOT, path)
    checkArg(1, path, "string")
    checkArg(2, mode, "string", "nil")
    local fs = filesystem.get(path)
    local fd, reason = fs.open(path:gsub("^" .. ROOT, ""), mode)
    if (not fd) then return nil, reason end
    handler.fd.lastFd = handler.fd.lastFd + 1
    handler.fd[handler.fd.lastFd] = {path, fd}
    return handler.fd.lastFd, reason
end

function handler.seek(handle, whence, offset)
    checkArg(1, handle, "number")
    checkArg(2, whence, "string")
    checkArg(3, offset, "number")
    local fs = filesystem.get(handler.fd[handle][1])
    return fs.seek(handler.fd[handle][2], whence, offset)
end

function handler.makeDirectory(path)
    path = buildPath(ROOT, path)
    checkArg(1, path, "string")
    return filesystem.makeDirectory(path)
end

function handler.exists(path)
    path = buildPath(ROOT, path)
    return filesystem.exists(path)
end

function handler.isReadOnly()
    local path = ROOT
    local fs = filesystem.get(path)
    return fs.isReadOnly() or RO
end

function handler.write(handle, value)
    checkArg(1, handle, "number")
    checkArg(2, value, "string")
    local fs = filesystem.get(handler.fd[handle][1])
    return fs.write(handler.fd[handle][2], value)
end

function handler.spaceTotal()
    local path = ROOT
    local fs = filesystem.get(path)
    return fs.spaceTotal()
end

function handler.isDirectory(path)
    path = buildPath(ROOT, path)
    return filesystem.isDirectory(path)
end

function handler.rename(from, to)
    checkArg(1, from, "string")
    checkArg(2, to, "string")
    from = ROOT .. from
    to   = ROOT .. to
    return filesystem.rename(from, to)
end

function handler.list(path)
    path = buildPath(ROOT, path)
    local paths = {}
    for lsPath in filesystem.list(path) do table.insert(paths, lsPath) end
    return paths
end

function handler.lastModified(path)
    checkArg(1, path, "string")
    path = buildPath(ROOT, path)
    return filesystem.lastModified(path)
end

function handler.getLabel()
    return NAME
end

function handler.remove(path)
    checkArg(1, path, "string")
    path = buildPath(ROOT, path)
    return filesystem.remove(path)
end

function handler.close(handle)
    checkArg(1, handle, "number")
    local fs = filesystem.get(handler.fd[handle][1])
    local res = fs.close(handler.fd[handle][2])
    handler.fd[handle] = nil
    return res
end

function handler.size(path)
    checkArg(1, path, "string")
    path = buildPath(ROOT, path)
    local fs = filesystem.get(path)
    return fs.size(path)
end

function handler.read(handle, count)
    checkArg(1, handle, "number")
    checkArg(2, count, "number")
    local fs = filesystem.get(handler.fd[handle][1])
    return fs.read(handler.fd[handle][2], count)
end

---@diagnostic disable-next-line: lowercase-global
function start(msg)
    ---@diagnostic disable-next-line: lowercase-global
    if (not args) then args = {root = ROOT, ro = false, port = 21} end
    ---@diagnostic disable-next-line: lowercase-global
    if (type(args) == "string") then args = {root = args, ro = false, port = 21} end
    ROOT = args.root or "/"
    RO = false or args.ro
    PORT = args.port or 21
    NAME = args.name
    if (not NAME) then
        if (filesystem.exists("/etc/hostname")) then
            local hf, reason = io.open("/etc/hostname")
            assert(hf, reason)
            NAME = hf:read("l")
            hf:close()
        end
    end
    if (not NAME) then NAME = "lnfs" end

    if (not modem.open(PORT)) then return false end
    event.listen("modem_message", function(e, to, from, port, dist, answerPort, cmd, data)
        if (from == to and cmd == "STOP") then
            return false
        end
        if (port == PORT) then
            modem.send(from, answerPort, PORT, cmd, serialization.serialize(table.pack(handler[cmd](table.unpack(serialization.unserialize(data))))))
        end
    end)
    return true
end

---@diagnostic disable-next-line: lowercase-global
function stop()
    if (not modem.isOpen(21)) then return false end
    modem.send(modem.address, PORT, "STOP")
    modem.close(21)
    return true
end
