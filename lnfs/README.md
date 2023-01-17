# lnfsd
Provide the lnfs filesystem to other machines on the Network

## Installation
- Run `oppm install lnfss`
- Configure the server in `/etc/rc.cfg` to fit your needs
- Run `rc lnfsd enable`
- Run `rc lnfsd start`

## Configuration
Configuration is done in the `/etc/rc.cfg` file

### root
Mandatory : no
Type : string
Default : "/"
Root folder shared by lnfsd

### ro
Mandatory : no
Type : boolean
Default : false
Is the shared folder read only

### port
Mandatory : no
Type : number
Default : 21
Port to listen on

### name
Mandatory : no
Type : string
Default : hostname
The filesystem label seen by the client

Example :
```lua
lnfsd = {root="/home",ro=false,name="label",port=21}
```
---
# lnfsc
The lnfs client

## Installation
- Run `oppm install lnfsc`

## Usage
- Run `mount.lnfs <server address> <mount point>`