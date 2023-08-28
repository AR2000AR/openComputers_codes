local bit32        = require("bit32")
local ipv4Address  = require("network.ipv4.address")
local ipv4Consts   = require("network.ipv4.constantes")
local IPv4Packet   = require("network.ipv4.IPv4Packet")
local UDPDatagram  = require("network.udp.UDPDatagram")
local TCPSegment   = require("network.tcp.TCPSegment")
local NetworkLayer = require('network.abstract.NetworkLayer')
local class        = require("libClass2")


---@class Route
---@field network number
---@field mask number
---@field gateway number
---@field metric number
---@field interface IPv4Layer
--=============================================================================

---@class IPv4Router:NetworkLayer
---@field private _routes table<Route>
---@field private _protocols table<ipv4Protocol,NetworkLayer>
---@operator call:IPv4Router
---@overload fun():IPv4Router
local IPv4Router = class(NetworkLayer)
IPv4Router.layerType = require("network.ethernet").TYPE.IPv4

---@return IPv4Router
function IPv4Router:new()
    local o = self.parent()
    setmetatable(o, {__index = self})
    ---@cast o IPv4Router
    o._routes = {}
    o._protocols = {}
    return o
end

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
    error(string.format("No route found to %s. This is not normal. Make sure a default route is set", ipv4Address.tostring(address)), 2)
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
    self:removeGateway(interface:addr())
end

---send the IPv4 packet
---@param packet IPv4Packet
function IPv4Router:send(packet)
    packet:ttl(packet:ttl() - 1)
    if (packet:ttl() < 1) then
        --TODO : icmp error if ttl 0
        return
    end
    local route = self:getRoute(packet:dst())
    if (packet:src() == 0) then
        packet:src(route.interface:addr())
    end
    if (packet:protocol() == ipv4Consts.PROTOCOLS.UDP) then
        local udpPacket = UDPDatagram.unpack(packet:payload())
        udpPacket:checksum(udpPacket:calculateChecksum(packet:src(), packet:dst()))
        packet:payload(udpPacket:pack())
    elseif (packet:protocol() == ipv4Consts.PROTOCOLS.TCP) then
        local tcpSegment = TCPSegment.unpack(packet:payload())
        tcpSegment:windowSize(route.interface:mtu() - 5 * 4)
        tcpSegment:checksum(tcpSegment:calculateChecksum(packet:src(), packet:dst()))
        packet:payload(tcpSegment:pack())
    end
    if (route.gateway == route.interface:addr()) then
        route.interface:send(packet)
    else
        route.interface:send(route.gateway, packet)
    end
end

---@param from number
---@param to number
---@param payload string
function IPv4Router:payloadHandler(from, to, payload)
    checkArg(1, from, 'number')
    checkArg(2, to, 'number')
    checkArg(3, payload, 'string')
    local packet = IPv4Packet.unpack(payload)
    if (self:higherLayer(packet:protocol())) then
        self:higherLayer(packet:protocol()):payloadHandler(from, to, packet:payload())
    end
end

---@return number
function IPv4Router:addr()
    return self:getRoute().interface:addr()
end

function IPv4Router:mtu()
    return self:getRoute().interface:mtu()
end

--=============================================================================

return IPv4Router
