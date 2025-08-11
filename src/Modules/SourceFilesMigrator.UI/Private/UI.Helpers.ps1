# Classification & processing helpers for the UI

# Exclude rules
$script:SourceFilesMigratorExcludePatterns = @(
    '\bdev[\\/]', '\bpsd\b', '\bpsb\b', '\bvray\b', '\bbackup\b', '\btemp\b',
    'thumbs\.db$', '(^|[\\/])\._', '\.bak$', '\.blend.*$', '\.psd$', '\.mdmp$'
) -join '|'

function Filter-Path {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    return [Regex]::IsMatch($Path, $script:SourceFilesMigratorExcludePatterns, 'IgnoreCase')
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

