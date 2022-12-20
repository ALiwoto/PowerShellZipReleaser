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

# Uses the famous git clone command to clone a repository from the given
# upstream url. This function will also return the whole output given by
# git clone command. 
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
        # previously, logic for this function was to invoke "git describe --tags --abbrev=0"
        # command; but later on, we found out that this command will have a common bug:
        # v1.1.09 will be considered as the latest tag while v1.1.10 exists in the list of
        # all tags.
        # So what we did, was to just replace it with this simple solution.
        # but since this solution is kinda expensive (receiving a list of ALL tags and then returning
        # the last index of them EACH TIME), it's adviced not to use this function anymore,
        # instead it's better for caller to call Get-AllGitTags cmdlet directly and cache
        # all of the tags in the memory, and then use the latest index of that array to get the
        # latest tag of the repository. (but if this operation is one-time, and it doesn't need repeating
        # at all, then using this cmdlet is ideal, since it reduces code).
        return (Get-AllGitTags)[-1]
    }
}

# This function fetches and returns a list of all of git tags created in this
# repository. It will report the error by calling Write-Error cmdlet.
# Please do notice that if the current git repository (in the current directory)
# doesn't have any tags, this function will report an error and return $null.
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

