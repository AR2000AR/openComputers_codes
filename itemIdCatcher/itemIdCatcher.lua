local shell = require("shell")
local tr = require("component").transposer
local beep = require("computer").beep
local fs = require("filesystem")

local args,opts = shell.parse(...)

local fileName = args[1] or "/home/id.txt"
local openMode = "a"
if(not fs.exists(fileName)) then openMode = "w" end
local file = io.open(fileName,openMode)

local from = 1
local to = -1
--look for the input chest
while(tr.getInventoryName(from) == nil) do
  from = from + 1
  if(from == 1) then
    print("Need 2 chest")
    os.exit()
  end
  if(from == 6)then
    form = 0
  end
end

--look for the output chest
repeat
  to = to + 1
  if(to==from)then to=to+1 end
  if(to > 5) then
    print("Need 2 chest")
    os.exit()
  end
until tr.getInventoryName(to) ~= nil

local empty = 0 --empty loop counter
local fromSlot = 1
while tr.getStackInSlot(to,tr.getInventorySize(to)) == nil and empty < 3 do
  if(fromSlot > tr.getInventorySize(from)) then --if we reached the end of the inventory
    fromSlot = 1
    empty = empty + 1
    beep()
  end
  if(tr.getStackInSlot(from,fromSlot)~=nil) then --if there is a item
    local stack = tr.getStackInSlot(from,fromSlot) --get the stack info
    tr.transferItem(from,to,64,fromSlot) --move stack from the input to the output inventory
    if(tr.getStackInSlot(from,fromSlot)==nil) then
      file:write(stack.name.."\n")
      file:flush() --save the file
      empty = 0 --reset the empty loop counter if we found a item
    end
  end
  fromSlot = fromSlot + 1
end
file:close()
