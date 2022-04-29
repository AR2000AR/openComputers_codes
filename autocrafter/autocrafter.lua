local event = require 'event'
local component = require 'component'
local io = require 'io'
local filesystem = require 'filesystem'
local serialization = require 'serialization'
local string = require 'string'
local term = require 'term'
local text = require 'text'

local transposer = component.transposer

local RECIPES_FILE = "/etc/autocraft/recipes.list"
local RECIPES_DIR = "/etc/autocraft/recipes.d/"
local COLUMNS = 3

--get the keys from a table
local function getKeys(sourceArray)
    local keyset = {}
    for k,v in pairs(sourceArray) do
        table.insert(keyset,k)
    end
    return keyset;     
end

--find item in storage
local function findStack(targetItem,side)
    local slot = 1
    if(type(targetItem) ~= "table") then targetItem = {targetItem,false} end
    for item in transposer.getAllStacks(side) do
        if(item.name == targetItem[1] and (not targetItem[2] or targetItem[2] == item.damage)) then return slot end
        slot = slot +1
    end
    return 0
end

local function emptyCrafter(sideStorage,sideRobot)
    for slot = 1,transposer.getInventorySize(sideRobot) do
        transposer.transferItem(sideRobot,sideStorage,64,slot)
    end
end

local function loadRecipe(recipePatern,sideStorage,sideRobot)
    local craftingGrid = {1,2,3,5,6,7,9,10,11} --crafting grid slot to robot inventory slot
    emptyCrafter(sideStorage,sideRobot)
    for i,item in pairs(recipePatern) do
        if(type(item) ~= "table") then item = {item,false} end
        if(item[1] ~= "minecraft:air" and item[1] ~= "") then
            local itemSlot = findStack(item,sideStorage)
            if(itemSlot == 0) then emptyCrafter(sideStorage,sideRobot) return item end --not enough ressources
            transposer.transferItem(sideStorage,sideRobot,1,itemSlot,craftingGrid[i]) --put
        end
    end
    return true
end

local function craftItem(recipes,itemName,sideStorage,sideRobot)
    print("Crafing "..itemName)
    local craftable = true
    while craftable == true do
        local loaded = loadRecipe(recipes[itemName],sideStorage,sideRobot)
        if(loaded == true) then
            print("Crafted 1 "..itemName)
            component.tunnel.send("craft")
            emptyCrafter(sideStorage,sideRobot)
            return true
        else
            if(recipes[loaded[1]]) then
                craftable = craftItem(recipes,loaded[1],sideStorage,sideRobot)
            else
                emptyCrafter(sideStorage,sideRobot)
                return loaded[1]
            end
        end
    end 
    emptyCrafter(sideStorage,sideRobot)
    return craftable
end

--init
if(not filesystem.exists("/etc/autocraft/")) then filesystem.makeDirectory("/etc/autocraft/") end

--load recipes list
local recipes = {}
if(filesystem.exists(RECIPES_FILE)) then
    local rFile = io.open(RECIPES_FILE)
    local fileRecipes = serialization.unserialize(rFile:read("*a"))
    rFile:close()
    if(fileRecipes) then
        for key,val in pairs(fileRecipes) do
            recipes[key] = val
        end
    end
end
if(filesystem.isDirectory(RECIPES_DIR)) then
    for file in filesystem.list(RECIPES_DIR) do
        if(string.sub(file,-1) ~= "/") then 
            local rFile = io.open(RECIPES_DIR..file)
            local fileRecipes = serialization.unserialize(rFile:read("*a"))
            rFile:close()
            if(fileRecipes) then
                for key,val in pairs(fileRecipes) do
                    recipes[key] = val
                end
            end
        end
    end
end

--find robot and storage sides
local sideRobot = 1
local sideStorage = 2
for i=0,5 do
    local name = transposer.getInventoryName(i)
    if(name) then
        if(name == "opencomputers:robot") then sideRobot = i
        else sideStorage = i end
    end
end

-- main loop
local recipesNames = getKeys(recipes)
event.listen("interrupted",function() run = false return false end)
run = true
local pageNumber = 1
local maxPage = 1
while run do
    maxPage = math.ceil(#recipesNames / 23.0)
    term.clear()
    if(pageNumber > maxPage) then pageNumber = maxPage end
    if(pageNumber < 1) then pageNumber = 1 end
    for i, name in ipairs(recipesNames) do
        io.write(text.padRight(name,math.floor(80/COLUMNS)))
        if(i%COLUMNS == 0) then io.write("\n") end
    end
    if(#recipesNames %COLUMNS ~= 0) then io.write("\n") end
    print("Page "..pageNumber.."/"..maxPage)
    io.write("<item name>|<new> :")
    local itemName = io.read()
    if(tonumber(itemName))then
        pageNumber = tonumber(itemName)
    elseif(itemName == "new") then
        term.clear()
        print("Reading recipe from robot")
        local newPatern = {}
        for i,slot in pairs({1,2,3,5,6,7,9,10,11}) do
            local item = transposer.getStackInSlot(sideRobot,slot)
            local itemInf=""
            if(item) then
                print("slot : "..i,item.name,item.damage)
                itemInf={item.name,false}
                io.write("Save damage yN ?")
                local save = io.read()
                if(save == "y" or save == "Y") then itemInf[2]=item.damage end
            end
            table.insert(newPatern,itemInf)
        end
        local newName = ""
        repeat
            io.write("Craft name :")
            newName = io.read()
        until newName ~= "" and not tonumber(newName) and newName ~= "new" and newName ~= "delete"
        recipes[newName] = newPatern
        recipesNames = getKeys(recipes)
        --save the new recipe in the main file
        local fRecipes = {}
        if(filesystem.exists(RECIPES_FILE) and not filesystem.isDirectory(RECIPES_FILE)) then
            local rFile = io.open(RECIPES_FILE)
            fRecipes = serialization.unserialize(rFile:read("*a"))
            rFile:close()
        end
        fRecipes[newName] = newPatern
        rFile = io.open(RECIPES_FILE,"w")
        rFile:write(serialization.serialize(fRecipes))
        rFile:close()
    elseif(itemName == "delete") then
        term.clear()
        print("Chose a recipe to delete or leave blanc to cancel.\nOnly recipes in the main config file can be deleted that way.\nYou will need to restart the program to apply the changes")
        io.write(">")
        local rName = io.read()
        local fRecipes = {}
        if(filesystem.exists(RECIPES_FILE) and not filesystem.isDirectory(RECIPES_FILE)) then
            local rFile = io.open(RECIPES_FILE)
            fRecipes = serialization.unserialize(rFile:read("*a"))
            rFile:close()
        end
        fRecipes[rName] = nil
        rFile = io.open(RECIPES_FILE,"w")
        rFile:write(serialization.serialize(fRecipes))
        rFile:close()
    elseif(recipes[itemName]) then
        io.write("[item count] (default 1) :")
        local count = io.read()
        if(not tonumber(count)) then count = 1 end
        local crafted = 0
        for i=1,count do
            local craftedItem = craftItem(recipes,itemName,sideStorage,sideRobot)
            if(craftedItem == true) then crafted = crafted+1
            else print("Missing "..craftedItem) end
        end
        print("Crafted "..crafted.."/"..count.." "..itemName)
        io.write("Press enter to continue")
        io.read()
    end
end
term.clear()