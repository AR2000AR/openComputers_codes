local shell               = require("shell")
local filesystem          = require("filesystem")
local io                  = require("io")
local component           = require("component")
local serialization       = require("serialization")
local pm                  = require("pm")
---@type ComponentInternet
local internet

--=============================================================================

local DOWNLOAD_DIR        = "/home/.pm-get/" --can't use /tmp as some archive can be bigger than the tmpfs
local CONFIG_DIR          = "/etc/pm/"       --share the config directory with the rest of the package manager
local SOURCE_FILE         = CONFIG_DIR .. "sources.list"
local SOURCE_DIR          = CONFIG_DIR .. SOURCE_FILE .. ".d/"
local REPO_MANIFEST_CACHE = CONFIG_DIR .. "manifests.cache"
local AUTO_INSTALLED      = CONFIG_DIR .. "automaticlyInstalled"

--=============================================================================

local reposRuntimeCache

--=============================================================================


local f = string.format

local function printf(...)
    print(f(...))
end

local function printferr(...)
    io.error():write(f("%s\n", f(...)))
end

---@return table
local function getSources()
    local sources = {}
    local file
    if (filesystem.exists(SOURCE_FILE) and not filesystem.isDirectory(SOURCE_FILE)) then
        file = assert(io.open(SOURCE_FILE))
        for url in file:lines() do
            table.insert(sources, url)
        end
        file:close()
    end
    if (not filesystem.isDirectory(SOURCE_DIR)) then return sources end
    for fileName in filesystem.list(SOURCE_DIR) do
        file = assert(io.open(SOURCE_DIR .. fileName))
        for url in file:lines() do
            table.insert(sources, url)
        end
        file:close()
    end
    return sources
end

local function update()
    local repos = getSources()
    local manifests = {}
    for _, repoURL in pairs(repos) do
        printf("Found repository : %s", repoURL)
        local request = internet.request(repoURL .. "/manifest")
        local ready, pcalled = false, nil
        repeat
            pcalled, ready = pcall(request.finishConnect, request)
        until pcalled == false or ready == true
        if (not pcalled) then
            printferr("Could not get manifest from %s", repoURL)
        end
        local data = ""
        repeat
            local read = request.read()
            if (read) then data = data .. read end
        until not read
        request.close()
        pcalled, data = pcall(serialization.unserialize, data)
        if (pcalled == false) then
            printferr("Invalid manifest for %s", repoURL)
        else
            manifests[repoURL] = data
        end
    end
    io.open(REPO_MANIFEST_CACHE, "w"):write(serialization.serialize(manifests)):close()
end

---@return table<string,table<string,manifest>>
local function getRepoList()
    if (not reposRuntimeCache) then
        if (not filesystem.exists(REPO_MANIFEST_CACHE)) then
            printferr("No data. Run `pm-get upddate` or add repositorys")
            return {}
        end
        local cache = assert(io.open(REPO_MANIFEST_CACHE))
        reposRuntimeCache = serialization.unserialize(cache:read("a"))
        cache:close()
    end
    return reposRuntimeCache
end

---Get a packet manifest from the caceh
---@param name string
---@param targetRepo? string
---@return manifest? manifest, string? originRepo
local function getPacket(name, targetRepo)
    for repoName, repo in pairs(getRepoList()) do
        if (not targetRepo or repoName == targetRepo) then
            if (repo[name]) then
                return repo[name], repoName
            end
        end
    end
    return nil, nil
end

---@param package string
---@return table<number,string>? dep ordered list of dependances
---@return string? error
local function buildDepList(package)
    local dependances = {}
    local manifest = getPacket(package)
    if (manifest) then
        if (manifest.dependencies) then
            for dep, ver in pairs(manifest.dependencies) do
                table.insert(dependances, dep)
                local extraDeps, reason = buildDepList(dep)
                if (extraDeps) then
                    for _, dep2 in pairs(extraDeps) do
                        table.insert(dependances, dep2)
                    end
                else
                    return nil, f("Cannot fuffil dependancie %s for %s", dep, package)
                end
            end
        end
    end
    --TODO : filter dependances to remove duplicates
    return dependances
end

---Download from url and return it
---@param url any
---@return string? data, string? reason
local function wget(url)
    local request = internet.request(url)
    local pcalled, ready
    repeat
        pcalled, ready = pcall(request.finishConnect, request)
    until pcalled == false or ready == true
    if (pcalled == false) then
        return nil, "Could not connect to " .. url
    end
    local data = ""
    repeat
        local read = request.read()
        if (read) then data = data .. read end
    until not read
    request.close()
    return data, nil
end

local function isAuto(package)
    local auto = false
    for line in io.lines(AUTO_INSTALLED) do
        if (line == package) then
            auto = true
        end
    end
    return auto
end

local function markManual(package)
    local auto = {}
    if (not filesystem.exists(AUTO_INSTALLED)) then return end
    for line in io.lines(AUTO_INSTALLED) do
        if (line ~= package) then table.insert(auto, line) end
    end
    local autoFile = assert(io.open(AUTO_INSTALLED, 'w'))
    for _, pk in pairs(auto) do
        autoFile:write(pk .. "\n")
    end
    autoFile:close()
end

