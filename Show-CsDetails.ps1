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

$csCustomObjects = $csProjFiles | ForEach-Object { 
    @{ "Path" = "$_"; "Content" = (Get-Content -Path $_) }
}


foreach ($currentObject in $csCustomObjects) {
    $currentContents = $currentObject["Content"]
    foreach ($currentLine in $currentContents) {
        if ($currentLine -isnot [string] -or [string]::IsNullOrEmpty($currentLine)) {
            continue
        }

        # do some validations here
        if ($currentLine -notmatch "TargetFramework|ProductVersion|OutputType|AppDesignerFolder|AssemblyInfo\.cs") {
            continue
        }

        $myStrs = $currentLine | Split-StringValue -Separators @("</", "<", ">")
        if ($myStrs.Count -lt 3) {
            if ($myStrs -is [string]) {
                # single string
                $myStrs = @($myStrs)
            }

            if (($myStrs[0] -as [string]).Contains("AssemblyInfo")) {
                $currentObject["HasAssemblyInfo"] = $true
            }

            # not what we are expecting
            continue
        }

        $currentObject["$($myStrs[0])Line"] = $currentLine
        $currentObject["$($myStrs[0])"] = $myStrs[1]
    }
}

"Found $($csCustomObjects.Count) projects in the specified path." | Write-Host
$currentIndex = 1
$csCustomObjects | ForEach-Object {
    "$currentIndex- " | Write-Host -NoNewline
    if ($Short) {
        "$(Split-Path -Path $_["Path"] -Leaf): " | Write-Host -NoNewline -ForegroundColor Green
    }
    else {
        "$($_["Path"]): " | Write-Host -NoNewline -ForegroundColor Green
    }

    "$($_["TargetFrameworkVersion"])" | Write-Host -NoNewline -ForegroundColor DarkGreen
    " Product($($_["ProductVersion"]))" | Write-Host -NoNewline -ForegroundColor Cyan
    if ($_["AppDesignerFolder"]) {
        " InfoFolder($($_["AppDesignerFolder"]))" | Write-Host -NoNewline -ForegroundColor DarkMagenta
    } elseif ($_["HasAssemblyInfo"]) {
        " HasAssemblyInfo" | Write-Host -NoNewline -ForegroundColor DarkMagenta
    }
    " Output($($_["OutputType"]))" | Write-Host -NoNewline -ForegroundColor DarkRed
    
    "" | Write-Host
    $currentIndex++
}



