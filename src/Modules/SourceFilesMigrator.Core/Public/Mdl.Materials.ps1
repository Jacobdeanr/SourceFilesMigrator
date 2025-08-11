Set-StrictMode -Version Latest

function Get-TextureInfoFromMdl {
    <#
    .SYNOPSIS
      Extract cdmaterials directories and material basenames from a Source MDL file using header tables.
    .DESCRIPTION
      Reads studiohdr_t offsets:
        - numtextures / textureindex
        - numcdtextures / cdtextureindex
      Then resolves:
        - cdmaterials dirs from cdtexture string table
        - texture basenames from mstudiotexture_t entries via sznameindex
      Falls back to a conservative heuristic only if table parsing fails.
    .PARAMETER MdlFilePath
      Path to .mdl file.
    .OUTPUTS
      PSCustomObject with:
        - CdMaterialDirectories (string[])
        - MaterialBasenames    (string[])
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$MdlFilePath)

    if (-not (Test-Path -LiteralPath $MdlFilePath)) {
        throw "Model file not found: $MdlFilePath"
    }

    # -- helpers --------------------------------------------------------------
    [byte[]]$bytes = [System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $MdlFilePath))

    function Read-I32LE([int]$Offset) {
        if ($Offset -lt 0 -or $Offset + 4 -gt $bytes.Length) { throw "Read-I32LE OOB at $Offset" }
        [BitConverter]::ToInt32($bytes, $Offset)
    }

    function Read-CString([int]$Offset) {
        if ($Offset -lt 0 -or $Offset -ge $bytes.Length) { return $null }
        $sb = New-Object System.Text.StringBuilder
        for ($i = $Offset; $i -lt $bytes.Length; $i++) {
            $b = $bytes[$i]
            if ($b -eq 0) { break }
            # keep printable ASCII only
            if ($b -ge 32 -and $b -le 126) { [void]$sb.Append([char]$b) }
            else { break } # bail on non-printable to avoid garbage
        }
        $sb.ToString()
    }

    function Normalize-Dir([string]$s) {
        if ([string]::IsNullOrWhiteSpace($s)) { return $null }
        $n = ($s -replace '/', '\').Trim('"','''')
        $n = ($n -replace '[\\]+','\')
        if ($n.Length -eq 0) { return $null }
        if ($n[$n.Length-1] -ne '\') { $n += '\' }
        $n
    }

    # -- try header-driven parse ---------------------------------------------
    $cdDirs = @()
    $bases  = @()

    try {
        # Studio header magic
        $magic = [System.Text.Encoding]::ASCII.GetString($bytes, 0, [Math]::Min(4, $bytes.Length))
        if ($magic -notin @('IDST','IDST0')) { throw "Unsupported MDL magic '$magic'" }

        # Known offsets within studiohdr_t (Valve SDK layout)
        $numtextures    = Read-I32LE 204
        $textureindex   = Read-I32LE 208
        $numcdtextures  = Read-I32LE 212
        $cdtextureindex = Read-I32LE 216

        # Guard sanity
        if ($numtextures   -lt 0 -or $numtextures   -gt 4096) { throw "numtextures out of range: $numtextures" }
        if ($numcdtextures -lt 0 -or $numcdtextures -gt 4096) { throw "numcdtextures out of range: $numcdtextures" }
        if ($textureindex   -lt 0 -or $textureindex   -ge $bytes.Length) { throw "textureindex OOB: $textureindex" }
        if ($cdtextureindex -lt 0 -or $cdtextureindex -ge $bytes.Length) { throw "cdtextureindex OOB: $cdtextureindex" }

        # 1) cdmaterials directories
        $dirs = New-Object System.Collections.Generic.List[string]
        for ($i = 0; $i -lt $numcdtextures; $i++) {
            $off = Read-I32LE ($cdtextureindex + 4*$i)
            $str = Read-CString $off
            $norm = Normalize-Dir $str
            if ($norm) { $dirs.Add($norm) | Out-Null }
        }
        $cdDirs = @($dirs | Sort-Object -Unique)

        # 2) texture basenames from mstudiotexture_t table
        # We only need sznameindex at offset +0; entry size varies across versions.
        # Try common sizes: 64, 72, 80, 96 and pick the first that yields non-empty results.
        $entrySizes = 64,72,80,96
        $names = $null
        foreach ($esz in $entrySizes) {
            $tmp = New-Object System.Collections.Generic.List[string]
            $ok = $true
            for ($i = 0; $i -lt $numtextures; $i++) {
                $baseOff = $textureindex + ($i * $esz)
                if ($baseOff + 4 -gt $bytes.Length) { $ok = $false; break }
                $nameIndex = Read-I32LE $baseOff
                $nm = Read-CString ($baseOff + $nameIndex)
                if ([string]::IsNullOrWhiteSpace($nm)) { $ok = $false; break }
                # strip extension if somehow embedded
                $nm = ($nm -replace '\.(vmt|vtf)$','')
                $tmp.Add($nm) | Out-Null
            }
            if ($ok -and $tmp.Count -gt 0) { $names = $tmp; break }
        }

        if ($names) {
            # final sanitize & unique (keep original casing)
            $bases = @(
                $names |
                Where-Object { $_ -match '^[A-Za-z0-9_\-\.]{2,64}$' } |
                Sort-Object -Unique
            )
        } else {
            throw "Failed to read mstudiotexture_t names"
        }
    }
    catch {
        Write-Verbose "Header-driven parse failed: $($_.Exception.Message)"
        # conservative fallback: mine ASCII strings for reasonable tokens, avoid common noise
        $sb = New-Object System.Text.StringBuilder
        $tokens = New-Object System.Collections.Generic.List[string]
        foreach ($b in $bytes) {
            if ($b -ge 32 -and $b -le 126) { [void]$sb.Append([char]$b) }
            else {
                if ($sb.Length -ge 3) { $tokens.Add($sb.ToString()) | Out-Null }
                [void]$sb.Clear()
            }
        }
        if ($sb.Length -ge 3) { $tokens.Add($sb.ToString()) | Out-Null }

        $stop = @(
            'default','idle','@idle','body','static_prop','prop','player','male','female',
            'ragdoll','cloth','trigger','sequence','physics','gib','lod','lod1','lod2',
            'open','close','locked','unlock','wood','metal','glass','flesh','concrete',
            'idst','idst0','idst1','idag','idsq','studio','root'
        )
        $bases = @(
            $tokens |
            Where-Object { $_ -match '^[A-Za-z0-9_\-\.]{3,64}$' } |
            ForEach-Object { ($_ -replace '\.(vmt|vtf)$','') } |
            Where-Object { $stop -notcontains $_.ToLowerInvariant() } |
            Sort-Object -Unique
        )
        $cdDirs = @(
            $tokens |
            Where-Object { $_ -match '[\\/].*[\\/]$' } |
            ForEach-Object { Normalize-Dir $_ } |
            Where-Object { $_ } |
            Sort-Object -Unique
        )
    }

    [pscustomobject]@{
        CdMaterialDirectories = @($cdDirs)
        MaterialBasenames    = @($bases)
    }
}
