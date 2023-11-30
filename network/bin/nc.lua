local shell  = require("shell")
local event  = require("event")
local thread = require("thread")
local term   = require("term")
local os     = require("os")
local socket = require("socket")


local args, opts = shell.parse(...)
---@type TCPSocket|UDPSocket
local localSocket
---@type TCPSocket|nil
local clientSocket
---@type thread
local listenerThread


opts.p = tonumber(opts.p) or 0
opts.b = opts.b or "0.0.0.0"

---@param listenedSocket UDPSocket|TCPSocket
local function listenSocket(listenedSocket)
    checkArg(1, listenedSocket, 'table')
    while true do
        if (listenedSocket:instanceOf(socket.tcp)) then
            ---@cast listenedSocket TCPSocket
            if (listenedSocket:getState() ~= "ESTABLISHED") then
                return false
            end
        end
        local data = listenedSocket:recieve()
        if (data) then
            term.write(data)
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

---read stdin indefenitely and send what's read through the socket
---@param outSocket TCPSocket|UDPSocket
local function readUserInput(outSocket)
    repeat
        local msg = term.read()
        if (msg) then outSocket:send(msg .. "\n") end
    until not msg or listenerThread:status() == "dead"
end

local function exit()
    if (localSocket) then localSocket:close() end
    if (clientSocket) then clientSocket:close() end
    if (listenerThread) then
        if (not listenerThread:join(3)) then
            listenerThread:kill()
        end
    end
    return false
end

event.listen("interrupted", exit)

if (opts.h or opts.help) then
    help()
    os.exit()
elseif (opts.l and opts.u and (tonumber(args[1]) or opts.p)) then --listen UDP
    localSocket = socket.udp()
    assert(localSocket:setsockname("*", tonumber(args[1]) or opts.p))
    print(string.format("Listening on %s:%d", localSocket:getsockname()))
    listenerThread = thread.create(listenSocket, localSocket)
    while true do
        --no remote addr/port. We cannot send msgs
        os.sleep()
    end
    localSocket:close()
elseif (opts.u) then --connect UDP
    localSocket = socket.udp()
    assert(localSocket:setsockname(opts.b, opts.p))
    args[2] = assert(tonumber(args[2]), "Invalid port number")
    assert(localSocket:setpeername(args[1], args[2]))
    print(string.format("Listening on %s:%d", localSocket:getsockname()))
    listenerThread = thread.create(listenSocket, localSocket)
    readUserInput(localSocket)
    localSocket:close()
elseif (opts.l) then --listen tcp
    localSocket = socket.tcp()
    args[1] = args[1] or opts.b
    args[2] = assert(tonumber(args[2] or opts.p), "Invalid port number")
    assert(localSocket:bind(args[1], args[2]))
    print(string.format("Listening on %s:%d", localSocket:getsockname()))
    localSocket:listen(1)
    local reason
    clientSocket = localSocket:accept()
    localSocket:close() --client connected, we don't need the listening socket anymore
    if (clientSocket) then
        print(string.format("Connected to : %s:%d", clientSocket:getpeername()))
        listenerThread = thread.create(listenSocket, clientSocket)
        readUserInput(clientSocket)
        clientSocket:close()
    else
        print(reason)
    end
else --connect TCP
    args[2] = assert(tonumber(args[2]), "Invalid port number")
    localSocket = socket.tcp()
    localSocket:settimeout(5)
    local s = localSocket:connect(args[1], args[2])
    if (s ~= 1) then
        print("Timeout")
    else
        print(string.format("Connected to %s:%d", localSocket:getpeername()))
        listenerThread = thread.create(listenSocket, localSocket)
        readUserInput(localSocket)
    end
    localSocket:close()
end

exit()