local function getNotNeededIfUninstalled(package)
    local oldDep = {}
    local manifest = pm.getManifestFromInstalled(package)
    if (manifest.dependencies) then
        for dep, ver in pairs(manifest.dependencies) do
            if (#(pm.getDependantOf(dep)) == 1 and isAuto(dep)) then
                table.insert(oldDep, dep)
            end
        end
    end
    return oldDep
end

---Return true if version number a is strictly higher than b.
local function compareVersion(a, b)
    local aMajor, aMinor, aPatch = a:match("(%d+)%.(%d+)%.(%d+)")
    local bMajor, bMinor, bPatch = b:match("(%d+)%.(%d+)%.(%d+)")
    if (aMajor > bMajor) then return true elseif (aMajor < bMajor) then return false end
    if (aMinor > bMinor) then return true elseif (aMinor < bMinor) then return false end
    if (aPatch > bPatch) then return true elseif (aPatch < bPatch) then return false end
    return false --equal
end

--=============================================================================

---@param package string
---@param markAuto? boolean
---@param buildDepTree? boolean
local function install(package, markAuto, buildDepTree)
    if (buildDepTree == nil) then buildDepTree = true end
    local targetManifest, repoName = getPacket(package)
    --check that the packet exists
    if (not targetManifest) then
        printferr("Package %s not found", package)
        os.exit(1)
    end
    if (buildDepTree) then
        local dependances, reason = buildDepList(package)
        if (not dependances) then
            printferr(reason)
            os.exit(1)
        end
        for _, dep in pairs(dependances) do
            if (not pm.isInstalled(dep)) then
                printf("Installing non installed dependancie : %s", dep)
                install(dep, true, false)
            end
        end
    end
    filesystem.makeDirectory(DOWNLOAD_DIR)
    printf("Downloading : %s", package)
    local data, reason = wget(f("%s/%s", repoName, targetManifest.archiveName))
    if (not data) then
        printferr("Failed to download %s", package)
        printferr(reason)
        os.exit(1)
    end
    io.open(f("%s/%s", DOWNLOAD_DIR, targetManifest.archiveName), "w"):write(data):close()
    local _, code = shell.execute(f("pm install %s", f("%s/%s", DOWNLOAD_DIR, targetManifest.archiveName)))
    filesystem.remove(f("%s/%s", DOWNLOAD_DIR, targetManifest.archiveName))
    if (markAuto) then
        io.open(AUTO_INSTALLED, "a"):write(targetManifest.package):close()
    end
    return code
end

--=============================================================================

if (component.isAvailable("internet")) then
    internet = component.internet
else
    printferr("Need a internet card")
end

do
    local tokeep = {}
    for pkg in io.lines(AUTO_INSTALLED) do
        if (pm.isInstalled(pkg)) then table.insert(tokeep, pkg) end
    end
    local file = assert(io.open(AUTO_INSTALLED, 'w'))
    for _, pkg in pairs(tokeep) do file:write(f("%s\n", pkg)) end
    file:close()
end

local args, opts = shell.parse(...)
local mode = table.remove(args, 1)

if (mode == "update") then
    print("Updating repository cache")
    update()
elseif (mode == "list") then
    args[1] = args[1] or ".*"
    for repoName, repo in pairs(getRepoList()) do
        for package, manifest in pairs(repo) do
            if (package:match("^" .. args[1])) then
                printf("%s (%s)", package, manifest.version)
            end
        end
    end
elseif (mode == "info") then
    local manifest, repoName = getPacket(args[1])
    if (not manifest) then
        printferr("Package %s not found", args[1])
        os.exit(1)
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
    printf("Repo : %s", repoName)
    os.exit(0)
elseif (mode == "install") then
    markManual(args[1])
    --TODO : check version
    install(args[1])
    os.exit(0)
elseif (mode == "uninstall") then
    if (not pm.isInstalled(args[1])) then
        printf("Package not installed : %s", args[1])
        os.exit(0)
    end
    local oldDep = {}
    if (opts.autoremove) then
        for _, dep in pairs(getNotNeededIfUninstalled(args[1])) do
            if (isAuto(dep)) then
                table.insert(oldDep, dep)
            end
        end
    end
    --TODO : ask for confirmation
    --uninstallation
    shell.execute(f("pm uninstall %s", args[1]))
    for _, dep in pairs(oldDep) do
        shell.execute(f("pm uninstall %s", dep))
    end
    markManual(args[1])
elseif (mode == "autoremove") then
    local oldDep = {}
    if (filesystem.exists(AUTO_INSTALLED)) then
        for package in io.lines(AUTO_INSTALLED) do
            if (#pm.getDependantOf(package) == 0) then
                table.insert(oldDep, package)
            end
        end
    end
    --TODO : ask for confirmation
    --uninstallation
    for _, dep in pairs(oldDep) do
        shell.execute(f("pm uninstall %s", dep))
        markManual(dep)
    end
elseif (mode == "upgrade") then
    local installed = pm.getInstalled(false)
    local toUpgrade = {}
    for pkg, manifest in pairs(installed) do
        if (manifest.version == "oppm") then
            printf("Found oppm version for %q.", pkg)
            table.insert(toUpgrade, pkg)
        else
            local remoteManifest = getPacket(pkg)
            if (remoteManifest and compareVersion(remoteManifest.version, manifest.version)) then
                table.insert(toUpgrade, pkg)
            end
        end
    end
    for _, pkg in pairs(toUpgrade) do
        install(pkg, false)
    end
end
