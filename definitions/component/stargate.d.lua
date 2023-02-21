---@meta

---@class ComponentStargate
local stargate = {}

---@alias stargateState
--- | "Idle" # Operating and ready to dial
--- | "Dialling" # In the process of dialling an address
--- | "Opening" # Finished dialling, wormhole in transient phase
--- | "Connected" # Wormhole is stable
--- | "Closing" # Wormhole is shutting down
--- | "Offline" # Interface not connected to a functioning stargate

---@alias stargateDirection
--- | "Outgoing"  # Connection was dialled from this end
--- | "Incoming"  # Connection was dialled from the other end
--- | ""  # Not connected

---@alias irisState
--- | "Closed"
--- | "Opening"
--- | "Open"
--- | "Closing"
--- | "Offline"

---Return the gate state
---@return stargateState state
---@return number engaged
---@return stargateDirection direction number of engared chevron
function stargate.stargateState()
end

---Returns the amount of energy in the gate's internal buffer plus the buffers of any attached Stargate Power Units. This is the energy available for the next dialling operation. If the interface is not connected to a functioning stargate, zero is returned.
---@return number su
function stargate.energyAvailable()
end

---Returns the amount of energy that would be needed to connect to the stargate at the given address.
---@param address string
---@return number su
function stargate.energyToDial(address)
end

---Returns the address of the attached stargate. If the interface is not connected to a functioning stargate, an empty string is returned.
---@return string
function stargate.localAddress()
end

---Returns the address of the connected stargate. If there is no connection, or the interface is not connected to a functioning stargate, an empty string is returned.
---@return string
function stargate.remoteAddress()
end

---Dials the given address.
---@param address string
function stargate.dial(address)
end

---Closes any open connection.
function stargate.disconnect()
end

---Returns a string indicating the state of the iris: Closed, Opening, Open, Closing. Returns Offline if no iris is fitted or the interface is not connected to a functioning stargate.
---@return irisState
function stargate.irisState()
end

---Closes the iris, if fitted.
function stargate.closeIris()
end

---Opens the iris, if fitted.
function stargate.openIris()
end

---Sends a message through an open connection to any stargate interfaces attached to the destination stargate. Any number of arguments may be passed. The message is delivered to connected computers as an sgMessageReceived event. Has no effect if no stargate connection is open.
---@param arg string|number|boolean
---@param ... string|number|boolean
function stargate.sendMessage(arg, ...)
end
