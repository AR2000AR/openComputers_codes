local shell         = require("shell")
local filesystem    = require("filesystem")
--local tar           = require("tar")
local tar           = dofile("/usr/lib/tar.lua")
local uuid          = require("uuid")
local os            = require("os")
local io            = require("io")
local serialization = require("serialization")


---@class manifest
---@field package string
---@field dependencies table
---@field configFiles table
---@field name string
---@field version string
---@field description string
---@field authors string
---@field note string
---@field hidden string
---@field repo string

local RM_BLACKLIST = {
    ["/bin/"] = true,
    ["/boot/"] = true,
    ["/dev/"] = true,
    ["/etc/"] = true,
    ["/etc/rd.d"] = true,
    ["/home/"] = true,
    ["/lib/"] = true,
    ["/mnt/"] = true,
    ["/tmp/"] = true,
    ["/usr/"] = true,
    ["/usr/lib/"] = true,
    ["/usr/bin/"] = true,
}

local args, opts = shell.parse(...)

local f = string.format

local function printf(...)
    print(f(...))
end

local function printHelp()
    printf("pm [opts] <mode> [args]")
    printf("mode :")
    printf("\tinstall <packageFile>")
    printf("\tuninstall <packageName>")
    printf("\tinfo <packageName>|<packageFile>")
    printf("\tlist-installed")
    printf("opts :")
    printf("\t--purge : remove configuration files")
    printf("\t--dry-run : do not really perform the operation")
    printf("\t--include-removed : also list non completly removed packages")
    printf("\t--allow-same-version : allow a package of the same version to be used for to update the installed version")
end

local function cleanup(path)
    filesystem.remove(path)
end

---@return manifest
local function getManifestFromInstalled(package)
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
local function getManifestFromPackage(packagePath)
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

---Extract the package tar and return the extracted path
---@param packagePath string
---@return boolean? ok, string? reason
local function extractPackage(packagePath)
    checkArg(1, packagePath, "string")
    if (opts["dry-run"]) then return true, nil end
    packagePath = filesystem.canonical(packagePath)
    printf("extracting : %s", packagePath)
    return tar.extract(packagePath, "/", false, "DATA/", nil, "DATA/")
end

---get the list of installed packages
---@param includeNonPurged? boolean
---@return table<string,manifest>
local function getInstalled(includeNonPurged)
    checkArg(1, includeNonPurged, 'boolean', 'nil')
    local prefix = "%.files$"
    if (includeNonPurged) then prefix = "%.manifest$" end
    local installed = {}
    for file in filesystem.list("/etc/pm/info/") do
        local pacakgeName = file:match("(.+)" .. prefix)
        if (pacakgeName) then
            installed[pacakgeName] = getManifestFromInstalled(pacakgeName)
        end
    end
    return installed
end

---@param package string
---@return boolean installed, boolean notPurged
local function isInstalled(package)
    local installed = filesystem.exists(f("/etc/pm/info/%s.files", package))
    local notPurged = filesystem.exists(f("/etc/pm/info/%s.manifest", package))
    return installed and notPurged, notPurged
end

---check if a install package depend of the package
---@return boolean,string?
local function checkDependant(pacakge)
    printf("Checking for package dependant of %s", pacakge)
    for pkg, manifest in pairs(getInstalled(false)) do
        ---@cast pkg string
        ---@cast manifest manifest
        if (manifest.dependencies and manifest.dependencies[pacakge]) then
            return true, pkg
        end
    end
    return false
end

local function rm(...)
    local cmd = f("rm -f %s", table.concat({...}, " "))
    if (opts["dry-run"]) then
        print(cmd)
    else
        shell.execute(cmd)
    end
end

local function rmdir(...)
    local cmd = f("rmdir %s", table.concat({...}, " "))
    if (opts["dry-run"]) then
        print(cmd)
    else
        shell.execute(cmd)
    end
end

---Return true if version number a is higher than b. Still return true when equals
local function compareVersion(a, b)
    local aMajor, aMinor, aPatch = a:match("(%d+)%.(%d+)%.(%d+)")
    local bMajor, bMinor, bPatch = b:match("(%d+)%.(%d+)%.(%d+)")
    if (aMajor > bMajor) then return true elseif (aMajor < bMajor) then return false end
    if (aMinor > bMinor) then return true elseif (aMinor < bMinor) then return false end
    if (aPatch > bPatch) then return true elseif (aPatch < bPatch) then return false end
    return true --equal
end

--=============================================================================

local mode = table.remove(args, 1)

if (mode == "info") then
    local manifest
    if (args[1]:match("%.tar$")) then
        args[1] = shell.resolve(args[1])
        local r, rr
        manifest, r, rr = getManifestFromPackage(args[1])
        if (not manifest) then
            printf("Error : %s, %s", r, rr or "")
            os.exit(1)
        end
    else
        if (isInstalled(args[1])) then
            manifest = getManifestFromInstalled(args[1])
        else
            printf("Could not find package named %q", args[1])
            os.exit(1)
        end
    end

    printf("Name : %s (%s)", manifest.name, manifest.package)
    printf("Version : %s", manifest.version)
    if (manifest.description) then printf("Description : \n%s", manifest.description) end
    if (manifest.note) then printf("Note :\n%s", manifest.note) end
    if (manifest.authors) then printf("Authors : %s", manifest.authors) end
    if (manifest.dependencies) then
        print("Dependencies :")
        for name, version in pairs(manifest.dependencies) do
            printf("%s (%s)", name, version)
        end
    end
    os.exit(0)
