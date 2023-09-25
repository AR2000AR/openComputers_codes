local shell  = require("shell")
local event  = require("event")
local thread = require("thread")
local term   = require("term")
local os     = require("os")
local socket = require("socket")


local args, opts        = shell.parse(...)
local udpSocket, reason = socket.udp()
local listenerThread


opts.p = tonumber(opts.p) or 0
opts.b = opts.b or "0.0.0.0"

---@param listenedSocket UDPSocket
local function listenSocket(listenedSocket)
    checkArg(1, listenedSocket, 'table')
    while true do
        local datagram = listenedSocket:recieve()
        if (datagram) then
            term.write(datagram)
        end
        os.sleep()
    end
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
    if (udpSocket) then udpSocket:close() end
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
elseif (opts.l and opts.u and (tonumber(args[1]) or opts.p)) then --listen UDP
    assert(udpSocket:setsockname("*", tonumber(args[1]) or opts.p))
    --udpSocket:setCallback(listenSocket)
    print(string.format("Listening on %s:%d", udpSocket:getsockname()))
    listenerThread = thread.create(listenSocket, udpSocket)
    while true do
        --no remote addr/port. We cannot send msgs
        os.sleep()
    end
    udpSocket:close()
elseif (opts.u) then --connect UDP
    assert(udpSocket:setsockname(opts.b, opts.p))
    args[2] = assert(tonumber(args[2]), "Invalid port number")
    assert(udpSocket:setpeername(args[1], args[2]))
    --udpSocket:setCallback(listenSocket)
    print(string.format("Listening on %s:%d", udpSocket:getsockname()))
    listenerThread = thread.create(listenSocket, udpSocket)
    repeat
        local msg = term.read()
        if (msg) then udpSocket:send(msg .. "\n") end
    until not msg
    udpSocket:close()
elseif (opts.l) then
    local tcpsocket = socket.tcp()
    assert(tcpsocket:bind(opts.b, opts.p))
    args[2] = assert(tonumber(args[2]), "Invalid port number")
    assert(tcpsocket:bind(args[1], args[2]))
    print(string.format("Listening on %s:%d", tcpsocket:getsockname()))
    tcpsocket:listen(1)
    local client = tcpsocket:accept()
    if (client) then
        listenerThread = thread.create(listenSocket, client)
        repeat
            local msg = term.read()
            if (msg) then client:send(msg .. "\n") end
        until not msg
        client:close()
    end
    tcpsocket:close()
else --connect TCP
    args[2] = assert(tonumber(args[2]), "Invalid port number")
    local tcpsocket = socket.tcp()
    tcpsocket:settimeout(5)
    local s = tcpsocket:connect(args[1], args[2])
    if (s ~= 1) then
        print("Timeout")
        os.exit(1)
    end
    print(string.format("Connected to %s:%d", tcpsocket:getpeername()))
    listenerThread = thread.create(listenSocket, tcpsocket)
    repeat
        local msg = term.read()
        if (msg) then tcpsocket:send(msg .. "\n") end
    until not msg
    tcpsocket:close()
end
