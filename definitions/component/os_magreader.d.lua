---@meta

---@class ComponentOsMagReader : Component
local os_magreader = {}

---Sets the event name returned when you click it with a card, default is magData
---@param eventName string
function os_magreader.setEventName(eventName)
end

---Enables/disables automatic lights on the magreader. If true, it will function as it normally does when clicked with a card. If false, you have to call setLightState to change the lights on the magreader. default is true.
---@param enableLights boolean
function os_magreader.swipeIndicator(enableLights)
end

---Sets the light state of the magreader. Takes in a number from 0 to 7. default is 0\
--- - 1 : red\
--- - 2 : yellow\
--- - 4 : green
---@param lightState number light state as a binary number (1 : red, 3 red + yellow)
---@return boolean lightChanged
function os_magreader.setLightState(lightState)
end
