local io = require("io")
local shell = require("shell")
local os = require("os")
local component = require("component")
local event = require("event")
local term = require("term")
local serialization = require("serialization")

local config = {secret = "", timeout = 5, bank_addr = ""}

local args, opts = shell.parse(...)
if (#args ~= 1 or opts["h"]) then
  print("generateClientSecret clientName")
  os.exit(1)
end

--get the local (server) address
local localModemAdd = component.modem.address
print("Server address : " .. localModemAdd)

--get the future client address
local clientModemAdd = localModemAdd
while (clientModemAdd == localModemAdd) do
  print("Replace the network card with the client one")
  event.pull(10, "component_available")
  clientModemAdd = component.modem.address
  if (clientModemAdd == localModemAdd) then
    print("Error : same network card")
    term.write("Cancel [y/N]")
    local userInput = term.read()
    if (userInput == "y\n" or userInput == "Y\n") then
      os.exit(1)
    end
  end
end
print("Client address : " .. clientModemAdd)

shell.execute("generateClientSecret " .. clientModemAdd .. " " .. args[1] .. ".secret")
local secretFile = io.open(args[1] .. ".secret", "r")
assert(secretFile, string.format("Could not open file : %s.secret", args[1]))
local secretString = secretFile:read("*a")
secretFile:close()

config.bank_addr = localModemAdd
config.secret = secretString

local apiConfigFile = io.open(args[1] .. ".conf", "w")
assert(apiConfigFile, string.format("Could not open file : %s.conf", args[1]))
apiConfigFile:write(serialization.serialize(config)):close()
