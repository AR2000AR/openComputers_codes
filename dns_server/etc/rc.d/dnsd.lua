local dns           = require("dns")
local serialization = require("serialization")
local filesystem    = require("filesystem")
local io            = require("io")
local ipv4Address   = require("network.ipv4").address
local socket        = require("socket")
local thread        = require("thread")
--=============================================================================
---@alias Resource table<number|string>
---@alias Zone table<string,table<dnsRecordClass,table<dnsRecordType,table<Resource>>>> table<recordName,table<dnsRecordClass,table<dnsRecordType,table<Resource>>>>
---@alias Zones table<string,Zone> table<zoneName,Zone>
--=============================================================================


---@type UDPSocket
local udpSocket
---@type Zones
local zones  = {}
local config = {recursion = false}
local listenerThread

local function printf(...) print(string.format(...)) end

---Load a zone file
---@param path string
---@return Zone,string
local function loadZoneFile(path)
    ---@param fileHandle file*
    ---@return string
    local function readLine(fileHandle)
        local line = ""
        repeat
            line = fileHandle:read("l")
        until not line or line ~= ""
        if (not line) then return line end
        line = line:match("^([^;]+)"):reverse("^%s*(.*)$"):reverse()
        while (line:match("%(") and not line:match("%)")) do
            line = line .. " " .. readLine(fileHandle):match("%s*(.*)$")
        end
        return line
    end

    local parseRdata = {}
    parseRdata[dns.DNSRessourceRecord.TYPE.A] = function(rdata)
        return ipv4Address.fromString(rdata)
    end
    parseRdata[dns.DNSRessourceRecord.TYPE.SOA] = function(rdata)
        rdata = rdata:gsub("%(", " "):gsub("%)", " ")
        local infos = {}
        for info in rdata:gmatch("(%S+)") do
            table.insert(infos, info)
        end
        return infos
    end

    assert(filesystem.exists(path) and not filesystem.isDirectory(path), "zone file not found")
    assert(path:match("%.zone$"), "Not a zone file")

    local file = io.open(path)
    assert(file, "zone file could not be opened")

    ---@type Zone
    local zone = {}
    local zoneName = ""
    local lastDomainName = ""
    ---@type number
    local defaultsTTL = 0
    ---@type dnsRecordClass
    local defaultsClass = nil

    while true do --see 2 lines under for break condition
        local line = readLine(file)
        if (not line) then break end
        if (line:match("^%$")) then
            line = line:sub(2)
            if (line:match("^ORIGIN")) then
                zoneName = line:match("^%S+%s+(%S+)")
            elseif (line:match("^TTL")) then
                defaultsTTL = tonumber(line:match("^%S+%s+(%d+)")) or 0
            end
        else
            ---@type string,dnsRecordType,string
            local name, rtype, rdata
            local ttl = defaultsTTL
            ---@type dnsRecordClass
            local class = defaultsClass
            if (line:match("^%s")) then
                name, line = line:match("^(%s+)(.*)$")
            else
                name, line = line:match("^(%S+)%s+(.*)$")
            end
            if (name:match("^%s+$")) then
                name = lastDomainName
                name = name .. "." .. zoneName
                name = name:gsub("%.%.", ".")
            elseif (name == "@") then
                name = zoneName
                lastDomainName = name
            else
                lastDomainName = name
                name = name .. "." .. zoneName
                name = name:gsub("%.%.", ".")
            end

            --try to get ttl and class twice
            for _ = 0, 1 do
                local tmp = line:match("^%S+")
                if (tonumber(tmp)) then
                    ttl, line = line:match("^(%d+)%s+(.*)")
                    ttl = tonumber(ttl) or defaultsTTL
                    defaultsTTL = ttl
                elseif (dns.DNSHeaderFlags.CLASS[tmp]) then
                    class, line = line:match("^(%S+)%s+(.*)")
                    class = dns.DNSHeaderFlags.CLASS[class]
                    defaultsClass = class
                end
            end
            rtype, rdata = line:match("(%S+)%s+(.*)")
            rtype = dns.DNSRessourceRecord.TYPE[rtype]
            if (parseRdata[rtype]) then rdata = parseRdata[rtype](rdata) end

            zone[name] = zone[name] or {}
            zone[name][class] = zone[name][class] or {}
            zone[name][class][rtype] = zone[name][class][rtype] or {}
            table.insert(zone[name][class][rtype], {ttl, rdata})
        end
    end
    return zone, zoneName
end

---@param rootDir string
---@return Zones
local function loadAllZoneFiles(rootDir)
    local loadedZones = {}
    checkArg(1, rootDir, 'string')
    if (not filesystem.isDirectory(rootDir)) then
        error(string.format("Path %q is not a directory", rootDir), 2)
    end
    for file in filesystem.list(rootDir) do
        if file:match("%.zone$") then
            local zone, zname = loadZoneFile(rootDir .. file)
            loadedZones[zname] = zone
        end
    end
    return loadedZones
