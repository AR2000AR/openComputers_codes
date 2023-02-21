---@meta

---@class ComponentComputer : Component
local computer = {}

---Tries to start the computer. Returns true on success, false otherwise. Note that this will also return false if the computer was already running. If the computer is currently shutting down, this will cause the computer to reboot instead.
---@return boolean
function computer.start()
end

---Tries to stop the computer. Returns true on success, false otherwise. Also returns false if the computer is already stopped.
---@return boolean
function computer.stop()
end

---Returns whether the computer is currently running.
---@return boolean
function computer.isRunning()
end

---Plays a tone, useful to alert users via audible feedback. Supports frequencies from 20 to 2000Hz, with a duration of up to 5 seconds.
---@param frequency number
---@param duration number
function computer.beep(frequency, duration)
end

---Returns a table of device information. Note that this is architecture-specific and some may not implement it at all.
---@return table
function computer.getDeviceInfo()
end

---Attempts to crash the computer for the specified reason.
---@param reason string
function computer.crash(reason)
end

---Returns the computer's current architecture.
---@return string
function computer.getArchitecture()
end

---Returns whether or not the computer is, in fact, a robot.
---@return boolean
function computer.isRobot()
end
