# Internal helpers (not exported)

function Add-LongPathPrefix {
    param([Parameter(Mandatory)][string]$Path)

    $onWindows = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform(
        [System.Runtime.InteropServices.OSPlatform]::Windows
    )

    if ($onWindows -and -not ($Path -like '\\?\*') -and ($Path.Length -gt 240)) {
        return "\\?\$Path"
    }
    return $Path
}

function Invoke-SafeCopy {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination,
        [switch]$DryRun
    )

    $src = Add-LongPathPrefix -Path $Source
    $dst = Add-LongPathPrefix -Path $Destination

    if ($DryRun) {
        Write-Verbose "DRYRUN: would copy '$Source' -> '$Destination'"
        return $false
    }

    if ($PSCmdlet.ShouldProcess($Destination, "Copy from '$Source'")) {
        # Directory ensured by public Test-Directory
        Test-Directory -Path (Split-Path -Path $dst -Parent) | Out-Null
        Copy-Item -LiteralPath $src -Destination $dst -Force
        return $true
    }
    return $false
}
