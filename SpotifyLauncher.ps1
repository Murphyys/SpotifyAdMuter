# SpotifyLauncher.ps1
# Opens Spotify, waits for its process to appear, then starts the ad-muter
# watcher (which exits immediately if Spotify isn't running).
# Target of the "Spotify AdMuter" Start Menu shortcut.

# Microsoft Store version first, then the classic desktop installer location
$spotifyExe = @(
    "$env:LOCALAPPDATA\Microsoft\WindowsApps\Spotify.exe",
    "$env:APPDATA\Spotify\Spotify.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $spotifyExe) {
    [System.Windows.Forms.MessageBox] | Out-Null
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show('Spotify not found on this machine.', 'Spotify AdMuter') | Out-Null
    exit 1
}

Start-Process $spotifyExe

for ($i = 0; $i -lt 30; $i++) {
    if (Get-Process -Name Spotify -ErrorAction SilentlyContinue) { break }
    Start-Sleep -Milliseconds 500
}

Start-ScheduledTask -TaskName 'SpotifyAdMuter'
