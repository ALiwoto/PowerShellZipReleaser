# PowerShellZipReleaser
# Copyright (C) 2022 ALiwoto
# This file is subject to the terms and conditions defined in
# file 'LICENSE', which is part of the source code.


Describe "Testing git-related cmdlets" {
    It "Should return a list of tags" {
        . ".\AdvancedUtils.ps1"
        $originalPWD = $PWD
        Set-Location "E:\abedini\projects\PowerShellZipReleaser\clones\guisharp1"
        $tagsList = Get-AllGitTags
        # this needs pester with higher version than current version installed on this system
        # and uhhh, well, nvm, will uncomment this later
        # ($null -eq $tagsList) -or ($tagsList.Length -eq 0) | Should -Be $false
        if (($null -eq $tagsList) -or ($tagsList.Length -eq 0)) {
            "tags list is null or empty" | Write-Error
        }

        Set-Location $originalPWD
    }
}

