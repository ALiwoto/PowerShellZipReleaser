# PowerShellZipReleaser
# Copyright (C) 2022 ALiwoto
# This file is subject to the terms and conditions defined in
# file 'LICENSE', which is part of the source code.

# script modules
using module ".\CreateCsRelease.psm1"

# dot-source dependency files.
. "./AdvancedUtils.ps1"

$script:ZipReleaserTmpDir = "ZipReleaser-tmp-Dir"
$ZipReleaserVersionString = "1.0.0"


function Show-WrongValueEntered {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$ValueName
    )

    process {
        "Looks like you have provided a wrong $ValueName`n" +
        "Please make sure the entered value is correct." | Write-Host
    }
}

function Read-ValueFromHost {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$ValueName,
        [Parameter(Mandatory = $false)]
        [string]$ValueDefault = $null,
        [Parameter(Mandatory = $false)]
        [switch]$NoPlease
    )
    
    $thePrompt = "Please enter the $ValueName"
    if ($NoPlease.ToBool()) {
        # there will be no please prompting anymore.
        $thePrompt = $ValueName
    }
    $theInput = ([string](Read-Host -Prompt $thePrompt)).Trim()
    if ([string]::IsNullOrEmpty($theInput)) {
        return $ValueDefault
    }

    return $theInput
}

function Read-DirPathFromHost {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$ValueName,
        [Parameter(Mandatory = $false)]
        [string]$ValueDefault = $null,
        [Parameter(Mandatory = $false)]
        $CreateIfNotExist = $true
    )

    $thePath = Read-ValueFromHost -ValueName $ValueName -ValueDefault $ValueDefault
    if ([string]::IsNullOrEmpty($thePath)) {
        return $thePath
    }

    if (-not ($thePath[-1] -eq "/" -or $thePath[-1] -eq "\")) {
        $thePath += "\"
    }

    if ((-not ([System.IO.Directory]::Exists($thePath)))) {
        [System.IO.Directory]::CreateDirectory($thePath)
        # looks like creating directory takes a bit time, and then git clone
        # command will fail because of this.. looks like git clone command
        # entirely runs at background, or something like that?
        Start-Sleep -Milliseconds 1200
    }

    return $thePath
}

class ConfigElement {
    # If set to $true, will prevent the script from asking for user-input
    # each time, instead will just use the value specified in the config hashtable.
    [bool]$UseConfigForAll = $false

    # The git-upstream uri (which points to the git repository host provider such as GitHub.com, etc)
    [uri]$GitUpstreamUri = $null

    # The destination path in which we will be cloning the repository and do our operations.
    # The destination path for putting zip file will be different tho, this value here only
    # points to the place where the repository will be located on our local machine.
    [string]$DestinationPath = $null

    # the path in which we will be storing our zip file(s).
    [string]$ZipDestinationPath = $null

    # The target tag. The tag in which we will be working on to build and pack a zip file out of it.
    [string]$TargetTag = $null

    # The target branch we will be switching to. User has the choice to give us an empty input,
    # which means we will just stay on the current default branch of the repository (and this varible
    # will be set to that branch as well.)
    [string]$TargetBranch = $null

    # The original PWD variable in which the script has been started. Normally the script has to
    # go to the location in which the repository is located on local machine (AKA: $DestinationPath),
    # for doing operations such as "git branch", "git checkout", "git describe", etc.
    # It's ideal for the script to do `Set-Location $OriginalPWD` after it's done for the current
    # operation.
    [string]$OriginalPWD = $null

    # Set to `$true` when and only when the user wants us to make zip files for every
    # single project defined in this repository separately.
    # (so count of .csproj files == count of .zip files)
    # If this is set to `$false`, we will build all once, and pack all once,
    # in other words, no matter how many .csproj files are defined in this repository,
    # at the end, we will have only 1 .zip file.
    [bool]$PackSeparatedPackages = $false

    # This property is here only and only because we want it to be cached in the
    # memory. It is NOT supplie by the user.
    [string[]]$AllRepoTags = $null

    # Paths of .sln files.
    [string[]]$SlnFilesPaths = $null

    # Paths of generated final .zip files (can be 1, or more).
    [string[]]$ZipFilesPaths = $null

