--shameless copy of OpenOS's /bin/mount cmd
--adapted to mount a lnfs filesystem

local lnfs = require("lnfs")
local filesystem = require("filesystem")
local shell = require("shell")

local function usage()
    io.stderr:write([==[
  Usage: mount [OPTIONS] [address] [path]")
    If no args are given, all current mount points are printed.
    <Options> Note that multiple options can be used together
    -r, --ro       Mount the filesystem read only
    -p=, --port=   Server port (default 21)
    <Args>
    address        Specify server address
    path           Target folder path to mount to
    ]==])
    os.exit(1)
end

-- smart parse, follow arg after -o
local args, opts = shell.parse(...)
opts.readonly = opts.r or opts.readonly
opts.port = opts.p or opts.port or 21

if opts.h or opts.help then
    usage()
end

local function do_mount()
    local proxy, reason = lnfs.LnfsProxy.new(args[1], opts.port, opts.readonly)
    if not proxy then
        io.stderr:write("Failed to mount: ", tostring(reason), "\n")
        os.exit(1)
    end

    assert(proxy)
    local result, mount_failure = filesystem.mount(proxy, shell.resolve(args[2]))
    if not result then
        io.stderr:write(mount_failure, "\n")
        os.exit(2) -- error code
    end
end

if #args == 0 then
    if next(opts) then
        io.stderr:write("Missing argument\n")
        usage()
    end
elseif #args == 2 then
    do_mount()
else
    io.stderr:write("wrong number of arguments: ", #args, "\n")
    usage()
end
