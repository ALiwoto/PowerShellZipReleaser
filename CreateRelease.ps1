


class CsProjectContainer {
    [string]$CsProjectFilePath
    [string]$RawContent

    # Coonstructor of the CsProjectContainer class.
    CsProjectContainer(
        [string]$Path,
        [string]$RawContent,
        [string]$ProjectUUID = $null
    ) {
        $this.CsProjectFilePath = $Path
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
    param 
    (
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

    $myStrs = $allContent | Split-StringValue -Separators @("Project(", "EndProject") | Where-Object {
        $_.StartsWith("`"{") -and $_.EndsWith("}`"")
    }
    
    # "{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}") = "GUISharp", "GUISharp\GUISharp.csproj", "{6CB5C21A-EB16-48D6-B98A-F18D7CE46785}"
    $myStrs | Write-Host
    # $myStrs.StartsWith("`"{") | Write-Host
    # "ok" | Write-Host
    # $myStrs.EndsWith("}`"") | Write-Host
}

ConvertFrom-SlnFile -SlnPath "E:\abedini\projects\GUISharp\GUISharp.sln"

