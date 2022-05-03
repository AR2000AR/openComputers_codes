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
local LABEL_FILE = "/etc/autocraft/label.csv"
local RECIPES_DIR = "/etc/autocraft/recipes.d/"
local COLUMNS = 3
local SCREEN_WIDTH,ROW = component.gpu.getResolution()
SCREEN_WIDTH = math.floor(SCREEN_WIDTH)
ROW = math.floor(ROW-3)

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
    local itemID = targetItem:match("^[^/]+")
    local itemDamage = targetItem:match("%d+")
    if(itemDamage) then itemDamage = tonumber(itemDamage) end
    for item in transposer.getAllStacks(side) do
        if(item.name == itemID and (not itemDamage or itemDamage == item.damage)) then return slot end
        slot = slot +1
    end
    return 0
end

--empty the crafter into the storage
local function emptyCrafter(sideStorage,sideRobot)
    for slot = 1,transposer.getInventorySize(sideRobot) do
        if(transposer.getStackInSlot(sideRobot,slot)) then transposer.transferItem(sideRobot,sideStorage,64,slot) end
    end
end

-- put the items for a recipe in the crafter
local function loadRecipe(recipePatern,sideStorage,sideRobot)
    local craftingGrid = {1,2,3,5,6,7,9,10,11} --crafting grid slot to robot inventory slot
    emptyCrafter(sideStorage,sideRobot)
    for i,item in pairs(recipePatern) do
        local itemID = item:match("^[^/]+")
        local itemDamage = tonumber(item:match("%d+$"))
        if(itemID and itemID ~= "minecraft:air" and itemID ~= "") then
            local itemSlot = findStack(item,sideStorage)
            if(itemSlot == 0) then 
                emptyCrafter(sideStorage,sideRobot) 
                if(itemDamage) then return string.format("%s/%d",itemID,itemDamage) 
                else return itemID end
            end --not enough ressources
            transposer.transferItem(sideStorage,sideRobot,1,itemSlot,craftingGrid[i]) --put
        end
    end
    return true
end

--ask the linked robot to craft and wait for it's answer
local function craft(...)
    component.tunnel.send(...)
    local _,_,_,_,_,m = event.pull(1,"modem_message")
    --timout of 1s in case the event was recived befor we listen for it
    return m
end

--recursive function. Craft a item and it's missing ressouces
local function craftItem(recipes,labels,itemName,sideStorage,sideRobot)
    print("Crafing "..labels[itemName] or itemName)
    local name = itemName:match("^[^/]+")
    local damage = tonumber(itemName:match("%d+$")) or 0
    local craftable = true
    while craftable == true do
        local loaded = loadRecipe(recipes[name][damage],sideStorage,sideRobot)
        if(loaded == true) then
            local crafted = craft("craft")
            emptyCrafter(sideStorage,sideRobot)
            return crafted
        else
            local loadedName = loaded:match("^[^/]+")
            local loadedDamage = tonumber(loaded:match("%d+$"))
            if(recipes[loadedName]) then
                if(not loadedDamage) then 
                    for k,r in pairs(recipes[loadedName]) do
                        craftable = craftItem(recipes,labels,string.format("%s/%d",loadedName,k),sideStorage,sideRobot)
                        if(craftable == true) then break end
                    end
                elseif(recipes[loadedName][loadedDamage]) then
                    craftable = craftItem(recipes,labels,loaded,sideStorage,sideRobot)
                else --do know a recipe for the missing item
                    emptyCrafter(sideStorage,sideRobot)
                    return loaded
                end
            else
                emptyCrafter(sideStorage,sideRobot)
                return loaded
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
            if(not recipes[key]) then recipes[key] = {} end
            for d,patern in pairs(val) do
                recipes[key][d] = patern
            end
        end
    end
end
--load from .d
if(filesystem.isDirectory(RECIPES_DIR)) then
    for file in filesystem.list(RECIPES_DIR) do
        if(string.sub(file,-1) ~= "/") then 
            local rFile = io.open(RECIPES_DIR..file)
            local fileRecipes = serialization.unserialize(rFile:read("*a"))
            rFile:close()
            if(fileRecipes) then
                for key,val in pairs(fileRecipes) do
                    if(not recipes[key]) then recipes[key] = {} end
                    for d,patern in pairs(val) do
                        recipes[key][d] = patern
                    end
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

--load item labels
local labels={}
if(filesystem.exists(LABEL_FILE) and not filesystem.isDirectory(LABEL_FILE)) then
    local lFile = io.open(LABEL_FILE)
    for line in lFile:lines() do
        local name = line:match("^(.*),")
        local label = line:match(",(.*)$")
        labels[name] = label
    end
end

-- main loop
function getRecipesNames(recipes)
    local recipesNames = {}
    for itemID,recipesList in pairs(recipes) do
        for damage,_ in pairs(recipesList) do
            table.insert(recipesNames,string.format("%s/%d",itemID,damage))
        end
    end
    table.sort(recipesNames,function(s1,s2)
        local modID1 = s1:match("^(.*):")
        local modID2 = s2:match("^(.*):")
        local itemID1 = s1:match(":(.*)$")
        local itemID2 = s2:match(":(.*)$")
        if(modID1 == modID2) then --same mod
            return itemID1 < itemID2
        else
            return modID1<modID2
        end
    end)
    return recipesNames
end

