local ethernet     = require("network.ethernet")
local ipv4Address  = require("network.ipv4.address")
local IPv4Layer    = require('network.ipv4.IPv4Layer')
local NetworkLayer = require('network.abstract.NetworkLayer')
local IcablePacket = require('icable.IcablePacket')
local icableConsts = require('icable.constantes')
local class        = require("libClass2")


---@class IcableIPv4Tunnel : IPv4Layer
---@field private _addr number
---@field private _mask number
---@field private _router IPv4Router
---@field package _layer IcableDataLayer
---@field private _buffer table<number,table<number,table<number,IPv4Packet>>>
---@operator call:IcableIPv4Tunnel
---@overload fun(dataLayer:NetworkLayer,router:IPv4Router,addr:number|string,mask:number|string,auto:boolean):IcableIPv4Tunnel
---@overload fun(dataLayer:NetworkLayer,router:IPv4Router,addr:number|string,mask:number|string):IcableIPv4Tunnel
---@overload fun(dataLayer:NetworkLayer,router:IPv4Router,addr:number|string,mask:number|string):IcableIPv4Tunnel
local IcableIPv4Tunnel     = class(NetworkLayer)
IcableIPv4Tunnel.layerType = ethernet.TYPE.IPv4


---@param dataLayer IcableDataLayer
---@param router IPv4Router
---@param addr number|string
---@param mask number
---@param auto? boolean
---@return IcableIPv4Tunnel
function IcableIPv4Tunnel:new(dataLayer, router, addr, mask, auto)
    checkArg(1, dataLayer, "table")
    checkArg(2, router, 'table')
    checkArg(3, addr, "number", "string", 'nil')
    if (not addr) then
        checkArg(4, mask, 'nil')
    else
        checkArg(4, mask, "number", "string")
    end
    checkArg(5, auto, "boolean", "nil")
    if (auto == nil) then auto = false end

    local o = self.parent()
    setmetatable(o, {__index = self})
    ---@cast o IcableIPv4Tunnel
    o._layer = dataLayer
    o._buffer = {}
    o._router = router

    if (type(addr) == 'string') then addr = ipv4Address.fromString(addr) end

    o:layer(dataLayer)
    dataLayer:setAddress(addr, mask, auto)
    return o
end

IcableIPv4Tunnel.addr = IPv4Layer.addr
IcableIPv4Tunnel.mask = IPv4Layer.mask
IcableIPv4Tunnel.mtu = IPv4Layer.mtu
IcableIPv4Tunnel.router = IPv4Layer.router
IcableIPv4Tunnel.payloadHandler = IPv4Layer.payloadHandler

---Send a IPv4Packet
---@param self IPv4Layer
---@param to number
---@param payload IPv4Packet
---@overload fun(self:IPv4Layer,payload:IPv4Packet)
function IcableIPv4Tunnel:send(to, payload)
    if (not payload) then
        ---@diagnostic disable-next-line: cast-local-type
        payload = to
        to = payload:dst()
    end
    ---@cast payload IPv4Packet
    if (to == self:addr()) then --sent to self
        local l = self:layer() --[[@as EthernetInterface]]
        self:payloadHandler(l:addr() --[[@as string]], l:addr() --[[@as string]], payload:pack())
    else
        self:layer() --[[@as IcableDataLayer]]:send(nil, IcablePacket(icableConsts.KIND.CLIENT_DATA, payload:pack()))
    end
end

function IcableIPv4Tunnel:close()
    self:router():removeByInterface(self)
end

---@param addr number|string
---@param mask number
function IcableIPv4Tunnel:setLocalAddress(addr, mask)
    self:addr(addr)
    self:mask(mask)
    self:router(self:router())
end

return IcableIPv4Tunnel
