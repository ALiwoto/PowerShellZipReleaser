using module "./CreateCsRelease.psm1"

param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [string]$Path,
    [Parameter(Mandatory = $false)]
    [switch]$Short
)

$csProjFiles = (((Get-ChildItem -Recurse -Path $Path).FullName | 
        Where-Object { 
            $_.EndsWith(".csproj", $true, $null) 
        }))

$csCustomObjects = $csProjFiles | ForEach-Object { @{ "Path" = "$_"; "Content" = (Get-Content -Path $_) } }


foreach ($currentObject in $csCustomObjects) {
    $currentContents = $currentObject["Content"]
    foreach ($currentLine in $currentContents) {
        if ($currentLine -is [string] -and $currentLine -like "*TargetFramework*") {
            # do some validations here
            $myStrs = $currentLine | Split-StringValue -Separators @("</", "<", ">")
            if ($myStrs.Count -lt 3) {
                # not what we are expecting
                continue
            }

            $currentObject["TargetFrameworkLine"] = $currentLine
            $currentObject["TargetFramework"] = $myStrs[1]
        }
    }
}

"Found $($csCustomObjects.Count) projects in the specified path." | Write-Host
$csCustomObjects | ForEach-Object {
    if ($Short) {
        "$(Split-Path -Path $_["Path"] -Leaf): $($_["TargetFramework"])" | Write-Host
    }
    else {
        "$($_["Path"]): $($_["TargetFramework"])" | Write-Host
    }
}



