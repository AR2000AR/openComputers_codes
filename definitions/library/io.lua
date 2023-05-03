---@diagnostic disable: redundant-parameter
---@meta

---@class iolib
local io = {}

-------------------------------------------------------------------------------

---Equivalent to file:close(). Without a file, closes the default output file.
---@param file? file*
---@return boolean? suc
---@return ("exit"|"signal")? exitcode
---@return integer? code:
function io.close(file)
end

---Equivalent to io.output():flush().
function io.flush()
end

---Opens the given file name in read mode and returns an iterator function that works like file:lines(···) over the opened file. When the iterator function detects the end of file, it returns nil (to finish the loop) and automatically closes the file.\
---The call io.lines() (with no file name) is equivalent to io.input():lines(); that is, it iterates over the lines of the default input file. In this case it does not close the file when the loop ends.\
---In case of errors this function raises the error, instead of returning an error code.
---@param filename string
---@param ... readmode
---@return fun():any, ...unknown
function io.lines(filename, ...)
end

---This function opens a file, in the mode specified in the string mode. It returns a new file handle, or, in case of errors, nil plus an error message.\
---The mode string can be any of the following:
--- - "r": read mode (the default);
--- - "w": write mode;
--- - "a": append mode;
--- - "r+": update mode, all previous data is preserved;
--- - "w+": update mode, all previous data is erased;
--- - "a+": append update mode, previous data is preserved, writing is only allowed at the end of file.
---
---The mode string can also have a 'b' at the end, which is needed in some systems to open the file in binary mode.
---@param path string
---@param mode readmode
---@return file*? file, string? reason
function io.open(path, mode)
end

---Return the filestream for the given file descriptor of file path.\
---If file is provided, the newly created steam will be given the file descriptor fd
---@param fd number
---@param file? string|table
---@param mode? readmode
---@return file*
function io.stream(fd, file, mode)
end

---When called with a file name, it opens the named file (in text mode), and sets its handle as the default input file. When called with a file handle, it simply sets this file handle as the default input file. When called without parameters, it returns the current default input file.\
---In case of errors this function raises the error, instead of returning an error code.
---@param file? file*|string
---@return file*
function io.input(file)
end

---Similar to io.input, but operates over the default output file.
---@param file? file*|string
---@return file*
function io.output(file)
end

---Similar to io.input, but operates over the default error file.
---@param file? file*|string
---@return file*
function io.error(file)
end

---Starts program prog in a separated process and returns a file handle that you can use to read data from this program (if mode is "r", the default) or to write data to this program (if mode is "w").
---@param prog string
---@param mode? "r"|"w"
---@param env? table
function io.popen(prog, mode, env)
end

---Equivalent to io.input():read(···).
---@param ... readmode
---@return any,....any
function io.read(...)
end

---Returns a handle for a temporary file. This file is opened in update mode and it is automatically removed when the program ends.
---@return file*
function io.tmpfile()
end

---Checks whether obj is a valid file handle. Returns the string "file" if obj is an open file handle, "closed file" if obj is a closed file handle, or nil if obj is not a file handle.
---@param object table
---@return "file"|"closed file"|nil
function io.type(object)
end

---Equivalent to io.output():write(···).
---@param ... string|number
---@return file*?, string? errmsg
function io.write(...)
end

---@unknown
function io.dup(fd)
end

-------------------------------------------------------------------------------

return io
