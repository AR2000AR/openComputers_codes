local bank          = require("bank_api")
local filesystem    = require("filesystem")
local io            = require("io")
local serialization = require("serialization")
local event         = require("event")
local libCB         = require("libCB")
local component     = require("component")
local term          = require("term")
local computer      = require("computer")

local transposer    = component.transposer
local gpu           = component.gpu
local disk_drive    = component.disk_drive
local data          = component.data

local CONFIG_PATH   = "/etc/bank/accountMaker/"
local CONFIG_FILE   = CONFIG_PATH .. "config.cfg"
local OUT_PATH      = "/var/bank/accountMaker/"
local ACCOUNT_FILE  = OUT_PATH .. "accounts.csv"
local ERROR_FILE    = OUT_PATH .. "operr.csv"

local config        = {}
local knownAccounts = {}
local run           = true

--FUNCTION DECALARATION========================================================
local function parseCSVLine(line, sep)
    local endReached = false
    local res = {}
    while (not endReached) do
        local i = line:find(sep)
        if (not i) then
            endReached = true
            i = #line + 1
        end
        table.insert(res, line:sub(1, i - 1))
        line = line:sub(i + 1)
    end
    return (res)
end

local function saveConfig()
    --save the config table to a file
    if (config.masterAccountCBdata) then
        ---@type string
        config.masterAccountCBdata = data.encode64(serialization.serialize(config.masterAccountCBdata))
    end
    local cFile = io.open(CONFIG_FILE, "w")
    assert(cFile, string.format("Could not open : %s", CONFIG_FILE))
    cFile:write(serialization.serialize(config))
    cFile:close()
    if (config.masterAccountCBdata) then
        ---@type cardData
        config.masterAccountCBdata = serialization.unserialize(data.decode64(config.masterAccountCBdata --[[@as string]]))
    end
end

local function addToKnonwPlayer(playerName, accountUUID)
    --save the player/account list to a file
    local file = io.open(ACCOUNT_FILE, "a")
    assert(file, "Could not append or create " .. ACCOUNT_FILE)
    file:write(string.format("%s,%s\n", playerName, accountUUID))
    file:close()
    table.insert(knownAccounts, {playerName, accountUUID})
end

---Get the player's account uuid if exists
---@param playerName string
---@return string|boolean
local function getAccountUUID(playerName)
    for _, v in ipairs(knownAccounts) do
        if (v[1] == playerName) then return v[2] end
    end
    return false
end

local function moveItem(source, sink, item, amount)
    local function itemFromString(itemString)
        local name, damage = itemString:match("([^:]+:[^:]+):?([0-9]*)")
        if (damage == "") then damage = "0" end
        damage = tonumber(damage)
        return {
            name = name,
            damage = damage,
            label = name:match(":([^:]+)")
        }
    end

    local function itemEquals(itemA, itemB)
        if (type(itemA) == "string") then itemA = itemFromString(itemA) end
        if (type(itemB) == "string") then itemB = itemFromString(itemB) end
        return itemA.name == itemB.name and itemA.damage == itemB.damage
    end

    assert(type(source) == "number", "Invalid source side")
    assert(type(sink) == "number", "Invalid sink side")
    assert(item, "No item provided")
    amount = amount or 1
    assert(type(amount) == "number", "number expected")
    local slot = 0
    local request = amount
    for chestItem in transposer.getAllStacks(source) do
        slot = slot + 1
        if (chestItem.name and itemEquals(item, chestItem)) then
            amount = amount - transposer.transferItem(source, sink, amount, slot)
        end
        if (amount <= 0) then break end
    end
    return request - amount
end

