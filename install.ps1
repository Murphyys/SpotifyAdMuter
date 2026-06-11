#Requires -Version 5.1
# install.ps1 — Installs SpotifyAdMuter and registers the scheduled task.
# No administrator rights required. Run from the cloned repo folder.

$ErrorActionPreference = 'Stop'
$installDir = Join-Path $env:LOCALAPPDATA 'SpotifyMute'
$taskName   = 'SpotifyAdMuter'
$srcDir     = $PSScriptRoot

Write-Host ""
Write-Host "SpotifyAdMuter Installer" -ForegroundColor Cyan
Write-Host "========================" -ForegroundColor Cyan
Write-Host ""

# ── 1. Copy scripts to stable install location ────────────────────────────────
Write-Host "Copying files to $installDir ..."
if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir | Out-Null
}
Copy-Item "$srcDir\SpotifyAdMuter.ps1"  "$installDir\SpotifyAdMuter.ps1"  -Force
Copy-Item "$srcDir\SpotifyLauncher.ps1" "$installDir\SpotifyLauncher.ps1" -Force
Write-Host "  Done." -ForegroundColor Green

# ── 2. Register / update scheduled task ──────────────────────────────────────
Write-Host "Registering scheduled task '$taskName' ..."

$action = New-ScheduledTaskAction `
    -Execute  'conhost.exe' `
    -Argument "--headless powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$installDir\SpotifyAdMuter.ps1`""

$triggerLogon  = New-ScheduledTaskTrigger -AtLogOn
$triggerRepeat = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Minutes 5) -Once -At (Get-Date)

$settings = New-ScheduledTaskSettingsSet `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Hours 0)

$principal = New-ScheduledTaskPrincipal `
    -UserId    $env:USERNAME `
    -LogonType Interactive `
    -RunLevel  Limited

$existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existing) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}
Register-ScheduledTask `
    -TaskName  $taskName `
    -Action    $action `
    -Trigger   @($triggerLogon, $triggerRepeat) `
    -Settings  $settings `
    -Principal $principal | Out-Null

Write-Host "  Done." -ForegroundColor Green

# ── 3. Verify CoreAudio interop ───────────────────────────────────────────────
Write-Host ""
Write-Host "Running CoreAudio verification (Spotify does not need to be open) ..."
try {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass `
        -File "$installDir\SpotifyAdMuter.ps1" -TestMuteToggle
    Write-Host "  CoreAudio test passed." -ForegroundColor Green
} catch {
    Write-Host "  CoreAudio test failed: $_" -ForegroundColor Yellow
    Write-Host "  The muter may still work — muting is skipped if no Spotify audio session exists."
}

# ── 4. Summary ────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host " Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "  Installed to  : $installDir"
Write-Host "  Scheduled task: $taskName  (runs at logon + every 5 min)"
Write-Host "  Stats file    : $installDir\SpotifyMuteStats.json  (created on first mute)"
Write-Host "  Activity log  : $installDir\SpotifyAdMuter.log"
Write-Host ""
Write-Host " Open Spotify and the muter starts automatically." -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""
