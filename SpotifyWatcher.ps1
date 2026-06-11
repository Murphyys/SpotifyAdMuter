# SpotifyWatcher.ps1
# Always-on mode (Mode 1). Launched at logon by a Startup-folder shortcut, hidden via conhost.
# Loops forever: whenever Spotify is open, makes sure the ad-muter is running.
# The muter's single-instance mutex makes a redundant spawn a harmless no-op.

$muter   = Join-Path $PSScriptRoot 'SpotifyAdMuter.ps1'
$spawned = $false

while ($true) {
    if (Get-Process -Name Spotify -ErrorAction SilentlyContinue) {
        if (-not $spawned) {
            Start-Process powershell.exe -WindowStyle Hidden -ArgumentList `
                '-NoProfile','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File',$muter
            $spawned = $true
        }
    } else {
        # Spotify closed — the muter self-exits after ~60s; re-arm for the next launch.
        $spawned = $false
    }
    Start-Sleep -Seconds 10
}
