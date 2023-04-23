local function call(self, ...)
    local new = rawget(self, 'new')
    if (new) then return self:new(...) end
    local o = self.parent(...)
    return setmetatable(o, {__index = self})
end


---@class Object
---@field parent Object the parent class
local Object = {}

function Object:new()
    return setmetatable({}, {__index = self})
end

---Test if the object is a instance of a class
---@param C Object
---@return boolean
function Object:instanceOf(C)
    if (not getmetatable(C).isClass) then error("Argument #1 is not a class or object", 2) end
    if (getmetatable(self).__index == C) then
        return true
    else
        return getmetatable(self).__index ~= Object and getmetatable(self).__index:instanceOf(C)
    end
end

setmetatable(Object, {
    isClass = true,
    __call = call
}
)
--=============================================================================

---Create a new class
---@generic C:Object
---@param parent? C Class inherited from
---@return unknown Really is a new class type.
local function class(parent)
    parent = parent or Object

    local mt = {
        isClass = true,
        __call = call,
        __index = parent,
    }
    return setmetatable({parent = parent}, mt)
end

return class
