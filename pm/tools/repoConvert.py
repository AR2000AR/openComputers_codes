from slpp import slpp as lua
import pathlib
import json
import re
from pprint import pprint

def manifestOppmToPm(packageName,packageInfo):
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
    return manifest

def fileListOppmToPm(packageInfo,relativeTo=""):
    out = {"files":[],"config":[]}
    if "files" in packageInfo:
        for fileInfo,destination in packageInfo["files"].items():
            if re.match("//", destination):
                destination = destination[1:]
            else:
                destination = "/usr"+destination
            if destination[-1] != "/":
                destination = destination+"/"
            prefix = fileInfo[0]
            fileInfo=pathlib.Path(*pathlib.Path(fileInfo).parts[1:])
            if(fileInfo.is_relative_to(relativeTo)):
                fileInfo=fileInfo.relative_to(relativeTo)
            out["config" if prefix=="?" else "files"].append((str(fileInfo),destination))
    return out


with open('programs.cfg') as file:
    oppmManifest = lua.decode(file.read())
default=pathlib.Path("manifest/")
for pName,pInfo in oppmManifest.items():
    manifest=manifestOppmToPm(pName,pInfo)
    sourceDir = pathlib.Path(manifest["repo"]).relative_to("tree/master")
    if(sourceDir.exists() and sourceDir.is_dir()):
        out=sourceDir
        files=fileListOppmToPm(pInfo,pName)
    else:
        out = default
        files=fileListOppmToPm(pInfo)

    with open(pathlib.Path(out,f"{pName}.manifest"),"w") as f:
        f.write(lua.encode(manifest))
    with open(pathlib.Path(out,f"{pName}.files.json"),"w") as f:
        json.dump(files,f,indent="\t")

