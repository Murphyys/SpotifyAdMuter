# SpotifyAdMuter

Mutes Spotify during ads on Windows — automatically, silently, without touching your system volume.

## What it does

SpotifyAdMuter runs as a hidden background process. Every second, it reads Spotify's window title. Real tracks always show **"Artist - Song"** (with a dash). During ads the title changes to something else — "Advertisement", "Spotify Free", a promo line. When that happens, SpotifyAdMuter mutes **only Spotify's audio session** and unmutes the moment music resumes.

No system volume change. No Spotify UI interaction. Just silence.

## Requirements

- Windows 10 or Windows 11
- PowerShell 5.1 (built into Windows — nothing to download)
- Spotify desktop app (classic installer or Microsoft Store version)

## Install

```powershell
git clone https://github.com/Murphyys/SpotifyAdMuter
cd SpotifyAdMuter
.\install.ps1
```

The installer copies the scripts to `%LOCALAPPDATA%\SpotifyMute\`, creates a **"Spotify Launcher"** desktop shortcut, runs a CoreAudio verification, then asks which mode you want:

### Mode 1 — Always-on
A small watcher starts automatically at logon (a hidden shortcut in your Startup folder). Whenever Spotify is open, it makes sure the muter is running. Open Spotify any way you like — nothing else to do.

### Mode 2 — Manual
No auto-start. The muter only runs when you open Spotify through the **"Spotify Launcher"** desktop shortcut, which opens Spotify and starts the muter together. Use it instead of the regular Spotify shortcut.

> Both modes are window-free — shortcuts launch PowerShell hidden via `conhost --headless`, so nothing flashes on screen.

> **Execution policy error?**
> Run this once, then retry:
> ```powershell
> Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
> ```

## How it works

**Ad detection:** Spotify sets its window title to `"Artist — Song"` during playback and to `"Advertisement"` / `"Spotify Free"` / promo text during ads. SpotifyAdMuter polls this title once per second.

**Audio muting:** Uses the Windows CoreAudio COM API (`IAudioSessionManager2`) to mute Spotify's audio session directly. No other apps or your system volume are affected.

**Single instance:** A named mutex prevents duplicate processes — launching again while the muter is already running is a harmless no-op.

**Hidden execution:** Shortcuts run PowerShell through `conhost --headless`, and the muter is spawned with `-WindowStyle Hidden`, so no console window ever appears.

## Stats

After the first mute event, a stats file is created at:

```
%LOCALAPPDATA%\SpotifyMute\SpotifyMuteStats.json
```

```json
{ "installedAt": "2026-06-11T12:00:00+07:00", "totalMutes": 42 }
```

`totalMutes` counts how many times Spotify switched from music to an ad since installation on this machine. This file is local-only and not included in the repository.

## Uninstall

```powershell
.\uninstall.ps1
```

Stops any running process, removes the shortcuts and the installed files. You'll be asked whether to keep your stats file.

## FAQ

**Does it work with Spotify Premium?**
Premium doesn't serve audio ads so the script never mutes anything — but it runs harmlessly in the background. If you ever downgrade it works automatically.

**I see "Muted 0 session(s)" during install — is that a problem?**
No. That message appears when Spotify is not open during the CoreAudio test. It means the COM interface loaded correctly; there was just no active audio session to mute.

**Where are the logs?**
`%LOCALAPPDATA%\SpotifyMute\SpotifyAdMuter.log` — rotates automatically when it exceeds 512 KB.