---Create a new card for the player
---@param playerName string
local function makeCard(playerName)
    term.clear()
    local status
    local newAccount = false

    --#region getaccount

    local acUUID = getAccountUUID(playerName)
    if (not acUUID) then
        print("Making a new account")
        newAccount = true
        ---@diagnostic disable-next-line: cast-local-type
        status, acUUID = bank.createAccount()
        if (status == 0) then --ok
            addToKnonwPlayer(playerName, acUUID)
            if (config.masterAccountCreditPerAccount ~= 0) then
                status = bank.editAccount(config.masterAccountCBdata --[[@as cardData]], config.masterAccountCreditPerAccount)
                if (status ~= 0) then
                    local file = io.open(ERROR_FILE, "a")
                    assert(file, "Can't fail here")
                    file:write(string.format("%i,%s,%i\n", status, "master account", config.newAccountCredit))
                    file:close()
                end
            end
        else
            print("Server did not respond")
            print("Status : " .. status)
            event.pull("touch")
            return
        end
    end

    --#endregion
    --#region writeCard

    if (component.isAvailable("drive")) then
        if (component.drive.getLabel()) then
            disk_drive.eject()
            event.pull("component_unavailable", "drive")
            moveItem(config.sideChest, config.sideDrive, "opencomputers:storage:1", 1)
        end
    end
    if (not component.isAvailable("drive")) then
        moveItem(config.sideChest, config.sideDrive, "opencomputers:storage:1", 1)
    end
    local pin, rawCBdata
    local try = 0
    local goodCB = false
    repeat
        if (not component.isAvailable("drive")) then event.pull("component_available", "drive") end
        print("Requesting CB")
        ---@cast acUUID string
        status, pin, rawCBdata = bank.requestNewCBdata(acUUID, component.drive.address)
        if (status ~= 0) then
            print("ERROR : Could not get rawCBdata\nStatus : " .. status)
        else
            assert(rawCBdata, "Status 0 but no rawCBdata")
            print(string.format("PIN : %q", pin))
            print("Writing CB")
            libCB.writeCB(rawCBdata, component.drive)
            goodCB = libCB.getCB(component.drive, pin)
        end
        try = try + 1
    until (goodCB or try >= 3)

    --#endregion
    --#region initialCredit

    if (try < 3) then
        if (newAccount) then
            if (config.newAccountCredit ~= 0) then
                print("Giving stating credits")
                status = bank.editAccount(libCB.getCB(component.drive, pin), config.newAccountCredit)
                if (status ~= 0) then
                    print("No credit given. Contact admin")
                    local file = io.open(ERROR_FILE, "a")
                    assert(file, "Can't fail here")
                    file:write(string.format("%i,%s,%i\n", status, acUUID, config.newAccountCredit))
                    file:close()
                end
            end
        end
        for i = 1, 3 do computer.beep(nil, 0.25) end
        print("Take your card")
        event.pull("component_unavailable", "drive")
    else
        moveItem(config.sideDrive, config.sideChest, "opencomputers:storage:1", 1)
        print("Can't make a card")
        print("Touch to continue")
        event.pull("touch")
    end

    --#endregion
end

--INIT=========================================================================
--make directory if missing
if (not filesystem.isDirectory(CONFIG_PATH)) then filesystem.makeDirectory(CONFIG_PATH) end
if (not filesystem.isDirectory(OUT_PATH)) then filesystem.makeDirectory(OUT_PATH) end

--default config
config = {
    masterAccountCBdata = "",
    masterAccountCreditPerAccount = 0,
    newAccountCredit = 0,
    sideChest = 1,
    sideDrive = 5
}

--load the config if present
if (filesystem.exists(CONFIG_FILE) and not filesystem.isDirectory(CONFIG_FILE)) then
    local cFile = io.open(CONFIG_FILE, "r")
    assert(cFile, "Something went wrong when reading the config file")
    local tconf = serialization.unserialize(cFile:read("*a")) or {}
    cFile:close()
    for key, val in pairs(tconf) do
        config[key] = val --override default configurations
    end
    cFile:close()
end

--load masterAccountCBdata if present
if (config.masterAccountCBdata and config.masterAccountCBdata ~= "") then
    ---@type cardData
    config.masterAccountCBdata = serialization.unserialize(data.decode64(config.masterAccountCBdata))
end

--register master cb on first boot
if (config.masterAccountCBdata == "") then
    print("Insert master cb to register it")
    local reader = libCB.waitForCB(5)
    if (reader) then
        local encryptedData = libCB.loadCB(reader)
        local try = 0
        local pin
        repeat
            try = try + 1
            io.write("Enter pin : ")
            pin = term.read({pwchar = "*"})
            pin = pin:gsub("\n", "")
        until (pin or try >= 3)
        local cb = libCB.getCB(encryptedData, pin)
        if (cb) then
            config.masterAccountCBdata = cb
            computer.beep()
        else
            ---@diagnostic disable-next-line: assign-type-mismatch
            config.masterAccountCBdata = nil
            computer.beep()
            computer.beep()
        end
    else
        config.masterAccountCBdata = nil
        computer.beep()
        computer.beep()
    end
end

saveConfig()

-- load already created account list
if (filesystem.exists(ACCOUNT_FILE)) then
    local aFile = io.open(ACCOUNT_FILE, 'r')
    assert(aFile, "No account file found. HOW !?")
    for line in aFile:lines() do
        line = string.gsub(line, " ", "")
        line = parseCSVLine(line, ",")
        table.insert(knownAccounts, {line[1], line[2]})
    end
end

-- init screen
local old_res_x, old_res_y = gpu.getResolution()
gpu.setResolution(26, 13)

--listen for ctrl+c (interrupted)
event.listen("interrupted", function()
    run = false;
    return false
end)
--MAIN LOOP====================================================================
while (run) do
    term.clear()
    print("Touch the screen")
    print("to get a card")
    local e, _, _, _, _, playerName = event.pull(1, "touch")
    if (e) then
        makeCard(playerName)
    end
end
--restore old screen resolution
gpu.setResolution(old_res_x, old_res_y)
