local ImageFile = require("libGUI/ImageFile")
local gpu = require("component").gpu

local Image = require("libClass").newClass("Image", require("libGUI/widget/Widget"))

Image.DRAW_METHOD_OLD    = false
Image.DRAW_METHOD_NEW    = true
Image.imageData          = {}
Image.private.drawMethod = Image.DRAW_METHOD_OLD

Image.constructor = function(self, x, y, img, drawMethod)
  if     (type(img) == "string") then
    self.imageData = ImageFile(img)
  elseif (type("table") and img.class == "Image") then
    self.imageData = img
  end
  if (drawMethod ~= nil) then self:setDrawMethod(drawMethod) end
end
Image.private.draw = {}
Image.private.draw.old = function(self)
  local background = gpu.getBackground()
  for deltaX, column in ipairs(self.imageData:getPixel()) do
    for deltaY, pixel in ipairs(column) do
      if (pixel ~= "nil") then
        gpu.setBackground(pixel)
        gpu.set(self:getX() + deltaX - 1, self:getY() + deltaY - 1, " ")
      end
    end
  end
  gpu.setBackground(background)
end
Image.private.draw.new = function(self)
  local bg, fg = gpu.getBackground(), gpu.getForeground()
  local pixelFg, pixelBg
  for x = 1, self.imageData:getWidth() do
    for y = 1, math.floor(self.imageData:getHeight()) do
      if (y % 2 == 1) then
        pixelFg = self.imageData:getPixel(x, y)
        if (pixelFg == "nil") then _, _, pixelFg = gpu.get(self:getX() + x - 1, self:getY() + (y - 1) / 2) end
        if (y + 1 <= self.imageData:getHeight()) then
          pixelBg = self.imageData:getPixel(x, y + 1)
          if (pixelBg == "nil") then _, _, pixelBg = gpu.get(self:getX() + x - 1, self:getY() + (y - 1) / 2) end
        else
          _, _, pixelBg = gpu.get(self:getX() + x - 1, self:getY() + (y - 1) / 2)
        end
        gpu.setForeground(pixelFg)
        gpu.setBackground(pixelBg)
        gpu.set(self:getX() + x - 1, self:getY() + (y - 1) / 2, "▀")
      end
    end
  end
  gpu.setBackground(bg)
  gpu.setForeground(fg)
end

Image.getWidth      = function(self) return self.imageData:getWidth() end
Image.getHeight     = function(self) if (self:getDrawMethod()) then return math.ceil(self.imageData:getHeight() / 2) else return self.imageData:getHeight() end end
Image.getSize       = function(self) return self.imageData:getSize() end
Image.setWidth      = function(self) error("Can change a image size", 2) end
Image.setHeight     = function(self) error("Can change a image size", 2) end
Image.setSize       = function(self) error("Can change a image size", 2) end
Image.setDrawMethod = function(self, drawMethod) self.private.drawMethod = drawMethod end
Image.getDrawMethod = function(self) return self.private.drawMethod end
Image.draw          = function(self)
  if (self:getDrawMethod() == Image.DRAW_METHOD_NEW) then
    self.private.draw.new(self)
  else
    self.private.draw.old(self)
  end
end


return Image
