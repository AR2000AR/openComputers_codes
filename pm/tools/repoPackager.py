#!/bin/python3
from slpp import slpp as lua
import tarfile
import sys
import getopt
import pprint
import os
import tempfile
import shutil
import pathlib
import re

PACKAGE_DIR = os.getcwd()+"/package/"
pathlib.Path(PACKAGE_DIR).mkdir(
    parents=True, exist_ok=True)

opts, args = getopt.getopt(sys.argv[1:], '', '')

raw = ""
with open(args[0], 'r') as file:
    raw = file.read()

data = lua.decode(raw)

for packageName, packageInfo in data.items():
    with tempfile.TemporaryDirectory(prefix="packager.") as tmpDir:
        os.mkdir(tmpDir+"/CONTROL/")
        os.mkdir(tmpDir+"/DATA/")

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
                    manifest["dependencies"] = []
                depDic = {}
                depDic[dep] = "0"
                manifest["dependencies"].append(depDic)

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
                if (prefix == "?"):  # add it to the config file list
                    if not "configFiles" in manifest:
                        manifest["configFiles"] = []
                    manifest["configFiles"].append(destination)

                print(f"{filePath} -> {destination}")
                destination = tmpDir+"/DATA"+destination

                if (prefix == ":"):
                    shutil.copytree(filePath, destination)
                else:
                    pathlib.Path(destination).mkdir(
                        parents=True, exist_ok=True)
                    shutil.copy(filePath, destination)

        with open(tmpDir+"/CONTROL/manifest", 'w') as file:
            file.write(lua.encode(manifest))

        version = manifest["version"]
        with tarfile.open(f"{PACKAGE_DIR}{packageName}_({version}).tar", 'w') as tar:
            tar.add(tmpDir+"/CONTROL", arcname="CONTROL")
            tar.add(tmpDir+'/DATA/', arcname="DATA")
