local shell               = require("shell")
local filesystem          = require("filesystem")
local io                  = require("io")
local component           = require("component")
local serialization       = require("serialization")
local pm                  = require("pm")
local term                = require("term")
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

local function tableMergeUniq(target, source)
    local newElements = {}
    for _, v in pairs(source) do
        local new = true
        for _, vv in pairs(target) do
            if v == vv then
                new = false
                break
            end
        end
        if (new) then table.insert(newElements, v) end
    end
    for _, v in pairs(newElements) do table.insert(target, v) end
end

local function printf(...)
    print(f(...))
end

local function printferr(...)
    io.error():write(f("%s\n", f(...)))
end

---Compare a with b
---@return -1|0|1 cmp `-1 a<b, 0 a=b, 1 a>b`
local function compareVersion(a, b)
    local aVersion = a:gmatch("%d+")
    local bVersion = b:gmatch("%d+")
    while true do
        local vA = aVersion()
        local vB = bVersion()
        if vA == nil and vB == nil then return 0 end
        vA = tonumber(vA)
        vB = tonumber(vB)
        if vA == nil then vA = 0 end
        if vB == nil then vB = 0 end
        if (vA > vB) then return 1 elseif (vA < vB) then return -1 end
    end
end

---Check if the pkg version is compatible with dep
---@param dep string
---@param pkg string
---@return boolean
local function checkDepVersion(dep, pkg)
    checkArg(1, dep, 'string')
    checkArg(2, pkg, 'string')
    if (dep == "oppm" or dep == "") then return true end
    if (dep:sub(1, 1) == ">") then
        return compareVersion(pkg, dep:sub(2, -1)) <= 0
    elseif (dep:sub(1, 1) == "=") then
        return compareVersion(pkg, dep:sub(2, -1)) == 0
    end
    error(f("Something went wrong with dep=%q and pkg=%q", dep, pkg))
end

local function confirm(prompt, default)
    if (opts["y"]) then return true end
    while true do
        local y = default and "Y" or "y"
        local n = default and "n" or "N"
        term.write(f("%s [%s/%s] ", prompt, y, n))
        local op = term.read()
        require("event").onError(op)
        if op == false or op == nil then return false end
        if op == "\n" and default then return true end
        if op == "\n" and not default then return false end
        if op == "y\n" or op == "Y\n" then return true end
        if op == "n\n" or op == "N\n" then return false end
    end
end

---Return the sources list
---@param raw? boolean
---@return table
local function getSources(raw)
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
    if (not raw) then
        for i, url in pairs(sources) do
            if (url:match("^https://github.com/")) then
                sources[i] = url:gsub("https://github.com/", "https://raw.githubusercontent.com/"):gsub("/tree/", "/"):gsub("/blob/", "/")
            end
        end
    end
    return sources
end

---@return table<string,table<string,manifest>>
local function getCachedPackageList()
    if (not reposRuntimeCache) then
        if (not filesystem.exists(REPO_MANIFEST_CACHE)) then
            printferr("No data. Run `pm-get update` or add repository")
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
local function getCachedPackageManifest(name, targetRepo)
    for repoName, repo in pairs(getCachedPackageList()) do
        if (not targetRepo or repoName == targetRepo) then
            if (repo[name]) then
                return repo[name], repoName
            end
        end
    end
    return nil, nil
end

---@param package string|table
---@param resolved? table<number,table> Current dependency list.
---@return table<number,table>? dep ordered list of dependency
---@return string? error
local function resolveDepTree(package, resolved)
    if (type(package) == "string") then package = {package, "oppm"} end
    if not resolved then resolved = {} end
    local packageManifest = getCachedPackageManifest(package[1])
    if (not packageManifest) then return nil, string.format("Package %q cannot be found", package) end
    if (packageManifest.dependencies) then
        for dep, requiredVersion in pairs(packageManifest.dependencies) do
            local new = -1
            for i, v in pairs(resolved) do
                if (v[1] == dep) then
                    new = i
                    break
                end
            end
            if (new == -1) then
                resolveDepTree({dep, requiredVersion}, resolved)
            elseif (compareVersion(resolved[new][2], requiredVersion:sub(2, -1)) < 0) then
                resolved[new][2] = requiredVersion
            end
            table.insert(resolved, package)
        end
    end
    return resolved
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
    if (not filesystem.exists(AUTO_INSTALLED)) then return false end
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

