local dns         = require("dns")
local ipv4Address = require("network.ipv4").address
local socket      = require("socket")
local os          = require("os")
--=============================================================================


---@class libdnsapi
local dnsapi = {}

---@class options
---@field timeout number

---@class config
---@field nameserver table<number>
---@field options options

---@return config
local function getConfig()
    local config = {options = {timeout = 5}, nameserver = {}}
    local file = io.open("/etc/resolv.conf")
    assert(file, "resolv.conf not found")
    for line in file:lines() do
        local option, argument = line:match("^(%S+)%s+(.+)$")
        if (option == "nameserver") then
            table.insert(config.nameserver, argument)
        elseif (option == "options") then
            option, argument = argument:match("^(%S+)%s+(.+)$")
            config.options[option] = tonumber(argument) or argument
        else
            config[option] = argument
        end
    end
    file:close()
    return config
end

dnsapi.getConfig = getConfig

---@param name string
---@param class dnsRecordClass
---@param rtype dnsRecordType
---@return DNSMessage? message,string? reason
function dnsapi.resolve(name, class, rtype)
    local config = getConfig()

    local question = dns.DNSQuestion(name, rtype, class)

    ---@type DNSMessage
    local message = {
        header = dns.DNSHeader(1, dns.DNSHeaderFlags(dns.DNSHeaderFlags.QR.QUERRY, dns.DNSHeaderFlags.OPCODE.QUERY, false, false, false, false, dns.DNSHeaderFlags.RCODE.NOERROR), 1, 0, 0, 0),
        questions = {question},
        answer = {},
        authority = {},
        additional = {}
    }

    local udpSocket, reason = socket.udp()
    assert(udpSocket:setpeername(config.nameserver[1], 51), reason)
    udpSocket:settimeout(config.options.timeout)

    udpSocket:send(dns.message.packDNSMessage(message))

    local answerPacket
    local t = os.time()
    repeat
        answerPacket = udpSocket:recieve()
        os.sleep()
    until answerPacket or (os.time() - t > (config.options.timeout * 100))
    udpSocket:close()
    if (os.time() - t > (config.options.timeout * 100)) then return nil, "timeout" end
    --TODO : try next srv
    assert(answerPacket)
    local answerMessage = dns.message.parsePacket(answerPacket)
    return answerMessage
end

return dnsapi
