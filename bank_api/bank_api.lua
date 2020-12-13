--Bank API by AR2000AR=(AR2000)======
--public api used to comunicate with the bank server.
--=====================================
--LOAD LIB
local event = require("event")
local serialization = require("serialization")
local io = require("io")
--INIT CONST
local BANK_PORT = 351
local CONF_DIR = "/etc/bank/api/"
local CONF_FILE_NAME = CONF_DIR.."api.conf"
local MODEM_TIMEDOUT = -1
--INIT COMPONENT
local modem = require("component").modem
--INIT VAR
local confFile = io.open(CONF_FILE_NAME,"r")
local config = serialization.unserialize(confFile:read("*a"))
confFile:close()
config.bank_addr = config.bank_addr or "ecdc8d43-5e73-4a9c-ba43-051716c71dc8" --fetched from conf file
config.timeout = config.timeout or 5

local bank = {} --table returned by require

--protocole commands constants
local PROTOCOLE_GET_CREDIT = "GET_CREDIT"
local PROTOCOLE_MAKE_TRANSACTION = "MAKE_TRANSACTION"
local PROTOCOLE_NEW_ACCOUNT = "NEW_ACCOUNT"
local PROTOCOLE_NEW_CB = "NEW_CB"
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
local function reciveMessage() --recive a message from the modem component
  local _,_,from,port,_,status,command,message = event.pull(config.timeout,"modem_message")
  if(not status) then status = MODEM_TIMEDOUT end
  if(not command) then command = "" end
  if(not message) then message = "" end
  return status,command,serialization.unserialize(message)
end

--send a request to the server
-- @param requestType:string
-- @param requestData:table
-- @return status:int,command:string,message:table
local function sendRequest(requestType,requestData) --format and send a request to the server
  modem.open(BANK_PORT)
  modem.send(config.bank_addr,BANK_PORT,requestType,serialization.serialize(requestData))
  local status,command,message = reciveMessage()
  modem.close(BANK_PORT)
  return status,command,message
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
  local status,command,message = sendRequest(PROTOCOLE_GET_CREDIT,{cbData=cbData})
  if(status) then
    if(command == PROTOCOLE_GET_CREDIT) then
      if(status==PROTOCOLE_OK) then return 0, message.solde
      elseif(status==PROTOCOLE_NO_ACCOUNT) then return 1, nil
      elseif(status==PROTOCOLE_ERROR_ACCOUNT) then return 2, nil
      elseif(status==PROTOCOLE_ERROR_CB) then return 3, nil
      end
    else
      return -2 --wrong message
    end
  else
    return MODEM_TIMEDOUT --timeout
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
function bank.makeTransaction(uuid_cible,cbData,amount)
  local status,command,msg = sendRequest(PROTOCOLE_MAKE_TRANSACTION,{dst=uuid_cible,cbData=cbData,amount=amount})
  if(command == PROTOCOLE_MAKE_TRANSACTION) then
    return status
  elseif(status) then
    return -2 --wrong message
  else
    return MODEM_TIMEDOUT --timeout
  end
end

function bank.createAccount(secret)
  local status,command,msg = sendRequest(PROTOCOLE_NEW_ACCOUNT,{secret=secret})
  if(command == PROTOCOLE_NEW_ACCOUNT) then
    if(status == PROTOCOLE_OK) then
      return status,msg.uuid
    else
      return status
    end
  elseif(status)then
    return -2
  else
    return MODEM_TIMEDOUT
  end
end

function bank.requestNewCBdata(secret,accountUUID,cbUUID)
  local status,command,msg = sendRequest(PROTOCOLE_NEW_CB,{secret=secret,uuid=accountUUID,cbUUID=cbUUID})
  if(command == PROTOCOLE_NEW_CB) then
    if(status == PROTOCOLE_OK) then
      return status, msg.pin, msg.rawCBdata
    else
      return status
    end
  elseif(status)then
    return -2
  else
    return MODEM_TIMEDOUT
  end
end

--set the modem timeout (in s)
-- @param t:int
function bank.setModemTimeout(t)
  timeout = t
end

return bank