local function needUpgrade(pkg)
    local remoteManifest = getCachedPackageManifest(pkg)
    if not remoteManifest then return false end
    local localManifest = pm.getManifestFromInstalled(pkg)
    if not localManifest then return false end
    if remoteManifest.version == "oppm" or localManifest == "oppm" then return true end
    if compareVersion(remoteManifest.version, localManifest.version) > 0 then return true end
    if compareVersion(remoteManifest.version, localManifest.version) == 0 and opts["allow-same-version"] then return true end
    return false
end

---List the packages than can be upgraded
---@return table
local function listNeedUpgrade()
    local canBeUpgraded = {}
    for pkgName in pairs(pm.getInstalled()) do
        if (needUpgrade(pkgName)) then table.insert(canBeUpgraded, pkgName) end
    end
    return canBeUpgraded
end

---Find missing dependencies for the package
---@param pkg string
---@return table<number,string>?, table|string
local function findMissingDep(pkg)
    local missingDep = {}
    local outdatedDep = {}
    ---@type manifest?
    local packageManifest
    if pm.isInstalled(pkg) then
        packageManifest = pm.getManifestFromInstalled(pkg)
    else
        packageManifest = getCachedPackageManifest(pkg)
    end
    if (not packageManifest) then return nil, f("Cannot find dependencies for %s. Package not found", pkg) end

    local resolvedDepTree, msg = resolveDepTree(pkg)
    if (not resolvedDepTree) then
        ---@cast msg -nil
        return nil, msg
    end

    for _, dep in pairs(resolvedDepTree) do
        if (not pm.isInstalled(dep[1])) then
            local manifest = getCachedPackageManifest(dep[1])
            if (not manifest or not checkDepVersion(dep[2], manifest.version)) then
                return nil, f("Cannot fulfil dependency : %s (%s) for %s for (%s)", dep[1], dep[2], pkg, packageManifest.version)
            end
            table.insert(missingDep, dep[1])
        else
            local manifest = pm.getManifestFromInstalled(dep[1])
            if (checkDepVersion(dep[2], manifest.version) == false) then
                ---@diagnostic disable-next-line: cast-local-type
                manifest = getCachedPackageManifest(dep[2])
                if (not manifest or not checkDepVersion(dep[2], manifest.version)) then
                    return nil, f("Cannot fulfil dependency : %s (%s) for %s for (%s)", dep[1], dep[2], pkg, packageManifest.version)
                end
                table.insert(outdatedDep, dep[1])
            end
        end
    end
    return missingDep, outdatedDep
end

--=============================================================================

---Install a package
---@param package string
---@param markAuto boolean
---@return any? code
---@return string? errorReason
local function doInstall(package, markAuto)
    local targetManifest, repoName = getCachedPackageManifest(package)
    if (not targetManifest) then
        return nil, string.format("Cannot find package : %s", package)
    end
    --install the package
    filesystem.makeDirectory(DOWNLOAD_DIR)
    --download
    printf("Downloading : %s", package)
    local data, reason = wget(f("%s/%s", repoName, targetManifest.archiveName))
    if (not data) then
        printferr("Failed to download %s", package)
        printferr(reason)
        return -1, reason
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

