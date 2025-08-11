# SourceFilesMigrator

SourceFilesMigrator is a modular PowerShell-based utility designed to streamline the process of migrating and packaging Source Engine project files. 
It automates asset discovery, dependency resolution, and structured copying into a target project directory. 
With support for models (`.mdl`), materials (`.vmt`), textures (`.vtf`), and entire asset folders, it ensures your Source Engine projects stay clean, organized, and ready for deployment.

## Features

- **Automated Asset Discovery**
  - Scans provided folders, models, or individual files for all relevant Source Engine assets.
  - Resolves `.vmt` and `.vtf` dependencies from `.mdl` files.
  - Recursively inventories subfolders.

- **Dependency-Aware Copying**
  - Copies discovered files into the correct subdirectories of your destination project path.
  - Avoids duplicate work via case-insensitive de-duplication.
  - Optionally includes associated `.vtf` textures.

- **Batch Processing**
  - Process multiple entries in one run (models, textures, materials, or folders).
  - Summarizes counts of planned vs. copied files.

- **Dry-Run Mode**
  - Preview the operations without making any changes to disk.

- **Graphical UI**
  - Drag-and-drop interface for adding assets or folders.
  - Checkboxes for including `.vtf` textures and enabling dry-run mode.
  - Real-time log output.

## How It Works

1. **Input Entries**
   - You can add one or more entries, each with a type (`Model`, `Vmt`, `Vtf`, or `Folder`) and a path.
   - The tool can be run via CLI or its integrated WPF-based UI.

2. **Processing Pipeline**
   - For each entry, SourceFilesMigrator:
     - Normalizes paths and de-dupes entries.
     - Resolves dependencies (e.g., `.mdl` -> `.vmt` -> `.vtf`).
     - Accumulates planned file lists and performs copies if not in dry-run.

3. **Output**
   - All files are placed into your `DestinationProjectRoot` in the correct Source Engine folder structure.
   - A summary object is returned/logged with counts of processed and copied files.

## Example UI Usage

1. Run the UI entry point:
   ```powershell
   .\Start-SourceFilesMigrator.ps1
   ```
2. Drag and drop files/folders into the UI list.
3. Set the destination project path.
4. Toggle **Include VTFs** and/or **Dry Run** options.
5. Click **Run** to process.

## Requirements

- **Windows PowerShell 5.1**
- .NET Framework (for WPF UI support)
- Permissions to read from the source and write to the destination paths.

## Installation

1. Clone or extract the project into a working directory.
2. Run the UI entry point:
   ```powershell
   .\Start-SourceFilesMigrator.ps1
   ```

## Project Structure

```
SourceFilesMigrator/                # (zip root extracted)
├── Start-SourceFilesMigrator.ps1   # One-click UI bootstrap (imports modules)
└── src/
    └── Modules/
        ├── SourceFilesMigrator.Core/
        │   ├── SourceFilesMigrator.Core.psd1
        │   ├── SourceFilesMigrator.Core.psm1
        │   ├── SourceFilesMigratorCore.psm1
        │   ├── Private/
        │   │   └── Core.Private.ps1
        │   └── Public/
        │       └── Core.Public.ps1
        ├── SourceFilesMigrator.Vmt/
        │   ├── SourceFilesMigrator.VMT.psd1
        │   ├── SourceFilesMigrator.VMT.psm1
        │   └── Public/
        │       └── Vmt.Public.ps1
        ├── SourceFilesMigrator.Commands/
        │   ├── SourceFilesMigrator.Commands.psd1
        │   ├── SourceFilesMigrator.Commands.psm1
        │   ├── Private/
        │   │   └── Inventory.ps1
        │   └── Public/
        │       ├── Invoke-ModelPack.ps1
        │       ├── Invoke-SourcePackEntries.ps1
        │       ├── Invoke-VmtBatch.ps1
        │       └── Invoke-VtfBatch.ps1
        └── SourceFilesMigrator.UI/
            ├── SourceFilesMigrator.UI.psd1
            ├── SourceFilesMigrator.UI.psm1
            ├── Private/
            │   └── UI.Helpers.ps1
            └── Public/
                └── Start-SourceFilesMigratorI.ps1   # UI window (XAML & event wiring)
```

## Contributing

Contributions are welcome! Please fork the repo, make your changes in a feature branch, and submit a pull request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
