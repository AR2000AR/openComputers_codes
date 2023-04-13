local gpu, gpuAD
local screenAD
local tunnel, tunnelAD
local crafter, crafterAD
gpuAD = component.list("gpu")()
screenAD = component.list("screen")()
while true do
    while not tunnel or not crafter do
        tunnelAD = component.list("tunnel")()
        if (tunnelAD) then tunnel = component.proxy(tunnelAD) end
        crafterAD = component.list("crafting")()
        if (crafterAD) then crafter = component.proxy(crafterAD) end
        if (gpuAD and screenAD) then
            gpu = assert(component.proxy(component.list("gpu")()))
            gpu.bind(screenAD)
            gpu.set(1, 1, "GPU OK ")
            if (tunnel) then gpu.set(1, 2, "tunnel OK ") else gpu.set(1, 2, "tunnel ERR") end
            if (crafter) then gpu.set(1, 3, "crafting OK ") else gpu.set(1, 3, "crafter ERR") end
        end
    end
    local count = 0

    while tunnel and crafter do
        local sigName, localAd, _, _, _, message = computer.pullSignal(1)
        if (sigName and gpu) then gpu.set(1, 4, sigName) end
        if (sigName == "modem_message" and localAd == tunnelAD) then
            tunnel.send(crafter.craft())
            count = count + 1
            if (gpu) then gpu.set(1, 5, tostring(count)) end
        end
    end
end
