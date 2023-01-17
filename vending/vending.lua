local gui = require("libGUI")
local filesystem = require("filesystem")
local io = require("io")
local serialization = require("serialization")
local text = require("text")
local event = require("event")
local term = require("term")
---@diagnostic disable-next-line: undefined-field
local sleep = require("os").sleep
local component = require("component")
local transposer = component.transposer
local computer = require("computer")
local libCoin = {} --imported later if required by config
local bank = {} --imported later if required by config
local libCB = {} --imported later if required by config

--make sure we have the required hardware
assert(transposer, "No transposer found")

--constants
local CONFIG_PATH = "/etc/vending/"
local CONFIG_FILE = CONFIG_PATH .. "config.cfg"
local PRODUCT_LIST_FILE = CONFIG_PATH .. "products.csv"
local OUT_PATH = "/var/vending/"
local SALE_STATS = OUT_PATH .. "sales.csv"

local COLUMN_SOLD_ITEM = 1
local COLUMN_SOLD_QTE  = 2
local COLUMN_COST_ITEM = 3
local COLUMN_COST_QTE  = 4
local COLUMN_COST_COIN = 5

--global vars
local config = {}
local products = {}
local availableProduct = {}

--functions definition
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
    local cFile = io.open(CONFIG_FILE, "w")
    assert(cFile, string.format("Could not open : %s", CONFIG_FILE))
    cFile:write(serialization.serialize(config))
    cFile:close()
end

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

local function payInCoin(amount)
    local paid = false
    --check allowed payment method
    if (config.acceptCoin) then
        paid = libCoin.moveCoin(amount, config.chestFront, config.chestBack)
    end
    if (paid) then return paid end
    if (config.acceptCB) then
        local readerComponent = nil
        if (not config.forceDriveEvent and component.isAvailable("drive")) then
            readerComponent = component.drive
        else
            print("Insert CB")
            readerComponent = libCB.waitForCB(config.cbTimeout)
        end
        local encryptedCardData = libCB.loadCB(readerComponent, config.cbTimeout)
        local try = 0
        local cb = false
        if (encryptedCardData) then
            repeat
                io.write("PIN :")
                local pin = term.read(nil, false, nil, "*")
                if (not pin) then print(""); return false end
                pin = pin:gsub("\n", "") --remove newline cause by term.read
                cb = libCB.getCB(encryptedCardData, pin)
                try = try + 1
                print("") --clean new line
            until (cb or try >= 3)
            local res = bank.makeTransaction(config.accountUUID, cb, amount)
            paid = res == 0
            if (not paid) then
                print(({
                          [1] = "NO ACCOUNT",
                          [2] = "ERROR ACCOUNT",
                          [3] = "ERROR CB",
                          [4] = "ERROR AMOUNT",
                          [COLUMN_COST_COIN] = "ERROR_RECEIVING_ACCOUNT",
                          [-1] = "TIMEOUT",
                          [-2] = "WRONG MESSAGE"
                      })[res])
            end
        else
            print("NO CB")
        end
    end
    return paid
end

local function checkItemAvailability(item, amount, side)
    if (not side) then side = config.chestBack end
    assert(item, "No item provided")
    assert(amount and type(amount) == "number", "No or invalid amount")
    assert(not side or type(side) == "number", "Invalid side")
    local foundAmmount = 0
    for chestItem in transposer.getAllStacks(side) do
        if (chestItem.name and itemEquals(item, chestItem)) then
            foundAmmount = foundAmmount + chestItem.size
        end
    end
    return foundAmmount >= amount
end

local function getFreeSpace(side, item)
    checkArg(1, side, "number")
    checkArg(2, item, "nil", "table")
    local stackSize = 64
    local emptyStack = 0
    local freeSpace = 0
    if (item and item.maxSize) then stackSize = item.maxSize end
    for chestItem in transposer.getAllStacks(side) do
        if  (not chestItem.name) then
            emptyStack = emptyStack + 1
        elseif (item and itemEquals(chestItem, item)) then
            stackSize = chestItem.maxSize
            freeSpace = freeSpace + chestItem.maxSize - chestItem.size
        end
    end
    return freeSpace + emptyStack * stackSize
