# OpenComputers codes
My lua programs for openComputers.
---
## Installation with oppm
- install oppm
- run `oppm register AR2000AR/openComputers_codes`
- run `oppm install <package>`
## OPPM bug
Because of a bug in oppm (Issue : https://github.com/OpenPrograms/Vexatos-Programs/issues/30) (PR : https://github.com/OpenPrograms/Vexatos-Programs/pull/31), please use [repo-installer](repo-installer/) to install any of programs until the bug get fixed.
### Install repo-installer manually
```
mkdir /usr/bin/ /usr/misc/repo-installer/
wget https://raw.githubusercontent.com/AR2000AR/openComputers_codes/master/repo-installer/bin/instgen.lua /usr/bin/instgen.lua
wget https://raw.githubusercontent.com/AR2000AR/openComputers_codes/master/repo-installer/misc/repo-installer/repoinstaller.lua /usr/misc/repo-installer/repoinstaller.lua
```
### Create the installation floppy
Get a empty floppy disk and run :
```
$ instgen AR2000AR/openComputers_codes <floppy path>
```
### Install a package
With the floppy in the machine run `install`. No internet card is required.

---
## Banking system
The bank is made of 2 main part : the server and a client. The client can be an ATM or a app to manage accounts.

### Main apps
#### bank_server
The main server hosting every files needed for the system to work.
The opp package provide tools to help setting up clients who need the secret

### bank_dev_tools
Add a simple command line program to edit the encrypted accounts info. Don't install it if you don't need it.

### bank_atm
Let account holders withdraw or deposit coins. Coins used are defined by [libCoin](libCoin)

### bank_account_maker
Let users create a bank account and create a new debit card.

### vending
A automatic vending machine. Install it on a normal computer with a transposer. Accept coins ([libCoin](libCoin)) items and debit card ([libCB](libCB)/[bank_api](bank_api)).

### Library and API

#### bank_api
Enable the programs to make requests to the server.

#### libCB
Read and write debit card on an unmanaged floppy.
**new** Debit card can be a magnetic card from [open security](https://www.curseforge.com/minecraft/mc-mods/opensecurity)

#### libCoin
Move coins with a transposer. Use coins from the [ordinary coins](https://www.curseforge.com/minecraft/mc-mods/ordinary-coins) mod.  

---
## Lua Network File System

### lnfsc
lnfs client. Provide the lib (filesystem proxy) and mount.lnfs command
example usage : `mount.lnfs address -p=21 -r`

### lnfss
lnfs server. Configuration handled by /etc/rc.cfg. See `man lnfsd` or [lnfsd](lnfs/lnfsd) for more info

---
## Other programs

### stargate
Graphical interface to control and monitor gates from [Stargate Network](https://www.curseforge.com/minecraft/mc-mods/stargate-network). Whitelist, blacklist, gate list, iris management and password. Fully configurable from the GUI

### doorCtrl
Control a number of redstone IO blocs with a single touchscreen. Easy to configure with `doorCtrl -c`

### itemIdCatcher
Write the item id of every items in the chest on top of the transposer in a file. Item are moved on the chest on the bottom once it's id is saved. The program stop after 3 loop without items in the chest.

### autocrafter
Experimental. Use a PC, a Robot, linked card and a transposer to craft items.

---
## Additional library

### libClass
add object oriented programing to lua.

### libGUI
draw graphical element on screen. Use a widget system based on libClass.

### libGUI_extra
Non essential widgets for libGUI.
