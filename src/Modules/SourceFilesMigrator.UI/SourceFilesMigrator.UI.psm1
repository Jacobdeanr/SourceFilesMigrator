Set-StrictMode -Version Latest

Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'Private') -Filter *.ps1 -ErrorAction SilentlyContinue |
  ForEach-Object { . $_.FullName }
Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'Public') -Filter *.ps1 -ErrorAction SilentlyContinue |
  ForEach-Object { . $_.FullName }
