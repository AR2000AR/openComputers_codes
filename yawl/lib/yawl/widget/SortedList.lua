local gpu = require("component").gpu
local Widget = require("yawl.widget.Widget")
local unicode = require("unicode")
local keyboard = require('keyboard')

---@class SortedList:Widget
---@field private _size Size
---@operator call:SortedList
---@overload fun(parent:Frame,x:number,y:number,width:number,height:number,backgroundColor:number)
local SortedList = require("libClass2")(Widget)
---Create a new SortedList
---@param parent Frame
---@param x number
---@param y number
---@param width number
---@param height number
---@param backgroundColor number
---@return SortedList
function SortedList:new(parent, x, y, width, height, backgroundColor)
    checkArg(1, parent, 'table')
    checkArg(2, x, 'number')
    checkArg(3, y, 'number')
    checkArg(4, width, 'number')
    checkArg(5, height, 'number')
    checkArg(6, backgroundColor, 'number')
    local o = self.parent(parent, x, y)
    setmetatable(o, {__index = self})
    o._list = {}
    o._shown = {} --used for selection
    o._selection = {} --for multi selection, selection[index] = index in _list
    o._scrollindex = 0
    o._showsErrors = false
    ---@cast o SortedList
    o:size(width, height)
    o:backgroundColor(backgroundColor or 0)
    return o
end

function SortedList:select(index, state) --getter/setter
    checkArg(1, index, 'number')
    checkArg(1, state, 'boolean', 'nil')
    local oldValue = self._selection[index]
    if state ~= nil then --needs work 
        self._selection[index] = state --select
    end
    return oldValue
end

function SortedList:insert(value, index)
    checkArg(1, value, 'table', 'boolean', 'number', 'string')
    checkArg(1, index, 'number', 'nil')
    if type(value) == 'table' then
        for _,v in ipairs (self._list) do
            if v == value then
                return false, 'table already inserted'
            end
        end
    end
    if type(index)=='number' then
        table.insert(self._list, index, value) 
    else
        table.insert(self._list, value)
    end
    return true
end

function SortedList:delete(value) 
    --can be index or string or table, if its not a number then iterate through list and do a direct == comparison and use table.remove(self._list, i)
    checkArg(1, value, 'function', 'number', 'table', 'string', 'boolean')
    local valueType = type(value)
    if valueType == 'function' then --custom delete
        return value(self)
    elseif valueType == 'number' then --index
        if self._list[value] then
            return table.remove(self._list, value)
        end
    else
        for i,v in ipairs (self._list) do
            if v == value then
                return table.remove(self._list, i)
            end
        end
    end
    return false, 'no such value'
end

function SortedList:move(value, index) --shifts things around

end

function SortedList:sorter(sortfunc)
    checkArg(1, sortfunc, 'function', 'boolean', 'nil')
    local oldValue = self._sortfunc or false
    if (sortfunc ~= nil) then self._sortfunc = sortfunc end
    return oldValue
end

function SortedList:numbered(value)
    checkArg(1, value, 'boolean', 'nil')
    local oldValue = self._numbered or false
    if (value ~= nil) then self._numbered = value end
    return oldValue
end

function SortedList:filter(filterfunc)
    checkArg(1, filterfunc, 'function', 'boolean', 'nil')
    local oldValue = self._filterfunc or false
    if (filterfunc ~= nil) then self._filterfunc = filterfunc end
    return oldValue
end

function SortedList:filterBy(value) --sets the value that gets passed into filterFunc
    checkArg(1, value, 'string', 'number', 'nil', 'boolean')
    local oldValue = self._filter or false
    if (value ~= nil) then 
        self._filter = value
        if value == "" then 
            self._contextScroll = nil
            self._contextStart = nil
            self._contextEnd = nil
            self._highestContextIndex = nil
        else 
            self._contextScroll = 0
        end
    end
    return oldValue
end

function SortedList:format(formatfunc) --for displaying values
    checkArg(1, formatfunc, 'function', 'boolean', 'nil')
    local oldValue = self._formatfunc or false
    if (formatfunc ~= nil) then self._formatfunc = formatfunc end
    return oldValue
end

function SortedList:clearList() --empty list
    self._list = {}
    return true
end

function SortedList:clearSelection() --empty list
    self._selection = {}
    return true
end

function SortedList:getSelection()
    local selected = {}
    for i,v in pairs (self._selection) do
        if v then table.insert(selected, i) end
    end
    return selected
end

function SortedList:mount(object)
    checkArg(1, object, 'table', 'nil', 'boolean')
    --check for duplicates first
    local oldValue = self._mount
    local objectType = type(object)
    if objectType == 'table' and object.text then --note: could potentially use something that isn't strictly text based, e.g., a toggle switch :value()
        self._mount = object
    elseif object == false then
        self._mount = nil
    end
    return oldValue
end

