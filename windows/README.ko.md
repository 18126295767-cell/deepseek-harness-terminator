# DeepSeek Harness Terminator Windows 런처

**언어:** [简体中文](README.zh-CN.md) · [English](README.md) · [日本語](README.ja.md) · 한국어 · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [Русский](README.ru.md) · [العربية](README.ar.md) · [हिन्दी](README.hi.md) · [繁體中文](README.zh-TW.md)

이 프로젝트는 공식 `@deepseek-ai/dsh` Web runtime을 실행하고 기본 브라우저에서 `http://127.0.0.1:<port>`를 여는 Windows용 커뮤니티 런처입니다. DeepSeek AI의 공식 데스크톱 앱이 아니며 runtime, API 키, profile, 세션, macOS 전용 `dsh-mac-control`을 포함하지 않습니다.

## 요구 사항

- Windows 10/11 x64
- Node.js 22 LTS 권장(20 이상)
- PowerShell 5.1 또는 7
- `node_modules\@deepseek-ai\dsh\lib\bin.js`가 있는 로컬 DSH runtime

## 공식 runtime 준비

```powershell
New-Item -ItemType Directory -Force "$HOME\dsh-runtime" | Out-Null
Set-Location "$HOME\dsh-runtime"
npm init -y
npm install --save-exact @deepseek-ai/dsh@0.1.0-rc.7
node node_modules\@deepseek-ai\dsh\lib\bin.js web --port 3080
```

빌드 환경과 공식 runtime을 함께 준비하려면 저장소 루트에서 다음을 실행하세요. `winget`으로 Git, Node.js LTS, NSIS를 설치하지만 인증 정보는 설정하지 않습니다.

```powershell
Set-Location windows
& .\bootstrap-build-environment.ps1
```

## 설치와 실행

압축을 푼 ZIP에서 `.\install.ps1`을 실행하거나 GitHub Release의 NSIS 설치 프로그램을 사용하세요. 관리자 권한은 필요하지 않습니다. 현재 설치 파일은 코드 서명되지 않았으므로 실행 전 SHA-256을 확인하세요.

```powershell
& "$env:LOCALAPPDATA\DeepSeek Harness Terminator\launch-dsh.ps1" -DshRuntime "$HOME\dsh-runtime" -Port 3080
```

런처는 이미 사용 중인 포트를 거부하고, 준비가 되면 브라우저를 열며, 로그를 `%LOCALAPPDATA%\DeepSeek Harness Terminator\logs`에 저장합니다. 브라우저 없이 실행하려면 `-NoBrowser`를 사용하세요.

## 빌드와 검증

```powershell
Set-Location windows
& .\build-release.ps1 -Version 0.1.1
Get-FileHash .\releases\DeepSeek-Harness-Setup-v0.1.1-x64.exe -Algorithm SHA256
Get-Content .\releases\DeepSeek-Harness-Windows-x64-v0.1.1.sha256
```

`windows-2025` CI는 공식 runtime을 실제로 실행하고 HTTP 200과 `window.__DSH_BOOT__`를 확인한 뒤 ZIP, NSIS, 12개 언어 문서, SHA-256을 검증합니다. macOS Automation/Accessibility 기능은 Windows에서 제공되지 않습니다.

## 제거

```powershell
& "$env:LOCALAPPDATA\DeepSeek Harness Terminator\uninstall.ps1"
```

DSH runtime과 profile은 삭제되지 않습니다.

## Profile 무결성 검사

DSH를 시작하기 전에 런처가 선택한 profile과 실제 runtime을 비교하고 호스트
`@deepseek-ai/dsh-*` 패키지의 두 번째 물리적 복사본을 차단합니다. 보고서는 충돌 패키지와
이를 가져온 플러그인을 표시하지만 profile 파일은 삭제하지 않습니다. 플러그인을 수정한 뒤에는
이전 세션에 불완전한 `tool_calls`가 남을 수 있으므로 새 세션에서 작업을 다시 보내십시오.
