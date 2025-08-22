# NavSrcHandler.ps1 — Interactive NAV object split/merge helper with persisted settings

<#
  Features
  - Set working folder (persisted)
  - Select source type codes (e.g., DLY, PRD, DEV, TST, BSE) (persisted)
  - Prepare: split each <CODE>.txt to <WORKING>/<CODE>/ and seed <WORKING>/MRG2<CODE>/
  - Merge: join <WORKING>/MRG2<CODE>/*.txt into <WORKING>/MRG2<CODE>.txt
  - Menu system for all actions
    - Settings persisted to a settings.json file (JSON content)

  Requirements
  - PowerShell 5+ (Windows) or pwsh 7+
  - NAV/BC PowerShell tools providing:
      Split-NAVApplicationObjectFile, Join-NAVApplicationObjectFile

  Notes
  - If NAV cmdlets are not available, the tool will warn and skip split/merge.
#>

param(
    [switch]$Menu = $true
)


Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# region Git update check (run once at script start)
$script:GitAvailable = $false
$script:GitUpdateAvailable = $false
try {
    $gitVersion = git --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        $script:GitAvailable = $true
        $originUrl = git remote get-url origin 2>$null
        if ($LASTEXITCODE -eq 0 -and $originUrl) {
            git fetch origin 2>$null
            $behindCount = git rev-list HEAD..origin/main --count 2>$null
            if ($behindCount -and ($behindCount -as [int]) -gt 0) {
                $script:GitUpdateAvailable = $true
                $script:GitBehindCount = $behindCount
            }
        }
    }
} catch {}
# endregion

# region Settings
$script:SettingsPath = Join-Path $PSScriptRoot 'settings.json'   # JSON settings file

function New-DefaultSettings {
    [pscustomobject]@{
        WorkingFolder = (Get-Location).Path
        SourceTypes   = @('DLY','PRD','DEV','TST','BSE')
    }
}

function Get-Settings {
    if (Test-Path -LiteralPath $script:SettingsPath) {
        try {
            $raw = Get-Content -LiteralPath $script:SettingsPath -Raw -ErrorAction Stop
            if ([string]::IsNullOrWhiteSpace($raw)) { return New-DefaultSettings }
            $obj = $raw | ConvertFrom-Json -ErrorAction Stop
            # Ensure mandatory fields
            if (-not $obj.WorkingFolder) { $obj.WorkingFolder = (Get-Location).Path }
            if (-not $obj.SourceTypes)   { $obj.SourceTypes   = @('DLY','PRD','DEV','TST','BSE') }
            return [pscustomobject]$obj
        }
        catch {
            Write-Warning "Settings file is corrupt or unreadable. Recreating defaults. Details: $($_.Exception.Message)"
            return New-DefaultSettings
        }
    }
    else {
        return New-DefaultSettings
    }
}

function Set-Settings([object]$settings) {
    $json = $settings | ConvertTo-Json -Depth 5
    $json | Set-Content -LiteralPath $script:SettingsPath -Encoding UTF8
}
# endregion Settings

# region Helpers
function New-DirectoryIfMissing([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) {
        New-Item -Path $path -ItemType Directory -Force | Out-Null
    }
}

function Clear-Directory([string]$path) {
    if (Test-Path -LiteralPath $path) {
        Get-ChildItem -LiteralPath $path -Force -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
    }
}

function Test-NavCmdlets {
    $split = Get-Command -Name 'Split-NAVApplicationObjectFile' -ErrorAction SilentlyContinue
    $join  = Get-Command -Name 'Join-NAVApplicationObjectFile'  -ErrorAction SilentlyContinue
    return [bool]($split -and $join)
}

function Import-NavCmdlets {
    if (Test-NavCmdlets) { return $true }
    $loaded = $false

    # Try module by name first
    try {
        Import-Module -Name 'Microsoft.Dynamics.Nav.Model.Tools' -ErrorAction Stop
        if (Test-NavCmdlets) { $loaded = $true }
    } catch { }

    $roots = @(
        'C:\Program Files (x86)\Microsoft Dynamics 365 Business Central',
        'C:\Program Files\Microsoft Dynamics 365 Business Central',
        'C:\Program Files (x86)\Microsoft Dynamics NAV',
        'C:\Program Files\Microsoft Dynamics NAV'
    )

    foreach ($root in $roots) {
        if ($loaded) { break }
        if (-not (Test-Path -LiteralPath $root)) { continue }
        # Try module manifest
        $psd1 = Get-ChildItem -LiteralPath $root -Filter 'Microsoft.Dynamics.Nav.Model.Tools.psd1' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($psd1) {
            try {
                Import-Module -LiteralPath $psd1.FullName -ErrorAction Stop
                if (Test-NavCmdlets) { $loaded = $true; break }
            } catch { }
        }
        # Try helper script
        if (-not $loaded) {
            $ps1 = Get-ChildItem -LiteralPath $root -Filter 'NavModelTools.ps1' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($ps1) {
                try {
                    . $ps1.FullName
                    if (Test-NavCmdlets) { $loaded = $true; break }
                } catch { }
            }
        }
    }

    if ($loaded) {
        Write-Host 'NAV/BC Dev Shell cmdlets initialized.' -ForegroundColor Green
        return $true
    } else {
        Write-Warning 'NAV/BC Dev Shell cmdlets not found. Run in a NAV/BC Development Shell or install/import Microsoft.Dynamics.Nav.Model.Tools.'
        return $false
    }
}

function Get-Choice([string]$prompt, [string[]]$options, [int]$defaultIndex = 0) {
    Write-Host ''
    for ($i=0; $i -lt $options.Count; $i++) {
        $marker = if ($i -eq $defaultIndex) { '*' } else { ' ' }
        Write-Host ("  [{0}] {1} {2}" -f $i, $options[$i], $marker)
    }
    $sel = Read-Host "$prompt (0..$($options.Count-1))"
    if ([string]::IsNullOrWhiteSpace($sel)) { return $defaultIndex }
    if ($sel -as [int] -ge 0 -and $sel -as [int] -lt $options.Count) { return [int]$sel }
    Write-Host 'Invalid selection.' -ForegroundColor Yellow
    return $defaultIndex
}

function Test-Code([string]$code) {
    if ([string]::IsNullOrWhiteSpace($code)) { return $false }
    $c = $code.Trim().ToUpperInvariant()
    return ($c.Length -eq 3 -and $c -match '^[A-Z0-9]{3}$')
}

function Get-ExistingTxt([string]$folder, [string]$pattern) {
    Get-ChildItem -LiteralPath $folder -Filter $pattern -File -ErrorAction SilentlyContinue
}

# Return list of available source files based on current settings (only those that exist)
function Get-AvailableSourceFiles {
    param([object]$settings)
    $root = $settings.WorkingFolder
    $available = @()
    foreach ($code in $settings.SourceTypes) {
        $c = $code.ToUpperInvariant()
        $path = Join-Path $root ("$c.txt")
        if (Test-Path -LiteralPath $path) {
            $available += [pscustomobject]@{ Code = $c; Path = $path }
        }
    }
    return $available
}

# Normalize a path segment for comparison (trim quotes/whitespace and trailing separators)
function Normalize-PathSegment([string]$segment) {
    if ($null -eq $segment) { return '' }
    $s = $segment.Trim().Trim('"')
    # Remove trailing backslashes/slashes
    while ($s.EndsWith('\') -or $s.EndsWith('/')) { $s = $s.Substring(0, $s.Length - 1) }
    return $s
}

# Check if a path is present as a full segment in a PATH-like string
function Test-PathInPathValue {
    param(
        [string]$path,
        [string]$pathValue
    )
    if ([string]::IsNullOrWhiteSpace($pathValue)) { return $false }
    $needle = Normalize-PathSegment $path
    if ([string]::IsNullOrWhiteSpace($needle)) { return $false }
    foreach ($seg in ($pathValue -split ';')) {
        $candidate = Normalize-PathSegment $seg
        if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
        if ($candidate.Equals($needle, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    return $false
}

# Check across Process, User, and Machine PATH values
function Test-PathInAnyEnvPATH([string]$path) {
    $proc = $env:Path
    $usr  = [System.Environment]::GetEnvironmentVariable('Path', [System.EnvironmentVariableTarget]::User)
    $mach = [System.Environment]::GetEnvironmentVariable('Path', [System.EnvironmentVariableTarget]::Machine)
    return (Test-PathInPathValue -path $path -pathValue $proc) -or
           (Test-PathInPathValue -path $path -pathValue $usr)  -or
           (Test-PathInPathValue -path $path -pathValue $mach)
}

# Add host folder to User PATH (and current session) if not present anywhere
function Add-HostFolderToUserPath {
    param([string]$hostFolder)
    if ([string]::IsNullOrWhiteSpace($hostFolder)) {
        Write-Warning 'Host folder path is empty.'
        return
    }
    if (Test-PathInAnyEnvPATH -path $hostFolder) {
        Write-Host 'Host folder already present in PATH. Nothing to do.' -ForegroundColor Yellow
        return
    }

    $currentUserPath = [System.Environment]::GetEnvironmentVariable('Path', [System.EnvironmentVariableTarget]::User)
    $normalizedHost = Normalize-PathSegment $hostFolder
    $newUserPath = if ([string]::IsNullOrWhiteSpace($currentUserPath)) { $normalizedHost } else { ($currentUserPath.TrimEnd(';') + ';' + $normalizedHost) }

    try {
        [System.Environment]::SetEnvironmentVariable('Path', $newUserPath, [System.EnvironmentVariableTarget]::User)
        # Also update current session PATH for immediate use if missing
        if (-not (Test-PathInPathValue -path $normalizedHost -pathValue $env:Path)) {
            $env:Path = ($env:Path.TrimEnd(';') + ';' + $normalizedHost)
        }
        Write-Host ('Added to User PATH: ' + $normalizedHost) -ForegroundColor Green
        Write-Host 'New terminals will inherit this change. Restart apps as needed.' -ForegroundColor DarkGray
    }
    catch {
        Write-Warning ('Failed to update User PATH: ' + $_.Exception.Message)
    }
}
# endregion Helpers

# region Core actions
function Set-WorkingFolder {
    param([ref]$settings)
    Clear-Host
    Show-Header -settings $settings.Value
    $current = $settings.Value.WorkingFolder
    Write-Host "Current working folder: $current" -ForegroundColor Cyan
    $inputPath = Read-Host 'Enter new working folder path (leave blank to keep current, type . to set to active folder)'
    if ([string]::IsNullOrWhiteSpace($inputPath)) { return $true }
    $resolved = Resolve-Path -LiteralPath $inputPath -ErrorAction SilentlyContinue
    if (-not $resolved) {
        $create = Read-Host 'Path does not exist. Create it? (y/n)'
        if ($create -match '^(y|yes)$') {
            New-Item -Path $inputPath -ItemType Directory -Force | Out-Null
            $resolved = Resolve-Path -LiteralPath $inputPath
        }
        else { return $false }
    }
    $settings.Value.WorkingFolder = $resolved.Path
    Set-Settings $settings.Value
    Write-Host "Working folder set to: $($settings.Value.WorkingFolder)" -ForegroundColor Green
    return $true
}

function Set-SourceTypes {
    param([ref]$settings)
    $codes = [System.Collections.Generic.List[string]]::new()
    $settings.Value.SourceTypes | ForEach-Object { [void]$codes.Add($_.ToUpperInvariant()) }

    $done = $false
    while (-not $done) {
        Clear-Host
        Show-Header -settings $settings.Value
        Write-Host ''
        Write-Host 'Source type codes (3 chars):' -ForegroundColor Cyan
        Write-Host ('  ' + ($codes -join ', '))
        Write-Host '1) Add'
        Write-Host '2) Remove'
        Write-Host '3) Reset to defaults'
        Write-Host '0) Done/Return'
        $choice = Read-Host 'Choose option'
        switch ($choice) {
            '1' {
                $new = Read-Host 'Enter code to add (e.g., DLY)'
                if (Test-Code $new) {
                    $u = $new.Trim().ToUpperInvariant()
                    if (-not $codes.Contains($u)) { [void]$codes.Add($u); Write-Host 'Added.' -ForegroundColor Green }
                    else { Write-Host 'Already present.' -ForegroundColor Yellow }
                } else { Write-Host 'Invalid code. Must be exactly 3 alnum chars.' -ForegroundColor Yellow }
            }
            '2' {
                $rem = Read-Host 'Enter code to remove'
                if (Test-Code $rem) {
                    $u = $rem.Trim().ToUpperInvariant()
                    if ($codes.Remove($u)) { Write-Host 'Removed.' -ForegroundColor Green } else { Write-Host 'Not found.' -ForegroundColor Yellow }
                } else { Write-Host 'Invalid code.' -ForegroundColor Yellow }
            }
            '3' {
                $codes = [System.Collections.Generic.List[string]]::new()
                'DLY','PRD','DEV','TST','BSE' | ForEach-Object { [void]$codes.Add($_) }
                Write-Host 'Reset to defaults.' -ForegroundColor Green
            }
            '0' { $done = $true }
            default { Write-Host 'Invalid selection.' -ForegroundColor Yellow }
        }
    }

    if ($codes.Count -eq 0) { Write-Host 'No codes selected, keeping previous.' -ForegroundColor Yellow; return $true }
    $settings.Value.SourceTypes = @($codes | Sort-Object -Unique)
    Set-Settings $settings.Value
    return $true
}

function Show-ObjectIdSummary {
    param([object]$settings)
    Clear-Host
    Show-Header -settings $settings
    $available = Get-AvailableSourceFiles -settings $settings
    if (-not $available -or $available.Count -eq 0) {
        Write-Warning ("No source files found in working folder: " + $settings.WorkingFolder)
        return
    }

    $options = @()
    foreach ($item in $available) { $options += $item.Code }
    for ($i=0; $i -lt $options.Count; $i++) {
        Write-Host ("{0}) {1}" -f ($i+1), $options[$i])
    }
    Write-Host '0) Return'
    $choice = Read-Host 'Select a source'
    if ($choice -eq '0') { return }
    $index = ($choice -as [int]) - 1
    if ($index -lt 0 -or $index -ge $options.Count) {
        Write-Host 'Invalid selection.' -ForegroundColor Yellow
        return
    }
    $selection = $available[$index]

    Write-Host ''
    Write-Host ("Inspecting " + $selection.Code) -ForegroundColor Cyan

    # Map Type -> [List[int]] of IDs
    $map = @{}
    try {
        Get-Content -LiteralPath $selection.Path -ErrorAction Stop | ForEach-Object {
            $line = $_
            if ($line -match '^\s*OBJECT\s+([A-Za-z]+)\s+(\d+)\b') {
                $type = $matches[1]
                $id = [int]$matches[2]
                if (-not $map.ContainsKey($type)) { $map[$type] = [System.Collections.Generic.List[int]]::new() }
                [void]$map[$type].Add($id)
            }
        }
    }
    catch {
        $err = $_
        Write-Warning ("Failed to read '" + $selection.Path + "' - " + $err.Exception.Message)
        return
    }

    if ($map.Keys.Count -eq 0) {
        Write-Host ("No OBJECT headers found in " + $selection.Path) -ForegroundColor Yellow
        return
    }

    foreach ($type in ($map.Keys | Sort-Object)) {
        $ids = $map[$type] | Sort-Object
        $pipe = ($ids -join '|')
        Write-Host ("  {0}: {1}" -f $type, $pipe)
    }
}

function Invoke-PrepareSplits {
    param([object]$settings)
    Clear-Host
    Show-Header -settings $settings
    if (-not (Test-NavCmdlets)) {
        Write-Warning 'NAV cmdlets not found. Ensure Split-NAVApplicationObjectFile and Join-NAVApplicationObjectFile are available (open NAV/BC Dev Shell).'
        return
    }

    $root = $settings.WorkingFolder
    New-DirectoryIfMissing $root
    $foundAny = $false
    foreach ($code in $settings.SourceTypes) {
        $c = $code.ToUpperInvariant()
        $srcFile  = Join-Path $root ("$c.txt")
        $splitDir = Join-Path $root $c
        $mrgDir   = Join-Path $root ("MRG2$c")

        # Print a neat header per found source
        if (-not (Test-Path -LiteralPath $srcFile)) { continue }
        $foundAny = $true
        Write-Host ''
        Write-Host ("Preparing " + $c) -ForegroundColor Cyan

    New-DirectoryIfMissing $splitDir
    New-DirectoryIfMissing $mrgDir
        Clear-Directory $splitDir
        Clear-Directory $mrgDir

        try {
            Split-NAVApplicationObjectFile -Source $srcFile -Destination $splitDir -PreserveFormatting -Force
            Write-Host "  Split -> $splitDir" -ForegroundColor Green
        }
        catch {
            $err = $_
            $msg = ($err.Exception.Message)
            Write-Warning ("  Split failed for " + $c + " - " + $msg)
            continue
        }

        try {
            # Only copy if split produced files; use -Path to expand wildcard
            $hasFiles = Get-ChildItem -Path $splitDir -Force -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer } | Select-Object -First 1
            if ($hasFiles) {
                Copy-Item -Path (Join-Path $splitDir '*') -Destination $mrgDir -Force -Recurse -ErrorAction Stop
                Write-Host "  Seeded -> $mrgDir" -ForegroundColor Green
            } else {
                Write-Host "  No files produced for $c — nothing to seed." -ForegroundColor Yellow
            }
        }
        catch {
            $err = $_
            $msg = ($err.Exception.Message)
            Write-Warning ("  Copy to merge folder failed for " + $c + " - " + $msg)
        }
    }
    if (-not $foundAny) {
        Write-Warning ("No source files found for selected types in working folder: " + $root)
    }
}

function Invoke-MergeFiles {
    param([object]$settings)
    Clear-Host
    Show-Header -settings $settings
    if (-not (Test-NavCmdlets)) {
        Write-Warning 'NAV cmdlets not found. Ensure Split-NAVApplicationObjectFile and Join-NAVApplicationObjectFile are available (open NAV/BC Dev Shell).'
        return
    }

    $root = $settings.WorkingFolder
    foreach ($code in $settings.SourceTypes) {
        $c = $code.ToUpperInvariant()
        $mrgDir = Join-Path $root ("MRG2$c")
        $out    = Join-Path $root ("MRG2$c.txt")

    if (-not (Test-Path -LiteralPath $mrgDir)) { continue }
    Write-Host ("`nMerging " + $c) -ForegroundColor Cyan

        $files = Get-ExistingTxt -folder $mrgDir -pattern '*.txt'
        if (-not $files) {
            Write-Host "  No .txt files found in $mrgDir — skipping." -ForegroundColor Yellow
            continue
        }

        if (Test-Path -LiteralPath $out) { Remove-Item -LiteralPath $out -Force }
        try {
            Join-NAVApplicationObjectFile -Source (Join-Path $mrgDir '*.txt') -Destination $out
            Write-Host "  Created $out" -ForegroundColor Green
        }
        catch {
            $err = $_
            $msg = ($err.Exception.Message)
            Write-Warning ("  Merge failed for " + $c + " - " + $msg)
        }
    }
}
# endregion Core actions

# region Menu
function Show-Header {
    param([object]$settings)
    Write-Host ''
    Write-Host '==============================================='
    Write-Host ' NAV Source Handler — Split/Merge Tool'
    Write-Host '==============================================='
    Write-Host (" Working: " + $settings.WorkingFolder) -ForegroundColor Cyan
    Write-Host (" Sources: " + ($settings.SourceTypes -join ', ')) -ForegroundColor Cyan
}

function Invoke-Menu {
    $settings = Get-Settings
    # Attempt to initialize NAV cmdlets once at startup
    Import-NavCmdlets | Out-Null

    while ($true) {
        Clear-Host
        $skipPause = $false
        Show-Header -settings $settings
        Write-Host ''
        $hostFolder = $PSScriptRoot
        $offerAddPath = -not (Test-PathInPathValue -path $hostFolder -pathValue $env:Path)

        Write-Host '1) Set working folder'
        Write-Host '2) Manage source types'
        Write-Host '3) Inspect source IDs (pipe-per-type)'
        Write-Host '4) Prepare (split + seed merge folders)'
        Write-Host '5) Merge (MRG2<CODE>/*.txt -> MRG2<CODE>.txt)'
        if ($offerAddPath) { Write-Host '6) Add host folder to path' }

        if ($script:GitAvailable -and $script:GitUpdateAvailable) {
            Write-Host ("7) Pull latest update from origin/main (" + $script:GitBehindCount + " commit(s) behind)") -ForegroundColor Yellow
        }
        Write-Host '0) Exit'

        try {
            $sel = Read-Host 'Select option'
        }
        catch {
            Write-Host 'Interactive input is not available. Please run this script in a terminal (e.g., VS Code Terminal) to use the menu.' -ForegroundColor Yellow
            break
        }
        switch ($sel) {
            '1' { $changed = Set-WorkingFolder -settings ([ref]$settings); if ($changed) { $skipPause = $true } }
            '2' { $changed = Set-SourceTypes -settings ([ref]$settings); if ($changed) { $skipPause = $true } }
            '3' { Show-ObjectIdSummary -settings $settings }
            '4' { Invoke-PrepareSplits -settings $settings }
            '5' { Invoke-MergeFiles -settings $settings }
            '6' {
                if ($offerAddPath) {
                    Add-HostFolderToUserPath -hostFolder $hostFolder
                } else {
                    Write-Host 'Invalid choice.' -ForegroundColor Yellow
                }
            }
            '7' {
                if ($script:GitAvailable -and $script:GitUpdateAvailable) {
                    Write-Host 'Pulling latest updates from origin/main...'
                    git pull origin main
                } else {
                    Write-Host 'No updates available to pull.' -ForegroundColor Green
                }
            }
            '0' { return }
            default { Write-Host 'Invalid choice.' -ForegroundColor Yellow }
        }
        if (-not $skipPause) {
            Write-Host ''
            try { [void](Read-Host 'Press Enter to continue') } catch { }
            try { Clear-Host } catch { }
        }
    }
}
# endregion Menu

# Entry point
if ($Menu -and ($MyInvocation.InvocationName -ne '.')) {
    try { Invoke-Menu } catch { Write-Error $_ }
}
