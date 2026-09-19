# Windows के लिए DeepSeek Harness Launcher

**भाषा:** [简体中文](README.zh-CN.md) · [English](README.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [Русский](README.ru.md) · [العربية](README.ar.md) · हिन्दी · [繁體中文](README.zh-TW.md)

यह community launcher official `@deepseek-ai/dsh` Web runtime शुरू करता है और default browser में `http://127.0.0.1:<port>` खोलता है। यह DeepSeek AI का official desktop app नहीं है। इसमें runtime, API keys, profiles, sessions या macOS-only `dsh-mac-control` plugin शामिल नहीं हैं।

## आवश्यकताएँ

- Windows 10/11 x64
- Node.js 22 LTS सुझाया गया (20 या नया)
- PowerShell 5.1 या 7
- `node_modules\@deepseek-ai\dsh\lib\bin.js` वाला local DSH runtime

## Official runtime तैयार करें

```powershell
New-Item -ItemType Directory -Force "$HOME\dsh-runtime" | Out-Null
Set-Location "$HOME\dsh-runtime"
npm init -y
npm install --save-exact @deepseek-ai/dsh@0.1.0-rc.7
node node_modules\@deepseek-ai\dsh\lib\bin.js web --port 3080
```

`winget` से Git, Node.js LTS और NSIS भी तैयार करने के लिए repository root से यह चलाएँ। Script credentials configure नहीं करती।

```powershell
Set-Location windows
& .\bootstrap-build-environment.ps1
```

## Install और start

Extracted ZIP में `.\install.ps1` चलाएँ या GitHub Release का NSIS installer इस्तेमाल करें। Administrator rights की ज़रूरत नहीं है। मौजूदा installer code-signed नहीं है; चलाने से पहले published SHA-256 मिलाएँ।

```powershell
& "$env:LOCALAPPDATA\DeepSeek Harness Terminator\launch-dsh.ps1" -DshRuntime "$HOME\dsh-runtime" -Port 3080
```

Launcher occupied port को reject करता है, service ready होने पर browser खोलता है और logs `%LOCALAPPDATA%\DeepSeek Harness Terminator\logs` में लिखता है। Browser न खोलने के लिए `-NoBrowser` लगाएँ।

## Build और verify

```powershell
Set-Location windows
& .\build-release.ps1 -Version 0.1.1
Get-FileHash .\releases\DeepSeek-Harness-Setup-v0.1.1-x64.exe -Algorithm SHA256
Get-Content .\releases\DeepSeek-Harness-Windows-x64-v0.1.1.sha256
```

`windows-2025` CI official runtime को वास्तव में चलाती है, HTTP 200 और `window.__DSH_BOOT__` की जाँच करती है, फिर ZIP, NSIS, 12 language guides और SHA-256 verify करती है। macOS Automation/Accessibility Windows पर उपलब्ध नहीं है।

## Uninstall

```powershell
& "$env:LOCALAPPDATA\DeepSeek Harness Terminator\uninstall.ps1"
```

DSH runtime और profiles सुरक्षित रहते हैं।

## Profile integrity जाँच

DSH शुरू होने से पहले launcher चुने हुए profile की वास्तविक runtime से तुलना
करता है और host `@deepseek-ai/dsh-*` package की दूसरी physical copy रोकता है।
रिपोर्ट package और उसे लाने वाले plugin का नाम बताती है, पर कोई file नहीं मिटाती।
Plugin ठीक करने के बाद task को नई session में फिर भेजें, क्योंकि पुरानी session में
अधूरा `tool_calls` message रह सकता है।
