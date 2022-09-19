# OpenComputers codes
My lua programs for openComputers.

---

---
## Banking system
The bank is made of 2 main part : the server and a client. The client can be an ATM or a app to manage accounts.

### Main apps
#### bank_server
The main server hosting every files needed for the system to work.
The opp package provide tools to help setting up clients who need the secret

### bank_dev_tools
Add a simple command line program to edit the encrypted accounts info. Don't install it if you don't need it.

### Librairy and API

#### bank_api
Enable the programs to make requests to the server.

#### libCB
Read and write credit card on an unmanaged floppy.

#### libCoin
move coins with a transposer. Use coins from the [ordinary coins](https://www.curseforge.com/minecraft/mc-mods/ordinary-coins) mod.  
Note that the exchange rate is 50:1 instead of the default 100:1.

---
## Other programs

### vending
A automatic vending machine program. Install it on a normal computer with a transposer.
Can use coins (libGUI) or a CB (libCB & bank_api). Configurable.

### stargate
Graphical interface to control and monitor gates from [Stargate Network](https://www.curseforge.com/minecraft/mc-mods/stargate-network). Whitelist, blacklist, gate list, iris management and password. Fully configurable from the GUI

### doorCtrl
Control a number of redstone IO blocs with a single touchscreen. Easy to configure with `doorCtrl -c`

### itemIdCatcher
Write the item id of every items in the chest on top of the transposer in a file. Item are moved on the chest on the bottom once it's id is saved. The program stop after 3 loop without items in the chest.

### autocrafter
Use a PC, a Robot, linked card and a transposer to craft items

---
## Additional librarys

### libClass
add object oriented programing to lua.

### libGUI
draw graphical element on screen. Use a widget system based on libClass.

### libGUI_extra
Non essential widgets for libGUI.
