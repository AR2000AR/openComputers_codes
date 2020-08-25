local Class = require("libClass")
local fs = require("filesystem")

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

local function openPAM(path)
  local file = io.open(path,"rb")
  if(file:read("*l")~="P7") then error("The file is not a pam image",2) end
  local img = {property = {},pixel = {}}
  local line = ""
  repeat
    line = file:read("*l")
    local spacePos = line:find(" ")
    if(spacePos ~= nil) then
      local propertyName = line:sub(0,spacePos-1)
      local propertyValue = line:sub(spacePos+1)
      img.property[propertyName] = tonumber(propertyValue) or propertyValue
    end
  until line == "ENDHDR"
  assert(tonumber(img.property.MAXVAL) <= 255,"can read this image")
  for i = 1, tonumber(img.property.WIDTH) do
    img.pixel[i] = {}
  end
  local i = 0
  repeat
    local rgb = {}
    local pixel = ""
    if (img.property.TUPLTYPE == "RGB" or img.property.TUPLTYPE == "RGB_ALPHA") then
      rgb.R = file:read(1):byte()
      rgb.G = file:read(1):byte()
      rgb.B = file:read(1):byte()
      pixel = string.format("%02x%02x%02x",rgb.R,rgb.G,rgb.B)
      if(img.property.TUPLTYPE == "RGB_ALPHA") then
        rgb.A = file:read(1):byte()
        if(rgb.A==0) then
          pixel = nil
        end
      end
    else
      pixel = file:read(1):byte()
      pixel = string.format("%02x%02x%02x",pixel,pixel,pixel)
    end
    if(pixel ~= nil) then
      img.pixel[(i%img.property.WIDTH)+1][(math.floor(i/img.property.WIDTH))+1] = tonumber(pixel,16)
    else
      img.pixel[(i%img.property.WIDTH)+1][(math.floor(i/img.property.WIDTH))+1] = "nil"
    end
    i=i+1
  until i == img.property.WIDTH * img.property.HEIGHT
  file:close()
  return img
end

local Image = Class.newClass("Image")
Image.private = {property = {}, pixel = {}}
Image.getPixel = function(self,x,y)
  if(x) then
    if(x > #self.private.pixel) then error("x out of range",2) end
    if(y) then
      if(x > #self.private.pixel) then error("x out of range",2) end
      return deepcopy(self.private.pixel[x][y])
    end
    return deepcopy(self.private.prixel[x])
  else
    return deepcopy(self.private.pixel)
  end
end
Image.open = function(self,path)
  local imgTable = {}
  if(not (fs.exists(path) and not fs.isDirectory(path))) then
    error("No file with path : "..path,2)
  end
  if(path:match("%..+$")==".pam") then
    imgTable = openPAM(path)
  else
    error(path:match("%..+$"):sub(2).. "not supported")
  end
  self.private.property = imgTable.property
  self.private.pixel = imgTable.pixel
end
Image.getWidth = function(self) return #self.private.pixel end
Image.getHeight = function(self) return #self.private.pixel[1] end
Image.getSize = function(self) return self:getWidth(), self:getHeight() end
Image.constructor = function(self,path) if(path) then self:open(path) end end

return Image
