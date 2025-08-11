@{
    RootModule        = 'SourceFilesMigrator.Shared.psm1'
    ModuleVersion     = '0.1.0'
    Author            = 'Jacob Robbins'
    CompanyName       = 'SourceFilesMigrator'
    Copyright         = '(c) Jacob Robbins'
    PowerShellVersion = '5.1'

    FunctionsToExport = @(
        'Get-SfmExcludeRegex',
        'Test-SfmPathExclusion'
    )
    AliasesToExport   = @()
    CmdletsToExport   = @()
    VariablesToExport = @()
}
