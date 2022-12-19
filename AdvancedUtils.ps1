# PowerShell-AdvancedUtils Project
# Copyright (C) 2022 ALiwoto
# This file is subject to the terms and conditions defined in
# file 'LICENSE', which is part of the source code.

function ConvertFrom-PSObject {
    param (
        [Parameter(ValueFromPipeline)]
        $InputObject
    )

    process {
        if ($null -eq $InputObject) {
            return $null
        }

        if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
            $collection = @(
                foreach ($object in $InputObject.GetEnumerator()) { ConvertFrom-PSObject $object }
            )

            Write-Output -NoEnumerate $collection
        }
        elseif ($InputObject -is [PSObject]) {
            $hash = @{}

            foreach ($property in $InputObject.PSObject.Properties) {
                $hash[$property.Name] = ConvertFrom-PSObject $property.Value
            }

            return $hash
        }
        else {
            return $InputObject
        }
    }
}

function Get-CurrentGitBranch {
    [CmdletBinding()]
    param (
    )
    
    process {
        $theBranch = (git branch 2>&1) -split "\n" | Where-Object {$_.StartsWith("*") }
        if ($null -eq $theBranch) {
            # putting this just in case of exceptional situations (like not being in a dir with .git dir, etc).
            # we might want to change the behaviour of it in future.
            return $null
        }

        return ($theBranch -as [string]).Substring(1, $theBranch.Length - 2)
    }
}

