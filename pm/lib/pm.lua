local filesystem    = require("filesystem")
local serialization = require("serialization")
local uuid          = require("uuid")
local tar           = require("tar")

---@class manifest
---@field package string
---@field dependencies table<string,string>
---@field configFiles table<number,string>
---@field name string
---@field version string
---@field description string
---@field authors string
---@field note string
---@field hidden string
---@field repo string
---@field archiveName string

local function cleanup(path)
    filesystem.remove(path)
end

local f = string.format

local function printf(...)
    print(f(...))
end

---@class libpm
local pm = {}

---@return manifest
function pm.getManifestFromInstalled(package)
    local file = assert(io.open(f("/etc/pm/info/%s.manifest", package)))
    ---@type manifest
    local currentManifest = serialization.unserialize(file:read("a"))
    file:close()
    return currentManifest
end

---Get the manifest from the package
---@param packagePath string
---@return manifest? manifest
---@return string? reason
---@return string? parserError
function pm.getManifestFromPackage(packagePath)
    checkArg(1, packagePath, "string")
    packagePath = filesystem.canonical(packagePath)
    local tmpPath = "/tmp/pm/"
    if (not filesystem.exists(packagePath)) then return nil, "Invalid path" end
    filesystem.makeDirectory("/tmp/pm/")
    repeat
        tmpPath = "/tmp/pm/" .. uuid.next()
    until not filesystem.isDirectory(tmpPath)
    filesystem.makeDirectory(tmpPath)
    local ok, reason = tar.extract(packagePath, tmpPath, true, "CONTROL/manifest", nil, "CONTROL/")
    local filepath = tmpPath .. "/manifest"

    if (not filepath) then
        return nil, f("Invalid package format")
    end
    local manifestFile = assert(io.open(filepath, "r"))
    local manifest
    manifest, reason = serialization.unserialize(manifestFile:read("a"))
    if (not manifest) then
        return nil, f("Invalid package manifest. Could not parse"), reason
    end
    cleanup(tmpPath)
    return manifest
end

---get the list of installed packages
---@param includeNonPurged? boolean
---@return table<string,manifest>
function pm.getInstalled(includeNonPurged)
    checkArg(1, includeNonPurged, 'boolean', 'nil')
    local prefix = "%.files$"
    if (includeNonPurged) then prefix = "%.manifest$" end
    local installed = {}
    for file in filesystem.list("/etc/pm/info/") do
        local pacakgeName = file:match("(.+)" .. prefix)
        if (pacakgeName) then
            installed[pacakgeName] = pm.getManifestFromInstalled(pacakgeName)
        end
    end
    return installed
end

---@param package string
---@return boolean installed, boolean notPurged
function pm.isInstalled(package)
    local installed = filesystem.exists(f("/etc/pm/info/%s.files", package))
    local notPurged = filesystem.exists(f("/etc/pm/info/%s.manifest", package))
    return installed and notPurged, notPurged
end

---check if a installed package depend of the package
---@return boolean,string?
function pm.checkDependant(pacakge)
    printf("Checking for package dependant of %s", pacakge)
    for pkg, manifest in pairs(pm.getInstalled(false)) do
        ---@cast pkg string
        ---@cast manifest manifest
        if (manifest.dependencies and manifest.dependencies[pacakge]) then
            return true, pkg
        end
    end
    return false
end

---Get the list of package that depend on the provided package
---@param package string
---@return table
function pm.getDependantOf(package)
    local dep = {}
    for installedPackageName, installedPackageManifest in pairs(pm.getInstalled(false)) do
        if (installedPackageManifest.dependencies and installedPackageManifest.dependencies[package]) then
            table.insert(dep, installedPackageName)
        end
    end
    return dep
end

return pm
