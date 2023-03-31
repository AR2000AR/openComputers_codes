local os = require("os")
local ipv4Address = require("network.ipv4.address")
local resolvLoaded, resolv = pcall(require, "resolv")
local dnsTypes
if (resolvLoaded) then dnsTypes = require("dns") end

---@class socketdns
local dns = {}

---@class resolved
---@field name string canonic-name
---@field alias table<string> alias-list
---@field ip table<string> ip-address-List

---Returns the standard host name for the machine as a string.
---@return string?
function dns.gethostname()
    return os.getenv("HOSTNAME")
end

function dns.tohostname(address)
    return nil, "not implemented"
end

---Converts from host name to IP address.\
---address can be an IP address or host name.\
---Returns a string with the first IP address found for address, followed by a table with all information returned by the resolver. In case of error, the function returns nil followed by an error message.
---@param address string
---@return string? ip
---@return table|string resolvedOrReason
function dns.toip(address)
    if (pcall(ipv4Address.fromString, address)) then
        return address, {name = address, alias = {address}, ip = {address}}
    else
        if (resolvLoaded) then --resolv may not be installed
            local msg = resolv.resolve(address, dnsTypes.CLASS.IN, dnsTypes.TYPE.A)
            if (not msg) then return nil, "address not found" end
            if (#msg.answer == 0) then
                return nil, "address not found"
            end
            local resolved = {
                name = (msg.answer[1] --[[@as DNSRessourceRecord]]):getName(),
                alias = {},
                ip = {}
            }

            local ip = ipv4Address.tostring((msg.answer[1] --[[@as DNSRessourceRecord]]):getRdata())
            for _, answer in pairs(msg.answer) do
                ---@cast answer DNSRessourceRecord
                table.insert(resolved.ip, ipv4Address.tostring(answer:getRdata()))
                table.insert(resolved.alias, answer:getName())
            end
            return ip, resolved
        end
        return nil, "No dns resolver installed"
    end
end

return dns
