@{
    RootModule        = 'SourceFilesMigrator.Core.psm1'
    ModuleVersion     = '0.1.0'
    Author            = 'Jacob Robbins'
    PowerShellVersion = '5.0'
    FunctionsToExport = @(
        'Test-Directory',
        'Resolve-PathSeparators',
        'Get-GameRootFromModelPath',
        'Get-CandidateGameRoots',
        'Get-StringPoolFromBinary',
        'Get-TextureInfoFromMdl',
        'Get-ModelRelativeSubPath',
        'Find-ExistingVmts',
        'Copy-PathsWithLayout',
        'Copy-ModelWithCompanions',
        'Get-GameRootFromMaterialsPath'
    )
    PrivateData = @{
        PSData = @{
            Tags       = @('Source','Valve','VPK','VTF','VMT','Models')
            ProjectUri = ''
        }
    }
}
