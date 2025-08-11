# --- VMT comment/kv helpers ---
function Remove-VmtComments {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Text)
    $noBlock = [Regex]::Replace($Text, '/\*.*?\*/', '', 'Singleline')
    [Regex]::Replace($noBlock, '^\s*//.*$', '', 'Multiline')
}

function Resolve-VmtPathLogical {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Value,
        [switch]$IsTexture
    )
    $v = $Value.Trim().Trim('"','''') -replace '/', '\'
    if ($v.ToLowerInvariant().StartsWith('materials\')) { $v = $v.Substring(10) }
    if ($IsTexture -and $v.ToLowerInvariant().EndsWith('.vtf')) { $v = $v.Substring(0, $v.Length - 4) }
    $v
}

function Resolve-VmtIncludeAbsolutePaths {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$CurrentVmtAbsolutePath,
        [Parameter(Mandatory)][string]$GameRoot
    )

    # include logic: try materials\includePath, then sibling dir, finally a filename search
    $materialsRoot = Join-Path $GameRoot 'materials'

    try { $content = Get-Content -LiteralPath $CurrentVmtAbsolutePath -Raw -Encoding UTF8 }
    catch { $content = Get-Content -LiteralPath $CurrentVmtAbsolutePath -Raw -Encoding Default }

    $content = Remove-VmtComments -Text $content
    $incLine = ($content -split "`n") | Where-Object { $_ -match '^\s*#include\s+"([^"]+)"' } | Select-Object -First 1
    if (-not $incLine) { return @() }
    $m = [regex]::Match($incLine, '^\s*#include\s+"([^"]+)"')
    if (-not $m.Success) { return @() }
    $incLogical = Resolve-VmtPathLogical -Value $m.Groups[1].Value

    if (-not $incLogical) { return @() }

    $cand1 = Join-Path $materialsRoot ($incLogical + ".vmt")
    if (Test-Path -LiteralPath $cand1) { return ,((Resolve-Path $cand1).Path) }

    $curDir = Split-Path $CurrentVmtAbsolutePath -Parent
    $cand2 = Join-Path $curDir ($incLogical + ".vmt")
    if (Test-Path -LiteralPath $cand2) { return ,((Resolve-Path $cand2).Path) }

    $leaf = [IO.Path]::GetFileName($incLogical + ".vmt")
    $hits = Get-ChildItem -LiteralPath $materialsRoot -Filter $leaf -Recurse -ErrorAction SilentlyContinue
    return @($hits | ForEach-Object { $_.FullName })
}

# --- Parse a single VMT to logical texture paths + includes ---
function Get-TextureLogicalPathsFromSingleVmt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$VmtAbsolutePath,
        [Parameter(Mandatory)][string]$GameRoot
    )

    if (-not (Test-Path -LiteralPath $VmtAbsolutePath)) {
        return [pscustomobject]@{ LogicalTexturePaths=@(); IncludeVmtPaths=@() }
    }

    try {
        try { $content = Get-Content -LiteralPath $VmtAbsolutePath -Raw -Encoding UTF8 }
        catch { $content = Get-Content -LiteralPath $VmtAbsolutePath -Raw -Encoding Default }
        $content = Remove-VmtComments -Text $content
    } catch {
        Write-Verbose "Failed to read VMT '$VmtAbsolutePath': $_"
        return [pscustomobject]@{ LogicalTexturePaths=@(); IncludeVmtPaths=@() }
    }

    #  ^\s*                # Optional leading spaces/tabs
    #  "?                  # Optional opening quote before the key
    #  \$?                 # Optional $ at the start of the key
    #  ([A-Za-z0-9_]+)     # Group 1: key name (letters, digits, underscore)
    #  "?                  # Optional closing quote after the key
    #  \s+                 # At least one space/tab before the value
    #  "                   # Opening quote for the value
    #  ([^"]+)             # Group 2: value (anything except a double-quote)
    #  "                   # Closing quote for the value

    $kv = @{}
    foreach ($line in $content -split "`n") {
        if ($line -match '^\s*"?\$?([A-Za-z0-9_]+)"?\s+"([^"]+)"') {
            $kv[$matches[1].ToLowerInvariant()] = $matches[2]
        }
    }

    # Recognized texture keys
    $textureKeys = @(
        'basetexture','basetexture2','basetexture3','basetexture4',
        'bumpmap','bumpmap2','normalmap','bumpmask','dudvmap',
        
        # Pretty sure this was deprecated, but including anyways
        'parallaxmap',
        
        # Envmap
        'envmapmask','envmapmask2',

        # Only used on Lightmapped_4WayBlend?
        # https://developer.valvesoftware.com/wiki/Lightmapped_4WayBlend
        'basenormalmap2','basenormalmap3','basenormalmap4',
        
        # Phong
        'phongexponenttexture','phongwarptexture','lightwarptexture',
        
        # Detail
        'detail','detail2','basenormalmap','selfillumtexture','decaltexture',

        # EyeRefract
        # https://developer.valvesoftware.com/wiki/EyeRefract
        'iris','corneatexture','ambientoccltexture',

        # https://developer.valvesoftware.com/wiki/$blendmodulatetexture
        'blendmodulatetexture',

        # Sky
        # https://developer.valvesoftware.com/wiki/Sky_(Source_1_shader)
        'hdrbasetexture','hdrcompressedtexture',

        # EP 1 Citadel core
        # https://developer.valvesoftware.com/wiki/Core_(shader)
        'corecolortexture',

        # Source 2013 MP + Gmod
        # https://developer.valvesoftware.com/wiki/$lightmap
        'lightmap',
        
        # wrinkle maps
        'compress','stretch',
        
        # Flowmaps in water and VortWarp
        # https://developer.valvesoftware.com/wiki/Water_(shader)
        # https://developer.valvesoftware.com/wiki/VortWarp
        'flowmap','flow_noise_texture',
        
        # Portal 2
        'paintsplatnormalmap','paintsplatbubblelayout','paintsplatbubble','paintenvmap',
        
        # strata
        'flashlighttexture','mraotexture','mraotexture2','emissiontexture','emissiontexture2',
        
        # Black Mesa
        'specmap_texture','moss_texture',

        # Stock VertexLitGeneric:
        'SelfIllumMask',

        # Stock EmissiveBlend
        'EmissiveBlendBaseTexture', 'EmissiveBlendFlowTexture', 'EmissiveBlendTexture'

        # Stock Flesh Interior Pass
        'FleshInteriorTexture', 'FleshInteriorNoiseTexture', 'FleshBorderTexture1D', 'FleshNormalTexture', 'FleshSubSurfaceTexture', 'FleshCubeTexture',

        # Stock Cloud Shader
        'CloudAlphaTexture',

        # Stock ParallaxTest ( ASW+ )
        'HeightMap',

        # Couple of Shaders like Stock UnlitTwoTexture 
        'Texture2',

        # Stock ScreenSpace_General ( also has Texture2 )
        'Texture3',

        # Stock Refract Shader
        'RefractTintTexture',

        # Stock Wrinkle Mapping has these two as well
        'BumpCompress', 'BumpStretch',

        # Usually set to Rendertargets, but I have seen users before that specified
        # regular Textures to fake certain Effects like Parallax offsets 
        'RefractTexture', 'ReflectTexture',

        # More Sky Textures, although they may be unusable atm on Stock Shaders
        'HDRCompressedTexture0', 'HDRCompressedTexture1', 'HDRCompressedTexture2',

        # SpriteCard Shader
        'RampTexture',

        # L4D2 Infected Shader
        'WoundCutOutTexture', 'GradientTexture', 'BurnDetailTexture'

        # LUX WorldVertexTransition
        'PhongExponentTexture2', 'SelfIllumMask2', 

        # LUX Expensive Water
        'Surface_BumpMap',

        # LUX UnlitTwoTexture / LUX_UnlitCombineTextures
        'Texture4', 'Texture5', 'Texture6', 'Texture7', 'Texture8', 'Texture9', 'Texture10', 'Texture11', 'Texture12', 'Texture13', 

        # LUX Sky_HDRI
        'SkyTextureX1Y1', 'SkyTextureX2Y1', 'SkyTextureX3Y1', 'SkyTextureX4Y1',
        'SkyTextureX1Y2', 'SkyTextureX2Y2', 'SkyTextureX3Y2', 'SkyTextureX4Y2',

        # LUX  ( not necessarily a Strata thing )
        'NormalTexture'
    )

    $logical = New-Object System.Collections.Generic.HashSet[string]
    foreach ($k in $textureKeys) {
        if ($kv.ContainsKey($k)) {
            $v = Resolve-VmtPathLogical -Value $kv[$k] -IsTexture
            if ($v) { $null = $logical.Add($v.ToLowerInvariant()) }
        }
    }

    $includes = @(Resolve-VmtIncludeAbsolutePaths -CurrentVmtAbsolutePath $VmtAbsolutePath -GameRoot $GameRoot)

    [pscustomobject]@{
        LogicalTexturePaths = @($logical | Sort-Object)
        IncludeVmtPaths     = $includes
    }
}

function Get-TextureLogicalPathsFromVmtsDeep {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$VmtAbsolutePaths,
        [Parameter(Mandatory)][string]$GameRoot
    )

    $queue   = [System.Collections.Generic.Queue[string]]::new()
    $visited = [System.Collections.Generic.HashSet[string]]::new()
    $all     = [System.Collections.Generic.HashSet[string]]::new()

    foreach ($p in $VmtAbsolutePaths) { if ($p) { $queue.Enqueue($p) } }

    while ($queue.Count -gt 0) {
        $cur = $queue.Dequeue()
        if (-not $visited.Add($cur.ToLowerInvariant())) { continue }

        $res = Get-TextureLogicalPathsFromSingleVmt -VmtAbsolutePath $cur -GameRoot $GameRoot
        foreach ($l in $res.LogicalTexturePaths) { if ($l) { $null = $all.Add($l.ToLowerInvariant()) } }
        foreach ($inc in $res.IncludeVmtPaths)   { if ($inc -and -not $visited.Contains($inc.ToLowerInvariant())) { $queue.Enqueue($inc) } }
    }

    return @($all | Sort-Object)
}

# --- Map logical paths to .vtf across multiple roots and copy ---
function Resolve-LogicalTexturesToVtfFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$GameRoots,
        [Parameter(Mandatory)][string[]]$LogicalTexturePaths
    )
    $LogicalTexturePaths = @($LogicalTexturePaths)
    if ($LogicalTexturePaths.Count -eq 0) { return @() }

    $results = New-Object System.Collections.Generic.List[string]
    foreach ($logical in $LogicalTexturePaths) {
        if ([string]::IsNullOrWhiteSpace($logical)) { continue }

        $foundOne = $false
        foreach ($root in $GameRoots) {
            $materialsRoot = Join-Path $root "materials"
            $candidate = (Join-Path $materialsRoot ($logical + '.vtf')) -replace '\\+','\'
            if (Test-Path -LiteralPath $candidate) {
                $results.Add((Resolve-Path -LiteralPath $candidate).Path) | Out-Null
                $foundOne = $true; break
            }
        }
        if (-not $foundOne) {
            Write-Verbose "VTF not found for logical '$logical' across roots."
        }
    }
    @($results | Sort-Object -Unique)
}

function Copy-VtfsToProject {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$DestinationProjectRoot,
        [Parameter(Mandatory)][string[]]$AbsoluteVtfPaths,
        [Parameter(Mandatory)][string[]]$GameRoots,
        [switch]$DryRun
    )

    # Reuse Core generalized layout copier
    Copy-PathsWithLayout -DestinationRoot $DestinationProjectRoot `
                         -AbsolutePaths $AbsoluteVtfPaths `
                         -GameRoots $GameRoots `
                         -LayoutRootName 'materials' `
                         -DryRun:$DryRun
}
