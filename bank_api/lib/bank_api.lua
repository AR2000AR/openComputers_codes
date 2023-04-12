--Bank API by AR2000AR=(AR2000)======
--public api used to comunicate with the bank server.
--=====================================
--LOAD LIB
local event = require("event")
local serialization = require("serialization")
local io = require("io")
local fs = require("filesystem")
local socket = require("socket")
--INIT CONST
local BANK_PORT = 351
local CONF_DIR = "/etc/bank/api/"
local CONF_FILE_NAME = CONF_DIR .. "api.conf"
local MODEM_TIMEDOUT = -1
--INIT COMPONENT
local data = require("component").data
--INIT VAR

if (not fs.exists(CONF_FILE_NAME)) then
  fs.makeDirectory(CONF_DIR)
  local file = io.open(CONF_FILE_NAME, "w")
  assert(file, string.format("Something went really wrong when openning : %s", CONF_FILE_NAME))
  file:write(serialization.serialize({bank_addr = "bank.mc", timeout = 5, secret = ""}))
  file:close()
end
local confFile = io.open(CONF_FILE_NAME, "r")
assert(confFile, string.format("Something went really wrong when openning : %s", CONF_FILE_NAME))
local config = serialization.unserialize(confFile:read("*a"))
confFile:close()
config.bank_addr = config.bank_addr or "bank.mc" --fetched from conf file
config.timeout = config.timeout or 5
config.secret = data.decode64(config.secret) or ""


---@class bankapi
local bank = {} --table returned by require

local PROTOCOLE = {}
---protocole commands
---@enum ProtocoleCommand
PROTOCOLE.COMMAND = {
  GET_CREDIT = "GET_CREDIT",
  MAKE_TRANSACTION = "MAKE_TRANSACTION",
  NEW_ACCOUNT = "NEW_ACCOUNT",
  NEW_CB = "NEW_CB",
  EDIT = "EDIT",
  NONE = ""
}
---protocole status
---@enum ProtocoleStatus
PROTOCOLE.STATUS = {
  MODEM_TIMEDOUT          = MODEM_TIMEDOUT,
  OK                      = 0,
  NO_ACCOUNT              = 1,
  ERROR_ACCOUNT           = 2,
  ERROR_CB                = 3,
  ERROR_AMOUNT            = 4,
  DENIED                  = 4,
  ERROR_RECEIVING_ACCOUNT = 5,
  ERROR_UNKNOWN           = 999,
}
---@enum CommandStatus
bank.STATUS = {
  TIMEOUT                 = PROTOCOLE.STATUS.MODEM_TIMEDOUT,
  WRONG_MESSAGE           = -2,
  OK                      = PROTOCOLE.STATUS.OK,
  NO_ACCOUNT              = PROTOCOLE.STATUS.NO_ACCOUNT,
  ACCOUNT_ERROR           = PROTOCOLE.STATUS.ERROR_ACCOUNT,
  CARD_ERROR              = PROTOCOLE.STATUS.ERROR_CB,
  AMOUNT_ERROR            = PROTOCOLE.STATUS.ERROR_AMOUNT,
  DENIED                  = PROTOCOLE.STATUS.DENIED,
  RECIVEING_ACCOUNT_ERROR = PROTOCOLE.STATUS.ERROR_RECEIVING_ACCOUNT,
  UNKNOWN                 = PROTOCOLE.STATUS.ERROR_UNKNOWN
}
--=====================================

---send a request to the server
---@param requestType string
---@param requestData table
---@return ProtocoleStatus status,string command ,table message
local function sendRequest(requestType, requestData) --format and send a request to the server
  local clientSocket = socket.udp()
  clientSocket:setpeername(assert(socket.dns.toip(config.bank_addr)), BANK_PORT)
  clientSocket:settimeout(config.timeout)
  clientSocket:send(serialization.serialize(table.pack(requestType, serialization.serialize(requestData))))
  local response = clientSocket:recieve()
  clientSocket:close()
  if (response) then
    local status, command, message = table.unpack(serialization.unserialize(response))
    return status, command, serialization.unserialize(message)
  else
    return MODEM_TIMEDOUT, PROTOCOLE.COMMAND.NONE, {""}
  end
end

---get the account solde
---@param cbData cardData
---@return CommandStatus status, number|nil balance
function bank.getCredit(cbData)
  local status, command, message = sendRequest(PROTOCOLE.COMMAND.GET_CREDIT, {cbData = cbData})
  if (status == MODEM_TIMEDOUT) then
    return bank.STATUS.TIMEOUT
  else
    if (command ~= PROTOCOLE.COMMAND.GET_CREDIT) then
      return bank.STATUS.WRONG_MESSAGE
    else
      if (status == PROTOCOLE.STATUS.OK) then
        return bank.STATUS.OK, message.solde
      else
        return status, nil
      end
    end
  end
end

---send credit to uuid_cible
---@param uuid_cible string
---@param cbData cardData
---@param amount number
---@return CommandStatus status
function bank.makeTransaction(uuid_cible, cbData, amount)
  local status, command, msg = sendRequest(PROTOCOLE.COMMAND.MAKE_TRANSACTION, {dst = uuid_cible, cbData = cbData, amount = amount})
  if (status == MODEM_TIMEDOUT) then
    return MODEM_TIMEDOUT
  else
    if (command ~= PROTOCOLE.COMMAND.MAKE_TRANSACTION) then
      return -2 --wrong message
    else
      return status
    end
  end
end

---create a new account
---@return CommandStatus status, string|nil accountUUID
function bank.createAccount()
  local status, command, msg = sendRequest(PROTOCOLE.COMMAND.NEW_ACCOUNT, {secret = config.secret})
  if (status == MODEM_TIMEDOUT) then
    return MODEM_TIMEDOUT
  else
    if (command ~= PROTOCOLE.COMMAND.NEW_ACCOUNT) then
      return -2 --wrong message
    else
      if (status == PROTOCOLE.STATUS.OK) then
        return status, msg.uuid
      else
        return status
      end
    end
  end
end

---Request data to write a new debit card from the server
---If cbUUID is not provided, the server will send less and unsigned data
---@param accountUUID string
---@param cbUUID? string
---@return CommandStatus status, string|nil pin, string|nil rawCBdata
function bank.requestNewCBdata(accountUUID, cbUUID)
  local status, command, msg = sendRequest(PROTOCOLE.COMMAND.NEW_CB, {secret = config.secret, uuid = accountUUID, cbUUID = cbUUID})
  if (status == MODEM_TIMEDOUT) then
    return MODEM_TIMEDOUT
  else
    if (command ~= PROTOCOLE.COMMAND.NEW_CB) then
      return -2 --wrong message
    else
      if (status == PROTOCOLE.STATUS.OK) then
        return status, msg.pin, msg.rawCBdata
      else
        return status
      end
    end
  end
end

---Edit (add or remove) the account's balance
---@param cbData cardData
---@param amount number
---@return CommandStatus status
function bank.editAccount(cbData, amount)
  local status, command = sendRequest(PROTOCOLE.COMMAND.EDIT, {secret = config.secret, cbData = cbData, amount = amount})
  if (status == MODEM_TIMEDOUT) then
    return MODEM_TIMEDOUT
  else
    if (command ~= PROTOCOLE.COMMAND.EDIT) then
      return -2 --wrong message
    else
      return status
    end
  end
end

---set the modem timeout (in s)
---@param t number
function bank.setModemTimeout(t)
  config.timeout = t
end

return bank
