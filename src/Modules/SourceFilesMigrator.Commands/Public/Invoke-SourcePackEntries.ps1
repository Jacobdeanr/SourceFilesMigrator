function Invoke-SourceFilesMigratorEntries {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [object[]]$Entries, # expects .Kind (Model|Vmt|Vtf|Folder) and .Path

        [Parameter(Mandatory)][string]$DestinationProjectRoot,
        [switch]$IncludeVtfs,
        [switch]$DryRun
    )

    $cmp = [System.StringComparer]::OrdinalIgnoreCase
    $seenModels = New-Object 'System.Collections.Generic.HashSet[string]' ($cmp)
    $seenVMTs   = New-Object 'System.Collections.Generic.HashSet[string]' ($cmp)
    $seenVTFs   = New-Object 'System.Collections.Generic.HashSet[string]' ($cmp)
    $copiedVMTs = New-Object 'System.Collections.Generic.HashSet[string]' ($cmp)
    $copiedVTFs = New-Object 'System.Collections.Generic.HashSet[string]' ($cmp)

    function Normalize([string]$p) {
        if ([string]::IsNullOrWhiteSpace($p)) { return $null }
        try { (Resolve-Path -LiteralPath $p -ErrorAction Stop).Path } catch { ($p -replace '[\\/]+','\') }
    }
    function Add-Once($set, [string]$p) {
        $n = Normalize $p
        if (-not $n) { return $false }
        return $set.Add($n)
    }
    function Accumulate-Copied($copyObj, [string]$kind) {
        if (-not $copyObj) { return 0 }
        $added = 0
        $paths = @($copyObj.FilesCopied) # actual copies (empty in -DryRun)
        foreach ($p in $paths) {
            switch ($kind) {
                'vmt' { if (Add-Once $copiedVMTs $p) { $added++ } }
                'vtf' { if (Add-Once $copiedVTFs $p) { $added++ } }
            }
        }
        return $added
    }

    $summary = [pscustomobject]@{
        UniqueModelsProcessed = 0
        UniqueVMTsPlanned     = 0
        UniqueVTFsPlanned     = 0
        ModelFilesCopied      = 0
        VmtFilesCopied        = 0
        VtfFilesCopied        = 0
    }

    $details = [ordered]@{
        Models = New-Object System.Collections.Generic.List[object]
        VMTs   = New-Object System.Collections.Generic.List[string]
        VTFs   = New-Object System.Collections.Generic.List[string]
    }

    foreach ($e in $Entries) {
        $kind = "$($e.Kind)".Trim()
        $path = Normalize $e.Path
        if (-not $path) { continue }

        switch -Regex ($kind) {
            '^Model$' {
                if (-not (Add-Once $seenModels $path)) { continue }
                $res = Invoke-ModelPack -ModelFilePath $path -DestinationProjectRoot $DestinationProjectRoot `
                                        -IncludeVtfs:$IncludeVtfs -DryRun:$DryRun
                $details.Models.Add($res) | Out-Null
                $summary.UniqueModelsProcessed++
                $summary.ModelFilesCopied += @($res.ModelCopy.FilesCopied).Count

                foreach ($p in @($res.VmtPathsFound)) {
                    if (Add-Once $seenVMTs $p) {
                        $summary.UniqueVMTsPlanned++
                        [void]$details.VMTs.Add($p)
                    }
                }
                foreach ($p in @($res.VtfAbsolutePaths)) {
                    if (Add-Once $seenVTFs $p) {
                        $summary.UniqueVTFsPlanned++
                        [void]$details.VTFs.Add($p)
                    }
                }

                # NEW: include actual copies done as part of the model pipeline
                $summary.VmtFilesCopied += (Accumulate-Copied $res.VmtCopy 'vmt')
                $summary.VtfFilesCopied += (Accumulate-Copied $res.VtfCopy 'vtf')
            }

            '^Vmt$' {
                if (-not (Add-Once $seenVMTs $path)) { continue }
                $summary.UniqueVMTsPlanned++
                [void]$details.VMTs.Add($path)

                $batch = Invoke-VmtBatch -VmtPaths @($path) -DestinationProjectRoot $DestinationProjectRoot `
                                         -IncludeVtfs:$IncludeVtfs -DryRun:$DryRun
                if ($batch) {
                    # Copies from the batch itself
                    $summary.VmtFilesCopied += (Accumulate-Copied $batch.VmtCopy 'vmt')
                    if ($batch.VtfCopy) {
                        foreach ($p in @($batch.VtfCopy.FilesPlanned)) {
                            if (Add-Once $seenVTFs $p) {
                                $summary.UniqueVTFsPlanned++
                                [void]$details.VTFs.Add($p)
                            }
                        }
                        $summary.VtfFilesCopied += (Accumulate-Copied $batch.VtfCopy 'vtf')
                    }
                    foreach ($p in @($batch.VmtPaths)) { [void]$details.VMTs.Add($p) }
                }
            }

            '^Vtf$' {
                if (-not (Add-Once $seenVTFs $path)) { continue }
                $summary.UniqueVTFsPlanned++
                [void]$details.VTFs.Add($path)

                $copy = Invoke-VtfBatch -VtfPaths @($path) -DestinationProjectRoot $DestinationProjectRoot -DryRun:$DryRun
                if ($copy) {
                    $summary.VtfFilesCopied += (Accumulate-Copied $copy 'vtf')
                }
            }

            '^Folder$' {
                $inv = Get-FolderInventory -FolderPath $path

                # Models in folder (MDL → VMT/VTF discovery and *copy accumulation*)
                foreach ($mdl in @($inv.Models)) {
                    if (-not (Add-Once $seenModels $mdl)) { continue }
                    $res = Invoke-ModelPack -ModelFilePath $mdl -DestinationProjectRoot $DestinationProjectRoot `
                                            -IncludeVtfs:$IncludeVtfs -DryRun:$DryRun
                    $details.Models.Add($res) | Out-Null
                    $summary.UniqueModelsProcessed++
                    $summary.ModelFilesCopied += @($res.ModelCopy.FilesCopied).Count

                    foreach ($p in @($res.VmtPathsFound)) {
                        if (Add-Once $seenVMTs $p) {
                            $summary.UniqueVMTsPlanned++
                            [void]$details.VMTs.Add($p)
                        }
                    }
                    foreach ($p in @($res.VtfAbsolutePaths)) {
                        if (Add-Once $seenVTFs $p) {
                            $summary.UniqueVTFsPlanned++
                            [void]$details.VTFs.Add($p)
                        }
                    }

                    # NEW: these lines make your counters reflect copies done while handling MDLs in folders
                    $summary.VmtFilesCopied += (Accumulate-Copied $res.VmtCopy 'vmt')
                    $summary.VtfFilesCopied += (Accumulate-Copied $res.VtfCopy 'vtf')
                }

                # VMTs directly in folder (de-duped)
                $pendingVmts = foreach ($v in @($inv.Vmts)) { if (Add-Once $seenVMTs $v) { $v } }
                $pendingVmts = @($pendingVmts | Where-Object { $_ })
                if ($pendingVmts.Count -gt 0) {
                    $summary.UniqueVMTsPlanned += $pendingVmts.Count
                    foreach ($p in $pendingVmts) { [void]$details.VMTs.Add($p) }

                    $batch = Invoke-VmtBatch -VmtPaths $pendingVmts -DestinationProjectRoot $DestinationProjectRoot `
                                             -IncludeVtfs:$IncludeVtfs -DryRun:$DryRun
                    if ($batch) {
                        $summary.VmtFilesCopied += (Accumulate-Copied $batch.VmtCopy 'vmt')
                        if ($batch.VtfCopy) {
                            foreach ($p in @($batch.VtfCopy.FilesPlanned)) {
                                if (Add-Once $seenVTFs $p) {
                                    $summary.UniqueVTFsPlanned++
                                    [void]$details.VTFs.Add($p)
                                }
                            }
                            $summary.VtfFilesCopied += (Accumulate-Copied $batch.VtfCopy 'vtf')
                        }
                        foreach ($p in @($batch.VmtPaths)) { [void]$details.VMTs.Add($p) }
                    }
                }

                # VTFs directly in folder (de-duped)
                $pendingVtfs = foreach ($t in @($inv.Vtfs)) { if (Add-Once $seenVTFs $t) { $t } }
                $pendingVtfs = @($pendingVtfs | Where-Object { $_ })
                if ($pendingVtfs.Count -gt 0) {
                    $summary.UniqueVTFsPlanned += $pendingVtfs.Count
                    foreach ($p in $pendingVtfs) { [void]$details.VTFs.Add($p) }

                    $copy = Invoke-VtfBatch -VtfPaths $pendingVtfs -DestinationProjectRoot $DestinationProjectRoot -DryRun:$DryRun
                    if ($copy) {
                        $summary.VtfFilesCopied += (Accumulate-Copied $copy 'vtf')
                    }
                }
            }

            default { Write-Verbose "Skipping unsupported entry kind '$kind' for path: $path" }
        }
    }

    [pscustomobject]@{
        Summary = $summary
        Details = [pscustomobject]$details
    }
}
