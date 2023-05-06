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
local SOURCE_DIR          = SOURCE_FILE .. ".d/"
local REPO_MANIFEST_CACHE = CONFIG_DIR .. "manifests.cache"
local AUTO_INSTALLED      = CONFIG_DIR .. "autoInstalled"

--=============================================================================
---@type table<string>,table<progOpts>
local args, opts          = shell.parse(...)
local mode                = table.remove(args, 1)
--=============================================================================

local reposRuntimeCache

--=============================================================================

---@alias progOpts
---| 'autoremove'
---| 'purge'
---| 'allow-same-version'


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
            if (not url:sub(1, 1) ~= "#") then
                table.insert(sources, url)
            end
        end
        file:close()
    end
    if (filesystem.isDirectory(SOURCE_DIR)) then
        for fileName in filesystem.list(SOURCE_DIR) do
            if (fileName:match("%.list$")) then
                file = assert(io.open(SOURCE_DIR .. fileName))
                for url in file:lines() do
                    if (not url:sub(1, 1) ~= "#") then
                        table.insert(sources, 1, url)
                    end
                end
                file:close()
            end
        end
    end
    for i, url in pairs(sources) do
        if (url:match("^https://github.com/")) then
            sources[i] = url:gsub("https://github.com/", "https://raw.githubusercontent.com/"):gsub("/tree/", "/"):gsub("/blob/", "/")
        end
    end
    return sources
end

---@return table<string,table<string,manifest>>
local function getCachedPackageList()
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

