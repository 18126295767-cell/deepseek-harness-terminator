# Lanzador de DeepSeek Harness para Windows

**Idioma:** [简体中文](README.zh-CN.md) · [English](README.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · Español · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [Русский](README.ru.md) · [العربية](README.ar.md) · [हिन्दी](README.hi.md) · [繁體中文](README.zh-TW.md)

Este lanzador comunitario inicia el runtime Web oficial `@deepseek-ai/dsh` y abre `http://127.0.0.1:<port>` en el navegador predeterminado. No es una aplicación de escritorio oficial de DeepSeek AI y no incluye el runtime, claves API, perfiles, sesiones ni el plugin `dsh-mac-control`, que es exclusivo de macOS.

## Requisitos

- Windows 10/11 x64
- Node.js 22 LTS recomendado (20 o posterior)
- PowerShell 5.1 o 7
- Un runtime DSH local con `node_modules\@deepseek-ai\dsh\lib\bin.js`

## Preparar el runtime oficial

```powershell
New-Item -ItemType Directory -Force "$HOME\dsh-runtime" | Out-Null
Set-Location "$HOME\dsh-runtime"
npm init -y
npm install --save-exact @deepseek-ai/dsh@0.1.0-rc.7
node node_modules\@deepseek-ai\dsh\lib\bin.js web --port 3080
```

Para preparar también Git, Node.js LTS y NSIS mediante `winget`, ejecute desde la raíz del repositorio. El script no configura credenciales.

```powershell
Set-Location windows
& .\bootstrap-build-environment.ps1
```

## Instalar e iniciar

Ejecute `.\install.ps1` dentro del ZIP extraído o use el instalador NSIS de GitHub Release. No necesita privilegios de administrador. El instalador actual no está firmado; compare el SHA-256 publicado antes de ejecutarlo.

```powershell
& "$env:LOCALAPPDATA\DeepSeek Harness Terminator\launch-dsh.ps1" -DshRuntime "$HOME\dsh-runtime" -Port 3080
```

El lanzador rechaza puertos ocupados, abre el navegador cuando el servicio está listo y guarda registros en `%LOCALAPPDATA%\DeepSeek Harness Terminator\logs`. Use `-NoBrowser` para no abrir el navegador.

## Compilar y verificar

```powershell
Set-Location windows
& .\build-release.ps1 -Version 0.1.1
Get-FileHash .\releases\DeepSeek-Harness-Setup-v0.1.1-x64.exe -Algorithm SHA256
Get-Content .\releases\DeepSeek-Harness-Windows-x64-v0.1.1.sha256
```

La CI `windows-2025` inicia el runtime oficial y exige HTTP 200 y `window.__DSH_BOOT__` antes de verificar ZIP, NSIS, las 12 guías y SHA-256. Las funciones Automation/Accessibility de macOS no existen en Windows.

## Desinstalar

```powershell
& "$env:LOCALAPPDATA\DeepSeek Harness Terminator\uninstall.ps1"
```

El runtime DSH y los perfiles se conservan.

## Control de integridad del perfil

Antes de iniciar DSH, el lanzador compara el perfil elegido con el runtime real
y bloquea una segunda copia física de cualquier paquete host
`@deepseek-ai/dsh-*`. El informe identifica el paquete y el plugin responsable,
pero no elimina archivos. Tras corregir el plugin, vuelve a enviar la tarea en
una sesión nueva, pues la anterior puede contener un `tool_calls` incompleto.
