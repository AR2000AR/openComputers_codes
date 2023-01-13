--libCB by AR2000AR=(AR2000)==========
--manage credit card (unmanaged floppy)
--=====================================
local cb            = {} --table returned by require
local data          = require("component").data --data component used for cryptocraphic stuf
local serialization = require("serialization") --data serialization and unserialization
local event         = require("event")
local proxy         = require("component").proxy
local computer      = require("computer")
local lastMagRead   = {}

local componentSwitch = {
  __call = function(self, componentProxy, ...)
    checkArg(1, componentProxy, "table")
    if self[componentProxy.type] then
      return self[componentProxy.type](componentProxy, ...)
    else
      error("{cbDrive.type} is not a valid component", 2)
    end
  end
}

cb.loadCB = {}
setmetatable(cb.loadCB, componentSwitch)

function cb.loadCB.drive(cbDrive)
  --get the data from the card
  --the card is in unmanaged mode (binary) and the data is writen at the start of
  --the floppy disk
  --read the floppy
  local cbData = cbDrive.readSector(1):gsub("\0", "") --clean null byte after the data
  return {data = cbData, uuid = cbDrive.address, type = "driveData"}
end

local function getRecentMagRead(os_magreader)
  checkArg(1, os_magreader, "table")
  if (not lastMagRead[os_magreader.address]) then return nil end
  if (computer.uptime() - 10 <= lastMagRead[os_magreader.address][1]) then
    lastMagRead[os_magreader.address][1] = 0 --prevent using it again
    return lastMagRead[os_magreader.address][2]
  end
  return nil
end

function cb.loadCB.os_magreader(os_magreader)
  checkArg(1, os_magreader, "table")
  local recent = getRecentMagRead(os_magreader)
  if (recent) then return recent end
  --read the card
  local _, _, _, rawData, cardUUID, _, _ = event.pull("magData", os_magreader.address)
  return {data = rawData, uuid = cardUUID, type = "magDataData"}
end

event.listen("magData", function(eName, eAddr, player, rawData, cardUUID, locked, color) lastMagRead[eAddr] = {computer.uptime(), {data = rawData, uuid = cardUUID, type = "magDataData"}} end)

cb.getCB = {}
setmetatable(cb.getCB, componentSwitch)

--decrypt the card's raw data
--@param rawData:table data returned by loadCB
--@param pin:string card's pin
--@return {uuid,cbUUID,type,sig}
function cb.getCB.driveData(rawData, pin)
  --decrypt it's content
  local clearData = data.decrypt(data.decode64(rawData.data), data.md5(pin), data.md5(rawData.uuid))
  if (not clearData) then return false, "Pin might be wrong" end
  --unserialize the data to use it later
  local cbData = serialization.unserialize(clearData)
  if (not cbData or not cbData.uuid) then return false, "Pin might be wrong" end
  --add the missing card uuid to the data
  cbData.cbUUID = rawData.uuid
  cbData.type = "signed"
  return cbData
end

--decrypt the card's raw data
--@param rawData:table data returned by loadCB
--@param pin:string card's pin
--@return {uuid,cbUUID,type}
function cb.getCB.magDataData(rawData, pin)
  --data format :
  --aesIV(24)data(64)
  --decrypted :
  --uuid(36)"PIN"(3)
  --eventName,componentAddress,Player,data,cardUUID,locked,color
  --decrypt the data
  local clearData = data.decrypt(data.decode64(rawData.data:sub(25)), data.md5(pin), data.decode64(rawData.data:sub(1, 24)))
  if (clearData and #clearData == 39 and clearData:sub(37) == "PIN") then
    return {uuid = clearData:sub(1, 36), cbUUID = rawData.uuid, type = "unsigned"}
  else
    return false
  end
end

--read the credit card data and return it
-- @param cbDrive:proxy the floppy's component
-- @param pin: pin used to decrypt the data
function cb.getCB.drive(cbDrive, pin)
  return cb.getCB(cb.loadCB(cbDrive), pin)
end

--read the credit card data and return it
-- @param cbDrive:proxy the floppy's component
-- @param pin: pin used to decrypt the data
function cb.getCB.os_magreader(cbDrive, pin)
  return cb.getCB.magDataData(cb.loadCB(cbDrive))
end

-- check if the cb is valide
-- @param cbData:table (see man libCB for more info about cbData)
-- @param publicKey:userdata
-- @return boolean
function cb.checkCBdata(cbData, publicKey)
  return cbData.type == "unsigned" or data.ecdsa(cbData.uuid .. cbData.cbUUID, publicKey, data.decode64(cbData.sig))
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
  if (cbUUID) then --for floppy
    local pin = randomPin()
    local aesKey = data.md5(pin)
    local aesIV = data.md5(cbUUID)
    local newCB = {}
    newCB.uuid = uuid
    newCB.sig = data.encode64(data.ecdsa(uuid .. cbUUID, privateKey))
    newCB = data.encode64(data.encrypt(serialization.serialize(newCB), aesKey, aesIV))
    return newCB, pin
  else --magCard
    local pin = randomPin()
    local aesKey = data.md5(pin)
    local aesIV = data.md5(randomPin())
    local newCB = data.encode64(aesIV) .. data.encode64(data.encrypt(uuid .. "PIN", aesKey, aesIV))
    return newCB, pin
  end
end

-- write rawCBdata to a unmanaged floppy or a magcard
-- @param rawCBdata:table the table provided by cb.createNew(...)
-- @param cbDrive:proxy the floppy's component proxy
function cb.writeCB(rawCBdata, cbDrive)
  if     (cbDrive.type == "drive") then
    local buffer = serialization.serialize(rawCBdata)
    cbDrive.writeSector(1, buffer)
    cbDrive.setLabel("CB")
    return true
  elseif (cbDrive.type == "os_cardwriter") then
    return cbDrive.write(rawCBdata, "CB", true, 11) --11 == color.blue
  end
end

return cb --return the table containing all the public functions
