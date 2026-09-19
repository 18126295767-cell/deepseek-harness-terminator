# DeepSeek Harness Terminator Windows ランチャー

**言語:** [简体中文](README.zh-CN.md) · [English](README.md) · 日本語 · [한국어](README.ko.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [Русский](README.ru.md) · [العربية](README.ar.md) · [हिन्दी](README.hi.md) · [繁體中文](README.zh-TW.md)

これは公式 `@deepseek-ai/dsh` Web runtime を起動し、既定のブラウザで `http://127.0.0.1:<port>` を開く Windows 用コミュニティランチャーです。DeepSeek AI 公式デスクトップアプリではありません。runtime、API キー、profile、セッション、macOS 専用の `dsh-mac-control` は同梱しません。

## 要件

- Windows 10/11 x64
- Node.js 22 LTS 推奨（20 以上）
- PowerShell 5.1 または 7
- `node_modules\@deepseek-ai\dsh\lib\bin.js` を含むローカル DSH runtime

## 公式 runtime の準備

```powershell
New-Item -ItemType Directory -Force "$HOME\dsh-runtime" | Out-Null
Set-Location "$HOME\dsh-runtime"
npm init -y
npm install --save-exact @deepseek-ai/dsh@0.1.0-rc.7
node node_modules\@deepseek-ai\dsh\lib\bin.js web --port 3080
```

ビルド環境を自動準備する場合は、リポジトリのルートから次を実行します。`winget` で Git、Node.js LTS、NSIS を入れますが、認証情報は設定しません。

```powershell
Set-Location windows
& .\bootstrap-build-environment.ps1
```

## インストールと起動

解凍した ZIP 内で `.\install.ps1` を実行するか、GitHub Release の NSIS インストーラーを使います。管理者権限は不要です。現在のインストーラーはコード署名されていないため、実行前に SHA-256 を照合してください。

```powershell
& "$env:LOCALAPPDATA\DeepSeek Harness Terminator\launch-dsh.ps1" -DshRuntime "$HOME\dsh-runtime" -Port 3080
```

ランチャーは使用中のポートを拒否し、起動後にブラウザを開き、ログを `%LOCALAPPDATA%\DeepSeek Harness Terminator\logs` に保存します。`-NoBrowser` でブラウザを開かずに起動できます。

## ビルドと検証

```powershell
Set-Location windows
& .\build-release.ps1 -Version 0.1.1
Get-FileHash .\releases\DeepSeek-Harness-Setup-v0.1.1-x64.exe -Algorithm SHA256
Get-Content .\releases\DeepSeek-Harness-Windows-x64-v0.1.1.sha256
```

`windows-2025` の CI は公式 runtime を実際に起動し、HTTP 200 と `window.__DSH_BOOT__` を検査してから ZIP、NSIS、12 言語のガイド、SHA-256 を検証します。macOS の Automation/Accessibility 機能は Windows では提供されません。

## アンインストール

```powershell
& "$env:LOCALAPPDATA\DeepSeek Harness Terminator\uninstall.ps1"
```

DSH runtime と profile は削除されません。

## Profile 整合性チェック

DSH の起動前に、ランチャーは選択した profile と実際の runtime を比較し、ホストの
`@deepseek-ai/dsh-*` パッケージの別の物理コピーをブロックします。レポートは競合する
パッケージと導入元を示しますが、profile のファイルは削除しません。プラグイン修正後は、
古いセッションに不完全な `tool_calls` が残り得るため、新しいセッションでタスクを再送してください。
