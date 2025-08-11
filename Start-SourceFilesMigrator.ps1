<#
.SYNOPSIS
  One-click starter for SourceFilesMigrator (Windows PowerShell 5.x only). Imports all modules and launches the WPF UI.

.EXAMPLE
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Start-SourceFilesMigrator.ps1 -Destination ".\package"
#>

[CmdletBinding()]
param(
  [string]$Destination = (Join-Path (Get-Location) "package"),
  [switch]$VerboseImport
)

Set-StrictMode -Version Latest

function Get-PowerShellExePath {
  # Always prefer this process' engine, fallback to system path.
  $exe = Join-Path $PSHOME 'powershell.exe'
  if (Test-Path -LiteralPath $exe) { return $exe }
  return "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
}

# 1) Ensure STA for WPF (relaunch self if needed)
if ([System.Threading.Thread]::CurrentThread.ApartmentState -ne [System.Threading.ApartmentState]::STA) {
  $exe = Get-PowerShellExePath
  $argsList = @(
    '-NoLogo','-NoProfile','-STA','-ExecutionPolicy','Bypass',
    '-File', ('"{0}"' -f $MyInvocation.MyCommand.Path)
  )
  if ($PSBoundParameters.ContainsKey('Destination')) { $argsList += @('-Destination', ('"{0}"' -f $Destination)) }
  if ($VerboseImport) { $argsList += '-VerboseImport' }
  Write-Host "Re-launching under -STA with: $exe $($argsList -join ' ')" -ForegroundColor Yellow
  & $exe @argsList
  exit $LASTEXITCODE
}

# 2) Import modules (relative to repo root)
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$mods = @(
  (Join-Path $root 'src/Modules/SourceFilesMigrator.Shared/SourceFilesMigrator.Shared.psd1'),
  (Join-Path $root 'src/Modules/SourceFilesMigrator.Core/SourceFilesMigrator.Core.psd1'),
  (Join-Path $root 'src/Modules/SourceFilesMigrator.VMT/SourceFilesMigrator.VMT.psd1'),
  (Join-Path $root 'src/Modules/SourceFilesMigrator.Commands/SourceFilesMigrator.Commands.psd1'),
  (Join-Path $root 'src/Modules/SourceFilesMigrator.UI/SourceFilesMigrator.UI.psd1')
)

foreach ($m in $mods) {
  if (-not (Test-Path -LiteralPath $m)) { Write-Error "Module not found: $m"; exit 1 }
  try {
    Import-Module $m -Force -ErrorAction Stop -Verbose:$VerboseImport
  } catch {
    Write-Error "Failed to import $m : $($_.Exception.Message)"
    exit 1
  }
}

# 3) Verify UI export; dot-source fallback if needed
$hasCmd = Get-Command -Name 'Start-SourceFilesMigratorUI' -ErrorAction SilentlyContinue

if (-not $hasCmd) {
  Write-Warning "Start-SourceFilesMigratorUI not exported; attempting dot-source fallback."
  $uiModule = Get-Module -Name 'SourceFilesMigrator.UI' -ErrorAction SilentlyContinue
  if (-not $uiModule) {
    $uiModule = Get-Module | Where-Object { $_.Path -like '*SourceFilesMigrator.UI.psd1' -or $_.Path -like '*SourceFilesMigrator.UI.psm1' } | Select-Object -First 1
  }
  if ($uiModule -and (Test-Path $uiModule.Path)) {
    $uiRoot  = Split-Path -Parent $uiModule.Path
    $uiEntry = Join-Path $uiRoot 'Public\Start-SourceFilesMigratorUI.ps1'
    if (Test-Path -LiteralPath $uiEntry) { . $uiEntry } else {
      Write-Error "Could not find $uiEntry to dot-source."; exit 1
    }
  } else {
    Write-Error "UI module not loaded and no path available."; exit 1
  }
}

# 4) Launch UI
Write-Host "Launching SourceFilesMigrator UI (Destination: $Destination)..." -ForegroundColor Cyan
Start-SourceFilesMigratorUI -InitialDestination $Destination
