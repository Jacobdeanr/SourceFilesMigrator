Set-StrictMode -Version Latest

# Classification & processing helpers for the UI

# No local pattern; call into shared module
function Test-PathExclution {
    <#
    .SYNOPSIS
        Back-compat shim for the UI module. Forwards to the shared predicate.
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

    Write-Verbose "[Folder] scanning: $FolderPath"

    Get-ChildItem -LiteralPath $FolderPath -File -Recurse -Force -ErrorAction SilentlyContinue |
      Where-Object {
        -not (Test-PathExclution -Path $_.FullName) -and
        -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint)
      } |
      ForEach-Object {
        $file = $_; $ext = $file.Extension.ToLowerInvariant()
        switch ($ext) {
            '.mdl' { $models.Add($file.FullName) | Out-Null }
            '.vmt' { $vmts.Add($file.FullName)   | Out-Null }
            '.vtf' { $vtfs.Add($file.FullName)   | Out-Null }
        }
      }

    [pscustomobject]@{
        Models = @($models)
        Vmts   = @($vmts)
        Vtfs   = @($vtfs)
    }
}


function Get-DroppedItemKind {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (Test-Path -LiteralPath $Path -PathType Container) { return 'Folder' }
    $ext = [IO.Path]::GetExtension($Path).ToLowerInvariant()
    switch ($ext) {
        '.mdl' { 'Model' }
        '.vmt' { 'Vmt' }
        '.vtf' { 'Vtf' }
        #'.bsp' { 'Map' }
        default { 'File' }
    }
}

