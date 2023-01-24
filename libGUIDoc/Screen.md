# Screen
Group widgets together do draw them, hide or show, enable or disable them.  
You should always put any widget in at least one Screen as it manage a [frame buffer](https://ocdoc.cil.li/component:gpu#video_ram_buffers) to speed up drawing
## Constructor
Take no arguments

## Public methods
### setVisible
Set the Screen's visibility. When hidden, no child widgets will be drawn.
#### Arguments
- visible : boolean

---
### enable
Enable or disable the Screen. When disabled, the trigger event won't be propagated to the children.
#### Arguments
- enable : boolean

---
### isVisible
Check if the Screen is visible.
#### Return
- boolean

---
### isEnabled
Check if the Screen is enable.
#### Return
- boolean

---
### addChild
Add a child to the Screen.
#### Arguments
- child : Widget|Screen

---
### trigger
Method to call to handle events. Most often a `touch` handler.
```lua
local gui = require "libGUI"
local event = require "event"

local screen = gui.Screen()
event.listen("touch",function(...) screen:trigger(...) end)
```
#### Arguments
- ... : any. The event infos

---
### draw
Draw the child widgets.
#### Arguments
- useBuffer : boolean. Should the Screen create a frame buffer to draw in. Default is true.
## Private methods
### clickHandler(eventName:string, uuid:string, x:int, y:int, button:int, playerName:string)
#### Parameter
`touch` event property.
