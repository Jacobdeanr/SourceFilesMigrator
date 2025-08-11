# Single source of truth for exclude patterns
# Keep this list here ONLY. Everyone else must ask this module.
$script:SfmExcludePattern = @(
    '\bdev[\\/]',              # dev folders
    '\bpsd\b',                 # psd
    '\bpsb\b',                 # psb
    '\bvray\b',                # vray
    '\bbackup\b',              # backup dirs
    '\btemp\b',                # temp dirs
    'thumbs\.db$',             # Thumbs.db
    '(^|[\\/])\._',            # macOS resource forks
    '\.bak$',                  # .bak
    '\.blend.*$',              # .blend*
    '\.psd$',                  # .psd (explicit)
    '\.mdmp$'                  # .mdmp
) -join '|'