---@param packages table|string
---@param markAuto? boolean
---@return number 1=ok,0=nothing done, -1=error
---@return string? error
local function install(packages, markAuto)
    if (type(packages) == "string") then packages = {packages} end
    ---get the dependency list
    local depList, toInstall, toUpgrade = {}, {}, {}
    for _, package in pairs(packages) do
        local targetManifest, repoName = getCachedPackageManifest(package)
        --check that the packet exists
        if (not targetManifest) then
            printferr("Package %s not found", package)
            os.exit(1)
        end
        local newInstall, newUpgrade = findMissingDep(package)
        if (not newInstall) then
            ---@cast newUpgrade -table
            return -1, newUpgrade
        end
        assert(type(newInstall) == "table")
        assert(type(newUpgrade) == "table")
        tableMergeUniq(toInstall, newInstall)
        tableMergeUniq(toUpgrade, newUpgrade)
    end


    local display = {}
    for _, v in pairs(toInstall) do table.insert(display, v) end
    for _, v in pairs(packages) do table.insert(display, v) end
    if (#display > 0) then printf("Will be installed :\n %s", table.concat(display, ', ')) end
    if (#toUpgrade > 0) then printf("Will be updated :\n %s", table.concat(toUpgrade, ', ')) end
    printf("%d upgraded, %d newly installed", #toUpgrade, #display)
    if (#display == 0 and #toUpgrade == 0) then return 0 end
    if not confirm("Proceed") then return 0 end

    if (not opts['dry-run']) then
        for _, dep in pairs(toUpgrade) do
            printf("Updating dependency : %s", dep)
            printf("Installing dependency : %s", dep)
            local code, errorReason = doInstall(dep, true)
            if (errorReason) then
                printferr("Failed to install %q. Giving up.", dep)
                return -1
            end
        end
        for _, dep in pairs(toInstall) do
            printf("Installing dependency : %s", dep)
            local code, errorReason = doInstall(dep, true)
            if (errorReason) then
                printferr("Failed to install %q. Giving up.", dep)
                return -1
            end
        end
        for _, package in pairs(packages) do
            printf("Installing : %s", package)
            local code, errorReason = doInstall(package, false)
            if (errorReason) then
                printferr("Failed to install %q. Giving up.", package)
                return -1
            end
        end
    end
    return 1
end

local function uninstall(packages)
    local toUninstall = {}
    for _, package in pairs(packages) do
        table.insert(toUninstall, package)
    end

    printf("Will be uninstalled :\n %s", table.concat(toUninstall, ', '))

    if not confirm("Proceed") then return end
    --uninstallation
    local options = ""
    if (opts.purge) then options = options .. "--purge" end
    shell.execute(f("pm uninstall %s %s", options, args[1]))
    for _, pkg in pairs(toUninstall) do
        shell.execute(f("pm uninstall %s %s", options, pkg))
        markManual(pkg)
    end

    if (opts["autoremove"]) then
        shell.execute(f("pm-get autoremove -y %s", options))
    end
end

local function update()
    local repos = getSources()
    local manifests = {}
    for _, repoURL in pairs(repos) do
        local data, reason = wget(repoURL .. "/manifest")
        if (not data) then
            printferr("Could not get manifest from %s\ns", repoURL, reason)
        else
            printf("Found repository : %s", repoURL)
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

    printf("%s package(s) can be upgraded", #listNeedUpgrade())
end

local function printHelp()
    print("pm-get [opts] <mode> [args]")
    print("mode :")
    print("\tinstall <packageFile>")
    print("\tuninstall <packageName>")
    print("\tpruge <packageName>")
    print("\tautoremove")
    print("\tupdate : update the package cache")
    print("\tupgrade : apply all upgrades possible")
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
elseif (mode == "update" or mode == "install") then
    printferr("Need a internet card")
    os.exit(1)
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

if (mode == "purge") then
    mode = "uninstall"
    opts["purge"] = true
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
    local manifest, repoName = getCachedPackageManifest(args[1])
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
    if (install(args)) then
        for _, p in pairs(args) do
            markManual(p)
        end
        os.exit(0)
    else
        os.exit(1)
    end
elseif (mode == "uninstall") then
    uninstall(args)
elseif (mode == "autoremove") then
    local oldDep = {}
    if (filesystem.exists(AUTO_INSTALLED)) then
        for package in io.lines(AUTO_INSTALLED) do
            if (#pm.getDependantOf(package) == 0) then
                table.insert(oldDep, package)
            end
        end
    end
    printf("Will be uninstalled :\n %s", table.concat(oldDep, ', '))
    if not confirm("Proceed") then return end
    --uninstallation
    local options = ""
    if (opts.purge) then options = options .. " --purge" end
    for _, dep in pairs(oldDep) do
        shell.execute(f("pm uninstall %s %s", options, dep))
    end
    markManual(args[1])
elseif (mode == "upgrade") then
    local toUpgrade = {}
    if (args[1]) then
        if (pm.isInstalled(args[1])) then
            table.insert(toUpgrade, args[1])
            local manifest = assert(pm.getManifestFromInstalled(args[1]))
            if (manifest.dependencies) then
                for dep, ver in pairs(manifest.dependencies) do
                    if (needUpgrade(dep)) then
                        table.insert(toUpgrade, dep)
                    end
                end
            end
        else
            printf("Package %s is not installed")
            os.exit(1)
        end
    else
        toUpgrade = listNeedUpgrade()
    end
    install(toUpgrade, false)
elseif (mode == "sources") then
    if (args[1] == "list") then
        local sources = getSources()
        for _, s in pairs(sources) do
            print(s)
        end
    elseif (args[1] == "add" and args[2]) then
        local sources = getSources(true)
        local exists = false
        for _, url in pairs(sources) do
            if (url == args[2]) then
                exists = true
                printf("Found %q in the source list. It will not be added again.", args[2])
                break
            end
        end

        if (not exists) then
            filesystem.makeDirectory(SOURCE_DIR)
            assert(io.open(SOURCE_DIR .. "/custom.list", "a")):write(args[2] .. "\n"):close()
            printf("Added %q to the source list", args[2])
        end
    else
        print("pm-get sources add|list")
    end
else
    printHelp()
    os.exit(0)
end
os.exit(0)