end

local function moveItem(source, sink, item, amount)
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

local function payInItem(item, amount)
    if (checkItemAvailability(item, amount, config.chestFront)) then
        return moveItem(config.chestFront, config.chestBack, item, amount) == amount
    end
end

local function logSale(item, itemQte, unitCost, qte)
    if (not config.logSales) then return end
    checkArg(1, item, "table")
    checkArg(2, itemQte, "number")
    checkArg(3, unitCost, "number", "string")
    checkArg(4, qte, "number")
    assert(item.name, "Invalid item provided")
    local sFile = io.open(SALE_STATS, "a")
    assert(sFile, "Something when terribally wrong with " .. SALE_STATS)
    sFile:write(string.format("%s,%i,%s,%i\n", item.name, itemQte, unitCost, qte))
    sFile:close()
end

local function getSalesCoinTotal()
    local sFile = io.open(SALE_STATS, "r")
    if (not sFile) then return 0 end
    local total = 0
    for line in sFile:lines() do
        local data = parseCSVLine(line, ",")
        if (tonumber(data[3])) then
            total = total + tonumber(data[3]) * tonumber(data[4])
        end
    end
    sFile:close()
    return total
end

--load configurations
if (not filesystem.isDirectory(CONFIG_PATH)) then
    filesystem.makeDirectory(CONFIG_PATH)
end
config = {
    acceptCoin      = true,
    acceptCB        = false,
    chestFront      = 3,
    chestBack       = 2,
    accountUUID     = "",
    exitString      = "exit",
    adminPlayer     = "",
    logSales        = true,
    forceDriveEvent = true,
    cbTimeout       = 30
}
if (filesystem.exists(CONFIG_FILE) and not filesystem.isDirectory(CONFIG_FILE)) then
    local cFile = io.open(CONFIG_FILE, "r")
    assert(cFile, "Something went wrong when reading the config file")
    local tconf = serialization.unserialize(cFile:read("*a")) or {}
    cFile:close()
    for key, val in pairs(tconf) do
        config[key] = val
    end
    cFile:close()
end
saveConfig()
if (config.acceptCoin) then libCoin = require("libCoin") end
if (config.acceptCB) then
    bank = require("bank_api");
    libCB = require("libCB")
