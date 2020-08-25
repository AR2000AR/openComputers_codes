local Class = {Object=require("libClass/Object")}

function Class.newClass(newType,parent)
  assert(type(newType) == "string","arg #1 must be a string")
  parent = parent or Class.Object
  assert(parent.class or Class.Object.class,"not a compatible class")
  local newClass = parent:clone()
  if(parent.constructor) then
    table.insert(newClass.class.parentConstructor,parent.constructor)
  end
  newClass.constructor = nil
  newClass.class.type = newType
  return newClass
end

return Class
