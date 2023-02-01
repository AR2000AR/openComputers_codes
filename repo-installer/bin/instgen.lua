local serial = require "serialization"
local internet = require("component").internet
local fs = require "filesystem"
local os = require "os"

local tArgs = {...}
local src, dest = tArgs[1], tArgs[2] .. "/"

local _OSVERSION = _OSVERSION or ""

local header = {["User-Agent"] = "oc-instgen"}
if (os.getenv("HTTP_BASIC")) then
    header.Authorization = "Basic " .. os.getenv("HTTP_BASIC")
end

local function normalisePath(path)
    local pt = {}
    for seg in path:gmatch("[^/]+") do
        seg = seg:gsub("?master", "master"):gsub(":master", "master")
        pt[#pt+1] = seg
    end
    local pre = ""
    if path:sub(1, 1) == "/" then
        pre = "/"
    end
    return pre .. table.concat(pt, "/")
end

local function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

-- Return a list of file in a folder. Recursive
-- @param github url
-- @return table of github raw files url
local function parseFolders(pack, repo, info)
    print(string.format("Package : %q", pack))
    local function getContent(url)
        -- https://github.com/MightyPirates/OpenComputers/blob/1c0dc67182292895495cb0d421ec0f529d243d74/src/main/resources/assets/opencomputers/loot/oppm/usr/bin/oppm.lua#L48-L58
        local sContent = ""
        local result, reason = internet.request(url, nil, header)
        --wait for the connexion to exists
        if (not result) then
            error(reason, 2)
        end
        repeat
            os.sleep(0)
            local s, c, reason = pcall(result.finishConnect)
            if  (not s) then
                error(c, 2)
            elseif (c == nil) then
                error(reason, 2)
            end
        until s and c
        -- get the status code and headers
        local status, _, headers = result.response()
        -- read the response
        repeat
            local data, reason = result.read()
            if  not data then
                result.close()
                if reason then
                    error(reason, 2)
                end
            elseif (#data > 0) then
                sContent = sContent .. data
            end
            os.sleep(0)
        until data == nil --eof
        return sContent, status, headers
    end

    --https://github.com/MightyPirates/OpenComputers/blob/1c0dc67182292895495cb0d421ec0f529d243d74/src/main/resources/assets/opencomputers/loot/oppm/usr/bin/oppm.lua#L243-L302
    --modified to handle rate limit
    local function getFolderTable(repo, namePath, branch)
        --check rate limit
        repeat
            local sucess, reason, _, headers = pcall(getContent, "https://api.github.com/rate_limit")
            if (not sucess) then error("Failed to request guihub rate limit info :\n" .. tostring(reason), 2) end
            if (tonumber(headers["X-RateLimit-Remaining"][1]) == 0) then
                print(string.format("No more API request available. More call will be possible at %s", os.date("%H:%M:%S", headers["X-RateLimit-Reset"])))
                print("Waiting 1 minute")
                os.sleep(60)
            end
        until tonumber(headers["X-RateLimit-Remaining"][1]) > 0

        --call the api
        local success, filestring, _, headers = pcall(getContent, "https://api.github.com/repos/" .. repo .. "/contents/" .. namePath .. "?ref=" .. branch)
        ---@diagnostic disable-next-line: need-check-nil
        if not success or filestring:find('"message": "Not Found"') then
            if (not success) then print(filestring) end
            io.stderr:write("Error while trying to parse folder names in declaration of package " .. pack .. ".\n")
            ---@diagnostic disable-next-line: need-check-nil
            if filestring:find('"message": "Not Found"') then
                io.stderr:write("Folder " .. namePath .. " does not exist.\n")
            else
                io.stderr:write(filestring .. "\n")
            end
            io.stderr:write("Please contact the author of that package.\n")
            return nil
        end
        assert(filestring)
        return serial.unserialize(filestring:gsub("%[", "{"):gsub("%]", "}"):gsub("(\"[^%s,]-\")%s?:", "[%1] = "))
    end

    local function nonSpecial(text)
        return text:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    end

    local function unserializeFiles(files, repo, namePath, branch, relPath)
        if not files then return nil end
        local tFiles = {}
        for _, v in pairs(files) do
            if  v["type"] == "file" then
                local newPath = v["download_url"]:gsub("https?://raw.githubusercontent.com/" .. nonSpecial(repo) .. "(.+)$", "%1"):gsub("/*$", ""):gsub("^/*", "")
                tFiles[newPath] = relPath
            elseif v["type"] == "dir" then
                local newFiles = unserializeFiles(getFolderTable(repo, v["path"], branch), repo, namePath, branch, fs.concat(relPath, v["name"]))
                ---@diagnostic disable-next-line: need-check-nil, param-type-mismatch
                for p, q in pairs(newFiles) do
                    tFiles[p] = q
                end
            end
        end
        return tFiles
    end

    local newInfo = deepcopy(info)
    for i, j in pairs(info.files) do
        if string.find(i, "^:") then
            local iPath = i:gsub("^:", "")
            local branch = string.gsub(iPath, "^(.-)/.+", "%1"):gsub("/*$", ""):gsub("^/*", "")
            local namePath = string.gsub(iPath, ".-(/.+)$", "%1"):gsub("/*$", ""):gsub("^/*", "")
            local absolutePath = j:find("^//")

            local files = unserializeFiles(getFolderTable(repo, namePath, branch), repo, namePath, branch, j:gsub("^//", "/"))
            if not files then return nil end
            for p, q in pairs(files) do
                if absolutePath then
                    newInfo.files[p] = "/" .. q
                else
                    newInfo.files[p] = q
                end
            end
            newInfo.files[i] = nil
        end
    end
    return newInfo
end

local function wget(src, dest)
    src = src:gsub("?master", "master"):gsub(":master", "master")
    dest = normalisePath(dest)
    local fstr = "wget '%s' -qO '%s'"
    local command = string.format(fstr, src, dest)
    return os.execute(command)
end

local dirs = {}
local function mkdir(path)
    path = normalisePath(path)
    if dirs[path] then return true end
    local fstr = "mkdir -p '%s'"
    if _OSVERSION:sub(1, 6) == "OpenOS" then
        fstr = "mkdir '%s'"
    end
    local command = string.format(fstr, path)
    dirs[path] = true
    return os.execute(command)
end

local function parsecfg(path)
    path = normalisePath(path)
    local f = io.open(path, "rb")
    if not f then error("unable to open " .. tostring(path) .. " for parsing") end
    local rt = serial.unserialize(f:read("*a"))
    f:close()
    if type(rt) ~= "table" then error("unable to parse " .. tostring(path)) end
    return rt
end

local function writecfg(t, path)
    path = normalisePath(path)
    local f = io.open(path, "wb")
    if not f then error("unable to open " .. tostring(path) .. " for writing") end
    f:write(serial.serialize(t))
    f:close()
end

if (not src:match("^https?://")) then src = "https://raw.githubusercontent.com/" .. src .. "/master/programs.cfg" end
local pathpre = src:match("(.+/).+/.+")
local repoName = src:match("https?://raw.githubusercontent.com/([^/]+/[^/]+)/.+")

mkdir(dest .. "/master/")
local pcfgname = os.tmpname()
wget(src, pcfgname)
local programs = parsecfg(pcfgname)
os.execute("rm '" .. pcfgname .. "'")

local dlfiles = {}
for k, v in pairs(programs) do
    v = parseFolders(k, repoName, v)
    assert(v, "v should not be nil")
    if v.files then
        for l, m in pairs(v.files) do
            dlfiles[#dlfiles+1] = l
        end
    end
end

print("Downloading...")
for k, v in pairs(dlfiles) do
    local path, fn = v:match("(.+)/(.+)")
    if v:sub(1, 4) ~= "http" then
        mkdir(dest .. path)
        wget(pathpre .. v, dest .. v)
    else
        mkdir(dest .. "/external")
        wget(v, dest .. "/external/" .. fn)
    end
end

-- merge programs.cfg with existing if applicable

local w, oprograms = pcall(parsecfg, dest .. "/master/programs.cfg")
if w then
    for k, v in pairs(oprograms) do
        programs[k] = programs[k] or v
    end
end

writecfg(programs, dest .. "/master/programs.cfg")

local prop = {label = repoName}
fs.copy("/usr/misc/repo-installer/repoinstaller.lua", dest .. "/.install")
if (fs.exists(dest .. "/.prop")) then
    local propFile = io.open(dest .. "/.prop", "r")
    assert(propFile, "Existing file could not be open ???")
    prop = serial.unserialize(propFile:read("a"))
    propFile:close()
    prop.label = "repoinstaller"
end
local propFile = io.open(dest .. "/.prop", "w")
assert(propFile, "Could not open file ???")
propFile:write(serial.serialize(prop))
propFile:close()
