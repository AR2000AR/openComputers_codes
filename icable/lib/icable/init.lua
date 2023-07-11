local IcableDataLayer  = require('icable.IcableDataLayer')
local IcableIPv4Tunnel = require('icable.IcableIPv4Tunnel')
local icableConsts     = require('icable.constantes')
local computer         = require("computer")
local network          = require("network")


---@class libIcable
local icable = {}

---@param uname string
---@param password string
---@param remoteAddr string icable server address
---@param remotePort? number icable server port (default 4222)
---@param localAddr number local ipv4 address
---@param localMask number local ipv4 netmask
---@overload fun(uname:string,password:string,remoteAddr:string,remotePort?:number):table<InterfaceTypes>,string|nil
---@return table<InterfaceTypes>|nil,string|nil reason
function icable.connect(uname, password, remoteAddr, remotePort, localAddr, localMask)
    local success, dataLayer = pcall(IcableDataLayer.new, IcableDataLayer, remoteAddr, remotePort)
    if (not success) then return nil, dataLayer --[[@as string]] end
    dataLayer:authenticate(uname, password)
    local t = computer.uptime()
    while dataLayer:authenticated() == nil and computer.uptime() - t < 5.0 do os.sleep() end
    if (not dataLayer:authenticated()) then
        dataLayer:close()
        if (dataLayer:authenticated() == false) then
            dataLayer:close()
            return nil, "Authentication failed"
        end
        dataLayer:close()
        if (not (computer.uptime() - t < 5.0)) then
            return nil, "Authentication timeout"
        else
            return nil, "Unknown error."
        end
    end
    local ipLayer = IcableIPv4Tunnel(dataLayer, network.router, localAddr, localMask)
    return {ip = ipLayer, ethernet = dataLayer}
end

return icable
