function Invoke-VmtBatch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$VmtPaths,
        [Parameter(Mandatory)][string]$DestinationProjectRoot,
        [switch]$IncludeVtfs,
        [switch]$DryRun
    )

    if ($VmtPaths.Count -eq 0) { return $null }
    $primaryRoot = Get-GameRootFromMaterialsPath -MaterialFilePath $VmtPaths[0]
    $roots       = @($primaryRoot)

    $vmtCopy = Copy-PathsWithLayout -DestinationRoot $DestinationProjectRoot `
                                    -AbsolutePaths $VmtPaths `
                                    -GameRoots $roots `
                                    -LayoutRootName 'materials' `
                                    -DryRun:$DryRun

    $vtfCopy = $null
    if ($IncludeVtfs) {
        $logical = @(Get-TextureLogicalPathsFromVmtsDeep -VmtAbsolutePaths $VmtPaths -GameRoot $primaryRoot)
        if ($logical.Count -gt 0) {
            $vtfAbs = @(Resolve-LogicalTexturesToVtfFiles -GameRoots $roots -LogicalTexturePaths $logical)
            if ($vtfAbs.Count -gt 0) {
                $vtfCopy = Copy-VtfsToProject -DestinationProjectRoot $DestinationProjectRoot `
                                              -AbsoluteVtfPaths $vtfAbs -GameRoots $roots `
                                              -DryRun:$DryRun
            }
        }
    }

    [pscustomobject]@{
        VmtPaths = @($VmtPaths)
        VmtCopy  = $vmtCopy
        VtfCopy  = $vtfCopy
    }
}
