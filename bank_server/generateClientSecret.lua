local data = require("component").data
local io = require("io")
local shell = require("shell")
local fs=require("filesystem")
local serialization = require("serialization")

local CONF_DIR = "/etc/bank/server/"
local CONF_FILE_NAME = "conf.cfg"
local keyFile = CONF_DIR.."key" --default value

local function help()
  print("generateClientSecret uuid [file]")
end

local function getKey(public)
  local ext = ".priv"
  local type = "ec-private"
  if(public) then
    ext=".pub"
    type = "ec-public"
  end
  local file = io.open(keyFile..ext,"r")
  local key = data.deserializeKey(data.decode64(file:read("*a")),type)
  file:close()
  return key
end

local args,opts = shell.parse(...)
if(fs.exists(CONF_DIR..CONF_FILE_NAME))then --read the config file
  local file=io.open(CONF_DIR..CONF_FILE_NAME,"r")
  local confTable = serialization.unserialize(file:read("*a"))
  file:close()
  if(confTable.keyFile)then keyFile = confTable.keyFile end
end
if(args[1]) then
  local secret = data.ecdsa(args[1],getKey(false))
  local secretFile = io.open(args[2] or "/home/secret","w")
  secretFile:write(data.encode64(secret))
  secretFile:close()
else
  help()
end
