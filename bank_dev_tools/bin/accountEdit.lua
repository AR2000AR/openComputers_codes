local dataCard = require("component").data
local fs = require("filesystem")
local io = require("io")
local os = require("os")
local serialization = require("serialization")
local shell = require("shell")

local CONF_DIR = "/etc/bank/server/"
local CONF_FILE_NAME = "conf.cfg"
local AES_IV = dataCard.md5("bank")

local keyFile = CONF_DIR .. "key" --default value
local aesKeyFile = CONF_DIR .. "aes" --default value
local accountDir = "/srv/bank/" --default value

local PROTOCOLE_NO_ACCOUNT = 1
local PROTOCOLE_ERROR_ACCOUNT = 2

---load the keys form a file.
---@param public
--- | true # public
--- | false # private
---@return EcKey
local function getKey(public)
  print("-> getKey")
  local ext = ".priv"
  local type = "ec-private"
  if (public) then
    ext = ".pub"
    type = "ec-public"
  end
  local file = io.open(keyFile .. ext, "r")
  assert(file, "No key file found at " .. keyFile)
  local key = dataCard.deserializeKey(dataCard.decode64(file:read("*a")), type)
  file:close()
  print("<- getKey")
  return key
end

local function getAES()
  local file = io.open(aesKeyFile, "r")
  assert(file, "No aes key file found at " .. aesKeyFile)
  local res = file:read("*a")
  file:close()
  return dataCard.decode64(res)
end

local function loadAccount(accountUUID)
  print("-> loadAccount")
  if (fs.exists(accountDir .. accountUUID)) then
    local file = io.open(accountDir .. accountUUID, "r")
    assert(file, "No account " .. accountUUID)
    local rawData = file:read("*a") --read the entire file
    file:close()
    rawData = dataCard.decode64(rawData)
    local clearData = dataCard.decrypt(rawData, getAES(), AES_IV) --decrypt the data
    print("clear data : " .. clearData)
    clearData = serialization.unserialize(clearData) --get the table form the decrypted string
    if (dataCard.ecdsa(clearData.solde .. accountUUID, getKey(true), dataCard.decode64(clearData.sig))) then --check the data signature to prevent manual edition of the file
      print("<- loadAccount sig ok")
      return clearData, clearData;
    else
      print("<- loadAccount sig err")
      return PROTOCOLE_ERROR_ACCOUNT, clearData --signature invalide
    end
  else
    print("<- loadAccount no account")
    return PROTOCOLE_NO_ACCOUNT --account not found
  end
end

-- write the account file
-- @param accountUUID:string
-- @param solde:int
local function writeAccount(accountUUID, solde)
  print("-> writeAccount")
  local account = {solde = solde, uuid = accountUUID}
  account.sig = dataCard.encode64(dataCard.ecdsa(solde .. accountUUID, getKey(false)) --[[@as string]]) --encode sig to make saving it easier
  local fileContent = serialization.serialize(account) --convert the table into a string
  fileContent = dataCard.encrypt(fileContent, getAES(), AES_IV) --encrypt the data
  fileContent = dataCard.encode64(fileContent) --encode the encrypted data to make saving and reading it easier
  io.open(accountDir .. accountUUID, "w"):write(fileContent):close() --save the data
  print("<- writeAccount ")
end

-- handle account edition (check if the account exists and add amount to it's solde)
-- @param uuid:string
-- @param amount:ini
-- @return boolean
local function editAccount(accountUUID, amount)
  local _, account = loadAccount(accountUUID)
  if (account == PROTOCOLE_NO_ACCOUNT or account == PROTOCOLE_ERROR_ACCOUNT) then --check for errors with the account
    return false --give up
  else
    assert(account, "WTF !!!!!")
    writeAccount(account.uuid, account.solde + amount)
    return true
  end
end

--MAIN=================================
if (fs.exists(CONF_DIR .. CONF_FILE_NAME)) then --read the config file
  print("Server configurations file read")
  local file = io.open(CONF_DIR .. CONF_FILE_NAME, "r")
  assert(file, "WHY !!!")
  local confTable = serialization.unserialize(file:read("*a"))
  file:close()
  if (confTable.account_dir) then accountDir = confTable.account_dir end
  if (confTable.aes_key_file) then aesKeyFile = confTable.aes_key_file end
  if (confTable.key_file) then keyFile = confTable.key_file end
else
  io.stderr:write("NO CONFIG FILE FOUND IN " .. CONF_DIR)
  os.exit()
end

local args, opts = shell.parse(...)
if (args[3]) then assert(tonumber(args[3]) ~= nil, "not a number") end
if (args[1] == "get") then
  local ac = loadAccount(args[2])
  if (type(ac) == "number") then
    print("err:" .. ac)
  else
    print(ac.solde)
  end
elseif (args[1] == "set") then
  assert(tonumber(args[3]), "not a number")
  writeAccount(args[2], tonumber(args[3]))
  print("done")
elseif (args[1] == "add") then
  assert(tonumber(args[3]), "not a number")
  editAccount(args[2], tonumber(args[3]))
  print("done")
elseif (args[1] == "remove") then
  assert(tonumber(args[3]), "not a number")
  editAccount(args[2], tonumber(args[3]) * -1)
  print("done")
elseif (args[1] == 'test') then
  local _, clearData = loadAccount(args[2])
  assert(clearData, "Error when loading the account data")
  local b, c
  b = dataCard.ecdsa(clearData.solde .. args[2], getKey(true), dataCard.decode64(clearData.sig))
  c = dataCard.encode64(dataCard.ecdsa(clearData.solde .. args[2], getKey(false)) --[[@as string]])
  print(b)
  print("saved: " .. clearData.sig)
  print("calc : " .. c)
else
  print("accountEdit <get/set/add/remove> <uuid> [ammount]")
end
