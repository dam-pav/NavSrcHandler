# NAV Source Handler (Split/Merge Tool)

An interactive PowerShell helper that prepares and merges Microsoft Dynamics NAV/BC application object files. The purpose of this tool is to facilitate the [Nav Development Protocol](The Nav Development Protocol.md).

## Features

- Set a working folder (persisted)
- Manage 3-letter source type codes (e.g., `DLY`, `PRD`, `DEV`, `TST`, `BSE`) (persisted)
- Inspect: pick an available source (from existing `<CODE>.txt` in the working folder) and print pipe-separated IDs grouped by object type
- Prepare: split `<CODE>.txt` into `<WORKING>/<CODE>/` and seed `<WORKING>/MRG2<CODE>/`
- Merge: join `<WORKING>/MRG2<CODE>/*.txt` into `<WORKING>/MRG2<CODE>.txt`
- Menu-driven, settings saved to `settings.json` (JSON content). The file is created on first change (e.g., after setting working folder or codes).
- Conditional utility: add the script's host folder to the User PATH (shows only if it's not already on PATH)

## Requirements

- Windows PowerShell 5.1 or PowerShell 7+ (pwsh)
- NAV/BC PowerShell cmdlets available in the session:
  - `Split-NAVApplicationObjectFile`
  - `Join-NAVApplicationObjectFile`

On start, the tool attempts to initialize NAV/BC Dev Shell cmdlets automatically. If not found, it will warn you to run in the Dev Shell or import the module `Microsoft.Dynamics.Nav.Model.Tools`.

Tip: Start a “Microsoft Dynamics NAV/Business Central Development Shell” or import the relevant module so these commands exist.

## Getting Started

Choose a folder to host the script and download the ps1 and cmd files. You may want to copy this README.md file as well, for future reference. If you clone the complete repository you can take advantage of keeping up to date almost automatically.

### From the repository folder:

```powershell
# Run the interactive tool
./NavSrcHandler.ps1
```

### Add the hosting folder to environment paths

If the path is not yet part of environment, the menu will show a sixth option. Simply select the option.

### Removing the tool

If you find this tool is not what you want you will want to remove it.

1. Clear the folder from the environment path using `RemoveFolderFromPath.ps1`.
2. Remove the folder and its contents. That's it.

## Usage (Menu)

1. Set working folder
   - Choose or create the folder that contains your source files like `PRD.txt`, `DLY.txt`, etc.
   - This path is saved in `settings.json`.
2. Manage source types
   - Add or remove 3-letter codes (e.g., `PRD`, `DLY`, `DEV`, `TST`, `BSE`).
   - Saved in `settings.json`.
3. Inspect source IDs (pipe-per-type)

- Lists only the source codes for which `<CODE>.txt` exists in the working folder.
- After you pick a source, parses the file and prints one line per object type with IDs pipe-separated, e.g. `Table: 18|27|36`.

4. Prepare (split + seed merge folders)
   - For each selected code `XXX`:
     - Split `XXX.txt` into `./XXX/` using `Split-NAVApplicationObjectFile`.
     - Copy contents to `./MRG2XXX/`.
5. Merge (MRG2 `<CODE>`/*.txt -> MRG2 `<CODE>`.txt)
   - For each selected code `XXX`, join files in `./MRG2XXX/` to `./MRG2XXX.txt` using `Join-NAVApplicationObjectFile`.
6. Add host folder to PATH (conditional)

- Appears only when the script's folder isn't already on PATH.
- Adds the folder to the User PATH and updates the current session PATH for immediate use.

## Settings & Persistence

- Settings are stored next to the script in `settings.json` (JSON content). The file is created on first change.
- Keys:
  - `WorkingFolder`: absolute path to your working directory.
  - `SourceTypes`: array of 3-letter codes.

Example:

```json
{
  "WorkingFolder": "C:\\Projects\\Work\\MyObjects",
  "SourceTypes": ["DLY", "PRD", "DEV", "TST", "BSE"]
}
```

## Typical Workflow

1. Option 1: set the working folder where `PRD.txt`, `DLY.txt`, etc. live.
2. Option 2: confirm the set of source codes you care about.
3. Option 3 (optional): Inspect — see object IDs per type for a selected source.
4. Option 4: Prepare — performs splitting and seeds merge folders.
5. Make any manual edits in `MRG2XXX/` as needed.
6. Option 5: Merge — produces `MRG2XXX.txt` outputs.

## Troubleshooting

- "NAV cmdlets not found": ensure you are running in a NAV/BC Dev Shell or that the module providing `Split-NAVApplicationObjectFile` and `Join-NAVApplicationObjectFile` is imported.
- Missing source file: the tool skips a code if `CODE.txt` isn’t present in the working folder.
- Permissions: run PowerShell with sufficient rights to create directories and files in the working folder.

## Notes

- Folder creation and cleanup are handled safely; the tool clears only the code-specific split and merge folders when preparing.
