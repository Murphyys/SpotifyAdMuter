#Requires -Version 5.1
# install.ps1 — Installs SpotifyAdMuter. No administrator rights required.
# Run from the cloned repo folder:  .\install.ps1

$ErrorActionPreference = 'Stop'
$installDir = Join-Path $env:LOCALAPPDATA 'SpotifyMute'
$srcDir     = $PSScriptRoot

Write-Host ""
Write-Host "SpotifyAdMuter Installer" -ForegroundColor Cyan
Write-Host "========================" -ForegroundColor Cyan
Write-Host ""

# -- 0. Choose mode --------------------------------------------------------------
Write-Host "Choose install mode:"
Write-Host ""
Write-Host "  [1] Always-on   - starts automatically at logon; the muter runs"
Write-Host "                    whenever Spotify is open. Open Spotify normally."
Write-Host ""
Write-Host "  [2] Manual      - runs only when you open Spotify via the"
Write-Host "                    'Spotify Launcher' shortcut. You control when it runs."
Write-Host ""
do {
    $choice = Read-Host "Enter 1 or 2"
} while ($choice -ne '1' -and $choice -ne '2')
$alwaysOn = ($choice -eq '1')

# -- 1. Copy scripts to a stable install location --------------------------------
Write-Host ""
Write-Host "Copying files to $installDir ..."
if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir | Out-Null
}
Copy-Item "$srcDir\SpotifyAdMuter.ps1"  "$installDir\SpotifyAdMuter.ps1"  -Force
Copy-Item "$srcDir\SpotifyLauncher.ps1" "$installDir\SpotifyLauncher.ps1" -Force
Copy-Item "$srcDir\SpotifyWatcher.ps1"  "$installDir\SpotifyWatcher.ps1"  -Force
Write-Host "  Done." -ForegroundColor Green

# Shared helper: create a hidden shortcut that runs a script via conhost --headless
# (runs PowerShell with the window hidden, and no AV-prone .vbs wrapper).
function New-HiddenShortcut {
    param([string]$Path, [string]$ScriptName, [string]$IconLocation)
    $shell = New-Object -ComObject WScript.Shell
    $sc = $shell.CreateShortcut($Path)
    $sc.TargetPath       = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
    $sc.Arguments        = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$installDir\$ScriptName`""
    $sc.WorkingDirectory = $installDir
    if ($IconLocation) { $sc.IconLocation = $IconLocation }
    $sc.WindowStyle      = 7
    $sc.Save()
}

# Spotify icon for the shortcut(s), if we can find it
$spotifyExe = "$env:LOCALAPPDATA\Microsoft\WindowsApps\Spotify.exe"
if (-not (Test-Path $spotifyExe)) { $spotifyExe = "$env:APPDATA\Spotify\Spotify.exe" }
$iconLocation = if (Test-Path $spotifyExe) { "$spotifyExe,0" } else { "powershell.exe,0" }

# -- 2. Desktop launch shortcut --------------------------------------------------
Write-Host "Creating 'Spotify Launcher' desktop shortcut ..."
try {
    $desktop = [Environment]::GetFolderPath('Desktop')
    New-HiddenShortcut -Path "$desktop\Spotify Launcher.lnk" -ScriptName 'SpotifyLauncher.ps1' -IconLocation $iconLocation
    Write-Host "  Done." -ForegroundColor Green
} catch {
    Write-Host "  Could not create desktop shortcut: $_" -ForegroundColor Yellow
}

# -- 3. Always-on: Startup-folder watcher shortcut -------------------------------
$startupLnk = Join-Path ([Environment]::GetFolderPath('Startup')) 'SpotifyAdMuter (always-on).lnk'
if ($alwaysOn) {
    Write-Host "Enabling always-on (Startup shortcut) ..."
    try {
        New-HiddenShortcut -Path $startupLnk -ScriptName 'SpotifyWatcher.ps1' -IconLocation $iconLocation
        # Start it now so the user does not have to log off/on first
        Start-Process $startupLnk
        Write-Host "  Done." -ForegroundColor Green
    } catch {
        Write-Host "  Could not enable always-on: $_" -ForegroundColor Yellow
    }
} else {
    # Manual mode: make sure no stale always-on shortcut is left behind
    if (Test-Path $startupLnk) { Remove-Item $startupLnk -Force }
}

# -- 4. Verify CoreAudio interop -------------------------------------------------
Write-Host ""
Write-Host "Running CoreAudio verification (Spotify does not need to be open) ..."
try {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass `
        -File "$installDir\SpotifyAdMuter.ps1" -TestMuteToggle
    Write-Host "  CoreAudio test passed." -ForegroundColor Green
} catch {
    Write-Host "  CoreAudio test failed: $_" -ForegroundColor Yellow
    Write-Host "  The muter may still work - muting is skipped if no Spotify audio session exists."
}

# -- 5. Summary ------------------------------------------------------------------
Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host " Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "  Installed to  : $installDir"
if ($alwaysOn) {
    Write-Host "  Mode          : Always-on (starts at logon)" -ForegroundColor Green
    Write-Host "  Open Spotify normally - the muter starts itself." -ForegroundColor Green
} else {
    Write-Host "  Mode          : Manual" -ForegroundColor Yellow
    Write-Host "  Use the 'Spotify Launcher' desktop shortcut to open Spotify + muter." -ForegroundColor Yellow
}
Write-Host "  Stats file    : $installDir\SpotifyMuteStats.json  (created on first mute)"
Write-Host "  Activity log  : $installDir\SpotifyAdMuter.log"
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
