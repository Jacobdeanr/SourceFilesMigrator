@{
    RootModule        = 'SourceFilesMigrator.VMT.psm1'
    ModuleVersion     = '0.1.0'
    Author            = 'Jacob Robbins'
    PowerShellVersion = '5.0'
    FunctionsToExport = @(
        'Remove-VmtComments',
        'Resolve-VmtPathLogical',
        'Resolve-VmtIncludeAbsolutePaths',
        'Get-TextureLogicalPathsFromSingleVmt',
        'Get-TextureLogicalPathsFromVmtsDeep',
        'Resolve-LogicalTexturesToVtfFiles',
        'Copy-VtfsToProject'
    )
}