end

---Answer a dns question
---@param question DNSQuestion
---@param originalName? string
---@return table<DNSRessourceRecord> answer, table<DNSRessourceRecord> authoritative,table<DNSRessourceRecord> additional, boolean NXDOMAIN
local function answerQuestion(question, originalName)
    if (not originalName) then originalName = question:getName() end
    ---@type DNSRessourceRecord
    local answers, authoritys, additionals, nxdomain = {}, {}, {}, false

    local zName, zone = "", nil
    --Search the available zones for the zone which is the nearest ancestor to QNAME.
    for k, v in pairs(zones) do
        if (question:getName():match(k:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%1") .. "$")) then
            if (#k > #zName) then
                zName = k
                zone = v
            end
        end
    end
    if (not zones[zName]) then return answers, authoritys, additionals, true end

    if (zone[question:getName()]) then
        if (zone[question:getName()][question:getClass()][dns.DNSRessourceRecord.TYPE.NS]) then --If a match would take us out of the authoritative data, we have a referral.  This happens when we encounter a node with NS RRs marking cuts along the bottom of a zone.
            local node = zone[question:getName()][question:getClass()]
            local ressourceRecords = node[dns.DNSRessourceRecord.TYPE.NS]
            for _, rr in pairs(ressourceRecords) do
                table.insert(authoritys, dns.DNSRessourceRecord(question:getName(), question:getClass(), dns.DNSRessourceRecord.TYPE.NS, rr[1], rr[2]))
            end
            ressourceRecords = zone[question:getName()][question:getClass()][question:getType()]
            for _, rr in pairs(ressourceRecords) do
                table.insert(additionals, dns.DNSRessourceRecord(question:getName(), question:getClass(), dns.DNSRessourceRecord.TYPE.NS, rr[1], rr[2]))
            end
        else --If the whole of QNAME is matched, we have found the node.
            local node = zone[question:getName()][question:getClass()]
            if (node[dns.DNSRessourceRecord.TYPE.CNAME] and question:getType() ~= dns.DNSRessourceRecord.TYPE.CNAME) then
                local ressourceRecords = node[dns.DNSRessourceRecord.TYPE.CNAME]
                --If the data at the node is a CNAME, and QTYPE doesn't match CNAME, copy the CNAME RR into the answer section of the response, change QNAME to the canonical name in the CNAME RR, and go back to step 1
                table.insert(answers, dns.DNSRessourceRecord(
                    question:getName(), dns.DNSRessourceRecord.TYPE.CNAME, question:getClass(), ressourceRecords[1][1], ressourceRecords[1][2]))
                local newQuestion = dns.DNSQuestion(ressourceRecords[1][2], question:getType(), question:getClass())
                local answer2, authority2, additionals2, nxdomain2 = answerQuestion(newQuestion, question:getName())
                for _, answer in pairs(answer2) do table.insert(answers, answer) end
                for _, authority in pairs(authority2) do table.insert(authoritys, authority) end
                for _, additional in pairs(additionals2) do table.insert(additionals, additional) end
                nxdomain = nxdomain or nxdomain2
            elseif (node[question:getType()]) then
                local ressourceRecords = node[question:getType()]
                for _, rr in pairs(ressourceRecords) do
                    table.insert(answers, dns.DNSRessourceRecord(question:getName(), question:getType(), question:getClass(), rr[1], rr[2]))
                end
            end
        end
    elseif (zone[question:getName():gsub("^%w+", "*")]) then --If at some label, a match is impossible (i.e., the corresponding label does not exist), look to see if a the "*" label exists.
        local node = zone[question:getName():gsub("^%w+", "*")][question:getClass()]
        if (node) then
            local ressourceRecords = node[question:getType()]
            for _, rr in pairs(ressourceRecords) do
                table.insert(answers, dns.DNSRessourceRecord(question:getName(), question:getType(), question:getClass(), rr[1], rr[2]))
            end
        end
    elseif (not zone[question:getName():gsub("^%w+", "*")] and question:getName() == originalName) then --If the name is original, set an authoritative name error in the response and exit.
        nxdomain = true
    end
    return answers, authoritys, additionals, nxdomain
end

---Handle a dns request
---@param packet string
---@param fromIP string
---@param fromPort number
local function handleMessage(packet, fromIP, fromPort)
    local sucess, dnsMessage = pcall(dns.message.parsePacket, packet)
    ---@type DNSMessage
    local dnsResponse = {header = dns.DNSHeader(dnsMessage.header:getId(), dnsMessage.header:getFlags(), 0, 0, 0, 0), questions = {}, answer = {}, authority = {}, additional = {}}
    dnsResponse.header:getFlags():setQR(dns.DNSHeaderFlags.QR.REPLY)

    if (not sucess or not dnsMessage) then
        dnsResponse.header:getFlags():setRCODE(dns.RCODE.FORMERR)
    end

    --Set or clear the value of recursion available in the response depending on whether the name server is willing to provide recursive service.
    dnsResponse.header:getFlags():setRA(config.recursion)

    if (config.recursion and dnsMessage.header:getFlags():getRD()) then --recursion requested
        --TODO recurse
        dnsResponse.header:getFlags():setRCODE(dns.RCODE.NIMPL)
    elseif (not config.recursion and dnsMessage.header:getFlags():getRD()) then
        --TODO error : cannot recurse
        dnsResponse.header:getFlags():setRCODE(dns.RCODE.NIMPL)
    else
        for i, question in pairs(dnsMessage.questions) do
            local answer, authoritative, additional, nxdomain = answerQuestion(question)
            if (nxdomain) then dnsResponse.header:getFlags():setRCODE(dns.DNSHeaderFlags.RCODE.NXDOMAIN) end
            for _, an in pairs(answer) do table.insert(dnsResponse.answer, an) end
            for _, au in pairs(authoritative) do table.insert(dnsResponse.authority, au) end
            for _, ad in pairs(additional) do table.insert(dnsResponse.additional, ad) end
            if (i == 1) and #authoritative == 0 then dnsResponse.header:getFlags():setAA(true) end
        end
    end
    dnsResponse.header:setAncount(#dnsResponse.answer)
    dnsResponse.header:setArcount(#dnsResponse.additional)
    dnsResponse.header:setNscount(#dnsResponse.authority)

    udpSocket:sendto(dns.message.packDNSMessage(dnsResponse), fromIP, fromPort)
end

---@return boolean
local function getStatus()
    if (not udpSocket) then
        return false
    else
        return true
    end
end

---@param listenedSocket UDPSocket
local function listenSocket(listenedSocket)
    checkArg(1, listenedSocket, 'table')
    while true do
        local read = table.pack(listenedSocket:receivefrom())
        if (read.n == 3) then
            local sucess, msg = pcall(handleMessage, table.unpack(read))
            if (sucess == false) then
                require("event").onError(msg)
            end
        end
        os.sleep()
    end
end
--RC METHODS===================================================================

---@diagnostic disable-next-line: lowercase-global
function start()
    local reason
    ---@diagnostic disable-next-line: cast-local-type
    udpSocket = assert(socket.udp())
    assert(udpSocket:setsockname("*", 51))
    zones = loadAllZoneFiles("/etc/dnsd/")
    listenerThread = thread.create(listenSocket, udpSocket):detach()
end

---@diagnostic disable-next-line: lowercase-global
function stop()
    if (listenerThread) then
        listenerThread:kill()
        listenerThread = nil
    end
    if (udpSocket) then
        udpSocket:close()
        ---@diagnostic disable-next-line: cast-local-type
        udpSocket = nil
    end
    ---@diagnostic disable-next-line: cast-local-type
    zones = nil
    require("rc").unload("dnsd")
end

---@diagnostic disable-next-line: lowercase-global
function status()
    if (getStatus()) then
        print("Running")
    else
        print("Not running")
    end
end

---@diagnostic disable-next-line: lowercase-global
function testZone()
    if (not getStatus()) then require("rc").unload("dnsd") end
    local callStatus, data = pcall(loadAllZoneFiles, "/etc/dnsd/")
    if (not callStatus) then
        print("Error : ", data)
    else
        print("ok")
    end
end

---@diagnostic disable-next-line: lowercase-global
function printZone(name)
    if (not getStatus()) then require("rc").unload("dnsd") end
    local function reverseDict(dict)
        local r = {}
        for k, v in pairs(dict) do
            r[v] = k
        end
        return r
    end
    local tmpzones = loadAllZoneFiles("/etc/dnsd/")
    for zname, zone in pairs(tmpzones) do
        print(zname)
        for k, v in pairs(zone) do
            for class, vv in pairs(v) do
                for rtype, datas in pairs(vv) do
                    for _, rdata in pairs(datas) do
                        if (rtype == dns.DNSRessourceRecord.TYPE.A) then rdata[2] = ipv4Address.tostring(rdata[2]) end
                        local recordData = rdata[2]
                        if (type(rdata[2]) == "table") then
                            recordData = serialization.serialize(rdata[2])
                        end
                        printf("\t%s\t%s\t%s\t%d\t%q", k, reverseDict(dns.DNSHeaderFlags.CLASS)[class], reverseDict(dns.DNSRessourceRecord.TYPE)[rtype], rdata[1], recordData)
                    end
                end
            end
        end
    end
end

---@diagnostic disable-next-line: lowercase-global
function resolve(name, rtype, class)
    class = class or "IN"
    if (not getStatus()) then require("rc").unload("dnsd") end
    local zone, zname = loadZoneFile("/etc/dnsd/testZone.zone")
    zones[zname] = zone
    local question = dns.DNSQuestion(name, dns.DNSRessourceRecord.TYPE[rtype], dns.DNSHeaderFlags.CLASS[class])
    print(serialization.serialize(table.pack(answerQuestion(question))))
end
