#Requires -Version 5.1
# uninstall.ps1 — Removes SpotifyAdMuter shortcuts, running processes, and installed files.

$ErrorActionPreference = 'Continue'
$installDir = Join-Path $env:LOCALAPPDATA 'SpotifyMute'

Write-Host ""
Write-Host "SpotifyAdMuter Uninstaller" -ForegroundColor Cyan
Write-Host "==========================" -ForegroundColor Cyan
Write-Host ""

# -- 1. Stop any running muter / watcher ----------------------------------------
Write-Host "Stopping any running muter/watcher ..."
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { $_.CommandLine -match 'SpotifyAdMuter\.ps1|SpotifyWatcher\.ps1' } |
    ForEach-Object { try { Stop-Process -Id $_.ProcessId -Force } catch {} }
Write-Host "  Done." -ForegroundColor Green

# -- 2. Remove shortcuts (desktop launcher + always-on startup) -----------------
Write-Host "Removing shortcuts ..."
$desktopLnk = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Spotify Launcher.lnk'
$startupLnk = Join-Path ([Environment]::GetFolderPath('Startup')) 'SpotifyAdMuter (always-on).lnk'
foreach ($lnk in @($desktopLnk, $startupLnk)) {
    if (Test-Path $lnk) { Remove-Item $lnk -Force }
}
# Clean up a scheduled task from older versions, if present
$task = Get-ScheduledTask -TaskName 'SpotifyAdMuter' -ErrorAction SilentlyContinue
if ($task) {
    Stop-ScheduledTask -TaskName 'SpotifyAdMuter' -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName 'SpotifyAdMuter' -Confirm:$false
}
Write-Host "  Done." -ForegroundColor Green

# -- 3. Show stats before removing ----------------------------------------------
$statsFile = Join-Path $installDir 'SpotifyMuteStats.json'
$keepStats = $false
if (Test-Path $statsFile) {
    try {
        $s = Get-Content $statsFile -Raw | ConvertFrom-Json
        Write-Host ""
        Write-Host "Your stats: installed $($s.installedAt -replace 'T.*',''), total ads muted: $($s.totalMutes)"
    } catch { }
    $answer = Read-Host "Keep SpotifyMuteStats.json? [Y/n]"
    $keepStats = ($answer -eq '' -or $answer -match '^[Yy]')
}

# -- 4. Remove install directory ------------------------------------------------
if (Test-Path $installDir) {
    Write-Host ""
    Write-Host "Removing $installDir ..."
    if ($keepStats -and (Test-Path $statsFile)) {
        $tempStats = Join-Path $env:TEMP 'SpotifyMuteStats.json'
        Copy-Item $statsFile $tempStats -Force
        Remove-Item $installDir -Recurse -Force
        New-Item -ItemType Directory -Path $installDir | Out-Null
        Move-Item $tempStats $statsFile
        Write-Host "  Kept stats at $statsFile" -ForegroundColor Green
    } else {
        Remove-Item $installDir -Recurse -Force
        Write-Host "  Done." -ForegroundColor Green
    }
}

# -- 5. Ensure Spotify is not left muted ----------------------------------------
if (Get-Process -Name Spotify -ErrorAction SilentlyContinue) {
    Write-Host ""
    Write-Host "Spotify is running. If it sounds muted, open the Volume Mixer and restore it manually." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host " Uninstall complete!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
