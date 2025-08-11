function Get-SfmExcludeRegex {
    <#
    .SYNOPSIS
        Returns the canonical regex string used to exclude files/paths.
    #>
    [CmdletBinding()] param()
    $script:SfmExcludePattern
}

function Test-SfmPathExclusion {
    <#
    .SYNOPSIS
        Tests a path against the shared exclusion regex.
    .PARAMETER Path
        Path to test (absolute or relative).
    .EXAMPLE
        Test-SfmPathExclusion -Path 'C:\foo\dev\bar\baz.vmt'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    return [Regex]::IsMatch($Path, (Get-SfmExcludeRegex), 'IgnoreCase')
}
