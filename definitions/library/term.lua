---@meta

---@termLib
local term = {}

---Returns whether the term API is available for use, i.e. whether a primary GPU and screen are present. In other words, whether term.read and term.write will actually do something.
---@return boolean
function term.isAvailable()
end

---(new in OpenOS 1.6)\
---Gets the width, height, x offset, y offset, relative x, and relative y values.
---@return number, number, number, number, number, number
function term.getViewport()
end

---(new in OpenOS 1.6)\
---Gets the gpu proxy used by the term api.
---@return table
function term.gpu()
end

---(new in OpenOS 1.6)\
---Acts exactly like event.pull taking the same parameters and returning the same results. This method is used to blink the cursor while waiting for an event result.
---@param ...? any
---@return any ...
function term.pull(...)
end

---Gets the current position of the cursor.
---@return number, number
function term.getCursor()
end

---Sets the cursor position to the specified coordinates.
---@param col number
---@param row number
function term.setCursor(col, row)
end

---Gets whether the cursor blink is currently enabled, i.e whether the cursor alternates between the actual “pixel” displayed at the cursor position and a fully white block every half second.
---@return boolean
function term.getCursorBlink()
end

---Sets whether cursor blink should be enabled or not.
---@param enabled boolean
function term.setCursorBlink(enabled)
end

---Clears the complete screen and resets the cursor position to (1, 1).\
function term.clear()
end

---Clears the line the cursor is currently on and resets the cursor's horizontal position to 1.\
function term.clearLine()
end

---Read some text from the terminal, i.e. allow the user to input some text. For example, this is used by the shell and Lua interpreter to read user input. This will make the rest of the current line, starting at the current cursor position, an editable area. It allows input, deletion and navigating to the left and right via the arrow keys and home/end keys.\
---since OpenOS 1.6 the parameter list as specified here is considered deprecated. The first parameter is an options argument. The indexed array values are treated as history, named keys take the place of legacy arguments. For compatibility, OpenOS 1.6 will respect the previous usage, i.e. parameter list.\
---The new ops parameter supports a new key, nowrap. The default behavior of term.read wrap the cursor and input vertically. Legacy behavior scrolled the input horizontally, i.e. term.read({nowrap=true})\
---The optional history table can be used to provide predefined text that can be cycled through via the up and down arrow keys. It must be a sequence (i.e. the keys must be a gap-less integral interval starting at 1). This is used for the command history in shell and Lua interpreter, for example. If text is entered and confirmed with enter, it will be added to the end of this table.\
---The dobreak parameter, when set to false (nil defaults to true!) will not enter a new line after input was completed (e.g. by the user pressing enter).\
---The hint parameter is used for tab completion. It can either be a table with strings or a function that returns a table of strings and takes two parameters, the current text and the position in that text, i.e. the signature of the callback is function(line:string, pos:number):table.\
---The pwchar parameter, when given, causes input to be masked using the first char of the given string. For example, providing "*" will make all entered characters appear as stars. The returned value will still be the actual text inserted, of course.\
---The function will return a string if input was successful, nil if the pipe was closed (^d), or false if the pipe was interrupted (^c)\
---Note: io.stdin:read() uses this function.\
---Note 2: This will return the entered string with the \n (new line character). If you want only the entered string to be returned, use io.read().
---@param history? table
---@param dobreak? boolean
---@param hint? table|function
---@param pwchar? string
---@return string
---@overload fun(options:table):string
function term.read(history, dobreak, hint, pwchar)
end

---Allows writing optionally wrapped text to the terminal starting at the current cursor position, updating the cursor accordingly. It automatically converts tab characters to spaces using text.detab. If wrap is true, it will automatically word-wrap the text. It will scroll the displayed buffer if the cursor exceeds the bottom of the display area, but not if it exceeds the right of the display area (when wrap is false).\
---Note: This method respects io redirection. That is to say, term.write writes to the same stream as io.stdout
---@param value string
---@param wrap? boolean
function term.write(value, wrap)
end

---(new in OpenOS 1.6)\
---Binds a gpu proxy (not address) to the terminal. This method is called automatically during boot when the gpu and screen become available. Note that if manually rebinding a terminal to a screen with different width and height, the terminal draw area will be truncated and not maximized. This changes the gpu used in all terminal output, not just via the term api, i.e. io.write, print, io.stdout:write, etc all use the same output stream, and term.bind is used to change the gpu used.
---@param gpu ComponentGPU
function term.bind(gpu)
end

---(new in OpenOS 1.6)\
---Convenience method, simply calls getScreen on the terminal's bound gpu (see term.bind)
---@return string
function term.screen()
end

---(new in OpenOS 1.6)\
---Gets the address of the keyboard the terminal is accepting key events from.
---@return string
function term.keyboard()
end

return term
