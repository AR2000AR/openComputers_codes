# pm Package Manager
Package manager for OpenOS. Use tar archive as package container

## Installation
- run `oppm install pm`

or

Create a installation floppy. Installation and script can be found [here](../pm_installer/).

## Usage

**Install a package :**\
`pm install [--dry-run] [--allow-same-version] package.tar`\
**Uninstall a package**\
`pm uninstall [--purge] [--dry-run] pakageName`\
**List installed packages :**\
`pm list-installed [--include-removed]`\

## Package format
### File tree
A package is a tar archive with the following data structure
```
/
|---DATA
|---CONTROL
    |---manifest
```
The `DATA` folder contain all files installed by the package. The `DATA` folder is the `/` of the OS similar of how `install` work.
### Manifest file
The manifest file describe the package. It is a serialization compatible file.
```
{
    manifestVersion = "1.0",
    package = "example",
    dependencies = {
        ["neededpackage"] = "=1.0"
    },
    configFiles = {
        "/etc/example.conf"
    }, --list configurations files that need to be left on update / uninstallation of the package
    name = "Example Package",
    version = "1.0.0",
    description = "Package description",
    authors = "AR2000AR",
    note = "Extra bit of information",
    hidden = false,
    repo = "https://github.com/AR2000AR/openComputers_codes"
}
```
### manifestVersion :
The manifest file version. Currently `1.0`
### package :
The package's name. Different from the display name.
### dependencies :
The package's dependencies. The key is a package name, and value a version. Version is in the format `[>=]major.minor.patch`. `minor` and `patch` can be omitted.
### configFiles :
A table of all configurations files. They will not be overridden on update or removed by default during uninstallation.
### name :
The display name
### version :
The package's version. Version is in the format `major.minor.patch`. `minor` and `patch` can be omitted.\
A other valid version number is `"oppm"` for oppm packages without a version number
### description :
Package's description
### note :
Extra information about the package
### authors :
List of authors
### hidden :
Hide the package from package managers's install candidate list
### repo :
URL to the source code

## Packaging a application
### Manually
- Create a folder with the same file structure as describe above
- Write the package manifest's file
- Create a tar archive with the tool of your choice. For example, while being the the folder, do `tar -c -f ../mypackage.tar *`
### From a cloned oppm repo
- Call the [repoPackager.py](tools/repoPackager.py) from the terminal while in the repository. If the default settings don't fit your need, call it with the `-h` option to see what can be changed.