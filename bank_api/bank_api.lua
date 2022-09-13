--Bank API by AR2000AR=(AR2000)======
--public api used to comunicate with the bank server.
--=====================================
--LOAD LIB
local event = require("event")
local serialization = require("serialization")
local io = require("io")
local fs = require("filesystem")
--INIT CONST
local BANK_PORT = 351
local CONF_DIR = "/etc/bank/api/"
local CONF_FILE_NAME = CONF_DIR .. "api.conf"
local MODEM_TIMEDOUT = -1
--INIT COMPONENT
local modem = require("component").modem
local data = require("component").data
--INIT VAR

if (not fs.exists(CONF_FILE_NAME)) then
  local file = io.open(CONF_FILE_NAME, "w")
  assert(file, string.format("Something went really wrong when openning : %s", CONF_FILE_NAME))
  file:write(serialization.serialize({bank_addr = "00000000-0000-0000-0000-000000000000", timeout = 5, secret = ""}))
  file:close()
end
local confFile = io.open(CONF_FILE_NAME, "r")
assert(confFile, string.format("Something went really wrong when openning : %s", CONF_FILE_NAME))
local config = serialization.unserialize(confFile:read("*a"))
confFile:close()
config.bank_addr = config.bank_addr or "00000000-0000-0000-0000-000000000000" --fetched from conf file
config.timeout = config.timeout or 5
config.secret = data.decode64(config.secret) or ""



local bank = {} --table returned by require

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
--=====================================
local function reciveMessage() --recive a message from the modem component.
  local _, _, from, port, _, status, command, message = event.pull(config.timeout, "modem_message")
  if (not status) then status = MODEM_TIMEDOUT end
  --make sure no nil value is returned
  if (not command) then command = "" end
  if (not message) then message = "" end
  return status, command, serialization.unserialize(message)
end

--send a request to the server
-- @param requestType:string
-- @param requestData:table
-- @return status:int,command:string,message:table
local function sendRequest(requestType, requestData) --format and send a request to the server
  modem.open(BANK_PORT)
  modem.send(config.bank_addr, BANK_PORT, requestType, serialization.serialize(requestData))
  local status, command, message = reciveMessage()
  modem.close(BANK_PORT)
  return status, command, message
end

--get the account solde
-- @param uuid_cible:string
-- @param cbData:table
-- @param amount:init
-- @return int
--  -1 : timeout
--  -2 : wrong message
--  0 : ok
--  1 : no account
--  2 : account error
--  3 : cb error
-- @return solde
function bank.getCredit(cbData)
  local status, command, message = sendRequest(PROTOCOLE_GET_CREDIT, {cbData = cbData})
  if (status == MODEM_TIMEDOUT) then
    return MODEM_TIMEDOUT
  else
    if (command ~= PROTOCOLE_GET_CREDIT) then
      return -2 --wrong message
    else
      if (status == PROTOCOLE_OK) then
        return 0, message.solde
      else
        return status, nil
      end
    end
  end
end

-- send credit to uuid_cible
-- @param uuid_cible:string
-- @param cbData:table
-- @param amount:init
-- @return int
--  -1 : timeout
--  -2 : wrong message
--  0 : ok
--  1 : no account
--  2 : account error
--  3 : cb error
--  4 : amount error
function bank.makeTransaction(uuid_cible, cbData, amount)
  local status, command, msg = sendRequest(PROTOCOLE_MAKE_TRANSACTION, {dst = uuid_cible, cbData = cbData, amount = amount})
  if (status == MODEM_TIMEDOUT) then
    return MODEM_TIMEDOUT
  else
    if (command ~= PROTOCOLE_MAKE_TRANSACTION) then
      return -2 --wrong message
    else
      return status
    end
  end
end

function bank.createAccount()
  local status, command, msg = sendRequest(PROTOCOLE_NEW_ACCOUNT, {secret = config.secret})
  if (status == MODEM_TIMEDOUT) then
    return MODEM_TIMEDOUT
  else
    if (command ~= PROTOCOLE_NEW_ACCOUNT) then
      return -2 --wrong message
    else
      if (status == PROTOCOLE_OK) then
        return status, msg.uuid
      else
        return status
      end
    end
  end
end

function bank.requestNewCBdata(accountUUID, cbUUID)
  local status, command, msg = sendRequest(PROTOCOLE_NEW_CB, {secret = config.secret, uuid = accountUUID, cbUUID = cbUUID})
  if (status == MODEM_TIMEDOUT) then
    return MODEM_TIMEDOUT
  else
    if (command ~= PROTOCOLE_NEW_CB) then
      return -2 --wrong message
    else
      if (status == PROTOCOLE_OK) then
        return status, msg.pin, msg.rawCBdata
      else
        return status
      end
    end
  end
end

function bank.editAccount(cbData, amount)
  local status, command = sendRequest(PROTOCOLE_EDIT, {secret = config.secret, cbData = cbData, amount = amount})
  if (status == MODEM_TIMEDOUT) then
    return MODEM_TIMEDOUT
  else
    if (command ~= PROTOCOLE_EDIT) then
      return -2 --wrong message
    else
      return status
    end
  end
end

--set the modem timeout (in s)
-- @param t:int
function bank.setModemTimeout(t)
  config.timeout = t
end

return bank
