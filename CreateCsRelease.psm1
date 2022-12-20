
class CsProjectContainer {
    [string]$ProjectName
    [string]$CsProjectFilePath
    [string]$RawContent
    [string]$CsUUID

    # Coonstructor of the CsProjectContainer class.
    CsProjectContainer(
        [string]$Path,
        [string]$TheName,
        [string]$RawContent,
        [string]$ProjectUUID = $null
    ) {
        $this.ProjectName = $TheName
        $this.CsProjectFilePath = $Path
        $this.CsUUID = $ProjectUUID
        if ($RawContent) {
            $this.RawContent = $RawContent
        }
        else {
            $this.RawContent = $this.GetRawContent()
        }
    }

    # Returns the raw content of the target .csproj file.
    [string]GetRawContent() {
        return Get-Content -Path $this.CsProjectFilePath -Raw
    }

    # Removes the raw content of the target .csproj file cached inside of
    # the memory.
    [void]RemoveRawContent() {
        $this.RawContent = $null;
    }
}

function Split-StringValue {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$InputObject,
        [string[]]$Separators = " "
    )
    
    
    process {
        return $InputObject.Split($Separators, 
            [System.StringSplitOptions]::RemoveEmptyEntries) |
        ForEach-Object {
            if ([string]::IsNullOrWhiteSpace($_)) {
                return $null
            }

            return $_.Trim()
        } | Where-Object { $null -ne $_ }
    }
}

# This function tries to parse the contents inside of a .sln file (visual studio solution file)
# and returns an array of CsProjectContainer class instances.
function ConvertFrom-SlnFile {
    param
    (
        [string]$SlnPath
    )
    
    $allContent = Get-Content -Path $SlnPath -Raw

    # parsed value will be something like this:
    # "{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}") = "GUISharp", "GUISharp\GUISharp.csproj", "{6CB5C21A-EB16-48D6-B98A-F18D7CE46785}"
    $projectsStrs = $allContent | Split-StringValue -Separators @("Project(", "EndProject") | Where-Object {
        $_.StartsWith("`"{") -and $_.EndsWith("}`"")
    }
    
    [CsProjectContainer[]]$allCsProjectContainers = @()
    foreach ($currentProjectStr in $projectsStrs) {
        # csInfos will be something like this:
        # 0- {FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}")
        # 1- "GUISharp"
        # 2- "GUISharp\GUISharp.csproj"
        # 3- "{6CB5C21A-EB16-48D6-B98A-F18D7CE46785}"
        # do note that 0th index is useless for us here, because it's just a unique-id assigned to the current
        # solution (ig? because it's shared between all of the csproject in the solution, most of the times.).
        # index 1 is the project name;
        # index 2 is the project path;
        # index 3 is the project unique-id;
        $csInfos = $currentProjectStr | Split-StringValue -Separators @("=", ",") | ForEach-Object {
            $_.Trim("`"")
        }
        $allCsProjectContainers += [CsProjectContainer]::new($csInfos[2], $csInfos[1], $null, $csInfos[3])
    }

    return $allCsProjectContainers
}

