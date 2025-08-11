Set-StrictMode -Version Latest

# dot-source Private first
Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'Private') -Filter *.ps1 -ErrorAction SilentlyContinue |
  ForEach-Object { . $_.FullName }

# then Public
Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'Public') -Filter *.ps1 -ErrorAction SilentlyContinue |
  ForEach-Object { . $_.FullName }
