#!/bin/python3
import contextlib
import re
import sys
import tarfile
from datetime import datetime
from io import BytesIO
from os import environ
from pathlib import Path
from pprint import pprint
from tempfile import TemporaryDirectory

import github
from github.ContentFile import ContentFile
import pause
import requests
from slpp import slpp as lua
from tqdm import tqdm
from tqdm.contrib import DummyTqdmFile

# ==============================================================================
OPPM_REPOS_LIST_URL = "https://raw.githubusercontent.com/OpenPrograms/openprograms.github.io/master/repos.cfg"
OUT_DIR = Path(Path.home(), "tmp/oppmPackages")
OUT_DIR.mkdir(exist_ok=True)

# ==============================================================================


class MalformedPackage(Exception):
    """Error raised when a oppm package's manifest look malformed"""
    pass


class UnsuportedFileURI(MalformedPackage):
    pass


class UnsuportedDependanceName(MalformedPackage):
    pass


@contextlib.contextmanager
def std_out_err_redirect_tqdm():
    """Trick to allow multipes progress bars and text output"""
    orig_out_err = sys.stdout, sys.stderr
    try:
        sys.stdout, sys.stderr = map(DummyTqdmFile, orig_out_err)
        yield orig_out_err[0]
    # Relay exceptions
    except Exception as exc:
        raise exc
    # Always restore sys.stdout/err if necessary
    finally:
        sys.stdout, sys.stderr = orig_out_err

# ==============================================================================


def filterReposIfRepo(pair):
    """Remove repos with no "repo" field"""
    name, repo = pair
    return "repo" in repo


def filterReposIfPrograms(pair):
    """Remove repos with no "programs" field"""
    name, repo = pair
    return "programs" in repo


def rateLimitPause(githubInstance: github.Github):
    """Wait until github's api rate limit reset"""
    if (githubInstance.rate_limiting[0] == 0):
        until = datetime.fromtimestamp(githubInstance.rate_limiting_resettime)
        print(f"Hit rate limit. Waiting until {until.time()}")
        pause.until(githubInstance.rate_limiting_resettime)


def removeMetadata(tarObject: tarfile.TarInfo):
    """Remove mtime from the tarObject"""
    tarObject.mtime = 0
    return tarObject


def getGithubFileAsString(fileObj: ContentFile) -> str:
    """Get the string content of the github file"""
    if (fileObj.content):
        return fileObj.content
    else:
        with requests.get(fileObj.download_url) as response:
            return response.text


def makePackage(packageName: str, packageInfo: dict, repoPath: str,  outputDirectory: str | Path = './packages/'):
    with TemporaryDirectory(prefix="packager.") as tmpDir:
        repo = githubAPI.get_repo(repoPath)
        Path(tmpDir+"/CONTROL/").mkdir(exist_ok=True)
        Path(tmpDir+"/DATA/").mkdir(exist_ok=True)

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
                    if (Path(dep).parts[0][-1] == ":"):
                        # cannot handle protocols like http https
                        raise UnsuportedDependanceName(
                            f"Package {packageName} from {repoPath} is malformed")
                manifest["dependencies"][dep] = "oppm"
        if "repo" in packageInfo:
            url = packageInfo["repo"]
            manifest["url"] = f"https://github.com/{repoOwnerAndName}/{url}"

        files = {}
        # copy the required files
        if "files" in packageInfo:
            for fileInfo, destination in packageInfo["files"].items():
                if (type(fileInfo) != str):
                    continue
                if re.match("//", destination):
                    destination = destination[1:]
                else:
                    destination = "/usr"+destination
                if destination[-1] != "/":
                    destination = destination+"/"

                prefix = fileInfo[0]
                filePath = Path(*Path(fileInfo).parts[1:])
                ref = Path(fileInfo).parts[0]
                if (ref[-1] == ":"):
                    # cannot handle protocols like http https
                    raise UnsuportedFileURI(
                        f"Package {packageName} from {repoPath} is malformed : Invalid file")

                # check the prefix
                if (ref[0] in (":", "?")):
                    ref = ref[1:]
                if (prefix == "?"):  # add it to the config file list
                    if not "configFiles" in manifest:
                        manifest["configFiles"] = []
                    configFile = Path(
                        *Path(fileInfo).parts[2:])
                    manifest["configFiles"].append("/"+str(configFile))

                if (prefix == ":"):  # folder
                    rateLimitPause(githubAPI)
                    try:
                        contents = repo.get_contents(str(filePath), ref)
                    except github.GithubException as e:
                        raise MalformedPackage(e)
                    while contents:
                        file_content = contents.pop(0)
                        if file_content.type == "dir":
                            rateLimitPause(githubAPI)
                            try:
                                contents.extend(repo.get_contents(file_content.path, ref))
                            except github.GithubException as e:
                                raise MalformedPackage(e)
                        else:
                            files[file_content.path] = getGithubFileAsString(file_content)
                else:  # normal file
                    rateLimitPause(githubAPI)
                    try:
                        files[filePath] = getGithubFileAsString(repo.get_contents(str(filePath), ref))
                    except github.GithubException as e:
                        raise MalformedPackage(e)

        with open(tmpDir+"/CONTROL/manifest", 'w') as file:
            file.write(lua.encode(manifest))

        version = manifest["version"]
        # manifest["archiveName"] = f"{packageName}_({version}).tar"
        manifest["archiveName"] = f"{packageName}.tar"
        with tarfile.open(Path(outputDirectory, manifest["archiveName"]), 'w') as tar:
            tar.add(tmpDir+"/CONTROL", arcname="CONTROL",filter=removeMetadata)
            for filePath, data in files.items():
                data = data.encode()
                tinfo = tarfile.TarInfo(filePath)
                tinfo.size = len(data)
                tinfo.name = f"DATA/{filePath}"
                tinfo.mtime = 0
                tar.addfile(tinfo, BytesIO(data))
        return manifest


