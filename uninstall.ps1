#Requires -Version 5.1
# uninstall.ps1 — Removes SpotifyAdMuter scheduled task and installed files.

$ErrorActionPreference = 'Continue'
$installDir = Join-Path $env:LOCALAPPDATA 'SpotifyMute'
$taskName   = 'SpotifyAdMuter'

Write-Host ""
Write-Host "SpotifyAdMuter Uninstaller" -ForegroundColor Cyan
Write-Host "==========================" -ForegroundColor Cyan
Write-Host ""

# ── 1. Stop and remove scheduled task ────────────────────────────────────────
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($task) {
    Write-Host "Removing scheduled task '$taskName' ..."
    Stop-ScheduledTask  -TaskName $taskName -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host "  Done." -ForegroundColor Green
} else {
    Write-Host "Scheduled task '$taskName' not found — skipping." -ForegroundColor Yellow
}

# ── 2. Show stats before removing ────────────────────────────────────────────
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

# ── 3. Remove install directory ───────────────────────────────────────────────
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

# ── 4. Ensure Spotify is not left muted ──────────────────────────────────────
if (Get-Process -Name Spotify -ErrorAction SilentlyContinue) {
    Write-Host ""
    Write-Host "Spotify is running. If it sounds muted, open the Volume Mixer and restore it manually." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host " Uninstall complete!" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""
