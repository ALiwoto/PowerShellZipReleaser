# PowerShellZipReleaser
A simple but efficient zip-releaser powershell script for packing .NET projects releases (tags).

# How does it work?
[ZipReleaser.ps1](ZipReleaser.ps1) should be run. It will take a git-upstream url from you (it can be for any git-hosting provider: GitHub, GitLab, Azure, etc...) and will ask for a few inputs which are as follow:
  1- Destination path to clone the repo:
        The destination path in which the repository will be cloned, we recommend using `clones\REPO_NAME`, since `clones\` directory is git-ingored.
    
  2- Name of the branch to switch to:
        The name of the branch you would like the script to switch to, it's set to the current branch's name by default, so you can just press `Enter` and continue; otherwise you will have to provide a valid branch name to the script.

  3- Name of the tag to switch to:
        The name of the tag you would like the script to switch to, it's set to the latest tag by default, so you can just press `Enter` and skip this step; otherwise you will have to either provide a valid and existing tag on this repo, or select the number of the tag you wish to switch in the list.

  4- Packing all of projects in a single .zip file:
        At this step, the script will ask you whether you want all of project binaries to be packed in one single .zip file or not. If enter `Y`, the script will compress all of the binaries inside of a single .zip file; otherwise the script will give separated .zip files for every projects discovered inside of the cloned repository. (this feature is not fully implemeneted yet, it's a #TODO for the future. For now, the script will give you a single .zip file in both cases.)

  5- destination path to store the zip file(s):
        At this step, the script will ask you to give the destination path to the final zip file(s).


