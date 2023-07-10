local gpu       = require("component").gpu
local class     = require("libClass2")
local Widget    = require("yawl.widget.Widget")
local ImageFile = require("yawl.ImageFile")

local HALF_CHAR = "▀"


---@class Image:Widget
---@field private _imageData ImageFile
---@operator call:Image
---@overload fun(parent:Frame,x:number,y:number,img:string|table):Image
local Image = class(Widget)

---Create a Image widget
---@param parent Frame
---@param x number
---@param y number
---@param img ImageFile|string
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

---@return number
function Image:width(value)
    return self._imageData:width()
end

---@return number
function Image:height(value)
    return math.ceil(self._imageData:height() / 2)
end

---@param value? ImageFile
---@return ImageFile
function Image:imageData(value)
    checkArg(1, value, 'table', 'nil')
    local oldValue = self._imageData
    if (value ~= nil) then self._imageData = value end
    return oldValue
end

function Image:draw()
    if (not self:visible()) then return end
    local bg, fg = gpu.getBackground(), gpu.getForeground()
    --read pixels into a table with one cell per screen pixel
    local pixels = {}
    for pixY = 1, self._imageData:height(), 2 do
        local row1 = self._imageData:pixel(nil, pixY) --[[@as table]]
        local row2 = {}
        if (pixY > self._imageData:height()) then
            for i, _ in pairs(row1) do row2[i] = "nil" end
        else
            row2 = self._imageData:pixel(nil, pixY + 1) --[[@as table]]
        end
        for i, _ in pairs(row1) do
            table.insert(pixels, {fg = row1[i] or 'nil', bg = row2[i] or 'nil'})
        end
    end
    for i, v in pairs(pixels) do
        if (v.bg ~= "nil" or v.fg ~= "nil") then
            local x = (self:absX()) + ((i - 1) % self:width())
            local y = self:absY() + math.floor((i - 1) / self:width())
            if (v.fg == "nil") then
                local c, cfg, cbg = gpu.get(x, y)
                if (c == HALF_CHAR) then
                    v.fg = cfg
                else
                    v.fg = cbg
                end
            end
            if (v.bg == "nil") then
                _, _, v.bg = gpu.get(x, y)
            end
            gpu.setForeground(v.fg)
            gpu.setBackground(v.bg)
            gpu.set(x, y, HALF_CHAR, false)
        end
    end

    gpu.setBackground(bg)
    gpu.setForeground(fg)
end

return Image
