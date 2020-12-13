local ImageFile = require("libGUI/ImageFile")
local gpu = require("component").gpu

local Image = require("libClass").newClass("Image",require("libGUI/widget/Widget"))
Image.imageData = {}
Image.constructor = function(self,x,y,img)
  if(type(img) == "string") then
    self.imageData = ImageFile(img)
  elseif(type("table") and img.class == "Image") then
    self.imageData = img
  end
end
Image.getWidth = function(self) return self.imageData:getWidth() end
Image.getHeight = function(self) return self.imageData:getHeight() end
Image.getSize = function(self) return self.imageData:getSize() end
Image.setWidth = function(self) error("Can change a image size",2) end
Image.setHeight = function(self) error("Can change a image size",2) end
Image.setSize = function(self) error("Can change a image size",2) end
Image.draw = function(self)
  local background = gpu.getBackground()
  for deltaX, column in ipairs(self.imageData:getPixel()) do
    for deltaY, pixel in ipairs(column) do
      if(pixel ~= "nil") then
        gpu.setBackground(pixel)
        gpu.set(self:getX()+deltaX-1,self:getY()+deltaY-1," ")
      end
    end
  end
  gpu.setBackground(background)
end

return Image
