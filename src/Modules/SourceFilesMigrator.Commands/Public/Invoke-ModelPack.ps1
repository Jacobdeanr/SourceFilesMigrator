function Invoke-ModelPack {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Medium')]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ModelFilePath,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$DestinationProjectRoot,
        [switch]$IncludeVtfs,
        [switch]$DryRun
    )

    if (-not (Test-Path -LiteralPath $ModelFilePath)) { throw "Model file not found: $ModelFilePath" }
    Test-Directory -Path $DestinationProjectRoot | Out-Null

    $primaryGameRoot = Get-GameRootFromModelPath -ModelFilePath $ModelFilePath
    $gameRoots       = @(Get-CandidateGameRoots -ModelFilePath $ModelFilePath)

    # Parse MDL -> get cdmaterials + basenames
    $info = Get-TextureInfoFromMdl -MdlFilePath $ModelFilePath

    # Find VMTs across all roots
    $existingVmts = @(Find-ExistingVmts -GameRoots $gameRoots `
                                       -CdMaterialDirectories $info.CdMaterialDirectories `
                                       -MaterialBasenames $info.MaterialBasenames)

    # Copy model + companions
    $modelsDestRoot = Join-Path $DestinationProjectRoot "models"
    $modelCopy = Copy-ModelWithCompanions -ModelFilePath $ModelFilePath `
                                          -DestinationModelsRoot $modelsDestRoot `
                                          -DryRun:$DryRun

    # Copy VMTs
    $vmtCopy = $null
    if ($existingVmts.Count -gt 0) {
        $vmtCopy = Copy-PathsWithLayout -DestinationRoot $DestinationProjectRoot `
                                        -AbsolutePaths $existingVmts `
                                        -GameRoots $gameRoots `
                                        -LayoutRootName 'materials' `
                                        -DryRun:$DryRun
    }

    # Parse VMTs -> textures and copy VTFs
    $vtfLogical  = @()
    $vtfAbsolute = @()
    $vtfCopy     = $null

    if ($IncludeVtfs -and $existingVmts.Count -gt 0) {
        $vtfLogical  = @(Get-TextureLogicalPathsFromVmtsDeep -VmtAbsolutePaths $existingVmts -GameRoot $primaryGameRoot)

        if ($vtfLogical.Count -gt 0) {
            $vtfAbsolute = @(Resolve-LogicalTexturesToVtfFiles -GameRoots $gameRoots -LogicalTexturePaths $vtfLogical)
            if ($vtfAbsolute.Count -gt 0) {
                $vtfCopy = Copy-VtfsToProject -DestinationProjectRoot $DestinationProjectRoot `
                                              -AbsoluteVtfPaths $vtfAbsolute `
                                              -GameRoots $gameRoots `
                                              -DryRun:$DryRun
            }
        }
    }

    [pscustomobject]@{
        GameRoot                 = $primaryGameRoot
        CandidateGameRoots       = $gameRoots
        CdMaterials              = $info.CdMaterialDirectories
        MaterialBasenames        = $info.MaterialBasenames
        ModelCopy                = $modelCopy
        VmtPathsFound            = $existingVmts
        VmtCopy                  = $vmtCopy
        VtfLogicalPaths          = $vtfLogical
        VtfAbsolutePaths         = $vtfAbsolute
        VtfCopy                  = $vtfCopy
        DryRun                   = [bool]$DryRun
    }
}
