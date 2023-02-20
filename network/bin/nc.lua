local network      = require("network")
local modem        = require("component").modem
local ipv4Address  = require("layers").ipv4.address
local shell        = require("shell")
local event        = require("event")
local thread       = require("thread")
local term         = require("term")
local os           = require("os")

local args, opts   = shell.parse(...)
local udpInterface = network.interfaces[modem.address].udp
local socket, reason
local listenerThread


opts.p = tonumber(opts.p)

local function listenSocket(listenedSocket)
    repeat
        local msg = listenedSocket:reciveString()
        if (msg) then
            term.write(msg)
        end
        os.sleep()
    until not listenedSocket:isOpen()
end

local function help()
    print("nc [-l] [-u] [-p=local port] [address] [port]")
    print("\t-l : Listen for incomming connexion. With -u make nc listen for packet from all hosts")
    print("\t-u : UDP")
    print("\t-p : In UDP, the local port to listen on. Default to the remote port")
    print("Examples :")
    print("\t nc -l -u 9999")
    print("\t nc -u -p=9999 192.168.1.1 9999")
    print("\t nc -u 192.168.1.1 9999")
end

event.listen("interrupted", function(...)
    if (socket) then socket:close() end
    if (listenerThread) then
        if (not listenerThread:join(3)) then
            listenerThread:kill()
        end
    end
    return false
end
)
if (opts.h or opts.help) then
    help()
    os.exit()
elseif (opts.l and opts.u and (opts.p or tonumber(arg[1]))) then --listen UDP
    socket = udpInterface:open(opts.p or tonumber(arg[1]))
    assert(socket)
    print(string.format("Listening on port %d", socket:getLocalPort()))
    listenerThread = thread.create(listenSocket, socket)
    while socket:isOpen() do
        --no remote addr/port. We cannot send msgs
        os.sleep()
    end
    socket:close()
elseif (opts.u) then --connect UDP
    socket, reason = udpInterface:open(opts.p or tonumber(args[2]), ipv4Address.fromString(args[1]), tonumber(args[2]))
    if (not socket) then
        print("Could not open socket : " .. reason)
        os.exit(1)
    end
    assert(socket)
    print(string.format("Listening on port %d", socket:getLocalPort()))
    listenerThread = thread.create(listenSocket, socket)
    repeat
        local msg = term.read()
        if (msg) then socket:send(msg .. "\n") end
    until not msg or not socket:isOpen()
    socket:close()
else
    help()
end
