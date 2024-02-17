#!/bin/python3
import getopt
import getopt
import os
import pathlib
import re
import shutil
import sys
import tarfile
import tempfile
import json
from glob import glob

from slpp import slpp as lua

RED = '\33[31m'
RESET = '\33[0m'


def printError(msg):
    print(f"{RED}{msg}{RESET}", file=sys.stderr)


def printUsage():
    print(
        f"{sys.argv[0]} [-d|--destination <path>] [-s|--strip-comments]")
    print("\t-d|--destination <path> : path to output the pacakges. Default is \"./packages/\"")
    print("\t-s|--strip-comments : remove the comments from lua files before adding them to the archive. Line number are not affected")


def removeMetadata(tarObject: tarfile.TarInfo):
    tarObject.mtime = 0
    return tarObject


def makePackage(projectDir: pathlib.Path, manifestPath: pathlib.Path, filesListJsonPath: pathlib.Path, outputDirectory=pathlib.Path('./packages/')):
    global opts

    with tempfile.TemporaryDirectory(prefix="packager.") as tmpDir:

        # parse the files
        manifest = {}
        with open(manifestPath, 'r') as manifestFile:
            manifest = lua.decode(manifestFile.read())
        parsedFilesList = {}
        with open(filesListJsonPath, 'r') as filesListFile:
            parsedFilesList = json.load(filesListFile)

        os.mkdir(tmpDir+"/CONTROL/")
        os.mkdir(tmpDir+"/DATA/")
        if not projectDir:
            projectDir = os.getcwd()

        # copy the required files
        if "files" in parsedFilesList:
            for (fileInfo, destination) in parsedFilesList["files"]:
                addFileToPackage(tmpDir, projectDir, fileInfo, destination)
        if "config" in parsedFilesList:
            for (fileInfo, destination) in parsedFilesList["config"]:
                addFileToPackage(tmpDir, projectDir, fileInfo, destination)
                if not "configFiles" in manifest:
                    manifest["configFiles"] = []
                manifest["configFiles"].append(str(destination))

        # write the package's manifest file
        with open(tmpDir+"/CONTROL/manifest", 'w') as file:
            file.write(lua.encode(manifest))

        if any(item in ['-s', '--strip-comments'] for item, v in opts):
            for luaFile in glob(root_dir=tmpDir+"/DATA/", pathname="**/*.lua", recursive=True):
                os.system(f'sed -i s/^--.*// {tmpDir+"/DATA/"+luaFile}')

        manifest["archiveName"] = f"{manifest['package']}.tar"
        with tarfile.open(pathlib.Path(outputDirectory, manifest["archiveName"]), 'w') as tar:
            tar.add(tmpDir+"/CONTROL", arcname="CONTROL",
                    filter=removeMetadata)
            tar.add(tmpDir+'/DATA/', arcname="DATA", filter=removeMetadata)
        return manifest


def addFileToPackage(tmpDir, source, fileInfo, destination):
    filePath = pathlib.Path(source, fileInfo)
    destination = pathlib.Path(destination)
    if (destination.is_absolute()):
        destination = destination.relative_to("/")
    destination = pathlib.Path(tmpDir, 'DATA', destination)

    if (filePath.is_dir()):
        shutil.copytree(filePath, destination)
    else:
        pathlib.Path(destination).mkdir(
            parents=True, exist_ok=True)
        shutil.copy(filePath, destination)


if __name__ == '__main__':
    # parse arguments
    # TODO : repo manifest update mode
    global opts, args
    try:
        opts, args = getopt.gnu_getopt(sys.argv[1:], 'hd:s', [
                                       'destination=', 'strip-comments'])
    except getopt.GetoptError as e:
        printError(e.msg)
        exit(1)

    # get the output dir absolute path
    outputDirectory = pathlib.Path(os.getcwd(), "packages/").absolute()

    # check and parse cmd line arguments
    for option, value in opts:
        if option in ("-h", "--help"):
            printUsage()
            exit(0)
        elif option in ("-d", "--destination"):
            outputDirectory = pathlib.Path(value).absolute()

    # make sure the output directory exists
    # TODO : arg to create the dir if doesnt' exists
    pathlib.Path(outputDirectory).mkdir(parents=True, exist_ok=True)

    # look for manifest files
    repoManifest = {}
    for pmManifestPath in glob("**/*.manifest"):
        manifestPath = pathlib.Path(pmManifestPath)
        projectDir = manifestPath.parent
        projectName = manifestPath.stem
        filesJson = pathlib.Path(projectDir, f"{projectName}.files.json")
        if not filesJson.exists():
            continue
        packageManifest = makePackage(
            projectDir, manifestPath, filesJson, outputDirectory)
        repoManifest[packageManifest["package"]] = packageManifest

    with open(pathlib.Path(outputDirectory, "manifest"), "w") as repoManifestFile:
        repoManifestFile.write(lua.encode(repoManifest))
