--libCB by AR2000AR=(AR2000)==========
--manage credit card (unmanaged floppy)
--=====================================
local cb = {} --table returned by require
local data = require("component").data --data component used for cryptocraphic stuf
local serialization = require("serialization") --data serialization and unserialization

--read the credit card data and return it
-- @param cbDrive:proxy the floppy's component
local function readCB(cbDrive)
  local i = 1
  --get the data from the card
  --the card is in unmanaged mode (binary) and the data is writen at the start of
  --the floppy disk
  local rawData = cbDrive.readSector(1):gsub("\0", "") --clean null byte after the data
  local cbData = serialization.unserialize(rawData)
  if (not cbData or not cbData.uuid or not cbData.pin_check) then return false end
  cbData.cbUUID = cbDrive.address
  return cbData
end

function cb.getCB(cbDrive, pin)
  local res = readCB(cbDrive)
  if (not res) then return false end
  res.uuid = data.decrypt(data.decode64(res.uuid), data.md5(res.cbUUID), data.md5(pin))
  local pin_check = false
  pin_check = data.decrypt(data.decode64(res.pin_check), data.md5(res.cbUUID), data.md5(pin)) == "PIN"
  if (pin_check) then
    return res
  else
    return false
  end
end

-- check if the cb is valide
-- @param cbData:table (see man libCB for more info about cbData)
-- @param publicKey:userdata
-- @return boolean
function cb.checkCBdata(cbData, publicKey)
  return data.ecdsa(cbData.uuid .. cbData.cbUUID .. cbData.pin_check, publicKey, data.decode64(cbData.sig))
end

-- generate a random 4 digit pin
-- @return string
local function randomPin()
  local pin = "" .. math.floor(math.random(9999))
  while (#pin < 4) do
    pin = "0" .. pin
  end
  return pin
end

-- create a new rawCBdata
-- @param uuid:string account uuid
-- @param cbUUID:string new cb's uuid
-- @param privateKey:userdata key used to sign the cb
-- @retrun rawCBdata:table
-- @return pin:string
function cb.createNew(uuid, cbUUID, privateKey)
  local pin = randomPin()
  local aesKey = data.md5(cbUUID)
  local aesIV = data.md5(pin)
  local newCB = {}
  newCB.uuid = data.encode64(data.encrypt(uuid, aesKey, aesIV))
  newCB.pin_check = data.encode64(data.encrypt("PIN", aesKey, aesIV))
  newCB.sig = data.ecdsa(uuid .. cbUUID .. newCB.pin_check, privateKey)
  newCB.sig = data.encode64(newCB.sig)
  return newCB, pin
end

-- write rawCBdata to a unmanaged floppy
-- @param rawCBdata:table the table provided by cb.createNew(...)
-- @param cbDrive:proxy the floppy's component proxy
function cb.writeCB(rawCBdata, cbDrive)
  local buffer = serialization.serialize(rawCBdata)
  cbDrive.writeSector(1, buffer)
  cbDrive.setLabel("CB")
end

return cb --return the table containing all the public functions
