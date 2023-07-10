local class = require("libClass2")
local fs = require("filesystem")
local os = require("os")

---copy the table orig, metatable included. Sub-tables are also copied
---@param orig table
---@return table
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
    local file = io.open(path, "rb")
    assert(file, "No file named " .. path)
    if (file:read("*l") ~= "P7") then error("The file is not a pam ImageFile", 2) end
    local img = {property = {}, pixel = {}}
    local line = ""
    repeat
        repeat
            line = file:read("*l")
        until (line:sub(1, 1) ~= "#") -- ignore comments
        local spacePos = line:find(" ")
        if (spacePos ~= nil) then
            local propertyName = line:sub(0, spacePos - 1)
            local propertyValue = line:sub(spacePos + 1)
            img.property[propertyName] = tonumber(propertyValue) or propertyValue
        end
    until line == "ENDHDR"
    assert(tonumber(img.property.MAXVAL) <= 255, "can't read this ImageFile")
    for i = 1, tonumber(img.property.WIDTH) do
        img.pixel[i] = {}
    end
    local i = 0
    repeat
        if (i % 1000 == 0) then os.sleep() end
        local rgb = {}
        local pixel = ""
        if (img.property.TUPLTYPE == "RGB" or img.property.TUPLTYPE == "RGB_ALPHA") then
            rgb.R = file:read(1):byte()
            rgb.G = file:read(1):byte()
            rgb.B = file:read(1):byte()
            pixel = string.format("%02x%02x%02x", rgb.R, rgb.G, rgb.B)
            if (img.property.TUPLTYPE == "RGB_ALPHA") then
                rgb.A = file:read(1):byte()
                if (rgb.A == 0) then
                    pixel = "nil"
                end
            end
        else
            pixel = file:read(1):byte()
            pixel = string.format("%02x%02x%02x", pixel, pixel, pixel)
        end
        if (pixel ~= "nil") then
            img.pixel[(i % img.property.WIDTH) + 1][(math.floor(i / img.property.WIDTH)) + 1] = tonumber(pixel, 16)
        else
            img.pixel[(i % img.property.WIDTH) + 1][(math.floor(i / img.property.WIDTH)) + 1] = "nil"
        end
        i = i + 1
    until i == img.property.WIDTH * img.property.HEIGHT
    file:close()
    return img
end

local function openPPM(path)
    local file = io.open(path, "rb")
    assert(file, "No file named " .. path)

    local img = {property = {}, pixel = {}}

    -- check the image format
    -- P3 is ASCII
    -- P6 is raw
    img.property.TYPE = file:read("*l")
    if (img.property.TYPE ~= "P6" and img.property.TYPE ~= "P3") then error("The file is not a ppm ImageFile", 2) end

    local line = ""

    -- get image size
    repeat
        line = file:read("*l")
    until (line:sub(1, 1) ~= "#") --ignore comment
    local spacePos = line:find(" ")
    if (spacePos ~= nil) then
        local width = line:sub(0, spacePos - 1)
        local height = line:sub(spacePos + 1)
        img.property.WIDTH = tonumber(width) or width
        img.property.HEIGHT = tonumber(height) or height
    end

    -- get pixel maxval
    img.property.MAXVAL = file:read("*l")
    assert(tonumber(img.property.MAXVAL) <= 255, "can't read this ImageFile")

    -- create pixel array
    for i = 1, tonumber(img.property.WIDTH) do
        img.pixel[i] = {}
    end

    -- read pixel data
    local i = 0
    repeat
        if (i % 1000 == 0) then os.sleep() end
        local rgb = {}
        local pixel = ""
        if (img.property.TYPE == "P6") then
            rgb.R = file:read(1):byte()
            rgb.G = file:read(1):byte()
            rgb.B = file:read(1):byte()
        elseif (img.property.TYPE == "P3") then
            rgb.R = tonumber(file:read("*l"))
            rgb.G = tonumber(file:read("*l"))
            rgb.B = tonumber(file:read("*l"))
        end
        pixel = string.format("%02x%02x%02x", rgb.R, rgb.G, rgb.B)
        if (pixel ~= nil) then
            img.pixel[(i % img.property.WIDTH) + 1][(math.floor(i / img.property.WIDTH)) + 1] = tonumber(pixel, 16)
        else
            img.pixel[(i % img.property.WIDTH) + 1][(math.floor(i / img.property.WIDTH)) + 1] = "nil"
        end
        i = i + 1
    until i == img.property.WIDTH * img.property.HEIGHT
    file:close()
    return img
end

---@class ImageProperty
---@field TUPLTYPE string
---@field WIDTH number
---@field HEIGHT number

---@class ImageFile:Object
---@field private _pixel table<number,table<number,number>>
---@field private _property ImageProperty
local ImageFile = class()

---Open a image file
---@param path string
---@return ImageFile
function ImageFile:new(path)
    checkArg(1, path, 'string')
    local o = self.parent()
    setmetatable(o, {__index = self})
    ---@cast o ImageFile
    o._property = {}
    o._pixel = {}
    if (not fs.exists(path)) then
        error(string.format("No such file : %s", path), 2)
    end
    o:open(path)
    return o
end

---Get the pixel color value
---@param x number
---@param y number
---@return number
---@overload fun(self:ImageFile,x:number):table<number,number>
---@overload fun(self:ImageFile,x:nil,y:number):table<number,number>
function ImageFile:pixel(x, y)
    checkArg(1, x, 'number', 'nil')
    checkArg(2, y, 'number', 'nil')
    if (x) then
        if (x > #(self._pixel)) then error("x out of range", 2) end
        if (y) then
            if (y > #(self._pixel[x])) then error("y out of range", 2) end
            return self._pixel[x][y]
        end
        return deepcopy(self._pixel[x])
    elseif (not x and y) then
        local row = {}
        for i, pixs in pairs(self._pixel) do
            table.insert(row, pixs[y])
        end
        return row
    else
        return deepcopy(self._pixel)
    end
end

function ImageFile:open(path)
    local imgTable = {}
    if (not (fs.exists(path) and not fs.isDirectory(path))) then
        error("No file with path : " .. path, 2)
    end
    if (path:match("%..+$") == ".pam") then
        imgTable = openPAM(path)
    elseif (path:match("%..+$") == ".ppm") then
        imgTable = openPPM(path)
    else
        error(path:match("%..+$"):sub(2) .. "not supported")
    end
    self._property = imgTable.property
    self._pixel = imgTable.pixel
end

function ImageFile:width() return #(self._pixel) end

function ImageFile:height() return #(self._pixel[1]) end

function ImageFile:size() return self:width(), self:height() end

---@return ImageProperty
function ImageFile:property()
    return deepcopy(self._property)
end

return ImageFile
