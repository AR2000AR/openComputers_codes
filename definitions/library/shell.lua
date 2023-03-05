---@meta
---@class shellLib
local shell = {}

---Gets the value of a specified alias, if any. If there is no such alias returns `nil`.
---@param alias string
---@return string
function shell.getAlias(alias)
end

---Defines a new alias or updates an existing one. Pass `nil` as the value to remove an alias. Note that aliases are not limited to program names, you can include parameters as well. For example, `view` is a default alias for `edit -r`.
---@param alias string
---@param value? string
function shell.setAlias(alias, value)
end

---Returns an iterator over all known aliases.
---@return function
function shell.aliases()
end

---Gets the path to the current working directory. This is an alias for `os.getenv("PWD")`.
---@return string
function shell.getWorkingDirectory()
end

---Sets the current working directory. This is a checked version of `os.setenv("PWD", dir)`.
---@param dir string
function shell.setWorkingDirectory(dir)
end

---Gets the search path used by `shell.resolve`. This can contain multiple paths, separated by colons (`:`).\
---This is an alias for `os.getenv("PATH")`.
---@return string
function shell.getPath()
end

---Sets the search path. Note that this will replace the previous search paths. To add a new path to the search paths, do this:\
---`shell.setPath(shell.getPath() .. ":/some/path")`\
---This is an alias for `os.setenv("PATH", value)`.
---@param value string
function shell.setPath(value)
end

---Tries to “resolve” a path, optionally also checking for files with the specified extension, in which case `path` would only contain the name. This first searches the working directory, then all entries in the search path (see `getPath`/`setPath`).\
---If no file with the exact specified name exists and an extension is provided, it will also check for a file with that name plus the specified extension, i.e. for path .. "." .. ext.
---@param path string
---@param ext? string
---@return string
function shell.resolve(path, ext)
end

---Runs the specified command. This runs the default shell (see `os.getenv("SHELL")`) and passes the command to it. `env` is the environment table to use for the shell, and thus for the called program, in case you wish to sandbox it or avoid it cluttering the caller's namespace. Additional arguments are passed directly to the first program started based on the command, so you can pass non-string values to programs.\
---Returns values similar to `pcall` and `coroutine.resume`: the first returned value is a boolean indicating success or error. In case of errors, the second returned value is a detailed error message. Otherwise the remaining returned values are the values that were returned by the specified program when it terminated.
---@param command string
---@param env? table
---@param ... any
---@return boolean, any ...
function shell.execute(command, env, ...)
end

---Utility methods intended for programs to parse their arguments. Will return two tables, the first one containing any “normal” parameters, the second containing “options”. Options are indicated by a leading `-`, and all options must only be a single character, since multiple characters following a single `-` will be interpreted as multiple options. Options specified with 2 dashes are not split and can have multiple letters. Also, 2-dash options can be given values by using an equal sign.
---@return table args, table opts
function shell.parse(...)
end

return shell
