# CLAUDE.md — SpotifyAdMuter (project-specific rules)

> Shared rules for all dev projects are in `../CLAUDE.md` — this file holds only this project's rules · usage/install details → `README.md`

## What this is
Mutes only Spotify's audio session during ads on Windows — reads the window title every 1 s (a real track = "Artist - Song" with a dash, an ad = anything else) then mutes/unmutes via CoreAudio COM without touching the system volume

## Stack
- Pure PowerShell 5.1 (no external dependencies) + CoreAudio COM (Spotify's per-session volume)
- 3 scripts: `SpotifyAdMuter.ps1` (the muter) · `SpotifyLauncher.ps1` (opens Spotify + the muter from a shortcut) · `SpotifyWatcher.ps1` (always-on mode: watches whether Spotify is open and then commands the muter)
- v1.1+ uses a conhost shortcut + hidden spawn instead of a scheduled task / `launcher.vbs` (removed)

## Running / Install
- `.\install.ps1` → copies to `%LOCALAPPDATA%\SpotifyMute\` + creates the "Spotify Launcher" shortcut + asks for the mode (1 always-on / 2 manual) · `.\uninstall.ps1` removes it
- Real testing requires opening the Spotify desktop app and waiting for an ad — there are no unit tests; verify with `SpotifyAdMuter.log` / `SpotifyMuteStats.json` (both gitignored, never commit)

## Conventions
- Code must run on PowerShell 5.1 (do not use PowerShell 7 syntax such as `&&`, `??`, ternary)
- The GitHub repo = `Murphyys/SpotifyAdMuter` (public) but the local folder is named `SpotifyMute` — do not rename the folder (the install path references this name)
- After changing the ad-detection logic, also update README § FAQ (user-facing)

## Pending / Known issues
- README is entirely English — does not yet match the dev standard (English headers/Thai body); intentionally left as is because the repo is public and read by outsiders · if converting, make a separate Thai README file and do not overwrite the existing one
- No other pending items as of 2026-10-08 (v1.1.1 verified on a real machine)
