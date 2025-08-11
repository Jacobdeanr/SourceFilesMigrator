Set-StrictMode -Version Latest

# No more local regex. Use the shared predicate.
function Test-PathExclution {
    <#
    .SYNOPSIS
        Back-compat shim (note: original spelling error kept).
        Forwards to Test-SfmPathExclusion from SourceFilesMigrator.Shared.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    return (Test-SfmPathExclusion -Path $Path)
}

function Get-FolderInventory {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$FolderPath)

    $models = New-Object System.Collections.Generic.List[string]
    $vmts   = New-Object System.Collections.Generic.List[string]
    $vtfs   = New-Object System.Collections.Generic.List[string]

    Get-ChildItem -LiteralPath $FolderPath -File -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object {
            -not (Test-PathExclution -Path $_.FullName) -and
            -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint)
        } |
        ForEach-Object {
            $f = $_; $ext = $f.Extension.ToLowerInvariant()
            switch ($ext) {
                '.mdl' { $models.Add($f.FullName) | Out-Null }
                '.vmt' { $vmts.Add($f.FullName)   | Out-Null }
                '.vtf' { $vtfs.Add($f.FullName)   | Out-Null }
            }
        }

    [pscustomobject]@{
        Models = @($models)
        Vmts   = @($vmts)
        Vtfs   = @($vtfs)
    }
}
