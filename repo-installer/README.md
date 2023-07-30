Original source : [izaya/OC-misc/repo-installer](https://git.shadowkat.net/izaya/OC-misc/src/branch/master/repo-installer)
# repo-installer
A set of tools for making installable floppies for OpenComputers from OPPM repositories.

## repoinstaller
An installer script that can be placed on a floppy containing an oppm repo to create an installer. Includes selecting packages for installation and attempting to install packages via oppm if they are not found.

There must be a *master/* folder, containing a *programs.cfg* file on the disk, and all paths in programs.cfg must be specified relative to the root of the floppy disk.

## instgen
A script to download an oppm repository to create an installer (including install script).  
**Note :** Only github is supported for the `:` prefix in a package's file list.

### Installation
#### From oppm
`oppm install instgen`
#### Manually
```
mkdir /usr/bin/ /usr/misc/repo-installer/
wget https://raw.githubusercontent.com/AR2000AR/openComputers_codes/master/repo-installer/bin/instgen.lua /usr/bin/instgen.lua
wget https://raw.githubusercontent.com/AR2000AR/openComputers_codes/master/repo-installer/misc/repo-installer/repoinstaller.lua /usr/misc/repo-installer/repoinstaller.lua
```
### Usage

```
instgen AR2000AR/openComputers_codes /mnt/xxx/
```
Replace /mnt/xxx/ with the path to your floppy.

You can provide a [github personal token](https://github.com/settings/tokens?type=beta) if the package listing fail. It may be because of a rate limit with github's api. To do so set the environment variable `HTTP_BASIC` to the base64 representation of `username:token`.

This will download all the files specified in the programs.cfg specified into */mnt/xxx*, in a manner compatible with repoinstaller.

~~You must provide your own .prop file.~~ A .prop file is generated with the repository name.
