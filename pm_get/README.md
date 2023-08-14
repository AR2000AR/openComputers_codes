# pm_get
Download and install pm packages from a repository on internet.

## Installation
- run `oppm install pm`

or

- Create a installation floppy. Installation and script can be found [here](../pm_installer/).

## Usage :
- `pm-get install <package>` : install the package
- `pm-get uninstall <package> [--autoremove] [--purge]` : uninstall the package. Optionally remove configurations files and/or old dependance no longer needed
- `pm-get autoremove` : remove no longer required dependance.
- `pm-get sources list` : list configured source repository
- `pm-get sources add <url>` : add a source repository url to `/etc/pm/sources.list.d/custom.list`
- `pm-get list` : list available packages
- `pm-get info <package>` : get the infos about the package

## Files :
- `/etc/pm/sources.list` : the main repository list
- `/etc/pm/sources.list.d/*.list` : additional repository lists
- `/etc/pm/autoInstalled` : list dependance installed automatically

## Repository :
A repository is a collection of packages and a manifest file for the repository, accessible via http or https.

### File structure :
The repository owner if free to structure it however they want. The only restriction is that the manifest file `manifest` is placed in the repository's root folder.

### Manifest file :
The manifest file is a aggregation of the packages's manifest files in a table. Inside each package's manifest is added a extra field that point to the package file. See [manifest](../packages/manifest) for a example.\
Example :
```
{
    ["pm_get"] = {
		["manifestVersion"] = "1.0",
		["package"] = "pm_get",
		["version"] = "1.2.0",
		["name"] = "pm get",
		["repo"] = "tree/master/pm",
		["description"] = "Download and install package for pm",
		["authors"] = "AR2000AR",
		["dependencies"] = 	{
			["pm"] = "oppm"
		},
		["configFiles"] = 	{
			"/etc/pm/sources.list"
		},
		["archiveName"] = "pm_get.tar"
	}
}
```