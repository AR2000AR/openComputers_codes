--Bank server by AR2000AR=(AR2000)===
--
--=====================================
--IMPORT standard lib------------------
local dataCard = require("component").data
local modem = require("component").modem
local event = require("event")
local fs = require("filesystem")
local os = require("os")
local io = require("io")
local uuid = require("uuid")
local serialization = require("serialization")
local uuid = require("uuid")
--IMPORT custom lib--------------------
local cb = require("libCB")
--=====================================
--INIT constants-----------------------
local CONF_DIR = "/etc/bank/server/"
local CONF_FILE_NAME = "conf.cfg"
local SERVER_PORT = 351
local AES_IV = dataCard.md5("bank")

--INIT config default values
local keyFile = CONF_DIR .. "key" --default value
local aesKeyFile = CONF_DIR .. "aes" --default value
local accountDir = "/srv/bank/account/" --default value
local verbose = false --change it in rc.cfg
--protocole commands constants
local PROTOCOLE_GET_CREDIT = "GET_CREDIT"
local PROTOCOLE_MAKE_TRANSACTION = "MAKE_TRANSACTION"
local PROTOCOLE_NEW_ACCOUNT = "NEW_ACCOUNT"
local PROTOCOLE_NEW_CB = "NEW_CB"
local PROTOCOLE_EDIT = "EDIT"
--protocole status constants
local PROTOCOLE_OK = 0
local PROTOCOLE_NO_ACCOUNT = 1
local PROTOCOLE_ERROR_ACCOUNT = 2
local PROTOCOLE_ERROR_CB = 3
local PROTOCOLE_ERROR_AMOUNT = 4
local PROTOCOLE_DENIED = 4
local PROTOCOLE_ERROR_RECEIVING_ACCOUNT = 5
local PROTOCOLE_ERROR_UNKNOWN = 999
---------------------------------------

local function log(msg)
  if (verbose) then io.open("/tmp/bank_server.log", "a"):write("\n" .. msg):flush():close() end
end

local function sendMsg(add, status, command, msg) --serialize and send msg to the client
  msg = serialization.serialize(msg)
  modem.send(add, SERVER_PORT, status, command, msg)
end

-- return a key for later use with the data component
-- @param public:boolean
-- @return public or private key for this server
local function getKey(public)
  log("-> getKey")
  local ext = ".priv"
  local type = "ec-private"
  if (public) then
    ext = ".pub"
    type = "ec-public"
  end
  local file = io.open(keyFile .. ext, "r")
  assert(file, "No key file " .. keyFile .. ext)
  local key = dataCard.deserializeKey(dataCard.decode64(file:read("*a")), type)
  file:close()
  log("<- getKey")
  return key
end

-- read the aes key from a file (filename in aesKeyFile)
-- @return binary
local function getAES()
  local file = io.open(aesKeyFile, "r")
  assert(file, "No aes key file " .. aesKeyFile)
  local res = file:read("*a")
  file:close()
  return dataCard.decode64(res)
end

-- return a given account
-- @param uuid:string
-- @return {solde,uuid} or PROTOCOLE_NO_ACCOUNT or PROTOCOLE_ERROR_ACCOUNT
local function loadAccount(accountUUID)
  log("-> loadAccount")
  local account = {}
  if (fs.exists(accountDir .. accountUUID)) then
    local file = io.open(accountDir .. accountUUID, "r")
    assert(file, "No account file " .. accountDir .. accountUUID)
    local rawData = file:read("*a") --read the entire file
    file:close()
    rawData = dataCard.decode64(rawData)
    local clearData = dataCard.decrypt(rawData, getAES(), AES_IV) --decrypt the data
    log("clear data : " .. clearData)
    clearData = serialization.unserialize(clearData) --get the table form the decrypted string
    if (dataCard.ecdsa(clearData.solde .. accountUUID, getKey(true), dataCard.decode64(clearData.sig))) then --check the data signature to prevent manual edition of the file
      log("<- loadAccount sig ok")
      return clearData;
    else
      log("<- loadAccount sig err")
      return PROTOCOLE_ERROR_ACCOUNT --signature invalide
    end
  else
    log("<- loadAccount no account")
    return PROTOCOLE_NO_ACCOUNT --account not found
  end
