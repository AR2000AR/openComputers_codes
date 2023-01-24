# *Widget*
Abstract class. Define the basic information any widget need.
## Constructor
### Arguments
- x : int
- y : int

## Abstract public methods

### setPos
#### Arguments
- x : int
- y : int

---
### setX
#### Arguments
 - x : int

---
### setY
#### Arguments
 - y : int

---
### setCallback
Set the function called when `trigger` is called. This usually happen when the widget is clicked.
#### Arguments
- callback : function

---
### getX
#### Return
- x : int

---
### getY
#### Return
- y : int

---
### getPos
#### Return
- x : int
- y : int

---
### *collide*
Check if the position passed as arguments is on the widget
#### Arguments
- x : int
- y : int

---
### *draw*
Draw the widget.

---
## Public methods

### trigger
Call the callback method if the widget is enabled. Pass the widget and all arguments passed to it to the callback method.
### Arguments
- ... : any