    # Containers of all of cs-projects that we are going to build/modify.
    # Type of each element of this array SHOULD be CsProjectContainer class.
    [System.Object[]]$CsProjectContainers = $null

    # Set to $true if and only if we have to modify the version defined in
    # project config file of each of our projects. This property is set to $true
    # by default, in near future, we are planning to add support to modify the value of this
    # property by users.
    [bool]$ModifyProjectVersion = $true

    # count of failed builds/compilations.
    [int]$FailedBuilts = 0

    # count of succeeded builds/compilations.
    [int]$SucceededBuilts = 0

    # The path in remote server in which we will be copying the final
    # zip file over.
    [string]$SSHTargetPath = $null

    # The identity file path (which has to be passed with -i arg) for the ssh.
    [string]$SSHIdentifyFilePath = $null

    # Creates a new instance of ConfigElement class and tries to
    # assign all of the variables via 
    ConfigElement() {
        $this.GitUpstreamUri = $Env:GIT_UPSTREAM_URI -as [string]
        $this.DestinationPath = $Env:DESTINATION_PATH -as [string]
        $this.TargetBranch = $Env:TARGET_BRANCH -as [string]
        $this.TargetTag = $Env:TARGET_TAG -as [string]
        $this.SSHTargetPath = $Env:SSH_TARGET_PATH -as [string]
        $this.SSHIdentifyFilePath = $Env:SSH_IDENTIFYFILE_PATH -as [string]
        $this.PackSeparatedPackages = $Env:PACK_SEPARATED_PACKAGE -as [bool]
        $this.ModifyProjectVersion = $Env:MODIFY_PROJECT_VERSION -as [bool]
        $this.UseConfigForAll = $Env:USE_CONFIG_FOR_ALL -as [bool]
    }

    # Creates a new instance of ConfigElement class.
    # Please do notice that the passed-argument MUST be an instance of [hashtable] type.
    ConfigElement([hashtable]$ParsedValue) {
        $this.GitUpstreamUri = $ParsedValue["upstream_url"] -as [string]
        $this.DestinationPath = $ParsedValue["destination_path"] -as [string]
        $this.TargetBranch = $ParsedValue["target_branch"] -as [string]
        $this.TargetTag = $ParsedValue["target_tag"] -as [string]
        $this.PackSeparatedPackages = $ParsedValue["pack_separated_packages"] -as [bool]
        $this.ModifyProjectVersion = $ParsedValue["modify_project_version"] -as [bool]
        $this.UseConfigForAll = $ParsedValue["use_config_for_all"]
    }

    [void]SetDestinationPath() {
        if (-not [string]::IsNullOrEmpty($this.DestinationPath)) {
            if ($this.UseConfigForAll) {
                # all is good
                return
            }

            # the value is set, but should be displayed for the user
            # to confirm.
            $this.DestinationPath = ("destination path to clone the repo (default: " +
                "$($this.DestinationPath))") | Read-DirPathFromHost -ValueDefault $this.DestinationPath
            return
        }

        $this.DestinationPath = ("destination path to clone the repo" | Read-DirPathFromHost)
        if ($this.DestinationPath -is [string]) {
            $this.DestinationPath = $this.DestinationPath.Trim()
        }

        if ([System.IO.Directory]::Exists($this.DestinationPath + ".git")) {
            "Removing items from $($this.DestinationPath) because there are already " +
            "files in it" | Write-Host -ForegroundColor "Red"
            Remove-Item -Path $this.DestinationPath -Recurse -Force -WarningAction "SilentlyContinue"
        }

        "Cloning your repository to $($this.DestinationPath)" | Write-Host
    }

    [bool]CloneGitRepository() {
        [string[]]$gitOutput = (Invoke-CloneGitRepository -RepoUrl $this.GitUpstreamUri -DestinationPath $this.DestinationPath)
        if ($null -ne $gitOutput -and $gitOutput.Length -ge 1) {
            $gitOutput[-1] | Write-Host
        }

        return ([System.IO.Directory]::Exists($this.DestinationPath + ".git"))
    }

