---@diagnostic disable: redefined-local
---@meta

---@class eventlib
local event = {}

---Register a new event listener that should be called for events with the specified name.\
---event - name of the signal to listen to.\
---callback - the function to call if this signal is received. The function will receive the event name it was registered for as first parameter, then all remaining parameters as defined by the signal that caused the event.\
---Returns: number, the event id which can be canceled via event.cancel, if the event was successfully registered, false if this function was already registered for this event type.
---@param event string
---@param callback function
---@return number|boolean
function event.listen(event, callback)
end

---Unregister a previously registered event listener.\
---event - name of the signal to unregister.\
---callback - the function that was used to register for this event.\
---Returns: true if the event was successfully unregistered, false if this function was not registered for this event type.\
---Note: An event listeners may return false to unregister themselves, which is equivalent to calling event.ignore and passing the listener with the event name it was registered for.
---@param event string
---@param callback function
---@return boolean
function event.ignore(event, callback)
end

---Cancels a timer previously created with event.timer.\
---timerId - a timer ID as returned by event.timer.\
---Returns: true if the timer was stopped, false if there was no timer with the specified ID.
---@param timerId number
---@return boolean
function event.cancel(timerId)
end

---Starts a new timer that will be called after the time specified in interval.\
---interval - time in seconds between each invocation of the callback function. Can be a fraction like 0.05.\
---callback - the function to call.\
---times - how many times the function will be called. If omitted the function will be called once. Pass math.huge for infinite repeat.\
---Returns: a timer ID that can be used to cancel the timer at any time.\
---Note: the timer resolution can vary. If the computer is idle and enters sleep mode, it will only be woken in a game tick, so the time the callback is called may be up to 0.05 seconds off.
---@param interval number
---@param callback function
---@param times? number
---@return number
function event.timer(interval, callback, times)
end

---Pulls and returns the next available event from the queue, or waits until one becomes available.\
---timeout - if passed the function will wait for a new event for this many seconds at maximum then returns nil if no event was queued during that time.\
---name - an event pattern that will act as a filter. If given then only events that match this pattern will be returned. Can be nil in which case the event names will not be filtered. See string.match on how to use patterns.\
---… - any number of parameters in the same order as defined by the signal that is expected. Those arguments will act as filters for the additional arguments returned by the signal. Direct equality is used to determine if the argument is equal to the given filter. Can be nil in which case this particular argument will not be filtered.\
---Filter example:\
---The touch signal (when a player clicks on a tier two or three screen) has the signature screenX: number, screenY: number, playerName: string\
---To only pull clicks by player “Steve” you'd do:\
---local _, x, y = event.pull("touch", nil, nil, "Steve")
---@param timeout number
---@param name string
---@param ... any
---@return  string, any ...
---@overload fun(name:string,...:any):string, ...:any
function event.pull(timeout, name, ...)
end

---(Since 1.5.9) Pulls and returns the next available event from the queue, or waits until one becomes available but allows filtering by specifying filter function. timeout - if passed the function will wait for a new event for this many seconds at maximum then returns nil if no event was queued during that time.\
---filter - if passed the function will use it as a filtering function of events. Allows for advanced filtering.\
---Example:
---```lua
---local allowedPlayers = {"Kubuxu", "Sangar", "Magik6k", "Vexatos"}
---local function filter(name, ...)
---    if name ~= "key_up" and name ~= "key_down" and name ~= "touch" then
---        return false
---    end
---    local nick
---    if name == "touch" then
---        nick = select(3, ...)
---    else
---        nick = select(4, ...)
---    end
---    for _, allowed in ipairs(allowedPlayers) do
---        if nick == allowed then
---            return true
---        end
---    end
---    return false
---end
---local e = {event.pullFiltered(filter)}  -- We are pulling key_up, key_down and click events for unlimited amount of time. The filter will ensure that only events caused by players in allowedPlayers are pulled.
---```
---@param timeout number
---@param filter? function
---@return string, any ...
---@overload fun(filer:function):string,...:any
function event.pullFiltered(timeout, filter)
end

---As its arguments pullMultiple accepts multiple event names to be pulled, allowing basic filtering of multiple events at once.
---@param ... string
---@return any ...
function event.pullMultiple(...)
end

---Global event callback error handler. If an event listener throws an error, we handle it in this function to avoid it bubbling into unrelated code (that only triggered the execution by calling event.pull). Per default, this logs errors into a file on the temporary file system.\
---You can replace this function with your own if you want to handle event errors in a different way.
---@param message any
function event.onError(message)
end

---This is only an alias to computer.pushSignal. This does not modify the arguments in any way. It seemed logical to add the alias to the event library because there is also an event.pull for signals.
---@param name string
---@param ... any
function event.push(name, ...)
end

return event
