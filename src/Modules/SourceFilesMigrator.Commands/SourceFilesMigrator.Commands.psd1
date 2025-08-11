@{
    RootModule        = 'SourceFilesMigrator.Commands.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '2b2d6b9a-21a8-4f27-86b0-1f5b7b0f5e44'
    Author            = 'Jacob Robbins'
    PowerShellVersion = '5.0'
    FunctionsToExport = @('Invoke-ModelPack',
        'Invoke-VmtBatch',
        'Invoke-VtfBatch',
        'Invoke-SourceFilesMigratorEntries')
    RequiredModules   = @('SourceFilesMigrator.Core','SourceFilesMigrator.VMT')
}