    [bool]SwitchToBranch([string]$BranchName) {
        $gitOutputs = (git checkout $BranchName 2>&1)
        foreach ($currentGitOutput in $gitOutputs) {
            # $currentGitOutput here can be [System.Management.Automation.ErrorRecord] or
            # [string] types, so be better be using (-as [string]) for it.
            $currentGitOutput = ($currentGitOutput -as [string])

            if ($currentGitOutput.Contains("Already on") -or
                $currentGitOutput.Contains("Switched to") -or 
                $currentGitOutput.Contains("Your branch is up to date with")) {
                # All is good. let it pass
                return $true
            }
        }

        return $false
    }

    [void]SetTargetBranch() {
        $defaultValuePrompt = $null
        if (-not [string]::IsNullOrEmpty($this.TargetBranch)) {
            if ($this.UseConfigForAll) {
                if ($this.TargetBranch -ne "default") {
                    if (-not ($this.SwitchToBranch($this.TargetBranch))) {
                        "Invalid branch name has provided (or there were " +
                        "some other issues when switching)." | Write-Host
                        return
                    }

                    # All is good, we don't need to prompt user for getting input string.
                    return
                }

                # When user has set "default" in their config file, it means
                # we will have to fetch the current branch, and don't switch to
                # any branch at all.
                $this.TargetBranch = Get-CurrentGitBranch
                return
            }

            $defaultValuePrompt = "use default config "
        }
        else {
            $this.TargetBranch = Get-CurrentGitBranch
            $defaultValuePrompt = "stay at current branch"
        }


        "We are currently on branch `"$($this.TargetBranch)`"" | Write-Host
        while ($true) {
            $branchNameToSwitch = "name of the new branch to switch to (or empty " +
            "string to $defaultValuePrompt)" | Read-ValueFromHost

            if ([string]::IsNullOrEmpty($branchNameToSwitch)) {
                # we will stay on this branch.
                break
            }

            if (-not ($this.SwitchToBranch($branchNameToSwitch))) {
                "Invalid branch name has provided (or there were " +
                "some other issues when switching)." | Write-Host
                continue
            }

            $this.TargetBranch = $branchNameToSwitch
            break
        }
    }

    [bool]SwitchToTag([string]$TagName) {
        return $this.SwitchToTag($TagName, $true)
    }

    [bool]SwitchToTag([string]$TagName, [bool]$Confirm) {
        $this.GetAllRepoTags()
        
        if ($Confirm -and -not ($this.AllRepoTags -contains $TagName)) {
            return $false
        }
        
        $this.TargetTag = $TagName
        $gitOutput = (git checkout tags/$TagName 2>&1)
        if ($null -eq $gitOutput -or $gitOutput.Count -eq 0) {
            return $false
        }

        $outputStr = $gitOutput[0].ToString()
        if ($outputStr.Contains("switching to") -or $outputStr.Contains("HEAD is now at")) {
            # two kind of outputs are expected here:
            # 1- "Note: switching to 'tags/v1.1.10'."
            # 2- "HEAD is now at 23973e8 Do some code refactor."
            return $true
        }

        "Unexpected output from git checkout command while switching to " +
        "tag $($this.TargetTag): $outputStr" | Write-Error

        return $false
    }

    [string[]]GetAllRepoTags() {
        return $this.GetAllRepoTags($false)
    }

    [string[]]GetAllRepoTags([bool]$ForceFetch = $false) {
        if ($null -ne $this.AllRepoTags -and $this.AllRepoTags.Length -gt 0 -and -not $ForceFetch) {
            # Just return the cached value in the momery if all of the tags are already fetch'ed.
            # This will increase running-time a lot, specially when we have large amount of tags in
            # large repositories and don't want to receive and parse them all again each time.
            return $this.AllRepoTags
        }

        $this.AllRepoTags = Get-AllGitTags
        return $this.AllRepoTags
    }

    [bool]HasAnyTags() {
        return ($null -ne $this.AllRepoTags -and $this.AllRepoTags.Count -gt 0)
    }

    [void]SetTargetTag() {
        $defaultValuePrompt = $null
        # make sure the repo tags are cached.
        $this.GetAllRepoTags()
        if (-not $this.HasAnyTags) {
            throw "The repository does not contain any tags."
        }

        if (-not [string]::IsNullOrEmpty($this.TargetTag)) {
            if ($this.UseConfigForAll) {
                if ($this.TargetTag -eq "latest") {
                    # make sure to get the latest tag and set it here, if
                    # user has "latest" value set in their config file.
                    $this.SwitchToTag($this.AllRepoTags[-1])
                    "Target tag has been sent to $($this.TargetTag)!" | Write-Host
                    return
                }
                
                if (-not ($this.SwitchToTag($this.TargetTag))) {
                    throw "Invalid tag name has provided (or there were " +
                    "some other issues when switching).`n"+
                    "Please re-confirm the existence of the tag."
                }