end

-- write the account file
-- @param accountUUID:string
-- @param solde:int
local function writeAccount(accountUUID, solde)
  log("-> writeAccount")
  local account = {solde = solde, uuid = accountUUID}
  account.sig = dataCard.encode64(dataCard.ecdsa(solde .. accountUUID, getKey(false))) --encode sig to make saving it easier
  local fileContent = serialization.serialize(account) --convert the table into a string
  fileContent = dataCard.encrypt(fileContent, getAES(), AES_IV) --encrypt the data
  fileContent = dataCard.encode64(fileContent) --encode the encrypted data to make saving and reading it easier
  io.open(accountDir .. accountUUID, "w"):write(fileContent):close() --save the data
  log("<- writeAccount ")
end

-- handle account edition (check if the account exists and add amount to it's solde)
-- @param uuid:string
-- @param amount:ini
-- @return boolean
local function editAccount(accountUUID, amount)
  local account = loadAccount(accountUUID)
  if (account == PROTOCOLE_NO_ACCOUNT or account == PROTOCOLE_ERROR_ACCOUNT) then --check for errors with the account
    return false --give up
  else
    writeAccount(account.uuid, account.solde + amount)
    return true
  end
end

-- handle account creation
-- @param address:string
-- @param from:string
-- @param to:string
-- @param amount:int
local function handlerMakeTransaction(address, from, to, amount)
  log("-> handlerMakeTransaction")
  amount = tonumber(amount)
  local fromAccount = loadAccount(from)
  if (fromAccount == PROTOCOLE_NO_ACCOUNT or fromAccount == PROTOCOLE_ERROR_ACCOUNT) then --check for errors with the first account
    sendMsg(address, fromAccount, PROTOCOLE_MAKE_TRANSACTION)
  else
    if (fromAccount.solde >= amount) then
      local toAccount = loadAccount(to)
      if (toAccount == PROTOCOLE_NO_ACCOUNT or toAccount == PROTOCOLE_ERROR_ACCOUNT) then --check for errors with the second account
        sendMsg(address, PROTOCOLE_ERROR_RECEIVING_ACCOUNT, PROTOCOLE_MAKE_TRANSACTION)
      else
        ---@diagnostic disable-next-line:param-type-mismatch
        if (editAccount(fromAccount.uuid, (-1 * math.abs(amount))) and editAccount(toAccount.uuid, (math.abs(amount)))) then
          sendMsg(address, PROTOCOLE_OK, PROTOCOLE_MAKE_TRANSACTION)
        else
          sendMsg(address, PROTOCOLE_ERROR_UNKNOWN, PROTOCOLE_MAKE_TRANSACTION)
        end
      end
    else
      log("secret error")
      sendMsg(address, PROTOCOLE_ERROR_AMOUNT, PROTOCOLE_MAKE_TRANSACTION)
    end
  end
  log("<- handlerMakeTransaction")
end

-- handle account creation
-- @param address:string
-- @param secret:string
local function handlerCreateAccount(address, secret)
  log("-> handlerCreateAccount")
  if (dataCard.ecdsa(address, getKey(true), secret)) then --check if the client have the write to call this command
    local newUUID
    repeat
      newUUID = uuid.next()
    until not fs.exists(accountDir .. newUUID)
    writeAccount(newUUID, 0)
    sendMsg(address, PROTOCOLE_OK, PROTOCOLE_NEW_ACCOUNT, {uuid = newUUID})
  else
    log("secret error")
    sendMsg(address, PROTOCOLE_DENIED, PROTOCOLE_NEW_ACCOUNT)
  end
  log("<- handlerCreateAccount")
end

-- handle the PROTOCOLE_GET_CREDIT messages
-- @param address:string
-- @param cbData:table (cbData)
local function handlerGetCredit(address, cbData)
  log("-> handlerGetCredit")
  local account = loadAccount(cbData.uuid)
  if (account == PROTOCOLE_NO_ACCOUNT or account == PROTOCOLE_ERROR_ACCOUNT) then
    sendMsg(address, account, PROTOCOLE_GET_CREDIT, {solde = 0}) --error
  else
    sendMsg(address, PROTOCOLE_OK, PROTOCOLE_GET_CREDIT, {solde = account.solde}) --ok
  end
  log("<- handlerGetCredit")
end

local function hanlerMakeCreditCard(address, secret, targetUUID, cbUUID)
  log("-> hanlerMakeCreditCard")
  if (dataCard.ecdsa(address, getKey(true), secret)) then --check if the client have the write to call this command
    local account = loadAccount(targetUUID)
    log("account " .. serialization.serialize(account, true))
    if (account == PROTOCOLE_NO_ACCOUNT or account == PROTOCOLE_ERROR_ACCOUNT) then -- check if the account exists
      log("error " .. account)
      sendMsg(address, account, PROTOCOLE_NEW_CB) --error
    else
      log("-> cb.createNew")
      local rawCBdata, pin = cb.createNew(targetUUID, cbUUID, getKey(false))
      log("<- cb.createNew")
      log("rawCBdata : " .. serialization.serialize(rawCBdata, true))
      sendMsg(address, PROTOCOLE_OK, PROTOCOLE_NEW_CB, {pin = pin, rawCBdata = rawCBdata}) --ok
    end
  else
    sendMsg(address, PROTOCOLE_DENIED, PROTOCOLE_NEW_CB) --error
  end
  log("<- hanlerMakeCreditCard")
end

local function handlerEditBalance(address, secret, targetUUID, amount)
  log("-> hanglerEditBalance")
  if (dataCard.ecdsa(address, getKey(true), secret)) then --check if the client have the write to call this command
    local account = loadAccount(targetUUID)
    log("account " .. serialization.serialize(account, true))
    if (account == PROTOCOLE_NO_ACCOUNT or account == PROTOCOLE_ERROR_ACCOUNT) then -- check if the account exists
      log("error " .. account)
      sendMsg(address, account, PROTOCOLE_EDIT) --error
    else
      if (amount < 0) then
        if (account.solde < math.abs(amount)) then
          sendMsg(address, PROTOCOLE_ERROR_AMOUNT, PROTOCOLE_EDIT)
        else
          if (editAccount(account.uuid, amount)) then
            sendMsg(address, PROTOCOLE_OK, PROTOCOLE_EDIT)
          else
            sendMsg(address, PROTOCOLE_ERROR_UNKNOWN, PROTOCOLE_EDIT)
          end
        end
      else
        if (editAccount(account.uuid, amount)) then
          sendMsg(address, PROTOCOLE_OK, PROTOCOLE_EDIT)
        else
          sendMsg(address, PROTOCOLE_ERROR_UNKNOWN, PROTOCOLE_EDIT)
        end
      end
    end
  else
    log("secret error")
    sendMsg(address, PROTOCOLE_DENIED, PROTOCOLE_EDIT)
  end
  log("<- hanglerEditBalance")
end

-- main function
local function listener(sig, local_add, remote_add, port, dist, command, arg)
  if (sig ~= "modem_message") then return end --check the signal type
  if (port ~= SERVER_PORT) then return end --check if the port is the correct one
  if (not command or not arg) then return end --check if a parameter is missing

  log("==> " .. remote_add .. " " .. command .. " " .. arg)
  arg = serialization.unserialize(arg)
  -------------------------------------
  if     (command == PROTOCOLE_GET_CREDIT) then
    log(arg.cbData.uuid .. arg.cbData.cbUUID)
    if (cb.checkCBdata(arg.cbData, getKey(true))) then
      handlerGetCredit(remote_add, arg.cbData)
    else
      log("PROTOCOLE_GET_CREDIT : error cb")
      sendMsg(remote_add, PROTOCOLE_ERROR_CB, PROTOCOLE_GET_CREDIT)
    end
    -------------------------------------
  elseif (command == PROTOCOLE_MAKE_TRANSACTION) then
    if (cb.checkCBdata(arg.cbData, getKey(true))) then
      handlerMakeTransaction(remote_add, arg.cbData.uuid, arg.dst, arg.amount)
    else
      log("PROTOCOLE_MAKE_TRANSACTION : error cb")
      sendMsg(remote_add, PROTOCOLE_ERROR_CB, command)
    end
    -------------------------------------
  elseif (command == PROTOCOLE_NEW_ACCOUNT) then
    handlerCreateAccount(remote_add, arg.secret)
    -------------------------------------
  elseif (command == PROTOCOLE_NEW_CB) then
    hanlerMakeCreditCard(remote_add, arg.secret, arg.uuid, arg.cbUUID)
    -------------------------------------
  elseif (command == PROTOCOLE_EDIT) then
    if (cb.checkCBdata(arg.cbData, getKey(true))) then
      handlerEditBalance(remote_add, arg.secret, arg.cbData.uuid, arg.amount)
    else
      log("PROTOCOLE_EDIT : error cb")
      sendMsg(remote_add, PROTOCOLE_ERROR_CB, command)
    end
  else
    log("Unknown error : " .. command)
    --TODO : error handling
  end
end

---@diagnostic disable-next-line: lowercase-global
function start(msg) --start the service
  if (args == "verbose") then
    verbose = true
    log("==========verbose on==========")
  end

  fs.makeDirectory(CONF_DIR)
  if (fs.exists(CONF_DIR .. CONF_FILE_NAME)) then --read the config file
    local file = io.open(CONF_DIR .. CONF_FILE_NAME, "r")
    assert(file, "No config file " .. CONF_DIR .. CONF_FILE_NAME)
    local confTable = serialization.unserialize(file:read("*a"))
    file:close()
    if (confTable.account_dir) then accountDir = confTable.account_dir end
    if (confTable.aes_key_file) then aesKeyFile = confTable.aes_key_file end
    if (confTable.key_file) then keyFile = confTable.key_file end
  else --if the config file doesn't exists create a new one with the defaults values
    local file = io.open(CONF_DIR .. CONF_FILE_NAME, "w")
    assert(file, "No config file " .. CONF_DIR .. CONF_FILE_NAME)
    file:write(serialization.serialize({account_dir = accountDir, aes_key_file = aesKeyFile, key_file = keyFile}))
    file:close()
  end
  fs.makeDirectory(accountDir)
  if (not fs.exists(aesKeyFile)) then -- create a new aes key if no key is present
    log("generating aes key")
    io.open(aesKeyFile, "w"):write(dataCard.encode64(dataCard.md5(dataCard.random(128)))):close()
  end
  if (not fs.exists(keyFile .. ".priv")) then -- create a new key paire if the private one is absent
    log("generating key pair")
    --TODO : check for the public one
    local pub, priv = dataCard.generateKeyPair()
    --keys are encoded (base64) for easy reading and writing to a file
    io.open(keyFile .. ".pub", "w"):write(dataCard.encode64(pub.serialize())):close()
    io.open(keyFile .. ".priv", "w"):write(dataCard.encode64(priv.serialize())):close()
  end

  event.listen("modem_message", listener) --register the listener for modem_message
  modem.open(SERVER_PORT)
end

---@diagnostic disable-next-line: lowercase-global
function stop()
  event.ignore("modem_message", listener) --delete the listener
  modem.close(SERVER_PORT)
end
