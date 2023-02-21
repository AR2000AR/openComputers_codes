---@meta

---@class ComponentOsCardWriter : Component
local os_cardwriter = {}

---writes data to an magnetic/rfid card, 3rd parameter sets the card to readonly
---@param data string
---@param displayName string
---@param locked boolean
---@param color colors
---@return boolean cardWritten
function os_cardwriter.write(data, displayName, locked, color)
end

---flashes data to an eeprom
---@param data string
---@param title string
---@param writelock boolean
function os_cardwriter.flash(data, title, writelock)
end
