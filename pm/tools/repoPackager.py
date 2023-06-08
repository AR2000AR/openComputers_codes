#!/bin/python3
import getopt
import os
import pathlib
import re
import shutil
import sys
import tarfile
import tempfile
from glob import glob

from slpp import slpp as lua

RED = '\33[31m'
RESET = '\33[0m'


def printError(msg):
    print(f"{RED}{msg}{RESET}", file=sys.stderr)


def printUsage():
    print(f"{sys.argv[0]} [-p|--programs <file>] [-d|--destination <path>] [-s|--strip-comments] [*packageName]")
    print("\t-p|--programs <file> : oppm's programs.cfg file. Default is \"./programs.cfg\"")
    print("\t-d|--destination <path> : path to output the pacakges. Default is \"./packages/\"")
    print("\t-s|--strip-comments : remove the comments from lua files before adding them to the archive. Line number are not affected")


def removeMetadata(tarObject):
    tarObject.mtime = 0
    return tarObject


def makePackage(packageInfo, source=None, outputDirectory='./packages/'):
    global opts
    with tempfile.TemporaryDirectory(prefix="packager.") as tmpDir:
        os.mkdir(tmpDir+"/CONTROL/")
        os.mkdir(tmpDir+"/DATA/")
        if not source:
            source = os.getcwd()

        # build the manifest
        manifest = {}
        manifest["manifestVersion"] = "1.0"
        manifest["package"] = packageName
        if "version" in packageInfo:
            manifest["version"] = packageInfo["version"]
        else:
            manifest["version"] = "oppm"
        if "name" in packageInfo:
            manifest["name"] = packageInfo["name"]
        if "repo" in packageInfo:
            manifest["repo"] = packageInfo["repo"]
        if "description" in packageInfo:
            manifest["description"] = packageInfo["description"]
        if "note" in packageInfo:
            manifest["note"] = packageInfo["note"]
        if "authors" in packageInfo:
            manifest["authors"] = packageInfo["authors"]
        if "dependencies" in packageInfo:
            for dep in packageInfo["dependencies"]:
                if not "dependencies" in manifest:
                    manifest["dependencies"] = {}
                manifest["dependencies"][dep] = "oppm"

        # copy the required files
        if "files" in packageInfo:
            for fileInfo, destination in packageInfo["files"].items():
                if re.match("//", destination):
                    destination = destination[1:]
                else:
                    destination = "/usr"+destination
                if destination[-1] != "/":
                    destination = destination+"/"

                prefix = fileInfo[0]
                filePath = pathlib.Path(*pathlib.Path(fileInfo).parts[1:])
                filePath = pathlib.Path(source, filePath)
                if (prefix == "?"):  # add it to the config file list
                    if not "configFiles" in manifest:
                        manifest["configFiles"] = []
                    configFile = pathlib.Path(*pathlib.Path(fileInfo).parts[2:])
                    manifest["configFiles"].append("/"+str(configFile))

                destination = tmpDir+"/DATA"+destination

                if (prefix == ":"):
                    shutil.copytree(filePath, destination)
                else:
                    pathlib.Path(destination).mkdir(
                        parents=True, exist_ok=True)
                    shutil.copy(filePath, destination)

        #write the package's manifest file
        with open(tmpDir+"/CONTROL/manifest", 'w') as file:
            file.write(lua.encode(manifest))
    
        if any(item in ['-s','--strip-comments'] for item,v in opts):
            for luaFile in glob(root_dir=tmpDir+"/DATA/",pathname="**/*.lua",recursive=True):
                os.system(f'sed -i s/--.*// {tmpDir+"/DATA/"+luaFile}')

        version = manifest["version"]
        # manifest["archiveName"] = f"{packageName}_({version}).tar"
        manifest["archiveName"] = f"{packageName}.tar"
        with tarfile.open(pathlib.Path(outputDirectory, manifest["archiveName"]), 'w') as tar:
            tar.add(tmpDir+"/CONTROL", arcname="CONTROL",filter=removeMetadata)
            tar.add(tmpDir+'/DATA/', arcname="DATA", filter=removeMetadata)
        return manifest


if __name__ == '__main__':
    global opts,args
    try:
        opts, args = getopt.gnu_getopt(sys.argv[1:], 'hp:d:s', ['programs=', 'destination=','strip-comments'])
    except getopt.GetoptError as e:
        printError(e.msg)
        exit(1)

    outputDirectory = pathlib.Path(os.getcwd(), "packages/").absolute()
    packageInfoFile = pathlib.Path(os.getcwd(), "programs.cfg").absolute()

    for option, value in opts:
        if option in ("-h", "--help"):
            printUsage()
            exit(0)
        elif option in ("-p", "--programs"):
            packageInfoFile = pathlib.Path(value).absolute()
        elif option in ("-d", "--destination"):
            outputDirectory = pathlib.Path(value).absolute()

    pathlib.Path(outputDirectory).mkdir(parents=True, exist_ok=True)

    if not os.path.isfile(packageInfoFile):
        printError(f"{packageInfoFile} not found")
        exit(1)

    raw = None
    with open(packageInfoFile, 'r') as file:
        raw = file.read()

    data = lua.decode(raw)

    repoManifest = {}
    for packageName, packageInfo in data.items():
        if len(args) == 0 or packageName in args:
            packageManifest = makePackage(packageInfo, outputDirectory=outputDirectory)
            repoManifest[packageManifest["package"]] = packageManifest

    with open(pathlib.Path(outputDirectory, "manifest"), "w") as repoManifestFile:
        repoManifestFile.write(lua.encode(repoManifest))
