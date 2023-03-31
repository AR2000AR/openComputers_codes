local bit32 = require("bit32")
local ipv4 = require("network.ipv4")

---@class routingLib
local routing = {}
--=============================================================================

---@class Route
---@field network number
---@field mask number
---@field gateway number
---@field metric number
---@field interface IPv4Layer
--=============================================================================

---@class IPv4Router:OSINetworkLayer
---@field private _routes table<Route>
---@field private _protocols table<ipv4Protocol,OSILayer>
---@operator call:IPv4Router
---@overload fun():IPv4Router
local IPv4Router = {}
IPv4Router.layerType = require("network.ethernet").TYPE.IPv4

---@return IPv4Router
setmetatable(IPv4Router, {
    __call = function(self)
        local o = {
            _routes = {},
            _protocols = {}
        }
        setmetatable(o, {__index = self})
        return o
    end
})

---Add a new route
---@param route Route
function IPv4Router:addRoute(route)
    if (not route.network) then return end
    if (not (route.network == 0 and route.mask == 0)) then
        table.insert(self._routes, 1, route)
    else
        table.insert(self._routes, route)
    end
    ---@param a Route
    ---@param b Route
    ---@return boolean
    table.sort(self._routes, function(a, b)
        if (a.network == 0 and b.network == 0) then
            return a.metric > b.metric
        elseif (a.network ~= 0 and b.network ~= 0) then
            if (a.metric == b.metric) then
                if (a.network == b.network) then
                    return a.mask > b.mask
                else
                    return a.network < b.network
                end
            else
                return a.metric > b.metric
            end
        elseif (a.network == 0) then
            return false
        else
            return true
        end
    end
    )
end

---Get the route for the prodvided network address / mask
---@param address? number
---@return Route
function IPv4Router:getRoute(address)
    checkArg(1, address, 'nil', 'number')
    if (not address) then
        for id, route in ipairs(self:listRoutes()) do
            ---@cast route Route
            if (route.network == 0 and route.mask == 0) then return route end
        end
    end
    for id, route in ipairs(self:listRoutes()) do
        ---@cast route Route
        local address1 = bit32.band(address, route.mask)
        local address2 = bit32.band(route.network, route.mask)
        if (address1 == address2) then return route end
    end
    error(string.format("No route found to %s. This is not normal. Make sure a default route is set", ipv4.address.tostring(address)), 2)
end

---Remove a route
---@param id number
function IPv4Router:removeRoute(id)
    table.remove(self._routes, id)
end

---List all routes or return the route number id
---@param id number
---@return Route
---@overload fun(self:IPv4Router):table<Route>
function IPv4Router:listRoutes(id)
    checkArg(1, id, "number", "nil")
    if (id) then return self._routes[id] end
    return self._routes
end

---Remove a gateway from the routing table. Useful to remove default route for a interface.
---@param gateway number
function IPv4Router:removeGateway(gateway)
    local rmRoutes = {}
    --find the routes to remove
    for i, route in ipairs(self._routes) do
        if (route.gateway == gateway) then
            table.insert(rmRoutes, i)
        end
    end
    --remove the routes
    for v in pairs(rmRoutes) do
        table.remove(self._routes, v)
    end
end

---Remove routes that use the provided interface
---@param interface IPv4Layer
function IPv4Router:removeByInterface(interface)
    local rmRoutes = {}
    --find the routes to remove
    for i, route in ipairs(self._routes) do
        ---@cast route Route
        if (route.interface == interface) then
            table.insert(rmRoutes, i)
        end
    end
    --remove the routes
    for v in pairs(rmRoutes) do
        table.remove(self._routes, v)
    end
    self:removeGateway(interface:getAddr())
end

---send the IPv4 packet
---@param packet IPv4Packet
function IPv4Router:send(packet)
    packet:setTtl(packet:getTtl() - 1)
    --TODO : icmp error if ttl 0
    local route = self:getRoute(packet:getDst())
    if (route.gateway == route.interface:getAddr()) then
        route.interface:send(packet)
    else
        route.interface:send(route.gateway, packet)
    end
end

---@param protocolHandler OSILayer
function IPv4Router:setProtocol(protocolHandler)
    self._protocols[protocolHandler.layerType] = protocolHandler
end

IPv4Router.setLayer = IPv4Router.setProtocol

---@param protocolID ipv4Protocol
---@return OSILayer
function IPv4Router:getProtocol(protocolID)
    return self._protocols[protocolID]
end

---@param from number
---@param to number
---@param payload string
function IPv4Router:payloadHandler(from, to, payload)
    checkArg(1, from, 'number')
    checkArg(2, to, 'number')
    checkArg(3, payload, 'string')
    local packet = ipv4.IPv4Packet.unpack(payload)
    if (self._protocols[packet:getProtocol()]) then
        self._protocols[packet:getProtocol()]:payloadHandler(from, to, packet:getPayload())
    end
end

function IPv4Router:getAddr()
    return self:getRoute().interface
end

function IPv4Router:getMTU()
    return self:getRoute().interface:getMTU()
end

--=============================================================================

routing.IPv4Router = IPv4Router
return routing
