# Запуск DeepSeek Harness для Windows

**Язык:** [简体中文](README.zh-CN.md) · [English](README.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · Русский · [العربية](README.ar.md) · [हिन्दी](README.hi.md) · [繁體中文](README.zh-TW.md)

Этот запускатель сообщества запускает официальный Web runtime `@deepseek-ai/dsh` и открывает `http://127.0.0.1:<port>` в браузере по умолчанию. Это не официальное настольное приложение DeepSeek AI. Он не содержит runtime, API-ключи, профили, сессии и macOS-плагин `dsh-mac-control`.

## Требования

- Windows 10/11 x64
- Рекомендуется Node.js 22 LTS (20 или новее)
- PowerShell 5.1 или 7
- Локальный DSH runtime с `node_modules\@deepseek-ai\dsh\lib\bin.js`

## Подготовка официального runtime

```powershell
New-Item -ItemType Directory -Force "$HOME\dsh-runtime" | Out-Null
Set-Location "$HOME\dsh-runtime"
npm init -y
npm install --save-exact @deepseek-ai/dsh@0.1.0-rc.7
node node_modules\@deepseek-ai\dsh\lib\bin.js web --port 3080
```

Чтобы также установить Git, Node.js LTS и NSIS через `winget`, выполните в корне репозитория. Скрипт не настраивает учетные данные.

```powershell
Set-Location windows
& .\bootstrap-build-environment.ps1
```

## Установка и запуск

Запустите `.\install.ps1` из распакованного ZIP или NSIS-установщик из GitHub Release. Права администратора не нужны. Текущий установщик не подписан; перед запуском сверьте SHA-256.

```powershell
& "$env:LOCALAPPDATA\DeepSeek Harness Terminator\launch-dsh.ps1" -DshRuntime "$HOME\dsh-runtime" -Port 3080
```

Запускатель отказывается от занятого порта, открывает браузер после готовности и пишет журналы в `%LOCALAPPDATA%\DeepSeek Harness Terminator\logs`. Ключ `-NoBrowser` не открывает браузер.

## Сборка и проверка

```powershell
Set-Location windows
& .\build-release.ps1 -Version 0.1.1
Get-FileHash .\releases\DeepSeek-Harness-Setup-v0.1.1-x64.exe -Algorithm SHA256
Get-Content .\releases\DeepSeek-Harness-Windows-x64-v0.1.1.sha256
```

CI `windows-2025` реально запускает официальный runtime, требует HTTP 200 и `window.__DSH_BOOT__`, затем проверяет ZIP, NSIS, 12 языковых руководств и SHA-256. Функции macOS Automation/Accessibility в Windows недоступны.

## Удаление

```powershell
& "$env:LOCALAPPDATA\DeepSeek Harness Terminator\uninstall.ps1"
```

DSH runtime и профили сохраняются.

## Проверка целостности профиля

Перед запуском DSH программа сравнивает выбранный профиль с реальным runtime и
блокирует вторую физическую копию любого пакета хоста `@deepseek-ai/dsh-*`.
Отчёт указывает пакет и добавивший его плагин, но не удаляет файлы. После
исправления повторите задачу в новой сессии: в старой уже мог сохраниться
неполный вызов `tool_calls`.
