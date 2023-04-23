local gpu       = require("component").gpu
local class     = require("libClass2")
local Widget    = require("yaowbgl.widget.Widget")
local ImageFile = require("yaowbgl.ImageFile")


---@class Image:Widget
---@field private _imageData ImageFile
---@operator call:Image
---@overload fun(parent:Frame,x:number,y:number,img:string|table):Image
local Image = class(Widget)

---Create a Image widget
---@param parent Frame
---@param x number
---@param y number
---@param img any
function Image:new(parent, x, y, img)
    local o = self.parent(parent, x, y)
    setmetatable(o, {__index = self})
    ---@cast o Image
    if (type(img) == "string") then
        o._imageData = ImageFile(img)
    elseif (type("table") and img:instanceOf(ImageFile)) then
        o._imageData = img
    end
    return o
end

function Image:draw()
    local bg, fg = gpu.getBackground(), gpu.getForeground()
    local pixelFg, pixelBg
    for x = 1, self._imageData:width() do
        for y = 1, math.floor(self._imageData:height()) do
            if (y % 2 == 1) then
                pixelFg = self._imageData:pixel(x, y)
                if (pixelFg == "nil") then _, _, pixelFg = gpu.get(self:x() + x - 1, self:y() + (y - 1) / 2) end
                if (y + 1 <= self._imageData:height()) then
                    pixelBg = self._imageData:pixel(x, y + 1)
                    if (pixelBg == "nil") then _, _, pixelBg = gpu.get(self:x() + x - 1, self:y() + (y - 1) / 2) end
                else
                    _, _, pixelBg = gpu.get(self:x() + x - 1, self:y() + (y - 1) / 2)
                end
                gpu.setForeground(pixelFg)
                gpu.setBackground(pixelBg)
                gpu.set(self:x() + x - 1, self:y() + (y - 1) / 2, "▀")
            end
        end
    end
    gpu.setBackground(bg)
    gpu.setForeground(fg)
end

return Image
