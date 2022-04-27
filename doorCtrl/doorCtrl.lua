local sides = require 'sides'
local gui = require 'libGUI'
local class = require 'libClass'
local component = require 'component'
local filesystem = require 'filesystem'
local serialization = require 'serialization'
local shell = require 'shell'
local string = require 'string'
local io = require 'io'
local os = require 'os'
local term = require 'term'
local beep = require('computer').beep
local event = require 'event'

-- constants
local CONFIG_FILE = '/etc/doorCtrl.conf'
local LOG_FILE = '/tmp/doorCtrl.log'

local args,ops = shell.parse(...)

--get the keys from a table
local function getKeys(sourceArray)
    local keyset = {}
    for k,v in pairs(sourceArray) do
        table.insert(keyset,k)
    end
    return keyset;     
end

--save the config file
local function saveConfig(newConf)
    local confFile = io.open('/etc/doorCtrl.conf','w')
    confFile:write(serialization.serialize(newConf))
    confFile:close()
end

--verbose out
local function verbose(...)
    if(ops.v) then 
        print(...) 
        local lf = io.open(LOG_FILE,'a')
        lf:write(...)
        lf:close()
    end
end

local function isValidSide(side)
    local s = sides[side]
    return not (s == nil or s == "unknown")
end

function readPassword()
    cursorPosX,cursorPosY = term.getCursor()
    password = ""
    garble = ""
    event_t = event.listen("interrupted",function(...)
        event.cancel(event_t)
        event.cancel(keyboard_event)
    end)
    keyboard_event = event.listen("key_down",function(self,uuid,char,code,player)
        if (char == 8) then
            password = string.sub(password,1,-2)
            garble = string.sub(garble,1,-2)
            term.setCursor(cursorPosX,cursorPosY)
            garble = garble.." "
            term.write(garble)
            garble = string.sub(garble,1,-2)
        elseif(char ~= 13) then
            password = password..string.char(char)
            garble = garble.."*"
            term.write("*")
        end
        lastKey = char
    end)
    lastKey = nil
    while lastKey ~= 13 do
        os.sleep()
    end
    event.cancel(keyboard_event)
    return password
end
--Door class
local Door = class.newClass("Door")
Door.private = {}
Door.private.name = nil
Door.private.component = nil
Door.private.side = nil
Door.private.default = false
Door.private.inverted = false
Door.constructor = function(self,name,component,side,default,inverted)
    self:setName(name)
    self:setComponent(component)
    self:setSide(side)
    self:setDefault(default)
    self:setInverted(inverted)
end
Door.setName = function (self,name) self.private.name = name end
Door.getName = function(self) return self.private.name end
Door.setComponent = function (self,newComponent) self.private.component = component.proxy(newComponent) end
Door.getComponent = function(self) return self.private.component.address end
Door.setSide = function (self,side)
    if(not tonumber(side)) then
        self.private.side = sides[side] 
    else
        self.private.side = side
    end
end
Door.getSide = function(self) return self.private.side end
Door.setDefault = function (self,default) self.private.default = default end
Door.getDefault = function(self) return self.private.default end
Door.setInverted = function (self,inverted) self.private.inverted = inverted end
Door.isInverted = function(self) return self.private.inverted end
Door.open = function (self) 
    local onLevel = 15
    if(self:isInverted()) then onLevel = 0 end
    self.private.component.setOutput(self:getSide(),onLevel)
end
Door.close = function (self) 
    local offLevel = 0
    if(self:isInverted()) then offLevel = 15 end
    self.private.component.setOutput(self:getSide(),offLevel)
end
Door.isOpen = function (self) 
    verbose(self:getSide())
    local isOn = (self.private.component.getOutput(self:getSide()) == 15)
    if(self:isInverted()) then isOn = not isOn end
    return isOn
end
Door.isClosed = function(self) return not self:isOpen() end
Door.toggle = function(self) 
    if(self:isOpen()) then 
        self:close() 
    else 
        self:open() 
    end 
end
Door.set = function(self,open) if(open) then self:open() else self:close() end end

-- get redstone io list
local redstoneIO = getKeys(component.list("redstone"))

-- load config
local configRaw = "{}"
if(filesystem.exists(CONFIG_FILE)) then
    local confFile = io.open(CONFIG_FILE,'r')
    configRaw = confFile:read('*a')
    confFile:close()
else
    local confFile = io.open(CONFIG_FILE,'w')
    configRaw = serialization.serialize({doors={},adminCode="",whitelist={},applyDefault=true})
    confFile:write(configRaw)
    confFile:close()
end
verbose(serialization.serialize(configRaw))
local config = serialization.unserialize(configRaw)

--[[config syntax 
{
    doors"{
        {name="door1",component="uuid",side=side,default=false,inv=false}
    },
    settings={
        adminCode=0000,
        whitelist={},
        applyDefault=true
    }
}
 ]]

