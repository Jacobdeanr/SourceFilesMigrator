@{
    RootModule        = 'SourceFilesMigrator.UI.psm1'
    ModuleVersion     = '0.1.0'
    Author            = 'Jacob Robbins'
    PowerShellVersion = '5.0'
    RequiredModules   = @('SourceFilesMigrator.Shared','SourceFilesMigrator.Core','SourceFilesMigrator.VMT','SourceFilesMigrator.Commands')
    FunctionsToExport = @('Start-SourceFilesMigratorUI')
}
