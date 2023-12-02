# libClass2
```lua
local class = require("libClass2")

---@class A:Object
local A = class()


--constructor 
function A:new()
  --call the parent's constructor
  local o = self.parent()
  -- this line make `o` a objet of class `A`
  o = setmetatable(o, {__index = self})
  ---@cast o A
  o.member = 1
  return o
end

function A:method()
  self.member = self.member +1
  return self.member
end

---@class B:A
local B = class(A)

local a = A()
print(a:method())

local b = B
print(b:method())
```