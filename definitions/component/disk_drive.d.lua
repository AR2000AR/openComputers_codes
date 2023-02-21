---@meta

---@class ComponentDiskDrive : Component
local disk_drive = {}

---Eject the currently present medium from the drive.
---@param velocity? number
---@return boolean
function disk_drive.eject(velocity)
end

---Check whether some medium is currently in the drive.
---@return boolean
function disk_drive.isEmpty()
end

---Return the internal floppy disk address.
---@return string|nil address, string|nil reason
function disk_drive.media()
end
