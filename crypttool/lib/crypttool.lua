local component = require("component")
local os = require("os")
local fs = require("filesystem")
local io = require("io")
local event = require("event")

-- check for datacard
assert(component.isAvailable("data"), "No data card available.")
assert(component.data.encrypt, "Need a T2 or higher data card.")
local data = component.data

local DATA_DIR = "/.crypttools/"

local crypttool = {}

crypttool.Proxy = {}
function crypttool.Proxy.new(filesystemComponent, aesKey)
    checkArg(1, filesystemComponent, "string", "table")
    checkArg(2, aesKey, "string")
    if (type(filesystemComponent) == "string") then
        filesystemComponent = fs.get(filesystemComponent)
    end
    assert(filesystemComponent, "No filesystem component")
    filesystemComponent.makeDirectory(DATA_DIR)
    local self = {rawFS = filesystemComponent, aesKey = aesKey, type = "filesystem", address = filesystemComponent.address:sub(1, -13) .. "43525950542e", handles = {last = 0}}
    local status, err = pcall(data.encrypt, "testdata", self.aesKey, data.md5(self.rawFS.address))
    if (not status) then
        error("Cannot encrypt data. Check that the aesKey is valid\n" .. err, 2)
    end

    local function getSecurePath(path)
        if (not path:match("^" .. DATA_DIR)) then
            return string.format("%s%s", "^" .. DATA_DIR, path)
        end
        return path
    end

    local function getVisiblePath(path)
        local tmp = path:gsub("^" .. DATA_DIR, "")
        return tmp
    end

    function self.spaceUsed() return self.rawFS.spaceUsed() end

    function self.spaceTotal() return self.rawFS.spaceTotal() end

    function self.size(path)
        path = getSecurePath(path)
        return self.rawFS.size(path)
    end

    function self.isReadOnly() return self.rawFS.isReadOnly() end

    function self.getLabel() return self.rawFS.getLabel() or "crypttool" end

    function self.list(path) return self.rawFS.list(getSecurePath(path)) end

    function self.lastModified(path) return self.rawFS.lastModified(getSecurePath(path)) end

    function self.exists(path) return self.rawFS.exists(getSecurePath(path)) end

    function self.isDirectory(path) return self.rawFS.isDirectory(getSecurePath(path)) end

    function self.makeDirectory(path) return self.rawFS.makeDirectory(getSecurePath(path)) end

    function self.remove(path) return self.rawFS.remove(getSecurePath(path)) end

    function self.rename(from, to) return self.rawFS.rename(getSecurePath(from), getSecurePath(to)) end

    function self.setLabel(value) return self.rawFS.setLabel(value) end

    function self.open(path, mode)
        if (mode == nil) then mode = "r" end
        path = getSecurePath(path)
        if (mode == "r" or mode == "rb") then
            if (not self.exists(path) or self.isDirectory(path)) then
                error(string.format("Cannot open %q : Not such file.", getVisiblePath(path)), 2)
            end
        end
        local handle = self.handles.last + 1
        self.handles.last = self.handles.last + 1
        self.handles[handle] = {path = path}
        self.handles[handle].tmpFilePath = os.tmpname()
        if (mode == "r" or mode == "rb" or mode == "a" or mode == "ab") then
            local eFile = self.rawFS.open(path, mode)
            assert(eFile, "Could not open the encrypted file")
            local tFile
            if (mode:match("b")) then tFile = io.open(self.handles[handle].tmpFilePath, "wb")
            else tFile = io.open(self.handles[handle].tmpFilePath, "w") end
            assert(tFile)
            local eData = ""
            repeat
                local readData = self.rawFS.read(eFile, 1024)
                if (readData) then eData = eData .. readData end
            until readData == nil
            tFile:write(data.decrypt(eData, self.aesKey, data.md5(self.rawFS.address)))
            tFile:close()
            self.rawFS.close(eFile)
        end
        self.handles[handle].tmpFile = io.open(self.handles[handle].tmpFilePath, mode)
        return handle
    end

    function self.seek(handle, whence, offset)
        assert(self.handles[handle], "No such file handle")
        return self.handles[handle].tmpFile:seek(whence, offset)
    end

    function self.read(handle, count)
        return self.handles[handle].tmpFile:read(count)
    end

    function self.write(handle, value)
        return self.handles[handle].tmpFile:write(value)
    end

    function self.close(handle)
        assert(self.handles[handle], "No such file handle")
        --close the tmp file
        self.handles[handle].tmpFile:close()
        -- reopen the tmp file
        local tFile = io.open(self.handles[handle].tmpFilePath, "r")
        assert(tFile, "Could not open temporary file")
        --open the encrypted file
        local eFile = self.rawFS.open(self.handles[handle].path, "wb")
        self.rawFS.write(eFile, data.encrypt(tFile:read("*a"), self.aesKey, data.md5(self.rawFS.address)))
        self.rawFS.close(eFile)
        tFile:close()
        fs.remove(self.handles[handle].tmpFilePath)
        self.handles[handle] = nil
    end

    event.listen("component_removed", function(e, a, t) if (a == self.rawFS.address) then fs.umount(self); return false end end)

    return self
end

return crypttool
