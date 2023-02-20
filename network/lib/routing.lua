local bit32 = require("bit32")
local ipv4Address = require("layers.ipv4").address

---@class routingLib
local routing = {}
--=============================================================================

---@class Route
---@field network number
---@field mask number
---@field gateway number
---@field metric number
--=============================================================================

---@class IPv4Router:OSINetworkLayer
---@field private _routes table<Route>
---@field private _layers table<IPv4Layer>
---@operator call:IPv4Router
local IPv4Router = {}
IPv4Router.layerType = require("layers.ethernet").TYPE.IPv4

---@return IPv4Router
setmetatable(IPv4Router, {
    __call = function(self)
        local o = {
            _routes = {},
            _layers = {}
        }
        setmetatable(o, { __index = self })
        return o
    end
})

---Add a new route
---@param route Route
function IPv4Router:addRoute(route)
    if (not route.network) then return end
    --TODO : sort by metrics
    if (not (route.network == 0 and route.mask == 0xffffffff)) then
        table.insert(self._routes, 1, route)
    else
        table.insert(self._routes, route)
    end
end

---Get the route for the prodvided network address / mask
---@param address number
---@return Route
function IPv4Router:getRoute(address)
    for id, route in ipairs(self._routes) do
        local address1 = bit32.band(address, route.mask)
        local address2 = bit32.band(route.network, route.mask)
        if (address1 == address2) then return route end
    end
    error("No route found. This is not normal. Make sure a default route is set", 2)
end

---Remove a route
---@param id number
function IPv4Router:removeRoute(id)
    table.remove(self._routes, id)
end

---List all routes or return the route number id
---@param id number
---@return Route
---@overload fun():table<Route>
function IPv4Router:listRoutes(id)
    checkArg(1, id, "number", "nil")
    if (id) then return self._routes[id] end
    return self._routes
end

---Add a gateway (IPv4Lyer)
---@param interface IPv4Layer
function IPv4Router:setLayer(interface)
    table.insert(self._layers, interface)
end

---Get the interface with the given address
---@param address number
---@return IPv4Layer?
---@overload fun():table<IPv4Layer>
function IPv4Router:getLayer(address)
    if (not address) then return self._layers end
    for v in pairs(self._layers) do
        if (v:getAddr() == address) then
            return v
        end
    end
end

---remove the interface
---@param address any
function IPv4Router:removeLayer(address)
    for i, v in ipairs(self._layers) do
        if (v:getAddr() == address) then
            table.remove(self._layers, i)
            break
        end
    end
end

---send the IPv4 packet
---@param packet IPv4Packet
function IPv4Router:send(packet)
    local route = self:getRoute(packet:getDst())
    local interface = self:getLayer(route.gateway)
    assert(interface, "Cannot send packet to : ", ipv4Address.address.tostring(packet:getDst()))
    interface:send(route.gateway, packet)
end

--=============================================================================

routing.IPv4Router = IPv4Router
return routing
