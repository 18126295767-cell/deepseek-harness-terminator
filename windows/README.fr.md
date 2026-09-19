# Lanceur DeepSeek Harness pour Windows

**Langue :** [简体中文](README.zh-CN.md) · [English](README.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md) · Français · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [Русский](README.ru.md) · [العربية](README.ar.md) · [हिन्दी](README.hi.md) · [繁體中文](README.zh-TW.md)

Ce lanceur communautaire démarre le runtime Web officiel `@deepseek-ai/dsh` et ouvre `http://127.0.0.1:<port>` dans le navigateur par défaut. Ce n'est pas une application de bureau officielle de DeepSeek AI. Il n'inclut ni runtime, ni clé API, ni profil, ni session, ni le plugin `dsh-mac-control` réservé à macOS.

## Prérequis

- Windows 10/11 x64
- Node.js 22 LTS recommandé (20 ou ultérieur)
- PowerShell 5.1 ou 7
- Un runtime DSH local contenant `node_modules\@deepseek-ai\dsh\lib\bin.js`

## Préparer le runtime officiel

```powershell
New-Item -ItemType Directory -Force "$HOME\dsh-runtime" | Out-Null
Set-Location "$HOME\dsh-runtime"
npm init -y
npm install --save-exact @deepseek-ai/dsh@0.1.0-rc.7
node node_modules\@deepseek-ai\dsh\lib\bin.js web --port 3080
```

Pour installer aussi Git, Node.js LTS et NSIS via `winget`, exécutez depuis la racine du dépôt. Le script ne configure aucun identifiant.

```powershell
Set-Location windows
& .\bootstrap-build-environment.ps1
```

## Installer et démarrer

Exécutez `.\install.ps1` dans le ZIP extrait ou utilisez l'installateur NSIS de la GitHub Release. Aucun droit administrateur n'est requis. L'installateur actuel n'est pas signé ; comparez son SHA-256 avant de l'exécuter.

```powershell
& "$env:LOCALAPPDATA\DeepSeek Harness Terminator\launch-dsh.ps1" -DshRuntime "$HOME\dsh-runtime" -Port 3080
```

Le lanceur refuse un port déjà utilisé, ouvre le navigateur une fois le service prêt et écrit les journaux dans `%LOCALAPPDATA%\DeepSeek Harness Terminator\logs`. Utilisez `-NoBrowser` pour un démarrage sans navigateur.

## Construire et vérifier

```powershell
Set-Location windows
& .\build-release.ps1 -Version 0.1.1
Get-FileHash .\releases\DeepSeek-Harness-Setup-v0.1.1-x64.exe -Algorithm SHA256
Get-Content .\releases\DeepSeek-Harness-Windows-x64-v0.1.1.sha256
```

La CI `windows-2025` lance réellement le runtime officiel et exige HTTP 200 avec `window.__DSH_BOOT__`, puis valide ZIP, NSIS, les 12 guides et SHA-256. Les fonctions Automation/Accessibility de macOS ne sont pas disponibles sous Windows.

## Désinstaller

```powershell
& "$env:LOCALAPPDATA\DeepSeek Harness Terminator\uninstall.ps1"
```

Le runtime DSH et les profils sont conservés.

## Contrôle d'intégrité du profil

Avant de démarrer DSH, le lanceur compare le profil choisi au runtime réel et
bloque toute seconde copie physique d'un paquet hôte `@deepseek-ai/dsh-*`.
Le rapport indique le paquet et le plugin responsable sans supprimer de fichier.
Après correction, renvoyez la tâche dans une nouvelle session, car l'ancienne
peut déjà contenir un message `tool_calls` incomplet.
