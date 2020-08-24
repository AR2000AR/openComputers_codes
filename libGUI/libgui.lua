local component = require("component")

local libGUI = {}

-- read pam image and return a pixel table
function libGUI.openPAM(path)
  local file = io.open(path,"rb")
  local pixmap = {}
  assert(file:read("*l")=="P7","The file is not a pam image")
  local img = {}
  img.property = {}
  img.pixel = {}
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

function libGUI.drawImg(img,x,y)
  local background = component.gpu.getBackground()
  for deltaX, column in ipairs(img.pixel) do
    for deltaY, pixel in ipairs(column) do
      if(pixel ~= "nil") then
        component.gpu.setBackground(pixel)
        component.gpu.set(x+deltaX-1,y+deltaY-1," ")
        --print(deltaX.." "..deltaY.." "..string.format("%06x",pixel))
      end
    end
  end
  component.gpu.setBackground(background)
end

return libGUI
