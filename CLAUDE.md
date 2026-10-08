# CLAUDE.md — SpotifyAdMuter (project-specific rules)

> กฎร่วมของทุก dev project อยู่ที่ `../CLAUDE.md` — ไฟล์นี้เก็บเฉพาะกฎของโปรเจกต์นี้ · รายละเอียดการใช้งาน/ติดตั้ง → `README.md`

## What this is
mute เฉพาะ audio session ของ Spotify ตอนโฆษณาบน Windows — อ่าน window title ทุก 1 วิ (เพลงจริง = "Artist - Song" มีขีด, โฆษณา = อย่างอื่น) แล้ว mute/unmute ผ่าน CoreAudio COM ไม่แตะ system volume

## Stack
- PowerShell 5.1 ล้วน (ไม่มี dependency ภายนอก) + CoreAudio COM (per-session volume ของ Spotify)
- 3 สคริปต์: `SpotifyAdMuter.ps1` (ตัว mute) · `SpotifyLauncher.ps1` (เปิด Spotify + muter จาก shortcut) · `SpotifyWatcher.ps1` (always-on mode: ดูว่า Spotify เปิดอยู่ไหมแล้วคอยสั่ง muter)
- v1.1+ ใช้ conhost shortcut + hidden spawn แทน scheduled task / `launcher.vbs` (ถอดออกแล้ว)

## Running / Install
- `.\install.ps1` → copy ไป `%LOCALAPPDATA%\SpotifyMute\` + สร้าง shortcut "Spotify Launcher" + ถาม mode (1 always-on / 2 manual) · `.\uninstall.ps1` ถอด
- ทดสอบจริงต้องเปิด Spotify desktop แล้วรอโฆษณา — ไม่มี unit test; ยืนยันด้วย `SpotifyAdMuter.log` / `SpotifyMuteStats.json` (ทั้งคู่ gitignore แล้ว ห้าม commit)

## Conventions
- โค้ดต้องรันได้บน PowerShell 5.1 (ไม่ใช้ syntax ของ PowerShell 7 เช่น `&&`, `??`, ternary)
- repo GitHub = `Murphyys/SpotifyAdMuter` (public) แต่โฟลเดอร์ local ชื่อ `SpotifyMute` — อย่าเปลี่ยนชื่อโฟลเดอร์ (install path อ้างชื่อนี้)
- แก้ logic ตรวจโฆษณาแล้วให้อัปเดต README § FAQ ด้วย (user-facing)

## Pending / Known issues
- README เป็น English ล้วน — ยังไม่ตรงมาตรฐาน dev (header อังกฤษ/body ไทย) ตั้งใจคงไว้ก่อนเพราะ repo public มีคนนอกอ่าน · ถ้าจะแปลงให้ทำเป็น README ไทยแยกไฟล์ ไม่ทับของเดิม
- ไม่มีสถานะค้างอื่น ณ 2026-10-08 (v1.1.1 verified บนเครื่องจริง)
