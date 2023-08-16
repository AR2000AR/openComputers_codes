#!/bin/python3
from slpp import slpp as lua
import pathlib
import json
import re
from getopt import gnu_getopt as getopt
from getopt  import GetoptError
import colorama
import sys
from glob import glob

def printe(msg):
    print(f"{colorama.Fore.RED}{msg}{colorama.Fore.RESET}", file=sys.stderr)

def printw(msg):
    print(f"{colorama.Fore.YELLOW}{msg}{colorama.Fore.RESET}")

def printHelp():
    print(f"{sys.argv[0]} [-f|--from <name>] [-t|--to <name>]")
    print('\t<name> : one of "oppm" or "pm"')

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

def fileListOppmToPm(packageInfo,root=""):
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
            if(fileInfo.is_relative_to(root)):
                fileInfo=fileInfo.relative_to(root)
            out["config" if prefix=="?" else "files"].append((str(fileInfo),destination))
    return out

def doOppmToPm():
    with open('programs.cfg') as file:
        oppmManifest = lua.decode(file.read())
    default=pathlib.Path("manifest/")
    for pName,pInfo in oppmManifest.items():
        manifest=manifestOppmToPm(pName,pInfo)
        sourceDir = pathlib.Path(manifest["repo"]).relative_to("tree/master")
        if(sourceDir.exists() and sourceDir.is_dir()):
            out=sourceDir
        else:
            out = default
        files=fileListOppmToPm(pInfo,out)

        with open(pathlib.Path(out,f"{pName}.manifest"),"w") as f:
            f.write(lua.encode(manifest))
        with open(pathlib.Path(out,f"{pName}.files.json"),"w") as f:
            json.dump(files,f,indent="\t")

def recurseConfig(folderPath:pathlib.Path,fileDst,origin=None):
    out = dict()
    origin = origin or folderPath
    dirFiles = glob(f"{str(folderPath)}/**",recursive=True)
    for configPath in dirFiles:
        configPath=pathlib.Path(configPath)
        if(configPath.is_dir()):
            out |= recurseConfig(configPath,fileDst,origin)
        else:
            dst = pathlib.Path(fileDst,folderPath)
            if(fileDst.is_relative_to("/usr")):
                dst = f"/{dst.relative_to('/usr')}"
            else:
                dst = f"/{dst}"
            out[f"?master{str(configPath)}"] = dst
    return out

def doPmToOppm():
    manifestFiles = glob("*/*.manifest")
    manifestFiles = [pathlib.Path(path) for path in manifestFiles]
    oppmData = dict()
    for path in manifestFiles:
        manifest = None
        with path.open() as file:
            manifest = lua.decode(file.read())
        pName=manifest['package']
        
        fileListPath = pathlib.Path(path.parent,f"{pName}.files.json")
        if(not fileListPath.is_file()):
            printe(f"Could not find file list for {pName} in {str(path.parent)}")
            continue
        files=None
        with fileListPath.open() as file:
            files=json.load(file)

        oppmData[pName] = manifest
        oppmData[pName].pop('package')
        oppmData[pName].pop('manifestVersion')

        oppmData[pName]["files"] =  dict()
        for filePaths in files["files"]:
            filePath,fileDst = filePaths[0],filePaths[1]
            filePath = pathlib.Path(path.parent,filePath)
            fileDst = pathlib.Path(fileDst)
            if(not filePath.exists()):
                printw(f"Error in the file list for {pName} : {str(filePath)} does not exists")
            
            if(fileDst.is_relative_to("/usr")):
                fileDst = f"/{fileDst.relative_to('/usr')}"
            else:
                fileDst = f"/{fileDst}"

            if(filePath.is_dir()):
                oppmData[pName]["files"][f":master/{str(filePath)}"] = fileDst
            else:
                oppmData[pName]["files"][f"master/{str(filePath)}"] = fileDst

        for filePaths in files["config"]:
            filePath,fileDst = filePaths[0],filePaths[1]
            filePath = pathlib.Path(path.parent,filePath)
            fileDst = pathlib.Path(fileDst)
            if(not filePath.exists()):
                printw(f"Error in the file list for {pName} : {str(filePath)} does not exists")
            
            if(fileDst.is_relative_to("/usr")):
                fileDst = f"/{fileDst.relative_to('/usr')}"
            else:
                fileDst = f"/{fileDst}"

            if(filePath.is_dir()):
                oppmData[pName]["files"] |= recurseConfig(filePath,fileDst)
            else:
                oppmData[pName]["files"][f"?master/{str(filePath)}"] = fileDst

        if("dependencies" in oppmData[pName]):
            for k in oppmData[pName]["dependencies"].keys():
                oppmData[pName]["dependencies"][k]="/"

    fields = ("version","name","repo","description","authors","dependencies","files","note")
    data = lua.encode(oppmData)
    for field in fields:
        data=re.sub(re.escape(f'["{field}"]'),field,data)

    with open("programs.cfg","w") as file:
        file.write(data)

if __name__ == '__main__':
    global opts,args
    try:
        r=re.compile("-*(.*)")
        opts = dict()
        optsList, args = getopt(sys.argv[1:], 'hf:t:', ['from=', 'to=','strip-comments'])
        for k,v in optsList:
            k=r.findall(k)[0]
            opts[k]=v
    except GetoptError as e:
        printe(e.msg)
        exit(1)

    if("h" in opts):
        printHelp()
        exit()

    if(not ("from" in opts or "f" in opts)):
        printHelp()
        exit(1)
    if(not ("to" in opts or "t" in opts)):
        printHelp()
        exit(1)

    opts["from"] = opts["from"] if "from" in opts else  opts["f"]
    opts["to"] = opts["to"] if "to" in opts else  opts["t"]

    if(opts["from"] == "oppm"):
        if(opts["to"] == "pm"):
            doOppmToPm()
    if(opts["from"] == "pm"):
        if(opts["to"] == "oppm"):
            doPmToOppm()