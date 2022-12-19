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

class HashtableUtils {
    static [object]ConvertToHashtable([hashtable]$theHashtable = $null, $theObject) {
        if ($null -eq $theHashtable) {
            $theHashtable = [hashtable]::new()
        }

        if ($theObject -is [System.Management.Automation.PSCustomObject]) {
            $theObject.PSObject.Properties | ForEach-Object { $configHashtable[$_.Name] = [HashtableUtils]::ConvertToHashtable($_) }
        }
        elseif ($theObject -is [System.Management.Automation.PSNoteProperty]) {
            if ($theObject.Value -is [System.Object[]]) {

            }
        }
        else {
            "ok" | Write-Debug
        }

        return $theHashtable
    }

    static [object]ConvertFromArray($theObject) {

        return $null
    }

}