end
--load product list
if (filesystem.exists(PRODUCT_LIST_FILE) and not filesystem.isDirectory(PRODUCT_LIST_FILE)) then
    local pFile = io.open(PRODUCT_LIST_FILE, "r")
    assert(pFile, "Something went wrong when reading the product list file")
    local header = false --was the header read ?
    local lineNb = 0
    for line in pFile:lines() do
        lineNb = lineNb + 1
        line = string.gsub(line, " ", "")
        if (header and line ~= "" and line ~= "\n") then
            local productInfo = parseCSVLine(line, ",")
            if (productInfo[1] ~= "") then productInfo[1] = itemFromString(productInfo[1]) else productInfo[1] = false end
            if (productInfo[3] ~= "") then productInfo[3] = itemFromString(productInfo[3]) else productInfo[3] = false end
            productInfo[2] = tonumber(productInfo[2]) or 1
            productInfo[4] = tonumber(productInfo[4]) or false
            productInfo[5] = tonumber(productInfo[5]) or false
            if (productInfo[5] == 0) then productInfo[5] = false end
            assert(productInfo[2], string.format("%s:%i:invalid product data %q\nNo sold item qte", PRODUCT_LIST_FILE, lineNb, line))
            assert(productInfo[4] or productInfo[5], string.format("%s:%i:invalid product data %q\nNo price qte", PRODUCT_LIST_FILE, lineNb, line))
            assert(#productInfo == 5, string.format("%s:%i:invalid product data %q\nNot enough columns", PRODUCT_LIST_FILE, lineNb, line))
            table.insert(products, productInfo)
            table.insert(availableProduct, false)
        end
        header = true --use to skip the header on the first line
    end
    pFile:close()
end
--load items label
for item in transposer.getAllStacks(config.chestBack) do
    if (item.name) then
        for i, product in ipairs(products) do
            if (product[1] and itemEquals(product[1], item)) then
                product[1].label = item.label
            end
            if (product[3] and itemEquals(product[3], item)) then
                product[3].label = item.label
            end
        end
    end
end
if (not filesystem.isDirectory(OUT_PATH)) then
    filesystem.makeDirectory(OUT_PATH)
end

--main
local run = true
while (run) do
    local op = nil
    --user interface loop (draw/input)
    repeat
        --draw the products list
        term.clear()
        for i, product in ipairs(products) do
            local cost = product[COLUMN_COST_COIN]
            if (not product[COLUMN_COST_COIN] or product[COLUMN_COST_COIN] == 0) then
                cost = string.format("%qx%s", product[COLUMN_COST_ITEM].label, product[COLUMN_COST_QTE])
            end
            if (checkItemAvailability(product[COLUMN_SOLD_ITEM], product[COLUMN_SOLD_QTE])) then --filter out unavailable products
                print(string.format("%i : %qx%s (%s)", i, product[COLUMN_SOLD_ITEM].label, product[COLUMN_SOLD_QTE], cost))
            end
        end
        --read user input
        io.write(string.format("1-%i[*qte] >", #products))
        op = io.read("l")
    until (op)

    if (op == "admin") then --admin
        --admin Menu
        local auth = false
        if (config.adminPlayer ~= "") then
            term.clear()
            print("Press any key")
            local _, _, _, _, player = event.pull(10, "key_down")
            if (player and player == config.adminPlayer) then auth = true end
        else auth = true end
        while (auth) do
            --print the interface
            term.clear()
            if (config.logSales) then print(string.format("Coin(s) earned : %i", getSalesCoinTotal())) end
            if (config.acceptCoin) then print(string.format("Coins in back chest : (%i) %i %i %i %i", libCoin.getValue(libCoin.getCoin(config.chestBack)), libCoin.getCoin(config.chestBack))) end
            print("1 : Payment settings")
            print("2 : Unload to front")
            print("3 : Load from front")
            if (config.acceptCoin) then
                print("4 : Unload coins to front")
                print("5 : Load coins from front")
            end
            print("6 : Clear sale data")
            print("7 : Return")
            print(string.format("%q : Exit the program", config.exitString))
            --read user input
            io.write("[1-7] >")
            op = io.read("l")
            if  (op == config.exitString) then --exit
                run = false
                auth = false
            elseif (op == nil) then
                auth = false --exit admin mode
            end
            op = tonumber(op)

            --switch
            if     (op == 1) then --Payment settings
                local subMenu = true
                repeat
                    --interface
                    term.clear()
                    print(string.format("1 : Accept coin (%s)", config.acceptCoin))
                    print(string.format("2 : Accept card (%s)", config.acceptCB))
                    if (config.acceptCB) then
                        print(string.format("3 : Register new owner account (%.9s****-****-****-************)", config.accountUUID))
                        print(string.format("4 : Set card read timeout (%d)", config.cbTimeout))
                    end
                    print("5 : back")
                    io.write("[1-5] >")
                    op = io.read("l")
                    if (op == nil) then subMenu = false end --exit admin mode
                    op = tonumber(op)

                    --switch
                    if     (op == 1) then --toggle acceptCoin
                        config.acceptCoin = not config.acceptCoin
                        saveConfig()
                    elseif (op == 2) then --toggle acceptCB
                        config.acceptCB = not config.acceptCB
                        saveConfig()
                    elseif (config.acceptCB and op == 3) then --register owner bank account
                        term.clear()
                        print("Insert or swipe card")
                        local readerComponent = libCB.waitForCB(config.cbTimeout) --read card
                        if (readerComponent) then --card swipped
                            local encryptedCardData = libCB.loadCB(readerComponent) --load card data to decrypt later
                            local cb = nil
                            local try = 0
                            repeat --ask for pin (3 erros max)
                                io.write("PIN :")
                                local pin = term.read(nil, false, nil, "*")
                                if (not pin) then print(""); return false end
                                pin = pin:gsub("\n", "") --remove newline cause by term.read
                                cb = libCB.getCB(encryptedCardData, pin)
                                try = try + 1
                                print("") --clean new line
                            until (cb or try >= 3)
                            if (cb) then --cb = false if pin is wrong
                                config.accountUUID = cb.uuid
                                saveConfig()
                            end
                        end
                    elseif (config.acceptCB and op == 4) then --card read timout
                        io.write("timout (s) >")
                        op = io.read("l")
                        op = tonumber(op)
                        if (op) then
                            config.cbTimeout = op
                            saveConfig()
                        end
                    elseif (op == 5) then subMenu = false end --exit the submenu
                until (not subMenu)
            elseif (op == 2) then --Back chest unloading
                print("Unloading")
                while (transposer.transferItem(config.chestBack, config.chestFront) ~= 0) do end
            elseif (op == 3) then --Back chest loading
                print("Loading")
                while (transposer.transferItem(config.chestFront, config.chestBack) ~= 0) do end
            elseif (config.acceptCoin and op == 4) then --Unload coins
                libCoin.moveCoin(libCoin.getValue(libCoin.getCoin(config.chestBack)), config.chestBack, config.chestFront)
            elseif (config.acceptCoin and op == 5) then --Load coins
                libCoin.moveCoin(libCoin.getValue(libCoin.getCoin(config.chestFront)), config.chestFront, config.chestBack)
            elseif (config.acceptCoin and op == 6) then --Reset sales info
                if (filesystem.exists(SALE_STATS)) then filesystem.remove(SALE_STATS) end
            elseif (op == 7) then --exit admin mode
                auth = false
            end
        end
    else --sale
        local qte = 1
        op, qte = op:match("([0-9]+)[x\\*]?([0-9]*)")
        op = tonumber(op)
        qte = tonumber(qte) or 1
        if (op and op >= 1 and op <= #products) then
            if (checkItemAvailability(products[op][COLUMN_SOLD_ITEM], products[op][COLUMN_SOLD_QTE] * qte)) then
                --check if there is enough space to give the bought item
                if (getFreeSpace(config.chestFront, products[op][COLUMN_SOLD_ITEM]) >= products[op][COLUMN_SOLD_QTE] * qte) then
                    if (products[op][COLUMN_COST_COIN]) then
                        if (payInCoin(products[op][COLUMN_COST_COIN] * qte)) then
                            moveItem(config.chestBack, config.chestFront, products[op][COLUMN_SOLD_ITEM], products[op][COLUMN_SOLD_QTE] * qte)
                            logSale(products[op][COLUMN_SOLD_ITEM], products[op][COLUMN_SOLD_QTE], products[op][COLUMN_COST_COIN], qte)
                            print(string.format("Sold %i %s for %i coin(s)", products[op][COLUMN_SOLD_QTE] * qte, products[op][COLUMN_SOLD_ITEM].label, products[op][COLUMN_COST_COIN] * qte))
                            computer.beep()
                        else
                            print("No payment")
                        end
                    else
                        if (getFreeSpace(config.chestBack, products[op][COLUMN_COST_ITEM]) >= products[op][COLUMN_COST_QTE] * qte) then
                            if (payInItem(products[op][COLUMN_COST_ITEM], products[op][COLUMN_COST_QTE] * qte)) then
                                moveItem(config.chestBack, config.chestFront, products[op][COLUMN_SOLD_ITEM], products[op][COLUMN_SOLD_QTE] * qte)
                                logSale(products[op][COLUMN_SOLD_ITEM], products[op][COLUMN_SOLD_QTE], string.format("%s*%i", products[op][COLUMN_COST_ITEM].name, products[op][COLUMN_COST_QTE]), qte)
                                print(string.format("Sold %i %s for %i %s", products[op][COLUMN_SOLD_QTE] * qte, products[op][COLUMN_SOLD_ITEM].label, products[op][COLUMN_COST_QTE] * qte, products[op][COLUMN_COST_ITEM].label))
                                computer.beep()
                            else
                                print("Not enough to pay")
                            end
                        else
                            print("Could not accept payment")
                        end
                    end
                else
                    print("Not enough free space in the chest")
                end
            else
                print("UNAVAILABLE")
            end
            print("Press the Return key to continue")
            term.read(nil, true, nil, nil)
        end
    end
end
