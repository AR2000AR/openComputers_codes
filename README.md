# OpenComputers codes
My lua programs for openComputers.
---
## Installation with oppm
- install oppm
- run `oppm register AR2000AR/openComputers_codes`
- run `oppm install <package>`
## Install with pm-get
- run `pm-get install <package>`
## Install with pm
- download the tar file from [packages](packages/) with `get` (get the raw file url)
- run `pm install <archiveName.tar>`

---

## Network
Yes, yes, I know. Yet a other network stack. Why use it when [minitel](https://github.com/ShadowKatStudios/OC-Minitel/tree/master/) or [network](https://github.com/OpenPrograms/Magik6k-Programs/tree/master/network) are a thing. No reason really, except that my version called `osinetwork` is close the the reals RFCs. It implement Ethernet, ARP, ICMP, IPV4, and UDP.

### [osinetwork](network/)
The main package. It provide the network stack and surrounding utilities. Provide a `socket` library using the same interface as `luasocket`

### [dns_common](dns_common/)
Common files for dns resolution

### [dns_server](dns_server/)
DNS server as a rc daemon.

### [nslookup](nslookup/)
Command line tool for dns resolution

---
## PM Package manager
`oppm` is good. No denying it. But it has it's limitations. The main one for me : requiring a github repository (ironic I know).\
To fix this issue, I created a package format using tar as container.\

You can find instructions to make a installation floppy [here](pm_installer/)

### [pm](pm/)
The package manager. Install, uninstall and keep track of installed packages.

### [pm_get](pm_get/)
Download and install pm packages from a repo on internet. Customs repos can be added

---
## Banking system
The bank is made of 2 main part : the server and a client. The client can be an ATM or a app to manage accounts.

## Main apps
### [bank_server](bank_server/)
The main server hosting every files needed for the system to work.
The opp package provide tools to help setting up clients who need the secret

### [bank_dev_tools](bank_dev_tools/)
Add a simple command line program to edit the encrypted accounts info. Don't install it if you don't need it.

### [bank_atm](bank_atm/)
Let account holders withdraw or deposit coins. Coins used are defined by [libCoin](libCoin)

### [bank_account_maker](account_maker/)
Let users create a bank account and create a new debit card.

### [vending](vending/)
A automatic vending machine. Install it on a normal computer with a transposer. Accept coins ([libCoin](libCoin)) items and debit card ([libCB](libCB)/[bank_api](bank_api)).


## Library and API

### [bank_api](bank_api/)
Enable the programs to make requests to the server.

### [libCB](libCB/)
Read and write debit card on an unmanaged floppy.
**new** Debit card can be a magnetic card from [open security](https://www.curseforge.com/minecraft/mc-mods/opensecurity)

#### [libCoin](libCoin/)
Move coins with a transposer. Use coins from the [ordinary coins](https://www.curseforge.com/minecraft/mc-mods/ordinary-coins) mod.  

---
## Lua Network File System

### [lnfsc](lnfs/)
lnfs client. Provide the lib (filesystem proxy) and mount.lnfs command
example usage : `mount.lnfs address -p=21 -r`

### [lnfss](lnfs/)
lnfs server. Configuration handled by /etc/rc.cfg. See `man lnfsd` or [lnfsd](lnfs/lnfsd) for more info

---
## Other programs

### [stargate2](stargate_ctl2/)
Graphical interface to control and monitor gates from [Stargate Network](https://www.curseforge.com/minecraft/mc-mods/stargate-network). Whitelist, blacklist, gate list, iris management and password. Fully configurable from the GUI.

### [doorCtrl](doorCtrl/)
Control a number of redstone IO blocs with a single touchscreen. Easy to configure with `doorCtrl -c`

### [itemIdCatcher](itemIdCatcher/)
Write the item id of every items in the chest on top of the transposer in a file. Item are moved on the chest on the bottom once it's id is saved. The program stop after 3 loop without items in the chest.

### [autocrafter](autocrafter/)
Experimental. Use a PC, a Robot, linked card and a transposer to craft items.

### [crypttool](crypttool/)
Ful disk encryption utility.  
Let you mount a "decrypted" version of the disk for easy file manipulation.

---
## Additional library

### [libClass2](libClass2/)
add object oriented programming to lua.

### [libGUI](libGUI/)
draw graphical element on screen. Use a widget system based on libClass.

### [libGUI_extra](libGUI-extra/)
Non essential widgets for libGUI.
