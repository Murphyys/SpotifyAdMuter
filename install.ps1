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

# ── 0. Choose mode ────────────────────────────────────────────────────────────
Write-Host "Choose install mode:"
Write-Host ""
Write-Host "  [1] Always-on   — starts automatically at logon and every 5 minutes"
Write-Host "                    Spotify opens normally, muter runs in the background"
Write-Host ""
Write-Host "  [2] Manual      — only runs when you open Spotify via SpotifyLauncher.ps1"
Write-Host "                    No auto-start; you control when it runs"
Write-Host ""
do {
    $choice = Read-Host "Enter 1 or 2"
} while ($choice -ne '1' -and $choice -ne '2')
$alwaysOn = ($choice -eq '1')

# ── 1. Copy scripts to stable install location ────────────────────────────────
Write-Host ""
Write-Host "Copying files to $installDir ..."
if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir | Out-Null
}
Copy-Item "$srcDir\SpotifyAdMuter.ps1"  "$installDir\SpotifyAdMuter.ps1"  -Force
Copy-Item "$srcDir\SpotifyLauncher.ps1" "$installDir\SpotifyLauncher.ps1" -Force
Write-Host "  Done." -ForegroundColor Green

# ── 2. Register scheduled task ────────────────────────────────────────────────
Write-Host "Registering scheduled task '$taskName' ..."

$action = New-ScheduledTaskAction `
    -Execute  'conhost.exe' `
    -Argument "--headless powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$installDir\SpotifyAdMuter.ps1`""

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

if ($alwaysOn) {
    $triggerLogon  = New-ScheduledTaskTrigger -AtLogOn
    $triggerRepeat = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Minutes 5) -Once -At (Get-Date)
    Register-ScheduledTask `
        -TaskName  $taskName `
        -Action    $action `
        -Trigger   @($triggerLogon, $triggerRepeat) `
        -Settings  $settings `
        -Principal $principal | Out-Null
} else {
    # Manual mode: task registered but no triggers — SpotifyLauncher calls it on demand
    Register-ScheduledTask `
        -TaskName  $taskName `
        -Action    $action `
        -Settings  $settings `
        -Principal $principal | Out-Null
}

Write-Host "  Done." -ForegroundColor Green

# ── 3. Desktop shortcut ──────────────────────────────────────────────────────
Write-Host "Creating Desktop shortcut ..."
try {
    $desktop      = [Environment]::GetFolderPath('Desktop')
    $spotifyExe   = "$env:LOCALAPPDATA\Microsoft\WindowsApps\Spotify.exe"
    if (-not (Test-Path $spotifyExe)) { $spotifyExe = "$env:APPDATA\Spotify\Spotify.exe" }
    $iconLocation = if (Test-Path $spotifyExe) { "$spotifyExe,0" } else { "powershell.exe,0" }

    $shell = New-Object -ComObject WScript.Shell
    $sc = $shell.CreateShortcut("$desktop\Spotify.lnk")
    $sc.TargetPath       = "powershell.exe"
    $sc.Arguments        = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$installDir\SpotifyLauncher.ps1`""
    $sc.WorkingDirectory = $installDir
    $sc.IconLocation     = $iconLocation
    $sc.WindowStyle      = 7
    $sc.Save()
    Write-Host "  Done — Spotify.lnk on Desktop." -ForegroundColor Green
} catch {
    Write-Host "  Could not create shortcut: $_" -ForegroundColor Yellow
}

# ── 4. Verify CoreAudio interop ───────────────────────────────────────────────
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

# ── 5. Summary ────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host " Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "  Installed to  : $installDir"
if ($alwaysOn) {
    Write-Host "  Mode          : Always-on  (starts at logon + every 5 min)" -ForegroundColor Green
    Write-Host "  Open Spotify normally — the muter runs automatically." -ForegroundColor Green
} else {
    Write-Host "  Mode          : Manual  (runs only when launched via SpotifyLauncher.ps1)" -ForegroundColor Yellow
    Write-Host "  Open Spotify via SpotifyLauncher.ps1 to activate the muter." -ForegroundColor Yellow
    Write-Host "  Shortcut path : $installDir\SpotifyLauncher.ps1"
}
Write-Host "  Stats file    : $installDir\SpotifyMuteStats.json  (created on first mute)"
Write-Host "  Activity log  : $installDir\SpotifyAdMuter.log"
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""
