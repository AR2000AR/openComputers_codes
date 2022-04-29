local function sleep(s)
    local t1 = computer.uptime()
    while t1+s > computer.uptime() do end
end
local gpu = component.proxy(component.list("gpu")())
local screenAD = component.list("screen")()
gpu.bind(screenAD)
gpu.set(1,1,"GPU OK")
sleep(1)
local tunnel = component.proxy(component.list("tunnel")())
gpu.set(1,2,"tunnel OK")
sleep(1)
local crafter = component.proxy(component.list("crafting")())
gpu.set(1,3,"crafting OK")
sleep(1)
while true do
    sigName,localAd,_,_,_,message = computer.pullSignal(1)
    if(sigName) then
    gpu.set(1,4,sigName)
    gpu.set(1,5,tostring(localAd))
    gpu.set(1,6,tunnel.address)
    end
    if(sigName == "modem_message" and  localAd == tunnel.address) then
        crafter.craft()
    end
end