-- creating doors
local doors = {}
if(#config.doors > 0) then
    for i, val in ipairs(config.doors) do
        table.insert(doors,Door(val.name,val.component,val.side,val.default,val.inv))
    end
end

print("Found "..#doors.." for "..#redstoneIO.." redstone I/O")
os.sleep(2)

if(ops.config or ops.c) then
    --password check
    local try = 0
    if(config.adminCode ~= "") then
        while try < 3 do
            io.write("Admin password :")
            local password = readPassword()
            if(password == config.adminCode) then break
            else try = try+1
            end
        end
        if(try >= 3) then
            print("Too many wrong passwords")
            os.exit(1)
        end
    end
    local run = true
    --main loop
    while run do
        term.clear()
        --config mod
        for i, door in ipairs(doors) do
            print(i.." : "..door:getName().." "..string.sub(door:getComponent(),1,8).." default("..tostring(door:getDefault())..") Opened("..tostring(door:isOpen())..")")
        end
        print("")
        print("n : New door")
        print("d : Apply default (current value : "..tostring(config.applyDefault)..")")
        print("p : Change password")
        print("q : Exit")
        io.write(">")
        local op = io.read()
        if(tonumber(op)) then
            op = tonumber(op)
            if(op >= 1 and op <= #doors) then
                local door = doors[op]
                local doorID = op
                while true do
                    term.clear()
                    print("Name      : "..door:getName())
                    print("Component : "..door:getComponent())
                    print("Side      : "..sides[door:getSide()])
                    print("Default   : "..(door:getDefault() and "open" or "closed"))
                    print("Inverted  : "..tostring(door:isInverted()))
                    print("Opened    : "..tostring(door:isOpen()))
                    print("")
                    print("r : Rename")
                    print("d : Default")
                    print("i : Inverted")
                    print("s : Side")
                    print("t : Toggle")
                    print("b : Back")
                    io.write(">"..doorID..">")
                    local op = io.read()
                    if(op == "r") then
                        io.write(">"..doorID..">r>["..door:getName().."]")
                        local newName = io.read()
                        if(newName ~= "") then
                            config.doors[doorID].name = newName
                            door:setName(newName)
                            saveConfig(config)
                        end
                    elseif(op == "d") then
                        config.doors[doorID].default = not door:getDefault()
                        door:setDefault(not door:getDefault())
                        saveConfig(config)
                    elseif(op == "i") then
                        config.doors[doorID].inv = not door:isInverted()
                        door:setInverted(not door:isInverted())
                        saveConfig(config)
                    elseif(op == "s") then
                        io.write(">"..doorID..">s>["..sides[door:getSide()].."]")
                        local newSide = io.read()
                        if(isValidSide(newSide)) then
                            door:setSide(sides[newSide])
                            config.doors[doorID].side = sides[door:getSide()]
                            saveConfig(config)
                        end
                    elseif(op == "t") then
                        door:toggle()
                    elseif(op == "b") then
                        break
                    end
                end
            end
        elseif(op == "n") then
            for i, comp in ipairs(redstoneIO) do
                print(i.." : "..comp)
            end
            local compNb = 0
            while (compNb < 1 or compNb > #redstoneIO) do
                io.write(">n>")
                compNb = tonumber(io.read());
            end
            local name = ""
            print("chose a name")
            while (name == "") do
                io.write(">n>"..compNb..">")
                name = io.read();
            end
            print("chose a side")
            local side = nil
            while not isValidSide(side) do
                io.write(">n>"..compNb..">"..name..">")
                side = io.read()
            end
            local door = Door(name,redstoneIO[compNb],side,false,false)
            table.insert(doors,door)
            table.insert(config.doors,{name=name,component=redstoneIO[compNb],side=sides[door:getSide()],default=false,inv=false})
            saveConfig(config)
        elseif(op == "d") then
            config.applyDefault = not config.applyDefault
            saveConfig(config)
        elseif(op == "p") then
            print("Enter new password")
            io.write(">p>")
            local p1 = readPassword()
            io.write("\n")
            print("Confirm password")
            io.write(">p>")
            local p2 = readPassword()
            if(p1 == p2) then
                config.adminCode = p1
                saveConfig(config)
            else
                print("Password do not match. Abodring")
            end
        elseif(op == "q") then
            os.exit(0)
        end
    end
else

    local function closeGUI()
        event.cancel(event_touch)
        event.cancel(event_term)
        term.clear()
        run = false
    end

    event_touch = nil
    event_term = event.listen("interrupted",closeGUI)

    local function buttonCallback(self,eventName,uuid,x,y)
        verbose(self.door:getName())
        beep()
        self.door:toggle()
        if(self.door:isOpen()) then 
            self:setBackground(0x00ff00)
        else
            self:setBackground(0xff0000)
        end
        self:draw()
    end

    

    --normal mod
    local mainScreen = gui.Screen();
    event_touch = event.listen("touch",function(...) mainScreen:trigger(...) end)
    local background = gui.widget.Rectangle(1,1,80,25,0xc3c3c3)
    background:enable(false)
    mainScreen:addChild(background)

    local doorListScreen = gui.Screen()
    mainScreen:addChild(doorListScreen)

    local x = 2
    local y = 3
    for i,door in ipairs(doors) do
        local doorText = gui.widget.Text(x,y,37,1,0xffffff,door:getName())
        --calculate the position of the next button
        if(i%2 == 1) then
            x = 42
        else
            x = 2
            y = y+2
        end
        if(config.applyDefault) then door:set(door:getDefault()) end
        if(door:isOpen()) then 
            doorText:setBackground(0x00ff00)
        else
            doorText:setBackground(0xff0000)
        end
        doorText.door = door --this is dirty
        doorText:setCallback(buttonCallback)
        doorListScreen:addChild(doorText)
    end

    mainScreen:draw()
    run = true
    while run do
        os.sleep()
    end
    closeGUI()
end