                # All is good, we don't need to prompt user for getting input string.
                return
            }

            $defaultValuePrompt = "use config value ($($this.TargetTag))"
        }
        else {
            $this.TargetTag = $this.AllRepoTags[-1]
            $defaultValuePrompt = "use the latest tag"
        }

        

        $tagsListStr = "Here is a list of tags for this repository:`n"
        for ($i = 0; $i -lt $this.AllRepoTags.Count; $i++) {
            $tagsListStr += "$i- $($this.AllRepoTags[$i])`n"
        } 
        
        $tagsListStr| Write-Host
        "The latest tag for this repository is `"$($this.TargetTag)`"" | Write-Host
        while ($true) {
            $tagNameToSwitch = "name of the target tag to switch to (or empty " +
            "string to $defaultValuePrompt)" | Read-ValueFromHost

            if ([string]::IsNullOrEmpty($tagNameToSwitch)) {
                if (-not ($this.SwitchToTag($this.TargetTag))) {
                    "Invalid tag name has provided (or there were " +
                    "some other issues when switching).`n"+
                    "Please re-confirm the existence of the tag." | Write-Host
                    continue
                }
                # we will stay on the default-provided tag.
                break
            }

            try {
                $tagNameToSwitch = $this.AllRepoTags[[int]$tagNameToSwitch]
            }
            catch {}

            if (-not ($this.SwitchToTag($tagNameToSwitch))) {
                "Invalid tag name has provided (or there were " +
                "some other issues when switching).`n"+
                "Please re-confirm the existence of the tag." | Write-Host
                continue
            }

            break
        }


        # $this.SwitchToTag method has already changed the value
        # of $this.TargetTag, there is no need to change it again here.
        "Target tag has been set to $($this.TargetTag)!" | Write-Host
    }

    [void]DiscoverProjects() {
        $this.PackSeparatedPackages = ("Would you like to pack all of the projects in this"  +
        " repository to a single .zip file?`n" +
        "(Y/N)" | Read-ValueFromHost -NoPlease).Trim() -ne "y"

        foreach ($currentSlnFile in Get-ChildItem ".\" -Filter "*.sln" -Recurse) {
            $currentSlnPath = $currentSlnFile.PSPath | Get-NormalizedPSPath
            $this.SlnFilesPaths += $currentSlnPath
            $currentCsProjs = $currentSlnPath | ConvertFrom-SlnFile

            "Discovered Solution File: " | Write-Host -NoNewline -ForegroundColor "Green"
            $currentSlnPath | Write-Host
            if ($null -eq $currentCsProjs -or $currentCsProjs.Count -eq 0) {
                "   Found 0 cs-projects in this solution file." | Write-Host -ForegroundColor "Gray"
                continue
            }

            foreach ($currentCsProj in $currentCsProjs) {
                $this.CsProjectContainers += $currentCsProj
                "   Found " | Write-Host -NoNewline
                "$($currentCsProj.ProjectName)" | Write-Host -ForegroundColor "Green" -NoNewline
                ": $($currentCsProj.CsProjectFilePath)" | Write-Host

                if ($this.ModifyProjectVersion) {
                    $currentCsProj.ModifyProjectVersion($this.TargetTag)
                }
            }

            "`n" | Write-Host
        }
    }

    [object]GetCsProjectByName([string]$TheName) {
        foreach ($currentProject in $this.CsProjectContainers) {
            if ($currentProject.ProjectName -eq $TheName) {
                return $currentProject
            }
        }

        return $null
    }

    [void]BuildProjects() {
        $originalPWDPath = $PWD
        foreach ($currentSlnPath in $this.SlnFilesPaths) {
            $currentSlnParent = Split-Path -Path $currentSlnPath
            Set-Location $currentSlnParent

            $dotnetOutput = (dotnet build 2>&1)
            if (-not $dotnetOutput -or $dotnetOutput.Count -eq 0) {
                throw "Unexpected empty response received from dotnet build command"
            }


            foreach ($currentLine in $dotnetOutput) {
                if (-not $currentLine.Contains(" -> ")) {
                    # this isn't what we are looking for.
                    continue
                }

                $tmpStrs = $currentLine.Split(" -> ", 2,"RemoveEmptyEntries")
                $theProject = $this.GetCsProjectByName($tmpStrs[0].Trim())
                $theProject.IsBuilt = $true
            }
        }
        
        Set-Location $originalPWDPath
    }

    [void]SetZipZipDestinationPath() {
        if (-not [string]::IsNullOrEmpty($this.ZipDestinationPath)) {
            if ($this.UseConfigForAll) {
                # all is good
                return
            }

            # the value is set, but should be displayed for the user
            # to confirm.
            $this.ZipDestinationPath = ("destination path to store the zip file(s) (default: " +
                "$($this.ZipDestinationPath))") | Read-DirPathFromHost -ValueDefault $this.ZipDestinationPath
            return
        }

        $this.ZipDestinationPath = ("destination path to store the zip file(s)" | Read-DirPathFromHost)
        if ($this.ZipDestinationPath -is [string]) {
            $this.ZipDestinationPath = $this.ZipDestinationPath.Trim()
        }

        $tmpZippingPath = $this.GetTempZipDestinationPath()
        if ([System.IO.Directory]::Exists($this.GetTempZipDestinationPath())) {
            Remove-Item -Path $this.GetTempZipDestinationPath() -Recurse -Force -WarningAction "SilentlyContinue"
        }

        New-Item -Path $tmpZippingPath -ItemType "Directory"
    }

    [string]GetTempZipDestinationPath() {
        return $script:ZipReleaserTmpDir + "ZipReleaser-tmp-folder$global:PID"
    }

    [void]ZipProjects() {
        $tmpZipDest = $this.GetTempZipDestinationPath()
        New-Item -Path ($tmpZipDest) -ItemType "Directory"
        foreach ($currentCsProject in $this.CsProjectContainers) {
            if (-not $currentCsProject.IsBuilt) {
                $this.FailedBuilts++
                continue
            }

            $this.SucceededBuilts++
            $myBin = $currentCsProject.GetBinFolderPath()
            $copyingDest = $tmpZipDest + [System.IO.Path]::DirectorySeparatorChar + $currentCsProject.ProjectName
            (Copy-Item -Path $myBin -Destination ($copyingDest) -Force -Recurse)
        }

        $zipRawName = $this.CsProjectContainers[0].SlnName.Substring(0, $this.CsProjectContainers[0].SlnName.Length - 4) 
        $pathToSave = $global:PWD.ToString() + [System.IO.Path]::DirectorySeparatorChar + 
        $script:ZipReleaserTmpDir + [System.IO.Path]::DirectorySeparatorChar
        New-Item -Path $pathToSave -ItemType "Directory" -Force -ErrorAction "SilentlyContinue"

        $this.ZipFilesPaths += $pathToSave + "$zipRawName-$($this.TargetTag).zip"
        $compressOutput = Compress-Archive -Path ($tmpZipDest + "\*") -DestinationPath $this.ZipFilesPaths[0]`
            -CompressionLevel "Optimal" -Force
        $compressOutput | Write-Host
    }
}

class ConfigContainer {
    [hashtable]$AllConfigs

    ConfigContainer() {
        $this.AllConfigs = [hashtable]::new()
    }

    [void]AddConfig([string]$Name, $ConfigValue) {
        $this.AllConfigs.Add($Name, [ConfigElement]::new($ConfigValue))
    }

    [ConfigElement]GetConfig([string]$Name) {
        return $this.AllConfigs[$Name]
    }

    [bool]Contains([string]$Name) {
        return $this.AllConfigs.Contains($Name)
    }
}

function Read-JsonConfig {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$Path = "config.json"
    )

    process {
        if (-not ([System.IO.File]::Exists($Path))) {
            return $null
        }
    
        $configValue = (Get-Content -Path $Path -Raw | ConvertFrom-Json) | ConvertFrom-PSObject
        $theContainer = [ConfigContainer]::new()
        foreach ($currentConfig in $configValue["configs"]) {
            $theContainer.AddConfig($currentConfig["name"], $currentConfig)
        }
    
        return $theContainer
    }
}

function Start-MainOperation {
    [ConfigContainer]$projectConfigContainer = Read-JsonConfig
    [string]$userInput = $null
    [ConfigElement]$currentConfig = $null
    
    while ($true) {
        # reset variables.
        $currentConfig = $null

        $userInput = ("Git-upstream url (or name of your config)" | Read-ValueFromHost)
        if ([string]::IsNullOrWhiteSpace($userInput)) {
            "Git-upstream url (or a valid config name)" | Show-WrongValueEntered
            continue
        }
        elseif ($userInput -eq "exit") {
            return $false
        }
    
        if ($userInput.StartsWith("http")) {
            # user has directly entered a http url, just set that.
            $currentConfig = [ConfigElement]::new()
            $currentConfig.GitUpstreamUri = $userInput
        }
        elseif ($null -ne $projectConfigContainer -and $projectConfigContainer.Contains($userInput)) {
            $currentConfig = $projectConfigContainer.GetConfig($userInput)
        }
        elseif ([System.IO.File]::Exists("$userInput.config.json")) {
            $projectConfigContainer = Read-JsonConfig -Path "$userInput.config.json"
            $currentConfig = $projectConfigContainer.GetConfig($userInput)
            if ($null -eq $currentConfig) {
                "I have found $userInput.config.json file, but looks like the file doesn't" +
                "contain a valid config with the same name" +
                "Please make sure the config is valid" | Write-Host
                continue
            }

            $userInput = "I have imported the config with name `"$userInput`" for you.`n" +
            "Would you like to use all of the values in this config? Or just use them " +
            "as default value for each stage? (A=All, D=Default-values)" | Read-ValueFromHost
            $currentConfig.UseConfigForAll = ($userInput -eq "A")
        }
        else {
            "Git-upstream url (or a valid config name)" | Show-WrongValueEntered
            continue
        }

        break
    }

    $currentConfig.SetDestinationPath()
    if (-not $currentConfig.CloneGitRepository()) {
        "Git clone operation has failed! Please check the url and destination " +
        "path and try again." | Write-Host
        return $true
    }

    $currentConfig.OriginalPWD = $PWD
    Set-Location $currentConfig.DestinationPath

    $currentConfig.SetTargetBranch()
    $currentConfig.SetTargetTag()
    $currentConfig.DiscoverProjects()
    $currentConfig.BuildProjects()
    $currentConfig.SetZipZipDestinationPath()
    $currentConfig.ZipProjects()

    Set-Location $currentConfig.OriginalPWD

    $finalFileNames = @()

    foreach ($currentZipFilePath in $currentConfig.ZipFilesPaths) {
        $finalFileNames += ($currentConfig.ZipDestinationPath +
            (Split-Path -Path $currentZipFilePath -Leaf))
        Move-Item -Path $currentZipFilePath -Destination $currentConfig.ZipDestinationPath -Force -ErrorAction "SilentlyContinue"
    }

    if ($this.$ZipFilesPaths.Count -gt 1) {
        "List of Zip files: " | Write-Host
    } else {
        "Final Zip file: "
    }
    foreach ($currentZipPath in $this.$ZipFilesPaths) {
        "-> $($this.$ZipFilesPaths)" | Write-Host -ForegroundColor "Green"
    }

    "[*] Total Projects built: $($currentConfig.SucceededBuilts) " +
    " / Failed builts: $($currentConfig.FailedBuilts)" +
    "`n[*] Total Solutions built: $($currentConfig.SlnFilesPaths.Count)" +
    "`n[*] Total zip files: $($this.$ZipFilesPaths.Count)" | Write-Host
    
    $sshPathToSave = "ssh path to upload the zip artifact" | Read-ValueFromHost
    if (-not $sshPathToSave -or $sshPathToSave.Length -eq 0) {
        return $true
    }

    foreach ($currentFinalFile in $finalFileNames) {
        $scpResult = (scp $currentFinalFile $sshPathToSave 2>&1)
        $scpResult | Write-Host
    }

    "Done!" | Write-Host
    return $true
}


"=====================================`n" +
"Welcome to ZipReleaser Version $ZipReleaserVersionString`n" +
"=====================================`n" | Write-Host

while ($true) {
    if (-not (Start-MainOperation)) {
        "Thank you for taking your time and trying out this script!" | Write-Host
        break
    }
}