function SortedList:scroll(value) --not perfect, needs refinement for when filter has been applied, needs to differentiate between unfiltered and filtered
    checkArg(1, value, 'number', 'nil')
    local oldValue = self._contextScroll or self._scrollindex or 0
    
    if (value ~= nil) then --and height <= shownheight then 
        if self._filter == "" or not self._filter then --I know, you won't like that I accessed them directly
            self._scrollindex = math.max(math.min(#self._list - self:height(), self._scrollindex + value), 0)
        elseif #self._shown > 0 then --filterBy is set and there is something to visually scroll
            local currentListIndex = self._shown[1]
            if self._contextScroll == 0 then 
                self._contextStart = (currentListIndex or 1) - 1 
                self._contextScroll = self._contextStart 
            end
            
            if value == 1 then
                local nextListIndex = self._shown[2]
                if nextListIndex then
                    value = nextListIndex - currentListIndex
                end
            elseif value == -1 and currentListIndex>1 and (self._highestContextIndex == nil or self._highestContextIndex~=currentListIndex) then
                local nextListIndex, foundHigher = currentListIndex, false
                local filterFunc, filterValue = self:filter(), self:filterBy()
                repeat 
                    nextListIndex = nextListIndex - 1
                    local nextListValue = self._list[nextListIndex]
                    local succ, returned = pcall(filterFunc, filterValue, nextListValue)
                    foundHigher = (succ and returned~=nil and returned~=false ) or (not succ and self._showsErrors)
                until nextListIndex == 1 or foundHigher
                value = nextListIndex - currentListIndex
                if nextListIndex == 1 and not foundHigher then --searched and never found with current filter, gets wiped when new filterby value is passed
                    self._highestContextIndex = currentListIndex
                end
            end
            self._contextScroll = math.max(math.min((self._contextEnd <= self:height() and self._contextScroll or #self._list), self._contextScroll + value), self._contextStart)
        
            self._debugTxt:text(string.format("%d | %d", self._contextScroll, value) )
        end
    end
    return oldValue
end

function SortedList:defaultCallback(_, eventName, uuid, x, y, button, playerName)
    if eventName == "touch" then
        local index = self._shown[y - self:absY() + 1]
        if button == 0 then
            if keyboard.isControlDown() then
                self:select(index, not self:select(index))
                return
            else
                self:clearSelection()
            end
        end
        if index then
            self:select(index, button == 0) 
        end
    elseif eventName == "scroll" then
        self:scroll(-button)
    end
end

---Draw the SortedList on screen
function SortedList:draw()
    if (not self:visible()) then return end
    local x, y, width, height = self:absX(), self:absY(), self:width(), self:height()
    local oldBG, oldFG = gpu.getBackground(), gpu.getForeground()
    local newBG, newFG = self:backgroundColor(), self:foregroundColor()
    if newBG then gpu.setBackground(newBG) end
    if newFG then gpu.setForeground(newFG) end
    gpu.fill(x, y, width, height, " ") --overwrite the background
    
    if #self._list == 0 then return end
    local sorterFunc = self:sorter()
    if sorterFunc then 
        local succ, err = pcall(table.sort, self._list, sorterFunc) 
        if not succ then
            gpu.set(x,y, unicode.sub(err, 1, width))
            return
        end
    end

    self._shown = {}
    local filterFunc, mounted, filterValue = self:filter(), self:mount()
    if mounted then
        local newFilterVal = mounted:text()
        if self:filterBy() ~= newFilterVal then self:filterBy(newFilterVal) end
        filterValue = newFilterVal
    else
        filterValue = self:filterBy()
    end
    if filterValue == "" then filterValue = nil end

    local i, scrollIndex, listValue = 1, self:scroll()
    repeat
        local index = i + scrollIndex
        listValue = self._list[index] 
        if not listValue then break end
        if filterFunc and filterValue then
            local succ, returned = pcall(filterFunc, filterValue, listValue)
            if succ then
                if returned~=nil and returned~=false then
                    table.insert(self._shown, index)
                end
            elseif self._showsErrors then
                table.insert(self._shown, tostring(index).." (filter)"..returned)
            end
        else
            table.insert(self._shown, index)
        end
        i=i+1
    until listValue == nil or #self._shown > height --go to at most 1 over
    
    local formatFunc, isNumbered = self:format(), self:numbered()
    local linePrefix = "%+"..tostring(tostring(#self._shown):len()).."s:%+"..tostring(tostring(#self._list):len()).."s "
    if filterValue then self._contextEnd = #self._shown end --for scrolling end detection
    
    for line, index in ipairs (self._shown) do
        if line > height then break end
        if type(index) == 'number' then
            local listValue = self._list[index]
            if formatFunc then 
                local succ, returned = pcall(formatFunc, listValue)
                listValue = (not succ and '(format)' or '') .. returned --should be fine
            end
            listValue = (isNumbered and string.format(linePrefix, line, index) or "") .. tostring(listValue):gsub("\n","; ")
            local isSelected = self:select(index)
            if isSelected and newFG and newBG then gpu.setBackground(newFG) gpu.setForeground(newBG) end
            gpu.set(x, y+line-1, unicode.sub(listValue, 1, width) ) --do the formatting here
            if isSelected and newFG and newBG then gpu.setBackground(newBG) gpu.setForeground(newFG) end
        else
            local errVal = index:gsub("\n","; ")
            local failedIndex = errVal:match("%d+")
            errVal = unicode.sub(errVal, failedIndex:len()+2)
            gpu.set(x, y+line-1, unicode.sub( (isNumbered and string.format(linePrefix, line, failedIndex) or "") .. errVal, 1, width) )
        end
    end
    gpu.setBackground(oldBG)
    gpu.setForeground(oldFG)
end

return SortedList