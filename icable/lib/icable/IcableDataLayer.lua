local class           = require("libClass2")
local NetworkLayer    = require("network.abstract.NetworkLayer")
local component       = require("component")
local event           = require("event")
local ethernetType    = require("network.ethernet").TYPE
local IcablePacket    = require('icable.IcablePacket')
local icableConsts    = require('icable.constantes')
local ipv4address     = require('network.ipv4.address')
local datahashlib     = require('datahashlib')

---@class IcableDataLayer:NetworkLayer
---@field _addr string
---@field _port number
---@field _socket TcpSocket
---@field _authenticated boolean
---@field _readLock boolean
---@field _buffer string
---@field _listener number
---@operator call:IcableDataLayer
---@overload fun(address:string,port?:number):IcableDataLayer
local IcableDataLayer = require('libClass2')(NetworkLayer)

---@param address string
---@param port number
---@return IcableDataLayer
function IcableDataLayer:new(address, port)
    local o = self.parent()
    setmetatable(o, {__index = self})
    ---@cast o IcableDataLayer
    o._addr = address
    o._port = port or 4222
    o._readLock = false
    o._buffer = ""
    assert(component.internet)
    o._socket = assert(component.internet.connect(o._addr, o._port))
    local connected, reason
    repeat
        connected, reason = o._socket.finishConnect()
    until connected or reason
    if (reason) then
        error(reason, 2)
    end
    o._listener = event.listen("internet_ready", function(...) o:onInternetReady(...) end) --[[@as number]]
    return o
end

