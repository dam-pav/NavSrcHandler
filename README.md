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
  - PowerShell 7+ (pwsh) will technically work and NavSrcHandler.cmd will attempt to mitigate by running a separate session for the tool. This is invisible to the user. If you don't get a warning about Powershell version, you are fine.
- NAV PowerShell cmdlets provided by NAV Model Tools:
  - `Split-NAVApplicationObjectFile`
  - `Join-NAVApplicationObjectFile`
- Git (optional):
  - `winget install -e --id Git.Git`

On start, the tool attempts to initialize NAV/BC Dev Shell cmdlets automatically. If not found, it will warn you to run in the Dev Shell or import the module `Microsoft.Dynamics.Nav.Model.Tools`.

Make sure that you are using model tools compatible with your development environment. Module selection is integrated and persisted. Double check the encoding of output files.

> Tip: NAV Model Tools can behave differently if run from Powershell 7, leading to codepage disruption. Run NavSrcHandler.cmd rather than NavSrcHandler.ps1 directly. Or if you need to run NavSrcHandler.ps1, do it within a Powershell 5.1 terminal session.
>
> In Windows 11 you can select  "Windows PowerShell" from Windows menu to open a PowerShell 5.1 terminal.

> Tip: Start a “Microsoft Dynamics NAV/Business Central Development Shell” (also Powershell 5.1) or import the relevant module so these commands exist.Getting Started

## Installation

Using a terminal (Powershell or Cmd) create and navigate to a local folder suitable for manually managed tools. For instance, "C:\tools".

If you have Git installed you simply do this:

1. `git clone https://github.com/dam-pav/NavSrcHandler.git`
2. This will create a folder named NavSrcHandler. Navigate to the new folder and run NavSrcHandler.cmd

If not, you can

1. Create a new folder named NavSrcHandler and navigate to the new folder.
2. Download as zip and extract the content into a suitable folder.
3. Run NavSrcHandler.cmd.

> Warning: without Git you are missing out on automatic updates.

> Tip: the clone also contains this README.md so you can use it as reference anytime.

### Add the hosting folder to environment paths

The first time you will need to run the tool directly from the host folder.

```
# Run the interactive tool
NavSrcHandler.cmd
```

If the path is not yet part of environment, the menu will show an option to apply the required change. Simply select the option.

### Set up

#### Source types

Source types define the names for the txt files that will be considered for containing the source. By default these designations are `PRD`, `DLY`, `DEV`, `TST` and `BSE`. You can add or remove names that you find convenient.

#### NAV Model Tools selection

By default the Model Tools will be selected by automated detection. If this works for you, you don't need any further setup. If you run into issues related to compatibility, you can select a specific version out of any that are installed at your host locally. The selection remains persistent.

### Removing the tool

If you find this tool is not what you want you will want to remove it.

1. Clear the folder from the environment path using `RemoveFolderFromPath.ps1`.
2. Remove the folder and its contents. That's it.

## Usage

> Tip: Avoid running ps1 directly even if you try to incorporate it into a broader context. Or, make sure ps1 runs in a Powershell 5.1 session.

#### Running after navigation

I recommend running the tool from a console. You don't need to run as administrator, not even during installation. In fact, don't - some of the settings are related to the current user profile.

Navigate to the folder containing your source files (DEV.txt, TST.txt and so on). Simply run:

```
NavSrcHandler.cmd
```

Your current path in the console becomes your working path.

#### Running with a Target Folder

You can pass a target folder path as an argument to set a specific folder as working path instead of the current one:

```powershell
NavSrcHandler.cmd "C:\Projects\MyNavProject"
```

### Menu options

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
  - `NavModelToolsPath`: NAV Model Tools selection

Example:

```json
{
  "SourceTypes": ["DLY", "PRD", "DEV", "TST", "BSE"],
  "NavModelToolsPath": "C:\\Program Files (x86)\\Microsoft Dynamics NAV\\110\\RoleTailored Client\\Microsoft.Dynamics.Nav.Model.Tools.psd1"
}
```

## Typical Workflow

1. Option 1 : Inspect — see object IDs per type for a selected source.
2. Option 2: Prepare — performs splitting and seeds merge folders.
3. Make any manual edits in `MRG2XXX/` as needed. Do not modify files in `XXX/` folders, keep them as backup and reference. After you complete the merge for all the objects you can compare `XXX/` and `MRG2XXX/` to get the actual changes in the code for the target environment.
4. Option 3: Merge — produces `MRG2XXX.txt` outputs.

## Troubleshooting

- "NAV cmdlets not found": ensure you are running in a NAV/BC Dev Shell or that the module providing `Split-NAVApplicationObjectFile` and `Join-NAVApplicationObjectFile` is imported.
- Missing source file: the tool skips a code if `CODE.txt` isn’t present in the current working folder.
- Permissions: run PowerShell with sufficient rights to create directories and files in the working folder where you run the tool.
- Local characters are disrupted: make sure you are using Powershell 5.1 and select model tools compatible with your current project.

## Notes

- Folder creation and cleanup are handled safely; the tool clears only the code-specific split and merge folders when preparing.
