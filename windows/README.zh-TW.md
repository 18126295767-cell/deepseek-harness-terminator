# DeepSeek Harness Terminator Windows 啟動器

**語言：** [簡體中文](README.zh-CN.md) · [English](README.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [Русский](README.ru.md) · [العربية](README.ar.md) · [हिन्दी](README.hi.md) · 繁體中文

這是一個社群版 Windows 啟動器，用來啟動官方 `@deepseek-ai/dsh` Web runtime，並在預設瀏覽器開啟 `http://127.0.0.1:<port>`。它不是 DeepSeek AI 官方桌面 App，也不包含 runtime、API Key、profile、瀏覽器會話或僅支援 macOS 的 `dsh-mac-control` 外掛。

## 需求

- Windows 10/11 x64
- 建議 Node.js 22 LTS（20 或更新版）
- PowerShell 5.1 或 7
- 包含 `node_modules\@deepseek-ai\dsh\lib\bin.js` 的本機 DSH runtime

## 準備官方 runtime

```powershell
New-Item -ItemType Directory -Force "$HOME\dsh-runtime" | Out-Null
Set-Location "$HOME\dsh-runtime"
npm init -y
npm install --save-exact @deepseek-ai/dsh@0.1.0-rc.7
node node_modules\@deepseek-ai\dsh\lib\bin.js web --port 3080
```

如果也要透過 `winget` 準備 Git、Node.js LTS 和 NSIS，請從儲存庫根目錄執行。腳本不會設定任何憑證。

```powershell
Set-Location windows
& .\bootstrap-build-environment.ps1
```

## 安裝與啟動

在解壓後的 ZIP 內執行 `.\install.ps1`，或使用 GitHub Release 中的 NSIS 安裝程式。不需要管理員權限。目前安裝程式尚未簽章，執行前請核對公開的 SHA-256。

```powershell
& "$env:LOCALAPPDATA\DeepSeek Harness Terminator\launch-dsh.ps1" -DshRuntime "$HOME\dsh-runtime" -Port 3080
```

啟動器會拒絕已佔用的連接埠，服務就緒後開啟瀏覽器，並將日誌寫入 `%LOCALAPPDATA%\DeepSeek Harness Terminator\logs`。使用 `-NoBrowser` 可不開啟瀏覽器。

## 建置與驗證

```powershell
Set-Location windows
& .\build-release.ps1 -Version 0.1.1
Get-FileHash .\releases\DeepSeek-Harness-Setup-v0.1.1-x64.exe -Algorithm SHA256
Get-Content .\releases\DeepSeek-Harness-Windows-x64-v0.1.1.sha256
```

`windows-2025` CI 會真正啟動官方 runtime，要求 HTTP 200 和 `window.__DSH_BOOT__` 通過，再驗證 ZIP、NSIS、12 種語言指南和 SHA-256。macOS Automation/Accessibility 功能不會在 Windows 上提供。

## 移除

```powershell
& "$env:LOCALAPPDATA\DeepSeek Harness Terminator\uninstall.ps1"
```

DSH runtime 與 profiles 會保留。

## Profile 完整性檢查

DSH 啟動前，啟動器會比對所選 profile 與實際 runtime，並阻止宿主
`@deepseek-ai/dsh-*` 套件的第二個實體副本。報告會指出衝突套件與引入者，但不會刪除
profile 檔案。修復外掛後，請在新工作階段重新送出中斷的工作，因為舊工作階段可能已
儲存缺少對應工具結果的 `tool_calls` 訊息。
