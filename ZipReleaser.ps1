
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
        $ValueName,
        [Parameter(Mandatory = $false)]
        $ValueDefault = $null
    )
    
    $theInput = (Read-Host -Prompt "Please enter the $ValueName")
    if ([string]::IsNullOrEmpty($theInput)) {
        return $ValueDefault
    }

    return $theInput
}

function Invoke-CloneGitRepository {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$RepoUrl,
        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )

    return (git clone $RepoUrl $DestinationPath)
}

class ConfigElement {
    [bool]$UseConfigForAll = $false
    [uri]$GitUpstreamUri
    [string]$DestinationPath

    ConfigElement() {
        # no params here, default value
    }

    ConfigElement($ParsedValue) {
        $this.GitUpstreamUri = $ParsedValue["upstream_url"]
        $this.DestinationPath = $ParsedValue["destination_path"]
    }

    [void]SetDestinationPath() {
        if ($this.DestinationPath) {
            if ($this.UseConfigForAll) {
                # all is good
                return
            }

            # the value is set, but should be displayed for the user
            # to confirm.
            $this.DestinationPath = "Enter destination path to clone the repo (default: " +
            $this.DestinationPath + ")" | Read-ValueFromHost -ValueDefault $this.DestinationPath
            return
        }

        $this.DestinationPath = "Enter destination path to clone the repo" | Read-ValueFromHost
    }

    [void]CloneGitRepository() {
        Invoke-CloneGitRepository -RepoUrl $this.GitUpstreamUri -DestinationPath $this.DestinationPath
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
    
        $configValue = Get-Content -Path $Path -Raw | ConvertFrom-Json -AsHashtable
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
        elseif ($null -ne $projectConfigContainer.Contains($userInput)) {
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
    $currentConfig.CloneGitRepository()
    
    "Done!" | Write-Host
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
