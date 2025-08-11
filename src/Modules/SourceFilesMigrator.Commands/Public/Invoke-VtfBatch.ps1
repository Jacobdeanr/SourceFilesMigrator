function Invoke-VtfBatch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$VtfPaths,
        [Parameter(Mandatory)][string]$DestinationProjectRoot,
        [switch]$DryRun
    )

    if ($VtfPaths.Count -eq 0) { return $null }
    $primaryRoot = Get-GameRootFromMaterialsPath -MaterialFilePath $VtfPaths[0]
    $roots       = @($primaryRoot)

    Copy-PathsWithLayout -DestinationRoot $DestinationProjectRoot `
                         -AbsolutePaths $VtfPaths `
                         -GameRoots $roots `
                         -LayoutRootName 'materials' `
                         -DryRun:$DryRun
}
