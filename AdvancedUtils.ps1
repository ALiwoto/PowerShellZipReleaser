# PowerShellZipReleaser
# Copyright (C) 2022 ALiwoto
# This file is subject to the terms and conditions defined in
# file 'LICENSE', which is part of the source code.

# This function will convert a PSObject to a [hashtable] object.
# Mostly used for json parsing. In PowerShell 7.1+ ConvertFrom-Json itself
# has a switch parameter called `-AsHashtable`, but since we want our script to be able
# to run on PowerShell 5.1 as well, we can't use that, sadly.
# hence the existence of this function here.
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


# fetches and returns the current git branch that we are on.
# If the current directory are we are in at the moment, doesn't belong to
# any git repository (AKA: does not have .git dir and its content), this
# function will write the error using Write-Error cmdlet and returns $null.
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
        } elseif ($gitOutput -is [System.Management.Automation.ErrorRecord]) {
            $gitOutput | Write-Error
            return $null
        }

        return ($theBranch -as [string]).Substring(2, $theBranch.Length - 2)
    }
}

# This command fetches and returns the latest tag created in the current repository.
# It will use Write-Error cmdlet to report the errors if any.
# NOTICE: If there are no tags EVER created on this repository, this function will
# call Write-Error and returns $null.
function Get-LatestGitTag {
    [CmdletBinding()]
    param (
    )
    
    process {
        $gitOutput = (git describe --tags --abbrev=0 2>&1)
        if ($gitOutput -is [string]) {
            return $gitOutput.Trim()
        } elseif ($gitOutput -is [string[]]) {
            foreach ($currentOutput in $gitOutput) {
                $currentOutput = ($currentOutput -as [string]).Trim()
                if ($currentOutput.StartsWith("v")) {
                    return $currentOutput
                }
            }
        } elseif ($null -eq $gitOutput) {
            "Unexpected `$null result received from git command.`n" +
            "Are you sure you have git client installed on this machine?" | Write-Error
            return $null
        } elseif ($gitOutput -is [System.Management.Automation.ErrorRecord]) {
            $gitOutput | Write-Error
            return $null
        }

        "Unexpected result of type $($gitOutput.GetType().FullName) received from " +
        "git command." | Write-Error
        return $null
    }
}

function Get-AllGitTags {
    [CmdletBinding()]
    param (
    )
    
    process {
        $gitOutput = (git tag 2>&1)
        if ($gitOutput -is [string]) {
            # looks like we only have 1 output (and it's returned as a single string? most likely.)
            return ($gitOutput -as [string[]])
        }
        elseif ($gitOutput -is [object[]]) {
            # this is what we expect to happen normally, yup.
            # a list of tags, and the last index (-1), is always the
            # latest created tag.
            return $gitOutput
        }
        elseif ($gitOutput -is [System.Management.Automation.ErrorRecord]) {
            $gitOutput | Write-Error
            return $null
        }

        "Unexpected result of type $($gitOutput.GetType().FullName) received from " +
        "git command." | Write-Error
        return $null
    }
}

