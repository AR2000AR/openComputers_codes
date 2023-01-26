# crypttool
A easy way to encrypt a entire filesystem. It is **not** a filesystem.  
As of now, it can't work for the boot filesystem.

## Installation
### Requirement
- A T2 or higher data card
- A 2nd storage medium (floppy or hdd).

### Software
- Run `oppm install crypttool`

## Usage
- Insert the floppy disk or HDD you want to use. It must be in managed mode.
- Run `decryptDisk <disk mount point> <password>` to decrypt and remount the filesystem.  
Example : `decryptDisk /mnt/82d password`

You can put this command in `/home/.shrc` put that mean leaving the password in clear text.