# Shared exclude regex (kept here to avoid UI dependency)
$script:SourceFilesMigratorExcludePatterns = @(
  '\bdev[\\/]', '\bpsd\b', '\bpsb\b', '\bvray\b', '\bbackup\b', '\btemp\b',
  'thumbs\.db$', '(^|[\\/])\._', '\.bak$', '\.blend.*$', '\.psd$', '\.mdmp$'
) -join '|'

function Filter-Path {
  param([Parameter(Mandatory)][string]$Path)
  return [Regex]::IsMatch($Path, $script:SourceFilesMigratorExcludePatterns, 'IgnoreCase')
}

function Get-FolderInventory {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$FolderPath)

    $models = New-Object System.Collections.Generic.List[string]
    $vmts   = New-Object System.Collections.Generic.List[string]
    $vtfs   = New-Object System.Collections.Generic.List[string]

    Get-ChildItem -LiteralPath $FolderPath -File -Recurse -Force -ErrorAction SilentlyContinue |
      Where-Object {
        -not (Filter-Path -Path $_.FullName) -and
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
