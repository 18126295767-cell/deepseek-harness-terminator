# DeepSeek Harness Terminator Windows-Launcher

**Sprache:** [简体中文](README.zh-CN.md) · [English](README.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md) · [Français](README.fr.md) · Deutsch · [Português](README.pt-BR.md) · [Русский](README.ru.md) · [العربية](README.ar.md) · [हिन्दी](README.hi.md) · [繁體中文](README.zh-TW.md)

Dieser Community-Launcher startet die offizielle Web-Runtime `@deepseek-ai/dsh` und öffnet `http://127.0.0.1:<port>` im Standardbrowser. Er ist keine offizielle DeepSeek-AI-Desktop-App und enthält weder Runtime, API-Schlüssel, Profile oder Sitzungen noch das nur unter macOS verfügbare Plugin `dsh-mac-control`.

## Voraussetzungen

- Windows 10/11 x64
- Node.js 22 LTS empfohlen (20 oder neuer)
- PowerShell 5.1 oder 7
- Lokale DSH-Runtime mit `node_modules\@deepseek-ai\dsh\lib\bin.js`

## Offizielle Runtime vorbereiten

```powershell
New-Item -ItemType Directory -Force "$HOME\dsh-runtime" | Out-Null
Set-Location "$HOME\dsh-runtime"
npm init -y
npm install --save-exact @deepseek-ai/dsh@0.1.0-rc.7
node node_modules\@deepseek-ai\dsh\lib\bin.js web --port 3080
```

Um Git, Node.js LTS und NSIS zusätzlich per `winget` einzurichten, führe im Repository-Stamm Folgendes aus. Das Skript richtet keine Zugangsdaten ein.

```powershell
Set-Location windows
& .\bootstrap-build-environment.ps1
```

## Installieren und starten

Führe `.\install.ps1` im entpackten ZIP aus oder nutze den NSIS-Installer aus der GitHub Release. Administratorrechte sind nicht nötig. Der aktuelle Installer ist nicht codesigniert; vergleiche vor dem Start den veröffentlichten SHA-256-Wert.

```powershell
& "$env:LOCALAPPDATA\DeepSeek Harness Terminator\launch-dsh.ps1" -DshRuntime "$HOME\dsh-runtime" -Port 3080
```

Der Launcher lehnt belegte Ports ab, öffnet nach Bereitschaft den Browser und schreibt Logs nach `%LOCALAPPDATA%\DeepSeek Harness Terminator\logs`. Mit `-NoBrowser` bleibt der Browser geschlossen.

## Bauen und prüfen

```powershell
Set-Location windows
& .\build-release.ps1 -Version 0.1.1
Get-FileHash .\releases\DeepSeek-Harness-Setup-v0.1.1-x64.exe -Algorithm SHA256
Get-Content .\releases\DeepSeek-Harness-Windows-x64-v0.1.1.sha256
```

Die `windows-2025`-CI startet die offizielle Runtime wirklich, verlangt HTTP 200 und `window.__DSH_BOOT__` und prüft danach ZIP, NSIS, alle 12 Sprachdateien und SHA-256. macOS Automation/Accessibility ist unter Windows nicht verfügbar.

## Deinstallieren

```powershell
& "$env:LOCALAPPDATA\DeepSeek Harness Terminator\uninstall.ps1"
```

DSH-Runtime und Profile bleiben erhalten.

## Profil-Integritätsprüfung

Vor dem DSH-Start vergleicht der Launcher das gewählte Profil mit der echten
Runtime und blockiert eine zweite physische Kopie eines Host-Pakets
`@deepseek-ai/dsh-*`. Der Bericht nennt Paket und verursachendes Plugin, löscht
aber keine Dateien. Senden Sie die Aufgabe nach der Korrektur in einer neuen
Sitzung erneut, da die alte Sitzung bereits unvollständige `tool_calls` enthalten kann.