---Get a packet manifest from the cache
---@param name string
---@param targetRepo? string
---@return manifest? manifest, string? originRepo
local function getCachedPacketManifest(name, targetRepo)
    for repoName, repo in pairs(getCachedPackageList()) do
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
    local manifest = getCachedPacketManifest(package)
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
    local ready, reason
    repeat
        ready, reason = request.finishConnect()
    until ready or reason
    if (not ready) then
        return nil, reason
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
                local extraDeps = getNotNeededIfUninstalled(dep)
                for _, extraDep in pairs(extraDeps) do
                    if (isAuto(extraDep)) then
                        table.insert(oldDep, extraDep)
                    end
                end
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
    local targetManifest, repoName = getCachedPacketManifest(package)
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
        local notInstalledDep = {}
        for _, dep in pairs(dependances) do
            if (not pm.isInstalled(dep)) then
                table.insert(notInstalledDep, 1, dep)
            end
        end
        if (#notInstalledDep > 0) then printf("Will be installed : %s", table.concat(notInstalledDep, ', ')) end
        for _, dep in pairs(notInstalledDep) do
            printf("Installing non installed dependancie : %s", dep)
            install(dep, true, false)
        end
    end

    if (not opts['dry-run']) then
        --install the package
        filesystem.makeDirectory(DOWNLOAD_DIR)
        --download
        printf("Downloading : %s", package)
        local data, reason = wget(f("%s/%s", repoName, targetManifest.archiveName))
        if (not data) then
            printferr("Failed to download %s", package)
            printferr(reason)
            os.exit(1)
        end
        --write downloaded archive in download dir
        io.open(f("%s/%s", DOWNLOAD_DIR, targetManifest.archiveName), "w"):write(data):close()
        --build opts for pm
        local pmOptions = ""
        if (opts["allow-same-version"]) then
            pmOptions = "--allow-same-version"
        end
        --run pm
        local _, code = shell.execute(f("pm install %s %s", pmOptions, f("%s/%s", DOWNLOAD_DIR, targetManifest.archiveName)))
        --cleanup
        filesystem.remove(f("%s/%s", DOWNLOAD_DIR, targetManifest.archiveName))
        --mark the pacakge as auto if asked for
        if (markAuto) then
            io.open(AUTO_INSTALLED, "a"):write(targetManifest.package .. "\n"):close()
        end
        return code
    end
    return 0
end

local function update()
    local repos = getSources()
    local manifests = {}
    for _, repoURL in pairs(repos) do
        local request = internet.request(repoURL .. "/manifest")
        local ready, reason
        repeat
            ready, reason = request.finishConnect()
        until ready or reason
        if (not ready) then
            printferr("Could not get manifest from %s\ns", repoURL, reason)
            request.close()
        else
            printf("Found repository : %s", repoURL)
            local data = ""
            repeat
                local read = request.read()
                if (read) then data = data .. read end
            until not read
            request.close()
            local pcalled
            pcalled, data = pcall(serialization.unserialize, data)
            if (pcalled == false) then
                printferr("Invalid manifest for %s", repoURL)
            else
                manifests[repoURL] = data
            end
        end
    end
    io.open(REPO_MANIFEST_CACHE, "w"):write(serialization.serialize(manifests)):close()
end

local function printHelp()
    print("pm-get [opts] <mode> [args]")
    print("mode :")
    print("\tinstall <packageFile>")
    print("\tuninstall <packageName>")
    print("\tautoremove")
    print("\tinfo <packageName>|<packageFile>")
    print("\tlist")
    print("\tsources list|add [new source url]")
    print("opts :")
    print("\t--autoremove : also remove dependencies non longer required")
    print("\t--purge : purge removed packages")
    print("\t--allow-same-version : allow the same package version to be installed over the currently installed one")
    print("\t--installed : only list installed packages")
end

--=============================================================================

if (component.isAvailable("internet")) then
    internet = component.internet
else
    printferr("Need a internet card")
end

--Remove uninstalled files from autoInstalled file
if (filesystem.exists(AUTO_INSTALLED)) then
    do
        local tokeep = {}
        for pkg in io.lines(AUTO_INSTALLED) do
            if (pm.isInstalled(pkg)) then table.insert(tokeep, pkg) end
        end
        local file = assert(io.open(AUTO_INSTALLED, 'w'))
        for _, pkg in pairs(tokeep) do file:write(f("%s\n", pkg)) end
        file:close()
    end
end

if (mode == "update") then
    print("Updating repository cache")
    update()
elseif (mode == "list") then
    args[1] = args[1] or ".*"
    for repoName, repo in pairs(getCachedPackageList()) do
        local sortedTable = {}
        for package, _ in pairs(repo) do
            table.insert(sortedTable, package)
        end
        table.sort(sortedTable, function(a, b) return string.lower(a) < string.lower(b) end)
        for i, package in pairs(sortedTable) do
            local manifest = repo[package]
            if (package:match("^" .. args[1])) then
                local installed, notpurged = pm.isInstalled(package)
                if (not opts['installed'] or installed) then
                    local lb = ""
                    if (installed) then
                        lb = '[installed]'
                        if (isAuto(package)) then
                            lb = '[installed, auto]'
                        end
                    elseif (notpurged) then
                        lb = '[config]'
                    end
                    printf("%s (%s) %s", package, manifest.version, lb)
                end
            end
        end
    end
elseif (mode == "info") then
    local manifest, repoName = getCachedPacketManifest(args[1])
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
        if (#oldDep > 0) then printf("The following dependances are no longer required and will be uninstalled : %s", table.concat(oldDep, ', ')) end
    end
    --TODO : ask for confirmation
    --uninstallation
    local options = ""
    if (opts.purge) then options = options .. " --purge" end
    shell.execute(f("pm uninstall %s %s", options, args[1]))
    for _, dep in pairs(oldDep) do
        shell.execute(f("pm uninstall %s %s", options, dep))
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
    local options = ""
    if (opts.purge) then options = options .. " --purge" end
    for _, dep in pairs(oldDep) do
        shell.execute(f("pm uninstall %s %s", options, dep))
    end
    markManual(args[1])
elseif (mode == "upgrade") then
    local installed = pm.getInstalled(false)
    local toUpgrade = {}
    if (args[1]) then
        if (pm.isInstalled(args[1])) then
            table.insert(toUpgrade, args[1])
            local manifest = assert(pm.getManifestFromInstalled(args[1]))
            if (manifest.dependencies) then
                for dep, ver in pairs(manifest.dependencies) do
                    local remoteManifest = getCachedPacketManifest(dep) --TODO : add target repo
                    local localManifest = pm.getManifestFromInstalled(dep)
                    if (remoteManifest and (remoteManifest.version == "oppm" or compareVersion(remoteManifest.version, localManifest.version) or opts["allow-same-version"])) then
                        table.insert(toUpgrade, dep)
                    end
                end
            end
        end
    else
        for pkg, manifest in pairs(installed) do
            if (manifest.version == "oppm") then
                printf("Found oppm version for %q.", pkg)
                table.insert(toUpgrade, pkg)
            else
                local remoteManifest = getCachedPacketManifest(pkg)
                if (remoteManifest and (remoteManifest.version == "oppm" or compareVersion(remoteManifest.version, manifest.version))) then
                    table.insert(toUpgrade, pkg)
                end
            end
        end
    end
    for _, pkg in pairs(toUpgrade) do
        install(pkg, false)
    end
elseif (mode == "sources") then
    if (args[1] == "list") then
        local sources = getSources()
        for _, s in pairs(sources) do
            print(s)
        end
    elseif (args[1] == "add" and args[2]) then
        --TODO check if exists
        filesystem.makeDirectory(SOURCE_DIR)
        assert(io.open(SOURCE_DIR .. "/custom.list", "a")):write(args[2] .. "\n"):close()
    else
        print("pm-get sources add|list")
    end
else
    printHelp()
    os.exit(0)
end
os.exit(0)
