---@meta

---@class ComponentDrive : Component
local drive = {}

---Read a single byte at the specified offset.
---@param offset number
---@return number
function drive.readByte(offset)
end

---Write a single byte to the specified offset.
---@param offset number
---@param value number
function drive.writeByte(offset, value)
end

---Returns the size of a single sector on the drive, in bytes.
---@return number
function drive.getSectorSize()
end

---Get the current label of the drive.
---@return string
function drive.getLabel()
end

---Sets the label of the drive. Returns the new value, which may be truncated.
---@param value string
---@return string
function drive.setLabel(value)
end

---Read the current contents of the specified sector.
---@param sector number
---@return string
function drive.readSector(sector)
end

---Write the specified contents to the specified sector.
---@param sector number
---@param value string
function drive.writeSector(sector, value)
end

---Returns the number of platters in the drive.
---@return number
function drive.getPlatterCount()
end

---Returns the total capacity of the drive, in bytes.
---@return number
function drive.getCapacity()
end
