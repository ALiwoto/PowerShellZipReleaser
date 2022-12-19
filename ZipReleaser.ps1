
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
        [string]$ValueDefault = $null
    )
    
    $theInput = [string](Read-Host -Prompt "Please enter the $ValueName").Trim()
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

function Invoke-CloneGitRepository {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$RepoUrl,
        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )

    $ok = (git clone $RepoUrl $DestinationPath --progress 2>&1)
    return $ok
}

class ConfigElement {
    [bool]$UseConfigForAll = $false
    [uri]$GitUpstreamUri = $null
    [string]$DestinationPath = $null

    ConfigElement() {
        # no params here, default value
        $this.GitUpstreamUri = $null
        $this.DestinationPath = $null
    }

    ConfigElement($ParsedValue) {
        $this.GitUpstreamUri = $ParsedValue["upstream_url"]
        $this.DestinationPath = $ParsedValue["destination_path"]
    }

    [void]SetDestinationPath() {
        if (-not [string]::IsNullOrEmpty($this.DestinationPath)) {
            if ($this.UseConfigForAll) {
                # all is good
                return
            }

            # the value is set, but should be displayed for the user
            # to confirm.
            $this.DestinationPath = ("Enter destination path to clone the repo (default: " +
            $this.DestinationPath + ")") | Read-DirPathFromHost -ValueDefault $this.DestinationPath
            return
        }

        $this.DestinationPath = ("Enter destination path to clone the repo" | Read-DirPathFromHost)
        $this.DestinationPath | Write-Host
    }

    [bool]CloneGitRepository() {
        [string[]]$gitOutput = (Invoke-CloneGitRepository -RepoUrl $this.GitUpstreamUri`
            -DestinationPath $this.DestinationPath)
        if ($null -ne $gitOutput -and $gitOutput.Length -ge 1) {
            $gitOutput[-1] | Write-Host
        }

        $ok = ([System.IO.Directory]::Exists($this.DestinationPath + ".git"))
        return $ok
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
        if (-not (Test-Path -Path $Path)) {
            return $null
        }
    
        $configValue = (Get-Content -Path $Path -Raw | ConvertFrom-Json)[0]
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
        elseif (Test-Path ("$userInput.config.json")) {
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
