local io = require("io")
local shell = require("shell")
local os = require("os")
local component = require("component")
local event = require("event")
local term = require("term")
local serialization = require("serialization")
local fs = require("filesystem")

local config = {secret = "", timeout = 5, bank_addr = ""}

local args, opts = shell.parse(...)
if (#args < 1 or #args > 3 or opts["h"]) then
  print("generateClientSecret [-n] [clientAddress] clientName [serverAddress]")
  print("\t -n : do not generate secret")
  os.exit(1)
end


if (not opts["n"]) then
  local clientAdd = table.remove(args, 1)
  print("Client address : " .. clientAdd)

  local secretFileName = string.format("/tmp/%s.secret", args[1])
  shell.execute(string.format("generateClientSecret %q %q", clientAdd, secretFileName))

  local secretFile = io.open(secretFileName, "r")
  assert(secretFile, string.format("Could not open file : %s", secretFileName))
  local secretString = secretFile:read("*a")
  secretFile:close()

  fs.remove(secretFileName)

  config.secret = secretString
end

--get the local (server) address
local srvAd = args[2] or "bank.mc"
print("Server address : " .. srvAd)
config.bank_addr = srvAd

local apiConfigFile = io.open(args[1] .. ".conf", "w")
assert(apiConfigFile, string.format("Could not open file : %s.conf", args[1]))
apiConfigFile:write(serialization.serialize(config)):close()