# ==============================================================================
if (environ.get("GITHUB_TOKEN") == None):
    print("\033[33mNo github token found\033[m")
else:
    print("\033[32mFound github token\033[m")


githubAPI = github.Github(login_or_token=environ.get("GITHUB_TOKEN"))

# ==============================================================================
with std_out_err_redirect_tqdm() as orig_stdout:
    reposList = None
    with requests.get(OPPM_REPOS_LIST_URL) as response:
        if (response.status_code == 200):
            reposList = lua.decode(response.text)

    reposList = dict(filter(filterReposIfRepo, reposList.items()))

    for repoName, info in tqdm(reposList.items(), unit="repo", desc="Fetching repos", file=orig_stdout):
        if ("repo" in info):
            repoGitRepo = info["repo"]
            with requests.get(f"https://raw.githubusercontent.com/{repoGitRepo}/master/programs.cfg") as response:
                if (response.status_code == 200):
                    if (type(lua.decode(response.text)) == dict):
                        reposList[repoName]["programs"] = lua.decode(
                            response.text)

    reposList = dict(filter(filterReposIfPrograms, reposList.items()))

    nbPackages = 0
    for repoDisplayName, info in reposList.items():
        if ("programs" in info):
            nbPackages += len(info["programs"])

    rateLimitPause(githubAPI)
    reposManifest = {}
    with tqdm(total=nbPackages, unit="package", desc="Building package", file=orig_stdout, position=1) as progressBar:
        for repoDisplayName, info in reposList.items():
            if ("programs" in info):
                programs = info["programs"]
                repoOwnerAndName = info["repo"]
                for package, packageInfo in tqdm(programs.items(), unit="package", desc=repoDisplayName, file=orig_stdout, position=0, leave=False):
                    progressBar.set_postfix_str(f"{repoDisplayName}:{package}")
                    with TemporaryDirectory(prefix="oppm-") as tmpDir:
                        if (not repoOwnerAndName in reposManifest):
                            reposManifest[repoOwnerAndName] = {}
                        Path(OUT_DIR, repoOwnerAndName).mkdir(exist_ok=True, parents=True)
                        try:
                            reposManifest[repoOwnerAndName][package] = makePackage(package, packageInfo, repoOwnerAndName, Path(OUT_DIR, repoOwnerAndName))
                        except MalformedPackage as e:
                            print(
                                f"\033[31m{repoOwnerAndName} : {package} : {e.__class__.__name__} : {e}\033[m")

                        finally:
                            progressBar.update(1)

    for repoOwnerAndName, repoManifest in reposManifest.items():
        with open(Path(OUT_DIR, repoOwnerAndName, "manifest"), "w") as repoManifestFile:
            repoManifestFile.write(lua.encode(repoManifest))