recipesNames = getRecipesNames(recipes)
run = true
local pageNumber = 1
local maxPage = 1
while run do

    term.clear()
    if(pageNumber > maxPage) then pageNumber = maxPage end
    if(pageNumber < 1) then pageNumber = 1 end
    maxPage = math.max(1,math.ceil(#recipesNames/(ROW*COLUMNS)))
    
    local firstID=(pageNumber-1)*(ROW*COLUMNS)+1
    local lastID= math.min(pageNumber*(ROW*COLUMNS),#recipesNames)
    
    --print(pageNumber,maxPage,firstID,lastID)

    for i=firstID,lastID do
        io.write(text.padRight(string.sub(i.." : "..(labels[recipesNames[i]] or recipesNames[i]),1,math.floor(SCREEN_WIDTH/COLUMNS)-1),math.floor(SCREEN_WIDTH/COLUMNS)))
        if(i%COLUMNS == 0) then io.write("\n") end
    end
    if(#recipesNames %COLUMNS ~= 0) then io.write("\n") end
    print("Page "..pageNumber.."/"..maxPage)

    io.write("<id>|<new>|<refreshLabels> :")
    local userInput = io.read()
    if(userInput == false) then run = false
    elseif(userInput:match("^p%d$"))then
        pageNumber = tonumber(userInput:match("%d"))
    elseif(tonumber(userInput)) then
        userInput=tonumber(userInput)
        if(userInput >= 1 or userInput <= #recipesNames) then 
            local itemName = recipesNames[userInput]:match("^[^/]+")
            local itemDamage = tonumber(recipesNames[userInput]:match("%d+$")) or 0
            if(recipes[itemName] and recipes[itemName][itemDamage]) then
                io.write("[item count] (default 1) :")
                local count = io.read()
                if(count == false) then goto END_CRAFT
                elseif(not tonumber(count)) then count = 1 end
                local crafted = 0
                for i=1,count do
                    local craftedItem = craftItem(recipes,labels,recipesNames[userInput],sideStorage,sideRobot)
                    if(craftedItem == true) then crafted = crafted+1
                    else print("Missing "..(labels[craftedItem] or craftedItem)) end
                end
                print(string.format("Crafted %d/%d %s",crafted,count,labels[recipesNames[userInput]] or recipesNames[userInput]))
            end
        end
        ::END_CRAFT::
        io.write("Press enter to continue")
        io.read()
    elseif(userInput == "new" or userInput == "n") then
        term.clear()
        print("Reading recipe from robot")
        local newPatern = {}
        local save = ""
        for i,slot in pairs({1,2,3,5,6,7,9,10,11}) do
            local item = transposer.getStackInSlot(sideRobot,slot)
            local itemInf=""
            if(item) then
                print(string.format("slot %d : %s (%s/%d)",i,item.label,item.name,item.damage))
                itemInf=item.name
                repeat
                    if(save ~= "N" and save ~= "Y") then
                        io.write("Save damage y:yes | Y:yes to all | n:no (default) | N:no to all ?")
                        save = io.read()
                    end
                until(save == false or save:match("^[yYnN]$"))
                if(save == false) then goto END_NEW
                elseif(save == "y" or save == "Y") then itemInf=string.format("%s/%d",item.name,item.damage) end
            end
            table.insert(newPatern,itemInf)
        end
        print("Crafting one")
        if(not craft("craft")) then goto END_NEW end
        local newItem = component.transposer.getStackInSlot(sideRobot,1)
        emptyCrafter(sideStorage,sideRobot)
        print("Saving recipe for "..string.format("%s (%s/%d)",newItem.label,newItem.name,newItem.damage))
        --save the label if it does not exists yet
        if(not labels[string.format("%s/%d",newItem.name,newItem.damage)]) then
            labels[string.format("%s/%d",newItem.name,newItem.damage)] = newItem.label
            local lFile = io.open(LABEL_FILE,"a")
            lFile:write(string.format("%s/%d,%s\n",newItem.name,newItem.damage,newItem.label))
            lFile:close()
        end
        if(not recipes[newItem.name]) then recipes[newItem.name] = {} end
        recipes[newItem.name][newItem.damage] = newPatern
        recipesNames = getRecipesNames(recipes)
        --save the new recipe in the main file
        local fRecipes = {}
        if(filesystem.exists(RECIPES_FILE) and not filesystem.isDirectory(RECIPES_FILE)) then
            local rFile = io.open(RECIPES_FILE)
            fRecipes = serialization.unserialize(rFile:read("*a")) or {}
            rFile:close()
        end
        if(not fRecipes[newItem.name]) then fRecipes[newItem.name] = {} end
        fRecipes[newItem.name][newItem.damage] = newPatern
        rFile = io.open(RECIPES_FILE,"w")
        rFile:write(serialization.serialize(fRecipes))
        rFile:close()
        
        ::END_NEW::
    elseif(userInput == "refreshLabels" or userInput == "r") then
        --scan for unknown label
        local lFile = io.open(LABEL_FILE,"a")
        for item in transposer.getAllStacks(sideStorage) do
            if(item and item.name) then
                local itemID = string.format("%s/%d",item.name,item.damage)
                if(not labels[itemID]) then 
                    labels[itemID] = item.label
                    lFile:write(string.format("%s,%s\n",itemID,item.label))
                end
            end
        end
        lFile:close()
    elseif(userInput == "exit" or userInput:match("^[eq]$")) then run = false
    end
end
term.clear()