# SpotifyLauncher.ps1
# Opens Spotify, waits for its process to appear, then starts the ad-muter.
# Target of the Desktop shortcut (via launcher.vbs).

# Microsoft Store version is a 0-byte stub — launch via URI instead.
# Classic installer registers the same spotify: protocol, so this works for both.
$storeStub  = "$env:LOCALAPPDATA\Microsoft\WindowsApps\Spotify.exe"
$classicExe = "$env:APPDATA\Spotify\Spotify.exe"

if ((Test-Path $classicExe) -and (Get-Item $classicExe).Length -gt 0) {
    Start-Process $classicExe
} elseif (Test-Path $storeStub) {
    $pkg = Get-AppxPackage -Name "*Spotify*" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($pkg) {
        Start-Process "explorer.exe" -ArgumentList "shell:AppsFolder\$($pkg.PackageFamilyName)!Spotify"
    }
} else {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show('Spotify not found on this machine.', 'Spotify AdMuter') | Out-Null
    exit 1
}

for ($i = 0; $i -lt 30; $i++) {
    if (Get-Process -Name Spotify -ErrorAction SilentlyContinue) { break }
    Start-Sleep -Milliseconds 500
}

Start-ScheduledTask -TaskName 'SpotifyAdMuter'
