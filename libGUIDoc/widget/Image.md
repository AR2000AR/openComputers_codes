# Image([Widget](Widget.md))
Display a image. Supported format are `.ppm` and `.pam` both in ASCII or RAW (binary) format.

## Constructor
- x : int
- y : int
- img : string|[ImageFile](ImageFile.md). The image file path
- drawMethod : int

## Inherited public methods
- [setX](Widget.md#setx)
- [setY](Widget.md#sety)
- [setPos](Widget.md#setpos)
- [getX](Widget.md#getx)
- [getY](Widget.md#gety)
- [getPos](Widget.md#getpos)
- [setCallback](Widget.md#setcallback)
- [draw](Widget.md#draw)
- [collide](Widget.md#collide)

## Public methods
### getWidth
#### Return
- width : int
---
### getHeight
#### Return
- height: int

---
### getSize
#### Return
- width : int
- height : int

---
### setDrawMethod
Define how a individual pixel is drawn :
- true : 2 pixels per character (square pixel)
- false : 1 pixel per character (rectangle pixel)
#### Argument
- drawMethod : boolean

---
### getDrawMethod
How a individual pixel is drawn :
- true : 2 pixels per character (square pixel)
- false : 1 pixel per character (rectangle pixel)
#### Return
- drawMethod : boolean

---