# NAV Source Handler (Split/Merge Tool)

An interactive PowerShell helper that prepares and merges Microsoft Dynamics NAV/BC application object files. The purpose of this tool is to facilitate the [Nav Development Protocol](The%20Nav%20Development%20Protocol.md).

## Features

- Manage 3-letter source type codes (e.g., `DLY`, `PRD`, `DEV`, `TST`, `BSE`) (persisted)
- Inspect: pick an available source (from existing `<CODE>.txt` in the current working folder) and print pipe-separated IDs grouped by object type
- Prepare: split `<CODE>.txt` into `<WORKING>/<CODE>/` and seed `<WORKING>/MRG2<CODE>/`
- Merge: join `<WORKING>/MRG2<CODE>/*.txt` into `<WORKING>/MRG2<CODE>.txt`
- Menu-driven, settings saved to `settings.json` (JSON content). The file is created on first change.
- Conditional utility: add the script's host folder to the User PATH (shows only if it's not already on PATH)
- Conditional utility: update the tool if git shows the origin to be ahead

## Requirements

- Windows PowerShell 5.1
  - PowerShell 7+ (pwsh) will technically work, but the output of file manipulation will most likely disrupt codepages.
- NAV PowerShell cmdlets available in the session:
  - `Split-NAVApplicationObjectFile`
  - `Join-NAVApplicationObjectFile`

On start, the tool attempts to initialize NAV/BC Dev Shell cmdlets automatically. If not found, it will warn you to run in the Dev Shell or import the module `Microsoft.Dynamics.Nav.Model.Tools`.

Make sure that you are using model tools compatible with your development environment. Module selection is integrated and persisted. Double check the encoding of output files.

> Tip: Start a “Microsoft Dynamics NAV/Business Central Development Shell” or import the relevant module so these commands exist. Use "Windows Powershell" an avoid using "Powershell 7".

## Getting Started

Choose a folder to host the script and download the ps1 and cmd files. You may want to copy this README.md file as well, for future reference. If you clone the complete repository you can take advantage of keeping up to date almost automatically.

### Add the hosting folder to environment paths

The first time you will need to run the tool directly from the host folder.

```
# Run the interactive tool
NavSrcHandler.cmd
```

If the path is not yet part of environment, the menu will show an option to apply the required change. Simply select the option.

### Removing the tool

If you find this tool is not what you want you will want to remove it.

1. Clear the folder from the environment path using `RemoveFolderFromPath.ps1`.
2. Remove the folder and its contents. That's it.

### Running with a Target Folder

You can pass a target folder path as an argument to process a specific directory instead of the current one:

```powershell
NavSrcHandler.cmd "C:\Projects\MyNavProject"
```

## Usage (Menu)

1. Inspect source IDs (pipe-per-type)
   - Lists only the source codes for which `<CODE>.txt` exists in the current working folder.
   - After you pick a source, parses the file and prints one line per object type with IDs pipe-separated, e.g. `Table: 18|27|36`.
2. Prepare (split + seed merge folders)
   - For each selected code `XXX`:
     - Split `XXX.txt` into `./XXX/` using `Split-NAVApplicationObjectFile`.
     - Copy contents to `./MRG2XXX/`.
3. Merge (MRG2 `<CODE>`/*.txt -> MRG2 `<CODE>`.txt)
   - For each selected code `XXX`, join files in `./MRG2XXX/` to `./MRG2XXX.txt` using `Join-NAVApplicationObjectFile`.
4. Manage source types
   - Add or remove 3-letter codes (e.g., `PRD`, `DLY`, `DEV`, `TST`, `BSE`).
   - Saved in `settings.json`.
5. Add host folder to PATH (conditional)
   - Appears only when the script's folder isn't already on PATH.
   - Adds the folder to the User PATH and updates the current session PATH for immediate use.
6. Select NAV Model Tools
   * Make sure the tools are compatible with your current project
7. Pull latest update from origin (conditional)
   - Appears when new commits are detected.
   - Executes git pull until the folder is up to date.

## Settings & Persistence

- Settings are stored next to the script in `settings.json` (JSON content). The file is created on first change.
- Keys:
  - `SourceTypes`: array of 3-letter codes.

Example:

```json
{
  "SourceTypes": ["DLY", "PRD", "DEV", "TST", "BSE"]
}
```

## Typical Workflow

1. Option 1 : Inspect — see object IDs per type for a selected source.
2. Option 2: Prepare — performs splitting and seeds merge folders.
3. Make any manual edits in `MRG2XXX/` as needed.
4. Option 3: Merge — produces `MRG2XXX.txt` outputs.

## Troubleshooting

- "NAV cmdlets not found": ensure you are running in a NAV/BC Dev Shell or that the module providing `Split-NAVApplicationObjectFile` and `Join-NAVApplicationObjectFile` is imported.
- Missing source file: the tool skips a code if `CODE.txt` isn’t present in the current working folder.
- Permissions: run PowerShell with sufficient rights to create directories and files in the working folder where you run the tool.
- Local characters are disrupted: make sure you are using Powershell 5.1 and select model tools compatible with your current project.

## Notes

- Folder creation and cleanup are handled safely; the tool clears only the code-specific split and merge folders when preparing.
