---@meta

---@class oslib
local os = {}

---Returns an approximation of the amount in seconds of CPU time used by the program.
---@return number
function os.clock()
end

---Returns a string or a table containing date and time, formatted according to the given string format.\
---If the time argument is present, this is the time to be formatted (see the os.time function for a description of this value). Otherwise, date formats the current time.\
---If format starts with '!', then the date is formatted in Coordinated Universal Time. After this optional character, if format is the string "*t", then date returns a table with the following fields: year (four digits), month (1–12), day (1–31), hour (0–23), min (0–59), sec (0–61), wday (weekday, Sunday is 1), yday (day of the year), and isdst (daylight saving flag, a boolean). This last field may be absent if the information is not available.\
---If format is not "*t", then date returns the date as a string, formatted according to the same rules as the ISO C function strftime.\
---When called without arguments, date returns a reasonable date and time representation that depends on the host system and on the current locale (that is, os.date() is equivalent to os.date("%c")).\
---On non-Posix systems, this function may be not thread safe because of its reliance on C function gmtime and C function localtime.
---@param format? string
---@param time? string | number
---@return string | table
function os.date(format, time)
end

function os.execute()
end

---@param code? any
---@param close? any
function os.exit(code, close)
end

function os.setenv()
end

function os.remove()
end

function os.rename()
end

function os.time()
end

function os.tmpname()
end

---Sleep for x seconds
---@param time? number
function os.sleep(time)
end

return os