elseif (mode == "list-installed") then
    for name, manifest in pairs(getInstalled(opts["include-removed"])) do
        if (opts["include-removed"]) then
            local installed, removed = isInstalled(name)
            local label = "installed"
            if (not installed and removed) then label = "config remaining" end
            printf("%s (%s) [%s]", name, manifest.version, label)
        else
            printf("%s (%s)", name, manifest.version)
        end
    end
elseif (mode == "install") then
    --get the pacakge file absolute path
    args[1] = shell.resolve(args[1])

    --get the manifest from the package
    local manifest, r, rr = getManifestFromPackage(args[1])
    if (not manifest) then
        printf("Invalid package")
        os.exit(1)
    end

    --check if the package is already installed
    if (isInstalled(manifest.package)) then
        local currentManifest = getManifestFromInstalled(manifest.package)
        if (manifest.version == "oppm" or currentManifest.version == "oppm") then
            --do nothing. We force reinstallation for oppm since there is no version number
        elseif (manifest.version == currentManifest.version and not opts["allow-same-version"]) then
            print("Already installed")
            os.exit(0)
        elseif (compareVersion(currentManifest.version, manifest.version)) then --downgrade
            print("Cannot downgrade package")
            os.exit(1)
        end
    end

    --check the pacakge's dependencies
    if (manifest.dependencies) then
        for dep, version in pairs(manifest.dependencies) do
            if (not isInstalled(dep)) then
                printf("Missing dependencie : %s (%s)", dep, version)
                os.exit(1)
            end
            local compType = version:match("^[<>=]") or ">"
            version = version:match("%d.*$")
            local installedVersion = getManifestFromInstalled(dep).version
            if (installedVersion == "oppm") then
                printf("Warning : %s is using a oppm version. Cannot determine real installed version", dep)
            else
                if (compType == "=") then
                    if (not version == installedVersion) then
                        printf("Package %s require %s version %s but %s is installed", manifest.package, dep, version, installedVersion)
                        os.exit(1)
                    end
                elseif (compType == "<") then
                    if (compareVersion(version, installedVersion)) then
                        printf("Package %s require %s version %s but %s is installed", manifest.package, dep, version, installedVersion)
                        os.exit(1)
                    end
                else
                    if (compareVersion(version, installedVersion) and version ~= installedVersion) then
                        printf("Package %s require %s version %s but %s is installed", manifest.package, dep, version, installedVersion)
                        os.exit(1)
                    end
                end
            end
        end
    end

    --make the values the keys for easier test later
    local configFiles = {}
    if (manifest.configFiles) then
        for _, file in pairs(manifest.configFiles) do
            configFiles[file] = true
        end
    end

    --check that no file not from the package get overwriten
    for _, header in pairs(assert(tar.list(args[1]))) do
        if (header.name:match("^/DATA/") and header.typeflag == "file") then
            local destination = header.name:sub(#("/DATA/"))
            --TODO : ignore config files
            if (filesystem.exists(destination)) then
                printf("File already exists %s", destination)
                os.exit(1)
            end
        end
    end

    --uninstall old version. It's easier than to check wich file need to be deleted
    if (isInstalled(manifest.package)) then
        shell.execute(f("pm uninstall %q --no-dependencies-check", args[1]))
    end

    --extract the files in the correct path
    local extracted, reason = extractPackage(args[1])
    if (not extracted) then
        printf("\27[37m%s\27[m", reason or "Unkown error")
        os.exit(1)
    end

    --save the package info and file list
    if (not opts["dry-run"]) then
        filesystem.makeDirectory("/etc/pm/info/")
        local listFile = assert(io.open(f("/etc/pm/info/%s.files", manifest.package), "w"))
        for _, header in pairs(assert(tar.list(args[1]))) do
            if (header.name:match("^DATA")) then
                local name = header.name:match("DATA(.*)")
                if (name and name ~= "") then listFile:write(name .. "\n") end
            end
        end
        listFile:close()
        assert(tar.extract(args[1], "/tmp/pm/", true, "CONTROL/manifest", nil, "CONTROL/"))
        filesystem.rename("/tmp/pm/manifest", f("/etc/pm/info/%s.manifest", manifest.package))
    end

    --remove the tmp folder
    --cleanup(extracted)
elseif (mode == "uninstall") then
    --check if the package exists
    if (not isInstalled(args[1])) then
        printf("Package %q is not installed", args[1])
        os.exit(0)
    end

    local manifest = getManifestFromInstalled(args[1])

    --check dep
    local cantUninstall, dep = checkDependant(args[1])
    if (not opts["no-dependencies-check"] and cantUninstall) then
        printf("Cannot uninstall %s. One or more package (%s) depend on it.", args[1], dep)
        os.exit(1)
    end

    printf("Uninstalling : %s", args[1])

    --make the values the keys for easier test later
    local configFiles = {}
    if (manifest.configFiles) then
        for _, file in pairs(manifest.configFiles) do
            configFiles[file] = true
            require("event").onError(file)
        end
    end

    local fileListFile = assert(io.open(f("/etc/pm/info/%s.files", args[1])))
    local dirs = {}
    --delete the files
    for path in fileListFile:lines() do
        if (not configFiles[path] or opts.purge) then
            if (not filesystem.isDirectory(path)) then
                rm(f("%q", path))
            else
                if (path and path ~= "/" and path ~= "") then
                    table.insert(dirs, 1, path)
                end
            end
        end
    end
    fileListFile:close()
    --delete empty directory left behind
    for _, dir in pairs(dirs) do
        if (not RM_BLACKLIST[dir]) then
            rmdir(f("%q", dir))
        end
    end
    rm(f("%q", f("/etc/pm/info/%s.files", args[1])))
    if (opts.purge) then rm(f("%q", f("/etc/pm/info/%s.manifest", args[1]))) end
else
    printHelp()
    os.exit(0)
end
