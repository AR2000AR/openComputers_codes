---@meta

---@class threadapi
local thread = {}

---Starts a new thread executing the function `thread_proc` and returns its thread handle, see Thread Handle API. This method takes an optional `...` which is passed to `thread_proc`. The runtime of the thread continues autonomously.
---@param thread_proc function
---@param ... any
---@return thread
function thread.create(thread_proc, ...)
end

---Waits for the array of `threads` to complete. This blocking call can return in `timeout` seconds if provided. Returns success and an error message on failure. A thread is “completed” under multiple conditions, see `t:join()` for details.
---@param threads table<thread>
---@param timeout? number
function thread.waitForAll(threads, timeout)
end

--Returns the current thread `t` object. The init process does not represent a thread and nothing is returned from this method if called from the init process and not inside any thread.
---@return thread? t
function thread.current()
end

---@class thread
local t = {}


---Resumes (or thaws) a suspended thread. Returns success and an error message on failure. A thread begins its life already in a running state and thus basic thread workflows will not ever need to call `t:resume()`. A “running” thread will autonomously continue until it completes. `t:resume()` is only necessary to resume a thread that has been suspended(`t:suspend()`). Note that because you are not directly resuming the thread any exceptions thrown from the thread are absorbed by the threading library and not exposed to your process.\
--- - At this time there is no way to hook in an exception handler for threads but for now `event.onError` is used to print the error message to “/tmp/event.log”. Please note that currently the hard interrupt exception is only thrown once, and the behavior of a process with threads when a hard interrupt is thrown is unspecified. At this time, any one of the threads or the parent process may take the exception. These details are not part of the specification for threads and any part of this implementation detail may change later.
---@return boolean,string
function t:resume()
end

---Suspends (or freezes) a running thread. Returns success and an error message on failure. A “suspended” thread never autonomously wakes up and dies as soon as its parent process (if attached) closes. A suspended thread ignores events. That means any event listeners or timers created inside the thread will not respond to event notifications. Note that threads do not buffer event signals and a suspended thread may miss event signals it was waiting for. For example, if a thread was last waiting on `event.pull("modem_message")` and is “suspended” and a “modem_message” is received by the computer then the thread will miss the event and never know it happened. Please note that if you suspend a thread that is blocked waiting for an event, it is unspecified which event the thread will receive when it is next resumed.\
---Suspending the current thread causes the thread to immediately yield and does not resume until `t:resume()` is called explicitly elsewhere.
---@return boolean,string
function t:suspend()
end

---Stabby stab! Kills the thread dead. The thread is terminated and will not continue its thread function. Any event registrations it made will die with it. Keep in mind that the core underlying Lua type is a coroutine which is not a preemptive thread. Thus, the thread's stopping points are deterministic, meaning that you can predict exactly where the thread will stop.
function t:kill()
end

--- Returns the thread status as a string.\
--- - “running”\
--- A running thread will continue (autonomously reactivating) after yields and blocking calls until its thread function exits. This is the default and initial state of a created thread. A thread remains in the “running” state even when blocked or not active. A running thread can be suspended(`t:suspend()`) or killed (`t:kill()`) but not resumed(`t:resume()`). A running thread will block calls to `t:join()` and block its parent from closing. Unlike a coroutine which appears “suspended” when not executing in this very moment, a thread state remains “running” even when waiting for an event.\
--- - “suspended”\
--- A suspended thread will remain suspended and never self resume execution of its thread function. A suspended thread is automatically killed when its attached parent closes or when you attempt to `t:join()` it. A suspended thread ignores event signals, and any event registrations made from the context of the thread, or any child threads created therein, also ignore any event signals. A suspended thread's children behave as if suspended even if their status is “running”. A suspended thread can be resumed(`t:resume()`) or killed (`t:kill()`) but not suspended(`t:suspend()`).\
--- - “dead”\
--- A dead thread has completed or aborted its execution or has been terminated. It cannot be resumed(`t:resume()`) nor suspended(`t:suspend()`). A dead thread does not block a parent process from closing. Killing a dead thread is not an error but does nothing.
---@return "running"|"suspended"|"dead"
function t:status()
end

---Attaches a thread to a process, conventionally known as a child thread or attached thread. `level` is an optional used to get parent processes, 0 or nil uses the currently running process. When initially created a thread is already attached to the current process. This method returns nil and an error message if `level` refers to a nonexistent process, otherwise it returns truthy. An attached thread blocks its parent process from closing until the thread dies (or is killed, or the parent process aborts).
---@param level? number
---@return boolean,string
function t:attach(level)
end

---Detaches a thread from its parent if it has one. Returns nil and an error message if no action was taken, otherwise returns self (handy if you want to create and detach a thread in one line). A detached thread will continue to run until the computer is shutdown or rebooted, or the thread dies.
---@return thread,string
function t:detach()
end

return thread
