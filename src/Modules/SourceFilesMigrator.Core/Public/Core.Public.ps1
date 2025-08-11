# --- Public: Directory creation (exported) ---
function Test-Directory {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    $p = Add-LongPathPrefix -Path $Path
    if (-not (Test-Path -LiteralPath $p)) {
        New-Item -ItemType Directory -Path $p -Force | Out-Null
    }
    return $Path
}

# --- materials path -> game root ---
function Get-GameRootFromMaterialsPath {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$MaterialFilePath)

    $normalized = (Resolve-PathSeparators $MaterialFilePath)
    $idx = $normalized.ToLowerInvariant().LastIndexOf('\materials\')
    if ($idx -lt 0) { throw "Cannot infer game root: path does not contain '\materials\': $MaterialFilePath" }
    return $normalized.Substring(0, $idx + 1)
}

# --- Paths ---
function Resolve-PathSeparators {
    [CmdletBinding()]
    param([string]$Path)
    if (-not $Path) { return $Path }
    return ($Path -replace '[\\/]+', '\')
}

# --- Game roots ---
function Get-GameRootFromModelPath {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ModelFilePath)

    $normalized = (Resolve-PathSeparators $ModelFilePath)
    $idx = $normalized.ToLowerInvariant().LastIndexOf('\models\')
    if ($idx -lt 0) { throw "Cannot infer game root: path does not contain '\models\': $ModelFilePath" }
    return $normalized.Substring(0, $idx + 1)
}

function Get-CandidateGameRoots {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ModelFilePath)

    $primary = Get-GameRootFromModelPath -ModelFilePath $ModelFilePath
    $roots   = [System.Collections.Generic.List[string]]::new()
    $roots.Add(($primary.TrimEnd('\') + '\'))

    # If ...\hl2\custom\<mod>\, add base ...\hl2\
    $m = [regex]::Match($primary, '(?i)^(.*?\\hl2\\)custom\\[^\\]+\\$')
    if ($m.Success) { $roots.Add($m.Groups[1].Value) }

    $roots | Sort-Object -Unique
}

# --- MDL parsing (string pool heuristic) ---
function Get-StringPoolFromBinary {
    [CmdletBinding()]
    param([Parameter(Mandatory)][byte[]]$BinaryBytes)

    $text = [System.Text.Encoding]::GetEncoding("ISO-8859-1").GetString($BinaryBytes)
    $text -split "\x00+" | Where-Object { $_.Length -ge 2 }
}

# --- Models pathing ---
function Get-ModelRelativeSubPath {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ModelFilePath)

    $normalized = (Resolve-PathSeparators $ModelFilePath)
    $lower      = $normalized.ToLowerInvariant()
    $modelsIdx  = $lower.LastIndexOf('\models\')
    if ($modelsIdx -lt 0) { throw "File not under \models\: $ModelFilePath" }
    return $normalized.Substring($modelsIdx + 1) # includes "models\..."
}

# --- Find VMTs for (cdmaterials x basenames) across roots ---
function Find-ExistingVmts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$GameRoots,
        [Parameter(Mandatory)][string[]]$CdMaterialDirectories,
        [Parameter(Mandatory)][string[]]$MaterialBasenames
    )

    $results = [System.Collections.Generic.HashSet[string]]::new()

    foreach ($root in $GameRoots) {
        $materialsRoot = Join-Path $root 'materials'
        foreach ($cd in $CdMaterialDirectories) {
            foreach ($base in $MaterialBasenames) {
                $candidate = (Join-Path $materialsRoot (Join-Path $cd ($base + '.vmt'))) -replace '\\+','\'
                if (Test-Path -LiteralPath $candidate) {
                    $null = $results.Add((Resolve-Path -LiteralPath $candidate).Path)
                }
            }
        }
    }

    @($results | Sort-Object)
}

# --- Generalized copy: place files under a layout (e.g., materials\..., models\...) ---
function Copy-PathsWithLayout {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$DestinationRoot,
        [Parameter(Mandatory)][string[]]$AbsolutePaths,
        [Parameter(Mandatory)][string[]]$GameRoots,
        [Parameter(Mandatory)][ValidateSet('materials','models')][string]$LayoutRootName,
        [switch]$DryRun
    )

    $destRoot = Join-Path $DestinationRoot $LayoutRootName
    $copied   = [System.Collections.Generic.List[string]]::new()

    foreach ($abs in @($AbsolutePaths)) {
        if ([string]::IsNullOrWhiteSpace($abs)) { continue }
        $norm = (Resolve-PathSeparators $abs)

        $matchedRoot = $null
        foreach ($root in $GameRoots) {
            $needle = (Join-Path $root $LayoutRootName) -replace '/', '\'
            if ($norm.ToLowerInvariant().StartsWith($needle.ToLowerInvariant())) {
                $matchedRoot = $needle; break
            }
        }
        if (-not $matchedRoot) { continue }

        $rel  = $norm.Substring($matchedRoot.Length).TrimStart('\')
        $dest = Join-Path $destRoot $rel

        if (Invoke-SafeCopy -Source $abs -Destination $dest -DryRun:$DryRun) {
            $copied.Add($dest) | Out-Null
        } else {
            if ($DryRun) { $copied.Add($dest) | Out-Null } # "would" copy
        }
    }

    [pscustomobject]@{
        DestinationRoot = $destRoot
        FilesPlanned    = @($AbsolutePaths)
        FilesCopied     = @($copied)
        DryRun          = [bool]$DryRun
    }
}

# --- Copy model + companions (.mdl, .vvd, .dx90.vtx, .phy, .ani, etc.) ---
function Copy-ModelWithCompanions {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$ModelFilePath,
        [Parameter(Mandatory)][string]$DestinationModelsRoot,
        [switch]$DryRun
    )

    $norm = (Resolve-PathSeparators $ModelFilePath)
    if (-not (Test-Path -LiteralPath $norm)) { throw "Model file not found: $ModelFilePath" }

    # Use -Path to avoid older Split-Path ambiguity on some shells
    $dir      = Split-Path -Path $norm -Parent
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($norm)

    # companion patterns
    $patterns = @(
        "$baseName.mdl", "$baseName.vvd", "$baseName.phy", "$baseName.ani",
        "$baseName.vtx", "$baseName.dx80.vtx", "$baseName.dx90.vtx", "$baseName.sw.vtx"
    )

    $files = Get-ChildItem -LiteralPath $dir -File -ErrorAction SilentlyContinue |
             Where-Object { $patterns -contains $_.Name }

    $copied = [System.Collections.Generic.List[string]]::new()
    foreach ($f in $files) {
        $relWithinModels = ($f.FullName -split '(?i)\\models\\',2)[1]
        if (-not $relWithinModels) { continue }
        $dest = Join-Path $DestinationModelsRoot $relWithinModels

        if (Invoke-SafeCopy -Source $f.FullName -Destination $dest -DryRun:$DryRun) {
            $copied.Add($dest) | Out-Null
        } else {
            if ($DryRun) { $copied.Add($dest) | Out-Null }
        }
    }

    [pscustomobject]@{
        DestinationDirectory = $DestinationModelsRoot
        FilesCopied          = @($copied)
        DryRun               = [bool]$DryRun
    }
}
