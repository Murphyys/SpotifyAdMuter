# SpotifyAdMuter.ps1
param(
    # Mute Spotify, wait 3 seconds, unmute, then exit. For verifying the CoreAudio interop.
    [switch]$TestMuteToggle
)
# Mutes only the Spotify app's audio session while an ad is playing, unmutes when music resumes.
# Detection: window title is "Artist - Song" during music, "Advertisement"/"Spotify"/"Spotify Free" during ads.

$ErrorActionPreference = 'Continue'

# Single-instance guard
$createdNew = $false
$mutex = New-Object System.Threading.Mutex($true, 'SpotifyAdMuterSingleInstance', [ref]$createdNew)
if (-not $createdNew) {
    Write-Host 'SpotifyAdMuter is already running. Exiting.'
    exit
}

# Run only while Spotify is open: if it isn't running, exit immediately
# (cheap probe — the scheduled task retries every 5 minutes).
if (-not $TestMuteToggle -and -not (Get-Process -Name Spotify -ErrorAction SilentlyContinue)) {
    $mutex.ReleaseMutex()
    exit
}

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
class MMDeviceEnumeratorComObject { }

[Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDeviceEnumerator
{
    int NotImpl_EnumAudioEndpoints();
    [PreserveSig] int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice device);
}

[Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDevice
{
    [PreserveSig] int Activate(ref Guid iid, int clsCtx, IntPtr activationParams,
        [MarshalAs(UnmanagedType.IUnknown)] out object iface);
}

[Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioSessionManager2
{
    int NotImpl_GetAudioSessionControl();
    int NotImpl_GetSimpleAudioVolume();
    [PreserveSig] int GetSessionEnumerator(out IAudioSessionEnumerator sessionEnum);
}

[Guid("E2F5BB11-0570-40CA-ACDD-3AA01277DEE8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioSessionEnumerator
{
    [PreserveSig] int GetCount(out int count);
    [PreserveSig] int GetSession(int index, out IAudioSessionControl2 session);
}

[Guid("bfb7ff88-7239-4fc9-8fa2-07c950be9c6d"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioSessionControl2
{
    // IAudioSessionControl vtable slots
    int NotImpl_GetState();
    int NotImpl_GetDisplayName();
    int NotImpl_SetDisplayName();
    int NotImpl_GetIconPath();
    int NotImpl_SetIconPath();
    int NotImpl_GetGroupingParam();
    int NotImpl_SetGroupingParam();
    int NotImpl_RegisterAudioSessionNotification();
    int NotImpl_UnregisterAudioSessionNotification();
    // IAudioSessionControl2 slots
    int NotImpl_GetSessionIdentifier();
    int NotImpl_GetSessionInstanceIdentifier();
    [PreserveSig] int GetProcessId(out uint pid);
}

public static class SpotifyWindows
{
    delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb, IntPtr lParam);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder sb, int max);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr hWnd);

    // Returns the best title among all top-level windows owned by the process,
    // preferring visible windows. More reliable than Process.MainWindowTitle,
    // which often comes back empty for Spotify.
    public static string GetTitle(string processName)
    {
        var pids = new System.Collections.Generic.HashSet<uint>();
        foreach (var p in System.Diagnostics.Process.GetProcessesByName(processName))
            pids.Add((uint)p.Id);
        if (pids.Count == 0) return null;

        string visibleTitle = null, hiddenTitle = null;
        EnumWindows(delegate(IntPtr h, IntPtr l)
        {
            uint pid;
            GetWindowThreadProcessId(h, out pid);
            if (!pids.Contains(pid)) return true;
            var sb = new System.Text.StringBuilder(512);
            GetWindowText(h, sb, 512);
            if (sb.Length == 0) return true;
            string t = sb.ToString();
            // Skip helper windows that never carry track info
            if (t == "Default IME" || t == "MSCTFIME UI" || t.StartsWith("GDI+ Window")) return true;
            if (IsWindowVisible(h)) { if (visibleTitle == null) visibleTitle = t; }
            else { if (hiddenTitle == null) hiddenTitle = t; }
            return true;
        }, IntPtr.Zero);
        return visibleTitle != null ? visibleTitle : hiddenTitle;
    }
}

[Guid("87CE5498-68D6-44E5-9215-6DA47EF883D8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface ISimpleAudioVolume
{
    int NotImpl_SetMasterVolume();
    int NotImpl_GetMasterVolume();
    [PreserveSig] int SetMute([MarshalAs(UnmanagedType.Bool)] bool mute, ref Guid eventContext);
    [PreserveSig] int GetMute([MarshalAs(UnmanagedType.Bool)] out bool mute);
}

public static class SpotifyAudio
{
    // Sets mute on every audio session owned by a process with the given name.
    // Returns the number of sessions changed.
    public static int SetMuteByProcessName(string processName, bool mute)
    {
        var pids = new System.Collections.Generic.HashSet<uint>();
        foreach (var p in System.Diagnostics.Process.GetProcessesByName(processName))
            pids.Add((uint)p.Id);
        if (pids.Count == 0) return 0;

        int changed = 0;
        var deviceEnumerator = (IMMDeviceEnumerator)new MMDeviceEnumeratorComObject();
        IMMDevice device = null;
        IAudioSessionManager2 manager = null;
        IAudioSessionEnumerator sessions = null;
        try
        {
            deviceEnumerator.GetDefaultAudioEndpoint(0 /*eRender*/, 1 /*eMultimedia*/, out device);
            Guid iid = typeof(IAudioSessionManager2).GUID;
            object obj;
            device.Activate(ref iid, 0x17 /*CLSCTX_ALL*/, IntPtr.Zero, out obj);
            manager = (IAudioSessionManager2)obj;
            manager.GetSessionEnumerator(out sessions);
            int count;
            sessions.GetCount(out count);
            for (int i = 0; i < count; i++)
            {
                IAudioSessionControl2 session = null;
                try
                {
                    sessions.GetSession(i, out session);
                    uint pid;
                    session.GetProcessId(out pid);
                    if (!pids.Contains(pid)) continue;
                    var volume = session as ISimpleAudioVolume;
                    if (volume == null) continue;
                    Guid ctx = Guid.Empty;
                    if (volume.SetMute(mute, ref ctx) == 0) changed++;
                }
                catch { }
                finally { if (session != null) Marshal.ReleaseComObject(session); }
            }
        }
        finally
        {
            if (sessions != null) Marshal.ReleaseComObject(sessions);
            if (manager != null) Marshal.ReleaseComObject(manager);
            if (device != null) Marshal.ReleaseComObject(device);
            Marshal.ReleaseComObject(deviceEnumerator);
        }
        return changed;
    }
}
'@

if ($TestMuteToggle) {
    $n = [SpotifyAudio]::SetMuteByProcessName('Spotify', $true)
    Write-Host "Muted $n Spotify session(s). Waiting 3 seconds..."
    Start-Sleep -Seconds 3
    $n = [SpotifyAudio]::SetMuteByProcessName('Spotify', $false)
    Write-Host "Unmuted $n Spotify session(s). Test done."
    $mutex.ReleaseMutex()
    exit
}

# Real songs always title the window "Artist - Song". Anything else (Advertisement,
# Spotify Free, localized brand/promo ad titles, paused/idle) is treated as an ad —
# muting while paused is harmless since nothing is playing.
$songTitlePattern = ' - '
$muted = $false

$logFile   = Join-Path $PSScriptRoot 'SpotifyAdMuter.log'
$statsFile = Join-Path $PSScriptRoot 'SpotifyMuteStats.json'

function Write-Log([string]$message) {
    $line = "{0:yyyy-MM-dd HH:mm:ss}  {1}" -f (Get-Date), $message
    Write-Host $line
    try {
        if ((Test-Path $logFile) -and (Get-Item $logFile).Length -gt 512KB) {
            Move-Item $logFile "$logFile.old" -Force
        }
        Add-Content -Path $logFile -Value $line -Encoding UTF8
    } catch { }
}

function Save-Stats {
    try {
        $json = $script:stats | ConvertTo-Json -Compress
        Set-Content -Path $statsFile -Value $json -Encoding UTF8
    } catch { }
}

# Load or create persistent mute counter
if (Test-Path $statsFile) {
    try { $stats = Get-Content $statsFile -Raw | ConvertFrom-Json } catch { $stats = $null }
}
if (-not $stats -or -not $stats.PSObject.Properties['installedAt']) {
    $stats = [PSCustomObject]@{ installedAt = (Get-Date -Format 'o'); totalMutes = 0 }
    Save-Stats
}

Write-Log 'SpotifyAdMuter started. Watching Spotify window titles...'

$lastTitle = $null
$absentSeconds = 0
try {
    while ($true) {
        $title = [SpotifyWindows]::GetTitle('Spotify')

        # Exit once Spotify has been closed for a full minute
        if ($null -eq $title -and -not (Get-Process -Name Spotify -ErrorAction SilentlyContinue)) {
            $absentSeconds++
            if ($absentSeconds -ge 60) {
                Write-Log 'Spotify closed for 60s; exiting until next launch.'
                break
            }
        } else {
            $absentSeconds = 0
        }

        if ($title -ne $lastTitle) {
            Write-Log "title changed: '$title'"
            $lastTitle = $title
        }

        if ($title) {
            if ($title.Contains($songTitlePattern)) {
                if ($muted) {
                    $n = [SpotifyAudio]::SetMuteByProcessName('Spotify', $false)
                    $muted = $false
                    Write-Log "UNMUTED ($n session(s)) - title: '$title'"
                }
            }
            else {
                # Re-apply mute every cycle: ads may spawn a new audio session after the first mute
                $n = [SpotifyAudio]::SetMuteByProcessName('Spotify', $true)
                if (-not $muted) {
                    $muted = $true
                    $stats.totalMutes++
                    Save-Stats
                    Write-Log "MUTED ($n session(s)) - title: '$title'"
                }
            }
        }
        # Spotify not running or no visible window: keep current state

        Start-Sleep -Seconds 1
    }
}
finally {
    # Never leave Spotify muted if this script stops
    [SpotifyAudio]::SetMuteByProcessName('Spotify', $false) | Out-Null
    $mutex.ReleaseMutex()
    Write-Log 'SpotifyAdMuter stopped; Spotify unmuted.'
}
