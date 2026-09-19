# Inicializador DeepSeek Harness para Windows

**Idioma:** [简体中文](README.zh-CN.md) · [English](README.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · Português · [Русский](README.ru.md) · [العربية](README.ar.md) · [हिन्दी](README.hi.md) · [繁體中文](README.zh-TW.md)

Este inicializador comunitário executa o runtime Web oficial `@deepseek-ai/dsh` e abre `http://127.0.0.1:<port>` no navegador padrão. Ele não é um aplicativo oficial da DeepSeek AI e não inclui runtime, chaves de API, profiles, sessões nem o plugin `dsh-mac-control`, exclusivo do macOS.

## Requisitos

- Windows 10/11 x64
- Node.js 22 LTS recomendado (20 ou superior)
- PowerShell 5.1 ou 7
- Runtime DSH local com `node_modules\@deepseek-ai\dsh\lib\bin.js`

## Preparar o runtime oficial

```powershell
New-Item -ItemType Directory -Force "$HOME\dsh-runtime" | Out-Null
Set-Location "$HOME\dsh-runtime"
npm init -y
npm install --save-exact @deepseek-ai/dsh@0.1.0-rc.7
node node_modules\@deepseek-ai\dsh\lib\bin.js web --port 3080
```

Para preparar também Git, Node.js LTS e NSIS com `winget`, execute na raiz do repositório. O script não configura credenciais.

```powershell
Set-Location windows
& .\bootstrap-build-environment.ps1
```

## Instalar e iniciar

Execute `.\install.ps1` no ZIP extraído ou use o instalador NSIS da GitHub Release. Não são necessários privilégios de administrador. O instalador atual não tem assinatura de código; confira o SHA-256 publicado antes de executá-lo.

```powershell
& "$env:LOCALAPPDATA\DeepSeek Harness Terminator\launch-dsh.ps1" -DshRuntime "$HOME\dsh-runtime" -Port 3080
```

O inicializador recusa portas ocupadas, abre o navegador quando o serviço fica pronto e grava logs em `%LOCALAPPDATA%\DeepSeek Harness Terminator\logs`. Use `-NoBrowser` para não abrir o navegador.

## Compilar e verificar

```powershell
Set-Location windows
& .\build-release.ps1 -Version 0.1.1
Get-FileHash .\releases\DeepSeek-Harness-Setup-v0.1.1-x64.exe -Algorithm SHA256
Get-Content .\releases\DeepSeek-Harness-Windows-x64-v0.1.1.sha256
```

O CI `windows-2025` inicia o runtime oficial, exige HTTP 200 e `window.__DSH_BOOT__` e verifica ZIP, NSIS, os 12 guias e SHA-256. Os recursos Automation/Accessibility do macOS não existem no Windows.

## Desinstalar

```powershell
& "$env:LOCALAPPDATA\DeepSeek Harness Terminator\uninstall.ps1"
```

O runtime DSH e os profiles são preservados.

## Verificação de integridade do profile

Antes de iniciar o DSH, o launcher compara o profile escolhido com o runtime
real e bloqueia uma segunda cópia física de pacotes host
`@deepseek-ai/dsh-*`. O relatório identifica o pacote e o plugin responsável,
sem excluir arquivos. Após corrigir o plugin, reenvie a tarefa em uma sessão
nova, pois a antiga pode conter um `tool_calls` incompleto.