function IcableDataLayer:onInternetReady(a, b, sockId)
    --is this for us
    if (sockId ~= self._socket.id()) then
        --self._socket.finishConnect()
        return
    end
    local data = self._socket.read()
    if (data == nil) then --issue with the socket
        --we do not free the lock as we will never need to read again
        require("event").onError('icable : connexion lost')
        self:close()
        return false
    end
    if (#data == 0) then return end --no data
    self._buffer = self._buffer .. data
    while (self._readLock) do os.sleep() end
    self._readLock = true
    pcall(self._handlePacket, self)
    self._readLock = false
end

---@protected
---Read from the local buffer
---@param size? number
---@return string
function IcableDataLayer:_readFromBuffer(size)
    if (not size) then
        local res = self._buffer
        self._buffer = ""
        return res
    end
    local res = self._buffer:sub(1, size)
    self._buffer = self._buffer:sub(size + 1)
    return res
end

---@protected
function IcableDataLayer:_handlePacket()
    local data = self:_readFromBuffer(8)
    if (#data == 0) then return end --no data
    local len = IcablePacket.getLenFromHeaderData(data)
    if (not len) then return end    --invalid header data
    --at this point we have read the icable header. We now need to read the data if applicable
    while #data < (8 + len) do
        local newData = self:_readFromBuffer(len - (#data - 8))
        if (newData and #newData > 0) then
            data = data .. newData
        end
        --os.sleep() --allow the os to process events
    end
    --At this point, we have the entire packet data
    local packet = IcablePacket.unpack(data) --unpack the data
    --check the packet kind and act on it
    if (packet:kind() == icableConsts.KIND.SERVER_DATA) then
        self:payloadHandler(nil, nil, packet:payload())
    elseif (packet:kind() == icableConsts.KIND.SERVER_AUTH) then
        --the SERVER_AUTH packet contain a single byte set to 0x00 if authentication failed, or 0xff if it succeeded
        local auth = string.unpack('>B', packet:payload())
        self._authenticated = auth == 0xff
        self._password = nil
        if (not self._authenticated) then
            self._uname = nil
        end
    elseif (packet:kind() == icableConsts.KIND.SERVER_AUTH_REQUEST) then
        ---authentication step 2
        local salt, srvsalt = string.unpack('>c16c16', packet:payload())
        local salted = datahashlib.sha256(salt .. self._password)
        self._password = nil
        salted = datahashlib.sha256(srvsalt .. salted)
        local icableMsg = IcablePacket(icableConsts.KIND.CLIENT_AUTH, string.pack('>s1s1', self._uname, salted))
        self:send(nil, icableMsg)
    elseif (packet:kind() == icableConsts.KIND.SERVER_NETCONF) then
        --this is the effective network configuration.
        local kind, addr, mask = packet:getNetConf()
        if (kind == icableConsts.SERVER_NETCONF_KIND.IPv4 and addr and mask) then
            ---@cast addr number
            ---@cast mask number
            self:higherLayer(ethernetType.IPv4) --[[@as IcableIPv4Tunnel]]:setLocalAddress(addr, mask)
        end
    elseif (packet:kind() == icableConsts.KIND.SERVER_DISCONNECT) then
        self:close()
    elseif (packet:kind() == icableConsts.KIND.SERVER_ERROR) then
        --handle errors
        local errorData = packet:payload()
        local errorKind = string.unpack('>B', errorData)
        local errorMsg = ""
        if (string.unpack('>H', errorData, 1) > 0) then
            require("event").onError(string.unpack('>H', errorData, 1))
            errorMsg = string.unpack('>s2', errorData, 1)
        end
        require("event").onError("icable:error:" .. errorKind .. ":" .. errorMsg)
        if (errorKind == 0x02) then     --auth erro
            self._authenticated = false
        elseif (errorKind == 0x04) then --netconf error
            self:close()
        end
    end
end

---Get the payload from the previous layer
---@param from nil
---@param to nil
---@param payload string
function IcableDataLayer:payloadHandler(from, to, payload)
    ---@diagnostic disable-next-line: param-type-mismatch
    self:higherLayer(ethernetType.IPv4):payloadHandler(from, to, payload)
end

---@param uname string
---@param password string
function IcableDataLayer:authenticate(uname, password)
    local icableMsg = IcablePacket(icableConsts.KIND.CLIENT_AUTH_REQUEST, string.pack('>s1', uname))
    self._password = password
    self._uname = uname
    self:send(nil, icableMsg)
end

---check if we are authenticated to the srv. nil mean no authentification attempt was done
---@return boolean|nil
function IcableDataLayer:authenticated()
    return self._authenticated
end

---Set the interface address. May fail if the srv deny it.
---@param addr number
---@param mask number
---@param auto? boolean
function IcableDataLayer:setAddress(addr, mask, auto)
    local icablePacket
    if (auto == nil) then auto = false end
    checkArg(3, auto, "boolean")
    if (addr and not auto) then
        checkArg(1, addr, 'number')
        checkArg(2, mask, 'number')
        assert(addr >= 0 and addr <= 0xffffffff, 'Invalid IPv4 : ' .. addr)
        icablePacket = IcablePacket(icableConsts.KIND.CLIENT_NETCONF,
                                    string.pack('>BIB', icableConsts.CLIENT_NETCONF_KIND.MANUAL_IPv4, addr, ipv4address.maskToMaskLen(mask)))
    else
        checkArg(1, addr, 'number', 'nil')
        if (addr) then
            checkArg(2, mask, 'number')
        else
            checkArg(2, mask, 'nil')
        end
        if (addr) then
            icablePacket = IcablePacket(icableConsts.KIND.CLIENT_NETCONF, string.pack('>BIB', icableConsts.CLIENT_NETCONF_KIND.AUTO_IPv4addr, ipv4address.maskToMaskLen(mask)))
        else
            icablePacket = IcablePacket(icableConsts.KIND.CLIENT_NETCONF, string.pack('>B', icableConsts.CLIENT_NETCONF_KIND.AUTO_IPv4))
        end
    end
    self:send(nil, icablePacket)
end

---Send the payload
---@param to nil destination.
---@param payload IcablePacket
---@overload fun(payload)
function IcableDataLayer:send(to, payload)
    self._socket.write(payload:pack())
end

---Return the maximum payload size
---@return number
function IcableDataLayer:mtu()
    return 8192
end

---@return string|number
function IcableDataLayer:addr()
    return self._socket.id()
end

function IcableDataLayer:close()
    self._socket.close()
    if (self:higherLayer(ethernetType.IPv4)) then
        self:higherLayer(ethernetType.IPv4) --[[@as IcableIPv4Tunnel]]:close()
    end
    event.cancel(self._listener)
    --lie about the component so ifconfig remove it.
    --ifconfig wait for 'modem' components to remove
    event.push('component_removed', self._socket.id(), 'modem')
end

return IcableDataLayer
