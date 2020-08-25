local function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

local construcMetaTable = {
  __call = function(self,...)
    local cp = deepcopy(self)
    local cpMeta = getmetatable(cp)
    cpMeta.__call = nil
    setmetatable(cp,cpMeta)
    cp.class.callConstructor(cp,...) -- call the constructor
    return cp
  end
}

local Object = {
  constructor = nil, --object constructor
  class = {
    type = "object",
    parentConstructor = {}, --the parents constructor
    callConstructor = function(self,...)
      print(...)
      for _,constructor in ipairs(self.class.parentConstructor) do constructor(...) end
      self:constructor(...)
    end,
  },
  clone = function(self) return deepcopy(self) end
}
setmetatable(Object.class,{__tostring=function(self)return self.type end})
setmetatable(Object,construcMetaTable)
return Object
