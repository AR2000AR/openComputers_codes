# Input([Text](Text.md))
Get text input from the user.
The widget must be able to 

## Inherited public methods
- [setX](Widget.md#setx)
- [setY](Widget.md#sety)
- [setPos](Widget.md#setpos)
- [getX](Widget.md#getx)
- [getY](Widget.md#gety)
- [getPos](Widget.md#getpos)
- [draw](Widget.md#draw)
- [collide](Widget.md#collide)
- [setWidth](Rectangle.md#setwidth)
- [setHeight](Rectangle.mdsetHeight)
- [setSize](Rectangle.mdd#setsize)
- [setColor](Rectangle.md#setcolor)
- [getWidth](Rectangle.md#getwidth)
- [getHeight](Rectangle.md#getheight)
- [getSize](Rectangle.mdd#getsize)
- [getColor](Rectangle.md#getcolor)
- [getForeground](Text.md#getforeground)
- [getBackground](Text.md#getbackground)
- [setForeground](Text.md#setforeground)
- [setBackground](Text.md#setbackground)  

Do not use :
- [setCallback](Widget.md#setcallback)

This methods are replaced by [getValue](#getvalue) and [setValue](#setvalue)
- [getText](Text.md#gettext)
- [setText](Text.md#settext)

## Public methods
### setPlaceholder
If set, the widget will show the placeholder character instead of the normal text. Useful for password prompts
#### Arguments
- char : string|nil

---
### getPlaceholder
Get the placeholder character.
#### Return
- char : string

---
### getValue
Get the inputted value. Return a different value than `getText`. Prefer this method.
#### Return
- value : string
---
### setValue
Get the inputted value. Should be used instead of `setText`
#### Arguments
#### Return

---