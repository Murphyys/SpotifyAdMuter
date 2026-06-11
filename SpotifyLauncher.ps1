# SpotifyLauncher.ps1
# Opens Spotify, waits for its process to appear, then starts the ad-muter (hidden).
# Target of the "Spotify Launcher" desktop shortcut.

$launchLog = Join-Path $PSScriptRoot 'SpotifyLauncher.log'
function Write-LaunchLog($msg) {
    try { Add-Content -Path $launchLog -Value ("{0}  {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg) -Encoding UTF8 } catch { }
}

Write-LaunchLog "launcher started (PSScriptRoot=$PSScriptRoot)"

# Microsoft Store version is a 0-byte stub — launch via URI instead.
# Classic installer registers the same spotify: protocol, so this works for both.
$storeStub  = "$env:LOCALAPPDATA\Microsoft\WindowsApps\Spotify.exe"
$classicExe = "$env:APPDATA\Spotify\Spotify.exe"

if ((Test-Path $classicExe) -and (Get-Item $classicExe).Length -gt 0) {
    Write-LaunchLog "opening classic Spotify: $classicExe"
    Start-Process $classicExe
} elseif (Test-Path $storeStub) {
    Write-LaunchLog "opening Store Spotify via 'spotify:' URI"
    Start-Process "cmd.exe" -ArgumentList "/c start spotify:" -WindowStyle Hidden
} else {
    Write-LaunchLog "Spotify NOT FOUND"
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show('Spotify not found on this machine.', 'Spotify AdMuter') | Out-Null
    exit 1
}

Start-Sleep -Seconds 2

for ($i = 0; $i -lt 60; $i++) {
    if (Get-Process -Name Spotify -ErrorAction SilentlyContinue) { break }
    Start-Sleep -Milliseconds 500
}
$spotifyUp = [bool](Get-Process -Name Spotify -ErrorAction SilentlyContinue)
Write-LaunchLog "Spotify process detected: $spotifyUp"

# Launch the ad-muter hidden. Its single-instance mutex prevents duplicates,
# so clicking the shortcut again while it's already running is harmless.
$muter = Join-Path $PSScriptRoot 'SpotifyAdMuter.ps1'
Start-Process powershell.exe -WindowStyle Hidden -ArgumentList `
    '-NoProfile','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File',$muter
Write-LaunchLog "muter spawn issued; launcher done"
